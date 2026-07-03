# R コア言語

データ構造・添字・coercion・関数とスコープ・制御構造と反復・OOP・エラー処理・デバッグを、実行可能なコード例とともにまとめたリファレンス。冒頭のレビュー観点は普段のコードチェックで最優先に確認する項目である。

---

## レビュー観点（最優先チェックリスト）

- atomic vector は単一型。異なる型を混ぜると共通型へ coercion される（`logical < integer < double < complex < character`）。意図しない文字列化を疑う。
- 添字は 1-based。`[` は同じ種類のコンテナを返し、`[[` は要素そのもの、`$` は名前付き list/data frame の簡易抽出。
- data frame/matrix で単一行・単一列を抽出すると dimension drop が起きる。形を保つなら `drop = FALSE`。
- `x == NA` は使わない。`is.na()` / `is.null()` / `is.nan()` / `is.finite()` を使う。
- `if` は長さ 1 の条件のみ。ベクトル条件は `ifelse()` / `dplyr::if_else()` / `case_when()`。`&&` / `||` はスカラー専用（R 4.3.0 以降は長さ > 1 でエラー）。
- 長さが割り切れないリサイクルは警告になる。長さを明示的に確認してから演算する。
- `1:length(x)` は `x` が空だと `c(1, 0)` を生む。`seq_along(x)` / `seq_len(length(x))` を使う。
- ループ内で `cbind` / `rbind` によりオブジェクトを伸ばすと O(n^2) のコピーが発生する。事前確保して添字代入する。
- `...` は typo を飲み込む。受け取る引数は検証する。
- factor を数値に戻すときは `as.numeric(as.character(x))`。`as.numeric(factor)` は水準番号を返す。

---

## 1. atomic vector と型・coercion

### 1.1 ベクトル作成と名前付け

`c()` が最も基本的なコンストラクタ。ベクトルは「複数の値」の基本単位で、連結すると平坦化される。名前は演算結果に影響しない補助属性。

```r
c(c(1, 3, 42), c(5, 6))     # 連結は平坦化: 1 3 42 5 6
v <- c(name1 = 1, name2 = 3, oncemore = 42)
names(v)[2] <- "second"     # 名前の変更
as.vector(v)                # 名前を外してプレーンなベクトルへ
```

### 1.2 型と coercion 階層

atomic vector は **単一型** しか持てない。混在させると優先順位の高い型へ強制変換される。

```r
c(TRUE, 1L, 2.5)      # double へ:    1.0 1.0 2.5
c(1, 2, "three")      # character へ: "1" "2" "three"

# 明示的 coercion
as.integer(c(1.9, 2.1))          # 1 2   (切り捨て、四捨五入ではない)
as.numeric(c(TRUE, FALSE, TRUE)) # 1 0 1
as.character(c(1, 2, 3))         # "1" "2" "3"
as.numeric("hello")              # NA   (変換不能。警告あり)

# 型チェック
is.numeric(3.14)   # TRUE
is.integer(3L)     # TRUE
is.double(1:4)     # FALSE  (整数リテラルは integer)
```

暗黙の coercion は演算子経由でも起きる。デバッグ時に見落としやすい。

```r
1:4 + c(T, F, F, T)  # logical が numeric に: 2 2 3 5
paste("value:", 42)  # numeric が character に: "value: 42"
```

### 1.3 系列と繰り返しの生成

```r
3:27                                    # コロン演算子（ステップ 1、降順も自動）
seq(from = 3, to = 27, by = 3)          # 刻み指定
seq(from = 3, to = 27, length.out = 5)  # 個数指定で等分
rep(c(3, 62, 8.3), times = 3)           # 全体を 3 回
rep(c(3, 62, 8.3), each = 2)            # 各要素を 2 回

seq_along(NULL); seq_len(0)   # どちらも integer(0)（空に強い）
# 1:length(x) は x が空だと c(1, 0) になり for が 2 回まわる罠
```

コロン演算子は算術より優先度が高い。ループ変数で頻出する罠。

