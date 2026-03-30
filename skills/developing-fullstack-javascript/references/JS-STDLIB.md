# JS-STDLIB.md — 数値・日付・文字列・正規表現・配列・コレクション リファレンス

JavaScript標準ライブラリの実用リファレンス。数値・日付（Ch5）、文字列・正規表現（Ch6）、配列・コレクション（Ch7）を網羅する。

---

## 1. 数値（Number / BigInt / Math）

### 1.1 数値リテラル

```javascript
42           // decimal
0x2A         // hexadecimal（16進）
0o52         // octal（8進）— strict mode では 052 は禁止
0b101010     // binary（2進）
4.2e-3       // 指数表記（0.0042）
299_792_458  // 区切り文字 _ （ES2021+）— 読みやすさ用
```

### 1.2 Number クラス：関数と定数

| 名前 | 説明 |
|------|------|
| `Number.isNaN(x)` | `x` が NaN なら true。グローバル `isNaN()` は型変換するため**使用禁止** |
| `Number.isFinite(x)` | ±Infinity でも NaN でもなければ true。グローバル版も**使用禁止** |
| `Number.isInteger(x)` | 整数なら true |
| `Number.isSafeInteger(x)` | 安全な整数範囲内（±2⁵³−1）なら true |
| `Number.parseInt(str, radix)` | グローバル `parseInt` と等価 |
| `Number.parseFloat(str)` | グローバル `parseFloat` と等価 |
| `Number.MAX_SAFE_INTEGER` | `9_007_199_254_740_991`（2⁵³−1） |
| `Number.MIN_SAFE_INTEGER` | `-9_007_199_254_740_991` |
| `Number.MAX_VALUE` | 表現可能な最大浮動小数点数（約 1.8×10³⁰⁸） |
| `Number.EPSILON` | 1 と隣接表現可能数の差（約 2.2×10⁻¹⁶）、浮動小数点比較に使用 |

```javascript
// ⚠️ グローバル版の罠
isNaN('Hello')   // true（型変換が走る）
isFinite([0])    // true（型変換が走る）
// ✅ Number. を付ける
Number.isNaN('Hello')  // false
```

### 1.3 数値フォーマット（メソッド）

```javascript
const x = 1 / 600  // 0.0016666...

x.toFixed(4)       // '0.0017'  — 固定小数点
x.toExponential(4) // '1.6667e-3' — 指数表記
x.toPrecision(4)   // '0.001667' — 有効桁数

const n = 3735928559
n.toString(16)     // 'deadbeef'（16進）
n.toString(2)      // '11011110...'（2進）
```

### 1.4 Math クラス

| 関数 | 説明 |
|------|------|
| `Math.max(...values)` | 最大値。スプレッドで配列を渡せる |
| `Math.min(...values)` | 最小値 |
| `Math.round(x)` | 最近傍整数への丸め（-2.5 → -2 に注意） |
| `Math.trunc(x)` | 小数部切り捨て（符号保持） |
| `Math.floor(x)` | 以下の最大整数 |
| `Math.ceil(x)` | 以上の最小整数 |
| `Math.abs(x)` | 絶対値 |
| `Math.random()` | `[0, 1)` の乱数 |
| `Math.sqrt(x)` / `Math.cbrt(x)` | 平方根 / 立方根 |
| `Math.pow(x, y)` | `x^y`（`**` 演算子でも可） |
| `Math.log(x)` / `Math.log2(x)` / `Math.log10(x)` | 自然対数 / log₂ / log₁₀ |
| `Math.PI` | π（3.14159...） |
| `Math.E` | e（2.71828...） |

```javascript
// [a, b) の乱数
const rand = (a, b) => a + (b - a) * Math.random()
const randInt = (a, b) => a + Math.trunc((b - a) * Math.random())
```

### 1.5 BigInt

整数桁数無制限の型。暗号処理・ファクトリアル計算などに使用。

```javascript
const big = 81591528324789773434561126959611589427200000000n  // n サフィックス
const result = big * BigInt(41)  // BigInt 同士のみ演算可

// ⚠️ 通常の Number と直接混在は TypeError
// 815915283247897734345611269596115894272000000000n * 41  // エラー

typeof 42n  // 'bigint'
100n / 3n   // 33n（整数除算、余り切り捨て）
```

