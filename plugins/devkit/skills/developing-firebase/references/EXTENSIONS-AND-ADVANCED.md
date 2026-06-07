# Firebase Extensions・AdMob・クロスプラットフォーム

## 1. AdMob — モバイルアプリ収益化

AdMob は Google のモバイル広告プラットフォーム。Firebase プロジェクトとリンクして Firebase Console から管理する。

### 1-1. 広告フォーマット選択

| フォーマット | 特徴 | 最適な用途 |
|------------|------|-----------|
| **Banner** | 画面上/下に常時表示（非侵入的） | コンテンツ量の多いアプリ |
| **Interstitial** | 全画面・自然な区切りで表示 | ゲームのレベル遷移・画面切替 |
| **Rewarded** | ユーザーが任意で視聴 → 報酬獲得 | ゲーム内アイテム・プレミアム解放 |
| **Native** | アプリUIに溶け込むカスタム広告 | 高い UX が求められるアプリ |

### 1-2. SDK セットアップ

```kotlin
// Android (Kotlin) — build.gradle
implementation("com.google.android.gms:play-services-ads:22.6.0")

// Application.onCreate()
MobileAds.initialize(this) {}

// バナー広告
val adView = AdView(context).apply {
    setAdSize(AdSize.BANNER)
    adUnitId = "ca-app-pub-xxxx/yyyy"  // テスト: "ca-app-pub-3940256099942544/6300978111"
    loadAd(AdRequest.Builder().build())
}

// インタースティシャル
InterstitialAd.load(context, adUnitId, AdRequest.Builder().build(),
    object : InterstitialAdLoadCallback() {
        override fun onAdLoaded(ad: InterstitialAd) { ad.show(activity) }
    })
```

```swift
// iOS (Swift)
GADMobileAds.sharedInstance().start(completionHandler: nil)  // AppDelegate

let banner = GADBannerView(adSize: GADAdSizeBanner)
banner.adUnitID = "ca-app-pub-xxxx/yyyy"
banner.rootViewController = self
banner.load(GADRequest())
```

### 1-3. 収益化ベストプラクティス

- **Rewarded を優先**: ユーザー体験を損なわず高い eCPM を実現
- **自然な遷移点に配置**: Interstitial の強制表示は禁止
- **テスト ID 必須**: 開発中は本番 ID での自己クリック禁止（アカウント停止リスク）
- **Analytics 連携**: ユーザーセグメント別収益分析で広告配置を最適化

---

## 2. Firebase Extensions

### 2-1. Extensions とは

Cloud Functions ベースのプリビルト機能パッケージ。カスタムコード不要で一般的なタスクを自動化できる。

```bash
firebase ext:install <publisher>/<extension-name>  # インストール
firebase ext:list                                   # 一覧表示
firebase deploy --only extensions                   # デプロイ
firebase ext:uninstall <instance-id>                # 削除
```

### 2-2. 主要 Extensions カタログ

| Extension | 機能 | ユースケース |
|-----------|------|-------------|
| `storage-resize-images` | Storage アップロード時に画像自動リサイズ | サムネイル生成・帯域削減 |
| `firestore-algolia-search` | Firestore → Algolia 同期 | 全文検索機能の追加 |
| `firestore-bigquery-export` | Firestore → BigQuery エクスポート | 高度な分析・BI |
| `firestore-send-email` | ドキュメント作成トリガーでメール送信 | ウェルカムメール・通知 |
| `firestore-translate-text` | Cloud Translation API でテキスト自動翻訳 | 多言語アプリ対応 |
| `auth-mailchimp-sync` | Auth ユーザーを Mailchimp に同期 | メールマーケティング |

### 2-3. カスタム Extension 作成

```
my-extension/
├── extension.yaml   # メタデータ・パラメーター定義
├── PREINSTALL.md
├── POSTINSTALL.md
└── functions/src/index.ts
```

