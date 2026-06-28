# agent-browser コマンドリファレンス（正典）

`agent-browser`（Vercel Labs 製の高速ネイティブ Rust 製ブラウザ自動化 CLI）の全コマンド・全フラグ・全環境変数を網羅した正典リファレンス。

## アーキテクチャ前提

- `agent-browser` は **client-daemon アーキテクチャ**。Rust デーモンが **Chrome DevTools Protocol (CDP)** で Chrome を直接制御する。
- デーモンの実行に **Node.js / Playwright ランタイムは不要**（"No Playwright or Node.js required for the daemon."）。
- Chrome 本体は `agent-browser install` で **Chrome for Testing**（Google 公式の自動化用チャネル）から取得する。
- AI エージェント向けに最適化されており、`snapshot` が返す `ref`（要素参照）を後続コマンドに渡す **snapshot→ref ワークフロー**、`read` / `chat` / `mcp` などの高水準コマンドを備える。
- 互換情報: `state` ファイルは storageState 互換の JSON 形式で保存される。`trace` で記録したトレースは Playwright Trace Viewer で開ける。

## インストール

複数の導入経路がある。いずれも導入後に **`agent-browser install`（初回のみ Chrome for Testing を DL・省略不可）** を実行する。

```bash
# npm (global)
npm install -g agent-browser && agent-browser install

# npm (local)
npm install agent-browser && agent-browser install

# Homebrew
brew install agent-browser && agent-browser install

# Cargo
cargo install agent-browser && agent-browser install

# From source (Node.js 24+ / pnpm 11+ / Rust が必要)

# Linux 依存込み
agent-browser install --with-deps
```

導入確認:

```bash
which agent-browser
agent-browser --version
```

スキル発動時の自動インストール推奨フロー（`${CLAUDE_SKILL_DIR}` は自スキルのバンドルディレクトリに解決される公式変数）:

```bash
which agent-browser >/dev/null 2>&1 || bash "${CLAUDE_SKILL_DIR}/scripts/install.sh"
```

`install.sh` は npm 不在時に Homebrew / Cargo をフォールバック案内する。

## ナビゲーションコマンド

| コマンド | 説明 |
|---------|------|
| `open <url>`（別名 `goto` / `navigate`） | URL へ遷移 |
| `open <url> --headed` | ブラウザウィンドウを表示して遷移 |
| `open <url> --headers '{"key":"value"}'` | カスタム HTTP ヘッダー付きで遷移 |
| `back` | 履歴を戻る |
| `forward` | 履歴を進む |
| `reload` | 現在のページを再読込 |
| `close` | ブラウザセッションを閉じる |

```bash
# 基本
agent-browser open https://example.com

# ヘッダー付き（認証など）
agent-browser open https://api.example.com --headers '{"Authorization": "Bearer TOKEN"}'

# デバッグ用に可視ウィンドウで
agent-browser open https://example.com --headed
```

## snapshot コマンド

`snapshot` は **デフォルトでアクセシビリティツリーの `ref`（要素参照）を返す**。返った `ref` を `click` / `fill` などの後続コマンドに渡す（snapshot→ref ワークフロー）。

| オプション | 短縮 | 説明 |
|-----------|------|------|
| `--interactive` | `-i` | interactive な要素のみ表示 |
| `--compact` | `-c` | 空ノードを除去 |
| `--depth <n>` | `-d` | ツリーの深さを制限 |
| `--selector <css>` | `-s` | CSS セレクタにスコープ |
| `--urls` | | リンクの URL を付与して表示 |
| `--json` | | JSON 形式で出力 |

```bash
# デフォルト（ref を返す）
agent-browser snapshot

# interactive な要素のみ
agent-browser snapshot -i

# 大きなページはコンパクトに
agent-browser snapshot -i -c

# 特定領域にスコープ
agent-browser snapshot -s "#main-content"

# リンク URL 付き
agent-browser snapshot --urls

# 機械可読出力
agent-browser snapshot --json
```

## read コマンド

Chrome を起動せず URL を取得し、**agent-readable text（markdown）** を返す。URL を省略するとアクティブタブの DOM を読む。

| フラグ | 説明 |
|--------|------|
| `--filter <x>` | 内容をフィルタ |
| `--outline` | 見出しのアウトラインのみ |
| `--llms <index\|full>` | `llms.txt` を参照（index / full） |
| `--require-md` | markdown を要求 |
| `--json` | JSON 形式で出力 |

