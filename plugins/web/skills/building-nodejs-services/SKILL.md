---
name: building-nodejs-services
description: >-
  Build backend services, web servers, and CLI tools on the Node.js runtime using the Fastify
  framework. Use when package.json contains fastify, when defining Fastify routes, plugins, hooks, or
  JSON-schema validation, or when working with Node runtime internals (event loop phases, libuv,
  streams, buffers, clustering, worker threads, blocking-the-event-loop avoidance) beyond browser-level
  JavaScript. Covers Fastify routing and request/reply, schema-based validation and serialization
  (AJV/JSON Schema), the plugin and encapsulation model, Pino logging, server-side rendering with
  EJS/Handlebars, RESTful CRUD APIs, persistence with Mongoose/Sequelize/SQLite/Redis, session/cookie
  and JWT authentication flows, message queues (RabbitMQ/amqplib), CLI tooling (process stdio,
  promisify, CSV), external data integration (fetch, feed aggregation, scraping via cheerio/Puppeteer),
  email and generative-AI service integration, and project scaffolding (npm init, ESM, node --watch).
when_to_use: >-
  For Express/NestJS backends, React frontends, CI/CD, deployment, or JavaScript language fundamentals,
  use developing-fullstack-javascript. For selecting between REST/GraphQL/gRPC API styles, use
  choosing-api-styles. For HTTP/Web API protocol design, versioning, and API test strategy, use
  developing-web-apis. For DB schema design and SQL tuning, use lang:developing-databases. For deep
  prompt-engineering and LLM app architecture, use ai:integrating-ai-web-apps. For containerization and
  deployment infrastructure, use cloud:practicing-devops.
disable-model-invocation: false
---

# building-nodejs-services

Node ランタイム上で Fastify を用いてバックエンドサービス・Web サーバー・CLI ツールを構築するためのクイックリファレンス。詳細な実装ガイドは `references/` を参照する。

---

## 1. 使用タイミング

本スキルは以下の状況で起動する:

- `package.json` の `dependencies` または `devDependencies` に `fastify` が含まれている
- Fastify のルート定義・プラグイン・フック・スキーマ検証を実装・改修する
- Node ランタイムの内部動作（イベントループ・libuv・ストリーム・クラスタリング）を深く扱う
- CLI ツール・バックグラウンドジョブ・データ統合スクリプトを Node で構築する
- 認証・永続化・メッセージキューなどのサービス機能を Fastify ベースで追加する

> **自動起動**: `disable-model-invocation: false` により、Fastify 関連ファイルが文脈に存在するとき自動的に本スキルが適用される。devkit のルーティング hook を別途更新するまでは、`fastify` 検出時に本スキルが自動起動するかどうかは description ベースの文脈判断に依存する。

---

## 2. コアプリンシプル

### ① ノンブロッキング前提の設計

Node のイベントループはシングルスレッドで非同期 I/O を多重化する。CPU バウンドな同期処理（ネストしたループ・巨大データ変換・暗号演算）はイベントループを停止させ、全リクエストの応答を遅延させる。

**判断ルール**:
- ファイル読み書き・DB クエリ・ネットワーク呼び出し → 非同期 API を使う（`fs.promises` / ORM / `fetch`）
- CPU バウンド処理 → `worker_threads` か外部プロセスへオフロード
- `setInterval` / `setTimeout` 内での重い処理 → スタック分割か `setImmediate` でサイクルを明け渡す

### ② スキーマ駆動（AJV で入出力を型付け）

Fastify はルート定義時に JSON Schema を受け取り、AJV で**リクエストバリデーション**と**レスポンスシリアライゼーション**を事前コンパイルする。

利点:
- 不正入力をルートハンドラーに到達する前に弾き、防御コードを削減できる
- `response` スキーマによりシリアライズが高速化される（未定義フィールドを自動除去）
- スキーマが自己文書化として機能する