```yaml
# extension.yaml（最小構成）
name: my-custom-extension
version: 0.1.0
specVersion: v1beta
description: Firestore ドキュメント作成時にカスタム処理を実行

params:
  - param: COLLECTION_PATH
    label: 監視対象コレクションパス
    type: string
    required: true

resources:
  - name: processDocument
    type: firebaseextensions.v1beta.function
    properties:
      eventTrigger:
        eventType: providers/cloud.firestore/eventTypes/document.create
        resource: projects/${PROJECT_ID}/databases/(default)/documents/${COLLECTION_PATH}/{docId}
```

```typescript
// functions/src/index.ts
import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
admin.initializeApp();

export const processDocument = functions.firestore
  .document(`${process.env.COLLECTION_PATH}/{docId}`)
  .onCreate(async (snap, context) => {
    const data = snap.data();
    await admin.firestore().doc(`processed/${context.params.docId}`)
      .set({ ...data, processedAt: admin.firestore.FieldValue.serverTimestamp() });
  });
```

---

## 3. プラットフォーム固有の注意点

| 項目 | Web | iOS | Android |
|------|-----|-----|---------|
| SDK 追加 | npm / CDN | CocoaPods / SPM | Gradle (Firebase BOM) |
| Auth 永続化設定 | `setPersistence()` 必須 | デフォルト有効 | デフォルト有効 |
| Firestore オフライン | `enableIndexedDbPersistence()` 必須 | デフォルト有効 | デフォルト有効 |
| FCM トークン取得 | `getToken(vapidKey)` | APNs 連携 + `apnsToken` 設定 | `getToken()` |
| App Check | reCAPTCHA v3 | AppAttest / DeviceCheck | Play Integrity |

```typescript
// Web: オフライン + FCM セットアップ
import { enableIndexedDbPersistence } from 'firebase/firestore';
import { getMessaging, getToken } from 'firebase/messaging';

await enableIndexedDbPersistence(db);  // Web のみ明示的に有効化が必要

const messaging = getMessaging(app);
const token = await getToken(messaging, { vapidKey: 'YOUR_VAPID_KEY' });
```

```swift
// iOS: APNs トークン連携（AppDelegate）
func application(_ application: UIApplication,
                 didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Messaging.messaging().apnsToken = deviceToken
}
```

---

## 4. クロスプラットフォーム開発

### 4-1. Flutter

```yaml
# pubspec.yaml
dependencies:
  firebase_core: ^2.24.0
  firebase_auth: ^4.15.0
  cloud_firestore: ^4.13.0
  firebase_messaging: ^14.7.0
```

```dart
// 初期化（flutterfire configure で firebase_options.dart を自動生成）
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

// Firestore リアルタイムリスナー
FirebaseFirestore.instance.collection('messages').snapshots().listen((snapshot) {
  for (var doc in snapshot.docs) print(doc.data());
});
```

### 4-2. React Native

```bash
npm install @react-native-firebase/app @react-native-firebase/auth
npm install @react-native-firebase/firestore @react-native-firebase/messaging
```

```typescript
import auth from '@react-native-firebase/auth';
import firestore from '@react-native-firebase/firestore';
import messaging from '@react-native-firebase/messaging';

// google-services.json (Android) / GoogleService-Info.plist (iOS) が必要
await auth().signInWithEmailAndPassword(email, password);
await firestore().collection('users').doc(userId).set({ name: 'Alice' });

await messaging().requestPermission();
const token = await messaging().getToken();
```

### 4-3. クロスプラットフォーム設計原則

| 原則 | 実践方法 |
|------|---------|
| バックエンドの共有 | Firestore・Auth・Functions は全プラットフォームで共通 |
| ネイティブ差分の抽象化 | APNs/FCM 固有コードをプラットフォーム層に閉じ込める |
| オフライン対応の差異を把握 | Web は明示的有効化、iOS/Android はデフォルト有効 |
| App Check 導入 | 不正クライアントからの API アクセスをブロック |
| Emulator でのクロス検証 | 同一 Emulator に複数クライアントを接続して動作確認 |
