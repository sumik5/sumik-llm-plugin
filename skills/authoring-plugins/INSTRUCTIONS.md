# Claude Code Plugin 開発ガイド

Claude Code Plugin（Agent・Skill・Command）の作成・最適化を体系的にガイドする。

## 🔴 クリティカルルール

### PDF入力の取り扱い（絶対遵守）

**PDFファイルを `Read` ツールで直接読み込んではならない。** PDFの各ページは画像としてレンダリングされ、コンテキストウィンドウを大幅に圧迫してcompactionが発生する。

| 禁止 | 必須手順 |
|------|---------|
| `Read(file_path: "input.pdf")` | まずMarkdownに変換し、変換後の `.md` ファイルを読む |

PDFが引数として渡された場合のフロー:
1. **絶対にReadツールでPDFを開かない**（ページ数確認も不可）
2. Phase 0で入力がPDFであることを判定
3. Phase AのPlannerタチコマに変換を委譲（`pdf-to-markdown.mjs` スクリプト使用）
4. 変換後のMarkdownファイルのみを読み込む

---

## コンポーネント概要と選択ガイド

Claude Code Plugin は3種類のコンポーネントで構成される。

| コンポーネント | 配置 | 用途 | コンテキスト |
|--------------|------|------|------------|
| **Agent** | `agents/<name>.md` | 独立した実行エージェント | 専用ウィンドウ（分離） |
| **Skill** | `skills/<name>/SKILL.md` | 知識・ガイドラインの提供 | 親会話に注入 |
| **Command** | `commands/<name>.md` | ユーザー呼び出しタスク | スキルと同仕組み |

### Agent vs Skill: いつどちらを使うか

**Agentを選ぶ場面:**
- コンテキストを分離したい（大量出力・独立タスク）
- ツールを制限したい（読取専用エージェント等）
- 並列実行したい（複数インスタンス）
- 専門ドメインの実装を委譲したい

**Skillを選ぶ場面:**
- 知識・ガイドラインを親会話で直接使いたい
- 再利用可能なプロンプトを提供したい
- 短い参照コンテンツ（コーディング規約、チェックリスト等）

---

## 共通: フロントマター仕様

### 命名規則

| コンポーネント | 命名 | 例 |
|--------------|------|-----|
| Agent ファイル | ケバブケース | `tachikoma-nextjs.md` |
| Skill ディレクトリ | 動名詞形（verb + -ing） | `developing-nextjs/` |
| Command ファイル | ケバブケース | `pull-request.md` |

### description 三部構成（🔴 最重要）

descriptionはClaude Code本体がルーティング先を判断する**唯一の手がかり**。

**Agent用フォーマット:**
```
"{ドメイン} specialized Tachikoma execution agent.
 Handles {具体的タスク列挙}.
 Use proactively when {トリガー条件}. Detects: {ファイルパターン}."
```

**Skill用フォーマット（三部構成）:**
```
1行目: 機能の端的な説明
2行目: Use when [トリガー条件]
3行目以降: 補足（For X, use Y instead等）
```

**共通ルール:**
- `>-`（folded block scalar）を必ず使用（インライン文字列はコロンでYAMLエラー）
- **1024文字以下**（Claude Codeのフロントマター解析制限）
- 具体的なタスク・技術名を列挙する（「helps with X」はNG）

---

## Agent 定義: 概要

Agent定義ファイルの詳細は [AGENT-GUIDE.md](references/AGENT-GUIDE.md) を参照。テンプレートは [AGENT-TEMPLATE.md](references/AGENT-TEMPLATE.md) を参照。

### フロントマターフィールド早見表

```yaml
---
name: タチコマ（role）           # 必須: 表示名
description: "..."                # 必須: トリガー検出用（英語推奨）
model: sonnet                      # sonnet / opus / haiku / inherit
color: cyan                        # ターミナル表示色
tools: Read, Grep, Glob, Edit, Write, Bash  # 省略=全ツール（🔴 非推奨）
disallowedTools: Write, Edit       # 拒否ツール
permissionMode: default            # default / acceptEdits / dontAsk / plan / bypassPermissions
maxTurns: 50                       # 最大ターン数
skills:                            # プリロードするスキル一覧（全文注入）
  - domain-skill-1
  - writing-clean-code
memory: project                    # user / project / local
mcpServers:                        # MCPサーバー
  - serena
---
```

