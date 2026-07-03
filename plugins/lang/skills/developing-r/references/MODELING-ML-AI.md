# R 機械学習・AI 連携

`tidymodels` を軸にした機械学習ワークフローと、`httr2` / `ellmer` による LLM・埋め込み API 連携、RAG 実装、品質評価を扱う。統計・確率・分布・シミュレーション寄りの基礎指針は `STATISTICS.md` を参照。

## 貫く原則

- 学習・検証・テストの分割は**最初の一手**として固定し、以降テストセットに触れない。前処理・特徴量選択は全データで fit せず、欠損補完・標準化・カテゴリ処理・次元削減はすべて resampling 内で学習させる。
- 評価指標は目的に合わせる。回帰は RMSE/MAE/R^2、分類は accuracy 単独でなく ROC AUC・PR AUC・sensitivity・specificity・calibration を見る。不均衡データでは accuracy が誤解を生むため閾値・コスト・base rate を明示する。
- モデル object・前処理 recipe・乱数 seed・学習データ schema・評価結果は **1 つの成果物として一緒に保存**する。
- LLM 出力を後続処理に渡す前に JSON schema 検証・型チェック・fallback を用意する。API key はコードに書かず環境変数から読む。

---

## データ分割とデータリーケージ防止

機械学習で最も重篤なミスはデータリーケージ（テストデータの情報が学習に漏れること）。分割を固定してからは、テストセットを最終評価の 1 回以外で触らない。

```r
library(tidymodels)

set.seed(42)
# strata で目的変数の分布を層化抽出に反映する
split <- initial_split(data, prop = 0.8, strata = outcome)
train <- training(split)   # 80%: 学習・チューニング専用
test  <- testing(split)    # 20%: 最終評価のみ。途中経過では使わない

# 訓練セット内で k-fold CV を作る（ハイパーパラメータ探索用）
folds <- vfold_cv(train, v = 5, strata = outcome)
```

**落とし穴**

- 分割前に全データで欠損補完や標準化を行うと訓練/テストの境界を超えて情報が流入する。前処理は必ず `recipe()` に閉じ込め、resampling 内で fit させる。
- 時系列データをランダム分割すると「未来のデータで過去を予測する」形になる。`initial_time_split()` と時系列用の resampling（`sliding_period()` / `rolling_origin()`）を使う。
- テストの accuracy を見て再チューニングすると実質的にテストへ overfit する。チューニングは CV のみで行い、テストは最後の `last_fit()` 1 回で触る。

---

## tidymodels の標準フロー

| ステップ | パッケージ | 主要関数 |
|---------|-----------|---------|
| 分割 | rsample | `initial_split()`, `vfold_cv()` |
| 前処理定義 | recipes | `recipe()`, `step_*()` |
| モデル仕様 | parsnip | `rand_forest()`, `linear_reg()` など |
| バンドル | workflows | `workflow()`, `add_recipe()`, `add_model()` |
| チューニング | tune | `tune_grid()`, `select_best()`, `finalize_workflow()` |
| 最終評価 | tune + yardstick | `last_fit()`, `collect_metrics()` |

recipe は前処理の唯一の定義場所にする（別スクリプトで同じ処理を手書きしない）。tuning では探索空間・metric・seed・parallel 設定を明示する。本番予測では学習時と同じ列名・型・factor levels・欠損処理を保証する。

### 完全なワークフロー例（ランダムフォレスト分類）

