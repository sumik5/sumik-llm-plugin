# コードベース監査ワークフロー

> 出典: Apple Developer Documentation / App Review Guidelines（最終確認 2026-07-15）。仕様は更新されるため、実装時は必ず併記の公式 URL で最新版を確認すること。

> 鮮度補正: 本文の検査項目・Info.plistキー名・Xcodeビルド設定キー・SDK必須バージョンは2026-07-15時点のスナップショットである。監査実行時はApple Developer Documentationの現行ページで対象キー・設定値・必須条件を再確認し、本ファイルの記述だけで合否を断定しないこと。

このファイルは「ガイドラインが何を求めるか」ではなく、「実際のプロジェクトファイルをどう検査するか」の実務手順を扱う。ガイドライン本文の条項解説は developing-ios-apps の [APP-STORE-REVIEW.md](../../developing-ios-apps/references/APP-STORE-REVIEW.md) を参照する（別スキル）。

---

## 検査対象一覧

| 検査対象 | 検査方法 | 判定区分 |
|---|---|---|
| Info.plist | ファイル読取・キー存在確認 | 必須/推奨 |
| `*.entitlements` | ファイル読取・キー存在確認 | 必須/条件付き必須 |
| project.pbxproj / `*.xcconfig` | grep によるビルド設定値抽出 | 必須/推奨 |
| `PrivacyInfo.xcprivacy` | 存在確認・target membership確認 | 必須（詳細はdeveloping-ios-apps側） |
| ソースコード | grep によるAPI呼び出し検出 | 必須/推奨 |
| App Store Connect側メタデータ | コードから検査不能 | 手動確認要 |

---

## 1. Info.plist の検査

### 概要

Info.plistは審査可否・実行時クラッシュ・輸出コンプライアンスに直結するキーの集合体。存在確認だけで判定できる項目が多い。

### 検査項目

| キー | 検査内容 | 判定 |
|---|---|---|
| `ITSAppUsesNonExemptEncryption` | 存在するか。標準暗号（HTTPS等）のみなら`false`推奨（未設定だと提出毎に輸出コンプライアンス質問が発生） | 推奨 |
| `NS*UsageDescription`（各種） | 使用する保護APIに対応するキーが**存在するか**（文言の質・具体性はdeveloping-ios-appsのPRIVACY.mdで判定） | 必須 |
| `CFBundleShortVersionString` | 前回提出値より大きいか（git履歴や配布記録と突き合わせる） | 必須 |
| `CFBundleVersion` | 同一Versionで再アップロードする場合に増加しているか | 必須 |
| `UIRequiredDeviceCapabilities` | 宣言した機能が実装と一致しているか（過剰宣言は対応端末を不必要に絞る） | 推奨 |
| `LSApplicationCategoryType`（macOS） | Mac App Store提出時に設定されているか | 必須（macOS対象時） |

### 検査コマンド例

```bash
/usr/bin/grep -n "UsageDescription\|ITSAppUsesNonExemptEncryption\|CFBundleShortVersionString\|CFBundleVersion" path/to/Info.plist
```

### 判定基準

- キーが存在しない、かつ対応するAPIをソースコードで呼んでいる → **必須(Blocking)**（実行時クラッシュの原因）
- `ITSAppUsesNonExemptEncryption`未設定 → **推奨**（提出は可能だが毎回の質問が発生）
- バージョン単調増加が確認できない → **必須(Blocking)**（アップロード自体が拒否される）

公式: https://developer.apple.com/jp/app-store/review/guidelines/

---

## 2. Entitlements の検査

### 概要

`*.entitlements`ファイルは、サンドボックス・capability・外部購入リンク等、審査時に実装との整合を問われるcapability宣言の集合体。

### 検査項目

