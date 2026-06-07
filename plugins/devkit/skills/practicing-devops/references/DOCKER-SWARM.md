---
description: Docker Swarm基礎。クラスタ構築・サービス管理の基本コマンドを解説。Kubernetes主流の現代では基礎知識のみ提供。
---

# Docker Swarm (基礎編)

**注**: Docker SwarmはKubernetesが主流となった現代では使用頻度が低下している。本ドキュメントは基本概念とコマンドのみを提供し、詳細な運用手順やトラブルシューティングは省略する。

---

## 📋 目次

- [Swarm概要](#swarm概要)
- [基本概念](#基本概念)
- [クラスタ構築](#クラスタ構築)
- [アプリケーションデプロイ](#アプリケーションデプロイ)
- [コマンドリファレンス](#コマンドリファレンス)

---

## Swarm概要

### Docker Swarmとは

**Docker Swarm** は2つの意味を持つ：

1. **swarm (小文字)**: 複数のDockerノードで構成される安全なクラスタ
2. **Swarm (大文字)**: アプリケーションオーケストレーション機能

### 用途

| 使用場面 | 理由 |
|---------|------|
| **小規模ビジネス** | Kubernetesの学習曲線やオーバーヘッドが不要 |
| **シンプルな要件** | 複雑なオーケストレーションが不要な場合 |
| **Kubernetes学習の入門** | Swarmで基礎を学んでからKubernetesへ |

**現在の位置づけ**: Kubernetesが主流。Swarmは小規模・シンプルなユースケース向け。

---

## 基本概念

### ノード構成

```
┌─────────────────────────────────────────┐
│          Swarmクラスタ                   │
│                                          │
│  ┌────────────┐  ┌────────────┐         │
│  │  Manager   │  │  Manager   │         │
│  │  (Leader)  │  │(Reachable) │         │
│  └────────────┘  └────────────┘         │
│        │                │                │
│  ┌─────┴────────────────┴─────┐         │
│  │                            │         │
│  ▼                            ▼         │
│  ┌────────────┐       ┌────────────┐   │
│  │  Worker    │       │  Worker    │   │
│  └────────────┘       └────────────┘   │
└─────────────────────────────────────────┘
```

#### ノードタイプ

| タイプ | 役割 | 特徴 |
|--------|------|------|
| **Manager** | コントロールプレーン管理 | - クラスタ状態管理<br>- タスクスケジューリング<br>- ユーザーアプリも実行可能 (デフォルト) |
| **Worker** | アプリ実行 | - ユーザーアプリのみ実行<br>- クラスタ管理機能なし |

#### 高可用性 (HA)

| Manager数 | 許容障害数 | 推奨環境 |
|-----------|-----------|---------|
| 1 | 0 | テスト環境のみ |
| 3 | 1 | **本番推奨** |
| 5 | 2 | 大規模環境 |
| 7 | 3 | 超大規模環境 |

**重要**: 本番環境では**奇数個のManager**を複数AZ (Availability Zone) に分散配置。

---

## クラスタ構築

### 前提条件

- 各ノードがDockerをインストール済み
- ノード間でポート2377が開放されている
- DNS名前解決が設定済み (推奨)

### 1. Swarm初期化

**最初のManagerノードで実行**:
```bash
docker swarm init
```

**複数IPアドレスを持つ場合**:
```bash
docker swarm init --advertise-addr <PRIMARY-IP>
```

**出力例**:
```
Swarm initialized: current node (b8slc7...) is now a manager.

To add a worker to this swarm, run the following command:
  docker swarm join --token SWMTKN-1-2hl6...-...3lqg 172.31.40.192:2377
```

### 2. Workerノード追加 (オプション)

**Workerトークン取得** (Managerで実行):
```bash
docker swarm join-token worker
```

**Workerノードで実行**:
```bash
docker swarm join --token SWMTKN-1-2hl6...-...3lqg 172.31.40.192:2377
```

### 3. 追加Managerノード追加

**Managerトークン取得** (既存Managerで実行):
```bash
docker swarm join-token manager
```

**追加Managerノードで実行**:
```bash
docker swarm join --token SWMTKN-1-2f4s...-...uei9 172.31.40.192:2377
```

### 4. クラスタ確認

```bash
docker node ls
```

**出力例**:
```
ID                            HOSTNAME   STATUS   MANAGER STATUS
b8slc7l29tgdetxgy8acy1k1q *   node1      Ready    Leader
y43jr1d754pbjv3arlhpn9pqw     node2      Ready    Reachable
k1npnfxr7ykueac4jovmyiv0b     node3      Ready    Reachable
w3e321uxty2quuqnsk1w19kfc     node4      Ready    (Worker)
kbodotf68tz8dne2ktk1g5mt4     node5      Ready    (Worker)
```

**用語**:
- **Leader**: アクティブなManagerノード
- **Reachable**: バックアップManagerノード
- **(空欄)**: Workerノード

---

## アプリケーションデプロイ

### Swarmアプリの構成要素

| 要素 | 説明 |
|------|------|
| **Service** | 同一コンテナの集合 (例: web-fe service) |
| **Replica** | Serviceを構成する個々のコンテナ |
| **Task** | Replicaのスケジュール単位 |
| **Stack** | 複数ServiceをまとめたComposeアプリ |

### Compose定義例

```yaml
networks:
  counter-net:
    driver: overlay
    driver_opts:
      encrypted: 'yes'  # 暗号化ネットワーク

volumes:
  counter-vol:

services:
  web-fe:
    image: myapp:latest
    deploy:
      replicas: 4  # 4つのReplicaを起動
      update_config:
        parallelism: 2  # 2つずつ更新
        delay: 10s      # 10秒待機
        failure_action: rollback  # 失敗時ロールバック
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
    networks:
      - counter-net
    ports:
      - "5001:8080"

  redis:
    image: redis:alpine
    networks:
      - counter-net
    volumes:
      - type: volume
        source: counter-vol
        target: /data
```

### デプロイ

```bash
docker stack deploy -c compose.yaml myapp
```

**出力例**:
```
Creating network myapp_counter-net
Creating service myapp_web-fe
Creating service myapp_redis
```

### アプリ確認

```bash
# Stack一覧
docker stack ls

# Replica詳細
docker stack ps myapp

# Service詳細
docker stack services myapp
```

---

## 宣言的管理 (推奨)

### 重要原則

**すべての変更はCompose ファイルで行う**

| 方法 | 説明 | 推奨 |
|------|------|------|
| **宣言的 (Declarative)** | Composeファイルを編集して再デプロイ | ✅ 推奨 |
| **命令的 (Imperative)** | `docker service scale` などのCLI | ❌ 非推奨 |

### なぜ宣言的管理か

**問題シナリオ**:
1. Composeファイルで `replicas: 1` と定義
2. 同僚が `docker service scale reporting=10` で10に増やす
3. 後日、別のServiceを更新するため `docker stack deploy` 実行
4. **結果**: replicaが1に戻る (Composeファイルの定義が正)

**教訓**: Composeファイルが唯一の信頼できる情報源 (Single Source of Truth)。

### 正しい更新フロー

**1. Composeファイル編集**:
```yaml
services:
  web-fe:
    image: myapp:v2  # ← v1からv2に変更
    deploy:
      replicas: 10   # ← 4から10に変更
```

**2. 再デプロイ**:
```bash
docker stack deploy -c compose.yaml myapp
```

**3. 更新進捗確認**:
```bash
docker stack ps myapp
```

**Swarmの動作**:
- 既存4 ReplicaをローリングアップデートでimageをV2に更新
- 新規6 Replicaを追加
- `update_config` の設定 (parallelism, delay) に従って実行

---

## コマンドリファレンス

### クラスタ管理

| コマンド | 説明 |
|---------|------|
| `docker swarm init` | Swarm初期化 (最初のManager作成) |
| `docker swarm join-token manager` | Managerトークン表示 |
| `docker swarm join-token worker` | Workerトークン表示 |
| `docker swarm join-token --rotate <role>` | トークンローテーション |
| `docker swarm leave [-f]` | ノードをSwarmから削除 |
| `docker swarm update --cert-expiry <duration>` | 証明書ローテーション期間変更 |
| `docker node ls` | ノード一覧表示 |

### アプリ管理

| コマンド | 説明 |
|---------|------|
| `docker stack deploy -c <file> <name>` | アプリをデプロイ/更新 |
| `docker stack ls` | Stack一覧表示 |
| `docker stack ps <name>` | Replica詳細表示 |
| `docker stack services <name>` | Service一覧表示 |
| `docker stack rm <name>` | アプリ削除 (確認なし) |

### Service管理 (非推奨: 宣言的管理を優先)

| コマンド | 説明 |
|---------|------|
| `docker service ls` | Service一覧 |
| `docker service ps <service>` | Service詳細 |
| `docker service scale <service>=<num>` | Replica数変更 (非推奨) |
| `docker service update <service>` | Service更新 (非推奨) |

---

## クリーンアップ

### アプリ削除

```bash
# Stack削除 (確認なし)
docker stack rm myapp
```

**注**: Volumeは削除されない (ライフサイクル分離)。

### Volume削除

```bash
# Volumeを使用していたノードで実行
docker volume rm myapp_counter-vol
```

### Swarm削除

```bash
# すべてのノードで実行 (Leaderは最後)
docker swarm leave

# Leader削除 (強制)
docker swarm leave --force
```

---

## Swarm vs Kubernetes

| 項目 | Docker Swarm | Kubernetes |
|------|-------------|-----------|
| **学習曲線** | 緩やか | 急峻 |
| **セットアップ** | 簡単 (`docker swarm init`) | 複雑 (多くのコンポーネント) |
| **エコシステム** | 小規模 | 巨大 (CNCF) |
| **用途** | 小規模・シンプル | 大規模・複雑 |
| **現在の人気** | 低下中 | 圧倒的シェア |

**結論**: Kubernetes学習を推奨。Swarmは入門やシンプルなユースケース向け。

---

## まとめ

### Swarmの基本

- ✅ **簡単なセットアップ**: `docker swarm init` だけでクラスタ作成
- ✅ **宣言的管理**: Composeファイルでアプリを定義・更新
- ✅ **自動スケジューリング**: ノード間でReplicaを自動分散
- ✅ **セルフヒーリング**: 障害発生時に自動復旧
- ✅ **ローリングアップデート**: 無停止でアプリ更新

### 重要な制約

- ⚠️ **Kubernetes主流**: 本番環境では通常Kubernetesを選択
- ⚠️ **エコシステム**: Swarmのツール・統合は限定的
- ⚠️ **詳細な運用知識**: 本ドキュメントは基礎のみ (詳細は別途学習が必要)

### 次のステップ

Kubernetesを学ぶことを強く推奨：
- **Quick Start Kubernetes**: Kubernetes基礎を最速でマスター
- **The Kubernetes Book**: Kubernetesの詳細な解説

**Swarmの価値**: Kubernetesの概念 (宣言的管理、Desired State、Orchestration) を簡単に学べる入門ツールとして有用。
