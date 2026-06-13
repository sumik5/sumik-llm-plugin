# Goプロジェクト構造

## 標準レイアウト

### シンプルなプロジェクト
```
myproject/
├── go.mod
├── go.sum
├── main.go           # エントリーポイント
├── handler.go        # HTTPハンドラ
├── service.go        # ビジネスロジック
├── repository.go     # データアクセス
└── handler_test.go   # テスト
```

### 中規模プロジェクト
```
myproject/
├── go.mod
├── go.sum
├── main.go
├── cmd/
│   └── myapp/
│       └── main.go       # エントリーポイント
├── internal/             # プロジェクト内部パッケージ
│   ├── handler/
│   │   ├── handler.go
│   │   └── handler_test.go
│   ├── service/
│   │   ├── service.go
│   │   └── service_test.go
│   └── repository/
│       ├── repository.go
│       └── repository_test.go
├── pkg/                  # 外部公開パッケージ（必要な場合）
│   └── client/
│       └── client.go
└── Makefile
```

### 大規模プロジェクト
```
myproject/
├── go.mod
├── go.sum
├── cmd/
│   ├── api/
│   │   └── main.go       # APIサーバー
│   ├── worker/
│   │   └── main.go       # バックグラウンドワーカー
│   └── cli/
│       └── main.go       # CLIツール
├── internal/
│   ├── app/              # アプリケーション層
│   │   ├── api/
│   │   └── worker/
│   ├── domain/           # ドメイン層
│   │   ├── user/
│   │   │   ├── entity.go
│   │   │   ├── repository.go  # インターフェース
│   │   │   └── service.go
│   │   └── order/
│   ├── infra/            # インフラ層
│   │   ├── database/
│   │   ├── cache/
│   │   └── external/
│   └── config/
│       └── config.go
├── pkg/                  # 公開ライブラリ
├── api/                  # API定義
│   ├── openapi.yaml
│   └── proto/
├── migrations/           # DBマイグレーション
├── scripts/              # ビルド/デプロイスクリプト
├── deployments/          # デプロイ設定
│   ├── docker/
│   └── k8s/
├── docs/
├── Makefile
├── Dockerfile
└── docker-compose.yml
```

## ディレクトリの役割

### cmd/
実行可能ファイルのエントリーポイント：

```go
// cmd/api/main.go
package main

import (
    "context"
    "log"
    "os/signal"
    "syscall"

    "github.com/username/myproject/internal/app/api"
    "github.com/username/myproject/internal/config"
)

func main() {
    ctx, stop := signal.NotifyContext(context.Background(),
        syscall.SIGINT, syscall.SIGTERM)
    defer stop()

    cfg, err := config.Load()
    if err != nil {
        log.Fatalf("load config: %v", err)
    }

    if err := api.Run(ctx, cfg); err != nil {
        log.Fatalf("run api: %v", err)
    }
}
```

### internal/
プロジェクト内部のコード。外部からインポート不可：

```go
// internal/handler/user.go
package handler

type UserHandler struct {
    service UserService
}

func NewUserHandler(service UserService) *UserHandler {
    return &UserHandler{service: service}
}
```

### pkg/
外部に公開するパッケージ（慎重に使用）：

```go
// pkg/client/client.go
package client

// Client は外部から使用可能
type Client struct {
    baseURL string
}

func New(baseURL string) *Client {
    return &Client{baseURL: baseURL}
}
```

## go.mod

### 初期化
```bash
go mod init github.com/username/myproject
```

### 基本構造
```go
module github.com/username/myproject

go 1.22

require (
    github.com/gin-gonic/gin v1.9.1
    github.com/lib/pq v1.10.9
)

require (
    // 間接依存
    golang.org/x/net v0.17.0 // indirect
)
```

### コマンド
```bash
# 依存関係の追加
go get github.com/gin-gonic/gin

# 不要な依存の削除
go mod tidy

# 依存関係の検証
go mod verify

# ベンダリング
go mod vendor
```

## パッケージ設計

### 単一責任
```go
// Good: 明確な責任
package user

type User struct { ... }
type Repository interface { ... }
type Service struct { ... }

// Bad: 複数の責任
package models  // 様々なエンティティが混在
```

### 依存関係の方向
```
cmd/
 └── depends on → internal/app/
                   └── depends on → internal/domain/
                                    └── depends on → internal/infra/ (via interface)
```

