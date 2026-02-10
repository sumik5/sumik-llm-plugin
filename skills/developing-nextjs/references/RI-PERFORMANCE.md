# PERFORMANCE.md - Reactパフォーマンス最適化の深い理解

## 1. Reactレンダリングの基本原理

### レンダリングの3つのトリガー

Reactコンポーネントがレンダリングされるのは、以下の3つの場面のみです：

1. **コンポーネントのマウント時（初回レンダリング）**
   - コンポーネントがDOMに初めて追加される時

2. **親コンポーネントの再レンダー時**
   - 親がレンダリングされると、子も自動的にレンダリングされる

3. **hookによる再レンダーフラグが立った時**
   - `useState`のsetter関数が呼ばれた時
   - `useReducer`のdispatchが実行された時
   - Contextの値が変更された時

### 重要な誤解の訂正

**❌ 間違った理解**: 「プロパティの変更がレンダリングを引き起こす」

**✅ 正しい理解**: プロパティの変更自体はレンダリングのトリガーではありません。親コンポーネントが再レンダーされるから、新しいプロパティで子コンポーネントも再レンダーされるのです。

```jsx
// 親コンポーネント
function Parent() {
  const [count, setCount] = useState(0);

  // countが変更 → Parentが再レンダー → Childも再レンダー
  return <Child value={count} />;
}

// 子コンポーネント
// valueプロパティの変更がトリガーではなく、
// 親の再レンダーがトリガーである
function Child({ value }) {
  console.log('Child rendered');
  return <div>{value}</div>;
}
```

### Strict Modeでの二重呼び出し

開発モードでReact Strict Modeが有効な場合、以下が二重に呼び出されます：

- コンポーネント関数本体
- `useState`の初期化関数
- `useMemo`、`useCallback`のコールバック関数

これは意図的な動作で、副作用の検出とバグの早期発見を目的としています。本番環境では発生しません。

---

## 2. メモ化戦略

Reactのメモ化には3つの主要なAPI：`memo()`、`useMemo`、`useCallback`があります。

### `memo()`: コンポーネント全体のメモ化

コンポーネント全体をメモ化し、プロパティが変更されない限り再レンダーをスキップします。

```jsx
import { memo } from 'react';

// メモ化なし: 親が再レンダーされるたびに再レンダーされる
function Items({ items }) {
  console.log('Items rendered');
  return (
    <ul>
      {items.map(todo => (
        <li key={todo}>{todo}</li>
      ))}
    </ul>
  );
}

// メモ化あり: itemsが変更されない限り再レンダーをスキップ
const Items = memo(function Items({ items }) {
  console.log('Items rendered');
  return (
    <ul>
      {items.map(todo => (
        <li key={todo}>{todo}</li>
      ))}
    </ul>
  );
});
```

**使用場面**：
- 大規模なリストコンポーネント
- 高コストなレンダリングを持つコンポーネント
- 頻繁に親が再レンダーされるが、プロパティはあまり変わらないコンポーネント

### `useMemo`: 値のメモ化

高コストな計算結果をメモ化し、依存値が変更されない限り再計算をスキップします。

```jsx
import { useMemo } from 'react';

function TodoList({ items }) {
  // 高コスト計算のメモ化
  const sortedItems = useMemo(() => {
    console.log('Sorting items...');
    return [...items].sort((a, b) => a.priority - b.priority);
  }, [items]);

  // オブジェクト/配列の安定化（メモ化コンポーネントへのprop渡し用）
  const allItems = useMemo(
    () => ["Complete todo list", ...items],
    [items]
  );

  return <Items items={allItems} />;
}
```

**使用場面**：
1. **高コスト計算**: ソート、フィルタリング、変換など
2. **オブジェクト/配列の安定化**: メモ化コンポーネントにインラインオブジェクト/配列をpropとして渡す場合

**注意**: シンプルな計算には使わない（メモ化自体のコストの方が高い場合がある）

### `useCallback`: 関数のメモ化

関数をメモ化し、依存値が変更されない限り同じ関数インスタンスを返します。

```jsx
import { useCallback, memo } from 'react';

function TodoList() {
  const [items, setItems] = useState([]);

  // メモ化なし: 毎回新しい関数が作られる
  const onDelete = (item) => {
    setItems(list => list.filter(i => i !== item));
  };

  // メモ化あり: 同じ関数インスタンスが保持される
  const onDelete = useCallback(
    (item) => {
      setItems(list => list.filter(i => i !== item));
    },
    [] // setItemsはstableなので依存配列に含めない
  );

  return <MemoizedItem onDelete={onDelete} />;
}

const MemoizedItem = memo(function Item({ onDelete }) {
  // onDeleteが同じインスタンスなら再レンダーされない
  return <button onClick={onDelete}>Delete</button>;
});
```

