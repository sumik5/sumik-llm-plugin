---
name: writing-clean-go
description: "Teaches clean code practices specific to Go including function design, error handling, data structures, concurrency patterns, and refactoring strategies. Use when writing, reviewing, or refactoring Go code for quality. Complements developing-go (language patterns) and applying-solid-principles (language-agnostic)."
---

# Writing Clean Go

Go言語固有のクリーンコード実践スキル。可読性、保守性、テスト容易性を備えたGoコードを書くための原則とパターンを提供します。

---

## 🎯 使用タイミング

以下の場面で本スキルを参照してください:

- **Goコードのリファクタリング時**: 既存コードの品質改善
- **コードレビューでの品質チェック時**: レビュー基準の適用
- **新規Go関数・構造体設計時**: 設計初期段階からクリーンな構造を
- **並行処理のクリーンな実装時**: goroutine/channel パターンの適用
- **テストコードの設計・改善時**: テスタブルな設計とテーブル駆動テスト

---

## 📚 ドキュメント構成

本スキルは以下のサブファイルで構成されています:

- **[CLEAN-FUNCTIONS.md](./CLEAN-FUNCTIONS.md)**: 関数設計とリファクタリング（命名、引数、早期リターン、DRY/KISS/YAGNI）
- **[ERROR-HANDLING.md](./ERROR-HANDLING.md)**: エラーハンドリングパターン（明示的チェック、ラップ、カスタムエラー）
- **[DATA-STRUCTURES.md](./DATA-STRUCTURES.md)**: データ構造の設計（struct、interface、ゼロ値、カプセル化）
- **[CONCURRENCY-AND-TESTING.md](./CONCURRENCY-AND-TESTING.md)**: 並行処理・テスト・リファクタリング（context、channel、テーブル駆動テスト）

---

## 🔑 Go クリーンコードの核心原則

### 1. 可読性 > 巧妙さ

Goコミュニティでは「Clever code is not idiomatic Go」が鉄則です。読みやすさを最優先にしてください。

```go
// ❌ Dirty: 巧妙だが意図が不明瞭
func c(s string) int { return len(strings.Fields(s)) }

// ✅ Clean: 明示的で理解しやすい
func countWords(text string) int {
    words := strings.Fields(text)
    return len(words)
}
```

**理由**: 巧妙なワンライナーは一時的な満足感を与えますが、後のメンテナンス時に認知負荷を増やします。

### 2. DRY + KISS + YAGNI（Goの文脈で）

