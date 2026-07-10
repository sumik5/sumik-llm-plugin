# メッセージングとキュー

Node.js サービスでワークロードをオフロードし、スケーラビリティと信頼性を高めるためのキューパターン。
重い処理や非同期タスクをキューで分離し、サービス間の非同期通信を実現する。

---

## なぜキューが必要か

Node.js のイベントループは非同期 I/O を効率的に処理するが、以下の場面で応答遅延やクラッシュが起きる:

- **CPU バウンドな同期処理**（重い計算・画像処理）がイベントループをブロック
- **リクエストのバースト**（急増するリクエスト量）がサーバーを圧迫
- **処理中クラッシュ**でインメモリのタスクが消失

キュー導入による改善:

```
従来: クライアント → Fastify → 処理（ブロック）→ レスポンス（遅延）
改善: クライアント → Fastify → キューに積む → 即レスポンス
                                  ↓
                            コンシューマーがキューから取り出して処理
```

---

## キュー技術の選択

> **AskUserQuestion 配置箇所**

以下の問いでキュー技術を選択する:

```
Q1. クラッシュ後もメッセージを失いたくないか？
  ┣ No（試作・開発環境・単一プロセス内）→ インメモリ配列（最小構成）
  ┗ Yes → Q2 へ

Q2. 複数のサービスへメッセージをルーティングしたいか？
  ┣ No（シンプルな 1 対 1 通信・リアルタイム通知）→ Redis Pub/Sub
  ┗ Yes（サービス連鎖・メッセージ確認応答（ACK）必須・高信頼性）→ RabbitMQ / amqplib
```

| 技術 | 永続化 | ルーティング | ACK | 難易度 | 代表的な用途 |
|------|--------|------------|-----|--------|------------|
| インメモリ配列 | ❌（揮発） | ❌ | ❌ | 低 | 試作・単一プロセス内の処理分離 |
| Redis Pub/Sub | △（設定依存） | チャンネル名で分岐 | ❌ | 中 | リアルタイム通知・シンプルなファンアウト |
| RabbitMQ / amqplib | ✅ | Exchange・Routing Key | ✅ | 高 | 本番サービス間連携・確実なメッセージ配達 |

> **ツール利用不可環境向け代替質問**:
> 「耐障害性が必要か（→ Redis か RabbitMQ）、複数サービスへのルーティングが必要か（→ RabbitMQ）、まず試作したいか（→ インメモリ）？」

---

## インメモリキューパターン

JavaScript の Array を FIFO（先入れ先出し）キューとして利用する最小実装。

```js
import Fastify from 'fastify';
import fastifyFormbody from '@fastify/formbody';

const app = Fastify({ logger: true });
await app.register(fastifyFormbody);

// アプリケーションスコープのキュー
const taskQueue = [];

// タスクをキューに積む（enqueue）
app.post('/tasks', async (req, reply) => {
  const { task } = req.body;
  taskQueue.push(task);                    // 末尾に追加
  return reply.send({
    accepted: task,
    queueLength: taskQueue.length,
  });
});

// キューの先頭からタスクを取り出して処理（dequeue）
app.get('/process', async (req, reply) => {
  const next = taskQueue.shift();          // 先頭から取り出し
  if (!next) {
    return reply.send({ message: 'キューが空です' });
  }
  // 処理ロジック...
  return reply.send({ processed: next });
});

// キューの長さを確認
app.get('/queue-count', async (req, reply) => {
  return reply.send({ count: taskQueue.length });
});

await app.listen({ port: 3000 });
```

**制約**:
- プロセス終了でキューの内容が消える
- 複数プロセスやサーバー間でキューを共有できない
- 手動で処理をトリガーする必要がある

---

## Redis Pub/Sub パターン

Redis を介したプロデューサー / サブスクライバーモデル。チャンネル名でメッセージを分類し、リアルタイムに配信する。

### インストール

```bash
npm install redis
```

### クライアントの準備

```js
import { createClient } from 'redis';

// publish と subscribe は別クライアントが必須
const publisher  = createClient();
const subscriber = createClient();

await publisher.connect();
await subscriber.connect();
```

### チャンネルの購読と発行

```js
// サブスクライバー側: チャンネルを購読してメッセージを受信
await subscriber.subscribe('orders', (message) => {
  const order = JSON.parse(message);
  console.log(`受信: ${order.item} × ${order.qty}`);
  // 処理ロジック...
});

// プロデューサー側: チャンネルへメッセージを発行
await publisher.publish('orders', JSON.stringify({
  item: 'コーヒー',
  qty: 2,
  orderedAt: Date.now(),
}));
```

### Fastify ルートからメッセージを発行

```js
app.post('/orders', async (req, reply) => {
  const { item, qty } = req.body;
  await publisher.publish('orders', JSON.stringify({ item, qty }));
  return reply.send({ status: 'queued' });
});
```

