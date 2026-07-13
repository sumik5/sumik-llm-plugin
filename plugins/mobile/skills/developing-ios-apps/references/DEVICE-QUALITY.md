# デバイス対応・パフォーマンス・テスト（Device Support / Performance / Testing）

> 出典: Apple Human Interface Guidelines / Apple Developer Documentation（最終確認 2026-07-13）。仕様は更新されるため、実装時は必ず併記の公式 URL で最新版を確認すること。日本語版がある場合は公式の言語切替または本文の日本語 URL を使い、英語版との差分がある場合は最新側を確認する。

> 鮮度補正: 機種名・ポイント寸法・インセット・タップ領域・性能閾値・Xcode/OS/API導入版は2026-07-13時点のスナップショットまたは計測開始点であり、恒久的な合否基準ではない。実装時は現行HIG、対象SDKのAvailability、Xcodeの計測資料、実機baselineで再確認すること。

対象: iPhone / iPad（iOS / iPadOS）アプリを設計・実装する開発者と AI コーディングエージェント。実装判断に直結する「〜すること / 〜してはならない」形式で記述する。

---

## 1. デバイス / 画面対応マトリクス（Screen & Safe Area Matrix）

### 概要

iPhone / iPad は画面サイズ・角丸・センサーハウジング（ノッチ / Dynamic Island）・ホームインジケータの有無が機種ごとに異なる。固定座標や固定サイズでレイアウトを組むと必ずどこかの機種で破綻するため、**セーフエリア（Safe Area）とレイアウトガイドに対する相対レイアウト**を唯一の前提とすること。

### 主要デバイスの論理解像度（ポートレート・pt、確認時点の例）

| デバイス | ポイント寸法 | スケール | 前面形状 |
|---------|------------|---------|---------|
| iPhone 17 Pro Max | 440×956 pt | @3x | Dynamic Island |
| iPhone 17 Pro / iPhone 17 | 402×874 pt | @3x | Dynamic Island |
| iPhone Air | 420×912 pt | @3x | Dynamic Island |
| iPhone SE 系（ホームボタン機） | 375×667 pt | @2x | ベゼル（セーフエリア切欠きなし） |
| iPad Pro 13-inch | 1032×1376 pt | @2x | 均一ベゼル |
| iPad Pro 12.9-inch | 1024×1366 pt | @2x | 均一ベゼル |
| iPad mini 8.3-inch | 744×1133 pt | @2x | 均一ベゼル |

> 新機種は追加・変更される。表はテスト観点を示す例であり、現行ラインアップの完全な一覧ではない。**特定機種の寸法をコードにハードコードしてはならない**。一覧は実装時に HIG Layout の「Specifications」で再確認する。

### セーフエリアを構成する要素

| 要素 | 影響領域 | 代表的なインセット値（参考） |
|------|---------|--------------------------|
| ステータスバー | 上端 | ノッチ機 44–47pt / Dynamic Island 機 54pt 前後（機種依存） |
| ノッチ / Dynamic Island | 上端センサーハウジング周辺 | セーフエリア top に包含される |
| ホームインジケータ | 下端 | ポートレート 34pt / ランドスケープ 21pt 前後 |
| 角丸コーナー | 四隅 | コーナー半径ぶんの欠け |
| キーボード | 下端（表示時） | SwiftUI は `SafeAreaRegions.keyboard` で扱う |

### 🔴 必須（遵守事項）

- レイアウトは **Auto Layout（`safeAreaLayoutGuide` / `layoutMarginsGuide`）または SwiftUI の既定セーフエリア**に基づいて組むこと。画面寸法からの手計算を禁止する。
- テキスト・ボタン・入力欄などの**インタラクティブ要素とプライマリコンテンツはセーフエリア内に配置する**こと。セーフエリア外（Dynamic Island 直下・ホームインジケータ帯）にタップ対象を置いてはならない。
- 背景・画像・マップなどの**非インタラクティブな装飾はセーフエリアを越えて画面端までフルブリード**させること（`ignoresSafeArea()` / `edgesForExtendedLayout`）。切欠き周辺に黒帯を残すレイアウトは不合格。
- タップ可能領域は、確認時点のHIGが示す44×44ptという推奨値を設計baselineにする。ただしこれを全状況のApp Review絶対下限と断定せず、現行HIG、controlの種類、入力方式、周囲の間隔を確認し、操作しやすい領域を確保する。
- ホームインジケータは既定で常時表示のままにすること。`prefersHomeIndicatorAutoHidden` は動画全画面・ゲーム等の没入体験に限定する。
- ステータスバーは既定で表示すること。非表示にしてよいのはゲーム・メディア視聴など全画面体験のみ。
- Dynamic Island / センサーハウジングの**インセット値をハードコードしてはならない**。値は機種と OS バージョンで変わる。

