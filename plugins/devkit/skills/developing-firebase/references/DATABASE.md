# Firebase Database リファレンス

Firestore と Realtime Database（RTDB）の選択基準から実装パターンまでのリファレンス。

---

## 1. DB選択判断基準

### RTDB vs Firestore 比較テーブル

| 比較軸 | Cloud Firestore | Realtime Database |
|--------|----------------|-------------------|
| データ構造 | コレクション / ドキュメント（階層型） | JSONツリー（フラット推奨） |
| クエリ能力 | 複合クエリ・範囲・ソート・インデックス | 単一フィールド絞り込みのみ |
| スケーラビリティ | 自動スケーリング、マルチリージョン対応 | シングルリージョン・上限あり |
| オフライン | Web / iOS / Android すべて対応 | iOS / Android のみ（Web非対応） |
| リアルタイム同期 | ✅（onSnapshot） | ✅（WebSocket常時接続・超低遅延） |
| トランザクション | ✅ アトミック操作 | ✅（ただし複雑なケースは制限あり） |
| コスト | 読み書き回数課金（高頻度は注意） | 帯域幅 / ストレージ課金 |
| 推奨用途 | **新規アプリの第一選択** | リアルタイムチャット・IoT・単純同期 |

### ユースケース別選択フロー

```
アプリの要件は？
├─ 複雑なクエリが必要（複合条件・ソート・ページネーション）
│   └─ → Cloud Firestore 確定
├─ 超低レイテンシのリアルタイム同期が最優先（チャット・ゲーム・IoT）
│   └─ → Realtime Database が適している
├─ モバイル + Web 両方でオフライン対応が必要
│   └─ → Cloud Firestore（RTDBはWebオフライン非対応）
├─ データ構造が単純なJSONで十分
│   ├─ スケールしない可能性あり → Realtime Database
│   └─ スケール必要 → Cloud Firestore
└─ 迷ったら → Cloud Firestore（現在の推奨）
```

---

## 2. Cloud Firestore

### 2-1. データ構造とモデリング

Firestoreのデータモデルは**コレクション → ドキュメント → サブコレクション**の階層で構成される。

```
users/                       ← コレクション
  alice123/                  ← ドキュメント（ID: alice123）
    name: "Alice"
    age: 30
    posts/                   ← サブコレクション
      post001/               ← ドキュメント
        title: "Hello"
        createdAt: Timestamp
```

#### モデリングパターン

| パターン | 適用場面 | 注意 |
|---------|---------|------|
| フラット（独立コレクション） | エンティティが独立して成長する場合 | 結合はクライアント側で実施 |
| サブコレクション | 親子関係が明確で独立ドキュメント取得が必要 | ルートクエリでは子を取得できない |
| 非正規化（データ複製） | 読み取り頻度が高いフィールドの高速取得 | 書き込み時に複数箇所を更新 |
| 参照（DocumentReference型） | 関連ドキュメントへのポインタを保存 | 取得には別途getが必要 |

```typescript
// ❌ 深いネストは避ける（RTDBの罠と同じ）
users/{id}/posts/{id}/comments/{id}/likes/{id}  // 4階層以上は管理困難

// ✅ フラットなコレクション + 参照
// users/{userId}, posts/{postId}, comments/{commentId}
// posts/{postId}.authorRef = doc(db, 'users', userId)
```

### 2-2. CRUD操作（Firestore）

**Web (TypeScript)**

```typescript
import {
  collection, doc, addDoc, setDoc, getDoc, getDocs,
  updateDoc, deleteDoc, serverTimestamp, Timestamp
} from 'firebase/firestore';

// ── Create ──────────────────────────────────────────
// 自動ID生成
const newRef = await addDoc(collection(db, 'posts'), {
  title: 'Hello Firebase',
  authorId: user.uid,
  createdAt: serverTimestamp(),  // サーバー側タイムスタンプ推奨
});

// カスタムIDを指定（ユーザーIDなど）
await setDoc(doc(db, 'users', user.uid), {
  name: 'Alice',
  email: user.email,
  createdAt: serverTimestamp(),
});

// ── Read ────────────────────────────────────────────
// 単一ドキュメント取得
const snap = await getDoc(doc(db, 'users', userId));
if (snap.exists()) {
  const data = snap.data();  // { name, email, createdAt }
  console.log(snap.id, data);
}

// ── Update ──────────────────────────────────────────
// 部分更新（指定フィールドのみ更新）
await updateDoc(doc(db, 'users', userId), {
  age: 31,
  'profile.bio': 'Firebase enthusiast',  // ネストフィールドはドット記法
});

// setDoc with merge（存在しない場合は作成、ある場合はマージ）
await setDoc(doc(db, 'users', userId), { age: 31 }, { merge: true });

// ── Delete ──────────────────────────────────────────
await deleteDoc(doc(db, 'users', userId));
```