```r
i <- 2
1:i - 1     # (1:2) - 1 = c(0, 1)  ← リサイクルで意図とずれる
1:(i - 1)   # 1:1 = 1              ← 括弧で正しく評価
```

### 1.4 ベクトル化演算とリサイクル

演算は要素ごと（element-wise）。長さ 1 のスカラーや短いベクトルはリサイクルされる。

```r
foo <- 5.5:0.5           # c(5.5, 4.5, 3.5, 2.5, 1.5, 0.5)
foo + 3                  # スカラーは全要素へ
foo * c(1, -1)           # 長さ 2 が 3 回リサイクル（割り切れる→警告なし）
foo * c(1, -1, 0.5, -0.5)  # Warning: longer object length is not a multiple...
```

---

## 2. 添字と抽出

### 2.1 ベクトルの添字

```r
myvec <- c(5, -2.3, 4, 6, 8, 10, -8)
myvec[length(myvec)]       # 末尾
myvec[c(1, 3, 5)]          # 複数位置
myvec[1:4]                 # 範囲
myvec[c(2, 2, 1)]          # 反復添字で同一要素を複数回取得
myvec[-c(1, 3)]            # 負の添字は除外（正と負の混在は不可）
```

### 2.2 論理インデックス（フィルタ）と上書き

```r
z <- c(5, 2, -3, 8)
z[z * z > 8]               # 条件を満たす要素: 5 -3 8
y <- c(1, 2, 30, 5)
y[z * z > 8]               # 別ベクトルの条件でフィルタも可

x <- c(1, 3, 8, 2, 20)
x[x > 3] <- 0              # 条件に合う位置へ一括代入
x[c(2, 4)] <- c(-2, -0.5)  # 複数位置へ個別代入（リサイクルも働く）
```

`NA` の扱いで `[` と `subset()` は挙動が異なる。

```r
x <- c(6, 1:3, NA, 12)
x[x > 5]           # 6 NA 12   ← NA が混入する
subset(x, x > 5)   # 6 12      ← NA を自動除外
```

### 2.3 all / any / which / ifelse

```r
x <- 1:10
any(x > 8)         # TRUE  一つでも成立するか
all(x > 0)         # TRUE  全て成立するか
which(x %% 2 == 0) # 条件を満たすインデックス: 2 4 6 8 10
which.max(abs(x - median(x)))  # 最大偏差の位置（外れ値検出の常套句）

# ifelse: ベクトル化条件分岐（if とは別物）
ifelse(x %% 2 == 0, 5, 12)  # 偶数→5, 奇数→12
```

### 2.4 コンテナ別の抽出演算子

- `[` … 同じ種類のコンテナを返す（スライス）
- `[[` … 要素そのものを返す（単体取り出し。list/data frame で使う）
- `$` … 名前付き list/data frame の簡易抽出（クォート不要）

部分一致には頼らない。パッケージや共有関数では明示名を使う。

---

## 3. matrix と array

### 3.1 作成と次元

行列は列優先（column-major, `byrow = FALSE` がデフォルト）で埋められる。

```r
matrix(1:6, nrow = 2, ncol = 3)      # 列優先
matrix(1:6, nrow = 2, byrow = TRUE)  # 行優先
rbind(1:3, 4:6)                      # 行として積む
cbind(c(1, 4), c(2, 5), c(3, 6))     # 列として並べる
m <- rbind(c(1, 3, 4), 5:3); dim(m)  # c(行数, 列数); nrow(m); ncol(m)
```

### 3.2 添字と drop

書式は `A[行, 列]`。省略した次元は全要素。単一行・単一列はベクトルに降格する（drop）。

```r
A <- matrix(c(0.3, 4.5, 55.3, 91, 0.1, 105.5, -4.2, 8.2, 27.9), 3, 3)
A[3, 2]        # スカラー
A[, 2]         # 第 2 列（ベクトルに降格）
A[2:3, ]       # 部分行列
A[, -2]        # 第 2 列以外
diag(A)        # 対角要素

A[1, , drop = FALSE]  # drop=FALSE で行列の形を保持
A[2, ] <- 1:3         # 行の一括上書き
diag(A) <- 0          # 対角の一括上書き
```

