# Agent Definition Authoring Guide

エージェント定義ファイル（`agents/*.md`）の作成・修正・改善を体系的にガイドするスキル。
19体の専門タチコマ作成で確立したパターンと、公式ドキュメント・コミュニティのベストプラクティスに基づく。

---

## When to Use

- 新しい専門タチコマの作成
- 既存エージェント定義の修正・改善・最適化
- エージェントに割り当てるスキル・ツール・権限の選定
- エージェントのモデル・色・description・permissionMode 設計
- エージェントのパフォーマンス問題やコンテキスト溢れの診断

---

## Agent vs Skill の違い

| 項目 | Agent（`agents/*.md`） | Skill（`skills/*/SKILL.md`） |
|------|----------------------|---------------------------|
| 配置 | `agents/<name>.md` | `skills/<name>/SKILL.md` |
| 構造 | 単一ファイル（YAML + Markdown body） | SKILL.md + INSTRUCTIONS.md + references/ |
| 起動 | Task tool の `subagent_type` で指定 | Skill tool でロード |
| 目的 | **独立した実行エージェント**の定義 | **知識・ガイドライン**の提供 |
| コンテキスト | 独立した専用ウィンドウ | 親会話のコンテキストに注入 |
| skills フィールド | スキル全文をプリロード | なし |

**判断基準:** コンテキストを分離したい / ツールを制限したい / 並列実行したい → Agent。知識を共有したい / 親会話で使いたい → Skill。

---

## フロントマター仕様

```yaml
---
name: タチコマ（role）                    # 必須: 表示名
description: "Domain description..."      # 必須: トリガー検出用（英語推奨）
model: sonnet                             # 任意: sonnet / opus / haiku / inherit
color: cyan                               # 任意: ターミナル表示色
tools: Read, Grep, Glob, Edit, Write, Bash  # 任意: 許可ツール（省略=全ツール）
disallowedTools: Write, Edit              # 任意: 拒否ツール
permissionMode: default                   # 任意: 権限モード
maxTurns: 50                              # 任意: 最大ターン数
skills:                                   # 任意: プリロードするスキル一覧
  - domain-skill-1
  - writing-clean-code
memory: project                           # 任意: 永続メモリスコープ
mcpServers:                               # 任意: MCPサーバー
  - serena
hooks:                                    # 任意: ライフサイクルフック
  PreToolUse: [...]
background: false                         # 任意: 常にバックグラウンド実行
# isolation: worktree                     # 任意: Git worktree分離（jj環境では非推奨。詳細はINSTRUCTIONS.md「isolation: worktreeとの使い分け」参照）
---
```

### 各フィールド詳細

| フィールド | 必須 | 説明 |
|-----------|------|------|
| `name` | Yes | `タチコマ（role）` 形式。roleはドメインを端的に表す日本語 |
| `description` | Yes | 英語で記述。3部構成: 何をするか + Use when + Detects |
| `model` | No | `sonnet`（実装）/ `opus`（設計・レビュー）/ `haiku`（軽量）/ `inherit`（親継承）。省略時=inherit |
| `color` | No | ターミナルでの識別色（`orange`, `cyan`, `green`, `blue`, `red`, `yellow`） |
| `tools` | No | 許可ツールのホワイトリスト。**省略=全ツール付与（🔴 非推奨）** |
| `disallowedTools` | No | 拒否ツール。toolsとの差分で最終権限を決定 |
| `permissionMode` | No | `default` / `acceptEdits` / `dontAsk` / `bypassPermissions` / `plan` |
| `maxTurns` | No | 最大エージェントターン数。暴走防止に有効 |
| `skills` | No | スキル名の配列。**全文がコンテキストに注入**される（参照ではない） |
| `memory` | No | `user`（全プロジェクト共有）/ `project`（VCS共有）/ `local`（ローカル専用） |
| `mcpServers` | No | 使用可能なMCPサーバー名の配列、またはインライン定義 |
| `hooks` | No | PreToolUse/PostToolUse/Stopイベントのフック定義 |
| `background` | No | `true` で常にバックグラウンド実行 |
| `isolation` | No | `worktree` でGit worktreeで分離実行（並列作業時に有効） |

---

## description の設計（🔴 最重要）