| entitlement | 検査内容 | 判定 |
|---|---|---|
| `com.apple.security.app-sandbox` | macOS Mac App Store配信時に`true`か | 必須（macOS+MAS時） |
| `com.apple.developer.in-app-payments` 等StoreKit関連 | 宣言と実装（後述ソースコード検査）が一致しているか | 必須 |
| External Purchase Link Entitlement | 宣言している場合、対象storefrontの地域判定コードが実装にあるか（[IN-APP-PURCHASE.md](IN-APP-PURCHASE.md)参照） | 必須（該当時） |
| `com.apple.developer.applesignin`（Sign in with Apple） | 宣言している場合、アカウント削除時の`revoke_tokens`呼び出しがソースコードにあるか | 必須（該当時） |
| 未使用capabilityの宣言 | Xcode Signing & Capabilitiesと実装機能を突き合わせ、使っていない宣言がないか | 推奨（過剰宣言はリジェクト要因） |

### 検査コマンド例

```bash
/usr/bin/grep -c "com.apple.security\|com.apple.developer" path/to/*.entitlements
```

### 判定基準

- 実装で使用するcapabilityの宣言漏れ → **必須(Blocking)**（機能が動作しない、または審査時に指摘）
- 未使用capabilityの宣言残置 → **推奨**（削除を推奨。放置しても即リジェクトではないが説明を求められる場合がある）

公式: https://developer.apple.com/jp/app-store/review/guidelines/

---

## 3. Xcodeプロジェクト設定の検査

### 概要

project.pbxprojおよび`*.xcconfig`のビルド設定値は、審査提出条件（SDKバージョン等）とmacOS固有要件（サンドボックス・Hardened Runtime）の両方に関わる。

### 検査項目

| キー | 検査内容 | 判定 |
|---|---|---|
| `IPHONEOS_DEPLOYMENT_TARGET` / `MACOSX_DEPLOYMENT_TARGET` | 対象OSの現行サポート方針と整合するか | 推奨 |
| 使用Xcodeバージョン・SDK | 新規提出・アップデートに必須の現行SDK条件を満たすか（2026年4月よりXcode 26 SDKでのビルドが新規提出・アップデート双方に必須という変更が2026年に案内されている。現行条件は提出時にApple公式で必ず再確認する） | 必須 |
| `ENABLE_APP_SANDBOX`（macOS） | Mac App Store配信時に有効か | 必須（macOS+MAS時、詳細はMACOS-APP-STORE.md） |
| `ENABLE_HARDENED_RUNTIME`（macOS） | Developer ID配布時に有効か（推奨設定） | 推奨（macOS+Developer ID時、詳細はMACOS-APP-STORE.md） |
| `CODE_SIGN_STYLE` | Automatic/Manualの選択とCI運用の整合 | 推奨 |

### 検査コマンド例

```bash
/usr/bin/grep -n "IPHONEOS_DEPLOYMENT_TARGET\|MACOSX_DEPLOYMENT_TARGET\|ENABLE_APP_SANDBOX\|ENABLE_HARDENED_RUNTIME\|CODE_SIGN_STYLE" path/to/project.pbxproj path/to/*.xcconfig
```

### 判定基準

- 提出時点で必須とされるXcode/SDKバージョンより古い設定でビルドされている → **必須(Blocking)**（アップロード自体が拒否される）
- macOS Mac App Store配信でサンドボックス無効 → **必須(Blocking)**

公式: https://developer.apple.com/jp/app-store/review/guidelines/

---

## 4. PrivacyInfo.xcprivacy の存在確認

コードベース監査では**存在確認とtarget membership確認のみ**を行う。理由コード・カテゴリの詳細判定はdeveloping-ios-appsのPRIVACY.mdへ委譲する。

| 検査内容 | 判定 |
|---|---|
| `PrivacyInfo.xcprivacy`がターゲット直下に存在するか | 必須 |
| 依存SDK（Swift Package/XCFramework）側にも同ファイルが同梱されているか | 必須（該当SDKがある場合） |

公式: https://developer.apple.com/jp/app-store/review/guidelines/

---

## 5. ソースコードgrepパターン

### 概要

コード中のAPI呼び出しパターンから、審査対応済みの機能を実装レベルで検出する。存在しない場合は「未実装」または「該当機能なし」を切り分ける。

### 検査パターン

