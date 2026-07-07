# Hunk レビュー操作ガイド

Hunk は対話型のターミナル diff ビューアだ。**TUI 本体はユーザーのもの** — `hunk diff`・`hunk show` などの対話コマンドを直接実行してはならない。ローカルデーモン経由でライブセッションを検査・制御する `hunk session *` CLI コマンドのみを使う。

セッションが存在しない場合は、まずユーザーにターミナルで Hunk を起動してもらうこと。

## 🔴 大原則

| If X | then Y |
|------|--------|
| diff を見たい | `hunk session review --json` で file/hunk 構造を先に把握する（生 patch でコンテキストを膨張させない） |
| 生の unified diff テキストが本当に必要 | そのファイルに限り `--include-patch` を付ける |
| コメントを付けたい | 先に `navigate` でユーザーの視点を合わせてから `comment add` / `comment apply` |
| セッションが無い | ユーザーに Hunk 起動を依頼（推測で対話コマンドを叩かない） |

## 基本ワークフロー

```text
1. hunk session list                                    # ライブセッションを探す
2. hunk session get --repo .                            # path / repo / source を確認
3. hunk session review --repo . --json                  # まず file/hunk 構造を検査
4. hunk session review --repo . --include-patch --json  # 生 diff が要る時だけ opt-in
5. hunk session context --repo .                        # 必要時に現在のフォーカスを確認
6. hunk session navigate ...                            # 適切な位置へ移動
7. hunk session reload -- <command>                     # 必要なら内容を差し替え
8. hunk session comment add ...                         # 1件のレビューコメントを残す
9. hunk session comment apply ...                       # 複数コメントを stdin バッチで一括投入
```

## セッション選択

ほとんどの session コマンドは次を受け付ける:

- `--repo <path>` — ライブセッションを現在ロード中の repo ルートで照合（最も一般的）
- `<session-id>` — 正確な ID で照合（1 つの repo を複数セッションが共有する時に使う）
- セッションが 1 つだけなら自動解決される

`reload` は追加で次をサポートする:

- `--session-path <path>` — ライブ Hunk ウィンドウを現在の作業ディレクトリで照合
- `--source <path>` — 差し替える `diff` / `show` コマンドを別ディレクトリからロード

`--source` は「制御したいライブセッションが、次にロードしたい checkout と関連付いていない」高度な reload でのみ使う。通常の worktree セッションは `--repo /path/to/worktree` で直接選択するほうが良い。

## コマンド詳細

### Inspect（検査）

```bash
hunk session list [--json]
hunk session get (--repo . | <id>) [--json]
hunk session context (--repo . | <id>) [--json]
hunk session review (--repo . | <id>) [--json] [--include-patch]
```

- `get` はセッションの `Path` / `Repo` / `Source` を表示する。`--repo` と `--session-path` のどちらを使うか選ぶ手がかりになる
- `Repo` が `--repo` の照合対象、`Path` が `--session-path` の照合対象
- `review --json` はデフォルトで file/hunk 構造を返す。生の unified diff テキストが本当に必要な呼び出しでのみ `--include-patch` を足す

### Navigate（移動）

絶対ナビゲーションは `--file` と、`--hunk` / `--new-line` / `--old-line` のうち **ちょうど 1 つ** を要求する:

```bash
hunk session navigate --repo . --file src/App.tsx --hunk 2
hunk session navigate --repo . --file src/App.tsx --new-line 372
hunk session navigate --repo . --file src/App.tsx --old-line 355
```

コメント間の相対ナビゲーションは注釈済み hunk 間をジャンプし、`--file` を要求しない:

```bash
hunk session navigate --repo . --next-comment
hunk session navigate --repo . --prev-comment
```

- `--hunk <n>` は 1-based
- `--new-line` / `--old-line` はその diff サイドの 1-based 行番号
- `--next-comment` か `--prev-comment` のどちらか一方のみ（両方は不可）

### Reload（内容差し替え）

ライブセッションの内容を差し替える。`--` の後に Hunk レビューコマンドを渡す:

```bash
hunk session reload --repo . -- diff
hunk session reload --repo . -- diff main...feature -- src/ui
hunk session reload --repo . -- show HEAD~1
hunk session reload --repo . -- show HEAD~1 -- README.md
hunk session reload --repo /path/to/worktree -- diff
hunk session reload --session-path /path/to/live-window --source /path/to/other-checkout -- diff
```

