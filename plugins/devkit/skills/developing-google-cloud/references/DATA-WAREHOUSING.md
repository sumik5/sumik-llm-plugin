# データウェアハウス設計ガイド（BigQuery）

データウェアハウスの設計原則、データモデリング、正規化・非正規化の判断基準、アクセスパターン対応、BigQuery設計ベストプラクティスを解説する。

---

## データウェアハウスの概念

**データウェアハウス**: 複数の（通常は関連する）データソースから大量のデータを収集・整理し、一元的に格納する中央リポジトリ。分析用ストレージハブとして、収集されたデータの相互参照・分析・パターン発見に使用される。

### データウェアハウス vs データレイク

| 比較項目 | データウェアハウス | データレイク |
|---------|------------------|------------|
| **データ構造** | 構造化・整理済み | 生データ（構造化・半構造化・非構造化混在） |
| **用途** | 分析・BI・レポーティング | 探索的分析・ML・多様なデータ保管 |
| **GCPサービス** | BigQuery | Cloud Storage + BigQuery（外部テーブル） |

### データウェアハウスの構築動機

- 複数データソースからのデータ統合・一元化
- 大量データに対するパターン発見・分析的洞察
- 意思決定者への分析基盤提供
- クラウドサービスにより、従来困難だった大規模データの収集・移動・管理が容易に

---

## データモデル設計

### データモデルの定義

**データモデル**: データベースに格納されるデータの期待される構造・制約・型を定義したもの。

**例**: Userモデル

| Column Name | Data Type | Description |
|------------|-----------|-------------|
| user_id | UUID | ユニークユーザー識別子 |
| email | VARCHAR(100) | ユーザーメールアドレス |
| first_name | VARCHAR(50) | ユーザー名 |
| last_name | VARCHAR(50) | ユーザー姓 |
| dob | DATE | 生年月日 |
| user_rating | FLOAT | ユーザー評価 |

---

## カラム選択

### 選択基準

すべてのデータをウェアハウスに格納する必要はない。以下の基準で選択:

| 基準 | 説明 | 例 |
|------|------|-----|
| **分析要件** | 分析に必要なカラムのみ格納 | GDPRコンセントフラグは記録必要だが分析不要 → 除外 |
| **クエリサイズ** | クエリパフォーマンスに影響 | 不要なカラムはクエリコストを増加 |
| **データ形式** | パース・変換コスト | 複雑なネストJSONは事前に平坦化 |
| **ストレージコスト** | 保存容量に影響 | 大容量カラムは別ストレージ検討 |

### 実例: ビル入館ログ

**要件**:
- ユーザー識別（既存Userテーブルから参照）
- 入口識別（A/B/C）
- タイムスタンプ
- ログエントリのユニーク識別

**データモデル**:

| Column Name | Data Type | Description |
|------------|-----------|-------------|
| check_in_id | UUID | チェックインユニークID |
| user_id | Foreign Key | Userモデルの識別子 |
| entrance | ENUM('A', 'B', 'C') | 入口オプション |
| check_in_time | DATETIME | チェックインタイムスタンプ |

**分析可能な情報**:
- ユーザー入館頻度
- 最頻利用入口
- 時間帯別入館傾向

---

## データ型制約

### 基本制約

| 制約タイプ | 説明 | 例 |
|-----------|------|-----|
| **データ型** | INT, FLOAT, VARCHAR, DATE等 | `first_name VARCHAR(50)` |
| **サイズ制限** | 最大長・桁数 | `VARCHAR(50)` = 最大50文字 |
| **NOT NULL** | NULL値禁止 | 必須フィールド |
| **UNIQUE** | 重複禁止 | `user_id` |
| **DEFAULT** | デフォルト値 | `created_at DEFAULT CURRENT_TIMESTAMP` |

### 事前データ制限

ウェアハウス書き込み前にデータをフィルタリング:

**例: ビル入館ログの制約**
1. **日付範囲**: タイムスタンプは当日のみ許可（過去・未来は拒否）
2. **外部キー整合性**: `user_id` がUserテーブルに存在すること
3. **列挙値検証**: `entrance` はA/B/Cのいずれか

**実装箇所**:
- アプリケーションレベル
- バックエンドAPI
- **Data Pipeline**: GCP Data Pipelineでデータクリーニング・変換

---

## データ記述（メタデータ）

### メタデータの重要性

