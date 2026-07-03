# R データ分析

データ入出力・文字列/正規表現・tidyverse 整形・join/reshape・data.table・EDA を、実務で使えるコードとレビュー観点でまとめる。base R と tidyverse を対比しながら、それぞれの落とし穴を明示する。

---

## 1. パスと作業ディレクトリ

`setwd()` 前提のスクリプトは移植性が低い。パスは `here`・`rprojroot`・関数引数・設定値で扱い、`file.path()` で OS 差を吸収する。

```r
file.path("data", "raw", "sales.csv")  # OS 依存の区切り文字を自動適用
basename("/tmp/bin/Rscript")           # "Rscript"
dirname("/tmp/bin/Rscript")            # "/tmp/bin"
normalizePath("./data/../x.csv", mustWork = FALSE)  # 絶対パスへ正規化
list.files("data", pattern = "\\.csv$", full.names = TRUE, recursive = TRUE)

# 一時的に移動する場合は必ず元へ戻す
run_in <- function(dir, expr) {
  old <- setwd(dir)                    # 戻り値は変更前のパス
  on.exit(setwd(old), add = TRUE)      # 例外時でも復帰
  force(expr)
}
```

---

## 2. 表形式データの読み込み

### 2.1 readr（tidyverse・推奨）

型推定に任せきらない。列型・ロケール・文字コード・欠損表現・日付形式を明示すると本番で崩れにくい。

```r
library(readr)

df <- read_csv("sales.csv")            # 高速・tibble を返す

# 列型を明示（推定任せは本番で危険）
df <- read_csv("sales.csv", col_types = cols(
  date    = col_date(format = "%Y-%m-%d"),
  revenue = col_double(),
  region  = col_character(),
  active  = col_logical()
))

df <- read_tsv("data.tsv")             # タブ区切り
df <- read_csv("data.csv", na = c("", "NA", "N/A", "-"))  # 複数の欠損表現

# 大容量は vroom（遅延読み込みで高速）
df <- vroom::vroom("big.csv")
```

### 2.2 base R（依存を足したくない場面）

```r
df <- read.table("data.txt",
  header           = TRUE,
  sep              = "",               # "" は任意個数の空白で分割
  na.strings       = c("NA", "*"),
  comment.char     = "#",
  stringsAsFactors = FALSE,            # R 4.0+ の既定
  fileEncoding     = "UTF-8"
)

df <- read.csv("data.csv")             # header=TRUE, sep="," が既定
df <- read.csv2("eu.csv")              # 欧州式（sep=";" dec=","）
df <- read.delim("data.tsv")           # sep="\t"

# 高速化: colClasses を与えると型推定を省ける
df <- read.csv("large.csv",
  colClasses = c("integer", "numeric", "character", "logical"))
```

**header の非対称性**: `read.table` は `header = FALSE`、`read.csv` は `header = TRUE` が既定。`read.table` で CSV を読むなら明示する。

### 2.3 Excel / JSON / DB / RDS

```r
library(readxl)
excel_sheets("report.xlsx")                      # シート一覧
df <- read_excel("report.xlsx", sheet = "Q4", range = "A1:E50")
df <- jsonlite::fromJSON("data.json")            # JSON

# DB は DBI + ドライバ。遅延 SQL 変換は dbplyr
con <- DBI::dbConnect(RSQLite::SQLite(), "app.db")
df  <- DBI::dbGetQuery(con, "SELECT * FROM sales WHERE region = ?",
                       params = list("east"))    # プレースホルダで SQLi 回避
DBI::dbDisconnect(con)

# 中間データは RDS が安全（型・factor 水準・属性を完全保持）
saveRDS(df, "data.rds"); df <- readRDS("data.rds")
```

---

## 3. 表形式データの書き出し

```r
readr::write_csv(df, "out.csv")                  # BOM なし UTF-8・行名なし
readr::write_excel_csv(df, "out.csv")            # Excel 向け BOM 付き UTF-8

# base R
write.csv(df, "out.csv", row.names = FALSE)      # row.names=FALSE を忘れない
write.table(df, "out.tsv", sep = "\t",
            quote = FALSE, row.names = FALSE, fileEncoding = "UTF-8")

# 安全な書き出し（一時ファイル経由でアトミックに置換）
safe_write_csv <- function(df, path) {
  tmp <- paste0(path, ".tmp")
  on.exit(if (file.exists(tmp)) file.remove(tmp), add = TRUE)
  readr::write_csv(df, tmp)
  file.rename(tmp, path)               # 同一ファイルシステム内は原子的
}
```