```js
// スキーマ付きルートの骨格
app.post('/items', {
  schema: {
    body: {
      type: 'object',
      required: ['name', 'price'],
      properties: {
        name:  { type: 'string', maxLength: 100 },
        price: { type: 'number', minimum: 0 }
      }
    },
    response: {
      201: {
        type: 'object',
        properties: {
          id:   { type: 'string' },
          name: { type: 'string' }
        }
      }
    }
  }
}, async (request, reply) => {
  reply.code(201).send({ id: crypto.randomUUID(), name: request.body.name });
});
```

### ③ プラグインで機能をカプセル化

Fastify のプラグインは `fastify.register()` で追加し、スコープ内に装飾・ルート・フックを閉じ込める。親スコープには自動で漏れない（encapsulation）。`fastify-plugin`（`fp`）でラップすると親スコープへ公開できる。

```js
// 認証フックをプラグインとして切り出す例
import fp from 'fastify-plugin';

const authPlugin = async (fastify) => {
  fastify.addHook('preHandler', async (request, reply) => {
    if (!request.headers.authorization) {
      reply.code(401).send({ error: 'Unauthorized' });
    }
  });
};
export default fp(authPlugin);
```

### ④ 構造化ログ（Pino）

Fastify はデフォルトで Pino ロガーを内蔵する。`request.log.info()` / `request.log.error()` で JSON 構造化ログを出力する。`console.log` を本番コードに残してはならない。

```js
const app = Fastify({ logger: { level: process.env.LOG_LEVEL ?? 'info' } });

app.get('/health', async (request) => {
  request.log.info({ reqId: request.id }, 'health check called');
  return { status: 'ok' };
});
```

### ⑤ 秘匿情報は環境変数

DB 接続文字列・JWT シークレット・外部 API キーをコードにハードコードしてはならない。`dotenv` または Node 20+ の `--env-file` フラグを使い、`.env` をリポジトリに含めない（`.gitignore` に追加する）。

### ⑥ 段階的スケール

| 負荷特性 | 推奨手法 |
|---------|---------|
| I/O 多い・CPU 軽い | 単一プロセス（デフォルト）で十分 |
| マルチコアを活かしたい | `cluster` モジュールで CPU コア数分のワーカープロセスを起動 |
| CPU バウンド処理あり | `worker_threads` でメインスレッドから重い計算を分離 |

> スケール判断は実測（プロファイリング）ベースで行う。過早な最適化を避ける。

---

## 3. Fastify クイックスタート

### 最小サーバー

```js
// index.js（ESM モード: package.json に "type":"module" を追加）
import Fastify from 'fastify';

const app = Fastify({ logger: true });
const PORT = Number(process.env.PORT) || 3000;

app.get('/', async () => ({ message: 'hello' }));

try {
  await app.listen({ port: PORT, host: '0.0.0.0' });
} catch (err) {
  app.log.error(err);
  process.exit(1);
}
```

**ポイント**:
- `Fastify({ logger: true })` でリクエストログが自動付与される
- ルートハンドラーが返す値は JSON 自動シリアライズされてレスポンスボディになる
- `host: '0.0.0.0'` を指定してコンテナ環境でも外部からアクセス可能にする
- 起動失敗時は `process.exit(1)` でクラッシュを明示し壊れた状態で動き続けないようにする

### ルートの基本

```js
// URL パラメータ・クエリ文字列の取得
app.get('/users/:id', async (request) => {
  const { id }   = request.params;  // /users/42 → id = '42'
  const { page } = request.query;   // ?page=2 → page = '2'
  return { id, page };
});

// JSON ボディを受け取る POST
app.post('/users', async (request, reply) => {
  const user = request.body;        // Content-Type: application/json が必要
  reply.code(201).send(user);
});
```

### `reply` オブジェクトの主要メソッド

