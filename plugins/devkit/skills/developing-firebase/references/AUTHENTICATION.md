# Firebase Authentication 詳細リファレンス

## 認証方式選択ガイド

| 方式 | SDK呼び出し | 向いているケース |
|------|------------|-----------------|
| Email/Password | `createUserWithEmailAndPassword` | 独自ブランドUX、業務アプリ |
| Google | `GoogleAuthProvider` | コンシューマーアプリ、Workspace連携 |
| Apple | `OAuthProvider('apple.com')` | iOS App Store審査要件（必須） |
| GitHub | `GithubAuthProvider` | 開発者向けツール |
| 電話番号 SMS | `signInWithPhoneNumber` | モバイルファースト |
| 匿名 | `signInAnonymously` | ゲスト体験→後でアカウント昇格 |
| カスタムトークン | `signInWithCustomToken` | 既存認証システムとのブリッジ |

---

## 1. Email/Password 認証

### サインアップ・メール確認

```typescript
// Web (Modular SDK)
import { createUserWithEmailAndPassword, sendEmailVerification, updateProfile } from 'firebase/auth';

const { user } = await createUserWithEmailAndPassword(auth, email, password);
await updateProfile(user, { displayName: name });
await sendEmailVerification(user); // 確認メール送信
```

```java
// Android (Java)
mAuth.createUserWithEmailAndPassword(email, password).addOnCompleteListener(task -> {
    if (task.isSuccessful()) {
        FirebaseUser user = mAuth.getCurrentUser();
        user.sendEmailVerification();
    }
});
```

```swift
// iOS (Swift)
Auth.auth().createUser(withEmail: email, password: password) { result, error in
    guard let user = result?.user, error == nil else { return }
    user.sendEmailVerification()
}
```

### パスワードリセット

```typescript
import { sendPasswordResetEmail } from 'firebase/auth';
await sendPasswordResetEmail(auth, email, { url: 'https://yourapp.com/login' });
```

### エラーコード対応表

| エラーコード | 原因 | UX上の対処 |
|-------------|------|-----------|
| `auth/email-already-in-use` | メール重複 | 「ログイン」または「パスワードリセット」へ誘導 |
| `auth/user-not-found` / `auth/wrong-password` | 認証失敗 | 「認証情報が正しくない」と統一表示（列挙攻撃防止） |
| `auth/weak-password` | 6文字未満 | パスワード強度メーターで事前警告 |
| `auth/too-many-requests` | レートリミット | しばらく待つよう案内 |
| `auth/popup-blocked` | ポップアップブロック | `signInWithRedirect` にフォールバック |

---

## 2. ソーシャルログイン

### Popup vs Redirect 選択

| 方式 | 特徴 | 推奨環境 |
|------|------|---------|
| `signInWithPopup` | UX良好、ポップアップブロックのリスクあり | デスクトップWeb |
| `signInWithRedirect` | ページ遷移あり、ブロックされにくい | モバイルWeb / Safari |

### Google サインイン

```typescript
import { GoogleAuthProvider, signInWithPopup, signInWithRedirect, getRedirectResult } from 'firebase/auth';

const provider = new GoogleAuthProvider();
provider.addScope('profile'); // 追加スコープ（任意）

// Popup方式
const result = await signInWithPopup(auth, provider);
const accessToken = GoogleAuthProvider.credentialFromResult(result)?.accessToken;

// Redirect方式（モバイル推奨）
await signInWithRedirect(auth, provider);
const redirectResult = await getRedirectResult(auth); // ページロード後に取得
```

```java
// Android - credential取得後にFirebase認証
AuthCredential credential = GoogleAuthProvider.getCredential(account.getIdToken(), null);
mAuth.signInWithCredential(credential).addOnCompleteListener(task -> { /* ... */ });
```

### Apple サインイン（iOS App Store必須）

```typescript
// Web
import { OAuthProvider } from 'firebase/auth';
const provider = new OAuthProvider('apple.com');
provider.addScope('email');
provider.addScope('name');
const result = await signInWithPopup(auth, provider);
```

