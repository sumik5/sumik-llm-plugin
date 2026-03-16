# プレゼンテーション作成スイート

このスキルは4つのプレゼンテーションニーズを一元的にカバーする統合スキルです。

| 機能 | 用途 |
|------|------|
| **プレゼン品質改善** | ストーリー・構成・デリバリー・エンゲージメントの改善 |
| **HTMLスライド作成** | 1スライド=1HTMLファイル（1280×720px）のデッキ生成 |
| **PDFテンプレート変換** | PDF → スクリーンショット → HTML 視覚再現 |
| **Google Slides生成** | 非構造化テキスト → GAS slideData 配列生成 |

---

## プレゼン品質改善

プレゼンのコンテンツ・構成・デリバリーの質を高める。HTMLスライド生成が目的なら「HTMLスライド作成」セクションへ。

### 5つの改善領域

| 領域 | 核心原則 | 詳細参照 |
|------|---------|---------|
| **1. マインドセット・準備** | 情熱と目的の明確化（3ゴール・核メッセージ・聴衆分析） | — |
| **2. ストーリー・構成** | ストーリーが記憶を作る（ピラミッド・1:2:1三幕・AIDMA・空雨傘） | [QUALITY-LOGICAL-STRUCTURE.md](references/QUALITY-LOGICAL-STRUCTURE.md) |
| **3. スライド・資料デザイン** | スライドは話の補助（KISS原則・1スライド1メッセージ・3秒ルール） | [QUALITY-SLIDE-DESIGN.md](references/QUALITY-SLIDE-DESIGN.md) |
| **4. デリバリー・話し方** | 「どう話すか」が印象の60〜90%を決める（3T原則・18分ルール・緊張管理） | [QUALITY-DELIVERY-TECHNIQUES.md](references/QUALITY-DELIVERY-TECHNIQUES.md) |
| **5. 聴衆エンゲージメント** | 能動的参加で記憶が定着（PUNCH原則・問いかけ・双方向性） | [QUALITY-ENGAGEMENT-STRATEGIES.md](references/QUALITY-ENGAGEMENT-STRATEGIES.md) |

### 改善ワークフロー（5ステップ）

1. **入力受付** — 草稿 / アウトライン / メモのいずれかを受け取る
2. **現状分析** — プレゼン種類（提案型/報告型/啓発型/ピッチ型）と聴衆を判定
3. **重点領域の特定** — ユーザーに確認し、優先領域を決める（全領域同時はオーバーキル）
4. **改善提案の実行** — 構成の再設計・メッセージのシャープ化・デリバリーアドバイス
5. **出力と橋渡し** — 技術スキルへの橋渡し（HTMLスライド / Google Slides / スクリプト推敲）

### プレゼン種類別の重点領域

| 種類 | 推奨構成 | 重点参照 |
|------|---------|---------|
| 提案型 | SCQ + ピラミッド（結論→根拠3つ→実行計画→感情訴求） | [QUALITY-LOGICAL-STRUCTURE.md](references/QUALITY-LOGICAL-STRUCTURE.md) |
| 報告型 | 結論先行→現状→データ→次アクション | [QUALITY-SLIDE-DESIGN.md](references/QUALITY-SLIDE-DESIGN.md) |
| 啓発型 | TED型（フック→核心アイデア→ストーリー→実践示唆→締め） | [QUALITY-STORYTELLING.md](references/QUALITY-STORYTELLING.md) |
| ピッチ型 | 問題→ソリューション→差別化→実績→Ask | [QUALITY-DELIVERY-TECHNIQUES.md](references/QUALITY-DELIVERY-TECHNIQUES.md) |
| 社内型 | 結論→現状・課題→提案QCD→リスク→次アクション | [QUALITY-LOGICAL-STRUCTURE.md](references/QUALITY-LOGICAL-STRUCTURE.md) |

### AskUserQuestion が必要な場面

| 場面 | 確認内容 |
|------|---------|
| プレゼン種類が不明 | 提案型 / 報告型 / 啓発型 / ピッチ型 |
| 聴衆が特定できない | 意思決定者 / 現場実行者 / 一般 / 投資家 |
| 重点改善領域 | 5領域のどこに注力するか |
| 持ち時間 | 18分ルール適用と構成密度に影響 |

### 説得の3要素（目安配分）

| 要素 | 内容 | 目安 |
|------|------|------|
| エトス（信頼感） | 実績・立場・誠実さ | 10〜15% |
| ロゴス（論理） | データ・根拠・エビデンス | 25〜30% |
| パトス（感情） | ストーリー・情熱・共感 | 55〜65% |

**橋渡し**: コンテンツ改善完了 → HTMLスライド化（本スキル「HTMLスライド作成」）/ Google Slides化（本スキル「Google Slides生成」）/ スクリプト推敲（`writing-effective-prose`）

---

## HTMLスライド作成

1スライド = 1 HTMLファイル（1280×720px）のプレゼンデッキを生成する。**ユーザーへの全連絡は日本語で行う。**

### ワークフロー概要

