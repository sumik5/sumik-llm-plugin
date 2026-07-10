# データ永続化パターン

Node サービスで利用できる主要な永続化ストアの接続・操作パターンと、技術選択の判断基準。

---

## 1. 概念 — SQL vs NoSQL vs キャッシュ層

### データ構造の3分類

| 分類 | 代表ストア | 格納単位 | 特徴 |
|------|-----------|---------|------|
| リレーショナル SQL | PostgreSQL / SQLite | 行（テーブル） | 固定スキーマ・ACID・JOIN |
| ドキュメント NoSQL | MongoDB / Mongoose | ドキュメント（JSON） | 柔軟スキーマ・水平スケール |
| インメモリ KV | Redis | キー・バリュー | 超高速・揮発性がデフォルト |

### 語彙対応表

| 概念 | SQL | NoSQL (MongoDB) |
|------|-----|----------------|
| スキーマ定義 | テーブル定義（CREATE TABLE） | Mongoose モデル定義 |
| 行の集合 | テーブル | コレクション |
| 1レコード | 行（row） | ドキュメント |
| 一意識別子 | 主キー (id) | ObjectId |

---

## 2. MongoDB / Mongoose

### 接続パターン

Mongoose は MongoDB 公式ドライバーの上位 ORM で、スキーマ・バリデーション・ミドルウェアを提供する。

```js
// db/mongo.js
import mongoose from 'mongoose';

const MONGO_URI = process.env.MONGO_URI ?? 'mongodb://localhost:27017/myapp';

export async function connectMongo() {
  await mongoose.connect(MONGO_URI);
  console.log('MongoDB connected');
}
```

アプリ起動時に一度だけ呼ぶ。接続は内部でプールされる。

### モデル定義と CRUD

```js
// models/article.js
import mongoose from 'mongoose';

const articleSchema = new mongoose.Schema({
  title:     { type: String, required: true, unique: true },
  body:      { type: String, required: true },
  published: { type: Boolean, default: false },
}, { timestamps: true });  // createdAt / updatedAt 自動付与

export const Article = mongoose.model('Article', articleSchema);
```

```js
// 作成
const article = await Article.create({ title: 'Hello', body: 'World' });

// 取得 (単一)
const found = await Article.findById(article._id);

// 更新
await Article.findByIdAndUpdate(article._id, { published: true });

// 削除
await Article.findByIdAndDelete(article._id);
```

### 落とし穴

| 状況 | 問題 | 対処 |
|------|------|------|
| 未接続で `find` を呼ぶ | `MongoNotConnectedError` | `connectMongo()` を `listen` 前に `await` する |
| 同じ `unique` フィールドを二重登録 | `MongoServerError: E11000` | `try/catch` で `err.code === 11000` を捕捉してユーザーへ 409 応答 |
| `findByIdAndUpdate` の返り値 | デフォルトは更新前のドキュメント | `{ returnDocument: 'after', new: true }` オプションを付ける |
| スキーマにないフィールドを保存 | 黙って無視される | `strict: true`（デフォルト）を変えない・必要フィールドをすべて定義 |

---

## 3. PostgreSQL / Sequelize

### 接続パターン

Sequelize は PostgreSQL・MySQL・SQLite に対して同一 API を提供する ORM。

```js
// db/postgres.js
import { Sequelize } from 'sequelize';

export const db = new Sequelize(
  process.env.DATABASE_URL ?? 'postgres://user:pass@localhost:5432/myapp',
  { logging: false }  // SQL ログが不要な場合
);

export async function connectPostgres() {
  await db.authenticate();
  console.log('PostgreSQL connected');
}
```

### モデル定義と CRUD

```js
// models/user.js
import { DataTypes } from 'sequelize';
import { db } from '../db/postgres.js';

export const User = db.define('User', {
  username: { type: DataTypes.STRING, allowNull: false, unique: true },
  email:    { type: DataTypes.STRING, allowNull: false },
  hash:     { type: DataTypes.TEXT,   allowNull: false },
  salt:     { type: DataTypes.STRING, allowNull: false },
});

await User.sync();  // テーブルが存在しなければ作成
```

