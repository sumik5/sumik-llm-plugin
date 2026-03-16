# Codex Agent オーケストレーション

**Codex本体はオーケストレーターに徹し、tachikoma-architecture agent に計画策定を委譲する。計画承認後、ドメイン別専門agentをWave単位で最大並列起動する。**

---

## 概要

### Claude Code Team方式（比較参考）
```
TeamCreate → タチコマ並列起動（tmux pane）→ SendMessage → TeamDelete
```

### Codex方式（このスキル）
```
Codex本体 → tachikoma-architecture agent（計画策定・Wave分割）
         → ユーザー確認（テキストベース）
         → Wave 1: 独立agentを同時並列起動 → 全完了待ち
         → Wave 2: Wave 1に依存するagentを同時並列起動 → 全完了待ち
         → ...（Wave N まで繰り返し）
```

**Codex環境ではClaude Code Team API（TeamCreate/SendMessage等）が使えないため、agentを直接呼び出す方式で同等のワークフローを実現する。**

### Wave並列実行の原則

**🔴 依存関係がないタスク群は必ず同一Waveにまとめて並列起動する。逐次実行はアンチパターン。**

```
❌ Bad: DB設計 → API実装 → 型定義 → UI実装 → テスト（全直列）
✅ Good:
  Wave 1: DB設計 + 共通型定義（独立タスク）
  Wave 2: API実装 ∥ UIスケルトン実装（Wave 1に依存、相互に独立）
  Wave 3: E2Eテスト ∥ 統合テスト（Wave 2に依存、相互に独立）
```

---

## 前提条件

- Codex CLI がインストール済み
- `~/dotfiles/codex/agents/` にagent定義ファイルが存在
- Git が使用可能

---

## 使用タイミング

**🔴 ファイルを読んで判断しない。ユーザーの要求文から以下に該当しそうなら即座にtachikoma-architecture agentを起動:**

1. **複数の機能・コンポーネント** に言及している（例: 「UIとAPIを作って」）
2. **異なる関心事** が含まれる（例: 「フロントエンドとバックエンドを変更」）
3. **複数のサブタスク** が明示的または暗示的に含まれる
4. **「〜を追加して」＋「テストも書いて」** のような複合要求

**以下の場合のみ単体agent起動:**
- 明らかに1ファイルのみの変更（「このファイルのバグを直して」）
- 単一の小さなタスク（「typoを修正して」）

---

## クイックスタート（2フェーズ方式）

### Phase 1: 計画策定（tachikoma-architecture agent に全委譲）
1. **tachikoma-architecture agent 起動** - ユーザー要求をそのまま渡す。現状把握・コードベース分析・要件整理・**Wave分割**・`docs/plan-{feature}.md` 作成を全てplannerが実行
2. **計画レビュー・承認** - Codex本体がdocs/planの内容をユーザーに提示し、承認を求める

### Phase 2: 実装（Wave単位で最大並列起動）
3. **Wave N のagentを全て同時起動** - 同一Wave内のagentは並列実行（ファイル所有権が分離済み）
4. **Wave N の全agent完了を待機** → **Wave N+1 のagentを全て同時起動**
5. **全Wave完了後** - 品質チェック・統合確認

**🔴 Codex本体はファイルを読まない・分析しない。** ユーザー要求を受け取ったら即座にtachikoma-architecture agentを起動。現状把握からWave分割・計画策定まで全てplannerの責務。

---

## 🔴 並列起動の実装方法（最重要）

**Wave内の複数agentは、1つのレスポンス内で複数のAgent tool呼び出しを同時に行うことで並列起動する。1つずつ順番に起動してはならない。**

### 正しいパターン（並列起動）

```
# Wave 2の2つのagentを同時に起動する場合:
# → 1つのレスポンス内で、2つのAgent tool callを同時に発行する

Agent tool call 1: tachikoma-fullstack-js（API実装）  ← 同時発行
Agent tool call 2: tachikoma-nextjs（UI実装）          ← 同時発行

# 両方のagentが完了するまで待機
# → 両方完了したらWave 3へ進む
```

### 間違ったパターン（逐次起動 = アンチパターン）

```
❌ Agent tool call: tachikoma-fullstack-js → 完了待ち → Agent tool call: tachikoma-nextjs
   これは逐次実行であり、Wave並列の意味がない
```

### 実装の鍵

1. **同一Wave内の全agentを1つのメッセージで同時にAgent tool呼び出しする**
2. **各agentのプロンプトにファイル所有権を明記する**（並列実行で競合しないため）
3. **全agentの完了を待ってから次のWaveの全agentを同時起動する**
4. **Wave内のagent数に上限はない** - 独立タスクが5つあれば5つ同時起動する

---

## 🔴 ファイル所有権パターン（必須ルール）

**Wave内の並列agentが同一ファイルに書き込むと競合する。plannerが排他的所有権を厳密に定義すること。**

