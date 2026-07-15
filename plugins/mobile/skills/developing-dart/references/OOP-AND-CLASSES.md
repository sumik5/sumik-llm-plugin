# クラスとオブジェクト指向

## 概要

Dart はクラスベースのオブジェクト指向言語で、すべての値がオブジェクトである（`int`・`bool`・関数リテラルも含む）。本ファイルはクラス宣言・コンストラクタ・static メンバー・継承と多態・abstract class・mixin・カプセル化を扱う。ジェネリクス・enum・extension methods・演算子オーバーロード・null safety は [ADVANCED-TYPES.md](ADVANCED-TYPES.md) を参照。`developing-dart` 本体（[INSTRUCTIONS.md](../INSTRUCTIONS.md)）からはクラス設計の中核リファレンスという位置づけ。

## クラスとオブジェクトの基礎

クラスはフィールド（状態）とメソッド（振る舞い）をまとめた型の設計図。オブジェクトはクラスのインスタンス。

```dart
class Person {
  final String name;
  final int age;

  Person(this.name, this.age);

  void introduce() {
    print('$name, $age歳');
  }
}

void main() {
  final person = Person('Aiko', 28);
  person.introduce();
}
```

- コンストラクタ引数に `this.name` と書くと、同名フィールドへの代入を自動生成する（フィールド初期化省略記法）。
- フィールドは `final` を既定にし、可変にする明確な理由がある場合のみ非 `final` にする（不変オブジェクトはスレッド安全でテストしやすい）。
- ゲッター/セッターは `get`/`set` キーワードで宣言でき、呼び出し側からは通常のプロパティアクセスに見える。

```dart
class Rectangle {
  Rectangle(this.width, this.height);

  final double width;
  final double height;

  double get area => width * height;
  set doubleWidth(double _) => throw UnsupportedError('use copyWith instead');
}
```

## コンストラクタ

| 種類 | 用途 | 構文の要点 |
|---|---|---|
| ジェネレーティブ（既定） | 通常のインスタンス生成 | `ClassName(this.field, ...)` |
| 名前付きコンストラクタ | 同一クラスに複数の生成経路を用意 | `ClassName.fromJson(...)` |
| const コンストラクタ | コンパイル時定数インスタンスを作る | 全フィールドが `final` かつ再帰的に const 化可能な場合のみ宣言できる |
| factory コンストラクタ | 必ずしも新規インスタンスを返さない生成ロジック | `factory ClassName(...) { ... return ...; }` |
| リダイレクトコンストラクタ | 別のコンストラクタへ委譲 | `ClassName.name(...) : this(...)` |

```dart
class Point {
  const Point(this.x, this.y);

  const Point.origin() : x = 0, y = 0; // 初期化子リストで直接代入

  final double x;
  final double y;

  factory Point.fromMap(Map<String, double> map) {
    return Point(map['x'] ?? 0, map['y'] ?? 0);
  }
}
```

- 初期化子リスト（`:` の後ろ）は `super(...)` 呼び出しや、コンストラクタ本体実行前に不変条件を assert する用途にも使う。
- factory コンストラクタはインスタンスを生成しないケース（キャッシュ返却・サブクラス選択・シングルトン）で必須。`this` を持たないため初期化子リストは書けない。

```dart
class Logger {
  Logger._internal(); // プライベートな名前付きコンストラクタ

  static final Logger _instance = Logger._internal();

  factory Logger() => _instance; // 常に同一インスタンスを返すシングルトン
}
```

## static 変数とメソッド

`static` メンバーはインスタンスではなくクラス自体に属する。定数・カウンタ・ファクトリヘルパーなど、個々のオブジェクトの状態に依存しないものに使う。

```dart
class Counter {
  static int _count = 0;

  static int get count => _count;

  Counter() {
    _count++;
  }
}

void main() {
  Counter();
  Counter();
  print(Counter.count); // 2
}
```

| 判断基準 | static にする | インスタンスメンバーにする |
|---|---|---|
| 状態がオブジェクトごとに異なるか | いいえ | はい |
| インスタンス化せずに呼びたいか | はい | いいえ |
| ユーティリティ関数・定数 | 該当 | 非該当 |

## 継承と多態

`extends` で単一継承する。`super` で親クラスのメンバーにアクセスし、`@override` でオーバーライドを明示する（付けなくても動くが、リンターの警告を得るため必須にする）。

```dart
abstract class Shape {
  double get area;

  @override
  String toString() => '${runtimeType}(area: ${area.toStringAsFixed(2)})';
}

class Circle extends Shape {
  Circle(this.radius);
  final double radius;

  @override
  double get area => 3.141592653589793 * radius * radius;
}

class Square extends Shape {
  Square(this.side);
  final double side;

  @override
  double get area => side * side;
}

void printAreas(List<Shape> shapes) {
  for (final shape in shapes) {
    print(shape); // 実行時の型に応じたオーバーライドが呼ばれる（多態）
  }
}
```

- Dart は単一継承のみ（多重継承は不可）。複数の振る舞いを合成したい場合は mixin を使う。
- `super.method()` で親の実装を呼びつつ拡張できる。

## abstract class とインターフェース

Dart には Java のような `interface` キーワードは無く、**すべてのクラスが暗黙にインターフェースを持つ**。`implements` を使えばどんなクラスもインターフェースとして実装できる（実装側は全メンバーを再実装する必要があり、親の実装は継承されない）。

