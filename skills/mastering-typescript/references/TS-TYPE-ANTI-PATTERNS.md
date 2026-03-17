# 避けるべきコード規則（アンチパターン）- TypeScript編

このファイルでは、TypeScript/JavaScriptで避けるべきコードパターンを説明します。

## 📋 目次

- [共通アンチパターン（TypeScript）](#共通アンチパターン-typescript)
- [TypeScript固有のアンチパターン](#typescript固有のアンチパターン)
- [その他の一般的なアンチパターン](#その他の一般的なアンチパターン)

## 🚫 共通アンチパターン（TypeScript）

### 1. マジックナンバー

#### ❌ 悪い例

```typescript
// TypeScript
function calculateDiscount(price: number): number {
  if (price > 10000) {
    return price * 0.1  // 0.1って何？
  }
  return 0
}
```

**問題点**:
- 数値の意味が不明
- 変更時に漏れが発生しやすい
- テストが困難

#### ✅ 良い例

```typescript
// TypeScript
const DISCOUNT_THRESHOLD = 10000
const DISCOUNT_RATE = 0.1

function calculateDiscount(price: number): number {
  if (price > DISCOUNT_THRESHOLD) {
    return price * DISCOUNT_RATE
  }
  return 0
}
```

### 2. グローバル変数の濫用

#### ❌ 悪い例

```typescript
// TypeScript - グローバル変数
let userCache: Map<string, User> = new Map()

function getUser(id: string): User {
  return userCache.get(id)!  // グローバル状態に依存
}

function setUser(user: User): void {
  userCache.set(user.id, user)  // 副作用
}
```

**問題点**:
- テストが困難
- 並行処理で問題が発生
- 依存関係が不明確

#### ✅ 良い例

```typescript
// TypeScript - 依存性注入
class UserRepository {
  private cache = new Map<string, User>()

  getUser(id: string): User | undefined {
    return this.cache.get(id)
  }

  setUser(user: User): void {
    this.cache.set(user.id, user)
  }
}

// 使用時
const userRepo = new UserRepository()
const user = userRepo.getUser('123')
```

### 3. 過度なネスト

#### ❌ 悪い例

```typescript
// TypeScript
function processUser(user: User | null): string {
  if (user !== null) {
    if (user.profile !== null) {
      if (user.profile.name !== null) {
        if (user.profile.name.length > 0) {
          return user.profile.name
        }
      }
    }
  }
  return 'Unknown'
}
```

**問題点**:
- 可読性が低い
- 保守が困難
- バグが混入しやすい

#### ✅ 良い例

```typescript
// TypeScript - 早期リターン
function processUser(user: User | null): string {
  if (!user) return 'Unknown'
  if (!user.profile) return 'Unknown'
  if (!user.profile.name) return 'Unknown'
  if (user.profile.name.length === 0) return 'Unknown'

  return user.profile.name
}

// さらに良い: オプショナルチェイニング
function processUserBetter(user: User | null): string {
  return user?.profile?.name || 'Unknown'
}
```

### 4. 巨大な関数

#### ❌ 悪い例

```typescript
// TypeScript - 100行を超える巨大関数
function processOrder(order: Order): OrderResult {
  // 検証処理（20行）
  // 在庫確認（30行）
  // 支払い処理（30行）
  // 通知送信（20行）
  // 合計100行以上...
}
```

**問題点**:
- 単一責任の原則違反
- テストが困難
- 再利用できない

#### ✅ 良い例

```typescript
// TypeScript - 小さな関数に分割
function processOrder(order: Order): OrderResult {
  validateOrder(order)
  checkInventory(order)
  processPayment(order)
  sendNotification(order)
  return createResult(order)
}

function validateOrder(order: Order): void {
  // 検証処理のみ（5-10行）
}

function checkInventory(order: Order): void {
  // 在庫確認のみ（5-10行）
}

function processPayment(order: Order): void {
  // 支払い処理のみ（5-10行）
}

function sendNotification(order: Order): void {
  // 通知送信のみ（5-10行）
}
```

### 5. コメントアウトされたコード

#### ❌ 悪い例

```typescript
// TypeScript
function calculateTotal(items: Item[]): number {
  // const tax = 0.1  // 古い税率
  const tax = 0.08
  // return items.reduce((sum, item) => sum + item.price, 0)  // 古い実装
  return items.reduce((sum, item) => sum + item.price * (1 + tax), 0)
}
```

**問題点**:
- コードが肥大化
- 混乱を招く
- バージョン管理で履歴を見れば十分

#### ✅ 良い例

```typescript
// TypeScript - コメントアウトされたコードは削除
function calculateTotal(items: Item[]): number {
  const tax = 0.08
  return items.reduce((sum, item) => sum + item.price * (1 + tax), 0)
}
```

## 🔴 TypeScript固有のアンチパターン

### 1. `==` の使用（厳密等価演算子の不使用）

#### ❌ 悪い例

```typescript
// ❌ == は暗黙的な型変換を行う
if (value == null) { }  // null と undefined の両方にマッチ
if (count == '0') { }   // 数値0と文字列'0'が等しいと判定される
if (flag == 1) { }      // true と 1 が等しいと判定される
```

**問題点**:
- 暗黙的な型変換で予期しない動作
- バグの原因になりやすい
- 意図が不明確

#### ✅ 良い例

```typescript
// ✅ === を使用（厳密等価演算子）
if (value === null || value === undefined) { }
// または
if (value == null) { }  // このケースのみ例外的に許容される場合もある

if (count === 0) { }  // 数値として比較
if (flag === true) { }  // 真偽値として比較
```

### 2. 暗黙的な型変換への依存

#### ❌ 悪い例

```typescript
// ❌ 暗黙的な型変換に依存
const num = +'42'  // 文字列を数値に変換
const str = 42 + ''  // 数値を文字列に変換
const bool = !!value  // 値を真偽値に変換

if (value) {  // 0, '', null, undefined, false, NaN すべてfalsy
  // ...
}
```

**問題点**:
- 意図が不明確
- バグの原因
- 可読性が低い

#### ✅ 良い例

```typescript
// ✅ 明示的な型変換
const num = Number('42')  // または parseInt('42', 10)
const str = String(42)  // または 42.toString()
const bool = Boolean(value)

// ✅ 明示的な条件チェック
if (value !== null && value !== undefined && value !== '') {
  // ...
}
```

### 3. `Function` 型の使用

#### ❌ 悪い例

```typescript
// ❌ Function型は any と同等
const handler: Function = (x: number) => x * 2
const callback: Function = () => {}

function execute(fn: Function): any {
  return fn()  // 引数・戻り値の型が不明
}
```

**問題点**:
- 引数と戻り値の型が不明
- 型安全性が失われる

#### ✅ 良い例

```typescript
// ✅ 具体的な関数シグネチャを定義
type Handler = (x: number) => number
const handler: Handler = (x) => x * 2

type Callback = () => void
const callback: Callback = () => {}

function execute<T>(fn: () => T): T {
  return fn()
}
```

### 4. 配列操作で `for...in` の使用

#### ❌ 悪い例

```typescript
// ❌ for...in は配列に使用してはいけない
const items = [1, 2, 3]
for (const index in items) {
  console.log(items[index])  // indexは文字列型
}
```

**問題点**:
- `index` が文字列型
- プロトタイプチェーンのプロパティも列挙される
- 順序が保証されない場合がある

#### ✅ 良い例

```typescript
// ✅ for...of または Array methods を使用
const items = [1, 2, 3]

// for...of
for (const item of items) {
  console.log(item)
}

// forEach
items.forEach(item => console.log(item))

// インデックスが必要な場合
items.forEach((item, index) => console.log(index, item))
```

### 5. プリミティブ型のラッパーオブジェクト使用

#### ❌ 悪い例

```typescript
// ❌ String, Number, Boolean のラッパーオブジェクト
const str: String = new String('hello')  // オブジェクト型
const num: Number = new Number(42)
const bool: Boolean = new Boolean(true)
```

**問題点**:
- プリミティブ型ではなくオブジェクト型
- 比較演算子で期待通りに動作しない
- 混乱を招く

#### ✅ 良い例

```typescript
// ✅ プリミティブ型を使用
const str: string = 'hello'
const num: number = 42
const bool: boolean = true
```

## 🔧 その他の一般的なアンチパターン

### 1. 過度なコメント

#### ❌ 悪い例

```typescript
// ❌ 自明なコメント
// ユーザーIDを取得する
function getUserId(): string {
  // user変数からidプロパティを取得
  return user.id  // idを返す
}
```

**問題点**:
- コードを読めば分かることを重複して書いている
- メンテナンスコストが増加

#### ✅ 良い例

```typescript
// ✅ コメントは「なぜ」を説明する
function calculateDiscount(price: number): number {
  // 2024年3月のキャンペーン期間中は特別割引を適用
  // 通常の10%割引に加えて5%の追加割引
  const baseDiscount = 0.10
  const campaignDiscount = 0.05
  return price * (1 - baseDiscount - campaignDiscount)
}
```

### 2. 長すぎる引数リスト

#### ❌ 悪い例

```typescript
// ❌ 引数が多すぎる
function createUser(
  id: string,
  firstName: string,
  lastName: string,
  email: string,
  age: number,
  address: string,
  phone: string,
  country: string,
  isActive: boolean
): User {
  // ...
}
```

**問題点**:
- 引数の順序を覚えるのが困難
- 呼び出し時にミスしやすい
- 可読性が低い

#### ✅ 良い例

```typescript
// ✅ オプションオブジェクトを使用
interface CreateUserParams {
  id: string
  firstName: string
  lastName: string
  email: string
  age: number
  address: string
  phone: string
  country: string
  isActive: boolean
}

function createUser(params: CreateUserParams): User {
  // ...
}

// 使用時
createUser({
  id: '123',
  firstName: 'John',
  lastName: 'Doe',
  email: 'john@example.com',
  age: 30,
  address: '123 Main St',
  phone: '555-1234',
  country: 'US',
  isActive: true
})
```

### 3. 意味のない変数名

#### ❌ 悪い例

```typescript
// ❌ 意味不明な変数名
const x = getUserById('123')
const tmp = calculateTotal(items)
const data = fetchData()
const result = processData(data)
```

**問題点**:
- 変数の目的が不明
- コードの理解が困難

#### ✅ 良い例

```typescript
// ✅ 意図が明確な変数名
const currentUser = getUserById('123')
const orderTotal = calculateTotal(items)
const customerData = fetchCustomerData()
const validatedOrder = validateOrder(customerData)
```

## 🔗 関連ファイル

- **[INSTRUCTIONS.md](../INSTRUCTIONS.md)** - mastering-typescript 概要に戻る
- **[TS-TYPE-SAFETY.md](./TS-TYPE-SAFETY.md)** - TypeScript型安全性詳細
- **[TS-TYPE-REFERENCE.md](./TS-TYPE-REFERENCE.md)** - チェックリストとツール設定
