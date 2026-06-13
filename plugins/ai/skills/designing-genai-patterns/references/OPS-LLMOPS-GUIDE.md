# LLMOps実践ガイド

本スキルはLLM（大規模言語モデル）を本番環境で運用するための包括的なフレームワークを提供する。MLOps/DevOpsの知見をベースに、LLM特有の課題（確率的出力、動的な振る舞い、巨大なコンテキスト管理）に対応する運用手法を定義する。

---

## LLMOpsの定義

LLMOpsはLLMアプリケーションを本番環境で運用するためのフレームワーク。MLOps/DevOpsから派生しているが、LLM特有の課題に対応した新しい実践体系である。

### 4つの目標

| 目標 | 説明 |
|------|------|
| **Reliability** | 信頼性の高い予測可能な動作を保証 |
| **Scalability** | 需要に応じた効率的なスケーリング |
| **Robustness** | 想定外の入力や環境変化への耐性 |
| **Security** | データプライバシーとモデル安全性の確保 |

---

## MLOps vs LLMOps：主要な違い

| ライフサイクル | MLOps | LLMOps |
|--------------|-------|--------|
| **Data** | 構造化データ、固定スキーマ、人手でラベリング | 非構造化データ、柔軟なスキーマ、プロンプトベース |
| **Model** | タスク特化型、数百万〜数億パラメータ | 汎用モデル、数十億〜数千億パラメータ |
| **Evaluation** | 決定論的、標準メトリクス（Accuracy/F1） | 非決定論的、複合メトリクス（Factuality/Toxicity） |
| **Deployment** | リアルタイム推論、低レイテンシ | ストリーミング応答、高レイテンシ許容 |
| **Monitoring** | ドリフト検出、パフォーマンス劣化 | プロンプトドリフト、幻覚検出、毒性モニタリング |
| **Security** | 標準的なMLセキュリティ | プロンプトインジェクション、データリーク、脱獄対策 |
| **Adaptation** | 再学習・ファインチューニング | プロンプトエンジニアリング、RAG、コンテキスト学習 |

---

## 成熟度モデル

LLMOps成熟度は3段階で評価する。

| Level | 名称 | 特徴 |
|-------|------|------|
| **Level 0** | 手動オペレーション | スクリプトベース、手動デプロイ、モニタリングなし |
| **Level 1** | 半自動化 | CI/CD統合、基本的なモニタリング、プロンプトバージョニング |
| **Level 2** | 完全自動化 | エンドツーエンドパイプライン、リアルタイム評価、自動スケーリング |

**目標**: Level 2を目指し、データパイプライン・評価・デプロイの自動化を段階的に導入する。

---

## LLMアーキテクチャ選定

用途に応じて適切なアーキテクチャを選択する。

| アーキテクチャ | 用途 | 代表例 |
|--------------|------|--------|
| **Encoder-Only** | テキスト理解、分類、埋め込み生成 | BERT, RoBERTa |
| **Decoder-Only** | テキスト生成、補完、創作 | GPT-3/4, LLaMA |
| **Encoder-Decoder** | 翻訳、要約、構造変換 | T5, BART |
| **State Space Models** | 長文処理、低メモリフットプリント | Mamba |
| **Small Language Models (SLM)** | エッジデバイス、特定タスク特化 | DistilBERT, MobileBERT |

**判断基準**:
- テキスト生成が主目的 → Decoder-Only
- 理解・分類タスク → Encoder-Only
- 入出力が異なる構造 → Encoder-Decoder
- 超長文（100K+ tokens）処理 → State Space Models

---

## LLMベースアプリケーション設計

### エージェント類型

