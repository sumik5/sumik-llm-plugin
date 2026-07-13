# herdr 操作ガイド

## 🔴 前提チェック

**使用前に `HERDR_ENV` 環境変数を確認する。**

```bash
echo $HERDR_ENV
```

値が `1` でなければ「herdr 管理下のペインで動作していない」と述べて停止する。herdr の外部から focused な herdr ペインを操作・検査してはならない。

---

## herdr とは

herdr は terminal-native agent multiplexer（ターミナルネイティブのエージェント多重化ツール）。tmux 系譜だが AI エージェントの spawn・監視・協調に特化している。

herdr は workspace・tab・pane という3層構造を提供し、各 pane は独立したシェル・エージェント・サーバー・ログストリームとして動作する。herdr CLI は local unix socket を通じて実行中の herdr インスタンスと通信する。

**これにより以下が可能になる:**
- 他の pane やエージェントの動作状況を把握する
- workspace 内に tab を作成してサブコンテキストを分離する
- pane を分割・移動・リサイズしてコマンドを実行する
- sibling pane でサーバー起動・ログ監視・テスト実行を行う
- 特定の出力が現れるまで待機してから処理を続ける
- 別エージェントの完了を待機する
- `herdr agent start` でエージェントインスタンスを spawn し協調する

**iTerm2 / tmux との関係（重要）**: herdr は iTerm2 や tmux を制御しない。独自の Unix socket と PTY で workspace/tab/pane を多重化する自前のマルチプレクサであり、tmux の代替として機能する。したがって Claude Code の並列タチコマ（teammate）を別ペインに出す `teammateMode` の split-pane（`tmux` / `iterm2` / `auto`）は herdr のペイン管理と競合して spawn 失敗する。herdr 環境では Claude Code の `teammateMode` を `in-process` にし、複数エージェントを別ペインに出したいときは Claude Code の teammate ではなく herdr ネイティブの `herdr agent start`（下記）または `herdr pane split` を使う。

`herdr` バイナリは PATH に存在する。socket API の詳細は https://herdr.dev/docs/socket-api/ 、agent 検出・spawn の詳細は https://herdr.dev/docs/agents/ を参照。

---

## concepts（基本概念）

**workspaces** はプロジェクトコンテキスト。各 workspace は1つ以上の tab を持つ。手動でリネームしない限り、workspace のラベルは最初の tab のルート pane に従う（通常はリポジトリ名、なければルート pane のカレントフォルダ名）。

**tabs** は workspace 内のサブコンテキスト。各 tab は1つ以上の pane を持つ。

**panes** は tab 内のターミナル分割領域。各 pane は独自のプロセス（シェル・エージェント・サーバー・任意のプロセス）を実行する。

**agent_status** は herdr が自動検出する。API は以下のフィールドを公開する:
- `agent_status` — `idle` / `working` / `blocked` / `done` / `unknown`

`done` はエージェントが完了したが、その完了済み pane をまだ確認していない状態を意味する。シェルも pane として存在するが、herdr のサイドバーはシェル全件ではなく検出されたエージェントに意図的に絞って表示する。

**ids** — workspace id は `w1`・`w2` のような形式。tab id は `w1:t1`・`w1:t2`・`w2:t1` のような形式。pane id は `w1:p1`・`w1:p5`・`w2:p2` のような形式。これらは現在のライブセッションに対するコンパクトな公開 ID。

> **⚠️ 注意**: tab・pane・workspace が閉じられると id が詰まる（compact）場合がある。id を永続的な識別子として扱わないこと。現在の id が必要な場合は `workspace list`・`tab list`・`pane list`・`agent list` あるいは create/split/start レスポンスから再読みすること。以前の `w1:p5` が後で同じ pane を指しているとは限らない。

**herdr が注入する環境変数**: herdr 管理下の pane では `HERDR_ENV=1`・`HERDR_SOCKET_PATH`・`HERDR_WORKSPACE_ID`・`HERDR_TAB_ID`・`HERDR_PANE_ID` が設定される。

---

## 自己発見（discover yourself）

存在する pane と focused な pane を確認する:

```bash
herdr pane list
```

focused な pane が自分自身。その他の pane が neighbor（隣接 pane）。自身の pane id は `herdr pane current --current` でも取得できる。workspace 一覧は `herdr workspace list`、検出済みエージェント一覧は `herdr agent list`。

---

## tab 管理

```bash
herdr tab list --workspace w1                # 現在の workspace 内の tab を一覧
herdr tab create --workspace w1              # 新規 tab（--label なしは番号付き命名を維持）
herdr tab create --workspace w1 --label "logs"   # 名前付きで作成
herdr tab rename w1:t2 "logs"                # リネーム
herdr tab focus w1:t2                        # フォーカス
herdr tab close w1:t2                        # 閉じる
```

