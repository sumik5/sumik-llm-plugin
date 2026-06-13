# React 19 Actions・フォーム実装パターン

React 19 の Actions システム・フォーム送信・楽観的更新・フォーム状態管理・キャッシング戦略の実装パターンリファレンス。

---

## 目次

1. Actions 概要
2. `use server` Server Functions
3. フォーム送信・サーバーサイド検証
4. `useOptimistic` — 即時フィードバックと失敗時リバート
5. `useFormStatus` — 送信中フィードバック
6. `useActionState` — マルチステップ・リセット/復旧
7. React 19 キャッシング戦略
8. React Query / SWR との統合（差分パターン）
9. 判断基準：パターン選択

---

## 1. Actions 概要

React 19 の **Actions** はサーバーサイド操作・フォーム送信・データ変更を宣言的に扱うパターン。ローディング状態・エラー境界・状態遷移を React が自動管理する。

| 従来パターン | Actions |
|---|---|
| `useState` でローディング管理 | 自動管理 |
| 手動でエラーハンドリング | error boundary に統合 |
| fetch → 手動で state 更新 | Server Function を直接呼び出し |
| API ルートファイルが必要 | 多くのケースで省略可能 |
| 各 API コールで重複実装 | 一貫したパターンで集約 |

Actions は自動バッチング・リクエスト重複排除・インテリジェントなキャッシングを透過的に行う。

---

## 2. `use server` Server Functions

`'use server'` ディレクティブでサーバー側で実行される関数を定義し、クライアントコードから直接呼び出せる。

### 基本的な Server Function

```typescript
// actions/users.ts
'use server'
import { db } from '@/lib/db'

export async function createUser(
  formData: FormData
): Promise<{ success: boolean; user: any }> {
  const name = formData.get('name') as string | null
  const email = formData.get('email') as string | null

  if (!name || !email) {
    throw new Error('Name and email are required')
  }

  const user = await db.user.create({
    data: { name, email },
  })

  return { success: true, user }
}
```

**サーバー側でアクセス可能なリソース**: DB・ファイルシステム・環境変数・外部 API

TypeScript は Server Function のパラメータ型・戻り値型を推論するため、API 契約のミスマッチによるランタイムエラーをコンパイル時に検出できる。

### フォームへの直接バインド

```typescript
// components/ItemForm.tsx
'use client'
import { createUser } from '../actions/users'

export default function ItemForm() {
  return (
    <form action={createUser}>
      <input name="name" placeholder="Name" required />
      <input name="email" type="email" placeholder="Email" required />
      <button type="submit">作成</button>
    </form>
  )
}
```

`<form>` の `action` 属性に Server Function を直接渡せる。プログラム的な呼び出しも可能で、イベントハンドラや他のコンポーネントロジックからも起動できる。

---

## 3. フォーム送信・サーバーサイド検証

### FormData + Zod による検証

サーバーサイドのバリデーションはクライアントでは回避できず、データ整合性とセキュリティを保証する。

```typescript
'use server'
import { z } from 'zod'
import { db } from '@/lib/db'

const userSchema = z.object({
  name: z.string().min(2).max(50),
  email: z.string().email(),
  age: z.number().min(13).max(120),
})

export async function createUser(formData: FormData): Promise<
  | { success: true; user: any }
  | { success: false; errors: ReturnType<typeof userSchema.flatten> }
> {
  try {
    const validatedData = userSchema.parse({
      name: formData.get('name') as string,
      email: formData.get('email') as string,
      age: parseInt(formData.get('age') as string, 10),
    })

    const user = await db.user.create({ data: validatedData })
    return { success: true, user }
  } catch (error) {
    if (error instanceof z.ZodError) {
      return { success: false, errors: error.flatten() }
    }
    throw error  // 予期しないエラーは error boundary へ
  }
}
```

| エラー種別 | 処理方法 |
|---|---|
| バリデーションエラー（Zod） | `{ success: false, errors }` を返して UI に表示 |
| 予期しないエラー | `throw` して error boundary で捕捉 |

### プロファイル更新 + `revalidatePath`