descriptionはClaude Code本体がタスク委譲先を判断する**唯一の手がかり**。質の低いdescriptionは誤ルーティングの原因になる。

### 三部構成

```
"{ドメイン} specialized Tachikoma execution agent.
 Handles {具体的なタスク列挙}.
 Use proactively when {トリガー条件}. Detects: {ファイルパターン}."
```

### 設計チェックリスト

- [ ] **アクション指向**: 「何をするか」が冒頭で明確
- [ ] **具体的なタスク列挙**: 抽象的な「開発を支援」ではなく具体的技術・タスクを列挙
- [ ] **"Use proactively when"を含む**: 自動委譲のトリガー条件
- [ ] **"Detects:"を含む**: ファイルパターンによる検出条件
- [ ] **既存エージェントとの境界が明確**: 類似ドメインとの差別化

**良い例:**
```yaml
description: "Next.js/React specialized Tachikoma execution agent. Handles Next.js 16 App Router, Server Components, React 19 features, Turbopack, Cache Components, and next-devtools MCP integration. Use proactively when implementing Next.js pages, components, API routes, middleware, or React features in Next.js projects. Detects: package.json with 'next' dependency."
```

**悪い例:**
```yaml
description: "An agent that helps with web development tasks."
```

---

## ツール制限戦略（🔴 重要）

**`tools` フィールドの省略は全ツールへの暗黙的アクセス権を付与する。** これはセキュリティリスクであり、#1アンチパターンとして報告されている。

### 権限最小化の原則

| エージェント種別 | 推奨 tools | 理由 |
|----------------|-----------|------|
| 読取専用（アーキテクチャ、セキュリティ） | `Read, Grep, Glob, Bash` | コードを変更しない |
| 実装系（Next.js, Python等） | `Read, Grep, Glob, Edit, Write, Bash` | 標準的な実装権限 |
| ドキュメント系 | `Read, Grep, Glob, Edit, Write` | Bash不要の場合が多い |

### MCP・Taskツールの考慮

- MCPツールが必要なエージェントは `mcpServers` で明示的に指定
- サブエージェントは他のサブエージェントを起動できない（Task tool不可）

---

## permissionMode 選択

| モード | 用途 | リスク |
|--------|------|--------|
| `default` | 対話的な作業、標準的な実装 | 低（都度確認） |
| `acceptEdits` | 自動ファイル編集（CI/CD用） | 中 |
| `dontAsk` | 読取専用分析（権限プロンプト自動拒否） | 低 |
| `plan` | 設計・計画フェーズ（読取専用） | 低 |
| `bypassPermissions` | 全権限スキップ | 🔴 高（慎重に使用） |

**推奨:** 実装系は `default` または `acceptEdits`。読取専用は `plan` または `dontAsk`。

---

## スキルプリロード戦略

### コア品質スキル（4種）

コード実装系エージェントには以下をプリロード:

| スキル | 用途 | 対象 |
|--------|------|------|
| `writing-clean-code` | SOLID原則、コードスメル | 全コーディング系 |
| `enforcing-type-safety` | 型安全性（any禁止） | TypeScript/Python系のみ |
| `testing-code` | TDD、テストパターン | テスト実装するエージェント |
| `securing-code` | セキュリティチェック | 全コーディング系 |

### コア品質スキルの例外

| エージェント種別 | コア品質 | 理由 |
|----------------|---------|------|
| アーキテクチャ（読取専用） | なし | コードを書かない |
| セキュリティ（読取専用） | なし | securing-code自体がドメイン |
| ドキュメント | なし | コードを書かない |
| Go | enforcing-type-safety 除外 | 静的型付け言語（型ガード不要） |
| Bash | enforcing-type-safety, testing-code 除外 | シェルスクリプトの特性 |

### コンテキスト予算管理

スキルは **全文がコンテキストに注入** される。過剰なプリロードはコンテキストウィンドウを圧迫し、エージェントの推論能力を低下させる。

- **日常的に参照する知識** → プリロード
- **たまに必要な知識** → プリロードしない（Skill toolでオンデマンド）
- **1エージェントあたり 3-9スキル** を目安
- スキルの総行数を意識する（大きなスキルは1つで数百行消費）

