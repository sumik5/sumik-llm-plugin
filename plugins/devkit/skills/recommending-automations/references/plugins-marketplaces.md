# プラグイン・マーケットプレイスガイド（Claude Code / Codex 両対応）

---

## プラグインとは

プラグインは **skills / commands / agents / hooks の配布単位**。
Claude Code でも Codex でも「まとまった自動化セット」をインストール・共有する手段として機能する。

---

## Claude Code 版

### インストールコマンド

```bash
# 公式マーケットプレイスからインストール
/plugin install <plugin-name>

# サードパーティマーケットプレイスを追加
/plugin marketplace add <marketplace-name>

# インストール済み一覧確認
/plugin list
```

### 公式プラグイン例

| プラグイン | 内容 |
|----------|------|
| `plugin-dev` | plugin・skill・agent・command の作成ガイド（`authoring-plugins` スキル等を収録） |
| `commit-commands` | Conventional Commits 形式でのコミットメッセージ自動生成 |
| `frontend-design` | フロントエンド・デザインシステム向けスキル群 |
| `feature-dev` | 機能開発フルワークフロー（設計→実装→テスト→PR） |
| LSP 系プラグイン | 言語固有の Language Server 連携（Claude Code 専用機能） |

### 独自プラグイン作成

```
<plugin-root>/
├── .claude-plugin/plugin.json   # Claude Code 用マニフェスト
├── skills/                      # SKILL.md を格納
├── commands/                    # スラッシュコマンド
├── agents/                      # Agent 定義
└── hooks/                       # Hook スクリプト
```

`plugin.json` 最小構成:
```json
{
  "name": "my-plugin",
  "version": "1.0.0",
  "description": "プラグインの説明",
  "skills": ["./skills/"]
}
```

詳細は `authoring-plugins` スキル参照。

---

## Codex 版

### インストールコマンド

```bash
# マーケットプレイスからプラグインをインストール
codex plugin add <plugin>@<marketplace>

# 例: sumik-marketplace から devkit をインストール
codex plugin add devkit@sumik-marketplace

# インストール済み一覧確認
codex plugin list
```

### Codex 内蔵 system skill（一部ビルドに含まれる）

| スキル | 用途 |
|-------|------|
| `skill-creator` | 新しい skill を対話的に作成 |
| `plugin-creator` | 新しい plugin を作成 |
| `skill-installer` | skill を検索・インストール |

`$skill-creator` で呼び出し可能（ビルドによって利用可否が異なる）。

### Codex プラグイン構造

```
<plugin-root>/
├── .codex-plugin/plugin.json    # Codex 用マニフェスト
├── skills/                      # SKILL.md を格納
└── .mcp-codex.json              # MCP サーバー設定（MCP を持つ場合のみ）
```

`.codex-plugin/plugin.json` 最小構成:
```json
{
  "name": "my-plugin",
  "version": "1.0.0",
  "description": "プラグインの説明",
  "skills": "./skills/"
}
```

MCP を持つ場合は `mcpServers` フィールドで `.mcp-codex.json` を参照:
```json
{
  "name": "my-plugin",
  "version": "1.0.0",
  "description": "プラグインの説明",
  "skills": "./skills/",
  "mcpServers": "./.mcp-codex.json"
}
```

### Codex marketplace マニフェスト

```json
{
  "name": "my-marketplace",
  "plugins": [
    {
      "name": "my-plugin",
      "version": "1.0.0",
      "source": { "type": "git", "path": "./path/to/plugin" }
    }
  ]
}
```

---

## Claude Code と Codex の機能比較

| 機能 | Claude Code | Codex |
|------|-------------|-------|
| skills | ✅ Agent Skills 標準 | ✅ Agent Skills 標準 |
| commands | ✅ `/command-name` | ❌（skill で代替） |
| agents | ✅ `.md` 形式 | ✅ `.toml` 形式 |
| hooks | ✅ `.claude/settings.json` | ✅ `config.toml`（`hooks = true` 必要） |
| MCP | ✅ `.mcp.json`（JSON） | ✅ `.mcp-codex.json`（TOML map） |
| LSP 連携 | ✅ Claude Code 専用 | ❌ |
| Output Styles | ✅ `/output-style` | ❌（AGENTS.md で代替） |
| marketplace | ✅ `/plugin marketplace add` | ✅ `codex plugin add ...@<marketplace>` |

---

## 判断基準: プラグインをいつ薦めるか

- 既存の公式プラグインがカバーしない**特定のワークフロー**が識別できる
- チームで共通の hook/skill/command セットを**配布・共有**したい
- 1 プロジェクトに留まらず**複数プロジェクトで再利用**したい自動化パターンがある
- 現状は個別ファイル（`.claude/settings.json`・`.codex/agents/`）で管理しているが規模が大きくなった

詳細な plugin 作成手順は `authoring-plugins` スキル参照。
