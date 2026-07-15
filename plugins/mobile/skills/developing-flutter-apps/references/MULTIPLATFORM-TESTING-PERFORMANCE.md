# レスポンシブ・マルチプラットフォーム対応・テスト・性能最適化

## 概要

このリファレンスは、単一の Flutter コードベースをモバイル・Web・デスクトップへ展開する際のレスポンシブレイアウト戦略とプラットフォーム差分の吸収、Flutter アプリ固有の widget/integration テスト、rebuild 削減を中心とした性能最適化とプロファイリングを扱う。

状態管理・ナビゲーション・アーキテクチャそのものの選定は [STATE-MANAGEMENT.md](STATE-MANAGEMENT.md)・[NAVIGATION-ROUTING.md](NAVIGATION-ROUTING.md)・[ARCHITECTURE-PATTERNS.md](ARCHITECTURE-PATTERNS.md) を参照する。widget/integration テストは Flutter 固有の実装としてここで扱うが、TDD・AAA パターン・カバレッジ方針といった一般的なテスト方法論は devkit:testing-code を参照する。

## 1. レスポンシブレイアウトの基礎

### MediaQuery で画面情報を取得する

`MediaQuery` は画面幅・高さ・向き・システムの余白（セーフエリア）等を提供する。レイアウト分岐の起点として最も基本的な手段である。

```dart
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= 900 ? const _DesktopLayout() : const _MobileLayout();
  }
}
```

`MediaQuery.of(context)` は画面全体の再描画を招きやすいため、幅や高さだけが必要な場合は `MediaQuery.sizeOf(context)` のような専用アクセサを使い、rebuild 範囲を最小化する。

### LayoutBuilder で親の制約に応じて分岐する

`LayoutBuilder` は画面全体ではなく、そのウィジェットが実際に配置される領域の制約（`BoxConstraints`）を基準に分岐できる。ネストした分割ビュー（マスター・ディテールなど）で `MediaQuery` より適切な場面が多い。

```dart
LayoutBuilder(
  builder: (context, constraints) {
    if (constraints.maxWidth >= 840) {
      return const Row(children: [Expanded(child: _ListPane()), Expanded(child: _DetailPane())]);
    }
    return const _ListPane();
  },
)
```

### Flexible・Expanded・AspectRatio

| ウィジェット | 用途 |
|---|---|
| `Expanded` | 残りスペースを全て割り当てる |
| `Flexible` | 割合（`flex`）に応じて柔軟に伸縮させる |
| `AspectRatio` | 画面サイズに関わらず縦横比を固定する |
| `FittedBox` | 子要素を利用可能な領域に収まるよう拡大縮小する |

### 目安のブレークポイント

| 区分 | 幅の目安 |
|---|---|
| コンパクト（スマートフォン） | 600dp 未満 |
| ミディアム（タブレット縦・折りたたみ展開） | 600〜840dp |
| 拡張（タブレット横・デスクトップ・Web） | 840dp 以上 |

固定値として暗記せず、対象デバイスの実測値と Flutter 公式のレイアウトガイドを都度確認する。

## 2. プラットフォーム差分の吸収

### Material と Cupertino

Android では Material Widgets、iOS ではプラットフォームらしさを重視する場合に Cupertino Widgets を使う。両方を切り替える場合は、判定ロジックを 1 箇所（テーマや共通ウィジェット層）に集約し、画面ごとに分岐を書き散らさない。

```dart
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

Widget adaptiveButton({required String label, required VoidCallback onPressed}) {
  if (Platform.isIOS) {
    return CupertinoButton(onPressed: onPressed, child: Text(label));
  }
  return ElevatedButton(onPressed: onPressed, child: Text(label));
}
```

### プラットフォーム判定

| API | 対象 | 注意点 |
|---|---|---|
| `Platform.isAndroid` / `Platform.isIOS` 等（`dart:io`） | ネイティブ実行時 | Web では利用不可（`dart:io` 自体がコンパイル対象外） |
| `kIsWeb`（`package:flutter/foundation.dart`） | Web かどうかの判定 | `dart:io` 参照より先に確認する |
| `defaultTargetPlatform` | ネイティブ・Web を問わない論理プラットフォーム推定 | Web 上でのホスト OS 推定に使う |

`dart:io` の `Platform` を直接参照するコードは Web ビルドで失敗する。Web を対象に含める場合は `kIsWeb` で先に分岐するか、`universal_io` のようなクロスプラットフォーム抽象を使う。