---

## モデル選択戦略

| モデル | 用途 | コスト | 例 |
|--------|------|--------|-----|
| **sonnet** | 実装・テスト・インフラ・ドキュメント | 標準 | Next.js, Python, AWS, テスト |
| **opus** | 設計・分析・セキュリティ監査（高度な推論） | 高 | アーキテクチャ, セキュリティ |
| **haiku** | 定型作業・軽量タスク・コスト重視 | 低 | 探索、コード検索 |
| **inherit** | 親会話のモデルを継承 | 親依存 | 特に指定不要な場合 |

**コスト最適化:** メインセッションをOpusで実行し、実装タチコマはSonnetで集中タスクを処理する。3体並列実行時は通常3-4倍のトークン消費。

---

## Markdown body（システムプロンプト）設計

### 構成順序

```markdown
# 言語設定（最優先・絶対遵守）
CRITICAL: 日本語で応答

# 実行エージェント（タチコマ・{role}専門）

## 役割定義
何をするか。Claude Code本体からの委譲を受ける。**ペルソナを明確に。**

## 専門領域
### {スキル名} スキルの活用
プリロードされたスキルごとに、重要ポイントを要約

## コード設計の原則（必須遵守）
SOLID原則・型安全性・セキュリティ（コア品質スキル参照）

## 基本的な動作フロー
1. タスク受信
2. docs実行指示の確認（並列実行時）
3. MCP確認・情報収集
4. 実装
5. 報告

## 完了定義（Definition of Done）
タスク完了と判断する基準を明記

## 報告フォーマット
完了報告・進捗報告テンプレート

## コンテキスト管理の重要性
状態を持たないため報告時に含めるべき情報

## 禁止事項
挨拶禁止・勝手な作業開始禁止等

## バージョン管理（Jujutsu）
jjコマンド使用ルール
```

### プロンプト設計のベストプラクティス

1. **単一責任**: 1エージェント = 1つの明確なゴール・入力・出力・ハンドオフルール
2. **ペルソナの明確化**: 「シニアReact開発者」「セキュリティ監査官」のように役割を定義
3. **具体的なワークフロー**: When invoked → Step 1 → Step 2 → ... の形式で行動を指示
4. **完了定義（DoD）**: タスク完了と判断する基準をチェックリスト形式で明記
5. **出力フォーマット指定**: 報告・成果物の形式を明確に定義
6. **コンテキスト自己完結**: 親会話のコンテキストは受け取らない前提で、必要な情報をすべてプロンプトに含める

テンプレート全文は [AGENT-TEMPLATE.md](references/AGENT-TEMPLATE.md) を参照。

---

## 専門領域セクションの書き方

各プリロードスキルごとに、そのエージェントが持つ知識を箇条書きで要約する。

**良い例（tachikoma-nextjs.md から）:**
```markdown
### App Router / Server Components
- デフォルトはServer Components。クライアント機能が必要な場合のみ `"use client"`
- データフェッチはサーバーサイドで直接 `async/await` を使用
- Server Actions でフォーム送信・データ更新を処理
```

**悪い例:**
```markdown
### developing-nextjs スキル
developing-nextjs スキルの内容に従ってください。
```

→ スキル全文がプリロードされるため、body に「スキルを参照してください」は不要。**エージェントが日常的に使う重要ポイントだけを抽出する。**

---

## 並列実行対応（🔴 全エージェント必須）

同一エージェントの複数インスタンス並列実行（scale-outパターン）を可能にするため、全エージェントに以下を含める:

### 役割定義に並列命名規則を記述

```markdown
- 並列実行時は「tachikoma-{domain}1」「tachikoma-{domain}2」として起動されます
```

### ワークフローに docs 確認ステップを含める

```markdown
N. **docs実行指示の確認（並列実行時）**
   - Claude Code本体から `docs/plan-xxx.md` のパスと担当セクション名を受け取る
   - 該当セクションを読み込み、担当ファイル・要件・他タチコマとの関係を確認
   - docs内の指示が作業の正式な仕様書として機能する
```

### DoD に docs チェックリスト更新を含める

```markdown
- [ ] docs/plan-*.md のチェックリストを更新した（並列実行時）
```

### 並列安全設計のポイント

