# herdr 操作ガイド

## 🔴 前提チェック

**使用前に `HERDR_ENV` 環境変数を確認する。**

```bash
echo $HERDR_ENV
```

値が `1` でなければ「herdr 管理下のペインで動作していない」と述べて停止する。herdr の外部から focused な herdr ペインを操作・検査してはならない。

---

## 🔴 Step 0: herdr 公式ドキュメント確認（毎回必須）

herdr は活発に開発が進む CLI であり、コマンド仕様・エージェント対応表・検知方式は変わりうる。herdr 関連の調査・トラブルシューティングを行う前に、必ず https://herdr.dev/docs/ を起点に WebFetch で最新仕様を確認すること。

**確認必須 URL**

| URL | 内容 |
|-----|------|
| https://herdr.dev/docs/ | トップ・目次 |
| https://herdr.dev/docs/agents/ | エージェント対応表（lifecycle hooks / screen-manifest の区分）・Local overrides の仕様 |
| https://herdr.dev/docs/troubleshooting/ | 既知の問題と対処 |
| https://herdr.dev/docs/socket-api/ | agent_status API・イベント購読方式 |

**確認タイミング**:
- herdr の新機能を使う判断をする前
- herdr の挙動が本スキルの記載と食い違う時
- 24時間以上前に確認した内容を前提にする時

**最終確認日: 2026-07-22**

**🔴 herdr 0.7.4→0.7.5（2026-07-21リリース）で `agent start`・`agent wait`・`agent send` の体系が破壊的に変わったことを実機の `--help` 出力で確認済み**: `agent start` は「pane生成+配置+起動」の1コマンドから「`herdr pane split` で pane を確保 → `herdr agent start --kind <kind> --pane <id>` で既存paneに起動」の2段階方式に変わり、`--cwd`/`--workspace`/`--tab`/`--split`/`--env`/`--focus`/`--no-focus` は `agent start` から消えて `pane split` 側に残った。`agent wait --status` は `agent wait --until`（`done` も指定可・複数指定可）に統合され、トップレベルの `herdr wait` 名前空間（`wait output`・`wait agent-status`）は廃止されて `pane wait-output`（`--match`/`--regex`のいずれか必須）に一本化された。`agent send` + `pane send-keys Enter` の2段階は `agent prompt`（`--wait --until <state>...` で待機も可）1コマンドに統合された。以下の本文は全てこの新体系（0.7.5）で記述している。

WebFetch の呼び出し例:

```
WebFetch(url: "https://herdr.dev/docs/agents/", prompt: "エージェントごとの検知方式（lifecycle hooks / screen manifest）の対応表と、Local overrides の仕様を確認してください。前回確認時から変更点があれば列挙してください。")
```

仕様変更を検出した場合は、本スキルの該当箇所（特に下記「herdr integration（統合フックの導入）」節と「検知遅延への対処」節）を更新すること。

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

### エージェントを spawn する（pane split → agent start の2段階方式）

🔴 **herdr 0.7.5では「pane生成+配置+起動」の1コマンドが廃止され、`herdr pane split` で pane を確保してから `herdr agent start --kind <KIND> --pane <ID>` で既存paneにエージェントを起動する2段階方式になった。** `--cwd`/`--workspace`/`--tab`/`--split`/`--env`/`--focus`/`--no-focus` は `agent start` から全て消え、配置に関する指定は `pane split` 側（`--pane`/`--current`・`--direction right|down`・`--ratio`・`--cwd`・`--env`・`--focus`/`--no-focus`）で行う。`--kind` はエージェント種別の明示指定（`pi`/`claude`/`codex`/`gemini`/`cursor`/`devin`/`agy`/`cline`/`omp`/`mastracode`/`opencode`/`copilot`/`kimi`/`kiro`/`droid`/`amp`/`grok`/`hermes`/`kilo`/`qodercli`/`maki` 等）で必須。

🔴 **`--kind` と `--` 以降の引数を混同しない**: 公式ドキュメント（herdr.dev/docs/cli-reference/）は "The kind selects Herdr's canonical interactive executable, while arguments after `--` are passed to that executable." と明記している。つまり `--kind` の値そのものが起動する実行ファイル（claude/pi/codex等）を決定し、`-- ` の後にはその実行ファイルへの**追加引数のみ**を書く。実行ファイル名自体を `--` 以降に重複して書いてはいけない（`--kind claude` を指定したのに `--` の後へ実行ファイル名を再度書くような重複は誤り）。追加引数が不要なら `--` 自体を省略できる。