```bash
# URL を直接 markdown で取得（Chrome 不要）
agent-browser read https://example.com

# アクティブタブの DOM を読む
agent-browser read

# アウトラインのみ
agent-browser read https://example.com --outline
```

## chat コマンド

自然言語でブラウザを操作する（single-shot）。引数なしで起動すると対話 REPL に入る。AI Gateway 利用時は `AI_GATEWAY_API_KEY` を使う。

| フラグ | 説明 |
|--------|------|
| `-q` | quiet 出力 |
| `-v` | verbose 出力 |
| `--model <id>` | 使用するモデル ID |
| `--json` | JSON 形式で出力 |

```bash
# 自然言語で 1 回操作
agent-browser chat "ログインフォームに入力して送信して"

# 対話 REPL
agent-browser chat

# モデル指定
agent-browser chat "検索結果の上位 5 件を抽出" --model some-model-id
```

## batch コマンド

複数コマンドを連続実行する。stdin に JSON 配列を渡して `--json` も使える。

| フラグ | 説明 |
|--------|------|
| `--bail` | 失敗時に中断 |
| `--json` | stdin の JSON 配列を入力／JSON 出力 |

```bash
# 複数コマンドを連続実行
agent-browser batch "open https://example.com" "snapshot -i" "click @e1"

# 失敗時に中断
agent-browser batch --bail "open https://example.com" "click @e1"

# JSON 配列を stdin から
echo '["open https://example.com", "snapshot"]' | agent-browser batch --json
```

## diff コマンド

状態・ビジュアルの差分を比較する。

| サブコマンド | 説明 |
|-------------|------|
| `diff snapshot` | アクセシビリティスナップショットの差分 |
| `diff screenshot` | スクリーンショット（ビジュアル）の差分 |
| `diff url` | URL の差分 |

```bash
agent-browser diff snapshot
agent-browser diff screenshot
agent-browser diff url
```

## react コマンド

React アプリを解析する（**`--enable react-devtools` が必要**）。

| サブコマンド | 説明 |
|-------------|------|
| `react tree` | コンポーネントツリー |
| `react inspect` | コンポーネントの詳細を検査 |
| `react renders` | 再レンダリングを追跡 |
| `react suspense` | Suspense 境界を解析 |

```bash
agent-browser open https://example.com --enable react-devtools
agent-browser react tree
agent-browser react renders
```

## vitals コマンド

Web Vitals + hydration メトリクスを取得する。

| 引数／フラグ | 説明 |
|-------------|------|
| `[url]` | 計測対象 URL（省略でアクティブタブ） |
| `--json` | JSON 形式で出力 |

```bash
agent-browser vitals
agent-browser vitals https://example.com --json
```

## インタラクションコマンド

### マウス操作

| コマンド | 説明 |
|---------|------|
| `click <selector>` | 要素をクリック |
| `dblclick <selector>` | ダブルクリック |
| `hover <selector>` | 要素にホバー |
| `drag <from> <to>` | 要素から要素へドラッグ |

### キーボード操作（要素単位）

| コマンド | 説明 |
|---------|------|
| `fill <selector> <text>` | フィールドをクリアして入力 |
| `type <selector> <text>` | クリアせず入力 |
| `press <key>` | 単一キーを押下 |
| `press <key1>+<key2>` | キー組み合わせを押下 |

### キー名

`press` で使う主なキー名:
- ナビゲーション: `Enter`, `Tab`, `Escape`, `Backspace`, `Delete`
- 矢印: `ArrowUp`, `ArrowDown`, `ArrowLeft`, `ArrowRight`
- 修飾キー: `Control`, `Shift`, `Alt`, `Meta`（Mac の Cmd）
- ファンクション: `F1`〜`F12`
- 特殊: `Home`, `End`, `PageUp`, `PageDown`, `Space`

```bash
agent-browser press Control+a       # 全選択
agent-browser press Control+c       # コピー
agent-browser press Control+v       # 貼り付け
agent-browser press Meta+Enter      # Mac: Cmd+Enter
```

### keyboard コマンド（実キーストローク送出）

ページ全体に対し実際のキーストロークを送出する（要素を経由しない）。

