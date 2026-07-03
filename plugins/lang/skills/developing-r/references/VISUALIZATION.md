# R 可視化（base graphics と ggplot2）

R には性格の異なる 2 つの主要な描画系がある。base graphics は「キャンバスに命令を積み上げる」手続き的なモデルで、素早い探索や統計オブジェクトの即席プロットに強い。ggplot2 は Grammar of Graphics に基づく宣言的なモデルで、多次元データを一貫した文法で組み立て、再利用・拡張しやすい。どちらを選ぶかは「使い捨ての探索か」「積み上げて洗練させる図か」で判断するとよい。

---

## Part 1: base graphics

### 描画の 3 層モデルと高水準／低水準関数

base graphics は **デバイス → プロット領域 → プロット内容** の 3 層で動く。関数は役割で 3 種に分かれる。

| 種別 | 役割 | 代表関数 |
|---|---|---|
| **高水準** | デバイスを初期化して新しい図を描く | `plot()`, `hist()`, `barplot()`, `boxplot()`, `pie()`, `curve()`, `matplot()` |
| **低水準** | 既存の図に要素を追加する（デバイスをリセットしない） | `points()`, `lines()`, `abline()`, `segments()`, `text()`, `legend()`, `axis()`, `arrows()`, `polygon()` |
| **パラメータ** | 描画環境を大域的に設定する | `par()` |

高水準関数を呼ぶたびに現在のデバイスがリフレッシュされ、前の図は消える。段階的に図を積み上げたいときは `type = "n"` で空のキャンバスを作り、低水準関数で要素を足していく。この「空キャンバス → 追加」の流儀が base graphics の柔軟さの源になる。

### plot() の基本と type 引数

```r
foo <- c(1.1, 2, 3.5, 3.9, 4.2)
bar <- c(2, 2.2, -1.3, 0, 0.2)

plot(foo, bar)                 # 座標ベクトルで散布図

baz <- cbind(foo, bar)
plot(baz)                      # 行列やデータフレームも渡せる（左列=x, 右列=y）
```

`type` で描画モードを切り替える。

```r
plot(foo, bar, type = "p")   # 点のみ（既定）
plot(foo, bar, type = "l")   # 線のみ
plot(foo, bar, type = "b")   # 点と線（between: 点と線の間に隙間）
plot(foo, bar, type = "o")   # 点と線の重ね合わせ（隙間なし）
plot(foo, bar, type = "n")   # 何も描かない（軸だけ）— 段階構築の起点
plot(foo, bar, type = "h")   # 垂直線（ヒストグラム型）
plot(foo, bar, type = "s")   # 階段状
```

タイトルと軸ラベルは高水準関数の引数で与える。

```r
plot(foo, bar,
     main = "1行目\n2行目",   # \n で改行
     xlab = "",              # 空文字でラベルを消す
     ylab = "")
```

### 色・点・線のスタイル指定

色は整数（1〜8）、色名、`rgb()` のいずれでも指定できる。

```r
plot(foo, bar, col = 2)              # 整数: 2=red
plot(foo, bar, col = "steelblue")    # 色名

length(colors())                     # 認識される色名の総数（657）

col_custom <- rgb(0.2, 0.6, 0.9)                    # 各成分 0〜1
col_hex    <- rgb(51, 153, 230, maxColorValue = 255) # 0〜255 スケール
col_alpha  <- rgb(1, 0, 0, alpha = 0.4)             # 半透明の赤（重なり対策）
```

連続値を色で表すときはグラデーションパレットを作る。

```r
palette()                            # 現在のパレットを確認
palette(c("navy", "firebrick", "darkgreen"))  # 変更
palette("default")                   # 既定に戻す

ramp <- colorRampPalette(c("white", "steelblue"))
ramp(5)                              # 5 段階の色ベクトルを返す

n    <- 20
cols <- colorRampPalette(c("yellow", "red"))(n)
plot(1:n, 1:n, col = cols, pch = 19, cex = 2)
```

