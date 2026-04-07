# Firebase Analytics & Performance Monitoring

## 1. Firebase Analytics 概要

Firebase Analytics は無料のアプリ行動分析サービス。自動計測とカスタムイベントの2層構造で設計されている。

### 自動収集イベント（コード不要）

| イベント | タイミング |
|---------|-----------|
| `first_open` | 初回起動 |
| `app_update` | アプリ更新後初回起動 |
| `session_start` | セッション開始 |
| `screen_view` | 画面遷移 |
| `user_engagement` | フォアグラウンド滞在 |
| `in_app_purchase` | アプリ内購入完了 |

### セットアップ

**Web (JS/TS)**
```typescript
import { initializeApp } from 'firebase/app';
import { getAnalytics, logEvent, setUserProperties } from 'firebase/analytics';

const app = initializeApp(firebaseConfig);
export const analytics = getAnalytics(app);
```

**Android (Kotlin)**
```kotlin
// build.gradle (app)
implementation(platform("com.google.firebase:firebase-bom:32.7.0"))
implementation("com.google.firebase:firebase-analytics-ktx")

// Activity
val analytics = Firebase.analytics
```

**iOS (Swift)**
```swift
import FirebaseAnalytics
// AppDelegate で FirebaseApp.configure() 後から即利用可
```

---

## 2. カスタムイベント実装

### 命名規則・制限

| 制約 | 値 |
|------|-----|
| イベント名 | 40文字以内、英数字 + `_` のみ |
| パラメータ数 | 1イベントあたり最大25個 |
| パラメータ名 | 40文字以内 |
| パラメータ値 | 文字列100文字以内 or 数値 |

> **ベストプラクティス**: Firebase定義済みイベント（`add_to_cart`, `purchase`, `sign_up`等）を優先使用すると、コンソールの自動レポートが充実する。

### 実装例

**Web**
```typescript
import { logEvent } from 'firebase/analytics';

// 購入イベント（定義済みイベントを活用）
logEvent(analytics, 'purchase', {
  transaction_id: 'T-12345',
  value: 19.99,
  currency: 'JPY',
  items: [{ item_id: 'SKU001', item_name: 'Premium Plan' }],
});

// カスタムイベント
logEvent(analytics, 'tutorial_complete', {
  step_name: 'profile_setup',
  duration_sec: 45,
});
```

**Android (Kotlin)**
```kotlin
val bundle = Bundle().apply {
  putString(FirebaseAnalytics.Param.ITEM_ID, "SKU001")
  putString(FirebaseAnalytics.Param.ITEM_NAME, "Premium Plan")
  putDouble(FirebaseAnalytics.Param.VALUE, 19.99)
  putString(FirebaseAnalytics.Param.CURRENCY, "JPY")
}
analytics.logEvent(FirebaseAnalytics.Event.PURCHASE, bundle)

// カスタムイベント
val params = Bundle().apply {
  putString("step_name", "profile_setup")
  putLong("duration_sec", 45)
}
analytics.logEvent("tutorial_complete", params)
```

**iOS (Swift)**
```swift
// 定義済みイベント
Analytics.logEvent(AnalyticsEventPurchase, parameters: [
  AnalyticsParameterItemID: "SKU001",
  AnalyticsParameterValue: 19.99,
  AnalyticsParameterCurrency: "JPY",
])

// カスタムイベント
Analytics.logEvent("tutorial_complete", parameters: [
  "step_name": "profile_setup" as NSObject,
  "duration_sec": 45 as NSObject,
])
```

---

## 3. ユーザープロパティ

イベントが「何が起きたか」を記録するのに対し、ユーザープロパティは「どんなユーザーか」を永続的に記録する属性。オーディエンス作成やセグメント分析に活用できる。

```typescript
// Web
import { setUserProperties } from 'firebase/analytics';
setUserProperties(analytics, {
  subscription_type: 'premium',
  preferred_language: 'ja',
});
```

```kotlin
// Android
analytics.setUserProperty("subscription_type", "premium")
```

```swift
// iOS
Analytics.setUserProperty("premium", forName: "subscription_type")
```

---

## 4. デバッグ

開発中はリアルタイムで events を確認できる DebugView を活用する。

```bash
# Android: DebugView 有効化
adb shell setprop debug.firebase.analytics.app <package_name>

# iOS: Xcode スキームの引数に追加
-FIRDebugEnabled

# Web: コンソール URL に debug_mode パラメータを追加
# Firebase Console > Analytics > DebugView
```

---

## 5. BigQuery 連携

Firebase Analytics の最大の高度機能。コンソールUIでは集計済みデータしか見えないが、BigQuery Exportで生の event データに直接 SQL でアクセスできる。

### セットアップ

```
Firebase Console
└─ プロジェクト設定 > 統合タブ
   └─ BigQuery > リンク
      ├─ GCPプロジェクトを選択（BigQuery API 有効化済み）
      ├─ エクスポート対象データを選択（イベント・ユーザープロパティ）
      └─ スケジュール設定（日次 or 時間次）
```

エクスポート後、`analytics_<app_id>.events_YYYYMMDD` テーブルに生データが蓄積される。

### 代表的クエリ例

```sql
-- 日別アクティブユーザー数
SELECT
  event_date AS date,
  COUNT(DISTINCT user_pseudo_id) AS active_users
FROM `project.analytics_XXXXXXXX.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20240101' AND '20240131'
  AND event_name = 'session_start'