---

## workspace 管理

```bash
herdr workspace create --cwd /path/to/project              # 新規 workspace（--label なしは cwd ベース命名）
herdr workspace create --cwd /path/to/project --label "api server"   # 名前付き
herdr workspace create --no-focus                          # フォーカスせず作成
herdr workspace focus w2                                   # フォーカス
herdr workspace rename w1 "api server"                     # リネーム
herdr workspace close w2                                   # 閉じる
```

---

## pane 名前空間

### 別の pane の出力を読み取る

```bash
herdr pane read w1:p1 --source recent --lines 50
```

`--source` オプション:
- `--source visible` — 現在のビューポートを取得する
- `--source recent` — pane 内でレンダリングされた最近のスクロールバックを取得する
- `--source recent-unwrapped` — ソフトラップを結合してまとめた最近のターミナルテキストを取得する

> **補足**: `pane read` はテキストを返す（JSON ではない）。`--format ansi` または `--ansi` フラグを付けると TUI フィードバックループ向けにレンダリング済みの ANSI スナップショットを返す。

### pane ナビゲーション（レイアウト把握）

```bash
herdr pane current --current                          # 現在の pane 情報
herdr pane get w1:p5                                  # 特定 pane の情報
herdr pane layout --current                           # レイアウト構造
herdr pane process-info --current                     # 実行中プロセス情報
herdr pane edges --current                            # pane の境界情報
herdr pane neighbor --direction left --current        # 指定方向の隣接 pane を取得
herdr pane focus --direction right --current          # 指定方向の pane へフォーカス移動
```

### pane を分割してコマンドを実行する

pane を右に分割し、現在の pane にフォーカスを保つ:

```bash
herdr pane split w1:p2 --direction right --no-focus
```

このコマンドは新しい pane の情報を JSON で出力し、新 pane の id は `result.pane.pane_id` にある。その値を parse してコマンドを実行する:

```bash
NEW_PANE=$(herdr pane split w1:p2 --direction right --no-focus | python3 -c 'import sys,json; print(json.load(sys.stdin)["result"]["pane"]["pane_id"])')
herdr pane run "$NEW_PANE" "npm run dev"
```

`--ratio FLOAT` で分割比、`--cwd PATH` で起動ディレクトリ、`--env KEY=VALUE` で環境変数を指定できる。下方向は `--direction down`。

> **使い分け**: `pane split` + `pane run` は素のシェル・サーバー・テスト・ビルドなど「任意のプロセス」を起動する用途に使う。エージェントを spawn する場合は下記の `herdr agent start` を使う（検出とステータス追跡が自動で有効になる）。

### pane のサイズ・ズーム・入れ替え・移動

```bash
herdr pane resize --direction right --amount 0.1 --current       # サイズ変更
herdr pane zoom --current --toggle                               # ズームのトグル（--on / --off も可）
herdr pane rename w1:p5 "server"                                 # ラベル付与（--clear で解除）
herdr pane swap --direction left --current                       # 方向指定で隣接 pane と入れ替え
herdr pane swap --source-pane w1:p1 --target-pane w1:p2          # id 指定で入れ替え
herdr pane move w1:p5 --tab w1:t2 --split right --focus          # 別 tab へ移動
herdr pane move w1:p5 --new-tab --label "logs"                   # 新 tab へ切り出し
herdr pane move w1:p5 --new-workspace --label "api"              # 新 workspace へ切り出し
```

### テキスト・キーを pane に送信する

```bash
herdr pane send-text w1:p1 "hello from claude"    # Enter なしでテキスト送信
herdr pane send-keys w1:p1 Enter                  # Enter やその他のキーを送信
herdr pane run w1:p1 "echo hello"                 # テキスト送信 + Enter を1リクエストで実行
```

### エージェントステータスの手動報告（report-agent）

lifecycle hook を持たない外部プロセスのステータスを手動で herdr に通知する場合に使う:

```bash
herdr pane report-agent w1:p5 --source my-runner --agent worker --state working --message "building"
```

### pane を閉じる

```bash
herdr pane close w1:p3
```

---

## herdr agent 名前空間（エージェント spawn・協調）

`herdr agent` はエージェントインスタンスの起動・観測・協調に特化した名前空間。**エージェントを扱うときは pane 系より agent 系を優先する**（検出・ステータス追跡が組み込まれる）。

`<target>` は terminal id / 一意な agent 名 / 検出・報告された agent ラベル / legacy pane id を受け付ける。

