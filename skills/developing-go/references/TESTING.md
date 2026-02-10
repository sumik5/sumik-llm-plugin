# Goテスト戦略

## 基本

### ファイル配置
```
mypackage/
├── handler.go
├── handler_test.go      # 同じパッケージ
├── service.go
└── service_test.go
```

### 基本的なテスト
```go
// handler_test.go
package mypackage

import "testing"

func TestAdd(t *testing.T) {
    result := Add(2, 3)
    if result != 5 {
        t.Errorf("Add(2, 3) = %d; want 5", result)
    }
}
```

### テスト実行
```bash
# 全テスト実行
go test ./...

# 特定パッケージ
go test ./internal/handler

# 詳細出力
go test -v ./...

# 特定のテスト
go test -run TestAdd ./...

# カバレッジ
go test -cover ./...
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out
```

## テーブル駆動テスト

### 基本パターン
```go
func TestCalculate(t *testing.T) {
    tests := []struct {
        name     string
        input    int
        expected int
    }{
        {"zero", 0, 0},
        {"positive", 5, 25},
        {"negative", -3, 9},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            result := Calculate(tt.input)
            if result != tt.expected {
                t.Errorf("Calculate(%d) = %d; want %d", tt.input, result, tt.expected)
            }
        })
    }
}
```

### エラーケースを含む
```go
func TestParse(t *testing.T) {
    tests := []struct {
        name    string
        input   string
        want    int
        wantErr bool
    }{
        {"valid", "42", 42, false},
        {"invalid", "abc", 0, true},
        {"empty", "", 0, true},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := Parse(tt.input)
            if (err != nil) != tt.wantErr {
                t.Errorf("Parse(%q) error = %v, wantErr %v", tt.input, err, tt.wantErr)
                return
            }
            if got != tt.want {
                t.Errorf("Parse(%q) = %d; want %d", tt.input, got, tt.want)
            }
        })
    }
}
```

### 構造体の比較
```go
import "reflect"

func TestCreateUser(t *testing.T) {
    tests := []struct {
        name  string
        input CreateUserInput
        want  *User
    }{
        {
            name:  "basic",
            input: CreateUserInput{Name: "John", Email: "john@example.com"},
            want:  &User{Name: "John", Email: "john@example.com"},
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got := CreateUser(tt.input)
            if !reflect.DeepEqual(got, tt.want) {
                t.Errorf("CreateUser() = %+v; want %+v", got, tt.want)
            }
        })
    }
}
```

## t.Error vs t.Fatal

### t.Error: テスト継続
```go
func TestMultipleAssertions(t *testing.T) {
    result := Process()

    if result.Status != "ok" {
        t.Errorf("Status = %q; want %q", result.Status, "ok")
    }
    if result.Count != 10 {
        t.Errorf("Count = %d; want %d", result.Count, 10)
    }
    // 両方のエラーが報告される
}
```

### t.Fatal: テスト即終了
```go
func TestWithSetup(t *testing.T) {
    db, err := setupDatabase()
    if err != nil {
        t.Fatalf("setup failed: %v", err)  // 続行不可能
    }

    // dbを使ったテスト
    result := db.Query()
    if result == nil {
        t.Error("result should not be nil")
    }
}
```

## テストヘルパー

### t.Helper()
```go
func assertEqual(t *testing.T, got, want int) {
    t.Helper()  // エラー行が呼び出し元を指す
    if got != want {
        t.Errorf("got %d; want %d", got, want)
    }
}

func TestWithHelper(t *testing.T) {
    assertEqual(t, Add(2, 3), 5)  // この行が報告される
}
```

### セットアップ/クリーンアップ
```go
func setupTestDB(t *testing.T) *Database {
    t.Helper()
    db, err := NewDatabase(":memory:")
    if err != nil {
        t.Fatalf("setup: %v", err)
    }

    t.Cleanup(func() {
        db.Close()
    })

    return db
}

func TestDatabase(t *testing.T) {
    db := setupTestDB(t)  // 自動クリーンアップ

    // テスト
}
```