**Redis Pub/Sub の限界**:
- クライアントが切断中のメッセージは届かない（メッセージは揮発する）
- ペイロードは文字列のみ（JSON.stringify / JSON.parse で対応）
- Pub/Sub はシングルスレッドで動作するため大量メッセージに注意

---

## RabbitMQ / amqplib パターン

複数サービス間の信頼性の高いメッセージング。ACK（確認応答）まではキューにメッセージが残り、障害時でも再配信される。

### インストール

```bash
npm install amqplib
```

複数サービス構成では各サービスに異なる `PORT`（例: 3000/3001/3002）を `process.env.PORT` で設定する。

### RabbitMQ 接続と初期化

```js
import amqp from 'amqplib';

let connection, channel;

async function connectQueue() {
  try {
    // RabbitMQ はデフォルトポート 5672 で AMQP を待ち受ける
    connection = await amqp.connect('amqp://localhost:5672');
    channel = await connection.createChannel();

    // キューが存在しなければ自動作成。存在する場合は再利用
    await channel.assertQueue('task-queue');
  } catch (err) {
    console.error('RabbitMQ 接続エラー:', err);
    process.exit(1);
  }
}

await connectQueue();
```

### メッセージ送信（producer）

```js
// データを Buffer に変換してキューへ送信
async function enqueue(queueName, data) {
  const payload = Buffer.from(JSON.stringify(data));
  channel.sendToQueue(queueName, payload);
}

// Fastify ルートからキューへ送信
app.post('/tasks', async (req, reply) => {
  const { task, userId } = req.body;
  await enqueue('task-queue', { task, userId, createdAt: Date.now() });
  return reply.send({ status: 'accepted' });
});
```

### メッセージ消費（consumer）と ACK

```js
channel.consume('task-queue', async (msg) => {
  if (!msg) return;

  const data = JSON.parse(msg.content.toString());
  console.log(`処理中: ${data.task} for userId ${data.userId}`);

  try {
    // 処理ロジック...

    // 成功 → ACK でキューからメッセージを削除
    channel.ack(msg);
  } catch (err) {
    // 失敗 → NACK で再キュー（true = requeue）
    // 無限ループ防止のためリトライ回数を管理すること
    channel.nack(msg, false, true);
  }
});
```

### サービス連鎖パターン（task-queue → analytics-queue）

```js
// worker_service: task-queue を消費し analytics-queue へ転送
channel.consume('task-queue', async (msg) => {
  const data = JSON.parse(msg.content.toString());

  // 処理ロジック...
  console.log(`処理完了: ${data.task}`);
  channel.ack(msg);

  // 次のサービスへデータを転送
  channel.sendToQueue(
    'analytics-queue',
    Buffer.from(JSON.stringify(data))
  );
});
```

```js
// analytics_service: analytics-queue を消費して集計
const tally = {};

channel.consume('analytics-queue', (msg) => {
  const { task } = JSON.parse(msg.content.toString());
  tally[task] = (tally[task] ?? 0) + 1;
  console.log('集計:', tally);
  channel.ack(msg);
});
```

### キューの耐障害性設定

```js
// durable: true でサーバー再起動後もキュー定義が残る
await channel.assertQueue('task-queue', { durable: true });

// persistent: true でメッセージをディスクに永続化
channel.sendToQueue(
  'task-queue',
  Buffer.from(JSON.stringify(data)),
  { persistent: true }
);
```

---

## 落とし穴

| 症状 | 原因 | 対処 |
|------|------|------|
| Redis `subscribe` 後に他コマンドが失敗する | `subscribe` 中のクライアントは他のコマンドを実行できない | publisher と subscriber は必ず別クライアントを用意する |
| RabbitMQ のメッセージがキューに溜まり続ける | `channel.ack(msg)` の呼び忘れ | 処理完了後は必ず `ack`。エラー時は `nack(msg, false, true)` で再キュー |
| RabbitMQ 再接続後にチャンネルが無効 | チャンネルはコネクション依存で、コネクション切断で無効化される | `amqplib-connection-manager` 等の再接続ライブラリを導入するか、接続エラーイベントでプロセスを再起動 |
| インメモリキューが複数プロセス間で共有できない | 各 Node.js プロセスのメモリは独立 | クラスター・マルチサーバー構成が必要になったら Redis か RabbitMQ へ移行 |
| RabbitMQ 再起動でメッセージが消える | デフォルトキューは非永続 | `{ durable: true }` + `{ persistent: true }` を明示的に指定する |
| サービス間のポート競合 | 複数サービスが同じ `PORT` を使う | 各サービスに異なる `PORT`（例: 3000/3001/3002）を `process.env.PORT` で設定 |

---

## スコープ外・関連スキル

- Kafka・Amazon SQS 等の大規模分散メッセージングの設計判断 → `web:choosing-api-styles`
- Redis の詳細な設定・永続化・クラスタリング → `lang:developing-databases`
- RabbitMQ / Kafka の本番インフラ構成・コンテナ化 → `cloud:practicing-devops`
