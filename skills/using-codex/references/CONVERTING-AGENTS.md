# Converting Agents to Codex

Claude Code Agent 定義ファイル（.md）を Codex マルチエージェント形式に変換する。

---

## 前提条件

- Codex CLI がインストール済み
- `~/dotfiles/codex/config.toml` が存在する
- `~/dotfiles/codex/agents/` ディレクトリが存在する

---

## ワークフロー

### 🔴 並列処理アーキテクチャ（バッチ処理時）

フォルダ一括処理では **Agent Teams API** を使い、最大5体のタチコマを並列起動して変換を行う。

```
┌─────────────────────────────────────────────────┐
│  Leader（Claude Code 本体）                       │
│  ・Codex 仕様取得                                 │
│  ・ファイルリスト作成 → バッチ分割（MAX 5）       │
│  ・TeamCreate → Worker 起動 → 結果収集            │
│  ・config.toml 一括更新（共有リソース）            │
│  ・サマリー表示 → TeamDelete                      │
└──────┬──────┬──────┬──────┬──────┬────────────────┘
       │      │      │      │      │
     ┌─▼─┐ ┌─▼─┐ ┌─▼─┐ ┌─▼─┐ ┌─▼─┐
     │ W1 │ │ W2 │ │ W3 │ │ W4 │ │ W5 │  ← タチコマ
     └─┬──┘ └─┬──┘ └─┬──┘ └─┬──┘ └─┬──┘
       ▼      ▼      ▼      ▼      ▼
     .toml  .toml  .toml  .toml  .toml   ← 独立ファイル
```

| 責務 | Leader | Worker |
|------|--------|--------|
| Codex 仕様取得 | ✅ | - |
| Agent .md 読み込み・解析 | - | ✅（1体1ファイル） |
| プラットフォーム用語置換 | - | ✅ |
| スキル description 取得 | - | ✅（limit: 15） |
| Agent .toml 書き込み | - | ✅（各自の担当ファイルのみ） |
| config.toml 更新 | ✅（共有リソース） | ❌ |
| サマリー表示 | ✅ | - |

---

### Phase 0: 準備

#### Step 1: Codex 仕様の最新取得（🔴 毎回必須）

**必ず WebFetch で最新仕様を確認する。キャッシュされた知識に頼らない。**

```
WebFetch(
  url: "https://developers.openai.com/codex/multi-agent",
  prompt: "Extract the complete agent config file format: all available fields, their types, defaults, and any new features. Focus on the agent .toml file structure."
)
```

取得した仕様情報から**仕様サマリー**を作成し保持する（Worker プロンプトに埋め込むため）。

#### Step 1.1: スキル自己改善チェック（公式仕様との同期）

Step 1 で取得した最新仕様をこのファイル（CONVERTING-AGENTS.md）の記述内容と比較し、差分を検出する。

**比較対象**: 利用可能フィールド・デフォルト値・推奨モデル名・sandbox_mode の選択肢・新機能/廃止機能

差分がある場合: AskUserQuestion で「CONVERTING-AGENTS.md を更新しますか？」を確認し、必要に応じて更新。

#### Step 1.5: 入力タイプ判定

`$ARGUMENTS` がファイルパスかディレクトリパスかを判定する。
- **ファイル**: チームなしで Leader が直接処理（単一ファイル処理セクション参照）
- **ディレクトリ**: Phase 1 へ進む（並列バッチ処理）

---

### Phase 1: 並列変換（Worker）

#### Step 2: チーム作成とワーカー起動

1. Glob ツールで `<directory>/*.md` を列挙
2. ファイルリストを**最大5ファイルずつのバッチ**に分割
3. `TeamCreate(team_name: "codex-convert")` でチームを作成
4. バッチごとに各ファイルに対して Worker を起動:
   - `subagent_type: "sumik:タチコマ"`, `team_name: "codex-convert"`, `run_in_background: true`, `model: "haiku"`
   - **1メッセージ内で最大5つの Agent ツール呼び出しを並列発行**
   - 全 Worker の完了を待つ → 次のバッチへ

#### Worker の内部処理