## サブテスト

### 並列テスト
```go
func TestParallel(t *testing.T) {
    tests := []struct {
        name  string
        input int
    }{
        {"case1", 1},
        {"case2", 2},
        {"case3", 3},
    }

    for _, tt := range tests {
        tt := tt  // Go 1.22未満では必要
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel()  // 並列実行
            result := SlowProcess(tt.input)
            if result < 0 {
                t.Errorf("unexpected negative result")
            }
        })
    }
}
```

### グループ化
```go
func TestUser(t *testing.T) {
    t.Run("Create", func(t *testing.T) {
        t.Run("valid input", func(t *testing.T) {
            // ...
        })
        t.Run("invalid input", func(t *testing.T) {
            // ...
        })
    })

    t.Run("Delete", func(t *testing.T) {
        // ...
    })
}
```

## モック

### インターフェースベース
```go
// プロダクションコード
type UserRepository interface {
    FindByID(id string) (*User, error)
}

type UserService struct {
    repo UserRepository
}

func (s *UserService) GetUser(id string) (*User, error) {
    return s.repo.FindByID(id)
}

// テストコード
type mockUserRepo struct {
    users map[string]*User
    err   error
}

func (m *mockUserRepo) FindByID(id string) (*User, error) {
    if m.err != nil {
        return nil, m.err
    }
    return m.users[id], nil
}

func TestUserService_GetUser(t *testing.T) {
    mock := &mockUserRepo{
        users: map[string]*User{
            "1": {ID: "1", Name: "John"},
        },
    }
    service := &UserService{repo: mock}

    user, err := service.GetUser("1")
    if err != nil {
        t.Fatalf("unexpected error: %v", err)
    }
    if user.Name != "John" {
        t.Errorf("Name = %q; want %q", user.Name, "John")
    }
}
```

## HTTPテスト

### httptest.Server
```go
import (
    "net/http"
    "net/http/httptest"
    "testing"
)

func TestHTTPClient(t *testing.T) {
    // モックサーバー作成
    server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusOK)
        w.Write([]byte(`{"status":"ok"}`))
    }))
    defer server.Close()

    // クライアントテスト
    client := NewClient(server.URL)
    resp, err := client.GetStatus()
    if err != nil {
        t.Fatalf("unexpected error: %v", err)
    }
    if resp.Status != "ok" {
        t.Errorf("Status = %q; want %q", resp.Status, "ok")
    }
}
```

### httptest.ResponseRecorder
```go
func TestHandler(t *testing.T) {
    req := httptest.NewRequest("GET", "/users/1", nil)
    rec := httptest.NewRecorder()

    handler := NewUserHandler()
    handler.ServeHTTP(rec, req)

    if rec.Code != http.StatusOK {
        t.Errorf("Status = %d; want %d", rec.Code, http.StatusOK)
    }
}
```

## ベンチマーク

```go
func BenchmarkProcess(b *testing.B) {
    data := prepareData()

    b.ResetTimer()  // 準備時間を除外
    for i := 0; i < b.N; i++ {
        Process(data)
    }
}

func BenchmarkProcessParallel(b *testing.B) {
    data := prepareData()

    b.RunParallel(func(pb *testing.PB) {
        for pb.Next() {
            Process(data)
        }
    })
}
```

```bash
go test -bench=. ./...
go test -bench=BenchmarkProcess -benchmem ./...
```

## TestMain

```go
func TestMain(m *testing.M) {
    // セットアップ
    setup()

    // テスト実行
    code := m.Run()

    // クリーンアップ
    cleanup()

    os.Exit(code)
}
```

## ベストプラクティス