| Phase | 内容 | 成果物 |
|-------|------|--------|
| 1 | ヒアリング | 出力先・スタイル・テーマ・内容・枚数を確定 |
| 2 | カスタムテンプレート読み込み | `references/templates/` のHTML解析（なければスキップ） |
| 3 | デザイン決定 | カラーパレット・フォント・アイコン（ユーザー確認必須） |
| 4 | スライド構成設計 | スライドマップ（全スライドの型・レイアウト） |
| 5 | HTML生成 | `001.html`〜`NNN.html` |
| 6 | print.html 生成 | 全スライドを iframe で並べた一覧ページ |
| 7 | チェックリスト確認 | 制約適合確認・修正 → [SLIDEKIT-CHECKLIST.md](references/SLIDEKIT-CHECKLIST.md) |
| 8 | PPTX変換（任意） | `/pptx` スキルへ橋渡し → [SLIDEKIT-CHECKLIST.md](references/SLIDEKIT-CHECKLIST.md) |

### 必須制約

| ルール | 値 |
|--------|-----|
| スライドサイズ | `width: 1280px; height: 720px` |
| CSS フレームワーク | Tailwind CSS 2.2.19 via CDN |
| アイコン | Font Awesome 6.4.0 via CDN |
| フォント | Google Fonts（JP 1本 + Latin 1本） |
| JavaScript | **完全禁止**（Chart.js 等も不可） |
| 外部画像 | デフォルト禁止（明示的ユーザー承認が必要） |
| ルート DOM | `<body>` → single wrapper `<div>` |
| テキスト要素 | `<p>` / `<h*>`（`<div>` でのテキスト禁止） |
| CSS テキスト | `::before` / `::after` に表示テキスト禁止 |

### 15レイアウトパターン一覧

DOM構造・コンポーネントスニペット → [SLIDEKIT-PATTERNS.md](references/SLIDEKIT-PATTERNS.md)

| # | パターン | 用途 |
|---|---------|------|
| 1 | Center | 表紙・締め |
| 2 | Left-Right Split | 章区切り・概念+詳細 |
| 3 | Header-Body-Footer (HBF) | コンテンツスライド（デフォルト） |
| 4 | HBF + 2-Column | 比較・データ+説明 |
| 5 | HBF + 3-Column | カード列挙・3way比較 |
| 6 | HBF + N-Column | プロセスフロー（最大5列） |
| 7 | Full-bleed | インパクト表紙 |
| 8 | HBF + Top-Bottom Split | コンテンツ+KPIサマリー |
| 9 | HBF + Timeline/Roadmap | ロードマップ |
| 10 | HBF + KPI Dashboard | KPIカード+チャート |
| 11 | HBF + Grid Table | 機能比較・競合分析 |
| 12 | HBF + Funnel | コンバージョンファネル |
| 13 | HBF + Vertical Stack | アーキテクチャ・層構造 |
| 14 | HBF + 2x2 Grid | SWOT・リスク分析 |
| 15 | HBF + Stacked Cards | FAQ・番号付き要点 |

**ルール**: 同一パターンを3枚以上連続させない。

### ヒアリング項目（Phase 1）

| 項目 | 内容 |
|------|------|
| 出力ディレクトリ | デフォルト: `output/slide-page{NN}/` |
| スタイル | Creative / Elegant / Modern / Professional / Minimalist |
| テーマ | Marketing / Portfolio / Business / Technology / Education |
| 内容ソース | 参照ファイル / 直接入力 / トピックのみ |
| タイトル | プレゼンタイトル |
| 枚数 | 10 / 15 / 20（推奨） / 25 / Auto |
| ブランド名 | ヘッダー/フッター表示用 |
| カラー希望 | あれば指定、なければ自動提案 |
| 背景画像 | 使用有無（デフォルト: なし） |

### スライド構成（20枚標準）

| 位置 | タイプ | パターン |
|------|--------|---------|
| 1枚目 | Cover | Center |
| 2枚目 | Agenda | HBF |
| 3/6/10/14枚目 | Section Divider | Left-Right Split |
| 4〜5, 7〜9, 11〜13, 15〜18枚目 | Content | パターン4〜15から適宜 |
| 19枚目 | Summary | HBF |
| 20枚目 | Closing | Full-bleed / Center |

### print.html 生成

```html
<!DOCTYPE html><html lang="ja"><head>
    <meta charset="utf-8" /><title>View for Print</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { background: #FFFFFF; }
        .slide-frame { width: 1280px; height: 720px; margin: 20px auto;
            box-shadow: 0 2px 10px rgba(0,0,0,0.15); border: 1px solid #e2e8f0; overflow: hidden; }
        .slide-frame iframe { width: 1280px; height: 720px; border: none; }
        @media print { .slide-frame { page-break-after: always; box-shadow: none; border: none;
            margin: 0 auto; transform: scale(0.85); transform-origin: top center; } }
    </style>
</head><body>
    <div class="slide-frame"><iframe src="001.html"></iframe></div>
    <!-- ... 全スライド分繰り返し ... -->
</body></html>
```

---

## PDFテンプレート変換

PDF → スライドスクリーンショット → Claude が HTML を記述する視覚的再現パイプライン。

