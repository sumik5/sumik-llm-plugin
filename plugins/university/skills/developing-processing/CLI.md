# Processing 4 CLI 完全リファレンス

Processing 4.5.2 のコマンドラインインターフェイス（Java Mode の CLI 版）の実機検証済みリファレンス。スケッチのヘッドレスなコンパイル・実行・整形・書き出しを CLI から行うための実務ガイド。

> 本ドキュメントの数値・挙動・フラグはすべて Processing 4.5.2（`processing-4.5.2-1313`）での実測に基づく。記載のないフラグは存在を仮定しないこと。

---

## バイナリパス

| 項目 | 値 |
|------|-----|
| 既定バイナリ（macOS） | `/Applications/Processing.app/Contents/MacOS/Processing` |
| 環境変数による上書き | `PROCESSING_BIN` |

スクリプトでは環境変数を優先し、未設定なら既定パスへフォールバックするのが安全。

```bash
PROCESSING_BIN="${PROCESSING_BIN:-/Applications/Processing.app/Contents/MacOS/Processing}"
"$PROCESSING_BIN" --version
# => processing-4.5.2-1313
```

`processing --version` はバージョン文字列を返し、`processing --help` および `processing cli --help` でヘルプを表示できる。

---

## `processing-java` からの改名（4.4.3+ / PR #1050）

Processing 4.4.3 以降、従来の独立コマンド `processing-java` は廃止され、その機能はトップレベルバイナリのサブコマンド **`processing cli`** に統合・リネームされた（GitHub `processing/processing4` の PR #1050）。

> 🔴 **古い記事に注意**: Web 上で広く見られる `processing-java --sketch=... --run` 形式の解説は 4.4.3 未満のものであり、**現行バージョンではそのまま通用しない**。現行では `processing cli --sketch=... --run` のようにサブコマンド `cli` を介して呼び出す。`processing-java` という名前のバイナリも標準では存在しない前提で記述・検証すること。

旧 → 新の対応例:

| 旧（4.4.3 未満・非推奨） | 新（4.4.3+ / 現行） |
|---------------------------|----------------------|
| `processing-java --sketch=foo --build` | `processing cli --sketch=foo --build` |
| `processing-java --sketch=foo --run` | `processing cli --sketch=foo --run` |
| `processing-java --sketch=foo --export` | `processing cli --sketch=foo --export` |

---

## トップレベル サブコマンド一覧

`processing <subcommand> [options]` の形式。

| サブコマンド | 役割 |
|-------------|------|
| `lsp` | エディタ統合用 Language Server を起動する |
| `cli` | Java Mode のコマンドライン版。スケッチのプリプロセス・コンパイル・実行・書き出しを行う（旧 `processing-java`） |
| `contributions` | ライブラリ・サンプル等のコントリビューション管理 |
| `sketchbook` | スケッチブック（スケッチ一覧）の操作 |
| `sketch` | スケッチ単位のユーティリティ操作（整形など） |

---

## `processing cli` 全フラグ

スケッチのプリプロセス・コンパイル・実行・書き出しを担う中核サブコマンド。

| フラグ | 意味 | 必須 |
|--------|------|------|
| `--sketch=<dir>` | 対象スケッチフォルダ | ✅ 必須 |
| `--output=<dir>` | 出力フォルダ（`--sketch` と同一ディレクトリは指定不可） | 任意 |
| `--force` | 既存の `--output` を削除してから書き込む（output を再利用する際に必須） | 任意 |
| `--build` | プリプロセス + コンパイルのみ。ウィンドウを開かない（ヘッドレス検証向き） | アクション※ |
| `--run` | プリプロセス + コンパイル + 実行。ウィンドウを開く | アクション※ |
| `--present` | 全画面（presentation）で実行 | アクション※ |
| `--export` | アプリケーションとして書き出す | アクション※ |
| `--variant=<v>` | `--export` 用のプラットフォーム / アーキテクチャ指定 | `--export` 時に任意 |
| `--no-java` | `--export` 時に Java ランタイムを埋め込まない | `--export` 時に任意 |

※ アクションフラグ（`--build` / `--run` / `--present` / `--export`）は処理内容を決める末尾フラグ。下記「アクションフラグは必ず最後」を参照。

### 🔴 アクションフラグは必ず最後の引数

`--build` / `--run` / `--present` / `--export` は**必ずコマンドラインの最後**に置く。これらより後ろに書いた引数は Processing 自身のオプションとしては解釈されず、**スケッチ側へ渡され** PApplet の `args` フィールドから参照できる（args passthrough）。

```bash
# args passthrough の例: --run の後ろの "level3" "fast" がスケッチへ渡る
"$PROCESSING_BIN" cli --sketch=my_sketch --output=/tmp/out --force --run level3 fast
# スケッチ内では args[0] == "level3", args[1] == "fast"
```

