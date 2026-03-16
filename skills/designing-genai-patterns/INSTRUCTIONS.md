# GenAI デザインパターン

> 32のプロダクション向けGenAIデザインパターン。GenAIアプリケーション設計・RAG戦略選択・エージェントアーキテクチャ・信頼性向上の実践的知識を提供する。

---

## 1. 使用タイミング

このスキルを参照すべき場面:

- **GenAIアプリケーション設計時**: どのパターンを組み合わせるかを判断する際
- **RAG戦略の選択時**: Basic RAGから高度な検索戦略まで、要件に合った手法を選ぶ際
- **エージェントアーキテクチャの設計時**: Tool Calling・Code Execution・Multiagent Collaborationの適切な選択
- **信頼性・品質向上が必要な時**: 幻覚対策・自己修正・評価パターンを実装する際
- **デプロイ最適化が必要な時**: コスト・レイテンシ・スループットのトレードオフを改善する際
- **安全ガードレールの実装時**: 入力検証・出力制御・有害コンテンツフィルタリング

**関連スキルとの差別化:**

| スキル | 対象領域 |
|--------|---------|
| 本スキル（designing-genai-patterns） | フレームワーク非依存のパターン選択・アーキテクチャ設計判断 |
| `building-rag-systems` | RAGの実装詳細（チャンキング・ベクトルDB設定・埋め込み） |
| `practicing-llmops` | LLMの運用・監視・継続的改善 |
| `integrating-ai-web-apps` | WebアプリへのAI統合（Vercel AI SDK・LangChain.js） |

---

## 2. パターンカタログ（32パターン一覧）

### コンテンツ制御（P1–P5）

| # | パターン名 | 1行概要 |
|---|-----------|---------|
| P1 | Logits Masking | Logit値を操作してモデルの出力トークン分布を直接制御する |
| P2 | Grammar | 構造化出力（JSON・XML等）をガラマー制約で強制する |
| P3 | Style Transfer | Few-shotサンプルやLogit調整でスタイルを転換する |
| P4 | Reverse Neutralization | 中立化されたモデルを特定ドメイン・語調に再チューニングする |
| P5 | Content Optimization | 生成コンテンツをユーザーフィードバックで反復的に最適化する |

### RAG基礎（P6–P8）

| # | パターン名 | 1行概要 |
|---|-----------|---------|
| P6 | Basic RAG | ベクトル検索+生成の基本的なRAGパイプライン |
| P7 | Semantic Indexing | 意味論的チャンキングとメタデータで検索精度を向上させる |
| P8 | Indexing at Scale | 大規模データセット向けの分散・階層的インデックス戦略 |

### RAG応用（P9–P12）

| # | パターン名 | 1行概要 |
|---|-----------|---------|
| P9 | Index-Aware Retrieval | インデックス構造を考慮した適応的検索クエリ |
| P10 | Node Postprocessing | 検索結果の後処理（再ランキング・フィルタリング・マージ） |
| P11 | Trustworthy Generation | ソース帰属と引用によって幻覚を抑制する |
| P12 | Deep Search | マルチステップ推論と反復検索で複雑な質問に回答する |

### モデル能力拡張（P13–P16）

| # | パターン名 | 1行概要 |
|---|-----------|---------|
| P13 | Chain of Thought | ステップバイステップの推論を促進して問題解決精度を向上させる |
| P14 | Tree of Thoughts | 複数の思考経路を並列に探索して最良の解を選択する |
| P15 | Adapter Tuning | LoRA等で基盤モデルをドメイン特化タスクに効率的に微調整する |
| P16 | Evol-Instruct | 既存データから進化的手法で高難度学習データを合成生成する |

### 信頼性向上（P17–P20）

| # | パターン名 | 1行概要 |
|---|-----------|---------|
| P17 | LLM-as-Judge | LLM自身を評価者として出力品質を自動採点する |
| P18 | Reflection | エージェントが自身の出力を批評して自己修正する |
| P19 | Dependency Injection | プロンプトへの依存注入でモジュール性とテスト容易性を確保する |
| P20 | Prompt Optimization | 自動最適化手法でプロンプトを継続的に改善する |

### エージェントシステム（P21–P23）

