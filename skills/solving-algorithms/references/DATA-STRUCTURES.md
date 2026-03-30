# データ構造リファレンス

基本データ構造から高度なデータ構造まで、競技プログラミングで頻出の実装パターンと計算量を網羅する。

---

## 1. 基本データ構造

### 1.1 スタック (Stack)

**特性**
- LIFO (Last In First Out)：最後に追加した要素が最初に取り出される
- 配列またはリンクリストで実装可能
- 逆ポーランド記法の評価、再帰の模倣、バックトラッキングに有効

**操作と計算量**

| 操作 | 説明 | 計算量 |
|------|------|--------|
| `push(x)` | トップに要素を追加 | O(1) |
| `pop()` | トップから要素を取り出す | O(1) |
| `top()` / `peek()` | トップ要素を参照（削除しない） | O(1) |
| `isEmpty()` | 空かどうかの確認 | O(1) |

**配列による実装の核心**

```
// スタックポインタ top: 現在のトップ要素を指す（空のとき 0）
initialize(): top = 0
push(x):      S[++top] = x
pop():        return S[top--]
isEmpty():    return top == 0
```

**典型的な使用場面**
- 式評価（逆ポーランド記法）
- 括弧の対応チェック
- 深さ優先探索の非再帰実装
- undo/redo 操作

---

### 1.2 キュー (Queue)

**特性**
- FIFO (First In First Out)：最初に追加した要素が最初に取り出される
- 循環バッファ（リングバッファ）で固定メモリに効率よく実装できる
- ラウンドロビンスケジューリング、BFS に有効

**操作と計算量**

| 操作 | 説明 | 計算量 |
|------|------|--------|
| `enqueue(x)` / `push(x)` | 末尾に要素を追加 | O(1) |
| `dequeue()` / `pop()` | 先頭から要素を取り出す | O(1) |
| `front()` | 先頭要素を参照 | O(1) |
| `isEmpty()` | 空かどうかの確認 | O(1) |

**配列による実装の核心（循環バッファ）**

```
// head: 先頭インデックス、tail: 末尾+1 インデックス
initialize(): head = 0, tail = 0
enqueue(x):   Q[tail] = x; tail = (tail + 1) % MAX
dequeue():    x = Q[head]; head = (head + 1) % MAX; return x
isEmpty():    return head == tail
```

**典型的な使用場面**
- 幅優先探索 (BFS)
- ラウンドロビンスケジューリングのシミュレーション
- 処理待ちキューの管理

---

### 1.3 双方向連結リスト (Doubly Linked List)

**特性**
- 各ノードが前後のノードへのポインタを持つ
- 指定位置への挿入・削除が O(1)（ただしポインタを既知の場合）
- 配列と異なりメモリを動的に確保できる
- 番兵（sentinel）ノードを使うと境界条件を統一できる

**操作と計算量**

| 操作 | 説明 | 計算量 |
|------|------|--------|
| 先頭/末尾への挿入 | ポインタを繋ぎ替える | O(1) |
| 指定ノードの削除 | ポインタを繋ぎ替える | O(1) |
| キーによる探索 | リストを線形走査 | O(n) |
| キーによる削除 | 探索 + 削除 | O(n) |

**典型的な使用場面**
- 高等データ構造（ハッシュテーブルのチェイン等）の部品
- 挿入・削除が頻繁で探索が少ない場面
- LRU キャッシュの実装

---

## 2. 木構造 (Trees)

### 2.1 根付き木 (Rooted Tree)

**概念と用語**

```
         0           ← 根 (root)
        /|\
       1 2 3         ← 深さ 1（節点 0 の子）
      /|   /|\
     4 5  7 8 9      ← 深さ 2
       |
      11 12          ← 葉 (leaf): 子を持たない節点
```

| 用語 | 説明 |
|------|------|
| 根 (root) | 親を持たない唯一の節点 |
| 葉 (leaf) | 子を持たない節点 |
| 内部節点 | 葉でない節点 |
| 深さ (depth) | 根からその節点までの辺の数 |
| 高さ (height) | その節点から葉までの最長経路の長さ |
| 次数 (degree) | 子の数 |

**左子右兄弟表現 (Left-Child Right-Sibling)**

n個の子を持ちうる根付き木を、固定サイズで表現する汎用的な方法。

