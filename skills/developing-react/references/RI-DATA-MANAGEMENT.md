# React データ管理戦略

React アプリケーションにおけるローカル状態管理とリモートデータ管理の包括的ガイド。

---

## 1. ローカル状態管理の選択肢

### useState vs useReducer

**useState推奨ケース:**
- シンプルなプリミティブ値（string, number, boolean）
- 独立した状態変更
- 更新ロジックが単純（1-2行で完結）

**useReducer推奨ケース:**
- 複雑なオブジェクト/配列
- 複数の状態が連動して変更
- 更新ロジックが複雑（条件分岐、複数ステップ）
- アクションベースの状態管理が必要

```typescript
// useState: シンプルなケース
const [count, setCount] = useState(0);
const increment = () => setCount(c => c + 1);

// useReducer: 複雑なケース
type State = { count: number; history: number[] };
type Action =
  | { type: "increment" }
  | { type: "decrement" }
  | { type: "reset" };

function reducer(state: State, action: Action): State {
  switch (action.type) {
    case "increment":
      return { count: state.count + 1, history: [...state.history, state.count + 1] };
    case "decrement":
      return { count: state.count - 1, history: [...state.history, state.count - 1] };
    case "reset":
      return { count: 0, history: [] };
  }
}

const [state, dispatch] = useReducer(reducer, { count: 0, history: [] });
dispatch({ type: "increment" });
```

### Context API による状態共有

**Context使用の判断基準:**
- 3階層以上のprops drilling発生時
- アプリ全体で共有する状態（テーマ、認証、言語設定）
- 中規模以上のコンポーネントツリー

**Context使用の注意点:**
- 過度な使用はパフォーマンス低下を招く
- 値が変更されると全コンシューマーが再レンダリング
- useMemo/useCallbackで値を最適化

```typescript
interface ThemeContextValue {
  theme: "light" | "dark";
  toggleTheme: () => void;
}

const ThemeContext = createContext<ThemeContextValue | undefined>(undefined);

function ThemeProvider({ children }: PropsWithChildren) {
  const [theme, setTheme] = useState<"light" | "dark">("light");

  const toggleTheme = useCallback(() => {
    setTheme((prev) => (prev === "light" ? "dark" : "light"));
  }, []);

  const value = useMemo(() => ({ theme, toggleTheme }), [theme, toggleTheme]);

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

function useTheme() {
  const context = useContext(ThemeContext);
  if (!context) {
    throw new Error("useTheme must be used within ThemeProvider");
  }
  return context;
}
```

---

## 2. Redux Toolkit (RTK) による大規模状態管理

### Redux Toolkit の基本構造

**Redux Toolkit推奨ケース:**
- 大規模アプリケーション（10+ 画面、複雑な状態相互依存）
- タイムトラベルデバッグが必要
- 複数チーム開発で一貫した状態管理パターンが必要
- Redux DevToolsでの状態監視が重要

```typescript
// store.ts
import { configureStore } from "@reduxjs/toolkit";
import userReducer from "./slices/userSlice";
import todosReducer from "./slices/todosSlice";

export const store = configureStore({
  reducer: {
    user: userReducer,
    todos: todosReducer,
  },
});

export type RootState = ReturnType<typeof store.getState>;
export type AppDispatch = typeof store.dispatch;

// slices/userSlice.ts
import { createSlice, PayloadAction } from "@reduxjs/toolkit";

interface UserState {
  id: string | null;
  name: string | null;
  isAuthenticated: boolean;
}

const initialState: UserState = {
  id: null,
  name: null,
  isAuthenticated: false,
};

const userSlice = createSlice({
  name: "user",
  initialState,
  reducers: {
    login(state, action: PayloadAction<{ id: string; name: string }>) {
      state.id = action.payload.id;
      state.name = action.payload.name;
      state.isAuthenticated = true;
    },
    logout(state) {
      state.id = null;
      state.name = null;
      state.isAuthenticated = false;
    },
  },
});

export const { login, logout } = userSlice.actions;
export default userSlice.reducer;

// hooks.ts
import { useDispatch, useSelector } from "react-redux";
import type { AppDispatch, RootState } from "./store";

export const useAppDispatch = useDispatch.withTypes<AppDispatch>();
export const useAppSelector = useSelector.withTypes<RootState>();

// 使用例
function UserProfile() {
  const dispatch = useAppDispatch();
  const user = useAppSelector((state) => state.user);

  const handleLogout = () => {
    dispatch(logout());
  };

  return (
    <div>
      {user.isAuthenticated ? (
        <>
          <p>Welcome, {user.name}</p>
          <button onClick={handleLogout}>Logout</button>
        </>
      ) : (
        <p>Not logged in</p>
      )}
    </div>
  );
}
```

### RTK Query（APIスライス）

