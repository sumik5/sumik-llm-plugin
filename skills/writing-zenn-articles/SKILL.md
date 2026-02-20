---
name: writing-zenn-articles
description: >-
  Zenn技術記事の作成・投稿ワークフローガイド（フロントマター仕様・命名規則・品質チェック・Lint設定）。
  Use when creating or publishing technical articles on Zenn platform, writing tech blog posts, or setting up Zenn CLI projects.
  Triggers: "zenn", "記事", "ブログ", "技術記事", "投稿"
  For general writing principles (structure, sentence craft, style), use writing-effective-prose instead.
---

## 概要

Zenn CLIベースの技術記事リポジトリにおける記事作成・品質管理のワークフロースキル。記事のフロントマター仕様、命名規則、Zenn固有のMarkdown記法、画像管理、Lintチェックまでを網羅する。

---

## 記事ファイル仕様

### ファイル命名規則

- 形式: `NNN-slug-name.md`（NNN: 3桁の連番、slug: ケバブケース）
- 配置: `articles/` ディレクトリ
- 例: `001-certified-blockchain.md`, `020-claude-code-team-notification.md`

### フロントマター（必須）

```yaml
---
title: "記事タイトル"
emoji: "🎯"
type: "tech"           # "tech"（技術記事）または "idea"（アイデア）
topics: ["tag1", "tag2"]  # 英数字小文字、最大5個
published: false        # 公開状態
---
```

| フィールド | 必須 | 値 | 説明 |
|-----------|------|-----|------|
| title | ✓ | 文字列 | 記事タイトル（日本語OK） |
| emoji | ✓ | 絵文字1個 | 記事アイコン |
| type | ✓ | "tech" / "idea" | 記事種別 |
| topics | ✓ | 文字列配列 | トピックタグ（英数字小文字、最大5個） |
| published | ✓ | boolean | 公開状態 |

---

## 本文の書き方

### 見出しルール

- H2（##）から開始。H1は使用しない
- 構成例: はじめに → 本題セクション群 → おわりに

### Zenn固有のMarkdown記法

```markdown
:::message
情報ブロック（注意書き、補足情報）
:::

:::message alert
警告ブロック（重要な注意事項）
:::
```

### コードブロック

- 必ず言語指定を付ける（```bash, ```json, ```typescript 等）
- ファイルパスはコードブロック直前にバッククォートで記載

### 画像管理

- 配置: `images/NNN/` ディレクトリ（NNN = 記事番号）
- 参照: `![alt text](/images/NNN/filename.png)`
- GIFアニメーションも対応

---

## ワークフロー

### Step 0: トレンド調査とタイトル設計

記事を書き始める前に、Zennのトレンドを確認してタイトルを設計する。

**トレンド確認**

WebFetchまたはブラウザで以下を確認する:

- `https://zenn.dev` トップページ（注目記事・急上昇）
- `https://zenn.dev/trending` トレンド一覧

**トレンドから読み取るポイント**

- 今週話題の技術・ツール・概念は何か
- 多くのLikeを集めているタイトルのパターン
- 読者が今困っていること・知りたいことの傾向

**タイトル設計パターン**

| パターン | 例 |
|---------|-----|
| 体験型 | 「〇〇してみた」「〇〇を導入した話」 |
| 数値型 | 「〇〇選」「N個の〇〇」「〇〇を50%削減した方法」 |
| 問題解決型 | 「〇〇で困ったときの対処法」「〇〇が動かないときに確認すること」 |
| 逆説・挑発型 | 「〇〇はもう古い」「〇〇をやめた理由」「〇〇は不要だった」 |
| How-to型 | 「〇〇入門」「〇〇の始め方」「〇〇完全ガイド」 |
| 比較型 | 「〇〇 vs △△」「〇〇から△△に移行して分かったこと」 |

**タイトルのチェック**

- 具体的か（「改善しました」ではなく「通知遅延を90%削減しました」）
- 検索されそうか（読者が使いそうなキーワードが入っているか）
- クリックしたくなるか（自分がこのタイトルを見たら開くか）
- 記事の内容と一致しているか（釣りタイトルになっていないか）

### Step 1: 記事番号の決定

```bash
# 既存記事の最大番号を確認
ls articles/ | sort | tail -1
# → 次の番号を使用（例: 020 → 021）
```

### Step 2: 記事ファイル作成

- `articles/NNN-slug-name.md` を作成
- フロントマターを記述（published: false で開始）
- Step 0 で決定したタイトルをフロントマターに設定

### Step 3: 本文執筆

- 既存記事のトーンに合わせた自然な日本語（です・ます調）
- 技術用語はそのまま英語
- 読者が即座に再現できる具体性
- コードは完全なものを掲載（断片ではなく）

### Step 4: 画像の追加（必要に応じて）

```bash
mkdir -p images/NNN
# 画像ファイルを配置
```

### Step 5: 品質チェック

```bash
# Lint全実行
cd /path/to/zenn && pnpm run lint

# 個別実行
pnpm run lint:text        # textlint（日本語品質）
pnpm run lint:markdown    # markdownlint
pnpm run lint:prettier    # Prettier形式チェック

# プレビュー
pnpm run preview
```

### Step 6: 公開

- `published: true` に変更
- GitHubにpush（mainブランチへのマージで自動デプロイ）

---

## 品質チェックリスト

- [ ] タイトルがトレンドを意識したキャッチーなものになっている
- [ ] タイトルが具体的・検索性が高い・クリックしたくなる
- [ ] ファイル名が `NNN-slug-name.md` 形式
- [ ] フロントマターの5フィールドがすべて記入済み
- [ ] topicsが英数字小文字で5個以内
- [ ] 見出しが##から開始
- [ ] コードブロックに言語指定あり
- [ ] 画像パスが `/images/NNN/filename` 形式
- [ ] `:::message` ブロックが正しく閉じている
- [ ] `pnpm run lint` でエラーなし
- [ ] 全角スペースが混入していない
- [ ] 技術用語の表記が統一されている

---

## Lint環境

このZennリポジトリは以下のLintツールを使用:

| ツール | 設定ファイル | 目的 |
|--------|------------|------|
| textlint | `.textlintrc.yml` | 日本語品質チェック |
| markdownlint-cli2 | `.markdownlint-cli2.jsonc` | Markdown形式統一 |
| Prettier | `.prettierrc.yml` | コード・Markdown整形 |
| prh | `prh/` | 表記揺れ検査 |
| cspell | `.cspell.json` | スペルチェック |

---

## 既存記事の参考スタイル

技術記事（type: "tech"）の場合:

1. はじめに - 問題提起・動機
2. 技術解説セクション - 段階的に詳細化
3. コード全文掲載 - 断片ではなく動作する完全なコード
4. おわりに - まとめ・今後の展望・謝辞

---

## 文体ルール

記事執筆時は `writing-effective-prose` スキルのAI臭チェック・文章技法を必ず適用する。

**このリポジトリの統一文体: です・ます調**

- 既存記事はすべてです・ます調で統一されている。だ・である調に変えない
- AI臭除去と文体変更は別問題。文体を維持しつつAI臭だけを除去する
- 自分の体験を交えた語り口。「〜してみました」「〜になりました」等
- 技術用語はそのまま英語

---

## 関連スキル

| スキル | 使い分け |
|--------|---------|
| `writing-effective-prose` | 記事執筆時に必ず併用。AI臭除去・論理構成・技術文書原則 |
