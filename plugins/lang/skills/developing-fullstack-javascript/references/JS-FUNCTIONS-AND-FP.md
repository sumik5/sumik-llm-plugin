# JavaScript 関数と関数型プログラミング

JavaScriptは「関数型」プログラミング言語であり、関数は数や文字列と同じ**ファーストクラスの値**だ。
変数に入れ、引数として渡し、戻り値として返すことができる。

---

## 1. 関数の宣言スタイル

### 1.1 関数宣言（function declaration）

```javascript
function average(x, y) {
  return (x + y) / 2
}
```

- **ホイスティング**される（ファイル先頭に巻き上げられる）ため、宣言より前に呼び出せる
- 相互再帰を書くときに便利
- トップレベルの名前付き関数に適している

### 1.2 関数式（function expression）

```javascript
const average = function (x, y) { return (x + y) / 2 }
```

- 変数に束縛することで名前を付ける
- ホイスティングされない（`let`/`const` の一時的デッドゾーンが適用される）

### 1.3 アロー関数（arrow function）

```javascript
// 式ボディ（暗黙のreturn）
const average = (x, y) => (x + y) / 2

// パラメータ1個は括弧省略可
const double = x => x * 2

// パラメータなし
const dieToss = () => Math.trunc(Math.random() * 6) + 1

// ブロックボディ（明示的 return が必要）
const indexOf = (arr, value) => {
  for (let i in arr) {
    if (arr[i] === value) return i
  }
  return -1
}

// オブジェクトリテラルを返す場合は丸括弧で囲む
const stats = (x, y) => ({
  average: (x + y) / 2,
  distance: Math.abs(x - y)
})
```

**アロー vs function の使い分け**

| 用途 | 推奨 |
|------|------|
| コールバック・インライン関数 | アロー関数（`this` バインドが正規で混乱しない） |
| トップレベル名前付き関数 | どちらでも可（好みの問題） |
| メソッド（オブジェクトリテラル） | 通常の `function` か省略記法を使う（アローは `this` を持たない） |
| コンストラクタ | `class` 構文を使う（アローは `new` 不可） |

> **落とし穴**: アロー `=>` トークンはパラメータリストと同じ行に置く必要がある。
> ```javascript
> const distance = (x, y) // Error: 改行後に => を置けない
>   => Math.abs(x - y)
> ```

---

## 2. 高階関数パターン

関数は変数に格納でき、引数として渡せ、戻り値として返せる。

```javascript
let f = average       // 関数を変数に格納
f(6, 7)               // → 6.5

f = Math.max          // 別の関数に差し替え
f(6, 7)               // → 7

// 関数を引数として渡す（高階関数）
[0, 1, 2, 4].map(Math.sqrt)  // → [0, 1, 1.414..., 2]
```

---

## 3. 配列メソッドチェーン（関数型パイプライン）

`forEach`/`map`/`filter`/`reduce`/`flatMap` を組み合わせて「何をするか」を宣言的に表現する。

### 3.1 forEach

副作用のためだけに使う（戻り値なし）。

```javascript
arr.forEach((element, index) => {
  console.log(`${index}: ${element}`)
})
```

### 3.2 map

各要素を変換して新しい配列を返す（元の配列は変更しない）。

```javascript
const enclose = (tag, contents) => `<${tag}>${contents}</${tag}>`
const listItems = items.map(i => enclose('li', i))
```

### 3.3 filter

述語関数（真偽値を返す関数）を満たす要素だけを残す。

```javascript
const nonEmpty = items.filter(i => i.trim() !== '')
```

### 3.4 パイプラインの構築

```javascript
const list = enclose('ul',
  items
    .filter(i => i.trim() !== '')   // 空文字を除去
    .map(htmlEscape)                // HTML エスケープ
    .map(i => enclose('li', i))     // li タグで囲む
    .join('')                       // 文字列に連結
)
```

> **ポイント**: 「どうやって」ではなく「何をするか」を記述するのが関数型スタイルの本質。
> ループと分岐は実装の詳細にすぎない。

### 3.5 reduce

配列を単一の値に集約する。

```javascript
const sum = [1, 2, 3, 4].reduce((acc, val) => acc + val, 0)  // → 10
```

### 3.6 flatMap

map + flat（ネストした配列を1段階平坦化）。

```javascript
const sentences = ['Hello World', 'Foo Bar']
const words = sentences.flatMap(s => s.split(' '))
// → ['Hello', 'World', 'Foo', 'Bar']
```

---

## 4. クロージャとスコープキャプチャ

### 4.1 クロージャとは

関数は **コード + パラメータ + 自由変数** の3成分で構成される。
**自由変数**（パラメータでもローカル変数でもない変数）を持つ関数を「クロージャ」と呼ぶ。

