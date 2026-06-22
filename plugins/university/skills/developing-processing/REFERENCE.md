# Processing 言語 API カテゴリ別リファレンス

Processing 4 の言語 API をカテゴリ別にまとめたリファレンス。各表は「関数 / 簡潔な説明」で構成し、主要カテゴリには最小例を添える。関数名・定数名は公式の表記に従って verbatim で記載している。

> 一次情報: 公式リファレンス <https://processing.org/reference> を参照すること。本ドキュメントは概要把握とコード生成補助のための要約であり、引数の細かい仕様・オーバーロード・戻り値の正確な定義は公式リファレンスで確認する。
>
> スケッチの記述言語は Java をベースとした Processing の方言である。コードブロックは `java` として扱う。

---

## Structure（構造）

スケッチのライフサイクルと描画ループ、実行制御を担う最重要カテゴリ。

| 関数 | 説明 |
|------|------|
| `setup()` | 起動時に一度だけ実行される初期化関数 |
| `draw()` | フレームごとに繰り返し実行される描画関数 |
| `settings()` | `size()` / `fullScreen()` 等を確定するための先行フック（高度な用途） |
| `exit()` | スケッチを終了する |
| `noLoop()` | `draw()` の繰り返し実行を停止する |
| `loop()` | `noLoop()` で止めた `draw()` の繰り返しを再開する |
| `redraw()` | `draw()` を一度だけ実行する |
| `push()` | 描画スタイルと座標変換をまとめて退避する |
| `pop()` | `push()` で退避した状態を復元する |
| `thread()` | 指定した関数を別スレッドで非同期実行する |

```java
void setup() {
  size(400, 400);   // ウィンドウサイズを確定（最初に一度だけ）
}
void draw() {
  background(220);  // 毎フレーム背景をクリア
  ellipse(mouseX, mouseY, 40, 40);
}
```

---

## Environment（環境）

ウィンドウサイズ・フレームレート・描画品質・表示状態を制御する。

| 関数 / 変数 | 説明 |
|------|------|
| `size()` | 描画領域の幅・高さ（とレンダラ）を設定する |
| `fullScreen()` | 全画面で実行する |
| `frameRate()` | 目標フレームレート（fps）を設定する |
| `frameCount` | 起動からの経過フレーム数（変数） |
| `width` / `height` | 描画領域の幅・高さ（変数） |
| `displayWidth` / `displayHeight` | ディスプレイ全体の幅・高さ（変数） |
| `pixelDensity()` | 高 DPI 描画の画素密度を設定する |
| `smooth()` / `noSmooth()` | アンチエイリアスを有効化／無効化する |
| `cursor()` / `noCursor()` | マウスカーソルの表示・形状を制御する |
| `settings()` | サイズ・レンダラ確定用の先行フック（Structure と共通） |
| `windowTitle()` | ウィンドウのタイトル文字列を設定する |

```java
void setup() {
  size(600, 400, P2D);
  frameRate(30);    // 30fps を目標に
  pixelDensity(displayDensity());
}
```

---

## Shape（2D）

基本的な 2D 図形の描画と、頂点・PShape による任意形状の構築。

| 関数 | 説明 |
|------|------|
| `point()` | 点を描く |
| `line()` | 線分を描く |
| `rect()` | 矩形を描く |
| `ellipse()` | 楕円を描く |
| `circle()` | 真円を描く |
| `square()` | 正方形を描く |
| `triangle()` | 三角形を描く |
| `quad()` | 四辺形を描く |
| `arc()` | 円弧を描く |
| `rectMode()` | 矩形の座標解釈モードを設定する |
| `ellipseMode()` | 楕円の座標解釈モードを設定する |
| `beginShape()` | 頂点ベースの形状定義を開始する |
| `vertex()` | 頂点を追加する |
| `endShape()` | 頂点ベースの形状定義を終了する（`CLOSE` で閉じる） |
| `curveVertex()` | 曲線（Catmull-Rom）の頂点を追加する |
| `bezierVertex()` | ベジェ曲線の制御点・頂点を追加する |
| `PShape` | 形状を保持・再利用するためのクラス |
| `loadShape()` | SVG / OBJ 等のファイルから `PShape` を読み込む |
| `createShape()` | プログラム的に `PShape` を生成する |

```java
void draw() {
  rectMode(CENTER);
  rect(width/2, height/2, 100, 60);   // 中心基準で矩形

  beginShape();
  vertex(10, 10); vertex(90, 20); vertex(50, 80);
  endShape(CLOSE);                    // 三角形を閉じる
}
```

