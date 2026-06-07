# PERF-CUDA-ADVANCED

イントラカーネルパイプライン・Warp Specialization・CUDAストリーム・CUDAグラフ・動的並列処理の高度なCUDA最適化技術。

---

## 1. イントラカーネルパイプライン

### 非同期コピー（cp.async）

カーネル実行中にグローバルメモリ→共有メモリのコピーをバックグラウンドで実行する仕組み。CUDAのPipeline APIで抽象化。

```cpp
#include <cuda/pipeline>

// スレッドブロックスコープのパイプライン
__shared__ cuda::pipeline_shared_state<cuda::thread_scope_block, 2> pipe_state;
auto pipe = cuda::make_pipeline(this_thread_block(), &pipe_state);

// プロデューサー: 非同期コピーをキューに追加
pipe.producer_acquire();
cuda::memcpy_async(warp, smem_tile, global_ptr, tile_bytes, pipe);
pipe.producer_commit();

// コンシューマー: コピー完了を待ってから処理
pipe.consumer_wait();
// ... shared memoryを使った計算 ...
pipe.consumer_release();
```

### ダブルバッファリング（2段パイプライン）

現在のタイルを計算しながら、次のタイルをプリフェッチする。

```
時刻T:   [タイルN: 計算]  [タイルN+1: ロード中]
時刻T+1: [タイルN+1: 計算] [タイルN+2: ロード中]
```

**効果**
- グローバルメモリのレイテンシを計算で隠蔽
- 命令数: ナイーブ実装比 -38%
- L2スループット: ナイーブ比 +94%

---

## 2. Warp Specialization

### プロデューサー/コンシューマーモデル

1ブロック内のワープをロール（役割）で分割し、各ワープが専用の仕事を繰り返す。

```cpp
__global__ void warp_specialized(const float* A, const float* B, float* C) {
    extern __shared__ float smem[];
    int warp_id = threadIdx.x / 32;

    // ローダーワープ(0): グローバルメモリ→共有メモリへ非同期コピー
    if (warp_id == 0) {
        // cp.async で次のタイルをプリフェッチ
        cuda::memcpy_async(warp, smem, A_tile, bytes, pipe);
        pipe.producer_commit();
    }
    // コンピュートワープ(1): タイルを消費して演算
    else if (warp_id == 1) {
        pipe.consumer_wait();
        // ... matmul計算 ...
        pipe.consumer_release();
    }
    // ストアワープ(2): 結果をグローバルメモリへ書き出し
    else if (warp_id == 2) {
        // 結果ストア
    }
}
```

### ナイーブ→2段パイプライン→Warp Specialization比較

| 手法 | 命令数 | L2スループット | 適切なユースケース |
|------|--------|--------------|-----------------|
| ナイーブタイリング | 1.70 B | 80 GB/s | 基本的なGEMM |
| 2段ダブルバッファ | 1.05 B（-38%） | 155 GB/s（+94%） | 均一タイルGEMM |
| Warp Specialization | 1.00 B（+4.8%追加削減） | 165 GB/s | Fused Attention, 不規則パイプライン |

> **注**: FlashAttention-3でもピークFP16 FLOPSの約75%にとどまる。100%を目指す必要はない。

### PyTorchとの対応

```python
# torch.compileが自動的にwarp specializationを生成
context = torch.nn.functional.scaled_dot_product_attention(q, k, v)

# ローダー/コンピュート/ストアワープが内部で自動的に分離
# 明示的なCUDA C++コードは不要
```

---

## 3. Persistent Kernelとメガカーネル

### Persistent Kernel

短命な小カーネルを何度も起動する代わりに、1つの長寿命カーネルがデバイス側タスクキューからワークをポーリングする。

```cpp
__device__ int g_task_index = 0;  // デバイス側カウンタ

__global__ void persistentKernel(Task* tasks, int totalTasks) {
    while (true) {
        int idx = atomicAdd(&g_task_index, 1);
        if (idx >= totalTasks) break;
        processTask(tasks[idx]);
    }
}

// 起動: 1 block/SM で全SMをカバー
int numSMs = deviceProp.multiProcessorCount;
cudaMemset(&g_task_index, 0, sizeof(int));
persistentKernel<<<numSMs, 256>>>(d_tasks, totalTasks);
```

**ユースケース**

| 向いているケース | 向いていないケース |
|---------------|-----------------|
| 多数の小タスク（起動オーバーヘッド削減） | 大きな均一タスク（通常起動で十分） |
| 不均一なタスクサイズ（動的ロードバランス） | 短命カーネル（常駐コストが高い） |
| グラフトラバーサル、per-tokenLLM推論 | 別ワークロードと共存が必要な場合 |

**オーバーヘッド比較（例: 1,000タスク）**

