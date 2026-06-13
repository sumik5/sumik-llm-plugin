# ワークフロー管理・ETL/ELT実践

## ETL vs ELT: 基本概念と選択基準

### ETL と ELT の違い

| 処理順 | 定義 | 特徴 |
|--------|------|------|
| **ETL** | Extract → Transform → Load | データを取得・変換後に格納。外部処理エンジン（Dataflowなど）を使う |
| **ELT** | Extract → Load → Transform | データをそのまま格納後、DWH内で変換。BigQuery向け推奨パターン |

### BigQueryでELTを推奨する理由

- BigQuery はスケーラブルなDWHであり、大規模データ変換をそのまま実行できる
- SQL のみで変換処理を記述でき、別途ETLパイプラインの開発・運用が不要
- Dataproc/Dataflow ではクラスタ起動オーバーヘッドが発生するが、BigQuery ではオーバーヘッドなしに大規模並列処理が即時実行される
- ただし、SQL で表現できない変換や、クラスタが許容できる規模（数百GB〜）では ETL も選択肢となる

---

## BigQuery での ELT 実践

### 基本フロー（3ステップ）

1. **Load**: Cloud Storage のデータを作業用テーブルへロード
2. **Transform**: 作業用テーブルと他テーブルを結合・集計し、結果テーブルへ書き込み（`INSERT ... SELECT`）
3. **Cleanup**: 作業用テーブルを削除

```bash
# 1. Cloud Storage → BigQuery 作業用テーブルへロード
bq --location=us load \
  --autodetect \
  --source_format=NEWLINE_DELIMITED_JSON \
  gcpbook_ch5.work_events \
  gs://[project]-bucket/data/events/20181001/*.json.gz

# 2. 作業用テーブルと結合・集計して結果テーブルへ挿入
bq --location=us query --nouse_legacy_sql \
  --parameter='dt:date:2018-10-01' \
  'INSERT gcpbook_ch5.dau
   SELECT @dt AS dt,
     COUNTIF(u.is_paid_user) AS paid_users,
     COUNTIF(NOT u.is_paid_user) AS free_to_play_users
   FROM (SELECT DISTINCT user_pseudo_id FROM gcpbook_ch5.work_events) e
   INNER JOIN gcpbook_ch5.users u ON u.user_pseudo_id = e.user_pseudo_id'

# 3. 作業用テーブル削除
bq rm -f gcpbook_ch5.work_events
```

### ETL（外部データ参照）

BigQuery の外部テーブル機能を使い、Cloud Storage 上のデータを直接クエリしてデータを加工・投入することもできる。ただし、大規模な Join や集計では BigQuery ELT の方がパフォーマンスに優れる。

---

## Dataform による ELT パイプライン管理

### Dataformとは

BigQuery 内での ELT をコード管理・テスト・スケジュール実行できるマネージドサービス。SQL を拡張した **SQLX** 形式でクエリを記述し、依存関係の解決・自動実行・データ品質テストを提供する。

### 構成要素

| 要素 | 役割 |
|------|------|
| **リポジトリ** | SQLXファイル・JSファイル・設定ファイルを Git 管理 |
| **開発ワークスペース** | ブランチ単位の開発環境。Git 統合で複数人開発に対応 |
| **リリース構成** | SQLXをコンパイルするスケジュール（cron形式） |
| **ワークフロー構成** | コンパイル済みパイプラインの実行スケジュール（cron形式） |

### SQLX ファイルの構造

```sql
-- config ブロック: BigQueryオブジェクトのメタデータ・品質設定
config {
  type: "table",           -- table / view / incremental / operations
  description: "DAU集計テーブル",
  columns: {
    paid_users: "課金ユーザー数",
  },
  assertions: {
    uniqueKey: ["dt"],
    nonNull: ["dt", "paid_users"]
  }
}

-- body ブロック: 実際のSQL
SELECT
  '${dataform.projectConfig.vars.dt}' AS dt,
  COUNTIF(u.is_paid_user) AS paid_users,
  COUNTIF(NOT u.is_paid_user) AS free_to_play_users
FROM (
  SELECT DISTINCT user_pseudo_id
  FROM ${ref("work_events")}  -- 依存関係の定義: work_events.sqlx を先に実行
) e
INNER JOIN gcpbook_ch5.users u ON u.user_pseudo_id = e.user_pseudo_id
```

