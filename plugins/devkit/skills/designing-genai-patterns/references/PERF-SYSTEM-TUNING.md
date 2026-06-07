# システムレイヤー チューニングガイド

OS、Docker/Kubernetes、ネットワーク（NCCL/InfiniBand/GPUDirect RDMA）、
ストレージ（GDS）を対象とするGPUシステム性能最適化の実践ガイド。

---

## 1. NVIDIA ソフトウェアスタック概要

```
PyTorch / TensorFlow / JAX / vLLM
         ↓
cuDNN / cuBLAS / NCCL / OpenAI Triton
         ↓
CUDA Toolkit (nvcc, cudart)
         ↓
NVIDIA GPU ドライバ
         ↓
Linux OS / GPU ハードウェア
```

### 主要コンポーネント

| コンポーネント | 役割 |
|-------------|------|
| GPU ドライバ | カーネルモジュール (`/dev/nvidia*`)、メモリ管理、スケジューリング |
| CUDA Toolkit | `nvcc` コンパイラ、`cudart`、最適化ライブラリ群 |
| cuBLAS | 行列演算 (GEMM) 最適化 |
| cuDNN | ニューラルネットワーク基本演算 |
| NCCL | マルチGPU通信コレクティブ |
| nvidia-smi | GPU監視・設定ツール |

### CUDA 互換性モデル

```bash
# PTX (中間表現) + CUBIN (アーキテクチャ固有) の fatbinary 構成
# PTX → 将来GPUへの前方互換 (JITコンパイル)
# CUBIN → 既知アーキテクチャでの直接実行

nvcc -arch=sm_90 -code=sm_90,compute_90 kernel.cu
#           ↑ B200 SM アーキテクチャ指定
```

---

## 2. OS チューニング

### 必須設定

```bash
# メモリスワップ無効化 (GPU ワークロードへの干渉防止)
echo 0 | sudo tee /proc/sys/vm/swappiness
echo "vm.swappiness=0" | sudo tee -a /etc/sysctl.conf

# Transparent Huge Pages 無効化 (予測不能なレイテンシ増加を防ぐ)
echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled

# IRQ アフィニティ調整 (GPU-NIC の割り込みを同一NUMAノードに固定)
# /proc/irq/N/smp_affinity で設定
```

### NVIDIA 推奨デーモン

```bash
# Persistence Daemon: ドライバコンテキストを常駐
sudo nvidia-persistenced --persistence-mode

# Fabric Manager: NVLink/NVSwitch トポロジ管理 (NVL72必須)
sudo systemctl enable nvidia-fabricmanager

# DCGM: GPU ヘルスメトリクス収集
sudo systemctl enable nvidia-dcgm
```

---

## 3. NUMA アフィニティと CPU ピニング

### NUMA の重要性

```
同一NUMAノード内メモリアクセス: ~80 ns
クロスNUMAノードメモリアクセス: ~139 ns (約75%レイテンシ増)
```

### GPU と NUMA ノードの対応確認

```bash
nvidia-smi topo -m  # GPU↔NUMA マッピング表示
```

### プロセスをNUMAノードに固定

```bash
# GPU 4 が NUMA node 1 に接続されている場合
numactl --cpunodebind=1 --membind=1 python train.py --gpu 4

# 複数GPUの自動NUMA固定スクリプト
for GPU in 0 1 2 3; do
  NODE=$(nvidia-smi topo -m -i $GPU | awk '/NUMA Affinity/ {print $NF}')
  numactl --cpunodebind=$NODE --membind=$NODE \
    bash -c "CUDA_VISIBLE_DEVICES=$GPU python train.py --gpu $GPU" &
done
```

### PyTorch DataLoader での CPU アフィニティ設定

```python
import psutil
import torch

def worker_init_fn(worker_id):
    # GPUのNUMAノードに対応するCPUコアにバインド
    gpu_id = worker_id % torch.cuda.device_count()
    numa_node = get_gpu_numa_node(gpu_id)  # カスタム関数
    cpus = get_numa_cpus_for_node(numa_node)
    psutil.Process().cpu_affinity(cpus)

dataloader = DataLoader(
    dataset,
    num_workers=4,
    worker_init_fn=worker_init_fn
)
```

---

## 4. Hugepages と GPU ドライバ設定

