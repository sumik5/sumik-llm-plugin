# Google Analytics (GA4) を MCP で分析する

`google` プラグインが同梱する **Google Analytics 公式 MCP サーバー (`analytics-mcp` / PyPI)** を使って、GA4 のアカウント・プロパティ情報の取得と、標準/ファネル/リアルタイムレポートの実行を行うためのガイド。

> このスキルは **読み取り専用の分析** を対象とする。認証スコープは `analytics.readonly` で、GA4 の設定変更・データ書き込みは行わない。

---

## 1. 全体像

| 項目 | 値 |
|------|-----|
| MCP サーバー名（本プラグイン内） | `google-analytics` |
| 起動コマンド | `pipx run analytics-mcp`（`bin/pipx-mise.sh` 経由） |
| PyPI パッケージ | `analytics-mcp`（コンソールスクリプト: `analytics-mcp` / `google-analytics-mcp`） |
| 必要 Python | 3.10 以上 |
| 認証 | Google Cloud Application Default Credentials (ADC) |
| 必要スコープ | `https://www.googleapis.com/auth/analytics.readonly` |

呼び出し時のツール名は Claude Code 上では `mcp__plugin_google_google-analytics__<tool>` の形で露出する（環境により命名は変わりうるため、実際の deferred tools 一覧で確認する）。

---

## 2. 前提条件（初回のみ）

### 2.1 ランタイム

- **Python 3.10+** と **pipx** が PATH 上にあること。本プラグインの `bin/pipx-mise.sh` は `mise` があれば `mise exec -- pipx run` 経由で、無ければ素の `pipx run` で起動する。
- 動作確認: `pipx run analytics-mcp --help`（初回はパッケージ取得のため時間がかかる）。

### 2.2 Google Cloud 側の API 有効化

対象の Google Cloud プロジェクトで、以下 2 つの API を有効化する:

- **Google Analytics Admin API**（`analyticsadmin.googleapis.com`）
- **Google Analytics Data API**（`analyticsdata.googleapis.com`）

```bash
gcloud services enable analyticsadmin.googleapis.com analyticsdata.googleapis.com \
  --project YOUR_PROJECT_ID
```

### 2.3 GA4 側の権限

認証に使う Google アカウント（または サービスアカウント）が、分析したい **GA4 プロパティの「閲覧者」以上** の権限を持っていること。

---

## 3. 認証（ADC）セットアップ

`analytics-mcp` は Google の標準 ADC を使う。次のいずれかで認証情報を用意する。

### 方式 A: ユーザー認証（推奨・手軽）

```bash
gcloud auth application-default login \
  --scopes=https://www.googleapis.com/auth/analytics.readonly,https://www.googleapis.com/auth/cloud-platform
```

これで認証情報が ADC の既定パス（`~/.config/gcloud/application_default_credentials.json`）に保存され、`GOOGLE_APPLICATION_CREDENTIALS` を明示しなくてもサーバーが拾う。

### 方式 B: サービスアカウント JSON

サービスアカウントの鍵 JSON を使う場合は、シェルでパスを export する（**鍵ファイルそのものや絶対パスをコミット対象ファイルに書かない**）:

```bash
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/secrets/ga4-sa.json"
export GOOGLE_PROJECT_ID="your-project-id"
```

サービスアカウントを impersonate する場合:

```bash
gcloud auth application-default login \
  --impersonate-service-account=SERVICE_ACCOUNT_EMAIL \
  --scopes=https://www.googleapis.com/auth/analytics.readonly,https://www.googleapis.com/auth/cloud-platform
```

---

## 4. 環境変数とコミット安全性（🔴 重要）

| 環境変数 | 役割 | 必須 |
|---------|------|------|
| `GOOGLE_APPLICATION_CREDENTIALS` | 認証情報 JSON のパス。**方式 A（ADC）なら不要** | 条件付き |
| `GOOGLE_PROJECT_ID` | 課金/quota 対象の Google Cloud プロジェクト ID | 推奨 |

本プラグインの `.mcp.json`（Claude）と `.mcp-codex.json`（Codex）は **`env` ブロックを持たない**（devkit / studio と同じ慣習）。Claude Code / Codex は MCP サーバーを子プロセスとして起動する際に**親プロセスの環境変数を継承**するため、上記をシェル（`.zshrc` 等）で `export` するだけで値が渡る。**秘匿値はリポジトリに一切コミットされない**。

```bash
# ~/.zshrc 等で export（MCP サーバーがそのまま継承する）
export GOOGLE_PROJECT_ID="your-project-id"
# サービスアカウント JSON を使う場合のみ追加:
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/secrets/ga4-sa.json"
```

> ⚠️ **方式 A（ADC ユーザー認証）だけで運用する場合**: `GOOGLE_APPLICATION_CREDENTIALS` は `export` せず、`GOOGLE_PROJECT_ID` のみ設定すれば足りる（認証情報は ADC 既定パス `~/.config/gcloud/application_default_credentials.json` から自動解決）。`env` ブロックを持たない設計なので、空文字 `GOOGLE_APPLICATION_CREDENTIALS=""` が渡って ADC を壊す心配もない。

---

## 5. 提供ツール一覧

`analytics-mcp` が公開するツールは大きく「アカウント情報」「レポート実行」「リアルタイム」の 3 系統。**各ツールの正確な引数スキーマは MCP サーバーが提供する tool 定義を実行時に参照する**（ここでは用途と典型的な使いどころを示す）。

### 5.1 アカウント情報系

