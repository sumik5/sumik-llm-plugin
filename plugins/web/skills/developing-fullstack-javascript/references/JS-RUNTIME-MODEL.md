# JS-RUNTIME-MODEL — 非同期スケジューリングの内部機構

> **対象スコープ**: JavaScript ランタイムの**スケジューリング内部機構**に特化する。
> Promise/async-await の基本構文・チェーン・基礎的なエラーハンドリングは
> `JS-ASYNC-AND-MODULES.md` を参照（本ファイルでは重複させない）。

---

## 目次

1. [非同期の本質：コールスタックと実行コンテキスト](#1-非同期の本質コールスタックと実行コンテキスト)
2. [Promise の内部状態機械](#2-promise-の内部状態機械)
3. [マルチキューモデル](#3-マルチキューモデル)
4. [ランタイム間の非互換性](#4-ランタイム間の非互換性)
5. [マイクロタスクスターベーション](#5-マイクロタスクスターベーション)
6. [非同期スケジューリング制御の実践](#6-非同期スケジューリング制御の実践)

---

## 1. 非同期の本質：コールスタックと実行コンテキスト

非同期を「後で実行される」と定義するのは不正確だ。正確な定義は「**現在のコールスタックとは別の、新しいスタックで実行される**」こと。

```javascript
// 同期：コールバックはコールスタックを共有する
function processItems(items) {
  items.forEach(item => {
    console.log(item);  // processItems のスタック内で実行
  });
  console.log('done');  // a, b, c の後に出力
}

// 非同期：コールスタックが完全に空になってから実行
function processItems(items) {
  items.forEach(item => {
    setTimeout(() => console.log(item), 10);  // 別スタックで実行
  });
  console.log('done');  // 先に出力される
}
```

**コールスタック共有の影響**:

| 状態 | スタック | try/catch の有効範囲 | `this` の継承 |
|------|---------|---------------------|--------------|
| 同期コールバック | 呼び出し元と共有 | 有効 | 継承される |
| 非同期コールバック | 新規スタック（空から開始） | 無効（スタック消滅済み） | なし |

非同期コールバック内のエラーは `try/catch` で補足できない。これは Zalgo（同期・非同期が不定になるパターン）が危険な理由でもある。Promise はコールバックを**必ず**新しいスタックで実行することで、この不定性を排除する。

---

## 2. Promise の内部状態機械

Promise は内部に 3 つのスロットを持つ状態機械として定義されている。

```
              resolve(value)
┌─────────┐ ──────────────────► ┌───────────┐
│ pending │                     │ fulfilled │
└─────────┘ ──────────────────► └───────────┘
              reject(reason)
                               ┌───────────┐
                               │ rejected  │
                               └───────────┘

一度 settled になると状態は変化しない（不変）
```

| 内部スロット | 役割 | pending 時 | settled 後 |
|-------------|------|-----------|-----------|
| `[[PromiseState]]` | 現在の状態 | `"pending"` | `"fulfilled"` または `"rejected"` |
| `[[PromiseResult]]` | 結果値 / 拒否理由 | `undefined` | 解決値 / エラーオブジェクト |
| `[[PromiseReactions]]` | 待機中コールバックのリスト | reaction record が積まれる | 全 reaction が microtask としてエンキュー |

### `.then()` が行う処理（内部機構）

`.then()` は「コールバックをすぐ実行せよ」という命令ではなく、「reaction record を作成して `[[PromiseReactions]]` リストに追加せよ」という命令だ。

```javascript
const p = Promise.resolve(42);
p.then(x => console.log('first', x));
p.then(x => console.log('second', x));
p.then(x => console.log('third', x));
// → p はすでに resolved だが、3 つの reaction はすべてマイクロタスクとしてエンキューされる
//   現在のコールスタックが空になった後に順番に実行される
```

**`await` との等価性**:

```javascript
// これと
const result = await fetchUser();
console.log(result);

// これは機械的に等価
fetchUser().then((result) => {
  console.log(result);
});
```

`await` は `.then()` のシンタックスシュガー。スケジューリングコストは同一。

---

## 3. マルチキューモデル

### 3.1 なぜ複数のキューが存在するか

ECMAScript 仕様が定義するスケジューリング機構は**マイクロタスクキュー（Job queue）のみ**。`setTimeout`・`setImmediate`・`process.nextTick` はすべてプラットフォーム（Node.js / ブラウザ）が独自に追加したもの。

複数キューが存在する理由:
- **単一 FIFO キューでは優先度を表現できない** — タイマーコールバックより先に Promise reaction を実行したい
- **異なるスケジューリングニーズが後から追加された** — Node.js は Promise 登場前に `nextTick` を作り、ブラウザは描画サイクルに連動する `requestAnimationFrame` を必要とした
- **後方互換性のため統合できなかった** — `process.nextTick` を microtask queue に統合すると既存エコシステムが壊れる

### 3.2 ドレイン規則（全ランタイム共通）

```
┌─────────────────────────────────────────────────────────┐
│  1 マクロタスクを実行                                      │
│    ├─ 追加の マイクロタスク・マクロタスク をスケジュール可能  │
└────────────────────────────────┬────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────┐
│  マイクロタスクキューを「空になるまで」ドレイン              │
│    ├─ マイクロタスク内でさらにマイクロタスクをエンキュー可能 │
│    └─ それも含めてすべてが完了するまで次へ進まない          │
└────────────────────────────────┬────────────────────────┘
                                 │
                                 ▼
                        次のマクロタスクへ（繰り返し）
```

**実行順序の確認**:

```javascript
setTimeout(() => console.log('timeout'), 0);
Promise.resolve().then(() => console.log('promise'));
console.log('sync');

// 出力（全ランタイム共通）:
// sync
// promise
// timeout
```

**マイクロタスク内でマクロタスクをスケジュールした場合**:

```javascript
setTimeout(() => {
  console.log('task 1');
  Promise.resolve().then(() => console.log('microtask from task 1'));
}, 0);

setTimeout(() => {
  console.log('task 2');
}, 0);

Promise.resolve().then(() => {
  console.log('microtask 1');
  setTimeout(() => console.log('task from microtask'), 0);
});

// 出力:
// microtask 1
// task 1
// microtask from task 1
// task 2
// task from microtask
```

リズムは「マクロタスク実行 → マイクロタスクをドレイン → マクロタスク実行 → …」。

### 3.3 スケジューリング API とキューの対応表

| API | キュー種別 | Node.js | ブラウザ | Deno | Bun | Workers |
|-----|----------|---------|---------|------|-----|---------|
| `process.nextTick` | pre-microtask（専用キュー） | ✓ | — | ✓（compat） | ✓（compat） | compat |
| `queueMicrotask` | microtask | ✓ | ✓ | ✓ | ✓ | ✓ |
| `Promise.then` / `await` | microtask | ✓ | ✓ | ✓ | ✓ | ✓ |
| `setTimeout` | macrotask / timer | ✓ | ✓ | compat | compat | compat |
| `setImmediate` | macrotask / check | ✓ | — | compat | compat | compat |
| `requestAnimationFrame` | pre-paint（描画前） | — | ✓ | — | — | — |
| `requestIdleCallback` | idle | — | ✓ | — | — | — |

**標準化されているのは `queueMicrotask` と `Promise.then` のみ**。それ以外はランタイム独自実装。

---

## 4. ランタイム間の非互換性

### 4.1 `process.nextTick` の実装差異

Node.js の `nextTick` は**専用の pre-microtask キュー**に入り、Promise microtask より先にドレインされる。

```javascript
const resolvedPromise = Promise.resolve(2);
resolvedPromise.then((val) => console.log(val));  // 2番目
process.nextTick(() => console.log(1));             // 1番目（Node.js のみ）
```

Cloudflare Workers は `process.nextTick` を内部で `queueMicrotask` に委譲するため、Promise reaction と同一キューに入る。結果として「登録順」に実行され、Node.js の動作と異なる。

```javascript
queueMicrotask(() => console.log('microtask'));
process.nextTick(() => console.log('nextTick'));
// Node.js:  nextTick → microtask
// Workers:  microtask → nextTick
```

### 4.2 コンテキストが決定する実行順序（CJS vs ESM）

同一の Node.js ファイルを `.js`（CommonJS）と `.mjs`（ECMAScript module）で実行すると順序が逆転する場合がある。

```javascript
queueMicrotask(() => {
  queueMicrotask(() => console.log('A'));
  process.nextTick(() => console.log('B'));
});

process.nextTick(() => {
  queueMicrotask(() => console.log('A'));
  process.nextTick(() => console.log('B'));
});

// .js  (CommonJS): B, A, A, B
// .mjs (ESM):      A, B, B, A
```

**理由**: CJS はスクリプトをマクロタスクとして実行するが、ESM はマイクロタスクとして実行する。これによりドレインの基点が変わり、順序が反転する。

---

## 5. マイクロタスクスターベーション

マイクロタスクキューは「空になるまで」ドレインされる。キューが決して空にならない場合、アプリケーションは凍結する。

```javascript
// 危険：無限ループがイベントループを完全に占有
function forever() {
  queueMicrotask(forever);
}
forever();
// → タイマーが発火しない / I/O コールバックが実行されない / UI が応答しない
```

**実用コードでの落とし穴**:

```javascript
// items が数千件ある場合、マイクロタスクキューを数百ミリ秒占有する
async function processQueue(items) {
  for (const item of items) {
    await processItem(item);  // await は microtask queue に yield するだけ
                               // macrotask queue（タイマー・I/O）にはターンを渡さない
  }
}
```

`await` は microtask queue に戻るだけで、macrotask queue（setTimeout・I/O）に制御を返さない点に注意。

---

## 6. 非同期スケジューリング制御の実践

### 6.1 明示的な順序保証

```javascript
// 暗黙的な順序（モンスターに餌をやる）
fetchUserData();
updateUI();  // fetchUserData の完了を保証できない

// 明示的な順序（モンスターを飢えさせる）
await fetchUserData();
updateUI();  // fetchUserData 完了が保証される

// 並行実行の意図を明示
const [user, posts, comments] = await Promise.all([
  fetchUser(),
  fetchPosts(),
  fetchComments()
]);
```

`await` 間には「他の Promise チェーンのマイクロタスク」は割り込める。しかし I/O コールバック（他のリクエストハンドラ等）は割り込めない。この保証を理解した上で設計する。

```javascript
// 2 つの await の間、I/O は割り込まない（microtask priority の保証）
async function transferFunds(from, to, amount) {
  await debit(from, amount);
  await credit(to, amount);  // debit 後, credit 前に他リクエストは見えない
}
```

### 6.2 各 API の正しい用途

| API | 設計された用途 | 誤用パターン |
|-----|-------------|-------------|
| `queueMicrotask` | 現在のタスク完了直後に実行したい軽量処理 | 無限ループ・大量スケジューリング |
| `Promise.then` / `await` | 真に非同期な処理（I/O・通信）の待機 | 同期処理を Promise でラップする |
| `process.nextTick` | I/O 前にコールバックを確実に実行（Node.js のイベント発火タイミング調整） | 汎用的な「後で実行」 |
| `setImmediate` | I/O コールバック後、CPU 集約処理をチャンク単位でイベントループに yield | 汎用的な遅延 |
| `setTimeout(fn, 0)` | 少なくとも 1 回のイベントループ後に実行を保証したい場合 | 「できるだけ早く」の代替（`queueMicrotask` を使うべき） |
| `requestAnimationFrame` | ブラウザ描画サイクルに同期したアニメーション更新 | タブ非表示時も動かしたい処理 |

**`process.nextTick` の正しい使い方**:

```javascript
class MyEmitter extends EventEmitter {
  constructor() {
    super();
    // 誤: イベントがコンストラクタ内で発火し、呼び出し元がハンドラを登録できない
    // this.emit('ready');

    // 正: コンストラクタ返却後、I/O 前に発火
    process.nextTick(() => this.emit('ready'));
  }
}

const emitter = new MyEmitter();
emitter.on('ready', () => console.log('ready!'));  // ハンドラを登録できる
```

現代コードでは `process.nextTick` より `queueMicrotask` や `Promise` を使うほうがランタイム間の一貫性が高い。

### 6.3 CPU 集約処理のイベントループへの yield

`await` は macrotask queue（タイマー・I/O）にターンを渡さない。大量のアイテムを `await` でループすると他の処理が遅延する。

```javascript
// 問題: 数千件処理中にタイマー・I/O が遅延する
async function processQueue(items) {
  for (const item of items) {
    await processItem(item);
  }
}

// 解決: 100 件ごとに setTimeout で macrotask queue に yield する
async function wait() {
  const { promise, resolve } = Promise.withResolvers();
  setTimeout(resolve, 0);
  await promise;
}

async function processQueue(items) {
  for (let i = 0; i < items.length; i++) {
    await processItem(items[i]);
    if (i % 100 === 0) {
      await wait();  // macrotask queue に yield してタイマー・I/O に機会を与える
    }
  }
}
```

`setImmediate` を使った旧来パターン（コールバックスタイル）:

```javascript
function processLargeDataset(data, callback) {
  const results = [];
  let index = 0;

  function processChunk() {
    const chunkEnd = Math.min(index + 1000, data.length);
    while (index < chunkEnd) {
      results.push(transform(data[index++]));
    }
    if (index < data.length) {
      setImmediate(processChunk);  // I/O コールバックにターンを譲ってから続行
    } else {
      callback(results);
    }
  }

  processChunk();
}
```

### 6.4 Promise 過剰使用のパフォーマンスコスト

Promise はオブジェクトの生成とマイクロタスクの登録コストを伴う。同期処理を Promise でラップすると不要なコストが蓄積する。

```javascript
// 悪い例：同期処理を Promise チェーンで実行
const p = doSomethingThatResolvesSynchronously();
p.then(doSomethingElseSynchronous)
 .then(doYetAnotherSynchronousThing);
// → 各 .then() が Promise オブジェクトを生成しマイクロタスクをエンキューする

// 良い例：同期処理は同期的に実行
doSomethingThatResolvesSynchronously();
doSomethingElseSynchronous();
doYetAnotherSynchronousThing();
```

本来非同期な処理（I/O・ネットワーク）では Promise のオーバーヘッドは待機時間に埋もれて無視できる。しかし同期処理を Promise でラップした場合、数千リクエストが並行すると累積コストが無視できなくなる。

**診断ツール（Node.js）**:

```javascript
const v8 = require('node:v8');
let created = 0;
v8.promiseHooks.createHook({
  init() { created++; },
});
// アプリケーションを実行して created の値を確認する
// 1 リクエストあたりの Promise 生成数が異常に多い場合はリファクタリングを検討
```

### 6.5 ストリーム処理でのタイミング落とし穴

Node.js ストリームの `data` / `end` イベントは `process.nextTick` でスケジュールされる。`data` ハンドラで async 関数を使うと、`end` 時点で処理が完了していない。

```javascript
// 落とし穴：end 発火時点で async 処理が完了していない可能性がある
readable.on('data', async (chunk) => {
  const processed = await transform(chunk);
  results.push(processed);  // end より後に実行される場合がある
});
readable.on('end', () => {
  console.log(results.length);  // 0 になることがある
});

// 解決 1: Promise を収集して end で await する
const pending = [];
readable.on('data', (chunk) => {
  pending.push(transform(chunk));
});
readable.on('end', async () => {
  const results = await Promise.all(pending);
  console.log(results.length);
});

// 解決 2: for-await でストリームを消費する（最もクリーン）
for await (const chunk of readable) {
  pending.push(transform(chunk));
}
const results = await Promise.all(pending);
```

---

## まとめ：判断基準テーブル

| やりたいこと | 使う API | 注意点 |
|------------|---------|--------|
| 非同期処理の結果を待つ | `await` / `Promise.then` | 同期処理に使うとコスト増 |
| 同期コードの後に実行（汎用） | `queueMicrotask` | 無限ループでスターベーション |
| I/O 前に確実に実行（Node.js） | `process.nextTick` | ランタイム間で動作差異あり |
| I/O コールバック後に実行 | `setImmediate` | Node.js 専用（compat 注意） |
| 次のイベントループ後に実行 | `setTimeout(fn, 0)` | microtask より遅延が大きい |
| 描画前に実行（ブラウザ） | `requestAnimationFrame` | タブ非表示時は停止する |
| CPU 集約処理を分割して yield | `setTimeout` + バッチ | `await` だけでは不十分 |
| ランタイム横断で動作を保証 | `queueMicrotask` / `await` | `nextTick`・`setImmediate` は避ける |