| メソッド | 用途 |
|---------|------|
| `reply.send(data)` | ボディを送信（型に応じて Content-Type 自動決定） |
| `reply.code(n)` | HTTP ステータスコードを設定（チェーン可能） |
| `reply.header(k, v)` | レスポンスヘッダーを追加 |
| `reply.redirect(url)` | 3xx リダイレクト |

### 開発中の自動再起動

```bash
node --watch index.js   # Node 18.11+ の組み込み watch モード
```

---

## 4. Node ランタイム要点

### イベントループの 6 フェーズ

```
timers → pending callbacks → idle/prepare → poll → check → close callbacks
```

| フェーズ | 実行内容 |
|---------|---------|
| timers | `setTimeout` / `setInterval` のコールバック |
| pending callbacks | 前のループで defer された I/O コールバック |
| poll | 新しい I/O イベントの取得と実行 |
| check | `setImmediate` のコールバック |
| close callbacks | `socket.destroy()` 等の close イベント |

`process.nextTick` と `queueMicrotask`（Promise の `.then`）は各フェーズの直後に実行されるマイクロタスクキューに入り、次フェーズに持ち越されない。

### ストリームとバッファ

- **Buffer**: バイナリデータを固定長で保持するメモリ領域。画像・バイナリファイルを扱う際に使う
- **Stream**: データをチャンク単位で流すインターフェース。大ファイル処理・HTTP レスポンスの逐次送信に最適
- `stream.pipeline(source, transform, dest, cb)` または `stream/promises` の `pipeline` でエラー伝播を自動管理する（手動の `.pipe()` より推奨）

### CPU バウンド判断表

| 処理 | ブロッキングリスク | 対処 |
|------|------------------|------|
| ファイル読み書き | なし（libuv が非同期処理） | `fs.promises` / ストリーム |
| DB クエリ | なし（I/O オフロード） | ORM / ドライバの async API |
| JSON.parse（大サイズ） | あり | ワーカースレッドへオフロード |
| 正規表現（バックトラック） | あり | timeout 付き外部プロセスで実行 |
| 暗号演算（pbkdf2 等） | あり | `util.promisify(crypto.pbkdf2)` |

> libuv のスレッドプールサイズはデフォルト 4。`UV_THREADPOOL_SIZE` 環境変数で最大 128 まで拡張可能。

---

## 5. AskUserQuestion 原則

**判断が分岐する局面では推測せず確認する**。以下のシグナルを検出したら `AskUserQuestion` を使う:

| 検出シグナル | 確認すべき内容 | 選択肢の骨子 |
|-------------|-------------|------------|
| データを永続化する | 永続化レイヤの選択 | SQLite / PostgreSQL(Sequelize) / MongoDB(Mongoose) / Redis |
| 認証が必要 | 認証方式の選択 | セッション/Cookie（SSR アプリ）/ JWT（ステートレス API） |
| キュー・非同期処理が必要 | キュー技術の選択 | インメモリ / Redis / RabbitMQ |
| HTML を返すページがある | テンプレートエンジン | EJS（JS 埋め込み）/ Handlebars（ロジックレス） |
| 高負荷・マルチコア活用 | スケール手法 | 単一プロセス / clustering / worker threads |

**確認が不要な推奨事項（既定で適用）**:
- バリデーションは AJV/JSON Schema を使う（Fastify 組み込みのスキーマ機構）
- パスワードは必ず bcrypt か `node:crypto` の `scrypt`/`pbkdf2` で安全にハッシュ化する
- ロギングは Pino を既定とする（`console.log` を本番コードに残さない）
- 秘匿情報は環境変数で管理し、コードにハードコードしない

> ⚠️ **Codex fallback**: `AskUserQuestion` ツールが使えない環境では、判断が必要な箇所に `// TODO: 要件に応じて変更` コメントを挿入し、複数パターンのコード断片を列挙して人間が選べる状態にする。

---

## 6. references ナビゲーション

詳細な実装ガイドは `references/` ディレクトリを参照。各ファイルは「概念 → 汎用パターン → 最小コード例 → 落とし穴」の順で構成している。