| コマンド | 説明 |
|---------|------|
| `keyboard type <text>` | テキストを 1 文字ずつタイプ |
| `keyboard inserttext <text>` | テキストを一括挿入 |

```bash
agent-browser keyboard type "Hello, world"
agent-browser keyboard inserttext "貼り付け相当の一括挿入"
```

### フォームコントロール

| コマンド | 説明 |
|---------|------|
| `check <selector>` | チェックボックスを ON |
| `uncheck <selector>` | チェックボックスを OFF |
| `select <selector> <value>` | ドロップダウンを選択 |
| `upload <selector> <file>` | ファイルをアップロード |

### スクロール

| コマンド | 説明 |
|---------|------|
| `scroll up <px>` | 上にスクロール |
| `scroll down <px>` | 下にスクロール |
| `scroll left <px>` | 左にスクロール |
| `scroll right <px>` | 右にスクロール |
| `scrollintoview <selector>` | 要素を表示域へスクロール |

## 情報取得（get コマンド）

| コマンド | 説明 |
|---------|------|
| `get text <selector>` | 可視テキストを取得 |
| `get value <selector>` | 入力フィールドの値を取得 |
| `get html <selector>` | 要素の HTML を取得 |
| `get attr <selector> <name>` | 属性値を取得 |
| `get title` | ページタイトルを取得 |
| `get url` | 現在の URL を取得 |
| `get count <selector>` | 一致要素数をカウント |
| `get box <selector>` | バウンディングボックスを取得 |
| `get styles <selector>` | 算出スタイルを取得 |

### 状態確認（is コマンド）

| コマンド | 説明 |
|---------|------|
| `is visible <selector>` | 要素が可視か |
| `is enabled <selector>` | 要素が有効か |
| `is checked <selector>` | チェックボックスが ON か |

## wait コマンド

| コマンド | 説明 |
|---------|------|
| `wait <selector>` | 要素が可視になるまで待機 |
| `wait <ms>` | ミリ秒待機 |
| `wait --text "<text>"` | テキスト出現を待機 |
| `wait --url "<pattern>"` | URL がパターンに一致するまで待機 |
| `wait --load networkidle` | ネットワークアイドルまで待機 |
| `wait --load domcontentloaded` | DOM 構築完了まで待機 |
| `wait --load load` | ページ load まで待機 |
| `wait --js "<expression>"`（別名 `--fn`） | JS 条件が true になるまで待機 |
| `wait <selector> --hidden` | 要素が非表示になるまで待機 |

```bash
agent-browser wait @e1
agent-browser wait "#loading" --hidden
agent-browser wait --load networkidle
agent-browser wait --url "**/success"
agent-browser wait --js "window.dataLoaded === true"
```

## セマンティックロケーター（find コマンド）

`ref` ではなくセマンティックな属性で要素を探して操作する。構文は `find <type> <value> <action> [--name]`。

| ロケータ種別 | 説明 |
|-------------|------|
| `role <role>` | ARIA ロールで検索 |
| `text "<text>"` | 可視テキストで検索 |
| `label "<label>"` | 関連ラベルで検索 |
| `placeholder "<text>"` | プレースホルダで検索 |
| `alt "<text>"` | alt テキスト（画像）で検索 |
| `title "<text>"` | title 属性で検索 |
| `testid "<id>"` | data-testid で検索 |
| `nth <value>` | n 番目の要素で検索 |

```bash
agent-browser find role button click --name "Submit"
agent-browser find role textbox fill "hello" --name "Email"
agent-browser find text "Sign In" click
agent-browser find label "Email" fill "user@example.com"
agent-browser find placeholder "Search..." fill "query"
agent-browser find testid "submit-button" click
```

## ネットワークコマンド

### リクエスト傍受

| コマンド | 説明 |
|---------|------|
| `network route <url> [--abort\|--body\|--resource-type]` | 一致リクエストを傍受 |
| `network unroute` | 傍受を解除 |
| `network requests [--filter\|--type\|--method\|--status]` | キャプチャ済みリクエストを一覧 |

```bash
# リクエストを中断（ブロック）
agent-browser network route "**/*.png" --abort

# レスポンスをモック
agent-browser network route "**/api/users" --body '{"users":[]}'

# キャプチャ済みリクエストを参照
agent-browser network requests
agent-browser network requests --filter "**/api/*" --method GET
```

