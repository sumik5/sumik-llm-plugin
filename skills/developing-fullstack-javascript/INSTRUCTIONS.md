# Full Stack JavaScript 開発ストラテジー

このスキルは、フルスタックJavaScript開発時にClaude Agentが参照すべき実践的ストラテジーをまとめています。

---

## 1. 使用タイミング

このスキルを参照すべき場面：

- **新規プロジェクト立ち上げ時**: アーキテクチャ判断、技術スタック選定
- **バックエンド設計**: API設計、データベーススキーマ設計、認証・認可実装
- **フロントエンド設計**: コンポーネント設計、状態管理戦略、データフェッチパターン
- **パフォーマンス最適化**: キャッシュ戦略、バンドルサイズ削減、レンダリング最適化
- **セキュリティ実装**: OWASP Top 10対策、認証・認可、入力バリデーション
- **テスト戦略策定**: テストピラミッド、テストカバレッジ、E2Eテスト
- **デプロイ・CI/CD構築**: Blue-Green/Canaryデプロイ、ロールバック戦略

---

## 2. コアプリンシプル（書籍の核心メッセージ）

### 2.1 コード規約を最初に確立

**チーム全員が同じ規約に従う。命名規則、ファイル構造、PRレビューテンプレートを初日に決める。**

- **命名規則**: camelCase（変数・関数）、PascalCase（クラス・コンポーネント）、UPPER_CASE（定数）
- **ファイル構造**: 機能ベース vs レイヤーベース（初日に決定）
- **コード整形**: ESLint + Prettier（設定を共有）
- **PRレビューテンプレート**: 変更内容、テスト、セキュリティチェック項目

```json
// .eslintrc.json 例
{
  "extends": ["airbnb", "plugin:@typescript-eslint/recommended"],
  "rules": {
    "no-console": "warn",
    "no-unused-vars": "error"
  }
}
```

### 2.2 ドキュメント駆動開発

**アーキテクチャ図、ADR（Architecture Decision Records）、変更ログを常に更新。**

- **ADR**: 重要な技術判断を記録（なぜReact Queryを選んだか、なぜマイクロサービスにしなかったか）
- **アーキテクチャ図**: Mermaid、C4モデルで可視化
- **変更ログ**: CHANGELOG.md（Conventional Commits形式）

```markdown
## ADR: TanStack Query導入

**日付**: 2026-02-07
**ステータス**: 採用

**コンテキスト**: データフェッチとキャッシュの管理が複雑化

**決定**: TanStack Query（React Query）を導入

**理由**:
- キャッシュ管理が自動化
- ステイル/フレッシュ判定が容易
- 楽観的更新のサポート

**結果**: API呼び出しが50%削減、UX向上
```

### 2.3 段階的改善

**最初から完璧を目指さない。MVP→パフォーマンス改善→スケーリングの順。**

1. **MVP（Minimum Viable Product）**: 最小限の機能で市場検証
2. **パフォーマンス改善**: プロファイリング、ボトルネック特定、最適化
3. **スケーリング**: 水平スケーリング、キャッシュ層追加、CDN導入

**過剰設計を避ける（YAGNI: You Aren't Gonna Need It）**

### 2.4 セキュリティファースト

**OWASP Top 10を常に意識。フロントエンドもバックエンドも。**

- **認証（AuthN）**: JWT、OAuth 2.0、MFA
- **認可（AuthZ）**: RBAC（Role-Based Access Control）
- **入力バリデーション**: フロントエンド + バックエンド両方で実施
- **機密情報管理**: 環境変数、シークレット管理サービス（AWS Secrets Manager等）

### 2.5 テストは実装と同時に書く

**後回しにしない。Red→Green→Refactorサイクル。**

- **テストファースト**: 失敗するテストを書く → 実装 → リファクタリング
- **テストピラミッド**: Unit（多）> Integration（中）> E2E（少）
- **カバレッジ目標**: ビジネスロジック100%、ユーティリティ100%

### 2.6 コミュニケーションが最重要

**技術的判断をProduct/Design/DevOpsチームと共有。**