```bash
# 1. pane を確保する（現在フォーカス中のpaneを右に分割）
SPLIT_JSON=$(herdr pane split --current --direction right --cwd ~/project --no-focus)
NEW_PANE=$(printf '%s' "$SPLIT_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["pane"]["pane_id"])')

# 2. 確保したpaneにエージェントを起動する（--kindが実行ファイルを決めるため、追加引数がなければ -- 自体省略可）
herdr agent start reviewer --kind pi --pane "$NEW_PANE" --timeout 30000
herdr agent start docs --kind claude --pane "$NEW_PANE" --timeout 30000 -- --permission-mode auto
```

`agent start` は既存paneへの起動専用になったため、新しいpane IDは事前の `pane split` の応答（`result.pane.pane_id`）で既に判明している。`agent start` 自体の応答構造（成功可否・JSON有無）は0.7.5で実機未検証のため、以降の状態確認は `herdr agent get <target>` / `herdr agent list` で行う。

> **⚠️ permission mode は明示指定する**: `--kind claude` で起動する際は `-- --permission-mode auto` を明示する。省略すると起動先 `--cwd` の settings.json 解決結果に依存し、Claude Code のステータス表示が「auto mode on」にならないことがある（`acceptEdits`/`dontAsk`/`bypassPermissions`/無指定はそれぞれ別のステータス表示になり `auto` とは異なる）。`auto` は内蔵classifierが安全な操作を自動承認しつつ `git push`/`git reset`/`rm -rf` 等の危険操作は引き続きブロックする準自動モードで、`bypassPermissions`（全許可）より安全。

> **⚠️ 分割対象の指定は `pane split` 側の責務になった**: 0.7.4では `agent start --split` が常に「現在フォーカスされているpane」を分割していたため複数体連続起動時にレイアウトが乱れやすかったが、0.7.5では分割は `pane split` の `--current`/`--pane <ID>` で明示的に指定するため、対象paneをより厳密にコントロールできる。それでも複数体を連続で並べる場合は、直前に確保・起動した pane を明示的に対象にして次の `pane split` を呼ぶ必要がある（フォーカス操作に頼るなら引き続き `herdr agent focus <直前のagent名>` の後に `pane split --current` を呼ぶ）。複数体を整列よく起動する手順は下記「複数エージェントを整列よく起動する」レシピを参照。

### エージェントの出力を読む・指示を送る

```bash
herdr agent read reviewer --source recent --lines 80          # 出力を読む（pane read と同じ --source に加え detection も指定可）
herdr agent prompt reviewer "review the test coverage in src/api/"   # テキスト送信+Enter確定を1コマンドで実行
```

`agent read` の `--source` は `visible` / `recent` / `recent-unwrapped` に加え、🔴 `detection`（エージェント検出根拠のスナップショット）が指定可能。`pane read` の `--source` には `detection` は追加されていない。

> **`agent prompt` と `agent send-keys` の違い**: 🔴 0.7.5では `agent send`（Enterを送らないテキスト書き込み）+ `pane send-keys <pane_id> Enter`（Enter確定）の2段階操作が廃止され、`herdr agent prompt <target> <text>` 1コマンドでテキスト送信とEnter確定が完結する。完了まで待ちたい場合は `--wait --until <state>...`（例: `--until idle --until done`）と `--timeout <MS>` を付ける。キー入力のみを送りたい場合（Enter単体など送信テキストがない場面）は `herdr agent send-keys <target> <key>...` を使う。シェルコマンドをテキスト入力とEnterの1リクエストで実行する場合は引き続き `herdr pane run <pane_id> <command>` を使う。

> **⚠️ Escape で中断した直後の多段送信は要注意**: 長時間動作中のエージェントを Escape で中断した直後に新しい指示テキストを `agent prompt` で送ると、通常のプロンプト送信として確定するとは限らない。対話型 UI が「プランを作成しますか」のような確認ダイアログ（モード切替キーや dismiss キーの選択肢）を表示したまま止まり、送ったテキストが入力欄に反映されないことがある。`agent prompt` を機械的に連投する前に、まず `herdr agent read <target> --source recent` や `herdr pane read <pane_id> --source recent` で現在の UI 状態を確認する。確認ダイアログが出ている場合は、そのダイアログを明示的に解決（選択肢に応じたキー入力を `agent send-keys` で送る）してから本来送りたい指示を送ること。中断して全く別の独立タスクに切り替えたい場合は、同じ pane へ多段送信するより新しい `pane split` + `agent start` で別 pane を起動する方が確実。

