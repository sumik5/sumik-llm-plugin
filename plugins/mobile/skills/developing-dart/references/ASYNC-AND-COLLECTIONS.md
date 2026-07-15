# 非同期処理とコレクション

## 概要

本ファイルは `Future`・`async`/`await`・`Stream`・`Isolate` による非同期処理と、`List`/`Set`/`Map`・`Iterable` によるコレクション操作を扱う。クラス設計は [OOP-AND-CLASSES.md](OOP-AND-CLASSES.md)、null safety は [ADVANCED-TYPES.md](ADVANCED-TYPES.md) を参照。Dart は**シングルスレッドのイベントループ**で非同期処理を行う言語であり、この前提を理解しないまま並行処理を書くとデッドロックやレースコンディションではなく「意図しない実行順序」につまずくことが多い。

## Future と async/await

`Future<T>` は「将来のある時点で値 `T`（または例外）が得られる」ことを表す型。`async` 修飾された関数は常に `Future` を返し、内部で `await` を使うと `Future` が解決されるまで**その関数の実行だけ**を一時停止する（他のコードの実行はブロックしない）。

```dart
Future<String> fetchUserName(String id) async {
  await Future.delayed(const Duration(milliseconds: 300)); // ネットワーク呼び出しの想定
  return 'user-$id';
}

Future<void> main() async {
  final name = await fetchUserName('42');
  print(name);
}
```

- `async` 関数の戻り値は自動的に `Future` でラップされる（`Future<void>` の関数から素の `void` 相当の値を返しても問題ない）。
- `try`/`catch` は同期コードと同じ書き方で非同期の例外を捕捉できる（`await` された `Future` が reject されると、その場で例外として送出される）。

```dart
Future<void> loadSafely() async {
  try {
    final name = await fetchUserName('42');
    print(name);
  } on TimeoutException {
    print('タイムアウトしました');
  } catch (e) {
    print('取得失敗: $e');
  }
}
```

### 複数の Future を組み合わせる

| API | 挙動 | 用途 |
|---|---|---|
| `Future.wait([f1, f2])` | 全て完了するまで待ち、結果を `List` で返す（1 つでも失敗すると即座に失敗） | 並行実行可能な独立したリクエストをまとめて待つ |
| `Future.any([f1, f2])` | 最初に完了したものの結果を返す | タイムアウト実装・複数ソースからの早い者勝ち取得 |
| `.then(...)` | コールバックスタイルでの継続処理 | `await` を使えない/使いたくない場面 |
| `Completer<T>` | コールバックベース API を手動で `Future` 化する | レガシー API のラップ |

```dart
Future<void> loadDashboard() async {
  final results = await Future.wait([
    fetchUserName('1'),
    fetchUserName('2'),
  ]);
  print(results); // [user-1, user-2]
}
```

```dart
Future<int> legacyCallbackToFuture() {
  final completer = Completer<int>();
  Timer(const Duration(milliseconds: 100), () => completer.complete(42));
  return completer.future;
}
```

## Stream

`Stream<T>` は時間経過とともに複数の値を非同期に送出する連続的なデータ源（`Future` の複数版）。`await for` で購読するか、`listen` でコールバック登録する。

```dart
Stream<int> countUpTo(int max) async* {
  for (var i = 1; i <= max; i++) {
    await Future.delayed(const Duration(milliseconds: 100));
    yield i; // Stream 版の return（値を1つ送出して継続）
  }
}

Future<void> main() async {
  await for (final value in countUpTo(3)) {
    print(value);
  }
}
```

| 種類 | 購読者数 | 典型用途 |
|---|---|---|
| single-subscription stream | 1 つのみ（2 回目の `listen` は例外） | ファイル読み込み・HTTP レスポンスボディ |
| broadcast stream | 0〜複数（後から購読しても以降のイベントのみ届く） | UI イベント・複数箇所で購読する通知 |

```dart
final controller = StreamController<String>.broadcast();

controller.stream.listen((event) => print('listener A: $event'));
controller.stream.listen((event) => print('listener B: $event'));
controller.add('hello');
await controller.close(); // 購読者・リソースを明示的に解放する
```

