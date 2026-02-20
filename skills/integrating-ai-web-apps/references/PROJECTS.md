# ハンズオンプロジェクト — AIアプリのアーキテクチャパターン

2つの実装プロジェクト（チャットベースの面接アシスタントと、マルチナレッジベースRAGエージェント）から抽出した汎用アーキテクチャパターン集。特定ツールへの依存を最小化し、設計判断の根拠と再利用可能なパターンを整理する。

---

## 1. AI Interview Assistant パターン

### プロジェクト概要

LLMを活用した面接シミュレーション・フィードバック生成・音声対話を組み合わせたアプリケーション。チャットUIを中心に設計し、セッション管理とセキュリティを外部サービスで堅牢化する構成。

| 機能 | 説明 |
|---|---|
| インタビュータイプ選択 | カスタム求人票または事前定義テンプレートから開始 |
| パラメータ設定 | 質問数・難易度・質問タイプ（行動/技術/混合）を構成 |
| チャットベース面接 | コンテキスト保持しながら会話形式で進行 |
| Text-to-Speech（TTS） | 質問を音声で読み上げる（機能フラグで有効化/無効化） |
| フィードバック生成 | 面接終了後にセッション全体をLLMが分析してレビューを生成 |
| セッション履歴 | 過去の面接セッションを時系列で参照可能 |
| セッションクローズ | ユーザーが明示的に操作を完了させることでセッションをロック |

### アーキテクチャ

#### 技術スタック構成

| レイヤー | 技術 | 役割 |
|---|---|---|
| フレームワーク | Next.js (App Router) | SSR・APIルート・サーバーアクション |
| AI統合 | Vercel AI SDK | ストリーミング会話・LLM抽象化 |
| 認証 | 認証サービス（Clerk等） | ユーザー管理・セッション保護 |
| データストア | Redis（KV） | 会話履歴・セッションメタデータの永続化 |
| TTS | 外部TTS API（Google Cloud TTS等） | テキスト→音声変換 |
| UIコンポーネント | Tailwind CSS + shadcn/ui | レスポンシブUI・アクセシブルな共通部品 |

#### コンポーネント構成

```
app/
  ├── (auth)/              # 認証ページ群
  ├── interview/
  │   ├── page.tsx         # 面接タイプ選択・設定画面
  │   ├── chat/            # チャットUI（ChatThread）
  │   └── feedback/        # フィードバック生成・表示
  ├── api/
  │   ├── chat/            # LLM会話APIルート（ストリーミング）
  │   └── tts/             # TTS変換APIルート
  └── middleware.ts        # 認証・レート制限・CORSの集約
```

---

### Text-to-Speech統合パターン

外部TTSサービスをAPIルートでラップし、フロントエンドへオーディオストリームを返す。

**設計判断**:

| アプローチ | 特徴 | 適用場面 |
|---|---|---|
| フロントエンド直接呼び出し（Web Speech API） | サーバーレス・ブラウザ標準API | プロトタイプ・シンプルな用途 |
| バックエンドAPIルート経由 | APIキー保護・レート制限可能 | 本番アプリ（推奨） |

**APIルートパターン**:

```typescript
// /api/tts/route.ts — TTSを保護されたAPIルートでラップ
export async function POST(request: Request) {
  // 1. 認証確認（ミドルウェアで保護済み）
  // 2. テキスト受け取り → 外部TTS APIへ転送
  // 3. 音声バイナリをストリームで返す
  return new Response(audioStream, {
    headers: { 'Content-Type': 'audio/mpeg' },
  });
}
```

**機能フラグによるオン/オフ制御**:

```
NEXT_PUBLIC_FEATURE_TTS_ENABLED=true
```

- 環境変数で即時切替可能（シンプルなユースケース向け）
- 本番では外部フィーチャーフラグサービス（LaunchDarkly等）を推奨: ユーザーセグメント別制御・A/Bテスト・段階ロールアウトが可能