**Android (Kotlin)**

```kotlin
val db = Firebase.firestore

// Create
db.collection("users").document(user.uid)
  .set(hashMapOf("name" to "Alice", "email" to user.email))
  .addOnSuccessListener { Log.d(TAG, "Written") }
  .addOnFailureListener { e -> Log.e(TAG, "Error", e) }

// Read
db.collection("users").document(userId).get()
  .addOnSuccessListener { doc ->
    if (doc.exists()) Log.d(TAG, "${doc.data}")
  }

// Update
db.collection("users").document(userId)
  .update("age", 31)
```

**iOS (Swift)**

```swift
let db = Firestore.firestore()

// Create
db.collection("users").document(user.uid).setData([
  "name": "Alice",
  "email": user.email ?? ""
]) { error in
  if let error { print("Error: \(error)") }
}

// Read
db.collection("users").document(userId).getDocument { snap, _ in
  if let data = snap?.data() { print(data) }
}

// Update
db.collection("users").document(userId).updateData(["age": 31])
```

### 2-3. 複合クエリ

Firestoreは複数条件の組み合わせに対応するが、**複合クエリはインデックスが必要**になる場合がある。

```typescript
import { query, collection, where, orderBy, limit, startAfter, getDocs } from 'firebase/firestore';

// 複合クエリ（where + orderBy + limit）
const q = query(
  collection(db, 'posts'),
  where('status', '==', 'published'),
  where('authorId', '==', userId),  // 異なるフィールドの複合条件はインデックス必須
  orderBy('createdAt', 'desc'),
  limit(20)
);
const snapshot = await getDocs(q);
const posts = snapshot.docs.map(d => ({ id: d.id, ...d.data() }));

// ページネーション（カーソルベース）
const lastDoc = snapshot.docs[snapshot.docs.length - 1];
const nextQ = query(
  collection(db, 'posts'),
  where('status', '==', 'published'),
  orderBy('createdAt', 'desc'),
  startAfter(lastDoc),  // 前ページの最後ドキュメント
  limit(20)
);

// 配列フィールドのクエリ
const tagQ = query(
  collection(db, 'posts'),
  where('tags', 'array-contains', 'firebase')
);

// 複数値マッチ（OR的な検索、最大30要素）
const multiQ = query(
  collection(db, 'users'),
  where('role', 'in', ['admin', 'editor'])
);
```

### 2-4. リアルタイムリスナー（Firestore）

```typescript
import { onSnapshot, doc, collection, query, where } from 'firebase/firestore';

// 単一ドキュメント監視
const unsubDoc = onSnapshot(doc(db, 'users', userId), (snap) => {
  if (snap.exists()) {
    console.log('User updated:', snap.data());
  }
}, (error) => {
  console.error('Listen error:', error);
});

// コレクション監視（差分検知）
const unsubCol = onSnapshot(
  query(collection(db, 'messages'), orderBy('createdAt', 'desc'), limit(50)),
  (snapshot) => {
    snapshot.docChanges().forEach((change) => {
      if (change.type === 'added')    handleAdd(change.doc);
      if (change.type === 'modified') handleUpdate(change.doc);
      if (change.type === 'removed')  handleDelete(change.doc);
    });
  }
);

// React useEffect での解除パターン
useEffect(() => {
  const unsubscribe = onSnapshot(doc(db, 'users', userId), callback);
  return () => unsubscribe();  // アンマウント時に必ず解除（コスト節約）
}, [userId]);
```

### 2-5. トランザクション & バッチ書き込み

```typescript
import { runTransaction, writeBatch, increment, doc } from 'firebase/firestore';

// ── Transaction（読み取り → 書き込みが原子的に必要な場合）──
// 例: 在庫減算（複数クライアントの競合を防ぐ）
await runTransaction(db, async (transaction) => {
  const productRef = doc(db, 'products', productId);
  const productSnap = await transaction.get(productRef);

  if (!productSnap.exists()) throw new Error('Product not found');

  const stock = productSnap.data().stock;
  if (stock <= 0) throw new Error('Out of stock');

  transaction.update(productRef, { stock: stock - 1 });
  transaction.set(doc(db, 'orders', orderId), {
    productId,
    userId: user.uid,
    createdAt: serverTimestamp(),
  });
});

// ── Batch Write（最大500操作、読み取り不要なまとめ書き込み）──
const batch = writeBatch(db);
userIds.forEach((id) => {
  batch.update(doc(db, 'users', id), { notified: true });
});
await batch.commit();

// ── increment（カウンターの原子的加算）──
await updateDoc(doc(db, 'posts', postId), {
  likeCount: increment(1),   // 同時更新でも正確にカウント
});
```

