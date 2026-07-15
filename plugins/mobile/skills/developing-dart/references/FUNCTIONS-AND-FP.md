# 関数と関数型プログラミング

## 概要

このリファレンスは、Dartにおける関数の宣言、多様なパラメータ形式、匿名関数、クロージャ、高階関数、関数の合成・カリー化を扱う。Dartの関数は第一級オブジェクト（`Function` 型の値として変数に代入したり、引数として渡したりできる）であり、オブジェクト指向とともに関数型のスタイルを併用できる。クラス・継承などのOOP要素はOOP-AND-CLASSES.mdを参照する。

## 関数の宣言

```dart
// トップレベル関数
int add(int a, int b) {
  return a + b;
}

// 式本体（式が1つだけの場合の短縮記法）
int multiply(int a, int b) => a * b;

// 戻り値のない関数
void logMessage(String message) {
  print('[LOG] $message');
}

// ローカル関数（関数内で定義する関数）
int computeTotal(List<int> values) {
  int sum(List<int> xs) => xs.fold(0, (acc, x) => acc + x);
  return sum(values);
}
```

関数は必ず戻り値の型を明示する（`void` を含む）ことが推奨される。トップレベル関数・メソッド・ローカル関数はいずれも同じ構文で宣言でき、ローカル関数はその関数の中でだけ使う補助ロジックを閉じ込めるのに適する。

## 関数パラメータ

Dartのパラメータは大きく分けて「位置パラメータ（positional）」と「名前付きパラメータ（named）」があり、それぞれ必須／省略可能を組み合わせられる。

| 種類 | 構文 | 呼び出し例 |
|---|---|---|
| 必須位置パラメータ | `void f(int a, int b)` | `f(1, 2)` |
| 省略可能位置パラメータ | `void f(int a, [int? b])` | `f(1)` / `f(1, 2)` |
| 必須名前付きパラメータ | `void f({required int a})` | `f(a: 1)` |
| 省略可能名前付きパラメータ | `void f({int? a})` | `f()` / `f(a: 1)` |

```dart
// 位置パラメータ + 省略可能位置パラメータ
String buildGreeting(String name, [String? honorific]) {
  return honorific == null ? 'Hello, $name' : 'Hello, $honorific $name';
}

buildGreeting('Alice'); // 'Hello, Alice'
buildGreeting('Alice', 'Dr.'); // 'Hello, Dr. Alice'

// 名前付きパラメータ（呼び出し側で意図が読み取りやすい）
void createUser({required String name, required String email, int age = 0}) {
  print('$name <$email>, age=$age');
}

createUser(name: 'Bob', email: 'bob@example.com');
createUser(name: 'Bob', email: 'bob@example.com', age: 30);
```

## 省略可能パラメータと既定値

省略可能パラメータ（位置・名前付きいずれも）には既定値を指定できる。既定値はコンパイル時定数でなければならない。

```dart
void configure({int retryCount = 3, Duration timeout = const Duration(seconds: 30)}) {
  // ...
}

// 省略可能位置パラメータの既定値
double calculateArea(double width, [double height = 1.0]) => width * height;
```

`required` キーワードは名前付きパラメータを必須にする（省略時はコンパイルエラー）。位置パラメータは丸括弧、省略可能位置パラメータは角括弧 `[]`、名前付きパラメータは波括弧 `{}` で囲む構文上の違いに注意する。

**判断基準:**

| 状況 | 推奨 |
|---|---|
| 引数の順序が自明で少数（2〜3個） | 必須位置パラメータ |
| 引数が多い、または呼び出し側での可読性を重視したい | 名前付きパラメータ |
| 省略されがちなオプション設定 | 名前付き省略可能パラメータ + 既定値 |
| 省略時にnullとして扱いたい | `?` を付けた省略可能パラメータ（既定値なし） |

Widgetのコンストラクタなど引数が多くなりがちな箇所では、名前付きパラメータを既定にすることで呼び出し側の可読性と将来の引数追加時の後方互換性を両立できる。

## 匿名関数とラムダ式

名前を持たない関数（匿名関数）は、コールバックやコレクション操作の引数としてその場で定義できる。

```dart
final numbers = [1, 2, 3, 4, 5];

// 匿名関数（ブロック本体）
final doubled = numbers.map((int n) {
  return n * 2;
}).toList();

// アロー構文（式本体）による短縮記法
final tripled = numbers.map((n) => n * 3).toList();

// 型注釈を省略しても呼び出し元から推論される
final filtered = numbers.where((n) => n.isEven).toList();

// ボタンのコールバックのような単発利用
void onTap(void Function() callback) => callback();
onTap(() => print('tapped'));
```