---

## Shape（3D）

P3D レンダラ上での 3D プリミティブとライティング・カメラ設定。

| 関数 | 説明 |
|------|------|
| `box()` | 直方体を描く |
| `sphere()` | 球を描く |
| `sphereDetail()` | 球のポリゴン分割数（精細さ）を設定する |
| `lights()` | 既定のライティングをまとめて有効化する |
| `ambientLight()` | 環境光を設定する |
| `directionalLight()` | 平行光源を設定する |
| `pointLight()` | 点光源を設定する |
| `spotLight()` | スポットライトを設定する |
| `camera()` | カメラの位置・注視点・上方向を設定する |
| `perspective()` | 透視投影を設定する |
| `ortho()` | 平行投影（正射影）を設定する |

```java
void setup() { size(400, 400, P3D); }
void draw() {
  background(0);
  lights();                 // 既定ライティング
  translate(width/2, height/2);
  rotateY(frameCount * 0.01);
  box(120);                 // 回転する立方体
}
```

---

## Color（色）

塗り・線の色指定、カラーモード、色成分の抽出・補間。

| 関数 | 説明 |
|------|------|
| `background()` | 背景色でクリアする |
| `fill()` | 塗りつぶし色を設定する |
| `noFill()` | 塗りつぶしを無効化する |
| `stroke()` | 線の色を設定する |
| `noStroke()` | 線描画を無効化する |
| `strokeWeight()` | 線の太さを設定する |
| `strokeCap()` | 線端の形状を設定する |
| `strokeJoin()` | 線の接合部の形状を設定する |
| `colorMode()` | RGB / HSB などの色モードと最大値を設定する |
| `color()` | 色値（`color` 型）を生成する |
| `lerpColor()` | 2 色間を線形補間する |
| `red()` / `green()` / `blue()` | 色から R / G / B 成分を取り出す |
| `alpha()` | 色からアルファ成分を取り出す |
| `hue()` / `saturation()` / `brightness()` | 色から色相・彩度・明度を取り出す |

```java
void draw() {
  colorMode(HSB, 360, 100, 100);
  fill(map(mouseX, 0, width, 0, 360), 80, 90);  // 色相をマウスで変化
  noStroke();
  ellipse(width/2, height/2, 200, 200);
}
```

---

## Transform（座標変換）

平行移動・回転・拡大縮小と行列スタックの操作。

| 関数 | 説明 |
|------|------|
| `translate()` | 座標系を平行移動する |
| `rotate()` | 2D 平面で回転する |
| `rotateX()` / `rotateY()` / `rotateZ()` | 各軸まわりに 3D 回転する |
| `scale()` | 座標系を拡大縮小する |
| `shearX()` / `shearY()` | X / Y 方向にせん断変形する |
| `pushMatrix()` | 現在の座標変換行列を退避する |
| `popMatrix()` | 退避した座標変換行列を復元する |
| `resetMatrix()` | 座標変換行列を単位行列に戻す |
| `applyMatrix()` | 任意の行列を現在の変換に乗算する |
| `printMatrix()` | 現在の座標変換行列をコンソールに出力する |

```java
void draw() {
  pushMatrix();
  translate(width/2, height/2);   // 原点を中央へ
  rotate(frameCount * 0.02);      // 回転を適用
  rect(-25, -25, 50, 50);
  popMatrix();                    // 変換を元に戻す
}
```

---

## Math・三角関数・定数

数値演算・補間・乱数（一部）・三角関数と角度ユーティリティ、組み込み定数。

| 関数 / 定数 | 説明 |
|------|------|
| `random()` | 範囲指定の擬似乱数を返す |
| `randomSeed()` | 乱数のシードを設定する |
| `randomGaussian()` | 正規分布に従う乱数を返す |
| `noise()` | Perlin ノイズ値を返す |
| `noiseSeed()` | ノイズのシードを設定する |
| `noiseDetail()` | ノイズのオクターブ・減衰を設定する |
| `map()` | 値をある範囲から別の範囲へ写像する |
| `constrain()` | 値を指定範囲内に丸める |
| `lerp()` | 2 値間を線形補間する |
| `norm()` | 値を範囲に対し 0〜1 に正規化する |
| `dist()` | 2 点間の距離を返す |
| `mag()` | ベクトルの大きさ（原点からの距離）を返す |
| `abs()` | 絶対値を返す |
| `ceil()` / `floor()` / `round()` | 切り上げ／切り捨て／四捨五入する |
| `sq()` / `sqrt()` | 二乗／平方根を返す |
| `pow()` / `exp()` / `log()` | べき乗／指数／自然対数を返す |
| `min()` / `max()` | 最小値／最大値を返す |
| `sin()` / `cos()` / `tan()` | 三角関数（引数はラジアン） |
| `asin()` / `acos()` / `atan()` / `atan2()` | 逆三角関数 |
| `radians()` / `degrees()` | 度数⇔ラジアンを変換する |
| `PI` / `TWO_PI` / `HALF_PI` / `QUARTER_PI` / `TAU` | 円周率関連の定数 |

