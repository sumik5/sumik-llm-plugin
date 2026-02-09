# 戦術的パターン / Tactical Patterns

本ファイルでは、DDD実装における4段階の業務ロジックパターン、3種類のアーキテクチャパターン、および通信パターンを解説する。

---

## 業務ロジック実装パターン（4段階）

業務領域の複雑さに応じて、適切な実装パターンを選択する。

### 1. Transaction Script（トランザクションスクリプト）

**適用対象**: 補完的業務領域、一般的業務領域で、データ構造が単純な手続き的操作。

**特徴**:
- 単一の手続き（関数/メソッド）で処理を完結
- ETL（Extract-Transform-Load）パイプライン、バッチ処理に適する
- データ構造が単純で、業務ロジックが少ない場合に有効

**実装例**:
```csharp
DB.StartTransaction();
var job = DB.LoadNextJob();
var json = LoadFile(job.Source);
var xml = ConvertJsonToXml(json);
WriteFile(job.Destination, xml.ToString());
DB.MarkJobAsCompleted(job);
DB.Commit();
```

**一貫性の担保**:
- データベーストランザクションでACID特性を保証
- メッセージングとの整合性はOutboxパターンで対応（通信パターン参照）

**冪等性の実装**:
- 操作が複数回実行されても同じ結果になるよう設計
- 楽観的ロックやバージョン番号の活用

```csharp
public void Execute(Guid userId, long expectedVisits)
{
    _db.Execute(@"UPDATE Users SET visits=visits+1
                  WHERE user_id=@p1 and visits = @p2",
                userId, expectedVisits);
}
```

WHERE句に`visits = @p2`を追加することで、期待される状態でのみ更新が実行される。

---

### 2. Active Record（アクティブレコード）

**適用対象**: 補完的業務領域、一般的業務領域で、データ構造が中程度の複雑さを持つCRUD中心の処理。

**特徴**:
- データベーステーブルと1対1で対応するクラス
- ORM（Object-Relational Mapping）との親和性が高い
- getter/setterメソッドでデータアクセス
- 永続化ロジックをオブジェクト自身が持つ（`Save()`メソッド等）

**実装例**:
```csharp
public void Execute(UserDetails userDetails)
{
    try
    {
        _db.StartTransaction();
        var user = new User(); // Active Recordオブジェクト
        user.Name = userDetails.Name;
        user.Email = userDetails.Email;
        user.Save(); // 永続化メソッド
        _db.Commit();
    } catch {
        _db.Rollback();
        throw;
    }
}
```

**適用判断**:
- データ構造が複雑でない
- 業務ロジックがシンプル
- CRUD操作が中心

---

### 3. Domain Model（ドメインモデル）

**適用対象**: 中核業務領域で、複雑な業務ロジックとデータ構造を持つ場合。

**特徴**:
- 業務の関心事を反映した豊かなオブジェクトモデル
- Value Object、Entity、Aggregate、Domain Event、Domain Serviceで構成
- 不変条件（invariants）の保護
- 業務の語彙とルールを表現

---

#### 3.1 Value Object（値オブジェクト）

**定義**: IDを持たず、値の等価性で識別されるオブジェクト。

**特徴**:
- 不変性（Immutable）
- 値の等価性（Value Equality）
- 自己検証（Self-Validation）
- プリミティブ型執着（Primitive Obsession）の解消

**実装例**:
```csharp
class Color
{
    public readonly byte Red;
    public readonly byte Green;
    public readonly byte Blue;

    public Color(byte r, byte g, byte b)
    {
        this.Red = r;
        this.Green = g;
        this.Blue = b;
    }

    public Color MixWith(Color other)
    {
        return new Color( // 新しいインスタンスを返す（不変性）
            r: (byte) Math.Min(this.Red + other.Red, 255),
            g: (byte) Math.Min(this.Green + other.Green, 255),
            b: (byte) Math.Min(this.Blue + other.Blue, 255)
        );
    }

    public override bool Equals(object obj)
    {
        var other = obj as Color;
        return other != null &&
               this.Red == other.Red &&
               this.Green == other.Green &&
               this.Blue == other.Blue;
    }

    public static bool operator == (Color lhs, Color rhs)
    {
        if (Object.ReferenceEquals(lhs, null)) {
            return Object.ReferenceEquals(rhs, null);
        }
        return lhs.Equals(rhs);
    }

    public static bool operator != (Color lhs, Color rhs)
    {
        return !(lhs == rhs);
    }

    public override int GetHashCode()
    {
        return ToString().GetHashCode();
    }
}
```

