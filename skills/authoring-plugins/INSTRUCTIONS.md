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
3. Phase AのPlannerタチコマに変換を委譲（`pdf-to-markdown` スクリプト使用）
4. 変換後のMarkdownファイルのみを読み込む

---

## 🔴 Step 0: 最新仕様確認（毎回必須）

このスキルが扱う Agent Skills 仕様と Claude Code 拡張は**進化し続ける**。スキルを使う前に必ず以下を WebFetch で確認する。

### 必須確認 URL

| 仕様 | URL | 確認内容 |
|------|-----|---------|
| Agent Skills 標準（最優先） | <https://agentskills.io/specification> | フロントマター全フィールド・description 文字数上限・name 制約 |
| Agent Skills ドキュメントインデックス | <https://agentskills.io/llms.txt> | 仕様追加ページの検出 |
| Claude Code 拡張 | <https://code.claude.com/docs/en/skills> | 拡張フィールド（context / agent / when_to_use 等）の追加・変更 |

### 確認タイミング

- **新規スキル作成時**（必須）
- **既存スキル description 改修時**（必須）
- **新フィールド検討時**（必須）
- セッション開始から 24 時間以上経過後の改修時（推奨）

### 仕様変更検出時の対応フロー

1. **新フィールド追加検出**: フロントマター仕様表を更新し、判定マトリクスへの影響を評価
2. **既存フィールドの制約変更検出**: 該当箇所を更新（例: description 1024→XXXX）し、既存スキルへの遡及影響を確認
3. **Claude Code 拡張 → 標準昇格**: 移植性警告を更新し、標準準拠スキルから安全に使用可能と明示
4. **仕様削除/非推奨化**: 該当機能を使うスキルに deprecation 警告を追記

### WebFetch コマンド例

```
WebFetch(
  url: "https://agentskills.io/specification",
  prompt: "SKILL.md フロントマター仕様の全フィールドと文字数制限・命名規則を確認。前回確認時から変更点を列挙してください。"
)
```

確認結果は会話内に記録し、判定マトリクス・テンプレート・チェックリストへの反映要否を判断する。

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

## 🔴 Agent Skills 標準 vs Claude Code 拡張

スキル定義は **Agent Skills 標準**（<https://agentskills.io/specification>）に準拠することが基本。
Claude Code は標準を拡張しており、`context: fork`・`agent`・`when_to_use`・`disable-model-invocation` 等は **Claude Code 固有**で他クライアント非互換。

### 標準準拠フィールド（クロスクライアント互換）

| フィールド | Required | 制約 |
|---------|----------|------|
| `name` | Yes | Max 64 chars。lowercase alphanumeric + hyphens のみ。先頭末尾ハイフン禁止、連続ハイフン禁止。**親ディレクトリ名と一致必須** |
| `description` | Yes | **Max 1,024 chars（非空）**。何をするか・いつ使うかを記述 |
| `license` | No | ライセンス名 or 同梱ライセンスファイルへの参照 |
| `compatibility` | No | Max 500 chars。動作環境要件（対象プロダクト・必要パッケージ等） |
| `metadata` | No | 任意の key-value マップ |
| `allowed-tools` | No | 事前承認ツールのスペース区切り文字列（Experimental） |

### Claude Code 固有拡張フィールド（標準にない）

| 拡張フィールド | 目的 | 互換性 |
|--------------|------|--------|
| `context: fork` | サブエージェント分離実行（中間ログ隔離・92% context 削減） | **Claude Code のみ** |
| `agent` | fork 時のサブエージェント種類指定 | **Claude Code のみ** |
| `when_to_use` | description を補完（合算で 1,536 文字まで） | Claude Code のみ |
| `disable-model-invocation` | Claude の自動呼び出し禁止・subagent preload 抑制 | Claude Code のみ |
| `user-invocable` | / メニューでの表示制御 | Claude Code のみ |
| `model` | スキル発動時のモデル切替 | Claude Code のみ |
| `effort` | low / medium / high / xhigh / max | Claude Code のみ |
| `hooks` | スキル単位の hook 定義 | Claude Code のみ |
| `paths` | glob パターンでスキル発火条件を限定 | Claude Code のみ |
| `shell` | bash / powershell 切替 | Claude Code のみ |
| `argument-hint` | 自動補完表示用ヒント | Claude Code のみ |
| `arguments` | $N 置換用の名前付き位置引数 | Claude Code のみ |