---

## 2. 日付と時刻（Date API）

### 2.1 Date の基礎知識

- JavaScript は UTC 1970年1月1日（エポック）からのミリ秒で時刻を管理
- `Date` は UTC+N のローカルタイムゾーンを考慮したメソッドを持つ
- ISO 8601 形式: `YYYY-MM-DDTHH:mm:ss.sssZ`

### 2.2 Date の構築

```javascript
// ISO 8601 文字列から
const moonLanding = new Date('1969-07-20T20:17:40.000Z')

// エポックからのミリ秒
const oneYear = new Date(365 * 86400 * 1000)

// 現在
const now = new Date()

// ローカルタイムゾーン（月は 0 始まり！）
new Date(2024, 0 /* 1月 */, 31, 12, 0, 0, 0)

// ⚠️ new を忘れると文字列を返す（Date オブジェクトにならない）
Date(365 * 86400 * 1000)  // 引数無視して現在時刻の文字列を返す

// UTCでDateを構築する（Date.UTC はミリ秒を返すため new が必要）
const deadline = new Date(Date.UTC(2024, 0 /* January */, 31))
```

### 2.3 Date の静的関数

| 関数 | 戻り値 |
|------|--------|
| `Date.now()` | 現在のエポックミリ秒（数値） |
| `Date.UTC(year, month, ...)` | UTC 基準のエポックミリ秒（数値） |
| `Date.parse(str)` | ISO 8601 文字列→エポックミリ秒 |

> ⚠️ 3 関数ともに返すのは **Date オブジェクトではなくミリ秒の数値**。

### 2.4 Date のメソッド

```javascript
const d = new Date('1969-07-20T20:17:40.000Z')

// UTC 取得系（推奨）
d.getUTCFullYear()   // 1969
d.getUTCMonth()      // 6（0始まり！ 7月 → 6）
d.getUTCDate()       // 20
d.getUTCDay()        // 0（日曜）〜 6（土曜）
d.getUTCHours()      // 20
d.getTime()          // エポックミリ秒

// ISO 文字列
d.toISOString()      // '1969-07-20T20:17:40.000Z'

// ローカライズ表示
d.toLocaleDateString('ja-JP')            // '1969/7/20'
d.toLocaleDateString('en-US', { month: 'long', year: 'numeric', day: 'numeric' })
// 'July 20, 1969'
```

```javascript
// 経過時間の計測
const before = new Date()
// ...処理...
const after = new Date()
const ms = after - before  // Dateの差は数値（ミリ秒）になる
```

### 2.5 Temporal API（将来の方向性）

`Date` の設計上の問題（可変オブジェクト、月が 0 始まり、タイムゾーン処理の複雑さ）を解消する次世代 API。
現時点では polyfill（`@js-temporal/polyfill`）での利用を検討。

---

## 3. 文字列（String）

### 3.1 Unicode とコードポイント

JavaScript の文字列は UTF-16 コードユニットのシーケンスで格納される。
`\u{FFFF}` を超える絵文字・漢字は **2 コードユニット（サロゲートペア）** を消費する。

```javascript
// コードポイント → 文字列
String.fromCodePoint(0x48, 0x69, 0x20, 0x1F310, 0x21)  // 'Hi 🌐!'

// 文字列 → コードポイント配列（スプレッドで正しく分割）
[...'Hi 🌐!']               // ['H', 'i', ' ', '🌐', '!']（5要素）
'Hi 🌐!'.length             // 6（UTF-16 コードユニット数 = 絵文字が2単位）

// コードポイント整数値
[...'Hi 🌐!'].map(c => c.codePointAt(0))

// ⚠️ split('') は UTF-16 単位で分割するため絵文字が壊れる
// ✅ [...str] を使う
```

### 3.2 部分文字列操作

```javascript
// 検索（戻り値は UTF-16 オフセット）
'Hello yellow'.indexOf('el')       // 1
'Hello yellow'.lastIndexOf('el')   // 7
url.startsWith('https://')
url.endsWith('.gif')
url.includes('?')

// 切り出し（slice を推奨）
'I♡yellow'.slice(3, 7)    // 'yell'（負インデックス対応）
'I♡yellow'.slice(-6, -2)  // 'yell'（末尾から数える）

// ⚠️ substring は引数の大小を自動交換する奇妙な挙動あり
// ✅ slice を使う

// 分割
'Mary had a little lamb'.split(' ')        // ['Mary', 'had', 'a', 'little', 'lamb']
'Mary had a little lamb'.split(' ', 3)     // ['Mary', 'had', 'a']
```

