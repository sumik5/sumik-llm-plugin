# 移行戦略と組織設計

マイクロフロントエンドの成功には、技術的な実装だけでなく、組織設計とモノリスからの移行戦略が重要です。このドキュメントでは、実践的な移行手順と組織パターンを解説します。

---

## モノリスからの移行戦略

### 意思決定フレームワークの適用

#### ステップ1: 現状分析

**調査項目**:

| 項目 | 調査内容 | ツール |
|------|---------|--------|
| **トラフィック分析** | どのページが最も使われているか | Google Analytics, New Relic |
| **機能境界特定** | 独立して変更可能な機能単位 | コードベース分析 |
| **チーム構成** | 現在のチーム分担とコミュニケーション | 組織図、ヒアリング |
| **技術スタック** | 使用中のフレームワーク、ライブラリ | package.json分析 |

**出力**: 現状のアーキテクチャマップ

```
[モノリスフロントエンド]
├── /home (15% トラフィック)
├── /products (40% トラフィック) ← 最優先移行候補
├── /cart (10% トラフィック)
├── /checkout (20% トラフィック)
└── /profile (15% トラフィック)
```

#### ステップ2: サブドメイン分割

**DDD適用**:

1. **コアドメイン**: ビジネス価値が最も高い（例: 商品検索・購入フロー）
2. **サポートドメイン**: コアを支える（例: レビュー、レコメンデーション）
3. **汎用ドメイン**: どのビジネスでも共通（例: 認証、通知）

**分割例**:

| ドメイン | 種別 | 移行優先度 | 理由 |
|---------|------|-----------|------|
| Products | コア | 高 | トラフィック40%、ビジネス価値高 |
| Checkout | コア | 高 | 収益直結 |
| Profile | サポート | 中 | 独立性高、依存少 |
| Home | 汎用 | 低 | 他ドメインへの依存多 |

#### ステップ3: 技術選定

**評価基準**:

| 基準 | 重み | Module Federation | iframe | SSR Framework |
|------|------|------------------|--------|---------------|
| **SEO要件** | 高 | ★★ | ★ | ★★★★★ |
| **チーム独立性** | 高 | ★★★★ | ★★★★★ | ★★★ |
| **既存コード再利用** | 中 | ★★★★ | ★★★ | ★★ |
| **学習コスト** | 中 | ★★ | ★★★★★ | ★★★ |
| **パフォーマンス** | 中 | ★★★★ | ★★★ | ★★★★★ |

**決定**: Products（SEO重要）はSSR、他はModule Federation

### 段階的移行手順

#### Phase 1: インフラ準備（Week 1-2）

**タスク**:
- [ ] リポジトリ戦略決定（Monorepo vs Polyrepo）
- [ ] CI/CDパイプライン構築
- [ ] 開発環境セットアップ
- [ ] デザインシステム抽出

```bash
# Monorepo構成例
npx create-nx-workspace my-app --preset=apps
cd my-app

# マイクロフロントエンド作成
nx generate @nrwl/react:app products
nx generate @nrwl/react:app checkout
nx generate @nrwl/react:app app-shell
```

#### Phase 2: アプリケーションシェル構築（Week 3-4）

**実装内容**:

```typescript
// app-shell/src/App.tsx
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { lazy, Suspense } from 'react';

// レガシーアプリケーション（iframe経由）
const LegacyApp = () => (
  <iframe
    src={process.env.LEGACY_URL}
    style={{ width: '100%', height: '100vh', border: 'none' }}
    title="Legacy App"
  />
);

// 新規マイクロフロントエンド
const Products = lazy(() => import('products/App'));

function AppShell() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Header />
        <Suspense fallback={<Loading />}>
          <Routes>
            {/* 新マイクロフロントエンド */}
            <Route path="/products/*" element={<Products />} />

            {/* レガシー（暫定） */}
            <Route path="*" element={<LegacyApp />} />
          </Routes>
        </Suspense>
        <Footer />
      </BrowserRouter>
    </AuthProvider>
  );
}
```

