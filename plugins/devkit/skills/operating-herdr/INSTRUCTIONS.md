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
- pane を分割してコマンドを実行する
- sibling pane でサーバー起動・ログ監視・テスト実行を行う
- 特定の出力が現れるまで待機してから処理を続ける
- 別エージェントの完了を待機する
- エージェントインスタンスをさらに spawn する

`herdr` バイナリは PATH に存在する。socket API の詳細・完全なリファレンスは https://herdr.dev/docs/socket-api/ を参照。

---

## concepts（基本概念）

**workspaces** はプロジェクトコンテキスト。各 workspace は1つ以上の tab を持つ。手動でリネームしない限り、workspace のラベルは最初の tab のルート pane に従う（通常はリポジトリ名、なければルート pane のカレントフォルダ名）。

**tabs** は workspace 内のサブコンテキスト。各 tab は1つ以上の pane を持つ。

**panes** は tab 内のターミナル分割領域。各 pane は独自のプロセス（シェル・エージェント・サーバー・任意のプロセス）を実行する。

**agent_status** は herdr が自動検出する。API は以下のフィールドを公開する:
- `agent_status` — `idle` / `working` / `blocked` / `done` / `unknown`

`done` はエージェントが完了したが、その完了済み pane をまだ確認していない状態を意味する。シェルも pane として存在するが、herdr のサイドバーはシェル全件ではなく検出されたエージェントに意図的に絞って表示する。

**ids** — workspace id は `1`・`2` のような形式。tab id は `1:1`・`1:2`・`2:1` のような形式。pane id は `1-1`・`1-2`・`2-1` のような形式。これらは現在のライブセッションに対するコンパクトな公開 ID。

> **⚠️ 注意**: tab・pane・workspace が閉じられると id が詰まる（compact）場合がある。id を永続的な識別子として扱わないこと。現在の id が必要な場合は `workspace list`・`tab list`・`pane list` あるいは create/split レスポンスから再読みすること。以前の `1-3` が後で同じ pane を指しているとは限らない。

---

## 自己発見（discover yourself）

存在する pane と focused な pane を確認する:

```bash
herdr pane list
```

focused な pane が自分自身。その他の pane が neighbor（隣接 pane）。

workspace を一覧表示する:

```bash
herdr workspace list
```

---

## tab 管理

現在の workspace 内の tab を一覧表示:

```bash
herdr tab list --workspace 1
```

新規 tab を作成（`--label` なしの場合はデフォルトの番号付き tab 名が維持される）:

```bash
herdr tab create --workspace 1
```

作成と同時に名前を付ける:

```bash
herdr tab create --workspace 1 --label "logs"
```

tab をリネーム:

```bash
herdr tab rename 1:2 "logs"
```

tab にフォーカスする:

```bash
herdr tab focus 1:2
```

tab を閉じる:

```bash
herdr tab close 1:2
```

---

## 別の pane の出力を読み取る

別の pane の画面内容を確認する:

```bash
herdr pane read 1-1 --source recent --lines 50
```

`--source` オプション:
- `--source visible` — 現在のビューポートを取得する
- `--source recent` — pane 内でレンダリングされた最近のスクロールバックを取得する
- `--source recent-unwrapped` — ソフトラップを結合してまとめた最近のターミナルテキストを取得する

> **補足**: `pane read` はテキストを返す（JSON ではない）。`--format ansi` または `--ansi` フラグを付けると TUI フィードバックループ向けにレンダリング済みの ANSI スナップショットを返す。

---

## pane を分割してコマンドを実行する

pane を右に分割し、現在の pane にフォーカスを保つ:

```bash
herdr pane split 1-2 --direction right --no-focus
```

このコマンドは新しい pane の情報を JSON で出力し、新 pane の id は `result.pane.pane_id` にある。その値を parse してコマンドを実行する:

```bash
NEW_PANE=$(herdr pane split 1-2 --direction right --no-focus | python3 -c 'import sys,json; print(json.load(sys.stdin)["result"]["pane"]["pane_id"])')
herdr pane run "$NEW_PANE" "npm run dev"
```

下方向に分割する場合:

```bash
herdr pane split 1-2 --direction down --no-focus
```

---

## 出力を待機する（wait output）

pane に特定のテキストが現れるまでブロックする。サーバー・ビルド・テストの完了待ちに有用。

`--source recent` でのマッチングはソフトラップを除去した最近のターミナルテキストを使用するため、pane 幅やソフトラップによってマッチが壊れない。`pane read --source recent` は pane をレンダリング済みで表示する。wait で使ったのと同じトランスクリプトを検査したい場合は `pane read --source recent-unwrapped` を使う。

```bash
herdr wait output 1-3 --match "ready on port 3000" --timeout 30000
```