### 3.3 文字列メソッド一覧

| メソッド | 説明 |
|---------|------|
| `trim()` / `trimStart()` / `trimEnd()` | 空白除去 |
| `padStart(len, str)` / `padEnd(len, str)` | パディング |
| `repeat(n)` | n回繰り返し |
| `toUpperCase()` / `toLowerCase()` | 大文字/小文字変換 |
| `concat(...args)` | 連結（テンプレートリテラルが通常は優先） |
| `match(regex)` | マッチ配列、グローバルなら全マッチ |
| `matchAll(regex)` | 全マッチをイテラブルで返す |
| `search(regex)` | 最初のマッチインデックス |
| `replace(target, replacement)` | 置換（グローバルフラグで全置換） |

```javascript
'Straße'.toUpperCase()  // 'STRASSE'（ドイツ語 ß の正しい大文字変換）

// encodeURIComponent で URL 安全エンコード
const url = prefix + encodeURIComponent('à coté de') + suffix
```

### 3.4 タグ付きテンプレートリテラル

```javascript
// タグ関数の署名: (fragments: TemplateStringsArray, ...values: any[]) => any
const strong = (fragments, ...values) => {
  let result = fragments[0]
  for (let i = 0; i < values.length; i++) {
    result += `<strong>${values[i]}</strong>${fragments[i + 1]}`
  }
  return result
}

const person = { name: 'Harry', age: 42 }
strong`Next year, ${person.name} will be ${person.age + 1}.`
// 'Next year, <strong>Harry</strong> will be <strong>43</strong>.'

// 断片数 = 値数 + 1（常に）
```

### 3.5 String.raw（rawテンプレートリテラル）

```javascript
// バックスラッシュをエスケープとみなさない
const path = String.raw`c:\users\nate`   // \u や \n が変換されない

// タグ関数内で raw にアクセス
const tag = (fragments, ...values) => {
  console.log(fragments.raw[0])  // 生のバックスラッシュ文字列
}
```

---

## 4. 正規表現（RegExp）

### 4.1 リテラルと構築

```javascript
const timeRegex = /^([1-9]|1[0-2]):[0-9]{2} [ap]m$/  // リテラル

// 動的に構築
const pattern = new RegExp('[0-9]+', 'g')

typeof /abc/      // 'object'
/abc/ instanceof RegExp  // true
```

### 4.2 構文リファレンス

| パターン | 意味 | 例 |
|---------|------|-----|
| `.` | 任意の1文字（`\n` 以外） | `h.t` → "hat", "hit" |
| `*` / `+` / `?` | 0以上 / 1以上 / 0か1 | `be+s?` → "be", "bee", "bees" |
| `{n}` / `{n,}` / `{m,n}` | n回 / n回以上 / m〜n回 | `[0-9]{4,6}` |
| `X*?` / `X+?` | 非貪欲（最短マッチ） | `.*?` |
| `[abc]` / `[^abc]` | 文字クラス / 補集合 | `[A-Za-z]` |
| `\d` / `\D` | 数字 `[0-9]` / 非数字 | |
| `\w` / `\W` | ワード文字 `[a-zA-Z0-9_]` / 非ワード | |
| `\s` / `\S` | 空白 / 非空白 | |
| `^` / `$` | 行頭 / 行末 | |
| `\b` / `\B` | 単語境界 / 非単語境界 | |
| `(X)` | キャプチャグループ | |
| `(?:X)` | 非キャプチャグループ | |
| `(?<name>X)` | 名前付きキャプチャグループ | |
| `\k<name>` | 名前付きグループの後方参照 | |
| `X\|Y` | 選択 | `http\|ftp` |

### 4.3 フラグ

