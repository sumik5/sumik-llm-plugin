# Domain-Driven Design (ドメイン駆動設計)

Domain-Driven Design (DDD) は、複雑なビジネスロジックを持つソフトウェアの設計手法であり、事業戦略とソフトウェア実装を結びつける実践的方法論です。

## 全体構成

DDDは以下の4段階で構成されます：

```
【戦略的設計】
  ↓ 事業分析とモデル境界の定義
【戦術的パターン】
  ↓ 実装方法の選択
【実践の経験則】
  ↓ テストと進化的設計
【他技法との統合】
```

### 1. 戦略的設計（Strategic Design）
事業領域（Business Domain）を分析し、適切なモデル境界（Bounded Context）を定義します。
→ 詳細は [STRATEGIC-DESIGN.md](./references/./STRATEGIC-DESIGN.md) 参照

### 2. 戦術的パターン（Tactical Patterns）
業務ロジックの複雑さに応じた実装方法を選択します。
→ 詳細は [TACTICAL-PATTERNS.md](./references/./TACTICAL-PATTERNS.md) 参照

### 3. 実践の経験則（Practice and Heuristics）
設計判断、テスト方針、イベントストーミングなどの実践技法。
→ 詳細は [PRACTICE.md](./references/./PRACTICE.md) 参照

### 4. 業務データの分解（Data Decomposition）
モノリシックなデータベースを境界づけられたコンテキストに基づいて分解する手法。データ分解の推進要因、5段階プロセス、ポリグロットデータベース選択基準を含む。
→ 詳細は [DATA-DECOMPOSITION.md](./references/./DATA-DECOMPOSITION.md) 参照

### 5. 他技法との関係（Integration）
Microservices、Event-Driven Architecture、Data Meshとの統合。
→ 詳細は [INTEGRATION.md](./references/./INTEGRATION.md) 参照

---

## Quick Start: DDDの全体像

### DDD適用の4ステップ

```
1. 事業領域の分析
   └─ Subdomain分類（Core / Generic / Supporting）

2. Bounded Contextの定義
   └─ モデルの適用範囲と境界を明確化

3. 実装パターンの選択
   └─ 複雑さに応じた実装方法（Transaction Script / Domain Model / Event Sourcing）

4. Context間の連係設計
   └─ Context Mapping（Partnership / Anticorruption Layer / Conformist等）
```

### DDD用語対照表

| 英語（DDD標準） | 日本語訳 | 説明 |
|----------------|---------|------|
| Business Domain | 事業領域 | 組織が取り組む事業活動全体 |
| Subdomain | 業務領域 | 事業活動を構成する個別の業務単位 |
| Ubiquitous Language | ユビキタス言語 | チーム内で統一された用語体系 |
| Bounded Context | 区切られた文脈 | モデルの適用範囲と境界 |
| Context Map | 文脈地図 | Bounded Context間の関係を可視化した図 |
| Core Subdomain | 中核業務領域 | 競合優位の源泉となる業務 |
| Generic Subdomain | 一般業務領域 | 業界共通の解決済み問題 |
| Supporting Subdomain | 補完業務領域 | 差別化にならないが必要な業務 |
| Value Object | 値オブジェクト | 識別子を持たない不変オブジェクト |
| Entity | エンティティ | 一意の識別子を持つオブジェクト |
| Aggregate | 集約 | トランザクション境界を持つエンティティの集合 |

---

## 戦略的設計（概要）

### 1. 事業領域と業務領域

**Business Domain（事業領域）**: 組織が取り組む事業活動全体。

**Subdomain（業務領域）**: 事業活動を構成する個別の業務単位。以下の3種類に分類します。

#### Subdomain分類マトリクス

```
業務ロジック    大 │ 一般        │ 中核
の複雑さ          │ (Generic)   │ (Core)
                │             │
             小 │ 一般/補完   │ 補完
                │             │ (Supporting)
                └─────────────┘
                  小          大
                競合他社との差別化
```

