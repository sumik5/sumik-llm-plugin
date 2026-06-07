# アーキテクチャアンチパターン

## アンチパターン概要

アンチパターンとは、一見正しいように見えるが長期的に問題を引き起こす設計パターン。早期発見・早期対処が保守コストを大幅に削減する。

---

## 1. Big Ball of Mud（泥団子）

### 症状

- システムに明確な構造・境界が存在しない
- ビジネスロジック・データアクセス・プレゼンテーションが混在
- どこに何があるか誰も分からない
- 変更すると予期しない箇所が壊れる

### 根本原因

| 原因 | 詳細 |
|------|------|
| 納期プレッシャー | 速度優先でアーキテクチャを後回しにし続けた結果 |
| リファクタリング不足 | 「動いているものを触るな」文化 |
| 短期的思考 | 明日の締切だけを見て、1年後を考えない |

### 解決策

1. **新規機能は CA レイヤーに従って実装**（既存部分の混乱を拡大しない）
2. **段階的リファクタリング**：最も変化の多い箇所から境界を引く
3. **「抑止剤」ルールの設定**：新規コードの依存方向ルールを CI で強制

---

## 2. God Classes と Anemic Domain Models

### God Classes（神クラス）

**症状：**
- 1つのクラスが数千行を超えている
- クラス名が `Manager`, `Service`, `Handler`, `Util` 等の曖昧な名前
- 変更するたびに多くの箇所に影響が及ぶ

**根本原因：** SRP 違反。責任を分割せずに機能追加し続けた結果。

```typescript
// ❌ God Class の例
class UserManager {
  register(user: User): void { /* 登録 */ }
  sendEmail(user: User, message: string): void { /* メール送信 */ }
  generateReport(user: User): PDF { /* レポート生成 */ }
  calculateBilling(user: User): number { /* 請求計算 */ }
  updateProfile(user: User): void { /* プロフィール更新 */ }
}

// ✅ 責任分割後
class UserRegistrationUseCase { /* 登録のみ */ }
class NotificationService { /* メール送信のみ */ }
class ReportGenerationUseCase { /* レポートのみ */ }
class BillingCalculator { /* 請求のみ */ }
```

### Anemic Domain Models（貧血ドメインモデル）

**症状：**
- エンティティがデータだけ持ち、ビジネスロジックを持たない
- ビジネスロジックがサービス層やコントローラーに漏れ出している
- エンティティが DTO と変わらない

```typescript
// ❌ 貧血ドメインモデル
class Order {
  public items: OrderItem[];
  public totalAmount: number;
  public status: string;
  // ビジネスロジックなし
}

// ビジネスロジックがサービスに漏れ出す
class OrderService {
  calculateTotal(order: Order): number { /* ここに漏れ */ }
  validateOrder(order: Order): boolean { /* ここに漏れ */ }
}

// ✅ リッチドメインモデル
class Order {
  private items: OrderItem[];

  addItem(item: OrderItem): void { /* バリデーション込み */ }
  calculateTotal(): Money { /* ここに属するロジック */ }
  submit(): void { /* 状態遷移ルール */ }
}
```

**解決策：** ビジネスルールをエンティティに持ち帰る。テストは `OrderService` ではなく `Order` の振る舞いをテストする。

---

## 3. Over-Engineering と Premature Abstraction（過剰設計と早まった抽象化）

### 症状

- 1つのユースケースに対して5つのインターフェースが存在する
- 「将来必要になるかもしれない」機能が実装されている
- 設計の説明に15分かかる
- YAGNI（You Aren't Gonna Need It）違反

### 根本原因

| 原因 | 詳細 |
|------|------|
| 完璧主義 | すべての将来ケースをカバーしようとする |
| 要件理解不足 | 問題を完全に理解する前に抽象化を試みる |
| 重複恐怖 | 小さな重複を排除するためだけに過剰な抽象化 |

### 解決策

**Three Rule（3の法則）：** 同じロジックが3回登場した時点で初めて抽象化を検討する。

```
初回実装：コピー&ペーストでも良い
2回目：再コピーを認識（将来抽象化の候補）
3回目：抽象化のタイミング
```

**抽象化の判断基準：**
- [ ] 同じロジックが複数箇所に存在するか？
- [ ] 変更時に複数箇所を修正する必要があるか？
- [ ] 抽象化によって理解が**容易**になるか？（難しくならないか）

---

## 4. Overuse of Patterns（パターンの過剰適用）

### 症状

- 単純な CRUD 操作に Factory + Builder + Strategy + Observer が使われている
- 新人開発者がコードを読めない
- パターン名を説明しないとコードの意図が伝わらない

### 根本原因

- パターンに精通すると「全てに適用したくなる」心理
- パターンを使うこと自体が目的化する
- 根本的な設計問題をパターンで隠蔽しようとする

### 解決策

| 状況 | 推奨アプローチ |
|------|--------------|
| 単純な変換処理 | 関数 1 つ |
| 1種類の実装しか存在しない | インターフェース不要 |
| 設定値が 2 つ以下 | if 文で十分 |
| 将来交換可能にしたい | まず直接実装し、必要になったらリファクタリング |

**原則：** パターンは問題を解決するために存在する。問題がないならパターンは不要。

---

## 5. Misplaced Responsibilities（責任の誤配置）

### 症状

- Controller がビジネスロジックを持つ
- Entity が HTTP リクエストオブジェクトを知っている
- UseCase が HTML を生成する
- Repository がメール送信を行う

### 典型的な誤配置パターン

```typescript
// ❌ Controller にビジネスロジックが混入
class OrderController {
  async createOrder(req: Request): Promise<Response> {
    const order = new Order();
    // ❌ ここはビジネスルール → UseCase に移動すべき
    if (req.body.items.length > 100) {
      throw new Error('Too many items');
    }
    // ❌ ここもビジネスルール
    const discount = order.totalAmount > 10000 ? 0.1 : 0;
    order.applyDiscount(discount);
    await this.orderRepository.save(order);
  }
}

// ✅ Controller は UseCase を呼ぶだけ
class OrderController {
  async createOrder(req: Request): Promise<Response> {
    const request = this.mapToRequest(req);
    this.createOrderUseCase.execute(request);
    // レスポンス組み立て
  }
}
```

### CA レイヤー別の責任チェックリスト

| レイヤー | 責任あり | 責任なし |
|---------|---------|---------|
| Entity | ビジネスルール、ドメインロジック | HTTP、DB、メール |
| UseCase | フロー制御、エンティティ操作の指揮 | UI表示、SQL、外部サービス直接呼び出し |
| Controller | リクエスト解析、DTO 変換 | ビジネスロジック |
| Repository | データアクセス実装 | ビジネス判断 |

---

## アンチパターン検出ツール

### 静的解析

```bash
# TypeScript の場合：eslint と dependency-cruiser
npx eslint src --rule "max-lines: ['warn', 300]"  # 300行超でワーニング
npx depcruise --validate .dependency-cruiser.js src  # 依存ルール違反チェック

# Python の場合：pylint, radon
radon cc -a src/  # 循環複雑度（高いほど God Function の疑い）
pylint src/ --max-line-count=300
```

### コードレビューチェックリスト

- [ ] クラスが300行を超えていないか
- [ ] 単一クラスの責任が1つか
- [ ] ビジネスロジックが適切なレイヤーにあるか
- [ ] エンティティがビジネスルールを保持しているか
- [ ] インターフェースが本当に必要か（実装が1つだけなら再考）