| フラグ | プロパティ | 説明 |
|-------|----------|------|
| `i` | `ignoreCase` | 大文字小文字無視 |
| `m` | `multiline` | `^` `$` が行頭/行末にマッチ |
| `s` | `dotAll` | `.` が `\n` にもマッチ |
| `u` | `unicode` | Unicode モード（必須：絵文字・非ASCII文字） |
| `g` | `global` | 全マッチを検索 |
| `y` | `sticky` | `lastIndex` 位置から厳密にマッチ |

### 4.4 Unicode 対応（u フラグ）

```javascript
// ⚠️ u フラグなし → 絵文字1文字が2コードユニットとして扱われる
/Hello .$/.test('Hello 🌐')    // false（絵文字が2コードユニット）
/Hello .$/u.test('Hello 🌐')   // true（uフラグで正しく1文字扱い）

// \p{プロパティ} で Unicode カテゴリマッチ（u フラグ必須）
/\p{L}+/u.test('世界')         // true（Unicode 文字）
/\p{Script=Han}+/u             // 漢字シーケンス

// \u{...} でコードポイント指定
/[A-Za-z]+ \u{1F310}/u         // 絵文字を含むパターン
```

**Unicode プロパティ一覧（`\p{...}`）**

| プロパティ | 説明 |
|---------|------|
| `L` | 文字（letter） |
| `Lu` / `Ll` | 大文字 / 小文字 |
| `Nd` | 10進数字 |
| `P` | 区切り記号 |
| `White_Space` | 空白（`\s` と同等） |
| `Emoji` | 絵文字 |

### 4.5 名前付きグループと後方参照

```javascript
// 名前付きキャプチャ
const lineItem = /(?<item>\p{L}+(?:\s+\p{L}+)*)\s+(?<currency>[A-Z]{3})(?<price>[0-9.]+)/u

const result = lineItem.exec('Blackwell Toaster USD29.95')
result.groups  // { item: 'Blackwell Toaster', currency: 'USD', price: '29.95' }

// 名前付き後方参照
/(?<quote>['"]).*\k<quote>/  // 同じ引用符で閉じる
```

### 4.6 先読み / 後読み

```javascript
// 先読み（lookahead）— ':' の前の数字だけをマッチ
'10:30 - 12:00'.match(/[0-9]+(?=:)/g)    // ['10', '12']

// 否定先読み
'10:30 - 12:00'.match(/[0-9][0-9](?!:)/g) // ['30', '00']

// 後読み（lookbehind）— ':' の後の数字
'10:30 - 12:00'.match(/(?<=:)[0-9]+/g)    // ['30', '00']

// 否定後読み
'10:30 - 12:00'.match(/(?<!\d:)[0-9]+/g)
```

### 4.7 String × RegExp メソッド

```javascript
const str = 'agents 007 and 008'

// match — グローバルなら全マッチ配列
str.match(/[0-9]+/)   // ['007', index: 7, ...]（最初の1件）
str.match(/[0-9]+/g)  // ['007', '008']（全件）

// matchAll — 全マッチをイテラブルで（グループ情報も取得可能）
for (const [, hours, min, period] of input.matchAll(time)) { ... }

// search — 最初のマッチインデックス
str.search(/[0-9]+/)  // 7

// replace — 置換
str.replace(/[0-9]/g, '?')  // 'agents ??? and ???'

// 関数での置換
names.replace(/^([A-Z][a-z]+) ([A-Z][a-z]+)$/gm,
  (match, first, last) => `${last}, ${first[0]}.`)
// 'Smith, H.\nLin, S.'

// split と正規表現
str.split(/\s*,\s*/)  // カンマと周囲の空白で分割
```

---

## 5. 配列（Array）

### 5.1 配列の構築

```javascript
const names = ['Peter', 'Paul', 'Mary']

// スプレッドでイテラブルを展開
const merged = [...a, ...b]

// Array.from — イテラブルまたは配列的オブジェクトから
Array.from({ length: 5 }, (_, i) => i * i)  // [0, 1, 4, 9, 16]

// ⚠️ new Array(10000) は長さ 10000 の空配列（要素なし）
// ✅ 配列リテラルを使う
const arr = [10000]  // 要素が 10000 の 1 要素配列
```

### 5.2 ミューテータメソッド（配列を変更する）

