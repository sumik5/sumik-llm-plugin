---
name: generating-google-slides
description: Generates Google Slides presentations from unstructured text via Google Apps Script slideData arrays. Use when creating presentations from meeting notes, proposals, or memos. For frontend UI components, use designing-frontend; for LaTeX documents, use writing-latex instead.
---

# generating-google-slides

## Overview

このスキルは、非構造化されたテキスト（議事録・企画書・提案書・メモ等）からGoogle Apps Script（GAS）フレームワーク用の `slideData` オブジェクト配列を生成し、Google風デザインのプレゼンテーションを自動生成します。

### 主な特徴

- **入力**: 自由形式のテキスト（箇条書き、章立て、段落形式等）
- **出力**: `slideData` JavaScript配列（GASテンプレートに挿入可能）
- **スライドタイプ**: 11種類のパターン（title/section/content/compare/process/timeline/diagram/cards/table/progress/closing）
- **デザイン**: Google公式スライド風（Google Sans、Google Colors、シンプルな余白設計）

### 使用タイミング

- 会議の議事録をスライドに変換したい
- 企画書・提案書のプレゼン資料を自動生成したい
- テキストベースの情報を視覚的に整理したい
- GASテンプレート（BLUEPRINT.md）と組み合わせてスライドを生成したい

### このスキルが対象外とする範囲

- フロントエンドUIコンポーネント作成 → `designing-frontend` スキルを使用
- LaTeX文書作成 → `writing-latex` スキルを使用
- PowerPoint形式の出力 → Google Slides専用

---

## 生成ワークフロー

### ステップ1: コンテキストの完全分解と正規化

**目的**: テキストの意図・目的・聞き手を把握し、章→節→要点への階層マッピングを行う。

- **ユーザー確認の原則**: プレゼンターゲット聴衆が不明確な場合は `AskUserQuestion` ツールで必ず確認
- **階層マッピング**: 章・節・要点を抽出し、論理構造を明確化
- **意図の抽出**: 「提案」「報告」「比較」「プロセス説明」等の意図を特定

### ステップ2: パターン選定と論理ストーリーの再構築

**目的**: 最適なスライドパターンを選定し、説得ライン（ストーリー）を再配列する。

- **パターン選定**: 各節の内容に応じて最適なスライドタイプを選定（詳細は後述）
- **ストーリー設計**: 聴衆の理解を最大化する順序に再配列
- **ユーザー確認**: 章構成の順序に複数の選択肢がある場合は確認

### ステップ3: スライドタイプへのマッピング

**目的**: 各節を具体的なスライドタイプ（11種類）に割り当てる。

| 内容の性質 | 推奨パターン |
|-----------|-------------|
| 2つの対象を比較 | `compare` |
| 時系列・プロセス | `process` または `timeline` |
| マイルストーン・ロードマップ | `timeline` |
| フロー・泳道図 | `diagram` |
| カード状の複数項目 | `cards` |
| 表形式データ | `table` |
| 進捗・達成率 | `progress` |
| 一般的な箇条書き | `content` |

**ユーザー確認**: パターン選定で迷う場合（compare vs table等）は確認

### ステップ4: オブジェクトの厳密な生成

**目的**: スキーマに厳密に準拠した `slideData` オブジェクトを生成する。

#### 必須タスク

1. **スキーマ準拠**: 後述の「slideDataスキーマ定義」に完全一致
2. **エスケープ処理**: 文字列内のバッククォート・改行を除去
3. **インライン強調記法**:
   - `**太字**`: 重要語を強調
   - `[[重要語]]`: 太字＋Googleブルー（#4285F4）で強調
4. **画像URL抽出**: テキスト中の画像URLを抽出し、`images` 配列に格納
5. **スピーカーノート生成**: 各スライドの補足説明を `notes` プロパティに記述

### ステップ5: 自己検証と反復修正

**目的**: 生成したオブジェクトが制約を満たすか検証し、違反があれば修正する。

#### 検証項目

- **文字数上限**: title（35/30/40文字）、subhead（50文字）、箇条書き要素（90文字）
- **改行禁止**: 箇条書き要素内に改行文字（`\n`）が含まれていないか
- **禁止記号**: `■` `→` が使用されていないか
- **句点禁止**: 箇条書き文末に「。」が付いていないか（体言止め推奨）
- **アジェンダ安全装置**: 章が2つ以上の場合のみアジェンダスライド（content）を挿入

### ステップ6: 最終出力

**目的**: BLUEPRINT.mdのテンプレートに `slideData` を埋め込み、実行可能なコードを出力する。

