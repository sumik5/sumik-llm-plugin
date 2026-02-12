# 関数型プログラミングとリアクティブパターン

TypeScript 5における関数型プログラミング（Ch7）とリアクティブ・非同期プログラミング（Ch8）のパターン集。

---

## 純粋関数と不変性

### 純粋関数 (Pure Functions)

**概念**: 同じ入力に対して常に同じ出力を返し、副作用を持たない関数。

```typescript
// 純粋関数
function add(a: number, b: number): number {
  return a + b;
}

// 不純な関数（外部状態を変更）
let count = 0;
function incrementAndLog(value: number): number {
  count++; // 外部状態を変更
  console.log(`Count is now ${count}`); // 副作用
  return value + 1;
}
```

**使用場面**:
- テスト可能性が重要な箇所
- 並列処理・キャッシュが必要な計算
- 予測可能な動作が求められる関数

**注意点**:
- IO操作（ファイル、ネットワーク、console.log）は副作用
- 外部変数の変更も副作用とみなされる

---

## 不変性 (Immutability)

### constによる基本的な不変性

```typescript
const name = "Alice";
// name = "Bob"; // Error: Cannot assign to 'name'

const numbers = [1, 2, 3];
numbers.push(4); // OK - 配列自体は変更可能
// numbers = [5, 6, 7]; // Error
```

### Readonly型による不変性

```typescript
interface User {
  name: string;
  age: number;
}

const user: Readonly<User> = {
  name: "Alice",
  age: 30
};

// user.age = 31; // Error: Cannot assign to 'age'
```

### DeepReadonly（深い不変性）

```typescript
type DeepReadonly<T> =
  T extends (infer R)[] ? ReadonlyArray<DeepReadonly<R>> :
  T extends Function ? T :
  T extends object ? {readonly [K in keyof T]: DeepReadonly<T[K]>} : T;

interface Department {
  name: string;
  employees: {id: number, name: string}[];
}

const dept: DeepReadonly<Department> = {
  name: "Engineering",
  employees: [{id: 1, name: "Alice"}]
};

// dept.name = "Sales"; // Error
// dept.employees.push({id: 2, name: "Bob"}); // Error
```

**使用場面**:
- Redux/Fluxパターンでの状態管理
- イミュータブルなデータ構造が必要な箇所

**注意点**:
- TypeScriptの型レベルでの制約であり、ランタイムでは強制されない
- `as any` で回避可能なため、チーム規約での運用が重要
- Immutable.js等のライブラリでランタイム不変性を保証可能

---

## 再帰 (Recursion)

### 基本的な再帰

```typescript
function factorial(n: number): number {
  if (n <= 1) return 1; // ベースケース
  return n * factorial(n - 1); // 再帰ケース
}

console.log(factorial(5)); // 120
```

**可視化**:
```
factorial(5) -> 5 * factorial(4)
             -> 5 * 4 * factorial(3)
             -> 5 * 4 * 3 * factorial(2)
             -> 5 * 4 * 3 * 2 * factorial(1)
             -> 5 * 4 * 3 * 2 * 1 = 120
```

### ツリー再帰

```typescript
interface TreeNode {
  value: number;
  left?: TreeNode;
  right?: TreeNode;
}

function inOrder(node: TreeNode | undefined): number[] {
  if (!node) return [];
  return [...inOrder(node.left), node.value, ...inOrder(node.right)];
}
```

### 末尾再帰最適化

```typescript
function factorialTail(n: number, accumulator: number = 1): number {
  if (n <= 1) return accumulator;
  return factorialTail(n - 1, n * accumulator);
}
```

**注意点**:
- **TypeScript/JavaScriptは末尾呼び出し最適化をサポートしていない**
- 大きな入力でスタックオーバーフローの可能性
- ループやイテレーションの方が安全な場合がある

---

## 関数合成 (Function Composition)

### 基本的な合成

```typescript
function double(x: number): number {
  return x * 2;
}

function increment(x: number): number {
  return x + 1;
}

const doubleAndIncrement = (x: number): number => increment(double(x));
console.log(doubleAndIncrement(3)); // 7
```

### composeユーティリティ

```typescript
function compose<T>(...fns: Array<(arg: T) => T>) {
  return (x: T) => fns.reduceRight((acc, fn) => fn(acc), x);
}

const formatName = compose(
  (s: string) => truncate(s, 10),
  removeSpaces,
  capitalizeFirstLetter
);
```

**パフォーマンス注意**:
- 深いネストは呼び出しスタックとメモリを消費
- 3-4関数以上の合成は分割を検討

---

## カリー化 (Currying)

### 基本的なカリー化

```typescript
function curry<T, U, V>(fn: (a: T, b: U) => V): (a: T) => (b: U) => V {
  return (a: T) => (b: U) => fn(a, b);
}

const add = (a: number, b: number) => a + b;
const curriedAdd = curry(add);
const add5 = curriedAdd(5);

console.log(add5(3)); // 8
```