点の形状 `pch`、線種 `lty`、太さ `lwd`、サイズ `cex` を組み合わせる。

```r
# pch: 1=○, 2=△, 3=+, 4=×, 15=■, 16/19=●, 17=▲, 21〜25=境界と塗りを分離
plot(1:5, 1:5, pch = 21:25, col = "black", bg = "yellow", cex = 2)
#   pch 21〜25 は col=境界色, bg=塗り色 で色付けする

# lty: 1=solid, 2=dashed, 3=dotted, 4=dotdash, 5=longdash, 6=twodash
plot(1:10, type = "l", lty = 2, lwd = 2)

plot(foo, bar, type = "b", col = 4, pch = 8,
     lty = 2, cex = 2.3, lwd = 3.3)   # cex=点倍率, lwd=線幅倍率
```

### プロット領域と par()

```r
plot(foo, bar, xlim = c(-10, 5), ylim = c(-3, 3))  # 軸範囲を広げて注釈の場所を確保
plot(foo, bar, pch = 19, asp = 1)                  # asp=1 で x/y の単位長を揃える（地図など）
```

`par()` の設定は `dev.off()` するか明示的に戻すまで持続する。**保存 → 変更 → 復元** のイディオムを徹底する。

```r
old_par <- par(no.readonly = TRUE)   # 現在値を全保存
par(
  mfrow    = c(2, 3),          # 2 行 3 列パネル（行優先）。列優先は mfcol
  mar      = c(5, 4, 4, 2) + 0.1,  # 内側余白: 下・左・上・右（行数単位）
  oma      = c(0, 0, 2, 0),    # 外側余白（複数パネル共通タイトル用）
  bg       = "white", fg = "black",
  las      = 1,                # 軸ラベルを常に水平
  cex.axis = 0.8, cex.lab = 1.1, cex.main = 1.3
)
# ... 作図 ...
par(old_par)                   # 必ず元に戻す
```

複数パネルと共通タイトル。

```r
par(oma = c(0, 0, 3, 0), mfrow = c(1, 2))
plot(rnorm(50)); hist(rnorm(50))
mtext("共通タイトル", outer = TRUE, cex = 1.5, line = 1)
par(mfrow = c(1, 1), oma = c(0, 0, 0, 0))
```

### 低水準関数で図を積み上げる

```r
x <- 1:20
y <- c(-1.49, 3.37, 2.59, -2.78, -3.94, -0.92, 6.43, 8.51, 3.41, -8.23,
       -12.01, -6.58, 2.87, 14.12, 9.63, -4.58, -14.78, -11.67, 1.17, 15.62)

plot(x, y, type = "n")                          # 1. 空キャンバス
abline(h = c(-5, 5), col = "red", lty = 2, lwd = 2)   # 2. 水平の境界線
segments(x0 = c(5, 15), y0 = c(-5, -5),         # 3. 有限長の垂直線分
         x1 = c(5, 15), y1 = c( 5,  5), col = "red", lty = 3, lwd = 2)
points(x[y >= 5],  y[y >= 5],  pch = 4, col = "darkmagenta", cex = 2)  # 4. 条件別の点
points(x[y <= -5], y[y <= -5], pch = 3, col = "darkgreen",   cex = 2)
lines(x, y, lty = 4)                            # 5. 全点を結ぶ線
arrows(x0 = 8, y0 = 14, x1 = 11, y1 = 2.5)      # 6. 矢印（先端が (x1,y1)）
text(x = 8, y = 15, labels = "スイートスポット") # 7. 注釈（labels の中心が座標）
```

`abline()` は水平・垂直・切片傾き・回帰オブジェクトのいずれでも直線を引ける。

```r
abline(h = 0, v = 0)                 # y=0, x=0
abline(a = 2, b = 1)                 # y = 2 + 1*x（切片, 傾き）
lmout <- lm(y ~ x); abline(lmout)    # 回帰直線を自動で描く
```

