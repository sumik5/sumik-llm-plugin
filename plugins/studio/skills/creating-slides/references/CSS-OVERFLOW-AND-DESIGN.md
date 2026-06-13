# CSS・オーバーフロー・デザインガイドライン

オーバーフロー防止・情報密度CSS調整・デザインガイドライン・テーマ拡張に関するリファレンス。

---

## はみ出し（overflow）の予防・測定・解消（🔴 必須）

固定16:9（1280×720）キャンバスでは、フォント拡大・コード全表示・情報過密が容易にスライド下端のはみ出しを生む。以下を順守する。

### 測定の正しい方法（罠に注意）

`.slide` は `overflow: hidden; height: 720px` 固定。はみ出しは内部コンテンツで起きるため、**`scrollHeight - clientHeight`（クランプ状態）で測る**。

```js
// 1280×720 のページで、対象スライドだけ is-active にして測定
const slides = [...document.querySelectorAll('.slide')];
slides.forEach(s => s.classList.remove('is-active'));
target.classList.add('is-active');
const overflowPx = target.scrollHeight - target.clientHeight; // > 2 ならはみ出し
```

- ❌ `height: auto` / `overflow: visible` を付けて「自然高さ」を測らない（はみ出しを検出できない）
- 🔴 **CSS変更が反映されているか必ず確認**: HTTP プレビューサーバは旧CSSをキャッシュする。`file://` を直接開くか、`?cb=<timestamp>` を HTML と `<link>` の両方に付けてキャッシュバストする。古いCSSで測ると「縮んで見えてはみ出し0」と誤判定する。
- 全スライドを1枚ずつ is-active 化して総当りで測る（特定スライドだけ見ない）

### 解消は systemic-fix を優先（分割は最後の手段）

はみ出しを見つけたら、**個別スライドを分割する前に**、全スライドに効く根本対処を先に試す（少ない変更で大量のはみ出しが一括解消する）:

1. **上部・下部の余白を削る**（`engine/slide.css` の `.slide { padding }`。既定の上余白は `--sp-lg`(40px)。どうしても収まらない密なスライドに限り `--sp-md`(24px)〜`--sp-xs`(8px) まで詰めると content 領域が広がる。ただし第一選択はスライド分割）
2. **`.slide-content` の gap を詰める**（`--sp-lg` → `--sp-md`）
3. **cols-N が縦積みになっていないか確認**（theme で `.slide-content .body.cols-N { display:grid }` 対策済み。カードは横並びが正）
4. それでも収まらない密なコード/テーブルのみ、**論理境界でスライド分割**（コード値・情報は無改変、`slide-counter` を更新）

> 実例: フォント拡大で27スライドがはみ出したが、上部余白削減（+96px）だけで大半が解消し、真に分割が必要だったのは数枚だった。**まず余白・gap・grid、最後に分割**。

### コードブロックはスクロールバー禁止

`.slide pre` に `max-height` + `overflow:auto` を付けない（スライド内スクロールバーは NG）。収まらなければ分割する。長い行は `white-space: pre-wrap` で折り返す（theme 設定済み）。

### 既知のCSSの罠（theme で対策済み・再発させない）

| 罠 | 症状 | 対策（theme済み） |
|----|------|-----------------|
| `.list li { display:flex }` | li 内のインライン要素（tag/mono/テキスト）が flex item に分解され、隙間・単語途中改行で崩れる | `.list li` は block + bullet を `::before` 絶対配置 |
| `.body cols-N` 併用 | `.slide-content .body` の flex-column が grid を打ち消しカード縦積み→はみ出し | `.slide-content .body.cols-N { display:grid }` で詳細度上書き |
| `pre { max-height; overflow:auto }` | スライド内にスクロールバー | max-height を使わず分割で対応 |

### 制作メタデータをスライドに出さない（🔴）

