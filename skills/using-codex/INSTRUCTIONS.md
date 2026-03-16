# Codex

## Codex基本操作

スキル同梱の固定ラッパースクリプト `scripts/codex-consult.sh` を使用してコードレビュー・分析を実行するスキル。

### 実行コマンド

scripts/codex-consult.sh "<project_directory>" "<request>"

### プロンプトのルール

**重要**: codexに渡すリクエストには、以下の指示を必ず含めること：

> 「確認や質問は不要です。具体的な提案・修正案・コード例まで自主的に出力してください。」

### パラメータ

| パラメータ | 説明 |
|-----------|------|
| `scripts/codex-consult.sh` | 固定オプション付きラッパースクリプト |
| `<project_directory>` | 対象プロジェクトのディレクトリ |
| `"<request>"` | 依頼内容（日本語可） |

### 使用例

**注意**: 各例では末尾に「確認不要、具体的な提案まで出力」の指示を含めている。

scripts/codex-consult.sh "/path/to/project" "このプロジェクトのコードをレビューして、改善点を指摘してください。"

scripts/codex-consult.sh "/path/to/project" "認証処理でエラーが発生する原因を調査してください。"

scripts/codex-consult.sh "/path/to/project" "技術的負債を特定し、リファクタリング計画を提案してください。"

### 実行手順

1. ユーザーから依頼内容を受け取る
2. 対象プロジェクトのディレクトリを特定する（現在のワーキングディレクトリまたはユーザー指定）
3. **プロンプトを作成する際、末尾に「確認や質問は不要です。具体的な提案まで自主的に出力してください。」を必ず追加する**
4. 上記スクリプト形式でCodexを実行
5. 結果をユーザーに報告

---

## プランレビュー

スキル同梱の固定ラッパースクリプト `scripts/codex-plan-review.sh` を使用して Markdown プランファイルの致命的問題をレビューする。

### 2つのモード

| モード | 用途 | コマンド |
|-------|------|---------|
| **初回レビュー** (デフォルト) | 新規プランの致命的問題を指摘 | `scripts/codex-plan-review.sh "<plan_file_fullpath>"` |
| **再レビュー** (`--resume`) | 更新済みプランの再確認 | `scripts/codex-plan-review.sh "<plan_file_fullpath>" --resume` |

### 実行手順

**1. Codex 存在確認**

```bash
which codex
```

codex が見つからない場合: `npm install -g @openai/codex` でインストールを案内して終了。

**2. 引数解析**

`$ARGUMENTS` から `plan_file_path` と `--resume` フラグを取得。引数なしの場合は AskUserQuestion でプランファイルパスとモードを確認。

**3. コマンド実行**

```bash
# 初回レビュー
scripts/codex-plan-review.sh "{plan_file_fullpath}"

# 再レビュー
scripts/codex-plan-review.sh "{plan_file_fullpath}" --resume
```

**4. エラーハンドリング**

| エラー | 対応 |
|-------|------|
| codex 未インストール | インストール手順を案内して終了 |
| ファイル不存在 | パスの確認を促す |
| `--resume` で前回セッションなし | 初回レビューモードでの実行を提案 |

---

## Codexオーケストレーション

**Codex本体はオーケストレーターに徹し、tachikoma-architecture agent に計画策定を委譲する。計画承認後、ドメイン別専門agentをWave単位で最大並列起動する。**

### 概要

```
Codex本体 → tachikoma-architecture agent（計画策定・Wave分割）
         → ユーザー確認（テキストベース）
         → Wave 1: 独立agentを同時並列起動 → 全完了待ち
         → Wave 2: Wave 1に依存するagentを同時並列起動 → 全完了待ち
         → ...（Wave N まで繰り返し）
```

**🔴 依存関係がないタスク群は必ず同一Waveにまとめて並列起動する。逐次実行はアンチパターン。**

```
❌ Bad: DB設計 → API実装 → 型定義 → UI実装 → テスト（全直列）
✅ Good:
  Wave 1: DB設計 + 共通型定義（独立タスク）
  Wave 2: API実装 ∥ UIスケルトン実装（Wave 1に依存、相互に独立）
  Wave 3: E2Eテスト ∥ 統合テスト（Wave 2に依存、相互に独立）
```

