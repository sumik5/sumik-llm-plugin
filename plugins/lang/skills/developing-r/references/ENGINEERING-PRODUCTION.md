# R エンジニアリングと運用

分析用の R コードを再現可能で、テスト済みで、性能面でも実務に耐える形に仕上げるためのリファレンス。プロジェクト構成・依存管理・テスト・パッケージ化・アプリ/レポート配布から、計測に基づく性能改善・並列化・他言語連携・セキュリティまでを扱う。

---

## プロジェクト構成

代表的な構成:

```text
.
├── R/
├── tests/testthat/
├── data-raw/
├── data/
├── inst/
├── man/
├── vignettes/
├── reports/
├── renv.lock
├── DESCRIPTION
└── README.md
```

- パッケージでは reusable code を `R/`、テストを `tests/testthat/`、生成元データ処理を `data-raw/` に置く。分析プロジェクトでは raw data、intermediate data、outputs、reports を分ける。
- `.Rprofile` は全員の実行に影響するため最小限にする。自動で package attach や `setwd()` をしない。
- `.gitignore` には `.Rhistory`、`.RData`、secret、巨大な生成物、個人ローカル設定を含める。
- パスは `here::here("data", "raw", "sales.csv")` で project root 起点に解決し、`setwd()` や実行者のカレントディレクトリへの依存を避ける。

---

## renv

- `renv.lock` があるプロジェクトでは `renv::restore()` を前提にする。
- 依存追加やバージョン変更後は `renv::snapshot()` を検討する。
- `renv::status()` で lockfile と library の差分を確認する。
- システムライブラリが必要な package は README やセットアップ手順に明記する。

```r
renv::init()        # プロジェクト固有ライブラリを作成し .Rprofile を書き込む
renv::snapshot()    # 現在の状態を renv.lock に固定（依存追加・更新後）
renv::restore()     # lockfile どおりに library を復元（CI/新規環境で）
renv::status()      # lockfile と実 library の差分を確認
```

- `renv.lock` は必ず commit する。R バージョン・repository・各 package のバージョンと source が記録される。CI では `renv::restore()` をキャッシュ付きで実行し、環境差による "手元では動く" を排除する。

---

## testthat

- テストは Arrange、Act、Assert を分ける。
- 小さな純粋関数からテストする。ファイル、DB、API、時刻、乱数は fixture や mock で制御する。
- `testthat::expect_equal()` は数値誤差を考慮する。浮動小数点に完全一致を要求しない。
- 外部サービス依存は `skip_if_offline()`、環境変数チェック、mock を使う。
- snapshot test は表示が成果物である場合に使う。OS、locale、時刻、乱数で揺れる出力は安定化する。

```r
# tests/testthat/test-summarize.R
test_that("group_means は欠損を除外して平均を返す", {
  # Arrange
  df <- data.frame(g = c("a", "a", "b"), x = c(1, NA, 4))
  # Act
  result   <- group_means(df, "g", "x")
  expected <- data.frame(g = c("a", "b"), mean_x = c(1, 4))
  # Assert
  expect_equal(result, expected)
})

test_that("浮動小数点は tolerance 付き・不正入力はエラー", {
  expect_equal(sqrt(2)^2, 2, tolerance = 1e-8)   # 完全一致は要求しない
  expect_error(group_means(1:3, "g", "x"), "data.frame")
})
```

外部依存は隔離する。ネットワークは `skip_if_offline()`、環境変数は `skip_if(Sys.getenv("API_TOKEN") == "")`、内部関数呼び出しは `local_mocked_bindings()` で差し替える。

- `devtools::test()` または `testthat::test_local()` で一括実行する。カバレッジは `covr::package_coverage()` で確認する。
- ビジネスロジックは 100% カバレッジを目標に、境界値・異常系・空入力を必ずテストする。

---

## パッケージ開発

- `DESCRIPTION` に依存、ライセンス、R バージョン、URL、BugReports を明示する。
- exported function は roxygen2 で引数、返り値、例、エラー条件を説明する。
- `NAMESPACE` は手書きより roxygen2 生成を優先する。
- internal function は export しない。テストで必要な場合も public API を増やしすぎない。
- release 前は `R CMD check .` または `devtools::check()` を実行し、warning/error/note を確認する。