### Agentの設計原則

**ツール制限（🔴 重要）**: `tools`フィールド省略=全ツールへの暗黙的アクセス（セキュリティリスク）

| エージェント種別 | 推奨 tools |
|----------------|-----------|
| 読取専用 | `Read, Grep, Glob, Bash` |
| 実装系 | `Read, Grep, Glob, Edit, Write, Bash` |
| ドキュメント系 | `Read, Grep, Glob, Edit, Write` |

**モデル選択:**
- `sonnet`: 実装・テスト・インフラ・ドキュメント（標準）
- `opus`: 設計・分析・セキュリティ監査（高度推論）
- `haiku`: 軽量タスク・コスト重視

**スキルプリロード戦略:**
- コード実装系: `writing-clean-code`, `testing-code`, `securing-code` をプリロード
- TypeScript/Python系のみ: `enforcing-type-safety` を追加
- 1エージェントあたり 3-9スキルを目安
- スキルの全文がコンテキストに注入されるため、過剰プリロードに注意

**permissionMode選択:**
- 実装系: `default` または `acceptEdits`
- 読取専用: `plan` または `dontAsk`

### Markdown body（システムプロンプト）構成順序

```markdown
# 言語設定（最優先・絶対遵守）

# 実行エージェント（タチコマ・{role}専門）

## 役割定義（ペルソナ・並列命名規則）

## 専門領域（各プリロードスキルの重要ポイントを抽出）

## 基本的な動作フロー（タスク受信→docs確認→実装→報告）

## 完了定義（DoDチェックリスト）

## 報告フォーマット（完了報告・進捗報告テンプレート）

## 禁止事項
```

> **重要**: サブエージェントはMarkdown body**のみ**をシステムプロンプトとして受け取る。完全なClaude Codeシステムプロンプトは受け取らない。

### 並列実行対応（🔴 全エージェント必須）

- 役割定義に `並列実行時は「tachikoma-{domain}1」「tachikoma-{domain}2」として起動` を記述
- ワークフローに `docs/plan-xxx.md` 確認ステップを含める
- DoDに `docs/plan-*.md のチェックリストを更新した（並列実行時）` を含める

---

## Skill 定義: 概要

Skillの詳細設計は [SKILL-GUIDE.md](references/SKILL-GUIDE.md) を参照。

### Two-Stage Loading（🔴 必須パターン）

```
Stage 1: SKILL.md 自動注入（200〜500バイト）
  → フロントマター（description）のみがコンテキストに入る
Stage 2: Claude が必要と判断した時のみ INSTRUCTIONS.md を読む
  → 詳細な手順・ガイドラインがオンデマンドで読み込まれる
```

**効果**: 全体で94.8%のコンテキスト節約。

### SKILL.md テンプレート

```yaml
---
name: my-skill
description: >-
  What it does. Use when [trigger]. For X, use Y instead.
---

詳細な手順・ガイドラインは `INSTRUCTIONS.md` を参照してください。
```

### Progressive Disclosure（段階的開示）

INSTRUCTIONS.md本文は **500行以下**を目安とする。500行超の場合は `references/` に詳細を分離:

```
my-skill/
├── SKILL.md              # フロントマター + ポインター（自動注入）
├── INSTRUCTIONS.md       # 本文全体（オンデマンド）
└── references/           # 詳細ドキュメント（必要時のみ）
    ├── REFERENCE.md
    └── EXAMPLES.md
```

### 呼び出し制御

