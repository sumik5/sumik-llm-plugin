---
name: developing-firebase
description: >-
  Firebase platform development guide covering Authentication (email/social/session),
  Firestore & Realtime Database (modeling/queries/security rules),
  Cloud Storage, Cloud Functions (triggers/scheduling), Hosting,
  Analytics (events/BigQuery), FCM push notifications,
  Remote Config, Test Lab, Performance Monitoring, Dynamic Links,
  App Distribution, AdMob, and Extensions.
  MUST load when firebase, @firebase, or firebase-admin packages detected,
  or firebaseConfig/firebase.json/firestore.rules files present.
  For GCP infra→developing-google-cloud. For Next.js integration→developing-nextjs.
  For REST API design→developing-web-apis.
---

# Firebase 開発ガイド

## 1. Firebaseエコシステム概要

Firebase は Google が提供する BaaS（Backend-as-a-Service）プラットフォーム。3つの柱でアプリ開発を支援する。

| 柱 | 主要サービス |
|----|-------------|
| **Build** | Authentication, Firestore, RTDB, Storage, Functions, Hosting |
| **Release & Monitor** | Crashlytics, Performance Monitoring, Test Lab, App Distribution |
| **Engage** | Analytics, FCM, In-App Messaging, Remote Config, Dynamic Links |

### サービス選択フロー

```
データ永続化が必要?
├─ リアルタイム同期・シンプル構造 → Realtime Database
├─ 複雑なクエリ・スケーラブル     → Cloud Firestore ← 基本的にこちら
└─ ファイル（画像・動画等）        → Cloud Storage

ロジック実行が必要?
├─ Firebase イベントトリガー       → Cloud Functions
├─ HTTP API エンドポイント         → Cloud Functions (HTTPS)
└─ スケジューリング               → Cloud Functions (Scheduled)

ユーザー管理が必要?
└─ Firebase Authentication（必須）

Web公開が必要?
└─ Firebase Hosting（CDN + SSL自動）
```

### プロジェクト初期化・SDK設定

**Web (JS/TS)**
```typescript
import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';
import { getStorage } from 'firebase/storage';

const app = initializeApp({
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
});

export const auth = getAuth(app);
export const db = getFirestore(app);
export const storage = getStorage(app);
```

**Android (Kotlin)**
```kotlin
// build.gradle (app)
implementation(platform("com.google.firebase:firebase-bom:32.7.0"))
implementation("com.google.firebase:firebase-auth-ktx")
implementation("com.google.firebase:firebase-firestore-ktx")
```

**iOS (Swift)**
```swift
import FirebaseCore
// AppDelegate.swift
FirebaseApp.configure()
```

---

## 2. コアサービス早見表

### 2-1. Authentication（認証方式選択）

| 方式 | SDK呼び出し | 主なユースケース |
|------|------------|----------------|
| Email/Password | `createUserWithEmailAndPassword` / `signInWithEmailAndPassword` | 一般的なサインアップ |
| Google | `signInWithPopup(new GoogleAuthProvider())` | ワンクリックログイン |
| GitHub / Twitter / Facebook | `signInWithPopup(new GithubAuthProvider())` | 開発者向け・SNS系 |
| 電話番号 (SMS) | `signInWithPhoneNumber` | モバイル優先アプリ |
| 匿名 | `signInAnonymously` | ゲストユーザー→後でアカウント昇格 |
| カスタム | `signInWithCustomToken` | 既存の認証システム連携 |

```typescript
// Email/Password サインアップ例
import { createUserWithEmailAndPassword, sendEmailVerification } from 'firebase/auth';

const { user } = await createUserWithEmailAndPassword(auth, email, password);
await sendEmailVerification(user); // メール認証送信

// ソーシャルログイン（Google）
import { GoogleAuthProvider, signInWithPopup } from 'firebase/auth';
const provider = new GoogleAuthProvider();
const result = await signInWithPopup(auth, provider);

// 認証状態監視
import { onAuthStateChanged } from 'firebase/auth';
onAuthStateChanged(auth, (user) => {
  if (user) {
    // ログイン済み: user.uid, user.email, user.displayName
  }
});
```