```r
#' 売上をグループ別に集計する
#'
#' @param df    集計対象の data.frame
#' @param by    グループ化キーの列名（character）
#' @param value 集計する数値列名（character）
#' @return グループごとの平均を持つ data.frame
#' @examples
#' group_means(data.frame(g = "a", x = 1), "g", "x")
#' @export
group_means <- function(df, by, value) {
  stopifnot(is.data.frame(df))
  # ...
}
```

- `usethis::use_r("summarize")` で `R/` にファイル、`usethis::use_test("summarize")` でテスト雛形を作る。
- `Imports` は関数を利用する依存、`Suggests` はテスト・vignette 専用の依存に分ける。`::` で明示的に呼び、`library()` を package コードに書かない。
- ドキュメントと `NAMESPACE` は `devtools::document()`（内部で roxygen2 実行）で再生成する。

---

## Shiny

- 小規模なら `app.R`、中規模以上は `ui.R`/`server.R`、module、`R/` に分ける。
- reactive graph を意識する。`reactive()` は値、`observeEvent()` は副作用、`eventReactive()` はイベント駆動の値に使う。
- 入力がそろう前は `req()`、ユーザー向けの検証は `validate()`/`need()` を使う。
- 重い処理は reactive の外で cache するか、非同期/事前計算/DB 側集計を検討する。
- ユーザー入力を SQL、ファイルパス、コード評価に直接渡さない。

```r
server <- function(input, output, session) {
  # eventReactive: ボタン押下時のみ再計算する値
  filtered <- eventReactive(input$go, {
    req(input$threshold)                 # 入力が揃うまで停止
    validate(need(input$threshold >= 0, "しきい値は 0 以上にしてください"))
    dplyr::filter(dataset, value > input$threshold)
  })

  # reactive: 依存が変わると自動再計算される派生値
  summary_stats <- reactive(list(n = nrow(filtered()), mean = mean(filtered()$value)))

  output$table <- renderTable(filtered())

  # observeEvent: 副作用（ログ・通知）専用。値を返さない
  observeEvent(input$go, message("フィルタ実行: ", summary_stats()$n, " 行"))
}
```

- module（`moduleServer()` / `NS()`）で UI・server をカプセル化し、名前空間衝突を防ぐ。
- 重い集計は `bindCache()` でキャッシュするか、起動時に事前計算した object を参照する。長時間処理は `promises` + `future` で非同期化し UI をブロックしない。

---

## Quarto / R Markdown

- `params` を使うと同じレポートを条件違いで再生成しやすい。
- chunk ごとに `message`、`warning`、`echo`、`cache`、`fig.width`、`fig.height` を意図に合わせる。
- 図表番号、相互参照、caption、alt text を成果物に合わせて整える。
- HTML/PDF/Word で表示差が出るため、最終形式で render して確認する。

```yaml
---
title: "月次レポート"
format: html
params:
  month: "2026-06"
  region: "all"
---
```

```r
# パラメータを差し替えたバッチ生成（コンソールから）
quarto::quarto_render("report.qmd",
  execute_params = list(month = "2026-05", region = "east"),
  output_file    = "report-2026-05-east.html")
```

- 計算結果と本文を混在させる chunk は `echo: false` と `message: false` で成果物をクリーンに保つ。再現性のため冒頭 chunk で `set.seed()` を呼び、乱数を含む図表を安定させる。

---

## 性能改善の進め方

推測ではなく計測から始める。典型的な改善ステップ: (1) `Rprof`/`profvis`/`bench` で計測 → (2) ボトルネックをベクトル化 → (3) 事前確保で再アロケーション排除 → (4) `compiler::cmpfun()` でバイトコンパイル → (5) `data.table`/`arrow` で I/O 改善 → (6) `future`/`parallel` で並列化 → (7) どうしても足りなければ `Rcpp`/`.C()` で C/C++。

| 手法 | 効果の目安 | 適用条件 |
|---|---|---|
| ベクトル化 | 10〜100 倍 | ループが `for()` で書かれている |
| 事前確保 | 2〜10 倍 | `rbind`/`cbind`/`c` で逐次拡張している |
| バイトコンパイル | 5〜10 倍 | ループが残る自作関数 |
| 並列化 | コア数倍（上限あり） | タスクが独立し 計算 >> 通信 |
| Rcpp | 100〜1000 倍 | 反復多・スカラー演算中心 |

---

## 計測ツール

### system.time() — 手軽な壁時計計測