| プラクティス | 説明 |
|------------|------|
| テーブル駆動 | 複数ケースを構造化して記述 |
| t.Helper() | ヘルパー関数で使用 |
| t.Parallel() | 独立したテストは並列化 |
| インターフェース | 依存性注入でモック可能に |
| t.Cleanup() | リソースの自動クリーンアップ |
| サブテスト | t.Run()で構造化 |

## アンチパターン

| パターン | 問題 | 修正 |
|---------|------|------|
| グローバル状態に依存 | テストが不安定 | 依存性注入 |
| 外部サービスに直接依存 | CI/CDで失敗 | モック/スタブ |
| 実行順序に依存 | 並列実行で失敗 | 独立したテスト |
| magic number | 意図が不明確 | 名前付き定数 |
| 巨大なテスト関数 | メンテナンス困難 | サブテストに分割 |

## Fuzzing (Go 1.18+)

### 基本的な使い方

Fuzzingは**ランダムな入力でバグを発見する自動テスト**。予期しない入力で脆弱性やpanicを検出します。

```go
// fuzz_test.go
package parser

import "testing"

func FuzzParse(f *testing.F) {
    // シードコーパス（初期入力）を追加
    f.Add("hello")
    f.Add("123")
    f.Add("")
    f.Add("特殊文字!@#$%^&*()")

    // Fuzz関数で自動生成入力をテスト
    f.Fuzz(func(t *testing.T, input string) {
        // panicや予期しないエラーがないことを確認
        result, err := Parse(input)

        // 常に満たすべき不変条件をチェック
        if err == nil && result == nil {
            t.Error("result should not be nil when error is nil")
        }
    })
}
```

### シードコーパスの追加

```go
func FuzzValidateEmail(f *testing.F) {
    // 有効なメールアドレス
    f.Add("user@example.com")
    f.Add("test+tag@example.co.jp")

    // 無効なメールアドレス
    f.Add("invalid")
    f.Add("@example.com")
    f.Add("user@")

    f.Fuzz(func(t *testing.T, email string) {
        // panicを起こさないことを確認
        _, _ = ValidateEmail(email)
    })
}
```

### 実行方法

```bash
# Fuzzing実行（デフォルト: 無限に実行）
go test -fuzz=FuzzParse

# 時間制限を設定
go test -fuzz=FuzzParse -fuzztime=30s

# 発見したクラッシュケースを再現
go test -run=FuzzParse/crasher_hash
```

### コーパスの保存

Fuzzingで発見した入力は`testdata/fuzz/FuzzXxx/`に自動保存：

```
mypackage/
├── parser.go
├── fuzz_test.go
└── testdata/
    └── fuzz/
        └── FuzzParse/
            ├── seed1
            ├── seed2
            └── crasher_abc123  # 発見されたクラッシュケース
```

再実行時はこれらのコーパスが自動的にテストされます。

### Fuzzingのベストプラクティス

| プラクティス | 説明 |
|------------|------|
| 不変条件のチェック | エラーがnilの場合は結果がnilでないことを確認 |
| panicの検出 | 予期しない入力でpanicを起こさないことを確認 |
| シードコーパスの充実 | 既知のエッジケースを追加 |
| CI/CDでの短時間実行 | `-fuzztime=10s`で定期的に実行 |

## testify/assert

標準ライブラリの`if`文に比べ、**簡潔で読みやすいアサーション**を提供：

### インストール

```bash
go get github.com/stretchr/testify/assert
```

### 基本的な使い方

```go
import (
    "testing"
    "github.com/stretchr/testify/assert"
)

func TestCalculate(t *testing.T) {
    result := Calculate(2, 3)

    // 値の比較
    assert.Equal(t, 5, result)
    assert.NotEqual(t, 0, result)

    // nil チェック
    assert.Nil(t, err)
    assert.NotNil(t, result)

    // ブール値
    assert.True(t, result > 0)
    assert.False(t, result < 0)

    // 配列・スライス
    assert.Len(t, items, 3)
    assert.Contains(t, items, "apple")
    assert.ElementsMatch(t, expected, actual)  // 順序無視の比較

    // エラー
    assert.NoError(t, err)
    assert.Error(t, err)
    assert.EqualError(t, err, "expected error message")
}
```

