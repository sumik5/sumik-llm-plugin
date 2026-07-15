# Dart言語開発ガイド

## 目的

このスキルは、Dart言語そのもの（構文、型システム、null安全性、関数型・オブジェクト指向の両スタイル、非同期処理、コレクション操作、エラー処理、テスト、パッケージ管理、ツールチェーン）を対象に、コードを書く・レビューする・修正するときの判断基準を提供する。対象は新規Dartコードの作成、既存Dartコードの改修・リファクタリング、null安全性への移行、型設計の見直し、Dartパッケージ（プレーンなDartライブラリ・CLIツール・サーバーサイドDart）の開発である。

## 責務境界

このスキルが担当するもの:

- Dartの型システム、null安全性、変数、コレクション（List/Set/Map/Iterable）
- 関数、クロージャ、高階関数、関数合成
- クラス、コンストラクタ、継承、mixin、generics、enum、extension methods
- 非同期処理（Future、Stream、async/await、isolate）
- エラー処理、デバッグ、`test` パッケージによるテスト
- `pub`（パッケージマネージャ）、`pubspec.yaml`、依存管理
- Dart CLI・Webランタイム、Dart SDKツール（analyzer、formatter、DartPad）

developing-flutter-appsが担当するもの:

- Flutterの Widget システム、レイアウト、テーマ、アニメーション
- 状態管理（Provider、Riverpod、BLoC等）、ナビゲーション・ルーティング
- Flutterアプリのネットワーキング、ローカル永続化
- マルチプラットフォーム対応（iOS/Android/Web/デスクトップ）、Flutterのビルドとストア公開

Flutterプロジェクト（`pubspec.yaml` に `flutter` SDK依存がある）でDartの言語仕様（null安全性、型設計、関数・クラスの構造）について判断が必要な場合は、本スキルとdeveloping-flutter-appsを併用する。Widget実装やUIレイアウトのタスクでは、まず本スキルで型・関数・クラスの設計を固め、UIの構築はdeveloping-flutter-appsに委ねる。

## Source of truthと鮮度

Dart公式のオンライン資料を最終的なsource of truthとする。

- 言語仕様・チュートリアル: https://dart.dev/
- API リファレンス: https://api.dart.dev/
- パッケージエコシステム: https://pub.dev/

### 鮮度ルール

次の事項は言語バージョンやツールの更新で変わりやすいため、記憶や本スキル内の固定値だけで決定してはならない。

- 現在のDart SDKの安定版バージョンと言語バージョン（`// @dart=X.Y` の対象）
- 各言語機能（パターンマッチング、レコード型、クラス修飾子等）の導入バージョンと利用可否
- `pub` コマンドの現行オプション、`pubspec.yaml` のスキーマ
- リンター（`analysis_options.yaml`）の推奨ルールセット
- `test` パッケージ・非同期APIの現行の推奨パターン

上記を含む作業では、対象プロジェクトの `pubspec.yaml` の `environment.sdk` 制約と、実行環境の `dart --version` を確認し、確認した内容を作業メモまたは完了報告に残す。本リファレンス内のコード例は現行Dart 3.x（sound null safety前提）を基準にしているが、プロジェクトのSDK制約がこれより古い場合は、その制約に合わせて機能の利用可否を判断する。

## 要求強度

すべての記述を同じ強さで扱わない。

### 必須

- sound null safetyの前提を破らない（`dynamic` の濫用や不要な `!` でその場しのぎをしない）
- 公開APIの引数・戻り値には型を明示する
- 例外を握りつぶさず、catchした例外は再送出するか意味のある処理につなげる

### 原則採用

- 再代入しない変数は `final`／`const` を既定にする
- 名前付きパラメータで呼び出し側の可読性を確保する
- コレクション操作は `for` ループと高階関数（`map`／`where`／`fold`）を状況に応じて使い分ける
- 公開APIには `///` ドキュメンテーションコメントを付ける

採用しない場合は、既存コードとの整合性やパフォーマンス制約等の理由を説明できるようにする。

### 条件付き

- `late` の使用（初期化順序の保証が本当に成立するか要確認）
- `dynamic` の使用（外部データのデコード直後等、限定箇所のみ）
- カリー化・関数合成の多用（可読性とのトレードオフ）
- isolateの導入（重い計算処理がUIスレッド／メインイベントループを圧迫する場合のみ）

## タスク開始時の前提確認

既存ファイルと依頼内容から次を確定する。発見できる情報をユーザーへ聞き直さない。