### 依存関係の解決

`${ref("テーブル名")}` でSQLXファイル間の依存関係を定義。Dataform が自動で実行順序を解決し、依存グラフを COMPILED GRAPH として可視化する。

### 定期実行の設定

```
リリース構成（ビルド）:   0 9,12 * * *  → 毎日 9時・12時にビルド
ワークフロー構成（実行）: 0 17 * * *    → 毎日 17時に実行
```

**ポイント**: ビルド頻度は実行頻度より高く設定し、ビルド完了後に実行が走るようにする。同じ頻度にするとビルド中に実行が始まり最新ビルドで動かないリスクがある。

### 本番環境での推奨事項

**環境分離**: 開発プロジェクトと本番プロジェクトを分ける。開発者ごとに開発ワークスペースを作成し、コンフリクトを回避する。

**データ品質テスト**:
- **組み込みアサーション**: `assertions: { uniqueKey, nonNull }` で NOT NULL / ユニークチェック
- **手動アサーション**: `type: "assertion"` で任意の SQLを使った複雑な品質確認

**増分テーブル**: `type: "incremental"` で差分のみ追加。初回はフルスキャン、以降は増分挿入/マージ。

**CI/CD統合**: GitHub/GitLab などのサードパーティ Git リポジトリと接続し、GitHub Actions でSQLX COMMIT 時に自動ビルド・テスト実行が可能。

**タグ分離**: `tags: ["daily"]` / `tags: ["monthly"]` でワークフロー構成を分け、実行単位を柔軟に制御する。

**Cloud Composer / Workflows からの実行**: `DataformOperator` や Workflows YAML 経由で Dataform を外部オーケストレーションに組み込むことも可能。

---

## Dataflow による ETL 実践（Python / Apache Beam）

### Dataflowとは

Google Cloud のフルマネージドデータ処理サービス。Apache Beam SDK を使って、ストリーミング処理とバッチ処理を統一的に記述できる。

### 主な特徴

- **ジョブに応じた自動プロビジョニング**: リソース管理不要
- **オートスケーリング**: データ量に応じたワーカー数の自動調整
- **ダイナミックワークリバランス**: 分散処理の偏りを是正

### Apache Beam パイプラインの構造（Python）

```python
import apache_beam as beam
from apache_beam.io import ReadFromText
from apache_beam.options.pipeline_options import PipelineOptions

with beam.Pipeline(options=pipeline_options) as p:
    # Cloud Storage からデータ読み取り
    user_pseudo_ids = (
        p
        | 'Read Events' >> ReadFromText(event_file_path)
        | 'Parse Events' >> beam.Map(lambda e: json.loads(e).get('user_pseudo_id'))
        | 'Deduplicate' >> beam.Distinct()
        | 'To KV' >> beam.Map(lambda uid: (uid, None))
    )

    # BigQuery からユーザー情報読み取り
    users = (
        p
        | 'Read Users' >> beam.io.Read(beam.io.BigQuerySource('dataset.users'))
        | 'Transform' >> beam.Map(lambda u: (u['user_pseudo_id'], u['is_paid_user']))
    )

    # 結合・集計・BigQueryへ書き込み
    (
        {'user_pseudo_ids': user_pseudo_ids, 'users': users}
        | 'Join' >> beam.CoGroupByKey()
        | 'Filter' >> beam.Filter(lambda r: len(r[1]['user_pseudo_ids']) > 0)
        | 'Count' >> beam.CombineGlobally(CountUsersFn())
        | 'Write' >> beam.io.WriteToBigQuery('dataset.dau', ...)
    )
```

### Dataflow ジョブの実行

```bash
python3 etl.py \
  --region us-central1 \
  --runner DataflowRunner \
  --project $(gcloud config get-value project) \
  --temp_location gs://[project]-bucket/tmp/ \
  --experiments shuffle_mode=service  # Dataflow Shuffle でコスト・性能最適化
```

### 本番運用の考慮点

- **可用性**: デフォルトで最適ゾーンを自動選択。バッチジョブは自動ゾーン選択を利用
- **スケーラビリティ**: オートスケールがデフォルト有効。定期バッチで処理量一定なら `--numWorkers` 固定が高速な場合もある
- **コスト**: `FlexRS`（Flexible Resource Scheduling）でバッチ料金を大幅削減（6時間以内に実行開始）。Dataflow Shuffle を有効化することでコスト削減にも寄与

