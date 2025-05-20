CXX = g++
CXXFLAGS = -fopenmp -O3 -std=c++11

all: lab_v0 lab_v1

lab_v0: lab_v0.cpp
	$(CXX) $(CXXFLAGS) -o lab_v0 lab_v0.cpp

lab_v1: lab_v1.cpp
	$(CXX) $(CXXFLAGS) -o lab_v1 lab_v1.cpp

runv0:
	@echo "=== Run lab_v0 ===" | tee result.log
	@/usr/bin/time -p ./lab_v0 >> result.log 2>&1

runv1:
	@echo "=== Run lab_v1 ===" | tee -a result.log
	@OMP_DISPLAY_ENV=VERBOSE /usr/bin/time -p ./lab_v1 >> result.log 2>&1

run: runv0 runv1

clean:
	rm -f lab_v0 lab_v1
