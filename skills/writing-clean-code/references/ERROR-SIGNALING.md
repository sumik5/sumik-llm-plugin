# エラーシグナリング戦略

エラーをどう「伝えるか」の設計は、コードの堅牢性を左右する根本的な選択。回復可能性の判断から8つのシグナリング方式の詳細比較まで、実践的な意思決定フレームワークを提供する。

---

## エラー回復可能性の判断フロー

```
エラーが発生した
        ↓
プログラムがこのエラーから回復できるか？
    ├─ Yes（回復可能）→
    │   呼び出し側は回復したいか？
    │   ├─ Yes → 明示的なシグナリング手法を使う
    │   └─ 不明 → 明示的なシグナリング手法を使う（安全側に倒す）
    └─ No（回復不能）→
        Fail Fast + Fail Loudの原則を適用する
        ├─ 開発中: 例外を投げ、スタックトレースで場所を特定
        └─ 本番: エラーログ + 監視・アラートで検出
```

### 重要な原則：呼び出し側のみが回復可能性を判断できる

```java
// このparse()関数は、自分の呼び出し側を知らない
class PhoneNumber {
    static PhoneNumber parse(String number) {
        if (!isValidPhoneNumber(number)) {
            // ここで回復できるか判断できない！
            // 呼び出し側によって異なる:
            //   - ハードコードされた値からの呼び出し → プログラミングエラー（回復不能）
            //   - ユーザー入力からの呼び出し → 入力検証エラー（回復可能）
        }
    }
}

// 呼び出し側A: 回復不能
PhoneNumber getHeadOfficeNumber() {
    return PhoneNumber.parse("01234typo56789");  // バグ
}

// 呼び出し側B: 回復可能
PhoneNumber getUserPhoneNumber(UserInput input) {
    return PhoneNumber.parse(input.getPhoneNumber());  // ユーザー入力検証
}
```

**設計指針**: 自分のコードがどこから呼ばれるか完全に把握できない場合、回復可能として扱い、明示的なシグナリングを使う。

---

## Fail Fast / Fail Loud 原則

### Fail Fast（早期失敗）

エラーを発生源に近い場所でシグナルする。

```
// Bad: Fail Fastでない場合
エラー発生箇所 → 誤データが伝播 → 誤データが伝播 → エラー顕現
（ここから逆にたどる必要がある）

// Good: Fail Fastな場合
エラー発生箇所 → 即時例外（スタックトレースに正確な場所）
```

**なぜ重要か**:
- エラー発生箇所から離れた場所でエラーが表れると、デバッグに多大な時間がかかる
- 誤データが伝播して別の問題（データ破損など）を引き起こす可能性がある

### Fail Loud（大きな失敗）

エラーが静かに無視されないようにする。

```java
// Bad: エラーが隠れる
void saveData(Database db, Data data) {
    try {
        db.save(data);
    } catch (Exception e) {
        // 何もしない → エラーが消える
    }
}

// Good: エラーを明示的に扱う
void saveData(Database db, Data data) {
    try {
        db.save(data);
    } catch (DatabaseException e) {
        logger.error("データ保存失敗: {}", e.getMessage(), e);
        throw e;  // 上位に伝播させる
    }
}
```

### 回復可能性のスコープ

```
サーバー全体をクラッシュさせる必要はない場合：

リクエスト処理ロジック
    ↓ Unchecked例外が発生
サーバーの上位ハンドラ（try-catch）
    ├─ エラーをログに記録（詳細情報で後からデバッグ可能に）
    ├─ 監視システムへのアラート
    └─ エラーレスポンスを返す（サーバー全体は継続稼働）
```

---

## 8つのエラーシグナリング方式 詳細比較表

| # | 方式 | 明示/暗黙 | コントラクト位置 | 呼び出し側の認識強制 |
|---|------|-----------|----------------|-------------------|
| 1 | Checked例外 | **明示的** | 必須 | コンパイルエラー |
| 2 | Unchecked例外 | **暗黙的** | Small Print | なし |
| 3 | Nullable戻り値（null安全あり） | **明示的** | 必須 | コンパイラが検査強制 |
| 4 | Result型 | **明示的** | 必須 | `hasError()`チェックが必要 |
| 5 | Outcome型（@CheckReturnValue付き） | **明示的** | 必須 | コンパイラ警告 |
| 6 | Promise/Future | **暗黙的** | Small Print | なし |
| 7 | マジック値（-1など） | **暗黙的** | Small Print | なし |
| 8 | 何もしない（Do nothing） | **暗黙的** | なし | なし |

---

## 各方式の詳細

### 1. Checked例外（明示的）

