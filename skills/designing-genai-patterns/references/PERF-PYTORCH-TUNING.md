# PERF-PYTORCH-TUNING: PyTorchプロファイリング・チューニング・スケーリング

> Ch 13–14 カバー範囲: PyTorch Profiler、Nsight Systems/Compute、分散学習（DDP/FSDP）、torch.compile、CUDAグラフ、メモリ最適化

---

## 1. プロファイリングツール全体像

### ツール選択判断基準

| ツール | スコープ | 主な用途 |
|--------|---------|---------|
| PyTorch profiler (Kineto) | Python/CUDA オペレーター | 遅い演算・グラフブレーク・メモリ使用量の特定 |
| Nsight Systems (`nsys`) | システム全体タイムライン | CPU-GPU重複・データローダーストール・マルチGPU同期 |
| Nsight Compute (`ncu`) | カーネル単位のハードウェア解析 | メモリバウンド/コンピュートバウンド判定、Roofline |
| PyTorch memory profiler | GPU メモリ使用量 | フラグメンテーション・ピークメモリの特定 |
| Linux `perf` | CPU サイクル・キャッシュミス | Python GIL・データロード・ホストI/Oボトルネック |
| Holistic Trace Analysis (HTA) | 分散学習トレース | マルチGPU・マルチノードの不均衡分析 |
| Perfetto / Chrome tracing | オフライントレース閲覧 | チーム共有・SQLクエリによる詳細フィルタリング |

> ⚠️ TensorBoardのPyTorchトレースプラグインは廃止済み → Perfetto + HTA を使用する

### NVTX マーカーの活用

```python
# コードのセクションを NVTX でアノテーション
torch.cuda.nvtx.range_push("forward")
with torch.autocast(device_type="cuda", dtype=torch.bfloat16):
    outputs = model(input_ids, ...)
torch.cuda.nvtx.range_pop()
```

- `torch.profiler.record_function("name")` でも同様に可
- NVTX マーカーは PyTorch profiler と Nsight Systems 両方に表示される → クロスツール分析が容易

---

## 2. プロファイリング実践

### PyTorch Profilerの基本パターン

```python
from torch import profiler

with profiler.profile(
    activities=[profiler.ProfilerActivity.CPU, profiler.ProfilerActivity.CUDA],
    record_shapes=True,    # テンソル形状を記録
    profile_memory=True,   # GPU メモリ使用量をトラック
    with_stack=True,       # スタックトレース有効
    with_flops=True        # FLOPs カウンタ
) as prof:
    with profiler.record_function("train_step"):
        train_step(...)

# top-10 演算を CUDA 実行時間でソート
print(prof.key_averages().table(sort_by="self_cuda_time_total", row_limit=10))
```

### Nsight Systems + NVTX 解析

```bash
nsys profile --output=profile --stats=true -t cuda,nvtx python train.py
nsys stats --report=nvtx_gpu_proj_sum profile.nsys-rep
```

### Nsight Compute で GEMM のRoofline分析

```bash
ncu \
  --kernel-name-regex "matmul" \
  --metrics \
    gpu__time_duration.avg,\
    gpu__dram_throughput.avg.pct_of_peak_sustained_elapsed,\
    sm__warps_active.avg.pct_of_peak_sustained_active \
  -o matmul_report python train.py
```

| 状態 | FLOPS% | メモリBW% | 対処法 |
|------|--------|---------|--------|
| メモリバウンド（ベースライン） | 50% | 70% | カーネル融合・精度削減でArithmetic Intensity向上 |
| コンピュートバウンド（最適化後） | 85% | 40% | ほぼRoofline到達 |

> 占有率に万能な目標値はない。Nsightのストール理由ブレークダウンと合わせて判断する

### Linux `perf` によるCPUホスト解析

```bash
# CPU統計の概要
perf stat -e cycles,instructions,cache-misses,branch-misses python train.py

# コールグラフの詳細収集
perf record -F 2000 -g --call-graph dwarf -o perf.data python train.py
perf report --stdio -n -g -i perf.data
```

ホット関数別の対処法:

| ボトルネック | 対処法 |
|------------|--------|
| Python interpreter (45%) | `torch.compile` でインタープリタオーバーヘッド除去 |
| `aten::matmul` (20%) | コンパイルまたはカスタム CUDA カーネル |
| DataLoader (10%) | `num_workers` 増加・`persistent_workers=True` |
| `ncclAllReduce` (8%) | `bucket_cap_mb` チューニング・勾配圧縮 |
| I/O reads (5%) | `pin_memory=True`・`non_blocking=True`・大きいシャードフォーマット |

---

## 3. PyTorch Compiler（torch.compile）