> **⚠️ プロンプト入力欄に未送信テキストが自動的に現れることがある（2回観測）**: エージェントが完了報告（時に質問を含む）を出した直後、`agent_status` が `idle`/`done` になった状態で `agent read`/`pane read --source recent`（または `visible`）を確認すると、`❯` プロンプト行（未送信の入力欄）に、誰も送信していないテキストが表示されていることが2回観測された。1回目は完了報告内の質問に対する妥当な承諾文が、2回目は完了報告と無関係な次操作を示唆する文言（`git commit` 等）が、それぞれ表示されていた。発生源は特定できていない。これは未確定の表示であり送信キューには入っていない模様——`pane send-keys <target> Enter` だけを送ってもこのテキストは送信されない（Enter 後も idle のまま・テキストも消えない）。このプリフィルを採用したい場合は、その内容を明示的に `agent prompt <target> "<同じ文言>"` で送り直す必要がある。逆に、このテキストが `git commit`/`push`/`rm` 等の危険操作を示唆している場合は、内容を採用するか自分でまず判断し、意図しない実行を避けるため不用意に `send-keys ... Enter` を送らない（git 書込操作はユーザー確認を要する運用ルールがある環境では、気づかず誤送信すると意図しない実行につながりかねない）。迷う場合は `pane close` で pane ごと破棄し、必要なら新しい pane で仕切り直すのが安全。

### エージェントのステータスを待機する

```bash
herdr agent wait reviewer --until idle --timeout 120000
```

🔴 0.7.5では `agent wait --status`（`idle`/`working`/`blocked`/`unknown`、`done`なし）とトップレベルの `herdr wait agent-status`（`idle`/`working`/`blocked`/`done`/`unknown`）という別名前空間の2コマンドが `herdr agent wait --until` 1つに統合された。`--until` は `idle`/`working`/`blocked`/`done`/`unknown` を指定でき、繰り返し指定でOR条件になる（例: `--until idle --until done`）。`--until` を省略すると `idle`/`done`/`blocked` のいずれかにマッチする。

### エージェントに直接アタッチする

```bash
herdr agent attach reviewer            # 直接アタッチ
herdr agent attach reviewer --takeover # 入力が競合する場合に強制的に主導権を取る
```

detach は `ctrl+b q`。

---

## herdr integration（統合フックの導入）

エージェントを install すると統合フックが導入されるが、その効果はエージェントによって異なる。

**lifecycle authority を獲得するエージェント**（install 後、`idle` / `working` / `blocked` とセッション同一性を authoritative（権威ある情報源）として報告するようになる）: Pi・OMP・Kimi Code CLI・Hermes Agent・OpenCode・Kilo Code CLI・MastraCode。

**🔴 lifecycle authority を獲得しないエージェント**（install 後も screen-manifest 検出が唯一のステータス判定経路のまま）: Claude Code・Codex・GitHub Copilot CLI・Droid・Qoder CLI・Cursor Agent CLI。公式ドキュメントは次のように明記している（原文引用）:

> "Claude Code, Codex, GitHub Copilot CLI, Droid, Qoder CLI, and Cursor Agent CLI integrations are intentionally not lifecycle authorities. They provide native session identity for restore, but their hooks do not cover the whole lifecycle."

つまり Claude Code・Codex に対する `integration install` は、セッション復元用の native session identity を提供するだけであり、`agent_status`（idle/working/blocked/done）の検知精度には寄与しない。

```bash
herdr integration install claude              # Claude Code の統合フックを導入（セッション復元用の識別情報付与のみ）
herdr integration install codex               # Codex の統合フックを導入（同上）
herdr integration status                      # 導入状況を確認
herdr integration status --outdated-only      # 更新が必要なものだけ表示
herdr integration uninstall claude            # 統合を解除
```

> **訂正（確認日: 2026-07-17）**: 従来「herdr 上で Claude Code / Codex エージェントを協調させる前に該当エージェントの統合を install しておくと、`agent wait` / `agent-status` の判定が screen-manifest フォールバックより信頼できる」と記載していたが、これは誤り。Claude Code・Codex は install してもステータス判定は常に screen-manifest に依存し続け、検知精度は向上しない。install する価値はセッション復元（`herdr session attach` 等での同一性維持）にあり、検知精度向上を目的に install しても効果はない。検知遅延そのものへの実務的な対処は下記「検知遅延への対処」セクションを参照。

---

## 出力を待機する（pane wait-output）

