#!/bin/bash 

export OMP_NUM_THREADS=12

make
make run
make clean