| 分類 | 特徴 | 例 |
|------|------|-----|
| **Core Subdomain（中核）** | 競合優位の源泉、複雑な業務ロジック | Uberの配車アルゴリズム、Googleの検索ランキング |
| **Generic Subdomain（一般）** | 業界共通の解決済み問題 | 認証・認可、メール送信、決済処理 |
| **Supporting Subdomain（補完）** | 差別化にならないが必要な業務 | ETL、CRUD操作、通知システム |

### 2. ユビキタス言語（Ubiquitous Language）

**定義**: チーム内で統一された用語体系。ビジネス専門家と開発者が共通の言語を使用します。

**重要性**:
- 翻訳による情報損失を防止
- モデルの一貫性を保証
- コミュニケーションコストを削減

**構築方法**:
- イベントストーミング、ドメインエキスパートとの対話
- Gherkinなどの形式化されたツールの活用
- wiki、用語集での管理

### 3. Bounded Context（区切られた文脈）

**定義**: モデルの適用範囲と境界。同じ用語でも文脈により意味が異なる場合、別のBounded Contextに分離します。

**例**: 「見込み客（lead）」の意味は文脈により異なる
- **販売促進の文脈**: 複雑な管理対象（キャンペーン経由、イベント参加等）
- **営業の文脈**: シンプルな連絡先情報

**境界の判断基準**:
1. **モデルの一貫性**: 同じ用語が異なる意味を持つ場合は分離
2. **業務領域との対応**: 1つのSubdomainに複数のBounded Contextが存在する場合もある
3. **所有権の境界**: チーム構成と一致させることが望ましい

### 4. Context Mapping（文脈間の連係）

Bounded Context間の関係を定義するパターン群。詳細は [STRATEGIC-DESIGN.md](./references/./STRATEGIC-DESIGN.md) の「文脈間の連係パターン」を参照。

---

## 実装方法の選択（概要）

業務ロジックの複雑さに応じて適切な実装パターンを選択します。

### 実装パターンの選択フロー

```
業務ロジックの複雑さは？
  │
  ├─ 低（ETL、CRUD）
  │   └─ Transaction Script or Active Record
  │
  ├─ 中（一定の業務ルール）
  │   └─ Domain Model
  │
  └─ 高（複雑な業務ルール、時系列分析）
      └─ Event Sourcing + CQRS
```

### 1. Transaction Script
- **適用**: ETL、単純なビジネスロジック
- **特徴**: 手続き型、単一トランザクション内で完結

### 2. Active Record
- **適用**: CRUD中心のシステム
- **特徴**: データモデルと業務ロジックが結合、ORM利用

### 3. Domain Model
- **適用**: 複雑な業務ルール
- **構成要素**: Value Object、Entity、Aggregate

### 4. Event Sourcing
- **適用**: 時系列分析、監査要件、複雑な状態遷移
- **特徴**: イベントの履歴を保存、状態を再構築

詳細は [TACTICAL-PATTERNS.md](./references/./TACTICAL-PATTERNS.md) 参照。

---

## 実践の経験則（概要）

### 設計判断の経験則
- **シンプルさ優先**: 複雑さは必要な場合のみ導入
- **進化的設計**: 要件の変化に応じてパターンを切り替える
- **テストファースト**: ビジネスロジックは必ずテストを書く

### イベントストーミング
業務フローとイベントを可視化するワークショップ技法。詳細は [PRACTICE.md](./references/./PRACTICE.md) 参照。

### 既存システムへのDDD導入
レガシーシステムへの段階的な適用方法。詳細は [PRACTICE.md](./references/./PRACTICE.md) 参照。

---

## 他技法との関係（概要）

### Microservices
Bounded Contextをマイクロサービスにマッピングするパターン。詳細は [INTEGRATION.md](./references/./INTEGRATION.md) 参照。

### Event-Driven Architecture
Bounded Context間のイベント駆動連携。詳細は [INTEGRATION.md](./references/./INTEGRATION.md) 参照。

### Data Mesh
Bounded Contextをデータドメインにマッピング。詳細は [INTEGRATION.md](./references/./INTEGRATION.md) 参照。

---

## 意思決定フレームワーク

### ステップ1: 業務領域カテゴリの判定

