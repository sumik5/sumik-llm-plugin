# RAGとドキュメント要約 — WebアプリへのRAG統合実装

> RAGの理論的詳細（インデックス設計・類似検索アルゴリズム・評価手法）は `building-rag-systems` スキルを参照。
> 本ファイルはNext.js + LangChain.jsを用いたWebアプリへのRAG統合実装に焦点を当てる。

---

## 1. ドキュメント要約

**いつ使うか**: ユーザーがPDF/DOCXをアップロードして要約を生成するWeb機能を実装するとき。

### LangChain.jsによる要約アーキテクチャ

| コンポーネント | 役割 |
|---|---|
| Next.js | リクエスト受付・サーバーアクション実行 |
| Vercel AI SDK | UIとAI状態のブリッジ・ストリーミング |
| LangChain.js | ドキュメント処理パイプライン（チャンク分割・要約チェーン） |
| LLM | 要約生成（OpenAI / Gemini） |

### 要約戦略の選択基準

| 手法 | 仕組み | 適用ケース | 注意点 |
|---|---|---|---|
| **Stuffing** | ドキュメント全体を1回のプロンプトへ | 短いドキュメント（コンテキストウィンドウ内） | 長文は失敗する |
| **MapReduce** | チャンクごとに並列要約→統合 | 大きなドキュメント、速度優先 | APIコストが増加する |
| **Refine** | 初期要約+後続チャンクを反復更新 | 文脈継続が重要な長文 | 早期要約の誤りが伝播する |

### 処理ワークフロー

```
ユーザーアップロード
    ↓
ドキュメントロード（PDFLoader / DocxLoader）
    ↓
前処理（normalizeDocuments）
    ↓
チャンク分割（RecursiveCharacterTextSplitter）
    ↓
コンテキストウィンドウ超過？
    ├─ No  → Stuffing（loadSummarizationChain: "stuff"）
    └─ Yes → MapReduce or Refine
    ↓
要約をストリーミング表示
```

### ドキュメントローダーの実装

```typescript
import { PDFLoader } from "@langchain/community/document_loaders/fs/pdf";
import { DocxLoader } from "@langchain/community/document_loaders/fs/docx";
import path from "path";

const loaders: Record<string, typeof PDFLoader | typeof DocxLoader> = {
  pdf: PDFLoader,
  docx: DocxLoader,
};

const loadDocumentFromFile = async (filePath: string) => {
  const ext = path.extname(filePath).substring(1).toLowerCase();
  const LoaderClass = loaders[ext];
  if (!LoaderClass) throw new Error(`Unsupported extension: ${ext}`);
  return await new LoaderClass(filePath).load();
};
```

### チャンク分割

```typescript
import { RecursiveCharacterTextSplitter } from "langchain/text_splitter";

const splitter = new RecursiveCharacterTextSplitter({
  chunkSize: 1500,    // チャンクサイズ（文字数）
  chunkOverlap: 200,  // コンテキスト継続のためのオーバーラップ
});
const documentChunks = await splitter.splitDocuments(documents);
```

### MapReduce要約チェーンの実行

```typescript
import { loadSummarizationChain } from "langchain/chains";

const chain = loadSummarizationChain(model, {
  type: "map_reduce",
  verbose: true,
});

const result = await chain.invoke({
  input_documents: documentChunks,
});
// result.text に要約テキストが入る
```

---

## 2. ドキュメント前処理の制約と対策

**いつ使うか**: PDF/DOCXの解析精度が低い、または要約品質が悪いとき。

### 主な制約と対応策

| 制約 | 原因 | 対策 |
|---|---|---|
| テキスト抽出精度 | PDF内の非構造テキスト、画像埋め込み | OCR連携、メタデータ付加 |
| ヘッダー・フッターのノイズ | ページ番号・ウォーターマーク | 正規表現による前処理フィルター |
| ストップワードによるトークン浪費 | "the", "and"等の無意味語 | 前処理でフィルタリング |
| APIコスト増大 | 大ドキュメントで多数のLLM呼び出し | 後述のプロンプト圧縮・クラスタリング |

### ドキュメント正規化（normalizeDocuments）

```typescript
function normalizeDocuments(docs: Document[]) {
  return docs.map((doc) => {
    let content = Array.isArray(doc.pageContent)
      ? doc.pageContent.join("\n")
      : doc.pageContent;

    content = content.trim()
      .replace(/Figure \d+:.*?\n/g, "")  // 図の参照を削除
      .replace(/\s+/g, " ");              // 余分なスペースを正規化

    doc.pageContent = content;
    return doc;
  }).filter((doc) => doc.pageContent);
}
```

### トークン使用量の追跡

```typescript
const model = new ChatGoogleGenerativeAI({
  apiKey,
  model: "gemini-2.0-flash",
  callbacks: [{
    handleLLMEnd: (output) => {
      const { message } = output.generations[0][0];
      tokenTracker.updateTokens(message.usage_metadata);
    },
  }],
});
```