### インターフェースの配置
```go
// internal/domain/user/repository.go
// インターフェースは使用する側で定義
package user

type Repository interface {
    FindByID(ctx context.Context, id string) (*User, error)
    Save(ctx context.Context, user *User) error
}

// internal/infra/database/user_repository.go
// 実装はインフラ層
package database

type UserRepository struct {
    db *sql.DB
}

func (r *UserRepository) FindByID(ctx context.Context, id string) (*user.User, error) {
    // 実装
}
```

## 設定管理

### 環境変数ベース
```go
// internal/config/config.go
package config

import (
    "os"
    "strconv"
    "time"
)

type Config struct {
    Server   ServerConfig
    Database DatabaseConfig
}

type ServerConfig struct {
    Port         int
    ReadTimeout  time.Duration
    WriteTimeout time.Duration
}

type DatabaseConfig struct {
    Host     string
    Port     int
    User     string
    Password string
    Name     string
}

func Load() (*Config, error) {
    return &Config{
        Server: ServerConfig{
            Port:         getEnvInt("SERVER_PORT", 8080),
            ReadTimeout:  getEnvDuration("SERVER_READ_TIMEOUT", 30*time.Second),
            WriteTimeout: getEnvDuration("SERVER_WRITE_TIMEOUT", 30*time.Second),
        },
        Database: DatabaseConfig{
            Host:     getEnv("DB_HOST", "localhost"),
            Port:     getEnvInt("DB_PORT", 5432),
            User:     getEnv("DB_USER", "postgres"),
            Password: os.Getenv("DB_PASSWORD"),  // 必須
            Name:     getEnv("DB_NAME", "mydb"),
        },
    }, nil
}

func getEnv(key, defaultValue string) string {
    if v := os.Getenv(key); v != "" {
        return v
    }
    return defaultValue
}

func getEnvInt(key string, defaultValue int) int {
    if v := os.Getenv(key); v != "" {
        if i, err := strconv.Atoi(v); err == nil {
            return i
        }
    }
    return defaultValue
}

func getEnvDuration(key string, defaultValue time.Duration) time.Duration {
    if v := os.Getenv(key); v != "" {
        if d, err := time.ParseDuration(v); err == nil {
            return d
        }
    }
    return defaultValue
}
```

## Makefile

```makefile
.PHONY: build test lint run clean

# 変数
BINARY_NAME=myapp
BUILD_DIR=bin

# ビルド
build:
	go build -o $(BUILD_DIR)/$(BINARY_NAME) ./cmd/api

# テスト
test:
	go test -v -race -cover ./...

# Lint
lint:
	golangci-lint run

# 開発サーバー起動
run:
	go run ./cmd/api

# クリーン
clean:
	rm -rf $(BUILD_DIR)

# 依存関係
deps:
	go mod tidy
	go mod verify

# 全チェック
check: lint test
```

## ベストプラクティス

| プラクティス | 説明 |
|------------|------|
| internal/使用 | 内部コードを外部から保護 |
| 小さなパッケージ | 単一責任、テスト容易性 |
| インターフェース分離 | 使用側で定義 |
| 依存性注入 | テスト容易性、疎結合 |
| 設定は環境変数 | 12-Factor App準拠 |

## アンチパターン

| パターン | 問題 | 修正 |
|---------|------|------|
| 巨大なmain.go | テスト困難 | cmd/とinternal/に分離 |
| 循環インポート | ビルドエラー | インターフェースで分離 |
| グローバル変数 | テスト困難 | 依存性注入 |
| utils/パッケージ | 意味不明な集合 | 目的別パッケージ |
| pkg/の乱用 | API汚染 | internal/を優先 |

---

## Go Modules実践

### マルチモジュール構成

1つのリポジトリに複数のモジュールを配置できます。

```
myproject/
├── go.mod              # ルートモジュール
├── go.sum
├── main.go
├── pkg/
│   └── utils/
│       ├── go.mod      # サブモジュール
│       ├── go.sum
│       └── utils.go
└── tools/
    ├── go.mod          # ツール用モジュール
    ├── go.sum
    └── main.go
```

**使用場面**:
- ツール類を別モジュールとして管理
- ライブラリと実行ファイルを分離
- 依存関係を厳密に分離したい場合

### replace directive（ローカル開発）

`go.mod` の `replace` ディレクティブで、依存モジュールをローカルパスに置き換えます。

```go
// go.mod
module github.com/user/myapp

go 1.22

require (
    github.com/user/mylib v1.0.0
)

// ローカルの mylib を使用
replace github.com/user/mylib => ../mylib
```

