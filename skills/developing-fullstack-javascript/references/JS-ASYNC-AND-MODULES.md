# JS-ASYNC-AND-MODULES.md — 非同期プログラミング & モジュールシステム

## 1. JavaScriptの並行モデル

JavaScriptは**シングルスレッド**で動作する。一度実行を開始した関数は、完了するまで他のコードに割り込まれない（排他制御・デッドロック不要）。

代わりに「非同期処理」と「イベントループ」で並行性を実現する:

```
[コールスタック]     [タスクキュー]
  実行中の関数    ←  完了した非同期処理のコールバック
                      (setTimeoutコールバック, PromiseのthenハンドラなどのMicrotask)
```

**重要**: `Promise.all` で複数Promiseを渡しても、JavaScriptは1スレッドのまま。
「並列実行」ではなく「完了待ちを重ねる」ことで効率を上げる。

---

## 2. Promise — 非同期処理の基礎

### 2.1 Promiseのライフサイクル

```
pending（未決定）→ fulfilled（成功）
                 → rejected（失敗）
```

一度 fulfilled/rejected になったPromiseは変化しない（不変）。

### 2.2 Promiseを作る

```javascript
const myPromise = new Promise((resolve, reject) => {
  // executor関数 — 非同期タスクを開始する
  doAsyncTask((result, error) => {
    if (error) reject(error)
    else resolve(result)
  })
})
```

**落とし穴**: executor内でresolve/rejectを呼び忘れると、Promiseが永久にpending状態のままになる。
コールバック内では必ずtry/catchで例外を補足し、rejectに渡すこと。

```javascript
// NG: 例外がrejectされない
new Promise((resolve, reject) => {
  const callback = () => {
    riskyOperation()  // 例外が飛んでも誰もrejectしない
    resolve(result)
  }
  setTimeout(callback, 1000)
})

// OK: 例外をrejectに変換
new Promise((resolve, reject) => {
  const callback = () => {
    try {
      resolve(riskyOperation())
    } catch (e) {
      reject(e)
    }
  }
  setTimeout(callback, 1000)
})
```

### 2.3 即決するPromise

```javascript
Promise.resolve(value)  // 即座に成功するPromise
Promise.reject(error)   // 即座に失敗するPromise
```

用途: 戻り値を常にPromiseに統一したいとき。

```javascript
const getFromCache = key => {
  const cached = cache.get(key)
  if (cached) return Promise.resolve(cached)  // 同期的な値もPromiseでラップ
  return fetchFromServer(key)
}
```

---

## 3. Promiseチェーン

### 3.1 基本的な連鎖

```javascript
fetch('/api/user')
  .then(response => response.json())   // 次のPromiseを返す → チェーン継続
  .then(user => loadProfile(user.id))  // 同上
  .then(profile => renderProfile(profile))
  .catch(err => showError(err))        // どの段階の失敗もキャッチ
  .finally(() => hideSpinner())        // 成功・失敗どちらでも実行
```

**ルール**: `then` のハンドラが普通の値を返すと、その値で即決したPromiseが返る。
Promiseを返すと、そのPromiseの結果が次の `then` に渡される。

### 3.2 エラー伝播

```javascript
Promise.resolve()
  .then(() => step1())   // step1が例外を投げると
  .then(() => step2())   // ← スキップされ
  .then(() => step3())   // ← スキップされ
  .catch(err => handleError(err))  // ← ここで捕捉される
```

`catch` ハンドラが正常にリターンすれば、パイプラインを再開できる:

```javascript
loadData()
  .catch(() => loadFallbackData())  // フォールバック
  .then(data => render(data))       // フォールバックのデータで続行
```

### 3.3 よくある間違い

```javascript
// NG: thenの引数が関数でない（Promiseを渡してしまっている）
p.then(loadImage('url'))   // loadImageが即座に呼ばれ、戻り値（Promise）が捨てられる

// OK: 関数として渡す
p.then(() => loadImage('url'))
```

---

## 4. Promise並列実行API

### 4.1 使い分け判断テーブル

| メソッド | 動作 | 失敗時 | 用途 |
|---------|------|--------|------|
| `Promise.all(promises)` | 全件成功で解決 | 1件でも失敗→即rejectされ残りは無視 | 全部成功が前提の並列処理 |
| `Promise.allSettled(promises)` | 全件完了まで待機 | 失敗も`{status:'rejected', reason}`として結果に含む | 個別結果を全件確認したいとき |
| `Promise.race(promises)` | 最初に決定した1件の結果 | 最初にrejectしたものが勝つ場合もある | タイムアウト実装、最速応答取得 |
| `Promise.any(promises)` | 最初に成功した1件 | 全件失敗→`AggregateError` | 冗長なエンドポイントのフォールバック |

### 4.2 実装例

