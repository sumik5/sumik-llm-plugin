# ログとオブザーバビリティ

## 現代のログ戦略

### アーキテクチャの変化

- **標準出力に出力 + クラウドログ収集**: ログローテーション不要
- **構造化ログ（JSON/LTSV）**: 機械可読、分析可能
- **コンテナ環境**: 標準出力をエージェント（Firelenz/CloudWatch Logs）が自動収集
- **ログローテーション廃止**: サービス停止リスク解消、運用シンプル化
- **分散トレーシング**: マイクロサービス間の処理追跡（OpenTelemetry）

### ログの目的別要件

| 目的 | 必要な情報 |
|-----|-----------|
| 不具合追跡 | 入力値、エラー発生箇所、ユニークなエラーコード |
| パフォーマンス改善 | 処理時間、ボトルネック箇所 |
| 運用監視 | エラーレベル、サーバー停止検知 |
| セキュリティ監査 | ユーザー操作履歴、IPアドレス、ログイン/ログアウト |
| ユーザー行動分析 | セッションID、ユーザー状態のスナップショット |

## 標準ライブラリ log

### 基本的な使い方

```go
import "log"

log.Println("ログ出力をします")
// output: 2020/02/13 22:26:27 ログ出力をします

n := 10
s := "文字列"
log.Printf("%d, %sなどを使って変数出力", n, s)
```

**用途**: デバッグ時の変数ダンプ、開発中の一時的ログ。

### ユニットテスト内のログ

```go
func TestLog(t *testing.T) {
    t.Log("失敗時やgo test -vのときだけ表示されます")
    t.Fatal("メッセージとともにテストを失敗させます")
}
```

**重要**: テストコード内では`t.Log()`/`t.Fatal()`を使用。`log`パッケージは使わない。

### 出力先カスタマイズ

```go
// 標準出力に変更
log.SetOutput(os.Stdout)

// ファイルと標準エラー出力に同時出力
file, _ := os.Create("log.txt")
log.SetOutput(io.MultiWriter(file, os.Stderr))
```

### フォーマット設定

```go
// ファイル名と行番号を出力
log.SetFlags(log.Lshortfile)

// フルパスと行番号
log.SetFlags(log.Llongfile)

// 日時 + ファイル名
log.SetFlags(log.LstdFlags | log.Lshortfile)

// 接頭辞設定（視認性向上）
log.SetPrefix("🔥 ERROR: ")
```

### 用途と制限

| 用途 | 推奨 |
|-----|------|
| デバッグ時の変数ダンプ | ✅ 推奨 |
| 本番環境の業務ログ | ❌ 構造化ログ使用 |
| ユニットテスト内 | ❌ `t.Log()`使用 |

**原則**: `log`パッケージは開発中のみ使用し、コミット前に削除。本番ログは構造化ログを使う。

## 構造化ログ

### 構造化ログとは

キーと値のペアで情報を記録。JSON/LTSV形式で出力し、ログ分析サービス（CloudWatch Logs/Cloud Logging）で検索・フィルタリング可能。

### ライブラリ選択

| ライブラリ | 特徴 |
|----------|------|
| **zerolog** | 高速、ゼロアロケーション、JSON出力 |
| **zap** | Uber製、型安全、高性能 |
| **slog** | Go 1.21+標準ライブラリ、公式推奨 |

**推奨**: `rs/zerolog`（速度重視）、`slog`（標準化重視）

## zerolog

### 基本的な使い方

```go
import (
    "github.com/rs/zerolog"
    "github.com/rs/zerolog/log"
)

log.Printf("Hello World")
// {"level":"debug","time":"2020-02-13T22:47:19+09:00","message":"Hello World"}
```

### ログレベル

| レベル | メソッド | 用途 |
|-------|---------|------|
| Panic | `Panic()` | panic()呼び出し、ゴルーチン終了 |
| Fatal | `Fatal()` | 致命的エラー、プログラム異常終了 |
| Error | `Error()` | エラー、予期しない実行エラー |
| Warn | `Warn()` | 警告、正常とは言えない予期しない問題 |
| Info | `Info()` | システム実行状況、通常の情報 |
| Debug | `Debug()` | デバッグ用情報 |
| Trace | `Trace()` | デバッグよりも詳細な情報 |

```go
log.Info().Msg("サーバー起動")
log.Warn().Str("user", "alice").Msg("権限不足")
log.Error().Err(err).Msg("データベース接続失敗")
```

### フィールド付きログ

```go
log.Info().
    Str("user_id", "12345").
    Int("status_code", 200).
    Dur("latency", time.Since(start)).
    Msg("リクエスト完了")

// {"level":"info","user_id":"12345","status_code":200,"latency":123,"message":"リクエスト完了","time":"..."}
```

### コンテキスト付きロガー

```go
// 共通フィールドを持つロガー作成
logger := log.With().
    Str("service", "api-server").
    Str("version", "1.0.0").
    Logger()

logger.Info().Msg("起動完了")
// {"level":"info","service":"api-server","version":"1.0.0","message":"起動完了","time":"..."}
```

### グローバルログレベル設定

```go
// 環境変数でログレベル制御
if os.Getenv("ENV") == "production" {
    zerolog.SetGlobalLevel(zerolog.InfoLevel)
} else {
    zerolog.SetGlobalLevel(zerolog.DebugLevel)
}
```

### HTTP リクエストログ