### Platform Channel によるネイティブ機能連携

Flutter 標準 API で足りないネイティブ機能（バッテリー残量、特殊センサー等）は `MethodChannel` で呼び出す。

```dart
import 'package:flutter/services.dart';

class BatteryService {
  static const _channel = MethodChannel('com.example.app/battery');

  Future<int> currentLevel() async {
    try {
      final level = await _channel.invokeMethod<int>('getBatteryLevel');
      return level ?? -1;
    } on PlatformException catch (e) {
      throw StateError('battery level fetch failed: ${e.message}');
    }
  }
}
```

Platform Channel は Web では利用できないため、Web を対象にする場合は機能提供の有無を切り分けて設計する。

## 3. デスクトップ・Web 特有の考慮事項

- デスクトップ: キーボードショートカット、マウスホバー状態、ウインドウのリサイズ、右クリックメニューを想定する。タッチ専用のジェスチャ（長押しでコンテキストメニュー等）をそのまま流用しない。
- Web: マウス・キーボード入力とタッチ入力の両立、ブラウザの戻る操作とアプリ内ナビゲーションの整合、URL 構造（ディープリンク）を考慮する。
- 折りたたみ端末・大画面タブレット: `MediaQuery.of(context).displayFeatures` でヒンジやカットアウトの位置情報を取得できる。

現行のビルドオプションやレンダラー設定は変更されやすいため、対象プラットフォームを追加するタイミングで Flutter 公式ドキュメントの最新情報を確認する。

## 4. Widget テスト

