---
name: managing-docker
description: Docker volumes guide for persistent data management, covering volume lifecycle, mounting strategies, and best practices.
---

# Dockerボリュームと永続データ

Dockerにおける永続データ管理の基礎から、ボリュームの作成・マウント・共有までを解説します。

---

## データの種類

### 永続データ（Persistent Data）

**定義:** 保持する必要がある重要なデータ

**例:**
- 顧客記録
- 財務データ
- 研究結果
- 監査データ
- 一部のログ

**アプリケーション:** Stateful apps（状態を持つアプリケーション）

### 非永続データ（Non-Persistent Data）

**定義:** 保持する必要がない一時的なデータ

**例:**
- スクラッチデータ
- 一時ファイル
- キャッシュ

**アプリケーション:** Stateless apps（状態を持たないアプリケーション）

---

## ボリュームなしのコンテナ

### エフェメラルストレージ（Ephemeral Storage）

すべてのコンテナはデフォルトで非永続的なローカルストレージを持ちます。

**特徴:**
- コンテナ作成時に自動作成
- コンテナ削除時に自動削除
- コンテナのライフサイクルに紐づく
- 読み書き可能な薄い層（thin writable layer）

**別名:**
- Thin writable layer
- Read-write storage
- Local storage
- Graphdriver storage

**保存場所:**
- Linuxコンテナ: `/var/lib/docker/<storage-driver>/...`
- Windowsコンテナ: `C:\ProgramData\Docker\windowsfilter\...`

### 構造

コンテナは以下のレイヤー構造で構成されます：

```
┌─────────────────────────────┐
│ 薄い読み書き可能層（Local）  │ ← エフェメラルストレージ
├─────────────────────────────┤
│ 読み取り専用イメージ層       │
│ （複数のコンテナで共有可能） │
└─────────────────────────────┘
```

### 制約事項

- **ライフサイクルに依存**: コンテナ削除でデータも消失
- **Immutable Infrastructureの原則**: デプロイ後のコンテナは変更しない
- **設定変更の推奨方法**: 新しいコンテナを作成して置き換える

**注意:**
- データベース等のアプリケーションはデータを変更可能
- ただし、ユーザーや運用ツールはコンテナの設定（ネットワーク、アプリケーション設定等）を変更すべきでない

---

## ボリュームの基礎

### ボリュームを使用する理由

1. **ライフサイクルの独立**: コンテナのライフサイクルと切り離された独立オブジェクト
2. **外部ストレージ対応**: 専門的な外部ストレージシステムにマッピング可能
3. **データ共有**: 異なるDockerホスト上の複数コンテナで同じデータにアクセス可能

### 基本概念

```
┌─────────────────────┐
│   Container         │
│                     │
│   /data ───────┐    │
└────────────────┼────┘
                 │
                 ↓ マウント
         ┌──────────────┐
         │   Volume     │ ← 独立オブジェクト
         │  (永続化)     │
         └──────────────┘
                 │
                 ↓ マッピング可能
         ┌──────────────┐
         │ 外部ストレージ │
         │ or ホストFS   │
         └──────────────┘
```

### ボリュームのライフサイクル

1. **作成**: `docker volume create`
2. **マウント**: コンテナ起動時に指定されたディレクトリにマウント
3. **使用**: アプリケーションがマウントポイントにデータを書き込み
4. **保持**: コンテナ削除後もボリュームとデータは存在
5. **再利用**: 別のコンテナにマウント可能
6. **削除**: `docker volume rm` で明示的に削除

---

## ボリュームの作成と管理

### 基本コマンド

```bash
# ボリューム作成
docker volume create myvol

# ボリューム一覧表示
docker volume ls

# ボリューム詳細確認
docker volume inspect myvol

# ボリューム削除
docker volume rm myvol

# 未使用ボリュームを全削除（注意！）
docker volume prune --all
```

### ボリューム詳細の確認

