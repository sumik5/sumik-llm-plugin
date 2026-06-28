# agent-browser によるブラウザ自動化

## agent-browser とは（アーキテクチャ）

agent-browser は Vercel Labs 製の高速ネイティブ **Rust 製ブラウザ自動化 CLI**。AI エージェント向けに最適化されており、`snapshot` で取得した `ref` を使って操作する snapshot→ref ワークフロー、URL を agent-readable text として読む `read`、自然言語操作の `chat`、MCP サーバー化の `mcp` などを備える。

- **client-daemon アーキテクチャ**: Rust 製デーモンが Chrome DevTools Protocol (CDP) で Chrome を直接制御する。
- **Node.js / Playwright ランタイム不要**: デーモンの実行に Node.js も Playwright も要らない（"No Playwright or Node.js required for the daemon."）。
- **Chrome for Testing**: ブラウザ本体は `agent-browser install` で Google 公式の自動化用チャネル（Chrome for Testing）から取得する。

> 互換性メモ: state ファイルは storageState 互換の JSON 形式で保存される。trace は Playwright Trace Viewer で開ける。これらは互換フォーマットを採用しているだけで、ランタイムとして Playwright が動いているわけではない。

## 使い分け（このスキルが担う役割）

| 用途 | 第一選択 |
|------|---------|
| **アプリの web 操作・ブラウザ自動化**（スクレイピング、UI 操作フロー、認証永続化、フォーム送信、データ抽出） | **automating-browser**（agent-browser CLI）= 第一選択 |
| E2E テストスイートの設計・実装 | `web:testing-e2e-with-playwright`（住み分け） |
| パフォーマンス計測 / Lighthouse / 詳細トレース等の診断 | `chrome-devtools` MCP が補完 |
| ユーザーの既存 Chrome タブ・ログイン済みセッションの操作 | `claude-in-chrome` が補完 |

アプリのブラウザ自動化は agent-browser を起点にし、診断やユーザー実セッションの操作が必要な局面でのみ補完ツールへ切り替える。

## インストール

導入経路は複数ある。いずれの経路でも、最後に `agent-browser install` を実行して Chrome for Testing を取得する（**初回のみ・省略不可**）。

```bash
# npm (global)
npm install -g agent-browser && agent-browser install

# npm (local)
npm install agent-browser && agent-browser install

# Homebrew
brew install agent-browser && agent-browser install

# Cargo
cargo install agent-browser && agent-browser install

# Linux: システム依存パッケージも導入
agent-browser install --with-deps
```

- From source からビルドする場合は Node.js 24+ / pnpm 11+ / Rust が必要。
- 導入確認:

```bash
which agent-browser
agent-browser --version
```

### スキル発動時の自動インストール推奨フロー

```bash
which agent-browser >/dev/null 2>&1 || bash "${CLAUDE_SKILL_DIR}/scripts/install.sh"
```

`${CLAUDE_SKILL_DIR}` は自スキルのバンドルディレクトリに解決される公式変数。`install.sh` は npm 不在時に Homebrew / Cargo を案内する。

## 機能ハイライト

- **セマンティックロケーター**: `find role|text|label|placeholder|alt|title|testid|nth <value> <action>` でアクセシビリティ属性から要素を選択。
- **snapshot→ref ワークフロー**: `snapshot` はデフォルトで `ref`（アクセシビリティツリー）を返す。`-i` で interactive 要素のみ、`--urls` でリンク URL 付き。
- **状態永続化（state / auth vault）**: `state save|load|list|show|rename|clear` で storageState 互換 JSON を永続化。`auth save|login` で AES-256-GCM 暗号化された認証 Vault を扱う。
- **ネットワーク傍受（route / har）**: `network route` でリクエストを横取り（abort / body 差し替え / resource-type 指定）、`network har start|stop` で HAR 記録。
- **デバイスエミュレーション**: `set device "iPhone 14"` でデバイス、`set geo <lat> <lng>` で位置情報、`set media [dark|light]` でカラースキームをエミュレート。
- **read**: Chrome を起動せず URL を agent-readable text(markdown) として取得（URL 省略でアクティブタブの DOM を読む）。
- **chat**: 自然言語でブラウザを操作（single-shot / 引数なしで対話 REPL）。
- **batch**: 複数コマンドを連続実行（`--bail` で失敗時中断・stdin の JSON 配列にも対応）。
- **mcp**: stdio で MCP サーバーを起動し、ツールプロファイル（core / network / state / debug / tabs / react / mobile / all）を選択。
- **diff**: `diff snapshot|screenshot|url` で状態・ビジュアルの差分比較。
- **vitals**: `vitals [url]` で Web Vitals + hydration メトリクスを取得。
- **react**: `react tree|inspect|renders|suspense` で React 解析（要 `--enable react-devtools`）。

## クイックスタート

```bash
# 1. ページへ移動
agent-browser open <url>

# 2. interactive 要素を ref 付きで取得（@e1, @e2, ...）
agent-browser snapshot -i

# 3. snapshot の ref を使って操作
agent-browser click @e1
agent-browser fill @e2 "input text"

# 4. DOM 変化後は再 snapshot
agent-browser snapshot -i

# 5. 終了時にブラウザを閉じる
agent-browser close
```

## 中核ワークフロー

1. **Navigate**: `agent-browser open <url>`
2. **Snapshot**: `agent-browser snapshot -i`（`@e1`, `@e2` のような ref を返す）
3. **Interact**: snapshot の ref でクリック・入力などを実行
4. **Re-snapshot**: ナビゲーションや大きな DOM 変化のあと
5. **Repeat**: タスク完了まで繰り返す

## 主な環境変数

| 変数 | 説明 |
|------|------|
| `AGENT_BROWSER_SESSION` | 分離セッション名 |
| `AGENT_BROWSER_RESTORE` | 自動保存 / 復元するセッション状態の名前 |
| `AGENT_BROWSER_RESTORE_SAVE` | 復元保存ポリシー（`auto` / `always` / `never`） |
| `AGENT_BROWSER_NAMESPACE` | デーモンソケット / 復元状態ディレクトリの名前空間 |
| `AGENT_BROWSER_PROFILE` | Chrome プロファイル名 または 永続化ディレクトリのパス |
| `AGENT_BROWSER_STATE` | JSON ファイルからストレージ状態をロード |
| `AGENT_BROWSER_ENCRYPTION_KEY` | AES-256-GCM 用の 64 文字 hex キー |
| `AGENT_BROWSER_STATE_EXPIRE_DAYS` | N 日経過した状態を自動削除（既定 30） |
| `AGENT_BROWSER_DEFAULT_TIMEOUT` | 既定の操作タイムアウト（ms・既定 25000） |

> `AGENT_BROWSER_PROFILE` は「Chrome プロファイル名」または「永続化ディレクトリのパス」を指定する。パス指定（例: `/tmp/agent-browser-profile`）も引き続き有効で、専用ディレクトリを割り当てたい場合に使う。

## 関連リファレンス

- **コマンド詳細リファレンス**: `AGENT-COMMANDS.md`
- **実践例**: `AGENT-EXAMPLES.md`
- **GitHub リポジトリ**: https://github.com/vercel-labs/agent-browser
