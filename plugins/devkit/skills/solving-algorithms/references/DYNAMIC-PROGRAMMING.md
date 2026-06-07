# 動的計画法（Dynamic Programming）

動的計画法（DP）は、**重複する部分問題の解をメモリに記録して再利用**することで、
指数時間アルゴリズムを多項式時間に改善する汎用的な設計技法。

---

## DP設計フレームワーク

どんなDP問題も以下の4ステップで設計できる：

```
1. 状態定義   : dp[i] や dp[i][j] が何を意味するか決める
2. 遷移式     : 大きな問題を小さな問題の解から求める式を立てる
3. 初期値     : ベースケース（境界条件）を設定する
4. 計算順序   : 依存関係を満たす順に（通常は小 → 大）計算する
```

### トップダウン（メモ化再帰） vs ボトムアップ

| 手法 | 実装方法 | 特徴 |
|------|---------|------|
| メモ化再帰 | 再帰 + キャッシュ配列 | 必要な部分問題のみ計算。再帰オーバーヘッドあり |
| ボトムアップ | ループで小 → 大へ計算 | 全部分問題を計算。スタックオーバーフローなし |

---

## 基礎DP問題

### 1. フィボナッチ数列

**問題**: fib(n) = fib(n-1) + fib(n-2)、fib(0)=fib(1)=1

**なぜ単純再帰が遅いか**:

```
        fib(5)
       /       \
    fib(4)    fib(3)    ← fib(3) が重複計算される
    /    \    /    \
 fib(3) fib(2) fib(2) fib(1)
```

fib(n) の単純再帰は fib(n) 回のコールが発生 → **O(2^n)**

**メモ化再帰（トップダウン）**:

```
fib_memo(n):
    if n == 0 or n == 1:
        return memo[n] = 1
    if memo[n] は計算済み:
        return memo[n]
    return memo[n] = fib_memo(n-1) + fib_memo(n-2)
```

**ボトムアップDP**:

```
make_fibonacci(n):
    F[0] = 1
    F[1] = 1
    for i from 2 to n:
        F[i] = F[i-1] + F[i-2]
    return F[n]
```

| 手法 | 時間計算量 | 空間計算量 |
|------|-----------|-----------|
| 単純再帰 | O(2^n) | O(n) |
| メモ化再帰 | O(n) | O(n) |
| ボトムアップ | O(n) | O(n)（O(1)に最適化可） |

---

### 2. 最長共通部分列（LCS: Longest Common Subsequence）

**問題**: 2つの列 X（長さm）と Y（長さn）の共通部分列の最大長を求める

**例**: X = {a,b,c,b,d,a,b}、Y = {b,d,c,a,b,a} → LCS = {b,c,b,a}（長さ4）

**状態定義**: `dp[i][j]` = Xi（X の先頭 i 文字）と Yj（Y の先頭 j 文字）の LCS の長さ

**遷移式**:

```
dp[i][j] = 0                          (i=0 または j=0)
dp[i][j] = dp[i-1][j-1] + 1          (X[i] == Y[j])
dp[i][j] = max(dp[i-1][j], dp[i][j-1])  (X[i] != Y[j])
```

**ボトムアップ実装**:

```
lcs(X, Y):
    m = len(X), n = len(Y)
    for i from 0 to m:
        dp[i][0] = 0
    for j from 0 to n:
        dp[0][j] = 0
    for i from 1 to m:
        for j from 1 to n:
            if X[i] == Y[j]:
                dp[i][j] = dp[i-1][j-1] + 1
            else:
                dp[i][j] = max(dp[i-1][j], dp[i][j-1])
    return dp[m][n]
```

**計算量**: 時間 O(mn)、空間 O(mn)

---

### 3. 連鎖行列積（Matrix Chain Multiplication）

**問題**: n 個の行列 M1,M2,...,Mn の積の計算順序を決め、スカラー乗算の回数を最小化する

**背景**: p×q 行列と q×r 行列の積のコストは p×q×r。計算順序によりコストが大幅に変わる。
- 全探索: O(n!) → DPで O(n^3) に削減

**状態定義**: `dp[i][j]` = Mi から Mj までの積の最小乗算回数（p[i-1]×p[i]が行列 Mi の次元）

**遷移式**:

```
dp[i][i] = 0
dp[i][j] = min over k from i to j-1:
               dp[i][k] + dp[k+1][j] + p[i-1] * p[k] * p[j]
```

**ボトムアップ実装**（連鎖長を小さい順に計算）:

```
matrix_chain(p, n):
    for i from 1 to n:
        dp[i][i] = 0
    for length from 2 to n:          // 連鎖の長さ
        for i from 1 to n-length+1:
            j = i + length - 1
            dp[i][j] = INF
            for k from i to j-1:
                cost = dp[i][k] + dp[k+1][j] + p[i-1] * p[k] * p[j]
                dp[i][j] = min(dp[i][j], cost)
    return dp[1][n]
```

**計算量**: 時間 O(n^3)、空間 O(n^2)

---

## 応用DP問題

### 4. コイン問題（最小枚数）

**問題**: m 種類のコイン（額面 C[1],...,C[m]）で n 円を支払う最小枚数を求める

**ポイント**: 貪欲法は一般の額面では最適解を保証しない（例: 1,2,7,8,12 で 15円 → 貪欲は3枚、最適は2枚）

**状態定義**: `dp[j]` = j 円を支払う最小枚数

**遷移式**:

```
dp[0] = 0
dp[j] = min(dp[j], dp[j - C[i]] + 1)   // コイン i を使う場合
```

**ボトムアップ実装**:

```
coin_change(C, m, n):
    dp[0..n] = INF
    dp[0] = 0
    for i from 1 to m:
        for j from C[i] to n:
            dp[j] = min(dp[j], dp[j - C[i]] + 1)
    return dp[n]
```

**計算量**: 時間 O(mn)、空間 O(n)

---

### 5. 0-1 ナップザック問題（0-1 Knapsack）

**問題**: N 個の品物（価値 v[i]、重さ w[i]）と容量 W のナップザック。価値最大化（各品物は最大1回使用）

**状態定義**: `dp[i][j]` = i 番目までの品物を考慮して容量 j のナップザックに入れた場合の価値の最大値

**遷移式**:

```
dp[0][j] = 0  (全 j)
dp[i][0] = 0  (全 i)
dp[i][j] = dp[i-1][j]                              // 品物 i を選ばない
         = max(dp[i-1][j], dp[i-1][j-w[i]] + v[i]) // w[i] <= j の場合、選ぶ/選ばないを比較
```

**ボトムアップ実装**:

```
knapsack(items, N, W):
    dp[0..N][0..W] = 0
    for i from 1 to N:
        for j from 1 to W:
            dp[i][j] = dp[i-1][j]       // 選ばない
            if items[i].w <= j:
                dp[i][j] = max(dp[i][j], dp[i-1][j - items[i].w] + items[i].v)
    return dp[N][W]
```

**1次元配列への最適化**（空間節約）:

```
dp[0..W] = 0
for i from 1 to N:
    for j from W downto items[i].w:   // 逆順で更新（各品物を1回だけ使う）
        dp[j] = max(dp[j], dp[j - items[i].w] + items[i].v)
```

**計算量**: 時間 O(NW)、空間 O(NW)（1次元化で O(W)）

**注意**: NW が大きい場合は擬多項式時間。価値が小さければ `dp[i][v]`（重さ最小化）で解く

---

### 6. 最長増加部分列（LIS: Longest Increasing Subsequence）

**問題**: 数列 A = {a0, a1, ..., an-1} の最長の増加部分列の長さを求める

**手法1: 基本DP — O(n^2)**

状態定義: `L[i]` = A[i] を末尾とした LIS の長さ

```
LIS_dp(A, n):
    L[0] = 1
    for i from 1 to n-1:
        L[i] = 1
        for j from 0 to i-1:
            if A[j] < A[i]:
                L[i] = max(L[i], L[j] + 1)
    return max(L)
```

**手法2: DP + 二分探索 — O(n log n)**

`T[k]`（長さ k+1 の増加部分列の末尾の最小値）を二分探索で更新：

```
LIS_binary(A, n):
    T = []
    for i from 0 to n-1:
        if T is empty or T.last < A[i]:
            T.append(A[i])          // LIS を延長
        else:
            pos = lower_bound(T, A[i])  // T[pos] >= A[i] の最左位置
            T[pos] = A[i]           // より小さい末尾に更新
    return len(T)
```

**例**: A = {4,1,6,2,8,5,7,3}

```
処理後の T の変化:
[4] → [1] → [1,6] → [1,2] → [1,2,8] → [1,2,5] → [1,2,5,7] → [1,2,3,7]
LIS の長さ = 4（例: {1,2,5,7}）
```

**計算量比較**:

| 手法 | 時間計算量 | 空間計算量 |
|------|-----------|-----------|
| 基本 DP | O(n^2) | O(n) |
| DP + 二分探索 | O(n log n) | O(n) |

---

### 7. 最大正方形（2Dグリッド）

