# Claude Code Agent → Codex Agent 変換ガイド

Claude Code Agent定義ファイル（`.md`）をCodexのsubagent定義（`agents/*.toml`）に変換する。

---

## 最重要原則

1. **Claude Code agentの本文を `developer_instructions` の主ソースとする**（短く要約しない）
2. **frontmatterの `skills:` は Codexの `[[skills.config]]` に展開する**
3. **Codexで未確認のフィールドを推測で追加しない**
4. **変換後にTOMLとランタイムの両方で検証する**

---

## 前提条件

- Codex CLIがインストール済み
- `~/.codex/agents/`（個人）または `.codex/agents/`（プロジェクト）にagent定義ファイルを配置可能
- 元のClaude Code agent定義（`.md`）が取得できる

---

## Codex Agent定義の基本構造

カスタムagentは `~/.codex/agents/<name>.toml` または `.codex/agents/<name>.toml` に配置する。**`config.toml`への登録は不要。**

```toml
name = "tachikoma-nextjs"
description = "Next.js/React specialized Tachikoma execution agent. ..."
model = "gpt-5.4"
model_reasoning_effort = "high"
sandbox_mode = "workspace-write"
nickname_candidates = ["Route", "Server", "Cache"]

developer_instructions = """
<元agent本文をベースにしたinstructions>
"""

[skills]

[[skills.config]]
path = "~/.codex/skills/developing-nextjs/SKILL.md"
enabled = true

[[skills.config]]
path = "~/.codex/skills/testing-code/SKILL.md"
enabled = true
```

### フィールド一覧

| フィールド | 必須 | 説明 |
|-----------|------|------|
| `name` | 必須 | ASCII安定名を推奨 |
| `description` | 必須 | 元agent descriptionを基にする |
| `developer_instructions` | 必須 | 元agent本文を主ソースとする |
| `model` | 任意 | 運用方針に合わせて固定可 |
| `model_reasoning_effort` | 任意 | `"high"` / `"medium"` / `"low"` |
| `sandbox_mode` | 任意 | `"workspace-write"` / `"read-only"` |
| `nickname_candidates` | 任意 | 複数起動時の識別に有用 |
| `[[skills.config]]` | 任意 | 複数定義可能 |

---

## フィールドマッピング

| Claude Code agent | Codex agent |
|-------------------|-------------|
| frontmatter `name` | `name`（ASCII安定名へ正規化推奨） |
| frontmatter `description` | `description` |
| frontmatter `skills:` | `[[skills.config]]` 群 |
| Markdown body | `developer_instructions` |
| frontmatter `tools` / `permissionMode` | 直接対応なし（`sandbox_mode`で制御） |

---

## `developer_instructions` の変換ルール

**元のMarkdown bodyを主にそのまま使う。**

やること:
- `Claude Code` → `Codex` に置換
- `Claude Code本体` → `Codex本体` に置換
- 明らかに存在しないツール名だけ実情に合わせて補正
- 変換後も元agentの専門性・チェックリスト・報告フォーマットを維持

やってはいけないこと:
- 4行程度の短い一般文に要約する
- 専門領域、品質基準、報告フォーマットを消す
- skills情報を本文から完全に失わせる

### `AskUserQuestion` の扱い

Claude Code agent本文に `AskUserQuestion` の言及がある場合:

```text
ユーザーへのテキスト出力で質問・確認を行い、次の入力を待つ
```

### 文字列形式

`developer_instructions` は三重引用符で囲む。Markdownの見出し・表・コードブロックはそのまま入れてよい。

```toml
developer_instructions = """
<長文本文>
"""
```

---

## `skills.config` の変換ルール

Claude Code agentのfrontmatter:

```yaml
skills:
  - developing-nextjs
  - testing-code
  - securing-code
```

Codexでは:

```toml
[skills]

[[skills.config]]
path = "~/.codex/skills/developing-nextjs/SKILL.md"
enabled = true

[[skills.config]]
path = "~/.codex/skills/testing-code/SKILL.md"
enabled = true

[[skills.config]]
path = "~/.codex/skills/securing-code/SKILL.md"
enabled = true
```

**重要事項:**
- `[[skills.config]]` は**複数定義できる**
- `enabled = true` を**毎回明示する**
- `path` は **`~/.codex/skills/<skill>/SKILL.md` 形式**に統一する
- 参照先skillが存在しない場合は、そのskillだけ除外して理由を報告する

### 変換前にやる確認

```bash
test -f ~/.codex/skills/<skill>/SKILL.md
```

**推測で存在しないpathを書かない。**

---

