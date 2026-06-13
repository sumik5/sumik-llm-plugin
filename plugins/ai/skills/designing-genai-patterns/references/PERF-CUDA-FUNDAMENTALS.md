# PERF-CUDA-FUNDAMENTALS

GPUアーキテクチャ・CUDAプログラミング・Occupancy最大化・メモリアクセスパターン最適化・Rooflineモデルの基礎知識。

---

## 1. GPUアーキテクチャ概要

### SIMT実行モデル

GPUはスループット最適化プロセッサ。CPUが低レイテンシ単一スレッド性能を重視するのに対し、GPUは数千スレッドを並列実行する。

**Streaming Multiprocessor (SM)**

| 要素 | Blackwell B200値 |
|------|-----------------|
| SM当たり最大ワープ数 | 64ワープ（2,048スレッド） |
| SM当たり最大スレッド数 | 2,048 |
| SM当たり最大アクティブブロック数 | 32 |
| SM当たりレジスタ | 64K個（256 KB） |
| SM当たり共有メモリ | 最大228 KB（227 KB使用可能） |
| ワープスケジューラ数 | 4（dual-issue対応） |

**ワープ（Warp）**
- 32スレッドがSIMTで一括実行される単位
- ワープスケジューラが毎サイクル最大4ワープを選択して命令発行
- dual-issue: 同一ワープから算術命令 + メモリ命令を同時発行可能

### スレッド階層

```
グリッド (Grid)
  └─ スレッドブロック (Thread Block / CTA): 最大1,024スレッド
       └─ ワープ (Warp): 32スレッド（SIMTで実行）
            └─ スレッド (Thread): カーネル関数の実行単位
```

**Thread Block Cluster（Hopper/Blackwell以降）**
- 複数スレッドブロックがSM間で共有メモリ（DSMEM）を介して通信
- クラスター内のブロック同士が `cluster.sync()` で同期可能
- DSMEM: クラスター内の全SMの共有メモリを統合したアドレス空間

**ワープダイバージェンス**
- 同一ワープ内のスレッドが異なる分岐パスを実行すると逐次化が発生
- if-elseで50/50分岐 → ワープ実効スループット50%低下
- 異なるワープ間の分岐はペナルティなし

---

## 2. CUDAプログラミング基礎

### カーネル定義と起動

```cpp
// カーネル定義: __global__ で修飾
__global__ void myKernel(float* input, int N) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < N) {          // 境界チェック必須
        input[idx] *= 2.0f;
    }
}

// カーネル起動
int N = 1'000'000;
int threadsPerBlock = 256;   // 32の倍数を選ぶ
int blocksPerGrid = (N + threadsPerBlock - 1) / threadsPerBlock;

myKernel<<<blocksPerGrid, threadsPerBlock>>>(d_input, N);
cudaDeviceSynchronize();     // エラー検出のため同期必須
```

**データフロー**
1. `cudaMallocHost()` でピン留めホストメモリ確保
2. `cudaMalloc()` でデバイスメモリ確保
3. `cudaMemcpy(H→D)` でデータ転送
4. カーネル実行（非同期）
5. `cudaDeviceSynchronize()` で同期
6. `cudaMemcpy(D→H)` で結果取得
7. `cudaFree()` / `cudaFreeHost()` でメモリ解放

**非同期メモリ管理（推奨）**
```cpp
// ストリームごとに非同期アロケーション
cudaMallocAsync(&ptr, size, stream);
cudaFreeAsync(ptr, stream);

// メモリプールのリリース閾値設定
cudaMemPool_t pool;
cudaDeviceGetDefaultMemPool(&pool, device);
uint64_t threshold = totalGlobalMem / 2;
cudaMemPoolSetAttribute(pool, cudaMemPoolAttrReleaseThreshold, &threshold);
```

### 互換性モデル（PTX / SASS）

| 概念 | 内容 |
|------|------|
| PTX | 仮想アーキテクチャ用中間表現、前方互換性あり |
| SASS | GPUアーキテクチャ固有のネイティブアセンブリ |
| fatbin | PTX + 複数アーキテクチャのSASS を含むバイナリ |

- forward互換性確保: `CUDA_FORCE_PTX_JIT=1` でPTX JITコンパイルを強制テスト
- アーキテクチャ固有最適化（`sm_100f`等）は移植性を下げる