---

## 4. コネクション・圧縮・エンコーディング

### 4.1 コネクションの種類

| 関数 | 用途 |
|------|------|
| `file(path, open)` | ローカルファイル |
| `url(url, open)` | HTTP/HTTPS/FTP |
| `gzfile` / `bzfile` / `xzfile` | 圧縮ファイル（解凍不要で読める） |
| `textConnection(x)` | 文字列ベクトルをファイルのように扱う |

`open`: `"r"` 読み取り / `"w"` 書き込み / `"a"` 追記 / `"rb"`・`"wb"` バイナリ。

```r
# 開いたコネクションは必ず閉じる（on.exit が確実）
read_head <- function(path, n = 5) {
  con <- file(path, "r")
  on.exit(close(con), add = TRUE)
  readLines(con, n = n, warn = FALSE)
}

# gzip 圧縮 CSV を透過的に読み書き
df  <- read.csv(gzfile("data.csv.gz"))
con <- gzfile("out.csv.gz", "w"); write.csv(df, con, row.names = FALSE); close(con)

# textConnection: テスト用に文字列から data.frame を作る
csv_text <- c("name,age", "Alice,30", "Bob,25")
df <- read.csv(textConnection(csv_text))
```

### 4.2 行単位の入出力

```r
lines <- readLines("notes.txt", warn = FALSE)    # 全行を文字ベクトルへ
writeLines(c("first", "second"), "out.txt")

# 巨大ファイルを 1 行ずつストリーム処理
while (length(line <- readLines(con, n = 1, warn = FALSE)) > 0) { ... }
```

### 4.3 エンコーディング

```r
# 読み込み時に指定
df    <- read.csv("sjis.csv", fileEncoding = "CP932")   # Windows Shift-JIS
lines <- readLines(file("euc.txt", encoding = "EUC-JP"))
guess <- readr::guess_encoding("unknown.txt")           # 検出（参考値）

# 変換（失敗箇所は NA になる）
utf8 <- iconv(lines, from = "CP932", to = "UTF-8")
sum(is.na(utf8))                                         # 変換失敗数を確認

# 書き出し時に指定
write.csv(df, "cp932.csv", fileEncoding = "CP932", row.names = FALSE)
```

---

## 5. 文字列操作（base R）

R の文字列は `character` 型ベクトルで、ほぼ全関数がベクトル化される。

```r
nchar(c("alpha", "beta"))              # 5 4
substr("Equator", 3, 5)                # "uat"（1 始まり）
s <- "Hello World"; substr(s, 1, 5) <- "Howdy"; s   # "Howdy World"（代入）

# 結合
paste0("file", 1:3, ".csv")            # "file1.csv" "file2.csv" "file3.csv"
paste(c("a", "b", "c"), collapse = "-")# "a-b-c"（1 文字列に畳む）

# 整形（C の printf 準拠・ベクトル化される）
sprintf("q%d.pdf", 1:3)                # "q1.pdf" "q2.pdf" "q3.pdf"
sprintf("%05d", c(1, 23, 456))         # "00001" "00023" "00456"（ゼロ埋め）
sprintf("%.2f", 3.14159)               # "3.14"
format(1234567, big.mark = ",")        # "1,234,567"

# 大小変換・空白除去
toupper("abc"); tolower("ABC")
trimws("  hello  ")                    # "hello"（which="left"/"right" で片側）
```

**落とし穴 — `nchar(NA)`**: `nchar(NA)` は文字列 `"NA"` として `2` を返す。欠損を保ちたいなら `nchar(NA_character_)`（`NA` を返す）か `nchar(x, keepNA = TRUE)` を使う。factor は `as.character()` してから渡す。

---

## 6. 正規表現

正規表現が効く関数: `grep` `grepl` `sub` `gsub` `regexpr` `gregexpr` `strsplit`。

