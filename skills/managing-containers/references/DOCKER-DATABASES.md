# データベースコンテナ運用リファレンス

Docker環境でのデータベース管理・最適化・運用の実践的ガイド。

---

## PostgreSQL in Docker

### 基本セットアップ

```dockerfile
FROM postgres:13

# 環境変数
ENV POSTGRES_DB=myapp
ENV POSTGRES_USER=myuser
ENV POSTGRES_PASSWORD=mypassword

# 初期化スクリプト（docker-entrypoint-initdb.d で自動実行）
COPY ./init.sql /docker-entrypoint-initdb.d/

EXPOSE 5432
```

```bash
# ビルドと起動
$ docker build -t my-postgres .
$ docker run -d \
  --name postgres-container \
  -p 5432:5432 \
  my-postgres
```

### 初期化スクリプト

`/docker-entrypoint-initdb.d/` に配置した `.sql` または `.sh` ファイルは初回起動時に自動実行される:

```sql
-- init.sql
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  username VARCHAR(50) UNIQUE NOT NULL,
  email VARCHAR(100) UNIQUE NOT NULL
);
```

### カスタム設定（postgresql.conf）

```dockerfile
FROM postgres:13

# カスタム設定をコピー
COPY postgresql.conf /etc/postgresql/postgresql.conf

CMD ["postgres", "-c", "config_file=/etc/postgresql/postgresql.conf"]
```

```conf
# postgresql.conf
max_connections = 100
shared_buffers = 1GB
effective_cache_size = 3GB
work_mem = 32MB
maintenance_work_mem = 256MB
```

### Docker Compose構成

```yaml
version: '3.8'
services:
  postgres:
    image: postgres:13
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: myuser
      POSTGRES_PASSWORD: mypassword
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    ports:
      - "5432:5432"
    networks:
      - app-network

volumes:
  pgdata:

networks:
  app-network:
```

---

## MySQL in Docker

### 基本セットアップ

```dockerfile
FROM mysql:8.0

ENV MYSQL_ROOT_PASSWORD=rootpassword
ENV MYSQL_DATABASE=myapp
ENV MYSQL_USER=myuser
ENV MYSQL_PASSWORD=mypassword

# カスタム設定
COPY ./my.cnf /etc/mysql/conf.d/
COPY ./init.sql /docker-entrypoint-initdb.d/

EXPOSE 3306
```

```bash
$ docker build -t my-mysql .
$ docker run -d \
  --name mysql-container \
  -p 3306:3306 \
  my-mysql
```

### カスタム設定（my.cnf）

```ini
# my.cnf
[mysqld]
max_connections = 200
innodb_buffer_pool_size = 2G
innodb_log_file_size = 512M
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
```

### Docker Compose構成

```yaml
version: '3.8'
services:
  mysql:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: rootpassword
      MYSQL_DATABASE: myapp
      MYSQL_USER: myuser
      MYSQL_PASSWORD: mypassword
    volumes:
      - mysqldata:/var/lib/mysql
      - ./my.cnf:/etc/mysql/conf.d/my.cnf
    ports:
      - "3306:3306"

volumes:
  mysqldata:
```

---

## MongoDB in Docker

### 基本セットアップ

```dockerfile
FROM mongo:4.4

ENV MONGO_INITDB_ROOT_USERNAME=admin
ENV MONGO_INITDB_ROOT_PASSWORD=adminpassword
ENV MONGO_INITDB_DATABASE=myapp

# 初期化スクリプト
COPY ./init-mongo.js /docker-entrypoint-initdb.d/

EXPOSE 27017
```

### 初期化スクリプト

```javascript
// init-mongo.js
db = db.getSiblingDB('myapp');

db.createUser({
  user: 'appuser',
  pwd: 'apppassword',
  roles: [
    { role: 'readWrite', db: 'myapp' }
  ]
});

db.createCollection('users');
```

### Docker Compose構成（認証付き）

```yaml
version: '3.8'
services:
  mongodb:
    image: mongo:4.4
    environment:
      MONGO_INITDB_ROOT_USERNAME: admin
      MONGO_INITDB_ROOT_PASSWORD: adminpassword
      MONGO_INITDB_DATABASE: myapp
    volumes:
      - mongodata:/data/db
      - ./init-mongo.js:/docker-entrypoint-initdb.d/init-mongo.js
    ports:
      - "27017:27017"

volumes:
  mongodata:
```

---

## Redis in Docker

### 基本セットアップ

```bash
$ docker run -d \
  --name redis-cache \
  -p 6379:6379 \
  redis:6
```

### 永続化設定（AOF + RDB）