### Hugepages 設定

```bash
# 2MB hugepages を4096ページ確保
echo 4096 | sudo tee /proc/sys/vm/nr_hugepages

# 1GB hugepages (巨大モデルのメモリ効率向上)
echo 'vm.nr_hugepages=4096' | sudo tee -a /etc/sysctl.conf

# 確認
grep HugePages /proc/meminfo
```

### GPU Persistence Mode

```bash
# Persistence Mode: ドライバ初期化コスト削減
sudo nvidia-smi -pm 1

# 確認
nvidia-smi | grep Persistence
```

### MPS (Multi-Process Service)

```bash
# 複数プロセスでGPUを共有する場合 (GPUコア利用率向上)
export CUDA_MPS_PIPE_DIRECTORY=/tmp/nvidia-mps
export CUDA_MPS_LOG_DIRECTORY=/tmp/nvidia-log
nvidia-cuda-mps-control -d  # MPS デーモン起動
```

### MIG (Multi-Instance GPU)

```bash
# B200を複数の独立したGPUインスタンスに分割
sudo nvidia-smi mig -cgi 1g.10gb,1g.10gb  # 10GB ×2インスタンス作成
sudo nvidia-smi mig -cci  # Compute Instanceを作成
```

---

## 5. Docker と NVIDIA Container Toolkit

### NVIDIA Container Toolkit

```bash
# インストール
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
sudo apt-get install -y nvidia-container-toolkit

# デフォルトランタイム設定
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

### GPU コンテナ起動

```bash
# 全GPU アクセス
docker run --gpus all --ipc=host --ulimit memlock=-1 \
  nvcr.io/nvidia/pytorch:24.01-py3 python train.py

# 特定GPU 指定
docker run --gpus '"device=0,1"' nvcr.io/nvidia/pytorch:24.01-py3 python train.py

# NUMA 固定付き
docker run --gpus all --cpuset-cpus="0-31" --cpuset-mems="0" \
  nvcr.io/nvidia/pytorch:24.01-py3 python train.py
```

---

## 6. Kubernetes と GPU Operator

### GPU Operator のインストール

```bash
# Helm で GPU Operator をインストール
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
helm install gpu-operator nvidia/gpu-operator \
  --namespace gpu-operator \
  --create-namespace \
  --set driver.enabled=true \
  --set mig.strategy=mixed
```

### Kubernetes Topology Manager

```yaml
# kubelet 設定でトポロジーマネージャーを有効化
# /var/lib/kubelet/config.yaml
topologyManagerPolicy: "best-effort"  # またはsingle-numa-node
topologyManagerScope: "pod"
```

### GPU リソース要求

```yaml
# Pod の GPU リソース要求
apiVersion: v1
kind: Pod
metadata:
  name: gpu-training-job
spec:
  containers:
  - name: trainer
    image: nvcr.io/nvidia/pytorch:24.01-py3
    resources:
      limits:
        nvidia.com/gpu: 8
    env:
    - name: NCCL_DEBUG
      value: "INFO"
    - name: NCCL_SOCKET_IFNAME
      value: "ens"  # NIC インターフェース名
```

---

## 7. NCCL チューニング

NCCL（NVIDIA Collective Communications Library）は分散学習の通信コレクティブを提供する。

### 重要な環境変数

```bash
# デバッグ情報出力
export NCCL_DEBUG=INFO
export NCCL_DEBUG_SUBSYS=ALL

# NVLink使用強制
export NCCL_P2P_DISABLE=0
export NCCL_SHM_DISABLE=0

# InfiniBand 設定
export NCCL_IB_DISABLE=0
export NCCL_IB_GID_INDEX=3  # RoCEv2
export NCCL_SOCKET_IFNAME=ib0

# GPUDirect RDMA 有効化
export NCCL_NET_GDR_LEVEL=2

# NCCL ツリー/リング 選択
export NCCL_ALGO=Tree  # LatencyバウンドはTree、BandwidthバウンドはRing

# チャンクサイズ調整
export NCCL_BUFFSIZE=8388608  # 8MB
```

### NCCL 通信ステップ計算

```
AllReduce の通信量 = 2 × N × (N-1) / N × データサイズ
  N = GPU数
  例: 8GPU, 1GB/GPU → 通信量 ≈ 1.75 GB