| # | パターン名 | 1行概要 |
|---|-----------|---------|
| P21 | Tool Calling | LLMが外部ツール・API・データベースを呼び出せるようにする |
| P22 | Code Execution | LLMが生成したコードをサンドボックスで実行し結果を取得する |
| P23 | Multiagent Collaboration | 専門エージェント群が協調してワークフローを実行する |

### デプロイ最適化（P24–P28）

| # | パターン名 | 1行概要 |
|---|-----------|---------|
| P24 | Small Language Model | タスク特化のSLMで大型LLMのコスト・レイテンシを削減する |
| P25 | Prompt Caching | 共通コンテキストをキャッシュして繰り返し呼び出しコストを削減する |
| P26 | Inference Optimization | バッチ処理・量子化・投機的デコードで推論を高速化する |
| P27 | Degradation Testing | 継続的テストでモデルのパフォーマンス劣化を早期検出する |
| P28 | Long-Term Memory | セッション横断の記憶管理でパーソナライズされた応答を実現する |

### 安全ガードレール（P29–P32）

| # | パターン名 | 1行概要 |
|---|-----------|---------|
| P29 | Template Generation | 構造化テンプレートで出力の一貫性・安全性を保証する |
| P30 | Assembled Reformat | 複数の安全な断片を組み合わせて出力を構築する |
| P31 | Self-Check | モデルが出力の安全性・正確性を自己検証する |
| P32 | Guardrails | 入力・出力両方にリアルタイムフィルタリングを適用する |

---

## 3. パターン選択フローチャート

### ステップ1: 主要課題の特定

```
GenAIアプリケーションの課題は何か？
│
├─ 出力スタイル・形式の制御 ──────────────────────→ コンテンツ制御カテゴリ（P1-P5）
│
├─ 外部知識・企業データの統合が必要 ────────────────→ [RAG戦略選択 Q1へ]
│
├─ 推論・問題解決精度の向上が必要 ──────────────────→ [推論戦略選択 Q2へ]
│
├─ 自律的なタスク実行が必要 ────────────────────────→ [エージェント選択 Q3へ]
│
├─ コスト・レイテンシの最適化が必要 ────────────────→ デプロイ最適化（P24-P28）
│
└─ セキュリティ・安全性の確保が必要 ────────────────→ 安全ガードレール（P29-P32）
```

### Q1: RAG戦略選択

> **AskUserQuestion**: GenAIアプリケーションに外部知識を統合する必要があります。どのRAG戦略が適切ですか？

**選択肢:**

| 選択 | 推奨パターン | 条件 |
|------|-------------|------|
| Basic RAG（P6） | `references/RAG-FUNDAMENTALS.md` | プロトタイプ・小規模データ・シンプルな要件 |
| Semantic Indexing + Indexing at Scale（P7+P8） | `references/RAG-FUNDAMENTALS.md` | 大規模データ・高精度検索が必要 |
| Advanced RAG（P9-P12） | `references/RAG-ADVANCED.md` | エンタープライズ品質・複雑なクエリ・信頼性要件 |

**判断基準:**
- データ量 < 10万件 → Basic RAG（P6）から始める
- データ量 > 100万件または複数ソース → Indexing at Scale（P8）
- クエリが複雑または多段推論が必要 → Deep Search（P12）

### Q2: 推論戦略選択

> **AskUserQuestion**: LLMの推論能力を強化する必要があります。どのアプローチが適切ですか？

**選択肢:**

| 選択 | 推奨パターン | 条件 |
|------|-------------|------|
| Chain of Thought（P13） | `references/MODEL-CAPABILITIES.md` | 段階的推論・数学・論理問題 |
| Tree of Thoughts（P14） | `references/MODEL-CAPABILITIES.md` | 複数解法の評価・クリエイティブ問題 |
| Adapter Tuning（P15） | `references/MODEL-CAPABILITIES.md` | ドメイン特化・大幅な品質向上が必要 |
| Evol-Instruct（P16） | `references/MODEL-CAPABILITIES.md` | ファインチューニング用データ生成 |

### Q3: エージェントアーキテクチャ選択

> **AskUserQuestion**: エージェントシステムを構築します。どのアーキテクチャが適切ですか？（複数選択可）

**選択肢:**