| 類型 | 説明 | 用途 |
|------|------|------|
| **Reflex Agent** | ルールベース、単一ステップ | SQL生成、簡単な質問応答 |
| **Chain-of-Thought Agent** | 段階的推論、プロンプト内分解 | 数学問題、論理推論 |
| **Plan-and-Act Agent** | 計画策定後に実行 | ブログ執筆、プロジェクト管理 |
| **Reflective Agent** | 自己評価・改善ループ | コードレビュー、論文執筆 |
| **Multi-Agent System** | 複数エージェントの協調 | 複雑なワークフロー自動化 |

### インフラ標準プロトコル

| プロトコル | 役割 | 主要概念 |
|-----------|------|----------|
| **MCP (Model Context Protocol)** | モデル↔ツール連携 | Tools, Resources, Prompts |
| **A2A (Agent-to-Agent Protocol)** | エージェント間通信 | Agent Cards, Capability Discovery |

---

## LLM構築の10の課題

| 課題 | 説明 | 対策 |
|------|------|------|
| 1. **サイズと複雑性** | 数十億パラメータ、サイレント失敗 | 構造化評価、複数メトリクス |
| 2. **訓練スケール** | 大規模データ、長期訓練、GPU/TPU管理 | 分散訓練、ハードウェア計画 |
| 3. **プロンプトエンジニアリング** | プロンプト依存、モデルドリフト | バージョニング、監視パイプライン |
| 4. **推論レイテンシ** | リアルタイム応答、スループット最適化 | キャッシング、バッチ処理 |
| 5. **倫理的配慮** | バイアス、毒性、社会的影響 | フェアネス評価、セーフガード |
| 6. **リソースオーケストレーション** | 動的スケーリング、ロードバランシング | 自動スケーリング、マルチモデル管理 |
| 7. **統合とツールキット** | API統合、バージョン管理 | セキュアAPI設計、互換性テスト |
| 8. **広範な適用性** | 未テストシナリオへの曝露 | 高速フィードバックループ、A/Bテスト |
| 9. **プライバシーとセキュリティ** | PII漏洩、プロンプトインジェクション | データ匿名化、入力検証 |
| 10. **コスト** | 訓練・推論の高コスト、実験費用 | コスト監視、モデル最適化 |

---

## リファレンスナビゲーション

詳細な実装ガイドは以下のリファレンスを参照。

| リファレンス | 内容 |
|-------------|------|
| [DATA-ENGINEERING.md](references/DATA-ENGINEERING.md) | データパイプライン、前処理、ストレージ、埋め込み管理 |
| [MODEL-ADAPTATION.md](references/MODEL-ADAPTATION.md) | プロンプトエンジニアリング、ファインチューニング、RAG、量子化 |
| [API-DEPLOYMENT.md](references/API-DEPLOYMENT.md) | APIファースト設計、ビジネスモデル（IaaS/PaaS/SaaS）、レイテンシ最適化 |
| [EVALUATION.md](references/EVALUATION.md) | 評価フレームワーク、メトリクス、ベンチマーク、人手評価 |
| [SECURITY-GOVERNANCE.md](references/SECURITY-GOVERNANCE.md) | LLMSecOps、プライバシー、ガバナンス、監査フレームワーク |
| [SCALING-INFRASTRUCTURE.md](references/SCALING-INFRASTRUCTURE.md) | ハードウェア選定、リソース管理、分散訓練、監視 |
| [AGENTOPS.md](references/AGENTOPS.md) | **🆕** AgentOps詳細リファレンス（ロール・FM選定・Prompt Catalog・評価・アーキテクチャ） |

---

## AskUserQuestion指針

以下の判断分岐で必ずユーザー確認を実施する:

| 状況 | 確認内容 |
|------|----------|
| モデル選定時 | オープンソース vs プロプライエタリ、アーキテクチャ選択 |
| データ取り込み前 | PII含有リスク、ライセンス確認 |
| デプロイ戦略 | IaaS/PaaS/SaaS選択、コスト試算 |
| 評価メトリクス | タスク固有メトリクス、受容基準 |
| セキュリティポリシー | データ保持期間、プロンプトインジェクション対策レベル |

---

