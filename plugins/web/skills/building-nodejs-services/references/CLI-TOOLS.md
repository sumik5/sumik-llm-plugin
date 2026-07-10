# CLI-TOOLS — Node.js コマンドラインツール構築

Node.js 組み込みモジュールと外部パッケージを組み合わせて、対話型 CLI アプリケーションを実装する実践ガイド。
`process` ストリームを起点に、コールバック非同期の Promise 化・CSV 変換・外部パッケージへの移行まで体系化する。

---

## 1. `process` 標準入出力

### 概念

| プロパティ | 型 | 役割 |
|---|---|---|
| `process.stdin` | `Readable` | 端末（またはパイプ）からの入力 |
| `process.stdout` | `Writable` | 端末への出力 |
| `process.stderr` | `Writable` | エラー出力 |

これらはイベントループと統合された非同期ストリームであり、`readline` や `prompt` はこのストリームをラップした高レベル抽象。

### `process.argv` — コマンドライン引数

```js
// node cli.mjs --name Alice
// process.argv = ['node', 'cli.mjs', '--name', 'Alice']
const args = process.argv.slice(2); // 先頭 2 要素（node, スクリプトパス）を除く
```

複雑なフラグ解析には `commander` や `yargs` が宣言的で便利。

### `process.exit()` — 終了コード

```js
process.exit(0); // 正常
process.exit(1); // エラー（CI でキャッチさせる場合）
```

---

## 2. `readline` モジュールによる対話型入力

### 概念

`readline` は `process.stdin` / `process.stdout` を `createInterface` でラップし、行単位入力を提供する追加インストール不要の組み込みモジュール。

### Promise ラッパーパターン

```js
import { createInterface } from "readline";

const rl = createInterface({ input: process.stdin, output: process.stdout });
const ask = (prompt) => new Promise((resolve) => rl.question(prompt, resolve));

const name = await ask("Your name: ");
console.log(`Hello, ${name}!`);
rl.close(); // 必ず閉じる（閉じないとプロセスがハングする）
```

### 落とし穴

| 症状 | 原因 | 対策 |
|------|------|------|
| プロセスが終了しない | `rl.close()` 忘れ | `finally` ブロックで確実に呼ぶ |
| パイプ入力が取れない | EOF 検知の問題 | `rl.on('close')` を監視する |

---

## 3. `promisify` — コールバック API の Promise 化

### 概念

`util.promisify` はエラーファーストコールバック `(err, result) => void` 形式の関数を Promise 化し、`async/await` で扱えるようにする。

```js
import { promisify } from "util";
import { readFile } from "fs";

const readFileAsync = promisify(readFile);
const content = await readFileAsync("./data.txt", "utf8");
```

### `readline.question` への適用

```js
import { createInterface } from "readline";
import { promisify } from "util";

const rl = createInterface({ input: process.stdin, output: process.stdout });
const question = promisify(rl.question).bind(rl); // bind(rl) で this を固定

try {
  const answer = await question("Input: ");
  console.log(`Got: ${answer}`);
} finally {
  rl.close();
}
```

> **`bind(rl)` が必要な理由**: `promisify` は関数参照のみを取るため `this` コンテキストが失われる。

### 適用条件

- コールバック引数が `(err, value)` のエラーファースト形式であること
- コールバックが最後の引数であること（満たさない場合は `new Promise(...)` で手動ラップ）

---

## 4. ファイルシステム操作（`fs` モジュール）

### CSV への追記パターン

```js
import { appendFileSync, existsSync, writeFileSync } from "fs";

// ファイルが無ければヘッダー行を先に書く
if (!existsSync("./output.csv")) {
  writeFileSync("./output.csv", "name,email\n", "utf8");
}

const saveLine = (data) => {
  const line = `${data.name},${data.email}\n`;
  try {
    appendFileSync("./output.csv", line, "utf8");
  } catch (err) {
    console.error("Write error:", err.message);
    process.exit(1);
  }
};
```

### 落とし穴