| 方式 | 起動オーバーヘッド | SMアクティブ率 |
|------|---------------|-------------|
| 1,000個の小カーネル | 20 ms（×1,000） | ~35% |
| Persistent Kernel | 0.02 ms（×1） | ~100% |

### メガカーネル

Persistent Kernelを複数GPU・複数レイヤーに拡張。1つの大カーネルがシーケンシャルな操作全体をフュージョン。

- LLM推論での効果: レイテンシ 1.2〜6.7×削減（per-layer起動比）
- TMAを使って次のタスクをプリフェッチしつつ現タスクを計算

---

## 4. Cooperative Groups

スレッドをグループ化して柔軟な粒度でsync・collective操作が可能。

```cpp
#include <cooperative_groups.h>
namespace cg = cooperative_groups;

__global__ void myKernel() {
    auto tb = cg::this_thread_block();  // ブロック全体
    auto warp = cg::tiled_partition<32>(tb);  // ワープ

    // ワープ内リダクション
    float val = threadVal;
    val = cg::reduce(warp, val, cg::plus<float>());

    // ブロック同期
    tb.sync();

    // グリッドレベル同期（cooperative launch必須）
    auto grid = cg::this_grid();
    grid.sync();
}
```

**Cooperative Groupの階層**

| グループ種別 | API | スコープ |
|------------|-----|---------|
| `thread_block` | `this_thread_block()` | ブロック |
| Warpタイル | `tiled_partition<32>(tb)` | ワープ |
| `cluster_group` | `this_cluster()` | クラスター（複数SM） |
| `grid_group` | `this_grid()` | グリッド全体 |

---

## 5. Thread Block Clustersと分散共有メモリ

### Thread Block Cluster（CTA Cluster）

複数のThread BlockをSM間でグループ化。DSMEM（Distributed Shared Memory）で相互の共有メモリに直接アクセス。

```cpp
// クラスターサイズの指定
cudaLaunchAttribute attr;
attr.id = cudaLaunchAttributeClusterDimension;
attr.val.clusterDim = dim3(4, 1, 1);  // 4ブロック/クラスター

// クラスター内のブロックがDSMEMを共有
cluster_group cluster = this_cluster();
float* remote_smem = cluster.map_shared_rank(local_smem, 0);  // leader blockのSMEMを参照
cluster.sync();  // クラスター全体で同期
```

### TMAマルチキャスト（Tensor Memory Accelerator）

```cpp
// leader blockが1度ロード → クラスター全体に配布
// 4ブロッククラスターでグローバルメモリトラフィックを1/4に削減
cuda::memcpy_async(warp, A_tile_local, A_global + offset, bytes, pipe);
// cluster.sync() 後、全ブロックがleaderのSMEMを参照可能
```

**クラスターサイズによる削減効果**

| クラスターサイズ | グローバルメモリ削減率 |
|---------------|---------------------|
| 2 CTA | 2× |
| 4 CTA (2×2) | 4× |
| 8 CTA | 8× |
| 16 CTA（非ポータブル） | 16×（`cudaFuncAttributeNonPortableClusterSizeAllowed`必要） |

---

## 6. CUDAストリームとイベント

### CUDAストリームによる並列化

```cpp
// Non-blockingストリームを使うことが重要
cudaStream_t stream1, stream2;
cudaStreamCreateWithFlags(&stream1, cudaStreamNonBlocking);
cudaStreamCreateWithFlags(&stream2, cudaStreamNonBlocking);

// 3-way overlap: stream0=計算, stream1=H2D, stream2=D2H
cudaMemcpyAsync(d_data1, h_data1, bytes, cudaMemcpyHostToDevice, stream1);
computeKernel<<<grid, block, 0, stream1>>>(d_data1, d_result1);
cudaMemcpyAsync(h_result1, d_result1, bytes, cudaMemcpyDeviceToHost, stream1);

// stream2も並行して動く
cudaMemcpyAsync(d_data2, h_data2, bytes, cudaMemcpyHostToDevice, stream2);
computeKernel<<<grid, block, 0, stream2>>>(d_data2, d_result2);

cudaStreamSynchronize(stream1);
cudaStreamSynchronize(stream2);
```

**重要な前提条件**
- ホストポインタは必ず**ピン留めメモリ**（`cudaMallocHost`）を使用
- `cudaMemcpyAsync`がpageable memoryを渡すとステージングコピーで非同期性が失われる

### CUDAイベント（GPU間・ストリーム間同期）

```cpp
cudaEvent_t event;
cudaEventCreateWithFlags(&event, cudaEventDisableTiming);  // タイミング不要なら軽量版

// stream0での処理完了をeventに記録
cudaEventRecord(event, stream0);

// stream1がeventを待機してから次の処理へ
cudaStreamWaitEvent(stream1, event, 0);
```

### ストリーム順序付きメモリアロケーター

