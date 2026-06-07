# JavaScript 基礎：型・変数・制御構造リファレンス

モダンJavaScript（ES2020+）の基礎を、落とし穴と安全なパターンで整理したリファレンス。

---

## 1. 型システムと typeof

### 基本型一覧

| 型 | typeof 結果 | 備考 |
|----|------------|------|
| 数値 | `'number'` | 整数型はなく、すべて倍精度浮動小数点数 |
| 真偽値 | `'boolean'` | |
| 文字列 | `'string'` | |
| undefined | `'undefined'` | |
| null | **`'object'`** | ⚠️ 歴史的バグ。`typeof null === 'object'` |
| シンボル | `'symbol'` | |
| オブジェクト | `'object'` | 配列・関数以外 |
| 関数 | `'function'` | |

### typeof の落とし穴

```js
// null の判定は typeof を使えない
typeof null === 'object'  // true ⚠️
null === null             // true ✅ これが正解

// 配列の判定
typeof []         // 'object' ⚠️ 配列も object
Array.isArray([]) // true  ✅ これが正解

// ラッパーオブジェクトは使わない
typeof new Number(42)   // 'object' ⚠️ 意図しない型
typeof 42               // 'number' ✅
```

### NaN の扱い

```js
// NaN との比較は常に false
NaN === NaN  // false ⚠️
NaN < 4      // false
NaN >= 4     // false

// 判定には Number.isNaN を使う
Number.isNaN(NaN)       // true  ✅
Number.isNaN(parseFloat('pie'))  // true  ✅

// 浮動小数点の誤差
0.1 + 0.2               // 0.30000000000000004 ⚠️
// 金額計算はセント（整数）で扱う
```

---

## 2. 変数宣言：let / const / var

### 使い分けルール

| 宣言 | 再代入 | スコープ | ホスティング | 推奨 |
|------|--------|---------|------------|------|
| `const` | ❌ 不可 | ブロック | あり（初期化なし） | **第一優先** |
| `let` | ✅ 可 | ブロック | あり（初期化なし） | 再代入が必要な時のみ |
| `var` | ✅ 可 | 関数 | あり（`undefined`で初期化） | ❌ **使用禁止** |

### var を避ける理由

```js
// 問題1: 関数スコープ - ブロックを突き抜ける
if (true) {
  var leaked = 'outside!'
}
console.log(leaked)  // 'outside!' ⚠️ ブロック外から見える

// 問題2: タイプミスで新変数が生まれる
var counter = 0
coutner = 1  // スペルミスでも新変数が作られ、エラーにならない ⚠️

// 問題3: 同名での再宣言が可能
var x = 1
var x = 2  // エラーなし ⚠️
```

### const の正しい理解

```js
// const はオブジェクトの中身を凍結しない
const user = { name: 'Alice', age: 25 }
user.age = 26         // ✅ OK - プロパティの変更は可能
user = { name: 'Bob' } // ❌ Error - const 変数への再代入は不可

// 配列も同様
const nums = [1, 2, 3]
nums.push(4)   // ✅ OK
nums = [5, 6]  // ❌ Error
```

### const-first 原則

```js
// ❌ 可変変数を不必要に使う
let MAX = 100
let greeting = 'Hello, World'

// ✅ 変更しない値は const
const MAX = 100
const greeting = 'Hello, World'
```

---

## 3. null と undefined の使い分け

### 意味の違い

| 値 | 意味 | 発生タイミング |
|----|------|--------------|
| `undefined` | 「まだ値がない」「初期化されていない」 | 未初期化変数、省略されたパラメータ、存在しないプロパティ |
| `null` | 「意図的に値が存在しないことを示す」 | 明示的に「なし」を表現したいとき |

### プロジェクト内で一貫させる

```js
// 流派1: undefined 統一（null を避ける）
function findUser(id) {
  const user = db.find(id)
  return user ?? undefined  // 見つからなければ undefined
}

// 流派2: null 統一（undefined を避ける）
function findUser(id) {
  const user = db.find(id)
  return user ?? null  // 見つからなければ null
}

// ❌ 混在させる（どちらのチェックも必要になる）
function findUser(id) {
  if (!found) return undefined  // ここでは undefined
  if (!valid) return null       // ここでは null ← 混在！
}
```

