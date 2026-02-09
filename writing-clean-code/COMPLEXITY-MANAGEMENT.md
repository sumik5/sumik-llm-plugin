# 複雑さ管理

## 概要

複雑さの管理はソフトウェアエンジニアリングの中核的課題である。オブジェクト指向プログラミングは、カプセル化を通じて複雑性を管理し、再利用性・テスト容易性・保守性・拡張可能性を向上させる。若手と経験豊富なエンジニアの主な違いは、偶発的な複雑さをいかに最小限に抑えるかという点にある。

このセクションでは、重複コード・設定フラグ・過度な技巧・肥大化したメソッド/クラス・YAGNI違反・フェイルファストに関するレシピを扱う。

## コードスメル検出チェックリスト

- [ ] **重複した振る舞い**が複数箇所に存在する（DRY原則違反）
- [ ] グローバルな**設定/機能フラグ**に依存している
- [ ] 読みにくく**技巧的なコード**が多用されている
- [ ] メソッドが**8-10行を大幅に超える**長さになっている
- [ ] 関数の**引数が3つ以上**ある
- [ ] 同時にアクティブな**変数が多すぎる**
- [ ] クラスの**メソッド数が過剰**である
- [ ] クラスの**属性数が過剰**である
- [ ] **import文のリスト**が長すぎる
- [ ] 関数名に**「and」が含まれている**（複数責務の兆候）
- [ ] インターフェースが**多数のメソッド**を定義している
- [ ] **デッドコード**が残っている
- [ ] **図に頼りすぎて**コードとテストが軽視されている
- [ ] サブクラスが**1つしかない**抽象クラスがある
- [ ] 実装が**1つしかない**インターフェースがある
- [ ] **事前条件の検証**が不十分である
- [ ] 引数の**型が柔軟すぎる**（様々な型を受け入れる）
- [ ] switch文のdefault節で**通常処理を行っている**
- [ ] 繰り返し処理中に**コレクションを変更**している

---

## 10章 複雑さ（Ch.10, 行5674-6274）

### 問題パターン

偶発的な複雑さの蓄積により、コードの保守性・テスト容易性が低下する。

### 主要レシピ

#### 10.1 重複コードの除去

**問題**: コード内に重複した振る舞いが存在する。重複したコードと重複した振る舞いは異なる概念である。

**解決策**: 適切な抽象化を見出し、重複している振る舞いを集約する。

**コード例**:
```javascript
// Before（重複あり）
class WordProcessor {
  replaceText(pattern, replacement) {
    this.text = '<<<' + str_replace(pattern, replacement, this.text) + '>>>';
  }
}
class Obfuscator {
  obfuscate(pattern, replacement) {
    this.text = strtolower(str_ireplace(pattern, replacement, this.text));
  }
}

// After（抽象化）
class TextReplacer {
  replace(pattern, replacement, subject, replaceFn, postProcess) {
    return postProcess(replaceFn(pattern, replacement, subject));
  }
}
class WordProcessor {
  replaceText(pattern, replacement) {
    this.text = new TextReplacer().replace(
      pattern, replacement, this.text, 'str_replace',
      text => '<<<' + text + '>>>'
    );
  }
}
```

**関連**: レシピ19.3（サブクラス化の回避）

#### 10.2 設定/機能フラグの削除

**問題**: コードがグローバルな設定・機能フラグに依存している。

**解決策**: 機能フラグを追跡して成熟後に削除。設定は小さなオブジェクトに具象化する。

**コード例**:
```javascript
// Before（グローバル結合）
class VerySpecificObject {
  retrieveData() {
    if (GlobalSettings.getInstance().valueAt('RetrievDataDirectly')) {
      this.retrieveDataThisWay();
    } else {
      this.retrieveDataThisOtherWay();
    }
  }
}

// After（ストラテジーパターン）
class VerySpecificObject {
  constructor(retrievalStrategy) {
    this.retrievalStrategy = retrievalStrategy;
  }
  retrieveData() {
    this.retrievalStrategy.retrieveData();
  }
}
```

**関連**: レシピ14.4（switch置換）、レシピ17.3（ゴッドオブジェクト分割）

#### 10.3 オブジェクトの状態変化を属性変更で表現することの廃止

