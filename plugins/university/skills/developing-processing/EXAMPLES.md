# Processing スケッチ雛形集（EXAMPLES）

すぐにコピーして使える Processing 4.5.2 のスケッチ雛形を、用途別にまとめる。各例は次の3点をセットで示す。

1. 完全な `.pde` コード（そのままコンパイルが通る）
2. 保存先フォルダ構造（メインタブは必ず `<フォルダ名>/<フォルダ名>.pde`）
3. `processing cli` での compile / run コマンド

## 前提（CLI バイナリと共通ルール）

- CLI バイナリは macOS 既定で `/Applications/Processing.app/Contents/MacOS/Processing`。本ドキュメントでは `$PROCESSING_BIN` として参照する。環境変数で上書きできる。
- Processing 4.4.3 以降では旧 `processing-java` が廃止され、サブコマンド `processing cli`（Java Mode のコマンドライン版）にリネームされた。Web 上に残る `processing-java --run` 等の古い記事はそのまま通用しない。本ドキュメントのコマンドが現行の正しい形である。
- `--build` / `--run` / `--present` / `--export` は **必ず最後の引数**に置く。これより後ろの引数はスケッチ側へ渡る（`PApplet` の `args` フィールドで参照可能）。
- スケッチは「フォルダ」が単位。メインタブのファイル名は必ずフォルダ名と一致させる（例: `my_sketch/my_sketch.pde`）。一致しないと CLI がスケッチを認識しない。
- 素材（画像・フォント等）は `data/` サブフォルダに置き、`.jar` は `code/` サブフォルダに置く。
- 出力フォルダ（`--output`）はスケッチフォルダと同一にできない。既存の出力フォルダを再利用するときは `--force` を付ける。

共通の環境変数定義（以降の bash 例はこれを前提とする）。

```bash
export PROCESSING_BIN="${PROCESSING_BIN:-/Applications/Processing.app/Contents/MacOS/Processing}"
# macOS で GNU timeout を使う場合（Homebrew の coreutils を導入済みの想定）
export TIMEOUT_BIN="${TIMEOUT_BIN:-/opt/homebrew/bin/timeout}"
```

---

## 例1: 最小スケッチ（静止画・noLoop）

一度だけ描画して止める静止画スケッチ。`noLoop()` で `draw()` のループを止め、CPU を無駄に回さない。

保存先フォルダ構造。

```text
static_circle/
└── static_circle.pde
```

```java
void setup() {
  size(400, 400);
  noLoop();            // draw() を1回だけ実行してループを止める
}

void draw() {
  background(30);
  noStroke();
  fill(255, 180, 0);
  ellipse(width / 2, height / 2, 200, 200);

  fill(255);
  textAlign(CENTER, CENTER);
  textSize(20);
  text("static sketch", width / 2, height / 2);
}
```

compile / run コマンド。

```bash
# コンパイルのみ（ウィンドウを開かない・ヘッドレス検証）
"$PROCESSING_BIN" cli \
  --sketch="$PWD/static_circle" \
  --output="$PWD/static_circle/build" \
  --force \
  --build

# 実行（ウィンドウを開く）
"$PROCESSING_BIN" cli \
  --sketch="$PWD/static_circle" \
  --output="$PWD/static_circle/build" \
  --force \
  --run
```

---

## 例2: アニメーションループ（draw で動かす）

`draw()` が既定で毎フレーム呼ばれる性質を使い、`frameCount` を基準に角度を進めて回転させる。`frameRate()` で更新頻度を制御する。

保存先フォルダ構造。

```text
spinning_square/
└── spinning_square.pde
```

```java
float angle = 0.0;

void setup() {
  size(400, 400);
  frameRate(60);       // 1秒あたり60回 draw() を呼ぶ
  rectMode(CENTER);
}

void draw() {
  background(20);

  translate(width / 2, height / 2);
  rotate(angle);

  noStroke();
  fill(0, 200, 255);
  rect(0, 0, 160, 160);

  angle += 0.02;       // 毎フレーム少しずつ回す
  if (angle > TWO_PI) {
    angle -= TWO_PI;
  }
}
```

compile / run コマンド。

```bash
# コンパイル確認
"$PROCESSING_BIN" cli \
  --sketch="$PWD/spinning_square" \
  --output="$PWD/spinning_square/build" \
  --force \
  --build

# 実行（無限ループのため timeout で包む。GNU timeout はタイムアウト時に exit 124）
"$TIMEOUT_BIN" 5 "$PROCESSING_BIN" cli \
  --sketch="$PWD/spinning_square" \
  --output="$PWD/spinning_square/build" \
  --force \
  --run
```

