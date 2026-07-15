# Widget・レイアウト・テーマ

## 概要

このリファレンスは、Flutter の UI 構築の土台となる Widget モデル、レイアウトシステム、テーマ、アニメーションを扱う。developing-flutter-apps 本体のうち「画面をどう組み立てるか」を担当する部分であり、状態管理の詳細は [STATE-MANAGEMENT.md](STATE-MANAGEMENT.md)、ナビゲーションは NAVIGATION-ROUTING.md を参照する。

## Widget モデルの基本

Flutter では画面を構成するあらゆる要素が Widget である。Widget は不変（immutable）な設定オブジェクトであり、実際の描画は Flutter エンジンが Widget ツリーから Element ツリー・RenderObject ツリーを構築して行う。アプリ開発者が直接触るのは Widget ツリーの宣言だけでよい。

Widget は大きく2種類に分かれる。

| 種類 | 特徴 | 典型例 |
|---|---|---|
| StatelessWidget | 一度構築されたら再構築されるまで見た目が変わらない。内部に可変状態を持たない | アイコン、ラベル、静的なカード |
| StatefulWidget | `State` オブジェクトに可変状態を持ち、`setState` で再構築をスケジュールできる | 入力フォーム、トグル、カウンタ |

```dart
class Greeting extends StatelessWidget {
  const Greeting({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Text('Hello, $name!');
  }
}

class Counter extends StatefulWidget {
  const Counter({super.key});

  @override
  State<Counter> createState() => _CounterState();
}

class _CounterState extends State<Counter> {
  int _count = 0;

  void _increment() {
    setState(() {
      _count++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Count: $_count'),
        ElevatedButton(
          onPressed: _increment,
          child: const Text('Increment'),
        ),
      ],
    );
  }
}
```

判断基準:

| 状態 | 選択 |
|---|---|
| 再構築の間ずっと同じ見た目・値のみで決まる | StatelessWidget |
| ウィジェット自身がライフサイクル内で値を保持し、UI を書き換える必要がある | StatefulWidget |
| 複数の画面・ウィジェットをまたいで共有する状態 | StatefulWidget の内部状態ではなく状態管理ソリューション（[STATE-MANAGEMENT.md](STATE-MANAGEMENT.md)）へ委譲する |

`const` コンストラクタを使えるウィジェットには必ず `const` を付ける。Flutter は同一の `const` ウィジェットインスタンスを再利用でき、不要な再構築を防げる。

## Widget ツリーと BuildContext

`BuildContext` は Widget ツリー内での自分の位置を表すハンドルであり、`build` メソッドの引数として渡される。`BuildContext` を通じて次のことができる。

- `Theme.of(context)` や `MediaQuery.of(context)` のように、祖先ウィジェットが `InheritedWidget` 経由で提供する値を参照する
- `Navigator.of(context)` でナビゲーションスタックを操作する
- `context.mounted` で非同期処理の再開時にウィジェットがまだツリーに存在するかを確認する（`async` の後に `BuildContext` を使う前に必ず確認する）

```dart
Future<void> _submit(BuildContext context) async {
  final result = await someAsyncCall();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Result: $result')),
  );
}
```

BuildContext をウィジェットの外（`State` のフィールドなど）に保存して後から使い回すことは避ける。ツリーが変化すると無効な参照になり得るため、必要な値はそのフレームの `build` 内、あるいは `context.mounted` を確認した直後に取得する。

## Material と Cupertino

Flutter はプラットフォームに依存しない描画エンジンを持つため、Android 風・iOS 風のどちらのデザイン言語も同じコードベースで利用できる。

| デザインシステム | 主なウィジェット | 使いどころ |
|---|---|---|
| Material（`package:flutter/material.dart`） | `MaterialApp`, `Scaffold`, `AppBar`, `ElevatedButton` | Android を含む大半のアプリの既定選択 |
| Cupertino（`package:flutter/cupertino.dart`） | `CupertinoApp`, `CupertinoPageScaffold`, `CupertinoButton` | iOS ライクな見た目を明示的に再現したい場合 |

```dart
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sample App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
```

判断基準（AskUserQuestion 不要・一義的に決まる領域）: 新規アプリでは特に理由がない限り Material 3（`useMaterial3: true`、既定）を採用し、iOS でも Material ウィジェットを使う。iOS ネイティブの見た目を厳密に再現する要件がある場合のみ Cupertino ウィジェットや `PlatformWidget` パターンで出し分ける。

## レイアウトウィジェット

### Row・Column・Stack

```dart
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: const [
    Icon(Icons.star),
    Text('Featured'),
    Icon(Icons.arrow_forward),
  ],
);

Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: const [
    Text('Title', style: TextStyle(fontWeight: FontWeight.bold)),
    Text('Subtitle'),
  ],
);

Stack(
  children: [
    Image.network('https://example.com/banner.jpg', fit: BoxFit.cover),
    const Positioned(
      left: 16,
      bottom: 16,
      child: Text(
        'Overlay caption',
        style: TextStyle(color: Colors.white),
      ),
    ),
  ],
);
```