- **ファイル所有権の前提**: 同一エージェント複数起動時、各インスタンスは docs/plan で指定された独立のファイルセットを担当する。同一ファイルへの同時書き込みは発生しない前提で設計する
- **状態の独立性**: エージェントは状態を持たない。並列起動された各インスタンスは互いの存在を知らず、独立して動作する
- **docs/plan が調整レイヤー**: Claude Code本体が docs/plan でファイル所有権を事前設計し、各インスタンスに担当範囲を指示することで競合を回避する

### `isolation: worktree` との使い分け

Task tool の `isolation: "worktree"` パラメータは、Git worktree を使ってエージェントごとに独立したリポジトリコピーを作成する技術的分離手段。

**現環境では非推奨の理由:**

- 本プロジェクトは Jujutsu (jj) でバージョン管理しており、git worktree との互換性が不確実
- worktree で分離した変更を後からマージ統合するオーバーヘッドが発生する
- ファイル所有権パターン（docs/plan による事前設計）の方がシンプルかつ実用的

**worktree が有効なケース:**

- git-only 環境（jj を使用していないプロジェクト）
- エージェントが破壊的操作（ファイル大量削除・リネーム等）を行う可能性がある場合
- テスト実行で作業ディレクトリを汚染する可能性がある場合

**結論:** 現在の推奨はファイル所有権パターン（docs/plan による事前設計）。`isolation: worktree` はフロントマターの `isolation` フィールドとして利用可能だが、デフォルトでは設定しない（詳細は [AGENT-TEMPLATE.md](references/AGENT-TEMPLATE.md) 参照）。

---

## 命名規則

### ファイル名

- 形式: `tachikoma-{domain}.md`（ケバブケース）
- 例: `tachikoma-nextjs.md`, `tachikoma-e2e-test.md`, `tachikoma-ai-ml.md`

### name フィールド

- 形式: `タチコマ（{ドメイン名}）`
- ドメイン名は日本語またはよく知られた技術名
- 例: `タチコマ（Next.js）`, `タチコマ（フロントエンド）`, `タチコマ（E2Eテスト）`

### 非タチコマエージェント

タチコマ以外のエージェント（Serena Expert等）は独自の命名で良い。

---

## 新規作成ワークフロー

### Step 1: ドメイン分析

1. 対象ドメインで必要なスキルをリストアップ
2. 既存の専門タチコマと重複しないか確認（`agents/` 内の全ファイル）
3. 既存エージェントの拡張か、新規作成かを判断

### Step 2: スキル・ツール・権限の設計

1. ドメインスキル（2-5個）を選定
2. コア品質スキルの要否を判断（上記の例外ルール参照）
3. 合計 3-9 スキルに収める
4. **ツール制限**: エージェントが必要とするツールのみホワイトリスト化
5. **permissionMode**: 読取専用か実装可能かで選択
6. **memory**: 学習蓄積が有益なドメインか判断
7. **並列実行互換性**: scale-outパターンで複数インスタンス起動される可能性を考慮（並列命名規則・docsステップ・ファイル所有権前提を「並列実行対応」セクションに従い組み込む）

### Step 3: description 作成

1. 三部構成で英語記述
2. `Detects:` にファイルパターンを含める（ルーティング判断に使用）
3. `Use proactively when` でトリガー条件を明記
4. 既存エージェントとの境界を明確にする

### Step 4: body 記述

1. [AGENT-TEMPLATE.md](references/AGENT-TEMPLATE.md) をベースに
2. **専門領域セクション**: 各プリロードスキルの SKILL.md / INSTRUCTIONS.md を読み、重要ポイントを抽出
3. **完了定義（DoD）**: タスク完了の判断基準をチェックリストで明記
4. 要約は「スキルの内容をそのままコピー」ではなく「このエージェントにとって重要なポイント」を抽出

### Step 5: 外部設定ファイルの同期（🔴 必須）

エージェント定義の変更は `$HOME/.claude` 配下の設定ファイルとの整合性維持が必要。**これを怠るとルーティングの不整合が発生する。**

#### 影響判定マトリクス