```r
x <- c("Equator", "North Pole", "South Pole")

grep("Pole", x)                        # 2 3（インデックス）
grep("Pole", x, value = TRUE)          # "North Pole" "South Pole"
grepl("Pole", x)                       # FALSE TRUE TRUE（論理ベクトル）
grep("pole", x, ignore.case = TRUE)    # 2 3

# 置換: sub は最初の 1 件、gsub は全件
sub("o",  "0", "foo")                  # "f0o"
gsub("o", "0", "foo")                  # "f00"
gsub("(\\w+) (\\w+)", "\\2 \\1", "John Smith")  # "Smith John"（後方参照）
gsub("\\s+", " ", "a   b  c")          # "a b c"（連続空白を圧縮）

# マッチ部分の抽出
m <- gregexpr("\\$[0-9]+\\.[0-9]+", "price $9.99 and $14.50")
regmatches("price $9.99 and $14.50", m)[[1]]    # "$9.99" "$14.50"

# 分割（結果はリスト。[[1]] を忘れない）
strsplit("6-16-2011", "-")[[1]]        # "6" "16" "2011"
as.integer(strsplit("1 4 5", "\\s+")[[1]])      # 1 4 5
```

**メタ文字とエスケープ**: `. ^ $ | ? * + ( ) [ ] { } \` はメタ文字。リテラルとして扱うには R 文字列中で `\\` を前置する（`"\\."` = 正規表現の `\.`）。より直感的には `fixed = TRUE` を使う。

```r
grep(".", c("abc", "f.g"))                 # 1 2（. が任意 1 文字にマッチ）
grep("\\.", c("abc", "f.g"))               # 2（リテラルのピリオド）
grep(".", c("abc", "f.g"), fixed = TRUE)   # 2（同上・読みやすい）
strsplit("x.y.z", ".", fixed = TRUE)[[1]]  # "x" "y" "z"（fixed 必須）
```

**貪欲マッチ**: `.*` は既定で最長一致。最短一致は `perl = TRUE` で `?` を付ける。

```r
x <- "<a>text</a>"
regmatches(x, regexpr("<.*>",  x))              # "<a>text</a>"（貪欲）
regmatches(x, regexpr("<.*?>", x, perl = TRUE)) # "<a>"（非貪欲）
```

---

## 7. stringr（tidyverse）

関数名・引数順・NA の扱いが統一され、パイプに乗せやすい。

| base R | stringr |
|--------|---------|
| `nchar(x)` | `str_length(x)` |
| `substr(x, s, e)` | `str_sub(x, s, e)` |
| `grepl(p, x)` | `str_detect(x, p)` |
| `grep(p, x)` | `str_which(x, p)` |
| `regmatches(x, regexpr(p, x))` | `str_extract(x, p)` |
| `sub` / `gsub` | `str_replace` / `str_replace_all` |
| `strsplit(x, p)` | `str_split(x, p)` |
| `trimws(x)` | `str_trim(x)` |
| `formatC(x, width, flag="0")` | `str_pad(x, w, pad = "0")` |
| — | `str_count` / `str_to_title` / `str_wrap` |

```r
library(stringr)
x <- c("apple pie", "banana split")

str_detect(x, "an")                    # FALSE TRUE
str_count("banana", "a")               # 3
str_extract("price $9.99", "\\$[0-9.]+")   # "$9.99"
str_replace_all("hello", "o", "0")     # "hell0"
str_split("a-b-c", "-")[[1]]           # "a" "b" "c"
str_pad("42", 5, pad = "0")            # "00042"
str_c("a", NA)                         # NA（paste0 は "aNA"）

# 正規表現ヘルパー
str_detect("a.b", fixed("."))              # TRUE（リテラル）
str_detect("Hello", regex("hello", ignore_case = TRUE))  # TRUE
```

---

## 8. tidyverse 整形の基盤

### 8.1 パイプ

R 4.1+ はネイティブパイプ `|>` が使える。`%>%` は magrittr / tidyverse 経由。

```r
result <- data |>
  select(name, salary) |>
  filter(salary > 50000) |>
  arrange(desc(salary))
