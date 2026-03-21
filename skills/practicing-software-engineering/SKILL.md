---
name: practicing-software-engineering
description: >-
  Comprehensive SW engineering practices covering project foundations (fast feedback, small steps,
  DORA metrics), team organization (Team Topologies, 4 types), pair programming (4 patterns),
  developer habits (GREAT framework), IC effectiveness mindset (outcomes vs outputs, strategic
  prioritization), career-stage skills (junior to staff, IC vs management), cross-functional
  influence (PM/design, authority-free leadership), 20 anti-patterns (15 individual + 5
  team-level), sustainable performance (burnout, remote work), and AI-enhanced workflows (daily
  AI, 90-day rollout). Use when starting projects, organizing teams, for IC effectiveness,
  career growth, or team AI culture.
  For TDD/BDD/ATDD, use testing-code instead.
  For SOLID/refactoring, use writing-clean-code instead.
  For CI/CD, use practicing-devops instead.
  For DDD/Clean Architecture, use applying-clean-architecture instead.
  For ODD/debugging, use implementing-observability instead.
  For prompt engineering techniques, use developing-with-ai instead.
---

# ソフトウェアエンジニアリングプラクティス

新しいプロジェクトを成功させるための基盤構築から、チーム組織設計、ペアプログラミング、
優れた開発者習慣まで、ソフトウェア開発の横断的プラクティスを体系化したガイド。

---

## このスキルの使い方

| 状況 | 参照先 |
|------|--------|
| 新規プロジェクト開始時の基盤設計 | [FOUNDATIONS.md](./FOUNDATIONS.md) |
| チーム組織設計・チームトポロジー | [TEAM-ORGANIZATION.md](./TEAM-ORGANIZATION.md) |
| ペアプログラミング導入・パターン選択 | [TEAM-ORGANIZATION.md](./TEAM-ORGANIZATION.md) |
| 開発者習慣の確立・悪習慣の排除 | [DEVELOPER-HABITS.md](./DEVELOPER-HABITS.md) |
| IC効果性マインドセット・アウトカム思考 | [EFFECTIVENESS-MINDSET.md](./EFFECTIVENESS-MINDSET.md) |
| キャリア成長・昇進・IC vs Management パス | [CAREER-GROWTH.md](./CAREER-GROWTH.md) |
| PM/デザイナー協働・権限なきリーダーシップ | [INFLUENCE-LEADERSHIP.md](./INFLUENCE-LEADERSHIP.md) |
| 個人・チームのアンチパターン検出・対処 | [ANTI-PATTERNS.md](./ANTI-PATTERNS.md) |
| バーンアウト防止・リモートワーク・エネルギー管理 | [SUSTAINABLE-PERFORMANCE.md](./SUSTAINABLE-PERFORMANCE.md) |
| AI日常統合ワークフロー・チームAI採用計画 | [AI-ENHANCED-WORKFLOW.md](./AI-ENHANCED-WORKFLOW.md) |

---

## 他スキルとの差別化

| スキル | 扱う内容 |
|--------|---------|
| **本スキル** | プロジェクト基盤・チーム組織・ペアプロ・開発者習慣・IC効果性・キャリア・影響力・アンチパターン・持続可能性・AI活用 |
| `testing-code` | TDD/BDD/ATDD の具体的手法・テスト設計 |
| `writing-clean-code` | SOLID原則・コードスメル・リファクタリング手法 |
| `practicing-devops` | Deployment Pipeline設定・CI/CD具体構成 |
| `applying-clean-architecture` | DDD・Clean Architecture・マイクロサービス |
| `developing-with-ai` | AIコーディングツール活用・プロンプトエンジニアリング・LLM対話設計 |

---

## クイックスタート

### 新規プロジェクト開始

```
1. ビジョン作成 → Fast Feedback ループ確立 → Walking Skeleton 構築
2. Deployment Pipeline（最小版）を最初のフィーチャーと同時に構築
3. DORA メトリクス（Throughput / Stability）計測開始
4. チーム構造を確定
```

### チーム組織設計

```
1. Stream-Aligned Team を中心に設計（大多数のチームがこれ）
2. Platform Team は Stream-Aligned Team の自律性を高める目的のみ
3. Enabling Team は専門知識の一時的な貸し出し役
4. チームサイズ: 5〜9人を目標
```

---

## AskUserQuestion: チーム構造選択

チーム構造を設計する際は以下を確認すること:

**機能横断チーム vs コンポーネントチーム** — どちらが適しているかはプロジェクト規模と依存構造による:

- 小〜中規模プロジェクト → 全員が全体を担う機能横断チーム
- 大規模・複雑なシステム → Stream-Aligned + Platform + Enabling の3層構成

## AskUserQuestion: ペアプログラミングパターン選択

用途に応じてパターンを使い分けること:

