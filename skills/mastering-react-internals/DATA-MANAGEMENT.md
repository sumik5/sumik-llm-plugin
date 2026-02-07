# DATA-MANAGEMENT.md - Reactデータ管理とリモートデータ戦略

## 1. ローカル状態管理の選択肢

Reactアプリケーションでのローカル状態管理には、複数のアプローチがあります。それぞれの特徴とトレードオフを理解し、プロジェクトに最適な選択をすることが重要です。

### useState + Context

最もシンプルなアプローチですが、再レンダー問題に注意が必要です。

```jsx
import { createContext, useContext, useState } from 'react';

// Context作成
const DataContext = createContext(null);

// Provider
export function DataProvider({ children }) {
  const [items, setItems] = useState([]);

  const addItem = (item) => {
    setItems(prev => [...prev, item]);
  };

  const removeItem = (id) => {
    setItems(prev => prev.filter(item => item.id !== id));
  };

  return (
    <DataContext.Provider value={{ items, addItem, removeItem }}>
      {children}
    </DataContext.Provider>
  );
}

// カスタムhook
export function useData() {
  const context = useContext(DataContext);
  if (!context) {
    throw new Error('useData must be used within DataProvider');
  }
  return context;
}

// 使用例
function ItemList() {
  const { items } = useData(); // Contextが更新されると全体が再レンダー
  return <ul>{items.map(item => <li key={item.id}>{item.name}</li>)}</ul>;
}
```

**利点**：
- シンプルで学習コストが低い
- 追加のライブラリ不要
- 小規模なアプリに最適

**欠点**：
- Contextの値が変わるとすべての購読コンポーネントが再レンダー
- 複雑な状態遷移の管理が難しい
- DevToolsのサポートが限定的

### useReducer + Immer

複雑な状態遷移をイミュータブルに管理しつつ、ミュータブルな書き方ができます。

```jsx
import { useReducer } from 'react';
import { produce } from 'immer';

// Reducerの定義
function dataReducer(state, action) {
  // Immerを使ってイミュータブル更新をミュータブルな書き方で実現
  return produce(state, (draft) => {
    switch (action.type) {
      case 'ADD_ITEM':
        draft.items.push(action.payload);
        break;
      case 'REMOVE_ITEM':
        draft.items = draft.items.filter(item => item.id !== action.payload);
        break;
      case 'TOGGLE_ITEM':
        const item = draft.items.find(item => item.id === action.payload);
        if (item) {
          item.done = !item.done;
          item.done ? item.doneAt.push(Date.now()) : item.doneAt.pop();
        }
        break;
      case 'UPDATE_ITEM':
        const index = draft.items.findIndex(item => item.id === action.payload.id);
        if (index !== -1) {
          draft.items[index] = { ...draft.items[index], ...action.payload.updates };
        }
        break;
      default:
        break;
    }
  });
}

// 初期状態
const initialState = {
  items: [],
  filter: 'all',
  loading: false
};

// 使用例
function App() {
  const [state, dispatch] = useReducer(dataReducer, initialState);

  const addItem = (item) => {
    dispatch({ type: 'ADD_ITEM', payload: item });
  };

  const toggleItem = (id) => {
    dispatch({ type: 'TOGGLE_ITEM', payload: id });
  };

  return (
    <div>
      <ItemList items={state.items} onToggle={toggleItem} />
    </div>
  );
}
```

**利点**：
- 複雑な状態遷移を明確に管理
- Immerにより、ミュータブルな書き方でイミュータブル更新が可能
- 状態更新のロジックが一箇所に集約

**欠点**：
- ボイラープレートが増える
- 小規模なアプリには過剰

### Redux Toolkit (RTK)

スライス単位で状態を整理し、充実したDevToolsを活用できます。

