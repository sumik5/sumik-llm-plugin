---
name: transforming-legacy-systems
description: >-
  A hands-on, iterative method for transforming a legacy codebase into a domain-driven,
  modular target architecture. Assess maturity with the Modularity Maturity Index (MMI, 0-10:
  modularity, hierarchy, pattern consistency), then run four strategic steps (domain
  rediscovery, target architecture modeling, actual-vs-target comparison, prioritized
  refactoring). Covers transformation approaches (big-bang vs step-by-step vs reshaping),
  technical stabilization (seams, characterization tests, design by contract), fighting model
  anemia, sociotechnical team reshaping, and a catalog of strategic/tactical/sociotechnical
  refactorings with motivation and mechanics. Use when modernizing a legacy monolith, planning
  incremental migration, or decomposing a big ball of mud into bounded contexts. For
  DDD/clean-architecture layering, use applying-clean-architecture. For portfolio
  modernization and migration patterns, use cloud:architecting-infrastructure. For code-level
  refactoring, use writing-clean-code.
---

# レガシーシステムの変革

既存のレガシーコードベースを、定量的な成熟度評価（MMI: Modularity Maturity Index）を起点に、ドメイン駆動の反復的リファクタリングでモジュラーな目標アーキテクチャへ変革するための実践手法。「あるべき設計を描く」`applying-clean-architecture` の兄弟スキルであり、本スキルは「そこへ至るプロセス」——現状評価・優先順位付け・段階的な作り替え——を担当する。新規設計の指南ではなく、動いている既存システムを止めずに作り替えるための判断材料を提供する。

このスキルは概念そのものの再教育をしない。判断テーブルと参照リンクを軸に構成し、詳細な手順・チェックリスト・コード例は `references/` の各ファイルに委譲する。

---

## 1. 手法の全体像（at a glance）

```
  現状評価                         反復サイクル（戦略変革）
 ┌──────────────┐        ┌───────────────────────────────────────┐
 │ MMIで成熟度を   │  ───▶  │ Step1 ドメイン再発見                     │
 │ 測定 (0〜10)    │        │   ↓                                    │
 └──────────────┘        │ Step2 目標アーキテクチャのモデリング        │
        │                 │   ↓                                    │
        │ 必要なら         │ Step3 現状 ↔ 目標アーキテクチャの突き合わせ │
        ▼                 │   ↓                                    │
 ┌──────────────┐        │ Step4 優先順位付けと実装                  │
 │ 技術変革        │        │   ↓（小さく実装し、常にデプロイ可能を維持） │
 │ 戦術変革        │ ◀──────┴─────────────┬───────────────────────────┘
 │ （下支え）       │                       │ 反復
 └──────────────┘◀──────────────────────┘
```

MMIが低い（構造がない）システムでは、技術変革・戦術変革で足場を固めてから戦略変革（4ステップ）を回す。MMIが高い（既にモジュール化されている）システムでは、最初から4ステップを一巡させて微調整する。技術・戦術・戦略のどの組み合わせを選ぶかは §4「MMI経路セレクター」で判断する。

---

## 2. 変革ヘルパー早見表

変革の各局面で使う代表的な道具と、その詳細を扱う参照先。

| ヘルパー | 役割 | 詳細参照 |
|---------|------|---------|
| C4モデル | システムを文脈・コンテナ・コンポーネント・コードの4段階の抽象度で図示し、関係者間の共通理解をつくる | [ARCHITECTURE-CONCEPTS.md](references/ARCHITECTURE-CONCEPTS.md) |
| 協働モデリング（ドメインストーリーテリング／EventStorming／シナリオキャスティング） | 業務プロセスをドメインエキスパートと開発者が共同で可視化し、既存実装を意識せず業務の実態を再発見する | [COLLABORATIVE-MODELING.md](references/COLLABORATIVE-MODELING.md) |
| アーキテクチャレビューツール | ソースコードを読み込み、現状の依存構造を目標構造と重ねて視覚的に比較する | [ARCHITECTURE-CONCEPTS.md](references/ARCHITECTURE-CONCEPTS.md) |
| MMI（Modularity Maturity Index） | モジュール性・階層・パターン一貫性を0〜10で定量評価し、変革経路を選ぶ起点にする | [MODULARITY-MATURITY-INDEX.md](references/MODULARITY-MATURITY-INDEX.md) |
| DDD（戦略的／戦術的設計） | 境界づけられたコンテキストやユビキタス言語など、変革の「道具」としてのDDD概念一式 | `applying-clean-architecture`（本スキルは変革の文脈での使い方のみを扱う） |