---

## 例3: マウス / キーボード インタラクション

マウス位置に追従する円を描き、`mousePressed()` でクリック点に印を残す。キーボードで色を切り替え、`ESC` 以外のキーも処理する。

保存先フォルダ構造。

```text
interactive_paint/
└── interactive_paint.pde
```

```java
ArrayList<PVector> marks = new ArrayList<PVector>();
color brushColor;

void setup() {
  size(500, 500);
  brushColor = color(255, 100, 100);
  noStroke();
}

void draw() {
  background(15);

  // 過去にクリックした点を描画
  fill(brushColor);
  for (PVector m : marks) {
    ellipse(m.x, m.y, 24, 24);
  }

  // マウス位置に追従するカーソル円
  fill(255, 120);
  ellipse(mouseX, mouseY, 40, 40);

  fill(255);
  textSize(14);
  text("click to stamp / press r g b to change color", 12, 24);
}

void mousePressed() {
  marks.add(new PVector(mouseX, mouseY));
}

void keyPressed() {
  if (key == 'r') {
    brushColor = color(255, 100, 100);
  } else if (key == 'g') {
    brushColor = color(100, 255, 120);
  } else if (key == 'b') {
    brushColor = color(100, 160, 255);
  } else if (keyCode == UP) {
    marks.clear();        // 上キーで全消去
  }
}
```

compile / run コマンド。

```bash
# コンパイル確認
"$PROCESSING_BIN" cli \
  --sketch="$PWD/interactive_paint" \
  --output="$PWD/interactive_paint/build" \
  --force \
  --build

# 実行（操作確認のため少し長めに包む）
"$TIMEOUT_BIN" 10 "$PROCESSING_BIN" cli \
  --sketch="$PWD/interactive_paint" \
  --output="$PWD/interactive_paint/build" \
  --force \
  --run
```

---

## 例4: P3D を使った3D（box / sphere / lights / rotate）

`size(w, h, P3D)` で OpenGL 3D レンダラを指定する。照明を当て、座標変換で立体を配置・回転させる。

保存先フォルダ構造。

```text
rotating_solids/
└── rotating_solids.pde
```

```java
float ry = 0.0;

void setup() {
  size(600, 600, P3D);
  noStroke();
}

void draw() {
  background(10);

  // ライティング
  ambientLight(60, 60, 60);
  directionalLight(255, 255, 255, -0.5, 0.5, -1);
  pointLight(120, 180, 255, width / 2, height / 2, 300);

  // 左に立方体
  pushMatrix();
  translate(width * 0.33, height / 2, 0);
  rotateY(ry);
  rotateX(ry * 0.5);
  fill(255, 150, 0);
  box(140);
  popMatrix();

  // 右に球
  pushMatrix();
  translate(width * 0.66, height / 2, 0);
  rotateY(-ry);
  fill(0, 200, 255);
  sphereDetail(32);
  sphere(90);
  popMatrix();

  ry += 0.01;
}
```

compile / run コマンド。

```bash
# コンパイル確認
"$PROCESSING_BIN" cli \
  --sketch="$PWD/rotating_solids" \
  --output="$PWD/rotating_solids/build" \
  --force \
  --build

# 実行
"$TIMEOUT_BIN" 6 "$PROCESSING_BIN" cli \
  --sketch="$PWD/rotating_solids" \
  --output="$PWD/rotating_solids/build" \
  --force \
  --run
```

---

## 例5: data/ から画像読み込み（loadImage / image）

画像素材は `data/` サブフォルダに置く。`loadImage()` で読み込み、`image()` で描画する。`imageMode()` と `tint()` の使い方も示す。

保存先フォルダ構造（`photo.jpg` は実在する画像に置き換える）。

```text
image_viewer/
├── image_viewer.pde
└── data/
    └── photo.jpg
```

```java
PImage photo;

void setup() {
  size(640, 480);
  photo = loadImage("photo.jpg");   // data/ 配下のパスを相対指定
  imageMode(CENTER);
}

void draw() {
  background(0);

  if (photo != null) {
    // ウィンドウに収まるよう縦横比を保って縮小
    float scale = min(width / (float) photo.width, height / (float) photo.height);
    float w = photo.width * scale;
    float h = photo.height * scale;

    // マウスX位置で色味（tint）を変える
    float t = map(mouseX, 0, width, 100, 255);
    tint(255, t, t);
    image(photo, width / 2, height / 2, w, h);
    noTint();
  } else {
    fill(255);
    textAlign(CENTER, CENTER);
    text("image not found: data/photo.jpg", width / 2, height / 2);
  }
}
```