- `listen` が返す `StreamSubscription` は必ず保持し、不要になったら `cancel()` する（`Widget` の `dispose` や `Bloc`/`Cubit` の破棄処理などライフサイクルの終端で解放するのが定石）。
- `Stream` の `map`/`where`/`transform` は `Iterable` と同じ感覚で非同期データの変換パイプラインを組める。

## Isolate

Dart はシングルスレッドのイベントループで動くため、CPU バウンドな重い処理（大量データのパース・画像処理等）を直接実行するとイベントループをブロックし UI やタイマーコールバックが止まる。`Isolate` は独立したメモリ空間とイベントループを持つ実行単位で、メッセージパッシングでのみ相互作用する（メモリ共有なし）。

```dart
Future<int> heavyComputationOffMainIsolate(int n) {
  return Isolate.run(() {
    var sum = 0;
    for (var i = 0; i < n; i++) {
      sum += i;
    }
    return sum;
  });
}
```

| 判断基準 | Isolate を使う | Future/async のままでよい |
|---|---|---|
| CPU バウンドで数十ミリ秒以上ブロックする処理か | はい | I/O 待ちが主体ならこちら（await だけで十分） |
| 単発の重い計算を隔離したいだけか | `Isolate.run(...)`（Dart 2.19+・簡潔） | — |
| 長期間常駐して継続的にメッセージをやり取りするワーカーが必要か | `Isolate.spawn` + `SendPort`/`ReceivePort` | — |

- I/O 待ち（ネットワーク・ファイル）は Isolate を使わなくても `await` だけでイベントループをブロックしない。Isolate が必要なのは純粋な計算負荷が高い場合。

## Stream のエラーハンドリング

`Stream` は値だけでなくエラーイベントも送出できる。`await for` 内では通常の `try`/`catch` で捕捉できるが、`listen` を使う場合は `onError` コールバックを明示的に登録しないとエラーが握りつぶされずに未処理例外として伝播する。

```dart
controller.stream.listen(
  (event) => print('data: $event'),
  onError: (Object error, StackTrace stackTrace) {
    print('stream error: $error');
  },
  onDone: () => print('completed'),
);
```

```dart
Future<void> consume(Stream<int> source) async {
  try {
    await for (final value in source) {
      print(value);
    }
  } catch (e) {
    print('エラーを捕捉: $e');
  }
}
```

- `Stream.handleError`/`Stream.transform` でエラー変換パイプラインを組める。エラーを握りつぶす（何もしない `onError`）実装は、障害の発見を遅らせるため避ける。

## List・Set・Map

| 型 | 特徴 | 主な用途 |
|---|---|---|
| `List<T>` | 順序あり・重複可 | 一般的な配列的コレクション |
| `Set<T>` | 順序保証なし（`LinkedHashSet` 相当で挿入順を保つ既定実装）・重複不可 | 一意な値の集合・所属判定の高速化 |
| `Map<K, V>` | キーと値の対応 | 辞書・インデックス構造 |

```dart
final numbers = <int>[1, 2, 3];
final uniqueTags = <String>{'dart', 'flutter', 'dart'}; // 'dart' は1つに集約される
final ages = <String, int>{'Aiko': 28, 'Taro': 31};

final growableList = List<int>.generate(5, (i) => i * i); // [0, 1, 4, 9, 16]
final fixedLengthList = List<int>.filled(3, 0, growable: false);
```

- `List.generate`/`List.filled` は初期値を持つコレクションを簡潔に作る。`growable: false` を付けると要素数固定のリストになり、`add`/`remove` が例外になる。
- `Map` のキー参照は `map['missing']` が `null` を返す（`Map<K, V>` の値型が非 null でも、存在しないキーへのアクセスは `V?` を返す）。存在確認には `containsKey` か `putIfAbsent` を使う。

```dart
final counters = <String, int>{};
counters.update('visits', (value) => value + 1, ifAbsent: () => 1);
```

## 不変コレクション

