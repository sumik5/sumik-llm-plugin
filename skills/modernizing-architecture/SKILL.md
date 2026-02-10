---
name: modernizing-architecture
description: >-
  Socio-technical architecture modernization covering strategy, domain design, team organization, and trade-off analysis methodology.
  Use when modernizing legacy systems, redesigning domain boundaries, planning migration strategies, or building custom trade-off analysis frameworks.
  Differs from writing-clean-code (code-level) by focusing on system-level decisions.
  For microservices patterns (Saga, granularity), use architecting-microservices instead.
  For DDD domain modeling, use applying-domain-driven-design instead.
---

# アーキテクチャモダナイゼーション

レガシーシステムを現代的なアーキテクチャに進化させるための包括的ガイド。技術パターンだけでなく、戦略・組織・ドメイン設計・**トレードオフ分析**を含む **Socio-technical** アプローチを提供する。

## 目次

- [核心原則](#核心原則)
- [モダナイゼーション・フレームワーク](#モダナイゼーション・フレームワーク)
- [判断基準テーブル](#判断基準テーブル)
- [ユーザー確認の原則](#ユーザー確認の原則askuserquestion)
- [サブファイル一覧](#サブファイル一覧)

---

## 核心原則

### 1. 「最悪でない」トレードオフを選択する

> アーキテクトが行える最善のデザインとは、**少なくとも最悪でないトレードオフの集合**だ。

すべてのアーキテクチャ決定はトレードオフを伴う。「ベスト」を追い求めるのではなく、競合するすべてのアーキテクチャ特性のバランスを取ることが成功の鍵。詳細は [TRADEOFF-ANALYSIS.md](TRADEOFF-ANALYSIS.md) 参照。

### 2. アーキテクチャは技術以上のもの（Socio-technical）

モダナイゼーションは技術的な変更だけでは不十分。ソフトウェア・組織構造・ビジネス戦略の **三位一体** で最適化する必要がある。

> アーキテクチャの負債は、技術的負債だけでなく、組織構造の不整合やビジネス戦略との乖離からも生まれる。

### 3. Independent Value Streams（独立バリューストリーム）

現代的アーキテクチャの構成要素。ビジネス・ドメイン・組織・技術の関心を接続し、持続可能な高速フローを実現する。

```
ユーザーニーズ発見 → 要件定義 → 設計 → 実装 → テスト → デプロイ → 検証
        └── 1つのチームが全工程を担当（独立性の鍵）──┘
```

### 4. ポートフォリオ駆動の進化的旅路

モダナイゼーションは「ターゲットアーキテクチャを設計し、そこへ向かう」ものではない。**進化的・ポートフォリオ的アプローチ** で、各領域に最適な投資レベルを決定する。

### 5. Conway の法則を活用する

> 組織構造がシステム設計を制約する。

これを抵抗するのではなく、**意図的に活用する**。理想的なアーキテクチャに合わせて組織を設計する（Inverse Conway Maneuver）。

### 6. Nail It Then Scale It

小さなスライスで3-6ヶ月以内に価値を届け、検証してからスケールアップする。大規模なビッグバン・リライトは避ける。

---

## モダナイゼーション・フレームワーク

モダナイゼーションは4つのフェーズで構成される:

```
┌─────────────────────────────────────────────────────┐
│ Phase 1: 基礎・準備                                  │
│   ビジネス目的の明確化、リーダーシップ準備、           │
│   リスニング＆マッピングツアー                        │
│   → FOUNDATIONS.md                                   │
├─────────────────────────────────────────────────────┤
│ Phase 2: 発見・設計                                  │
│   EventStorming、Wardley Mapping、                    │
│   Domain Storytelling、ドメイン境界識別               │
│   → DISCOVERY-TECHNIQUES.md, DOMAIN-DESIGN.md       │
├─────────────────────────────────────────────────────┤
│ Phase 3: 戦略・実行                                  │
│   Core Domain Chart、Team Topologies、               │
│   疎結合設計、Migration Patterns、Platform、Data Mesh │
│   → STRATEGIC-PORTFOLIO.md, TECHNICAL-MODERNIZATION.md│
├─────────────────────────────────────────────────────┤
│ Phase 4: 持続・拡大                                  │
│   AMET、Strategy Deck、Roadmap、Learning             │
│   → EXECUTION-STRATEGY.md                            │
└─────────────────────────────────────────────────────┘
```

---

## 判断基準テーブル

### サブドメインの投資戦略

| サブドメインの種類 | 投資レベル | 技術選択 | チーム構成 |
|-------------------|-----------|---------|-----------|
| **Core**（差別化源泉） | 最高 | 最先端技術・フルカスタム | 最も優秀なメンバー |
| **Supporting**（コア支援） | 中 | 状況に応じた最適選択 | 有能なメンバー |
| **Generic**（汎用機能） | 最低 | SaaS/COTS/OSS活用 | 外部委託も可 |

### モダナイゼーション戦略セレクター

各サブシステムに対し、**行動変更軸**（x軸）と**技術変更軸**（y軸）の2軸で戦略を選択:

| 戦略 | 行動変更 | 技術変更 | 適用場面 |
|------|---------|---------|---------|
| **Sunset** | なし | なし | 廃止予定のシステム |
| **Maintain** | なし | 最小限 | 現状維持で十分な場合 |
| **Legacy Encapsulate** | Expose | 最小限 | API公開で価値を引き出す |
| **Lift and Shift** | なし | インフラのみ | クラウド移行が目的 |
| **Lift and Reshape** | Polish | インフラ+一部 | 低リスクな改善 |
| **Extract and Remodel** | Remodel | 最小限 | ドメインモデルの再設計 |
| **Total Modernization** | Rethink | 全面 | 競争優位の中核システム |

### マイグレーションパターン

| パターン | 概要 | リスク | 適用場面 |
|---------|------|--------|---------|
| **Strangler Fig** | 段階的にレガシーを新システムで置換 | データ同期、ルーティング複雑化 | 最も一般的。段階的移行 |
| **Branch by Abstraction** | 抽象レイヤーを挟んで段階的切替 | 抽象化の複雑さ | モノリス内のモジュール |
| **Parallel Running** | 新旧システムを並行稼働し結果比較 | コスト倍増 | 高リスク・高精度要件 |
| **Bubble Context** | 新しいBounded Contextを既存横に配置 | 統合複雑化 | DDDベースの拡張 |

---

## カップリングの理解

疎結合設計の基盤として、結合の種類を理解する（統合強度の昇順）:

| カップリング種別 | 統合強度 | 説明 |
|----------------|---------|------|
| **Functional** | 最弱 | 別コンポーネントの存在のみ認識 |
| **Model** | 弱 | 公開インターフェース（API）を認識 |
| **Implementation** | 強 | 内部実装の詳細を認識 |
| **Intrusive** | 最強 | 他コンポーネントの全てを認識（最も危険） |

---

## Team Topologies 概要

4つのチームタイプと3つのインタラクションモードでチームを設計:

**チームタイプ:**
| タイプ | 役割 |
|--------|------|
| **Stream-aligned** | ビジネス領域に整合、主要な価値提供 |
| **Platform** | 内部サービスを提供し他チームの生産性を加速 |
| **Enabling** | 他チームの能力向上を支援（AMET等） |
| **Complicated-subsystem** | 専門知識を要する複雑なサブシステムを担当 |

**インタラクションモード:**
| モード | 説明 |
|--------|------|
| **Collaboration** | 密な協働（発見段階、新しい技術導入時） |
| **X-as-a-Service** | サービス提供/消費（安定期） |
| **Facilitating** | 支援・コーチング（Enablingチームが主に使用） |

---

## ユーザー確認の原則（AskUserQuestion）

**判断分岐がある場合、推測で進めず必ずAskUserQuestionツールでユーザーに確認する。**

### 確認すべき場面

- **モダナイゼーション戦略の選択**: 各サブシステムをSunset/Maintain/Rewrite等のどれにするか
- **ドメイン境界の決定**: 境界が曖昧な場合の分割方針
- **チームトポロジーの選択**: チームタイプとインタラクションモードの決定
- **プラットフォーム構築の判断**: IDPを構築すべきタイミングと範囲
- **マイグレーションパターンの選択**: Strangler Fig vs Branch by Abstraction等
- **投資優先度**: Core Domain Chartでのサブドメイン分類

### 確認不要な場面

- Conway の法則の適用（常に考慮すべき）
- 疎結合の追求（設計の基本原則）
- Nail It Then Scale It アプローチ（推奨されるデフォルト）
- Independent Value Stream の目標設定（基本方針）

### AskUserQuestion 実装例

```python
AskUserQuestion(
    questions=[
        {
            "question": "このサブシステムのモダナイゼーション戦略はどれが最適ですか？",
            "header": "戦略選択",
            "options": [
                {"label": "Strangler Fig", "description": "段階的にレガシーを新システムで置換。最もリスクが低い"},
                {"label": "Extract and Remodel", "description": "サブシステムを抽出しドメインモデルを再設計"},
                {"label": "Total Modernization", "description": "技術・機能・ドメインモデルを全面刷新。コスト高だが最大効果"},
                {"label": "Lift and Shift", "description": "インフラのみ移行。最小コスト"}
            ],
            "multiSelect": False
        }
    ]
)
```

---

## サブファイル一覧

| ファイル | 内容 | 対応章 |
|---------|------|--------|
| [TRADEOFF-ANALYSIS.md](TRADEOFF-ANALYSIS.md) | トレードオフ分析方法論、Architecture Quantum、ADR、適応度関数、独自分析の構築 | Ch 1-2, 15 |
| [FOUNDATIONS.md](FOUNDATIONS.md) | ビジネス目的、準備、リスニングツアー | Ch 1-3 |
| [DISCOVERY-TECHNIQUES.md](DISCOVERY-TECHNIQUES.md) | EventStorming、Wardley Mapping、Domain Storytelling | Ch 4-5, 7-8 |
| [DOMAIN-DESIGN.md](DOMAIN-DESIGN.md) | Product Taxonomy、ドメイン識別、境界設計ヒューリスティクス | Ch 6, 9 |
| [STRATEGIC-PORTFOLIO.md](STRATEGIC-PORTFOLIO.md) | Core Domain Chart、Team Topologies、Independent Service Heuristics | Ch 10-11 |
| [TECHNICAL-MODERNIZATION.md](TECHNICAL-MODERNIZATION.md) | 疎結合設計、Migration Patterns、Internal Developer Platform、Data Mesh | Ch 12-14 |
| [EXECUTION-STRATEGY.md](EXECUTION-STRATEGY.md) | AMET、Strategy Deck、Roadmap、Learning & Upskilling | Ch 15-17 |

---

## クイックリファレンス: 主要テクニック一覧

| テクニック | フェーズ | 目的 | 参照先 |
|-----------|---------|------|--------|
| Listening & Mapping Tour | 基礎 | ステークホルダーの課題発見 | FOUNDATIONS.md |
| Wardley Mapping | 基礎 | 戦略的な進化の可視化 | DISCOVERY-TECHNIQUES.md |
| Big Picture EventStorming | 発見 | ドメイン全体のマッピング | DISCOVERY-TECHNIQUES.md |
| Process Modeling EventStorming | 発見 | プロセスの詳細設計 | DISCOVERY-TECHNIQUES.md |
| Domain Storytelling | 発見 | ドメインの物語的理解 | DISCOVERY-TECHNIQUES.md |
| Product Taxonomy | 設計 | アーキテクチャの言語定義 | DOMAIN-DESIGN.md |
| Domain Boundary Heuristics | 設計 | ドメイン境界の発見 | DOMAIN-DESIGN.md |
| Core Domain Chart | 戦略 | ポートフォリオ投資判断 | STRATEGIC-PORTFOLIO.md |
| Modernization Strategy Selector | 実行 | サブシステム別戦略選択 | TECHNICAL-MODERNIZATION.md |
| Domain Message Flow Modeling | 実行 | アーキテクチャフローの設計 | TECHNICAL-MODERNIZATION.md |
| Strategy Deck | 持続 | ナラティブ構築・ステークホルダー説得 | EXECUTION-STRATEGY.md |