```typescript
// services/api.ts
import { createApi, fetchBaseQuery } from "@reduxjs/toolkit/query/react";

interface User {
  id: string;
  name: string;
  email: string;
}

export const api = createApi({
  reducerPath: "api",
  baseQuery: fetchBaseQuery({ baseUrl: "/api" }),
  tagTypes: ["User"],
  endpoints: (builder) => ({
    getUsers: builder.query<User[], void>({
      query: () => "/users",
      providesTags: ["User"],
    }),
    createUser: builder.mutation<User, Omit<User, "id">>({
      query: (newUser) => ({
        url: "/users",
        method: "POST",
        body: newUser,
      }),
      invalidatesTags: ["User"],
    }),
  }),
});

export const { useGetUsersQuery, useCreateUserMutation } = api;

// 使用例
function UserList() {
  const { data: users, isLoading, error } = useGetUsersQuery();
  const [createUser] = useCreateUserMutation();

  if (isLoading) return <div>Loading...</div>;
  if (error) return <div>Error loading users</div>;

  return (
    <ul>
      {users?.map((user) => (
        <li key={user.id}>{user.name}</li>
      ))}
    </ul>
  );
}
```

---

## 3. Zustand による軽量状態管理

### Zustand の特徴

**Zustand推奨ケース:**
- Redux ほど複雑でない中規模状態管理
- 学習コストを抑えたい
- Providerラップ不要なシンプルAPI
- TypeScript との相性が良い

```typescript
import { create } from "zustand";
import { devtools, persist } from "zustand/middleware";

interface TodoState {
  todos: { id: string; text: string; completed: boolean }[];
  addTodo: (text: string) => void;
  toggleTodo: (id: string) => void;
  removeTodo: (id: string) => void;
}

export const useTodoStore = create<TodoState>()(
  devtools(
    persist(
      (set) => ({
        todos: [],
        addTodo: (text) =>
          set((state) => ({
            todos: [...state.todos, { id: crypto.randomUUID(), text, completed: false }],
          })),
        toggleTodo: (id) =>
          set((state) => ({
            todos: state.todos.map((todo) =>
              todo.id === id ? { ...todo, completed: !todo.completed } : todo
            ),
          })),
        removeTodo: (id) =>
          set((state) => ({
            todos: state.todos.filter((todo) => todo.id !== id),
          })),
      }),
      {
        name: "todo-storage", // localStorage key
      }
    )
  )
);

// 使用例
function TodoList() {
  const todos = useTodoStore((state) => state.todos);
  const addTodo = useTodoStore((state) => state.addTodo);
  const toggleTodo = useTodoStore((state) => state.toggleTodo);

  return (
    <div>
      <ul>
        {todos.map((todo) => (
          <li key={todo.id}>
            <input
              type="checkbox"
              checked={todo.completed}
              onChange={() => toggleTodo(todo.id)}
            />
            {todo.text}
          </li>
        ))}
      </ul>
      <button onClick={() => addTodo("New Todo")}>Add</button>
    </div>
  );
}
```

---

## 4. XState によるステートマシン

### XState 推奨ケース

- 複雑なビジネスロジック（注文フロー、承認ワークフロー）
- 明確な状態遷移ルールが必要
- 状態の可視化が重要（XState Visualizer）
- 並行状態や階層状態が必要

```typescript
import { createMachine, assign } from "xstate";
import { useMachine } from "@xstate/react";

interface TrafficLightContext {
  timer: number;
}

type TrafficLightEvent =
  | { type: "TIMER" }
  | { type: "EMERGENCY_STOP" };

const trafficLightMachine = createMachine(
  {
    id: "trafficLight",
    initial: "red",
    context: { timer: 0 },
    states: {
      red: {
        on: { TIMER: "yellow" },
        entry: "resetTimer",
      },
      yellow: {
        on: { TIMER: "green" },
      },
      green: {
        on: { TIMER: "red" },
      },
    },
    on: {
      EMERGENCY_STOP: ".red",
    },
  },
  {
    actions: {
      resetTimer: assign({ timer: 0 }),
    },
  }
);

function TrafficLight() {
  const [state, send] = useMachine(trafficLightMachine);

  useEffect(() => {
    const interval = setInterval(() => send({ type: "TIMER" }), 3000);
    return () => clearInterval(interval);
  }, [send]);

  return (
    <div>
      <p>Current Light: {state.value}</p>
      <button onClick={() => send({ type: "EMERGENCY_STOP" })}>
        Emergency Stop
      </button>
    </div>
  );
}
```

---

## 5. リモートデータ管理の課題

### リモートデータ特有の問題

1. **ネットワークレイテンシ**: 200ms ~ 2秒の遅延
2. **セキュリティ**: クライアント側は信頼できない環境
3. **キャッシュ管理**: 新鮮さ vs パフォーマンス
4. **競合状態**: 複数ユーザーの同時操作
5. **楽観的更新**: UI即時反映 vs サーバー確認

