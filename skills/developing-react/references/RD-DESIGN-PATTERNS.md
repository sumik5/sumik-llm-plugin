# Reactデザインパターン補完集

> **前提**: Provider / Compound Components（Composite） / Custom Hooks（Summary）は [`RI-PATTERNS.md`](./RI-PATTERNS.md) で詳述済み。本ファイルはそれらを除いた追加パターンと、全パターンを統合した選定ガイドを提供する。

---

## 目次

1. [Container / Presenter](#1-container--presenter)
2. [HOC（Higher-Order Components）](#2-hoc-higher-order-components)
3. [Render Props](#3-render-props)
4. [State Reducer](#4-state-reducer)
5. [Controlled Components](#5-controlled-components)
6. [Headless Components](#6-headless-components)
7. [Control Props](#7-control-props)
8. [Conditional Rendering](#8-conditional-rendering)
9. [ForwardRef & Ref Patterns](#9-forwardref--ref-patterns)
10. [Prop Combination](#10-prop-combination)
11. [パターン統合選定ガイド](#11-パターン統合選定ガイド)

---

## 1. Container / Presenter

### 概要

**ロジック（Container）** と **表示（Presenter）** を分離するパターン。
Presenter は純粋な UI コンポーネントとして props を受け取るだけ。

### Custom Hooks 時代の位置づけ

Container/Presenter は **カスタムフックが登場する前** の主要な分離手法だった。現在はロジックをカスタムフック（Summary パターン）に抽出する方が自然。ただし以下の場面では依然有効：

- データ取得ロジックをサーバーコンポーネントに分離する（Next.js App Router）
- Storybook でロジックなしの純粋 UI をテストしたい

### コード例

```typescript
// Presenter: ロジックなし、純粋 UI
interface UserCardProps {
  name: string;
  email: string;
  avatarUrl: string;
  onFollow: () => void;
}

function UserCard({ name, email, avatarUrl, onFollow }: UserCardProps) {
  return (
    <div className="card">
      <img src={avatarUrl} alt={name} />
      <h2>{name}</h2>
      <p>{email}</p>
      <button onClick={onFollow}>フォロー</button>
    </div>
  );
}

// Container: データ取得・ロジック担当
function UserCardContainer({ userId }: { userId: string }) {
  const { data, mutate } = useSWR(`/api/users/${userId}`);

  const handleFollow = async () => {
    await fetch(`/api/users/${userId}/follow`, { method: 'POST' });
    mutate();
  };

  if (!data) return <Skeleton />;
  return <UserCard {...data} onFollow={handleFollow} />;
}
```

### いつ使うか / いつ使わないか

| 使う | 使わない |
|------|---------|
| Presenter を Storybook で独立テストしたい | ロジックがシンプルでカスタムフック1本で済む |
| Server Component + Client Component の分離（Next.js） | チームが小さく分割コストが高い |
| 同じ UI を複数の data source から駆動したい | |

---

## 2. HOC（Higher-Order Components）

### 概要

コンポーネントを受け取り、拡張されたコンポーネントを返す関数。
**横断的関心事**（認証、ロギング、パーミッション）を既存コンポーネントに付与する。

### Hooks 時代の使い分け

HOC の多くはカスタムフックで代替できる。HOC が適切なのは **コンポーネントの外側から振る舞いを注入** したい場合（ライブラリ API 互換性、クラスコンポーネントとの共存）。

### コード例：withAuth

```typescript
interface WithAuthProps {
  user: User;
}

function withAuth<T extends WithAuthProps>(
  WrappedComponent: React.ComponentType<T>
) {
  return function AuthenticatedComponent(
    props: Omit<T, keyof WithAuthProps>
  ) {
    const { user, isLoading } = useAuth();

    if (isLoading) return <Spinner />;
    if (!user) return <Navigate to="/login" />;

    return <WrappedComponent {...(props as T)} user={user} />;
  };
}

// 使用
const ProtectedDashboard = withAuth(Dashboard);
```

### withLogging HOC（デバッグ用）

```typescript
function withLogging<T extends object>(
  WrappedComponent: React.ComponentType<T>,
  componentName: string
) {
  return function LoggedComponent(props: T) {
    useEffect(() => {
      console.log(`[${componentName}] mounted`, props);
      return () => console.log(`[${componentName}] unmounted`);
    }, []);

    return <WrappedComponent {...props} />;
  };
}
```

### いつ使うか / いつ使わないか

| 使う | 使わない |
|------|---------|
| サードパーティコンポーネントに振る舞いを追加 | ロジック共有ならカスタムフックで十分 |
| クラスコンポーネントとの互換性維持 | HOC を多重適用（デバッグ困難）|
| コンポーネント外部から条件付きレンダリングを制御 | props の命名衝突リスクがある |

---

## 3. Render Props

### 概要

render 関数を props として受け取り、コンポーネント間でコードを共有するパターン。
子コンポーネントがどうレンダリングされるかを親が制御できる。

### Hooks との比較

Render Props はほぼカスタムフックで代替できる。ただし **JSX の構造を外部から制御** したい場面（テーブル行のカスタマイズ、ドラッグ&ドロップの hit test 可視化）では依然有効。

### コード例

```typescript
interface MousePosition {
  x: number;
  y: number;
}

interface MouseTrackerProps {
  render: (position: MousePosition) => React.ReactNode;
}

function MouseTracker({ render }: MouseTrackerProps) {
  const [position, setPosition] = useState<MousePosition>({ x: 0, y: 0 });

  const handleMouseMove = (e: React.MouseEvent) => {
    setPosition({ x: e.clientX, y: e.clientY });
  };

  return (
    <div onMouseMove={handleMouseMove} style={{ height: '100vh' }}>
      {render(position)}
    </div>
  );
}

// 使用
<MouseTracker
  render={({ x, y }) => (
    <p>マウス位置: {x}, {y}</p>
  )}
/>
```

### children as function パターン

```typescript
// render props の別表記（children を関数にする）
function DataFetcher<T>({
  url,
  children,
}: {
  url: string;
  children: (data: T | null, isLoading: boolean) => React.ReactNode;
}) {
  const { data, isLoading } = useSWR<T>(url);
  return <>{children(data ?? null, isLoading)}</>;
}
```

### いつ使うか / いつ使わないか

| 使う | 使わない |
|------|---------|
| レンダリングする JSX を外部から差し込みたい | 単純な状態共有（カスタムフックで十分） |
| 仮想化リスト・テーブルのカスタム行レンダリング | HOC 地獄の代替（どちらも複雑になる） |

---

## 4. State Reducer

### 概要

`useReducer` を公開してコンポーネントの状態管理をカスタマイズ可能にするパターン。
ライブラリが提供するデフォルト reducer をユーザーが上書きできる。

### Discriminated Unions との組み合わせ

```typescript
type ToggleAction =
  | { type: 'TOGGLE' }
  | { type: 'RESET' }
  | { type: 'SET'; value: boolean };

type ToggleState = { isOn: boolean };

function defaultToggleReducer(
  state: ToggleState,
  action: ToggleAction
): ToggleState {
  switch (action.type) {
    case 'TOGGLE':
      return { isOn: !state.isOn };
    case 'RESET':
      return { isOn: false };
    case 'SET':
      return { isOn: action.value };
  }
}

interface UseToggleOptions {
  initialState?: ToggleState;
  reducer?: (state: ToggleState, action: ToggleAction) => ToggleState;
}

function useToggle({
  initialState = { isOn: false },
  reducer = defaultToggleReducer,
}: UseToggleOptions = {}) {
  const [state, dispatch] = useReducer(reducer, initialState);

  const toggle = () => dispatch({ type: 'TOGGLE' });
  const reset = () => dispatch({ type: 'RESET' });
  const set = (value: boolean) => dispatch({ type: 'SET', value });

  return { ...state, toggle, reset, set };
}

// 使用側でリセット禁止に上書き
const { isOn, toggle } = useToggle({
  reducer(state, action) {
    if (action.type === 'RESET') return state; // リセット無効化
    return defaultToggleReducer(state, action);
  },
});
```

### いつ使うか / いつ使わないか

| 使う | 使わない |
|------|---------|
| 再利用可能コンポーネントのロジックをユーザーが拡張したい | 状態管理がシンプルで拡張不要 |
| UIライブラリ開発（ドロップダウン・トグル等） | 全 state を外部公開する Control Props の方が適切な場合 |

---

## 5. Controlled Components

### 概要

フォーム要素の値を React の state で管理するパターン。
`value` + `onChange` の組み合わせで、単一の真実の源（Single Source of Truth）を実現。

### バリデーション付き例

```typescript
interface FormState {
  email: string;
  password: string;
}

interface FormErrors {
  email?: string;
  password?: string;
}

function LoginForm() {
  const [form, setForm] = useState<FormState>({ email: '', password: '' });
  const [errors, setErrors] = useState<FormErrors>({});

  const validate = (field: keyof FormState, value: string): string | undefined => {
    if (field === 'email' && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) {
      return '有効なメールアドレスを入力してください';
    }
    if (field === 'password' && value.length < 8) {
      return '8文字以上で入力してください';
    }
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    setForm((prev) => ({ ...prev, [name]: value }));
    setErrors((prev) => ({ ...prev, [name]: validate(name as keyof FormState, value) }));
  };

  return (
    <form>
      <input
        name="email"
        type="email"
        value={form.email}
        onChange={handleChange}
        aria-invalid={!!errors.email}
        aria-describedby="email-error"
      />
      {errors.email && <span id="email-error" role="alert">{errors.email}</span>}
      <input
        name="password"
        type="password"
        value={form.password}
        onChange={handleChange}
      />
    </form>
  );
}
```

> **実務推奨**: 複雑なフォームは [React Hook Form](https://react-hook-form.com/) + Zod でバリデーション統合が標準。

### いつ使うか / いつ使わないか

| 使う | 使わない |
|------|---------|
| リアルタイムバリデーション | 単純な送信のみのフォーム（uncontrolled で十分） |
| 値に基づいた UI 動的変更 | パフォーマンスが問題（大量フィールド） |
| フォームの値を親が制御する必要がある | |

---

## 6. Headless Components

### 概要

**ロジックとアクセシビリティのみを提供し、スタイルは持たない**コンポーネント設計。
ユーザーが完全なスタイルの自由を持ちながら、複雑な UI ロジック（キーボード操作、ARIA 属性管理）を再実装せずに済む。

### 代表ライブラリ

- **Radix UI** - アクセシビリティ対応の Headless プリミティブ
- **Headless UI**（Tailwind Labs）- Tailwind と相性の良い Headless コンポーネント
- **shadcn/ui** - Radix UI + Tailwind のスタイル付きラッパー

### カスタム Headless Dropdown 実装例

```typescript
interface UseDropdownReturn {
  isOpen: boolean;
  selectedItem: string | null;
  getToggleProps: () => React.HTMLAttributes<HTMLButtonElement>;
  getMenuProps: () => React.HTMLAttributes<HTMLUListElement>;
  getItemProps: (item: string) => React.HTMLAttributes<HTMLLIElement>;
}

function useDropdown(items: string[]): UseDropdownReturn {
  const [isOpen, setIsOpen] = useState(false);
  const [selectedItem, setSelectedItem] = useState<string | null>(null);

  const getToggleProps = () => ({
    onClick: () => setIsOpen((v) => !v),
    'aria-haspopup': 'listbox' as const,
    'aria-expanded': isOpen,
  });

  const getMenuProps = () => ({
    role: 'listbox' as const,
    hidden: !isOpen,
  });

  const getItemProps = (item: string) => ({
    role: 'option' as const,
    'aria-selected': selectedItem === item,
    onClick: () => {
      setSelectedItem(item);
      setIsOpen(false);
    },
  });

  return { isOpen, selectedItem, getToggleProps, getMenuProps, getItemProps };
}

// 使用側（スタイルは自由）
function MyDropdown({ items }: { items: string[] }) {
  const { selectedItem, getToggleProps, getMenuProps, getItemProps } =
    useDropdown(items);

  return (
    <div>
      <button {...getToggleProps()}>{selectedItem ?? '選択してください'}</button>
      <ul {...getMenuProps()}>
        {items.map((item) => (
          <li key={item} {...getItemProps(item)}>{item}</li>
        ))}
      </ul>
    </div>
  );
}
```

### いつ使うか / いつ使わないか

| 使う | 使わない |
|------|---------|
| デザインシステムのプリミティブ構築 | プロダクト内の 1 箇所でのみ使う単純な UI |
| アクセシビリティ対応の複雑な UI（ドロップダウン、モーダル、コンボボックス） | Radix UI / Headless UI で十分なケース |
| スタイルを完全にカスタムしたい | |

---

## 7. Control Props

### 概要

コンポーネントの内部状態を外部から制御できるようにする **Controlled / Uncontrolled 両対応**パターン。
`value` と `onChange` を渡せば Controlled、渡さなければ内部 state を使う Uncontrolled として動作する。

### 実装例

```typescript
interface AccordionProps {
  // Control Props（渡せば Controlled）
  isOpen?: boolean;
  onToggle?: (isOpen: boolean) => void;
  // デフォルト値（Uncontrolled 時のみ参照）
  defaultOpen?: boolean;
}

function Accordion({ isOpen, onToggle, defaultOpen = false, children }: AccordionProps & { children: React.ReactNode }) {
  const [internalOpen, setInternalOpen] = useState(defaultOpen);

  // Controlled か Uncontrolled かを判定
  const isControlled = isOpen !== undefined;
  const open = isControlled ? isOpen : internalOpen;

  const handleToggle = () => {
    const next = !open;
    if (!isControlled) setInternalOpen(next);
    onToggle?.(next);
  };

  return (
    <div>
      <button onClick={handleToggle}>{open ? '閉じる' : '開く'}</button>
      {open && <div>{children}</div>}
    </div>
  );
}

// Uncontrolled（デフォルト状態で使う）
<Accordion defaultOpen={true}>コンテンツ</Accordion>

// Controlled（外部から制御）
const [open, setOpen] = useState(false);
<Accordion isOpen={open} onToggle={setOpen}>コンテンツ</Accordion>
```

### いつ使うか / いつ使わないか

| 使う | 使わない |
|------|---------|
| 再利用ライブラリコンポーネント（外部制御が必要な場合もある） | 常に Controlled が確定している場合（シンプルな props で OK） |
| フォーム統合ライブラリとの互換性確保 | 実装が複雑になる割に用途が 1 箇所のみ |

---

## 8. Conditional Rendering

### 5つのパターン比較

#### パターン 1: if 文（最も読みやすい）

```typescript
function Alert({ type, message }: { type: 'error' | 'warning' | 'info'; message: string }) {
  if (type === 'error') return <div className="error">{message}</div>;
  if (type === 'warning') return <div className="warning">{message}</div>;
  return <div className="info">{message}</div>;
}
```

#### パターン 2: 三項演算子（2択の場合）

```typescript
function LoginButton({ isLoggedIn }: { isLoggedIn: boolean }) {
  return isLoggedIn ? <LogoutButton /> : <LoginButton />;
}
```

#### パターン 3: && 演算子（表示/非表示のみ）

```typescript
// ⚠️ 0 や '' を使う場合は注意（0 がレンダリングされる）
function NotificationBadge({ count }: { count: number }) {
  return <>{count > 0 && <span className="badge">{count}</span>}</>;
}
```

#### パターン 4: switch-case（多分岐）

```typescript
type Status = 'idle' | 'loading' | 'success' | 'error';

function StatusView({ status, data, error }: { status: Status; data?: string; error?: Error }) {
  switch (status) {
    case 'idle':   return <p>待機中</p>;
    case 'loading': return <Spinner />;
    case 'success': return <p>{data}</p>;
    case 'error':   return <ErrorMessage error={error!} />;
  }
}
```

#### パターン 5: Suspense（非同期の宣言的ローディング）

```typescript
// React 19: use() + Suspense
function UserProfile({ userPromise }: { userPromise: Promise<User> }) {
  const user = use(userPromise); // Promise を直接渡す
  return <div>{user.name}</div>;
}

// 親コンポーネント
<Suspense fallback={<Skeleton />}>
  <UserProfile userPromise={fetchUser(userId)} />
</Suspense>
```

### 使い分けガイド

| 状況 | 推奨パターン |
|------|-----------|
| true/false の 2択 | 三項演算子 or && |
| 3種類以上の状態 | switch-case または if 文の早期リターン |
| 非同期データ待ち | Suspense + use() |
| 複雑な条件の組み合わせ | if 文（読みやすさ優先） |

---

## 9. ForwardRef & Ref Patterns

### React 19 の変更点：forwardRef 不要化

**React 19 以降、`ref` は通常の props として渡せる。** `forwardRef()` のラップは不要。

```typescript
// React 19〜: ref を props として受け取る
interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  label: string;
}

function Input({ label, ref, ...props }: InputProps & { ref?: React.Ref<HTMLInputElement> }) {
  return (
    <label>
      {label}
      <input ref={ref} {...props} />
    </label>
  );
}

// 使用側
const inputRef = useRef<HTMLInputElement>(null);
<Input label="名前" ref={inputRef} />
```

### React 18 以前（forwardRef が必要）

```typescript
const Input = React.forwardRef<HTMLInputElement, InputProps>(
  ({ label, ...props }, ref) => (
    <label>
      {label}
      <input ref={ref} {...props} />
    </label>
  )
);
Input.displayName = 'Input';
```

### useImperativeHandle：公開 API を制限する

```typescript
interface VideoPlayerHandle {
  play: () => void;
  pause: () => void;
}

// React 19 スタイル
function VideoPlayer(
  { src, ref }: { src: string; ref?: React.Ref<VideoPlayerHandle> }
) {
  const videoRef = useRef<HTMLVideoElement>(null);

  useImperativeHandle(ref, () => ({
    play: () => videoRef.current?.play(),
    pause: () => videoRef.current?.pause(),
    // seek や volume は非公開
  }));

  return <video ref={videoRef} src={src} />;
}
```

### いつ使うか / いつ使わないか

| 使う | 使わない |
|------|---------|
| フォーカス管理・スクロール・アニメーション命令 | 状態や props で表現できる操作 |
| サードパーティライブラリへの DOM 参照渡し | ref の乱用（React の宣言的設計に反する）|
| `useImperativeHandle` で公開 API を最小化 | |

---

## 10. Prop Combination

### 概要

スプレッド演算子でベースの props と追加 props を合成し、コンポーネントの**インターフェースを簡素化**するパターン。
特に汎用 UI コンポーネントで、既存 HTML 要素の props を引き継ぎながら拡張する際に有効。

### 基本パターン

```typescript
// HTML の button 全 props を引き継ぎつつ variant を追加
interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'danger';
  size?: 'sm' | 'md' | 'lg';
}

function Button({ variant = 'primary', size = 'md', className, ...rest }: ButtonProps) {
  return (
    <button
      className={cn(buttonVariants({ variant, size }), className)}
      {...rest} // onClick, disabled, type 等はすべて引き継ぐ
    />
  );
}
```

### 合成によるインターフェース整理

```typescript
// 複数の props セットを合成する例
interface CardProps {
  header?: React.ReactNode;
  footer?: React.ReactNode;
}

type CardDivProps = CardProps & React.HTMLAttributes<HTMLDivElement>;

function Card({ header, footer, children, className, ...divProps }: CardDivProps) {
  return (
    <div className={cn('card', className)} {...divProps}>
      {header && <div className="card-header">{header}</div>}
      <div className="card-body">{children}</div>
      {footer && <div className="card-footer">{footer}</div>}
    </div>
  );
}
```

### いつ使うか / いつ使わないか

| 使う | 使わない |
|------|---------|
| HTML 要素を薄くラップするデザインシステムコンポーネント | 全 props を公開したくない場合（意図的な制限が必要） |
| 既存コンポーネントに props を追記するだけのラッパー | スプレッドで型安全が失われる恐れがある場合 |

---

## 11. パターン統合選定ガイド

### 全パターン一覧（RI-PATTERNS.md 含む）

| パターン | 主な用途 | Hooks 代替可否 | 複雑度 |
|---------|---------|--------------|-------|
| **Provider**（RI） | グローバル状態・深いツリーへのデータ配布 | - | 中 |
| **Compound Components**（RI） | 親子間の暗黙的状態共有（タブ、アコーディオン） | 部分的 | 中 |
| **Custom Hooks**（RI） | ロジック再利用・コンポーネント間共有 | - | 低 |
| **Container / Presenter** | ロジックと UI の物理的分離 | △（カスタムフックで代替可） | 低 |
| **HOC** | 横断的関心事の付与（認証、ロギング） | △（多くはカスタムフックで代替可） | 中 |
| **Render Props** | JSX 構造のカスタマイズ | △（カスタムフックで代替可） | 中 |
| **State Reducer** | ユーザーが状態遷移をカスタマイズできる API | - | 高 |
| **Controlled Components** | フォーム値の単一真実源 | - | 低 |
| **Headless Components** | ロジック提供・スタイル自由 | - | 高 |
| **Control Props** | Controlled / Uncontrolled 両対応 | - | 中 |
| **Conditional Rendering** | 条件付き表示の構造整理 | - | 低 |
| **ForwardRef & Ref** | DOM 操作・命令的 API 公開 | - | 低 |
| **Prop Combination** | インターフェース簡素化・HTML props 引き継ぎ | - | 低 |

### ディシジョンツリー

```
コンポーネント設計で困ったら
│
├─ グローバル状態を深いツリーに渡したい
│   └─→ Provider パターン（RI-PATTERNS.md）
│
├─ 親子間で暗黙状態を共有（タブ・アコーディオン等）
│   └─→ Compound Components（RI-PATTERNS.md）
│
├─ ロジックを複数コンポーネントで再利用したい
│   └─→ Custom Hooks（RI-PATTERNS.md） ← 第一選択
│
├─ ロジックと UI を物理的に分離したい
│   ├─ Storybook / Server Component 分離目的
│   │   └─→ Container / Presenter
│   └─→ それ以外は Custom Hooks で OK
│
├─ 既存コンポーネントに横断的関心事を付与したい
│   ├─ コンポーネント外部から振る舞いを変えたい → HOC
│   └─ ロジックだけ共有すれば OK → Custom Hooks
│
├─ レンダリングする JSX を外部から差し込みたい
│   └─→ Render Props（または children as function）
│
├─ 状態遷移ロジックをユーザーが上書きできる API を提供
│   └─→ State Reducer
│
├─ フォームを制御したい
│   ├─ シンプル（1〜3フィールド）→ Controlled Components
│   └─ 複雑（バリデーション・条件分岐）→ React Hook Form + Zod
│
├─ アクセシビリティ対応の複雑な UI（完全スタイル自由）
│   ├─ 自分で実装 → Headless Components パターン
│   └─ ライブラリ利用 → Radix UI / Headless UI / shadcn/ui
│
├─ 外部から状態を制御することもあれば内部管理することもある
│   └─→ Control Props（Controlled / Uncontrolled 両対応）
│
├─ DOM を直接操作・命令的 API を公開したい
│   └─→ ForwardRef & Ref（React 19: ref as prop）
│
└─ HTML 要素を薄くラップしてインターフェースを整理
    └─→ Prop Combination
```

### よくある組み合わせパターン

| 組み合わせ | ユースケース |
|-----------|-----------|
| Headless + Prop Combination | デザインシステムのプリミティブ（Button・Input） |
| State Reducer + Control Props | 高度な再利用コンポーネントライブラリ |
| Custom Hooks + Container/Presenter | Next.js Server/Client Component 分離 |
| HOC + Provider | 認証ガード付きルーティング |
| Compound Components + Render Props | カスタマイズ可能なテーブルコンポーネント |
| Controlled Components + Headless | フォームライブラリ統合（React Hook Form + Radix） |