---

## Cloud Composer によるワークフロー管理

### Cloud Composerとは

Apache Airflow をベースにしたフルマネージドのワークフロー管理サービス。DAG（Directed Acyclic Graph）で複数 ETL/ELT ジョブの依存関係・スケジュールを一元管理する。

### 環境の構成コンポーネント（Cloud Composer 2）

**顧客プロジェクト（ユーザーが見える）**:
- **GKE クラスタ**: Airflow Worker / Celery 分散タスクキュー / Scheduler が稼働。ノードのアップグレードは自動
- **Cloud Storage バケット**: DAGファイル・プラグインを配置。DAGフォルダに置くと自動デプロイ
- **Cloud Logging / Cloud Monitoring**: Airflow ログ・指標が自動連携
- **Airflow Web UI**: IAM と統合された認証認可が自動設定

**テナントプロジェクト（Google 管理）**:
- **Cloud SQL**: AirflowのバックエンドDB（設定・ジョブ履歴）
- **Cloud SQL ストレージ**: Cloud SQL のバックアップ（毎日自動取得）

### バージョン選択指針

| バージョン | 状態 | 特徴 |
|-----------|------|------|
| Composer 1 | メンテナンス後 | 利用非推奨 |
| **Composer 2** | 安定版（推奨） | GKE Autopilot による自動スケーリング |
| Composer 3 | パブリックプレビュー | GKE がテナントプロジェクトへ移行。IP消費なし。ネットワーク設定簡略化 |

### Airflow の主要概念

| 概念 | 説明 |
|------|------|
| **DAG** | 一連のタスクを有向非巡回グラフで表現。1 DAG = 1 ワークフロー |
| **タスク** | DAG 内の単一処理。DAG グラフのノードとして表現 |
| **オペレータ** | タスクの具体的な処理を定義するクラス |
| **タスクインスタンス** | 特定日付・特定 DAG の特定タスクの実行インスタンス |

### 主要 Operator（Google Provider）

| Operator | 用途 |
|----------|------|
| `GCSToBigQueryOperator` | GCS ファイルを BigQuery にロード |
| `BigQueryInsertJobOperator` | BigQuery クエリ実行 |
| `BigQueryDeleteTableOperator` | BigQuery テーブル削除 |
| `BashOperator` | Bash コマンド実行 |
| `PythonOperator` | Python 関数実行 |
| `Sensor` | 条件成立まで後続タスクを待機 |

### DAG 定義の実装例

```python
import airflow
from airflow.providers.google.cloud.operators.bigquery import (
    BigQueryInsertJobOperator, BigQueryDeleteTableOperator
)
from airflow.providers.google.cloud.transfers.gcs_to_bigquery import GCSToBigQueryOperator

default_args = {
    'owner': 'team',
    'retries': 1,
    'retry_delay': datetime.timedelta(minutes=5),
    'start_date': pendulum.today('Asia/Tokyo').add(hours=2)
}

with airflow.DAG(
    'count_users',
    default_args=default_args,
    schedule_interval=datetime.timedelta(days=1),
    catchup=False
) as dag:

    # タスク1: GCS → BigQuery ロード
    load_events = GCSToBigQueryOperator(
        task_id='load_events',
        bucket=os.environ.get('MY_PROJECT_ID') + '-bucket',
        source_objects=['data/events/{{ ds_nodash }}/*.json.gz'],  # Jinja テンプレート
        destination_project_dataset_table='dataset.work_events',
        source_format='NEWLINE_DELIMITED_JSON'
    )

    # タスク2: 集計クエリ実行
    insert_dau = BigQueryInsertJobOperator(
        task_id='insert_dau',
        configuration={"query": {"useLegacySql": False, "query": "INSERT ..."}}
    )

    # タスク3: 作業用テーブル削除
    delete_work_table = BigQueryDeleteTableOperator(
        task_id='delete_work_table',
        deletion_dataset_table='dataset.work_events'
    )

    # 依存関係の定義（Bit shift operator）
    load_events >> insert_dau >> delete_work_table
```

### DAG の登録と実行

