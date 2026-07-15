# In-App Purchase 実装レベル準拠（StoreKit 2）

> 出典: Apple Developer Documentation（StoreKit）/ App Review Guidelines（最終確認 2026-07-15）。仕様は更新されるため、実装時は必ず併記の公式 URL で最新版を確認すること。

> 鮮度補正: 本文のAPI名・地域別条件・料率・期間は2026-07-15時点のスナップショットである。特に外部購入リンクの地域別扱いは2025年のEpic Games訴訟に関する裁判所命令を受けた米国ストアフロント向け変更を反映しているが、今後さらに変わる可能性がある。実装・監査時は必ずApple公式の現行ページで対象storefront・条件を再確認すること。

このファイルは「App Review Guidelines 3.1.xが何を求めるか」ではなく、「StoreKit 2でどう実装すれば準拠するか」の実装レベルの内容を扱う。ガイドライン条項の解説自体は developing-ios-apps の [APP-STORE-REVIEW.md](../../developing-ios-apps/references/APP-STORE-REVIEW.md) を参照する（別スキル）。

---

## 1. StoreKit 2 トランザクション検証

### 概要

StoreKit 2はJWS（JSON Web Signature）署名付きのトランザクション情報をApple側で検証済みの形で提供する。自前のレシート検証サーバーを必須としない設計が可能になった。

### 実装要件

| 要件 | 内容 |
|---|---|
| エンタイトルメント確認 | `Transaction.currentEntitlements`を起動時・購入直後に確認し、現在有効な購入を反映する |
| 更新監視 | `Transaction.updates`を監視するリスナーをアプリライフサイクルの早い段階（App起動時）で開始する |
| 署名検証 | JWS形式のトランザクションはStoreKitが自動検証する。サーバー側で独自検証する場合はApp Store Server API/App Store Server Notificationsとの整合を取る |
| 完了処理 | 購入を正しく付与した後、`transaction.finish()`を呼ぶ（呼ばないとトランザクションが未完了のまま残る） |

### 検査観点（コードベース監査から参照）

- `Transaction.currentEntitlements`、`Transaction.updates`の呼び出しがあるか
- `finish()`を呼ばずに握りつぶしているtransactionがないか

### 判定基準

- IAP実装があるのに`Transaction.currentEntitlements`または同等の検証機構が検出できない → **必須(Blocking)**（購入の永続化・複数デバイス反映ができず、2.1完全性違反にもつながる）

公式: https://developer.apple.com/jp/app-store/review/guidelines/
公式: https://developer.apple.com/storekit/

---

## 2. リストア購入ボタンの実装必須性

### 概要

非消費型・自動更新サブスクリプションは、機種変更・再インストール後に購入を復元できる手段が必須。

### 実装要件

- SwiftUIの場合、`.storeButton(.visible, for: .restorePurchases)`モディファイアまたは同等のUI導線を提供する
- UIKitの場合、設定画面等に明示的な「購入を復元」ボタンを配置し、`AppStore.sync()`（StoreKit 2）を呼ぶ
- リストア処理はネットワークエラー時のフィードバック（成功/失敗/該当購入なし）をユーザーに明示する

### 判定基準

- 非消費型/サブスクIAPが実装されているのにリストア導線が検出されない → **必須(Blocking)**（App Review Guidelines 3.1.1の典型的リジェクト理由）

公式: https://developer.apple.com/jp/app-store/review/guidelines/
公式: https://developer.apple.com/storekit/

---

## 3. サブスクリプション管理導線

### 概要

自動更新サブスクリプションのキャンセル・変更は、アプリ内から容易にアクセスできる必要がある。アカウント削除とサブスク解約は別プロセスであることをユーザーに明示する。

### 実装要件

| 手段 | 使い方 |
|---|---|
| `AppStore.showManageSubscriptions(in:)` | アプリ内から直接サブスク管理画面を開く（StoreKit 2 API） |
| `https://apps.apple.com/account/subscriptions` | 上記が使えない場合の代替リンク |