### 2-6. インデックス設計

```json
// firestore.indexes.json
{
  "indexes": [
    {
      "collectionGroup": "posts",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "authorId", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "posts",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    }
  ]
}
```

| インデックスのルール | 内容 |
|---------------------|------|
| 単一フィールド | 自動で作成（設定不要） |
| 複合インデックス | 異なるフィールドへのwhere + orderBy で必要 |
| 不等式 (`!=`, `<`, `>`) | 使用するフィールドで自動 or 複合インデックス要 |
| エラーからリンク | クエリエラーにインデックス作成リンクが含まれる |

**インデックス最適化の原則**

```
読み取りパターンを先に設計 → データモデルを決める → インデックスを定義
（RDBの正規化とは逆。クエリ駆動設計が Firestore のベストプラクティス）
```

### 2-7. Firestore Security Rules

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ヘルパー関数
    function isAuthenticated() {
      return request.auth != null;
    }
    function isOwner(userId) {
      return request.auth.uid == userId;
    }
    function isAdmin() {
      return request.auth.token.admin == true;
    }
    function isValidPost() {
      let data = request.resource.data;
      return data.title is string
          && data.title.size() > 0
          && data.title.size() <= 200
          && data.authorId == request.auth.uid;
    }

    // ユーザープロフィール
    match /users/{userId} {
      allow read: if isAuthenticated();
      allow write: if isOwner(userId);
    }

    // 投稿
    match /posts/{postId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated() && isValidPost();
      allow update: if resource.data.authorId == request.auth.uid;
      allow delete: if resource.data.authorId == request.auth.uid || isAdmin();
    }

    // 管理者専用コレクション
    match /admin/{doc=**} {
      allow read, write: if isAdmin();
    }
  }
}
```

---

## 3. Realtime Database

### 3-1. データ構造設計

RTDBのデータは**JSONツリー**として格納される。Firestoreと異なりフラットな設計が推奨される。

```json
// ✅ 推奨: フラット構造（深いネストを避ける）
{
  "users": {
    "alice123": { "name": "Alice", "email": "alice@example.com" }
  },
  "posts": {
    "post001": { "title": "Hello", "authorId": "alice123" }
  },
  "user-posts": {
    "alice123": { "post001": true }  // インデックス（多対多の関係）
  }
}

// ❌ アンチパターン: 深いネスト（取得時に不要なデータも全取得）
{
  "users": {
    "alice123": {
      "posts": { "post001": { "comments": { ... } } }
    }
  }
}
```

### 3-2. CRUD操作（RTDB）

**Web (TypeScript)**

```typescript
import { getDatabase, ref, set, update, get, push, remove, onValue, off } from 'firebase/database';

const db = getDatabase();

// Create（set: 上書き / push: 自動ID）
await set(ref(db, `users/${userId}`), { name: 'Alice', age: 30 });
const newPostRef = push(ref(db, 'posts'));  // 自動ID生成
await set(newPostRef, { title: 'Hello', authorId: userId });

// Read（一度だけ）
const snap = await get(ref(db, `users/${userId}`));
if (snap.exists()) console.log(snap.val());

// Update（部分更新）
await update(ref(db, `users/${userId}`), { age: 31 });

// Multi-location Update（複数パスを原子的に更新）
await update(ref(db), {
  [`users/${userId}/postCount`]: 1,
  [`user-posts/${userId}/${newPostRef.key}`]: true,
});

// Delete
await remove(ref(db, `users/${userId}`));
```

**Android (Kotlin)**

```kotlin
val db = Firebase.database.reference

// Write
db.child("users").child(user.uid)
  .setValue(hashMapOf("name" to "Alice"))
  .addOnSuccessListener { Log.d(TAG, "Written") }

// Read once
db.child("users").child(userId).get()
  .addOnSuccessListener { snap ->
    if (snap.exists()) Log.d(TAG, snap.value.toString())
  }
```

**iOS (Swift)**

```swift
let ref = Database.database().reference()

// Write
ref.child("users/\(user.uid)").setValue(["name": "Alice"])

// Read once
ref.child("users/\(userId)").getData { error, snap in
  if let val = snap?.value { print(val) }
}
```

### 3-3. リアルタイムリスナー（RTDB）

RTDBはWebSocket常時接続でリアルタイム同期を実現する。レイテンシはFirestoreより低い。

```typescript
import { ref, onValue, onChildAdded, onChildChanged, onChildRemoved, off } from 'firebase/database';

