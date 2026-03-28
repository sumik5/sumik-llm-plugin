# 3つのテスト手法と関数型アーキテクチャ

> 出典: Vladimir Khorikov, *Unit Testing: Principles, Practices, and Patterns* (Manning, 2020)
> 須田智之 訳「単体テストの考え方/使い方」(マイナビ出版) — 第6章

---

## 1. 3つの手法の定義

| 手法 | 検証対象 | 特徴 |
|------|---------|------|
| **出力値ベース**（Output-based） | 戻り値のみ | 副作用なし。関数型テストとも呼ばれる |
| **状態ベース**（State-based） | テスト対象/協力者の状態変化 | 実行後のオブジェクト状態を検証 |
| **コミュニケーションベース**（Communication-based） | モックによるやり取り | 協力者を正しく呼び出したかを検証 |

1つのテストケースに1つだけ適用することも、複数を組み合わせることも可能。

### 出力値ベース

```typescript
// 副作用なし。戻り値のみを検証
class PriceEngine {
  calculateDiscount(products: Product[]): number {
    const discount = products.length * 0.01
    return Math.min(discount, 0.2)
  }
}

it('2つの商品で2%の割引率を返す', () => {
  const actual = new PriceEngine().calculateDiscount([
    new Product('Hand wash'),
    new Product('Shampoo'),
  ])
  const expected = 0.02
  expect(actual).toBe(expected)
})
```

### 状態ベース

```typescript
it('商品を追加するとOrderに追加される', () => {
  const product = new Product('Hand wash')
  const sut = new Order()

  sut.addProduct(product)

  // テスト対象システムの状態を検証
  expect(sut.products).toHaveLength(1)
  expect(sut.products[0]).toBe(product)
})
```

### コミュニケーションベース

```typescript
it('ユーザーに挨拶メールを送信する', () => {
  const emailGatewayMock = { sendGreetingsEmail: vi.fn() }
  const sut = new Controller(emailGatewayMock)

  sut.greetUser('user@email.com')

  // 協力者オブジェクトへの呼び出しを検証
  expect(emailGatewayMock.sendGreetingsEmail)
    .toHaveBeenCalledWith('user@email.com')
})
```

---

## 2. 4本の柱による比較

> 4本の柱の詳細定義は `FOUR-PILLARS.md` を参照

### 退行に対する保護 / 迅速なフィードバック

**3手法とも実質的な差はない**。テストコード量・コードの複雑さ・ドメインの重要性によって決まる。

### リファクタリングへの耐性 / 保守のしやすさ

|  | 出力値ベース | 状態ベース | コミュニケーションベース |
|--|:-----------:|:----------:|:------------------------:|
| **リファクタリング耐性** コスト | 低い | 普通 | 普通 |
| **保守のしやすさ** コスト | 低い | 普通 | **高い** |

- **出力値ベース**: 実装詳細との結びつきが最小。コード量が少なく簡潔
- **状態ベース**: 状態検証により多くのAPIと結びつく。コード量が増える
- **コミュニケーションベース**: テストダブルのセットアップが必要。モックの連鎖でさらに複雑化

**結論**: 出力値ベーステストが最も費用対効果が高い。できる限り増やすことを目指す。

---

## 3. 関数型アーキテクチャ

### 3.1 なぜ必要か

出力値ベーステストを適用するには、プロダクションコードが**数学的関数（純粋関数）**として実装されている必要がある。

> 純粋関数の基本定義は `TESTABLE-DESIGN.md` 参照。隠れた入力（DBアクセス・`Date.now()`・プライベートフィールド参照）や隠れた出力（副作用・例外）がないこと。

### 3.2 関数的核と可変殻

**関数型アーキテクチャ**: ビジネスロジック（決定を下すコード）と副作用（決定に基づくアクション）を分離する。

```
┌─────────────────────────────────────────────────┐
│               アプリケーションサービス               │
│  ┌───────────────┐      ┌──────────────────────┐  │
│  │  関数的核     │      │     可変殻            │  │
│  │(functional    │  ←  │  (mutable shell)      │  │
│  │ core)         │  →  │                       │  │
│  │  決定を下す   │      │  入力収集・副作用実行  │  │
│  │  純粋関数     │      │  DB・ファイル操作     │  │
│  └───────────────┘      └──────────────────────┘  │
└─────────────────────────────────────────────────┘
```

連携フロー:
1. 可変殻がすべての入力値を収集する
2. 関数的核が決定を下す（戻り値として返す）
3. 可変殻が決定内容に基づいて副作用を発生させる

**テスト戦略**:
- 関数的核 → **出力値ベーステスト**（モック不要）
- 可変殻 → **統合テスト**（テストケース数は少なく）

### 3.3 ヘキサゴナルアーキテクチャとの比較

| アーキテクチャ | 副作用の扱い |
|--------------|------------|
| **関数型** | すべての副作用をドメイン層の外に出す |
| **ヘキサゴナル** | ドメイン層内に収まる副作用は許容 |

> 関数型アーキテクチャはヘキサゴナルアーキテクチャに極端な制限を課したものと見なせる。