- **定期的な技術共有会**: 週次、隔週でアーキテクチャレビュー
- **ドキュメント共有**: Notion、Confluence等で一元管理
- **非同期コミュニケーション**: Slackスレッド、GitHub Discussions活用

### 2.7 ユーザー確認の原則（AskUserQuestion）

**フルスタック開発では判断分岐が多い。曖昧さがある場合、推測で進めず必ずAskUserQuestionツールでユーザーに確認する。**

- **確認すべき場面**:
  - **アーキテクチャ判断**: モノリス vs マイクロサービス、BFF導入有無
  - **状態管理の選択**: useState vs Zustand vs 外部ライブラリ
  - **データフェッチパターンの選択**: SSR vs CSR vs ISR、GraphQL vs REST
  - **テスト戦略**: テスト範囲、E2Eの対象ページ・フロー
  - **デプロイ戦略**: Blue-Green vs Canary、ロールバック手順
  - **セキュリティ要件の確認**: 認証方式（JWT vs Session）、MFA要否
  - **パフォーマンス要件の確認**: ターゲットメトリクス（LCP、FID、CLS）

- **確認不要な場面**:
  - スキル内に明確な推奨がある場合（例: TanStack Query推奨、テストピラミッド比率）
  - ベストプラクティスが一義的に決まる場合（例: SQLインジェクション対策にプリペアドステートメント）
  - セキュリティ上の必須対策（例: パスワードハッシュ化、HTTPS強制）

**AskUserQuestion使用例:**

```python
AskUserQuestion(
    questions=[{
        "question": "このプロジェクトの状態管理方針を確認させてください。",
        "header": "状態管理の選択",
        "options": [
            {
                "label": "useState + useContext",
                "description": "小〜中規模向け。React標準APIのみで完結"
            },
            {
                "label": "Zustand",
                "description": "中〜大規模向け。軽量でボイラープレート少"
            },
            {
                "label": "Jotai",
                "description": "アトムベース。細粒度のリアクティビティが必要な場合"
            },
            {
                "label": "その他",
                "description": "別の状態管理ライブラリを使用（詳細を教えてください）"
            }
        ],
        "multiSelect": False
    }]
)
```

---

## 3. アーキテクチャ判断フロー（クイックリファレンス）

### 3.1 バックエンドアーキテクチャ: モノリス vs マイクロサービス

| 判断基準                 | モノリス推奨               | マイクロサービス推奨         |
|-------------------------|---------------------------|------------------------------|
| チームサイズ            | 1-10人                    | 10人以上                     |
| デプロイ頻度            | 週次〜月次                 | 日次〜複数回/日              |
| ドメイン境界の明確性    | 不明確                    | 明確                         |
| 技術スタックの統一性    | 統一されている            | 多様化が必要                 |
| 運用コスト              | 低                        | 高（Kubernetes、監視、ログ） |

**推奨**: 最初はモノリスで開始 → ドメイン境界が明確になったらマイクロサービス化

### 3.2 フロントエンドアーキテクチャ: コンポーネントベース、Atomic Design

**Atomic Design階層:**

```
Atoms（原子）: Button, Input, Label
  ↓
Molecules（分子）: SearchForm, UserCard
  ↓
Organisms（生命体）: Header, Sidebar
  ↓
Templates（テンプレート）: PageLayout
  ↓
Pages（ページ）: HomePage, DashboardPage
```

**ディレクトリ構造例:**

```
src/
├── components/
│   ├── atoms/        # Button, Input
│   ├── molecules/    # SearchForm, UserCard
│   ├── organisms/    # Header, Sidebar
│   ├── templates/    # PageLayout
│   └── pages/        # HomePage, DashboardPage
├── hooks/            # カスタムフック
├── services/         # API呼び出し
├── types/            # TypeScript型定義
└── utils/            # ユーティリティ関数
```

### 3.3 状態管理: useState → useReducer → useContext → 外部ライブラリ

**判断基準:**

| 状態の複雑度       | 推奨手法                     |
|-------------------|------------------------------|
| ローカル・単純    | `useState`                   |
| ローカル・複雑    | `useReducer`                 |
| グローバル・小規模 | `useContext` + `useReducer` |
| グローバル・大規模 | Zustand、Jotai、Recoil      |