### 大規模ドキュメント向け最適化手法

#### プロンプト圧縮（LLMLingua）

- 小型ローカルLLMでプロンプトを事前圧縮
- 標準プロンプトで2.5倍、会話履歴で10倍、反復コンテンツで20倍の削減
- ※現在LangChain Python版のみ対応（JS版は未統合）

#### k-meansクラスタリングによるチャンク統合

```typescript
import { kmeans } from "ml-kmeans";
import { pipeline } from "@huggingface/transformers";

async function clusterDocuments(
  documentChunks: string[],
  similarityThreshold = 0.8
) {
  // 埋め込み生成（MiniLM-L6-v2）
  const extractor = await pipeline(
    "feature-extraction",
    "Xenova/all-MiniLM-L6-v2"
  );
  const embeddings = await Promise.all(
    documentChunks.map((chunk) => extractor(chunk))
  );
  const flatEmbeddings = embeddings.map((e) => e[0][0].data);

  // 最適クラスタ数の計算（√(n/2)のヒューリスティック）
  const k = Math.max(1, Math.min(
    Math.ceil(Math.sqrt(flatEmbeddings.length / 2)),
    flatEmbeddings.length - 1
  ));

  const result = kmeans(flatEmbeddings, k);
  return mergeSimilarClusters(documentChunks, result.clusters, similarityThreshold);
}
```

**クラスタリングのステップ**:
1. RecursiveCharacterTextSplitterでチャンク分割（サイズ10,000文字）
2. 埋め込みベクトルへ変換
3. k-meansクラスタリング適用
4. 類似度閾値（デフォルト0.8）でクラスタ統合

---

## 3. RAGアーキテクチャ（Webアプリ向け構成）

**いつ使うか**: ドキュメントコーパスに基づく質問応答Webアプリを実装するとき。

### コンポーネント構成テーブル

| コンポーネント | 役割 | 実装選択肢 |
|---|---|---|
| ドキュメントインデックス | テキスト→ベクトル変換・保存 | HNSWLib（ファイルシステム） |
| 埋め込みモデル | テキスト→高次元ベクトル | GoogleAI Embeddings / OpenAI Embeddings |
| 検索エンジン | クエリ→類似ドキュメント取得 | asRetriever（k=6） |
| 拡張層 | 取得ドキュメント＋クエリ→強化プロンプト | ChatPromptTemplate |
| 生成エンジン | 強化プロンプト→応答生成 | LLM（Gemini / GPT） |
| グラウンディング | 応答の信頼性評価 | ログ確率・知識ベース検証 |

### 技術スタック（Next.js + LangChain.js）

```
Frontend:  React（Next.js App Router）
Backend:   Next.js Server Actions
Vector DB: HNSWLib（ファイルシステム保存）
Embedding: GoogleAI Embeddings
LLM:       ChatGoogleGenerativeAI
Grounding: Log Probability評価
```

---

## 4. RAGシステムコンポーネント実装

### ドキュメントインデックス構築

**オフライン処理**（起動前に一度実行）:

```typescript
import { HNSWLib } from "@langchain/community/vectorstores/hnswlib";
import { GoogleGenerativeAIEmbeddings } from "@langchain/google-genai";

async function indexDocumentsFromDirectory(dir: string) {
  const pdfFiles = fs.readdirSync(dir)
    .filter((f) => path.extname(f).toLowerCase() === ".pdf")
    .map((f) => path.join(dir, f));

  const documents: Document[] = [];
  for (const filePath of pdfFiles) {
    const docs = await processDocument(filePath);
    documents.push(...docs);
  }

  const embeddings = new GoogleGenerativeAIEmbeddings({ apiKey });
  const vectorStore = await HNSWLib.fromDocuments(documents, embeddings);
  await vectorStore.save("./rag_index");
}
```

**ベクトルストア選定基準**:

| ストア | 特徴 | 適用場面 |
|---|---|---|
| **HNSWLib** | ファイルシステム保存・ポータブル | 小〜中規模、開発・プロトタイプ |
| **MemoryVectorStore** | インメモリ・再起動で消える | テスト・セッション内 |
| **Pinecone / Weaviate** | マネージドクラウド | 大規模本番環境 |

### 検索（Retrieval）

```typescript
async function loadIndex(indexPath: string) {
  const embeddings = new GoogleGenerativeAIEmbeddings({ apiKey });
  const vectorStore = await HNSWLib.load(indexPath, embeddings);
  const retriever = vectorStore.asRetriever({ k: 6 });
  return retriever;
}
```

**注意**: インデックス作成時と検索時に**同じ埋め込みモデル**を使用すること。異なるモデルを使うと次元ミスマッチエラーが発生する（`building-rag-systems` スキルのトラブルシューティング参照）。

---

## 5. グラウンディング（信頼性向上）