---

## 4. 実例: 訪問者記録システム（TypeScript/Vitest）

訪問者記録をテキストファイルに書き込むシステムの3段階進化:

```
初期版（ファイルシステム直結） → 迅速なフィードバック: ❌ 保守性: ❌
モック導入版（DI + インターフェース）→ 迅速なフィードバック: ✅ 保守性: △
関数型アーキテクチャ版          → 迅速なフィードバック: ✅ 保守性: ✅
```

### 関数型アーキテクチャ版（推奨）

```typescript
// 入力データクラス（可変殻から関数的核へ）
interface FileContent { fileName: string; lines: string[] }

// 出力データクラス（関数的核の決定内容）
interface FileUpdate { fileName: string; newContent: string }

// ✅ 関数的核: 副作用なし。戻り値で決定を伝える
class AuditManager {
  constructor(private maxEntriesPerFile: number) {}

  addRecord(
    files: FileContent[],
    visitorName: string,
    timeOfVisit: Date,
  ): FileUpdate {
    const sorted = sortByIndex(files)
    const newRecord = `${visitorName};${timeOfVisit.toISOString()}`

    if (sorted.length === 0) {
      return { fileName: 'audit_1.txt', newContent: newRecord }
    }

    const [currentIndex, currentFile] = sorted.at(-1)!
    const lines = [...currentFile.lines]

    if (lines.length < this.maxEntriesPerFile) {
      lines.push(newRecord)
      return { fileName: currentFile.fileName, newContent: lines.join('\r\n') }
    }
    return { fileName: `audit_${currentIndex + 1}.txt`, newContent: newRecord }
  }
}

// 可変殻: ファイルシステムとのやり取りのみ担当
class Persister {
  readDirectory(dir: string): FileContent[] { /* fs.readdirSync ... */ }
  applyUpdate(dir: string, update: FileUpdate): void { /* fs.writeFileSync ... */ }
}
```

**出力値ベーステスト（モック不要）:**

```typescript
describe('AuditManager', () => {
  it('現在のファイルが上限に達したとき、新しいファイルが作成される', () => {
    const sut = new AuditManager(3)
    const files: FileContent[] = [
      { fileName: 'audit_1.txt', lines: [] },
      {
        fileName: 'audit_2.txt',
        lines: ['Peter; 2019-04-06T16:30:00', 'Jane; 2019-04-06T16:40:00', 'Jack; 2019-04-06T17:00:00'],
      },
    ]

    const actual = sut.addRecord(files, 'Alice', new Date('2019-04-06T18:00:00'))

    const expected: FileUpdate = {
      fileName: 'audit_3.txt',
      newContent: 'Alice;2019-04-06T18:00:00.000Z',
    }
    expect(actual).toEqual(expected)
  })
})
```

---

## 5. 関数型アーキテクチャの制限

### 5.1 長い処理チェーン / 途中での追加データ取得

決定の途中でプロセス外依存からデータを追加取得しなければならない場合、関数的核への依存が生じ純粋関数でなくなる。

```typescript
// ❌ 関数的核からプロセス外依存を呼ぶと純粋関数でなくなる
addRecord(files, visitorName, timeOfVisit, database: IDatabase): FileUpdate
```

解決策（トレードオフがある）:
- **前もって全入力を収集**: ビジネスロジックの分離を維持 → 不要なDBアクセスでパフォーマンス低下
- **段階的に決定**: アプリサービスが「DB呼び出し要否を判断」→ビジネスロジックの一部が漏れる

> **NOTE**: 関数的核は協力者オブジェクトと共に処理するのではなく、協力者オブジェクトによって得られた**値**を用いて処理する。

### 5.2 パフォーマンス面の欠点

「入力データ収集 → 決定 → 実行」の形式を遵守するため、プロセス外依存への呼び出しが増える可能性がある（例: 必要なファイルだけでなくディレクトリ全体を先に読み込む）。

保守のしやすさとパフォーマンスのトレードオフ: パフォーマンスへの影響が軽微なシステムなら関数型アーキテクチャが有利。

### 5.3 コードベース肥大化の懸念

関数的核と可変殻の明確な分離により初期実装コード量が増える。単純なシステムでは初期コストが利益を上回ることがある。

### 5.4 実践的な指針

```
目標: すべてのテストを出力値ベーステストにすることではなく、
      できるだけ多くのテストを出力値ベーステストにすること

実際: 出力値ベース + 状態ベースを組み合わせた運用が現実的
     （コミュニケーションベースは限定的に使用）
```

---

## まとめ

| 手法 | 推奨度 | 使用場面 |
|------|:------:|---------|
| 出力値ベース | ◎ | 純粋関数で実装されたビジネスロジック |
| 状態ベース | ○ | 状態変化が観察可能な振る舞いの場合 |
| コミュニケーションベース | △ | アプリケーション境界を超え、外部から確認できる副作用がある場合のみ |

出力値ベーステストを増やす鍵は**関数型アーキテクチャ**: 関数的核（決定）と可変殻（副作用実行）に分離することで、ビジネスロジックをモックなしでテストできるようになる。
