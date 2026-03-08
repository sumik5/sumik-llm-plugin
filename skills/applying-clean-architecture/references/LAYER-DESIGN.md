# レイヤー設計詳細

## 各レイヤーの責任と設計ガイドライン

---

## エンティティ（Entities）層

### 責任範囲

エンティティはシステム全体で最も安定したビジネスルールをカプセル化する。

- **企業規模のビジネスルール**：複数アプリで共有される普遍的ルール
- **アプリ固有ルール**：1アプリのみ存在する場合はそのアプリのビジネスオブジェクト
- 外部変化（UI変更、DB変更、セキュリティポリシー変更）に影響されない

### 設計パターン

```typescript
// エンティティの例（TypeScript）
class Order {
  private items: OrderItem[];

  addItem(item: OrderItem): void {
    // ビジネスルール：在庫確認、最大数チェック等
    if (this.items.length >= 100) {
      throw new Error('注文上限を超えています');
    }
    this.items.push(item);
  }

  calculateTotal(): Money {
    // ビジネスルール：合計計算、割引適用
    return this.items.reduce((sum, item) => sum.add(item.price), Money.zero());
  }
}
```

### 良いエンティティの条件

- [ ] フレームワークを import していない
- [ ] DB 関連ライブラリを import していない
- [ ] ログライブラリを直接使用していない
- [ ] ビジネスルールがメソッドとして表現されている（Anemic Domain Model を避ける）

---

## ユースケース（Use Cases）層

### 責任範囲

アプリケーション固有のビジネスロジックを含む。「誰が何をするか」を表現する。

- **入力**：Request DTO（プリミティブ型・値オブジェクトのみ）
- **出力**：OutputBoundary インターフェース経由（直接 Presenter を呼ばない）
- エンティティへの操作を指揮
- DB は `Gateway Interface` 経由でのみアクセス

### Request/Response Model 設計

```typescript
// 良い例：DTO は単純なデータ構造のみ
interface CreateOrderRequest {
  customerId: string;
  items: Array<{ productId: string; quantity: number }>;
}

interface CreateOrderResponse {
  orderId: string;
  totalAmount: number;
  estimatedDeliveryDate: string;
}

// ユースケースインターフェース
interface CreateOrderInputBoundary {
  execute(request: CreateOrderRequest): void;
}

interface CreateOrderOutputBoundary {
  present(response: CreateOrderResponse): void;
}
```

### Database Gateway インターフェース

```typescript
// ユースケース層で定義するインターフェース
interface OrderGateway {
  findById(orderId: string): Order | null;
  findByCustomerId(customerId: string): Order[];
  save(order: Order): void;
  delete(orderId: string): void;
}
```

SQL はこのインターフェースの実装側（外側のレイヤー）に記述。ユースケース層は SQL を知らない。

---

## インターフェースアダプター（Interface Adapters）層

### 責任範囲

内側（UseCase/Entity）と外側（DB/Web/外部サービス）のデータ形式を相互変換する。

### Presenter と View の分離

**Humble Object パターンの適用：**

```typescript
// Presenter（テスト容易）
class CreateOrderPresenter implements CreateOrderOutputBoundary {
  private viewModel: OrderViewModel;

  present(response: CreateOrderResponse): void {
    this.viewModel = {
      orderId: response.orderId,
      totalAmount: formatCurrency(response.totalAmount),  // "¥1,234" 形式
      deliveryDate: formatDate(response.estimatedDeliveryDate),
      isExpressEligible: response.totalAmount > 5000  // boolean フラグ
    };
  }

  getViewModel(): OrderViewModel { return this.viewModel; }
}

// View（テスト困難なため最小限に）
class OrderConfirmationView {
  render(viewModel: OrderViewModel): string {
    // ViewModel から HTML を生成するだけ（ロジックなし）
    return `<div>${viewModel.totalAmount}</div>`;
  }
}
```

### Controller の設計