```cpp
// 非推奨: 全ストリームをブロックする
cudaMalloc(&ptr, size);    // グローバル同期発生

// 推奨: ストリームにエンキューされるだけで他ストリームをブロックしない
cudaMallocAsync(&ptr, size, stream);
cudaFreeAsync(ptr, stream);

// PyTorchで有効化
// PYTORCH_CUDA_ALLOC_CONF=backend:cudaMallocAsync python train.py
```

**メモリプール設定**

```cpp
cudaMemPool_t pool;
cudaDeviceGetDefaultMemPool(&pool, device);
uint64_t threshold = totalGlobalMem / 2;  // OS返却前に保持するバイト数
cudaMemPoolSetAttribute(pool, cudaMemPoolAttrReleaseThreshold, &threshold);
```

### Multi-GPU通信パターン

```cpp
// GPUDirect Peer: GPU間の直接メモリコピー（CPUバイパス）
cudaMemcpyPeerAsync(dest, dest_gpu, src, src_gpu, size, comm_stream);

// MPI + GPUDirect RDMA（CUDA-aware MPI）
MPI_Send(device_buf, count, MPI_FLOAT, peer_rank, ...);  // NVLinkまたはInfiniBand経由

// NCCLによる非同期Collective
ncclAllReduce(src, dst, count, ncclFloat, ncclSum, comm, stream);
```

---

## 7. CUDAグラフ

### CUDAグラフの仕組み

複数のカーネル・メモリコピーをGPU上の依存グラフとして事前に記録し、CPUの都度介入なしに1コマンドで再実行する。

**効果**

| メトリクス | CUDAグラフなし | CUDAグラフあり |
|----------|-------------|-------------|
| CPU launch calls（100回） | 300回（カーネルごと） | 100回（`g.replay()`） |
| カーネル間GPU idle | ~3 µs/iteration | 0 µs |
| 反復レイテンシ | ~1.00 ms | ~0.75 ms（25%削減） |

### CUDA C++でのグラフキャプチャ

```cpp
cudaGraph_t graph;
cudaGraphExec_t instance;
cudaStream_t stream;
cudaStreamCreateWithFlags(&stream, cudaStreamNonBlocking);

// 1. キャプチャ開始
cudaStreamBeginCapture(stream, cudaStreamCaptureModeGlobal);

// 2. 通常通り操作をエンキュー
kernelA<<<grid, block, 0, stream>>>(d_X);
kernelB<<<grid, block, 0, stream>>>(d_Y);
kernelC<<<grid, block, 0, stream>>>(d_Z);

// 3. キャプチャ終了
cudaStreamEndCapture(stream, &graph);
cudaGraphInstantiate(&instance, graph, nullptr, nullptr, 0);

// 4. 繰り返し再実行（1コマンドで）
for (int iter = 0; iter < 100; ++iter) {
    cudaGraphLaunch(instance, stream);
}
cudaStreamSynchronize(stream);

// 5. クリーンアップ
cudaGraphExecDestroy(instance);
cudaGraphDestroy(graph);
```

### PyTorchでのCUDAグラフ

```python
import torch

# 静的バッファ（アドレス固定が必須）
static_x = torch.empty_like(X)
static_y = torch.empty_like(X)
static_z = torch.empty_like(X)

# ウォームアップ（ライブラリ初期化のため必須）
_ = torch.sqrt(torch.sin(X))
torch.cuda.synchronize()

# グラフキャプチャ
static_x.copy_(X)
g = torch.cuda.CUDAGraph()
with torch.cuda.graph(g):
    torch.sin(static_x, out=static_y)
    torch.sqrt(static_y, out=static_z)

# 高速リプレイ（入力変更時はstatic_xにコピー）
for i in range(100):
    # static_x.copy_(new_X)  # 入力更新が必要な場合
    g.replay()
```

**注意事項（CUDAグラフのNG操作）**

| NG操作 | 理由 |
|-------|------|
| キャプチャ内でのメモリアロケーション | アドレス固定が壊れる |
| `print()` / RNG呼び出し | 非決定的操作 |
| Nested capture | 未サポート |
| 入力テンソルの再アロケーション | グラフのポインタが無効化 |

**メモリプール（ポインタ安定性の確保）**

```python
# PyTorchのグラフ専用メモリプール
pool = torch.cuda.graph_pool_handle()
g = torch.cuda.CUDAGraph()
with torch.cuda.graph(g, pool=pool):
    ...
```

### 動的グラフ更新

```cpp
// バッチサイズなど一部パラメータが変わる場合: 再キャプチャ不要
cudaGraphExecUpdate(instance, new_graph, &result_info);

// 個別ノードのパラメータ更新
cudaKernelNodeParams params;
// ... params設定 ...
cudaGraphExecKernelNodeSetParams(instance, node, &params);
```