## `mcp_servers` の扱い

**このフィールドは慎重に扱う。**

| ルール | 理由 |
|--------|------|
| 公式docsと実ランタイムの両方で形式を確認できない限り書かない | 形式誤りでagentが無視される |
| 配列形式で入れない | `invalid type: sequence, expected a map` エラー |
| 不確かな場合は親セッションのMCP設定継承に任せる | 安全なデフォルト |

---

## Agent マッピング表

Claude Code subagent_type → Codex agent名の対応（変換時の参照用）:

| Claude Code subagent_type | Codex agent名 | 用途 |
|--------------------------|--------------|------|
| `sumik:タチコマ（プロダクトマネジメント）` | `tachikoma-product-manager` | 要件分析・計画策定 |
| `sumik:タチコマ（Next.js）` | `tachikoma-nextjs` | Next.js/React |
| `sumik:タチコマ（フロントエンド）` | `tachikoma-frontend` | UI/UX・shadcn |
| `sumik:タチコマ（フルスタックJS）` | `tachikoma-fullstack-js` | NestJS/Express |
| `sumik:タチコマ（TypeScript）` | `tachikoma-typescript` | TypeScript型設計 |
| `sumik:タチコマ（Python）` | `tachikoma-python` | Python・ADK |
| `sumik:タチコマ（Go）` | `tachikoma-go` | Go開発 |
| `sumik:タチコマ（Bash）` | `tachikoma-bash` | シェルスクリプト |
| `sumik:タチコマ（インフラ）` | `tachikoma-infra` | Docker/CI-CD |
| `sumik:タチコマ（Terraform）` | `tachikoma-terraform` | Terraform IaC |
| `sumik:タチコマ（AWS）` | `tachikoma-aws` | AWS全般 |
| `sumik:タチコマ（Google Cloud）` | `tachikoma-google-cloud` | GCP全般 |
| `sumik:タチコマ（セキュリティ）` | `tachikoma-security` | セキュリティ監査 |
| `sumik:タチコマ（データベース）` | `tachikoma-database` | DB設計・SQL |
| `sumik:タチコマ（AI/ML）` | `tachikoma-ai-ml` | AI/RAG/MCP |
| `sumik:タチコマ（テスト）` | `tachikoma-test` | ユニット/統合テスト |
| `sumik:タチコマ（E2Eテスト）` | `tachikoma-e2e-test` | Playwright E2E |
| `sumik:タチコマ（オブザーバビリティ）` | `tachikoma-observability` | 監視・OTel |
| `sumik:タチコマ（ドキュメント）` | `tachikoma-document` | 技術文書 |
| `sumik:タチコマ（デザイン）` | `tachikoma-design` | Figma→コード |
| `sumik:タチコマ（研修・プレゼン）` | `tachikoma-training-presenter` | 研修・プレゼン |
| `sumik:タチコマ` | `tachikoma` | 汎用フォールバック |
| `sumik:serena-expert` | `serena-expert` | トークン効率化開発 |

---

## 推奨ワークフロー

### 単一agent変換

1. 元 `.md` のfrontmatterと本文を読む
2. `agents/<name>.toml` を作る
3. `developer_instructions` に本文を戻す
4. `skills:` を `[[skills.config]]` に展開する
5. TOMLパース確認
6. Codex再起動で警告有無を確認

### 複数agent一括変換

1. まず1ファイルで変換ルールを確定
2. 確定したルールで残りを一括変換
3. 生成後に全件を機械検証
4. 実ランタイムで警告を確認

---

## 変換テンプレート

```toml
name = "<ascii_agent_name>"
description = "<元frontmatterのdescription>"
model = "gpt-5.4"
model_reasoning_effort = "high"
sandbox_mode = "workspace-write"
nickname_candidates = ["Alpha", "Beta", "Gamma"]

developer_instructions = """
<元Markdown bodyをCodex向けに軽微補正したもの>
"""

[skills]

[[skills.config]]
path = "~/.codex/skills/<skill-1>/SKILL.md"
enabled = true

[[skills.config]]
path = "~/.codex/skills/<skill-2>/SKILL.md"
enabled = true
```

---

## サブファイルナビゲーション

| ファイル | 内容 |
|---------|------|
| `references/CONVERTING-AGENTS.md` | 検証手順・よくある失敗パターン・最終チェックリスト |

---

## 関連スキル

- `orchestrating-codex` - Codex Agentオーケストレーション（Wave並列実行）
- `authoring-plugins` - Claude Code Plugin開発ガイド
- `implementing-as-tachikoma` - タチコマAgent運用ガイド
