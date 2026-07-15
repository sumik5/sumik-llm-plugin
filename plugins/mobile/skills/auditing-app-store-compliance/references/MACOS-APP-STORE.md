# macOS / Mac App Store 固有要件

> 出典: Apple Developer Documentation（Security / Distribution）/ App Review Guidelines（最終確認 2026-07-15）。仕様は更新されるため、実装時は必ず併記の公式 URL で最新版を確認すること。

> 鮮度補正: サンドボックス・公証・Hardened Runtimeの必須/任意の区分、entitlementsの種類、`notarytool`の仕様は2026-07-15時点のスナップショットである。監査実行時はApple公式の現行ページで対象macOSバージョン・配布経路の必須条件を再確認すること。

developing-ios-appsはiOS/iPadOS向けの内容のみを扱い、macOS固有の内容は含まれていない。このファイルはmacOS/Mac App Store配信・Developer ID配布に固有の技術要件を扱う。App Review Guidelines本文のMac App Store条項（2.4.5等）の解説はdeveloping-ios-appsの [APP-STORE-REVIEW.md](../../developing-ios-apps/references/APP-STORE-REVIEW.md) を参照し（別スキル）、このファイルではMac固有の技術実装（サンドボックス/公証/Hardened Runtime）に注力する。

---

## 1. 配布経路の選択（Mac App Store vs Developer ID配布）

### 概要

macOSアプリは2つの配布経路を選択できる。それぞれ審査・技術要件が異なる。

| 配布経路 | 審査 | サンドボックス | 公証 | Hardened Runtime |
|---|---|---|---|---|
| Mac App Store | App Review Guidelines準拠が必須 | 必須 | Apple側の審査プロセスに含まれる | オプション |
| Developer ID配布（App Store外） | App Review Guidelinesの対象外だが、Gatekeeper/公証の要件は別途課される | オプション | 開発者が`notarytool`で明示的に取得する必要がある | 事実上必須の推奨設定 |

### 判定基準

- Developer ID配布を選択しているのに公証プロセスが未実施 → **必須(Blocking)**（Gatekeeperにブロックされ配布不能）
- Mac App Store配信でサンドボックス未対応 → **必須(Blocking)**（提出自体が拒否される）

公式: https://developer.apple.com/jp/app-store/review/guidelines/
公式: https://developer.apple.com/developer-id/

---

## 2. サンドボックス化（App Sandbox）

### 概要

App Sandboxは、アプリがアクセスできるシステムリソースをentitlementsで明示的に宣言した範囲へ制限する仕組み。Mac App Store配信では必須。

### 実装要件

| entitlement | 用途 |
|---|---|
| `com.apple.security.app-sandbox` | サンドボックス自体の有効化（Mac App Store配信では`true`必須） |
| `com.apple.security.network.client` / `.server` | ネットワーク通信（クライアント/サーバー） |
| `com.apple.security.files.user-selected.read-write` | ユーザーが明示的に選択したファイルへの読み書き |
| `com.apple.security.files.bookmarks.app-scope` | サンドボックス下でのファイル参照の永続化（セキュリティスコープブックマーク） |
| `com.apple.security.device.camera` / `.microphone` | カメラ・マイクアクセス |
| `com.apple.security.print` | 印刷機能 |
| `com.apple.security.personal-information.*` | 連絡先・カレンダー等の個人情報アクセス |

entitlementsを宣言すると、対応するProvisioning Profile不要で当該機能へのアクセスが許可される（iOSと異なりMac App Store配信では都度のプロファイル管理は不要）。

### 検査観点

- `ENABLE_APP_SANDBOX`ビルド設定とentitlementsファイルの`com.apple.security.app-sandbox`が一致しているか
- 実装が使用するシステムリソース（ファイルアクセス・ネットワーク・デバイス）に対応するentitlementが宣言されているか（宣言漏れはサンドボックス下で実行時エラーになる）
- 未使用entitlementの宣言残置がないか（過剰宣言はレビュー時に説明を求められることがある）

### 判定基準

- Mac App Store配信で`com.apple.security.app-sandbox`が`false`または未設定 → **必須(Blocking)**
- 実装がファイルアクセス/ネットワーク/デバイスAPIを呼ぶのに対応entitlementが宣言されていない → **必須(Blocking)**（サンドボックス下で実行時に機能しない）

公式: https://developer.apple.com/jp/app-store/review/guidelines/

---

## 3. 公証（Notarization）

### 概要

