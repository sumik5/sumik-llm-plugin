# 型システム応用と null safety

## 概要

本ファイルはジェネリクス・enum・extension methods・演算子オーバーロード・`late`・sound null safety・`Object`/`dynamic` の使い分けを扱う。クラス設計そのものは [OOP-AND-CLASSES.md](OOP-AND-CLASSES.md) を参照。null safety は Dart 3.x の言語基盤であり、他のどのトピックより優先して理解すべき前提知識として最初に置く。

## Sound null safety の仕組み

Dart は 2.12 以降、既定で **sound null safety** が有効。型システムが「その変数が null になり得るか」をコンパイル時に保証し、null 非許容の変数へ実行時に null が代入されることは（`dynamic` や FFI 境界を除き）原理的に起こらない。

| 表記 | 意味 |
|---|---|
| `String name` | null 非許容。宣言時または使用前に必ず非 null 値を持つ |
| `String? name` | null 許容。`null` を代入できる |
| `late String name` | 非 null 型だが初期化を遅延（使用前に必ず代入する責任はプログラマ側） |
| `late final String name` | 遅延初期化 + 一度だけ代入可能 |

```dart
class Profile {
  Profile({required this.email, this.nickname});

  final String email;       // 必須・null 非許容
  final String? nickname;   // 省略可・null 許容

  String get displayName => nickname ?? email; // null 合体演算子
}
```

### null 許容値を安全に扱う演算子

| 演算子 | 意味 | 例 |
|---|---|---|
| `?.` | レシーバが null なら呼び出し全体を null にする | `user?.email` |
| `??` | 左辺が null なら右辺を評価する | `nickname ?? 'ゲスト'` |
| `??=` | 変数が null の場合のみ代入する | `cache ??= computeExpensiveValue()` |
| `!` | 非 null であると表明する（間違っていれば実行時例外） | `user!.email` |

```dart
String greet(String? name) {
  return 'こんにちは、${name ?? 'ゲスト'}さん';
}
```

- `!`（null 表明演算子）は「型システムでは追えないが自分は非 null だと知っている」場面に限定する。乱用すると sound null safety の恩恵を自ら捨てることになる。
- フロー解析（type promotion）により、`if (value != null) { value.length }` のようなガード後は `value` が非 null 型として扱われる。ローカル変数・`final` フィールドで特に効果的。

### `late` の使いどころ

| 場面 | 使ってよいか | 理由 |
|---|---|---|
| DI コンテナから後から注入されるフィールド | 適切 | コンストラクタ実行時点では値が確定していない |
| 単に null チェックが面倒だから | 不適切 | 初期化忘れが実行時 `LateInitializationError` になる |
| 高コストな計算を初回アクセス時まで遅延したい | 適切（`late final` + ゲッター相当） | 遅延評価の意図が明確 |

```dart
class ImageCache {
  late final Directory cacheDir; // initialize() で後から設定される想定

  Future<void> initialize() async {
    cacheDir = await getTemporaryDirectory();
  }
}
```

## レコード型（Records）とパターンマッチング

Dart 3.0 で導入された **record** は、クラスを定義せずに複数の値を型安全にひとまとめにできる匿名の不変データ構造。関数から複数値を返す用途で、専用クラスや `Map<String, dynamic>` の代わりに使う。

```dart
(double, double) minMax(List<double> values) {
  var min = values.first;
  var max = values.first;
  for (final v in values) {
    if (v < min) min = v;
    if (v > max) max = v;
  }
  return (min, max);
}

void main() {
  final (min, max) = minMax([3.0, 1.5, 9.2, 4.4]); // 分割代入（destructuring）
  print('min=$min, max=$max');
}
```

- named fields も使える: `({double min, double max}) minMax(...)` と宣言すれば `result.min` / `result.max` でアクセスできる。
- record は構造的に等価（同じ形・同じ値なら `==` が真になる）。値オブジェクトを手早く作りたいだけで振る舞い（メソッド）が不要な場合は、クラスより record が適する。
- `switch` 式のパターンマッチングと組み合わせると、record やクラスの分解・条件分岐を簡潔に書ける。

```dart
String classify((int, int) point) => switch (point) {
      (0, 0) => '原点',
      (var x, 0) => 'x軸上 (x=$x)',
      (0, var y) => 'y軸上 (y=$y)',
      (var x, var y) when x == y => '対角線上 ($x, $y)',
      _ => 'その他',
    };
```

| 判断基準 | record が適する | クラスが適する |
|---|---|---|
| メソッド・不変条件の検証ロジックが必要か | 不要ならこちら | 必要ならこちら |
| 一時的な複数値の受け渡し（関数の戻り値等）か | はい | 長期的なドメインモデルはこちら |
| 型に名前を付けてドキュメント化したいか | 匿名で十分なら record | 意味のある型名が欲しいならクラス |

## ジェネリクス

型パラメータでクラス・メソッドを汎用化し、コンパイル時の型安全性を保ったまま再利用性を高める。

```dart
class Box<T> {
  Box(this.value);
  T value;

  R map<R>(R Function(T value) transform) => transform(value);
}

void main() {
  final box = Box<int>(42);
  final text = box.map((value) => 'value=$value');
  print(text);
}
```

