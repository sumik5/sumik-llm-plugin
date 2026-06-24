# デプロイメントガイド

Next.js SaaSアプリケーションの本番環境へのデプロイ手順とベストプラクティス。

---

## 1. Vercelデプロイ

### 基本フロー

1. **GitHubリポジトリ連携**
   - Vercelダッシュボードで「New Project」を選択
   - GitHubアカウントと連携し、対象リポジトリを選択
   - リポジトリのアクセス権限を許可

2. **自動フレームワーク検出**
   - Vercelが `package.json` を解析し、Next.jsを自動検出
   - ビルドコマンド（`next build`）とデプロイ設定が自動構成される
   - `next.config.js` の設定が自動的に読み込まれる

3. **ビルド・デプロイプロセス**
   ```
   git push → Vercel自動検知 → ビルド → デプロイ → 本番URL生成
   ```
   - mainブランチへのプッシュで本番デプロイ
   - PRごとにプレビュー環境が自動生成
   - ビルドログはリアルタイムで確認可能

4. **カスタムドメイン設定**
   - Vercelダッシュボードの「Domains」セクションでカスタムドメインを追加
   - DNSレコード（A/CNAME）を設定
   - SSL証明書は自動発行・更新

---

## 2. 環境変数管理

### 環境の分離

| 環境 | ファイル | 用途 |
|------|---------|------|
| 開発 | `.env.local` | ローカル開発用（gitignore必須） |
| 本番 | Vercelダッシュボード | 本番環境用（UIから設定） |
| プレビュー | Vercelダッシュボード | PR環境用（オプション） |

### 環境変数の分類

#### サーバーサイド専用（NEXT_PUBLIC_なし）

機密情報を含むため、サーバーサイドでのみ使用する変数:

```bash
# データベース
DATABASE_URL=postgresql://user:password@host:5432/db

# 認証（秘密鍵）
CLERK_SECRET_KEY=sk_test_xxxxx

# AI API
REPLICATE_API_TOKEN=r8_xxxxx
OPENAI_API_KEY=sk-xxxxx

# 決済（秘密鍵）
STRIPE_SECRET_KEY=sk_test_xxxxx
PAYPAL_SECRET=xxxxx
```

⚠️ **これらは絶対にクライアントサイドに公開しない**

#### クライアントサイド共有（NEXT_PUBLIC_必須）

ブラウザ側で参照する必要がある変数:

```bash
# 認証（公開鍵）
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_test_xxxxx

# 決済（公開鍵）
NEXT_PUBLIC_PAYPAL_CLIENT_ID=xxxxx
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_test_xxxxx

# Firebase
NEXT_PUBLIC_FIREBASE_API_KEY=AIzaSyxxxxx
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=project.firebaseapp.com
NEXT_PUBLIC_FIREBASE_PROJECT_ID=project-id
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=project.appspot.com
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=123456789
NEXT_PUBLIC_FIREBASE_APP_ID=1:123456789:web:xxxxx
```

### Vercelでの設定方法

1. Vercelダッシュボード → プロジェクト → Settings → Environment Variables
2. 変数名と値を入力
3. 環境を選択（Production / Preview / Development）
4. 「Save」をクリック

**重要**: 環境変数を追加・変更した後は再デプロイが必要

---

## 3. デプロイ前チェックリスト

### 必須確認項目

- [ ] **環境変数が全て設定されている**
  - Vercelダッシュボードで全変数を確認
  - 開発環境と本番環境で異なる値を使用

- [ ] **開発用APIキーを本番用に切り替え**
  - `test_` → 本番キーに変更
  - `sandbox` → 本番モードに変更

- [ ] **認証プロバイダの本番モード設定**
  - Clerk: Production Instanceを作成し、本番用キーを使用
  - 許可されたリダイレクトURLに本番ドメインを追加

- [ ] **決済ゲートウェイのサンドボックス→本番切り替え**
  - Stripe: テストモード → 本番モード
  - PayPal: Sandboxアカウント → Liveアカウント
  - Webhookエンドポイントに本番URLを設定

- [ ] **Firebase Storageのセキュリティルール確認**
  - 開発用のオープンルールを本番用に切り替え（後述）
  - Firebase Consoleで「Storage Rules」を確認

- [ ] **DBスキーマが最新に同期されている**
  - Prismaの場合: `npx prisma migrate deploy`
  - マイグレーションが本番DBに適用済みか確認

- [ ] **機密情報ファイルがgitignoreに含まれている**
  ```gitignore
  .env
  .env.local
  .env*.local
  ```

- [ ] **ビルドが成功する**
  - ローカルで `npm run build` を実行して確認
  - 警告・エラーがないことを確認

---

## 4. Firebase Storage セキュリティ

### ⚠️ 重要: 開発用ルールを本番に使わない

#### 開発時のルール（オープンアクセス）

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read, write: if true;
    }
  }
}
```

**問題点**: 誰でも読み書き可能。本番環境では絶対に使用しない。

#### 本番用ルール（認証必須）

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      // 読み取りは誰でも可能（公開画像の場合）
      allow read: if true;

      // 書き込みは認証済みユーザーのみ
      allow write: if request.auth != null;
    }
  }
}
```

#### より厳密なルール例

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // ユーザーごとのプライベート領域
    match /users/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // 公開画像
    match /public/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}