コンパイラが呼び出し側に例外の処理を強制する。Javaでは`Exception`を継承したクラス。

```java
// シグナリング側
class NegativeNumberException extends Exception {
    private final double erroneousNumber;
    NegativeNumberException(double value) { this.erroneousNumber = value; }
    double getErroneousNumber() { return erroneousNumber; }
}

// throws宣言が必須（ないとコンパイルエラー）
double getSquareRoot(double value) throws NegativeNumberException {
    if (value < 0.0) throw new NegativeNumberException(value);
    return Math.sqrt(value);
}

// 呼び出し側：catchするか、自分もthrows宣言するかを選ぶ（どちらかが必須）
void displaySquareRoot() {
    try {
        ui.setOutput("√ = " + getSquareRoot(ui.getInputNumber()));
    } catch (NegativeNumberException e) {
        ui.setError("負の数の平方根は計算できません: " + e.getErroneousNumber());
    }
}
```

**Pros**: 呼び出し側が確実に気づく / **Cons**: 多すぎると冗長になる。主にJavaで利用可能。

### 2. Unchecked例外（暗黙的）

呼び出し側が知らなくても、コンパイルは通る。Javaでは`RuntimeException`を継承。ほとんどの言語でデフォルト。

```java
// シグナリング側（関数シグネチャにthrows不要）
/**
 * @throws NegativeNumberException 負の値が渡された場合（Small Print！）
 */
double getSquareRoot(double value) {
    if (value < 0.0) throw new NegativeNumberException(value);
    return Math.sqrt(value);
}

// 呼び出し側：catchしなくてもコンパイルOK（知らないままになりやすい）
void displaySquareRoot() {
    ui.setOutput("√ = " + getSquareRoot(ui.getInputNumber()));
    // NegativeNumberExceptionが投げられても誰も知らない
}
```

**Pros**: 冗長でない / **Cons**: 呼び出し側が気づかない可能性がある。

### 3. Nullable戻り値（明示的）

null安全をサポートする言語では、`?`付きの型がnullになりうることをコンパイラが強制する。

```kotlin
// Kotlin: null安全が強制される
fun getSquareRoot(value: Double): Double? {
    if (value < 0.0) return null
    return Math.sqrt(value)
}

// 呼び出し側: nullチェックなしでは使えない
fun displaySquareRoot() {
    val result: Double? = getSquareRoot(ui.getInputNumber())
    if (result == null) {
        ui.setError("負の数の平方根は計算できません")
    } else {
        ui.setOutput("√ = $result")
    }
}
```

**Pros**: シンプル / **Cons**: なぜnullなのか理由を伝えられない。

### 4. Result型（明示的）

成功値またはエラー情報を持てる型。Rust、Swift、F#はビルトイン。他の言語は自作するかライブラリを使う。

```java
// Result型の実装例
class Result<V, E> {
    private final Optional<V> value;
    private final Optional<E> error;

    static <V, E> Result<V, E> ofValue(V value) { ... }
    static <V, E> Result<V, E> ofError(E error) { ... }

    boolean hasError() { return error.isPresent(); }
    V getValue() { return value.get(); }
    E getError() { return error.get(); }
}

// 使用例
Result<Double, NegativeNumberError> getSquareRoot(double value) {
    if (value < 0.0) return Result.ofError(new NegativeNumberError(value));
    return Result.ofValue(Math.sqrt(value));
}

// 呼び出し側
void displaySquareRoot() {
    var result = getSquareRoot(ui.getInputNumber());
    if (result.hasError()) {
        ui.setError("エラー: " + result.getError().getErroneousNumber());
    } else {
        ui.setOutput("√ = " + result.getValue());
    }
}
```

**Pros**: エラー詳細情報を伝えられる / **Cons**: ボイラープレートが増える。

### 5. Outcome型（明示的）

値を返さない関数が、成功・失敗を戻り値で伝える。`@CheckReturnValue`で無視を防ぐ。

```java
@CheckReturnValue  // 戻り値を無視するとコンパイラ警告
boolean sendMessage(Channel channel, String message) {
    if (!channel.isOpen()) return false;
    channel.send(message);
    return true;
}

// 呼び出し側
void sayHello(Channel channel) {
    if (sendMessage(channel, "hello")) {
        ui.setOutput("送信成功");
    } else {
        ui.setError("送信失敗");
    }
}
```

**Pros**: シンプルな成功/失敗の伝達 / **Cons**: 複数の失敗理由を表現しにくい。

### 6. Promise/Future（暗黙的）

非同期関数が返す結果。エラーハンドラを設定しなくてもコンパイルが通る。

