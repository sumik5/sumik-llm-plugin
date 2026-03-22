# リアルタイム分析リファレンス

Google Cloudにおけるリアルタイム分析基盤の設計・実装・運用の包括的ガイド。

---

## リアルタイム分析の概要

### ユースケースと定義

リアルタイム分析は、データの発生から分析までの時間が秒単位から分単位の処理を指す。時間単位・日単位のバッチ処理と対比される概念。

代表的なユースケース:

| ユースケース | 内容 |
|-------------|------|
| **異常検知** | デバイスの故障予兆を即時検知して対処を判断 |
| **パーソナライゼーション** | 初回訪問者のコンテンツ閲覧に基づくリアルタイムレコメンド |
| **ルート最適化** | 渋滞などのリアルタイム情報から即時に最適交通ルートを再計画 |
| **広告最適化** | タイムセール中のクーポン・広告配信のリアルタイム最適化 |
| **コンテンツ分析** | ライブ配信中の視聴者反応分析によるコンテンツ動的変更 |
| **リアルタイムKPI** | コンバージョン数をユーザーにリアルタイム表示して行動促進 |

### リアルタイム分析基盤の要件

分析基盤の4機能（収集・処理・蓄積・分析）に加えて以下が必要:

- **安定的な収集**: 発生するデータを継続的に収集し続ける（メッセージング）
- **ストリーミング処理**: 収集データを逐次区切りながら整形・集計・保存をリアルタイムに実行
- **即時蓄積**: 処理データをリアルタイムに蓄積してユーザーが分析可能な状態に保つ
- **スケーラビリティ**: 突発的な負荷変動に自動対応できる柔軟性

### Google Cloudにおけるアーキテクチャ

各要件に対するGoogle Cloudサービスのマッピング:

```
データの発生源 → Pub/Sub → Dataflow → BigQuery → 分析者・BIツール
```

| 要件 | サービス | 役割 |
|------|---------|------|
| 収集・メッセージング | **Pub/Sub** | スケーラブルなメッセージキューイング |
| ストリーミング処理 | **Dataflow** | Java/Pythonで実装したパイプラインを分散実行 |
| 蓄積・分析 | **BigQuery** | ストリーミング挿入対応のフルマネージドDWH |

---

## Pub/Sub

### 基本概念

Pub/Subは、パブリッシャーとサブスクライバーを仲介するマネージドメッセージングサービス。Googleが自社サービスのインフラで利用している実績を持ち、1秒あたり5億件以上・総計1TB/秒以上のデータ送信に対応している。

**主要コンポーネント**:

| 要素 | 説明 |
|------|------|
| **メッセージ** | データ本体（任意のテキスト/バイナリ）＋属性（Key-Value型メタ情報） |
| **トピック** | メッセージを受信する名前付きリソース |
| **サブスクリプション** | メッセージを配信するための名前付きリソース（1つのトピックに紐づく） |
| **パブリッシャー** | 指定トピックにメッセージを配信する送信者 |
| **サブスクライバー** | サブスクリプションからメッセージを受信する受信者 |

**サブスクリプション配信方式**:

- **Pull型**: サブスクライバーが任意のタイミングでメッセージを取得
- **Push型**: 指定エンドポイントにPub/Sub側からメッセージを配信
- **エクスポートサブスクリプション**: BigQueryやCloud Storageへ直接出力（後述）

**主要仕様**:

| 仕様 | 説明 |
|------|------|
| **グローバルデータアクセス** | 最寄りリージョンに保管。障害時は次のリージョンへ自動転送 |
| **リージョン制限** | ロケーション制限ポリシーで特定リージョンに限定可能（例: 東京のみ） |
| **メッセージ複製** | 複数ディスクに複製。Ackまたは有効期限切れまで永続化 |
| **シャード管理不要** | サービス側でスケールするためクライアント側のパーティション管理不要 |

### スキーマの適用

**スキーマドリフト問題**: 送信側が異なる開発チームの場合、想定外の型のメッセージが流れてくる問題。後続処理でエラーの原因となる。

**Pub/Subスキーマの設定**:

- Apache Avro形式またはプロトコルバッファ形式で定義
- 1つのスキーマを複数トピックに関連付け可能
- スキーマに準拠しないデータはパブリッシュ不可 → データガバナンス向上