**問題**: オブジェクトの内部属性を直接変更することで状態を管理している。

**解決策**: オブジェクトの状態を実世界の概念に近い形で表現し、状態を外部で管理する。

**コード例**:
```java
// Before（状態を属性で管理）
class Order {
  private OrderState state;
  public void changeState(OrderState newState) {
    this.state = newState;
  }
}

// After（状態をコレクションで管理）
class Order {
  private LinkedList<int> items;
  public Order(LinkedList<int> items) {
    this.items = items;
  }
}
class OrderProcessor {
  Collection<Order> pendingOrders = new LinkedList<>();
  Collection<Order> confirmedOrders = new LinkedList<>();
  // 注文をコレクション間で移動させて状態を表現
}
```

**関連**: レシピ3.3（セッター除去）、レシピ16.2（早すぎる最適化）

#### 10.4 過度な技巧の除去

**問題**: コードが読みにくく、複雑で、言語の特殊機能を過剰に利用している。

**解決策**: 小手先の工夫を避け、謙虚な姿勢で可読性とシンプルさを重視する。

**コード例**:
```javascript
// Before（技巧的）
function primeFactors(n) {
  var f = [], i = 0, d = 2;
  for (i = 0; n >= 2; ) {
    if(n % d == 0) { f[i++] = (d); n /= d; }
    else { d++; }
  }
  return f;
}

// After（クリーン）
function primeFactors(numberToFactor) {
  var factors = [], divisor = 2, remainder = numberToFactor;
  while(remainder >= 2) {
    if(remainder % divisor === 0) {
      factors.push(divisor);
      remainder = remainder / divisor;
    } else {
      divisor++;
    }
  }
  return factors;
}
```

**関連**: レシピ6.8（マジックナンバー）、レシピ16.2（早すぎる最適化）

#### 10.5 複数のPromiseの分解

**問題**: 複数の独立したPromiseを順番に処理してブロックしている。

**解決策**: すべてのPromiseを並行実行し、完了を待つ。

**コード例**:
```javascript
// Before（連続実行）
async fetchAll() {
  let result1 = await this.fetchLongTask();
  let result2 = await this.fetchAnotherLongTask();
}

// After（並列実行）
async fetchAll() {
  let [result1, result2] = await Promise.all([
    this.fetchLongTask(),
    this.fetchAnotherLongTask()
  ]);
}
```

#### 10.6 長く続くメソッド呼び出しの連鎖の分割

**問題**: メソッド呼び出しが長く連鎖している。

**解決策**: 直接関係のあるオブジェクトとのみやりとりし、複雑な連鎖を避ける（デメテルの法則）。

**コード例**:
```javascript
// Before（連鎖）
for (var foot of dog.getFeet()) {
  foot.move();
}

// After（責務の委譲）
class Dog {
  walk() {
    for (var foot of this.feet) {
      foot.move();
    }
  }
}
dog.walk();
```

**関連**: レシピ17.9（中間者の排除）

#### 10.7 メソッドのオブジェクトとしての抽出

**問題**: 複雑で長大なアルゴリズムを含むメソッドがある。

**解決策**: メソッドをオブジェクトに移動し、小さな部分に分割する。

**コード例**:
```java
// Before（長いメソッド）
class BlockchainAccount {
  public double balance() {
    // 非常に長くてテスト不能なメソッド
  }
}

// After（メソッドオブジェクト）
class BlockchainAccount {
  public double balance() {
    return new BalanceCalculator(this).netValue();
  }
}
class BalanceCalculator {
  private BlockchainAccount account;
  public BalanceCalculator(BlockchainAccount account) {
    this.account = account;
  }
  public double netValue() {
    this.findStartingBlock();
    this.computeTransactions();
  }
}
```

**関連**: レシピ11.1（長すぎるメソッド）、レシピ20.1（プライベートメソッドテスト）

#### 10.8 配列コンストラクタの使用回避（JavaScript特有）

**問題**: JavaScriptで`new Array()`を使用している。

**解決策**: 配列リテラル`[]`を使用する。

**コード例**:
```javascript
// Before（予測不能）
const arr1 = new Array(3);      // [ <3 empty items> ]
const arr2 = new Array(3, 1);   // [ 3, 1 ]

// After（明確）
const arr1 = [undefined, undefined, undefined];
const arr2 = [3, 1];
```