| メソッド | 説明 |
|---------|------|
| `push(v)` / `pop()` | 末尾追加 / 末尾削除 |
| `unshift(v)` / `shift()` | 先頭追加 / 先頭削除 |
| `splice(start, del, ...items)` | 任意位置での削除・挿入 |
| `fill(val, start, end)` | 範囲を値で上書き |
| `copyWithin(target, start, end)` | 内部コピー |
| `reverse()` | その場で逆順 |
| `sort(fn)` | その場でソート。比較関数必須（省略時は文字列比較） |

```javascript
// ⚠️ sort() は比較関数を省略すると文字列変換後にソートする
[0, 1, 4, 9, 16, 25].sort()          // [0, 1, 16, 25, 4, 9] ← 意図しない結果
[0, 1, 4, 9, 16, 25].sort((a, b) => a - b)  // [0, 1, 4, 9, 16, 25] ← 正しい

// splice は削除した要素を返す
const deleted = arr.splice(1, 2, 'a', 'b')
```

### 5.3 イミュータブルメソッド（新しい配列/値を返す）

| メソッド | 説明 |
|---------|------|
| `slice(start, end)` | 範囲の浅いコピー |
| `concat(...args)` | 結合（配列は平坦化）|
| `flat(depth)` | 多次元配列を平坦化（デフォルト1段） |
| `map(f)` | 変換して新配列 |
| `flatMap(f)` | map + flat(1)（効率的） |
| `filter(f)` | 条件を満たす要素だけ |
| `find(f)` / `findIndex(f)` | 最初に条件を満たす要素/インデックス |
| `every(f)` / `some(f)` | 全要素/任意要素が条件を満たすか |
| `includes(val)` | 包含チェック（`===` 比較） |
| `indexOf(val)` / `lastIndexOf(val)` | インデックス検索 |
| `join(sep)` | 文字列結合 |
| `reduce(fn, init)` | 畳み込み（左から） |
| `reduceRight(fn, init)` | 畳み込み（右から） |

### 5.4 反復処理

```javascript
// for-of（推奨）— 欠けている要素を undefined として訪問
for (const element of arr) { ... }

// entries() でインデックスと要素を同時取得
for (const [index, element] of arr.entries()) { ... }

// forEach — 欠けている要素をスキップ
arr.forEach((element, index) => { ... })

// ⚠️ for-in はオブジェクトのキー（文字列）を返す — 配列には不適
```

### 5.5 疎な配列（Sparse Array）

```javascript
const sparse = [, 2, , 9]  // インデックス 0, 2 が欠けている
sparse.length               // 4

// 欠けた要素の挙動
// forEach / filter / map は欠けた要素をスキップ
// for-of は undefined として訪問
// Array.from は undefined で埋める

// 欠けた要素を undefined に変換
Array.from([, 2, , 9])   // [undefined, 2, undefined, 9]

// 欠けた要素を除去
[, 2, , 9].filter(x => true)  // [2, 9]
```

### 5.6 reduce の実践パターン

```javascript
// 合計
[1, 7, 2, 9].reduce((acc, x) => acc + x, 0)  // 19

// 文字頻度マップ（イミュータブルスタイル）
[...'Mississippi'].reduce(
  (freq, c) => ({ ...freq, [c]: (c in freq ? freq[c] + 1 : 1) }),
  {}
)
// { M: 1, i: 4, s: 4, p: 2 }

// ⚠️ 空配列に初期値なしで reduce → TypeError
// ✅ 必ず初期値を渡す
```

---

## 6. Map と Set

### 6.1 Map

プレーンオブジェクトより `Map` を選ぶ理由：
- キーはあらゆる型（オブジェクト参照含む）
- 挿入順序が保証される
- プロトタイプチェーンがない（`__proto__` 汚染なし）
- `size` で要素数を O(1) 取得

```javascript
const map = new Map([['Mon', 0], ['Tue', 1], ['Wed', 2]])

map.set(key, value)         // 追加・更新（メソッドチェーン可）
map.get(key)                // 取得（なければ undefined）
map.has(key)                // boolean
map.delete(key)             // 削除（成功なら true）
map.clear()                 // 全削除
map.size                    // 要素数

// 反復（挿入順）
for (const [key, value] of map) { ... }
map.forEach((value, key) => { ... })  // ⚠️ value が先、key が後

// ⚠️ オブジェクトキーは参照比較
// { x: 0, y: 0 } と { x: 0, y: 0 } は別キー → stringify をキーにする等の対策
```