**問題**: H×W のグリッドで、障害物のないセルのみからなる最大の正方形の面積を求める

**状態定義**: `dp[i][j]` = セル(i,j) を右下隅とした最大正方形の辺の長さ

**遷移式**（セル(i,j)が空きの場合）:

```
dp[i][j] = min(dp[i-1][j-1], dp[i-1][j], dp[i][j-1]) + 1
```

**直感的な理由**: 右下に(i,j)を持つ正方形の辺長は、左上・上・左の3方向から制約される最小値 + 1

**ボトムアップ実装**:

```
largest_square(G, H, W):
    max_side = 0
    for i from 0 to H-1:
        for j from 0 to W-1:
            if G[i][j] is obstacle:
                dp[i][j] = 0
            elif i == 0 or j == 0:
                dp[i][j] = 1 if G[i][j] is empty else 0
            else:
                dp[i][j] = min(dp[i-1][j-1], dp[i-1][j], dp[i][j-1]) + 1
            max_side = max(max_side, dp[i][j])
    return max_side * max_side
```

**計算量**: 時間 O(HW)、空間 O(HW)

---

### 8. 最大長方形（ヒストグラム応用）

**問題**: H×W のグリッドで、障害物のないセルのみからなる最大の長方形の面積を求める

**2段階アプローチ**:

**Step 1**: 各セル(i,j) で上方向に連続する空きセルの数を T[i][j] として計算（列ごとのDP）

```
T[i][j] = 0                 if G[i][j] is obstacle
T[i][j] = T[i-1][j] + 1    if G[i][j] is empty
```

**Step 2**: 各行 i を T[i][*] で表されるヒストグラムとみなし、**スタックを使って最大長方形**を O(W) で求める

```
largest_rectangle_in_histogram(h, W):
    stack = []  // (height, left_pos) を記録
    max_area = 0
    for i from 0 to W:
        left = i
        while stack is not empty and stack.top.height >= h[i]:
            rect = stack.pop()
            area = rect.height * (i - rect.pos)
            max_area = max(max_area, area)
            left = rect.pos
        if stack is empty or stack.top.height < h[i]:
            stack.push((h[i], left))
    return max_area

largest_rectangle(G, H, W):
    T[*][*] = 0（初期化）
    max_area = 0
    for i from 0 to H-1:
        for j from 0 to W-1:
            T[i][j] = 0 if G[i][j] is obstacle else T[i-1][j] + 1
        max_area = max(max_area, largest_rectangle_in_histogram(T[i], W))
    return max_area
```

**計算量**: 時間 O(HW)、空間 O(HW)

---

## 各問題の計算量比較表

| 問題 | 素朴解法 | DP解法 | 最適解法 | 空間計算量 |
|------|---------|--------|---------|-----------|
| フィボナッチ | O(2^n) | O(n) | O(n) | O(1)〜O(n) |
| LCS | O(2^m・2^n) | O(mn) | O(mn) | O(mn) |
| 連鎖行列積 | O(n!) | O(n^3) | O(n^3) | O(n^2) |
| コイン問題 | O(m^n) | O(mn) | O(mn) | O(n) |
| 0-1 ナップザック | O(2^N) | O(NW) | O(NW)* | O(W) |
| LIS | O(2^n) | O(n^2) | O(n log n) | O(n) |
| 最大正方形 | O(HW・min(H,W)^2) | O(HW) | O(HW) | O(HW) |
| 最大長方形 | O(HW^2) | O(HW) | O(HW) | O(HW) |

*0-1 ナップザックは擬多項式時間（NP困難問題）

---

## DP適用の判断基準

以下の条件を満たす場合、DPが有効：

1. **最適部分構造**: 最適解が部分問題の最適解から構成される
2. **重複部分問題**: 同じ部分問題が複数回現れる
3. **無後効性**: 過去の選択は現在の状態のみで要約できる

```
DP が使えるか？
    ↓
最適化問題（最大・最小・カウント）か？
    ↓ Yes
状態を定義できるか？（何を覚えれば十分か）
    ↓ Yes
遷移式を立てられるか？
    ↓ Yes
→ DP を適用する
```

### 典型的な状態の形

| 状態の形 | 典型問題 |
|---------|---------|
| `dp[i]` — 位置 i まで処理した最適値 | フィボナッチ、コイン、LIS |
| `dp[i][j]` — 2変数の状態 | LCS、ナップザック、正方形 |
| `dp[i][j]` — 区間 [i,j] の最適値 | 連鎖行列積 |
| `dp[i][j]` — グリッド位置 (i,j) | 最大正方形、最大長方形 |