**関連**: レシピ13.3（引数の型制限）

#### 10.9 ポルターガイストオブジェクトの除去

**問題**: 突然現れては消える、目的不明瞭なオブジェクトがある。

**解決策**: オブジェクト間の関係を整理し、必要最小限の抽象化レベルを維持する。

**コード例**:
```java
// Before（不要な中間者）
public class Driver {
  private Car car;
  public void driveCar() { car.drive(); }
}
Car porsche = new Car();
Driver homer = new Driver(porsche);
homer.driveCar();

// After（直接呼び出し）
Car porsche = new Car();
porsche.driveCar();
```

**関連**: レシピ16.6（未使用コード削除）、レシピ17.9（中間者排除）

---

## 11章 肥大化要因（Ch.11, 行6275-6878）

### 問題パターン

コードの成長に伴う肥大化は避けられないが、保守性・テスト容易性を損なう。

### 主要レシピ

#### 11.1 長すぎるメソッドの分割

**問題**: コード行数が多すぎるメソッドがある。

**解決策**: 長いメソッドを小さな部分に抽出し、単体テストを実施する。メソッドあたり8-10行を目安とする。

**コード例**:
```php
// Before（長い）
function setUpChessBoard() {
  $this->placeOnBoard($this->whiteTower);
  $this->placeOnBoard($this->whiteKnight);
  // 多くの行...
  $this->placeOnBoard($this->blackTower);
}

// After（分割）
function setUpChessBoard() {
  $this->placeWhitePieces();
  $this->placeBlackPieces();
}
```

**関連**: レシピ7.2（ヘルパー分割）、レシピ14.10（ネストif）

#### 11.2 多すぎる引数の削減

**問題**: 引数が多すぎるメソッドがある。

**解決策**: 関連する引数をパラメータオブジェクトとしてまとめる。引数は3つ以内が望ましい。

**コード例**:
```java
// Before（引数多数）
void print(String doc, String paperSize, String orientation,
           boolean grayscales, int pageFrom, int pageTo, int copies,
           float marginL, float marginR, float marginT, float marginB) { }

// After（オブジェクト化）
void print(Document doc, PrintSetup setup) { }
class PrintSetup {
  public PrintSetup(PaperSize size, PrintOrientation orientation,
                    ColorConfig color, PrintRange range,
                    int copies, PrintMargins margins) {}
}
```

**関連**: レシピ9.5（引数順序統一）、レシピ11.6（多すぎる属性）

#### 11.3 過度な変数の削減

**問題**: 同時に使用されている変数が多すぎる。

**解決策**: スコープを分割し、変数を可能な限り局所的にする。

**関連**: レシピ6.1（変数再利用抑制）、レシピ14.2（真偽値変数名）

#### 11.4 過剰な括弧の除去

**問題**: 括弧が多すぎる式がある。

**解決策**: コードの意味を変えない範囲で括弧の使用を最小限に抑える。

**コード例**:
```python
# Before（過剰）
schwarzschild = ((((2 * G)) * mass) / ((C ** 2)))

# After（適切）
schwarzschild = 2 * G * mass / (C ** 2)
```

**関連**: レシピ6.8（マジックナンバー）

#### 11.5 過度なメソッドの削除

**問題**: クラスにメソッドが多すぎる。

**解決策**: クラスをより凝集度の高い小さな部品に分割する。

**コード例**:
```java
// Before（肥大化）
public class MyHelperClass {
  public void print() { }
  public void format() { }
  public void persist() { }
  public void solveFermiParadox() { }
}

// After（分割）
public class Printer { public void print() { } }
public class DateFormatter { public void format() { } }
public class Database { public void persist() { } }
public class RadioTelescope { public void solveFermiParadox() { } }
```

**関連**: レシピ7.2（ヘルパー分割）、レシピ11.6（多すぎる属性）

#### 11.6 多すぎる属性の分割

**問題**: 属性が多数定義されているクラスがある。

**解決策**: 属性に関連するメソッドを特定し、まとまりを新しいオブジェクトとして切り出す。

