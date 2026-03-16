---
name: designing-graphics
description: >-
  Graphic design fundamentals covering form theory (Gestalt, optical illusions,
  figure-ground), color theory (color harmony, CMYK, tone concepts),
  typography (Japanese/Western typeface classification, typesetting rules),
  and layout composition (grid systems, visual flow, contrast, white space).
  Use when creating print materials, posters, brochures, editorial layouts,
  or applying foundational visual design principles beyond screen UI.
  For web/UI-specific design principles (cognitive psychology, interaction patterns,
  multi-device UI), use applying-design-guidelines instead.
---

# グラフィックデザインの基礎

造形・色彩・タイポグラフィ・レイアウトの基礎理論を体系的に扱う。印刷物・エディトリアルデザインにおける「考え方」と「手の動かし方」を接続する実践的な知識体系。

---

## 1. 使用タイミング

- 印刷物・ポスター・チラシ・パンフレット・冊子のデザイン制作時
- デザインの造形的・色彩的な判断（形の選択、配色スキームの決定）を行う時
- 書体選択・文字組みの方針を決定する時
- レイアウトの構図・視線誘導・グリッドシステムを設計する時

---

## 2. デザインの4要素

### 2.1 形（造形）

形はデザインの最も基本的な要素。**ゲシュタルト心理学**（近接・類同・閉合・よい連続）を応用して情報のまとまりをつくる。**図と地**の関係を意識し、「地の形」の美しさが洗練されたデザインの条件になる。幾何学形態の特性（正方形=安定、三角形=動き・緊張感）と錯視補正もデザイン判断の基礎。

→ 詳細: [references/FORM-AND-SHAPE.md](references/FORM-AND-SHAPE.md)

### 2.2 色（色彩）

色は形よりも記憶に残りやすく、印象形成への影響が最も大きい要素。**色の三属性**（色相・明度・彩度）の理解を土台に、**加法混色（RGB）** と **減法混色（CMYK）** の違いをモニター・印刷の文脈で使い分ける。配色セオリー（コンプリメンタリー、アナロガス、トライアド等）と**トーン概念**（トーン・イン・トーン配色、ドミナントカラー配色）を組み合わせて一貫した配色を設計する。

→ 詳細: [references/COLOR-THEORY.md](references/COLOR-THEORY.md)

### 2.3 文字（タイポグラフィ）

文字デザインは「書体選択」と「組み方」の二本柱。日本語書体（明朝体・ゴシック体）と欧文書体（セリフ4系統・サンセリフ4系統）の分類とイメージを理解し、媒体・目的に応じて選択する。**仮想ボディ・字面・字送り・行送り**の概念を押さえ、禁則処理・文字組みアキ量設定で可読性を担保する。

→ 詳細: [references/TYPOGRAPHY-AND-TYPESETTING.md](references/TYPOGRAPHY-AND-TYPESETTING.md)

### 2.4 レイアウト（構成）

レイアウトは情報の視覚的組織化。**構図**（二等分割・三等分割・対角線）、**コントラスト**（ジャンプ率：大小・明暗・粗密・色・形）、**マージンとホワイトスペース**、**視線誘導**（Z型・N型、アイキャッチャー）の4軸で設計する。**グリッドシステム**は情報量・媒体サイズに応じて選定し、シンメトリー/アシンメトリーの意図的な使い分けでリズムをつくる。

→ 詳細: [references/LAYOUT-AND-COMPOSITION.md](references/LAYOUT-AND-COMPOSITION.md)

---

## 3. クイックリファレンス

| 目的 | 使用する要素 | 参照先 |
|------|------------|--------|
| 安定感・信頼性を表現したい | 正方形・水平線・シンメトリー | FORM-AND-SHAPE.md |
| 動き・緊張感・スピード感を表現したい | 三角形・対角線・アシンメトリー | FORM-AND-SHAPE.md |
| 要素をまとまりとして見せたい | ゲシュタルト近接・類同・閉合 | FORM-AND-SHAPE.md |
| 統一感のある配色にしたい | トーン・イン・トーン配色 | COLOR-THEORY.md |
| メリハリのある配色にしたい | コンプリメンタリー（補色）配色 | COLOR-THEORY.md |
| 上品・格調を表現したい | 低彩度・高明度（ライトトーン） | COLOR-THEORY.md |
| 可読性重視の本文テキスト | ゴシック体 / サンセリフ体 | TYPOGRAPHY-AND-TYPESETTING.md |
| 格調・伝統・エレガントを表現したい | 明朝体 / セリフ体 | TYPOGRAPHY-AND-TYPESETTING.md |
| 視線を効果的に誘導したい | Z型・N型レイアウト、アイキャッチャー | LAYOUT-AND-COMPOSITION.md |
| 情報を整理・グループ化したい | グリッドシステム、ホワイトスペース | LAYOUT-AND-COMPOSITION.md |
| 印象的なビジュアルをつくりたい | 高ジャンプ率・大小コントラスト | LAYOUT-AND-COMPOSITION.md |

---

## 4. ユーザー確認の原則（AskUserQuestion）

**デザイン判断は媒体・目的・ブランド要件に強く依存する。推測で進めず、以下の分岐点では必ず `AskUserQuestion` でユーザーに確認する。**

### 確認すべき場面

- **媒体と目的の確認**: ポスター/チラシ・冊子・名刺・Webバナーで最適解が異なる
- **書体の選択**: デザインのトーン（クラシカル/モダン/カジュアル）とターゲット層に依存
- **配色スキームの決定**: ブランドガイドライン・使用色数・コントラスト要件に依存
- **レイアウト構図の選択**: コンテンツの量・種類・媒体サイズに依存
- **グリッドシステムの選定**: 情報量・段数・マージン幅が要件に依存

```python
AskUserQuestion(
    questions=[{
        "question": "デザインの媒体と目的を確認させてください。",
        "header": "デザイン要件",
        "options": [
            {"label": "ポスター/チラシ（A4以上）", "description": "大判印刷物。視認性・インパクト重視"},
            {"label": "冊子/パンフレット", "description": "複数ページ。可読性・情報整理重視"},
            {"label": "名刺/カード", "description": "小型印刷物。ミニマル・要素の厳選"},
            {"label": "Webバナー/SNS画像", "description": "デジタル用途。RGB配色・画面表示最適化"},
            {"label": "その他", "description": "自由記述で媒体を指定"}
        ],
        "multiSelect": False
    }]
)
```

### 確認不要な場面（ベストプラクティスが一義的）

- ゲシュタルト法則の適用（近接・類同・閉合は普遍的原則）
- 文字色と背景色のコントラスト確保（可読性の客観的基準あり）
- 禁則処理の適用（日本語組版の標準ルール）
- 図と地の明確な分離（視認性の基本原則）

---

## 5. 関連スキルとの使い分け

| スキル | 対象領域 |
|--------|---------|
| **designing-graphics**（本スキル） | 印刷物・グラフィックデザインの造形・色彩・タイポグラフィ・レイアウト基礎理論 |
| `applying-design-guidelines` | Web UI/UXデザイン原則（認知心理学・インタラクションパターン・マルチデバイスUI） |
| `designing-frontend` | フロントエンドコード生成（shadcn/ui、Storybook、コンポーネント実装） |
| `styling-with-tailwind` | Tailwind CSSスタイリング手法（ユーティリティファースト・デザイントークン） |
| `constructing-figma-design-systems` | Figmaを使ったデザインシステム構築（変数・コンポーネント・バリアント管理） |
