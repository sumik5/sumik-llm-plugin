# デザイントークン リファレンス

デザイントークンの階層構造・命名規則・Figmaバリアブル管理の詳細リファレンス。

---

## 1. トークン階層モデル

デザイントークンは3層に分類する。

```
Primitive（原子値）
  ↓
Theme / Alias（テーマ参照）
  ↓
Semantic（意味付き）
```

| 層 | 目的 | 変更頻度 | 公開範囲 |
|----|------|---------|---------|
| Primitive | 具体的な色・サイズの全一覧 | 低 | 内部のみ（非公開） |
| Theme/Alias | ブランドのロールに対する参照 | 中 | 内部のみ（非公開） |
| Semantic | UIの用途・文脈に紐付く値 | 高 | 公開（エンジニア参照） |

---

## 2. カラーシステム設計

### 2-1. プリミティブカラー

すべての色の原子値。HSLやHEXで定義し、番号スケールで段階的に管理する。

**命名規則**: `color/{hue}/{number}`

```
color/gray/10    → #F5F5F5（最も明るい）
color/gray/20    → #EBEBEB
color/gray/30    → #D6D6D6
...
color/gray/90    → #1A1A1A（最も暗い）

color/blue/10    → #EBF2FF
color/blue/30    → #92B4E8
color/blue/50    → #2563EB  （ベースカラー）
color/blue/70    → #1A42A0
color/blue/90    → #0D2156
```

スケール番号の指針：
- 10〜30: 明るい（ライトモードの背景・境界線に使用）
- 50: ベースカラー（アクセントや通常状態）
- 70〜90: 暗い（テキスト・強調）

### 2-2. テーマカラー（Alias）

ブランドのロールに対してプリミティブカラーを割り当てる中間層。

**命名規則**: `color/{role}/{number}`

```
color/primary/10  → color/blue/10 を参照
color/primary/30  → color/blue/30 を参照
color/primary/50  → color/blue/50 を参照
color/primary/70  → color/blue/70 を参照
color/primary/90  → color/blue/90 を参照

color/neutral/10  → color/gray/10 を参照
color/neutral/50  → color/gray/50 を参照
color/neutral/90  → color/gray/90 を参照

color/danger/50   → color/red/50 を参照
color/success/50  → color/green/50 を参照
color/warning/50  → color/yellow/50 を参照
```

### 2-3. セマンティックカラー

UIの用途・文脈に紐付くトークン。エンジニアが実際に参照する公開層。

#### カラー命名パターン

**基本パターン**: `color/{property}/{type}`

```
color/text/default          → 通常テキスト
color/text/subtle           → 補助テキスト（プレースホルダー等）
color/text/on-primary       → プライマリ背景上のテキスト
color/text/disabled         → 無効状態のテキスト
color/text/link             → リンクテキスト

color/background/default    → 画面背景
color/background/subtle     → サブ背景（カード等）
color/background/inverse    → インバース背景
color/background/disabled   → 無効状態の背景

color/border/default        → 通常の境界線
color/border/subtle         → 薄い境界線
color/border/strong         → 強調境界線
```

**コンテキスト特化パターン**: `color/{property}/{context}/{state}`

```
color/background/primary-action/enabled   → プライマリボタン通常時
color/background/primary-action/hovered   → プライマリボタンホバー時
color/background/primary-action/pressed   → プライマリボタン押下時
color/background/primary-action/disabled  → プライマリボタン無効時

color/background/secondary-action/enabled
color/background/secondary-action/hovered

color/text/primary-action/enabled         → プライマリボタン上のテキスト
color/text/primary-action/disabled
```

#### セマンティックカラーのライト/ダーク対応

同一トークン名で、モードに応じた値を参照先として切り替える。

| トークン | ライトモード参照先 | ダークモード参照先 |
|---------|----------------|----------------|
| `color/text/default` | `color/neutral/90` | `color/neutral/10` |
| `color/background/default` | `color/neutral/10` | `color/neutral/90` |
| `color/background/primary-action/enabled` | `color/primary/50` | `color/primary/40` |

---

## 3. タイポグラフィトークン

### 3-1. プリミティブタイポグラフィ

フォントサイズと行間の原子値。スケールに番号を付けて管理する。

**フォントサイズスケール（9段階）**

```
font-size/10  → 10px
font-size/20  → 12px
font-size/30  → 14px
font-size/40  → 16px（基準サイズ）
font-size/50  → 18px
font-size/60  → 20px
font-size/70  → 24px
font-size/80  → 30px
font-size/90  → 36px
```

**行間スケール（対応）**

```
line-height/10  → 1.2（見出し向け）
line-height/30  → 1.5（標準本文）
line-height/50  → 1.8（読みやすい長文）
```

**文字間隔**

```
letter-spacing/tight    → -0.02em
letter-spacing/normal   → 0em
letter-spacing/wide     → 0.05em
```

### 3-2. コンポジットタイポグラフィ

プリミティブを組み合わせた文脈別定義。Figmaのテキストスタイルに対応する。

**命名規則**: `typography/{context}/{size}/{weight}`

```
typography/heading/xl/bold    → font-size/90, line-height/10, Bold
typography/heading/lg/bold    → font-size/80, line-height/10, Bold
typography/heading/md/bold    → font-size/70, line-height/20, Bold
typography/heading/sm/bold    → font-size/60, line-height/20, SemiBold

typography/body/lg/regular    → font-size/50, line-height/30, Regular
typography/body/md/regular    → font-size/40, line-height/30, Regular
typography/body/sm/regular    → font-size/30, line-height/30, Regular

typography/label/md/medium    → font-size/40, line-height/10, Medium
typography/label/sm/medium    → font-size/30, line-height/10, Medium

typography/caption/sm/regular → font-size/20, line-height/30, Regular
```

