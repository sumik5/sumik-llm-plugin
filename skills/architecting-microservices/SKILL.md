---
name: architecting-microservices
description: >-
  Microservices architectural patterns covering CQRS, Event Sourcing, 8 Saga pattern variants, distributed transactions, service granularity decisions, data ownership, workflow orchestration, and contract design.
  Use when designing microservices architecture, choosing transaction strategies, or deciding service granularity.
  Covers messaging, resilience, security, reuse, and data access patterns.
  For migration strategy and trade-off analysis methodology, use modernizing-architecture instead.
  For DDD domain modeling, use applying-domain-driven-design instead.
  For frontend decomposition patterns (micro-frontends), use architecting-micro-frontends instead.
  For green/sustainable microservices trade-offs and carbon-efficient architecture, use building-green-software instead.
---

# Architecting Microservices

マイクロサービスアーキテクチャの実装パターン全般を網羅するスキル。CQRS、Event Sourcing、Saga、分散トランザクション、メッセージング、レジリエンス、セキュリティのパターンを扱います。

## 📋 目次

- [全体像](#全体像)
- [パターン選択判断基準](#パターン選択判断基準)
- [モノリスからマイクロサービスへの移行判断](#モノリスからマイクロサービスへの移行判断)
- [サービス粒度の決定](#サービス粒度の決定)
- [CAP定理の実践的解釈](#CAP定理の実践的解釈)
- [AskUserQuestion使用指示](#askuserquestion使用指示)
- [サブファイルナビゲーション](#サブファイルナビゲーション)

---

## 全体像

### マイクロサービスアーキテクチャの核心的課題

| 課題領域 | 主要パターン | トレードオフ |
|---------|------------|------------|
| **データ一貫性** | CQRS, Event Sourcing, Saga, BASE | 強整合性 vs 結果整合性 |
| **トランザクション** | XA/2PC, Saga (Orchestration/Choreography) | 信頼性 vs 疎結合 |
| **通信方式** | 同期REST, 非同期メッセージング, gRPC | レイテンシ vs レジリエンス |
| **耐障害性** | Circuit Breaker, Retry, Bulkhead, Fallback | 可用性 vs 複雑性 |
| **スケーラビリティ** | Read/Write分離, シャーディング, レプリケーション | 性能 vs 運用コスト |

### マイクロサービスの本質的なトレードオフ

マイクロサービスは**パーティション(分割)**を導入します。パーティション数が増えるほど、一貫性(Consistency)の保証は難しくなります。

```
モノリス: 1プロセス、1データベース → ローカルトランザクション → 強整合性
  ↓
マイクロサービス: Nプロセス、Nデータベース → 分散調整 → 結果整合性
```

---

## パターン選択判断基準

### トランザクションパターン比較

| パターン | 適用場面 | メリット | デメリット | 複雑性 |
|---------|---------|---------|----------|-------|
| **ローカルトランザクション** | 単一サービス内の操作 | 高速、シンプル、ACID保証 | スコープが限定的 | ⭐ |
| **グローバルXA/2PC** | 金融取引など高信頼性が必須 | ACID保証、強整合性 | 遅い、リソース占有、可用性低下 | ⭐⭐⭐⭐ |
| **Saga (Orchestration)** | ビジネスプロセスが複雑 | 中央制御、可視性高 | SPOF、補償トランザクション必要 | ⭐⭐⭐ |
| **Saga (Choreography)** | サービス間が疎結合 | 疎結合、拡張性高 | デバッグ困難、分散追跡必要 | ⭐⭐⭐⭐ |
| **BASE** | 最終的な一貫性で許容 | 高可用性、スケーラブル | 一時的な不整合 | ⭐⭐ |

### CQRS適用判断

| 判断軸 | CQRS採用 | CQRS不採用 |
|-------|---------|----------|
| **Look-to-Book比率** | 読み取り >> 書き込み (10:1以上) | ほぼ同等 |
| **読み取り要求** | 複数の異なるビュー必要 | 単一ビューで十分 |
| **スケーリング** | 読み書き独立スケール必須 | 一律スケールで可 |
| **パフォーマンス** | 読み取りレスポンス最優先 | バランス型 |
| **複雑性許容度** | 高 (結果整合性受容) | 低 (シンプルさ優先) |

### メッセージング vs 同期通信

| 判断軸 | 非同期メッセージング | 同期REST/gRPC |
|-------|------------------|-------------|
| **即時レスポンス** | 不要 | 必須 |
| **サービス可用性** | 一時的なダウン許容 | 常時稼働前提 |
| **スループット** | 高 | 中〜高 |
| **デバッグ容易性** | 低 | 高 |
| **トランザクション境界** | あいまい | 明確 |

---

## モノリスからマイクロサービスへの移行判断

### 移行の前提条件チェックリスト

| 項目 | 必須条件 | 確認ポイント |
|-----|---------|------------|
| **組織の準備** | DevOpsチーム体制 | 各サービスを独立してデプロイ可能か？ |
| **技術スキル** | 分散システムの知見 | CAP定理、結果整合性を理解しているか？ |
| **ツール整備** | 監視・ログ集約基盤 | 分散トレーシング、メトリクス収集は可能か？ |
| **ビジネス価値** | スケーラビリティが収益に直結 | 現在のモノリスがボトルネックか？ |
| **テスト戦略** | E2Eテスト自動化 | マイクロサービス間のテストをどう担保するか？ |

### 移行判断テーブル

| 状況 | 推奨アプローチ | 理由 |
|-----|-------------|------|
| スタートアップ初期 | ❌ マイクロサービス | 過剰エンジニアリング、人的リソース不足 |
| モジュラーモノリス | ⚠️ 段階的移行 | 境界が明確なら部分的に分離 |
| 巨大モノリス (100万行超) | ✅ マイクロサービス | スケーラビリティ・デプロイ頻度向上 |
| 高トラフィック (QPS 10K超) | ✅ マイクロサービス | 読み書き独立スケール必要 |
| 複雑なビジネスドメイン | ✅ マイクロサービス | ドメイン境界でサービス分割 |

---

## サービス粒度の決定

### グラニュラリティの5段階

| レベル | 粒度 | 例 | 適用場面 | 運用負荷 |
|-------|-----|---|---------|---------|
| **1. Function** | 関数レベル | AWS Lambda単一関数 | イベント駆動の単純処理 | ⭐⭐⭐⭐⭐ |
| **2. Feature** | 機能単位 | ユーザー登録API | 単一機能の独立デプロイ | ⭐⭐⭐⭐ |
| **3. Domain** | ドメイン境界 | 注文管理サービス | DDD境界付けられたコンテキスト | ⭐⭐⭐ |
| **4. Capability** | ビジネス能力 | 決済処理プラットフォーム | 複数ドメインを統合 | ⭐⭐ |
| **5. Application** | アプリケーション全体 | ECサイト全体 | モノリス | ⭐ |

### 推奨サービス粒度

**最適解: Domain (ドメイン境界)**

- DDD (Domain-Driven Design) の境界付けられたコンテキストに対応
- チームが自律的に開発・デプロイ可能
- ビジネス変更がサービス境界を超えにくい

**Function粒度の落とし穴:**

- サービス数が爆発的に増加 (例: 100個以上)
- 分散トレーシング・ロギングが複雑化
- コールドスタート問題 (FaaS利用時)

**Capability粒度の落とし穴:**

- サービスが大きすぎてモノリス化
- チーム間の調整コストが増大

---

## CAP定理の実践的解釈

### CAP定理の3要素

| 要素 | 意味 | 実装例 |
|-----|-----|-------|
| **C (Consistency)** | すべてのノードで同じデータを見る | 強整合性トランザクション (XA) |
| **A (Availability)** | すべてのリクエストが応答を返す | レプリカからの読み取り許可 |
| **P (Partition Tolerance)** | ネットワーク分断に耐える | 必須 (分散システムでは避けられない) |

### マイクロサービスにおけるCAP選択

**現実の選択: AP (可用性 + パーティション耐性) → 結果整合性**

| シナリオ | 選択 | パターン | 例 |
|---------|-----|---------|---|
| **金融取引** | CP (一貫性優先) | XA/2PC | 送金、決済 |
| **在庫管理** | CP → APに緩和 | Saga + 補償 | 在庫引当 → 非同期補正 |
| **SNS投稿** | AP (可用性優先) | 結果整合性 | いいね数のカウント |
| **ユーザープロフィール** | AP | CQRS + Event Sourcing | プロフィール更新 → 非同期反映 |

### パーティションと一貫性のトレードオフ

```
パーティション数 ↑  →  ネットワーク境界 ↑  →  調整コスト ↑  →  一貫性保証 ↓
```

**最適化戦略:**

1. **グローバルトランザクション → ローカルトランザクション最適化**
   - メッセージキューの永続化バックエンドとサービスDBを同一リソースに配置
   - 2PCの範囲を最小化

2. **読み書き分離 (CQRS)**
   - 書き込み: 1インスタンス (一貫性優先)
   - 読み取り: Nインスタンス (可用性・性能優先)

---

## AskUserQuestion使用指示

以下の状況では、必ず**AskUserQuestionツール**でユーザーに確認してください。

### 1. トランザクション戦略の選択

```python
AskUserQuestion(
    questions=[{
        "question": "このユースケースでどのトランザクション戦略を採用しますか？",
        "header": "トランザクション戦略",
        "options": [
            {
                "label": "XA/2フェーズコミット",
                "description": "ACID保証必須、金融取引など (高コスト、低スループット)"
            },
            {
                "label": "Saga (Orchestration)",
                "description": "中央制御、ビジネスプロセス可視化 (SPOF注意)"
            },
            {
                "label": "Saga (Choreography)",
                "description": "疎結合、イベント駆動 (デバッグ困難)"
            },
            {
                "label": "BASE/結果整合性",
                "description": "高可用性、最終的な一貫性で許容 (一時的不整合あり)"
            }
        ],
        "multiSelect": False
    }]
)
```

### 2. CQRS採用の判断

```python
AskUserQuestion(
    questions=[{
        "question": "このサービスでCQRSパターンを採用しますか？",
        "header": "CQRS判断",
        "options": [
            {
                "label": "CQRS採用",
                "description": "読み書き比率10:1以上、複数ビュー必要、読取性能最優先"
            },
            {
                "label": "シンプルCRUD",
                "description": "読み書き比率均等、単一ビュー、シンプルさ優先"
            },
            {
                "label": "段階的CQRS",
                "description": "まずCRUD、後で読み取りビューのみ分離"
            }
        ],
        "multiSelect": False
    }]
)
```

### 3. サービス粒度の決定

```python
AskUserQuestion(
    questions=[{
        "question": "サービス分割の粒度をどのレベルにしますか？",
        "header": "サービス粒度",
        "options": [
            {
                "label": "Domain (推奨)",
                "description": "DDD境界付けられたコンテキスト、チーム自律性高"
            },
            {
                "label": "Feature",
                "description": "機能単位、高頻度デプロイ、運用負荷大"
            },
            {
                "label": "Capability",
                "description": "ビジネス能力単位、複数ドメイン統合、大規模チーム"
            }
        ],
        "multiSelect": False
    }]
)
```

---

## サブファイルナビゲーション

各パターンの詳細は以下のサブファイルを参照してください。

| # | ファイル | 内容 |
|---|---------|------|
| 1 | [GRANULARITY-DECISIONS.md](references/GRANULARITY-DECISIONS.md) | サービス粒度、コンポーネント分解パターン、分解vs統合ドライバー |
| 2 | [DATA-OWNERSHIP.md](references/DATA-OWNERSHIP.md) | データ所有権モデル、再利用パターン、分散データアクセス |
| 3 | [WORKFLOW-CONTRACTS.md](references/WORKFLOW-CONTRACTS.md) | オーケストレーション vs コレオグラフィ、コントラクト設計、スタンプ結合 |
| 4 | [DISTRIBUTED-TRANSACTIONS.md](references/DISTRIBUTED-TRANSACTIONS.md) | XA/2PC、Saga 8パターンマトリクス、BASE、冪等性設計 |
| 5 | [CQRS-EVENT-SOURCING.md](references/CQRS-EVENT-SOURCING.md) | CQRSメタモデル、Event Sourcing、Look-to-Book比率 |
| 6 | [MESSAGING-PATTERNS.md](references/MESSAGING-PATTERNS.md) | 同期vs非同期、メッセージ永続性、Pub/Sub、相関ID |
| 7 | [RESILIENCE-PATTERNS.md](references/RESILIENCE-PATTERNS.md) | Circuit Breaker、Retry、Bulkhead、Fallback |
| 8 | [SERVICE-COMMUNICATION.md](references/SERVICE-COMMUNICATION.md) | Service Discovery、API Gateway、REST vs gRPC |
| 9 | [HIGH-AVAILABILITY.md](references/HIGH-AVAILABILITY.md) | スケーリングテンプレート、Primary/Standby、楽観的ロック |
| 10 | [SECURITY-PATTERNS.md](references/SECURITY-PATTERNS.md) | OAuth 2.0、JWT、API Gateway認証、トークン伝播 |

---

## 実装時の推奨手順

1. **ビジネス要件分析**
   - 読み書き比率、トランザクション要件、可用性要求を明確化
   - 上記判断テーブルでパターン候補を絞る

2. **AskUserQuestionで確認**
   - トランザクション戦略、CQRS採用、サービス粒度を確定

3. **サブファイル参照**
   - 選択したパターンの詳細実装ガイドを確認

4. **プロトタイプ実装**
   - 小規模で実装し、性能・複雑性を評価

5. **段階的展開**
   - 一部サービスから開始、成熟度に応じて展開

---

## 関連スキル

- **modernizing-architecture**: 組織・移行戦略レベルのアーキテクチャモダナイゼーション
- **designing-web-apis**: APIエンドポイント設計、RESTful原則
- **building-multi-tenant-saas**: SaaSマルチテナントアーキテクチャ
- **implementing-opentelemetry**: 分散トレーシング、可観測性

---

**次のステップ**: 上記サブファイルナビゲーションから該当パターンの詳細を参照し、具体的な実装設計に進んでください。
