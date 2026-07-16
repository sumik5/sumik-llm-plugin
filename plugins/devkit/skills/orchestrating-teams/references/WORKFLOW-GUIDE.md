# Agent Team / herdr ワークフローガイド

Claude Code本体が実行バックエンドを選び、2フェーズで進めるワークフロー。**Phase 1（計画策定）はplanner タチコマに委譲し、Phase 2（実装）でimplementer タチコマを並列起動**します。

## Step 0: 実行バックエンドを固定する

```bash
if [ "${HERDR_ENV:-}" = "1" ]; then
  echo herdr
else
  echo agent-teams
fi
```

| 条件 | 起動 | タスク正本 | 連絡・監視 | 終了 |
|------|------|-----------|-----------|------|
| `HERDR_ENV=1` | `herdr agent start` | `docs/plan-*.md` | `herdr agent read/send/wait` | `herdr pane close` |
| `HERDR_ENV!=1` | Agent tool | TaskCreate + `docs/plan-*.md` | TaskList / SendMessage | shutdown_request |

`HERDR_ENV=1` では `operating-herdr` をロードし、Claude Code の `teammateMode` を `in-process` にする。`--tmux`、iTerm2、素のtmuxによるペイン分割は使わない。独立したherdrエージェントは Agent Teams API のタスク・メッセージ状態を共有しないため、1タスク中に2つのバックエンドを混在させない。

---

## Phase 1: 計画策定

### Step 0.1: 遅延ツールのロード（Agent Teams バックエンドのみ）

**`HERDR_ENV!=1` の場合だけ実行する。** SendMessage / Task 系（TaskCreate, TaskUpdate, TaskList）は遅延ツール（deferred tools）。ToolSearch でロードしないと呼び出せない。Agent ツール自体は遅延ツールではなく最初から使用可能。TeamCreate/TeamDelete は v2.1.178 で廃止済み（ToolSearch しても "No matching deferred tools found" となる）。

各ツールを使用する直前に以下を実行:

```
ToolSearch("TaskCreate task")       → TaskCreate, TaskUpdate, TaskList がロード
ToolSearch("SendMessage message")   → SendMessage がロード
```

⚠️ **Task 系 / SendMessage の使用前にこの手順を省略しないこと。**

---

### Step 1: planner タチコマ起動（即座に実行）

**🔴 Claude Code本体はファイルを読まない・コードベースを分析しない。**

ユーザー要求を受け取ったら、選択したバックエンドで planner タチコマを起動する（TeamCreate は v2.1.178 で廃止済み・不要）。

---

### Step 2: planner タチコマ起動（現状把握・計画策定を全委譲）

**Claude Code本体はファイル読み込み・コードベース分析・要件整理を一切行わず、ユーザー要求をそのまま planner タチコマに渡す。** 現状把握から計画策定まで全てplannerの責務。

#### herdr バックエンド

`PLANNER_PROMPT` に下記Agent Teams版の `prompt` と同じ内容を入れ、herdrが注入したworkspace/tabへ起動する。`agent start` の応答で新しいペインIDは `result.agent.pane_id` にある。

```bash
PLANNER_START=$(herdr agent start feature-planner \
  --cwd "$PWD" \
  --workspace "$HERDR_WORKSPACE_ID" \
  --tab "$HERDR_TAB_ID" \
  --split right \
  --no-focus \
  -- claude \
  --agent devkit:tachikoma-str-product-mgr \
  --model opus \
  --permission-mode auto \
  --name feature-planner)

PLANNER_PANE=$(printf '%s' "$PLANNER_START" | python3 -c \
  'import json,sys; print(json.load(sys.stdin)["result"]["agent"]["pane_id"])')

herdr agent wait feature-planner --status idle --timeout 30000
herdr agent send feature-planner "$PLANNER_PROMPT"
herdr pane send-keys "$PLANNER_PANE" Enter
```

- agent名はライブセッション内で一意にする（例: `{feature}-planner`）
- `herdr integration status` で Claude 統合が current か確認する
- `herdr wait agent-status "$PLANNER_PANE" --status working --timeout 30000` で開始を確認してから、`herdr agent wait feature-planner --status idle --timeout 1800000` で完了を待つ。`working` を取り逃した場合は `agent get/read` で状態と出力を確認する
- 完了後は `herdr agent read feature-planner --source recent --lines 100` で結果を確認する
- workspace/tab/pane IDはcompactされ得るため、`docs/plan` に永続保存しない

