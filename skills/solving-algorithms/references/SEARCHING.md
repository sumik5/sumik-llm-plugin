# 探索アルゴリズム リファレンス

探索・再帰・分割統治・ヒューリスティック探索の実装パターンと選択指針。

---

## 1. 線形探索 (Linear Search)

配列の先頭から末尾まで順番に比較する最もシンプルな探索。

```
linearSearch(A, n, key):
    for i = 0 to n-1:
        if A[i] == key: return i
    return NOT_FOUND
```

**計算量**: O(n) / **前提**: なし（未整列データに適用可能）

### 番兵法 (Sentinel)

配列末尾に探索キーを「番兵」として置き、ループ終了条件を1つに削減する。

```
linearSearchSentinel(A, n, key):
    A[n] = key          // 番兵を末尾に設置
    i = 0
    while A[i] != key:
        i++
    return (i != n) ? i : NOT_FOUND
```

**効果**: ループ内の比較を「インデックス境界 + キー比較」の2回から「キー比較のみ」1回に削減。大規模データで定数倍の高速化。

---

## 2. 二分探索 (Binary Search)

**前提**: 配列が昇順に整列されていること。

```
binarySearch(A, n, key):
    left = 0; right = n
    while left < right:
        mid = (left + right) / 2
        if A[mid] == key:   return mid
        if key < A[mid]:    right = mid      // 前半へ
        else:               left = mid + 1   // 後半へ
    return NOT_FOUND
```

**計算量**: O(log n)

| 要素数 n | 線形探索（最悪） | 二分探索（最悪） |
|---------|--------------|--------------|
| 100 | 100回 | 7回 |
| 10,000 | 10,000回 | 14回 |
| 1,000,000 | 1,000,000回 | 20回 |

### lower_bound / upper_bound

```
lowerBound(A, n, value):   // value 以上の最初の位置
    left = 0; right = n
    while left < right:
        mid = (left + right) / 2
        if A[mid] < value:  left = mid + 1
        else:               right = mid
    return left
```

`upperBound` は条件を `A[mid] <= value` に変えるだけ。

### 応用：最適解の計算（二分探索 on 答え）

**条件**: check(P) が真になる P が単調（P が増えると偽→真に転じる）

```
findMinimumP(lo, hi):
    while hi - lo > 1:
        mid = (lo + hi) / 2
        if check(mid):  hi = mid   // 条件を満たす → 範囲を前半に
        else:           lo = mid
    return hi
```

**計算量**: O(n log P)（check が O(n) の場合）
**典型例**: k 台のトラックで n 個の荷物を積む最小積載量 → check(P) で積載可能かを O(n) で判定

---

## 3. ハッシュ (Hash)

キーをハッシュ関数でインデックスに変換し、配列に格納する。

```
h(key) = key mod m    // m はテーブルサイズ（素数推奨）
```

**計算量**: 平均 O(1)

### 衝突解決：オープンアドレス法（ダブルハッシュ）

```
h1(key) = key mod m
h2(key) = 1 + (key mod (m-1))    // m と互いに素にする
h(key, i) = (h1(key) + i * h2(key)) mod m

insert(T, key):
    i = 0
    loop:
        j = h(key, i)
        if T[j] == NIL: T[j] = key; return
        i++

search(T, key):
    i = 0
    loop:
        j = h(key, i)
        if T[j] == key: return j
        if T[j] == NIL or i >= m: return NIL
        i++
```

**設計ポイント**: テーブルサイズ m は素数、文字列キーは多項式で数値化してからハッシュ適用。

---

## 4. 再帰と分割統治法

### 分割統治法のステップ

1. **Divide** — 問題を部分問題に分割
2. **Solve** — 再帰的に解く
3. **Conquer** — 部分問題の解を統合

```
findMax(A, l, r):
    if l == r - 1: return A[l]      // 基底ケース
    mid = (l + r) / 2
    u = findMax(A, l, mid)          // Divide + Solve
    v = findMax(A, mid, r)
    return max(u, v)                // Conquer
```

### 全探索パターン（組み合わせ列挙）

n 個の要素について「選ぶ/選ばない」の 2^n 通りを再帰で列挙する。

```
solve(i, remaining):
    // i 番目以降の要素を使って remaining を作れるか
    if remaining == 0: return true
    if i >= n:         return false
    return solve(i+1, remaining) OR solve(i+1, remaining - A[i])
```