### Server as Single Source of Truth

**基本原則:**
- サーバーのデータが常に正 (Single Source of Truth)
- クライアントはキャッシュに過ぎない
- ミューテーション後は必ずサーバーからrefetch

---

## 6. TanStack Query (React Query) の基本

### TanStack Query 推奨ケース

- サーバー状態が主体のアプリ（SPA、ダッシュボード）
- 頻繁なサーバーリクエストが発生
- キャッシュ無効化・再取得が必要
- 楽観的更新が必要

### 基本構成

```typescript
// main.tsx
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { ReactQueryDevtools } from "@tanstack/react-query-devtools";

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5 * 60 * 1000, // 5分間はキャッシュを利用
      cacheTime: 10 * 60 * 1000, // 10分間キャッシュ保持
      refetchOnWindowFocus: false,
    },
  },
});

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <YourApp />
      <ReactQueryDevtools initialIsOpen={false} />
    </QueryClientProvider>
  );
}
```

### Query（データ取得）

```typescript
interface Todo {
  id: string;
  title: string;
  completed: boolean;
}

// APIクライアント
async function fetchTodos(): Promise<Todo[]> {
  const response = await fetch("/api/todos");
  if (!response.ok) throw new Error("Failed to fetch todos");
  return response.json();
}

async function fetchTodo(id: string): Promise<Todo> {
  const response = await fetch(`/api/todos/${id}`);
  if (!response.ok) throw new Error("Failed to fetch todo");
  return response.json();
}

// カスタムフック
function useTodos() {
  return useQuery({
    queryKey: ["todos"],
    queryFn: fetchTodos,
  });
}

function useTodo(id: string) {
  return useQuery({
    queryKey: ["todo", { id }],
    queryFn: () => fetchTodo(id),
    enabled: !!id, // idが存在する場合のみクエリ実行
  });
}

// 使用例
function TodoList() {
  const { data: todos, isLoading, error } = useTodos();

  if (isLoading) return <div>Loading...</div>;
  if (error) return <div>Error: {error.message}</div>;

  return (
    <ul>
      {todos?.map((todo) => (
        <li key={todo.id}>{todo.title}</li>
      ))}
    </ul>
  );
}
```

### Mutation（データ変更）

```typescript
async function createTodo(newTodo: Omit<Todo, "id">): Promise<Todo> {
  const response = await fetch("/api/todos", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(newTodo),
  });
  if (!response.ok) throw new Error("Failed to create todo");
  return response.json();
}

async function updateTodo(todo: Todo): Promise<Todo> {
  const response = await fetch(`/api/todos/${todo.id}`, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(todo),
  });
  if (!response.ok) throw new Error("Failed to update todo");
  return response.json();
}

function useCreateTodo() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: createTodo,
    onSuccess: () => {
      // キャッシュ無効化 → 自動再取得
      queryClient.invalidateQueries({ queryKey: ["todos"] });
    },
  });
}

function useUpdateTodo() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: updateTodo,
    onSuccess: (updatedTodo) => {
      // 特定のクエリのみ無効化
      queryClient.invalidateQueries({ queryKey: ["todo", { id: updatedTodo.id }] });
      queryClient.invalidateQueries({ queryKey: ["todos"] });
    },
  });
}

// 使用例
function TodoForm() {
  const createTodo = useCreateTodo();

  const handleSubmit = (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const formData = new FormData(e.currentTarget);
    const title = formData.get("title") as string;

    createTodo.mutate({ title, completed: false });
  };

  return (
    <form onSubmit={handleSubmit}>
      <input name="title" required />
      <button type="submit" disabled={createTodo.isPending}>
        {createTodo.isPending ? "Creating..." : "Create"}
      </button>
    </form>
  );
}
```

---

## 7. TanStack Query 高度なパターン

### キャッシュ直接更新（サーバーラウンドトリップ削減）

```typescript
function useToggleTodo() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (id: string) => {
      const response = await fetch(`/api/todos/${id}/toggle`, { method: "POST" });
      if (!response.ok) throw new Error("Failed to toggle todo");
      return response.json();
    },
    onSuccess: (updatedTodo) => {
      // キャッシュを直接更新（invalidateではなくsetQueryData）
      queryClient.setQueryData<Todo[]>(["todos"], (oldTodos) =>
        oldTodos?.map((todo) => (todo.id === updatedTodo.id ? updatedTodo : todo))
      );

      queryClient.setQueryData<Todo>(["todo", { id: updatedTodo.id }], updatedTodo);
    },
  });
}
```

### 楽観的更新（Optimistic Updates）

