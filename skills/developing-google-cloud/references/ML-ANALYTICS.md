# ML-ANALYTICS: Google Cloud ML・高度分析リファレンス

BigQuery GIS・BigQuery ML・Vertex AI・学習済みAPI・AutoMLを網羅したGoogle Cloud機械学習ガイド。

---

## 1. Google Cloud ML概要

### 1.1 MLサービスの3層構造

Google Cloudの機械学習サービスは大きく2つに分類される。

| 分類 | 概要 |
|------|------|
| **AIビルディングブロック** | MLモデルを簡単に利用または開発できる機能群 |
| **Vertex AI** | カスタムMLモデルの開発・運用（MLOps）を助ける統合プラットフォーム |

AIビルディングブロックはさらに以下の2種類に分かれる。

| サービス | 説明 |
|---------|------|
| **学習済みAPI** | Googleが事前学習済みのMLモデルをそのままAPIとして利用 |
| **AutoML** | ユーザーのカスタムデータを使って自動でMLモデルを生成 |

### 1.2 データタイプ別サービスマップ

|             | 非構造化データ（言語） | 非構造化データ（音声） | 非構造化データ（視覚） | 構造化データ |
|-------------|------|------|------|------|
| **学習済みAPI** | Natural Language API、Translation API | Speech-to-Text API、Text-to-Speech API | Vision API | Inference API、Recommendations AI |
| **AutoML** | AutoML Natural Language、AutoML Translation | — | AutoML Vision、AutoML Video Intelligence | AutoML Tables |

### 1.3 MLサービスの選択フロー

```
特定領域のデータ or カスタムタスク？
├── No  → 学習済みAPI（Googleのチューニング済みモデルを活用）
└── Yes → 非構造化データ？
          ├── Yes → コーディング不要で開発？
          │         ├── Yes → AutoML（言語・音声・視覚）
          │         └── No  → 独自コーディング（TensorFlow等）
          └── No  → コーディング不要で開発？
                    ├── Yes → AutoML Tables
                    └── No  → 独自コーディング or BigQuery ML
```

---

## 2. 学習済みAPI

### 2.1 共通の基本仕様

- **認証**: サービスアカウント推奨
- **インターフェース**: REST / gRPC
- **クライアントライブラリ**: C#、Go、Java、Node.js、PHP、Python、Ruby
- **入力データ**: Cloud StorageのURIまたはHTTP(S)アクセス可能なURL
- **出力**: JSON形式

### 2.2 Cloud Natural Language API

テキストデータの構造・意味を解析する。

| 機能 | 説明 |
|------|------|
| 構文解析 | テキストを文・トークンに分解。形態素・POS・依存関係ツリーを出力 |
| エンティティ分析 | テキストからエンティティ（名詞・固有名詞）を抽出 |
| 感情分析 | テキストの感情方向（-1.0〜1.0）と強度（0.0〜）を数値化 |
| エンティティ感情分析 | エンティティに対する感情のポジティブ/ネガティブを判定 |
| コンテンツ分類 | テキストのカテゴリを判定し信頼度を出力 |

### 2.3 Cloud Translation API

ニューラル機械翻訳（NMT）モデルで100以上の言語に対応。

| エディション | 特徴 |
|---------|------|
| Basic (v2) | 言語検出・NMT翻訳 |
| Advanced (v3) | AutoMLモデル利用・ドキュメント翻訳・用語集・Cloud Storage一括翻訳 |

新規利用はAdvancedを推奨。

### 2.4 Cloud Speech-to-Text API

音声データをテキストに変換。125以上の言語・方言に対応。

| 認識方法 | 特徴 | 制限 |
|---------|------|------|
| 同期認識 | 全音声処理後に結果返却 | 1分以内 |
| 非同期認識 | ポーリングで結果取得 | 480分以内 |
| ストリーミング認識 | リアルタイムキャプチャ | gRPCのみ |

### 2.5 Cloud Text-to-Speech API

テキストを音声に変換。40以上の言語・方言、220種類以上の音声に対応。

- **標準**: 通常の音声合成
- **WaveNet**: DeepMind技術による自然な発話（割高）
- **カスタム音声**: ユーザー録音データから独自音声を合成

