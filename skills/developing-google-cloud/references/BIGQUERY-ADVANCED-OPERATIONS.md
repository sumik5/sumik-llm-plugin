# BigQuery 高度運用リファレンス

BigQueryの内部アーキテクチャから本番運用まで、エンタープライズDWHとして活用するための高度な技術リファレンス。

---

## 1. 内部アーキテクチャ

### 1.1 BigQueryの誕生背景

Googleは検索エンジン事業を通じて世界最大規模のデータに向き合ってきた。Hadoop/MapReduceの課題（SQLが使えない、分析担当者が扱いにくい）を解決するためにDremelが開発され、2006年からGoogle社内のエンタープライズDWHとして利用開始。2010年にGoogle CloudのサービスとしてBigQueryが提供開始された。

### 1.2 コンポーネント全体像

BigQueryは以下の独立したコンポーネントで構成される。

```
API
  │
マスタ／スケジューラー／ジョブキュー
  │
ワーカー (Borg上のコンテナ)  ← クエリプランに応じて数百〜数万起動
  │
ハードウェアアクセラレーションネットワーク (Jupiter: 6 Pbps帯域)
  │
分散インメモリシャッフル
  │
分散ストレージ (Colossus)
  │
列指向ファイルフォーマット (Capacitor)
```

**一般的なDWHとの違い:**

| 項目 | 一般的なDWH | BigQuery |
|------|------------|---------|
| プロビジョニング | 事前に必要 | 不要（リージョン共有プール） |
| スケーリング単位 | コンピュート+ストレージ一体 | コンピュート/ストレージ/メモリ独立 |
| クラスタ管理 | ユーザーが管理 | Googleが全管理 |
| 課金単位 | 固定（インスタンス） | スキャン量またはスロット時間 |

### 1.3 Dremel クエリエンジン

**処理フロー:**
- ルートサーバーがクエリを受信し、分割して大量のリーフサーバーに配布
- リーフサーバーがColossusの分割データを並列処理
- ツリーアーキテクチャで結果を集約

```
[ルートサーバー]
     ↓ クエリ分割
[中間サーバー群]
     ↓
[リーフサーバー群]  ← Colossusの分割データを読み込み
```

目標: 1TB以上のテーブルスキャンを1秒以内で処理。

### 1.4 Colossus（分散ストレージ）

Google File System (GFS) の後継となる分散ファイルシステム。

- 大きなデータを分割し、別々の物理ディスクに複製して保存
- 選択されたリージョン内の複数ゾーンに自動レプリケーション
- 追記とスキャンに特化した設計（DWH用途に最適化）
- ユーザーはスケーリング（容量・I/O）を管理不要

### 1.5 Capacitor（列指向ファイルフォーマット）

BigQueryのネクストジェネレーション列指向ストレージフォーマット。

- データを列単位で圧縮格納
- 同一列には同一データ型が集まるため圧縮効率が高い
- 複数のCapacitorファイルをテーブルメタデータと束ねてテーブルとして表示
- データ更新ごとに差分ファイルが生成・配置される

**列指向のメリット:**
- SELECT対象列のみスキャン → スキャン量削減
- 列単位の圧縮・展開 → I/O効率向上
- 同一型データの集約 → 圧縮率向上

### 1.6 Jupiter（ネットワーク）

ワーカーと分散インメモリシャッフル／分散ストレージ間を結ぶ独自ネットワーク。

- ハードウェアアクセラレーションと独自プロトコルによる高速通信
- 2022年時点: 6 Pbpsの帯域幅をサポート
- ワーカー間の大量データ転送を支える屋台骨

### 1.7 分散インメモリシャッフル

**シャッフルとは:** GROUP BYなどの処理で特定のワーカーに特定のキーを寄せる処理。

**課題:** ワーカー数・キー数が増えるとメッシュ状のデータ移動でオーバーヘッドが増大し、ワーカー障害時はジョブが失敗する。

**BigQueryの解決策:** シャッフルを専用の巨大な分散インメモリシャッフル基盤に委託する。

メリット:
- メッシュ状通信オーバーヘッドを削減
- クエリの途中計算状態をインメモリ保管 → 高速読み出し
- ワーカー障害時も別ワーカーに再割り当てして継続（クエリ失敗なし）
- **投機的実行**: 遅いワーカーと同じタスクを別ワーカーでも並列実行し、早い方を採用
- スケールアウトで線形にスループット向上

### 1.8 マルチテナント方式

Googleがリージョンレベルで巨大なコンピュートリソースプールを事前確保し、クエリ発行時に動的割り当て。