### 使用タイミング

**🔴 ファイルを読んで判断しない。ユーザーの要求文から以下に該当しそうなら即座にtachikoma-architecture agentを起動:**

1. **複数の機能・コンポーネント** に言及している（例: 「UIとAPIを作って」）
2. **異なる関心事** が含まれる（例: 「フロントエンドとバックエンドを変更」）
3. **複数のサブタスク** が含まれる
4. **「〜を追加して」＋「テストも書いて」** のような複合要求

以下の場合のみ単体agent起動: 1ファイルのみの変更・単一の小さなタスク

### クイックスタート（2フェーズ方式）

**Phase 1: 計画策定**
1. tachikoma-architecture agent 起動 → 現状分析・Wave分割・`docs/plan-{feature}.md` 作成
2. 計画レビュー・ユーザー承認

**Phase 2: 実装（Wave単位で最大並列起動）**
3. Wave N のagentを全て同時起動（1メッセージ内で複数Agent tool呼び出し）
4. Wave N の全agent完了を待機 → Wave N+1 のagentを全て同時起動
5. 全Wave完了後 - 品質チェック・統合確認

### Agent マッピング表

| Codex agent名 | 用途 |
|--------------|------|
| `tachikoma-architecture` | 設計・計画策定（読取専用） |
| `tachikoma-nextjs` | Next.js/React開発 |
| `tachikoma-fullstack-js` | NestJS/Express |
| `tachikoma-typescript` | TypeScript型設計 |
| `tachikoma-python` | Python・ADK |
| `tachikoma-go` | Go開発 |
| `tachikoma-bash` | シェルスクリプト |
| `tachikoma-infra` | Docker/CI-CD |
| `tachikoma-aws` | AWS全般 |
| `tachikoma-database` | DB設計・SQL |
| `tachikoma-ai-ml` | AI/RAG/MCP |
| `tachikoma-test` | ユニット/統合テスト |
| `tachikoma-e2e-test` | Playwright E2E |
| `tachikoma-security` | セキュリティ監査（読取専用） |
| `tachikoma` | 汎用フォールバック |

### 🔴 絶対に避けるべきこと

- Codex本体がファイルを読んで分析する（plannerの責務）
- 同一Wave内で同一ファイルに複数agentが書き込む
- 依存関係がないタスクを逐次実行する
- `docs/plan-*.md` なしでagentを起動する
- ユーザー確認なしに計画を実行する
- Claude Code Team API（TeamCreate等）を呼び出す（Codex環境では使えない）

### サブファイルナビゲーション

| ファイル | 内容 |
|---------|------|
| `references/PLAN-TEMPLATE.md` | `docs/plan-{feature-name}.md` テンプレート・回復手順 |
| `references/WORKFLOW-GUIDE.md` | Phase 1-2 詳細ワークフロー（計画策定→Wave並列実装→完了） |

---

## Agent→Codex変換

Claude Code Agent 定義ファイル（.md）を Codex マルチエージェント形式（config.toml + agent .toml）に変換する。

詳細な手順・ワークフローは `references/CONVERTING-AGENTS.md` を参照。

### 概要

| 処理 | フロー |
|------|--------|
| 単一ファイル | Leader が直接処理（チーム不要） |
| ディレクトリ一括 | TeamCreate → Worker × MAX 5 並列変換 → config.toml 一括更新 |

### 前提条件

- Codex CLI がインストール済み
- `~/dotfiles/codex/config.toml` が存在する
- `~/dotfiles/codex/agents/` ディレクトリが存在する

### 重要ルール

- 毎回 WebFetch で最新仕様を確認: `https://developers.openai.com/codex/multi-agent`
- `sandbox_mode` は常に `"workspace-write"` 固定
- config.toml は Leader のみが更新（Worker は触れない）
- 生成した .toml に `Claude Code` や `AskUserQuestion` が残っていないか最終確認