- ネストした Hunk コマンドの前には **必ず `--`** を含める
- 通常は `--repo` か `<session-id>` で目的のセッションを選択する
- `--source` は高度な用途: セッションを選択せず、差し替えレビューコマンドの実行場所だけを変える
- ライブセッションが既に目的の worktree を表示しているなら `hunk session reload --repo /path/to/worktree -- diff` を優先
- `--session-path` は、セッション選択と reload ソースを分離したい時にライブウィンドウを狙う

### Comments（コメント）

```bash
hunk session comment add --repo . --file README.md --new-line 103 --summary "Tighten this wording" [--rationale "..."] [--author "agent"] [--focus]
printf '%s\n' '{"comments":[{"filePath":"README.md","newLine":103,"summary":"Tighten this wording"}]}' | hunk session comment apply --repo . --stdin [--focus]
hunk session comment list --repo . [--file README.md] [--type live|all|ai|agent|user]
hunk session comment rm --repo . <comment-id>
hunk session comment clear --repo . --yes [--file README.md]
```

- `comment list --type user` は人間が書いたインラインノートを表示。`--type` 無しの `comment list` は従来の live-agent-comment ビューを保つ
- `comment add` は 1 件のノート向き。`comment apply` はエージェントが既に複数ノートを準備済みの時に最適
- `comment add` は `--file`・`--summary`・`--old-line`/`--new-line` のうち 1 つを要求する
- `comment apply` の payload 各項目は `filePath`・`summary`・ターゲット 1 つ（`hunk`・`hunkNumber`・`oldLine`・`newLine` のいずれか）を要求する
- `comment apply` は stdin から JSON バッチを読み、ライブセッションを変更する前にバッチ全体を検証する
- 新しいノート（またはバッチの先頭ノート）へジャンプしたい時は `--focus` を付ける
- `comment list` と `comment clear` は任意で `--file` を受け付ける
- `--summary` と `--rationale` はシェルで防御的にクォートする

## working-tree レビューでの新規ファイル

`hunk diff` はデフォルトで untracked ファイルを含む。tracked な変更だけを見たい場合は `--exclude-untracked` で reload する:

```bash
hunk session reload --repo . -- diff --exclude-untracked
```

## レビューをガイドする

ユーザーは変更セットのウォークスルーや、Hunk を使ったコードレビューを依頼してくることがある。まず `hunk session review --json` で file/hunk 構造を把握し（エージェントのコンテキストを膨張させない）、本当に生 diff で読む必要があるファイルにのみ `--include-patch` を使う。`context` と `navigate` でユーザーの現在ビューを揃えてからコメントを付ける。

あなたの役割は **ナレーション**だ: ユーザーの視点を重要な箇所へ誘導し、今見ているものを説明するコメントを残す。

典型的なフロー:

1. 正しい内容をロードする（必要なら `reload`）
2. 最初の注目すべき file / hunk へ移動する
3. 何が起きていて、なぜかを説明するコメントを付ける
4. 既に複数ノートが準備済みなら、多数の個別シェル呼び出しより 1 回の `comment apply` バッチを優先する
5. 完了したら要約する

ガイドライン:

- ファイル順ではなく、最も明快にストーリーが伝わる順序で進める
- コメント前にナビゲートし、議論対象のコードをユーザーに見せる
- エージェント生成のバッチには `comment apply`、単発ノートには `comment add`
- コメント自身がレビューを能動的に誘導すべき時のみ `--focus` を控えめに使う
- コメントは焦点を絞る: 意図・構造・リスク・フォローアップ
- 全 hunk にコメントしない — ユーザーが自力で気づけない点を際立たせる

## よくあるエラー

- **"No visible diff file matches ..."** — そのファイルはロード済みレビューに含まれていない。`context` を確認し、必要なら `reload` する
- **"No active Hunk sessions"** — Hunk が明らかに動作中なら、localhost がエージェントサンドボックスにブロックされている可能性。network/sandbox 権限を昇格して再試行する。そうでなければユーザーに Hunk を開いてもらう
- **"Multiple active sessions match"** — `<session-id>` を明示的に渡す
- **"No active Hunk session matches session path ..."** — 高度な split-path reload では、`hunk session get` / `list` でライブウィンドウの `Path` を確認してから `--session-path` を使う
- **"Pass the replacement Hunk command after `--`"** — ネストした `diff` / `show` コマンドの前に `--` を含める
- **"Pass --stdin to read batch comments from stdin JSON."** — `comment apply` はバッチ payload を stdin からのみ読む
- **"Specify exactly one navigation target"** — `--hunk` / `--old-line` / `--new-line` のうち 1 つを選ぶ
- **"Specify either --next-comment or --prev-comment, not both."** — コメントナビゲーションの方向を 1 つに絞る
