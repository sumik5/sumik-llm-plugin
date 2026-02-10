# クラウドとコンテナ

## Graceful Shutdown

### 基本実装

```go
import (
    "context"
    "log"
    "net/http"
    "os"
    "os/signal"
    "syscall"
    "time"
)

func main() {
    srv := &http.Server{
        Addr:    ":8080",
        Handler: setupRouter(),
    }

    // サーバーを非同期起動
    go func() {
        if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            log.Fatalf("listen: %s\n", err)
        }
    }()

    // シグナル待機（SIGINT = Ctrl+C, SIGTERM = Dockerコンテナ停止）
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit

    log.Println("Shutting down server...")

    // タイムアウト付きでシャットダウン
    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()

    if err := srv.Shutdown(ctx); err != nil {
        log.Fatal("Server forced to shutdown:", err)
    }

    log.Println("Server exited")
}
```

**重要**:
- `SIGTERM`/`SIGINT`を受信して優雅に終了
- 処理中のリクエストを完了させてから停止
- タイムアウト（5秒）後は強制終了

### Kubernetesでの動作

1. `kubectl delete pod xxx` → `SIGTERM`送信
2. アプリケーションが`Shutdown()`開始
3. 処理中のリクエスト完了を待機
4. 30秒（デフォルト）後に`SIGKILL`強制終了

### データベース接続のクローズ

```go
func main() {
    db, err := sql.Open("postgres", dsn)
    if err != nil {
        log.Fatal(err)
    }
    defer db.Close()

    srv := &http.Server{
        Addr:    ":8080",
        Handler: setupRouter(db),
    }

    go func() {
        if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            log.Fatal(err)
        }
    }()

    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit

    log.Println("Shutting down...")

    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()

    // HTTPサーバーをシャットダウン
    if err := srv.Shutdown(ctx); err != nil {
        log.Fatal("Server shutdown error:", err)
    }

    // データベース接続をクローズ
    if err := db.Close(); err != nil {
        log.Println("Database close error:", err)
    }

    log.Println("Server exited")
}
```

## コンテナイメージ作成

### Dockerfile基本構造

```dockerfile
# ビルドステージ
FROM golang:1.21-bullseye AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN go build -o /app/server ./cmd/server

# 実行ステージ
FROM debian:bullseye-slim

WORKDIR /app
COPY --from=builder /app/server .

EXPOSE 8080
CMD ["./server"]
```

### マルチステージビルド（推奨）

```dockerfile
# ビルドステージ（サイズ大）
FROM golang:1.21-bullseye AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /app/server ./cmd/server

# 実行ステージ（サイズ小）
FROM scratch

COPY --from=builder /app/server /server
EXPOSE 8080
ENTRYPOINT ["/server"]
```

**メリット**:
- ビルドツールを含まない小さなイメージ
- セキュリティリスク削減

### distrolessイメージ（推奨）

```dockerfile
FROM golang:1.21 AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /app/server ./cmd/server

# Google製のセキュアなベースイメージ
FROM gcr.io/distroless/static-debian11

COPY --from=builder /app/server /server
EXPOSE 8080
ENTRYPOINT ["/server"]
```

**distrolessの特徴**:
- シェルなし（デバッグは難しいがセキュア）
- 最小限のOS依存関係
- 脆弱性が少ない

### scratchイメージ

```dockerfile
FROM golang:1.21 AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /app/server ./cmd/server

# 完全に空のイメージ
FROM scratch

COPY --from=builder /app/server /server
EXPOSE 8080
ENTRYPOINT ["/server"]
```

**注意**: 完全に空のため、デバッグツール一切なし。本番環境専用。

### ビルドオプション

```bash
CGO_ENABLED=0 GOOS=linux go build \
  -ldflags="-s -w" \
  -trimpath \
  -o /app/server \
  ./cmd/server
```

| オプション | 効果 |
|----------|------|
| `CGO_ENABLED=0` | CGO無効化、完全静的リンク（scratch対応） |
| `-ldflags="-s -w"` | デバッグ情報削除、バイナリサイズ削減 |
| `-trimpath` | ファイルパス情報削除、再現性向上 |

### タイムゾーン対応（distroless/scratch）

```dockerfile
# タイムゾーンデータをコピー
FROM gcr.io/distroless/static-debian11

COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /app/server /server

ENV TZ=Asia/Tokyo
ENTRYPOINT ["/server"]
```

または`time/tzdata`を埋め込む:

```go
import _ "time/tzdata"
```

### CA証明書（HTTPS通信）

```dockerfile
# CA証明書をコピー（HTTPS通信に必要）
FROM gcr.io/distroless/static-debian11

COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /app/server /server

ENTRYPOINT ["/server"]
```

## ヘルスチェック

### Kubernetes Probe

```yaml
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: app
    image: myapp:latest
    livenessProbe:
      httpGet:
        path: /healthz
        port: 8080
      initialDelaySeconds: 10
      periodSeconds: 10
    readinessProbe:
      httpGet:
        path: /readyz
        port: 8080
      initialDelaySeconds: 5
      periodSeconds: 5
```

### ヘルスチェックエンドポイント実装

