# BigQuery ゲーム分析実践パターン

ゲーム運営におけるBigQueryを使ったデータ分析基盤の構築・運用ガイド。Aiming社の実運用事例を基に、ログ収集パイプライン・KPI設計・SQL実例・コスト管理を解説する。DWH設計原則（DATA-WAREHOUSING.md）との棲み分けとして、本書はゲーム固有のKPI・実践的SQL・コスト事例に集中する。

---

## ゲームログ分析の特性と課題

### なぜゲームのログ分析は難しいか

一般的なWebサービスと異なり、ゲームログ分析には固有の困難が伴う。

| 課題 | 内容 | 影響 |
|-----|------|------|
| **サイジング不可能** | ヒットするか事前に分からない | リリース前にシステム規模を確定できない |
| **ログ重要度の混在** | 課金ログ（低頻度・高重要）とバトルログ（高頻度・低重要）が混在 | 信頼性と処理量のトレードオフが発生 |
| **ログ仕様の頻繁な変更** | ゲーム改良に伴ってフォーマットが変わる | スキーマ固定システムで対応困難 |
| **タイトル数の多さ** | 複数タイトルを同一基盤で管理 | 導入コストを最小化できるシステムが必要 |

### 過去のアーキテクチャと課題

**Hadoop方式の課題:**
- 1回のSQL実行に5〜10分 → 1日4〜5個のKPI登録が限界
- 事前バッチ集計のため、データ修正時の再集計が必要

**MySQL方式の課題:**
- ログを丸めて保存するため、誤送信発生時の復旧が困難
- 過去の値が最新値を参照しているため、トラブル発生時点からの全ログ再集計が必要
- 数億件以上の集計には不向き

---

## BigQuery選定と分析ツール比較

### 主要分析ツール比較

| ツール | 特徴 | メリット | デメリット | 適したケース |
|-------|------|---------|----------|------------|
| **BigQuery** | Google SaaS型OLAP。数千台で並列集計 | 高速・安価・スキーマレス不要 | スキーマ事前定義必要・ストリーミングで欠け発生 | 大量ログの高速集計 |
| **Treasure Data** | Hadoop/Presto基盤のSaaS型 | 月額固定・ログ収集堅牢・スキーマレス | Hive集計が遅い・Presto集計はメモリ制限あり | 安定課金・スキーマレス優先 |
| **Amazon Redshift** | PostgreSQL互換の半マネージドDWH | PostgreSQL互換・更新/削除対応 | 正規表現/中間一致検索に不向き・インデックス管理必要 | PostgreSQL資産流用 |
| **MySQL** | 一般的なRDBMS | 知見蓄積・更新削除容易 | 数億件以上の集計に不向き | 小規模 |
| **MongoDB** | ドキュメント指向NoSQL | スキーマレス・手軽 | 大規模集計に不向き | ログの一時蓄積 |

### 各ツールの適切なデータ規模目安

| データ規模 | 推奨ツール |
|-----------|----------|
| 〜1億件 | MySQL / MongoDB |
| 1億〜数十億件 | Treasure Data / Amazon Redshift |
| 数十億件〜 | BigQuery |

### BigQueryを選ぶ判断基準

- **集計レスポンスが最優先**（数秒以内で返ってくること）
- 将来のヒット規模が読めない（スケールを意識しない設計が必要）
- 複雑なSQL集計（window関数・正規表現・中間一致）を多用する
- コストを従量制で管理できる（月額固定より柔軟性を優先）

---

## ログ収集パイプライン（fluentd + BigQuery）

### アーキテクチャ概要

ゲーム分析のデファクトスタンダードは「**fluentd + BigQuery**」の組み合わせ。Pub/Sub + Dataflowより構築コストが低く、BigQueryのUDF（User Defined Function）でETL処理が対応できる範囲が広い。

```
ゲームサーバ
    │
    ├── Fluentd（tail input / direct library）
    │       │
    │       └──→ BigQuery（streaming insert / load）
    │
    └── Embulk（バルクロード：MySQLダンプ等）
            │
            └──→ BigQuery（load）
```

### ログ送信方式の選択

| 方式 | 仕組み | メリット | デメリット | 推奨ケース |
|-----|--------|---------|----------|----------|
| **専用ログ収集サーバ経由** | ゲームサーバ → 集約サーバ → BigQuery | スキーマ変更時に1台修正で済む・管理容易 | 単一故障点・高負荷時にRubyが過負荷 | サーバ台数が少ない時 |
| **各ゲームサーバから直接** | ゲームサーバ100台 → BigQuery（分散） | 負荷分散・スケーラブル | confファイル管理が煩雑（Chef/Ansible必須） | 大規模展開（100台以上） |

### Fluentdの使い分け

