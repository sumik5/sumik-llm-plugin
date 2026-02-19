# ソフトウェア開発ライフサイクルと方法論

Pythonプロジェクトにおける開発ライフサイクル管理と方法論選択の実践ガイド。

---

## SDLCの全体像

**Software Development Life Cycle (SDLC)** は、ソフトウェア開発に伴う一連の活動を体系化したフレームワーク。正式なプロセスがなくても、これらの活動は実質的に発生している。

| フェーズ | 区分 | 主な目的 |
|---------|------|---------|
| Phase 1: Initial concept/vision | 事前開発 | ニーズの概念化・初期ビジョン |
| Phase 2: Concept development | 事前開発 | 概念の具体化・ビジネスプロセス定義 |
| Phase 3: Project management planning | 事前開発 | プロジェクト計画・リソース配分 |
| Phase 4: Requirements analysis and definition | 開発 | 要件の詳細定義 |
| Phase 5: System architecture and design | 開発 | アーキテクチャ・設計 |
| Phase 6: Development and quality assurance | 開発 | コード実装・品質保証 |
| Phase 7: System integration, testing, and acceptance | 開発 | 統合・テスト・受け入れ |
| Phase 8: Implementation/installation/distribution | 事後開発 | デプロイ・配布 |
| Phase 9: Operations, use, and maintenance | 事後開発 | 運用・保守・機能追加 |
| Phase 10: Decommissioning | 事後開発 | システム廃止・データ移行 |

---

## 事前開発フェーズ（Phase 1-3）

コード1行も書く前に完了させる。エンジニアが注目すべき成果物はユーザー・機能・リスクの把握。

### Phase 1: Initial concept/vision

| 要素 | 内容 |
|-----|------|
| 目的 | 未充足ニーズの認識・システムの初期ビジョン策定 |
| 発案者 | ビジネス担当、開発者、システム管理者など |
| 成果物 | 期待される機能・メリットの一覧、ユーザーニーズ、リスク、実現可能性の懸念点 |

**エンジニアが確認すべき項目:**
- 既存パッケージで代替できない機能は何か
- ビジョンの根拠となる具体的なペインポイント

### Phase 2: Concept development

| 要素 | 内容 |
|-----|------|
| 目的 | Phase 1のビジョンを具体化し、後続フェーズへの方向性を提供 |
| 主な活動 | システムモデリング、ビジネスオブジェクト定義、ユーザーインタラクション設計 |
| 質問例 | 「何を追跡するか」「ユーザーはどこから・どのように使うか」 |

**実践例（配達車両燃費管理システム）:**
```
「各車両の給油時に走行距離と燃料量を記録し、燃費が90%を下回ったら通知する」
→ Web/モバイルアプリ + バックエンドAPIの構成を示唆
```

### Phase 3: Project management planning

| ドキュメント要素 | エンジニアへの関連性 |
|----------------|-------------------|
| Business purpose / Objectives | 要件分析の出発点 |
| What's included / excluded | 開発スコープの境界 |
| Key assumptions | 設計上の制約や前提 |
| Risks, issues, dependencies | 実装時の注意点 |
| Roles and responsibilities | 不明点の問い合わせ先 |
| Change management | 変更プロセスの期待値 |

**事前開発フェーズ完了時のチェックリスト:**
- [ ] システムのユーザー（アクター）が特定されている
- [ ] 各ユーザーが行う必要があることが明確
- [ ] ユーザーのインタラクション方法（場所・デバイス）が定義されている

---

## 開発フェーズ（Phase 4-7）

Agile採用により各フェーズの順序・形態は変化するが、すべての活動は必ず発生する。

### Phase 4: Requirements analysis and definition

「何をするシステムか」を具体化するフェーズ。ユーザーストーリー形式が一般的。

**ユーザーストーリーの基本形:**
```
As a <ユーザータイプ>,
I need to <実施したいアクション>,
so that <達成したい目的>.
```

**例:**
```
As a fleet driver,
I need to log my vehicle's odometer reading and fuel amount when refueling,
so I don't have to keep paper receipts.
```

**エンジニアへの要件品質基準:**

| 基準 | チェック |
|-----|---------|
| コードを書けるレベルの具体性 | ✅ |
| テストで確認できる検証可能な条件 | ✅ |
| 実装範囲の明確な境界 | ✅ |

### Phase 5: System architecture and design

「どのようにシステムを構築するか」を定義するフェーズ。

| 確認項目 | 理由 |
|---------|------|
| 実行環境の制約（クラウド vs オンプレ） | アーキテクチャを根本から左右する |
| 既存コードとのインタフェース | 統合設計に必要 |
| 変更可能な範囲 | リファクタリングの境界を決定 |

設計はAgile開発ではイテレーションとともに進化するが、**最低限の設計方向性**（関数ベース vs OOPなど）は早期に決定すること。

### Phase 6: Development and quality assurance

コードを実際に書くフェーズ。CI（Continuous Integration）の有無で品質保証活動の形態が変わる。