| 操作 | `skill-triggers.md` | `tachikoma-system.md` | `README.md` | `CLAUDE.md` |
|------|---------------------|----------------------|-------------|-------------|
| **新規作成** | 🔴 行追加 | 🔴 行追加 | 🔴 行追加 | 通常不要 |
| **description変更** | 🟡 検出条件更新（ルーティングに影響する場合） | 不要 | 不要 | 不要 |
| **name変更** | 🔴 subagent_type列更新 | 🔴 subagent_type列更新 | 🔴 name列更新 | 不要 |
| **削除** | 🔴 行削除 | 🔴 行削除 | 🔴 行削除 | 不要 |
| **tools/permissionMode/DoD変更** | 不要 | 不要 | 不要 | 不要 |
| **model変更** | 不要 | 🟡 モデル列更新 | 不要 | 不要 |
| **skills変更** | 🟡 主要プリロードスキル列更新 | 不要 | 不要 | 不要 |

#### 各ファイルの具体的な更新箇所

**1. `$HOME/dotfiles/claude-code/rules/skill-triggers.md`**

更新セクション: `## 🔴 サブエージェントルーティング表`

```markdown
| 検出条件 | 委譲先 subagent_type | 主要プリロードスキル |
|---------|---------------------|-------------------|
| {Detects:パターンに対応する検出条件} | `sumik:タチコマ（{name}）` | {主要スキル名} |
```

- **検出条件**: エージェントの `Detects:` パターンと整合させる（例: `Detects: go.mod` → 検出条件: `Go`）
- **subagent_type**: `sumik:{name フィールドの値}` 形式
- **主要プリロードスキル**: `skills:` フィールドからコア品質スキルを除いたドメインスキルを列挙

**2. `$HOME/dotfiles/claude-code/rules/tachikoma-system.md`**

更新セクション: `### 専門タチコマ一覧（19体）` → カウントも更新

```markdown
| # | subagent_type | モデル | 専門領域 |
|---|--------------|--------|---------|
| {連番} | `sumik:タチコマ（{name}）` | {Sonnet/Opus} | {専門領域} |
```

**3. `README.md`（プラグインルート）**

更新セクション: Agents テーブル + カウント

- テーブルにエージェント行を追加/削除
- ディレクトリ構成セクションのカウントを実数と一致させる

**4. `$HOME/dotfiles/claude-code/CLAUDE.md`** — 通常は変更不要

以下の場合のみ変更が必要:
- 委譲モデル自体の変更（例: 新しいエージェントカテゴリの追加）
- CRITICALルールの変更が必要な構造変更

### Step 6: 検証

- [ ] フロントマターのYAMLが正しくパースされるか
- [ ] skills フィールドのスキル名が実在するか
- [ ] tools フィールドが権限最小化されているか（省略していないか）
- [ ] description が三部構成になっているか
- [ ] body が全セクションを含んでいるか（特に完了定義）
- [ ] `skill-triggers.md` のルーティング表との整合性（検出条件 ↔ Detects:）
- [ ] `tachikoma-system.md` の一覧テーブルとの整合性
- [ ] `README.md` のAgentsテーブル・カウントとの整合性

---

## 既存エージェント改善ワークフロー

既存エージェントの品質向上・最適化のためのチェックリストと手順。

### Step 1: 現状診断

既存エージェントの `.md` ファイルを読み込み、以下の観点で診断する:

#### フロントマター診断

| チェック項目 | 問題兆候 | 改善アクション |
|------------|---------|-------------|
| `tools` が省略されている | 全ツールへの暗黙的アクセス | 必要なツールのみホワイトリスト化 |
| `description` が曖昧 | 誤ルーティング・未使用 | 三部構成で具体化 |
| `skills` が多すぎる（10+） | コンテキスト圧迫 | 日常的に不要なスキルを除外 |
| `model` が不適切 | コスト過剰 or 推論不足 | 用途に応じたモデル再選定 |
| `permissionMode` が未設定 | 不要な権限プロンプト | 適切なモードを設定 |
| `memory` が未設定 | 学習が蓄積されない | 繰り返し使うエージェントに設定 |

#### body（システムプロンプト）診断

