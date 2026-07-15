# 言語基礎（型・変数・文字列・演算子・クリーンコード）

## 概要

このリファレンスは、Dart言語の最も基礎的な構成要素（型システム、変数と定数、型推論、文字列、数値、論理演算、演算子、コメント、クリーンコードの慣行）を扱う。developing-dart の INSTRUCTIONS.md から「型・変数を理解し安全なコードを書きたい」タスクでルーティングされる想定であり、関数やクラスなどのより高度な構成要素は別リファレンス（FUNCTIONS-AND-FP.md、OOP-AND-CLASSES.md 等）が担当する。

## 型システム概要

Dartは静的型付け言語であり、sound null safety（健全なnull安全性）を前提とする。コンパイル時にすべての式の型が確定し、`null` を許容しない型に `null` を代入するとコンパイルエラーになる。

Dartの基本型は以下の通り。

| 型 | 用途 | 例 |
|---|---|---|
| `int` | 整数 | `42` |
| `double` | 浮動小数点数 | `3.14` |
| `num` | `int`/`double` の共通スーパー型 | `num n = 1;` |
| `String` | 文字列 | `'hello'` |
| `bool` | 真偽値 | `true` |
| `List<T>` | 順序付きコレクション | `[1, 2, 3]` |
| `Set<T>` | 重複のないコレクション | `{1, 2, 3}` |
| `Map<K, V>` | キーと値のペア | `{'a': 1}` |
| `Object` / `Object?` | すべての非null型のルート／null許容ルート | — |
| `dynamic` | 型チェックを実行時まで先送りする型 | — |
| `void` | 戻り値がないことを示す | — |
| `Never` | 決して正常終了しない式（`throw` 式等） | — |

`Object` と `dynamic` は似て見えるが役割が異なる。`Object?` は「あらゆる値を保持できるが、メンバー呼び出し前に型を確定させる必要がある」型で、静的解析の恩恵を受けられる。`dynamic` は静的型チェックを無効化するため、型安全性が必要な設計では避け、外部データのデコード直後など型が未確定な限られた場面に留める。

```dart
Object safeValue = 'hello';
// safeValue.length; // コンパイルエラー: Object に length は無い

dynamic riskyValue = 'hello';
riskyValue.length; // コンパイルは通るが実行時までチェックされない
```

## 変数と定数

Dartには3種類の変数宣言があり、意味が異なる。

| キーワード | 意味 | 値の決定時点 | 再代入 |
|---|---|---|---|
| `var` | 型推論される可変変数 | 実行時 | 可 |
| `final` | 一度だけ代入できる変数 | 実行時（初回代入時） | 不可 |
| `const` | コンパイル時定数 | コンパイル時 | 不可 |

```dart
var counter = 0;
counter = counter + 1; // OK

final userId = fetchCurrentUserId(); // 実行時に決まる値でもよい
// userId = 'other-id'; // コンパイルエラー

const maxRetryCount = 3; // コンパイル時に値が確定していなければならない
const timeout = Duration(seconds: 30); // const コンストラクタなら複合値もOK
```

**判断基準:**

| 状況 | 推奨 |
|---|---|
| 値がコンパイル時に決まる（リテラル、他の `const`） | `const` |
| 値は実行時に決まるが再代入しない | `final` |
| 値を後から変更する必要がある | `var` |

クリーンコードの原則として、再代入が不要な変数は既定で `final` にし、可変にする必要が生じた箇所だけ `var` を選ぶ。これにより意図しない再代入をコンパイル時に検出できる。

## 型推論と型安全

Dartの型推論は、初期化式から変数の型を決定する。`var` や `final` を使っても型は静的に確定しており、後から別の型を代入することはできない。

```dart
var name = 'Alice'; // String と推論される
// name = 42; // コンパイルエラー: int は String に代入できない

final items = <int>[]; // List<int> と推論される
items.add(1);
// items.add('two'); // コンパイルエラー
```

### null安全性

型名の末尾に `?` を付けない限り、その型は non-nullable（null非許容）である。null許容にしたい変数には明示的に `?` を付ける。

```dart
String nonNullable = 'value';
String? nullable = fetchOptionalValue(); // null になり得る

// null許容値をnon-nullableへ渡す前に絞り込みが必要
if (nullable != null) {
  print(nullable.length); // このスコープ内では String として扱われる
}

// null合体演算子で既定値を与える
final resolved = nullable ?? 'default';

// null非許容だが後から初期化されると保証される場合
late String configuredAtStartup;
```