compile / run コマンド。

```bash
# 事前に data/ へ画像を配置しておく
mkdir -p "$PWD/image_viewer/data"
# cp /path/to/your/photo.jpg "$PWD/image_viewer/data/photo.jpg"

# コンパイル確認（コードのみ。画像が無くてもコンパイルは通る）
"$PROCESSING_BIN" cli \
  --sketch="$PWD/image_viewer" \
  --output="$PWD/image_viewer/build" \
  --force \
  --build

# 実行
"$TIMEOUT_BIN" 8 "$PROCESSING_BIN" cli \
  --sketch="$PWD/image_viewer" \
  --output="$PWD/image_viewer/build" \
  --force \
  --run
```

---

## 例6: ジェネラティブ / データ可視化パターン（random / noise / map / PVector）

Perlin ノイズで滑らかに動く粒子群を描く。`noise()` の連続性、`map()` による値域変換、`PVector` によるベクトル演算、`random()` による初期化を組み合わせる。

保存先フォルダ構造。

```text
noise_field/
└── noise_field.pde
```

```java
int particleCount = 300;
PVector[] positions;
float noiseScale = 0.005;
float t = 0.0;

void setup() {
  size(700, 700);
  positions = new PVector[particleCount];
  randomSeed(42);                 // 再現性のためシードを固定
  noiseSeed(42);
  for (int i = 0; i < particleCount; i++) {
    positions[i] = new PVector(random(width), random(height));
  }
  background(10);
}

void draw() {
  // 残像を残すためうっすら塗り重ねる
  noStroke();
  fill(10, 18);
  rect(0, 0, width, height);

  for (int i = 0; i < particleCount; i++) {
    PVector p = positions[i];

    // ノイズから流れ場の角度を作る
    float n = noise(p.x * noiseScale, p.y * noiseScale, t);
    float angle = map(n, 0, 1, 0, TWO_PI * 2);
    PVector velocity = PVector.fromAngle(angle);
    velocity.mult(1.5);
    p.add(velocity);

    // 画面外に出たら反対側へ巻き戻す
    if (p.x < 0) p.x += width;
    if (p.x > width) p.x -= width;
    if (p.y < 0) p.y += height;
    if (p.y > height) p.y -= height;

    float hueValue = map(i, 0, particleCount, 120, 255);
    stroke(hueValue, 180, 255, 200);
    strokeWeight(2);
    point(p.x, p.y);
  }

  t += 0.005;
}
```

compile / run コマンド。

```bash
# コンパイル確認
"$PROCESSING_BIN" cli \
  --sketch="$PWD/noise_field" \
  --output="$PWD/noise_field/build" \
  --force \
  --build

# 実行
"$TIMEOUT_BIN" 8 "$PROCESSING_BIN" cli \
  --sketch="$PWD/noise_field" \
  --output="$PWD/noise_field/build" \
  --force \
  --run
```

---

## 例7: CI 検証用 instrumented sketch（println で期待値出力 → frameCount で exit）

自動検証向けの「計測スケッチ」。`println()` で期待値を stdout に出力し、`frameCount` が一定に達したら `exit()` を呼んでクリーンに終了する。これを `--run` + `timeout` で実行し、stdout を `grep` して合否を判定する。

ポイント。

- スケッチ内で `exit()` を呼ぶと、その後 `Finished.` が出て exit 0 で終了する。
- 実行時例外はプロセスを終了させない（ウィンドウが残る）ため、`--run` は必ず `timeout` で包む。
- `--build` の出力を `head` 等へパイプすると `$?` がパイプ末尾コマンドの終了コードに化ける。検証では `set -o pipefail` を使うか、パイプせずに exit code を直接見るか、成果物（`.class`）の有無で判定する。

保存先フォルダ構造。

```text
ci_probe/
└── ci_probe.pde
```

```java
int sum = 0;

void setup() {
  size(200, 200);
  println("PROBE_START");
}

void draw() {
  background(0);

  // 何らかのロジックを実行し、期待値を出力する
  sum += frameCount;

  if (frameCount == 5) {
    int expected = 1 + 2 + 3 + 4 + 5;   // = 15
    println("PROBE_SUM=" + sum);
    println("PROBE_EXPECTED=" + expected);
    if (sum == expected) {
      println("PROBE_RESULT=PASS");
    } else {
      println("PROBE_RESULT=FAIL");
    }
    println("PROBE_END");
    exit();        // クリーンに終了。この後 Finished. が出て exit 0
  }
}
```

