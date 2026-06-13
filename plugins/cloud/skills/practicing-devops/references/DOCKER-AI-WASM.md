---
description: Docker AI/Wasm統合。Docker Model Runner (DMR) によるローカルAI実行とWebAssemblyコンテナ化を解説。
---

# Docker AI & WebAssembly

DockerはAIモデルとWebAssembly (Wasm) アプリケーションの実行をサポートし、クラウドコンピューティングの新しい波を推進する。

## 📋 目次

### Docker Model Runner (DMR)
- [DMR概要](#docker-model-runner-概要)
- [アーキテクチャ](#アーキテクチャ)
- [インストール](#インストール)
- [モデル管理](#モデル管理)
- [Compose統合](#compose統合)
- [サードパーティアプリ統合](#サードパーティアプリ統合)

### Docker & WebAssembly
- [Wasm概要](#webassembly-概要)
- [Wasmアプリ作成](#wasmアプリ作成)
- [コンテナ化](#wasmコンテナ化)
- [実行](#wasm実行)

---

## Docker Model Runner (DMR)

### 概要

**Docker Model Runner (DMR)** はAIモデルをローカルで実行するDockerの新技術。

#### なぜDMRか

| 理由 | 説明 |
|------|------|
| **プライバシー** | データがローカルに留まる (クラウド送信なし) |
| **コスト削減** | 予測不可能なクラウドコストを回避 |
| **低レイテンシ** | ネットワーク遅延なし |
| **フルコントロール** | プロンプトカスタマイズ・ファインチューニング可能 |

#### 重要な特徴

- ✅ **コンテナ外で実行**: AI加速ハードウェア (GPU, NPU, TPU) に直接アクセス
- ✅ **OpenAI互換エンドポイント**: 既存アプリとの統合が容易
- ✅ **Docker統合**: CLI、Compose、Docker Hubとシームレスに連携

**なぜコンテナ外か**: ほとんどのAI加速デバイスは独自ドライバ/SDKを持ち、コンテナからのアクセスが困難。コンテナ外実行により幅広いハードウェアサポートを実現。

#### 対応環境

| プラットフォーム | GPU対応 | 状態 |
|---------------|---------|------|
| **Mac (Apple Silicon)** | 内蔵GPU | ✅ 対応 |
| **Windows** | NVIDIA GPU | ✅ 対応 |
| **CPU** | - | ✅ 対応 (低速) |
| **Linux** | - | 🚧 将来対応予定 |

---

### アーキテクチャ

```
┌─────────────────────────────────────────────┐
│       コンテナ化アプリケーション              │
│  ┌──────────┐        ┌──────────┐          │
│  │Frontend  │◄──────►│ Backend  │          │
│  └──────────┘        └──────────┘          │
│                           │                 │
│                           │ HTTP Request    │
│                           ▼                 │
│      model-runner.docker.internal:12434    │
└─────────────────────────────────────────────┘
                            │
        ┌───────────────────┴────────────────────┐
        │    Docker Model Runner (ホストプロセス) │
        │  ┌────────────────────────────────┐   │
        │  │  llama.cpp (Runtime)           │   │
        │  │  - Model Loading/Unloading     │   │
        │  │  - OpenAI-compatible Endpoints │   │
        │  └────────────────────────────────┘   │
        └────────────────┬───────────────────────┘
                         │
        ┌────────────────▼───────────────────┐
        │  AI加速ハードウェア (GPU/NPU)      │
        └────────────────────────────────────┘
```

#### 主要コンポーネント

| コンポーネント | 役割 |
|--------------|------|
| **DMRホストプロセス** | コンテナ外で実行、ハードウェア直接アクセス |
| **Runtime** | 推論エンジン (デフォルト: `llama.cpp`、将来的に複数対応) |
| **ローカルモデルストア** | `~/.docker/models` にモデルを保存 |
| **APIエンドポイント** | OpenAI互換 + モデル管理エンドポイント |

#### エンドポイント

**モデル管理 (DMRネイティブ)**:
```
GET    /models
POST   /models/create
GET    /models/{namespace}/{name}
DELETE /models/{namespace}/{name}
```

**推論 (OpenAI互換)**:
```
GET  /engines/llama.cpp/v1/models
POST /engines/llama.cpp/v1/chat/completions
POST /engines/llama.cpp/v1/completions
POST /engines/llama.cpp/v1/embeddings
```

#### アクセス方法

| アクセス元 | エンドポイント |
|-----------|---------------|
| **同一ホストのコンテナ** | `http://model-runner.docker.internal/` |
| **同一ホストの非コンテナアプリ** | `http://localhost:12434` |
| **リモートホスト** | `http://<DMR-host-IP>:12434` |

---

### インストール

#### 前提条件

- Docker Desktop 4.41以上
- Mac (Apple Silicon推奨) またはWindows + NVIDIA GPU

#### セットアップ手順

**1. Docker Desktopで有効化**

```
Settings → Features in development
→ ✅ Enable Docker Model Runner
→ ✅ Enable host-side TCP support (Port: 12434)
→ Apply & restart
```

**2. 動作確認**

```bash
docker model status
```

**出力例**:
```
Docker Model Runner is running

Status:
llama.cpp: running llama.cpp latest-metal (sha256:ad58230f548...)
```

---

### モデル管理

#### モデルのプル

```bash
# Docker Hubからモデルをダウンロード
docker model pull ai/gemma3:4B-Q4_K_M

# モデル一覧表示
docker model ls
```

**出力例**:
```
MODEL NAME            PARAMS   QUANTIZATION     ARCHITECTURE   SIZE
ai/gemma3:4B-Q4_K_M   3.88 B   IQ2_XXS/Q4_K_M   gemma3         2.31G
```

#### モデルの検査

**マニフェスト確認 (Docker Hub)**:
```bash
docker manifest inspect ai/gemma3:4B-Q4_K_M | jq
```

**ローカルモデル詳細**:
```bash
docker model inspect ai/gemma3:4B-Q4_K_M
```

**ストレージ場所**:
```bash
ls -lh ~/.docker/models/blobs/sha256
```

#### モデルのテスト

**CLI (REPL)**:
```bash
docker model run ai/gemma3:4B-Q4_K_M
> How long is a day on Mars?
A day on Mars, also known as a "sol," is about 24 hours, 39 minutes...
> /bye
```

**Docker Desktop UI**:
- Models タブ → モデル選択 → チャット開始

#### モデルのプッシュ

```bash
# Docker Hubにプッシュ
docker model push ai/my-custom-model:v1
```

---

### APIの使用

#### 利用可能なモデル確認

```bash
curl -s localhost:12434/engines/v1/models | jq
```

#### 推論リクエスト

```bash
curl -s http://localhost:12434/engines/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "ai/gemma3:4B-Q4_K_M",
    "messages": [
      {
        "role": "system",
        "content": "Keep responses to one sentence."
      },
      {
        "role": "user",
        "content": "How long is a day on Mars?"
      }
    ],
    "temperature": 0.7,
    "max_tokens": 500
  }' | jq -r '.choices[0].message.content'
```

**パラメータ**:
- `model`: 使用するモデル名
- `messages`: システムプロンプト + ユーザープロンプト
- `temperature`: 創造性 (0=予測可能、1=創造的)
- `max_tokens`: レスポンス長制限

---

### Compose統合

#### アーキテクチャ

```yaml
services:
  frontend:
    build: ./frontend
    ports:
      - "3000:3000"
    depends_on:
      - backend

  backend:
    build: ./backend
    ports:
      - "8000:8000"
    depends_on:
      - dmr

  dmr:
    provider:
      type: model
      options:
        model: ${LLM_MODEL_NAME}
```

#### 環境変数 (.env)

```env
MODEL_HOST=http://model-runner.docker.internal/engines/v1
LLM_MODEL_NAME=ai/gemma3:4B-Q4_K_M
```

#### デプロイ

```bash
docker compose up --build --detach
```

**動作**:
1. DMRサービスが起動し、指定モデルをロード
2. Backendが起動し、DMRに接続
3. Frontendが起動し、Backendに接続
4. ユーザーがFrontend (port 3000) にアクセス
5. リクエストがBackend → DMR → モデル推論 → レスポンス返却

---

### サードパーティアプリ統合

#### Open WebUI統合例

**Compose設定**:
```yaml
volumes:
  open-webui:

services:
  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    environment:
      - DEFAULT_MODELS=${MODEL_NAME}
      - WEBUI_AUTH=False
      - OPENAI_API_KEY=${OPENAI_KEY}
      - OPENAI_API_BASE_URL=${MODEL_HOST}
    volumes:
      - open-webui:/app/backend/data
    ports:
      - "3001:8080"
    depends_on:
      - dmr

  dmr:
    provider:
      type: model
      options:
        model: ${MODEL_NAME}
```

**環境変数**:
```env
MODEL_HOST=http://model-runner.docker.internal/engines/v1
MODEL_NAME=ai/qwen3:0.6B-Q4_K_M
OPENAI_KEY=na
```

**使用**:
```bash
docker compose up
# http://localhost:3001 にアクセス
```

---

### DMRコマンドリファレンス

| コマンド | 説明 |
|---------|------|
| `docker model status` | DMRステータス確認 |
| `docker model pull <model>` | モデルダウンロード |
| `docker model push <model>` | モデルアップロード |
| `docker model ls` | ローカルモデル一覧 |
| `docker model inspect <model>` | モデル詳細表示 |
| `docker model rm <model>` | モデル削除 |
| `docker model run <model>` | モデルREPL起動 |

---

## WebAssembly (Wasm)

### 概要

**WebAssembly (Wasm)** はクラウドコンピューティングの第3の波を推進する新しいVMアーキテクチャ。

#### 3つの波

```
第1波: 仮想マシン (VM)
    └─ サイズ: 大、速度: 遅、セキュリティ: 高

第2波: コンテナ
    └─ サイズ: 中、速度: 中、セキュリティ: 中

第3波: WebAssembly (Wasm)
    └─ サイズ: 小、速度: 高、セキュリティ: 高
```

#### Wasmの利点

| 特徴 | 説明 |
|------|------|
| **軽量** | Linuxコンテナより小さい (数MB) |
| **高速** | 起動時間がミリ秒単位 |
| **ポータブル** | Wasmランタイムがあればどこでも実行可能 |
| **セキュア** | サンドボックス実行、メモリ安全 |

#### 現在の適用領域

- ✅ **AI/ML推論**
- ✅ **サーバーレス関数**
- ✅ **プラグインシステム**
- ✅ **エッジデバイス**

#### 制限事項

- ❌ **複雑なネットワーキング** (改善中)
- ❌ **ヘビーI/O** (改善中)

**注**: Wasmエコシステムは急速に進化中。

---

### Docker + Wasm統合

#### Wasmランタイム確認

```bash
docker run --rm -i --privileged --pid=host \
  jorgeprendes420/docker-desktop-shim-manager:latest
```

**出力例** (利用可能なランタイム):
```
io.containerd.wasmtime.v1
io.containerd.wws.v1
io.containerd.spin.v2
io.containerd.wasmer.v1
io.containerd.wasmedge.v1
io.containerd.lunatic.v1
```

#### Wasmコンテナとは

**Wasmコンテナ = Wasmバイナリ + 最小限のscratchコンテナ**

- ✅ 既存Dockerツール (`docker build`, `docker run`) で管理可能
- ✅ Docker Hubなど既存OCIレジストリで配布可能
- ✅ OCI Image形式で保存

---

### Wasmアプリ作成

#### 前提条件

```bash
# Rust インストール
# → https://www.rust-lang.org/tools/install

# Wasm target追加
rustup target add wasm32-wasip1

# Spin インストール
# → https://developer.fermyon.com/spin/install
```

#### アプリ作成

**1. Spinアプリ初期化**:
```bash
spin new hello-world -t http-rust
# Description: Wasm app
# HTTP path: /hello
```

**2. コード編集** (`src/lib.rs`):
```rust
use spin_sdk::http::{IntoResponse, Request, Response};

#[spin_sdk::http_component]
fn handle_request(_req: Request) -> anyhow::Result<Response> {
    Ok(http::Response::builder()
        .status(200)
        .header("content-type", "text/plain")
        .body("Docker loves Wasm")?)  // ← メッセージ変更
        .build())
}
```

**3. ビルド**:
```bash
spin build
```

**生成物**: `target/wasm32-wasip1/release/hello_world.wasm`

**4. ローカルテスト**:
```bash
spin up
# http://127.0.0.1:3000/hello にアクセス
```

---

### Wasmコンテナ化

#### Dockerfile作成

```dockerfile
FROM scratch
COPY /target/wasm32-wasip1/release/hello_world.wasm .
COPY spin.toml .
```

#### spin.toml 修正

```toml
[component.hello-world]
source = "hello_world.wasm"  # ← パスをルートに変更
```

#### イメージビルド

```bash
docker build \
  --platform wasi/wasm \
  --provenance=false \
  -t username/myapp:wasm .
```

**重要フラグ**:
- `--platform wasi/wasm`: WasmイメージとしてマークS

#### イメージ確認

```bash
docker images
```

**出力例**:
```
REPOSITORY         TAG    SIZE
username/myapp     wasm   104kB  ← 非常に小さい
```

#### レジストリへのプッシュ

```bash
docker push username/myapp:wasm
```

---

### Wasm実行

#### コンテナ起動

```bash
docker run -d --name wasm-ctr \
  --runtime=io.containerd.spin.v2 \
  --platform=wasi/wasm \
  -p 5556:80 \
  username/myapp:wasm /
```

**フラグ解説**:
- `--runtime=io.containerd.spin.v2`: Spinランタイム指定
- `--platform=wasi/wasm`: Wasmプラットフォーム指定

#### アクセス

```
http://localhost:5556/hello
```

#### コンテナ確認

```bash
docker ps
# → 通常のコンテナと同様に表示される
```

---

### Wasmクリーンアップ

```bash
# コンテナ削除
docker rm wasm-ctr -f

# イメージ削除
docker rmi username/myapp:wasm
```

---

## DMR vs Ollama vs LM Studio

| 機能 | DMR | Ollama | LM Studio |
|------|-----|--------|-----------|
| **推論エンジン** | llama.cpp (拡張可能) | llama.cpp | llama.cpp |
| **Docker統合** | ✅ ネイティブ | ⚠️ コンテナ化可能 | ⚠️ なし |
| **Compose対応** | ✅ あり | ⚠️ 手動設定 | ❌ なし |
| **OpenAI互換** | ✅ あり | ✅ あり | ✅ あり |
| **OCI/Docker Hub** | ✅ あり | ⚠️ 独自レジストリ | ❌ なし |

**DMRを選ぶべき場合**:
- 既存Dockerユーザー
- Docker + ローカルモデルの統合を希望
- クラウドネイティブエコシステムとの統合

---

## まとめ

### Docker Model Runner (DMR)

- ✅ **ホストプロセス**: コンテナ外実行でハードウェア直接アクセス
- ✅ **OpenAI互換**: 既存アプリとの統合が容易
- ✅ **Docker統合**: CLI、Compose、Docker Hubとシームレス連携
- ✅ **動的ロード**: 需要に応じてモデルをロード/アンロード
- 🚧 **今後**: Linux対応、CI/CD統合予定

### WebAssembly (Wasm)

- ✅ **軽量・高速**: Linuxコンテナより小さく、起動が速い
- ✅ **ポータブル**: 一度コンパイルすればどこでも実行可能
- ✅ **Docker統合**: 既存ツールでビルド・実行可能
- 🚧 **制限**: ネットワーク・I/O機能は発展途上

**重要**: Docker DesktopはWasmランタイムを標準搭載。`docker build`、`docker run`でWasmアプリを扱える。