- アカウント削除機能がある場合、削除だけでは課金停止にならないことを削除確認画面で明示し、上記いずれかへの導線を提供する（developing-ios-appsのPRIVACY.md「アカウント削除要件」と対で確認する）

### 判定基準

- サブスクIAPがあるのに管理導線（上記いずれか）が検出されない → **必須(Blocking)**
- アカウント削除機能があるのに、サブスク継続に関する告知・導線がない → **必須(Blocking)**（5.1.1(v)系の指摘対象）

公式: https://developer.apple.com/jp/app-store/review/guidelines/
公式: https://developer.apple.com/storekit/

---

## 4. App Store Server Notifications V2

### 概要

サーバーサイドでサブスクリプションの更新・キャンセル・返金・請求問題をリアルタイムに受信する仕組み。バックエンドを持つアプリでは実装が事実上必須になる。

### 実装要件

- App Store ConnectでNotifications V2のエンドポイントURLを設定する
- 受信するイベント種別（`DID_RENEW`, `EXPIRED`, `REFUND`, `DID_FAIL_TO_RENEW`等。名称は現行ドキュメントで確認する）に応じてサーバー側のエンティトルメント状態を更新する
- JWSで署名された通知の検証を行う

### 検査観点

バックエンド実装は通常このリポジトリの対象外だが、クライアント側にサーバー通知を前提とした状態同期ロジックがあるかを確認する。

### 判定基準

- サブスクIAPがあり、かつサーバーサイドでのエンタイトルメント管理を行っている設計であるにもかかわらずNotifications受信の実装が確認できない → **推奨**（即リジェクトの直接要因ではないが、返金・キャンセル未反映は運用上の重大リスク）

公式: https://developer.apple.com/jp/app-store/review/guidelines/
公式: https://developer.apple.com/storekit/

---

## 5. StoreKit Configuration file によるローカルテスト

### 概要

`.storekit`設定ファイルをXcodeプロジェクトに追加すると、App Store Connectへの実接続なしにIAPフローをSimulator/実機でテストできる。

### 実装要件

- `.storekit`ファイルでテスト用Product ID・価格・トライアル条件を定義する
- Xcode SchemeのStoreKit Configuration設定でこのファイルを指定する
- 購入・リストア・失敗系（支払い保留・キャンセル）のテストシナリオを`.storekit`のトランザクションマネージャで再現する

### 判定基準

- IAPがあるのに`.storekit`ファイルもテスト用Sandboxアカウントでのテスト記録もない → **推奨**（提出可否に直結しないが、審査時のクラッシュ・不具合リスクを高める）

公式: https://developer.apple.com/jp/app-store/review/guidelines/
公式: https://developer.apple.com/storekit/

---

## 6. 無料トライアル・紹介オファー・プロモーションオファーの適格性

### 概要

サブスクリプションの各種オファー（Introductory Offer、Promotional Offer、Offer Code）は、ユーザーごとの適格性判定を実装で正しく扱う必要がある。

### 実装要件

- `Product.SubscriptionInfo.Status`および`Product.SubscriptionInfo.eligibility`（または現行APIの同等プロパティ）で、対象ユーザーが当該オファーに適格かを購入前に判定する
- 同一Apple IDで過去に同じサブスクグループのトライアルを利用済みの場合、再度トライアルを提示しない（Appleのサーバー側判定と実装UIの表示を一致させる）
- オファー内容（期間・価格・提供内容）を購入ボタン近傍に明示する（App Review Guidelines 3.1.2要件との整合）

### 判定基準

- オファー機能があるのに適格性チェックのAPI呼び出しが検出されない → **推奨**（不適格ユーザーへの誤表示はユーザークレーム・返金対応の原因になる）

公式: https://developer.apple.com/jp/app-store/review/guidelines/
公式: https://developer.apple.com/storekit/

---

## 7. 外部購入リンク entitlement（地域別の扱い）

### 概要

