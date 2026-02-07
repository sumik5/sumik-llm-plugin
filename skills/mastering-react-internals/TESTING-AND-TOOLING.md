# テスト・CSS・フレームワーク選定ガイド

Reactプロジェクトにおけるテスト戦略、CSS手法の選定、フレームワーク選定、開発ツールチェーンについて解説します。

---

## 1. Reactテスト戦略

### AAAパターン（必須）

すべてのテストは以下の3段階で構成します。

```typescript
test("カウンターがクリックで増加する", async () => {
  // Arrange: テストの準備（レンダリング、モック設定等）
  render(<Counter />);

  // Act: 操作の実行（ユーザー操作のシミュレーション）
  const user = userEvent.setup();
  const increment = screen.getByRole("button", { name: "Increment" });
  await user.click(increment);

  // Assert: 結果の検証（期待値と実際の値の比較）
  const heading = screen.getByRole("heading", { name: "Counter: 1" });
  expect(heading).toBeInTheDocument();
});
```

**変数名規則:**
- `actual`: 実際の値
- `expected`: 期待値
- `expect(actual).toBe(expected)` の順序を厳守

```typescript
test("合計金額が正しく計算される", () => {
  // Arrange
  const items = [
    { id: "1", price: 100 },
    { id: "2", price: 200 },
  ];

  // Act
  const actual = calculateTotal(items);

  // Assert
  const expected = 300;
  expect(actual).toBe(expected);
});
```

### 要素クエリ優先順位（必須）

React Testing Libraryでは、以下の優先順位でクエリを使用します。

**1. getByRole（最優先）**

```typescript
// ボタン
const submitButton = screen.getByRole("button", { name: "送信" });
const submitButton2 = screen.getByRole("button", { name: /送信/i }); // 正規表現

// 見出し
const heading = screen.getByRole("heading", { name: "タイトル" });
const h2Heading = screen.getByRole("heading", { level: 2, name: "サブタイトル" });

// リンク
const link = screen.getByRole("link", { name: "ホームへ戻る" });

// テキストボックス（input type="text", textarea等）
const input = screen.getByRole("textbox", { name: "ユーザー名" });

// チェックボックス
const checkbox = screen.getByRole("checkbox", { name: "利用規約に同意する" });

// ラジオボタン
const radio = screen.getByRole("radio", { name: "オプションA" });

// リスト
const list = screen.getByRole("list");
const listItems = screen.getAllByRole("listitem");
```

**2. getByLabelText（フォーム要素）**

```typescript
// label要素と関連付けられたinput
const emailInput = screen.getByLabelText("メールアドレス");
const passwordInput = screen.getByLabelText(/パスワード/i);
```

**3. getByPlaceholderText**

```typescript
const searchInput = screen.getByPlaceholderText("キーワードを入力");
```

**4. getByText**

```typescript
// 通常のテキスト
const text = screen.getByText("こんにちは");

// 部分一致
const partialText = screen.getByText(/こんにちは/, { exact: false });

// 特定の要素のみ
const paragraph = screen.getByText("こんにちは", { selector: "p" });
```

**5. getByTestId（最終手段）**

```typescript
// アイコンやデコレーション要素など、他の方法で取得できない場合のみ
const icon = screen.getByTestId("user-icon");
```

**クエリの種類:**
- `getBy*`: 要素が見つからない場合エラー（単一要素）
- `queryBy*`: 要素が見つからない場合null（単一要素、存在しないことの検証用）
- `findBy*`: 非同期で要素を待機（単一要素、Promise返却）
- `getAllBy*`: 複数要素（配列）
- `queryAllBy*`: 複数要素（配列、空配列の場合あり）
- `findAllBy*`: 非同期で複数要素待機

### user-event（必須）

**fireEventではなくuser-eventを使用します**（実際のユーザー操作に近い動作を再現）。

```typescript
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

test("フォーム入力とクリック", async () => {
  render(<LoginForm />);

  const user = userEvent.setup();

  // テキスト入力
  const emailInput = screen.getByLabelText("メールアドレス");
  await user.type(emailInput, "test@example.com");

  // クリック
  const submitButton = screen.getByRole("button", { name: "ログイン" });
  await user.click(submitButton);

  // 結果の検証
  const successMessage = await screen.findByText("ログインに成功しました");
  expect(successMessage).toBeInTheDocument();
});
```

**主な操作:**

```typescript
const user = userEvent.setup();

// クリック
await user.click(element);
await user.dblClick(element);

// キーボード入力
await user.type(input, "テキスト");
await user.clear(input); // クリア
await user.keyboard("{Enter}"); // 特殊キー
await user.keyboard("{Shift>}A{/Shift}"); // Shift+A

// 選択
await user.selectOptions(select, "option1");
await user.selectOptions(select, ["option1", "option2"]); // 複数選択

// チェックボックス・ラジオ
await user.click(checkbox); // トグル
```

