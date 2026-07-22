# Agent Team オーケストレーション

**Claude Code本体はファイル読み込みや分析を一切行わない。最初に `HERDR_ENV` を判定し、herdr 管理下では `operating-herdr`、herdr 外では Agent Teams API を使って、planner（`devkit:tachikoma-str-product-mgr`）へ即座に委譲する。**

---

## 概要

### このスキル方式（2フェーズ・実行バックエンド分岐）
```
Claude Code（このスキルをロード）
    ├─ 実行バックエンド判定
    │    ├─ HERDR_ENV=1: operating-herdr + herdr pane split → agent start/read/prompt/wait --until
    │    └─ HERDR_ENV!=1: Agent / TaskCreate / SendMessage / TaskList
    ├─ Phase 1: planner → 要件分析・コードベース分析・docs/plan作成
    ├─ 計画レビュー・承認（ユーザー確認）
    └─ Phase 2: ドメイン別専門タチコマを選択したバックエンドで並列実行
                 → 進捗管理 → 統合 → ペイン/メンバーのクリーンアップ
```

**Claude Code本体は最小限の判断（並列化の要否）のみ行い、計画策定から実装までAgentに委譲します。**

---

## 🔴 Step 0: 実行バックエンド判定

最初に `HERDR_ENV` を確認し、1つのタスク中にバックエンドを混在させない。

```bash
if [ "${HERDR_ENV:-}" = "1" ]; then
  echo herdr
else
  echo agent-teams
fi
```

### `HERDR_ENV=1`: herdr バックエンド

- `operating-herdr` をロードし、`HERDR_WORKSPACE_ID` / `HERDR_TAB_ID` / `HERDR_PANE_ID` を確認する
- Claude Code の `teammateMode` は `in-process` にする。`tmux` / `iterm2` / `auto` の split-pane を使わない
- planner と implementer は `herdr pane split --current --direction right|down --no-focus` でpaneを確保してから `herdr agent start --kind claude --pane <id> -- --permission-mode auto ...` で起動する（`--kind` が起動する実行ファイルを決定し、`--` 以降には実行ファイル名を書かずその追加引数のみを書く。0.7.5でpane確保とエージェント起動が別コマンドに分離）
- 🔴 **起動前に、ユーザーが実行時のランタイムを限定していないか確認する**（例:「Claudeは使えない。Codexだけで行う」等の明示的な指定）。このスキル内の既定例（`--kind claude`）はあくまでデフォルトであり、ユーザーがランタイムを限定している場合はそれに従い `herdr agent start --kind codex --pane <id> -- ...` のみを使う
- 既にユーザーの制約に反するランタイムでペインを起動してしまっていた場合は直ちにそのペインを閉じ、以後の作業対象（planner/implementerの一員）に含めない
- 一般原則として、スキル内の既定例よりユーザーが指定した実行環境の制約（ランタイム指定）が常に優先される
- `docs/plan-*.md` をタスク・依存関係・実行ログの正本とし、更新はリーダーに集約する
- `herdr agent list/read/prompt/wait --until` で進捗を管理する
- `TaskCreate` / `TaskList` / `SendMessage` の状態は、別ペインの独立Claude CLIセッションと共有されない

### `HERDR_ENV!=1`: Agent Teams バックエンド