### Nullish Coalescing（??）

```js
// || との違い: 0 や '' も「有効な値」として扱う
const port = config.port || 3000      // ⚠️ config.port が 0 なら 3000 になる
const port = config.port ?? 3000      // ✅ null/undefined のときだけ 3000

const name = user.nickname || 'Guest'   // ⚠️ '' も 'Guest' に変わる
const name = user.nickname ?? 'Guest'   // ✅ 空文字は空文字のまま

// ?? の使いどき：値の欠如（null/undefined）のみ判定したいとき
const result = someMethod() ?? defaultValue
```

---

## 4. 文字列とテンプレートリテラル

### テンプレートリテラルの使い方

```js
const name = 'Alice'
const age = 25

// 基本: 変数や式を埋め込む
const msg = `Hello, ${name.toUpperCase()}! You are ${age} years old.`

// 複数行（改行がそのまま含まれる）
const html = `
  <div>
    <p>${name}</p>
  </div>
`

// 式を埋め込む
const label = `Status: ${isActive ? 'Active' : 'Inactive'}`

// ネスト（条件付きフォーマット）
const greeting = `Hello, ${firstName.length > 0 ? `${firstName[0]}.` : ''} ${lastName}`
```

### タグ付きテンプレートリテラル

```js
// XSS対策など、加工処理を挟みたいとき
function safeHtml(strings, ...values) {
  return strings.reduce((result, str, i) => {
    const val = values[i - 1]
    const escaped = String(val).replace(/</g, '&lt;').replace(/>/g, '&gt;')
    return result + escaped + str
  })
}

const userInput = '<script>alert("xss")</script>'
const safe = safeHtml`<p>${userInput}</p>`
// → '<p>&lt;script&gt;alert("xss")&lt;/script&gt;</p>'
```

---

## 5. 分割代入パターン集

### 配列の分割代入

```js
// 基本
const [first, second] = [1, 2, 3]  // first=1, second=2

// スキップ
const [, second, , fourth] = [1, 2, 3, 4]  // second=2, fourth=4

// rest（残余要素）
const [head, ...tail] = [1, 2, 3, 4]  // head=1, tail=[2,3,4]

// デフォルト値
const [a, b = 0] = [42]  // a=42, b=0

// 変数の交換（一時変数不要）
let x = 1, y = 2
;[x, y] = [y, x]  // x=2, y=1
```

### オブジェクトの分割代入

```js
const user = { name: 'Alice', age: 25, role: 'admin' }

// 基本（プロパティ名と変数名が一致）
const { name, age } = user  // name='Alice', age=25

// リネーム（別名で受け取る）
const { name: userName, age: userAge } = user

// デフォルト値
const { name, nickname = 'Anonymous' } = user  // nickname='Anonymous'

// ネスト
const config = { db: { host: 'localhost', port: 5432 } }
const { db: { host, port } } = config  // host='localhost', port=5432

// rest（残余プロパティ）
const { name: _, ...userWithoutName } = user  // { age: 25, role: 'admin' }

// 関数パラメータのデフォルト設定パターン
function connect({ host = 'localhost', port = 3000, ssl = false } = {}) {
  // ...
}
```

### 分割代入の実践パターン

```js
// 設定オブジェクトのオプション展開
const config = { separator: ';' }
const {
  separator = ',',
  leftDelimiter = '[',
  rightDelimiter = ']'
} = config
// → separator=';', leftDelimiter='[', rightDelimiter=']'

// 関数の複数戻り値
function getCoordinates() {
  return { lat: 35.68, lng: 139.69 }
}
const { lat, lng } = getCoordinates()

// 既存変数への再代入（括弧が必要）
let firstName, lastName
;({ firstName, lastName } = fullName)  // () で囲む ← { } がブロック文と誤認されるため
```

---

## 6. 等価判定と truthy/falsy

### === を使う（絶対ルール）

