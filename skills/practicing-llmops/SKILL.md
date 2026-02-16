---
description: >-
  Comprehensive LLMOps operational framework covering data engineering pipelines,
  model domain adaptation (fine-tuning, RAG, prompt engineering), API-first deployment,
  LLM evaluation metrics, LLMSecOps security audits, and infrastructure scaling.
  MUST load when building or operating LLM-based applications in production.
  For RAG implementation details, use building-rag-systems. For general monitoring
  patterns, use designing-monitoring. For AI development methodology, use developing-with-ai.
---

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