```
各節点が持つ情報:
  parent  : 親の番号（根は NIL）
  left    : 最も左の子の番号（子なしは NIL）
  right   : すぐ右の兄弟の番号（いなければ NIL）
```

特性：
- 節点の深さ：親をたどっていき根に至るまでの辺数 → O(h)
- 再帰的に深さを求めると O(n) に高速化できる

---

### 2.2 二分木 (Binary Tree)

**特性**
- 各節点の子の数が 2 以下
- 左の子と右の子を区別する（順序木）
- 再帰的定義：空 OR（根 + 左部分木 + 右部分木）

**二分木の表現**

```
各節点が持つ情報:
  key    : ノードのキー値
  parent : 親へのポインタ（根は NIL）
  left   : 左の子へのポインタ（なければ NIL）
  right  : 右の子へのポインタ（なければ NIL）
```

---

### 2.3 木の巡回 (Tree Traversal)

二分木の全節点を体系的に訪問する 3 つのアルゴリズム。いずれも O(n)。

**前順巡回（Preorder: 根→左→右）**

```
preorder(u):
  if u == NIL: return
  visit(u)               ← ここで根を処理
  preorder(u.left)
  preorder(u.right)
```

**中順巡回（Inorder: 左→根→右）**

```
inorder(u):
  if u == NIL: return
  inorder(u.left)
  visit(u)               ← ここで根を処理
  inorder(u.right)
```

BST に適用すると **昇順でキーが得られる** 重要な性質がある。

**後順巡回（Postorder: 左→右→根）**

```
postorder(u):
  if u == NIL: return
  postorder(u.left)
  postorder(u.right)
  visit(u)               ← ここで根を処理
```

**木の復元**：Preorder + Inorder が与えられれば Postorder を復元できる
- Preorder の先頭が根 c → Inorder で c の位置 m を探す
- m の左側が左部分木、右側が右部分木として再帰的に復元

---

## 3. 二分探索木 (Binary Search Tree)

### 3.1 特性

**BST 条件**：節点 x について
- x の左部分木に属する節点 y のキー ≤ x のキー
- x の右部分木に属する節点 z のキー ≥ x のキー

中順巡回で **昇順ソートされた列** が得られる。

**計算量**：木の高さ h = O(log n)（平均）、O(n)（偏った入力で最悪）

---

### 3.2 挿入 (Insert)

```
insert(T, key):
  y = NIL            // 挿入位置の親
  x = T.root
  while x != NIL:
    y = x
    if key < x.key:
      x = x.left
    else:
      x = x.right
  z = new Node(key)
  z.parent = y
  if y == NIL:       // 木が空の場合
    T.root = z
  else if key < y.key:
    y.left = z
  else:
    y.right = z
```

計算量：O(h)

---

### 3.3 探索 (Find)

```
find(x, key):
  while x != NIL and key != x.key:
    if key < x.key:
      x = x.left
    else:
      x = x.right
  return x  // 見つからなければ NIL
```

計算量：O(h)

---

### 3.4 削除 (Delete)

削除対象節点 z に応じた 3 ケース：

| ケース | 条件 | 処理 |
|--------|------|------|
| 1 | z が子を持たない | z の親から z への参照を NIL に |
| 2 | z が子を 1 つ持つ | z の親の子を z の子に繋ぎ替え |
| 3 | z が子を 2 つ持つ | 中順次節点 y のキーを z にコピーし y を削除（ケース 1 or 2 適用） |

計算量：O(h)

**中順次節点（successor）**：Inorder で次に現れる節点 = 右部分木の最小値

---

### 3.5 STL 実装（set / map）

set と map は内部的に **平衡二分探索木**（赤黒木）で実装されており、常に O(log n) を保証する。

| コンテナ | 特徴 | 主な操作 | 計算量 |
|---------|------|---------|--------|
| `set<T>` | 重複なし・自動ソート集合 | insert, erase, find | O(log n) |
| `map<K,V>` | キー→値の連想配列 | insert, erase, find, `[]` | O(log n) |

```
// set の使用例
S.insert(x)         // 挿入
S.erase(x)          // 削除
it = S.find(x)      // 検索（見つからなければ S.end()）
S.size()            // 要素数

// map の使用例
T[key] = value      // 書き込み（キーがなければ自動作成）
T.find(key)         // 検索（見つからなければ T.end()）
T.erase(key)        // 削除
```

---