### 3.3 線形代数

`*` は要素ごとの積。数学的な行列積は `%*%`。

```r
A <- rbind(c(2, 5, 2), c(6, 1, 4))   # 2x3
B <- cbind(c(3, -1, 1), c(-3, 1, 5)) # 3x2
t(A)              # 転置
A %*% B           # 行列積（A の列数 == B の行数）
diag(3)           # 3x3 単位行列（整数スカラーを渡す）
diag(c(2, 3, 5))  # 対角行列（ベクトルを渡す）

M <- matrix(c(3, 4, 1, 2), 2, 2)
solve(M)          # 逆行列（特異行列はエラー）
M %*% solve(M)    # 単位行列に一致
```

### 3.4 apply による行・列への関数適用

```r
z <- matrix(1:6, 3, 2)
apply(z, 2, mean)   # 列ごと（dimcode=2）
apply(z, 1, sum)    # 行ごと（dimcode=1）
colMeans(z); rowSums(z)  # 専用関数の方が高速

# 追加引数は末尾に渡す
copymaj <- function(rw, d) if (sum(rw[1:d]) / d > 0.5) 1 else 0
x <- matrix(c(1,0,1,1,0, 1,1,1,1,0), 2, 5, byrow = TRUE)
apply(x, 1, copymaj, 3)   # 各行の先頭 3 要素の多数決
```

`apply` の出力方向に注意。関数がベクトルを返すと結果は **列** に収まるため、必要に応じて `t()` で転置する。`apply` は base R 実装であり、劇的な高速化はしない点も忘れない。

### 3.5 多次元配列

```r
AR <- array(1:24, dim = c(3, 4, 2))  # dim = c(行, 列, レイヤー)
AR[2, , 2]        # 第 2 レイヤーの第 2 行
AR[1, , ]         # 各レイヤーの第 1 行が列になった行列
```

---

## 4. list

### 4.1 作成とアクセス

list は異なる型・長さを保持できる。`[[` でメンバー、`[` でサブリストを返す。

```r
foo <- list(mat = matrix(1:4, 2, 2), flags = c(T, F, T), msg = "hello")
foo[[1]]          # 行列そのもの
foo$mat[1, 2]     # ドル演算子 + 通常の添字
foo[c(1, 3)]      # サブリスト（長さ 2 の list が返る）
foo$msg <- NULL   # メンバー削除（NULL 代入）
foo$new <- 99     # メンバー追加
```

### 4.2 lapply / sapply / do.call / unlist

```r
lapply(list(1:3, 25:29), median)   # 各要素へ適用 → list を返す
sapply(list(1:3, 25:29), median)   # 結果を単純化 → ベクトル/行列

g <- c("M", "F", "F", "I", "M")
lapply(c("M", "F", "I"), function(gender) which(g == gender))

unlist(list(a = 1:3, b = 4:6))     # 平坦化して名前付きベクトルへ
do.call(rbind, list(c(1, 2), c(3, 4)))  # 引数リストを展開して呼ぶ
do.call(paste, list("a", "b", sep = "-"))  # "a-b"
```

---

## 5. factor と日付

### 5.1 factor

factor は整数ベクトル + levels。カテゴリ順序・未使用水準・数値変換で事故が起きやすい。

```r
sex <- factor(c("female", "female", "male", "female"))
levels(sex); nlevels(sex)

# 観測がない水準も明示できる
ms  <- month.abb                       # "Jan" ... "Dec"
mob <- factor(c("Apr", "Jan", "Dec"), levels = ms)
table(mob)                             # 12 水準すべてを集計

relevel(sex, ref = "male")             # 参照カテゴリの変更
droplevels(mob)                        # 未使用水準の削除

# 数値ラベルの罠
qux <- factor(c(2, 2, 3, 5))
as.numeric(qux)                # 1 1 2 3  ← 水準番号！
as.numeric(as.character(qux))  # 2 2 3 5  ← 正しい復元

# 連続値のビニング
cut(c(0.5, 5.4, 1.5, 3.3), breaks = c(0, 2, 4, 6),
    right = FALSE, include.lowest = TRUE,
    labels = c("Small", "Medium", "Large"))
```