### 2.6 Cloud Vision API

画像データを解析して情報抽出・分類を行う。

| 機能 | 説明 |
|------|------|
| 顔検出 | 顔の位置・感情状態（喜び/怒り/驚き）を出力 |
| ランドマーク検出 | 自然・人工のランドマークを検出 |
| ロゴ検出 | 商品ロゴ・企業ロゴを検出 |
| ラベル検出 | 画像内エンティティのラベルと信頼度を出力 |
| テキスト検出 | OCRでテキスト・手書き文字を検出 |
| オブジェクト検出 | 複数オブジェクトのラベルと位置情報を出力 |
| 不適切コンテンツ検出 | adult/spoof/medical/violence/racyカテゴリで評価 |

### 2.7 Cloud Video Intelligence API

動画コンテンツを解析して情報抽出・分類を行う。

| 機能 | 説明 |
|------|------|
| オブジェクトトラッキング | 複数エンティティを追跡しラベル・位置を出力 |
| ラベル検出 | フレーム全体に対してラベルを付与 |
| 人の検出 | 人物の存在と位置情報を出力 |
| テキスト検出 | 動画内テキスト・手書き文字をOCR検出 |
| ショット変更検出 | カメラショットの切り替わりを検知 |
| 音声文字変換 | 動画内音声をテキストに変換 |

---

## 3. AutoML

### 3.1 概要と特徴

AutoMLはユーザーが独自カスタムMLモデルを簡単に開発できるサービス。ユーザーのデータセットを入力すると、AutoMLが自動でデータセットを分割・学習・評価してカスタムMLモデルを生成する。

**精度を高めるためにユーザーが注力すべき点**: データセットの品質（偏りのないデータ収集と正確なアノテーション）。

### 3.2 サービス利用フロー

```
① データセット作成
   → AutoMLにデータをロード・アノテーション付与

② 学習の実行
   → 学習用/評価用データの分割も自動実行
   → 評価結果参照後に再学習で精度向上も可能

③ モデルのデプロイ
   → クラウドまたはEdgeにデプロイ

④ 予測の実行
   → オンライン予測（個別リクエスト）
   → バッチ予測（大量データ）
```

### 3.3 AutoML Natural Language

テキストデータを解析するカスタムMLモデルを作成。

| 機能 | 学習データ要件 |
|------|---------|
| テキスト分類（単一/複数ラベル） | テキストデータ + 分類ラベル |
| 感情分析 | テキスト + 感情スコア数値 |
| エンティティ抽出 | JSONL形式のアノテーション付きテキスト |

### 3.4 AutoML Translation

特定業務ドメインや社内用語を含む専門文書の翻訳モデルを作成。学習データはTSV形式のソース言語・ターゲット言語対応テキスト。BLEUスコアで翻訳品質を評価。

### 3.5 AutoML Vision

画像データを分析して情報抽出・分類を行う。

| 機能 | 説明 |
|------|------|
| ラベル分類 | 自社独自ラベルで画像を分類 |
| オブジェクト検出 | 独自ラベルでオブジェクトを検出 |

**AutoML Vision Edge**: スマートフォン・スマート家電等のEdgeにMLモデルをデプロイ。TensorFlow Liteでエクスポート可能。予測実行時のクラウド通信不要で高速化。

### 3.6 AutoML Tables

構造化データ（テーブル形式）に対するカスタムMLモデルを生成。

| 機能 | 説明 |
|------|------|
| 分類 | データのカテゴリを予測 |
| 回帰 | 時系列に変化する値を予測 |

---

## 4. Vertex AI

### 4.1 Vertex AIの全体像

MLの工程をエンドツーエンドでサポートする統合プラットフォーム。MLOpsをサポートし本番活用を可能にする。AutoMLを統合しており、開発方法はAutoMLと独自コーディングを選択できる。

**MLライフサイクルの工程別機能**:

| 工程 | 機能 |
|------|------|
| **データ準備** | DataSets、Data Labeling Service、Feature Store |
| **開発** | Workbench（JupyterLabベース） |
| **学習・評価・実行** | Training、Model、End Point、Batch Prediction |
| **運用** | Vertex AI Pipelines、Vertex ML Metadata |