```r
x <- runif(1e6); y <- runif(1e6)

system.time(z <- x + y)          # ベクトル化版: elapsed 約 0.07 秒
z <- vector(length = 1e6)
system.time(for (i in seq_along(x)) z[i] <- x[i] + y[i])  # ループ版は約120倍遅い
```

- `user` = R プロセスが CPU を使った時間、`system` = OS カーネル時間（I/O 等）、`elapsed` = 実経過時間（並列効果の確認に使う）。
- 変動を吸収したいときは反復して中央値を取る: `median(replicate(20, system.time(expr)[["elapsed"]]))`。

### Rprof() + summaryRprof() — 関数レベルのホットスポット検出

```r
Rprof("prof.out", interval = 0.005)   # サンプリング開始
invisible(slow_function(x))
Rprof(NULL)                           # 停止
summaryRprof("prof.out")$by.self      # self.time 降順で各関数の占有時間を表示
```

`self.time` が大きい関数が真のボトルネック。例えば `cbind` が全体の 86% を占めるなら、事前確保版への切り替え根拠になる。プロファイル結果は既定で `Rprof.out` に書かれ、後から `summaryRprof()` で参照できる。

### profvis — インタラクティブな炎上グラフ

```r
library(profvis)
profvis({
  x <- runif(1e6); z <- vector(length = 1e6)
  for (i in seq_along(x)) z[i] <- x[i]^2   # 遅い部分が炎上グラフで浮かび上がる
  w <- x^2
})
```

呼び出しツリーとメモリ使用量が時系列で可視化されるため、`Rprof()` より原因特定が速い。RStudio / Positron のビューアか htmlwidget で確認する。

### bench::mark() — 正確なマイクロベンチマーク

```r
library(bench)
x <- runif(1e5)
result <- bench::mark(
  loop       = { z <- vector(length = length(x)); for (i in seq_along(x)) z[i] <- x[i]^2; z },
  vectorized = x^2,
  iterations = 10
)
print(result)     # min / median / itr/sec / mem_alloc を比較。plot(result) で箱ひげ図
```

`bench::mark()` は GC を制御して反復計測するため `system.time()` より信頼できる。既定で全式の戻り値が等値かをチェックする（異なってよい場合のみ `check = FALSE`）。

---

## ベクトル化とループ回避

R の `for()` は関数呼び出しであり、`[` と `[<-` も関数呼び出し。100 万回のループは 100 万回のスタックフレーム確保を意味する。ベクトル化はループを C 実装の一括演算に置き換える。

```r
# NG: ループで奇数を数える
oddcount_loop <- function(x) { c <- 0; for (i in seq_along(x)) if (x[i] %% 2 == 1) c <- c + 1; c }
# OK: ベクトル化（約20倍速）
oddcount <- function(x) sum(x %% 2 == 1)
```

有用なベクトル化関数:

| 用途 | 関数 |
|---|---|
| 条件付き選択 | `ifelse()`, `which()` |
| 論理集約 | `any()`, `all()` |
| 累積演算 | `cumsum()`, `cumprod()`, `cummax()`, `cummin()` |
| 行列集約 | `rowSums()`, `colSums()`, `rowMeans()`, `colMeans()` |
| 全組み合わせ | `outer()`, `expand.grid()`, `combn()` |
| 要素ごと最大/最小 | `pmax()`, `pmin()` |

### apply() や outer() は必ずしも速くない

`apply()` は R で実装されており、C 実装の `lapply()` より遅いことがある。`outer(x, 1:dg, "^")` のような一見エレガントな式も、内部で `length(x) × dg` 回のスカラー乗算を呼ぶためベクトル化の恩恵がない。「高級関数」が速いとは限らないので常に計測する。モンテカルロ等では条件全体を論理ベクトルで書き下すと `apply()` 版より桁違いに速くなることが多い。

```r
# apply(u, 1, f) の行ごとループを、行方向の論理演算で完全にベクトル化する
cndtn <- u[, 1] <= a & u[, 2] <= b1 | u[, 1] > a & u[, 2] <= b2
mean(cndtn)
```

---

## 事前確保（Pre-allocation）

`rbind`/`cbind`/`c` での逐次拡張は、毎回メモリ再確保とコピーが発生するため禁止。全体を先に確保してから代入する。

