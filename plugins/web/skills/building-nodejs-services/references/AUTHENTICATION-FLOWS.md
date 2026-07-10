# 認証フロー

Node サービスにおける認証方式の実装パターン。ログインフォーム・パスワードハッシュ・セッション/Cookie・JWT・暗号ハッシュによるデータ整合性検証を扱う。

---

## 1. 概念 — 基本の流れ

```
登録: パスワードをハッシュ化して保存
ログイン: 入力パスワードを再ハッシュ → 保存済みハッシュと比較
認証成功: セッション (SSR) または JWT (API) を発行
以降: Cookie または Authorization ヘッダーで身元を証明
```

平文パスワードを DB に保存してはいけない。DB 漏洩で全アカウントが危険にさらされる（OWASP ASVS で禁止）。**保存するのは「ハッシュ + ソルト」のみ**。

---

## 2. パスワードハッシュ — bcrypt

### 概念

bcrypt は「コスト係数（ラウンド数）」で計算負荷を調整できる適応型ハッシュ関数。ブルートフォース攻撃への耐性が高い。

- `hashSync(password, saltRounds)` — 同期版（CLI・起動時処理向け）
- `hash(password, saltRounds)` — 非同期版（サーバーのルートハンドラ向け、推奨）

### 登録フロー

```js
import bcrypt from 'bcrypt';

const SALT_ROUNDS = 12;  // 2^12 回のイテレーション（本番では 12〜14 が標準）

async function registerUser(username, plainPassword) {
  const hash = await bcrypt.hash(plainPassword, SALT_ROUNDS);
  await User.create({ username, hash });
}
```

### ログイン認証フロー

```js
async function loginUser(username, plainPassword) {
  const user = await User.findOne({ where: { username } });
  if (!user) return null;  // ユーザーが存在しない

  const isValid = await bcrypt.compare(plainPassword, user.hash);
  return isValid ? user : null;
}
```

bcrypt の `compare` は、元のハッシュに埋め込まれたソルトを自動抽出して再ハッシュし比較する。ソルトを別途保存する必要はない。

### 落とし穴

- `hashSync` はイベントループをブロックする → リクエストハンドラでは `await bcrypt.hash(...)` を使う
- ソルトラウンド数は最低 10、本番は 12 以上
- ハッシュと平文を `===` で比較しない → 必ず `bcrypt.compare`
- 72 バイト超の入力は切り捨てられる → 入力長に上限バリデーションを設ける

---

## 3. パスワードハッシュ — `node:crypto` (PBKDF2 + salt)

### 概念

`node:crypto` は Node 標準モジュール。外部パッケージなしに PBKDF2・SHA-256/512・HMAC・乱数生成が使える。ソルトを自前で生成・保存する設計が必要。

### 登録フロー（ソルト + ハッシュの分離保存）

```js
import crypto from 'node:crypto';

function hashPassword(plainPassword) {
  const salt = crypto.randomBytes(32).toString('hex');   // 64 文字の乱数 hex
  const hashRaw = crypto.pbkdf2Sync(
    plainPassword,
    salt,
    12000,   // イテレーション数
    64,      // 出力バイト長
    'sha512'
  );
  const hash = Buffer.from(hashRaw).toString('hex');
  return { hash, salt };  // 両方を DB に保存
}

async function registerAccount(username, password) {
  const { hash, salt } = hashPassword(password);
  await Account.create({ username, hash, salt });
}
```

### 認証フロー（保存済みソルトで再ハッシュして比較）

```js
function verifyPassword(plainPassword, storedHash, storedSalt) {
  const hashRaw = crypto.pbkdf2Sync(
    plainPassword,
    storedSalt,
    12000,
    64,
    'sha512'
  );
  const hash = Buffer.from(hashRaw).toString('hex');
  return hash === storedHash;
}

async function authenticate(username, password) {
  const account = await Account.findOne({ where: { username } });
  if (!account) return null;
  return verifyPassword(password, account.hash, account.salt) ? account : null;
}
```

### bcrypt vs `node:crypto` (PBKDF2) の使い分け

- **bcrypt**: ソルト自動管理・72 バイト上限あり・多くの Web アプリの第一選択
- **PBKDF2**: Node 標準で外部依存ゼロ・ソルトを手動管理・長いパスワードも制限なし
- **Argon2**: より強力な選択肢。新規プロジェクトでの評価を推奨

---

## 4. `node:crypto` によるデータ整合性検証（ハッシュ）

