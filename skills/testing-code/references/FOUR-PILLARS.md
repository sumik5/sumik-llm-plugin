# 良い単体テストの4本の柱

> 出典: Vladimir Khorikov 著「単体テストの考え方/使い方」(Unit Testing: Principles, Practices, and Patterns)
> 第2章・第4章・第5章より

---

## 目次

- [4本の柱の定義と相互関係](#4本の柱の定義と相互関係)
- [テストの正確性: 偽陽性と偽陰性](#テストの正確性-偽陽性と偽陰性)
- [3本の柱の排反性と理想的テストの探求](#3本の柱の排反性と理想的テストの探求)
- [観察可能な振る舞い vs 実装の詳細](#観察可能な振る舞い-vs-実装の詳細)
- [テストピラミッドと4本の柱](#テストピラミッドと4本の柱)
- [古典学派 vs ロンドン学派](#古典学派-vs-ロンドン学派)

---

## 4本の柱の定義と相互関係

良い単体テストを構成する4本の柱:

| 柱 | 意味 | 0になる条件 |
|---|---|---|
| **退行（regression）に対する保護** | バグを検出できる能力 | 取るに足らないコードしかテストしない |
| **リファクタリングへの耐性** | 偽陽性を起こさない性質 | 実装の詳細に結びついている |
| **迅速なフィードバック** | テスト実行速度の短さ | E2Eテストのみで構成する |
| **保守のしやすさ** | テストの理解・実行の容易さ | テストが巨大・複雑またはプロセス外依存だらけ |

### 掛け算モデル（最重要）

```
テスト・ケースの価値 = 退行保護[0..1] × リファクタリング耐性[0..1] × 迅速FB[0..1] × 保守性[0..1]
```

**4本のうち1本でも0になると、テストの価値全体が0になる。**

```typescript
// ❌ 取るに足らないテスト: 退行保護 = 0 → 価値 = 0
it('should set name', () => {
  const user = new User()
  user.name = 'Alice'
  expect(user.name).toBe('Alice') // バグが入り込む余地がない
})

// ❌ 壊れやすいテスト: リファクタリング耐性 = 0 → 価値 = 0
it('should use correct sub-renderers', () => {
  const renderer = new MessageRenderer()
  // 内部の構成を確認している = 実装の詳細と結びついている
  expect(renderer.subRenderers[0]).toBeInstanceOf(HeaderRenderer)
  expect(renderer.subRenderers[1]).toBeInstanceOf(BodyRenderer)
})

// ✅ 観察可能な振る舞いを検証: 4本すべてにある程度の値がある
it('should render message as HTML', () => {
  const renderer = new MessageRenderer()
  const actual = renderer.render({ header: 'h', body: 'b', footer: 'f' })
  const expected = '<h1>h</h1><b>b</b><i>f</i>'
  expect(actual).toBe(expected)
})
```

### 各柱の評価基準

**退行に対する保護を高めるには:**
- テスト時に実行されるプロダクション・コードの量を増やす
- 複雑なビジネスロジック・ドメインロジックを重点的にテストする
- アプリケーションが使うライブラリやフレームワークも対象に含める

**リファクタリングへの耐性を高めるには:**
- 検証対象を「最終的な結果（観察可能な振る舞い）」にする
- 実装の手順（how）ではなく、結果（what）に目を向ける
- テスト対象のクライアントの視点で確認する

**保守のしやすさの2観点:**
1. テスト・ケースを理解するコストが低いか（コード量・複雑さ）
2. テストを実行するコストが低いか（プロセス外依存の有無・環境準備）

---

## テストの正確性: 偽陽性と偽陰性

### 4区分マトリクス

|  | 実際の振る舞いが正しい | 実際の振る舞いが間違い |
|---|---|---|
| **テスト成功** | ✅ 真陰性（正しい） | ❌ 偽陰性（見落とし） |
| **テスト失敗** | ❌ 偽陽性（嘘の警告） | ✅ 真陽性（正しい） |

```
テストの正確性 = 信号（検出されたバグの数）/ ノイズ（嘘の警告が発せられた数）
```

### 偽陰性（false negative）= 第二種過誤

- テストが成功しているのに、実際にはバグがある状態
- **退行に対する保護**が不足していると発生する
- 例: 取るに足らないコードしかテストしない、実行範囲が狭い

### 偽陽性（false positive）= 第一種過誤

- テストが失敗しているのに、コードは正しく動作している状態
- **リファクタリングへの耐性**が不足していると発生する
- 例: 内部実装と結びついたテストはリファクタリングで壊れる

### 偽陽性がプロジェクト成長とともに深刻化する理由

**初期段階**では偽陽性は許容できる:
- コードベースが小さくリファクタリングの必要性が低い
- コードを書いた記憶が新しく、問題を特定しやすい

**プロジェクト成長後**に偽陽性が致命的になる:
1. 嘘の警告が続くと開発者はテスト結果を無視するようになる
2. 「本当の失敗」も嘘の警告として無視されるようになる
3. バグが本番に持ち込まれる
4. リファクタリングへの意欲が失われコードベースが劣化する

> **実際にあった出来事（書籍より）:** あるプロジェクトで偽陽性が頻発し、開発者がテスト失敗を無視するようになった結果、本当のバグを見落として本番環境に持ち込まれた。

### 偽陽性を引き起こす根本原因

```typescript
// ❌ 実装の詳細に結びついたテスト（偽陽性を生む）
it('should use HeaderRenderer, BodyRenderer, FooterRenderer', () => {
  const sut = new MessageRenderer()
  // SubRenderersの内部構成を確認している
  expect(sut.subRenderers).toHaveLength(3)
  expect(sut.subRenderers[0]).toBeInstanceOf(HeaderRenderer)
})
// → BodyRendererをBoldRendererにリファクタリングしただけで失敗する

// ✅ 観察可能な振る舞いを検証（偽陽性が起きない）
it('should render message correctly', () => {
  const sut = new MessageRenderer()
  const actual = sut.render({ header: 'h', body: 'b', footer: 'f' })
  const expected = '<h1>h</h1><b>b</b><i>f</i>'
  expect(actual).toBe(expected)
})
// → 内部実装がどう変わっても、同じHTMLが出れば成功する
```

---

## 3本の柱の排反性と理想的テストの探求

### 排反する3本の柱

退行に対する保護・リファクタリングへの耐性・迅速なフィードバックは**同時に最大化できない**。

> CAP定理（分散DBにおいて一貫性・可用性・分断耐性の3つを同時に保証できない）と同じ構造。

```
         リファクタリングへの耐性
                ▲
                │ 常に最大化
                │
  退行に対する保護 ←→ 迅速なフィードバック
         (このバランスを調整する)
```

### 3つの極端な例

| テスト種別 | 退行保護 | リファクタリング耐性 | 迅速FB | 保守性 | 価値 |
|---|---|---|---|---|---|
| **E2Eテスト** | ◎ | ◎ | ✗ | △ | 保守コスト高 |
| **取るに足らないテスト** | ✗ | ◎ | ◎ | ◎ | 0（バグ検出なし） |
| **壊れやすいテスト** | ◎ | ✗ | ◎ | △ | 0（偽陽性多発） |

**E2Eテスト（迅速FBが犠牲）:**
```typescript
// 退行保護は最高レベル（全コードが実行される）
// リファクタリング耐性も高い（エンドユーザー視点のみ）
// しかし実行が遅く、フィードバックループが長い
test('complete purchase flow', async ({ page }) => {
  await page.goto('/products')
  await page.click('[data-product="shampoo"]')
  await page.goto('/cart')
  await page.click('button:has-text("Checkout")')
  await expect(page.locator('.success')).toBeVisible()
})
```

**壊れやすいテスト（リファクタリング耐性が犠牲）:**
```typescript
// 実行が速く退行も検出できる
// しかし実装の詳細に依存しているため、リファクタリングで即壊れる
it('should call validate then save in that order', () => {
  const mockValidator = { validate: vi.fn().mockReturnValue(true) }
  const mockDb = { save: vi.fn() }
  // ❌ 内部の呼び出し順序を検証 → リファクタリングで即失敗
  expect(mockValidator.validate).toHaveBeenCalledBefore(mockDb.save)
})
```

### 現実的な戦略

**リファクタリングへの耐性は犠牲にできない。** 理由:
- リファクタリングへの耐性は「0か1か」の二択になりやすい（部分的に持てない）
- 偽陽性が続くとテストスイート全体の信頼が失われる

**したがって実際の選択は:**

```
退行に対する保護  ←[スライダー]→  迅速なフィードバック
```

これが単体テスト・統合テスト・E2Eテストの棲み分けの本質。

---

## 観察可能な振る舞い vs 実装の詳細

### 定義

コードが**観察可能な振る舞い**の一部となるには:
1. クライアントが**目標を達成するために使う公開された操作**（計算・副作用を起こすメソッド）
2. クライアントが**目標を達成するために使う公開された状態**

これらに該当しないコードが**実装の詳細**。

### 実装の詳細の漏洩例

```typescript
// ❌ 実装の詳細が漏洩しているクラス
class User {
  name: string

  // これはクライアントの目標（名前変更）に直接関係しない = 実装の詳細
  normalizeName(name: string): string {
    return (name ?? '').trim().substring(0, 50)
  }
}

// クライアントが2つの操作を呼ばなければならない = 実装の詳細が漏洩している
class UserController {
  renameUser(userId: string, newName: string) {
    const user = this.db.getUser(userId)
    const normalizedName = user.normalizeName(newName) // ← これが漏洩
    user.name = normalizedName
    this.db.save(user)
  }
}
```

```typescript
// ✅ きちんと設計されたAPI（実装の詳細を隠蔽）
class User {
  private _name: string = ''

  get name(): string { return this._name }

  set name(value: string) {
    // NormalizeNameはプライベートに隠蔽
    this._name = this.normalizeName(value)
  }

  private normalizeName(name: string): string {
    return (name ?? '').trim().substring(0, 50)
  }
}

// クライアントは1つの操作で目標を達成できる
class UserController {
  renameUser(userId: string, newName: string) {
    const user = this.db.getUser(userId)
    user.name = newName // ← これだけ
    this.db.save(user)
  }
}
```

### 漏洩を検知する方法

**クライアントが1つの目標を達成するのに何回操作を呼んでいるか？**

- 1回で済む → きちんと設計されている
- 2回以上 → 実装の詳細が漏洩している可能性が高い

### カプセル化との関係

実装の詳細の漏洩はカプセル化の崩壊と深く関係する:

```
実装の詳細が漏洩 → 不変条件をクライアント側で守る責任が発生
                 → クライアントがルールを破れる状態になる
                 → データ整合性が壊れる
```

| API設計 | 観察可能な振る舞い | 実装の詳細 |
|---|---|---|
| **公開すべき** | ✅ 公開する | ❌ 公開しない |
| **プライベートにすべき** | 該当なし | ✅ 隠す |

> **TIP:** APIをきちんと設計すれば、単体テストは自然と質の良いものになる。
> すべての実装の詳細をプライベートにすることで、観察可能な振る舞いしか検証できない状態が生まれ、リファクタリングへの耐性が自動的に備わる。

---

## テストピラミッドと4本の柱

TEST-TYPES.mdでカバーする「ピラミッドの形状」ではなく、**4本の柱の視点でのピラミッドの意味**を説明する。

### 層ごとのトレードオフ

```
             E2Eテスト         退行保護↑ リファクタリング耐性↑ 迅速FB↓ 保守性↓
             ────────
             統合テスト         中間（バランス型）
             ────────
             単体テスト         迅速FB↑ 保守性↑ 退行保護（スコープ内）
```

**すべての層でリファクタリングへの耐性を常に最大化すること。**

```
         リファクタリング耐性
              ▲（全層で最大化）
              │
  退行保護 ←────→ 迅速FB
  E2E↑多   ────    単体↑多
```

### なぜE2Eテストのケースを少なくするのか

テスト価値の計算式に当てはめると:

```
E2Eテストの価値 = 退行保護[高] × リファクタリング耐性[高] × 迅速FB[極低] × 保守性[低]
               ≈ 0に近い（迅速FBと保守性が著しく低い）
```

E2Eテストが意味を持つのは: 単体テストや統合テストでは同等の退行保護を得られない、クリティカルなユーザーフローに限定する。

### ブラックボックス vs ホワイトボックステスト

| | ブラックボックス | ホワイトボックス |
|---|---|---|
| **検証対象** | 観察可能な振る舞い（最終結果） | 内部実装の詳細（手順） |
| **リファクタリング耐性** | ◎ | ✗ |
| **退行保護** | 適切な範囲 | 高いが偽陽性多発 |
| **推奨** | ✅ 基本はこちら | ⚠️ カバレッジ確認程度 |

> **指針:** テストはブラックボックス（観察可能な振る舞い）で書き、ホワイトボックス（カバレッジ計測）で確認する。

---

## 古典学派 vs ロンドン学派

> MOCK-PATTERNS.mdのテストダブル用語整理（モック・スタブ・スパイ等）とは異なり、ここでは**学派間の哲学的な対立**の文脈で整理する。

### 根本的な対立点: 「隔離」の定義

| | 古典学派（デトロイト学派） | ロンドン学派（モック主義者） |
|---|---|---|
| **隔離の対象** | テスト・ケース同士 | テスト対象システムとその協力者 |
| **単体の意味** | 1単位の振る舞い（複数クラス可） | 1つのクラス |
| **テスト・ダブルの使用対象** | 共有依存のみ | 不変依存を除くすべての依存 |
| **バイブル** | Kent Beck「TDD by Example」 | Freeman/Pryce「GOOS」 |

### 依存の分類と各学派の扱い

```
依存
├── 共有依存（DB、ファイルシステム等）← 古典学派もテスト・ダブルに置き換える
└── プライベート依存
    ├── 可変依存（Storeクラス等）← ロンドン学派は置き換える。古典学派は置き換えない
    └── 不変依存（値オブジェクト、リテラル等）← 両学派とも置き換えない
```

### コード例で比較

```typescript
// 古典学派: 協力者オブジェクトをそのまま使う
describe('Customer - 古典学派', () => {
  it('should succeed purchase when enough inventory', () => {
    // Arrange: 実際のStoreを使う
    const store = new Store()
    store.addInventory(Product.Shampoo, 10)
    const customer = new Customer()

    // Act
    const actual = customer.purchase(store, Product.Shampoo, 5)

    // Assert: Storeの状態で確認
    const expected = true
    expect(actual).toBe(expected)
    expect(store.getInventory(Product.Shampoo)).toBe(5)
  })
})

// ロンドン学派: すべての協力者オブジェクトをモックに置き換える
describe('Customer - ロンドン学派', () => {
  it('should succeed purchase when enough inventory', () => {
    // Arrange: Storeをモックに置き換える
    const storeMock = {
      hasEnoughInventory: vi.fn().mockReturnValue(true),
      removeInventory: vi.fn(),
    }
    const customer = new Customer()

    // Act
    const actual = customer.purchase(storeMock as Store, Product.Shampoo, 5)

    // Assert: モックとのやり取りで確認
    const expected = true
    expect(actual).toBe(expected)
    expect(storeMock.removeInventory).toHaveBeenCalledWith(Product.Shampoo, 5)
  })
})
```

### 各学派のメリットとデメリット

**ロンドン学派のメリット:**
- 細かい粒度でのバグ特定が可能（テスト失敗 = SUT内の問題と確定）
- 複雑な依存関係があっても個別テストが書きやすい
- 外側→内側への設計（TDD）がやりやすい

**ロンドン学派のデメリット（なぜ著者は古典学派を好むか）:**
- モックの過剰利用 → 実装の詳細との結びつき → **偽陽性が増える**
- モックはリファクタリングへの耐性を損なう傾向がある
- テストが「何を検証しているか」が不明確になりやすい

**古典学派のメリット:**
- 観察可能な振る舞いを自然に検証するようになる
- リファクタリングへの耐性が高い
- テストがより現実の振る舞いに近い

**古典学派のデメリット:**
- バグが複数のテストを同時に失敗させることがある（失敗の特定が広がる）
- 複雑な依存関係の設定が必要な場合がある

### 本書の結論

> 著者（Vladimir Khorikov）は**古典学派を推奨**する。
> 理由: ロンドン学派のモック多用は実装の詳細と結びつきやすく、リファクタリングへの耐性（4本の柱の中でもっとも重要な柱）を損なう。

---

## 関連ファイル

- **[SKILL.md](../SKILL.md)** - スキル概要
- **[TEST-TYPES.md](./TEST-TYPES.md)** - テストピラミッドの基本構造・各テスト種別の実装
- **[MOCK-PATTERNS.md](./MOCK-PATTERNS.md)** - テストダブルの用語整理・モック実装パターン
- **[TDD.md](./TDD.md)** - Red→Green→Refactorサイクル
- **[TESTABLE-DESIGN.md](./TESTABLE-DESIGN.md)** - テスタブルな設計パターン
