---
description: >-
  Comprehensive RAG (Retrieval-Augmented Generation) system building guide covering data loading
  pipelines (11 source types including Word, PDF, CSV, audio, video, multimodal), data preparation
  (metadata enrichment, text quality enhancement, 5 chunking strategies from character to agentic),
  and full RAG architecture overview with Python. Use when building RAG applications, designing data
  ingestion pipelines, or implementing text chunking strategies. For Python language best practices,
  use developing-python instead.
---

# RAGシステム構築ガイド

## 概要

RAG (Retrieval-Augmented Generation) は、検索エンジンとLLMを融合させた技術です。企業データの約80%は非構造化データ（PowerPoint、Word、Excel、メール、議事録等）であり、これらを効果的に活用するためにRAGが必要とされています。

### RAGが必要な理由

1. **Foundation Modelのコンテキストサイズ制限**: 多くのLLMには入力トークン数の上限があり、すべてのドキュメントを一度にプロンプトに含めることはできません
2. **コストと応答時間**: 巨大なプロンプトは処理時間とコストの増大を招きます
3. **知識の鮮度**: RAGは最新情報をリアルタイムで検索・統合できます
4. **ハルシネーション軽減**: 検索した実データに基づく回答により、LLMの幻覚を抑制できます

---

## RAGアーキテクチャ全体像

RAGシステムは2つのフェーズで構成されます。

### Indexingフェーズ（事前処理）

1. **Load Data**: 各種データソースから情報を読み込み
2. **Split Text**: テキストを小さなチャンクに分割
3. **Translate to Embeddings**: テキストチャンクをベクトル表現（Embedding）に変換
4. **Store**: ベクトルストアに格納

### Runtimeフェーズ（実行時）

1. **Translate Question**: ユーザーの質問をベクトル化
2. **Search for Similarities**: ベクトル空間で類似検索を実行
3. **Answer Question**: 検索結果をコンテキストとしてLLMに渡し、回答を生成

```
┌─────────────────────────────────────────────────────────────┐
│                    Indexing Phase                           │
│  (事前処理：ドキュメント群の準備)                          │
└─────────────────────────────────────────────────────────────┘
    ┌─────────────┐
    │ Load Data   │  ← Word, PDF, CSV, Audio, Video, DB...
    └──────┬──────┘
           │
    ┌──────▼──────┐
    │ Split Text  │  ← Chunking strategies (5種)
    └──────┬──────┘
           │
    ┌──────▼────────────┐
    │ Translate to      │  ← Embedding model
    │ Embeddings        │
    └──────┬────────────┘
           │
    ┌──────▼──────┐
    │   Store     │  ← Vector Store (pgvector, Pinecone, etc.)
    └─────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    Runtime Phase                            │
│  (実行時：ユーザー質問への応答)                            │
└─────────────────────────────────────────────────────────────┘
    ┌─────────────────┐
    │ User Question   │
    └────────┬────────┘
             │
    ┌────────▼────────────┐
    │ Translate Question  │  ← Same embedding model
    └────────┬────────────┘
             │
    ┌────────▼───────────────┐
    │ Search for             │  ← Similarity search
    │ Similarities           │     (cosine, euclidean, etc.)
    └────────┬───────────────┘
             │
    ┌────────▼────────┐
    │ Answer Question │  ← LLM with retrieved context
    └─────────────────┘
```

---

## 全章ロードマップ

本ガイドは11章で構成されており、RAGシステムの構築に必要なすべての要素をカバーしています。

| 章 | トピック | 状態 |
|---|---------|------|
| Ch1 | データ読み込み（11ソースタイプ） | ✅ 詳細あり → [DATA-LOADING.md](references/DATA-LOADING.md) |
| Ch2 | データ準備（メタデータ、品質改善、チャンキング） | ✅ 詳細あり → [DATA-PREPARATION.md](references/DATA-PREPARATION.md) |
| Ch3 | Embeddings（ベクトル表現の生成） | 🔜 準備中 |
| Ch4 | 類似検索（距離メトリクス、検索アルゴリズム） | 🔜 準備中 |
| Ch5 | 検索（Retrieval戦略、フィルタリング） | 🔜 準備中 |
| Ch6 | プロンプトエンジニアリング | 🔜 準備中 |
| Ch7 | 生成（LLMによる回答生成） | 🔜 準備中 |
| Ch8 | RAGシステム評価 | 🔜 準備中 |
| Ch9 | Agentic RAG | 🔜 準備中 |
| Ch10 | GraphRAG | 🔜 準備中 |
| Ch11 | RAGアプリケーション | 🔜 準備中 |