### 6.2 Set

```javascript
const set = new Set(['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])

set.add(x)     // 追加（重複は無視）
set.has(x)     // boolean
set.delete(x)  // 削除（成功なら true）
set.clear()    // 全削除
set.size       // 要素数

// 反復（挿入順）
for (const value of set) { ... }

// 集合演算（ES2025+ で Array メソッドライクな Set メソッドが追加予定）
// ポリフィル的実装
const union = new Set([...a, ...b])
const intersection = new Set([...a].filter(x => b.has(x)))
const difference = new Set([...a].filter(x => !b.has(x)))
```

### 6.3 WeakMap と WeakSet

GC に対して「弱い参照」を提供する。DOM ノード等のメタデータ付加に最適。

```javascript
// ✅ WeakMap — DOM ノードにプロパティを付加（GC の邪魔をしない）
const outcome = new WeakMap()
outcome.set(domNode, 'success')

// キーがほかから参照されなくなると GC に回収される
// ゆえに反復・サイズ取得は不可能

// WeakSet — バイナリフラグ的な用途
const visited = new WeakSet()
visited.add(node)
visited.has(node)

// ⚠️ キー/要素はオブジェクトのみ（基本型は不可）
// ⚠️ forEach / size / iteration は存在しない
```

---

## 7. 型付き配列と ArrayBuffer

### 7.1 型付き配列の種類

| 型 | 説明 | 範囲 |
|----|------|------|
| `Int8Array` | 8bit 符号あり整数 | -128 〜 127 |
| `Uint8Array` | 8bit 符号なし整数 | 0 〜 255 |
| `Uint8ClampedArray` | 8bit 符号なし（クランプ） | HTMLCanvas 用 |
| `Int16Array` | 16bit 符号あり | -32768 〜 32767 |
| `Uint16Array` | 16bit 符号なし | 0 〜 65535 |
| `Int32Array` | 32bit 符号あり | |
| `Uint32Array` | 32bit 符号なし | |
| `Float32Array` | 32bit 浮動小数点 | |
| `Float64Array` | 64bit 浮動小数点 | |

```javascript
// 構築（長さ固定、後から変更不可）
const iarr = new Int32Array(1024)         // 全要素 0
const farr = Float32Array.of(1, 0.5, 0.25)
const uarr = Uint32Array.from(farr, x => 1 / x)

// push/pop/shift/unshift/flat/flatMap は使用不可（サイズ変更系）
// concat の代わりに set を使う
const target = new Int32Array(a.length + b.length)
target.set(a, 0)
target.set(b, a.length)

// subarray — 元のバッファを共有するビュー（slice とは異なる）
const sub = iarr.subarray(16, 32)
sub[0] = 1024  // iarr[16] も 1024 になる
```

### 7.2 ArrayBuffer と DataView

```javascript
// ArrayBuffer — 連続バイトシーケンス
const buf = new ArrayBuffer(1024)

// DataView — 複雑なバイナリフォーマットを読み書き
const view = new DataView(buf)
const value = view.getUint32(offset, /* littleEndian */ true)
view.setUint32(offset, newValue, true)

// 型付き配列でバッファを解釈（エンディアンはホスト依存）
const arr = new Uint16Array(buf)  // 512個の Uint16
```

---

## 8. 判断テーブル

| 状況 | 推奨 |
|------|------|
| 数値が NaN かチェック | `Number.isNaN(x)` ← グローバル版は禁止 |
| 文字列を正しくコードポイント分割 | `[...str]` ← `str.split('')` は禁止 |
| 文字列切り出し | `slice` ← `substring` は引数交換の挙動あり |
| 正規表現で非ASCII文字 | `u` フラグ必須 |
| キー付きデータ構造 | `Map` ← プレーンオブジェクトより安全 |
| 重複排除 | `new Set([...arr])` |
| DOM ノードにメタデータ付加 | `WeakMap` ← GC フレンドリー |
| 効率的な数値バッファ | 型付き配列 + `ArrayBuffer` |
| BigInt が必要な場面 | 暗号・大整数計算（`n` サフィックス） |
