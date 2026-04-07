# Cloud Functions リファレンス

Cloud Functions for Firebase は Firebase エコシステムのイベントに反応するサーバーレス実行環境。
インフラ管理不要でバックエンドロジックを実装できる。

---

## 1. プロジェクト初期化・デプロイ

```bash
# 初期化（TypeScript 推奨）
firebase init functions
# → functions/ ディレクトリ + tsconfig.json が生成される

# デプロイ
firebase deploy --only functions
firebase deploy --only functions:myFunction  # 特定関数のみ

# ログ確認
firebase functions:log
firebase functions:log --only myFunction
```

**ディレクトリ構成**
```
functions/
├── src/
│   └── index.ts      # 関数エントリポイント
├── package.json
└── tsconfig.json
```

---

## 2. トリガー種別

### 2-1. HTTP トリガー

REST API・Webhook の受け口。認証不要でパブリックアクセス可能（IAM で制御）。

```typescript
import { onRequest, onCall, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';

admin.initializeApp();

// REST API エンドポイント
export const api = onRequest(
  { region: 'asia-northeast1', cors: true },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Method Not Allowed' });
      return;
    }
    const { name } = req.body;
    res.json({ message: `Hello, ${name}!` });
  }
);

// Callable Function（クライアント SDK から呼び出す）
export const greet = onCall({ region: 'asia-northeast1' }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication required');
  }
  const { name } = request.data;
  return { message: `Hello, ${name}!` };
});
```

**クライアント（Web）から Callable を呼び出す**
```typescript
import { getFunctions, httpsCallable } from 'firebase/functions';
const functions = getFunctions(app, 'asia-northeast1');
const greet = httpsCallable(functions, 'greet');
const result = await greet({ name: 'Alice' });
// Android: Firebase.functions("asia-northeast1").getHttpsCallable("greet").call(...)
// iOS: Functions.functions(region:).httpsCallable("greet").call(...)
```

---

### 2-2. Firestore トリガー

ドキュメントの作成・更新・削除・書き込みをフック。データ変換・通知送信などに使用。

```typescript
import {
  onDocumentCreated,
  onDocumentUpdated,
  onDocumentDeleted,
  onDocumentWritten,
} from 'firebase-functions/v2/firestore';

// 新規作成時（ウェルカムメール送信など）
export const onUserCreated = onDocumentCreated('users/{userId}', async (event) => {
  const userId = event.params.userId;
  const data = event.data?.data();
  if (!data) return;
  console.log(`New user: ${userId}`, data);
  // FCM 通知・メール送信などの処理
});

// 更新時（before/after を比較）
export const onOrderUpdated = onDocumentUpdated('orders/{orderId}', async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (before?.status !== after?.status) {
    console.log(`Order ${event.params.orderId} status changed: ${before?.status} → ${after?.status}`);
  }
});

// 削除時（関連データクリーンアップ）
export const onUserDeleted = onDocumentDeleted('users/{userId}', async (event) => {
  const userId = event.params.userId;
  // Storage ファイル削除、サブコレクション削除など
  await admin.storage().bucket().deleteFiles({ prefix: `users/${userId}/` });
});
```

---

### 2-3. Auth トリガー

ユーザー作成・削除に連動。プロファイル初期化やデータクリーンアップに使用。

```typescript
import { beforeUserCreated, onUserDeleted } from 'firebase-functions/v2/identity';

// 作成前フック（バリデーション・カスタムクレーム付与）
export const beforeSignUp = beforeUserCreated(async (event) => {
  if (!event.data?.email?.endsWith('@example.com')) {
    throw new HttpsError('permission-denied', 'Invalid email domain');
  }
  return { customClaims: { role: 'user' } };
});

// 削除時クリーンアップ
export const cleanupOnDelete = onUserDeleted(async (event) => {
  await admin.firestore().collection('users').doc(event.data.uid).delete();
});
```

---

### 2-4. Cloud Storage トリガー

ファイルアップロード・削除をフック。画像リサイズ・ウイルススキャンなどに使用。

```typescript
import { onObjectFinalized } from 'firebase-functions/v2/storage';

export const onImageUploaded = onObjectFinalized(
  { bucket: 'my-project.appspot.com' },
  async (event) => {
    if (!event.data.contentType?.startsWith('image/')) return;
    // sharp 等でサムネイル生成
    console.log(`Image uploaded: ${event.data.name}`);
  }
);
```

---

### 2-5. Pub/Sub トリガー

非同期メッセージング。重い処理をバックグラウンドに委譲するパイプライン構築に適する。

```typescript
import { onMessagePublished } from 'firebase-functions/v2/pubsub';

export const processMessage = onMessagePublished('my-topic', async (event) => {
  const message = event.data.message;
  const data = message.json as { userId: string; action: string };
  console.log(`Processing: userId=${data.userId}, action=${data.action}`);
  // 重い処理（メール一括送信・データ集計など）
});
```

---

### 2-6. スケジュールトリガー

Cron 式または App Engine cron 形式で定期実行。データクリーンアップ・定期レポートに使用。

```typescript
import { onSchedule } from 'firebase-functions/v2/scheduler';

// 毎日午前2時に実行（JST: 'Asia/Tokyo' タイムゾーン）
export const dailyCleanup = onSchedule(
  { schedule: '0 2 * * *', timeZone: 'Asia/Tokyo', region: 'asia-northeast1' },
  async () => {
    const cutoff = new Date();
    cutoff.setDate(cutoff.getDate() - 30);
    const db = admin.firestore();
    const old = await db.collection('logs')
      .where('createdAt', '<', cutoff)
      .limit(500)
      .get();
    const batch = db.batch();
    old.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
    console.log(`Deleted ${old.size} old logs`);
  }
);
```