```bash
$ docker volume inspect myvol
[
    {
        "CreatedAt": "2024-05-15T12:23:14Z",
        "Driver": "local",
        "Labels": null,
        "Mountpoint": "/var/lib/docker/volumes/myvol/_data",
        "Name": "myvol",
        "Options": null,
        "Scope": "local"
    }
]
```

**重要なフィールド:**
- `Driver`: ボリュームドライバー（デフォルトは `local`）
- `Scope`: スコープ（`local` = 単一ホストのみ）
- `Mountpoint`: Dockerホスト上の実際の保存場所

### ボリュームドライバー

**ビルトインドライバー:**
- `local`: デフォルト、単一Dockerホスト上でのみ利用可能

**サードパーティドライバー:**
- クラウドストレージサービス（AWS EBS、Azure Disk等）
- オンプレミスストレージ（SAN、NAS等）
- 高度な機能（レプリケーション、スナップショット等）を提供

```bash
# サードパーティドライバーを指定してボリューム作成
docker volume create -d <driver-name> myvol
```

### ボリュームの削除

```bash
# 特定のボリュームを削除
docker volume rm myvol

# 全ての未使用ボリュームを削除
docker volume prune --all
```

**注意事項:**
- コンテナまたはサービスレプリカが使用中のボリュームは削除不可
- `prune` コマンドは慎重に使用（重要なデータを失う可能性）

---

## コンテナでボリュームを使用

### ボリュームのマウント

```bash
# 新しいコンテナを作成してボリュームをマウント
docker run -it --name voltainer \
  --mount source=bizvol,target=/vol \
  alpine
```

**動作:**
- `bizvol` が存在する場合: 既存のボリュームを使用
- `bizvol` が存在しない場合: 自動的に作成してマウント

### ボリュームへのデータ書き込み

```bash
# コンテナに接続
docker exec -it voltainer sh

# ボリュームにデータ書き込み
echo "Important data" > /vol/file1

# データ確認
cat /vol/file1
ls -l /vol
```

### コンテナ削除後のボリューム確認

```bash
# コンテナ削除
docker rm voltainer -f

# ボリューム確認（存在する）
docker volume ls

# ホストファイルシステムで直接確認（非推奨）
ls -l /var/lib/docker/volumes/bizvol/_data/
cat /var/lib/docker/volumes/bizvol/_data/file1
```

**重要:**
- ボリュームはコンテナから独立して存在
- ホストファイルシステムから直接アクセス可能だが**非推奨**

### ボリュームの再利用

```bash
# 既存のボリュームを新しいコンテナにマウント
docker run -it --name newctr \
  --mount source=bizvol,target=/vol \
  alpine sh

# データが保持されているか確認
cat /vol/file1
```

---

## Dockerfileでのボリューム定義

### VOLUME命令

```dockerfile
FROM alpine
VOLUME /data
```

**特徴:**
- コンテナ内のマウントポイントのみ指定可能
- ホストディレクトリは指定不可（OS間の互換性のため）
- デプロイ時にホストディレクトリを指定する必要がある

---

## クラスタ間でのストレージ共有

### 外部ストレージシステムとの統合

複数のDockerホストに同じボリュームを提示することで、異なるノード上のコンテナが同じデータにアクセス可能になります。

```
┌─────────────────┐         ┌─────────────────┐
│  Docker Host 1  │         │  Docker Host 2  │
│  ┌───────────┐  │         │  ┌───────────┐  │
│  │Container 1│  │         │  │Container 2│  │
│  └─────┬─────┘  │         │  └─────┬─────┘  │
│        │ mount  │         │        │ mount  │
│        ↓        │         │        ↓        │
│   ┌─────────┐   │         │   ┌─────────┐   │
│   │ Driver  │   │         │   │ Driver  │   │
│   └────┬────┘   │         │   └────┬────┘   │
└────────┼────────┘         └────────┼────────┘
         │                           │
         └───────────┬───────────────┘
                     ↓
            ┌─────────────────┐
            │  External       │
            │  Storage System │
            │  (SAN/NAS/Cloud)│
            └─────────────────┘
```

### 要件