| CI採用 | QA活動 |
|--------|-------|
| あり | 自動テストスイート必須、回帰テスト自動化 |
| なし | 手動テスト計画を別途実施 |

### Phase 7: System integration, testing, and acceptance

新しいコードを既存システムに組み込む際のテスト。

| テスト種別 | 目的 |
|----------|------|
| 統合テスト | 新コードが既存機能を破壊しないことを確認 |
| 回帰テスト | 既存機能の継続動作を確認 |
| End-to-Endテスト | システム全体の動作を確認 |
| UAT（User Acceptance Testing） | UIを通じたユーザー受け入れ確認 |

**開発フェーズ完了時のチェックリスト:**
- [ ] 要件が実装されている
- [ ] QA活動（テスト）が完了している
- [ ] 統合テストと受け入れが完了している

---

## 事後開発フェーズ（Phase 8-10）

コア開発完了後のフェーズ。バグ修正・機能追加で再び開発フェーズに戻ることが多い。

### Phase 8: Implementation/installation/distribution

パッケージング・インストール・デプロイプロセスの確立。

```
手動デプロイ → 部分自動化 → 完全CI/CD自動化
```

**エンジニアへの影響:** デプロイスクリプト・パッケージ構成をUAT開始前から設計しておく。

### Phase 9: Operations, use, and maintenance

開発チームはシステム管理者・エンドユーザーへの**知識提供者**としての役割を担う。

| 活動 | エンジニアの貢献 |
|------|----------------|
| 日常運用 | 運用ドキュメント、管理ツール |
| 機能追加 | 開発フェーズへの再エントリ |
| バグ修正 | トリアージ・修正・テスト |

### Phase 10: Decommissioning

システム廃止時の要件は**通常運用時のデータ削除設計**に影響する。

| 要件 | 実装への影響 |
|-----|------------|
| データの保存・アーカイブポリシー | ソフトデリート設計 |
| センシティブデータの破棄 | 削除APIの設計 |
| ユーザー通知 | 通知基盤の構築 |

**事後開発フェーズでエンジニアが注目すべき点:**
- コードがどのようにエンドユーザーに届くか（デプロイ方式）
- バグ報告・トリアージ・対応のプロセス
- 廃止を見据えたデータ移行・削除の設計

---

## プロセス方法論

### Waterfall

| 要素 | 内容 |
|-----|------|
| 特徴 | 厳格な線形プロセス、各フェーズが完全完了してから次へ |
| フェーズ順序 | Requirements → Design → Implementation → Verification → Maintenance |
| SDLCとの対応 | Requirements = Phase1-3、Design = Phase4-5、Implementation = Phase6、Verification = Phase7、Maintenance = Phase9 |
| 強み | 理解しやすい、各ステップが前ステップの成果物に基づく |
| 弱み | 変更への対応が遅い、途中のミスがプロジェクト全体に影響 |

**適用条件:** 要件が最初から完全に定義可能、変更がほぼない、規制要件が厳格なプロジェクト。

---

### Scrum

Agile方法論の中で最も広く採用されているイテレーション型プロセス。

**ロール:**

| ロール | 責務 |
|-------|-----|
| Product Owner (PO) | ステークホルダーとの窓口、ストーリーの優先度決定、意思決定 |
| Scrum Master (SM) | プロセスのファシリテーター、ブロッカー解消 |
| Development Team | 実装・テスト・完成させる |

**Sprintサイクル:**

```
Sprint計画 → 開発（Daily Stand-up） → Sprint終了デモ → レトロスペクティブ → 次Sprint計画
```

**Scrum セレモニー:**

| セレモニー | 目的 |
|----------|------|
| Sprint Planning | 次Sprintのストーリーを決定 |
| Daily Stand-up | 進捗・ブロッカーを共有（昨日・今日・障害） |
| Backlog Grooming | ストーリーの詳細化・見積もり |
| Sprint Review/Demo | 完成したストーリーのデモと受け入れ |
| Retrospective | 改善点の特定と次Sprintへの反映 |

**ユーザーストーリーのサイジング:**
- 時間見積もりベース **禁止**（複雑さと時間を混同する）
- ストーリーポイントまたはTシャツサイズ（XS/S/M/L/XL）を使用

**Scrumの利点と課題:**

| 利点 | 課題 |
|-----|-----|
| 変化への適応性が高い | Sprint途中の変更はコストが高い |
| 透明性が高い（タスクボード） | チームメンバーの変動に敏感 |
| 自己修正型プロセス | スキルサイロを強化しやすい |
| イテレーション完了毎にデプロイ可能 | 外部依存・規制要件が多い場合は困難 |

---

### Kanban

Lean原則に基づく継続的フロー型のAgile方法論。

**核心原則:** コンテキストスイッチを最小化し、1ストーリーを完了させてから次へ移る。

**WIP（Work In Progress）制限:**

```python
# Kanbanのコア概念
WIP_LIMIT_PERSONAL = 2  # 個人が同時に担当するストーリー数の上限
WIP_LIMIT_TEAM = 5       # チームの同時進行数の上限
# 超過した場合は新規取得せず完了に集中する
```