詳細: [`references/AUTHENTICATION.md`](references/AUTHENTICATION.md) — セッション管理・MFA・カスタムクレーム

---

### 2-2. Database選択（Firestore vs RTDB）

| 比較軸 | Cloud Firestore | Realtime Database |
|--------|----------------|-------------------|
| データ構造 | コレクション/ドキュメント | JSONツリー |
| クエリ | 複合クエリ・インデックス対応 | 単純な絞り込みのみ |
| スケーラビリティ | 自動スケーリング | リージョン単一・制限あり |
| オフライン | ✅ Web/iOS/Android | ✅ iOS/Android のみ |
| コスト | 読書き回数課金 | 帯域幅/ストレージ課金 |
| **推奨用途** | **新規アプリ（基本こちら）** | リアルタイムチャット・IoT |

```typescript
// Firestore CRUD
import { collection, doc, setDoc, getDoc, updateDoc, deleteDoc, query, where, getDocs } from 'firebase/firestore';

// 作成・更新
await setDoc(doc(db, 'users', userId), { name: 'Alice', age: 30 });
await updateDoc(doc(db, 'users', userId), { age: 31 });

// 読み込み
const snap = await getDoc(doc(db, 'users', userId));
if (snap.exists()) console.log(snap.data());

// クエリ
const q = query(collection(db, 'users'), where('age', '>', 18));
const querySnap = await getDocs(q);
querySnap.forEach(doc => console.log(doc.id, doc.data()));

// リアルタイムリスナー
import { onSnapshot } from 'firebase/firestore';
const unsubscribe = onSnapshot(collection(db, 'messages'), (snap) => {
  snap.docChanges().forEach(change => {
    if (change.type === 'added') console.log('New:', change.doc.data());
  });
});
```

```kotlin
// Android (Kotlin) Firestore
val db = Firebase.firestore
db.collection("users").document(userId)
  .set(hashMapOf("name" to "Alice", "age" to 30))
  .addOnSuccessListener { Log.d("TAG", "DocumentSnapshot written") }
```

詳細: [`references/DATABASE.md`](references/DATABASE.md) — データモデリング・トランザクション・インデックス設計

---

### 2-3. Cloud Storage（ファイル管理）

```typescript
import { ref, uploadBytes, getDownloadURL, deleteObject } from 'firebase/storage';

// アップロード
const storageRef = ref(storage, `images/${userId}/profile.jpg`);
const snapshot = await uploadBytes(storageRef, file);
const downloadURL = await getDownloadURL(snapshot.ref);

// 削除
await deleteObject(ref(storage, `images/${userId}/profile.jpg`));
```

```swift
// iOS (Swift)
let storageRef = Storage.storage().reference().child("images/\(uid)/profile.jpg")
storageRef.putData(imageData, metadata: nil) { metadata, error in
  storageRef.downloadURL { url, error in /* use url */ }
}
```

詳細: [`references/STORAGE-AND-HOSTING.md`](references/STORAGE-AND-HOSTING.md)

---

### 2-4. Cloud Functions（トリガー種別）

| トリガー種別 | 記述例 | 主なユースケース |
|------------|--------|----------------|
| HTTP | `onRequest` | REST API・Webhook |
| Firestore | `onDocumentCreated` / `onDocumentUpdated` | データ変換・通知送信 |
| Auth | `beforeUserCreated` / `onUserDeleted` | プロファイル初期化・クリーンアップ |
| Storage | `onObjectFinalized` | 画像リサイズ・ウイルススキャン |
| Pub/Sub | `onMessagePublished` | 非同期処理パイプライン |
| Scheduled | `onSchedule` | 定期バッチ処理 |