### 4.2 Feature Store

特徴量（Feature）データを管理し、学習・予測環境に提供するサービス。

**解決する課題**:
- 特徴量の属人化・共有不足
- 本番環境に見合った速度・品質での特徴量提供不足
- 学習時と実行時の特徴量のずれ（ドリフト）

**主要機能**:
- 特徴量リポジトリ（組織内での検索・共有・再利用）
- オンラインサービング（低レイテンシーでの特徴量提供）
- ドリフト監視（学習から本番実行間のデータ変化を検知）

### 4.3 Workbench

機械学習の統合開発環境（IDE）。JupyterLabノートブックをベース。

| モード | 特徴 |
|--------|------|
| マネージドノートブック | Cloud Storageとの統合。BigQueryのデータを直接参照・クエリ実行可能。Executorでジョブ化 |
| ユーザー管理ノートブック | 細かく制御が可能 |

### 4.4 Training・Model・Endpoint・Batch Prediction

**学習方法の選択**:
- AutoML統合による自動学習
- 独自コーディング + Vertex Vizierでハイパーパラメーターチューニング（最適化アルゴリズム、学習率、正則化パラメーター、DNN隠れ層数など）

**モデルのデプロイ**:
- **標準**: REST API。AutoMLモデル・独自コードモデル両方対応
- **プライベート**: プライベートサービスアクセス経由。独自コードモデル・テーブル形式モデルのみ

**Continuous model monitoring**: デプロイモデルのパフォーマンスを継続的に監視。特徴量ドリフトによる性能低下を検知してアラート送信。

**Batch Prediction**: Cloud StorageまたはBigQueryのデータをソースとして指定。出力形式はBigQueryテーブル・CSVファイル・JSONLファイルから選択。

### 4.5 Vertex AI Pipelines

MLの各工程をコンポーネント化し、パイプライン（ワークフロー）として管理・自動化するサービス。

**対応フレームワーク**:
- TensorFlow Extended (TFX)
- Kubeflow Pipelines

**パイプライン構成**:
```
データ抽出 → データ検証 → データ前処理 → モデル学習 →
モデル評価 → モデル検証 → モデルデプロイ → 予測実行 →
予測結果評価 → 継続的モデル監視 → フィードバック
```

### 4.6 Vertex ML Metadata

MLシステム全体のメタデータ・アーティファクト（データセット・モデル・ログ）・実行ステップを自動トラッキング。学習に使用したデータの追跡（コンプライアンス対応）や同一データでの再学習を容易にする。

---

## 5. BigQuery ML

### 5.1 BigQuery MLの特徴とメリット

BigQuery上でSQLの拡張構文を使い、機械学習のモデル構築から予測までを実行する機能。

**最大の特徴**: すべての処理がSQLから実行可能。BigQueryにデータを残したままMLを実行できる。

**主なメリット**:
- データの移動コストが不要
- サービス環境（推論インフラ）を意識する必要がない
- データパイプライン（Dataform、Composer）と統合しやすい
- 探索的データ分析（EDA）から機械学習まで一気通貫

### 5.2 BigQuery MLとVertex AIの関係性

補完関係にあり、双方を組み合わせることでより実践的な環境を構築できる。

| 観点 | BigQuery ML | Vertex AI |
|------|-------------|-----------|
| インターフェース | SQLベース | API・SDK経由 |
| データ連携 | BigQueryからシームレス | 別途データ連携が必要 |
| 周辺ツール | 可視化・BIとの連携が充実 | ノートブック・モデル管理が充実 |
| 利用単位 | テーブル単位で統合的 | 機能ごとのコンポーネント単位 |

**連携ユースケース例**:
- Vertex AIの生成AIAPIで非構造データを構造化 → BigQueryで後続分析
- BigQuery MLで学習したモデルをVertex AI Model Registryに登録 → Vertex AIでオンラインサービス
- Vertex AI Workbench（Colab Enterprise）からBigQueryデータにアクセスして基礎分析〜ML

### 5.3 サポートするモデル一覧