1. **Agent .md 読み込み**: フロントマターと Body を抽出
2. **プラットフォーム用語置換**: `Claude Code` → `Codex`。`AskUserQuestion` → 「ユーザーへのテキスト出力で質問・確認を行い、次の入力を待つ」
3. **フィールドマッピング**:

   | Claude Code | Codex | 変換ルール |
   |------------|-------|-----------|
   | ファイル名（拡張子なし） | `[agents.<key>]` | ハイフン → アンダースコア |
   | `description` | `description` | 置換済みテキストをそのまま転記 |
   | 固定値 | `model` | Step 1 で取得した最新推奨モデル名 |
   | 固定値 | `model_reasoning_effort` | `"high"` |
   | 固定値 | `sandbox_mode` | `"workspace-write"`（常に固定） |
   | Body + skills テーブル | `developer_instructions` | 下記テンプレート参照 |

4. **スキル参照テーブル生成**: `skills/<skill-name>/SKILL.md` を `limit: 15` で Read → description 1行目を抽出
5. **Agent .toml 書き込み**: 存在チェック → 差分判定 → created/updated/skipped
6. **結果報告**: SendMessage で Leader に報告

#### Worker プロンプトテンプレート

Worker 起動時に以下のプロンプトを Agent ツールの `prompt` に設定する:

```
あなたは Claude Code Agent 定義ファイルを Codex 形式に変換する Worker です。

## 担当ファイル
<file_path>

## Codex 仕様サマリー
<Step 1 で取得した仕様サマリーをここに埋め込む>

## 変換ルール

### プラットフォーム用語置換
- 「Claude Code」→「Codex」に一律置換
- `AskUserQuestion` ツール呼び出し・参照 → 「ユーザーへのテキスト出力で質問・確認を行い、次の入力を待つ」

### フィールドマッピング
- agent_key: ファイル名（拡張子なし）のハイフンをアンダースコアに変換
- model: Step 1 で取得した最新推奨モデル名
- model_reasoning_effort: "high"（固定値）
- sandbox_mode: "workspace-write"（常に固定）
- developer_instructions: 置換済み Body 全文 + スキル参照テーブル

## Agent .toml テンプレート
```toml
model = "openai/<最新推奨モデル名>"
model_reasoning_effort = "high"
sandbox_mode = "workspace-write"
developer_instructions = """
<置換済み Body 全文>

## 参照すべき Skill

| Skill 名 | 説明 |
|----------|------|
| <skill-1> | <skill-1 の説明> |
...
"""
```

## 出力先
~/dotfiles/codex/agents/<agent-filename>.toml

## 処理手順
1. Read で担当ファイルを読み込む
2. フロントマターと Body を抽出
3. 用語置換を適用
4. スキル参照テーブルを生成
5. Agent .toml を生成
6. 既存ファイルがあれば比較し、差分がなければスキップ、あれば上書き
7. 生成した .toml に「Claude Code」「AskUserQuestion」が残っていないか最終確認
8. SendMessage で結果を報告
```

---

### Phase 2: 集約（Leader）

#### Step 3: config.toml 一括更新

全 Worker の処理完了後、Leader が `~/dotfiles/codex/config.toml` を更新する。

各 Worker の報告について:
1. Grep で `config.toml` 内に `[agents.<agent_key>]` が存在するか確認
2. **存在しない場合**: 末尾に追記
3. **存在する場合**: 差分があれば Edit で更新

> **注意**: config.toml は **Leader のみが更新**する。

#### Step 4: サマリー表示とチーム解散

```
=== 変換サマリー ===
処理対象: <N> ファイル
  作成: <created> 件 / 更新: <updated> 件 / スキップ: <skipped> 件
```

サマリー表示後、`TeamDelete` でチームを解散する。

---

### 単一ファイル処理（チーム不要）

1. **Codex 仕様取得**: Step 1 と同じ
2. **Agent .md 読み込み・変換・.toml 書き込み**: Worker の内部処理と同じルール
3. **config.toml 更新**: 既存エントリがあれば比較し、AskUserQuestion で確認

---

## テンプレート

### config.toml エントリ

```toml
[agents.<agent_key>]
description = "<description（プラットフォーム用語置換適用済み）>"
config_file = "agents/<agent-filename>.toml"
```

---

## 注意事項

- **TOML文字列のエスケープ**: `developer_instructions` は三重引用符（`"""`）で囲む
- **日本語の扱い**: TOML は UTF-8 をサポートするため、日本語テキストはそのまま
- **既存エントリの重複チェック**: config.toml への追記前に Grep で確認
- **プラットフォーム用語の置換忘れ防止**: 生成した `.toml` に `Claude Code` や `AskUserQuestion` が残っていないか最終確認
- **バッチサイズ**: MAX 5。超える場合は5ファイルずつ順次処理