```javascript
const sayLater = (text, when) => {
  let task = () => console.log(text)  // text は自由変数（キャプチャされる）
  setTimeout(task, when)
}

sayLater('Hello', 1000)    // 1秒後に 'Hello'
sayLater('Goodbye', 10000) // 10秒後に 'Goodbye'
```

各 `sayLater` 呼び出しで独立したクロージャが作られ、それぞれ別の `text` 変数をキャプチャする。

### 4.2 参照キャプチャの落とし穴

JavaScriptのクロージャは**値ではなく変数への参照**をキャプチャする。

```javascript
let text = 'Goodbye'
setTimeout(() => console.log(text), 10000)
text = 'Hello'
// → 10秒後に 'Hello' が表示される（'Goodbye' ではない）
```

---

## 5. 堅いオブジェクト（ファクトリーパターン）

クロージャを使ってプライベート状態を持つオブジェクトを作る。
`this` 問題を回避しながらカプセル化を実現する。

```javascript
const createAccount = (initialBalance = 0) => {
  let balance = initialBalance + 10  // ローカル変数（外部からアクセス不可）

  return Object.freeze({
    deposit: amount => {
      balance += amount
    },
    withdraw: amount => {
      if (balance >= amount) balance -= amount
    },
    getBalance: () => balance
  })
}

const harrysAccount = createAccount()
const sallysAccount = createAccount(500)
sallysAccount.deposit(100)
sallysAccount.getBalance()  // → 610
```

**2つの利点**:
1. **自動カプセル化**: データはファクトリー関数のローカル変数に存在し、外部から書き換え不可
2. **this 回避**: アロー関数を使うため `this` バインドの問題が発生しない

> `Object.freeze()` でメソッドの追加・変更・削除も禁止できる（より堅固なオブジェクト）。

---

## 6. strictモード

### 6.1 有効化

```javascript
'use strict'  // ファイル先頭（コメント以外）に記述
```

> クラスと ESモジュール（`import`/`export`）では**自動的に strict モードが有効**になる。
> モダンな開発では明示的な `'use strict'` が不要なケースが多い。

### 6.2 主な制約

| 禁止事項 | 非strict での挙動 | strict での挙動 |
|---------|----------------|----------------|
| 未宣言変数への代入 | グローバル変数が作成される | `ReferenceError` |
| `NaN`/`undefined` への代入 | 暗黙に無視される | `TypeError` |
| 重複パラメータ名 | 許可される | `SyntaxError` |
| `0`プリフィックス8進数 (`010`) | 8 として解釈 | `SyntaxError` |
| `with` 文 | 許可される | `SyntaxError` |

> **未宣言変数の読み取り確認**: `typeof` を使う
> ```javascript
> typeof possiblyUndefinedVariable !== 'undefined'  // ✅ safe
> possiblyUndefinedVariable !== undefined            // ❌ ReferenceError の可能性
> ```

---

## 7. 引数パターン

### 7.1 引数の過多・過少

```javascript
const average = (x, y) => (x + y) / 2

average(3, 4, 5)  // → 3.5（余分な引数は無視）
average(3)        // → NaN（y が undefined になる）
```

### 7.2 デフォルト引数

```javascript
const average = (x = 0, y = x) => (x + y) / 2

average()      // → 0（x=0, y=0）
average(3)     // → 3（x=3, y=3）
average(3, 7)  // → 5（x=3, y=7）
```

- `undefined` を明示的に渡した場合もデフォルト値が使われる
- `null` を渡した場合はデフォルト値は使われない（`null !== undefined`）

### 7.3 rest パラメータ（可変長引数）

最後のパラメータの前に `...` を付けて、残りの引数を配列として受け取る。

```javascript
const average = (first = 0, ...following) => {
  let sum = first
  for (const value of following) { sum += value }
  return sum / (1 + following.length)
}

average(1, 7, 2, 9)  // → 4.75
```

### 7.4 spread 演算子（配列の展開）

配列を個別の引数として展開する。rest の**逆操作**。

```javascript
const numbers = [1, 7, 2, 9]
Math.max(...numbers)   // → 9（Math.max(1, 7, 2, 9) と同等）

// 配列の連結にも使える
const more = [1, 2, 3, ...numbers]  // → [1, 2, 3, 1, 7, 2, 9]

// 文字列も展開可能（イテラブル）
const chars = [..."Hello"]  // → ['H', 'e', 'l', 'l', 'o']
```

> **rest vs spread の見分け方**:
> - **宣言側**（パラメータリスト）の `...` → rest（値のシーケンスを配列にまとめる）
> - **呼び出し側**（引数リスト・配列リテラル）の `...` → spread（配列を値のシーケンスに展開する）