```typescript
// functions/src/index.ts
import { onRequest } from 'firebase-functions/v2/https';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import * as admin from 'firebase-admin';

admin.initializeApp();

// HTTP トリガー
export const api = onRequest({ region: 'asia-northeast1' }, (req, res) => {
  res.json({ message: 'Hello from Firebase!' });
});

// Firestore トリガー（新規ユーザー作成時）
export const onUserCreated = onDocumentCreated('users/{userId}', async (event) => {
  const userId = event.params.userId;
  const data = event.data?.data();
  // ウェルカムメール送信等の処理
});

// スケジュールトリガー（毎日午前2時）
export const dailyCleanup = onSchedule('0 2 * * *', async () => {
  // 期限切れデータのクリーンアップ
});
```

詳細: [`references/FUNCTIONS.md`](references/FUNCTIONS.md) — 環境変数・エラーハンドリング・デプロイ設定

---

### 2-5. Hosting（デプロイフロー）

```bash
# セットアップ
npm install -g firebase-tools
firebase login
firebase init hosting  # public dir, SPA rewrite設定

# デプロイ
firebase deploy --only hosting

# プレビューチャンネル（PR確認用）
firebase hosting:channel:deploy preview-branch
```

```json
// firebase.json
{
  "hosting": {
    "public": "out",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
    "rewrites": [{ "source": "**", "destination": "/index.html" }],
    "headers": [
      { "source": "**/*.@(js|css)", "headers": [{ "key": "Cache-Control", "value": "max-age=31536000" }] }
    ]
  }
}
```

詳細: [`references/STORAGE-AND-HOSTING.md`](references/STORAGE-AND-HOSTING.md) — カスタムドメイン・リライト・CI/CD統合

---

## 3. Security Rules設計原則

### 共通パターン

| パターン | 用途 | ルール例 |
|---------|------|---------|
| 認証必須 | すべての操作で認証要求 | `request.auth != null` |
| 所有権チェック | 自分のデータのみ操作 | `request.auth.uid == userId` |
| ロールベース | カスタムクレームで権限管理 | `request.auth.token.admin == true` |
| データ検証 | 書き込みデータのバリデーション | `request.resource.data.age is int` |

### Firestore Security Rules

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

    // ユーザープロフィール: 本人のみ読み書き
    match /users/{userId} {
      allow read: if isAuthenticated() && isOwner(userId);
      allow write: if isOwner(userId) && request.resource.data.keys().hasAll(['name', 'email']);
    }

    // 投稿: 認証済みユーザーは全員読み取り可、作成者のみ編集・削除
    match /posts/{postId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated() && request.resource.data.authorId == request.auth.uid;
      allow update, delete: if resource.data.authorId == request.auth.uid;
    }

    // 管理者専用
    match /admin/{document=**} {
      allow read, write: if isAdmin();
    }
  }
}
```

### Realtime Database Rules

```json
{
  "rules": {
    "users": {
      "$userId": {
        ".read": "auth != null && auth.uid == $userId",
        ".write": "auth != null && auth.uid == $userId"
      }
    },
    "posts": {
      ".read": "auth != null",
      "$postId": {
        ".write": "auth != null && (!data.exists() || data.child('authorId').val() == auth.uid)"
      }
    }
  }
}
```

### Storage Rules

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // ユーザー固有の画像: 本人のみ操作可
    match /images/{userId}/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null
                   && request.auth.uid == userId
                   && request.resource.size < 5 * 1024 * 1024  // 5MB制限
                   && request.resource.contentType.matches('image/.*');
      allow delete: if request.auth.uid == userId;
    }
  }
}
```

---

## 4. 運用・スケーリング

### Emulatorスイート活用

```bash
# Emulator起動（開発中は必ずローカルで完結させる）
firebase emulators:start --import=./emulator-data --export-on-exit

# Emulator接続（アプリ側）
```