**計算量**: O(2^n)
**注意**: 同じ部分問題を重複計算する無駄あり → 動的計画法（DP）で改善可能

---

## 5. ヒューリスティック探索

### バックトラッキング (Backtracking)

状態を体系的に試し、解が得られないと判断した時点で打ち切って前の状態に戻る手法。

```
backtrack(状態 s, 深さ d):
    if s がゴール: 解を記録; return
    for 次の選択肢 c:
        if 制約違反でない:
            c を適用して状態更新
            backtrack(次の状態, d+1)
            c を取り消して状態を復元    // バックトラック
```

**8クイーン問題**の探索空間削減:
- 素朴な全探索: 64C8 ≈ 44億通り
- 1行1クイーン制約: 8^8 ≈ 1677万通り
- 列重複排除: 8! = 40,320通り
- バックトラック適用後: さらに大幅に削減

8クイーン問題では行・列・対角線の使用状況を配列で管理し、競合するマスをスキップして再帰する。

### 反復深化 (Iterative Deepening)

深さ制限付きDFSを制限を増やしながら繰り返す。最短解を保証しつつメモリを節約。

```
iterativeDeepening(初期状態 s):
    for limit = 0, 1, 2, ...:
        if depthLimitedDFS(s, 0, limit): return 解
```

**特徴**: BFSと同等の最短解保証 + DFSと同等の O(深さ) メモリ使用量

### IDA* (Iterative Deepening A*)

反復深化にヒューリスティック関数 h を加えて枝刈りを強化する。

```
dfs(s, g, limit):
    if s がゴール: return true
    if g + h(s) > limit: return false    // ヒューリスティック枝刈り
    for 各操作 op:
        if dfs(apply(s, op), g+1, limit): return true
    return false

IDA*(初期状態 s):
    for limit = h(s), h(s)+1, ...:
        if dfs(s, 0, limit): return 解
```

**ヒューリスティック関数の設計（15パズルの例）**:

| ヒューリスティック | 内容 | 枝刈り効果 |
|-----------------|-----|---------|
| h1: 位置ずれ枚数 | ゴール位置にないパネルの個数 | 弱め |
| h2: マンハッタン距離 | 各パネルのゴールまでの縦横移動距離の総和 | 強め（推奨） |

**Admissible heuristicの条件**: `h(s) ≤ 実際の残りコスト`（下限値の推定）
→ この条件を満たすとき IDA* は最適解を保証する。h2 は h1 より値が大きく（より正確）優位。

### A* アルゴリズム

優先度付きキューで `g + h` が最小の状態から探索を展開する。

```
A*(初期状態 s):
    open = 優先度付きキュー（優先度: g + h(s)）
    while open が空でない:
        u = open.pop()
        if u がゴール: return 経路
        for 各操作 op:
            v = apply(u, op)
            open.push(v, g(v) + h(v))
```

**IDA* との比較**:

| | IDA* | A* |
|--|------|-----|
| メモリ | O(深さ) | O(状態数) |
| 用途 | メモリ制約が厳しい | メモリ十分で高速化優先 |

---

## 6. 探索アルゴリズム選択ガイド

| 問題の特徴 | 推奨アルゴリズム | 計算量 |
|----------|---------------|------|
| 未整列データ・小さい n | 線形探索（番兵法） | O(n) |
| 整列済みデータの要素検索 | 二分探索 | O(log n) |
| 単調条件の最小/最大値を求める | 二分探索 on 答え | O(n log P) |
| 頻繁な挿入・検索・削除 | ハッシュテーブル | 平均 O(1) |
| n ≤ 20 程度の組み合わせ全列挙 | 再帰的全探索 | O(2^n) |
| 制約充足問題（配置問題など） | バックトラッキング | 問題依存 |
| 状態数が少ない、最短手数が必要 | BFS | O(状態数) |
| 状態数が多い、メモリ制約あり | IDA* | O(深さ) |
| 状態数が多い、メモリ十分 | A* | O(状態数) |

### 判断フロー

```
データが整列済み？
├─ YES → 二分探索 (O(log n))
└─ NO
    ├─ キー検索が頻繁？ → ハッシュ (O(1) avg)
    └─ 組み合わせ・状態空間探索？
        ├─ 状態数が少ない → BFS（最短解保証）
        ├─ 状態数が多い + ヒューリスティックあり → IDA* / A*
        └─ 制約充足（解の存在確認のみ） → バックトラック + 枝刈り
```