### 設計指針

- **クロスクライアント配布**を考えるなら標準フィールドのみ使用（name / description / license / compatibility / metadata / allowed-tools）
- **Claude Code 専用**なら拡張フィールド利用可（`context: fork` 等）
- 拡張フィールドを使う場合は `compatibility: Designed for Claude Code` を任意で記載

> ⚠️ `context: fork` / `agent` は Claude Code 固有拡張。Cursor / Gemini CLI / OpenCode / Goose 等では動作しない。詳細は [FORK-GUIDE.md](references/FORK-GUIDE.md) を参照。

---

## 共通: フロントマター仕様

### 命名規則

| コンポーネント | 命名 | 例 |
|--------------|------|-----|
| Agent ファイル | ケバブケース | `tachikoma-nextjs.md` |
| Skill ディレクトリ | 動名詞形（verb + -ing） | `developing-nextjs/` |
| Command ファイル | ケバブケース | `pull-request.md` |

### name フィールドの公式制約（Agent Skills 標準準拠）

Skill / Command の `name` フィールドには以下の制約がある（標準仕様の必須項目）:

- **1-64 chars**
- **lowercase alphanumeric + hyphens のみ**（Unicode 対応）
- **先頭末尾ハイフン禁止**、**連続ハイフン禁止**
- 🔴 **親ディレクトリ名と一致必須**（例: `skills/my-skill/SKILL.md` の `name` は必ず `my-skill`）

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
- **1024文字以下**（Agent Skills 標準制限）。`when_to_use` フィールド併用時のみ Claude Code 固有挙動で合算 1,536 文字まで拡張可能
- 具体的なタスク・技術名を列挙する（「helps with X」はNG）

---

## Agent 定義: 概要

Agent定義ファイルの詳細は [AGENT-GUIDE.md](references/AGENT-GUIDE.md) を参照。テンプレートは [AGENT-TEMPLATE.md](references/AGENT-TEMPLATE.md) を参照。
エージェントのファイル命名規則・ディレクトリ構造・スキルカバレッジ分析については AGENT-GUIDE.md の該当セクションを参照。

### フロントマターフィールド早見表

```yaml
---
name: タチコマ（role）           # 必須: 表示名
description: "..."                # 必須: トリガー検出用（英語推奨）
model: sonnet                      # sonnet / opus[1m] / haiku / inherit
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

### Three-Stage Loading（🔴 必須パターン）

```
Stage 1: SKILL.md 自動注入（200〜500バイト = 100 tokens 程度）
  → フロントマター（description）のみがコンテキストに入る
  → Agent Skills 標準の Metadata ステージに相当
Stage 2: INSTRUCTIONS.md オンデマンド読み込み（< 5,000 tokens 推奨）
  → Claude が必要と判断した時のみ詳細な手順・ガイドラインを読み込む
  → Agent Skills 標準の Instructions ステージに相当
Stage 3: context: fork（Claude Code 固有拡張・オプション）
  → スキル実行をサブエージェントに分離、中間ログを親会話から隔離
  → 親会話に戻るのは最終結果のサマリーのみ（92% context 削減効果）
  → 🔴 アクション型スキルのみ有効。リファレンス型は機能停止するため禁止
```

**効果**: Stage 1+2 だけで全体の 94.8% のコンテキスト節約。Stage 3（fork）追加でさらに親会話圧迫を軽減。

### SKILL.md テンプレート

**最小構成（標準準拠フィールドのみ）:**

```yaml
---
name: my-skill                   # 必須・親ディレクトリ名と一致・1-64 chars
description: >-                  # 必須・max 1,024 chars
  What it does. Use when [trigger]. For X, use Y instead.
---

詳細な手順・ガイドラインは `INSTRUCTIONS.md` を参照してください。
```

**フル構成（Claude Code 拡張フィールドを含む・fork化スキル向け）:**

```yaml
---
# === Agent Skills 標準フィールド ===
name: my-skill                   # 必須・親ディレクトリ名と一致・1-64 chars
description: >-                  # 必須・max 1,024 chars
  What it does. Use when [trigger]. For X, use Y instead.