```r
library(tidymodels)

set.seed(42)
split <- initial_split(churn_data, prop = 0.8, strata = churned)
train <- training(split)
test  <- testing(split)
folds <- vfold_cv(train, v = 5, strata = churned)

# --- Recipe（前処理）: train のみを見て定義する ---
rec <- recipe(churned ~ ., data = train) |>
  step_impute_median(all_numeric_predictors()) |>
  step_impute_mode(all_nominal_predictors()) |>
  step_mutate(tenure_log = log1p(tenure)) |>       # 特徴量エンジニアリング
  step_dummy(all_nominal_predictors()) |>
  step_normalize(all_numeric_predictors()) |>
  step_nzv(all_predictors())                        # 分散ゼロに近い列を除去

# --- モデル仕様（parsnip）---
rf_spec <- rand_forest(mtry = tune(), trees = 500, min_n = tune()) |>
  set_engine("ranger", importance = "impurity") |>
  set_mode("classification")

# --- Workflow でバンドル ---
wf <- workflow() |>
  add_recipe(rec) |>
  add_model(rf_spec)

# --- ハイパーパラメータ探索（tune）---
set.seed(99)
tuned <- tune_grid(
  wf,
  resamples = folds,
  grid      = 15,                                   # ランダムに 15 通り探索
  metrics   = metric_set(roc_auc, accuracy)
)

collect_metrics(tuned)                              # 全候補の CV 結果
autoplot(tuned)                                     # 探索結果を可視化

best_params <- select_best(tuned, metric = "roc_auc")
final_wf    <- finalize_workflow(wf, best_params)

# --- 最終評価（last_fit が train 全体で fit → test で 1 回だけ評価）---
final_fit <- last_fit(final_wf, split)
collect_metrics(final_fit)                          # test 上の roc_auc, accuracy
collect_predictions(final_fit) |>
  conf_mat(truth = churned, estimate = .pred_class)

# --- デプロイ用に fit 済み workflow を取り出す ---
fitted_wf <- extract_workflow(final_fit)            # predict() に使える
```

---

## Recipe のよく使う step

```r
recipe(outcome ~ ., data = train) |>
  step_impute_median(all_numeric_predictors()) |>   # 数値: 中央値補完
  step_impute_mode(all_nominal_predictors()) |>     # カテゴリ: 最頻値補完
  step_impute_knn(col1, neighbors = 5) |>           # KNN 補完
  step_mutate(ratio = x / y) |>                     # 特徴量生成
  step_date(order_date, features = c("dow", "month")) |>
  step_log(skewed_col, base = 10) |>                # 歪んだ分布を対数変換
  step_normalize(all_numeric_predictors()) |>       # 平均0・分散1
  step_other(cat_col, threshold = 0.05) |>          # 出現率5%未満を "other" に集約
  step_dummy(all_nominal_predictors()) |>           # one-hot（基準水準は落とす）
  step_nzv(all_predictors()) |>                     # near-zero variance を除去
  step_corr(all_numeric_predictors(), threshold = 0.9)  # 高相関ペアを除去
```

`workflow()` を使う場合、recipe の `prep()`（学習）と `bake()`（適用）は fit/predict の際に自動化される。workflow を使わず手動で扱うときは `prep(rec, training = train)` で学習し、`bake(prepped, new_data = test)` で変換、`bake(prepped, new_data = NULL)` で学習済み訓練データを取り出す。

**順序の注意**: `step_dummy()` の前に `step_impute_mode()` / `step_other()` を置く。`step_normalize()` はダミー化後の数値列にも掛かるため、必要に応じて `step_normalize(all_numeric_predictors(), -starts_with("cat_"))` で対象を絞る。

---

## 代表的なモデル仕様（parsnip）

### 線形・正則化回帰・ロジスティック回帰（glmnet）

`mixture` は L1/L2 の混合比（1=LASSO, 0=Ridge, tune で Elastic Net）。glmnet 系は入力スケールに敏感なので recipe に `step_normalize()` を必ず入れる。

```r
lm_spec    <- linear_reg() |> set_engine("lm")                                     # OLS
enet_spec  <- linear_reg(penalty = tune(), mixture = tune()) |> set_engine("glmnet")  # Elastic Net
log_spec   <- logistic_reg(penalty = tune(), mixture = 1) |>                        # 二値分類（LASSO）
  set_engine("glmnet") |> set_mode("classification")

# 予測（fit 済み workflow に対して）
preds <- predict(fitted_wf, test, type = "class")   # .pred_class
probs <- predict(fitted_wf, test, type = "prob")     # .pred_<level> 列が生成される
```

### ランダムフォレスト（ranger）

```r
rf_spec <- rand_forest(
  mtry  = tune(),   # 各分岐で試す変数数（分類は sqrt(p)、回帰は p/3 が目安）
  trees = 500,
  min_n = tune()    # 葉の最小サンプル数
) |>
  set_engine("ranger", importance = "impurity") |>
  set_mode("classification")  # or "regression"

# 特徴量重要度を可視化
fitted_wf |> extract_fit_parsnip() |> vip::vip(num_features = 20)
```

### XGBoost・KNN・決定木

