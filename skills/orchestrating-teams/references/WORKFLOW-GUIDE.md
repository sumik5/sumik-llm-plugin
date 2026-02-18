# Agent Team ワークフローガイド

Claude Code本体がAgent Team APIを操作する2フェーズ方式のワークフロー。**Phase 1（計画策定）はplanner タチコマに委譲し、Phase 2（実装）でimplementer タチコマを並列起動**します。

---

## Phase 1: 計画策定

### Step 1: TeamCreate（即座に実行）

**🔴 Claude Code本体はファイルを読まない・コードベースを分析しない。**

ユーザー要求を受け取ったら、要求内容から `team_name` を決定して即座に TeamCreate を呼び出す:

```json
{
  "team_name": "user-management",
  "description": "ユーザー管理機能の開発"
}
```

**注意:**
- セッションあたり1チームのみ作成可能
- `team_name` は `docs/plan-{feature-name}.md` の `{feature-name}` と一致させる

---

### Step 2: planner タチコマ起動（現状把握・計画策定を全委譲）

**Claude Code本体はファイル読み込み・コードベース分析・要件整理を一切行わず、ユーザー要求をそのまま planner タチコマに渡す。** 現状把握から計画策定まで全てplannerの責務。

planner タチコマの起動:

```json
{
  "description": "計画策定",
  "prompt": "## タスク: 実装計画の策定\n\n**ユーザー要求:** {ユーザーの要求をそのまま記載}\n\n以下を実行してください:\n1. コードベースを分析し、変更対象ファイル・影響範囲を特定\n2. TEAM-PATTERNS.md を参照し、最適なチーム編成パターンを選択\n3. タスク分解（1メンバーあたり5-6タスク目標）\n4. ファイル所有権パターンを定義（同一ファイル同時書込禁止）\n5. docs/plan-{feature-name}.md を PLAN-TEMPLATE.md の形式で作成\n\n参照スキル: orchestrating-teams（references/TEAM-PATTERNS.md, references/PLAN-TEMPLATE.md）\n\n禁止事項:\n- 実装コードの変更（計画策定のみ）\n- jj書込操作",
  "subagent_type": "sumik:タチコマ",
  "model": "opus",
  "team_name": "user-management",
  "name": "planner",
  "run_in_background": true,
  "mode": "bypassPermissions"
}
```

**planner タチコマの責務（現状把握から計画策定まで全て）:**
1. **現状把握**: コードベースの読み込み・プロジェクト構造の理解・既存実装の分析
2. **要件分析**: ユーザー要求の詳細化・変更対象ファイル・影響範囲の特定
3. **並列化判定**: 独立サブタスクに分解可能か、ファイル競合リスクはあるか
4. **チーム編成設計**: `references/TEAM-PATTERNS.md` から最適なパターンを選択
5. **モデル戦略選択**: デフォルト Adaptive（planner=Opus, implementer=Sonnet）
6. **タスク分解**: 1メンバーあたり5-6タスク目標、依存関係の明示
7. **ファイル所有権パターン定義**: 同一ファイル同時書込を防ぐパス別所有権
8. **計画書作成**: `docs/plan-{feature-name}.md` を `references/PLAN-TEMPLATE.md` 形式で作成

**planner タチコマは実装コードを変更しない（読み取り専用 + docs/ への計画書作成のみ）。**

---

### Step 3: 計画レビュー・承認

planner タチコマが `docs/plan-{feature-name}.md` を作成したら、Claude Code本体がレビュー:

1. `docs/plan-{feature-name}.md` の内容を確認
2. AskUserQuestion でユーザー確認を取得:

```python
AskUserQuestion(
    questions=[{
        "question": "以下の計画で進めてよろしいですか？",
        "header": "Agent Team 実行計画",
        "options": [
            {"label": "承認", "description": "計画通りに進める"},
            {"label": "修正", "description": "計画を見直す"}
        ]
    }]
)
```

修正が必要な場合は、planner タチコマに SendMessage でフィードバックを送信。

---

## Phase 2: 実装

### Step 4: TaskCreate でタスク一覧作成

**planner が作成した `docs/plan-*.md` のタスクリストに基づいて作成**

```json
{
  "subject": "ユーザーモデルのスキーマ設計",
  "description": "PostgreSQLテーブル定義・マイグレーションスクリプト作成。src/models/user.ts と migrations/ 配下を編集。",
  "activeForm": "スキーマ設計中"
}
```

### フィールド説明

| フィールド | 必須 | 説明 |
|-----------|------|------|
| `subject` | ✅ | タスクの短いタイトル（50文字以内） |
| `description` | ✅ | 詳細な説明（対象ファイル・具体的な実装内容） |
| `activeForm` | ✅ | 進捗表示用のステータス（「〜中」形式） |

