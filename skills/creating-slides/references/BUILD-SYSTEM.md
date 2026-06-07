# HTMLスライド ビルドシステム詳細

HTMLスライドテンプレートの技術構造・初期化手順・パーツビルド・スライドタイプ・ユーティリティクラスに関するリファレンス。

---

## 概要

ブラウザで動く16:9 HTMLスライドのテンプレートシステム。`engine/` と `theme/` は共通資産、デッキごとに `decks/{name}/index.html` を作成する。

## ディレクトリ構成

```
slide-starter/
├── CLAUDE.md              ← AI向け仕様書
├── design-guidelines.md   ← デザイン方針
├── plan.md                ← 構築ガイド
├── README.md              ← ユーザー向け説明書
├── engine/
│   ├── slide.css          ← 16:9ロック・ナビUI・PDF出力
│   └── slide.js           ← キーボード操作・スケーリング・PDF・ハッシュ連動・進捗バーAPI
├── theme/
│   └── sample.css           ← デザイントークン（カスタマイズはここだけ）
├── shared/                ← 共有アセット（画像・テクスチャなど）
└── decks/
    └── {deck-name}/
        └── index.html     ← デッキ本体
```

## 3層分離ルール

| 層 | ファイル | 役割 | 編集 |
|----|----------|------|------|
| Engine | `engine/slide.css`, `engine/slide.js` | 16:9ロック、ナビ、PDF出力、スケーリング、ハッシュ連動、進捗バーAPI | **ユーザー確認の上で変更可** |
| Theme | `theme/sample.css` | カラー・フォント・余白の変数、スライドタイプ、ユーティリティ | テーマ変更時のみ |
| Content | `decks/{name}/index.html` | 発表ごとのコンテンツ | **自由** |

---

## プロジェクト初期化

新規スライドプロジェクトは**現在の作業ディレクトリ（カレントディレクトリ）**に作成する。`/tmp` や他の場所には作成しない。

### ディレクトリ構成の作成

```
{project-name}/
├── CLAUDE.md              ← AI向け仕様書（本スキルの内容を転記）
├── design-guidelines.md   ← デザイン方針
├── engine/
│   ├── slide.css          ← 16:9ロック・ナビUI・PDF出力
│   └── slide.js           ← キーボード操作・スケーリング
├── theme/
│   └── sample.css         ← デザイントークン
├── shared/
│   ├── fonts/
│   ├── images/
│   └── logo/
├── reference/             ← 参考資料置き場
└── decks/
    └── 01_sample/
        ├── index.html     ← サンプルデッキ
        └── assets/        ← デッキ固有画像
```

### 初期化手順

1. 上記ディレクトリ構成を作成
2. 本スキルの `templates/` ディレクトリから各ファイル・ディレクトリをコピーして配置する:
   - `templates/engine/` → `engine/`（共通エンジン。共通化すべき機能追加時はユーザー確認の上で変更可）
   - `templates/theme/` → `theme/`（テーマカスタマイズの起点）
   - `templates/decks/01_sample/` → `decks/01_sample/`（サンプルデッキ＋サンプル画像）
   - `templates/shared/` → `shared/`（共有アセット置き場）
   - `templates/reference/` → `reference/`（参考資料置き場）
3. ロゴの確認（Stage 0 の決定ポイント8と対応。**何を使うか必ず AskUserQuestion で聞く。勝手に決めない**）:
   - **指定ロゴを使う**: ファイル/パスを提供してもらい `shared/logo/` に配置 → `src` に指定
   - **プレースホルダーのまま**: 既定の `shared/logo/logo.svg`（中立プレースホルダー。差し替え前提）をそのまま使う
   - **ロゴなし**: スライド内の `<img class="slide-logo">` タグを置かない
   - いずれの場合も、配置する `<img>` には `onerror="this.style.display='none'"` を付け、パス誤り時に broken image を出さない

> **既存プロジェクトの場合**: 上記構造が既にある場合はこのセクションをスキップする。

---

## スライドタイプ一覧

| クラス | 用途 |
|--------|------|
| `slide-title` | タイトルスライド（最初の1枚） |
| `slide-content` | 汎用コンテンツ（本文・箇条書き・カード・図解） |
| `slide-section` | セクション区切り（章立て） |
| `slide-landing` | 核心の一文を大きく見せる全画面スライド |
| `slide-end` | エンディング |
| `slide-toc` | もくじスライド（節目ごとに反復挿入、現在位置ハイライト） |
| `slide-breath` | 呼吸スライド（1メッセージ/画像のみの「間」） |
| `slide-photo-overlay` | 3層写真スライド（全面写真→透過オーバーレイ→中央テキスト） |

---

## ユーティリティクラス