```

| 項目 | `|>` | `%>%` |
|------|------|-------|
| 依存 | なし（R 4.1+） | magrittr / tidyverse |
| プレースホルダ | `_`（R 4.2+・名前付き引数のみ） | `.`（任意位置） |
| 推奨 | 新規コード | 旧コード互換・`.` が必要な場面 |

ラムダは R 4.1+ の `\(x) x^2`、purrr 内では `~ .x^2` を使う。

### 8.2 tibble

```r
library(tibble)
employees <- tibble(
  name   = c("Alice", "Bob", "Charlie", "Diana", "Eve"),
  dept   = c("Sales", "IT", "HR", "IT", "Sales"),
  salary = c(55000, 72000, 48000, 68000, 61000),
  years  = c(3, 7, 2, 5, 4)
)
as_tibble(iris)                        # data.frame → tibble
```

tibble は列名の部分マッチをエラーにし、文字列を自動 factor 化せず、`df[, 1]` で列をドロップしない。data.frame より事故が少ない。

### 8.3 dplyr コア動詞

```r
library(dplyr)

# filter: 行の絞り込み
employees |> filter(dept == "IT", years >= 4)      # カンマ = AND
employees |> filter(dept %in% c("IT", "HR"))       # OR は %in% が可読

# select: 列の選択（tidyselect ヘルパー・型選択が使える）
employees |> select(name, salary)
employees |> select(-years)
employees |> select(starts_with("sal"), where(is.numeric))
employees |> rename(income = salary)

# mutate: 列の追加・変更
employees |> mutate(
  monthly = salary / 12,
  bonus   = if_else(years >= 5, salary * 0.1, 0),
  rank    = case_when(
    salary >= 70000 ~ "Senior",
    salary >= 55000 ~ "Mid",
    TRUE            ~ "Junior"
  )
)

# arrange / group_by + summarise / 補助動詞
employees |> arrange(dept, desc(salary))
employees |>
  group_by(dept) |>
  summarise(avg = mean(salary), n = n(), .groups = "drop")  # 解除を常に明示
employees |> count(dept, sort = TRUE)
employees |> distinct(dept)
employees |> slice_max(salary, n = 2)              # 上位 2 行
```

`.groups = "drop"` を省略すると summarise 後にグループが残り、後続処理が直感と異なる。**常に明示する習慣をつける。**

### 8.4 across（複数列への一括適用）

```r
# na.rm はラムダ形式で渡す
df |> summarise(across(where(is.numeric), ~ mean(.x, na.rm = TRUE)))

# 複数関数を適用（列名にサフィックス）
df |> summarise(across(where(is.numeric),
  list(mean = mean, sd = sd), na.rm = TRUE))       # revenue_mean, revenue_sd, ...

# if_any / if_all で行フィルタ
df |> filter(if_all(starts_with("rev"), ~ !is.na(.x)))
```

---

## 9. join

```r
orders    <- tibble(id = 1:3, customer_id = c(10, 11, 12), amount = c(500, 300, 700))
customers <- tibble(id = c(10, 11, 99), name = c("A", "B", "C"))

left_join(orders,  customers, by = c("customer_id" = "id"))  # orders 全行
inner_join(orders, customers, by = c("customer_id" = "id"))  # マッチのみ
full_join(orders,  customers, by = c("customer_id" = "id"))  # 両方全行

# フィルタリング join（列を増やさない）
semi_join(orders, customers, by = c("customer_id" = "id"))   # マッチする orders
anti_join(orders, customers, by = c("customer_id" = "id"))   # マッチしない orders
```

**join のレビュー観点**: キーの一意性と行数の増減を必ず確認する。many-to-many join は意図を明示する。

```r
orders |> count(customer_id) |> filter(n > 1)      # キー重複を検出

# 想定を relationship で契約化（違反すればエラー）
left_join(a, b, by = "key", relationship = "many-to-one")
nrow(orders); nrow(result)                         # join 前後で行数を比較
```

---

## 10. reshape（tidyr）

```r
library(tidyr)

wide <- tibble(product = c("A", "B"), Q1 = c(100, 200), Q2 = c(150, 180))

# wide → long
long <- wide |> pivot_longer(cols = starts_with("Q"),
  names_to = "quarter", values_to = "revenue")