```javascript
// Promise.all — 全件並列取得してまとめて処理
const [user, posts, comments] = await Promise.all([
  fetchUser(id),
  fetchPosts(id),
  fetchComments(id)
])

// Promise.allSettled — 失敗してもすべての結果を取得
const results = await Promise.allSettled(urls.map(fetch))
const successes = results
  .filter(r => r.status === 'fulfilled')
  .map(r => r.value)
const failures = results
  .filter(r => r.status === 'rejected')
  .map(r => r.reason)

// Promise.race — タイムアウト付きfetch
const timeout = new Promise((_, reject) =>
  setTimeout(() => reject(new Error('Timeout')), 5000)
)
const result = await Promise.race([fetchData(), timeout])

// Promise.any — 最速のCDNを使う
const fastest = await Promise.any([
  fetch('https://cdn1.example.com/data'),
  fetch('https://cdn2.example.com/data'),
  fetch('https://cdn3.example.com/data')
])
```

---

## 5. async/await

### 5.1 基本構文

```javascript
// async関数は必ずPromiseを返す
const loadUser = async (id) => {
  const response = await fetch(`/api/users/${id}`)  // Promiseが解決するまで待機
  const user = await response.json()
  return user  // Promise.resolve(user) として返される
}
```

`await` は `async` 関数の中でのみ使用可能。

### 5.2 async関数が使える場所

```javascript
// アロー関数
const fn = async (x) => { ... }

// メソッド
class MyClass {
  async load() { ... }
}

// オブジェクトリテラルのメソッド
const obj = {
  async fetch() { ... }
}

// 名前付き関数
async function process(data) { ... }
```

### 5.3 戻り値の注意

```javascript
const getValue = async () => {
  return 42  // 外から見ると Promise<42>
}

// 呼び出し側でawaitまたはthenが必要
const n = await getValue()    // async関数の中でのみ
getValue().then(n => use(n)) // どこでも使える
```

### 5.4 例外処理

```javascript
// async関数内でthrowすると失敗したPromiseになる
const risky = async () => {
  throw new Error('failed')  // → Promise.reject(Error('failed'))
}

// awaitで失敗したPromiseを受けると例外として再スロー
const caller = async () => {
  try {
    const result = await risky()
  } catch (e) {
    console.error(e.message)  // 'failed'
  }
}

// .catch()で受け取ることも可能
risky().catch(e => console.error(e.message))
```

---

## 6. コンカレントawait（並列実行パターン）

### 6.1 直列 vs 並列

```javascript
// 直列実行（遅い）— img1の完了後にimg2を開始
const img1 = await loadImage(url1)
const img2 = await loadImage(url2)

// 並列実行（速い）— 両方を同時に開始して待機
const [img1, img2] = await Promise.all([loadImage(url1), loadImage(url2)])
```

### 6.2 罠: 配列リテラル内のawait

```javascript
// NG: これは直列実行 — awaitが先に評価される
const [img1, img2] = [await loadImage(url1), await loadImage(url2)]

// OK: Promise.allで並列化
const [img1, img2] = await Promise.all([loadImage(url1), loadImage(url2)])
```

### 6.3 awaitを書き忘れた場合

```javascript
// NG: awaitなし — Promiseが放置される
const processAll = async (urls) => {
  for (const url of urls) {
    processItem(url)  // Promiseを返すが、awaitしていない
  }
  // エラーがキャッチされず、完了を待てない
}

// OK
const processAll = async (urls) => {
  for (const url of urls) {
    await processItem(url)   // 直列
  }
  // または
  await Promise.all(urls.map(processItem))  // 並列
}
```

### 6.4 try/catch内での `return await` の違い

```javascript
// return Promise — loadImageが失敗してもcatchに入らない
async function load() {
  try {
    return loadImage(url)  // PromiseをそのままReturn → try/catchをバイパス
  } catch {
    return fallback
  }
}

// return await Promise — loadImageの失敗もcatchで捕捉される（推奨）
async function load() {
  try {
    return await loadImage(url)  // awaitで例外に変換してからReturn
  } catch {
    return fallback
  }
}
```

---

## 7. ESモジュール

### 7.1 基本的なimport/export

```javascript
// named export — 複数エクスポート可能
export function encrypt(str, key) { ... }
export class Cipher { ... }
export const DEFAULT_KEY = 3

// default export — 1ファイルに1つだけ
export default class CaesarCipher { ... }
// または
export default (s, key) => { ... }  // 匿名でOK
```

```javascript
// named import
import { encrypt, decrypt } from './cipher.mjs'

// エイリアス
import { encrypt as caesarEncrypt } from './cipher.mjs'

// default import — 名前は任意
import CaesarCipher from './cipher.mjs'
import CC from './cipher.mjs'  // 任意の名前でOK

// 全部をオブジェクトとして
import * as CipherTools from './cipher.mjs'
CipherTools.encrypt(...)
CipherTools.default(...)  // default機能へのアクセス
```

### 7.2 エクスポートは変数の参照