正規表現を使う場合:

```bash
herdr wait output 1-3 --match "server.*ready" --regex --timeout 30000
```

タイムアウトした場合、exit code は `1` になる。

---

## エージェントのステータスを待機する（wait agent-status）

別エージェントが特定のステータスに達するまでブロックする:

```bash
herdr wait agent-status 1-1 --status done --timeout 60000
```

UI に表示される `done` / `idle` の区別を同じ形で扱いたい場合に使用する。

---

## テキスト・キーを pane に送信する

テキストを Enter なしで送信:

```bash
herdr pane send-text 1-1 "hello from claude"
```

Enter やその他のキーを送信:

```bash
herdr pane send-keys 1-1 Enter
```

`pane run` はテキスト送信と実際の Enter キー送信を1リクエストで行う:

```bash
herdr pane run 1-1 "echo hello"
```

---

## workspace 管理

新規 workspace を作成（`--label` なしの場合は cwd ベースのデフォルト名が維持される）:

```bash
herdr workspace create --cwd /path/to/project
```

作成と同時に名前を付ける:

```bash
herdr workspace create --cwd /path/to/project --label "api server"
```

フォーカスせずに作成:

```bash
herdr workspace create --no-focus
```

workspace にフォーカスする:

```bash
herdr workspace focus 2
```

workspace をリネーム:

```bash
herdr workspace rename 1 "api server"
```

workspace を閉じる:

```bash
herdr workspace close 2
```

---

## pane を閉じる

```bash
herdr pane close 1-3
```

---

## recipes（実用パターン）

### サーバーを起動して準備完了まで待機する

```bash
NEW_PANE=$(herdr pane split 1-2 --direction right --no-focus | python3 -c 'import sys,json; print(json.load(sys.stdin)["result"]["pane"]["pane_id"])')
herdr pane run "$NEW_PANE" "npm run dev"
herdr wait output "$NEW_PANE" --match "ready" --timeout 30000
herdr pane read "$NEW_PANE" --source recent --lines 20
```

### 別の pane でテストを実行して結果を確認する

```bash
herdr pane split 1-2 --direction down --no-focus
herdr pane run 1-3 "cargo test"
herdr wait output 1-3 --match "test result" --timeout 60000
herdr pane read 1-3 --source recent --lines 30
```

### 別エージェントの作業内容を確認する

```bash
herdr pane list
herdr pane read 1-1 --source recent --lines 80
```

### 別の pane を堅牢に監視する

```bash
# すでにある出力を検査する
herdr pane read 1-3 --source recent --lines 40
# 次に期待する出力だけを待機する
herdr wait output 1-3 --match "ready" --timeout 30000
# wait がマッチしたのと同じトランスクリプトを検査したい場合は recent-unwrapped で直接読む
herdr pane read 1-3 --source recent-unwrapped --lines 40
```

### 新規エージェントを spawn してタスクを与える

```bash
herdr pane split 1-2 --direction right --no-focus
herdr pane run 1-3 "claude"
herdr wait output 1-3 --match ">" --timeout 15000
herdr pane run 1-3 "review the test coverage in src/api/"
```

### 別エージェントと協調する

```bash
herdr wait agent-status 1-1 --status done --timeout 120000
herdr pane read 1-1 --source recent --lines 100
```

---

## notes（補足事項）

**JSON を返すコマンド**: `workspace list`・`workspace create`・`tab list`・`tab create`・`tab get`・`tab focus`・`tab rename`・`tab close`・`pane list`・`pane get`・`pane split`・`wait output`・`wait agent-status` は成功時に JSON を出力する。

**テキストを返すコマンド**: `pane read` は JSON ではなくテキストを返す。

**成功時に何も出力しないコマンド**: `pane send-text`・`pane send-keys`・`pane run` は成功時に何も出力しない。

**新規 id の parse 方法**:
- `workspace create` のレスポンスは `result.workspace`・`result.tab`・`result.root_pane` を返す
- `tab create` のレスポンスは `result.tab`・`result.root_pane` を返す
- `pane split` の新 pane id は `result.pane.pane_id` にある

**`--no-focus` の効果**: `pane split`・`tab create`・`workspace create` に付けることで現在のターミナルコンテキストをフォーカスしたまま保つ。

**`--label` の効果**: `tab create` と `workspace create` に付けるとカスタム名が即座に適用される。付けない場合、`workspace create` は cwd ベースの命名を維持し、`tab create` は番号付き命名を維持する。

**`pane read` の使い分け**: すでに存在する出力の確認には `pane read` を使う。次に来ることを期待する出力の待機には `wait output` を使う。

**`HERDR_ENV` 変数**: herdr 管理下の pane で動作している場合、`HERDR_ENV` 環境変数は `1` に設定されている。
