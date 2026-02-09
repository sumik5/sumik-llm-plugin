# アーキテクチャとコード構造

## 概要

システムのアーキテクチャレベルで発生するコードスメルと、それらを解消するためのリファクタリング手法を扱います。結合度、グローバル変数の使用、継承階層の設計など、システム全体の保守性に影響を与える重要な問題に対処します。

## コードスメル検出チェックリスト

- [ ] シングルトンパターンを使用している
- [ ] グローバル関数やスタティックメソッドが多数存在する
- [ ] クラス間で強い依存関係がある
- [ ] 継承階層が深すぎる（3レベル以上）
- [ ] 具象クラスが他の具象クラスを継承している
- [ ] protected属性を多用している
- [ ] 1つのクラスが多くの責務を持っている
- [ ] 小さな変更が広範囲に影響を及ぼす

---

## 17章：結合

### 問題パターン

結合度が高いシステムでは、あるオブジェクトの変更が他のオブジェクトに大きな影響を与えます。結合度が高い状態は理解・保守が困難で、変更が予期せぬ波及効果を引き起こします。

### 主要レシピ

#### レシピ17.1：隠された前提の明確化

**問題**: 暗黙的な前提や想定がコードに含まれ、システムの振る舞いに影響を与えている

**解決策**: コードを明示的に保つ。測定単位、データ形式、前提条件を明示的にモデル化する

**コード例**:
```python
# Before（暗黙的な単位）
ten_centimeters = 10
ten_inches = 10
result = ten_centimeters + ten_inches  # 20（単位混同）

# After（明示的なモデル化）
class Measure:
    def __init__(self, scalar, unit):
        self.scalar = scalar
        self.unit = unit

ten_cm = Measure(10, "cm")
ten_in = Measure(10, "in")
# 異なる単位の加算はエラーとなり、適切な変換が必要
```

**関連**: 暗黙の前提を見つけるには、テストと実際の動作確認が重要

#### レシピ17.2：シングルトンの置き換え

**問題**: シングルトンパターンを使用している

**解決策**: 文脈に応じて適切に生成される通常のオブジェクトに置き換える

**コード例**:
```php
// Before（シングルトン）
class God {
    private static $instance = null;

    private function __construct() {}

    public static function getInstance() {
        if (null === self::$instance) {
            self::$instance = new self();
        }
        return self::$instance;
    }
}

// After（文脈依存の設計）
interface Religion {
    // 宗教に共通する振る舞い
}

final class MonotheisticReligion implements Religion {
    private $godInstance;

    public function __construct(God $onlyGod) {
        $this->godInstance = $onlyGod;
    }
}

final class PolytheisticReligion implements Religion {
    private $gods;

    public function __construct(array $gods) {
        $this->gods = $gods;
    }
}
```

**主な問題点**:
- 全単射性の欠如（現実世界の概念と対応しない）
- 密結合とテスト困難
- フェイルファスト原則違反
- マルチスレッド環境での問題

#### レシピ17.3：ゴッドオブジェクトの分割

**問題**: 過剰な責務を持つオブジェクトがシステム全体に影響を与えている

**解決策**: 単一責任の原則に従い、責務を分割する

**コード例**:
```python
# Before（ゴッドオブジェクト）
class Soldier:
    def run(self): pass
    def fight(self): pass
    def serialize(self): pass
    def display(self): pass
    def toXML(self): pass
    def jsonDecode(self): pass
    # ... 多数のメソッド

# After（責務分割）
class Soldier:
    def run(self): pass
    def fight(self): pass
    def clean(self): pass
    # 兵士の本質的な行動のみ
```

**関連**: 定数クラスも同様に分割が必要

#### レシピ17.6：散弾銃型変更の解消

**問題**: 単一の機能変更が複数箇所での修正を必要とする

**解決策**: DRY原則に従い、重複を排除して変更の影響範囲を限定する

