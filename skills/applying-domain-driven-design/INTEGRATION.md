# 他技法との関係 / Integration with Other Techniques

本ファイルでは、DDDとマイクロサービス、イベント駆動型アーキテクチャ、データメッシュの関係を解説する。

---

## 1. マイクロサービスとDDD / Microservices and DDD

### 1.1 サービスの定義

**OASISのSOA参照モデルによる定義**:

サービスとは「ある機能を公開するメカニズムであり、公開されたインターフェースを介してアクセスされ、定義された制約と方針に従って実行される」。

重要なのは「公開されたインターフェース」である。

---

### 1.2 マイクロサービスの設計目的

マイクロサービスアーキテクチャは、システムを独立してデプロイ可能な小さなサービスに分割することで、変更の影響範囲を局所化し、開発・デプロイの俊敏性を向上させることを目的とする。

しかし、誤った境界設定は「分散した大きな泥団子」を生み出す。

**複雑さのトレードオフ**:
```
# 複雑さ

大きな泥団子 ────────→ 分散した大きな泥団子
  局所的複雑さ大            大局的複雑さ大

        ↓ 適切な境界設定

      Bounded Context
  （粒度のスイートスポット）
```

**大きな泥団子**: すべてのロジックが1つのモノリシックシステムに集約され、内部の複雑さ（局所的複雑さ）が高い。

**分散した大きな泥団子**: 不適切な境界でサービスを分割した結果、サービス間の依存関係が複雑化し、システム全体の複雑さ（大局的複雑さ）が増大する。

**Bounded Context（境界づけられた文脈）**: DDDの戦略的設計で定義される境界は、マイクロサービスの粒度設計における有力な候補となる。

---

### 1.3 深いモジュール（The Philosophy of Software Design）

**深いモジュールの原則**:
- **インターフェース（機能）**: 少ないほうが良い
- **実装の複雑さ（ロジック）**: 多いほうが良い

```
深いモジュール:
┌────┐
│機能│ ← 少ない公開インターフェース
├────┤
│    │
│ロジ│ ← 複雑なロジックをカプセル化
│ック│
│    │
└────┘

浅いモジュール:
┌────┐
│機能│ ← 多くの公開インターフェース
├────┤
│ロジ│ ← 単純なロジック
└────┘
```

**アンチパターン**:
```csharp
int AddTwoNumbers(int a, int b)
{
    return a + b;
}
```

このような単純なロジックを1つのサービスにすることは、ネットワーク通信のオーバーヘッドが価値を上回る。

**DDDの適用**:
- Bounded ContextやAggregateは、業務的に意味のある境界を提供する
- これにより、深いモジュールとしての設計が可能になる

---

### 1.4 DDDとマイクロサービス境界の設計

**Bounded Contextを起点とした境界設計**:

1つのBounded Contextは、1つ以上のマイクロサービスに対応する可能性がある。

**例: 販売促進と営業活動のBounded Context**

Bounded Context:
```
販売促進
├─ キャンペーン管理
├─ 広告素材最適化
└─ カタログ

営業活動
├─ 見込み客管理
├─ 電話営業
├─ 契約
└─ 営業事務
```

**分け方1（Bounded Contextごと）**:
```
販売促進サービス
営業活動サービス
認証認可サービス
請求サービス
顧客管理サービス
```

**分け方2（Aggregateごと）**:
```
キャンペーン管理サービス
広告素材最適化サービス
カタログサービス
見込み客管理サービス
電話営業サービス
契約サービス
営業事務サービス
報奨金最適化サービス
認証認可サービス
請求サービス
顧客管理サービス
```

**分け方3（ハイブリッド）**:
```
キャンペーン管理サービス
広告最適化サービス（広告素材+カタログ統合）
営業支援サービス（見込み客+電話営業+契約+営業事務統合）
請求サービス
顧客管理サービス
認証認可サービス
```

**粒度のスイートスポット**:
```
粒度

大きな泥団子 ── Bounded Context ── マイクロサービス ── 分散した大きな泥団子
                     ↑
             最適な粒度の範囲
```

Bounded ContextとAggregateの間に、組織の変更速度やチーム構成を考慮した最適な境界が存在する。

---

### 1.5 Aggregateとマイクロサービス境界

Aggregateはトランザクション境界であり、マイクロサービスの境界候補となる。

**例: キャンペーン最適化サービス（11のAggregate）**

インターフェース（少ない）:
```
CampaignOptimizationService
+ OptimizeCampaign(CampaignId): OptimizationResult
```

ロジックの複雑さ（多い）:
- 広告配信最適化
- 予算配分アルゴリズム
- A/Bテスト管理
- パフォーマンス追跡
- 11のAggregate