**メタデータ**: データを説明するデータ

**用途**:
1. チーム間でのデータ理解共有
2. セマンティックAI分析（コンテキスト理解）
3. データカタログ・リネージ追跡

### BigQueryでの記述

BigQueryでは各カラムにDescription欄が存在:

```sql
-- BigQuery テーブル作成時に記述を追加
CREATE TABLE project.dataset.check_ins (
  check_in_id STRING OPTIONS(description="ユニークチェックイン識別子"),
  user_id STRING OPTIONS(description="Userテーブルの外部キー"),
  entrance STRING OPTIONS(description="入口 (A, B, C)"),
  check_in_time TIMESTAMP OPTIONS(description="チェックインタイムスタンプ")
);
```

### Manifestファイル（カスタムウェアハウス）

マネージドサービス以外の場合、`manifest.json` で記述:

```json
[
  {
    "field": "user_id",
    "type": "foreign_key(user)",
    "description": "Userテーブルの外部キー"
  },
  {
    "field": "entrance",
    "type": "enum",
    "values": ["A", "B", "C"],
    "description": "入館入口"
  }
]
```

---

## 正規化の判断

### データ正規化の定義

**データ正規化**: 異なるソースから来るデータを統一されたスキーマ・スケールに変換し、一貫した分析を可能にするプロセス。

### スキーマ正規化

**問題**: 異なるフォーマットのデータが混在

**例: 日付フォーマット統一**
- **標準**: `YYYY-MM-DD`（ISO 8601）
- **変換必要**: `YYYY-DD-MM`, `MM/DD/YYYY`

**アプローチ**:
```python
# Data Pipeline / Dataflow での変換例
def normalize_datetime(input_str):
    # 複数フォーマットを検出
    for fmt in ['%Y-%m-%d', '%Y-%d-%m', '%m/%d/%Y']:
        try:
            return datetime.strptime(input_str, fmt).strftime('%Y-%m-%d')
        except ValueError:
            continue
    raise ValueError(f"Unsupported date format: {input_str}")
```

### スケール正規化

**問題**: 異なるスケール・単位のデータが同一カラムに格納

**例1: 温度単位統一**
- Fahrenheit → Celsius変換
- データソースごとに単位が異なる場合

**例2: 年齢スケーリング**

**変換前**:

| User_id | Age |
|---------|-----|
| 1 | 99 |
| 2 | 12 |
| 3 | 45 |
| 4 | 63 |

**変換後（0-1正規化）**:

| User_id | Age |
|---------|-----|
| 1 | 0.88 |
| 2 | 0.08 |
| 3 | 0.41 |
| 4 | 0.59 |

**正規化式**:
```
normalized_value = (value - min) / (max - min)
```

**メリット**:
- データのバイアス削減
- 機械学習アルゴリズムのパフォーマンス向上
- 異なるスケールの特徴量を同等に扱える

---

## 非正規化（Denormalization）

### 非正規化の目的

**非正規化**: 分析・機械学習のためにデータ構造を簡素化・抽出する処理。

**適用ケース**:
- 機械学習モデルの入力準備
- トークン分析
- カテゴリカルデータの数値化

### One-Hot Encoding

**概念**: 列挙型カラムを複数のBoolean（0/1）カラムに分解。

**例: 入口列挙値の非正規化**

**変換前**:

| check_in_id | entrance |
|-------------|----------|
| 1 | A |
| 2 | C |
| 3 | B |
| 4 | C |

**変換後**:

| check_in_id | entrance | is_entrance_A | is_entrance_B | is_entrance_C |
|-------------|----------|---------------|---------------|---------------|
| 1 | A | 1 | 0 | 0 |
| 2 | C | 0 | 0 | 1 |
| 3 | B | 0 | 1 | 0 |
| 4 | C | 0 | 0 | 1 |

**BigQueryでの実装**:

```sql
SELECT
  check_in_id,
  entrance,
  IF(entrance = 'A', 1, 0) AS is_entrance_A,
  IF(entrance = 'B', 1, 0) AS is_entrance_B,
  IF(entrance = 'C', 1, 0) AS is_entrance_C
FROM check_ins;
```

**メリット**:
- 機械学習アルゴリズムが数値データとして処理可能
- カテゴリカル変数の数値変換
- アルゴリズムパフォーマンス向上

**注意**:
- 可読性低下（人間にとって読みにくい）
- 一時的なデータセットとして作成（元データは保持）

