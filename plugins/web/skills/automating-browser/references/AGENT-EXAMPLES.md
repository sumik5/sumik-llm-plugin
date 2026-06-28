# agent-browser 実践例集

よくある自動化シナリオの実例集。agent-browser は Vercel Labs 製の Rust ネイティブ CLI で、デーモンが Chrome DevTools Protocol (CDP) で Chrome を直接制御する（デーモン実行に Node.js / Playwright ランタイムは不要）。

> **snapshot の前提**: `snapshot` はデフォルトでアクセシビリティツリーと `ref`（要素参照）を返す。`-i` は interactive 要素のみに絞り込むフラグで、ノイズ削減のために使う。`--urls` でリンクの URL を付与できる。`@e1` のような ref は DOM 更新後に変わるため、アクションの前後で必要に応じて再 snapshot する。

## Example 1: ログインフローと状態の永続化

```bash
# 初回ログイン
agent-browser open https://app.example.com/login
agent-browser snapshot
# 出力例: textbox "Email" [ref=e1], textbox "Password" [ref=e2], button "Sign In" [ref=e3]

agent-browser fill @e1 "user@example.com"
agent-browser fill @e2 "secretPassword123"
agent-browser click @e3
agent-browser wait --url "**/dashboard"

# 認証済み状態を保存して再利用（storageState 互換の JSON）
agent-browser state save auth-state.json
agent-browser close

# 後で: 認証済みセッションを復元
agent-browser state load auth-state.json
agent-browser open https://app.example.com/dashboard
agent-browser snapshot
# すでにログイン済み
```

## Example 2: 複数の入力タイプを含むフォーム

```bash
agent-browser open https://example.com/registration
agent-browser snapshot -i

# テキスト入力
agent-browser fill @e1 "John Doe"           # 名前
agent-browser fill @e2 "john@example.com"   # メール
agent-browser fill @e3 "+1-555-123-4567"    # 電話

# ドロップダウン選択
agent-browser select @e4 "USA"              # 国

# ラジオボタン / チェックボックス
agent-browser click @e5                     # プラン選択
agent-browser check @e6                     # 規約チェックボックス

# 日付ピッカー（ネイティブ input の場合）
agent-browser fill @e7 "2024-12-31"

# ファイルアップロード
agent-browser upload @e8 /path/to/document.pdf

# 送信
agent-browser click @e9
agent-browser wait --load networkidle
agent-browser wait --text "Registration successful"
```

## Example 3: JSON 出力でのデータスクレイピング

```bash
agent-browser open https://example.com/products
agent-browser snapshot -i --json > page-structure.json

# 特定データの取得
agent-browser get text ".product-title" --json
agent-browser get text ".product-price" --json
agent-browser get attr ".product-image" src --json

# 件数カウント
agent-browser get count ".product-card"

# ページネーション・スクレイピングのループパターン
agent-browser open https://example.com/products?page=1
agent-browser snapshot -i

# ページ1のデータ取得
agent-browser get text @e1 --json >> results.json

# 次ページへ
agent-browser click @e10  # "Next" ボタン
agent-browser wait --load networkidle
agent-browser snapshot -i

# ページ2のデータ取得
agent-browser get text @e1 --json >> results.json
```

## Example 4: スクリーンショットによるドキュメント化

```bash
# フルページ・スクリーンショット
agent-browser open https://example.com/features
agent-browser wait --load networkidle
agent-browser screenshot features-full.png --full

# 特定要素のスクリーンショット
agent-browser snapshot -i
agent-browser screenshot hero-section.png --selector "#hero"

# 複数ビューポートのスクリーンショット
agent-browser set viewport 1920 1080
agent-browser screenshot desktop.png

agent-browser set viewport 768 1024
agent-browser screenshot tablet.png

agent-browser set viewport 375 667
agent-browser screenshot mobile.png

# PDF 生成
agent-browser pdf documentation.pdf --format A4
```

## Example 5: セッション分離による並列テスト

```bash
# 複数の分離セッションを開始
agent-browser --session user1 open https://app.example.com/login
agent-browser --session user2 open https://app.example.com/login
agent-browser --session admin open https://app.example.com/admin/login

# 異なるユーザーでログイン（各セッションは独立）
agent-browser --session user1 snapshot -i
agent-browser --session user1 fill @e1 "user1@example.com"
agent-browser --session user1 fill @e2 "password1"
agent-browser --session user1 click @e3

agent-browser --session user2 snapshot -i
agent-browser --session user2 fill @e1 "user2@example.com"
agent-browser --session user2 fill @e2 "password2"
agent-browser --session user2 click @e3

agent-browser --session admin snapshot -i
agent-browser --session admin fill @e1 "admin@example.com"
agent-browser --session admin fill @e2 "adminpass"
agent-browser --session admin click @e3

# 各セッションは cookie・storage・認証状態が分離される
agent-browser session list

# ユーザー間のインタラクションをテスト
agent-browser --session user1 open https://app.example.com/chat
agent-browser --session user2 open https://app.example.com/chat
# ... ユーザー間のリアルタイムメッセージングをテスト

# クリーンアップ
agent-browser --session user1 close
agent-browser --session user2 close
agent-browser --session admin close
```