```bash
herdr agent list                                   # 検出済みエージェント一覧
herdr agent get reviewer                           # 特定エージェントの情報
herdr agent explain reviewer --json                # 検出根拠・状態の説明（デバッグ用）
herdr agent focus reviewer                          # フォーカス
herdr agent rename reviewer "review-api"            # リネーム（--clear で解除）
```

### エージェントを spawn する（agent start）

`-- ` の後に起動するエージェントのコマンド（argv）を書く:

```bash
herdr agent start reviewer --cwd ~/project --split right -- pi
herdr agent start docs --workspace w1 --tab w1:t1 -- claude
```

主なオプション: `--cwd PATH`（起動ディレクトリ）・`--workspace ID` / `--tab ID`（配置先）・`--split right|down`（分割方向）・`--env KEY=VALUE`・`--focus` / `--no-focus`。

`agent start` の応答では、新しいpane IDは `result.agent.pane_id` にある。`pane split` の `result.pane.pane_id` とは階層が異なる。

```bash
START_JSON=$(herdr agent start reviewer --cwd ~/project --split right --no-focus -- claude)
AGENT_PANE=$(printf '%s' "$START_JSON" | python3 -c \
  'import json,sys; print(json.load(sys.stdin)["result"]["agent"]["pane_id"])')
```

### エージェントの出力を読む・指示を送る

```bash
herdr agent read reviewer --source recent --lines 80          # 出力を読む（pane read と同じ --source）
herdr agent send reviewer "review the test coverage in src/api/"   # リテラルテキストを書く
```

> **`agent send` と `pane run` の違い**: `agent send` はリテラルテキストを書き込むだけ（Enter を送らない）。対話型エージェントへ書いた指示を確定するには `herdr pane send-keys <pane_id> Enter` を続ける。シェルコマンドをテキスト入力とEnterの1リクエストで実行する場合は `herdr pane run <pane_id> <command>` を使う。

### エージェントのステータスを待機する

```bash
herdr agent wait reviewer --status idle --timeout 120000
```

`--status` は `idle` / `working` / `blocked` / `unknown`。

### エージェントに直接アタッチする

```bash
herdr agent attach reviewer            # 直接アタッチ
herdr agent attach reviewer --takeover # 入力が競合する場合に強制的に主導権を取る
```

detach は `ctrl+b q`。

---

## herdr integration（統合フックの導入）

エージェントを install すると lifecycle hook が導入され、その agent の `idle` / `working` / `blocked` とセッションの同一性を authoritative（権威ある情報源）として報告するようになる。これは画面バッファのスナップショット（screen-manifest）ベースの検出より優先され、ステータス追跡が正確になる。対応エージェントには Claude Code・Codex を含む多数がある。

```bash
herdr integration install claude              # Claude Code の統合フックを導入
herdr integration install codex               # Codex の統合フックを導入
herdr integration status                      # 導入状況を確認
herdr integration status --outdated-only      # 更新が必要なものだけ表示
herdr integration uninstall claude            # 統合を解除
```

> **推奨**: herdr 上で Claude Code / Codex エージェントを協調させる前に該当エージェントの統合を install しておくと、`agent wait` / `agent-status` の判定が screen-manifest フォールバックより信頼できる。

---

## 出力を待機する（wait output）

pane に特定のテキストが現れるまでブロックする。サーバー・ビルド・テストの完了待ちに有用。

`--source recent` でのマッチングはソフトラップを除去した最近のターミナルテキストを使用するため、pane 幅やソフトラップによってマッチが壊れない。wait で使ったのと同じトランスクリプトを検査したい場合は `pane read --source recent-unwrapped` を使う。

```bash
herdr wait output w1:p3 --match "ready on port 3000" --timeout 30000
herdr wait output w1:p3 --match "server.*ready" --regex --timeout 30000
```

`--lines N` で走査範囲、`--raw` で生テキストのマッチングを指定できる。タイムアウトした場合、exit code は `1` になる。

---

## エージェントのステータスを待機する（wait agent-status）

別エージェントが特定のステータスに達するまでブロックする:

```bash
herdr wait agent-status w1:p1 --status done --timeout 60000
```

`--status` は `idle` / `working` / `blocked` / `done` / `unknown`。UI に表示される `done` / `idle` の区別を同じ形で扱いたい場合に使用する。

---

## notification / session

```bash
herdr notification show "build done" --body "tests passed" --position top-right --sound done
herdr session list --json          # セッション一覧
herdr session attach <name>        # アタッチ
herdr session stop <name>          # 停止
herdr session delete <name>        # 削除
```

`--sound` は `none` / `done` / `request`。`--position` は `top-left` / `top-right` / `bottom-left` / `bottom-right`。