#### Agent Teams バックエンド

Agent toolで planner タチコマを起動する:

```json
{
  "description": "計画策定",
  "prompt": "## タスク: 実装計画の策定\n\n**ユーザー要求:** {ユーザーの要求をそのまま記載}\n\n以下を実行してください:\n1. コードベースを分析し、変更対象ファイル・影響範囲を特定\n2. TEAM-PATTERNS.md を参照し、最適なチーム編成パターンを選択\n3. タスク分解（1メンバーあたり5-6タスク目標）\n4. ファイル所有権パターンを定義（同一ファイル同時書込禁止）\n5. docs/plan-{feature-name}.md を PLAN-TEMPLATE.md の形式で作成\n6. 各タスクに最適な専門タチコマのsubagent_typeを推奨\n（参照: rules/skill-triggers.md のルーティング表）\n7. 🔴 Codex プランレビューループ: 計画書作成後、完了報告前に必ず実行\n   a. `which codex` で存在確認（見つからない or エラー → スキップしてOK）\n   b. `using-codex` スキルを使って `{plan_file_fullpath}` を初回レビューする\n   c. 致命的な指摘があればプランを修正し、同スキルの `--resume` モードで再レビューする\n   d. 致命的な指摘がなくなるまで修正→再レビューを繰り返す\n   e. 本質的でないコメントは無視してOK\n\n参照スキル: orchestrating-teams（references/TEAM-PATTERNS.md, references/PLAN-TEMPLATE.md）, using-codex\n\n禁止事項:\n- 実装コードの変更（計画策定のみ）\n- git書込操作",
  "subagent_type": "devkit:tachikoma-str-product-mgr",
  "model": "opus",
  "name": "planner",
  "run_in_background": true,
  "mode": "bypassPermissions"
}
```

**planner タチコマの責務（現状把握から計画策定・Codexレビューまで全て）:**
1. **現状把握**: コードベースの読み込み・プロジェクト構造の理解・既存実装の分析
2. **要件分析**: ユーザー要求の詳細化・変更対象ファイル・影響範囲の特定
3. **並列化判定**: 独立サブタスクに分解可能か、ファイル競合リスクはあるか
4. **チーム編成設計**: `references/TEAM-PATTERNS.md` から最適なパターンを選択
5. **モデル戦略選択**: デフォルト Adaptive（planner=Opus, implementer=Sonnet）
6. **タスク分解**: 1メンバーあたり5-6タスク目標、依存関係の明示
7. **ファイル所有権パターン定義**: 同一ファイル同時書込を防ぐパス別所有権
8. **計画書作成**: `docs/plan-{feature-name}.md` を `references/PLAN-TEMPLATE.md` 形式で作成
9. **🔴 Codex プランレビューループ**: 計画書作成後、Codex CLI で致命的問題をレビュー。指摘があれば修正→再レビューを繰り返す（codex未インストール・エラー時はスキップ可）

**planner タチコマは実装コードを変更しない（読み取り専用 + docs/ への計画書作成のみ）。**

---

### Step 3: 計画レビュー・承認

planner タチコマが `docs/plan-{feature-name}.md` を作成し**Codexレビューループを完了**したら、Claude Code本体がレビュー:

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

修正が必要な場合はバックエンドごとにフィードバックする。

- herdr: `herdr agent send feature-planner "$FEEDBACK"` の後、`herdr pane send-keys "$PLANNER_PANE" Enter` で送信を確定する。`agent send` 単体はEnterを送らない
- Agent Teams: SendMessage でplannerへ送信する

---

## Phase 2: 実装

### Step 4: タスク一覧を準備する

#### herdr バックエンド

planner が作成した `docs/plan-*.md` をそのままタスク・依存関係の正本にする。TaskCreate / TaskUpdate は使わない。複数の独立Claude CLIセッションが同じ計画書を同時編集しないよう、チェックリストと実行ログの更新はリーダーが行う。

#### Agent Teams バックエンド

planner が作成した `docs/plan-*.md` のタスクリストに基づき、TaskCreateで作成する。

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

### Step 5: implementer タチコマ並列起動

#### herdr バックエンド