| ファイル | カバー内容 |
|---------|-----------|
| [FASTIFY-FUNDAMENTALS.md](references/FASTIFY-FUNDAMENTALS.md) | インスタンス化・ルーティング・request/reply・ライフサイクル/フック・プラグイン & encapsulation・decorators・スキーマ検証 & シリアライゼーション（AJV）・Pino ロギング・エラーハンドリング |
| [NODE-RUNTIME-INTERNALS.md](references/NODE-RUNTIME-INTERNALS.md) | イベントループのフェーズ詳細・libuv・ストリーム & バッファ・clustering / worker threads・Blocking the Event Loop 回避・`process` stdio |
| [REST-API-DESIGN.md](references/REST-API-DESIGN.md) | HTTP メソッド・RESTful ルート設計・CRUD API レイアウト・リソース設計の実装レシピ |
| [DATA-PERSISTENCE-PATTERNS.md](references/DATA-PERSISTENCE-PATTERNS.md) | Mongoose / Sequelize / SQLite3 / Redis 接続パターン・SQLite vs PostgreSQL 選択基準・**AskUserQuestion: 永続化レイヤ選択** |
| [AUTHENTICATION-FLOWS.md](references/AUTHENTICATION-FLOWS.md) | セッション/Cookie・bcrypt / `node:crypto` ハッシュ・JWT 認証・**AskUserQuestion: 認証方式選択** |
| [SERVER-SIDE-RENDERING.md](references/SERVER-SIDE-RENDERING.md) | EJS / Handlebars SSR・`@fastify/view`・静的アセット配信・フォームレンダリング・**AskUserQuestion: テンプレートエンジン** |
| [MESSAGING-AND-QUEUES.md](references/MESSAGING-AND-QUEUES.md) | インメモリキュー・Redis キュー・RabbitMQ/amqplib・**AskUserQuestion: キュー技術選択** |
| [CLI-TOOLS.md](references/CLI-TOOLS.md) | `process` 標準入出力・引数処理・`promisify`・外部パッケージ利用・CSV 変換 |
| [EXTERNAL-DATA-INTEGRATION.md](references/EXTERNAL-DATA-INTEGRATION.md) | native `fetch`・フィード取得と集約・スクレイピング（cheerio / Puppeteer）・文字列処理と感情分析 |
| [SERVICE-INTEGRATIONS.md](references/SERVICE-INTEGRATIONS.md) | メール（nodemailer）・タスクスケジューラ・生成 AI API 統合の実装面（詳細は `ai:integrating-ai-web-apps` へ） |
| [PROJECT-SCAFFOLDING.md](references/PROJECT-SCAFFOLDING.md) | `npm init`・スケール別ディレクトリ構成・ESM / top-level await / `node --watch` / native fetch・Yarn vs npm |
| [QUALITY-CHECKLIST.md](references/QUALITY-CHECKLIST.md) | `fastify.inject` ルートテスト・graceful shutdown・環境設定・エラーハンドリング・セキュリティ基本 |

---

## 7. スコープ外

以下は本スキルの対象外。適切なスキルへ誘導する:

| 対象外テーマ | 参照先スキル |
|------------|-------------|
| Express / NestJS バックエンド | `developing-fullstack-javascript` |
| React / Next.js フロントエンド | `developing-fullstack-javascript` |
| CI/CD・デプロイメント・コンテナ本番設定 | `cloud:practicing-devops` |
| REST / GraphQL / gRPC のスタイル選定 | `choosing-api-styles` |
| HTTP プロトコル設計・バージョニング・API テスト戦略 | `developing-web-apis` |
| DB スキーマ設計・SQL チューニング | `lang:developing-databases` |
| プロンプトエンジニアリング・LLM アプリアーキテクチャ | `ai:integrating-ai-web-apps` |
| JavaScript 言語基礎（クロージャ・プロトタイプ等） | `developing-fullstack-javascript` |
