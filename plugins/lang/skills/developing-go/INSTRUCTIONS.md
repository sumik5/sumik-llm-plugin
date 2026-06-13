# Go開発ガイド（Modern Go Development）

## 🎯 使用タイミング
- **Goプロジェクト新規作成時**
- **既存Goコードのレビュー・改善時**
- **並行処理の実装時**
- **エラーハンドリング設計時**
- **Goのテスト作成時**

## 📚 ドキュメント構成

このスキルは以下のドキュメントで構成されています：

### 1. [命名規則](./references/NAMING.md)
Goの命名ベストプラクティス：
- パッケージ名の付け方
- 変数・関数名の規則
- インターフェース命名（-erサフィックス）
- エクスポート名の考え方

### 2. [エラーハンドリング](./references/ERROR-HANDLING.md)
堅牢なエラー処理パターン：
- エラーは値として扱う
- エラーラッピング（%w vs %v）
- センチネルエラーとカスタムエラー型
- panic/recoverの適切な使用

### 3. [並行処理](./references/CONCURRENCY.md)
Goの強力な並行処理パターン：
- goroutineの基本
- チャネルによる通信
- select文の活用
- 同期プリミティブ（sync.Mutex等）
- コンテキストによるキャンセル

### 4. [テスト戦略](./references/TESTING.md)
効果的なGoテストの書き方：
- テーブル駆動テスト
- t.Errorとt.Fatalの使い分け
- サブテスト（t.Run）
- ベンチマークテスト
- テストヘルパーの作成

### 5. [nilハンドリング](./references/NIL-HANDLING.md)
nil値の包括的ガイド：
- interfaceの(type,value)パラドックス
- 型別nil挙動一覧（ポインタ/スライス/マップ/チャネル/関数/interface）
- nil receiverガードパターン
- nilスライス vs 空スライス

### 6. [プロジェクト構造](./references/PROJECT-STRUCTURE.md)
推奨ディレクトリレイアウト：
- cmd/とinternal/の使い分け
- pkg/の適切な使用
- go.modの管理
- モジュール設計

### 7. [開発ツール](./references/TOOLING.md)
Goエコシステムのツール活用：
- gofmt/goimports
- golangci-lint
- go vet
- delve（デバッガ）
- Makefileパターン

### 8. [クリーンな関数設計](./references/CLEAN-FUNCTIONS.md)
関数設計とリファクタリング：
- 命名、引数、早期リターン
- DRY/KISS/YAGNIの適用
- 小さく焦点を絞った関数

### 9. [データ構造設計](./references/DATA-STRUCTURES.md)
構造体とインターフェースの設計：
- struct、interface、ゼロ値
- カプセル化の強化

### 10. [クリーンなエラーハンドリング](./references/ERROR-HANDLING-CLEAN.md)
エラーハンドリングパターンの詳細：
- 明示的チェック、ラップ
- カスタムエラー型の設計
- センチネルエラーとエラーチェーン

### 11. [並行処理とテスト](./references/CONCURRENCY-AND-TESTING.md)
並行処理・テスト・リファクタリング：
- context、channel
- テーブル駆動テスト
- リファクタリングチェックリスト

## 🎯 Goの設計哲学とクリーンコード原則

### 1. 可読性 > 巧妙さ
Goコミュニティでは「Clever code is not idiomatic Go」が鉄則。読みやすさを最優先に。

