# App Store 審査対応コードベース監査ガイド

## 目的

このスキルは、iPhone・iPad・Mac向けアプリのコードベースを実地に検査し、App Store提出（新規提出・アップデート）の可否を判定するための監査ワークフローとレポート形式を提供する。対象は提出直前の最終チェック、リリース判断、既存コードベースの審査対応状況の棚卸しである。

「ガイドラインが何を求めるか」を解説することが目的ではない。**実際のプロジェクトファイルを検査し、pass/fail/要確認を判定するアクション**が目的である。

## 責務境界

このスキルが担当するもの:

- Info.plist、entitlements、Xcodeプロジェクト設定（project.pbxproj/xcconfig）の実地検査
- ソースコードgrepによるIAP実装・ATT・アカウント削除等の実装検出
- StoreKit 2でのIn-App Purchase実装レベル準拠（トランザクション検証、リストア購入、サブスク管理導線、外部購入リンク等）
- macOS / Mac App Store固有の技術要件（サンドボックス、entitlements、公証、Hardened Runtime、配布経路選択）
- 上記を統合した「必須(Blocking)/推奨/手動確認要」の3段階判定レポートの作成

developing-ios-appsが担当するもの（本スキルでは再解説しない）:

- App Review Guidelines本文の5章構成・条項の解説
- Privacy Manifest・Required Reason API・App Privacyの詳細
- コード署名・TestFlight・App Store Connectの操作手順
- SwiftUI/UIKit・architecture・lifecycle等の技術設計判断

applying-apple-higが担当するもの（本スキルでは扱わない）:

- HIGに基づく画面構成、ナビゲーション、コンポーネント、アクセシビリティのUI/UX判断

監査対象プロジェクトの技術設計やUI判断に踏み込む必要が生じた場合は、判定結果に「developing-ios-apps / applying-apple-higを参照して対応要」と記載し、本スキル内で解説を書き足さない。

## Source of truthと鮮度

developing-ios-appsと同じ鮮度ルールを適用する。App Review Guidelinesの条項番号、IAPの地域別条件、macOSの配布要件は変動するため、本スキルとreferencesの記述は確認時点のスナップショットである。監査実行時は必ず該当するApple公式ページを確認し、レポートに確認日を記録する。

## 前提確認

監査を始める前に、依頼内容と対象プロジェクトから次を確定する。発見できる情報をユーザーへ聞き直さない。

| 項目 | 確認内容 |
|---|---|
| 対象プラットフォーム | iPhone、iPad、Mac（Mac App Store / Developer ID）、Mac Catalystのどれを含むか |
| 提出種別 | 新規提出、アップデート、既存アプリの棚卸しのどれか |
| IAPの有無 | 消費型/非消費型/自動更新サブスクリプションの有無、外部購入リンクの使用有無 |
| プロジェクト形態 | Xcodeプロジェクトの実ファイルへアクセス可能か、リポジトリのどの範囲を監査対象にするか |
| 既存監査 | developing-ios-appsの実装完了ゲート・リリース完了ゲートを通過済みか |

## 監査ワークフロー

### 1. 対象を棚卸しする

- Info.plist、`*.entitlements`、project.pbxproj/xcconfig、`PrivacyInfo.xcprivacy`の所在を確認する
- IAP関連コード（StoreKit呼び出し）の有無をgrepで確認する
- macOSターゲットの有無、Mac Catalystの有無を確認する
- 詳細な検査手順は [references/CODEBASE-AUDIT.md](references/CODEBASE-AUDIT.md) を参照する

### 2. コードベースを検査する

[references/CODEBASE-AUDIT.md](references/CODEBASE-AUDIT.md) の検査項目表に従い、Info.plist・entitlements・プロジェクト設定・ソースコードを個別に検査し、各項目を「必須(Blocking)」「推奨」「手動確認要」に分類する。

### 3. IAPを実装している場合はStoreKit 2準拠を確認する

IAP実装がある場合、[references/IN-APP-PURCHASE.md](references/IN-APP-PURCHASE.md) に従い、トランザクション検証・リストア購入・サブスク管理導線・外部購入リンクの地域判定等を確認する。

### 4. macOSターゲットがある場合はMac固有要件を確認する

macOSターゲット（Mac App Store配信またはDeveloper ID配布）がある場合、[references/MACOS-APP-STORE.md](references/MACOS-APP-STORE.md) に従い、サンドボックス、entitlements、公証、Hardened Runtimeを確認する。