**コード例**:
```php
// Before（重複コード）
class SocialNetwork {
    function postStatus(string $newStatus) {
        if (!$user->isLogged()) {
            throw new Exception('ユーザーがログインしていません');
        }
        // ...
    }

    function uploadPicture(Picture $pic) {
        if (!$user->isLogged()) {
            throw new Exception('ユーザーがログインしていません');
        }
        // ...
    }
}

// After（共通化）
class SocialNetwork {
    function postStatus(string $newStatus) {
        $this->assertUserIsLogged();
        // ...
    }

    private function assertUserIsLogged() {
        if (!$this->user->isLogged()) {
            throw new Exception('ユーザーがログインしていません');
        }
    }
}
```

#### レシピ17.8：フィーチャーエンヴィの防止

**問題**: あるオブジェクトが他のオブジェクトのメソッドを過度に利用している

**解決策**: 依存関係を断ち、振る舞いを適切なクラスに配置する

**コード例**:
```java
// Before（フィーチャーエンヴィ）
class Candidate {
    void printJobAddress(Job job) {
        System.out.println(job.address().street());
        System.out.println(job.address().city());
        System.out.println(job.address().zipCode());
    }
}

// After（責務の再配置）
class Job {
    void printAddress() {
        System.out.println(this.address().street());
        System.out.println(this.address().city());
        System.out.println(this.address().zipCode());
    }
}

class Candidate {
    void printJobAddress(Job job) {
        job.printAddress();
    }
}
```

#### レシピ17.11：波及効果の回避

**問題**: 小さな変更が予期せぬ広範囲の問題を引き起こす

**解決策**: コンポーネント間の依存関係を減らし、適切にテストを配置する

**コード例**:
```javascript
// Before（文脈依存のメソッド）
class Time {
    now() {
        // OSの現在時刻を取得（タイムゾーン不明）
    }
}

// After（文脈を明示）
class Time {
    constructor(hour, minute, second, timezone) {
        this.hour = hour;
        this.minute = minute;
        this.second = second;
        this.timezone = timezone;
    }
}

class RelativeClock {
    constructor(timezone) {
        this.timezone = timezone;
    }

    now(timezone) {
        var localTime = this.localSystemTime();
        // タイムゾーン変換
        return new Time(..., timezone);
    }
}
```

#### レシピ17.15：データの塊のリファクタリング

**問題**: 常に一緒に使用される複数のデータ項目が分散している

**解決策**: 関連データを1つのオブジェクトにまとめる

**コード例**:
```csharp
// Before（データの塊）
public class DinnerTable {
    private Person Guest;
    private DateTime From;
    private DateTime To;
}

// After（オブジェクト化）
public class TimeInterval {
    public TimeInterval(DateTime from, DateTime to) {
        if (from >= to) {
            throw new ArgumentException("無効な期間");
        }
        From = from;
        To = to;
    }
}

public class DinnerTable {
    public DinnerTable(Person guest, TimeInterval reservationTime) {
        Guest = guest;
        Interval = reservationTime;
    }
}
```

---

## 18章：グローバル

### 問題パターン

グローバル関数、クラス、属性は見過ごされがちなコストがあります。`new()`を使ったオブジェクト生成さえも、適切に扱わなければグローバルクラスとの密結合を生み出します。

### 主要レシピ

#### レシピ18.1：グローバル関数の具象化

**問題**: どこからでも呼び出せるグローバル関数が存在する

**解決策**: スコープを狭め、コンテキストオブジェクトでカプセル化する

**コード例**:
```php
// Before（グローバル関数直接呼び出し）
class Employee {
    function taxesPaidUntilToday() {
        return database()->select(
            "SELECT TAXES FROM EMPLOYEE WHERE ID = " . $this->id()
        );
    }
}

// After（コンテキストオブジェクトに委譲）
final class EmployeeTaxesCalculator {
    function taxesPaidUntilToday($context) {
        return $context->selectTaxesForEmployeeUntil(
            $this->socialSecurityNumber,
            $context->currentDate()
        );
    }
}
```