**プリミティブ型執着の解消**:

Before:
```csharp
var dave = new Person(
    id: 30217,
    firstName: "Dave",
    lastName: "Ancelovici",
    landlinePhone: "023745001",
    mobilePhone: "0873712503",
    email: "dave@learning-ddd.com",
    heightMetric: 180,
    countryCode: "BG");
```

After:
```csharp
var dave = new Person(
    id: new PersonId(30217),
    name: new Name("Dave", "Ancelovici"),
    landline: PhoneNumber.Parse("023745001"),
    mobile: PhoneNumber.Parse("0873712503"),
    email: Email.Parse("dave@learning-ddd.com"),
    height: Height.FromMetric(180),
    country: CountryCode.Parse("BG"));
```

Value Objectにすることで、型安全性の向上、ドメインロジックのカプセル化、可読性の改善が実現される。

---

#### 3.2 Entity（エンティティ）

**定義**: 一意のIDで識別され、ライフサイクルを持つオブジェクト。

**特徴**:
- 一意の識別子（ID）
- ライフサイクル管理
- 状態の変更が可能
- IDによる等価性判定

**実装例**:
```csharp
class Person
{
    public readonly PersonId Id;
    public Name Name { get; set; }

    public Person(PersonId id, Name name)
    {
        this.Id = id;
        this.Name = name;
    }
}
```

PersonIdが同じであれば、Nameが変わっても同一人物と識別される。

---

#### 3.3 Aggregate（集約）

**定義**: 関連するEntityとValue Objectをまとめ、トランザクション境界を定義するパターン。

**特徴**:
- トランザクション境界: 集約内は強い整合性を保証
- 集約ルート（Aggregate Root）: 外部からのアクセスはすべて集約ルートを経由
- 楽観的ロック: 並行更新を検出するためにバージョン管理

**実装例**:
```csharp
public class Ticket
{
    TicketId _id;
    int _version; // 楽観的ロックのためのバージョン番号
    List<Message> _messages;

    public void Execute(EvaluateAutomaticActions cmd)
    {
        if (this.IsEscalated && this.RemainingTimePercentage < 0.5 &&
            GetUnreadMessagesCount(forAgent: AssignedAgent) > 0)
        {
            _agent = AssignNewAgent();
        }
    }

    public int GetUnreadMessagesCount(UserId id)
    {
        return _messages.Where(x => x.To == id && !x.WasRead).Count();
    }
}
```

**楽観的ロックの実装**:
```sql
UPDATE tickets
SET ticket_status = @new_status,
    agg_version = agg_version + 1
WHERE ticket_id=@id and agg_version=@expected_version;
```

WHERE句で`agg_version=@expected_version`を確認し、バージョンが一致した場合のみ更新を実行する。一致しない場合は並行更新が発生したことを検出できる。

**集約の境界設計**:
- 集約内: 強い一貫性を保証する必要があるデータ
- 集約外: 結果的に整合していればよいデータ（IDで参照）

```csharp
public class Ticket
{
    private UserId _customer;       // ID参照
    private List<ProductId> _products; // ID参照
    private UserId _assignedAgent;  // ID参照
    private List<Message> _messages; // 実体を含む（強い一貫性）
}
```

集約ルートであるTicketは、顧客・製品・担当者をIDで参照し、メッセージは実体として保持する。

**アクセスルール**:
- 外部から集約内のエンティティ（Message等）に直接アクセスすることは禁止
- すべての操作は集約ルート（Ticket）を経由する

```csharp
public class Ticket
{
    List<Message> _messages;

    public void Execute(AcknowledgeMessage cmd)
    {
        var message = _messages.Where(x => x.Id == cmd.id).First();
        message.WasRead = true; // 集約ルート経由でのみ変更可能
    }
}
```

---

#### 3.4 Domain Event（ドメインイベント）

**定義**: 集約内で発生した業務上の重要な出来事を表すオブジェクト。

**特徴**:
- 状態変更を通知
- publish/subscribeパターンで他の集約やサービスと連携
- イミュータブル（不変）

**実装例**:
```json
{
  "ticket-id": "c9d286ff-3bca-4f57-94d4-4d4e490867d1",
  "event-id": 146,
  "event-type": "ticket-escalated",
  "escalation-reason": "missed-sla",
  "escalation-time": 1628970815
}
```

