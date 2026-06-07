# アジャイル開発との統合

## アジャイルと CA の両立

「アジャイル = アーキテクチャを考えない」は誤解。アジャイルにおいてアーキテクチャは**継続的に進化する設計判断の蓄積**として存在する。

---

## インクリメンタル設計

### YAGNI と CA のバランス

**YAGNI（You Aren't Gonna Need It）：** 今必要でない機能を作らない原則。

CA の視点から YAGNI を解釈：
- 抽象化は「今」必要な場合のみ作る（Partial Boundary の活用）
- レイヤーを完全に分離する前に、まず正しい構造を決める
- インターフェースは「実装が2種類必要になる」まで待っても良い

**YAGNI vs 適切な境界設計のバランス：**

```
✅ YAGNI を適用すべき：
  - 2番目の DB 実装（今は PostgreSQL のみ）
  - 複雑なキャッシュ機構（要件なし）
  - 非同期処理（現状同期で十分）

❌ YAGNI を適用すべきでない（今やるべき）：
  - UseCase と Controller の分離（後でやると高コスト）
  - Entity へのビジネスルール集約（混乱が広がる前に）
  - Gateway インターフェースの定義（テスト可能性に直結）
```

---

## テクニカルデット管理

### アーキテクチャレベルのテクニカルデット

| デット種別 | 例 | 影響 | 優先度 |
|-----------|-----|------|--------|
| **依存方向の違反** | UseCase が Express の型を直接使用 | フレームワーク交換不可 | 高 |
| **境界の侵食** | Controller にビジネスルールが混入 | テスト困難化、変更影響範囲拡大 | 高 |
| **循環依存** | A→B→C→A | ビルド不安定、テスト困難 | 高 |
| **貧血ドメインモデル** | Entity が DTO 化 | ビジネスルール散在 | 中 |
| **不適切な凝集** | 無関係クラスが同一コンポーネント | 変更の影響が広がる | 中 |

### テクニカルデット可視化

```bash
# 依存違反の検出（TypeScript）
# .dependency-cruiser.js で以下のルールを設定
{
  forbidden: [
    {
      name: 'usecase-no-framework',
      from: { path: 'src/usecases' },
      to: { path: 'node_modules/express' }
    },
    {
      name: 'entity-no-db',
      from: { path: 'src/entities' },
      to: { path: 'node_modules/(typeorm|pg|mysql)' }
    }
  ]
}
```

---

## バランシング：YAGNI vs 長期構造

### スプリントでの判断フレームワーク

```
新機能追加時の判断：

Q1: 既存のレイヤー分離を壊す変更か？
  Yes → リファクタリングを先に実施（技術負債返済）
  No  → そのまま実装 ↓

Q2: 新しいドメイン境界が生まれるか？
  Yes → コンポーネント分割を検討
  No  → 既存コンポーネントに追加 ↓

Q3: 将来の変更可能性が高い箇所か？
  Yes → Gateway Interface 等で柔軟性を確保
  No  → 直接実装（YAGNI）
```

---

## アーキテクチャリファクタリング

### コードレベル vs アーキテクチャレベルのリファクタリング

| 種別 | 対象 | 例 | リスク |
|------|------|-----|--------|
| コードレベル | クラス・メソッド内 | 変数名変更、メソッド抽出 | 低 |
| コンポーネントレベル | クラス間・ファイル間 | クラス移動、インターフェース導入 | 中 |
| アーキテクチャレベル | レイヤー・境界 | ビジネスルールの Entity 移動 | 高 |

### アーキテクチャリファクタリングの進め方

**前提：テストが存在すること**

```
Step 1: テストを先に書く（現在の振る舞いを保護）
Step 2: リファクタリングを小さなステップで実施
Step 3: 各ステップでテストを実行
Step 4: 全テスト通過を確認
```

**Entity 抽出リファクタリングの例：**

```typescript
// Before: Service にビジネスルールが混在
class OrderService {
  async addItem(orderId: string, productId: string, qty: number) {
    const order = await this.orderRepo.findById(orderId);
    // ❌ ビジネスルールが Service に
    if (qty <= 0) throw new Error('数量は1以上必要');
    if (order.items.length >= 100) throw new Error('注文上限');
    order.items.push({ productId, qty });
    order.totalAmount = order.items.reduce((sum, item) => sum + item.price, 0);
    await this.orderRepo.save(order);
  }
}

// After Step 1: テストを書く
describe('Order.addItem', () => {
  it('数量0でエラー', () => { ... });
  it('上限100個超えでエラー', () => { ... });
});

// After Step 2: Entity にルールを移動
class Order {
  addItem(productId: string, qty: number): void {
    if (qty <= 0) throw new Error('数量は1以上必要');
    if (this.items.length >= 100) throw new Error('注文上限');
    this.items.push({ productId, qty });
  }
}

// After Step 3: Service は Entity に委譲
class OrderService {
  async addItem(orderId: string, productId: string, qty: number) {
    const order = await this.orderRepo.findById(orderId);
    order.addItem(productId, qty);  // ビジネスルールは Entity に
    await this.orderRepo.save(order);
  }
}
```

---

## 保守可能なシステムの構築

### 変更コストの時間的推移

```
理想（CA 適用）:
変更コスト
│     __________ （若干増加だが安定）
│___/
└─────────────── 時間

問題システム:
変更コスト
│         /
│       /
│     /
│   /
│ /
└─────────────── 時間
```

CA を適用しないと変更コストは時間とともに増大する。初期の投資（適切なレイヤー分離）が長期的コスト削減につながる。

### 保守性の測定指標

| 指標 | 計算方法 | 目標値 |
|------|---------|--------|
| **変更影響範囲** | 1変更で影響するファイル数 | 少ないほど良い |
| **テストカバレッジ** | Entity/UseCase の単体テスト率 | ビジネスロジック 80%+ |
| **循環依存数** | 依存グラフ中の循環数 | 0（ゼロ） |
| **依存違反数** | CI での依存ルール違反件数 | 0（ゼロ） |
| **平均クラスサイズ** | クラスあたりの行数 | 200行以下 |

---

## アジャイルチームでの CA 導入

### 段階的導入ロードマップ

```
Month 1: 認識
  - チーム全員が CA の基本概念を共有
  - 現状のアーキテクチャ問題を可視化
  - 最も痛みの大きい箇所を特定

Month 2-3: 基盤確立
  - Entity 層の確立（ビジネスルールを移動）
  - UseCase 境界の定義
  - 新規機能は CA に従って実装

Month 4-6: 浸透
  - Gateway Interface の導入（DB 依存の解消）
  - フレームワーク依存の外側への移動
  - CI での依存ルール自動チェック

Month 7+: 継続的改善
  - テクニカルデット残高の定期的削減
  - コンポーネント分割の評価（SDP/SAP 適用）
  - アーキテクチャ決定記録（ADR）の整備
```

### Definition of Done（DoD）への追加

スプリントの DoD に CA 観点を追加：

- [ ] 新規コードは Dependency Rule に違反していないか
- [ ] ビジネスルールは適切なレイヤー（Entity/UseCase）に配置されているか
- [ ] UseCase は単体テスト可能か（フレームワークなし）
- [ ] CI の依存チェックが通っているか