### 5.2 日付・日時

Date と POSIXct/POSIXlt はタイムゾーンと表示形式を分けて考える。

```r
as.Date("2025-02-19")                          # デフォルト YYYY-MM-DD
as.Date("2/19/25", format = "%m/%d/%y")        # 書式指定
d <- as.Date("2025-02-19")
d + 139                                        # 日数加算
as.numeric(d)                                  # 1970-01-01 からの日数
format(d, "%b %y")                             # "Feb 25"
weekdays(d); quarters(d)                       # 曜日・四半期

strptime("2022-10-31 19:34:12",
         format = "%Y-%m-%d %H:%M:%S", tz = "GMT")  # 日時（POSIXlt）
Sys.time(); Sys.timezone()
```

| 指定子 | 意味 | 指定子 | 意味 |
|--------|------|--------|------|
| `%Y` | 4桁年 | `%y` | 2桁年 |
| `%m` | 数値月 | `%B`/`%b` | 月名フル/略 |
| `%d` | 日 | `%H:%M:%S` | 時分秒 |

---

## 6. data frame

### 6.1 作成と構造確認

各列はベクトル（同じ行数が必須）。技術的には list のサブクラス。

```r
df <- data.frame(
  person = c("Peter", "Lois", "Meg"),
  age    = c(42, 40, 17),
  sex    = factor(c("M", "F", "F"))
)
str(df)                       # 構造（型と先頭値）
nrow(df); ncol(df); dim(df)
head(df, 2); colnames(df)
is.list(df)                   # TRUE（list のサブクラス）
```

### 6.2 抽出とフィルタ

```r
df[2, 2]                      # スカラー
df[, c("person", "age")]      # 複数列 → data frame
df$age                        # 列ベクトル
df[, 2, drop = FALSE]         # 1 列 data frame を維持

df[df$sex == "M", ]           # 論理フィルタ（行）
df[df$age > 10 & df$sex == "F", ]  # 複合条件
subset(df, age > 10, select = c(person, age))  # df$ 前置不要
```

列アクセスは 3 通り（`df[[1]]` / `df[, 1]` / `df$person`）あるが、列名を明示する `$` か文字列添字が最も安全。

### 6.3 列・行の追加と NA

```r
df$age.mon <- df$age * 12                     # 列追加
df <- cbind(df, funny = c("Hi", "Lo", "Med")) # 列追加
newrow <- data.frame(person = "Brian", age = 7,
                      sex = factor("M", levels = levels(df$sex)))
df <- rbind(df, newrow)                       # 行追加（factor 水準を合わせる）

mean(c(2, NA, 4))               # NA
mean(c(2, NA, 4), na.rm = TRUE) # 3
df[complete.cases(df), ]        # NA を含む行を除外
lapply(df, class)               # 列ごとの class（list はそのまま lapply 可）
```

欠損を落とす処理は分析結果を変える。`complete.cases()` や `na.rm` を使うときはサンプル数の変化を必ず確認する。

---

## 7. 特殊値（Inf / NaN / NA / NULL）

```r
# Inf: 無限大
-59 / 0        # -Inf（ゼロ除算）
Inf - Inf      # NaN（打ち消しは NaN）
is.infinite(c(-42, Inf, -Inf)); is.finite(3)

# NaN: 非数（NaN は is.na でも TRUE）
0 / 0          # NaN
bar <- c(NaN, 54.3, NA, -Inf)
is.nan(bar)                          # NaN のみ TRUE
which(is.na(bar) & !is.nan(bar))     # 純粋な NA の位置

# NA: 欠損（型別バリエーションあり）
3 + NA         # NA（算術は感染する）
NA > 76        # NA
na.omit(c(NA, 5.89, NaN, 2.10))      # NA/NaN を削除
NA_integer_; NA_real_; NA_character_ # 型付き NA

# NULL: 空オブジェクト（位置を占有しない）
c(2, 4, NA, 8)    # length 4（NA は位置を占める）
c(2, 4, NULL, 8)  # length 3（NULL は消える）
NULL + 53         # numeric(0)
is.null(NULL)     # TRUE（単一値を返す）
lst <- list(a = 1); lst$missing  # 存在しないメンバーは NULL
```

