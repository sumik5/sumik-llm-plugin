# Node.js ランタイム内部構造

Node.js は**シングルスレッド**の JavaScript エンジン（V8）と、**非同期 I/O** を担う libuv を組み合わせたランタイムである。
イベントループが「実行待ちのコールバック」を順次処理することで、スレッドを増やさずに多数の並行接続を捌く。

---

## 1. イベントループのフェーズ

1 周（ティック）は 6 フェーズを順に処理する。

```
   ┌──────────────────────────────┐
┌─▷│ timers                       │ setTimeout / setInterval
│  └──────────────────────────────┘
│  ┌──────────────────────────────┐
│  │ pending callbacks            │ 前ティックで延期された I/O
│  └──────────────────────────────┘
│  ┌──────────────────────────────┐
│  │ idle, prepare                │ Node 内部用（通常スキップ）
│  └──────────────────────────────┘
│  ┌──────────────────────────────┐
│  │ poll                         │ 新 I/O イベント待機・実行
│  └──────────────────────────────┘
│  ┌──────────────────────────────┐
│  │ check                        │ setImmediate
│  └──────────────────────────────┘
│  ┌──────────────────────────────┐
└──│ close callbacks              │ socket.close() 等
   └──────────────────────────────┘
```

### フェーズ詳細

| フェーズ | 実行されるもの | 補足 |
|---------|--------------|------|
| **timers** | `setTimeout` / `setInterval` の期限切れコールバック | 期限は「最短の目安」であり保証ではない |
| **pending callbacks** | TCP エラー等、OS が前ティックに通知しなかった I/O | 通常は空 |
| **idle / prepare** | Node 内部フック | ユーザーコードは書かない |
| **poll** | I/O コールバックを実行。キューが空なら次のタイマーまで待機 | ブロック発生の主要フェーズ |
| **check** | `setImmediate` のコールバック | poll フェーズ直後に保証実行 |
| **close callbacks** | 非同期に閉じられたソケットや handle の後始末 | |

### マイクロタスクキュー（割り込み優先）

`Promise.then` / `queueMicrotask` は**フェーズ遷移のたびに**、次フェーズへ移る前に空になるまで実行される。

```js
setTimeout(() => console.log('timer'));    // timers フェーズ
setImmediate(() => console.log('immed')); // check フェーズ
Promise.resolve().then(() => console.log('micro')); // フェーズ遷移前

// 出力順: micro → timer or immed（poll 後の順序依存）
```

---

## 2. libuv とスレッドプール

libuv はクロスプラットフォームな非同期 I/O ライブラリ。Node.js の「裏方」として 2 種類の戦略を使い分ける。

| I/O 種別 | 戦略 | スレッド |
|---------|------|---------|
| ネットワーク | OS の非同期 API（`epoll` / `kqueue` / IOCP） | 不要 |
| ファイルシステム | libuv スレッドプール | 使用 |
| DNS 解決 (`dns.lookup`) | libuv スレッドプール | 使用 |
| `crypto` 系（bcrypt 等） | libuv スレッドプール | 使用 |

```
メインスレッド ──── イベントループ ──── コールバック実行
                        │
              libuv スレッドプール（デフォルト 4）
                        │
                OS / ファイルシステム
```

**スレッドプールサイズの調整**（CPU コア数に合わせる）:

```
UV_THREADPOOL_SIZE=8 node server.js
```

> `crypto.pbkdf2` や `bcrypt` を多用する場合、デフォルト 4 スレッドがボトルネックになりやすい。

---

## 3. Streams と Buffers

### 3.1 Buffer

`Buffer` はバイナリデータを扱う固定長のメモリ領域。

```js
// 文字列 → Buffer
const buf = Buffer.from('hello', 'utf8');
console.log(buf.toString('hex'));  // 68656c6c6f

// ゼロ埋め安全確保
const safe = Buffer.alloc(16);

// 生確保（初期化なし・高速だが機密漏洩リスクあり）
const raw = Buffer.allocUnsafe(16);
```

### 3.2 Stream の種類

| 種類 | クラス | 用途 |
|------|-------|------|
| Readable | `stream.Readable` | ファイル読み込み・HTTP リクエスト |
| Writable | `stream.Writable` | ファイル書き込み・HTTP レスポンス |
| Duplex | `stream.Duplex` | ソケット（読み書き両方） |
| Transform | `stream.Transform` | 圧縮・暗号化・変換 |

Stream の利点: 大きなデータを**チャンク**（デフォルト 16 KB）で処理し、メモリ使用量を一定に保つ。

```js
import { createReadStream, createWriteStream } from 'node:fs';
import { createGzip } from 'node:zlib';
import { pipeline } from 'node:stream/promises';

// ファイルを圧縮しながら書き出す（メモリに全データを溜め込まない）
await pipeline(
  createReadStream('input.log'),
  createGzip(),
  createWriteStream('input.log.gz'),
);
```

### 3.3 `stream.pipeline` を使う理由

`pipe()` は**エラー時にクリーンアップしない**。`pipeline`（または `stream/promises` 版）を使うと、
エラー発生時にすべてのストリームが自動クローズされる。

---

## 4. Clustering（マルチコア活用）

Node.js のメインスレッドは 1 CPU コアしか使わない。`cluster` モジュールで**複数のワーカープロセス**を起動すると、
OS のロードバランサーが接続を分散する。