パスワード用途とは別に、ファイル・ペイロード・ブロックデータの改ざん検知にも暗号ハッシュが使われる。

### SHA-256 ハッシュによるデータ指紋

```js
import { createHash } from 'node:crypto';

function sha256(data) {
  return createHash('sha256')
    .update(typeof data === 'string' ? data : JSON.stringify(data))
    .digest('hex');
}

// 例: 複合データの整合性指紋（連鎖ログ・監査証跡）
const entryHash = sha256(
  parentHash + timestamp + JSON.stringify(payload)
);
```

### HMAC による送信者認証付き検証

```js
import { createHmac } from 'node:crypto';

const SECRET = process.env.HMAC_SECRET;

function sign(payload) {
  return createHmac('sha256', SECRET)
    .update(JSON.stringify(payload))
    .digest('hex');
}

function verify(payload, signature) {
  const expected = sign(payload);
  return crypto.timingSafeEqual(
    Buffer.from(expected, 'hex'),
    Buffer.from(signature, 'hex')
  );
}
```

> `===` での比較はタイミング攻撃を受けやすい。秘密情報の比較には常に `crypto.timingSafeEqual` を使う。

### 利用場面

Webhook 署名検証・コンテンツ指紋・ファイル整合性チェック・前後データのハッシュ連鎖（チェーン型ログ）など。

---

## 5. ログインフォームと Fastify ルート

Handlebars テンプレート（`views/login.hbs`）にはフォームの `action` を `{{route}}` で動的に切り替える。登録フォームは `/account`、ログインフォームは `/auth` へ POST する。テンプレートの詳細は `SERVER-SIDE-RENDERING.md` を参照。

```js
import Fastify from 'fastify';
import fastifyFormbody from '@fastify/formbody';

const app = Fastify();
await app.register(fastifyFormbody);  // URL エンコードフォームを解析

// アカウント登録
app.post('/account', async (request, reply) => {
  const { username, password } = request.body;
  try {
    const hash = await bcrypt.hash(password, 12);
    await User.create({ username, hash });
    return reply.send({ message: 'Account created.' });
  } catch (e) {
    return reply.code(400).send({ message: e.message });
  }
});

// ログイン
app.post('/auth', async (request, reply) => {
  const { username, password } = request.body;
  const user = await User.findOne({ where: { username } });
  if (!user || !(await bcrypt.compare(password, user.hash))) {
    return reply.redirect('/?page=login');
  }
  return reply.send({ message: 'Logged in.', username });
});
```

---

## 6. セッション / Cookie 認証

SSR アプリ（ブラウザクライアント）向け。サーバー側にセッションを保持し、ブラウザには Cookie でセッション ID を渡す。

```js
import fastifySession from '@fastify/session';
import fastifyCookie  from '@fastify/cookie';

await app.register(fastifyCookie);
await app.register(fastifySession, {
  secret: process.env.SESSION_SECRET,  // 32 文字以上・必ず環境変数から
  cookie: { secure: process.env.NODE_ENV === 'production',
            httpOnly: true, sameSite: 'lax' },
  saveUninitialized: false,
});

// ログイン後にセッション保存
app.post('/auth', async (request, reply) => {
  const user = await loginUser(request.body.username, request.body.password);
  if (!user) return reply.code(401).send({ message: 'Unauthorized' });
  request.session.userId = user.id;
  return reply.send({ message: 'Logged in.' });
});

// 保護ルート
app.get('/dashboard', async (request, reply) => {
  if (!request.session.userId) return reply.redirect('/?page=login');
  const user = await User.findByPk(request.session.userId);
  return reply.view('dashboard', { username: user.username });
});

// ログアウト
app.get('/logout', async (request, reply) => {
  await request.session.destroy();
  return reply.redirect('/');
});
```

**セッション永続化**: デフォルトはインメモリ（再起動でクリア）。本番では Redis ストアを使う。`@fastify/session` は `store` オプションで Redis バックエンドを指定できる。

---

## 7. JWT 認証（ステートレス API 向け）

モバイルアプリ・SPA・マイクロサービス等、Cookie を使えないクライアントに適する。サーバー側はセッション状態を持たない。

### JWT の構造

```
eyJhbGciOiJIUzI1NiJ9  ← ヘッダー (Base64)
.
eyJ1c2VybmFtZSI6ImFsaWNlIn0  ← ペイロード (Base64)
.
SflKxwRJSMeKKF2QT4fwpMeJf...  ← 署名 (HMAC-SHA256)
```