### 2. DRY + KISS + YAGNI
- **DRY (Don't Repeat Yourself)**: 3回繰り返したら共通化を検討
- **KISS (Keep It Simple, Stupid)**: シンプルに保つ
- **YAGNI (You Aren't Gonna Need It)**: 必要になったときに追加

### 3. 小さく焦点を絞った関数
1つの関数は1つの責任を持ち、引数は3つ以下を目標に。

### 4. インターフェースは小さく
1-2メソッドの小さなインターフェースを推奨（`io.Reader`, `io.Writer`パターン）。

### 5. ゼロ値の活用
不要な初期化を省き、ゼロ値で有用な設計を心がける。

### シンプルさを重視
```go
// Good: シンプルで明確
func ProcessItems(items []Item) error {
    for _, item := range items {
        if err := item.Process(); err != nil {
            return fmt.Errorf("process item %s: %w", item.ID, err)
        }
    }
    return nil
}

// Bad: 過度な抽象化
func ProcessItems(items []Item, processor ItemProcessor, validator ItemValidator) error {
    // 不必要な複雑さ
}
```

### 明示的であること
```go
// Good: 明示的なエラーハンドリング
result, err := doSomething()
if err != nil {
    return err
}

// Bad: エラーを無視
result, _ := doSomething()
```

### 通信でメモリを共有
```go
// Good: チャネルで通信
results := make(chan Result)
go func() {
    results <- process(data)
}()
result := <-results

// Avoid: 共有メモリでの通信（必要な場合のみ）
var mu sync.Mutex
var shared int
```

## 🚀 クイックスタート

### 1. プロジェクト初期化
```bash
# モジュール作成
mkdir my-project && cd my-project
go mod init github.com/username/my-project

# 基本構造
mkdir -p cmd/myapp internal/handler internal/service
```

### 2. 基本的なmain.go
```go
package main

import (
    "context"
    "log"
    "os"
    "os/signal"
    "syscall"
)

func main() {
    ctx, cancel := signal.NotifyContext(context.Background(),
        os.Interrupt, syscall.SIGTERM)
    defer cancel()

    if err := run(ctx); err != nil {
        log.Fatal(err)
    }
}

func run(ctx context.Context) error {
    // アプリケーションロジック
    return nil
}
```

### 3. 開発コマンド
```bash
# フォーマット
gofmt -w .

# Lint
golangci-lint run

# テスト
go test ./...

# ビルド
go build -o bin/myapp ./cmd/myapp
```

## 💡 重要な原則

### ゼロ値の活用
```go
// Good: ゼロ値で有効な状態
type Counter struct {
    mu    sync.Mutex
    count int  // ゼロ値は0で有効
}

func (c *Counter) Inc() {
    c.mu.Lock()
    c.count++
    c.mu.Unlock()
}

// 初期化なしで使用可能
var c Counter
c.Inc()
```

### インターフェースは小さく
```go
// Good: 単一メソッドインターフェース
type Reader interface {
    Read(p []byte) (n int, err error)
}

type Writer interface {
    Write(p []byte) (n int, err error)
}

// 組み合わせで拡張
type ReadWriter interface {
    Reader
    Writer
}
```

### 早期リターン
```go
// Good: ガード節で早期リターン
func process(item *Item) error {
    if item == nil {
        return errors.New("item is nil")
    }
    if item.ID == "" {
        return errors.New("item ID is empty")
    }

    // メインロジック
    return item.Save()
}
```

## ユーザー確認の原則（AskUserQuestion）

**判断分岐がある場合、推測で進めず必ずAskUserQuestionツールでユーザーに確認する。**

### 確認すべき場面

| 確認項目 | 例 |
|---|---|
| HTTPフレームワーク | net/http, Chi, Gin, Echo |
| プロジェクト構造 | Standard Layout, Flat, Domain-driven |
| DBドライバ | database/sql, sqlx, GORM, ent |
| ログライブラリ | log/slog, zap, zerolog |
| 設定管理 | 環境変数, Viper, envconfig |

### 確認不要な場面

- Go バージョン（go.mod記載のバージョンに従う）
- コードフォーマッタ（gofmt/goimports は必須）
- エラーハンドリングスタイル（Google Style Guide準拠）

## 🔗 関連スキル

- **[writing-clean-code](../writing-clean-code/SKILL.md)**: SOLID原則とクリーンコード
- **[testing-code](../testing-code/SKILL.md)**: テストファーストアプローチ
- **[securing-code](../securing-code/SKILL.md)**: セキュアコーディング
- **[practicing-devops](../practicing-devops/SKILL.md)**: Goアプリのコンテナ化

## 📖 参考リソース

- [Effective Go](https://go.dev/doc/effective_go)
- [Google Go Style Guide](https://google.github.io/styleguide/go/)
- [Go Code Review Comments](https://github.com/golang/go/wiki/CodeReviewComments)

## Design Patterns

GoFデザインパターン、Go並行処理パターン、アーキテクチャパターン（DDD/CQRS/Event Sourcing）。

| ファイル | 内容 |
|---------|------|
| [DP-CREATIONAL.md](./references/DP-CREATIONAL.md) | 生成パターン（Factory, Builder, Singleton等） |
| [DP-STRUCTURAL.md](./references/DP-STRUCTURAL.md) | 構造パターン（Adapter, Decorator, Proxy等） |
| [DP-BEHAVIORAL.md](./references/DP-BEHAVIORAL.md) | 振る舞いパターン（Strategy, Observer, Command等） |
| [DP-CONCURRENCY.md](./references/DP-CONCURRENCY.md) | 並行処理パターン（Pipeline, Fan-out/Fan-in等） |
| [DP-ADVANCED.md](./references/DP-ADVANCED.md) | 高度なパターン（DDD, CQRS, Event Sourcing） |
| [DP-ANTI-PATTERNS.md](./references/DP-ANTI-PATTERNS.md) | アンチパターンと回避策 |
| [DP-TESTING.md](./references/DP-TESTING.md) | パターンのテスト手法 |
| [DP-CASE-STUDIES.md](./references/DP-CASE-STUDIES.md) | 実システムでのパターン適用ケーススタディ |

## 実践パターン

本番環境で頻出する実践的知識（HTTP通信、データフォーマット、DB操作、ログ、クラウドデプロイ）。

| ファイル | 内容 |
|---------|------|
| [PRACTICAL-PATTERNS.md](./references/PRACTICAL-PATTERNS.md) | 定数/iota、Functional Option、ドメイン型、メモリ最適化、文字列結合、日時処理 |
| [DATA-FORMATS.md](./references/DATA-FORMATS.md) | JSON/CSV/Excel/固定長データ処理（カスタムマーシャラー、BOM対応、巨大ファイル） |
| [DATABASE.md](./references/DATABASE.md) | database/sql、トランザクション、コネクションプール、バッチインサート、sqlc/sqlboiler/GORM |
| [HTTP-SERVER.md](./references/HTTP-SERVER.md) | net/http、ルーター（chi）、Middleware、SPA配信、oapi-codegen |
| [TEMPLATE-ENGINE.md](./references/TEMPLATE-ENGINE.md) | html/templateとtext/templateの使い分け：コンテキスト依存XSS防御、マルチファイルテンプレート（ParseFiles/ExecuteTemplate）、FuncMapによるカスタム関数 |
| [HTTP-CLIENT.md](./references/HTTP-CLIENT.md) | RoundTripperパターン、リトライ（Exponential Backoff/Jitter）、プロキシ対応 |
| [LOGGING.md](./references/LOGGING.md) | 構造化ログ（zerolog/zap/slog）、ログレベル戦略、net/httpエラーログカスタマイズ |
| [CLOUD-CONTAINER.md](./references/CLOUD-CONTAINER.md) | Graceful Shutdown、コンテナイメージ（distroless/scratch）、ヘルスチェック、設定管理 |

## Go Internals

型システム、メモリレイアウト、スライス/マップ内部構造、interfaceの表現、リフレクション、Goスケジューラー。

| ファイル | 内容 |
|---------|------|
| [INT-TYPE-SYSTEM.md](./references/INT-TYPE-SYSTEM.md) | 型システムと基本型のメモリレイアウト |
| [INT-COMPOSITE-INTERNALS.md](./references/INT-COMPOSITE-INTERNALS.md) | スライス・マップ・チャネルの内部構造 |
| [INT-INTERFACE-INTERNALS.md](./references/INT-INTERFACE-INTERNALS.md) | interfaceの実装とディスパッチ |
| [INT-REFLECTION.md](./references/INT-REFLECTION.md) | reflectパッケージとコード生成 |
| [INT-LOW-LEVEL.md](./references/INT-LOW-LEVEL.md) | unsafe/cgo/メモリ管理 |
| [INT-SCHEDULER.md](./references/INT-SCHEDULER.md) | Goスケジューラーの内部構造（G-M-Pモデル、ワークスティーリング） |
| [CONCURRENCY-SCALE.md](./references/CONCURRENCY-SCALE.md) | 大規模開発での並行処理（エラー伝播、タイムアウト、ハートビート、流量制限、Healingパターン） |

## 📖 次のステップ

1. **初めての方**: [プロジェクト構造](./references/PROJECT-STRUCTURE.md)から始めてください
2. **命名に迷ったら**: [命名規則](./references/NAMING.md)を参照
3. **エラー処理**: [エラーハンドリング](./references/ERROR-HANDLING.md)でパターン確認
4. **並行処理**: [並行処理](./references/CONCURRENCY.md)でgoroutine/channel学習
5. **テスト作成**: [テスト戦略](./references/TESTING.md)でテーブル駆動テスト
6. **ツール設定**: [開発ツール](./references/TOOLING.md)でlint設定
7. **デザインパターン**: [DP-CREATIONAL.md](./references/DP-CREATIONAL.md)からパターン学習
8. **内部構造理解**: [INT-TYPE-SYSTEM.md](./references/INT-TYPE-SYSTEM.md)から型システム学習