---

## データアクセスパターン対応

### ユーザー要件の聞き出し

**よくある質問**:

| 質問 | 目的 |
|------|------|
| どのくらいのデータ量を保存するか？ | ストレージ容量・コスト見積もり |
| どのデータソースから取り込むか？ | データコネクタ選定 |
| データセキュリティ要件は？ | IAM・ネットワーク・行/列レベルセキュリティ設定 |
| クエリ速度の要件は？ | パーティショニング・クラスタリング設計 |
| 予算は？ | ストレージクラス・クエリ最適化 |

**BigQueryの回答例**:
1. **容量**: 無制限（ロード時の制限あり）
2. **コネクタ**: 主要クラウドプロバイダ・多数のデータ収集サービス対応
3. **セキュリティ**: IAM、ネットワークベース、行/列レベルセキュリティ
4. **クエリ速度**: Dry runで最適化可能
5. **コスト**: ストレージ・転送コスト、大容量は割引交渉可能

### 要件の実装への変換

**例: 会計事務所の要件**

**要件**:
- Google Sheets（会計士ごと）のデータを統合
- 会計士ごとにエントリを識別
- BigQueryから再度Sheetsで分析

**実装選択肢**:

| アプローチ | メリット | デメリット |
|-----------|---------|----------|
| **会計士ごとにテーブル作成** | 実装容易 | テーブル数増加、分析困難 |
| **会計士IDカラム追加** | 実装やや複雑 | 分析容易、スケーラブル |

**推奨**: 会計士IDカラム追加（持続可能性・スケーラビリティ重視）

**実装**:
```sql
-- Sheetsから取り込み時にカラム追加
CREATE TABLE project.dataset.accounting_entries (
  entry_id STRING,
  accountant_id STRING,  -- 追加
  amount FLOAT64,
  date DATE,
  description STRING
);
```

### アクセスパターンの監視と最適化

データウェアハウスの構成は、実際のデータアクセスパターンに基づいて継続的に最適化する必要がある。

**GCPでのアクセスパターン分析**:
- **Cloud Logging**: データアクセスのアクティビティログを記録
- **Cloud Monitoring**: アクセスパターンを統計的に可視化
- ログの日次・月次・年次パターンを分析し、構成の最適化に反映

**実践シナリオ: Cloud Storage上のデータレイク/ウェアハウス**

IoTデバイスの日次CSVログをCloud Storageに格納するケース:
1. ログファイルを日付・デバイスシリアル番号でラベリングして保存
2. 1週間後にサードパーティサービスが抽出・分析
3. 抽出後はアーカイブティアに自動移行（ストレージコスト削減）
4. コンプライアンス要件でRetention Policyを設定（一定期間削除不可）

> **Filestoreの検討**: フォルダベースのファイル操作が必要な場合は、Cloud StorageではなくFilestoreを検討する。

---

## BigQuery設計ベストプラクティス

### データセット構成

**データセット**: テーブルをグループ化する論理的な単位。

**設計原則**:
- **ドメイン別**: 財務、営業、マーケティング等
- **環境別**: dev, staging, prod
- **地理的リージョン**: リージョン別データセット

```bash
# データセット作成
bq mk --dataset \
  --location=US \
  --description="Production financial data" \
  project_id:finance_prod
```

### パーティショニング

**概念**: テーブルをセグメントに分割し、クエリ時にスキャン範囲を削減。

**パーティショニングタイプ**:

| タイプ | 説明 | ユースケース |
|--------|------|-------------|
| **時間単位パーティション** | `_PARTITIONTIME` による自動分割 | 日次ログ、時系列データ |
| **取込時刻パーティション** | データ取込時刻で分割 | ストリーミングデータ |
| **整数範囲パーティション** | 整数カラムで分割 | ユーザーID、注文番号 |

**例: 日付カラムでパーティション**:

```sql
CREATE TABLE project.dataset.events (
  event_id STRING,
  event_date DATE,
  user_id STRING,
  event_type STRING
)
PARTITION BY event_date
OPTIONS(
  partition_expiration_days=90
);
```

**メリット**:
- クエリコスト削減（スキャンデータ量削減）
- クエリ速度向上
- パーティション自動削除（コスト管理）

### クラスタリング

**概念**: パーティション内でデータを特定カラムでソート。

