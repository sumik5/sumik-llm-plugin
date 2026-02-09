# コードの可読性

## 概要

宣言的なコードは、タスクの実行手順(how)ではなく、望まれる結果(what)に焦点を当てます。本章では、変数の再利用抑制、適切な命名、コメントの削減、コーディング規約の統一を通じて、読みやすく理解しやすいコードを構築する方法を示します。

## コードスメル検出チェックリスト

- [ ] 同じ変数を異なる目的で使用している
- [ ] 空行で大きなコードブロックを区切っている
- [ ] メソッド名にバージョン情報が含まれている
- [ ] 二重否定(!isNotFinished)を使用している
- [ ] 責務が不適切なオブジェクトに配置されている
- [ ] 添字を使った単純なループ処理が多い
- [ ] マジックナンバーが存在する
- [ ] 複雑な正規表現が多い
- [ ] コメントアウトされたコードがある
- [ ] 古くなったコメントが残っている
- [ ] インデントにタブとスペースが混在している

---

## 宣言的なコード（Ch.6）

### 概要

宣言的なコードは、プログラムが何を達成すべきかを記述します。命令的コードとは異なり、最終的な結果に焦点を当て、読みやすく理解しやすいものになります。

### レシピ6.1: 変数の再利用の抑制

**問題**: 同じ変数を異なる目的で複数回使用している

**解決策**: 変数のスコープをできるだけ狭く定義し、再利用を避ける

**コード例**:
```java
// Before
double total = item.getPrice() * item.getQuantity();
System.out.println("明細合計: " + total);
total = order.getTotal() - order.getDiscount();
System.out.println("金額合計: " + total);

// After
function printLineTotal() {
    double lineTotal = item.getPrice() * item.getQuantity();
    System.out.println("明細合計: " + lineTotal);
}

function printAmountTotal() {
    double amountTotal = order.getTotal() - order.getDiscount();
    System.out.println("金額合計: " + amountTotal);
}
```

**関連レシピ**: 10.1, 10.7, 11.1, 11.3

---

### レシピ6.2: 不要な空行の整理

**問題**: 多くの空行で大きなコードブロックを区切っている

**解決策**: 空行で区別されている部分を独立したメソッドに分割

**コード例**:
```php
// Before
function translateFile() {
    $this->buildFilename();
    $this->readFile();
    // 空行
    $this->translateHyperlinks();
    $this->translateMetadata();
    // 空行
    $this->generateStats();
}

// After
function translateFile() {
    $this->readFileToMemory();
    $this->translateContents();
    $this->generateStatsAndSaveFileContents();
}
```

**関連レシピ**: 8.6, 10.7, 11.1

---

### レシピ6.3: メソッド名からのバージョン情報の削除

**問題**: sort、sortOld、sort20210117等、メソッド名にバージョン情報を含めている

**解決策**: バージョン情報を削除し、バージョン管理システムを使用

**コード例**:
```
// Before
findMatch()
findMatch_new()
findMatch_version2()

// After
findMatch()
```

**関連レシピ**: 8.5

---

### レシピ6.4: 二重否定の肯定的な表現への書き換え

**問題**: 否定的な条件を表す変数/メソッドがあり、その条件が発生していないことを確認する必要がある

**解決策**: 常に肯定的な名前を使用

**コード例**:
```java
// Before
if (!work.isNotFinished())

// After
if (work.isDone())
```

**関連レシピ**: 10.4, 14.3, 14.11, 24.2

---

### レシピ6.5: 責務の適切な再配置

**問題**: メソッドが不適切なオブジェクトに配置されている

**解決策**: MAPPERの原則に従い、責務を適切に担うオブジェクトを特定

**コード例**:
```javascript
// Before
class GraphicEditor {
    constructor() {
        this.PI = 3.14; // 不適切
    }
}

// After
class RealConstants {
    static pi() {
        return 3.14;
    }
}
```

**関連レシピ**: 7.2, 17.8

---

### レシピ6.6: 添字を使ったループ処理の高レベルな反復への置き換え

**問題**: 配列の添字を使った単純なループ構文を使用している