### コールバックテスト（モック）

```typescript
import { vi } from "vitest";

test("削除コールバックが正しい引数で呼ばれる", async () => {
  // Arrange
  const items = [
    { id: "1", name: "Item A" },
    { id: "2", name: "Item B" },
  ];
  const mockDelete = vi.fn();
  render(<ItemList items={items} onDelete={mockDelete} />);

  // Act
  const user = userEvent.setup();
  const deleteButton = screen.getByRole("button", { name: "Delete 'Item B'" });
  await user.click(deleteButton);

  // Assert
  expect(mockDelete).toHaveBeenCalledTimes(1);
  expect(mockDelete).toHaveBeenCalledWith("2");
});

test("フォーム送信時にonSubmitが正しいデータで呼ばれる", async () => {
  // Arrange
  const mockSubmit = vi.fn();
  render(<UserForm onSubmit={mockSubmit} />);

  // Act
  const user = userEvent.setup();
  await user.type(screen.getByLabelText("名前"), "Alice");
  await user.type(screen.getByLabelText("メール"), "alice@example.com");
  await user.click(screen.getByRole("button", { name: "送信" }));

  // Assert
  const expected = { name: "Alice", email: "alice@example.com" };
  expect(mockSubmit).toHaveBeenCalledWith(expected);
});
```

### テストの耐久性（実装詳細に依存しない）

**❌ 悪い例（脆いテスト）:**

```typescript
// クラス名に依存
const button = container.querySelector(".btn-primary");

// DOM構造に依存
const text = container.querySelector("div > span > p");

// data属性に依存（getByTestId以外）
const element = container.querySelector("[data-custom='value']");
```

**✅ 良い例（耐久性の高いテスト）:**

```typescript
// ロール + アクセシブルネームで取得
const button = screen.getByRole("button", { name: "送信" });

// 意味のあるテキストで取得
const message = screen.getByText("登録が完了しました");

// ラベルで取得（フォーム）
const input = screen.getByLabelText("ユーザー名");
```

**アイコンボタンのテスト:**

```typescript
// アイコンのみのボタン → aria-labelで取得可能にする
<button aria-label="お気に入りに追加">
  <HeartIcon />
</button>

// テスト
const favoriteButton = screen.getByRole("button", { name: "お気に入りに追加" });
```

### モック戦略

**ブラウザAPIモック:**

```typescript
test("クリップボードにコピーする", async () => {
  // Arrange
  const mockWriteText = vi.fn();
  Object.assign(navigator, {
    clipboard: {
      writeText: mockWriteText,
    },
  });

  render(<CopyButton text="Hello" />);

  // Act
  const user = userEvent.setup();
  await user.click(screen.getByRole("button", { name: "コピー" }));

  // Assert
  expect(mockWriteText).toHaveBeenCalledWith("Hello");
});
```

**ライブラリモック:**

```typescript
// 例: date-fnsのモック
vi.mock("date-fns", () => ({
  format: vi.fn((date, formatStr) => "2025-01-01"),
}));

test("日付が正しくフォーマットされる", () => {
  render(<DateDisplay date={new Date()} />);
  expect(screen.getByText("2025-01-01")).toBeInTheDocument();
});
```

**Contextモック:**

```typescript
test("ログイン状態でユーザー名を表示", () => {
  // Arrange
  const mockContextValue = {
    user: { id: "1", name: "Alice" },
    isAuthenticated: true,
  };

  render(
    <AuthContext.Provider value={mockContextValue}>
      <Header />
    </AuthContext.Provider>
  );

  // Assert
  expect(screen.getByText("Alice")).toBeInTheDocument();
});
```

### 非同期処理のテスト

```typescript
test("データ取得後にリストを表示", async () => {
  // Arrange
  global.fetch = vi.fn(() =>
    Promise.resolve({
      json: () => Promise.resolve([{ id: "1", name: "Item 1" }]),
    })
  ) as any;

  render(<ItemList />);

  // Act & Assert
  // findByで非同期に要素が現れるまで待機（デフォルト1秒タイムアウト）
  const item = await screen.findByText("Item 1");
  expect(item).toBeInTheDocument();
});

test("ローディング状態の表示", () => {
  render(<AsyncComponent />);

  // 初期状態でローディング表示
  expect(screen.getByText("読み込み中...")).toBeInTheDocument();

  // データ取得後にローディングが消える
  await waitFor(() => {
    expect(screen.queryByText("読み込み中...")).not.toBeInTheDocument();
  });
});
```

