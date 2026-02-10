# Go開発ツール

## 標準ツール

### gofmt
公式フォーマッター。全Goコードに必須：

```bash
# フォーマット確認
gofmt -d .

# フォーマット適用
gofmt -w .

# シンプル化も適用
gofmt -s -w .
```

### goimports
gofmt + インポート整理：

```bash
# インストール
go install golang.org/x/tools/cmd/goimports@latest

# 実行
goimports -w .
```

### go vet
静的解析で潜在的な問題を検出：

```bash
go vet ./...
```

検出例：
- Printf系関数の引数ミスマッチ
- 到達不能コード
- コピーされるべきでない値のコピー

### go mod
依存関係管理：

```bash
# 初期化
go mod init github.com/username/project

# 依存追加
go get github.com/gin-gonic/gin@v1.9.1

# 不要な依存削除
go mod tidy

# 依存のダウンロード
go mod download

# ベンダリング
go mod vendor

# 依存グラフ表示
go mod graph
```

## golangci-lint

### インストール
```bash
# macOS
brew install golangci-lint

# Go
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest

# バイナリ
curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(go env GOPATH)/bin
```

### 実行
```bash
# 全チェック
golangci-lint run

# 特定パッケージ
golangci-lint run ./internal/...

# 自動修正
golangci-lint run --fix
```

### 設定ファイル (.golangci.yml)
```yaml
run:
  timeout: 5m
  tests: true

linters:
  enable:
    - errcheck      # エラーチェック漏れ
    - govet         # go vet
    - ineffassign   # 無駄な代入
    - staticcheck   # 静的解析
    - unused        # 未使用コード
    - gosimple      # 簡略化可能なコード
    - gocritic      # コードレビュー的チェック
    - gofmt         # フォーマット
    - goimports     # インポート整理
    - misspell      # スペルミス
    - revive        # golint後継

linters-settings:
  errcheck:
    check-type-assertions: true
    check-blank: true

  govet:
    enable-all: true

  revive:
    rules:
      - name: exported
        severity: warning
      - name: blank-imports
        severity: warning
      - name: context-as-argument
        severity: warning
      - name: error-return
        severity: warning

issues:
  exclude-rules:
    - path: _test\.go
      linters:
        - errcheck
        - gocritic
```

## delve（デバッガ）

### インストール
```bash
go install github.com/go-delve/delve/cmd/dlv@latest
```

### 使用方法
```bash
# デバッグ実行
dlv debug ./cmd/api

# テストのデバッグ
dlv test ./internal/handler

# 実行中プロセスにアタッチ
dlv attach <pid>

# コアダンプのデバッグ
dlv core ./myapp core.dump
```

### 基本コマンド
```
(dlv) break main.main     # ブレークポイント設定
(dlv) break handler.go:42 # 行指定
(dlv) continue            # 実行継続
(dlv) next                # ステップオーバー
(dlv) step                # ステップイン
(dlv) print variable      # 変数表示
(dlv) locals              # ローカル変数一覧
(dlv) goroutines          # goroutine一覧
(dlv) stack               # スタックトレース
```

## go generate

### 使用例
```go
//go:generate mockgen -source=repository.go -destination=mock_repository.go -package=user

type Repository interface {
    FindByID(ctx context.Context, id string) (*User, error)
}
```

```bash
# 実行
go generate ./...
```

### よく使うジェネレータ
- **mockgen**: モック生成
- **stringer**: String()メソッド生成
- **sqlc**: SQLからGoコード生成
- **ent**: ORMコード生成

## Makefile

```makefile
.PHONY: all build test lint clean

# 変数
BINARY_NAME := myapp
BUILD_DIR := bin
GO_FILES := $(shell find . -name '*.go' -not -path './vendor/*')

# デフォルトターゲット
all: lint test build

# ビルド
build:
	CGO_ENABLED=0 go build -ldflags="-s -w" -o $(BUILD_DIR)/$(BINARY_NAME) ./cmd/api

# 開発ビルド（デバッグ情報付き）
build-dev:
	go build -o $(BUILD_DIR)/$(BINARY_NAME) ./cmd/api

# テスト
test:
	go test -v -race -cover ./...

# カバレッジレポート
coverage:
	go test -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html

# Lint
lint:
	golangci-lint run

# フォーマット
fmt:
	gofmt -s -w .
	goimports -w .

# 依存関係
deps:
	go mod tidy
	go mod verify

# コード生成
generate:
	go generate ./...

# クリーン
clean:
	rm -rf $(BUILD_DIR)
	rm -f coverage.out coverage.html

# 開発サーバー（ホットリロード）
dev:
	air -c .air.toml

# Docker
docker-build:
	docker build -t $(BINARY_NAME) .

docker-run:
	docker run -p 8080:8080 $(BINARY_NAME)
```

