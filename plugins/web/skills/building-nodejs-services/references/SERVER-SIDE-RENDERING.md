# サーバーサイドレンダリング（SSR）

Fastify でテンプレートエンジンを使い、動的データから HTML を生成してクライアントへ返すパターン。
`@fastify/view` プラグインが複数のテンプレートエンジンを抽象化する共通インターフェースを提供する。

---

## テンプレートエンジン選択

> **判断ポイント（弱推奨あり）**
> テンプレートエンジンを決めていない場合は以下の観点で選ぶ。どちらでも問題なければ EJS から始めると手軽。

| 観点 | EJS | Handlebars |
|------|-----|------------|
| 記法 | `<%= var %>` で JS 式を直接埋め込み | `{{var}}` でロジックレス記述 |
| テンプレート内ロジック | `<% %>` でループ・条件分岐を直接記述 | ヘルパー関数経由でのみ実装 |
| 学習コスト | HTML 経験者が短時間で習得可 | テンプレートとロジックの分離に慣れが必要 |
| 推奨シナリオ | 小〜中規模 / チームに JS 経験者が多い場合 | テンプレートのメンテナンス性を重視するチーム |

**弱推奨**: 初めての Fastify SSR には EJS が手軽。テンプレートとビジネスロジックを厳密に分離したい場合は Handlebars を選ぶ。

> **ツール利用不可環境向け代替質問**:
> 「テンプレート内に JS ロジックを直接書きたいか（→ EJS）、テンプレートはロジックレスに保ちたいか（→ Handlebars）？」

---

## 概念とセットアップ

### `@fastify/view` のしくみ

```
HTTP リクエスト → Fastify ルートハンドラ → reply.view(テンプレート, データ)
                                       → テンプレートエンジンが HTML を生成
                                       → クライアントへ HTML レスポンス
```

1. プラグイン登録時にテンプレートエンジンと `root` ディレクトリを指定
2. ルートハンドラで `reply.view(templatePath, data)` を呼び出す
3. Fastify がテンプレートを解決して HTML を生成し、レスポンスとして返す

SSR は SPA（React 等）の代替として機能し、初回表示が速く、SEO に有利で、クライアントビルドが不要。

---

## EJS パターン

### インストール

```bash
npm install @fastify/view ejs
```

### 登録とルート設定

```js
import Fastify from 'fastify';
import fastifyView from '@fastify/view';
import ejs from 'ejs';

const app = Fastify({ logger: true });

await app.register(fastifyView, {
  engine: { ejs },
  root: 'views',  // テンプレートファイルを配置するディレクトリ
});

app.get('/items', async (req, reply) => {
  const items = [
    { name: 'Alpha', price: 1200 },
    { name: 'Beta',  price: 2800 },
  ];
  return reply.view('items.ejs', { items });
});

await app.listen({ port: 3000 });
```

### EJS テンプレート例（`views/items.ejs`）

```html
<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="UTF-8">
  <title>アイテム一覧</title>
  <link rel="stylesheet" href="/public/style.css">
</head>
<body>
  <h1>アイテム一覧</h1>
  <ul>
    <% for (const item of items) { %>
      <li><strong><%= item.name %></strong> — <%= item.price %>円</li>
    <% } %>
  </ul>
</body>
</html>
```

EJS の基本構文:

| 記法 | 意味 |
|------|------|
| `<%= expr %>` | 評価結果を HTML エスケープして出力 |
| `<%- expr %>` | エスケープなしで出力（信頼済み HTML のみ） |
| `<% code %>` | JS コードを実行（出力なし・ループ・条件分岐に使う） |

---

## Handlebars パターン

### インストール

```bash
npm install @fastify/view handlebars @fastify/formbody
```

### 登録とフォームルート