---

## データ読み込みクイックリファレンス

RAGシステムは多様なデータソースからの読み込みをサポートする必要があります。以下は主要なデータソースタイプと推奨ライブラリの一覧です。

| ソース | 推奨ライブラリ | 用途 |
|-------|-------------|------|
| Word (.docx) | python-docx / unstructured | テキスト抽出、要素分類（見出し、表、箇条書き等） |
| PDF | PyPDF2 | テキスト+メタデータ抽出（シンプルなPDF向け） |
| CSV/Excel | pandas + openpyxl | 行→テキスト変換、テーブル埋め込み、Text-to-SQL対応 |
| PostgreSQL | SQLAlchemy + psycopg2 | DBクエリ、pgvectorでベクトル検索も可 |
| Audio | OpenAI Whisper | Speech-to-Text変換（高精度） |
| 画像(OCR) | Tesseract + pytesseract | テキスト中心の画像に最適、高速・低コスト |
| 画像(Multimodal) | GPT-4o / Claude / Gemini | 柔軟、プロンプトで制御可能（図表・グラフ・レイアウト理解） |
| 画像要約 | GPT-4o (multimodal) | テキストembedding用の画像説明生成 |
| テーブル要約 | unstructured + GPT-4o | テーブルからキーインサイト抽出 |
| マルチメディアPDF | unstructured + multimodal | テキスト、画像、テーブルの統合処理 |
| 動画 | moviepy + Whisper + GPT-4o | フレーム抽出+音声文字起こし+画像要約 |

**詳細は [DATA-LOADING.md](references/DATA-LOADING.md) を参照してください。**

### データソース選択のガイドライン

- **テキストのみのPDF**: PyPDF2で十分
- **スキャンPDF・画像PDF**: OCR (Tesseract) または Multimodal model
- **複雑なレイアウトのPDF**: unstructured でパーティショニング
- **音声データ**: Whisperで文字起こし
- **動画**: フレーム抽出（moviepy）+ Whisper + 画像要約
- **データベース**: SQLAlchemyでクエリ、pgvectorでベクトル検索統合

---

## データ準備クイックリファレンス

データ読み込み後、チャンク分割前の前処理が重要です。

### 前処理テクニック

| テクニック | 用途 | 効果 |
|-----------|------|------|
| メタデータ付与 | 検索フィルタリング高速化 | 日付・カテゴリ・著者等でフィルタリング可能 |
| 略語展開 | チャンクの自己完結性向上 | "API" → "Application Programming Interface" |
| 仮想質問生成 (HyDE) | 検索精度向上 | チャンクごとに「このチャンクで答えられる質問」を生成してembedding |

**メタデータの重要性:**

メタデータを付与することで、ベクトル検索前にフィルタリングが可能になります。これにより、検索対象を事前に絞り込み、検索精度と速度を大幅に向上できます。

```
例:
- 日付範囲でフィルタリング: "2024年1月以降のドキュメントのみ検索"
- カテゴリでフィルタリング: "技術ドキュメントのみ検索"
- 著者でフィルタリング: "特定部署の資料のみ検索"
```

### チャンキング戦略の選定

テキストを適切なサイズに分割することは、RAGシステムの精度を左右する重要なステップです。

```
ドキュメントの構造は？
├── 構造なし（ログ、ストリーム）
│   → Character Splitting
│      （固定文字数で分割、シンプル）
│
├── 段落・見出しあり
│   → Recursive Text Splitting（推奨デフォルト）
│      （\n\n → \n → スペース の優先順位で分割）
│
├── マークアップ言語（Markdown/HTML/LaTeX）
│   → Document-Aware Splitting
│      （ヘッダー階層を維持して分割）
│
├── 構造なし（会話、音声文字起こし）
│   → Semantic Chunking
│      （意味の境界で分割、embedding類似度ベース）
│
└── 複雑・長文・相互参照多
    → Agentic Chunking
       （LLM Agentが文脈を判断して分割）
```