- **DRY (Don't Repeat Yourself)**: 過度な抽象化は避ける。3回繰り返したら共通化を検討
- **KISS (Keep It Simple, Stupid)**: Goの哲学は「Less is more」。シンプルに保つ
- **YAGNI (You Aren't Gonna Need It)**: 将来の拡張性を過剰に考えない。必要になったときに追加

```go
// ❌ Dirty: 過度な抽象化（YAGNIに反する）
type Processor interface {
    Process(ctx context.Context, data interface{}) (interface{}, error)
    Validate(data interface{}) error
    Transform(data interface{}) interface{}
}

// ✅ Clean: 必要最小限のインターフェース
type DataProcessor interface {
    Process(ctx context.Context, data []byte) ([]byte, error)
}
```

### 3. 明示的なエラーハンドリング

Goでは「エラーは値」。明示的にチェックし、コンテキストを付けて返します。

```go
// ❌ Dirty: エラーを無視
data, _ := os.ReadFile(path)

// ❌ Dirty: コンテキストなしでラップ
if err != nil {
    return err
}

// ✅ Clean: 明示的チェック + コンテキスト付きラップ
data, err := os.ReadFile(path)
if err != nil {
    return nil, fmt.Errorf("failed to read config file %s: %w", path, err)
}
```

**理由**: コンテキスト付きエラーは、問題発生時のデバッグを劇的に効率化します。

### 4. 小さく焦点を絞った関数

1つの関数は1つの責任を持ち、引数は3つ以下を目標に。

```go
// ❌ Dirty: 複数責任 + 引数過多
func ProcessUserData(id int, name, email, role, department string, active bool) error {
    // 検証、データベース保存、メール送信、ログ記録...
}

// ✅ Clean: 単一責任 + 構造体グループ化
type UserProfile struct {
    ID         int
    Name       string
    Email      string
    Role       string
    Department string
    Active     bool
}

func SaveUserProfile(profile UserProfile) error {
    // データベース保存のみ
}

func NotifyUserCreated(email string) error {
    // メール送信のみ
}
```

**理由**: 小さな関数はテストしやすく、再利用しやすく、理解しやすい。

### 5. インターフェースは小さく

Goのインターフェースは暗黙的実装。1-2メソッドの小さなインターフェースを推奨。

```go
// ❌ Dirty: 巨大なインターフェース（Java的）
type Repository interface {
    Create(data interface{}) error
    Read(id int) (interface{}, error)
    Update(id int, data interface{}) error
    Delete(id int) error
    List() ([]interface{}, error)
    Search(query string) ([]interface{}, error)
}

// ✅ Clean: 小さなインターフェース（Go的）
type Writer interface {
    Write(p []byte) (n int, err error)
}

type Reader interface {
    Read(p []byte) (n int, err error)
}

type UserStore interface {
    SaveUser(u User) error
}

type UserFinder interface {
    FindUserByID(id int) (User, error)
}
```

**理由**: `io.Reader`, `io.Writer` パターンに従い、組み合わせ可能な小さなインターフェースが柔軟性を生みます。

### 6. ゼロ値の活用

Goの「ゼロ値は有用」哲学を活用し、不要な初期化を省きます。

```go
// ❌ Dirty: 不要な初期化
var count int = 0
var name string = ""
users := make([]User, 0)

// ✅ Clean: ゼロ値を活用
var count int
var name string
var users []User
```

**理由**: ゼロ値を有用に設計することで、構造体の初期化が不要になり、コードが簡潔になります。

---

## 📊 Clean vs Dirty 判断基準テーブル

| 要素 | ❌ Dirty | ✅ Clean | 理由 |
|------|---------|---------|------|
| **関数名** | `func f(n int) int` | `func calculateFactorial(number int) int` | 意図が明確 |
| **エラー** | `return nil, e` | `return nil, fmt.Errorf("failed to read %s: %w", path, err)` | コンテキスト付き |
| **引数** | 5個以上のパラメータ | 構造体にグループ化 | 可読性 |
| **else** | ネストしたif-else | 早期リターン（ガード節） | フラットな制御フロー |
| **変数名** | `d`, `e`, `u` | `daysUntilExpiration`, `err`, `user` | 自己文書化 |
| **構造体** | 巨大モノリス構造体 | 単一責任の小さな構造体 | 関心の分離 |
| **interface{}** | `func Process(v interface{})` | `func Process[T any](v T)` (1.18+) | 型安全性 |
| **エラー無視** | `data, _ := fn()` | `data, err := fn(); if err != nil {...}` | 堅牢性 |
| **グローバル変数** | パッケージレベル可変変数 | 依存性注入 / 構造体フィールド | テスタビリティ |
| **panic** | `panic("error")` | `return fmt.Errorf(...)` | 回復可能性 |
| **長い関数** | 100行超の関数 | 10-30行の関数に分割 | 理解容易性 |
| **コメント** | 実装を説明するコメント | 意図を説明するコメント（またはコメント不要） | 自己文書化 |

---

## 🔄 リファクタリングチェックリスト

Goコードをレビュー・リファクタリングする際の必須チェック項目:

### 関数設計
- [ ] 関数は単一責任か？（名前に "and" が必要なら分割）
- [ ] 関数の引数は3つ以下か？（超過なら構造体化）
- [ ] 関数名は動詞で始まっているか？（`CalculateTotal`, `SaveUser`）
- [ ] 戻り値の順序は `(data, error)` か？
- [ ] Exported関数にドキュメントコメントがあるか？

### エラーハンドリング
- [ ] エラーにコンテキストが付いているか？（`%w` でラップ）
- [ ] エラーチェックを省略していないか？（`_, _` は疑わしい）
- [ ] panic は本当に必要か？（errorを返すべきでは？）
- [ ] defer でリソースクリーンアップしているか？

### 制御フロー
- [ ] 不要なelse文がないか？（早期リターンに変換）
- [ ] ネストレベルは3以下か？（深い場合は関数抽出）
- [ ] switch文のdefaultケースがあるか？

### 命名
- [ ] 変数名は意図を表しているか？（1文字変数は小スコープのみ）
- [ ] 略語は一般的か？（`ctx`, `err`, `buf` はOK、`usrMgr` はNG）
- [ ] パッケージ名は短く小文字か？（`util`, `common` は避ける）

### データ構造
- [ ] interfaceは必要最小限か？（1-2メソッド推奨）
- [ ] 構造体フィールドの可視性は適切か？（不要なexportは避ける）
- [ ] ゼロ値で有用な設計か？
- [ ] `interface{}` を避け、型パラメータ（Generics）を検討したか？（Go 1.18+）

### 並行処理
- [ ] 並行処理にcontextが使われているか？（キャンセル対応）
- [ ] goroutineのライフサイクル管理は明確か？
- [ ] data raceの可能性はないか？（`go run -race`）
- [ ] channelのクローズ責任は明確か？

### テスト
- [ ] テストはテーブル駆動か？（`t.Run` で構造化）
- [ ] テスト名は `Test<Function>_<Scenario>_<ExpectedResult>` 形式か？
- [ ] テストカバレッジは十分か？（重要ロジックは100%目標）
- [ ] モックではなく実装でテスト可能か？（過度なモック依存を避ける）

### ツール
- [ ] `gofmt` / `goimports` は実行済みか？
- [ ] `go vet` は警告なしか？
- [ ] `golangci-lint` は通っているか？
- [ ] `go mod tidy` は実行済みか？

---

## 🚨 ユーザー確認の原則（AskUserQuestion）

判断分岐がある場合、推測で進めず必ず **AskUserQuestion** ツールでユーザーに確認してください。

### 確認すべき場面

以下の状況では、必ずユーザーに選択肢を提示してください:

1. **リファクタリング範囲の決定**
   - 関数分割の粒度（1関数 vs 複数関数）
   - リファクタリング対象の範囲（1ファイル vs パッケージ全体）

2. **エラーハンドリング戦略**
   - カスタムエラー型 vs センチネルエラー vs シンプルなラップ
   - エラーの伝播方法（そのまま返す vs コンテキスト付加 vs 変換）

3. **並行処理パターンの選択**
   - Worker Pool vs Fan-out/Fan-in vs Pipeline
   - バッファ付きchannelのサイズ決定

4. **テスト戦略**
   - モック選択（手動モック vs gomock vs testify）
   - テストカバレッジの目標値

5. **interface設計の粒度**
   - 既存の大きなinterfaceを分割する際の分割基準
   - 新規interfaceの導入タイミング

### 確認不要な場面（自動適用可能）

以下は明確なベストプラクティスなので、ユーザー確認なしで適用できます:

- `gofmt` / `goimports` の適用
- 早期リターン（ガード節）への変換
- エラーチェックの追加（`if err != nil` の挿入）
- テーブル駆動テストへの変換（既存テストがある場合）
- `_, _` による意図的なエラー無視を明示的チェックに変換

**例: AskUserQuestionツールの使用**

```go
// 3つの異なるエラーハンドリング戦略がある場合
AskUserQuestion(
    questions=[{
        "question": "エラーハンドリング戦略を選択してください",
        "header": "エラーハンドリング",
        "options": [
            {
                "label": "シンプルなラップ",
                "description": "fmt.Errorf(%w)でコンテキスト追加のみ"
            },
            {
                "label": "センチネルエラー",
                "description": "errors.Is()で比較可能な定数エラー"
            },
            {
                "label": "カスタムエラー型",
                "description": "構造体ベースのエラー型（詳細情報付き）"
            }
        ],
        "multiSelect": False
    }]
)
```

---

## 🔗 関連スキル

本スキルは他のスキルと以下の関係にあります:

| スキル | 関係 |
|--------|------|
| **developing-go** | Go言語仕様・イディオム・プロジェクト構造を提供（本スキルの前提知識） |
| **applying-solid-principles** | 言語非依存のSOLID原則を提供（本スキルはGo固有の適用方法） |
| **testing** | テストファースト開発一般論を提供（本スキルはGoテスト固有のパターン） |
| **enforcing-type-safety** | 型安全性の原則を提供（本スキルはGoのinterface/generics視点） |

**使い分けガイド**:
- **プロジェクト構造や言語仕様が不明** → `developing-go` を参照
- **オブジェクト指向設計原則が必要** → `applying-solid-principles` を参照
- **Go固有のコード品質改善** → 本スキル (`writing-clean-go`) を参照
- **テストファーストアプローチの基本** → `testing` を参照
- **Goコードの品質改善（関数、エラー、構造体）** → 本スキル内のサブファイルを参照

---

## 📖 次のステップ

1. **関数設計を改善したい** → [CLEAN-FUNCTIONS.md](./CLEAN-FUNCTIONS.md) を読む
2. **エラーハンドリングを学びたい** → [ERROR-HANDLING.md](./ERROR-HANDLING.md) を読む
3. **データ構造設計を学びたい** → [DATA-STRUCTURES.md](./DATA-STRUCTURES.md) を読む
4. **並行処理やテストを学びたい** → [CONCURRENCY-AND-TESTING.md](./CONCURRENCY-AND-TESTING.md) を読む

---

## 🎓 学習のヒント

### 読む順序の推奨

初学者は以下の順序で学習することを推奨します:

1. **CLEAN-FUNCTIONS.md** - 関数設計は全ての基礎
2. **ERROR-HANDLING.md** - Goの最重要イディオム
3. **DATA-STRUCTURES.md** - 構造体とinterfaceの設計
4. **CONCURRENCY-AND-TESTING.md** - 応用テクニック

### 実践のポイント

- **小さく始める**: 1つの関数のリファクタリングから
- **ツールを活用**: `gofmt`, `go vet`, `golangci-lint` を常時実行
- **テーブル駆動テストを書く**: リファクタリング後の動作確認
- **レビューを受ける**: 人間の目でのチェックも重要