`late` は「宣言時点では初期化しないが、使用前に必ず値が入る」ことをプログラマが保証する場合に使う。保証が誤っていると、未初期化アクセス時に実行時エラーになる。詳細（`late` の応用パターン、`!` によるnullチェック演算子の是非）は ADVANCED-TYPES.md を参照する。

**判断基準:**

| 状況 | 推奨 |
|---|---|
| 値が常に存在する | non-nullable型（既定） |
| 値が存在しない場合がある | `?` を付けたnullable型 |
| 初期化を遅延させたいが使用時には必ず値がある | `late` |
| 外部APIの戻り値が未確定 | まず `?` で受け、早期に絞り込む |

## 文字列の扱い

Dartの `String` はUTF-16コードユニットの列であり、シングルクォートとダブルクォートのどちらでも記述できる（プロジェクト内では統一する）。

```dart
final greeting = 'Hello';
final name = 'World';

// 文字列補間（式展開）
final message = '$greeting, $name!'; // 単純な式は $ のみ
final upperMessage = '${greeting.toUpperCase()}, $name!'; // 式には {} が必要

// 複数行文字列
const multiline = '''
1行目
2行目
''';

// raw文字列（エスケープを無効化）
final path = r'C:\Users\name';

// StringBuffer による効率的な連結（ループ内での + 連結を避ける）
final buffer = StringBuffer();
for (final word in ['a', 'b', 'c']) {
  buffer.write(word);
  buffer.write(' ');
}
final joined = buffer.toString().trim();
```

**判断基準:**

| 状況 | 推奨 |
|---|---|
| 単純な結合・埋め込み | 文字列補間 `$variable` / `${expr}` |
| ループ内で多数の断片を連結する | `StringBuffer` |
| バックスラッシュを多用する文字列（正規表現、Windowsパス等） | raw文字列 `r'...'` |
| 複数行の固定テキスト | 三重クォート `'''...'''` |

ループ内で `+=` により文字列を連結すると、そのたびに新しい文字列オブジェクトが生成されコピーコストがかかる。件数が多い場合は `StringBuffer` を使う。

## 数値と算術演算

`int` と `double` はいずれも `num` のサブタイプであり、算術演算子は両者に共通して使える。

```dart
const a = 10;
const b = 3;

print(a + b); // 13
print(a - b); // 7
print(a * b); // 30
print(a / b); // 3.3333333333333335 （常に double を返す）
print(a ~/ b); // 3 （整数除算）
print(a % b); // 1 （剰余）

// 複合代入演算子
var counter = 0;
counter += 1;
counter *= 2;

// インクリメント・デクリメント
var i = 0;
i++;
++i;
```

`/` 演算子は `int` 同士でも常に `double` を返す点に注意する。整数の商が必要な場合は `~/`（整数除算）を使う。

数値の変換は明示的に行う。

```dart
final parsed = int.parse('42'); // String -> int（失敗時は例外）
final maybeParsed = int.tryParse('abc'); // 失敗時は null
final asDouble = 42.toDouble();
final asString = 42.toString();
final fixed = 3.14159.toStringAsFixed(2); // '3.14'
```

外部入力（フォーム入力、APIレスポンス）を数値に変換する際は、例外を投げる `parse` ではなく `null` を返す `tryParse` を使い、失敗時のフォールバックを明示する。

## 論理演算と比較

```dart
final isAdult = age >= 18;
final canVote = isAdult && hasCitizenship;
final needsReview = !isApproved || hasFlag;

// 短絡評価（short-circuit）: 右辺は必要な場合のみ評価される
final isValid = user != null && user.isActive;

// 三項演算子
final label = isValid ? '有効' : '無効';

// null許容bool向けの明示的比較
bool? maybeFlag;
if (maybeFlag == true) {
  // maybeFlag が null でも false でもない場合のみ通る
}
```

`&&` と `||` は短絡評価されるため、左辺が結果を確定させる場合は右辺は評価されない。この性質を利用して、null チェックと後続アクセスを1つの式にまとめられる（`user != null && user.isActive`）。

`bool?`（null許容の真偽値）を `if` 文の条件に直接使うことはできない。`== true` のように明示的に比較するか、`??` で既定値を与えてから判定する。

## 演算子の全体像