#### Phase 3: 最初のマイクロフロントエンド移行（Week 5-8）

**対象**: Products（トラフィック40%、独立性高）

**移行ステップ**:

1. **新規実装**: Productsマイクロフロントエンドを新規開発
2. **Feature Flag**: `/products?new=true` で新版にアクセス可能
3. **A/Bテスト**: 5% → 25% → 50% → 100%と段階的に移行
4. **レガシー削除**: 完全移行後にレガシーコード削除

**Feature Flag実装**:

```typescript
// app-shell/src/App.tsx
const shouldUseNewProducts = () => {
  const params = new URLSearchParams(window.location.search);
  const forceNew = params.get('new') === 'true';
  const rolloutPercentage = 50; // 50%のユーザーに新版を表示

  if (forceNew) return true;

  const userId = getUserId();
  const hash = simpleHash(userId);
  return (hash % 100) < rolloutPercentage;
};

<Route path="/products/*" element={
  shouldUseNewProducts() ? <Products /> : <LegacyProducts />
} />
```

#### Phase 4: 残りのマイクロフロントエンド移行（Week 9-24）

優先度順に段階的に移行します：

| Week | 対象 | 理由 |
|------|------|------|
| 9-12 | Checkout | 収益直結、独立性高 |
| 13-16 | Profile | 依存少、リスク低 |
| 17-20 | Cart | Checkout完了後に移行 |
| 21-24 | Home | 他ドメイン完了後（依存多） |

---

## 実装詳細

### アプリケーションシェルの責任範囲

**担当する機能**:

| 機能 | 実装場所 | 理由 |
|------|---------|------|
| **認証** | アプリケーションシェル | 全MFEで共通 |
| **ルーティング** | アプリケーションシェル | MFE間の切り替え |
| **共通UI（Header, Footer）** | アプリケーションシェル | 一貫性維持 |
| **エラーバウンダリ** | アプリケーションシェル | 障害の分離 |
| **ビジネスロジック** | 各マイクロフロントエンド | ドメイン固有 |

**実装例**:

```typescript
// app-shell/src/components/ErrorBoundary.tsx
import { Component, ReactNode } from 'react';

interface Props {
  children: ReactNode;
  fallback: (error: Error) => ReactNode;
}

interface State {
  error: Error | null;
}

export class ErrorBoundary extends Component<Props, State> {
  state: State = { error: null };

  static getDerivedStateFromError(error: Error): State {
    return { error };
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    // エラーログをSentryに送信
    Sentry.captureException(error, { extra: errorInfo });
  }

  render() {
    if (this.state.error) {
      return this.props.fallback(this.state.error);
    }
    return this.props.children;
  }
}

// 使用
<ErrorBoundary fallback={(error) => <ErrorPage error={error} />}>
  <Suspense fallback={<Loading />}>
    <Products />
  </Suspense>
</ErrorBoundary>
```

### 認証統合

**セッション管理の統一**:

```typescript
// app-shell/src/auth/AuthContext.tsx
import { createContext, useContext, useState, useEffect } from 'react';

interface User {
  id: string;
  name: string;
  email: string;
}

interface AuthContextType {
  user: User | null;
  login: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  token: string | null;
}

const AuthContext = createContext<AuthContextType>(null!);

export function AuthProvider({ children }) {
  const [user, setUser] = useState<User | null>(null);
  const [token, setToken] = useState<string | null>(null);

  // 初期化時にトークンを復元
  useEffect(() => {
    const storedToken = sessionStorage.getItem('auth_token');
    if (storedToken) {
      setToken(storedToken);
      fetchUser(storedToken).then(setUser);
    }
  }, []);

  const login = async (email: string, password: string) => {
    const response = await fetch('/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password }),
    });

    const { token, user } = await response.json();

    // トークンを永続化
    sessionStorage.setItem('auth_token', token);
    setToken(token);
    setUser(user);

    // 全MFEに認証状態を通知
    window.dispatchEvent(new CustomEvent('auth:login', { detail: { user } }));
  };

  const logout = async () => {
    await fetch('/api/auth/logout', { method: 'POST' });
    sessionStorage.removeItem('auth_token');
    setToken(null);
    setUser(null);

    window.dispatchEvent(new CustomEvent('auth:logout'));
  };

  return (
    <AuthContext.Provider value={{ user, login, logout, token }}>
      {children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => useContext(AuthContext);
```

