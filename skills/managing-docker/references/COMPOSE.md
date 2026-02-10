---
name: managing-docker
description: Docker Compose guide for deploying and managing multi-container microservices applications with declarative YAML configuration.
---

# Docker Compose

Docker Composeを使用したマルチコンテナマイクロサービスアプリケーションのデプロイと管理を解説します。

---

## 概要

Docker Compose（略して「Compose」、大文字Cで表記）は、複数のコンテナで構成されるマイクロサービスアプリケーションを簡単にデプロイ・管理するためのツールです。

### 背景

**進化の歴史:**
1. **Fig**: Orchard Labsが開発したPythonツール
2. **Docker Compose v1**: Docker, Inc.がOrchard Labsを買収し、Figを「Docker Compose」にリブランド
3. **Docker Compose v2**: `docker` CLIに統合され、`docker compose` サブコマンドとして提供

**現在の状況:**
- 全ての最新版Dockerにプリインストール済み
- [Compose Specification](https://www.compose-spec.io/)としてオープン標準化
- Dockerはリファレンス実装を提供

---

## マイクロサービスアプリケーションの課題

### 典型的なマイクロサービス構成

```
┌─────────────────────────────────────┐
│  Multi-Container Application        │
├─────────────────────────────────────┤
│  - Web front-end                    │
│  - Ordering service                 │
│  - Catalog service                  │
│  - Back-end datastore               │
│  - Logging service                  │
│  - Authentication service           │
│  - Authorization service            │
└─────────────────────────────────────┘
```

### Composeによる解決

- **複雑なスクリプトや長いdockerコマンドを排除**
- **宣言的YAML設定ファイル（Compose file）でアプリケーション全体を定義**
- **`docker compose` コマンドで全体をデプロイ・管理**

---

## インストール確認

```bash
# Composeバージョン確認
docker compose version

# 出力例
Docker Compose version v2.35.1
```

---

## Compose File

### 基本構造

Compose fileはYAML形式で記述し、通常は `compose.yaml` または `compose.yml` という名前で保存します。

**トップレベルキー:**
- `services`: マイクロサービス定義（必須）
- `networks`: ネットワーク定義
- `volumes`: ボリューム定義
- `secrets`: シークレット定義
- その他（configs等）

### サンプルCompose File

```yaml
services:
  web-fe:
    deploy:
      replicas: 1
    build: .
    command: python app.py
    ports:
      - target: 8080
        published: 5001
    networks:
      - counter-net

  redis:
    deploy:
      replicas: 1
    image: "redis:alpine"
    networks:
      - counter-net
    volumes:
      - type: volume
        source: counter-vol
        target: /data

networks:
  counter-net:

volumes:
  counter-vol:
```

---

## サービス定義

### Web Front-end サービスの例

```yaml
services:
  web-fe:                     # サービス名（コンテナ名の一部に使用）
    deploy:
      replicas: 1             # デプロイするコンテナ数
    build: .                  # カレントディレクトリのDockerfileからビルド
    command: python app/app.py # コンテナ起動時に実行するコマンド
    ports:
      - target: 8080          # コンテナ内のポート
        published: 5001       # ホストのポート（5001→8080にマッピング）
    networks:
      - counter-net           # 接続するネットワーク
```

**重要なフィールド:**
- `deploy.replicas`: レプリカ数（Docker Desktopではポート競合により1のみ推奨）
- `build`: Dockerfileの場所（`.` = カレントディレクトリ）
- `command`: コンテナ起動コマンド（Dockerfileの `ENTRYPOINT`/`CMD` を上書き）
- `ports`: ポートマッピング
- `networks`: 接続するネットワーク名

### Redisサービスの例

```yaml
services:
  redis:                      # サービス名
    image: "redis:alpine"     # Docker Hubから取得するイメージ
    deploy:
      replicas: 1
    networks:
      - counter-net           # 接続するネットワーク
    volumes:
      - type: volume
        source: counter-vol   # マウントするボリューム名
        target: /data         # コンテナ内のマウントポイント
```

**重要なフィールド:**
- `image`: Docker Hubまたはレジストリから取得するイメージ
- `volumes`: マウントするボリューム（永続データ用）

---

## ネットワークとボリューム定義

### ネットワーク

```yaml
networks:
  counter-net:    # ネットワーク名
```

デフォルトでは `bridge` ドライバーが使用されます。

### ボリューム

```yaml
volumes:
  counter-vol:    # ボリューム名
```

デフォルトでは `local` ドライバーが使用されます。

---

## サービス間通信

同じネットワークに接続されたサービスは、**サービス名で相互に通信**できます。

### 例: アプリケーションコードでの名前解決

```python
import redis
from flask import Flask

app = Flask(__name__)
cache = redis.Redis(host='redis', port=6379)  # 'redis'はサービス名
```

**仕組み:**
- DockerのembeddedDNSサーバーがサービス名をIPアドレスに解決
- 同じネットワーク上のサービスのみ解決可能

---

## アプリケーションのデプロイ

### 基本デプロイ

```bash
# compose.yamlがあるディレクトリで実行
docker compose up --detach

# 出力例
[+] Building 613s (11/11) FINISHED
[+] Running 5/5
 - Network multi-container_counter-net   Created
 - Volume "multi-container_counter-vol"  Created
 - Container multi-container-redis-1     Created
 - Container multi-container-web-fe-1    Created
```

**動作:**
1. イメージのビルド（`build`指定の場合）
2. イメージのpull（`image`指定の場合）
3. ネットワークの作成
4. ボリュームの作成
5. コンテナの起動

### カスタムComposeファイルの指定

```bash
# -f フラグでファイル名とパスを指定
docker compose -f apps/myproject/sample-app.yml up --detach
```

---

## リソースの命名規則

Composeは以下の命名規則でリソースを作成します：

**フォーマット:** `<project-name>_<resource-name>[-replica-number]`

| リソースタイプ | 定義名 | 実際の名前 |
|--------------|--------|-----------|
| サービス | web-fe | multi-container-web-fe-1 |
| サービス | redis | multi-container-redis-1 |
| ネットワーク | counter-net | multi-container_counter-net |
| ボリューム | counter-vol | multi-container_counter-vol |

**プロジェクト名:**
- デフォルト: ビルドコンテキストのディレクトリ名
- カスタマイズ: `--project-name` フラグで指定可能

---

## アプリケーション管理

### 状態確認

```bash
# アプリケーション内のコンテナ一覧
docker compose ps

# 出力例
NAME                       COMMAND                 SERVICE    STATUS        PORTS
multi-container-redis-1    "docker-entrypoint..."  redis      Up 33 sec     6379/tcp
multi-container-web-fe-1   "python app/app.py"     web-fe     Up 33 sec     0.0.0.0:5001->8080

# コンテナ内のプロセス一覧
docker compose top

# アプリケーション一覧
docker compose ls

# 出力例
NAME               STATUS       CONFIG FILES
multi-container    running(2)   /path/to/compose.yaml
```

### ログ確認

```bash
# 全サービスのログ表示
docker compose logs

# 特定サービスのログ表示
docker compose logs web-fe

# リアルタイムログ追跡
docker compose logs -f
```

### 停止と再起動

```bash
# アプリケーション停止（コンテナは削除されない）
docker compose stop

# アプリケーション再起動
docker compose restart

# 状態確認（停止中も表示）
docker compose ps -a
```

### 削除

```bash
# コンテナとネットワークを削除（ボリュームとイメージは保持）
docker compose down

# ボリュームも削除
docker compose down --volumes

# イメージも削除
docker compose down --rmi all

# 全て削除
docker compose down --volumes --rmi all
```

---

## デプロイメントパターン

### 開発環境

```yaml
services:
  web:
    build: .
    volumes:
      - .:/app              # ホストのコードをマウント
    environment:
      - DEBUG=true
    ports:
      - "5001:8080"
```

**特徴:**
- ホストのコードをボリュームマウント（ホットリロード可能）
- デバッグモード有効
- ポートを直接公開

### 本番環境

```yaml
services:
  web:
    image: myapp:1.0.0      # ビルド済みイメージ使用
    deploy:
      replicas: 3           # 複数レプリカ
      restart_policy:
        condition: on-failure
    environment:
      - DEBUG=false
    networks:
      - frontend
      - backend
```

**特徴:**
- ビルド済みイメージ使用
- 複数レプリカでスケール
- 再起動ポリシー設定
- 複数ネットワークで分離

---

## 高度な設定

### 環境変数

```yaml
services:
  web:
    environment:
      - NODE_ENV=production
      - API_KEY=${API_KEY}    # ホストの環境変数から取得
    env_file:
      - .env                  # ファイルから環境変数を読み込み
```

### 依存関係

```yaml
services:
  web:
    depends_on:
      - db
      - redis

  db:
    image: postgres:15

  redis:
    image: redis:alpine
```

**注意:**
- `depends_on` は起動順序のみ制御
- サービスの準備完了は待たない

### ヘルスチェック

```yaml
services:
  web:
    image: nginx
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

### リソース制限

```yaml
services:
  web:
    image: nginx
    deploy:
      resources:
        limits:
          cpus: '0.50'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 256M
```

---

## 主要コマンド一覧

### デプロイと管理

```bash
# アプリケーションデプロイ
docker compose up --detach

# 特定のサービスのみ起動
docker compose up -d web-fe

# スケール（レプリカ数変更）
docker compose up -d --scale web-fe=3

# ビルドからデプロイ
docker compose up --build

# フォアグラウンドで起動（ログ表示）
docker compose up
```

### 状態確認

```bash
# コンテナ一覧
docker compose ps

# 全コンテナ（停止中も含む）
docker compose ps -a

# プロセス一覧
docker compose top

# ログ表示
docker compose logs
docker compose logs -f         # リアルタイム
docker compose logs web-fe     # 特定サービス
```

### 停止と削除

```bash
# 停止
docker compose stop

# 再起動
docker compose restart

# 一時停止
docker compose pause

# 再開
docker compose unpause

# 削除（コンテナとネットワーク）
docker compose down

# 削除（ボリュームも）
docker compose down --volumes

# 削除（イメージも）
docker compose down --rmi all
```

### その他

```bash
# イメージビルド
docker compose build

# イメージpull
docker compose pull

# 設定ファイル検証
docker compose config

# 実行中のサービスでコマンド実行
docker compose exec web-fe sh

# 新しいコンテナでコマンド実行
docker compose run web-fe python manage.py test
```

---

## ベストプラクティス

### Compose File設計

| 原則 | 説明 |
|------|------|
| **バージョン管理** | Compose fileをGit等で管理 |
| **環境分離** | 開発・ステージング・本番で異なるファイル使用 |
| **シークレット管理** | 機密情報は環境変数またはsecretsで管理 |
| **ドキュメント化** | コメントで設定の意図を明記 |

### セキュリティ

- **最小権限**: 必要最小限のポート公開
- **ネットワーク分離**: フロントエンドとバックエンドを分離
- **イメージ検証**: 信頼できるイメージのみ使用
- **定期更新**: ベースイメージとライブラリを最新化

### パフォーマンス

- **ビルドキャッシュ活用**: レイヤーを効率的に配置
- **マルチステージビルド**: イメージサイズを最小化
- **リソース制限**: 適切なCPU/メモリ制限を設定

### 運用

- **ログ管理**: 適切なログドライバーを選択
- **監視**: ヘルスチェックを実装
- **バックアップ**: ボリュームデータを定期バックアップ
- **ドキュメント**: README.mdでデプロイ手順を文書化

---

## トラブルシューティング

### よくある問題

| 問題 | 原因 | 解決方法 |
|------|------|----------|
| コンテナが起動しない | イメージビルドエラー | `docker compose build` でエラー確認 |
| ポート競合 | 既に使用中 | `docker compose ps` で確認、ポート変更 |
| ネットワーク通信不可 | 異なるネットワーク | 同じネットワークに接続 |
| ボリュームデータ消失 | `--volumes` フラグ使用 | バックアップから復元 |

### デバッグコマンド

```bash
# 設定検証（YAML構文チェック）
docker compose config

# サービス詳細確認
docker compose ps
docker inspect <container-name>

# ログ確認
docker compose logs -f

# コンテナ内でシェル起動
docker compose exec <service-name> sh
```

---

## チェックリスト

### デプロイ前

- [ ] Compose fileの構文検証（`docker compose config`）
- [ ] 必要なイメージがビルド/pull可能か確認
- [ ] ポート競合がないか確認
- [ ] 環境変数が正しく設定されているか確認
- [ ] ボリュームのバックアップが存在するか確認

### デプロイ後

- [ ] 全コンテナが起動しているか確認（`docker compose ps`）
- [ ] サービス間通信が動作しているか確認
- [ ] ヘルスチェックが成功しているか確認
- [ ] ログにエラーがないか確認
- [ ] 外部からアクセス可能か確認

### 運用中

- [ ] リソース使用量を監視
- [ ] ログを定期的に確認
- [ ] ボリュームデータをバックアップ
- [ ] イメージを定期的に更新

---

## 判断フローチャート

### Compose vs Kubernetes

```
Q: どのオーケストレーターを使用するか？
├─ Q: デプロイ規模は？
│  ├─ 小規模（1-3ホスト）
│  │  └─ → Docker Compose
│  │
│  └─ 大規模（4+ホスト）
│     └─ Q: 高度な機能が必要か？
│        ├─ Yes（自動スケーリング、ローリングアップデート等）
│        │  └─ → Kubernetes
│        │
│        └─ No
│           └─ → Docker Compose + Docker Swarm
│
└─ Q: チームのスキルセットは？
   ├─ Kubernetes経験あり → Kubernetes
   └─ Docker経験のみ → Docker Compose
```

---

## 実践例

### シンプルなWebアプリ

```yaml
services:
  web:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./html:/usr/share/nginx/html

  app:
    build: ./app
    environment:
      - DATABASE_URL=postgresql://db/myapp
    depends_on:
      - db

  db:
    image: postgres:15
    environment:
      - POSTGRES_PASSWORD=secret
    volumes:
      - db-data:/var/lib/postgresql/data

volumes:
  db-data:
```

### マイクロサービスアーキテクチャ

```yaml
services:
  frontend:
    image: myapp/frontend:latest
    networks:
      - frontend-net
    ports:
      - "80:80"

  api:
    image: myapp/api:latest
    networks:
      - frontend-net
      - backend-net
    environment:
      - DATABASE_URL=postgresql://db/myapp

  auth:
    image: myapp/auth:latest
    networks:
      - backend-net

  db:
    image: postgres:15
    networks:
      - backend-net
    volumes:
      - db-data:/var/lib/postgresql/data

networks:
  frontend-net:
  backend-net:

volumes:
  db-data:
```

---

このガイドは標準的なDocker Composeのベストプラクティスをまとめたものです。具体的な環境に応じて設定を調整してください。