1. **外部ストレージシステム**: クラウドストレージ、SAN、NAS等
2. **ボリュームドライバー**: 外部システムに対応したドライバー
3. **アプリケーション設計**: データ破損を防ぐための適切な読み書き設計

---

## データ破損のリスク

### 問題のシナリオ

```
時刻  Container 1            Container 2          共有ボリューム
─────────────────────────────────────────────────────────
t1    データ更新(値=A)
      ローカルキャッシュに保持

t2                          データ更新(値=B)      値=B
                            直接コミット

t3    キャッシュフラッシュ                        値=A (上書き!)

結果: Container 2の更新が失われる
```

### 対策

- **アプリケーションレベルの調整**: 共有データへの更新を協調
- **ロック機構**: 排他制御を実装
- **トランザクション管理**: ACID特性を保証
- **メッセージキュー**: 更新を順序付け

---

## ボリュームのベストプラクティス

### 設計原則

| 原則 | 説明 |
|------|------|
| **分離** | アプリケーションデータと設定を別ボリュームに分離 |
| **命名規則** | 明確で説明的な名前を使用 |
| **バックアップ** | 定期的なバックアップを実施 |
| **監視** | ボリューム使用量を監視 |

### セキュリティ

- **アクセス制御**: 必要なコンテナのみにマウント
- **暗号化**: 機密データには暗号化ボリュームを使用
- **監査**: ボリュームアクセスをログ記録

### パフォーマンス

- **ローカルボリューム優先**: 可能な限りローカルドライバーを使用
- **I/O最適化**: 高I/Oワークロード用には専用ストレージを検討
- **キャッシング**: 適切なキャッシング戦略を実装

### 運用

- **ラベル活用**: メタデータでボリュームを分類
- **定期的なクリーンアップ**: 未使用ボリュームを削除
- **IaC管理**: Compose fileやTerraformで管理

---

## Docker Composeでのボリューム管理

### Composeファイルでの定義

```yaml
services:
  web:
    image: nginx
    volumes:
      - type: volume
        source: web-data
        target: /usr/share/nginx/html

volumes:
  web-data:
```

### ボリュームマウントのオプション

```yaml
volumes:
  - type: volume          # ボリュームタイプ
    source: mydata        # ボリューム名
    target: /app          # コンテナ内のマウントポイント
    read_only: true       # 読み取り専用（オプション）
```

### Named Volumesの利点

- **宣言的**: Composeファイルで明示的に定義
- **自動作成**: 存在しない場合は自動作成
- **プロジェクトスコープ**: プロジェクト名でプレフィックス付与

---

## 主要コマンド一覧

```bash
# ボリューム作成
docker volume create <volume-name>

# ボリューム一覧表示
docker volume ls

# ボリューム詳細確認
docker volume inspect <volume-name>

# ボリューム削除
docker volume rm <volume-name>

# 未使用ボリューム全削除
docker volume prune --all

# コンテナにボリュームをマウントして起動
docker run --mount source=<volume>,target=<path> <image>

# または -v フラグを使用（古い書式）
docker run -v <volume>:<path> <image>
```

---

## トラブルシューティング

### よくある問題

| 問題 | 原因 | 解決方法 |
|------|------|----------|
| ボリュームが削除できない | コンテナが使用中 | `docker ps -a` で確認し、コンテナを停止・削除 |
| データが消えた | エフェメラルストレージを使用 | ボリュームを使用するように変更 |
| パーミッションエラー | UID/GIDの不一致 | Dockerfileで適切なユーザー設定 |
| 容量不足 | ボリュームが満杯 | 不要なデータを削除、または容量拡張 |

### デバッグコマンド

```bash
# ボリュームを使用しているコンテナを確認
docker ps -a --filter volume=<volume-name>

# ボリュームのマウント情報確認
docker inspect <container-name> | grep -A 10 "Mounts"

# ホスト上のボリュームディレクトリ確認
ls -la /var/lib/docker/volumes/<volume-name>/_data
```

---

## チェックリスト

### デプロイ前

- [ ] 永続データの要件を明確化
- [ ] 適切なボリュームドライバーを選択
- [ ] ボリューム命名規則を定義
- [ ] バックアップ戦略を計画

