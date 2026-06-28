# agent-browser CLI

`agent-browser` は Vercel Labs 製の高速ネイティブ・ブラウザ自動化 CLI。Rust 製デーモンが Chrome DevTools Protocol (CDP) を介して Chrome を直接制御する client-daemon アーキテクチャを採る。デーモンの実行に Node.js / Playwright ランタイムは不要（"No Playwright or Node.js required for the daemon."）で、Chrome は `agent-browser install` が Chrome for Testing（Google 公式の自動化用チャネル）から取得する。AI エージェント向けに最適化されており、`snapshot` → `ref` ワークフロー・`read`・`chat`・`mcp` など、エージェントが扱いやすいコマンド群を備える。

## 優先利用方針

アプリの web 操作・ブラウザ自動化（スクレイピング、UI 操作フロー、認証永続化、フォーム送信、データ抽出）は **本スキル（agent-browser CLI）を第一選択** にする。下記の住み分けに従う。

| ユースケース | 推奨 | 説明 |
|------------|------|------|
| ブラウザ操作自動化（スクレイピング・UI操作フロー・認証永続化・フォーム送信・データ抽出） | **`automating-browser`（本スキル・agent-browser CLI）** | 第一選択。CDP 直結で高速・状態永続化・ネットワーク傍受が可能 |
| E2E テストスイートの設計・実装 | `web:testing-e2e-with-playwright` | `@playwright/test` によるテスト設計（ロケーター、フィクスチャ、CI/CD） |
| パフォーマンス計測 / Lighthouse / 詳細トレース等の診断 | `chrome-devtools` MCP | 計測・診断を補完 |
| 既存 Chrome タブ / ログイン済みセッションの操作 | `claude-in-chrome` | ユーザーの開いているブラウザを補完的に操作 |

## Prerequisites（自動インストール）

スキル発動時、まず導入を確認し、未導入なら同梱の `install.sh` を実行する。

```bash
which agent-browser >/dev/null 2>&1 || bash "${CLAUDE_SKILL_DIR}/scripts/install.sh"
```

`${CLAUDE_SKILL_DIR}` は自スキルのバンドルディレクトリに解決される公式変数。`install.sh` は npm 不在時に Homebrew / Cargo 経路を案内する。

導入経路（いずれも最後に Chrome DL ステップが必須）:

| 経路 | コマンド |
|------|---------|
| npm (global) | `npm install -g agent-browser` → `agent-browser install` |
| npm (local) | `npm install agent-browser` → `agent-browser install` |
| Homebrew | `brew install agent-browser` → `agent-browser install` |
| Cargo | `cargo install agent-browser` → `agent-browser install` |
| From source | Node.js 24+ / pnpm 11+ / Rust が必要 |
| Linux 依存込み | `agent-browser install --with-deps` |

- 🔴 `agent-browser install` は初回のみ Chrome for Testing を DL する。**必須・省略不可**（このステップを飛ばすと Chrome が見つからず操作できない）。
- 導入確認: `which agent-browser` / `agent-browser --version`

## 環境変数

| 環境変数 | 意味 |
|---------|------|
| `AGENT_BROWSER_SESSION` | 分離セッション名 |
| `AGENT_BROWSER_RESTORE` | 自動保存/復元するセッション状態の名前 |
| `AGENT_BROWSER_RESTORE_SAVE` | 復元保存ポリシー（`auto` / `always` / `never`） |
| `AGENT_BROWSER_NAMESPACE` | デーモンソケット / 復元状態ディレクトリの名前空間 |
| `AGENT_BROWSER_PROFILE` | Chrome プロファイル名 または 永続化ディレクトリのパス |
| `AGENT_BROWSER_STATE` | JSON ファイルからストレージ状態をロード |
| `AGENT_BROWSER_ENCRYPTION_KEY` | AES-256-GCM 用の 64 文字 hex キー |
| `AGENT_BROWSER_STATE_EXPIRE_DAYS` | N 日経過した状態を自動削除（既定 30） |
| `AGENT_BROWSER_DEFAULT_TIMEOUT` | 既定の操作タイムアウト（ms・既定 25000） |