```typescript
'use server'
import { revalidatePath } from 'next/cache'
import { db } from '@/lib/db'

export async function updateProfile(formData: FormData) {
  const userId = formData.get('userId') as string
  const bio = formData.get('bio') as string | null

  if (!userId) throw new Error('User ID is required')

  await db.profile.update({
    where: { userId: parseInt(userId, 10) },
    data: {
      bio,
      preferences: {
        newsletter: formData.get('newsletter') === 'on',
        notifications: formData.get('notifications') === 'on',
      },
    },
  })

  revalidatePath('/profile')  // ミューテーション後にキャッシュ無効化
  return { success: true }
}
```

`revalidatePath` は Next.js のキャッシュを自動無効化する。従来の API ルートで必要だった複雑なキャッシュ管理が不要になる。

### 応答データによる UI 更新

Action は任意のシリアライズ可能データを返せる。返されたデータが React の再レンダリングを自動的にトリガーする。

```typescript
'use server'
import { revalidatePath } from 'next/cache'
import { db } from '@/lib/db'

export async function toggleFavorite(
  itemId: string,
  isFavorited: boolean
): Promise<{ success: boolean; isFavorited: boolean; favoriteCount: number }> {
  const updated = await db.item.update({
    where: { id: itemId },
    data: {
      favoriteCount: isFavorited ? { decrement: 1 } : { increment: 1 },
    },
  })

  revalidatePath('/items')

  return {
    success: true,
    isFavorited: !isFavorited,
    favoriteCount: updated.favoriteCount,
  }
}
```

---

## 4. `useOptimistic` — 即時フィードバックと失敗時リバート

楽観的 UI はサーバー確認前にインターフェースを即時更新し、知覚パフォーマンスを向上させる。`useOptimistic` はこのパターンの状態管理と失敗時のリバートを構造化する。

### 基本実装パターン

```typescript
'use client'
import { useOptimistic } from 'react'
import { addComment } from '../actions/comments'

type Comment = {
  id: string
  content: string
  author: string
  createdAt: string
  pending?: boolean
}

type CommentListProps = {
  comments: Comment[]
  currentUser: { name: string }
}

export default function CommentList({ comments, currentUser }: CommentListProps) {
  const [optimisticComments, addOptimisticComment] = useOptimistic<Comment[], Comment>(
    comments,
    (state, newComment) => [...state, newComment]  // 楽観的な状態更新関数
  )

  async function handleAddComment(formData: FormData) {
    const content = formData.get('content') as string
    if (!content) return

    // 1. 楽観的更新（即時 UI 反映）
    const optimisticComment: Comment = {
      id: `temp-${Date.now()}`,
      content,
      author: currentUser.name,
      createdAt: new Date().toISOString(),
      pending: true,
    }
    addOptimisticComment(optimisticComment)

    // 2. サーバー送信（失敗時は自動でリバート）
    try {
      await addComment(formData)
    } catch (error) {
      console.error('コメント追加に失敗しました:', error)
    }
  }

  return (
    <div>
      {optimisticComments.map(comment => (
        <div key={comment.id} style={{ opacity: comment.pending ? 0.5 : 1 }}>
          <strong>{comment.author}</strong>: {comment.content}
          {comment.pending && <span> (送信中...)</span>}
        </div>
      ))}
      <form action={handleAddComment}>
        <textarea name="content" placeholder="コメントを追加..." />
        <button type="submit">投稿</button>
      </form>
    </div>
  )
}
```

**`useOptimistic` の動作原理**:

| 状態 | 挙動 |
|---|---|
| Action 進行中 | 楽観的な状態（`optimisticComments`）を表示 |
| Action 成功 | 元の `comments` prop の確定値に自動同期 |
| Action 失敗 | 元の状態に自動リバート |

### エラーハンドリング付きカスタムフック

