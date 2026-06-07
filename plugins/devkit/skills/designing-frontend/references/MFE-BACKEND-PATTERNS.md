# バックエンドパターン詳細

マイクロフロントエンドは、バックエンドAPIとの統合方法がアーキテクチャの成否を左右します。このドキュメントでは、主要なAPI統合パターンとベストプラクティスを解説します。

---

## Service Dictionary（サービスディクショナリ）

### 概要

Service Dictionaryは、APIエンドポイントを動的に検出・管理するレジストリパターンです。

### アーキテクチャ

```
[マイクロフロントエンド]
        ↓ 1. サービス検索
[Service Dictionary]
        ↓ 2. エンドポイント返却
[マイクロフロントエンド]
        ↓ 3. API呼び出し
[マイクロサービス]
```

### 実装例

**Service Dictionary API**:

```json
// GET /api/service-dictionary

{
  "products": {
    "baseUrl": "https://products-api.example.com",
    "version": "v2",
    "endpoints": {
      "list": "/products",
      "detail": "/products/:id",
      "search": "/products/search"
    }
  },
  "orders": {
    "baseUrl": "https://orders-api.example.com",
    "version": "v1",
    "endpoints": {
      "create": "/orders",
      "list": "/orders"
    }
  }
}
```

**クライアント実装**:

```typescript
// services/ServiceDictionary.ts
class ServiceDictionary {
  private cache: Map<string, ServiceInfo> = new Map();

  async getService(serviceName: string): Promise<ServiceInfo> {
    if (this.cache.has(serviceName)) {
      return this.cache.get(serviceName)!;
    }

    const response = await fetch('/api/service-dictionary');
    const services = await response.json();

    // キャッシュに保存
    Object.entries(services).forEach(([name, info]) => {
      this.cache.set(name, info as ServiceInfo);
    });

    return services[serviceName];
  }

  async callAPI(serviceName: string, endpoint: string, options?: RequestInit) {
    const service = await this.getService(serviceName);
    const url = `${service.baseUrl}${service.endpoints[endpoint]}`;
    return fetch(url, options);
  }
}

// 使用例
const dict = new ServiceDictionary();
const products = await dict.callAPI('products', 'list');
```

### メリット

- **動的エンドポイント管理**: サービスURLの変更に柔軟に対応
- **環境別設定**: 環境ごとにService Dictionaryを切り替えるだけ
- **バージョン管理**: API バージョンを明示的に管理

### デメリット

- **追加ホップ**: 初回呼び出し時にService Dictionary への問い合わせが必要
- **単一障害点**: Service Dictionary が落ちると全APIアクセス不可
- **キャッシュ管理**: 適切なキャッシュ戦略が必要

### 適用シーン

- マイクロサービスが多数存在（10個以上）
- 環境ごとにエンドポイントが大きく異なる
- 動的なサービス検出が必要

---

## API Gateway

### 概要

すべてのAPIリクエストを単一エントリポイント経由で処理します。

### アーキテクチャパターン

#### 1. クライアントサイドAPI Gateway

マイクロフロントエンドが直接複数のマイクロサービスを呼び出します。

```
[ブラウザ]
    ↓ CORS許可
[Products API]
[Orders API]
[Users API]
```

**メリット**:
- シンプル
- 低レイテンシ（プロキシなし）

**デメリット**:
- CORS設定が複雑
- 認証トークンがブラウザに露出
- マイクロサービスのURLがクライアントに露出

#### 2. サーバサイドAPI Gateway

すべてのAPIリクエストをゲートウェイ経由で処理します。

```
[ブラウザ]
    ↓
[API Gateway]
    ↓ ルーティング
[Products API]
[Orders API]
[Users API]
```

**実装例（Node.js + Express）**:

```typescript
// api-gateway/src/index.ts
import express from 'express';
import { createProxyMiddleware } from 'http-proxy-middleware';

const app = express();

// 認証ミドルウェア
app.use(async (req, res, next) => {
  const token = req.headers.authorization;
  if (!token) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  try {
    const user = await verifyToken(token);
    req.user = user;
    next();
  } catch (error) {
    res.status(401).json({ error: 'Invalid token' });
  }
});

// ルーティング
app.use('/api/products', createProxyMiddleware({
  target: 'http://products-service:3001',
  changeOrigin: true,
  pathRewrite: { '^/api/products': '' },
}));

app.use('/api/orders', createProxyMiddleware({
  target: 'http://orders-service:3002',
  changeOrigin: true,
  pathRewrite: { '^/api/orders': '' },
}));

app.listen(4000);
```