ペイロードは Base64 なので**暗号化されていない**。秘密情報（パスワード等）は含めない。

### トークン発行（ログイン時）

```js
import jwt from 'jsonwebtoken';

const JWT_SECRET = process.env.JWT_SECRET;  // 必ず環境変数から取得

function signJWT(payload) {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: '7d' });
}

app.post('/api/auth', async (request, reply) => {
  const user = await loginUser(request.body.username, request.body.password);
  if (!user) return reply.code(401).send({ message: 'Unauthorized' });

  const token = signJWT({ username: user.username, userId: user.id });
  return reply.send({ token });
});
```

### トークン検証（保護ルート）

```js
function verifyJWT(token) {
  return jwt.verify(token, JWT_SECRET);  // 検証失敗時は例外を投げる
}

// Fastify preValidation フック
async function jwtAuth(request, reply) {
  const authHeader = request.headers.authorization;
  if (!authHeader?.startsWith('Bearer ')) {
    return reply.code(401).send({ message: 'No token provided' });
  }
  try {
    const payload = verifyJWT(authHeader.slice(7));
    request.user = payload;
  } catch {
    return reply.code(401).send({ message: 'Invalid token' });
  }
}

app.get('/api/profile',
  { preValidation: jwtAuth },
  async (request, reply) => {
    return reply.send({ username: request.user.username });
  }
);
```

### Passport.js + JWT 統合（`@fastify/passport`）

より本格的な構成では `passport-jwt` の `JWTStrategy` + `@fastify/passport` を使う。`ExtractJwt.fromAuthHeaderAsBearerToken()` で Bearer トークンを自動抽出し、`secretOrKey` で検証する。`done(null, account)` で認証成功、`done(null, false)` で失敗を表現する。詳細は `@fastify/passport` のドキュメントを参照。

### 落とし穴

| 状況 | 問題 | 対処 |
|------|------|------|
| JWT_SECRET をハードコード | リポジトリ漏洩で全トークン偽造可能 | 必ず `process.env.JWT_SECRET` を使う |
| `expiresIn` を設定しない | トークンが永遠に有効になる | 用途に応じて 15m〜7d 程度を設定 |
| ペイロードに平文パスワードを含める | Base64 解読で露出 | ペイロードには識別子（username・userId）のみ |
| JWT 失効（ログアウト）を実現したい | ステートレス JWT は取り消せない | 短い有効期限 + リフレッシュトークン、またはブラックリスト（Redis） |
| `jwt.verify` のエラーを握り潰す | 不正トークンを通過させる | 必ず `try/catch` で捕捉して 401 を返す |

---

## 8. セッション vs JWT の選択

```
アプリケーションの特性を確認する
│
├── ブラウザ (SSR・Fastify/Handlebars)
│   → セッション + Cookie
│   　 利点: ログアウトが即時有効・サーバーで状態制御
│
└── API・モバイル・SPA・マイクロサービス
    → JWT（ステートレストークン）
       利点: サーバーレス対応・スケールアウト容易・クロスドメイン
```

### AskUserQuestion — 認証方式の選択

```
【認証方式を確認します】

1. セッション / Cookie
   → ブラウザ向け SSR アプリ・Handlebars/EJS テンプレートを使用する
   → ログアウト即時有効・サーバー側で状態管理したい

2. JWT（JSON Web Token）
   → モバイルアプリ・SPA・外部 API クライアント向け
   → ステートレス・複数サーバー/クラウド環境で動かす

→ アプリのクライアント種別（ブラウザ / モバイル / API）を教えてください。
```

> **Codex / ツール呼び出し非対応環境**: 上記テキスト質問を会話メッセージとして送信し、
> 回答をもとに §6（セッション）または §7（JWT）のパターンを適用してください。

---

## 9. アカウント保護のポイント

- パスワード長・複雑性はサーバー側バリデーション（クライアント側のみでは不十分）
- ユーザー名は保存前に `toLowerCase()` で統一
- ログイン失敗繰り返しには `@fastify/rate-limit` でレートリミット
- `password`・`hash`・`token` を `console.log` しない
- Cookie は `secure: true`・`httpOnly: true`・`sameSite: 'lax'` を設定
- JWT は署名アルゴリズムを `HS256` または `RS256` に明示指定（`none` を受け付けない）

> OWASP チェックリスト全般・CI/CD 統合は `developing-fullstack-javascript` を参照。
