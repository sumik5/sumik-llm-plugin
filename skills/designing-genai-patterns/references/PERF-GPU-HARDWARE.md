# GPU ハードウェアアーキテクチャ概要

AIシステム性能最適化の基礎となるGPUハードウェア知識。
NVIDIA Blackwell/Grace世代のアーキテクチャを中心に、Tensor Cores、NVLink/NVSwitch等の主要技術を解説する。

---

## 関連ファイルガイド

| ファイル | 内容 |
|---------|------|
| PERF-GPU-HARDWARE.md（本ファイル）| GPU/CPU ハードウェア概要 |
| PERF-SYSTEM-TUNING.md | OS/Docker/K8s/ネットワーク最適化 |
| PERF-SCALING-FUTURE.md | AI支援最適化・大規模スケーリング |

---

## 1. Mechanical Sympathy（ハードウェア-ソフトウェア協調設計）

**Mechanical Sympathy** とは、ハードウェアの特性を深く理解した上でソフトウェアを設計するアプローチ。

### 代表例

| アルゴリズム | 最適化内容 | 効果 |
|------------|-----------|------|
| FlashAttention | GPU メモリ階層を意識したタイル分割計算 | Attention計算 2×〜4× 高速化 |
| Multi-Head Latent Attention | Tensor Coresを活用した再構成 | FlashAttentionを超える効率 |
| DeepSeek DualPipe | 計算と通信オーバーラップ | 帯域制限環境での高スループット |

### 原則

- ハードウェアの制約が革新的なアルゴリズムを生む（DeepSeekのH800制約→DualPipe）
- アルゴリズムの需要がハードウェア機能を引き出す（Transformerの普及→Tensor Engine）
- このサイクルが継続的な性能向上を実現する

---

## 2. Goodput（有効スループット）

```
Goodput = 有効処理量 / 理論最大処理量
```

### 算出例

```
GPU 8枚ノードが10秒で100,000トークン処理:
  Goodput = 10,000 tokens/sec
  各GPU理論最大 1,500 tokens/sec → 合計 12,000 tokens/sec
  効率 = 10,000 / 12,000 = 83.3%
```

### Goodputを低下させる要因

| 要因 | 例 |
|-----|-----|
| 通信待機 | 勾配同期中のGPUアイドル |
| データロード遅延 | ストレージからの読み込みボトルネック |
| 障害・再起動 | ジョブ失敗による時間損失 |
| 過剰同期 | 不要なバリア操作 |

---

## 3. CPU+GPU スーパーチップアーキテクチャ

### Grace Blackwell GB200 スーパーチップ

```
┌────────────────────────────────┐
│  Grace CPU (ARM Neoverse V2)   │
│  72コア / ~480GB LPDDR5X       │
│  ~500 GB/s メモリ帯域幅        │
├────────────────────────────────┤
│     NVLink-C2C (最大~900 GB/s) │  ← キャッシュコヒーレント
├─────────────┬──────────────────┤
│ Blackwell   │ Blackwell        │
│ GPU (B200)  │ GPU (B200)       │
│ 192GB HBM3e │ 192GB HBM3e      │
└─────────────┴──────────────────┘
合計: 約900GB のコヒーレント統合メモリ空間
```

### 従来PCIeとの比較

| 接続方式 | 帯域幅 | キャッシュコヒーレンス |
|---------|--------|---------------------|
| PCIe Gen5 x16 | ~64 GB/s | なし |
| PCIe Gen6 x16 | ~128 GB/s | なし |
| NVLink-C2C | ~900 GB/s | あり |

### 統合メモリ活用のポイント

```python
# CPU-GPU間メモリ管理のベストプラクティス
import torch

# 明示的プリフェッチでページフォルト抑制
# cudaMemPrefetchAsync を使用してページフォルトを回避
# cudaMemAdvise で使用パターンをヒント指定

# ❌ 非推奨: 暗黙のページマイグレーションに依存
tensor_on_cpu = torch.zeros(1024, device='cpu')
result = tensor_on_cpu.cuda()  # ページフォルトが発生する可能性

# ✅ 推奨: 明示的なデータ配置管理
tensor_pinned = torch.zeros(1024, pin_memory=True)
tensor_gpu = tensor_pinned.cuda(non_blocking=True)
```

---

## 4. NVIDIA Grace CPU

| 仕様 | 値 |
|-----|-----|
| コアアーキテクチャ | ARM Neoverse V2 |
| コア数 | 72 |
| メモリ帯域幅 | ~500 GB/s (LPDDR5X) |
| L3キャッシュ | 100MB以上 |
| 役割 | データ前処理、GPU への効率的なデータ供給 |

---

## 5. NVIDIA Blackwell GPU（デュアルダイ設計）

### アーキテクチャ概要

```
B200 = 2ダイ MCM（Multi-Chip Module）
  各ダイ: ~104B トランジスタ + 96GB HBM3e
  合計: ~208B トランジスタ + 192GB HBM3e (180GB usable)
  ダイ間接続: NV-HBI (10 TB/s)
```

### Hopper H100 との比較

| 項目 | H100 (Hopper) | B200 (Blackwell) | 向上率 |
|-----|---------------|-----------------|--------|
| トランジスタ数 | ~80B | ~208B | 2.6× |
| HBMメモリ | 80GB HBM3 | 180GB HBM3e | 2.25× |
| メモリ帯域幅 | ~3.35 TB/s | ~8 TB/s | 2.4× |
| L2キャッシュ | 50MB | 126MB | 2.5× |

