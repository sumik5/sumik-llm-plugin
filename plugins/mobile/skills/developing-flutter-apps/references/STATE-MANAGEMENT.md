# 状態管理

## 概要

このリファレンスは Flutter アプリにおける状態管理の選択肢（`setState` / Provider / Riverpod / BLoC・Cubit / Redux / GetX）と、それぞれの適用場面・実装パターンを扱う。状態管理はアーキテクチャ全体の設計判断に直結するため、選択の分岐では推測せずユーザー確認を行う（本リファレンス末尾「ユーザー確認の原則」を参照）。レイヤ分離を含むアーキテクチャ全体の設計は ARCHITECTURE-PATTERNS.md を参照する。

## 状態の分類

状態管理ソリューションを選ぶ前に、扱う状態がどちらの種類かを見極める。

| 種類 | 説明 | 例 |
|---|---|---|
| ローカル状態（ephemeral state） | 単一のウィジェットとその近傍だけが関心を持つ、短命な状態 | テキストフィールドの入力途中の値、アニメーションの進行度、タブの選択状態 |
| アプリ状態（app state） | 複数の画面・複数のウィジェットツリーにまたがって共有される状態 | ログインユーザー情報、カートの中身、テーマ設定、フィード一覧 |

ローカル状態は多くの場合 `setState` で十分であり、わざわざ外部ライブラリに載せる必要はない。以降の Provider / Riverpod / BLoC / Redux / GetX はアプリ状態の共有・伝播をどう構造化するかの選択肢である。

## 1. setState

`StatefulWidget` に閉じた最小の状態管理。外部パッケージが不要で、学習コストも最も低い。

```dart
class LikeButton extends StatefulWidget {
  const LikeButton({super.key});

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> {
  bool _liked = false;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(_liked ? Icons.favorite : Icons.favorite_border),
      onPressed: () => setState(() => _liked = !_liked),
    );
  }
}
```

`setState` は状態を持つウィジェットのサブツリーしか再構築できない。祖先や兄弟ウィジェットと状態を共有したくなった時点が、他の手法へ移行する合図になる。

## 2. Provider

`InheritedWidget` を薄くラップし、`ChangeNotifier` ベースのモデルを widget tree に流し込む。導入が容易でエコシステムも大きく、中規模アプリの定番。

```dart
class CartModel extends ChangeNotifier {
  final List<String> _items = [];

  List<String> get items => List.unmodifiable(_items);

  void add(String item) {
    _items.add(item);
    notifyListeners();
  }
}

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => CartModel(),
      child: const App(),
    ),
  );
}

class CartBadge extends StatelessWidget {
  const CartBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final itemCount = context.watch<CartModel>().items.length;
    return Badge(label: Text('$itemCount'), child: const Icon(Icons.shopping_cart));
  }
}

class AddToCartButton extends StatelessWidget {
  const AddToCartButton({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => context.read<CartModel>().add(itemId),
      child: const Text('Add to cart'),
    );
  }
}
```

`context.watch<T>()` は値の変化を購読して再構築する。`context.read<T>()` は購読せず一度だけ値を取得するため、`onPressed` のようなコールバック内で使う。両者の使い分けを誤ると不要な再構築や、逆に更新されない UI につながる。

## 3. Riverpod

Provider の後継として同じ作者が設計した、コンパイル時に安全なプロバイダベースの状態管理。`BuildContext` に依存せずどこからでもプロバイダを参照でき、テストや依存関係の差し替えがしやすい。

```dart
final counterProvider = NotifierProvider<CounterNotifier, int>(CounterNotifier.new);

class CounterNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;
}

void main() {
  runApp(const ProviderScope(child: App()));
}

class CounterText extends ConsumerWidget {
  const CounterText({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(counterProvider);
    return Text('Count: $count');
  }
}

class IncrementButton extends ConsumerWidget {
  const IncrementButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: () => ref.read(counterProvider.notifier).increment(),
      child: const Text('Increment'),
    );
  }
}
```

非同期データを扱う場合は `FutureProvider` や `AsyncNotifier` を使い、`AsyncValue` の `when`/`switch` パターンで loading・error・data を網羅的に扱う。

```dart
final userProvider = FutureProvider<User>((ref) async {
  final repository = ref.watch(userRepositoryProvider);
  return repository.fetchCurrentUser();
});

class UserView extends ConsumerWidget {
  const UserView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider);
    return userAsync.when(
      data: (user) => Text(user.name),
      loading: () => const CircularProgressIndicator(),
      error: (error, stackTrace) => Text('Error: $error'),
    );
  }
}
```

`riverpod_generator` を使う `@riverpod` アノテーション形式もあるが、いずれも `Notifier`/`AsyncNotifier` を中心とした考え方は共通する。

## 4. BLoC / Cubit

`bloc` / `flutter_bloc` パッケージが提供する、イベント駆動でリアクティブな状態管理。ビジネスロジックを UI から明確に分離し、大規模チーム開発やテスト容易性を重視するプロジェクトで採用されることが多い。

`Cubit` はイベントを持たずメソッド呼び出しで状態遷移する軽量版、`Bloc` はイベントをストリームとして受け取り `on<Event>` ハンドラで状態遷移を記述する。