**スキーマのバージョン管理（リビジョン）**:

- スキーマあたり最大20リビジョンを保持
- トピックに許容するリビジョン範囲を指定可能
- 旧スキーマと新スキーマを同時に許容する移行期間を設けることができる
- すべてのパブリッシャー・サブスクライバーの移行完了後、最新スキーマのみ許容に更新

```yaml
# Pub/Subトピックのスキーマ定義例（YAML形式）
- column: event_timestamp
  type: TIMESTAMP
  mode: REQUIRED
- column: payload
  type: STRUCT
  subcolumns:
    - column: sales_number
      type: INT64
    - column: sales_datetime
      type: STRING
    - column: department_code
      type: INT64
```

### メッセージの重複と順序

**配信保証モデル**:

| モデル | 説明 | 設定方法 |
|--------|------|---------|
| **At-least-once**（デフォルト） | 少なくとも1回配信。重複の可能性あり | デフォルト動作 |
| **Exactly-once** | 1回限りの配信。重複なし | Pull型サブスクリプションのオプションで有効化 |

**重複排除の設計パターン**:

1. **Pub/SubのExactly-once**: Pub/SubがメッセージIDで重複排除
2. **DataflowのExactly-once**: Dataflowがユーザー付与のユニークIDで重複排除（Pub/Sub以外の処理系や独自IDで重複排除したい場合に有効）

**メッセージの順序保証**:

- デフォルト: 受信した順序と異なる順序で配信される可能性あり
- **メッセージの順序指定機能**: 指定キーに基づく配信順序を有効化可能
- **注意**: 順序指定はレイテンシの劣化とトレードオフ

### エクスポートサブスクリプション

データ変換なしでPub/Subメッセージをリアルタイムに外部サービスへ直接出力する特殊なサブスクリプション。シンプルな収集パイプラインを簡単に構築できる。

**BigQueryサブスクリプション**:

- 対象トピックのデータを指定BigQueryテーブルにリアルタイム直接書き込み
- スキーマを考慮した構造化データを即座に分析可能な状態で格納
- スキーマ指定方法: Pub/Subスキーマ利用 or BigQueryテーブルスキーマ利用
- スキーマなし: `data`カラムにメッセージデータを格納

```bash
# Pub/SubサービスアカウントにBigQuery データ編集者の権限を付与
PROJECT_ID=$(gcloud config get-value project)
PUBSUB_SA="service-$(gcloud projects describe $PROJECT_ID \
  --format='value(projectNumber)')@gcp-sa-pubsub.iam.gserviceaccount.com"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${PUBSUB_SA}" \
  --role="roles/bigquery.dataEditor"
```

**Cloud Storageサブスクリプション**:

- 指定バケット・ファイル名・ファイルフォーマットでマイクロバッチ格納
- データ格納間隔: 最小1分〜最大10分で指定
- ファイルフォーマット: テキスト or Apache Avro形式

> **使い分け**: データ変換が必要な場合はDataflowを利用。変換不要なシンプルな収集のみならエクスポートサブスクリプションが適切。

---

## Dataflow

### 概要

Dataflowは、大規模データの分散処理を実行できるフルマネージドサービス。Apache Beamプログラミングモデルに則って実装し、複数のCompute Engine上で分散実行される。

- **対応言語**: Java、Python、Go
- **処理タイプ**: バッチ処理・ストリーミング処理の両方に対応
- **スケーリング**: 処理負荷に応じて自動スケールアウト
- **I/Oコネクタ**: Pub/Sub、BigQuery、Cloud Storageなど標準提供

### パイプライン

Dataflowにおける一連のデータ処理の単位を**パイプライン**と呼ぶ。

**基本構成要素**:

| 要素 | 説明 |
|------|------|
| **PCollection** | パイプラインで扱うデータのコレクション |
| **Transform** | 入力PCollectionに処理を施し、別のPCollectionを出力 |
| **I/Oコネクタ** | 外部サービスとのデータ入出力（Cloud Storage、Pub/Sub、BigQueryなど） |

```python
# バッチパイプラインの実装例（ワードカウント）
with beam.Pipeline(options=pipeline_options) as p:
    lines = p | ReadFromText(known_args.input)
    counts = (
        lines
        | 'Split' >> beam.FlatMap(lambda x: re.findall(r'[A-Za-z\']+', x))
        | 'PairWithOne' >> beam.Map(lambda x: (x, 1))
        | 'GroupAndSum' >> beam.CombinePerKey(sum)
    )
    counts | WriteToText(known_args.output)
```

