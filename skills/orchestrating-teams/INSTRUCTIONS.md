# Agent Team オーケストレーション

**Claude Code本体はファイル読み込みや分析を一切行わず、即座にplanner（`sumik:タチコマ（アーキテクチャ）`）に委譲する。plannerが現状把握・計画策定を行い、その計画に基づき**ドメイン別専門タチコマ**が並列実装する。**

---

## 概要

### Before（team-builder Agent方式）
```
Claude Code → Task tool → team-builder(Agent) → TeamCreate → タチコマ
                                                  ↓
                                        tmux制御が効かない（仕様）
```

### After（このスキル方式 - 2フェーズ）
```
Claude Code（このスキルをロード）
    ├─ Phase 1: TeamCreate → planner（sumik:タチコマ（アーキテクチャ）, model: opus）→ コードベース分析・docs/plan作成
    ├─ 計画レビュー・承認（ユーザー確認）
    └─ Phase 2: TaskCreate → ドメイン別専門タチコマ（team_name + run_in_background: true）← tmux pane ✓
                 → 進捗管理 → 統合 → クリーンアップ
```

**Claude Code本体は最小限の判断（並列化の要否）のみ行い、計画策定から実装までAgent Teamに委譲します。**

---

## 前提条件

### 環境要件
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`（settings.jsonの `env` セクション）
- `teammateMode: "tmux"` でClaude Codeを起動
- settings.json設定: `"teammateMode": "tmux"`
- tmuxがインストール済みであること

---

## 🔴 Step 0: Agent Teams API ツールのロード（最初に必ず実行）

**Agent Teams API のツールはすべて「遅延ツール（deferred tools）」であり、ToolSearch で事前にロードしないと呼び出せない。**

スキルをロードしたら、他のどの操作よりも先に以下を実行:

```
ToolSearch("TeamCreate team")       → TeamCreate, TeamDelete がロードされる
ToolSearch("TaskCreate task")       → TaskCreate, TaskUpdate, TaskList がロードされる
ToolSearch("SendMessage message")   → SendMessage がロードされる
```

**⚠️ これを省略すると TeamCreate が呼び出せず、`team_name` 付きで Task tool を呼んでも tmux pane は起動しない（バックグラウンド実行のみになる）。これが tmux pane が開かない最大の原因。**

---

## 使用タイミング（ユーザー要求のテキストから即座に判断）

**🔴 ファイルを読んで判断しない。ユーザーの要求文から以下に該当しそうなら即座にTeamCreate → planner起動:**

1. **複数の機能・コンポーネント** に言及している（例: 「UIとAPIを作って」）
2. **異なる関心事** が含まれる（例: 「フロントエンドとバックエンドを変更」）
3. **複数のサブタスク** が明示的または暗示的に含まれる
4. **「〜を追加して」＋「テストも書いて」** のような複合要求

**以下の場合のみ単体タチコマ起動:**
- 明らかに1ファイルのみの変更（「このファイルのバグを直して」）
- 単一の小さなタスク（「typoを修正して」）

---

## クイックスタート（2フェーズ方式）

### Phase 1: 計画策定（planner タチコマに全委譲）
1. **TeamCreate** - チーム作成（ユーザー要求の内容から team_name を決定するだけ）
2. **planner タチコマ起動（model: opus）** - ユーザー要求をそのまま渡す。現状把握・コードベース分析・要件整理・チーム編成設計・`docs/plan-{feature}.md` 作成・**Codex プランレビューループ**を全てplannerが実行
3. **計画レビュー・承認** - plannerがCodexレビュー済みのdocs/planをユーザーに提示して確認

### Phase 2: 実装（implementer タチコマ並列起動）
4. **TaskCreate + Task tool（`team_name` + `run_in_background: true`）** - plan に基づきドメイン別専門タチコマを `team_name` 付きで並列起動（tmux pane）
5. **進捗管理 → 統合 → クリーンアップ** - SendMessage、TaskList、TeamDelete

**🔴 Claude Code本体はファイルを読まない・分析しない。** ユーザー要求を受け取ったら即座にTeamCreate → planner起動。現状把握から計画策定まで全てplannerの責務。

---

## 🔴 ファイル所有権パターン（必須ルール）

**同一ファイルへの同時書き込みを絶対に避ける。**

パスベースの所有権を事前に定義:
```
frontend: src/components/**, src/pages/**
backend: src/api/**, src/services/**, src/models/**
tester: tests/e2e/**, tests/integration/**
architect: docs/design/**
```

**競合が予想される場合はタスクを順次実行に変更すること。**

---

## タスク分解ルール

### 最適なタスク粒度
- **1メンバーあたり5-6タスクを目標** にする（実証済みの生産性最適値）
- タスクが多すぎる（8+）→ メンバーのオーバーヘッド増加
- タスクが少なすぎる（1-2）→ 待機時間の増加

### 依存関係の明示
- TaskUpdate の `blockedBy` フィールドで前提タスクを指定
- 例: タスク3「API実装」はタスク1「スキーマ設計」に依存
  ```json
  {"taskId": "3", "addBlockedBy": ["1"]}
  ```

---

## Jujutsu連携注意事項

### jj操作の原則
- **このプロジェクトはJujutsu (jj) を使用** - gitコマンドは原則使用禁止（`jj git`サブコマンドを除く）
- **jj読み取り操作のみ許可**: `jj status`, `jj diff`, `jj log`, `jj bookmark list`
- **jj書込操作はリーダー（Claude Code本体）のみ**: `jj new`, `jj commit`, `jj describe`, `jj push` はユーザー確認必須
- **詳細は `rules/jujutsu.md` 参照**

### チーム作業時の注意
- **各メンバーの変更は同一 change（`@`）に統合される**
- **コンフリクトを避けるため、ファイル所有権パターンを厳守**
- 作業完了後、`jj status` で全変更を確認してからコミット判断をユーザーに委ねる

---

## 🔴 絶対に避けるべきこと

- **Bash toolでメンバーを起動しない**（`--team` 等のCLIオプションは存在しない）
- **🔴 `team_name` + `run_in_background: true` を省略しない**（`team_name` なし = tmux paneに表示されない。`run_in_background` なし = 前景で逐次実行。両方必須）
- **Task toolに存在しないパラメータを使用しない**（`task`, `additional_instructions` は無効）
- **同一ファイルへの同時書き込み**（サイレントな上書きが発生）
- **`docs/plan-*.md` なしでチーム作成しない**（回復不能になる）
- **汎用タチコマ（`sumik:タチコマ`）を安易に使わない** → `rules/skill-triggers.md` のルーティング表から適切な専門タチコマを選択

---

## サブファイルナビゲーション

詳細な手順やパターンは以下のリファレンスファイルを参照してください:

| ファイル | 内容 |
|---------|------|
| `references/TEAM-PATTERNS.md` | チーム編成パターン（4種）・モデル戦略（4種）・既存Agent/スキル統合 |
| `references/WORKFLOW-GUIDE.md` | Step 1-8 詳細ワークフロー（要件分析 → チーム作成 → スポーン → 進捗管理 → 統合 → クリーンアップ） |
| `references/PLAN-TEMPLATE.md` | `docs/plan-{feature-name}.md` テンプレート・回復手順・実行ログ記録方法 |

---

## 関連スキル

- `rules/skill-triggers.md` - **サブエージェントルーティング表**（専門タチコマ選択の判断基準）
- `implementing-as-tachikoma` - タチコマAgent運用ガイド
- `using-serena` - トークン効率化開発

---

## 正直な評価

**このスキルの価値は「設計パターンの体系化」と「チーム編成の自動化」の両方にあります。**

Claude Code本体がこのスキルを参照することで、チーム編成・並列実行・進捗管理を体系的に実行できます。以下の場面で特に有効です:

1. **ファイル所有権パターンの事前設計** - 手動では見落としやすい競合を防止
2. **タスク粒度の最適化** - 5-6タスク/メンバーの実証済みパターン適用
3. **モデル戦略の体系化** - コスト効率の判断基準を明文化
4. **再現可能なワークフロー** - チーム編成パターンのテンプレート化
5. **docs先行開発による回復可能性** - 失敗時の復旧手順の確立

**使い分けの推奨:**
- 複数ファイル・複数関心事の並列タスク → このスキル使用
- 1ファイル・単一関心事の軽微修正 → タチコマ直接起動で十分
- ファイル競合リスクが高い → このスキルでファイル所有権パターン設計必須
