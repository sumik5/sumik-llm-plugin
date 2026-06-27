# OWASP Top 10 対策ガイド

[← セキュアコーディング に戻る](../SKILL.md)

## 📖 目次

- [概要](#概要)
- [A01: アクセス制御の不備](#a01-アクセス制御の不備)
- [A02: 暗号化の失敗](#a02-暗号化の失敗)
- [A03: インジェクション](#a03-インジェクション)
- [A04: 安全が確認されない不安全な設計](#a04-安全が確認されない不安全な設計)
- [A05: セキュリティの設定ミス](#a05-セキュリティの設定ミス)
- [A06: 脆弱で古くなったコンポーネント](#a06-脆弱で古くなったコンポーネント)
- [A07: 識別と認証の失敗](#a07-識別と認証の失敗)
- [A08: ソフトウェアとデータの整合性の不備](#a08-ソフトウェアとデータの整合性の不備)
- [A09: セキュリティログとモニタリングの失敗](#a09-セキュリティログとモニタリングの失敗)
- [A10: サーバーサイドリクエストフォージェリ](#a10-サーバーサイドリクエストフォージェリ)
- [実装完了前チェックリスト](#実装完了前チェックリスト)

## 概要

OWASP（Open Web Application Security Project）Top 10は、Webアプリケーションにおける最も重大なセキュリティリスクのリストです。すべてのWebアプリケーション開発において、これらのリスクへの対策は必須です。

**重要**: 実装完了後は必ずCodeGuardでセキュリティチェックを実施してください。

## A01: アクセス制御の不備

### 概要
ユーザーが権限外のリソースにアクセスできてしまう脆弱性。

### 対策

#### ✅ 認可チェックの実装
```typescript
// 認可チェック
function deleteUser(userId: string, currentUser: User) {
  // 管理者権限チェック
  if (currentUser.role !== 'admin') {
    throw new UnauthorizedError('管理者権限が必要です')
  }

  // 自分自身のアカウント削除を防ぐ
  if (userId === currentUser.id) {
    throw new ForbiddenError('自分のアカウントは削除できません')
  }

  return userRepository.delete(userId)
}

// リソース所有者チェック
function updatePost(postId: string, currentUser: User, data: PostUpdateData) {
  const post = await postRepository.findById(postId)

  // 所有者チェック
  if (post.authorId !== currentUser.id && currentUser.role !== 'admin') {
    throw new ForbiddenError('このリソースを編集する権限がありません')
  }

  return postRepository.update(postId, data)
}
```

#### ✅ ロールベースアクセス制御（RBAC）
```typescript
// 権限定義
enum Permission {
  READ_POSTS = 'read:posts',
  CREATE_POSTS = 'create:posts',
  UPDATE_OWN_POSTS = 'update:own:posts',
  UPDATE_ANY_POSTS = 'update:any:posts',
  DELETE_POSTS = 'delete:posts'
}

// ロール定義
const ROLES = {
  user: [
    Permission.READ_POSTS,
    Permission.CREATE_POSTS,
    Permission.UPDATE_OWN_POSTS
  ],
  moderator: [
    Permission.READ_POSTS,
    Permission.CREATE_POSTS,
    Permission.UPDATE_ANY_POSTS
  ],
  admin: Object.values(Permission)
}

// 権限チェックミドルウェア
function requirePermission(permission: Permission) {
  return (req: Request, res: Response, next: NextFunction) => {
    const userPermissions = ROLES[req.user.role]

    if (!userPermissions.includes(permission)) {
      throw new ForbiddenError('権限がありません')
    }

    next()
  }
}

// 使用例
app.delete('/api/posts/:id',
  authenticate,
  requirePermission(Permission.DELETE_POSTS),
  deletePostHandler
)
```

### ❌ やってはいけないこと
```typescript
// クライアントから送られた権限情報を信頼
function deleteUser(userId: string, isAdmin: boolean) {  // 危険
  if (isAdmin) {
    return userRepository.delete(userId)
  }
}

// URLパラメータのみでアクセス制御
app.get('/api/users/:userId', (req, res) => {  // 危険
  // 認証・認可チェックなし
  const user = await userRepository.findById(req.params.userId)
  res.json(user)
})
```

## A02: 暗号化の失敗

### 概要
機密データの暗号化が不十分、または暗号化されていない状態での保存・送信。

### 対策

#### ✅ パスワードのハッシュ化
```typescript
import bcrypt from 'bcrypt'

// パスワードハッシュ化
async function hashPassword(plainPassword: string): Promise<string> {
  const saltRounds = 10
  return bcrypt.hash(plainPassword, saltRounds)
}

// パスワード検証
async function verifyPassword(
  plainPassword: string,
  hashedPassword: string
): Promise<boolean> {
  return bcrypt.compare(plainPassword, hashedPassword)
}

// ユーザー作成
async function createUser(data: UserCreateData) {
  const hashedPassword = await hashPassword(data.password)

  return userRepository.create({
    ...data,
    password: hashedPassword  // ハッシュ化されたパスワードを保存
  })
}
```

#### ✅ データ暗号化
```typescript
import crypto from 'crypto'

// 暗号化キー（環境変数から取得）
const ENCRYPTION_KEY = process.env.ENCRYPTION_KEY!  // 32バイトの鍵
const IV_LENGTH = 16  // AES-256-CBCの初期化ベクトル長

// データ暗号化
function encrypt(text: string): string {
  const iv = crypto.randomBytes(IV_LENGTH)
  const cipher = crypto.createCipheriv(
    'aes-256-cbc',
    Buffer.from(ENCRYPTION_KEY),
    iv
  )

  let encrypted = cipher.update(text, 'utf8', 'hex')
  encrypted += cipher.final('hex')

  return iv.toString('hex') + ':' + encrypted
}

// データ復号化
function decrypt(text: string): string {
  const parts = text.split(':')
  const iv = Buffer.from(parts[0], 'hex')
  const encryptedText = parts[1]

  const decipher = crypto.createDecipheriv(
    'aes-256-cbc',
    Buffer.from(ENCRYPTION_KEY),
    iv
  )

  let decrypted = decipher.update(encryptedText, 'hex', 'utf8')
  decrypted += decipher.final('utf8')

  return decrypted
}

// 使用例
const encryptedData = encrypt(sensitiveData)
await database.save({ data: encryptedData })
```

#### ✅ HTTPS通信の強制
```typescript
// HTTPSリダイレクト
app.use((req, res, next) => {
  if (req.header('x-forwarded-proto') !== 'https' && process.env.NODE_ENV === 'production') {
    res.redirect(`https://${req.header('host')}${req.url}`)
  } else {
    next()
  }
})

// Strict-Transport-Securityヘッダー
app.use(helmet.hsts({
  maxAge: 31536000,  // 1年
  includeSubDomains: true,
  preload: true
}))
```

### ❌ やってはいけないこと
```typescript
// 平文パスワードの保存
const user = {
  username: 'alice',
  password: 'password123'  // 絶対禁止
}

// 弱いハッシュアルゴリズム
const hash = crypto.createHash('md5').update(password).digest('hex')  // 危険
```

## A03: インジェクション

### 概要
信頼できない入力がコマンドやクエリの一部として解釈される脆弱性。

### 対策
詳細は [入力検証とインジェクション対策](INPUT-VALIDATION.md) を参照してください。

#### クイックリファレンス
```typescript
// ✅ SQLインジェクション対策: プリペアドステートメント
const user = await db.query('SELECT * FROM users WHERE id = $1', [userId])

// ✅ コマンドインジェクション対策: 入力検証
const allowedCommands = ['ls', 'pwd', 'whoami']
if (!allowedCommands.includes(command)) {
  throw new Error('不正なコマンド')
}
```

## A04: 安全が確認されない不安全な設計

### 概要
設計段階でのセキュリティ考慮不足による脆弱性。

### 対策

#### ✅ Threat Modeling（脅威モデリング）
```typescript
// データフロー図とTrust Boundary（信頼境界）の定義

// 例: ユーザー登録プロセス
/**
 * 脅威モデル: ユーザー登録
 *
 * Trust Boundaries:
 * 1. クライアント → サーバー（検証必須）
 * 2. サーバー → データベース（信頼できる）
 *
 * Threats (STRIDE):
 * - Spoofing: メール検証で対策
 * - Tampering: HTTPS通信で対策
 * - Repudiation: 監査ログで対策
 * - Information Disclosure: 暗号化で対策
 * - Denial of Service: レート制限で対策
 * - Elevation of Privilege: デフォルト権限を最小に
 */
async function registerUser(data: UserRegistrationData) {
  // 入力検証（Trust Boundaryでの検証）
  const validated = UserRegistrationSchema.parse(data)

  // メール検証トークン生成
  const verificationToken = generateSecureToken()

  // デフォルト権限を最小に（Elevation of Privilege対策）
  const user = await userRepository.create({
    ...validated,
    role: 'user',  // デフォルトは最小権限
    emailVerified: false,
    verificationToken
  })

  // 監査ログ（Repudiation対策）
  auditLog.info('User registered', {
    userId: user.id,
    email: user.email
  })

  return user
}
```

#### ✅ Principle of Least Privilege（最小権限の原則）
```typescript
// データベースユーザーの権限分離
const dbConfig = {
  read: {
    user: process.env.DB_READ_USER,
    password: process.env.DB_READ_PASSWORD,
    privileges: ['SELECT']  // 読み取り専用
  },
  write: {
    user: process.env.DB_WRITE_USER,
    password: process.env.DB_WRITE_PASSWORD,
    privileges: ['SELECT', 'INSERT', 'UPDATE']  // 書き込み権限
  },
  admin: {
    user: process.env.DB_ADMIN_USER,
    password: process.env.DB_ADMIN_PASSWORD,
    privileges: ['ALL']  // 管理者権限（移行時のみ使用）
  }
}

// 読み取り専用操作
const readOnlyDb = createConnection(dbConfig.read)
const users = await readOnlyDb.query('SELECT * FROM users')

// 書き込み操作
const writeDb = createConnection(dbConfig.write)
await writeDb.query('INSERT INTO users ...', params)
```

## A05: セキュリティの設定ミス

### 概要
不適切な設定、デフォルト値の使用、詳細すぎるエラーメッセージなど。

### 対策
詳細は [セキュアヘッダーとその他の対策](SECURE-HEADERS.md) を参照してください。

#### クイックリファレンス
```typescript
// ✅ セキュアな設定
app.use(helmet({
  contentSecurityPolicy: true,
  hsts: { maxAge: 31536000 }
}))

// エラーメッセージは一般的に
app.use((err, req, res, next) => {
  console.error(err)  // サーバーログに詳細
  res.status(500).json({
    error: '内部サーバーエラー'  // クライアントには一般的なメッセージ
  })
})
```

## A06: 脆弱で古くなったコンポーネント

### 概要
既知の脆弱性を持つライブラリやフレームワークの使用。

### 対策

#### ✅ 依存関係の管理
```bash
# 定期的な脆弱性スキャン
npm audit

# 脆弱性の自動修正
npm audit fix

# Snykによるスキャン
npx snyk test

# Dependabotの有効化（GitHub）
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
```

#### ✅ package.jsonの管理
```json
{
  "dependencies": {
    "express": "^4.18.2",  // メジャーバージョン固定、マイナー・パッチは自動更新
    "react": "~18.2.0"     // マイナーバージョン固定、パッチのみ自動更新
  },
  "scripts": {
    "audit": "npm audit",
    "update-deps": "npm update && npm audit"
  }
}
```

## A07: 識別と認証の失敗

### 概要
認証メカニズムの脆弱性、セッション管理の不備など。

### 対策
詳細は [認証・認可と機密情報管理](AUTH-SECRETS.md) を参照してください。

#### クイックリファレンス
```typescript
// ✅ セキュアな認証
import bcrypt from 'bcrypt'
import jwt from 'jsonwebtoken'

// パスワード複雑度チェック
const passwordSchema = z.string()
  .min(8)
  .regex(/[A-Z]/, '大文字を含む必要があります')
  .regex(/[a-z]/, '小文字を含む必要があります')
  .regex(/[0-9]/, '数字を含む必要があります')
  .regex(/[^A-Za-z0-9]/, '記号を含む必要があります')

// JWTトークン生成
const token = jwt.sign(
  { userId: user.id },
  process.env.JWT_SECRET!,
  { expiresIn: '1h' }
)
```

## A08: ソフトウェアとデータの整合性の不備

### 概要
コードやインフラストラクチャの整合性検証が不十分。

### 対策

#### ✅ SubResource Integrity（SRI）
```html
<!-- CDNからのスクリプト読み込みに整合性チェック -->
<script
  src="https://cdn.example.com/library.js"
  integrity="sha384-oqVuAfXRKap7fdgcCY5uykM6+R9GqQ8K/ux..."
  crossorigin="anonymous"
></script>
```

#### ✅ コード署名検証
```typescript
// npm パッケージの署名検証
// package-lock.json の integrity フィールド確認

// Docker イメージの署名検証
// docker trust sign/verify コマンド使用
```

#### ✅ CI/CDパイプラインのセキュリティ
```yaml
# GitHub Actions例
name: Security Scan
on: [push, pull_request]
jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Snyk
        uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
      - name: Run npm audit
        run: npm audit --audit-level=high
```

## A09: セキュリティログとモニタリングの失敗

### 概要
セキュリティイベントのログ記録やモニタリングの不足。

### 対策
詳細は [セキュアヘッダーとその他の対策](SECURE-HEADERS.md) を参照してください。

#### クイックリファレンス
```typescript
// ✅ セキュアなログ管理
import winston from 'winston'

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  transports: [
    new winston.transports.File({ filename: 'error.log', level: 'error' }),
    new winston.transports.File({ filename: 'security.log', level: 'warn' })
  ]
})

// セキュリティイベントのログ記録
logger.warn('Failed login attempt', {
  userId: userId,
  ip: req.ip,
  timestamp: new Date().toISOString()
  // password: password  // 絶対に機密情報を記録しない
})
```

## A10: サーバーサイドリクエストフォージェリ

### 概要
サーバーが外部リソースにアクセスする際の検証不足。

### 対策

#### ✅ URL検証
```typescript
// URLホワイトリスト
const ALLOWED_DOMAINS = [
  'api.example.com',
  'trusted-service.com'
]

async function fetchExternalResource(url: string) {
  const parsedUrl = new URL(url)

  // ホワイトリストチェック
  if (!ALLOWED_DOMAINS.includes(parsedUrl.hostname)) {
    throw new Error('許可されていないドメインです')
  }

  // プライベートIPアドレスへのアクセス防止
  const ipv4Regex = /^(?:10|127|172\.(?:1[6-9]|2[0-9]|3[01])|192\.168)\./
  if (ipv4Regex.test(parsedUrl.hostname)) {
    throw new Error('プライベートIPアドレスへのアクセスは禁止されています')
  }

  // localhostへのアクセス防止
  if (parsedUrl.hostname === 'localhost' || parsedUrl.hostname === '127.0.0.1') {
    throw new Error('localhostへのアクセスは禁止されています')
  }

  return fetch(url)
}
```

#### ✅ リダイレクト制限
```typescript
// リダイレクトの検証
async function fetchWithRedirectValidation(url: string) {
  const response = await fetch(url, {
    redirect: 'manual'  // 自動リダイレクトを無効化
  })

  if (response.status >= 300 && response.status < 400) {
    const redirectUrl = response.headers.get('location')

    if (redirectUrl) {
      // リダイレクト先も検証
      await validateUrl(redirectUrl)
      return fetchWithRedirectValidation(redirectUrl)
    }
  }

  return response
}
```

## 実装完了前チェックリスト

すべてのコード実装完了時に確認：

### 必須チェック
- [ ] **software-security スキルに基づくセキュリティ確認実施済み**
- [ ] A01: 認可チェックの実装
- [ ] A02: 機密データの暗号化
- [ ] A03: インジェクション対策（入力検証、プリペアドステートメント）
- [ ] A04: 脅威モデリングと最小権限の原則
- [ ] A05: セキュアな設定（セキュリティヘッダー、エラーハンドリング）
- [ ] A06: 依存関係の脆弱性スキャン
- [ ] A07: セキュアな認証・認可
- [ ] A08: コード整合性検証
- [ ] A09: セキュリティログの記録
- [ ] A10: SSRF対策（URL検証）

### 推奨チェック
- [ ] 多要素認証（MFA）の実装
- [ ] レート制限の実装
- [ ] セキュリティテストの自動化
- [ ] インシデント対応計画の策定
- [ ] 定期的なペネトレーションテスト

## 📚 参考資料

- [OWASP Top 10 2021](https://owasp.org/www-project-top-ten/)
- [OWASP Cheat Sheet Series](https://cheatsheetseries.owasp.org/)
- [CWE Top 25](https://cwe.mitre.org/top25/)

---

[← セキュアコーディング に戻る](../SKILL.md)