**各マイクロフロントエンドでの使用**:

```typescript
// products/src/App.tsx
import { useAuth } from 'app-shell/auth';

function ProductsApp() {
  const { user, token } = useAuth();

  // 認証が必要なAPI呼び出し
  const fetchProducts = async () => {
    const response = await fetch('/api/products', {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    });
    return response.json();
  };

  return <div>Products for {user?.name}</div>;
}
```

### 依存関係管理

**Semantic Versioning（semver）戦略**:

```json
// design-system/package.json
{
  "name": "@my-app/design-system",
  "version": "1.2.3",
  "peerDependencies": {
    "react": "^18.0.0",
    "react-dom": "^18.0.0"
  }
}
```

**各マイクロフロントエンドでの使用**:

```json
// products/package.json
{
  "dependencies": {
    "@my-app/design-system": "^1.2.0",  // 1.2.x のみ許可
    "react": "^18.2.0"
  }
}
```

**Breaking Change時の移行期間**:

```
1. v2.0.0をリリース（Breaking Change）
2. 6ヶ月間 v1.x と v2.x を並行メンテナンス
3. 各MFEを段階的に v2.x に移行
4. 全MFE移行完了後、v1.x を廃止
```

### デザインシステム統合

**段階的な統合**:

```typescript
// design-system/src/Button/Button.tsx
export interface ButtonProps {
  variant?: 'primary' | 'secondary';
  size?: 'small' | 'medium' | 'large';
  onClick?: () => void;
  children: React.ReactNode;
}

export function Button({ variant = 'primary', size = 'medium', onClick, children }: ButtonProps) {
  return (
    <button
      className={`btn btn-${variant} btn-${size}`}
      onClick={onClick}
    >
      {children}
    </button>
  );
}
```

**レガシーコンポーネントのラップ**:

```typescript
// design-system/src/Button/LegacyButtonAdapter.tsx
import { OldButton } from 'legacy-ui-library';
import { Button, ButtonProps } from './Button';

export function LegacyButtonAdapter(props: ButtonProps) {
  // 新デザインシステムのプロパティをレガシー形式に変換
  return (
    <OldButton
      type={props.variant === 'primary' ? 'default' : 'ghost'}
      size={props.size}
      onClick={props.onClick}
    >
      {props.children}
    </OldButton>
  );
}
```

### カナリアリリースの実装

**トラフィック分割（NGINX）**:

```nginx
upstream products_v1 {
  server products-v1:3000;
}

upstream products_v2 {
  server products-v2:3000;
}

split_clients $request_id $products_version {
  95% v1;  # 95%は旧版
  5%  v2;  # 5%は新版（カナリア）
}

location /products {
  if ($products_version = "v1") {
    proxy_pass http://products_v1;
  }
  if ($products_version = "v2") {
    proxy_pass http://products_v2;
  }
}
```

**メトリクス監視**:

```typescript
// products-v2/src/monitoring.ts
import { onCLS, onFID, onLCP } from 'web-vitals';

function reportMetric(metric: Metric) {
  fetch('/api/metrics', {
    method: 'POST',
    body: JSON.stringify({
      name: metric.name,
      value: metric.value,
      version: 'v2',  // バージョンを明示
      mfe: 'products',
    }),
  });
}

onCLS(reportMetric);
onFID(reportMetric);
onLCP(reportMetric);
```

**自動ロールバック条件**:

| メトリクス | v1 | v2 閾値 | アクション |
|----------|----|---------|---------|
| **エラー率** | 0.1% | > 0.5% | 即座にロールバック |
| **LCP** | 2.0秒 | > 3.0秒 | 警告、30分後ロールバック |
| **コンバージョン率** | 5% | < 4% | 警告、調査 |

### ローカライゼーション

**メッセージ管理**:

```typescript
// app-shell/src/i18n/index.ts
import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';

i18n
  .use(initReactI18next)
  .init({
    resources: {
      ja: {
        common: {
          header: { title: 'マイアプリ' },
          footer: { copyright: '© 2024 My App' },
        },
      },
      en: {
        common: {
          header: { title: 'My App' },
          footer: { copyright: '© 2024 My App' },
        },
      },
    },
    lng: 'ja',
    fallbackLng: 'en',
    ns: ['common'],
  });

export default i18n;
```

**各マイクロフロントエンドで独自のメッセージ**:

```typescript
// products/src/i18n/ja.json
{
  "products": {
    "title": "商品一覧",
    "addToCart": "カートに追加",
    "outOfStock": "在庫切れ"
  }
}
```

```typescript
// products/src/index.tsx
import i18n from 'app-shell/i18n';
import productsJa from './i18n/ja.json';

i18n.addResourceBundle('ja', 'products', productsJa);

function ProductList() {
  const { t } = useTranslation('products');
  return <h1>{t('title')}</h1>;
}
```

---

## 組織設計

### Conway's Law の適用

**Conway's Law**: システムの構造は、それを設計する組織のコミュニケーション構造を反映する。

**適用方法**:
- チーム境界 = マイクロフロントエンド境界
- チームが完全所有（フロント + BFF + マイクロサービス）

### 機能チーム vs コンポーネントチーム

#### 機能チーム（Feature Team）

**定義**: ビジネスドメイン単位でフルスタック開発。

```
[Products Team]
├── Products MFE (React)
├── Products BFF (Node.js)
└── Products Service (Go)

[Checkout Team]
├── Checkout MFE (React)
├── Checkout BFF (Node.js)
└── Orders Service (Go)
```

**メリット**:
- ドメイン知識の集約
- エンドツーエンドの自律性
- 迅速な意思決定

**デメリット**:
- 技術スキルの重複（全チームがReact/Node/Go必要）
- 技術的な一貫性維持が困難

#### コンポーネントチーム（Component Team）

**定義**: 技術レイヤー単位で分業（非推奨）。

```
[Frontend Team]
├── Products MFE
├── Checkout MFE
└── Profile MFE

[Backend Team]
├── Products Service
├── Orders Service
└── Users Service
```

**デメリット**:
- チーム間の調整コスト高
- 責任の分散（障害時に誰の責任か不明確）
- デプロイの依存関係

#### 比較テーブル

| 観点 | 機能チーム | コンポーネントチーム |
|------|-----------|------------------|
| **自律性** | ★★★★★ | ★★ |
| **専門性** | ★★★ | ★★★★★ |
| **調整コスト** | ★★★★★（低） | ★★（高） |
| **デプロイ独立性** | ★★★★★ | ★★ |
| **技術一貫性** | ★★★ | ★★★★★ |
| **推奨度** | ★★★★★ | ★ |

**推奨**: 機能チーム。ただし、デザインシステムチーム（横断的）は別途設置。

---

## ガバナンスの実装

### RFC（Request for Comments）

**目的**: アーキテクチャ変更を提案し、チーム全体で議論するプロセス。

**テンプレート**:

```markdown
# RFC-001: Module Federationへの移行

## ステータス
提案中

## 概要
現在のiframe統合からModule Federationへ移行する。

## 背景
- iframe統合によるパフォーマンス問題
- Reactインスタンスの重複

## 提案内容
### 移行計画
1. Products MFEから段階的に移行
2. webpack 5 + Module Federation Plugin使用

### メリット
- Reactインスタンス共有によるバンドルサイズ削減
- パフォーマンス改善

### デメリット
- webpackへの依存
- 学習コスト

## 影響範囲
- 全マイクロフロントエンド
- ビルドパイプライン

## 代替案
- Web Components
- SSR Framework

## 決定事項
（議論後に記入）

## 関連リンク
- [Module Federation公式ドキュメント](https://webpack.js.org/concepts/module-federation/)
```

**プロセス**:

1. **提案**: RFCドキュメントを作成し、PRで提出
2. **議論**: 2週間のコメント期間
3. **決定**: アーキテクトチームが最終決定
4. **実装**: 承認後に実装開始

### ADR（Architecture Decision Records）

**目的**: 意思決定の記録と共有。

**テンプレート**:

```markdown
# ADR-005: カナリアリリースの採用

## ステータス
承認済み

## コンテキスト
新機能デプロイ時のリスク最小化が必要。

## 決定
カナリアリリースを標準デプロイ戦略とする。

## 根拠
- 段階的なリスク検証
- 本番データでの検証

## 結果
- 全マイクロフロントエンドでカナリアリリースを実装
- デプロイ時間は増加するが、ロールバック率は低下
```

**保管場所**: `docs/adr/` ディレクトリ

---

## コミュニケーションの流れを良くするテクニック

### 後方支援（Enabling Team）

**役割**: 各機能チームを技術的に支援する専門チーム。

**担当領域**:
- デザインシステムの開発・保守
- CI/CDパイプラインの構築
- 可観測性基盤の整備
- ベストプラクティスの共有

**構成**:
- デザインシステムエンジニア × 2
- DevOpsエンジニア × 2
- フロントエンドアーキテクト × 1

### 実践共同体（CoP: Community of Practice）

**目的**: 特定のトピックに関心のあるメンバーが集まり、知識を共有。

**例**:
- **Frontend CoP**: フロントエンド技術全般
- **Testing CoP**: テスト戦略、E2E
- **Performance CoP**: パフォーマンス最適化

**活動**:
- 月次ミーティング（1時間）
- Slackチャンネルでの情報共有
- 勉強会の開催

### タウンホール（全体ミーティング）

**頻度**: 月次

**アジェンダ**:
- 各チームの進捗共有
- 横断的な課題の議論
- RFCの最終決定
- ベストプラクティスの共有

---

## 導入判断：いつマイクロフロントエンドを使うべきか

### 使うべき状況

| 状況 | 理由 |
|------|------|
| **複数チーム（5+）が同一アプリ開発** | チーム間の独立性向上 |
| **異なる技術スタックを混在させたい** | 段階的な技術移行 |
| **デプロイ頻度がチームで異なる** | 独立したデプロイサイクル |
| **ドメイン境界が明確** | DDDによる自然な分割 |

### 使うべきでない状況

| 状況 | 理由 |
|------|------|
| **小規模チーム（< 5人）** | オーバーエンジニアリング |
| **シンプルなアプリケーション** | 複雑さが利益を上回る |
| **組織が準備不足** | Conway's Lawにより失敗 |
| **技術的負債が大きい** | まず技術的負債解消が先 |

---

## 成功の鍵

1. **段階的な移行**: 一度に全体を移行せず、段階的に実施
2. **組織設計の見直し**: Conway's Lawに従い、チーム境界を調整
3. **ガバナンスの確立**: RFC/ADRでアーキテクチャ決定を透明化
4. **可観測性の強化**: メトリクス収集とアラート設定
5. **継続的な改善**: 定期的な振り返りと改善

---

## 次のステップ

1. **現状分析**: トラフィック、機能境界、チーム構成の調査
2. **優先順位決定**: ビジネス価値と独立性から移行順序を決定
3. **PoC実施**: 最優先マイクロフロントエンドで小規模PoC
4. **組織設計**: 機能チームへの再編成
5. **段階的展開**: カナリアリリースで段階的に移行