# long → wide
long |> pivot_wider(names_from = quarter, values_from = revenue)

# 列名に複数情報が詰まったデータは先に分解する
tibble(ym = c("2024-01", "2024-02")) |>
  separate(ym, into = c("year", "month"), sep = "-")
tibble(y = 2024, m = "01") |> unite("ym", y, m, sep = "-")

# NA を含む行の除去
df |> drop_na(salary, dept)            # 指定列に NA がある行のみ削除

# list-column（グループごとに data.frame を入れ子）
nested <- employees |> group_by(dept) |> nest()
nested |> unnest(data)
```

---

## 11. purrr / lubridate / forcats

### 11.1 purrr（関数型）

```r
library(purrr)
map_dbl(1:3, ~ .x^2)                   # 型を明示（合わなければ即エラー）
map2_dbl(c(1, 2), c(10, 20), ~ .x + .y)
pmap(list(n = c(10, 20), mean = c(0, 1), sd = c(1, 1)), rnorm)

# 複数ファイルを読んで結合
df_all <- map(files, read_csv, show_col_types = FALSE) |> list_rbind()

# エラー処理
safe_read <- possibly(read_csv, otherwise = tibble())  # 失敗時デフォルト値
results   <- map(urls, safely(httr::GET))              # result / error を分離
reduce(list(df1, df2, df3), full_join, by = "id")      # 複数 join を一発で
```

### 11.2 lubridate（日付・時刻）

```r
library(lubridate)
ymd("2024-01-15"); mdy("01/15/2024"); ymd_hms("2024-01-15 09:30:00")

d <- ymd("2024-07-03")
year(d); month(d, label = TRUE); wday(d, label = TRUE); quarter(d)
floor_date(d, "month")                 # 2024-07-01

# mutate 内で時間特徴量を作る
df |> mutate(
  month      = month(date, label = TRUE),
  is_weekend = wday(date) %in% c(1, 7),
  week_start = floor_date(date, "week")
)
```

### 11.3 forcats（factor 順序）

グラフの並び順は factor 水準で決まる。順序は明示的に制御する。

```r
library(forcats)
df |> mutate(product = fct_reorder(product, revenue, .desc = TRUE))  # 値で並べ替え
fct_infreq(f)                          # 頻度順
fct_lump_n(f, n = 5)                   # 上位 5 水準以外を Other
fct_relevel(f, "Low", "Med", "High")   # 手動指定
```

---

## 12. data.table（大規模データ）

数百万行超では data.table が有効。構文は `dt[i, j, by]`（i=行フィルタ / j=列操作 / by=グループ）。

```r
library(data.table)
dt <- fread("large.csv", select = c("id", "revenue", "region"))  # 高速読み込み

dt[revenue > 0]                                    # 行フィルタ
dt[, .(avg = mean(revenue), n = .N), by = region]  # グループ集計
dt[, monthly := revenue / 12]                      # 列追加（参照渡し・コピーなし）
setkey(dt, id); merged <- dt1[dt2, on = "id"]      # インデックス付き join
fwrite(dt, "out.csv")

as_tibble(dt); as.data.table(df)                   # 相互変換
```

| データ規模 | 推奨 |
|-----------|------|
| 〜100 万行 | dplyr（可読性優先） |
| 100 万〜1000 万行 | dplyr + vroom、または data.table |
| 1000 万行超 | data.table、または DuckDB（duckdb + dplyr） |

**落とし穴**: `:=` は元の `dt` を破壊的に変更する。元を残したいなら `copy(dt)` してから操作する。

---

## 13. EDA ワークフロー

最初に構造・欠損・重複・範囲・カテゴリ水準を確認し、異常値と欠損パターンを分けて見る。

```r
# 構造把握・サマリー
dim(df); names(df); glimpse(df)
summary(df)                            # base: 最小・最大・四分位・欠損数
skimr::skim(df)                        # 型別サマリー・ミニヒストグラム

# 欠損
df |> summarise(across(everything(), ~ sum(is.na(.x))))
df |> filter(if_any(everything(), is.na))

