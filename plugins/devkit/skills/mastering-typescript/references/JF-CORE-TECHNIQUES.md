# JavaScript関数型プログラミングコアテクニック（Part 2: 関数型のデザインとコーディング）

map/filter/reduce・カリー化・関数合成・Lodash/Ramda・ファンクター/モナドの実践的な活用パターン。
DP-FUNCTIONAL-REACTIVE.mdの基礎概念に対し、本ファイルはJavaScript実装の具体的なパターンに焦点を当てる。

---

## 関数チェーンの構築

### map / filter / reduce の組み合わせ

```typescript
interface Student {
  firstname: string;
  lastname: string;
  ssn: string;
  address: { country: string };
  enrolled: number; // 履修科目数
  grade: number;
}

// 命令型: 繰り返しのデータ変換
function getAverageGrade(students: Student[]): number {
  let total = 0;
  let count = 0;
  for (const s of students) {
    if (s.enrolled >= 2 && s.address.country === 'US') {
      total += s.grade;
      count++;
    }
  }
  return count > 0 ? total / count : 0;
}

// 関数型: 合成可能な関数チェーン
const isEnrolledInAtLeast = (n: number) =>
  (s: Student) => s.enrolled >= n;

const isFromCountry = (country: string) =>
  (s: Student) => s.address.country === country;

const toGrade = (s: Student): number => s.grade;

const average = (grades: number[]): number =>
  grades.reduce((sum, g) => sum + g, 0) / grades.length;

// 合成して再利用可能なパイプライン
const getAverageGrade = (students: Student[]): number =>
  average(
    students
      .filter(isEnrolledInAtLeast(2))
      .filter(isFromCountry('US'))
      .map(toGrade)
  );
```

### 再帰による木構造走査

```typescript
interface TreeNode {
  value: string;
  children?: TreeNode[];
}

// 再帰でツリーを深さ優先でフラット化
function flatten(node: TreeNode): string[] {
  if (!node.children || node.children.length === 0) {
    return [node.value];
  }
  return [
    node.value,
    ...node.children.flatMap(flatten)
  ];
}

// 使用例
const tree: TreeNode = {
  value: 'Church',
  children: [
    { value: 'Rosser', children: [
      { value: 'Mendelson' },
      { value: 'Sacks' }
    ]},
    { value: 'Turing', children: [{ value: 'Gandy' }] }
  ]
};

flatten(tree);
// ['Church', 'Rosser', 'Mendelson', 'Sacks', 'Turing', 'Gandy']
```

### 遅延評価チェーン（Lodashパターン）

```typescript
// Lodashのチェーンは遅延評価（lazy evaluation）
import _ from 'lodash';

// 全データを一度に処理するのではなく、必要な時点で評価
const result = _(students)
  .filter(s => s.enrolled >= 2)   // まだ実行されない
  .map(s => s.grade)               // まだ実行されない
  .reduce((acc, g) => acc + g, 0); // ここで初めて実行（.value()等でも）

// 利点: 中間配列を生成しないため大規模データでパフォーマンス向上
```

---

## カリー化の実践パターン

### 基本実装と型安全性

```typescript
// 型安全な2引数カリー化
function curry2<A, B, C>(fn: (a: A, b: B) => C): (a: A) => (b: B) => C {
  return (a: A) => (b: B) => fn(a, b);
}

// 使用例
const divide = curry2((dividend: number, divisor: number): number =>
  dividend / divisor
);

const halve = divide(10); // 部分適用: 10 / ?
halve(2);  // 5
halve(5);  // 2
```

### パターン1: 関数ファクトリ（依存性の注入）

```typescript
// カリー化で関数インターフェースをエミュレート
interface StudentStore {
  get(id: string): Student | null;
}

// データソースを抽象化したファクトリ
const fetchStudentFrom = (store: StudentStore) =>
  (id: string): Student | null => store.get(id);

// 実行時に実装を切り替え可能
const findFromDB = fetchStudentFrom(dbStore);
const findFromCache = fetchStudentFrom(cacheStore);

// テスト時はモックを注入
const findFromMock = fetchStudentFrom({ get: () => mockStudent });
```