### 推奨

- Dynamic Island を積極活用する場合は Live Activities（ActivityKit）を検討する（対応機ではロック画面と Dynamic Island の両方に表示される）。
- フル幅ボタンを画面端まで伸ばさず、システム定義のレイアウトマージンを尊重する（HIG 明記）。
- 角丸コーナーと Dynamic Island に追従するため、上下端に置くバー類はシステム標準コンポーネント（`UINavigationBar` / `UITabBar` / SwiftUI toolbar）を優先する。
- サイドバーやインスペクタの背後にコンテンツ背景を延長する場合は `backgroundExtensionEffect()`（SwiftUI）/ `UIBackgroundExtensionView`（UIKit）を使う。

### よくある違反・注意点

- ❌ `UIScreen.main.bounds` を基準にした絶対座標レイアウト（マルチウィンドウ・Stage Manager でウィンドウ ≠ 画面となり破綻。`UIScreen.main` 自体が非推奨方向）。
- ❌ 「ノッチがあるかどうか」を機種名やセーフエリア値の判定で分岐するコード。セーフエリアをそのまま使えば分岐は不要。
- ❌ 下端タブバーの直上にさらに独自のフローティングバーを重ね、ホームインジケータのジェスチャ領域と競合させる。
- ❌ ランドスケープ時の左右セーフエリア（センサーハウジング側）を無視して全幅テキストを敷く。

公式: https://developer.apple.com/design/human-interface-guidelines/layout

---

## 2. iPhone / iPad ユニバーサル対応（Size Classes / Multitasking / Rotation）

### 概要

1 つのバイナリで iPhone と iPad の両方に最適な UI を提供するのがユニバーサルアプリの前提。分岐の単位は「デバイス種別」ではなく **サイズクラス（Size Class）** であること。iPadOS ではウィンドウが自由リサイズされる（Stage Manager / ウィンドウ表示モード）ため、iPad = Regular×Regular という決め打ちも成立しない。

### サイズクラス早見表

| 状況 | horizontal × vertical |
|------|----------------------|
| iPhone ポートレート | Compact × Regular |
| iPhone ランドスケープ（標準サイズ） | Compact × Compact |
| iPhone ランドスケープ（Max/Air 系大画面） | Regular × Compact |
| iPad フルスクリーン（両向き） | Regular × Regular |
| iPad Split View 1/2・1/3 やウィンドウ縮小時 | Compact × Regular になり得る |

```swift
@Environment(\.horizontalSizeClass) var hSizeClass

var body: some View {
    if hSizeClass == .regular {
        NavigationSplitView { Sidebar() } detail: { Detail() }
    } else {
        NavigationStack { List() }
    }
}
```

### 🔴 必須（遵守事項）

- レイアウト分岐は **サイズクラスと利用可能サイズで行う**こと。`UIDevice.current.userInterfaceIdiom` によるデバイス分岐は表示スタイルのヒントに留め、レイアウト計算に使ってはならない。
- **iPadでは複数ウインドウと自由なリサイズを原則採用する**。アプリのカテゴリ、capability、現行の提出要件で例外が認められるかをApple公式で確認し、例外を選ぶ場合は製品上の理由を記録する。固定のSplit View比率だけでなく、最小許容サイズから広いウインドウまで連続的にUIが破綻しないこと。
- アプリ側から**マルチタスキング構成を制御・検知できない**前提で設計すること（「Apps don't control multitasking configurations」）。どのサイズで表示されても成立するレスポンシブレイアウトのみが解。
- 回転（ポートレート / ランドスケープ）は**両対応を基本**とすること。ランドスケープ固定にする場合も左右両回転（landscapeLeft / landscapeRight）をサポートする。
- iPad アプリで `UIRequiresFullScreen` に依存して リサイズ対応を回避しない こと（レガシー扱いであり、新規開発では使用しない）。
- Split View / ウィンドウ縮小で Compact 幅になった際、**3 カラム構成はインスペクタ等の三次カラムを畳んで段階的に縮退**させること。いきなり全損させない。