| 判定基準 | Core | Generic | Supporting |
|---------|------|---------|-----------|
| **競合差別化** | 高（競合優位の源泉） | 低～中 | 低 |
| **業務ロジック複雑さ** | 高 | 低～中 | 低 |
| **変更頻度** | 高 | 低 | 中 |
| **戦略的重要性** | 最優先 | 標準対応 | コスト最小化 |

**判定方法**:
1. CEO/経営層に「この業務は競合他社に対する優位性に直結するか？」を質問
2. 「この業務ロジックは頻繁に変更されるか？」を確認
3. 複雑さと差別化のマトリクスにプロット

### ステップ2: 実装方法の選択

| 業務領域 | 複雑さ | 推奨パターン | 理由 |
|---------|-------|-------------|------|
| Core | 高 | Domain Model or Event Sourcing | 柔軟性と保守性が最優先 |
| Generic | 低～中 | ライブラリ・SaaS | 車輪の再発明を避ける |
| Supporting | 低 | Transaction Script / Active Record | コスト最小化 |

### ステップ3: 技術方式の選択

#### Domain Model採用時
```
Value Object設計
  ↓
Entity設計（識別子の決定）
  ↓
Aggregate境界の決定
  ↓
Repository実装
```

#### Event Sourcing採用時
```
イベント定義
  ↓
イベントストアの選定
  ↓
Read Model構築（CQRS）
  ↓
イベントバージョニング戦略
```

### ステップ4: テスト方針

| パターン | テスト対象 | カバレッジ目標 |
|---------|-----------|--------------|
| Transaction Script | 手続き全体 | 80%以上 |
| Active Record | モデルメソッド | 70%以上 |
| Domain Model | Value Object / Entity / Aggregate | 100%（ビジネスロジック） |
| Event Sourcing | イベントハンドラ / Projection | 100%（イベント処理） |

---

## ユーザー確認の原則（AskUserQuestion）

以下の判断が必要な場合、AskUserQuestionツールで確認してください。

### 1. 業務領域分類の確認

```
この業務は競合他社に対する優位性に直結しますか？

選択肢:
- はい（Core Subdomainとして扱う）
- いいえ、業界共通の問題（Generic Subdomainとして扱う）
- いいえ、必要だが差別化にならない（Supporting Subdomainとして扱う）
```

### 2. Bounded Context境界の確認

```
以下の用語は同じBounded Context内で一貫した意味を持ちますか？

例: 「顧客」「注文」「支払い」

選択肢:
- はい（単一のBounded Contextで管理）
- いいえ、文脈により意味が異なる（複数のBounded Contextに分離）
```

### 3. 実装パターンの確認

```
この業務ロジックの複雑さはどの程度ですか？

選択肢:
- 低（ETL、CRUD中心）→ Transaction Script / Active Record
- 中（一定の業務ルール）→ Domain Model
- 高（複雑な業務ルール、時系列分析）→ Event Sourcing + CQRS
```

### 4. Context連係パターンの確認

```
このBounded Context間の関係はどのパターンに該当しますか？

選択肢:
- 緊密な協力（Partnership / Shared Kernel）
- 上流・下流の関係（Conformist / Anticorruption Layer / Open-Host Service）
- 互いに独立（Separate Ways）
```

---

## 関連スキル

- **modernizing-architecture**: 社会技術的アーキテクチャのモダナイゼーション
- **architecting-microservices**: マイクロサービス分散パターン（Saga、メッセージング）
- **designing-web-apis**: REST API設計ベストプラクティス
- **writing-clean-code**: SOLID原則とクリーンコード実践

---

## 参考情報

### DDDの主要コンセプト
- **戦略的設計**: ビジネス分析とモデル境界
- **戦術的パターン**: 実装技法（Value Object、Entity、Aggregate、Event Sourcing）
- **ユビキタス言語**: チーム共通の用語体系
- **Bounded Context**: モデルの適用範囲
- **Context Mapping**: Bounded Context間の関係パターン

### 学習リソース
- イベントストーミングによる業務分析
- Gherkinによる仕様の形式化
- Context Mapperなどの可視化ツール