**コード例**:
```php
// Before（属性多数）
class ExcelSheet {
  String filename;
  String fileEncoding;
  String documentOwner;
  String documentReadPassword;
  DateTime creationTime;
  List cells;
}

// After（分割）
class ExcelSheet {
  FileProperties fileProperties;
  SecurityProperties securityProperties;
  DocumentDatingProperties datingProperties;
  DocumentContent content;
}
```

**関連**: レシピ11.2（多すぎる引数）、レシピ17.3（ゴッドオブジェクト）

#### 11.7 importのリストの削減

**問題**: クラスがあまりにも多くのほかのクラスに依存している。

**解決策**: 同じファイル内であまり多くをimportせず、依存関係を分割する。

**関連**: レシピ11.5（過度なメソッド）、レシピ17.14（強い依存関係）

#### 11.8 名前に「And」が付いた関数の分割

**問題**: 1つの関数で複数のタスクを実行している。

**解決策**: アトミック性が必要な場合を除き、関数ごとに1つのタスクのみ実行する。

**コード例**:
```python
# Before（複数責務）
def fetch_and_display_personnel():
  data = # ...
  for person in data: print(person)

# After（分割）
def fetch_personnel():
  return # ...
def display_personnel(data):
  for person in data: print(person)
```

**関連**: レシピ11.1（長すぎるメソッド）

#### 11.9 肥大化したインターフェースの分割

**問題**: 1つのインターフェースで定義されているメソッドが多すぎる。

**解決策**: インターフェースを分割する（インターフェース分離の原則）。

**コード例**:
```java
// Before（肥大化）
interface Animal {
  void eat();
  void sleep();
  void makeSound();
}
class Fish implements Animal {
  public void sleep() { throw new UnsupportedOperationException(); }
  public void makeSound() { throw new UnsupportedOperationException(); }
}

// After（分離）
interface Animal {
  void move();
  void reproduce();
}
class Fish implements Animal {
  public void move() { }
  public void reproduce() { }
}
```

**関連**: レシピ12.4（実装1つのインターフェース）

---

## 12章 YAGNI（Ch.12, 行6879-7296）

### 問題パターン

「You Ain't Gonna Need It」原則：将来使われるかもしれないという推測で不要な機能を追加する。

### 主要レシピ

#### 12.1 デッドコードの除去

**問題**: 使用されていない、または必要とされていないコードがある。

**解決策**: 「念のため必要になるかもしれない」という理由でコードを保持しない。削除する。

**関連**: レシピ16.6（未使用コード）、レシピ23.1（メタプログラミング停止）

#### 12.2 図ではなくコードによる表現

**問題**: ソフトウェアの動作を説明するために図を使用している。

**解決策**: コードとテストを生きたドキュメントとして使用する。

**関連**: レシピ3.1（貧血オブジェクト）、レシピ12.5（過剰なパターン）

#### 12.3 サブクラスが1つしかないクラスのリファクタリング

**問題**: サブクラスを1つだけ持つクラスがある。

**解決策**: 事前の過度な一般化を避け、現時点の知識に基づいて設計する。

**コード例**:
```python
# Before（推測による設計）
class Boss(object):
  def __init__(self, name):
    self.name = name
class GoodBoss(Boss):
  pass

# After（シンプル）
class Boss(object):
  def __init__(self, name):
    self.name = name
```

**関連**: レシピ12.4（実装1つのインターフェース）、レシピ19.3（サブクラス化回避）

#### 12.4 実装が1つしかないインターフェースの削除

**問題**: 実装クラスが1つしかないインターフェースがある。

**解決策**: 複数の具体的な実装例が出るまでインターフェースによる一般化は控える。

**関連**: レシピ7.14（Impl削除）、レシピ20.4（モック置換）

#### 12.5 過剰なデザインパターンの見直し

**問題**: 過度な設計でデザインパターンを不適切に使用している。

**解決策**: 不必要なパターン使用を避け、実装名ではなく現実世界の概念に基づいた名称を使用する。

**コード例**:
| 不適切な例 | 適切な例 |
|-----------|---------|
| FileTreeComposite | FileSystem |
| DateTimeConverterAdapterSingleton | DateTimeFormatter |
| NetworkPacketObserver | NetworkSniffer |

**関連**: レシピ7.7（抽象的名前）、レシピ17.2（シングルトン置換）

#### 12.6 独自のコレクションクラスの見直し

**問題**: 特別な機能を持たない独自のコレクションクラスを使用している。