---

## 2. CSS手法選定ガイド

### 比較表

| 手法 | 特異性制御 | 衝突リスク | DX | バンドルサイズ | パフォーマンス | 学習コスト |
|------|----------|----------|-----|-------------|-------------|----------|
| CSSファイル+クラス名 | 中 | 高 | 中 | 中 | 優秀 | 低 |
| CSS Modules | 中 | なし | 良好 | 中 | 優秀 | 低 |
| styled-components | 高 | なし | 優秀 | 大 | 中 | 中 |
| Tailwind CSS | 高 | 低 | 良好 | 大* | 優秀 | 中 |

*Tailwind CSSはPurgeCSS等で最適化可能

### 1. CSSファイル + クラス名（従来型）

```css
/* Button.css */
.button {
  padding: 8px 16px;
  border: none;
  border-radius: 4px;
  cursor: pointer;
}

.button-primary {
  background-color: blue;
  color: white;
}

.button-secondary {
  background-color: gray;
  color: white;
}
```

```tsx
// Button.tsx
import "./Button.css";

function Button({ variant = "primary", children }) {
  return <button className={`button button-${variant}`}>{children}</button>;
}
```

**メリット:**
- シンプル、既存知識で開発可能
- バンドルサイズが小さい

**デメリット:**
- グローバルスコープによる衝突リスク
- クラス名の命名規則（BEM等）が必要

### 2. CSS Modules

```css
/* Button.module.css */
.button {
  padding: 8px 16px;
  border: none;
  border-radius: 4px;
  cursor: pointer;
}

.primary {
  background-color: blue;
  color: white;
}

.secondary {
  background-color: gray;
  color: white;
}
```

```tsx
// Button.tsx
import styles from "./Button.module.css";

function Button({ variant = "primary", children }) {
  return (
    <button className={`${styles.button} ${styles[variant]}`}>
      {children}
    </button>
  );
}
```

**メリット:**
- スコープの自動隔離（クラス名が自動生成される）
- 標準的なCSS記法
- サーバーサイドレンダリング対応

**デメリット:**
- クラス名の結合が煩雑（`classnames`ライブラリ推奨）
- 動的スタイリングがやや不便

### 3. styled-components（CSS-in-JS）

```tsx
import styled from "styled-components";

const StyledButton = styled.button<{ variant: "primary" | "secondary" }>`
  padding: 8px 16px;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  background-color: ${(props) =>
    props.variant === "primary" ? "blue" : "gray"};
  color: white;

  &:hover {
    opacity: 0.8;
  }
`;

function Button({ variant = "primary", children }) {
  return <StyledButton variant={variant}>{children}</StyledButton>;
}
```

**メリット:**
- コンポーネント内でスタイル完結
- propsによる動的スタイリングが容易
- 自動ベンダープレフィックス

**デメリット:**
- ランタイムオーバーヘッド（スタイル生成）
- バンドルサイズ増加
- サーバーサイドレンダリング設定が複雑

### 4. Tailwind CSS（ユーティリティファースト）

```tsx
function Button({ variant = "primary", children }) {
  const baseClasses = "px-4 py-2 rounded cursor-pointer border-none";
  const variantClasses =
    variant === "primary"
      ? "bg-blue-500 text-white hover:bg-blue-600"
      : "bg-gray-500 text-white hover:bg-gray-600";

  return <button className={`${baseClasses} ${variantClasses}`}>{children}</button>;
}
```

**メリット:**
- 高速プロトタイピング
- デザインシステムの一貫性
- PurgeCSSで未使用クラスを削除可能

**デメリット:**
- HTMLが冗長になる
- カスタムデザインの学習コスト
- 初期バンドルサイズが大きい（最適化必須）

### 選定基準

**CSS Modules推奨:**
- サーバーサイドレンダリング重視
- バンドルサイズを最小化したい
- 従来のCSS記法を維持したい
- Next.js、Remix等のフレームワーク使用時

**styled-components推奨:**
- DX（開発者体験）最重視
- 動的スタイリングが多い（テーマ、状態による変化）
- コンポーネント単位の完全なカプセル化が必要

**Tailwind CSS推奨:**
- 高速プロトタイピング
- デザインシステムの統一が重要
- レスポンシブデザインを多用

**CSSファイル推奨:**
- レガシープロジェクトとの統合
- シンプルなサイト（複雑な状態管理なし）

### ユーザー確認が必要な場合

CSS手法の選択は**プロジェクト・チームの慣習に大きく依存**するため、以下の場合はAskUserQuestionで確認してください。