```bash
# Dataflowジョブの実行
python wordcount.py \
  --project $PROJECT_ID \
  --job_name=wordcount \
  --region='us-central1' \
  --runner DataflowRunner \
  --input gs://$PROJECT_ID-bucket/input.csv \
  --output gs://$PROJECT_ID-bucket/output
```

### ストリーミング処理

バッチ処理と異なり、ストリーミング処理では止むことなく発生し続けるデータを逐次処理する。

**ストリーミングパイプラインの有効化**:

```python
# streaming=Trueでストリーミングジョブを有効化
pipeline_options = PipelineOptions(pipeline_args, streaming=True)
```

#### ウィンドウ

ストリーミングデータを一定範囲で分割する仕組み。3種類のウィンドウが利用可能:

| ウィンドウ種別 | 説明 | ユースケース |
|--------------|------|-------------|
| **タンブリングウィンドウ** | 一定時間間隔で分割（重複なし） | 毎分の集計、定期レポート |
| **ホッピングウィンドウ** | 開始時刻をずらしてウィンドウを重複させる | 移動平均、スライディング集計 |
| **セッションウィンドウ** | データの途切れ（ギャップ期間）で区切る | ユーザーセッション単位の集計 |

```python
# タンブリングウィンドウ（60秒）でストリーミングデータを集計
counts = (
    lines
    | 'Split' >> beam.FlatMap(lambda x: re.findall(r'[A-Za-z\']+', x))
    # beam.WindowIntoで60秒のタンブリングウィンドウを生成
    | beam.WindowInto(window.FixedWindows(60, 0))
    | 'PairWithOne' >> beam.Map(lambda x: (x, 1))
    | 'GroupAndSum' >> beam.CombinePerKey(sum)
)
```

#### ウォーターマークとトリガ

**2つの時間軸**:

- **イベント時間**: データが発生した時刻
- **処理時間**: DataflowでデータがActuallyに処理された時刻

ネットワーク遅延などにより、イベント時間と処理時間は基本的に乖離する。

**ウォーターマーク**: 「このイベント時間以前のデータはすべて届いている」という内部基準値。ウォーターマークがウィンドウの終了時間を超えたら処理結果を出力する。

**遅延データの扱い**:

- デフォルト: ウォーターマーク通過後に届いた遅延データは破棄
- **トリガ機能**: 遅延データの扱いをコントロール可能

**トリガの設定オプション**:

| トリガタイプ | 説明 |
|------------|------|
| **イベント時間** | 指定イベント時間が過ぎたら出力 |
| **処理時間** | 指定処理時間が過ぎたら出力 |
| **データの数** | 指定件数のデータが集まったら出力 |

> **設計ポイント**: データの完全性（全データを揃える）と即時性（速報値を出す）のバランスをトリガで設計する。遅延が発生しうるデータは、速報→最終値という2段階出力パターンが有効。

### テンプレート

Googleが提供するDataflowテンプレートを使うと、コードを書かずにデータパイプラインを実装できる。

**主要テンプレート**:

| テンプレート | 処理内容 |
|-------------|---------|
| **Pub/Sub to BigQuery** | Pub/SubサブスクリプションからBigQueryへストリーミング格納 |
| **Cloud Storage to BigQuery** | GCSファイルの変更検知・新規検知してBigQueryへストリーミング格納 |
| **JDBC to BigQuery** | データベーステーブルからBigQueryへバッチ格納 |

コンソールのWeb UIからパラメータを設定するだけでジョブを実行可能。独自テンプレートも作成でき、開発スキルを持たないメンバーへの定型パイプライン提供などの運用ができる。

### Dataflow Prime

Dataflow PrimeはApache BeamパイプラインをよりサーバーレスなGoogleマネージドで実行できる新しい利用方法。

**従来のDataflowとの違い**:

| 機能 | 従来のDataflow | Dataflow Prime |
|------|--------------|----------------|
| マシンタイプ指定 | 必要 | 不要 |
| メモリ不足時 | 手動でスケールアップして再実行 | 自動的に大きなワーカーで再実行 |
| スケーリング方向 | 水平スケーリング | 水平＋垂直スケーリング |
| 課金モデル | vCPU・メモリ時間 | DCU（Data Compute Unit）ベース |