```go
func loggingMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        start := time.Now()

        // ResponseWriterをラップしてステータスコードキャプチャ
        recorder := &statusRecorder{ResponseWriter: w}
        next.ServeHTTP(recorder, r)

        log.Info().
            Str("method", r.Method).
            Str("path", r.URL.Path).
            Int("status", recorder.statusCode).
            Dur("latency", time.Since(start)).
            Str("ip", r.RemoteAddr).
            Msg("request")
    })
}
```

## エラーとログの関係

### 基本原則

- **エラーは値**: 関数の戻り値として返す
- **ログは副作用**: システムの状態を記録

### ログレベルの使い分け

```go
// Good: エラーレベルの適切な使い分け
func processOrder(orderID string) error {
    order, err := db.GetOrder(orderID)
    if err != nil {
        // データベースエラー: ERROR
        log.Error().Err(err).Str("order_id", orderID).Msg("注文取得失敗")
        return err
    }

    if order.Status != "pending" {
        // ビジネスロジックエラー: WARN
        log.Warn().Str("order_id", orderID).Str("status", order.Status).Msg("注文が保留状態ではない")
        return fmt.Errorf("order not pending")
    }

    // 正常処理: INFO
    log.Info().Str("order_id", orderID).Msg("注文処理開始")
    return nil
}
```

### エラーログのベストプラクティス

| プラクティス | 説明 |
|------------|------|
| エラーは1箇所でログ | 関数チェーン中で多重ログ出力しない |
| エラーコード付与 | ユニークなIDで発生箇所特定 |
| 入力値を記録 | 再現性のため |
| スタックトレース | xerrors/errors.Wrap使用 |

```go
// Good: エラーコード付きログ
log.Error().
    Err(err).
    Str("error_code", "ORD-001").
    Str("order_id", orderID).
    Msg("注文処理エラー")
```

## net/httpエラーログのカスタマイズ

```go
// デフォルトのhttp.Serverはlog.Logger使用
srv := &http.Server{
    Addr:    ":8080",
    Handler: r,
    ErrorLog: log.New(os.Stderr, "http: ", log.LstdFlags),
}

// zerologに統合
srv.ErrorLog = log.New(&zerologWriter{logger: log.Logger}, "", 0)

type zerologWriter struct {
    logger zerolog.Logger
}

func (w *zerologWriter) Write(p []byte) (n int, err error) {
    w.logger.Error().Msg(string(p))
    return len(p), nil
}
```

## 機密情報のマスキング

### Stringer/GoStringer実装

```go
type User struct {
    ID       string
    Name     string
    Password string
}

// String() で機密情報をマスク
func (u User) String() string {
    return fmt.Sprintf("User{ID:%s, Name:%s, Password:***}", u.ID, u.Name)
}

log.Info().Str("user", user.String()).Msg("ユーザー登録")
// {"level":"info","user":"User{ID:123, Name:Alice, Password:***}","message":"ユーザー登録"}
```

**重要**: パスワード、APIキー、個人情報は絶対にログ出力しない。

## 分散トレーシング（概要）

### OpenTelemetry

マイクロサービス間のリクエスト追跡。同一セッションでTrace IDを共有。

```go
import "go.opentelemetry.io/otel"

// Trace ID をログに含める
traceID := span.SpanContext().TraceID().String()
log.Info().Str("trace_id", traceID).Msg("リクエスト処理")
```

詳細は`implementing-opentelemetry`スキル参照。

## ログとコスト

### クラウドログサービスのコスト管理

- **出力量削減**: 不要なログを絞り込む
- **保存期間設定**: エラーログは長期、デバッグログは短期
- **アーカイブ**: S3/Cloud Storage に低コスト保存
- **サンプリング**: 全件出力せず一定割合のみ

### セキュリティログの特別扱い

- **100%出力**: サンプリング禁止
- **最低3ヶ月即座検査可能**: PCI DSS要件
- **最低1年保存**: 監査要件
- **改変防止**: S3のロック機能等使用
- **アクセス制限**: 権限者のみ閲覧可能
- **閲覧ログ記録**: ログ閲覧自体をログ記録

## ベストプラクティス

| プラクティス | 説明 |
|------------|------|
| 標準出力に出力 | ログローテーション不要 |
| 構造化ログ使用 | JSON形式、キーバリュー |
| ログレベル適切設定 | ERROR以上でアラート |
| 機密情報マスク | パスワード/個人情報除外 |
| エラーコード付与 | 発生箇所特定のためユニークID |
| 入力値記録 | 再現性確保 |
| コンテキスト情報追加 | trace_id, user_id等 |
| デバッグログはコミット前削除 | 本番環境に残さない |
| セキュリティログは別扱い | 100%出力、長期保存 |

## アンチパターン

| パターン | 問題 | 修正 |
|---------|------|------|
| log.Println多用 | 構造化されていない | zerolog/slog使用 |
| ログレベル未設定 | 重要度不明 | 適切なレベル設定 |
| 機密情報出力 | セキュリティリスク | Stringerでマスク |
| エラー多重ログ | ログが重複 | 1箇所でログ出力 |
| 全件出力 | コスト増大 | サンプリング検討 |
| ファイル出力 | ログローテーション必要 | 標準出力使用 |
| デバッグログコミット | 本番環境でノイズ | コミット前削除 |
| セキュリティログサンプリング | 監査不可 | 100%出力 |