### パターン2: 再利用可能な関数テンプレート

```typescript
// ログレベルと出力先を部分適用で固定
type LogLevel = 'info' | 'warn' | 'error';
type LogTarget = 'console' | 'file' | 'remote';

const createLogger = (target: LogTarget) =>
  (level: LogLevel) =>
    (message: string): void => {
      const entry = `[${level.toUpperCase()}][${target}] ${message}`;
      if (target === 'console') {
        if (level === 'error') console.error(entry);
        else if (level === 'warn') console.warn(entry);
        else console.log(entry);
      }
      // file/remote の実装は省略
    };

// 特化したロガーを生成
const consoleLogger = createLogger('console');
const errorToConsole = consoleLogger('error');
const warnToConsole = consoleLogger('warn');

errorToConsole('Something went wrong!');
warnToConsole('This is a warning');
```

### パターン3: 型チェック関数

```typescript
// Ramdaスタイルの型チェックカリー化
const checkType = <T>(typeCtor: new (...args: unknown[]) => T) =>
  (value: unknown): T => {
    if (!(value instanceof typeCtor)) {
      throw new TypeError(
        `Type mismatch. Expected [${typeCtor.name}] but found [${typeof value}]`
      );
    }
    return value as T;
  };

const checkString = checkType(String);
const checkNumber = checkType(Number);

checkString(new String('hello')); // OK
// checkString(42); // TypeError: Type mismatch
```

---

## 関数合成の実践パターン

### compose と pipe

```typescript
// compose: 右から左に実行（数学的記法）
const compose = <T>(...fns: Array<(arg: T) => T>) =>
  (x: T): T => fns.reduceRight((acc, fn) => fn(acc), x);

// pipe: 左から右に実行（読みやすい）
const pipe = <T>(...fns: Array<(arg: T) => T>) =>
  (x: T): T => fns.reduce((acc, fn) => fn(acc), x);

// 実践例: 名前のフォーマット
const trim = (str: string): string => str.trim();
const normalize = (str: string): string => str.replace(/-/g, '');
const truncate = (max: number) => (str: string): string =>
  str.length > max ? str.slice(0, max) + '...' : str;

// pipeで読みやすく記述
const formatSsn = pipe(trim, normalize, truncate(9));
formatSsn(' 444-44-4444 '); // '444444444'
```

### コンビネータパターン

```typescript
// tap: デバッグ用の副作用挿入（値を変更しない）
const tap = <T>(fn: (value: T) => void) =>
  (value: T): T => {
    fn(value);
    return value;
  };

// fork: 1つの入力を2つの関数で処理して結合
const fork = <T, U, V>(
  join: (a: U, b: V) => unknown,
  fn1: (x: T) => U,
  fn2: (x: T) => V
) => (value: T) => join(fn1(value), fn2(value));

// 使用例: 平均計算
const sum = (nums: number[]): number => nums.reduce((a, b) => a + b, 0);
const length = (arr: unknown[]): number => arr.length;
const average = fork(
  (total: number, count: number) => total / count,
  sum,
  length
);

average([80, 90, 100]); // 90
```

---

## Tuple型による型安全な複数値返却

```typescript
// 型安全なTuple（固定長・型付きの配列）
type Pair<A, B> = readonly [A, B];

function pair<A, B>(first: A, second: B): Pair<A, B> {
  return Object.freeze([first, second]) as Pair<A, B>;
}

// Validation結果をTupleで返す
type ValidationResult = Pair<boolean, string>;

const validateSsn = (ssn: string): ValidationResult => {
  const normalized = ssn.replace(/-/g, '').trim();
  if (normalized.length !== 9) {
    return pair(false, 'Invalid input. Expected 9 digits.');
  }
  return pair(true, 'Valid SSN');
};

const [isValid, message] = validateSsn('444-44-4444');
// isValid: true, message: 'Valid SSN'
```

---

## Either型: 型安全なエラー処理

> 基本的なMaybe実装はDP-FUNCTIONAL-REACTIVE.mdを参照。
> 本セクションではEither（エラー情報付きの分岐）に焦点を当てる。