- 型引数に制約を課すには `extends` を使う（`class Repository<T extends Entity> { ... }`）。
- コレクション型（`List<T>`・`Map<K, V>`）は標準ライブラリの代表的なジェネリクス活用例。独自の型でも同じ発想で「特定の型に依存しないコンテナ/処理」を作る。
- 型推論が効くため、呼び出し側で型引数を省略できることが多い（`Box(42)` でも `Box<int>` と推論される）。

```dart
T firstWhereOrDefault<T>(List<T> items, bool Function(T) test, T fallback) {
  for (final item in items) {
    if (test(item)) return item;
  }
  return fallback;
}
```

## enum

Dart の enum は単純な値の列挙（Dart 2.x 相当）に加え、Dart 2.17 以降は**フィールド・コンストラクタ・メソッドを持つ拡張 enum（enhanced enum）**をサポートする。

```dart
enum Priority {
  low(weight: 1),
  medium(weight: 2),
  high(weight: 3);

  const Priority(this.weight);
  final int weight;

  bool get isUrgent => this == Priority.high;
}

void main() {
  print(Priority.high.weight); // 3
  print(Priority.values.length); // 3
}
```

- enum は暗黙的に `index`（宣言順の 0 始まり整数）と `values`（全ケースの `List`）を持つ。
- `switch` 文/式と組み合わせると網羅性チェックが働き、ケース漏れをコンパイルエラーとして検出できる。

```dart
String label(Priority priority) => switch (priority) {
      Priority.low => '低',
      Priority.medium => '中',
      Priority.high => '高',
    };
```

## extension methods

既存の型（自分が定義していないライブラリ標準の型も含む）に、ソース変更なしでメソッド/ゲッターを追加する仕組み。

```dart
extension StringCasing on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

void main() {
  print('dart'.capitalize()); // Dart
}
```

| 判断基準 | extension が適する | クラス継承/mixin が適する |
|---|---|---|
| 対象の型を自分で定義していない（標準ライブラリ・外部パッケージ）か | はい | 継承/mixin は不可な場合が多い |
| 状態（フィールド）を追加したいか | 不可（extension はフィールドを持てない） | 可能 |
| 既存 API に「ちょっとした便利メソッド」を足したいだけか | はい | オーバーエンジニアリングになりがち |

- 同名メソッドを持つ複数の extension が同時にスコープに入るとコンパイルエラーになる。衝突時は `show`/`hide` 付き import か、明示的な `extensionName(value).method()` 呼び出しで解決する。

## 演算子オーバーロード

`operator` キーワードで算術・比較演算子などをクラスに定義できる。値オブジェクト（座標・金額・ベクトルなど）で「自然な記法」を提供する場合に有効。

```dart
class Vector2 {
  const Vector2(this.x, this.y);
  final double x;
  final double y;

  Vector2 operator +(Vector2 other) => Vector2(x + other.x, y + other.y);
  Vector2 operator *(double scalar) => Vector2(x * scalar, y * scalar);

  @override
  bool operator ==(Object other) =>
      other is Vector2 && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}
```

- `==` をオーバーライドしたら **必ず `hashCode` も一致するように再定義する**（`Set`/`Map` のキーとして正しく機能させるため）。`Object.hash(...)` で複数フィールドから合成するのが定石。
- オーバーロードできる演算子は限定的（`+` `-` `*` `/` `==` `<` `[]` など）。独自の中置演算子は追加できない。

## Object と dynamic

| 型 | コンパイル時型チェック | 主な用途 |
|---|---|---|
| `Object` / `Object?` | あり（`Object` が持つメンバーのみ静的に呼び出せる） | 「何でも受け取れるが安全に扱いたい」引数・戻り値 |
| `dynamic` | なし（あらゆるメンバー呼び出しがコンパイルを通り、実行時に解決される） | 動的な JSON デコード結果など、型を静的に確定できない値 |

```dart
void logAny(Object? value) {
  print(value.toString()); // Object の toString() は静的に呼べる
}

void risky(dynamic value) {
  value.nonExistentMethod(); // コンパイルは通るが実行時に NoSuchMethodError
}
```

- 型が不明な値を扱う場合でも、可能な限り `Object?` + 型チェック（`is`/`as`）や ジェネリクスを選び、`dynamic` は「本当に動的解決が必要な場面」に限定する。`dynamic` を多用すると sound null safety と静的型検査の恩恵の大半を失う。

```dart
String describe(Object? value) {
  return switch (value) {
    int n => '整数: $n',
    String s => '文字列: $s',
    null => 'null',
    _ => '不明な型: ${value.runtimeType}',
  };
}
```

## チェックリスト

- [ ] null 許容が本当に必要な値だけに `?` を付けているか（不要な `?` は呼び出し側の負担を増やす）
- [ ] `!`（null 表明）を安易な null チェック回避として使っていないか
- [ ] `late` を「初期化忘れの隠蔽」ではなく「意図的な遅延初期化」としてのみ使っているか
- [ ] ジェネリクスの型パラメータに適切な制約（`extends`）を課しているか
- [ ] enum に振る舞いを持たせる場合、拡張 enum（コンストラクタ・フィールド）を検討したか
- [ ] `==` をオーバーライドしたクラスで `hashCode` も一致させて再定義したか
- [ ] `dynamic` を使う箇所が本当に静的型付けを諦めるべき場面か再検討したか