| パターン | `disable-model-invocation` | `user-invocable` | 用途 |
|---------|--------------------------|-----------------|------|
| 自動+手動 | `false`（デフォルト） | `true`（デフォルト） | 通常スキル |
| 手動のみ | `true` | `true` | ユーザーが明示的に呼ぶもの |
| バックグラウンド | `false` | `false` | Agentにプリロードされる知識 |

> `disable-model-invocation: true` を設定すると、descriptionがコンテキストから**完全に除外**される。Agentから参照するスキルには **必ず `false`（またはフィールド省略）** を設定する。

### Skillトリガー機構

1. **REQUIRED/MUST パターン**: descriptionに含めると該当タスク前に必ずロード
2. **SessionStart Hook**: `detect-project-skills.sh` がプロジェクトを解析して自動推奨
3. **Use when パターン**: 条件に該当する場合に明示的にロード

### 動的コンテキスト注入

`` !`command` `` 構文でシェルコマンドの出力をスキル内容に埋め込める:

```yaml
## PRコンテキスト
- PR差分: !`gh pr diff`
```

---

## 品質チェックリスト

新規コンポーネント追加時:
- [ ] フロントマターのYAMLが正しくパースされるか
- [ ] description が三部構成になっているか
- [ ] description が1024文字以下か（`python3 -c "import yaml; ..."` で検証）
- [ ] Agent: `tools`フィールドが権限最小化されているか（省略していないか）
- [ ] Agent: `skills`フィールドのスキル名が実在するか
- [ ] Skill: Two-Stage Loading（SKILL.md + INSTRUCTIONS.md）構造になっているか
- [ ] Skill: エージェントから参照するなら `disable-model-invocation: false`
- [ ] `plugin.json` への登録が完了しているか（必要な場合）
- [ ] `README.md` が更新されているか
- [ ] `rules/skill-triggers.md` のルーティング表との整合性（Agent追加時）

---

## 外部設定ファイル同期（Agent追加・変更・削除時）

| 操作 | `skill-triggers.md` | `tachikoma-system.md` | `README.md` |
|------|---------------------|----------------------|-------------|
| **新規作成** | 🔴 行追加 | 🔴 行追加 | 🔴 行追加 |
| **description変更** | 🟡 条件更新（ルーティングに影響する場合） | 不要 | 不要 |
| **name変更** | 🔴 subagent_type列更新 | 🔴 subagent_type列更新 | 🔴 name列更新 |
| **削除** | 🔴 行削除 | 🔴 行削除 | 🔴 行削除 |

---

## 関連ドキュメント

### Agent詳細
- **[AGENT-GUIDE.md](references/AGENT-GUIDE.md)**: フロントマター詳細・ツール制限・permissionMode・並列実行・体制同期手順
- **[AGENT-TEMPLATE.md](references/AGENT-TEMPLATE.md)**: タチコマAgent定義テンプレート

### Skill詳細
- **[SKILL-GUIDE.md](references/SKILL-GUIDE.md)**: Skill作成・変換・レビューの完全ガイド
- **[NAMING.md](references/NAMING.md)**: 命名規則・description三部構成・統一ネーミングルール
- **[STRUCTURE.md](references/STRUCTURE.md)**: ファイル構造とProgressive Disclosure
- **[WORKFLOWS.md](references/WORKFLOWS.md)**: 開発ワークフローとイテレーション
- **[CHECKLIST.md](references/CHECKLIST.md)**: 品質チェックリスト
- **[PATTERNS.md](references/PATTERNS.md)**: ワークフローパターン集
- **[TESTING.md](references/TESTING.md)**: テスト・評価フレームワーク
- **[TROUBLESHOOTING.md](references/TROUBLESHOOTING.md)**: トラブルシューティング
- **[CONVERTING.md](references/CONVERTING.md)**: ソース→スキル変換ワークフロー
- **[CONTEXT-MANAGEMENT.md](references/CONTEXT-MANAGEMENT.md)**: Context圧迫防止・disable-model-invocationベストプラクティス
- **[USAGE-REVIEW.md](references/USAGE-REVIEW.md)**: スキル利用状況レビュー・棚卸しガイド