「想定尺 約N分」「前提タグ: section-xx-end」「前提: リポジトリ未取得」等は**制作者向けの内部メモ**。受講者・聴衆が見るスライドには出さない（タイトルスライドのサブタイトルは演題の説明のみに留める）。現在位置は `slide-counter` とプログレスバー（`engine/slide.js` が `#auto-progress` を自動生成）が担う。

### シンタックスハイライト（engine 標準・自動）

コードへの色付けは engine に標準搭載済み。`highlight.js` をローカル同梱（`engine/vendor/highlight.min.js` + `hljs-theme.css`）し、`engine/slide.js` の `initHighlight()` が起動時に動的ロード→`.slide pre > code` 全要素へ `hljs.highlightElement()` を自動適用する。**`<pre><code>` を書くだけで色が付く**（特別な opt-in 不要）。言語を明示したい場合は `<code class="language-js">` のように付ける（未指定でも hljs が自動判定）。

- 色付けは `<span>` 付与のみでテキスト値は不変 → 写経・コピペ安全
- CDN ではなくローカル vendoring（オフライン・録画・PDF・社内ネットワークで安定）
- `.hljs` の背景・padding はスライド側に合わせて `engine/slide.css` で上書き済み（スクロールバー禁止・長い行は折返し）
- テーマCSSは GitHub Light（白背景デッキと整合）。ダークテーマ化する場合は別の hljs テーマCSSに差し替える
- **無効化したい場合**: デッキのルート要素を `<div class="deck" data-no-highlight>`（または `<body data-no-highlight>`）にすると、ハイライト用CSS/JSの読込ごとスキップされる。コードを載せないデッキで使う（Stage 0 の決定ポイント6「シンタックスハイライト=無効」に対応）

---

## 情報密度の高いデッキ向けCSS調整

テーマのデフォルトは撮影・配信での視認性を優先して本文フォントを底上げ済み（base 1.1rem）。一方で、コードブロック・手順・つまずきポイントを1枚に大量に載せるハンズオン研修デッキでは、**逆にデフォルトより少し詰めて**情報量を確保したい場合がある。その際は以下の縮小オーバーライドをデッキの `<style>` ブロック（または `_head.html`）に追加する。ただし第一選択は「スライド分割」であり、縮小は最後の手段とする。

### 高密度デッキ向け縮小オーバーライド（デフォルト比 約90%）

```css
:root {
  --text-xs:   .75rem;    /* 12px */
  --text-sm:   .875rem;   /* 14px */
  --text-base: 1rem;      /* 16px */
  --text-lg:   1.1875rem; /* 19px */
  --text-xl:   1.625rem;  /* 26px */
  --text-2xl:  1.875rem;  /* 30px */
  --text-3xl:  2.5rem;    /* 40px */
  --text-4xl:  3.75rem;   /* 60px */

  --sp-xs:  .5rem;        /* 8px */
  --sp-sm:  .9375rem;     /* 15px */
  --sp-md:  1.375rem;     /* 22px */
  --sp-lg:  2.125rem;     /* 34px */
  --sp-xl:  3.25rem;      /* 52px */
}
```

### 推奨デッキ固有クラスのオーバーライド

テーマのデフォルトではハンズオン系スライドの以下の要素が小さすぎるため、デッキ固有スタイルで上書きする:

```css
/* コードブロック: テーマの --text-sm → --text-lg に拡大 */
.code-block { font-size: var(--text-lg); }

/* 手順テキスト: --text-base → --text-xl */
.step-row p { font-size: var(--text-xl); }

/* ステップ番号: 1.5rem → 2.5rem */
.step-num { width: 2.5rem; height: 2.5rem; line-height: 2.5rem; font-size: var(--text-lg); }

/* つまずきポイント: 見出し・本文を拡大 */
.troubleshoot h3 { font-size: var(--text-xl); }
.troubleshoot p { font-size: var(--text-lg); }

/* 期待される結果: ラベル・本文を拡大 */
.expect::before { font-size: var(--text-base); }
.expect p { font-size: var(--text-lg); }

/* リスト項目（もくじ・学習目標等） */
.list li { font-size: var(--text-xl); }
.goal-list li { font-size: var(--text-xl); }

/* タグバッジ: --text-xs → --text-base */
.tag { font-size: var(--text-base); padding: .2em .6em; }

/* ツリー表示（ディレクトリ構造等） */
.tree { font-size: var(--text-lg); }
```