```bash
# DAGファイルを Cloud Composer の DAGフォルダへアップロード（自動デプロイ）
gcloud composer environments storage dags import \
  --environment my-env --location us-central1 \
  --source my_dag.py

# 特定日付で手動実行（backfill）
gcloud composer environments run my-env \
  --location us-central1 \
  dags backfill -- -s 2018-10-01 -e 2018-10-01 my_dag
```

### 環境変数の設定

```bash
# DAGから参照できる環境変数を設定
gcloud composer environments update my-env \
  --location us-central1 \
  --update-env-variables=MY_PROJECT_ID=$(gcloud config get-value project)
```

### 本番環境の勘所

**アクセス制御**:
- IAM ロールで Airflow Web UI へのアクセス・環境編集を制御
- Apache Airflow アクセス制御モデルで UI 内のきめ細かい制御
- ウェブサーバーネットワークアクセス制御で IP 範囲を限定可能
- 接続情報（DB/API）は **Secret Manager** に格納して Airflow Connections を経由 → Airflow UI 上で閲覧できないよう保護

**スケーラビリティ**:
- Cloud Composer 2 は GKE Autopilot でワーカー自動スケーリング
- スケジューラ/ウェブサーバー/ワーカーのCPU・メモリ・ディスク上限を環境に合わせて設定

**DAG 設計のベストプラクティス**:
- 全タスクは失敗を前提に **冪等な実装** とリトライポリシーを設定
- ビジネスロジックは DAG ではなく BigQuery SQL や Dataflow ジョブ側に持たせ、DAG 自体をシンプルに保つ
- サービスアカウントを環境に明示設定し、権限を最小化する

**可用性**:
- 環境スナップショットを定期保存（Airflow 設定・環境変数・パッケージ・DBバックアップを含む）
- Cloud Composer 2 の高復元性環境でゾーン障害に対するフェイルオーバーを設定可能

---

## Cloud Data Fusion によるデータ統合

### Cloud Data Fusionとは

GUI でコードを書かずにETL/ELT パイプラインを構築できるフルマネージドデータ統合サービス。OSSの **CDAP** をベースとし、実行エンジンに **Dataproc**（Spark/MapReduce）を使用する。各パイプライン実行時にエフェメラルクラスタを自動作成・削除。

### エディション

| エディション | 用途 |
|-------------|------|
| **Developer** | 全機能使用可（ゾーン可用性・同時実行に制限あり）。開発用途 |
| **Basic** | バッチパイプライン。クリティカルでない環境向け |
| **Enterprise** | リアルタイムパイプライン・高可用性対応。本番クリティカル環境向け |

### ノード（プラグイン）の種類

| 種類 | 役割 |
|------|------|
| **ソース** | DB・ファイル・ストリームからデータを取得 |
| **変換** | データ整形・加工・型変換 |
| **分析** | 集計・結合・機械学習処理 |
| **シンク** | DB・ファイルストレージへのデータ書き込み |
| **条件** | パイプラインの分岐・フロー制御 |
| **アクション** | DB操作・コマンド実行など任意のアクション |

### GUI パイプライン構築の流れ

1. **インスタンス作成**: Data Fusion インスタンス（Developer/Basic/Enterprise）を作成
2. **ハブからプラグイン取得**: `HUB` からコネクタプラグインをインストール
3. **パイプライン設計**: Studio でソース・変換・シンクのノードをドラッグ&ドロップで接続
4. **マクロの活用**: `${project_id}` / `${logicalStartTime(yyyyMMdd, 0d, Asia/Tokyo)}` で動的なパラメータ設定
5. **デプロイ**: `Deploy` ボタンでパイプラインをデプロイ
6. **プロファイル設定**: Dataproc の実行環境（Region・ディスクサイズ等）を Profile として定義
7. **実行**: Runtime Arguments に `logical.start.time`（UNIX 時間ミリ秒）を渡して手動実行
8. **スケジュール**: cron 形式で定期実行を設定（`Max concurrent runs` で同時実行数を制限）

### スケジュール設定

```
Pipeline run repeats: Daily
Repeats every: 1 day(s)
Starting at: 12:00 AM (UTC)
Max concurrent runs: 1
Compute profiles: [Dataproc Profile 名]
```

### メタデータ・データリネージ