- ユーザー側でのプロビジョニング不要
- クエリ実行時のみリソース消費 → オンデマンド課金が可能
- ワーカーはコンテナで起動し、終了後は破棄
- ストレージも同一リージョン内では全ユーザーで共有 → データサイロ化の防止

---

## 2. 課金モデル

### 2.1 コンピューティング課金の2モデル

**オンデマンド料金（TiB単位）:**
- デフォルトの課金モデル
- クエリが処理したバイト数（スキャン量）に基づいて課金
- 同時実行スロット数は最大2,000（ベストエフォート）
- SELECT * や LIMIT 句はスキャン量削減に寄与しない
- WHERE句・パーティションフィルタでスキャン量を減らすことがコスト削減に直結

**BigQueryエディション（スロット時間単位）:**
- クエリ実行に利用されたコンピューティング容量（スロット）に課金
- 大規模利用・予算コントロールに有利

### 2.2 ストレージ課金

- 論理バイト課金と物理バイト課金の2方式
- 90日間変更・削除がないデータは**長期ストレージ**として割引価格が適用
- タイムトラベル・フェイルセーフの課金方式:
  - 論理バイト課金: ストレージ料金に内包（追加コストなし）
  - 物理バイト課金: タイムトラベル・フェイルセーフのサイズも課金対象

### 2.3 コスト最適化のベストプラクティス

```sql
-- NG: SELECT * はすべての列をスキャン
SELECT * FROM `dataset.table`;

-- OK: 必要な列のみ指定
SELECT col1, col2 FROM `dataset.table`;

-- プレビューはクエリ料金不要（コンソール左ペインまたは bq head）
-- ドライランでスキャン量確認
bq query --dry_run --use_legacy_sql=false 'SELECT col1 FROM ...'

-- 課金上限の設定（上限超過クエリをエラーとして料金発生を防ぐ）
bq query --maximum_bytes_billed=1000000000 'SELECT ...'
```

---

## 3. BigQueryエディション

### 3.1 エディション概要

2024年10月時点の3エディション:

| エディション | SLA | 特徴 |
|------------|-----|------|
| Standard | 99.9% | 最大1,600スロット自動スケーリング、基本機能 |
| Enterprise | 99.99% | ベースライン+オートスケール（制限なし）、高度なワークロード管理 |
| Enterprise Plus | 99.99% | マネージドDR、顧客管理暗号鍵(CMEK)、データクリーンルーム |

### 3.2 エディション選定指針

- **利用開始時**: オンデマンド料金 または Standard エディション
- **複数プロジェクト展開・クリティカルバッチ・ML利用時**: Enterprise を検討
- **特殊要件時**: Enterprise Plus を検討
  - 顧客秘密鍵（CMEK）
  - Assured Workloads
  - マネージドディザスタリカバリー
  - データクリーンルーム

### 3.3 エディション機能差（主要機能）

| 機能 | Standard | Enterprise | Enterprise Plus | オンデマンド |
|-----|---------|-----------|----------------|------------|
| 列レベルアクセス制御 | ✗ | ✓ | ✓ | ✓ |
| 行レベルセキュリティ | ✗ | ✓ | ✓ | ✓ |
| 動的データマスキング | ✗ | ✓ | ✓ | ✓ |
| BI Engine | ✗ | ✓ | ✓ | ✓ |
| マテリアライズドビュー | クエリのみ | 作成・自動更新・スマートチューニング | 同左 | 同左 |
| 検索インデックス | ✗ | ✓ | ✓ | ✓ |
| BigQuery ML | ✗ | ✓ | ✓ | ✓ |
| マネージドDR | ✗ | ✗ | ✓ | ✗ |
| 容量コミットメント | ✗ | 1年/3年 | 1年/3年 | ✗ |
| クロスユーザーキャッシュ | ✗ | ✓ | ✓ | ✗ |

---

## 4. スロット管理とオートスケーリング

### 4.1 スロットとは

**スロット**: ワーカー上のコンピュートユニット。処理の並列度を表す。

クエリ実行時: 複数のスロットによる分散クエリとして実行。

### 4.2 スロットスケジューリングの4原則

1. **スロットのサイジングは主観的な目標値**: 足りなくても動作しない訳ではなく、クエリプランを自動調整して完了
2. **スロットの最適量はBigQueryが自動決定**: 多ければ必ず早くなるわけではない
3. **クエリプランは実行中も動的変化**: 途中で最適化が行われる
4. **フェアスケジューリング**: リソースを均等に割り当て、長時間占有を防ぐ

**スロット消費量の計算式:**
```
スロット消費時間 = 時間あたりスロット消費量 × かかった時間

例: 4,000スロット × 1秒 = 4,000スロット秒
   ↓ 実際は2,000スロットしかない場合
   2,000スロット × 2秒 = 4,000スロット秒（仕事量は同じ）
```