```dockerfile
FROM redis:6

# カスタム設定
COPY redis.conf /usr/local/etc/redis/redis.conf

CMD ["redis-server", "/usr/local/etc/redis/redis.conf"]
```

```conf
# redis.conf

# RDB永続化（スナップショット）
save 900 1        # 900秒間に1回以上の変更で保存
save 300 10       # 300秒間に10回以上の変更で保存
save 60 10000     # 60秒間に10000回以上の変更で保存

# AOF永続化（追記ログ）
appendonly yes
appendfilename "appendonly.aof"
appendfsync everysec

# メモリ管理
maxmemory 2gb
maxmemory-policy allkeys-lru
```

### Docker Compose構成

```yaml
version: '3.8'
services:
  redis:
    image: redis:6
    volumes:
      - redisdata:/data
      - ./redis.conf:/usr/local/etc/redis/redis.conf
    command: redis-server /usr/local/etc/redis/redis.conf
    ports:
      - "6379:6379"

volumes:
  redisdata:
```

---

## データ永続化戦略

### Named Volumes（推奨）

```bash
# ボリューム作成
$ docker volume create pgdata

# ボリュームをマウントして起動
$ docker run -d \
  --name postgres-container \
  -v pgdata:/var/lib/postgresql/data \
  -p 5432:5432 \
  my-postgres
```

**メリット:**
- Docker管理下で安全に管理
- ポータブル（`docker volume inspect` で場所確認可能）
- コンテナ削除後もデータ保持

### バックアップ戦略（PostgreSQL）

```bash
#!/bin/bash
# backup-postgres.sh

CONTAINER_NAME="postgres-container"
BACKUP_DIR="/path/to/backup/directory"
DATE=$(date +%Y%m%d_%H%M%S)

# pg_dump でバックアップ
docker exec $CONTAINER_NAME pg_dump -U myuser myapp \
  > $BACKUP_DIR/backup_$DATE.sql

# 全データベースをバックアップ
docker exec -t $CONTAINER_NAME pg_dumpall -c -U postgres \
  > $BACKUP_DIR/backup_all_$DATE.sql
```

### リストア手順

```bash
# 単一データベースのリストア
$ docker exec -i postgres-container psql -U myuser myapp \
  < /path/to/backup/file.sql

# 全データベースのリストア
$ cat backup_all.sql | docker exec -i postgres-container psql -U postgres
```

### バックアップ戦略（MySQL）

```bash
#!/bin/bash
# backup-mysql.sh

CONTAINER_NAME="mysql-container"
BACKUP_DIR="/path/to/backup"
DATE=$(date +%Y%m%d_%H%M%S)

# mysqldump でバックアップ
docker exec $CONTAINER_NAME mysqldump -u myuser -pmypassword myapp \
  > $BACKUP_DIR/backup_$DATE.sql
```

### バックアップ戦略（MongoDB）

```bash
#!/bin/bash
# backup-mongo.sh

CONTAINER_NAME="mongo-container"
BACKUP_DIR="/path/to/backup"
DATE=$(date +%Y%m%d_%H%M%S)

# mongodump でバックアップ
docker exec $CONTAINER_NAME mongodump \
  --username admin \
  --password adminpassword \
  --authenticationDatabase admin \
  --out /tmp/backup

# バックアップをホストにコピー
docker cp $CONTAINER_NAME:/tmp/backup $BACKUP_DIR/backup_$DATE
```

---

## パフォーマンスチューニング

### リソース割り当て

```bash
$ docker run -d \
  --name postgres-container \
  --cpus 2 \
  --memory 4g \
  --memory-swap 4g \
  -p 5432:5432 \
  my-postgres
```

**推奨設定:**
- **CPU**: データベース負荷に応じて2-8コア
- **メモリ**: 最低4GB、本番環境では8GB以上
- **Swap**: メモリと同量、またはSwap無効化（`--memory-swap=メモリ値`）

### PostgreSQL設定最適化

```conf
# postgresql.conf（4GBメモリマシン向け）

# 接続
max_connections = 100

# メモリ
shared_buffers = 1GB                  # 総メモリの25%
effective_cache_size = 3GB            # 総メモリの75%
work_mem = 32MB                       # shared_buffers / max_connections / 3
maintenance_work_mem = 256MB          # shared_buffersの1/4

# WAL
wal_buffers = 16MB
checkpoint_completion_target = 0.9

# クエリプランナー
random_page_cost = 1.1                # SSD前提
effective_io_concurrency = 200
```

### MySQL設定最適化