### Either の実装

```typescript
// Either: Left（エラー）またはRight（成功）
abstract class Either<L, R> {
  abstract isLeft(): this is Left<L, R>;
  abstract isRight(): this is Right<L, R>;
  abstract map<U>(fn: (value: R) => U): Either<L, U>;
  abstract chain<U>(fn: (value: R) => Either<L, U>): Either<L, U>;
  abstract getOrElse(defaultValue: R): R;
}

class Left<L, R> extends Either<L, R> {
  constructor(private error: L) { super(); }
  isLeft(): this is Left<L, R> { return true; }
  isRight(): this is Right<L, R> { return false; }
  map<U>(_fn: (value: R) => U): Either<L, U> { return new Left<L, U>(this.error); }
  chain<U>(_fn: (value: R) => Either<L, U>): Either<L, U> { return new Left<L, U>(this.error); }
  getOrElse(defaultValue: R): R { return defaultValue; }
  getError(): L { return this.error; }
}

class Right<L, R> extends Either<L, R> {
  constructor(private value: R) { super(); }
  isLeft(): this is Left<L, R> { return false; }
  isRight(): this is Right<L, R> { return true; }
  map<U>(fn: (value: R) => U): Either<L, U> { return new Right<L, U>(fn(this.value)); }
  chain<U>(fn: (value: R) => Either<L, U>): Either<L, U> { return fn(this.value); }
  getOrElse(_defaultValue: R): R { return this.value; }
  getValue(): R { return this.value; }
}

const left = <L, R>(error: L): Either<L, R> => new Left<L, R>(error);
const right = <L, R>(value: R): Either<L, R> => new Right<L, R>(value);
```

### Either を使ったエラー処理パイプライン

```typescript
const checkLength = (ssn: string): Either<string, string> =>
  ssn.length === 9 ? right(ssn) : left('Invalid length');

const checkFormat = (ssn: string): Either<string, string> =>
  /^\d{9}$/.test(ssn) ? right(ssn) : left('Invalid format: digits only');

// チェーンによるパイプライン構築
const validateSsn = (input: string): Either<string, string> =>
  right<string, string>(input.replace(/-/g, '').trim())
    .chain(checkLength)
    .chain(checkFormat);

const result = validateSsn('444-44-4444');
if (result.isRight()) {
  console.log('Valid:', result.getValue());
} else {
  console.log('Error:', (result as Left<string, string>).getError());
}
```

---

## Ramdaを使った関数型スタイル

```typescript
import * as R from 'ramda';

interface Student {
  ssn: string;
  firstname: string;
  lastname: string;
  grade: number;
  country: string;
}

// Ramdaのカリー化関数を組み合わせる
const processStudents = R.pipe(
  R.filter(R.propEq('country', 'US')),        // 米国の学生のみ
  R.sortBy(R.prop('ssn')),                    // SSNでソート
  R.map(R.pick(['ssn', 'firstname', 'grade'])) // 必要なフィールドのみ
);

// R.curry で独自関数をカリー化
const safeDivide = R.curry((dividend: number, divisor: number) => {
  if (divisor === 0) throw new Error('Division by zero');
  return dividend / divisor;
});

const halve = safeDivide(R.__, 2); // プレースホルダーで第2引数を固定
halve(10); // 5
```

---

## 判断基準: テクニック選択ガイド

| 状況 | 推奨テクニック | 理由 |
|------|--------------|------|
| コレクション変換 | map/filter/reduce | 宣言的、再利用可能 |
| 複数の検証ステップ | Either チェーン | エラー情報を保持しながら処理 |
| null安全な処理 | Maybe（DP-FUNCTIONAL-REACTIVEを参照） | nullチェックを排除 |
| 関数の段階的適用 | カリー化 | 部分適用で再利用性向上 |
| 複数関数の結合 | compose/pipe | 読みやすいパイプライン |
| 依存性の注入 | カリー化ファクトリ | テストでモック注入可能 |
| 副作用の分離 | IO モナド | 純粋なコードを保護 |