```dart
// Cubit: メソッド呼び出しでシンプルに状態を変える
class CounterCubit extends Cubit<int> {
  CounterCubit() : super(0);

  void increment() => emit(state + 1);
  void decrement() => emit(state - 1);
}

// Bloc: イベントを介して状態遷移を宣言的に記述する
sealed class CounterEvent {}

final class Incremented extends CounterEvent {}

final class Decremented extends CounterEvent {}

class CounterBloc extends Bloc<CounterEvent, int> {
  CounterBloc() : super(0) {
    on<Incremented>((event, emit) => emit(state + 1));
    on<Decremented>((event, emit) => emit(state - 1));
  }
}

class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CounterBloc(),
      child: Scaffold(
        body: BlocBuilder<CounterBloc, int>(
          builder: (context, count) => Center(child: Text('$count')),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => context.read<CounterBloc>().add(Incremented()),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
```

非同期処理や副作用のログ出力には `BlocListener`（再構築せず副作用のみ実行）を、状態遷移とウィジェット再構築を両方行いたい場合は `BlocConsumer` を使う。

## 5. Redux

`redux` / `flutter_redux` パッケージによる単一方向データフロー。単一の Store・Action・Reducer で状態を一元管理し、状態変化の履歴を追いやすい（time-travel debugging）。Web フロントエンドの Redux に馴染みのあるチームに向く。

```dart
// Action
class Increment {
  const Increment();
}

// Reducer（純粋関数。状態は不変に保つ）
int counterReducer(int state, dynamic action) {
  if (action is Increment) return state + 1;
  return state;
}

void main() {
  final store = Store<int>(counterReducer, initialState: 0);
  runApp(StoreProvider<int>(store: store, child: const App()));
}

class CounterText extends StatelessWidget {
  const CounterText({super.key});

  @override
  Widget build(BuildContext context) {
    return StoreConnector<int, int>(
      converter: (store) => store.state,
      builder: (context, count) => Text('Count: $count'),
    );
  }
}

class IncrementButton extends StatelessWidget {
  const IncrementButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => StoreProvider.of<int>(context).dispatch(const Increment()),
      child: const Text('Increment'),
    );
  }
}
```

Reducer は副作用を持たない純粋関数として書く。非同期処理や API 呼び出しなどの副作用は `redux_thunk`・`redux_epics` のようなミドルウェアに切り出す。

## 6. GetX

状態管理・ルーティング・依存性注入を1つのパッケージで提供する軽量ソリューション。ボイラープレートが少なく学習コストが低い一方、`BuildContext` に依存しないグローバルアクセスが暗黙的な依存関係を生みやすい点に留意する。

```dart
class CounterController extends GetxController {
  final count = 0.obs;

  void increment() => count.value++;
}

class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(CounterController());
    return Scaffold(
      body: Center(
        child: Obx(() => Text('Count: ${controller.count.value}')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: controller.increment,
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

`.obs` で監視可能な値にし、`Obx` でその値を参照するウィジェットだけを局所的に再構築する。`Get.put`/`Get.find` によるサービスロケーターパターンで依存性注入とルーティング（`Get.to()` 等）も統一的に扱える。

## 比較表

| ソリューション | 学習コスト | ボイラープレート | テスト容易性 | 主な採用理由 |
|---|---|---|---|---|
| setState | 最小 | 最小 | 低（ウィジェット単位のテストのみ） | ローカル状態のみで完結する小規模な部品 |
| Provider | 低 | 低〜中 | 中 | 中規模アプリの定番、既存 `ChangeNotifier` 資産の活用 |
| Riverpod | 中 | 低〜中 | 高（`BuildContext` 非依存でモック差し替えが容易） | 型安全性・テスト容易性を重視する中〜大規模アプリ |
| BLoC / Cubit | 中〜高 | 中〜高 | 高（入出力がイベント/状態で明確） | 大規模チーム開発、業務ロジックとUIの厳格な分離 |
| Redux | 中〜高 | 高 | 高（純粋関数のReducerが単体テストしやすい） | Web版Reduxとの知見共有、単一方向データフローの一貫性 |
| GetX | 低 | 最小 | 低〜中（グローバル状態がテストの独立性を損ないやすい） | プロトタイピング・少人数開発でのスピード重視 |

## ユーザー確認の原則（AskUserQuestion）

**判断分岐がある場合、推測で進めずAskUserQuestionで確認する。**

確認すべき場面:
- 新規プロジェクトや新規機能で状態管理ソリューションが未選定のとき（既存コードに `provider`/`flutter_riverpod`/`flutter_bloc`/`redux`/`get` のいずれかが pubspec.yaml に存在する場合は、それに従うため確認不要）
- 選択肢: setState / Provider / Riverpod / BLoC(Cubit) / Redux / GetX

確認不要な場面:
- pubspec.yaml に既存の状態管理パッケージが1つだけ入っている場合（それに従う）
- 単一ウィジェットに閉じたローカル状態（アニメーション進行度、フォーム入力途中の値など）は setState で確定でよい
- null safety の採用（Dart 3.x では必須）

## チェックリスト

- [ ] 扱う状態がローカル状態かアプリ状態かを見極めた
- [ ] 状態管理ソリューションが未選定の場合は AskUserQuestion で確認した（既存プロジェクトでは既存パッケージに従った）
- [ ] Provider/Riverpodでは `watch`（購読・再構築）と `read`（一度だけ取得）を適切に使い分けた
- [ ] 非同期状態は loading/error/data を網羅的に扱っている（Riverpod の `AsyncValue`、BLoCの状態クラス設計など）
- [ ] Reducer・Notifier・Bloc のロジック本体はテスト可能な純粋ロジックとしてUIから分離した
