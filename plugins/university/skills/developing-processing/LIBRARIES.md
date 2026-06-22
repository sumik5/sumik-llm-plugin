# Processing ライブラリ運用ガイド (LIBRARIES.md)

Processing 4 におけるライブラリの種類・import 方法・導入経路・CLI ビルド時の解決パスをまとめる。Processing のライブラリは「同梱（Core）」「追加同梱可能（公式配布だが要インストール）」「contributed（サードパーティ）」の 3 層に分かれる。

---

## 1. 同梱ライブラリ (Core Libraries)

Processing 4 のインストールに最初から含まれており、追加インストールなしで `import` するだけで使える。

| ライブラリ | パッケージ | 用途 |
|-----------|-----------|------|
| PDF Export | `processing.pdf` | スケッチの描画をベクター PDF として書き出す |
| Network | `processing.net` | TCP クライアント/サーバ通信 |
| Serial | `processing.serial` | シリアルポート（USB/RS-232 等）との入出力 |
| DXF Export | `processing.dxf` | 3D 形状を DXF（CAD 用ベクター）として書き出す |

### import 文の書き方

スケッチ冒頭でパッケージをワイルドカード import する。

```java
import processing.pdf.*;
import processing.net.*;
import processing.serial.*;
import processing.dxf.*;
```

PDF Export はレンダラ指定と組み合わせて使うことが多い。

```java
import processing.pdf.*;

void setup() {
  size(600, 400, PDF, "output.pdf");
}

void draw() {
  line(0, 0, width, height);
  exit(); // 1 フレーム描画して終了し PDF を確定
}
```

> 同梱されているレンダラ（PDF / SVG）と「同梱ライブラリ」は区別すること。`size(w, h, PDF)` のレンダラ利用には `import processing.pdf.*;` が必要。DXF も同様に `import processing.dxf.*;` が必要。

---

## 2. 同梱されない公式ライブラリ (Video / Sound)

以下の 2 つは Processing 3 では同梱されていたが、**Processing 4 では同梱されない**。利用するには別途インストールが必要。

| ライブラリ | パッケージ | 用途 |
|-----------|-----------|------|
| Video | `processing.video` | 動画再生・Webカメラ（キャプチャ）入力 |
| Sound | `processing.sound` | 音声再生・合成・解析（FFT 等） |

### 導入手順 A: Library Manager (GUI・推奨)

Processing IDE のメニューから導入する。

1. `Sketch > Import Library > Manage Libraries...` を開く（Library Manager が開く）
2. 検索欄に `Video` または `Sound` と入力
3. 該当ライブラリを選び `Install` をクリック

インストールされたライブラリはスケッチブックフォルダの `libraries/` 配下に展開される。導入後は通常どおり import する。

```java
import processing.video.*;
import processing.sound.*;
```

### 導入手順 B: スケッチブック libraries/ への手動配置

GUI を使えない環境（CLI 中心の運用・オフライン環境等）では、ライブラリの配布アーカイブを展開してスケッチブックの `libraries/` に手動配置する。

```text
<スケッチブック>/
└── libraries/
    └── video/
        ├── library/        # .jar 本体やネイティブライブラリ
        ├── examples/
        └── library.properties
```

配置の要点:
- `libraries/<ライブラリ名>/library/` の中に `.jar` が入る構造を保つ（1 階層深い `library/` フォルダが必須）。
- スケッチブックの場所は IDE の Preferences（Sketchbook location）で確認できる。CLI 運用時もこの `libraries/` がライブラリ解決の基準になる（後述 §4）。

---

## 3. contributed（サードパーティ）ライブラリの導入

公式 Core 以外のライブラリ。コミュニティが公開している OSS が多数あり、物理シミュレーション・カメラ/Webカメラ制御・GUI 部品・コンピュータビジョン・幾何/メッシュ処理・OSC 等の通信など、分野は幅広い。代表的な分野の例:

| 分野 | 概要（一般的な用途） | 代表的な OSS の例 |
|------|---------------------|-------------------|
| 物理シミュレーション | 2D/3D の剛体・粒子・バネ系の物理演算 | Box2D ベースのラッパー等 |
| GUI / UI 部品 | ボタン・スライダー等のコントロール部品 | ControlP5 |
| コンピュータビジョン | 画像認識・顔検出・特徴抽出 | OpenCV ベースのラッパー等 |
| カメラ/入力デバイス制御 | Webカメラ・深度センサ等のデバイス入力 | （デバイス向け各種ラッパー） |
| 幾何 / メッシュ | 形状生成・メッシュ操作・座標計算 | （ジオメトリ系ライブラリ群） |
| 通信プロトコル | OSC / MIDI 等のリアルタイム通信 | oscP5 等 |