| ウィジェット | 並べ方 | 主な用途 |
|---|---|---|
| `Row` | 水平方向に並べる | ツールバー、アイコン+ラベルの横並び |
| `Column` | 垂直方向に並べる | フォーム、カードの縦積み |
| `Stack` + `Positioned` | 重ねて配置する | 画像の上にラベルを重ねる、バッジ表示 |
| `ListView` | スクロール可能な一次元リスト | 可変長のリスト表示 |
| `GridView` | スクロール可能なグリッド | 画像ギャラリー、タイル UI |

### 制約（Constraints）モデル

Flutter のレイアウトは「制約は親から子へ下り、サイズは子から親へ上る」という一方向の流れで決まる（constraints go down, sizes go up, parent sets position）。子は親から渡された `BoxConstraints`（最小・最大の幅高さ）の範囲内で自分のサイズを決め、親はその結果を見て自分の中での子の位置を決める。

- `Expanded` / `Flexible` は `Row`/`Column` の中で残りスペースを分配する
- 無制限の制約（`Column` の中で `ListView` を単純に置く等）を渡すと `RenderFlex overflowed` のような例外が起きやすい。スクロール可能な子を `Expanded` で包むか `shrinkWrap: true` を検討する
- `SizedBox` で明示的にサイズを固定する、`ConstrainedBox` で最小・最大値を指定する、といった明示的な制約の付与で意図しない overflow を防ぐ

```dart
Column(
  children: [
    const Text('Header'),
    Expanded(
      child: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) => ListTile(
          title: Text(items[index]),
        ),
      ),
    ),
  ],
);
```

## Theme とスタイリング

`ThemeData` はアプリ全体で共有する色・タイポグラフィ・コンポーネントスタイルを定義する。個々のウィジェットへ直接 `TextStyle` や `Color` をハードコードするのではなく、`Theme.of(context)` 経由でテーマ値を参照することで、ダークモード対応やブランド変更に強い実装になる。

```dart
final theme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.indigo,
    brightness: Brightness.light,
  ),
  textTheme: const TextTheme(
    titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
    bodyMedium: TextStyle(fontSize: 14),
  ),
);

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleLarge);
  }
}
```

ライト・ダーク両テーマを用意する場合は `MaterialApp` に `theme` と `darkTheme`、`themeMode` を渡す。`ThemeExtension` を使うとブランド固有の独自トークン（例: 成功・警告色）もテーマシステムに統合できる。

| 要素 | 値 |
|---|---|
| アプリ共通の配色 | `ColorScheme.fromSeed` でシードカラーから自動生成する |
| ダークモード対応が必要 | `theme`/`darkTheme`/`themeMode` を分けて定義する |
| ブランド固有の独自プロパティ | `ThemeExtension` を定義してテーマに登録する |
| 個別ウィジェットだけ例外的な見た目 | ウィジェット直下でスタイルを上書きするが、乱用しない |

## アニメーション

### 暗黙的アニメーション（Implicit Animations）

値の変化を Flutter に任せるだけで滑らかな遷移が得られる。`AnimatedContainer` や `AnimatedOpacity` のように `Animated*` で始まるウィジェットは、プロパティの新しい値を渡すだけで自動的に補間する。

```dart
class ExpandableBox extends StatefulWidget {
  const ExpandableBox({super.key});

  @override
  State<ExpandableBox> createState() => _ExpandableBoxState();
}

class _ExpandableBoxState extends State<ExpandableBox> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        width: _expanded ? 200 : 100,
        height: _expanded ? 200 : 100,
        color: _expanded ? Colors.indigo : Colors.indigoAccent,
      ),
    );
  }
}
```

### 明示的アニメーション（Explicit Animations）

タイミングや繰り返し、複数プロパティの連動を細かく制御したい場合は `AnimationController` と `Tween` を組み合わせる。`AnimationController` は `TickerProvider`（`SingleTickerProviderStateMixin` 等）を必要とし、`dispose()` での解放が必須になる。

```dart
class PulsingIcon extends StatefulWidget {
  const PulsingIcon({super.key});

  @override
  State<PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat(reverse: true);

  late final Animation<double> _scale = Tween(begin: 0.8, end: 1.2).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: const Icon(Icons.favorite, color: Colors.red),
    );
  }
}
```

| 要件 | 選択 |
|---|---|
| 単一プロパティの単純な変化（サイズ・色・不透明度） | 暗黙的アニメーション（`Animated*` ウィジェット） |
| 複数プロパティの連動、繰り返し・逆再生、外部トリガーでの精密制御 | 明示的アニメーション（`AnimationController` + `Tween`） |
| ページ遷移のアニメーション | `Hero` ウィジェットや `PageRouteBuilder`（NAVIGATION-ROUTING.md を参照） |

`AnimationController` を使うクラスでは必ず `dispose()` をオーバーライドしてコントローラを破棄する。破棄を忘れるとリスナーが残り続けメモリリークの原因になる。

## チェックリスト

- [ ] 再構築されない静的な部分は `StatelessWidget` + `const` にした
- [ ] 状態を持つ部分は `StatefulWidget` に閉じ込め、共有が必要な状態だけ状態管理ソリューションへ切り出した
- [ ] `async` 処理の後で `BuildContext` を使う前に `context.mounted` を確認した
- [ ] レイアウトの overflow が起きないよう、スクロール領域は `Expanded` や `shrinkWrap` で制約を明示した
- [ ] 色・フォントは `ThemeData` 経由で参照し、ハードコードを避けた
- [ ] `AnimationController` を使う場合は `dispose()` で解放している