**使用場面**:
- ローカルでライブラリを同時開発
- フォークしたライブラリの開発
- モノレポ構成でのサブモジュール参照

### プライベートリポジトリの利用

#### GOPRIVATEの設定

プライベートリポジトリからモジュールをダウンロードする場合、`GOPRIVATE` 環境変数を設定します。

```bash
# 特定のドメインをプライベートとして扱う
export GOPRIVATE="github.com/mycompany/*,gitlab.com/myteam/*"

# または .bashrc / .zshrc に追加
echo 'export GOPRIVATE="github.com/mycompany/*"' >> ~/.bashrc
```

**効果**:
- 公開プロキシ（proxy.golang.org）をバイパス
- チェックサムデータベース（sum.golang.db）をバイパス
- Git認証情報を使用してダウンロード

#### GOSUMDBの無効化

プライベートモジュールでチェックサムデータベースを無効化：

```bash
# 特定のドメインでチェックサム検証をスキップ
export GOSUMDB="sum.golang.org https://sum.golang.org+12345678+... github.com/mycompany off"

# またはすべて無効化（非推奨）
export GOSUMDB=off
```

#### Git認証の設定

```bash
# SSH経由でアクセス（HTTPSをSSHに書き換え）
git config --global url."git@github.com:".insteadOf "https://github.com/"

# または .netrc で認証情報を設定（macOS/Linux）
echo "machine github.com login myuser password mytoken" >> ~/.netrc
chmod 600 ~/.netrc
```

### フォークモジュールの参照

フォークしたライブラリを参照する方法:

```go
// go.mod
module github.com/user/myapp

go 1.22

require (
    github.com/original/lib v1.2.3
)

// フォークを参照
replace github.com/original/lib => github.com/user/lib v1.2.4-fork
```

**注意**: `go get` でフォークをダウンロード後、`replace` を追加します。

```bash
# フォークを取得
go get github.com/user/lib@v1.2.4-fork

# go.modに replace を追加
# replace github.com/original/lib => github.com/user/lib v1.2.4-fork
```

### タグ再設定の禁止

**重要**: 一度公開したタグのコミット位置を変更してはいけません。

```bash
# ❌ Bad: 既存タグを上書き（エラーが発生）
git tag -f v1.0.0
git push origin v1.0.0 --force

# ユーザーがダウンロードすると...
# verifying github.com/user/lib@v1.0.0: checksum mismatch
# SECURITY ERROR
```

**対策**: バージョンをインクリメントして新しいタグを作成

```bash
# ✅ Good: 新しいバージョンを作成
git tag v1.0.1
git push origin v1.0.1
```

---

## 静的プラグイン機構

Goには動的プラグイン機能（plugin パッケージ）がありますが、実用性が低いため、**静的プラグイン** パターンが一般的です。

### init()登録パターン

```go
// plugin/registry.go
package plugin

var registry = make(map[string]Handler)

type Handler interface {
    Handle(input string) string
}

func Register(name string, handler Handler) {
    registry[name] = handler
}

func Get(name string) (Handler, bool) {
    h, ok := registry[name]
    return h, ok
}

// plugin/hello/hello.go
package hello

import "github.com/user/app/plugin"

type HelloHandler struct{}

func (h HelloHandler) Handle(input string) string {
    return "Hello, " + input
}

// init()でプラグインを自動登録
func init() {
    plugin.Register("hello", HelloHandler{})
}

// main.go
package main

import (
    "fmt"
    "github.com/user/app/plugin"
    _ "github.com/user/app/plugin/hello"  // ブランクimport
)

func main() {
    handler, ok := plugin.Get("hello")
    if ok {
        fmt.Println(handler.Handle("World"))
    }
}
```

### ブランクimport（blank import）

プラグインを登録するためだけに `import` します。

```go
import (
    _ "github.com/lib/pq"  // PostgreSQLドライバーを登録
    _ "github.com/user/app/plugin/hello"  // プラグインを登録
)
```

**用途**:
- database/sql ドライバー登録
- image形式のデコーダー登録
- プラグイン機構
- init()による副作用のみを実行

### ビルドタグによる条件コンパイル

特定の条件でのみプラグインをビルドします。

```go
// +build postgres
// または
//go:build postgres

package postgres

import (
    "database/sql"
    _ "github.com/lib/pq"
)

func Connect() (*sql.DB, error) {
    return sql.Open("postgres", "...")
}
```

```bash
# PostgreSQLプラグインを有効化してビルド
go build -tags postgres

# 複数タグ
go build -tags "postgres redis"
```