> 製品名は導入経路の理解を助けるための例示であり、特定ライブラリの採用を推奨するものではない。バージョン互換（特に Processing 4 / Java 17 対応の有無）は各配布元で必ず確認すること。

### 導入経路は 3 つ

#### 経路 1: GUI の Library Manager（最も簡単）

`Sketch > Import Library > Manage Libraries...` から検索してインストール。依存関係も含めて自動的に `libraries/` へ展開され、IDE 再起動なしで使えることが多い。Library Manager のカタログに登録されている contributed ライブラリはこの経路が最短。

#### 経路 2: スケッチブック libraries/ への手動配置（複数スケッチで共有）

カタログに無い・特定バージョンを固定したい場合は、配布アーカイブをスケッチブックの `libraries/` に手動で展開する（構造は §2 の手動配置と同じ）。スケッチブック配下に置くため、**同一スケッチブックの全スケッチから共有**される。CLI ビルドが解決するのもこの場所（§4）。

#### 経路 3: スケッチの code/ への .jar 直接配置（そのスケッチ専用）

特定スケッチだけで使う `.jar` は、スケッチフォルダ内の `code/` サブフォルダに直接置く。

```text
my_sketch/
├── my_sketch.pde
└── code/
    └── some_library.jar
```

`code/` に置いた `.jar` はそのスケッチのクラスパスへ自動的に追加される。スケッチに同梱されるため配布時に持ち運びやすい一方、他スケッチとは共有されない。素材（画像・フォント等）は `data/`、追加 `.jar` は `code/` という役割分担を守る。

---

## 4. CLI (processing cli) でビルドするときのライブラリ解決

コマンドラインから `processing cli` でビルド・実行する場合も、ライブラリの解決ルールは IDE と同じ。

- **同梱（Core）ライブラリ**: 追加設定なしで解決される（`processing.pdf` 等）。
- **追加ライブラリ（Video / Sound / contributed）**: **スケッチブックの `libraries/` から解決される**。CLI 実行前に、対象ライブラリが `<スケッチブック>/libraries/<名前>/library/*.jar` の構造で配置されていることを確認する。GUI が無いビルド環境では §2-B / §3 経路2 の手動配置が前提になる。
- **スケッチ専用 `.jar`**: 当該スケッチの `code/` に置けば CLI でも自動的にクラスパスへ加わる。

CLI のビルド/実行例:

```bash
PROCESSING_BIN="${PROCESSING_BIN:-/Applications/Processing.app/Contents/MacOS/Processing}"

# プリプロセス + コンパイルのみ（ウィンドウを開かない・ヘッドレス検証向き）
# 同じ output を再利用するため --force を付ける（既存 output 衝突を回避）
"$PROCESSING_BIN" cli --sketch=/path/to/my_sketch --output=/path/to/build_out --force --build

# 実行（ウィンドウを開く・必ず timeout で包む）
/opt/homebrew/bin/timeout 20 \
  "$PROCESSING_BIN" cli --sketch=/path/to/my_sketch --output=/path/to/run_out --force --run
```

> ライブラリが解決されない場合、コンパイルは失敗（exit 1）し、stderr に `<file>.pde:開始行:開始列:終了行:終了列: メッセージ` 形式のエラーが出る（`.class` は生成されない）。ライブラリ未配置に起因する場合は、当該 import に対応する `libraries/<名前>/` がスケッチブックに存在するかをまず確認する。

### FX2D レンダラは別ライブラリ扱い

`P2D` / `P3D` は Core に含まれるが、**FX2D レンダラ（JavaFX ベース）は任意ライブラリ化**されており、別途 JavaFX を import library する必要がある。FX2D を使うスケッチは、対応する JavaFX ライブラリを §2 / §3 の手順で導入したうえで指定する。

```java
void settings() {
  size(800, 600, FX2D); // JavaFX ライブラリの導入が前提
}
```

---

## 5. 公式リファレンス

ライブラリの一覧・各ライブラリの API・配布元は公式サイトを参照する。

- ライブラリ一覧（公式）: https://processing.org/reference/libraries
- 言語リファレンス（公式）: https://processing.org/reference

---

## チェックリスト

- [ ] 使うライブラリが Core（同梱）か、Video/Sound か、contributed かを切り分けた
- [ ] Core 以外は Library Manager または `libraries/` 手動配置で導入済み
- [ ] スケッチ専用の `.jar` は `code/`、共有ライブラリは `libraries/` に配置している
- [ ] CLI ビルド時、追加ライブラリがスケッチブックの `libraries/` に正しい構造（`<名前>/library/*.jar`）で置かれている
- [ ] FX2D を使う場合は JavaFX を別途 import library した
- [ ] バージョン互換（Processing 4 / Java 17 対応）を配布元で確認した