`text()` の `pos`（1=下, 2=左, 3=上, 4=右）で点からラベルをずらす。凡例は `legend()` で、`NA` を使って「その項目にはこの属性を使わない」ことを表す。

```r
plot(1:5, col = c("red", "blue"), pch = c(19, 17), cex = 1.5)
legend("topleft",
       legend = c("グループA", "グループB"),
       col    = c("red", "blue"),
       pch    = c(19, 17),
       bty    = "n")                 # bty="n" で枠線を消す

# 点と線を混在させる凡例: pt.cex が点サイズ, cex が凡例テキストサイズ
legend("bottomleft",
       legend = c("全点を結ぶ線", "sweet", "too big", "too small", "境界"),
       pch    = c(NA, 19, 4, 3, NA),
       lty    = c(4,  NA, NA, NA, 2),
       col    = c("black", "blue", "darkmagenta", "darkgreen", "red"),
       lwd    = c(1,  NA, NA, NA, 2),
       pt.cex = c(NA, 1,  2,  2,  NA))
```

軸を手動制御するには高水準側で `xaxt="n"` / `yaxt="n"` を指定してから `axis()` を呼ぶ。

```r
plot(1:12, rnorm(12), xaxt = "n")
axis(side = 1, at = 1:12, labels = month.abb, las = 2)  # side: 1=下,2=左,3=上,4=右

plot(10^(1:5), 1:5, log = "xy")      # 両軸を対数スケールに
```

### 統計プロット関数

```r
x <- rnorm(200)
hist(x, freq = FALSE, breaks = 20, col = "steelblue", border = "white",
     main = "分布", xlab = "値", ylab = "密度")
lines(density(x), col = "red", lwd = 2)   # 密度曲線を重ねる
h <- hist(x, plot = FALSE)                # 描画せず区間・頻度を取り出す
h$breaks; h$counts; h$density
```

```r
dat <- data.frame(value = c(rnorm(50), rnorm(50, 2), rnorm(50, 4)),
                  group = rep(c("A", "B", "C"), each = 50))
boxplot(value ~ group, data = dat, notch = TRUE,
        col = c("skyblue", "salmon", "lightgreen"))  # notch=信頼区間のくびれ
```

```r
counts <- c(A = 30, B = 45, C = 20, D = 35)
barplot(counts, col = "steelblue", horiz = FALSE)    # horiz=TRUE で横棒

mat <- matrix(c(10, 20, 30, 15, 25, 5), nrow = 2,
              dimnames = list(c("Q1", "Q2"), c("A", "B", "C")))
barplot(mat, beside = FALSE, legend = rownames(mat))  # FALSE=積み上げ, TRUE=並列
```

```r
pie(c(30, 25, 20, 15, 10), col = rainbow(5))          # 円グラフ（比較には棒グラフが優る）

curve(exp(-x) * sin(x), from = 0, to = 4*pi,          # 関数のグラフ（expr 内で x を使う）
      col = "steelblue", lwd = 2, main = "減衰振動")
curve(cos(x), add = TRUE, col = "red", lty = 2)       # add=TRUE で重ね描き

y_mat <- matrix(rnorm(30), nrow = 10, ncol = 3)       # 行列の各列を折れ線に
matplot(1:10, y_mat, type = "b", pch = 1:3, lty = 1:3, col = c("red", "blue", "green"))
```

補助的な低水準関数として、曲線下の面積を塗る `polygon()`、散布図に平滑曲線を重ねる `lowess()` がある。

```r
f <- function(x) 1 - exp(-x); curve(f, 0, 2)
polygon(c(1.2, 1.4, 1.4, 1.2), c(0, 0, f(1.3), f(1.3)), col = "lightgray")

d <- data.frame(x = rnorm(100), y = rnorm(100))
plot(d); lines(lowess(d), col = "red", lwd = 2)
```

### グラフの保存（デバイス関数）

デバイスを開く → 作図する → **`dev.off()` で閉じる** の 3 段を守る。閉じ忘れるとファイルが壊れる。

