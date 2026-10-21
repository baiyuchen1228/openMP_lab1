CXX = g++
CXXFLAGS = -fopenmp -O3 -std=c++11

LOG ?= result.log

all: lab_v0 lab_v1 lab_v1_atomic

lab_v0: lab_v0.cpp
	$(CXX) $(CXXFLAGS) -o lab_v0 lab_v0.cpp

lab_v1: lab_v1.cpp
	$(CXX) $(CXXFLAGS) -o lab_v1 lab_v1.cpp

lab_v1_atomic: lab_v1_atomic.cpp
	$(CXX) $(CXXFLAGS) -o lab_v1_atomic lab_v1_atomic.cpp

runv0:
	@echo "=== Run lab_v0 ===" | tee $(LOG)
	@/usr/bin/time -p ./lab_v0 >> $(LOG) 2>&1

runv1:
	@echo "=== Run lab_v1 ===" | tee -a $(LOG)
	@OMP_DISPLAY_ENV=VERBOSE /usr/bin/time -p ./lab_v1 >> $(LOG) 2>&1

runv1_atomic:
	@echo "=== Run lab_v1_atomic ===" | tee -a $(LOG)
	@OMP_DISPLAY_ENV=VERBOSE /usr/bin/time -p ./lab_v1_atomic >> $(LOG) 2>&1

run: runv0 runv1 runv1_atomic

clean:
	rm -f lab_v0 lab_v1 lab_v1_atomic