# カテゴリ分布・数値分布
df |> count(region, sort = TRUE)
df |> summarise(
  mean = mean(revenue, na.rm = TRUE),
  sd   = sd(revenue, na.rm = TRUE),
  p25  = quantile(revenue, 0.25, na.rm = TRUE),
  p75  = quantile(revenue, 0.75, na.rm = TRUE)
)

# 重複・列名整理
df |> distinct() |> nrow()             # 完全重複を除いた行数
df |> count(id) |> filter(n > 1)       # キー列の重複
df <- janitor::clean_names(df)         # 列名を snake_case に統一
```

サンプルサイズ・欠損除外数・外れ値処理・単位変換は、分析結果の近くに記録として残す。

---

## 14. 実践パターン

```r
# A. 複数 CSV を読み、ファイル名を列に残す
read_with_name <- function(f) read_csv(f, show_col_types = FALSE) |>
  mutate(source_file = basename(f))
combined <- map(files, read_with_name) |> list_rbind()

# B. 重い計算のキャッシュ（RDS で再利用）
cached <- function(path, expr, force = FALSE) {
  if (!force && file.exists(path)) return(readRDS(path))
  result <- force(expr); saveRDS(result, path); result
}

# C. グループごとにモデルを当てはめる（split-apply）
employees |>
  group_by(dept) |> nest() |>
  mutate(model = map(data, ~ lm(salary ~ years, data = .x)),
         tidy  = map(model, broom::tidy)) |>
  select(dept, tidy) |> unnest(tidy)
```

**rowwise は遅い**。行ごとの最大値などはベクトル化で置き換える。

```r
df |> rowwise() |> mutate(m = max(c(a, b, c))) |> ungroup()  # 遅い
df |> mutate(m = pmax(a, b, c))                              # 速い
```

---

## 15. レビュー観点・落とし穴まとめ

### データ入出力

- 型推定に任せきらない。列型・ロケール・文字コード・欠損表現・日付形式を明示する。
- 中間データは `saveRDS()`/`readRDS()` が安全。`.RData` に複数オブジェクトを詰める運用は再現性を落とす。
- パスは `here`・関数引数・設定値で扱い、`setwd()` 前提のスクリプトにしない。
- 開いたコネクションは `on.exit(close(con))` で確実に閉じる。閉じ忘れるとバッファ未書き込みで欠損する。

### 整形・変換

- dplyr の基本順序は `filter` → `select` → `mutate` → `group_by` → `summarise` → `arrange`。
- `summarise()` の後は `.groups = "drop"` を明示し、グループの残存事故を防ぐ。
- join はキーの一意性と行数の増減を確認する。many-to-many は `relationship` で意図を契約化する。
- wide/long 変換は `pivot_longer`/`pivot_wider`。列名に複数情報を詰めたデータは先に `separate` で分解する。
- 文字列は `stringr`、日付は `lubridate`、カテゴリ順序は `forcats` で意図を読みやすくする。
- `rowwise()` は遅い。ベクトル化・list-column・nest/map・join で置き換えられないか確認する。

### 文字列・正規表現

| 落とし穴 | 対処 |
|---------|------|
| `.` がリテラルにならない | `fixed = TRUE` か `"\\."` |
| `strsplit(fn, ".")` が全文字分割 | `strsplit(fn, ".", fixed = TRUE)` |
| `nchar(NA)` が `2` | `nchar(NA_character_)` / `keepNA = TRUE` |
| `paste0("x", NA)` が `"xNA"` | `str_c` は NA を伝播 |
| factor をそのまま `nchar` へ | `as.character()` してから |
| `sub` が 1 件しか置換しない | 全置換は `gsub` |
| 貪欲マッチが広く取りすぎる | `perl = TRUE` で `.*?` |
| `strsplit(x, "-")` の `[[1]]` 忘れ | 戻り値はリスト・`[[1]]` で取り出す |

### EDA・統計

- 最初に行数・列数・型・欠損数・重複・範囲・カテゴリ水準・サンプルを確認する。
- 異常値と欠損パターンを分けて見る。欠損除外数・外れ値処理・単位変換は結果の近くに残す。
- p 値だけで結論しない。推定値・信頼区間・効果量・サンプルサイズ・仮定の限界を併記する。
- 予測目的と説明目的を混同しない。説明なら解釈可能性と仮定、予測なら汎化性能を優先する。