**解決策**: 高レベルのコレクション操作を優先

**コード例**:
```javascript
// Before
for (let i = 0; i < colors.length; i++) {
    console.log(colors[i]);
}

// After
colors.forEach((color) => {
    console.log(color);
});
```

**関連レシピ**: 7.1

---

### レシピ6.7: 設計上の判断の明確な表現

**問題**: 重要な判断をコードで明確に表現する必要がある

**解決策**: 意図が明確に伝わる説明的な名前を使用し、コード自体で設計の意図を表現

**コード例**:
```c
// Before
set_memory("512k");
run_process();

// After
increase_memory_to_avoid_false_positives();
run_process();
```

**関連レシピ**: 8.5, 8.6

---

### レシピ6.8: マジックナンバーの定数での置き換え

**問題**: 意味や由来が不明確な数値を直接使用している

**解決策**: マジックナンバーを定数で置き換え、意味を明確に示す名前を付ける

**コード例**:
```php
// Before
function energy($mass) {
    return $mass * (299792 ** 2);
}

// After
function energy($mass) {
    return $mass * (LIGHT_SPEED_KILOMETERS_OVER_SECONDS ** 2);
}
```

**関連レシピ**: 5.2, 5.6, 10.4, 11.4, 17.1, 17.3

---

### レシピ6.9: 「何を」と「どのように」の分離

**問題**: コードが達成すべき目的ではなく、内部の実装の詳細に焦点を当てている

**解決策**: 宣言型プログラミングを心がけ、目的や期待される結果を明確に示す

**コード例**:
```javascript
// Before
class Workflow {
    moveToNextTransition() {
        if (this.stepWork.hasPendingTasks()) {
            throw new Error('前提条件を満たしていません。');
        }
    }
}

// After
class Workflow {
    moveToNextTransition() {
        if (this.canMoveOn()) {
            this.moveToNextStep();
        }
    }

    canMoveOn() {
        return !this.stepWork.hasPendingTasks();
    }
}
```

**関連レシピ**: 8.5, 19.6

---

### レシピ6.10: 正規表現の可読性の向上

**問題**: 複雑で理解しづらい正規表現を使用している

**解決策**: 正規表現を短く理解しやすいように分解

**コード例**:
```kotlin
// Before
val regex = Regex("^\\+(?:[0-9][ -]?){6,14}[0-9]$")

// After
val prefix = "\\+"
val digit = "[0-9]"
val space = "[ -]"
val phoneRegex = Regex("^$prefix(?:$digit$space?){6,14}$digit$")
```

**関連レシピ**: 4.7, 10.4, 16.2, 25.4

---

### レシピ6.11: ヨーダ条件式の書き換え

**問題**: 等価比較式で定数を左側、変数を右側に配置している

**解決策**: 変数を左側に、定数値を右側に配置

**コード例**:
```java
// Before (ヨーダ条件式)
if (42 == answerToLifeMeaning) {
}

// After
if (answerToLifeMeaning == 42) {
}
```

**関連レシピ**: 7.15

---

### レシピ6.12: 不適切な表現を含むメソッドの除去

**問題**: 不適切なユーモアや攻撃的な表現を使���している

**解決策**: プロフェッショナルな方法でコードを書く

**コード例**:
```javascript
// Before
function eradicateAndMurderAllCustomers();

// After
function deleteAllCustomers();
```

**関連レシピ**: 7.7

---

### レシピ6.13: コールバック地獄の回避

**問題**: コールバックが過度にネストされている

**解決策**: Promiseやasync/awaitを使用

**コード例**:
```javascript
// Before
asyncFunc1(function (error, result1) {
    if (error) {
        console.log(error);
    } else {
        asyncFunc2(function (error, result2) {
            // 深いネスト
        });
    }
});

// After
async function performAsyncOperations() {
    try {
        const result1 = await asyncFunc1();
        const result2 = await asyncFunc2();
    } catch (error) {
        console.log(error);
    }
}
```

**関連レシピ**: 10.4, 14.10

---

### レシピ6.14: 良いエラーメッセージの作成

**問題**: 適切なエラーメッセージを作成する必要がある

