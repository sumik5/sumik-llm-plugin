# Flutterアプリ開発ガイド

## 目的

このスキルは、Dartで書かれた単一コードベースからiOS・Android・Web・デスクトップ向けにFlutterアプリを新規作成、機能追加、改修、テスト、配布するための判断基準を提供する。対象はFlutterプロジェクトの新規作成、既存アプリへの機能追加、状態管理・アーキテクチャの選定、マルチプラットフォーム対応、パフォーマンス最適化、ストアへのリリース準備である。

## 責務境界

このスキルが担当するもの:

- Flutterプロジェクトのセットアップとプロジェクト構造
- Widget体系、レイアウト、テーマ、アニメーション
- 状態管理（setState、Provider、Riverpod、BLoC/Cubit、Redux、GetX）
- ナビゲーションとルーティング
- ネットワーキング、バックエンド連携（REST、Firebase、GraphQL）、ローカル永続化
- マルチプラットフォーム対応（mobile/web/desktop）、レスポンシブデザイン
- アーキテクチャパターン（Clean Architecture、BLoC、MVVM）
- widget/integrationテスト、パフォーマンス最適化
- pub.devパッケージエコシステムの選定
- ビルド設定、flavor、App Store/Play Storeへの公開

developing-dartが担当するもの:

- Dart言語そのもの（型システム、null safety、コレクション、関数型プログラミング、OOP、generics、非同期処理）
- Dartの`test`パッケージによるユニットテスト、pub/依存管理

Flutterコードを書くタスクでは、Widget・状態管理・アーキテクチャの判断は本スキルが担い、個々のDartコードの書き方（型設計、null安全性、コレクション操作など）で疑問が生じたらdeveloping-dartを参照する。iOS/iPadOS向けのネイティブSwift/SwiftUIアプリはdeveloping-ios-appsとapplying-apple-higが担当し、本スキルとは別物である。FlutterアプリのiOSビルド成果物（Xcodeプロジェクト）を最終提出する際のコードベース監査はauditing-app-store-complianceを使う。

## Source of truthと鮮度

Flutter/Dart公式のオンライン資料を最終的なsource of truthとする。

### 鮮度ルール

次の事項は変動しやすいため、記憶や本スキル内の固定値だけで決定してはならない。

- Flutter/Dart SDKのバージョン、Flutter 3.xの最新マイナーバージョンで導入・非推奨になったAPI
- 各状態管理パッケージ（provider、flutter_riverpod、flutter_bloc、redux、get等）のメジャーバージョンとAPI
- pub.devパッケージの最新バージョン、メンテナンス状況、null safety対応状況
- Firebase SDKのバージョンと設定手順（flutterfire_cli等）
- App Store Connect・Google Play Consoleの提出要件
- Flutter DevToolsの機能とパフォーマンス計測指標

上記を含む作業では、実行時に該当する公式ページを開き、対象Flutter/Dartバージョン、確認日を記録する。reference内のコード例やパッケージ名は、確認日付きの作業用スナップショットである。公式ドキュメントと不一致なら公式を採用し、差異を報告する。pub.devのパッケージページで最終更新日・Nullsafety対応・likesを確認せずに古い、または非推奨のパッケージを提案しない。

### 鮮度記録

変動項目を判断したときは、作業メモまたは完了報告に次を残す。

- 確認日
- 公式URL（flutter.dev / docs.flutter.dev / api.flutter.dev / pub.dev）
- 確認したFlutter/Dart/パッケージのバージョン
- 採用した要件
- referenceとの差異

## 要求強度

すべての記述を同じ強さで扱わない。根拠と影響から次の3段階に分類する。

### 必須

次に該当し、違反するとビルド失敗、実行時クラッシュ、提出不能、データ破損につながる要件。

- null safety前提のsound Dartコード
- `AnimationController`等、`dispose()`が必要なリソースの解放
- 非同期処理後に`BuildContext`を使う前の`context.mounted`確認
- 機密情報（トークン、APIキー）をsecure_storageまたは環境変数で扱うこと
- Reducer/Notifierの純粋性（副作用を混入させない）