公証は、Appleのマルウェアスキャンサービスにビルドを提出し、Gatekeeperが信頼するステープル（staple）付きバイナリを得るプロセス。Developer ID配布では開発者自身が明示的に実施する必要がある。

### 実装要件

- `xcrun notarytool submit`でアップロードし、承認後に`xcrun stapler staple`でチケットをバイナリへ添付する
- 旧`altool`によるアップロードは廃止済み（2023年11月）のため、CI/CDスクリプトが`notarytool`ベースになっているか確認する
- Apple ID・app-specific password またはApp Store Connect API Keyでの認証を使用し、資格情報をリポジトリにコミットしない

### 検査観点

- CI設定ファイル（fastlane lane、GitHub Actions workflow等）内で`altool`が残置されていないか
- `notarytool`の認証情報が環境変数・Secretsで管理され、平文でコミットされていないか

### 判定基準

- Developer ID配布のCI/CDが`altool`を使用している → **必須(Blocking)**（廃止済みAPIのため動作しない）
- 公証プロセス自体がCI/CDに組み込まれていない（手動公証のみ） → **推奨**（リリース手順のヒューマンエラーリスク）

公式: https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution
公式: https://developer.apple.com/developer-id/

---

## 4. Hardened Runtime

### 概要

Hardened Runtimeは、コード注入・メモリ改ざん・動的ライブラリの不正な読み込み等を防ぐランタイム保護。Mac App Store提出ではオプションだが、Developer ID配布では事実上必須の推奨設定（公証の前提条件になっている場合がある）。

### 実装要件

- Xcodeビルド設定で`ENABLE_HARDENED_RUNTIME`を有効にする
- 必要なCapability（例: JITコンパイル、署名されていないコードの実行等）がある場合のみ、対応するentitlement（`com.apple.security.cs.*`系）を最小限で宣言する
- サードパーティ動的ライブラリを読み込む場合、Hardened Runtime下での署名要件を満たしているか確認する

### 検査観点

- `ENABLE_HARDENED_RUNTIME`のビルド設定値
- `com.apple.security.cs.*`系entitlementの宣言が実装の必要性と一致しているか（過剰な緩和entitlement、例: `com.apple.security.cs.disable-library-validation`の不必要な使用がないか）

### 判定基準

- Developer ID配布でHardened Runtimeが無効 → **推奨**（公証プロセス自体が求める場合は事実上必須。現行の公証要件を公式で確認する）
- 不要な`com.apple.security.cs.*`緩和entitlementの宣言 → **推奨**（セキュリティ低下・審査時の説明を求められるリスク）

公式: https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution

---

## 5. Mac Catalyst の考慮点

### 概要

iPadアプリをMac向けに移植する場合、Mac Catalystを使う選択肢がある。Catalystアプリは技術的にはmacOSアプリとして扱われ、サンドボックス・entitlements・公証の要件は通常のmacOSアプリと同様に適用される。

### 実装要件

- iPad向けに実装したPrivacy Manifest・Info.plistの権限キーが、Mac環境（カメラ・マイクの扱いの違い、Mac固有の入力方式）でも意味を持つか確認する
- Catalyst特有のAPI差分（未サポートAPI、Mac固有UI慣行との整合）はapplying-apple-higの判断領域であり、本スキルでは技術要件（entitlements・サンドボックス・署名）の観点のみ確認する
- "Designed for iPad on Mac"（Catalystを使わずiPadバイナリをそのままMacで実行する形式）を採用する場合、Mac向けの追加entitlements設定は基本的に不要だが、UI/UX上の対応要否はapplying-apple-higで判断する

### 判定基準

- Mac Catalystターゲットが存在するのにmacOS向けentitlements（サンドボックス等）が未設定 → **必須(Blocking)**（Catalystアプリも通常のmacOSアプリと同じ提出要件が適用される）

公式: https://developer.apple.com/jp/app-store/review/guidelines/

---

## 6. Mac App Store固有のガイドライン条項（詳細はdeveloping-ios-apps参照）

App Review Guidelines 2.4.5（Mac App Store固有要件: Xcodeでのパッケージ化必須・サードパーティインストーラ禁止・自動実行禁止・アップデートはMac App Store経由のみ）の条項本文の解説は developing-ios-apps の [APP-STORE-REVIEW.md](../../developing-ios-apps/references/APP-STORE-REVIEW.md) を参照する（別スキル）。本スキルでは、この条項に対応する技術実装（サンドボックス化・公証・Hardened Runtime）の検査に留める。

公式: https://developer.apple.com/jp/app-store/review/guidelines/