```yaml
# リアルタイム送信（streaming insert）
- Fluentd + fluentd-bigquery-plugin
  - 直接ライブラリからの送信
  - in_tail プラグインでゲームログをtailして送信（ゲームロジック改修不要）

# バルクロード（大量一括）
- Embulk（MySQL→BigQuery等の一括ロード）
- 自作アップローダ（Resumable upload対応、整合性保証が必要なケース）
```

### Fluentd既知の不具合と対処

| 不具合 | 原因 | 対処 |
|-------|------|------|
| ストリーミングinsertでのログ欠け（3000万件に2000件程度） | fluentd-bigquery-pluginとBigQuery間の問題 | 前日テーブルを一旦削除してload方式で入れ直す |
| in_tailで日付ファイル切替時に先頭行が読み込まれない | Fluentd設定ミス | `read_from_head: true` を設定 |

---

## データ収集設計

### スキーマ定義方針

| アプローチ | 内容 | 推奨度 |
|-----------|------|-------|
| **全カラム展開** | 各フィールドを個別カラムで定義 | ✅ 推奨（集計効率が高い） |
| JSON文字列で全部入れる | STRING型に全てJSONで格納 | ❌ 非推奨（カラムナー型の効率が下がる・SQLが複雑化） |
| record型（配列/辞書型） | BigQueryのNESTED型を使用 | ⚠️ 要注意（NULL処理でエラーが発生しやすい） |

**設計原則:**
- 基本情報（発生時刻・user_id・platform・world_id等）はカラム別に保存
- 複雑なデータはSTRING型のJSONに入れる（スキーマ変更の柔軟性を確保）
- record型は使わない（NULLによるエラーが多い）

### 売上情報の標準スキーマ例

| フィールド | 型 | 説明 |
|-----------|-----|------|
| `user_id` | INTEGER | ユーザID |
| `time` | TIMESTAMP | イベント発生時刻（UTC） |
| `registered_time` | TIMESTAMP | ユーザ登録時刻 |
| `platform` | STRING | iOS / Android |
| `pay_cp` | INTEGER | 課金額 |
| `item_id` | INTEGER | 課金アイテムID |

### 時刻の扱い

BigQueryの時刻はUTC基準。JST（+9時間）への変換が必要。

```sql
-- JSTで12:00〜19:00のデータを取得
WHERE 12 <= DATE_ADD(time, -9, 'HOUR')
  AND DATE_ADD(time, -9, 'HOUR') < 19
```

**注意事項:**
- RubyのDatetime型をJSON化すると「+0900」形式で出力される
- BigQueryでは「+09:00」形式のみ読み込み可能 → epochタイムスタンプ形式での送信が安全

### テーブル分割戦略

Aimingの基本方針：**アクション単位 × 日付単位**の二重分割

```sql
-- テーブル命名規則
login_20151201, login_20151202, ...
get_cp_20151201, get_cp_20151202, ...

-- 日付範囲での横断集計
TABLE_DATE_RANGE(production.login, timestamp('2015-01-01'), current_timestamp())
```

| 分割方法 | 目的 | 効果 |
|---------|------|------|
| **アクション単位** | ガチャ・ログイン・課金を別テーブルに | 不要なカラムをスキャンしない → コスト削減 |
| **日付単位** | テーブル名に日付サフィックス | 特定期間のみスキャン可能 → コスト削減 |

**注意点:**
- テーブルが多いと集計に1テーブルあたり5msec加算される（1000日=5秒）
- 1SQLで集計できるテーブル上限は1000件（3年超えのサービスで日付分割すると問題になる）

### ユーザデータ・マスタデータの統合

行動ログとユーザデータを結合して分析する際（例：レベル分布とログイン頻度の相関）、MySQLからBigQueryへのロードが必要。

```
-- テーブル命名規則
user_info_20151210（ダンプした日付を付与）
→ 古いテーブルは定期削除
→ BigQueryはストレージ単価が安いため、過去分も保持するのが推奨
```

---

## KPI設計とユースケース

### ゲームKPIの体系

ゲームKPIには2つの軸がある：「ユーザ定着」と「課金行動」

#### 経営・運営向けKPI

| KPI | 定義 | 目的 |
|-----|------|------|
| **DAU** (Daily Active Users) | 日次ユニークアクティブユーザ数 | ゲーム規模の基本指標 |
| **DAU（新規除く）** | DAUから当日新規登録者を引いた値 | 定着ユーザ数の把握（キャンペーン効果除去） |
| **FQ5** | 5日間連続ログインユーザ数 | 真の定着度指標（DAUの変動ではなくコアユーザを捉える） |
| **継続率** | 一定期間後もプレイを続けているユーザの割合 | ゲームの長期的な魅力度 |
| **売上** | 期間内課金総額 | ビジネス成績 |
| **顧客単価（ARPPU）** | 課金ユーザ1人あたりの平均収益 | 課金ユーザの消費行動 |
| **MRPPU** | ARPPUの中央値（Median） | 高額課金者の影響を除去した実態把握 |
| **有料/無料ポイント消費者数** | 各種ポイント消費者のユニーク数 | 課金ファネルの健全性 |