```ini
[mysqld]
# メモリ（4GBマシン向け）
innodb_buffer_pool_size = 2G          # 総メモリの50%
innodb_log_buffer_size = 16M

# 接続
max_connections = 200

# InnoDB
innodb_flush_log_at_trx_commit = 2    # 高速化（耐障害性とのトレードオフ）
innodb_file_per_table = 1

# ログ
slow_query_log = 1
long_query_time = 2
```

---

## レプリケーション

### PostgreSQL Primary-Replica構成

```bash
# ネットワーク作成
$ docker network create pg-network

# Primaryノード起動
$ docker run -d \
  --name pg-primary \
  --network pg-network \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -e POSTGRES_REPLICATION_MODE=master \
  -e POSTGRES_REPLICATION_USER=repl_user \
  -e POSTGRES_REPLICATION_PASSWORD=repl_password \
  -v pgdata-primary:/var/lib/postgresql/data \
  postgres

# Replicaノード起動
$ docker run -d \
  --name pg-replica \
  --network pg-network \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -e POSTGRES_MASTER_HOST=pg-primary \
  -e POSTGRES_REPLICATION_MODE=slave \
  -e POSTGRES_REPLICATION_USER=repl_user \
  -e POSTGRES_REPLICATION_PASSWORD=repl_password \
  postgres
```

### MySQL Primary-Replica構成

```bash
# Primaryノード起動
$ docker run -d \
  --name mysql-primary \
  --network mysql-network \
  -e MYSQL_ROOT_PASSWORD=rootpassword \
  -e MYSQL_REPLICATION_MODE=master \
  -e MYSQL_REPLICATION_USER=repl_user \
  -e MYSQL_REPLICATION_PASSWORD=repl_password \
  mysql:8.0

# Replicaノード起動
$ docker run -d \
  --name mysql-replica \
  --network mysql-network \
  -e MYSQL_ROOT_PASSWORD=rootpassword \
  -e MYSQL_REPLICATION_MODE=slave \
  -e MYSQL_MASTER_HOST=mysql-primary \
  -e MYSQL_MASTER_ROOT_PASSWORD=rootpassword \
  mysql:8.0
```

---

## 監視

### Prometheus + Grafana構成

```yaml
# docker-compose-monitoring.yml
version: '3.8'
services:
  # データベース
  postgres:
    image: postgres:13
    environment:
      POSTGRES_PASSWORD: mysecretpassword
    volumes:
      - pgdata:/var/lib/postgresql/data
    networks:
      - monitoring

  # PostgreSQL Exporter
  postgres-exporter:
    image: prometheuscommunity/postgres-exporter
    environment:
      DATA_SOURCE_NAME: "postgresql://postgres:mysecretpassword@postgres:5432/postgres?sslmode=disable"
    ports:
      - "9187:9187"
    networks:
      - monitoring

  # Prometheus
  prometheus:
    image: prom/prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    ports:
      - "9090:9090"
    networks:
      - monitoring

  # Grafana
  grafana:
    image: grafana/grafana
    ports:
      - "3000:3000"
    networks:
      - monitoring

volumes:
  pgdata:

networks:
  monitoring:
```

```yaml
# prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres-exporter:9187']
```

**Grafanaダッシュボード:**
- PostgreSQL: Dashboard ID 9628
- MySQL: Dashboard ID 7362
- Redis: Dashboard ID 11835

---

## セキュリティ

### ネットワーク分離

```bash
# 専用ネットワーク作成
$ docker network create --driver bridge isolated_network

# データベースコンテナを分離ネットワークで起動
$ docker run \
  --network isolated_network \
  --name postgres-db \
  postgres
```

**ベストプラクティス:**
- データベースコンテナはポート公開せず、アプリコンテナと同一ネットワークで通信
- 外部アクセスが必要な場合のみ `-p` でポート公開

### Docker Secrets管理

```bash
# Secretを作成
$ echo "my_secure_password" | docker secret create db_password -

# Secretを使用してサービス作成
$ docker service create \
  --name postgres \
  --secret db_password \
  -e POSTGRES_PASSWORD_FILE=/run/secrets/db_password \
  postgres
```

**注意:** `docker secret` は Swarm mode でのみ使用可能。単一ホスト環境では `.env` ファイル + volume マウントで代替。

### 定期更新

```bash
# 最新イメージを取得
$ docker pull postgres:latest

# 既存コンテナを停止・削除
$ docker stop postgres-container
$ docker rm postgres-container

# 新しいイメージで起動（データはvolumeに保持）
$ docker run -d \
  --name postgres-container \
  -v pgdata:/var/lib/postgresql/data \
  postgres:latest
```

---

## 高度なパターン

### MongoDB Sharding