### HAR 記録

| コマンド | 説明 |
|---------|------|
| `network har start` | HAR 記録を開始 |
| `network har stop [output.har]` | HAR 記録を停止し保存 |

```bash
agent-browser network har start
# ... 操作 ...
agent-browser network har stop session.har
```

## タブ・ウィンドウ・フレーム

| コマンド | 説明 |
|---------|------|
| `tab list` | 全タブを一覧 |
| `tab new <url>` | 新規タブを開く |
| `tab switch <index>` | インデックスでタブ切替 |
| `tab close [index]` | タブを閉じる |
| `window new <url>` | 新規ウィンドウを開く |
| `window close` | 現在のウィンドウを閉じる |

### フレーム

| コマンド | 説明 |
|---------|------|
| `frame list` | 全フレームを一覧 |
| `frame select <name\|index>` | フレームへ切替 |
| `frame main` | メインフレームへ戻る |

```bash
agent-browser frame list
agent-browser frame select "iframe-name"
agent-browser snapshot -i
agent-browser click @e1
agent-browser frame main
```

## ストレージ管理

### Cookie

| コマンド | 説明 |
|---------|------|
| `cookies list` | 全 Cookie を一覧 |
| `cookies get <name>` | 特定の Cookie を取得 |
| `cookies set <name> <value>` | Cookie を設定 |
| `cookies delete <name>` | Cookie を削除 |
| `cookies clear` | 全 Cookie を削除 |

### Local / Session Storage

| コマンド | 説明 |
|---------|------|
| `storage local list` | localStorage を一覧 |
| `storage local get <key>` | localStorage の値を取得 |
| `storage local set <key> <value>` | localStorage に設定 |
| `storage local delete <key>` | localStorage から削除 |
| `storage local clear` | localStorage を全削除 |
| `storage session list` | sessionStorage を一覧 |
| `storage session get <key>` | sessionStorage の値を取得 |
| `storage session set <key> <value>` | sessionStorage に設定 |
| `storage session delete <key>` | sessionStorage から削除 |
| `storage session clear` | sessionStorage を全削除 |

## state コマンド（認証/ストレージ状態の永続化）

ログイン状態などを storageState 互換の JSON で保存・復元する。

| コマンド | 説明 |
|---------|------|
| `state save <path>` | 現在の状態を保存 |
| `state load <path>` | 保存済み状態を読込 |
| `state list` | 保存済み状態を一覧 |
| `state show <path>` | 状態の内容を表示 |
| `state rename <old> <new>` | 状態をリネーム |
| `state clear <path>` | 状態を削除 |

```bash
# 認証状態を保存
agent-browser state save auth.json

# 別実行で復元
agent-browser state load auth.json
```

## auth コマンド（暗号化された認証 Vault）

ログイン情報を暗号化して保管し、再ログインを省略する。暗号鍵は `AGENT_BROWSER_ENCRYPTION_KEY`（64 文字 hex）で指定する。

| コマンド | 説明 |
|---------|------|
| `auth save <name> --url <login-url>` | ログインフローを記録し Vault に保存 |
| `auth login <name>` | 保存済み認証でログイン |

```bash
agent-browser auth save mysite --url https://example.com/login
agent-browser auth login mysite
```

## ダイアログ処理

| コマンド | 説明 |
|---------|------|
| `dialog accept [text]` | ダイアログを受諾（任意で入力テキスト） |
| `dialog dismiss` | ダイアログをキャンセル |

```bash
agent-browser dialog accept
agent-browser dialog accept "my input"
agent-browser dialog dismiss
```

## JavaScript 実行（eval コマンド）

| コマンド | 説明 |
|---------|------|
| `eval <expression>` | JavaScript を評価 |
| `eval --file <path>` | JS ファイルを実行 |

```bash
agent-browser eval "document.title"
agent-browser eval "document.querySelectorAll('a').length"
agent-browser eval --file ./script.js
```

## スクリーンショット・PDF

| コマンド | 説明 |
|---------|------|
| `screenshot` | stdout へスクリーンショット |
| `screenshot <path>` | ファイルへ保存 |
| `screenshot --full`（別名 `--full-page`） | ページ全体を撮影 |
| `screenshot --selector <css>` | 特定要素を撮影 |
| `screenshot --annotate` | 要素注釈付きで撮影 |
| `pdf <path>` | PDF を生成 |
| `pdf <path> --format A4` | 用紙サイズを指定して PDF 生成 |