pane に特定のテキストが現れるまでブロックする。サーバー・ビルド・テストの完了待ちに有用。

🔴 0.7.5ではトップレベルの `herdr wait output` は廃止され、`herdr pane wait-output` に移動した。同時に `--match`（リテラル）と `--regex`（正規表現）が完全に別オプションになり、どちらか一方の指定が必須（併用不可・両方省略不可）。

`--source recent`（デフォルト）でのマッチングはソフトラップを除去した最近のターミナルテキストを使用するため、pane 幅やソフトラップによってマッチが壊れない。wait で使ったのと同じトランスクリプトを検査したい場合は `pane read --source recent-unwrapped` を使う。

```bash
herdr pane wait-output w1:p3 --match "ready on port 3000" --timeout 30000
herdr pane wait-output w1:p3 --regex "server.*ready" --timeout 30000
```

`--lines N` で走査範囲、`--raw` で生テキスト（ANSIエスケープ込み）のマッチングを指定できる。タイムアウトした場合、exit code は `1` になる。

---

## エージェントのステータスを待機する（agent wait --until）

別エージェントが特定のステータスに達するまでブロックする:

```bash
herdr agent wait w1:p1 --until done --timeout 60000
```

🔴 0.7.5では `herdr agent wait --status`（`done`なし）とトップレベルの `herdr wait agent-status --status`（`done`あり）という別名前空間の2コマンドが `herdr agent wait --until` 1つに統合された。`--until` は `idle` / `working` / `blocked` / `done` / `unknown` を指定でき、繰り返し指定でOR条件になる。UI に表示される `done` / `idle` の区別を同じ形で扱いたい場合は `--until done --until idle` のように複数指定する。

> **⚠️ ステータスだけで成果物の完成を判断しない**: `agent_status` が `done` / `idle` になったことは、そのエージェントの pane が動作中でなくなったことを示すに過ぎず、期待した成果物（計画ファイル・出力ファイル等）が実際に作成されたことは保証しない。前述の確認ダイアログで停止した場合でも status は `done` に見えることがある。成果物が作られたかどうかは対象ファイルの存在・内容・終端マーカーなど一次情報を直接確認して検証すること。

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
herdr pane wait-output "$NEW_PANE" --match "ready" --timeout 30000
herdr pane read "$NEW_PANE" --source recent --lines 20
```

### 別の pane でテストを実行して結果を確認する

```bash
NEW_PANE=$(herdr pane split w1:p2 --direction down --no-focus | python3 -c 'import sys,json; print(json.load(sys.stdin)["result"]["pane"]["pane_id"])')
herdr pane run "$NEW_PANE" "cargo test"
herdr pane wait-output "$NEW_PANE" --match "test result" --timeout 60000
herdr pane read "$NEW_PANE" --source recent --lines 30
```

### 別エージェントの作業内容を確認する

```bash
herdr agent list
herdr agent read reviewer --source recent --lines 80
```

### 新規エージェントを spawn してタスクを与える

```bash
SPLIT_JSON=$(herdr pane split --current --direction right --cwd ~/project --no-focus)
AGENT_PANE=$(printf '%s' "$SPLIT_JSON" | python3 -c \
  'import json,sys; print(json.load(sys.stdin)["result"]["pane"]["pane_id"])')
herdr agent start reviewer --kind claude --pane "$AGENT_PANE" --timeout 30000 -- --permission-mode auto
herdr agent wait reviewer --until idle --timeout 30000
herdr agent prompt reviewer "review the test coverage in src/api/"
```

### 複数エージェントを整列よく起動する（親の右 → その pane の下へ連鎖）

🔴 0.7.5では pane確保（`pane split`）とエージェント起動（`agent start --pane`）が別コマンドに分かれたため、複数体を整列よく並べる手順も「pane splitで対象を確保 → agent start --paneで起動」を1体ごとに繰り返す形になる。1体目は親の右に、2体目以降は「直前に確保・起動したpaneを対象に下方向へ分割」を繰り返すことで、親の右列に縦一列で整列させる。

```bash
# 1体目: 親（現在フォーカス中のpane）の右に分割してから起動
SPLIT1=$(herdr pane split --current --direction right --cwd ~/project --no-focus)
PANE1=$(printf '%s' "$SPLIT1" | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["pane"]["pane_id"])')
herdr agent start agent1 --kind claude --pane "$PANE1" --timeout 30000 -- --permission-mode auto --name agent1

