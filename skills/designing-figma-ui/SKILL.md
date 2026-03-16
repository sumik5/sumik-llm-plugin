---
name: designing-figma-ui
description: >-
  Guides Figma-based UI design workflow from wireframes through prototyping,
  detailed design, and developer handoff. Covers Auto Layout, components,
  variants, color/text style systems, dark mode, UI states (5 states),
  interactive components, plugin workflows (Unsplash, Content Reel),
  file organization, and engineer collaboration (Inspect/Design tabs).
  Use when designing mobile app UI in Figma or preparing design handoff.
  For Figma MCP tool integration (design-to-code automation),
  use implementing-figma instead.
  For design token architecture and variable systems,
  use constructing-figma-design-systems instead.
---

# Figma UIデザインワークフロー

## 使用タイミング

- モバイルアプリのUIデザインをFigmaで行うとき
- ワイヤーフレームからプロトタイプ・詳細デザインへ進めるとき
- エンジニアへのデザインハンドオフを準備するとき
- Figmaのコンポーネント・スタイル・バリアント設計を行うとき

> 他スキルとの使い分け:
> - Figma MCP ツール統合（デザイン→コード自動変換）→ `implementing-figma`
> - デザイントークンのアーキテクチャ・Variables設計 → `constructing-figma-design-systems`

---

## Phase 0: 企画確認とユーザーフロー

デザイン作業を開始する前に、**企画段階のアウトプット（ユーザーフロー）を確認**することで、設計すべき画面と遷移を把握する。

### ユーザーフローとは

企画からデザインに落とし込む際に作成される資料。ユーザーが各画面で「何を見て（See）何をするか（Do）」を明確化したもの。

**記述パターン（See/Do形式）:**

| 画面 | See（見えるもの） | Do（操作） |
|------|-----------------|-----------|
| ホーム画面 | 投稿一覧、ストーリー一覧 | 新規投稿ボタンのタップ、ストーリー選択、いいね |
| 投稿作成画面 | 写真ライブラリ | 写真の選択、完了ボタンのタップ |
| 詳細入力画面 | 投稿フォーム | 公開ボタンのタップ |

**ユーザーストーリーとの関係:**
- ユーザーストーリー: 機能がユーザーにどんな価値を提供するかを説明（抽象度が高い）
- ユーザーフロー: 具体的な画面と操作を示す（ユーザーストーリーをより具体化したもの）

**デザイン前に確認すべき事項:**
- 設計対象の画面数と遷移パターン
- 各画面の主要アクション（Do）に対応するUIコンポーネント
- 用語の定義（「ストーリー」「投稿」など、チーム内で統一する言葉）

---

## 制作ワークフロー概要

モバイルアプリUIの設計は以下の4フェーズで進める。

```
Phase 1: ワイヤーフレーム
  → 8ptグリッド設定、Safe Area確保、UI Kit活用、画面骨格設計

Phase 2: プロトタイプ
  → Flow管理、インタラクション設定、Smart Animate、遷移確認

Phase 3: 詳細デザイン
  → コンポーネント化、バリアント設計、カラースタイル/テキストスタイル登録
  → UIスタック（5状態）の設計、ダークモード対応

Phase 4: ハンドオフ
  → スタイル命名規則整備、Inspect/Designタブ確認環境の整備、画像書き出し設定
```

---

## 単位リファレンス

UIデザインの「1」は物理ピクセルではなく**論理単位**を指す。デバイスごとに倍率（@nx）が異なるため、レイアウトは論理単位で設計し、書き出し時に物理ピクセルに変換する。

| 単位 | プラットフォーム | 説明 |
|------|----------------|------|
| `pt`（Point） | iOS | iOSアプリのレイアウト単位。@2x/@3xで物理ピクセルに変換 |
| `dp`（Density-independent pixel） | Android | ptと同概念。ピクセル密度カテゴリ（ldpi〜xxxhdpi）で倍率が決まる |
| `px`（CSSピクセル） | Web | Webレイアウト単位。論理ピクセル（デバイスピクセルと区別） |
| Figmaの数値 | 全プラットフォーム | ptやCSSピクセルと同じ論理単位として扱う |