---

## 3. MMI経路セレクター（判断テーブル）

システムの現状評価は必ずMMIから始める。MMIはモジュール性・階層構造・パターンの一貫性という3つの観点を重み付けして合成した0〜10のスコアで、算出の考え方は [MODULARITY-MATURITY-INDEX.md](references/MODULARITY-MATURITY-INDEX.md) を参照する。

| MMI | 状態 | 推奨経路 |
|-----|------|---------|
| 0〜4 | Big Ball of Mud（構造がなく、すべてがすべてに依存する） | 技術変革 → 戦術変革 → 戦略変革の順に積み上げる |
| 4〜8 | 技術レイヤード（層構造はあるがドメイン層が未整理） | Path A（戦術先行：ドメイン層自体がBBoMの場合）／Path B（戦略先行：ドメイン層に構造の芽がある場合）。判断に迷う場合はPath Bを既定とする |
| 8〜10 | ドメイン駆動モジュラー（既に目標に近い） | 戦略変革の4ステップを一巡させ、残る依存関係を微調整する |

Path AかPath Bかの選択は現場ごとの事情に左右されるため、AskUserQuestionで確認する（§7参照）。

---

## 4. 変革アプローチ選定（判断テーブル）

システムを置き換えるか改造するかという大きな方針は、着手前に決めておく。

| アプローチ | 概要 | 特徴 |
|-----------|------|------|
| ビッグバン置換 | 新システムを完成させてから一斉に切り替える | 未知の未知が蓄積しやすく、フィードバックが遅い。原則として推奨しない |
| 段階的置換（Strangler Fig型） | 旧システムの機能を少しずつ新システムに置き換えていく | 既定の選択肢。低リスクで早期にフィードバックを得られる |
| リシェイピング | 旧システムを稼働させたままリファクタリングで作り変える | 蓄積したノウハウを温存でき、抜本的な作り直しをしない |

未知の未知・停滞と動く標的・二重作業・ノウハウ喪失・遅いデプロイ・ユーザー不満という6つの評価軸による詳細比較は [TRANSFORMATION-APPROACHES.md](references/TRANSFORMATION-APPROACHES.md) を参照する。既定は「段階的置換またはリシェイピング」であり、ビッグバン置換を安易に選ばない。

---

## 5. 4ステップ手法の要約

MMIによる下支えが済んだら（あるいは最初から）、次の4ステップを反復する。

| Step | 目的 | 詳細参照 |
|------|------|---------|
| 1. ドメイン再発見 | 既存実装を離れ、業務プロセスを協働モデリングで再発見し、サブドメインの境界を見つける | [STRATEGIC-STEPS-DISCOVERY-MODELING.md](references/STRATEGIC-STEPS-DISCOVERY-MODELING.md) |
| 2. 目標アーキテクチャのモデリング | 発見したサブドメインを分類し、境界づけられたコンテキストとチーム割当を含む目標のコンテキストマップを作る | [STRATEGIC-STEPS-DISCOVERY-MODELING.md](references/STRATEGIC-STEPS-DISCOVERY-MODELING.md) |
| 3. 現状と目標の突き合わせ | 現状アーキテクチャを分析し、目標との差分（発見事項・リファクタリング項目）を洗い出す | [STRATEGIC-STEPS-ALIGNMENT-EXECUTION.md](references/STRATEGIC-STEPS-ALIGNMENT-EXECUTION.md) |
| 4. 優先順位付けと実装 | 支援サブドメインなどリスクの低い箇所から着手し、小さくリファクタリングして常にデプロイ可能な状態を保つ | [STRATEGIC-STEPS-ALIGNMENT-EXECUTION.md](references/STRATEGIC-STEPS-ALIGNMENT-EXECUTION.md) |

