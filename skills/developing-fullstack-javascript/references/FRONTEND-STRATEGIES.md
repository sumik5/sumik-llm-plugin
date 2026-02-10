# フロントエンド開発戦略ガイド

このドキュメントは、O'Reilly書籍「Full Stack JavaScript Strategies」に基づくフロントエンド開発の包括的なガイドです。モダンなJavaScript/TypeScriptアプリケーション開発における設計原則、アーキテクチャパターン、実装戦略を提供します。

## 目次

1. [フロントエンドアーキテクチャ](#1-フロントエンドアーキテクチャ)
2. [状態管理](#2-状態管理)
3. [データフェッチ](#3-データフェッチ)
4. [エラーハンドリング](#4-エラーハンドリング)
5. [アクセシビリティ](#5-アクセシビリティ)
6. [パフォーマンス最適化](#6-パフォーマンス最適化)
7. [レスポンシブデザイン](#7-レスポンシブデザイン)
8. [フロントエンドセキュリティ](#8-フロントエンドセキュリティ)
9. [カスタムスタイル](#9-カスタムスタイル)

---

## 1. フロントエンドアーキテクチャ

### フレームワーク選択

モダンなフロントエンド開発において、フレームワークの選択は最も重要な意思決定の一つです。

#### React推奨理由

本ガイドでは**React**を推奨フレームワークとして採用します。その理由は以下の通りです：

- **成熟したエコシステム**: 豊富なライブラリ、ツール、プラグインが利用可能
- **大規模なコミュニティ**: Stack Overflow、GitHub、フォーラムでのサポートが充実
- **高い採用率**: 業界標準として広く採用され、求人市場でも需要が高い
- **企業サポート**: Metaによる継続的な開発とメンテナンス
- **柔軟性**: UIライブラリとして機能し、他のツールと組み合わせやすい
- **学習リソース**: 公式ドキュメント、チュートリアル、オンラインコースが豊富

#### 他フレームワークとの比較

| フレームワーク | 特徴 | 適用場面 |
|--------------|------|---------|
| **React** | コンポーネントベース、宣言的UI、巨大エコシステム | 中〜大規模SPA、企業向けアプリ |
| **Vue** | 段階的採用可能、テンプレート構文、学習曲線が緩やか | 中規模アプリ、既存プロジェクトへの統合 |
| **Angular** | フルフレームワーク、TypeScript標準、エンタープライズ向け | 大規模エンタープライズアプリ |
| **Svelte** | コンパイル時最適化、記述量が少ない、高速 | 小〜中規模アプリ、パフォーマンス重視 |

#### 重要な注意点

**フレームワーク変更はアプリケーション全体の再構築を意味します**。プロジェクト開始時に慎重に選択し、以下を考慮してください：

- チームの既存スキルセット
- プロジェクトの規模と複雑さ
- 長期的なメンテナンス計画
- エコシステムとサードパーティライブラリのサポート
- 採用市場での人材確保のしやすさ

### コンポーネントベースアーキテクチャ

Reactをはじめとするモダンフレームワークは、コンポーネントベースアーキテクチャを採用しています。

#### Atomic Design方法論

**Atomic Design**は、Brad Frost提唱のデザインシステム構築手法で、コンポーネントを5つの階層に分類します：

```
Atoms（原子）
  ↓
Molecules（分子）
  ↓
Organisms（有機体）
  ↓
Templates（テンプレート）
  ↓
Pages（ページ）
```

##### 1. Atoms（原子）

最小の構成要素。これ以上分解できない基本的なUIパーツ。

**例**:
- ボタン（Button）
- インプット（Input）
- ラベル（Label）
- アイコン（Icon）
- テキスト（Text）

```typescript
// atoms/Button.tsx
import { ButtonHTMLAttributes, FC } from 'react'

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'danger'
  size?: 'small' | 'medium' | 'large'
}

export const Button: FC<ButtonProps> = ({
  variant = 'primary',
  size = 'medium',
  children,
  ...props
}) => {
  return (
    <button
      className={`btn btn-${variant} btn-${size}`}
      {...props}
    >
      {children}
    </button>
  )
}
```

##### 2. Molecules（分子）

複数のAtomsを組み合わせた、一つの機能を持つコンポーネント。

**例**:
- 検索フォーム（SearchBox = Input + Button）
- フォームフィールド（FormField = Label + Input + ErrorMessage）
- カード（Card = Image + Text + Button）

```typescript
// molecules/SearchBox.tsx
import { FC, FormEvent, useState } from 'react'
import { Input } from '../atoms/Input'
import { Button } from '../atoms/Button'

interface SearchBoxProps {
  onSearch: (query: string) => void
  placeholder?: string
}

export const SearchBox: FC<SearchBoxProps> = ({
  onSearch,
  placeholder = 'Search...'
}) => {
  const [query, setQuery] = useState('')

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault()
    onSearch(query)
  }

  return (
    <form onSubmit={handleSubmit} className="search-box">
      <Input
        type="search"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        placeholder={placeholder}
        aria-label="Search input"
      />
      <Button type="submit" variant="primary">
        Search
      </Button>
    </form>
  )
}
```

##### 3. Organisms（有機体）

Molecules、Atoms、または他のOrganismsを組み合わせた、独立した機能を持つコンポーネント群。

**例**:
- ヘッダー（Header = Logo + Navigation + SearchBox）
- サイドバー（Sidebar = Menu + UserProfile + Notifications）
- 商品リスト（ProductList = ProductCard[]）

```typescript
// organisms/Header.tsx
import { FC } from 'react'
import { Logo } from '../atoms/Logo'
import { Navigation } from '../molecules/Navigation'
import { SearchBox } from '../molecules/SearchBox'
import { UserMenu } from '../molecules/UserMenu'

interface HeaderProps {
  onSearch: (query: string) => void
  currentUser?: User
}

export const Header: FC<HeaderProps> = ({ onSearch, currentUser }) => {
  return (
    <header className="header">
      <div className="header-container">
        <Logo />
        <Navigation />
        <SearchBox onSearch={onSearch} />
        {currentUser && <UserMenu user={currentUser} />}
      </div>
    </header>
  )
}
```

##### 4. Templates（テンプレート）

ページの骨組みとなるレイアウト。実際のコンテンツは含まず、コンポーネントの配置を定義。

```typescript
// templates/MainLayout.tsx
import { FC, ReactNode } from 'react'
import { Header } from '../organisms/Header'
import { Sidebar } from '../organisms/Sidebar'
import { Footer } from '../organisms/Footer'

interface MainLayoutProps {
  children: ReactNode
  currentUser?: User
}

export const MainLayout: FC<MainLayoutProps> = ({ children, currentUser }) => {
  return (
    <div className="main-layout">
      <Header currentUser={currentUser} />
      <div className="layout-body">
        <Sidebar />
        <main className="content">{children}</main>
      </div>
      <Footer />
    </div>
  )
}
```

##### 5. Pages（ページ）

実際のコンテンツを含む完全なページ。Templateに具体的なデータを注入したもの。

```typescript
// pages/DashboardPage.tsx
import { FC } from 'react'
import { MainLayout } from '../templates/MainLayout'
import { DashboardStats } from '../organisms/DashboardStats'
import { RecentOrders } from '../organisms/RecentOrders'
import { useCurrentUser } from '../hooks/useCurrentUser'

export const DashboardPage: FC = () => {
  const { data: currentUser } = useCurrentUser()

  return (
    <MainLayout currentUser={currentUser}>
      <h1>Dashboard</h1>
      <DashboardStats />
      <RecentOrders />
    </MainLayout>
  )
}
```

#### 用語のカスタマイズ

Atomic Designの用語（Atoms、Moleculesなど）は、チームによっては直感的でない場合があります。**チームに合わせてカスタマイズすることを推奨します**：

| Atomic Design | 代替案1 | 代替案2 |
|--------------|---------|---------|
| Atoms | Elements | Primitives |
| Molecules | Components | Blocks |
| Organisms | Modules | Sections |
| Templates | Layouts | Frames |
| Pages | Views | Screens |

重要なのは、**チーム全体で統一された用語を使うこと**です。

#### コンポーネントのモジュラーアプローチ

コンポーネント設計の原則：

1. **単一責任の原則**: 各コンポーネントは一つの明確な責任を持つ
2. **再利用性**: 汎用的で、複数の場所で使えるように設計
3. **カプセル化**: 内部実装を隠蔽し、明確なインターフェースを提供
4. **疎結合**: 他のコンポーネントへの依存を最小限に
5. **テスタビリティ**: ユニットテストが書きやすい設計

```typescript
// ❌ Bad: ビジネスロジックが混在
export const UserProfile: FC = () => {
  const [user, setUser] = useState<User | null>(null)

  useEffect(() => {
    fetch('/api/user')
      .then(res => res.json())
      .then(data => setUser(data))
  }, [])

  const calculateAge = (birthDate: string) => {
    // 複雑な計算ロジック...
  }

  return <div>{user && <p>Age: {calculateAge(user.birthDate)}</p>}</div>
}

// ✅ Good: ビジネスロジックとコンポーネントを分離
// hooks/useUser.ts
export const useUser = () => {
  return useQuery({
    queryKey: ['user'],
    queryFn: () => axios.get('/api/user').then(res => res.data)
  })
}

// utils/dateUtils.ts
export const calculateAge = (birthDate: string): number => {
  const today = new Date()
  const birth = new Date(birthDate)
  let age = today.getFullYear() - birth.getFullYear()
  const monthDiff = today.getMonth() - birth.getMonth()
  if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birth.getDate())) {
    age--
  }
  return age
}

// components/UserProfile.tsx
export const UserProfile: FC = () => {
  const { data: user, isLoading } = useUser()

  if (isLoading) return <Skeleton />
  if (!user) return <ErrorMessage />

  return (
    <div className="user-profile">
      <p>Age: {calculateAge(user.birthDate)}</p>
    </div>
  )
}
```

### プロジェクト構造

#### React + TypeScript + Vite 構成

推奨されるフォルダ構造：

```
src/
├── components/          # 再利用可能なUIコンポーネント
│   ├── atoms/          # 最小単位のコンポーネント
│   ├── molecules/      # Atomsを組み合わせたコンポーネント
│   └── organisms/      # 複雑なコンポーネント群
├── screens/            # ページコンポーネント（ルートに対応）
│   ├── DashboardPage/
│   ├── LoginPage/
│   └── SettingsPage/
├── layouts/            # レイアウトテンプレート
│   ├── MainLayout.tsx
│   └── AuthLayout.tsx
├── hooks/              # カスタムReact Hooks
│   ├── useUser.ts
│   ├── useAuth.ts
│   └── useDebounce.ts
├── utils/              # ユーティリティ関数
│   ├── dateUtils.ts
│   ├── stringUtils.ts
│   └── validation.ts
├── services/           # API通信ロジック
│   ├── api.ts
│   ├── userService.ts
│   └── orderService.ts
├── stores/             # 状態管理（Context/Redux/Valtio等）
│   ├── authStore.ts
│   └── cartStore.ts
├── types/              # TypeScript型定義
│   ├── user.ts
│   ├── order.ts
│   └── api.ts
├── mocks/              # テスト用モックデータ
│   ├── handlers.ts
│   └── fixtures.ts
├── styles/             # グローバルスタイル
│   ├── globals.css
│   ├── variables.css
│   └── theme.ts
├── assets/             # 静的ファイル
│   ├── images/
│   ├── fonts/
│   └── icons/
├── config/             # 設定ファイル
│   └── constants.ts
├── App.tsx             # ルートコンポーネント
└── main.tsx            # エントリーポイント
```

#### ファイル命名規則

一貫性のある命名規則を採用することで、コードベースの可読性と保守性が向上します。

**推奨命名規則**:

1. **コンポーネントファイル**: PascalCase（例: `UserProfile.tsx`, `SearchBox.tsx`）
2. **フックファイル**: camelCase + use接頭辞（例: `useAuth.ts`, `useDebounce.ts`）
3. **ユーティリティファイル**: camelCase（例: `dateUtils.ts`, `validation.ts`）
4. **型定義ファイル**: camelCase（例: `user.ts`, `api.ts`）
5. **定数ファイル**: camelCase（例: `constants.ts`, `config.ts`）

```typescript
// ✅ Good
components/
  UserProfile.tsx
  SearchBox.tsx
hooks/
  useAuth.ts
  useDebounce.ts
utils/
  dateUtils.ts
  stringUtils.ts

// ❌ Bad
components/
  user-profile.tsx    // kebab-case
  searchbox.tsx       // lowercase
hooks/
  auth.ts            // use接頭辞なし
utils/
  DateUtils.ts       // PascalCase（コンポーネントではない）
```

#### index.tsx パターン

`index.tsx`を使用して、フォルダからのエクスポートを整理します。

```typescript
// components/atoms/index.ts
export { Button } from './Button'
export { Input } from './Input'
export { Label } from './Label'
export { Icon } from './Icon'

// 使用側
import { Button, Input, Label } from '@/components/atoms'
```

**メリット**:
- インポート文が簡潔になる
- 内部構造の変更が容易
- 公開APIを明確に定義できる

**注意点**:
- バンドルサイズに影響する可能性があるため、Tree Shakingが効くことを確認
- 循環依存に注意

---

## 2. 状態管理

状態管理は、フロントエンド開発における最も重要な設計判断の一つです。適切な状態管理戦略を選択することで、コードの保守性、パフォーマンス、開発体験が大きく向上します。

### 状態管理の判断フロー

```
質問1: 状態はローカルコンポーネント内でのみ使用される？
  └─ YES → useState

質問2: 状態の更新ロジックが複雑（複数のアクションタイプ、複雑な状態遷移）？
  └─ YES → useReducer

質問3: 状態を複数のコンポーネント間で共有する必要がある？
  └─ YES → useContext（props drillingが3階層以上の場合）

質問4: アプリ全体でグローバルに状態を管理する必要がある？
  └─ YES → 外部ライブラリ（Valtio / Redux / Jotai / Zustand）

質問5: サーバーデータの管理？
  └─ YES → TanStack Query（後述）
```

### useState: シンプルなローカル状態

`useState`は、最もシンプルで直感的な状態管理フックです。

#### 適用場面

- プリミティブ値の管理（文字列、数値、真偽値）
- トグル状態（モーダルの開閉、ドロワーの表示/非表示）
- フォーム入力値
- ローカルUI状態

#### 基本的な使用法

```typescript
import { useState, FC } from 'react'

export const Counter: FC = () => {
  const [count, setCount] = useState(0)

  return (
    <div>
      <p>Count: {count}</p>
      <button onClick={() => setCount(count + 1)}>Increment</button>
      <button onClick={() => setCount(count - 1)}>Decrement</button>
      <button onClick={() => setCount(0)}>Reset</button>
    </div>
  )
}
```

#### オブジェクト状態の更新

```typescript
interface User {
  name: string
  email: string
  age: number
}

export const UserForm: FC = () => {
  const [user, setUser] = useState<User>({
    name: '',
    email: '',
    age: 0
  })

  // ❌ Bad: 直接変更（ミューテーション）
  const handleNameChangeBad = (name: string) => {
    user.name = name  // これは動作しない！
    setUser(user)
  }

  // ✅ Good: 新しいオブジェクトを作成
  const handleNameChange = (name: string) => {
    setUser({ ...user, name })
  }

  // ✅ Good: 関数形式でprevStateを使用
  const handleEmailChange = (email: string) => {
    setUser(prevUser => ({ ...prevUser, email }))
  }

  return (
    <form>
      <input
        value={user.name}
        onChange={(e) => handleNameChange(e.target.value)}
        placeholder="Name"
      />
      <input
        value={user.email}
        onChange={(e) => handleEmailChange(e.target.value)}
        placeholder="Email"
      />
    </form>
  )
}
```

#### 配列状態の更新

```typescript
export const TodoList: FC = () => {
  const [todos, setTodos] = useState<string[]>([])
  const [input, setInput] = useState('')

  // 追加
  const addTodo = () => {
    setTodos([...todos, input])
    setInput('')
  }

  // 削除
  const removeTodo = (index: number) => {
    setTodos(todos.filter((_, i) => i !== index))
  }

  // 更新
  const updateTodo = (index: number, newValue: string) => {
    setTodos(todos.map((todo, i) => i === index ? newValue : todo))
  }

  return (
    <div>
      <input
        value={input}
        onChange={(e) => setInput(e.target.value)}
      />
      <button onClick={addTodo}>Add</button>
      <ul>
        {todos.map((todo, index) => (
          <li key={index}>
            {todo}
            <button onClick={() => removeTodo(index)}>Delete</button>
          </li>
        ))}
      </ul>
    </div>
  )
}
```

### useReducer: 複雑な状態遷移

`useReducer`は、複雑な状態ロジックを管理するためのフックです。Redux風のaction/dispatchパターンを採用しています。

#### 適用場面

- 複数の関連する状態値がある
- 状態の更新ロジックが複雑
- 状態の更新パターンが複数ある
- 状態遷移のテストを書きやすくしたい

#### 基本的な使用法

```typescript
import { useReducer, FC } from 'react'

// 状態の型定義
interface State {
  count: number
  step: number
}

// アクションの型定義
type Action =
  | { type: 'increment' }
  | { type: 'decrement' }
  | { type: 'reset' }
  | { type: 'setStep'; payload: number }

// Reducer関数
const counterReducer = (state: State, action: Action): State => {
  switch (action.type) {
    case 'increment':
      return { ...state, count: state.count + state.step }
    case 'decrement':
      return { ...state, count: state.count - state.step }
    case 'reset':
      return { ...state, count: 0 }
    case 'setStep':
      return { ...state, step: action.payload }
    default:
      return state
  }
}

export const Counter: FC = () => {
  const [state, dispatch] = useReducer(counterReducer, {
    count: 0,
    step: 1
  })

  return (
    <div>
      <p>Count: {state.count}</p>
      <p>Step: {state.step}</p>
      <button onClick={() => dispatch({ type: 'increment' })}>
        +{state.step}
      </button>
      <button onClick={() => dispatch({ type: 'decrement' })}>
        -{state.step}
      </button>
      <button onClick={() => dispatch({ type: 'reset' })}>
        Reset
      </button>
      <input
        type="number"
        value={state.step}
        onChange={(e) => dispatch({
          type: 'setStep',
          payload: Number(e.target.value)
        })}
      />
    </div>
  )
}
```

#### 実践例: フォーム管理

```typescript
interface FormState {
  values: {
    username: string
    email: string
    password: string
  }
  errors: {
    username?: string
    email?: string
    password?: string
  }
  isSubmitting: boolean
}

type FormAction =
  | { type: 'SET_FIELD'; field: keyof FormState['values']; value: string }
  | { type: 'SET_ERROR'; field: keyof FormState['errors']; error: string }
  | { type: 'CLEAR_ERRORS' }
  | { type: 'SUBMIT_START' }
  | { type: 'SUBMIT_SUCCESS' }
  | { type: 'SUBMIT_FAILURE'; errors: FormState['errors'] }
  | { type: 'RESET' }

const initialState: FormState = {
  values: { username: '', email: '', password: '' },
  errors: {},
  isSubmitting: false
}

const formReducer = (state: FormState, action: FormAction): FormState => {
  switch (action.type) {
    case 'SET_FIELD':
      return {
        ...state,
        values: { ...state.values, [action.field]: action.value },
        errors: { ...state.errors, [action.field]: undefined }
      }
    case 'SET_ERROR':
      return {
        ...state,
        errors: { ...state.errors, [action.field]: action.error }
      }
    case 'CLEAR_ERRORS':
      return { ...state, errors: {} }
    case 'SUBMIT_START':
      return { ...state, isSubmitting: true, errors: {} }
    case 'SUBMIT_SUCCESS':
      return initialState
    case 'SUBMIT_FAILURE':
      return { ...state, isSubmitting: false, errors: action.errors }
    case 'RESET':
      return initialState
    default:
      return state
  }
}

export const RegistrationForm: FC = () => {
  const [state, dispatch] = useReducer(formReducer, initialState)

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault()
    dispatch({ type: 'SUBMIT_START' })

    try {
      await api.register(state.values)
      dispatch({ type: 'SUBMIT_SUCCESS' })
    } catch (error) {
      dispatch({
        type: 'SUBMIT_FAILURE',
        errors: { email: 'Registration failed' }
      })
    }
  }

  return (
    <form onSubmit={handleSubmit}>
      <input
        value={state.values.username}
        onChange={(e) => dispatch({
          type: 'SET_FIELD',
          field: 'username',
          value: e.target.value
        })}
        aria-invalid={!!state.errors.username}
      />
      {state.errors.username && <span role="alert">{state.errors.username}</span>}

      {/* email, password fields... */}

      <button type="submit" disabled={state.isSubmitting}>
        {state.isSubmitting ? 'Submitting...' : 'Register'}
      </button>
    </form>
  )
}
```

### useContext: Props Drillingの解消

`useContext`は、コンポーネントツリー全体で状態を共有するためのフックです。

#### 適用場面

- テーマ（ダークモード/ライトモード）
- 認証情報（現在のユーザー）
- ロケール（言語設定）
- グローバル設定

#### Props Drillingの問題

```typescript
// ❌ Bad: Props Drilling
const App = () => {
  const [theme, setTheme] = useState('light')
  return <Layout theme={theme} setTheme={setTheme} />
}

const Layout = ({ theme, setTheme }) => (
  <Header theme={theme} setTheme={setTheme} />
)

const Header = ({ theme, setTheme }) => (
  <ThemeToggle theme={theme} setTheme={setTheme} />
)

const ThemeToggle = ({ theme, setTheme }) => (
  <button onClick={() => setTheme(theme === 'light' ? 'dark' : 'light')}>
    Toggle
  </button>
)
```

#### Context による解決

```typescript
// contexts/ThemeContext.tsx
import { createContext, useContext, useState, ReactNode, FC } from 'react'

type Theme = 'light' | 'dark'

interface ThemeContextType {
  theme: Theme
  toggleTheme: () => void
}

const ThemeContext = createContext<ThemeContextType | undefined>(undefined)

export const ThemeProvider: FC<{ children: ReactNode }> = ({ children }) => {
  const [theme, setTheme] = useState<Theme>('light')

  const toggleTheme = () => {
    setTheme(prevTheme => prevTheme === 'light' ? 'dark' : 'light')
  }

  return (
    <ThemeContext.Provider value={{ theme, toggleTheme }}>
      {children}
    </ThemeContext.Provider>
  )
}

export const useTheme = () => {
  const context = useContext(ThemeContext)
  if (!context) {
    throw new Error('useTheme must be used within ThemeProvider')
  }
  return context
}

// ✅ Good: Context使用
const App = () => (
  <ThemeProvider>
    <Layout />
  </ThemeProvider>
)

const Layout = () => <Header />

const Header = () => <ThemeToggle />

const ThemeToggle = () => {
  const { theme, toggleTheme } = useTheme()
  return (
    <button onClick={toggleTheme}>
      Current: {theme}
    </button>
  )
}
```

#### パフォーマンス注意点

**Context の値が変更されると、そのコンテキストを使用するすべてのコンポーネントが再レンダリングされます。**

```typescript
// ❌ Bad: 不要な再レンダリング
interface AppContextType {
  user: User
  theme: Theme
  setUser: (user: User) => void
  setTheme: (theme: Theme) => void
}

// UserとThemeを別々に使いたい場合でも、どちらかが変更されると両方のコンシューマーが再レンダリング

// ✅ Good: Contextを分離
<UserProvider>
  <ThemeProvider>
    <App />
  </ThemeProvider>
</UserProvider>
```

#### メモ化によるパフォーマンス改善

```typescript
import { useMemo } from 'react'

export const ThemeProvider: FC<{ children: ReactNode }> = ({ children }) => {
  const [theme, setTheme] = useState<Theme>('light')

  const value = useMemo(() => ({
    theme,
    toggleTheme: () => setTheme(prev => prev === 'light' ? 'dark' : 'light')
  }), [theme])

  return (
    <ThemeContext.Provider value={value}>
      {children}
    </ThemeContext.Provider>
  )
}
```

### 外部ライブラリ: グローバル状態管理

大規模アプリケーションでは、専用の状態管理ライブラリが必要になることがあります。

#### Valtio: プロキシベースの状態管理

**特徴**:
- **ミュータブル**な書き方が可能（直接代入）
- プロキシベースで自動的に変更を追跡
- セットアップが簡単
- TypeScript完全対応

```typescript
// stores/cartStore.ts
import { proxy, useSnapshot } from 'valtio'

interface CartItem {
  id: string
  name: string
  price: number
  quantity: number
}

interface CartState {
  items: CartItem[]
  total: number
}

export const cartStore = proxy<CartState>({
  items: [],
  total: 0
})

// Actions（ミュータブルに書ける）
export const addToCart = (item: CartItem) => {
  const existingItem = cartStore.items.find(i => i.id === item.id)

  if (existingItem) {
    existingItem.quantity += 1
  } else {
    cartStore.items.push(item)
  }

  cartStore.total = cartStore.items.reduce(
    (sum, item) => sum + item.price * item.quantity,
    0
  )
}

export const removeFromCart = (id: string) => {
  const index = cartStore.items.findIndex(i => i.id === id)
  if (index !== -1) {
    cartStore.items.splice(index, 1)
    cartStore.total = cartStore.items.reduce(
      (sum, item) => sum + item.price * item.quantity,
      0
    )
  }
}

// コンポーネントでの使用
export const Cart: FC = () => {
  const snap = useSnapshot(cartStore)

  return (
    <div>
      <h2>Cart ({snap.items.length})</h2>
      <ul>
        {snap.items.map(item => (
          <li key={item.id}>
            {item.name} x {item.quantity} = ${item.price * item.quantity}
            <button onClick={() => removeFromCart(item.id)}>Remove</button>
          </li>
        ))}
      </ul>
      <p>Total: ${snap.total}</p>
    </div>
  )
}
```

**メリット**:
- ボイラープレートが少ない
- Immutableパターンを意識せずに書ける
- React外でも使用可能

**デメリット**:
- ミュータブルな書き方がチームによっては混乱を招く
- 複雑な状態遷移のデバッグが難しい場合がある

#### Redux: エンタープライズ向け

**特徴**:
- 最も成熟した状態管理ライブラリ
- DevToolsによる強力なデバッグ機能
- ミドルウェアエコシステム（redux-saga、redux-thunk）
- **Redux Toolkit**で大幅に簡略化

```typescript
// stores/userSlice.ts
import { createSlice, PayloadAction } from '@reduxjs/toolkit'

interface UserState {
  currentUser: User | null
  isLoading: boolean
  error: string | null
}

const initialState: UserState = {
  currentUser: null,
  isLoading: false,
  error: null
}

const userSlice = createSlice({
  name: 'user',
  initialState,
  reducers: {
    loginStart: (state) => {
      state.isLoading = true
      state.error = null
    },
    loginSuccess: (state, action: PayloadAction<User>) => {
      state.currentUser = action.payload
      state.isLoading = false
    },
    loginFailure: (state, action: PayloadAction<string>) => {
      state.error = action.payload
      state.isLoading = false
    },
    logout: (state) => {
      state.currentUser = null
    }
  }
})

export const { loginStart, loginSuccess, loginFailure, logout } = userSlice.actions
export default userSlice.reducer

// stores/store.ts
import { configureStore } from '@reduxjs/toolkit'
import userReducer from './userSlice'

export const store = configureStore({
  reducer: {
    user: userReducer
  }
})

export type RootState = ReturnType<typeof store.getState>
export type AppDispatch = typeof store.dispatch

// コンポーネントでの使用
import { useSelector, useDispatch } from 'react-redux'

export const UserProfile: FC = () => {
  const { currentUser, isLoading } = useSelector((state: RootState) => state.user)
  const dispatch = useDispatch()

  const handleLogout = () => {
    dispatch(logout())
  }

  if (isLoading) return <Spinner />
  if (!currentUser) return <LoginPrompt />

  return (
    <div>
      <h2>{currentUser.name}</h2>
      <button onClick={handleLogout}>Logout</button>
    </div>
  )
}
```

**メリット**:
- 大規模アプリケーションでの実績
- 予測可能な状態管理
- 時間旅行デバッグ

**デメリット**:
- Redux Toolkitを使っても、他のライブラリよりボイラープレートが多い
- 学習曲線が急

#### Jotai: アトミックな状態管理

**特徴**:
- アトム（atom）単位で状態を管理
- ボトムアップアプローチ
- Recoilに似たAPI

```typescript
// stores/atoms.ts
import { atom } from 'jotai'

export const countAtom = atom(0)
export const userAtom = atom<User | null>(null)

// Derived atom（computed値）
export const doubleCountAtom = atom(
  (get) => get(countAtom) * 2
)

// Write-only atom
export const incrementAtom = atom(
  null,
  (get, set) => set(countAtom, get(countAtom) + 1)
)

// コンポーネントでの使用
import { useAtom, useAtomValue, useSetAtom } from 'jotai'

export const Counter: FC = () => {
  const [count, setCount] = useAtom(countAtom)
  const doubleCount = useAtomValue(doubleCountAtom)
  const increment = useSetAtom(incrementAtom)

  return (
    <div>
      <p>Count: {count}</p>
      <p>Double: {doubleCount}</p>
      <button onClick={() => setCount(count + 1)}>+1</button>
      <button onClick={increment}>Increment (via atom)</button>
    </div>
  )
}
```

**メリット**:
- 最小限のボイラープレート
- TypeScript対応が優秀
- 必要な状態だけをサブスクライブ

**デメリット**:
- エコシステムがReduxほど成熟していない

#### Zustand: シンプルなAPI

**特徴**:
- Reduxの代替として人気
- フック不要でストアを直接使える
- ミドルウェア対応

```typescript
// stores/useStore.ts
import { create } from 'zustand'

interface BearState {
  bears: number
  increase: () => void
  decrease: () => void
  reset: () => void
}

export const useBearStore = create<BearState>((set) => ({
  bears: 0,
  increase: () => set((state) => ({ bears: state.bears + 1 })),
  decrease: () => set((state) => ({ bears: state.bears - 1 })),
  reset: () => set({ bears: 0 })
}))

// コンポーネントでの使用
export const BearCounter: FC = () => {
  const bears = useBearStore((state) => state.bears)
  const increase = useBearStore((state) => state.increase)

  return (
    <div>
      <p>Bears: {bears}</p>
      <button onClick={increase}>Add Bear</button>
    </div>
  )
}
```

**メリット**:
- 学習コストが低い
- Provider不要
- React外でも使える

**デメリット**:
- Redux DevTools統合が限定的

### 状態管理ライブラリの選択基準

| ライブラリ | 推奨規模 | 学習曲線 | ボイラープレート | TypeScript | ユースケース |
|-----------|---------|---------|---------------|-----------|-------------|
| **useState/useReducer** | 小 | 低 | 最小 | ✅ | ローカル状態 |
| **useContext** | 小〜中 | 低 | 少 | ✅ | テーマ、認証 |
| **Valtio** | 中 | 低 | 少 | ✅ | シンプルなグローバル状態 |
| **Zustand** | 中 | 低 | 少 | ✅ | Redux代替 |
| **Jotai** | 中 | 中 | 少 | ✅✅ | 細粒度の状態管理 |
| **Redux Toolkit** | 大 | 中〜高 | 中 | ✅ | エンタープライズ |

**推奨アプローチ**:
1. まずはReactの組み込みフック（useState、useReducer、useContext）で解決できないか検討
2. グローバル状態が必要になったら、チームの好みとプロジェクト規模に応じて選択
3. **サーバー状態にはTanStack Queryを使用**（次セクション）

---

## 3. データフェッチ

サーバーからのデータ取得は、モダンなフロントエンドアプリケーションの中心的な機能です。

### TanStack Query + Axios の推奨理由

#### TanStack Query（旧React Query）

**推奨理由**:

1. **自動キャッシュ管理**: 重複リクエストを自動で排除
2. **ローディング・エラー状態の自動管理**: `isLoading`、`error`が自動で提供される
3. **バックグラウンド更新**: データが古くなったら自動で再取得
4. **無限スクロール・ページネーション対応**: 専用フックが用意されている
5. **Optimistic Update**: UIを先に更新してからサーバーに送信
6. **DevTools**: 強力なデバッグツール

#### Axios

**推奨理由**:

1. **インターセプター**: リクエスト/レスポンスを一括処理
2. **グローバル設定**: baseURL、認証トークンを一元管理
3. **エラーハンドリング**: fetch APIより扱いやすい
4. **リクエストキャンセル**: AbortControllerの簡易ラッパー
5. **TypeScript対応**: 型定義が充実

### セットアップ

```typescript
// src/services/api.ts
import axios from 'axios'

// Axiosインスタンス作成
export const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL || 'https://api.example.com',
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json'
  }
})

// リクエストインターセプター（認証トークン追加）
api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('authToken')
    if (token) {
      config.headers.Authorization = `Bearer ${token}`
    }
    return config
  },
  (error) => Promise.reject(error)
)

// レスポンスインターセプター（エラーハンドリング）
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      // 認証エラー時の処理
      localStorage.removeItem('authToken')
      window.location.href = '/login'
    }
    return Promise.reject(error)
  }
)
```

```typescript
// src/main.tsx
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { ReactQueryDevtools } from '@tanstack/react-query-devtools'

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5 * 60 * 1000,     // 5分間はデータをfreshとみなす
      gcTime: 10 * 60 * 1000,       // 10分間キャッシュを保持（旧cacheTime）
      refetchOnWindowFocus: false,  // ウィンドウフォーカス時の自動再取得を無効化
      retry: 1,                     // エラー時のリトライ回数
    }
  }
})

const root = ReactDOM.createRoot(document.getElementById('root')!)
root.render(
  <QueryClientProvider client={queryClient}>
    <App />
    <ReactQueryDevtools initialIsOpen={false} />
  </QueryClientProvider>
)
```

### 基本的なデータ取得

#### useQuery: データの取得

```typescript
// services/orderService.ts
import { api } from './api'

export interface Order {
  id: string
  userId: string
  items: OrderItem[]
  total: number
  status: 'pending' | 'processing' | 'completed' | 'cancelled'
  createdAt: string
}

export const orderService = {
  getOrders: () => api.get<Order[]>('/v1/orders').then(res => res.data),
  getOrder: (id: string) => api.get<Order>(`/v1/orders/${id}`).then(res => res.data),
  createOrder: (data: CreateOrderDto) => api.post<Order>('/v1/orders', data).then(res => res.data),
  updateOrder: (id: string, data: UpdateOrderDto) =>
    api.patch<Order>(`/v1/orders/${id}`, data).then(res => res.data),
  deleteOrder: (id: string) => api.delete(`/v1/orders/${id}`)
}

// hooks/useOrders.ts
import { useQuery } from '@tanstack/react-query'
import { orderService } from '../services/orderService'

export const useOrders = () => {
  return useQuery({
    queryKey: ['orders'],
    queryFn: orderService.getOrders,
    staleTime: 30 * 60 * 1000,      // 30分間はfresh
    gcTime: 60 * 60 * 1000,         // 1時間キャッシュ保持
    refetchInterval: 60 * 60 * 1000 // 1時間ごとに自動再取得
  })
}

export const useOrder = (id: string) => {
  return useQuery({
    queryKey: ['orders', id],
    queryFn: () => orderService.getOrder(id),
    enabled: !!id,  // idが存在する場合のみクエリを実行
    staleTime: 5 * 60 * 1000
  })
}

// components/OrderList.tsx
export const OrderList: FC = () => {
  const { data: orders, isLoading, error, refetch } = useOrders()

  if (isLoading) {
    return <OrderListSkeleton />
  }

  if (error) {
    return (
      <ErrorMessage
        message="Failed to load orders"
        onRetry={refetch}
      />
    )
  }

  return (
    <div>
      <h2>Orders ({orders.length})</h2>
      <ul>
        {orders.map(order => (
          <OrderItem key={order.id} order={order} />
        ))}
      </ul>
    </div>
  )
}
```

#### useMutation: データの更新

```typescript
// hooks/useOrderMutations.ts
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { orderService, CreateOrderDto } from '../services/orderService'

export const useCreateOrder = () => {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: orderService.createOrder,
    onSuccess: () => {
      // キャッシュを無効化して再取得
      queryClient.invalidateQueries({ queryKey: ['orders'] })
    },
    onError: (error) => {
      console.error('Order creation failed:', error)
    }
  })
}

export const useUpdateOrder = () => {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: ({ id, data }: { id: string; data: UpdateOrderDto }) =>
      orderService.updateOrder(id, data),
    onMutate: async ({ id, data }) => {
      // Optimistic Update
      await queryClient.cancelQueries({ queryKey: ['orders', id] })

      const previousOrder = queryClient.getQueryData(['orders', id])

      queryClient.setQueryData(['orders', id], (old: Order) => ({
        ...old,
        ...data
      }))

      return { previousOrder }
    },
    onError: (err, variables, context) => {
      // ロールバック
      if (context?.previousOrder) {
        queryClient.setQueryData(['orders', variables.id], context.previousOrder)
      }
    },
    onSettled: (data, error, variables) => {
      queryClient.invalidateQueries({ queryKey: ['orders', variables.id] })
    }
  })
}

// components/CreateOrderForm.tsx
export const CreateOrderForm: FC = () => {
  const createOrder = useCreateOrder()
  const [formData, setFormData] = useState<CreateOrderDto>({
    items: [],
    userId: ''
  })

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault()
    createOrder.mutate(formData, {
      onSuccess: () => {
        toast.success('Order created successfully')
        setFormData({ items: [], userId: '' })
      },
      onError: () => {
        toast.error('Failed to create order')
      }
    })
  }

  return (
    <form onSubmit={handleSubmit}>
      {/* フォームフィールド */}
      <button type="submit" disabled={createOrder.isPending}>
        {createOrder.isPending ? 'Creating...' : 'Create Order'}
      </button>
    </form>
  )
}
```

### ローディング・エラー状態の適切な管理

#### アンチパターン: Promise.allで全APIを待つ

```typescript
// ❌ Bad: 全てのAPIが完了するまで何も表示されない（UX悪い）
export const Dashboard: FC = () => {
  const [isLoading, setIsLoading] = useState(true)
  const [data, setData] = useState<DashboardData | null>(null)

  useEffect(() => {
    Promise.all([
      api.get('/orders'),
      api.get('/users'),
      api.get('/products'),
      api.get('/analytics')
    ])
      .then(([orders, users, products, analytics]) => {
        setData({ orders, users, products, analytics })
      })
      .finally(() => setIsLoading(false))
  }, [])

  if (isLoading) return <FullPageSpinner />  // 全て待たないと何も表示されない

  return <DashboardContent data={data} />
}
```

#### ベストプラクティス: 個別のローディング状態

```typescript
// ✅ Good: 各セクションが独立してロード
export const Dashboard: FC = () => {
  const { data: orders, isLoading: ordersLoading } = useOrders()
  const { data: users, isLoading: usersLoading } = useUsers()
  const { data: products, isLoading: productsLoading } = useProducts()
  const { data: analytics, isLoading: analyticsLoading } = useAnalytics()

  return (
    <div className="dashboard">
      <section>
        <h2>Orders</h2>
        {ordersLoading ? <Skeleton /> : <OrdersWidget data={orders} />}
      </section>

      <section>
        <h2>Users</h2>
        {usersLoading ? <Skeleton /> : <UsersWidget data={users} />}
      </section>

      <section>
        <h2>Products</h2>
        {productsLoading ? <Skeleton /> : <ProductsWidget data={products} />}
      </section>

      <section>
        <h2>Analytics</h2>
        {analyticsLoading ? <Skeleton /> : <AnalyticsWidget data={analytics} />}
      </section>
    </div>
  )
}
```

**メリット**:
- ユーザーは利用可能なデータから順に見ることができる
- 一つのAPIが遅くても他のセクションは表示される
- Perceived Performance（体感パフォーマンス）が向上

### バックエンドに任せるべき処理

フロントエンドでデータ処理が必要になった場合、**まずバックエンドに移動できないか検討してください**。

#### ❌ フロントエンドで複雑な計算

```typescript
// ❌ Bad: フロントエンドで集計
export const OrderAnalytics: FC = () => {
  const { data: orders } = useOrders()

  const analytics = useMemo(() => {
    if (!orders) return null

    const totalRevenue = orders.reduce((sum, order) => sum + order.total, 0)
    const averageOrderValue = totalRevenue / orders.length
    const ordersByStatus = orders.reduce((acc, order) => {
      acc[order.status] = (acc[order.status] || 0) + 1
      return acc
    }, {} as Record<string, number>)

    // さらに複雑な計算が続く...

    return { totalRevenue, averageOrderValue, ordersByStatus }
  }, [orders])

  return <AnalyticsDisplay data={analytics} />
}
```

#### ✅ バックエンドで計算済みのデータを取得

```typescript
// ✅ Good: バックエンドで集計済み
// GET /v1/analytics/orders
// Response: { totalRevenue, averageOrderValue, ordersByStatus, ... }

export const OrderAnalytics: FC = () => {
  const { data: analytics, isLoading } = useQuery({
    queryKey: ['analytics', 'orders'],
    queryFn: () => api.get('/v1/analytics/orders').then(res => res.data)
  })

  if (isLoading) return <Skeleton />

  return <AnalyticsDisplay data={analytics} />
}
```

#### バックエンドに任せるべき処理のチェックリスト

- [ ] **大量データのフォーマット**: 10,000件以上のデータ整形
- [ ] **複数リクエスト結果のマージ**: 3つ以上のエンドポイントからデータを取得して結合
- [ ] **ページネーション**: サーバー側でページング
- [ ] **ソート**: データベースレベルでソート
- [ ] **フィルタリング**: 複雑な条件でのフィルタ
- [ ] **集計**: sum、average、count等の計算
- [ ] **検索**: 全文検索、あいまい検索

**統合エンドポイントの検討**:

```typescript
// ❌ Bad: 複数リクエスト
const { data: user } = useQuery(['user', userId], () => getUser(userId))
const { data: orders } = useQuery(['orders', userId], () => getUserOrders(userId))
const { data: preferences } = useQuery(['preferences', userId], () => getUserPreferences(userId))

// ✅ Good: 統合エンドポイント
// GET /v1/users/:id/dashboard
const { data } = useQuery(['userDashboard', userId], () =>
  api.get(`/v1/users/${userId}/dashboard`).then(res => res.data)
)
// Response: { user, orders, preferences }
```

### 無限スクロール・ページネーション

```typescript
// hooks/useInfiniteOrders.ts
import { useInfiniteQuery } from '@tanstack/react-query'

interface OrdersResponse {
  orders: Order[]
  nextCursor: string | null
  hasMore: boolean
}

export const useInfiniteOrders = () => {
  return useInfiniteQuery({
    queryKey: ['orders', 'infinite'],
    queryFn: ({ pageParam = 0 }) =>
      api.get<OrdersResponse>('/v1/orders', {
        params: { cursor: pageParam, limit: 20 }
      }).then(res => res.data),
    getNextPageParam: (lastPage) => lastPage.nextCursor,
    initialPageParam: 0
  })
}

// components/InfiniteOrderList.tsx
export const InfiniteOrderList: FC = () => {
  const {
    data,
    fetchNextPage,
    hasNextPage,
    isFetchingNextPage,
    isLoading
  } = useInfiniteOrders()

  const { ref, inView } = useInView()

  useEffect(() => {
    if (inView && hasNextPage) {
      fetchNextPage()
    }
  }, [inView, hasNextPage, fetchNextPage])

  if (isLoading) return <Skeleton />

  return (
    <div>
      {data.pages.map((page, i) => (
        <React.Fragment key={i}>
          {page.orders.map(order => (
            <OrderCard key={order.id} order={order} />
          ))}
        </React.Fragment>
      ))}

      <div ref={ref}>
        {isFetchingNextPage && <Spinner />}
      </div>
    </div>
  )
}
```

---

