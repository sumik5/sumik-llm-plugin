# R 統計リファレンス

記述統計・確率・分布・シミュレーション・推測統計（信頼区間／仮説検定／分散分析）・回帰と一般化線形モデルを、実行可能な R コードとともに体系的にまとめる。R の関数名・引数はすべて原語のまま扱う。

---

## 目次

1. [変数の種類と要約統計量](#1-変数の種類と要約統計量)
2. [比率・クロス集計・相関](#2-比率クロス集計相関)
3. [確率と離散確率変数](#3-確率と離散確率変数)
4. [確率分布：d/p/q/r の 4 系統](#4-確率分布dpqr-の-4-系統)
5. [離散分布](#5-離散分布)
6. [連続分布](#6-連続分布)
7. [乱数・sample・シミュレーション](#7-乱数sampleシミュレーション)
8. [標本分布と中心極限定理](#8-標本分布と中心極限定理)
9. [信頼区間](#9-信頼区間)
10. [仮説検定：平均・比率・カテゴリ](#10-仮説検定平均比率カテゴリ)
11. [検定力・多重比較](#11-検定力多重比較)
12. [分散分析（ANOVA）](#12-分散分析anova)
13. [回帰モデル](#13-回帰モデル)
14. [モデル選択と残差診断](#14-モデル選択と残差診断)
15. [一般化線形モデル（GLM）](#15-一般化線形モデルglm)
16. [レビュー観点・落とし穴](#16-レビュー観点落とし穴)

---

## 1. 変数の種類と要約統計量

分析方針は変数の型で決まる。連続（実数）・離散（整数）・名義（順序なしカテゴリ）・順序（順序ありカテゴリ）を最初に区別する。

```r
str(chickwts)         # 構造確認
class(chickwts$feed)  # データ型
levels(chickwts$feed) # factor のレベル
```

### 中心とばらつき

```r
xdata <- c(2, 4.4, 3, 3, 2, 2.2, 2, 4)

mean(xdata)    # 算術平均
median(xdata)  # 中央値（外れ値にロバスト）
var(xdata)     # 標本分散（分母 n-1）
sd(xdata)      # 標本標準偏差
IQR(xdata)     # 四分位範囲（ロバスト）

# モード（最頻値）は table + max で
xtab <- table(xdata)
xtab[xtab == max(xtab)]
```

`var()` / `sd()` は標本推定量（分母 n-1）を返す。母分散（分母 n）が必要なら `var(x) * (n - 1) / n` で変換する。

### NA の扱い

集約関数はデフォルトで欠損があると `NA` を返す。これは安全側の挙動であり、除外は意図的に行う。

```r
mean(c(1, 4, NA))              # NA
mean(c(1, 4, NA), na.rm = TRUE) # 2.5
```

`sum`, `prod`, `median`, `max`, `min`, `range`, `sd`, `var` も同じく `na.rm` を持つ。

### quantile と summary、グループ別集計

```r
quantile(xdata, prob = c(0, 0.25, 0.5, 0.75, 1)) # 五数要約
summary(xdata)                                    # 五数 + 平均
summary(quakes$mag[quakes$depth < 400])           # フィルタ後

# グループ別集計は tapply
tapply(chickwts$weight, INDEX = chickwts$feed, FUN = mean)
tapply(chickwts$weight, INDEX = chickwts$feed,
       FUN = function(x) quantile(x, 0.9))
```

### 数値ユーティリティと早期丸めの罠

```r
round(3.14159, digits = 3)  # 3.142
floor(9.83); ceiling(9.83)  # 9 / 10
abs(-4.48)                  # 4.48
```

中間計算で丸めると誤差が蓄積する。丸めは常に最終結果にだけ適用する。

```r
4.5743 * sqrt(0.9732 * 0.0268)                            # 0.7387（正確）
round(4.5743, 2) * sqrt(round(0.9732, 2) * round(0.0268, 2)) # 0.7796（誤差）
```

---

## 2. 比率・クロス集計・相関

```r
table(chickwts$feed)                       # 頻度
prop.table(table(chickwts$feed))           # 比率
mean(chickwts$feed == "soybean")           # 論理ベクトルの mean で比率
mean(chickwts$feed == "soybean") * 100     # パーセント

# 2 次元クロス集計と条件付き比率
tab <- table(mtcars$am, mtcars$cyl)
prop.table(tab, margin = 1)  # 行方向（各行が合計 1）
prop.table(tab, margin = 2)  # 列方向
```

`cumsum()` で累積分布を組み立てられる。

```r
X.outcomes <- c(-4, 0, 1, 8)
X.prob     <- c(0.32, 0.48, 0.15, 0.05)
cumsum(X.prob)  # 0.32 0.80 0.95 1.00
```

### 相関と共分散

```r
cor(quakes$mag, quakes$stations)                    # Pearson: 0.851
cor(xdata, ydata, method = "spearman")              # 順位相関
cor(xdata, ydata, method = "kendall")               # Kendall の τ
cov(xdata, ydata) / (sd(xdata) * sd(ydata))         # cor の手計算と一致
```

相関は**線形**関係のみを捉える。ρ ≈ 0 でも非線形パターンは存在しうる。また相関は因果を意味しない。`mean` は外れ値に敏感、`median` / `IQR` はロバストである。

---

## 3. 確率と離散確率変数

確率の基本規則を R の算術でそのまま表現できる。

```r
(2/3) * (1/2)          # 積事象 Pr(A ∩ B) = Pr(A|B) Pr(B)
(1/2) + (1/2) - (1/3)  # 和事象 Pr(A ∪ B) = Pr(A)+Pr(B)-Pr(A ∩ B)
1 - 1/2                # 余事象 Pr(Ā) = 1 - Pr(A)
```

離散確率変数の期待値・分散は結果と確率のベクトル演算で計算する。

```r
X.outcomes <- c(-4, 0, 1, 8)
X.prob     <- c(0.32, 0.48, 0.15, 0.05)

mu.X  <- sum(X.outcomes * X.prob)              # 期待値
var.X <- sum((X.outcomes - mu.X)^2 * X.prob)   # 分散
sd.X  <- sqrt(var.X)
```

---

## 4. 確率分布：d/p/q/r の 4 系統

任意の分布 `xxx` に対し 4 つの関数がある。この命名規則が分布関数群の中核。

| 接頭辞 | 意味 | 返すもの |
|---|---|---|
| `d` | density / mass | 密度 f(x) または確率質量 Pr(X=x) |
| `p` | probability | 累積確率 Pr(X ≤ x)（左側、デフォルト） |
| `q` | quantile | 指定した累積確率に対応する x |
| `r` | random | 分布からの乱数 |

```r
dnorm(0)      # 密度 f(0) = 0.3989
pnorm(1.96)   # Pr(Z ≤ 1.96) = 0.9750
qnorm(0.975)  # 1.96
rnorm(5)      # 標準正規から 5 個
```

`p*` は既定で**左側**累積。上側確率は `1 - p*(...)` か `lower.tail = FALSE`。

```r
pnorm(1.96, lower.tail = FALSE)  # Pr(X > 1.96) = 0.025
```

---

## 5. 離散分布

### 二項分布 `binom`

n 回の独立試行で成功が x 回起きる確率。

```r
dbinom(x = 5, size = 8, prob = 1/6)          # Pr(X = 5)
sum(dbinom(0:8, 8, 1/6))                      # 質量の総和 = 1
pbinom(q = 3, size = 8, prob = 1/6)           # Pr(X ≤ 3)
1 - pbinom(q = 2, size = 8, prob = 1/6)       # Pr(X ≥ 3)
qbinom(p = 0.95, size = 8, prob = 1/6)        # Pr(X ≤ ?) ≥ 0.95 の最小整数
rbinom(n = 3, size = 8, prob = 1/6)           # 乱数を 3 個

# 期待値 = n p、分散 = n p (1-p)
n <- 8; p <- 1/6
n * p; n * p * (1 - p)

barplot(dbinom(0:8, 8, 1/6), names.arg = 0:8, space = 0,
        xlab = "x", ylab = "Pr(X=x)")
```

### ポアソン分布 `pois`

一定レートで独立に起きる事象の回数。平均 = 分散 = λ。

```r
dpois(x = 3, lambda = 3.22)      # Pr(X = 3)
ppois(q = 2, lambda = 3.22)      # Pr(X ≤ 2)
1 - ppois(q = 5, lambda = 3.22)  # Pr(X > 5)
rpois(n = 15, lambda = 3.22)
```

---

## 6. 連続分布

連続分布では `d*` は**密度**であり確率ではない。確率は `p*`（区間の面積）で得る。

### 一様分布 `unif`

```r
a <- -0.4; b <- 1.1
dunif(0.5, min = a, max = b)                        # 区間内は 1/(b-a)、区間外は 0
punif(0.6, a, b) - punif(-0.21, a, b)               # 区間確率
qunif(0.127, a, b); runif(10, a, b)
(a + b) / 2; (b - a)^2 / 12                          # 期待値・分散
```

### 正規分布 `norm`

最重要。対称・釣鐘型で平均 = 中央値 = 最頻値。

```r
pnorm(1) - pnorm(-1)  # ±1σ ≈ 0.6827
pnorm(2) - pnorm(-2)  # ±2σ ≈ 0.9545
pnorm(3) - pnorm(-3)  # ±3σ ≈ 0.9973

mu <- 80.2; sigma <- 1.1
pnorm(78, mu, sigma)                     # Pr(X < 78)
qnorm(0.2, mu, sigma)                    # 下位 20% の境界

# 標準化 Z = (X - μ) / σ  →  N(0,1)
z <- (82.5 - mu) / sigma
pnorm(z)                                  # pnorm(82.5, mu, sigma) と一致

# 正規性の目視確認
qqnorm(chickwts$weight); qqline(chickwts$weight, col = "gray")
```

### t 分布 `t`

母標準偏差が未知のとき。自由度 ν が大きくなると N(0,1) に収束（裾が厚い）。

```r
1 - pt(1.87, df = 1)    # 0.156
1 - pt(1.87, df = 20)   # 0.038
1 - pnorm(1.87)         # 0.031（参照）
qt(p = 0.975, df = 29)  # n=30 の 95% 区間の臨界値
```

### 指数分布 `exp`

非負連続。ポアソン過程における「事象間の待機時間」。

```r
lambda.e <- 107 / 120
1 - pexp(2.5, rate = lambda.e)  # Pr(X > 2.5)
qexp(0.15, rate = lambda.e)
1 / lambda.e; 1 / lambda.e^2    # 期待値・分散
```

### カイ二乗分布 `chisq` と F 分布 `f`

χ² は ν 個の独立標準正規の二乗和で、分散・独立性検定に使う（期待値 ν、分散 2ν）。F 分布は 2 つのカイ二乗の比で、ANOVA・回帰評価に使う。

```r
qchisq(0.95, df = 1)          # 3.841（χ² 検定の代表的臨界値）
1 - pchisq(24, df = 18)       # Pr(X > 24)
qf(0.9, df1 = 100, df2 = 27)  # 1.539
```

その他の分布も同じ 4 系統を持つ: ガンマ `gamma`（`shape`,`scale`）、ベータ `beta`（`shape1`,`shape2`）、ワイブル `weibull`、負の二項 `nbinom`、幾何 `geom`、超幾何 `hyper`、多項 `multinom`。

---

## 7. 乱数・sample・シミュレーション

### 再現性：set.seed

`rnorm` / `runif` / `sample` は呼ぶたびに変わる。再現性が要るならスクリプト先頭で 1 回だけシードを固定する。

```r
set.seed(42); rnorm(3)
set.seed(42); rnorm(3)  # 同一結果
```

ループ内で毎回 `set.seed()` を呼ぶと擬似乱数の独立性が崩れる。避けること。

### sample：有限集合からの抽出

```r
sample(1:6, size = 10, replace = TRUE)                 # 復元抽出
sample(1:10, size = 5)                                  # 非復元（既定）
sample(c("A", "B", "C"), 20, replace = TRUE,
       prob = c(0.5, 0.3, 0.2))                          # 重み付き
sample(1:10)                                             # シャッフル
idx <- sample(nrow(chickwts), 30); chickwts[idx, ]       # 行のランダム抽出
```

### 反復：replicate と purrr

```r
# 標本平均を 1000 回（中心極限定理の確認）
set.seed(1)
sample_means <- replicate(1000, mean(rnorm(30)))
mean(sample_means); sd(sample_means)  # ≈ 0 / ≈ 1/sqrt(30)

library(purrr)
map_dbl(1:5, ~ mean(rnorm(100)))       # 数値ベクトルで返す
sim <- map_dfr(c(10, 100, 1000), function(n) {
  m <- replicate(500, mean(rnorm(n)))
  data.frame(n = n, sim_mean = mean(m), sim_sd = sd(m))
})
```

大規模なら並列化。furrr では `.options = furrr_options(seed = TRUE)` で並列 RNG を固定する。

```r
library(future); library(furrr)
plan(multisession, workers = 4)
set.seed(99)
res <- future_map_dbl(1:10000, ~ mean(rnorm(30)),
                      .options = furrr_options(seed = TRUE))
```

使い分け: 数千未満は `replicate()`、それ以上は事前確保 + `purrr`、CPU 律速なら `future`/`furrr`。

### モンテカルロと bootstrap

```r
# π の推定
set.seed(123); n <- 1e6
x <- runif(n, -1, 1); y <- runif(n, -1, 1)
4 * mean(x^2 + y^2 <= 1)  # ≈ 3.14159（誤差は 1/sqrt(n) で縮む）

# ランダムウォーク
set.seed(7)
path <- cumsum(sample(c(-1, 1), 200, replace = TRUE))

# bootstrap 95% 信頼区間
set.seed(55)
obs <- chickwts$weight[chickwts$feed == "casein"]
boot <- replicate(2000, mean(sample(obs, replace = TRUE)))
quantile(boot, probs = c(0.025, 0.975))
```

---

## 8. 標本分布と中心極限定理

標本統計量は確率変数であり、その分布が**標本分布**。その標準偏差を**標準誤差（SE）**と呼ぶ。各観測は独立同一分布（iid）と仮定する。

- 標本平均: SE = σ / √n。**中心極限定理（CLT）**により、原データが非正規でも n が大きい（目安 n ≥ 30）と標本平均は正規に近づく。
- σ が未知で s に置換すると不確実性が増し、標準化統計量は自由度 ν = n − 1 の t 分布に従う。
- 標本比率 p̂: p̂ ～ N(π, √(π(1−π)/n)) の近似。有効条件の目安は n·p̂ > 5 かつ n·(1−p̂) > 5。

```r
# n=5、σ 未知の標本平均を t 分布で評価
obs <- rnorm(5, mean = 22, sd = 1.5)
se  <- sd(obs) / sqrt(5)
pt((21.5 - mean(obs)) / se, df = 4)  # Pr(X̄ < 21.5) の近似

# 標本比率の有効性チェック
p.hat <- 80 / 118
118 * p.hat; 118 * (1 - p.hat)       # ともに > 5 なら正規近似 OK
```

---

## 9. 信頼区間

対称な標本分布では一般式は「統計量 ± 臨界値 × SE」。信頼水準が上がるほど臨界値が増え区間は広がる。

```r
# 平均の CI（正規性仮定、σ 未知 → t 分布、df = n-1）
x <- rnorm(n = 5, mean = 22, sd = 1.5)
m  <- mean(x); se <- sd(x) / sqrt(5)
m + c(-1, 1) * qt(0.975, df = 4) * se   # 95% CI
m + c(-1, 1) * qt(0.995, df = 4) * se   # 99% CI（より広い）

# 比率の CI（正規近似、SE に p.hat を使う）
p.hat <- 80 / 118
p.se  <- sqrt(p.hat * (1 - p.hat) / 118)
p.hat + c(-1, 1) * qnorm(0.95) * p.se   # 90% CI
```

**解釈の要点**: 「真値がこの区間に入る確率 95%」は厳密には誤り。正しくは「同条件で CI を作り続ければ、そのうち 95% が真値を含む」。シミュレーションで被覆率を確認できる。

```r
set.seed(1); n <- 300; true.mu <- 1 / 0.1
hit <- replicate(5000, {
  s <- rexp(n, rate = 0.1); m <- mean(s); se <- sd(s) / sqrt(n)
  cv <- qt(0.975, df = n - 1)
  (m - cv * se) <= true.mu && true.mu <= (m + cv * se)
})
mean(hit)  # ≈ 0.95
```

---

## 10. 仮説検定：平均・比率・カテゴリ

### 検定の枠組み

H₀（等号のベースライン）と Hₐ（不等号の主張）を立て、検定統計量から p 値（H₀ が真のときに観測以上に極端な値が出る確率）を求める。p 値 < α なら H₀ を棄却。`alternative` は `"less"`（左側）/ `"greater"`（右側）/ `"two.sided"`（両側）。p 値は「証拠の強さ」であって H₀ の真偽の証明ではない。

### 平均：t.test

```r
# 1 標本：mu = 80 か、それより小さいか
t.test(x = snacks, mu = 80, alternative = "less")
t.test(x = snacks, mu = 80, alternative = "two.sided")$conf.int  # 両側 CI

# 2 標本（独立・等分散なし = Welch、既定）: x に「大きい方」を渡す
t.test(x = snacks2, y = snacks, alternative = "greater")

# 2 標本（等分散を仮定 = pooled）
t.test(x = men, y = women, var.equal = TRUE)   # SD 比 < 2 なら等分散可

# 対応あり（before/after が対）: paired を忘れると独立検定になる
t.test(x = rate.after, y = rate.before, alternative = "less", paired = TRUE)
```

主な引数: `mu`（H₀ の平均）, `alternative`, `conf.level`, `var.equal`, `paired`。

### 比率：prop.test / binom.test

Z 検定は n·p̂ > 5 かつ n·(1−p̂) > 5 が条件。H₀ の π₀ を SE 計算に使う（CI と異なる点）。

```r
# 1 標本比率。correct=FALSE で Yates 補正を切り Z 検定と一致させる
prop.test(x = sum(sick), n = length(sick), p = 0.2, correct = FALSE)
binom.test(x = 8, n = 29, p = 0.2)  # 小標本や π が 0/1 に近いとき正確検定

# 2 標本比率。「大きい方」を先に渡す。プール比率を SE に使う
prop.test(x = c(x2, x1), n = c(n2, n1),
          alternative = "greater", correct = FALSE)
```

### カテゴリ：chisq.test

χ² 適合度検定（1 変数の頻度が仮説分布に合うか）と独立性検定（2 変数に関係があるか）。常に上側 p 値。期待度数 ≥ 5 が全セルの 80% 以上が有効条件。

```r
chisq.test(x = table(hairy))                       # 均等分布との適合度
chisq.test(x = table(hairy), p = c(0.25, 0.5, 0.25)) # 非均等 H₀
chisq.test(x = skin)                                # 行列を渡すと独立性検定
chisq.test(skin)$expected                           # 期待度数の確認
```

### ノンパラメトリック代替：wilcox.test

正規性が怪しいとき（特に n < 30）に中央値ベースで検定する。

```r
wilcox.test(x = snacks2, y = snacks, alternative = "greater")   # Mann-Whitney U
wilcox.test(rate.after, rate.before, paired = TRUE, alternative = "less")
shapiro.test(snacks)  # Shapiro-Wilk 正規性検定（p > 0.05 なら正規と矛盾せず）
```

---

## 11. 検定力・多重比較

### 2 種のエラーと検定力

| | H₀ が真 | Hₐ が真 |
|---|---|---|
| H₀ を棄却 | タイプ I（確率 α） | 正解（検定力 1−β） |
| H₀ を保持 | 正解 | タイプ II（確率 β） |

検定力 = 1 − β で、慣例として 0.8 以上を「強力」とみなす。α を下げると β は増え検定力は下がる。n を増やす・σ が小さい・効果量（μₐ−μ₀）が大きいほど検定力は上がる。シミュレーションで確認できる。

```r
typeII.tester <- function(mu0, muA, sigma, n, alpha, ITER = 10000) {
  p <- replicate(ITER, {
    s <- rnorm(n, mean = muA, sd = sigma)
    1 - pt((mean(s) - mu0) / (sd(s) / sqrt(n)), df = n - 1)
  })
  mean(p >= alpha)  # β
}
typeII.tester(mu0 = 0, muA = 0.5, sigma = 1, n = 30, alpha = 0.05)  # ≈ 0.14
1 - typeII.tester(mu0 = 0, muA = 0.5, sigma = 1, n = 30, alpha = 0.05) # power
```

### 多重比較補正

N 個の検定を α で行うと偽陽性が蓄積する。Bonferroni は各検定を α/N に下げる（保守的）。`p.adjust()` で複数の方法を選べる。

```r
p_values <- c(0.01, 0.04, 0.003, 0.10, 0.02)
p.adjust(p_values, method = "bonferroni")
p.adjust(p_values, method = "BH")  # Benjamini-Hochberg（FDR 制御・大規模向き）
```

---

## 12. 分散分析（ANOVA）

前提は独立性・各群の正規性・等分散性（最大 SD / 最小 SD < 2 が目安）。

### 一元配置

```r
# 前提チェック
chick.sds <- tapply(chickwts$weight, chickwts$feed, sd)
max(chick.sds) / min(chick.sds)   # < 2 なら等分散 OK

chick.means <- tapply(chickwts$weight, chickwts$feed, mean)
resid_cen <- chickwts$weight - chick.means[as.numeric(chickwts$feed)]
qqnorm(resid_cen); qqline(resid_cen)  # 残差の正規性

# ANOVA テーブル：F = 群間変動(MSG) / 群内変動(MSE)、p は F 分布の上側
chick.anova <- aov(weight ~ feed, data = chickwts)
summary(chick.anova)
```

H₀ を棄却しても「どの群が違うか」は分からない。多重比較へ進む。

### 多重比較（ANOVA の後）

```r
TukeyHSD(chick.anova)        # FWER 制御。CI がゼロをまたがないペアが有意
plot(TukeyHSD(chick.anova), las = 1)

pairwise.t.test(chickwts$weight, chickwts$feed, p.adjust.method = "bonferroni")
pairwise.t.test(chickwts$weight, chickwts$feed, p.adjust.method = "BH")
```

### 二元配置と交互作用

一変数ずつ別々に ANOVA するのは不十分。主効果と交互作用を同時に検定する。

```r
summary(aov(breaks ~ wool + tension, data = warpbreaks))         # 主効果のみ
summary(aov(breaks ~ wool * tension, data = warpbreaks))         # 主効果 + 交互作用
# wool * tension は wool + tension + wool:tension の短縮記法

# 交互作用プロット（線が非平行なら交互作用の可能性）
wb <- aggregate(warpbreaks$breaks,
                by = list(warpbreaks$wool, warpbreaks$tension), FUN = mean)
interaction.plot(x.factor = wb[, 2], trace.factor = wb[, 1],
                 response = wb$x, xlab = "tension", ylab = "mean breaks",
                 trace.label = "wool")
```

### ノンパラメトリック代替：Kruskal-Wallis

正規性が満たせない一元配置の代替（中央値ベース）。

```r
library(MASS)
kruskal.test(Age ~ Smoke, data = survey)
# 後続の多重比較は dunn.test::dunn.test(survey$Age, survey$Smoke, method="bonferroni")
```

---

## 13. 回帰モデル

### 単回帰と lm

ŷ = β̂₀ + β̂₁x。切片は x=0 での期待応答、傾きは x を 1 増やしたときの平均変化。誤差 ε は N(0, σ²)・独立・等分散を仮定する。

```r
library(MASS)
survfit <- lm(Height ~ Wr.Hnd, data = survey)  # data= で $ 不要
abline(survfit, lwd = 2)                         # 散布図に回帰直線

coef(survfit)      # 係数
fitted(survfit)    # 適合値 ŷ
resid(survfit)     # 残差 y - ŷ
confint(survfit)   # 係数の信頼区間
```

単回帰では R² = ρ²（相関係数の二乗）。

### formula 記法

| 記法 | 意味 |
|---|---|
| `y ~ x` | 切片 + x |
| `y ~ x1 + x2` | 主効果のみ |
| `y ~ x1 * x2` | 主効果 + 交互作用（`x1 + x2 + x1:x2`） |
| `y ~ x + I(x^2)` | 多項式（`I()` で算術式を保護） |
| `y ~ log(x)` | 対数変換 |
| `y ~ factor(x)` | 数値をカテゴリ扱い |
| `y ~ 1` | 切片のみ |

`I()` を忘れて `x^2` と書くと無視される（formula の演算子として解釈される）ので注意。

### summary の読み方

```r
summary(survfit)
```

`Estimate`（点推定 β̂）・`Std. Error`・`t value`（= Estimate/SE）・`Pr(>|t|)`（H₀: β=0 の両側 p 値）。全体では `Multiple R-squared`（説明できた変動の割合）・`Adjusted R-squared`（変数数でペナルティ）・`F-statistic`（全傾き = 0 の検定）。プログラムからは要素で取り出す。

```r
s <- summary(survfit)
s$r.squared; s$adj.r.squared; s$sigma
s$coefficients["Wr.Hnd", "Pr(>|t|)"]
```

### 予測：信頼区間 vs 予測区間

CI は「平均応答」の不確実性、PI は「個々の観測値」の不確実性で、PI は常に広い。`newdata` の列名は学習時と一致させる。

```r
xvals <- data.frame(Wr.Hnd = c(14.5, 24))
predict(survfit, newdata = xvals, interval = "confidence", level = 0.95) # CI（狭い）
predict(survfit, newdata = xvals, interval = "prediction", level = 0.95) # PI（広い）
```

観測範囲内の**内挿**は信頼できるが、範囲外の**外挿**は不確実。多項式では特に急激に外れる。

### カテゴリ変数と重回帰

factor を渡すと自動でダミーコーディングされ、最初の水準が基準になる。k 水準からは k−1 個の係数が出る。多水準変数はいずれか 1 係数でも有意なら変数全体を残す。

```r
lm(Height ~ Sex, data = survey)                     # SexMale = Male - Female の差
relevel(survey$Smoke, ref = "Never")                # 基準水準の変更
lm(mpg ~ factor(cyl), data = mtcars)                # 数値を明示的にカテゴリ化

# 重回帰の係数は「他変数を固定した」偏効果
survmult <- lm(Height ~ Wr.Hnd + Sex, data = survey)
# 単回帰で 3.12 だった Wr.Hnd が 1.59 に減る → 交絡があった証拠
predict(survmult, newdata = data.frame(Wr.Hnd = 16.5, Sex = "Male"),
        interval = "confidence")
```

### 変数変換と交互作用

```r
lm(mpg ~ disp + I(disp^2), data = mtcars)   # 多項式（poly(disp, 2) でも可）
lm(mpg ~ log(hp) + am, data = mtcars)        # 対数（外挿でも多項式より安定）
lm(mpg ~ hp * wt, data = mtcars)             # 連続 × 連続の交互作用
```

多項式は高次項が有意なら低次項を必ず残す。交互作用があるなら主効果も残す（下位効果の交絡を避けるため）。曲線は直線しか描けない `abline` ではなく `predict` + `lines` で描く。

---

## 14. モデル選択と残差診断

### ネストモデルの比較と段階的選択

```r
anova(survmult, survmult2)  # 偏 F 検定。p が大きければ追加項は不要

# 前進選択 / 後退消去（F 検定ベース）
add1(nuc_0, scope = .~. + date + t1 + cap + ne, test = "F")
nuc_1 <- update(nuc_0, . ~ . + date)
drop1(nuc_full, test = "F")

# AIC ステップワイズ（小さいほど良い）。BIC は k = log(n)
car_null <- lm(mpg ~ 1, data = mtcars)
step(car_null, scope = . ~ . + wt * hp + am + drat + qsec)
step(car_null, scope = ..., k = log(nrow(mtcars)))  # BIC
AIC(model); BIC(model)
```

ネストモデルを比較するときは、全モデルで**同じレコード**を使う（NA 除外で行数が変わると比較が壊れる）。

```r
diab <- na.omit(diabetes[, c("chol", "age", "frame")])
```

### 残差診断：plot(model)

`plot(fit, which = 1:6)` で 6 種の診断図が出る。

- `which = 1`（残差 vs 適合値）: ランダムに 0 付近が理想。曲線は非線形性、ファン状は不均一分散。
- `which = 2`（正規 QQ）: 対角線に乗れば残差正規。裾のずれは重尾。`shapiro.test(rstandard(fit))` で機械的確認。
- `which = 3`（スケール・ロケーション）: 水平に散らばれば等分散。
- `which = 4`（Cook's distance）: `D_i > 4/n` が要注意の目安。
- `which = 5, 6`: 標準化残差 vs leverage。高 leverage + 大残差 = 高影響点。

```r
hatvalues(fit)       # leverage（平均は (p+1)/n）
cooks.distance(fit)  # Cook's distance
rstandard(fit)       # 標準化残差
rstudent(fit)        # スチューデント化残差（外れ値検出）
```

### 多重共線性と VIF

症状: 個別 t 検定は全て非有意なのに全体 F は有意、係数の符号が直感に反する、説明変数間の相関が 0.8 以上。

```r
cor(survey$Wr.Hnd, survey$NW.Hnd, use = "complete.obs")  # 0.948
library(car)
vif(lm(Height ~ Wr.Hnd + NW.Hnd, data = survey))  # VIF > 5〜10 で問題
```

対処: 相関の高い変数の一方を除去、変数を合成、PCA、Ridge 回帰。

### データリーク回避

```r
# 訓練・テスト分割
set.seed(42); n <- nrow(mtcars)
train_idx <- sample(seq_len(n), size = floor(0.8 * n))
fit <- lm(mpg ~ wt + hp, data = mtcars[train_idx, ])
pred <- predict(fit, newdata = mtcars[-train_idx, ])
sqrt(mean((mtcars$mpg[-train_idx] - pred)^2))  # テスト RMSE
```

`step` / `add1` / `drop1` で選択したモデルの p 値は選択バイアスを含む。予測性能は選択に使ったデータではなくホールドアウトまたは交差検証で評価する。

---

## 15. 一般化線形モデル（GLM）

`lm` は応答が正規分布の場合に相当。`glm` はより広い分布族に対応する。

| 応答 | family | link（既定） |
|---|---|---|
| 連続・正規 | `gaussian` | `identity` |
| 二値（0/1）・比率 | `binomial` | `logit` |
| カウント（非負整数） | `poisson` | `log` |
| 正の連続 | `Gamma` | `inverse` |

### ロジスティック回帰（二値応答）

```r
logit_fit <- glm(am ~ wt + hp, family = binomial(link = "logit"), data = mtcars)
summary(logit_fit)
exp(coef(logit_fit))                       # オッズ比
predict(logit_fit, type = "response")      # 予測確率（type="link" はロジット）
AIC(logit_fit)
```

### ポアソン回帰（カウント）

```r
pois_fit <- glm(breaks ~ wool + tension, family = poisson(link = "log"),
                data = warpbreaks)
exp(coef(pois_fit))  # 相対的なカウント変化率

# 過分散チェック（1 に近ければ OK、大きければ quasi-Poisson / 負の二項へ）
summary(pois_fit)$deviance / summary(pois_fit)$df.residual
```

### GLM の診断

```r
residuals(glm_fit, type = "deviance")  # 逸脱残差（推奨）
residuals(glm_fit, type = "pearson")
cooks.distance(glm_fit)
plot(logit_fit)  # lm と同様に使える
```

---

## 16. レビュー観点・落とし穴

| 状況 | 落とし穴 | 対処 |
|---|---|---|
| 上側確率 | `p*` は左側累積。`pnorm(1.96)` は 0.975 | `1 - p*(...)` か `lower.tail = FALSE` |
| 分位点 | `q*` は左側確率を入力。上側 5% は | `qnorm(1 - 0.05)` = 1.645 |
| 連続分布の `d*` | 密度であって確率ではない | 確率は `p*` の区間差で |
| `rbinom(n, size, prob)` | `n` は乱数の個数、`size` が試行回数 | 引数の役割を取り違えない |
| 2 標本 t.test | `x`/`y` の順と `alternative` が不整合だと逆検定 | `x` を「大きい方」にし `"greater"` |
| 対応あり検定 | `paired = TRUE` を忘れると独立検定 | before/after ペアか確認 |
| prop.test | 既定 `correct = TRUE` は Yates 補正で Z と結果が違う | 一致させるなら `correct = FALSE` |
| chisq.test | 期待度数が小さいと無効 | `$expected` を確認、違反なら Fisher の正確検定 |
| ANOVA 後 | 全ペア検定で偽陽性が増える | `TukeyHSD` / `pairwise.t.test(p.adjust.method=)` |
| 片側 t.test の CI | 片側境界になる | 両側 CI は `alternative = "two.sided"` |
| CLT の適用 | n < 30 では成立しにくい | 正規性を確認 or Wilcoxon |
| ネストモデル比較 | NA 除外で行数が変わると壊れる | 事前に `na.omit` で行を揃える |
| 早期丸め | 中間で丸めると誤差が蓄積 | 生値を保持し最後に `round` |
| set.seed | ループ内で毎回リセットすると独立性が崩れる | スクリプト先頭で 1 回 |
| モデル選択後の p 値 | 選択バイアスを含む | 性能はホールドアウト/交差検証で |

### 関数クイックリファレンス

| 関数 | 用途 |
|---|---|
| `mean`/`median`/`sd`/`var`/`IQR`/`quantile`/`summary` | 要約統計量 |
| `tapply`/`aggregate` | グループ別集計 |
| `table`/`prop.table`/`cor`/`cov` | 頻度・比率・相関 |
| `d*`/`p*`/`q*`/`r*` | 分布の密度・累積・分位点・乱数 |
| `set.seed`/`sample`/`replicate` | 乱数・反復 |
| `t.test`/`wilcox.test` | 平均・中央値の検定 |
| `prop.test`/`binom.test` | 比率の検定 |
| `chisq.test`/`shapiro.test` | カテゴリ・正規性 |
| `aov`/`TukeyHSD`/`pairwise.t.test`/`kruskal.test` | 分散分析・多重比較 |
| `interaction.plot` | 交互作用の可視化 |
| `p.adjust` | 多重比較補正 |
| `lm`/`glm` | 線形・一般化線形モデル |
| `summary`/`coef`/`confint`/`predict`/`fitted`/`residuals` | モデルの要約・推定・予測 |
| `anova`/`add1`/`drop1`/`update`/`step`/`AIC`/`BIC` | モデル選択 |
| `plot`/`rstandard`/`rstudent`/`hatvalues`/`cooks.distance`/`vif` | 残差診断 |