```csharp
public class Ticket
{
    private List<DomainEvent> _domainEvents;

    public void Execute(RequestEscalation cmd)
    {
        if (!this.IsEscalated && this.RemainingTimePercentage <= 0)
        {
            this.IsEscalated = true;
            var escalatedEvent = new TicketEscalated(_id, cmd.Reason);
            _domainEvents.Append(escalatedEvent);
        }
    }
}
```

イベントは集約内に一時保存され、永続化のタイミングでpublishされる。

---

#### 3.5 Domain Service（ドメインサービス）

**定義**: 複数の集約にまたがるロジックや、特定の集約に属さないドメインロジックを表現するステートレスなサービス。

**適用ケース**:
- 複数の集約を横断する計算や判断
- ドメイン知識が特定の集約に閉じない場合

**実装例**:
```csharp
public class ResponseTimeFrameCalculationService
{
    public ResponseTimeframe CalculateAgentResponseDeadline(
        UserId agentId,
        Priority priority,
        bool escalated,
        DateTime startTime)
    {
        var policy = _departmentRepository.GetDepartmentPolicy(agentId);
        var maxProcTime = policy.GetMaxResponseTimeFor(priority);
        if (escalated) {
            maxProcTime = maxProcTime * policy.EscalationFactor;
        }
        var shifts = _departmentRepository.GetUpcomingShifts(
            agentId, startTime, startTime.Add(policy.MaxAgentResponseTime));
        return CalculateTargetTime(maxProcTime, shifts);
    }
}
```

このサービスは、部門ポリシーとシフトスケジュールという複数のデータソースを用いて、エージェントの応答期限を計算する。

---

### 4. Event-Sourced Domain Model（イベント履歴式ドメインモデル）

**適用対象**: 中核業務領域で、監査記録や時系列データ分析が必要な場合。

**特徴**:
- 状態ではなく、状態を変化させたイベントの履歴を保存
- イベントストアがSource of Truth
- 状態は投影（Projection）によって再構築
- 完全な監査証跡（Audit Trail）

**イベントストアインターフェース**:
```csharp
interface IEventStore
{
    IEnumerable<Event> Fetch(Guid instanceId);
    void Append(Guid instanceId, Event[] newEvents, int expectedVersion);
}
```

**イベント履歴の例**:
```json
[
  {
    "lead-id": 12,
    "event-id": 0,
    "event-type": "lead-initialized",
    "last-name": "Smith",
    "first-name": "John",
    "phone-number": "555-2951",
    "timestamp": "2020-05-20T09:52:55.95Z"
  },
  {
    "lead-id": 12,
    "event-id": 1,
    "event-type": "contacted",
    "timestamp": "2020-05-20T12:32:08.24Z"
  },
  {
    "lead-id": 12,
    "event-id": 2,
    "event-type": "followup-set",
    "followup-on": "2020-05-27T12:00:00.00Z",
    "timestamp": "2020-05-20T12:32:08.24Z"
  },
  {
    "lead-id": 12,
    "event-id": 3,
    "event-type": "contact-details-changed",
    "phone-number": "555-8101",
    "timestamp": "2020-05-20T12:32:08.24Z"
  }
]
```

**状態投影（Projection）**:

同じイベント履歴から、用途に応じて異なる投影を生成できる。