| 項目 | 確認内容 |
|---|---|
| 目的 | 新規実装、改修、リファクタリング、null安全性移行、パフォーマンス改善のどれか |
| 実行環境 | プレーンなDart CLI、サーバーサイドDart、Flutterアプリ内のDartコードのどれか |
| SDK制約 | `pubspec.yaml` の `environment.sdk`、`dart --version` |
| 既存の型設計 | 既存クラス・enum・genericsの構造、命名規則 |
| null安全性 | 既存コードがすでにsound null safetyへ移行済みか |
| 非同期処理 | 既存の `Future`/`Stream` の扱い方、エラー処理方針 |
| テスト | 既存テストの有無、`test` パッケージの利用状況 |
| 依存パッケージ | `pubspec.yaml` の依存関係、pub.devの利用パッケージ |
| Lint設定 | `analysis_options.yaml` の有無とルールセット |
| Flutter有無 | `pubspec.yaml` に `flutter:` SDK依存があるか（あればdeveloping-flutter-appsも併用） |

不足情報が型設計や公開APIの契約を変える場合だけ確認する。安全な既定値で進められる場合は、仮定を明記して実装を進める。

## 実行ワークフロー

### 1. 現状を把握する

- `pubspec.yaml` の `environment.sdk`、依存パッケージ、`flutter:` 依存の有無を確認する
- `analysis_options.yaml` のリンタールールを確認する
- 既存の型設計（クラス階層、generics、enum）と命名規則を確認する
- 既存の非同期処理・エラー処理のパターンを確認する
- 既存テスト（`test/` ディレクトリ、`test` パッケージの利用）を確認する

### 2. 変動要件を再確認する

- 採用したい言語機能がプロジェクトのSDK制約で利用可能か dart.dev で確認する
- 依存を追加する場合はpub.devで現行の推奨パッケージ・メンテナンス状況を確認する

### 3. 技術方針を決める

- null安全性を前提に、値が「常に存在する」か「存在しないことがある」かを型で表現する
- 関数型スタイル（高階関数・クロージャ）とOOPスタイル（クラス・継承）のどちらが適切かを判断する
- 非同期処理の失敗時動作（リトライ、タイムアウト、キャンセル）を決める
- 必須、原則採用、条件付きに判断を分類する

### 4. 小さい単位で実装する

- 型・関数・クラスのシグネチャを先に決め、実装の詳細を埋める
- 主要な分岐（成功・失敗・null・空コレクション）を単体テストで再現する
- `dart format` と `dart analyze` を通す

### 5. 品質を検証する

- `dart test` でユニットテストを実行する
- `dart analyze` で静的解析の警告・エラーがないことを確認する
- 例外・null安全性の境界（外部入力、非同期処理の失敗）を再確認する

## 各トピックの要約

### 型・変数・文字列・演算子（LANGUAGE-BASICS.md）

Dartの基本型（`int`/`double`/`String`/`bool`/コレクション型）、`var`/`final`/`const` の使い分け、型推論とnull安全性の基礎、文字列補間と`StringBuffer`、算術・論理・null関連演算子、コメントとクリーンコードの命名規則を扱う。すべてのDartコードの土台となるため、最初に読むべきリファレンスである。

### 関数と関数型プログラミング（FUNCTIONS-AND-FP.md）

関数宣言、位置パラメータ・名前付きパラメータ・省略可能パラメータと既定値、匿名関数、クロージャとレキシカルスコープ、高階関数、関数合成とカリー化を扱う。コールバックベースのAPI設計やコレクション操作の可読性判断に関わる。

### クラスとオブジェクト指向（OOP-AND-CLASSES.md）

クラス定義、コンストラクタ（named constructor、factory constructor）、継承と多態、abstract class とinterfaceとしてのクラス実装、mixin、カプセル化（ライブラリプライベート）、staticメンバーを扱う。ドメインモデルの設計や既存クラス階層の拡張時に参照する。

### 高度な型システム（ADVANCED-TYPES.md）

generics（型パラメータ、境界制約）、enum（拡張enumを含む）、extension methods、演算子オーバーロード、`late`、null安全性の応用（`!`の是非、nullable連鎖）、`Object`/`dynamic` の使い分けを扱う。型安全性を高めたい設計や、既存クラスを拡張したい場面で参照する。

### 非同期処理とコレクション（ASYNC-AND-COLLECTIONS.md）