```js
// === : 型変換なし・厳密比較
'42' === 42     // false ← 型が異なる
null === undefined  // false
undefined === undefined  // true
'42' === '4' + 2  // true ← 同じ文字列

// == の危険（使ってはいけない理由）
'' == 0     // true  ⚠️
'0' == 0    // true  ⚠️
'0' == false  // true  ⚠️
'' == '0'   // false ⚠️ 推移律が成り立たない！
```

### falsy 値の完全リスト

```js
// この 6 つだけが falsy（条件式で false として評価される）
false
0           // ゼロ
''          // 空文字列
null
undefined
NaN

// それ以外はすべて truthy
// ⚠️ 紛らわしい truthy
'0'         // truthy（空文字列ではない）
[]          // truthy（空配列もオブジェクト）
{}          // truthy（空オブジェクトもオブジェクト）
-0          // falsy（マイナスゼロ）
```

### 条件式では意図を明示する

```js
// ❌ 真偽性に頼った曖昧なチェック
if (performance) { ... }       // 0 や '' も false になる
if (user.name) { ... }         // '' も false になる

// ✅ 型と値を明示したチェック
if (performance !== undefined) { ... }  // undefined だけを除外
if (user.name !== '') { ... }           // 空文字だけを除外
if (user.name != null) { ... }          // null と undefined を除外（==null の例外的使用）
```

### オブジェクトの等価判定

```js
const a = { x: 1 }
const b = a
const c = { x: 1 }

a === b  // true  ← 同じオブジェクト参照
a === c  // false ← 内容が同じでも別オブジェクト

// 内容の比較にはシリアライズか専用関数を使う
JSON.stringify(a) === JSON.stringify(c)  // true（シンプルなオブジェクト向け）
```

---

## 7. for-of vs for-in

### 使い分け表

| ループ | 対象 | 返すもの | 推奨用途 |
|--------|------|---------|---------|
| `for...of` | iterable（配列・文字列・Map・Set等） | **値** | 配列・文字列の要素巡回 |
| `for...in` | すべてのオブジェクト | **キー（文字列）** | オブジェクトのプロパティ巡回 |
| `for` (古典的) | インデックス制御が必要な場合 | インデックス | 逆順・条件付き更新 |

### for-of（推奨：配列・文字列）

```js
const arr = [10, 20, 30]

// ✅ for-of: 値を取得
for (const item of arr) {
  console.log(item)  // 10, 20, 30
}

// ✅ インデックスも欲しい場合
for (const [index, item] of arr.entries()) {
  console.log(index, item)  // 0 10, 1 20, 2 30
}

// ✅ 文字列: Unicodeコードポイント単位で巡回（絵文字も正しく処理）
const greeting = 'Hello 🌍'
for (const char of greeting) {
  console.log(char)  // H, e, l, l, o, ' ', 🌍 ← 絵文字も1文字として扱われる
}
```

### for-in の落とし穴

```js
const obj = { a: 1, b: 2, c: 3 }

for (const key in obj) {
  console.log(key, obj[key])  // 'a' 1, 'b' 2, 'c' 3
}

// ⚠️ 落とし穴1: キーは文字列
const nums = [1, 2, 3]
for (const i in nums) {
  // i は '0', '1', '2'（数値ではなく文字列！）
  console.log(i + 1)  // '01', '11', '21' ⚠️ 文字列連結になる
}
// 配列の巡回には for-of を使う

// ⚠️ 落とし穴2: プロトタイプチェーンも含む
for (const key in obj) {
  if (Object.prototype.hasOwnProperty.call(obj, key)) {
    // 自身のプロパティのみ処理（継承プロパティを除外）
  }
}

// ⚠️ 落とし穴3: 配列 + for-in でインデックス + 追加プロパティが混在
nums.lucky = true
for (const i in nums)  // '0', '1', '2', 'lucky' ← lucky も含まれる
```

---

## 8. Optional Chaining と Nullish Coalescing

### Optional Chaining（?.）