```

### セキュリティルールの適用手順

1. Firebase Console → Storage → Rules
2. 本番用ルールを貼り付け
3. 「公開」ボタンをクリック
4. アプリで画像アップロード・表示をテスト

---

## 5. デプロイ後の確認

### 動作確認項目

#### 認証フロー
- [ ] サインアップが正常に動作
- [ ] ログインが正常に動作
- [ ] ログアウトが正常に動作
- [ ] セッションが維持される
- [ ] 保護されたページへのアクセス制御が機能

#### 決済テスト
- [ ] **Sandboxモード**: テストカードで決済フローを確認
- [ ] **本番モード**: 少額の実際の決済をテスト
- [ ] Webhook通知が正常に受信される
- [ ] 決済完了後のリダイレクトが正常
- [ ] サブスクリプション作成・キャンセルが動作

#### AI API
- [ ] API呼び出しが成功する
- [ ] レート制限が適切に設定されている
- [ ] エラーハンドリングが動作する

#### 画像アップロード・表示
- [ ] Firebase Storageへのアップロードが成功
- [ ] アップロードした画像が正常に表示される
- [ ] 認証済みユーザーのみがアップロード可能
- [ ] ファイルサイズ制限が機能している

#### パフォーマンス
- [ ] Lighthouse スコアを確認（特にPerformance）
- [ ] Core Web Vitals（LCP, FID, CLS）を確認
- [ ] 画像が最適化されている（Next.js Image）

---

## 6. CI/CD パターン

### Vercelの自動デプロイ

#### ブランチ戦略

| ブランチ | デプロイ先 | トリガー |
|---------|----------|---------|
| `main` | Production | プッシュ時 |
| `develop` | Preview（オプション） | プッシュ時 |
| PR | Preview | PR作成時 |

#### デプロイフロー

```
開発者がコミット
    ↓
git push origin main
    ↓
Vercel自動検知
    ↓
ビルド開始（環境変数ロード）
    ↓
next build 実行
    ↓
ビルド成功
    ↓
本番環境にデプロイ
    ↓
デプロイ完了通知（Slack/Email）
```

### プレビューデプロイ

- **自動生成**: PRごとに一意のURLが生成される
- **用途**: レビュー・QA・ステークホルダー確認
- **環境変数**: Preview環境用の変数を設定可能
- **URL例**: `https://project-name-pr-123.vercel.app`

### ロールバック手順

#### 方法1: Vercelダッシュボード

1. Deployments → 過去のデプロイを選択
2. 「Promote to Production」をクリック
3. 確認ダイアログで「Promote」

#### 方法2: Git

```bash
# 特定のコミットに戻す
git revert <commit-hash>
git push origin main

# または強制的に過去のコミットに戻す（慎重に）
git reset --hard <commit-hash>
git push --force origin main
```

### デプロイ通知の設定

Vercelダッシュボード → Settings → Notifications

- Slack連携
- Email通知
- Webhookカスタム通知

---

## トラブルシューティング

### ビルドエラー

**症状**: Vercelでビルドが失敗する

**解決策**:
1. ローカルで `npm run build` を実行して再現
2. ビルドログを確認し、エラー箇所を特定
3. 環境変数が正しく設定されているか確認
4. 依存関係の不整合がないか `package-lock.json` を確認

### 環境変数が読み込まれない

**症状**: `process.env.XXX` が undefined

**解決策**:
1. クライアントサイドで使う変数に `NEXT_PUBLIC_` プレフィックスがあるか確認
2. Vercelダッシュボードで環境変数が設定されているか確認
3. 環境変数追加後に再デプロイしたか確認

### 画像アップロードが失敗する

**症状**: Firebase Storageへのアップロードがエラー

**解決策**:
1. Firebase Storageのセキュリティルールを確認
2. Firebase設定（API Key等）が正しいか確認
3. CORSエラーの場合、Firebaseコンソールで許可オリジンを追加

### 決済が動作しない

**症状**: Stripe/PayPal決済が失敗する

**解決策**:
1. 本番キーとテストキーを混在させていないか確認
2. Webhookエンドポイントが正しい本番URLに設定されているか確認
3. 決済プロバイダのダッシュボードでログを確認

---

## セキュリティチェックリスト

デプロイ前に必ず確認:

- [ ] 環境変数に機密情報がハードコードされていない
- [ ] `.env` ファイルが `.gitignore` に含まれている
- [ ] Firebase Storageのルールが本番用に設定されている
- [ ] CORS設定が適切（必要最小限のオリジン許可）
- [ ] 認証が必要なAPIルートに適切なミドルウェアがある
- [ ] SQLインジェクション対策（Prisma等のORM使用）
- [ ] XSS対策（React/Next.jsのデフォルトエスケープに依存）
- [ ] CSRF対策（必要に応じてトークン実装）
- [ ] レート制限が実装されている（特にAI APIエンドポイント）

---

## まとめ

1. **Vercel + GitHub連携**で自動デプロイを実現
2. **環境変数の分離**（開発/本番）を徹底
3. **デプロイ前チェックリスト**を確実に実行
4. **Firebase Storageルール**を本番用に切り替え
5. **デプロイ後確認**で動作を検証
6. **CI/CD**でロールバック可能な体制を構築

これらを遵守することで、安全で信頼性の高いSaaSアプリケーションのデプロイが実現できる。
