# R 統計・機械学習・AI

## シミュレーション

- 乱数を使う処理は `set.seed()` を明示する。並列処理では並列 RNG の扱いも固定する。
- 小さなシミュレーションは `replicate()`、大きな処理は事前確保した vector/data frame、または `purrr`/`future` を使う。
- 分布関数は `r*` が乱数、`d*` が密度/確率、`p*` が累積確率、`q*` が分位点。
- シミュレーション結果は平均だけでなく分布、分位点、失敗率、極端値を確認する。

## モデリング原則

- 学習、検証、テストの分割を最初に固定する。前処理や特徴量選択を全データで fit しない。
- 欠損補完、標準化、カテゴリ処理、ダミー変数化、次元削減は resampling 内で学習する。
- 評価指標は目的に合わせる。回帰は RMSE/MAE/R2、分類は accuracy だけでなく ROC AUC、PR AUC、sensitivity、specificity、calibration を見る。
- 不均衡データでは accuracy が誤解を生む。閾値、コスト、再現率/適合率、base rate を明示する。
- モデル object、前処理 recipe、乱数 seed、学習データ schema、評価結果を一緒に保存する。

## tidymodels

標準的な流れ:

```r
set.seed(123)
split <- rsample::initial_split(data, strata = outcome)
train <- rsample::training(split)
test <- rsample::testing(split)

recipe <- recipes::recipe(outcome ~ ., data = train) |>
  recipes::step_impute_median(recipes::all_numeric_predictors()) |>
  recipes::step_dummy(recipes::all_nominal_predictors())

model <- parsnip::rand_forest(trees = 500) |>
  parsnip::set_engine("ranger") |>
  parsnip::set_mode("classification")

workflow <- workflows::workflow() |>
  workflows::add_recipe(recipe) |>
  workflows::add_model(model)

fit <- parsnip::fit(workflow, data = train)
```

- recipe は前処理の唯一の定義場所にする。別スクリプトで同じ処理を手書きしない。
- resampling は `vfold_cv()`、時系列は時系列用 split を使い、ランダム分割しない。
- tuning では探索空間、metric、seed、parallel 設定を明示する。
- 本番予測では学習時と同じ列名、型、factor levels、欠損処理を保証する。

## AI API 連携

- API key は環境変数から読む。`.Renviron` を使う場合も共有リポジトリに含めない。
- HTTP 呼び出しは `httr2` などで timeout、retry、status handling、rate limit を明示する。
- LLM 出力を後続処理に渡す場合は JSON schema、型検証、欠損時の fallback を用意する。
- prompt は文字列連結で散らさず、関数またはテンプレートとして管理する。入力データと指示を分離する。
- ログには request id、model、latency、token usage、エラー種別を残し、prompt 内の個人情報や secret は出さない。
- RAG では chunking、metadata、embedding model、index 更新、検索件数、reranking、引用根拠の扱いを明示する。
- agent や複雑な tool calling 設計は AI 系スキルも併用する。

## 品質評価

- 統計モデルは holdout/resampling の指標、LLM 機能は golden set と失敗例で評価する。
- データや prompt の変更で結果が変わる前提を置き、回帰テストや評価レポートを残す。
- 外部 API を使うテストは通常テストから分ける。録画、mock、skip 条件、低コスト smoke test を使い分ける。

