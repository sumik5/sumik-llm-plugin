# ケーススタディ・実例

## CA 設計プロセスの実践例

良いアーキテクトが辿るプロセスを追体験する。

---

## ケーススタディ1：コンテンツ販売システム

### ドメイン概要

デジタルコンテンツ（動画・記事等）を販売するWebシステム。

- 個人ユーザー：ストリーミング視聴または購入
- 法人ユーザー：バッチ購入（数量割引）
- コンテンツ作成者：コンテンツのアップロード・管理
- 管理者：コンテンツシリーズ・価格管理

### Step 1: アクター分析

**4つのアクターを特定（SRP 適用）：**

| アクター | 主な関心 | 変更理由 |
|---------|---------|---------|
| Viewer（視聴者） | コンテンツ視聴 | 視聴UX変更、プレイヤー仕様変更 |
| Purchaser（購入者） | コンテンツ購入 | 決済フロー変更、価格体系変更 |
| Author（作成者） | コンテンツ投稿 | 投稿フォーマット変更、審査プロセス変更 |
| Administrator（管理者） | 運用管理 | 管理機能追加、レポート変更 |

**ポイント：** 4アクターは4つの変更理由を持つ。アクターごとにコンポーネントを分けることで変更を局所化できる。

### Step 2: ユースケース定義

```
[Viewer]
├── ViewCatalog（閲覧）← abstract（PurchaserViewも継承）
├── StreamContent（ストリーミング視聴）
└── DownloadContent（ダウンロード購入者のみ）

[Purchaser]
├── ViewCatalog（継承）
├── AddToCart
├── Checkout
└── ViewPurchaseHistory

[Author]
├── UploadContent
├── EditDescription
└── SetExamProblems

[Administrator]
├── AddContentSeries
├── SetPricing
└── ManageLicenses
```

### Step 3: コンポーネントアーキテクチャ

```
entities/
├── Content.ts         # コンテンツのビジネスルール
├── License.ts         # ライセンス種別・価格ルール
└── User.ts            # ユーザー・権限ルール

usecases/
├── viewer/
│   ├── ViewCatalogUseCase.ts
│   └── StreamContentUseCase.ts
├── purchaser/
│   ├── CheckoutUseCase.ts
│   └── ViewPurchaseHistoryUseCase.ts
├── author/
│   └── UploadContentUseCase.ts
└── admin/
    └── SetPricingUseCase.ts

adapters/
├── controllers/
├── presenters/
└── repositories/

frameworks/
├── express/
└── database/
```

### Step 4: 依存管理

```
制御フロー（右から左）:
HTTP Request → Controller → UseCase → Entity → Gateway

依存関係（左から右、内側へ）:
Controller → UseCase（抽象）
UseCase → Entity
Gateway実装 → Gateway Interface（UseCase 層で定義）

全依存が内側（Entity・UseCase）を向く = Dependency Rule 準拠
```

### 設計判断のトレードオフ

**選択1: 単一デプロイ vs 役割別マイクロサービス**

| 方針 | メリット | デメリット |
|------|---------|----------|
| 単一デプロイ | シンプル、運用コスト低 | スケールが一括 |
| 役割別マイクロサービス | 独立スケール可能 | 複雑度増大 |

**推奨：** まず単一デプロイ（CA 準拠）で構築し、スケール要件が明確になったら分割。CA はどちらの形態でも機能する。

---

## ケーススタディ2：レガシーシステムのリファクタリング

### Before: 典型的な問題システム

```
❌ 問題のある構造（Big Ball of Mud）
class UserController {
  async createUser(req, res) {
    // DB 直接アクセス（SQLが controller に）
    const existing = await db.query('SELECT * FROM users WHERE email = ?', [req.body.email]);
    if (existing.length > 0) return res.status(409).json({ error: 'exists' });

    // ビジネスルール（controller に）
    const hashedPassword = bcrypt.hash(req.body.password, 10);

    // メール送信（controller に）
    await emailService.send(req.body.email, 'Welcome!', '...');

    // ログ（controller に）
    logger.info('User created', { email: req.body.email });
  }
}
```