同一Waveの全メンバーを `herdr agent start` で起動し終えてから待機する。Claude Codeの `--tmux` やAgent toolのsplit-paneは使わない。🔴 **`--split` は常に現在フォーカス中のpaneを分割するため、全員を同じ `--split right` で起動すると親paneが繰り返し分割されレイアウトが乱れる**（詳細: `operating-herdr` スキルの「複数エージェントを整列よく起動する」）。1体目のみ親の右に分割し、2体目以降は直前に起動したメンバーを `agent focus` してから下に分割して縦一列に連鎖させる。以下はfrontend/backend/testerの3メンバー例で、他の役割構成でも一意なagent名・専用ファイル所有権・適切な `--agent` を指定して同様に連鎖起動する。

```bash
# 1体目（frontend）: 親の右に分割
FRONTEND_START=$(herdr agent start feature-frontend \
  --cwd "$PWD" \
  --workspace "$HERDR_WORKSPACE_ID" \
  --tab "$HERDR_TAB_ID" \
  --split right \
  --no-focus \
  -- claude \
  --agent devkit:tachikoma-fw-nextjs \
  --permission-mode auto \
  --name feature-frontend)

FRONTEND_PANE=$(printf '%s' "$FRONTEND_START" | python3 -c \
  'import json,sys; print(json.load(sys.stdin)["result"]["agent"]["pane_id"])')

# 2体目（backend）: 直前のメンバー（frontend）をfocusしてから下に分割
herdr agent focus feature-frontend
BACKEND_START=$(herdr agent start feature-backend \
  --cwd "$PWD" \
  --workspace "$HERDR_WORKSPACE_ID" \
  --tab "$HERDR_TAB_ID" \
  --split down \
  --no-focus \
  -- claude \
  --agent devkit:tachikoma-fw-fullstack-js \
  --permission-mode auto \
  --name feature-backend)

BACKEND_PANE=$(printf '%s' "$BACKEND_START" | python3 -c \
  'import json,sys; print(json.load(sys.stdin)["result"]["agent"]["pane_id"])')

# 3体目（tester）: 直前のメンバー（backend）をfocusしてから下に分割
herdr agent focus feature-backend
TESTER_START=$(herdr agent start feature-tester \
  --cwd "$PWD" \
  --workspace "$HERDR_WORKSPACE_ID" \
  --tab "$HERDR_TAB_ID" \
  --split down \
  --no-focus \
  -- claude \
  --agent devkit:tachikoma-qa-e2e-test \
  --permission-mode auto \
  --name feature-tester)

TESTER_PANE=$(printf '%s' "$TESTER_START" | python3 -c \
  'import json,sys; print(json.load(sys.stdin)["result"]["agent"]["pane_id"])')

# 全員起動後、親にフォーカスを戻す（親 | 右列の2カラム構成なので left で一発戻れる）
herdr pane focus --direction left --current

# 各メンバーの起動確認とプロンプト送信（frontendの例。backend/testerも同様に行う）
herdr agent wait feature-frontend --status idle --timeout 30000
herdr agent send feature-frontend "$FRONTEND_PROMPT"
herdr pane send-keys "$FRONTEND_PANE" Enter
```

起動後は各メンバーについて `herdr wait agent-status "$FRONTEND_PANE" --status working --timeout 30000` で開始を確認し、`herdr agent wait feature-frontend --status idle --timeout 1800000` でターン完了を待つ。`working` を取り逃した場合は `herdr agent get feature-frontend` と `herdr agent read feature-frontend --source recent --lines 100` で状態と出力を確認する。

#### Agent Teams バックエンド

**Claude Code本体が Agent tool を直接呼び出し、planner の計画に基づいてimplementer タチコマを並列起動する。Bash経由で起動しない。**

##### Agent tool パラメータ

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| `description` | ✅ | 3-5語の短い説明（例: "フロントエンド実装"） |
| `prompt` | ✅ | タスクの詳細指示（Spawn Prompt全文を含める） |
| `subagent_type` | ✅ | **ドメイン別専門タチコマ**を選択（`rules/skill-triggers.md` ルーティング表参照）。例: `"devkit:tachikoma-fw-nextjs"`, `"devkit:tachikoma-qa-e2e-test"` |
| `name` | 任意 | メンバー名（例: "frontend", "backend"） |
| `run_in_background` | ✅ | `true` で並列実行（**必須**）。`team_name` は不要。ペイン表示の有無はClaude Codeの設定に従う |
| `mode` | 任意 | `"bypassPermissions"` で権限確認をスキップ |

