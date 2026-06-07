# TypeScript 型システム基礎

> TypeScriptの型システムは、JavaScriptの柔軟性を保ちながら静的型チェックの安全性を提供する。

## 目次

1. [基本型](#1-基本型)
2. [型推論と型アノテーション](#2-型推論と型アノテーション)
3. [変数とデータ型](#3-変数とデータ型)
4. [関数](#4-関数)
5. [モジュール](#5-モジュール)
6. [Interface](#6-interface)
7. [Enum](#7-enum)

---

## 1. 基本型

TypeScriptが提供するプリミティブ型とその使い方。

### プリミティブ型一覧

| 型 | 説明 | 使用例 |
|----|------|--------|
| `number` | 整数・浮動小数点 | `let age: number = 25;` |
| `string` | 文字列 | `let name: string = 'John';` |
| `boolean` | 真偽値 | `let isAdmin: boolean = true;` |
| `null` | 意図的な空値 | `let user: string \| null = null;` |
| `undefined` | 未初期化 | `let data: string \| undefined;` |

### コレクション型

```typescript
// 配列（2つの記法）
let numbers: number[] = [1, 2, 3];
let strings: Array<string> = ['hello', 'world'];

// タプル（固定長・固定型の配列）
let pair: [string, number] = ['age', 25];

// オブジェクト
let user: { name: string; age: number } = { name: 'John', age: 30 };
```

### 特殊型

| 型 | 用途 | 例 |
|----|------|-----|
| `void` | 戻り値なし関数 | `function log(): void { console.log('...'); }` |
| `unknown` | 型不明（安全。型ガード必須） | `let data: unknown = fetchData();` |
| `never` | 到達不能（例外スロー等） | `function fail(): never { throw new Error(); }` |
| `any` | **⚠️ 使用禁止** | `unknown` + 型ガードを代わりに使用 |

---

## 2. 型推論と型アノテーション

### 型推論（Type Inference）

TypeScriptは変数の初期値や使用コンテキストから型を自動推論する。

```typescript
let x = 5;              // number と推論
let message = 'hello';  // string と推論

// 関数の戻り値も推論される
function double(n: number) {
  return n * 2;  // 戻り値は number と推論
}
```

**型推論が有効な場面:**
- 変数の初期化（`let x = 5`）
- デフォルトパラメータ（`function greet(name = 'World')`）
- 配列リテラル（`const items = [1, 2, 3]`）

### 型アノテーション（Type Annotations）

明示的に型を指定する場合は `: type` 構文を使用する。

```typescript
// 変数
let age: number = 25;
let isAdmin: boolean | undefined = true;

// 関数パラメータと戻り値
function greet(name: string): void {
  console.log(`Hello, ${name}!`);
}

// 空配列（推論が不十分な場合に必須）
let items: string[] = [];
```

### 型推論 vs 型アノテーション 判断基準

| 場面 | 推奨 | 理由 |
|------|------|------|
| ローカル変数の初期化 | 型推論 | 冗長さを避ける |
| 関数パラメータ | 型アノテーション | 呼び出し側の安全性を保証 |
| 関数戻り値（exportされる） | 型アノテーション | API契約を明確化 |
| 空配列・空オブジェクト | 型アノテーション | `never[]` / `{}` 推論を回避 |
| 複雑なオブジェクトリテラル | 型アノテーション | 意図を明確化 |

---

## 3. 変数とデータ型

### 変数宣言キーワード

| キーワード | 再代入 | スコープ | 推奨度 |
|-----------|--------|---------|--------|
| `const` | ❌ | ブロック | ✅ 最優先 |
| `let` | ✅ | ブロック | ✅ 再代入が必要な場合 |
| `var` | ✅ | 関数 | ❌ 非推奨 |

**ベストプラクティス:**
- デフォルトで `const` を使用
- 再代入が必要な場合のみ `let`
- `var` は使用しない

### 演算子と型安全性

```typescript
// ✅ 厳密等価（===）を使用
if (value === 'admin') { ... }

// ❌ 緩い等価（==）は避ける
if (value == 'admin') { ... }  // 型変換が暗黙的に発生

// ✅ typeof による型チェック
if (typeof value === 'string') {
  console.log(value.toUpperCase());
}
```

---

## 4. 関数

### 基本的な関数定義

```typescript
// 名前付き関数
function add(a: number, b: number): number {
  return a + b;
}

// アロー関数
const multiply = (a: number, b: number): number => a * b;

// オプショナルパラメータ
function greet(name: string, greeting?: string): string {
  return `${greeting || 'Hello'}, ${name}!`;
}

// デフォルトパラメータ
function createUser(name: string, role: string = 'user'): void {
  console.log(`Created ${name} as ${role}`);
}
```

### 関数オーバーロード

同じ関数名で異なるパラメータリストを定義できる。

```typescript
function format(value: string): string;
function format(value: number): string;
function format(value: string | number): string {
  if (typeof value === 'string') {
    return value.trim();
  }
  return value.toFixed(2);
}

console.log(format('  hello  ')); // "hello"
console.log(format(3.14159));      // "3.14"
```

### 関数型の定義

```typescript
// 型エイリアスで関数型を定義
type Formatter = (input: string) => string;

// Interfaceで関数型を定義
interface Validator {
  (value: unknown): boolean;
}

// コールバック関数の型付け
function processItems(
  items: string[],
  callback: (item: string, index: number) => void
): void {
  items.forEach(callback);
}
```

---

## 5. モジュール

### ES Modules（推奨）

```typescript
// greeter.ts - エクスポート
export function greet(name: string): void {
  console.log(`Hello, ${name}!`);
}

export interface User {
  id: number;
  name: string;
}

// main.ts - インポート
import { greet, User } from './greeter';
greet('John');
```

### エクスポートパターン

```typescript
// 名前付きエクスポート（推奨）
export function add(a: number, b: number): number { return a + b; }
export const PI = 3.14159;

// デフォルトエクスポート
export default class Calculator { ... }

// 再エクスポート
export { greet } from './greeter';
export type { User } from './types';  // 型のみの再エクスポート
```

### モジュール構成のベストプラクティス

| ルール | 説明 |
|--------|------|
| 1ファイル1責務 | 関連する型・関数をまとめる |
| barrel export (`index.ts`) | ディレクトリのエントリポイントで再エクスポート |
| 型のみのインポート | `import type { User }` で型のみインポート（ランタイム削除を明示） |
| 循環参照を避ける | 依存関係を一方向に保つ |

---

## 6. Interface

### 基本定義

Interfaceはオブジェクトの「形状（shape）」を定義する契約。

```typescript
interface Person {
  name: string;
  age: number;
  email?: string;       // オプショナルプロパティ
  readonly id: number;  // 読み取り専用
}

const user: Person = {
  name: 'John',
  age: 30,
  id: 1
};
```

### Interface の拡張

```typescript
interface Animal {
  sound: string;
}

interface Dog extends Animal {
  breed: string;
}

const myDog: Dog = {
  sound: 'woof',
  breed: 'Golden Retriever'
};
```

### クラスでの実装

```typescript
interface Printable {
  print(): void;
}

interface Loggable {
  log(message: string): void;
}

// 複数のInterfaceを実装
class Report implements Printable, Loggable {
  print(): void {
    console.log('Printing report...');
  }

  log(message: string): void {
    console.log(`[Report] ${message}`);
  }
}
```

### Interface の使い分け

| 場面 | 推奨 | 理由 |
|------|------|------|
| API レスポンスの型定義 | ✅ Interface | 拡張性、Declaration Merging |
| React コンポーネントのProps | ✅ Interface | 慣習的 |
| ユニオン型の定義 | ❌ type alias | Interface では不可 |
| Utility Types の組み合わせ | ❌ type alias | 柔軟な型演算 |

---

## 7. Enum

### 数値Enum

```typescript
enum Direction {
  Up,      // 0
  Down,    // 1
  Left,    // 2
  Right    // 3
}

let move: Direction = Direction.Up;
```

### 文字列Enum

```typescript
enum Color {
  Red = 'RED',
  Green = 'GREEN',
  Blue = 'BLUE'
}

function paint(color: Color): void {
  console.log(`Painting with ${color}`);
}

paint(Color.Red);  // "Painting with RED"
```

### Enum vs Union型

| 比較項目 | Enum | Union型 (`type`) |
|---------|------|-----------------|
| ランタイム存在 | ✅ あり（JSに出力） | ❌ なし（型のみ） |
| リバースマッピング | ✅（数値Enum） | ❌ |
| Tree-shaking | ❌ 全値が含まれる | ✅ 未使用は削除 |
| **推奨場面** | ランタイムで値が必要 | 型チェックのみ |

```typescript
// Enum
enum Status { Active, Inactive }

// Union型（多くの場面でこちらが推奨）
type Status = 'active' | 'inactive';
```

**判断基準:**
- ランタイムで値のイテレーションが必要 → Enum
- 型チェックのみで十分 → Union型（軽量、Tree-shaking対応）