```js
import cluster from 'node:cluster';
import { cpus } from 'node:os';
import { createServer } from 'node:http';

if (cluster.isPrimary) {
  const numCPUs = cpus().length;
  for (let i = 0; i < numCPUs; i++) {
    cluster.fork();
  }
  cluster.on('exit', (worker) => {
    console.log(`worker ${worker.process.pid} died → reforking`);
    cluster.fork(); // クラッシュ時に自動再起動
  });
} else {
  // 各ワーカーが独立した Fastify インスタンスを起動
  const { default: buildApp } = await import('./app.js');
  const app = buildApp();
  await app.listen({ port: 3000 });
}
```

**Clustering の制約**:
- ワーカー間でメモリは**共有しない**（セッションやキャッシュは Redis 等の外部ストアへ）
- IPC チャンネルでメッセージングは可能（`process.send` / `worker.send`）

---

## 5. Worker Threads（CPU バウンド処理）

Clustering は I/O 多重化には有効だが、CPU バウンドな処理（画像変換・圧縮・ML 推論）には不向き。
`worker_threads` を使うと**同一プロセス内**でスレッドを生成し、共有メモリ（`SharedArrayBuffer`）も使える。

```js
// main.js
import { Worker } from 'node:worker_threads';

function runHeavyTask(data) {
  return new Promise((resolve, reject) => {
    const worker = new Worker('./heavy-task.js', { workerData: data });
    worker.on('message', resolve);
    worker.on('error', reject);
  });
}

const result = await runHeavyTask({ input: [1, 2, 3] });
```

```js
// heavy-task.js（Worker スクリプト）
import { workerData, parentPort } from 'node:worker_threads';

// CPU を使う処理（イベントループをブロックしても問題ない）
const result = workerData.input.reduce((a, b) => a + b, 0);
parentPort.postMessage(result);
```

---

## 6. Blocking the Event Loop 回避

### 6.1 ブロッキングの原因

| 原因 | 例 |
|------|-----|
| CPU バウンドな同期処理 | ネストしたループ・正規表現の非効率なバックトラック |
| 同期 I/O 呼び出し | `fs.readFileSync` をリクエストハンドラ内で使用 |
| 巨大な JSON のパース | `JSON.parse(veryLargeString)` |
| 重い暗号処理（同期） | `crypto.pbkdf2Sync` |

### 6.2 CPU バウンド vs I/O バウンド の判断表

| 特性 | CPU バウンド | I/O バウンド |
|------|------------|------------|
| ボトルネック | 計算量 | 待機時間 |
| 対策 | Worker Threads / 外部サービス化 | async/await + イベントループ |
| 例 | 画像処理・暗号・ML 推論 | DB クエリ・HTTP 呼び出し |

### 6.3 回避パターン

```js
// ❌ ブロッキング: リクエストハンドラ内で同期 I/O
app.get('/bad', (_req, reply) => {
  const data = fs.readFileSync('./data.json', 'utf8'); // 全リクエストが待つ
  reply.send(JSON.parse(data));
});

// ✅ ノンブロッキング: 非同期版を使う
app.get('/good', async (_req, reply) => {
  const data = await fs.promises.readFile('./data.json', 'utf8');
  reply.send(JSON.parse(data));
});

// ✅ CPU バウンドは Worker Thread に分離
app.get('/compute', async (_req, reply) => {
  const result = await runInWorker(heavyPayload);
  reply.send({ result });
});
```

---

## 7. `process` stdio と環境変数

```js
// 標準入出力
process.stdout.write('メッセージ\n');   // console.log の低レベル版
process.stderr.write('エラー情報\n');  // プロセス監視ツールで分離可能

// 環境変数（設定値はここから取得・ハードコード禁止）
const PORT = process.env.PORT ?? '3000';
const DB_URL = process.env.DATABASE_URL;
if (!DB_URL) {
  process.stderr.write('DATABASE_URL が未設定\n');
  process.exit(1);  // 異常終了コード
}

// プロセスシグナル（graceful shutdown）
process.on('SIGTERM', async () => {
  await app.close(); // 新規接続を停止し処理中リクエストを完了させる
  process.exit(0);
});
```

---

## 8. スケール手法の選択（AskUserQuestion）

スケール要件が不明な場合はユーザーに確認する。

```
負荷特性はどちらに近いですか？

A. I/O 多い（DB クエリ・外部 API 呼び出し）
   → 単一プロセス + 非同期処理で対応。CPUコアを使い切るなら clustering も追加。

B. CPU バウンドが含まれる（画像変換・暗号・機械学習）
   → Worker Threads または外部マイクロサービス化を推奨。

C. 高トラフィック予想（数千 RPS 以上）
   → clustering（コア数分のワーカー）+ ロードバランサー（Nginx / k8s）。

Codex 環境ではインタラクティブな確認が難しい場合があります。
その場合は A（単一プロセス非同期）を既定として実装し、後から切り替えてください。
```

---

## 落とし穴

| 罠 | 回避策 |
|----|-------|
| `setTimeout(fn, 0)` でイベントループを「回避」しようとする | 根本解決にならない。CPU バウンドは Worker Thread へ |
| Clustering + インメモリセッション | セッションは Redis 等の共有ストアへ移行する |
| `Buffer.allocUnsafe` で機密データが残存 | 機密領域は `Buffer.alloc`（ゼロ埋め）を使う |
| `pipeline` の代わりに `pipe` を使い続ける | エラー時にストリームがリークする。`pipeline` を使う |
| `UV_THREADPOOL_SIZE` を変更せず bcrypt を多用 | スレッドプール枯渇でレイテンシ急増。コア数に合わせて増やす |
| 同期 I/O をミドルウェアや起動処理だけに限定しない | 起動時のみ許容。リクエストハンドラ内での同期 I/O は原則禁止 |