| クラス | 効果 |
|--------|------|
| `accent` | アクセント色テキスト |
| `muted` | サブ情報（薄いグレー） |
| `mono` | モノスペースフォント |
| `bold` | 太字 |
| `divider` | 水平線 |
| `cols-2` | 2カラムグリッド |
| `cols-3` | 3カラムグリッド |
| `list` | アクセント付き箇条書き |
| `card` | ボーダー付きカード |
| `flow` / `flow-step` / `flow-arrow` | フローチャート |
| `stat` / `.number` / `.label` | 数字ハイライト（KPIなど） |
| `tag` | モノスペースのタグバッジ |
| `slide-logo` | 右上ロゴ（`<img class="slide-logo">`） |
| `img-box` | 画像コンテナ（`object-fit: cover`） |
| `text-img` | テキスト+画像の横並びレイアウト |
| `bridge-ref` | 前スライドの図/キーワードを縮小配置（接続ブリッジ） |
| `progress-indicator` / `.active` | 全体位置インジケータ（横並びロジック単位の現在位置表示） |
| `toc-current` / `toc-done` | もくじスライド内の現在位置/完了済みハイライト |

---

## ロゴの使い方

**ロゴは何を使うか必ずユーザーに確認する（Stage 0 決定ポイント8）。** 既定では中立プレースホルダー `shared/logo/logo.svg` が入っており、テンプレは broken image を出さない（差し替え前提）。ユーザー指定のロゴは `shared/logo/` に置いて `src` を差し替える。

```html
<section class="slide slide-content">
  <img class="slide-logo" src="../../shared/logo/logo.svg" alt="Logo"
       onerror="this.style.display='none'">
  <div class="body">...</div>
</section>
```

- `onerror="this.style.display='none'"` を付け、パス誤り・ファイル不在でも broken image を出さない
- 表示位置: コンテンツ・エンディングは左下、タイトルスライドは右上（`opacity: .4`、`height: 20px`）
- タイトル・コンテンツ・エンディングスライドに配置するのが一般的
- ランディング・セクション区切りには置かないのが推奨
- **ロゴなし**を選んだ場合は `<img class="slide-logo">` 自体を置かない

---

## 画像の使い方

デッキ固有の画像は `decks/{name}/assets/` に配置。

### テキスト+画像の横並び
```html
<div class="text-img">
  <div class="text"><p>テキスト</p></div>
  <div class="img-box"><img src="assets/sample.png" alt="説明"></div>
</div>
```

### 全幅画像スライド
```html
<section class="slide slide-content" style="padding: 0;">
  <div class="img-box" style="border-radius: 0;">
    <img src="assets/sample.png" alt="全幅画像">
  </div>
</section>
```

---

## 図解パターン

### フローチャート（横並び）
```html
<div class="flow">
  <div class="flow-step"><h3>Step 1</h3><p>説明</p></div>
  <div class="flow-arrow">→</div>
  <div class="flow-step"><h3>Step 2</h3><p>説明</p></div>
</div>
```

### カードグリッド（3カラム）
```html
<div class="cols-3">
  <div class="card"><span class="tag">01</span><h3>タイトル</h3><p>説明</p></div>
  <div class="card"><span class="tag">02</span><h3>タイトル</h3><p>説明</p></div>
  <div class="card"><span class="tag">03</span><h3>タイトル</h3><p>説明</p></div>
</div>
```

### 数字ハイライト
```html
<div class="cols-3">
  <div class="stat"><span class="number">42%</span><span class="label">説明</span></div>
  ...
</div>
```

---

## 新しいデッキを作るとき

1. `decks/` に新しいフォルダを作る（例: `decks/02_my-talk/`）
2. `decks/01_sample/index.html` をコピーして編集
3. `../../engine/` と `../../theme/` へのパスはそのまま維持
4. スライド総数を変えたら `slide-counter` の分母を更新

---

## 操作方法

### キーボード

| キー | 操作 |
|------|------|
| → / ↓ / Space | 次のスライド |
| ← / ↑ | 前のスライド |
| F | フルスクリーン切替 |

### クリック操作

| クリック位置 | 操作 |
|------------|------|
| 画面の右半分 | 次のスライド |
| 画面の左半分 | 前のスライド |

`engine/slide.js` でデッキの `getBoundingClientRect()` を基準にクリック位置を判定する。ナビUI（ボタン）上のクリックは無視される。

---

## engine/slide.js の共通機能

`engine/slide.js` には以下の機能が組み込まれている。デッキ側でインラインスクリプトを書く必要はない。

### URLハッシュ連動（自動）

- スライド移動時にURLが `index.html#5` のように自動更新される
- ページリロード時にハッシュを読み取り、同じスライドに復元する
- `history.replaceState` を使用し、ブラウザの戻る/進む履歴を汚さない
- MutationObserver でスライドの `is-active` クラス変更を自動監視

### 外部API

| API | 用途 |
|-----|------|
| `window.__slideShow(n)` | スライド番号（0ベース）に直接移動 |
| `window.__initProgressBar(segments)` | 進捗インジケータを初期化（セグメント配列を渡す） |

### デッキ側で書くこと

進捗インジケータを使わない場合、`_foot.html`（またはデッキ末尾）は `<script src="../../engine/slide.js"></script>` だけでよい。
進捗インジケータを使う場合のみ、セグメント定義を書く（後述）。

---

## パーツベースのビルドシステム（大規模デッキ向け）

スライド数が50枚を超える場合は、セクション単位でファイルを分割して管理する。

### ディレクトリ構成