> PApplet 標準の `main()` オプション（表示位置などの内部オプション）を使いたい場合は、スケッチに独自の `main()` を記述する必要がある。CLI 経由の passthrough はあくまで `args` フィールドへの受け渡しである。

---

## `--export` の variant 一覧

`--export` 時に書き出し対象のプラットフォーム / アーキテクチャを `--variant=<v>` で指定する。

| variant | 対象 |
|---------|------|
| `macos-x86_64` | macOS（Intel / x86_64） |
| `macos-aarch64` | macOS（Apple Silicon / arm64） |
| `windows-amd64` | Windows（x86_64） |
| `linux-amd64` | Linux（x86_64） |
| `linux-arm` | Linux（32bit ARM） |
| `linux-aarch64` | Linux（64bit ARM / arm64） |

`--no-java` を併用すると Java ランタイムを同梱しない（実行側に Java 17 を要求する軽量な書き出し）。

---

## 🔴 コンパイル / 実行の挙動表（実測）

新規の `--output` ディレクトリを使った場合の実測挙動。判定はこの表に厳密に従うこと。

| 状況 | exit code | stdout | stderr | `.class` 生成 | 備考 |
|------|-----------|--------|--------|---------------|------|
| **成功**（`--build`） | `0` | `Finished.` | 空 | あり（`<output>/<sketch>.class`） | `<output>/source/<sketch>.java` にプリプロセス後の Java ソースも生成される |
| **コンパイル失敗**（`--build`） | `1` | 空 | エラー行あり | なし | エラー形式は下記参照 |
| **実行時例外**（`--run`） | プロセスは終了しない（下記参照） | スケッチの出力まで | 例外行あり | （実行フェーズ・該当せず） | ウィンドウが残るため必ず `timeout` で包む |

### コンパイル失敗のエラー形式

stderr に次の形式で出力される（`.class` は生成されない）。

```
<file>.pde:開始行:開始列:終了行:終了列: メッセージ
```

実例:

```
bad_sketch.pde:3:0:3:0: The function undefinedFunctionCall(int) does not exist.
```

`Syntax Error - Missing` セミコロンの指摘なども同様の位置情報付きで出る。

### 実行（`--run`）の挙動

- スケッチ内の `println()` 出力は stdout に出る。
- スケッチ内で `exit()` を呼ぶとクリーンに終了し、その後 `Finished.` が出て exit `0` となる。
- 🔴 **実行時例外はプロセスを終了させない**（描画ウィンドウが残り続ける）。例外は stderr に次の形式で出る。

```
<file>.pde:開始行:開始列:終了行:終了列: ExceptionName: メッセージ
```

実例:

```
ArrayIndexOutOfBoundsException: Index 5 out of bounds for length 2
```

### 検証の黄金三点照合

成否は次の 3 点で確実に判定する。

1. **exit code** — `0` = 成功 / `1` = コンパイル失敗（ただし後述のパイプ罠で化ける）。
2. **stderr の `*.pde:l:c:` 形式のエラー行**の有無。
3. **成功時のみ** `<output>/<sketch>.class` が生成されているか。

---

## 🔴 パイプ罠と `timeout` 必須

### パイプ罠（exit code が化ける）

`--build` の出力を `head` などへパイプすると、`$?` がパイプ末尾コマンドの終了コードに化け、Processing 本来の exit code（`1` 等）が隠れてしまう。検証時は次のいずれかで回避する。

- `set -o pipefail` を使う。
- パイプせず exit code を直接読む。
- `.class` 成果物の有無で判定する（最も確実）。

```bash
# NG: head が exit 0 を返し、ビルド失敗(1)が隠れる
"$PROCESSING_BIN" cli --sketch=bad --output=/tmp/o --force --build | head   # $? が常に 0 になりうる

# OK: pipefail で本来の exit code を保持
set -o pipefail
"$PROCESSING_BIN" cli --sketch=bad --output=/tmp/o --force --build | head
echo "exit=$?"
```

### `timeout` 必須（`--run`）

`--run` はウィンドウを開き、実行時例外が起きてもプロセスが終了しないため、**必ず `timeout` で包む**こと。

- GNU `timeout` はタイムアウト時に exit `124` を返す。
- macOS では coreutils 同梱の `/opt/homebrew/bin/timeout`（`gtimeout` 実体）が使える。

```bash
TIMEOUT_BIN="$( [ -x /opt/homebrew/bin/timeout ] && echo /opt/homebrew/bin/timeout || command -v timeout )"
"$TIMEOUT_BIN" 10 "$PROCESSING_BIN" cli --sketch=my_sketch --output=/tmp/out --force --run
rc=$?
# rc == 124 ならタイムアウト（ウィンドウが残って自然終了しなかった）
```

---

## スケッチ構造