```swift
// iOS - ASAuthorizationAppleIDRequest でトークン取得後:
let credential = OAuthProvider.credential(
    withProviderID: "apple.com", idToken: idTokenString, rawNonce: nonce
)
Auth.auth().signIn(with: credential) { result, error in /* ... */ }
```

### GitHub / Facebook / Twitter（同一パターン）

```typescript
import { GithubAuthProvider, signInWithPopup } from 'firebase/auth';
// FacebookAuthProvider, TwitterAuthProvider も同様
const provider = new GithubAuthProvider();
provider.addScope('repo'); // プロバイダー固有のスコープ
const result = await signInWithPopup(auth, provider);
```

### アカウントリンク（複数プロバイダー統合）

```typescript
import { linkWithPopup, unlink } from 'firebase/auth';
// 既存アカウントにGoogleをリンク
await linkWithPopup(auth.currentUser!, new GoogleAuthProvider());
// リンク解除
await unlink(auth.currentUser!, 'google.com');
```

---

## 3. 匿名認証 → アカウント昇格

```typescript
import { signInAnonymously, linkWithCredential, EmailAuthProvider } from 'firebase/auth';

// ゲストとして開始（uid でFirestoreデータを紐付け）
const { user: guestUser } = await signInAnonymously(auth);

// Email/Passwordで昇格 → uid は変わらずデータが引き継がれる
const credential = EmailAuthProvider.credential(email, password);
await linkWithCredential(guestUser, credential);
```

> **注意**: 匿名ユーザーはアプリアンインストール/データクリアで消えるため、重要データは早めの昇格を促すUXにすること。

---

## 4. セッション管理

### 認証状態の監視

```typescript
import { onAuthStateChanged, User } from 'firebase/auth';

const unsubscribe = onAuthStateChanged(auth, (user: User | null) => {
  if (user) {
    // user.uid, user.email, user.displayName, user.emailVerified
    // await user.getIdToken() → Backend API認証用IDトークン
  } else {
    // 未ログイン → ログインページへリダイレクト
  }
});
return unsubscribe; // コンポーネントアンマウント時に解除
```

```java
// Android - AuthStateListener
mAuth.addAuthStateListener(auth -> {
    FirebaseUser user = auth.getCurrentUser();
    if (user != null) { /* ログイン済み */ } else { /* 未ログイン */ }
});
// onStop で removeAuthStateListener()
```

### 永続化設定（Web）

| 設定 | 動作 | 使用場面 |
|------|------|---------|
| `browserLocalPersistence` | ブラウザ再起動後も維持（デフォルト） | 一般的なWebアプリ |
| `browserSessionPersistence` | タブを閉じると消える | 共有PC・セキュリティ重視 |
| `inMemoryPersistence` | メモリのみ（リロードで消える） | SSR・テスト |

```typescript
import { setPersistence, browserSessionPersistence } from 'firebase/auth';
await setPersistence(auth, browserSessionPersistence);
await signInWithEmailAndPassword(auth, email, password);
```

---

## 5. 多要素認証 (MFA)

> Blaze（有料）プラン必須。SMS と TOTP（認証アプリ）をサポート。

### MFA登録フロー（SMS）

```typescript
import { multiFactor, PhoneAuthProvider, PhoneMultiFactorGenerator } from 'firebase/auth';

// セッション取得 → SMS送信 → 検証・登録
const session = await multiFactor(auth.currentUser!).getSession();
const verificationId = await new PhoneAuthProvider(auth)
    .verifyPhoneNumber({ phoneNumber: '+819012345678', session }, recaptchaVerifier);
const assertion = PhoneMultiFactorGenerator.assertion(
    PhoneAuthProvider.credential(verificationId, userEnteredCode)
);
await multiFactor(auth.currentUser!).enroll(assertion, '携帯電話');
```

### MFAログインフロー

