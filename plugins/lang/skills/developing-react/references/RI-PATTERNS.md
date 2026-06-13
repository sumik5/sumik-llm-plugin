# コンポーネント設計パターン

Reactコンポーネントの設計パターンは、**再利用性**、**保守性**、**テスト容易性**を高めるための構造化手法です。

---

## 目次

1. [Providerパターン](#providerパターン)
2. [Compositeパターン](#compositeパターン)
3. [Summaryパターン](#summaryパターン)
4. [パターン選定ガイド](#パターン選定ガイド)

---

## Providerパターン

### 概要

**Providerパターン**は、React Contextを使用して、コンポーネントツリー全体に状態と更新関数を配布する設計手法です。深くネストされたコンポーネントに対して、Propsバケツリレー（prop drilling）を避けながら、効率的にデータを共有できます。

### 基本実装

```typescript
import { createContext, useContext, useState, ReactNode } from 'react';

// 1. Context作成
interface ThemeContextValue {
  theme: 'light' | 'dark';
  toggleTheme: () => void;
}

const ThemeContext = createContext<ThemeContextValue | undefined>(undefined);

// 2. Providerコンポーネント
export function ThemeProvider({ children }: { children: ReactNode }) {
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
    <button
      onClick={toggleTheme}
      style={{ background: theme === 'light' ? '#fff' : '#333' }}
    >
      Toggle Theme
    </button>
  );
}
```

### 専用Providerコンポーネントの作成

状態管理ロジックを専用コンポーネントに分離することで、メインアプリケーションがよりクリーンになります。

```typescript
// 専用Providerコンポーネント
function DarkModeProvider({ children }: { children: ReactNode }) {
  const [isDarkMode, setDarkMode] = useState(false);
  const toggleDarkMode = () => setDarkMode((v) => !v);
  const contextValue = { isDarkMode, toggleDarkMode };

  return (
    <DarkModeContext.Provider value={contextValue}>
      {children}
    </DarkModeContext.Provider>
  );
}

// カスタムフック
function useDarkMode() {
  return useContext(DarkModeContext);
}

// アプリケーション（状態なし、再レンダーなし）
export default function App() {
  return (
    <DarkModeProvider>
      <Main />
    </DarkModeProvider>
  );
}
```

**利点**:
- Appコンポーネントが状態を持たないため、再レンダーされない
- Mainコンポーネントのmemo()が不要になる
- 状態管理ロジックが明確に分離される

### パフォーマンス最適化: use-context-selector

**問題**: 標準のContextは、値の一部だけを使用しているコンポーネントも、全体が変更されると再レンダーされます。

**解決策**: `use-context-selector`ライブラリを使用して、必要な部分のみを購読します。

```typescript
import { createContext, useContextSelector } from 'use-context-selector';

interface UserContextValue {
  user: { name: string; age: number };
  settings: { notifications: boolean };
}

const UserContext = createContext<UserContextValue | undefined>(undefined);

function useDarkMode(selector: (ctx: UserContextValue) => any) {
  return useContextSelector(DarkModeContext, selector);
}

// 名前のみを購読（settingsが変更されても再レンダーされない）
function UserName() {
  const name = useDarkMode((ctx) => ctx.user.name);
  return <div>{name}</div>;
}

// トグル関数のみを購読（isDarkModeが変更されても再レンダーされない）
function ToggleButton() {
  const toggle = useDarkMode((ctx) => ctx.toggle);
  return <button onClick={toggle}>Toggle mode</button>;
}
```

**重要**: トグル関数は`useCallback`でメモ化し、安定した参照を保つ必要があります。

```typescript
function DarkModeProvider({ children }) {
  const [isDarkMode, setDarkMode] = useState(false);
  const toggle = useCallback(() => setDarkMode((v) => !v), []);
  const contextValue = { isDarkMode, toggle };

  return (
    <DarkModeContext.Provider value={contextValue}>
      {children}
    </DarkModeContext.Provider>
  );
}
```

### TypeScript型付き: recontextualパッケージ

`recontextual`パッケージを使用すると、型安全なSelectable Contextを簡単に作成できます。

```typescript
import recontextual from 'recontextual';

interface DarkModeContext {
  isDarkMode: boolean;
  toggle: () => void;
}

const [Provider, useDarkMode] = recontextual<DarkModeContext>();

function DarkModeProvider({ children }: PropsWithChildren) {
  const [isDarkMode, setDarkMode] = useState(false);
  const toggle = useCallback(() => setDarkMode((v) => !v), []);
  const contextValue = { isDarkMode, toggle };

  return <Provider value={contextValue}>{children}</Provider>;
}

// 使用例
function ThemedButton() {
  const isDarkMode = useDarkMode((ctx) => ctx.isDarkMode);
  return <button>{isDarkMode ? 'Dark' : 'Light'}</button>;
}
```

### 判断基準

| 使用すべき場合 | 使用すべきでない場合 |
|--------------|------------------|
| ✅ アプリ全体で共有する状態（認証、テーマ、言語） | ❌ 頻繁に更新される状態（フォーム入力、アニメーション） |
| ✅ 深くネストされたコンポーネント間のデータ共有 | ❌ 単一コンポーネント内の状態 |
| ✅ 更新頻度が低い状態 | ❌ 大量のコンポーネントが購読する頻繁更新状態 |

**最適化の目安**: Context値が1秒に1回以上更新される場合、use-context-selectorまたは状態管理ライブラリ（zustand、Redux Toolkit）を検討。

---

## Compositeパターン

### 概要

**Compositeパターン**は、複合UIコンポーネントを、名前空間付きサブコンポーネントで構築する設計手法です。親コンポーネントが構造を定義し、子コンポーネントがその中で柔軟に配置されます。

### タブコンポーネントの実装例

```typescript
import { createContext, useContext, useState, ReactNode } from 'react';

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
function Tabs({ defaultTab, children }: { defaultTab: string; children: ReactNode }) {
  const [activeTab, setActiveTab] = useState(defaultTab);

  return (
    <TabsContext.Provider value={{ activeTab, setActiveTab }}>
      <div className="tabs">{children}</div>
    </TabsContext.Provider>
  );
}

// 3. サブコンポーネント: タブリスト
function TabList({ children }: { children: ReactNode }) {
  return <div className="tab-list">{children}</div>;
}

// 4. サブコンポーネント: タブボタン
function Tab({ id, children }: { id: string; children: ReactNode }) {
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
function TabPanel({ id, children }: { id: string; children: ReactNode }) {
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

### アコーディオンコンポーネントの実装例

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

function Accordion({ multiple = false, children }: { multiple?: boolean; children: ReactNode }) {
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

function AccordionItem({ id, children }: { id: string; children: ReactNode }) {
  return <div className="accordion-item">{children}</div>;
}

function AccordionHeader({ id, children }: { id: string; children: ReactNode }) {
  const { openItems, toggleItem } = useAccordionContext();
  const isOpen = openItems.has(id);

  return (
    <button className="accordion-header" onClick={() => toggleItem(id)} aria-expanded={isOpen}>
      {children}
      <span>{isOpen ? '▲' : '▼'}</span>
    </button>
  );
}

function AccordionContent({ id, children }: { id: string; children: ReactNode }) {
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

### 単一カスタムフックの例: RadioGroup

```typescript
import { useState } from "react";

// カスタムフック（ロジック集約）
function useContextValue({ name, onChange }: { name: string; onChange?: (value: string) => void }) {
  const [selectedValue, setSelectedValue] = useState("");

  const handleChange = (value: string) => {
    setSelectedValue(value);
    if (onChange) {
      onChange(value);
    }
  };

  return {
    name,
    selectedValue,
    onChange: handleChange,
  };
}

// コンポーネント（UIのみ）
export function RadioGroup({ children, name, onChange }: { children: ReactNode; name: string; onChange?: (value: string) => void }) {
  const contextValue = useContextValue({ name, onChange });

  return (
    <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-start" }}>
      <RadioGroupContext.Provider value={contextValue}>
        {children}
      </RadioGroupContext.Provider>
    </div>
  );
}
```

### 複数カスタムフックの例: タスク管理

```typescript
import { useState, useCallback } from "react";

// 1. タスクリスト管理フック
function useTaskList() {
  const [tasks, setTasks] = useState<Array<{ task: string; completed: boolean }>>([]);

  const addTask = (task: string) => {
    if (task.trim() !== "") {
      setTasks((prevTasks) => [...prevTasks, { task, completed: false }]);
    }
  };

  const toggleTaskCompletion = useCallback((index: number) => {
    setTasks((prevTasks) =>
      prevTasks.map((task, i) =>
        i === index ? { ...task, completed: !task.completed } : task
      )
    );
  }, []);

  return { tasks, addTask, toggleTaskCompletion };
}

// 2. 新規タスク入力フック
function useNewTaskInput(addTask: (task: string) => void) {
  const [newTask, setNewTask] = useState("");

  const handleNewTaskChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setNewTask(e.target.value);
  };

  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    addTask(newTask);
    setNewTask("");
  };

  return {
    newTask,
    handleNewTaskChange,
    handleSubmit,
  };
}

// 3. コンポーネント（UIのみ）
export function CompactTaskManager() {
  const { tasks, addTask, toggleTaskCompletion } = useTaskList();
  const { newTask, handleNewTaskChange, handleSubmit } = useNewTaskInput(addTask);

  return (
    <div>
      <form onSubmit={handleSubmit}>
        <input
          type="text"
          value={newTask}
          onChange={handleNewTaskChange}
          placeholder="Add new task"
        />
        <button type="submit">Add Task</button>
      </form>
      <ul>
        {tasks.map((task, index) => (
          <li
            key={index}
            style={{
              textDecoration: task.completed ? "line-through" : "none",
            }}
          >
            <input
              type="checkbox"
              checked={task.completed}
              onChange={() => toggleTaskCompletion(index)}
              disabled={task.completed}
            />
            {task.task}
          </li>
        ))}
      </ul>
    </div>
  );
}
```

### 単一フック vs 複数フック

| アプローチ | 適用場面 | 例 |
|----------|---------|-----|
| **単一フック** | 関心事が単一で、密結合したロジック | `useForm`: フォームの状態・バリデーション・送信を一括管理 |
| **複数フック** | 独立した複数の関心事 | `useTaskList` + `useNewTaskInput`: それぞれ独立 |

**判断基準**: ロジックが互いに依存している場合は単一フック、独立している場合は複数フックに分割。

### 判断基準

| 使用すべき場合 | 使用すべきでない場合 |
|--------------|------------------|
| ✅ コンポーネントのロジックが肥大化 | ❌ 非常にシンプルなコンポーネント |
| ✅ ロジックを複数コンポーネントで再利用 | ❌ 単一コンポーネントでしか使わない |
| ✅ テストしやすくしたい | ❌ フックのルールを理解していない |

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