```r
xgb_spec <- boost_tree(trees = tune(), tree_depth = tune(), learn_rate = tune(),
                       mtry = tune(), loss_reduction = tune(), sample_size = tune()) |>
  set_engine("xgboost") |> set_mode("classification")   # or "regression"

knn_spec <- nearest_neighbor(neighbors = tune(), weight_func = "rectangular") |>
  set_engine("kknn") |> set_mode("classification")       # step_normalize() 必須

dt_spec  <- decision_tree(cost_complexity = tune(), tree_depth = tune()) |>
  set_engine("rpart") |> set_mode("classification")
```

XGBoost は探索次元が多いので `grid_latin_hypercube()` や `tune_bayes()` で効率化し、学習率を下げるほど `trees` を増やす。KNN はスケールに敏感なので `step_normalize()` を欠かさない。

---

## 評価指標（yardstick）

`augment()` で予測列（`.pred` / `.pred_class` / `.pred_<level>`）を元データに付与してから指標を計算するのが定石。

### 回帰指標

```r
results <- augment(fitted_wf, new_data = test)

rmse(results, truth = price, estimate = .pred)   # 二乗平均平方根誤差
mae(results,  truth = price, estimate = .pred)   # 平均絶対誤差
rsq(results,  truth = price, estimate = .pred)   # 決定係数 R^2

# まとめて計算
reg_metrics <- metric_set(rmse, mae, rsq)
reg_metrics(results, truth = price, estimate = .pred)
```

### 分類指標

二値分類では `event_level` で陽性クラスを指定する（既定は factor の最初の水準 = `"first"`）。確率指標には確率列を、ラベル指標には `.pred_class` を渡す。

```r
results <- augment(fitted_wf, new_data = test)  # .pred_class, .pred_yes, .pred_no を含む

# ラベルが必要な指標
accuracy(results,    truth = churned, estimate = .pred_class)
sensitivity(results, truth = churned, estimate = .pred_class, event_level = "second")
specificity(results, truth = churned, estimate = .pred_class, event_level = "second")
precision(results,   truth = churned, estimate = .pred_class, event_level = "second")
recall(results,      truth = churned, estimate = .pred_class, event_level = "second")

# 確率が必要な指標
roc_auc(results, truth = churned, .pred_yes, event_level = "second")   # ROC AUC
pr_auc(results,  truth = churned, .pred_yes, event_level = "second")   # PR AUC（不均衡時に有効）

# 混同行列
conf_mat(results, truth = churned, estimate = .pred_class) |> autoplot(type = "heatmap")

# 確率指標とラベル指標を混在させてまとめて算出
cls_metrics <- metric_set(accuracy, sensitivity, specificity, roc_auc, pr_auc)
cls_metrics(results, truth = churned, .pred_yes,
            estimate = .pred_class, event_level = "second")
```

チューニング時は `tune_grid(..., metrics = metric_set(roc_auc, pr_auc, accuracy))` のように最適化対象を明示する。`select_best()` に渡す `metric` はこの中から選ぶ。

---

## 不均衡データへの対処

accuracy は不均衡時に誤解を招く。陽性クラスが 3% のデータで全件陰性と予測しても accuracy は 97% になる。

```r
library(themis)   # install.packages("themis")

rec_balanced <- recipe(fraud ~ ., data = train) |>
  step_impute_median(all_numeric_predictors()) |>
  step_dummy(all_nominal_predictors()) |>
  step_normalize(all_numeric_predictors()) |>
  step_smote(fraud, over_ratio = 0.5)             # 少数クラスを合成（SMOTE）
  # 代替: step_rose(fraud) / step_downsample(fraud, under_ratio = 1)
```

**重要**: サンプリング系 step（`step_smote` 等）は `skip = TRUE` が既定で、`bake(new_data)` や predict 時には適用されない（学習時のみ）。この設計により本番の予測分布を歪めない。評価は **PR AUC / F1 / sensitivity** を主指標にする。

分類閾値（既定 0.5）は業務コストに合わせて調整できる。

```r
# Precision-Recall 曲線で閾値の効きを見る
collect_predictions(final_fit) |>
  pr_curve(truth = fraud, .pred_yes, event_level = "second") |>
  autoplot()

# 閾値を手動で変える（陽性を取りこぼしたくない → 低めに設定）
lv <- levels(results$fraud)
results <- results |>
  mutate(.pred_custom = factor(if_else(.pred_yes > 0.3, lv[2], lv[1]), levels = lv))
```

---

## クラスタリング（k-means）