```typescript
AskUserQuestion({
  questions: [{
    question: "CSS手法を選択してください",
    header: "スタイリング",
    options: [
      {
        label: "CSS Modules",
        description: "スコープ自動隔離、SSR対応、標準的CSS記法"
      },
      {
        label: "styled-components",
        description: "DX優秀、動的スタイリング容易、コンポーネント内完結"
      },
      {
        label: "Tailwind CSS",
        description: "高速開発、デザインシステム統一、ユーティリティクラス"
      },
      {
        label: "CSSファイル",
        description: "シンプル、レガシー統合、学習コスト低"
      }
    ],
    multiSelect: false
  }]
})
```

---

## 3. Reactフレームワーク選定

### 比較表

| フレームワーク | SSR | SSG | ルーティング | データ取得 | デプロイ | 学習曲線 | 推奨用途 |
|-------------|-----|-----|-----------|----------|---------|---------|---------|
| **Next.js** | ✅ | ✅ | ファイルベース | Server Components, API Routes | Vercel最適化 | 中 | フルスタックWebアプリ |
| **Remix** | ✅ | ✅ | ネスト型 | loader/action | 自由（任意プラットフォーム） | 中 | データ駆動アプリ |
| **Vite + React** | ❌ | ❌ | React Router（手動） | クライアント（fetch/axios） | 静的ホスティング | 低 | SPA |
| **Astro** | ✅ | ✅ | ファイルベース | アイランドアーキテクチャ | 静的ホスティング | 低 | コンテンツサイト |

### Next.js（最も人気）

**特徴:**
- App Router（React Server Components対応）
- ファイルベースルーティング
- API Routes（バックエンド統合）
- 画像最適化（next/image）
- Vercelでのシームレスなデプロイ

```tsx
// app/page.tsx
export default async function Page() {
  const data = await fetch("https://api.example.com/data");
  const items = await data.json();

  return (
    <div>
      <h1>Items</h1>
      <ul>
        {items.map((item) => (
          <li key={item.id}>{item.name}</li>
        ))}
      </ul>
    </div>
  );
}
```

**推奨ケース:**
- フルスタックWebアプリ
- SEOが重要（ブログ、EC、コーポレートサイト）
- Vercelへのデプロイ
- 画像最適化が必要

### Remix

**特徴:**
- Web標準（FormData、Response等）重視
- ネスト型ルーティング
- loader（データ取得）/ action（データ変更）パターン
- エラーバウンダリの組み込み

```tsx
// app/routes/items.$id.tsx
import { json, type LoaderFunctionArgs } from "@remix-run/node";
import { useLoaderData } from "@remix-run/react";

export async function loader({ params }: LoaderFunctionArgs) {
  const item = await fetchItem(params.id);
  return json({ item });
}

export default function ItemPage() {
  const { item } = useLoaderData<typeof loader>();
  return <div>{item.name}</div>;
}
```

**推奨ケース:**
- データ駆動型アプリ（管理画面、ダッシュボード）
- フォーム処理が多い
- Web標準APIを重視
- 任意のホスティングプラットフォーム（Vercel以外）

### Vite + React（SPA）

**特徴:**
- 高速なHMR（Hot Module Replacement）
- シンプルな設定
- React Router手動設定
- クライアントサイドレンダリングのみ

```tsx
// main.tsx
import { createBrowserRouter, RouterProvider } from "react-router-dom";

const router = createBrowserRouter([
  {
    path: "/",
    element: <HomePage />,
  },
  {
    path: "/items/:id",
    element: <ItemPage />,
  },
]);

ReactDOM.createRoot(document.getElementById("root")!).render(
  <RouterProvider router={router} />
);
```

**推奨ケース:**
- SPA（Single Page Application）
- SEO不要（社内ツール、管理画面）
- 静的ホスティング（S3、Netlify等）
- 学習用・プロトタイプ

### Astro

**特徴:**
- アイランドアーキテクチャ（必要な部分のみJavaScript）
- 静的サイト生成特化
- React以外のフレームワークと混在可能
- 超高速（JavaScriptが最小限）

```astro
---
// src/pages/index.astro
const items = await fetch("https://api.example.com/items").then(r => r.json());
---

<html>
  <body>
    <h1>Items</h1>
    <ul>
      {items.map(item => <li>{item.name}</li>)}
    </ul>
    <!-- Reactコンポーネントは必要な部分のみ -->
    <Counter client:load />
  </body>
</html>
```

**推奨ケース:**
- コンテンツサイト（ブログ、ドキュメントサイト）
- 静的サイト生成重視
- パフォーマンス最優先
- JavaScriptを最小限にしたい

