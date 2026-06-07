# Firebase Messaging リファレンス

FCM (Firebase Cloud Messaging) / Remote Config / Dynamic Links の実装ガイド。

---

## 1. Firebase Cloud Messaging (FCM)

FCM はクロスプラットフォーム（Android / iOS / Web）のプッシュ通知配信サービス。無料で大規模配信が可能。

### 1-1. メッセージタイプ

| タイプ | 特徴 | 主なユースケース |
|--------|------|----------------|
| **notification** | OSが自動表示。アプリがバックグラウンドでも表示される | お知らせ・アラート |
| **data** | アプリが受信して処理。バックグラウンド時はOSで表示されない | サイレント更新・カスタムロジック |
| **両方** | フォアグラウンドではdataを処理、バックグラウンドではnotificationを表示 | 汎用（推奨） |

```typescript
// Admin SDK (Node.js/TypeScript) — 3タイプの例
import * as admin from 'firebase-admin';

// 1. 通知メッセージのみ
const notificationMsg = {
  notification: { title: '新着メッセージ', body: '1件の未読があります' },
  token: deviceToken,
};

// 2. データメッセージのみ（サイレント）
const dataMsg = {
  data: { action: 'refresh', targetId: '123' },
  token: deviceToken,
};

// 3. 両方（推奨: フォア/バックグラウンド両対応）
const combinedMsg = {
  notification: { title: '注文が完了しました' },
  data: { orderId: 'ORD-456', screen: 'order-detail' },
  token: deviceToken,
};

await admin.messaging().send(combinedMsg);
```

```kotlin
// Android (Kotlin) — フォアグラウンド受信処理
class MyFirebaseService : FirebaseMessagingService() {
    override fun onMessageReceived(message: RemoteMessage) {
        val title = message.notification?.title ?: message.data["title"]
        val body = message.notification?.body ?: message.data["body"]
        showNotification(title, body)
    }
    override fun onNewToken(token: String) {
        // トークン更新時: Firestoreに保存してサーバーと同期
        saveTokenToFirestore(token)
    }
}
```

```swift
// iOS (Swift) — フォアグラウンド受信
extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        // dataペイロードを取得して処理
        completionHandler([.banner, .sound])
    }
}
```

### 1-2. デバイストークン管理

```typescript
// Web (JS/TS) — サービスワーカー登録 + トークン取得
import { getMessaging, getToken, onMessage } from 'firebase/messaging';

const messaging = getMessaging(app);

const token = await getToken(messaging, {
  vapidKey: process.env.NEXT_PUBLIC_FIREBASE_VAPID_KEY,
});
// Firestoreのusers/{uid}/tokens/{token}に保存する

// フォアグラウンド受信
onMessage(messaging, (payload) => {
  console.log('Received message:', payload);
  // カスタム通知UIを表示
});
```

### 1-3. トピック購読と条件付き送信

トピックは「1対多配信」を実現する。特定グループへの一斉通知に適している。

```kotlin
// Android — トピック購読
FirebaseMessaging.getInstance().subscribeToTopic("news")
    .addOnCompleteListener { task ->
        if (task.isSuccessful) Log.d("FCM", "Subscribed to news")
    }
FirebaseMessaging.getInstance().unsubscribeFromTopic("news")
```

```swift
// iOS — トピック購読
Messaging.messaging().subscribe(toTopic: "news") { error in
    print("Subscribed to news topic")
}
```

```typescript
// Admin SDK — トピック送信 / 条件付き送信
// トピック全員へ
await admin.messaging().send({
  notification: { title: 'お知らせ', body: '新機能が追加されました' },
  topic: 'news',
});

// 条件付き送信 (最大5トピック、&&/||/()使用可)
await admin.messaging().send({
  notification: { title: 'キャンペーン', body: '本日限定オファー！' },
  condition: "'premium' in topics || 'trial' in topics",
});

// マルチキャスト (最大500トークン)
await admin.messaging().sendEachForMulticast({
  tokens: [token1, token2, token3],
  notification: { title: '複数端末へ送信' },
});
```

### 1-4. 通知のベストプラクティス

| 原則 | 内容 |
|------|------|
| 許可取得 | 明示的に許可を求める（iOS必須・Android 13以上必須） |
| 関連性 | 不要な通知は解除率を高める — セグメント配信を活用 |
| ディープリンク | `data.screen` でアプリ内の特定画面を指定 |
| 分析 | FCM + Analytics連携でCTRを計測し改善 |

---

## 2. Remote Config

アプリを更新せずにパラメータを変更できるサーバーサイド設定。A/Bテスト・段階的ロールアウト・パーソナライゼーションに活用する。

### 2-1. セットアップ (Web)

```typescript
import { getRemoteConfig, fetchAndActivate, getValue } from 'firebase/remote-config';

const remoteConfig = getRemoteConfig(app);
remoteConfig.settings.minimumFetchIntervalMillis = 3600000; // 1時間キャッシュ（本番）

// デフォルト値設定（オフライン時のフォールバック）
remoteConfig.defaultConfig = {
  welcome_message: 'こんにちは！',
  new_feature_enabled: false,
  max_items_per_page: 20,
};

// 起動時にフェッチして適用
await fetchAndActivate(remoteConfig);

const welcomeMsg = getValue(remoteConfig, 'welcome_message').asString();
const isEnabled = getValue(remoteConfig, 'new_feature_enabled').asBoolean();
const maxItems = getValue(remoteConfig, 'max_items_per_page').asNumber();
```