### iOSデバイス別スケール

| デバイス | 解像度（pt） | 倍率 |
|---------|------------|------|
| iPhone SE (2nd Gen) | 375 × 667pt | @2x |
| iPhone 13 mini | 375 × 812pt | @2.88x |
| iPhone 13 | 390 × 844pt | @3x |

### Android ピクセル密度と倍率

| 識別子 | ピクセル密度 | 倍率 |
|--------|------------|------|
| mdpi | ~160dpi | @1x |
| xhdpi | ~320dpi | @2x |
| xxhdpi | ~480dpi | @3x |
| xxxhdpi | ~640dpi | @4x |

---

## コアプリンシプル

### 1. 8ptグリッドシステム

すべてのレイアウト値を8の倍数（または4の倍数）で統一する手法。

**採用理由:**
- デザイナー間でレイアウト意思決定が迅速になる（10ptより8pt、15ptより16ptを選ぶ基準が明確）
- @0.75x〜@4xのどの倍率でも整数ピクセルになり、書き出し画像が鮮明になる
- 複数デザイナーによる一貫性維持

**Figma設定:**
- ナッジ移動距離を8ptに設定（環境設定で変更）
- Layout gridのSizeを8に設定してガイドとして使用
- グリッドFrameを作成してロック（意図せぬ編集防止）

**ナッジ設定（推奨値）:**

クイックアクション（`⌘` + `/`）で「ナッジ」と検索し、以下の値を設定する。

| 種類 | 推奨値 | 用途 |
|------|-------|------|
| 小さな調整（矢印キー） | `1pt` | ピクセル単位の微調整 |
| 大きな調整（`Shift` + 矢印キー） | `8pt` | 8ptグリッドに沿った移動 |

**スナップ設定（全ON推奨）:**

クイックアクションで「スナップ」と検索し、以下の3項目がすべて有効になっていることを確認する。

- ピクセルグリッドにスナップ（端数ピクセルを防ぐ）
- ジオメトリにスナップ（エッジ・中心への吸着）
- オブジェクトにスナップ（他要素のエッジ・中心への吸着）

> アイコン等のベクターパス編集時はスナップが邪魔になる場合がある。編集中のみ一時的に無効化し、完了後に必ず再有効化する。

**Safe Area設定（iOS）:**

| デバイス | 上部余白 | 下部余白 |
|---------|---------|---------|
| iPhone SE (2nd Gen) / iPhone 8 | 20pt | 0pt |
| iPhone 11 Pro / X | 44pt | 34pt |
| iPhone 12/13 mini | 50pt | 34pt |
| iPhone 12/13 | 47pt | 34pt |

Androidでは同等の概念を「Cutout Area」と呼ぶ。

---

### 2. コンポーネント駆動設計

#### コンポーネント作成基準

- 同じUIを2箇所以上で使う場合はコンポーネント化を検討
- 名前にスラッシュ（/）を使ってグループ階層化: `Button/Primary`, `Icon/Heart`
- コンポーネントはUIの「雛形」。レイアウトにはインスタンスを配置する

#### バリアントとコンポーネントプロパティ

| 機能 | 用途 | 例 |
|------|------|-----|
| バリアント | 複数状態のコンポーネントをセット管理 | `State: Default/Hover/Disabled` |
| ブール値プロパティ | 要素のOn/Off切り替え | `Rounded: true/false` |
| テキストプロパティ | テキスト内容の一元管理 | ラベルの差し替え |
| インスタンス置換プロパティ | 子コンポーネントの差し替え | アイコン種類の切り替え |

#### Auto Layout設計パターン

| Resizing設定 | 動作 | 使いどころ |
|-------------|------|----------|
| Hug contents | 子要素を包むようにサイズ変更 | テキスト量が変わるボタン、カード |
| Fixed | サイズ固定 | 固定幅のコンテナ |
| Fill container | 親Frameを埋めるようにリサイズ | 可変幅の要素 |

**Auto Layout の入れ子パターン:**
- 縦スクロールリスト: 縦方向Auto Layout（Vertical direction）
- 横並びボタン群: 横方向Auto Layout（Horizontal direction）
- カード内レイアウト: Auto LayoutのPaddingで内部余白を制御