## Example 6: API 認証とヘッダー

```bash
# 認証付き API エンドポイントへアクセス
agent-browser open https://api.example.com/dashboard \
  --headers '{"Authorization": "Bearer eyJhbGciOiJIUzI1NiIs..."}'

# セッション全体にヘッダーを設定
agent-browser set headers '{"Authorization": "Bearer TOKEN", "X-API-Key": "key123"}'
agent-browser open https://api.example.com/protected
agent-browser snapshot -i
```

## Example 7: E2E テストパターン

```bash
#!/bin/bash
# e2e-test.sh - 完結した E2E テスト例

set -e  # エラーで終了

echo "Starting E2E test..."

# セットアップ
agent-browser open https://app.example.com --headed

# テスト: 商品検索ができる
agent-browser snapshot -i
agent-browser fill @e1 "laptop"  # 検索入力
agent-browser click @e2          # 検索ボタン
agent-browser wait --load networkidle
agent-browser wait --text "results found"
echo "✓ Search works"

# テスト: カートに追加できる
agent-browser snapshot -i
agent-browser click @e3          # 最初の商品
agent-browser wait --url "**/product/*"
agent-browser snapshot -i
agent-browser click @e4          # カートに追加
agent-browser wait --text "Added to cart"
echo "✓ Add to cart works"

# テスト: カートを表示できる
agent-browser click @e5          # カートアイコン
agent-browser wait --url "**/cart"
agent-browser snapshot -i
CART_COUNT=$(agent-browser get text ".cart-count")
[ "$CART_COUNT" = "1" ] && echo "✓ Cart count correct"

# テスト: チェックアウトへ進める
agent-browser click @e6          # チェックアウトボタン
agent-browser wait --url "**/checkout"
echo "✓ Checkout navigation works"

# クリーンアップ
agent-browser close
echo "All tests passed!"
```

> 注: 体系的な E2E テストスイートの設計・実装は web:testing-e2e-with-playwright を使う（住み分け）。本スキルはアプリの web 操作・自動化フローの第一選択。

## Example 8: 動的コンテンツの処理

```bash
# AJAX で読み込まれるコンテンツを待つ
agent-browser open https://example.com/dashboard
agent-browser wait --load networkidle
agent-browser wait --js "window.dataLoaded === true"
agent-browser snapshot -i

# 無限スクロールの処理
agent-browser open https://example.com/feed
agent-browser snapshot -i

# スクロールして追加コンテンツを読み込む
agent-browser scroll down 1000
agent-browser wait --load networkidle
agent-browser snapshot -i  # 新要素を取得するため再 snapshot

# 新規コンテンツがなくなるまで読み込む
PREV_COUNT=0
CURR_COUNT=$(agent-browser get count ".feed-item")
while [ "$CURR_COUNT" -gt "$PREV_COUNT" ]; do
  PREV_COUNT=$CURR_COUNT
  agent-browser scroll down 1000
  agent-browser wait --load networkidle
  CURR_COUNT=$(agent-browser get count ".feed-item")
done
echo "Loaded all $CURR_COUNT items"
```

## Example 9: モーダル・ダイアログの処理

```bash
agent-browser open https://example.com/settings
agent-browser snapshot -i

# モーダルを開くボタンをクリック
agent-browser click @e1  # "Delete Account" ボタン

# モーダルの出現を待つ
agent-browser wait ".modal"
agent-browser snapshot -i  # モーダル要素を取得するため再 snapshot

# モーダルを操作
agent-browser fill @e5 "DELETE"  # 確認入力
agent-browser click @e6           # 確定ボタン

# JavaScript の confirm ダイアログを処理
agent-browser dialog accept

# または却下
# agent-browser dialog dismiss
```

## Example 10: iFrame の操作

```bash
agent-browser open https://example.com/embed-page
agent-browser snapshot -i  # メインフレームのコンテンツ

# 利用可能なフレーム一覧
agent-browser frame list

# iframe へ切り替え
agent-browser frame select "payment-iframe"
agent-browser snapshot -i  # iframe のコンテンツを表示

# iframe 内を操作
agent-browser fill @e1 "4111111111111111"  # カード番号
agent-browser fill @e2 "12/25"              # 有効期限
agent-browser fill @e3 "123"                # CVV
agent-browser click @e4                     # 送信

# メインフレームへ戻る
agent-browser frame main
agent-browser snapshot -i
```

## Example 11: ネットワーク傍受とモック