```r
png("out.png", width = 1200, height = 900, res = 150, type = "cairo")
  plot(rnorm(100)); abline(h = 0, lty = 2, col = "red")
dev.off()

pdf("out.pdf", width = 7, height = 5, useDingbats = FALSE)  # ベクター・印刷向き（インチ）
  hist(rnorm(1000), col = "steelblue")
dev.off()

svg("out.svg", width = 6, height = 4); barplot(1:5, col = rainbow(5)); dev.off()
```

関数内では `on.exit(dev.off())` で閉じ忘れを防ぐ。ループで複数ファイルを吐くときは各反復でデバイスを開閉する。`dev.list()` / `dev.cur()` / `dev.set(n)` で開いているデバイスの一覧・確認・切替ができる。

```r
for (i in 1:5) {
  pdf(sprintf("hist_%02d.pdf", i))
  hist(rnorm(100, sd = i), main = paste("sd =", i))
  dev.off()
}
```

---

## Part 2: ggplot2 と Grammar of Graphics

### 層構造の考え方

ggplot2 はグラフを「独立した層の合成物」として捉える。最終的なプロットは以下の部品を `+` で積み上げて構成する。

| 構成要素 | 役割 |
|---|---|
| **Data** | プロットに使うデータフレーム |
| **Aesthetics (`aes`)** | 変数 → 視覚属性（x/y/color/fill/size/shape/alpha/linetype）のマッピング |
| **Geoms** | 幾何オブジェクト（点・線・棒・箱ひげ等） |
| **Stats** | データ変換（ビニング・スムージング・平均など） |
| **Scales** | 美的属性のスケール制御（軸範囲・色パレット・凡例） |
| **Coord** | 座標系（デカルト・極・地図等） |
| **Facets** | 条件によるパネル分割 |
| **Theme** | 非データ的な外観（フォント・背景・グリッド線） |

### 基本構文と aes() の内外

```r
library(ggplot2)

# 最小構成: data + aes + geom
ggplot(iris, aes(x = Sepal.Length, y = Sepal.Width)) +
  geom_point()

# aes() をグローバルに書くと後続の geom にも継承される
ggplot(iris, aes(x = Sepal.Length, y = Sepal.Width, col = Species)) +
  geom_point() +
  geom_smooth(method = "loess")   # Species ごとにスムーザが引かれる
```

**最重要の落とし穴**: 定数を `aes()` の中に書くと、それは「マッピング」として扱われ意図しない結果になる。定数は `aes()` の外で直接渡す。

```r
# 誤: "blue" という 1 水準の因子にマッピングされ、既定色が割り当たる
ggplot(iris, aes(x = Sepal.Length, y = Sepal.Width, color = "blue")) + geom_point()

# 正: 定数は aes() の外
ggplot(iris, aes(x = Sepal.Length, y = Sepal.Width)) + geom_point(color = "blue")
```

### 主要 geom

```r
# 散布図: 追加変数を size/color/alpha に載せる
ggplot(iris, aes(x = Petal.Length, y = Petal.Width)) +
  geom_point(aes(color = Species, size = Sepal.Length), alpha = 0.6)

# 折れ線: カテゴリ別は group を必ず指定（怠ると全点を 1 本に結んで崩れる）
ggplot(economics_long, aes(x = date, y = value, color = variable, group = variable)) +
  geom_line()
```

`geom_bar` と `geom_col` の使い分けと `position`。

```r
ggplot(mpg, aes(x = class)) + geom_bar()            # 未集計データ → count を自動計算

df <- data.frame(class = c("SUV", "compact", "pickup"), n = c(62, 47, 33))
ggplot(df, aes(x = class, y = n)) + geom_col()      # 集計済みの y をそのまま高さに

ggplot(mpg, aes(x = class, fill = drv)) + geom_bar(position = "dodge")  # 並列
ggplot(mpg, aes(x = class, fill = drv)) + geom_bar(position = "fill")   # 比率(0〜1)
```

分布・密度・平滑化・ヒートマップ。

