# コードベース自動化レコメンダー（Claude Code / Codex 両対応）

> **読み取り専用**: このスキルはコードベースを解析してレコメンドを出すのみ。ファイルの作成・変更は行わない。
> 出自: anthropics/claude-plugins-official の claude-automation-recommender（Apache-2.0）を Claude Code＋Codex 両対応へ翻案。
> 方針: 検出されたプラットフォームを優先しつつ、各レコメンドに Claude Code 版と Codex 版セットアップを両方併記する。

---

## Phase 0: 対象プラットフォーム判定

まず以下のシグナルを確認し、レコメンドの主対象プラットフォームを判定する。

```bash
# Claude Code シグナル検出
ls -d .claude/ 2>/dev/null && echo "found: .claude/"
ls CLAUDE.md 2>/dev/null && echo "found: CLAUDE.md"
ls .mcp.json 2>/dev/null && echo "found: .mcp.json"
ls .claude-plugin/ 2>/dev/null && echo "found: .claude-plugin/"

# Codex シグナル検出
ls -d .codex/ 2>/dev/null && echo "found: .codex/"
ls AGENTS.md 2>/dev/null && echo "found: AGENTS.md"
ls .codex-plugin/ 2>/dev/null && echo "found: .codex-plugin/"
ls .mcp-codex.json 2>/dev/null && echo "found: .mcp-codex.json"
ls ~/.codex/config.toml 2>/dev/null && echo "found: ~/.codex/config.toml"
```

| 検出結果 | レコメンド方針 |
|---------|--------------|
| Claude シグナルのみ | Claude Code 版を先頭に、Codex 版を「参考」として続ける |
| Codex シグナルのみ | Codex 版を先頭に、Claude 版を「参考」として続ける |
| 両方検出 | 両方対等に併記（Claude→Codex の順） |
| 未検出 | 両方提示。レポート冒頭に「Claude Code と Codex のどちらをお使いですか？」と一言添える（強制はしない） |

---

## Phase 1: コードベース解析

プロジェクトのルートディレクトリを走査し、以下のシグナルを収集する。

```bash
# 主要設定ファイルを確認
find . -maxdepth 2 \( -name "package.json" -o -name "pyproject.toml" \
  -o -name "Cargo.toml" -o -name "go.mod" -o -name "*.config.ts" \
  -o -name "*.config.js" -o -name "playwright.config.*" \
  -o -name "jest.config.*" -o -name "vitest.config.*" \
  -o -name ".github" -o -name "Dockerfile" \) 2>/dev/null | head -40
```

### コードベース解析シグナル表

| カテゴリ | 検出対象 | 影響するレコメンド |
|----------|----------|------------------|
| 言語/FW | package.json, pyproject.toml, Cargo.toml, go.mod, import パターン | Hooks（フォーマッタ・linter）、MCP（context7） |
| フロントエンド | React, Vue, Angular, Next.js（next.config.*） | Playwright/chrome-devtools MCP、frontend skill |
| バックエンド | Express, FastAPI, Django, NestJS, Hono | API doc subagent、テスト hook |
| DB | Prisma, Supabase, Convex, 生 SQL ファイル | Database/Supabase/Convex MCP |
| 外部 API | Stripe, OpenAI, AWS SDK（@aws-sdk） | context7 MCP |
| テスト | Jest, pytest, Vitest, Playwright config | テスト hook / test-writer subagent |
| CI/CD | `.github/workflows/`, CircleCI `.circleci/` | GitHub MCP |
| Issue 管理 | Linear, Jira を参照するコメント/設定 | Issue tracker MCP |
| Docs | OpenAPI（openapi.yaml）、JSDoc、docstring | doc skill、api-documenter subagent |

---

## Phase 2: レコメンド生成

Phase 1 の解析結果をもとに、5 カテゴリから**各 1〜2 件**のレコメンドを生成する
（ユーザーが特定カテゴリを要求した場合のみ 3〜5 件）。

カタログ・詳細仕様は以下の references を参照:

| カテゴリ | 参照先 | 判断基準 |
|---------|--------|---------|
| 🔌 MCP Servers | `references/mcp-servers.md` | 外部 API・DB・CI が検出されたか |
| ⚡ Hooks | `references/hooks-patterns.md` | フォーマッタ・linter・テストランナーが検出されたか |
| 🤖 Subagents | `references/subagents.md` | コードベースが一定規模以上か、専門的レビュー需要があるか |
| 🎯 Skills | `references/skills-patterns.md` | 定型タスク（PR チェック、マイグレーション生成等）が識別できるか |
| 📦 Plugins | `references/plugins-marketplaces.md` | 既存 plugin がカバーしない機能が必要か |

> リスト外のツール・サービスが検出された場合は、Web 検索で対応 MCP や skill を補完して提案してよい。

### Decision Framework: カテゴリ別判断基準

#### MCP Servers → いつ薦めるか
- 外部 API（Stripe・OpenAI・AWS）が import されている → context7 MCP（最新ドキュメント参照）
- フロントエンドテストが存在する → Playwright MCP
- DB（Supabase・Convex・Postgres）が検出される → 対応 DB MCP
- GitHub Actions が存在する → GitHub MCP

#### Hooks → いつ薦めるか
- フォーマッタ（Prettier・Black・gofmt・rustfmt）が `devDependencies` または設定ファイルで検出される → PostToolUse hook で自動フォーマット
- linter（ESLint・mypy・tsc）が検出される → PostToolUse hook でリント
- `.env` ファイルが存在する → PreToolUse hook で `.env` 誤コミット保護
- テストランナーが検出される → PostToolUse hook でテスト自動実行（選択的に）

#### Subagents → いつ薦めるか
- セキュリティ要件が高い（auth, payment, PII 処理）→ security-reviewer
- テストカバレッジが低い or テストファイルが少ない → test-writer
- API が公開されている → api-documenter
- コードベースが大規模で一貫性が必要 → code-reviewer

#### Skills → いつ薦めるか
- 定型の PR 確認フローがある → pr-check skill
- マイグレーションファイルを頻繁に作成する → create-migration skill
- コンポーネント生成が繰り返し行われる → new-component skill

#### Plugins → いつ薦めるか
- 公式プラグインがカバーしない特定ワークフローがある
- チームで共通の hook/command/skill セットを共有したい

---

## Phase 3: レポート出力

以下のフォーマットで出力する。

```markdown
## 自動化レコメンド（Claude Code / Codex 対応）

検出プラットフォーム: [Claude Code / Codex / 両方 / 未検出]

### コードベースプロファイル
- 種別: [フロントエンド / バックエンド / フルスタック / ライブラリ 等]
- フレームワーク: [Next.js / FastAPI 等]
- 主要ライブラリ: [検出されたもの]

---

### 🔌 MCP Servers

#### [サーバー名]
**なぜ**: [検出ライブラリ/サービスに紐づく理由]
**Claude Code**: `claude mcp add [name]`（または `.mcp.json` に追記）
**Codex**: `~/.codex/config.toml` に以下を追加（map 形式必須）
\```toml
[mcp_servers.[name]]
command = "npx"
args = ["-y", "@package/mcp-server"]
enabled = true
\```

---

### ⚡ Hooks

#### [hook 名]
**なぜ**: [対象フォーマッタ/linter が検出された理由]
**Claude Code**: `.claude/settings.json` の `hooks` に追記
**Codex**: `~/.codex/config.toml` の `[hooks.PostToolUse]` に追記＋`[features] hooks = true`

---

### 🤖 Subagents / 🎯 Skills / 📦 Plugins

（同様に「なぜ」＋ Claude 版 ＋ Codex 版を各レコメンドに記載。検出された側を先に）

---
**もっと見る?** 任意カテゴリの追加候補を依頼可能（例：「MCP をもっと詳しく」）。
**実装の手伝い?** 依頼があれば各セットアップを支援（このスキル自体は読み取り専用）。
```

---

## 関連スキル

| スキル | 用途 |
|--------|------|
| `authoring-plugins` | plugin / skill / agent の新規作成・深掘り |
| `converting-agents-to-codex` | 既存 Claude Agent を Codex subagent に変換 |
| `orchestrating-codex` | Codex Agent のオーケストレーション運用 |
| `managing-claude-md` | CLAUDE.md / AGENTS.md 規約の整備 |