### パイプライン

```
PDF → (pdftoppm) → スライド画像
                       ↓
   Claude が各画像を読み込み → HTML 記述
                       ↓
        001.html, 002.html, ... + print.html
```

### 依存関係

```bash
brew install poppler
```

### ワークフロー

**Phase 1: スライド画像生成**

```bash
python {skills_dir}/creating-presentations/scripts/pdf_to_images.py input.pdf output_dir
```

`output_dir/slide-01.jpg`, `slide-02.jpg` ... が生成される。

**Phase 2: デッキ分析**

全スライド画像を読み込み、以下を把握する:

1. カラーパレット（3〜4色: primary dark / accent / secondary）
2. フォントスタイル（serif/sans-serif・ウェイトパターン）
3. ヘッダー/フッターのパターン
4. 全体スタイル（creative / elegant / modern / professional / minimalist）

**Phase 3: デザインシステムのロード**

本INSTRUCTIONS.mdの「HTMLスライド作成」セクションの制約・パターンを適用する。

**Phase 4: HTMLスライド記述**

各スライド画像について:

1. スライド画像を読み込む
2. 最も近いレイアウトパターン（15種）を選択
3. 視覚的に再現するHTMLを記述:
   - 色を正確に再現（画像から観察したhex値を使用）
   - テキスト内容を完全に一致させる
   - 空間レイアウト・比率・装飾要素を再現
4. `{output_dir}/{NNN}.html` として保存（`001.html`, `002.html` ...）

**Phase 5: print.html 生成**

「HTMLスライド作成」セクションと同じ print.html を生成する。

**Phase 6: ビジュアル QA**

各スライドについて:

1. 元の画像（`slide-NN.jpg`）を読み込む
2. 生成したHTMLを読み込む
3. 確認項目: テキスト・色・レイアウト・装飾要素・オーバーフロー
4. 問題を修正し再検証

全スライドで問題がないことを確認してから完了とする。

---

## Google Slides生成

非構造化テキスト（議事録・企画書・提案書・メモ等）から Google Apps Script（GAS）用の `slideData` 配列を生成する。

### 主な特徴

- **入力**: 自由形式のテキスト（箇条書き・章立て・段落形式等）
- **出力**: `slideData` JavaScript配列（GASテンプレートに挿入可能）
- **スライドタイプ**: 11種類（title / section / content / compare / process / timeline / diagram / cards / table / progress / closing）
- **デザイン**: Google公式スライド風（Google Sans・シンプルな余白設計）

### 生成ワークフロー（6ステップ）

| ステップ | 内容 |
|---------|------|
| 1 | コンテキスト分解（意図・構造・聴衆を把握） |
| 2 | パターン選定と論理ストーリーの再構築 |
| 3 | 各節を11種のスライドタイプにマッピング |
| 4 | スキーマ準拠の `slideData` オブジェクト生成（インライン強調記法適用） |
| 5 | 自己検証（文字数・禁止記号・句点・アジェンダ安全装置） |
| 6 | [GSLIDES-BLUEPRINT.md](references/GSLIDES-BLUEPRINT.md) テンプレートに埋め込んで出力 |

### スライドタイプ選定ガイド

| 内容の性質 | 推奨タイプ |
|-----------|----------|
| 2つの対象を比較 | `compare` |
| 時系列・プロセス | `process` または `timeline` |
| フロー・泳道図 | `diagram` |
| カード状の複数項目 | `cards` |
| 表形式データ | `table` |
| 進捗・達成率 | `progress` |
| 一般的な箇条書き | `content` |

### テキスト制限（厳守）

| 対象 | 制限 |
|------|------|
| `title.title` | 全角35文字以内 |
| `section.title` | 全角30文字以内 |
| 各パターンの `title` | 全角40文字以内 |
| `subhead` | 全角50文字以内 |
| 箇条書き要素 | 各90文字以内・改行禁止 |

### 禁止事項

- 禁止記号: `■` `→`
- 箇条書き文末の句点「。」（体言止め推奨）
- 改行文字（`\n`）

### インライン強調記法

| 記法 | 効果 |
|------|------|
| `**太字**` | 太字強調 |
| `[[重要語]]` | 太字＋Googleブルー（#4285F4）強調 |

### 全体構成ルール

```
1. title（表紙）
2. content（アジェンダ — 章が2つ以上のときのみ）
3. section → 本文2〜5枚（章の数だけ繰り返し）
4. closing（結び）
```

### AskUserQuestion が必要な場面

| 状況 | 確認内容 |
|------|---------|
| ターゲット聴衆が不明確 | 経営層・開発チーム・顧客等 |
| 章構成の順序に複数選択肢 | 並び替え案を提示 |
| パターン選定で迷う | compare vs table 等 |

### 詳細仕様・テンプレート

- スキーマ全定義・エラー回避ガイドライン → [GSLIDES-REFERENCE.md](references/GSLIDES-REFERENCE.md)
- GASテンプレート全文（slideData置換用） → [GSLIDES-BLUEPRINT.md](references/GSLIDES-BLUEPRINT.md)