### 合成との組み合わせ

```typescript
const truncate = (str: string, length: number): string =>
  str.length > length ? str.slice(0, length) + '...' : str;

const curriedTruncate = curry(truncate);

const formatAndTruncate = compose(
  (s: string) => curriedTruncate(s)(7),
  removeSpaces,
  capitalizeFirstLetter
);
```

---

## 高階関数 (Higher-Order Functions)

### 関数を引数に取る

```typescript
function executeOperation(
  x: number,
  y: number,
  operation: (a: number, b: number) => number
): number {
  return operation(x, y);
}

const multiply = (a: number, b: number) => a * b;
console.log(executeOperation(5, 3, multiply)); // 15
```

### 関数を返す（クロージャ）

```typescript
function createMultiplier(factor: number): (x: number) => number {
  return function(x: number): number {
    return x * factor;
  };
}

const double = createMultiplier(2);
const triple = createMultiplier(3);
console.log(double(5)); // 10
console.log(triple(5)); // 15
```

---

## Functor

### 基本実装

```typescript
class Box<T> {
  constructor(private value: T) {}

  map<U>(f: (value: T) => U): Box<U> {
    return new Box(f(this.value));
  }

  toString(): string {
    return `Box(${this.value})`;
  }
}

const box = new Box(5);
const result = box.map(x => x * 2).map(x => x + 1);
console.log(result.toString()); // Box(11)
```

### fp-tsでの使用

```typescript
import { pipe } from "fp-ts/function";
import * as A from 'fp-ts/Array';

const numbers = [1, 2, 3, 4];
const doubleArray = pipe(
  numbers,
  A.map(n => n * 2)
);
// [2, 4, 6, 8]
```

**使用場面**:
- コンテキスト内の値を変換したい場合
- チェーン可能な操作が必要な場合

---

## Lens (関数型レンズ)

### 基本実装

```typescript
export interface Lens<T, A> {
  get: (obj: T) => A;
  set: (obj: T) => (newValue: A) => T;
}

function lensProp<T, K extends keyof T>(key: K): Lens<T, T[K]> {
  return {
    get: (obj: T): T[K] => obj[key],
    set: (obj: T) => (value: T[K]): T => ({ ...obj, [key]: value }),
  };
}
```

### 使用例

```typescript
interface Person {
  name: string;
  age: number;
  email: string;
}

const person: Person = {
  name: "John",
  age: 30,
  email: "john@example.com",
};

const ageLens = lensProp<Person, "age">("age");
const currentAge = ageLens.get(person); // 30
const updatedPerson = ageLens.set(person)(35);
```

### ヘルパー関数

```typescript
function view<T, A>(lens: Lens<T, A>, obj: T): A {
  return lens.get(obj);
}

function set<T, A>(lens: Lens<T, A>, obj: T, value: A): T {
  return lens.set(obj)(value);
}

function over<T, A>(lens: Lens<T, A>, f: (x: A) => A, obj: T): T {
  return lens.set(obj)(f(lens.get(obj)));
}

const increaseAge = over(ageLens, (val: number) => val + 1, person);
```

**使用場面**:
- Reduxのようなイミュータブルな状態管理
- 深くネストされたオブジェクトの更新
- 関数合成による複雑なデータ変換

---

## Monad

### Maybe Monad

```typescript
class Maybe<T> {
  private constructor(private value: T | null) {}

  static just<T>(value: T): Maybe<T> {
    return new Maybe(value);
  }

  static nothing<T>(): Maybe<T> {
    return new Maybe<T>(null);
  }

  map<U>(f: (value: T) => U): Maybe<U> {
    return this.value === null
      ? Maybe.nothing()
      : Maybe.just(f(this.value));
  }

  flatMap<U>(fn: (value: T) => Maybe<U>): Maybe<U> {
    return this.value === null
      ? Maybe.nothing()
      : fn(this.value);
  }

  getOrElse(defaultValue: T): T {
    return this.value !== null ? this.value : defaultValue;
  }
}
```

### 使用例

```typescript
function safeDivide(x: number, y: number): Maybe<number> {
  return y !== 0 ? Maybe.just(x / y) : Maybe.nothing();
}

function safeSquareRoot(x: number): Maybe<number> {
  return x >= 0 ? Maybe.just(Math.sqrt(x)) : Maybe.nothing();
}

const result = safeDivide(16, 4).flatMap(safeSquareRoot);
console.log(result); // Maybe { value: 2 }

const invalidResult = safeDivide(16, 0).flatMap(safeSquareRoot);
console.log(invalidResult); // Maybe { value: null }
```

**使用場面**:
- null/undefinedチェックを排除したい場合
- オプショナルな値を安全に連鎖させたい場合
- エラー処理を型安全に行いたい場合

---

## Promise パターン

### Promise.all - 並列実行