```r
ggplot(mpg, aes(x = hwy)) + geom_histogram(binwidth = 2, fill = "steelblue", color = "white")

ggplot(mpg, aes(x = hwy, fill = drv)) + geom_density(alpha = 0.4)  # 半透明で重ね描き

ggplot(mpg, aes(x = class, y = hwy, fill = drv)) +
  geom_boxplot(position = "dodge") + coord_flip()

ggplot(mpg, aes(x = displ, y = hwy)) +
  geom_point() +
  geom_smooth(method = "lm", level = 0.90)          # 直線回帰・信頼水準 90%
# method="loess" は非パラメトリック。span を小さくするほど局所的になる

# 相関行列のヒートマップ
library(reshape2)
melted <- melt(round(cor(mtcars), 2))
ggplot(melted, aes(x = Var1, y = Var2, fill = value)) +
  geom_tile() +
  scale_fill_gradient2(low = "blue", high = "red", mid = "white",
                       midpoint = 0, limits = c(-1, 1)) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
```

### stat（統計変換）

各 geom は内部で stat を呼んでいる。明示的に使う場面もある。`after_stat()` は旧 `..density..` 記法の後継。

```r
ggplot(iris, aes(x = Species, y = Petal.Length)) +
  stat_summary(fun = mean, geom = "bar", fill = "steelblue") +
  stat_summary(fun.data = mean_sdl, geom = "errorbar", width = 0.2)

ggplot(mpg, aes(x = hwy)) +
  stat_bin(bins = 20, geom = "line", aes(y = after_stat(density)))
```

### scale_* — 軸と色のスケール

```r
ggplot(mpg, aes(x = displ, y = hwy)) +
  geom_point() +
  scale_x_continuous(name = "排気量 (L)", limits = c(1, 8), breaks = seq(1, 8, 1)) +
  scale_y_continuous(name = "高速燃費 (mpg)")

ggplot(diamonds, aes(x = carat, y = price)) +
  geom_point(alpha = 0.1) + scale_x_log10() + scale_y_log10()
```

色スケールは **データの性質** で選ぶ。ここが最も間違えやすい。

```r
# 連続変数 → _c / gradient 系
ggplot(mpg, aes(x = displ, y = hwy, color = cty)) +
  geom_point() + scale_color_viridis_c()               # 知覚均一・色覚対応

ggplot(mtcars, aes(x = wt, y = mpg, color = hp - mean(hp))) +
  geom_point(size = 3) +
  scale_color_gradient2(low = "blue", mid = "white", high = "red", midpoint = 0)  # 分岐

# カテゴリ変数 → manual / brewer(質的) 系
ggplot(iris, aes(x = Sepal.Length, y = Sepal.Width, color = Species)) +
  geom_point() +
  scale_color_manual(values = c(setosa = "#E41A1C", versicolor = "#377EB8",
                                virginica = "#4DAF4A"))

ggplot(iris, aes(x = Sepal.Length, y = Sepal.Width, color = Species)) +
  geom_point() + scale_color_brewer(palette = "Dark2")
```

**誤用**: 連続変数に離散専用パレット（`scale_color_brewer` / `scale_color_manual`）を当てると `Continuous value supplied to discrete scale` の警告が出て意図しない結果になる。連続 brewer が欲しければ `scale_color_distiller()` を使う。

```r
# 誤: 連続の Sepal.Length に離散パレット
ggplot(iris, aes(Petal.Length, Petal.Width, color = Sepal.Length)) +
  geom_point() + scale_color_brewer(palette = "Set1")   # → Warning

# 正
ggplot(iris, aes(Petal.Length, Petal.Width, color = Sepal.Length)) +
  geom_point() + scale_color_distiller(palette = "Blues", direction = 1)
```

`size` / `shape` のスケール。

```r
ggplot(mpg, aes(x = displ, y = hwy, size = cty, shape = factor(cyl))) +
  geom_point(alpha = 0.7) +
  scale_size_continuous(range = c(1, 8)) +
  scale_shape_manual(values = c("4" = 16, "5" = 17, "6" = 15, "8" = 18))
```