---

### セッション管理とデータ永続化

**Redisキー設計パターン**:

```
user:sessions:{userId}      → Set（セッションIDの集合）
session:{sessionId}         → Hash（セッション詳細: jobTitle, difficulty, createdAt...）
messages:{sessionId}        → List（会話メッセージの時系列リスト）
feedback:{sessionId}        → String（生成済みフィードバックのキャッシュ）
```

**セッション一覧取得の実装パターン**:

```typescript
// ユーザーのセッション一覧を取得（新しい順にソート）
async function fetchUserSessions(userId: string) {
  const sessionIds = await redis.smembers(`user:sessions:${userId}`);
  const sessions = await Promise.all(
    sessionIds.map(async (id) => redis.hgetall(`session:${id}`))
  );
  return sessions.sort((a, b) => b.createdAt - a.createdAt);
}
```

**ポイント**:
- `SMEMBERS` でユーザーのセッションID集合を取得 → 並列で詳細フェッチ（効率的）
- フィードバックをキャッシュ（`feedback:{sessionId}`）することで再訪問時の再生成を防止
- RedisはKVとして機能するがリレーショナル操作は苦手。スケール時はPostgreSQL等へ移行を検討

**スケールアップ判断基準**:

| 要件 | Redis | RDBMS（PostgreSQL等） |
|---|---|---|
| 高速なKVアクセス・TTL | ✅ | - |
| トランザクション保証 | 限定的 | ✅ |
| 複雑なクエリ・JOIN | ❌ | ✅ |
| 既存ユーザー数 < 数万人 | ✅（十分） | - |

---

### セキュリティ統合

Next.js `middleware.ts` に多層防御を集約するパターン:

```typescript
// middleware.ts — 全リクエストへの多層防御
export async function middleware(request: NextRequest) {
  // Layer 1: 認証確認（未認証 → ログインリダイレクト）
  const isAuthenticated = await verifyAuth(request);
  if (!isAuthenticated) return redirect('/login');

  // Layer 2: CORS設定（許可オリジン以外をブロック）
  const corsResponse = applyCors(request);
  if (corsResponse) return corsResponse;

  // Layer 3: レート制限（時間あたりリクエスト数の上限）
  const rateLimitResult = await rateLimit(request);
  if (rateLimitResult.exceeded) return new Response('Too Many Requests', { status: 429 });

  // Layer 4: セキュリティヘッダー付与
  const response = NextResponse.next();
  return applySecurityHeaders(response);
}
```

**セキュリティ多層防御テーブル**:

| 対策 | 目的 | 実装ポイント |
|---|---|---|
| 認証（JWT/Session） | 未認証アクセスを防止 | ミドルウェアで全ルートを保護 |
| CORS制御 | クロスオリジン攻撃を防止 | 許可オリジンのホワイトリスト管理 |
| レート制限 | DoS/乱用を防止 | Redisで時間ウィンドウ内リクエスト数を追跡 |
| セキュリティヘッダー | XSS/クリックジャッキング等を防止 | CSP, X-Frame-Options, HSTS |
| メッセージクォータ | APIコストの上限設定 | ユーザーごとの累積カウント管理 |

---

## 2. RAG Knowledge Base Agent パターン

### プロジェクト概要

複数のナレッジベースを管理し、アップロードされたドキュメントをベクトル検索で参照しながら会話応答を生成するフルスタックRAGアプリケーション。

| 機能 | 説明 |
|---|---|
| ナレッジベースCRUD | 作成・表示・削除（ユーザーごとに分離） |
| ドキュメントアップロード | PDF/DOCX対応・ドラッグ&ドロップUI |
| ドキュメント処理 | テキスト抽出 → チャンク分割 → ベクトル化 → Vector DB保存 |
| ベクトル検索チャット | 質問をベクトル化 → 類似チャンク検索 → コンテキスト付き応答 |
| ドキュメント削除 | 関連する全ベクトルデータを含めて削除 |