##### 並列起動例（3メンバー）

**1つのメッセージ内で複数のTask tool呼び出しを並列実行:**

```json
// メンバー1: frontend
{
  "description": "フロントエンド実装",
  "prompt": "## タスク: Reactコンポーネント実装\n\n担当タスク: #4, #5, #6\nファイル所有権: src/components/**, src/pages/**\n参照スキル: web:developing-nextjs\n\n具体的な実装指示:\n- ユーザー一覧コンポーネント（データテーブル、ページネーション）\n- ユーザー編集フォーム（バリデーション、API連携）\n- エラー表示・ローディング状態\n\n禁止事項:\n- 所有権範囲外のファイルを編集しない\n- 他メンバーのタスクに介入しない\n- git書込操作（commit等）を実行しない",
  "subagent_type": "devkit:tachikoma-fw-nextjs",
  "name": "frontend",
  "run_in_background": true,
  "mode": "bypassPermissions"
}

// メンバー2: backend（同じメッセージ内で並列呼び出し）
{
  "description": "バックエンドAPI実装",
  "prompt": "## タスク: REST API CRUD実装\n\n担当タスク: #1, #2, #3\nファイル所有権: src/api/**, src/services/**, src/models/**\n参照スキル: web:developing-fullstack-javascript\n\n具体的な実装指示:\n- PostgreSQLスキーマ設計・マイグレーション\n- GET/POST/PUT/DELETE エンドポイント実装\n- バリデーション、エラーハンドリング\n- 認可チェック\n\n禁止事項:\n- 所有権範囲外のファイルを編集しない\n- 他メンバーのタスクに介入しない\n- git書込操作を実行しない",
  "subagent_type": "devkit:tachikoma-fw-fullstack-js",
  "name": "backend",
  "run_in_background": true,
  "mode": "bypassPermissions"
}

// メンバー3: tester（同じメッセージ内で並列呼び出し）
{
  "description": "E2Eテスト作成",
  "prompt": "## タスク: E2Eテストシナリオ作成\n\n担当タスク: #7, #8\nファイル所有権: tests/e2e/**\n参照スキル: web:testing-e2e-with-playwright\n\n具体的な実装指示:\n- Playwrightによるユーザー登録・編集・削除フロー検証\n- 各種エラーケースのテスト\n- アクセシビリティチェック\n\n禁止事項:\n- 所有権範囲外のファイルを編集しない\n- 他メンバーのタスクに介入しない\n- git書込操作を実行しない",
  "subagent_type": "devkit:tachikoma-qa-e2e-test",
  "name": "tester",
  "run_in_background": true,
  "mode": "bypassPermissions"
}
```

#### 共通のSpawn Promptテンプレート

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
- git書込操作（git commit, git push）を実行しない

完了報告:
- 変更ファイル、検証結果、未解決事項をリーダーへ報告
- Agent Teamsバックエンドでは担当タスクのチェックリストを `- [x]` に更新
- herdrバックエンドでは `docs/plan` を編集せず、リーダーが報告を反映する
```

---

## Step 6: 進捗管理（planner シャットダウン → implementer 監視）

**Step 5 で implementer タチコマを起動したら、不要になった planner を閉じてリソースを解放する。** herdrではライブな `herdr agent list` からplannerのペインIDを再取得して `herdr pane close`、Agent Teamsではshutdown_requestを使う。

### 6.1 進捗確認

#### herdr バックエンド

```bash
herdr agent list
herdr agent read feature-frontend --source recent --lines 80
herdr agent wait feature-frontend --status idle --timeout 1800000
```

複数の対話型Claude agentの完了を待つときは、各agentに対して `herdr agent wait <name> --status idle` を使う。`done` はプロセス完了を表すため、ターン完了後も対話を継続するClaudeの待機条件には使わない。ペインIDは保存値を盲信せず、agent名と `herdr agent list` で現在値を照合する。

#### Agent Teams バックエンド

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

### 6.2 メンバー間調整

herdrでは `agent send` とEnterを組み合わせる。

```bash
herdr agent send feature-frontend "$MESSAGE"
herdr pane send-keys "$FRONTEND_PANE" Enter
```

Agent TeamsではSendMessageを使う。

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

**🔴 herdrではリーダーだけが `docs/plan-*.md` を更新する。** 独立セッションの同時編集を防ぐため、implementerは完了報告だけを返す。Agent Teamsでは各タチコマが担当タスクを `- [x]` に更新し、リーダーが確認する。

メンバーからの完了報告を受けたら、計画ドキュメントのタスクリストを更新:

```markdown
- [x] タスク1: ユーザーモデルのスキーマ設計（担当: backend）
- [x] タスク2: REST API CRUD エンドポイント実装（担当: backend）
- [ ] タスク3: バリデーション・エラーハンドリング（担当: backend、依存: タスク2）
```

### 6.4 実行ログセクションに記録

```markdown
## 実行ログ