### 依存関係の設定（TaskUpdate）

タスク間に依存関係がある場合、**TaskUpdate tool の `addBlockedBy`** で設定:

```json
{
  "taskId": "2",
  "addBlockedBy": ["1"]
}
```

これにより、タスク1が完了するまでタスク2はブロックされます。

---

### Step 5: implementer タチコマ並列起動（Task tool）

### 🔴 重要: 必ずTask toolを使用（Bash経由禁止）

**Claude Code本体が Task tool を直接呼び出し、planner の計画に基づいてimplementer タチコマを並列起動します。**

### 5.1 Task tool パラメータ

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| `description` | ✅ | 3-5語の短い説明（例: "フロントエンド実装"） |
| `prompt` | ✅ | タスクの詳細指示（Spawn Prompt全文を含める） |
| `subagent_type` | ✅ | `"sumik:タチコマ"`（実装ワーカー）推奨 |
| `team_name` | 任意 | チーム名（TeamCreateで作成した名前） |
| `name` | 任意 | メンバー名（例: "frontend", "backend"） |
| `run_in_background` | ✅ | `true` で並列実行（**必須**） |
| `mode` | 任意 | `"bypassPermissions"` で権限確認をスキップ |

### 5.2 並列起動例（3メンバー）

**1つのメッセージ内で複数のTask tool呼び出しを並列実行:**

```json
// メンバー1: frontend
{
  "description": "フロントエンド実装",
  "prompt": "## タスク: Reactコンポーネント実装\n\n担当タスク: #4, #5, #6\nファイル所有権: src/components/**, src/pages/**\n参照スキル: developing-nextjs\n\n具体的な実装指示:\n- ユーザー一覧コンポーネント（データテーブル、ページネーション）\n- ユーザー編集フォーム（バリデーション、API連携）\n- エラー表示・ローディング状態\n\n禁止事項:\n- 所有権範囲外のファイルを編集しない\n- 他メンバーのタスクに介入しない\n- jj書込操作（commit等）を実行しない",
  "subagent_type": "sumik:タチコマ",
  "team_name": "user-management",
  "name": "frontend",
  "run_in_background": true,
  "mode": "bypassPermissions"
}

// メンバー2: backend（同じメッセージ内で並列呼び出し）
{
  "description": "バックエンドAPI実装",
  "prompt": "## タスク: REST API CRUD実装\n\n担当タスク: #1, #2, #3\nファイル所有権: src/api/**, src/services/**, src/models/**\n参照スキル: developing-fullstack-javascript\n\n具体的な実装指示:\n- PostgreSQLスキーマ設計・マイグレーション\n- GET/POST/PUT/DELETE エンドポイント実装\n- バリデーション、エラーハンドリング\n- 認可チェック\n\n禁止事項:\n- 所有権範囲外のファイルを編集しない\n- 他メンバーのタスクに介入しない\n- jj書込操作を実行しない",
  "subagent_type": "sumik:タチコマ",
  "team_name": "user-management",
  "name": "backend",
  "run_in_background": true,
  "mode": "bypassPermissions"
}

// メンバー3: tester（同じメッセージ内で並列呼び出し）
{
  "description": "E2Eテスト作成",
  "prompt": "## タスク: E2Eテストシナリオ作成\n\n担当タスク: #7, #8\nファイル所有権: tests/e2e/**\n参照スキル: testing-e2e-with-playwright\n\n具体的な実装指示:\n- Playwrightによるユーザー登録・編集・削除フロー検証\n- 各種エラーケースのテスト\n- アクセシビリティチェック\n\n禁止事項:\n- 所有権範囲外のファイルを編集しない\n- 他メンバーのタスクに介入しない\n- jj書込操作を実行しない",
  "subagent_type": "sumik:タチコマ",
  "team_name": "user-management",
  "name": "tester",
  "run_in_background": true,
  "mode": "bypassPermissions"
}
```

### 5.3 Spawn Prompt テンプレート

**`prompt` パラメータに記述する内容:**

```markdown
## タスク: {task_title}

**担当タスク:** {task_ids}
**ファイル所有権:** {file_ownership_pattern}
**参照スキル:** {relevant_skills}
**依存関係:** {blocking_tasks}

具体的な実装指示:
- [詳細な指示1]
- [詳細な指示2]
- [詳細な指示3]

禁止事項:
- 所有権範囲外のファイルを編集しない
- 他メンバーのタスクに介入しない
- jj書込操作（jj new, jj commit, jj describe, jj push）を実行しない
```

---

## Step 6: 進捗管理（planner シャットダウン → implementer 監視）

**Step 5 で implementer タチコマを起動したら、不要になった planner タチコマをシャットダウンしてリソースを解放する。**

