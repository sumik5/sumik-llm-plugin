# Cloud Storage & Hosting リファレンス

## 1. Cloud Storage — ファイルアップロード

**Web (TypeScript) — 進捗モニタリング付き**
```typescript
import { ref, uploadBytesResumable, getDownloadURL, deleteObject } from 'firebase/storage';

const storageRef = ref(storage, `images/${userId}/profile.jpg`);

// 進捗モニタリング（大ファイル向け）
const uploadTask = uploadBytesResumable(storageRef, file);
uploadTask.on('state_changed',
  (snap) => {
    const pct = (snap.bytesTransferred / snap.totalBytes) * 100;
    console.log(`${pct.toFixed(0)}%`);
  },
  (err) => console.error(err),
  async () => {
    const url = await getDownloadURL(uploadTask.snapshot.ref);
    // url を画像表示やFirestoreに保存
  }
);
uploadTask.pause(); uploadTask.resume(); uploadTask.cancel(); // 制御

// シンプルアップロード（uploadBytes でOK、戻り値に ref 付き）
const { ref: snapRef } = await uploadBytes(storageRef, file);
const url = await getDownloadURL(snapRef);
```

**Android (Kotlin)**
```kotlin
val storageRef = Firebase.storage.reference.child("images/$userId/profile.jpg")
storageRef.putFile(fileUri)
  .addOnProgressListener { snap ->
    val pct = 100.0 * snap.bytesTransferred / snap.totalByteCount
    Log.d("Storage", "Upload: $pct%")
  }
  .addOnSuccessListener {
    storageRef.downloadUrl.addOnSuccessListener { uri -> /* use uri */ }
  }
```

**iOS (Swift)**
```swift
let ref = Storage.storage().reference().child("images/\(uid)/profile.jpg")
let task = ref.putData(imageData) { _, error in
    guard error == nil else { return }
    ref.downloadURL { url, _ in /* use url */ }
}
task.observe(.progress) { snap in
    let pct = Double(snap.progress!.completedUnitCount) / Double(snap.progress!.totalUnitCount)
    print("Progress: \(pct * 100)%")
}
```

---

## 2. ダウンロード・一覧・削除

```typescript
import { getDownloadURL, listAll, deleteObject } from 'firebase/storage';

// ダウンロードURL（<img src> や fetch() で使用）
const url = await getDownloadURL(ref(storage, `images/${userId}/profile.jpg`));

// フォルダ内一覧
const { items } = await listAll(ref(storage, `images/${userId}/`));
const urls = await Promise.all(items.map(r => getDownloadURL(r)));

// 削除
await deleteObject(ref(storage, `images/${userId}/old.jpg`));
```

---

## 3. ファイルメタデータ

```typescript
import { getMetadata, updateMetadata } from 'firebase/storage';

// アップロード時にメタデータ添付
await uploadBytes(storageRef, file, {
  contentType: 'image/jpeg',
  customMetadata: {
    uploadedBy: userId,
    uploadDate: new Date().toISOString(),
  },
});

// メタデータ取得
const meta = await getMetadata(storageRef);
// meta.size / meta.contentType / meta.timeCreated / meta.customMetadata

// カスタムメタデータ更新（customMetadata フィールドのみ変更可）
await updateMetadata(storageRef, { customMetadata: { status: 'approved' } });
```

---

## 4. Storage Security Rules

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    function isAuth()         { return request.auth != null; }
    function isOwner(uid)     { return request.auth.uid == uid; }
    function isImage()        { return request.resource.contentType.matches('image/.*'); }
    function maxMB(n)         { return request.resource.size < n * 1024 * 1024; }

    // プロフィール画像: 本人のみ書込、全認証ユーザーが閲覧
    match /images/{userId}/{filename} {
      allow read:   if isAuth();
      allow create: if isOwner(userId) && isImage() && maxMB(5);
      allow update: if isOwner(userId) && isImage() && maxMB(5);
      allow delete: if isOwner(userId);
    }

    // 公開ファイル（誰でも読み取り可）
    match /public/{allPaths=**} {
      allow read;
      allow write: if isAuth() && maxMB(10);
    }

    // 管理者専用
    match /admin/{allPaths=**} {
      allow read, write: if request.auth.token.admin == true;
    }
  }
}
```

**ルールの要点:**
- `request.resource` = アップロード前のデータ（write時のみ有効）
- `resource` = 既存のデータ（update/deleteで参照）
- `contentType` チェックでマルウェアアップロードを防止

---

## 5. Firebase Hosting — デプロイフロー

```bash
# 初期セットアップ
npm install -g firebase-tools && firebase login
firebase init hosting
# → public: out / dist / build（フレームワーク依存）
# → SPA rewrites: Yes

