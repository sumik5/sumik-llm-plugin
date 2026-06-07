# MCPエコシステム

MCPの真の力は、その仕様だけでなく、周辺に成長する活気あるコミュニティと相互接続ツールネットワークにある。このファイルは、公式レジストリ、サーバー/クライアントランドスケープ、新興パターン、将来展望を網羅。

---

## MCPレジストリ

### 発見問題の解決

初期段階では新規サーバー発見は手作業・非公式（SNS、"Awesome MCP Servers" GitHub等）。しかしこれらは中央集権的・プログラマティック・信頼できる発見方法を欠いていた。

**MCP Registry**の登場がこの問題を解決。

### 公式MCPレジストリ

**概要**

- 公式レジストリ: `registry.modelcontextprotocol.io`
- すべての公開MCPサーバーの唯一の権威ソース
- AI agent capabilityの"App Store"として機能

**アーキテクチャ**

単なるWebサイトではなく、OpenAPI仕様に基づく公開API。

| 役割 | 機能 |
|------|------|
| **Server Maintainer向け** | `mcp-publisher` CLIツールで公開。GitHubアカウント等で認証し、`server.json`マニフェスト（名前、説明、キーワード、接続手順）を提出 |
| **Client Developer向け** | Host（IDE/チャットボット）がプログラマティックにレジストリAPIをクエリ。キーワード（"database"）、カテゴリ（"finance"）、著者で検索可能。Host内に検索可能な"マーケットプレイス"UIを構築可能 |

### Federated Model（連合モデル）

**Sub-registries（サブレジストリ）**

公式レジストリは基盤層として機能し、サブレジストリ確立を許容。

| タイプ | 説明 | 例 |
|-------|------|---|
| **Public Sub-registries** | コミュニティ駆動プラットフォーム。公式レジストリからデータ取得し、独自の厳選マーケットプレイス提示。ユーザーレビュー、セキュリティ評価、チュートリアル追加可能 | mcp.so, glama.ai |
| **Private Sub-registries** | 厳格なセキュリティ・プライバシー要件を持つ大企業向け。完全にファイアウォール内のプライベート内部レジストリ。内部MCPサーバーの安全なカタログを提供 | 企業内部レジストリ |

**利点**

- 中央集権的オープン標準（パブリックアクセス）
- プライベート・セキュアデプロイメントへの適応性（組織内）

---

## サーバーランドスケープ

MCPレジストリとコミュニティリストは数千のサーバーをカタログ化。ほぼすべてのソフトウェア開発ドメインをカバー。

### 主要カテゴリ

#### 1. Knowledge and Memory（知識・メモリ）

Agent長期記憶を提供し、会話を越えて情報を永続化。

| サーバー | 説明 |
|---------|------|
| **Zep Graphiti** | 知識グラフを使用した長期記憶OSS。会話からエンティティ（人・場所・概念）と関係を自動抽出・保存。ユーザー設定、プロジェクト詳細、過去のインタラクションを学習・記憶 |
| **RAG Platforms** | Ragie、VectaraなどのRAG-as-a-Serviceプラットフォーム。強力なドキュメント取込・検索機能をシンプルなMCPサーバー経由で公開。カスタム知識ベースでAgentを簡単にGround |

#### 2. Developer Tools and Code Execution（開発ツール・コード実行）

最大かつ最活発なカテゴリ。AI assistantを真のペアプログラマーに変換。

| サーバー | 説明 |
|---------|------|
| **Code Execution** | Jupyter、E2B等。安全なサンドボックス環境でコード実行。JupyterサーバーはNotebookでコード書込・実行・出力確認・プロット生成。E2Bはクラウドベース安全サンドボックス提供 |
| **Version Control** | GitHub、GitLabの公式・コミュニティビルトサーバー。Issue閲覧、PR作成、リポジトリ内容分析、CI/CDパイプライン連携 |
| **Cloud Platforms** | AWS、Cloudflare、Vercel。Agentがクラウドインフラと対話・管理（サーバーレス関数デプロイ、DB状態確認、DNS管理） |

#### 3. Database and Data Platform Access（データベース・データプラットフォーム）

データの汎用トランスレータとして機能。

| サーバー | 説明 |
|---------|------|
| **MindsDB** | 数十の異なるデータソース（PostgreSQL、CockroachDB、Salesforce、Slack）に接続可能な強力なOSSプラットフォーム。単一統合MCPサーバーで自然言語クエリ |
| **Dedicated Database** | Qdrant、Weaviate、Neon、Supabase。ほぼすべての人気データベース（従来SQL〜最新ベクトルDB）でMCPサーバー利用可能 |

