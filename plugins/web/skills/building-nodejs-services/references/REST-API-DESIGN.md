# REST API 設計レシピ

RESTful API の設計と Fastify による実装パターン。
HTTP メソッドのセマンティクスから CRUD ルートのレイアウトまでを扱う。

> API スタイルの選択（REST vs GraphQL vs gRPC）や比較論は `choosing-api-styles` を参照。
> HTTP プロトコル詳細・バージョニング戦略は `developing-web-apis` を参照。

---

## 1. HTTP メソッドのセマンティクス

| メソッド | 用途 | 冪等性 | ボディ |
|---------|------|-------|-------|
| `GET` | リソースの取得（副作用なし） | ✅ | なし |
| `POST` | リソースの新規作成 | ❌ | あり |
| `PUT` | リソースの完全更新 | ✅ | あり |
| `PATCH` | リソースの部分更新 | 条件付き | あり |
| `DELETE` | リソースの削除 | ✅ | 通常なし |

**冪等性**とは、同じリクエストを複数回送っても結果が変わらない性質。  
`GET` / `PUT` / `DELETE` は冪等。`POST` は毎回新規リソースを作るため冪等でない。

---

## 2. リソース中心のルート設計

REST の本質は**リソース**（名詞）をエンドポイントで表し、操作は HTTP メソッドで区別すること。

### 命名規則

```
# 複数形の名詞でリソースを表す
GET    /books          → 全件取得
POST   /books          → 新規作成
GET    /books/:id      → 1 件取得
PUT    /books/:id      → 完全更新
PATCH  /books/:id      → 部分更新
DELETE /books/:id      → 削除

# ネストリソース
GET    /users/:userId/orders       → ユーザーの注文一覧
POST   /users/:userId/orders       → ユーザーの注文作成
```

### アンチパターン

```
# ❌ 動詞をパスに含めない
GET /getBooks
POST /createBook
DELETE /deleteBook?id=42

# ✅ メソッドが動詞を担う
GET    /books
POST   /books
DELETE /books/42
```

---

## 3. CRUD → HTTP メソッドマッピング

| CRUD 操作 | HTTP メソッド | 対象エンドポイント | 成功レスポンス |
|-----------|-------------|------------------|--------------|
| Create | `POST` | `/resources` | `201 Created` |
| Read（一覧） | `GET` | `/resources` | `200 OK` |
| Read（1 件） | `GET` | `/resources/:id` | `200 OK` |
| Update（全更新） | `PUT` | `/resources/:id` | `200 OK` |
| Update（部分更新） | `PATCH` | `/resources/:id` | `200 OK` |
| Delete | `DELETE` | `/resources/:id` | `204 No Content` |

---

## 4. Fastify での CRUD ルート実装

### 4.1 ディレクトリ構造

```
project/
├── index.js          # エントリポイント（Fastify インスタンス・listen）
└── routes/
    ├── index.js      # ルートプラグイン（名前空間登録）
    └── booksRouter.js # リソース別ルート定義
```

### 4.2 エントリポイントへのルート登録

```js
// index.js
import Fastify from 'fastify';
import routes from './routes/index.js';

const app = Fastify({ logger: true });
const PORT = process.env.PORT ?? 3000;

app.register(routes, { prefix: '/api' });

try {
  await app.listen({ port: PORT, host: '0.0.0.0' });
} catch (err) {
  app.log.error(err);
  process.exit(1);
}
```

```js
// routes/index.js — 名前空間でルーターを束ねる
import booksRouter from './booksRouter.js';

export default async function routes(fastify, _opts) {
  fastify.register(booksRouter, { prefix: '/books' });
}
```

### 4.3 リソース別ルータ（全 CRUD）