### デプロイ後

- [ ] ボリュームが正しくマウントされているか確認
- [ ] データが正しく書き込まれているか検証
- [ ] パーミッションが適切か確認
- [ ] バックアップが正常に動作しているか確認

### 運用中

- [ ] ボリューム使用量を定期的に監視
- [ ] 未使用ボリュームを定期的にクリーンアップ
- [ ] バックアップの定期的な検証
- [ ] ボリュームアクセスログの確認

---

## 判断フローチャート

### ストレージ選択

```
Q: データを保持する必要があるか？
├─ No
│  └─ → エフェメラルストレージ（デフォルト）
│
└─ Yes
   ├─ Q: 単一ホストか複数ホストか？
   │  ├─ 単一ホスト
   │  │  └─ → local ドライバー
   │  │
   │  └─ 複数ホスト
   │     └─ Q: 外部ストレージシステムがあるか？
   │        ├─ Yes → サードパーティドライバー
   │        └─ No → 外部ストレージの導入を検討
   │
   └─ Q: パフォーマンス要件は？
      ├─ 高I/O → 専用ストレージ + 適切なドライバー
      └─ 標準 → local ドライバー
```

---

## ステートフルコンテナパターン

永続データを必要とするアプリケーション（DB、設定ファイル、ログ等）のボリューム活用パターン。

### データベース永続化

**PostgreSQL例:**
```yaml
# docker-compose.yml
services:
  postgres:
    image: postgres:17
    volumes:
      - postgres-data:/var/lib/postgresql/data
    environment:
      POSTGRES_PASSWORD: example
    restart: unless-stopped

volumes:
  postgres-data:
```

**MySQL例:**
```yaml
services:
  mysql:
    image: mysql:9
    volumes:
      - mysql-data:/var/lib/mysql
    environment:
      MYSQL_ROOT_PASSWORD: example
    restart: unless-stopped

volumes:
  mysql-data:
```

**MongoDB例:**
```yaml
services:
  mongo:
    image: mongo:8
    volumes:
      - mongo-data:/data/db
      - mongo-config:/data/configdb
    restart: unless-stopped

volumes:
  mongo-data:
  mongo-config:
```

---

### 設定ファイルマウント

**単一設定ファイル:**
```bash
# ホストの設定ファイルをコンテナにマウント
docker run -d \
  -v $(pwd)/nginx.conf:/etc/nginx/nginx.conf:ro \
  nginx
```

**複数設定ファイル（ディレクトリ）:**
```yaml
services:
  app:
    image: myapp:latest
    volumes:
      - ./config:/etc/myapp:ro  # 読み取り専用
      - app-data:/var/lib/myapp
```

**環境別設定:**
```yaml
services:
  app:
    image: myapp:latest
    volumes:
      - ./config/${ENV:-dev}:/etc/myapp:ro
    environment:
      - ENV=${ENV:-dev}
```

---

### ログ永続化

**ログボリュームパターン:**
```yaml
services:
  web:
    image: nginx
    volumes:
      - web-logs:/var/log/nginx
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  log-processor:
    image: fluentd
    volumes:
      - web-logs:/logs:ro  # 読み取り専用
    depends_on:
      - web

volumes:
  web-logs:
```

**ログローテーション対応:**
```bash
# ホストでcronによるローテーション
docker run -d \
  -v /var/log/app:/var/log/app \
  --log-driver json-file \
  --log-opt max-size=50m \
  --log-opt max-file=5 \
  myapp:latest
```

---

## ホストボリュームパターン

ホストディレクトリを直接マウントする活用パターン。

### 開発時のbind mount活用

**ホットリロード開発:**
```yaml
services:
  dev:
    image: node:20
    volumes:
      - ./src:/app/src:cached  # ソースコードの同期
      - /app/node_modules      # node_modulesは除外
    working_dir: /app
    command: npm run dev
```

**Pythonアプリ開発:**
```yaml
services:
  python-dev:
    image: python:3.12
    volumes:
      - .:/app:delegated
      - /app/.venv  # 仮想環境は除外
    working_dir: /app
    command: python -m flask run --debug
```