#### 4. Web Access and Automation（Web アクセス・自動化）

Agentのインターネットにおける目と手。

| サーバー | 説明 |
|---------|------|
| **Browser Automation** | Playwright、Puppeteerライブラリ統合。Agentがローカル・リモートブラウザ制御。フォーム入力、ボタンクリック、動的JavaScript重視Webサイトからデータ抽出 |
| **Web Scraping Services** | Bright Data、Firecrawl等商用サービス。大規模Webスクレイピングプロジェクト向け。IPブロック、CAPTCHA、ヘッドレスブラウザ管理を回避 |

#### 5. Workplace and Productivity（ワークプレイス・生産性）

ナレッジワーカーが日常使用するツールにAgentを接続。

| カテゴリ | 例 |
|---------|---|
| **Project Management** | Asana、Jira、Linear（タスク・Issue作成・更新・検索） |
| **Communication** | Slack、Discord、Gmail（メッセージ読込・チャネル要約・返信草案） |
| **Knowledge Management** | Notion、Confluence（企業内部Wiki・知識ベース検索・情報取得） |

---

## ホスト/クライアントランドスケープ

豊富なサーバーエコシステムは、強力なClient/Hostがあって初めて有用。Host = ユーザー対面アプリケーション（開発者・ユーザーがAIと対話する環境）。

### 1. AI-Powered IDEs: Developer's Cockpit

最も成熟したMCP Hostカテゴリ。深くAI assistantを統合したコードエディタ。

| IDE | 説明 |
|-----|------|
| **Cursor** | 最初期かつ最も顕著なMCP採用者。AI-firstコードエディタ。ファイルシステムアクセス、Web検索、ドキュメント取得等幅広いサーバーに接続。組込MCPサーバー管理UIで`mcp.json`直接読込、新規ツール追加・設定が容易 |
| **Cline** | 強力なVS Code拡張。世界で最も人気のエディタを洗練されたMCP Hostに変換。VS Code環境内で直接AI agentをローカル・リモートサーバーに接続 |
| **Windsurf** | VS Codeベースで構築されたAI駆動コードエディタ。MCP強力サポート。コーディングアシスタントをカスタムツール・データソースに簡単接続、エディタ機能をオンザフライで拡張 |
| **Roo Code** | エディタ統合AI駆動自律コーディングAgent。自然言語通信、ワークスペース内直接ファイル操作、ターミナルコマンド実行、ブラウザ操作自動化、OpenAI互換/カスタムAPI統合、カスタムモードで"personality"・機能カスタマイズ |

### 2. Conversational Powerhouses: Desktop Agents

AI豊富なマルチモーダルチャット体験に焦点。MCPでAgentに超能力を付与。

| アプリ | 説明 |
|-------|------|
| **Claude Desktop** | AnthropicのMCP作成者による公式デスクトップアプリ。ネイティブファーストクラスプロトコルサポート。Claudeをメモリ・DBアクセス等幅広いツールに接続。開発者フレンドリーな設定で新規サーバーテスト・開発に理想的 |
| **Block's Goose** | Block（旧Square）の革新的プロジェクト。高度でマルチモーダルなAI assistant。大企業がMCPを使用して強力でカスタマイズされた内部Agentを構築する好例。金融・決済API等自社サービス・インフラと深く統合 |

### 3. Headless and Terminal Clients: For Power Users

全ClientがGUI必要とするわけではない。ターミナル常駐開発者向けツール増加中。

| クライアント | 説明 |
|------------|------|
| **Claude Code** | ターミナル常駐Agentic codingツール。コードベース理解、日常タスク実行、複雑コード説明、Gitワークフロー処理をすべて自然言語コマンドで実現し、高速コーディング支援 |
| **Gemini CLI** | GoogleのオープンソースCLI Agent。MCP専用クライアントではないがアーキテクチャ完璧適合。MCP clientをツールプロバイダーとして設定可能。Gemini力とMCPツール宇宙をシェルスクリプト・ターミナルワークフローに直接導入 |

**成功の証**

幅広いHostアプリケーションの存在がMCPの成功を示す。1つの適切に構築されたサーバー（例: SQLite Explorer）が、多様なユーザー対面アプリで即座に動作。

---

## 公式SDK