### 推奨

- ナビゲーションは `NavigationSplitView`（SwiftUI）/ `UISplitViewController`（UIKit）を使い、Compact 時の自動スタック化に任せる。
- タブ UI は `.tabViewStyle(.sidebarAdaptable)` で「Regular 幅ではサイドバー / Compact 幅ではタブバー」に自動適応させる（iPadOS のコンバーチブルタブバー）。
- できる限りフルレイアウトを維持し、早すぎる Compact 切替を避ける（HIG 明記）。
- システムが提供する代表的な配置に加え、自由なウインドウ幅を最小から最大まで連続的に変更して手動テストする。1/2・1/3・1/4等の比率は確認時点の代表例であり、現行iPadOSの全配置を表す固定リストとして扱わない。
- 複数ウィンドウ（同一アプリの多重ウィンドウ）をサポートし、`UIScene` ベースのライフサイクルで状態をシーンごとに分離する。
- ドキュメントベースのアプリでは Drag and Drop・ウィンドウ間ドラッグを検証する。

### よくある違反・注意点

- ❌ 「iPad なら Regular」という前提のコード。Split View / Stage Manager で iPad 上でも Compact になる。
- ❌ 回転やリサイズ時に `viewWillTransition(to:with:)` / サイズクラス変化を処理せず、古いサイズのキャッシュでレイアウトする。
- ❌ 起動時に一度だけ画面サイズを読んで以後使い回す（ウィンドウリサイズ・回転で陳腐化する）。
- ❌ シートやポップオーバーのアンカー未指定（iPad ではポップオーバーの sourceView/sourceRect が必須で、未指定はクラッシュや不正位置の原因）。

公式: https://developer.apple.com/design/human-interface-guidelines/multitasking

---

## 3. Designed for iPad on Mac / Mac Catalyst の概要

### 概要

iPhone/iPad アプリを Mac に届ける経路は 2 つある。どちらも iPad で正しくマルチタスキング・リサイズ対応していることが品質の土台になる。

| 経路 | 仕組み | 工数 | 適する場合 |
|------|--------|------|-----------|
| **Designed for iPad on Mac** | Apple シリコン Mac 上で iPad バイナリを**無修正・再コンパイルなし**で実行。iOS 機能は macOS の対応機能へ自動マッピング | ほぼゼロ（既定でオプトイン） | iPad 対応が良好で、Mac 固有 UI が不要な場合 |
| **Mac Catalyst** | プロジェクト設定のチェックボックスで有効化し、**同一ソースから macOS ネイティブアプリをビルド**。メニューバー・ツールバー等 Mac らしい UI を追加できる | 中 | Mac 向けに UI/UX を最適化したい場合 |

### 🔴 必須（遵守事項）

- **Designed for iPad on Mac をオプトアウトすべき条件**に該当するか判定すること: ①既に AppKit / Mac Catalyst 版がある ②加速度計・ジャイロ・磁力計・GPS・深度カメラ等 iOS 専用ハードウェア必須 ③macOS に存在しないフレームワーク/シンボルに依存 ④キーボード・マウスで代替不能な複数指タッチ必須 ⑤External Accessory Framework 等カスタムハードウェア依存。該当すれば App Store Connect の「Make this app available on Mac」を無効化する。
- Mac 上で動かす場合、次の**暗黙の前提をコードから排除する**こと: フロント/リアカメラの存在（`AVCaptureDevice.DiscoverySession` で実在確認する）、デバイス種別が iPhone/iPad であること、ウィンドウサイズ = 画面解像度、固定ファイルパス、PushKit のバックグラウンド起動（Mac ではフォアグラウンド）。
- Mac 判定は最終手段としてのみ `ProcessInfo.processInfo.isiOSAppOnMac` を使うこと。機能の有無は機能 API 自体で検出する。
- Mac Catalyst では **AppKit API は公式対応分（NSToolbar・NSTouchBar 等）以外使用してはならない**。未対応 AppKit API へのアクセスはサポート外。
- 検証は **Simulator ではなく Apple シリコン Mac の実機**で行うこと（Xcode から直接ネイティブ実行できる）。