`AGENT_BROWSER_PROFILE` には「Chrome プロファイル名」または「永続化ディレクトリのパス」を渡せる。パス指定の例:

```bash
export AGENT_BROWSER_PROFILE=/tmp/agent-browser-profile   # 永続化ディレクトリのパスを指定
```

## Quick Start ワークフロー

`snapshot` でアクセシビリティツリーを取得すると各要素に `@e1` `@e2` のような `ref` が振られる。以降の操作はこの `ref` を指して行うのが最も確実。

```bash
agent-browser open https://example.com           # ページを開く
agent-browser snapshot                            # デフォルトで ref 付きツリーを返す
agent-browser snapshot -i                         # interactive 要素のみに絞る
agent-browser click @e1                           # ref で要素をクリック
agent-browser fill @e2 "入力値"                   # ref で入力
agent-browser snapshot                            # 操作後の状態を再取得して確認
agent-browser close                               # 終了
```

## セレクタ優先順位

| 優先 | セレクタ | 用途 |
|------|---------|------|
| 1 | **Refs**（`@e1` 等） | `snapshot` が返す参照。最も安定・推奨 |
| 2 | **CSS** | `#id` `.class` 等。構造が安定している場合 |
| 3 | **text** | `find text "ログイン"` 等。表示テキストで指定 |
| 4 | **role** | `find role button --name "送信"` 等。アクセシビリティロール |
| 5 | **label** | `find label "メール"` 等。フォームラベル |

## 主要コマンド抜粋

```bash
# ナビゲーション
agent-browser open <url>        # 別名 goto / navigate
agent-browser back
agent-browser forward
agent-browser reload
agent-browser close

# snapshot（解析）
agent-browser snapshot                 # ref 付きツリー（デフォルト）
agent-browser snapshot -i              # interactive 要素のみ
agent-browser snapshot --urls          # リンク URL 付き
agent-browser snapshot --json

# 操作
agent-browser click @e1
agent-browser fill @e2 "text"
agent-browser type @e2 "text"
agent-browser press @e2 Enter
agent-browser hover @e3
agent-browser select @e4 "option"
agent-browser check @e5
agent-browser upload @e6 ./file.png

# 待機
agent-browser wait @e1                  # セレクタの出現を待つ
agent-browser wait 1000                 # ミリ秒待機
agent-browser wait --text "完了"
agent-browser wait --url "**/dashboard"
agent-browser wait --load networkidle

# screenshot
agent-browser screenshot out.png
agent-browser screenshot out.png --full
agent-browser screenshot out.png --selector @e1

# デバイス / 位置情報のエミュレート
agent-browser set device "iPhone 14"           # デバイスエミュレート
agent-browser set geo <lat> <lng>              # 位置情報
agent-browser set media dark                   # カラースキーム
```

## 新機能の短い紹介

- **`read [url]`**: Chrome を起動せずに URL を取得し、agent-readable な markdown を返す。URL 省略でアクティブタブの DOM を読む。`--filter <x>` / `--outline` / `--llms <index|full>` / `--require-md` / `--json`。
- **`chat "<instruction>"`**: 自然言語でブラウザを操作（single-shot）。引数なしで対話 REPL。`-q` / `-v` / `--model <id>` / `--json`。AI Gateway 利用時は `AI_GATEWAY_API_KEY` を使う。
- **`batch "cmd1" "cmd2"`**: 複数コマンドを連続実行。`--bail` で失敗時に中断。stdin に JSON 配列を渡して `--json` も可。
- **`mcp [--tools <profile>]`**: stdio で MCP サーバーを起動。ツールプロファイル: `core`(既定) / `network` / `state` / `debug` / `tabs` / `react` / `mobile` / `all`。
- **`auth save <name> --url <login-url>` / `auth login <name>`**: 暗号化された認証 Vault でログイン状態を保存・再利用。
- **`state save|load|list|show|rename|clear <path>`**: 認証 / ストレージ状態の永続化（storageState 互換の JSON 形式）。
- **`diff snapshot|screenshot|url`**: 状態 / ビジュアルの差分比較。
- **`vitals [url] [--json]`**: Web Vitals + hydration メトリクスを取得。
- **`react tree|inspect|renders|suspense`**: React 解析（要 `--enable react-devtools`）。

