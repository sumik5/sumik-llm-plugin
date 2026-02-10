---
name: testing-code
description: REQUIRED for all feature implementations. Automatically load when writing or reviewing tests. Enforces TDD approach with AAA pattern, actual/expected variables, and 100% coverage goal for business logic. Covers Vitest, React Testing Library, Jest, and Playwright.
---

# テストファーストアプローチ

## 📑 目次

このスキルは以下のファイルで構成されています：

- **SKILL.md** (このファイル): 概要と使用タイミング
- **[VITEST-RTL-GUIDELINES.md](./references/VITEST-RTL-GUIDELINES.md)**: Vitest / React Testing Library コード規約 ⭐NEW
- **[TDD.md](./references/TDD.md)**: TDDサイクルと実装パターン
- **[TEST-TYPES.md](./references/TEST-TYPES.md)**: テストピラミッド（単体、統合、E2E）
- **[TESTABLE-DESIGN.md](./references/TESTABLE-DESIGN.md)**: テスタブルな設計原則
- **[REFERENCE.md](./references/REFERENCE.md)**: ベストプラクティス、カバレッジ、チェックリスト
- **[AI-REVIEW-GUIDELINES.md](./references/AI-REVIEW-GUIDELINES.md)**: AIテストコードレビュー観点

## 🎯 使用タイミング

- **新機能実装時（実装前にテスト作成）**
- **バグ修正時（再現テスト作成）**
- **リファクタリング時（回帰テスト実行）**
- **コードレビュー時（テストカバレッジ確認）**

## 📋 基本原則

### テストファースト開発

実装の前にテストを書く「TDD（Test-Driven Development）」を推奨します。

**基本サイクル:**
```
1. Red（失敗するテストを書く）
   ↓
2. Green（最小限のコードで通す）
   ↓
3. Refactor（リファクタリング）
   ↓
繰り返し
```

詳細は [TDD.md](./references/TDD.md) を参照してください。

### テストピラミッド

```
        /\
       /  \      E2E（少数）
      /____\     統合テスト（中程度）
     /______\    単体テスト（多数）
```

**原則:**
- 単体テストを最も多く作成
- 統合テストは適度に
- E2Eテストは最小限に

詳細は [TEST-TYPES.md](./references/TEST-TYPES.md) を参照してください。

### AAAパターン（必須）

すべてのテストは **Arrange-Act-Assert** パターンに従い、**actual / expected 変数**で比較します：

```typescript
it('有効なデータの時、ユーザーを作成すべき', () => {
  // Arrange（準備）
  const userData = { name: 'John', email: 'john@example.com' }

  // Act（実行）
  const actual = userService.createUser(userData)

  // Assert（検証）
  const expected = { name: 'John', email: 'john@example.com' }
  expect(actual).toEqual(expect.objectContaining(expected))
})
```

### Vitest / RTL 必須規約

**詳細は [VITEST-RTL-GUIDELINES.md](./references/VITEST-RTL-GUIDELINES.md) を参照。**

| 規約 | 説明 |
|------|------|
| **明示的インポート** | `import { describe, it, expect } from 'vitest'` を必ず記述 |
| **日本語テスト名** | 「〜の時、〜すべき」形式で条件と結果を明示 |
| **ネスト禁止** | `describe` のネストは禁止。フラットな構造を維持 |
| **actual/expected** | AAA パターンで `actual` と `expected` 変数を使用 |
| **1テスト1検証** | オブジェクト比較で複数プロパティを1回で検証可 |
| **スナップショット制限** | セマンティックHTMLとa11y属性の検証のみに使用 |

## 🎯 カバレッジ目標

### 推奨カバレッジ基準

```
- ビジネスロジック: 100%
- ユーティリティ関数: 100%
- コントローラー: 80%以上
- UI コンポーネント: 70%以上
```

詳細は [REFERENCE.md](./references/REFERENCE.md) を参照してください。

## 🎨 テスタブルな設計

テストしやすいコードを書くための設計原則：

**1. 依存性注入（DI）**
- コンストラクタでの依存注入
- モック可能な設計

**2. 純粋関数**
- 副作用のない関数
- 同じ入力に対して同じ出力