### 推奨

- iPad マルチタスキング + Auto Layout 対応を済ませておく（Mac の可変ウィンドウにそのまま効く）。
- キーボードショートカット（`UIKeyCommand`）・メニュー（`UIMenuBuilder`）・ホバー（`UIHoverGestureRecognizer`）・ツールチップ（`UIToolTipInteraction`）を実装し、ポインタ環境の操作性を高める。
- ピンチ・スクロール・回転はシステム標準ジェスチャ認識器を使う（トラックパッド操作へ自動マッピングされる）。
- Mac Catalyst では「iPad idiom」か「Mac idiom」かを選び、Mac idiom ではタイトルバー統合・チェックボックス表示等 Mac ネイティブの見た目に寄せる。
- 配布前に TestFlight（Mac 対応）で実ユーザー環境の動作を確認する。

### よくある違反・注意点

- ❌ タッチ専用ジェスチャ（マルチタッチ描画等）を代替入力なしで必須動線に置いたまま Mac 配布する。
- ❌ 「シンボルが存在する = 機能が使える」という仮定（Mac 上では存在しても機能しない場合がある）。
- ❌ Mac Catalyst 有効化だけで最適化を終える（メニュー・ショートカット・ウィンドウ復元がないと Mac アプリとして低品質）。

公式: https://developer.apple.com/documentation/apple-silicon/running-your-ios-apps-in-macos / https://developer.apple.com/documentation/uikit/mac-catalyst

---

## 4. パフォーマンス基準（Performance Budgets）

### 概要

Apple はパフォーマンス改善を「①フィールドデータ収集 → ②問題特定 → ③Instruments プロファイル → ④改善 → ⑤前後比較・回帰テスト」の**継続サイクル**として定義している。指標は起動時間・応答性（ハング）・メモリ・ディスク書き込み・バッテリー・ディスク使用量。数値は必ず**実機**で計測すること（Simulator の数値は当てにならない）。

この章の400ms、250ms、ヒッチ時間比、frame budget等は、確認時点のApple資料やツールが示す診断上の目安である。単独でリリース可否を断定せず、現行資料を確認し、対象端末・主要操作・変更前後の実測からプロジェクト固有のbudgetを設定する。

### 4.1 起動時間（Launch Time）

- 測定定義: アイコンタップから**最初のフレーム描画**（TimeToFirstDraw）まで。
- 目標: WWDC セッション（Optimizing App Launch）で示された目安は**初回フレームまで約 400ms**。Cold launch と Warm launch を区別して測ること。
- iOS の watchdog は起動がブロックされ続けるアプリを**数秒で強制終了**する。起動パスでの同期 I/O・同期ネットワークは絶対禁止。

| 🔴 必須 | 内容 |
|--------|------|
| `didFinishLaunching` の軽量化 | 最初の画面表示に必要な処理のみ実行し、残り（同期・分析 SDK 初期化・全サービス起動）はバックグラウンド/遅延実行する |
| 静的初期化の排除 | C++ 静的コンストラクタ・Objective-C `+load`・`__attribute__((constructor))` を避け、遅延初期化にする |
| リンクの削減 | 未使用フレームワークのリンクを外す。動的ライブラリが多い場合は Mergeable Dynamic Libraries（Xcode 15+）を検討 |
| 初期ビューの単純化 | 初期画面で全データ・全画像をデコードしない。プレースホルダー + 遅延ロード |
| 計測 | Xcode Organizer の Launch Time ペイン（50th/90th percentile をデバイス別・バージョン別に確認）と Instruments **App Launch** テンプレート |

### 4.2 ハング（Hangs）とスクロールヒッチ（Scroll Hitches）

- **ハングの定義: メインスレッド（メインランループ）が 250ms 以上ビジーでイベントを処理できない状態**。100ms 未満の遅延はほぼ知覚されず、250ms が Apple ツール共通の報告閾値。
- 唯一の根本原因は「メインスレッド上の長時間処理」。ネットワーク・ディスク I/O・重い変換処理は `Task` / バックグラウンドキューへ移し、UI 更新のみ MainActor に戻すこと。
- **ヒッチ**はアニメーション/スクロール中にフレームが期限に間に合わず表示が乱れる現象。WWDC セッション（Explore UI animation hitches）の目安: **ヒッチ時間比 5ms/s 未満 = 良好、5–10ms/s = 要注意、10ms/s 超 = 不良**。
- 検出ツールの閾値: Hangs instrument（250ms・調整可）/ Thread Performance Checker（Xcode 診断・開発中に検出）/ Xcode Organizer Hang Rate（フィールド実データ）。