# ビルド & デプロイ
npm run build && firebase deploy --only hosting

# PRプレビューチャンネル（7日で自動削除）
firebase hosting:channel:deploy preview-${BRANCH} --expires 7d

# ロールバック（Console または CLI）
firebase hosting:clone <SOURCE_SITE_ID>:@latest <TARGET_SITE_ID>:live
```

---

## 6. firebase.json 完全設定例

```json
{
  "hosting": {
    "public": "out",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
    "cleanUrls": true,
    "trailingSlash": false,

    "rewrites": [
      { "source": "/api/**",  "function": "api" },
      { "source": "**",       "destination": "/index.html" }
    ],

    "redirects": [
      { "source": "/old",     "destination": "/new",   "type": 301 },
      { "source": "/blog/:p", "destination": "/posts/:p", "type": 301 }
    ],

    "headers": [
      {
        "source": "**/*.@(js|css)",
        "headers": [{ "key": "Cache-Control", "value": "public, max-age=31536000, immutable" }]
      },
      {
        "source": "**/*.@(jpg|jpeg|png|svg|webp|ico)",
        "headers": [{ "key": "Cache-Control", "value": "public, max-age=604800" }]
      },
      {
        "source": "**",
        "headers": [
          { "key": "X-Frame-Options",       "value": "SAMEORIGIN" },
          { "key": "X-Content-Type-Options", "value": "nosniff" }
        ]
      }
    ]
  }
}
```

| 設定キー | 用途 |
|----------|------|
| `cleanUrls` | `/about.html` → `/about` 自動変換 |
| `rewrites[].function` | Cloud Functions へルーティング（SSR） |
| `rewrites[].destination` | SPA用 `/index.html` フォールバック |
| `redirects[].type` | 301（恒久）/ 302（一時） |
| `headers` | キャッシュ制御・セキュリティヘッダー |

---

## 7. カスタムドメイン設定

```
1. ドメイン取得（GoDaddy / Namecheap / Google Domains 等）

2. Firebase Console → Hosting → 「カスタムドメインを追加」

3. 所有権確認
   TXT レコードを DNS に追加（Firebase コンソール指示通り）

4. DNS レコード設定
   A レコード → Firebase の IP（コンソール表示）
   www: CNAME → <project-id>.web.app

5. SSL 証明書
   自動プロビジョニング（完了まで最大48時間）＆ 自動更新

確認コマンド:
  dig yourdomain.com A
  curl -I https://yourdomain.com
```

---

## 8. CI/CD 統合（GitHub Actions）

```yaml
# .github/workflows/hosting-deploy.yml
name: Firebase Hosting Deploy

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: npm }
      - run: npm ci && npm run build

      # PR: プレビューチャンネルへ
      - if: github.event_name == 'pull_request'
        uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: ${{ secrets.GITHUB_TOKEN }}
          firebaseServiceAccount: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}
          projectId: my-project
          channelId: pr-${{ github.event.number }}

      # main: 本番へ
      - if: github.ref == 'refs/heads/main'
        uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: ${{ secrets.GITHUB_TOKEN }}
          firebaseServiceAccount: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}
          projectId: my-project
          channelId: live
```

---

## 9. パフォーマンス最適化

| 施策 | 対象 | 効果 |
|------|------|------|
| 長期キャッシュ（immutable） | JS/CSS | 再訪問時のネットワーク転送ゼロ |
| 画像 WebP 変換 | Storage | 配信コスト30〜80%削減 |
| `cleanUrls: true` | Hosting | CDN キャッシュ効率向上 |
| Cloud Functions SSR + Hosting | Rewrite | SEO・初期表示改善 |
| プレビューチャンネル | 開発フロー | PR確認の高速化 |

> **Storage × Hosting 連携**: Storage の `downloadURL` は Google CDN を通じて
> 配信される（Hosting CDN とは別）。大量の静的アセットは Storage 経由、
> アプリ本体は Hosting CDN 経由に分離するのが最適。