---

## 3. Occupancy最大化

Occupancy = SM上のアクティブワープ数 ÷ 最大ワープ数（64）

### ブロックサイズ選択の原則

| 推奨事項 | 理由 |
|---------|------|
| ブロックサイズは32の倍数 | 未充填ワープがスケジューラスロットを無駄に消費するのを防ぐ |
| 256〜512スレッド/ブロックが基本 | レジスタ・共有メモリ消費とOccupancyのバランス |
| 大きすぎるブロックは避ける | レジスタスピル、共有メモリ超過のリスク |

**SM-residentリソース制限（Blackwell B200）**

| リソース | 制限値 |
|---------|-------|
| 最大resident warps/SM | 64 |
| 最大resident threads/SM | 2,048 |
| 最大active blocks/SM | 32 |
| 最大registers/thread | 255 |
| 最大shared memory/SM | 228 KB |

### Occupancy API

```cpp
int minGridSize = 0, bestBlockSize = 0;
size_t dynSmemBytes = 0; // 動的共有メモリのバイト数

cudaOccupancyMaxPotentialBlockSize(
    &minGridSize, &bestBlockSize,
    myKernel,
    dynSmemBytes,
    /* blockSizeLimit = */ 0);

// N要素をカバーするグリッドサイズ
int gridSize = std::max(minGridSize, (N + bestBlockSize - 1) / bestBlockSize);
myKernel<<<gridSize, bestBlockSize, dynSmemBytes>>>(...);
```

```cpp
// レジスタ数上限を指定（Occupancy向上のトレードオフ）
__launch_bounds__(256, 4)  // 最大256スレッド/ブロック、SM当たり最低4ブロック
__global__ void myKernel(...) { ... }
```

> **注意**: Occupancy最大化 ≠ 最高性能。Nsight Computeの "Registers Per Thread" と "Occupancy" メトリクスで実測して確認する。

---

## 4. Rooflineモデル

### 算術強度（Arithmetic Intensity）

```
算術強度 = FLOP数 / グローバルメモリ転送バイト数 (FLOPs/byte)
```

**Blackwellの例**
- ピーク演算性能: ~80 TFLOPS (FP32)
- ピークHBM帯域幅: ~8 TB/s
- Ridge Point: 80÷8 = **10 FLOPs/byte**

| カーネルの状態 | 判断基準 |
|--------------|---------|
| メモリバウンド | 算術強度 < Ridge Point → 帯域幅がボトルネック |
| コンピュートバウンド | 算術強度 > Ridge Point → ALUがボトルネック |

**例: 浮動小数点加算カーネル**
- 2 float load (8B) + 1 add + 1 float write (4B) = 1 FLOP / 12 B = 0.083 FLOPs/byte
- → 強くメモリバウンド（Ridge Pointの100倍以上左）

### 精度変換による算術強度向上

| データ型 | バイト/値 | 対FP32比 |
|---------|----------|--------|
| FP32 | 4 B | 1× |
| FP16/BF16 | 2 B | 2×帯域削減 |
| FP8 | 1 B | 4×帯域削減 |
| FP4 | 0.5 B | 8×帯域削減（Blackwell） |

---

## 5. メモリ階層とアクセスパターン

### GPU メモリ階層

```
レジスタ    (~数ns, per-thread)
   ↓
L1/共有メモリ (~数ns, per-SM, 最大228KB on Blackwell)
   ↓
L2キャッシュ  (~数十ns, GPU全体)
   ↓
グローバルメモリ/HBM (~数百ns, ~8 TB/s on Blackwell)
   ↓
ホストメモリ (PCIe/NVLink経由, ~数ms)
```

### メモリCoalescing（結合アクセス）

ワープ内32スレッドが連続アドレスにアクセスすると、1回のメモリトランザクション（128B）で処理される。

```cpp
// ✅ 結合アクセス: thread_idx が連続アドレスを参照
float val = data[threadIdx.x + blockDim.x * blockIdx.x];

// ❌ 非結合アクセス: ストライドが大きいと複数トランザクション発生
float val = data[(threadIdx.x + blockDim.x * blockIdx.x) * 32];
```