### チャンクサイズのガイドライン

| 要素 | 推奨値 | 理由 |
|------|--------|------|
| チャンクサイズ | 1,000-2,000 tokens（約4,000-8,000文字） | バランスの取れたコンテキスト量 |
| オーバーラップ | 10-20% | チャンク境界での情報欠損を防ぐ |
| 最大サイズ | Embedding modelのコンテキスト上限内 | 例: text-embedding-3-small = 8,191 tokens |

**チャンクサイズのトレードオフ:**

- **大きなチャンク**:
  - ✅ コンテキストが豊富
  - ❌ コスト増加（処理トークン数増）
  - ❌ 応答遅延
  - ❌ ノイズが混入しやすい

- **小さなチャンク**:
  - ✅ 高速・低コスト
  - ✅ ノイズが少ない
  - ❌ コンテキスト不足
  - ❌ 複数チャンクにまたがる情報の取得困難

**詳細は [DATA-PREPARATION.md](references/DATA-PREPARATION.md) を参照してください。**

---

## 主要ライブラリ一覧

RAGシステム構築に必要な主要ライブラリと用途を整理します。

| ライブラリ | 用途 | 備考 |
|-----------|------|------|
| LangChain | RAGフレームワーク（テキスト分割、チェーン構築） | 高レベルAPI、迅速なプロトタイピング向け |
| LlamaIndex | RAGフレームワーク（インデックス構築、検索） | データ構造に特化 |
| unstructured | ドキュメントパーティショニング（テキスト/画像/テーブル分離） | 複雑なレイアウト対応 |
| PyPDF2 | PDF読み込み・メタデータ抽出 | シンプルなPDF向け |
| python-docx | Word文書処理 | .docxファイル専用 |
| OpenAI API | Whisper(STT)、GPT-4o(生成/要約)、Embeddings | マルチモーダル対応 |
| Tesseract | OCRエンジン | 高速・低コスト |
| moviepy | 動画処理（フレーム抽出、音声分離） | 動画からの情報抽出 |
| SQLAlchemy | データベース接続 | 構造化データソース |
| Pydantic | 構造化出力のスキーマ定義 | LLM出力のバリデーション |

### フレームワーク使用時の注意

**LangChain/LlamaIndexは便利ですが、まだ発展途上で頻繁にAPIが変更されます。**

プロダクション環境では以下を検討してください:

- 背後のスタンドアロンライブラリ（unstructured、PyPDF2等）を直接使用
- フレームワークのバージョン固定
- カスタム実装による柔軟性の確保

---

## ユーザー確認の原則

RAGシステムの設計には多数の選択肢があります。**判断分岐がある場合、推測で進めず必ずAskUserQuestionツールでユーザーに確認してください。**

### 確認すべき場面

以下の選択は、要件・制約・予算によって最適解が異なるため、ユーザーに確認が必要です:

#### 1. RAGフレームワーク選択

```
- LangChain（迅速なプロトタイピング、エコシステム充実）
- LlamaIndex（データ構造に特化、柔軟なインデックス）
- カスタム実装（完全な制御、依存関係最小化）
```

#### 2. ベクトルストア選択

```
- pgvector（PostgreSQL拡張、既存DBインフラ活用）
- Pinecone（マネージドサービス、スケーラブル）
- Chroma（軽量、開発環境向け）
- FAISS（高速、ローカル実行）
- Weaviate（GraphQL API、柔軟なスキーマ）
```

#### 3. チャンキング戦略選択

```
- Character Splitting（シンプル、構造なしテキスト）
- Recursive Text Splitting（デフォルト推奨）
- Document-Aware Splitting（Markdown/HTML等）
- Semantic Chunking（意味境界）
- Agentic Chunking（LLM活用）
```

#### 4. Embedding model選択

```
- OpenAI text-embedding-3-small（バランス型）
- OpenAI text-embedding-3-large（高精度）
- Cohere embed-multilingual-v3.0（多言語）
- オープンソースモデル（プライバシー重視）
```

#### 5. OCR vs Multimodal model選択

```
- OCR (Tesseract): テキスト中心、高速・低コスト
- Multimodal (GPT-4o): レイアウト・図表理解、柔軟だが高コスト
```