### コンパイラスタック

```
Python コード → TorchDynamo（グラフキャプチャ）→ AOT Autograd（バックワードキャプチャ）→ TorchInductor（CUDA カーネル生成）
```

### コンパイルモード比較

| モード | コンパイル時間 | 追加メモリ | 主な特徴 |
|--------|-----------|---------|---------|
| `default` | 低〜中 | なし | 汎用融合・基本オートチューン |
| `reduce-overhead` | 中 | あり（ワークスペース） | CUDA Graphs を積極活用・小バッチ向け |
| `max-autotune` | 高 | 場合あり | Triton積極オートチューン・CUDAグラフ有効 |
| `max-autotune-no-cudagraphs` | 高 | なし | max-autotune と同じだがグラフなし・動的形状向け |

```python
# 基本的な使い方
model = torch.compile(model)  # default モード

# MoE など動的ルーティングモデル
model = torch.compile(model, mode="max-autotune-no-cudagraphs")
# 形状が安定したら
model = torch.compile(model, mode="max-autotune")
```

**効果の目安**: MoE モデルで約30%高速化（dense モデルは <10%）

### TorchInductor の最適化

- **プロローグ・エピローグ融合**: bias-add + matmul + activation を1カーネルに
- **ワープ特殊化**: メモリワープ vs コンピュートワープを自動選択
- **Mega-Cache**: コンパイル済みカーネルをディスクに保存・再利用

```python
# コンパイルキャッシュの永続化
torch.compiler.save_cache_artifacts()
torch.compiler.load_cache_artifacts()
```

### グラフブレーク診断

```python
# グラフブレークの一覧と原因を表示
torch._dynamo.explain(model)

# 詳細ログの有効化
# TORCH_LOGS="+dynamo,+inductor" python train.py

# 動的形状のマーク
torch._dynamo.mark_dynamic(tensor, dim)

# TorchInductor カーネルのベンチマーク
# TORCHINDUCTOR_UNIQUE_KERNEL_NAMES=1 TORCHINDUCTOR_BENCHMARK_KERNEL=1 python train.py
```

### 地域コンパイル（Regional Compilation）

Transformer/MoE のような繰り返しブロック向け:

```python
# 繰り返しブロックを1回だけコンパイルして再利用
torch.compiler.nested_compile_region()
```

---

## 4. 注意最適化（PyTorch Attention APIs）

| API | 用途 |
|-----|------|
| `F.scaled_dot_product_attention` | 標準的な高速化（FlashAttentionを自動選択） |
| FlexAttention | カスタムスパース注意パターン（ブロックスパース・スライディングウィンドウ） |
| FlexDecoding | 推論デコーディング最適化（KVキャッシュ効率化） |
| Context Parallel | シーケンス長方向の並列化（超長コンテキスト向け） |

---

## 5. CUDA Graphs

### 基本的なキャプチャ・リプレイパターン

```python
# ウォームアップ（キャプチャ前に実行）
for _ in range(3):
    model(static_input)

# グラフキャプチャ
g = torch.cuda.CUDAGraph()
with torch.cuda.graph(g):
    static_output = model(static_input)

# リプレイ（新しいデータでの実行）
static_input.copy_(new_batch)
g.replay()
result = static_output.clone()
```

### ベストプラクティス

| 項目 | 方針 |
|------|------|
| メモリ割り当て | キャプチャ前に最大サイズで事前確保 |
| 形状の固定 | 形状ごとに別グラフをキャプチャ（または `max-autotune-no-cudagraphs`） |
| キャプチャ範囲 | フォワード+バックワード+オプティマイザを1グラフに |
| メモリ再利用 | 最大バッチサイズ前提でキャプチャ |
| 共有メモリプール | 複数グラフ間でメモリ共有（FireworksAI パターン） |

**CUDA Graph Trees**: `torch.compile(mode="reduce-overhead")` が内部的に使用。形状ごとにサブグラフをキャプチャして共有プールで管理。

---

## 6. 分散学習（DDP / FSDP）

### データ並列化選択基準

| 戦略 | 用途 | ZeRO ステージ |
|------|------|-------------|
| DDP (Distributed Data Parallel) | モデルが1GPUに収まる場合 | Stage-0 |
| FSDP SHARD_GRAD_OP | 勾配・オプティマイザ状態のみシャード | Stage-2 |
| FSDP FULL_SHARD | 全状態をシャード（最小メモリ） | Stage-3 |
| FSDP HYBRID_SHARD | ノード内シャード+ノード間レプリカ | Stage-3 + DP |

### FSDPの設定例