### 4.3 オートスケーリングの設定

BigQueryエディションでの予約（Reservation）設定:

```sql
-- 予約を作成（Enterpriseエディション、ベースライン500、最大1,000スロット）
CREATE RESERVATION `region-asia-northeast1.adhoc`
OPTIONS (
  slot_capacity = 500,          -- ベースライン
  autoscale_max_slots = 500,    -- オートスケール上限（ベースラインに加えて追加）
  edition = ENTERPRISE
);

-- 予約をプロジェクトに割り当て
CREATE ASSIGNMENT `region-asia-northeast1.adhoc`
OPTIONS (
  assignee = 'projects/my-project',
  job_type = 'QUERY'
);
```

**ベースラインとオートスケーリングの組み合わせ:**

- **最大予約サイズ = ベースライン**: オートスケールせず常に固定スロット。予算完全固定に向く
- **最大予約サイズ > ベースライン**: 負荷に応じて自動スケール。コスト効率と性能のバランス
- **容量コミットメント**: 1年・3年確約で費用削減

### 4.4 スロット使用量の確認

```bash
# ジョブIDの取得
bq --location=asia-northeast1 ls -j -n 20

# ジョブ詳細（totalSlotMsとelapsedMsを確認）
bq --format=prettyjson show -j <ジョブID>

# 平均スロット消費量 = totalSlotMs ÷ elapsedMs
```

### 4.5 ワークロード分離のパターン

**推奨構成例（プロジェクト分離 + 予約割り当て）:**

```
予約: batch-reservation    → バッチ処理プロジェクト
予約: adhoc-reservation    → アドホック分析プロジェクト
予約: critical-reservation → クリティカルバッチプロジェクト
```

---

## 5. 高可用性（HA）とDisaster Recovery

### 5.1 ゾーン内HA

BigQuery（Enterprise以上のオンデマンド料金）: **99.99% SLA**。

**ストレージ可用性:**
- テーブルデータを選択リージョン内の複数ゾーンに自動レプリケーション
- ゾーン内部のディスクをまたいだ分散レプリケーション
- ゾーン障害でもデータアクセス継続可能

**クエリ可用性:**
- マシンレベル障害: 数ミリ秒以下の遅延のみでクエリ失敗なし
- ゾーンレベル障害: 高速ゾーン切り替えでダウンタイムなし
- インメモリシャッフルに途中計算状態が保管されているため再割り当て即時完了

### 5.2 透過的なメンテナンス

BigQuery SLA条項に「メンテナンスウィンドウを除く」という条文が存在しない理由:

- ローリングアップデート方式: 利用していないワーカーから徐々にアップデート
- スロット追加・削除でもダウンタイムなし
- ユーザーの計画ダウンタイム調整は不要

### 5.3 Disaster Recovery計画

#### パターン1: クロスリージョンデータセットレプリケーション（全エディション対応）

```sql
-- データセットを東京リージョンに作成
CREATE SCHEMA my_dataset OPTIONS(location='asia-northeast1');

-- 大阪リージョンにレプリカを作成
ALTER SCHEMA my_dataset
ADD REPLICA 'asia-northeast2'
OPTIONS(location='asia-northeast2');
```

特徴:
- 東京（プライマリ）→ 大阪（セカンダリ）への非同期レプリケーション
- 合計: 2リージョン × 2ゾーン = 4ゾーンにデータが存在
- セカンダリは読み取り専用
- ターボレプリケーション: 15分以内でRPO達成を目指す

#### パターン2: マネージドディザスタリカバリー（Enterprise Plus限定）

```sql
-- 東京にEnterprise Plusの予約を作成（フェイルオーバー先:大阪を指定）
CREATE RESERVATION `region-asia-northeast1.dr-reservation`
OPTIONS (
  slot_capacity = 100,
  autoscale_max_slots = 0,
  edition = ENTERPRISE_PLUS,
  secondary_location = 'asia-northeast2'
);

-- データセットを予約に接続
ALTER SCHEMA replication_test_dataset
SET OPTIONS (
  failover_reservation = 'dr-reservation'
);

-- フェイルオーバー実行（大阪リージョンで実行）
ALTER RESERVATION `region-asia-northeast2.dr-reservation`
SET OPTIONS (is_primary = TRUE);
```

特徴:
- プライマリ障害時に自動フェイルオーバー
- DRサイト（大阪）のスロット料金も含む（追加DRコストなし）
- RTO短縮に有効

#### パターン3: BigQuery DTSによるデータセットコピー（簡易DR）