| チェック項目 | 問題兆候 | 改善アクション |
|------------|---------|-------------|
| ペルソナが不明確 | 汎用的な応答 | 具体的な専門家像を定義 |
| 動作フローが曖昧 | タスク遂行の一貫性が低い | Step-by-step で明記 |
| 完了定義がない | 中途半端な成果物 | DoDチェックリストを追加 |
| 専門領域がスキル全文のコピペ | コンテキスト浪費 | 重要ポイントのみ抽出 |
| 禁止事項が不十分 | 不要な行動をする | 観察された問題行動を追記 |

### Step 2: 改善の実施

1. **フロントマター改善**: 診断結果に基づきフィールドを追加・修正
2. **body 改善**: 診断結果に基づきセクションを追加・修正
3. **スキル構成の見直し**: プリロード対象の再評価
4. **ルーティング表の整合性確認**: description変更時は必ずルーティング表も更新

### Step 3: 改善の検証

- [ ] 改善前後で description の具体性が向上しているか
- [ ] tools が権限最小化されているか
- [ ] スキルの総数がコンテキスト予算内か
- [ ] 既存のルーティング表との整合性

### 定期メンテナンスのトリガー

以下の状況が発生した場合、エージェント定義の改善を検討する:

- エージェントが**繰り返し同じミス**をする → 禁止事項・動作フローの改善
- **コンテキストが頻繁に溢れる** → スキル数の削減、body の簡素化
- **誤ったエージェントにルーティングされる** → description の差別化強化
- **新しいスキルが追加された** → 関連エージェントへのプリロード検討
- **Claude Codeのバージョンアップ** → 新機能（memory, hooks等）の活用検討

---

## アンチパターン（避けるべき設計）

| アンチパターン | なぜ問題か | 正解 |
|--------------|---------|------|
| `tools` フィールドの省略 | 全ツール（MCP含む）への暗黙的アクセス権付与 | 必要なツールのみホワイトリスト化 |
| description が「helps with X」のような曖昧な記述 | ルーティング精度の低下 | 三部構成で具体的タスク・トリガー条件・ファイルパターンを明記 |
| スキルの過剰プリロード（10+） | コンテキストウィンドウ圧迫、推論能力低下 | 3-9スキルに制限、オンデマンド活用 |
| body でスキル全文をコピペ | 二重注入によるコンテキスト浪費 | 重要ポイントのみ抽出して要約 |
| 完了定義（DoD）の欠如 | 中途半端な成果物、タスク終了の判断が曖昧 | チェックリスト形式でDoDを明記 |
| 複数エージェントの境界が曖昧 | 誤ルーティング、重複実行 | description で明確に差別化 |
| 単一タスクに全エージェント投入 | 3体で3-4倍のトークン消費 | 必要な場合のみ展開、シンプルなタスクは単体起動 |
| `bypassPermissions` の安易な使用 | 全権限チェックをスキップ | `acceptEdits` or `default` で十分な場合が多い |
| 巨大なシステムプロンプト | エージェントの注意力分散 | 要点を絞り、詳細はスキルに委譲 |

---

## AskUserQuestion の使いどころ

以下の判断が必要な場合、推測で進めずユーザーに確認:

- **既存エージェントとの境界が曖昧**: 新エージェントの専門領域が既存と重なる場合
- **モデル選択**: sonnet か opus か判断がつかない場合
- **スキル割り当て**: プリロードすべきかオンデマンドか迷う場合
- **読取専用か実装可能か**: エージェントの権限レベル
- **ツール制限**: 特定のツール（Bash等）を許可すべきか判断がつかない場合

---

## 自己改善プロトコル（🔴 タスク完了後必須）

エージェント作成・変更タスクの完了後、このスキル自身（authoring-agents）を改善する機会を逃さない。

### トリガー

authoring-agents を使用してエージェントの作成・修正・改善を完了した直後。

### 分析の5観点

| # | 観点 | 探すもの |
|---|------|---------|
| 1 | **ユーザーの指示・補足** | タスク中にユーザーから与えられた指示で、INSTRUCTIONS.md にまだ記載されていないもの |
| 2 | **ユーザーの訂正** | Claudeの提案をユーザーが修正した箇所（暗黙の品質基準） |
| 3 | **繰り返しパターン** | 複数のエージェント作成で共通して発生した設計判断・構造パターン |
| 4 | **エッジケース** | 既存ガイドラインでカバーされていなかった状況・判断 |
| 5 | **アンチパターン** | 実行中に発見した「やってはいけないこと」 |