## 出力・診断

| コマンド | 説明 |
|---------|------|
| `console [--json\|--clear]` | コンソールメッセージを参照／クリア |
| `errors [--clear]` | ページエラーを参照／クリア |
| `trace start` | トレース記録を開始 |
| `trace stop <path>` | トレースを停止し保存（Playwright Trace Viewer で開ける） |
| `inspect` | Chrome DevTools を開く |

```bash
agent-browser console
agent-browser console --json
agent-browser errors
agent-browser trace start
# ... 操作 ...
agent-browser trace stop trace.zip
agent-browser inspect
```

## session コマンド（分離セッション）

| コマンド | 説明 |
|---------|------|
| `--session <name>` | 名前付きセッションを使用 |
| `session list` | アクティブセッションを一覧 |
| `session close <name>` | 特定セッションを閉じる |

```bash
agent-browser --session site1 open https://site1.com
agent-browser --session site2 open https://site2.com
agent-browser --session site1 snapshot -i
agent-browser session list
agent-browser session close site1
```

## set コマンド（ブラウザ設定）

| コマンド | 説明 |
|---------|------|
| `set viewport <width> <height>` | ビューポートサイズを設定 |
| `set device "<name>"` | デバイスをエミュレート |
| `set geo <lat> <lng>` | 位置情報を設定 |
| `set offline <true\|false>` | オフラインモードを切替 |
| `set headers <json>` | グローバルヘッダーを設定 |
| `set media [dark\|light]` | カラースキームをエミュレート |

```bash
# モバイルビューポート
agent-browser set viewport 375 667

# デバイスエミュレート
agent-browser set device "iPhone 14"
agent-browser set device "Pixel 5"

# 位置情報（NYC）
agent-browser set geo 40.7128 -74.0060

# ダークモードをエミュレート
agent-browser set media dark
```

## mcp コマンド（MCP サーバー起動）

stdio で MCP サーバーを起動し、`agent-browser` の機能を MCP ツールとして外部エージェントへ公開する。ツールプロファイルを `--tools` で選ぶ。

| プロファイル | 内容 |
|-------------|------|
| `core` | 既定のコアツール |
| `network` | ネットワーク系 |
| `state` | 状態永続化系 |
| `debug` | デバッグ系 |
| `tabs` | タブ操作系 |
| `react` | React 解析系 |
| `mobile` | モバイル/デバイス系 |
| `all` | 全ツール |

```bash
# コアツールのみで MCP サーバー起動（既定）
agent-browser mcp

# 全ツールを公開
agent-browser mcp --tools all

# 複数プロファイルを組み合わせ
agent-browser mcp --tools core,network,react
```

## グローバルフラグ

| フラグ | 説明 |
|--------|------|
| `--session <name>` | 名前付きセッションを使用 |
| `--restore [name]` | セッション状態を自動復元 |
| `--restore-save <policy>` | 復元保存ポリシー（auto / always / never） |
| `--restore-check-url <glob>` | 復元時に URL を glob 検証 |
| `--restore-check-text <text>` | 復元時にテキストを検証 |
| `--restore-check-fn <js>` | 復元時に JS 関数で検証 |
| `--profile <name\|path>` | Chrome プロファイル名 または永続化ディレクトリのパス |
| `--state <path>` | JSON ファイルからストレージ状態を読込 |
| `--proxy <url>` | プロキシ URL を指定 |
| `--headed` | ブラウザウィンドウを表示 |
| `--json` | JSON 出力 |
| `--config <path>` | 設定ファイルを指定 |
| `--allowed-domains <list>` | 許可ドメインを制限 |
| `--max-output <chars>` | 出力の最大文字数を制限 |
| `--content-boundaries` | 内容境界を明示 |
| `--annotate` | 要素注釈を付与 |
| `--provider`, `-p <name>` | 実行先プロバイダ（後述） |
| `--debug` | デバッグログを有効化 |
| `--timeout <ms>` | コマンドタイムアウトを設定 |

## クラウドプロバイダ（--provider / -p）

`--provider`（`-p`）でブラウザの実行先をクラウドサービスやデバイスに切り替えられる。

