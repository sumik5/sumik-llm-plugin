# QUALITY-CHECKLIST.md — Node.js サービス品質チェックリスト

Fastify サービスのレビュー・デプロイ前に確認するチェックリスト。
各セクションを上から順に確認し、すべての `- [ ]` をクリアしてから本番リリースする。

> 詳細な OWASP Top 10 対応・CI/CD パイプライン設計は `web:developing-fullstack-javascript` を参照すること。

---

## 1. ルートテスト（`fastify.inject`）

Fastify の `inject()` メソッドを使うと、実際に HTTP サーバーを起動せずにルートを検証できる。

```js
// src/app.js — アプリセットアップを関数として切り出す
import Fastify from 'fastify';

export function build(opts = {}) {
  const app = Fastify(opts);
  app.get('/health', async () => ({ status: 'ok' }));
  return app;
}
```

```js
// test/routes.test.js
import { build } from '../src/app.js';
import { describe, it, expect, afterEach } from 'vitest';

describe('GET /health', () => {
  let app;
  afterEach(async () => { await app.close(); });

  it('200 と ok を返す', async () => {
    app = build({ logger: false });
    const res = await app.inject({ method: 'GET', url: '/health' });
    expect(res.statusCode).toBe(200);
    expect(res.json()).toEqual({ status: 'ok' });
  });
});
```

### チェックリスト

- [ ] 主要ルート（GET・POST・PUT・DELETE）に対して `inject()` テストが存在する
- [ ] 正常系（200/201）と異常系（400/404/422/500）の両方をカバーしている
- [ ] バリデーションエラー（スキーマ違反リクエスト）が 400 を返すことを確認している
- [ ] 各テストで `app.close()` を呼んでリソースリークを防いでいる
- [ ] `npm test` で全テストが通る

---

## 2. 環境設定

- [ ] 秘匿情報（DB 接続文字列・API キー・JWT シークレット）はすべて環境変数で管理している
- [ ] `.env` ファイルが `.gitignore` に追加されている（コミット禁止）
- [ ] `.env.example` を用意し、必要な変数のキーを空値でコミットしている
- [ ] `PORT`・`HOST` などの設定値にデフォルト値を設けている

```js
const { PORT = 3000, HOST = '127.0.0.1', NODE_ENV = 'development' } = process.env;
```

- [ ] 本番・開発・テスト環境で `NODE_ENV` を使って設定を切り替えている
- [ ] 環境変数の読み込みはエントリーファイルの最初に行っている

---

## 3. Graceful Shutdown

突然のプロセス終了（`SIGTERM`・`SIGINT`）に対し、進行中のリクエストを完結させてから
サーバーを停止するパターン。

```js
const shutdown = async (signal) => {
  app.log.info(`${signal} received — shutting down`);
  await app.close(); // Fastify の onClose フックを実行してから接続を閉じる
  process.exit(0);
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT',  () => shutdown('SIGINT'));
```

### チェックリスト

- [ ] `SIGTERM` と `SIGINT` のハンドラーを実装している
- [ ] `app.close()` を `await` してから `process.exit(0)` を呼んでいる
- [ ] DB コネクション・キューコンシューマーのクローズを `onClose` フックまたはシャットダウン処理に含めている
- [ ] Docker/Kubernetes 環境でプロセスに `SIGTERM` が届くことを確認している

---

## 4. エラーハンドリング

### グローバルエラーハンドラー

```js
app.setErrorHandler((error, request, reply) => {
  app.log.error({ err: error, reqId: request.id }, 'request error');
  const status = error.statusCode ?? 500;
  // 500 系はクライアントに詳細を返さない（内部情報の漏洩防止）
  reply.status(status).send({
    error: status >= 500 ? 'Internal Server Error' : error.message,
  });
});
```

### 未処理の Promise 拒否

```js
process.on('unhandledRejection', (reason) => {
  app.log.fatal({ err: reason }, 'unhandled rejection');
  process.exit(1);
});
```

### チェックリスト

- [ ] `app.setErrorHandler()` でグローバルエラーハンドラーを設定している
- [ ] 500 系エラーはログに記録し、クライアントには汎用メッセージのみを返している
- [ ] `process.on('unhandledRejection')` を設定してクラッシュを補足している
- [ ] エラーログに `request.id` を含め、トレーサビリティを確保している
- [ ] Fastify のスキーマバリデーション（AJV）でリクエスト入力を検証している（400 の自動生成）

---

## 5. セキュリティ基本

> 詳細な脅威モデリング・ペネトレーションテストは `web:developing-fullstack-javascript` を参照すること。

- [ ] `@fastify/helmet` を導入し、HTTP セキュリティヘッダーを設定している
- [ ] CORS を `@fastify/cors` で明示的に制限している（本番で `origin: '*'` を使わない）
- [ ] レート制限（`@fastify/rate-limit`）でブルートフォース攻撃を緩和している
- [ ] すべての外部入力を Fastify のスキーマ（JSON Schema）で検証している
- [ ] SQL クエリはパラメーター化クエリを使い、SQL インジェクションを防いでいる
- [ ] パスワードは `bcrypt` または `node:crypto` の `scrypt` でハッシュ化している（平文保存禁止）
- [ ] JWT シークレット・API キー等の秘匿情報をコードにハードコードしていない
- [ ] `npm audit` を定期実行して既知の脆弱性を確認している

---

## 6. ロギング

- [ ] Fastify のビルトイン Pino ロガーを使っている（`console.log` に依存しない）
- [ ] 開発環境では `pino-pretty` でログを読みやすくしている
- [ ] 本番環境では JSON 形式の構造化ログを出力している
- [ ] ログにパスワード・トークン・個人情報が含まれないことを確認している

```js
const app = Fastify({
  logger: process.env.NODE_ENV === 'production'
    ? true
    : { transport: { target: 'pino-pretty' } },
});
```

---

## 7. 本番リリース前の最終確認

- [ ] `npm test` が全グリーン
- [ ] `npm audit` で High/Critical の脆弱性がゼロ
- [ ] 本番環境に必要な環境変数がすべて設定されている（`.env.example` をもとに確認）
- [ ] Graceful shutdown が動作確認済み（`SIGTERM` を手動送信して検証）
- [ ] ログに秘匿情報が流れていないことを確認済み
- [ ] 本番の `start` スクリプトに `--watch` が含まれていない
- [ ] Dockerfile / `.dockerignore` が存在し、`node_modules` と `.env` が除外されている