```java
void draw() {
  float y = height/2 + sin(radians(frameCount * 3)) * 100;  // 正弦波運動
  float x = map(mouseX, 0, width, 50, width - 50);          // 範囲を写像
  ellipse(x, y, 30, 30);
}
```

---

## PVector（ベクトル）

2D / 3D のベクトル演算をカプセル化するクラス。

| メンバ | 説明 |
|------|------|
| `PVector(x, y, z)` | ベクトルを生成するコンストラクタ |
| `add()` | ベクトルを加算する |
| `sub()` | ベクトルを減算する |
| `mult()` | スカラー倍する |
| `div()` | スカラーで除算する |
| `mag()` | 大きさ（長さ）を返す |
| `setMag()` | 大きさを指定値に設定する |
| `normalize()` | 単位ベクトルに正規化する |
| `limit()` | 大きさの上限を制限する |
| `dist()` | 2 ベクトル間の距離を返す |
| `dot()` | 内積を返す |
| `cross()` | 外積を返す |
| `heading()` | 2D での角度（向き）を返す |
| `rotate()` | 2D で回転する |
| `lerp()` | 別ベクトルへ線形補間する |
| `copy()` | ベクトルの複製を返す |
| `fromAngle()` | 角度から単位ベクトルを生成する（静的） |

```java
PVector pos, vel;
void setup() { size(400, 400); pos = new PVector(50, 50); vel = new PVector(2, 1.5); }
void draw() {
  pos.add(vel);                       // 位置に速度を加算
  if (pos.x < 0 || pos.x > width)  vel.x *= -1;
  if (pos.y < 0 || pos.y > height) vel.y *= -1;
  ellipse(pos.x, pos.y, 20, 20);
}
```

---

## Random・Noise（乱数・ノイズ）

手続き的な変化・自然なゆらぎを生む関数群（Math カテゴリにも属するが、生成的表現で多用するため独立して整理）。

| 関数 | 説明 |
|------|------|
| `random()` | 範囲指定の擬似乱数を返す |
| `randomSeed()` | 乱数のシードを固定し再現性を持たせる |
| `randomGaussian()` | 平均 0・標準偏差 1 の正規分布乱数を返す |
| `noise()` | 1〜3 次元の Perlin ノイズ値（0〜1）を返す |
| `noiseSeed()` | ノイズのシードを固定する |
| `noiseDetail()` | ノイズのオクターブ数と各層の寄与を設定する |

```java
float t = 0;
void draw() {
  background(255);
  float y = noise(t) * height;   // なめらかに変動する高さ
  line(0, y, width, y);
  t += 0.01;
}
```

---

## Input（mouse）

マウス座標・ボタン状態とイベントハンドラ。

| 変数 / 関数 | 説明 |
|------|------|
| `mouseX` / `mouseY` | 現在のマウス座標（変数） |
| `pmouseX` / `pmouseY` | 直前フレームのマウス座標（変数） |
| `mousePressed`（変数）/ `mousePressed()`（関数） | ボタン押下状態（変数）／押下時に呼ばれるハンドラ（関数） |
| `mouseButton` | 押されているボタン（`LEFT` / `RIGHT` / `CENTER`） |
| `mouseClicked()` | クリック完了時に呼ばれる |
| `mouseDragged()` | ボタンを押したまま移動した時に呼ばれる |
| `mouseMoved()` | ボタンを押さずに移動した時に呼ばれる |
| `mouseReleased()` | ボタンを離した時に呼ばれる |
| `mouseWheel()` | ホイール操作時に呼ばれる |

```java
void draw() { /* 描画 */ }
void mouseDragged() {
  line(pmouseX, pmouseY, mouseX, mouseY);  // ドラッグで線を描く
}
```

