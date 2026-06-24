# JavaScript OOP・プロトタイプ・this リファレンス

JavaScriptにおけるオブジェクト指向プログラミング、プロトタイプチェーン、class構文、`this`バインドの実践ガイド。

---

## 1. プロトタイプチェーン

### 仕組み

JavaScriptのすべてのオブジェクトは、内部スロット `[[Prototype]]` を持つ。プロパティ検索は「オブジェクト自身 → プロトタイプ → そのプロトタイプ...」と連鎖し、`null` に到達するまで続く（プロトタイプチェーン）。

```
harry → Employee.prototype → Object.prototype → null
```

プロパティの**読み込み**はチェーンを辿るが、**書き込み**は常にオブジェクト自身に対して行われる。

### プロトタイプへのアクセス

```javascript
// ✅ 正式API（推奨）
Object.getPrototypeOf(obj)
Object.setPrototypeOf(obj, proto)

// ❌ 非標準（非推奨）
obj.__proto__
```

### Object.create によるプロトタイプ指定

```javascript
const employeeProto = {
  raiseSalary(percent) {
    this.salary *= 1 + percent / 100
  }
}

function createEmployee(name, salary) {
  const obj = Object.create(employeeProto)
  obj.name = name
  obj.salary = salary
  return obj
}
```

### instanceof の仕組み

`instanceof` はプロトタイプチェーンを遡り、コンストラクタの `prototype` が含まれるかを確認する。

```javascript
boss instanceof Employee  // Employee.prototype がチェーンに存在すれば true
boss instanceof Object    // 常に true（すべてのオブジェクトが Object.prototype を持つ）
```

---

## 2. class 構文（ES2015+）

### 基本構造

`class` はコンストラクタ関数 + `prototype` オブジェクトを宣言する「構文糖」。実体はプロトタイプチェーン。

```javascript
class Employee {
  constructor(name, salary) {
    this.name = name
    this.salary = salary
  }

  raiseSalary(percent) {
    this.salary *= 1 + percent / 100
  }
}

const harry = new Employee('Harry Smith', 90000)
```

**class 宣言の規則:**
- `constructor` は最大1個
- `constructor` なし → 空コンストラクタが自動生成
- メソッド間にカンマ不要（オブジェクトリテラルとの違い）
- class はホイスティングされない（宣言より前に使用不可）
- class の本体は自動的に strict モードで実行される

### new 演算子の5ステップ

1. 空のオブジェクトを新規作成
2. `[[Prototype]]` に `ConstructorFn.prototype` を設定
3. `this = 新規オブジェクト` としてコンストラクタ呼び出し
4. コンストラクタがプロパティを設定
5. 新規オブジェクトを返す（コンストラクタの戻り値は無視される）

> **注意:** コンストラクタで値を `return` してはならない。

---

## 3. ゲッター / セッター

プロパティのように見えるが、アクセス時にメソッドが実行される「動的プロパティ」。

```javascript
class Person {
  constructor(last, first) {
    this.last = last
    this.first = first
  }

  get fullName() {
    return `${this.last}, ${this.first}`
  }

  set fullName(value) {
    const parts = value.split(/,\s*/)
    this.last = parts[0]
    this.first = parts[1]
  }
}

const p = new Person('Smith', 'Harry')
console.log(p.fullName)       // 'Smith, Harry'
p.fullName = 'Smith, Harold'  // セッター呼び出し
```

**用途:** バリデーション、算出プロパティ、カプセル化。

---

## 4. プライベートフィールド・メソッド（ES2022+）

`#` プレフィックスでプライベートになる。クラスメソッドの外からアクセスすると **SyntaxError**。

```javascript
class BankAccount {
  #balance = 0                    // プライベートフィールド宣言
  #transactionLog = []

  deposit(amount) {
    if (amount <= 0) throw new Error('Invalid amount')
    this.#balance += amount
    this.#log('deposit', amount)  // プライベートメソッド呼び出し
  }

  #log(type, amount) {            // プライベートメソッド
    this.#transactionLog.push({ type, amount, date: new Date() })
  }

  get balance() { return this.#balance }
}
```

**注意:** フィールド宣言（`= 0`）はクラス本体に記述が必要（`constructor` より前でも後でも可）。

---

## 5. static メソッド・フィールド

インスタンスではなく**クラス自体**に属する。ユーティリティ関数・定数・ファクトリメソッドに使う。

```javascript
class BankAccount {
  static #OVERDRAFT_FEE = 30     // プライベートstaticフィールド

  static get OVERDRAFT_FEE() {
    return this.#OVERDRAFT_FEE
  }

  static set OVERDRAFT_FEE(newValue) {
    if (newValue > this.#OVERDRAFT_FEE) {
      this.#OVERDRAFT_FEE = newValue
    }
  }

  static percentOf(amount, rate) {  // staticユーティリティメソッド
    return amount * rate / 100
  }

  addInterest(rate) {
    // staticメソッドはクラス名で呼び出す
    this.#balance += BankAccount.percentOf(this.#balance, rate)
  }
}
```

---

## 6. 継承（extends / super）

### extends による継承

```javascript
class Manager extends Employee {
  constructor(name, salary, bonus) {
    super(name, salary)  // ① super() を最初に呼び出す
    this.bonus = bonus   // ② this が有効になるのは super() の後
  }

  getSalary() {
    return super.getSalary() + this.bonus  // スーパークラスのメソッドを呼び出す
  }
}
```