| タスク | 典型的なユースケース | サポートモデル |
|--------|------|------|
| 予測 | 需要予測、購買確率予測 | 線形回帰、ロジスティック回帰、ブーストツリー、時系列予測（ARIMA）、DNN |
| 分類 | 優良顧客判別 | ロジスティック回帰、ブーストツリー、DNN |
| クラスタリング | 属性が似たユーザーの分類 | K-means |
| 行列分解 | 商品レコメンデーション | Matrix Factorization |
| 次元削減 | データの可視化 | 主成分分析（PCA） |
| 時系列 | 商品の需要予測 | ARIMA |

### 5.4 2項ロジスティック回帰による分類（実践例）

#### モデルの構築

```sql
-- ロジスティック回帰のモデル構築
CREATE MODEL `bqml.model`
OPTIONS(model_type='logistic_reg') AS
SELECT
  -- total.transactionsを目的変数（labelという名前のカラムは自動的に目的変数扱い）
  IF(totals.transactions IS NULL, 0, 1) AS label,
  -- その他を説明変数として使用
  IFNULL(totals.newVisits, 0) AS new_visits,
  IFNULL(totals.pageviews, 0) AS page_views,
  IFNULL(device.browser, "") AS browser,
  IFNULL(device.operatingSystem, "") AS os,
  device.isMobile AS is_mobile,
  IFNULL(geoNetwork.continent, "") AS continent
FROM
  `bigquery-public-data.google_analytics_sample.ga_sessions_*`
WHERE
  _TABLE_SUFFIX BETWEEN '20160801' AND '20170531';
```

#### モデルの評価

```sql
-- ML.EVALUATE関数でモデル評価
SELECT * FROM ML.EVALUATE(MODEL `bqml.model`, (
  SELECT
    IF(totals.transactions IS NULL, 0, 1) AS label,
    IFNULL(totals.newVisits, 0) AS new_visits,
    IFNULL(totals.pageviews, 0) AS page_views,
    IFNULL(device.browser, "") AS browser,
    IFNULL(device.operatingSystem, "") AS os,
    device.isMobile AS is_mobile,
    IFNULL(geoNetwork.continent, "") AS continent
  FROM
    `bigquery-public-data.google_analytics_sample.ga_sessions_*`
  WHERE
    -- 学習データとは異なる期間を指定（過学習の検出のため）
    _TABLE_SUFFIX BETWEEN '20170601' AND '20170630'));
```

評価指標: `precision`、`recall`、`accuracy`、`f1_score`、`log_loss`、`roc_auc`

#### 推論の実行

```sql
-- ML.PREDICT関数で推論
SELECT * FROM ML.PREDICT(MODEL `bqml.model`, (
  SELECT
    -- 推論では目的変数（label）は不要
    IFNULL(totals.newVisits, 0) AS new_visits,
    IFNULL(totals.pageviews, 0) AS page_views,
    IFNULL(device.browser, "") AS browser,
    IFNULL(device.operatingSystem, "") AS os,
    device.isMobile AS is_mobile,
    IFNULL(geoNetwork.continent, "") AS continent
  FROM
    `bigquery-public-data.google_analytics_sample.ga_sessions_*`
  WHERE
    -- 学習・評価データとは異なる期間
    _TABLE_SUFFIX BETWEEN '20170701' AND '20170801'
));
```

### 5.5 AutoMLによる機械学習（BigQuery ML経由）

AutoMLはBigQuery MLを介してSQLから利用できる。学習に関する一連のプロセス（前処理・モデル選択・チューニング・学習・評価）をAutoMLが自動で実行。

```sql
-- AutoML分類モデルの作成
CREATE OR REPLACE MODEL `bqml.automl`
OPTIONS(
  model_type='AUTOML_CLASSIFIER',
  budget_hours=1.0  -- Training Budget（学習の最大時間）
) AS
SELECT
  IF(totals.transactions IS NULL, 0, 1) AS label,
  IFNULL(totals.newVisits, 0) AS new_visits,
  IFNULL(totals.pageviews, 0) AS page_views,
  IFNULL(device.browser, "") AS browser,
  IFNULL(device.operatingSystem, "") AS os,
  device.isMobile AS is_mobile,
  IFNULL(geoNetwork.continent, "") AS continent
FROM
  `bigquery-public-data.google_analytics_sample.ga_sessions_*`
WHERE
  _TABLE_SUFFIX BETWEEN '20160801' AND '20170531';
```