**クラスタリングカラム選択基準**:
- WHERE句で頻繁にフィルタリングするカラム
- GROUP BY で使用するカラム
- 高カーディナリティ（多様な値）のカラム

**例**:

```sql
CREATE TABLE project.dataset.events (
  event_id STRING,
  event_date DATE,
  user_id STRING,
  event_type STRING
)
PARTITION BY event_date
CLUSTER BY user_id, event_type;
```

**パーティショニング vs クラスタリング**:

| 比較項目 | パーティショニング | クラスタリング |
|---------|------------------|---------------|
| 粒度 | 粗い（日次等） | 細かい（カラム値） |
| スキャン削減 | 大幅 | 中程度 |
| メンテナンス | パーティション削除可能 | 自動最適化 |
| 組み合わせ | パーティション後にクラスタリング推奨 | - |

---

## BigQuery ML概要

BigQueryでは、SQLクエリでMLモデルを作成・評価・予測可能。

### モデル作成（CREATE MODEL）

```sql
CREATE OR REPLACE MODEL project.dataset.taxi_fare_model
OPTIONS(
  model_type='linear_reg',  -- 線形回帰
  labels=['total_fare']     -- 予測対象カラム
) AS
SELECT
  total_fare,
  dayofweek,
  hourofday,
  pickuplon,
  pickuplat,
  dropofflon,
  dropofflat,
  passengers
FROM
  project.dataset.taxitrips
WHERE
  trip_distance > 0 AND fare_amount > 0;
```

**主要model_type**:

| モデルタイプ | 説明 | ユースケース |
|------------|------|-------------|
| `linear_reg` | 線形回帰 | 数値予測（価格、売上等） |
| `logistic_reg` | ロジスティック回帰 | 2値分類（購入/非購入等） |
| `kmeans` | K-means | クラスタリング |
| `automl_classifier` | AutoML分類 | 自動モデル選択 |
| `dnn_classifier` | Deep Neural Network | 複雑な分類 |

### モデル評価（ML.EVALUATE）

```sql
SELECT
  SQRT(mean_squared_error) AS rmse
FROM
  ML.EVALUATE(MODEL project.dataset.taxi_fare_model,
    (
      SELECT
        total_fare,
        dayofweek,
        hourofday,
        pickuplon,
        pickuplat,
        dropofflon,
        dropofflat,
        passengers
      FROM
        project.dataset.taxitrips_eval
    )
  );
```

**評価指標**:
- **RMSE**: Root Mean Squared Error（回帰）
- **Accuracy**: 正解率（分類）
- **Precision/Recall**: 精度/再現率（分類）

### 予測（ML.PREDICT）

```sql
SELECT
  predicted_total_fare,
  total_fare AS actual_fare
FROM
  ML.PREDICT(MODEL project.dataset.taxi_fare_model,
    (
      SELECT
        total_fare,
        dayofweek,
        hourofday,
        pickuplon,
        pickuplat,
        dropofflon,
        dropofflat,
        passengers
      FROM
        project.dataset.taxitrips_test
    )
  );
```

---

## Cloud Storage データレイク統合

BigQueryはCloud Storageの外部テーブルとして直接クエリ可能。

### 外部テーブル作成

```sql
CREATE EXTERNAL TABLE project.dataset.csv_logs
OPTIONS (
  format = 'CSV',
  uris = ['gs://bucket/logs/*.csv'],
  skip_leading_rows = 1
);
```

**ユースケース**:
- IoTデバイスログ（CSV）をCloud Storageに保存
- 週次でBigQueryから抽出・分析
- アーカイブは自動的にColdline/Archive tierへ移行
- Retention Policyで法的保持対応

---

## まとめ

データウェアハウス設計の原則:

1. **データモデル設計**: カラム選択・型制約・メタデータ記述で分析可能性を確保
2. **正規化判断**: スキーマ・スケール正規化で一貫性を保ち、非正規化（One-Hot Encoding）で機械学習対応
3. **アクセスパターン対応**: ユーザー要件を聞き出し、実装に変換
4. **BigQuery最適化**: パーティショニング・クラスタリングでクエリコスト削減
5. **BigQuery ML**: CREATE MODEL / ML.EVALUATE / ML.PREDICTでSQL内でML実行

---

## ゲーム分析ユースケースとBigQuery活用パターン

ゲームインフラ特有のデータ分析要件とBigQueryを用いた実践的な構築パターンを示す。