### facet_wrap と facet_grid

```r
ggplot(mpg, aes(x = displ, y = hwy)) + geom_point() +
  facet_wrap(~ class, nrow = 2)                    # 1 変数で折り返し分割

ggplot(mpg, aes(x = displ, y = hwy)) + geom_point() +
  facet_wrap(~ class, scales = "free")             # 各パネル独立スケール（free_x/free_y も可）

ggplot(mpg, aes(x = displ, y = hwy)) + geom_point() +
  facet_grid(drv ~ cyl)                            # 行=drv, 列=cyl の格子
# facet_grid(. ~ cyl) 列方向のみ / facet_grid(drv ~ .) 行方向のみ
```

比較設計の指針: **最も直接比較したいカテゴリは facet に割り当てず、x 軸や fill に置く**。facet は「補助的な条件分け」に向く。

```r
library(MASS)
surv <- na.omit(survey[, c("Sex", "Wr.Hnd", "Exer")])
# 性別を直接比較したい → x=Sex, facet=Exer（補助）
ggplot(surv, aes(x = Sex, y = Wr.Hnd)) + geom_boxplot() + facet_grid(. ~ Exer)
```

### coord_* — 座標系

```r
ggplot(mpg, aes(x = class, y = hwy)) + geom_boxplot() + coord_flip()   # 軸反転

# 表示範囲の制限は coord_cartesian（データは保持）
ggplot(mpg, aes(x = displ, y = hwy)) + geom_point() +
  coord_cartesian(xlim = c(2, 5), ylim = c(15, 40))
# 注意: scale_*_continuous(limits=) は範囲外データを「除去してから」統計を計算する。
#       ズームしたいだけなら coord_cartesian を使う。

ggplot(mpg, aes(x = factor(1), fill = class)) +
  geom_bar(width = 1) + coord_polar(theta = "y")                        # 極座標(円グラフ)

ggplot(mpg, aes(x = displ, y = hwy)) + geom_point() + coord_equal()     # 縦横比固定
```

### labs と theme

```r
ggplot(iris, aes(x = Sepal.Length, y = Sepal.Width, color = Species)) +
  geom_point() +
  labs(title = "がく片の長さと幅", subtitle = "品種で色分け",
       x = "長さ (cm)", y = "幅 (cm)", color = "品種",
       caption = "出典: 公開データセット")

# 数式ラベル
ggplot(data.frame(x = rnorm(200)), aes(x = x)) +
  geom_histogram(bins = 30) +
  labs(x = expression(paste("値 ", bar(x))), y = expression(N[obs]))
```

組み込みテーマと個別調整。

```r
p <- ggplot(mpg, aes(x = displ, y = hwy)) + geom_point()
p + theme_bw()        # 白背景+グリッド
p + theme_classic()   # 軸のみ（論文向き）
p + theme_minimal()
p + theme_void()      # 軸なし（地図向き）

ggplot(iris, aes(x = Species, y = Sepal.Length, fill = Species)) +
  geom_boxplot() +
  theme_bw() +
  theme(
    plot.title       = element_text(size = 14, face = "bold", hjust = 0.5),
    axis.text.x      = element_text(angle = 45, hjust = 1),
    legend.position  = "bottom",
    legend.title     = element_blank(),
    panel.grid.minor = element_blank(),
    strip.text       = element_text(face = "bold")   # facet ラベル
  )
```

凡例の細かい制御は `theme(legend.position=)` と `guides()` で行う。

```r
p + theme(legend.position = "none")            # 非表示
p + theme(legend.position = c(0.8, 0.2))       # プロット内部の相対座標

ggplot(iris, aes(Sepal.Length, Sepal.Width, color = Species, size = Petal.Length)) +
  geom_point(alpha = 0.7) +
  guides(color = guide_legend(title = "品種", nrow = 1),
         size  = guide_legend(title = "花弁長 (cm)"))
```

### ggsave と複数プロットの配置