`is.na` / `is.nan` / `is.infinite` は要素ごとにベクトルを返す。`is.null` / `is.list` などはオブジェクト全体で単一値を返す。

---

## 8. attributes と class

```r
foo <- matrix(1:9, 3, 3)
attributes(foo)             # $dim など
attr(foo, "dim")            # 特定属性
dimnames(foo) <- list(c("A","B","C"), c("D","E","F"))

class(1:4)                  # "integer"
class(1.0)                  # "numeric"
class(matrix(1:4, 2, 2))    # "matrix" "array"
typeof(1L)                  # "integer"
typeof(1.0)                 # "double"（class は "numeric"）

# 継承チェック（class(obj) == "foo" は多重継承で漏れる）
ordfac <- factor(c("S","L","M"), levels = c("S","M","L"), ordered = TRUE)
class(ordfac)               # "ordered" "factor"
inherits(ordfac, "factor")  # TRUE
```

「このオブジェクトの正体は？」を調べる定型手順: `class()` → `typeof()` → `names()` → `attributes()` → `unclass()` → `str()`。

---

## 9. 関数

### 9.1 定義と返り値

```r
oddcount <- function(x) {
  k <- 0
  for (n in x) if (n %% 2 == 1) k <- k + 1
  k    # 最後に評価された式が返り値（return 省略可）
}
```

`return()` を省くと最終式が返るが、最後の文が `for` ループだと `NULL` が返る（`for` は invisibly に NULL を返すため）。副作用目的のループを関数末尾に置くときは注意する。

複数の値はリストで返し、成功/失敗で返り値の shape を揺らさない。

```r
oddsevens <- function(v) {
  list(odds  = which(v %% 2 == 1),
       evens = which(v %% 2 == 0))
}
oddsevens(1:5)$odds  # 1 3 5
```

### 9.2 引数マッチングとデフォルト

R は完全指定・部分指定・位置指定・混合で引数を解釈する。部分一致は一意に決まる範囲でのみ有効（`matrix(d = ...)` は data と dimnames の両方に一致してエラー）。

```r
args(matrix)  # 引数順序の確認
matrix(1:9, nrow = 3, ncol = 3)              # 完全指定
matrix(1:9, nr = 3, nc = 3)                  # 部分指定
matrix(1:9, 3, 3)                            # 位置指定

# デフォルト引数は遅延評価（他の引数を参照できる）
f <- function(x, y = x * 2) x + y
f(3)   # 3 + 6 = 9
```

引数の省略検出には `missing()` を使う。

```r
quadratic <- function(a, b, c) {
  if (missing(a) || missing(b) || missing(c)) return("引数不足")
  b^2 - 4 * a * c
}
```

### 9.3 可変長引数 `...`

```r
myplot <- function(x, y, ...) plot(x, y, ...)  # 後段へ透過
wrapper <- function(...) {
  args <- list(...)                            # 展開して検査
  cat("引数の数:", length(args), "名前:", names(args), "\n")
}
wrapper(x = 1:5, col = "red")
```

`...` は typo を静かに飲み込む。受け取る引数を検証する設計にする。

### 9.4 パイプ `|>`（R 4.1.0+）

左辺を右辺関数の第 1 引数に渡す。可読性向上の手段であり、速度上の優位はない。

```r
mtcars |> subset(am == 0, c(hp, mpg)) |> colMeans()
mtcars |> head(3)   # head(mtcars, 3) と同じ
```

### 9.5 無名関数と関数オブジェクト