**ScumとKanbanの比較:**

| 要素 | Scrum | Kanban |
|-----|-------|--------|
| 時間制限 | Sprint（固定期間） | ストーリーレベルで任意 |
| 主な単位 | User Story | Work Item |
| 計画会議 | Sprint Planning必須 | 必要時に実施 |
| Daily Stand-up | 必須 | 推奨だが任意 |
| ストーリー見積もり | 必須 | 任意 |
| 受け入れ | Sprint終了時 | ストーリー完成時 |
| WIP制限 | スプリット内暗黙的 | 明示的な数値制限 |

**Kanbanの利点と課題:**

| 利点 | 課題 |
|-----|-----|
| 知識サイロがある場合でも機能 | ボトルネックが生じやすい |
| 分割困難な大きなストーリーに対応 | マイルストーンの意識的な設定が必要 |
| 継続的なデリバリーが可能 | 設計共有が不足するとすれ違いが発生 |
| 新規ワークを随時追加可能 | 技術的負債が蓄積しやすい傾向 |

**KanbanとSDLC対応:**
- 要件定義・設計: Scrumと同様だが、より非形式的
- 開発・QA・統合: ストーリーのフロー内で完結（Sprint終了デモなし）

---

### 方法論選択ガイド

| 条件 | 推奨方法論 |
|-----|----------|
| 要件が最初から完全に定義済み | Waterfall |
| 要件の変化が頻繁、チームが均質なスキル | Scrum |
| 知識サイロあり、大きなストーリー、継続的デリバリー優先 | Kanban |
| プロジェクト規模: 小〜中 | Kanban |
| プロジェクト規模: 中〜大、チーム安定 | Scrum |
| 規制要件が厳格（医療・金融等） | Waterfall または Scrum（注意深い適応） |
| ステークホルダーの関与が高い | Scrum（PO役割が機能する環境） |
| 外部依存が多い | Kanban（フロー制御しやすい） |

---

## 開発パラダイム比較

Python は3つのパラダイムすべてをサポートする。プロジェクトの性質に応じて選択または組み合わせる。

| パラダイム | 特徴 | Pythonでの代表的な用途 |
|----------|------|----------------------|
| **Procedural** | 上から下への手続き実行、ループと分岐 | 単純なスクリプト、自動化タスク |
| **Object-Oriented (OOP)** | クラス・インスタンス・メソッドで状態と振る舞いを封じ込め | 複雑なアプリケーション、データモデリング |
| **Functional (FP)** | 純粋関数・不変データ・状態共有なし | データ変換パイプライン、並行処理 |

**OOP の特徴:**
- クラスが状態（属性）と振る舞い（メソッド）を保持
- 継承によるコード再利用
- モジュール化により保守性・デバッグ性が向上

**FP の特徴:**
- 純粋関数: 同じ入力には常に同じ出力
- 副作用なし（ファイル書き込み等は境界で行う）
- 不変データ構造によりバグが少なく安定

**Pythonでのパラダイム混在例:**
```python
# 手続き型: 単純なスクリプトのメインフロー
# OOP: ドメインオブジェクト（Vehicle, FuelLog等）
# FP: データ変換パイプライン（フィルタ・集計等）

# 実用的な組み合わせ
from dataclasses import dataclass
from functools import reduce
from typing import Sequence

@dataclass(frozen=True)  # OOP + FP（不変データクラス）
class FuelLog:
    odometer: float
    fuel_amount: float

def calc_efficiency(log: FuelLog, prev_odometer: float) -> float:
    """純粋関数: 燃費計算"""
    distance = log.odometer - prev_odometer
    return distance / log.fuel_amount if log.fuel_amount > 0 else 0.0

def average_efficiency(logs: Sequence[FuelLog]) -> float:
    """FP風: ログ列から平均燃費を計算"""
    if len(logs) < 2:
        return 0.0
    pairs = zip(logs[:-1], logs[1:])
    efficiencies = [calc_efficiency(b, a.odometer) for a, b in pairs]
    return sum(efficiencies) / len(efficiencies)
```

---

## CI/CDの位置づけ

CI/CDはPhase 8（Implementation/distribution）を自動化する事後開発プラクティス。詳細実装は別リファレンス参照。

| 段階 | 内容 |
|-----|------|
| **CI (Continuous Integration)** | コミット→自動テスト→ビルドを繰り返し、統合問題を早期検出 |
| **CD (Continuous Delivery)** | CIの成果物を本番環境にデプロイ可能な状態で保つ |
| **CD (Continuous Deployment)** | CIの成果物を自動的に本番環境にデプロイ |

**CI前提条件:**
- バージョン管理システム（単一メインブランチ）
- 自動ビルドプロセス
- 自動テストスイート（特にユニットテスト必須）

**テスト実行タイミングのトレードオフ:**

| タイミング | メリット | デメリット |
|----------|---------|----------|
| コミット前 | 壊れたコードが混入しない | 他者に手渡せない場合がある |
| コミット後 | いつでも手渡し可能 | ビルドが壊れチーム全体に影響 |