Dart には共有メモリ上のスレッドが存在しない（並行処理は Isolate 間のメッセージパッシングのみ）ため、複数スレッドからの同時書き込みという意味での「スレッドセーフ」は言語レベルでは問題にならない。代わりに重要なのは、意図しない書き換えを防ぐための**不変性**。

```dart
final immutableList = List<int>.unmodifiable([1, 2, 3]);
immutableList.add(4); // 実行時に UnsupportedError

const constList = [1, 2, 3]; // コンパイル時定数（さらに強い不変性）
```

| API | 不変性の強さ | 適用時点 |
|---|---|---|
| `const [...]` | コンパイル時定数。参照も内容も変更不可 | コンパイル時 |
| `List.unmodifiable(...)` | 実行時に変更禁止のビューを作る | 実行時（元データのコピー） |
| `UnmodifiableListView(list)` | 元の `list` への変更不可なビュー（元データ変更は透過） | 実行時（コピーなし） |

- API の戻り値として内部状態の `List`/`Map` をそのまま返すと、呼び出し側が誤って変更できてしまう。外部に公開するコレクションは `List.unmodifiable(...)` でラップするか、`Iterable` 型として返す（変更系メソッドを持たないインターフェースで公開する）と安全。

## コレクションリテラルと spread 演算子

```dart
final base = [1, 2, 3];
final extended = [0, ...base, 4]; // spread: base の要素を展開して挿入
final maybeExtended = [0, if (base.isNotEmpty) ...base, 4]; // collection if
final doubled = [for (final n in base) n * 2]; // collection for
```

- `...`（spread）はコレクションリテラル内で別のコレクションを展開する。null 許容のコレクションを安全に展開するには `...?` を使う。
- collection `if`/`for` により、条件分岐やループのためだけに一時変数や `addAll` を書く必要がなくなる。

## Iterable と where/map/reduce

`Iterable<T>` は `List`/`Set` 等が実装する共通インターフェースで、遅延評価の関数型スタイル変換メソッド群を提供する。

```dart
final orders = [12.5, 40.0, 8.25, 100.0];

final highValueTotal = orders
    .where((price) => price > 10) // 条件で絞り込む（遅延評価）
    .map((price) => price * 1.1) // 税込みに変換
    .fold<double>(0, (sum, price) => sum + price); // 初期値付きで畳み込む

final maxOrder = orders.reduce((a, b) => a > b ? a : b); // 初期値なし版の畳み込み
```

| メソッド | 戻り値 | 空リストでの挙動 |
|---|---|---|
| `map` | 変換後の `Iterable` | 空の `Iterable` |
| `where` | 条件を満たす要素の `Iterable` | 空の `Iterable` |
| `reduce` | 単一の値 | `StateError` を送出（初期値が無いため） |
| `fold` | 単一の値 | 初期値をそのまま返す（安全） |
| `expand` | 各要素を 0〜複数件に展開して平坦化した `Iterable` | 空の `Iterable` |

- `where`/`map` は**遅延評価**（lazy）。`toList()` や `for-in` で実際に走査するまで処理は実行されない。中間結果のリストを作らずに済むため、大きなコレクションのパイプラインでメモリ効率が良い。
- 要素が 1 件も無い可能性がある場合の集約には `reduce` ではなく `fold`（初期値を渡せる）を使い、`StateError` を避ける。

## チェックリスト

- [ ] `async` 関数内の例外を `try`/`catch` で適切に捕捉しているか
- [ ] 独立した非同期処理を `await` を連続させて直列化していないか（`Future.wait` で並行化できないか検討したか）
- [ ] `StreamSubscription` をライフサイクル終了時に `cancel()` しているか
- [ ] broadcast/single-subscription のどちらが必要な用途か区別して `StreamController` を選んだか
- [ ] CPU バウンドな重い処理をメインの Isolate でブロッキング実行していないか
- [ ] 要素が空の可能性がある集約で `reduce` ではなく `fold` を使っているか
- [ ] `where`/`map` の遅延評価を理解した上でパイプラインを組んでいるか