| ツール | 用途 | いつ使うか |
|--------|------|-----------|
| `get_account_summaries` | アクセス可能な GA4 アカウントと配下プロパティの一覧（Admin API の accountSummaries）。**プロパティ ID を発見する起点** | 「どのプロパティが見えるか」「property ID が分からない」とき最初に呼ぶ |
| `get_property_details` | 指定プロパティのメタdata（タイムゾーン・通貨・作成日時等） | レポートの日付/通貨解釈の前提を確認するとき |
| `list_google_ads_links` | プロパティに紐づく Google Ads リンクの一覧 | 広告連携の有無・リンク状況を確認するとき |

### 5.2 レポート実行系（コア）

| ツール | 用途 | いつ使うか |
|--------|------|-----------|
| `run_report` | 標準レポート（Data API runReport）。期間・ディメンション・メトリクスを指定して集計 | セッション数・ユーザー数・PV・コンバージョン等の集計の主力 |
| `run_funnel_report` | ファネルレポート（runFunnelReport）。ステップ間の遷移・離脱を分析 | 購入/登録などの段階的コンバージョン経路を見るとき |
| `get_custom_dimensions_and_metrics` | プロパティに定義されたカスタムディメンション/メトリクスの一覧 | カスタム計測値をレポートに含める前に名前を調べるとき |

### 5.3 リアルタイム系

| ツール | 用途 | いつ使うか |
|--------|------|-----------|
| `run_realtime_report` | リアルタイムレポート（runRealtimeReport）。直近約30分のアクティビティ | 「今まさに何人いるか」「公開直後の反応」を見るとき |

---

## 6. GA4 の基本概念（レポート作成の前提）

| 概念 | 説明 | 例 |
|------|------|-----|
| **Property ID** | レポート対象を特定する数値 ID（`properties/123456789`） | `get_account_summaries` で取得 |
| **ディメンション** | データを分類する軸 | `date` / `country` / `deviceCategory` / `pagePath` / `sessionSource` |
| **メトリクス** | 集計される数値 | `sessions` / `activeUsers` / `screenPageViews` / `conversions` / `totalRevenue` |
| **日付範囲** | 集計期間。相対指定可 | `7daysAgo`〜`today` / `2026-06-01`〜`2026-06-25` |
| **フィルタ** | ディメンション/メトリクスで絞り込み | `country == "Japan"` |

> ディメンション/メトリクスの正式な API 名は GA4 Data API のスキーマに従う。標準項目で不明なものは `run_report` を小さく試して名前を確認するか、カスタム項目は `get_custom_dimensions_and_metrics` で調べる。

---

## 7. 典型ワークフロー

### 7.1 はじめての分析（property を知らない状態から）

1. `get_account_summaries` を呼び、対象プロパティの **property ID** を特定する。
2. 必要なら `get_property_details` でタイムゾーン・通貨を確認。
3. `run_report` で目的の集計を実行（例: 過去28日の国別セッション数）。
   - dimensions: `country`
   - metrics: `sessions`, `activeUsers`
   - dateRange: `28daysAgo`〜`today`
4. 結果を表に整形してユーザーに提示し、必要なら深掘りクエリを追加。

### 7.2 リアルタイム確認

1. property ID を用意（上記 7.1-1）。
2. `run_realtime_report` を実行（例: `activeUsers` を `country` / `deviceCategory` 別に）。

### 7.3 コンバージョン経路（ファネル）

1. ファネルの各ステップを定義（例: 閲覧 → カート → 購入 のイベント）。
2. `run_funnel_report` で各ステップの到達数・離脱率を取得。
3. 離脱が大きいステップを特定して施策仮説を立てる。

---

## 8. トラブルシューティング

| 症状 | 原因 | 対処 |
|------|------|------|
| `PERMISSION_DENIED` / API 無効 | Admin/Data API 未有効化 | §2.2 の `gcloud services enable` を実行 |
| `403` / アクセス不可 | 認証アカウントに GA4 プロパティ権限なし | GA4 管理画面で「閲覧者」以上を付与 |
| `File '' was not found.` 等の認証エラー | 空の `GOOGLE_APPLICATION_CREDENTIALS` が渡った | §4 の注意に従い該当 env 行を外し ADC 既定パスに委ねる、または正しいパスを export |
| `invalid_scope` / スコープ不足 | ADC のスコープに `analytics.readonly` が無い | §3 のコマンドで `--scopes` を付け直して再ログイン |
| 結果が空 | property ID 誤り / 期間にデータ無し / ディメンション名誤り | `get_account_summaries` で ID 再確認、期間とメトリクス/ディメンション名を見直す |
| `pipx: command not found` | pipx 未導入 | `brew install pipx` または `mise use -g pipx@latest` |
| サーバーが起動しない | Python < 3.10 | Python 3.10+ を用意（`mise use python@3.12` 等） |

---

## 9. セキュリティ・運用メモ

- スコープは **読み取り専用**（`analytics.readonly`）に限定する。書き込みスコープは付けない。
- 認証情報（サービスアカウント鍵・ADC JSON）は **リポジトリにコミットしない**。env は環境変数展開で注入する（§4）。
- サービスアカウントを使う場合は最小権限（対象プロパティの閲覧者）に絞る。
- `GOOGLE_PROJECT_ID` は quota/課金の対象プロジェクトを明示するために設定を推奨。

---

## 10. 関連スキル

- 検索可視性戦略・SEO/GEO・GA4 を含む KPI/ROI 設計 → `studio:optimizing-search-visibility`
- BigQuery への GA4 エクスポートを使った大規模 SQL 分析 → `cloud:developing-google-cloud`
- MCP サーバーそのものの開発・プロトコル理解 → `lang:developing-mcp`
