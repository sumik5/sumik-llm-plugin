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
