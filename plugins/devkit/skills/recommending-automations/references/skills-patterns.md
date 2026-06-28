# カスタム Skill パターン集（Claude Code / Codex 両対応）

---

## 両プラットフォーム共通：Agent Skills 標準

カスタム skill の本体は **Agent Skills 標準の `SKILL.md`** であり、Claude/Codex 双方で読み込まれる。
差分は配置パスと一部 Claude 専用フィールドのみ。

| 項目 | Claude Code | Codex CLI |
|------|-------------|-----------|
| 配置パス | `.claude/skills/<name>/SKILL.md` | `.agents/skills/<name>/SKILL.md`（repo） / `~/.agents/skills/<name>/SKILL.md`（user） |
| 呼び出し | `/skill-name` or model が description 判断で自動ロード | `$skill-name` で明示呼出 or description による暗黙ロード |
| 暗黙ロード制御 | `user-invocable: false`（Claude 専用） | `agents/openai.yaml` の `policy.allow_implicit_invocation` |
| 分離実行 | `context: fork`（Claude 専用） | 非対応（無視される） |
| モデル呼出制御 | `disable-model-invocation: true`（Claude 専用） | 無視される |
| 動的コンテキスト | `` !`cmd` `` で実行結果注入（Claude 対応・Codex 要確認） | `$ARGUMENTS` プレースホルダー（両対応） |

---

## カスタム Skill アイデア

### api-doc（API ドキュメント自動生成）

**検出シグナル**: `openapi.yaml`・`swagger.json`・JSDoc コメント・docstring が豊富

```markdown
---
name: api-doc
description: >-
  ソースコードから API ドキュメントを自動生成する。
  Use when generating or updating API documentation from code.
allowed-tools: Read Glob Grep Write
---

# API ドキュメント生成

$ARGUMENTS で指定されたファイルまたはディレクトリを読み取り、
エンドポイント・パラメータ・レスポンス・エラーケースを含む
OpenAPI 形式または Markdown 形式のドキュメントを生成する。
```

**配置**:
- Claude: `.claude/skills/api-doc/SKILL.md`
- Codex: `.agents/skills/api-doc/SKILL.md`

---

### create-migration（DB マイグレーション生成）

**検出シグナル**: Prisma・Alembic・Flyway・`migrations/` ディレクトリ

```markdown
---
name: create-migration
description: >-
  データベーススキーマの変更から安全なマイグレーションファイルを生成する。
  Use when creating database migration files.
allowed-tools: Read Glob Grep Write Bash
---

# マイグレーション生成

現在のスキーマと変更要件を読み取り、前後互換性・ロールバック手順を
評価した上でマイグレーションファイルを生成する。
```

---

### gen-test（テストコード生成）

**検出シグナル**: テストファイルが存在するが少ない・`jest.config.*`・`pytest.ini`

```markdown
---
name: gen-test
description: >-
  指定されたソースファイルのユニットテストを生成する。
  Use when generating test files for existing code.
allowed-tools: Read Glob Grep Write
---

# テスト生成

$ARGUMENTS で指定されたソースファイルを読み取り、既存テストの
スタイル・フレームワークに合わせたテストを AAA パターンで生成する。
エッジケース・境界値・エラーケースを必ずカバーする。
```

---

### new-component（コンポーネント生成）

**検出シグナル**: React・Vue・Angular フロントエンドが存在する

```markdown
---
name: new-component
description: >-
  プロジェクトの既存コンポーネント規約に合わせた新規コンポーネントを生成する。
  Use when creating new UI components following project conventions.
allowed-tools: Read Glob Grep Write
---

# コンポーネント生成

既存のコンポーネントサンプルを読み取り、プロジェクトの命名規則・
ディレクトリ構造・スタイリング規約に合わせた
$ARGUMENTS という名前のコンポーネントを生成する。
```

---

### pr-check（PR マージ前チェック）

**検出シグナル**: GitHub Actions が存在する・チームワークフロー

```markdown
---
name: pr-check
description: >-
  プルリクエストのマージ前に品質チェックを実行する。
  Use when preparing a pull request for review or merge.
allowed-tools: Read Glob Grep Bash
---

# PR チェックリスト

以下の観点で変更内容を確認してレポートを生成する:
1. テストが全て通過するか（`npm test` / `pytest` 等）
2. 型チェックが通るか（`tsc --noEmit` / `mypy` 等）
3. linter エラーがないか
4. CHANGELOG / docs の更新が必要か
5. ブレーキングチェンジがないか
```

---

### release-notes（リリースノート生成）

**検出シグナル**: git タグ管理・`CHANGELOG.md`・バージョン管理ファイル

```markdown
---
name: release-notes
description: >-
  直近のコミット・変更から自動でリリースノートを生成する。
  Use when creating release notes or updating CHANGELOG.
allowed-tools: Read Bash
---

# リリースノート生成

前回のリリースタグから現在 HEAD までのコミットを読み取り、
機能追加・バグ修正・破壊的変更に分類してリリースノートを生成する。
```

---

### project-conventions（プロジェクト規約確認）

**検出シグナル**: `CLAUDE.md`・`AGENTS.md`・`CONTRIBUTING.md`・`.github/` が存在する

```markdown
---
name: project-conventions
description: >-
  プロジェクトのコーディング規約・貢献ガイドラインを要約して提示する。
  Use when starting work on a new project or unfamiliar codebase.
allowed-tools: Read Glob Grep
---

# プロジェクト規約確認

CLAUDE.md / AGENTS.md / CONTRIBUTING.md / README.md を読み取り、
このプロジェクトで守るべき命名規則・コードスタイル・コミット規約・
テスト要件・デプロイ手順を要約する。
```

---

### setup-dev（開発環境セットアップ）

**検出シグナル**: 新規クローン直後・`package.json` / `pyproject.toml` が存在する

```markdown
---
name: setup-dev
description: >-
  開発環境のセットアップ手順を案内し、必要なツールのインストールを支援する。
  Use when setting up a new development environment for a project.
allowed-tools: Read Bash
---

# 開発環境セットアップ

README.md・package.json・pyproject.toml 等を読み取り、
このプロジェクトの開発を始めるために必要な手順を順序立てて案内する。
（依存インストール・環境変数設定・初期ビルド・テスト実行まで）
```

---

## Skill 作成の深掘り

skill の新規作成・プラグイン化の詳細手順は `authoring-plugins` スキル参照。

### ミニマム SKILL.md テンプレート

```markdown
---
name: <skill-name>
description: >-
  <1行説明>
  Use when <ユーザーが何を求めたとき>.
allowed-tools: Read Glob Grep
---

# <タイトル>

<本文: 手順・制約・出力フォーマット>
```

フロントマターフィールドのポイント:
- `name`: 親ディレクトリ名と一致させる
- `description`: 1024 文字以内。`Use when ...` でトリガー条件を明示
- `allowed-tools`: スペース区切り（`Read Glob Grep Bash Write`）
- Claude 専用フィールド（`context: fork`・`disable-model-invocation`）は Codex では無視されるため、**両対応 skill では付けないことを推奨**