- **Metadata 画面**: データセット名・フィールド・タグ・スキーマ情報を検索・閲覧
- **Lineage 画面**: データセットの起源（どのパイプラインがどのデータから生成したか）を可視化
- **Field Level Lineage**: フィールド単位での系譜を確認可能
- **Dataplex との統合**: Dataplex のデータガバナンス機能と連携し、BigQuery テーブル情報からもリネージを確認可能

### Wrangler 機能

GUI 上でデータをインタラクティブにプレビュー・整形し、その結果をパイプラインで使用できる。ビジネスアナリストや非エンジニアでも直感的なデータ加工が可能。

---

## サービス比較・使い分けガイド

### ETL/ELT 手法の使い分け

| | BigQuery ELT | Dataflow ETL | Dataform ELT |
|---|---|---|---|
| **軸足** | SQL で完結するデータ変換 | SQL で表現できないバッチ・ストリーミング | BigQuery 内 ELT の開発・管理・テスト |
| **適用ユースケース** | SQL/Spark Stored Procedures で完結するデータ処理 | 複雑な変換・ストリーミング・大規模バッチ（数百GB〜） | SQL で完結するデータ処理をマネージドに実行したい |
| **言語・フレームワーク** | SQL、Spark | Apache Beam（Python/Java/Go/YAML）、Dataflow SQL | SQLX（SQL + JavaScript） |
| **データソース/シンク** | BigQuery ストレージ・外部テーブル（GCS/Bigtable） | BigQuery・GCS・オンプレ・他クラウドDB | BigQuery ストレージ・外部テーブル |
| **ストリーミング** | ストリーミング取り込み・書き出し対応 | ストリーミング取り込み・ストリーミング中の分析 | 非対応 |

### ワークフロー管理ツールの使い分け

| | Cloud Composer | Cloud Data Fusion | Dataform |
|---|---|---|---|
| **サービスの軸** | プログラムによるワークフロー制御 | GUI によるデータ統合・コネクタ開発省力化 | BigQuery 内 ELT の開発・テスト・制御 |
| **主な対象ユーザー** | データエンジニア・開発者 | ビジネスアナリスト・IT管理者（or 開発者の省力化） | データエンジニア・データアナリスト |
| **ETL/ELT 開発** | 主眼ではない（既存ジョブをオーケストレーション） | GUI でコネクタ接続しながら ETL/ELT を構築 | BigQuery 内 ELT を SQL で開発・テスト・デプロイ |
| **依存関係管理** | DAG で複雑な依存関係を管理 | 独立パイプライン（複数間は Composer で管理） | BigQuery 内ジョブの依存関係を管理（外部ジョブは限定的） |

### 相互補完パターン

```
Cloud Composer（オーケストレーター）
     ├── BigQuery SQL Jobs（ELT）
     ├── Dataform（SQL ELT管理）  ← DataformOperator で制御
     ├── Dataflow Jobs（ETL）
     └── Cloud Data Fusion（データ統合）  ← DataFusionOperator で制御

Workflows（軽量オーケストレーター）
     ├── Cloud Functions（データロード）
     ├── Dataform（ビルド + 実行）
     └── BigQuery（データマート作成）
```

**選択フロー**:
1. SQL だけで完結する → **Dataform** または **BigQuery ELT** を直接使用
2. GUI でノーコードが必要 → **Cloud Data Fusion**（ビジネスアナリスト主体の場合）
3. 複数サービスを跨ぐ複雑な依存管理 → **Cloud Composer**
4. SQL で表現できない変換・ストリーミング処理 → **Dataflow**
5. サードパーティ ETL ツール既存ライセンス → Informatica/Talend との組み合わせも可

---

## 環境セットアップ早見表

### Cloud Composer 環境作成

```bash
# API 有効化
gcloud services enable composer.googleapis.com

# 環境作成（Composer 2 / Airflow 2.7.3）
gcloud composer environments create my-env \
  --location us-central1 \
  --image-version composer-2.8.3-airflow-2.7.3
```

### Cloud Data Fusion API 有効化

```bash
gcloud services enable datafusion.googleapis.com
```

### Dataform API 有効化

```bash
gcloud services enable dataform.googleapis.com
```

### Dataform サービスアカウントへの権限付与

Dataform リポジトリ作成後に表示されるサービスアカウントに以下を付与:
- `roles/bigquery.admin`（BigQuery 管理者）
- `roles/storage.admin`（ストレージ管理者）
- `roles/dataform.serviceAgent`（Dataformサービスエージェント）