---

## Input（keyboard）

キー入力の状態取得とイベントハンドラ。

| 変数 / 関数 / 定数 | 説明 |
|------|------|
| `key` | 直近に入力された文字（変数） |
| `keyCode` | 特殊キーのコード（変数） |
| `keyPressed`（変数）/ `keyPressed()`（関数） | キー押下状態（変数）／押下時に呼ばれるハンドラ（関数） |
| `keyReleased()` | キーを離した時に呼ばれる |
| `keyTyped()` | 文字入力が確定した時に呼ばれる |
| `UP` / `DOWN` / `LEFT` / `RIGHT` | 方向キーを表す定数 |
| `ENTER` / `ESC` 等 | 特殊キーを表す定数 |

```java
int x = 200;
void draw() { background(220); rect(x, 180, 40, 40); }
void keyPressed() {
  if (keyCode == LEFT)  x -= 10;   // 矢印キーで移動
  if (keyCode == RIGHT) x += 10;
}
```

---

## Typography（タイポグラフィ）

テキスト描画・フォント・整列。

| 関数 / 定数 | 説明 |
|------|------|
| `text()` | 文字列を描画する |
| `textSize()` | 文字サイズを設定する |
| `textAlign()` | 水平・垂直の整列を設定する |
| `textFont()` | 使用するフォントを設定する |
| `createFont()` | システムフォントから `PFont` を生成する |
| `loadFont()` | `.vlw` フォントファイルを読み込む |
| `textWidth()` | 文字列の描画幅を返す |
| `textLeading()` | 行間（行送り）を設定する |
| `PFont` | フォントを表すクラス |
| `LEFT` / `CENTER` / `RIGHT` | 水平整列の定数 |
| `TOP` / `BOTTOM` / `BASELINE` | 垂直整列の定数 |

```java
void setup() {
  size(400, 200);
  textSize(32);
  textAlign(CENTER, CENTER);
}
void draw() {
  background(0);
  fill(255);
  text("Processing", width/2, height/2);
}
```

---

## Image・Pixels（画像・ピクセル）

画像の読み込み・描画・色調補正と、ピクセル単位の直接操作。

| 関数 / 変数 / クラス | 説明 |
|------|------|
| `loadImage()` | 画像ファイルを読み込む |
| `image()` | 画像を描画する |
| `PImage` | 画像を表すクラス |
| `createImage()` | 空の画像をプログラム的に生成する |
| `requestImage()` | 画像を非同期に読み込む |
| `tint()` / `noTint()` | 画像に色味・透明度を掛ける／解除する |
| `imageMode()` | 画像の座標解釈モードを設定する |
| `get()` / `set()` | ピクセル色を取得／設定する |
| `pixels[]` | ピクセル配列（直接アクセス用） |
| `loadPixels()` | `pixels[]` を読み込み可能状態にする |
| `updatePixels()` | `pixels[]` への変更を画面へ反映する |
| `filter()` | ぼかし・グレースケール等のフィルタを適用する |
| `blend()` | 画像同士をブレンドモードで合成する |
| `copy()` | 画像領域をコピーする |
| `mask()` | マスク画像で透明度を適用する |
| `save()` | 描画結果を画像ファイルに保存する |
| `saveFrame()` | フレーム番号付きで連番画像を保存する |

```java
PImage img;
void setup() { size(400, 400); img = loadImage("photo.jpg"); }
void draw() {
  image(img, 0, 0, width, height);   // 全面に描画
  filter(GRAY);                       // グレースケール化
}
```

---

## Data・IO（データ・入出力）

文字列・JSON・テーブル・XML の読み書きと日時・経過時間の取得。

| 関数 / クラス | 説明 |
|------|------|
| `loadStrings()` / `saveStrings()` | テキストを行配列として読み書きする |
| `loadJSONObject()` / `saveJSONObject()` | JSON オブジェクトを読み書きする |
| `loadJSONArray()` | JSON 配列を読み込む |
| `JSONObject` / `JSONArray` | JSON を表すクラス |
| `loadTable()` | CSV / TSV をテーブルとして読み込む |
| `Table` | 表形式データを表すクラス |
| `loadXML()` | XML を読み込む |
| `XML` | XML を表すクラス |
| `createWriter()` | ファイル書き込み用ライターを生成する |
| `year()` / `month()` / `day()` | 現在の年・月・日を返す |
| `hour()` / `minute()` / `second()` | 現在の時・分・秒を返す |
| `millis()` | 起動からの経過ミリ秒を返す |