### 4.3 ProMotion / 120Hz

- ProMotion ディスプレイ（対応 iPhone Pro 系・iPad Pro）は最大 120Hz・可変リフレッシュレート。**8.3ms のフレーム予算**で描画が完了しないとヒッチとして知覚されやすくなる。
- 🔴 iPhone で Core Animation / UIKit のカスタムアニメーションを 120Hz でフル駆動したい場合は Info.plist に **`CADisableMinimumFrameDurationOnPhone` = YES** を設定すること（未設定では最大 60Hz に制限される）。
- 🔴 フレームレートを固定値と仮定してはならない。アニメーションは時間ベース（duration ベース）で書き、`CADisplayLink` を使う場合は `preferredFrameRateRange` で必要レンジ（例: min 80 / max 120 / preferred 120）を宣言する。
- 低電力モード・省電力状態ではリフレッシュレートが動的に下がる。60Hz 前提のフレームカウント計算（「60 フレーム = 1 秒」等）は禁止。

### 4.4 メモリ

- メモリ超過はフォアグラウンドの Jetsam 強制終了（クラッシュに見える）と、バックグラウンド滞留率の低下（再起動が増え起動時間 UX が悪化）を招く。
- 🔴 メモリ警告（`didReceiveMemoryWarning` / `UIApplication.didReceiveMemoryWarningNotification`）で再生成可能なキャッシュを即時解放すること。
- 🔴 画像は表示サイズにダウンサンプリングしてから保持すること。原寸 UIImage の配列保持はピークメモリの典型的犯人。
- キャッシュは Caches ディレクトリ（`FileManager` の cachesDirectory）に置き、iCloud バックアップ対象から外す。OS が容量逼迫時に削除できる。
- 計測: Instruments **Allocations / Leaks**、Xcode Memory Graph、フィールドは MetricKit `PeakMemoryMetric` / Jetsam イベントレポート。

### 4.5 バッテリー / エネルギー

- 🔴 位置情報は必要最低精度・必要期間に限定すること（`LocationActivityTimeMetric` で精度レベル別時間を監視できる）。
- 🔴 ネットワークはバッチ化・遅延許容タスクのバックグラウンドスケジューリング（BGTaskScheduler）で無線起床回数を減らすこと。
- 判断基準は「メトリクスの絶対値」ではなく**用途との乖離**（例: ポッドキャストアプリの background audio 高消費は正常、ゲームなら異常）。
- 計測: Instruments **Energy Log**、Xcode Organizer のエネルギーペイン、MetricKit の CPU/GPU/時間系メトリクス。

### 計測ツールの使い分け

| 対象 | 開発中（ローカル） | リリース後（フィールド） |
|------|------------------|------------------------|
| 起動時間 | Instruments App Launch / Time Profiler | Organizer Launch Time / MetricKit TimeToFirstDrawMetric |
| ハング | Hangs instrument / Thread Performance Checker | Organizer Hang Rate / MetricKit HangTimeMetric・HangDiagnostic |
| ヒッチ | Animation Hitches テンプレート | MetricKit HitchTimeMetric・ScrollHitchTimeMetric |
| メモリ | Allocations / Leaks / Memory Graph | Organizer / MetricKit PeakMemoryMetric・MemoryExceptionDiagnostic |
| バッテリー | Energy Log | Organizer Energy / MetricKit 時間・CPU/GPU メトリクス |
| ディスク I/O | File Activity | MetricKit LogicalDiskWritesMetric・DiskWriteExceptionDiagnostic |

公式: https://developer.apple.com/documentation/xcode/improving-your-app-s-performance / https://developer.apple.com/documentation/xcode/understanding-hangs-in-your-app / https://developer.apple.com/documentation/xcode/reducing-your-app-s-launch-time

---

## 5. テスト戦略（XCTest / XCUITest / Instruments / 実機）

### 概要