**解決策**: 意味のある説明を使用し、対処方法を提案

**コード例**:
```javascript
// Before
alert("予約をキャンセルしますか？", "はい", "いいえ");

// After
alert("予約をキャンセルしますか？\n" +
      "すべての履歴を失います",
      "予約をキャンセルする",
      "編集を続ける");
```

**関連レシピ**: 15.1, 17.13, 22.3, 22.5

---

### レシピ6.15: 自動的な値の変換の回避

**問題**: 自動的な値の変換や暗黙的な処理が行われている

**解決策**: 明示的な処理に置き換え

**コード例**:
```javascript
// Before
new Date(31, 02, 2020); // 有効
1 + 'Hello'; // 有効

// After
new Date(31, 02, 2020); // 例外
1 + 'Hello'; // 型不一致エラー
```

**関連レシピ**: 10.4, 24.2

---

## 命名（Ch.7）

### 概要

命名はコードの可読性、理解のしやすさ、保守性に直接影響します。良い名前は混乱やエラーの発生を防ぎます。

### レシピ7.1: 略語の回避

**問題**: 曖昧な略語を名前に使用している

**解決策**: 明確で、十分に長く、曖昧さがない説明的な名前を使用

**コード例**:
```go
// Before
package main
import "fmt"
type YVC struct {
    id int
}

// After
package main
import "formatter"
type YouTubeVideoContent struct {
    imdbMovieIdentifier int
}
```

**関連レシピ**: 7.6, 10.4

---

### レシピ7.2: ヘルパーとユーティリティクラスの改名と責務の分割

**問題**: Helperという名前のクラスがあり、責務が不明確

**解決策**: より具体的な名前に変更し、責務を分割

**コード例**:
```javascript
// Before
export default class UserHelpers {
    static getFullName(user) {
        return `${user.firstName} ${user.lastName}`;
    }
}

// After
class FullNameFormatter {
    fullname(userscore) {
        return `${userscore.name()} ${userscore.lastname()}`;
    }
}
```

**関連レシピ**: 6.5, 7.7, 11.5, 18.2, 23.2

---

### レシピ7.3: myで始まるオブジェクト名の変更

**問題**: 変数名がmyで始まっている

**解決策**: オブジェクトの役割がわかる名前に変更

**コード例**:
```csharp
// Before
MainWindow myWindow = Application.Current.MainWindow as MainWindow;

// After
MainWindow salesWindow = Application.Current.MainWindow as MainWindow;
```

---

### レシピ7.4: resultという名の変数の回避

**問題**: 結果をresultという曖昧な名前で表している

**解決策**: 役割を明確に示す適切な名前を使用

**コード例**:
```javascript
// Before
var result;
result = lastBlockchainBlock();

// After
var lastBlockchainBlock;
lastBlockchainBlock = findLastBlockchainBlock();
```

**関連レシピ**: 7.7

---

### レシピ7.5: 型に基づいた変数名の変更

**問題**: 変数名に型情報が含まれている

**解決策**: 型情報は偶発的なもので、名前から削除

**コード例**:
```csharp
// Before
Regex regex = new Regex(@"[a-z]{2,7}[0-9]{3,4}");

// After
Regex stringHas3To7LowercaseCharsFollowedBy3or4Numbers =
    new Regex(@"[a-z]{2,7}[0-9]{3,4}");
```

**関連レシピ**: 7.6, 7.7, 7.9

---

### レシピ7.6: 長い名前の変更

**問題**: 非常に長く冗長な名前を使っている

**解決策**: 長くて説明的だが、長すぎない名前に

**コード例**:
```
// Before
PlanetarySystem.PlanetarySystemCentralStarCatalogEntry

// After
PlanetarySystem.CentralStarCatalogEntry
```

**関連レシピ**: 7.1

---

### レシピ7.7: 抽象的な名前の変更

**問題**: 名前が抽象的すぎる

**解決策**: 現実世界との対応付けに基づいて具体的な名前に

**コード例**:
```java
// Before
final class MeetingsCollection {}
abstract class AbstractTransportation {}

// After
final class Schedule {}
final class Vehicle {}
```