k-means はスケールに敏感なので必ず正規化してから実行する。`nstart` で初期値を複数試し、elbow 法で `k` を選ぶ。

```r
customer_scaled <- customer_data |> select(where(is.numeric)) |> scale()

# elbow 法: within-cluster SS の減少が鈍る k を選ぶ
wss <- purrr::map_dbl(1:10, \(k) kmeans(customer_scaled, centers = k, nstart = 25)$tot.withinss)
plot(1:10, wss, type = "b", xlab = "k", ylab = "within-cluster SS")

set.seed(42)
km <- kmeans(customer_scaled, centers = 4, nstart = 25)
customer_data$cluster <- factor(km$cluster)

# クラスタ別のプロファイリング
customer_data |> group_by(cluster) |> summarise(across(where(is.numeric), mean), n = n())
```

---

## モデル・前処理・メタデータの保存

モデル単体でなく、前処理・seed・評価結果・列名までを 1 つの bundle として保存する。再現性と本番投入時の schema チェックに使う。

```r
model_version <- paste0("v", format(Sys.Date(), "%Y%m%d"))
model_bundle <- list(
  workflow   = fitted_wf,                              # fit 済み workflow（recipe を内包）
  version    = model_version,
  metrics    = collect_metrics(final_fit),             # test 評価結果
  features   = extract_recipe(final_fit) |> summary(), # 学習時の変数一覧・役割
  seed       = 42,
  trained_on = Sys.time()
)
saveRDS(model_bundle, sprintf("models/model_bundle_%s.rds", model_version))

bundle    <- readRDS(sprintf("models/model_bundle_%s.rds", model_version))
new_preds <- predict(bundle$workflow, new_data = new_df)
```

`workflow` は recipe を内包するため、これ 1 つで前処理と予測が完結する。前処理を別管理にすると本番でズレる。

---

## httr2 で LLM API を呼ぶ

### API キーの管理

```r
# .Renviron に記載（共有リポジトリに含めない）
#   OPENAI_API_KEY=sk-...
#   ANTHROPIC_API_KEY=sk-ant-...
usethis::edit_r_environ()        # エディタで開く → 保存後に R を再起動
Sys.getenv("OPENAI_API_KEY")     # 読み出し
```

### timeout / retry / rate limit を備えた呼び出し

```r
library(httr2)

call_llm <- function(prompt,
                     model   = "gpt-4o-mini",
                     timeout = 30,
                     max_try = 3) {
  api_key <- Sys.getenv("OPENAI_API_KEY")
  if (!nzchar(api_key)) stop("OPENAI_API_KEY が未設定")

  request("https://api.openai.com/v1/chat/completions") |>
    req_headers(Authorization = paste("Bearer", api_key)) |>
    req_body_json(list(
      model      = model,
      messages   = list(list(role = "user", content = prompt)),
      max_tokens = 512
    )) |>
    req_timeout(timeout) |>
    req_retry(
      max_tries    = max_try,
      is_transient = \(resp) resp_status(resp) %in% c(429, 500, 503),
      backoff      = \(i) 2 ^ i                       # 指数バックオフ
    ) |>
    req_perform() |>
    resp_body_json() |>
    (\(r) r$choices[[1]]$message$content)()
}
```

`req_retry()` の `is_transient` で 429（Rate Limit）や 5xx のみを再試行対象に絞るのが重要。`req_body_json()` は `Content-Type: application/json` を自動付与するのでヘッダーに手書きしない。

### rate limit 対応と memoise キャッシュ

`Sys.sleep()` で呼び出し間隔を空けてレート制限を回避し、`memoise` で同一入力の重複コールをキャッシュする。

```r
library(memoise)
safe_classify   <- function(text) { Sys.sleep(0.3); call_llm(paste("Classify sentiment:", text)) }
classify_cached <- memoise(safe_classify)
results         <- purrr::map_chr(reviews$text, classify_cached)
```

ログには request id・model・latency・token usage・エラー種別を残し、prompt 内の個人情報や secret は出さない。

---

## プロンプトの関数化（RCTF パターン）

プロンプトは文字列連結で散らさず関数として管理し、指示と入力データを分離する。再現性とレビュー容易性が上がる。