このようにAggregateをサービス内部にカプセル化することで、深いモジュールとして設計できる。

---

### 1.6 Context Mappingによる連係パターン

マイクロサービス間の連係は、Context Mappingパターンを適用する。

**Shared Kernel（共用カーネル）**:
```
下流のBounded Context
     ↕（共用）
上流のBounded Context
     ↕（共用）
下流のBounded Context
```

共通のモデルやコードを複数サービスで共有する。

**Anti-Corruption Layer（腐敗防止層）**:
```
下流のBounded Context
     ↑（モデル変換装置）
上流のBounded Context
     ↑（モデル変換装置）
下流のBounded Context
```

上流のモデル変更から下流を保護するため、変換層を設ける。

詳細はSTRATEGIC-DESIGN.mdのContext Mappingセクション参照。

---

### 1.7 変更コストと粒度

```
# 変更コスト

大きな泥団子 ─ 適切なマイクロサービス ─ 分散した大きな泥団子
      ↑                ↑                      ↑
    高コスト       低コスト              非常に高コスト
```

適切に境界づけられたマイクロサービスは、変更コストを最小化する。

---

## 2. イベント駆動型アーキテクチャとDDD / Event-Driven Architecture and DDD

### 2.1 イベント駆動型アーキテクチャの基本

イベント駆動型アーキテクチャでは、サービス間の連係をイベントのpublish/subscribeで実現する。

```
サービス1 ─publish→ イベント ─subscribe→ サービス2
```

DDDのDomain Eventは、イベント駆動型アーキテクチャの基盤となる。

---

### 2.2 イベントの3カテゴリ

#### 2.2.1 Event Notification（イベント通知）

**特徴**:
- 発行者は「何かが起きた」ことを通知するのみ
- 詳細情報は含まない（あるいは最小限のメタデータのみ）
- 受信者は必要に応じて発行者に問い合わせる

**実装例**:
```json
{
  "type": "paycheck-generated",
  "event-id": "537ec7c2-d1a1-2005-8654-96aee1116b72",
  "delivery-id": "05011927-a328-4860-a106-737b2929db4e",
  "timestamp": 1615726445,
  "payload": {
    "employee-id": "456123",
    "link": "/paychecks/456123/2021/01"
  }
}
```

受信者は`link`にアクセスして詳細を取得する。

**メリット**:
- 発行者と受信者の結合度が低い
- 受信者が必要な情報のみ取得

**デメリット**:
- 追加のHTTPリクエストが必要
- 発行者のAPIが常に利用可能である必要がある

---

#### 2.2.2 Event-Carried State Transfer（イベントによる状態転送）

**特徴**:
- イベントに必要な状態をすべて含める
- 受信者はイベントから状態を投影（キャッシュ）し、問い合わせ不要

**実装例**:
```json
{
  "type": "customer-updated",
  "event-id": "6b7ce6c6-8587-4e4f-924a-cec028000ce6",
  "customer-id": "01b18d56-b79a-4873-ac99-3d9f767dbe61",
  "timestamp": 1615728520,
  "payload": {
    "first-name": "Carolyn",
    "last-name": "Hayes",
    "phone": "555-1022",
    "status": "follow-up-set",
    "follow-up-date": "2021/05/08",
    "birthday": "1982/04/05",
    "version": 7
  }
}
```

受信者は`customer-updated`イベントから顧客情報をローカルに投影し、発行者への問い合わせなしに利用できる。

**メリット**:
- 受信者の読み取りパフォーマンス向上
- 発行者への依存を削減

**デメリット**:
- イベントサイズが大きくなる可能性
- 結果整合性（eventually consistent）

**差分更新の例**:
```json
{
  "type": "customer-updated",
  "event-id": "6b7ce6c6-8587-4e4f-924a-cec028000ce6",
  "customer-id": "01b18d56-b79a-4873-ac99-3d9f767dbe61",
  "timestamp": 1615728520,
  "payload": {
    "status": "follow-up-set",
    "follow-up-date": "2021/05/10",
    "version": 8
  }
}
```

変更されたフィールドのみを含めることで、イベントサイズを削減できる。

---

#### 2.2.3 Domain Event（ドメインイベント）

**特徴**:
- 業務上の出来事を表現
- Event NotificationとEvent-Carried State Transferの中間
- 業務的に重要な情報を含む

**実装例**:
```json
{
  "type": "person-married",
  "person-id": "01b9a761",
  "payload": {
    "person-id": "126a7b61",
    "assumed-partner-last-name": true
  }
}
```

このイベントは「結婚した」という業務イベントを表し、パートナーのIDと姓の変更有無を含む。