```r
apply(matrix(1:12, 3, 4), 2, function(x) sort(x, decreasing = TRUE))
lapply(list("a", c("b","c")), \(v) paste0(v, "!"))  # \() は 4.1.0+ の短縮記法

f1 <- function(a, b) a + b
formals(f1); body(f1); environment(f1)  # 関数はオブジェクトとして検査可能
```

---

## 10. スコープ（lexical scoping・環境・クロージャ）

### 10.1 検索順序

R は lexical scoping。関数内で見つからない名前は **定義環境** を外側へ順にたどる。暗黙のグローバル参照は避ける。

```r
w <- 12
f <- function(y) {
  d <- 8
  h <- function() d * (w + y)   # d, y は f のローカル、w はグローバル
  h()
}
f(2)   # 8 * (12 + 2) = 112
```

関数内での代入はローカルコピーを作り、グローバルは変わらない。

```r
w <- 12
f <- function(y) { w <- w + 1; w }  # ローカルの w
f(4)   # 13
w      # 12 のまま
```

### 10.2 スーパーアサイン `<<-` とクロージャ

`<<-` は上位環境を検索して代入する（なければグローバルに作成）。クロージャで状態を持たせるのが定石。

```r
make_counter <- function() {
  count <- 0
  list(
    inc = function() { count <<- count + 1; invisible(count) },
    get = function() count
  )
}
cnt <- make_counter()
cnt$inc(); cnt$inc()
cnt$get()   # 2

make_adder <- function(n) function(x) x + n  # n を抱え込む
add5 <- make_adder(5); add5(3)  # 8
```

`environment()` / `parent.frame()` / `new.env()` / `assign()` / `get()` で環境を明示操作できる。

---

## 11. 制御構造と反復

### 11.1 条件分岐

```r
if (a <= b) { a <- a^2 } else { a <- a - 3.5 }

# switch: 複数選択の省略記法
switch("Lisa", Homer = 12, Lisa = 78, NA)  # 78（最終のタグなし値がデフォルト）
switch(3, 12, 34, 56, 78)                  # 位置指定 → 56
```

`if` はベクトルを受け付けない（R 4.3.0 以降エラー）。要素別分岐は `ifelse()`。

```r
ifelse(-5:5 == 0, NA, 5 / (-5:5))  # ゼロ割りを NA に置換
```

### 11.2 ループ

```r
# for: インデックスで回すなら seq_along（空ベクトルに強い）
for (i in seq_along(myvec)) print(2 * myvec[i])

# while: 回数が未定のとき
myval <- 5
while (myval < 10) myval <- myval + 1

# repeat: break まで無制限（do-while 相当）
fib.a <- 0; fib.b <- 1
repeat {
  tmp <- fib.a + fib.b; fib.a <- fib.b; fib.b <- tmp
  if (fib.b > 150) break
}

# break / next は最内ループにのみ作用
for (i in seq_along(bar)) {
  if (bar[i] == 0) next        # スキップ
  result[i] <- foo / bar[i]
}
```

### 11.3 apply 族による暗黙ループ

```r
lapply(baz, is.matrix)                 # list → list
sapply(baz, function(x) class(x)[1])   # 単純化して返す
vapply(baz, is.matrix, logical(1))     # 出力型を固定（推奨）
tapply(ChickWeight$weight, ChickWeight$Chick, max)  # 因子でグループ集計
Map(function(x, y) x + y, 1:4, 5:8)    # 複数引数の並列適用
Reduce(`+`, 1:5, accumulate = TRUE)    # 畳み込み
```

型を固定したいときは `vapply()`、tidyverse では `purrr::map_*()` 系で出力型を明示する。

### 11.4 再帰

```r
myfibrec <- function(n) {
  if (n == 0 || n == 1) return(n)   # 停止条件（必須）
  myfibrec(n - 1) + myfibrec(n - 2)
}
myfibrec(10)  # 55
```

停止条件のない再帰は無限再帰になる。単純なループで書けるケースは反復の方が高速で安全。木構造の走査や分割統治では再帰が有効。