## 次のステップ

1. **成熟度評価**: 現在のLLMOps成熟度を測定（Level 0/1/2）
2. **課題特定**: 10の課題から優先順位を決定
3. **リファレンス参照**: 該当セクションの詳細実装を確認
4. **段階的導入**: Level 0 → 1 → 2へ段階的に自動化を進める

---

## MLOps → GenAIOps → AgentOps 進化

「Ops」ディシプリンは**加算的進化**を遂げる。旧来のレイヤーはなくならず、新しい課題に対応した上位概念が積み重なる。

### 進化の全体像

```
Model Development（モデル創造者）
  DevOps
    └── MLOps（非決定論的ML対応: 継続監視・再訓練・データガバナンス）
          └── FMOps / LLMOps（大規模Foundation Model対応）

Application Development（モデル消費者）
  GenAIOps（非決定論的GenAIアプリケーション本番化）
    ├── PromptOps（プロンプト再利用・バージョニング・評価）
    ├── RAGOps（データ取得パイプライン〜回答生成の標準化）
    └── AgentOps（エージェント+ツールの複合システム本番化）
```

**重要**: ほとんどの企業は**Model Consumer**。既存FMをAPI経由で消費し、アプリケーション開発に集中する。

### AgentOps固有の4課題

GenAIOps（PromptOps/RAGOps）が解決済みの課題に加え、AgentOpsは以下の4課題を扱う:

| 課題 | 説明 | なぜ難しいか |
|------|------|------------|
| **1. Autonomous Decision-Making** | ツール選択・実行順序をエージェントが自律決定 | 入出力だけでなく「推論パス」の評価が必要 |
| **2. Tool Orchestration & Governance** | 複数ツールの連携・ライフサイクル管理 | Tool Registry による組織横断ガバナンスが必須 |
| **3. Complex Memory Management** | Short-Term（会話内）+ Long-Term（セッション横断）メモリ | データプライバシー・ガバナンス・評価への影響 |
| **4. Multi-Agent Systems** | 専門エージェント群の協調・分散システム管理 | マイクロサービス的な監視・デバッグが必要 |

---

## Agent評価プロセス

GenAIOpsのPrompt Catalogベース評価を**拡張**する5段階プロセス。

### 5段階評価フロー

| ステップ | 内容 |
|---------|------|
| Step 1: Tool Unit Tests | 各ツールを単独で検証（前提条件） |
| Step 2: データセット拡張 | Prompt Catalogにfunction-calling data追加 |
| Step 3: Trajectory Evaluation | ツール選択成功率・パラメータ精度・不要呼び出し防止率 |
| Step 4: End-to-End Evaluation | ユーザー入力→最終出力の品質・正確性（従来GenAIOps評価） |
| Step 5: Operational Metrics | レイテンシ・コストの本番適合性確認 |

**Evaluation Prompt Catalogの拡張**: 従来のプロンプト+期待出力ペアに、期待ツール呼び出し列・パラメータ例・ツール出力例を追加する。

**FM Reference Table**: 組織として5〜20モデルをEULA法的審査済みで事前登録し、自社データ評価と精度/コスト/レイテンシのトレードオフで選定する（詳細 → [AGENTOPS.md](references/AGENTOPS.md)）。

---

## Tool Registry

### 概要

組織全体のツールを一元管理する**権威あるカタログ**。

```
Tool Registry（中央カタログ）
  ├── Local Functions（内部システム上のコード関数）
  ├── Private APIs（セキュアクラウド上のプライベートAPI）
  └── Public Services（サードパーティの公開サービス）
         ↓
  各エージェントは「tool list」（レジストリのサブセット）を受け取る
```

### 提供価値

| 価値 | 説明 |
|------|------|
| **再利用性** | 既存ツールの検索・発見（車輪の再発明防止） |
| **標準化** | ツール定義・インターフェースの統一 |
| **セキュリティ** | アクセス制御・脆弱性管理の一元化 |
| **監査可能性** | ツール使用履歴・バージョン変更の追跡 |