**メリット**:
- 認証の一元管理
- レート制限、ロギング等の横断的関心事を集約
- マイクロサービスの内部URLを隠蔽

**デメリット**:
- 追加レイテンシ
- 単一障害点
- スケーラビリティのボトルネック

### 機能拡張

#### レート制限

```typescript
import rateLimit from 'express-rate-limit';

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15分
  max: 100, // 最大100リクエスト
  message: 'Too many requests',
});

app.use('/api/', limiter);
```

#### リクエスト/レスポンス変換

```typescript
app.use('/api/products', (req, res, next) => {
  // リクエスト変換
  req.headers['x-user-id'] = req.user.id;
  next();
});

app.use('/api/products', createProxyMiddleware({
  target: 'http://products-service:3001',
  onProxyRes: (proxyRes, req, res) => {
    // レスポンス変換
    proxyRes.headers['x-gateway-version'] = '1.0';
  },
}));
```

### 適用シーン

- 認証の一元管理が必要
- レート制限、ロギング等の横断的関心事がある
- マイクロサービスの内部構造を隠蔽したい

---

## BFF（Backend for Frontend）パターン

### 概要

各マイクロフロントエンド（またはクライアントタイプ）専用のバックエンドAPIを提供します。

### アーキテクチャ

```
[Home MFE] → [Home BFF] ↘
[Products MFE] → [Products BFF] → [マイクロサービス群]
[Checkout MFE] → [Checkout BFF] ↗
```

**原則**: 1ドメイン = 1 BFF（1:1マッピング）

### 実装例

**Products BFF**:

```typescript
// products-bff/src/index.ts
import express from 'express';

const app = express();

// Products MFE専用のエンドポイント
app.get('/api/products', async (req, res) => {
  // 複数のマイクロサービスからデータ取得
  const [products, inventory, recommendations] = await Promise.all([
    fetch('http://products-service/products'),
    fetch('http://inventory-service/stock'),
    fetch('http://recommendations-service/related'),
  ]);

  // Products MFEに最適化したレスポンス
  const result = products.map(product => ({
    ...product,
    inStock: inventory[product.id] > 0,
    relatedProducts: recommendations[product.id],
  }));

  res.json(result);
});

// 商品詳細（複数APIの集約）
app.get('/api/products/:id', async (req, res) => {
  const { id } = req.params;

  const [product, reviews, inventory] = await Promise.all([
    fetch(`http://products-service/products/${id}`),
    fetch(`http://reviews-service/reviews?productId=${id}`),
    fetch(`http://inventory-service/stock/${id}`),
  ]);

  res.json({
    ...product,
    reviews: reviews.slice(0, 10), // 最新10件のみ
    inStock: inventory.quantity > 0,
    averageRating: calculateAverage(reviews),
  });
});

app.listen(3100);
```

**Checkout BFF**（異なるデータ構造）:

```typescript
// checkout-bff/src/index.ts
app.post('/api/checkout', async (req, res) => {
  const { items, shippingAddress, paymentMethod } = req.body;

  // トランザクション的な処理
  try {
    // 1. 在庫確認
    await fetch('http://inventory-service/reserve', {
      method: 'POST',
      body: JSON.stringify({ items }),
    });

    // 2. 決済処理
    const payment = await fetch('http://payment-service/charge', {
      method: 'POST',
      body: JSON.stringify({ amount, paymentMethod }),
    });

    // 3. 注文作成
    const order = await fetch('http://orders-service/orders', {
      method: 'POST',
      body: JSON.stringify({ items, shippingAddress, paymentId: payment.id }),
    });

    res.json({ orderId: order.id });
  } catch (error) {
    // ロールバック処理
    await rollback();
    res.status(500).json({ error: 'Checkout failed' });
  }
});
```

### SoundCloud方式（ドメインごとの独立性）

SoundCloudは、各ドメインに専用のBFFを配置し、完全な自律性を実現しました。

**特徴**:
- 各チームが自分のBFFを完全所有
- BFF間の依存関係を禁止
- 共通機能はライブラリ化

```
[Upload MFE] → [Upload BFF] (Upload Team所有)
[Player MFE] → [Player BFF] (Player Team所有)
[Profile MFE] → [Profile BFF] (Profile Team所有)
```

### メリット

- **最適化**: 各マイクロフロントエンドに最適化されたAPI
- **独立性**: チームごとに独立してBFFを開発・デプロイ
- **複雑さの隠蔽**: 複数マイクロサービスの統合ロジックをBFFに集約
- **パフォーマンス**: 複数API呼び出しをサーバーサイドで並列化

### デメリット

- **重複コード**: BFF間で重複ロジックが発生しやすい
- **運用コスト**: BFFの数だけインフラが増える
- **過剰な最適化**: 過度な最適化により保守性が低下

### 適用シーン

- 各マイクロフロントエンドのデータ要件が大きく異なる
- 複数のマイクロサービスからデータを集約する必要がある
- チームの完全な自律性を重視

---

## GraphQL統合

### 概要

GraphQLを使用して、マイクロフロントエンドが必要なデータのみを柔軟に取得します。

### アーキテクチャパターン

#### 1. GraphQL Gateway（単一スキーマ）

すべてのマイクロサービスのスキーマを統合した単一GraphQLエンドポイント。

```
[マイクロフロントエンド]
        ↓ GraphQLクエリ
