# draw.io MCP Server 活用ガイド

## 概要

**draw.io MCP Server**（`@drawio/mcp`）は、Claude CodeからMCPプロトコル経由でdraw.ioエディタにダイアグラムを送信し、ブラウザ上で表示・編集するためのツールサーバー。

**提供ツール:**

| ツール | フォーマット | 用途 |
|--------|------------|------|
| `open_drawio_mermaid` | Mermaid.js | フローチャート・シーケンス図・ER図（推奨デフォルト） |
| `open_drawio_xml` | draw.io XML | 精密なスタイリング・座標指定が必要な場合 |
| `open_drawio_csv` | CSV + ディレクティブ | 組織図・階層データの可視化 |

**リポジトリ**: [jgraph/drawio-mcp](https://github.com/jgraph/drawio-mcp)

---

## フォーマット選択ガイド

| 用途 | 推奨 | 信頼性 | 理由 |
|------|------|--------|------|
| フローチャート | Mermaid | 高 | `flowchart TD/LR` で直感的に記述可能 |
| シーケンス図 | Mermaid | 高 | 参加者・メッセージの記法が明快 |
| ER図・クラス図 | Mermaid | 高 | リレーション記法が簡潔 |
| ガントチャート | Mermaid | 高 | タスク依存関係を自然に表現 |
| カスタムスタイル・精密配置 | XML | 高 | 座標・色・形状を完全制御 |
| 既存draw.ioファイルの編集 | XML | 高 | draw.ioネイティブフォーマット |
| 組織図・階層構造 | CSV | 中 | スプレッドシート的データから自動レイアウト |

**原則**: Mermaidで表現可能ならMermaidを使う。スタイル制御が必要ならXML。表形式データからの変換ならCSV。

---

## ツール共通パラメータ

| パラメータ | 型 | デフォルト | 説明 |
|-----------|-----|----------|------|
| `content` | string（必須） | - | ダイアグラム内容、またはコンテンツへのURL |
| `lightbox` | boolean | `false` | `true` で読み取り専用ビュー |
| `dark` | `"auto"` / `"true"` / `"false"` | `"auto"` | ダークモード制御 |

---

## Mermaid形式（推奨デフォルト）

信頼性が最も高く、多くのダイアグラムタイプに対応。

### 対応ダイアグラムタイプ

`flowchart`, `sequenceDiagram`, `erDiagram`, `classDiagram`, `stateDiagram-v2`, `gantt`

### 使用例: システムアーキテクチャ

```
open_drawio_mermaid({
  content: `flowchart LR
    subgraph Client
      A[Browser]
      B[Mobile App]
    end
    subgraph Backend
      C[API Gateway]
      D[Auth Service]
      E[Business Logic]
    end
    subgraph Data
      F[(PostgreSQL)]
      G[(Redis)]
    end
    A --> C
    B --> C
    C --> D
    C --> E
    E --> F
    E --> G`
})
```

### 使用例: ER図

```
open_drawio_mermaid({
  content: `erDiagram
    USER ||--o{ ORDER : places
    USER {
      int id PK
      string name
      string email
    }
    ORDER ||--|{ ORDER_ITEM : contains
    ORDER {
      int id PK
      int user_id FK
      date created_at
    }
    PRODUCT ||--o{ ORDER_ITEM : "ordered in"
    PRODUCT {
      int id PK
      string name
      decimal price
    }`
})
```

> Mermaid構文の詳細（22+ダイアグラムタイプ）は `mermaid-diagrams` スキルを参照。

---

## XML形式（精密制御用）

draw.ioネイティブのmxGraph XML形式。座標・スタイルを完全制御可能。

### 基本構造

```xml
<mxGraphModel>
  <root>
    <mxCell id="0"/>
    <mxCell id="1" parent="0"/>
    <!-- ノード定義 -->
    <mxCell id="2" value="ラベル"
      style="rounded=1;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#6c8ebf;"
      vertex="1" parent="1">
      <mxGeometry x="100" y="100" width="120" height="60" as="geometry"/>
    </mxCell>
    <!-- エッジ定義 -->
    <mxCell id="3" value="" style="endArrow=classic;html=1;"
      edge="1" source="2" target="4" parent="1"/>
  </root>
</mxGraphModel>
```

### 必須ルール

- `id="0"` と `id="1"` のルートセルは必ず含める
- 各セルの `id` はユニーク
- ノードは `vertex="1"`、エッジは `edge="1"` を指定
- 出力は正しいXML（XMLコメント内に `--` を含めない）

### 主要スタイル属性

| 属性 | 説明 | 値の例 |
|------|------|--------|
| `shape` | 形状指定 | `ellipse`, `rhombus`, `mxgraph.flowchart.process` |
| `fillColor` | 背景色 | `#dae8fc` |
| `strokeColor` | 枠線色 | `#6c8ebf` |
| `rounded` | 角丸 | `1` |
| `whiteSpace` | テキスト折り返し | `wrap` |
| `html` | HTMLラベル有効化 | `1` |
| `fontSize` | フォントサイズ | `14` |
| `fontStyle` | フォントスタイル | `1`(太字), `2`(斜体), `4`(下線) |
| `dashed` | 破線 | `1` |
| `endArrow` | 矢印タイプ | `classic`, `block`, `open`, `none` |

### 使用例: カスタムスタイルフロー

```
open_drawio_xml({
  content: `<mxGraphModel>
  <root>
    <mxCell id="0"/>
    <mxCell id="1" parent="0"/>
    <mxCell id="2" value="開始" style="ellipse;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#82b366;fontSize=14;" vertex="1" parent="1">
      <mxGeometry x="200" y="40" width="100" height="60" as="geometry"/>
    </mxCell>
    <mxCell id="3" value="処理" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#6c8ebf;fontSize=14;" vertex="1" parent="1">
      <mxGeometry x="175" y="140" width="150" height="60" as="geometry"/>
    </mxCell>
    <mxCell id="4" value="判断" style="rhombus;whiteSpace=wrap;html=1;fillColor=#fff2cc;strokeColor=#d6b656;fontSize=14;" vertex="1" parent="1">
      <mxGeometry x="187.5" y="240" width="125" height="80" as="geometry"/>
    </mxCell>
    <mxCell id="5" value="" style="endArrow=classic;html=1;" edge="1" source="2" target="3" parent="1"/>
    <mxCell id="6" value="" style="endArrow=classic;html=1;" edge="1" source="3" target="4" parent="1"/>
  </root>
</mxGraphModel>`
})
```

---

## CSV形式（階層データ用）

表形式データから自動レイアウトでダイアグラムを生成。組織図に最適。

### 基本構造

`#` で始まるディレクティブ行 + CSVデータ行で構成:

```csv
# label: %name%<br><i style="color:gray;">%role%</i>
# style: whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#6c8ebf;rounded=1;
# connect: {"from":"manager","to":"name","style":"curved=1;endArrow=blockThin;endFill=1;"}
# width: 180
# height: 60
# nodespacing: 40
# levelspacing: 100
# layout: auto
##
name,role,manager
CEO,最高経営責任者,
CTO,技術統括,CEO
CFO,財務統括,CEO
VP Engineering,エンジニアリング,CTO
VP Product,プロダクト,CTO
```

### 主要ディレクティブ

| ディレクティブ | 説明 |
|--------------|------|
| `# label:` | ラベルテンプレート（`%column%` で列参照、HTML可） |
| `# style:` | ノードの基本スタイル |
| `# connect:` | 接続定義（JSON: `from`, `to`, `style`, `invert`, `label`） |
| `# layout: auto` | 自動レイアウト |
| `# width:` / `# height:` | ノードサイズ（`auto` または数値） |
| `# nodespacing:` / `# levelspacing:` / `# edgespacing:` | 間隔設定 |
| `# stylename:` + `# styles:` | 列値による条件付きスタイル |
| `# ignore:` | メタデータから除外する列 |
| `# namespace:` | IDプレフィックス |
| `##` | コメント行 |

> ディレクティブの詳細仕様は [CSV-FORMAT.md](references/CSV-FORMAT.md) を参照。

### CSV注意事項

- `%column%` プレースホルダを `style` 属性のURI関連部分で使うとエラーになる場合あり
- Mermaid/XMLより信頼性が低い — 組織図以外は可能な限りMermaidを使用

---

## ダイアグラムパターン集

### シーケンス図（認証フロー）

```
open_drawio_mermaid({
  content: `sequenceDiagram
    participant C as Client
    participant A as Auth Server
    participant R as Resource Server

    C->>A: POST /token (credentials)
    A-->>C: access_token + refresh_token
    C->>R: GET /api/data (Bearer token)
    R->>A: Validate token
    A-->>R: Token valid
    R-->>C: 200 OK + data`
})
```

### 状態遷移図（注文ライフサイクル）

```
open_drawio_mermaid({
  content: `stateDiagram-v2
    [*] --> Pending: 注文作成
    Pending --> Confirmed: 在庫確認OK
    Pending --> Cancelled: キャンセル
    Confirmed --> Shipped: 出荷
    Shipped --> Delivered: 配達完了
    Delivered --> [*]
    Cancelled --> [*]`
})
```

### 条件付きスタイル組織図（CSV）

```
open_drawio_csv({
  content: `# label: %name%<br><i>%role%</i>
# stylename: dept
# styles: {"engineering": "rounded=1;fillColor=#dae8fc;strokeColor=#6c8ebf;whiteSpace=wrap;html=1;", \
# "business": "rounded=1;fillColor=#d5e8d4;strokeColor=#82b366;whiteSpace=wrap;html=1;", \
# "executive": "rounded=1;fillColor=#fff2cc;strokeColor=#d6b656;whiteSpace=wrap;html=1;"}
# connect: {"from":"manager","to":"name","style":"curved=1;endArrow=blockThin;endFill=1;"}
# width: 180
# height: 60
# layout: auto
# ignore: dept
##
name,role,manager,dept
CEO,最高経営責任者,,executive
CTO,技術統括,CEO,executive
CFO,財務統括,CEO,executive
Tech Lead,テックリード,CTO,engineering
Designer,デザイナー,CTO,engineering
Accountant,経理担当,CFO,business`
})
```

---

## トラブルシューティング

| 問題 | 原因 | 対処 |
|------|------|------|
| ブラウザが開かない | MCPサーバー未起動 | `npx @drawio/mcp` で起動確認 |
| XMLダイアグラム空白 | ルートセル欠落 | `id="0"` / `id="1"` の `mxCell` を確認 |
| CSV接続が描画されない | `#connect` のJSON構文エラー | ダブルクォートとエスケープを確認 |
| `%column%` でURIエラー | style内のプレースホルダ制限 | 固定値に置換、またはMermaid使用 |
| 日本語が文字化け | エンコーディング問題 | `whiteSpace=wrap;html=1;` をstyleに追加 |

---

## 関連スキル

- **mermaid-diagrams**: Mermaid構文の詳細リファレンス（22+ダイアグラムタイプ、テーマ設定）
- **developing-mcp**: MCPサーバー/クライアントの開発ガイド
