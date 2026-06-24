# 計算幾何学リファレンス

計算幾何学（Computational Geometry）は幾何学的問題をコンピュータで効率的に解くためのアルゴリズム群。
コンピュータグラフィックス・GIS・衝突判定など広い応用を持ち、競技プログラミングでも頻出テーマ。

---

## 1. 基本要素と表現

### 1.1 点とベクトル

**点（Point）**: 平面上の座標 `(x, y)` を持つ構造体。
**ベクトル（Vector）**: 大きさと向きを持つ量。原点 `O(0,0)` から点 `P(x,y)` への有向線分として表す。
実装上は Point と Vector を同じデータ構造として扱い、文脈に応じて使い分ける。

```
Point / Vector: { x: float, y: float }
```

**ベクトル演算**（オペレーター定義）:
- 加算: `a + b = (a.x + b.x, a.y + b.y)`
- スカラー倍: `a * t = (a.x * t, a.y * t)`
- 大きさ（ノルム）: `|a| = sqrt(a.x² + a.y²)`
- ノルムの二乗: `norm(a) = a.x² + a.y²`

### 1.2 線分と直線

**線分（Segment）**: 始点 `p1` と終点 `p2` の2点で定義。長さが有限。
**直線（Line）**: 2点を通る無限に続く線。端点を持たない。
同じ構造体で表し、どちらとして扱うかはアルゴリズム側で決定する。

```
Segment / Line: { p1: Point, p2: Point }
```

### 1.3 円と多角形

**円（Circle）**: 中心 `c`（Point）と半径 `r`（float）で定義。

```
Circle: { c: Point, r: float }
```

**多角形（Polygon）**: 点の列 `[p0, p1, ..., pn-1]`。
隣接する点 `p_i` と `p_{i+1}` を結ぶ辺で構成され、`pn-1` と `p0` も辺を形成する。

---

## 2. 数値安定性: EPS の扱い

浮動小数点数の比較には **EPS（epsilon）** を使う。直接 `==` で比較しない。

```
EPS = 1e-9  // 問題に応じて 1e-7 〜 1e-10

equals(a, b): return |a - b| < EPS
isZero(a):    return |a| < EPS
```

**注意点**:
- `cross(a, b) > EPS` → 正（反時計回り）
- `cross(a, b) < -EPS` → 負（時計回り）
- `|cross(a, b)| < EPS` → ゼロ（平行または重なり）

内積・外積の計算結果は整数入力でも誤差が累積するため、一貫して EPS 比較を使う。

---

## 3. ベクトル演算

### 3.1 内積（Dot Product）

$$a \cdot b = |a||b|\cos\theta = a_x \cdot b_x + a_y \cdot b_y$$

```
dot(a, b): return a.x * b.x + a.y * b.y
```

**幾何学的意味**:
- `dot(a, b) > 0` → θ < 90°（鋭角）
- `dot(a, b) = 0` → θ = 90°（**直交**）
- `dot(a, b) < 0` → θ > 90°（鈍角）

### 3.2 外積（Cross Product）

2次元では外積はスカラー値（z成分）として扱う:

$$|a \times b| = |a||b|\sin\theta = a_x \cdot b_y - a_y \cdot b_x$$

```
cross(a, b): return a.x * b.y - a.y * b.x
```

**幾何学的意味**:
- `cross(a, b) > 0` → b は a の **反時計回り**（左側）
- `cross(a, b) = 0` → a と b は **平行**（同方向または逆方向）
- `cross(a, b) < 0` → b は a の **時計回り**（右側）
- `|cross(a, b)|` = a と b が作る **平行四辺形の面積**

---

## 4. 判定アルゴリズム

### 4.1 直線の直交・平行判定

```
isOrthogonal(a, b): return equals(dot(a, b), 0.0)

isParallel(a, b): return equals(cross(a, b), 0.0)
```

直交判定: `dot(a, b) = 0` ⟺ 内積がゼロ ⟺ cos90° = 0
平行判定: `cross(a, b) = 0` ⟺ 外積がゼロ ⟺ sin0° = sin180° = 0

### 4.2 射影（Projection）

点 `p` から直線（または線分）`s` への正射影点 `x` を求める:

1. ベクトル `base = s.p2 - s.p1`、`hypo = p - s.p1`
2. `base` 方向の比率: `r = dot(hypo, base) / norm(base)`
3. 射影点: `x = s.p1 + base * r`

$$x = s.p1 + base \cdot \frac{hypo \cdot base}{|base|^2}$$

```
project(s, p):
    base = s.p2 - s.p1
    r = dot(p - s.p1, base) / norm(base)
    return s.p1 + base * r
```

### 4.3 反射（Reflection）

直線 `s` を対称軸とした点 `p` の線対称点 `x`:

1. 射影点 `p' = project(s, p)` を求める
2. `x = p + (p' - p) * 2.0`

```
reflect(s, p):
    return p + (project(s, p) - p) * 2.0
```

### 4.4 反時計回り（CCW: Counter-Clockwise）

点 `p0`→`p1` のベクトルに対する点 `p2` の位置関係を5種類に分類:

```
CCW(p0, p1, p2):
    a = p1 - p0  // 基準ベクトル
    b = p2 - p0  // 対象ベクトル

    if cross(a, b) > EPS:   return COUNTER_CLOCKWISE  // p2 は左側
    if cross(a, b) < -EPS:  return CLOCKWISE          // p2 は右側
    if dot(a, b) < -EPS:    return ONLINE_BACK         // p2→p0→p1 の順（後方）
    if norm(a) < norm(b):   return ONLINE_FRONT        // p0→p1→p2 の順（前方）
    return ON_SEGMENT                                  // p2 は線分 p0p1 上
```

| 状態 | 値 | 意味 |
|------|-----|------|
| COUNTER_CLOCKWISE | +1 | p2 は a の左側（反時計回り方向） |
| CLOCKWISE | -1 | p2 は a の右側（時計回り方向） |
| ONLINE_BACK | +2 | p2 → p0 → p1 の順で直線上 |
| ONLINE_FRONT | -2 | p0 → p1 → p2 の順で直線上 |
| ON_SEGMENT | 0 | p0 → p2 → p1 の順で線分上 |

---

## 5. 距離計算

### 5.1 2点間の距離

```
distance(a, b): return |a - b| = sqrt((a.x-b.x)² + (a.y-b.y)²)
```

### 5.2 点と直線の距離

外積を利用: 平行四辺形の面積 ÷ 底辺の長さ = 高さ

$$d = \frac{|a \times b|}{|a|}, \quad a = p2 - p1, \quad b = p - p1$$

```
distanceLinePt(l, p):
    return |cross(l.p2 - l.p1, p - l.p1)| / |l.p2 - l.p1|
```

### 5.3 点と線分の距離

端点付近の場合分けが必要:

```
distanceSegPt(s, p):
    if dot(s.p2 - s.p1, p - s.p1) < 0:  return |p - s.p1|   // p1 が最近点
    if dot(s.p1 - s.p2, p - s.p2) < 0:  return |p - s.p2|   // p2 が最近点
    return distanceLinePt(s, p)                                // 垂線の足が最近点
```

**判定の仕組み**: 内積が負 ⟺ なす角が90°超 ⟺ 射影が線分の外側

### 5.4 線分と線分の距離

```
distanceSegSeg(s1, s2):
    if intersect(s1, s2): return 0.0
    return min(
        distanceSegPt(s1, s2.p1),
        distanceSegPt(s1, s2.p2),
        distanceSegPt(s2, s1.p1),
        distanceSegPt(s2, s1.p2)
    )
```

交差している場合は距離0。交差しない場合は4つの「端点と線分」の距離の最小値。

---

## 6. 交差と交点

### 6.1 線分の交差判定

CCW を利用した高精度な交差判定:

```
intersect(s1, s2):
    return CCW(s1.p1, s1.p2, s2.p1) * CCW(s1.p1, s1.p2, s2.p2) <= 0
        && CCW(s2.p1, s2.p2, s1.p1) * CCW(s2.p1, s2.p2, s1.p2) <= 0
```

**判定の仕組み**:
- `CCW(p1, p2, p3) * CCW(p1, p2, p4) < 0`: p3, p4 が s1 の反対側
- 積が 0: いずれかの端点が他方の線分上
- 両条件が成立（≤ 0）→ 交差