```jsx
import { configureStore, createSlice } from '@reduxjs/toolkit';
import { Provider, useSelector, useDispatch } from 'react-redux';

// Slice定義（Immerが自動で有効）
const dataSlice = createSlice({
  name: 'data',
  initialState: {
    items: [],
    filter: 'all',
    loading: false
  },
  reducers: {
    addItem: (state, action) => {
      // Immerが自動で有効なので、ミュータブルな書き方でOK
      state.items.push(action.payload);
    },
    removeItem: (state, action) => {
      state.items = state.items.filter(item => item.id !== action.payload);
    },
    toggleItem: (state, action) => {
      const item = state.items.find(item => item.id === action.payload);
      if (item) {
        item.done = !item.done;
        item.done ? item.doneAt.push(Date.now()) : item.doneAt.pop();
      }
    },
    setFilter: (state, action) => {
      state.filter = action.payload;
    },
    setLoading: (state, action) => {
      state.loading = action.payload;
    }
  }
});

// Actions
export const { addItem, removeItem, toggleItem, setFilter, setLoading } = dataSlice.actions;

// Store作成
const store = configureStore({
  reducer: {
    data: dataSlice.reducer
  }
});

// App
function App() {
  return (
    <Provider store={store}>
      <ItemList />
    </Provider>
  );
}

// コンポーネント
function ItemList() {
  const items = useSelector(state => state.data.items);
  const filter = useSelector(state => state.data.filter);
  const dispatch = useDispatch();

  const filteredItems = items.filter(item => {
    if (filter === 'all') return true;
    if (filter === 'active') return !item.done;
    if (filter === 'completed') return item.done;
  });

  return (
    <ul>
      {filteredItems.map(item => (
        <li key={item.id}>
          <input
            type="checkbox"
            checked={item.done}
            onChange={() => dispatch(toggleItem(item.id))}
          />
          {item.name}
        </li>
      ))}
    </ul>
  );
}
```

**利点**：
- スライス単位の整理で大規模アプリに最適
- Redux DevToolsによる強力なデバッグ機能
- Immerが組み込まれている
- ミドルウェア（redux-thunk等）によるサイドエフェクト管理

**欠点**：
- 学習コストが高い
- 小規模なアプリには過剰
- ボイラープレートがある（Redux無印よりは少ない）

### zustand

最小限のボイラープレートで柔軟な状態管理を実現します。

```jsx
import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { immer } from 'zustand/middleware/immer';

// Store作成（Immer + Persist統合）
export const useDataStore = create(
  persist(
    immer((set) => ({
      // 初期状態
      items: [],
      filter: 'all',
      loading: false,

      // アクション
      addItem: (item) => set((state) => {
        state.items.push(item);
      }),

      removeItem: (id) => set((state) => {
        state.items = state.items.filter(item => item.id !== id);
      }),

      toggleItem: (id) => set((state) => {
        const item = state.items.find(item => item.id === id);
        if (item) {
          item.done = !item.done;
          item.done ? item.doneAt.push(Date.now()) : item.doneAt.pop();
        }
      }),

      setFilter: (filter) => set({ filter }),

      setLoading: (loading) => set({ loading }),

      // 複合アクション
      clearCompleted: () => set((state) => {
        state.items = state.items.filter(item => !item.done);
      })
    })),
    {
      name: 'app-data', // localStorageのキー
      partialize: (state) => ({ items: state.items }) // 永続化する部分のみ選択
    }
  )
);

// 使用例
function ItemList() {
  // 必要な状態とアクションのみ選択（細かい粒度で購読可能）
  const items = useDataStore(state => state.items);
  const filter = useDataStore(state => state.filter);
  const toggleItem = useDataStore(state => state.toggleItem);

  const filteredItems = items.filter(item => {
    if (filter === 'all') return true;
    if (filter === 'active') return !item.done;
    if (filter === 'completed') return item.done;
  });

  return (
    <ul>
      {filteredItems.map(item => (
        <li key={item.id}>
          <input
            type="checkbox"
            checked={item.done}
            onChange={() => toggleItem(item.id)}
          />
          {item.name}
        </li>
      ))}
    </ul>
  );
}

// Reactの外からもアクセス可能
export function addItemFromOutside(item) {
  useDataStore.getState().addItem(item);
}
```

**利点**：
- 最小限のボイラープレート
- 学習コストが低い
- Immer統合が簡単
- React外からもアクセス可能
- 細かい粒度で購読できる（不要な再レンダーを避けられる）
- middlewareによる拡張が柔軟

**欠点**：
- Redux DevToolsのサポートは限定的（middlewareで追加可能）
- 大規模チームでの標準化が難しい場合がある

### XState

有限状態マシン（Finite State Machine）による厳密なフロー管理を実現します。

