# Podman Desktop と AI Lab

Podman DesktopのGUI操作、Kubernetesクラスタ管理、ローカルAI推論（Podman AI Lab）について解説する。

---

## Podman Desktop の概要

Podman Desktopは、コンテナとKubernetes管理のためのオープンソースGUIアプリケーション。CLI操作に比べて、ダッシュボードでの状態確認・ログ閲覧・ターミナル操作が一画面で完結する。

**インストール方法：**

| OS | 方法 |
|----|------|
| Linux | Flatpakでインストール（`flatpak install io.podman_desktop.PodmanDesktop`） |
| macOS | `.dmg`ファイル or `brew install podman-desktop` |
| Windows | WSL2が必要。インストーラー実行後、WSL2バックエンドを有効化 |

---

## GUI コンテナ管理

Podman Desktopの左サイドバーには以下のセクションがある：

| セクション | 説明 |
|-----------|------|
| **Containers** | 実行中・停止中のコンテナ一覧。Logs/Inspect/Terminalタブで操作可能 |
| **Pods** | Podmanポッドの一覧と管理 |
| **Images** | ローカルイメージの一覧・プル・削除 |
| **Volumes** | ボリュームの作成・削除・マウント確認 |
| **Settings** | 拡張機能・リソース・Kubernetes接続の設定 |

### コンテナの詳細操作

コンテナをクリックすると詳細タブが展開される：

| タブ | 用途 |
|------|------|
| **Logs** | `docker logs` 相当。リアルタイムでログを確認 |
| **Inspect** | コンテナのJSON設定（マウント・ネットワーク・環境変数）を確認 |
| **Terminal** | コンテナ内でコマンドを実行（`podman exec -it` 相当） |

---

## Kubernetes クラスタ管理

Podman DesktopはKubernetesクラスタとの統合をサポートする。接続先は `~/.kube/config` で管理される。

### クラスタ接続方式

| 方式 | 説明 |
|------|------|
| 外部クラスタ（`~/.kube/config`） | 既存のEKS・GKE・本番クラスタ等を自動認識 |
| kind（local） | Settings → Resources → Kind → "Create new..." でローカルクラスタ作成 |
| minikube | Settings → Resources → Minikube から起動・停止 |

```bash
# 外部クラスタのkubeconfigを追加
export KUBECONFIG=~/.kube/config:~/other-cluster.yaml
```

### Kubernetes リソース管理

接続後、サイドバーの Kubernetes セクションから以下を操作できる：

- **Deployments**: レプリカ数（desired vs available）の確認、削除
- **Pods**: 個別Pod のLogs/Terminal/Inspectタブ
- **Services**: ClusterIP・NodePort・LoadBalancer の一覧とポート確認

実用例（WordPressが動作しているクラスタの場合）：
- Deployments で `wordpress-pod`・`mysql-pod` を確認
- Services で `wordpress-pod` の NodePort からアクセスポートを特定
- 問題のある Pod は Logs タブでエラーを確認、Terminal タブで設定ファイルを調査

---

## Podman AI Lab

### 概要

Podman AI LabはPodman Desktop組み込みの拡張機能。ローカルAI推論サーバーの構築を数クリックで実現する。コンテナを使って環境構築・依存関係管理・モデルサーバーの起動を自動化し、OpenAI互換のAPIエンドポイントを提供する。

**主な特徴：**
- オープンソースモデルのキュレーションカタログ（Phi、Llama、Mistral等）
- ワンクリックでのモデルダウンロードと推論サーバー起動
- 標準コンテナとして起動するため、既存のコンテナスキルで管理可能
- プライバシー・低コスト・オフライン対応

### AI Lab の有効化

Settings → Extensions → "Podman AI Lab" のトグルをONにする。再起動後、左サイドバーに「AI Lab」アイコンが表示される。

### モデルの起動手順

1. AI Lab → **Catalog** セクションを開く
2. 使用するモデル（例：`Phi-2-GGUF`）を選び、**Download**アイコンをクリック
3. ダウンロード完了後、ロケットアイコンに変わるのでクリック
4. 設定ダイアログで **Create service** をクリック