license: MIT                     # 任意
compatibility: >-                # 任意・max 500 chars
  Designed for Claude Code (uses context: fork extension)
metadata:                        # 任意
  version: "1.0"

# === Claude Code 固有拡張フィールド ===
when_to_use: >-                  # 任意。description と合算で 1,536 文字まで
  Additional trigger text.
context: fork                    # fork化対象のみ（アクション型に限定）
agent: general-purpose           # Explore / Plan / general-purpose / custom
disable-model-invocation: false  # ⚠️ true で description 除外 + subagent preload 抑制
---

詳細な手順・ガイドラインは `INSTRUCTIONS.md` を参照してください。
```

### Progressive Disclosure（段階的開示）

INSTRUCTIONS.md本文は **500行以下**を目安とする（**出典**: Agent Skills 標準仕様 - <https://agentskills.io/specification>、Progressive Disclosure 維持のため）。500行超の場合は `references/` に詳細を分離:

```
my-skill/
├── SKILL.md              # フロントマター + ポインター（自動注入）
├── INSTRUCTIONS.md       # 本文全体（オンデマンド）
└── references/           # 詳細ドキュメント（必要時のみ）
    ├── REFERENCE.md
    └── EXAMPLES.md
```

### 呼び出し制御

| パターン | `disable-model-invocation` | `user-invocable` | `context` | `agent` | 用途 |
|---------|--------------------------|-----------------|-----------|--------|------|
| リファレンス型・通常 | `false`（デフォルト） | `true`（デフォルト） | 省略 | 省略 | ガイドライン提供型 |
| アクション型・通常 | `false` | `true` | 省略 | 省略 | 親文脈密接なタスク型 |
| アクション型・fork | `false` | `true` | `fork` | `Explore` or `general-purpose` | 大量出力タスク型 |
| 手動のみ・fork | `true` | `true` | `fork` | 指定 | ユーザー明示呼出+大量出力 |
| Agent preload | `false` | `false` | 省略推奨 | — | Agent 専有知識 |

> `disable-model-invocation: true` を設定すると、descriptionがコンテキストから**完全に除外**される（subagent への preload も抑制）。Agentから参照するスキルには **必ず `false`（またはフィールド省略）** を設定する。

### fork 判定ロジック（5軸評価）

`context: fork` を付けるかどうかは以下の 5 軸を**上から順に**評価して決定する。

| 軸 | 質問 | fork 不可条件 |
|----|------|-------------|
| **🔴 軸0. 移植性** | Claude Code 専用で良いか? | クロスクライアント互換が必要なら **fork 不可** |
| **🔴 軸D. 種別** | 明示的タスクの実行（アクション型）か? | リファレンス型（ガイドライン提供）なら **fork 不可** |
| **軸A. 文脈依存** | 親会話のコード・議論・前段結果を参照するか? | 高依存なら **fork 不可** |
| **軸B. 出力量** | 実行時に大量ログ・grep結果・API応答が発生するか? | 少量なら **現状維持** |
| **軸C. サマリー可能性** | 中間プロセスを捨て最終結果のみで意思決定できるか? | 不可なら **現状維持** |

**4段階判定ルール:**

| 判定 | 条件 | アクション |
|------|------|-----------|
| 🔴 fork 不可（互換性） | 軸0=互換必須 | `context: fork` 不採用 |
| 🔴 fork 不可（種別） | 軸D=リファレンス型 または 軸A=高依存 | 絶対に fork を付けない（空応答・機能停止） |
| **fork 化** | 軸0=CC専用OK かつ 軸D=アクション型 かつ 軸A=低 かつ 軸B=大 かつ 軸C=可 | `context: fork` + `agent:` を追加 |
| 現状維持 | 上記以外 | 変更しない |

> **公式警告**: `context: fork` はアクション型のみ有効。ガイドライン提供型（"use these API conventions" 等）に付けると、サブエージェントが受け取るもののアクション可能なプロンプトがなく空応答で返る。

**アクション型 vs リファレンス型の判別:**

| 種別 | 特徴 | キーワード例 |
|------|------|-----------|
| **アクション型** | 「〇〇を実行する」「〇〇を生成する」「〇〇を変換する」 | search / find / convert / generate / create / evaluate / fetch |
| **リファレンス型** | 「〇〇規約に従う」「〇〇パターン集」「〇〇原則」 | guide / reference / principles / patterns / conventions |

詳細ガイドは [FORK-GUIDE.md](references/FORK-GUIDE.md) を参照。

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
- [ ] Step 0「最新仕様確認」を実施済みか（Agent Skills 標準・Claude Code 拡張の現行仕様を確認）
- [ ] フロントマターのYAMLが正しくパースされるか
- [ ] description が三部構成になっているか
- [ ] description が1024文字以下か（`python3 -c "import yaml; ..."` で検証）
- [ ] `name` が親ディレクトリ名と一致しているか（Agent Skills 標準必須）
- [ ] Agent: `tools`フィールドが権限最小化されているか（省略していないか）
- [ ] Agent: `skills`フィールドのスキル名が実在するか
- [ ] Skill: Three-Stage Loading（SKILL.md + INSTRUCTIONS.md + 任意fork）構造になっているか
- [ ] Skill: エージェントから参照するなら `disable-model-invocation: false`
- [ ] Skill: `context: fork` を付ける場合、5軸判定でアクション型・低文脈依存を確認したか
- [ ] `plugin.json` への登録が完了しているか（必要な場合）
- [ ] `README.md` が更新されているか
- [ ] `rules/skill-triggers.md` のルーティング表との整合性（Agent追加時）
- [ ] 標準準拠の検証: `skills-ref validate ./skills/<skill-name>`（<https://github.com/agentskills/agentskills/tree/main/skills-ref>）

### 標準フィールドの活用（任意推奨）

| フィールド | 活用シーン | 例 |
|---------|----------|-----|
| `license` | プラグイン全体のライセンス継承 | `license: MIT` |
| `compatibility` | Claude Code 固有拡張を使うスキルに移植性警告 | `compatibility: Designed for Claude Code` |
| `metadata` | バージョン管理・タグ付け | `metadata: {version: "1.0"}` |
| `allowed-tools` | Experimental 段階。積極使用は見送り | — |

---

## 外部設定ファイル同期（Agent追加・変更・削除時）

| 操作 | `skill-triggers.md` | `tachikoma-system.md` | `README.md` |
|------|---------------------|----------------------|-------------|
| **新規作成** | 🔴 行追加 | 🔴 行追加 | 🔴 行追加 |
| **description変更** | 🟡 条件更新（ルーティングに影響する場合） | 不要 | 不要 |
| **name変更** | 🔴 subagent_type列更新 | 🔴 subagent_type列更新 | 🔴 name列更新 |
| **削除** | 🔴 行削除 | 🔴 行削除 | 🔴 行削除 |

---

## スキル変更時のエージェント影響分析

スキルを作成・変更・削除した場合、`agents/` 内の関連エージェントへの影響を確認する。

### 影響判定マトリクス

| 操作 | 確認事項 | 対応 |
|------|---------|------|
| **新規作成** | 関連エージェントへのプリロード検討 | ドメイン親和性・スキル数（3-9目安）を確認し、適切なエージェントに追加 |
| **スキル名変更** | 参照エージェントの `skills:` フィールド | 全参照エージェントのフロントマターを更新 |
| **内容大幅変更** | エージェント body の「専門領域」セクション | 主要概念・推奨パターンが変わった場合は要約も更新 |
| **削除** | `skills:` フィールドの参照除去 | 全参照エージェントから該当スキル名を削除 |

### 2層影響チェック手順

影響範囲は「フロントマター参照」と「body 要約」の2層で確認する:

1. **フロントマター `skills:` 参照チェック**
   ```bash
   grep -rl "skill-name" agents/*.md   # 参照エージェントを検出
   ```
2. **body「専門領域」セクション要約チェック**
   - 参照エージェントの「専門領域」セクションを読み、スキルの変更内容と乖離がないか確認
   - 主要概念・用語・推奨パターンが変わった → body 要約も更新必須
   - マイナーな詳細変更のみ → body 更新は不要（スキル全文がプリロードされるため）

### 新規スキル作成時のプリロード判断フロー

| 条件 | 判断 |
|------|------|
| 既存エージェントのドメインと親和性が高い | 既存エージェントへの `skills:` 追加を検討 |
| プリロード後の合計スキル数が 9 を超える | 追加を見送るか、優先度の低いスキルと入れ替え |
| どの既存エージェントとも親和性がない | 新規エージェント作成を検討 |
| スキルが軽量・汎用（チェックリスト等） | オンデマンド参照のみで十分（プリロード不要） |

詳細な手順は [AGENT-GUIDE.md](references/AGENT-GUIDE.md) の「スキル変更時のエージェント更新」セクションを参照。

---

## AskUserQuestion 埋め込み設計

AskUserQuestion の使い方は2つの文脈で異なる。混同しないこと。

| 文脈 | 説明 | 例 |
|------|------|-----|
| **プロセス中の確認** | スキル/エージェントを*作成するプロセス*の中でユーザーに確認する | 「このスキルにはどのモデルを使いますか？」 |
| **コンテンツへの埋め込み** | *作成されるスキル/エージェント自体*の中に判断分岐を組み込む | 作成したスキルの INSTRUCTIONS.md に AskUserQuestion パターンを記述 |

### 埋め込みが必要なスキル・エージェントの判断基準

| 条件 | 対応 |
|------|------|
| アーキテクチャ選択肢が複数ある（DB設計・デプロイ戦略等） | 必須: 判断分岐箇所に埋め込む |
| ベストプラクティスが唯一（型安全・セキュリティ等） | 不要: 推奨パターンを直接記述 |
| 環境依存の設定がある（クラウドリージョン等） | 推奨: 確認後に手順を分岐 |
| エージェントが `background: true` で起動される | ⚠️ AskUserQuestion は失敗する → SendMessage で本体に委譲するパターンに変更 |

### background: true 時の制約と代替策

`background: true` フィールドを持つエージェントはユーザーとの対話ができない。確認が必要な場合は以下を設計する:

```markdown
## ワークフロー

1. 判断が必要な場合は SendMessage で本体（Claude Code）に委譲する
   - 例: 曖昧な要件は本体が AskUserQuestion で確認済みの前提で受け取る
2. 自己判断できる範囲でのみ実行し、不明点は完了報告に明記する
```

詳細は [SKILL-GUIDE.md](references/SKILL-GUIDE.md) の「AskUserQuestion Pattern」、
[AGENT-GUIDE.md](references/AGENT-GUIDE.md) の「AskUserQuestion の使いどころ」、
[TEMPLATES.md](references/TEMPLATES.md) のテンプレート集を参照。

---

## 🔴 完了ワークフロー（全作業完了時・必須）

**すべてのワークフロー（新規作成・変更・変換）の最終ステップとして必ず実行する。スキップ不可。**

すべてのコンポーネント作成・更新作業が完了したら、以下の手順でバージョン更新・タグ付与・コミットを行う。

### 1. バージョン更新

`.claude-plugin/plugin.json` の `version` フィールドを Semantic Versioning に従って更新する:

| 変更内容 | バージョン | 例 |
|---------|----------|-----|
| 新規コンポーネント追加（スキル・Agent・Command） | **MINOR** | `9.24.0` → `9.25.0` |
| 既存コンポーネントの修正・改善 | **PATCH** | `9.24.0` → `9.24.1` |
| 破壊的変更（スキルの大幅な構成変更等） | **MAJOR** | `9.24.0` → `10.0.0` |

### 2. コミット

Conventional Commits 形式でコミットする:

```bash
git add <変更ファイル> .claude-plugin/plugin.json
git commit -m "feat(skill-name): 変更内容の要約"
```

### 3. タグ付与

```bash
git tag v{new-version}
```

**⚠️ git書き込み操作（commit / tag）はユーザー確認必須。** タチコマが直接実行してはならない。Claude Code本体がユーザーに確認した上で実行する。

---

## 関連ドキュメント

### Agent詳細
- **[AGENT-GUIDE.md](references/AGENT-GUIDE.md)**: フロントマター詳細・ツール制限・permissionMode・並列実行・体制同期手順
- **[AGENT-TEMPLATE.md](references/AGENT-TEMPLATE.md)**: タチコマAgent定義テンプレート

### Skill詳細
- **[SKILL-GUIDE.md](references/SKILL-GUIDE.md)**: Skill作成・変換・レビューの完全ガイド
- **[FORK-GUIDE.md](references/FORK-GUIDE.md)**: `context: fork` 詳細ガイド（5軸判定マトリクス・適用例・アンチパターン・移植性警告）
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