テストは「単体（ロジック）→ パフォーマンス → UI（E2E）」の多層で構成する。最終確認時点では、新規単体テストにSwift Testingを検討し、UIテストとパフォーマンステストにはXCTest / XCUIAutomationを使う構成がApple公式で案内されていた。実装時は対象Xcodeの現行資料で、各テスト種別の対応frameworkと移行条件を再確認する。

### 🔴 必須（遵守事項）

- ビジネスロジックは **XCTestCase（または Swift Testing）による単体テスト**でカバーすること。アサーションは Boolean / Nil / Equality / Comparable / Error 系を目的別に使い分け、非同期は Expectations（XCTest）/ `await` 確認（Swift Testing）で待つ。
- **Swift Testing と XCTest の API を同一テスト内で混在させない**こと（Apple 明記）。移行はテスト単位で行う。
- パフォーマンス回帰を防ぐため、重要経路（起動・主要画面遷移・重い変換処理）に **`measure` 系パフォーマンステスト**（`XCTApplicationLaunchMetric`・`XCTMemoryMetric`・`XCTClockMetric` 等）を置き、**ベースラインを設定して CI で回帰検知**すること。
- UI テストは **XCUIAutomation**（`XCUIApplication` 起動 → `XCUIElementQuery` で要素特定 → `XCUIElement` 操作 → 検証）で主要ユーザーフローを自動化すること。要素特定は `accessibilityIdentifier` を付与して行い、画面上の座標・表示文字列依存を避ける（ローカライズで壊れる）。
- **実機テストを必須とする**こと。パフォーマンス計測・ProMotion・サーマル挙動・カメラ/センサー・メモリ上限・Metal 描画は Simulator では再現しない。サポート最古の低速デバイスと最新デバイスの両端で確認する。
- リリース前に多様な条件でテストすること: 複数デバイスサイズ・両向き回転・iPad の 1/2・1/3・1/4 ウィンドウ・Dynamic Type 最大/最小・ダークモード・RTL ローカライズ。

### 推奨

- テストピラミッドを守る: 単体テスト多数・結合中間・UI テストは重要フローのみ（UI テストは遅く不安定になりやすい）。
- XCUIAutomation の**レコーディング機能**で操作シーケンスの雛形を生成し、クエリを identifier ベースに書き直す。
- 長い UI テストは Activities で段階分割し、失敗時に `XCUIScreenshot` を Attachments として保存する。
- `XCUIDevice` で回転・ホームボタン等を、`launchArguments` / `launchEnvironment` でテスト用構成（モックサーバー URL 等）を注入する。
- 待機は sleep ではなく `waitForExistence(timeout:)` / expectation を使い、フレークテストを避ける。
- TestFlight の Test Information でベータテスターからパフォーマンスフィードバックを収集する。
- Instruments はテンプレートで使い分ける: Time Profiler（CPU / ハング）・Allocations + Leaks（メモリ）・Energy Log（電力）・File Activity（ディスク I/O）・Network（通信）・App Launch（起動）。改善前後で必ず同条件の Before/After プロファイルを取り比較する。

### よくある違反・注意点

- ❌ Simulator の起動時間・フレームレート・メモリ計測値をそのまま品質判断に使う。
- ❌ UI テストで `app.staticTexts["こんにちは"]` のような表示文言依存クエリ（ローカライズ・文言変更で全滅）。
- ❌ パフォーマンステストをベースラインなしで放置（計測するだけで回帰ゲートにならない）。
- ❌ 単体テストが UIKit 層に依存しすぎて Simulator 起動なしで走らない（ロジックはプラットフォーム非依存モジュールに分離する）。

公式: https://developer.apple.com/documentation/xctest / https://developer.apple.com/documentation/xcuiautomation

---

## 6. クラッシュ収集と診断（MetricKit / Xcode Organizer）

### 概要

フィールド（実ユーザー環境）の品質シグナルは 2 系統で収集する。①**Xcode Organizer**: App Store / TestFlight 経由の集計データ（クラッシュ・ハング率・起動時間・エネルギー・ディスク書き込み）をダッシュボードで確認。②**MetricKit**: アプリに組み込み、日次メトリクスと診断ペイロードをプログラムで受信して自社基盤へ送る。両者は排他ではなく併用が標準。

### 🔴 必須（遵守事項）