```typescript
async function fetchAllUsers(): Promise<User[]> {
  const promises = [
    fetchUser(1),
    fetchUser(2),
    fetchUser(3)
  ];

  return Promise.all(promises);
}
```

### Promise.race - 最速実行

```typescript
async function fetchWithTimeout<T>(
  promise: Promise<T>,
  timeout: number
): Promise<T> {
  const timeoutPromise = new Promise<never>((_, reject) =>
    setTimeout(() => reject(new Error('Timeout')), timeout)
  );

  return Promise.race([promise, timeoutPromise]);
}
```

### Promiseチェーン

```typescript
fetch('/api/user')
  .then(response => response.json())
  .then(user => fetchUserPosts(user.id))
  .then(posts => posts.filter(p => p.published))
  .catch(error => console.error(error));
```

---

## Async/Await パターン

### 型安全な非同期処理

```typescript
async function getUserWithPosts(userId: number): Promise<{user: User, posts: Post[]}> {
  try {
    const user = await fetchUser(userId);
    const posts = await fetchUserPosts(user.id);

    return { user, posts };
  } catch (error) {
    if (error instanceof NetworkError) {
      throw new CustomError('Failed to fetch user data');
    }
    throw error;
  }
}
```

### エラーハンドリング

```typescript
type Result<T, E = Error> =
  | { ok: true; value: T }
  | { ok: false; error: E };

async function safeAsyncCall<T>(
  fn: () => Promise<T>
): Promise<Result<T>> {
  try {
    const value = await fn();
    return { ok: true, value };
  } catch (error) {
    return { ok: false, error: error as Error };
  }
}
```

---

## Observable パターン (RxJS)

### 基本的なObservable

```typescript
import { Observable } from 'rxjs';

const observable = new Observable<number>(subscriber => {
  subscriber.next(1);
  subscriber.next(2);
  subscriber.next(3);
  setTimeout(() => {
    subscriber.next(4);
    subscriber.complete();
  }, 1000);
});

observable.subscribe({
  next(x) { console.log('got value ' + x); },
  error(err) { console.error('error: ' + err); },
  complete() { console.log('done'); }
});
```

### オペレータによる変換

```typescript
import { of } from 'rxjs';
import { map, filter, debounceTime } from 'rxjs/operators';

const source$ = of(1, 2, 3, 4, 5);

source$.pipe(
  filter(x => x % 2 === 0),
  map(x => x * 10)
).subscribe(x => console.log(x)); // 20, 40
```

### イベントストリーム

```typescript
import { fromEvent } from 'rxjs';
import { debounceTime, map, distinctUntilChanged } from 'rxjs/operators';

const searchBox = document.getElementById('search');
const typeahead = fromEvent(searchBox, 'input').pipe(
  map((e: Event) => (e.target as HTMLInputElement).value),
  debounceTime(300),
  distinctUntilChanged()
);

typeahead.subscribe(searchTerm => {
  console.log(searchTerm);
});
```

**使用場面**:
- 複数の非同期イベントをストリームとして扱いたい場合
- リアクティブプログラミングが必要な場合
- Debounce、Throttle等の複雑な制御が必要な場合

---

## AsyncIterator / AsyncGenerator

### AsyncIterator

```typescript
async function* asyncGenerator() {
  yield await Promise.resolve(1);
  yield await Promise.resolve(2);
  yield await Promise.resolve(3);
}

(async () => {
  for await (const num of asyncGenerator()) {
    console.log(num);
  }
})();
```

### ページネーション処理

```typescript
async function* fetchAllPages<T>(
  fetchPage: (page: number) => Promise<T[]>
): AsyncGenerator<T[], void, unknown> {
  let page = 1;
  while (true) {
    const items = await fetchPage(page);
    if (items.length === 0) break;
    yield items;
    page++;
  }
}

(async () => {
  for await (const items of fetchAllPages(fetchUsers)) {
    console.log(`Fetched ${items.length} users`);
  }
})();
```

**使用場面**:
- ページネーションされたAPIの処理
- 大量データのストリーミング処理
- 遅延評価が必要な非同期処理

---

## まとめ

### 関数型プログラミングの利点

- **予測可能性**: 純粋関数により副作用が明確
- **テスト容易性**: 入力と出力のみで検証可能
- **並列処理**: 副作用がないため安全に並列化可能
- **再利用性**: 高階関数による柔軟な組み合わせ

### リアクティブプログラミングの利点

- **イベント駆動**: 非同期イベントを宣言的に処理
- **合成可能**: オペレータによる柔軟なストリーム変換
- **バックプレッシャー**: データフローの制御が容易

### 注意点

- TypeScriptの型推論の限界（HKT非サポート）
- パフォーマンスオーバーヘッド（関数呼び出しコスト）
- 学習曲線（関数型の概念理解が必要）
- fp-ts等のライブラリ活用を推奨