| 症状 | 原因 | 対策 |
|------|------|------|
| 追記ではなく上書きされる | `writeFileSync` を使用 | 追記は `appendFileSync` または `{ flag: "a" }` |
| 文字化け | エンコーディング未指定 | 第 3 引数に `"utf8"` を明示 |
| サーバーがブロックされる | `*Sync` を使用 | サーバー内では `fs/promises` の非同期版を使う |

---

## 5. CSV 変換パターン

### 5.1 手動フォーマット（依存なし）

```js
const toCSVLine = (fields) =>
  fields.map((f) => (String(f).includes(",") ? `"${f}"` : f)).join(",");

appendFileSync("./out.csv", toCSVLine(["Alice", "alice@example.com"]) + "\n");
```

### 5.2 `csv-writer` パッケージ（ヘッダー付き・型安全）

```js
import { createObjectCsvWriter } from "csv-writer";

const writer = createObjectCsvWriter({
  path: "./contacts.csv",
  append: true,           // 既存ファイルへ追記（false で上書き）
  header: [
    { id: "name",  title: "NAME" },
    { id: "email", title: "EMAIL" },
  ],
});

await writer.writeRecords([{ name: "Alice", email: "alice@example.com" }]);
```

> `append: true` でもファイルが存在しない場合はヘッダー付き新規ファイルを作成する。2 回目以降はヘッダーなしで追記されるため重複の心配は不要。

---

## 6. 外部パッケージ（`prompt`）と選択基準

```js
import prompt from "prompt";

prompt.start();
prompt.message = "";

const schema = [
  { name: "name",  description: "Contact Name" },
  { name: "email", description: "Email Address",
    pattern: /\S+@\S+\.\S+/, message: "Valid email required" },
];

const responses = await prompt.get(schema);
```

### `readline` vs `prompt` の選択基準

| 観点 | `readline`（組み込み） | `prompt`（外部） |
|------|----------------------|----------------|
| 依存なし | ✅ | ❌ npm install 要 |
| バリデーション | 手動実装 | スキーマで宣言可 |
| 複数質問を一括収集 | 逐次 `await` が必要 | 配列で一括定義 |

---

## 7. 対話型 CLI の完全パターン

```js
import { createInterface } from "readline";
import { createObjectCsvWriter } from "csv-writer";

const rl = createInterface({ input: process.stdin, output: process.stdout });
const ask = (q) => new Promise((resolve) => rl.question(q, resolve));

const writer = createObjectCsvWriter({
  path: "./records.csv",
  append: true,
  header: [{ id: "name", title: "NAME" }, { id: "email", title: "EMAIL" }],
});

const run = async () => {
  let active = true;
  while (active) {
    const name  = await ask("Name: ");
    const email = await ask("Email: ");
    await writer.writeRecords([{ name, email }]);
    console.log(`Saved: ${name}`);
    const next = await ask("Continue? [y]: ");
    active = next.toLowerCase() === "y";
  }
  rl.close();
};

run().catch((err) => { console.error(err); rl.close(); process.exit(1); });
```

**ポイント**: `writer` はループ外で 1 度だけ初期化する（ループ内で都度 `createObjectCsvWriter` するとヘッダーが重複挿入される）。

---

## 8. 入力バリデーションパターン

```js
const askWithRetry = async (prompt, validate) => {
  while (true) {
    const input = await ask(prompt);
    const error = validate(input);
    if (!error) return input;
    console.error(`Invalid: ${error}`);
  }
};

// 使用例
const email = await askWithRetry(
  "Email: ",
  (v) => (/\S+@\S+\.\S+/.test(v) ? null : "Valid email required")
);
```

---

## 関連 references

| ファイル | 参照タイミング |
|---------|--------------|
| `NODE-RUNTIME-INTERNALS.md` | `process` ストリームとイベントループの詳細 |
| `EXTERNAL-DATA-INTEGRATION.md` | `fetch` / ファイル取得・スクレイピング |
| `PROJECT-SCAFFOLDING.md` | ESM 設定・`package.json` `scripts` への CLI 登録 |
| `QUALITY-CHECKLIST.md` | CLI を含む Node サービス全体の品質ゲート |