```csharp
// 状態モデル投影
public class LeadStateModelProjection
{
    public long LeadId { get; private set; }
    public string FirstName { get; private set; }
    public string LastName { get; private set; }
    public LeadStatus Status { get; private set; }
    public PhoneNumber PhoneNumber { get; private set; }
    public DateTime? FollowupOn { get; private set; }
    public DateTime CreatedOn { get; private set; }
    public DateTime UpdatedOn { get; private set; }
    public int Version { get; private set; }

    public void Apply(LeadInitialized @event)
    {
        LeadId = @event.LeadId;
        Status = LeadStatus.NEW_LEAD;
        FirstName = @event.FirstName;
        LastName = @event.LastName;
        PhoneNumber = @event.PhoneNumber;
        CreatedOn = @event.Timestamp;
        UpdatedOn = @event.Timestamp;
        Version = 0;
    }

    public void Apply(Contacted @event)
    {
        UpdatedOn = @event.Timestamp;
        FollowupOn = null;
        Version += 1;
    }
}

// 検索モデル投影
public class LeadSearchModelProjection
{
    public long LeadId { get; private set; }
    public HashSet<string> FirstNames { get; private set; }
    public HashSet<string> LastNames { get; private set; }
    public HashSet<PhoneNumber> PhoneNumbers { get; private set; }
    public int Version { get; private set; }

    public void Apply(LeadInitialized @event)
    {
        LeadId = @event.LeadId;
        FirstNames = new HashSet<string>();
        LastNames = new HashSet<string>();
        PhoneNumbers = new HashSet<PhoneNumber>();
        FirstNames.Add(@event.FirstName);
        LastNames.Add(@event.LastName);
        PhoneNumbers.Add(@event.PhoneNumber);
        Version = 0;
    }

    public void Apply(ContactDetailsChanged @event)
    {
        FirstNames.Add(@event.FirstName);
        LastNames.Add(@event.LastName);
        PhoneNumbers.Add(@event.PhoneNumber);
        Version += 1;
    }
}

// 分析モデル投影
public class AnalysisModelProjection
{
    public long LeadId { get; private set; }
    public int Followups { get; private set; }
    public LeadStatus Status { get; private set; }
    public int Version { get; private set; }

    public void Apply(FollowupSet @event)
    {
        Status = LeadStatus.FOLLOWUP_SET;
        Followups += 1;
        Version += 1;
    }
}
```

**集約の復元**:
```csharp
public class TicketAPI
{
    private ITicketsRepository _ticketsRepository;

    public void RequestEscalation(TicketId id, EscalationReason reason)
    {
        var events = _ticketsRepository.LoadEvents(id); // イベント履歴取得
        var ticket = new Ticket(events); // イベントから状態復元
        var originalVersion = ticket.Version;
        var cmd = new RequestEscalation(reason);
        ticket.Execute(cmd); // 新しいイベント生成
        _ticketsRepository.CommitChanges(ticket, originalVersion);
    }
}

public class Ticket
{
    private List<DomainEvent> _domainEvents = new List<DomainEvent>();
    private TicketState _state;

    public Ticket(IEnumerable<IDomainEvents> events)
    {
        _state = new TicketState();
        foreach (var e in events)
        {
            AppendEvent(e); // イベントを順次適用
        }
    }

    private void AppendEvent(IDomainEvent @event)
    {
        _domainEvents.Append(@event);
        ((dynamic)_state).Apply((dynamic)@event);
    }

    public void Execute(RequestEscalation cmd)
    {
        if (!_state.IsEscalated && _state.RemainingTimePercentage <= 0)
        {
            var escalatedEvent = new TicketEscalated(_id, cmd.Reason);
            AppendEvent(escalatedEvent);
        }
    }
}
```

**パフォーマンス最適化**:
- スナップショット: 定期的に状態のスナップショットを作成し、復元時の負荷を軽減
- シャーディング: イベントストアを複数ストアに分散

---

## 実装パターン選択基準

| 業務領域カテゴリ | データ構造の複雑さ | 金銭処理・データ分析・監査記録か？ | 推奨パターン |
|---|---|---|---|
| 補完/一般連係 | 低 | いいえ | Transaction Script |
| 補完/一般連係 | 中 | いいえ | Active Record |
| 中核 | 高 | いいえ | Domain Model |
| 中核 | 高 | はい | Event-Sourced Domain Model |

---

## アーキテクチャパターン（3種）

### 1. Layered Architecture（レイヤードアーキテクチャ）

**特徴**:
- 3層または4層で構成
- 各層は下位層にのみ依存

**3層構成**:
```
プレゼンテーション層 (Web UI / CLI / REST API)
↓
業務ロジック層 (Entity / ルール / 処理)
↓
データアクセス層 (データベース / 通信基盤 / ストレージ)
```

**4層構成（サービス層追加）**:
```
プレゼンテーション層 (Web UI / CLI / REST API)
↓
サービス層 (アクション / アクション / アクション)
↓
業務ロジック層 (Entity / ルール / 処理)
↓
データアクセス層 (データベース / 通信基盤 / ストレージ)
```

**サービス層の役割**:
- 業務ロジック層とプレゼンテーション層の橋渡し
- トランザクション境界の管理
- 複数のUIから共通利用可能なインターフェース