**避けるべき**: Redux（オーバーキルになりやすい）

### 3.4 データフェッチ: TanStack Query推奨、Axios組み合わせ

**TanStack Query（React Query）を使う理由:**

- **自動キャッシュ**: 同じクエリキーのデータを再利用
- **ステイル/フレッシュ判定**: 自動的にデータを再フェッチ
- **楽観的更新**: UIを先に更新、バックエンド完了後に確定
- **ページネーション・無限スクロール**: 組み込みサポート

```tsx
import { useQuery } from '@tanstack/react-query';
import axios from 'axios';

const fetchUser = async (userId: string) => {
  const { data } = await axios.get(`/api/users/${userId}`);
  return data;
};

function UserProfile({ userId }: { userId: string }) {
  const { data, isLoading, error } = useQuery({
    queryKey: ['user', userId],
    queryFn: () => fetchUser(userId),
    staleTime: 5 * 60 * 1000, // 5分間フレッシュ
  });

  if (isLoading) return <div>Loading...</div>;
  if (error) return <div>Error: {error.message}</div>;

  return <div>{data.name}</div>;
}
```

### 3.5 テスト: テストピラミッド

**比率の目安:**

```
       E2E (5%)           ← Playwright
      /        \
 Integration (15%)       ← Testing Library
   /              \
  Unit (80%)              ← Vitest、Jest
```

- **Unit**: 関数、フック、ユーティリティ
- **Integration**: コンポーネント統合、API呼び出し
- **E2E**: ユーザーフロー（ログイン→購入→ログアウト）

### 3.6 キャッシュ: フロントエンド（React Query）+ バックエンド（Redis）

**フロントエンド（React Query）:**

```tsx
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5 * 60 * 1000, // 5分
      cacheTime: 10 * 60 * 1000, // 10分
    },
  },
});
```

**バックエンド（Redis）:**

```typescript
import { Cache } from 'cache-manager';
import { CACHE_MANAGER, Inject, Injectable } from '@nestjs/common';

@Injectable()
export class UserService {
  constructor(@Inject(CACHE_MANAGER) private cacheManager: Cache) {}

  async getUser(id: string) {
    const cached = await this.cacheManager.get<User>(`user:${id}`);
    if (cached) return cached;

    const user = await this.userRepository.findById(id);
    await this.cacheManager.set(`user:${id}`, user, { ttl: 300 }); // 5分
    return user;
  }
}
```

---

## 4. SOLID原則クイックリファレンス

### S: 単一責任の原則（Single Responsibility Principle）

**1クラス/関数 = 1責務**

```typescript
// ❌ 悪い例: 複数の責務を持つ
class UserService {
  saveUser(user: User) { /* DB保存 */ }
  sendWelcomeEmail(user: User) { /* メール送信 */ }
  validateUser(user: User) { /* バリデーション */ }
}

// ✅ 良い例: 責務を分離
class UserRepository {
  saveUser(user: User) { /* DB保存のみ */ }
}

class EmailService {
  sendWelcomeEmail(user: User) { /* メール送信のみ */ }
}

class UserValidator {
  validate(user: User): ValidationResult { /* バリデーションのみ */ }
}
```

### O: 開放閉鎖の原則（Open/Closed Principle）

**拡張に開く、修正に閉じる**

```typescript
// ❌ 悪い例: 新しい支払い方法を追加するたびに修正が必要
class PaymentProcessor {
  process(type: string, amount: number) {
    if (type === 'credit') { /* クレカ処理 */ }
    else if (type === 'paypal') { /* PayPal処理 */ }
    // 新しい方法を追加するたびにif文が増える
  }
}

// ✅ 良い例: インターフェースで拡張可能に
interface PaymentMethod {
  process(amount: number): Promise<void>;
}

class CreditCardPayment implements PaymentMethod {
  async process(amount: number) { /* クレカ処理 */ }
}

class PayPalPayment implements PaymentMethod {
  async process(amount: number) { /* PayPal処理 */ }
}

class PaymentProcessor {
  constructor(private method: PaymentMethod) {}
  async process(amount: number) {
    await this.method.process(amount);
  }
}
```

### L: リスコフ置換の原則（Liskov Substitution Principle）