---

## 6. Tensor Cores と Transformer Engine

### 精度と効率のトレードオフ

| 数値形式 | ビット数 | 対FP16スループット | 用途 |
|---------|---------|-----------------|------|
| FP32 | 32bit | 0.25× | 高精度が必要な計算 |
| FP16/BF16 | 16bit | 1× (ベースライン) | 一般的な学習 |
| FP8 | 8bit | 2× | 推論・学習の高速化 |
| NVFP4 | 4bit | 4× | 最大スループット |

### NVL72 ラック全体の理論性能

```
72 GPU × FP4 精度 = ~1.44 exaFLOPS
72 GPU × FP8 精度 = ~720 petaFLOPS
```

### Transformer Engine (TE) の動作

```python
# PyTorch での混合精度学習（TE活用）
import torch
from torch.cuda.amp import autocast

model = YourTransformerModel().cuda()

with autocast(dtype=torch.float8_e4m3fn):  # FP8使用
    output = model(input)
    loss = criterion(output, target)
```

---

## 7. SM（Streaming Multiprocessor）とメモリ階層

### SM内部構成

```
SM
├── FP32 CUDA Cores (並列算術演算)
├── Tensor Cores (行列演算加速)
├── LD/ST Units (メモリアクセス)
├── SFU (特殊関数: sin, exp等)
└── Shared Memory / L1 Cache
```

### メモリ階層（低速→高速）

```
HBM (off-chip)
  ~8 TB/s, 容量大, レイテンシ高
    ↓
L2 Cache (shared, 126MB)
  全SMが共有
    ↓
L1 Cache / Shared Memory (per SM)
  高速アクセス
    ↓
Registers (per thread)
  最高速, 容量小
```

### レイテンシハイディング

```
SMは多数のワープを並列実行:
  ワープA: メモリ待機中
  ワープB: 計算実行 ← GPUはこちらを実行
  ワープC: スケジュール待ち

→ メモリアクセスレイテンシを計算で隠蔽する
```

---

## 8. NVLink 5 と NVSwitch

### NVL72 ネットワーク構成

```
72 GPU + 18 NVSwitch チップ
  各GPU: 18ポート × 100 GB/s = 1.8 TB/s 双方向
  各GPUが全NVSwitch に接続 (1ホップで全GPU到達)
  全体集約帯域幅: ~130 TB/s
```

### InfiniBand との比較

| 指標 | NVL72 (NVLink 5) | 従来 InfiniBand クラスタ |
|-----|-----------------|----------------------|
| GPU間帯域幅 | 1.8 TB/s/GPU | 20〜80 GB/s/GPU |
| GPU間レイテンシ | ~1〜2 μs | ~5〜10 μs以上 |
| ホップ数 | 1 (NVSwitch経由) | 複数 |

### SHARP (Scalable Hierarchical Aggregation and Reduction Protocol)

```
通常のAllReduce:
  GPU1 → スイッチ → GPU2 → CPU集約 → GPU全体配布

SHARP有効時:
  GPU1 → NVSwitch (スイッチ内で集約) → GPU全体
  ※ GPUを経由せずスイッチファブリック内で削減処理
```

**効果**: 大規模学習でのAllReduce通信コストを大幅削減

---

## 9. マルチラック構成

### 通信階層の設計原則

| スコープ | 通信手段 | 帯域幅 |
|---------|---------|--------|
| ラック内 GPU間 | NVLink/NVSwitch | 1.8 TB/s/GPU |
| ラック外 (ラック間) | InfiniBand / Ethernet | 20〜400 GB/s |
| ストレージ | GPUDirect Storage (GDS) | NVMe/並列FS依存 |

### 設計指針

- ラック内通信 (intra-rack) を最大化する
- ラック間通信 (inter-rack) を最小化する
- 計算と通信をオーバーラップさせる

---

## 10. 100兆パラメータモデルへのスケーリング

### メモリ必要量の試算

```
100兆パラメータ × 2 bytes (FP16) = 200 TB
B200 GPU (180GB): 約1,110 GPU必要 ≈ 138 ノード (8GPU/node)
B300 GPU (288GB): 約695 GPU必要 ≈ 86 ノード
※ これはウェイトのみ。KVキャッシュ・活性化・最適化器状態は別途必要
```

### 主要アプローチ

| 課題 | 対策 |
|-----|------|
| 計算量 | MoE（スパース活性化）、低精度 (FP4/FP8) |
| メモリ | アクティベーションチェックポイント、最適化器状態シャーディング |
| 通信 | パイプライン並列化、計算・通信オーバーラップ |
| スループット | 3D/4D並列化（DP + TP + PP + EP） |

### MoE（Mixture of Experts）効率化

```
DeepSeek V3の例:
  総パラメータ: ~680B
  活性パラメータ/トークン: ~37B (1 shared + 8 selected out of 256)
  → 密モデル相当の精度をはるかに低い計算コストで実現
```

---

## Quick Reference

| 判断 | 要素 | 値 |
|-----|-----|-----|
| B200 HBM3e 帯域幅 | GPU per | ~8 TB/s |
| NVLink-C2C 帯域幅 | CPU-GPU | ~900 GB/s |
| NVLink 5 帯域幅 | GPU per | 1.8 TB/s |
| NVL72 総帯域幅 | ラック内 | ~130 TB/s |
| FP8 vs FP16 | スループット比 | 2× |
| FP4 vs FP16 | スループット比 | 4× |