- **リリースビルドの dSYM（シンボル情報）と Xcode アーカイブを必ず保持する**こと。シンボリケート（16 進アドレス → 関数名・行番号への変換）ができないクラッシュレポートは実質解析不能。
- クラッシュ対応フローを固定化すること: ①シンボル付きでビルド → ②Organizer / デバイスからレポート取得 → ③シンボリケート → ④Exception Type と共通パターン照合 → ⑤修正 + **回帰防止テストを追加**。
- MetricKit を使う場合は `MXMetricManager`（新 API では `MetricManager`）の**デリゲート登録 / 購読を起動時に行う**こと。日次ペイロード（`MXMetricPayload`）と診断ペイロード（`MXDiagnosticPayload`: `MXCrashDiagnostic`・`MXHangDiagnostic`・`MXCPUExceptionDiagnostic`・`MXDiskWriteExceptionDiagnostic` 等）は iOS 15+ で発生後速やかに配信される。
- 🔴 収集データに**個人情報・機密情報をログとして含めてはならない**。ログ・メトリクス送信はプライバシーポリシーおよび App Store のデータ収集開示（Privacy Nutrition Label）と整合させる。
- メモリ起因の強制終了は通常クラッシュとして現れないことがあるため、**Jetsam イベントレポート**と `ForegroundTerminationMetric` / `BackgroundTerminationMetric`（終了理由カテゴリ別カウント）も監視すること。

### 推奨

- Organizer では クラッシュ / ハング率 / 起動時間をデバイスモデル別・アプリバージョン別・パーセンタイル別で見る。リリースごとの悪化を検知したらそのバージョンの差分を疑う。
- 重要ユーザーフローの所要時間は `mxSignpost()`（MetricKit のカスタムシグンポスト）で計測し、日次ヒストグラムとして受け取る。アニメーション区間は `mxSignpostAnimationIntervalBegin()` でヒッチ率を取得できる。
- クラッシュ地点の状況把握には `os_log` / `Logger`（os.log フレームワーク）の構造化ログを併用し、Console.app / デバイスログと突き合わせる。
- 発生端末が手元にない場合、デバイス実機の Settings > Privacy & Security > Analytics & Improvements からユーザーにレポート共有を依頼できる。
- MetricKit ペイロードは JSON 表現（`jsonRepresentation()`）で自社の監視基盤・ダッシュボードに転送し、クラッシュ率・ハング率の閾値アラートを設定する。

### よくある違反・注意点

- ❌ dSYM をアップロード/保管せずリリースし、クラッシュレポートが全て 16 進アドレスのまま。
- ❌ サードパーティのクラッシュ SDK だけに依存し、MetricKit / Organizer が拾う**ハング・ディスク書き込み例外・Jetsam**（クラッシュハンドラでは捕捉できない領域）を見ていない。
- ❌ TestFlight 期間中のクラッシュフィードバック（スクリーンショット付き）を確認せずに審査提出する。
- ❌ クラッシュ修正時に再現テストを書かず、同一リグレッションを繰り返す。

公式: https://developer.apple.com/documentation/metrickit / https://developer.apple.com/documentation/xcode/diagnosing-issues-using-crash-reports-and-device-logs

---

## クイックチェックリスト（実装完了前の確認）

- [ ] セーフエリア相対レイアウトのみ（固定座標・機種名分岐なし）／タップ領域は現行HIGの推奨と入力方式を確認
- [ ] サイズクラスと利用可能サイズで分岐し、iPadの自由なウインドウリサイズ全体で破綻しない
- [ ] 両向き回転対応（固定する場合は左右両ランドスケープ）
- [ ] Mac 実行の可否判定を実施（オプトアウト条件 or キーボード/ポインタ対応）
- [ ] 起動: `didFinishLaunching`を軽量化し、現行Apple資料と実機baselineから目標を設定
- [ ] メインスレッドの長時間ブロックを現行Instrumentsの判定と実機計測で検出
- [ ] ProMotion: フレームレート非依存のアニメーション・必要なら `CADisableMinimumFrameDurationOnPhone`
- [ ] 単体テスト + ベースライン付きパフォーマンステスト + 主要フローの XCUITest
- [ ] 実機（最古サポート機と最新機）で Instruments プロファイル済み
- [ ] dSYM 保管・MetricKit 購読・Organizer のクラッシュ/ハング/起動時間を監視
