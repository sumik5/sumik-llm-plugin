# テストのアンチパターン

> 出典: Vladimir Khorikov「単体テストの考え方/使い方（Unit Testing: Principles, Practices, and Patterns）」第11章

---

## 概要

アンチパターンとは、表面上は問題を適切に対処しているように見えても、後になってより大きな問題として遭遇することになる間違った解決方法のパターン。本章のアンチパターンはすべて、良い単体テストを構成する **4本の柱** の観点で問題を説明できる。

| 柱 | 説明 |
|----|------|
| **退行に対する保護** | バグを検出できるか |
| **リファクタリングへの耐性** | コード変更で偽陽性が出ないか |
| **迅速なフィードバック** | テストが速く実行できるか |
| **保守のしやすさ** | テストの読み書きが容易か |

---

## 1. プライベートなメソッドに対する単体テスト

**問題**: テストを可能にするためだけに、本来プライベートであるべきメソッドを公開すること。

**原因**: プライベートなメソッドが複雑すぎて、公開APIから間接的に十分テストできないように見えるため。しかし、これは「抽象化の欠落」が原因。

**4本の柱との関係**:
- **リファクタリングへの耐性↓**: テストが実装の詳細に結び付き、内部リファクタリングで偽陽性が発生する
- **退行に対する保護↓**: テストが振る舞いではなく内部構造を検証するため、本当のバグを見逃す可能性がある

**対処**:
1. プライベートなメソッドを **観察可能な振る舞いの一部として間接的に検証** する
2. 網羅率が不十分なら、コード設計を見直して抽象化を別クラスとして抽出する（Humble Object パターン）
3. 極めてまれな例外: O/Rマッパーなどが呼び出すプライベートコンストラクタは、観察可能な振る舞いの一部となるため公開しても問題ない

**コード例 (NG)**:

```typescript
class Order {
  private getPrice(): number { // 複雑なビジネスロジック
    const base = this.products.reduce((sum, p) => sum + p.price, 0)
    const discount = this.customer.isPreferred ? base * 0.05 : 0
    const tax = base * 0.1
    return base - discount + tax
  }

  generateDescription(): string {
    return `Total: ${this.getPrice()}`
  }
}

// NG: プライベートメソッドを公開してテスト
// (TypeScriptでは型アサーションでアクセス可能だが、これがアンチパターン)
it('getPrice calculates correctly', () => {
  const order = new Order(customer, products)
  const actual = (order as any).getPrice() // 実装の詳細に結び付いている
  expect(actual).toBe(100)
})
```

**コード例 (OK)**:

```typescript
// ✅ ビジネスロジックを独立クラスとして抽出（抽象化の欠落を解消）
class PriceCalculator {
  calculate(customer: Customer, products: Product[]): number {
    const base = products.reduce((sum, p) => sum + p.price, 0)
    const discount = customer.isPreferred ? base * 0.05 : 0
    const tax = base * 0.1
    return base - discount + tax
  }
}

// 独立クラスになったので出力値ベーステストが可能
it('calculates price with preferred discount', () => {
  const calc = new PriceCalculator()
  const actual = calc.calculate(preferredCustomer, products)
  const expected = 95  // 期待値はハードコード（アルゴリズムの再実装ではなく）
  expect(actual).toBe(expected)
})
```

---

## 2. プライベートな状態の公開

**問題**: テストのためだけに、本来プライベートであるべき状態（フィールド/プロパティ）を公開すること。

**原因**: 副作用の確認に最も手軽な方法が内部状態の直接参照に見えるため。

**4本の柱との関係**:
- **リファクタリングへの耐性↓**: テストが実装の詳細に結び付き、内部表現を変更するだけでテストが壊れる
- **保守のしやすさ↓**: テスト専用のAPIが増え、コードが理解しにくくなる

**対処**: テストでは **プロダクションコードと同じ方法でコードとやり取りする**。状態変更の副作用は、その変更が引き起こす **観察可能な振る舞い（公開APIの出力）** で検証する。

**コード例 (NG)**:

```typescript
class Customer {
  private status: 'Regular' | 'Preferred' = 'Regular' // プライベートな状態

  promote(): void {
    this.status = 'Preferred'
  }

  getDiscount(): number {
    return this.status === 'Preferred' ? 0.05 : 0
  }
}

// NG: テストのためだけに status を公開してしまうアンチパターン
it('promote changes status to Preferred', () => {
  const customer = new Customer()
  customer.promote()
  expect((customer as any).status).toBe('Preferred') // 内部状態を直接確認
})
```

**コード例 (OK)**:

```typescript
// ✅ 観察可能な振る舞い（割引率）で検証する
it('promoted customer receives 5% discount', () => {
  const customer = new Customer()
  customer.promote()

  const actual = customer.getDiscount()
  const expected = 0.05
  expect(actual).toBe(expected) // 振る舞いで確認
})
```

> **原則**: テストのためにプライベートな API を公開してはならない。

---

## 3. テストへのドメイン知識の漏洩

**問題**: テスト内でプロダクションコードのロジックやアルゴリズムを再実装すること。

**原因**: 複雑なアルゴリズムの「正しさ」を確認しようとする際に、同じ計算式をテストにも書いてしまうため。

**4本の柱との関係**:
- **リファクタリングへの耐性↓**: プロダクションコードのアルゴリズムを変更するたびにテストも同じように変更が必要になり、本来の誤りを検出できない
- **退行に対する保護↓**: プロダクションコードにバグがあっても、テストが同じバグを含む計算式を使うと偽陰性（見逃し）になる

**対処**: テストの期待値は **ハードコードした具体的な値** で書く。アルゴリズムを再実装するのではなく、独立した方法（ドメインエキスパートとの確認など）で算出した値を直接記述する。

**コード例 (NG)**:

```typescript
const add = (a: number, b: number): number => a + b

// NG: プロダクションコードのロジック（a + b）をテストに複製している
it.each([
  [1, 3],
  [11, 33],
  [100, 500],
])('adds two numbers (%d + %d)', (value1, value2) => {
  const expected = value1 + value2 // ドメイン知識の漏洩！
  const actual = add(value1, value2)
  expect(actual).toBe(expected)
})
```

**コード例 (OK)**:

```typescript
// ✅ 期待値を直接ハードコード（アルゴリズムとは独立した検証）
it.each([
  [1, 3, 4],     // 期待値を明示
  [11, 33, 44],
  [100, 500, 600],
])('adds %d and %d to get %d', (value1, value2, expected) => {
  const actual = add(value1, value2)
  expect(actual).toBe(expected)
})
```

> **原則**: テスト対象のコードとは異なる方法で取得した期待値と実行結果を比較することが、意味のある単体テストとなる。

---

## 4. プロダクションコードへの汚染

**問題**: テストでのみ必要なコード（`if (isTestMode)` 等の切り替えフラグ）をプロダクションコードに混入させること。

**原因**: テスト中に外部依存（ログ出力・ネットワーク等）を無効化する手軽な方法として、フラグによる分岐を追加してしまうため。

**4本の柱との関係**:
- **保守のしやすさ↓**: テスト専用コードがプロダクションコードに混入し、コードが複雑になる
- **退行に対する保護↓**: テスト専用の切り替えフラグが本番環境で誤って呼び出されるリスクが生まれる

**対処**: テスト専用コードはプロダクションコードに含めない。インターフェースを導入し、本番実装とテスト用スタブ実装を分離する。

**コード例 (NG)**:

```typescript
// NG: テスト時の振る舞いを切り替えるフラグがプロダクションコードに混入
class Logger {
  constructor(private readonly isTestEnvironment: boolean) {}

  log(text: string): void {
    if (this.isTestEnvironment) return // テスト専用コードが混入！
    console.log(text)
  }
}

// テスト
it('some test', () => {
  const logger = new Logger(true) // テストフラグを渡す
  const sut = new Controller(logger)
  sut.someMethod()
})
```

**コード例 (OK)**:

```typescript
// ✅ インターフェースで分離し、テスト用実装はテストコードに閉じ込める

// プロダクションコード
interface ILogger {
  log(text: string): void
}

class Logger implements ILogger {
  log(text: string): void {
    console.log(text)
  }
}

class Controller {
  constructor(private readonly logger: ILogger) {}

  someMethod(): void {
    this.logger.log('someMethod is called')
  }
}

// テストコード（プロダクションコードを汚染しない）
class FakeLogger implements ILogger {
  readonly messages: string[] = []
  log(text: string): void {
    this.messages.push(text)
  }
}

it('some test', () => {
  const fakeLogger = new FakeLogger()
  const sut = new Controller(fakeLogger)
  sut.someMethod()
  expect(fakeLogger.messages).toContain('someMethod is called')
})
```

> **注意**: インターフェースの導入自体も「汚染」ではあるが、フラグによる分岐と比べて影響が限定的で、バグを含む実行コードを持たないため許容される。

---

## 5. 具象クラスに対するテストダブル

**問題**: インターフェースではなく具象クラスに対してモック/スタブを作成し、一部のメソッドだけを差し替えること。

**原因**: クラスが「データ取得（プロセス外依存）」と「ビジネスロジック計算」の両方を担っており、どちらか一方だけを差し替えたくなるため。

**4本の柱との関係**:
- **保守のしやすさ↓**: 具象クラスのスタブは `CallBase = true` などのハック的な設定が必要で複雑
- **退行に対する保護↓**: 単一責任原則（SRP）違反が根本原因であり、設計の問題が隠蔽される

**対処**: 具象クラスが持つ2つの責務を分離する。プロセス外依存を扱うクラスはインターフェースを実装し、ドメインロジックは純粋な計算クラスとして切り出す（Humble Object パターン）。

**コード例 (NG)**:

```typescript
// NG: データ取得とビジネスロジックが同一クラスに混在
class StatisticsCalculator {
  calculate(customerId: number): { totalWeight: number; totalCost: number } {
    const records = this.getDeliveries(customerId) // プロセス外依存
    const totalWeight = records.reduce((sum, r) => sum + r.weight, 0)
    const totalCost = records.reduce((sum, r) => sum + r.cost, 0)
    return { totalWeight, totalCost }
  }

  getDeliveries(customerId: number): DeliveryRecord[] {
    // 外部APIを呼び出す（プロセス外依存）
    return fetchFromExternalApi(customerId)
  }
}

// NG: 具象クラスを部分的にモック（アンチパターン）
it('customer with no deliveries', () => {
  const stub = vi.spyOn(StatisticsCalculator.prototype, 'getDeliveries')
    .mockReturnValue([])
  const sut = new CustomerController(new StatisticsCalculator())
  // ...
})
```

**コード例 (OK)**:

```typescript
// ✅ 責務を分離: プロセス外依存クラスとドメインロジッククラスに分割
interface IDeliveryGateway {
  getDeliveries(customerId: number): DeliveryRecord[]
}

class DeliveryGateway implements IDeliveryGateway {
  getDeliveries(customerId: number): DeliveryRecord[] {
    return fetchFromExternalApi(customerId) // プロセス外依存はここだけ
  }
}

class StatisticsCalculator {
  calculate(records: DeliveryRecord[]): { totalWeight: number; totalCost: number } {
    // 純粋な計算のみ（プロセス外依存なし）
    const totalWeight = records.reduce((sum, r) => sum + r.weight, 0)
    const totalCost = records.reduce((sum, r) => sum + r.cost, 0)
    return { totalWeight, totalCost }
  }
}

// ✅ インターフェースに対してスタブを作成
it('customer with no deliveries', () => {
  const gatewayStub: IDeliveryGateway = { getDeliveries: vi.fn().mockReturnValue([]) }
  const sut = new CustomerController(new StatisticsCalculator(), gatewayStub)

  const actual = sut.getStatistics(1)
  const expected = 'Total weight delivered: 0. Total cost: 0'
  expect(actual).toBe(expected)
})
```