- BigQuery Data Transfer Service（DTS）でリージョン間を定期コピー
- 最短12時間ごとにコピー可能
- 最もシンプルなDR実現方法。データ転送料金とセカンダリのストレージコストが発生

#### DR方式の比較

| 方式 | RPO | RTO | コスト | 対象エディション |
|-----|-----|-----|--------|----------------|
| クロスリージョンレプリケーション | 15分以内 | 手動切替が必要 | ストレージ料金 | 全エディション |
| マネージドDR | 15分以内 | 自動フェイルオーバー | Enterprise Plusに含む | Enterprise Plus |
| BigQuery DTS | 最大12時間 | ほぼ即時 | 転送料金+ストレージ | 全エディション |

---

## 6. テーブル設計最適化

### 6.1 パーティション分割

パーティションごとにCapacitorファイルを分割し、クエリ時のスキャン範囲を限定する。

**パーティションの種類:**

| 種別 | キー | 用途 |
|------|------|------|
| カラムベース（日付） | DATE/TIMESTAMP列 | 時系列データ（主流） |
| カラムベース（整数） | INT64列（レンジ） | ID分割など |
| 取り込み時間 | データ取り込み日時 | レガシー手法、現在はあまり使わない |

```sql
-- 日付パーティションテーブルの作成
CREATE TABLE my_dataset.sales_records (
  dt TIMESTAMP,
  product_id STRING,
  customer_id STRING,
  quantity INT64
)
PARTITION BY DATE(dt)
OPTIONS (
  partition_expiration_days = 365  -- パーティション有効期限
);

-- パーティションを活用するクエリ（特定日のみスキャン）
SELECT product_id, SUM(quantity) AS total
FROM `my_dataset.sales_records`
WHERE DATE(dt) = DATE(2024, 1, 1)
GROUP BY product_id;
```

**特徴:**
- DML実行でパーティションが変わっても自動反映（再調整不要）
- パーティション有効期限設定でコスト自動最適化
- パーティション数に制限あり（テーブルメタデータオーバーヘッド）
- --dry-runのスキャン量見積もりが正確

### 6.2 クラスタ化

パーティション内のデータをクラスタリング列でソート・整理し、スキャン範囲をさらに絞る。

```sql
-- パーティション + クラスタ化テーブルの作成
CREATE TABLE my_dataset.sales_records (
  dt TIMESTAMP,
  product_id STRING,
  customer_id STRING,
  quantity INT64
)
PARTITION BY DATE(dt)
CLUSTER BY product_id, customer_id;  -- 最大4列指定可能（順序が重要）
```

**クラスタ化のルール:**
- パーティション分割テーブルにのみ適用（単体でも作成可能だが組み合わせが主流）
- 最大4列、指定順序でソート → 最初の列にフィルタが当たらないと効果薄い
- 対応型: INT64/STRING/DATE/TIMESTAMP/BOOL/NUMERIC/GEOGRAPHY など
- DML後はBigQueryがバックグラウンドで自動再クラスタリング（無料）
- --dry-runのスキャン量はパーティション恩恵のみ（実際はさらに少ない）

**パーティション vs クラスタ比較:**

| 項目 | パーティション | クラスタ |
|------|-------------|--------|
| 対象カラム数 | 1列 | 最大4列 |
| 対応型 | 時間・整数のみ | STRING含む多様な型 |
| 分割数制限 | あり | なし |
| スキャン量の事前見積もり精度 | 正確 | 過大見積もり（実際は少ない） |
| 向いているケース | 厳密なスキャン制限・有効期限設定 | 複数列フィルタ・集計クエリ |

**パーティション・クラスタの推奨機能:**
- 過去30日のワークロードをMLで分析し、大幅改善が見込める場合に推奨事項を生成
- 既存テーブルの構成改善も提案

### 6.3 マテリアライズドビュー

ベーステーブルへの変更を自動反映しつつ、クエリ高速化とスキャン量削減を実現する。

```sql
-- マテリアライズドビューの作成（パーティション + クラスタ可能）
CREATE MATERIALIZED VIEW my_dataset.daily_sales_mv
PARTITION BY DATE(dt)
CLUSTER BY product_id
OPTIONS (
  enable_refresh = TRUE,
  refresh_interval_minutes = 30,
  max_staleness = INTERVAL 1 HOUR  -- この期間内は古いデータを許容
)
AS SELECT
  DATE(dt) AS dt,
  product_id,
  SUM(quantity) AS total_quantity,
  COUNT(*) AS num_records
FROM my_dataset.sales_records
GROUP BY 1, 2;
```

**自動更新のしくみ（増分マテリアライズドビューの場合）:**

