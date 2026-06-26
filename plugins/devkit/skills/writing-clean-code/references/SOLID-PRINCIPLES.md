# SOLID原則の詳細

5つのSOLID原則を詳細に解説します。各原則について、悪い例と良い例を対比して説明します。

## 📋 目次
1. [Single Responsibility Principle](#1-single-responsibility-principle単一責任の原則)
2. [Open/Closed Principle](#2-openclosed-principle開放閉鎖の原則)
3. [Liskov Substitution Principle](#3-liskov-substitution-principleリスコフの置換原則)
4. [Interface Segregation Principle](#4-interface-segregation-principleインターフェース分離の原則)
5. [Dependency Inversion Principle](#5-dependency-inversion-principle依存関係逆転の原則)

---

## 1. Single Responsibility Principle（単一責任の原則）

### 定義
**各クラス・関数は単一の責任のみを持つ**

「変更する理由」が1つだけになるように設計します。

### なぜ重要か
- **保守性向上**: 変更の影響範囲が限定される
- **テストしやすい**: 単一の機能のみをテストすればよい
- **再利用性**: 責任が明確な部品は再利用しやすい

### ❌ 悪い例: 複数の責任を持つクラス
```typescript
class User {
  name: string
  email: string

  // ❌ ユーザークラスがDB操作の責任を持っている
  saveToDatabase() {
    const db = new Database()
    db.insert('users', this)
  }

  // ❌ ユーザークラスがメール送信の責任を持っている
  sendEmail(subject: string, body: string) {
    const emailService = new EmailService()
    emailService.send(this.email, subject, body)
  }

  // ❌ ユーザークラスがレポート生成の責任を持っている
  generateReport(): string {
    return `User Report: ${this.name} (${this.email})`
  }
}
```

**問題点**:
- DBスキーマ変更時にUserクラスを修正
- メール送信ロジック変更時にUserクラスを修正
- レポート形式変更時にUserクラスを修正
- テストが複雑（DB、メール、レポートすべてをモック）

### ✅ 良い例: 責任を分離
```typescript
// ユーザーエンティティ: データ保持のみ
class User {
  constructor(
    public readonly name: string,
    public readonly email: string
  ) {}
}

// DB操作の責任を分離
class UserRepository {
  save(user: User): void {
    const db = new Database()
    db.insert('users', user)
  }

  findById(id: string): User | null {
    const db = new Database()
    return db.findOne('users', { id })
  }
}

// メール送信の責任を分離
class UserEmailService {
  sendWelcomeEmail(user: User): void {
    const emailService = new EmailService()
    emailService.send(
      user.email,
      'Welcome!',
      `Hello ${user.name}, welcome to our service!`
    )
  }
}

// レポート生成の責任を分離
class UserReportGenerator {
  generate(user: User): string {
    return `User Report: ${user.name} (${user.email})`
  }
}
```

**改善点**:
- 各クラスが単一の責任を持つ
- 変更の影響範囲が限定される
- テストが容易（各クラスを独立してテスト）
- 再利用しやすい

---

## 2. Open/Closed Principle（開放閉鎖の原則）

### 定義
**拡張に対して開いており、修正に対して閉じている**

新機能追加時に既存コードを変更せず、拡張で対応します。

### なぜ重要か
- **安全性**: 既存コードを変更しないため、既存機能を壊すリスクが低い
- **拡張性**: 新機能を追加しやすい
- **保守性**: 既存コードの理解が不要

### ❌ 悪い例: 新しいタイプ追加で既存コード修正が必要
```typescript
class Shape {
  type: 'circle' | 'square' | 'rectangle'
  radius?: number
  side?: number
  width?: number
  height?: number
}

function getArea(shape: Shape): number {
  if (shape.type === 'circle') {
    return Math.PI * shape.radius! ** 2
  }
  if (shape.type === 'square') {
    return shape.side! ** 2
  }
  if (shape.type === 'rectangle') {
    return shape.width! * shape.height!
  }
  // 新しい形状（例: 三角形）を追加する場合
  // → この関数を修正する必要がある
  throw new Error('Unknown shape type')
}
```

**問題点**:
- 新しい形状を追加するたびに`getArea`関数を修正
- 修正時に既存機能を壊すリスク
- テストケースも増え続ける

### ✅ 良い例: インターフェースで拡張
```typescript
// インターフェースで抽象化
interface Shape {
  getArea(): number
}

class Circle implements Shape {
  constructor(private radius: number) {}

  getArea(): number {
    return Math.PI * this.radius ** 2
  }
}

class Square implements Shape {
  constructor(private side: number) {}

  getArea(): number {
    return this.side ** 2
  }
}

class Rectangle implements Shape {
  constructor(
    private width: number,
    private height: number
  ) {}

  getArea(): number {
    return this.width * this.height
  }
}

// 新しい形状を追加（既存コードは変更不要）
class Triangle implements Shape {
  constructor(
    private base: number,
    private height: number
  ) {}

  getArea(): number {
    return (this.base * this.height) / 2
  }
}

// 使用側のコードは変更不要
function printArea(shape: Shape): void {
  console.log(`Area: ${shape.getArea()}`)
}
```

**改善点**:
- 新しい形状追加時に既存コードを変更しない
- 各形状のロジックが独立
- テストも独立して実施可能

---

## 3. Liskov Substitution Principle（リスコフの置換原則）

### 定義
**派生クラスは基底クラスと置換可能である**

サブクラスは親クラスの契約（振る舞い）を破ってはいけません。

### なぜ重要か
- **信頼性**: 継承階層の振る舞いが予測可能
- **ポリモーフィズム**: 安全に基底クラス型で扱える
- **保守性**: 継承関係が明確

### ❌ 悪い例: 親の契約を破る継承
```typescript
class Bird {
  fly(): void {
    console.log('Flying in the sky')
  }
}

class Sparrow extends Bird {
  fly(): void {
    console.log('Sparrow flying fast')
  }
}

// ❌ ペンギンは飛べないため、親の契約を破る
class Penguin extends Bird {
  fly(): void {
    throw new Error('Penguins cannot fly!')
  }
}

// 使用側で問題が発生
function makeBirdFly(bird: Bird): void {
  bird.fly()  // Penguinの場合、エラーが発生
}

makeBirdFly(new Sparrow())  // OK
makeBirdFly(new Penguin())  // ❌ 例外が発生
```

**問題点**:
- `Bird`型を期待する関数が`Penguin`で壊れる
- 継承関係が適切でない

### ✅ 良い例: 適切な抽象化
```typescript
// 基底クラス: すべての鳥に共通
class Bird {
  constructor(public name: string) {}
}

// 飛べる能力をインターフェースで分離
interface Flyable {
  fly(): void
}

// 泳げる能力をインターフェースで分離
interface Swimmable {
  swim(): void
}

// スズメ: 飛べる鳥
class Sparrow extends Bird implements Flyable {
  fly(): void {
    console.log(`${this.name} is flying`)
  }
}

// ペンギン: 泳げる鳥
class Penguin extends Bird implements Swimmable {
  swim(): void {
    console.log(`${this.name} is swimming`)
  }
}

// アヒル: 飛べて泳げる鳥
class Duck extends Bird implements Flyable, Swimmable {
  fly(): void {
    console.log(`${this.name} is flying`)
  }

  swim(): void {
    console.log(`${this.name} is swimming`)
  }
}

// 使用側: 能力に応じた関数
function makeFly(flyable: Flyable): void {
  flyable.fly()
}

function makeSwim(swimmable: Swimmable): void {
  swimmable.swim()
}

makeFly(new Sparrow('Tweety'))  // OK
makeSwim(new Penguin('Pingu'))  // OK
makeFly(new Duck('Donald'))     // OK
makeSwim(new Duck('Donald'))    // OK
```

**改善点**:
- 継承とインターフェースを適切に使い分け
- 各クラスは実装できる能力のみを持つ
- 型安全に使用可能

---

## 4. Interface Segregation Principle（インターフェース分離の原則）

### 定義
**クライアントが使用しないメソッドへの依存を強制しない**

大きなインターフェースより、小さく特化したインターフェースを複数用意します。

### なぜ重要か
- **柔軟性**: 必要な機能のみを実装
- **保守性**: インターフェース変更の影響範囲が限定
- **理解しやすさ**: 役割が明確

### ❌ 悪い例: 巨大なインターフェース
```typescript
interface Worker {
  work(): void
  eat(): void
  sleep(): void
  takeBreak(): void
}

class Human implements Worker {
  work() { console.log('Working') }
  eat() { console.log('Eating') }
  sleep() { console.log('Sleeping') }
  takeBreak() { console.log('Taking a break') }
}

// ❌ ロボットは食事も睡眠も必要ない
class Robot implements Worker {
  work() { console.log('Processing tasks') }

  // 不要なメソッドを実装しなければならない
  eat() { throw new Error('Robots do not eat') }
  sleep() { throw new Error('Robots do not sleep') }
  takeBreak() { throw new Error('Robots do not take breaks') }
}
```

**問題点**:
- ロボットに不要なメソッドを実装
- インターフェース変更時の影響が大きい

### ✅ 良い例: 分離されたインターフェース
```typescript
// 作業する能力
interface Workable {
  work(): void
}

// 食事する能力
interface Eatable {
  eat(): void
}

// 睡眠する能力
interface Sleepable {
  sleep(): void
}

// 休憩する能力
interface Breakable {
  takeBreak(): void
}

// 人間: すべての能力を持つ
class Human implements Workable, Eatable, Sleepable, Breakable {
  work() { console.log('Working') }
  eat() { console.log('Eating') }
  sleep() { console.log('Sleeping') }
  takeBreak() { console.log('Taking a break') }
}

// ロボット: 作業する能力のみ
class Robot implements Workable {
  work() { console.log('Processing tasks') }
}

// 使用側: 必要な能力のみを要求
function assignWork(worker: Workable): void {
  worker.work()
}

function serveMeal(eater: Eatable): void {
  eater.eat()
}

assignWork(new Human())   // OK
assignWork(new Robot())   // OK
serveMeal(new Human())    // OK
// serveMeal(new Robot()) // コンパイルエラー（型安全）
```

**改善点**:
- 各インターフェースが単一の能力を定義
- クラスは必要な能力のみを実装
- 型安全に使用可能

---

## 5. Dependency Inversion Principle（依存関係逆転の原則）

### 定義
**上位モジュールは下位モジュールに依存しない。両者は抽象に依存する**

具象クラスではなく、インターフェース（抽象）に依存します。

### なぜ重要か
- **柔軟性**: 実装を簡単に切り替えられる
- **テストしやすさ**: モックやスタブを注入可能
- **疎結合**: モジュール間の依存が弱い

### ❌ 悪い例: 具象クラスを内部生成する
```typescript
interface User {
  id: string
  name: string
}

class MySqlUserRepository {
  async save(user: User): Promise<void> {
    console.log('Saving to MySQL:', user.id)
  }
}

class UserService {
  private readonly users = new MySqlUserRepository()

  async saveUser(user: User): Promise<void> {
    await this.users.save(user)
  }
}
```

**問題点**:
- DB実装変更時に`UserService`を修正する
- テスト時に実DBまたは重いモックが必要になる
- `UserService`が具象実装の生成責務まで持つ

### ✅ 良い例: 抽象を受け取り、Composition Rootで組み立てる
```typescript
interface User {
  id: string
  name: string
}

interface UserRepository {
  save(user: User): Promise<void>
  findById(id: string): Promise<User | null>
}

class MySqlUserRepository implements UserRepository {
  async save(user: User): Promise<void> {
    console.log('Saving to MySQL:', user.id)
  }

  async findById(id: string): Promise<User | null> {
    console.log('Finding in MySQL:', id)
    return null
  }
}

class InMemoryUserRepository implements UserRepository {
  private readonly users = new Map<string, User>()

  async save(user: User): Promise<void> {
    this.users.set(user.id, user)
  }

  async findById(id: string): Promise<User | null> {
    return this.users.get(id) ?? null
  }
}

class UserService {
  constructor(private readonly users: UserRepository) {}

  async saveUser(user: User): Promise<void> {
    await this.users.save(user)
  }
}

function buildUserService(): UserService {
  return new UserService(new MySqlUserRepository())
}

function buildTestUserService(): UserService {
  return new UserService(new InMemoryUserRepository())
}
```

**改善点**:
- `UserService`は抽象に依存し、具象実装の生成を知らない
- 本番実装とテスト実装をComposition Rootで差し替えられる
- 依存関係がコンストラクタから読み取れる
- DIコンテナがなくてもDIは成立する

### DIの補足

DIコンテナは任意の道具です。小規模なコードではPure DIで十分です。コンテナを使う場合も、`container.resolve()` を通常のアプリケーションコードから呼ばず、Composition Rootに閉じ込めてください。通常コードから任意の依存を取り出す設計はService Locatorです。

Python/FastAPI/TypeScript/NestJS/Angular/Inversify/TSyringeでの実践判断は [DEPENDENCY-INJECTION.md](./DEPENDENCY-INJECTION.md) を参照してください。

---

## 🔗 関連ドキュメント

- [クリーンコードの基礎](./CLEAN-CODE-BASICS.md)
- [Dependency Injection 実践](./DEPENDENCY-INJECTION.md)
- [品質チェックリスト](./QUALITY-CHECKLIST.md)
- [クイックリファレンス](./QUICK-REFERENCE.md)

## 📖 参考リンク

- [SOLID原則 メインページ](../SKILL.md)