### エラーメッセージのカスタマイズ

```go
assert.Equal(t, 5, result, "計算結果が期待値と一致しません")
```

### require vs assert

```go
import (
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

func TestWithRequire(t *testing.T) {
    db := setupDB()

    // require: 失敗時に即座にテストを終了（t.Fatal相当）
    require.NotNil(t, db, "DB初期化に失敗しました")

    // assert: 失敗してもテスト継続（t.Error相当）
    result := db.Query()
    assert.NotNil(t, result)
}
```

## go-cmp

`reflect.DeepEqual`の代替として、**人間が読みやすい差分表示**を提供：

### インストール

```bash
go get github.com/google/go-cmp/cmp
```

### 基本的な使い方

```go
import (
    "testing"
    "github.com/google/go-cmp/cmp"
)

func TestUser(t *testing.T) {
    got := CreateUser("John", "john@example.com")
    want := &User{
        Name:  "John",
        Email: "john@example.com",
    }

    // 差分がない場合は空文字列、ある場合は詳細な差分
    if diff := cmp.Diff(want, got); diff != "" {
        t.Errorf("CreateUser() mismatch (-want +got):\n%s", diff)
    }
}
```

### 特定フィールドを無視

```go
import "github.com/google/go-cmp/cmp/cmpopts"

func TestUserWithIgnore(t *testing.T) {
    got := CreateUser("John", "john@example.com")
    want := &User{
        Name:  "John",
        Email: "john@example.com",
        // CreatedAtは無視したい
    }

    // CreatedAtフィールドを比較から除外
    if diff := cmp.Diff(want, got, cmpopts.IgnoreFields(User{}, "CreatedAt")); diff != "" {
        t.Errorf("mismatch (-want +got):\n%s", diff)
    }
}
```

### 未エクスポートフィールドの比較

```go
import "github.com/google/go-cmp/cmp/cmpopts"

type privateUser struct {
    name  string  // 未エクスポート
    email string
}

func TestPrivateUser(t *testing.T) {
    got := createPrivateUser("John")
    want := privateUser{name: "John", email: "john@example.com"}

    // 未エクスポートフィールドも比較
    if diff := cmp.Diff(want, got, cmp.AllowUnexported(privateUser{})); diff != "" {
        t.Errorf("mismatch (-want +got):\n%s", diff)
    }
}
```

## テスト困難なものへの対処

### 時刻依存のコード

**問題**: `time.Now()`を直接使うとテストで固定の時刻を設定できない。

**解決策**: Clockインターフェースを導入：

```go
// clock.go
type Clock interface {
    Now() time.Time
}

// 実運用ではシステム時刻を返す
type realClock struct{}

func (realClock) Now() time.Time {
    return time.Now()
}

// テスト用の固定時刻Clock
type fixedClock struct {
    t time.Time
}

func (f fixedClock) Now() time.Time {
    return f.t
}

// サービス
type UserService struct {
    clock Clock
}

func (s *UserService) CreateUser(name string) *User {
    return &User{
        Name:      name,
        CreatedAt: s.clock.Now(),  // Clockから時刻取得
    }
}
```

テストコード：
```go
func TestCreateUser(t *testing.T) {
    fixedTime := time.Date(2024, 1, 1, 0, 0, 0, 0, time.UTC)
    service := &UserService{
        clock: fixedClock{t: fixedTime},
    }

    user := service.CreateUser("John")

    assert.Equal(t, fixedTime, user.CreatedAt)
}
```

### 乱数依存のコード

**問題**: `rand.Int()`を直接使うと再現性のあるテストが書けない。

**解決策**: シード固定または乱数ソースの注入：

