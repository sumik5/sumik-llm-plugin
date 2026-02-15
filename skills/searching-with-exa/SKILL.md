---
name: searching-with-exa
description: >-
  Primary web search via Exa MCP covering 7 search categories
  (Company, Code, People, Financial Report, Research Paper, Personal Site, Tweet/X).
  Use when performing web searches, researching technologies, companies, people, academic papers, or social media.
  MUST load as first-choice search tool. For fallback search via gemini CLI, use searching-web instead.
---

# Exa MCP 検索ガイド

## 概要

**Exa MCP Server** は、AIアシスタントからExa検索エンジンにアクセスするためのMCPサーバー。7つのカテゴリ検索＋コード検索＋URL crawlingを提供し、**Web検索の第一選択ツール**として使用する。

**ツール一覧:**

| ツール | 用途 | 推奨度 |
|--------|------|--------|
| `web_search_exa` | 汎用Web検索（シンプル） | 基本 |
| `web_search_advanced_exa` | カテゴリ別高度検索（7カテゴリ） | 推奨 |
| `get_code_context_exa` | コード検索（GitHub/StackOverflow） | コード専用 |
| `company_research_exa` | 企業リサーチ（簡易版） | 基本 |
| `crawling_exa` | 既知URLからコンテンツ取得 | URL指定時 |
| `people_search_exa` | 人物検索（簡易版） | 基本 |
| `deep_researcher_start` | AI深層リサーチ開始 | 包括調査 |
| `deep_researcher_check` | 深層リサーチ結果確認 | 上記の続き |

---

## カテゴリ選択ガイド

`web_search_advanced_exa` の `category` パラメータで検索対象を指定:

| 検索対象 | category | 主な用途 |
|---------|----------|---------|
| 企業情報 | `"company"` | 企業概要・資金調達・評価額・製品 |
| ニュース | `"news"` | 最新ニュース・プレスリリース・報道 |
| ツイート/X | `"tweet"` | X/Twitterの投稿・議論・トレンド |
| 人物 | `"people"` | LinkedIn・経歴・専門家 |
| 個人サイト | `"personal site"` | ブログ・ポートフォリオ・技術記事 |
| 財務報告 | `"financial report"` | SEC filing・決算報告・投資家向け資料 |
| 学術論文 | `"research paper"` | arXiv・PubMed・学術論文 |
| （指定なし） | 省略 or `auto` | 汎用Web検索 |

---

## 共通パラメータ

### web_search_advanced_exa

| パラメータ | 型 | 説明 |
|-----------|-----|------|
| `query` | string（必須） | 検索クエリ |
| `category` | string | 検索カテゴリ（上表参照） |
| `numResults` | number | 結果数（10-100、用途に応じて調整） |
| `type` | string | `"auto"`, `"fast"`, `"deep"`, `"neural"` |
| `livecrawl` | string | `"fallback"` で深堀りリサーチ |
| `includeDomains` | string[] | 特定ドメインに限定 |
| `excludeDomains` | string[] | 特定ドメインを除外 |
| `startPublishedDate` | string | 開始日（ISO 8601） |
| `endPublishedDate` | string | 終了日（ISO 8601） |
| `includeText` | string[] | 含む文字列（**1要素のみ**） |
| `excludeText` | string[] | 除外文字列（**1要素のみ**） |
| `additionalQueries` | string[] | 追加クエリ（並列検索） |
| `enableSummary` | boolean | 要約を有効化 |
| `summaryQuery` | string | 要約の焦点 |
| `enableHighlights` | boolean | ハイライト抽出 |

### カテゴリ別フィルター制限

| category | includeDomains | excludeDomains | Date filters | Text filters |
|----------|---------------|----------------|-------------|-------------|
| `company` | ❌ | ❌ | ✅ | ✅ |
| `people` | ✅（LinkedIn等のみ） | ❌ | ❌ | ❌ |
| `financial report` | ✅ | ✅ | ✅ | includeTextのみ |
| `research paper` | ✅ | ✅ | ✅ | ✅（1要素） |
| `personal site` | ✅ | ✅ | ✅ | ✅（1要素） |
| `news` | ✅ | ✅ | ✅ | ✅（1要素） |
| `tweet` | ✅ | ✅ | ✅ | ✅（1要素） |

> **400エラー防止**: `includeText`/`excludeText` は必ず**1要素の配列のみ**。複数要素はエラーになる。

---

## 検索パターン

### 1. 企業リサーチ（Company）

```
web_search_advanced_exa({
  query: "Anthropic funding rounds valuation 2024",
  category: "company",
  numResults: 20,
  type: "auto"
})
```

**クエリ例:**
- 発見: `"AI infrastructure startups San Francisco"`
- 深堀り: `"Anthropic funding rounds valuation 2024"`
- 競合分析: `"Anthropic competitors AI safety"`

### 2. コード検索（Code）

**専用ツール `get_code_context_exa` を使用**（`web_search_advanced_exa` ではない）:

```
get_code_context_exa({
  query: "Next.js 14 server actions form validation TypeScript",
  tokensNum: 5000
})
```

**クエリ最適化:**
- プログラミング言語を必ず含める: `"Go generics"` ✅ / `"generics"` ❌
- フレームワーク/バージョンを指定: `"React 19 use hook"`, `"Python 3.12 type hints"`
- 関数名・クラス名・エラーメッセージを含める