```typescript
import { useOptimistic, useState } from 'react'

function useOptimisticWithError<T>(
  initialState: T,
  updateFn: (state: T, value: T) => T
) {
  const [optimisticState, addOptimistic] = useOptimistic(initialState, updateFn)
  const [error, setError] = useState<string | null>(null)

  const addOptimisticWithErrorHandling = async (
    optimisticValue: T,
    serverAction: () => Promise<void>
  ) => {
    addOptimistic(optimisticValue)
    setError(null)
    try {
      await serverAction()
    } catch (err) {
      setError(err instanceof Error ? err.message : '操作に失敗しました')
      // useOptimistic が自動でリバートする
    }
  }

  return [optimisticState, addOptimisticWithErrorHandling, error] as const
}
```

エラーメッセージはコンテキストに応じた具体的な内容にする。リトライボタンや代替アクションの提示が UX を改善する。

---

## 5. `useFormStatus` — 送信中フィードバック

`useFormStatus` は**親の `<form>` の送信状態**をリアルタイムに返す。送信ボタンやローディング表示などの子コンポーネントで使用する。

```typescript
'use client'
import { useFormStatus } from 'react-dom'
import { updateProfile } from '../actions/profile'

// 送信ボタンを別コンポーネントに切り出す（重要）
function SubmitButton() {
  const { pending } = useFormStatus()

  return (
    <button
      type="submit"
      disabled={pending}
      style={{ opacity: pending ? 0.5 : 1 }}
    >
      {pending ? '保存中...' : '保存する'}
    </button>
  )
}

export default function ProfileForm() {
  return (
    <form action={updateProfile}>
      <input name="name" placeholder="氏名" />
      <input name="email" type="email" placeholder="メールアドレス" />
      <textarea name="bio" placeholder="自己紹介" />
      <SubmitButton />  {/* form の子コンポーネントとして配置 */}
    </form>
  )
}
```

> **重要な制約**: `useFormStatus` は `<form>` の**子コンポーネント**内で呼び出す必要がある。フォーム自身と同一コンポーネント内での使用は機能しない。

`useFormStatus` で取得できる値:

| プロパティ | 型 | 説明 |
|---|---|---|
| `pending` | `boolean` | 送信処理中かどうか |
| `data` | `FormData \| null` | 送信中のフォームデータ |
| `method` | `string` | HTTP メソッド |
| `action` | `string \| function` | form の action |

---

## 6. `useActionState` — マルチステップ・リセット/復旧

### マルチステップフォームの実装

`useActionState` は複数 Action とフォームステップをまたいだ状態管理を構造化する。

```typescript
'use client'
import { useActionState } from 'react'
import { validateStep, submitCompleteForm } from '../actions/formSteps'

type FormState = {
  step: number
  data: Record<string, unknown>
  errors: Record<string, string>
}

const initialState: FormState = {
  step: 1,
  data: {},
  errors: {},
}

// Server Function: 各ステップの処理
async function processFormStep(
  prevState: FormState,
  formData: FormData
): Promise<FormState> {
  const stepData = Object.fromEntries(formData.entries())
  const validation = await validateStep(prevState.step, stepData)

  // バリデーション失敗: 同ステップに留まりエラー表示
  if (!validation.success) {
    return { ...prevState, errors: validation.errors }
  }

  const updatedData = { ...prevState.data, ...stepData }

  // 最終ステップ: サーバーへ全データ送信
  if (prevState.step === 3) {
    await submitCompleteForm(updatedData)
    return { step: 4, data: updatedData, errors: {} }
  }

  // 次ステップへ進む
  return { step: prevState.step + 1, data: updatedData, errors: {} }
}

export default function MultiStepForm() {
  const [state, formAction, isPending] = useActionState<FormState, FormData>(
    processFormStep,
    initialState
  )

  return (
    <form action={formAction}>
      {state.step === 1 && <PersonalInfoStep errors={state.errors} />}
      {state.step === 2 && <AddressStep errors={state.errors} />}
      {state.step === 3 && <ReviewStep data={state.data} />}
      {state.step === 4 && <SuccessMessage />}

      {state.step < 4 && (
        <button type="submit" disabled={isPending}>
          {isPending ? '処理中...' : state.step === 3 ? '送信する' : '次へ'}
        </button>
      )}
    </form>
  )
}
```

**`useActionState` の返り値**:

| 値 | 型 | 説明 |
|---|---|---|
| `state` | `FormState` | 現在のフォーム状態（Server Function の戻り値） |
| `formAction` | `function` | `form` の `action` に渡す関数 |
| `isPending` | `boolean` | Action 実行中かどうか |

セッションをまたいだ状態保存が必要な場合は、`localStorage` / `sessionStorage` に状態を退避させる。

### フォームリセット・エラー復旧パターン

```typescript
import { useActionState, useState } from 'react'

type FormStateWithMeta<T> = T & {
  lastFormData?: FormData
  error?: string
}

export function useFormWithReset<T extends object>(
  initialState: FormStateWithMeta<T>,
  actionFn: (
    prevState: FormStateWithMeta<T>,
    formData: FormData
  ) => Promise<FormStateWithMeta<T>>
) {
  const [state, dispatch, isPending] = useActionState<FormStateWithMeta<T>, FormData>(
    actionFn,
    initialState
  )
  const [resetKey, setResetKey] = useState(0)

  // フォームを初期状態にリセット（key 変更で再マウント）
  const resetForm = () => setResetKey(prev => prev + 1)

  // 最後の操作をリトライ
  const retryLastAction = () => {
    if (state.lastFormData) {
      dispatch(state.lastFormData)
    }
  }

  return { state, dispatch, isPending, resetForm, retryLastAction, resetKey }
}

```

使用: `<form key={resetKey} action={dispatch}>` として、`resetKey` を変更することでフォームを再マウントする。フォームオートセーブは `useEffect` で定期的にフォーム状態をストレージに保存することで実装する。

---

## 7. React 19 キャッシング戦略

### `use cache` ディレクティブ（Server Component）

```typescript
// app/data/getProductData.ts
'use server'
import { db } from '@/lib/db'

export async function getProductData(productId: string) {
  'use cache'  // この関数の結果をキャッシュ

  return await db.product.findUnique({
    where: { id: productId },
    include: { reviews: true, variants: true },
  })
}
```

キャッシュキーは関数パラメータとコンポーネント props から自動生成される。手動のキャッシュ期間・無効化条件・タグの指定でより精密な制御も可能。

### タグベースのキャッシュ無効化

```typescript
'use server'
import { revalidatePath, revalidateTag } from 'next/cache'
import { db } from '@/lib/db'

export async function updatePost(postId: string, formData: FormData) {
  await db.post.update({
    where: { id: postId },
    data: {
      title: formData.get('title') as string,
      content: formData.get('content') as string,
      updatedAt: new Date(),
    },
  })

  // 関連するキャッシュをタグで選択的に無効化
  revalidateTag(`post-${postId}`)   // 個別エントリ
  revalidateTag('posts-list')        // 一覧
  revalidatePath('/posts')           // パスレベル
  revalidatePath(`/posts/${postId}`) // 個別ページ

  return { success: true }
}
```

| 無効化 API | 対象 | 用途 |
|---|---|---|
| `revalidatePath(path)` | パス配下のすべてのキャッシュ | ページ全体の更新 |
| `revalidateTag(tag)` | タグが付いたキャッシュエントリ | 関連データの選択的更新 |

タグベースの無効化は、関係のないキャッシュを過剰に破棄せずに関連データを一貫して更新できる。

### サーバーサイド vs クライアントサイドキャッシュの判断

| データ特性 | 推奨キャッシュ層 |
|---|---|
| 複数ユーザーで共有される | サーバーサイド（`use cache`） |
| DB クエリ・外部 API 結果 | サーバーサイド |
| 高コストな集計・計算 | サーバーサイド |
| ユーザー固有のデータ | クライアントサイド（React Query/SWR） |
| 頻繁にアクセスされる個人設定 | クライアントサイド |
| 初期表示 + 逐次更新 | ハイブリッド |

ハイブリッド戦略: 初期データはサーバーキャッシュで配信し、クライアントで水和後は React Query/SWR で差分管理する。

---

## 8. React Query / SWR との統合（差分パターン）