```r
# NG: 列を追加するたびにコピー / 逐次結合するたびにコピー
powers_bad <- function(x, dg) {
  pw <- matrix(x, nrow = length(x)); prod <- x
  for (i in 2:dg) { prod <- prod * x; pw <- cbind(pw, prod) }  # 毎回コピー
  pw
}

# OK: 全体を事前確保してから代入（約2倍速）
powers_ok <- function(x, dg) {
  pw <- matrix(nrow = length(x), ncol = dg); prod <- x
  pw[, 1] <- prod
  for (i in 2:dg) { prod <- prod * x; pw[, i] <- prod }
  pw
}

# ベクトルも同様: result <- c() で伸ばさず、vector("integer", n) を事前確保して result[i] <- ...
```

多数の断片を集める場合は `vector("list", n)` に貯めて最後に一括結合するのが定石:

```r
chunks <- vector("list", n_files)
for (i in seq_len(n_files)) chunks[[i]] <- read_one(files[i])
combined <- do.call(rbind, chunks)   # 結合は最後に1回だけ
```

---

## メモリ管理

### コピーオンモディファイ

`y <- z` の時点では実メモリはコピーされず参照共有される。どちらかが変更された瞬間に初めてコピーが作られる。`tracemem(z)` で監視すると、`y <- z` ではアドレスが変わらず、`y[1] <- 99` で初めてコピーが発生してアドレスが変化するのが確認できる。

ループ内の要素代入 `z[i] <- v` は内部的に `` z <- `[<-`(z, i, value = v) `` として実行される。素朴に書くとベクトル全体の再構築コストが毎回発生しうるので、事前確保とベクトル化で回避する。

同じデータでも構造で速度が変わる。行のリスト（`list` の各要素がベクトル）に対する要素更新はループで要素数ぶんのコピーが発生するが、行列にまとめれば列一括代入 `z[, 3] <- 8` がコピー1回で済み桁違いに速い。均質な数値データは `list` より `matrix`/`data.frame` を選ぶ。

### 大規模データの列限定読み込み・チャンク処理

```r
# data.table::fread — 列指定 + 型指定で無駄な読み込みを削る
dt <- data.table::fread("large.csv",
            select     = c("id", "amount", "date"),
            colClasses = c(id = "integer", amount = "double", date = "character"))

# arrow — Parquet から列プッシュダウン + 遅延評価。collect() で初めて R に読み込む
result <- arrow::open_dataset("data/parquet/") |>
  dplyr::select(id, amount) |> dplyr::filter(amount > 1000) |> dplyr::collect()
```

```r
# メモリに載らないデータはチャンク読み込みで逐次集計する
chunk_size <- 1e5; sums <- numeric(10)
for (k in seq_len(10)) {
  chunk   <- read.table("big.csv", header = FALSE,
                        skip = (k - 1) * chunk_size + 1,  # +1 でヘッダ行を飛ばす
                        nrows = chunk_size)
  sums[k] <- sum(chunk[, 2])
}
grand_total <- sum(sums)
```

---

## バイトコードコンパイル

```r
library(compiler)

f <- function(x) { s <- 0; for (i in seq_along(x)) s <- s + x[i]^2; s }
cf <- cmpfun(f)

system.time(f(runif(1e6)))    # コンパイル前
system.time(cf(runif(1e6)))   # コンパイル後（ループの多い自作関数で数倍速）
```

- `cmpfun()` はバイトコードにコンパイルした関数を返す。
- R 3.4 以降、標準パッケージや `source()` される関数は既定でバイトコードコンパイル済みのため、効果が出るのは主に自作の重いループ関数に限られる。
- 既にベクトル化された関数への効果は薄い。まずベクトル化を優先する。

---

## 並列 R

`parallel` は標準添付。UNIX/macOS はフォークベースの `mclapply()`、Windows 互換ならソケットクラスタの `parLapply()` を使う。モダンには `future`/`furrr` でバックエンドを抽象化する。

### mclapply() — フォークベース（UNIX/macOS）

```r
library(parallel)
result <- mclapply(1:100, function(i) mean(rnorm(1e4)),
                   mc.cores = detectCores() - 1)   # 1 コアは OS に残す
```

フォークで親環境を丸ごと共有するため `clusterExport()` 不要。Windows では動かず `mc.cores = 1` にフォールバックする。

### parLapply() — ソケットクラスタ（Windows 互換）