```csharp
namespace ServiceLayer
{
    public class UserService
    {
        public OperationResult Create(ContactDetails contactDetails)
        {
            OperationResult result = null;
            try
            {
                _db.StartTransaction();
                var user = new User();
                user.SetContactDetails(contactDetails)
                user.Save();
                _db.Commit();
                result = OperationResult.Success;
            } catch (Exception ex) {
                _db.Rollback();
                result = OperationResult.Exception(ex);
            }
            return result;
        }
    }
}

namespace MvcApplication.Controllers
{
    public class UserController: Controller
    {
        [AcceptVerbs(HttpVerbs.Post)]
        public ActionResult Create(ContactDetails contactDetails)
        {
            var result = _userService.Create(contactDetails);
            return View(result);
        }
    }
}
```

**適用対象**: Transaction Script、Active Record

**注意**: Layer（層）とTier（ティア）は異なる。Layerは論理的分割、Tierは物理的分割（サーバー配置等）を指す。

---

### 2. Ports & Adapters（ポートアンドアダプター / Hexagonal Architecture）

**特徴**:
- 業務ロジックを中心に配置
- インフラストラクチャ層への依存をインターフェース（ポート）を介して疎結合化
- DIP（Dependency Inversion Principle）の適用
- インフラストラクチャの交換可能性

**構成**:
```
インフラストラクチャ層
↓（アダプター）
アプリケーション層（ポート）
↓
業務ロジック層
↓（ポート）
インフラストラクチャ層（アダプター）
```

**実装例**:
```csharp
// ポート（業務ロジック層が定義）
namespace App.BusinessLogicLayer
{
    public interface IMessaging
    {
        void Publish(Message payload);
        void Subscribe(Message type, Action callback);
    }
}

// アダプター（インフラストラクチャ層が実装）
namespace App.Infrastructure.Adapters
{
    public class SQSBus: IMessaging { ... }
}
```

**適用対象**: Domain Model

---

### 3. CQRS（Command-Query Responsibility Segregation / コマンドクエリ責務分離）

**定義**: コマンド（状態変更）とクエリ（状態取得）のモデルを分離するパターン。

**特徴**:
- 書き込み（コマンド実行モデル）と読み取り（読み取りモデル）を分離
- ポリグロットパーシステンス: 各モデルに最適なストレージを選択可能
- 読み取りモデルは複数作成可能（用途に応じた最適化）

**構成**:
```
コマンド実行 → コマンド実行モデル
                ↓（変更通知）
                投影エンジン
                ↓
クエリ ← 複数の読み取りモデル
```

**投影の同期方式**:

**1. 同期投影（Synchronous Projection）**:
```
投影エンジン → コマンドモデルストレージ.GetChangesAfter(checkpoint)
投影エンジン → 投影ストレージ.UpdateProjections()
投影エンジン → 投影ストレージ.UpdateLastCheckpoint()
```

**2. 非同期投影（Asynchronous Projection）**:
```
コマンド実行モデル → publish → 変更イベント
                              ↓（subscribe）
                        投影エンジン → 読み取りモデル更新
```

**適用対象**: Event-Sourced Domain Model（CQRSとの親和性が高い）

**注意**: CQRSは複雑さを増すため、必要性がない場合は適用しない。

---

## 通信パターン

### 1. Outbox Pattern（送信箱パターン）

**目的**: データベーストランザクションとメッセージング通信の整合性を保証する。

**問題**: データベースへのコミットとメッセージの送信が異なるトランザクションで行われると、片方が失敗した場合に不整合が発生する。

**解決策**: 送信すべきメッセージをデータベース内の「送信箱テーブル」に保存し、別プロセス（中継サービス）が非同期で送信する。

**実装**:
```
アプリケーション → データベーストランザクション:
                    1. 集約の状態を更新
                    2. 送信箱テーブルにメッセージを追加
                    3. コミット

中継サービス → 送信箱テーブルから未送信メッセージを取得
             → メッセージ通信基盤に送信
             → 送信済みマークを更新
```

**NoSQLでの実装例**:
```json
{
  "campaign-id": "364b33c3-2171-446d-b652-8e5a7b2be1af",
  "state": {
    "name": "Autumn 2017",
    "publishing-state": "DEACTIVATED",
    "ad-locations": [...]
  },
  "outbox": [
    {
      "campaign-id": "364b33c3-2171-446d-b652-8e5a7b2be1af",
      "type": "campaign-deactivated",
      "reason": "Goals met",
      "published": false
    }
  ]
}
```

**保証**: at-least-once配信（少なくとも1回は配信される。重複の可能性があるため、受信側で冪等性を考慮する）

---

### 2. Saga（サガ）

**定義**: 単純なイベント駆動の協調パターン。状態を持たず、イベントに反応してコマンドを発行する。