**使用場面**：
- メモ化されたコンポーネントにコールバック関数を渡す場合
- 関数がuseEffectやuseMemoの依存配列に含まれる場合

### メモ化判断テーブル

| シナリオ | memo() | useMemo | useCallback |
|---------|--------|---------|-------------|
| 大規模リストコンポーネント | ✅ | ❌ | ❌ |
| 高コスト計算結果 | ❌ | ✅ | ❌ |
| インラインオブジェクト/配列のprop | ❌ | ✅ | ❌ |
| メモ化コンポーネントへのコールバック | ❌ | ❌ | ✅ |
| シンプルなコンポーネント（1-2秒未満のレンダリング） | ❌ | ❌ | ❌ |
| 関数がuseEffectの依存配列に含まれる | ❌ | ❌ | ✅ |

### 実践的な例

```jsx
import { useState, useMemo, useCallback, memo } from 'react';

function App() {
  const [items, setItems] = useState([]);
  const [filter, setFilter] = useState('all');

  // 高コストなフィルタリング処理をメモ化
  const filteredItems = useMemo(() => {
    console.log('Filtering items...');
    return items.filter(item => {
      if (filter === 'all') return true;
      if (filter === 'active') return !item.done;
      if (filter === 'completed') return item.done;
    });
  }, [items, filter]);

  // コールバック関数をメモ化（メモ化コンポーネントに渡すため）
  const onToggle = useCallback((id) => {
    setItems(prev => prev.map(item =>
      item.id === id ? { ...item, done: !item.done } : item
    ));
  }, []);

  const onDelete = useCallback((id) => {
    setItems(prev => prev.filter(item => item.id !== id));
  }, []);

  return (
    <div>
      <FilterButtons filter={filter} setFilter={setFilter} />
      <ItemList items={filteredItems} onToggle={onToggle} onDelete={onDelete} />
    </div>
  );
}

// リストコンポーネント全体をメモ化
const ItemList = memo(function ItemList({ items, onToggle, onDelete }) {
  console.log('ItemList rendered');
  return (
    <ul>
      {items.map(item => (
        <Item
          key={item.id}
          item={item}
          onToggle={onToggle}
          onDelete={onDelete}
        />
      ))}
    </ul>
  );
});

// 個別のアイテムもメモ化
const Item = memo(function Item({ item, onToggle, onDelete }) {
  console.log('Item rendered:', item.id);
  return (
    <li>
      <input
        type="checkbox"
        checked={item.done}
        onChange={() => onToggle(item.id)}
      />
      {item.text}
      <button onClick={() => onDelete(item.id)}>Delete</button>
    </li>
  );
});
```

---

## 3. 依存配列の深い理解

`useEffect`、`useMemo`、`useCallback`は依存配列の指定方法によって動作が変わります。

### 依存配列の3つのパターン

```jsx
// パターン1: 依存配列なし - 毎回実行
useEffect(() => {
  console.log('Runs after every render');
});

// パターン2: 空配列 [] - マウント時のみ実行
useEffect(() => {
  console.log('Runs only on mount');
}, []);

// パターン3: 指定あり - 依存値変更時のみ実行
useEffect(() => {
  console.log('Runs when count changes');
}, [count]);
```

### Stable Values（依存配列に含める必要がないもの）

以下の値は常に同一のインスタンスが保持されるため、依存配列に含める必要がありません：

1. **`useState`のsetter関数**
   ```jsx
   const [count, setCount] = useState(0);

   const increment = useCallback(() => {
     setCount(c => c + 1); // setCountは依存配列に不要
   }, []); // 空配列でOK
   ```

2. **`useRef`のrefオブジェクト**
   ```jsx
   const ref = useRef(null);

   useEffect(() => {
     ref.current.focus(); // refは依存配列に不要
   }, []); // 空配列でOK
   ```

3. **`useReducer`のdispatch関数**
   ```jsx
   const [state, dispatch] = useReducer(reducer, initialState);

   const handleAction = useCallback(() => {
     dispatch({ type: 'INCREMENT' }); // dispatchは依存配列に不要
   }, []); // 空配列でOK
   ```

### 依存配列の自動検出

`eslint-plugin-react-hooks`を使用すると、依存配列の不足を自動検出できます。

```json
// .eslintrc.json
{
  "plugins": ["react-hooks"],
  "rules": {
    "react-hooks/rules-of-hooks": "error",
    "react-hooks/exhaustive-deps": "warn"
  }
}
```