plannerが事前にパスベースの所有権を定義（Wave内で重複禁止）:
```
frontend agent: src/components/**, src/pages/**
backend agent: src/api/**, src/services/**, src/models/**
test agent: tests/e2e/**, tests/integration/**
architect agent: docs/design/**
```

**各agentは自身の所有範囲外のファイルを編集しない。** 共有ファイル（型定義・設定ファイル等）はWave分割で先行Waveに配置するか、1つのagentに所有権を集約する。

---

## Agent マッピング表

| Claude Code subagent_type | Codex agent名 | 用途 |
|--------------------------|--------------|------|
| `sumik:タチコマ（アーキテクチャ）` | `tachikoma-architecture` | 設計・計画策定（読取専用） |
| `sumik:タチコマ（Next.js）` | `tachikoma-nextjs` | Next.js/React開発 |
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
| `sumik:タチコマ（セキュリティ）` | `tachikoma-security` | セキュリティ監査（読取専用） |
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

### Agent選択の判断基準

- プロジェクトの技術スタック（package.json, go.mod等）から判定
- 複数候補がある場合はより専門的な方を優先
- 汎用 `tachikoma` は専門agentでカバーされない場合のフォールバック

---

## タスク分解ルール

### 最適なタスク粒度
- **1 agentあたり3-5タスクを目標**（並列度を上げるため、agentあたりのスコープを絞る）
- タスクが多すぎる（6+）→ agentのコンテキスト過負荷、完了まで他Waveをブロック
- タスクが少なすぎる（1）→ agent起動のオーバーヘッドが相対的に大きい

### Wave分割の原則（🔴 並列度最大化）

**plannerは依存関係グラフを作成し、独立タスクを同一Waveにまとめる。Waveの数を最小化（=並列度を最大化）することが最優先。**

```
Wave 1: スキーマ設計 (tachikoma-database) ∥ 共通型定義 (tachikoma-typescript)
  ↓ 全完了待ち
Wave 2: API実装 (tachikoma-fullstack-js) ∥ UIスケルトン (tachikoma-nextjs)
  ↓ 全完了待ち
Wave 3: E2Eテスト (tachikoma-e2e-test) ∥ 統合テスト (tachikoma-test)
```

#### Wave分割の判断基準

| 条件 | Wave配置 |
|------|---------|
| 他タスクへの依存なし | Wave 1（最初に並列起動） |
| Wave N の成果物を読むだけ（書かない） | Wave N+1 で並列起動可能 |
| 他agentが作成したファイルを**編集**する必要がある | 別Waveに分離（先行Wave完了後に起動） |
| 同一ファイルに複数agentが書き込む | **同一Waveに入れてはならない** → 所有権を分離するか、1つのagentに統合 |

#### 並列度を上げるテクニック

1. **共通型定義・インターフェースを先行Wave（Wave 1）に分離** → API/UIが同時に着手可能
2. **テスト作成は実装と同一Waveに配置可能**（テストagentは実装agentと異なるファイルを所有）
3. **同一agentを複数起動してスコープ分割**（例: tachikoma-nextjs × 2 で異なるページ群を並列実装）
4. **ドキュメントagentは実装と並列起動可能**（docsファイルは実装agentの所有外）

---

## Git連携注意事項

### git操作の原則
- **Git を使用**
- **git読み取り操作は全agent許可**: `git status`, `git diff`, `git log`
- **git書込操作はCodex本体のみ**: `git commit`, `git push` → ユーザー確認必須

### 並列作業時の注意
- **全agentの変更は同一ブランチに統合される**（Wave内の並列agentも同様）
- ファイル所有権が分離されていれば並列書き込みでも競合しない
- 作業完了後、`git status` で全変更を確認してからコミット判断をユーザーに委ねる

---

## 🔴 絶対に避けるべきこと

- **Codex本体がファイルを読んで分析する**（plannerの責務）
- **同一Wave内で同一ファイルに複数agentが書き込む**（並列実行で競合する）
- **依存関係がないタスクを逐次実行する**（並列化できるのに直列にするのはアンチパターン）
- **`docs/plan-*.md` なしでagentを起動する**（回復不能になる）
- **汎用tachikoma agentを安易に使わない** → Agent マッピング表から適切な専門agentを選択
- **ユーザー確認なしに計画を実行する**（必ず計画を提示して承認を得る）
- **Claude Code Team API（TeamCreate等）を呼び出す**（Codex環境では使えない）

---

## サブファイルナビゲーション

| ファイル | 内容 |
|---------|------|
| `references/PLAN-TEMPLATE.md` | `docs/plan-{feature-name}.md` テンプレート・回復手順・実行ログ記録方法 |
| `references/WORKFLOW-GUIDE.md` | Phase 1-2 詳細ワークフロー（計画策定 → ユーザー確認 → Wave並列実装 → 統合 → 完了） |

---

## 関連スキル

- `orchestrating-teams` - Claude Code Team並列実行版（Claude Code環境用）
- `implementing-as-tachikoma` - タチコマAgent運用ガイド
- `using-serena` - トークン効率化開発