#### レシピ18.2：スタティックメソッドの具象化

**問題**: クラスにスタティックメソッドが定義されている

**解決策**: インスタンスメソッドに置き換え、機能に特化したオブジェクトを作成する

**コード例**:
```javascript
// Before（スタティックメソッド）
class DateStringHelper {
    static format(date) {
        return date.toString('yyyy-MM-dd');
    }
}

DateStringHelper.format(new Date());

// After（インスタンスメソッド）
class DateToStringFormatter {
    constructor(date) {
        this.date = date;
    }

    englishFormat() {
        return this.date.toString('yyyy-MM-dd');
    }
}

new DateToStringFormatter(new Date()).englishFormat();
```

**理由**: スタティックメソッドはグローバル変数と同様に結合度を高め、テスト困難、モック化困難な問題を引き起こす

#### レシピ18.4：グローバルクラスの除去

**問題**: クラスをグローバルなアクセスポイントとして使用している

**解決策**: 名前空間やモジュールを使用してスコープを限定する

**コード例**:
```php
// Before（グローバルアクセス）
final class StringUtilHelper {
    static function formatYYYYMMDD($date): string {
        // ...
    }
}

// After（名前空間内に限定）
namespace Dates;

final class DateFormatter {
    public function formatYYYYMMDD(\DateTime $date): string {
        // ...
    }
}

// 使用時は完全修飾が必要
use Dates\DateFormatter;
$formatter = new DateFormatter();
```

---

## 19章：階層構造

### 問題パターン

継承は歴史的にコード再利用のために誤用されてきました。継承よりもコンポジションを優先すべきですが、適切に使うには経験が必要です。

### 主要レシピ

#### レシピ19.1：深い継承の分割

**問題**: コード再利用のために深い階層構造を持っている

**解決策**: インターフェースを見出し、継承よりコンポジションを優先する

**コード例**:
```python
# Before（深い階層）
class Animalia: pass
class Chordata(Animalia): pass
class Mammalia(Chordata): pass
class Carnivora(Mammalia): pass
class Pinnipedia(Carnivora): pass
class Phocidae(Pinnipedia): pass
class Halichoerus(Phocidae): pass
class GreySeal(Halichoerus): pass

# After（フラットな設計）
class GreySeal:
    def eat(self): pass
    def sleep(self): pass
    def swim(self): pass
    def breed(self): pass
```

**コンポジションの例**:
```python
# Before（継承による課金方法）
class Server:
    @abstractmethod
    def calculate_cost(self): pass

class HourlyChargedServer(Server):
    def calculate_cost(self):
        return (self.cpu * 5 + self.ram * 2) * self.hours

# After（コンポジションによる課金方法）
class Server:
    def calculate_cost(self):
        return self.charging.calculate_cost(self.cpu, self.ram)

    def change_charging_method(self, charging):
        self.charging = charging

class ChargingMethod:
    @abstractmethod
    def calculate_cost(self, cpu, ram): pass

class HourlyCharging(ChargingMethod):
    def calculate_cost(self, cpu, ram):
        return (cpu * 5 + ram * 2) * self.hours
```

#### レシピ19.3：コード再利用のためのサブクラス化の回避

**問題**: 「is-a」関係に基づいてサブクラス化を行っている

**解決策**: 継承よりコンポジションを優先し、「behaves-as-a」関係で考える

**コード例**:
```java
// Before（不適切な継承）
public class Rectangle {
    int length;
    int width;

    public int area() {
        return this.length * this.width;
    }
}

public class Square extends Rectangle {
    public int area() {
        return this.length * this.length;
    }
}

// After（適切な分離）
abstract public class Shape {
    abstract public int area();
}

public final class Rectangle extends Shape {
    int length;
    int width;

    public int area() {
        return this.length * this.width;
    }
}

public final class Square extends Shape {
    int size;

    public int area() {
        return this.size * this.size;
    }
}
```

#### レシピ19.7：具象クラスのfinal化

