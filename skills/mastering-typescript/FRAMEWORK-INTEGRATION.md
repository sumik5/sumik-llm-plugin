# TypeScript フレームワーク統合ガイド

> TypeScriptを主要フレームワークと統合し、型安全な開発体験を実現する。

## 目次

1. [React との統合](#1-react-との統合)
2. [Angular との統合](#2-angular-との統合)
3. [Vue.js / Nuxt との統合](#3-vuejs--nuxt-との統合)
4. [Node.js / Express との統合](#4-nodejs--express-との統合)
5. [フレームワーク選択ガイド](#5-フレームワーク選択ガイド)

---

## 1. React との統合

### プロジェクトセットアップ

React は TypeScript をネイティブサポートしている。

```bash
# Vite + React + TypeScript（推奨）
npm create vite@latest my-app -- --template react-ts

# Next.js + TypeScript
npx create-next-app@latest my-app --typescript
```

### tsconfig.json（React向け）

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "jsx": "react-jsx",
    "strict": true,
    "esModuleInterop": true,
    "forceConsistentCasingInFileNames": true,
    "isolatedModules": true,
    "skipLibCheck": true
  },
  "include": ["src"]
}
```

### コンポーネントの型付け

```typescript
// Props の定義
interface GreetingProps {
  name: string;
  greeting?: string;  // オプショナル
  onClose: () => void;
}

// 関数コンポーネント
const Greeting = ({ name, greeting = 'Hello', onClose }: GreetingProps) => {
  return (
    <div>
      <p>{greeting}, {name}!</p>
      <button onClick={onClose}>Close</button>
    </div>
  );
};
```

### Hooks の型付け

```typescript
// useState
const [count, setCount] = useState<number>(0);
const [user, setUser] = useState<User | null>(null);

// useRef
const inputRef = useRef<HTMLInputElement>(null);

// useReducer
interface State {
  count: number;
  loading: boolean;
}

type Action =
  | { type: 'increment' }
  | { type: 'decrement' }
  | { type: 'setLoading'; payload: boolean };

function reducer(state: State, action: Action): State {
  switch (action.type) {
    case 'increment':
      return { ...state, count: state.count + 1 };
    case 'decrement':
      return { ...state, count: state.count - 1 };
    case 'setLoading':
      return { ...state, loading: action.payload };
  }
}

const [state, dispatch] = useReducer(reducer, { count: 0, loading: false });
```

### イベントハンドラの型付け

```typescript
// フォームイベント
const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
  e.preventDefault();
  // ...
};

// 入力イベント
const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
  setValue(e.target.value);
};

// クリックイベント
const handleClick = (e: React.MouseEvent<HTMLButtonElement>) => {
  // ...
};
```

### React 型付けのベストプラクティス

| ルール | 推奨 | 避ける |
|--------|------|--------|
| Props 定義 | `interface XxxProps` | `React.FC<Props>`（暗黙のchildren） |
| children | `React.ReactNode` を明示 | 暗黙的に含める |
| イベント | 具体的なイベント型 | `any` |
| Ref | `useRef<HTMLElement>(null)` | `useRef<any>()` |

---

## 2. Angular との統合

### プロジェクトセットアップ

Angular は TypeScript で書かれたフレームワーク。デフォルトで TypeScript 対応。

```bash
ng new my-app
```

### コンポーネントの型付け

```typescript
import { Component, Input, Output, EventEmitter } from '@angular/core';

interface UserData {
  name: string;
  email: string;
}

@Component({
  selector: 'app-user-profile',
  template: `
    <div>
      <h2>{{ user.name }}</h2>
      <p>{{ user.email }}</p>
      <button (click)="onEdit()">Edit</button>
    </div>
  `
})
export class UserProfileComponent {
  @Input() user!: UserData;
  @Output() edit = new EventEmitter<UserData>();

  onEdit(): void {
    this.edit.emit(this.user);
  }
}
```

### サービスの型付け

```typescript
import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

interface ApiResponse<T> {
  data: T;
  status: number;
}

@Injectable({ providedIn: 'root' })
export class UserService {
  constructor(private http: HttpClient) {}

  getUsers(): Observable<ApiResponse<UserData[]>> {
    return this.http.get<ApiResponse<UserData[]>>('/api/users');
  }

  getUser(id: number): Observable<ApiResponse<UserData>> {
    return this.http.get<ApiResponse<UserData>>(`/api/users/${id}`);
  }
}
```

---

## 3. Vue.js / Nuxt との統合

### Vue.js + TypeScript

```bash
npm create vue@latest my-app
# TypeScript を選択
```

### Composition API での型付け

```vue
<script setup lang="ts">
import { ref, computed } from 'vue';

interface Todo {
  id: number;
  title: string;
  completed: boolean;
}

const todos = ref<Todo[]>([]);
const newTitle = ref('');

const incompleteTodos = computed(() =>
  todos.value.filter(todo => !todo.completed)
);

function addTodo(): void {
  todos.value.push({
    id: Date.now(),
    title: newTitle.value,
    completed: false,
  });
  newTitle.value = '';
}
</script>
```

### Props と Emits の型付け

```vue
<script setup lang="ts">
interface Props {
  title: string;
  count?: number;
}

const props = withDefaults(defineProps<Props>(), {
  count: 0,
});

const emit = defineEmits<{
  (e: 'update', value: number): void;
  (e: 'close'): void;
}>();
</script>
```

### Nuxt での TypeScript

```typescript
// nuxt.config.ts
export default defineNuxtConfig({
  typescript: {
    strict: true,
    typeCheck: true,
  },
});
```

```vue
<!-- pages/users/[id].vue -->
<script setup lang="ts">
interface User {
  id: number;
  name: string;
  email: string;
}

const { data: user } = await useFetch<User>(`/api/users/${route.params.id}`);
</script>
```

---

## 4. Node.js / Express との統合

### プロジェクトセットアップ

```bash
mkdir my-api && cd my-api
npm init -y
npm install express
npm install -D typescript @types/express @types/node ts-node
npx tsc --init
```

### tsconfig.json（Node.js向け）

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "commonjs",
    "moduleResolution": "node",
    "strict": true,
    "esModuleInterop": true,
    "outDir": "dist",
    "rootDir": "src",
    "sourceMap": true,
    "forceConsistentCasingInFileNames": true,
    "skipLibCheck": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
```

### Express アプリケーションの型付け

```typescript
import express, { Request, Response, NextFunction } from 'express';

const app = express();
app.use(express.json());

// 型付きリクエスト・レスポンス
interface CreateUserBody {
  name: string;
  email: string;
}

interface UserResponse {
  id: number;
  name: string;
  email: string;
}

app.post('/users', (
  req: Request<{}, UserResponse, CreateUserBody>,
  res: Response<UserResponse>
) => {
  const { name, email } = req.body;
  const newUser: UserResponse = { id: Date.now(), name, email };
  res.json(newUser);
});
```

### RESTful API の型安全な設計

```typescript
// types.ts - API型定義
interface Book {
  id: number;
  title: string;
  author: string;
}

type CreateBookInput = Omit<Book, 'id'>;
type UpdateBookInput = Partial<CreateBookInput>;

// routes/books.ts
import { Router, Request, Response } from 'express';

const router = Router();
let books: Book[] = [];

router.get('/', (_req: Request, res: Response<Book[]>) => {
  res.json(books);
});

router.get('/:id', (req: Request<{ id: string }>, res: Response<Book | { error: string }>) => {
  const book = books.find(b => b.id === Number(req.params.id));
  if (!book) {
    return res.status(404).json({ error: 'Book not found' });
  }
  res.json(book);
});

router.post('/', (
  req: Request<{}, Book, CreateBookInput>,
  res: Response<Book>
) => {
  const newBook: Book = { id: Date.now(), ...req.body };
  books.push(newBook);
  res.status(201).json(newBook);
});

router.put('/:id', (
  req: Request<{ id: string }, Book, UpdateBookInput>,
  res: Response<Book | { error: string }>
) => {
  const index = books.findIndex(b => b.id === Number(req.params.id));
  if (index === -1) {
    return res.status(404).json({ error: 'Book not found' });
  }
  books[index] = { ...books[index], ...req.body };
  res.json(books[index]);
});

router.delete('/:id', (req: Request<{ id: string }>, res: Response) => {
  books = books.filter(b => b.id !== Number(req.params.id));
  res.status(204).send();
});

export default router;
```

### エラーハンドリングミドルウェア

```typescript
interface AppError extends Error {
  statusCode: number;
  code: string;
}

function errorHandler(
  err: AppError,
  _req: Request,
  res: Response,
  _next: NextFunction
): void {
  const statusCode = err.statusCode || 500;
  res.status(statusCode).json({
    error: {
      message: err.message,
      code: err.code || 'INTERNAL_ERROR',
    },
  });
}

app.use(errorHandler);
```

---

## 5. フレームワーク選択ガイド

### 比較表

| 特性 | React | Angular | Vue.js | Express |
|------|-------|---------|--------|---------|
| TypeScript サポート | ネイティブ | 必須（TS製） | ネイティブ | `@types/express` |
| 型安全度 | 高 | 最高 | 高 | 中〜高 |
| 学習コスト | 低〜中 | 高 | 低 | 低 |
| エコシステム | 最大 | 大 | 中 | 最大（Node.js） |
| 推奨用途 | SPA、モバイル | エンタープライズ | 軽量SPA | API、サーバーサイド |

### TypeScript 統合の共通ベストプラクティス

| ルール | 説明 |
|--------|------|
| `strict: true` | tsconfig.jsonで常に有効化 |
| 型定義パッケージ | `@types/xxx` を必ずインストール |
| `any` 禁止 | すべてのフレームワークで共通 |
| Props/パラメータの型付け | コンポーネント/ルートハンドラの入出力を型付け |
| API レスポンスの型定義 | `interface` で定義し、フロント・バック間で共有 |