---

## recipes（実用パターン）

### サーバーを起動して準備完了まで待機する

```bash
NEW_PANE=$(herdr pane split w1:p2 --direction right --no-focus | python3 -c 'import sys,json; print(json.load(sys.stdin)["result"]["pane"]["pane_id"])')
herdr pane run "$NEW_PANE" "npm run dev"
herdr wait output "$NEW_PANE" --match "ready" --timeout 30000
herdr pane read "$NEW_PANE" --source recent --lines 20
```

### 別の pane でテストを実行して結果を確認する

```bash
NEW_PANE=$(herdr pane split w1:p2 --direction down --no-focus | python3 -c 'import sys,json; print(json.load(sys.stdin)["result"]["pane"]["pane_id"])')
herdr pane run "$NEW_PANE" "cargo test"
herdr wait output "$NEW_PANE" --match "test result" --timeout 60000
herdr pane read "$NEW_PANE" --source recent --lines 30
```

### 別エージェントの作業内容を確認する

```bash
herdr agent list
herdr agent read reviewer --source recent --lines 80
```

### 新規エージェントを spawn してタスクを与える

```bash
START_JSON=$(herdr agent start reviewer --cwd ~/project --split right --no-focus -- claude)
AGENT_PANE=$(printf '%s' "$START_JSON" | python3 -c \
  'import json,sys; print(json.load(sys.stdin)["result"]["agent"]["pane_id"])')
herdr agent wait reviewer --status idle --timeout 30000
herdr agent send reviewer "review the test coverage in src/api/"
herdr pane send-keys "$AGENT_PANE" Enter
```

### 別エージェントと協調する

```bash
herdr wait agent-status w1:p1 --status done --timeout 120000
herdr agent read w1:p1 --source recent --lines 100
```

### 別の pane を堅牢に監視する

```bash
herdr pane read w1:p3 --source recent --lines 40            # すでにある出力を検査
herdr wait output w1:p3 --match "ready" --timeout 30000     # 期待する出力だけ待機
herdr pane read w1:p3 --source recent-unwrapped --lines 40  # wait と同じトランスクリプトを検査
```

---

## notes（補足事項）

**agent 検出の仕組み**: herdr のエージェント検出には2系統ある。① **lifecycle hooks**（優先）— `herdr integration install` で導入され、idle/working/blocked とセッション同一性を authoritative に報告する。② **screen manifests**（フォールバック）— 画面下部バッファのスナップショットからエージェントを検出する。screen-manifest ベースのエージェントでは `blocked` 検出が意図的に厳格になる。ステータス追跡を正確にしたい場合は統合を install すること。

**JSON を返すコマンド**: `workspace list`・`workspace create`・`tab list`・`tab create`・`tab get`・`tab focus`・`tab rename`・`tab close`・`pane list`・`pane get`・`pane current`・`pane split`・`agent list`・`agent get`・`agent start`・`agent explain`（`--json`）・`wait output`・`wait agent-status` は成功時に JSON を出力する。

**テキストを返すコマンド**: `pane read`・`agent read` は JSON ではなくテキストを返す。

**成功時に何も出力しないコマンド**: `pane send-text`・`pane send-keys`・`pane run`・`agent send` は成功時に何も出力しない。

**新規 id の parse 方法**:
- `workspace create` のレスポンスは `result.workspace`・`result.tab`・`result.root_pane` を返す
- `tab create` のレスポンスは `result.tab`・`result.root_pane` を返す
- `pane split` の新 pane id は `result.pane.pane_id` にある
- `agent start` の新 pane id は `result.agent.pane_id` にある（`result.pane` ではない）

**`--no-focus` の効果**: `pane split`・`tab create`・`workspace create`・`agent start` に付けることで現在のターミナルコンテキストをフォーカスしたまま保つ。

**`--label` の効果**: `tab create` と `workspace create` に付けるとカスタム名が即座に適用される。付けない場合、`workspace create` は cwd ベースの命名を維持し、`tab create` は番号付き命名を維持する。

**`pane read` / `agent read` の使い分け**: すでに存在する出力の確認には `read` を使う。次に来ることを期待する出力の待機には `wait output` を使う。

**pane 系と agent 系の使い分け**: エージェントの spawn・観測・待機・指示は `herdr agent`（検出とステータス追跡が組み込まれる）を優先する。素のシェル・サーバー・テストなど任意のプロセスは `herdr pane split` + `herdr pane run` を使う。

**`HERDR_ENV` 変数**: herdr 管理下の pane で動作している場合、`HERDR_ENV` 環境変数は `1` に設定されている。