```r
p <- ggplot(iris, aes(Sepal.Length, Sepal.Width, color = Species)) +
  geom_point() + theme_classic()

ggsave("out.png", plot = p, width = 8, height = 6, dpi = 300)   # ラスタ: dpi 重要
ggsave("out.pdf", plot = p, width = 8, height = 6)              # ベクタ: dpi 不要
ggsave("out.svg", plot = p, width = 8, height = 6, device = "svg")
# plot= を省くと直前にアクティブなプロットが保存される
```

`gridExtra` / `patchwork` で複数図を並べる。

```r
library(gridExtra)
grid.arrange(g1, g2, g3, nrow = 2)
grid.arrange(g1, g2, g3,
             layout_matrix = matrix(c(1, 2, 3, 3), nrow = 2, byrow = TRUE))

library(patchwork)
g1 + g2          # 横並び
g1 / g2          # 縦積み
(g1 | g2) / g3   # 上段 2 枚・下段 1 枚
```

### 多次元表現のパターン

| 次元 | 使う美的属性 |
|---|---|
| 第 1 / 第 2 | x 軸 / y 軸 |
| 第 3（連続） | color（グラデーション）または size |
| 第 4（カテゴリ） | shape / linetype |
| 第 4（連続） | alpha または color |
| 第 5（カテゴリ） | facet |

```r
ggplot(iris, aes(x = Sepal.Length, y = Sepal.Width,
                 color = Petal.Length,   # 連続 → 色グラデーション
                 size  = Petal.Width,    # 連続 → サイズ
                 shape = Species)) +     # カテゴリ → 形状
  geom_point(alpha = 0.7) +
  scale_color_viridis_c() + scale_size_continuous(range = c(1, 6)) + theme_bw()
```

過剰なマッピングは可読性を落とす。3〜4 次元を超えるなら facet 分割や複数図への分解を検討する。

---

## レビュー観点・落とし穴チェックリスト

**base graphics**

| 状況 | 問題 | 対処 |
|---|---|---|
| 複数の密度曲線を重ねる | 後から描く曲線が上限を超えて切れる | 背の高い曲線を先に描くか `ylim` を明示 |
| `dev.off()` 忘れ | PDF/PNG が壊れる・空になる | 関数内は `on.exit(dev.off())` で保護 |
| `par()` 変更が残存 | 次のプロットに引き継がれる | `old <- par(...)` → 作業 → `par(old)` |
| `legend()` の `cex`/`pt.cex` 混同 | `cex` は文字だけ拡大し点は変わらない | 点サイズは `pt.cex` |
| `type="b"` で点と線がずれる | `b` は隙間を空ける | 密着させたいなら `type="o"` |
| `pch=21〜25` に色が付かない | `col` は境界色 | 塗りは `bg` を指定 |

**ggplot2**

| 誤用 | 原因 | 正しい対応 |
|---|---|---|
| 連続変数に `scale_color_brewer` | 離散専用パレットを適用 | `scale_color_distiller` / `_viridis_c` |
| `aes()` 内に定数を直接記述 | マッピングと定数設定の混同 | `aes()` の外で引数として渡す |
| facet で比較しにくい | 比較対象を facet に割り当てた | 比較変数は x 軸か fill、補助変数を facet に |
| `group` 未指定で折れ線が崩れる | 各行を別系列と解釈 | `aes(group = ...)` で系列を明示 |
| `ggsave` の解像度が低い | 既定 dpi が小さい | ラスタは `dpi = 300`（印刷は 600）を明示 |
| `scale_*_continuous(limits=)` でデータが消える | 範囲外を除去後に stat が動く | ズームは `coord_cartesian(xlim=)` を使う |

**共通の指針**: 軸ラベル・単位・凡例・色の意味・facet のスケールを常に明示する。y 軸を切断・省略するときは誤解を生まない表示にする。連続とカテゴリで色スケールを取り違えない。探索は base graphics、成果物として洗練させるなら ggplot2、という役割分担を意識すると全体の生産性が上がる。
