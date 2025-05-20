## 1. Name, Student ID,  School

---

白宇辰, 313554005, NYCU

## 2. Spec

---

### 1. **測試環境**

本次實驗在 WSL2 + Ubuntu 環境下進行，使用的硬體與系統規格如下：

- **CPU 型號**：12th Gen Intel(R) Core(TM) i5-12400
- **實體核心數**：6 cores
- **執行緒數**：12 threads（每核心 2 執行緒）
- **架構**：x86_64，支援 64-bit 作業模式
- **L3 Cache**：18 MB，共享
- **虛擬化**：執行於 Microsoft Hypervisor 上（WSL2）
- **作業系統**：Ubuntu 22.04 LTS on WSL2

### 2. **編譯器與編譯選項**

- **Compiler**：`g++ (Ubuntu 11.4.0)`
- **Flags**：
    - `fopenmp`：啟用 OpenMP 支援
    - `O2`：最佳化
    - `std=c++11`：指定 C++11 標準

```
CC = g++
CFLAGS = -fopenmp -O2 -std=c++11
```

---

### 3. **其他調整**

- 使用 `Makefile` 管理專案編譯與執行
- 使用 `lab.sh` 腳本自動設定執行緒數與執行兩版本程式：

```bash
export OMP_NUM_THREADS=12
make
time make runv0
time make runv1
make clean
```

## 3. Result

---

### 1. Sequential 時，你跑的時間為何？最終結果為何（優化多少 %）？

根據 `result1.log` 中的數據：

- **原始版本 (lab_v0)** 執行時間為 `17.56 秒`
- **平行版本 (lab_v1, OMP_NUM_THREADS=1)** 執行時間為 `18.53 秒`

由於 `OMP_NUM_THREADS=1` 時與序列版幾乎一樣，因此我們以 **`lab_v0` 約 17.56 秒** 為 baseline。

平行化版本在 12 執行緒下（`result12.log`）為：

- **lab_v1 (OMP_NUM_THREADS=12)**：**5.36 秒**

計算效能提升比率：

$$
Speedup=17.565.36≈3.28×\text{Speedup} = \frac{17.56}{5.36} \approx 3.28 \times
$$

$$
效率提升=(1−5.3617.56)×100%≈69.5%\text{效率提升} = \left(1 - \frac{5.36}{17.56}\right) \times 100\% \approx 69.5\%
$$

**總結**：

- 原始版本：17.56 秒
- 最佳版本（12 threads）：5.36 秒
- 整體加速比：約 **3.28 倍**
- 執行時間減少：約 **69.5%**

---

### 2. Scalability：用不同 thread 的數量測試，你覺得一切如同預期嗎？為什麼？

以下是各執行緒數量的實測時間與加速比：

| Threads | Time (s) | Speedup |
| --- | --- | --- |
| 1 | 18.53 | 0.95× |
| 2 | 10.87 | 1.62× |
| 4 | 8.32 | 2.11× |
| 6 | 6.94 | 2.53× |
| 8 | 5.33 | 3.29× |
| 12 | 5.36 | 3.28× |

觀察結果：

- 加速效果 **符合預期**，尤其在 2～8 執行緒時呈現穩定提升。
- 不過從 8 到 12 執行緒，效能幾乎沒再提升，出現 **平行化瓶頸**。
- 可能原因：
    - 某些段落（如 `criticalFlux` 計算）無法平行化，成為瓶頸（Amdahl’s Law）
    - 記憶體頻寬競爭
    - 排程與工作分配不平均

**總結**：

- 漸進式加速良好，最佳效能約在 8 執行緒後趨緩
- 整體來看平行化達到預期目標，但仍有部分瓶頸段可再優化

---

## 4. Implementation

1. 在哪裡加了 #pragma？為此做了什麼改動？優化了多少？

---

### (1) 初始化 `velocity` 和 `pressure`

```cpp
#pragma omp parallel for
for (int i = 0; i < numParticles; i++) {
    velocity[i] = i * 1.0;
    pressure[i] = (numParticles - i) * 1.0;
}
```

- **原因**：這段操作對每個元素獨立，適合平行處理。
- **效益**：初始化大量資料，加速非常明顯。

---

### (2) 初始化 `energy`

```cpp
#pragma omp parallel for
for (int i = 0; i < numParticles; i++) {
    energy[i] = velocity[i] + pressure[i];
}
```