// value イベント（ノード全体の変化を監視）
const userRef = ref(db, `users/${userId}`);
const unsubValue = onValue(userRef, (snap) => {
  console.log('User data:', snap.val());
});

// child_* イベント（リスト操作に効率的）
const postsRef = ref(db, 'posts');
const unsubAdded = onChildAdded(postsRef, (snap) => {
  appendPost({ id: snap.key, ...snap.val() });
});
const unsubChanged = onChildChanged(postsRef, (snap) => {
  updatePost({ id: snap.key, ...snap.val() });
});
const unsubRemoved = onChildRemoved(postsRef, (snap) => {
  removePost(snap.key);
});

// リスナー解除
off(postsRef);  // そのrefのすべてのリスナーを解除
```

### 3-4. RTDB Security Rules

```json
{
  "rules": {
    ".read": false,
    ".write": false,
    "users": {
      "$userId": {
        ".read": "auth != null && auth.uid == $userId",
        ".write": "auth != null && auth.uid == $userId",
        ".validate": "newData.hasChildren(['name', 'email'])"
      }
    },
    "posts": {
      ".read": "auth != null",
      "$postId": {
        ".write": "auth != null && (!data.exists() || data.child('authorId').val() == auth.uid)",
        ".validate": "newData.hasChildren(['title', 'authorId'])"
      }
    },
    "user-posts": {
      "$userId": {
        ".read": "auth != null && auth.uid == $userId",
        ".write": "auth != null && auth.uid == $userId"
      }
    }
  }
}
```

---

## 4. パフォーマンス最適化

### Firestoreの最適化

| 課題 | 対策 |
|------|------|
| 大量の読み取りコスト | `limit()` で取得件数を絞る、ページネーションを実装 |
| 頻繁なカウント操作 | `increment()` + dedicated counter doc を使用 |
| 不要なリスナーコスト | コンポーネントのアンマウント時に必ず `unsubscribe()` |
| 書き込みレート制限 | 同一ドキュメントは最大1回/秒。カウンターは分散カウンタ設計へ |
| 複合クエリの失敗 | `firestore.indexes.json` で事前にインデックスを定義・デプロイ |

### RTDBの最適化

| 課題 | 対策 |
|------|------|
| 深いネストで大量データ転送 | ルートリスナーを避ける。必要なパスのみを監視 |
| クエリ範囲の絞り込み | `limitToFirst()` / `limitToLast()` + `orderByChild()` |
| 接続数の管理 | 不要なリスナーは `off()` で解除。画面遷移時に整理 |

```typescript
// RTDB: 最新10件のみ取得
import { query, ref, orderByChild, limitToLast } from 'firebase/database';
const recentQ = query(ref(db, 'posts'), orderByChild('createdAt'), limitToLast(10));
```

---

## 5. マイグレーションガイド（RTDB → Firestore）

```typescript
// RTDB から Firestore へのデータ移行スクリプト例（Node.js / admin SDK）
import * as admin from 'firebase-admin';

admin.initializeApp();
const rtdb = admin.database();
const firestore = admin.firestore();

const migrateUsers = async () => {
  const snap = await rtdb.ref('users').once('value');
  const batch = firestore.batch();
  let count = 0;

  snap.forEach((child) => {
    const userRef = firestore.collection('users').doc(child.key!);
    batch.set(userRef, child.val());
    count++;

    // Firestoreのバッチ上限は500
    if (count === 500) {
      batch.commit();
      count = 0;
    }
  });

  if (count > 0) await batch.commit();
};
```

---

## 6. Emulatorでのローカル開発

```typescript
import { connectFirestoreEmulator } from 'firebase/firestore';
import { connectDatabaseEmulator } from 'firebase/database';

if (process.env.NODE_ENV === 'development') {
  connectFirestoreEmulator(db, 'localhost', 8080);
  connectDatabaseEmulator(rtdb, 'localhost', 9000);
}
```

```bash
# Emulator起動（データを永続化）
firebase emulators:start \
  --only firestore,database \
  --import=./emulator-data \
  --export-on-exit
```

---

## まとめ: 使い分けの原則

```
新規プロジェクト → Cloud Firestore（デフォルト）
  ├─ 理由: スケーラブル・複合クエリ・Web オフライン・マルチリージョン
  └─ コスト: 読み書き回数に注意（limitと不要リスナー解除を徹底）

リアルタイム性最優先 → Realtime Database
  ├─ 理由: WebSocket常時接続で超低レイテンシ
  └─ 制約: フラットなデータ設計必須・複雑なクエリは不向き

両方使うケース:
  ├─ RTDBをリアルタイム同期専用（チャット・プレゼンス）
  └─ Firestoreを本体データ管理用に使い分けることも可能
```