```
decks/{name}/
├── parts/
│   ├── _head.html          ← DOCTYPE・CSS変数・デッキ固有スタイル
│   ├── 00_opening.html     ← セクション単位のスライド群
│   ├── 01_session1.html
│   ├── 02_session2.html
│   ├── ...
│   ├── _foot.html          ← ナビUI・進捗バー・URLハッシュ・script
├── build.sh                ← パーツ結合スクリプト
└── index.html              ← build.sh で生成（直接編集しない）
```

### build.sh の基本形

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
cat parts/_head.html \
    parts/00_opening.html \
    parts/01_session1.html \
    parts/02_session2.html \
    parts/_foot.html > index.html
echo "Built index.html ($(grep -c 'class="slide ' index.html) slides)"
```

### 運用ルール

- `index.html` は直接編集しない（`build.sh` で再生成）
- **スライド枚数が変わったら** `_foot.html` のカウンター分母と進捗バーセグメントを必ず更新
- 各パーツの先頭にHTMLコメントで含まれるスライド範囲を記載

---

## セグメント式進捗インジケータ（オプション）

長時間の研修やセッション区切りがあるデッキには、セグメント式進捗インジケータを追加できる。セッション名・現在ページ番号・全体ページ数を表示し、聴衆がプレゼンのどこにいるかを一目で把握できる。

### CSS（デッキの `<style>` ブロックまたは `_head.html` に追加）

```css
/* ── 進捗インジケータ（セグメント式・ラベル付き） ── */
.progress-bar {
  position: fixed;
  bottom: 0;
  left: 0;
  width: 100%;
  height: 54px;
  display: flex;
  gap: 2px;
  z-index: 200;
  padding: 0 2px;
  font-family: var(--font-mono);
}
.progress-seg {
  height: 100%;
  position: relative;
  background: rgba(255,255,255,.15);
  overflow: hidden;
  display: flex;
  align-items: center;
  justify-content: center;
}
.progress-seg-fill {
  position: absolute;
  left: 0; top: 0; bottom: 0;
  width: 0%;
  background: var(--color-accent);
  transition: width .3s ease;
}
.progress-seg-label {
  position: relative;
  z-index: 1;
  font-size: 24px;
  font-weight: 600;
  color: rgba(0,0,0,.7);       /* 灰色背景では黒文字 */
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  padding: 0 6px;
  letter-spacing: .02em;
}
.progress-seg.active { background: rgba(0,51,255,.18); }  /* アクティブセグメント全体をアクセント色の薄塗りに */
.progress-seg.active .progress-seg-label { color: #fff; }   /* アクセント色背景では白文字 */
.progress-seg.done .progress-seg-label { color: rgba(255,255,255,.9); }
.progress-seg.done .progress-seg-fill { width: 100% !important; }
@media print { .progress-bar { display: none !important; } }
```

### 表示状態

| 状態 | 背景色 | フィル | ラベル色 | ラベル内容 |
|------|--------|--------|---------|-----------|
| 未到達 | `rgba(255,255,255,.15)` | なし | 黒 `rgba(0,0,0,.7)` | セッション名のみ |
| **アクティブ** | `rgba(0,51,255,.18)`（アクセント色の薄塗り） | アクセント色で進行表示 | 白 `#fff` | セッション名 + `[現在/全体]` |
| 完了 | アクセント色100% | 全幅 | 白 `rgba(255,255,255,.9)` | セッション名のみ |

### HTML（`</div><!-- /.deck -->` の後に配置）

```html
<div class="progress-bar" id="progress-bar"></div>
```

### JavaScript（`_foot.html` に記述）

描画・更新ロジックは `engine/slide.js` の `__initProgressBar` に集約済み。デッキ側はセグメント定義を渡すだけでよい。

```html
<script src="../../engine/slide.js"></script>
<script>
// デッキ固有: セグメント定義のみ
window.__updateProgress = window.__initProgressBar([
  { label: 'Opening',   start: 0,  end: 9  },
  { label: 'Session 1', start: 10, end: 24 },
  // ... セクション構成に合わせて定義
]);
if (window.__updateProgress) window.__updateProgress();
</script>
```

各セグメントの `start` / `end` はスライドの0ベースインデックス。幅は `flex: (end - start + 1)` でスライド枚数に比例。クリックでそのセクションの先頭に直接ジャンプする。

### 進捗インジケータを使わない場合

`<div id="progress-bar">` と `<script>` 内のセグメント定義を省略し、`<script src="../../engine/slide.js"></script>` だけを記述する。URLハッシュ連動やクリック操作は `slide.js` が自動で有効化する。

---

## スライドタイプ・ユーティリティの追加方法

### 新しいスライドタイプを追加する手順

1. `theme/sample.css` にスタイルを追加
2. クラス名は `.slide-{type}` の命名規則に従う
3. `<section class="slide slide-{type}">` で使用
4. `CLAUDE.md` のスライドタイプ一覧に追記

### 新しいユーティリティを追加する手順

1. `theme/sample.css` の「ユーティリティクラス」セクションに追加
2. CSS変数を活用して、テーマ変更に追従させる
3. `CLAUDE.md` のユーティリティ一覧に追記