**垂直スケーリング機能**:

- **垂直自動スケーリング（ストリーミングジョブのみ）**: メモリ不足・過剰割当を検知し自動調整
- **Right Fitting**: パイプラインのステップごとにリソースヒントで適切なワーカーサイズを指定

```bash
# Dataflow Primeを有効化するオプション（Apache Beam Python SDK 2.29.0以下）
--dataflow_service_options=enable_prime
```

> **Dataflow Prime適用場面**: 要求メモリが予測しづらい新規ジョブや、メモリ要求が変動する既存ジョブ。コードの修正なしに実行時オプションの変更のみで利用可能。

### Dataflow SQL

DataflowをSQLで操作できる機能。Apache BeamのコードをSQLで代替し、ストリーミングパイプラインを構築できる。

**特徴**:

- BigQueryコンソール画面から「Cloud Dataflowエンジン」を選択してSQLを実行
- BigQuery SQLに親しみのあるユーザーが入門しやすい操作感
- Pub/Subトピックをインプットとして扱うためには、トピックにスキーマを割り当てる必要がある

**Dataflow SQL向けPub/Subスキーマ割り当て手順**:

```bash
# スキーマ定義ファイル（topic_schema.yaml）を作成後、コマンドで割り当てる
# コンソール画面からは設定できないためCLIを利用

# トピック作成
gcloud pubsub topics create sales

# スキーマ割り当て（コマンドラインで実行）
gcloud data-catalog tag-templates ...
```

---

## BigQueryのリアルタイム取り込み

### Storage Write API

BigQueryへのデータ取り込みに利用する高スループットAPI。ストリーミング挿入とバッチ読み込み両方に対応。

**Storage Write APIの改善点（従来ストリーミングAPIとの比較）**:

| 改善点 | 内容 |
|--------|------|
| **1回限りの書き込み** | ストリームオフセットにより真のExactly-once書き込みを実現（従来は最大1分間のベストエフォート重複排除のみ） |
| **高スループット** | gRPCストリーミング＋プロトコルバッファ形式でUSマルチリージョンで最大3GB/秒 |
| **統合型API** | ストリーミング挿入もバッチ読み込みも同一APIで実装・運用の負担軽減 |
| **低コスト** | 従来比で半分のコストでストリーミング挿入を実現 |
| **DMLサポート** | 書き込み後すぐにUPDATE/DELETE/MERGEが利用可能（従来は30分の制限あり） |

**Pub/Sub BigQueryサブスクリプション**やApache BeamのBigQuery I/OコネクタでもStorage APIが内部的に利用されている。従来型APIで実装したパイプラインがある場合は乗り換えを検討する価値がある。

### BigQueryへのストリーミング挿入の考慮点

**バッチ方式とストリーミング方式の比較**:

| 方式 | 特徴 | コスト |
|------|------|--------|
| **バッチ方式** | ファイル/DBから一括読み込み、処理完了後にテーブル反映 | **無料** |
| **ストリーミング方式** | 1レコードずつリアルタイム取り込み、即時分析可能 | **有料**（米国マルチリージョン: 200MBあたり$0.01、最小1KBで課金） |

**バッチ方式のQuota制限**（ストリーミング移行の判断基準）:

| Quota | 制限値 |
|-------|-------|
| 宛先テーブルの日次更新回数 | テーブルごとに1,000回/日 |
| テーブルあたり読み込みジョブ数 | 1,000回/日（失敗含む） |
| プロジェクトあたり読み込みジョブ数 | 100,000回/日 |
| テーブルごとのDMLステートメント合計 | 1,000回/日 |

> **判断例**: 1テーブル1データソースの場合、10分ごとの更新で144回/日となりQuota内。複数テーブル・複数ソースになると超過リスクが高まりストリーミング方式を検討。

---

## マテリアライズドビューとBI Engineの活用

### マテリアライズドビュー

常に実体化されたビューを作る機能。通常のビューよりクエリパフォーマンスが高く、リアルタイムデータの整形・品質保証に有効。

**リアルタイム分析での活用**:

- **ストリーミング挿入に対応**: 元テーブルがリアルタイムに更新されても常に最新データを取得可能
- **定型処理の実装先**: 欠損データの排除・フォーマット統一などをマテリアライズドビューに実装
- **パフォーマンス**: BigQueryのリソースを使った再計算なしに高速クエリが可能

```sql
-- マテリアライズドビューの作成例（ストリーミングデータへの対応）
CREATE MATERIALIZED VIEW my_dataset.mv_rides_summary AS
SELECT
  TIMESTAMP_TRUNC(timestamp, MINUTE) AS window_start,
  ride_status,
  COUNT(*) AS count
FROM my_dataset.taxi_rides
WHERE ride_status IN ('pickup', 'dropoff')
GROUP BY 1, 2;
```

### BigQuery BI Engine

BIツール向けのメモリ内分析サービス。専用メモリ容量を購入することで、BIツールからのデータ参照をメモリ内処理で高速化する。

**リアルタイム分析でのコスト効果**:

- 通常、BIツールはBigQueryのクエリキャッシュ・BIツール自身のキャッシュを利用できる
- ただし、**リアルタイムで最新データを参照する場合はキャッシュが利用できない**
- オンデマンド課金では毎回クエリが実行されコストが増大
- BI Engineは予約メモリ容量に対する固定コストのため、頻繁なクエリ実行でも費用が増加しない

**BigQueryエディション利用時のBI Engine活用**:

- エディションでも頻繁なクエリ実行時に費用を固定できる
- BI Engineを組み合わせることでさらに効率的にクエリの並列処理数を増加・スロットを節約

---

## ストリーミングアーキテクチャ比較（2パターン）

BigQueryへのストリーミングデータ取り込みには、主に以下の2パターンがある。

### パターン比較

| 観点 | パターンA: BigQueryでJOIN | パターンB: DataflowでJOIN |
|------|--------------------------|--------------------------|
| **構成** | Pub/Sub → Dataflow → BigQuery（ストリーミングデータ） → ビュー（JOIN） | Pub/Sub → Dataflow（JOIN済） → BigQuery → ビュー |
| **Dataflow実装** | シンプル（JOINなし） | 複雑（JOIN処理を実装） |
| **クエリ速度** | ○（クエリ時にJOIN計算が発生） | ◎（JOIN済データを参照、BigQueryリソースをほぼ消費しない） |
| **スケーリング** | ◎（Dataflowがフルマネージドでスケール） | ◎（同上） |
| **実装容易さ** | ○（SQL/BeamのJOINが不要） | △（DataflowでのJOIN実装が必要） |
| **推奨場面** | 入門・シンプルなユースケース | 高頻度クエリ・分析パフォーマンス優先 |

### パターンA詳細: BigQueryでJOIN（推奨入門パターン）

```
[売上データ発生源]
      ↓
[Pub/Sub: データ集配]
      ↓
[Dataflow: 変換・整形のみ（JOINなし）]
      ↓
[BigQuery: ストリーミングデータテーブル]
      ↓
[BigQueryビュー: マスタデータとJOIN] ← [BigQueryマスタテーブル]
```

**特徴**:
- Dataflowはデータ変換・整形に集中しJOIN不要のためパイプライン実装がシンプル
- BigQueryでクエリ実行時に都度マスタデータとJOINするためクエリリソースを消費
- Dataflow SQLでも実装可能（SQL経験者が入門しやすい）

### パターンB詳細: DataflowでJOIN（パフォーマンス優先パターン）

```
[売上データ発生源]
      ↓
[Pub/Sub: データ集配]
      ↓
[Dataflow: 変換・整形 + BigQueryマスタとJOIN] ← [BigQueryマスタテーブル]
      ↓
[BigQuery: JOIN済みストリーミングデータテーブル]
      ↓
[BigQueryビュー: そのまま参照（JOINなし）]
```

**特徴**:
- Dataflow内でマスタデータとJOINするためパイプライン実装が複雑になる（Apache Beam習熟が必要）
- BigQueryへの書き込み時点でJOIN済みのため、ビュー参照時にBigQueryリソースをほぼ消費しない
- 分析クエリの速度が優れる（マテリアライズドビューに切り替えるとパターンAとの差はさらに縮まる）
- 高頻度クエリや分析パフォーマンスを優先する場合に有効

---

## 実践: リアルタイム分析基盤構築（タクシー位置情報）

### 全体構成