**特徴**:
- ステートレス
- イベント → コマンド のマッピング

**実装例**:
```csharp
public class CampaignPublishingSaga
{
    private readonly ICampaignRepository _repository;
    private readonly IPublishingServiceClient _publishingService;

    public void Process(CampaignActivated @event)
    {
        var campaign = _repository.Load(@event.CampaignId);
        var advertisingMaterials = campaign.GenerateAdvertisingMaterials();
        _publishingService.SubmitAdvertisement(@event.CampaignId, advertisingMaterials);
    }

    public void Process(PublishingConfirmed @event)
    {
        var campaign = _repository.Load(@event.CampaignId);
        campaign.TrackPublishingConfirmation(@event.ConfirmationId);
        _repository.CommitChanges(campaign);
    }

    public void Process(PublishingRejected @event)
    {
        var campaign = _repository.Load(@event.CampaignId);
        campaign.TrackPublishingRejection(@event.RejectionReason);
        _repository.CommitChanges(campaign);
    }
}
```

**適用対象**: シンプルなイベント連鎖

---

### 3. Process Manager（プロセスマネージャー）

**定義**: 複雑な状態遷移を管理し、条件分岐や長期にわたる協調処理を調整するパターン。

**特徴**:
- ステートフルな協調処理
- if-elseによる条件分岐
- 複数のターゲットへのコマンド発行
- 状態の永続化

**実装例**:
```csharp
public class BookingProcessManager
{
    private readonly IList<IDomainEvent> _events;
    private BookingId _id;
    private Destination _destination;
    private TripDefinition _parameters;
    private EmployeeId _traveler;
    private Route _route;
    private IList<Route> _rejectedRoutes;
    private IRoutingService _routing;

    // プロセス初期化
    public void Initialize(Destination destination, TripDefinition parameters, EmployeeId traveler)
    {
        _destination = destination;
        _parameters = parameters;
        _traveler = traveler;
        _route = _routing.Calculate(destination, parameters);
        var routeGenerated = new RouteGeneratedEvent(BookingId: _id, Route: _route);
        var commandIssuedEvent = new CommandIssuedEvent(
            command: new RequestEmployeeApproval(_traveler, _route)
        );
        _events.Append(routeGenerated);
        _events.Append(commandIssuedEvent);
    }

    // ルート承認時
    public void Process(RouteConfirmed confirmed)
    {
        var commandIssuedEvent = new CommandIssuedEvent(
            command: new BookFlights(_route, _parameters)
        );
        _events.Append(confirmed);
        _events.Append(commandIssuedEvent);
    }

    // ルート拒否時（再計算）
    public void Process(RouteRejected rejected)
    {
        var commandIssuedEvent = new CommandIssuedEvent(
            command: new RequestRerouting(_traveler, _route)
        );
        _events.Append(rejected);
        _events.Append(commandIssuedEvent);
    }

    // 再ルート承認時
    public void Process(ReroutingConfirmed confirmed)
    {
        _rejectedRoutes.Append(_route);
        _route = _routing.CalculateAltRoute(_destination, _parameters, _rejectedRoutes);
        var routeGenerated = new RouteGeneratedEvent(BookingId: _id, Route: _route);
        var commandIssuedEvent = new CommandIssuedEvent(
            command: new RequestEmployeeApproval(_traveler, _route)
        );
        _events.Append(confirmed);
        _events.Append(routeGenerated);
        _events.Append(commandIssuedEvent);
    }

    // フライト予約完了時
    public void Process(FlightBooked booked)
    {
        var commandIssuedEvent = new CommandIssuedEvent(
            command: new BookHotel(_destination, _parameters)
        );
        _events.Append(booked);
        _events.Append(commandIssuedEvent);
    }
}
```

**適用対象**: 複雑な状態遷移や長期にわたるビジネスプロセス

---

## まとめ

| 実装パターン | 適用領域 | アーキテクチャ | 通信 |
|---|---|---|---|
| Transaction Script | 補完/一般（低複雑） | Layered（3層） | Outbox |
| Active Record | 補完/一般（中複雑） | Layered（3層/4層） | Outbox |
| Domain Model | 中核（高複雑） | Ports & Adapters | Outbox / Saga |
| Event-Sourced Domain Model | 中核（監査要件） | CQRS | Outbox / Process Manager |

戦術的パターンは、戦略的設計（Bounded Context）の中で実装される。業務領域の複雑さと要件に応じて、適切なパターンを選択すること。