GROUP BY date
ORDER BY date;

-- ファネル分析（購入コンバージョン）
WITH funnel AS (
  SELECT
    user_pseudo_id,
    COUNTIF(event_name = 'view_item') AS views,
    COUNTIF(event_name = 'add_to_cart') AS carts,
    COUNTIF(event_name = 'purchase') AS purchases
  FROM `project.analytics_XXXXXXXX.events_*`
  WHERE _TABLE_SUFFIX >= '20240101'
  GROUP BY user_pseudo_id
)
SELECT
  COUNTIF(views > 0) AS step_view,
  COUNTIF(carts > 0) AS step_cart,
  COUNTIF(purchases > 0) AS step_purchase
FROM funnel;

-- カスタムイベントパラメータ取得
SELECT
  event_name,
  (SELECT value.string_value FROM UNNEST(event_params)
   WHERE key = 'step_name') AS step_name,
  COUNT(*) AS count
FROM `project.analytics_XXXXXXXX.events_*`
WHERE event_name = 'tutorial_complete'
GROUP BY 1, 2;
```

### BigQuery 連携の主なメリット

| メリット | 説明 |
|---------|------|
| 生データアクセス | 集計前の全イベントに SQL でアクセス |
| 長期保存 | コンソール表示の 14 ヶ月制限を超えた分析 |
| 外部BI連携 | Looker Studio / Tableau / Redash 等に接続 |
| 結合分析 | サーバーサイドDBや他データソースと JOIN |

---

## 6. Performance Monitoring

アプリの実行時パフォーマンスを自動・手動で計測するサービス。Analytics が「ユーザー行動」を扱うのに対し、Performance Monitoring は「実行時間・応答速度」を扱う。

### 自動計測される指標

| 指標 | 説明 |
|------|------|
| App Start Time | コールドスタート～UI描画完了までの時間 |
| Screen Rendering | 各画面のフレームレート・描画時間 |
| Network Requests | HTTP/HTTPS リクエストの応答時間・サイズ |

### セットアップ

```kotlin
// Android: build.gradle
implementation("com.google.firebase:firebase-perf-ktx")
```

```swift
// iOS: Podfile
pod 'Firebase/Performance'
// AppDelegate で FirebaseApp.configure() のみで自動計測開始
```

```typescript
// Web
import { getPerformance } from 'firebase/performance';
const perf = getPerformance(app);
// 初期化だけで自動ネットワーク計測が開始
```

### カスタムトレース

特定のコードブロックの実行時間を計測する場合に使用。DB クエリ、画像処理、重い計算処理等の特定セクションに仕込む。

**Web**
```typescript
import { trace } from 'firebase/performance';

const t = trace(perf, 'load_user_profile');
t.start();
try {
  await fetchUserProfile(userId); // 計測したい処理
  t.putAttribute('result', 'success');
} finally {
  t.stop();
}
```

**Android (Kotlin)**
```kotlin
val myTrace = Firebase.performance.newTrace("load_user_profile")
myTrace.start()
try {
  loadUserProfile(userId) // 計測したい処理
  myTrace.putAttribute("result", "success")
} finally {
  myTrace.stop()
}

// カスタムメトリクス（数値カウンター）
myTrace.incrementMetric("cache_hit", 1)
```

**iOS (Swift)**
```swift
let trace = Performance.startTrace(name: "load_user_profile")
defer { trace?.stop() }
// 計測したい処理...
trace?.setValue("success", forAttribute: "result")
```

### ネットワーク監視

Firebase Performance は `URLSession`（iOS）や `XMLHttpRequest` / `fetch`（Web）を自動インターセプトしてネットワークリクエストを計測する。

監視される指標:
- 応答時間（ms）
- ペイロードサイズ（request / response）
- 成功率 / エラーレート

特定のドメインを除外したい場合:

```kotlin
// Android: 手動で HTTP メトリクスを記録（自動計測は有効のまま）
val metric = Firebase.performance.newHttpMetric(
  "https://api.example.com/users", FirebasePerformance.HttpMethod.GET
)
metric.start()
// HTTP リクエスト実行
metric.setHttpResponseCode(200)
metric.stop()
```

### パフォーマンスアラート

```
Firebase Console > Performance > Alerts
└─ New Alert
   ├─ メトリクス選択（App Start Time, Network Request等）
   ├─ 閾値設定（例: App Start > 3000ms）
   └─ 通知先設定（メール）
```

---

## 7. AnalyticsとPerformance Monitoringの使い分け

| 目的 | 使うべきツール |
|------|--------------|
| ユーザーが何をしているか | Firebase Analytics（カスタムイベント） |
| ユーザーがどんな属性を持つか | Firebase Analytics（ユーザープロパティ） |
| 機能の実行にどれくらい時間がかかるか | Performance Monitoring（カスタムトレース） |
| APIが遅くなっていないか | Performance Monitoring（ネットワーク監視） |
| コンバージョンファネルを深く分析 | Analytics + BigQuery |
| 特定バージョンで性能劣化した | Performance Monitoring（バージョン比較） |

---

## 関連リファレンス

- [`references/MESSAGING.md`](MESSAGING.md) — FCM + Remote Config（Analytics オーディエンス連携）
- [`../SKILL.md`](../SKILL.md) — Firebase全体のエコシステム概要