---

### 3. スタイル命名規則

スタイル名は**カラー・テキストともにエンジニアと合意した命名規則**を使用する。

#### カラースタイルの命名規則

```
[Mode] / [Element] / [Type] (/ [State])
```

| 部分 | 説明 | 例 |
|------|------|-----|
| Mode | ライト/ダーク | `Light`, `Dark` |
| Element | 適用するUI要素 | `Label`, `Background`, `Button Label` |
| Type | バリエーション（数字 or 英単語） | `1`, `2`, `Primary` |
| State | 状態（省略可） | `Default`, `Active` |

**登録例:**

| スタイル名 | カラー値 | 用途 |
|----------|---------|------|
| `Light/Label/1` | `#000000` | ライトモードのテキスト・アイコン |
| `Light/Label/2` | `#8E8E8E` | ライトモードの補助テキスト |
| `Light/Background/1` | `#FFFFFF` | ライトモードの背景 |
| `Dark/Label/1` | `#FFFFFF` | ダークモードのテキスト・アイコン |
| `Dark/Background/1` | `#000000` | ダークモードの背景 |

#### テキストスタイルの命名規則

```
[Mode] / [Role] / [Size]
```

例: `Light/Heading/L`, `Light/Body/M`, `Light/Caption/S`

---

### 4. UIスタック（5状態）

すべての画面に対して以下の5状態を設計する。理想状態（Ideal State）だけ設計するのはアンチパターン。

| 状態 | 説明 | デザインポイント |
|------|------|---------------|
| **① Blank State** | 表示すべきデータが何もない状態（初回起動、検索0件） | ユーザー行動を促すCTAを配置。「見つかりません」だけでは不十分 |
| **② Loading State** | データ読み込み中 | コンテンツが想起されるプレースホルダー（スケルトンUI）を配置 |
| **③ Partial State** | 部分的には満たされているが完全ではない状態 | フォロー数が少ないSNSフィード等。補完を促すUIを追加 |
| **④ Error State** | 通信エラー、入力エラー等 | 原因と回復方法を伝えるメッセージを配置 |
| **⑤ Ideal State** | すべてのデータが揃った理想状態 | プラクティス編で最初に設計する基本デザイン |

**Figmaでの実装方法:**
- コンポーネントのバリアントとして各状態を管理
- レイヤー命名: `Home/Blank`, `Home/Loading`, `Home/Error`, `Home`（Ideal）

---

## クイックリファレンス

### フェーズ別チェックリスト

**Phase 1: ワイヤーフレーム**
- [ ] 8ptグリッドのLayout grid設定（Size: 8）
- [ ] Safe Areaフレームを作成してロック
- [ ] デバイスフレームサイズ決定（例: iPhone 13 = 390 × 844pt）
- [ ] 外部UI Kit（iOS/Material Design）の活用検討

**Phase 2: プロトタイプ**
- [ ] FlowのStart点を設定
- [ ] インタラクション（Trigger/Action/Animation）を設定
- [ ] Smart Animateを使った状態遷移
- [ ] デバイスプレビュー設定（右パネル Prototype タブ）

**Phase 3: 詳細デザイン**
- [ ] コンポーネント化（繰り返し使う要素）
- [ ] バリアント設計（状態管理）
- [ ] カラースタイルを命名規則に従って登録
- [ ] テキストスタイルを登録
- [ ] UIスタック（5状態）の設計
- [ ] ダークモード対応（Dark/xxx スタイル登録）
- [ ] インタラクティブコンポーネントの設定

**Phase 4: ハンドオフ**
- [ ] 全コンポーネントにカラースタイル適用済み
- [ ] 全テキストにテキストスタイル適用済み
- [ ] 画像書き出し設定（@2x/@3x）
- [ ] Inspectタブでエンジニアが確認できる状態か確認
- [ ] Constraintsが意図通りに設定されているか確認

---

## ユーザー確認の原則（AskUserQuestion）

**判断が必要な場面では推測で進めず、必ずAskUserQuestionでユーザーに確認する。**