**いつ使うか**: AIが知識外の質問に誤答するハルシネーションを防ぎたいとき。

### グラウンディングの5種類

| 種類 | 仕組み | 用途 |
|---|---|---|
| **検索拡張型** | 外部ソースから取得して統合 | リアルタイム情報を含む応答 |
| **知識ベース型** | キュレーション済みリポジトリを参照 | 特定ドメインに限定 |
| **引用型** | 出典リファレンスを明示 | 学術・研究向けアプリ |
| **コンテキスト型** | 過去の会話を参照して適応 | チャットボット |
| **ログ確率型** | トークンの生成確率で信頼度評価 | 信頼性スコアの提供 |

### ログ確率グラウンディングの実装

```typescript
const openAI = new ChatOpenAI({
  model: "gpt-3.5-turbo",
  apiKey: OpenAIKey,
  logprobs: true,
  topLogprobs: 3,
});
```

**信頼度評価の判断基準**:
- ログ確率 > -1.0 → 信頼できる応答
- ログ確率 ≤ -1.0 → 信頼度低（代替戦略を実行）
  - モデルへの再プロンプト
  - 外部データソースの参照
  - ユーザーへの追加コンテキスト要求

```typescript
const result = await rag.performEnhancedRAG(input, {
  confidenceThreshold: 85,    // 信頼度閾値（%）
  fallbackStrategy: "ask_user", // 閾値以下時の戦略
});
```

---

## 6. Next.js + LangChain.js RAG統合パターン

**いつ使うか**: Next.js Server ActionsとRAGシステムを統合するとき。

### RAGシステムのサーバーアクション統合

```typescript
import { RAG } from "@/lib/RAG";

// シングルトンパターン（リクエストをまたいでインデックスを再利用）
let ragSystem: RAG | null = null;

async function initializeRAG(): Promise<RAG> {
  if (!ragSystem) {
    ragSystem = new RAG(apiKey);
    const indexPath = process.env.RAG_INDEX_PATH!;
    await ragSystem.loadIndex(indexPath);
  }
  return ragSystem;
}

export async function continueConversation(input: string) {
  const rag = await initializeRAG();
  const result = await rag.performRAG(input);
  return {
    answer: result.answer,
    sources: result.sourceDocuments,
  };
}
```

### 拡張・生成チェーンのパターン

```typescript
async function performRAG(query: string) {
  const prompt = ChatPromptTemplate.fromTemplate(`
    提供されたコンテキストのみに基づいて質問に答えてください。
    Context: {context}
    Question: {question}
  `);

  const chain = RunnableSequence.from([
    {
      context: retriever.pipe(formatDocs),
      question: new RunnablePassthrough(),
    },
    prompt,
    llm,
    new StringOutputParser(),
  ]);

  const answer = await chain.invoke(query);
  const sourceDocuments = await retriever.invoke(query);
  return { answer, sourceDocuments };
}
```

### 環境設定

```bash
# .env
OPENAI_API_KEY=<OPEN_AI_SECRET_KEY>
GEMINI_API_KEY=<GOOGLE_AI_SECRET_KEY>
RAG_INDEX_PATH=/absolute/path/to/rag_index
```

**インデックス構築コマンド**:
```bash
cd ch07/rag-web-app
node scripts/indexDocuments.google.js -d corpus
```

### RAG変形パターン

| パターン | 概要 | 用途 |
|---|---|---|
| **基本RAG** | 単一検索→生成 | シンプルな質問応答 |
| **MultiHop-RAG** | 初期結果から再帰的に追加コンテキスト取得 | 複数ステップの推論が必要 |
| **HyDE** | 仮想ドキュメント埋め込みで検索精度向上 | Web検索・Q&A精度向上 |

#### MultiHop-RAG

MultiHop-RAGは、初期検索結果を出発点として**再帰的に追加コンテキストを取得**するパターン。複数の支持証拠にまたがる推論が必要なタスクに有効で、強化学習ベースの検索最適化と組み合わせることで特定タスク目標への適応が可能になる。

- **ユースケース**: 「AはBによってCに影響し、その結果Dはどうなるか」といった多段階の因果推論
- **特徴**: 1回の検索では不十分な複雑な質問に対し、反復的なコンテキスト収集で精度を向上させる

#### HyDE（Hypothetical Document Embeddings）

HyDEは、実在するドキュメントのインデックス化・検索にとどまらず、**仮想的なドキュメント表現を生成**して情報検索を補完するパターン。実在するテキストに対応しない合成ドキュメント表現を作成することで、セマンティック検索の精度を向上させる。

- **ユースケース**: Web検索・Q&Aにおける検索精度向上
- **仕組み**: クエリに対して「このような内容のドキュメントが存在するとすれば」という仮想ドキュメントを生成し、その埋め込みベクトルを使って類似ドキュメントを検索する

> より高度なRAGの実装パターン（データローダー・評価・本番運用）は `building-rag-systems` スキルを参照。