- **理由同上**，屬於資料獨立運算。
- **可視為初始化階段平行的延續**。

---

### (3) 計算 `fieldSum`（雙層巢狀迴圈）

```cpp
#pragma omp parallel for reduction(+ : fieldSum)
for (int r = 0; r < gridRows; r++) {
    for (int c = 0; c < gridCols; c++) {
        fieldSum += sqrt(r * 2.0) + log1p(c * 2.0);
    }
}
```

- **處理規模最大**，共 2.5B 次運算。
- 使用 `reduction(+ : fieldSum)` 來避免競爭。
- **這段是主要效能瓶頸之一，平行化效益最大。**

---

### (4) 累加 `atomicFlux`

```cpp
#pragma omp parallel for reduction(+ : atomicFlux)
for (int i = 0; i < numParticles; i++) {
    atomicFlux += velocity[i] * 0.000001;
}
```

- 屬於簡單向量積和。
- 雖然時間不長，但也能平行加速。

---

### (5) 統計總和：`sumVelocity`, `sumPressure`, `sumEnergy`

```cpp
#pragma omp parallel for reduction(+ : sumVelocity, sumPressure, sumEnergy)
for (int i = 0; i < numParticles; i++) {
    sumVelocity += velocity[i];
    sumPressure += pressure[i];
    sumEnergy += energy[i];
}
```

- 三個加總可一起平行處理。
- 同樣使用 `reduction` 避免資料競爭。

---

### 整體效益分析：

從 `OMP_NUM_THREADS=12` 結果可知，**總執行時間從 17.56 秒降到 5.36 秒，約提升 69.5% 效能**。

其中：

- `fieldSum` 占最大運算量，加速效果顯著
- 初始化、加總與能量運算都成功應用平行化

## 5.Experiment & Analysis

1. 為什麼認為 ... 這樣優化最好？其他跑出來的時間如何？相關解釋？

---

### 分析：

- 對於 **累加總和類型的問題**（如 `sumX += ...`），OpenMP 官方建議使用 `reduction` 而非 `atomic`。
- `#pragma omp atomic` 適用於 **極小範圍的寫入競爭**，但在大量迴圈中會因為頻繁進行記憶體同步造成效能下降。
- 在測試中，將 `atomicFlux` 與 `sumX` 等區段使用 `reduction` 效能會比 `atomic` 顯著更好。
- 部分區段（如 `criticalFlux`）因為存在跨次迴圈依賴，無法簡單平行化，也不能使用 `atomic` 或 `reduction`。

### 使用 `#pragma omp atomic` 的比較實驗

我嘗試將 `reduction` 改為 `#pragma omp atomic`，例如將：

```cpp
#pragma omp parallel for reduction(+ : atomicFlux)
    for (int i = 0; i < numParticles; i++) {
        atomicFlux += velocity[i] * 0.000001;
    }
```

改成

```cpp
#pragma omp parallel for
for (int i = 0; i < numParticles; i++) {
    #pragma omp atomic
    atomicFlux += velocity[i] * 0.000001;
}
```

實測後，在 12 執行緒下執行時間為 **5.75 秒**，相比 `reduction` 版本的 **5.36 秒**，慢了約 **7.3%**。

**分析：**

- `atomic` 會在每一次寫入時加鎖，導致執行緒間的同步開銷變大。
- 對於這種大量累加的場合，`reduction` 讓每個 thread 保有自己的局部暫存變數，在最後再合併，效能更佳。
- 雖然 `atomic` 可以保證正確性，但對效能較敏感的區段並不建議使用。

**結論：**

實驗結果驗證了理論上的推論——在大量加總的平行區段中，`reduction` 明顯優於 `atomic`。

## 6. 其他補充

---

這次實作讓我學到了多種平行化的技巧與工具

### 1. **平行化方式的選擇會明顯影響效能**

- 使用 `#pragma omp parallel for reduction(...)` 在處理大規模資料累加時，效能遠優於 `atomic` 或 `critical`。
- `reduction` 能讓每個 thread 使用區域變數累積，最後再合併，效率高。
- 而 `atomic` 雖然也能避免資料競爭，但每次存取都會有鎖的開銷，在密集迴圈中效果差。

### 2. **工具與觀察**

- 學會使用 `lscpu` 了解 CPU 架構
- 設定 `OMP_NUM_THREADS`、觀察 `user/real/sys` 等指標，幫助我定位效能變化與執行時間差異來源