- herdr CLI でペインを操作・検査しない
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` を有効化する
- Agent（`run_in_background: true`）/ TaskCreate / TaskList / SendMessage を使う
- ペイン表示の有無は Claude Code の設定に従う。このスキルから iTerm2 / tmux を直接操作しない

## Agent Teams バックエンド: 遅延ツールのロード

**この節は `HERDR_ENV!=1` の場合だけ実行する。** SendMessage / Task 系ツール（TaskCreate, TaskUpdate, TaskList）は「遅延ツール（deferred tools）」であり、ToolSearch で事前にロードしないと呼び出せない。Agent ツール自体は遅延ツールではなく最初から使用可能。

SendMessage / Task 系を使用する直前に以下を実行:

```
ToolSearch("TaskCreate task")       → TaskCreate, TaskUpdate, TaskList がロードされる
ToolSearch("SendMessage message")   → SendMessage がロードされる
```

**⚠️ これを省略すると TaskCreate / SendMessage が呼び出せない。TeamCreate/TeamDelete は v2.1.178 で廃止済み（ToolSearch しても "No matching deferred tools found" となる）。**

---

## 使用タイミング

並列化の判断基準・単体起動条件は `references/PARALLEL-DECISION-CRITERIA.md` を参照。

**このスキル固有の起動アクション:** 条件に該当したら、herdrでは `herdr agent start`、非herdrではAgentツールを使い、planner（`devkit:tachikoma-str-product-mgr`, model: opus）を起動する。

---

## クイックスタート（2フェーズ方式）

### Phase 1: 計画策定（planner タチコマに全委譲）
1. **planner タチコマ起動** - herdr では `herdr agent start`、非herdrでは Agent ツール（model: opus, run_in_background: true）を使う。ユーザー要求をそのまま渡し、現状把握・コードベース分析・要件整理・チーム編成設計・`docs/plan-{feature}.md` 作成・**Codex プランレビューループ**を全てplannerが実行
2. **計画レビュー・承認** - plannerがCodexレビュー済みのdocs/planをユーザーに提示して確認

### Phase 2: 実装（implementer タチコマ並列起動）
3. **implementer タチコマ並列起動** - herdr では同一Waveの全員を `herdr agent start` で待たずに起動し、非herdrでは TaskCreate + Agent ツール（`run_in_background: true`）を使う
4. **進捗管理 → 統合 → クリーンアップ** - herdr では agent read/wait と pane close、非herdrでは SendMessage / TaskList / shutdown_request を使う

**🔴 Claude Code本体はファイルを読まない・分析しない。** ユーザー要求を受け取ったら、選択済みバックエンドでplannerを起動する。現状把握から計画策定まで全てplannerの責務。

---

## ファイル所有権・タスク分解

ファイル所有権パターンと依存関係に基づくグループ化の共通基準は `references/PARALLEL-DECISION-CRITERIA.md` を参照。

**このスキル固有の補足:**
- 1メンバーあたり **5–6タスクが実証済みの最適値**（8+でオーバーヘッド増、1–2で待機時間増）
- TaskUpdate の `blockedBy` フィールドで前提タスクを明示する
  ```json
  {"taskId": "3", "addBlockedBy": ["1"]}
  ```

---

## Git連携注意事項

### git操作の原則
- **Git を使用**
- **git読み取り操作のみ許可**: `git status`, `git diff`, `git log`, `git branch -a`
- **git書込操作はリーダー（Claude Code本体）のみ**: `git commit`, `git push` はユーザー確認必須

### チーム作業時の注意
- **各メンバーの変更は同一ブランチに統合される**
- **コンフリクトを避けるため、ファイル所有権パターンを厳守**
- 作業完了後、`git status` で全変更を確認してからコミット判断をユーザーに委ねる

---

## 🔴 絶対に避けるべきこと

- **herdr 環境で Claude Code の `--tmux`、iTerm2、素のtmuxを使ってペインを作らない**
- **herdr 環境で Agent Teams API と独立herdrエージェントの管理状態を混在させない**
- **非herdr環境で Bash toolからメンバーを起動しない**（`--team` 等のCLIオプションは存在しない）
- **非herdr環境で `run_in_background: true` を省略しない**（省略すると前景で逐次実行になる。`team_name` は無視されるため不要）
- **herdr環境で `herdr agent start` 以外のCLI経路からエージェントを起動しない**
- **Task toolに存在しないパラメータを使用しない**（`task`, `additional_instructions` は無効）
- **同一ファイルへの同時書き込み**（サイレントな上書きが発生）
- **`docs/plan-*.md` なしでチーム作成しない**（回復不能になる）
- **汎用タチコマ（`devkit:tachikoma`）を安易に使わない** → `rules/skill-triggers.md` のルーティング表から適切な専門タチコマを選択

---

## サブファイルナビゲーション

詳細な手順やパターンは以下のリファレンスファイルを参照してください:

| ファイル | 内容 |
|---------|------|
| `references/PARALLEL-DECISION-CRITERIA.md` | **共有正本**: 並列化判断基準・ファイル所有権パターン・依存関係グループ化（orchestrating-codexと共有） |
| `references/TEAM-PATTERNS.md` | チーム編成パターン（4種）・モデル戦略（4種）・既存Agent/スキル統合 |
| `references/WORKFLOW-GUIDE.md` | Step 1-8 詳細ワークフロー（要件分析 → チーム作成 → スポーン → 進捗管理 → 統合 → クリーンアップ） |
| `references/PLAN-TEMPLATE.md` | `docs/plan-{feature-name}.md` テンプレート・回復手順・実行ログ記録方法 |

---

## 関連スキル

- `operating-herdr` - `HERDR_ENV=1` でのworkspace/tab/pane・agent操作（必須）
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
