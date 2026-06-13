# テスト・ツール・スタイリング戦略

Reactアプリケーションのテスト手法、開発ツールチェーン、CSS手法の選定基準について解説します。

---

## 1. React開発ツールチェーン

### 1.1 ESLint（Linter）

#### ESLintの役割

- コードの静的解析によるエラー検出
- チーム全体のコーディング規約の自動適用
- 300以上のルールで構成、カスタマイズ可能

#### 主要ルール設定

```json
{
  "extends": [
    "eslint:recommended",
    "plugin:react/recommended",
    "plugin:react-hooks/recommended"
  ],
  "rules": {
    "semi": ["error", "always"],
    "quotes": ["error", "double"],
    "react-hooks/rules-of-hooks": "error",
    "react-hooks/exhaustive-deps": "warn"
  }
}
```

**react-hooks関連ルール（必須）:**
- `rules-of-hooks`: フックのルール違反を検出
- `exhaustive-deps`: useEffectの依存配列の過不足を警告

#### セットアップ

```bash
# 初期化
npm init @eslint/config

# エディタ統合
# VS Code、VIM、Emacsなど主要エディタで利用可能
```

### 1.2 Prettier（Formatter）

#### Prettierの特徴

- **Opinionatedな自動フォーマッター** - ディスカッション不要の統一フォーマット
- コンテキストに応じた動的なフォーマット決定
- 全チームで共通のコードスタイルを実現

#### 基本設定

```json
{
  "semi": true,
  "singleQuote": false,
  "tabWidth": 2,
  "trailingComma": "es5",
  "printWidth": 80
}
```

#### 動的フォーマッティング例

```typescript
// シンプルな例 → 1行
const someCars = cars.filter((car) => car.make === "Fiat");

// 複雑な例 → 自動で複数行に
const someCars = originalListOfCars.filter(
  (car) =>
    car.make === "Fiat" &&
    !car.isPickup &&
    !car.isHatchback &&
    car.cylinders >= 6
);
```

#### ESLintとの併用

```bash
npm install -D eslint-config-prettier
```

```json
{
  "extends": [
    "eslint:recommended",
    "plugin:react/recommended",
    "prettier"  // 最後に配置してESLintのフォーマットルールを無効化
  ]
}
```

### 1.3 PropTypes（型チェック）

**注意: PropTypesはReact 19以降非推奨です。TypeScript推奨。**

#### PropTypesの使用例

```typescript
import PropTypes from 'prop-types';

function Input({ name, label, value, onChange }) {
  return (
    <label>
      {label}
      <input name={name} value={value} onChange={onChange} />
    </label>
  );
}

Input.propTypes = {
  name: PropTypes.string.isRequired,
  label: PropTypes.string.isRequired,
  value: PropTypes.string,
  onChange: PropTypes.func.isRequired,
};
```

#### 複雑な型定義

```typescript
// 形状（Shape）の定義
UserDisplay.propTypes = {
  user: PropTypes.shape({
    name: PropTypes.string,
    age: PropTypes.number,
  }).isRequired,
};

// 配列型の定義
Users.propTypes = {
  userList: PropTypes.arrayOf(
    PropTypes.shape({
      name: PropTypes.string,
      age: PropTypes.number,
    })
  ).isRequired,
};
```

#### PropTypes vs TypeScript

| PropTypes | TypeScript |
|-----------|-----------|
| ランタイム型チェック | 静的型チェック（エディタ内） |
| コンポーネントのみ | 全コードベース対応 |
| React 19で非推奨 | 推奨される現代的手法 |

### 1.4 React Developer Tools

#### Components Inspector（主要機能）

**コンポーネント階層の可視化:**
- Props/Stateのリアルタイム表示
- コンポーネントの値をインスペクタから直接編集可能
- コンテキストの値を確認
- Memoizedコンポーネントの検出

**State操作:**
```typescript
// useStateで管理されている状態をインスペクタから直接変更可能
// コンポーネントは変更後即座に再レンダリング
```

**Context確認:**
- Context Consumerでの値確認（読取専用）
- Context Providerでの値編集

#### Profiler（パフォーマンス計測）

**レンダリング分析:**
- コンポーネントのレンダリング時間計測
- 再レンダリング原因の特定
- レンダリングカスケードの可視化

**使用手順:**
1. 記録開始
2. 操作実行
3. 記録停止
4. 再レンダリング理由の分析

**設定:**
- "Why did this render?" 追跡を有効化
- レンダリング原因（Context更新、Props変更等）を表示

---

## 2. Reactテスト戦略

### 2.1 AAAパターン（必須）

すべてのテストは3段階で構成します。

```typescript
test("カウンターがクリックで増加する", async () => {
  // Arrange: テストの準備
  render(<Counter />);

  // Act: 操作の実行
  const user = userEvent.setup();
  const increment = screen.getByRole("button", { name: "Increment" });
  await user.click(increment);

  // Assert: 結果の検証
  const heading = screen.getByRole("heading", { name: "Counter: 1" });
  expect(heading).toBeInTheDocument();
});
```

**変数名規則:**
```typescript
const actual = calculateTotal(items);
const expected = 300;
expect(actual).toBe(expected);
```

### 2.2 要素クエリ優先順位（React Testing Library）

**1. getByRole（最優先）**

```typescript
// ボタン
screen.getByRole("button", { name: "送信" });

// 見出し
screen.getByRole("heading", { level: 2, name: "サブタイトル" });

// テキストボックス
screen.getByRole("textbox", { name: "ユーザー名" });

// チェックボックス
screen.getByRole("checkbox", { name: "利用規約に同意する" });
```

