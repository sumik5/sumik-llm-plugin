# PROJECT-SCAFFOLDING.md — Node.js プロジェクト構築パターン

Node.js サービスを始める際の「ゼロから実動環境まで」の標準手順を整理する。
プロジェクトの規模・チームの事情に応じたディレクトリ構成、`package.json` スクリプト設計、
モダン Node 構文の活用方法、そして Dockerfile の基本を扱う。

---

## 1. プロジェクトの初期化（`npm init`）

### 概念

`npm init` はプロジェクトの**マニフェストファイル（`package.json`）**を生成するコマンドだ。
このファイルは名前・バージョン・依存関係・スクリプトを一元管理し、チームメンバーや
ビルドツールがプロジェクトを正しく理解・操作できるようにする。

### 汎用パターン

```bash
mkdir my-service && cd my-service
npm init -y
```

`-y` フラグで全デフォルト値を自動受理し、すぐに開発へ移れる。生成後に必要なフィールドだけ
手動編集する。

**命名規則**: プロジェクト名は小文字＋ハイフン区切り（例: `my-api-server`）。
大文字・アンダースコア・特殊文字は npm レジストリや URL との互換性を損なうため避ける。

### 最小コード例

初期化直後の `package.json`（ESM 対応・開発サーバー付き）:

```json
{
  "name": "my-service",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "start": "node src/index.js",
    "dev":   "node --watch src/index.js"
  },
  "dependencies": {},
  "devDependencies": {}
}
```

- `"type": "module"` — `import`/`export` 構文が使える（ESM モード）。
- `--watch` フラグ — Node 20+ でビルトイン提供。ファイル変更時にプロセスを自動再起動
  （外部パッケージ `nodemon` が不要になる）。

### 落とし穴

| 罠 | 回避策 |
|----|--------|
| `"type"` フィールドを省略 → CommonJS（`require`）モードのまま | `"type": "module"` を明示して ESM に統一する |
| `package-lock.json` をリポジトリから除外 | ロックファイルは**コミット必須**（チーム間の依存バージョンを固定する） |
| `dev` スクリプトを本番で誤用 | `start`（本番・`--watch` なし）と `dev`（開発・`--watch` 付き）を明確に分ける |

---

## 2. スケール別ディレクトリ構成

### 概念

プロジェクトの複雑度に合わせてディレクトリ構成を段階的に育てる。
最初から過剰な構成は保守コストを増やし、単一ファイルへの肥大化は可読性を損なう。

### パターン A — 小規模（スクリプト・単一 API）

```
my-service/
├── index.js
└── package.json
```

CLI ツール・単機能スクリプト・実験的なサーバーに適する。テスト層や設定ファイルが
まだ不要なフェーズで使う。

### パターン B — 中規模（API・Fastify サービス）

```
my-service/
├── src/
│   └── index.js
├── test/
├── .env
├── .gitignore
├── package.json
└── README.md
```

本番を意識した Fastify サービスの標準レイアウト。`src/` にアプリロジックを集約し、
`test/` にユニット/統合テストを置く。`.env` に秘匿情報を書き、`.gitignore` でコミット
対象から除外する。

### パターン C — 大規模（フルスタック・マイクロサービス）

```
my-service/
├── src/
│   ├── server/
│   └── client/
│       ├── components/
│       └── index.html
├── public/
├── config/
├── scripts/
├── test/
├── .env
├── .gitignore
├── package.json
└── README.md
```

バックエンド（`src/server/`）とフロントエンドを同一リポジトリで管理するフルスタック構成。
`config/` に環境別設定、`scripts/` にデプロイ・自動化スクリプトを置く。

### 規模判断表

| 条件 | 推奨パターン |
|------|-------------|
| スクリプト・CLI ツール・PoC | A |
| REST API・Fastify サービス（単体） | B |
| フルスタック・複数サービス | C |

---

## 3. `package.json` スクリプト設計

### 概念

`scripts` フィールドはプロジェクトの**ユニファイド CLI** として機能する。
長いコマンドを短いエイリアスにまとめ、チーム全員が `npm run <task>` で一貫した操作を行える。

### 汎用パターン（拡張版）

```json
{
  "scripts": {
    "start":  "node src/index.js",
    "dev":    "node --watch src/index.js",
    "test":   "vitest run",
    "lint":   "eslint src",
    "format": "prettier --write src"
  }
}
```

| スクリプト | 役割 |
|-----------|------|
| `start`  | 本番エントリーポイント。ファイル監視なし |
| `dev`    | 開発用。変更を即検知して再起動 |
| `test`   | テストランナーを起動（`npm test` でも実行可） |
| `lint`   | 構文・スタイルチェック。CI でも同じコマンドを使う |
| `format` | コードフォーマット。コミット前に実行する |

### 高度なフィールド