```jsx
import { createMachine, assign } from 'xstate';
import { useMachine } from '@xstate/react';

// ステートマシン定義
export const appMachine = createMachine({
  id: 'app',
  context: {
    items: [],
    currentItem: null,
    error: null
  },
  initial: 'list',
  states: {
    list: {
      on: {
        SELECT_ITEM: {
          target: 'single',
          actions: assign({
            currentItem: (context, event) =>
              context.items.find(item => item.id === event.id)
          })
        },
        ADD_ITEM: {
          target: 'adding'
        },
        TOGGLE_ITEM: {
          target: 'list',
          actions: assign({
            items: (context, event) =>
              context.items.map(item =>
                item.id === event.id
                  ? { ...item, done: !item.done, doneAt: item.done ? [] : [Date.now()] }
                  : item
              )
          })
        }
      }
    },
    single: {
      on: {
        SEE_ALL: {
          target: 'list',
          actions: assign({
            currentItem: null
          })
        },
        DELETE_ITEM: {
          target: 'deleting'
        }
      }
    },
    adding: {
      invoke: {
        src: 'addItem',
        onDone: {
          target: 'list',
          actions: assign({
            items: (context, event) => [...context.items, event.data]
          })
        },
        onError: {
          target: 'list',
          actions: assign({
            error: (context, event) => event.data
          })
        }
      }
    },
    deleting: {
      invoke: {
        src: 'deleteItem',
        onDone: {
          target: 'list',
          actions: assign({
            items: (context, event) =>
              context.items.filter(item => item.id !== event.data.id),
            currentItem: null
          })
        },
        onError: {
          target: 'single',
          actions: assign({
            error: (context, event) => event.data
          })
        }
      }
    }
  }
}, {
  services: {
    addItem: async (context, event) => {
      const response = await fetch('/api/items', {
        method: 'POST',
        body: JSON.stringify(event.item)
      });
      return response.json();
    },
    deleteItem: async (context, event) => {
      await fetch(`/api/items/${context.currentItem.id}`, {
        method: 'DELETE'
      });
      return { id: context.currentItem.id };
    }
  }
});

// 使用例
function App() {
  const [state, send] = useMachine(appMachine);

  return (
    <div>
      {state.matches('list') && (
        <ItemList
          items={state.context.items}
          onSelect={(id) => send({ type: 'SELECT_ITEM', id })}
          onToggle={(id) => send({ type: 'TOGGLE_ITEM', id })}
          onAdd={() => send({ type: 'ADD_ITEM' })}
        />
      )}

      {state.matches('single') && (
        <ItemDetail
          item={state.context.currentItem}
          onBack={() => send({ type: 'SEE_ALL' })}
          onDelete={() => send({ type: 'DELETE_ITEM' })}
        />
      )}

      {state.matches('adding') && <div>Adding item...</div>}
      {state.matches('deleting') && <div>Deleting item...</div>}

      {state.context.error && (
        <div className="error">{state.context.error.message}</div>
      )}
    </div>
  );
}
```

**利点**：
- 複雑なワークフローを明確にモデル化
- 不可能な状態遷移を防げる
- ビジュアライザーで状態遷移を視覚化
- 非同期処理の統合が自然
- テストしやすい

**欠点**：
- 学習曲線が急
- ボイラープレートが多い
- シンプルなアプリには過剰
- コード量が増える

---

## 2. 状態管理選定マトリクス

| ライブラリ | ボイラープレート | 学習コスト | DevTools | 推奨用途 |
|-----------|----------------|-----------|---------|---------|
| useState+Context | 少 | 低 | 基本のみ | 小規模、プロトタイプ、シンプルな状態 |
| useReducer+Immer | 少 | 中 | 基本のみ | 中規模、複雑なstate遷移、Contextと組合せ |
| Redux Toolkit | 中 | 高 | 優秀 | 大規模、チーム開発、標準化重視 |
| zustand | 最小 | 低 | 良好 | 柔軟性重視、素早い開発、中小規模 |
| XState | 多 | 高 | 優秀 | 複雑なワークフロー、有限状態、厳密な制御 |

### 選定フローチャート

```
プロジェクト規模は？
  ├─ 小規模（1-2画面）
  │   └─ useState + Context
  │
  ├─ 中規模（3-10画面）
  │   ├─ 複雑な状態遷移がある？
  │   │   ├─ Yes → useReducer + Immer または XState
  │   │   └─ No → zustand
  │   │
  │   └─ チーム開発で標準化が必要？
  │       └─ Yes → Redux Toolkit
  │
  └─ 大規模（10画面以上）
      ├─ 複雑なワークフロー・厳密な制御が必要？
      │   └─ Yes → XState
      │
      └─ 一般的な状態管理
          ├─ チーム標準がある → その標準に従う
          ├─ 柔軟性重視 → zustand
          └─ エコシステム重視 → Redux Toolkit
```