**解決策**: 不要な抽象化を避け、標準のコレクションクラスを使用する。

**関連**: レシピ13.5（コレクション繰り返し処理中の変更回避）

---

## 13章 フェイルファスト（Ch.13, 行7297-7750）

### 問題パターン

問題が発生したらすぐに対応する必要がある。静かに失敗することは改善の機会を逃すこと。

### 主要レシピ

#### 13.1 変数の再利用を避けるリファクタリング

**問題**: 異なるスコープで変数を再利用している。

**解決策**: 変数名は再利用せず、スコープをできるだけ狭く保つ。

**関連**: レシピ11.1（長すぎるメソッド）

#### 13.2 事前条件の強制

**問題**: 事前条件・事後条件・不変条件で堅牢なオブジェクトを作成したい。

**解決策**: 開発環境と本番環境の両方でアサーションを有効にする（明確な証拠がない限り）。

**コード例**:
```python
# Before（検証なし）
class Date:
  def __init__(self, day, month, year):
    self.day = day
    self.month = month

# After（検証あり）
class Date:
  def __init__(self, day, month, year):
    if month > 12:
      raise Exception("月は12を超えるべきではありません")
    self._month = month
```

**関連**: レシピ3.1（貧血オブジェクト）、レシピ25.1（入力値サニタイズ）

#### 13.3 引数の型の厳格な制限

**問題**: ポリモーフィズムを適切に利用せず、様々な型の引数を受け取る柔軟性の高すぎる関数がある。

**解決策**: 明確な契約を作成し、関数が受け取る引数の型を1つのインターフェースに限定する。

**関連**: レシピ10.4（過度な技巧）、レシピ15.1（Nullオブジェクト）

#### 13.4 switch文のdefault節における通常処理の除去

**問題**: switch文内で未知のケースに対して適切に例外を発生させていない。

**解決策**: default節で通常処理ではなく、未知のケースに対して明示的に例外を発生させる。

**コード例**:
```javascript
// Before（不適切）
switch (value) {
  case value1: doSomething(); break;
  default: doSomethingSpecial(); break;
}

// After（適切）
switch (value) {
  case value1: doSomething(); break;
  case value3: doSomethingSpecial(); break;
  default:
    throw new Exception('予期しない値です ' + value);
}
```

**関連**: レシピ14.4（switch置換）

#### 13.5 コレクションの繰り返し処理中の変更の回避

**問題**: コレクションを繰り返し処理しながら、同時にその内容を変更している。

**解決策**: コレクションをコピーして安全に処理する。

**コード例**:
```java
// Before（危険）
for (Object person : people) {
  if (condition(person)) {
    people.remove(person); // 要素の見落とし可能性
  }
}

// After（安全）
List<Object> iterationPeople = ImmutableList.copyOf(people);
for (Object person : iterationPeople) {
  if (condition(person)) {
    people.remove(person);
  }
}
```

**関連**: レシピ6.6（添字ループ置換）、レシピ12.6（独自コレクション）

#### 13.6 オブジェクトのハッシュ値と等価性の適切な実装

**問題**: ハッシュ値を計算するメソッドを実装しているが、等価性を判定するメソッドが適切でない。

**解決策**: ハッシュ値メソッドを実装する場合、必ず等価性メソッドも適切に実装する。

**関連**: レシピ14.15（オブジェクト等価性比較）、レシピ16.7（キャッシュ見直し）

#### 13.7 機能変更を伴わないリファクタリング

**問題**: 機能の実装とコードのリファクタリングを同時に行っている。

**解決策**: 機能追加とリファクタリングは別々に行う。リファクタリングが必要な場合、まずリファクタリングを完了させてから機能実装を再開する。

---

## まとめ

複雑さ管理の4つの柱:

1. **重複の排除**: DRY原則、適切な抽象化
2. **肥大化の防止**: 小さなメソッド・クラス、少ない引数・属性、狭いスコープ
3. **YAGNIの遵守**: デッドコード削除、推測による設計回避、必要十分な抽象化
4. **フェイルファスト**: 事前条件の強制、型の厳格化、即座のエラー検出

これらのレシピを組み合わせることで、保守性・テスト容易性・拡張可能性の高いクリーンなコードを実現できる。
