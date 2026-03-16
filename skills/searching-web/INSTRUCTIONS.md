# Web検索ガイド

## 検索ツール優先順位

| 順位 | ツール | 用途 |
|------|--------|------|
| 1 | **Exa MCP** | Web検索・企業調査・人物検索・コード検索・学術論文・SNS検索 |
| 2 | **context7** | 特定ライブラリのドキュメント検索 |
| 3 | **deepwiki** | GitHub Wiki / リポジトリドキュメント |
| 4 | **gemini CLI**（本スキル scripts/web-search.sh） | Exa MCPが使えない場合のfallback |
| 5 | **WebSearch**（ビルトイン） | 最終手段 |

---

## Exa MCP検索

**Exa MCP Server** は、AIアシスタントからExa検索エンジンにアクセスするためのMCPサーバー。7つのカテゴリ検索＋コード検索＋URL crawlingを提供し、**Web検索の第一選択ツール**として使用する。

### ツール一覧

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

### カテゴリ選択ガイド

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

### 共通パラメータ（web_search_advanced_exa）

| パラメータ | 型 | 説明 |
|-----------|-----|------|
| `query` | string（必須） | 検索クエリ |
| `category` | string | 検索カテゴリ（上表参照） |
| `numResults` | number | 結果数（10-100） |
| `type` | string | `"auto"`, `"fast"`, `"deep"`, `"neural"` |
| `livecrawl` | string | `"fallback"` で深堀りリサーチ |
| `includeDomains` | string[] | 特定ドメインに限定 |
| `excludeDomains` | string[] | 特定ドメインを除外 |
| `startPublishedDate` | string | 開始日（ISO 8601） |
| `includeText` | string[] | 含む文字列（**1要素のみ**） |
| `excludeText` | string[] | 除外文字列（**1要素のみ**） |
| `additionalQueries` | string[] | 追加クエリ（並列検索） |
| `enableSummary` | boolean | 要約を有効化 |

#### カテゴリ別フィルター制限

| category | includeDomains | excludeDomains | Date filters | Text filters |
|----------|---------------|----------------|-------------|-------------|
| `company` | ❌ | ❌ | ✅ | ✅ |
| `people` | ✅（LinkedIn等のみ） | ❌ | ❌ | ❌ |
| `financial report` | ✅ | ✅ | ✅ | includeTextのみ |
| `research paper` | ✅ | ✅ | ✅ | ✅（1要素） |
| `personal site` | ✅ | ✅ | ✅ | ✅（1要素） |
| `news` | ✅ | ✅ | ✅ | ✅（1要素） |
| `tweet` | ✅ | ✅ | ✅ | ✅（1要素） |

> **400エラー防止**: `includeText`/`excludeText` は必ず**1要素の配列のみ**。

---

### 検索パターン

#### 1. 企業リサーチ（Company）
```
web_search_advanced_exa({
  query: "Anthropic funding rounds valuation 2024",
  category: "company",
  numResults: 20,
  type: "auto"
})
```

#### 2. コード検索（Code）

**専用ツール `get_code_context_exa` を使用**:
```
get_code_context_exa({
  query: "Next.js 14 server actions form validation TypeScript",
  tokensNum: 5000
})
```

| 用途 | tokensNum |
|------|-----------|
| ピンポイントのスニペット | 1000-3000 |
| 標準的なタスク | 5000 |
| 複雑な統合 | 10000-20000 |

#### 3. 学術論文検索（Research Paper）
```
web_search_advanced_exa({
  query: "transformer attention mechanism optimization 2024",
  category: "research paper",
  numResults: 20,
  startPublishedDate: "2024-01-01",
  type: "deep"
})
```

#### 4. X/Twitter検索（Tweet）
```
web_search_advanced_exa({
  query: "AI safety regulation",
  category: "tweet",
  numResults: 20,
  startPublishedDate: "2025-01-01"
})
```

---

### numResults 調整ガイド

| リクエストの性質 | numResults |
|----------------|-----------|
| ピンポイントの回答 | 5-10 |
| 一般的な調査 | 10-20 |
| 包括的リサーチ | 50-100 |
| 曖昧な場合 | AskUserQuestionで確認 |

---

### 高度な機能

#### 並列クエリ（additionalQueries）
```
web_search_advanced_exa({
  query: "ML engineer San Francisco",
  additionalQueries: ["AI engineer Bay Area", "machine learning developer SF"],
  category: "people",
  numResults: 25
})
```

#### URL crawling
```
crawling_exa({
  url: "https://example.com/article",
  textMaxCharacters: 10000
})
```

#### Deep Research
```
deep_researcher_start({ query: "AI regulation landscape 2025" })
deep_researcher_check({ taskId: "..." })
```

---

### トークン分離パターン

大量の検索結果でメインコンテキストを汚染しないため、**Task agentを使用**してトークン分離する:

```
Task({
  subagent_type: "general-purpose",
  prompt: "Exa MCPで以下を検索し、結果を要約してください: ..."
})
```

---

### トラブルシューティング

| 問題 | 原因 | 対処 |
|------|------|------|
| 400エラー | フィルター制限違反 | カテゴリ別フィルター制限表を確認 |
| `includeText` で400 | 複数要素の配列 | 1要素のみに制限 |
| `people` カテゴリで結果不足 | フィルター使用不可 | category なしで再検索 |
| `financial report` で `excludeText` | サポート外 | `includeText` のみ使用 |
| レート制限 | 無料プラン制限 | API keyの設定を確認 |

---

## gemini CLI検索（フォールバック）

Exa MCPが利用できない場合、または複雑な質問・詳細な情報収集に使用するフォールバック手段です。
単純なキーワード検索ではなく、複雑な質問や詳細な情報収集に適しています。

### 使い方

以下のコマンドを実行して、Web検索を実行します。
引数には検索したい内容や質問を自然言語で指定してください。

```
bash scripts/web-search.sh "<検索したい内容や質問>"
```

検索結果を確認し、ユーザーの質問に対する回答を構築します。

- 関連性の高い情報を抽出
- 必要に応じて複数の検索結果を統合
- 情報源を明記
- 検索結果が不十分な場合は、異なるクエリで再検索を検討