---

## 3. TanStack Queryによるリモートデータ管理

サーバー状態（リモートデータ）は、クライアント状態とは異なる性質を持ちます。TanStack Query（旧React Query）は、サーバー状態管理に特化したライブラリです。

### アーキテクチャ

```
QueryClient（中央管理）
  ├─ Queries（読み取り：GET）
  │   ├─ キャッシュ管理
  │   ├─ 自動再フェッチ
  │   ├─ バックグラウンド更新
  │   └─ Stale/Fresh状態
  │
  └─ Mutations（書き込み：POST/PUT/DELETE）
      ├─ 楽観的更新
      ├─ ロールバック
      └─ キャッシュ無効化
```

### 基本的なQuery

```jsx
import { useQuery, QueryClient, QueryClientProvider } from '@tanstack/react-query';

// QueryClient作成
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 60 * 5, // 5分間はデータをフレッシュとみなす
      cacheTime: 1000 * 60 * 10, // 10分間キャッシュを保持
      retry: 3, // 失敗時に3回リトライ
      refetchOnWindowFocus: true, // ウィンドウフォーカス時に再フェッチ
    }
  }
});

// App
function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <ItemList />
    </QueryClientProvider>
  );
}

// API関数
async function fetchItems() {
  const response = await fetch('/api/items');
  if (!response.ok) {
    throw new Error('Failed to fetch items');
  }
  return response.json();
}

// カスタムhook
function useAllItems() {
  return useQuery({
    queryKey: ['items'], // キャッシュのキー
    queryFn: fetchItems, // データ取得関数
  });
}

// コンポーネント
function ItemList() {
  const { data: items = [], isLoading, error, refetch } = useAllItems();

  if (isLoading) return <div>Loading...</div>;
  if (error) return <div>Error: {error.message}</div>;

  return (
    <div>
      <button onClick={() => refetch()}>Refresh</button>
      <ul>
        {items.map(item => (
          <li key={item.id}>{item.name}</li>
        ))}
      </ul>
    </div>
  );
}
```

### Mutationとキャッシュ更新

```jsx
import { useMutation, useQueryClient } from '@tanstack/react-query';

// API関数
async function addItem(newItem) {
  const response = await fetch('/api/items', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(newItem)
  });
  if (!response.ok) {
    throw new Error('Failed to add item');
  }
  return response.json();
}

async function deleteItem(id) {
  const response = await fetch(`/api/items/${id}`, {
    method: 'DELETE'
  });
  if (!response.ok) {
    throw new Error('Failed to delete item');
  }
}

// コンポーネント
function ItemManager() {
  const queryClient = useQueryClient();
  const { data: items = [] } = useAllItems();

  // アイテム追加
  const addMutation = useMutation({
    mutationFn: addItem,
    onSuccess: () => {
      // キャッシュを無効化して再フェッチ
      queryClient.invalidateQueries({ queryKey: ['items'] });
    }
  });

  // アイテム削除
  const deleteMutation = useMutation({
    mutationFn: deleteItem,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['items'] });
    }
  });

  const handleAdd = () => {
    addMutation.mutate({ name: 'New Item', done: false });
  };

  const handleDelete = (id) => {
    deleteMutation.mutate(id);
  };

  return (
    <div>
      <button onClick={handleAdd} disabled={addMutation.isPending}>
        {addMutation.isPending ? 'Adding...' : 'Add Item'}
      </button>

      {addMutation.isError && (
        <div className="error">Error: {addMutation.error.message}</div>
      )}

      <ul>
        {items.map(item => (
          <li key={item.id}>
            {item.name}
            <button
              onClick={() => handleDelete(item.id)}
              disabled={deleteMutation.isPending}
            >
              Delete
            </button>
          </li>
        ))}
      </ul>
    </div>
  );
}
```

### 楽観的更新パターン（重要）

楽観的更新は、サーバーのレスポンスを待たずにUIを即座に更新する手法です。UX向上に効果的ですが、エラー時のロールバックが必要です。