**関連レシピ**: 7.2, 7.14, 12.5

---

### レシピ7.8: スペルミスの修正

**問題**: 名前にスペルミスがある

**解決策**: 自動スペルチェッカーを使用

**コード例**:
```
// Before
comboFeededBySupplyer = supplyer.providers();

// After
comboFedBySupplier = supplier.providers();
```

**関連レシピ**: 9.1

---

### レシピ7.9: 属性名からのクラス名の削除

**問題**: 属性名にクラス名が含まれている

**解決策**: 冗長性を除去

**コード例**:
```java
// Before
public class Employee {
    String empName = "John";
    int empId = 5;
}

// After
public class Employee {
    String name;
    int id;
}
```

**関連レシピ**: 7.3, 7.5, 7.10

---

### レシピ7.10: クラス・インターフェース名からの識別用文字の削除

**問題**: クラス/インターフェース名の先頭に識別用の文字(A、I等)を使用している

**解決策**: 現実世界の概念を適切に表す名前を使用

**コード例**:
```csharp
// Before
public interface IEngine { }
public class ACar {}

// After
public interface Engine { }
public class Car {}
```

**関連レシピ**: 7.9, 7.14

---

### レシピ7.11: 「Basic」や「Do」という関数名の変更

**問題**: doSort、basicSort等、混乱を招くバリエーションが存在

**解決策**: ラッパーを取り除き、デコレータパターン等を使用

**コード例**:
```php
// Before
function computeSomething() {
    if (isset($this->cachedResults)) {
        return $this->cachedResults;
    }
    $this->cachedResults = $this->logAndComputeSomething();
}

private function logAndComputeSomething() {
    $this->logProcessStart();
    $result = $this->basicComputeSomething();
    return $result;
}

// After (デコレータパターン)
final class Calculator {
    function computeSomething() {
        // 処理
    }
}

final class CalculatorDecoratorCache {
    function computeSomething() {
        if (isset($this->cachedResults)) {
            return $this->cachedResults;
        }
        return $this->decorated->computeSomething();
    }
}
```

---

### レシピ7.12: 複数形のクラス名の単数形への変更

**問題**: クラス名が複数形で表現されている

**解決策**: 単数形で表現

**コード例**:
```ruby
# Before
class Users

# After
class User
```

---

### レシピ7.13: 名前からのCollectionの削除

**問題**: 名前にcollectionという単語が含まれている

**解決策**: より具体的な概念に

**コード例**:
```javascript
// Before
for (var customer in customerCollection) { }

// After
for (var customer in customers) { }
```

**関連レシピ**: 12.6

---

### レシピ7.14: クラス名からのImplの削除

**問題**: クラス名にImplが含まれている

**解決策**: 現実世界の概念に基づいた名前を付ける

**コード例**:
```java
// Before
public class AddressImpl implements Address { }

// After
public class Address { }
// または
public class Address implements ContactLocation { }
```

**関連レシピ**: 7.5, 7.7

---

### レシピ7.15: 引数名の役割に応じた改善

**問題**: メソッドの引数に説明的な名前が付いていない

**解決策**: 役割や目的に基づいて命名

**コード例**:
```python
# Before
class Calculator:
    def subtract(self, first, second):
        return first - second

# After
class Calculator:
    def subtract(self, minuend, subtrahend):
        return minuend - subtrahend
```

**関連レシピ**: 7.5

---

### レシピ7.16: 冗長な引数名の改善

**問題**: メソッドの引数名が冗長

**解決策**: 重複した名前を使わない

**コード例**:
```crystal
# Before
class Employee
    def initialize(
        @employee_first_name : String,
        @employee_last_name : String)
    end
end

# After
class Employee
    def initialize(
        @first_name : String,
        @last_name : String)
    end
end
```

**関連レシピ**: 7.9, 9.5

---

### レシピ7.17: 名前からの不必要な文脈の除去

**問題**: クラスに接頭辞/接尾辞としてグローバルな識別子を付けている

**解決策**: 不要な情報を削除