1. 作成後に非同期で全体更新（バックグラウンド）
2. INSERTのみの変更: 5分程度でマテリアライズドビューに反映
3. 未反映データがある場合: クエリ時に差分のみベーステーブルから取得して最新結果を返す
4. UPDATE/DELETE/MERGEまたは有効期限切れ: 対象パーティションのマテリアライズドビューを無効化し再構築

**スマートチューニング:**
ベーステーブルへのクエリでも、マテリアライズドビューが使えると判断した場合は自動でクエリを書き換えて利用。

**ビュー種別比較:**

| 種別 | パフォーマンス | ストレージ | 使えるクエリ | 更新方式 |
|-----|------------|---------|-----------|---------|
| クエリキャッシュ | ○ | なし | 全般（一意でないクエリは不可） | 自動無効化 |
| スケジュールクエリ+テーブル | ○ | あり | すべて | フルリフレッシュ |
| 論理ビュー | ✗ | なし | すべて | リアルタイム |
| マテリアライズドビュー | ◎ | あり | 集約・フィルタ・グループ化・結合 | 増分リフレッシュ |

### 6.4 検索インデックス

大量データからピンポイントでデータを抽出する場合に有効（Enterprise以上）。

```sql
-- 検索インデックスの作成（テキストアナライザを指定）
CREATE SEARCH INDEX my_index ON my_dataset.logs (log_text)
OPTIONS (analyzer = 'LOG_ANALYZER');  -- IP/メールアドレス向け

-- 全列インデックス（複雑なスキーマのログテーブルに便利）
CREATE SEARCH INDEX my_index ON my_dataset.logs (ALL COLUMNS);

-- SEARCH関数での全文検索
SELECT * FROM `my_dataset.logs` AS t
WHERE SEARCH(t, 'hello world');

-- = や IN での活用（透過的にインデックスを利用）
SELECT * FROM `my_dataset.logs`
WHERE log_text = '192.168.0.1';
```

**テキストアナライザの種類:**

| アナライザ | 特徴 | 向くケース |
|-----------|------|---------|
| LOG_ANALYZER（デフォルト） | IPアドレス・メールアドレスなど特定フォーマットのトークン化 | ログ分析 |
| PATTERN_ANALYZER | 正規表現でトークン化 | カスタムパターン |
| NO_OP_ANALYZER | テキストをそのままトークン化 | 完全一致のみ |

**インデックス活用確認:**
ジョブ情報でインデックスが使用されたか・使用されなかった理由を確認可能。

### 6.5 主キーと外部キー

**バリデーションなし**の制約（データの整合性チェックは行わない）。クエリオプティマイザーがJOINを最適化するために使用。

```sql
CREATE TABLE my_dataset.orders (
  order_id STRING NOT NULL,
  cust_id STRING,
  amount NUMERIC,
  PRIMARY KEY (order_id) NOT ENFORCED
);

CREATE TABLE my_dataset.customers (
  cust_id STRING NOT NULL,
  cust_name STRING,
  PRIMARY KEY (cust_id) NOT ENFORCED,
  FOREIGN KEY (cust_id) REFERENCES my_dataset.orders(cust_id) NOT ENFORCED
);
```

**最適化の種類:**

1. **内部結合解除**: orders列のみSELECTする場合、JOIN不要と判断してorders表のみスキャン
2. **外部結合解除**: LEFT JOINで1件一致が保証される場合もJOINを解除
3. **結合順序変更**: カーディナリティ情報を利用してオプティマイザーが結合順序を最適化

---

## 7. バックアップとリストア

### 7.1 タイムトラベル（7日以内の任意時点）

```sql
-- 10分前の状態でクエリ
SELECT *
FROM `dataset.table`
FOR SYSTEM TIME AS OF
TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL -10 MINUTE);

-- 特定時刻を指定（DML終了時刻より前を指定）
SELECT * FROM dataset.example
FOR SYSTEM TIME AS OF '2024-01-01 10:00:00+09:00';

-- CTASでバックアップテーブルを作成
CREATE TABLE dataset.example_restore AS
SELECT * FROM dataset.example
FOR SYSTEM TIME AS OF '2024-01-01 10:00:00+09:00';
```

**保管期間**: 2〜7日間（設定可能）

**テーブル削除後のリストア（bq CLI）:**
```bash
# 10分（600,000ミリ秒）前の状態からリストア
bq cp dataset.example@-600000 dataset.example
```

**フェイルセーフストレージ:**
- タイムトラベル期間終了後も7日間自動保管される緊急領域
- ユーザーはクエリ不可; サポートへの問い合わせで復旧
- 誤削除後にタイムトラベル期間が過ぎた場合の最後の砦