実行して stdout を検証する流れ。

```bash
# 出力を確実に捕捉するため、stdout/stderr をファイルへ落とす
OUT="$PWD/ci_probe/run.out"
ERR="$PWD/ci_probe/run.err"

"$TIMEOUT_BIN" 30 "$PROCESSING_BIN" cli \
  --sketch="$PWD/ci_probe" \
  --output="$PWD/ci_probe/build" \
  --force \
  --run \
  > "$OUT" 2> "$ERR"
RUN_RC=$?

echo "run exit code: $RUN_RC"   # timeout 発火時は 124

# 期待値が出力されているか grep で検証（/usr/bin/grep を直呼びして RTK ラッパー化を避ける）
if /usr/bin/grep -q "PROBE_RESULT=PASS" "$OUT"; then
  echo "VERIFY: PASS"
else
  echo "VERIFY: FAIL"
  echo "--- stdout ---"; cat "$OUT"
  echo "--- stderr ---"; cat "$ERR"
fi

# 実行時例外が出ていないかも確認（*.pde:l:c: 形式のエラー行を探す）
if /usr/bin/grep -nE "\.pde:[0-9]+:[0-9]+:" "$ERR"; then
  echo "VERIFY: runtime error detected (see stderr above)"
fi
```

期待される正常時の挙動。

- stdout に `PROBE_START` / `PROBE_SUM=15` / `PROBE_EXPECTED=15` / `PROBE_RESULT=PASS` / `PROBE_END` が並び、最後に `Finished.` が出る。
- `RUN_RC` は 0（`timeout` 内に `exit()` で正常終了したため。124 ならタイムアウトで、`exit()` に到達していない）。

---

## 例8: ヘッドレス検証スニペット（--build だけでコンパイル可否を確認）

ウィンドウを開かずに「コンパイルが通るか」だけを確認する最小手順。CI やプリコミット検証に向く。判定は黄金三点照合で行う。

判定の3点。

1. exit code（0 = 成功 / 1 = コンパイル失敗。ただしパイプすると化けるので注意）。
2. stderr に `*.pde:開始行:開始列:終了行:終了列: メッセージ` 形式のエラー行があるか。
3. 成功時のみ `<sketch>.class` が出力フォルダに生成される。

保存先フォルダ構造（検証対象は任意のスケッチ。ここでは例1を流用）。

```text
static_circle/
└── static_circle.pde
```

ヘッドレス・コンパイル検証スクリプト。

```bash
SKETCH_DIR="$PWD/static_circle"
SKETCH_NAME="static_circle"
BUILD_DIR="$SKETCH_DIR/build"

# パイプを使わず exit code を直接受ける（パイプ罠を避ける）
"$PROCESSING_BIN" cli \
  --sketch="$SKETCH_DIR" \
  --output="$BUILD_DIR" \
  --force \
  --build \
  > "$SKETCH_DIR/build.out" 2> "$SKETCH_DIR/build.err"
BUILD_RC=$?

echo "build exit code: $BUILD_RC"   # 0=成功 / 1=コンパイル失敗

# (1) exit code と (3) .class 生成の有無で二重に判定する
if [ "$BUILD_RC" -eq 0 ] && [ -f "$BUILD_DIR/$SKETCH_NAME.class" ]; then
  echo "COMPILE: OK ($SKETCH_NAME.class generated)"
else
  echo "COMPILE: FAILED"
  # (2) stderr のエラー行を表示（*.pde:l:c:l:c: 形式）
  /usr/bin/grep -nE "\.pde:[0-9]+:[0-9]+:[0-9]+:[0-9]+:" "$SKETCH_DIR/build.err" || cat "$SKETCH_DIR/build.err"
fi

# 参考: 成功時はプリプロセス後の Java ソースが build/source/<sketch>.java に生成される
ls -1 "$BUILD_DIR" 2>/dev/null
ls -1 "$BUILD_DIR/source" 2>/dev/null
```

コンパイル失敗時の stderr の例（形式の参考）。

```text
bad_sketch.pde:3:0:3:0: The function undefinedFunctionCall(int) does not exist.
```

このとき exit code は 1、`.class` は生成されない。`set -o pipefail` を使わずにパイプへ流すと exit code が末尾コマンドのものに化けるため、上記のようにパイプせず直接受けるか `.class` の有無で判定するのが確実である。