[GraphQL Gateway]
    ↓ REST API呼び出し
[Products Service]
[Orders Service]
[Users Service]
```

**実装例（Apollo Server）**:

```typescript
// graphql-gateway/src/index.ts
import { ApolloServer } from '@apollo/server';
import { RESTDataSource } from '@apollo/datasource-rest';

// データソース定義
class ProductsAPI extends RESTDataSource {
  override baseURL = 'http://products-service:3001';

  async getProducts() {
    return this.get('/products');
  }

  async getProduct(id: string) {
    return this.get(`/products/${id}`);
  }
}

class OrdersAPI extends RESTDataSource {
  override baseURL = 'http://orders-service:3002';

  async getOrders(userId: string) {
    return this.get(`/orders?userId=${userId}`);
  }
}

// スキーマ定義
const typeDefs = `
  type Product {
    id: ID!
    name: String!
    price: Float!
    orders: [Order]  # リレーション
  }

  type Order {
    id: ID!
    productId: ID!
    userId: ID!
    status: String!
  }

  type Query {
    products: [Product]
    product(id: ID!): Product
    orders(userId: ID!): [Order]
  }
`;

// リゾルバ定義
const resolvers = {
  Query: {
    products: (_, __, { dataSources }) => dataSources.productsAPI.getProducts(),
    product: (_, { id }, { dataSources }) => dataSources.productsAPI.getProduct(id),
    orders: (_, { userId }, { dataSources }) => dataSources.ordersAPI.getOrders(userId),
  },
  Product: {
    orders: (product, _, { dataSources }) =>
      dataSources.ordersAPI.getOrders(product.id),
  },
};

const server = new ApolloServer({
  typeDefs,
  resolvers,
});
```

**クライアント使用例**:

```typescript
// マイクロフロントエンド側
import { gql, useQuery } from '@apollo/client';

const GET_PRODUCT_WITH_ORDERS = gql`
  query GetProduct($id: ID!) {
    product(id: $id) {
      id
      name
      price
      orders {
        id
        status
      }
    }
  }
`;

function ProductDetail({ productId }) {
  const { data, loading } = useQuery(GET_PRODUCT_WITH_ORDERS, {
    variables: { id: productId },
  });

  if (loading) return <Loading />;
  return (
    <div>
      <h1>{data.product.name}</h1>
      <p>価格: {data.product.price}</p>
      <h2>注文履歴</h2>
      {data.product.orders.map(order => (
        <OrderItem key={order.id} order={order} />
      ))}
    </div>
  );
}
```

#### 2. GraphQL Federation（スキーマ分散）

各マイクロサービスが独自のGraphQLスキーマを持ち、Gatewayが統合します。

```
[マイクロフロントエンド]
        ↓
[Apollo Gateway]
    ↓ GraphQL Federation
[Products GraphQL] [Orders GraphQL] [Users GraphQL]
```

**実装例**:

```typescript
// products-service/src/schema.ts
import { buildSubgraphSchema } from '@apollo/subgraph';

const typeDefs = gql`
  type Product @key(fields: "id") {
    id: ID!
    name: String!
    price: Float!
  }
`;