### 7.2 テーブルスナップショット（7日以上の長期バックアップ）

```sql
-- スナップショット作成（現時点）
CREATE SNAPSHOT TABLE dataset.example_snapshot
CLONE dataset.example;

-- タイムトラベルと組み合わせた過去時点のスナップショット
CREATE SNAPSHOT TABLE dataset.example_snapshot
CLONE dataset.example
FOR SYSTEM TIME AS OF '2024-01-01 10:00:00+09:00';

-- スナップショットからの復元（ベーステーブル上書き）
CREATE OR REPLACE TABLE dataset.example
CLONE dataset.example_snapshot;
```

**コピー・オン・ライト方式:**
- スナップショット作成時: ストレージ使用量ゼロ
- ベーステーブルへの変更があった場合のみ: 変更前データの差分のみ保存
- フルコピーと比較してストレージコストが大幅削減

**タイムトラベル vs テーブルスナップショット:**

| 項目 | タイムトラベル | テーブルスナップショット |
|-----|--------------|-------------------|
| 保管期間 | 最大7日 | 7日以上も可能 |
| ストレージコスト | 論理課金に内包 | コピー・オン・ライトで効率的 |
| 操作方法 | FOR SYSTEM TIME AS OF | CREATE SNAPSHOT TABLE |
| 用途 | 短期の誤操作リカバリ | 長期バックアップ |

---

## 8. トランザクションとDML最適化

### 8.1 MVCC（スナップショット分離）

BigQueryはMulti Version Concurrency Control (MVCC)を採用。

- 並行トランザクションのリード操作が他をブロックしない
- 並列性と整合性のバランスをとる

### 8.2 単一SQL文トランザクション

- DML文ごとに処理を確定（アトミック）
- 競合判定単位: テーブル内の同じパーティション
- 競合時: 最大3回自動リトライ
- 複数DML構成のバッチ処理で途中失敗 → 前の処理は確定したまま残る
- **幂等性のある設計が必須**（再実行しても同じ結果になるよう設計）

### 8.3 マルチステートメントトランザクション

```sql
BEGIN TRANSACTION;
  DELETE FROM dataset.intermediate WHERE DATE(dt) = '2024-01-01';
  INSERT INTO dataset.intermediate
    SELECT * FROM dataset.source WHERE DATE(dt) = '2024-01-01';
  MERGE dataset.daily_summary AS target
  USING dataset.intermediate AS source
  ON target.dt = source.dt AND target.product_id = source.product_id
  WHEN MATCHED THEN UPDATE SET total_quantity = source.total_quantity
  WHEN NOT MATCHED THEN INSERT VALUES (source.dt, source.product_id, source.total_quantity);
COMMIT TRANSACTION;
-- エラー時は全処理をBEGIN TRANSACTION時点にロールバック
```

**単一SQL vs マルチステートメントの選択:**

| 状況 | 推奨方式 |
|------|---------|
| 複数DMLで途中障害時に全ロールバックしたい | マルチステートメントトランザクション |
| 依存関係のない中間テーブルを並列処理したい | 単一SQLトランザクション（ジョブスケジューラで管理） |
| シンプルな実装を優先 | マルチステートメントトランザクション |
| 最大の並列度を確保したい | 単一SQLトランザクション |

**競合の注意点:**
- マルチステートメントトランザクション内で同じテーブルにDMLがある場合: キャンセル+ロールバック
- マルチステートメントトランザクション実行中に単一SQLのDMLが同テーブルへ: PENDING状態で待機

### 8.4 DML最適化の原則

BigQueryはOLAP用途。変更DMLには無視できないオーバーヘッドがある。

**更新DMLのオーバーヘッドが大きい理由:**
- UPDATE/DELETE/MERGE時: 更新対象行を含むファイルを変更行+残行のデータで再作成
- 少量データの頻繁なINSERT: 小さなCapacitorファイルが増加 → SELECTパフォーマンス一時的低下
- 同時実行制限: UPDATE/DELETE/MERGEは最大2並列、20ジョブキュー

**最適化戦略:**

1. **DMLをできるだけ大きなジョブにまとめる**
   - 細かいDMLを1つの大きなDMLに統合
   - パーティション内の処理をまとめることで競合リスク低減

2. **CTASによる洗い替えを優先する**
   ```sql
   -- NG: 更新系DMLの連続実行
   UPDATE dataset.daily_summary SET ... WHERE date = '2024-01-01';

   -- OK: 中間テーブルCTAS → 最終テーブルへ反映
   CREATE OR REPLACE TABLE dataset.intermediate AS
   SELECT * FROM dataset.source WHERE date = '2024-01-01';

   MERGE dataset.daily_summary AS target
   USING dataset.intermediate AS source
   ON target.date = source.date
   WHEN MATCHED THEN UPDATE SET ...
   WHEN NOT MATCHED THEN INSERT ...;
   ```