```bash
# アナリティクスと広告をブロック
agent-browser network route "**/analytics/*" --abort
agent-browser network route "**/ads/*" --abort

# テスト用に API レスポンスをモック
agent-browser network route "**/api/user" \
  --body '{"name": "Test User", "email": "test@example.com"}'

# モックレスポンスでナビゲート
agent-browser open https://app.example.com
agent-browser snapshot -i

# 捕捉したリクエストを確認
agent-browser network requests --json

# 傍受を解除
agent-browser network unroute "**/api/user"
```

## Example 12: デバイスエミュレーションによるモバイルテスト

```bash
# iPhone をエミュレート（旧 emulate コマンドは廃止 → set device を使う）
agent-browser set device "iPhone 14"
agent-browser open https://example.com
agent-browser screenshot mobile-ios.png

# Android をエミュレート
agent-browser set device "Pixel 5"
agent-browser open https://example.com
agent-browser screenshot mobile-android.png

# カスタムビューポート
agent-browser set viewport 390 844
agent-browser open https://example.com
agent-browser snapshot -i

# 位置情報のエミュレート（geolocation ではなく set geo）
agent-browser set geo 35.6895 139.6917   # 東京 (lat lng)

# カラースキームのエミュレート
agent-browser set media dark

# レスポンシブ・ブレークポイントのテスト
for WIDTH in 320 375 768 1024 1920; do
  agent-browser set viewport $WIDTH 800
  agent-browser screenshot "viewport-${WIDTH}.png"
done
```

## Example 13: デバッグセッション

```bash
# 可視ブラウザで起動
agent-browser --headed open https://buggy-app.example.com

# JavaScript エラーを確認
agent-browser errors

# コンソールメッセージを表示
agent-browser console

# パフォーマンス分析のためトレース開始
agent-browser trace start

# 操作を実行
agent-browser snapshot -i
agent-browser click @e1
agent-browser fill @e2 "test"
agent-browser click @e3

# トレースを停止して保存
agent-browser trace stop debug-trace.zip
# debug-trace.zip は Playwright Trace Viewer で開ける
```

## Example 14: cookie ベースのセッション管理

```bash
# 現在の cookie を一覧
agent-browser cookies list

# カスタム cookie を設定
agent-browser cookies set "session_id" "abc123"
agent-browser cookies set "user_pref" "dark_mode"

# 特定 cookie の値を取得
agent-browser cookies get "session_id"

# クリアして初期化
agent-browser cookies clear
agent-browser storage local clear
agent-browser storage session clear
```

## Example 15: read で Chrome 起動なしに記事/ドキュメントを取得

`read` は Chrome を起動せず URL を取得し、エージェント可読なテキスト (markdown) を返す。軽量な情報収集に最適。

```bash
# URL を markdown として取得
agent-browser read https://example.com/blog/article

# 見出しのアウトラインのみ抽出（全体像の把握に）
agent-browser read https://example.com/docs/guide --outline

# CSS セレクタで本文領域だけにフィルタ
agent-browser read https://example.com/article --filter "main"

# ページが公開する llms.txt を取得（index 一覧 または full 本文）
agent-browser read https://example.com --llms full

# markdown が取れない場合は失敗扱いにする（スクリプト向け）
agent-browser read https://example.com/article --require-md

# JSON で構造化出力
agent-browser read https://example.com/article --json > article.json

# URL 省略でアクティブタブの DOM を読む
agent-browser open https://app.example.com/report
agent-browser read --outline
```

## Example 16: chat で自然言語ワンショット操作

`chat` は自然言語の指示でブラウザを操作する（single-shot）。引数なしで対話 REPL を起動する。

```bash
# 自然言語でワンショット操作
agent-browser chat "検索ボックスに laptop と入力して検索ボタンを押す"

# quiet モード（最終結果のみ）
agent-browser chat "ログインフォームを送信して" -q

# 詳細ログ付き
agent-browser chat "カートに最初の商品を追加して" -v

# 使用モデルを指定
agent-browser chat "価格一覧を抽出して" --model gpt-4o

# JSON で結果を受け取る
agent-browser chat "見出しをすべて取得して" --json

# 対話 REPL（引数なし）
agent-browser chat

# AI Gateway 経由の場合は AI_GATEWAY_API_KEY を使う
export AI_GATEWAY_API_KEY="..."
agent-browser chat "ページを要約して"
```

## Example 17: batch で複数コマンドを一括実行

`batch` は複数コマンドを連続実行する。`--bail` で失敗時に中断、stdin に JSON 配列を渡して `--json` で受け取ることもできる。