## Air（ホットリロード）

### インストール
```bash
go install github.com/air-verse/air@latest
```

### 設定 (.air.toml)
```toml
root = "."
tmp_dir = "tmp"

[build]
  cmd = "go build -o ./tmp/main ./cmd/api"
  bin = "./tmp/main"
  include_ext = ["go", "tpl", "tmpl", "html"]
  exclude_dir = ["assets", "tmp", "vendor", "testdata"]
  delay = 1000

[log]
  time = false

[color]
  main = "magenta"
  watcher = "cyan"
  build = "yellow"
  runner = "green"

[misc]
  clean_on_exit = true
```

## pre-commit

### インストール
```bash
pip install pre-commit
```

### 設定 (.pre-commit-config.yaml)
```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml

  - repo: https://github.com/dnephin/pre-commit-golang
    rev: v0.5.1
    hooks:
      - id: go-fmt
      - id: go-imports
      - id: go-vet
      - id: golangci-lint

  - repo: local
    hooks:
      - id: go-mod-tidy
        name: go mod tidy
        entry: go mod tidy
        language: system
        pass_filenames: false
```

```bash
# 有効化
pre-commit install

# 手動実行
pre-commit run --all-files
```

## CI/CD (GitHub Actions)

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: '1.22'
      - name: golangci-lint
        uses: golangci/golangci-lint-action@v4
        with:
          version: latest

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: '1.22'
      - name: Test
        run: go test -v -race -coverprofile=coverage.out ./...
      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          files: coverage.out

  build:
    runs-on: ubuntu-latest
    needs: [lint, test]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: '1.22'
      - name: Build
        run: go build -o bin/myapp ./cmd/api
```

## ビルドフラグ詳細

### バイナリサイズ削減

#### `-ldflags '-s -w'`
シンボルテーブルとDWARFデバッグ情報を削除してバイナリサイズを大幅削減：

```bash
# デフォルトビルド
go build -o myapp main.go
# サイズ: 1.9MB

# 最適化ビルド
go build -ldflags="-s -w" -o myapp main.go
# サイズ: 1.3MB（約30%削減）
```

オプション詳細：
- `-s`: シンボルテーブル削除（デバッグ情報は残る）
- `-w`: DWARFデバッグ情報削除（スタックトレースは残る）

**注意**: デバッグが困難になるため、開発ビルドでは使用しない。

#### `-trimpath`
ビルドパス情報を削除（セキュリティ・再現性向上）：

```bash
go build -trimpath -ldflags="-s -w" -o myapp main.go
```

効果：
- バイナリからローカルパスが除外される
- 再現可能なビルド（同じソースから同一バイナリ）
- セキュリティ向上（内部パス情報の非公開）

### 変数埋め込み（バージョン情報等）

`-ldflags '-X'`でビルド時に変数を設定：

```go
// version.go
package main

var (
    version = "dev"
    commit  = "unknown"
    date    = "unknown"
)

func printVersion() {
    fmt.Printf("Version: %s\nCommit: %s\nBuild Date: %s\n", version, commit, date)
}
```

```bash
# ビルド時に変数を埋め込む
go build -ldflags "\
  -X main.version=1.0.0 \
  -X main.commit=$(git rev-parse HEAD) \
  -X main.date=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  -o myapp main.go
```

Makefileでの自動化：
```makefile
VERSION := $(shell git describe --tags --always --dirty)
COMMIT := $(shell git rev-parse HEAD)
DATE := $(shell date -u +%Y-%m-%dT%H:%M:%SZ)

build:
	go build -ldflags "\
		-s -w \
		-X main.version=$(VERSION) \
		-X main.commit=$(COMMIT) \
		-X main.date=$(DATE)" \
		-o bin/myapp ./cmd/myapp
```

### 完全静的リンク（コンテナ環境）

```bash
# CGOを無効化して完全静的リンク
CGO_ENABLED=0 go build -ldflags="-s -w" -o myapp main.go

# マルチステージDockerfileでの使用
FROM golang:1.22 AS builder
WORKDIR /app
COPY . .
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o myapp .

FROM scratch
COPY --from=builder /app/myapp /myapp
ENTRYPOINT ["/myapp"]
```

`CGO_ENABLED=0`の効果：
- Cライブラリへの依存を排除
- distroless/scratchイメージで動作可能
- クロスコンパイルが容易

## golangci-lint 段階的導入

### 既存プロジェクトへの導入戦略

#### ステップ1: 最小限のLinterから開始

```bash
# 基本的なチェックのみ有効化
golangci-lint run --disable-all --enable=govet,errcheck,staticcheck
```

推奨初期設定（.golangci.yml）:
```yaml
run:
  timeout: 5m
  tests: true

linters:
  disable-all: true
  enable:
    - govet         # go vet（標準）
    - errcheck      # エラーチェック漏れ
    - staticcheck   # 静的解析