3. **中間テーブルに有効期限を設定**
   ```sql
   CREATE TABLE dataset.intermediate
   OPTIONS (expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR))
   AS SELECT ...;
   ```

---

## 9. パフォーマンスチューニング

### 9.1 クエリチューニング基礎

```sql
-- NG: SELECT * + LIMIT（スキャン量は全カラム分変わらない）
SELECT * FROM `dataset.table` LIMIT 100;

-- OK: 必要なカラムのみ選択
SELECT col1, col2, col3 FROM `dataset.table` WHERE condition LIMIT 100;

-- NG: ORDER BYを多用（並列処理ノードが限定される）
SELECT * FROM `dataset.large_table` ORDER BY created_at;

-- OK: サブクエリ結果に対してORDER BY
SELECT * FROM (
  SELECT col1, SUM(col2) AS total FROM `dataset.table`
  WHERE DATE(dt) = '2024-01-01' GROUP BY col1
) ORDER BY total DESC;
```

### 9.2 パーティション・クラスタの活用

```sql
-- パーティションフィルタを必須にする（安全装置）
ALTER TABLE `dataset.large_table`
SET OPTIONS (require_partition_filter = TRUE);

-- パーティション + クラスタを活用するクエリ
SELECT product_id, customer_id, SUM(quantity)
FROM `dataset.sales_records`
WHERE DATE(dt) BETWEEN '2024-01-01' AND '2024-01-31'  -- パーティション絞り込み
  AND product_id IN ('P001', 'P002')                    -- クラスタ絞り込み
GROUP BY product_id, customer_id;
```

### 9.3 STRUCT型・ARRAY型によるJOIN削減

```sql
-- 別テーブルのJOINをSTRUCT+ARRAYで回避
SELECT
  order_id,
  product.name AS product_name,
  version
FROM `dataset.orders`,
  UNNEST(products) AS product,
  UNNEST(product.versions) AS version;
```

### 9.4 キャッシュの活用

```sql
-- キャッシュを有効にして同一クエリを高速化
bq query --use_cache --use_legacy_sql=false 'SELECT ...'

-- キャッシュヒットの確認（コンソールの「キャッシュされた結果を使用」表示）
```

キャッシュが効かない場合:
- CURRENT_TIMESTAMP()などの非決定的関数
- テーブルデータが変更された場合
- ストリーミング挿入されたテーブル

### 9.5 一時テーブルの活用

```sql
-- サブクエリを一時テーブルに置き換えて繰り返しコスト削減
CREATE TEMP TABLE temp_result AS
SELECT product_id, SUM(quantity) AS total
FROM `dataset.sales_records`
WHERE DATE(dt) BETWEEN '2024-01-01' AND '2024-03-31'
GROUP BY product_id;

SELECT t.product_id, t.total, m.name
FROM temp_result t
JOIN `dataset.products` m ON t.product_id = m.id;
```

### 9.6 履歴ベースの最適化

```sql
-- プロジェクトレベルで有効化
ALTER PROJECT `my-project`
SET OPTIONS (
  `region-asia-northeast1.default_query_optimizer_options` = 'adaptive=on'
);

-- 適用状況の確認
SELECT job_id, query_info.optimization_details
FROM `region-asia-northeast1`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR);
```

過去の実行履歴から類似クエリを自動最適化。最初の実行後、2回目以降の実行時間を短縮できる場合がある。

---

## 10. BigQueryモニタリング

### 10.1 コンソールのモニタリング機能

**3つのビュー:**

1. **運用の健全性**: 組織全体のスロット使用状況・ジョブ同時実行・ジョブ所要時間の概要
   - ロケーション・予約ごとの詳細にドリルダウン可能
   - ライブデータ有効時: 5分ごとに自動更新

2. **リソースの活用**: 過去30日のリソース使用量を時系列で分析
   - プロジェクト・ユーザー・予約などの軸でフィルタ・グループ化
   - 実行中のジョブのキャンセルも可能

3. **ジョブエクスプローラー**: スロット時間・実行時間が閾値を超えるジョブを検出
   - クエリプランと実行グラフを確認
   - クエリ分析情報（スロット検出・メモリシャッフル容量）を表示

### 10.2 INFORMATION_SCHEMAによるモニタリング