**問題**: 具象クラスがサブクラスを持っている

**解決策**: 具象クラスをfinalにし、階層構造を見直す

**原則**: 階層の末端は具象final、それ以外は抽象クラス

**コード例**:
```java
// Before（具象クラスの継承）
class Stack extends ArrayList {
    public void push(Object value) { ... }
    public Object pop() { ... }
}

// After（適切な階層）
abstract class Collection {
    public abstract int size();
}

final class Stack extends Collection {
    private Object[] contents;

    public void push(Object value) { ... }
    public Object pop() { ... }
    public int size() {
        return contents.length;
    }
}

final class ArrayList extends Collection {
    private Object[] contents;

    public int size() {
        return contents.length;
    }
}
```

#### レシピ19.11：protected属性の削除

**問題**: クラスにprotected属性がある

**解決策**: 属性をprivateに変更し、コンポジションを使用する

**コード例**:
```php
// Before（protected属性）
abstract class ElectronicDevice {
    protected $battery;

    public function __construct(Battery $battery) {
        $this->battery = $battery;
    }
}

abstract class IDevice extends ElectronicDevice {
    protected $operatingSystem;

    public function __construct(Battery $battery, OperatingSystem $ios) {
        $this->operatingSystem = $ios;
        parent::__construct($battery);
    }
}

// After（コンポジション）
interface ElectronicDevice {}

final class IPad implements ElectronicDevice {
    private $operatingSystem;
    private $battery;

    public function __construct(Battery $battery, OperatingSystem $ios) {
        $this->operatingSystem = $ios;
        $this->battery = $battery;
    }
}

final class IPhone implements ElectronicDevice {
    private $phoneModule;
    private $operatingSystem;
    private $battery;

    public function __construct(
        Battery $battery,
        OperatingSystem $ios,
        PhoneModule $phoneModule
    ) {
        $this->phoneModule = $phoneModule;
        $this->operatingSystem = $ios;
        $this->battery = $battery;
    }
}
```

---

## 実践ガイド

### アーキテクチャレベルのコードスメル検出手順

1. **結合度チェック**
   - シングルトンの使用箇所を特定
   - グローバル関数/クラスの依存関係を可視化
   - クラス間の依存グラフを作成

2. **階層構造チェック**
   - 継承の深さを測定（3レベル超は要注意）
   - 具象クラス間の継承を検出
   - protected属性の使用状況を確認

3. **責務チェック**
   - 各クラスのメソッド数をカウント（10個超は要注意）
   - 変更理由が複数ある箇所を特定
   - データの塊パターンを検出

### リファクタリング優先順位

**高優先度（即座に対応）**:
- シングルトンパターンの使用
- ゴッドオブジェクト
- グローバル関数の乱用

**中優先度（計画的に対応）**:
- 深い継承階層
- 散弾銃型変更
- データの塊

**低優先度（機会があれば対応）**:
- protected属性
- オプション引数
- 中間者パターン

### AskUserQuestion使用ガイド

アーキテクチャ変更は影響範囲が大きいため、以下の場合は必ずユーザーに確認:

- シングルトンを通常のオブジェクトに置き換える際の文脈設計
- 深い継承階層をフラット化する際の代替アプローチ
- グローバルクラスの名前空間設計

```python
AskUserQuestion(
    questions=[{
        "question": "シングルトンの置き換え方針を選択してください",
        "header": "リファクタリングアプローチ",
        "options": [
            {
                "label": "文脈依存オブジェクト",
                "description": "各文脈で個別のインスタンスを生成"
            },
            {
                "label": "依存性注入",
                "description": "DIコンテナで管理"
            },
            {
                "label": "現状維持",
                "description": "影響範囲を評価してから判断"
            }
        ],
        "multiSelect": False
    }]
)
```

---

## 関連スキル

- `applying-solid-principles`: SOLID原則の詳細
- `testing`: リファクタリング時のテスト戦略
- `enforcing-type-safety`: 型システムによる依存関係の明示