技術変革（安定化）と戦術変革（ドメイン知識による強化）の具体的な手順は [TECHNICAL-STABILIZATION.md](references/TECHNICAL-STABILIZATION.md) と [DOMAIN-KNOWLEDGE-IN-CODE.md](references/DOMAIN-KNOWLEDGE-IN-CODE.md) を、実際のリファクタリング手順は [REFACTORING-CATALOG.md](references/REFACTORING-CATALOG.md) のカタログを参照する。チーム編成の見直しは [TEAM-ORGANIZATION.md](references/TEAM-ORGANIZATION.md) を参照する。

一巡で完了することはまれで、反復のたびに新しい発見や優先順位の入れ替えが起こる。1回の反復で完璧を目指さず、小さな安全な一歩を積み重ねることを原則とする。

---

## 6. ドメインの性質から実装パターンを選ぶ

境界づけられたコンテキストの実装が固まってきたら、ドメインの性質（ワークフロー型か・中心的なドメインモデルの有無・成熟度）に応じた実装パターンの引き出しを持っておくと判断が速い。詳細は [DOMAIN-PATTERNS.md](references/DOMAIN-PATTERNS.md) を参照する。

---

## 7. AskUserQuestion 配置箇所

判断分岐は推測で進めず、AskUserQuestionで確認する（非対応環境では通常のテキスト質問として代替提示する）。

### 確認すべき場面（options付きで質問する）

1. **変革アプローチの選択**：ビッグバン置換／段階的置換／リシェイピング（§4）
2. **MMI 4〜8でのPath選択**：Path A（戦術先行）／Path B（戦略先行）（§3）
3. **最初に着手する境界コンテキスト／サブドメインの選択**：支援サブドメインから開始／コアドメインから開始（[STRATEGIC-STEPS-ALIGNMENT-EXECUTION.md](references/STRATEGIC-STEPS-ALIGNMENT-EXECUTION.md)）
4. **境界コンテキストの実現方式**：既存コードからの抽出／ゼロからの実装（言語移行時など）（[REFACTORING-CATALOG.md](references/REFACTORING-CATALOG.md)）
5. **UI分解方針**：モノリシックUIを維持／マイクロフロントエンド化（[STRATEGIC-STEPS-ALIGNMENT-EXECUTION.md](references/STRATEGIC-STEPS-ALIGNMENT-EXECUTION.md)）
6. **チーム再編の形**：機能横断チーム形成の複数パターンから選択（[TEAM-ORGANIZATION.md](references/TEAM-ORGANIZATION.md)、[REFACTORING-CATALOG.md](references/REFACTORING-CATALOG.md)）

### 確認不要（既定として適用する原則）

- ビッグバン置換を安易に選ばない（既定は段階的置換またはリシェイピング）
- MMIで現状評価してから変革経路を決める（順序を逆にしない）
- 小さいステップでリファクタリングし、常にデプロイ可能な状態を保つ
- リファクタリングの前に特性テスト（characterization test）で安全網を張る

### 実装例

```
AskUserQuestion(questions=[{
  "question": "このレガシーシステムの変革アプローチはどれが最適ですか？",
  "header": "変革アプローチ",
  "options": [
    {"label": "段階的置換", "description": "旧システムを少しずつ新システムで置換（Strangler Fig型）。既定・低リスク・早期フィードバック"},
    {"label": "リシェイピング", "description": "旧システムを稼働させたままリファクタリングで改造。ノウハウ温存。抜本的な作り直しはしない"},
    {"label": "ビッグバン置換", "description": "新システムを完成させ一斉切替。未知の未知・遅いフィードバックのリスク大。原則非推奨"}
  ],
  "multiSelect": false
}])
```

---

## 8. 相互参照マップ