```bash
# ネットワーク作成
$ docker network create mongo-cluster

# Config Servers（3台）
$ docker run -d --name mongo-config1 --network mongo-cluster \
  mongo:4.4 --configsvr --replSet configRS

$ docker run -d --name mongo-config2 --network mongo-cluster \
  mongo:4.4 --configsvr --replSet configRS

$ docker run -d --name mongo-config3 --network mongo-cluster \
  mongo:4.4 --configsvr --replSet configRS

# Config Server Replica Set初期化
$ docker exec -it mongo-config1 mongo --eval \
  "rs.initiate({_id: 'configRS', members: [{_id: 0, host: 'mongo-config1'}, {_id: 1, host: 'mongo-config2'}, {_id: 2, host: 'mongo-config3'}]})"

# Shard Servers（2シャード）
$ docker run -d --name mongo-shard1 --network mongo-cluster \
  mongo:4.4 --shardsvr --replSet shard1RS

$ docker run -d --name mongo-shard2 --network mongo-cluster \
  mongo:4.4 --shardsvr --replSet shard2RS

# Shard Replica Sets初期化
$ docker exec -it mongo-shard1 mongo --eval \
  "rs.initiate({_id: 'shard1RS', members: [{_id: 0, host: 'mongo-shard1'}]})"

$ docker exec -it mongo-shard2 mongo --eval \
  "rs.initiate({_id: 'shard2RS', members: [{_id: 0, host: 'mongo-shard2'}]})"

# mongosルーター
$ docker run -d --name mongo-router --network mongo-cluster \
  -p 27017:27017 \
  mongo:4.4 mongos --configdb configRS/mongo-config1,mongo-config2,mongo-config3

# シャードを追加
$ docker exec -it mongo-router mongo --eval \
  "sh.addShard('shard1RS/mongo-shard1')"

$ docker exec -it mongo-router mongo --eval \
  "sh.addShard('shard2RS/mongo-shard2')"
```

### マイグレーション戦略（PostgreSQLバージョンアップ）

```bash
# 1. 既存DBをバックアップ
$ docker exec -t old-postgres pg_dumpall -c -U postgres > dump.sql

# 2. 新バージョンのコンテナを起動
$ docker run -d \
  --name new-postgres \
  -e POSTGRES_PASSWORD=mysecretpassword \
  postgres:13

# 3. データをリストア
$ cat dump.sql | docker exec -i new-postgres psql -U postgres

# 4. バージョン確認
$ docker exec -it new-postgres psql -U postgres -c "SELECT version();"

# 5. 動作確認後、古いコンテナを停止・削除
$ docker stop old-postgres
$ docker rm old-postgres
```

### マルチDB構成（PostgreSQL + Redis）

```yaml
version: '3.8'
services:
  # PostgreSQL（永続データ）
  postgres:
    image: postgres:13
    environment:
      POSTGRES_PASSWORD: mysecretpassword
    volumes:
      - pgdata:/var/lib/postgresql/data
    networks:
      - app-network

  # Redis（キャッシュ）
  redis:
    image: redis:6
    volumes:
      - redisdata:/data
    networks:
      - app-network

  # アプリケーション
  app:
    image: your-app-image
    depends_on:
      - postgres
      - redis
    networks:
      - app-network
    ports:
      - "8000:8000"

volumes:
  pgdata:
  redisdata:

networks:
  app-network:
```

**ユースケース:**
- PostgreSQL: ユーザー情報、トランザクションデータ
- Redis: セッション管理、レート制限、クエリ結果キャッシュ

---

## トラブルシューティング

### コンテナ起動失敗

```bash
# ログ確認
$ docker logs postgres-container

# よくある原因:
# 1. ポート競合 → -p 5433:5432 で別ポートに変更
# 2. ボリューム権限 → docker volume rm で再作成
# 3. 環境変数未設定 → -e で必須変数を設定
```

### 接続できない

```bash
# コンテナ内でpsqlを実行して確認
$ docker exec -it postgres-container psql -U myuser -d myapp

# ネットワーク確認
$ docker network inspect app-network

# ポート確認
$ docker port postgres-container
```

### パフォーマンス問題

```bash
# リソース使用状況確認
$ docker stats postgres-container

# クエリログ確認（PostgreSQL）
$ docker exec -it postgres-container tail -f /var/lib/postgresql/data/log/postgresql-*.log
```

---

## 参考リソース

- [Docker Hub - PostgreSQL](https://hub.docker.com/_/postgres)
- [Docker Hub - MySQL](https://hub.docker.com/_/mysql)
- [Docker Hub - MongoDB](https://hub.docker.com/_/mongo)
- [Docker Hub - Redis](https://hub.docker.com/_/redis)