```java
String[] lines = loadStrings("data.txt");   // 行ごとに読み込み
println(lines.length + " 行 / 経過 " + millis() + "ms");
```

---

## データ構造

組み込みのプリミティブ型・配列と、Processing が提供するコレクション型。クラス定義は Java と同様に記述できる。

| 型 / クラス | 説明 |
|------|------|
| `int` / `float` / `boolean` / `char` / `byte` | 基本プリミティブ型 |
| `color` | 色を保持する型（内部は 32bit 整数） |
| `String` | 文字列型 |
| 配列（`int[]` など） | 同型要素の固定長配列 |
| `ArrayList` | 可変長のオブジェクトリスト |
| `HashMap` | キー・値のマップ |
| `IntList` / `FloatList` / `StringList` | プリミティブ／文字列に最適化した可変長リスト |
| `IntDict` / `FloatDict` / `StringDict` | 文字列キーの辞書型 |

```java
IntList scores = new IntList();
scores.append(10);
scores.append(25);
println(scores.sum());     // 合計
```

```java
class Particle {           // クラス定義は Java と同様
  PVector pos;
  Particle(float x, float y) { pos = new PVector(x, y); }
  void update() { pos.y += 1; }
}
```

---

## レンダラ（JAVA2D / P2D / P3D / PDF / SVG / FX2D）

`size(w, h, RENDERER)` の第 3 引数でレンダラを選択する。既定は JAVA2D。

| レンダラ | 説明 |
|------|------|
| `JAVA2D` | 既定の 2D レンダラ（指定省略時に使用） |
| `P2D` | OpenGL ベースの高速 2D レンダラ |
| `P3D` | OpenGL ベースの 3D レンダラ（`box()` 等の 3D 図形・ライティングに必須） |
| `PDF` | 描画をベクタ PDF として出力する（`processing.pdf` を import） |
| `SVG` | 描画をベクタ SVG として出力する |
| `FX2D` | JavaFX ベースの 2D レンダラ。Processing 4 では任意ライブラリ（JavaFX を別途 import library）として提供される |

```java
void setup() {
  size(800, 600, P3D);   // 3D 描画を有効化
}
```

> 同梱ライブラリの `processing.pdf` を用いると `size(w, h, PDF, "out.pdf")` 形式でベクタ PDF を直接書き出せる。Video（`processing.video`）と Sound（`processing.sound`）は同梱されず、Library Manager 等での追加導入が必要。

---

## Processing 4 の追加（window 関数・Java 17）

Processing 4 で導入・変更された主な点。

| 項目 | 説明 |
|------|------|
| Java 17 上で動作 | 旧 Java 8 から更新。Apple Silicon（aarch64）・Intel・Raspberry Pi ARM に対応 |
| `windowResizable()` | 実行中のウィンドウをリサイズ可能にするか設定する |
| `windowResize(w, h)` | ウィンドウサイズをプログラムから変更する |
| `windowTitle(s)` | ウィンドウのタイトル文字列を設定する |
| `windowMove(x, y)` | ウィンドウの表示位置を移動する |
| `windowRatio()` | アスペクト比に基づくスケーリング座標系を設定する |
| `windowResized()` | ウィンドウのリサイズ時に呼ばれるイベントハンドラ |
| `windowMoved()` | ウィンドウの移動時に呼ばれるイベントハンドラ |

```java
void setup() {
  size(400, 400);
  windowResizable(true);    // リサイズを許可
  windowTitle("My Sketch");
}
void windowResized() {
  println("新しいサイズ: " + width + " x " + height);
}
```

> 同梱ライブラリ: PDF Export（`processing.pdf`）／ Network（`processing.net`）／ Serial（`processing.serial`）／ DXF Export（`processing.dxf`）。レンダラとして FX2D を使う場合は JavaFX を別途 import library する。

---

## 補足

- 関数の引数仕様・オーバーロード・戻り値型・各定数の厳密な値は、必ず公式リファレンス <https://processing.org/reference> で確認すること。
- スケッチは「フォルダ」が単位で、メインタブのファイルは `<フォルダ名>.pde` という名前である必要がある（例: `my_sketch/my_sketch.pde`）。
- 素材（画像・フォント等）は `data/` サブフォルダに置き `loadImage()` 等で読み込む。