```typescript
function useDeleteTodo() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (id: string) => {
      await fetch(`/api/todos/${id}`, { method: "DELETE" });
    },
    onMutate: async (deletedId) => {
      // 進行中のクエリをキャンセル
      await queryClient.cancelQueries({ queryKey: ["todos"] });

      // 前の値を保存（ロールバック用）
      const previousTodos = queryClient.getQueryData<Todo[]>(["todos"]);

      // 楽観的更新（即座にUIから削除）
      queryClient.setQueryData<Todo[]>(["todos"], (old) =>
        old?.filter((todo) => todo.id !== deletedId)
      );

      return { previousTodos }; // コンテキストとして返す
    },
    onError: (err, deletedId, context) => {
      // エラー時はロールバック
      if (context?.previousTodos) {
        queryClient.setQueryData<Todo[]>(["todos"], context.previousTodos);
      }
    },
    onSettled: () => {
      // 成功・失敗に関わらず、最終的にサーバーから取得
      queryClient.invalidateQueries({ queryKey: ["todos"] });
    },
  });
}
```

### 部分データの初期値（Initial Data）

```typescript
function useTodo(id: string) {
  const queryClient = useQueryClient();

  return useQuery({
    queryKey: ["todo", { id }],
    queryFn: () => fetchTodo(id),
    initialData: () => {
      // リスト取得済みなら、そこから該当アイテムを初期値として使用
      const todos = queryClient.getQueryData<Todo[]>(["todos"]);
      return todos?.find((todo) => todo.id === id);
    },
  });
}
```

### ローディング状態の最適化

```typescript
function TodoDetail({ id }: { id: string }) {
  const queryClient = useQueryClient();

  const { data: todo, isLoading, isFetching } = useQuery({
    queryKey: ["todo", { id }],
    queryFn: () => fetchTodo(id),
    initialData: () => {
      const todos = queryClient.getQueryData<Todo[]>(["todos"]);
      return todos?.find((t) => t.id === id);
    },
  });

  // isLoading: データが全くない状態（初回）
  // isFetching: バックグラウンドでフェッチ中

  if (isLoading) {
    return <div>Loading...</div>; // 初回のみ表示
  }

  // isFetchingの場合は、古いデータを表示しながらバックグラウンドで更新
  return (
    <div>
      <h2>{todo?.title}</h2>
      {isFetching && <span>(Updating...)</span>}
    </div>
  );
}
```

---

## 8. 状態管理ライブラリ選択フローチャート

```
[プロジェクト規模は？]
  ├─ 小規模（1-5画面）
  │   └─ useState + useContext
  │
  ├─ 中規模（6-20画面）
  │   ├─ サーバー状態が主 → TanStack Query + zustand
  │   └─ ローカル状態が主 → zustand または Context + useReducer
  │
  └─ 大規模（20+画面、複数チーム）
      ├─ サーバー状態が主 → TanStack Query + Redux Toolkit
      └─ ローカル状態が主 → Redux Toolkit

[特殊ケース]
  ├─ 複雑なワークフロー → XState
  ├─ タイムトラベルデバッグ必須 → Redux Toolkit
  └─ 学習コスト最小化 → zustand
```

---

## 9. 状態管理ライブラリ比較表

| ライブラリ | 学習コスト | バンドルサイズ | TypeScript | DevTools | 用途 |
|-----------|----------|--------------|-----------|---------|-----|
| **useState/useReducer** | 低 | 0 KB | ✅ | ❌ | 小規模 |
| **Context API** | 低 | 0 KB | ✅ | ❌ | グローバル状態共有 |
| **Zustand** | 低 | 3.3 KB | ✅ | ✅ | 中規模 |
| **Redux Toolkit** | 中 | 12 KB | ✅ | ✅ | 大規模 |
| **XState** | 高 | 25 KB | ✅ | ✅ | ワークフロー |
| **TanStack Query** | 中 | 13 KB | ✅ | ✅ | サーバー状態 |

---

## まとめ

### ローカル状態管理のベストプラクティス

1. **小さく始める**: useState/useReducerで十分な場合は複雑化しない
2. **Contextは慎重に**: パフォーマンスへの影響を考慮
3. **状態の分離**: UIステート vs ビジネスロジックステート vs サーバーステート
4. **型安全性**: TypeScriptで状態の型を明確に定義
5. **不変性**: Immer等を活用して状態更新を安全に

### リモートデータ管理のベストプラクティス

1. **TanStack Query推奨**: サーバー状態の標準ライブラリ
2. **キャッシュ戦略**: staleTime, cacheTime を適切に設定
3. **楽観的更新**: UX向上のため積極活用
4. **エラーハンドリング**: ロールバック戦略を常に用意
5. **ローディング状態**: isLoading vs isFetching を使い分け

**重要**: 状態管理ライブラリの選択はプロジェクト要件とチーム経験に依存します。不明な点があればユーザーに確認してください。