### SSR/Hydrationの仕組み

**Server-Side Rendering (SSR):**
1. サーバーでReactコンポーネントをHTMLに変換
2. HTMLをクライアントに送信
3. ブラウザがHTMLを即座に表示（高速な初期表示）

**Hydration:**
1. ブラウザがJavaScriptをダウンロード
2. 既存のHTML要素にReactのイベントリスナーを付与
3. インタラクティブなUIに変換

**メリット:**
- SEO最適化（検索エンジンがHTMLを読める）
- 初期表示が高速（HTMLが先に表示される）

**デメリット:**
- サーバー側のコスト増
- Hydrationミスマッチのリスク

### ユーザー確認が必要な場合

フレームワーク選択は**要件に大きく依存**するため、不明な場合はAskUserQuestionで確認してください。

```typescript
AskUserQuestion({
  questions: [{
    question: "プロジェクトの要件を選択してください（複数選択可）",
    header: "フレームワーク選定",
    options: [
      {
        label: "SEOが重要",
        description: "検索エンジン最適化が必須（Next.js/Remix/Astro推奨）"
      },
      {
        label: "高速な初期表示",
        description: "ユーザーが即座にコンテンツを見る必要がある（SSR/SSG推奨）"
      },
      {
        label: "SPAで十分",
        description: "社内ツール、SEO不要（Vite + React推奨）"
      },
      {
        label: "フルスタック開発",
        description: "API統合、バックエンドも同じコードベース（Next.js推奨）"
      },
      {
        label: "静的サイト",
        description: "ブログ、ドキュメント、コンテンツサイト（Astro推奨）"
      },
      {
        label: "データ駆動型",
        description: "フォーム処理多用、管理画面（Remix推奨）"
      }
    ],
    multiSelect: true
  }]
})
```

---

## 4. 開発ツールチェーン

### ESLint（必須）

**eslint-plugin-react-hooks必須:**

```json
{
  "extends": [
    "eslint:recommended",
    "plugin:react/recommended",
    "plugin:react-hooks/recommended"
  ],
  "rules": {
    "react-hooks/rules-of-hooks": "error",
    "react-hooks/exhaustive-deps": "warn"
  }
}
```

**主要ルール:**
- `rules-of-hooks`: フックの呼び出しルール違反を検出
- `exhaustive-deps`: useEffectの依存配列の過不足を警告

### Prettier（推奨）

```json
{
  "semi": true,
  "singleQuote": false,
  "tabWidth": 2,
  "trailingComma": "es5",
  "printWidth": 80
}
```

**ESLintとの併用:**
```bash
npm install -D eslint-config-prettier
```

```json
{
  "extends": [
    "eslint:recommended",
    "plugin:react/recommended",
    "prettier" // 最後に配置してESLintのフォーマットルールを無効化
  ]
}
```

### React Developer Tools

**Components Inspector:**
- コンポーネント階層の可視化
- Props/Stateのリアルタイム表示
- コンポーネントの編集（値の変更）

**Profiler:**
- レンダリングパフォーマンスの計測
- コンポーネントのレンダリング時間
- レンダリング原因の特定

**使用方法:**
1. Chrome/Firefoxの拡張機能をインストール
2. DevToolsで「Components」「Profiler」タブを開く
3. コンポーネントを選択してProps/Stateを確認

### TypeScript（推奨設定）

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ESNext",
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "jsx": "react-jsx",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true
  },
  "include": ["src"],
  "exclude": ["node_modules"]
}
```

---

## 5. ユーザー確認の原則

### 確認すべき場面

以下の選択は**プロジェクト・チーム・要件に大きく依存**するため、必ずAskUserQuestionで確認してください。

1. **CSS手法の選択**
   - プロジェクトの既存スタイル
   - チームの慣習
   - バンドルサイズ vs DX

2. **フレームワーク選択**
   - SEO要件
   - SSR/SSGの必要性
   - ホスティングプラットフォーム

3. **テストカバレッジ目標**
   - ビジネスロジック100%
   - UIコンポーネント: 80%以上
   - ユーティリティ関数: 100%

### 確認不要な場面（業界標準）

以下は業界のベストプラクティスであり、ユーザー確認不要です。

1. **AAAパターンの採用**
   - すべてのテストでArrange → Act → Assertを使用

2. **getByRoleの優先使用**
   - React Testing Library推奨のクエリ優先順位

3. **user-eventの使用**
   - fireEventではなくuser-eventを使用

4. **ESLint + Prettierの導入**
   - eslint-plugin-react-hooks必須

5. **actual/expected変数名**
   - テストの可読性向上のための標準パターン
