# MCP サーバーカタログ（Claude Code / Codex 両対応）

---

## セットアップ手順

### Claude Code 版

```bash
# CLI でグローバル追加
claude mcp add context7

# または .mcp.json に記述してプロジェクト共有
```

`.mcp.json`（チーム共有: git commit 推奨）:

```json
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp"]
    }
  }
}
```

診断: `claude mcp list`、`claude --mcp-debug` で接続確認。

### Codex 版

`~/.codex/config.toml` に **map 形式**で記述する（配列形式 `[[mcp_servers]]` は `invalid type: sequence` エラーになるため不可）。

```toml
[mcp_servers.context7]
command = "npx"
args = ["-y", "@upstash/context7-mcp"]
enabled = true
# startup_timeout_sec = 30  # 必要な場合
```

チーム共有: `.mcp-codex.json` に記述してプロジェクトに commit する（プラグイン方式）。
不確かな設定は書かずに**親セッション継承**に任せるのが安全なデフォルト。

診断: `codex mcp list` で登録済みサーバーを確認。

---

## MCP サーバーカタログ

### ドキュメント・検索

| サーバー | パッケージ | 検出シグナル | 用途 |
|---------|-----------|------------|------|
| **context7** | `@upstash/context7-mcp` | 外部ライブラリ import（React・Next.js・Prisma 等） | ライブラリ最新ドキュメント参照 |
| **Exa** | `exa-mcp-server` | Web 検索需要のあるタスク | AI 向け Web 検索 |

### ブラウザ・フロントエンドテスト

| サーバー | パッケージ | 検出シグナル | 用途 |
|---------|-----------|------------|------|
| **Playwright** | `@playwright/mcp` | `playwright.config.*`、E2E テスト | ブラウザ自動化・E2E テスト実行 |
| **Puppeteer** | `@modelcontextprotocol/server-puppeteer` | `puppeteer` in dependencies | ヘッドレスブラウザ操作 |

### データベース

| サーバー | パッケージ | 検出シグナル | 用途 |
|---------|-----------|------------|------|
| **Supabase** | `@supabase/mcp-server-supabase` | `@supabase/supabase-js`、`supabase/` dir | Supabase DB・認証操作 |
| **Convex** | `@convex-dev/mcp-server` | `convex` in dependencies | Convex リアルタイム DB |
| **PostgreSQL** | `@modelcontextprotocol/server-postgres` | `pg`・`postgres`・`DATABASE_URL` | PostgreSQL 直接操作 |
| **Neon** | `@neondatabase/mcp-server-neon` | Neon 接続文字列 | Neon サーバーレス Postgres |
| **Turso** | `@turso/mcp` | `@libsql/client` | Turso SQLite at the edge |
| **Filesystem** | `@modelcontextprotocol/server-filesystem` | 大規模ファイル操作が必要 | ファイルシステム高速操作 |
| **Memory** | `@modelcontextprotocol/server-memory` | セッション横断の状態保持が必要 | ナレッジグラフ記憶 |

### CI/CD・開発ツール

| サーバー | パッケージ | 検出シグナル | 用途 |
|---------|-----------|------------|------|
| **GitHub** | `@modelcontextprotocol/server-github` | `.github/workflows/`、PR フロー | GitHub Issues・PR・Actions 操作 |
| **GitLab** | `@modelcontextprotocol/server-gitlab` | `.gitlab-ci.yml` | GitLab Issues・MR 操作 |
| **Docker** | `@modelcontextprotocol/server-docker` | `Dockerfile`、`docker-compose.*` | コンテナ管理 |
| **Kubernetes** | `@modelcontextprotocol/server-kubernetes` | `k8s/`・`helm/`・`*.yaml` with `apiVersion` | K8s クラスタ操作 |

### Issue・プロジェクト管理

| サーバー | パッケージ | 検出シグナル | 用途 |
|---------|-----------|------------|------|
| **Linear** | `@linear/mcp-server` | Linear URL / `LINEAR_API_KEY` | Linear Issue 管理 |
| **Notion** | `@modelcontextprotocol/server-notion` | Notion URL 参照 | Notion ドキュメント連携 |
| **Slack** | `@modelcontextprotocol/server-slack` | `SLACK_TOKEN` / Slack URL | Slack チャンネル操作 |

### クラウド・インフラ

| サーバー | パッケージ | 検出シグナル | 用途 |
|---------|-----------|------------|------|
| **AWS** | `@modelcontextprotocol/server-aws` | `@aws-sdk/*`・`aws-cdk` | AWS リソース操作 |
| **Cloudflare** | `@cloudflare/mcp-server-cloudflare` | `wrangler.toml`・`@cloudflare/workers-sdk` | Workers・D1・KV 操作 |
| **Vercel** | `@vercel/mcp-adapter` | `vercel.json`・Vercel デプロイ | Vercel デプロイ・プロジェクト管理 |

### 監視・可観測性

| サーバー | パッケージ | 検出シグナル | 用途 |
|---------|-----------|------------|------|
| **Sentry** | `@sentry/mcp-server` | `@sentry/node`・`SENTRY_DSN` | エラートラッキング・Issue 解析 |
| **Datadog** | `@datadog/mcp-server` | `dd-trace`・`DD_API_KEY` | APM・ログ・メトリクス |

---

## Codex 設定例（主要サーバー）

```toml
# ~/.codex/config.toml への追記例

[mcp_servers.context7]
command = "npx"
args = ["-y", "@upstash/context7-mcp"]
enabled = true

[mcp_servers.github]
command = "npx"
args = ["-y", "@modelcontextprotocol/server-github"]
enabled = true
# 環境変数は env ブロックではなくシェルで export して継承させる
# export GITHUB_TOKEN=ghp_xxxx

[mcp_servers.playwright]
command = "npx"
args = ["-y", "@playwright/mcp"]
enabled = true

[mcp_servers.supabase]
command = "npx"
args = ["-y", "@supabase/mcp-server-supabase", "--access-token", "ENV:SUPABASE_ACCESS_TOKEN"]
enabled = true
```

> 認証情報（API キー等）は `env` ブロックではなくシェルで `export` して MCP サーバーに親プロセス環境として継承させる（秘匿値をコミットしない）。