```jsx
function useOptimisticMutation() {
  const queryClient = useQueryClient();

  // アイテム追加（楽観的更新）
  const addItemMutation = useMutation({
    mutationFn: async (newItem) => {
      const response = await fetch('/api/items', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(newItem)
      });
      if (!response.ok) throw new Error('Failed to add item');
      return response.json();
    },

    // Mutation実行前（楽観的更新）
    onMutate: async (newItem) => {
      // 進行中のクエリをキャンセル（競合を避ける）
      await queryClient.cancelQueries({ queryKey: ['items'] });

      // 現在のデータを保存（ロールバック用）
      const previousItems = queryClient.getQueryData(['items']);

      // 楽観的更新: 一時IDで即座にUIに反映
      queryClient.setQueryData(['items'], (old = []) => [
        ...old,
        { id: `temp-${Date.now()}`, ...newItem, optimistic: true }
      ]);

      // contextとして返す（onErrorとonSuccessで使用）
      return { previousItems };
    },

    // エラー時（ロールバック）
    onError: (error, newItem, context) => {
      console.error('Failed to add item:', error);
      // 保存しておいた元のデータに戻す
      if (context?.previousItems) {
        queryClient.setQueryData(['items'], context.previousItems);
      }
    },

    // 成功時（サーバーレスポンスで置き換え）
    onSuccess: (serverItem, newItem, context) => {
      // 一時IDのアイテムをサーバーから返された正式なデータで置き換え
      queryClient.setQueryData(['items'], (old = []) => {
        return old.map(item =>
          item.optimistic ? serverItem : item
        );
      });
    },

    // 完了時（成功・失敗問わず）
    onSettled: () => {
      // 念のため再フェッチして同期を保証
      queryClient.invalidateQueries({ queryKey: ['items'] });
    }
  });

  // アイテム削除（楽観的更新）
  const deleteItemMutation = useMutation({
    mutationFn: async (id) => {
      const response = await fetch(`/api/items/${id}`, { method: 'DELETE' });
      if (!response.ok) throw new Error('Failed to delete item');
    },

    onMutate: async (id) => {
      await queryClient.cancelQueries({ queryKey: ['items'] });
      const previousItems = queryClient.getQueryData(['items']);

      // 楽観的更新: 即座に削除
      queryClient.setQueryData(['items'], (old = []) =>
        old.filter(item => item.id !== id)
      );

      return { previousItems };
    },

    onError: (error, id, context) => {
      console.error('Failed to delete item:', error);
      if (context?.previousItems) {
        queryClient.setQueryData(['items'], context.previousItems);
      }
    },

    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: ['items'] });
    }
  });

  // トグル（楽観的更新）
  const toggleItemMutation = useMutation({
    mutationFn: async ({ id, done }) => {
      const response = await fetch(`/api/items/${id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ done })
      });
      if (!response.ok) throw new Error('Failed to toggle item');
      return response.json();
    },

    onMutate: async ({ id, done }) => {
      await queryClient.cancelQueries({ queryKey: ['items'] });
      const previousItems = queryClient.getQueryData(['items']);

      // 楽観的更新: 即座に状態変更
      queryClient.setQueryData(['items'], (old = []) =>
        old.map(item =>
          item.id === id
            ? { ...item, done, doneAt: done ? [...item.doneAt, Date.now()] : item.doneAt.slice(0, -1) }
            : item
        )
      );

      return { previousItems };
    },

    onError: (error, variables, context) => {
      console.error('Failed to toggle item:', error);
      if (context?.previousItems) {
        queryClient.setQueryData(['items'], context.previousItems);
      }
    },

    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: ['items'] });
    }
  });

  return {
    addItem: addItemMutation.mutate,
    deleteItem: deleteItemMutation.mutate,
    toggleItem: toggleItemMutation.mutate,
    isLoading: addItemMutation.isPending || deleteItemMutation.isPending || toggleItemMutation.isPending
  };
}

// 使用例
function ItemManager() {
  const { data: items = [] } = useAllItems();
  const { addItem, deleteItem, toggleItem, isLoading } = useOptimisticMutation();

  return (
    <div>
      <button onClick={() => addItem({ name: 'New Task', done: false })}>
        Add Item
      </button>

      <ul>
        {items.map(item => (
          <li key={item.id} style={{ opacity: item.optimistic ? 0.5 : 1 }}>
            <input
              type="checkbox"
              checked={item.done}
              onChange={() => toggleItem({ id: item.id, done: !item.done })}
            />
            {item.name}
            {item.optimistic && <span> (Saving...)</span>}
            <button onClick={() => deleteItem(item.id)}>Delete</button>
          </li>
        ))}
      </ul>

      {isLoading && <div>Processing...</div>}
    </div>
  );
}
```

### リアクティブキャッシュ: 部分データの活用

TanStack Queryのキャッシュはリアクティブなので、すでに取得したデータを活用して追加のリクエストを減らせます。

```jsx
// すべてのアイテムを取得
function useAllItems() {
  return useQuery({
    queryKey: ['items'],
    queryFn: fetchItems,
  });
}