### 5. コードで検査できない項目を手動確認チェックリストへ分離する

App Store Connect側のメタデータ（デモアカウント記載、年齢レーティング、スクリーンショット、輸出コンプライアンス申告等）はコードから検査できない。[references/CODEBASE-AUDIT.md](references/CODEBASE-AUDIT.md) の手動確認チェックリストへ明示的に分離し、レポートの「手動確認要」区分にまとめる。

### 6. レポートを作成する

以下の形式で判定結果を出力する。テンプレートの詳細は [references/CODEBASE-AUDIT.md](references/CODEBASE-AUDIT.md) を参照する。

```markdown
# App Store 審査対応監査レポート

- 監査日: YYYY-MM-DD
- 対象: iPhone / iPad / Mac App Store / Developer ID（該当を明記）
- 提出種別: 新規提出 / アップデート

## 必須(Blocking) — 未対応だと提出不能・即リジェクトの対象
- [ ] 項目、検出方法、該当ファイル:行、対応方法

## 推奨 — 対応しないとリジェクトリスクが高い、または品質を損なう
- [ ] 項目、理由、対応方法

## 手動確認要 — コードから検査不能、App Store Connect等で人手確認が必要
- [ ] 項目、確認先

## 参照したApple公式URLと確認日
- URL、確認日、対象OS/Xcode

## 仮定・未確認事項
```

## Referenceルーティング

| タスク | 読むreference |
|---|---|
| Info.plist/entitlements/プロジェクト設定/ソースコードの実地検査、手動確認チェックリスト、レポートテンプレート | [CODEBASE-AUDIT.md](references/CODEBASE-AUDIT.md) |
| StoreKit 2実装レベル準拠（トランザクション検証、リストア購入、サブスク管理、外部購入リンク、確率開示） | [IN-APP-PURCHASE.md](references/IN-APP-PURCHASE.md) |
| macOS/Mac App Store固有要件（サンドボックス、entitlements、公証、Hardened Runtime、配布経路選択） | [MACOS-APP-STORE.md](references/MACOS-APP-STORE.md) |
| App Review Guidelines本文、条項の解説、リジェクト理由と対策 | developing-ios-apps の [APP-STORE-REVIEW.md](../developing-ios-apps/references/APP-STORE-REVIEW.md)（別スキル） |
| Privacy Manifest、Required Reason API、ATT、権限、アカウント削除の詳細実装 | developing-ios-apps の [PRIVACY.md](../developing-ios-apps/references/PRIVACY.md)（別スキル） |
| 署名、App Store Connect操作、TestFlight、バージョニング | developing-ios-apps の [DISTRIBUTION.md](../developing-ios-apps/references/DISTRIBUTION.md)（別スキル） |

referenceはすべてINSTRUCTIONS.mdから1階層で到達する。

## Apple公式の入口

- App Review Guidelines: https://developer.apple.com/jp/app-store/review/guidelines/
- StoreKit: https://developer.apple.com/storekit/
- External Purchase (US): https://developer.apple.com/documentation/storekit/external-purchase
- Notarizing macOS Software: https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution
- Developer ID: https://developer.apple.com/developer-id/

## 監査完了ゲート

- [ ] 対象プラットフォーム（iPhone/iPad/Mac）と提出種別を確認した
- [ ] Info.plist、entitlements、プロジェクト設定を実地検査した
- [ ] ソースコードgrepでIAP実装・ATT・アカウント削除の有無を確認した
- [ ] IAPがある場合、StoreKit 2実装レベル準拠を確認した
- [ ] macOSターゲットがある場合、サンドボックス・公証・Hardened Runtimeを確認した
- [ ] コードで検査不能な項目を手動確認チェックリストへ分離した
- [ ] 判定結果を必須(Blocking)/推奨/手動確認要の3段階でレポート化した
- [ ] 参照したApple公式URLと確認日を記録した
- [ ] 判定に用いた条項番号・数値が確認時点のスナップショットである旨を明記した

## 禁止事項

- App Review Guidelines本文・Privacy Manifest詳細・署名手順をこのスキル内で再解説する（developing-ios-appsへ委譲する）
- HIGに基づくUI/UX判断をこのスキル内で行う（applying-apple-higへ委譲する）
- コードで検査不能なApp Store Connect側の項目を「検査済み」として扱う
- 条項番号・数値・地域別条件を固定知識として断定し、公式確認を省略する