#### マーケティング向けKPI

- 登録月別アクティブユーザ数（コホート分析）
- 登録月別課金額・課金者数
- 媒体・キャンペーン別の定着率・課金率

#### 企画・運営向けKPI

- チュートリアル突破率
- クエスト達成状況・難易度別クリア者数
- ガチャ消費者数・アイテム別消費数
- イベント効果測定（グラフへのイベント日時オーバーレイ）
- ユーザ分布（レベル・総合力）

#### ユーザサポート向け機能

BigQueryに全行動ログを蓄積することで「アイテムがいつ取得・使用・強化されたか」を追跡でき、ユーザからの問い合わせをエビデンスベースで対応可能。

---

## SQL実例集

### テーブル構造（前提）

```
-- loginテーブル（日付分割）: production.login20150101, login20150102, ...
user_id | time
3       | 2015-01-02 12:15:30 UTC

-- get_cpテーブル（日付分割）: production.get_cp20150101, ...
user_id | time                      | pay_cp
3       | 2015-01-02 12:15:30 UTC   | 100
```

### DAU（日次アクティブユーザ数）

```sql
SELECT
  EXACT_COUNT_DISTINCT(user_id) AS dau,
  STRFTIME_UTC_USEC(DATE_ADD(time, 9, 'HOUR'), '%Y-%m-%d') AS date
FROM TABLE_DATE_RANGE(production.login,
    TIMESTAMP('2015-01-01'),
    CURRENT_TIMESTAMP())
GROUP BY date
ORDER BY date;
```

**ポイント:**
- `EXACT_COUNT_DISTINCT()`: 重複除去カウント（MySQLの `COUNT(DISTINCT user_id)` 相当）
- `TABLE_DATE_RANGE()`: 日付分割テーブルを横断集計（UNION ALL相当）
- `DATE_ADD(time, 9, 'HOUR')`: UTCからJSTへ変換

### FQ5（5日間連続ログインユーザ数）

```sql
SELECT
  EXACT_COUNT_DISTINCT(user_id) AS value,
  STRFTIME_UTC_USEC(date, '%Y-%m-%d') AS date
FROM (
  SELECT
    user_id,
    date,
    COUNT(*) OVER (
      PARTITION BY user_id
      ORDER BY date
      RANGE BETWEEN 4 * 24 * 60 * 60 * 1000000 PRECEDING AND CURRENT ROW
    ) AS cnt
  FROM (
    SELECT
      user_id,
      UTC_USEC_TO_DAY(DATE_ADD(time, 9, 'HOUR')) AS date
    FROM TABLE_DATE_RANGE(production.login,
        TIMESTAMP('2015-01-01'),
        DATE_ADD(CURRENT_TIMESTAMP(), 9, 'HOUR'))
    GROUP BY user_id, date
  )
)
WHERE cnt = 5
GROUP BY date;
```

**ポイント:**
- window関数（`COUNT(*) OVER (PARTITION BY user_id ...)`）で各ユーザの直近5日間のログイン日数を計算
- `WHERE cnt = 5`: ちょうど5日間連続ログインのユーザのみ抽出
- DAUよりコアユーザの定着を正確に捉えられる

### MRPPU（課金額中央値）

```sql
SELECT
  INTEGER(NTH(50, QUANTILES(pcp))) AS value,
  date
FROM (
  SELECT
    STRFTIME_UTC_USEC(time, '%Y-%m-%d') AS date,
    SUM(pay_cp) AS pcp,
    user_id
  FROM TABLE_DATE_RANGE(production.get_cp,
      TIMESTAMP('2015-01-01'),
      DATE_ADD(CURRENT_TIMESTAMP(), 9, 'HOUR'))
  WHERE pay_cp > 0
  GROUP BY user_id, date
)
GROUP BY date
ORDER BY date;
```

**ポイント:**
- `QUANTILES(pcp)`: パーセンタイルを100分割して返す
- `NTH(50, ...)`: 50パーセンタイル = 中央値を取得（25で25%位、75で75%位）
- 高額課金ユーザの外れ値に引っ張られない指標として有用

### SQL Tips（BigQuery固有の注意点）