**Nsightでの診断**
- `Stall: Long Scoreboard` → HBMからのデータ待ち（メモリバウンドの典型）
- `Stall: Short Scoreboard` → 共有メモリ↔レジスタ転送待ち
- `Stall: Memory Throttle` → ロード/ストアパイプラインが飽和

---

## 6. 共有メモリとBank Conflict

### 共有メモリの特性

- SM当たり最大228 KB（Blackwell）
- 32バンク × 4バイト幅 → 32スレッドが同時に別バンクへアクセス可能
- 同一バンクへの複数アクセス → バンクコンフリクト（逐次化）

### バンクコンフリクトの解決

**問題例（32-way conflict）**

```cpp
__shared__ float tile[32][32];
// tile[threadIdx.y][threadIdx.x] でwrite (OK: 結合)
// tile[threadIdx.x][threadIdx.y] でread → 32-way conflict!
```

**解決策1: Padding**

```cpp
#define PAD 1
__shared__ float tile[32][32 + PAD]; // 各行に1要素追加
// 効果: バンクコンフリクト0、~3%メモリオーバーヘッド
```

**解決策2: Swizzling**
- インデックスをXORや剰余演算で変換して各スレッドが別バンクにマップ
- パディングより実装が複雑だが、メモリオーバーヘッドゼロ

**Before/After比較**

| メトリクス | Before（パディングなし） | After（パディングあり） |
|----------|----------------------|---------------------|
| 共有メモリbank conflicts | 4.8 million | 0 |
| 共有メモリ使用率 | 52% | 100% |
| Warpストール率（メモリ） | 38% | 0.5% |
| カーネル実行時間 | 4 ms | 1.3 ms（3×改善） |

### Warp Shuffle Intrinsics

共有メモリを使わずワープ内でデータ交換（バンクコンフリクト不可能）。

```cpp
// ワープ内リダクション（ butterfly方式）
unsigned mask = __activemask();
float val = threadVal;
for (int offset = 16; offset > 0; offset >>= 1) {
    float other = __shfl_down_sync(mask, val, offset);
    val += other;
}
// lane 0 が合計値を保持
```

| Shuffle関数 | 動作 |
|------------|------|
| `__shfl_sync` | 特定レーンの値をブロードキャスト |
| `__shfl_down_sync` | 上位レーンの値を取得（リダクションに使用） |
| `__shfl_xor_sync` | XORパターンで値を交換 |

---

## 7. Warpダイバージェンス最適化

### ワープ実行効率（Warp Execution Efficiency）

Nsight Computeで計測。30%なら70%のスレッドが無駄に待機。

### ダイバージェンス回避テクニック

**1. データ構造の再配置**
- 同一ワープが均質なデータを処理するようにソート/パーティショニング

**2. ワープ単位で分岐（Warp-unanimous）**
```cpp
int warpId = threadIdx.x / 32;
if (warpId % 2 == 0) { /* Task A */ }  // 1ワープ = 1分岐方向
else              { /* Task B */ }
```

**3. Predication（短い分岐のみ有効）**
```cpp
// ❌ 分岐あり（ダイバージェンス発生）
if (X[i] > threshold) Y[i] = X[i]; else Y[i] = 0.0f;

// ✅ Predication（分岐なし）
float cond = X[i] > threshold ? 1.0f : 0.0f;
Y[i] = cond * X[i];  // 全スレッドが同じ命令を実行
```

**4. Warp Vote Intrinsics**
```cpp
// ワープ内での投票
uint32_t ballot = __ballot_sync(0xFFFFFFFF, condition);  // ビットマスク
bool any_true = __any_sync(0xFFFFFFFF, condition);
bool all_true = __all_sync(0xFFFFFFFF, condition);
```

---

## 8. 算術強度向上テクニック（Ch.9）

### マルチレベルタイリング

```
グローバルメモリ → 共有メモリ（タイル）→ レジスタ（マイクロタイル）
```
- 32×32タイル → 各バイトが1,024回再利用（算術強度大幅向上）
- `float4`・`half2` などベクトル型でレジスタレベル再利用

### カーネルフュージョン

```python
# ❌ 2カーネル: 中間データがグローバルメモリ経由
y = sin(x)
z = sqrt(y)

# ✅ フュージョン: 中間データがレジスタに留まる
z[i] = sqrt(sin(x[i]))  # メモリトラフィック半減
```