| 選択 | 推奨パターン | 条件 |
|------|-------------|------|
| Tool Calling（P21）単体 | `references/AGENTIC-SYSTEMS.md` | 単一エージェント・シンプルなタスク自動化 |
| Code Execution（P22） | `references/AGENTIC-SYSTEMS.md` | 計算・データ処理が必要 |
| Multiagent Collaboration（P23） | `references/AGENTIC-SYSTEMS.md` | 複雑なワークフロー・専門分担 |
| P21 + P23の組合せ | `references/AGENTIC-SYSTEMS.md` | 外部ツール利用の複数エージェント協調 |

---

## 4. コアコンセプト

### 基盤モデル（Foundational Models）

**基盤モデル**とは、大規模なデータセットで事前学習された汎用的なAIモデルのこと（GPT、Gemini、Claude、Llama等）。主な訓練フェーズ:

1. **Pretraining**: 大規模テキストコーパスで次トークン予測を学習（汎用的な言語理解）
2. **SFT（Supervised Fine-Tuning）**: 人手による高品質な例文データで指示追従能力を強化
3. **RLHF（Reinforcement Learning with Human Feedback）**: 人間の好みによる強化学習でアライメント向上

**モデルの種類と使い分け:**

| 種類 | 例 | 特徴 |
|------|-----|------|
| Frontier Models | GPT-5, Gemini 2.5 Pro | 最高品質・高コスト・ローカル実行不可 |
| Distilled Models | Gemini Flash, Claude Sonnet | 品質とコストのバランス・高速 |
| Open-weight Models | Llama, DeepSeek, Qwen | プライバシー・カスタマイズ向き |
| Locally Hostable | Llama 8B, Gemma 2B | 完全プライベート・低コスト・性能制限あり |

### Fine-Grained Control（細粒度制御）

LLMの出力を直接制御するための基本パラメータ:

- **Logits**: 最終層の未正規化出力値（P1 Logits Maskingの基礎）
- **Temperature**: 出力のランダム性制御（0=決定的, 高=多様）
- **Top-K Sampling**: 上位K個のトークンのみから選択（長尾を除去）
- **Nucleus Sampling（Top-P）**: 累積確率がp以上のトークン群から選択（動的制御）

### Agentic AI（エージェント型AI）

エージェントの主要特性:

- **自律性**: 明示的プログラムなしに目標に向けて行動
- **ゴール指向**: システムプロンプトで設定した目標を追求
- **計画・推論**: タスクを分解してステップを計画（P13 Chain of Thought）
- **知覚・行動**: 外部ツールを通じた環境への働きかけ（P21 Tool Calling）
- **適応・学習**: 出力を評価して自己修正（P18 Reflection, P31 Self-Check）

### In-Context Learning（インコンテキスト学習）

モデルの重みを変更せずにプロンプト内の情報だけで新タスクに適応する能力:

- **Zero-shot**: 例なしで指示のみ実行
- **Few-shot**: 少数の例示を含めて構造を教示（P13-P16の基礎）
- **Context Engineering**: プロンプトのコンテキスト設計でモデル性能を最大化

---

## 5. ユーザー確認の原則

パターン選択時は以下のAskUserQuestion指示に従って要件を確認してから推奨パターンを提示すること:

### Q4: デプロイ最適化戦略選択

> **AskUserQuestion**: デプロイの制約（コスト・レイテンシ・スループット）は何ですか？

| 制約 | 推奨パターン |
|------|-------------|
| APIコストが高い | P24（SLM）または P25（Prompt Caching） |
| レイテンシが問題 | P26（Inference Optimization） |
| 時間経過による性能劣化が心配 | P27（Degradation Testing） |
| ユーザーのパーソナライゼーションが必要 | P28（Long-Term Memory） |

### Q5: ガードレール戦略選択

> **AskUserQuestion**: アプリケーションに必要な安全性の要件は何ですか？

| 要件 | 推奨パターン |
|------|-------------|
| 出力形式の一貫性確保 | P29（Template Generation） |
| 危険なコンテンツ組合せを防ぐ | P30（Assembled Reformat） |
| 生成前の自己検証 | P31（Self-Check） |
| リアルタイムの入出力フィルタリング | P32（Guardrails） |

---

## 6. 詳細ガイド

各カテゴリの詳細実装ガイドは以下のサブファイルを参照:

| ファイル | 対象パターン | 主な内容 |
|---------|-------------|---------|
| `references/CONTENT-CONTROL.md` | P1–P5 | Logitsベースのスタイル制御・構造化出力・コンテンツ最適化 |
| `references/RAG-FUNDAMENTALS.md` | P6–P8 | Basic RAG実装・意味論的インデックス・大規模インデックス戦略 |
| `references/RAG-ADVANCED.md` | P9–P12 | 高度な検索・後処理・信頼性の高い生成・Deep Search |
| `references/MODEL-CAPABILITIES.md` | P13–P16 | CoT・ToT・ファインチューニング・データ合成 |
| `references/RELIABILITY.md` | P17–P20 | LLM評価・自己修正・依存注入・プロンプト最適化 |
| `references/AGENTIC-SYSTEMS.md` | P21–P23 | Tool Calling・コード実行・マルチエージェント協調 |
| `references/DEPLOYMENT-OPTIMIZATION.md` | P24–P28 | SLM・キャッシング・推論最適化・劣化テスト・長期記憶 |
| `references/SAFETY-GUARDRAILS.md` | P29–P32 | テンプレート生成・再フォーマット・自己チェック・ガードレール |

---

## 7. パターン組合せ指針

### コンポーザブルなアジェンティックワークフロー

プロダクション品質のアジェンティックアプリケーションは複数のパターンを組み合わせて構築する。代表的な組合せパターン:

#### エージェントパターンの基本組合せ

各エージェントは独立して以下のパターンを利用できる:

```
エージェント内部の典型的なパターン組合せ:
├─ 計画・推論: P13（Chain of Thought）
├─ 知識取得: P6（Basic RAG）+ P9（Index-Aware Retrieval）
├─ ツール利用: P21（Tool Calling）
├─ エラー回復: P18（Reflection）+ P31（Self-Check）
└─ リスク制御: P29（Template Generation）+ P30（Assembled Reformat）
```

#### マルチエージェントワークフローの構成

```
マルチエージェントシステム（P23）の典型構成:
├─ Task Assigner Agent: ルーティング判断
├─ Specialist Agents: 各専門エージェント（P6/P9 RAG利用）
├─ Review Panel: P17（LLM-as-Judge）による品質評価
└─ Secretary Agent: P2（Grammar）で構造化出力を統合
```

#### ガバナンス・監視・セキュリティ

```
全エージェントに横断する関心事:
├─ 入力ガードレール: P32（Guardrails）+ P17（LLM-as-Judge）を並列実行
├─ 長期記憶: P28（Long-Term Memory）でユーザー指示を保持
├─ キャッシング: P25（Prompt Caching）でページ再描画コストを削減
└─ 劣化監視: P27（Degradation Testing）で継続的品質チェック
```

#### 学習パイプラインとの統合

アプリケーションをより良くするための継続的改善サイクル:

1. **人間フィードバック収集**: UIを通じた暗黙的フィードバックをログに保存
2. **オフライン評価**: ログデータを使ったバッチ評価
3. **モデル改善**: P5（Content Optimization）+ P15（Adapter Tuning）+ P20（Prompt Optimization）
4. **データ品質向上**: P16（Evol-Instruct）で複雑な学習データを合成生成

### パターン選択の優先順位

1. **まずシンプルなパターンから始める**: Basic RAG（P6）→ Advanced RAG（P9-P12）の順に複雑度を上げる
2. **独立性を維持する**: 各エージェント・パターンは疎結合に保ち個別テスト可能にする
3. **フレームワーク非依存を心がける**: PydanticAI・LlamaIndex等を使いつつもコアロジックを抽象化する
4. **パターン組合せは問題に合わせて選択**: 「全パターンを使う」ではなく「課題解決に必要なもの」を選ぶ

### 代表的なユースケースと推奨パターン組合せ

| ユースケース | 主要パターン | 補完パターン |
|-------------|------------|------------|
| エンタープライズ知識検索 | P7+P8+P9+P11 | P17+P28+P32 |
| コンテンツ生成パイプライン | P3+P13+P17 | P18+P31+P29 |
| 自律コーディングエージェント | P21+P22+P13 | P18+P31+P25 |
| コスト最適化LLMシステム | P24+P25+P26 | P27+P6 |
| マルチエージェント教育コンテンツ | P23+P6+P17+P28 | P32+P25+P18 |