必須と記すときは、該当する公式根拠を確認する。本スキルの文言だけを根拠に必須へ格上げしない。

### 原則採用

Flutterが標準として提供する構造、コミュニティの広い合意、保守性と品質の高い既定値。

- 新規プロジェクトでMaterial 3（`useMaterial3: true`）を第一候補にする
- `const`コンストラクタを使えるウィジェットには`const`を付ける
- 単一の状態所有者と一方向のデータフローを保つ
- 状態管理・アーキテクチャは既存プロジェクトの選択に従う

採用しない場合は、製品要件、既存資産、チームの知見と代替策を説明できるようにする。

### 条件付き

対象プラットフォーム、アプリ規模、チーム構成、既存資産で変わる事項。

- 状態管理ソリューションの選択（setState/Provider/Riverpod/BLoC/Redux/GetX）
- アーキテクチャパターンの採用（Clean Architecture/BLoC/MVVM/素朴なlayered）
- ナビゲーション方式（Navigator 1.0/2.0/go_router/auto_route）
- ローカル永続化の選択（shared_preferences/sqflite/hive/drift/secure_storage）
- ターゲットプラットフォームの範囲（mobile only/+web/+desktop）

条件付き項目は、該当条件を先に示すか、AskUserQuestionで確認してから実装する（各referenceの「ユーザー確認の原則」を参照）。

## タスク開始時の前提確認

まず、既存ファイルと依頼内容から次を確定する。発見できる情報をユーザーへ聞き直さない。

| 項目 | 確認内容 |
|---|---|
| 目的 | 新規作成、機能追加、改修、状態管理移行、パフォーマンス改善、リリースのどれか |
| SDK | pubspec.yamlのflutter/dart SDK制約、CIとの差 |
| 対象プラットフォーム | mobile（iOS/Android）、+web、+desktop |
| 状態管理 | 既存プロジェクトで使われているパッケージ（provider/flutter_riverpod/flutter_bloc/redux/get） |
| アーキテクチャ | 既存のレイヤ分離方針（Clean Architecture、BLoC、MVVM、素朴なlayered） |
| ナビゲーション | 既存の採用方式（Navigator、go_router、auto_route） |
| データ | ローカル永続化の対象と既存の採用パッケージ、バックエンドAPI契約 |
| UI | Material/Cupertino、既存テーマ定義 |
| テスト | 既存のテスト種別（unit/widget/integration）とカバレッジ方針 |
| 配布 | 開発、TestFlight/内部テスト、Play Store/App Storeのどの段階か |

不足情報がアーキテクチャ、状態管理、配布可否を変える場合だけ確認する。安全な既定値で進められる場合は、仮定を明記して実装を進める。

## 実行ワークフロー

### 1. 現状を把握する

- pubspec.yamlの依存関係、Flutter/Dart SDK制約を確認する
- lib/main.dartとプロジェクト構造（feature単位かlayer単位か）を確認する
- 既存の状態管理パッケージとアーキテクチャパターンを特定する
- テスト構成（test/、integration_test/）とCI設定を確認する
- 対象プラットフォームディレクトリ（ios/、android/、web/、macos/、windows/、linux/）の有無を確認する

### 2. 変動要件を再確認する

- 採用予定パッケージのpub.devページで最新バージョン・メンテナンス状況を確認する
- Flutter/Dartのバージョンアップで変更されたAPIがないか公式変更履歴を確認する
- バックエンド連携がある場合はAPI契約とFirebase設定を確認する
- 固定値をコードへ写す必要がある場合は確認日を残す

### 3. 技術方針を決める

- 状態管理・ナビゲーション・永続化・アーキテクチャの各分岐を、既存プロジェクトの選択に従うか、未選定ならAskUserQuestionで確認する
- Widgetツリーの構造、状態の所有者を決める
- 必須、原則採用、条件付きに判断を分類する