### ゲームデータ分析の3段階モデル

ゲームにおけるログ・データ分析の活用は段階的に深化する。エンジニア以外の関係者が増えるほど、非技術者向けの分析UI整備が重要になる。

| ステージ | 活用レベル | 主なユースケース | 対象者 |
|---------|-----------|----------------|--------|
| **I** | ログ検索・追跡 | 障害発生時のログ特定、ユーザ問合せ対応 | エンジニア |
| **II** | KPI集計・分析 | DAU・ARPU・リテンション率の日次算出 | エンジニア + 企画・運営 |
| **III** | ゲーム企画分析 | イベント効果測定、行動ログによるユーザ分類 | 全関係者（経営含む） |

**ゲームKPIの代表的な集計パターン**:

```sql
-- DAU（日次アクティブユーザー数）
SELECT
  DATE(login_time) AS date,
  COUNT(DISTINCT user_id) AS dau
FROM `project.game.login_20*`
WHERE _TABLE_SUFFIX BETWEEN '151201' AND '151231'
GROUP BY date
ORDER BY date;

-- ARPU（ユーザーあたり平均収益）
SELECT
  DATE(purchase_time) AS date,
  SUM(amount) / COUNT(DISTINCT user_id) AS arpu
FROM `project.game.purchase_20*`
WHERE _TABLE_SUFFIX = FORMAT_DATE('%y%m%d', CURRENT_DATE())
GROUP BY date;
```

### ゲームログが難しい理由と対策

| 課題 | 内容 | BigQueryによる対策 |
|------|------|-------------------|
| **サイジング予測困難** | タイトルヒット予測不可、ログ量が爆発的に増える可能性 | 無制限スケール・従量課金で事前サイジング不要 |
| **ログ内容の頻繁な変化** | ゲーム改良でスキーマが変わり続ける | JSONカラムで対応 or カラム追加で後方互換維持 |
| **重要ログと大量ログの混在** | 課金ログ（低頻度・高重要）とバトルログ（高頻度・低重要）の混在 | アクション単位でテーブルを分割して管理 |
| **多タイトル管理** | タイトルごとに異なるスキーマ、ライフサイクル短い | データセット単位でタイトル分離 |

### BigQueryゲーム分析アーキテクチャ選択

3つの軸での設計判断が必要。ゲームではシンプルさと再集計容易性を優先することが多い。

| 軸 | 選択肢A | 選択肢B | ゲームでの推奨 |
|---|---------|---------|--------------|
| **ログ粒度** | 生レコードをそのまま保存 | 時間単位で丸めて保存 | **生レコード**（送信ミス時の修正が容易） |
| **集計タイミング** | リクエスト都度集計 | 事前集計して保存 | **都度集計**（再集計が自動化される） |
| **集計範囲** | 常に全期間から再集計 | 当日分のみ差分集計 | **全期間**（欠損・重複ログの自動補正） |

**推奨アーキテクチャ（Aiming実績ベース）**:
```
ゲームサーバ
  → Fluentd（リアルタイム）/ Embulk（日次バルク）
  → BigQuery（生レコード、日付×アクション単位テーブル）
  → リクエスト都度SQL集計
  → 内製or BIツールで可視化
```

### テーブル設計パターン

**ゲームログのテーブル命名規則**:
```sql
-- アクション種別×日付でテーブルを分割
-- 命名例: login_20151201, purchase_20151201, gacha_20151201

-- 日付範囲を横断するクエリ（table_date_range使用）
SELECT COUNT(DISTINCT user_id) AS dau
FROM TABLE_DATE_RANGE(login_, TIMESTAMP('20151201'), TIMESTAMP('20151231'))
```

**テーブル分割の判断基準**:

| 分割軸 | 採用理由 | 注意点 |
|-------|---------|-------|
| **アクション単位** | ガチャ・ログイン等の関心別集計が多い | 横断分析が必要な場合はJOINが増える |
| **日付単位** | コスト最適化（必要期間のみスキャン）、再ロード容易 | 3年以上継続タイトルは1000テーブル上限に注意（5ミリ秒×テーブル数分のオーバーヘッド） |

---

## fluentd連携パターン（BigQueryリアルタイムログ送信）

### 2種類のFluentd構成と使い分け

**構成A: 専用ログ収集サーバ経由**

```
ゲームサーバ群 → 専用ログ収集サーバ(Fluentd) → BigQuery
```