### 縦レイアウト優先の原則

情報密度の高いデッキでは、`cols-2` / `cols-3` のカードグリッドを使わず、**縦並びの `.troubleshoot` スタイル**を優先する。

| パターン | 使用場面 |
|---------|---------|
| `cols-2` / `cols-3` + `.card` | 要素が少なく各カードの情報量が1-2行のとき |
| `.troubleshoot` 縦並び | 各項目に見出し+説明文があるとき（**デフォルトでこちらを使う**） |

縦並びの利点:
- フォントサイズを大きく保てる（横に詰め込まないため）
- オンライン投影時に読みやすい
- スライド分割せずに3-4項目を1枚に収められる

```html
<!-- 推奨: 縦並びパターン -->
<div class="troubleshoot">
  <h3><span class="tag" style="margin-right: var(--sp-sm);">01</span>タイトル</h3>
  <p>説明文</p>
</div>
<div class="troubleshoot" style="margin-top: var(--sp-sm);">
  <h3><span class="tag" style="margin-right: var(--sp-sm);">02</span>タイトル</h3>
  <p>説明文</p>
</div>
```

### テキストサイズの使い分け目安

| 要素 | 推奨サイズ |
|------|-----------|
| スライド説明文（h2の直下） | `--text-xl`（26px） |
| 手順テキスト（step-row） | `--text-xl`（26px） |
| コードブロック | `--text-lg`（19px） |
| 補足・mutedテキスト | `--text-lg`（19px） |
| 期待される結果の本文 | `--text-lg`（19px） |
| つまずきポイント見出し | `--text-xl`（26px） |
| つまずきポイント本文 | `--text-lg`（19px） |

> **注意**: `--text-sm`（14px）以下をスライド本文に使わないこと。オンライン投影では見えない。`--text-sm` はインラインコードのサイズ調整（`.code-inline` の `.9em`）でのみ使う。

### 印刷（PDF）用CSS変数の縮小（必須）

画面は1280px幅で描画するが、印刷は254mm ≈ 960px（75%）になる。`rem`ベースのCSS変数はコンテナ幅に連動しないため、印刷時にテキストが相対的に大きくなりはみ出る。**情報密度の高いデッキでは `@media print` でCSS変数を75%スケールに上書きすること。**

```css
@media print {
  :root {
    --text-xs:   .5625rem;  /* 9px */
    --text-sm:   .6875rem;  /* 11px */
    --text-base: .75rem;    /* 12px */
    --text-lg:   .875rem;   /* 14px */
    --text-xl:   1.1875rem; /* 19px */
    --text-2xl:  1.375rem;  /* 22px */
    --text-3xl:  1.875rem;  /* 30px */
    --text-4xl:  2.75rem;   /* 44px */

    --sp-xs:  .375rem;      /* 6px */
    --sp-sm:  .6875rem;     /* 11px */
    --sp-md:  1rem;         /* 16px */
    --sp-lg:  1.5rem;       /* 24px */
    --sp-xl:  2.375rem;     /* 38px */
  }
  .code-block { font-size: var(--text-sm); }
  .step-row p { font-size: var(--text-lg); }
  .step-num { width: 1.75rem; height: 1.75rem; line-height: 1.75rem; font-size: var(--text-sm); }
  .troubleshoot h3 { font-size: var(--text-lg); }
  .troubleshoot p { font-size: var(--text-sm); }
  .expect::before { font-size: var(--text-xs); }
  .expect p { font-size: var(--text-sm); }
  .list li { font-size: var(--text-lg); }
  .tag { font-size: var(--text-xs); padding: .15em .4em; }
}
```