```

---

## 8. InfiniBand 最適化

### IB 設定確認

```bash
# InfiniBand デバイス確認
ibstat
ibv_devices

# 帯域幅テスト
ib_send_bw -d mlx5_0 -i 1 -F --report_gbits  # サーバー
ib_send_bw -d mlx5_0 -i 1 -F --report_gbits <server_ip>  # クライアント

# レイテンシテスト
ib_send_lat -d mlx5_0
```

### RoCEv2 設定（Ethernet over RDMA）

```bash
# RoCEv2 有効化 (PFC: Priority Flow Control 必須)
# スイッチ側でも PFC 設定が必要

# DCQCN 輻輳制御パラメータ
echo 1 | sudo tee /sys/class/infiniband/mlx5_0/ports/1/congestion/mode
```

---

## 9. GPUDirect RDMA

GPUDirect RDMAにより、NICがGPUメモリに直接DMAアクセス可能になる（CPU経由なし）。

### 有効化

```bash
# nvidia-peermem ドライバのロード
sudo modprobe nvidia-peermem

# 確認
lsmod | grep nvidia_peermem
```

### PyTorch での活用

```python
# NCCL が自動的に GPUDirect RDMA を使用
# NCCL_NET_GDR_LEVEL で制御
import torch.distributed as dist

dist.init_process_group(
    backend='nccl',  # NCCL は GPUDirect RDMA を自動活用
    init_method='env://'
)
```

---

## 10. GPUDirect Storage (GDS)

GDSにより、ストレージからGPUメモリへの直接データ転送が可能（CPU/システムメモリを経由しない）。

### インストールと設定

```bash
# cuFile ライブラリ (GDS の API)
apt-get install libcufile-dev

# GDS 有効確認
gdscheck.py -p
```

### cuFile API の利用例

```python
# PyTorch でのGDS活用 (torch.cuda.GDS経由)
import torch
import cufile  # cuFileライブラリ

# ファイルからGPUメモリに直接読み込み
with cufile.CUFileDriver(filepath, 'r') as f:
    gpu_tensor = torch.empty(size, device='cuda')
    f.read(gpu_tensor.data_ptr(), nbytes, offset)
```

### 通常パス vs GDS パス比較

| 転送パス | レイテンシ | CPU負荷 |
|---------|---------|--------|
| 通常: ストレージ → CPU RAM → GPU | 高 | 高 |
| GDS: ストレージ → GPU (直接) | 低 | 低 |

---

## 11. 分散学習スタックのトポロジー選択

### 通信バックエンド選択基準

| 条件 | 推奨バックエンド |
|-----|--------------|
| NCCL対応GPU (NVLink有効) | NCCL |
| CPUのみの分散処理 | Gloo |
| カスタム通信最適化 | MPI + NCCL |
| 低レイテンシ要件 | NCCL (p2p) |

### ネットワークトポロジーとNCCL設定対応

| 環境 | 最適設定 |
|-----|---------|
| NVL72 (NVLink) | デフォルト / NVLS有効化推奨 |
| InfiniBand クラスタ | NCCL_IB_DISABLE=0, GDR有効 |
| Ethernet (RoCE) | NCCL_IB_GID_INDEX=3, PFC有効 |
| 混在構成 | 階層的通信 (intra-node NVLink, inter-node IB) |

---

## Quick Reference: システム最適化チェックリスト

| 優先度 | 項目 | 確認方法 |
|-------|-----|---------|
| ★★★ | NUMA固定（CPUと同一ノードのGPU） | `nvidia-smi topo -m` |
| ★★★ | vm.swappiness=0 | `cat /proc/sys/vm/swappiness` |
| ★★★ | GPU Persistence Mode有効 | `nvidia-smi -q` |
| ★★ | THP 無効化 | `cat /sys/kernel/mm/transparent_hugepage/enabled` |
| ★★ | NCCL_DEBUG=INFO で通信確認 | ログ出力確認 |
| ★★ | GPUDirect RDMA 有効 | `lsmod \| grep nvidia_peermem` |
| ★ | MPS (低レイテンシ推論の多プロセス共有) | `ps aux \| grep mps` |
| ★ | SHARP 有効確認 | `ibdiagnet` または NCCL ログ |