| 項目 | 内容 |
|------|------|
| **メリット** | スキーマ変更時に収集サーバのみ修正、ゲームサーバ不要。設定管理が集中化 |
| **デメリット** | 単一故障点になる。数百台からのログ集中で過負荷リスク（Rubyのfluentd） |
| **推奨台数** | 数十台以下のゲームサーバ構成 |

**構成B: ゲームサーバから直接送信**

```
ゲームサーバ × N台（各自Fluentd） → BigQuery
```

| 項目 | 内容 |
|------|------|
| **メリット** | 負荷が分散（100台なら100分の1）。過負荷リスクなし |
| **デメリット** | 設定変更時に全台配布が必要（Chef/Ansibleなどのデプロイツール必須） |
| **推奨台数** | 数十台以上の大規模ゲームサーバ |

### Fluentdログ送信の落とし穴と対策

| 問題 | 原因 | 対策 |
|------|------|------|
| **streaming insertでログが欠ける** | fluentd-bigquery-pluginとBigQuery間の問題（3000万件で約2000件欠落） | 日付単位テーブル＋リアルタイム送信＋前日テーブルを日次ロード方式で上書き |
| **日付変更時に先頭行が読まれない** | in_tailプラグインのread_from_headオプションのデフォルト設定 | `read_from_head true` を明示的に設定 |
| **タイムゾーンのズレ** | BigQueryはUTCのみ、JSTで送ると9時間ずれる | ログ送信時にUTCで統一 or クエリ時に`DATE_ADD(time, -9, 'HOUR')`で補正 |

### ログ収集ツールの選択

| ツール | 用途 | 特徴 |
|--------|------|------|
| **Fluentd** | リアルタイム・ストリーミング送信 | 無償、tail pluginでゲームログ自動収集、幅広いプラグインエコシステム |
| **Embulk** | バルク一括ロード（日次等） | MySQLダンプ→BigQuery一括移行など大量データに最適 |
| **resumable upload** | データ整合性保証が必要な場合 | 全件入ればtrue、一件でも失敗すれば全件不投入（アトミック保証） |

### ゲームログ分析コスト最適化

- **日付単位テーブル分割**: 直近期間のみクエリすることでスキャン量を削減
- **アクション単位分割**: ガチャログのみ集計など、不要テーブルをスキャン対象外に
- **Billing Alert必須**: 従量課金のため運用ミスで予期せぬ課金が発生しやすい
- **定型レポート**: 月数千円〜数万円、全社的活用: 月数十万円が目安

---

## 外部接続の最適化（Storage API / BI Engine）

BigQueryをDWHとして利用する際には、BIツール・ODBC/JDBC接続・Jupyter Notebookなどの外部接続ツールと組み合わせることが多い。接続方法の選択によってスループットが大きく変わる。

### BigQuery Storage API（Notebook / Hadoop / Spark）

BigQuery Storage APIはRPC経由で並行してデータを読み出す高速API。列プロジェクション（必要な列のみ取得）とフィルタリングをサーバーサイド（ストレージ側）で実行するため、転送データ量を最小化できる。

| 利用シーン | 推奨ライブラリ/コネクタ |
|-----------|----------------------|
| Python / Pandas | `google-cloud-bigquery`（Storage API を内包） |
| Jupyter Notebook | `pandas-gbq` → `google-cloud-bigquery` への移行推奨 |
| Apache Spark | BigQuery Spark / Hadoop コネクタ |
| ODBC/JDBC | BigQuery ODBC/JDBC ドライバ（Storage API 対応） |

> **確認ポイント**: 各ライブラリはオプションでStorage APIの有効/無効を切り替えられる。デフォルトで無効になっている場合があるため、大量データを扱う場合は明示的に有効化する。

### BigQuery BI Engine（BIツール）

BigQuery BI Engineはインメモリのクエリエンジンを利用し、BIツールからのデータマートアクセスやドリルダウンを高速化する。BI Engine SQL Interfaceにより、Tableau・Looker・Power BIなどから透過的に利用できる。

| 特徴 | 内容 |
|-----|------|
| **高速化対象** | BIツールからのフィルタ・ドリルダウン・集計クエリ |
| **Looker Studio** | 1GBのメモリが無料で利用可能（ネイティブ統合を除く） |
| **課金** | 予約したメモリ容量に対して課金（クエリ課金とは別） |
| **透過利用** | 既存SQLを変更せずにアクセラレーション可能 |

