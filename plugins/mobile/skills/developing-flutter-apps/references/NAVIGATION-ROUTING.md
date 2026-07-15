# ナビゲーションとルーティング

## 概要

このリファレンスは、Flutterアプリの画面遷移（Navigator 1.0の命令的ナビゲーション、Navigator 2.0/Router APIの宣言的ナビゲーション、go_router、auto_route）とディープリンクを扱う。developing-flutter-apps のINSTRUCTIONS.mdから「画面遷移を実装したい」「ルーティング方式を決めたい」タスクでルーティングされる想定であり、Widget自体の構築はWIDGETS-LAYOUT-THEMING.md、状態管理はSTATE-MANAGEMENT.mdが担当する。

## Navigator 1.0（命令的ナビゲーション）

Navigator 1.0はFlutter標準の命令的（imperative）ナビゲーションAPIで、画面をスタックにpush/popして管理する。小〜中規模アプリや画面数が少ないアプリでは、追加の依存パッケージなしで完結できる。

### 無名ルート（push/pop）

`Navigator.push` に `MaterialPageRoute` を渡すだけで、名前を付けずに画面遷移できる。

```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => const DetailsScreen()),
);

// 戻る
Navigator.pop(context);

// 結果を受け取って戻る
final result = await Navigator.push<String>(
  context,
  MaterialPageRoute(builder: (context) => const SelectionScreen()),
);
```

### 名前付きルート（named routes）

アプリ全体のルート一覧を `MaterialApp` の `routes` に定義し、文字列で遷移する。ルート名を一箇所に集約できるため、無名ルートより見通しが良い。

```dart
void main() {
  runApp(MaterialApp(
    initialRoute: '/',
    routes: {
      '/': (context) => const HomeScreen(),
      '/details': (context) => const DetailsScreen(),
    },
  ));
}

// 遷移
Navigator.pushNamed(context, '/details');

// 現在のスタックを置き換える（ログイン後のホーム遷移等）
Navigator.pushReplacementNamed(context, '/home');
```

### 画面間のデータ受け渡し

`arguments` で任意のオブジェクトを渡し、遷移先で `ModalRoute.of(context)!.settings.arguments` から取得する。ただし型が失われる（`Object?` として渡る）ため、コンストラクタ引数で直接渡せる無名ルートの方が型安全性は高い。

```dart
Navigator.pushNamed(context, '/details', arguments: article.id);

// 遷移先
final articleId = ModalRoute.of(context)!.settings.arguments as String;
```

複数画面で共有する必要がなく型安全性を優先するなら、`MaterialPageRoute` にコンストラクタ引数を直接渡す方式を優先する。

```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => DetailsScreen(articleId: article.id)),
);
```

### onGenerateRoute によるルート生成の一元化

引数付きの名前付きルートや、存在しないルート名（404相当）を扱う場合は `onGenerateRoute` を使う。

```dart
MaterialApp(
  onGenerateRoute: (settings) {
    switch (settings.name) {
      case '/details':
        final articleId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (context) => DetailsScreen(articleId: articleId),
        );
      default:
        return MaterialPageRoute(builder: (context) => const NotFoundScreen());
    }
  },
);
```

## Navigator 2.0（Router API）

Navigator 2.0はFlutterの宣言的（declarative）ルーティングAPIで、アプリの状態からナビゲーションスタックを導出する。ブラウザの戻る/進むボタン、OSレベルのディープリンク、URLとアプリ状態の同期が必要なアプリ（特にWebターゲット）に向く。

Router APIは `RouterDelegate`・`RouteInformationParser`・`RouteInformationProvider` の3つの役割で構成される。自前で実装すると、画面追加のたびにこれらを更新する必要があり記述量が多い。実務では、これらを抽象化した go_router や auto_route を使うのが標準的である。

```dart
MaterialApp.router(
  routerDelegate: MyRouterDelegate(),
  routeInformationParser: MyRouteInformationParser(),
);
```

Navigator 2.0を自前実装するのは、go_router等が対応しない特殊な要件（独自のルート遷移アニメーション基盤との統合等）がある場合に限る。通常はgo_routerを第一候補にする。

## go_router

go_routerはNavigator 2.0を宣言的なAPIでラップした公式サポートのルーティングパッケージで、現行Flutterアプリのデファクト標準になっている。URLパスベースのルート定義、ネストされたナビゲーション、リダイレクト、型安全なルート引数を提供する。