### 実行手順

1. タスク完了報告の後、会話中のユーザー指示・フィードバックを振り返る
2. 上記5観点で改善候補を抽出
3. 既存の INSTRUCTIONS.md / references/* と照合し、**未記載のもののみ**リスト化
4. AskUserQuestion で改善提案を提示し承認を得る
5. 承認された項目を INSTRUCTIONS.md または AGENT-TEMPLATE.md に追記

### 追記ルール

- **If X then Y 形式推奨**: 条件→行動の形式で記述（検索・参照しやすい）
- **適切なセクションに配置**: 既存の構造に自然に馴染む位置に追加（フロントマター仕様、body設計、ワークフロー等）
- **重複回避**: 既に記載されている内容の言い換えは追加しない
- **一般化**: 再利用可能な知見のみ（セッション固有の事情は CLAUDE.md に追記すべき）
- **アンチパターンテーブルへの追加**: アンチパターンを発見した場合は既存の「アンチパターン」テーブルに行を追加
- **外部設定ファイル同期**: 影響判定マトリクスに新しいケースが見つかった場合は Step 5 テーブルを更新

### 追記しないもの

- 1回限りの特殊な指示（一般化できないもの）
- 既にカバーされている内容
- プロジェクト固有の事情（CLAUDE.md や auto-memory に記録すべきもの）

---

## 既存エージェント一覧（参照用）

| ファイル | name | model | 専門領域 |
|---------|------|-------|---------|
| tachikoma.md | タチコマ | sonnet | 汎用フォールバック |
| serena-expert.md | Serena Expert | sonnet | トークン効率化開発 |
| tachikoma-nextjs.md | タチコマ（Next.js） | sonnet | Next.js/React |
| tachikoma-frontend.md | タチコマ（フロントエンド） | sonnet | UI/UX・shadcn |
| tachikoma-fullstack-js.md | タチコマ（フルスタックJS） | sonnet | NestJS/Express |
| tachikoma-typescript.md | タチコマ（TypeScript） | sonnet | TypeScript型設計 |
| tachikoma-python.md | タチコマ（Python） | sonnet | Python・ADK |
| tachikoma-go.md | タチコマ（Go） | sonnet | Go開発 |
| tachikoma-bash.md | タチコマ（Bash） | sonnet | シェルスクリプト |
| tachikoma-infra.md | タチコマ（インフラ） | sonnet | Docker/CI-CD |
| tachikoma-terraform.md | タチコマ（Terraform） | sonnet | Terraform IaC |
| tachikoma-aws.md | タチコマ（AWS） | sonnet | AWS全般 |
| tachikoma-google-cloud.md | タチコマ（Google Cloud） | sonnet | GCP全般 |
| tachikoma-architecture.md | タチコマ（アーキテクチャ） | opus | 設計・DDD（読取専用） |
| tachikoma-security.md | タチコマ（セキュリティ） | opus | セキュリティ監査（読取専用） |
| tachikoma-database.md | タチコマ（データベース） | sonnet | DB設計・SQL |
| tachikoma-ai-ml.md | タチコマ（AI/ML） | sonnet | AI/RAG/MCP/LLM |
| tachikoma-test.md | タチコマ（テスト） | sonnet | ユニット/統合テスト |
| tachikoma-e2e-test.md | タチコマ（E2Eテスト） | sonnet | Playwright E2E |
| tachikoma-observability.md | タチコマ（オブザーバビリティ） | sonnet | 監視・OTel・ログ |
| tachikoma-document.md | タチコマ（ドキュメント） | sonnet | 技術文書・記事 |
| tachikoma-design.md | タチコマ（デザイン） | sonnet | Figma MCP・デザイン→コード |

---

## Related Skills

- **authoring-skills** - スキル（`skills/*/SKILL.md`）の作成ガイド
- **implementing-as-tachikoma** - タチコマとしての実行時動作ガイド
- **orchestrating-teams** - 作成したエージェントをチームで並列起動するワークフロー
- **managing-claude-md** - ルーティング表（`rules/skill-triggers.md`）の更新ガイド