```json
{
  "engines": { "node": ">=20" },
  "exports": { ".": "./src/index.js" }
}
```

- `engines` — 対応 Node バージョンを宣言。意図しないバージョンでの実行を防ぐ。
- `exports` — パッケージのエントリーポイントを明示。ESM 環境での tree-shaking に有効。
- `workspaces` — モノレポ構成でサブパッケージを一元管理する。

---

## 4. モダン Node 構文パターン（Node 18–20+）

### 4.1 ESM（ES Modules）

`"type": "module"` を設定すると `import`/`export` をそのまま使える。

```js
// 標準ライブラリは "node:" プレフィックスを推奨（npm パッケージとの衝突を防ぐ）
import fs   from 'node:fs/promises';
import path from 'node:path';

// サードパーティパッケージ
import Fastify from 'fastify';
```

### 4.2 Top-level `await`

ESM モードではファイルのトップレベルで `await` を使える（`async` 関数で包む必要がない）。

```js
// src/index.js（ESM）
import fs from 'node:fs/promises';
import Fastify from 'fastify';

const config = JSON.parse(await fs.readFile('./config.json', 'utf-8'));
const app = Fastify({ logger: true });
await app.listen({ port: config.PORT ?? 3000 });
```

エントリーファイルでの設定読み込みやサーバー起動が簡潔に書ける。

### 4.3 `node --watch`（Node 18+）

```bash
# 開発時のみ使用
node --watch src/index.js
```

ファイル変更のたびにプロセスを再起動する。`nodemon` への依存を排除できる。
本番の `start` スクリプトには含めない。

### 4.4 native `fetch`（Node 18+）

```js
// node-fetch 等の外部ライブラリ不要
const res  = await fetch('https://api.example.com/items');
const data = await res.json();
```

ブラウザと同じ Fetch API がグローバルに使える。

### 4.5 デストラクチャリング・オプショナルチェーン・Nullish 合体

```js
// 環境変数のデフォルト値
const { PORT = 3000, HOST = '127.0.0.1' } = process.env;

// 深いネストへの安全アクセス（?. は undefined を返す。?? は null/undefined のときフォールバック）
const username = req.user?.profile?.name ?? 'anonymous';
```

`??` は `null`/`undefined` のみフォールバックし、`0` や `""` はフォールバックしない（`||` との違い）。

### 落とし穴

| 状況 | 問題 | 対策 |
|------|------|------|
| ESM で `__dirname` を使う | ESM では `__dirname` が未定義 | `new URL('.', import.meta.url).pathname` で代替する |
| `--watch` を本番で使う | ソース変更で即再起動し安定性を損なう | 本番の `start` スクリプトには含めない |
| `import` と `require` を混在 | ESM と CJS の混在でエラーが発生する | `"type": "module"` を設定して ESM に統一する |

---

## 5. Yarn vs npm

| 項目 | npm | Yarn v4 |
|------|-----|---------|
| デフォルト提供 | ✅（Node に同梱） | ❌（Corepack で有効化） |
| ロックファイル | `package-lock.json` | `yarn.lock` |
| PnP（Plug'n'Play） | ❌ | ✅（`node_modules` を省略可） |
| Zero Install | ❌ | ✅（依存をリポジトリにコミット） |
| 採用率 | 高い | 中程度（大規模チームで実績） |
| 有効化 | — | `corepack enable && yarn init -2` |

**推奨**: 特別な要件がなければ npm を使う。Yarn は高速インストールや
Zero Install を必要とするモノレポ等で選択肢になる。
チーム内では 1 つのパッケージマネージャーに統一し、ロックファイルを混在させない。

---

## 6. Node 固有 Dockerfile パターン

> コンテナ設計の詳細（マルチステージビルド・Compose・本番最適化）は
> `cloud:practicing-devops` を参照すること。

### 最小 Dockerfile（Node サービス用）

```dockerfile
FROM node:20-slim

WORKDIR /usr/src/app

# 依存ファイルを先にコピー → アプリコード変更でキャッシュを再利用できる
COPY package*.json ./
RUN npm ci --omit=dev

COPY . .

EXPOSE 3000
CMD ["npm", "start"]
```

**Node 固有の要点**:

| 項目 | 理由 |
|------|------|
| `node:20-slim` | `node:20` より軽量（不要なシステムツールを除外） |
| `package*.json` を先にコピー | アプリコードが変わっても npm install 層をキャッシュできる |
| `npm ci` | `package-lock.json` を厳密に使用。`npm install` より再現性が高い |
| `--omit=dev` | `devDependencies` をインストールしない（本番イメージを最小化） |

### `.dockerignore`

```
node_modules
npm-debug.log
.env
.git
```

`node_modules` を除外するとビルドコンテキストが大幅に削減できる。
`.env` をイメージに含めないことで秘匿情報の漏洩を防ぐ。
