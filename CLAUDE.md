# CLAUDE.md - sumik-claude-plugin

sumik Claude Code Plugin のプロジェクト固有開発ルール。

---

## ディレクトリ構成

Claude Code プラグイン本体は `plugins/devkit/` へ隔離している（claude.ai の marketplace 同期が repo 丸ごとを取り込む際に Codex 異物が混入しないようにするため）。ルートには claude.ai / Codex が最初に読む marketplace 定義と Codex 用マニフェストのみを残す。

```
plugins/devkit/              # ★ Claude Code プラグイン本体（claude.ai が取り込む清潔な範囲・${CLAUDE_PLUGIN_ROOT}）
├── agents/                  # Agent定義（.md）
├── commands/                # スラッシュコマンド（.md）
├── hooks/                   # イベントフック（.sh）
├── bin/                     # MCPサーバー起動ラッパー（Claude/Codex 双方が参照）
├── scripts/                 # ヘルパースクリプト
├── skills/                  # ナレッジスキル（ディレクトリ/SKILL.md）
├── .claude-plugin/plugin.json  # プラグインマニフェスト（Claude Code 用・plugin名 devkit・version 同期必須）
└── .mcp.json                # MCPサーバー設定（Claude Code 用・${CLAUDE_PLUGIN_ROOT}/bin/... 使用）

.claude-plugin/marketplace.json   # claude.ai が読む marketplace（marketplace名 sumik・plugin名 devkit・source "./plugins/devkit"）
.codex-plugin/plugin.json         # プラグインマニフェスト（Codex CLI 用・plugin名 devkit・skills ./plugins/devkit/skills/・version 同期必須）
.agents/plugins/marketplace.json  # Codex marketplace マニフェスト（marketplace名 sumik-marketplace・plugin名 devkit・version）
.cache/sumik-marketplace/devkit -> ../..  # Codex の source.path symlink（repo root を指す・mode 120000・git 同梱）
.mcp-codex.json                   # MCPサーバー設定（Codex 用・command "./plugins/devkit/bin/..." + cwd "."）
```

---

## 🔴 絶対ルール

### 書籍名・著者名・出版社名の禁止（最重要）

**このリポジトリ配下のスキル本文・参考資料・コミットメッセージ・ドキュメント・コード・コメントに、書籍名・著者名・出版社名を一切含めてはいけない。**

このリポジトリは公開Claude Codeプラグインであり、スキル本文・コミット履歴は全て公開対象になる。固有の書籍・著者への参照は著作権・第三者の権利・中立性の観点で不適切。スキルはあくまで汎用的なパターンとして記述する。

#### 対象範囲

| 場所 | 禁止例 | 推奨表現 |
|------|--------|---------|
| スキル本文（SKILL.md / INSTRUCTIONS.md / references/） | 「TAC ビジネス実務法務検定試験®一問一答エクスプレス」「Wallwork『国際学会プレゼン戦略』」「オライリー『〜』」 | 「資格試験対策書籍」「専門書」「学術論文向けガイド」など汎用記述 |
| コミットメッセージ | `feat(skill): Wallwork『〜』を反映` `書籍5冊の知見で〜` | `feat(skill): 国際学会発表向けのリファレンスを追加` |
| README / docs | 著者名・書名・ISBN・出版社名 | 「公開済みベストプラクティス」「業界標準パターン」など汎用記述 |
| コードコメント | `# 田中『〜』より` | `# 一般的な実装パターン` または出典記述なし |

#### チェックポイント

- スキル**および `agents/`（Claude `.md`・Codex `.toml`）・README** 編集後、変更ファイルに対して `grep -nE "『|』|著|出版|TAC|オライリー|オーム社|技術評論|翔泳社|日経BP|インプレス|Effective [A-Z]|Programming [A-Z]"` で残存固有名を機械チェックする。**掃討対象は `skills/` だけでなく `agents/`・README も含む**（過去 agents/ 本文に英字書名・「〜著」表記の著者名が残存していた）。`『』` 偏重では**英字書名・著者フルネーム・「〜著」**を取りこぼすため多角的パターンで確認する
- コミット前にメッセージから書籍名・著者名・出版社名を除去する
- 既存の過去コミットに固有名が含まれていても、それを参考に新規コミットを書かないこと（過去分は遡及修正しない）
- 知見の出典が必要な場合は「業界標準」「広く知られたパターン」「公開資料」等の汎用表現に置き換える

### README.md の自動同期（最重要）

**コンポーネントの追加・変更・削除を行った場合、同一タスク内でREADME.mdも必ず更新する。**

#### 自動同期ルール

Claude Code本体がタチコマにタスクを振る際、以下のいずれかに該当する変更が含まれる場合、**README.md更新をタチコマの作業スコープに自動的に含める**こと（ユーザーからの個別指示は不要）:

- Agent の追加・削除・名称変更
- Command の追加・削除・名称変更
- Skill の追加・削除・名称変更
- Hook の追加・削除
- MCP Server の追加・削除
- プラグインバージョンの更新（plugin.json）
- ディレクトリ構成の変更