本スキルは変革プロセスとMMI・リファクタリングカタログに集中し、次の話題は既存スキルへ委譲する。重複記述はしない。

| 話題 | 委譲先 |
|------|--------|
| DDD概念の定義（Bounded Context・Ubiquitous Language・Aggregate・Value Object等） | `applying-clean-architecture` |
| 戦略／ポートフォリオ視点のモダナイゼーション、マイグレーションパターン、クラウド／インフラ | `cloud:architecting-infrastructure` |
| コードレベルの一般的なリファクタリング・SOLID原則 | `writing-clean-code` |
| テスト戦略・特性テストの実装 | `testing-code` |

逆に、本スキル固有の価値は「MMIによる定量評価」「4ステップの反復的な変革プロセス」「技術・戦術・社会技術のリファクタリングカタログ」「貧血ドメインモデルの解消」「変革アプローチの選定（ビッグバン／段階的／リシェイピング）」に集中する。

---

## 9. サブファイル索引（references/）

| # | ファイル | 内容 |
|---|---------|------|
| 1 | [MASTERING-COMPLEXITY.md](references/MASTERING-COMPLEXITY.md) | 複雑性の起源（問題空間／解決空間）、本質的複雑性と偶発的複雑性の区別、レガシーシステムにおける複雑性の増大要因 |
| 2 | [MODULARITY-MATURITY-INDEX.md](references/MODULARITY-MATURITY-INDEX.md) | MMIの3次元（モジュール性／階層／パターン一貫性）と評価観点、0〜10採点の考え方、算出手順の概要、経路選択、アーキテクチャレビューの運用 |
| 3 | [ARCHITECTURE-CONCEPTS.md](references/ARCHITECTURE-CONCEPTS.md) | C4モデル、モジュール性、凝集と結合、Big Ball of Mud、代表的なアーキテクチャスタイルの比較 |
| 4 | [COLLABORATIVE-MODELING.md](references/COLLABORATIVE-MODELING.md) | ドメインストーリーテリング、EventStorming、シナリオキャスティング、手法選択の基準、リモート／AI活用 |
| 5 | [TRANSFORMATION-APPROACHES.md](references/TRANSFORMATION-APPROACHES.md) | 置換（ビッグバン）／置換（段階的）／リシェイピングの3アプローチと6評価軸による比較、選定指針 |
| 6 | [TECHNICAL-STABILIZATION.md](references/TECHNICAL-STABILIZATION.md) | 技術変革：ビルド／デプロイ自動化、依存更新、テスト増強、Seam、エラー堅牢性、自己評価チェックリスト |
| 7 | [DOMAIN-KNOWLEDGE-IN-CODE.md](references/DOMAIN-KNOWLEDGE-IN-CODE.md) | 戦術変革：業務コードと技術コードの分離、貧血ドメインモデルの解消、値オブジェクト、結合削減、自己評価チェックリスト |
| 8 | [TEAM-ORGANIZATION.md](references/TEAM-ORGANIZATION.md) | 社会技術システムとしてのチーム編成、水平／垂直分割、チームトポロジーの基礎、変革期のチーム進化 |
| 9 | [STRATEGIC-STEPS-DISCOVERY-MODELING.md](references/STRATEGIC-STEPS-DISCOVERY-MODELING.md) | Step1 ドメイン再発見とStep2 目標アーキテクチャのモデリングの手順・ツール・成果物 |
| 10 | [STRATEGIC-STEPS-ALIGNMENT-EXECUTION.md](references/STRATEGIC-STEPS-ALIGNMENT-EXECUTION.md) | Step3 現状と目標の突き合わせとStep4 優先順位付けと実装の手順・ツール・成果物 |
| 11 | [REFACTORING-CATALOG.md](references/REFACTORING-CATALOG.md) | 戦略的／戦術的／社会技術的リファクタリングのカタログ（Motivation／Mechanics形式） |
| 12 | [DOMAIN-PATTERNS.md](references/DOMAIN-PATTERNS.md) | ワークフロー型・ドメインモデルの多様性・ドメインの成熟度から実装パターンを選ぶ指針 |