### 4. 小さい垂直スライスで実装する

- UI、状態、データ、副作用、エラー表示を一つの経路で通す
- widgetテストで主要な状態遷移を再現する
- 単体テストを追加し、必要な統合テストへ広げる

### 5. マルチプラットフォーム品質を検証する

- 対象プラットフォームそれぞれでレイアウトと動作を確認する
- レスポンシブ対応（画面幅・向きの変化）を確認する
- パフォーマンス（不要な再構築、フレームレート）をDevToolsで確認する

### 6. テストとビルドを閉じる
- 単体・widget・integrationテストを実行する
- リリースビルド設定（flavor、署名）を確認する
- ストア提出要件（メタデータ、アイコン、権限説明）を確認する

## 各トピックの要約

### Widget・レイアウト・テーマ

StatelessWidget/StatefulWidgetの使い分け、Widgetツリーと`BuildContext`、Material/Cupertinoの選択、Row/Column/Stackと制約（constraints）モデル、`ThemeData`によるスタイリング、暗黙的/明示的アニメーションを扱う。詳細は [references/WIDGETS-LAYOUT-THEMING.md](references/WIDGETS-LAYOUT-THEMING.md) を参照する。

### 状態管理

ローカル状態とアプリ状態の区別、setState、Provider、Riverpod、BLoC/Cubit、Redux、GetXそれぞれの実装パターンと比較、選択判断を扱う。詳細は [references/STATE-MANAGEMENT.md](references/STATE-MANAGEMENT.md) を参照する。

### ナビゲーションとルーティング

Navigator 1.0（命令的）、Navigator 2.0（Router API、宣言的）、go_router、auto_routeの選択と実装、deep link対応を扱う。詳細は [references/NAVIGATION-ROUTING.md](references/NAVIGATION-ROUTING.md) を参照する。

### ネットワークと永続化

http/dioによるHTTP通信、REST/GraphQL連携、Firebase（Auth/Firestore）統合、ローカル永続化（shared_preferences/sqflite/hive/drift/secure_storage）の選択を扱う。詳細は [references/DATA-NETWORKING.md](references/DATA-NETWORKING.md) を参照する。

### アーキテクチャパターン

Clean Architecture、BLoCアーキテクチャ、MVVM、レイヤ分離とアーキテクチャ選択判断を扱う。詳細は [references/ARCHITECTURE-PATTERNS.md](references/ARCHITECTURE-PATTERNS.md) を参照する。

### マルチプラットフォーム・テスト・パフォーマンス

mobile/web/desktopのプラットフォーム差分、レスポンシブデザイン、widget/integrationテスト、rebuild削減や`const`化を含むパフォーマンス最適化を扱う。詳細は [references/MULTIPLATFORM-TESTING-PERFORMANCE.md](references/MULTIPLATFORM-TESTING-PERFORMANCE.md) を参照する。

### パッケージ・ビルド・リリース

pub.dev主要パッケージのカテゴリ別選定、リリースビルド、flavor設定、App Store/Play Store公開手順を扱う。詳細は [references/PACKAGES-BUILD-RELEASE.md](references/PACKAGES-BUILD-RELEASE.md) を参照する。

## Referenceルーティング