## よくあるパターン

### フォーム送信

```bash
agent-browser open https://example.com/contact
agent-browser snapshot -i                  # 入力要素の ref を把握
agent-browser fill @e1 "山田太郎"
agent-browser fill @e2 "taro@example.com"
agent-browser click @e3                    # 送信ボタン
agent-browser wait --text "送信完了"
```

### ログイン + 状態保存

```bash
agent-browser open https://example.com/login
agent-browser fill @e1 "$USER"
agent-browser fill @e2 "$PASS"
agent-browser click @e3
agent-browser wait --url "**/dashboard"
agent-browser state save ./auth.json       # storageState 互換 JSON で保存

# 次回以降はログインを省略して状態をロード
agent-browser --state ./auth.json open https://example.com/dashboard
```

### データ抽出

```bash
# Chrome を起動せず markdown で取得（軽量）
agent-browser read https://example.com/article --outline

# 動的ページは open → snapshot → get
agent-browser open https://example.com/list
agent-browser get text @e1
agent-browser get count ".item"
agent-browser eval "document.querySelectorAll('.price').length"
```

## ヘッドフル（可視）操作とデーモン管理

### デーモンモデル（接続不調時の最初の一手）

`agent-browser` のデーモンは **最初のコマンドで自動起動し、コマンド間で常駐** する（高速化のため）。`close` はブラウザを閉じるが **デーモンは残る** ため、headless で起動した後に headed へ切り替えるなど起動オプションが食い違うと `Failed to connect: No such file or directory (os error 2)` 等が出ることがある。挙動が崩れたらデーモンをリセットする。

```bash
agent-browser close --all      # 全セッションを閉じる
agent-browser doctor --fix     # stale なソケット等を診断・自動クリーン
```

`agent-browser doctor` は CLI / Chrome / デーモン / プロバイダの健全性を一覧表示する（接続不調の切り分けに有用）。

### ブラウザを「見える状態」で操作する（CDP 接続）

`--headed`（または `AGENT_BROWSER_HEADED=true`）を付けても、実行プロセスが GUI（デスクトップ）セッションに属さない環境（一部のエージェント実行環境・CI・SSH など）では、Chrome は起動するがウィンドウが画面に描画されない。この場合は **見える Chrome を別途起動して CDP ポートで接続** する。

```bash
# 1) GUI セッションに見える Chrome を remote-debugging 付きで起動
#    macOS: open -na が LaunchServices 経由でウィンドウを前面起動する
open -na "Google Chrome" --args --remote-debugging-port=9222 --user-data-dir=/tmp/abrowser-chrome-debug "about:blank"
#    Linux: google-chrome --remote-debugging-port=9222 --user-data-dir=/tmp/abrowser-chrome-debug about:blank &

# 2) CDP ポートが開くまで待つ（sleep を使わずリトライ）
curl --retry 25 --retry-delay 1 --retry-connrefused -s http://127.0.0.1:9222/json/version

# 3) その見える Chrome に接続して操作（各コマンドに --cdp を付ける）
agent-browser --cdp 9222 open https://www.google.com
agent-browser --cdp 9222 snapshot -i
agent-browser --cdp 9222 find role combobox fill "検索語"
agent-browser --cdp 9222 press Enter
agent-browser --cdp 9222 read                     # 結果を markdown で取得
```

- 起動中の通常 Chrome を再利用するなら `--auto-connect`（実行中の Chrome を自動検出して接続）も使える。
- `--user-data-dir` を分けると普段使いの Chrome プロファイルと競合しない。

## 詳細リファレンス

| ファイル | 内容 |
|---------|------|
| [BROWSER-AGENT.md](./references/BROWSER-AGENT.md) | エージェント概要と機能 |
| [AGENT-COMMANDS.md](./references/AGENT-COMMANDS.md) | コマンドリファレンス（全コマンド・全フラグ） |
| [AGENT-EXAMPLES.md](./references/AGENT-EXAMPLES.md) | 使用例 |

公式リポジトリ: https://github.com/vercel-labs/agent-browser