**AutoMLのデータ要件**: 最低1,000行以上、100列まで。

### 5.6 Gemini連携（BigQuery MLからの利用）

BigQuery MLを通じてGemini等の生成AIモデルをSQL経由で呼び出せる。

#### 接続とリモートモデルの作成

```sql
-- Geminiリモートモデルの作成
CREATE OR REPLACE MODEL `bqml.genai`
REMOTE WITH CONNECTION `us.bqml_to_vertexai`
OPTIONS (ENDPOINT='gemini-pro');
```

#### テーブルデータへのGemini適用

```sql
-- テーブルデータに対してGeminiを一括適用
SELECT * FROM ML.GENERATE_TEXT(
  MODEL `bqml.genai`,
  (
    SELECT CONCAT('次の英語の文章を要約して日本語で説明して：', body) AS prompt
    FROM `bigquery-public-data.stackoverflow.stackoverflow_posts`
    LIMIT 10
  ),
  STRUCT(
    0.4 AS temperature,
    100 AS max_output_tokens,
    0.5 AS top_p,
    FALSE AS flatten_json_output
  )
);
```

利用可能なモデル: Gemini 1.5 Pro（`gemini-1.5-pro-002`）、Gemini 1.5 Flash（`gemini-1.5-flash-002`）、Gemini 1.0 Pro（`gemini-pro`）など。

### 5.7 BigQuery MLの実践的な使い方

**探索的データ分析（EDA）**: Vertex AI Workbench（Colab Enterprise）を使い、ノートブック環境からBigQueryデータにアクセスして試行錯誤。

**Vertex AI Workbenchの利用**:
- BigQueryのデータをノートブック上で直接操作
- `pandas.read_gbq`等でBigQueryのデータをDataFrameとして取得
- 特徴量エンジニアリング・可視化・モデルチューニングを実施

**オンライン推論**:
- BigQuery MLで学習したモデルをVertex AI Model Registryにエクスポート
- Vertex AI上でエンドポイントを作成してオンラインサービスとして提供
- REST APIまたは`gcloud ai endpoints predict`でリクエスト

```bash
# エンドポイントへの推論リクエスト例
curl -X POST \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  https://ENDPOINT_URL/v1/projects/PROJECT_ID/locations/LOCATION/endpoints/ENDPOINT_ID:predict \
  -d @input.json
```

---

## 6. 非構造化データ分析（BigQuery ML + Vertex AI連携）

### 6.1 リモートモデルの仕組み

BigQuery MLのリモートモデルを使うことで、Vertex AIの学習済みAPIをBigQuery MLのモデルとして扱うことができる。

**事前準備手順**:
1. BigQuery Connection APIを有効化
2. Vertex AIへのクラウドリソース接続を作成
3. 接続に紐づくサービスアカウントに必要なロールを付与
   - `roles/aiplatform.user`
   - `roles/serviceusage.serviceUsageConsumer`
4. BigQuery MLでリモートモデルとして学習済みAPIを指定

### 6.2 Natural Language APIによる自然言語処理

```sql
-- Natural Language APIリモートモデルの作成
CREATE OR REPLACE MODEL `bqml.nlp`
REMOTE WITH CONNECTION `us.bqml_to_vertexai`
OPTIONS (REMOTE_SERVICE_TYPE = 'CLOUD_AI_NATURAL_LANGUAGE_V1');

-- センチメント分析の実行
SELECT * FROM ML.UNDERSTAND_TEXT(
  MODEL `bqml.nlp`,
  (SELECT '今日はすごく楽しい一日でした。' AS text_content),
  STRUCT('ANALYZE_SENTIMENT' AS nlu_option)
);

-- テーブル単位でのテキスト分類
SELECT * FROM ML.UNDERSTAND_TEXT(
  MODEL `bqml.nlp`,
  (SELECT body AS text_content
   FROM `bigquery-public-data.stackoverflow.stackoverflow_posts`
   LIMIT 10),
  STRUCT('CLASSIFY_TEXT' AS nlu_option)
);
```