#### 6. クラウドAPI vs ローカルモデル

```
- クラウドAPI（OpenAI、Anthropic等）: 高精度、メンテナンス不要
- ローカルモデル（Ollama、Hugging Face等）: プライバシー、コスト削減
```

### 確認不要な場面

以下は一般的なベストプラクティスであり、特に理由がない限り確認不要です:

- ✅ APIキーを環境変数で管理すること
- ✅ メタデータを付与すること（常に推奨）
- ✅ オーバーラップを設定すること（10-20%が一般的）
- ✅ エラーハンドリングを実装すること

ただし、以下は実験・調整が必要なためユーザーと協議してください:

- ❓ 具体的なチャンクサイズ（データ特性に依存）
- ❓ オーバーラップの具体的な比率（データ特性に依存）
- ❓ Top-K検索の具体的なK値（要件に依存）

---

## 実装時のワークフロー

### 1. 要件定義フェーズ

AskUserQuestionで以下を確認:

- データソースの種類（PDF、Word、DB等）
- データ量の規模
- 更新頻度
- レイテンシ要件
- コスト制約
- プライバシー要件

### 2. アーキテクチャ設計フェーズ

確認した要件に基づき、以下を選定:

- RAGフレームワーク
- ベクトルストア
- Embedding model
- チャンキング戦略

### 3. 実装フェーズ

1. データ読み込みパイプライン構築
2. データ前処理・チャンク分割実装
3. Embedding生成・ベクトルストア格納
4. 検索システム実装
5. LLM統合・回答生成

### 4. 評価・改善フェーズ

- 検索精度の測定
- レイテンシの測定
- コストの測定
- チャンクサイズ・Top-K等のチューニング

---

## よくある落とし穴

### 1. チャンクサイズの不適切な設定

❌ **悪い例**: 一律200文字で分割
✅ **良い例**: ドキュメント構造を考慮し、段落単位で1,000-2,000 tokens

### 2. メタデータの欠如

❌ **悪い例**: テキストのみをembedding
✅ **良い例**: 日付、カテゴリ、著者等のメタデータを付与し、フィルタリング可能に

### 3. オーバーラップなし

❌ **悪い例**: チャンクを完全に独立して分割
✅ **良い例**: 10-20%のオーバーラップで境界情報の欠損を防ぐ

### 4. 単一の検索戦略のみ

❌ **悪い例**: ベクトル検索のみ
✅ **良い例**: ベクトル検索 + メタデータフィルタリング + キーワード検索のハイブリッド

### 5. 評価指標の不在

❌ **悪い例**: 感覚的な評価のみ
✅ **良い例**: Precision、Recall、MRR等の定量的指標で継続的に測定

---

## 次のステップ

1. **データ読み込み**: [DATA-LOADING.md](references/DATA-LOADING.md) でソースタイプ別の詳細実装を確認
2. **データ準備**: [DATA-PREPARATION.md](references/DATA-PREPARATION.md) でチャンキング戦略の詳細を確認
3. **Embeddings**: Ch3（準備中）でベクトル表現の生成方法を学習
4. **検索**: Ch4-5（準備中）で効果的な検索戦略を実装
5. **評価**: Ch8（準備中）でRAGシステムの性能を定量的に測定

---

## 関連スキル

- **`developing-python`**: Python開発のベストプラクティス
- **`writing-clean-code`**: SOLID原則、クリーンコード実践
- **`enforcing-type-safety`**: Pydanticによる型安全性
- **`testing-code`**: RAGシステムのテスト戦略
- **`securing-code`**: APIキー管理、データプライバシー

---

## まとめ

RAGシステムの構築は、データ読み込み→前処理→チャンク分割→Embedding→検索→生成という一連のパイプラインです。各ステップで適切な選択を行うことで、高精度かつ効率的なRAGアプリケーションを実現できます。

**重要なポイント:**

- データソースの特性に応じた読み込み方法の選択
- メタデータ付与による検索精度向上
- ドキュメント構造を考慮したチャンキング戦略
- 適切なチャンクサイズ（1,000-2,000 tokens推奨）
- ユーザー要件に基づくアーキテクチャ選定

詳細な実装方法は各章のリファレンスドキュメントを参照してください。