> **追加の注意事項**:
> - `engine/slide.css` の `print-color-adjust: exact` がカラー背景・背景画像の印刷を保証する。デッキ側で `background: #fff !important` を指定しないこと
> - ブラウザの印刷ダイアログで「背景のグラフィック」にチェックが必要
> - 進捗インジケータは `@media print { .progress-bar { display: none !important; } }` で自動非表示

---

## デザインガイドライン

### 設計思想

「ミニマルで読みやすい」を最優先とする。装飾ではなく、余白・タイポグラフィ・構造でメッセージを伝える。

### カラーパレット

デフォルトはライトテーマ（白背景・濃色テキスト・青アクセント）。撮影・動画配信での視認性が高い。

| 用途 | 変数 | デフォルト値 | 運用ルール |
|------|------|-------------|-----------|
| 背景 | `--color-bg` | `#ffffff` | 白。スライド全体のベース |
| テキスト | `--color-fg` | `#1a1a1a` | ほぼ黒の濃いグレー |
| サブテキスト | `--color-muted` | `rgba(26,26,26,.6)` | 補足・説明用。白背景で約#767676＝WCAG AA 4.5:1 を満たす（小テキスト可読の下限） |
| アクセント | `--color-accent` | `#0033FF` | 線・テキストのみ。塗りには使わない |
| ボーダー | `--color-border` | `rgba(26,26,26,.1)` | 区切り線・カード枠 |
| カード背景 | `--color-card-bg` | `rgba(0,0,0,.03)` | ごく薄いグレー。カード・ボックス用 |
| 外側背景 | `--color-chrome` | `#e8e8e8` | deck外側（ブラウザ背景） |

#### アクセント色の使い方
- テキストの強調（`.accent`クラス）
- 線・ボーダー（タイトル下線、ランディング左線）
- タグバッジの枠線
- 塗りつぶしには使わない（面が大きすぎると目が疲れる）

### タイポグラフィ

#### フォントスタック
- **本文**: Zen Kaku Gothic New → Hiragino Sans → Yu Gothic → Noto Sans JP（webfontは埋め込まず、未導入環境では後続へ自動フォールバック）
- **コード・数字**: SF Mono → Fira Code → Consolas

#### カスタムフォントの使い方

**外部フォント（Google Fonts等）を使う場合、CDN URLを直接埋め込まず、必ずローカルにダウンロードして使用する。**

手順:
1. フォントファイル（`.woff2` 推奨）を `shared/fonts/` にダウンロード
2. `theme/sample.css`（またはカスタムテーマCSS）に `@font-face` を定義
3. `--font-sans` 等のCSS変数でフォントファミリーを指定

```css
/* theme/sample.css に追記 */
@font-face {
  font-family: 'Noto Sans JP';
  src: url('../../shared/fonts/NotoSansJP-Regular.woff2') format('woff2');
  font-weight: 400;
  font-display: swap;
}
@font-face {
  font-family: 'Noto Sans JP';
  src: url('../../shared/fonts/NotoSansJP-Bold.woff2') format('woff2');
  font-weight: 700;
  font-display: swap;
}
:root {
  --font-sans: 'Noto Sans JP', Helvetica Neue, sans-serif;
}
```

> **禁止**: `<link href="https://fonts.googleapis.com/...">` のようなCDN参照。オフライン環境・社内ネットワークで表示が崩れる原因になる。

#### サイズスケール
| トークン | サイズ | 用途 |
|----------|--------|------|
| `--text-4xl` | 5rem (80px) | タイトルスライドの見出し |
| `--text-3xl` | 3.5rem (56px) | ランディング・セクション見出し |
| `--text-2xl` | 2.5rem (40px) | コンテンツスライドの見出し |
| `--text-xl` | 1.85rem (29.6px) | h3・サブ見出し |
| `--text-lg` | 1.38rem (22px) | 本文・リスト項目 |
| `--text-base` | 1.1rem (17.6px) | カード本文 |
| `--text-sm` | 0.98rem (15.7px) | ラベル・日付 |
| `--text-xs` | 0.85rem (13.6px) | タグ |