```js
// routes/booksRouter.js
export default async function booksRouter(fastify, _opts) {

  // GET /api/books — 全件取得
  fastify.get('/', async (_req, reply) => {
    const books = await fastify.db.all('SELECT * FROM books ORDER BY id');
    reply.send(books);
  });

  // GET /api/books/:id — 1 件取得
  fastify.get('/:id', async (req, reply) => {
    const book = await fastify.db.get(
      'SELECT * FROM books WHERE id = ?',
      [req.params.id],
    );
    if (!book) {
      return reply.status(404).send({ message: 'Not found' });
    }
    reply.send(book);
  });

  // POST /api/books — 新規作成
  fastify.post('/', {
    schema: {
      body: {
        type: 'object',
        required: ['title', 'author'],
        properties: {
          title:  { type: 'string', minLength: 1 },
          author: { type: 'string', minLength: 1 },
        },
      },
    },
  }, async (req, reply) => {
    const { title, author } = req.body;
    const result = await fastify.db.run(
      'INSERT INTO books (title, author) VALUES (?, ?)',
      [title, author],
    );
    reply.status(201).send({ id: result.lastID, title, author });
  });

  // PUT /api/books/:id — 完全更新
  fastify.put('/:id', async (req, reply) => {
    const { title, author } = req.body;
    const result = await fastify.db.run(
      'UPDATE books SET title = ?, author = ? WHERE id = ?',
      [title, author, req.params.id],
    );
    if (result.changes === 0) {
      return reply.status(404).send({ message: 'Not found' });
    }
    reply.send({ id: req.params.id, title, author });
  });

  // DELETE /api/books/:id — 削除
  fastify.delete('/:id', async (req, reply) => {
    const result = await fastify.db.run(
      'DELETE FROM books WHERE id = ?',
      [req.params.id],
    );
    if (result.changes === 0) {
      return reply.status(404).send({ message: 'Not found' });
    }
    reply.status(204).send();
  });
}
```

---

## 5. HTTP ステータスコードの使い方

| 状況 | コード | 使い方 |
|------|-------|--------|
| 取得・更新成功 | `200 OK` | `reply.send(data)` |
| 作成成功 | `201 Created` | `reply.status(201).send(created)` |
| 削除成功（返却なし） | `204 No Content` | `reply.status(204).send()` |
| バリデーションエラー | `400 Bad Request` | Fastify スキーマが自動返却 |
| 認証失敗 | `401 Unauthorized` | 認証プラグインが返却 |
| 権限なし | `403 Forbidden` | 認可チェックで返却 |
| リソース未存在 | `404 Not Found` | `reply.status(404).send(...)` |
| サーバー内部エラー | `500 Internal Server Error` | `setErrorHandler` で返却 |

```js
// グローバルエラーハンドラ（index.js に登録）
app.setErrorHandler((err, _req, reply) => {
  app.log.error(err);
  const statusCode = err.statusCode ?? 500;
  reply.status(statusCode).send({
    error: err.message ?? 'Internal Server Error',
  });
});
```

---

## 6. JSON Schema によるリクエスト検証

Fastify はルートに `schema` を定義するだけで**AJV が自動検証**する。
不正なリクエストには `400 Bad Request` を自動返却し、ハンドラは実行されない。

```js
const postSchema = {
  body: {
    type: 'object',
    required: ['title', 'author'],
    properties: {
      title:  { type: 'string', minLength: 1, maxLength: 255 },
      author: { type: 'string', minLength: 1, maxLength: 100 },
    },
    additionalProperties: false, // 未定義フィールドを拒否
  },
  response: {
    201: {
      type: 'object',
      properties: {
        id:     { type: 'integer' },
        title:  { type: 'string' },
        author: { type: 'string' },
      },
    },
  },
};

fastify.post('/', { schema: postSchema }, handler);
```

`response` スキーマを定義するとシリアライゼーション（JSON 変換）も高速化される。

---

## 7. ページネーションとクエリパラメータ

```js
// GET /api/books?page=1&limit=20
fastify.get('/', {
  schema: {
    querystring: {
      type: 'object',
      properties: {
        page:  { type: 'integer', minimum: 1, default: 1 },
        limit: { type: 'integer', minimum: 1, maximum: 100, default: 20 },
      },
    },
  },
}, async (req, reply) => {
  const { page, limit } = req.query;
  const offset = (page - 1) * limit;
  const books = await fastify.db.all(
    'SELECT * FROM books LIMIT ? OFFSET ?',
    [limit, offset],
  );
  reply.send({ page, limit, data: books });
});
```

---

## 落とし穴

| 罠 | 回避策 |
|----|-------|
| エンドポイントに動詞を含める（`/getBook`） | 複数形名詞 + HTTP メソッドで操作を表す |
| `POST` で更新・削除を行う | `PUT` / `PATCH` / `DELETE` を使う |
| 削除成功に `200 + {}` を返す | `204 No Content`（ボディなし）が正しい |
| 存在しないリソースに `500` を返す | `404 Not Found` で明示する |
| スキーマなしでボディを信頼する | `schema.body` で必ず検証し、`additionalProperties: false` を付ける |
| `:id` を文字列のまま SQL に渡す | `parseInt(req.params.id)` or スキーマで `type: 'integer'` に |
| `reply.send` の後に処理を続ける | `return reply.send(...)` で早期リターンする（二重レスポンス防止） |
