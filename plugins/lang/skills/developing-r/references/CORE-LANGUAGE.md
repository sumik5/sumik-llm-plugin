# R コア言語

## データ構造

- atomic vector は R の基本単位。logical、integer、double、character、complex、raw を混在させると共通型へ coercion される。
- `list` は異なる型や長さを保持できる。data frame/tibble の列も list として扱える。
- `matrix` と `array` は同一型の多次元データ。列優先で格納される。
- data frame は同じ行数の列を持つ list。tibble は出力、部分抽出、名前修復がより厳密。
- factor は整数ベクトル + levels。カテゴリ順序、未使用水準、文字列変換で事故が起きやすい。
- Date/POSIXct/POSIXlt はタイムゾーンと表示形式を分けて考える。
- attributes と class により S3/S4/R6 の振る舞いが決まる。

## 添字と抽出

- R は 1-based indexing。0 は「何も選ばない」、負の添字は除外、logical vector はフィルタ、名前付き vector/list は名前で抽出する。
- `[` は同じ種類のコンテナを返す。`[[` は要素そのものを返す。`$` は名前付き list/data frame の簡易抽出。
- data frame で単一列や単一行を抽出すると dimension drop が起きる。形を保つ必要があるときは `drop = FALSE` を使う。
- 部分一致に頼らない。パッケージや共有関数では明示名を使う。

## 欠損値と特殊値

- `NA` は欠損、`NULL` は値や要素が存在しないこと、`NaN` は未定義の数値、`Inf` は無限大。
- `x == NA` は使わない。`is.na(x)`、`is.null(x)`、`is.nan(x)`、`is.finite(x)` を使う。
- `mean(x)` などの集計は `NA` を含むと `NA` になりうる。`na.rm = TRUE` を使う場合は、欠損を除外してよい根拠を明確にする。
- 欠損を落とす処理は分析結果を変える。`drop_na()`、`complete.cases()`、代入補完はサンプル数の変化を確認する。

## ベクトル化とリサイクル

- 多くの演算は要素ごとにベクトル化される。`x + y`、`ifelse()`、`pmin()`、`pmax()`、`case_when()` を活用する。
- 長さ 1 の値はリサイクルされる。長さが割り切れないリサイクルは警告や潜在バグになる。
- `if` は長さ 1 の条件だけに使う。ベクトル条件には `ifelse()`、`dplyr::if_else()`、`case_when()` を使う。
- `&&` と `||` は最初の要素だけを見る。ベクトル論理には `&` と `|`、集約には `any()` と `all()` を使う。

## 関数

- 関数は第一級オブジェクト。入力、出力、副作用を分けて設計する。
- R は lexical scoping。関数内で見つからない名前は外側の環境から探されるため、暗黙のグローバル変数参照を避ける。
- 引数は lazy evaluation。使われるまで評価されないので、default 引数と副作用の組み合わせに注意する。
- `...` は拡張点として便利だが、typo を飲み込みやすい。受け取る引数を検証する。
- API では返り値の型と shape を安定させる。成功時は data frame、失敗時は list などの揺れを避ける。

## 制御構造と反復

- `for` ループは可読性が高い場合に使ってよい。大きな object を反復的に伸ばすのは避け、事前確保する。
- `lapply()`、`vapply()`、`Map()`、`Reduce()` は base R の反復手段。型を固定したい場合は `vapply()` を使う。
- tidyverse では `purrr::map_*()` 系で出力型を明示する。
- エラーを値として扱いたいときは `tryCatch()`、`purrr::safely()`、`purrr::possibly()` を使う。

## OOP の使い分け

- S3 は軽量な generic/method。多くの tidyverse/base オブジェクトと相性がよい。
- S4 は slot と class を厳密に定義する必要がある領域に向く。
- R6 は mutable object や stateful service に向くが、分析コードでは副作用を増やしすぎない。
- 既存パッケージの拡張では、そのエコシステムが使う OOP に合わせる。

## デバッグ

- 直近のエラーは `traceback()`、tidyverse/rlang 系は `rlang::last_trace()` を見る。
- 一時停止して確認するには `browser()`、関数単位では `debugonce()` を使う。
- オブジェクト構造は `str()`、`dplyr::glimpse()`、`typeof()`、`class()`、`attributes()` で確認する。
- 再現用の最小データを作り、外部ファイルや巨大データに依存しない失敗例へ縮小する。