```javascript
// logging.mjs
export let currentLevel = 2
export const setLevel = (level) => { currentLevel = level }

// main.mjs
import * as logging from './logging.mjs'
console.log(logging.currentLevel)  // 2
logging.setLevel(3)
console.log(logging.currentLevel)  // 3 — 変更が反映される！

logging.currentLevel = 3  // エラー: インポートした変数に直接代入不可
```

**ポイント**: エクスポートは「値のスナップショット」ではなく「変数のライブバインディング」。

### 7.3 再エクスポート

```javascript
// facade/index.mjs — サブモジュールをまとめて公開
export { encrypt, decrypt } from './cipher.mjs'
export { randInt, randDouble } from './random.mjs'
export { default } from './stringutil.mjs'  // defaultを再エクスポート
export * from './utils.mjs'                 // デフォルト以外を全件再エクスポート

// 名前変更して再エクスポート
export { randInt as randomInteger } from './random.mjs'
export { CaesarCipher as default } from './cipher.mjs'  // defaultに昇格
```

---

## 8. 動的インポート（Code Splitting）

### 8.1 基本

```javascript
// 静的import: ファイル先頭に固定記述
import { fn } from './module.mjs'

// 動的import: 実行時に任意のパスをロード、Promiseを返す
const module = await import(`./plugins/${pluginName}.mjs`)
module.default()          // defaultエクスポートを実行
module.namedExport(args)  // named exportを呼び出す
```

### 8.2 用途とパターン

```javascript
// ルートベースのCode Splitting（フレームワーク統合の基礎）
const loadPage = async (route) => {
  const { default: Page } = await import(`./pages/${route}.mjs`)
  renderPage(new Page())
}

// 機能フラグ
if (featureFlags.useNewAlgorithm) {
  const { newAlgo } = await import('./algorithms/new.mjs')
  return newAlgo(data)
}

// 重いライブラリの遅延ロード
button.addEventListener('click', async () => {
  const { default: Chart } = await import('chart.js')
  new Chart(canvas, config)
})
```

**注意**: `import()` は関数のように見えるが、関数ではない（`super()`と同様の特殊構文）。
引数を変数に入れて渡すことはできるが、スプレッドなどの関数的操作はできない。

---

## 9. モジュール設計のベストプラクティス

### 9.1 tree-shaking対応のexport設計

```javascript
// NG: デフォルトexportにオブジェクトをまとめる（tree-shakingが効かない）
export default {
  formatDate,
  formatCurrency,
  formatPhone
}

// OK: named exportで個別公開（未使用関数がバンドルに含まれない）
export function formatDate(date) { ... }
export function formatCurrency(amount) { ... }
export function formatPhone(number) { ... }
```

### 9.2 循環依存の回避

循環依存 (`A → B → A`) は動作するが、初期化順序によっては `undefined` を参照する危険がある。

```javascript
// 問題: A.mjs
import { b } from './B.mjs'
export const a = () => b()  // B.mjsがまだ初期化されていないと bがundefined

// 解決策1: 依存方向を一方向に整理（推奨）
// 解決策2: ファサードモジュールで循環を断ち切る
// 解決策3: 関数内でのlazy import（動的importを使う）
const a = async () => {
  const { b } = await import('./B.mjs')
  return b()
}
```

### 9.3 モジュールのパッケージング

```html
<!-- ブラウザ: type="module"必須 -->
<script type="module" src="./app.mjs"></script>
```

```json
// Node.js: package.jsonでESMとして宣言
{
  "type": "module"
}
```

```javascript
// import.meta — 現在のモジュール情報
console.log(import.meta.url)  // このモジュールファイルのURL
```

**ファイル拡張子の推奨**: `.mjs` はすべてのランタイム・ビルドツールで認識される最もポータブルな選択。

### 9.4 ESモジュールの特性

- **自動 strict mode**: モジュール内のコードは常に `'use strict'`
- **独自のスコープ**: モジュールのトップレベル変数はグローバルスコープに漏れない
- **一度だけ実行**: 同じモジュールが複数回importされても、実行は1回のみ
- **非同期処理**: importの解析は本体実行前に完了する（循環依存を解決可能にする基盤）

---

## 10. 判断フロー

### 非同期処理のスタイル選択

```
複数Promiseを扱う？
├─ 全件成功が必要 → Promise.all()
├─ 個別結果が必要（失敗含む） → Promise.allSettled()
├─ 最初の成功だけ必要 → Promise.any()
└─ 最初の決定（成功/失敗問わず）だけ必要 → Promise.race()

単一Promiseを扱う？
├─ コードを同期的に書きたい → async/await（推奨）
└─ 関数型パイプラインが適切 → .then()チェーン
```

### モジュールのexportスタイル選択

```
ライブラリ/ユーティリティ（tree-shaking重要）
└─ named export推奨

フレームワーク/クラス主体（メインの機能が1つ）
└─ default export + named exportの併用

サブモジュールを束ねる（ファサード）
└─ export * / export { ... } from 再エクスポート
```
