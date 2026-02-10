# エラー処理戦略

> TypeScriptにおける型安全なエラー処理パターンとその使い分け

## 目次

1. [null を返す](#1-null-を返す)
2. [例外をスローする](#2-例外をスローする)
3. [例外を返す](#3-例外を返す)
4. [Option型パターン](#4-option型パターン)
5. [エラー処理戦略の比較](#5-エラー処理戦略の比較)

---

## 1. null を返す

最も軽量なエラー処理方法。

### パターン

```typescript
function parse(birthday: string): Date | null {
  const date = new Date(birthday)
  if (!isValid(date)) {
    return null
  }
  return date
}

function isValid(date: Date): boolean {
  return Object.prototype.toString.call(date) === '[object Date]'
    && !Number.isNaN(date.getTime())
}

// 使用例
const date = parse(userInput)
if (date) {
  console.info('Date is', date.toISOString())
} else {
  console.error('Error parsing date')
}
```

### メリット

- 型安全
- 軽量で実装が簡単
- TypeScriptが両方のケース（成功とnull）の処理を強制

### デメリット

- **失敗理由が不明**: なぜエラーになったか正確な情報がない
- **操作の連鎖が困難**: 複数の操作を組み立てる際に冗長になる
- **デバッグが難しい**: ログから原因を特定しづらい

---

## 2. 例外をスローする

カスタムエラークラスで失敗の種類を区別する。

### パターン

```typescript
// カスタムエラー型
class InvalidDateFormatError extends RangeError {}
class DateIsInTheFutureError extends RangeError {}

function parse(birthday: string): Date {
  const date = new Date(birthday)
  if (!isValid(date)) {
    throw new InvalidDateFormatError('Enter a date in the form YYYY/MM/DD')
  }
  if (date.getTime() > Date.now()) {
    throw new DateIsInTheFutureError('Are you a timelord?')
  }
  return date
}

// 使用例
try {
  const date = parse(userInput)
  console.info('Date is', date.toISOString())
} catch (e) {
  if (e instanceof InvalidDateFormatError) {
    console.error(e.message)
  } else if (e instanceof DateIsInTheFutureError) {
    console.info(e.message)
  } else {
    throw e
  }
}
```

### メリット

- **詳細な失敗情報**: カスタムエラーで失敗理由を明確化
- **操作の連鎖が容易**: 1つのtry/catchで複数の操作をラップ可能
- **デバッグが容易**: スタックトレースとメタデータ

### デメリット

- **型シグネチャに含まれない**: 関数が何をスローするか型で表現できない
- **処理忘れのリスク**: 型システムがエラー処理漏れを検出できない
- **ドキュメントが必要**: JSDocでスローする例外を明示する必要がある

### ドキュメント例

```typescript
/**
 * @throws {InvalidDateFormatError} ユーザーが誕生日を間違って入力した
 * @throws {DateIsInTheFutureError} ユーザーが未来の誕生日を入力した
 */
function parse(birthday: string): Date {
  // ...
}
```

---

## 3. 例外を返す

合併型を使って例外をシグネチャに含める。

### パターン

```typescript
function parse(
  birthday: string
): Date | InvalidDateFormatError | DateIsInTheFutureError {
  const date = new Date(birthday)
  if (!isValid(date)) {
    return new InvalidDateFormatError('Enter a date in the form YYYY/MM/DD')
  }
  if (date.getTime() > Date.now()) {
    return new DateIsInTheFutureError('Are you a timelord?')
  }
  return date
}

// 使用例
const result = parse(userInput)
if (result instanceof InvalidDateFormatError) {
  console.error(result.message)
} else if (result instanceof DateIsInTheFutureError) {
  console.error(result.message)
} else {
  console.info('Date is', result.toISOString())
}
```

### メリット

- **型安全なエラー宣言**: 起こり得る例外がシグネチャに明示される
- **処理の強制**: すべてのエラーケースの処理を利用者に強制
- **明示的なエラー伝播**: エラーを上位に伝播させる意図が明確

### デメリット

- **操作の連鎖が冗長**: エラーを返す操作を連鎖させると急速に複雑化
- **エラー型の蓄積**: 関数を重ねるとエラー型のリストが膨大になる

### エラーの伝播例

```typescript
function x(): T | Error1 { /* ... */ }

function y(): U | Error1 | Error2 {
  const a = x()
  if (a instanceof Error) {
    return a  // エラーを伝播
  }
  // aを使って処理
}

function z(): V | Error1 | Error2 | Error3 {
  const a = y()
  if (a instanceof Error) {
    return a  // さらに伝播
  }
  // aを使って処理
}
```

---

## 4. Option型パターン

Haskell/Scala/Rust由来の型安全なコンテナパターン。

### 基本構造

```typescript
interface Option<T> {
  flatMap<U>(f: (value: T) => Option<U>): Option<U>
  getOrElse(value: T): T
}

class Some<T> implements Option<T> {
  constructor(private value: T) {}

  flatMap<U>(f: (value: T) => Option<U>): Option<U> {
    return f(this.value)
  }

  getOrElse(): T {
    return this.value
  }
}

class None implements Option<never> {
  flatMap<U>(): Option<U> {
    return this
  }

  getOrElse<U>(value: U): U {
    return value
  }
}
```

### オーバーロードによる型の絞り込み

```typescript
interface Option<T> {
  flatMap<U>(f: (value: T) => None): None
  flatMap<U>(f: (value: T) => Option<U>): Option<U>
  getOrElse(value: T): T
}

class Some<T> implements Option<T> {
  flatMap<U>(f: (value: T) => None): None
  flatMap<U>(f: (value: T) => Some<U>): Some<U>
  flatMap<U>(f: (value: T) => Option<U>): Option<U> {
    return f(this.value)
  }
  // ...
}
```

### Option関数（コンパニオンオブジェクト）

```typescript
function Option<T>(value: null | undefined): None
function Option<T>(value: T): Some<T>
function Option<T>(value: T): Option<T> {
  if (value == null) {
    return new None
  }
  return new Some(value)
}
```

### 使用例

```typescript
// 失敗する可能性のある操作の連鎖
ask()                                              // Option<string>
  .flatMap(parse)                                  // Option<Date>
  .flatMap(date => new Some(date.toISOString()))   // Option<string>
  .flatMap(date => new Some('Date is ' + date))    // Option<string>
  .getOrElse('Error parsing date for some reason') // string
```

### メリット

- **操作の連鎖**: flatMapで失敗する可能性のある操作を簡潔に連鎖
- **型安全性**: 失敗の可能性を型システムで表現
- **明示的な失敗モード**: Noneで失敗を明確に示す

### デメリット

- **失敗理由が不明**: Noneは「失敗した」ことしか示さない
- **相互運用性**: Option型を使わないコードとの統合が必要
- **学習コスト**: 関数型プログラミングの概念に慣れが必要

---

## 5. エラー処理戦略の比較

### 選択基準

| 基準 | 推奨戦略 |
|------|---------|
| **情報量** | |
| 失敗したことだけ伝える | null、Option |
| 失敗理由も伝える | 例外をスロー、例外を返す |
| **処理の強制** | |
| すべてのエラーを明示的に処理 | 例外を返す |
| ボイラープレートを減らす | 例外をスロー |
| **操作の組み立て** | |
| エラーを組み立てる必要がある | Option |
| エラー発生時にその場で処理 | null、例外 |

### パターンの使い分け

```typescript
// 1. シンプルな検証 → null
function validateEmail(email: string): string | null {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ? email : null
}

// 2. 詳細なエラー情報が必要 → 例外をスロー
function connectDatabase(config: DbConfig): Connection {
  if (!config.host) {
    throw new ConfigurationError('Host is required')
  }
  // ...
}

// 3. APIレベルでの型安全性 → 例外を返す
function getUser(id: string): User | UserNotFoundError | DatabaseError {
  // ...
}

// 4. 複数の失敗操作の連鎖 → Option
function processRequest(): Option<Response> {
  return validateInput()
    .flatMap(authenticate)
    .flatMap(authorize)
    .flatMap(execute)
}
```

### 戦略の組み合わせ

実際のアプリケーションでは複数の戦略を併用する：

- **ドメイン境界内**: Option型で型安全な連鎖
- **APIレイヤー**: 例外を返して明示的なエラー型
- **インフラ層**: 例外をスローして詳細情報
- **簡易検証**: nullで軽量チェック

---

## まとめ

TypeScriptの型システムを活用した4つのエラー処理戦略：

1. **null**: 軽量だが情報が少ない
2. **例外をスロー**: 詳細だが型安全性が低い
3. **例外を返す**: 型安全だが冗長
4. **Option型**: 連鎖可能だが学習コストあり

プロジェクトの特性、チームの経験、パフォーマンス要件に応じて適切な戦略を選択し、一貫性を保つことが重要。