```python
from torch.distributed.fsdp import FullyShardedDataParallel as FSDP, CPUOffload, ShardingStrategy

fsdp_model = FSDP(
    model,
    sharding_strategy=ShardingStrategy.FULL_SHARD,
    cpu_offload=CPUOffload(offload_params=True, pin_memory=True),
    mixed_precision=MixedPrecision(
        param_dtype=torch.bfloat16,
        reduce_dtype=torch.bfloat16
    ),
    backward_prefetch=BackwardPrefetch.BACKWARD_PRE,
    activation_checkpointing_policy={nn.TransformerEncoderLayer}
)
```

### DeepSpeed / FSDP との使い分け

| 機能 | FSDP | DeepSpeed ZeRO |
|------|------|----------------|
| ZeRO-3 | ✅ FULL_SHARD | ✅ ZeRO-3 |
| CPU オフロード | ✅ CPUOffload | ✅ ZeRO-Infinity |
| NVMe オフロード | ❌ | ✅ ZeRO-Infinity |
| パイプライン並列との組み合わせ | ✅ | ✅ |

---

## 7. メモリ最適化

### アクティベーションチェックポイント

```python
# トランスフォーマーブロックに適用
from torch.utils.checkpoint import checkpoint

class TransformerLayer(nn.Module):
    def forward(self, x):
        return checkpoint(self._forward, x)
```

**トレードオフ**: 計算コスト増（約30%）↔️ メモリ使用量削減。現代GPUはFLOPS > メモリのため有効。

### CPUオフロード戦略

```python
# DeepSpeed ZeRO-Inference の例
# less-used expert layers を CPU/NVMe にオフロード
# compute中に非同期でprefetch
model.to_device("cpu", non_blocking=True)
```

### CUDAメモリアロケータのチューニング

```bash
export PYTORCH_ALLOC_CONF=\
max_split_size_mb:256,\
roundup_power2_divisions:[256:1,512:2,1024:4,>:8],\
backend:cudaMallocAsync
```

| パラメータ | 効果 |
|-----------|------|
| `max_split_size_mb` | 大きなフリーブロックを分割しない → フラグメンテーション削減 |
| `roundup_power2_divisions` | 類似サイズをバケット化 → キャッシュ再利用率向上 |
| `backend:cudaMallocAsync` | 非同期アロケータ → マルチスレッドI/O同期コスト削減 |

### メモリ使用量の監視

```python
torch.cuda.memory_stats()         # 詳細統計
torch.cuda.mem_get_info()         # free/total
torch.cuda.memory._record_memory_history(max_entries=100000)
torch.cuda.memory._dump_snapshot('memory_snapshot.pkl')  # ビジュアライザで確認
```

---

## 8. データパイプライン最適化

```python
# 効率的なDataLoader設定
DataLoader(
    dataset,
    num_workers=os.cpu_count(),      # CPU数程度
    pin_memory=True,                  # ページロックメモリ使用
    persistent_workers=True,          # ワーカー再起動コスト削減
    prefetch_factor=4,                # 先読みバッファ
)

# 非同期データ転送
batch = batch.to(device, non_blocking=True)
```

**データフォーマット推奨**: Arrow / WebDataset (tar shards) / TFRecord → 小ファイルの分散I/Oを回避。

---

## 9. マルチGPU通信最適化

### Symmetric Memory（MoE向け）

ホストCPUを介さずGPU間で直接データアクセス。MoEのall-to-allトークンシャッフルをCUDA Graphsでキャプチャ可能にする。

### NCCL PluggableAllocator

```python
from torch.cuda.memory import MemPool
nccl_pool = MemPool(backend.mem_allocator)
backend.register_mem_pool(nccl_pool)
with torch.cuda.use_mem_pool(nccl_pool):
    dist.all_reduce(tensor)
```

**効果**: GPUDirect RDMA + SHARP を活用してSM競合を削減。

### UCX + NCCL（マルチノード向け）

```bash
export NCCL_NET=UCX
export NCCL_PLUGIN_P2P=ucx
export UCX_TLS=rc,self,gdr_copy,cuda_copy
```

---

## 10. torchao（量子化・スパース化・プルーニング）

```python
import torchao

# PTQ（学習後量子化）
torchao.quantization.quantize_(model, int8_weight_only())

# QAT（量子化認識学習）
torchao.quantization.prepare_for_quantization_aware_training_(model)
```

対応フォーマット: INT8、FP8、FP4（Blackwell向け）

---

## 関連ファイル

- `PERF-INFERENCE-OPTIMIZATION.md` — vLLM、PagedAttention、投機的デコーディング
- `PERF-CUDA-ADVANCED.md` — カーネルパイプライン、CUDAグラフ詳細
- `PERF-SCALING-FUTURE.md` — 大規模スケーリング戦略