### 採用例

#### database/sql

```go
import (
    "database/sql"
    _ "github.com/lib/pq"           // PostgreSQL
    _ "github.com/go-sql-driver/mysql"  // MySQL
)

// ドライバーは init() で自動登録される
db, err := sql.Open("postgres", "...")
```

#### image

```go
import (
    "image"
    _ "image/jpeg"  // JPEG デコーダー登録
    _ "image/png"   // PNG デコーダー登録
)

// 自動的に JPEG/PNG をデコード可能
img, format, _ := image.Decode(file)
```

#### OpenTelemetry

```go
import (
    _ "go.opentelemetry.io/otel/exporters/jaeger"
    _ "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
)

// エクスポーターが自動登録される
```

---

## 初期化順序

Goのパッケージ初期化は決定論的で予測可能です。

### 初期化の順序

1. **深さ優先探索（DFS）でインポート先から初期化**
2. **同一パッケージ内はファイル名の昇順**
3. **各ファイル内は宣言順**

```
main パッケージ
├── import "fmt"
│   ├── import "io"
│   │   └── (ioを初期化)
│   └── (fmtを初期化)
├── import "myapp/config"
│   └── (configを初期化)
└── (mainパッケージを初期化)
```

### 具体例

```go
// a.go
package main

import "fmt"

var A = initA()

func initA() int {
    fmt.Println("Initializing A")
    return 1
}

// b.go
package main

var B = initB()

func initB() int {
    fmt.Println("Initializing B (depends on A:", A, ")")
    return A + 1
}

// main.go
package main

func init() {
    fmt.Println("init() in main.go")
}

func main() {
    fmt.Println("main() starts")
    fmt.Println("A:", A, "B:", B)
}
```

**実行順序**:
```
Initializing A
Initializing B (depends on A: 1 )
init() in main.go
main() starts
A: 1 B: 2
```

**ファイル名昇順**: `a.go` → `b.go` → `main.go`

### init()関数

`init()` は特殊な関数で、各ファイルに複数定義できます。

```go
// config.go
package config

import "fmt"

var Config map[string]string

func init() {
    fmt.Println("init 1: Allocating Config")
    Config = make(map[string]string)
}

func init() {
    fmt.Println("init 2: Loading defaults")
    Config["host"] = "localhost"
    Config["port"] = "8080"
}

func init() {
    fmt.Println("init 3: Loading from environment")
    // 環境変数から読み込み
}
```

**init()の実行順序**: ファイル内で定義された順

---

## cmd/設計方針

`cmd/` ディレクトリは**エントリーポイントのみ**を配置し、ロジックは `internal/` や `pkg/` に分離します。

### 良い設計

```go
// cmd/api/main.go
package main

import (
    "context"
    "log"
    "os"
    "os/signal"
    "syscall"

    "github.com/user/myapp/internal/app"
    "github.com/user/myapp/internal/config"
)

func main() {
    // 1. 設定読み込み
    cfg, err := config.Load()
    if err != nil {
        log.Fatalf("load config: %v", err)
    }

    // 2. コンテキスト作成
    ctx, stop := signal.NotifyContext(context.Background(),
        syscall.SIGINT, syscall.SIGTERM)
    defer stop()

    // 3. アプリケーション起動（ロジックは internal/app に委譲）
    if err := app.Run(ctx, cfg); err != nil {
        log.Fatalf("run app: %v", err)
    }
}
```

### 悪い設計

```go
// ❌ Bad: cmd/api/main.go にロジックを書く
package main

import (
    "database/sql"
    "net/http"
    // ...
)

func main() {
    // データベース接続
    db, err := sql.Open("postgres", "...")
    if err != nil {
        panic(err)
    }

    // ルーター設定
    mux := http.NewServeMux()
    mux.HandleFunc("/users", func(w http.ResponseWriter, r *http.Request) {
        // ハンドラーロジック（ここに書いてはいけない）
        rows, _ := db.Query("SELECT * FROM users")
        // ...
    })

    // サーバー起動
    http.ListenAndServe(":8080", mux)
}
```

### CLIパース程度に留める

`cmd/` ではフラグ解析程度に留め、実行ロジックは別パッケージに委譲します。

```go
// cmd/cli/main.go
package main

import (
    "flag"
    "log"

    "github.com/user/myapp/internal/cli"
)

func main() {
    var (
        configPath = flag.String("config", "config.yaml", "config file path")
        verbose    = flag.Bool("v", false, "verbose output")
    )
    flag.Parse()

    // ロジックは internal/cli に委譲
    if err := cli.Run(*configPath, *verbose); err != nil {
        log.Fatal(err)
    }
}
```