**派生クラスは基底クラスと置換可能**

```typescript
// ✅ 良い例: 基底クラスと派生クラスで動作が一貫
abstract class Bird {
  abstract makeSound(): string;
}

class Sparrow extends Bird {
  makeSound() { return 'chirp'; }
}

class Crow extends Bird {
  makeSound() { return 'caw'; }
}

function letBirdSpeak(bird: Bird) {
  console.log(bird.makeSound()); // どのBirdでも動作する
}
```

### I: インターフェース分離の原則（Interface Segregation Principle）

**必要なメソッドのみを持つインターフェース**

```typescript
// ❌ 悪い例: 不要なメソッドを強制
interface Worker {
  work(): void;
  eat(): void;
}

class Robot implements Worker {
  work() { /* 作業 */ }
  eat() { throw new Error('ロボットは食べません'); } // 不要
}

// ✅ 良い例: インターフェースを分離
interface Workable {
  work(): void;
}

interface Eatable {
  eat(): void;
}

class Robot implements Workable {
  work() { /* 作業 */ }
}

class Human implements Workable, Eatable {
  work() { /* 作業 */ }
  eat() { /* 食事 */ }
}
```

### D: 依存関係逆転の原則（Dependency Inversion Principle）

**抽象に依存する**

```typescript
// ❌ 悪い例: 具象クラスに依存
class MySQLDatabase {
  query(sql: string) { /* MySQL固有の実装 */ }
}

class UserService {
  private db = new MySQLDatabase(); // 具象に依存
  getUser(id: string) {
    return this.db.query(`SELECT * FROM users WHERE id = ${id}`);
  }
}

// ✅ 良い例: 抽象に依存
interface Database {
  query(sql: string): Promise<unknown>;
}

class MySQLDatabase implements Database {
  async query(sql: string) { /* MySQL実装 */ }
}

class UserService {
  constructor(private db: Database) {} // 抽象に依存
  async getUser(id: string) {
    return this.db.query(`SELECT * FROM users WHERE id = ${id}`);
  }
}
```

### その他の重要原則

- **DRY（Don't Repeat Yourself）**: 同じコードを繰り返さない
- **YAGNI（You Aren't Gonna Need It）**: 今必要ないものは実装しない
- **KISS（Keep It Simple, Stupid）**: シンプルに保つ

---

## 5. セキュリティクイックリファレンス

### 5.1 認証（Authentication）vs 認可（Authorization）

- **認証（AuthN）**: ユーザーが誰かを確認（ログイン）
- **認可（AuthZ）**: ユーザーが何をできるかを確認（権限チェック）

### 5.2 認証手法

| 手法                | 説明                               | 用途                     |
|--------------------|------------------------------------|--------------------------|
| **パスワード**     | bcrypt、Argon2でハッシュ化         | 基本的な認証             |
| **MFA（多要素認証）** | TOTP（Google Authenticator等）     | セキュリティ強化         |
| **OAuth 2.0**      | Google、GitHub等でログイン         | ソーシャルログイン       |
| **OTP（ワンタイム）** | メール・SMS送信                    | パスワードリセット       |

**パスワードハッシュ例:**

```typescript
import * as bcrypt from 'bcrypt';

async function hashPassword(password: string): Promise<string> {
  const saltRounds = 10;
  return bcrypt.hash(password, saltRounds);
}

async function verifyPassword(password: string, hash: string): Promise<boolean> {
  return bcrypt.compare(password, hash);
}
```

### 5.3 認可手法

| 手法   | 説明                                       | 用途                     |
|--------|--------------------------------------------|--------------------------|
| **RBAC** | Role-Based Access Control（ロールベース） | 一般的な権限管理         |
| **ABAC** | Attribute-Based Access Control（属性ベース）| 細かい権限制御          |
| **PBAC** | Policy-Based Access Control（ポリシーベース）| エンタープライズ向け    |

**RBAC例:**

```typescript
enum Role {
  Admin = 'admin',
  Editor = 'editor',
  Viewer = 'viewer',
}

const permissions = {
  [Role.Admin]: ['read', 'write', 'delete'],
  [Role.Editor]: ['read', 'write'],
  [Role.Viewer]: ['read'],
};

function hasPermission(role: Role, action: string): boolean {
  return permissions[role].includes(action);
}
```