**3. インターフェース抽象化**
- 具象クラスではなくインターフェースに依存
- テスト用モックの作成が容易

詳細は [TESTABLE-DESIGN.md](./references/TESTABLE-DESIGN.md) を参照してください。

## 🤖 AI生成コードの注意点

AIが生成したテストコードは網羅的ですが、以下の観点でレビューが必要です：

### 主要な注意点

1. **テストケースの肥大化**: 分岐網羅・境界値を全部入りで生成 → 責務分離・優先度付けで絞り込む
2. **マジックナンバー/ストリング**: Enum/定数を無視して直書き → リファクタリング時の修正漏れの原因
3. **Fixture未使用**: 各テストでダミーデータ重複生成 → ファクトリー関数で共通化
4. **責務混在**: テスト対象外のケース（バリデーション等）まで含む → レイヤー分離
5. **重複テスト**: 同じ仕様を複数レイヤーでテスト → レイヤー間の重複排除

**詳細は [AI-REVIEW-GUIDELINES.md](./references/AI-REVIEW-GUIDELINES.md) を参照してください。**

---

## 📊 クイックスタート

### 新機能実装時の基本フロー

```
1. テストを先に書く（Red）
   ↓
2. 最小限の実装（Green）
   ↓
3. リファクタリング（Refactor）
   ↓
4. カバレッジ確認
   ↓
5. 完了
```

### バグ修正時の基本フロー

```
1. バグを再現するテストを書く
   ↓
2. テストが失敗することを確認
   ↓
3. バグを修正
   ↓
4. テストが成功することを確認
   ↓
5. 完了
```

## 🚀 実践例

### TypeScript + Vitest

```typescript
import { describe, it, expect } from 'vitest'

describe('calculateTotal', () => {
  it('割引率が指定された時、割引後の合計を返すべき', () => {
    // Arrange
    const items = [100, 200]
    const discountRate = 0.1

    // Act
    const actual = calculateTotal(items, discountRate)

    // Assert
    const expected = 270 // (100 + 200) * 0.9
    expect(actual).toBe(expected)
  })
})

// 実装
function calculateTotal(items: number[], discount: number): number {
  const subtotal = items.reduce((sum, item) => sum + item, 0)
  return subtotal * (1 - discount)
}
```

### E2Eテスト（Playwright）

```typescript
import { test, expect } from '@playwright/test'

test('新規登録フォーム送信時、成功メッセージが表示されるべき', async ({ page }) => {
  // Arrange
  await page.goto('/register')

  // Act
  await page.fill('#email', 'john@example.com')
  await page.click('button[type="submit"]')

  // Assert
  await expect(page.locator('.success')).toBeVisible()
})
```

## 📋 最小限のチェックリスト

実装完了前に確認：
- [ ] vitest から明示的にインポートしているか
- [ ] テスト名は「〜の時、〜すべき」形式か
- [ ] AAA パターンで actual / expected を使用しているか
- [ ] describe がネストしていないか
- [ ] カバレッジ目標を達成しているか
- [ ] テストは独立しているか（順序依存なし）

完全なチェックリストは [REFERENCE.md](./references/REFERENCE.md) を参照してください。

## ユーザー確認の原則（AskUserQuestion）

**判断分岐がある場合、推測で進めず必ずAskUserQuestionツールでユーザーに確認する。**

### 確認すべき場面

| 確認項目 | 例 |
|---|---|
| テストフレームワーク | Vitest, Jest, pytest, Go testing |
| テスト種別の比率 | ユニット重視, E2E重視, バランス型 |
| カバレッジ目標 | 80%, 90%, 100%（ビジネスロジック） |
| モック戦略 | MSW, vi.mock, 手動モック |
| E2Eツール | Playwright, Cypress |
| テスト環境 | jsdom, happy-dom, node |

### 確認不要な場面

- AAAパターンの使用（必須）
- actual/expected変数の明示（必須）
- 日本語テスト名の使用（必須）
- ネストしたdescribeの禁止（必須）

## 🔗 関連スキル

- **writing-clean-code** - SOLID原則・テスタブルな設計原則
- **enforcing-type-safety** - 型安全なテストコード
- **mcp-browser-auto** - E2Eテスト実装
- **implementing-as-tachikoma** - Developer Agent実装ガイド
