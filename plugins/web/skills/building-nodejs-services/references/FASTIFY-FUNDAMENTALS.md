# FASTIFY-FUNDAMENTALS.md

Fastify のコア API を体系的に整理した参照リファレンス。インスタンス化からエラーハンドリングまでを「概念 → 汎用パターン → 最小コード例 → 落とし穴」の順で記述する。

---

## 1. インスタンス化

### 概念

`Fastify()` は設定オブジェクトを受け取り、アプリケーションインスタンスを返す。ファクトリ関数であり `new` は不要。オプションで **ロガー設定**・**HTTP2**・**HTTPS** 等を渡せる。

### 汎用パターン

```js
import Fastify from 'fastify';

const app = Fastify({
  logger: true,          // Pino ロガーを有効化（本番推奨）
  disableRequestLogging: false,
});
```

主要オプション: `logger`（Pino 有効化）・`trustProxy: true`（プロキシ後段の実 IP）・`ajv.customOptions`（スキーマ挙動調整）。

### 落とし穴

- `Fastify()` は ESM の **top-level `await`** と組み合わせると `app.listen` を `await` できる。CommonJS の場合は即時実行関数（IIFE）でラップする。
- `logger: true` と `logger: { level }` は**排他ではない**。両方指定する場合はオブジェクト形式で統一する。

---

## 2. ルーティング

### 概念

Fastify のルート定義は **ショートハンド形式**（`app.get`/`app.post` 等）と **フル形式**（`app.route()`）の 2 通りがある。ルートハンドラーは `async` 関数または `return` による値返却が基本。

### 汎用パターン

```js
// ショートハンド（最多用途）
app.get('/items', async (request, reply) => {
  return { items: [] };
});

// パスパラメーター
app.get('/items/:id', async (request, reply) => {
  const { id } = request.params;
  return { id };
});

// クエリパラメーター
app.get('/search', async (request, reply) => {
  const { q, limit = 10 } = request.query;
  return { q, limit };
});

// フル形式（スキーマを inline で定義する場合）
app.route({
  method: 'POST',
  url: '/items',
  schema: { body: itemBodySchema },
  handler: async (request, reply) => {
    reply.code(201).send({ created: true });
  },
});
```

### prefix によるルートグループ化

プラグイン + `prefix` でリソース単位のネームスペースを形成する:

```js
// routes/booksRouter.js
async function booksRouter(fastify, _opts) {
  fastify.get('/:id', async (request, reply) => {
    const { id } = request.params;
    return { id };
  });

  fastify.post('/', async (request, reply) => {
    reply.code(201).send({ created: true });
  });
}
export default booksRouter;

// index.js
await app.register(booksRouter, { prefix: '/api/books' });
```

### 落とし穴

- ルートハンドラーで **例外を throw** すると Fastify がキャッチして適切なエラーレスポンスに変換する。`try/catch` で握りつぶすと Fastify のエラー処理をバイパスする。
- `app.get` と `app.route` を**同一パスに二重登録**すると起動時にエラーになる。

---

## 3. request / reply オブジェクト

### request の主要プロパティ

- `request.params` — パスパラメーター（`:id` 等）
- `request.query` — クエリ文字列（`?key=val`）
- `request.body` — リクエストボディ（JSON / form-encoded）
- `request.headers` — HTTP ヘッダー
- `request.ip` — クライアント IP（`trustProxy: true` 時は実 IP）
- `request.log` — Pino リクエストスコープロガー

### reply の主要メソッド

```js
// ステータスコードを設定して送信
reply.code(201).send({ id: newId });

// ヘッダーを設定
reply.header('X-Custom', 'value').send(data);

// リダイレクト
reply.redirect('/new-path');

// Content-Type を明示
reply.type('application/json').send(data);
```

### 汎用パターン

```js
app.post('/users', async (request, reply) => {
  const { name, email } = request.body;
  // ... 永続化処理 ...
  reply.code(201).send({ name, email });
});
```

### 落とし穴

- `reply.send()` 後にさらに `send()` を呼ぶと `FST_ERR_REP_ALREADY_SENT` エラーになる。`return` か `reply.send()` どちらかに統一する。
- `return` した値は Fastify が自動で `reply.send()` する。両方使うと二重送信になる。

---

## 4. ライフサイクル / フック

### 概念

Fastify のリクエスト処理は**明確なライフサイクル順序**を持つ。`addHook` で各フェーズにロジックを挿入できる。

```
受信 → onRequest → preParsing → preValidation
     → preHandler → handler → preSerialization
     → onSend → onResponse
                   ↕（エラー時）onError
```

### 主要フックと用途

- `onRequest` — 受信直後（レート制限・IP フィルタリング）
- `preValidation` — スキーマ検証前（認証トークン検証）
- `preHandler` — ハンドラー前（認可チェック）
- `onSend` — 送信直前（ヘッダー追加・レスポンス変換）
- `onResponse` — 完了後（メトリクス収集）
- `onError` — エラー時（カスタムエラー整形）

### 汎用パターン