### 5.4 OWASP Top 10対策

| 脅威                           | 対策                                                     |
|--------------------------------|----------------------------------------------------------|
| **1. 認証の不備**              | MFA、強力なパスワードポリシー、セッションタイムアウト    |
| **2. 暗号化の失敗**            | HTTPS必須、機密情報の暗号化（AES-256）                   |
| **3. インジェクション**         | プリペアドステートメント、入力バリデーション            |
| **4. 安全でない設計**          | セキュリティレビュー、脅威モデリング                    |
| **5. セキュリティ設定ミス**    | デフォルト設定の変更、不要な機能の無効化                |
| **6. 脆弱なコンポーネント**    | 依存関係の定期更新（npm audit）                          |
| **7. 認証・認可の失敗**        | JWT検証、RBAC実装                                        |
| **8. データ整合性の失敗**      | チェックサム、署名検証                                  |
| **9. ログ・監視の不備**        | エラーログ記録、異常検知アラート                        |
| **10. SSRF（Server-Side Request Forgery）** | URL検証、内部IPへのアクセス制限 |

### 5.5 フロントエンドセキュリティ

**XSS（Cross-Site Scripting）対策:**

```tsx
// ❌ 危険: innerHTML使用は避ける
// 必要な場合は必ずDOMPurifyでサニタイズ

// ✅ 安全: Reactがエスケープしてくれる
<div>{userInput}</div>

// ✅ HTMLレンダリングが必要な場合: DOMPurify使用
import DOMPurify from 'dompurify';
const sanitizedHtml = DOMPurify.sanitize(userInput);
// sanitizedHtmlを使用
```

**CSRF（Cross-Site Request Forgery）対策:**

```typescript
// バックエンドでCSRFトークン生成
import { csurf } from 'csurf';
app.use(csurf({ cookie: true }));

// フロントエンドでトークンを送信
axios.post('/api/data', data, {
  headers: { 'X-CSRF-Token': csrfToken },
});
```

### 5.6 バックエンドセキュリティ

**SQLインジェクション対策:**

```typescript
// ❌ 危険: 生のSQL
const query = `SELECT * FROM users WHERE id = ${userId}`;

// ✅ 安全: プリペアドステートメント
const query = 'SELECT * FROM users WHERE id = ?';
db.query(query, [userId]);
```

**機密情報管理:**

```typescript
// ✅ 環境変数から読み込む
const dbPassword = process.env.DB_PASSWORD;

// ✅ .envファイルは.gitignoreに追加
// .gitignore:
// .env
// .env.local
```

---

## 6. 詳細ガイドへのナビゲーション

このSKILL.mdはクイックリファレンスです。詳細な実装ガイドは以下を参照してください：

- **[バックエンド戦略](./references/BACKEND-STRATEGIES.md)**: NestJS/Express、API設計、データベース、キャッシュ、認証・認可
- **[フロントエンド戦略](./references/FRONTEND-STRATEGIES.md)**: React、コンポーネント設計、状態管理、データフェッチ、パフォーマンス最適化
- **[デプロイ戦略](./references/DEPLOYMENT-STRATEGIES.md)**: CI/CD、Blue-Green/Canaryデプロイ、ロールバック、監視・ログ
- **[品質チェックリスト](./references/QUALITY-CHECKLIST.md)**: テスト、セキュリティ、パフォーマンス、デバッグの実践チェックリスト

---

## 7. まとめ

このスキルはフルスタックJavaScript開発の全体像を提供します。**段階的に改善すること**を忘れず、以下の優先順位で進めてください：

1. **コード規約・ドキュメント整備**（初日）
2. **セキュリティ基盤構築**（認証・認可、入力バリデーション）
3. **テストファースト開発**（Red→Green→Refactor）
4. **パフォーマンス最適化**（キャッシュ、バンドルサイズ削減）
5. **スケーリング**（必要になったタイミングで）

**最重要原則**: **コミュニケーションとドキュメント**がすべての基盤です。技術的判断を記録し、チームと共有してください。
