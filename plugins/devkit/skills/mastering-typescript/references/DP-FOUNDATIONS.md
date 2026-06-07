# TypeScript 5 基礎とデザインパターン概論

## 目次

1. [TypeScript 5の主要な新機能・改善](#typescript-5の主要な新機能改善)
2. [OOP原則のTypeScript実装](#oop原則のtypescript実装)
3. [Utility Types実践ガイド](#utility-types実践ガイド)
4. [Advanced Types & Assertions](#advanced-types--assertions)
5. [ブラウザ開発](#ブラウザ開発)
6. [サーバー開発](#サーバー開発)
7. [デザインパターン概論](#デザインパターン概論)

---

## TypeScript 5の主要な新機能・改善

### Decorators（Stage 3対応）

TypeScript 5では、ECMAScript Stage 3 Decoratorsに正式対応。クラス、メソッド、アクセサ、プロパティに対してメタプログラミングが可能。

```typescript
function logged(target: any, key: string, descriptor: PropertyDescriptor) {
  const original = descriptor.value;
  descriptor.value = function(...args: any[]) {
    console.log(`Calling ${key} with`, args);
    return original.apply(this, args);
  };
  return descriptor;
}

class Calculator {
  @logged
  add(a: number, b: number): number {
    return a + b;
  }
}
```

**主な用途:**
- ロギング、バリデーション、依存性注入
- フレームワーク（NestJS等）での宣言的な設定

### const type parameters

型パラメータを`const`として推論し、リテラル型を保持。

```typescript
function makeArray<const T>(values: T[]): T[] {
  return values;
}

const numbers = makeArray([1, 2, 3]); // type: (1 | 2 | 3)[]
```

### 改良されたenum

enumのパフォーマンス改善と型安全性強化。ただし、Union Typesでの代替も推奨される。

```typescript
// Union Types推奨パターン
type Status = "pending" | "success" | "error";

// enumを使う場合
enum HttpStatus {
  OK = 200,
  NotFound = 404,
  InternalError = 500
}
```

### その他の改善

| 機能 | 概要 |
|------|------|
| `satisfies` operator | 型の検証と推論を同時に実行 |
| `extends` in infer | Conditional Typesでの柔軟な推論 |
| Array.findLast/findLastIndex | 配列メソッドの型定義追加 |

---

## OOP原則のTypeScript実装

### Encapsulation（カプセル化）

プライベートフィールドとメソッドでデータを保護。

```typescript
class BankAccount {
  #balance: number; // プライベートフィールド（ES2022構文）

  constructor(initialBalance: number) {
    this.#balance = initialBalance;
  }

  deposit(amount: number): void {
    if (amount > 0) {
      this.#balance += amount;
    }
  }

  getBalance(): number {
    return this.#balance;
  }
}
```

**ベストプラクティス:**
- `#`構文（ランタイム保護）vs `private`キーワード（コンパイル時のみ）
- Getters/Settersで内部状態を制御

### Inheritance（継承）

基底クラスの機能を派生クラスで拡張。

```typescript
abstract class Animal {
  constructor(protected name: string) {}

  abstract makeSound(): void;

  move(): void {
    console.log(`${this.name} is moving`);
  }
}

class Dog extends Animal {
  makeSound(): void {
    console.log("Woof!");
  }
}

class Cat extends Animal {
  makeSound(): void {
    console.log("Meow!");
  }
}
```

**重要な判断基準:**

| 使用すべき場合 | 避けるべき場合 |
|--------------|--------------|
| "is-a"関係が明確 | "has-a"関係（→Compositionを使用） |
| 共通の振る舞いが多い | 深いネスト（3階層以上） |
| テンプレートメソッドパターン | 多重継承が必要 |

### Polymorphism（ポリモーフィズム）

同じインターフェースで異なる実装を扱う。

```typescript
interface PaymentMethod {
  processPayment(amount: number): void;
}

class CreditCard implements PaymentMethod {
  processPayment(amount: number): void {
    console.log(`Charging ${amount} to credit card`);
  }
}

class PayPal implements PaymentMethod {
  processPayment(amount: number): void {
    console.log(`Processing ${amount} via PayPal`);
  }
}

function checkout(payment: PaymentMethod, amount: number) {
  payment.processPayment(amount); // ポリモーフィズム
}
```

---

## Utility Types実践ガイド

### Partial<T> と Required<T>

```typescript
interface User {
  id: number;
  name: string;
  email: string;
}

// 全フィールドをオプショナルに
type PartialUser = Partial<User>;

// 全フィールドを必須に
type RequiredUser = Required<Partial<User>>;

function updateUser(id: number, updates: Partial<User>) {
  // 一部のフィールドのみ更新可能
}
```

### Pick<T, K> と Omit<T, K>

```typescript
// 特定のプロパティを選択
type UserCredentials = Pick<User, "email" | "password">;

// 特定のプロパティを除外
type PublicUser = Omit<User, "password">;
```

### Record<K, V>

```typescript
type Role = "admin" | "user" | "guest";
type Permissions = Record<Role, string[]>;

const permissions: Permissions = {
  admin: ["read", "write", "delete"],
  user: ["read", "write"],
  guest: ["read"]
};
```

### ReturnType<T> と Parameters<T>

```typescript
function createUser(name: string, age: number) {
  return { name, age, createdAt: new Date() };
}

type UserResult = ReturnType<typeof createUser>;
// { name: string; age: number; createdAt: Date }

type CreateUserParams = Parameters<typeof createUser>;
// [name: string, age: number]
```

**Utility Types使い分け:**

| ユースケース | 推奨Utility Type |
|------------|-----------------|
| APIレスポンスの部分更新 | Partial<T> |
| フォームデータの型定義 | Required<T> |
| 特定フィールドのみ公開 | Pick<T, K> |
| 機密情報を除外 | Omit<T, K> |
| 辞書・マップ構造 | Record<K, V> |

---

## Advanced Types & Assertions

### Type Guards

```typescript
function isString(value: unknown): value is string {
  return typeof value === "string";
}

function processValue(value: unknown) {
  if (isString(value)) {
    console.log(value.toUpperCase()); // 型が絞り込まれる
  }
}
```

### Branded Types（型ブランディング）

プリミティブ型に名前付きの意味を付与。

```typescript
type UserId = string & { readonly __brand: "UserId" };
type Email = string & { readonly __brand: "Email" };

function createUserId(id: string): UserId {
  return id as UserId;
}

function sendEmail(userId: UserId, email: Email) {
  // 型レベルで誤った引数を防ぐ
}
```

### Conditional Types

```typescript
type IsArray<T> = T extends any[] ? true : false;

type A = IsArray<string[]>; // true
type B = IsArray<string>;   // false

// Extract / Exclude
type StringOrNumber = string | number | boolean;
type OnlyString = Extract<StringOrNumber, string>; // string
type NoString = Exclude<StringOrNumber, string>;   // number | boolean
```

### keyof演算子

```typescript
interface Product {
  id: number;
  name: string;
  price: number;
}

type ProductKey = keyof Product; // "id" | "name" | "price"

function getProperty<T, K extends keyof T>(obj: T, key: K): T[K] {
  return obj[key];
}

const product: Product = { id: 1, name: "Book", price: 1000 };
const name = getProperty(product, "name"); // string型で推論
```

---

## ブラウザ開発

### DOM型の活用

```typescript
const button = document.querySelector<HTMLButtonElement>("#submit");
if (button) {
  button.addEventListener("click", (event: MouseEvent) => {
    console.log("Clicked at", event.clientX, event.clientY);
  });
}
```

**重要なDOM型:**

| 型 | 用途 |
|----|------|
| `HTMLElement` | すべてのHTML要素の基底型 |
| `HTMLInputElement` | `<input>`要素 |
| `HTMLButtonElement` | `<button>`要素 |
| `Event` | すべてのイベントの基底型 |
| `MouseEvent` | マウスイベント |

### Vite統合

**tsconfig.json設定:**

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ESNext",
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "moduleResolution": "bundler",
    "strict": true,
    "isolatedModules": true
  }
}
```

**Viteの利点:**
- 開発時のHMR（Hot Module Replacement）
- ネイティブESM対応
- TypeScriptの高速トランスパイル

### React with TypeScript

```typescript
interface ButtonProps {
  label: string;
  onClick: () => void;
  disabled?: boolean;
}

const Button: React.FC<ButtonProps> = ({ label, onClick, disabled = false }) => {
  return (
    <button onClick={onClick} disabled={disabled}>
      {label}
    </button>
  );
};
```

**型安全なHooks:**

```typescript
const [count, setCount] = useState<number>(0);
const [user, setUser] = useState<User | null>(null);

useEffect(() => {
  // 副作用処理
}, [count]);
```

---

## サーバー開発

### ランタイム比較

| 項目 | Node.js | Deno | Bun |
|------|---------|------|-----|
| TypeScript | 要トランスパイル | ネイティブサポート | ネイティブサポート |
| パッケージ管理 | npm/yarn/pnpm | URL/npm互換 | npm互換 |
| セキュリティ | 制限なし | 権限ベース | 制限なし |
| パフォーマンス | 標準 | やや速い | 非常に高速 |
| エコシステム | 最大 | 成長中 | 成長中 |

**選択基準:**

```typescript
// Node.js: 既存エコシステム重視
import express from "express";

// Deno: セキュリティとモダンAPI重視
import { serve } from "https://deno.land/std/http/server.ts";

// Bun: 高速起動と開発体験重視
import { serve } from "bun";
```

### フレームワーク比較（Express.js vs Nest.js）

**Express.js（軽量・柔軟）:**

```typescript
import express from "express";

const app = express();

app.get("/health", (req, res) => {
  res.send("OK");
});

app.listen(3000);
```

**Nest.js（構造化・型安全）:**

```typescript
import { Controller, Get, Module } from "@nestjs/common";
import { NestFactory } from "@nestjs/core";

@Controller()
class AppController {
  @Get("/health")
  getHealth() {
    return "OK";
  }
}

@Module({
  controllers: [AppController]
})
class AppModule {}

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  await app.listen(3000);
}
bootstrap();
```

**選択基準:**

| プロジェクト特性 | 推奨フレームワーク |
|----------------|------------------|
| 小規模API、マイクロサービス | Express.js |
| エンタープライズアプリ | Nest.js |
| 既存コードベースの拡張 | Express.js |
| DI・モジュール化重視 | Nest.js |

### エラーハンドリングパターン

#### Custom Error Classes

```typescript
class DatabaseConnectionError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "DatabaseConnectionError";
  }
}

try {
  throw new DatabaseConnectionError("Unable to connect");
} catch (error) {
  if (error instanceof DatabaseConnectionError) {
    console.error("DB Error:", error.message);
  }
}
```

#### Union Types for Errors

```typescript
type SuccessResponse = { success: true; value: number };
type ErrorResponse = { success: false; error: string };

function divide(a: number, b: number): SuccessResponse | ErrorResponse {
  if (b === 0) {
    return { success: false, error: "Division by zero" };
  }
  return { success: true, value: a / b };
}

const result = divide(10, 0);
if (result.success) {
  console.log(result.value);
} else {
  console.error(result.error);
}
```

#### Centralized Error Handling（Express.js）

```typescript
function errorHandler(err: Error, req: Request, res: Response, next: NextFunction) {
  console.error(err.stack);
  res.status(500).json({ error: err.message });
}

app.use(errorHandler);
```

**エラーハンドリング選択基準:**

| 状況 | 推奨パターン |
|------|------------|
| 特定のエラー型を区別 | Custom Error Classes |
| 関数型プログラミング | Union Types |
| フレームワークレベル | Centralized Handler |

---

## デザインパターン概論

### なぜデザインパターンが必要か

ソフトウェア開発における共通の問題に対する実証済みの解決策。以下の課題を解決:

- **密結合（Tight Coupling）**: 変更時の影響範囲が広い
- **弱い凝集性（Weak Cohesion）**: 関連性の低い機能が混在
- **非効率なリソース管理**: メモリリーク、パフォーマンス低下

### TypeScriptでの位置づけ

**デザインパターンが現代でも有効な理由:**

1. **型システムとの相乗効果**: TypeScriptの型安全性とパターンの組み合わせでより堅牢なコードが実現
2. **共通言語**: チーム間でのコミュニケーション効率化（例: "Singletonで実装"）
3. **基礎知識**: Reactive ProgrammingやDDDなど高度な概念への足がかり

**TypeScriptによる最適化例:**

```typescript
// 古典的なFactory Pattern
interface Product {
  use(): void;
}

class ConcreteProductA implements Product {
  use() { console.log("Product A"); }
}

class ConcreteProductB implements Product {
  use() { console.log("Product B"); }
}

// TypeScript型システムでの改善
type ProductType = "A" | "B";

class ProductFactory {
  static create(type: ProductType): Product {
    switch (type) {
      case "A": return new ConcreteProductA();
      case "B": return new ConcreteProductB();
    }
  }
}
```

### デザインパターンの3分類

| カテゴリ | 目的 | 代表パターン |
|---------|------|-------------|
| **Creational（生成）** | オブジェクト生成の抽象化 | Singleton, Factory, Builder |
| **Structural（構造）** | クラス・オブジェクトの組み合わせ | Adapter, Decorator, Proxy |
| **Behavioral（振る舞い）** | オブジェクト間の責任分配 | Observer, Strategy, Command |

### TypeScriptでの現代的解釈

**パターンを適用すべき状況:**

```typescript
// ❌ パターンの過剰適用
class SimpleConfig {
  // Singletonは不要（モジュールスコープで十分）
}

// ✅ 適切な状況
class DatabaseConnection {
  // Singleton: グローバルに1つのインスタンスが必要
  private static instance: DatabaseConnection;

  private constructor() {}

  static getInstance() {
    if (!this.instance) {
      this.instance = new DatabaseConnection();
    }
    return this.instance;
  }
}
```

**注意点:**
- パターンは銀の弾丸ではない
- プロジェクトの文脈・規模・チームスキルに応じて選択
- 過度な抽象化はコードを複雑にする

### パターン学習のロードマップ

1. **基礎**: Singleton, Factory → オブジェクト生成の基本理解
2. **応用**: Adapter, Decorator → 既存コードの拡張技法
3. **高度**: Observer, Strategy → 振る舞いの動的変更
4. **発展**: Reactive Programming, Event Sourcing → パターンの組み合わせ

---

## まとめ

TypeScript 5は、型システムの強化（Decorators、const type parameters等）により、デザインパターンをより型安全かつ簡潔に実装できる。OOP原則（Encapsulation, Inheritance, Polymorphism）とUtility Typesを駆使し、ブラウザ・サーバー双方で堅牢なアプリケーションを構築可能。

デザインパターンは1994年の概念だが、TypeScriptの文脈では以下の価値を持つ:
- 型システムとの統合による安全性向上
- チーム間の共通言語としての機能
- より高度なアーキテクチャパターンへの基礎知識

**次のステップ:**
- Creational Patterns（Singleton, Factory, Builder等）の詳細実装
- Structural Patterns（Adapter, Decorator等）の実践
- Behavioral Patterns（Observer, Strategy等）の応用