警告例：
```jsx
function Example({ userId }) {
  const [user, setUser] = useState(null);

  useEffect(() => {
    fetchUser(userId).then(setUser);
  }, []); // ⚠️ Warning: 'userId' is missing in dependency array
}
```

修正：
```jsx
useEffect(() => {
  fetchUser(userId).then(setUser);
}, [userId]); // ✅ 正しい依存配列
```

### 依存配列のベストプラクティス

```jsx
function TodoItem({ item, onUpdate }) {
  // ❌ 悪い例: 関数を依存配列に含めると無限ループになる可能性
  useEffect(() => {
    if (item.needsUpdate) {
      onUpdate(item.id);
    }
  }, [item, onUpdate]); // onUpdateが毎回新しい関数だと無限ループ

  // ✅ 良い例: onUpdateをuseCallbackでメモ化するか、
  // または関数形式の更新を使う
  useEffect(() => {
    if (item.needsUpdate) {
      // IDのみを依存にし、更新ロジックを内部に持つ
      updateItem(item.id);
    }
  }, [item.id, item.needsUpdate]);
}
```

---

## 4. パフォーマンス計測

### React Developer Tools Profiler

React Developer Toolsのプロファイラーを使用して、コンポーネントのレンダリング時間を計測できます。

**使用手順**：
1. ブラウザにReact Developer Tools拡張機能をインストール
2. 開発者ツールを開き、「Profiler」タブを選択
3. 記録ボタンをクリックしてアプリを操作
4. 記録を停止して結果を分析

**確認すべき指標**：
- **Commit duration**: レンダリングにかかった時間
- **Render count**: 各コンポーネントが何回レンダリングされたか
- **Flame graph**: どのコンポーネントが時間を消費しているか

### 16msルール（60fps維持）

スムーズなユーザー体験を実現するには、1フレームを16ms以内に収める必要があります（60fps）。

```
1秒 ÷ 60フレーム = 約16.67ms/フレーム
```

**判断基準**：
- **16ms未満**: 最適化不要
- **16-50ms**: ユーザーは遅延を感じ始める → 最適化を検討
- **50ms以上**: 明らかに遅い → 最優先で最適化

### コンポーネント部分メモ化 vs 全体メモ化

大きなコンポーネントをメモ化するかどうかの判断：

**部分メモ化（推奨）**：
```jsx
function LargeComponent({ data }) {
  const [localState, setLocalState] = useState(0);

  // 変更されない部分のみメモ化
  const heavyPart = useMemo(() => (
    <HeavySubComponent data={data} />
  ), [data]);

  return (
    <div>
      {heavyPart}
      <button onClick={() => setLocalState(s => s + 1)}>
        Count: {localState}
      </button>
    </div>
  );
}
```

**全体メモ化**：
```jsx
// コンポーネント全体をメモ化
const LargeComponent = memo(function LargeComponent({ data }) {
  const [localState, setLocalState] = useState(0);

  return (
    <div>
      <HeavySubComponent data={data} />
      <button onClick={() => setLocalState(s => s + 1)}>
        Count: {localState}
      </button>
    </div>
  );
});
```

**判断基準**：
- **内部状態が頻繁に変わる**: 部分メモ化を選択（内部状態の変更で全体が再レンダーされるため、全体メモ化の意味がない）
- **内部状態がない・少ない**: 全体メモ化を選択
- **プロパティの変更頻度が低い**: 全体メモ化が効果的

### パフォーマンス最適化のチェックリスト

1. **計測する**: 推測ではなく、Profilerで実際に計測する
2. **ボトルネックを特定**: 最も時間のかかるコンポーネントを見つける
3. **適切なメモ化を選択**: memo/useMemo/useCallbackを正しく使い分ける
4. **再計測**: 最適化後に改善されたか確認する
5. **トレードオフを理解**: メモ化にもコストがある（メモリ使用量、コードの複雑さ）

---

## まとめ

Reactのパフォーマンス最適化は、以下の原則に従うことで効果的に行えます：

1. **レンダリングの仕組みを理解する**: 3つのトリガーを把握し、不要な再レンダーを避ける
2. **計測してから最適化する**: 推測ではなくProfilerで実測する
3. **適切なメモ化を選択する**: memo/useMemo/useCallbackを正しく使い分ける
4. **依存配列を正確に指定する**: eslint-plugin-react-hooksを活用する
5. **シンプルさを保つ**: 過度な最適化はコードを複雑にするだけ

**最も重要なルール**: 早すぎる最適化は避け、まずはシンプルで読みやすいコードを書き、パフォーマンス問題が実際に発生したら計測して対処する。
