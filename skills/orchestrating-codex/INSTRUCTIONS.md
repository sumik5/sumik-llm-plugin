# Codex Agent オーケストレーション

**Codex本体はオーケストレーターに徹し、tachikoma-architecture agent に計画策定を委譲する。計画承認後、ドメイン別専門agentが逐次実装する。**

---

## 概要

### Claude Code Team方式（比較参考）
```
TeamCreate → タチコマ並列起動（tmux pane）→ SendMessage → TeamDelete
```

### Codex方式（このスキル）
```
Codex本体 → tachikoma-architecture agent（計画策定）
         → ユーザー確認（テキストベース）
         → ドメイン別agent（逐次実装）
```

**Codex環境ではClaude Code Team API（TeamCreate/SendMessage等）が使えないため、agentを直接呼び出す方式で同等のワークフローを実現する。**

---

## 前提条件

- Codex CLI がインストール済み
- `~/dotfiles/codex/agents/` にagent定義ファイルが存在
- Jujutsu (jj) が使用可能

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
1. **tachikoma-architecture agent 起動** - ユーザー要求をそのまま渡す。現状把握・コードベース分析・要件整理・`docs/plan-{feature}.md` 作成・Codex プランレビューループを全てplannerが実行
2. **計画レビュー・承認** - Codex本体がdocs/planの内容をユーザーに提示し、承認を求める

### Phase 2: 実装（ドメイン別agent 逐次起動）
3. **ドメイン別agentを順次起動** - planに基づき依存関係順に適切なagentを呼び出して実装
4. **各agentの完了確認 → 次のagent起動** を繰り返す
5. **全タスク完了後** - 品質チェック・統合確認

**🔴 Codex本体はファイルを読まない・分析しない。** ユーザー要求を受け取ったら即座にtachikoma-architecture agentを起動。現状把握から計画策定まで全てplannerの責務。

---

## 🔴 ファイル所有権パターン（必須ルール）

**逐次実行のため並行書き込みリスクは低いが、一貫した分離を維持する。**

plannerが事前にパスベースの所有権を定義:
```
frontend agent: src/components/**, src/pages/**
backend agent: src/api/**, src/services/**, src/models/**
test agent: tests/e2e/**, tests/integration/**
architect agent: docs/design/**
```

**各agentは自身の所有範囲外のファイルを編集しない。**

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
- **1 agentあたり5-6タスクを目標**（実証済みの生産性最適値）
- タスクが多すぎる（8+）→ agentのコンテキスト過負荷
- タスクが少なすぎる（1-2）→ agent起動のオーバーヘッドが相対的に大きい

### 実行順序の決定
plannerが依存関係に基づき実行順序を決定する。Codex本体はplannerの計画に従って順次agentを起動:
```
1. スキーマ設計 (tachikoma-database)
2. API実装 (tachikoma-fullstack-js)  ← 1に依存
3. フロントエンド実装 (tachikoma-nextjs)  ← 2に依存
4. テスト作成 (tachikoma-test)  ← 2,3に依存
```

---

## Jujutsu連携注意事項

### jj操作の原則
- **Jujutsu (jj) を使用** - gitコマンドは原則使用禁止（`jj git`サブコマンドを除く）
- **jj読み取り操作は全agent許可**: `jj status`, `jj diff`, `jj log`
- **jj書込操作はCodex本体のみ**: `jj new`, `jj commit`, `jj describe`, `jj push` → ユーザー確認必須

### 逐次作業時の注意
- **各agentの変更は同一 change（`@`）に統合される**
- 作業完了後、`jj status` で全変更を確認してからコミット判断をユーザーに委ねる

---

## 🔴 絶対に避けるべきこと

- **Codex本体がファイルを読んで分析する**（plannerの責務）
- **同一ファイルへの複数agent書き込み**（逐次実行でも前のagentの変更を上書きするリスク）
- **`docs/plan-*.md` なしでagentを起動する**（回復不能になる）
- **汎用tachikoma agentを安易に使わない** → Agent マッピング表から適切な専門agentを選択
- **ユーザー確認なしに計画を実行する**（必ず計画を提示して承認を得る）
- **Claude Code Team API（TeamCreate等）を呼び出す**（Codex環境では使えない）

---

## サブファイルナビゲーション

| ファイル | 内容 |
|---------|------|
| `references/PLAN-TEMPLATE.md` | `docs/plan-{feature-name}.md` テンプレート・回復手順・実行ログ記録方法 |
| `references/WORKFLOW-GUIDE.md` | Phase 1-2 詳細ワークフロー（計画策定 → ユーザー確認 → 逐次実装 → 統合 → 完了） |

---

## 関連スキル

- `orchestrating-teams` - Claude Code Team並列実行版（Claude Code環境用）
- `implementing-as-tachikoma` - タチコマAgent運用ガイド
- `using-serena` - トークン効率化開発