```bash
# 複数コマンドをまとめて実行
agent-browser batch \
  "open https://app.example.com/login" \
  "fill @e1 user@example.com" \
  "fill @e2 secret" \
  "click @e3" \
  "wait --url **/dashboard"

# 失敗時に即中断（フェイルファスト）
agent-browser batch --bail \
  "open https://app.example.com" \
  "click @e1" \
  "wait --text Done"

# stdin から JSON 配列を渡し、結果を JSON で受け取る
echo '["open https://example.com", "snapshot", "get title"]' \
  | agent-browser batch --json
```

## Example 18: auth Vault + state でログイン状態を暗号化保存・再利用

`auth` は暗号化された認証 Vault を提供する。`AGENT_BROWSER_ENCRYPTION_KEY`（AES-256-GCM 用の 64 文字 hex キー）で保存内容を暗号化する。

```bash
# 暗号化キーを用意（64 文字の hex）
export AGENT_BROWSER_ENCRYPTION_KEY="$(openssl rand -hex 32)"

# ログイン画面を指定して認証状態を Vault に保存
agent-browser auth save myapp --url https://app.example.com/login

# 後で: Vault からログイン状態をロードして再利用
agent-browser auth login myapp
agent-browser open https://app.example.com/dashboard
agent-browser snapshot
# すでにログイン済み

# state コマンドでストレージ状態を管理
agent-browser state list                    # 保存済み状態を一覧
agent-browser state save prod-session.json  # 現在の状態を保存
agent-browser state show prod-session.json  # 内容を確認
agent-browser state load prod-session.json  # 復元

# 環境変数で起動時に状態をロード
AGENT_BROWSER_STATE=prod-session.json agent-browser open https://app.example.com
```

## Example 19: mcp サーバーモードで起動

`mcp` は stdio で MCP サーバーを起動する。`--tools` でツールプロファイルを指定する（既定 core）。プロファイル: core / network / state / debug / tabs / react / mobile / all。

```bash
# core ツールプロファイルで MCP サーバー起動（既定）
agent-browser mcp

# 全ツールを公開
agent-browser mcp --tools all

# 必要なプロファイルだけ組み合わせて公開
agent-browser mcp --tools core,network,react
```

MCP クライアント（例: Claude Code）の設定では、コマンドに `agent-browser`、引数に `mcp --tools core,network` のように指定して stdio 接続する。

## Example 20: diff / vitals / react による検証・計測

```bash
# --- diff: 状態/ビジュアルの差分比較 ---
agent-browser open https://app.example.com
agent-browser snapshot                       # 変更前のスナップショットを取得
# ... 何らかの操作 ...
agent-browser diff snapshot                  # アクセシビリティツリーの差分
agent-browser diff screenshot                # ビジュアル差分
agent-browser diff url                        # URL の差分

# --- vitals: Web Vitals + hydration メトリクス ---
agent-browser vitals https://example.com
agent-browser vitals https://example.com --json > vitals.json

# --- react: React 解析（要 react-devtools 有効化）---
agent-browser --enable react-devtools open https://react-app.example.com
agent-browser react tree                      # コンポーネントツリー
agent-browser react inspect                    # 選択要素のコンポーネント検査
agent-browser react renders                     # 再レンダー計測
agent-browser react suspense                     # Suspense 境界の状態
```

## 効果的な自動化のための Tips（最新ワークフロー）

1. **デフォルト snapshot で ref を取得** — `snapshot` はアクセシビリティツリーと `ref` を返す。interactive 要素だけに絞るなら `-i`、リンク URL も欲しいなら `--urls` を付ける
2. **アクション後は再 snapshot** — DOM が変わると `@e1` 等の ref は無効になる。操作の前後で取り直す
3. **read で軽量取得** — 単に記事/ドキュメントの本文が欲しいだけなら、Chrome を起動する `open` ではなく `read`（`--outline` / `--filter` / `--llms`）で markdown を軽量取得する
4. **batch で一括実行** — 定型の操作列は `batch`（`--bail` でフェイルファスト・stdin JSON ＋ `--json` も可）にまとめると往復を減らせる
5. **state / auth で再ログイン回避** — 認証済み状態は `state save` / `auth save`（`AGENT_BROWSER_ENCRYPTION_KEY` で暗号化）で永続化し、次回以降は `state load` / `auth login` でログインを省略する
6. **chat で自然言語ワンショット** — セレクタや ref を組み立てにくい曖昧な操作は `chat "<指示>"`（`-q` / `--model` / `--json`）に任せる
7. **wait でネットワーク待機** — ナビゲーションやフォーム送信の後は `wait --load networkidle` や `wait --text` / `wait --js` で安定化する
8. **--json で機械可読出力** — スクリプトに組み込む際は各コマンドの `--json` を使う
9. **--session で並列分離** — 独立した複数ユーザーのテストは `--session` で cookie/storage/認証を分離する
10. **diff / vitals / react で検証** — 状態差分は `diff`、性能は `vitals`、React 内部は `react`（要 `--enable react-devtools`）で確認する
```