**コード例**:
```rust
// Before
struct WEBBExoplanet {
    name: String,
}

// After
struct Exoplanet {
    name: String,
}
```

**関連レシピ**: 7.9, 7.10, 7.14

---

### レシピ7.18: 名前からのdataの削除

**問題**: オブジェクトに現実世界の概念を反映しない名前を使用している

**解決策**: dataを使わない

**コード例**:
```javascript
// Before
if (!dataExists()) {
    return '<div>Loading Data...</div>';
}

// After
if (!peopleFound()) {
    return '<div>Loading People...</div>';
}
```

**関連レシピ**: 3.1, 7.5

---

## コメント（Ch.8）

### 概要

コメントは適切な命名に失敗した結果として使われることが多いです。コメントはコンパイルされないため、デッドコードとなります。クリーンコードはほとんどコメントを必要としません。

### レシピ8.1: コメントアウトされたコードの除去

**問題**: コメントアウトされたコードがある

**解決策**: バージョン管理システムを使用し、安全に削除

**コード例**:
```javascript
// Before
function arabicToRoman(num) {
    // print(i)
    // if (result > 0) return ' ' + result
    return result;
}

// After
function arabicToRoman(num) {
    return romanString;
}
```

**関連レシピ**: 8.2, 8.3, 8.5, 8.6

---

### レシピ8.2: 古くなったコメントの整理

**問題**: 正確でなくなったコメントが存在する

**解決策**: 陳腐化したコメントを削除

**コード例**:
```cpp
// Before
void Widget::displayPlugin(Unit* unit) {
    // TODO Pluginは間もなく修正される予定
    if (!isVisible) {
        return;
    }
}

// After
void Widget::displayPlugin(Unit* unit) {
    if (!isVisible) {
        return;
    }
}
```

**関連レシピ**: 8.1, 8.3, 8.5, 8.7

---

### レシピ8.3: 条件式内の不適切なコメントの除去

**問題**: if文などの条件式の中にtrueやfalseをコメントとして含めている

**解決策**: コメントを削除し、ソース管理システムを使用

**コード例**:
```javascript
// Before
if (false && cart.items() > 11 && user.isRetail()) {
    doStuff();
}

// After
if (cart.items() > 11 && user.isRetail()) {
    doStuff();
}
// テストで両方のケースをカバー
```

**関連レシピ**: 8.1

---

### レシピ8.4: ゲッターのコメントの削除

**問題**: ゲッターに自明なコメントが記述されている

**解決策**: ゲッターの使用を見直し、自明なコメントを避ける

**コード例**:
```solidity
// Before
function price() public view returns(int) {
    /* 価格を返します */
    return _price;
}

// After
function price() public view returns(int) {
    return _price;
}
```

**関連レシピ**: 3.1, 3.8, 8.5

---

### レシピ8.5: コメントの関数名への変換

**問題**: コメントが多く含まれ、実装に密接に関連している

**解決策**: コメントの内容を反映した適切な名前の関数を作成

**コード例**:
```php
// Before
final class ChatBotConnectionHelper {
    // ChatBotConnectionHelperはBot Platformへの接続文字列を作成します
    function getString() {
        // チャットボットから接続文字列を取得
    }
}

// After
final class ChatBotConnectionSequenceGenerator {
    function connectionSequence() {
    }
}
```

**関連レシピ**: 8.6

---

### レシピ8.6: メソッド内のコメントの削除

**問題**: メソッド内にコメントがある

**解決策**: コメントで説明しようとしている内容を別のメソッドとして抽出

**コード例**:
```javascript
// Before
function recoverFromGrief() {
    // 否認の段階
    absorbTheBadNews();
    // 怒りの段階
    maskRealEffects();
}

// After
function recoverFromGrief() {
    denialStage();
    angerStage();
}

function denialStage() {
    absorbTheBadNews();
}
```

**関連レシピ**: 6.2, 6.7, 8.5, 10.7, 11.1

---

### レシピ8.7: コメントのテストでの置き換え

**問題**: 関数の動作を説明するコメントがある

**解決策**: コメントの内容を反映した関数名に変更し、テストで検証