```typescript
import { getMultiFactorResolver, MultiFactorError } from 'firebase/auth';

try {
  await signInWithEmailAndPassword(auth, email, password);
} catch (error) {
  if ((error as any).code === 'auth/multi-factor-auth-required') {
    const resolver = getMultiFactorResolver(auth, error as MultiFactorError);
    const verificationId = await new PhoneAuthProvider(auth).verifyPhoneNumber(
      { multiFactorHint: resolver.hints[0], session: resolver.session },
      recaptchaVerifier
    );
    await resolver.resolveSignIn(
      PhoneMultiFactorGenerator.assertion(PhoneAuthProvider.credential(verificationId, code))
    );
  }
}
```

---

## 6. カスタム認証 + Admin SDK

### カスタムトークン発行（Backend）

```typescript
// Cloud Functions / Node.js バックエンド
import * as admin from 'firebase-admin';

// 既存システムのユーザーIDでトークン生成
const token = await admin.auth().createCustomToken('existing-uid', {
  role: 'editor',         // カスタムクレーム（Firestore Rulesで利用可）
  premiumAccount: true,
});
// このトークンをクライアントへ返す
```

```typescript
// Frontend - カスタムトークンでサインイン
import { signInWithCustomToken } from 'firebase/auth';
const token = await fetchTokenFromYourBackend();
await signInWithCustomToken(auth, token);
```

```java
// Android
mAuth.signInWithCustomToken(customToken)
    .addOnCompleteListener(task -> { if (task.isSuccessful()) { /* ログイン完了 */ } });
```

### カスタムクレーム（RBAC実装）

```typescript
// クレームを設定（即時反映はIDトークンリフレッシュ後）
await admin.auth().setCustomUserClaims(uid, { admin: true, role: 'manager' });
```

```
// firestore.rules でクレームを参照
match /admin/{doc} { allow read, write: if request.auth.token.admin == true; }
match /posts/{doc}  { allow write: if request.auth.token.role == 'manager'; }
```

### ユーザー管理（Admin SDK）

```typescript
// ユーザー情報取得・更新・削除
const user = await admin.auth().getUser(uid);
await admin.auth().updateUser(uid, { disabled: true, displayName: '新しい名前' });
await admin.auth().deleteUser(uid);

// Backend APIでIDトークン検証
const decoded = await admin.auth().verifyIdToken(idTokenFromRequest);
const { uid, email, admin: isAdmin } = decoded;
```

---

## 7. セキュリティベストプラクティス

| 優先度 | 対策 | 実装 |
|--------|------|------|
| 🔴 最重要 | Backend側でIDトークンを必ず検証 | `admin.auth().verifyIdToken()` |
| 🔴 最重要 | Security Rulesで認証必須 | 全ルールに`request.auth != null` |
| 🔴 最重要 | APIキーをソースコードに含めない | `.env`ファイルと環境変数 |
| 🟡 重要 | メール確認済みのみ機能利用 | `user.emailVerified`チェック |
| 🟡 重要 | 重要操作前に再認証 | `reauthenticateWithCredential()` |
| 🟡 重要 | MFAを決済・設定変更に必須化 | Blaze + MFA Enrollment UI |
| 🟢 推奨 | 共有PCは`sessionPersistence` | 永続化設定を適切に選択 |
| 🟢 推奨 | Firebase SDK最新に維持 | セキュリティパッチを取り込む |

### Backend認証ミドルウェア（Express/NestJS）

```typescript
async function verifyFirebaseToken(req, res, next) {
  const token = req.headers.authorization?.split('Bearer ')[1];
  if (!token) return res.status(401).json({ error: 'Unauthorized' });
  try {
    req.user = await admin.auth().verifyIdToken(token); // uid, email, customClaims
    next();
  } catch {
    res.status(403).json({ error: 'Invalid token' });
  }
}
```

---

## 関連リファレンス

- [`SKILL.md`](../SKILL.md) — 認証方式クイックリファレンス・基本コード例
- [`DATABASE.md`](DATABASE.md) — Security Rulesとの連携パターン
- [`FUNCTIONS.md`](FUNCTIONS.md) — `beforeUserCreated` / `onUserDeleted` トリガー