- [2026-02-18 10:00] planner起動完了
- [2026-02-18 10:05] frontend/backend/testerスポーン完了
- [2026-02-18 10:30] タスク1完了（backend: スキーマ設計）
- [2026-02-18 10:45] タスク4完了（frontend: 一覧コンポーネント）
- [2026-02-18 11:00] タスク2完了（backend: API実装）
```

---

## Step 7: 統合・完了

### 7.1 全タスク完了の確認

herdrでは `herdr agent list` / `agent read` で全agentの完了と成果報告を確認し、`docs/plan-*.md` の全項目へ反映する。Agent TeamsではTaskListで全タスクが "completed" になったことを確認する。

```json
TaskList()
```

### 7.2 各メンバーの成果物を統合

- ファイルの整合性確認
- 統合テストの実施
- コンフリクトの解消（必要な場合）

### 7.3 品質チェック

**software-security セキュリティ確認（推奨）:**

```bash
software-security スキル
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
- [2026-02-18 11:40] software-security セキュリティ確認完了
```

---

## Step 8: クリーンアップ

### 8.1 herdr バックエンド

agent名から現在のペインIDを取り直し、成果物と出力を確認してから閉じる。

```bash
AGENT_INFO=$(herdr agent get feature-frontend)
CURRENT_PANE=$(printf '%s' "$AGENT_INFO" | python3 -c \
  'import json,sys; print(json.load(sys.stdin)["result"]["agent"]["pane_id"])')
herdr agent read feature-frontend --source recent --lines 100
herdr pane close "$CURRENT_PANE"
```

### 8.2 Agent Teams バックエンド

**SendMessage で shutdown_request を送信:**

```json
{
  "type": "shutdown_request",
  "recipient": "frontend",
  "content": "全タスク完了、ご協力ありがとうございました"
}
```

各メンバー（frontend, backend, tester）に対して個別に送信。

### 8.3 後始末（TeamDelete は不要）

**セッション終了で全メンバーは自動解散される（TeamDelete は v2.1.178 で廃止済み）。**
能動的に特定メンバーを閉じたい場合のみ、shutdown_request 後に `teammate_terminated` 通知を確認する。

---

## バックエンド別の制限（重要）

### herdr

- 別ペインのClaude CLIは独立セッションであり、TaskCreate / TaskList / SendMessageを共有しない
- タスク状態と依存関係は `docs/plan-*.md` に集約する
- pane/tab/workspace IDはclose後にcompactされ得る。操作直前にagent名から現在値を取得する
- `agent send` はEnterを送らない。送信確定には `pane send-keys <pane_id> Enter` が必要
- agent spawn・監視はagent系、サーバー・テスト・ログはpane系を使う

### Agent Teams API

#### 制限事項
- **ネストされたチーム不可**（メンバーは独自のサブエージェントチームを持てない）
- **リーダー固定**（譲渡不可）
- **各メンバーは独自コンテキスト**（リーダーの会話履歴は継承しない）

#### アイドル状態
- チームメンバーはターンごとにアイドルになる（**正常動作**）
- アイドル = 入力待ち状態であり、メッセージ送信で即座に復帰
- アイドル通知は自動送信されるため、エラーとして扱わない

#### タスク自動取得（Self-claiming）
- チームメンバーがタスクを完了すると、次の未割り当て・ブロック解除済みタスクを自動的に取得可能
- タスク取得はファイルロックで競合を防止
- **各メンバーに5-6タスクを用意すれば、自動取得で効率的に作業が進む**