```go
// シード固定
func TestWithFixedSeed(t *testing.T) {
    rng := rand.New(rand.NewSource(12345))  // 固定シード
    result := generateRandomID(rng)

    // 毎回同じ結果が返る
    assert.Equal(t, "abc123", result)
}

// 乱数ソースの注入
type Service struct {
    rng *rand.Rand
}

func TestService(t *testing.T) {
    service := &Service{
        rng: rand.New(rand.NewSource(0)),
    }
    // テスト可能に
}
```

### 外部サービス依存のコード

**問題**: HTTPクライアントが本物のAPIを叩いてしまう。

**解決策**: httptest.Serverでモックサーバーを立てる：

```go
func TestHTTPClient(t *testing.T) {
    // モックサーバー
    server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        assert.Equal(t, "/users/1", r.URL.Path)
        w.Header().Set("Content-Type", "application/json")
        w.WriteHeader(http.StatusOK)
        json.NewEncoder(w).Encode(map[string]string{"name": "John"})
    }))
    defer server.Close()

    // クライアントにモックサーバーのURLを使用
    client := NewClient(server.URL)
    user, err := client.GetUser("1")

    assert.NoError(t, err)
    assert.Equal(t, "John", user.Name)
}
```

## Example関数

Example関数は**ドキュメントとテストを兼ねる**特殊な関数：

### 基本的な使い方

```go
// example_test.go
package math

import "fmt"

func ExampleAdd() {
    result := Add(2, 3)
    fmt.Println(result)
    // Output: 5
}

func ExampleAdd_negative() {
    result := Add(-2, -3)
    fmt.Println(result)
    // Output: -5
}
```

実行：
```bash
go test -v
# === RUN   ExampleAdd
# --- PASS: ExampleAdd (0.00s)
```

### GoDo/home/ubuntu/Documents/sumik-claude-pluginでの表示

Example関数は**公式ドキュメント**に自動的に表示されます：

```bash
go doc -all math.Add
# func Add(a, b int) int
#
# Example:
#     result := Add(2, 3)
#     fmt.Println(result)
#     // Output: 5
```

### 複数の出力行

```go
func ExampleParseCSV() {
    data := ParseCSV("a,b,c\n1,2,3")
    for _, row := range data {
        fmt.Println(row)
    }
    // Output:
    // [a b c]
    // [1 2 3]
}
```

### 順不同の出力

```go
func ExampleGetKeys() {
    keys := GetKeys(map[string]int{"a": 1, "b": 2})
    for _, k := range keys {
        fmt.Println(k)
    }
    // Unordered output:
    // a
    // b
}
```

## TestMain

**テストスイート全体**のセットアップ/ティアダウンを実行：

### 基本的な使い方

```go
func TestMain(m *testing.M) {
    // 1. テスト全体の実行前
    setup()

    // 2. テスト実行
    code := m.Run()

    // 3. テスト全体の実行後
    cleanup()

    // 4. 終了コードを返す
    os.Exit(code)
}

func setup() {
    // DB接続、環境変数設定等
    fmt.Println("setup")
}

func cleanup() {
    // DB切断、一時ファイル削除等
    fmt.Println("cleanup")
}
```

### データベースのセットアップ例

```go
var testDB *sql.DB

func TestMain(m *testing.M) {
    var err error
    testDB, err = sql.Open("sqlite3", ":memory:")
    if err != nil {
        log.Fatal(err)
    }
    defer testDB.Close()

    // スキーマ作成
    if err := setupSchema(testDB); err != nil {
        log.Fatal(err)
    }

    // テスト実行
    code := m.Run()
    os.Exit(code)
}

func TestQuery(t *testing.T) {
    // testDBを使ったテスト
    rows, err := testDB.Query("SELECT * FROM users")
    assert.NoError(t, err)
    defer rows.Close()
}
```

### 注意点

- `TestMain`が存在する場合、通常の`Test*`関数の前後処理は実行されない
- テストごとの前後処理は`t.Cleanup()`を使用
- `m.Run()`の戻り値を必ず`os.Exit()`に渡す