### アーキテクチャ

#### 技術スタック構成

| レイヤー | 技術 | 役割 |
|---|---|---|
| フレームワーク | Next.js (App Router) | SSR・APIルート |
| AI統合 | Vercel AI SDK | ストリーミング会話・LLM抽象化 |
| LLMオーケストレーション | LangChain.js | ドキュメント処理・RAGチェーン構築 |
| 認証 | 認証サービス（Clerk等） | ユーザー管理・データアクセス保護 |
| KVストア | Redis | ナレッジベースメタデータの管理 |
| ベクトルDB | マネージドVector DB（Upstash Vector等） | 埋め込みの保存・類似検索 |
| UIコンポーネント | Tailwind CSS + shadcn/ui | ドラッグ&ドロップUI・レスポンシブデザイン |

#### データフロー図

```
ドキュメントアップロード
    ↓
テキスト抽出（PDFLoader / DocxLoader）
    ↓
チャンク分割（RecursiveCharacterTextSplitter）
    ↓
埋め込みベクトル生成（Embedding Model: 768次元等）
    ↓
Vector DBへ保存（名前空間: knowledgebaseId でスコープ）
    ↓
─────── クエリ時 ───────
ユーザー質問 → ベクトル化 → 類似チャンク検索 → LLMプロンプトに注入 → 回答生成（ストリーミング）
```

---

### マルチナレッジベース設計

**APIルート設計パターン**:

```
/api/knowledgebase               GET: 一覧取得 | POST: 新規作成
/api/knowledgebase/[id]          GET: 詳細取得 | DELETE: 削除
/api/knowledgebase/[id]/document GET: ドキュメント一覧 | POST: アップロード
/api/knowledgebase/[id]/document/[docId]  DELETE: 個別削除
/api/chat/[knowledgebaseId]      POST: チャット（ストリーミング）
```

**ナレッジベース作成APIパターン**:

```typescript
// /api/knowledgebase/route.ts
export async function POST(request: Request) {
  const { name, description } = await request.json();
  if (!name) return Response.json({ error: 'Name is required' }, { status: 400 });

  // Redis に knowledgebase メタデータを保存
  const kb = await createKnowledgeBase({ name, description });
  return Response.json(kb);  // 201でも可
}
```

**ユーザーごとのデータ分離**:

```
knowledgebases:{userId}           → Set（ナレッジベースIDの集合）
knowledgebase:{kbId}              → Hash（名前・説明・作成日時）
documents:{kbId}                  → Set（ドキュメントIDの集合）
```

---

### マネージドベクトルDB統合

**ローカルベクトルストア vs マネージドDB の判断基準**:

| 観点 | ローカル（HNSWLib等） | マネージド（クラウドVector DB等） |
|---|---|---|
| セットアップ | 即時・依存なし | API設定・認証情報が必要 |
| スケーラビリティ | サーバーメモリに依存 | 自動スケール |
| 永続化 | サーバー再起動で消失リスク | 永続化保証 |
| コスト | 無料 | 利用量課金 |
| データ分離（マルチユーザー） | 自前で名前空間管理が必要 | 名前空間機能を利用 |
| 推奨フェーズ | PoC・開発環境 | 本番・複数ユーザー対応 |

**移行判断のトリガー**:
- ユーザー数が増え、メモリ使用量が問題になる
- サーバーレス環境（Vercel等）でファイルシステム永続化が不可
- データプライバシー/コンプライアンス要件が生じる

**名前空間による分離パターン**:

```typescript
// LangChain.js の UpstashVectorStore を名前空間で分離
const vectorStore = new UpstashVectorStore(embeddings, {
  index: upstashVectorIndex,
  namespace: knowledgebaseId,  // ナレッジベースIDで分離
});

// ドキュメント削除時は名前空間内の関連チャンクを全削除
await vectorStore.delete({ ids: documentChunkIds });
```