### 11.5 パフォーマンスの鉄則

大きなオブジェクトを反復的に伸ばさず、事前確保して添字代入する。

```r
# 悪例: ループ内で cbind → O(n^2) の再割り当て
# 良例: 事前確保
result <- matrix(NA_real_, nrow = nrow(input), ncol = k)
for (i in seq_len(nrow(input))) result[i, ] <- compute(input[i, ])

system.time({ z <- x + y })  # 実行時間計測（elapsed が実時間）
```

---

## 12. OOP の使い分け

| 系統 | 定義 | 型安全 | ミュータブル | 用途 |
|------|------|--------|------------|------|
| S3 | `class(obj) <- "foo"` | 低 | 非対応 | base/tidyverse の大半 |
| S4 | `setClass()` | 高 | 非対応 | 厳密な API・Bioconductor 系 |
| R5 | `setRefClass()` | 中 | 対応 | stateful object |
| R6 | `R6::R6Class()` | 中 | 対応 | R5 より軽量 |

既存パッケージを拡張するときは、そのエコシステムが使う OOP に合わせる。

### 12.1 S3（軽量 generic/method）

実体は list + class 属性。generic は `UseMethod()` でディスパッチし、`generic.class` という命名のメソッドを探す。

```r
new_employee <- function(name, salary, union = FALSE) {
  structure(list(name = name, salary = salary, union = union),
            class = "employee")
}
print.employee <- function(x, ...) {
  cat(x$name, "salary:", x$salary, "union:", x$union, "\n")
}
joe <- new_employee("Joe", 55000, TRUE)
joe   # print() → UseMethod("print") → print.employee()

# 継承は class ベクトルの順序
kate <- structure(list(name = "Kate", salary = 68000, hrs = 2),
                  class = c("hrlyemployee", "employee"))
print.hrlyemployee <- function(x, ...) {
  NextMethod()                       # 親 print.employee を呼ぶ
  cat("hours:", x$hrs, "\n")
}
methods(class = "employee")          # 定義済みメソッド一覧
```

S3 はフィールド名の typo を検出しない（`joe$slary <- 1` が通る）。これが S4 を選ぶ主な動機。

### 12.2 S4（型安全・slot）

```r
setClass("employee",
  representation(name = "character", salary = "numeric", union = "logical"))
joe <- new("employee", name = "Joe", salary = 55000, union = TRUE)
joe@salary                 # slot 参照（@ または slot()）
joe@salry <- 1             # Error: slot が存在しない → 型安全

setGeneric("give_raise", function(emp, amount) standardGeneric("give_raise"))
setMethod("give_raise", "employee", function(emp, amount) {
  emp@salary <- emp@salary + amount; emp
})
setClass("Manager", contains = "employee",       # 継承
         representation(dept = "character"))
setMethod("show", "Manager", function(object) {   # print 相当
  callNextMethod(); cat("Dept:", object@dept, "\n")
})
```

`validity` で不変条件を強制でき、`validObject()` が無効状態を拒否する。

### 12.3 R5 / R6（参照セマンティクス）

代入してもコピーされない（参照が共有される）。副作用を持つ stateful なオブジェクト向け。

```r
# R5
Account <- setRefClass("Account",
  fields = list(owner = "character", balance = "numeric"),
  methods = list(
    deposit  = function(a) balance <<- balance + a,
    withdraw = function(a) { if (a > balance) stop("不足"); balance <<- balance - a }
  ))
acc <- Account$new(owner = "Alice", balance = 1000)
acc$deposit(500)
acc2 <- acc          # 参照コピー（acc も変わる）
acc3 <- acc$copy()   # 真のコピー

# R6（要 install.packages("R6"); self$ で代入・メソッドチェーン）
library(R6)
Counter <- R6Class("Counter", public = list(
  count = 0,
  increment = function(by = 1) { self$count <- self$count + by; invisible(self) }
))
c1 <- Counter$new(); c1$increment(5)$increment(3)$count  # 8
```