```js
// 作成
const user = await User.create({ username: 'alice', email: 'a@example.com',
                                  hash: '...', salt: '...' });

// 条件検索
const found = await User.findOne({ where: { username: 'alice' } });

// 更新 (返り値: 更新件数)
const [count] = await User.update({ email: 'new@example.com' },
                                    { where: { id: user.id } });

// 削除
await User.destroy({ where: { id: user.id } });
```

### Sequelize.Model を継承したクラス構成

アカウント管理など複雑なドメインでは `Model` を `extend` してメソッドを持たせる:

```js
import { Model, DataTypes } from 'sequelize';
import { db } from '../db/postgres.js';

class Account extends Model {
  static async findByUsername(username) {
    return this.findOne({ where: { username: username.toLowerCase() } });
  }
}

Account.init(
  {
    username: { type: DataTypes.STRING, allowNull: false, unique: true },
    hash:     { type: DataTypes.TEXT,   allowNull: false },
    salt:     { type: DataTypes.STRING, allowNull: false },
  },
  { sequelize: db, modelName: 'Account' }
);

Account.beforeCreate(account => {
  account.username = account.username.toLowerCase();
});

await Account.sync();
export default Account;
```

### 落とし穴

| 状況 | 問題 | 対処 |
|------|------|------|
| `sync({ force: true })` を本番で実行 | テーブルを DROP & 再作成 → データ消失 | 本番では `sync()` を使わずマイグレーションツールを使う |
| `UPDATE` / `DELETE` の返り値 | 更新・削除されたレコード自体ではなく件数 | 事前に `findOne` → 操作 → 返却する手順を踏む |
| `createdAt` / `updatedAt` 自動付与 | 不要な場合も列ができる | `{ timestamps: false }` で無効化 |

---

## 4. SQLite3 / Sequelize（SQLite ダイアレクト）

SQLite はサーバー不要のファイル DB。単一プロセスの書き込みしか許容しないが、プロトタイピングや CLI ツールには最適。

```js
// db/sqlite.js
import { Sequelize, DataTypes } from 'sequelize';

export const db = new Sequelize({
  dialect: 'sqlite',
  storage: './db/app.sqlite',  // ファイルパス
  logging: false,
});

await db.authenticate();
```

`Sequelize` の操作 API は PostgreSQL と完全に同じ。ダイアレクトを変えるだけで切り替え可能。

### `better-sqlite3` — ORM 不要の軽量同期ドライバー

```js
import Database from 'better-sqlite3';
const db = new Database('./db/tasks.sqlite');

db.exec(`
  CREATE TABLE IF NOT EXISTS tasks (
    id   INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    done  INTEGER DEFAULT 0
  )
`);

const insert = db.prepare('INSERT INTO tasks (title) VALUES (?)');
insert.run('Write tests');

const rows = db.prepare('SELECT * FROM tasks').all();
```

同期 API なのでシンプルだが、I/O 集中するサービスには不向き。

---

## 5. Redis — インメモリキャッシュ・セッションストア

Redis はデフォルトでオンメモリ（再起動でクリア）。永続化には AOF / RDB を有効化する。

### 接続

```js
// db/redis.js
import Redis from 'ioredis';

export const redis = new Redis({
  host: process.env.REDIS_HOST ?? 'localhost',
  port: 6379,
});
```

### 基本操作

```js
// 文字列 (セッション・設定値)
await redis.set('session:abc123', JSON.stringify({ userId: 42 }), 'EX', 3600);
const raw = await redis.get('session:abc123');
const session = JSON.parse(raw);

// TTL 確認
const ttl = await redis.ttl('session:abc123');  // 残り秒数

// ハッシュ (ユーザーのメタ情報)
await redis.hset('user:42', 'name', 'Alice', 'plan', 'pro');
const name = await redis.hget('user:42', 'name');

// 削除
await redis.del('session:abc123');
```