> 変更可能: グリッド/ブロック次元, ポインタアドレス, カーネルパラメータ
> 変更不可: ノードの追加/削除（エラーになり再キャプチャ必要）

### デバイス起動CUDAグラフ（Device-Initiated）

GPUカーネルからCUDAグラフをデバイス側で直接起動（CPU介入ゼロ）。

```cpp
// ホストでグラフをインスタンス化（専用APIで）
cudaGraphDeviceNode_t deviceNode;
cudaGraphInstantiateWithFlags(&instance, graph,
                               cudaGraphInstantiateFlagDeviceLaunch);

// カーネル内からグラフ起動
__global__ void parentKernel(cudaGraphExec_t graph) {
    if (threadIdx.x == 0) {
        cudaGraphLaunch(graph, cudaStreamGraphFireAndForget);
    }
}
```

---

## 8. 動的並列処理（Dynamic Parallelism）

カーネルがデバイス側から子カーネルを起動する機能。CPU介入なしでGPU上で動的にワークを分割。

**コンパイル要件**: `-rdc=true`（Relocatable Device Code）

```cpp
// 子カーネル
__global__ void childKernel(float* data, int n) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < n) data[idx] *= data[idx];
}

// 親カーネルがデバイス側で子を起動
__global__ void parentKernel(float* data, int n) {
    if (blockIdx.x == 0 && threadIdx.x == 0) {
        int half = n / 2;
        // デバイス側から子カーネルを起動（CPUに戻らない）
        childKernel<<<(half+255)/256, 256>>>(data,        half);
        childKernel<<<(half+255)/256, 256>>>(data + half, n - half);
        // 親カーネルは全子が完了するまで終了しない
    }
}
```

**ホスト駆動 vs デバイス駆動の比較**

| メトリクス | ホスト駆動 | デバイス駆動（DP） |
|----------|----------|----------------|
| 総ホスト起動回数 | 3回（parent+2 children） | 1回（parent only） |
| GPU idle（シーケンス中） | ~40% | ~5% |
| 全体実行時間 | 1.00 ms | 0.75 ms（25%削減） |

**適切なユースケース**

- グラフトラバーサル（深さ優先探索など）
- アダプティブ計算（実行時に作業量が決まる）
- 不規則なサブプロブレムの並列分解

> **注**: DP起動オーバーヘッドはホスト起動と同程度（~20〜25 µs）。小さなカーネルに使うと逆効果になることも。必ずプロファイルで確認。

---

## 9. マルチGPU協調（NVSHMEM）

GPU間でPartitioned Global Address Space（PGAS）を共有し、デバイスコードから直接リモートGPUメモリへ読み書き。

```cpp
// 送信GPU: デバイスコードからリモートGPUへ直接プット
nvshmem_float_p(remote_data + 1, value, dest_pe);  // dest_peのメモリへ書き込み
nvshmem_quiet();                                     // 書き込み完了を保証
nvshmem_int_p(remote_flag + 0, 1, dest_pe);         // 完了フラグを立てる

// 受信GPU: フラグをスピン待機
nvshmem_int_wait_until(remote_flag + 0, NVSHMEM_CMP_EQ, 1);
```

**通信レイテンシ（NVLink < PCIe < InfiniBand）**: 同一ノードNVLinkが最低レイテンシ

---

## 10. 複合テクニック適用戦略

### パフォーマンス優先順位（LLMワークロードの例）

| 優先度 | テクニック | 効果 |
|--------|----------|------|
| 1 | カーネルフュージョン + ダブルバッファリング | 最大効果 |
| 2 | CUDAストリームで転送と計算をオーバーラップ | H2D/D2H隠蔽 |
| 3 | CUDAグラフで起動オーバーヘッド削減 | レイテンシ25%削減 |
| 4 | Warp Specialization | 高度パイプライン |
| 5 | Thread Block Clusters | データ再利用最大化 |

> **重要**: 多くのLLMワークロードではシンプルなダブルバッファリング + CUDAストリームで十分。高度技術はエンジニアリングコスト対効果を慎重に評価すること。

### torch.compile との対応

| 高度CUDA技術 | torch.compileでの相当 |
|------------|---------------------|
| Warp Specialization | TorchInductorが自動生成（Triton経由） |
| cp.async / Pipeline API | Tritonカーネルに内包 |
| CUDAグラフ | `mode="reduce-overhead"` または `mode="max-autotune"` |
| カーネルフュージョン | TorchInductorが自動実行 |
| Persistent Kernel | 非サポート（カスタムCUDA C++が必要） |

### プロファイリングコマンド

```bash
nsys profile --trace=cuda,nvtx python train.py        # ストリームオーバーラップ確認
ncu --section WarpStateStats --section MemoryWorkloadAnalysis python model.py
```

**目標メトリクス（最適化済みカーネル）**: SM Utilization >85%, Memory Throughput >80%, Warp Execution Efficiency >90%