引数の型は呼び出し元のコンテキストから推論できることが多く、`map`・`where` のようなコレクション操作では型注釈を省略するのが一般的である。ただし推論が効かない、または可読性のために型を明示したい場合は書いてよい。

## クロージャとレキシカルスコープ

クロージャとは、定義時点のスコープにある変数を「閉じ込めて」参照し続ける関数のことである。Dartの関数はレキシカルスコープ（静的スコープ）を持ち、内側の関数は外側の変数へアクセスできる。

```dart
Function makeCounter() {
  var count = 0;
  return () {
    count += 1;
    return count;
  };
}

void main() {
  final counter = makeCounter();
  print(counter()); // 1
  print(counter()); // 2

  final anotherCounter = makeCounter();
  print(anotherCounter()); // 1（独立した状態を持つ）
}
```

各クロージャは自身が生成された呼び出しごとに独立した変数の束を保持する。`makeCounter()` を2回呼べば、それぞれの `count` は互いに独立している。この性質は、イベントハンドラごとに固有の状態を持たせたい場合や、設定値を「焼き込んだ」関数を生成する場合に使える。

```dart
// 設定値を焼き込んだ関数を生成する例
Function(int) createMultiplier(int factor) {
  return (int value) => value * factor;
}

final doubleFn = createMultiplier(2);
final tripleFn = createMultiplier(3);

print(doubleFn(5)); // 10
print(tripleFn(5)); // 15
```

## 高階関数

高階関数とは、関数を引数として受け取る、または関数を戻り値として返す関数のことである。Dartのコレクション操作（`map`・`where`・`reduce`・`fold` 等。詳細はASYNC-AND-COLLECTIONS.md参照）はいずれも高階関数として実装されている。

```dart
// 関数を引数として受け取る
List<T> applyToAll<T>(List<T> items, T Function(T) transform) {
  return items.map(transform).toList();
}

final result = applyToAll<int>([1, 2, 3], (n) => n * n); // [1, 4, 9]

// 関数を戻り値として返す
bool Function(int) createThresholdChecker(int threshold) {
  return (int value) => value > threshold;
}

final isAboveTen = createThresholdChecker(10);
print(isAboveTen(15)); // true

// 標準ライブラリの高階関数の例
final total = [1, 2, 3, 4].reduce((a, b) => a + b); // 10
final sumWithSeed = [1, 2, 3].fold<int>(100, (acc, n) => acc + n); // 106
```

高階関数を使うことで、繰り返し処理の「反復の骨格」と「各要素に対する処理」を分離でき、`for` ループを毎回書くよりも意図が読み取りやすくなる場面が多い。ただし、単純なループの方が読みやすい場合や、副作用（早期return、複雑な分岐）を伴う処理では通常の `for` 文の方が適していることもある。

## 関数合成とカリー化

関数合成とは、複数の小さな関数を組み合わせて1つの新しい関数を作ることである。Dartには関数合成のための専用演算子はないが、通常の関数として素直に書ける。

```dart
typedef Transformer<T> = T Function(T value);

Transformer<T> compose<T>(Transformer<T> f, Transformer<T> g) {
  return (T value) => f(g(value));
}

int increment(int n) => n + 1;
int double_(int n) => n * 2;

final incrementThenDouble = compose(double_, increment);
print(incrementThenDouble(3)); // (3 + 1) * 2 = 8
```

カリー化とは、複数引数を取る関数を「1引数を取り、残りの引数を取る関数を返す」関数の連鎖に変換することである。

```dart
// カリー化前: 2引数を一度に受け取る
int add(int a, int b) => a + b;

// カリー化後: 1引数ずつ順に受け取る
int Function(int) Function(int) curriedAdd = (int a) => (int b) => a + b;

final addFive = curriedAdd(5);
print(addFive(3)); // 8
print(curriedAdd(10)(20)); // 30
```

カリー化は、共通の第一引数を「焼き込んだ」部分適用の関数を作りたい場合（例: 特定の設定を固定したバリデーション関数を大量に生成する）に有用である。ただし呼び出し側の可読性が下がりやすいため、乱用せず、必要な箇所に限定して使う。

## チェックリスト

- [ ] 関数の戻り値の型を明示している（`void` を含む）
- [ ] 引数が多い関数では名前付きパラメータを使い、呼び出し側の可読性を確保している
- [ ] `required` を名前付きの必須パラメータに正しく付けている
- [ ] 既定値はコンパイル時定数にしている
- [ ] コレクション操作のコールバックで冗長な型注釈を書きすぎていない
- [ ] クロージャが意図せず外側の可変状態を共有していないか確認した
- [ ] 高階関数と通常の `for` ループのどちらが可読性・意図の伝達に適するか検討した
- [ ] 関数合成・カリー化を使う場合、呼び出し側の可読性を損なっていないか確認した