### キャッシュパターン

```js
async function getProfile(userId) {
  const cached = await redis.get(`profile:${userId}`);
  if (cached) return JSON.parse(cached);

  const profile = await User.findByPk(userId);  // DB クエリ
  await redis.set(`profile:${userId}`, JSON.stringify(profile), 'EX', 300);
  return profile;
}
```

### 落とし穴

| 状況 | 問題 | 対処 |
|------|------|------|
| `set` に `EX` を付けない | キーが永遠に残りメモリを圧迫 | 必ず有効期限を設定する |
| JSON を文字列化せずに `set` | オブジェクトが `"[object Object]"` になる | `JSON.stringify` / `JSON.parse` を明示する |
| Redis 未起動で接続 | サイレントに失敗し `null` を返すことがある | ヘルスチェックを起動時に実行 |
| 永続化なしで再起動 | セッションデータが消える | AOF または RDB を有効化、またはセッションを DB と併用 |

---

## 6. 永続化レイヤ選択の判断フロー

```
プロジェクトの要件を確認する
│
├── プロトタイプ / CLI ツール / 単一プロセス
│   → SQLite（ファイル 1 本・セットアップゼロ）
│
├── 本番 RDB が必要・テーブル結合・ACID 保証
│   → PostgreSQL + Sequelize
│
├── スキーマが頻繁に変化・JSON 中心・水平スケール予定
│   → MongoDB + Mongoose
│
└── キャッシュ・セッション・一時データ・メッセージキュー
    → Redis（メインDBと併用）
```

### 選択基準まとめ

| 観点 | SQLite | PostgreSQL | MongoDB | Redis |
|------|--------|-----------|---------|-------|
| セットアップ | ゼロ（ファイル） | サーバー必要 | サーバー必要 | サーバー必要 |
| スキーマ柔軟性 | 低 | 低〜中 | 高 | なし（KV） |
| クエリ能力 | 中 | 高（JOIN・集計） | 中（JSON） | 低（KV操作） |
| 本番スケール | 低（単一ライター） | 高 | 高 | 高 |
| 主用途 | プロト・CLI | 構造化データ・API | 柔軟ドキュメント | キャッシュ |

> DB スキーマ設計・正規化・インデックス戦略の深掘りは `lang:developing-databases` を参照。
> 本番環境のコンテナ化・Cloud DB 接続設定は `cloud:practicing-devops` を参照。

---

## 7. AskUserQuestion — 永続化レイヤ選択

プロジェクトの永続化要件が明確でない場合は、実装を始める前に以下を確認する。

```
【永続化レイヤの選択を確認します】

1. SQLite（ファイル1本・サーバー不要・プロトタイプ/CLIに最適）
2. PostgreSQL + Sequelize（本番 RDB・JOIN・ACID・高スケール）
3. MongoDB + Mongoose（柔軟スキーマ・JSON中心・水平スケール予定）
4. Redis（キャッシュ・セッション・一時データ・メインDBと併用）
5. 複数を組み合わせる（例: PostgreSQL + Redis）

→ 対象のユースケース・スケール要件・チームの技術スタックを教えてください。
```

> **Codex / ツール呼び出し非対応環境**: 上記テキスト質問を会話メッセージとして送信し、
> 回答をもとに該当セクションのパターンを適用してください。

---

## 8. ローカル vs クラウド DB

| 環境 | MongoDB | PostgreSQL | SQLite |
|------|---------|-----------|--------|
| ローカル開発 | `mongod --dbpath` | `pg_ctl start` | ファイル作成のみ |
| クラウドマネージド | MongoDB Atlas | Amazon RDS / Supabase / Cloud SQL | Cloudflare D1 / Turso（エッジ向け） |

クラウド接続は環境変数で接続文字列を管理し、コードに認証情報をハードコードしない:

```js
const db = new Sequelize(process.env.DATABASE_URL, { logging: false });
```