```dart
final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/articles/:id',
      builder: (context, state) {
        final articleId = state.pathParameters['id']!;
        return DetailsScreen(articleId: articleId);
      },
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
      routes: [
        // ネストされたルート（/settings/profile）
        GoRoute(
          path: 'profile',
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    ),
  ],
  redirect: (context, state) {
    final loggedIn = AuthState.of(context).isLoggedIn;
    final loggingIn = state.matchedLocation == '/login';
    if (!loggedIn && !loggingIn) return '/login';
    if (loggedIn && loggingIn) return '/';
    return null;
  },
);

void main() {
  runApp(MaterialApp.router(routerConfig: router));
}
```

遷移は `context.go('/articles/1')`（スタックを置き換え）や `context.push('/articles/1')`（スタックに積む）で行う。ボトムナビゲーションで各タブに独立したスタックを持たせる場合は `StatefulShellRoute` を使う。

## auto_route

auto_routeはアノテーションとコード生成（build_runner）でルート定義を型安全にするパッケージで、ルート追加時の定型コードを自動生成する。go_routerがパスベースの文字列中心API（外部からのディープリンクとの親和性が高い）であるのに対し、auto_routeはDartのクラス・アノテーション中心のAPI（型補完とコンパイル時チェックが強い）という違いがある。

```dart
@RoutePage()
class DetailsScreen extends StatelessWidget {
  const DetailsScreen({required this.articleId, super.key});
  final String articleId;

  @override
  Widget build(BuildContext context) => Scaffold(/* ... */);
}

@AutoRouterConfig()
class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
        AutoRoute(page: HomeRoute.page, initial: true),
        AutoRoute(page: DetailsRoute.page),
      ];
}

// 遷移（生成された *Route クラス経由で型安全に引数を渡す）
context.router.push(DetailsRoute(articleId: article.id));
```

## ディープリンクとURL同期

- モバイルのディープリンク（カスタムスキーム・Universal Links/App Links）は、go_router / auto_routeいずれもプラットフォーム側のディープリンク設定（iOS: Associated Domains、Android: Intent Filter）と組み合わせて使う。ルーティングパッケージはアプリ内のURL解釈を担い、OSレベルの登録は別途必要。
- Web targetでは、go_routerのパスベースのルート定義がブラウザURLと自然に対応する。ブラウザの戻る/進むボタンの挙動もgo_routerが吸収する。
- ディープリンクで受け取った未認証状態からの遷移は、`redirect` コールバックで一元的にガードする（各画面に認証チェックを分散させない）。

## ユーザー確認の原則（AskUserQuestion）

**判断分岐がある場合、推測で進めず必ずAskUserQuestionツールでユーザーに確認する。**

確認すべき場面:
- ナビゲーション方式の選択（Navigator 1.0 / Navigator 2.0の自前実装 / go_router / auto_route）。プロジェクトの規模、Web対応の有無、既存コードベースの方式、ディープリンク要件によって最適解が変わるため、推測で選ばない。
- 既存プロジェクトに複数のナビゲーション方式が混在する場合、統一するか共存させるか。

確認不要な場面:
- 新規かつ小規模なプロトタイプで、要件に特段のディープリンク/Web対応がない場合はNavigator 1.0の名前付きルートを既定として進めてよい（ただし本格運用が見込まれるならgo_routerを推奨する旨を伝える）。
- 既にgo_router/auto_routeが `pubspec.yaml` に導入済みの既存プロジェクトでは、その方式を踏襲する。

## チェックリスト

- [ ] アプリ規模・Web対応有無・ディープリンク要件からナビゲーション方式を選定した（不明な場合はAskUserQuestionで確認した）
- [ ] ルート定義を一箇所（ルーターの設定ファイルまたは名前付きルートテーブル）に集約した
- [ ] 画面間のデータ受け渡しが型安全である（`arguments` の `as` キャストに頼りすぎていない）
- [ ] 認証状態等によるリダイレクトを画面individually ではなくルーター側で一元管理した
- [ ] ディープリンクを使う場合、OSレベルの設定（Associated Domains / Intent Filter）を確認した
- [ ] ボトムナビゲーション等でタブごとに独立したスタックが必要か検討した