> **前提**: React Query の基本的な `useQuery` / `useMutation` / クエリキー設計は `RI-DATA-MANAGEMENT` を参照。ここでは React 19 Actions との統合差分のみ扱う。

### Actions + React Query `useMutation` の連携

```typescript
'use client'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { updateUser } from '../actions/users'

export default function UserProfile({ userId }: { userId: string }) {
  const queryClient = useQueryClient()

  const updateUserMutation = useMutation({
    mutationFn: updateUser,  // Server Action を mutationFn に渡す
    onSuccess: (data: { user: any }) => {
      // React Query のクライアントキャッシュを更新
      queryClient.invalidateQueries({ queryKey: ['user', userId] })
      queryClient.setQueryData(['user', userId], data.user)
    },
    onError: (error: unknown) => {
      console.error('更新に失敗しました:', error)
    },
  })

  const handleSubmit = async (formData: FormData) => {
    await updateUserMutation.mutateAsync(formData)
  }

  return (
    <form action={handleSubmit}>
      <input name="name" placeholder="氏名" />
      <input name="email" type="email" placeholder="メールアドレス" />
      <button type="submit" disabled={updateUserMutation.isPending}>
        {updateUserMutation.isPending ? '更新中...' : 'プロフィールを更新'}
      </button>
    </form>
  )
}
```

### キャッシュ整合性の維持

複数のキャッシュ層を使用する場合、無効化戦略を整合させる。

| キャッシュ層 | 無効化タイミング | 手段 |
|---|---|---|
| Next.js サーバーキャッシュ | Action 成功後 | `revalidatePath` / `revalidateTag` |
| React Query クライアントキャッシュ | `onSuccess` コールバック | `queryClient.invalidateQueries` |
| SWR クライアントキャッシュ | `onSuccess` コールバック | `mutate(key)` |

**重要**: 楽観的更新が失敗してリバートされた場合、React Query/SWR のキャッシュも `invalidateQueries` で整合性を確保する。バックグラウンドリフェッチのタイミングも各ライブラリで競合しないよう設定する。

---

## 9. 判断基準：パターン選択

### フォーム実装パターンの選択

| 要件 | 推奨パターン |
|---|---|
| シンプルな送信のみ | `<form action={serverFn}>` |
| 送信中のボタン無効化・ローディング表示 | `useFormStatus` |
| 送信結果でフォーム状態を更新する | `useActionState` |
| 複数ステップ・ウィザード形式 | `useActionState`（step 管理） |
| 即時 UI 反映が必要（コメント・いいね等） | `useOptimistic` + Server Action |
| 複雑なデータフェッチ・サーバー状態管理 | React Query/SWR + Actions |

### エラーハンドリング戦略

| エラー種別 | 対処法 |
|---|---|
| バリデーションエラー | Action から `{ success: false, errors }` を返し UI に表示 |
| 予期しないエラー | `throw` → error boundary で捕捉 |
| 楽観的更新の失敗 | `useOptimistic` が自動リバート + ユーザーへの通知 |
| ネットワークエラー | `useFormWithReset` でリトライ機能を提供 |

### AskUserQuestion で確認すべき判断分岐

以下の場面では推測せず `AskUserQuestion` でユーザーに確認する：

- **データ取得ライブラリ選択**: React Query vs SWR vs 組み込みキャッシングのみ。プロジェクトの既存依存・チームの習熟度によって最適解が変わる
- **楽観的更新の採用可否**: 操作の失敗率・エラー時の UX 影響・データ整合性要件によって判断が分かれる
- **マルチステップの状態保存先**: メモリのみ vs `sessionStorage` / `localStorage` への永続化。ユーザーセッション要件次第
- **キャッシュ戦略の境界線**: `use cache` のみ vs React Query 併用。アプリ規模・リアルタイム性要件によって判断が異なる

確認不要（一義的なベストプラクティス）：

- フォームに `useFormStatus` で送信中状態を表示する
- Server Action でサーバーサイドバリデーションを必ず実施する
- `revalidatePath` / `revalidateTag` でミューテーション後にキャッシュを無効化する
- バリデーションライブラリ（Zod 等）で型安全な検証を行う