### After: CA 適用後

```typescript
// Entity: ビジネスルールをカプセル化
class User {
  static create(email: string, passwordHash: string): User {
    if (!email.includes('@')) throw new Error('Invalid email');
    return new User(email, passwordHash);
  }
}

// UseCase: フローを制御
class CreateUserUseCase {
  constructor(
    private userRepo: UserRepository,
    private passwordHasher: PasswordHasher,
    private notifier: UserNotifier
  ) {}

  async execute(request: CreateUserRequest): Promise<void> {
    if (await this.userRepo.findByEmail(request.email)) {
      throw new UserAlreadyExistsError();
    }
    const hash = await this.passwordHasher.hash(request.password);
    const user = User.create(request.email, hash);
    await this.userRepo.save(user);
    await this.notifier.notifyWelcome(user);
  }
}

// Controller: リクエスト変換のみ
class UserController {
  async createUser(req: Request, res: Response): Promise<void> {
    await this.useCase.execute({ email: req.body.email, password: req.body.password });
    res.status(201).json({ message: 'Created' });
  }
}
```

### リファクタリング戦略

```
段階的移行（ストラングラーフィグパターン）:

Phase 1: Entity 抽出
  目標: ビジネスロジックを独立クラスに移動
  テスト: Entity の単体テストを先に書く

Phase 2: UseCase 境界確立
  目標: Controller からビジネスロジックを UseCase に移動
  テスト: UseCase の統合テスト（DB モック）

Phase 3: Gateway インターフェース導入
  目標: DB アクセスをインターフェース経由に変更
  テスト: UseCase の単体テスト（完全モック）

Phase 4: Controller 分離
  目標: Controller を薄くする
  テスト: E2E テスト（HTTP レベル）
```

---

## ケーススタディ3：Web API 設計

### クリーンな Web API の構造

```typescript
// UseCase（API の関心なし）
class GetProductCatalogUseCase {
  async execute(request: GetCatalogRequest): Promise<void> {
    const products = await this.productRepo.findActive(request.categoryId);
    this.outputBoundary.present({ products });
  }
}

// Presenter（レスポンスデータ整形）
class GetCatalogPresenter implements GetCatalogOutputBoundary {
  private viewModel: CatalogViewModel;

  present(response: GetCatalogResponse): void {
    this.viewModel = {
      items: response.products.map(p => ({
        id: p.id,
        name: p.name,
        price: `¥${p.price.toLocaleString()}`,
        isAvailable: p.stock > 0
      })),
      totalCount: response.products.length
    };
  }
}

// Controller（HTTP 変換のみ）
class ProductController {
  async getCatalog(req: Request, res: Response): Promise<void> {
    const request = { categoryId: req.query.category as string };
    this.useCase.execute(request);
    res.json(this.presenter.getViewModel());
  }
}
```

---

## 実装パターンの選択判断

### コードベース構造（パッケージ編成）の選択肢

| アプローチ | 構造 | 適合場面 |
|-----------|------|---------|
| **レイヤーByLayer** | `controllers/`, `services/`, `repos/` | 小規模・シンプルな CRUD |
| **Feature-by-Feature** | `ordering/`, `billing/`, `users/` | 中規模・複数ドメイン |
| **Screaming（推奨）** | UseCase 名が最上位 | CA を厳密に適用する場合 |
| **Ports and Adapters** | `core/`, `adapters/` | Hexagonal Architecture |

**推奨：** Screaming Architecture + Feature-by-Feature の組み合わせ

```
src/
├── ordering/              # ビジネスドメイン名が最上位
│   ├── CreateOrder/       # ユースケース名
│   │   ├── CreateOrderUseCase.ts
│   │   ├── CreateOrderRequest.ts
│   │   └── CreateOrderResponse.ts
│   └── ViewOrderHistory/
└── billing/
    └── ProcessPayment/
```