R5 は `<<-`、R6 は `self$field <-` で状態を更新する。分析コードでは副作用を増やしすぎない。

---

## 13. エラー処理

### 13.1 発生させる

```r
safe_sqrt <- function(x) { if (any(x < 0)) stop("負の値は不可"); sqrt(x) }
checked_log <- function(x) { if (any(x <= 0)) warning("非正の値あり"); log(x) }
message("進捗表示（標準エラー出力へ）")
```

`stop()` は中断、`warning()` は継続、`message()` は情報通知。

### 13.2 捕捉する

```r
result <- tryCatch(
  { log(-1); "ok" },
  warning = function(w) { cat("警告:", conditionMessage(w), "\n"); NaN },
  error   = function(e) { cat("エラー:", conditionMessage(e), "\n"); NA },
  finally = cat("finally は常に実行\n")
)
```

`try()` はより簡易で、失敗時に `"try-error"` クラスのオブジェクトを返す。

```r
r <- try(log("a"), silent = TRUE)
if (inherits(r, "try-error")) cat("失敗\n")
```

エラーを値として扱いたいときは `purrr::safely()` / `purrr::possibly()` も使える。

### 13.3 継続ハンドラと後処理

`withCallingHandlers` は `tryCatch` と異なりコールスタックを巻き戻さず、処理を継続できる。

```r
warns <- character(0)
withCallingHandlers(
  { log(-1); sqrt(4) },
  warning = function(w) {
    warns <<- c(warns, conditionMessage(w))
    invokeRestart("muffleWarning")   # 警告を抑制して続行
  }
)
```

`on.exit()` は正常終了・エラー終了のいずれでも必ず実行される。リソース解放に使う。

```r
read_safe <- function(path) {
  con <- file(path, "r")
  on.exit(close(con), add = TRUE)   # 関数終了時に必ずクローズ
  readLines(con)
}
```

テスト中は `options(warn = 2)` で警告をエラーに昇格させて止めると発見が早い（`warn = 0` に戻す）。

---

## 14. デバッグ

### 14.1 事後検査

```r
traceback()                   # 直近エラーのコールチェーン
rlang::last_trace()           # tidyverse/rlang 系
options(error = recover)      # エラー時に対話デバッガ（where で位置確認）
options(error = NULL)         # 通常モードへ戻す
```

### 14.2 ブレークポイント

```r
debugonce(findruns)           # 一度だけステップ実行
debug(f); undebug(f)          # 常時デバッグ/解除
browser()                     # コードに直接挿入して一時停止
if (i > 49) browser()         # 条件付きブレーク（後半反復のみ）
trace(gy, browser)            # ソースを変えずに挿入。untrace(gy) で解除
setBreakpoint("findruns.R", 5)  # ファイル行番号で指定
```

ブラウザ内コマンド: `n`/Enter（次行）、`c`（続行）、`where`（スタック）、`Q`（終了）。変数 `n` を見たいときは `print(n)`（`n` はコマンドと衝突するため）。

### 14.3 オブジェクト構造の確認

```r
str(lmout, max.level = 2)     # ネスト構造を再帰表示
dplyr::glimpse(mtcars)        # data frame/tibble に特化
unclass(table(mtcars$cyl))    # class を外して生の構造を見る
typeof(x); class(x); attributes(x)
```

### 14.4 最小再現例（reprex）

外部ファイルや巨大データに依存しない失敗例へ縮小する。

```r
set.seed(42)
df_min <- data.frame(x = c(1, 2, NA, 4), y = c("a", "b", "c", "d"))
sessionInfo()                 # R/OS/パッケージのバージョンを添付
# library(reprex); reprex({ ... })  # 出力付き Markdown を生成
```

判断フロー: エラーメッセージあり→`traceback()`、クラッシュ後→`options(error=recover)`、位置に見当あり→`browser()`、関数全体を追う→`debugonce()`、ソースを変えたくない→`trace()`/`setBreakpoint()`、構造が謎→`str()`/`attributes()`/`unclass()`。
