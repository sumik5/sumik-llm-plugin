# R 開発ガイド

R のスクリプト、パッケージ、データ分析、可視化、統計解析、機械学習、Shiny、Quarto/R Markdown、AI API 連携を実装・レビューするときに使う。

## 使用タイミング

- `.R`, `.Rmd`, `.qmd`, `renv.lock`, `DESCRIPTION`, `NAMESPACE`, `.Rproj`, `app.R` がある
- RStudio、Rscript、tidyverse、dplyr、tidyr、ggplot2、Shiny、Quarto、R Markdown、testthat、renv、tidymodels を扱う
- CSV/Excel/DB/JSON などを読み込み、整形、分析、可視化、レポート化する
- R パッケージ、R スクリプト、Shiny アプリ、分析ノートブック、統計モデル、AI API 呼び出しを書く

## 参照ファイル

| ファイル | 使う場面 |
|----------|----------|
| `references/CORE-LANGUAGE.md` | R のデータ構造、ベクトル化、関数、制御構造、OOP、デバッグ |
| `references/DATA-ANALYSIS.md` | データ読み込み、整形、EDA、可視化、統計解析の実務 |
| `references/STATISTICS-ML-AI.md` | シミュレーション、統計モデリング、tidymodels、AI API/RAG |
| `references/ENGINEERING-PRODUCTION.md` | renv、testthat、パッケージ開発、Shiny、Quarto、本番運用、性能、セキュリティ |

## 基本ワークフロー

1. プロジェクト種別を判定する。`DESCRIPTION` ならパッケージ、`app.R` や `R/` + `server/ui` なら Shiny、`.qmd`/`.Rmd` ならレポート、単独 `.R` ならスクリプトとして扱う。
2. 既存スタイルを確認する。base R、tidyverse、data.table、tidymodels のどれが主流かを見て合わせる。
3. 実行環境を確認する。`Rscript --version`、`renv::status()`、`sessionInfo()`、`DESCRIPTION`、`renv.lock` を優先する。
4. 入力データ、欠損値、型、因子、水準、日付時刻、文字コード、列名、単位を先に確認する。
5. 変換処理は再現可能な関数やパイプラインにまとめる。グローバル環境や手作業の RStudio 操作に依存しない。
6. 乱数を使う処理は `set.seed()` を明示し、学習/検証分割やリサンプリングの粒度を固定する。
7. 外部 API、DB、ファイル、時刻に依存する処理はテストで差し替えやすくする。
8. 検証を実行する。スクリプトは `Rscript`、パッケージは `R CMD check`、テストは `testthat`、レポートは `quarto render` または `rmarkdown::render()` を使う。

## プロジェクト種別の手掛かり

| 手掛かり | 扱い |
|----------|------|
| `DESCRIPTION`, `NAMESPACE`, `R/`, `tests/testthat/` | R パッケージ |
| `renv.lock` | 再現可能なプロジェクト。依存追加後は snapshot を検討 |
| `app.R`, `ui.R`, `server.R`, `R/` の Shiny module | Shiny アプリ |
| `.qmd`, `_quarto.yml` | Quarto レポート/サイト |
| `.Rmd` | R Markdown レポート |
| `data-raw/`, `data/`, `inst/extdata/` | データ処理またはパッケージ同梱データ |
| `models/`, `recipes/`, `workflows/` | モデリング・tidymodels 系 |

## 実装原則

- 既存コードが tidyverse 中心なら `dplyr`, `tidyr`, `purrr`, `stringr`, `lubridate`, `ggplot2` に合わせる。base R 中心のパッケージ内部では依存を増やさない。
- `library()` はスクリプトやレポートの先頭に集約する。パッケージ関数や共有コードでは `pkg::fun()` を優先する。
- `.GlobalEnv`、`setwd()`、暗黙のカレントディレクトリ、`.RData` 自動ロードに依存しない。パスは `here`、`rprojroot`、明示引数で扱う。
- `NA`, `NULL`, `NaN`, `Inf` を区別する。集計では `na.rm` の有無を明示し、欠損を落とす判断はコメントや変数名で分かるようにする。
- ベクトルリサイクル、因子の水準、日付時刻のタイムゾーン、文字列エンコーディングはバグ化しやすいので境界テストを書く。
- ループよりベクトル化を優先するが、可読性やメモリ効率を壊すなら明示的なループや `purrr` を使う。
- 長い分析ノートブックにロジックを閉じ込めない。再利用する変換、集計、可視化、モデル学習は関数化して `.R` に分離する。
- 秘密情報は `.Renviron`、環境変数、外部 secret manager から読む。トークン、キー、接続文字列をコード、Rmd/qmd、出力 HTML に埋め込まない。

## よく使う検証コマンド

```bash
Rscript --version
Rscript path/to/script.R
Rscript -e 'renv::status()'
Rscript -e 'testthat::test_dir("tests/testthat")'
Rscript -e 'devtools::test()'
R CMD check .
quarto render report.qmd
Rscript -e 'rmarkdown::render("report.Rmd")'
```

## レビュー観点

- 入力データの型と欠損が明示的に扱われているか
- 分析結果が実行環境、乱数、外部状態に依存せず再現できるか
- 統計モデルの前処理、分割、評価でデータリークがないか
- 可視化が軸、単位、スケール、凡例、サンプルサイズを誤解させないか
- Shiny の reactive が過剰再計算や循環依存を起こしていないか
- R パッケージで exported/internal API、依存、ドキュメント、テストが一致しているか
- 外部 API/DB/ファイル操作で secret、SQL injection、パストラバーサル、任意コード実行のリスクがないか