```js
// グローバルフック（全ルートに適用）
app.addHook('onRequest', async (request, reply) => {
  const token = request.headers['authorization'];
  if (!token) {
    reply.code(401).send({ error: 'Unauthorized' });
  }
});

// ルートレベルフック（特定ルートのみ）
app.get('/admin', {
  onRequest: [verifyAdminToken],
  handler: async (request, reply) => {
    return { secret: 'data' };
  },
});
```

### 落とし穴

- フック内で `reply.send()` を呼ぶとライフサイクルがそこで**短絡**する。残るフックやハンドラーは実行されない。
- `preHandler` フックで `next()` を省略（async フック以外）するとリクエストがハングする。

---

## 5. プラグイン & encapsulation

### 概念

Fastify のプラグインシステムは**スコープ分離（encapsulation）**が中心設計。`fastify.register()` で登録したプラグイン内で追加したルート・デコレーター・フックは、そのプラグインスコープ内にのみ有効。親スコープへの影響を防ぐ。

```
app (root scope)
├── plugin A (独自スコープ)
│   ├── route /a
│   └── decorator: db
└── plugin B (独自スコープ)
    └── route /b
        (decorator: db は見えない)
```

### 汎用パターン

```js
// プラグイン定義
async function authPlugin(fastify, opts) {
  fastify.addHook('preHandler', async (request, reply) => {
    // 認証ロジック
  });

  fastify.get('/profile', async (request, reply) => {
    return { user: request.user };
  });
}

// 登録
await app.register(authPlugin, { prefix: '/auth' });
```

### `fastify-plugin` で encapsulation を解除する

デコレーターや共有サービス（DB 接続等）を**全スコープで共有**したい場合は `fastify-plugin` を使う:

```js
import fp from 'fastify-plugin';

async function dbPlugin(fastify, opts) {
  const db = await connectToDatabase(opts.url);
  fastify.decorate('db', db);
}

export default fp(dbPlugin); // encapsulation 解除 → 親スコープへ伝播
```

### 落とし穴

- `fp()` を使わずに `decorate` した値は親・兄弟スコープから参照できない。「デコレーターが undefined になる」バグの大半はこれが原因。
- `app.register()` は**非同期**。`await` なしで次の `app.register()` に進むと登録順序が保証されない。

---

## 6. Decorators

### 概念

`app.decorate()` / `app.decorateRequest()` / `app.decorateReply()` で Fastify インスタンス・リクエスト・リプライオブジェクトを拡張できる。DB 接続・設定・ユーティリティを DI パターンで注入するのに使う。

### 汎用パターン

```js
// インスタンスデコレーター（DB 接続を共有）
app.decorate('db', mongooseConnection);

// リクエストデコレーター（認証情報を付加）
app.decorateRequest('user', null);

app.addHook('preHandler', async (request) => {
  request.user = await verifyToken(request.headers.authorization);
});

// ハンドラーで利用
app.get('/me', async (request) => {
  return request.user;
});
```

### 落とし穴

- 同名の `decorate` を 2 回呼ぶと `FST_ERR_DEC_ALREADY_PRESENT` エラー。条件付き登録が必要な場合は `app.hasDecorator('name')` で事前チェックする。
- `decorateRequest` の初期値に**オブジェクト・配列**を渡すと全リクエストで同一参照を共有してしまう。初期値は `null` にし、フック内で都度代入する。

---

## 7. スキーマ検証 & シリアライゼーション

### 概念

Fastify は **JSON Schema + AJV** を内蔵する。ルートに `schema` を定義するだけで:

1. **Validation（検証）**: リクエストの body・params・query・headers を受信時に自動検証
2. **Serialization（シリアライゼーション）**: レスポンスを定義に従って高速シリアライズ（不要フィールドを除去）

検証失敗は自動的に **400 Bad Request** を返す。

### 汎用パターン

```js
const itemSchema = {
  type: 'object',
  required: ['name', 'price'],
  properties: {
    name:  { type: 'string', minLength: 1 },
    price: { type: 'number', minimum: 0 },
  },
  additionalProperties: false,
};

const responseSchema = {
  201: {
    type: 'object',
    properties: {
      id:    { type: 'integer' },
      name:  { type: 'string' },
      price: { type: 'number' },
    },
  },
};

app.post('/items', {
  schema: {
    body: itemSchema,
    response: responseSchema,
  },
  handler: async (request, reply) => {
    const { name, price } = request.body;
    const created = await db.create({ name, price });
    reply.code(201).send(created);
  },
});
```

### 共有スキーマ

繰り返し使うスキーマは `addSchema` で登録し `$ref` で参照:

```js
app.addSchema({
  $id: 'Item',
  type: 'object',
  properties: {
    id:   { type: 'integer' },
    name: { type: 'string' },
  },
});

app.get('/items/:id', {
  schema: {
    params: { id: { type: 'integer' } },
    response: { 200: { $ref: 'Item#' } },
  },
  handler: async (request) => {
    return await db.findById(request.params.id);
  },
});
```

### 落とし穴

