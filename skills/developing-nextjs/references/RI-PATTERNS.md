# コンポーネント設計パターン

Reactコンポーネントの設計パターンは、**再利用性**、**保守性**、**テスト容易性**を高めるための構造化手法です。このドキュメントでは、実践的な3つの主要パターンと、UIライブラリ設計の原則を解説します。

---

## 目次

1. [Providerパターン](#providerパターン)
2. [Compositeパターン](#compositeパターン)
3. [Summaryパターン](#summaryパターン)
4. [UIライブラリ設計パターン](#uiライブラリ設計パターン)
5. [パターン選定ガイド](#パターン選定ガイド)

---

## Providerパターン

### 概要

**Providerパターン**は、React Contextを使用して、コンポーネントツリー全体に状態を配布する設計手法です。深くネストされたコンポーネントに対して、Propsバケツリレー（prop drilling）を避けながら、効率的にデータを共有できます。

### 利点

- **Propsバケツリレーの回避**: 中間コンポーネントを経由せずに、必要な箇所にデータを届ける
- **グローバル状態管理**: ユーザー認証情報、テーマ、言語設定など、アプリ全体で共有する状態に最適
- **疎結合**: 親子関係に依存せず、任意の深さのコンポーネントからアクセス可能

### 欠点

- **再レンダー問題**: Context値が変更されると、そのContextを使用する**すべて**のコンポーネントが再レンダーされる
- **過度な使用の危険性**: 頻繁に更新される状態をContextに入れると、パフォーマンスが劣化

### 基本実装例

```typescript
import { createContext, useContext, useState, ReactNode } from 'react';

// 1. Context作成
interface ThemeContextValue {
  theme: 'light' | 'dark';
  toggleTheme: () => void;
}

const ThemeContext = createContext<ThemeContextValue | undefined>(undefined);

// 2. Providerコンポーネント
interface ThemeProviderProps {
  children: ReactNode;
}

export function ThemeProvider({ children }: ThemeProviderProps) {
  const [theme, setTheme] = useState<'light' | 'dark'>('light');

  const toggleTheme = () => {
    setTheme((prev) => (prev === 'light' ? 'dark' : 'light'));
  };

  return (
    <ThemeContext.Provider value={{ theme, toggleTheme }}>
      {children}
    </ThemeContext.Provider>
  );
}

// 3. カスタムフック（使用側の簡略化）
export function useTheme() {
  const context = useContext(ThemeContext);
  if (!context) {
    throw new Error('useTheme must be used within ThemeProvider');
  }
  return context;
}

// 4. 使用例
function ThemedButton() {
  const { theme, toggleTheme } = useTheme();
  return (
    <button onClick={toggleTheme} style={{ background: theme === 'light' ? '#fff' : '#333' }}>
      Toggle Theme
    </button>
  );
}
```

### use-context-selectorによる最適化

**問題**: 標準のContextは、値の一部だけを使用しているコンポーネントも、全体が変更されると再レンダーされます。

**解決策**: `use-context-selector`ライブラリを使用して、必要な部分のみを購読します。

```typescript
import { createContext, useContextSelector } from 'use-context-selector';

interface UserContextValue {
  user: { name: string; age: number };
  settings: { notifications: boolean };
}

const UserContext = createContext<UserContextValue | undefined>(undefined);

// 名前のみを購読（settingsが変更されても再レンダーされない）
function UserName() {
  const name = useContextSelector(UserContext, (ctx) => ctx?.user.name);
  return <div>{name}</div>;
}

// 通知設定のみを購読（userが変更されても再レンダーされない）
function NotificationToggle() {
  const notifications = useContextSelector(UserContext, (ctx) => ctx?.settings.notifications);
  return <input type="checkbox" checked={notifications} />;
}
```

### 判断基準

| 使用すべき場合 | 使用すべきでない場合 |
|--------------|------------------|
| ✅ アプリ全体で共有する状態（認証、テーマ、言語） | ❌ 頻繁に更新される状態（フォーム入力、アニメーション） |
| ✅ 深くネストされたコンポーネント間のデータ共有 | ❌ 単一コンポーネント内の状態 |
| ✅ 更新頻度が低い状態 | ❌ 大量のコンポーネントが購読する頻繁更新状態 |

**最適化の目安**: Context値が1秒に1回以上更新される場合、use-context-selectorまたは状態管理ライブラリ（zustand、Redux）を検討。

---

## Compositeパターン

### 概要

**Compositeパターン**は、複合UIコンポーネントを、名前空間付きサブコンポーネントで構築する設計手法です。親コンポーネントが構造を定義し、子コンポーネントがその中で柔軟に配置されます。

### 利点

- **柔軟性**: 使用側が自由にサブコンポーネントを組み合わせられる
- **関心の分離**: 各サブコンポーネントが独立した責務を持つ
- **再利用性**: 共通のUIパターン（タブ、アコーディオン、ドロップダウン）を効率的に実装

### 欠点

- **初期設計コスト**: 適切な粒度のサブコンポーネント分割が必要
- **複雑性**: 親子間の通信にContextを使用するため、理解が必要

### 基本実装例（タブコンポーネント）

```typescript
import { createContext, useContext, useState, ReactNode, Children, isValidElement } from 'react';

// 1. 内部Context（タブの状態管理）
interface TabsContextValue {
  activeTab: string;
  setActiveTab: (id: string) => void;
}

const TabsContext = createContext<TabsContextValue | undefined>(undefined);

function useTabsContext() {
  const context = useContext(TabsContext);
  if (!context) {
    throw new Error('Tabs compound components must be used within <Tabs>');
  }
  return context;
}

// 2. 親コンポーネント（名前空間ルート）
interface TabsProps {
  defaultTab: string;
  children: ReactNode;
}

function Tabs({ defaultTab, children }: TabsProps) {
  const [activeTab, setActiveTab] = useState(defaultTab);

  return (
    <TabsContext.Provider value={{ activeTab, setActiveTab }}>
      <div className="tabs">{children}</div>
    </TabsContext.Provider>
  );
}

// 3. サブコンポーネント: タブリスト
interface TabListProps {
  children: ReactNode;
}

function TabList({ children }: TabListProps) {
  return <div className="tab-list">{children}</div>;
}

// 4. サブコンポーネント: タブボタン
interface TabProps {
  id: string;
  children: ReactNode;
}

function Tab({ id, children }: TabProps) {
  const { activeTab, setActiveTab } = useTabsContext();
  const isActive = activeTab === id;

  return (
    <button
      className={`tab ${isActive ? 'active' : ''}`}
      onClick={() => setActiveTab(id)}
      aria-selected={isActive}
    >
      {children}
    </button>
  );
}

// 5. サブコンポーネント: パネル
function TabPanel({ id, children }: TabProps) {
  const { activeTab } = useTabsContext();
  if (activeTab !== id) return null;

  return <div className="tab-panel">{children}</div>;
}

// 6. 名前空間付きエクスポート
Tabs.List = TabList;
Tabs.Tab = Tab;
Tabs.Panel = TabPanel;

export { Tabs };

// 7. 使用例
function App() {
  return (
    <Tabs defaultTab="home">
      <Tabs.List>
        <Tabs.Tab id="home">Home</Tabs.Tab>
        <Tabs.Tab id="profile">Profile</Tabs.Tab>
        <Tabs.Tab id="settings">Settings</Tabs.Tab>
      </Tabs.List>

      <Tabs.Panel id="home">
        <h2>Home Content</h2>
      </Tabs.Panel>
      <Tabs.Panel id="profile">
        <h2>Profile Content</h2>
      </Tabs.Panel>
      <Tabs.Panel id="settings">
        <h2>Settings Content</h2>
      </Tabs.Panel>
    </Tabs>
  );
}
```

### 高度な例: Accordionコンポーネント

```typescript
import { createContext, useContext, useState, ReactNode } from 'react';

interface AccordionContextValue {
  openItems: Set<string>;
  toggleItem: (id: string) => void;
}

const AccordionContext = createContext<AccordionContextValue | undefined>(undefined);

function useAccordionContext() {
  const context = useContext(AccordionContext);
  if (!context) {
    throw new Error('Accordion compound components must be used within <Accordion>');
  }
  return context;
}

interface AccordionProps {
  multiple?: boolean; // 複数項目の同時オープンを許可
  children: ReactNode;
}

function Accordion({ multiple = false, children }: AccordionProps) {
  const [openItems, setOpenItems] = useState<Set<string>>(new Set());

  const toggleItem = (id: string) => {
    setOpenItems((prev) => {
      const next = new Set(prev);
      if (next.has(id)) {
        next.delete(id);
      } else {
        if (!multiple) next.clear(); // 単一モード: 他を閉じる
        next.add(id);
      }
      return next;
    });
  };

  return (
    <AccordionContext.Provider value={{ openItems, toggleItem }}>
      <div className="accordion">{children}</div>
    </AccordionContext.Provider>
  );
}

interface AccordionItemProps {
  id: string;
  children: ReactNode;
}

function AccordionItem({ id, children }: AccordionItemProps) {
  return <div className="accordion-item">{children}</div>;
}

interface AccordionHeaderProps {
  id: string;
  children: ReactNode;
}

function AccordionHeader({ id, children }: AccordionHeaderProps) {
  const { openItems, toggleItem } = useAccordionContext();
  const isOpen = openItems.has(id);

  return (
    <button className="accordion-header" onClick={() => toggleItem(id)} aria-expanded={isOpen}>
      {children}
      <span>{isOpen ? '▲' : '▼'}</span>
    </button>
  );
}

function AccordionContent({ id, children }: AccordionItemProps) {
  const { openItems } = useAccordionContext();
  const isOpen = openItems.has(id);

  if (!isOpen) return null;
  return <div className="accordion-content">{children}</div>;
}

Accordion.Item = AccordionItem;
Accordion.Header = AccordionHeader;
Accordion.Content = AccordionContent;

export { Accordion };

// 使用例
function FAQ() {
  return (
    <Accordion multiple>
      <Accordion.Item id="q1">
        <Accordion.Header id="q1">What is React?</Accordion.Header>
        <Accordion.Content id="q1">
          React is a JavaScript library for building user interfaces.
        </Accordion.Content>
      </Accordion.Item>

      <Accordion.Item id="q2">
        <Accordion.Header id="q2">What is TypeScript?</Accordion.Header>
        <Accordion.Content id="q2">
          TypeScript is a typed superset of JavaScript.
        </Accordion.Content>
      </Accordion.Item>
    </Accordion>
  );
}
```

### 判断基準

| 使用すべき場合 | 使用すべきでない場合 |
|--------------|------------------|
| ✅ 複雑なUI部品（タブ、アコーディオン、ドロップダウン） | ❌ 単純なコンポーネント（ボタン、入力欄） |
| ✅ 柔軟なカスタマイズが必要 | ❌ 固定レイアウトで十分 |
| ✅ サブコンポーネント間の状態共有が必要 | ❌ 独立したコンポーネント |

---

## Summaryパターン

### 概要

**Summaryパターン**は、コンポーネントのビジネスロジック・副作用・状態管理を**カスタムフック**に集約する設計手法です。コンポーネント本体はUIの描画のみに集中し、ロジックはフックでカプセル化されます。

### 利点

- **テストが容易**: ロジックをフックとして独立してテスト可能
- **ロジック再利用**: 複数のコンポーネントで同じロジックを共有
- **可読性向上**: コンポーネントがUIに集中し、複雑なロジックがフックに隠蔽される

### 欠点

- **フックのルール**: トップレベルでのみ呼び出し可能、条件分岐内では使用不可
- **過度な抽象化**: すべてをフックに抽出すると、逆に複雑化する可能性

### 基本実装例（ユーザープロファイル）

```typescript
import { useState, useEffect } from 'react';

// 1. カスタムフック（ロジック集約）
interface User {
  id: string;
  name: string;
  email: string;
}

function useUserProfile(userId: string) {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    let isMounted = true;

    async function fetchUser() {
      try {
        setLoading(true);
        const response = await fetch(`/api/users/${userId}`);
        if (!response.ok) throw new Error('Failed to fetch user');
        const data = await response.json();
        if (isMounted) {
          setUser(data);
          setError(null);
        }
      } catch (err) {
        if (isMounted) {
          setError(err instanceof Error ? err : new Error('Unknown error'));
        }
      } finally {
        if (isMounted) setLoading(false);
      }
    }

    fetchUser();

    return () => {
      isMounted = false; // クリーンアップ
    };
  }, [userId]);

  return { user, loading, error };
}

// 2. コンポーネント（UIのみ）
interface UserProfileProps {
  userId: string;
}

function UserProfile({ userId }: UserProfileProps) {
  const { user, loading, error } = useUserProfile(userId);

  if (loading) return <div>Loading...</div>;
  if (error) return <div>Error: {error.message}</div>;
  if (!user) return <div>User not found</div>;

  return (
    <div>
      <h2>{user.name}</h2>
      <p>{user.email}</p>
    </div>
  );
}
```

### 複雑な例: フォーム管理

```typescript
import { useState, ChangeEvent, FormEvent } from 'react';

// 1. フォーム状態管理フック
interface FormValues {
  [key: string]: string;
}

interface FormErrors {
  [key: string]: string;
}

interface UseFormOptions {
  initialValues: FormValues;
  validate: (values: FormValues) => FormErrors;
  onSubmit: (values: FormValues) => Promise<void>;
}

function useForm({ initialValues, validate, onSubmit }: UseFormOptions) {
  const [values, setValues] = useState<FormValues>(initialValues);
  const [errors, setErrors] = useState<FormErrors>({});
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleChange = (e: ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    setValues((prev) => ({ ...prev, [name]: value }));
    // リアルタイムバリデーション
    if (errors[name]) {
      setErrors((prev) => ({ ...prev, [name]: '' }));
    }
  };

  const handleSubmit = async (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();

    const validationErrors = validate(values);
    if (Object.keys(validationErrors).length > 0) {
      setErrors(validationErrors);
      return;
    }

    try {
      setIsSubmitting(true);
      await onSubmit(values);
      setValues(initialValues); // リセット
    } catch (err) {
      setErrors({ submit: 'Submission failed' });
    } finally {
      setIsSubmitting(false);
    }
  };

  return {
    values,
    errors,
    isSubmitting,
    handleChange,
    handleSubmit,
  };
}

// 2. バリデーション関数
function validateLoginForm(values: FormValues): FormErrors {
  const errors: FormErrors = {};

  if (!values.email) {
    errors.email = 'Email is required';
  } else if (!/\S+@\S+\.\S+/.test(values.email)) {
    errors.email = 'Email is invalid';
  }

  if (!values.password) {
    errors.password = 'Password is required';
  } else if (values.password.length < 8) {
    errors.password = 'Password must be at least 8 characters';
  }

  return errors;
}

// 3. コンポーネント（UIのみ）
function LoginForm() {
  const { values, errors, isSubmitting, handleChange, handleSubmit } = useForm({
    initialValues: { email: '', password: '' },
    validate: validateLoginForm,
    onSubmit: async (values) => {
      // API呼び出し
      await fetch('/api/login', {
        method: 'POST',
        body: JSON.stringify(values),
      });
    },
  });

  return (
    <form onSubmit={handleSubmit}>
      <div>
        <label htmlFor="email">Email</label>
        <input id="email" name="email" type="email" value={values.email} onChange={handleChange} />
        {errors.email && <span className="error">{errors.email}</span>}
      </div>

      <div>
        <label htmlFor="password">Password</label>
        <input
          id="password"
          name="password"
          type="password"
          value={values.password}
          onChange={handleChange}
        />
        {errors.password && <span className="error">{errors.password}</span>}
      </div>

      <button type="submit" disabled={isSubmitting}>
        {isSubmitting ? 'Logging in...' : 'Login'}
      </button>

      {errors.submit && <span className="error">{errors.submit}</span>}
    </form>
  );
}
```

### 単一フック vs 複数フック

| アプローチ | 適用場面 | 例 |
|----------|---------|-----|
| **単一フック** | 関心事が単一で、密結合したロジック | `useForm`: フォームの状態・バリデーション・送信を一括管理 |
| **複数フック** | 独立した複数の関心事 | `useAuth` + `useTheme` + `useLocalStorage`: それぞれ独立 |

**判断基準**: ロジックが互いに依存している場合は単一フック、独立している場合は複数フックに分割。

### 判断基準

| 使用すべき場合 | 使用すべきでない場合 |
|--------------|------------------|
| ✅ コンポーネントのロジックが肥大化 | ❌ 非常にシンプルなコンポーネント |
| ✅ ロジックを複数コンポーネントで再利用 | ❌ 単一コンポーネントでしか使わない |
| ✅ テストしやすくしたい | ❌ フックのルールを理解していない |

---

## UIライブラリ設計パターン

### Switchコンポーネント

トグルスイッチは、アクセシビリティとビジュアルフィードバックが重要です。

```typescript
import { useState } from 'react';

interface SwitchProps {
  id: string;
  checked: boolean;
  onChange: (checked: boolean) => void;
  label: string;
  disabled?: boolean;
}

function Switch({ id, checked, onChange, label, disabled = false }: SwitchProps) {
  return (
    <div className="switch-container">
      <label htmlFor={id} className="switch-label">
        {label}
      </label>
      <button
        id={id}
        role="switch"
        aria-checked={checked}
        aria-label={label}
        disabled={disabled}
        onClick={() => onChange(!checked)}
        className={`switch ${checked ? 'checked' : ''} ${disabled ? 'disabled' : ''}`}
      >
        <span className="switch-thumb" />
      </button>
    </div>
  );
}

// 使用例
function App() {
  const [notifications, setNotifications] = useState(false);
  return <Switch id="notifications" checked={notifications} onChange={setNotifications} label="Enable Notifications" />;
}
```

**設計原則**:
- `role="switch"`でスクリーンリーダー対応
- `aria-checked`で状態を明示
- キーボード操作（Space/Enter）で切り替え可能

### Toastコンポーネント

通知の表示・自動消去・スタック管理を行います。

```typescript
import { useState, useEffect } from 'react';

interface Toast {
  id: string;
  message: string;
  type: 'success' | 'error' | 'info';
}

function useToast() {
  const [toasts, setToasts] = useState<Toast[]>([]);

  const addToast = (message: string, type: Toast['type'] = 'info') => {
    const id = Math.random().toString(36);
    setToasts((prev) => [...prev, { id, message, type }]);

    // 3秒後に自動削除
    setTimeout(() => {
      setToasts((prev) => prev.filter((toast) => toast.id !== id));
    }, 3000);
  };

  const removeToast = (id: string) => {
    setToasts((prev) => prev.filter((toast) => toast.id !== id));
  };

  return { toasts, addToast, removeToast };
}

function ToastContainer() {
  const { toasts, removeToast } = useToast();

  return (
    <div className="toast-container">
      {toasts.map((toast) => (
        <div key={toast.id} className={`toast toast-${toast.type}`}>
          <span>{toast.message}</span>
          <button onClick={() => removeToast(toast.id)}>✕</button>
        </div>
      ))}
    </div>
  );
}
```

**設計原則**:
- カスタムフックで状態管理をカプセル化
- 自動消去タイマーでUX向上
- 複数のトーストをスタック表示

### Storybook統合

```typescript
// Switch.stories.tsx
import { Meta, StoryObj } from '@storybook/react';
import { Switch } from './Switch';

const meta: Meta<typeof Switch> = {
  component: Switch,
  tags: ['autodocs'],
};

export default meta;
type Story = StoryObj<typeof Switch>;

export const Default: Story = {
  args: {
    id: 'default',
    checked: false,
    label: 'Default Switch',
  },
};

export const Checked: Story = {
  args: {
    id: 'checked',
    checked: true,
    label: 'Checked Switch',
  },
};

export const Disabled: Story = {
  args: {
    id: 'disabled',
    checked: false,
    label: 'Disabled Switch',
    disabled: true,
  },
};
```

---

## パターン選定ガイド

### フローチャート

```
【状態を複数コンポーネントで共有したい】
  └─ YES → Providerパターン
      └─ パフォーマンス問題がある？
          ├─ YES → use-context-selectorで最適化
          └─ NO → 標準Contextで十分

【複雑なUI部品を作りたい（タブ、アコーディオン等）】
  └─ YES → Compositeパターン
      └─ サブコンポーネント間で状態共有が必要？
          └─ YES → Composite + Provider（内部Context）

【コンポーネントのロジックが肥大化している】
  └─ YES → Summaryパターン
      └─ ロジックを抽出
          └─ 関心事が単一？
              ├─ YES → 単一カスタムフック
              └─ NO → 複数カスタムフック

【再利用可能なUI部品を作りたい】
  └─ YES → Composite + Summary
      └─ UIとロジックを分離
          ├─ Composite: UI構造
          └─ Summary: ビジネスロジック
```

### パターン組み合わせ例

| 要件 | 推奨パターン | 理由 |
|------|------------|------|
| グローバルな認証状態 | Provider | アプリ全体での状態共有 |
| タブコンポーネント | Composite + Provider | 柔軟なUI + 内部状態管理 |
| フォーム管理 | Summary | ロジック抽出でテスト容易 |
| 通知システム | Summary + Provider | フックでロジック管理 + グローバル表示 |
| ドロップダウンメニュー | Composite | サブコンポーネントでUI構築 |

### 実装チェックリスト

#### Providerパターン
- [ ] Context作成（createContext）
- [ ] Providerコンポーネント実装
- [ ] カスタムフック作成（useXxx）
- [ ] エラーハンドリング（Provider外での使用を検出）
- [ ] 必要に応じてuse-context-selectorで最適化

#### Compositeパターン
- [ ] 親コンポーネント作成
- [ ] サブコンポーネント作成
- [ ] 内部Context（必要な場合）
- [ ] 名前空間付きエクスポート（Parent.Child形式）
- [ ] Storybook統合

#### Summaryパターン
- [ ] カスタムフック作成
- [ ] ロジックをフックに集約
- [ ] コンポーネントはUIのみに集中
- [ ] フックのテスト作成
- [ ] 複数コンポーネントでの再利用を確認

---

## まとめ

| パターン | 主な用途 | 複雑度 | テスト容易性 | 再利用性 |
|---------|---------|--------|------------|---------|
| **Provider** | グローバル状態共有 | 中 | 中 | 高 |
| **Composite** | 複合UI部品 | 高 | 中 | 高 |
| **Summary** | ロジック抽出 | 低-中 | 高 | 高 |

**推奨アプローチ**:
1. まずシンプルな実装から始める
2. 複雑化してきたらパターンを適用
3. 過度な抽象化を避ける（YAGNI原則）

これらのパターンは、**保守性**、**再利用性**、**テスト容易性**を高めるための手段です。プロジェクトの要件に応じて、適切なパターンを選択してください。