> 本文系（xs〜xl）は撮影・配信で小さすぎないよう底上げ済み。見出し系（2xl/3xl/4xl）は据置。

#### ウェイト
- **400 (normal)**: 本文、説明テキスト
- **500 (medium)**: h3
- **700 (bold)**: h1, h2, 強調

### レイアウト原則

#### 1スライド1メッセージ
- 伝えたいことは1つに絞る
- 情報が多い場合はスライドを分割する（詰め込まない）

#### 余白を恐れない
- スライド内パディング: 上 `--sp-lg`(40px) / 左右 `--sp-xl`(64px) / 下 `--sp-md`(24px)。見出し上に呼吸（余白）を確保しつつ、下はやや控えめにして縦の作業領域を残す
- 要素間（`.slide-content` の gap）: `--sp-md`（1.5rem = 24px）
- 余白 = 読みやすさ。ただし詰め込みよりは「分割」で対応する

#### テキスト量の目安
| スライドタイプ | テキスト上限 |
|---------------|-------------|
| タイトル | タイトル1行 + サブ1〜2行 |
| コンテンツ | 見出し + 本文3〜5行 or リスト3〜5項目 |
| ランディング | 1〜3行の短文 |
| セクション | 見出し + 補足1行 |

### 図解の使い方

#### フローチャート (`flow`)
- **用途**: プロセス、手順、タイムライン
- **ステップ数**: 3〜5個（4が最適）
- **矢印**: `→` を `flow-arrow` で挟む

#### カードグリッド (`cols-3` + `card`)
- **用途**: 並列の概念、3つの柱、比較
- **カード数**: 3個が標準（`cols-2` で2個も可）
- **各カードの構造**: タグ番号 → 見出し → 1〜2行の説明

#### 数字ハイライト (`stat`)
- **用途**: KPI、成果、インパクトのある数値
- **数字**: 大きく、モノスペースで、アクセント色
- **ラベル**: 小さく、muted色で

#### 2カラム比較 (`cols-2`)
- **用途**: Before/After、旧/新、問題/解決
- **区切り**: 右カラムに `border-left` を付けると明確

### テーマカスタマイズ手順

1. `theme/sample.css` の `:root` 変数を変更
2. 変更するのは **変数の値だけ**。セレクタやプロパティは変えない
3. よく変えるもの:
   - `--color-accent`: ブランドカラーに合わせる
   - `--color-bg`: 背景色を変更する場合（ダーク化は「ダークテーマを作る場合」節参照）
   - `--font-sans`: ブランドフォントに差し替え

### アンチパターン（やってはいけないこと）

- スライドにテキストを詰め込む（5行超は分割する）
- アクセント色を背景の塗りに使う（目が疲れる）
- 画像を `background-image` だけで指定する（印刷で消える）
- `engine/` のファイルを直接編集する（全デッキに影響）
- 1スライドに複数の論点を混ぜる

---

## テーマ拡張

### ダークテーマを作る場合

デフォルトはライトテーマ（白背景）。ダークにしたい場合は `theme/dark.css` を新規作成し、変数を上書き:

```css
:root {
  --color-chrome:  #111111;
  --color-bg:      #0f0f0f;
  --color-fg:      #f0f0ee;
  --color-muted:   rgba(240,240,238,.45);
  --color-accent:  #6ee7b7;
  --color-border:  rgba(240,240,238,.1);
  --color-card-bg: rgba(255,255,255,.04);

  /* ナビUIクローム（ダーク背景では白系で視認性確保） */
  --color-ui-fg:        rgba(255,255,255,.5);
  --color-ui-bg:        rgba(255,255,255,.07);
  --color-ui-border:    rgba(255,255,255,.12);
  --color-ui-fg-strong: rgba(255,255,255,.9);
}
```

デッキの `<link>` を `../../theme/dark.css` に変更するだけで適用される。なおダーク化した場合、`engine/slide.css` の `#auto-progress` 背景（`rgba(0,0,0,.08)`）も明るい値へ調整するとプログレスバーの溝が見やすい。