**nlu_optionの種類**:
- `ANALYZE_SENTIMENT`: センチメント分析（magnitude・scoreで感情の方向と強度を出力）
- `CLASSIFY_TEXT`: テキスト分類（カテゴリと信頼度を出力）
- `EXTRACT_ENTITIES`: エンティティ抽出
- `EXTRACT_ENTITY_SENTIMENT`: エンティティ感情分析

### 6.3 Vision APIによる画像のタグ付け

Cloud Storage上の画像データをオブジェクトテーブルとして定義し、Vision APIで処理する。

```sql
-- オブジェクトテーブルの作成
CREATE EXTERNAL TABLE `bqml.vision`
WITH CONNECTION `us.bqml_to_vertexai`
OPTIONS(
  object_metadata = 'SIMPLE',
  uris = ['gs://cloud-samples-data/vision/label/*']
);

-- Vision APIリモートモデルの作成
CREATE OR REPLACE MODEL `bqml.vision_model`
REMOTE WITH CONNECTION `us.bqml_to_vertexai`
OPTIONS (REMOTE_SERVICE_TYPE = 'CLOUD_AI_VISION_V1');

-- 画像へのタグ付け実行
SELECT * FROM ML.ANNOTATE_IMAGE(
  MODEL `bqml.vision_model`,
  TABLE `bqml.vision`,
  STRUCT([['label_detection']] AS vision_features)
);
```

**vision_featuresの主な種類**:
- `label_detection`: 画像のラベル付け
- `face_detection`: 顔検出
- `logo_detection`: ロゴ検出
- `object_localization`: 物体検出（位置情報付き）

### 6.4 対応するREMOTE_SERVICE_TYPEの一覧

| サービス | REMOTE_SERVICE_TYPE |
|---------|------|
| Natural Language API | `CLOUD_AI_NATURAL_LANGUAGE_V1` |
| Vision API | `CLOUD_AI_VISION_V1` |
| Translation API | `CLOUD_AI_TRANSLATE_V3` |
| Speech-to-Text API | `CLOUD_AI_SPEECH_TO_TEXT_V1` |
| Document AI | `CLOUD_AI_DOCUMENT_V1` |

---

## 7. BigQuery GIS（地理情報分析）

### 7.1 BigQuery GISとは

BigQueryに組み込まれた、地理情報データを操作・分析するための関数とデータ型のセット。GIS（Geographic Information Systems）。SQLクエリ内で他のビルトイン関数と同様に利用でき、BigQuery Geo Vizで可視化できる。

### 7.2 地理情報の基本概念

地理情報は緯度経度の組み合わせで構成される。

| 形態 | 例 |
|------|-----|
| 点（Point） | デバイスの位置（GPS）、施設の位置 |
| 線（LineString） | 道路の中心線、河川 |
| ポリゴン（Polygon） | 行政区画、建物の区画 |

**分析のアプローチ**:
1. 移動体の位置・軌跡を可視化してインサイトを得る
2. 地理的な範囲で位置情報を集計して定量的に分析する

### 7.3 GEOGRAPHY型と主要な地理関数

#### 基本的な型変換

```sql
-- 数値型の緯度経度からGEOGRAPHY型に変換
SELECT
  ST_GEOPOINT(longitude, latitude) AS geometry,
  capacity
FROM `bigquery-public-data.new_york_citibike.citibike_stations`;
```

**主要なGIS関数**:

| 関数 | 説明 |
|------|------|
| `ST_GEOPOINT(lng, lat)` | 数値型の経度・緯度からGEOGRAPHY型の点を生成 |
| `ST_WITHIN(geog1, geog2)` | geog1がgeog2に完全に含まれる場合にTRUEを返す |
| `ST_DISTANCE(geog1, geog2)` | 2点間の距離を算出（メートル） |
| `ST_AREA(polygon)` | ポリゴンの面積を算出（平方メートル） |
| `ST_INTERSECTS(geog1, geog2)` | 2つの地理情報が交差するかを判定 |
| `ST_GEOGFROMTEXT(wkt)` | Well-Known Text（WKT）形式からGEOGRAPHY型に変換 |
| `ST_GEOGFROMGEOJSON(json)` | GeoJSON形式からGEOGRAPHY型に変換 |
| `ST_ASGEOJSON(geog)` | GEOGRAPHY型をGeoJSON形式に変換 |