- `additionalProperties: false` を設定しないと余分なフィールドが**スルー**される（セキュリティリスク）。
- `response` スキーマは**シリアライゼーション専用**であり、スキーマに含まれないフィールドはレスポンスから**自動除去**される。パスワードハッシュ等の機密フィールドをスキーマから外すだけでレスポンスから排除できる。
- AJV のデフォルト設定では `integer` 型に `float` が来るとバリデーション失敗する。`coerceTypes: true` で型強制できるが副作用に注意。

---

## 8. Pino ロギング

### 概念

Fastify は **Pino** をデフォルトロガーとして内蔵する。JSON 形式の構造化ログを非同期で出力し、文字列連結ベースのロガーより大幅に高速。

### 設定パターン

```js
const app = Fastify({
  logger: {
    level: process.env.LOG_LEVEL || 'info',
    transport: process.env.NODE_ENV === 'development'
      ? { target: 'pino-pretty' }   // 開発時: 読みやすい整形
      : undefined,                   // 本番: 生 JSON（ログ集約ツール向け）
  },
});
```

### 使用パターン

```js
// アプリレベルロガー
app.log.info('Server starting');

// リクエストスコープロガー（リクエスト ID が自動付与される）
app.get('/items', async (request) => {
  request.log.info({ action: 'list_items' }, 'Fetching all items');
  const items = await db.findAll();
  request.log.debug({ count: items.length }, 'Items fetched');
  return items;
});
```

ログレベル: `trace` → `debug` → `info`（デフォルト）→ `warn` → `error` → `fatal`。本番は `warn` 以上に絞ることが多い。

### 落とし穴

- `console.log` を本番で使うとバッファリングなしの同期出力になりスループットを下げる。Pino（`request.log`）に統一する。
- `pino-pretty` は本番環境で使わない。JSON 整形の CPU コストがロギングのメリットを打ち消す。
- シリアライズコストを下げるため、ログにオブジェクトを渡す場合は `{ key: value }` を第一引数、メッセージを第二引数にする（Pino の推奨フォーム）。

---

## 9. app.listen

### 概念

`app.listen()` でサーバーを指定ポート・ホストにバインドし、リクエスト受付を開始する。`await` で完了を待つ（top-level await か async IIFE）。

### 汎用パターン

```js
// パターン A: top-level await（ESM・推奨）
const PORT = parseInt(process.env.PORT || '3000', 10);
const HOST = process.env.HOST || '0.0.0.0'; // Docker/本番向け

try {
  await app.listen({ port: PORT, host: HOST });
  app.log.info(`Server listening at http://${HOST}:${PORT}`);
} catch (err) {
  app.log.fatal(err, 'Server failed to start');
  process.exit(1);
}
```

主要オプション: `port`（バインドポート）・`host`（`'127.0.0.1'`=ローカルのみ / `'0.0.0.0'`=全 NIC）・`backlog`（TCP キュー長）。

### 落とし穴

- Docker / Kubernetes では `host: '127.0.0.1'`（デフォルト）だとコンテナ外からアクセスできない。`'0.0.0.0'` を指定する。
- 起動エラーで `process.exit(1)` を呼ばないと、壊れた状態でプロセスが残り続ける。

---

## 10. エラーハンドリング

### 概念

Fastify のエラーハンドリングには 3 つの層がある:

1. **スキーマ検証エラー**: AJV が自動で 400 を返す
2. **ハンドラー内例外**: `throw` または `reject` したエラーを Fastify がキャッチし、デフォルトのエラーフォーマットで返す
3. **カスタムエラーハンドラー**: `app.setErrorHandler` でアプリ全体の書式を統一

### カスタムエラーハンドラー

```js
app.setErrorHandler(async (error, request, reply) => {
  request.log.error({ err: error }, 'Unhandled error');

  const statusCode = error.statusCode || 500;
  reply.code(statusCode).send({
    error: error.name || 'InternalServerError',
    message: statusCode < 500 ? error.message : 'Internal Server Error',
    statusCode,
  });
});
```

### Not Found ハンドラー

```js
app.setNotFoundHandler((request, reply) => {
  reply.code(404).send({
    error: 'NotFound',
    message: `Route ${request.method}:${request.url} not found`,
    statusCode: 404,
  });
});
```

### カスタムエラークラス

```js
class AppError extends Error {
  constructor(message, statusCode = 500) {
    super(message);
    this.name = 'AppError';
    this.statusCode = statusCode;
  }
}

// ハンドラー内で使用
app.get('/items/:id', async (request, reply) => {
  const item = await db.findById(request.params.id);
  if (!item) throw new AppError('Item not found', 404);
  return item;
});
```

### 落とし穴

- `setErrorHandler` は**最後に登録**した関数が優先される。プラグイン内部にスコープ限定のエラーハンドラーを持たせることもできる（encapsulation に準拠）。
- `async` ハンドラー内で `reply.send()` を呼んで**かつ** `throw` すると、二重エラーになる可能性がある。`return` か `throw` かどちらかに統一する。
- バリデーションエラーの `message` には詳細なスキーマパス情報が含まれる場合がある。本番では外部に漏らさず汎用メッセージに置き換えること。