### 7.5 名前付き引数パターン（分割代入 + デフォルト値）

```javascript
// 呼び出し側: キーワード形式で引数を渡せる
const result = mkString(values, { separator: ';', leftDelimiter: '(' })

// 実装側: 分割代入でデフォルト値も設定
const mkString = (array, {
  separator = ',',
  leftDelimiter = '[',
  rightDelimiter = ']'
} = {}) => {
  // separator, leftDelimiter, rightDelimiter が直接使える
  return leftDelimiter + array.join(separator) + rightDelimiter
}

mkString([1, 2, 3])                     // → '[1,2,3]'
mkString([1, 2, 3], { separator: ';' }) // → '[1;2;3]'
```

> 最後の `= {}` により、設定オブジェクトを省略して呼び出せる。

### 7.6 引数の型チェック

| 型 | チェック方法 |
|----|------------|
| 文字列 | `typeof x === 'string' \|\| x instanceof String` |
| 数値 | `typeof x === 'number' \|\| x instanceof Number` |
| 配列 | `Array.isArray(x)` |
| 関数 | `typeof x === 'function'` |
| 正規表現 | `x instanceof RegExp` |
| null | `x === null` |
| undefined | `x === undefined` または `typeof x === 'undefined'` |

---

## 8. ホイスティング（巻き上げ）

### 回避ルール（3つ守れば問題なし）

1. `var` を使わない → `let`/`const` を使う
2. `'use strict'` を使う（またはモジュール/クラスを使う）
3. 変数と関数は使う前に宣言する

### 知っておくべき挙動

- `function` 宣言はスコープ先頭に巻き上げられる（宣言前に呼び出し可能）
- `let`/`const` も巻き上げられるが、**一時的デッドゾーン**（TDZ）により宣言前のアクセスは `ReferenceError`
- `var` は巻き上げられ、初期化前は `undefined`（バグの温床）

```javascript
// 相互再帰（function 宣言のホイスティングを活用）
function isEven(n) { return n === 0 ? true  : isOdd(n - 1) }
function isOdd(n)  { return n === 0 ? false : isEven(n - 1) }
```

---

## 9. 例外処理

### 9.1 例外の送出（throw）

```javascript
const divide = (x, y) => {
  if (y === 0) throw Error('Division by zero')
  return x / y
}
```

- `throw` すると関数は即座に終了（戻り値も `undefined` も生成されない）
- 値には任意の型を使えるが、**`Error` オブジェクトを使うのが慣例**
- 組み込みのエラー型: `Error`、`SyntaxError`、`TypeError`、`RangeError`、`ReferenceError`

> **いつ例外を使うか**: 予測不能・回復不能な状況に使う。
> ユーザー入力ミスのような「よくある失敗」には `null`/`undefined`/エラーオブジェクトを返す方が適切なことが多い。

### 9.2 例外のキャッチ（try/catch）

```javascript
try {
  const data = JSON.parse(userInput)
  process(data)
} catch (e) {
  // e.name: エラー種別（'SyntaxError' 等）
  // e.message: エラーメッセージ
  console.error(`${e.name}: ${e.message}`)
  // 上位に委ねる場合は再送出
  throw e
}
```

> JavaScriptの `catch` は**すべての例外をキャッチする**（型による絞り込みは不可）。
> エラーの種別が重要な場合は `e.name` や `e instanceof TypeError` で判定する。

### 9.3 finally節（リソース解放）

```javascript
let resource = null
try {
  resource = acquireResource()
  // 何かの処理
} catch (e) {
  console.error(e)
} finally {
  // 例外の有無にかかわらず必ず実行
  if (resource) resource.release()
}
```

`finally` が実行されるタイミング:
- `try` が正常完了した場合
- `try` 内で `return`/`break` が実行された場合
- `try` 内で例外が発生した場合（`catch` 後も実行）

> **アンチパターン**: `finally` 内に `return`/`throw` を書かない。
> `try` や `catch` 内の戻り値を上書きしてしまい、デバッグが困難になる。

---

## 10. 判断テーブル

| 状況 | 推奨アプローチ |
|------|--------------|
| 使い捨てのコールバック | アロー関数のインライン定義 |
| 複数箇所で再利用 | `const fn = (...) => ...` で変数に格納 |
| 状態を持つオブジェクト | ファクトリー関数（堅いオブジェクト）|
| オプション引数が多い | 名前付き引数パターン（分割代入 + デフォルト）|
| 可変長引数 | rest パラメータ (`...args`) |
| 配列を個別引数として渡す | spread 演算子 (`...array`) |
| 予測不能なエラー | `throw Error(...)` + `try/catch` |
| よくある失敗ケース | `null`/`undefined`/エラーオブジェクトを返す |