### 確認すべき場面

- **カラースタイル命名規則**: プロジェクト固有の命名体系がある場合
  - 例: `Light/Label/1` vs `color/text/primary` vs `semantic/text/primary`
- **デバイス優先順位**: iOSファースト vs Androidファースト vs 両対応
  - フレームサイズ・Safe Area・書き出し倍率に影響する
- **コンポーネント粒度**: 細かく分割 vs 大きなコンポーネント
  - 例: アイコン単体コンポーネント vs アイコン+ラベルのセットコンポーネント
- **ダークモード対応タイミング**: 初期段階から対応 vs 後から対応
  - 後から追加する場合、カラースタイル命名規則の設計方針が変わる

### 確認不要な場面

- 8ptグリッドの採用（業界標準として推奨）
- UIスタック5状態の設計（すべての画面で必須）
- コンポーネントへのカラースタイル適用（ハンドオフ品質のため必須）

```python
# 確認例: デバイス優先順位の確認
AskUserQuestion(
    questions=[{
        "question": "デザインのターゲットデバイスを教えてください。フレームサイズとSafe Areaの設定に影響します。",
        "header": "デバイス優先順位",
        "options": [
            {"label": "iOSファースト（iPhone 13: 390 × 844pt）", "description": "Appleデバイス向けメインデザイン"},
            {"label": "Androidファースト（360 × 800dp）", "description": "Androidデバイス向けメインデザイン"},
            {"label": "両対応（iOS + Android）", "description": "プラットフォームごとにデザインを作成"}
        ],
        "multiSelect": False
    }]
)
```

---

## エンジニア協業のポイント

### Inspectタブ（全権限で利用可能）

エンジニアがデザインを実装するための情報源。

| 確認できる情報 | 詳細 |
|-------------|------|
| テキスト設定 | フォント名、ウェイト、サイズ、行間 |
| カラー | 名前（スタイル名）と値（HEX/RGB） |
| コードヒント | CSS / iOS / Android 形式で参照可能 |
| レイアウト制約 | Auto Layout適用時のみConstraintsが確認可能 |
| Flow | 画面遷移の視覚化（目玉アイコンをクリック） |

> テキストやカラーに名前が付いていない場合はスタイル適用漏れの可能性がある。ハンドオフ前に必ず確認する。

### Designタブ（Editor権限が必要）

- コンポーネントプロパティの確認と切り替え
- Constraintsの確認
- 画像書き出し（@2x/@3x同時書き出し）

### エンジニア向けショートカット

| 操作 | Mac | Windows |
|------|-----|---------|
| コメントモード | `C` | `C` |
| 選択ツール | `V` | `V` |
| 選択画面にズーム | `Shift` + `2` | `Shift` + `2` |
| 全画面表示 | `Shift` + `1` | `Shift` + `1` |
| ツールバー非表示 | `⌘` + `¥` | `Ctrl` + `¥` |
| クリップボードにコピー（貼り付け用） | `⌘` + `Shift` + `C` | `Ctrl` + `Shift` + `C` |

---

## 詳細ガイドへのリンク

より詳しい実装パターンは以下の参照ファイルを確認する。

| ファイル | 内容 |
|---------|------|
| [`references/PRODUCTION-WORKFLOW.md`](references/PRODUCTION-WORKFLOW.md) | Auto Layout設計パターン、コンポーネント/バリアント設計、ワイヤーフレーム制作、プロトタイプ設計 |
| [`references/HANDOFF-DESIGN.md`](references/HANDOFF-DESIGN.md) | カラースタイル設計詳細、ダークモード対応手順、テキストスタイル設計、インタラクティブコンポーネント |
| [`references/ENGINEER-COLLABORATION.md`](references/ENGINEER-COLLABORATION.md) | Inspect/Design/Prototypeタブ活用法、コメント機能、画像書き出し設定、PdM向けFigma活用 |
| [`references/PLUGIN-WORKFLOW.md`](references/PLUGIN-WORKFLOW.md) | プラグイン活用パターン（Unsplash・Content Reel）、貼り付けて置換、その他推奨プラグイン |
