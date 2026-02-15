# draw.io CSV フォーマット詳細リファレンス

draw.ioのCSVインポート形式の完全仕様。`open_drawio_csv` ツールで使用する。

---

## 構造

CSVデータの前に `#` で始まるディレクティブ行を記述。`##` はコメント。

```
# ディレクティブ1: 値
# ディレクティブ2: 値
## コメント（無視される）
column1,column2,column3
data1,data2,data3
```

---

## ディレクティブ一覧

### ラベル定義

```
# label: %name%<br><i style="color:gray;">%position%</i>
```

`%column_name%` でCSVの列値を参照。HTMLタグ使用可能。複数列を組み合わせてリッチなラベルを構成できる。

### ノードスタイル

```
# style: whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#6c8ebf;rounded=1;
```

draw.ioのスタイル文字列形式でノードの外観を定義。列参照 `%column%` も一部使用可能（`fillColor=%fill%` 等）。

### 条件付きスタイル

```
# stylename: type
# styles: {"decision": "rhombus;fillColor=#fff2cc;strokeColor=#d6b656;whiteSpace=wrap;html=1;", \
# "process": "rounded=1;fillColor=#dae8fc;strokeColor=#6c8ebf;whiteSpace=wrap;html=1;", \
# "start": "ellipse;fillColor=#d5e8d4;strokeColor=#82b366;whiteSpace=wrap;html=1;"}
```

`stylename` で指定した列の値に応じて異なるスタイルを適用。複数行にまたがる場合は行末に `\` を記述。

### 接続定義

```
# connect: {"from":"source_col", "to":"target_col", "style":"curved=1;endArrow=blockThin;endFill=1;"}
```

**パラメータ:**

| パラメータ | 型 | 説明 |
|-----------|-----|------|
| `from` | string | 接続元データを持つ列名 |
| `to` | string | 接続先データを持つ列名 |
| `style` | string | エッジのスタイル文字列 |
| `invert` | boolean | `true` で接続方向を反転 |
| `label` | string | エッジラベルに使う列名 |

複数の接続関係を定義する場合、`# connect:` 行を複数記述する:

```
# connect: {"from":"manager", "to":"name", "style":"endArrow=blockThin;endFill=1;"}
# connect: {"from":"refs", "to":"name", "invert":true, "label":"ref_label", "style":"dashed=1;endArrow=open;"}
```

### レイアウト設定

| ディレクティブ | 説明 | 値の例 |
|--------------|------|--------|
| `# layout: auto` | 自動レイアウトアルゴリズム | `auto` |
| `# width: 120` | ノード幅 | `auto` または数値 |
| `# height: 60` | ノード高さ | `auto` または数値 |
| `# nodespacing: 40` | 同レベルのノード間距離 | 数値（px） |
| `# levelspacing: 100` | 階層レベル間の距離 | 数値（px） |
| `# edgespacing: 40` | 平行エッジ間の距離 | 数値（px） |
| `# padding: 10` | オートサイズ時のパディング | 数値（負の値も可: `-12`） |

### メタデータ制御

| ディレクティブ | 説明 | 例 |
|--------------|------|-----|
| `# namespace: prefix-` | セルIDのプレフィックス | `csvimport-` |
| `# ignore: col1,col2` | メタデータから除外する列 | `fill,stroke,refs` |
| `# link: url` | ハイパーリンクに使う列 | `url` |
| `# image: photo` | 画像属性に使う列 | `photo` |

### コンテナ（グループ化）

```
# parentstyle: swimlane;collapsible=0;
```

親子関係のあるノードをグループ化するコンテナのスタイル。

---

## 完全な例: 多機能組織図

```csv
# label: %name%<br><i style="color:gray;">%position%</i><br><a href="mailto:%email%">%email%</a>
# style: whiteSpace=wrap;html=1;fillColor=%fill%;strokeColor=%stroke%;rounded=1;
# connect: {"from":"manager", "to":"name", "style":"curved=1;endArrow=blockThin;endFill=1;"}
# connect: {"from":"refs", "to":"name", "invert":true, "style":"dashed=1;endArrow=open;endFill=0;"}
# width: 200
# height: 80
# ignore: fill,stroke,refs,email
# nodespacing: 40
# levelspacing: 100
# edgespacing: 40
# layout: auto
# padding: 10
##
name,position,manager,email,fill,stroke,refs
田中太郎,CEO,,tanaka@example.com,#dae8fc,#6c8ebf,
佐藤花子,CTO,田中太郎,sato@example.com,#d5e8d4,#82b366,
山田次郎,CFO,田中太郎,yamada@example.com,#fff2cc,#d6b656,
鈴木一郎,VP Engineering,佐藤花子,suzuki@example.com,#e1d5e7,#9673a6,
高橋美咲,VP Product,佐藤花子,takahashi@example.com,#f8cecc,#b85450,田中太郎
```

---

## 完全な例: フローチャート（条件付きスタイル）

```csv
# label: %step%
# stylename: type
# styles: {"start": "ellipse;fillColor=#d5e8d4;strokeColor=#82b366;whiteSpace=wrap;html=1;", \
# "process": "rounded=1;fillColor=#dae8fc;strokeColor=#6c8ebf;whiteSpace=wrap;html=1;", \
# "decision": "rhombus;fillColor=#fff2cc;strokeColor=#d6b656;whiteSpace=wrap;html=1;", \
# "end": "ellipse;fillColor=#f8cecc;strokeColor=#b85450;whiteSpace=wrap;html=1;"}
# connect: {"from":"next","to":"step","style":"endArrow=classic;html=1;"}
# width: 140
# height: 60
# layout: auto
# ignore: type
##
step,type,next
開始,start,入力検証
入力検証,process,バリデーション
バリデーション,decision,処理実行
処理実行,process,結果出力
結果出力,process,終了
終了,end,
```

---

## 注意事項

- `%column%` は `fillColor` や `strokeColor` では安定して動作するが、URI関連の属性では避ける
- 複数行ディレクティブは `\` で継続（`# styles:` の複数スタイル定義等）
- CSVデータ行の最初の行はヘッダー（列名）
- 空セルは省略可（`,,,`）
- 組織図以外の用途では、可能な限りMermaid形式を推奨（信頼性が高い）