> **⚠️ 注意**: `.claude-plugin/plugin.json` の修正はREADME.md自動同期の対象外とする。バージョン更新等はユーザーが明示的に指示した場合のみ行うこと。

#### 更新手順

タチコマは以下の手順でREADME.mdを更新する:

1. **カウント更新**: ディレクトリ構成セクションとコンポーネント一覧見出しの個数を実数と一致させる
2. **テーブル追加/削除**: 該当カテゴリのテーブルにコンポーネント行を追加・削除
3. **カテゴリ判定**: 新規スキルは以下のカテゴリに分類
   | カテゴリ | 対象 |
   |---------|------|
   | コア開発 | Agent運用、型安全、テスト、セキュリティ等 |
   | アーキテクチャ | 設計原則、モダナイゼーション |
   | フレームワーク | 言語・フレームワーク固有 |
   | フロントエンド・デザイン | UI/UX、デザインツール |
   | ブラウザ自動化 | ブラウザ操作・テスト |
   | インフラ・ツール | Docker、Git、DevTools |
   | ドキュメント・品質 | 文書作成、コードレビュー |

#### 並列実行時の扱い

複数タチコマ並列実行時は、README.md更新を**最後に実行するタチコマ1体に集約**するか、**全タチコマ完了後にClaude Code本体が別タチコマを起動**して一括更新する。競合を避けるため、複数タチコマが同時にREADME.mdを編集しないこと。

### バージョン管理

- バージョンは `plugins/devkit/.claude-plugin/plugin.json` の `version` フィールドで管理（**3ファイル（両 plugin.json + marketplace.json）を必ず同期**→下記参照）
- Semantic Versioning (semver) に従う:
  - **MAJOR**: 破壊的変更（スキルの大幅な構成変更等）
  - **MINOR**: 新規コンポーネント追加（新スキル、新コマンド等）
  - **PATCH**: 既存コンポーネントの修正・改善

### バージョンファイルの同期（🔴 重要）

`plugins/devkit/.claude-plugin/plugin.json` の `version` を更新する際は、必ず以下 **3ファイルすべてを同じ値に同期**すること。Claude Code / Codex CLI / Codex marketplace カタログがそれぞれ別ファイルを参照するため、一部だけ更新すると配布物の整合性が崩れる（過去 marketplace.json の version が取り残された実績あり）。

| ファイル | 役割 |
|---------|------|
| `plugins/devkit/.claude-plugin/plugin.json` の `version` | Claude Code の参照 version |
| `.codex-plugin/plugin.json` の `version` | Codex CLI の参照 version |
| `.agents/plugins/marketplace.json` の `plugins[].version` | Codex marketplace カタログ version（**更新漏れしやすい**） |

#### 同期チェック

コミット前に3ファイルの version 一致を確認すること:

```bash
python3 - <<'PY'
import json
v1 = json.load(open('plugins/devkit/.claude-plugin/plugin.json'))['version']
v2 = json.load(open('.codex-plugin/plugin.json'))['version']
v3 = json.load(open('.agents/plugins/marketplace.json'))['plugins'][0]['version']
print('OK' if v1 == v2 == v3 else f'MISMATCH: {v1} / {v2} / {v3}')
PY
```

### Codex プラグイン配布の注意点

Codex CLI への配布（marketplace / plugin / MCP）固有の罠。

> **配布方式①（確定）**: Claude プラグイン本体を `plugins/devkit/` へ隔離後も、Codex の plugin root は **repo root のまま**にする。`.cache/sumik-marketplace/devkit` symlink のターゲットは `../..`（= repo root）を**据え置く**。これにより Codex は git clone した repo root を plugin ディレクトリとして読み、ルートの `.codex-plugin/plugin.json`・`.mcp-codex.json` が確実に解決される。実体（skills/bin/scripts）は `plugins/devkit/` の1箇所に集約し、Codex はルートのマニフェストから `./plugins/devkit/...` で共有参照する（重複コピーを作らない）。

| If X | then Y |
|------|--------|
| Codex 用 MCP サーバーを定義する時 | **`${CLAUDE_PLUGIN_ROOT}` を使わない**（Codex は非展開で `os error 2`）。`.mcp-codex.json`（root）に `command: "./plugins/devkit/bin/..."` の**相対パス + `"cwd": "."`**（= repo root 基準）で記述し、`.codex-plugin/plugin.json` の `"mcpServers": "./.mcp-codex.json"` で宣言する。Claude Code 用 `plugins/devkit/.mcp.json`（`${CLAUDE_PLUGIN_ROOT}/bin/...` 使用）は別ファイルとして温存し両者を混ぜない |
| Codex 用 `.codex-plugin/plugin.json` の skills パス | Codex plugin root = repo root のため、移動後の実体を `"skills": "./plugins/devkit/skills/"` で参照する（`mcpServers` は `"./.mcp-codex.json"` 据え置き） |
| `.cache/` 配下のパス（marketplace の source.path symlink 等）をリネームする時 | `.gitignore` の `.cache/**` を打ち消す `!` 例外行も新パスへ更新する（現状は `!.cache/sumik-marketplace/devkit`）。漏れると新パスが黙って ignore され commit されず、git clone に含まれず Codex の `source.path` が壊れる。**commit 後に `git ls-tree -r HEAD --name-only \| grep '^.cache/'` で同梱を必ず検証**（`git check-ignore` は negation でも exit 0 を返すため判定に使わない） |
| Codex marketplace / plugin の名称 | marketplace = `sumik-marketplace`（`.agents/plugins/marketplace.json` の `name`）／ plugin = `devkit`（同 `plugins[].name` + `.codex-plugin/plugin.json` の `name`）。インストールは `codex plugin add devkit@sumik-marketplace` |
| Codex プラグインを追加/更新する時 | git 方式。**repo 変更を push 後**に `~/dotfiles/codex/install-sumik-codex-plugin.sh` を実行（marketplace add/upgrade → plugin add → agents/・AGENTS.md を `~/.codex/` へ symlink）→ Codex 再起動。**plugin 名 devkit への改名に伴い、同スクリプトの `PLUGIN_NAME` を `devkit` に更新する必要がある（repo 外・dotfiles 側で対応）** |