## 4. ヒープ (Heap)

### 4.1 特性

**完全二分木（Complete Binary Tree）**
- 全ての葉が同じ深さ、または最下レベルのみ左から埋まっている
- n 個の節点の高さ = ⌊log₂ n⌋

**二分ヒープ（Binary Heap）**
- 完全二分木を **1-indexed 配列** で表現
- 添え字 i の節点の親・子は計算式で求まる：

```
parent(i)      = ⌊i / 2⌋
left_child(i)  = 2 * i
right_child(i) = 2 * i + 1
```

---

### 4.2 ヒープ条件

| 種別 | 条件 | 特徴 |
|------|------|------|
| max-heap | A[parent(i)] ≥ A[i] | 根が最大値 |
| min-heap | A[parent(i)] ≤ A[i] | 根が最小値 |

親子間のみに制約があり、兄弟間には制約なし。

---

### 4.3 主要操作

**maxHeapify（下方向への修正）**

```
maxHeapify(A, i):
  l = left(i); r = right(i)
  largest = (l <= H and A[l] > A[i]) ? l : i
  if r <= H and A[r] > A[largest]: largest = r
  if largest != i:
    swap(A[i], A[largest])
    maxHeapify(A, largest)    // 再帰
```
計算量：O(log n)

**buildMaxHeap（配列からヒープ構築）**

```
buildMaxHeap(A):
  for i = H/2 downto 1:
    maxHeapify(A, i)
```
計算量：O(n)（ナイーブな O(n log n) より高速）

**heapIncreaseKey（優先度引き上げ）**

```
heapIncreaseKey(A, i, key):
  A[i] = key
  while i > 1 and A[parent(i)] < A[i]:
    swap(A[i], A[parent(i)])
    i = parent(i)
```
計算量：O(log n)

---

### 4.4 優先度付きキュー (Priority Queue)

max-heap を使った max-優先度付きキューの操作：

| 操作 | 説明 | 計算量 |
|------|------|--------|
| `insert(key)` | 要素を追加 → heapIncreaseKey で整列 | O(log n) |
| `extractMax()` | 最大要素（根）を取り出し → maxHeapify で整列 | O(log n) |
| `getMax()` | 最大要素の参照 | O(1) |

**STL の priority_queue**

```
// max-heap（デフォルト）
priority_queue<int> pq;
pq.push(x)    // 挿入 O(log n)
pq.top()      // 最大値参照 O(1)
pq.pop()      // 最大値削除 O(log n)

// min-heap
priority_queue<int, vector<int>, greater<int>> pq;
```

---

## 5. 高度なデータ構造

### 5.1 Union-Find (Disjoint Set Forest)

**特性**
- 互いに素な集合の管理（素集合データ構造）
- 動的に集合を合併しながら所属集合を高速判定
- グラフの連結判定、クラスタリング、Kruskal 法で頻用

**操作**

| 操作 | 説明 |
|------|------|
| `makeSet(x)` | 要素 x のみの集合を作る |
| `findSet(x)` | x が属する集合の代表（根）を返す |
| `unite(x, y)` | x と y の集合を合併する |
| `same(x, y)` | `findSet(x) == findSet(y)` で同集合かを判定 |

**実装の核心**

```
// 初期化
for i in 0..n-1:
  parent[i] = i
  rank[i] = 0

// 経路圧縮付き findSet
findSet(x):
  if x != parent[x]:
    parent[x] = findSet(parent[x])    // 経路圧縮
  return parent[x]

// ランクによる union
unite(x, y):
  rx = findSet(x); ry = findSet(y)
  if rx == ry: return
  if rank[rx] > rank[ry]:
    parent[ry] = rx
  else:
    parent[rx] = ry
    if rank[rx] == rank[ry]: rank[ry]++
```

**計算量**：経路圧縮 + ランクの両方を使うと O(α(n)) ≈ 実質 O(1)（α はアッカーマン関数の逆関数）

**典型的な使用場面**
- グラフの連結成分管理
- Kruskal の最小全域木アルゴリズム
- 同値関係のグループ化

---

### 5.2 kD木 (k-D Tree)

**特性**
- k 次元空間上の点集合に対する**領域探索**を効率化
- 「静的なデータセット＋繰り返し範囲クエリ」の場面に適する
- 挿入・削除には再構築が必要（動的更新は非効率）