// 特定のアイテムを取得（キャッシュから初期データを取得）
function useItem(id) {
  const queryClient = useQueryClient();

  return useQuery({
    queryKey: ['items', id],
    queryFn: () => fetchItemById(id),

    // 初期データをキャッシュから取得（ローダー表示をスキップ）
    initialData: () => {
      const allItems = queryClient.getQueryData(['items']);
      return allItems?.find(item => item.id === id);
    },

    // 初期データがあっても一定時間後に再フェッチ
    initialDataUpdatedAt: () =>
      queryClient.getQueryState(['items'])?.dataUpdatedAt,
  });
}

// 使用例
function ItemDetail({ id }) {
  const { data: item, isLoading } = useItem(id);

  // キャッシュに存在すればローダーなしで即座に表示
  // バックグラウンドで最新データを取得して自動更新

  if (isLoading && !item) return <div>Loading...</div>;
  if (!item) return <div>Item not found</div>;

  return (
    <div>
      <h1>{item.name}</h1>
      <p>Status: {item.done ? 'Done' : 'Active'}</p>
    </div>
  );
}
```

---

## 4. ユーザー確認の原則

データ管理戦略を決定する際、以下の原則に従ってユーザーに確認すべきかを判断します。

### 確認すべき場面

以下の決定はプロジェクト固有の要素が多いため、必ずユーザーに確認してください：

1. **状態管理ライブラリの選択**
   - プロジェクト規模（小/中/大）
   - チームの技術スタック
   - 既存コードベースとの整合性
   - チーム標準の有無

   確認例：
   ```
   状態管理ライブラリを選択してください：

   1. useState + Context（小規模・シンプル）
   2. useReducer + Immer（中規模・複雑な遷移）
   3. Redux Toolkit（大規模・チーム標準）
   4. zustand（柔軟性重視・素早い開発）
   5. XState（複雑なワークフロー・厳密な制御）

   プロジェクトの規模と要件を教えてください。
   ```

2. **サーバー状態管理の方針**
   - TanStack Query vs SWR vs 独自実装
   - 楽観的更新の適用範囲
   - キャッシュ戦略

   確認例：
   ```
   サーバー状態管理のアプローチを選択してください：

   1. TanStack Query（推奨: 強力なキャッシュ・楽観的更新）
   2. SWR（軽量・シンプル）
   3. 独自実装（useEffect + fetch）

   パフォーマンス要件とチーム経験を考慮して選択してください。
   ```

### 確認不要な場面

以下はベストプラクティスまたは標準的なパターンであり、確認なしで適用できます：

1. **Immerによるイミュータブル更新の採用**
   - useReducer、Redux Toolkit、zustandすべてでImmerを活用するのが標準

2. **楽観的更新パターンの構造**
   - onMutate → onError → onSuccess → onSettledの標準的なフロー

3. **依存配列のstable values**
   - setState、dispatch、refは依存配列に含めない

4. **TanStack Queryのデフォルト設定**
   - staleTime、cacheTime、retryなどの基本設定

---

## まとめ

Reactのデータ管理は、以下の原則に従って適切に選択してください：

1. **クライアント状態とサーバー状態を分離する**
   - クライアント状態: useState/useReducer/Redux/zustand/XState
   - サーバー状態: TanStack Query/SWR

2. **プロジェクト規模に応じて選択する**
   - 小規模: useState + Context
   - 中規模: useReducer + Immer または zustand
   - 大規模: Redux Toolkit または zustand
   - 複雑なワークフロー: XState

3. **Immerを活用する**
   - イミュータブル更新をミュータブルな書き方で実現
   - コードの可読性と保守性が向上

4. **楽観的更新でUXを向上させる**
   - サーバーレスポンスを待たずにUIを更新
   - エラー時のロールバックを忘れずに実装

5. **リアクティブキャッシュを活用する**
   - TanStack Queryのキャッシュから初期データを取得
   - ローダー表示をスキップして高速なUI遷移

**重要**: 技術選定はプロジェクト要件、チーム経験、既存コードベースに依存します。不明な点があれば必ずユーザーに確認してください。