---

## 6. 単体テストにおける現在日時の扱い

**問題**: `new Date()` や `Date.now()` をプロダクションコード内で直接呼び出すこと（環境コンテキストとして扱うこと）。

**原因**: 現在日時は「どこでも使える」グローバルな値のように思えるため、直接参照してしまうことが多い。

**4本の柱との関係**:
- **迅速なフィードバック↓**: テストケース間で共有される依存（静的状態）が持ち込まれ、テストが統合テスト化する
- **リファクタリングへの耐性↓**: テスト実行タイミングによって結果が変わる（フレイキーテスト）

**3つの方法と推奨度**:

| 方法 | 説明 | 推奨度 |
|------|------|--------|
| 環境コンテキスト（ambient context） | 静的変数に保持して参照 | ❌ アンチパターン |
| サービスとして注入 | `IDateTimeServer` インターフェースを DI | ✅ 推奨 |
| 値として注入 | `Date` 型の値をメソッド引数で渡す | ✅✅ 最推奨 |

**コード例 (NG)**:

```typescript
// NG: 現在日時を環境コンテキスト（静的グローバル）として扱う
let currentDateProvider: () => Date = () => new Date()

// テスト時に差し替え
// setCurrentDateProvider(() => new Date('2024-01-01'))

class InquiryService {
  approve(inquiryId: number): void {
    const inquiry = this.getById(inquiryId)
    inquiry.approve(currentDateProvider()) // グローバルな静的依存
    this.save(inquiry)
  }
}
```

**コード例 (OK - 値として注入)**:

```typescript
// ✅ 最推奨: 現在日時を値として引数に渡す
class Inquiry {
  private isApproved = false
  private timeApproved: Date | null = null

  approve(now: Date): void { // 日時を値として受け取る
    if (this.isApproved) return
    this.isApproved = true
    this.timeApproved = now
  }
}

// テストが簡潔になる
it('approve sets approval time', () => {
  const inquiry = new Inquiry()
  const fixedDate = new Date('2024-01-15')

  inquiry.approve(fixedDate)

  const actual = inquiry.timeApproved
  const expected = fixedDate
  expect(actual).toEqual(expected)
})
```

**コード例 (OK - サービスとして注入)**:

```typescript
// ✅ DIフレームワークを使う場合: サービスとして注入
interface IDateTimeServer {
  readonly now: Date
}

class DateTimeServer implements IDateTimeServer {
  get now(): Date { return new Date() }
}

class InquiryController {
  constructor(private readonly dateTimeServer: IDateTimeServer) {}

  approveInquiry(id: number): void {
    const inquiry = this.getById(id)
    inquiry.approve(this.dateTimeServer.now) // サービスから値を取得して渡す
    this.save(inquiry)
  }
}

// テスト用スタブ
class FixedDateTimeServer implements IDateTimeServer {
  constructor(readonly now: Date) {}
}

it('approves inquiry with correct timestamp', () => {
  const fixedDate = new Date('2024-01-15')
  const sut = new InquiryController(new FixedDateTimeServer(fixedDate))
  sut.approveInquiry(1)
  // ...
})
```

> **原則**: 現在日時は明示的に依存として注入する。可能な限り値として注入し、DIフレームワークが必要な場合はサービスとして注入する。

---

## まとめ: アンチパターンと4本の柱

| アンチパターン | 主に損なわれる柱 | 根本原因 |
|--------------|----------------|---------|
| プライベートメソッドのテスト | リファクタリング耐性↓ | 抽象化の欠落 |
| プライベートな状態の公開 | リファクタリング耐性↓ | 観察可能な振る舞いとの混同 |
| ドメイン知識の漏洩 | リファクタリング耐性↓ | 期待値の再計算 |
| プロダクションコードへの汚染 | 保守のしやすさ↓ | テスト専用コードの混入 |
| 具象クラスへのテストダブル | 保守のしやすさ↓ | SRP違反 |
| 現在日時の直接参照 | 迅速なフィードバック↓ | 暗黙的な依存 |