```r
build_prompt <- function(role, context, task, format = NULL, constraint = NULL) {
  parts <- c(
    paste("ROLE:", role),
    paste("CONTEXT:", context),
    paste("TASK:", task)
  )
  if (!is.null(format))     parts <- c(parts, paste("FORMAT:", format))
  if (!is.null(constraint)) parts <- c(parts, paste("CONSTRAINT:", constraint))
  paste(parts, collapse = "\n")
}

prompt <- build_prompt(
  role       = "You are a senior data analyst expert in retail analytics.",
  context    = paste("Monthly sales data:", jsonlite::toJSON(sales_summary, auto_unbox = TRUE)),
  task       = "Identify the 3 most significant trends.",
  format     = 'Return a JSON array: [{trend, explanation, impact_level}]',
  constraint = "Each explanation under 50 words. No filler."
)
call_llm(prompt)
```

Few-shot は入出力例（`"Input: age = -5\nOutput: impossible_value"` のような正解ペア）をプロンプトに数個並べ、最後に `paste("Input:", new_value), "Output:"` を継ぎ足してタスクの型を示す。

---

## JSON 出力の検証とフォールバック

LLM 出力は不正 JSON や欠損フィールドを含みうる前提で扱う。パース失敗時のリトライと schema 検証を必ず入れる。

```r
library(ellmer)
library(jsonlite)

extract_structured <- function(review_text) {
  chat <- chat_openai(
    model         = "gpt-4o-mini",
    system_prompt = paste(
      "You extract structured data from customer reviews.",
      "Always return valid JSON. No markdown fences. No preamble.",
      "Schema: {sentiment, rating_out_of_5, main_issue, resolution_needed}"
    )
  )
  raw <- chat$chat(paste("Extract from this review:", review_text))

  # パース失敗時は「JSON のみ返せ」と一度だけ再要求する
  tryCatch(fromJSON(raw),
           error = function(e) fromJSON(chat$chat("Return ONLY valid JSON, nothing else.")))
}

results <- purrr::map(reviews$text, extract_structured) |> dplyr::bind_rows()
```

schema 検証は `setdiff(expected_fields, names(parsed))` で必須フィールドの欠損を検出し、欠けていれば無効として扱う（後続処理に不完全なデータを流さない）。

---

## ellmer パッケージ（R ネイティブ LLM インターフェース）

`ellmer` はマルチプロバイダ対応のチャット抽象化。tool（function calling）や構造化出力を R らしく扱える。`register_tool()` で登録した R 関数はモデルが必要時に自律的に呼ぶ。

```r
library(ellmer)

chat <- chat_openai(
  model         = "gpt-4o-mini",
  system_prompt = "You are a helpful R programming tutor. Always give code examples."
)
chat$chat("How do I calculate a rolling average in R?")

chat$register_tool(tool(
  name        = "summarize_column",
  description = "Get summary stats for a named column in the sales dataset",
  arguments   = list(column_name = type_string("Name of the column")),
  .f = function(column_name) {
    if (!column_name %in% names(sales)) return("Column not found")
    summary(sales[[column_name]]) |> as.list() |> jsonlite::toJSON(auto_unbox = TRUE)
  }
))
chat$chat("What is the average revenue and how does it vary by region?")
```

---

## 埋め込み（Embeddings）とセマンティック検索

埋め込みは 1 回計算してキャッシュし、以降は類似度計算のみ行う。キーワード一致では拾えない言い換え（"refund not processed" ⇄ "payment not returned"）を検索できる。

```r
library(httr2)

get_embedding <- function(text, model = "text-embedding-3-small") {
  request("https://api.openai.com/v1/embeddings") |>
    req_headers(Authorization = paste("Bearer", Sys.getenv("OPENAI_API_KEY"))) |>
    req_body_json(list(input = text, model = model)) |>
    req_timeout(20) |>
    req_perform() |>
    resp_body_json() |>
    (\(r) unlist(r$data[[1]]$embedding))()
}

cosine_sim <- function(a, b) sum(a * b) / (sqrt(sum(a^2)) * sqrt(sum(b^2)))

# インデックスを 1 回だけ構築してキャッシュ
ticket_embeddings <- purrr::map(support_tickets$description, get_embedding)

semantic_search <- function(query, top_k = 5) {
  q_vec <- get_embedding(query)
  sims  <- purrr::map_dbl(ticket_embeddings, \(e) cosine_sim(q_vec, e))
  support_tickets |>
    dplyr::mutate(similarity = sims) |>
    dplyr::slice_max(similarity, n = top_k)
}
```

