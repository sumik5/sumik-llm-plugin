# R エンジニアリングと運用

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

- パッケージでは reusable code を `R/`、テストを `tests/testthat/`、生成元データ処理を `data-raw/` に置く。
- 分析プロジェクトでは raw data、intermediate data、outputs、reports を分ける。
- `.Rprofile` は全員の実行に影響するため最小限にする。自動で package attach や `setwd()` をしない。
- `.gitignore` には `.Rhistory`、`.RData`、secret、巨大な生成物、個人ローカル設定を含める。

## renv

- `renv.lock` があるプロジェクトでは `renv::restore()` を前提にする。
- 依存追加やバージョン変更後は `renv::snapshot()` を検討する。
- `renv::status()` で lockfile と library の差分を確認する。
- システムライブラリが必要な package は README やセットアップ手順に明記する。

## testthat

- テストは Arrange、Act、Assert を分ける。
- 小さな純粋関数からテストする。ファイル、DB、API、時刻、乱数は fixture や mock で制御する。
- `testthat::expect_equal()` は数値誤差を考慮する。浮動小数点に完全一致を要求しない。
- 外部サービス依存は `skip_if_offline()`、環境変数チェック、mock を使う。
- snapshot test は表示が成果物である場合に使う。OS、locale、時刻、乱数で揺れる出力は安定化する。

## パッケージ開発

- `DESCRIPTION` に依存、ライセンス、R バージョン、URL、BugReports を明示する。
- exported function は roxygen2 で引数、返り値、例、エラー条件を説明する。
- `NAMESPACE` は手書きより roxygen2 生成を優先する。
- internal function は export しない。テストで必要な場合も public API を増やしすぎない。
- release 前は `R CMD check .` または `devtools::check()` を実行し、warning/error/note を確認する。

## Shiny

- 小規模なら `app.R`、中規模以上は `ui.R`/`server.R`、module、`R/` に分ける。
- reactive graph を意識する。`reactive()` は値、`observeEvent()` は副作用、`eventReactive()` はイベント駆動の値に使う。
- 入力がそろう前は `req()`、ユーザー向けの検証は `validate()`/`need()` を使う。
- 重い処理は reactive の外で cache するか、非同期/事前計算/DB 側集計を検討する。
- ユーザー入力を SQL、ファイルパス、コード評価に直接渡さない。

## Quarto / R Markdown

- `params` を使うと同じレポートを条件違いで再生成しやすい。
- chunk ごとに `message`、`warning`、`echo`、`cache`、`fig.width`、`fig.height` を意図に合わせる。
- 図表番号、相互参照、caption、alt text を成果物に合わせて整える。
- HTML/PDF/Word で表示差が出るため、最終形式で render して確認する。

## 性能

- まず計測する。`system.time()`、`bench`、`profvis`、`Rprof()` でボトルネックを確認する。
- 反復的な `rbind()`/`c()` で object を伸ばさない。list に貯めて最後に結合する。
- 大規模データでは読み込み列の限定、型指定、DB 側集計、data.table、Arrow などを検討する。
- 並列化は `parallel`、`future`、`furrr` などを使い、乱数、メモリ、worker 初期化、外部接続に注意する。
- C/C++/Python 連携はプロファイル後に導入する。境界のデータ変換コストも測る。

## セキュリティ

- `eval(parse())`、`source()`、`system()` にユーザー入力を渡さない。
- SQL は parameterized query を使う。文字列連結で WHERE 句を作らない。
- ファイル名やパスは許可されたディレクトリ配下に正規化して確認する。
- HTML/Markdown 出力にユーザー入力を混ぜるときは escaping を確認する。
- API key、DB password、個人情報をログ、plot、HTML、cache、RDS に残さない。
- 共有データは最小化、匿名化、アクセス制御、削除手順を用意する。