issues:
  max-issues-per-linter: 0
  max-same-issues: 0
```

#### ステップ2: 差分Lintの導入（reviewdog）

新規コードのみチェック（レガシーコードは対象外）:

```bash
# GitHubのdiff範囲でのみLint
reviewdog -f=golangci-lint -reporter=github-pr-check < <(golangci-lint run --out-format=line-number)
```

GitHub Actionsでの設定：
```yaml
- name: Run golangci-lint
  uses: reviewdog/action-golangci-lint@v2
  with:
    golangci_lint_flags: "--config=.golangci.yml"
    reporter: github-pr-review
    fail_on_error: true
```

利点：
- 既存コードは修正不要
- 新規コードの品質を段階的に向上
- PRレビューで自動指摘

#### ステップ3: Linterを段階的に追加

習熟度に応じてチェック項目を増やす：

```yaml
# 第2段階
linters:
  enable:
    - govet
    - errcheck
    - staticcheck
    - unused        # 未使用コード
    - gosimple      # 簡略化可能なコード
    - ineffassign   # 無駄な代入

# 第3段階
linters:
  enable:
    # ... 第2段階のLinter
    - gofmt         # フォーマット
    - goimports     # インポート整理
    - misspell      # スペルミス
    - revive        # golint後継

# 第4段階（厳格）
linters:
  enable:
    # ... 第3段階のLinter
    - gocritic      # 高度なコードレビュー
    - bodyclose     # HTTP Body Close漏れ
    - noctx         # contextなしHTTPリクエスト
```

#### ステップ4: 除外設定の最適化

段階的に除外範囲を縮小：

```yaml
issues:
  exclude-rules:
    # 初期: テストコードを除外
    - path: _test\.go
      linters:
        - errcheck
        - gocritic

    # 第2段階: generated codeのみ除外
    - path: .*_generated\.go
      linters:
        - all

    # 第3段階: 特定パターンのみ除外
    - text: "G104"  # エラーチェック省略を許可する特定パターン
      linters:
        - gosec
```

### ベストプラクティス

| フェーズ | 有効Linter数 | 対象範囲 | 目的 |
|---------|------------|---------|------|
| 導入直後 | 3個 | 差分のみ | 開発速度維持 |
| 1ヶ月後 | 6個 | 差分のみ | 基本品質向上 |
| 3ヶ月後 | 10個 | 新規パッケージ全体 | 品質標準化 |
| 6ヶ月後 | 15個以上 | 全コード | 高品質維持 |

## Goランタイムサポートポリシー

### リリースサポート期間

Goのリリースは**2つ後のメジャーバージョンがリリースされるまでサポート**：

```
Go 1.20 リリース（2023/02）
├─ サポート継続
Go 1.21 リリース（2023/08）
├─ サポート継続
Go 1.22 リリース（2024/02）
└─ Go 1.20 サポート終了 ⚠️
```

### Go 1互換性保証

Goはバージョン1の間は**ソースコードレベルの互換性を約束**：

```go
// Go 1.14で書いたコード
result, err := doSomething()
if err != nil {
    return fmt.Errorf("error: %w", err)
}

// Go 1.22でも同様に動作（再コンパイル必要）
```

例外：
- 言語仕様のバグ修正
- セキュリティ修正
- 明確にドキュメント化されていない動作

### バージョンアップ戦略

#### プロジェクトでの推奨アプローチ

```bash
# 新バージョンリリース後、1-2ヶ月以内にアップグレード
go mod tidy -go=1.22

# CI/CD環境でのテスト
go test -race -cover ./...
```

#### AWS Lambda/Google App Engineでの考慮点

**AWS Lambda:**
- `go1.x`ランタイムは長期サポート
- バイナリが永久に動作する保証はない（OS/ライブラリの定期更新）
- カスタムランタイム（provided.al2）での運用を推奨

**Google App Engine:**
- リリース後、数ヶ月でGAサポート
- 最新バージョンへの移行計画が必要

### go mod tidyでのバージョン指定

```bash
# モジュールをGo 1.22対応に更新
go mod tidy -go=1.22

# go.modファイルの確認
cat go.mod
# go 1.22
# toolchain go1.22.0
```

効果：
- 新バージョンの最適化を利用
- セキュリティパッチの適用
- 性能向上・バイナリサイズ削減

## ツール一覧

| ツール | 目的 | コマンド |
|-------|------|---------|
| gofmt | フォーマット | `gofmt -w .` |
| goimports | インポート整理 | `goimports -w .` |
| go vet | 静的解析 | `go vet ./...` |
| golangci-lint | 統合lint | `golangci-lint run` |
| delve | デバッグ | `dlv debug` |
| air | ホットリロード | `air` |
| mockgen | モック生成 | `go generate` |