| grepパターン | 検出目的 | 判定 |
|---|---|---|
| `SKPaymentQueue` | 旧StoreKit 1実装の残存（StoreKit 2への移行推奨） | 推奨 |
| `Transaction.currentEntitlements` / `Transaction.updates` | StoreKit 2でのトランザクション検証実装の有無 | 必須（IAPがある場合） |
| `.storeButton(.visible, for: .restorePurchases)` | リストア購入ボタンの実装（詳細はIN-APP-PURCHASE.md） | 必須（IAPがある場合） |
| `AppStore.showManageSubscriptions` | サブスク管理導線の実装 | 必須（サブスクがある場合） |
| `ATTrackingManager` | ATT許可フローの実装有無（Info.plistの`NSUserTrackingUsageDescription`と対で検査） | 必須（トラッキングがある場合） |
| アカウント削除API呼び出し（バックエンドAPI名は対象プロジェクト依存） | アプリ内アカウント削除導線の実装有無 | 必須（アカウント作成機能がある場合） |
| `revoke_tokens` またはSign in with Apple関連の失効処理 | アカウント削除時のトークン失効実装 | 必須（Sign in with Appleがある場合） |

### 検査コマンド例

```bash
/usr/bin/grep -rn "SKPaymentQueue\|Transaction.currentEntitlements\|Transaction.updates\|storeButton(.visible\|showManageSubscriptions\|ATTrackingManager\|revoke_tokens" --include="*.swift" path/to/Sources
```

### 判定基準

- IAP実装（`SKPaymentQueue`または`Transaction`関連）が検出され、かつリストア購入ボタンが検出されない → **必須(Blocking)**（App Review Guidelines 3.1.1違反の典型）
- `NSUserTrackingUsageDescription`がInfo.plistにあるのに`ATTrackingManager`呼び出しが検出されない、またはその逆 → **必須(Blocking)**（宣言と実装の不整合）

公式: https://developer.apple.com/jp/app-store/review/guidelines/

---

## 手動確認チェックリスト（コードから検査不能・App Store Connect側）

以下はコードベース監査の対象外であり、必ず「手動確認要」として分離する。

| 項目 | 確認先 |
|---|---|
| デモアカウントのApp Review情報記載 | App Store Connect の App Review 情報欄 |
| 年齢レーティング（age rating）の設問回答 | App Store Connect のコンテンツ設問 |
| スクリーンショット・プレビュー動画が実機能を反映しているか | App Store Connect のメタデータ画面 |
| 輸出コンプライアンス申告 | App Store Connect の提出フロー内設問 |
| プライバシーラベル（Privacy Nutrition Labels）と実装の一致 | App Store Connect の「Appのプライバシー」 |
| プライバシーポリシーURL・サポートURLの生存確認 | 実URLへのアクセス確認 |
| Paid Applications契約・税務/口座情報の完了 | App Store Connect の契約情報 |

公式: https://developer.apple.com/jp/app-store/review/guidelines/

---

## レポートテンプレート（詳細版）

```markdown
# App Store 審査対応監査レポート

- 監査日: YYYY-MM-DD
- 対象: iPhone / iPad / Mac App Store / Developer ID（該当を明記）
- 提出種別: 新規提出 / アップデート
- 監査したファイル範囲: （リポジトリパス・ターゲット名）

## 必須(Blocking) — 未対応だと提出不能・即リジェクトの対象

| # | 項目 | 検出方法 | 該当ファイル:行 | 対応方法 |
|---|---|---|---|---|
| 1 | ... | grep結果 or ファイル読取結果 | path:line | ... |

## 推奨 — 対応しないとリジェクトリスクが高い、または品質を損なう

| # | 項目 | 理由 | 対応方法 |
|---|---|---|---|
| 1 | ... | ... | ... |

## 手動確認要 — コードから検査不能、App Store Connect等で人手確認が必要

| # | 項目 | 確認先 |
|---|---|---|
| 1 | ... | App Store Connect の... |

## 参照したApple公式URLと確認日

| URL | 確認日 | 対象OS/Xcode |
|---|---|---|
| https://developer.apple.com/jp/app-store/review/guidelines/ | YYYY-MM-DD | ... |

## 仮定・未確認事項

- ...
```

公式: https://developer.apple.com/jp/app-store/review/guidelines/
