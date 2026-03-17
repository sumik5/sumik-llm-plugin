# アーキテクチャスタイル比較

## スタイル選択の基本姿勢

Clean Architecture は**特定のスタイルを強制しない**。CA は依存方向のルールを定める枠組みであり、その中でどのスタイルを採用するかはシステムの要件による。

---

## 主要アーキテクチャスタイル一覧

### 1. Layered（レイヤード）スタイル

最も一般的なスタイル。各レイヤーが上下のレイヤーとのみ通信する。

```
[Presentation Layer]
       ↓
[Business Logic Layer]
       ↓
[Data Access Layer]
       ↓
[Database]
```

**CA との関係：** CA の同心円モデルはレイヤードスタイルの発展形。CA が追加するのは「依存は内側のみ」という制約と、「フレームワーク・DBは外側」という認識の転換。

| 項目 | 従来のレイヤード | Clean Architecture |
|------|----------------|-------------------|
| 依存方向 | 上から下へ一方向 | 外から内へ（同心円）|
| DB の位置づけ | 最下層（重要） | 最外層（詳細） |
| フレームワーク | 全体に影響 | 最外層に閉じ込め |

### 2. Hexagonal Architecture（Ports and Adapters）

Clean Architecture の前身的存在。ビジネスロジックを中心に置き、外部との接点を「ポート」として抽象化する。

```
         [REST API Adapter]
              ↓
[Port] ← [Business Logic] → [Port]
              ↑
         [DB Adapter]
```

**CA との共通点：**
- ビジネスロジックを中心に置く
- 外部との接点をインターフェース（ポート）で抽象化
- アダプターがポートを実装

**実践的な違い：** CA はより詳細なレイヤー定義（Entity, UseCase, Adapter）を提供。Hexagonal はコンセプト重視。

### 3. Pipes and Filters スタイル

データを順次変換する処理チェーン。各フィルターは独立した変換処理を担う。

```
[Input] → [Filter1] → [Filter2] → [Filter3] → [Output]
```

**適用場面：**
- ETL パイプライン
- データ処理・変換システム
- コンパイラ・ビルドシステム

**CA との組み合わせ：** パイプライン処理を UseCase 層に配置し、各フィルターをエンティティルールで整理する。

### 4. MVC（Model-View-Controller）スタイル

UIとビジネスロジックの分離。Clean Architecture の Interface Adapter 層に対応。

```
[User] → [Controller] → [Model]
                    ↘ [View] ← [Model]
```

**CA における MVC の位置：**
- MVC 全体が **Interface Adapters 層**に収まる
- Model は Entity や UseCase の出力を ViewModel に変換したもの
- Controller はリクエストを UseCase の入力に変換するもの

**重要：** MVC は CA の「アーキテクチャ全体」ではなく「Interface Adapters 層のパターン」に過ぎない。

### 5. N-Tiered スタイル

物理的なデプロイ階層を明示するスタイル。

```
[Client Tier] ←→ [Application Server Tier] ←→ [Database Tier]
```

**3層 vs CA：**
- 3層はデプロイ構成の概念
- CA は依存関係の概念
- 両立可能：CA の論理レイヤーを 3 層の物理構成にマッピングする

### 6. Event-Driven / Reactive スタイル

イベントを通じてコンポーネントが疎結合に連携。

```
[Producer] → [Event Bus] → [Consumer1]
                        → [Consumer2]
```

**CA との組み合わせ：**
- Event Bus は外部インフラとして Frameworks & Drivers 層に配置
- UseCase がドメインイベントを発火（OutputBoundary 経由）
- イベントハンドラーは別 UseCase として実装

### 7. Service-Oriented Architecture（SOA）とマイクロサービス

システムをサービス単位に分割。

**CA との関係：**
- 各サービス内部で CA を適用する
- サービス間通信は最外層（Frameworks & Drivers）で処理
- サービス境界は CA の境界と一致させるのが理想

**マイクロサービスでの注意点：**
- CA はサービス内アーキテクチャを定義する
- サービス間の Saga, CQRS 等は `architecting-infrastructure` スキルを参照

---

## モバイルアーキテクチャへの適用

### iOS / Android での CA

```
iOS 例：
[UIViewController]     ← Frameworks & Drivers
[Presenter/ViewModel]  ← Interface Adapters
[UseCase/Interactor]   ← Use Cases
[Domain Model]         ← Entities
```

**モバイル固有の考慮事項：**
- ライフサイクル管理（バックグラウンド遷移）は最外層で処理
- ViewModel（MVVM）は Presenter に相当
- Repository パターンで DB/ネットワークを抽象化

---

## エンタープライズアプリケーションスタイル

### Web アプリケーション構造

```
[HTTP Request]
     ↓
[Controller（Interface Adapters）]
     ↓
[UseCase Interactor]
     ↓           ↓
[Entity]    [Gateway Interface]
                  ↓
           [Repository実装（Interface Adapters）]
                  ↓
             [ORM / SQL（Frameworks & Drivers）]
```

### CQRS との統合

```
Write Side:              Read Side:
[Command]                [Query]
    ↓                        ↓
[Command Handler]       [Query Handler]
    ↓                        ↓
[Domain Entity]         [Read Model（DTO直接）]
    ↓
[Event Store / DB]
```

CQRS は CA と相性が良い。Command 側で CA を完全適用し、Query 側は Read Model（DTO）への直接アクセスを許容するパターン。

---

## スタイル選択ガイド

| 要件 | 推奨スタイル |
|------|------------|
| 複雑なビジネスロジック | CA + DDD |
| データパイプライン処理 | Pipes and Filters |
| UIとロジックの分離 | CA の Interface Adapters 層内で MVC |
| イベント駆動システム | CA + Event-Driven |
| マイクロサービス展開 | CA（各サービス内）+ `architecting-infrastructure` |
| ML システム | CA の外層に ML パイプラインを配置 |
| 組み込み・安全クリティカル | Clean Embedded Architecture（CA の組み込み版） |

---

## 異種スタイルの組み合わせ（Heterogeneous Styles）

実際のシステムは複数スタイルの組み合わせが多い。

**例：EC サイト**
```
認証サービス    →  Layered + CA
商品カタログ    →  CQRS + CA
注文処理        →  CA + Event-Driven
検索機能        →  Read-Optimized（Query 側のみ）
バッチ処理      →  Pipes and Filters
```

**組み合わせ時の注意：**
- 各コンポーネント内で一貫したスタイルを維持
- スタイル間の境界は明確に定義
- 「なぜこのスタイルを選んだか」を文書化