```js
import Fastify from 'fastify';
import fastifyView from '@fastify/view';
import fastifyFormbody from '@fastify/formbody';
import handlebars from 'handlebars';

const app = Fastify({ logger: true });

// @fastify/formbody: application/x-www-form-urlencoded を解析（フォーム送信に必須）
await app.register(fastifyFormbody);

await app.register(fastifyView, {
  engine: { handlebars },
  root: 'views',
});

// GET でフォームページを表示
app.get('/login', async (req, reply) => {
  return reply.view('login.hbs', { title: 'ログイン' });
});

// POST でフォームデータを受信
app.post('/login', async (req, reply) => {
  const { username } = req.body;  // @fastify/formbody が解析
  return reply.view('welcome.hbs', { username });
});

await app.listen({ port: 3000 });
```

### Handlebars テンプレート例（`views/login.hbs`）

```html
<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="UTF-8">
  <title>{{title}}</title>
</head>
<body>
  <h1>{{title}}</h1>
  <form method="POST" action="/login">
    <input type="text" name="username" placeholder="ユーザー名" required>
    <button type="submit">ログイン</button>
  </form>
</body>
</html>
```

Handlebars の基本構文:

| 記法 | 意味 |
|------|------|
| `{{var}}` | 変数を出力（自動エスケープ） |
| `{{{var}}}` | エスケープなしで出力（信頼済み HTML のみ） |
| `{{#if cond}} ... {{/if}}` | 条件ブロック |
| `{{#each list}} ... {{/each}}` | 繰り返しブロック |

---

## 静的アセット配信

CSS・画像・クライアントサイド JS は `@fastify/static` で配信する。

```bash
npm install @fastify/static
```

```js
import fastifyStatic from '@fastify/static';
import { join } from 'path';

await app.register(fastifyStatic, {
  root: join(process.cwd(), 'public'),  // 配信元ディレクトリ（絶対パス必須）
  prefix: '/public/',                   // URL プレフィックス
});
```

テンプレートからの参照:

```html
<link rel="stylesheet" href="/public/style.css">
<script src="/public/main.js"></script>
<img src="/public/logo.png" alt="ロゴ">
```

ディレクトリ慣例: `views/` にテンプレート、`public/` に静的アセット（CSS・JS・画像）を配置する。

---

## フォーム処理パターン

HTML フォームの `action` / `method` を Fastify のルートに対応させる。
GET でフォームを表示し、POST でデータを受信・処理してリダイレクトまたは再レンダリングする。

POST 後のリダイレクト（PRG パターン）でブラウザの二重送信を防ぐ:

```js
app.post('/items', async (req, reply) => {
  const { name, price } = req.body;
  // データ保存処理（DB等）...
  return reply.redirect('/items');  // POST → Redirect → GET
});
```

---

## 落とし穴

| 症状 | 原因 | 対処 |
|------|------|------|
| `reply.view` でテンプレートが見つからないエラー | `root` パスの指定誤りまたは `views/` 未作成 | `process.cwd()` 基準でパスを確認、または `root` に絶対パスを渡す |
| フォームデータが `req.body` に入らない（undefined） | `@fastify/formbody` が未登録 | ルート定義より前に `await app.register(fastifyFormbody)` を呼ぶ |
| EJS で XSS 脆弱性が生まれる | `<%- %>` でユーザー入力をそのまま出力している | ユーザー入力は必ず `<%= %>` を使う（自動エスケープ）。`<%-` は信頼済み HTML のみ |
| `@fastify/view` と `@fastify/static` のパス衝突 | `prefix` の指定が重複またはデフォルト値が干渉 | `prefix` を明示的に設定し衝突を回避 |
| Handlebars で変数が空白になる | `reply.view()` に渡すオブジェクトのキー名とテンプレートの `{{varName}}` が不一致 | データオブジェクトのキー名とテンプレート変数名を照合する |

---

## スコープ外・関連スキル

- React などクライアントサイドフレームワークとの組み合わせ → `web:developing-fullstack-javascript`
- API スタイルの選定（REST vs SSR vs SPA） → `web:choosing-api-styles`
- HTTP プロトコル設計・バージョニング → `web:developing-web-apis`
