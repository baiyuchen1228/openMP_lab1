#include <omp.h>

#include <cmath>
#include <cstdlib>
#include <ctime>
#include <iostream>
#include <vector>

using namespace std;

int main() {
    srand(42);

    // init
    // ------------------------
    const int numParticles = 10000000;
    const int gridRows = 50000;
    const int gridCols = 50000;

    // main array：velocity, pressure, energy
    vector<double> velocity(numParticles), pressure(numParticles), energy(numParticles);

    // init velocity and pressure
    for (int i = 0; i < numParticles; i++) {
        velocity[i] = i * 1.0;
        pressure[i] = (numParticles - i) * 1.0;
    }

    for (int i = 0; i < numParticles; i++) {
        energy[i] = velocity[i] + pressure[i];
    }
    for (int i = 0; i < numParticles; i++) {
        double work = 0.0;
        int loops = (i % 10) * 10 + 10;  // 10, 20, ..., 100
        for (int j = 0; j < loops; j++) {
            work += sin(j * 0.01);
        }
        // update velocity
        velocity[i] = sin(energy[i]) + log(1 + fabs(work));
    }

    double fieldSum = 0;
    for (int r = 0; r < gridRows; r++) {
        for (int c = 0; c < gridCols; c++) {
            fieldSum += sqrt(r * 2.0) + log1p(c * 2.0);
        }
    }

    // ------------------------
    double atomicFlux = 0.0;
    for (int i = 0; i < numParticles; i++) {
        atomicFlux += velocity[i] * 0.000001;
    }

    // criticalFlux：complex logic
    double criticalFlux = 0.0;
    for (int i = 0; i < numParticles; i++) {
        // cal temp val
        double tempVal = sqrt(fabs(energy[i])) / 100.0;
        double extraVal = log(1 + fabs(velocity[i])) * 0.01;

        double oldValue = criticalFlux;
        // 如果 oldValue < 500，就用第一種方式計算 否則第二種
        if (oldValue < 500.0) {
            criticalFlux = oldValue + tempVal + extraVal;
        } else {
            criticalFlux = oldValue + sqrt(tempVal) - extraVal;
        }
    }

    // 6) print result to check correctness
    // ------------------------
    double sumVelocity = 0.0;
    double sumPressure = 0.0;
    double sumEnergy = 0.0;

    for (int i = 0; i < numParticles; i++) {
        sumVelocity += velocity[i];
        sumPressure += pressure[i];
        sumEnergy += energy[i];
    }

    // ------------------------
    cout << "=== result ===" << endl;
    // energy
    cout << "fieldValue      = " << fieldSum << endl;
    cout << "energy[0]       = " << energy[0] << endl;
    // sum
    cout << "Sum(velocity)   = " << sumVelocity << endl;
    cout << "Sum(pressure)   = " << sumPressure << endl;
    cout << "Sum(energy)     = " << sumEnergy << endl;
    // flux
    cout << "atomicFlux      = " << atomicFlux << endl;
    cout << "criticalFlux    = " << criticalFlux << endl;

    return 0;
}