---

### パフォーマンス考慮（macOS/Windows）

**パフォーマンスオプション:**

| オプション | 動作 | 適用場面 |
|-----------|------|---------|
| `cached` | ホスト→コンテナの書き込みを遅延許容 | 読み取り主体（ソース閲覧） |
| `delegated` | コンテナ→ホストの書き込みを遅延許容 | 書き込み主体（ログ、ビルド成果物） |
| `consistent` | デフォルト（完全同期） | データベース等の整合性重視 |

**使用例:**
```yaml
services:
  app:
    image: myapp:dev
    volumes:
      # 読み取り主体
      - ./src:/app/src:cached

      # 書き込み主体
      - ./build:/app/build:delegated

      # 完全同期（DB）
      - db-data:/var/lib/postgresql/data:consistent

volumes:
  db-data:
```

---

### tmpfsマウント（高速I/O）

**インメモリストレージ:**
```bash
# 一時データ用（コンテナ停止で消失）
docker run -d \
  --tmpfs /tmp:rw,noexec,nosuid,size=100m \
  myapp:latest
```

**Compose例:**
```yaml
services:
  cache:
    image: redis:7
    tmpfs:
      - /data:size=500M,mode=0755
```

---

## コンテナ間データ共有

### --volumes-from

**基本パターン:**
```bash
# データボリュームコンテナ作成
docker create -v /data --name data-container alpine

# 他のコンテナから参照
docker run --volumes-from data-container writer-app
docker run --volumes-from data-container reader-app
```

**非推奨理由:**
- コンテナの依存関係が暗黙的
- Named volumesの方が管理しやすい

---

### shared named volumes（推奨）

**複数コンテナでの共有:**
```yaml
services:
  producer:
    image: producer:latest
    volumes:
      - shared-data:/data

  consumer:
    image: consumer:latest
    volumes:
      - shared-data:/data:ro  # 読み取り専用

volumes:
  shared-data:
```

**並行書き込み対策:**
```yaml
services:
  writer:
    image: writer:latest
    volumes:
      - shared-data:/data
    deploy:
      replicas: 1  # 書き込みは1つのみ

  reader:
    image: reader:latest
    volumes:
      - shared-data:/data:ro
    deploy:
      replicas: 3  # 読み取りは複数OK

volumes:
  shared-data:
```

---

### サイドカーパターン

**ログ収集サイドカー:**
```yaml
services:
  app:
    image: myapp:latest
    volumes:
      - app-logs:/var/log/app

  log-collector:
    image: fluentd
    volumes:
      - app-logs:/logs:ro
    depends_on:
      - app

volumes:
  app-logs:
```

**設定リロードサイドカー:**
```yaml
services:
  nginx:
    image: nginx
    volumes:
      - config:/etc/nginx:ro

  config-watcher:
    image: config-watcher:latest
    volumes:
      - config:/config
    command: watch-and-reload /config

volumes:
  config:
```

---

## 実践的な組み合わせ例

### 完全なWebアプリケーションスタック

```yaml
services:
  # フロントエンド（開発時）
  frontend:
    build: ./frontend
    volumes:
      - ./frontend/src:/app/src:cached
      - /app/node_modules
    ports:
      - "3000:3000"

  # バックエンド
  backend:
    build: ./backend
    volumes:
      - ./backend:/app:delegated
      - backend-uploads:/app/uploads
    environment:
      - DATABASE_URL=postgresql://postgres:password@db/myapp
    depends_on:
      - db

  # データベース
  db:
    image: postgres:17
    volumes:
      - postgres-data:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql:ro
    environment:
      POSTGRES_PASSWORD: password

  # Redis（セッション）
  redis:
    image: redis:7-alpine
    volumes:
      - redis-data:/data

volumes:
  postgres-data:
  redis-data:
  backend-uploads:
```

---

このガイドは標準的なDockerボリューム管理のベストプラクティスをまとめたものです。具体的な環境に応じて設定を調整してください。