| 言語 | リポジトリ/パッケージ |
|------|---------------------|
| **TypeScript/JavaScript** | `@modelcontextprotocol/sdk` (NPM)<br>GitHub: modelcontextprotocol/typescript-sdk |
| **Python** | `mcp` (PyPI)<br>GitHub: modelcontextprotocol/python-sdk |
| **Java** | SDK開発中 |
| **Kotlin** | SDK開発中 |
| **C#/.NET** | SDK開発中 |

---

## 新興パターンとベストプラクティス

エコシステム成熟に伴い、AI-nativeシステムの未来を示す新アーキテクチャパターンが出現。

### 1. Tool Marketplaceの台頭

公開・プライベートMCPサーバーレジストリ出現。

- **企業内部マーケットプレイス**: チームが信頼できるツールを公開・発見
- **公開マーケットプレイス**: 企業が公式・安全なMCPサーバーでAPIを提供。Agentが新機能を動的に発見・使用

### 2. Multi-agent Systems（MCP + A2A）

未来は単一モノリシックAgentではなく、協調的・特化Agentシステム。

- **MCP + Agent2Agent (A2A) プロトコル協調**
- オーケストレーションAgentがA2Aで研究タスクを研究Agentに委譲
- 研究AgentがMCPでツール（DB、Web検索等）と通信してタスク完遂

### 3. 新セキュリティスタック

Agenticシステム固有脅威が新セキュリティレイヤーを生む。

- **mcp-scan**: 静的"Toxic Flow Analysis"
- **Secure Hulk**: MCPトラフィックリアルタイム監視ランタイムガードレール
- 従来Webアプリの**WAF (Web Application Firewall)** と同等の必須性

---

## MCPロードマップ

### 正式標準への道

MCPスペックは生きたドキュメント。バージョニング（例: 2025-06-18）はコミュニティフィードバックと実装経験に基づく継続的改良を反映。

**今後の注力領域**

| 項目 | 説明 |
|------|------|
| **Hardened Security Model** | OAuth 2.1統合の更なる改良。agent-to-agent通信向け`client_credentials`等異なるグラントタイプガイドライン明確化 |
| **Richer Capability Definitions** | Tool/Resourceスキーマの表現力強化。高度アノテーションオプション |
| **Standardized Error Handling** | より詳細なエラーコードでClientに豊富な診断情報提供 |

### A2Aプロトコルとの関係

- **MCP**: Agent ↔ Tool通信
- **A2A (Agent2Agent)**: Agent ↔ Agent通信
- 両プロトコルが協調して複雑マルチAgentシステムを実現

---

## リソース

### 公式ドキュメント

- **MCP Official Website**: https://modelcontextprotocol.io
- **MCP Specification**: https://spec.modelcontextprotocol.io
- **Official MCP Blog**: https://blog.modelcontextprotocol.io

### SDK

- **TypeScript SDK**: https://github.com/modelcontextprotocol/typescript-sdk
- **Python SDK**: https://github.com/modelcontextprotocol/python-sdk

### レジストリ

- **Official MCP Registry**: https://registry.modelcontextprotocol.io
- **Glama.ai Directory**: https://glama.ai/mcp/servers
- **Awesome MCP Servers**: https://github.com/punkpeye/awesome-mcp-servers
- **MCP.so**: https://mcp.so

### セキュリティツール

- **Damn Vulnerable MCP (DVMCP)**: https://github.com/harishs-g/damn-vulnerable-mcp
- **mcp-scan**: https://invariantlabs.ai/blog/introducing-mcp-scan
- **Secure-Hulk**: https://github.com/AppiumTestDistribution/secure-hulk

### Host/Client

- **Cursor**: https://cursor.sh
- **Cline**: https://docs.cline.bot
- **Windsurf**: https://windsurf.ai
- **Claude Desktop**: https://anthropic.com/claude
- **Gemini CLI**: https://github.com/google/gemini-cli

---

## エコシステムまとめ

MCPは技術仕様を超え、活気あるエコシステムの基盤となった。

- **Discovery Solved**: 公式レジストリで中央集権的プログラマティック発見を実現
- **Two-Sided Ecosystem**: Server（機能提供者）とClient/Host（機能消費者）双方の多様性
- **Network Effect**: 新Client登場でServer開発者価値増、新Server登場でClientユーザー価値増
- **Federated Model**: 公開レジストリとプライベートサブレジストリの共存
- **Future-Ready**: Multi-agent Systems、Tool Marketplace、新セキュリティスタックへ進化

このエコシステムこそ、MCPの約束実現の最終形態: 強力なAI capabilityが簡単に発見・共有・組合せられる世界。全員のイノベーションペースを加速。