```sql
-- 過去24時間の重いクエリTOP10
SELECT
  job_id,
  user_email,
  total_bytes_processed / (1024*1024*1024) AS processed_gb,
  total_slot_ms / 1000 AS slot_seconds,
  TIMESTAMP_DIFF(end_time, start_time, SECOND) AS elapsed_seconds,
  query
FROM `region-asia-northeast1`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
  AND state = 'DONE'
  AND job_type = 'QUERY'
ORDER BY total_slot_ms DESC
LIMIT 10;

-- スロット使用量の時系列（時間別集計）
SELECT
  TIMESTAMP_TRUNC(creation_time, HOUR) AS hour,
  SUM(total_slot_ms) / (1000 * 3600) AS total_slot_hours,
  COUNT(*) AS job_count
FROM `region-asia-northeast1`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
GROUP BY 1
ORDER BY 1 DESC;

-- 履歴ベース最適化の適用状況確認
SELECT
  job_id,
  query_info.optimization_details
FROM `region-asia-northeast1`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE query_info.optimization_details IS NOT NULL
  AND creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)
LIMIT 20;

-- パーティション・テーブルの情報確認
SELECT
  table_name,
  partition_id,
  total_rows,
  total_logical_bytes / (1024*1024*1024) AS size_gb,
  last_modified_time
FROM `my_dataset`.INFORMATION_SCHEMA.PARTITIONS
ORDER BY total_logical_bytes DESC;
```

### 10.3 Cloud Monitoring連携

```
# Stackdriver（Cloud Monitoring）での確認方法
リソース: BigQuery
メトリクス: Slot Utilization, Job Count, Scanned Bytes

# スロット使用量が常時高い場合の対処
→ BigQueryエディションの購入を検討
→ 同時実行クエリ数の制御
→ クエリのバッチモード化（--batch オプション）
```

### 10.4 主要なQuota（割り当て）

| 項目 | 制限値 |
|------|--------|
| インタラクティブクエリ同時実行数 | 100 |
| 宛先テーブルの日次更新回数 | 1,000回/テーブル/日 |
| クエリ実行時間上限 | 6時間 |
| 1クエリで参照できるテーブル最大数 | 1,000（ワイルドカードは1カウント） |
| UPDATE/DELETE/MERGEの同時実行 | 最大2（20ジョブまでキュー） |
| オンデマンド料金の同時実行スロット | 2,000（ベストエフォート） |

---

## 11. 移行とモダナイゼーション

### 11.1 他DWHからの移行

BigQuery Migration Serviceが利用可能:
- 対応ソース: Teradata、Redshift、Snowflake など
- SQL変換の自動化
- スキーマ移行の自動化
- パーティション・クラスタリングの推奨提案

### 11.2 Analytics Hub によるデータ共有

```
Analytics Hub = データ交換プラットフォーム

パブリッシャー: データセットを公開
データエクスチェンジ: カタログ的な役割
サブスクライバー: データを参照・利用

メリット:
- データをコピーせずにACL設定だけで組織横断共有
- データクリーンルーム（Enterprise Plus）で機密データの安全な分析
- データマーケットプレイス（外部組織への販売）
```

---

## 設計チェックリスト

### テーブル設計

- [ ] 日付・タイムスタンプ列でパーティション分割を設定しているか
- [ ] WHERE句に頻出するカラムでクラスタ化しているか（最大4列、順序を考慮）
- [ ] パーティション推奨機能・クラスタ推奨機能を定期的に確認しているか
- [ ] 繰り返し集計するケースでマテリアライズドビューを検討しているか
- [ ] 大量テキストデータからのピンポイント検索で検索インデックスを検討しているか
- [ ] JOIN最適化のために主キー・外部キーを設定しているか（バリデーションなし）

### 課金・コスト

- [ ] SELECT * を避け必要なカラムのみ選択しているか
- [ ] パーティションフィルタを使ってスキャン量を削減しているか
- [ ] --dry-runまたはコンソールでクエリサイズを事前確認しているか
- [ ] --maximum_bytes_billedで課金上限を設定しているか

### 可用性・DR

- [ ] クロスリージョンデータセットレプリケーションを設定しているか
- [ ] RTO/RPO要件に応じてDR方式を選択しているか
- [ ] タイムトラベル期間（2〜7日）を要件に合わせて設定しているか
- [ ] 長期バックアップ要件にテーブルスナップショットを使っているか

### 運用・モニタリング

- [ ] INFORMATION_SCHEMAで定期的に重いクエリを監視しているか
- [ ] BigQueryコンソールのモニタリング機能（運用の健全性・ジョブエクスプローラー）を活用しているか
- [ ] ワークロードマネジメントのためにBigQueryエディションの予約を適切に設定しているか
- [ ] DMLの幂等性を確保した設計になっているか