| 構文 | 用途 | MySQL相当 |
|-----|------|---------|
| `EXACT_COUNT_DISTINCT(col)` | 重複除去カウント | `COUNT(DISTINCT col)` |
| `TABLE_DATE_RANGE(table, start, end)` | 日付分割テーブルの横断集計 | `UNION ALL` |
| `STRFTIME_UTC_USEC(time, format)` | タイムスタンプを文字列に変換 | `DATE_FORMAT()` |
| `UTC_USEC_TO_DAY(time)` | タイムスタンプを日単位に丸める | `DATE(time)` |
| `COUNT(*) OVER (PARTITION BY ...)` | window関数 | MySQL 8.0以降で対応 |

---

## コスト管理・最適化

### BigQueryのコスト構造

コストは主に3つの要素から構成される：

| コスト種別 | 説明 | 削減方法 |
|-----------|------|---------|
| **分析（データスキャン）** | 実行したクエリがスキャンしたデータ量で課金 | テーブル分割・SELECT指定 |
| **データ保存** | テーブルに保存されているデータ量 | 古いテーブルの削除 |
| **ストリーミングインサート** | リアルタイムinsertの件数 | load方式への切替 |

### 実際のコスト事例（Aiming社）

| タイトル | ジャンル | 運用期間 | 月額コスト | 主なコスト要因 |
|---------|---------|---------|-----------|--------------|
| **タイトルA** | MMO-RPG | 2年 | 約70万円 | レコード7000億件。分析32%・保存39%・streaming25% |
| **タイトルB** | MMO-RPG | 3ヶ月 | 約1万円 | 開始直後。分析71%（再集計コスト主体） |
| **タイトルC** | カジュアルSPT | 2年 | 約5千円 | ログ量少。分析91%（運営期間の長さが影響） |
| **タイトルD** | MM-RPG | 1年 | 約3万円 | 複雑SQLが多い。分析94% |
| **タイトルE** | カジュアルRPG | 6ヶ月 | 約2万5千円 | アクション分割なし → 全テーブルスキャン。分析99% |

**教訓:**
- 長期タイトルでも一般的なタイトルは数万円オーダー
- タイトルE（アクション単位分割なし）はDの10倍近いコストになっている → テーブル分割が最重要

### コスト削減5つの手法

**1. テーブルをアクション単位・日付単位で分割する**
```sql
-- ❌ 非効率: 全アクションのテーブルを毎回スキャン
SELECT * FROM action_table WHERE action_type = 'gacha'

-- ✅ 効率的: ガチャのテーブルのみスキャン
SELECT * FROM TABLE_DATE_RANGE(production.gacha, ...)
```

**2. SELECTで読み込むカラムを限定する**
```sql
-- ❌ 非効率: カラム100個全て読み込む
SELECT * FROM action_table

-- ✅ 効率的: 必要なカラムのみ読み込む（カラムナー型の恩恵）
SELECT user_id FROM action_table WHERE world = 1
-- → user_idとworldの2カラムのみスキャン
```

**3. ストリーミングインサートからload方式への切替**
```
streaming insert: リアルタイム、コスト高
load方式: 1時間に1回バッチ、コストほぼゼロ
→ リアルタイム性が不要なログはload方式を推奨
```

**4. Cost Control（1日のスキャン量に上限設定）**
```
BigQuery Console → プロジェクト設定 → Cost Control
→ 1日あたりのスキャン量に上限を設定
→ 上限超過後はクエリ実行不可（意図しない課金防止）
```

**5. クエリ利用量可視化ツールの内製**
- BigQuery Ruby gem でジョブ一覧を取得
- 実行者別・SQL別のスキャン量を集計
- 高スキャンユーザに対してSQLの最適化を助言

### ストリーミングインサートのログ欠け対策

ストリーミングinsertでは3000万件に2000件程度の欠けが発生する可能性がある。

**対処策:**
```
1. テーブルを日付単位で分割してストリーミングで蓄積
2. 翌日に前日テーブルを一旦削除
3. ロード方式で全件入れ直し（完全性を保証）
→ リアルタイム性と完全性の両立
```

---

## 可視化・BIツール設計

### 内製BIツールの選択理由

Aimingでは市販ツール（Tableau等）を使わず内製を選択した。主な理由：

- 非エンジニア（企画・運営）が日常的に使うため日本語UIが必須
- 「週別」集計やイベントのグラフオーバーレイ表示など、ゲーム固有の機能が必要
- Tableauのユーザ単位課金では全員に展開しにくい

**内製で実現した機能:**
- 時間別・日次別・月別・**週別**集計
- イベント（「ポイント2倍キャンペーン」等）をグラフ上にオーバーレイ表示 → イベント効果の視覚的測定

### 集計システムのアーキテクチャ

```
【Aimingの基本方針】
・中間テーブルを作らない
・生ログから毎回全期間を集計する
→ データ修正が自動的に反映される
→ デメリット: 運営期間が長くなるほど集計コストが増加
→ 対策: 過去集計をキャッシュ化（要検討）
```