### メタデータ管理

各ツールエントリーに含める情報:
- **バージョン**: セマンティックバージョニング
- **オーナーシップ**: 担当チーム・連絡先
- **セキュリティ分類**: データアクセスレベル・副作用の種別
- **依存関係**: 必要な認証・外部サービス
- **使用例**: Few-shot examples for LLM tool selection

Tool RegistryはMCP標準（`developing-mcp` スキル参照）で実装可能。MCPサーバーとして公開し、各エージェントがMCPクライアントとして消費する。

---

## Agent Registry

### 概要

組織内の全デプロイ済みエージェントを管理する**中央ディレクトリ**。

### AgentCard（A2Aプロトコル）

各エージェントの「名刺」として機能するメタデータ:
- **能力記述**: エージェントが解決できるタスク
- **入出力スキーマ**: 期待する入力・出力の形式
- **エンドポイント**: 呼び出し方法（A2Aプロトコル）
- **ツール一覧**: エージェントが使用するツールのリスト

### Agent Template Catalog

Agent Registryはソースコードへのリンクを通じて**テンプレートカタログ**としても機能:
- 既存エージェントのコードを雛形として新規開発を加速
- ベストプラクティスが組み込まれたスターターテンプレート
- ゼロから始めずに「似たエージェント」を起点に開発

### ガバナンス機能

| 機能 | 説明 |
|------|------|
| **バージョニング** | エージェント定義のバージョン管理・ロールバック |
| **アクセス制御** | 誰がエージェントを呼び出せるか（IAM連携） |
| **ツール認可** | エージェントがアクセス可能なツール・データの範囲 |
| **監査ログ** | エージェント間通信・ツール呼び出しの記録 |

**Agents as a Service**: エージェントを独立マイクロサービスとしてデプロイし、専用CI/CDパイプラインで管理。A2Aプロトコルで他エージェントと通信し、Agent Registryで発見・アクセス制御する。

---

## Memory & Data Governance

### 2種類のメモリ

| 種類 | 配置場所 | 用途 | 実装例 |
|------|---------|------|--------|
| **Short-Term Memory** | Production Environment（エージェントと同居） | 進行中会話のコンテキスト追跡（マルチターン） | Cloud Trace / OpenTelemetry |
| **Long-Term Memory** | Data Project（永続ストレージ） | 過去会話・ユーザー嗜好の記憶（セッション横断） | BigQuery / Firestore / Spanner（Graph DB） |

Long-Term Memoryの蓄積データはVector化してRAGシステムに入力することで、エージェントが過去の会話文脈を参照できる。

### データガバナンス要件

メモリには**機密・個人情報**が含まれる可能性があるため:

- **開発時の露出防止**: テスト環境で本番メモリにアクセスできないよう分離
- **アクセスポリシー**: 誰がメモリを読み書きできるかをIAMで制御
- **データ保持ポリシー**: Short-Term（セッション終了後に削除）vs Long-Term（保持期間定義）
- **PII検出・マスキング**: 個人情報の自動検出と匿名化パイプライン

---

## Unified AgentOps Platform アーキテクチャ

| レイヤー | GenAIOps（既存） | AgentOps追加 |
|---------|----------------|-------------|
| **Data Project** | RAG向けデータ準備・Evaluation Prompt Catalog | Long-Term Memory / Trajectory評価データ |
| **Development** | GenAI App開発環境 | Agents as a Service開発・CI/CDパイプライン |
| **Production** | GenAIアプリ本番稼働 | Short-Term Memory / A2A通信 |
| **Governance（AI Control Tower）** | Prompt Template Catalog / モデルレジストリ | **Tool Registry + Agent Registry** |

詳細なリファレンスアーキテクチャ・ロール定義・評価フロー → [AGENTOPS.md](references/AGENTOPS.md)