---

### ドキュメント処理パイプライン

**パイプライン全体像**:

```
クライアント（ブラウザ）
    ↓ multipart/form-data アップロード
/api/upload
    ↓ 認証確認・ファイルタイプ/サイズ検証
ドキュメントロード
    ├── PDF  → PDFLoader
    └── DOCX → DocxLoader
    ↓
テキスト前処理（特殊文字除去・正規化）
    ↓
チャンク分割（RecursiveCharacterTextSplitter）
    chunkSize: 1000文字程度, overlap: 200文字程度
    ↓
埋め込み生成（Google AI / OpenAI Embedding）
    ↓
Vector DB保存（名前空間付き）
    ↓
Redisにドキュメントメタデータ登録
    ↓
クライアントへ完了レスポンス
```

**ドキュメント処理のセキュリティチェックリスト**:

| チェック項目 | 説明 |
|---|---|
| ファイルタイプ検証 | Content-Type と実際のバイトシグネチャの両方で確認 |
| ファイルサイズ制限 | サーバーリソース枯渇防止（例: 10MB上限） |
| マルウェアスキャン（推奨） | ウイルス検出サービス統合でシステム保護 |
| 処理失敗時のロールバック | 部分アップロード状態を防ぐ |
| 処理後の元ファイル破棄 | 保存が不要なら処理後即削除 |

---

### 状態同期とトラブルシューティング

**クライアント/サーバー状態同期の課題**:

ドキュメント処理（チャンク分割・ベクトル化）は時間がかかるため、クライアントが「処理完了」と思い込んでチャットを開始してしまうケースがある。

| 課題 | 解決策 |
|---|---|
| 処理中にチャットを開始される | サーバー側でステータス管理（`processing` / `ready`）し、フロントエンドでポーリングまたはリアルタイム更新 |
| ベクトルDBへの書き込み遅延 | 処理完了確認後にチャット画面へ遷移するフロー設計 |
| 大きなファイルでタイムアウト | バックグラウンドワーカー/キューイングへのオフロードを検討 |
| 共有ベクトルDBでのクロスユーザー漏洩 | 全クエリに `userId` + `knowledgebaseId` フィルタを強制適用 |

**共有ベクトルDB vs 専用インスタンスの選択**:

| 観点 | 共有DB（名前空間分離） | 専用インスタンス（ユーザーごと） |
|---|---|---|
| コスト | 低い | 高い |
| 運用複雑度 | 低い | 高い |
| データ分離レベル | 論理的（クエリフィルタ） | 物理的 |
| コンプライアンス要件 | 一般的なユースケースに十分 | 規制業種・高機密データ向け |
| 推奨ケース | スタートアップ・中小規模 | エンタープライズ・医療・金融 |

---

## 3. プロジェクト共通パターン

### 認証統合パターン

**Next.js middleware による保護の集約**:

```typescript
// middleware.ts — 認証チェックを単一箇所に集約
export const config = {
  matcher: ['/((?!_next|api/public|favicon.ico).*)'],  // 保護対象ルートの定義
};

export async function middleware(request: NextRequest) {
  const session = await getSession(request);
  if (!session) return NextResponse.redirect(new URL('/login', request.url));
  return NextResponse.next();
}
```

**認証統合チェックリスト**:
- [ ] 全APIルートで認証チェック（サーバーアクション含む）
- [ ] ユーザーIDをデータアクセスキーに必ず含める（他ユーザーデータへのアクセスを防止）
- [ ] セッショントークンはHTTPOnlyクッキーで管理
- [ ] ログアウト時にサーバー側のセッションも無効化

---

### コスト管理パターン

LLM APIの無制限使用はコスト爆発のリスクがある。二重防御でコントロールする。