**Event Notificationとの違い**:
```json
// Event Notification
{
  "type": "person-married",
  "person-id": "01b9a761",
  "payload": {
    "person-id": "126a7b61",
    "details": "/01b9a761/marriage-data"
  }
}
```

**Event-Carried State Transferとの違い**:
```json
// Event-Carried State Transfer
{
  "type": "person-married",
  "person-id": "01b9a761",
  "payload": {
    "new-last-name": "Williams"
  }
}
```

Domain Eventは業務的文脈を保持しつつ、必要な情報を含む。

---

### 2.3 結合の種類

イベント駆動型アーキテクチャにおける結合を理解し、設計に反映する。

#### 2.3.1 実装の結合（Implementation Coupling）

発行者と受信者が同じ実装詳細（データフォーマット、ライブラリ等）に依存する。

**回避策**: 標準化されたフォーマット（JSON、Protobuf等）を使用し、共有スキーマで管理。

---

#### 2.3.2 機能的な結合（Functional Coupling）

受信者が発行者の機能に依存する。

**例**:
```
販売促進サービス → publish: CampaignActivated
                            ↓ subscribe
                         顧客管理サービス
```

顧客管理サービスはキャンペーンアクティベーションという販売促進サービスの機能に依存している。

**回避策**: Event-Carried State Transferを活用し、受信者が必要な情報を自律的に保持する。

---

#### 2.3.3 時間的な結合（Temporal Coupling）

発行者と受信者が同時にオンラインである必要がある。

**回避策**: メッセージキュー（Apache Kafka、RabbitMQ等）を用いた非同期配信。

---

### 2.4 イベント駆動設計の経験則

1. **Event-Carried State Transferの活用**: 共用サービスから状態を投影し、受信者の自律性を高める。

```
販売促進サービス
       ↓ subscribe（状態投影）
   顧客管理サービス（共用）
       ↓ subscribe（状態投影）
広告最適化サービス
```

2. **Event Notificationの選択的利用**: リアルタイム性が必要で、かつ詳細情報が頻繁に変わる場合。

3. **Domain Eventの中心配置**: 業務的な意味を保ちながら、適切な粒度で情報を含める。

4. **Outboxパターンの必須化**: データベーストランザクションとイベント配信の整合性を保証（TACTICAL-PATTERNS.md参照）。

5. **Consumer-Driven Contract**: 受信者が期待するイベントスキーマを定義し、発行者との契約を明確化。

6. **イベントバージョニング**: スキーマ変更時の互換性を保つため、バージョン管理戦略を採用。

7. **冪等性の保証**: at-least-once配信により同じイベントが複数回配信される可能性があるため、受信者は冪等に処理する。

---

### 2.5 DDDとイベント駆動型アーキテクチャの統合

**Domain Event → イベント駆動型アーキテクチャ**:

DDDで定義されたDomain Eventは、そのままイベント駆動型アーキテクチャのイベントとして活用できる。

```csharp
public class Campaign
{
    List<DomainEvent> _events;

    public void Deactivate(string reason)
    {
        IsActive = false;
        var newEvent = new CampaignDeactivated(_id, reason);
        _events.Append(newEvent);
    }
}
```

永続化後、Outboxパターンでメッセージ通信基盤に配信する。

```csharp
public class ManagementAPI
{
    public ExecutionResult DeactivateCampaign(CampaignId id, string reason)
    {
        try
        {
            var campaign = repository.Load(id);
            campaign.Deactivate(reason);
            _repository.CommitChanges(campaign);

            var events = campaign.GetUnpublishedEvents();
            for (IDomainEvent e in events)
            {
                _messageBus.publish(e); // Outboxパターンで実装
            }
            campaign.ClearUnpublishedEvents();
        }
        catch(Exception ex) { ... }
    }
}
```

---

## 3. データメッシュとDDD / Data Mesh and DDD

### 3.1 データメッシュの背景

**従来のアプローチ**:
- **データウェアハウス（DWH）**: すべての業務データを中央集約型のDWHに統合し、分析用に変換
- **データレイク**: 生データをそのまま保存し、分析時に必要な形に変換

**課題**:
- スケーラビリティの限界
- データの鮮度低下
- 組織のサイロ化（データチームと業務チームの分断）
- 変更への対応コスト

---

### 3.2 分析系データモデル

分析系データベースは、OLTP（Online Transaction Processing）ではなく、OLAP（Online Analytical Processing）用に最適化される。

**事実テーブル（Fact Table）**:
- 業務イベント（トランザクション）を記録
- 測定可能な数値データ（売上、数量等）
- 外部キーで特性テーブルと連携