---

## RAG（Retrieval-Augmented Generation）

検索で得た文脈だけを根拠にさせ、根拠外は「わからない」と答えさせることでハルシネーションを抑える。chunk 化 → 埋め込み → 類似度検索 → 根拠付き生成の 4 段構成。

```r
# Step 1: chunk 化してインデックス構築（前掲の get_embedding / cosine_sim を再利用）
chunk_text <- function(text, chunk_size = 500) {
  words  <- strsplit(text, " ")[[1]]
  groups <- split(words, ceiling(seq_along(words) / chunk_size))
  vapply(groups, paste, character(1), collapse = " ")
}
all_chunks       <- unlist(purrr::map(documents$text, chunk_text))
chunk_embeddings <- purrr::map(all_chunks, get_embedding)

# Step 2: 検索 → Step 3: 根拠を与えて生成
rag_answer <- function(question, top_k = 3) {
  q_vec   <- get_embedding(question)
  sims    <- purrr::map_dbl(chunk_embeddings, \(e) cosine_sim(q_vec, e))
  context <- all_chunks[order(sims, decreasing = TRUE)[seq_len(top_k)]]
  prompt  <- paste(
    "Answer ONLY using the provided context.",
    "If the answer is not in the context, say you don't know.",
    "Context:", paste(context, collapse = "\n\n---\n\n"),
    "Question:", question,
    sep = "\n"
  )
  chat_openai(model = "gpt-4o-mini")$chat(prompt)
}
```

RAG 設計で明示すべき項目: chunk サイズ・オーバーラップ、メタデータ（ソース/日付）、embedding モデル、インデックス更新タイミング、top-K 件数、reranking の有無、引用根拠の出力形式。件数が増えたら線形探索でなくベクトル DB を検討する。

### embedding × k-means でトピッククラスタリング

embedding リストを `do.call(rbind, ...)` で行列化し `kmeans()` に渡すと、テキストを内容ベースでクラスタリングできる。各クラスタから代表サンプルを数件抜き出し `call_llm()` に「3 語で命名せよ」と投げれば、クラスタ名も自動生成できる。

```r
emb_matrix <- do.call(rbind, ticket_embeddings)   # embedding リスト → 行列
set.seed(42)
km <- kmeans(emb_matrix, centers = 5, nstart = 25)
support_tickets$cluster <- factor(km$cluster)
```

---

## AI 呼び出しのコスト管理

コストは `トークン数 × 行数 / 1e6 × 単価` で概算する（単価は都度確認）。削減策: (1) 軽いタスクは小さいモデル、(2) 長い入力を truncate、(3) system_prompt を短く保つ、(4) `max_tokens` でレスポンス長を制限、(5) `memoise` でキャッシュ、(6) 大量処理前に小サンプルで動作とコストを確認する。

---

## 品質評価とレビュー観点

- 統計モデルは holdout/resampling の指標で、LLM 機能は golden set（正解付きの代表例）と既知の失敗例で評価する。
- データや prompt の変更で結果が変わる前提を置き、回帰テスト・評価レポートを残す。
- 外部 API を叩くテストは通常テストから分離する。録画（httptest2 等）・mock・skip 条件・低コスト smoke test を使い分け、CI で毎回課金しない。

### よくある落とし穴チェックリスト

| 落とし穴 | 対策 |
|---------|------|
| 全データで前処理を fit | `recipe()` に閉じ込め resampling 内で fit |
| テストで繰り返しチューニング | CV のみでチューニング、test は `last_fit()` で 1 回だけ |
| 時系列をランダム分割 | `initial_time_split()` / 時系列用 resampling を使う |
| 不均衡データで accuracy 主指標 | PR AUC / F1 / sensitivity を主指標にする |
| `event_level` 未指定で陽性を取り違え | 二値分類は `event_level` を明示する |
| API キーをコードに直書き | `.Renviron` + `Sys.getenv()` で読む |
| LLM 出力を無検証で後続処理へ | JSON schema 検証・型チェック・fallback を用意 |
| 大量 API コールを事前テストしない | 小サンプルで動作とコストを確認してから実行 |
| モデルだけ保存し前処理を別管理 | `workflow`（recipe 内包）を bundle でセット保存 |
| RAG の引用根拠を管理しない | chunk にメタデータを付与し回答にソースを含める |
