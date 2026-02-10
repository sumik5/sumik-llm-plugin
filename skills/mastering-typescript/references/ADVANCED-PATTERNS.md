# TypeScript 高度な型パターン

> Generics、Union Types、Conditional Typesを駆使して、柔軟で再利用可能な型設計を実現する。

## 目次

1. [Generics](#1-generics)
2. [Union Types](#2-union-types)
3. [Intersection Types](#3-intersection-types)
4. [Type Guards](#4-type-guards)
5. [Conditional Types](#5-conditional-types)
6. [エラーハンドリング](#6-エラーハンドリング)
7. [保守性の高いコードのベストプラクティス](#7-保守性の高いコードのベストプラクティス)

---

## 1. Generics

### 基本的なジェネリック関数

型パラメータ `<T>` を使って、複数の型で動作する再利用可能な関数を作成する。

```typescript
// 配列の最初の要素を取得
function first<T>(items: T[]): T | undefined {
  return items[0];
}

const num = first([1, 2, 3]);       // number | undefined
const str = first(['a', 'b', 'c']); // string | undefined
```

### ジェネリッククラス

```typescript
class Container<T> {
  private value: T;

  constructor(value: T) {
    this.value = value;
  }

  getValue(): T {
    return this.value;
  }

  map<U>(fn: (value: T) => U): Container<U> {
    return new Container(fn(this.value));
  }
}

const numContainer = new Container(42);
const strContainer = numContainer.map(n => String(n)); // Container<string>
```

### 制約付きジェネリクス（Constraints）

`extends` を使って型パラメータに制約を設ける。

```typescript
// length プロパティを持つ型に制限
interface HasLength {
  length: number;
}

function logLength<T extends HasLength>(item: T): void {
  console.log(`Length: ${item.length}`);
}

logLength('hello');     // OK: string は length を持つ
logLength([1, 2, 3]);   // OK: 配列は length を持つ
// logLength(42);       // Error: number は length を持たない
```

### keyof とジェネリクスの組み合わせ

```typescript
function getProperty<T, K extends keyof T>(obj: T, key: K): T[K] {
  return obj[key];
}

const user = { name: 'John', age: 30, email: 'john@example.com' };
const name = getProperty(user, 'name');  // string
const age = getProperty(user, 'age');    // number
// getProperty(user, 'phone');           // Error: 'phone' は keyof User に含まれない
```

### よく使うジェネリックパターン

| パターン | 用途 | 例 |
|---------|------|-----|
| `<T>` | 単一型パラメータ | `function identity<T>(x: T): T` |
| `<T, U>` | 複数型パラメータ | `function pair<T, U>(a: T, b: U): [T, U]` |
| `<T extends X>` | 制約付き | `function len<T extends HasLength>(x: T)` |
| `<T extends keyof U>` | キー制約 | `function get<T, K extends keyof T>(obj: T, key: K)` |
| `<T = string>` | デフォルト型 | `class List<T = string>` |

---

## 2. Union Types

### 基本

複数の型のいずれかを受け入れる型。

```typescript
let value: string | number;
value = 'hello';  // OK
value = 42;       // OK
// value = true;  // Error: boolean は代入不可

// 関数パラメータでの使用
function formatId(id: string | number): string {
  if (typeof id === 'string') {
    return id.toUpperCase();
  }
  return String(id).padStart(5, '0');
}
```

### Discriminated Union（識別型ユニオン）

共通プロパティ（判別子）を使って型を安全に絞り込む強力なパターン。

```typescript
interface Circle {
  kind: 'circle';
  radius: number;
}

interface Rectangle {
  kind: 'rectangle';
  width: number;
  height: number;
}

type Shape = Circle | Rectangle;

function area(shape: Shape): number {
  switch (shape.kind) {
    case 'circle':
      return Math.PI * shape.radius ** 2;
    case 'rectangle':
      return shape.width * shape.height;
  }
}
```

### 網羅性チェック（Exhaustive Check）

```typescript
function assertNever(x: never): never {
  throw new Error(`Unexpected value: ${x}`);
}

function getShapeName(shape: Shape): string {
  switch (shape.kind) {
    case 'circle':
      return 'Circle';
    case 'rectangle':
      return 'Rectangle';
    default:
      return assertNever(shape); // 新しい Shape を追加したら、ここでコンパイルエラー
  }
}
```

---

## 3. Intersection Types

### 基本

複数の型を結合し、すべてのプロパティを持つ型を作成する。

```typescript
interface HasName {
  name: string;
}

interface HasAge {
  age: number;
}

type Person = HasName & HasAge;

const person: Person = {
  name: 'John',
  age: 30
};
// name と age の両方が必須
```

### ミックスイン的な使い方

```typescript
interface Timestamped {
  createdAt: Date;
  updatedAt: Date;
}

interface SoftDeletable {
  deletedAt: Date | null;
}

// エンティティの共通プロパティを合成
type BaseEntity = Timestamped & SoftDeletable & { id: number };

interface User extends BaseEntity {
  name: string;
  email: string;
}
```

### Union vs Intersection 比較

| 特性 | Union (`A \| B`) | Intersection (`A & B`) |
|------|-----------------|----------------------|
| 意味 | A **または** B | A **かつ** B |
| プロパティアクセス | 共通プロパティのみ | 全プロパティ |
| 代入 | A か B のどちらかでOK | A と B の両方を満たす必要 |
| 使い所 | 入力の柔軟性 | 型の合成・ミックスイン |

---

## 4. Type Guards

### typeof ガード

```typescript
function processValue(value: string | number): string {
  if (typeof value === 'string') {
    return value.toUpperCase();  // ここでは string として扱える
  }
  return value.toFixed(2);       // ここでは number として扱える
}
```

### instanceof ガード

```typescript
class ApiError extends Error {
  statusCode: number;
  constructor(message: string, statusCode: number) {
    super(message);
    this.statusCode = statusCode;
  }
}

function handleError(error: Error) {
  if (error instanceof ApiError) {
    console.log(`API Error ${error.statusCode}: ${error.message}`);
  } else {
    console.log(`Unknown error: ${error.message}`);
  }
}
```

### カスタム型ガード（User-Defined Type Guards）

`is` キーワードで独自の型判定関数を定義。

```typescript
interface Cat {
  meow(): void;
}

interface Dog {
  bark(): void;
}

function isDog(animal: Cat | Dog): animal is Dog {
  return 'bark' in animal;
}

function makeSound(animal: Cat | Dog): void {
  if (isDog(animal)) {
    animal.bark();   // Dog として安全にアクセス
  } else {
    animal.meow();   // Cat として安全にアクセス
  }
}
```

### in 演算子によるガード

```typescript
interface Admin {
  role: 'admin';
  permissions: string[];
}

interface User {
  role: 'user';
  email: string;
}

function getInfo(person: Admin | User): string {
  if ('permissions' in person) {
    return `Admin with ${person.permissions.length} permissions`;
  }
  return `User: ${person.email}`;
}
```

---

## 5. Conditional Types

### 基本構文

`T extends U ? X : Y` — 型 `T` が型 `U` に代入可能なら `X`、そうでなければ `Y`。

```typescript
type IsString<T> = T extends string ? true : false;

type A = IsString<'hello'>;  // true
type B = IsString<42>;       // false
```

### 実用的な Conditional Types

```typescript
// Nullable型の作成
type Nullable<T> = T | null;

// Promiseの中身を取り出す
type UnwrapPromise<T> = T extends Promise<infer U> ? U : T;

type A = UnwrapPromise<Promise<string>>;  // string
type B = UnwrapPromise<number>;           // number

// 配列の要素型を取り出す
type ElementType<T> = T extends (infer U)[] ? U : never;

type C = ElementType<string[]>;   // string
type D = ElementType<number[]>;   // number
```

### infer キーワード

`infer` を使って条件型の中で型を「推論」してキャプチャする。

```typescript
// 関数の戻り値の型を取得（ReturnType の自作版）
type MyReturnType<T> = T extends (...args: any[]) => infer R ? R : never;

type FnReturn = MyReturnType<(x: number) => string>;  // string

// 関数のパラメータ型を取得
type Parameters<T> = T extends (...args: infer P) => any ? P : never;

type FnParams = Parameters<(a: string, b: number) => void>;  // [string, number]
```

### 組み込み Utility Types

| Utility Type | 説明 | 例 |
|-------------|------|-----|
| `Partial<T>` | 全プロパティをオプショナルに | `Partial<User>` |
| `Required<T>` | 全プロパティを必須に | `Required<PartialUser>` |
| `Readonly<T>` | 全プロパティを読み取り専用に | `Readonly<Config>` |
| `Pick<T, K>` | 指定プロパティのみ抽出 | `Pick<User, 'name' \| 'email'>` |
| `Omit<T, K>` | 指定プロパティを除外 | `Omit<User, 'password'>` |
| `Record<K, V>` | キー型と値型のオブジェクト | `Record<string, number>` |
| `Exclude<T, U>` | Union型から特定の型を除外 | `Exclude<'a' \| 'b' \| 'c', 'a'>` |
| `Extract<T, U>` | Union型から特定の型を抽出 | `Extract<string \| number, string>` |
| `NonNullable<T>` | null / undefined を除外 | `NonNullable<string \| null>` |
| `ReturnType<T>` | 関数の戻り値型 | `ReturnType<typeof fn>` |

---

## 6. エラーハンドリング

### エラー型の階層

| エラー型 | 発生場面 |
|---------|---------|
| `Error` | すべてのエラーの基底型 |
| `TypeError` | 無効な操作（文字列と数値の加算等） |
| `ReferenceError` | 未定義の変数へのアクセス |
| `SyntaxError` | 構文エラー |

### Promise でのエラーハンドリング

```typescript
async function fetchData(url: string): Promise<string> {
  try {
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`HTTP Error: ${response.status}`);
    }
    return await response.text();
  } catch (error) {
    if (error instanceof Error) {
      console.error(`Fetch failed: ${error.message}`);
    }
    throw error;
  }
}
```

### 型安全なエラーハンドリングパターン

```typescript
// Result型パターン（Either型）
type Result<T, E = Error> =
  | { success: true; data: T }
  | { success: false; error: E };

async function safeFetch(url: string): Promise<Result<string>> {
  try {
    const response = await fetch(url);
    const data = await response.text();
    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error : new Error(String(error))
    };
  }
}

// 使用側
const result = await safeFetch('https://api.example.com/data');
if (result.success) {
  console.log(result.data);    // string として安全にアクセス
} else {
  console.error(result.error); // Error として安全にアクセス
}
```

### カスタムエラークラス

```typescript
class AppError extends Error {
  constructor(
    message: string,
    public readonly code: string,
    public readonly statusCode: number = 500
  ) {
    super(message);
    this.name = 'AppError';
  }
}

class NotFoundError extends AppError {
  constructor(resource: string) {
    super(`${resource} not found`, 'NOT_FOUND', 404);
  }
}

class ValidationError extends AppError {
  constructor(
    message: string,
    public readonly fields: Record<string, string>
  ) {
    super(message, 'VALIDATION_ERROR', 400);
  }
}
```

---

## 7. 保守性の高いコードのベストプラクティス

### 命名規則

| 対象 | 規則 | 良い例 | 悪い例 |
|------|------|--------|--------|
| 変数 | camelCase、意味のある名前 | `userInformation` | `u`, `data1` |
| 関数 | camelCase、動詞始まり | `calculateTotal` | `total`, `calc` |
| Interface | PascalCase | `UserProfile` | `userProfile`, `IUserProfile` |
| 型エイリアス | PascalCase | `ApiResponse` | `apiResponse` |
| 定数 | UPPER_SNAKE_CASE | `MAX_RETRIES` | `maxRetries` |
| Enum | PascalCase（型名・値名とも） | `Color.Red` | `color.red` |

### コード構造

```typescript
// ✅ 小さく、単一責務の関数
function calculateSubtotal(prices: number[]): number {
  return prices.reduce((acc, price) => acc + price, 0);
}

function calculateTax(subtotal: number, taxRate: number): number {
  return subtotal * taxRate;
}

function calculateTotal(prices: number[], taxRate: number): number {
  const subtotal = calculateSubtotal(prices);
  return subtotal + calculateTax(subtotal, taxRate);
}

// ❌ 巨大で複数の責務を持つ関数
function processOrder(prices: number[], taxRate: number, discount: number) {
  // 計算ロジック + バリデーション + ログ + DB保存 が全部混在...
}
```

### プロジェクト構成

```
src/
├── components/    # UIコンポーネント
│   ├── Button.tsx
│   └── InputField.tsx
├── services/      # ビジネスロジック
│   └── userService.ts
├── types/         # 型定義
│   └── user.ts
├── utils/         # ユーティリティ
│   └── format.ts
└── index.ts       # エントリポイント
```

### tsconfig.json 推奨設定

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "forceConsistentCasingInFileNames": true,
    "isolatedModules": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "sourceMap": true,
    "outDir": "dist"
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
```
