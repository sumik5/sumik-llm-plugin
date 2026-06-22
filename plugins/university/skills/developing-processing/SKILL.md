---
name: developing-processing
description: >-
  Processing (Java Mode) のスケッチ開発と、Processing 4 CLI(processing cli)による自動コンパイル・実行・検証ループ。
  Use when 大学等で .pde スケッチを書く / Processing でビジュアル・インタラクティブ作品やジェネラティブアート・データ可視化を作る / 作成したスケッチをコマンドラインで自動コンパイル(--build)・実行(--run)して検証したいとき。
  補足トリガー: .pde ファイル, Processing.app, processing cli, sketch, setup()/draw(), creative coding。
  詳細は CLI.md(CLI完全リファレンス) / REFERENCE.md(言語API) / LIBRARIES.md(ライブラリ) / EXAMPLES.md(スケッチ雛形と検証例) / scripts/verify-sketch.sh(検証ヘルパー) を参照。
---

## 1. このスキルは何か / いつ使うか

Processing は Java を基盤とするクリエイティブコーディング環境であり、`setup()` と `draw()` の 2 関数を中心に、図形・色・座標変換・入力イベントを宣言的に書くだけでビジュアル作品を作れる。`.pde` ファイル群を「スケッチ」と呼び、ジェネラティブアート、データ可視化、インタラクティブ作品、教育用デモなどに広く使われる。

このスキルは次のときに使う。

- 大学の課題等で `.pde` スケッチを書く / 読む / 直す
- ジェネラティブアート・データ可視化・インタラクティブ作品を Processing で作る
- 作ったスケッチを **コマンドラインで自動コンパイル・実行して検証** したい（GUI エディタを開かず、エージェントが書いて即検証するループ）

Processing 4 は Java 17 上で動作し、Apple Silicon(aarch64) / Intel / Raspberry Pi ARM に対応する。レンダラは既定の JAVA2D のほか P2D / P3D(OpenGL) / PDF / SVG / FX2D(任意ライブラリ) を `size(w, h, P3D)` のように選べる。

---

## 2. 🔴 CLI 自動コンパイル・実行・検証ワークフロー（最重要）

Processing 4.4.3 以降、旧来の `processing-java` は廃止され、**`processing cli`**（Java Mode のコマンドライン版）にリネームされた。Web 上に残る `processing-java --run ...` 等の古い記事はそのまま通用しない。必ず `processing cli` を使う。

バイナリの既定パスは下記。環境変数 `PROCESSING_BIN` で上書きできる。

```bash
PROCESSING_BIN="${PROCESSING_BIN:-/Applications/Processing.app/Contents/MacOS/Processing}"
```

### 基本形

```bash
# コンパイルのみ（ウィンドウを開かない・ヘッドレス検証向き）
"$PROCESSING_BIN" cli --sketch=/path/to/my_sketch --output=/path/to/out --force --build

# コンパイル + 実行（ウィンドウを開く）
"$PROCESSING_BIN" cli --sketch=/path/to/my_sketch --output=/path/to/out --force --run
```

主なオプション（詳細は `CLI.md`）。

| オプション | 意味 |
|-----------|------|
| `--sketch=<dir>` | スケッチフォルダ（**必須**） |
| `--output=<dir>` | 出力フォルダ（任意・sketch と同一ディレクトリは不可） |
| `--force` | 既存 output を消してから書く（同じ output を再利用するとき必須） |
| `--build` | プリプロセス + コンパイルのみ。ウィンドウを開かない |
| `--run` | プリプロセス + コンパイル + 実行。ウィンドウを開く |
| `--present` | 全画面（presentation）で実行 |
| `--export` | アプリケーションとして書き出し |

> 🔴 `--build` / `--run` / `--present` / `--export` は **必ず最後の引数**。これより後ろの引数はスケッチ側へ渡り、`PApplet` の `args` フィールドで参照できる。

### 🔴 スケッチ = フォルダ / メインタブ名の制約

スケッチの単位は **フォルダ** である。メインタブのファイルは **`<フォルダ名>.pde`** という名前でなければ CLI が認識しない。

```text
my_sketch/
├── my_sketch.pde        ← メインタブ。フォルダ名と完全一致が必須
├── Particle.pde         ← 追加 .pde は「タブ」として連結される
├── data/                ← 画像・フォント等の素材（loadImage 等で読む）
└── code/                ← 追加 .jar を置ける
```

フォルダ名とメインタブ名が食い違うと、コンパイル以前にスケッチとして読み込めない。新規作成時はまず `mkdir my_sketch && touch my_sketch/my_sketch.pde` の対応を守る。

---

## 3. 検証の黄金三点照合と 2 つの罠

`--build` / `--run` の成否は、**3 つの独立した証拠の照合**で確実に判定する。1 つの証拠（exit code だけ等）に頼らない。