**構築アルゴリズム（2D の場合）**

```
make2DTree(l, r, depth):
  if l >= r: return NIL
  mid = (l + r) / 2
  if depth % 2 == 0:
    P[l..r] を x で昇順ソート    // 偶数深さ: x 軸で分割
  else:
    P[l..r] を y で昇順ソート    // 奇数深さ: y 軸で分割
  T[t].location = mid
  T[t].left  = make2DTree(l, mid, depth + 1)
  T[t].right = make2DTree(mid + 1, r, depth + 1)
  return t
```

**範囲探索アルゴリズム**

```
find(v, sx, tx, sy, ty, depth):
  x = P[T[v].location].x
  y = P[T[v].location].y
  if sx <= x <= tx and sy <= y <= ty:
    output P[T[v].location]       // クエリ範囲内なら出力
  if depth % 2 == 0:              // x 軸で分割している場合
    if T[v].left != NIL and sx <= x:   find(T[v].left, ...)
    if T[v].right != NIL and x <= tx:  find(T[v].right, ...)
  else:                           // y 軸で分割している場合
    if T[v].left != NIL and sy <= y:   find(T[v].left, ...)
    if T[v].right != NIL and y <= ty:  find(T[v].right, ...)
```

**計算量**
- 構築：O(n log² n)（各レベルでソートが必要）
- クエリ：O(√n + k) 期待値（k は結果の点数）

**典型的な使用場面**
- 地図上の矩形範囲内の点の列挙
- 最近傍探索（Nearest Neighbor）の基礎
- 空間インデックス全般

---

## 6. STL コンテナ対応表

| STL コンテナ | 論理構造 | 挿入 | 削除 | 探索 | 用途 |
|-------------|---------|------|------|------|------|
| `stack<T>` | スタック | O(1) | O(1) | — | LIFO 操作 |
| `queue<T>` | キュー | O(1) | O(1) | — | FIFO 操作 |
| `vector<T>` | 動的配列 | O(1) amort. | O(n) | O(n) | 可変長配列 |
| `list<T>` | 双方向リスト | O(1) | O(1)* | O(n) | 頻繁な中間挿入 |
| `set<T>` | 平衡 BST | O(log n) | O(log n) | O(log n) | 重複なし集合 |
| `map<K,V>` | 平衡 BST | O(log n) | O(log n) | O(log n) | キー→値辞書 |
| `priority_queue<T>` | max-heap | O(log n) | O(log n) | O(1)† | 最大値優先取出し |

*list の削除: ポインタが既知の場合のみ O(1)
†priority_queue の探索: 最大値のみ O(1)、任意要素は不可

---

## 7. 操作計算量比較表

| データ構造 | 先頭挿入 | 末尾挿入 | 任意位置挿入 | 探索 | 最小/最大取得 |
|-----------|---------|---------|------------|------|------------|
| 配列（固定長） | O(n) | O(1) | O(n) | O(n) | O(n) |
| 動的配列（vector） | O(n) | O(1)† | O(n) | O(n) | O(n) |
| 双方向リスト | O(1) | O(1) | O(1)* | O(n) | O(n) |
| BST（非平衡） | — | — | O(h) | O(h) | O(h) |
| BST（平衡: set/map） | — | — | O(log n) | O(log n) | O(log n) |
| max-heap | — | O(log n) | — | — | O(1) |
| Union-Find | — | — | — | O(α(n)) | — |

†末尾挿入はアモータイズド O(1)
*ポインタが既知の場合

---

## 8. アルゴリズム選択フロー

```
目的: 何をしたいか？
│
├─ LIFO が必要（最後に入れたものを取り出す）
│   └─ Stack
│
├─ FIFO が必要（最初に入れたものを取り出す）
│   └─ Queue
│
├─ 最大値/最小値を繰り返し取り出す
│   └─ Priority Queue (Heap)
│
├─ ソート順で探索・挿入・削除
│   ├─ 重複なし集合 → set
│   └─ キー→値マッピング → map
│
├─ 集合の合併と所属判定
│   └─ Union-Find
│
├─ 木構造の走査
│   ├─ 前処理タスク（トップダウン） → Preorder
│   ├─ ソート順出力（BST） → Inorder
│   └─ 後処理タスク（ボトムアップ） → Postorder
│
└─ 多次元空間の範囲クエリ
    └─ kD-Tree
```