**ルール:**
- `super()` はコンストラクタ内で `this` 参照より前に呼ぶ
- コンストラクタを省略すると、全引数をスーパークラスに委譲するコンストラクタが自動生成
- ゲッター/セッターも `super` でオーバーライド可能

### 多相性（ポリモーフィズム）

プロトタイプチェーンの解決順により、実行時のオブジェクト型に応じたメソッドが呼ばれる。

```javascript
const empl = isManager ? new Manager(/*...*/) : new Employee(/*...*/)
empl.getSalary()  // 実際の型に応じて Manager か Employee のメソッドを呼び出す
```

### 継承 vs コンポジション

| 判断基準 | 継承（extends） | コンポジション（委譲） |
|---------|--------------|----------------|
| 関係 | is-a（〜である） | has-a（〜を持つ） |
| 使うとき | サブクラスが完全にスーパークラスの代替になれる場合 | 機能を組み合わせたい場合 |
| 注意点 | 深い継承階層はリファクタリングが困難 | 柔軟だが委譲コードが増える |

> **原則:** 3階層以上の継承は避ける。共通機能は **ミックスイン** か **コンポジション** で実現する。

### ミックスイン（class 式の活用）

```javascript
const withToString = Base =>
  class extends Base {
    toString() {
      return JSON.stringify(this)
    }
  }

const PrettyEmployee = withToString(Employee)
const e = new PrettyEmployee('Harry Smith', 90000)
console.log(e.toString())  // {"name":"Harry Smith","salary":90000}
```

---

## 7. this バインドの5ルール

`this` の値は、**関数の定義場所ではなく呼び出し方**によって決まる（アロー関数を除く）。

| ルール | 呼び出しパターン | this の値 |
|--------|--------------|-----------|
| 1. メソッド呼び出し | `obj.method()` | `obj` |
| 2. 通常関数呼び出し | `fn()` | `undefined`（strict mode） |
| 3. new 演算子 | `new Constructor()` | 新規オブジェクト |
| 4. アロー関数 | 定義時の外側スコープを継承 | レキシカル（静的） |
| 5. 明示的バインド | `fn.call(obj)` / `fn.apply(obj)` / `fn.bind(obj)` | 指定した `obj` |

### よくある落とし穴と対処

```javascript
// ❌ コールバック内で function を使うと this が undefined
class BankAccount {
  spreadTheWealth(accounts) {
    accounts.forEach(function(account) {
      account.deposit(this.balance / accounts.length) // this === undefined
    })
  }
}

// ✅ アロー関数を使う（外側の this を継承）
class BankAccount {
  spreadTheWealth(accounts) {
    accounts.forEach(account => {
      account.deposit(this.balance / accounts.length) // this === BankAccount インスタンス
    })
    this.balance = 0
  }
}
```

### bind / call / apply の使い分け

```javascript
function greet(greeting, punctuation) {
  return `${greeting}, ${this.name}${punctuation}`
}

const user = { name: 'Harry' }

// call: 引数をカンマ区切りで渡す（1回呼び出し）
greet.call(user, 'Hello', '!')       // 'Hello, Harry!'

// apply: 引数を配列で渡す（1回呼び出し）
greet.apply(user, ['Hello', '!'])    // 'Hello, Harry!'

// bind: 新しい関数を返す（後で呼び出す）
const boundGreet = greet.bind(user)
boundGreet('Hello', '!')             // 'Hello, Harry!'

// bind で引数も固定（部分適用）
const sayHello = greet.bind(user, 'Hello')
sayHello('!')   // 'Hello, Harry!'
sayHello('??')  // 'Hello, Harry??'
```

| メソッド | 戻り値 | 引数渡し | 用途 |
|--------|-------|---------|------|
| `call` | 実行結果 | カンマ区切り | 即時呼び出し |
| `apply` | 実行結果 | 配列 | 配列を引数として展開したいとき |
| `bind` | 新しい関数 | カンマ区切り | コールバックとして渡すとき・部分適用 |

---

## 8. this を安全に使うための原則

1. **メソッド・コンストラクタ内では `this` を自由に使う** → 問題なし
2. **コールバックには必ずアロー関数を使う** → `this` が外側スコープを参照する
3. **`function` 宣言の内側で `this` を使わない** → 予測不能な挙動を防ぐ
4. **`class` 構文を使う** → `new` なし呼び出しをランタイムエラーで防止
5. **メソッドを変数に取り出して呼ぶ場合は `bind` する**

```javascript
// ❌ メソッドをバラして渡すと this が失われる
const deposit = harrysAccount.deposit
deposit(500)  // エラー: this.balance が undefined

// ✅ bind で束縛してから渡す
const deposit = harrysAccount.deposit.bind(harrysAccount)
deposit(500)  // 正常動作
```

---

## 9. class 設計チェックリスト

- [ ] `class` 構文を使っているか（コンストラクタ関数直書きを避ける）
- [ ] センシティブなデータは `#` プライベートフィールドにしているか
- [ ] 継承は is-a 関係か（has-a なら コンポジション/ミックスインを検討）
- [ ] コールバック内に `function` キーワードを使っていないか
- [ ] メソッドを切り出して渡す場合、`bind` しているか
- [ ] サブクラスのコンストラクタで `super()` を最初に呼んでいるか
- [ ] ゲッター/セッターでバリデーションを実装しているか