```
Pub/Sub（公開データセット）→ Dataflow（1分集計） → BigQuery（集計テーブル）→ Looker（ダッシュボード）
                         → Pub/Sub BigQueryサブスクリプション → BigQuery（生データテーブル）
```

### Pub/Subサブスクリプション作成

```bash
# Pub/Sub APIの有効化
gcloud services enable pubsub.googleapis.com

# ニューヨークタクシーのリアルタイム位置情報の公開トピックにサブスクリプション作成
gcloud pubsub subscriptions create streaming-taxi-rides \
  --topic=projects/pubsub-public-data/topics/taxirides-realtime
```

**データ仕様**:

```json
{
  "ride_id": "cca9ed95-6831-4cab-bd3b-7ac494cead4f",
  "point_idx": 384,
  "latitude": 40.77059,
  "longitude": -73.97581,
  "timestamp": "2024-05-02T03:06:07.95982-04:00",
  "meter_reading": 14.627054,
  "meter_increment": 0.038091287,
  "ride_status": "enroute",
  "passenger_count": 2
}
```

| フィールド | 説明 |
|-----------|------|
| `ride_id` | 乗車ごとのユニークキー |
| `ride_status` | `pickup`（乗車開始）/ `enroute`（乗車中）/ `dropoff`（降車） |
| `point_idx` | 乗車からの位置情報のシーケンス番号 |

### Dataflowストリーミングパイプライン実装

```bash
# 権限付与: Pub/Subサブスクライバー + BigQueryデータ編集者 + Dataflow管理者・ワーカー
ROLES="pubsub.subscriber pubsub.viewer bigquery.dataEditor dataflow.admin dataflow.worker"
for role in $ROLES; do
  gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member=serviceAccount:$GCE_SERVICE_ACCOUNT \
    --role=roles/$role
done
```

```python
# ストリーミングパイプライン実装例（nyc_taxi_streaming_analytics）

# 1. パイプライン生成（ストリーミングモード有効化）
pipeline_options = PipelineOptions(pipeline_args, streaming=True)

with beam.Pipeline(options=pipeline_options) as p:
    # 2. Pub/Subからデータ読み込み・JSON変換
    rides = (
        p
        | 'Read' >> ReadFromPubSub(subscription=subscription).with_output_types(bytes)
        | 'ToDict' >> beam.Map(json.loads)
    )

    # 3. 乗降車データのみフィルタ（enrouteを除外）
    rides_onoff = (
        rides
        | 'Filter' >> beam.Filter(
            lambda e: e['ride_status'] in ('pickup', 'dropoff')
        )
    )

    # 4. 60秒タンブリングウィンドウで集計
    rides_onoff_1m = (
        rides_onoff
        | beam.WindowInto(window.FixedWindows(60, 0))
        # ... カウント集計処理
    )

    # 5. BigQueryへストリーミング挿入
    rides_onoff_1m | 'Write' >> WriteToBigQuery('trips_1m', dataset=dataset)
```

```bash
# Dataflowジョブ実行
python nyc_taxi_streaming_analytics1.py \
  --project $PROJECT_ID \
  --job_name=nyc-taxi-streaming \
  --region=$REGION \
  --runner DataflowRunner \
  --streaming

# ジョブの停止
gcloud dataflow jobs cancel --region=$REGION $DATAFLOW_JOB_ID
```

---

## 関連リファレンス

| リファレンス | 内容 |
|------------|------|
| [DATA-PIPELINES.md](DATA-PIPELINES.md) | データパイプライン設計・Dataflowバッチ処理・ETL/ELTパターン |
| [DATA-WAREHOUSING.md](DATA-WAREHOUSING.md) | BigQuery DWH設計・パーティション・クラスタリング |
| [BIGQUERY-ANALYTICS.md](BIGQUERY-ANALYTICS.md) | BigQuery SQL分析・ウィンドウ関数 |
| [BIGQUERY-ADVANCED-OPERATIONS.md](BIGQUERY-ADVANCED-OPERATIONS.md) | BigQuery高度運用・パフォーマンスチューニング |
| [BI-VISUALIZATION.md](BI-VISUALIZATION.md) | Looker・Looker Studio・BI Engineでのデータ可視化 |
| [DATA-INGESTION.md](DATA-INGESTION.md) | BigQuery DTS・Datastream CDCによるデータ集約 |