`flutter_test`（SDK 同梱）を使い、個々のウィジェットの描画とインタラクションを検証する。実機やエミュレータを起動せず高速に実行できるため、UI ロジックの回帰防止に向く。

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('タップでカウントが増える', (tester) async {
    var count = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: Column(
              children: [
                Text('count: $count'),
                ElevatedButton(
                  onPressed: () => setState(() => count++),
                  child: const Text('increment'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('count: 0'), findsOneWidget);

    await tester.tap(find.text('increment'));
    await tester.pump();

    expect(find.text('count: 1'), findsOneWidget);
  });
}
```

| API | 役割 |
|---|---|
| `tester.pumpWidget` | ウィジェットツリーを構築する |
| `tester.pump` / `pumpAndSettle` | 1 フレーム進める／アニメーション完了まで進める |
| `tester.tap` / `enterText` / `drag` | ユーザー操作をシミュレートする |
| `find.byType` / `byKey` / `text` | ウィジェットを検索する（Finder） |
| `expect(finder, findsOneWidget)` | 検索結果に対するアサーション |

非同期処理を伴う画面では、`pump()` を状態遷移の回数だけ呼ぶか `pumpAndSettle()` で安定を待つ。無限アニメーションが存在すると `pumpAndSettle()` がタイムアウトする点に注意する。

## 5. Integration テスト

`integration_test` パッケージは実機・エミュレータ上でアプリ全体を起動し、複数画面をまたぐユーザーフローを検証する。widget テストより実行は遅いが、ナビゲーション・永続化・実際のプラットフォーム API を含めた end-to-end の検証ができる。

```dart
// integration_test/app_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ログインからホーム画面遷移までの一連の操作', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('email_field')), 'user@example.com');
    await tester.enterText(find.byKey(const Key('password_field')), 'password123');
    await tester.tap(find.byKey(const Key('login_button')));
    await tester.pumpAndSettle();

    expect(find.text('ようこそ'), findsOneWidget);
  });
}
```

CI 上で実行する場合は `flutter test integration_test` に加え、対象プラットフォームのエミュレータ／シミュレータ、または実機ファームを用意する。

## 6. テスト戦略・ターゲットプラットフォームの選択（AskUserQuestion）

**判断分岐がある場合、推測せずに AskUserQuestion で確認する。**

**確認すべき場面**:
- テスト範囲（unit のみ／widget まで／integration まで含めるか）が要件から一意に決まらない場合
- ターゲットプラットフォーム（mobile only／+web／+desktop）がリポジトリ構成や依頼内容から確定できない場合

| 分岐 | 選択肢 |
|---|---|
| テスト戦略 | unit（Dart ロジック）のみ／widget まで／widget + integration |
| ターゲットプラットフォーム | mobile only／mobile + web／mobile + web + desktop |

**確認不要な場面（一義的に決まる）**:
- ビジネスロジック（Dart のクラス・関数）に対する unit テストの追加そのもの
- 既存プラットフォーム対象を変更せず、その範囲内でバグを修正する作業

## 7. 性能最適化の基本方針

### const コンストラクタで rebuild を止める

`const` を付けられるウィジェットは可能な限り `const` にする。設定が変化しないウィジェットを `const` にすると、親が rebuild してもそのサブツリーは再構築されない。これは判断分岐のない推奨事項であり、常に採用する。

```dart
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Text('Section'), // 動的な値がなければ const Text で固定してもよい
    );
  }
}
```

### rebuild 範囲を狭める

- 状態を持つウィジェットを画面全体ではなく、実際に変化する部分だけに閉じ込める（ウィジェットの分割）。
- `ValueListenableBuilder` / `ListenableBuilder` で、特定の値が変わった部分だけを再構築する。
- 状態管理ライブラリを使う場合は、選択的購読（`Selector`、`ref.watch` のフィールド単位購読等）の機構を活用する。詳細は [STATE-MANAGEMENT.md](STATE-MANAGEMENT.md) を参照する。

```dart
ValueListenableBuilder<int>(
  valueListenable: counter,
  builder: (context, value, child) => Text('$value'),
)
```

### リストと画像

- 要素数が不定・大量になり得るリストは `ListView`/`GridView` の直接生成ではなく `ListView.builder` / `SliverList.builder` で遅延構築する。
- 頻繁に再描画されないが描画コストの高いカスタムペイントは `RepaintBoundary` で独立したレイヤーに分離する。
- ネットワーク画像のキャッシュ・デコードサイズの最適化はパッケージ選定を含めて [PACKAGES-BUILD-RELEASE.md](PACKAGES-BUILD-RELEASE.md) を参照する。

| 手法 | 効果 |
|---|---|
| `const` コンストラクタ | 変化しないサブツリーの rebuild を除外 |
| ウィジェット分割 | 状態変化の影響範囲を局所化 |
| `ListView.builder` | 画面外要素の構築・破棄を遅延させる |
| `RepaintBoundary` | 描画レイヤーを分離し不要な再描画を防ぐ |
| `cacheExtent` 調整 | スクロール先読み範囲を調整する |

## 8. プロファイリングと計測

### Flutter DevTools

- Performance ビュー: フレームごとの構築・描画時間を確認し、ジャンク（フレーム落ち）の原因ウィジェットを特定する。
- Memory ビュー: メモリリーク、不要に保持されたオブジェクトを検出する。
- Widget Inspector: ウィジェットツリーと rebuild 回数を可視化する。

DevTools は必ず `--profile` ビルド（またはリリースに近い構成）で計測する。デバッグビルドはアサーションやオーバーヘッドが多く、実際の性能を反映しない。

```bash
flutter run --profile
flutter build apk --analyze-size
flutter build appbundle --release --target-platform android-arm64
```

### フレーム予算の考え方

Flutter は毎フレーム描画を試みる。1 フレームの予算を超えて構築・描画・ラスタライズに時間がかかると、フレームが落ちて操作がもたつく体感（ジャンク）につながる。固定の許容ミリ秒数を暗記して合否判定にするのではなく、対象デバイスでの実測とプロファイル結果の変化を基準に比較する。

- `build()` メソッド内で重い同期処理（ファイル I/O、大きな計算）を行わない。
- アニメーション中に大量の rebuild が走っていないか DevTools の Timeline で確認する。
- リリースビルドでのみ有効な最適化（Tree Shaking、AOT コンパイル）があるため、性能の最終判断はリリース相当の構成で行う。

## チェックリスト

- [ ] ターゲットプラットフォーム（mobile only／+web／+desktop）を確認した
- [ ] プラットフォーム固有 UI（Material/Cupertino）とプラットフォーム判定の方針を決めた
- [ ] Web 対象時に `dart:io` 直接参照がないことを確認した
- [ ] テスト戦略（unit/widget/integration の範囲）を確認した
- [ ] 主要フローの widget テストを追加した
- [ ] 必要に応じて integration テストを追加した
- [ ] 変化しないウィジェットを `const` にした
- [ ] 大きなリストで `ListView.builder` 等の遅延構築を使っている
- [ ] DevTools の Performance/Memory ビューで rebuild とメモリを確認した
- [ ] 計測はプロファイル／リリース相当の構成で行った