**2. getByLabelText（フォーム要素）**

```typescript
screen.getByLabelText("メールアドレス");
```

**3. getByPlaceholderText**

```typescript
screen.getByPlaceholderText("キーワードを入力");
```

**4. getByText**

```typescript
screen.getByText("こんにちは");
```

**5. getByTestId（最終手段）**

```typescript
// アイコン等、他の方法で取得できない場合のみ
screen.getByTestId("user-icon");
```

### 2.3 user-event（fireEventではなくuser-event使用）

```typescript
import userEvent from "@testing-library/user-event";

test("フォーム入力とクリック", async () => {
  render(<LoginForm />);
  const user = userEvent.setup();

  // テキスト入力
  await user.type(screen.getByLabelText("メールアドレス"), "test@example.com");

  // クリック
  await user.click(screen.getByRole("button", { name: "ログイン" }));

  // 結果の検証
  const successMessage = await screen.findByText("ログインに成功しました");
  expect(successMessage).toBeInTheDocument();
});
```

**主な操作:**
```typescript
const user = userEvent.setup();

await user.click(element);
await user.type(input, "テキスト");
await user.clear(input);
await user.keyboard("{Enter}");
await user.selectOptions(select, "option1");
```

### 2.4 コールバックテスト（モック）

```typescript
import { vi } from "vitest";

test("削除コールバックが正しい引数で呼ばれる", async () => {
  // Arrange
  const mockDelete = vi.fn();
  render(<ItemList items={items} onDelete={mockDelete} />);

  // Act
  const user = userEvent.setup();
  await user.click(screen.getByRole("button", { name: "Delete 'Item B'" }));

  // Assert
  expect(mockDelete).toHaveBeenCalledTimes(1);
  expect(mockDelete).toHaveBeenCalledWith("2");
});
```

### 2.5 非同期処理のテスト

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
  const item = await screen.findByText("Item 1");
  expect(item).toBeInTheDocument();
});
```

---

## 3. CSS手法選定

### 3.1 CSS手法比較

| 手法 | 特異性制御 | 衝突リスク | DX | パフォーマンス | 学習コスト |
|------|----------|----------|-----|-------------|----------|
| CSSファイル+クラス名 | 中 | 高 | 中 | 優秀 | 低 |
| CSS Modules | 中 | なし | 良好 | 優秀 | 低 |
| styled-components | 高 | なし | 優秀 | 中 | 中 |
| Tailwind CSS | 高 | 低 | 良好 | 優秀 | 中 |

### 3.2 CSSファイル + クラス名（従来型）

```css
/* Button.css */
.button {
  padding: 8px 16px;
  border-radius: 4px;
}

.button-primary {
  background-color: blue;
  color: white;
}
```

```tsx
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

### 3.3 CSS Modules

```css
/* Button.module.css */
.button {
  padding: 8px 16px;
}

.primary {
  background-color: blue;
  color: white;
}
```

```tsx
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
- スコープの自動隔離（クラス名が自動生成）
- 標準的なCSS記法
- SSR対応

**デメリット:**
- クラス名の結合が煩雑（classnamesライブラリ推奨）
- 動的スタイリングがやや不便

### 3.4 styled-components（CSS-in-JS）

```tsx
import styled from "styled-components";

const StyledButton = styled.button<{ variant: "primary" | "secondary" }>`
  padding: 8px 16px;
  border-radius: 4px;
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
- ランタイムオーバーヘッド
- バンドルサイズ増加
- SSR設定が複雑

### 3.5 Tailwind CSS

```tsx
function Button({ variant = "primary", children }) {
  const baseClasses = "px-4 py-2 rounded cursor-pointer";
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
- HTMLが冗長
- カスタムデザインの学習コスト
- 初期バンドルサイズが大きい

---

## 4. 選定基準

### 4.1 CSS手法選定

**CSS Modules推奨:**
- SSR重視
- バンドルサイズ最小化
- Next.js、Remix使用時

**styled-components推奨:**
- DX最重視
- 動的スタイリングが多い
- コンポーネント単位のカプセル化

**Tailwind CSS推奨:**
- 高速プロトタイピング
- デザインシステム統一
- レスポンシブデザイン多用

### 4.2 ツールチェーン選定

**ESLint（必須）:**
- eslint-plugin-react-hooks必須
- Airbnb等の既存ルールセット活用

**Prettier（推奨）:**
- ESLintと併用（eslint-config-prettier）
- チーム全体のコードスタイル統一

**TypeScript（推奨）:**
- PropTypesの代替（React 19以降）
- 静的型チェックによる早期エラー検出

---

## 5. まとめ

### 開発ツールチェーン

| ツール | 役割 | 必須度 |
|--------|-----|--------|
| ESLint | Linter | 必須 |
| Prettier | Formatter | 推奨 |
| React Developer Tools | デバッグ | 推奨 |
| TypeScript | 型チェック | 推奨 |

### CSS手法

| 手法 | 推奨ケース |
|------|----------|
| CSS Modules | SSR、バンドルサイズ重視 |
| styled-components | DX、動的スタイリング重視 |
| Tailwind CSS | 高速プロトタイピング、デザインシステム |
| CSSファイル | レガシー統合、シンプルなサイト |

### テスト戦略

| 手法 | 説明 |
|------|------|
| AAAパターン | Arrange → Act → Assert |
| getByRole優先 | アクセシビリティ重視のクエリ |
| user-event | 実ユーザー操作の再現 |
| actual/expected | 可読性の高い変数名規則 |