| 照合点 | 成功時 | 失敗時 |
|--------|--------|--------|
| (1) exit code | `0` | コンパイル失敗は `1`（ただしパイプで化ける→罠①） |
| (2) stderr のエラー行 | 空 | `<file>.pde:開始行:開始列:終了行:終了列: メッセージ` 形式の行が出る |
| (3) `.class` 成果物 | `output/<sketch>.class` が生成される | `.class` は生成されない |

成功時は stdout に `Finished.` が出て、`output/source/<sketch>.java` にプリプロセス後の Java ソースが残る。コンパイル失敗の stderr 実例: `bad_sketch.pde:3:0:3:0: The function undefinedFunctionCall(int) does not exist.` や `Syntax Error - Missing セミコロン` の指摘。

### 🔴 罠①: パイプで `$?` が化ける

`--build` の出力を `head` 等へパイプすると、`$?` がパイプ末尾コマンドの終了コードに化け、本当の exit code が隠れる。対策は次のいずれか。

- パイプせず exit code を直接見る
- `set -o pipefail` を使う
- exit code に頼らず **`.class` 成果物の有無**で判定する（最も堅牢）

### 🔴 罠②: 実行時例外はプロセスを終わらせない

`--run` で実行時例外が起きても、**ウィンドウは残りプロセスは終了しない**。例外は stderr に `<file>.pde:l:c:l:c: ExceptionName: メッセージ` 形式で出る（例: `ArrayIndexOutOfBoundsException: Index 5 out of bounds for length 2`）。よって `--run` は **必ず `timeout` で包む**。

```bash
# GNU timeout はタイムアウト時に exit 124 を返す。macOS では gtimeout を使う
/opt/homebrew/bin/timeout 10 "$PROCESSING_BIN" cli --sketch=... --output=... --force --run
```

---

## 4. 推奨運用ループ

1. **スケッチ作成**: `my_sketch/my_sketch.pde` を書く（フォルダ名 = メインタブ名）。
2. **必ずコンパイル検証**: `verify-sketch.sh build` で `--build` を回し、黄金三点照合で成否を確認する。**実行時挙動の確認より先に、まずコンパイルが通ることを保証する**。
3. **必要なら実行時検証**: 動作を確かめたいときは、`println()` で内部状態を出力し、検証が済んだら `exit()` を呼んでクリーンに終了する instrumented sketch を用意し、`verify-sketch.sh run` で実行する（`timeout` で包む）。`exit()` を呼ぶと `Finished.` が出て exit 0 になる。

`scripts/verify-sketch.sh`（このスキルディレクトリ内・`PROCESSING_BIN` で binary 上書き可）の使い方。

```bash
# 例1: コンパイルのみ検証（ヘッドレス・最頻用）。.class 生成有無で成否を判定
scripts/verify-sketch.sh build /path/to/my_sketch

# 例2: タイムアウト付きで実行時検証（println 出力を確認・既定 20 秒で打ち切り）
scripts/verify-sketch.sh run /path/to/my_sketch

# 例3: 別タイムアウトは位置引数（run <dir> [秒]）、別バイナリは PROCESSING_BIN 環境変数で指定
PROCESSING_BIN=/opt/Processing/Processing scripts/verify-sketch.sh run /path/to/my_sketch 30
```

スクリプトは内部で `--force` 付き一時 output を用い、黄金三点照合（exit code / stderr のエラー行 / `.class` 成果物）を機械的に行って成否を返す。詳細な引数仕様は `EXAMPLES.md` を参照。

---

## 5. 最小スケッチの雛形

`my_sketch/my_sketch.pde`（フォルダ名とファイル名が一致していること）。

```java
void setup() {
  size(640, 360);      // ウィンドウサイズ。settings() でも可
  background(20);
  noStroke();
}

void draw() {
  fill(255, 120, 0, 40);
  float r = 20 + 30 * sin(frameCount * 0.05);
  ellipse(mouseX, mouseY, r, r);   // マウス位置に円を描く
}
```

より多くの雛形（インタラクティブ・ジェネラティブ・データ可視化・3D・instrumented 検証用）は `EXAMPLES.md` を参照。言語 API の網羅は `REFERENCE.md`、同梱/追加ライブラリは `LIBRARIES.md`。

---

## 6. リファレンス早見表

| ファイル | 内容 |
|---------|------|
| `CLI.md` | `processing cli` 完全リファレンス（全サブコマンド・全オプション・export/variant・format/sketchbook/lsp・終了コードとエラー形式） |
| `REFERENCE.md` | 言語 API（Structure / Environment / Shape 2D・3D / Color / Transform / Math / PVector / Input / Typography / Image / Data・IO / データ構造） |
| `LIBRARIES.md` | 同梱ライブラリ（PDF/Network/Serial/DXF）と別途導入が必要なライブラリ（Video/Sound/FX2D）、Library Manager・libraries/ 配置 |
| `EXAMPLES.md` | スケッチ雛形集と検証例（コンパイル成功/失敗・実行時例外・instrumented sketch・三点照合の実演） |
| `scripts/verify-sketch.sh` | 検証ヘルパー（`build`/`run` サブコマンド・`PROCESSING_BIN`/`TIMEOUT` 上書き対応・黄金三点照合を自動実行） |