| 分類 | 演算子 | 備考 |
|---|---|---|
| 算術 | `+` `-` `*` `/` `~/` `%` | `/` は常に `double` を返す |
| 比較 | `==` `!=` `>` `<` `>=` `<=` | `==` は値の等価性（`identical()` は参照の等価性） |
| 論理 | `&&` `\|\|` `!` | 短絡評価 |
| 代入 | `=` `+=` `-=` `*=` `??=` | `??=` は左辺が `null` の場合のみ代入 |
| null関連 | `??` `?.` `!` | 後述 |
| 型テスト | `is` `is!` `as` | 型判定とキャスト |
| カスケード | `..` `?..` | 同一オブジェクトへの連続操作 |
| スプレッド | `...` `...?` | コレクションリテラル内での展開 |

```dart
// null関連演算子
final length = nullableString?.length; // null なら null を返す（null許容伝播）
final safeLength = nullableString?.length ?? 0; // null なら 0

config.timeout ??= const Duration(seconds: 10); // 未設定時のみ既定値を設定

// カスケード記法: 同一オブジェクトへの一連の操作をまとめる
final buffer = StringBuffer()
  ..write('a')
  ..write('b')
  ..write('c');

// is / as による型テストとキャスト
void handle(Object value) {
  if (value is String) {
    print(value.toUpperCase()); // このブロック内では String に絞り込まれる
  }
}
```

`!`（null非許容キャスト演算子）は「この値はnullではないはずだ」と型システムに強制的に伝える演算子であり、実際にnullだった場合は実行時例外になる。安易な多用は null safety の利点を損なうため、`??`・`?.`・早期の絞り込みで代替できないかを先に検討する。

## コメントとドキュメント

```dart
// 単一行コメント。実装意図や非自明な理由を書く。

/*
 複数行コメント。
 大きなブロックの一時的な無効化等に使う。
*/

/// ドキュメンテーションコメント（dartdoc対応）。
/// 最初の1行が要約として扱われる。
///
/// 詳細な説明はここに続ける。[関連するクラスやメンバー]は
/// 角括弧で囲むと dartdoc がリンクとして解決する。
int add(int a, int b) => a + b;
```

**判断基準:**

| コメントの種類 | 用途 |
|---|---|
| `//` | 実装の意図、一時的なメモ、非自明な理由の説明 |
| `///` | 公開API（ライブラリ、パッケージ、共有モジュール）のドキュメント |
| コメントなし | 命名やコードの構造だけで意図が読み取れる場合 |

コード自体から読み取れる「何をしているか」を説明するコメントは避け、「なぜそうしているか」「一見不自然に見える理由」を記録する。公開APIには `///` でドキュメンテーションコメントを付け、`dart doc` での生成や IDE のホバー表示に対応させる。

## クリーンコードのベストプラクティス

- 変数・関数はキャメルケース、クラス・型・enumはパスカルケース、定数もキャメルケース（`maxRetryCount` であり `MAX_RETRY_COUNT` ではない）で命名する。
- 再代入しない変数は `var` ではなく `final`／`const` を既定にする。
- 型が自明な場面（右辺を見れば型が明らかな場合）では型注釈を省略して型推論に任せ、公開APIのシグネチャ（関数の引数・戻り値）には明示的な型を書く。
- 1つの変数・関数に1つの責務を持たせ、無関係な処理を1つの式に詰め込まない。
- マジックナンバー・マジックストリングは名前付きの `const` として抽出する。
- `dynamic` は型が本当に不定な場合（JSONデコード直後等）に限定し、確定後は速やかに具体的な型へ絞り込む。
- null許容型を安易に増やさず、「値が本当に存在しないことがあるか」を都度検討する。

```dart
// 避ける: マジックナンバーと不明瞭な命名
if (n > 3) {
  retry(n);
}

// 推奨: 意図が読み取れる命名と定数化
const maxRetryCount = 3;

if (attemptCount > maxRetryCount) {
  retry(attemptCount);
}
```

## チェックリスト

- [ ] 再代入しない値は `final`／`const` を使っている
- [ ] コンパイル時に値が確定する定数は `const` にしている
- [ ] null許容が必要な箇所にだけ `?` を付けている
- [ ] `dynamic` の使用箇所を最小限に絞り、確定後は具体的な型へ絞り込んでいる
- [ ] 数値変換は `tryParse` 等でエラー処理を明示している
- [ ] ループ内の文字列連結に `StringBuffer` を使っている（件数が多い場合）
- [ ] `!`（null非許容キャスト）を多用せず `??`／`?.`／絞り込みで代替できないか検討した
- [ ] 命名規則（キャメルケース／パスカルケース）に従っている
- [ ] マジックナンバー・マジックストリングを名前付き定数に抽出している
- [ ] 公開APIには `///` ドキュメンテーションコメントを付けている