| タスク | 読むreference |
|---|---|
| Widget選定、レイアウト、テーマ、アニメーション | [WIDGETS-LAYOUT-THEMING.md](references/WIDGETS-LAYOUT-THEMING.md) |
| 状態管理ソリューションの選択と実装 | [STATE-MANAGEMENT.md](references/STATE-MANAGEMENT.md) |
| 画面遷移、ルーティング、deep link | [NAVIGATION-ROUTING.md](references/NAVIGATION-ROUTING.md) |
| HTTP通信、Firebase連携、ローカル永続化 | [DATA-NETWORKING.md](references/DATA-NETWORKING.md) |
| レイヤ分離、アーキテクチャ選定 | [ARCHITECTURE-PATTERNS.md](references/ARCHITECTURE-PATTERNS.md) |
| マルチプラットフォーム対応、テスト、性能最適化 | [MULTIPLATFORM-TESTING-PERFORMANCE.md](references/MULTIPLATFORM-TESTING-PERFORMANCE.md) |
| パッケージ選定、ビルド設定、ストア公開 | [PACKAGES-BUILD-RELEASE.md](references/PACKAGES-BUILD-RELEASE.md) |
| Dart言語仕様（型、null safety、コレクション、非同期、OOP） | developing-dart（別スキル） |
| iOS/iPadOSネイティブアプリ、Apple HIG判断 | developing-ios-apps / applying-apple-hig（別スキル） |
| Flutterアプリのビルド成果物（Xcodeプロジェクト）の提出監査 | auditing-app-store-compliance（別スキル） |

referenceはすべてINSTRUCTIONS.mdから1階層で到達する。referenceから別referenceをたどる前提にしない。

## 公式の入口

- Flutter Documentation: https://docs.flutter.dev/
- Flutter公式サイト: https://flutter.dev/
- Flutter API Reference: https://api.flutter.dev/
- Dart公式サイト: https://dart.dev/
- pub.dev（パッケージ検索）: https://pub.dev/
- Flutter DevTools: https://docs.flutter.dev/tools/devtools/overview
- Firebase for Flutter: https://firebase.google.com/docs/flutter/setup
- Flutter Testing: https://docs.flutter.dev/testing
- Flutter Performance: https://docs.flutter.dev/perf
- App Store Connect Help: https://developer.apple.com/jp/help/app-store-connect/
- Google Play Console Help: https://support.google.com/googleplay/android-developer/

## 実装完了ゲート

- [ ] 対象プラットフォーム、既存の状態管理・アーキテクチャを確認した
- [ ] 状態管理・ナビゲーション・永続化・アーキテクチャの未選定分岐をAskUserQuestionで確認した（既存プロジェクトはその選択に従った）
- [ ] StatelessWidget/StatefulWidgetを適切に使い分け、`const`を活用した
- [ ] 非同期処理後の`BuildContext`使用前に`context.mounted`を確認した
- [ ] `AnimationController`等のリソースを`dispose()`で解放している
- [ ] loading/error/dataの状態を網羅的に扱った
- [ ] 単体・widgetテストを追加し、必要な範囲でintegrationテストを行った
- [ ] 対象プラットフォームそれぞれでレイアウトを確認した
- [ ] 機密情報をsecure_storage/環境変数で扱っている
- [ ] 既存機能と既存データを破壊していない

## レビュー報告形式

完了報告には次を含める。

1. 対象プラットフォーム、Flutter/Dartバージョン、既存の状態管理・アーキテクチャ方針
2. 必須、原則採用、条件付きの判断（AskUserQuestionでの確認結果を含む）
3. 実装した状態管理、データフロー、レイヤ構造
4. テスト（unit/widget/integration）と対象プラットフォームでの確認結果
5. 参照した公式URLと確認日
6. 仮定、未確認事項、残るリスク

## 禁止事項

- Flutter/Dart公式以外の二次資料を規範根拠にする
- 古いFlutter/Dart APIやパッケージバージョンを固定知識で断定する
- 状態管理・アーキテクチャ・永続化の未選定分岐を推測で決め、AskUserQuestionを省略する
- `BuildContext`を`async`処理をまたいで`mounted`確認なしに使う
- `AnimationController`やStreamSubscriptionの解放を省略する
- Reducer/Notifier/Blocのロジックに副作用を混入させ、テスト困難にする
- 単一プラットフォーム（例: mobileのみ）を前提に、要求されたweb/desktop対応を省略する
- 機密情報をshared_preferencesや平文で保存する
- widget/integrationテストを行わずにリリースビルドの完了を報告する