- スケッチの単位は**フォルダ**。メインタブのファイルは必ず `<フォルダ名>.pde` でなければ CLI が認識しない（例: `my_sketch/my_sketch.pde`）。
- フォルダ内の追加 `.pde` は「タブ」として連結される。
- `data/` サブフォルダに画像・フォント等の素材を置き、`loadImage()` などで読み込む。
- `code/` サブフォルダに `.jar` を配置できる。

```
my_sketch/
├── my_sketch.pde      # メインタブ（フォルダ名と一致・必須）
├── helpers.pde        # 追加タブ（連結される）
├── data/              # 素材（画像・フォント等）
└── code/              # .jar ライブラリ
```

---

## その他のサブコマンド

### `processing sketch format <file>`

`.pde` を整形する軽量フォーマッタ。波括弧のインデントとカンマ後のスペースを整える。既定では整形結果を **stdout に出力**し、`-i`（`--inplace`）でファイルを上書きする。

```bash
# stdout へ整形結果を出力（元ファイルは変更しない）
"$PROCESSING_BIN" sketch format my_sketch/my_sketch.pde

# ファイルをその場で上書き
"$PROCESSING_BIN" sketch format -i my_sketch/my_sketch.pde
"$PROCESSING_BIN" sketch format --inplace my_sketch/my_sketch.pde
```

### `processing sketchbook list`

スケッチブック内のスケッチ一覧を JSON で返す。スケッチブックが未設定の場合は `[ null ]` を返す。

```bash
"$PROCESSING_BIN" sketchbook list
# 未設定時: [ null ]
```

### `processing contributions examples`

サンプル（examples）コントリビューションを管理する。

```bash
"$PROCESSING_BIN" contributions examples
```

### `processing lsp`

エディタ統合用の Language Server を起動する。エディタ（補完・診断など）からの利用が前提。

```bash
"$PROCESSING_BIN" lsp
```

---

## 代表的な呼び出し例

### ① ヘッドレスにコンパイルのみ（CI 検証向き）

```bash
PROCESSING_BIN="${PROCESSING_BIN:-/Applications/Processing.app/Contents/MacOS/Processing}"

"$PROCESSING_BIN" cli \
  --sketch=my_sketch \
  --output=/tmp/my_sketch_out \
  --force \
  --build
# 成功: exit 0 / stdout "Finished." / /tmp/my_sketch_out/my_sketch.class 生成
```

### ② 実行（必ず timeout で包む）

```bash
PROCESSING_BIN="${PROCESSING_BIN:-/Applications/Processing.app/Contents/MacOS/Processing}"
TIMEOUT_BIN="$( [ -x /opt/homebrew/bin/timeout ] && echo /opt/homebrew/bin/timeout || command -v timeout )"

"$TIMEOUT_BIN" 10 "$PROCESSING_BIN" cli \
  --sketch=my_sketch \
  --output=/tmp/my_sketch_out \
  --force \
  --run
rc=$?
[ "$rc" = "124" ] && echo "timed out (window stayed open)"
```

### ③ 整形（その場で上書き）

```bash
PROCESSING_BIN="${PROCESSING_BIN:-/Applications/Processing.app/Contents/MacOS/Processing}"

"$PROCESSING_BIN" sketch format -i my_sketch/my_sketch.pde
```

### ④ アプリケーションとして書き出し（Apple Silicon / Java 同梱なし）

```bash
PROCESSING_BIN="${PROCESSING_BIN:-/Applications/Processing.app/Contents/MacOS/Processing}"

"$PROCESSING_BIN" cli \
  --sketch=my_sketch \
  --output=/tmp/my_sketch_app \
  --force \
  --variant=macos-aarch64 \
  --no-java \
  --export
```

### ⑤ ビルドの成否を `.class` で確実に判定（パイプ罠回避）

```bash
PROCESSING_BIN="${PROCESSING_BIN:-/Applications/Processing.app/Contents/MacOS/Processing}"
OUT=/tmp/my_sketch_out

"$PROCESSING_BIN" cli --sketch=my_sketch --output="$OUT" --force --build
if [ -f "$OUT/my_sketch.class" ]; then
  echo "BUILD OK"
else
  echo "BUILD FAILED"   # stderr の *.pde:l:c: 形式エラー行を確認する
fi
```

---

## 検証チェックリスト

CLI からスケッチを扱う際の確認項目。

- [ ] メインタブが `<フォルダ名>.pde` になっているか。
- [ ] `--output` が `--sketch` と別ディレクトリか（同一は不可）。
- [ ] 既存 output を再利用するなら `--force` を付けたか。
- [ ] アクションフラグ（`--build` / `--run` / `--present` / `--export`）を末尾に置いたか。
- [ ] `--run` を `timeout` で包んだか（例外でプロセスが残るため）。
- [ ] exit code をパイプで化けさせていないか（`pipefail` か `.class` 判定）。
- [ ] `--export` で正しい `--variant` を指定したか。