- 通常の開発 → Driver & Navigator（デフォルト）
- TDD実践時 → Ping Pong
- ナレッジ移転・オンボーディング → Strong-Style
- ❌ Parent-Child は避けるべきアンチパターン

---

## 概要

### プロジェクト基盤（FOUNDATIONS.md）

- **Fast Feedback**: ビルド・テスト・デプロイ・プロダクションからの高速フィードバック
- **学習最適化**: レトロスペクティブ・実験的アプローチ・エビデンス基盤の意思決定
- **小さなステップ**: Walking Skeleton から始め、インクリメンタルに拡大
- **目標設定**: TIME か SCOPE を固定（両方同時は禁止）
- **計測**: DORA メトリクス（Throughput / Stability）を最初期から導入

### チーム組織（TEAM-ORGANIZATION.md）

- **チームサイズ**: 5〜9人。認知負荷と通信複雑性を最小化
- **チームトポロジー**: Stream-Aligned / Enabling / Complex Subsystem / Platform
- **Platform Team の原則**: Stream-Aligned Team の自律性向上が目的
- **ペアプログラミング**: 4つのパターン + Pair Rotation + 成功のコツ

### 開発者習慣（DEVELOPER-HABITS.md）

- **GREAT Habits**: Code as Communication / エンジニア思考 / 設計としてのコーディング / 品質優先 / チームワーク / 小さなステップ
- **よくある落とし穴**: Happy Path 思考 / コードオーナーシップ / 責任回避 / 変更恐怖 / ツール崇拝 / 神話への執着

### IC効果性マインドセット（EFFECTIVENESS-MINDSET.md）

- **アウトカム思考**: アウトプット（コード・機能）ではなくアウトカム（ユーザー行動変化・ビジネス指標）で仕事を評価する判断フレームワーク
- **生産性 vs 効果性**: 4つの作業領域（機能開発・バグ修正・技術的負債・コラボレーション）での判断軸の違い
- **高レバレッジ行動**: 複利効果をもたらす行動（ドキュメント・メンタリング・プロセス改善）の特定と優先

### キャリア成長とレベルアップ（CAREER-GROWTH.md）

- **キャリアステージ別スキルマトリクス**: Junior（L3）→ Staff（L6+）の各段階で求められるスコープ・自律性・技術的意思決定・リーダーシップの変化
- **IC vs Engineering Management パス**: Technical Track（Staff/Principal/Distinguished Engineer）vs Management Track の適性・評価・転換ポイント
- **昇進戦略**: スポンサーシップ獲得・可視性向上・影響範囲の拡大を具体的に計画する方法

### 影響力・ICリーダーシップ（INFLUENCE-LEADERSHIP.md）

- **PM/デザイナーとの協働チェックリスト**: 要件理解→技術インサイト提供→関係構築の3フェーズで機能横断チームを動かす方法
- **権限なきリーダーシップ**: 影響力の構成要素（信頼×コミュニケーション×証拠）と具体的な実践手法
- **技術意思決定の影響力**: RFC・ADR・技術ロードマップを使った組織横断での意思決定への参画方法

### アンチパターン集（ANTI-PATTERNS.md）

- **個人レベル（IC）15パターン**: Knowledge Silos・Hero Complex・Over-Engineering・Analysis Paralysis・Perfectionism 等の検出シグナルと対処法
- **チームレベル5パターン**: Rubber Stamping・Low Bus Factor・形骸化レトロ等、チームの効果性を阻む構造的問題
- **早期検出アプローチ**: 各アンチパターンの兆候を素早く発見し、チームに影響が広がる前に介入する判断基準

### 持続可能なパフォーマンス（SUSTAINABLE-PERFORMANCE.md）

- **バーンアウト認識と回復**: 6カテゴリの診断シグナル表・回復フロー（休暇→マネージャー対話→専門サポート）
- **エネルギー管理5実践**: Pomodoro サイクル・マイクロ休憩・罪悪感なきバケーション・身体的健康・コーディング以外の趣味
- **リモートワーク実践**: 非同期コミュニケーションリズム・孤独感対策・仕事と生活の境界設定

### AI活用ワークフロー（AI-ENHANCED-WORKFLOW.md）

- **AIの得意/苦手タスク**: ボイラープレート生成・テスト初稿・マイグレーション等のAI向けタスクと、アーキテクチャ判断・セキュリティ実装等の人間主導タスクの分類
- **1日のAI統合ワークフロー**: 計画/設計（ADR ブレインストーミング）・実装（コンテキスト管理）・レビュー・メンタリングまで、フェーズ別AI活用プロンプトパターン
- **90日チームAI採用ロールアウト**: Month 1（個人実験）→ Month 2（共有と標準化）→ Month 3（プロセス組み込み）の段階的チーム展開計画