```typescript
import { connectFirestoreEmulator } from 'firebase/firestore';
import { connectAuthEmulator } from 'firebase/auth';
import { connectStorageEmulator } from 'firebase/storage';
import { connectFunctionsEmulator } from 'firebase/functions';

if (process.env.NODE_ENV === 'development') {
  connectAuthEmulator(auth, 'http://localhost:9099');
  connectFirestoreEmulator(db, 'localhost', 8080);
  connectStorageEmulator(storage, 'localhost', 9199);
  connectFunctionsEmulator(functions, 'localhost', 5001);
}
```

| Emulator | ポート | 用途 |
|---------|--------|------|
| Authentication | 9099 | 認証テスト（実際のメール不要） |
| Firestore | 8080 | データ操作テスト |
| Storage | 9199 | ファイル操作テスト |
| Functions | 5001 | トリガー動作確認 |
| Hosting | 5000 | デプロイ前確認 |
| UI | 4000 | 全体ダッシュボード |

### パフォーマンス最適化

| 対策 | 対象 | 方法 |
|------|------|------|
| クエリ絞り込み | Firestore | `limit()` で取得件数を制限 |
| インデックス | Firestore | 複合クエリには `firestore.indexes.json` で事前定義 |
| オフラインキャッシュ | Firestore/RTDB | `enableIndexedDbPersistence()` |
| 遅延ロード | Functions | Cold start対策: 最小依存・メモリ設定 |
| CDNキャッシュ | Hosting | 静的アセットに長期 Cache-Control を設定 |

### コスト管理

| サービス | 無料枠（Spark） | 注意点 |
|---------|--------------|--------|
| Firestore | 読み取り5万回/日、書き込み2万回/日 | 不要なリスナー解除を徹底 |
| Storage | 5GB, 1GB/日ダウンロード | 大容量ファイルはCDN経由で配信 |
| Functions | 呼び出し200万回/月 | 無限ループに注意（トリガーの連鎖） |
| Hosting | 10GB/月 | 静的アセットの圧縮で削減 |

```typescript
// Firestore: 不要なリスナー解除
const unsubscribe = onSnapshot(query, callback);
// コンポーネントアンマウント時
return () => unsubscribe();
```

---

## 5. リファレンス索引

| ファイル | カバー内容 | 主なトピック |
|---------|-----------|------------|
| [`references/AUTHENTICATION.md`](references/AUTHENTICATION.md) | 認証詳細 | Email/Social実装・セッション管理・MFA・カスタムクレーム・匿名→昇格 |
| [`references/DATABASE.md`](references/DATABASE.md) | Firestore + RTDB | データモデリング・複合クエリ・トランザクション・バッチ・インデックス・RTDB構造設計 |
| [`references/STORAGE-AND-HOSTING.md`](references/STORAGE-AND-HOSTING.md) | Storage + Hosting | アップロード/ダウンロード・メタデータ・カスタムドメイン・リライト・プレビューChannel |
| [`references/FUNCTIONS.md`](references/FUNCTIONS.md) | Cloud Functions | 全トリガー詳細・環境変数・シークレット管理・エラーハンドリング・Gen2移行 |
| [`references/ANALYTICS-AND-MONITORING.md`](references/ANALYTICS-AND-MONITORING.md) | Analytics + 監視 | カスタムイベント・BigQuery連携・Crashlytics・Performance Monitoring |
| [`references/MESSAGING.md`](references/MESSAGING.md) | FCM + Remote Config | プッシュ通知送信・トピック購読・Remote Config A/Bテスト・Dynamic Links |
| [`references/TESTING-AND-DISTRIBUTION.md`](references/TESTING-AND-DISTRIBUTION.md) | テスト + 配布 | Test Lab・Emulatorテスト戦略・App Distribution・CI/CD統合 |
| [`references/EXTENSIONS-AND-ADVANCED.md`](references/EXTENSIONS-AND-ADVANCED.md) | 拡張機能・応用 | Firebase Extensions・AdMob・クロスプラットフォーム固有パターン |