---

## 3. 環境変数・シークレット管理

Gen2 では `defineString` / `defineSecret` を使用。コード内にシークレットをハードコードしない。

```typescript
import { defineString, defineSecret } from 'firebase-functions/params';
import { onRequest } from 'firebase-functions/v2/https';

// 環境変数（非機密情報）
const REGION = defineString('REGION', { default: 'asia-northeast1' });

// シークレット（Google Secret Manager に保存）
const STRIPE_KEY = defineSecret('STRIPE_SECRET_KEY');
const SENDGRID_KEY = defineSecret('SENDGRID_API_KEY');

// シークレットを使う関数に runWith で宣言
export const processPayment = onRequest(
  { secrets: [STRIPE_KEY], region: REGION.value() },
  async (req, res) => {
    const stripeKey = STRIPE_KEY.value();  // ランタイムで取得
    // Stripe API 呼び出し
    res.json({ success: true });
  }
);
```

```bash
# シークレット設定（初回）
firebase functions:secrets:set STRIPE_SECRET_KEY
# → プロンプトで値を入力

# 確認
firebase functions:secrets:access STRIPE_SECRET_KEY
```

---

## 4. エラーハンドリング

### HTTP / Callable のエラー処理

```typescript
import { onCall, HttpsError } from 'firebase-functions/v2/https';

export const riskyOperation = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Login required');
  }

  try {
    const result = await performOperation(request.data);
    return { success: true, result };
  } catch (error) {
    console.error('Operation failed:', error);
    // クライアントに返すエラーは HttpsError に変換
    throw new HttpsError('internal', 'Operation failed. Please retry.');
  }
});
```

**HttpsError のエラーコード**

| コード | 用途 |
|--------|------|
| `unauthenticated` | 未認証 |
| `permission-denied` | 権限不足 |
| `not-found` | リソースが存在しない |
| `invalid-argument` | 不正なリクエスト |
| `already-exists` | 重複エラー |
| `internal` | サーバー内部エラー |

### バックグラウンド関数のエラー処理

```typescript
export const onUserCreated = onDocumentCreated('users/{userId}', async (event) => {
  try {
    await sendWelcomeEmail(event.data?.data()?.email);
  } catch (error) {
    // エラーをログに記録して処理終了（リトライは避ける）
    console.error('Failed to send welcome email:', error);
    // throw するとリトライキューに入る（べき等性が確保されている場合のみ）
  }
});
```

---

## 5. べき等性（Idempotency）

Firestore・Pub/Sub トリガーは **At-least-once** 実行（重複呼び出しあり）。
`event.id` を使って重複処理を防ぐトランザクションパターンが有効。

```typescript
export const processOrder = onDocumentCreated('orders/{orderId}', async (event) => {
  const db = admin.firestore();
  await db.runTransaction(async (tx) => {
    const processedRef = db.collection('processedEvents').doc(event.id);
    if ((await tx.get(processedRef)).exists) return;  // 重複スキップ

    tx.update(db.collection('orders').doc(event.params.orderId), { status: 'processing' });
    tx.set(processedRef, { processedAt: admin.firestore.FieldValue.serverTimestamp() });
  });
});
```

---

## 6. テスト戦略

### Emulator を使ったローカルテスト

```bash
# Emulator 起動
firebase emulators:start --only functions,firestore,auth

# Functions Emulator のみ
firebase emulators:start --only functions
```

```typescript
// Jest + firebase-functions-test
import * as functionsTest from 'firebase-functions-test';
const test = functionsTest({ projectId: 'demo-test' });

it('onUserCreated sends welcome email', async () => {
  const wrapped = test.wrap(onUserCreated);
  const snap = test.firestore.makeDocumentSnapshot(
    { name: 'Alice', email: 'alice@example.com' },
    'users/alice123'
  );
  await wrapped({ data: snap, params: { userId: 'alice123' } });
});
```

| 観点 | 方針 |
|------|------|
| 単体テスト | ロジック関数を `index.ts` から分離してテスト |
| 統合テスト | Emulator Suite で実際のトリガーを発火させる |
| シークレット | `.env.local` でテスト用環境変数を管理 |
| CI/CD | `firebase emulators:exec` でテスト自動化 |

---

## 7. パフォーマンス最適化

| 課題 | 対策 |
|------|------|
| Cold Start | グローバルスコープで初期化コードを実行（関数外で `admin.initializeApp()`） |
| Cold Start | `minInstances` 設定でウォームインスタンスを維持 |
| メモリ不足 | `memory: '1GiB'` などで割り当て量を調整 |
| タイムアウト | デフォルト60秒。重い処理は `timeoutSeconds: 540`（最大9分） |
| 無限ループ | Firestore トリガー内でトリガー対象ドキュメントを更新しない |
| コスト | 不要なリトライを抑制：エラーをキャッチして `throw` しない |

```typescript
// グローバルスコープで初期化（Cold Start 対策）
admin.initializeApp();

export const heavyTask = onRequest(
  { region: 'asia-northeast1', memory: '2GiB', timeoutSeconds: 300, minInstances: 1 },
  async (req, res) => { /* 重い処理 */ }
);
```

---

## 関連リファレンス

- [`SKILL.md`](../SKILL.md) — Functions トリガー種別早見表
- [`DATABASE.md`](DATABASE.md) — Firestore トランザクション・バッチ
- [`AUTHENTICATION.md`](AUTHENTICATION.md) — Auth トリガーのカスタムクレーム
- [`TESTING-AND-DISTRIBUTION.md`](TESTING-AND-DISTRIBUTION.md) — Emulator Suite 詳細設定
