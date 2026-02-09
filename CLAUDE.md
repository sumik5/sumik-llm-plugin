# CLAUDE.md - sumik-claude-plugin

sumik Claude Code Plugin のプロジェクト固有開発ルール。

---

## ディレクトリ構成

```
agents/          # Agent定義（.md）
commands/        # スラッシュコマンド（.md）
hooks/           # イベントフック（.sh）
scripts/         # ヘルパースクリプト
skills/          # ナレッジスキル（ディレクトリ/SKILL.md）
.claude-plugin/  # プラグインマニフェスト
.mcp.json        # MCPサーバー設定
```

---

## 🔴 絶対ルール

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

- バージョンは `.claude-plugin/plugin.json` の `version` フィールドで管理
- Semantic Versioning (semver) に従う:
  - **MAJOR**: 破壊的変更（スキルの大幅な構成変更等）
  - **MINOR**: 新規コンポーネント追加（新スキル、新コマンド等）
  - **PATCH**: 既存コンポーネントの修正・改善

---

## コンポーネント開発ガイドライン

### Agent (.md)

- 配置: `agents/<name>.md`
- フロントマター必須: `---` で囲んだYAMLヘッダー
- 必須フィールド: model, description
- 命名: ケバブケース（例: `serena-expert.md`）

### Command (.md)

- 配置: `commands/<name>.md`
- フロントマター必須: `---` で囲んだYAMLヘッダー
- 必須フィールド: description, allowed-tools
- user-invocable: true で `/name` として呼び出し可能
- 命名: ケバブケース（例: `pull-request.md`）

### Skill (ディレクトリ)

- 配置: `skills/<skill-name>/SKILL.md`
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

- 配置: `hooks/<name>.sh`
- 実行可能権限必須: `chmod +x`
- イベント: PreToolUse, PostToolUse, Stop 等
- plugin.json の hooks セクションで登録

### MCP Server

- 設定: `.mcp.json` に定義
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
- `.mcp.json` の変更はClaude Codeの再起動が必要