### 6.1 TaskList で進捗確認

定期的に TaskList を呼び出して進捗を確認:

```json
TaskList()
```

出力例:
```json
[
  {"id": "1", "subject": "スキーマ設計", "status": "completed"},
  {"id": "2", "subject": "API実装", "status": "in_progress"},
  {"id": "3", "subject": "バリデーション", "status": "not_started", "blockedBy": ["2"]}
]
```

### 6.2 SendMessage でメンバー間調整

**type: "message"（特定メンバーに送信）:**

```json
{
  "type": "message",
  "recipient": "frontend",
  "content": "backend のタスク2が完了しました。API エンドポイントは /api/users です。POST時のリクエストボディは { name: string, email: string } です。",
  "summary": "API エンドポイント情報共有"
}
```

**type: "broadcast"（全メンバーに送信、⚠️コスト高）:**

```json
{
  "type": "broadcast",
  "content": "全員: 統合テストフェーズに移行します。各自の担当タスクが完了していることを確認してください。",
  "summary": "統合テストフェーズ移行"
}
```

### 6.3 docs/plan-*.md のタスクリスト更新

メンバーからの完了報告を受けたら、計画ドキュメントのタスクリストを更新:

```markdown
- [x] タスク1: ユーザーモデルのスキーマ設計（担当: backend）
- [x] タスク2: REST API CRUD エンドポイント実装（担当: backend）
- [ ] タスク3: バリデーション・エラーハンドリング（担当: backend、依存: タスク2）
```

### 6.4 実行ログセクションに記録

```markdown
## 実行ログ

- [2026-02-18 10:00] チーム作成完了（team_name: user-management）
- [2026-02-18 10:05] frontend/backend/testerスポーン完了
- [2026-02-18 10:30] タスク1完了（backend: スキーマ設計）
- [2026-02-18 10:45] タスク4完了（frontend: 一覧コンポーネント）
- [2026-02-18 11:00] タスク2完了（backend: API実装）
```

---

## Step 7: 統合・完了

### 7.1 全タスク完了の確認

TaskList で全タスクが "completed" になったことを確認:

```json
TaskList()
```

### 7.2 各メンバーの成果物を統合

- ファイルの整合性確認
- 統合テストの実施
- コンフリクトの解消（必要な場合）

### 7.3 品質チェック

**CodeGuardセキュリティチェック実行（推奨）:**

```bash
/codeguard-security:software-security
```

### 7.4 docs/plan-*.md のタスクリストを全完了に更新

全タスクを `- [x]` に変更し、実行ログに完了時刻を記録:

```markdown
- [x] タスク1: ユーザーモデルのスキーマ設計（担当: backend）
- [x] タスク2: REST API CRUD エンドポイント実装（担当: backend）
- [x] タスク3: バリデーション・エラーハンドリング（担当: backend）
- [x] タスク4: ユーザー一覧コンポーネント実装（担当: frontend）
- [x] タスク5: ユーザー編集フォーム実装（担当: frontend）
- [x] タスク6: API連携・エラー表示（担当: frontend）
- [x] タスク7: E2Eテストシナリオ作成（担当: tester）
- [x] タスク8: エラーケーステスト（担当: tester）

## 実行ログ

- [2026-02-18 11:30] 全タスク完了
- [2026-02-18 11:35] 統合テスト完了
- [2026-02-18 11:40] CodeGuardセキュリティチェック完了
```

---

## Step 8: クリーンアップ

### 8.1 各メンバーをシャットダウン

**SendMessage で shutdown_request を送信:**

```json
{
  "type": "shutdown_request",
  "recipient": "frontend",
  "content": "全タスク完了、ご協力ありがとうございました"
}
```

各メンバー（frontend, backend, tester）に対して個別に送信。

### 8.2 全メンバーシャットダウン後にTeamDelete

**全メンバーがシャットダウンしたことを確認してから TeamDelete を実行:**

```json
TeamDelete()
```

---

## Agent Teams API 制限（重要）

### 制限事項
- **セッションあたり1チーム**
- **ネストされたチーム不可**（メンバーは独自チーム不可）
- **リーダー固定**（譲渡不可）
- **各メンバーは独自コンテキスト**（リーダーの会話履歴は継承しない）

### アイドル状態
- チームメンバーはターンごとにアイドルになる（**正常動作**）
- アイドル = 入力待ち状態であり、メッセージ送信で即座に復帰
- アイドル通知は自動送信されるため、エラーとして扱わない

### タスク自動取得（Self-claiming）
- チームメンバーがタスクを完了すると、次の未割り当て・ブロック解除済みタスクを自動的に取得可能
- タスク取得はファイルロックで競合を防止
- **各メンバーに5-6タスクを用意すれば、自動取得で効率的に作業が進む**