**コード例**:
```python
# Before
def multiply(a, b):
    # この関数は2つの数字を掛け合わせて、結果を返します
    return a * b

# After
def multiply(first_multiplier, second_multiplier):
    return first_multiplier * second_multiplier

class TestMultiply(unittest.TestCase):
    def test_multiply_both_positive_outcome_is_positive(self):
        result = multiply(2, 3)
        self.assertEqual(result, 6)
```

**関連レシピ**: 8.2, 8.4, 10.7, 20.1

---

## コーディング規約（Ch.9）

### 概要

コーディング規約を設けることで、コードに一貫性を持たせ、可読性を向上させます。組織全体で共通のルールやベストプラクティスを用いることが重要です。

### レシピ9.1: コーディング規約への準拠

**問題**: さまざまな規約が混在している

**解決策**: 組織全体で同じ規約に従い、自動的に適用

**コード例**:
```java
// Before (混在)
public class MY_Account {
    private Statement privStatement;
    public SetAccount(Statement statement) {
    }
}

// After (統一)
public class Account {
    private Statement statement;

    public Account(Statement statement) {
        this.statement = statement;
    }
}
```

**関連レシピ**: 7.8, 10.4

---

### レシピ9.2: インデントの標準化

**問題**: タブとスペースが混在している

**解決策**: 一貫したスタイルを使用

**コード例**:
```javascript
// Before (混在)
function add(x, y) {
→ return x + y; // タブとスペース混在
}

// After (統一)
function add(x, y) {
  return x + y; // スペースのみ
}
```

**関連レシピ**: 9.1

---

### レシピ9.3: 大文字・小文字に関する規約の統一

**問題**: 異なる大文字・小文字の規約が使われている

**解決策**: 1つを選択し、適用

**コード例**:
```json
// Before (混在)
{
    "userId": 666,
    "UPDATED_AT": "2022-01-07",
    "created_at": "2019-01-07"
}

// After (統一)
{
    "userId": 666,
    "updatedAt": "2022-01-07",
    "createdAt": "2019-01-07"
}
```

**関連レシピ**: 9.1

---

### レシピ9.4: 英語でのコードの記述

**問題**: ローカル言語を使用したコードがある

**解決策**: 英語を使用

**コード例**:
```javascript
// Before (スペイン語混在)
var moreElements = new MultiConjunto();
moreElements.agregar('hello');

// After (英語)
var moreElements = new MultiSet();
moreElements.add('hello');
```

---

### レシピ9.5: 引数の順序の統一

**問題**: 引数の順序に一貫性がない

**解決策**: 引数の順序を一貫させる

**コード例**:
```javascript
// Before
function giveFirstDoseOfVaccine(person, vaccine) { }
function giveSecondDoseOfVaccine(vaccine, person) { }

// After
function giveFirstDoseOfVaccine(person, vaccine) { }
function giveSecondDoseOfVaccine(person, vaccine) { }
```

**関連レシピ**: 7.16, 11.2

---

### レシピ9.6: 割れた窓の修理

**問題**: 別の問題のある部分を見つけた

**解決策**: ボーイスカウトのルールに従い、見つけたコードをきれいにしてから去る

**コード例**:
```c
// Before
int mult(int a,int other) {
    int prod
    prod= 0;
    for(int i=0;i<other ;i++)
        prod+= a ;
    return prod;
}

// After
int multiply(int firstMultiplier, int secondMultiplier) {
    int product = 0;
    for(int index=0; index<secondMultiplier; index++) {
        product += firstMultiplier;
    }
    return product;
}
```

**関連レシピ**: 9.2, 9.3, 21.4

---

## 相互参照

- 6.1 → 10.1, 10.7, 11.1, 11.3
- 6.2 → 8.6, 10.7, 11.1
- 6.5 → 7.2, 17.8
- 7.2 → 6.5, 7.7, 11.5, 18.2, 23.2
- 8.1 → 8.2, 8.3, 8.5, 8.6
- 8.5 → 8.6
- 8.6 → 6.2, 6.7, 8.5, 10.7, 11.1
- 9.1 → 7.8, 10.4