**トークン戦略:**

| 用途 | tokensNum |
|------|-----------|
| ピンポイントのスニペット | 1000-3000 |
| 標準的なタスク | 5000 |
| 複雑な統合 | 10000-20000 |

### 3. 人物検索（People）

```
web_search_advanced_exa({
  query: "VP Engineering AI infrastructure",
  category: "people",
  numResults: 20,
  type: "auto"
})
```

**クエリ例:**
- 役職検索: `"VP Engineering AI infrastructure"`
- 特定人物: `"Dario Amodei Anthropic CEO background"`
- メディア露出: category `"news"` で `"Dario Amodei interview"`

> `category: "people"` ではDate/Textフィルターが使用不可。フィルターが必要な場合は category なしで実行。

### 4. 財務報告検索（Financial Report）

```
web_search_advanced_exa({
  query: "Tesla 10-K annual report 2024",
  category: "financial report",
  numResults: 15,
  type: "deep"
})
```

**対象:** SEC filing（10-K, 10-Q, 8-K, S-1）、四半期決算、年次報告、投資家向けプレゼン

> `category: "financial report"` では `excludeText` が使用不可（400エラー）。

### 5. 学術論文検索（Research Paper）

```
web_search_advanced_exa({
  query: "transformer attention mechanism optimization 2024",
  category: "research paper",
  numResults: 20,
  startPublishedDate: "2024-01-01",
  type: "deep"
})
```

**ドメイン指定例:** `includeDomains: ["arxiv.org", "openreview.net", "pubmed.ncbi.nlm.nih.gov"]`

### 6. 個人サイト検索（Personal Site）

```
web_search_advanced_exa({
  query: "Rust async runtime internals blog",
  category: "personal site",
  numResults: 15,
  excludeDomains: ["medium.com"]
})
```

**用途:** 技術ブログ、ポートフォリオ、独立系コンテンツの発見。アグリゲーターを除外して独自コンテンツを取得。

### 7. X/Twitter検索（Tweet）

```
web_search_advanced_exa({
  query: "AI safety regulation",
  category: "tweet",
  numResults: 20,
  startPublishedDate: "2025-01-01"
})
```

**クエリ例:**
- トピック: `"AI safety regulation"`
- 特定アカウント: `"from:@sama AI future"`
- トレンド: `"LLM benchmark 2025"`

---

## numResults 調整ガイド

| リクエストの性質 | numResults |
|----------------|-----------|
| ピンポイントの回答 | 5-10 |
| 一般的な調査 | 10-20 |
| 包括的リサーチ | 50-100 |
| ユーザー指定あり | 指定値に従う |
| 曖昧な場合 | AskUserQuestionで確認 |

---

## 高度な機能

### 並列クエリ（additionalQueries）

複数のクエリバリエーションを同時実行して網羅性を向上:

```
web_search_advanced_exa({
  query: "ML engineer San Francisco",
  additionalQueries: ["AI engineer Bay Area", "machine learning developer SF"],
  category: "people",
  numResults: 25,
  type: "deep"
})
```

### URL crawling（crawling_exa）

既知のURLからコンテンツを直接取得:

```
crawling_exa({
  url: "https://example.com/article",
  textMaxCharacters: 10000
})
```

### Deep Research

包括的なリサーチレポートが必要な場合:

```
deep_researcher_start({ query: "AI regulation landscape 2025" })
// 後で結果を確認
deep_researcher_check({ taskId: "..." })
```

---

## トークン分離パターン

大量の検索結果でメインコンテキストを汚染しないため、**Task agentを使用**してトークン分離する:

```
Task({
  subagent_type: "general-purpose",
  prompt: "Exa MCPで以下を検索し、結果を要約してください: ..."
})
```

検索→フィルタリング→重複排除→要約をAgent内で完結させ、最小限の結果のみメインコンテキストに返す。

---

## 検索ツール優先順位

| 順位 | ツール | 用途 |
|------|--------|------|
| 1 | **Exa MCP** | Web検索・企業調査・人物検索・コード検索・学術論文・SNS検索 |
| 2 | **context7** | 特定ライブラリのドキュメント検索 |
| 3 | **deepwiki** | GitHub Wiki / リポジトリドキュメント |
| 4 | **searching-web**（gemini CLI） | Exa MCPが使えない場合のfallback |
| 5 | **WebSearch**（ビルトイン） | 最終手段 |

---

## トラブルシューティング

| 問題 | 原因 | 対処 |
|------|------|------|
| 400エラー | フィルター制限違反 | カテゴリ別フィルター制限表を確認 |
| `includeText` で400 | 複数要素の配列 | 1要素のみに制限 |
| `people` カテゴリで結果不足 | フィルター使用不可 | category なしで再検索 |
| `financial report` で `excludeText` | サポート外 | `includeText` のみ使用 |
| レート制限 | 無料プラン制限 | API keyの設定を確認 |

---

## 関連スキル

- **searching-web**: gemini CLI による Web検索（Exa MCP のfallback）
- **researching-libraries**: ライブラリ調査（Exa Code Search + npmjs/PyPI等）
- **reviewing-with-coderabbit**: コードレビュー（検索とは別の品質チェック）
