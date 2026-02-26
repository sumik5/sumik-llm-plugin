# 開発者テスト技法リファレンス

開発者が実装中に適用すべきテスト手法（境界値テスト・状態遷移テスト・カバレッジ）を中心に、
上流品質向上のための実践ガイドをまとめる。

## 📋 目次

- [境界値テスト](#境界値テスト)
- [状態遷移テスト](#状態遷移テスト)
- [コードカバレッジ](#コードカバレッジ)
- [テスト設計技法](#テスト設計技法)
- [上流品質とShift Left](#上流品質とshift-left)
- [複雑度を下げるリファクタリング](#複雑度を下げるリファクタリング)

---

## 境界値テスト

**最も重要なテスト手法。** 境界値付近に潜むバグは全バグの大部分を占める。

### 境界値バグの4タイプ

要求仕様：「1ページ以上の印刷のみ受け付ける」

**正しい実装:**
```typescript
if (pages >= 1) {
  // 印刷処理
} else {
  // エラー処理
}
```

**タイプ1: 閉包関係バグ（`>` vs `>=` の間違い）**
```typescript
// ❌ バグ: pages=1 の時にエラーになる
if (pages > 1) { ... }
```
テストケース: `pages = 1` → 印刷されるべき

**タイプ2: 数字の書き間違い**
```typescript
// ❌ バグ: pages=1 の時にエラーになる
if (pages >= 2) { ... }
```
テストケース: `pages = 1` → 印刷されるべき

**タイプ3: 境界がない（エラー処理の実装漏れ）**
```typescript
// ❌ バグ: 0以下でもエラーが出ない
if (pages >= 1) {
  // 印刷処理
}
// else句がない
```
テストケース: `pages = 0` → エラーになるべき

**タイプ4: 余分な境界（上限の作り込み）**
```typescript
// ❌ バグ: pages=10 以上で印刷できない
if (pages >= 1 && pages < 10) { ... }
```
テストケース: `pages = 10` → 印刷されるべき

### 境界値テストのテストケース設計

範囲 `1 ≤ input ≤ 999` の場合:

| テストケース | 入力値 | 期待結果 |
|------------|--------|---------|
| 最小境界値（有効）| 1 | 正常処理 |
| 最小境界値-1（無効）| 0 | エラー |
| 最大境界値（有効）| 999 | 正常処理 |
| 最大境界値+1（無効）| 1000 | エラー |
| 中間値（有効）| 500 | 正常処理 |

```typescript
// 境界値テストの実装例（Vitest）
import { describe, it, expect } from 'vitest'
import { validatePageCount } from './printer'

describe('validatePageCount', () => {
  it('最小有効値1を受け付けるべき', () => {
    const actual = validatePageCount(1)
    expect(actual).toBe(true)
  })

  it('最小値未満の0を拒否するべき', () => {
    const actual = validatePageCount(0)
    expect(actual).toBe(false)
  })

  it('最大有効値999を受け付けるべき', () => {
    const actual = validatePageCount(999)
    expect(actual).toBe(true)
  })

  it('最大値超過の1000を拒否するべき', () => {
    const actual = validatePageCount(1000)
    expect(actual).toBe(false)
  })
})
```

---

## 状態遷移テスト

アプリケーションの「状態」と「遷移」をモデル化してテストする手法。UIやワークフロー系のバグ検出に有効。

### 状態遷移の基本概念

- **状態（State）**: システムが取り得る状況（例: 未ログイン、ログイン済み、管理者モード）
- **遷移（Transition）**: 状態を変化させるイベント（例: ログインボタン押下）
- **NA（Not Applicable）**: 設計上発生しない遷移（これが発生するとバグ）

### 状態遷移マトリックスの作成

例: メモ帳アプリの状態遷移

| 状態 \ イベント | 新規作成 | ファイルを開く | ダイアログ表示 | 文字入力 | 保存 |
|--------------|--------|-------------|------------|--------|------|
| **初期状態** | → 編集中 | → ダイアログ | NA | NA | NA |
| **編集中** | → 編集中 | → ダイアログ | NA | → 編集中 | → 保存済 |
| **ダイアログ表示中** | NA | NA | NA | NA (バグ候補) | NA |
| **保存済** | → 編集中 | → ダイアログ | NA | → 編集中 | NA |

### 状態遷移テストの実装

```typescript
describe('DocumentEditor - 状態遷移', () => {
  it('初期状態でダイアログを開ける', () => {
    const editor = new DocumentEditor()

    editor.openFile()

    expect(editor.state).toBe('DIALOG_OPEN')
  })

  it('ダイアログ表示中は文字入力できない', () => {
    const editor = new DocumentEditor()
    editor.openFile() // ダイアログを開く

    // ダイアログ表示中に文字入力しようとするとエラー
    expect(() => editor.typeText('hello')).toThrow('Cannot type while dialog is open')
  })

  it('ファイルを開いた後は編集できる', () => {
    const editor = new DocumentEditor()
    editor.openFile()
    editor.selectFile('/path/to/file.txt')

    editor.typeText('hello')

    expect(editor.content).toContain('hello')
    expect(editor.state).toBe('EDITING')
  })
})
```

---

## コードカバレッジ

### 命令網羅（C0カバレッジ）

**定義**: すべての命令文を少なくとも1回実行する

```typescript
function processOrder(order: Order): string {
  if (order.isPriority) {
    return 'EXPRESS'     // ← C0でカバー済み
  }
  return 'STANDARD'     // ← C0でカバー済み
}
```

**限界**: 条件の真偽両方をテストしない → 境界値バグを見逃す

### 分岐網羅（C1カバレッジ）

**定義**: すべての分岐（真/偽）を少なくとも1回通過する

```typescript
function processOrder(order: Order): string {
  if (order.isPriority) {      // TRUE分岐 → テスト必要
    return 'EXPRESS'
  }
  return 'STANDARD'            // FALSE分岐 → テスト必要
}
```

**C1テストの例:**
```typescript
describe('processOrder', () => {
  it('優先注文の時、EXPRESSを返すべき', () => {
    const order = { isPriority: true, items: [] }
    expect(processOrder(order)).toBe('EXPRESS')  // TRUE分岐
  })

  it('通常注文の時、STANDARDを返すべき', () => {
    const order = { isPriority: false, items: [] }
    expect(processOrder(order)).toBe('STANDARD')  // FALSE分岐
  })
})
```

### カバレッジ目標の実践

```
ビジネスロジック: 100%（C1以上推奨）
ユーティリティ関数: 100%
コントローラー: 80%以上（C0）
UIコンポーネント: 70%以上（C0）
```

> **注意**: C0カバレッジ100%は必要条件であって十分条件ではない。
> 境界値テストが含まれていなければ意味のないカバレッジになる。

---

## テスト設計技法

### 同値分割

無効な値と有効な値のグループ（同値クラス）を特定し、各グループから代表値を1つ選ぶ。

```
入力: 1〜100の整数
同値クラス:
  - 有効: 1〜100（代表: 50）
  - 無効（下限未満）: 0以下（代表: -1）
  - 無効（上限超過）: 101以上（代表: 200）
```

### デシジョンテーブル

複数の条件の組み合わせを網羅的に列挙する。

| 条件 | ルール1 | ルール2 | ルール3 | ルール4 |
|------|--------|--------|--------|--------|
| 会員か | Yes | Yes | No | No |
| クーポンあり | Yes | No | Yes | No |
| **結果: 割引適用** | 30% | 10% | 15% | 0% |

```typescript
describe('calculateDiscount - デシジョンテーブル', () => {
  it('会員 + クーポンあり → 30%割引', () => {
    const actual = calculateDiscount({ isMember: true, hasCoupon: true })
    expect(actual).toBe(0.3)
  })

  it('会員 + クーポンなし → 10%割引', () => {
    const actual = calculateDiscount({ isMember: true, hasCoupon: false })
    expect(actual).toBe(0.1)
  })

  it('非会員 + クーポンあり → 15%割引', () => {
    const actual = calculateDiscount({ isMember: false, hasCoupon: true })
    expect(actual).toBe(0.15)
  })

  it('非会員 + クーポンなし → 割引なし', () => {
    const actual = calculateDiscount({ isMember: false, hasCoupon: false })
    expect(actual).toBe(0)
  })
})
```

### ブラックボックス vs ホワイトボックス

| 観点 | ブラックボックステスト | ホワイトボックステスト |
|------|-------------------|-------------------|
| 対象 | 入出力の振る舞い | 内部実装・コード |
| 知識 | 仕様書のみ | ソースコードを参照 |
| 手法 | 同値分割・境界値 | C0/C1カバレッジ |
| 用途 | 機能テスト・受入テスト | 単体テスト |

---

## 上流品質とShift Left

### コスト増加の法則

バグを発見するコストは工程が進むほど指数的に増加する:

```
要件定義でのバグ修正コスト: 1倍
設計フェーズでの修正: 5倍
実装中の修正: 10倍
システムテストでの修正: 50倍
リリース後の修正: 100倍以上
```

**結論**: 上流でバグを潰すほど、プロジェクト全体のコストは大幅に削減される。

### Shift Leftの実践ポイント

| 活動 | 効果 |
|------|------|
| TDDの実践 | 実装中にバグを即発見 |
| コードレビュー | 実装直後に問題を発見 |
| 単体テストの自動化 | リグレッション防止 |
| 境界値テストの徹底 | 80%以上のバグを上流で摘出 |

---

## 複雑度を下げるリファクタリング

複雑度（サイクロマティック複雑度）が高いコードは単体テストが困難になる。

### 複雑度の計算

```
サイクロマティック複雑度 = 分岐数 + 1
```

```typescript
// 複雑度 = 4（if×3 + 1）- テストが困難
function calculate(a: number, b: number, op: string): number {
  if (op === 'add') {
    return a + b
  } else if (op === 'sub') {
    return a - b
  } else if (op === 'mul') {
    return a * b
  }
  throw new Error('Unknown op')
}
```

### リファクタリング後（複雑度を下げる）

```typescript
// Strategy パターンで複雑度を下げる
const operations: Record<string, (a: number, b: number) => number> = {
  add: (a, b) => a + b,
  sub: (a, b) => a - b,
  mul: (a, b) => a * b,
}

// 複雑度 = 2（if×1 + 1）- テストが容易
function calculate(a: number, b: number, op: string): number {
  const operation = operations[op]
  if (!operation) throw new Error(`Unknown op: ${op}`)
  return operation(a, b)
}
```

### MVC分離でテスト容易性を高める

```typescript
// ❌ 悪い例: ViewとロジックがView内に混在
function OrderView(order: Order): HTMLElement {
  const total = order.items.reduce((sum, item) => sum + item.price * item.qty, 0)
  const tax = total * 0.1
  const grandTotal = total + tax
  // DOM操作...
}

// ✅ 良い例: ロジックを分離して単体テスト可能に
function calculateOrderTotal(order: Order): { total: number; tax: number; grandTotal: number } {
  const total = order.items.reduce((sum, item) => sum + item.price * item.qty, 0)
  const tax = total * 0.1
  return { total, tax, grandTotal: total + tax }
}

// ビジネスロジックの単体テストが簡単に書ける
it('税込み合計を計算するべき', () => {
  const order = { items: [{ price: 1000, qty: 2 }] }
  const actual = calculateOrderTotal(order)
  expect(actual.grandTotal).toBe(2200)
})
```

---

## 🔗 関連ファイル

- **[INSTRUCTIONS.md](../INSTRUCTIONS.md)** - スキル概要
- **[TDD.md](./TDD.md)** - TDDサイクル詳細
- **[TESTABLE-DESIGN.md](./TESTABLE-DESIGN.md)** - テスタブルな設計
- **[TEST-MANAGEMENT.md](./TEST-MANAGEMENT.md)** - テスト工程・品質管理