AI Labは内部で **ramalama** コンテナを起動する。ramamalamはOCIコンテナとしてAIモデルを実行するオープンソースツールで、NVIDIA・AMD・Apple GPUを自動検出し、最適化されたコンテナイメージを使用する。

### APIエンドポイントの取得

AI Lab → Services タブ → 実行中のモデルをクリックすると、**API Endpoint URL** が表示される：

```
http://localhost:8080/v1/chat/completions
```

動作確認：

```bash
# モデル名の確認
curl -H 'accept: application/json' -X 'GET' 'http://localhost:PORT/v1/models'

# チャットAPIのテスト
curl -X POST http://localhost:PORT/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model": "/models/phi-2.Q4_K_M.gguf", "messages": [{"role": "user", "content": "What is Podman?"}]}'
```

### コンテナとしての確認

AI LabはPodmanの標準コンテナとして推論サーバーを起動する。Containers セクションで `ramalama-llama-server` が動作しているのを確認できる。通常のコンテナと同様にLogs・Inspect・Terminalで管理可能。

---

## チャットボット統合（AnythingLLM との連携）

### アーキテクチャ

```
AnythingLLMコンテナ (port 3001)
    ↓ http://host.containers.internal:PORT/v1
AI推論サーバーコンテナ (ramalama)
```

コンテナ間の通信には `host.containers.internal` という特殊DNSを使用する。これにより、AnythingLLMコンテナがホスト経由でAI推論サーバーのポートにアクセスできる。

### AnythingLLM のセットアップ

```bash
# 1. ボリュームのディレクトリ準備（rootlessコンテナのSELinux権限対応）
touch ~/.local/share/containers/storage/volumes/anythingllm/_data/.env
chmod -R 777 ~/.local/share/containers/storage/volumes/anythingllm/_data
```

**コンテナ作成設定（Podman Desktop の Create a container 画面）：**

| 項目 | 設定値 |
|------|--------|
| イメージ | `mintplexlabs/anythingllm` |
| ポート | `3001:3001` |
| ボリューム（データ） | `anythingllm-storage` → `/app/server/storage:z` |
| ボリューム（設定） | `.env` ファイル → `/app/server/.env:z` |
| 環境変数 | `STORAGE_DIR=/app/server/storage` |
| Security Capabilities | `SYS_ADMIN` を追加 |

> `:z` サフィックスはSELinuxがコンテナへの書き込み権限を付与するために必要。

### AnythingLLM の接続設定

`http://localhost:3001` でUIを開き、初期セットアップの「LLM Preference」ステップで以下を設定：

| 項目 | 設定値 |
|------|--------|
| LLM Provider | **Generic OpenAI** |
| Chat Endpoint | `http://host.containers.internal:PORT/v1`（AI LabのポートをPORTに置換） |
| API Key | 空白（ローカルモデルでは不要） |
| Chat Model Name | `/models/phi-2.Q4_K_M.gguf`（`/v1/models` APIで確認した値） |
| Token context window | `4096`（必要に応じて増加） |

---

## 判断フロー：ツール選択

```
Podmanで何を管理したい？
    │
    ├── コンテナ・イメージの視覚的管理
    │     → Podman Desktop（Containers/Images/Volumes）
    │
    ├── ローカルKubernetesクラスタが欲しい
    │     → Settings → Resources → kind または minikube を作成
    │
    ├── 既存クラスタを管理したい
    │     → ~/.kube/config を用意 → Podman Desktopが自動認識
    │
    └── ローカルでAIモデルを動かしたい
          → AI Lab を有効化 → Catalogからモデルを選択
          → OpenAI互換APIで自前アプリと統合
```

### ユーザー確認（AskUserQuestion）

以下について確認が必要な場合がある：

- GPUがあるか？（→ ramamalamが自動検出するが、macOS/Linuxでの動作要件確認）
- ローカルLLMの用途は何か？（→ チャットボットか、アプリ統合かで構成が変わる）
- Kubernetesは本番クラスタか開発用か？（→ 接続方式が変わる）