---

## パッケージ階層化3戦略

大規模プロジェクトでは、パッケージを階層化して整理します。

### 1. 共通要素パッケージ（util/common は非推奨）

**❌ Bad**: `util` や `common` に何でも入れる

```
myapp/
├── util/
│   ├── string.go     # 文字列ユーティリティ
│   ├── time.go       # 時刻ユーティリティ
│   ├── http.go       # HTTPユーティリティ
│   └── crypto.go     # 暗号化ユーティリティ
```

**✅ Good**: 目的別パッケージに分割

```
myapp/
├── internal/
│   ├── stringutil/
│   │   └── stringutil.go
│   ├── timeutil/
│   │   └── timeutil.go
│   ├── httputil/
│   │   └── httputil.go
│   └── crypto/
│       └── crypto.go
```

### 2. ルートを共通要素置き場に

小規模プロジェクトでは、ルートパッケージに共通関数を配置できます。

```
mylib/
├── go.mod
├── errors.go         # 共通エラー定義
├── types.go          # 共通型定義
├── client/
│   └── client.go     # クライアント実装
└── server/
    └── server.go     # サーバー実装
```

**使用例**:
```go
import (
    "github.com/user/mylib"          // 共通要素
    "github.com/user/mylib/client"   // クライアント
    "github.com/user/mylib/server"   // サーバー
)

if errors.Is(err, mylib.ErrNotFound) {
    // ...
}
```

### 3. 末端ロジックを子パッケージに

具体的な実装を子パッケージに配置し、抽象インターフェースを親に配置します。

```
myapp/
├── storage/
│   ├── storage.go        # インターフェース定義
│   ├── postgres/
│   │   └── postgres.go   # PostgreSQL実装
│   ├── mysql/
│   │   └── mysql.go      # MySQL実装
│   └── memory/
│       └── memory.go     # インメモリ実装
```

```go
// storage/storage.go
package storage

type Repository interface {
    Save(key, value string) error
    Load(key string) (string, error)
}

// storage/postgres/postgres.go
package postgres

import "github.com/user/myapp/storage"

type postgresRepo struct { ... }

func New() storage.Repository {
    return &postgresRepo{}
}
```

**使用例**:
```go
import (
    "github.com/user/myapp/storage"
    "github.com/user/myapp/storage/postgres"
)

var repo storage.Repository = postgres.New()
```

---

## 1ディレクトリ1パッケージルール

### Goの強制ルール

Goでは**1つのディレクトリには1つの `package` 宣言**しか許可されません（テストを除く）。

```
// ❌ Bad: 同一ディレクトリに複数パッケージは不可
mypackage/
├── foo.go       // package mypackage
└── bar.go       // package other    ← ビルドエラー！
```

### 例外1: テストパッケージ（`_test` サフィックス）

`_test.go` ファイルのみ別パッケージ名が許可されます。これを「外部テスト」と呼びます。

```go
// Good: 外部テストパッケージ（公開APIのみテスト）
// mypackage/foo_test.go
package mypackage_test  // _test サフィックスにより同一ディレクトリで別パッケージ可

import "github.com/user/myapp/mypackage"

func TestFoo(t *testing.T) {
    result := mypackage.Foo()
    // ...
}
```

### 例外2: ビルドタグによる条件付きコンパイル

同一パッケージ名で `//go:build` タグを使い、条件付きコンパイルが可能です。

```go
//go:build linux

package mypackage  // パッケージ名は同一

// Linux専用コード
```

### この制約の利点

| 利点 | 説明 |
|------|------|
| ビルドの単純化 | ディレクトリ = パッケージの1対1対応が明確 |
| IDE支援の向上 | パッケージ境界が明確でナビゲーションが容易 |
| 循環インポート防止 | パッケージ分割の粒度が自然に決まる |

---

## プロジェクト構造のまとめ

| 戦略 | 適用場面 | 例 |
|------|---------|-----|
| 目的別パッケージ | util/commonの代替 | stringutil, timeutil |
| ルートに共通要素 | 小規模ライブラリ | errors.go, types.go |
| 子パッケージに実装 | 複数実装の切り替え | storage/postgres, storage/mysql |
| cmd/はエントリーポイントのみ | すべてのプロジェクト | ロジックはinternal/に委譲 |
| internal/で内部コード保護 | すべてのプロジェクト | 外部からインポート不可 |