端点が線分上にある場合（`ON_SEGMENT`）も交差とみなす。

### 6.2 線分の交点計算

外積による比率計算:

$$t = \frac{d1}{d1 + d2}, \quad d1 = |base \times (s1.p1 - s2.p1)|, \quad d2 = |base \times (s1.p2 - s2.p1)|$$

$$x = s1.p1 + (s1.p2 - s1.p1) \times t$$

```
crossPoint(s1, s2):
    base = s2.p2 - s2.p1
    d1 = |cross(base, s1.p1 - s2.p1)|
    d2 = |cross(base, s1.p2 - s2.p1)|
    t = d1 / (d1 + d2)          // |base| は約分で消える
    return s1.p1 + (s1.p2 - s1.p1) * t
```

### 6.3 円と直線の交点

```
crossPointCircleLine(c, l):
    pr = project(l, c.center)              // 円の中心を直線に射影
    e = (l.p2 - l.p1) / |l.p2 - l.p1|    // 直線方向の単位ベクトル
    base = sqrt(c.r² - norm(pr - c.center)) // 射影点から交点までの距離
    return [pr + e * base, pr - e * base]
```

**前提**: 事前に `distanceLinePt(l, c.center) <= c.r` を確認する。

### 6.4 円と円の交点

余弦定理を用いて角度を計算:

```
crossPointCircleCircle(c1, c2):
    d = |c1.center - c2.center|
    a = acos((c1.r² + d² - c2.r²) / (2 * c1.r * d))   // 余弦定理
    t = atan2(c2.center.y - c1.center.y,
              c2.center.x - c1.center.x)                // c1→c2 方向の角度
    return [
        c1.center + polar(c1.r, t + a),
        c1.center + polar(c1.r, t - a)
    ]

// ヘルパー
polar(r, theta): return Point(cos(theta) * r, sin(theta) * r)
```

---

## 7. 高度なアルゴリズム

### 7.1 点の多角形内包判定

**半直線交差法（Ray Casting）**:
点 `p` から x 軸正方向への半直線が多角形の辺と交差する回数を数える。

- 奇数回 → **内部（IN）**
- 偶数回 → **外部（OUT）**
- 辺上の場合 → **境界上（ON）**

```
contains(polygon, p):
    inside = false
    n = len(polygon)

    for i in 0..n:
        a = polygon[i] - p
        b = polygon[(i+1) % n] - p

        // 辺上の判定
        if |cross(a, b)| < EPS and dot(a, b) < EPS:
            return ON  // 1

        // y が小さい方が a になるよう調整
        if a.y > b.y: swap(a, b)

        // 半直線との交差判定
        // a.y < 0 < b.y かつ cross(a, b) > 0（反時計回り）のとき交差
        if a.y < EPS and b.y > EPS and cross(a, b) > EPS:
            inside = !inside

    return IN(2) if inside else OUT(0)
```

**境界条件のポイント**:
- y 座標を調整することで、端点での二重カウントを防ぐ
- 凸多角形に限らず、任意の単純多角形に適用可能: O(n)

### 7.2 凸包（Convex Hull）

**Andrew's Monotone Chain アルゴリズム**:
点集合の凸包（最小凸多角形）を O(n log n) で求める。

```
convexHull(points):
    // 1. x 昇順（同一 x は y 昇順）でソート
    sort(points)

    // 2. 上部凸包を構築
    upper = []
    for p in points:
        while len(upper) >= 2 and CCW(upper[-2], upper[-1], p) != CLOCKWISE:
            upper.pop()
        upper.append(p)

    // 3. 下部凸包を構築（逆順）
    lower = []
    for p in reversed(points):
        while len(lower) >= 2 and CCW(lower[-2], lower[-1], p) != CLOCKWISE:
            lower.pop()
        lower.append(p)

    // 4. 結合（重複端点を除く）
    return upper[:-1] + lower[:-1]
```

**補足**:
- `!= CLOCKWISE` の条件: 辺上の点を **含めない**（厳密凸包）
- `== COUNTER_CLOCKWISE` に変更: 辺上の点を **含める**
- 計算量: ソートが O(n log n)、スタック操作は O(n) → **全体 O(n log n)**