2025年、Epic Games訴訟に関する裁判所命令を受け、**米国ストアフロント**のアプリはIAP以外の購入方法へのボタン・外部リンク・CTAを、StoreKit External Purchase Link Entitlementなしで含められるようになった。**米国以外のストアフロント**では引き続き、IAP使用または承認済みのStoreKit External Purchase Link Entitlement申請のいずれかが必要という旧ルールが適用される。

### 実装要件

- アプリが対象ユーザーのストアフロント（`Storefront.current`等の現行API）を判定し、米国ストアフロントの場合のみ外部購入リンクCTAを表示する分岐を実装する
- 米国以外のストアフロントでは、entitlement未申請の状態で外部購入リンク・CTAを表示しない
- entitlementを申請・保有している場合は、Appleが定める開示文言（金額・外部サイトへ遷移する旨の警告表示等）をリンク遷移前に表示する

### 検査観点

- ソースコードでストアフロント判定なしに外部決済リンクを全地域に表示していないか（`Storefront`関連のgrepと外部URL遷移コードの併存を確認する）

### 判定基準

- 外部購入リンクを地域判定なしに全ストアフロントへ表示 → **必須(Blocking)**（米国以外では3.1.1(a)違反、entitlement剥奪・リジェクトの対象）
- entitlementを保有しているのに開示文言が実装されていない → **推奨**

公式: https://developer.apple.com/jp/app-store/review/guidelines/
公式: https://developer.apple.com/documentation/storekit/external-purchase

---

## 8. ルートボックス等ランダム型アイテムの確率開示

### 概要

ガチャ・ルートボックス等、購入結果がランダムに決まるアイテムは、購入前に各アイテムの入手確率を開示することが必須（App Review Guidelines 3.1.1）。

### 実装要件

- 各アイテムの排出確率を購入導線内（購入確認画面またはその手前）でユーザーが確認できるUIを実装する
- 確率表示は実際の抽選ロジックの値と一致させる（サーバー側の実際の確率とUI表示に乖離がないか、実装または運用ドキュメントで裏付けを取る）

### 検査観点

- ガチャ・ルートボックス的なIAP（ランダムアイテム付与）のソースコードパターンが検出された場合、確率表示用のUIコンポーネント・文言リソースの有無を確認する

### 判定基準

- ランダム型アイテムのIAPがあるのに確率表示の実装が検出されない → **必須(Blocking)**

公式: https://developer.apple.com/jp/app-store/review/guidelines/

---

## 9. 消費型/非消費型/自動更新サブスクリプションの区別

### 概要

StoreKitのProduct種別（Consumable / Non-Consumable / Auto-Renewable Subscription / Non-Renewing Subscription）は、実装上の扱い（リストア対象か、エンタイトルメントの永続化方法）が異なる。App Store Connect側のProduct種別設定とクライアント実装の扱いが一致している必要がある。

| 種別 | リストア対象 | 実装上の扱い |
|---|---|---|
| 消費型（Consumable） | 対象外（都度購入） | `Transaction.currentEntitlements`には現れない。購入直後の付与のみ |
| 非消費型（Non-Consumable） | 対象 | `Transaction.currentEntitlements`で永続的に確認可能 |
| 自動更新サブスクリプション | 対象 | `Transaction.currentEntitlements`+期限監視 |
| 非更新サブスクリプション | 対象（アプリ側で期限管理） | 期限切れ判定をアプリ側で自前実装する必要がある |

### 判定基準

- Product種別とリストア/エンタイトルメント実装の扱いが一致していない（例: 非消費型なのにリストア対象から漏れている） → **必須(Blocking)**

公式: https://developer.apple.com/jp/app-store/review/guidelines/
公式: https://developer.apple.com/storekit/

---

## 参考動向（確定情報ではない・監査の合否基準にしない）

開発中の情報として、月額サブスクへの12ヶ月コミットメント、オファーコード刷新、統合されたApp Review提出フロー等の動きが報じられている。これらは確定仕様ではないため、監査レポートの判定根拠には使わず、実装時に公式発表を確認する程度に留める。

公式: https://developer.apple.com/jp/app-store/review/guidelines/