```js
// ネストしたプロパティへの安全なアクセス
const user = { profile: { address: { city: 'Tokyo' } } }

// ❌ 旧来の書き方
const city = user && user.profile && user.profile.address && user.profile.address.city

// ✅ Optional Chaining
const city = user?.profile?.address?.city    // 'Tokyo'
const zip  = user?.profile?.address?.zip    // undefined（エラーなし）

// メソッド呼び出し
const length = user?.profile?.getName?.()   // getName がなければ undefined

// 配列へのアクセス
const firstTag = user?.tags?.[0]

// NG パターン: 存在確認済みの変数には不要
// const city = user.profile.address.city  // user が確実に存在するなら直接アクセスでよい
```

### Nullish Coalescing との組み合わせ

```js
// Optional Chaining + Nullish Coalescing
const displayName = user?.profile?.nickname ?? user?.name ?? 'Anonymous'

// 設定値の取得
const timeout = config?.http?.timeout ?? 5000

// Optional Chaining でメソッド呼び出し + デフォルト
const label = formatter?.format(value) ?? String(value)
```

### ?? vs || の選択基準

```js
const value = 0

// || : 0, '', false, null, undefined → デフォルト値を使う
const a = value || 100   // 100 ⚠️ 0 が有効な値なのに置き換わる

// ?? : null, undefined のみ → デフォルト値を使う
const b = value ?? 100   // 0  ✅ 0 は有効な値として扱われる

// 判断基準：「0 や '' は有効な値か？」
// YES → ??
// NO  → ||
```

---

## 9. 型変換クイックリファレンス

### 数値変換

```js
// 推奨: 明示的な変換
Number('42')    // 42
Number('')      // 0
Number('hello') // NaN
Number(true)    // 1
Number(false)   // 0
Number(null)    // 0
Number(undefined) // NaN

parseInt('3.14px', 10)  // 3（基数は必ず指定）
parseFloat('3.14px')    // 3.14
```

### 文字列変換

```js
String(42)        // '42'
String(null)      // 'null'
String(undefined) // 'undefined'
(42).toString()   // '42'

// オブジェクトのログ出力（[object Object]を避ける）
console.log(JSON.stringify(obj))       // シンプルな確認
console.log({ user, config })          // 複数まとめて出力
```

### 暗黙の型変換は避ける

```js
// ❌ + 演算子は文字列連結と数値加算が混在
null + undefined       // NaN
'5' + 3               // '53'（文字列連結）
'5' - 3               // 2  （数値演算）
6 * '7'              // 42 （'7' が数値に変換される）

// ✅ 意図を明示する
Number('5') + 3        // 8
String(5) + '3'        // '53'
```

---

## 10. セミコロン自動挿入（ASI）の注意点

### 行頭が ( [ ` で始まると前の行と結合される

```js
// ❌ ( で始まる行が前の式と結合
let a = x
(console.log(6 * 7))  // → x(console.log(6 * 7)) として解釈

// ❌ [ で始まる行
let a = x
[1, 2, 3].forEach(console.log)  // → x[1, 2, 3] として解釈

// ✅ 行頭セミコロンで防ぐ（行頭 ; パターン）
let a = x
;[1, 2, 3].forEach(console.log)
```

### return 直後の改行

```js
// ❌ return 後に改行すると undefined が返る
function getConfig() {
  return           // ← ここでセミコロンが挿入される
  {
    timeout: 5000  // 到達しない
  }
}

// ✅ return と値を同じ行に
function getConfig() {
  return {
    timeout: 5000
  }
}
```

---

## まとめ：5 つの安全ルール

1. **const-first** — 変更しない変数は `const`、変更が必要な場合のみ `let`。`var` は絶対禁止
2. **=== 徹底** — `==` は使わない。`null/undefined` チェックのみ例外的に `== null` を許容
3. **意図を明示** — truthy/falsy に頼らず `!== undefined`、`!== null` などで条件を明確に書く
4. **for-of で配列** — 配列の巡回は `for-of`。`for-in` はオブジェクトのキー巡回専用
5. **?? でデフォルト** — `||` ではなく `??` でデフォルト値を設定。0 や '' が有効な値の場合は特に重要