### Thread Block Clustersによるタイリング（Hopper/Blackwell）

- 2×2クラスター（4ブロック）でTMAマルチキャストを使いタイルを1回だけロード
- グローバルメモリトラフィックを最大4×削減（16クラスターなら最大16×）

### 混合精度とTensor Core

```python
# PyTorch: TF32/BF16でTensor Core活用
torch.set_float32_matmul_precision('high')  # TF32有効化
# または
with torch.cuda.amp.autocast():             # FP16自動混合精度
    output = model(input)
```

| Tensor Coreへのアクセス方法 | 内容 |
|---------------------------|------|
| PyTorch `torch.matmul` / `torch.nn.functional.scaled_dot_product_attention` | 自動でTensor Core使用 |
| CUTLASS | 高性能GEMM/融合カーネルテンプレートライブラリ |
| `wmma` API | C++でTensor Coreに直接アクセス |
| `tcgen05` (Blackwell) | TMEM（Tensor Memory）と組み合わせたネイティブ命令 |

### インラインPTX（高度なマイクロ最適化）

```cpp
// L2キャッシュへのプリフェッチ（L1バイパス）
asm volatile("cp.async.bulk.prefetch.L2.global [%0], %1;"
             :: "l"(in + idx + 32), "n"(128));

// SM IDの取得（高レベルAPIなし）
unsigned smid;
asm("mov.u32 %0, %smid;" : "=r"(smid));
```

> PTXはアーキテクチャをまたいで比較的安定。SASSはアーキテクチャ間で変わるため注意。

---

## 9. デバッグ・プロファイリングツール

### NVIDIA Compute Sanitizer

```bash
compute-sanitizer [--tool toolname] [options] <application>
```

| ツール | 検出対象 |
|-------|---------|
| `memcheck` | 範囲外アクセス、デバイスヒープリーク |
| `racecheck` | 共有メモリのデータレース（WAW, WAR, RAW） |
| `initcheck` | 未初期化グローバルメモリへのアクセス |
| `synccheck` | バリア不整合によるデッドロック |

CI統合: `--error-exitcode` でエラー時に非ゼロ終了

### Nsight Systems / Nsight Compute

| ツール | 用途 |
|-------|------|
| Nsight Systems (`nsys`) | システム全体のタイムライン、CPU-GPUオーバーラップ確認 |
| Nsight Compute (`ncu`) | カーネルごとの詳細メトリクス、Roofline分析 |

**典型的ワークフロー**
1. Nsight Systemsでホットカーネルを特定
2. Nsight Computeで対象カーネルを深堀り
3. Warp Stall Reasonsで最大のストール要因を特定
4. 最適化実施 → 再プロファイルで効果確認

**Warp Stall Reasonsまとめ**

| ストール種別 | 意味 | 対策 |
|------------|------|------|
| Long Scoreboard | グローバルメモリロード待ち | より多くのワープ（Occupancy向上）、TMA非同期コピー |
| Short Scoreboard | 共有メモリ↔レジスタ転送待ち | バンクコンフリクト解消 |
| Memory Throttle | ロード/ストアパイプライン飽和 | アクセスパターン改善、ILP増加 |
| Exec Dependency | 命令間依存（ALUレイテンシ） | ILP向上（独立命令の増加）、ループアンロール |
| Compute Unit Busy | ALU/Tensor Coreが飽和 | コンピュートバウンド → 正常（精度削減で更に向上可） |
| Not Selected | スケジューラが別ワープを選択 | 通常は問題なし（高Occupancyの証拠） |

---

## 10. PyTorchとの対応関係

| CUDA技術 | PyTorchでの相当手段 |
|---------|-------------------|
| threadsPerBlock最適化 | `torch.compile(mode="max-autotune")` |
| カーネルフュージョン | TorchInductor（`torch.compile`）が自動実行 |
| 混合精度 | `torch.cuda.amp.autocast()` |
| Tensor Core | `torch.matmul`, `F.scaled_dot_product_attention` |
| 非同期メモリ | `DataLoader(pin_memory=True)` |
| Occupancy調整 | `torch.optim.AdamW(fused=True)` などのfused実装 |

> PyTorchの組み込み演算は既にTensor CoreやCoalescing最適化が適用済み。カスタムカーネルを書く場合のみ手動チューニングが必要。