---

## コンポーネント開発ガイドライン

### Agent (.md)

- 配置: `plugins/devkit/agents/<name>.md`
- フロントマター必須: `---` で囲んだYAMLヘッダー
- 必須フィールド: model, description
- 命名: ケバブケース（例: `serena-expert.md`）

### Command (.md)

- 配置: `plugins/devkit/commands/<name>.md`
- フロントマター必須: `---` で囲んだYAMLヘッダー
- 必須フィールド: description, allowed-tools
- user-invocable: true で `/name` として呼び出し可能
- 命名: ケバブケース（例: `pull-request.md`）

### Skill (ディレクトリ)

- 配置: `plugins/devkit/skills/<skill-name>/SKILL.md`
- ディレクトリ名: 動名詞形（verb + -ing）
  - ✅ `developing-nextjs`, `writing-clean-code`
  - ❌ `nextjs-development`, `solid-principles`
- SKILL.md: 500行以内を推奨
- 詳細は別ファイルに分離（Progressive Disclosure）:
  - `REFERENCE.md`, `EXAMPLES.md`, `COMMANDS.md` 等
- フロントマター必須: description（三部構成）
  - 1行目: 機能の端的な説明
  - 2行目: 使用タイミング（Use when ...）
  - 3行目以降: 補足的なトリガー情報

### Hook (.sh)

- 配置: `plugins/devkit/hooks/<name>.sh`
- 実行可能権限必須: `chmod +x`
- イベント: PreToolUse, PostToolUse, Stop 等
- plugin.json の hooks セクションで登録

### MCP Server

- 設定: `plugins/devkit/.mcp.json`（Claude Code 用）／ `.mcp-codex.json`（Codex 用・root）に定義
- 新規追加時は動作確認を実施
- 環境変数の依存を明記

---

## 命名規則

| コンポーネント | 命名規則 | 例 |
|--------------|---------|-----|
| Agent | ケバブケース | `serena-expert.md` |
| Command | ケバブケース | `pull-request.md` |
| Skill | 動名詞 + ケバブケース | `developing-nextjs/` |
| Hook | ケバブケース | `format-on-save.sh` |

---

## 品質チェックリスト

新規コンポーネント追加時:
- [ ] フロントマターが正しく記述されている
- [ ] description が三部構成になっている（スキルの場合）
- [ ] `plugin.json` への登録が完了している（必要な場合）
- [ ] `README.md` が更新されている
- [ ] 既存コンポーネントとの整合性が取れている

---

## 開発時の注意事項

- このリポジトリはClaude Code Pluginの定義ファイル群であり、ランタイムコードは含まない
- スキルの記述言語は日本語を基本とする
- フロントマターのフィールドはClaude Codeの仕様に従うこと
- `plugins/devkit/.mcp.json` の変更はClaude Codeの再起動が必要

### git コミット/タグ/push 時の注意（環境依存の罠）

| If X | then Y |
|------|--------|
| version bump + commit + tag + push を実行する時 | `git commit`/`tag`/`push` 等の .git 書込はサンドボックス下で**偽の `exit=0` を返して不発**になることがある。**`dangerouslyDisableSandbox: true`** で実行する（git 書込はユーザー明示依頼時のみ） |
| commit/tag メッセージに全角記号（`「」（）→`）や `<...>` を含む時 | `-m` 直渡しはパース崩れで不発。**Write でメッセージファイルを作り `-F <file>`** で渡す |
| 複合コマンドで `cd <dir> &&` を先頭に置く時 | パーミッションプロンプトを誘発しチェーン全体が不発になる。`cd` を使わず作業ディレクトリ既定のまま実行する |
| コマンドの `exit=0`/`RC=0` を見た時 | 鵜呑みにせず `git log -1 --format='%H %s'`・`git tag --points-at HEAD`・`git status --porcelain` で**実体検証**する |
| `grep -h`・`rm -f` 等のフラグが化ける／`git diff` 出力にノイズが混入する時 | rtk プロキシ起因。`/usr/bin/grep`・`/bin/rm` 等の絶対パスで呼ぶ |
