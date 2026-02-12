# TypeScriptアンチパターンと回避策

## 目次

1. [クラスの過剰使用](#1-クラスの過剰使用)
2. [過度に寛容な型](#2-過度に寛容な型)
3. [他言語のイディオム](#3-他言語のイディオム)
4. [型推論の落とし穴](#4-型推論の落とし穴)
5. [ジェネリクスの落とし穴](#5-ジェネリクスの落とし穴)
6. [OSSデザインパターン事例](#6-ossデザインパターン事例)

---

## 1. クラスの過剰使用

### 1.1 Jungle Problem（バナナ・モンキー・ジャングル問題）

**問題**: OOP継承によるクラス階層の引きずり。Bananaオブジェクトを使うためにJungle全体をインポートする必要が生じる。

**悪い例**:
```typescript
// バナナを使うにはジャングル全体が必要
new Jungle().getAnimalByType("Monkey").getBanana();
```

**解決策: Composition over Inheritance**:
```typescript
class Jungle {
  constructor(private animal: Animal, private fruit: Fruit) {}

  feedAnimals() {
    this.animal.eat(this.fruit);
  }
}

const jungle = new Jungle();
const monkey = new Monkey();
const banana = new Banana();
jungle.addAnimal(monkey);
jungle.addFruit(banana);
jungle.feedAnimals(); // "The monkey eats a banana."
```

**ポイント**:
- Jungleは環境コンテナとして機能
- 継承ではなくコンポジションで柔軟性を確保
- black-box reuseパターン: インターフェースのみに依存

---

### 1.2 クラス過剰使用の具体例（CSV/Excel/PDF）

**問題**: 部分的な機能継承による密結合。

**悪い例**:
```typescript
interface Reader {
  read(): string[]
}
interface Writer {
  write(input: string[]): void
}

class CSV implements Reader, Writer {
  constructor(private csvFilePath: string) {}
  read(): string[] { return ["data1", "data2"] }
  write(input: string[]): void { /* CSV書き込み */ }
}

// CSVの一部だけ使いたいのに全体に依存
class ExcelToCSV extends CSV {
  constructor(csvFilePath: string, private excelFilePath: string) {
    super(csvFilePath)
  }
  read(): string[] { return ["excelData1", "excelData2"] }
}

class ExcelToPDF extends ExcelToCSV {
  constructor(csvFilePath: string, excelFilePath: string, private pdfFilePath: string) {
    super(csvFilePath, excelFilePath)
  }
  write(input: string[]): void { /* PDF書き込み */ }
}
```

**改善例: interfaceとコンポジション**:
```typescript
class CSVReader implements Reader {
  constructor(private csvFilePath: string) {}
  read(): string[] { return ["data1", "data2"] }
}

class CSVWriter implements Writer {
  write(input: string[]): void { /* CSV書き込み */ }
}

class ExcelReader implements Reader {
  constructor(private excelFilePath: string) {}
  read(): string[] { return ["excelData1", "excelData2"] }
}

class PDFWriter implements Writer {
  write(input: string[]): void { /* PDF書き込み */ }
}

// Black-box reuse
class ReaderToWriters {
  constructor(private reader: Reader, private writers: Writer[]) {}

  perform() {
    const lines = this.reader.read();
    this.writers.forEach(writer => writer.write(lines));
  }
}
```

**利点**:
- SRP（単一責任原則）遵守
- 依存関係の最小化
- 柔軟な組み合わせ可能

---

### 1.3 モデルにはinterfaceを使う

**問題**: データモデルにclassを使うと冗長。

**悪い例**:
```typescript
class Employee {
  constructor(private id: string, private name: string) {}
  getName(): string { return this.name }
  setName(name: string) { this.name = name }
  getId(): string { return this.id }
  setId(id: string) { this.id = id }
}
```

**改善例: interface + factory関数**:
```typescript
interface Employee {
  readonly id: string;
  readonly name: string;
  readonly department: string;
}

function createEmployee(id: string, name: string, department: string): Employee {
  return { id, name, department };
}

function updateEmployee(employee: Employee, updates: Partial<Employee>): Employee {
  return { ...employee, ...updates };
}

const emp = createEmployee('1', 'John Doe', 'IT');
console.log(emp.name); // John Doe

const updatedEmp = updateEmployee(emp, { department: 'HR' });
console.log(updatedEmp.department); // HR
```

**Readonly/Partialでイミュータビリティ強化**:
```typescript
interface Project {
  id: number;
  name: string;
  description?: string;
}

type ReadonlyProject = Readonly<Project>;
type PartialProject = Partial<Project>;

const initialProject: ReadonlyProject = { id: 1, name: "TypeScript Guide" };
const updatedProject: Project = { ...initialProject, description: "Updated guide" };
```

---

## 2. 過度に寛容な型

### 2.1 any型の危険性

**問題**: 型チェック完全無効化でランタイムエラーの温床。

**悪い例**:
```typescript
function processValue(value) { // valueはany型に推論
  console.log(value.toUpperCase()) // 実行時エラーの可能性
}
processValue("hello") // 動作
processValue(123)     // ランタイムエラー: value.toUpperCase is not a function
```

**改善例: unknown + Type Guard**:
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

**原則**:
- `any`使用は禁止
- `unknown`を使い、型ガードで絞り込む
- `noImplicitAny`フラグを有効化

---

### 2.2 Function型の危険性

**問題**: 入出力型の損失。

**悪い例**:
```typescript
interface Callback {
  onEvent: Function; // 過度に寛容
}

const callback1: Callback = {
  onEvent: (a: string) => a.toUpperCase(),
};
const callback2: Callback = {
  onEvent: () => "Hello",
};
const callback3: Callback = {
  onEvent: () => 1,
};
// すべて型チェック通過だが、戻り値型が不明確
```

**改善例: ジェネリックCallback<T>**:
```typescript
interface Callback<T> {
  onEvent: (arg: T) => void;
}

const stringCallback: Callback<string> = {
  onEvent: (a) => console.log(a.toUpperCase()),
};
const numberCallback: Callback<number> = {
  onEvent: (n) => console.log(n * 2),
};

stringCallback.onEvent("hello"); // 動作
numberCallback.onEvent(5);       // 動作
// stringCallback.onEvent(5);    // エラー: 型不一致
```

**利点**:
- 型安全性向上
- コンパイル時エラー検出
- 可読性・保守性向上

---

## 3. 他言語のイディオム

### 3.1 Java: POJO/JavaBeanパターン

**問題**: TypeScriptには不適切。

**悪い例**:
```typescript
class Employee {
  constructor(private id: string, private name: string) {}
  getName(): string { return this.name }
  setName(name: string) { this.name = name }
  getId(): string { return this.id }
  setId(id: string) { this.id = id }
}
```

**問題点**:
- 複数コンストラクタ不可（TypeScript制約）
- get/setメソッドが冗長
- シリアライゼーション概念がTypeScriptに存在しない

**TypeScript流の解決策**:
```typescript
interface Employee {
  readonly id: string;
  readonly name: string;
  readonly department: string;
}

function createEmployee(id: string, name: string, department: string): Employee {
  return { id, name, department };
}

function updateEmployee(employee: Employee, updates: Partial<Employee>): Employee {
  return { ...employee, ...updates };
}
```

---

### 3.2 Go: タプルエラーハンドリング

**問題**: TypeScriptには`try/catch`がある。

**悪い例（Go風）**:
```typescript
function divideNumbers(a: number, b: number): [number | null, Error | null] {
  if (b === 0) {
    return [null, new Error("Division by zero")];
  }
  return [a / b, null];
}

const [result, err] = divideNumbers(10, 2);
if (err !== null) {
  console.error("Error:", err.message);
} else {
  console.log("Result:", result);
}
```

**改善例: try/catch + async/await**:
```typescript
function divideNumbers(a: number, b: number): number {
  if (b === 0) {
    throw new Error("Division by zero");
  }
  return a / b;
}

try {
  const result = divideNumbers(10, 2);
  console.log("Result:", result);
} catch (error) {
  console.error("Error:", error.message);
}
```

**考慮点**:
- **Explicitness（明示性）**: Goの利点は明示的エラーチェック
- **Error Propagation**: TypeScriptの例外は自動的に上位に伝播
- **async/await**: Promiseとの統合で非同期制御が容易

---

## 4. 型推論の落とし穴

### 4.1 暗黙的型付けへの過度な依存

**原則**:
```typescript
// 明示的型付け（推奨）
const arr: number[] = [1, 2, 3]

// 暗黙的型付け（単純な場合はOK）
const arr = [1, 2, 3] // number[]に推論

// 危険: 初期化なし
let x; // any型に推論（noImplicitAnyで検出）
x = 2;
```

**ベストプラクティス**:
- 変数宣言と初期化を同時に行う
- 複雑な型は明示的に宣言
- `noImplicitAny`フラグ有効化

---

### 4.2 リテラル型の推論とconst assertion

**問題**: オブジェクトリテラルは幅広い型に推論される。

**悪い例**:
```typescript
const colors = {
  red: "#FF0000",
  green: "#00FF00",
  blue: "#0000FF"
};

function getColor(color: "red" | "green" | "blue") {
  return colors[color]; // 戻り値型はstring（曖昧）
}
```

**改善例: const assertion**:
```typescript
const colors = {
  red: "#FF0000",
  green: "#00FF00",
  blue: "#0000FF"
} as const;

function getColor(color: keyof typeof colors) {
  return colors[color];
}
// 戻り値型: "#FF0000" | "#00FF00" | "#0000FF"（厳密）
```

**利点**:
- 型の正確性向上
- IDE補完の改善
- ランタイムエラー削減

---

## 5. ジェネリクスの落とし穴

### 5.1 複数ジェネリック型の命名

**悪い例**:
```typescript
interface KeyValuePair<T, K> {
  key: T;
  value: K;
}

interface ApiResponse<T, K> {
  data: T;
  error?: K;
}
```

**改善例: 説明的命名**:
```typescript
interface KeyValuePair<TKey, TValue> {
  key: TKey;
  value: TValue;
}

interface ApiResponse<TData, TError> {
  data: TData;
  error?: TError;
}
```

**命名ガイドライン**:
- 単一型: `T`はOK
- 複数型: `TKey`, `TValue`, `TData`, `TError`等の説明的命名
- キー・バリュー: `TKey/TValue`が標準的

---

### 5.2 デフォルトジェネリック型の過度な寛容性

**問題**: 空オブジェクト型`{}`はあらゆる形状を許容。

**悪い例**:
```typescript
type Config<T = {}, U = {}> = {
  ctx?: T
  data?: U
}

const t: Config = {
  ctx: {color: 'red'},
  data: {}
}

// エラー: color プロパティが型 {} に存在しない
// t.ctx.color = 'blue'
```

**改善例: 制約の明示**:
```typescript
type WithColor = { color: string };

type Config<T extends WithColor, U = {}> = {
  ctx?: T
  data?: U
}

const t: Config<WithColor> = {
  ctx: {color: 'red'},
  data: {}
}

if (t.ctx) {
  t.ctx.color = 'blue' // 動作
}
```

**別の例**:
```typescript
type FetchOptions<T extends { url: string }> = {
  params: T;
};

const options: FetchOptions<{ url: string; queryParams?: string }> = {
  params: { url: "/api/data", queryParams: "id=123" }
};
```

**原則**:
- デフォルト型に`{}`を使わない
- `extends`制約で必須プロパティを明示
- 可読性・保守性向上

---

### 5.3 TypeScript 5の新機能: NoInfer

**問題**: 型推論が両方の引数から広がる。

**悪い例**:
```typescript
function find<T extends string>(heyStack: T[], needle: T): number {
  return heyStack.indexOf(needle);
}

console.log(find(["a","b","c"],"d"))
// T は "a" | "b" | "c" | "d" に推論される（"d"が含まれるべきでない）
```

**改善例: NoInfer<T>**:
```typescript
function find<T extends string>(heyStack: T[], needle: NoInfer<T>): number {
  return heyStack.indexOf(needle)
}

// エラー: 引数 "d" は型 "a" | "b" | "c" に割り当てできません
// const invalidResult = find(["a", "b", "c"], "d");
```

**効果**:
- `needle`パラメータでの型推論を抑制
- 配列から推論された型のみ受け入れる
- コンパイル時エラー検出強化

---

## 6. OSSデザインパターン事例

### 6.1 Apollo Client

#### 6.1.1 正規化キャッシュ（Flyweightパターンの変種）

**概要**: 同一オブジェクトをメモリ内で1つのみ保持。

```typescript
const client = new ApolloClient({
  uri: "https://api.example.com/graphql",
  cache: new InMemoryCache({
    typePolicies: {
      User: {
        keyFields: ["id"],
      },
    },
  })
});
```

**利点**:
- メモリ効率化
- データ一貫性保証
- 自動キャッシュ更新

---

#### 6.1.2 Reactive Variables（Observerパターン）

**概要**: 状態変更時に自動通知。

```typescript
import { makeVar, useReactiveVar } from '@apollo/client';

const isDarkModeVar = makeVar(false);

function ThemeToggle() {
  const isDarkMode = useReactiveVar(isDarkModeVar);

  return (
    <button onClick={() => isDarkModeVar(!isDarkMode)}>
      {isDarkMode ? 'Light' : 'Dark'} Mode
    </button>
  );
}
```

**利点**:
- GraphQL非依存のローカル状態管理
- 自動再レンダリング
- テスト容易性

---

#### 6.1.3 Type Policies（Strategyパターン）

**概要**: フィールドごとの読み取り・書き込み戦略を定義。

```typescript
const cache = new InMemoryCache({
  typePolicies: {
    Query: {
      fields: {
        books: {
          merge(existing = [], incoming) {
            return [...existing, ...incoming];
          }
        }
      }
    }
  }
});
```

**利点**:
- キャッシュ動作のカスタマイズ
- ビジネスロジックとキャッシュロジックの分離

---

### 6.2 tRPC

#### 6.2.1 Procedure Builder（Builderパターン）

**概要**: 手続き定義を段階的に構築。

```typescript
const t = initTRPC.create();

const appRouter = t.router({
  hello: t.procedure
    .input((val: unknown) => {
      if (typeof val === "string") return val;
      throw new Error("Invalid input: expected string");
    })
    .query((req) => {
      return `Hello, ${req.input}!`;
    }),
});
```

**構造**:
1. `.input()`: 入力バリデーション定義
2. `.query()` / `.mutation()`: ハンドラー定義
3. メソッドチェーンで段階的構築

---

#### 6.2.2 Router（Mediatorパターン）

**概要**: プロシージャ間の通信を仲介。

```typescript
const userRouter = t.router({
  getUser: t.procedure
    .input(z.object({ id: z.string() }))
    .query(({ input }) => getUserById(input.id)),

  createUser: t.procedure
    .input(z.object({ name: z.string() }))
    .mutation(({ input }) => createUser(input.name)),
});

const appRouter = t.router({
  user: userRouter,
  post: postRouter,
});
```

**利点**:
- プロシージャの論理的グループ化
- 名前空間の整理
- 関心の分離

---

#### 6.2.3 型安全なClient-Server通信

**サーバー側**:
```typescript
const appRouter = t.router({
  hello: t.procedure
    .input((val: unknown) => {
      if (typeof val === "string") return val;
      throw new Error("Invalid input: expected string");
    })
    .query((req) => {
      return `Hello, ${req.input}!`;
    }),
});

export type AppRouter = typeof appRouter;
```

**クライアント側**:
```typescript
import { createTRPCClient, httpBatchLink } from '@trpc/client';
import type { AppRouter } from './server';

const trpc = createTRPCClient<AppRouter>({
  links: [
    httpBatchLink({
      url: 'http://localhost:3000',
    }),
  ],
});

async function main() {
  const response = await trpc.hello.query('tRPC User');
  console.log(response); // 完全な型安全性
}
```

**Factory Methodパターン**:
- `createTRPCClient<AppRouter>()`: ジェネリックでサーバー型を渡す
- クライアント作成ロジックをカプセル化

---

## まとめ

### アンチパターン回避の原則

1. **Composition over Inheritance**: 継承より合成を優先
2. **interface over class**: データモデルにはinterface
3. **unknown over any**: 型安全性を損なわない
4. **ジェネリックCallback<T> over Function**: 明示的な型パラメータ
5. **try/catch over タプルエラー**: TypeScriptのネイティブ機能を活用
6. **const assertion**: リテラル型の厳密な推論
7. **説明的ジェネリック命名**: `TKey`, `TValue`, `TData`等
8. **制約の明示**: デフォルト型に`{}`を使わない
9. **NoInfer活用**: TypeScript 5の最新機能で型推論制御

### OSSパターンから学ぶこと

- **Apollo Client**: Flyweight（正規化キャッシュ）、Observer（Reactive Variables）、Strategy（Type Policies）
- **tRPC**: Builder（Procedure Builder）、Mediator（Router）、Factory Method（クライアント作成）

これらのパターンは実戦で磨かれたベストプラクティスを示している。