### 7.4 位置情報の集計処理（実践例）

郵便番号エリアごとの位置情報の集計。`ST_WITHIN`関数を使って、位置情報がどのエリアに含まれるかを判定する。

```sql
-- WITH句でJOINするためのテーブルを準備
WITH
-- トリップデータの一時テーブル
trips AS (
  SELECT
    ST_GEOPOINT(start_station_longitude, start_station_latitude)
      AS start_geog_point
  FROM
    `bigquery-public-data.new_york_citibike.citibike_trips`
  WHERE
    bikeid IS NOT NULL
    AND DATETIME_TRUNC(starttime, YEAR) = '2017-01-01'
),

-- 郵便番号エリアの一時テーブル
zip_codes AS (
  SELECT
    zip_code,
    zip_code_geom
  FROM
    `bigquery-public-data.geo_us_boundaries.zip_codes`
  WHERE
    state_fips_code IN ('36', '34')
)

-- 郵便番号エリアごとの利用件数を集計
SELECT
  zip_code,
  zip_code_geom,
  total_trips
FROM (
  SELECT
    zip_code,
    COUNT(1) AS total_trips
  FROM
    trips
  JOIN
    zip_codes
  ON
    -- ST_WITHIN: 出発ステーションの位置が郵便番号エリアに含まれる場合にTRUE
    ST_WITHIN(start_geog_point, zip_code_geom)
  GROUP BY
    zip_code
)
-- 可視化のためにポリゴン情報を付加
JOIN
  zip_codes
USING (zip_code);
```

### 7.5 地理情報の可視化（BigQuery Geo Viz）

BigQueryが標準提供する地理情報可視化ツール。Googleマップを背景にしたデータ可視化が可能。

**利用手順**:
1. BigQueryでクエリ実行後、[データを探索] → [GeoVizで調べる] をクリック
2. Authorizeでログイン
3. Style設定でfillOpacity等を調整
   - `Data-driven: 有効`、`Function: linear`、`Field: total_trips`、`Domain: 0-1000000`、`Range: 0-1`

### 7.6 地理情報分析の活用パターン

**ラベル付けによる分析価値向上**:
- 地理メッシュ（等価面積エリア）による位置情報のラベル付け
- 地図情報を使った最寄り道路・駅のラベル付け
- 店舗マスタを使った店舗圏内フラグの付与

**ビジネス活用例**:
- IoTデバイスの位置データ分析（車両追跡、移動最適化）
- O2Oマーケティング（オンライン/オフライン融合分析）
- コネクテッドカーのセンサーデータ分析
- 小売店舗の商圏分析・ステーション最適化

---

## 8. まとめ：MLサービス選択指針

| シナリオ | 推奨サービス |
|---------|------|
| 汎用的なNLP/画像/音声処理 | 学習済みAPI（Natural Language / Vision / Speech） |
| 自社固有データの分類・検出 | AutoML（コーディング不要） |
| BigQueryデータをSQLでML | BigQuery ML（ロジスティック回帰・AutoML・GIS） |
| 本格的なMLパイプライン | Vertex AI Pipelines + Feature Store |
| 生成AI（テキスト生成・要約） | BigQuery ML + Gemini連携 |
| 画像・音声の非構造データML | BigQuery ML + リモートモデル（Vision API等） |
| 地理情報分析 | BigQuery GIS（ST_GEOPOINT・ST_WITHIN等） |
| MLOps・継続的モデル改善 | Vertex AI（Workbench + Pipelines + ML Metadata） |

> **注意**: BigQuery MLのモデル学習は学習フェーズで多くのデータとリソースを消費する。予期せぬコストを避けるため、AutoMLの`budget_hours`設定やBigQuery MLの料金体系を事前に把握しておくこと。