const resolvers = {
  Product: {
    __resolveReference(product) {
      return getProduct(product.id);
    },
  },
};

export const schema = buildSubgraphSchema({ typeDefs, resolvers });
```

```typescript
// orders-service/src/schema.ts
const typeDefs = gql`
  type Order {
    id: ID!
    product: Product
  }

  extend type Product @key(fields: "id") {
    id: ID! @external
    orders: [Order]
  }
`;

const resolvers = {
  Product: {
    orders(product) {
      return getOrdersByProductId(product.id);
    },
  },
};
```

```typescript
// gateway/src/index.ts
import { ApolloGateway } from '@apollo/gateway';

const gateway = new ApolloGateway({
  supergraphSdl: new IntrospectAndCompose({
    subgraphs: [
      { name: 'products', url: 'http://products:4001/graphql' },
      { name: 'orders', url: 'http://orders:4002/graphql' },
    ],
  }),
});
```

### メリット

- **柔軟なデータ取得**: 必要なフィールドのみ取得（Over-fetching解消）
- **型安全性**: GraphQL Code Generatorで自動型生成
- **単一エンドポイント**: 複数のREST APIを統合
- **リアルタイム対応**: Subscriptionでリアルタイム更新

### デメリット

- **学習コスト**: GraphQLの概念理解が必要
- **複雑なクエリ**: N+1問題、クエリコスト管理
- **キャッシュ戦略**: REST APIに比べ複雑

### 適用シーン

- データの取得パターンが多様
- マイクロフロントエンドごとに必要なデータが大きく異なる
- リアルタイム更新が必要

---

## ベストプラクティス

### 1. 1ドメイン = 1 APIエントリポイント

**悪い例**（複数エンドポイント）:

```
Products MFE → Products Service
            → Inventory Service
            → Reviews Service
```

**良い例**（BFF経由）:

```
Products MFE → Products BFF → Products Service
                            → Inventory Service
                            → Reviews Service
```

### 2. APIバージョニング

**URLベース**（推奨）:

```
/api/v1/products
/api/v2/products
```

**ヘッダーベース**:

```
GET /api/products
Accept: application/vnd.myapi.v2+json
```

### 3. エラーハンドリングの統一

```typescript
// 統一エラーレスポンス
{
  "error": {
    "code": "PRODUCT_NOT_FOUND",
    "message": "Product with ID 123 not found",
    "details": {
      "productId": "123"
    }
  }
}
```

### 4. 認証トークンの伝播

```typescript
// BFF内での認証トークン伝播
app.use(async (req, res, next) => {
  const token = req.headers.authorization;

  // すべての下流APIにトークンを伝播
  req.apiClient = axios.create({
    headers: {
      Authorization: token,
    },
  });

  next();
});
```

### 5. タイムアウトとリトライ

```typescript
import axios from 'axios';
import axiosRetry from 'axios-retry';

const client = axios.create({
  timeout: 5000, // 5秒
});

axiosRetry(client, {
  retries: 3,
  retryDelay: axiosRetry.exponentialDelay,
  retryCondition: (error) => {
    // 5xxエラーのみリトライ
    return error.response?.status >= 500;
  },
});
```

---

## パターン選択ガイド

| 要件 | 推奨パターン | 理由 |
|------|------------|------|
| **シンプルなAPI統合** | API Gateway | 認証・ロギング等の集約 |
| **マイクロサービスが多数** | Service Dictionary | 動的なエンドポイント管理 |
| **ドメインごとの最適化** | BFF | 各MFEに最適化されたAPI |
| **柔軟なデータ取得** | GraphQL | Over-fetching解消 |
| **完全な独立性** | BFF (1:1マッピング) | チームの自律性最大化 |
| **リアルタイム更新** | GraphQL Subscriptions | WebSocket経由のリアルタイム通信 |

---

## 次のステップ

1. **パターン選択**: プロジェクト要件に基づき上記ガイドから選択
2. **認証統合の設計**: トークン管理、セッション管理の統一
3. **エラーハンドリングの統一**: エラーレスポンス形式の標準化
4. **パフォーマンス最適化**: キャッシュ戦略、並列化の実装
5. **可観測性の実装**: [BUILD-AND-DEPLOY.md](./BUILD-AND-DEPLOY.md) 参照