| 値 | 実行先 |
|----|--------|
| `browserless` | Browserless |
| `browserbase` | Browserbase |
| `browseruse` | Browser Use |
| `kernel` | Kernel |
| `agentcore` | AgentCore |
| `ios` | iOS デバイス |

```bash
# クラウドプロバイダ上で実行
agent-browser -p browserbase open https://example.com

# iOS デバイス上で実行
agent-browser --provider ios open https://example.com
```

## 設定ファイル

ユーザー設定 `~/.agent-browser/config.json` またはプロジェクト設定 `./agent-browser.json` を読み込む。主なキー:

| キー | 説明 |
|------|------|
| `headed` | ブラウザウィンドウを表示するか |
| `proxy` | プロキシ URL |
| `profile` | Chrome プロファイル名 / 永続化ディレクトリ |
| `hideScrollbars` | スクロールバーを隠すか |
| `plugins` | プラグイン設定（vault 等） |

```json
{
  "headed": false,
  "proxy": "http://proxy.example.com:8080",
  "profile": "/path/to/profile",
  "hideScrollbars": true,
  "plugins": { "vault": true }
}
```

## 環境変数

| 変数 | 説明 |
|------|------|
| `AGENT_BROWSER_SESSION` | 分離セッション名 |
| `AGENT_BROWSER_RESTORE` | 自動保存/復元するセッション状態の名前 |
| `AGENT_BROWSER_RESTORE_SAVE` | 復元保存ポリシー（auto / always / never） |
| `AGENT_BROWSER_NAMESPACE` | デーモンソケット/復元状態ディレクトリの名前空間 |
| `AGENT_BROWSER_PROFILE` | Chrome プロファイル名 または永続化ディレクトリのパス |
| `AGENT_BROWSER_STATE` | JSON ファイルからストレージ状態をロード |
| `AGENT_BROWSER_ENCRYPTION_KEY` | AES-256-GCM 用の 64 文字 hex キー |
| `AGENT_BROWSER_STATE_EXPIRE_DAYS` | N 日経過した状態を自動削除（既定 30） |
| `AGENT_BROWSER_DEFAULT_TIMEOUT` | 既定の操作タイムアウト（ms・既定 25000） |

```bash
# 永続化ディレクトリをプロファイルに指定
export AGENT_BROWSER_PROFILE=/tmp/agent-browser-profile

# 暗号鍵（auth Vault 用）
export AGENT_BROWSER_ENCRYPTION_KEY=<64 文字 hex>
```

## 接続・デーモン管理・診断

`agent-browser` は最初のコマンドでデーモンを自動起動し、コマンド間で常駐させる（高速化のため）。`close` はブラウザを閉じるが **デーモンは残る** 点に注意。

| コマンド / フラグ | 説明 |
|------------------|------|
| `connect <port\|url>` | 起動中のブラウザに CDP で接続 |
| `--cdp <port>` | CDP ポート経由で接続（グローバルフラグ・各コマンドに付与） |
| `--auto-connect` | 実行中の Chrome を自動検出して接続（auth 状態を再利用） |
| `close [--all]` | ブラウザを閉じる（`--all` で全セッションを閉じる） |
| `doctor [--fix]` | 導入を診断し stale なソケット等を自動クリーン（接続不調時の切り分け） |
| `upgrade` | 最新バージョンへ更新 |

### 見える（ヘッドフル）ブラウザを操作する

実行プロセスが GUI（デスクトップ）セッション外（一部のエージェント実行環境・CI・SSH など）だと、`--headed` を付けても Chrome ウィンドウが画面に描画されない。その場合は見える Chrome を別途起動し、CDP ポートで接続する。

```bash
# macOS（open -na が LaunchServices 経由でウィンドウを前面起動）
open -na "Google Chrome" --args --remote-debugging-port=9222 --user-data-dir=/tmp/abrowser-chrome-debug "about:blank"
# Linux
google-chrome --remote-debugging-port=9222 --user-data-dir=/tmp/abrowser-chrome-debug about:blank &

# CDP ポートが開くまで待つ（sleep を使わずリトライ）
curl --retry 25 --retry-delay 1 --retry-connrefused -s http://127.0.0.1:9222/json/version

# 接続して操作（各コマンドに --cdp を付与）
agent-browser --cdp 9222 open https://example.com
agent-browser --cdp 9222 snapshot -i
```