```r
library(parallel)
cl <- makeCluster(detectCores() - 1)
clusterExport(cl, c("my_func", "my_data"))   # 変数をワーカーへ送出
clusterEvalQ(cl, library(data.table))        # パッケージをワーカーで読み込む
result <- parLapply(cl, 1:100, function(i) my_func(my_data, i))
stopCluster(cl)                              # 必ず後始末する
```

### 並列 RNG — 再現性の確保

`set.seed()` をワーカー内で呼んでも独立ストリームは保証されない。L'Ecuyer-CMRG を使う。`clusterSetRNGStream(cl, iseed = 42)` をクラスタ起動後に呼ぶと、各ワーカーに独立かつ再現可能な乱数ストリームが割り当てられる（`furrr` では `furrr_options(seed = 42)` が同等）。

### foreach + %dopar%

```r
library(foreach); library(doParallel)
cl <- makeCluster(detectCores() - 1); registerDoParallel(cl)
result <- foreach(i = 1:100, .combine = c, .packages = "dplyr") %dopar% mean(rnorm(1e4))
stopCluster(cl)
```

`.combine` は結合方法を指定する（`rbind` で行結合、`"+"` で合計など）。

### future / furrr — モダンな非同期並列

```r
library(future); library(furrr)
plan(multisession, workers = 4)   # Windows 互換。UNIX は multicore（フォーク）も可

# purrr::map の並列版。seed で再現性ある並列 RNG を確保する
result <- future_map_dbl(1:100, ~ mean(rnorm(1e4)), .options = furrr_options(seed = 42))

plan(sequential)   # 後始末
```

バックエンドは `plan()` 一行で切り替えられるため、コードを変えず開発機（逐次）と HPC（多重ソケット）を使い分けられる。

### 並列化の限界とオーバーヘッド

12 ワーカーでも実測 3〜4 倍にとどまることは珍しくない。原因は scatter（データ転送）と gather（結果収集）のオーバーヘッド。細粒度タスク（1 回が数ミリ秒以下）は逐次のほうが速いので **計算時間 >> 通信時間** の粒度に分割する。大きな行列を繰り返しワーカーへ送ると転送コストが支配的になるため、事前に `clusterExport()` して転送を 1 回に抑える。

---

## C / C++ 連携

### .C() — シンプルな void 関数

引数を R オブジェクトからポインタに変換して C に渡し、C 関数は `void` を返す。結果は引数ポインタ経由で受け取る。

```c
/* sd.c: 行列の第 k 副対角を取り出す */
#include <R.h>
void subdiag(double *m, int *n, int *k, double *result) {
  int nval = *n, kval = *k, stride = nval + 1;
  for (int i = 0, j = kval; i < nval - kval; ++i, j += stride)
    result[i] = m[j];
}
```

```r
# R CMD SHLIB sd.c でビルドしてから読み込む
dyn.load("sd.so")  # Windows では "sd.dll"
m <- rbind(1:5, 6:10, 11:15, 16:20, 21:25)
res <- .C("subdiag",
          as.double(m), as.integer(nrow(m)), as.integer(2L),
          result = double(nrow(m) - 2))
res$result
```

落とし穴: R の行列は **列優先（column-major）**、C は行優先なので添字計算を誤ると別の要素を読む。C の添字は 0 始まり・R は 1 始まり。引数は必ず正確な型に変換して渡す（`as.integer()` / `as.double()`）。結果用メモリ（`double(n)`）は R 側で事前確保する。

`.C()` と `.Call()` の違い: `.C()` は引数がポインタのみ・戻り値は void・習熟コスト低。`.Call()` は R の内部型 `SEXP` を直接扱い、リストや任意の R 型を返せるが R 内部 API の理解が必要。

### Rcpp — モダンな C++ 連携

```r
library(Rcpp)

# 短い関数はインラインで定義できる
cppFunction('
double my_mean(NumericVector x) {
  int n = x.size(); double total = 0;
  for (int i = 0; i < n; i++) total += x[i];
  return total / n;
}')
my_mean(rnorm(1e6))

# 実務ではファイルに書いて sourceCpp() で読み込む
# src/moving.cpp 内で // [[Rcpp::export]] を付けた関数が R から呼べるようになる
sourceCpp("src/moving.cpp")   # 反復多・スカラー演算中心の処理で純 R ループの数百倍速
```