```dart
abstract class Comparable2<T> {
  int compareTo2(T other);
}

class Money implements Comparable2<Money> {
  Money(this.cents);
  final int cents;

  @override
  int compareTo2(Money other) => cents.compareTo(other.cents);
}
```

| 手段 | 実装の継承 | 複数指定 | 用途 |
|---|---|---|---|
| `extends` | あり | 不可（単一） | is-a 関係で振る舞いを再利用 |
| `implements` | なし（型のみ） | 可（複数） | 契約（インターフェース）の充足 |
| `with`（mixin） | あり | 可（複数） | 横断的な振る舞いの合成 |

`abstract class` はインスタンス化できないクラスで、1 つ以上のメソッドを本体なしで宣言できる。サブクラスに実装を強制する契約として使う。

```dart
abstract class Repository<T> {
  Future<T?> findById(String id);
  Future<void> save(T entity);
}
```

### class modifiers（Dart 3.0 以降）

クラス継承・実装の可否をライブラリ境界で制御する修飾子群。パッケージ設計で「意図しない継承/実装」を型システムレベルで防ぐ。

| 修飾子 | 同一ライブラリでの extends | 外部ライブラリでの extends | 外部ライブラリでの implements | 主な用途 |
|---|---|---|---|---|
| （無指定） | 可 | 可 | 可 | 既定の柔軟なクラス |
| `base` | 可 | 可 | 不可 | 不変条件をコンストラクタで保証したいが継承は許す |
| `interface` | 可 | 不可 | 可 | 実装契約として公開し、継承による内部再利用は禁止 |
| `final` | 可 | 不可 | 不可 | 継承も実装も禁止（外部からは完全に閉じた型） |
| `sealed` | 可（暗黙 abstract） | 不可 | 不可 | 閉じた型階層。`switch` の網羅性チェックに使う |
| `mixin class` | mixin としても通常クラスとしても使用可 | — | — | mixin と基底クラスを両立したい場合 |

```dart
sealed class ApiResult<T> {}

class Success<T> extends ApiResult<T> {
  Success(this.data);
  final T data;
}

class Failure<T> extends ApiResult<T> {
  Failure(this.message);
  final String message;
}

String describe(ApiResult<int> result) => switch (result) {
      Success(:final data) => '成功: $data',
      Failure(:final message) => '失敗: $message',
      // sealed なので他のケースを網羅済み。default 不要（漏れがあればコンパイルエラー）
    };
```

## mixin と合成

`mixin` はコンストラクタを持たず、複数のクラスに横断的な振る舞いを注入するための単位。`with` 句で 1 つ以上の mixin をクラスに適用する。`on` 制約で「この mixin を適用できるのは特定の型のサブクラスのみ」と限定できる。

```dart
mixin Loggable {
  void log(String message) => print('[$runtimeType] $message');
}

mixin Flyable on Animal {
  void fly() => log('飛んでいます'); // Animal のメンバーを前提にできる
}

abstract class Animal with Loggable {
  void eat();
}

class Bird extends Animal with Flyable {
  @override
  void eat() => log('食べています');
}
```

| 判断基準 | mixin を使う | 抽象クラス継承を使う |
|---|---|---|
| 複数の独立した振る舞いを合成したいか | はい | いいえ（単一継承の制約に収まる） |
| コンストラクタ・状態初期化が必要か | 不要 | 必要ならこちら |
| 型階層に is-a の意味を持たせたいか | 弱い（機能の混入） | 強い |

## カプセル化とアクセス修飾子

Dart のプライバシーは**ライブラリ単位**で決まる（クラス単位ではない）。識別子名の先頭に `_` を付けると、そのファイル（正確にはライブラリ）の外から参照できなくなる。

```dart
class _InternalCache {
  final Map<String, Object> _store = {};
}

class PublicApi {
  final _InternalCache _cache = _InternalCache(); // 同一ライブラリ内なら参照可
}
```

- `part`/`part of` で同一ライブラリに分割されたファイル間ではプライベートメンバーを共有できる。
- クラス単位のカプセル化（外部からの継承・実装だけを禁止する）は前述の `final`/`interface`/`base` 修飾子で実現する。`_` 命名とクラス修飾子は目的が異なるため併用する。
- get-only の公開 API を作るには、フィールドを `final` かつプライベートにし、ゲッターのみ公開する。

```dart
class Temperature {
  Temperature(double celsius) : _celsius = celsius;
  final double _celsius;

  double get celsius => _celsius;
  double get fahrenheit => _celsius * 9 / 5 + 32;
}
```

## チェックリスト

- [ ] フィールドは既定で `final`、可変にする必要がある場合のみ非 `final` にしたか
- [ ] インスタンスに依存しない値・関数を誤ってインスタンスメンバーにしていないか（`static` の使いどころ）
- [ ] オーバーライドしたメンバーすべてに `@override` を付けたか
- [ ] 公開 API として外部実装/継承させたくないクラスに `final`/`interface`/`base`/`sealed` を検討したか
- [ ] 複数の振る舞いを合成する場面で、単一継承の制約を mixin で回避できないか検討したか
- [ ] プライベートにすべきフィールド/メソッドに `_` を付けたか、公開ゲッターだけを外部 API にしたか