#### 出力形式

```javascript
// BLUEPRINT.md全文のうち、slideData定義ブロックのみを置換
const slideData = [
  // 生成したオブジェクト配列をここに挿入
];
```

**重要**: BLUEPRINT.md全文を出力し、`slideData` 部分のみを生成内容で置換すること。

---

## slideDataスキーマ定義

### 共通プロパティ

すべてのスライドタイプで使用可能:

| プロパティ | 型 | 説明 |
|-----------|-----|------|
| `notes` | `string?` | スピーカーノート（補足説明） |

### スライドタイプ一覧

#### 1. title（表紙）

```javascript
{
  type: 'title',
  title: string,       // 全角35文字以内
  date: string,        // YYYY.MM.DD形式
  notes?: string
}
```

#### 2. section（章見出し）

```javascript
{
  type: 'section',
  title: string,       // 全角30文字以内
  sectionNo?: number,  // 章番号（省略可）
  notes?: string
}
```

#### 3. closing（結び）

```javascript
{
  type: 'closing',
  notes?: string
}
```

#### 4. content（汎用コンテンツ）

```javascript
{
  type: 'content',
  title: string,                // 全角40文字以内
  subhead?: string,             // 全角50文字以内
  points?: string[],            // 各要素90文字以内・改行禁止
  twoColumn?: boolean,          // 2カラムレイアウト
  columns?: [string[], string[]], // 2カラム時の左右配列
  images?: (string | { url: string, caption?: string })[],
  notes?: string
}
```

**注意**: `points` と `columns` は排他的（同時に使用しない）

#### 5. compare（左右比較）

```javascript
{
  type: 'compare',
  title: string,
  subhead?: string,
  leftTitle: string,
  rightTitle: string,
  leftItems: string[],   // 各要素90文字以内
  rightItems: string[],  // 各要素90文字以内
  images?: string[],
  notes?: string
}
```

#### 6. process（プロセス・フロー）

```javascript
{
  type: 'process',
  title: string,
  subhead?: string,
  steps: string[],       // 各ステップ90文字以内
  images?: string[],
  notes?: string
}
```

#### 7. timeline（タイムライン）

```javascript
{
  type: 'timeline',
  title: string,
  subhead?: string,
  milestones: {
    label: string,
    date: string,
    state?: 'done' | 'next' | 'todo'
  }[],
  images?: string[],
  notes?: string
}
```

#### 8. diagram（泳道図・フロー図）

```javascript
{
  type: 'diagram',
  title: string,
  subhead?: string,
  lanes: {
    title: string,
    items: string[]
  }[],
  images?: string[],
  notes?: string
}
```

#### 9. cards（カードレイアウト）

```javascript
{
  type: 'cards',
  title: string,
  subhead?: string,
  columns?: 2 | 3,       // カラム数（デフォルト: 3）
  items: (string | {
    title: string,
    desc?: string
  })[],
  images?: string[],
  notes?: string
}
```

#### 10. table（表）

```javascript
{
  type: 'table',
  title: string,
  subhead?: string,
  headers: string[],     // 列ヘッダー
  rows: string[][],      // データ行
  notes?: string
}
```

#### 11. progress（進捗バー）

```javascript
{
  type: 'progress',
  title: string,
  subhead?: string,
  items: {
    label: string,
    percent: number      // 0-100
  }[],
  notes?: string
}
```

---

## 構成ルール

### 全体構成

スライドは必ず以下の順序で構成する:

```
1. title（表紙）
2. content（アジェンダ、※章が2つ以上のときのみ）
3. section → 本文2〜5枚（章の数だけ繰り返し）
4. closing（結び）
```

#### アジェンダ安全装置

- **章が2つ以上**: アジェンダスライド（content）を挿入
- **章が1つのみ**: アジェンダスライドは挿入しない

### テキスト制限

| 対象 | 制限 |
|------|------|
| `title.title` | 全角35文字以内 |
| `section.title` | 全角30文字以内 |
| 各パターンの `title` | 全角40文字以内 |
| `subhead` | 全角50文字以内 |
| 箇条書き要素 | 各90文字以内・改行禁止 |

### 禁止事項

- **禁止記号**: `■` `→` の使用禁止
- **箇条書き文末**: 句点「。」禁止（体言止め推奨）
- **改行**: 箇条書き要素内に改行文字（`\n`）を含めない

### インライン強調記法

スライド内テキストで使用可能:

| 記法 | 効果 |
|------|------|
| `**太字**` | 太字強調 |
| `[[重要語]]` | 太字＋Googleブルー（#4285F4）強調 |

**例**:

```javascript
points: [
  '**重要**: データ駆動の意思決定を実現',
  '[[AI活用]]により業務効率を30%向上'
]
```

### 日付形式

- `title.date`: `YYYY.MM.DD` 形式（例: `2025.12.31`）
- `timeline.milestones[].date`: 自由形式（例: `2025 Q1`, `2025年1月`）

---

## ユーザー確認の原則

以下の場合は `AskUserQuestion` ツールで必ず確認すること:

| 状況 | 確認内容 |
|------|---------|
| ターゲット聴衆が不明確 | 「この資料のターゲット聴衆は誰ですか？（例: 経営層、開発チーム、顧客）」 |
| 章構成の順序に複数選択肢 | 「章の順序について、以下のどちらが適切ですか？」 |
| パターン選定で迷う | 「この内容は左右比較（compare）と表（table）のどちらが適切ですか？」 |
| 画像の配置方針が不明 | 「画像の配置方針を教えてください（各スライドに分散/特定スライドのみ）」 |

---

## サブファイル参照

より詳細な情報は以下のファイルを参照:

- **[BLUEPRINT.md](BLUEPRINT.md)**: GASテンプレート全文（slideData置換用）
- **[REFERENCE.md](REFERENCE.md)**: パターン詳細仕様、安全ガイドライン、チェックリスト

---

## 実装例

### 入力テキスト

```
# 新規プロダクト提案

## 背景
市場調査により、顧客のニーズが明確になった。

## 提案内容
- AI搭載の分析ツール
- リアルタイムダッシュボード
- 自動レポート生成

## 期待効果
業務効率30%向上、コスト20%削減
```

### 出力 slideData

```javascript
const slideData = [
  {
    type: 'title',
    title: '新規プロダクト提案',
    date: '2025.02.09',
    notes: 'AI搭載の分析ツールに関する提案資料'
  },
  {
    type: 'section',
    title: '背景',
    sectionNo: 1
  },
  {
    type: 'content',
    title: '市場調査による顧客ニーズの明確化',
    points: [
      '顧客ニーズが明確になった'
    ],
    notes: '市場調査の結果、具体的なニーズが特定された'
  },
  {
    type: 'section',
    title: '提案内容',
    sectionNo: 2
  },
  {
    type: 'content',
    title: '3つの主要機能',
    points: [
      '**AI搭載**の分析ツール',
      '[[リアルタイムダッシュボード]]',
      '自動レポート生成'
    ]
  },
  {
    type: 'section',
    title: '期待効果',
    sectionNo: 3
  },
  {
    type: 'progress',
    title: '業務改善の効果',
    items: [
      { label: '業務効率向上', percent: 30 },
      { label: 'コスト削減', percent: 20 }
    ]
  },
  {
    type: 'closing',
    notes: 'ご清聴ありがとうございました'
  }
];
```

---

## トラブルシューティング

### よくある問題

| 問題 | 原因 | 解決策 |
|------|------|--------|
| 文字数オーバー | 原文が長すぎる | 要約・分割して複数スライドに配置 |
| 章が1つだけなのにアジェンダが入る | 安全装置の誤動作 | 章数を確認し、アジェンダを削除 |
| 禁止記号が含まれる | 自動変換ミス | `■` → `・`, `→` → `から` 等に置換 |
| 改行が含まれる | エスケープ漏れ | `\n` を削除または半角スペースに置換 |

### デバッグチェックリスト

1. [ ] 全スライドが有効な `type` を持つか
2. [ ] 必須プロパティ（title等）がすべて存在するか
3. [ ] 文字数制限を満たしているか
4. [ ] 禁止記号・改行・句点が含まれていないか
5. [ ] アジェンダスライドが適切に挿入されているか
6. [ ] 章番号（sectionNo）が連番になっているか

---

## まとめ

このスキルは、以下の6ステップで非構造テキストからGoogle Slides用の `slideData` を生成します:

1. **コンテキスト分解**: 意図・構造を把握
2. **パターン選定**: 最適なスライドタイプを選択
3. **マッピング**: 各節をスライドタイプに割り当て
4. **オブジェクト生成**: スキーマ準拠のJavaScript配列を作成
5. **自己検証**: 制約違反を検出・修正
6. **最終出力**: BLUEPRINT.mdに埋め込み可能な形式で出力

不明点がある場合は、REFERENCE.mdの詳細仕様とチェックリストを参照してください。