```typescript
// Controller（Web フレームワーク依存を最小化）
class OrderController {
  constructor(private useCase: CreateOrderInputBoundary) {}

  async handleCreateOrder(httpRequest: HttpRequest): Promise<HttpResponse> {
    const request: CreateOrderRequest = {
      customerId: httpRequest.body.customer_id,
      items: httpRequest.body.items.map(item => ({
        productId: item.product_id,
        quantity: Number(item.qty)
      }))
    };
    this.useCase.execute(request);
    // Presenter から ViewModel を取得してレスポンスを構築
  }
}
```

### ORM / データマッパーの配置

ORM（Hibernate, TypeORM 等）はデータマッパーとしてこの層の DB 側に配置する。

```
[UseCase] → [OrderGateway interface] ← [TypeORMOrderRepository]
                                           ↕（ORM は DB レイヤーに）
                                      [Database]
```

---

## フレームワーク＆ドライバー（Frameworks & Drivers）層

### 責任範囲

最外層。すべての「詳細」が集まる。

- Webフレームワーク（Express, Spring, Rails 等）
- ORMフレームワーク（TypeORM, Hibernate 等）
- DB ドライバー（pg, mysql2 等）
- 外部サービスクライアント（AWS SDK 等）

### フレームワークとの関係

```
フレームワークはツールである。
フレームワークの設計思想に合わせてアーキテクチャを変えてはならない。
フレームワークはいつでも交換可能な「詳細」として扱う。
```

**フレームワーク依存を最小化する戦略：**
- フレームワーク固有のアノテーションは外側のクラスにのみ付与
- ビジネスロジッククラスはフレームワーク非依存の純粋クラスとして作成
- フレームワーク固有型はアダプターレイヤーで変換

---

## 独立性の4次元

良いアーキテクチャは以下の4次元での独立性を支える：

### 1. ユースケースの独立性

各ユースケースは独立したコンポーネントとして分離可能。変更が他のユースケースに波及しない。

### 2. 運用の独立性

モノリスとして始め、マイクロサービスに分割できるよう設計。逆も然り。アーキテクチャはデプロイ形態の決定を遅らせる。

### 3. 開発の独立性

異なるチームが異なるコンポーネントを並行開発できる。安定したインターフェースで結合。

### 4. デプロイの独立性

各コンポーネントを独立してデプロイ可能。ホットデプロイ対応。

---

## デカップリングモード

| モード | 説明 | 適用場面 |
|--------|------|---------|
| **ソースレベル** | 同一プロセス・同一バイナリ内でインターフェース分離 | 初期開発、小規模 |
| **デプロイメントレベル** | 独立デプロイ可能な `.jar`, `.dll` 等 | 中規模、チーム分割時 |
| **サービスレベル** | ネットワーク越しの通信（マイクロサービス） | 大規模、独立スケール要件 |

**重要：** デカップリングモードは変更可能であるべき。CA はどのモードへも移行できる構造を目指す。

---

## エンタープライズ構造のベストプラクティス

### Web アプリケーション構造

```
src/
├── entities/         # レイヤー1：ビジネスオブジェクト
│   ├── Order.ts
│   └── Product.ts
├── usecases/         # レイヤー2：アプリケーションビジネスルール
│   ├── CreateOrderUseCase.ts
│   └── interfaces/   # Gateway, Presenter インターフェース
├── adapters/         # レイヤー3：変換・MVC
│   ├── controllers/
│   ├── presenters/
│   └── repositories/ # Gateway 実装
└── frameworks/       # レイヤー4：フレームワーク・DB
    ├── express/
    └── typeorm/
```

### DDD との協調（applying-domain-driven-design との関係）

| CA の概念 | DDD の対応概念 |
|-----------|--------------|
| Entity | Domain Entity + Value Object |
| Use Case | Application Service |
| Gateway Interface | Repository Interface |
| Interface Adapter | Infrastructure Layer |

CA と DDD は補完関係。CA が依存の方向を規定し、DDD がドメイン内部の構造を規定する。