**特性テーブル（Dimension Table）**:
- 事実を説明する属性（顧客、製品、日時等）

**例: サポート案件の分析モデル**

事実テーブル:
```
事実_完了した案件
- 案件番号 (PK)
- 担当者キー (FK)
- 分類キー (FK)
- 開始日キー (FK)
- 終了日キー (FK)
- 顧客キー (FK)
```

特性テーブル:
```
利用者 (users)
- user-Id (PK)
- first-name
- last-name
- email
- is-active
- role (FK)

案件カテゴリー (case-category)
- category-Id (PK)
- name
```

---

### 3.3 データメッシュの4原則

#### 原則1: ドメイン分割（Domain-Oriented Decentralization）

データを中央集約するのではなく、業務領域（Bounded Context）ごとに分散管理する。

**DDDとの統合**:
- Bounded Contextごとにデータ所有権を持つ
- 各Bounded Contextは自身のデータを「データプロダクト」として公開

---

#### 原則2: データプロダクト（Data as a Product）

データを「プロダクト」として扱い、消費者（他のチームやサービス）に価値を提供する。

**データプロダクトの構成要素**:
- データ本体（事実テーブル、特性テーブル）
- メタデータ（スキーマ、データ品質指標、リネージ）
- アクセスインターフェース（API、ストリーム、クエリエンドポイント）
- 品質保証（データバリデーション、モニタリング）

---

#### 原則3: セルフサービス基盤（Self-Serve Data Infrastructure）

各チームが自律的にデータプロダクトを構築・管理できるプラットフォームを提供。

**プラットフォーム要素**:
- データパイプライン構築ツール
- データカタログ
- データガバナンスポリシー自動化
- モニタリング・アラート

---

#### 原則4: 連合型ガバナンス（Federated Computational Governance）

中央集権的なガバナンスではなく、各ドメインチームが自律的にガバナンスを実行しつつ、全体の整合性を保つ。

**ガバナンス要素**:
- データ品質基準
- セキュリティポリシー
- プライバシー保護（GDPR対応等）
- データリネージ追跡

---

### 3.4 DDDとデータメッシュの組み合わせ

**Bounded Context = データドメイン**:

各Bounded Contextが1つ以上のデータプロダクトを所有する。

**例: 販売促進のBounded Context**

データプロダクト:
- キャンペーンパフォーマンス分析
- 広告素材効果測定
- 顧客コンバージョンファネル

これらのデータプロダクトは、Event-Sourced Domain ModelやEvent-Carried State Transferで生成されたイベントから投影される。

---

### 3.5 イベントストアとデータメッシュ

Event-Sourced Domain Modelを採用している場合、イベントストアがデータプロダクトのSource of Truthとなる。

**データプロダクトの生成フロー**:
```
イベントストア（Source of Truth）
    ↓ イベント
投影エンジン
    ↓
分析モデル（事実テーブル + 特性テーブル）
    ↓
データプロダクトAPI
```

**例: 見込み客分析データプロダクト**

イベント:
```
LeadInitialized → Contacted → FollowupSet → OrderSubmitted → PaymentConfirmed
```

分析モデル:
```
事実_見込み客状態
- LeadId
- Followups（フォローアップ回数）
- Status
- ConversionTime（初回接触から成約までの時間）
```

このモデルは、マーケティングチームがコンバージョン率を分析するためのデータプロダクトとして公開される。

---

### 3.6 データメッシュ導入時の経験則

1. **Bounded Contextの明確化**: データドメインの境界を定義する前に、Bounded Contextを明確にする。

2. **Event-Sourcing優先**: イベント履歴がある場合、データプロダクトの生成が容易になる。

3. **データプロダクトオーナーの設定**: 各データプロダクトに責任者を置き、品質とアクセシビリティを保証する。

4. **段階的導入**: 全社一斉導入ではなく、1つのBounded Contextから始める。

5. **Consumer-Driven Data Contracts**: データ消費者の要件を起点にデータプロダクトを設計する。

6. **データリネージの可視化**: イベントから分析モデルまでのデータ変換フローを追跡可能にする。

---

## まとめ

| 技法 | DDDとの関係 | 活用ポイント |
|---|---|---|
| マイクロサービス | Bounded ContextとAggregateが境界候補 | 深いモジュール設計、Context Mapping |
| イベント駆動型アーキテクチャ | Domain Eventがイベントのソース | Event-Carried State Transfer、Outbox |
| データメッシュ | Bounded Context = データドメイン | イベントストア活用、データプロダクト化 |

DDDの戦略的設計と戦術的パターンは、これらの技法と組み合わせることで、スケーラブルで保守性の高いシステムを実現する。