`NumericVector` / `IntegerVector` / `DataFrame` / `List` などが R オブジェクトと自動変換される。`[[Rcpp::export]]` タグを付けた関数を `sourceCpp()` が R から呼べる形で登録する。パッケージ化する場合は `DESCRIPTION` に `LinkingTo: Rcpp` を追加し、`src/` に配置する。

---

## Python 連携（reticulate）

```r
library(reticulate)
use_virtualenv("~/.venv/r-env", required = TRUE)  # または use_condaenv() / use_python()
py_config()                    # 現在の Python 設定を確認

np <- import("numpy")
x_np <- np$array(1:10)         # R → NumPy
y_r  <- py_to_r(x_np * 2)      # NumPy → R（自動型変換）

py_run_string("import numpy as np; result = np.mean([1,2,3,4,5])")
py$result                      # Python 名前空間から取得
```

Quarto / R Markdown では `{python}` チャンクで Python を実行でき、`py$var` で Python 名前空間、`r.var` で Python 側から R 名前空間にアクセスできる。

主要な型変換:

| R 型 | Python 型 |
|---|---|
| `numeric` (scalar) | `float` |
| `integer` (scalar) | `int` |
| `logical` | `bool` |
| `NULL` | `None` |
| `vector` | `list` |
| `matrix` / `array` | `numpy.ndarray` |
| `data.frame` | `pandas.DataFrame` |
| named `list` | `dict` |

境界データ変換のコストに注意する。R の `numeric` は 64bit 倍精度で NumPy の `float64` と一致するが、`float32`/`int32` 配列は変換時に型昇格コストが出る。大きな DataFrame を繰り返し `py$df` で取得すると毎回コピーが発生するので、`py_run_string("subset = df[['id','value']].head(1000)")` のように **必要な列を Python 側で絞ってから** `py$subset` で R に持ち込む。

---

## セキュリティ

- `eval(parse())`、`source()`、`system()` にユーザー入力を渡さない。
- SQL は parameterized query を使う。文字列連結で WHERE 句を作らない。
- ファイル名やパスは許可されたディレクトリ配下に正規化して確認する。
- HTML/Markdown 出力にユーザー入力を混ぜるときは escaping を確認する。
- API key、DB password、個人情報をログ、plot、HTML、cache、RDS に残さない。
- 共有データは最小化、匿名化、アクセス制御、削除手順を用意する。

```r
# NG: 文字列連結は SQL インジェクションの温床
query <- paste0("SELECT * FROM users WHERE name = '", input$name, "'")

# OK: プレースホルダでパラメータ化する
library(DBI)
res <- dbGetQuery(con, "SELECT * FROM users WHERE name = ?", params = list(input$name))
```

```r
token <- Sys.getenv("API_TOKEN")                 # 秘匿値は環境変数から（コード/RDS に埋め込まない）
if (!nzchar(token)) stop("API_TOKEN が未設定です")

# パスは許可ディレクトリ配下に正規化して検証する
safe_path <- normalizePath(file.path(base_dir, user_file), mustWork = FALSE)
if (!startsWith(safe_path, normalizePath(base_dir))) stop("不正なパス")
```

`.Renviron` に置いた秘匿値は commit しない（`.gitignore` に追加・`usethis::edit_r_environ()` で編集）。Shiny では特に、ユーザー入力を `filter()`/SQL/`file.path()`/`eval()` に渡す経路を全て検証する。

---

## レビュー観点チェックリスト

- 構成・再現性: パスは `here()` 等で root 起点か。`renv.lock` が commit され `set.seed()` で乱数が固定されているか。関数先頭で `setwd()`/`rm(list=ls())` を乱用していないか。
- テスト: 純粋関数から AAA でテストされ、浮動小数点に `tolerance` を使い、外部依存が mock/skip で隔離されているか。
- 性能: 「遅い」を推測で断定せず `Rprof`/`bench` で計測したか。`rbind`/`c` の逐次拡張やループ内コピーが残っていないか。
- 並列: 並列 RNG（`clusterSetRNGStream` / `furrr_options(seed=)`）を設定し、粒度は 計算 >> 通信 か。クラスタを `stopCluster()`/`plan(sequential)` で後始末したか。
- 連携・安全: C/Rcpp/Python 導入はプロファイル後か。境界の型変換・列優先/行優先・0/1 始まりの添字を検証したか。SQL がパラメータ化され、秘匿値が環境変数で、ユーザー入力が `eval`/パス/HTML に無検証で渡っていないか。
