# AIエクスペリエンス設計ガイド

AIプロダクトのUXデザインに特化したフレームワーク。Input → Computation → Output の全フローをカバーする。

> 一般的なUI/UXビジュアルデザインは `designing-ux` を参照。
> デザイン思考プロセス・UXリサーチは `practicing-design-thinking` を参照。
> 行動変容設計（習慣化）は `applying-behavior-design` を参照。

---

## スキル構成

| ファイル | 内容 |
|---------|------|
| [AIX-AI-EXPERIENCE-GUIDE.md](references/AIX-AI-EXPERIENCE-GUIDE.md) | AIインターフェース設計完全ガイド（概要・全フレームワーク） |
| [AIX-MENTAL-MODELS.md](references/AIX-MENTAL-MODELS.md) | ユーザーメンタルモデル・AI歴史・組織成熟度診断 |
| [AIX-FRAMING-METHODS.md](references/AIX-FRAMING-METHODS.md) | ストーリーボード・デジタルツイン・Value Matrix |
| [AIX-INPUT-DESIGN.md](references/AIX-INPUT-DESIGN.md) | 3チャネル設計・CARE Framework・Voice入力3タイプ |
| [AIX-COMPUTATION-UX.md](references/AIX-COMPUTATION-UX.md) | 処理パイプライン・ルーティング・レイテンシー管理 |
| [AIX-OUTPUT-DESIGN.md](references/AIX-OUTPUT-DESIGN.md) | 出力5原則・AI Overreliance対策・Watermarking |
| [AIX-COPILOT-PATTERNS.md](references/AIX-COPILOT-PATTERNS.md) | SaaS Copilot配置・Discovery 4パターン・7 LLMパターン |
| [AIX-AI-FIRST-UX.md](references/AIX-AI-FIRST-UX.md) | AI-First IA・Forecasting・Anomaly Detection UI |
| [AIX-AGENTIC-DESIGN.md](references/AIX-AGENTIC-DESIGN.md) | 5 Agenticパターン詳細・チェックポイント・権限設計 |
| [AIX-RESEARCH-AND-ETHICS.md](references/AIX-RESEARCH-AND-ETHICS.md) | MUSE・RITE・AIバイアス対策・AI Humanifesto |

---

## AIプロジェクト失敗の5パターン（5 Fails）

| # | パターン | 対策 |
|---|---------|------|
| 1 | 間違ったユースケース選択 | Value Matrixで価値検証 |
| 2 | ビジョンの欠如 | AIストーリーボード（5要素）でフレーミング |
| 3 | データ品質の無視 | デジタルツインで全体像可視化 |
| 4 | ユーザーリサーチ省略 | MUSE / RITE でAI-Inclusive UCD |
| 5 | 倫理・バイアス無視 | AI Humanifesto 5原則でチェック |

---

## 主要設計フレームワーク

| フレームワーク | 概要 |
|--------------|------|
| 3チャネルモデル | 暗黙コンテキスト・明示プロンプト・直接操作でユーザー意図を翻訳 |
| CARE Framework | Context/Action/Results/Examples でプロンプトUI設計 |
| 出力5原則 | Clear・Verifiable・Grounded・Actionable・Adjustable |
| 5 Agenticパターン | Reflection/Tool Use/Planning/Multiagent/ReAct |

---

## When to Use（場面別ガイド）

| 場面 | 参照先 |
|------|--------|
| AIプロダクトのユースケース検証 | AIX-FRAMING-METHODS.md（Value Matrix） |
| プロンプトUIを設計したい | AIX-INPUT-DESIGN.md（CARE Framework） |
| AI出力の表示方法を決めたい | AIX-OUTPUT-DESIGN.md（出力5原則） |
| Copilot機能をSaaSに組み込む | AIX-COPILOT-PATTERNS.md |
| エージェント型システムのUXを設計 | AIX-AGENTIC-DESIGN.md |
| AI向けユーザーリサーチを実施 | AIX-RESEARCH-AND-ETHICS.md（MUSE・RITE） |
| AI倫理・バイアスを評価 | AIX-RESEARCH-AND-ETHICS.md（AI Humanifesto） |
| ユーザーのメンタルモデルを理解 | AIX-MENTAL-MODELS.md |

---

## 設計判断ルール（抜粋）

- **If** AIが失敗する可能性がある **then** 失敗の種類（間違い/不確実/拒否）を明示し、ユーザーが修正できるUIにする
- **If** AI出力を表示する **then** 出力5原則（Clear・Verifiable・Grounded・Actionable・Adjustable）に照らして評価する
- **If** ユーザーがAIに意図を伝えるUIを設計する **then** 3チャネル（暗黙コンテキスト/明示プロンプト/直接操作）から最適チャネルを選ぶ
- **If** エージェント型システムを設計する **then** チェックポイントと権限設計で人間の監督（human-in-the-loop）を確保する
- **If** AIリサーチを実施する **then** AI特有のバイアス（automation bias, overtrust）を考慮した MUSE/RITE 手法を使う