### 7.3 線分交差問題（平面走査: Sweep Line）

軸平行な線分（水平・垂直）の交点数を O(n log n + k) で求める（k = 交点数）。

**アルゴリズム（マンハッタン幾何）**:

```
sweepLineIntersection(segments):
    // 端点をイベントに変換
    events = []
    for s in segments:
        if s is horizontal: events.add(LEFT(s.left), RIGHT(s.right))
        if s is vertical:   events.add(BOTTOM(s.bottom), TOP(s.top))

    // y 座標でソート（同一 y は BOTTOM < LEFT < RIGHT < TOP の順）
    sort(events by y, then type priority)

    BST = 空の二分探索木  // 現在走査線と交差する垂直線分の x 座標を管理
    count = 0

    for event in events:
        if event.type == BOTTOM:
            BST.insert(event.x)         // 垂直線分の開始
        elif event.type == TOP:
            BST.remove(event.x)         // 垂直線分の終了
        elif event.type == LEFT:
            // 水平線分の範囲内の垂直線分を数える
            count += BST.count_in_range(segment.x1, segment.x2)

    return count
```

**計算量**: BST 操作 O(log n) × 2n イベント + k 交点報告 = **O(n log n + k)**
**拡張**: 一般的な線分交差（非軸平行）は Bentley-Ottmann アルゴリズムで O((n + k) log n)。

---

## 8. よくある実装パターン

### 8.1 基本ライブラリの構成

```
// 定数
EPS = 1e-9

// 比較ユーティリティ
equals(a, b): return |a - b| < EPS

// Point/Vector 演算子オーバーロード
// +, -, *, /, ==, <（辞書順）

// ベクトル演算
dot(a, b), cross(a, b), norm(a), abs(a)

// 基本プリミティブ（これを積み上げる）
project(s, p)
reflect(s, p)
CCW(p0, p1, p2)
intersect(s1, s2)       // intersect を利用する
crossPoint(s1, s2)
distanceSegPt(s, p)
distanceSegSeg(s1, s2)
contains(polygon, p)
convexHull(points)
```

### 8.2 アルゴリズム選択

| 問題 | アルゴリズム | 計算量 |
|------|-------------|--------|
| 2点間の距離 | ユークリッド距離 | O(1) |
| 点と線分の距離 | 内積による場合分け | O(1) |
| 線分の交差判定 | CCW ベース | O(1) |
| 線分の交点 | 外積による比率計算 | O(1) |
| 円と直線の交点 | 射影 + 単位ベクトル | O(1) |
| 点の多角形内包 | 半直線交差法 | O(n) |
| 凸包 | Andrew's Monotone Chain | O(n log n) |
| 軸平行線分交差数 | 平面走査 + BST | O(n log n + k) |
| 最近点対 | 分割統治法 | O(n log n) |
| 凸多角形の直径 | キャリパー法 | O(n) |

---

## 9. 数値安定性チェックリスト

- [ ] `==` での浮動小数点比較を `equals()` に置き換えた
- [ ] EPS の値が問題の座標範囲に対して適切（座標が ±1e9 なら EPS を大きめに）
- [ ] `sqrt()` の引数が負にならないよう `max(0.0, ...)` でガード
- [ ] `acos()` の引数が [-1, 1] の範囲内に収まっている（`clamp` 処理）
- [ ] CCW の戻り値を掛け算する際、整数オーバーフローに注意
- [ ] 線分が退化（長さ0）していないかチェック

---

## 10. その他の発展問題

| 問題 | 解法のヒント |
|------|------------|
| **最近点対（Closest Pair）** | 分割統治法で O(n log n)。ソート後に左右に分割し、再帰的に解く |
| **凸多角形の直径** | キャリパー法（回転キャリパー）で O(n)。凸包後に対蹠点を走査 |
| **凸多角形の切断** | CCW + 直線の交点検出で処理。辺を走査し直線の内側を保持 |
| **Voronoi 図・Delaunay 三角形分割** | Fortune's algorithm O(n log n) |
| **多角形の面積** | 外積の符号付き和（Shoelace formula）: O(n) |
| **一般線分交差（Bentley-Ottmann）** | イベントキュー + BST で O((n + k) log n) |