```go
func healthzHandler(w http.ResponseWriter, r *http.Request) {
    // Liveness: プロセスが生きているか
    w.WriteHeader(http.StatusOK)
    w.Write([]byte("OK"))
}

func readyzHandler(db *sql.DB) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        // Readiness: 依存サービスが利用可能か
        ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
        defer cancel()

        if err := db.PingContext(ctx); err != nil {
            w.WriteHeader(http.StatusServiceUnavailable)
            w.Write([]byte("DB connection failed"))
            return
        }

        w.WriteHeader(http.StatusOK)
        w.Write([]byte("OK"))
    }
}
```

**Liveness vs Readiness**:
- **Liveness**: プロセスが応答するか（失敗時は再起動）
- **Readiness**: 依存サービス含めて準備完了か（失敗時はトラフィック停止）

## 環境変数による設定管理

### 基本パターン

```go
import "os"

func main() {
    port := os.Getenv("PORT")
    if port == "" {
        port = "8080"
    }

    dbHost := os.Getenv("DB_HOST")
    dbUser := os.Getenv("DB_USER")
    dbPassword := os.Getenv("DB_PASSWORD")

    dsn := fmt.Sprintf("postgres://%s:%s@%s/mydb", dbUser, dbPassword, dbHost)
    // ...
}
```

### 構造体への読み込み（envconfig推奨）

```go
import "github.com/kelseyhightower/envconfig"

type Config struct {
    Port       string `envconfig:"PORT" default:"8080"`
    DBHost     string `envconfig:"DB_HOST" required:"true"`
    DBUser     string `envconfig:"DB_USER" required:"true"`
    DBPassword string `envconfig:"DB_PASSWORD" required:"true"`
}

func main() {
    var cfg Config
    if err := envconfig.Process("", &cfg); err != nil {
        log.Fatal(err)
    }

    log.Printf("Starting server on port %s", cfg.Port)
    // ...
}
```

### Kubernetes Secret連携

```yaml
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: app
    image: myapp:latest
    env:
    - name: DB_HOST
      value: "postgres.default.svc.cluster.local"
    - name: DB_USER
      valueFrom:
        secretKeyRef:
          name: db-secret
          key: username
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-secret
          key: password
```

## ステートレス設計

### 原則

- **状態はDBに保存**: メモリ上の状態は持たない
- **セッションは外部化**: Redis/Memcached使用
- **ファイルは外部ストレージ**: S3/Cloud Storage
- **スケールアウト可能**: 複数インスタンス起動可能

### セッション管理（Redis）

```go
import "github.com/go-redis/redis/v8"

func main() {
    rdb := redis.NewClient(&redis.Options{
        Addr: os.Getenv("REDIS_ADDR"),
    })

    // セッション保存
    rdb.Set(ctx, "session:"+sessionID, userData, 24*time.Hour)

    // セッション取得
    val, err := rdb.Get(ctx, "session:"+sessionID).Result()
}
```

## ログ出力（コンテナ環境）

### 原則

- **標準出力に出力**: ファイル出力禁止
- **構造化ログ**: JSON形式推奨
- **エージェント自動収集**: CloudWatch Logs/Stackdriver

```go
import "github.com/rs/zerolog/log"

func main() {
    // 標準出力にJSON出力
    log.Logger = log.Output(os.Stdout)

    log.Info().
        Str("service", "api-server").
        Str("version", "1.0.0").
        Msg("Server started")
}
```

## Docker Compose（ローカル開発）

```yaml
version: "3.8"
services:
  app:
    build: .
    ports:
      - "8080:8080"
    environment:
      - PORT=8080
      - DB_HOST=postgres
      - DB_USER=user
      - DB_PASSWORD=password
    depends_on:
      - postgres

  postgres:
    image: postgres:15
    environment:
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=password
      - POSTGRES_DB=mydb
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data

volumes:
  pgdata:
```

## ベストプラクティス

| プラクティス | 説明 |
|------------|------|
| Graceful Shutdown実装 | SIGTERM/SIGINT対応必須 |
| マルチステージビルド | イメージサイズ削減 |
| distroless/scratch使用 | セキュリティ向上 |
| CGO_ENABLED=0 | 完全静的リンク |
| ヘルスチェック実装 | Liveness/Readiness分離 |
| 環境変数で設定管理 | ハードコード禁止 |
| ステートレス設計 | スケールアウト可能に |
| 標準出力にログ | ファイル出力禁止 |
| タイムゾーン設定 | time/tzdataまたはコピー |
| CA証明書配置 | HTTPS通信に必要 |

## アンチパターン

| パターン | 問題 | 修正 |
|---------|------|------|
| Graceful Shutdown未実装 | リクエスト処理中に強制終了 | signal.Notify + Shutdown |
| シングルステージビルド | イメージサイズ肥大化 | マルチステージビルド |
| CGO有効 | 動的リンク、移植性低下 | CGO_ENABLED=0 |
| ヘルスチェックなし | 異常検知不可 | /healthz, /readyz実装 |
| ハードコード設定 | 環境ごとにビルド必要 | 環境変数使用 |
| メモリに状態保存 | スケールアウト不可 | DBまたはRedis使用 |
| ファイルにログ出力 | ローテーション必要 | 標準出力使用 |
| タイムゾーン未設定 | UTC固定 | TZ設定またはtzdata埋込 |
| CA証明書なし | HTTPS通信失敗 | 証明書コピーまたはベースイメージ変更 |