---

## 4. 数値トークン

### 4-1. スペーシング

8pxグリッドに基づくスペーシングスケール。

```
spacing/0   → 0px
spacing/1   → 4px
spacing/2   → 8px
spacing/3   → 12px
spacing/4   → 16px
spacing/5   → 20px
spacing/6   → 24px
spacing/8   → 32px
spacing/10  → 40px
spacing/12  → 48px
spacing/16  → 64px
spacing/20  → 80px
```

### 4-2. 角の半径

```
border-radius/none   → 0px
border-radius/sm     → 4px
border-radius/md     → 8px
border-radius/lg     → 12px
border-radius/xl     → 16px
border-radius/2xl    → 24px
border-radius/full   → 9999px（ピル形状）
```

### 4-3. 線幅

```
border-width/thin    → 1px
border-width/medium  → 2px
border-width/thick   → 4px
```

### 4-4. 不透明度

```
opacity/0    → 0%
opacity/10   → 10%
opacity/20   → 20%
opacity/30   → 30%
opacity/50   → 50%
opacity/70   → 70%
opacity/100  → 100%
```

### 4-5. エレベーション（シャドウ）

```
elevation/0  → なし
elevation/1  → 0 1px 3px rgba(0,0,0,0.12)    （カード等）
elevation/2  → 0 4px 12px rgba(0,0,0,0.15)   （ドロップダウン）
elevation/3  → 0 8px 24px rgba(0,0,0,0.18)   （モーダル）
elevation/4  → 0 16px 48px rgba(0,0,0,0.20)  （通知・トースト）
```

---

## 5. Figmaバリアブルコレクション設計

### 5-1. コレクション構成

| コレクション名 | 公開 | 用途 |
|-------------|-----|------|
| `_PrimitiveColor` | 非公開 | プリミティブカラー全一覧 |
| `_ThemeColor` | 非公開 | テーマ/エイリアスカラー |
| `SemanticColor` | **公開** | セマンティックカラー（エンジニア参照） |
| `Typography` | 公開 | フォントサイズ・行間等 |
| `Token` | 公開 | spacing, border-radius, border-width等 |
| `Breakpoint` | 公開 | ブレイクポイント値 |

> **命名規則**: コレクション名の先頭に `_` を付けると非公開（ライブラリ公開時に隠れる）。内部用の中間層は非公開にする。

### 5-2. モード設計

コレクションごとにモードを定義する。

| コレクション | モード |
|------------|-------|
| `_PrimitiveColor` | （モードなし：固定値） |
| `_ThemeColor` | Default / Alternative（ブランド切替等） |
| `SemanticColor` | Light / Dark |
| `Breakpoint` | xxl / xl / lg / md / sm / xs |

ダークモードはSemanticColorコレクションのモード切替で実現する。PrimitiveとThemeは変更せず、参照先のみを変える設計が保守性を高める。

### 5-3. ブレイクポイントバリアブル

| モード名 | 画面幅 | カラム数 | ガター |
|---------|-------|---------|-------|
| xxl | ≥ 1400px | 12 | 24px |
| xl  | ≥ 1200px | 12 | 24px |
| lg  | ≥ 992px  | 12 | 16px |
| md  | ≥ 768px  | 8  | 16px |
| sm  | ≥ 576px  | 4  | 16px |
| xs  | < 576px  | 2  | 8px  |

コンポーネントのレイアウトプロパティに `Breakpoint` コレクションのバリアブルを適用すると、モード切替でレスポンシブ確認が可能になる。

---

## 6. アクセシビリティ基準

### コントラスト比（WCAG 2.1）

| レベル | 通常テキスト（< 18pt） | 大きなテキスト（≥ 18pt / ≥ 14pt Bold） |
|-------|---------------------|-------------------------------------|
| AA（推奨最低限） | 4.5:1 以上 | 3:1 以上 |
| AAA（理想） | 7:1 以上 | 4.5:1 以上 |

セマンティックカラーの設計時は、`color/text/*` と `color/background/*` の組み合わせごとにコントラスト比を検証する。Figmaのコントラストグリッドプラグインを使うと全組み合わせを一覧できる。

---

## 7. 命名規則まとめ

| 種別 | パターン | 例 |
|------|---------|-----|
| プリミティブカラー | `color/{hue}/{number}` | `color/blue/50` |
| テーマカラー | `color/{role}/{number}` | `color/primary/50` |
| セマンティックカラー（基本） | `color/{property}/{type}` | `color/text/default` |
| セマンティックカラー（コンテキスト） | `color/{property}/{context}/{state}` | `color/background/primary-action/enabled` |
| フォントサイズ | `font-size/{number}` | `font-size/40` |
| 行間 | `line-height/{number}` | `line-height/30` |
| コンポジットタイポ | `typography/{context}/{size}/{weight}` | `typography/body/md/regular` |
| スペーシング | `spacing/{number}` | `spacing/4` |
| 角の半径 | `border-radius/{size}` | `border-radius/md` |
| 線幅 | `border-width/{size}` | `border-width/thin` |
| 不透明度 | `opacity/{number}` | `opacity/50` |
| エレベーション | `elevation/{number}` | `elevation/2` |