# 2体目以降: 直前に確保したpaneを対象に下方向へ分割してから起動する
SPLIT2=$(herdr pane split --pane "$PANE1" --direction down --cwd ~/project --no-focus)
PANE2=$(printf '%s' "$SPLIT2" | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["pane"]["pane_id"])')
herdr agent start agent2 --kind claude --pane "$PANE2" --timeout 30000 -- --permission-mode auto --name agent2

SPLIT3=$(herdr pane split --pane "$PANE2" --direction down --cwd ~/project --no-focus)
PANE3=$(printf '%s' "$SPLIT3" | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["pane"]["pane_id"])')
herdr agent start agent3 --kind claude --pane "$PANE3" --timeout 30000 -- --permission-mode auto --name agent3

# 全員起動後、親にフォーカスを戻す（親 | 右列の2カラム構成なので left で一発戻れる）
herdr pane focus --direction left --current
```

`pane split` は `--pane <ID>` で分割元paneを明示指定できるため、0.7.4時点で必要だった「フォーカス切替による分割対象の誘導（`herdr agent focus <name>` を挟む）」は不要になった。直前に確保した pane id をそのまま次の `pane split --pane` に渡せばよい。

### 別エージェントと協調する

```bash
herdr agent wait w1:p1 --until done --timeout 120000
herdr agent read w1:p1 --source recent --lines 100
```

### 別の pane を堅牢に監視する

```bash
herdr pane read w1:p3 --source recent --lines 40                 # すでにある出力を検査
herdr pane wait-output w1:p3 --match "ready" --timeout 30000     # 期待する出力だけ待機
herdr pane read w1:p3 --source recent-unwrapped --lines 40       # wait と同じトランスクリプトを検査
```

---

## 🔴 検知遅延への対処（Claude Code・Codex 等 screen-manifest 依存エージェント向け）

Claude Code・Codex は lifecycle authority を持たないため、`agent_status` の判定は screen-manifest（画面下部バッファの直近スナップショットを TOML ルールで評価する仕組み）の推測に留まる。このため次のような症状が起こりうる:

- 子エージェントが完了しプロンプトへ戻っているのに、`agent_status` が `working` のまま残る
- `agent wait --until done` の解決が遅れる
- 確認ダイアログ（承認・質問・permission UI）を idle と誤検知する

以下の4パターンで実務的に緩和する。

### 対処1（最も確実）: 子自身に完了を明示報告させる

herdr は lifecycle hook を持たない外部プロセス向けに手動ステータス報告 API（`herdr pane report-agent`、上記「pane 名前空間」参照）を提供している。子（Claude Code 等）を起動する委譲プロンプトに、自分のタスク完了時に自分自身で以下を実行するよう含めておく:

```bash
herdr pane report-agent "$HERDR_PANE_ID" --source <名前> --agent <エージェント名> --state done --message "<完了概要>"
```

`$HERDR_PANE_ID` は herdr が pane に注入する環境変数（上記「concepts」参照）で、子は自分自身の pane id をここから取得できる（親から id を渡す必要がない）。この対処は screen-manifest の推測を待たず親が完了を即座に検知できる、最も確実な方法。

### 対処2: 一意な完了マーカー文字列を出力させて `pane wait-output` で直接待つ

`agent_status` の判定に頼らず、子に一意な完了マーカー文字列（例 `TASK_DONE:<一意ID>`）を出力させ、親は次のコマンドで直接そのテキストを待つ:

```bash
herdr pane wait-output <pane> --match "TASK_DONE:<一意ID>" --timeout <ms>
```

screen-manifest のルール評価を経由しないため、エージェント種別（lifecycle authority の有無）に依存せず確実に検知できる。

### 対処3: 検知根拠を確認する

判定根拠が不明な場合は次のコマンドで screen-manifest のマッチ根拠を確認する:

```bash
herdr agent explain <target> --json
```

`default_known_agent_idle_fallback` のようなラベルが出ている場合、マッチする明示的な検知ルールがなく idle にフォールバックしていることを意味する。

### 対処4（上級）: ローカルオーバーライドで検知ルールを調整する

screen-manifest の検知ルールは TOML マニフェストで定義されている。次のパスにローカルオーバーライドを置くと、リモート/バンドルされたマニフェストより優先して適用される（出典: https://herdr.dev/docs/agents/ ）:

```
~/.config/herdr/agent-detection/<agent>.toml
```

編集後は `herdr server reload-agent-manifests` を実行するか herdr を再起動しないと反映されない。新規エージェントの追加はローカルオーバーライドでは不可（herdr バイナリ更新が必要）。

⚠️ ここまでの対処はいずれも「検知そのもの」を screen-manifest の推測より速く・確実にするための手段にすぎない。前述の「ステータスだけで成果物の完成を判断しない」注記が示す通り、最終判断は必ず成果物の一次情報（対象ファイルの存在・内容・終端マーカー等）で行うこと。

---

## notes（補足事項）

**agent 検出の仕組み**: herdr のエージェント検出には2系統ある。① **lifecycle hooks**（Pi・OMP・Kimi Code CLI・Hermes Agent・OpenCode・Kilo Code CLI・MastraCode が対応）— `herdr integration install` で導入され、idle/working/blocked とセッション同一性を authoritative に報告する。② **screen manifests**（Claude Code・Codex・GitHub Copilot CLI・Droid・Qoder CLI・Cursor Agent CLI にとってはフォールバックではなく唯一の検知経路）— 画面下部バッファの直近スナップショットを TOML ルールで評価してエージェントを検出する。screen-manifest ベースのエージェントでは `blocked` 検出が意図的に厳格になる。🔴 Claude Code・Codex は `integration install` してもこの区分（screen-manifest 依存であること）は変わらない。検知遅延の実務的な緩和策は上記「検知遅延への対処」セクションを参照。

**JSON を返すコマンド**: `workspace list`・`workspace create`・`tab list`・`tab create`・`tab get`・`tab focus`・`tab rename`・`tab close`・`pane list`・`pane get`・`pane current`・`pane split`・`agent list`・`agent get`・`agent explain`（`--json`）・`pane wait-output`・`agent wait` は成功時に JSON を出力する。🔴 `agent start`（0.7.5で既存paneへの起動専用に変更）自体の応答構造（JSON有無・キー構造）は実機未検証のため、以降の状態確認は `agent get <target>` / `agent list` で行うことを推奨する。

**テキストを返すコマンド**: `pane read`・`agent read` は JSON ではなくテキストを返す。

**成功時に何も出力しないコマンド**: `pane send-text`・`pane send-keys`・`pane run`・`agent send-keys` は成功時に何も出力しない。🔴 `agent prompt`（0.7.5新設）は `--wait` 指定時に状態情報を返す可能性があるが、0.7.5で応答形式は実機未検証。

**新規 id の parse 方法**:
- `workspace create` のレスポンスは `result.workspace`・`result.tab`・`result.root_pane` を返す
- `tab create` のレスポンスは `result.tab`・`result.root_pane` を返す
- `pane split` の新 pane id は `result.pane.pane_id` にある
- 🔴 `agent start` は0.7.5で「既存paneへの起動専用」に変わったため、対象paneのidは事前の `pane split` の応答（`result.pane.pane_id`）で既に判明している。0.7.4時点で使われていた「`agent start` の新pane idは `result.agent.pane_id` にある」という取得手順は0.7.5では基本的に不要（`agent start` 自体がpane_idを返すかどうかは実機未検証。0.7.5で応答構造が変わっている場合は実機で要確認）

**`--no-focus` の効果**: `pane split`・`tab create`・`workspace create` に付けることで現在のターミナルコンテキストをフォーカスしたまま保つ（🔴 `agent start` からは0.7.5で `--no-focus` オプション自体が消えた。フォーカス制御は事前の `pane split` 側で行う）。

**`--label` の効果**: `tab create` と `workspace create` に付けるとカスタム名が即座に適用される。付けない場合、`workspace create` は cwd ベースの命名を維持し、`tab create` は番号付き命名を維持する。

**`pane read` / `agent read` の使い分け**: すでに存在する出力の確認には `read` を使う。次に来ることを期待する出力の待機には `pane wait-output` を使う。

**pane 系と agent 系の使い分け**: エージェントの spawn・観測・待機・指示は `herdr agent`（検出とステータス追跡が組み込まれる）を優先する。素のシェル・サーバー・テストなど任意のプロセスは `herdr pane split` + `herdr pane run` を使う。

**pane split の分割対象**: 0.7.5では `pane split` の `--pane <ID>` / `--current` で分割元paneを明示指定できる。複数体を整列よく連鎖配置したい場合は「複数エージェントを整列よく起動する」レシピの通り、直前に確保した pane id をそのまま次の `pane split --pane` に渡せばよく、0.7.4時点で必要だった `agent focus` によるフォーカス誘導は必須ではなくなった。

**`HERDR_ENV` 変数**: herdr 管理下の pane で動作している場合、`HERDR_ENV` 環境変数は `1` に設定されている。