```kotlin
// Android (Kotlin) — フェッチと適用
val remoteConfig = Firebase.remoteConfig
remoteConfig.setConfigSettingsAsync(
    remoteConfigSettings { minimumFetchIntervalInSeconds = 3600 }
)
remoteConfig.setDefaultsAsync(R.xml.remote_config_defaults)
remoteConfig.fetchAndActivate().addOnCompleteListener { task ->
    if (task.isSuccessful) {
        val isEnabled = remoteConfig.getBoolean("new_feature_enabled")
        updateUI(isEnabled)
    }
}
```

### 2-2. フィーチャーフラグ（段階的ロールアウト）

Firebase Console → Remote Config → 条件を使ってユーザー割合を指定。

```
パラメータ: new_checkout_flow
デフォルト値: false
条件（10%ロールアウト）: ランダム %ile < 10 → true
```

```typescript
// アプリ側でフラグを読んで分岐
const newCheckoutEnabled = getValue(remoteConfig, 'new_checkout_flow').asBoolean();

if (newCheckoutEnabled) {
  router.push('/checkout/v2');
} else {
  router.push('/checkout');
}
```

### 2-3. A/Bテスト設計

```
Firebase Console → A/B Testing → 新しいテスト作成
  対象: Remote Config
  パラメータ: button_color
  コントロール: "blue"
  バリアント A: "green"
  目標指標: purchase イベント
  対象ユーザー割合: 50% / 50%
```

```typescript
// A/Bテスト中のバリアント取得
const buttonColor = getValue(remoteConfig, 'button_color').asString();
// → "blue" または "green" が自動的に割り当てられる
document.getElementById('cta-button')!.style.backgroundColor = buttonColor;
```

| Remote Config 制限 | 値 |
|-------------------|-----|
| パラメータ数 | 最大2,000 |
| パラメータキー長 | 256文字 |
| 値のサイズ | 最大1MB |
| フェッチ上限（開発） | 1分あたり5回 |

---

## 3. Dynamic Links（ディープリンク）

⚠️ **注意**: Firebase Dynamic Links は 2025年8月25日に廃止済み。新規実装には[App Links](https://developer.android.com/training/app-links) (Android) / [Universal Links](https://developer.apple.com/documentation/xcode/supporting-universal-links-in-your-app) (iOS) の直接実装を推奨。

### 3-1. Dynamic Links の仕組み（廃止前の参考知識）

```
Dynamic Linkの動作フロー:
  ユーザーがリンクをクリック
  ├─ アプリがインストール済み  → アプリ内の対象コンテンツを直接開く
  └─ アプリが未インストール   → App Store / Play Storeへ遷移
                               インストール後、対象コンテンツを開く（Deferred Deep Link）
```

### 3-2. ネイティブディープリンク実装（推奨）

App Links / Universal Links による直接実装:

```kotlin
// Android — App Links処理
// AndroidManifest.xml
// <intent-filter android:autoVerify="true">
//   <action android:name="android.intent.action.VIEW"/>
//   <data android:scheme="https" android:host="example.com"/>
// </intent-filter>

class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // ディープリンクのパスを取得
        val deepLinkPath = intent?.data?.path
        if (deepLinkPath?.startsWith("/product/") == true) {
            val productId = deepLinkPath.removePrefix("/product/")
            navigateToProduct(productId)
        }
    }
}
```

```swift
// iOS — Universal Links処理
// Info.plist に Associated Domains を設定:
// applinks:example.com

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else { return }
        // パスからコンテンツを特定してナビゲーション
        handleDeepLink(url: url)
    }
}
```

```typescript
// Web — ブランチやonelinksなどのサードパーティツール使用、
// または Next.js の動的ルーティングで /product/[id] を直接活用
// app/product/[id]/page.tsx でサーバーサイドレンダリング
```

### 3-3. ディープリンクのユースケース

| ユースケース | URL例 | 遷移先 |
|------------|-------|--------|
| 商品ページ | `example.com/product/123` | 商品詳細画面 |
| メール認証後 | `example.com/verify?oobCode=xxx` | 認証完了画面 |
| 招待リンク | `example.com/invite?ref=user123` | 招待受諾画面 |
| プロモ | `example.com/promo/summer2025` | キャンペーン画面 |

---

## 4. 統合パターン

### FCM + Firestore + Cloud Functions の連携

```typescript
// Cloud Functions — Firestoreのドキュメント作成時に通知送信
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import * as admin from 'firebase-admin';

export const notifyOnNewOrder = onDocumentCreated('orders/{orderId}', async (event) => {
  const order = event.data?.data();
  if (!order) return;

  // ユーザーのFCMトークンをFirestoreから取得
  const userDoc = await admin.firestore().doc(`users/${order.userId}`).get();
  const fcmToken = userDoc.data()?.fcmToken;
  if (!fcmToken) return;

  await admin.messaging().send({
    notification: {
      title: '注文を受け付けました',
      body: `注文ID: ${event.params.orderId}`,
    },
    data: {
      screen: 'order-detail',
      orderId: event.params.orderId,
    },
    token: fcmToken,
  });
});
```

### Remote Config + Analytics の連携

```typescript
// A/Bテストのバリアントをカスタムイベントとして記録
import { logEvent, getAnalytics } from 'firebase/analytics';

const analytics = getAnalytics(app);
const variant = getValue(remoteConfig, 'button_color').asString();

// バリアント割り当てを記録
logEvent(analytics, 'ab_test_exposure', {
  experiment_name: 'button_color_test',
  variant_name: variant,
});

// コンバージョンイベント
logEvent(analytics, 'purchase', { value: 2000, currency: 'JPY' });
```