`Future`/`Stream`、`async`/`await`、isolateによる並行処理、`List`/`Set`/`Map`/`Iterable`、コレクションリテラルとspread演算子、`where`/`map`/`reduce`/`fold` 等の操作を扱う。I/O待ちを伴う処理やデータ変換パイプラインの設計時に参照する。

### エラー処理・テスト・ツール（ERRORS-TESTING-TOOLING.md）

例外とスタックトレース、デバッグ手法、`test` パッケージによるユニットテスト、`pub` によるパッケージ管理と自作パッケージの公開、Dart CLI・Webランタイムの違い、Dart SDKツール（DartPad、analyzer、formatter）を扱う。品質保証やパッケージ運用のタスクで参照する。

## Referenceルーティング

| タスク | 読むreference |
|---|---|
| 型、変数と定数、文字列、数値、論理演算、演算子、コメント、クリーンコードの命名 | [LANGUAGE-BASICS.md](references/LANGUAGE-BASICS.md) |
| 関数宣言、パラメータ設計、クロージャ、高階関数、関数合成 | [FUNCTIONS-AND-FP.md](references/FUNCTIONS-AND-FP.md) |
| クラス設計、コンストラクタ、継承、mixin、カプセル化 | [OOP-AND-CLASSES.md](references/OOP-AND-CLASSES.md) |
| generics、enum、extension methods、演算子オーバーロード、`late`、null安全性の応用 | [ADVANCED-TYPES.md](references/ADVANCED-TYPES.md) |
| Future/Stream、async/await、isolate、コレクション操作 | [ASYNC-AND-COLLECTIONS.md](references/ASYNC-AND-COLLECTIONS.md) |
| 例外処理、デバッグ、テスト、pub/パッケージ管理、CLI/Webランタイム、ツール | [ERRORS-TESTING-TOOLING.md](references/ERRORS-TESTING-TOOLING.md) |
| Flutter Widget、状態管理、ナビゲーション、Flutterアプリのビルド・配布 | developing-flutter-apps（別スキル） |
| Apple公式HIGに基づくUI/UX判断、native iOS/iPadOS実装 | developing-ios-apps / applying-apple-hig（別スキル） |

referenceはすべてINSTRUCTIONS.mdから1階層で到達する。referenceから別referenceをたどる前提にしない。

## Dart公式の入口

- Dart公式サイト: https://dart.dev/
- 言語ツアー: https://dart.dev/language
- APIリファレンス: https://api.dart.dev/
- pub.dev（パッケージエコシステム）: https://pub.dev/
- DartPad（ブラウザ上の実行環境）: https://dartpad.dev/
- Effective Dart（スタイルガイド）: https://dart.dev/effective-dart
- null安全性ガイド: https://dart.dev/null-safety

## 実装完了ゲート

- [ ] 対象コードのSDK制約（`pubspec.yaml` の `environment.sdk`）を確認した
- [ ] null安全性を前提に、値の存在・非存在を型で表現した
- [ ] 公開API（関数・メソッドのシグネチャ）に型を明示した
- [ ] 例外を握りつぶさず、適切に再送出またはハンドリングした
- [ ] 非同期処理の失敗・キャンセル・タイムアウトを扱った
- [ ] コレクション操作は可読性を踏まえて `for` ループと高階関数を使い分けた
- [ ] `dart analyze` の警告・エラーがない
- [ ] `dart format` でフォーマット済みである
- [ ] 主要な分岐（成功・失敗・null・空コレクション）を単体テストで確認した
- [ ] 既存コードの命名規則・型設計との整合性を確認した

## レビュー報告形式

完了報告には次を含める。

1. 対象範囲（プレーンDart / サーバーサイドDart / Flutter内のDartコード）とSDK制約
2. 必須、原則採用、条件付きの判断
3. 実装した型設計、null安全性の扱い、非同期処理の方針
4. `dart analyze`・`dart test` の結果
5. 参照したDart公式URLと確認日（言語バージョンに依存する判断がある場合）
6. 仮定、未確認事項、残るリスク

## 禁止事項

- `dynamic` を型設計の代わりに安易に使う
- `!`（null非許容キャスト）で場当たり的にnullチェックを回避する
- 例外を空の `catch` ブロックで握りつぶす
- 古い言語バージョンの機能可否を固定知識で断定する（プロジェクトのSDK制約を確認せずに新しい構文を使う）
- Flutter固有のUI・状態管理・ナビゲーションの判断をこのスキルだけで完結させる（developing-flutter-appsを併用しない）
- ソースの丸コピーによるコード生成（このスキル自体もクリーンな新規コード例のみを収録している）