| 防御レイヤー | 実装 | 効果 |
|---|---|---|
| レート制限 | Redisで時間ウィンドウ（例: 10req/分）を追跡 | 短時間の集中アクセスをブロック |
| メッセージクォータ | ユーザーごとの累積カウント（例: 月100メッセージ） | 長期的な過剰利用を制限 |
| APIコスト監視 | プロバイダーのダッシュボードでアラート設定 | 異常検知・予算超過防止 |
| モデル選択戦略 | 用途別にモデルを使い分け（軽タスク→小型モデル） | コストパフォーマンス最適化 |

**Redisによるレート制限実装パターン**:

```typescript
async function rateLimit(userId: string, limit: number, windowSeconds: number) {
  const key = `rate:${userId}:${Math.floor(Date.now() / (windowSeconds * 1000))}`;
  const count = await redis.incr(key);
  if (count === 1) await redis.expire(key, windowSeconds);
  return { exceeded: count > limit, remaining: Math.max(0, limit - count) };
}
```

---

### アクセシビリティ考慮

| 機能 | 実装パターン |
|---|---|
| TTS統合 | 質問テキストを音声で提供（視覚的な読み取りが難しいユーザーへの配慮） |
| レスポンシブデザイン | Tailwind CSSのブレークポイントで全デバイス対応 |
| セマンティックHTML | `<main>`, `<nav>`, `<section>`等の適切なHTML要素の使用 |
| フォームアクセシビリティ | `aria-label`, `aria-describedby`による説明付与 |
| ドラッグ&ドロップ代替 | ファイル選択ボタンを必ず提供（キーボード操作対応） |

---

### 開発時の課題と教訓

#### 非決定的AI出力への対処

LLMの出力は毎回異なるため、プロダクション品質を担保するには反復的なプロンプト改善が必要。

| 課題 | 対処法 |
|---|---|
| フィードバックの品質ばらつき | プロンプトに評価軸を明示（強み・改善点・技術スキル・コミュニケーション等） |
| 指示無視・脱線 | システムプロンプトで役割と制約を明確化 |
| 長すぎる/短すぎるレスポンス | max_tokens とプロンプト内の「簡潔に答えよ」指示を組み合わせ |

#### プロンプト最適化のイテレーション

```
問題特定 → プロンプト修正 → テスト実行 → 評価 → 繰り返し
```

- 変更は1要素ずつ（複数変更すると効果の特定が困難）
- 代表的なエッジケースをテストセットとして管理
- フィードバックプロンプトの例:

```
面接セッションの包括的なフィードバックを提供してください。
以下の構造で回答してください:
- 総合評価: 全体的なパフォーマンス
- 強み: 優れていた点
- 改善点: 強化すべき領域
- 技術スキル評価: 回答の技術的正確性
- コミュニケーション: 表現力・明瞭さ
- 推奨アクション: 具体的な次のステップ
```

#### API制限・レート制限の実践的対処法

| 問題 | 対処法 |
|---|---|
| LLM APIのレート制限エラー | エクスポネンシャルバックオフによるリトライ |
| ベクトルDB書き込みの遅延 | バッチ処理・非同期処理でスループット改善 |
| ファイルアップロードのタイムアウト | チャンク分割アップロード・プログレス表示 |
| コンテキストウィンドウ超過 | チャンク分割戦略の再調整（サイズ・オーバーラップの最適化） |

---

## 関連リファレンス

| ファイル | 内容 |
|---|---|
| `VERCEL-AI-SDK.md` | `useChat` / `streamText` 等のストリーミング実装 |
| `LANGCHAIN-JS.md` | ドキュメント処理チェーン・RAGリトリーバー実装 |
| `RAG-AND-SUMMARIZATION.md` | RAG設計パターン・要約戦略の詳細 |
| `DEPLOYMENT-SECURITY.md` | 本番デプロイ・セキュリティヘッダー設定 |
| `PROMPT-ENGINEERING.md` | フィードバック生成プロンプトの最適化手法 |