```javascript
// 非同期関数
async function getSquareRoot(value) {
    await Timer.wait(Duration.ofSeconds(1));
    if (value < 0) throw new NegativeNumberError(value);
    return Math.sqrt(value);
}

// 呼び出し側：.catch()を書かなくてもOK（エラーが無視される）
getSquareRoot(ui.getInputNumber())
    .then(result => ui.setOutput("√ = " + result))
    .catch(error => ui.setError("エラー: " + error)); // これを書かないと消える

// 明示的にするためのパターン: Promise<Result>
async function getSquareRoot(value) {
    if (value < 0) return Result.ofError(new NegativeNumberError(value));
    return Result.ofValue(Math.sqrt(value));
}
```

### 7. マジック値（暗黙的）

通常の戻り値型に特殊な意味を持たせる。ドキュメントを読まないと気づかない。

```java
// Bad: -1がエラーを意味する（Small Printに書いてある）
// Returns -1 if a negative value is supplied
double getSquareRoot(double value) {
    if (value < 0.0) return -1.0;  // マジック値
    return Math.sqrt(value);
}

// 呼び出し側がマジック値を知らないとバグになる
double result = getSquareRoot(someValue);
ui.setOutput("√ = " + result);  // resultが-1でも表示してしまう
```

**Cons**: 呼び出し側が罠にはまる / Chapter 6で詳しく扱う。

### 8. 何もしない（暗黙的）

エラーが起きても何も伝えない。最も危険。

```java
// Bad: エラーが完全に消える
void addItem(InvoiceItem item) {
    if (item.getPrice().getCurrency() != this.getCurrency()) {
        return;  // 黙って何もしない → 呼び出し側はアイテムが追加されたと思っている
    }
    this.items.add(item);
}
```

---

## 回復不能エラーのシグナリング

```java
// 回復不能エラー = プログラミングエラー
// → Unchecked例外 + Fail Fast + ログ

void processOrder(Order order) {
    // 必須フィールドのnullチェック（プログラミングエラー）
    if (order == null) {
        throw new IllegalArgumentException("orderはnullであってはなりません");
    }
    // ...
}
```

---

## 回復可能エラーの推奨：明示的手法 vs 暗黙的手法

### 推奨：明示的手法を優先する

回復可能なエラーでは、呼び出し側が必ず気づけるよう明示的な手法を使う。

| 状況 | 推奨手法 |
|------|---------|
| 失敗理由を伝えたい | Result型 |
| 成功/失敗だけでよい | Nullable型（null安全あり） |
| 複数の失敗理由 | カスタム型 / Enum + Result |
| 非同期 | Promise<Result<V, E>> |

### 暗黙的手法を使う場面

- エラー処理を強制するとコードが煩雑になりすぎる場合
- プログラミングエラー（バグ）の通知用（Unchecked例外）
- 互換性の都合でUnchecked例外しか使えない場合

---

## コンパイラ警告の活用

コンパイラ警告はエラーではないため無視されがちだが、多くの実際のバグを防ぐ。

```java
// @CheckReturnValue: 戻り値を無視するとコンパイラ警告
// Java: javax.annotation.CheckReturnValue
// C#: [MustUseReturnValue]（JetBrains）
// C++: [[nodiscard]]

@CheckReturnValue
boolean sendMessage(Channel channel, String message) { ... }

// 以下はコンパイラ警告が出る（エンジニアが気づける）
sendMessage(channel, "hello");  // 戻り値を無視
```

**チームルール**: コンパイラ警告をビルドエラーとして扱う設定（`-Werror`等）を推奨。警告を全て0に保つことで、新しい警告に気づきやすくなる。

---

## エラーを隠す4つのアンチパターン

| アンチパターン | 問題 | 代替 |
|--------------|------|------|
| **デフォルト値を返す** | エラーと正常値が区別できない | null/Optional/Result型を返す |
| **Nullオブジェクトパターン（誤用）** | エラーが消えてバグが潜伏する | 適切な場面でのみ使用（後述） |
| **何もしない** | 呼び出し側が成功したと誤解する | 必ず何らかのシグナルを送る |
| **例外を握りつぶす** | バグが永遠に発見されない | ログ + 再スローが最低限必要 |

```java
// Bad: デフォルト値0を返す（エラーが消える）
double getAccountBalance(int customerId) {
    Result result = store.lookup(customerId);
    if (!result.success()) return 0.0;  // エラーが消える！
    return result.getAccount().getBalance();
}

// Good: エラーを明示的に伝える
Optional<Double> getAccountBalance(int customerId) {
    Result result = store.lookup(customerId);
    if (!result.success()) return Optional.empty();  // 取得できなかったことが分かる
    return Optional.of(result.getAccount().getBalance());
}
```
