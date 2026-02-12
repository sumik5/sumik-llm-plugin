# TypeScript 5 アーキテクチャ・設計原則ガイド

## 目次

1. [デザインパターンの結合](#デザインパターンの結合)
2. [Utility Typesの活用](#utility-typesの活用)
3. [DDD（ドメイン駆動設計）](#dddドメイン駆動設計)
4. [SOLID原則](#solid原則)
5. [MVCアーキテクチャ](#mvcアーキテクチャ)

---

## デザインパターンの結合

### 結合時の原則

複数のデザインパターンを組み合わせる際は、以下の観点で評価する:

| 評価基準 | 考慮すべき点 |
|---------|------------|
| **目的適合性** | プロジェクト要件に対する実効性 |
| **柔軟性 vs 複雑性** | 追加される複雑性が柔軟性のメリットを上回るか |
| **テスタビリティ** | 単体テストの作成・保守が容易か |

### Singleton + Builder

設定管理などで有効。BuilderはSingletonとして提供し、使用前にリセットする。

```typescript
export class PremiumWebsiteBuilder {
  private state: State = initialState;

  reset(): void {
    this.state = initialState;
  }

  // Builder methods...
}

export default new PremiumWebsiteBuilder();
```

**利点:**
- 単一インスタンスで状態管理
- デフォルトエクスポートで簡潔な利用

**注意点:**
- 使用前に`reset()`を呼び出して内部状態をクリア

### Singleton + Façade

APIゲートウェイなど、複雑なサブシステムへの統一インターフェース提供に有効。

```typescript
interface ServiceA {}
interface ServiceB {}

class SystemFacade {
  private static instance: SystemFacade;

  private constructor(
    private serviceA: ServiceA,
    private serviceB: ServiceB
  ) {}

  static getInstance(serviceA: ServiceA, serviceB: ServiceB): SystemFacade {
    if (!SystemFacade.instance) {
      SystemFacade.instance = new SystemFacade(serviceA, serviceB);
    }
    return SystemFacade.instance;
  }

  performComplexOperation(): void {
    // ServiceAとServiceBを調整
  }
}
```

**利点:**
- 遅延初期化（必要になるまで生成しない）
- 複数サービスの統合管理

**欠点:**
- 複雑性が増すとボトルネックになる可能性
- スケーラビリティの制約

### Singleton + Factory

サービスレジストリとして利用。ただしDI（依存性注入）との組み合わせでは制約が生じる。

```typescript
class ServiceRegistry {
  private static instance: ServiceRegistry;
  private services = new Map<string, any>();

  private constructor() {}

  static getInstance(): ServiceRegistry {
    if (!this.instance) {
      this.instance = new ServiceRegistry();
    }
    return this.instance;
  }

  register<T>(key: string, service: T): void {
    this.services.set(key, service);
  }

  resolve<T>(key: string): T {
    return this.services.get(key);
  }
}
```

**テスト時の課題:**
- Singleton Factoryはモック・スタブの注入が困難
- 単体テスト時に同一インスタンスが共有される

### Singleton + State

アプリケーション全体の状態管理。Stateオブジェクト自体をSingletonにして、すべてのOriginatorが共有する。

```typescript
interface State {
  data: string;
}

class AppState implements State {
  private static instance: AppState;
  data: string = "";

  private constructor() {}

  static getInstance(): AppState {
    if (!this.instance) {
      this.instance = new AppState();
    }
    return this.instance;
  }
}

class OriginatorA {
  constructor(private state: State) {}

  updateState(data: string): void {
    this.state.data = data;
  }
}

// 全Originatorが同じStateインスタンスを共有
const appState = AppState.getInstance();
const originatorA = new OriginatorA(appState);
const originatorB = new OriginatorA(appState);
```

### Iterator + Composite

ツリー構造の走査。ネストが深い場合はキャッシング・メモ化を検討する。

```typescript
const root = new Composite("Root");
root.add(new Composite("Child1"));
root.add(new Composite("Child2"));

const iterator = root.createIterator();
while (iterator.hasNext()) {
  const component = iterator.next();
  if (component) {
    console.log(component.getName());
  }
}
```

**最適化手法:**

| 手法 | 効果 |
|------|------|
| **キャッシング** | 以前アクセスした要素を保存し、再走査を回避 |
| **メモ化** | 高コスト関数の結果を記憶し、再計算を削減 |

### Iterator + Visitor

データ変換パイプライン。Collectionクラスを変更せずに操作を追加できる。

```typescript
const collection = new ElementCollection();
collection.add(new ElementA("Element A1"));
collection.add(new ElementB("Element B1"));
collection.add(new ElementA("Element A2"));

const visitor = new ConcreteVisitor();
const iterator = collection.createIterator();

while (iterator.hasNext()) {
  const element = iterator.next();
  if (element) {
    element.accept(visitor);
  }
}
```

**利点:**
- Collectionインターフェースを汚染しない
- 複数の異なる操作を柔軟に実行

---

## Utility Typesの活用

### Mutable<T>: readonlyの除去

再帰的にすべてのreadonly修飾子を削除する。

```typescript
type Mutable<T> = {
  -readonly [K in keyof T]: Mutable<T[K]>;
};

interface UserState {
  readonly name: string;
  readonly age: number;
  readonly address: {
    readonly street: string;
    readonly city: string;
  };
}

const mutableUserState: Mutable<UserState> = {
  name: "Alice",
  age: 24,
  address: {
    street: "123 Main St",
    city: "Wonderland"
  }
};

// ネストされたオブジェクトも変更可能
mutableUserState.age = 31;
mutableUserState.address.city = "New Wonderland";
```

**動作原理:**
- `-readonly`修飾子で各プロパティの読み取り専用を解除
- 再帰的に適用されるため、ネストしたオブジェクトも変更可能

### カスタムUtility Types

#### OptionalKeys<T>とRequiredKeys<T>

```typescript
type OptionalKeys<T> = {
  [K in keyof T]-?: {} extends Pick<T, K> ? K : never
}[keyof T];

type RequiredKeys<T> = {
  [K in keyof T]-?: {} extends Pick<T, K> ? never : K
}[keyof T];

interface User {
  id: number;
  name: string;
  email?: string;
}

type UserOptionalKeys = OptionalKeys<User>; // "email"
type UserRequiredKeys = RequiredKeys<User>; // "id" | "name"
```

**動作原理:**
- `Pick<T, K>`で各プロパティを抽出
- 空オブジェクト`{}`が割り当て可能ならオプショナル
- Conditional Typeで該当するキーのみをUnion型として返す

**パフォーマンス注意:**
- 大規模インターフェースでは再帰型チェックがコンパイル時間を増加させる
- 必要な箇所のみに適用を限定

#### FunctionPropertyNames<T>とFunctionProperties<T>

```typescript
type FunctionPropertyNames<T> = {
  [K in keyof T]: T[K] extends Function ? K : never
}[keyof T];

type FunctionProperties<T> = Pick<T, FunctionPropertyNames<T>>;

interface Calculator {
  readonly value: number;
  add: (n: number) => void;
  subtract: (n: number) => void;
}

type Names = FunctionPropertyNames<Calculator>; // "add" | "subtract"
type CalculatorMethods = FunctionProperties<Calculator>;

const calc: Mutable<Calculator> = {
  value: 0,
  add(n) {
    this.value += n;
  },
  subtract(n) {
    this.value -= n;
  }
};

calc.value = 10; // Mutable<Calculator>なので許可される
```

**利点:**
- メソッドのみを抽出して型安全に扱える
- Mutable<T>と組み合わせて柔軟な型変換が可能

### Utility Typesライブラリ

[ts-toolbelt](https://millsp.github.io/ts-toolbelt/) などのライブラリで、さらに高度なUtility Typesのコレクションが利用可能。

---

## DDD（ドメイン駆動設計）

### 概要

**DDD（Domain-Driven Design）**は、複雑なビジネスロジックをソフトウェアコンポーネントに翻訳する手法。ビジネス要件とコードを同じ言語で表現し、保守性・拡張性を向上させる。

**主な問い:**
- ビジネスロジックをどう組織化するか？
- アプリケーションが成長しても複雑性をどう管理するか？

### Bounded Context（境界づけられたコンテキスト）

異なるサブドメイン間の論理的境界を定義。マイクロサービスではサービス単位がBounded Contextに対応することが多い。

**例: ECサイト**

| Bounded Context | 担当エンティティ |
|----------------|-----------------|
| **ショッピングカート** | Cart, CartItem, Price, Adjustment |
| **決済処理** | Payment, CreditCard, PaymentGateway |
| **配送管理** | Shipment, DeliveryAddress, TrackingInfo |

各コンテキストは独自のモデル・言語・ルールを持つ。

### Ubiquitous Language（ユビキタス言語）

ステークホルダー・開発者間で共有される語彙。ドメインの用語を統一し、誤解を防ぐ。

**例: 金融取引ドメイン**
- **instrument**: 取引可能な資産またはキャピタルパッケージ
- 異なるドメインでは別の意味を持つ可能性

**実践:**
- 用語集を作成し、プロジェクトメンバー全員がアクセス可能にする
- コード内でも同じ用語を使用

### Entity（エンティティ）

一意なIDを持ち、ライフサイクル（作成・変更・削除）を持つドメインオブジェクト。

**学習管理システムの例:**

| Entity | 説明 |
|--------|------|
| **Author** | コース作成者 |
| **Course** | 学生が受講するコース |
| **Enrollment** | 学生のコース登録情報 |
| **Student** | コース受講者 |
| **Group** | コースを共同で修了する学生グループ |

**特徴:**
- 通常`id`, `created_at`, `updated_at`フィールドを含む
- Repository パターンで永続化を管理
- ビジネスロジックをカプセル化し、不変条件を保証

### Value Object（値オブジェクト）

一意なIDを持たず、属性ベースで同値性を判定する不変オブジェクト。

**例: Money**

```typescript
class Money {
  private readonly amount: number;
  private readonly currency: string;

  constructor(amount: number, currency: string) {
    this.amount = amount;
    this.currency = currency;
    this.validate();
  }

  private validate(): void {
    if (this.amount < 0) {
      throw new Error("Amount cannot be negative");
    }
    if (this.currency.length !== 3) {
      throw new Error("Currency must be a 3-letter ISO code");
    }
  }

  private ensureSameCurrency(other: Money): void {
    if (this.currency !== other.currency) {
      throw new Error("Cannot perform operations on different currencies");
    }
  }

  public equals(other: Money): boolean {
    return this.amount === other.amount &&
      this.currency === other.currency;
  }

  public add(other: Money): Money {
    this.ensureSameCurrency(other);
    return new Money(this.amount + other.amount, this.currency);
  }

  public subtract(other: Money): Money {
    this.ensureSameCurrency(other);
    const resultAmount = this.amount - other.amount;
    if (resultAmount < 0) {
      throw new Error("Resulting amount cannot be negative");
    }
    return new Money(resultAmount, this.currency);
  }
}
```

**特徴:**
- immutable（すべてのプロパティがreadonly）
- 属性ベースの同値性（`equals`メソッド）
- 生成時にバリデーション

### Repository Pattern

ドメインロジックとデータアクセス層の抽象化レイヤー。

```typescript
interface UserRepository {
  findById(id: string): Promise<User | null>;
  save(user: User): Promise<void>;
  delete(id: string): Promise<void>;
}

class InMemoryUserRepository implements UserRepository {
  private users = new Map<string, User>();

  async findById(id: string): Promise<User | null> {
    return this.users.get(id) || null;
  }

  async save(user: User): Promise<void> {
    this.users.set(user.id, user);
  }

  async delete(id: string): Promise<void> {
    this.users.delete(id);
  }
}
```

**利点:**
- ドメインロジックがDBの詳細に依存しない
- テスト時にモックRepository を使用可能

### Domain Events（ドメインイベント）

ドメイン内で発生した重要な出来事を表し、他のコンポーネントに通知する。

**例: ユーザー登録イベント**

```typescript
const dispatcher = new EventDispatcher();
const userService = new UserService(dispatcher);

async function sendWelcomeEmail(event: UserRegisteredEvent) {
  const maxRetries = 3;
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      await sendEmail(event.email);
      console.log(`Successfully sent welcome email to ${event.email}`);
      return;
    } catch (error) {
      console.error(`Attempt ${attempt} failed:`, error);
      if (attempt === maxRetries) {
        console.error(`Failed to send welcome email after ${maxRetries} attempts.`);
      }
    }
  }
}

async function notifyAdminOfNewUser(event: UserRegisteredEvent) {
  console.log(`Notifying admin of new user: ${event.userId}`);
}

dispatcher.addListener(sendWelcomeEmail);
dispatcher.addListener(notifyAdminOfNewUser);

userService.registerUser("user123", "user@example.com");
```

**利点:**
- 疎結合（各ハンドラーが独立）
- 非同期処理を統一的に管理
- リトライロジックなどの横断的関心事の統合

### DDDの欠点

| 欠点 | 説明 |
|------|------|
| **時間・リソースコスト** | ユビキタス言語の確立とモデル精緻化に時間がかかる |
| **適用対象の限定** | 単純なアプリには過剰設計となる可能性 |
| **ドメインエキスパート依存** | ドメインエキスパートへのアクセスが必須 |

**適用判断:**
- 複雑なビジネスロジックを持つドメインで効果大
- 小規模・単純なアプリには不向き

---

## SOLID原則

**SOLID**は5つのオブジェクト指向設計原則の頭字語。保守性・拡張性の高いコードを実現するための指針。

### Single Responsibility Principle（単一責任原則）

**原則:** *クラスは変更すべき理由を1つだけ持つ*

**悪い例:**

```typescript
class User {
  constructor(
    private name: string,
    private email: string,
    private password: string
  ) {}

  login(email: string, password: string) {} // 認証ロジック
  sendEmail(email: string, template: string) {} // メール送信
}
```

**良い例:**

```typescript
class User {
  constructor(
    private name: string,
    private email: string,
    private password: string
  ) {}

  generateSlug(): string {
    return kebabCase(this.name);
  }
}

class UserAccountService {
  login(user: User, password: string) {}
}

class EmailService {
  sendEmailToUser(user: User, template: string) {}
}
```

**利点:**
- テストが容易（各クラスが1つの関心事のみ）
- 変更の影響範囲が限定される
- クラス名から機能が明確

### Open-Closed Principle（開放閉鎖原則）

**原則:** *既存のエンティティを変更せずに機能を拡張可能にする*

**悪い例:**

```typescript
class VoucherService {
  getVoucher(user: User): string {
    if (user.isPremium()) {
      return "15% discount";
    }
    if (user.isUltimate()) {
      return "20% discount";
    } else {
      return "10% discount";
    }
  }
}
```

**良い例:**

```typescript
type AccountType = "Normal" | "Premium" | "Ultimate";
type Voucher = string;

const userTypeToVoucherMap: Record<AccountType, Voucher> = {
  Normal: "10% discount",
  Premium: "15% discount",
  Ultimate: "20% discount"
};

class VoucherService {
  getVoucher(user: User): string {
    return userTypeToVoucherMap[user.getAccountType()];
  }
}
```

**利点:**
- 新しいアカウントタイプの追加時、マッピングのみを変更
- VoucherServiceクラスを変更せずに拡張可能

### Liskov Substitution Principle（リスコフ置換原則）

**原則:** *基底クラスのオブジェクトを派生クラスのオブジェクトで置き換えても、プログラムの動作が変わらない*

**違反例:**

```typescript
interface Bag<T> {
  push(item: T): void;
  pop(): T | undefined;
  isEmpty(): boolean;
}

class NonEmptyStack<T> implements Bag<T> {
  private tag: any = Symbol();
  constructor(private items: T[] = []) {
    if (this.items.length == 0) {
      this.items.push(this.tag);
    }
  }

  push(item: T) {
    this.items.push(item);
  }

  pop(): T | undefined {
    if (this.items.length === 1) {
      const item = this.items.pop();
      this.items.push(this.tag); // 副作用: 常に1要素残す
      return item;
    }
    if (this.items.length > 1) {
      return this.items.pop();
    }
    return undefined;
  }

  isEmpty(): boolean {
    return this.items.length === 0; // 常にfalse
  }
}
```

**問題点:**
- `isEmpty()`が常に`false`を返す
- 親クラス（Bag）の期待する動作と異なる
- クライアントが予期しない動作に遭遇

**違反の形態:**
- 親クラスと互換性のないオブジェクトを返す
- 親クラスがスローしない例外をスローする
- 親クラスが処理しない副作用を導入する

### Interface Segregation Principle（インターフェース分離原則）

**原則:** *インターフェースは可能な限り小さく保ち、必要なメソッドのみを含める*

**悪い例:**

```typescript
interface Collection<T> {
  pushBack(item: T): void;
  popBack(): T;
  pushFront(item: T): void;
  popFront(): T;
  isEmpty(): boolean;
  insertAt(item: T, index: number): void;
  deleteAt(index: number): T | undefined;
}
```

**良い例:**

```typescript
interface Collection<T> {
  isEmpty(): boolean;
}

interface Array<T> extends Collection<T> {
  insertAt(item: T, index: number): void;
  deleteAt(index: number): T | undefined;
}

interface Stack<T> extends Collection<T> {
  pushFront(item: T): void;
  popFront(): T;
}

interface Queue<T> extends Collection<T> {
  pushBack(item: T): void;
  popFront(): T;
}
```

**利点:**
- 実装クラスが無関係なメソッドを実装する必要がない
- 拡張性が向上（新しいインターフェースを追加しやすい）

**パフォーマンス考慮:**
- 配列ベースのStackで`pushFront`/`popFront`を使うと要素シフトでO(n)
- 適切なデータ構造の選択が重要

### Dependency Inversion Principle（依存性逆転原則）

**原則:** *具体的な実装ではなく、抽象（インターフェース）に依存する*

**悪い例:**

```typescript
class UserService {
  findByEmail(email: string): User | undefined {
    const userRepo = UserRepositoryFactory.getInstance(); // ハードコード依存
    return userRepo.findByEmail(email);
  }
}
```

**良い例:**

```typescript
interface UserQuery {
  findByEmail(email: string): User | undefined;
}

class UserService {
  constructor(
    private userQuery: UserQuery = UserRepositoryFactory.getInstance()
  ) {}

  findByEmail(email: string): User | undefined {
    return this.userQuery.findByEmail(email);
  }
}

class UserRepository implements UserQuery {
  users: User[] = [{ name: "Theo", email: "theo@example.com" }];

  findByEmail(email: string): User | undefined {
    return this.users.find((u) => u.email === email);
  }
}

class MockUserQuery implements UserQuery {
  private users: User[] = [
    { name: "Alice", email: "alice@example.com" },
    { name: "Bob", email: "bob@example.com" }
  ];

  findByEmail(email: string): User | undefined {
    return this.users.find((u) => u.email === email);
  }
}

// テスト例
describe("UserService", () => {
  let userService: UserService;
  let mockUserQuery: MockUserQuery;

  beforeEach(() => {
    mockUserQuery = new MockUserQuery();
    userService = new UserService(mockUserQuery); // モック注入
  });

  // テストケース
});
```

**利点:**
- テスト容易性（モックを簡単に注入可能）
- 柔軟性（実装を容易に切り替え可能）
- DIフレームワーク（InversifyJS、Angular DI）との相性が良い

### SOLIDの限界

| 課題 | 説明 |
|------|------|
| **DRYとのトレードオフ** | SOLID適用で重複コードが増える場合がある |
| **KISSとの矛盾** | 複雑性が増し、シンプルさが損なわれる可能性 |
| **予測困難な変更** | 将来の要件変更を完全に予測することは不可能 |

**実践的アプローチ:**
- SOLID、DRY、KISSをバランスよく適用
- プロジェクトの規模・複雑性・チームスキルに応じて判断
- 過度な抽象化を避ける

---

## MVCアーキテクチャ

**MVC（Model-View-Controller）**は、アプリケーションを3つの相互接続されたコンポーネントに分離するアーキテクチャパターン。

| コンポーネント | 役割 | レイヤー |
|--------------|------|---------|
| **Model** | ビジネスロジックとデータ管理 | ドメイン層 |
| **View** | 表示・ユーザーインターフェース | プレゼンテーション層 |
| **Controller** | ModelとViewの仲介 | アプリケーション層 |

### Model（モデル）

ビジネスロジック、バリデーション、データ取得をカプセル化。

```typescript
interface TodoModel {
  id: number;
  title: string;
  completed: boolean;
  toggleCompletion(): void;
}

class Todo implements TodoModel {
  constructor(
    public readonly id: number,
    public title: string,
    public completed: boolean = false
  ) {}

  toggleCompletion(): void {
    this.completed = !this.completed;
  }
}
```

**パターンの適用:**
- **Singleton**: モデルの単一インスタンス管理
- **Factory Method**: モデルの生成を抽象化
- **Builder**: 複雑なビューモデルの構築

### View（ビュー）

データの表示とユーザー入力の受付を担当。

```typescript
class TodoList {
  private todos: TodoModel[] = [];
  private nextId: number = 1;

  addTodo(title: string): void {
    const newTodo = new Todo(this.nextId++, title);
    this.todos.push(newTodo);
  }

  getTodos(): TodoModel[] {
    return this.todos;
  }
}

class TodoView {
  constructor(private model: TodoList) {}

  displayTodos() {
    console.log("Todo List:");
    this.model.getTodos().forEach((todo, index) => {
      console.log(`${index + 1}. ${todo.title} [${todo.completed ? "✓" : " "}]`);
    });
  }

  promptAddTodo() {
    const readline = require("readline").createInterface({
      input: process.stdin,
      output: process.stdout
    });

    readline.question("Enter a new todo: ", (todo: string) => {
      console.log("Todo added successfully!");
      readline.close();
    });
  }
}
```

**フレームワークとの統合:**
- **Angular**: コンポーネントベースのView
- **React**: 関数型コンポーネント
- **Vue**: テンプレート構文

### Controller（コントローラー）

ModelとViewの間の「糊」として機能。ユーザー入力を処理し、Modelを更新し、Viewを再描画する。

```typescript
class TodoController {
  constructor(
    private model: TodoList,
    private view: TodoView
  ) {}

  addTodo(title: string): void {
    this.model.addTodo(title);
    console.log("Todo added successfully!");
    this.view.displayTodos();
  }

  promptAddTodo(): void {
    this.view.promptAddTodo();
  }
}

// 使用例
const todoList = new TodoList();
const todoView = new TodoView(todoList);
const todoController = new TodoController(todoList, todoView);

todoController.promptAddTodo();
```

**Controllerの責務:**
1. ユーザー入力のリスニング（クリック、フォーム送信など）
2. Modelメソッドの呼び出し
3. Viewの更新トリガー

### TypeScriptでのMVCの利点

| 利点 | 説明 |
|------|------|
| **型安全性** | コンパイル時にModel-View-Controller間のインターフェース整合性を検証 |
| **保守性** | 各コンポーネントが独立しており、変更が局所化される |
| **テスタビリティ** | 各層を独立してテスト可能 |
| **再利用性** | Modelは異なるViewやControllerで再利用可能 |

---

## まとめ

### アーキテクチャ選択のガイドライン

| 状況 | 推奨アプローチ |
|------|--------------|
| **複雑なビジネスロジック** | DDD + SOLID原則 |
| **中規模Webアプリ** | MVC + Utility Types |
| **マイクロサービス** | DDD Bounded Context + SOLID |
| **レガシーコード刷新** | SOLID原則でリファクタリング |

### ベストプラクティスの統合

1. **デザインパターン結合**: 目的に合わせて組み合わせ、過剰設計を避ける
2. **Utility Types**: 型変換を明示的にし、コンパイル時の安全性を向上
3. **DDD**: 複雑なドメインでBounded Contextとユビキタス言語を活用
4. **SOLID**: DRY・KISSとバランスを取りながら適用
5. **MVC**: 関心の分離を徹底し、各層の責務を明確化

これらの原則・パターンは銀の弾丸ではなく、プロジェクトの文脈に応じて選択的に適用すべきツールである。変更に強い堅牢なTypeScriptアプリケーションを構築するためには、継続的なリファクタリングと適切な抽象化のバランスが重要となる。
