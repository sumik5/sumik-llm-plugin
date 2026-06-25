# google

**Google サービス連携プラグイン — Google Analytics 4 (GA4) 公式 MCP サーバーと GA4 分析スキルを提供**

---

## 概要

google は devkit / studio と同一 marketplace（Claude: `sumik` / Codex: `sumik-marketplace`）から併設配布される兄弟プラグインです。Google Analytics の公式 MCP サーバー **`analytics-mcp`**（PyPI）を同梱し、GA4 のアカウント情報取得・標準/ファネル/リアルタイムレポート実行を可能にします。あわせて、その使い方と認証セットアップをまとめた日本語スキル **`analyzing-with-google-analytics`** を1個含みます。

- 元になった公式リポジトリ: `googleanalytics/google-analytics-mcp`
- 認証スコープは読み取り専用（`analytics.readonly`）。GA4 設定の変更・書き込みは行いません。

---

## インストール

### Claude Code

```bash
/plugin install google@sumik
```

インストール後、Claude Code は `plugins/google/.mcp.json` を自動検出し、`google-analytics` MCP サーバーを登録します。利用前に「前提条件・認証」の手順を済ませてください。

### Codex

```bash
codex plugin add google@sumik-marketplace
```

（marketplace の add/upgrade は `~/dotfiles/codex/install-sumik-codex-plugin.sh` 経由で実行する運用です。）

---

## ディレクトリ構成

```
sumik-claude-plugin/                       # GitHub repo（Codex はここを git clone）
├── .agents/plugins/marketplace.json       # Codex marketplace manifest（google エントリを含む）
├── .cache/sumik-marketplace/
│   └── google -> ../../plugins/google      # Codex marketplace から google plugin を指す symlink
└── plugins/
    └── google/                            # 本プラグイン
        ├── .claude-plugin/plugin.json     # プラグインメタデータ（plugin 名 google / version 同期必須）
        ├── .mcp.json                      # Claude 用 MCP 設定（${CLAUDE_PLUGIN_ROOT}/bin/... + env 展開）
        ├── .codex-plugin/plugin.json      # Codex CLI プラグインマニフェスト（skills ./skills/ + mcpServers）
        ├── .mcp-codex.json                # Codex 用 MCP 設定（command ./bin/... + cwd "."・env はシェル継承）
        ├── README.md
        ├── bin/pipx-mise.sh               # MCP サーバー起動ラッパー（mise→pipx フォールバック）
        └── skills/                        # ナレッジスキル (1個)
            └── analyzing-with-google-analytics/
```

---

## コンポーネント一覧

### MCP Servers (1個)

| サーバー | パッケージ | 起動 | 用途 |
|---------|-----------|------|------|
| `google-analytics` | `analytics-mcp`（PyPI） | `pipx run analytics-mcp`（`bin/pipx-mise.sh` 経由） | GA4 のアカウント/プロパティ情報取得・標準/ファネル/リアルタイムレポート実行 |

提供ツール: `get_account_summaries` / `get_property_details` / `list_google_ads_links` / `run_report` / `run_funnel_report` / `get_custom_dimensions_and_metrics` / `run_realtime_report`

### Skills (1個)

| スキル | 説明 |
|--------|------|
| `analyzing-with-google-analytics` | GA4 データを `google-analytics` MCP 経由で分析するスキル。7ツールの使い方・ADC 認証セットアップ・必要 API 有効化・環境変数・GA4 概念（ディメンション/メトリクス/日付範囲）・典型ワークフロー・トラブルシュートを日本語で解説 |

---

## 前提条件・認証

利用前に以下を済ませてください（詳細はスキル `analyzing-with-google-analytics` の INSTRUCTIONS.md 参照）。

1. **ランタイム**: Python 3.10 以上 と pipx（`bin/pipx-mise.sh` が `mise`→`pipx` の順に解決）。
2. **API 有効化**（対象 GCP プロジェクト）:
   ```bash
   gcloud services enable analyticsadmin.googleapis.com analyticsdata.googleapis.com --project YOUR_PROJECT_ID
   ```
3. **ADC 認証**（推奨・ユーザー認証）:
   ```bash
   gcloud auth application-default login \
     --scopes=https://www.googleapis.com/auth/analytics.readonly,https://www.googleapis.com/auth/cloud-platform
   ```
4. **GA4 権限**: 認証アカウントが対象プロパティの「閲覧者」以上であること。

---

## 環境変数

MCP サーバーは秘匿値を一切コミットせず、シェル環境から認証情報を取得します（Claude Code / Codex が MCP サーバーを子プロセスとして起動する際、親プロセスの環境変数を継承するため）。`.mcp.json` / `.mcp-codex.json` には devkit/studio と同じく `env` ブロックを置きません。必要な値をシェル（`.zshrc` 等）で `export` してください。

| 環境変数 | 役割 | 必須 |
|---------|------|------|
| `GOOGLE_APPLICATION_CREDENTIALS` | 認証情報 JSON のパス。ADC ユーザー認証（上記手順3）なら不要 | 条件付き |
| `GOOGLE_PROJECT_ID` | quota/課金対象の GCP プロジェクト ID | 推奨 |

> ADC ユーザー認証（上記手順3）だけで運用する場合は `GOOGLE_APPLICATION_CREDENTIALS` を `export` せず、`GOOGLE_PROJECT_ID` のみ設定すれば足ります（認証情報は ADC 既定パス `~/.config/gcloud/application_default_credentials.json` から自動解決）。サービスアカウント JSON を使う場合のみ `GOOGLE_APPLICATION_CREDENTIALS` を `export` してください。`env` ブロックを持たない設計なので、空文字が渡って ADC を壊す心配もありません。

---

## 依存関係メモ

- 本プラグインの MCP サーバーは外部 PyPI パッケージ `analytics-mcp` を `pipx run` で取得して起動します（初回はダウンロードに時間がかかります）。
- skills-only ではなく **MCP を持つプラグイン**のため、Claude 用 `.mcp.json` と Codex 用 `.mcp-codex.json` の 2 つの MCP 設定を持ちます（studio と同型・subdirectory 配布方式）。
- 認証は利用者ごとの Google Cloud 環境に依存します。秘匿情報はリポジトリに含めず、各自の ADC / 環境変数で供給してください。
