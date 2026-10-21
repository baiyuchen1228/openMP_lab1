#!/bin/bash
# Re-run the whole experiment on the current machine.
# Results go to results_<date>/ so the original result*.log files stay untouched.
# Each thread count is run REPEAT times (interleaved), summary.md reports mean / stddev.

set -e
cd "$(dirname "$0")"

THREADS="${THREADS:-1 2 4 6 8 12}"
REPEAT="${REPEAT:-5}"
OUT="${OUT:-results_$(date +%Y%m%d)}"
mkdir -p "$OUT"

# machine / toolchain / build flags
{
    echo "### date";      date
    echo "### uname";     uname -a
    echo "### os";        cat /etc/os-release
    echo "### lscpu";     lscpu
    echo "### memory";    free -h
    echo "### compiler";  g++ --version
    echo "### make";      make --version | head -1
    echo "### flags";     grep -E '^CXX(FLAGS)? *=' Makefile | tr -d '\r'
    echo "### libgomp";   ldconfig -p | grep libgomp || true
} > "$OUT/env.txt" 2>&1

make clean
make
for r in $(seq 1 "$REPEAT"); do
    mkdir -p "$OUT/run$r"
    for t in $THREADS; do
        echo ">>> run $r/$REPEAT, OMP_NUM_THREADS=$t"
        OMP_NUM_THREADS=$t make run LOG="$OUT/run$r/result$t.log"
    done
done
make clean

# summary table: mean ± stddev of real time per program per thread count
{
    echo "REPEAT=$REPEAT, real time in seconds (mean ± stddev)"
    echo
    printf "| Threads | lab_v0 | lab_v1 (reduction) | lab_v1_atomic |\n"
    printf "| --- | --- | --- | --- |\n"
    for t in $THREADS; do
        for r in $(seq 1 "$REPEAT"); do
            grep '^real' "$OUT/run$r/result$t.log" | awk '{print NR, $2}'
        done | awk -v t="$t" '
            { s[$1] += $2; q[$1] += $2 * $2; n[$1]++ }
            END {
                printf "| %s", t
                for (i = 1; i <= 3; i++) {
                    m = s[i] / n[i]; v = q[i] / n[i] - m * m; if (v < 0) v = 0
                    printf " | %.2f ± %.2f", m, sqrt(v)
                }
                printf " |\n"
            }'
    done
} | tee "$OUT/summary.md"