---

## データマートジョブの設計最適化

データウェアハウス上のデータを目的別に事前集計したデータマートを作成・運用する際の最適化パターン。

### データマート更新：差分更新より洗い替えが有効

DMLによる差分更新は直感的だが、BigQueryの特性（スキャン・演算の高速さ）を活かすには**洗い替え（パーティション単位の全件再集計）**の方が結果的に高速になることが多い。

**差分更新（DML）の問題点**:
- 差分を絞り込む `last_updated_at` のフィルタがパーティションキーと異なる場合、全表スキャンが発生
- UPDATEは内部的にCOPY+MERGEとなりコストが高い

**洗い替えパターン（推奨）**:

```sql
-- Step 1: 対象日付のパーティションを削除（スキャンなしで高速削除）
DELETE FROM `project.dataset.daily_sales_summary`
WHERE sales_date = "2024-01-01";

-- Step 2: 同日分を全件再集計してINSERT
INSERT INTO `project.dataset.daily_sales_summary`
SELECT sales_date, product_id, store_id, SUM(amount) AS daily_amount_sold
FROM `project.dataset.sales_records`
WHERE sales_date = "2024-01-01"
GROUP BY sales_date, product_id, store_id;
```

**一括更新パターン（更新中の値を見せたくない場合）**:

```sql
-- 一時テーブルで計算してから本テーブルを一括置換
CREATE OR REPLACE TABLE `project.dataset.daily_sales_summary`
PARTITION BY sales_date
CLUSTER BY store_id, product_id
AS
SELECT sales_date, product_id, store_id, SUM(amount) AS daily_amount_sold
FROM `project.dataset.sales_records`
GROUP BY sales_date, product_id, store_id;
```

### データマートテーブル設計の推奨構成

| 設定項目 | 推奨 | 理由 |
|---------|------|------|
| **sales_records（元データ）** | `PARTITION BY sales_date` | 差分更新の絞り込みをパーティション単位で実現 |
| **daily_sales_summary（マート）** | `PARTITION BY sales_date` | BIツールのフィルタ高速化 |
| **daily_sales_summary（マート）** | `CLUSTER BY store_id, product_id` | フィルタ・GROUP BYの高速化 |

> **マテリアライズドビューの活用**: 要件が合う場合はマテリアライズドビューで最新データを保持しながらより簡単にデータマートを構成できる。

---

## Analytics Hub によるデータ共有

BigQueryはデータセット権限で組織・プロジェクト間のデータ共有が可能だが、共有先とデータセットがM:N関係で増えると権限管理が煩雑になる。**Analytics Hub**はこの問題を解決するBigQuery上のデータ交換プラットフォーム。

### Analytics Hub の主要コンポーネント

| コンポーネント | 役割 |
|-------------|------|
| **データエクスチェンジ** | パブリッシャーとサブスクライバーをつなぐ交換所。限定公開/一般公開を選択可能 |
| **リスティング** | データエクスチェンジに登録される共有データセットのエントリ。名前・説明・ドキュメントを含む |
| **共有データセット** | パブリッシャーが提供するBigQueryデータセット（テーブル・MLモデル・承認済みビューを含められる） |
| **リンク済みデータセット** | サブスクライバーがサブスクライブすると作成される読み取り専用データセット（共有データセットへのシンボリックリンク） |

### Analytics Hub の特徴

- **データ複製なし**: リンク済みデータセットはシンボリックリンクであり、ストレージ料金が追加されない
- **課金モデル**: サブスクライバー側でのクエリ実行にのみ課金
- **使用状況監視**: `INFORMATION_SCHEMA.SHARED_DATASET_USAGE` でアクセスしたジョブレベルの使用状況を確認可能
- **セキュリティ制御**: パブリッシャーはコピー/エクスポート操作の無効化、行レベル・列レベルのアクセス制御、データマスキングを設定可能

### 利用ケースの判断基準

| シナリオ | 推奨アプローチ |
|---------|-------------|
| 少数のチームへの社内共有 | データセット権限による直接共有 |
| 多数の部門/組織への共有 | Analytics Hub（管理コスト削減） |
| 組織外へのデータ販売・提供 | Analytics Hub（データマーケットプレイス） |
| プライバシー保護が必要 | Analytics Hub（データクリーンルーム機能）|
