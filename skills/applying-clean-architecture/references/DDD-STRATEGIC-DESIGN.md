# 戦略的設計（Strategic Design）

戦略的設計は、事業領域（Business Domain）を分析し、適切なモデル境界（Bounded Context）を定義するフェーズです。

---

## 1. 事業領域と業務領域

### Business Domain（事業領域）

**定義**: 組織が取り組む事業活動全体。

**例**:
- **FedEx**: 輸送・物流
- **Walmart**: 小売・在庫管理
- **Uber**: 配車サービス

### Subdomain（業務領域）

**定義**: 事業活動を構成する個別の業務単位。大規模な事業領域は複数のSubdomainに分解されます。

**例（Uber）**:
- 配車管理
- ドライバー管理
- 料金計算
- 決済処理
- 評価システム

---

## 2. Subdomain分類

Subdomainは以下の3つに分類されます。

### 2.1 Core Subdomain（中核業務領域）

**定義**: 競合優位の源泉となる業務領域。組織の差別化要因であり、最も複雑な業務ロジックを持ちます。

**特徴**:
- 競合他社に対する優位性に直結
- 頻繁に変更される
- 業務ロジックが複雑
- 最も投資すべき領域

**例**:
- **Uber**: 配車アルゴリズム（需要予測、ドライバーマッチング、料金最適化）
- **Google**: 検索ランキングアルゴリズム
- **Netflix**: レコメンデーションエンジン

**重要**: Core Subdomainは組織の競争力の中核であり、複数のCore Subdomainを持つ組織もあります（例: Googleは検索、広告、クラウド等の複数のCore Subdomainを持つ）。

### 2.2 Generic Subdomain（一般業務領域）

**定義**: 業界共通の解決済み問題。既存のライブラリやSaaSで対応可能な領域。

**特徴**:
- 競合差別化にならない
- 業務ロジックは標準的
- 車輪の再発明を避けるべき

**例**:
- 認証・認可（Auth0、Cognito等）
- メール送信（SendGrid、Mailgun等）
- 決済処理（Stripe、PayPal等）
- 一般的なEC機能（カート、チェックアウト等）

**対処方針**: 既製品やSaaSを活用し、開発コストを最小化します。

### 2.3 Supporting Subdomain（補完業務領域）

**定義**: 競合差別化にはならないが、事業運営に必要な業務領域。

**特徴**:
- 競合差別化にならない
- 業務ロジックは比較的単純
- コスト最小化が目標

**例**:
- ETL（データ抽出・変換・読み込み）
- CRUD操作（基本的なデータ管理）
- 通知システム
- シフト管理
- 品質管理

**対処方針**: シンプルな実装（Transaction Script、Active Record）でコストを最小化します。

---

## 3. Subdomain分類マトリクス

Subdomainの分類は「業務ロジックの複雑さ」と「競合他社との差別化」の2軸で判定します。

```
業務ロジック    大 │ Generic     │ Core
の複雑さ          │             │
                │             │
             小 │ Generic or  │ Supporting
                │ Supporting  │
                └─────────────┘
                  小          大
                競合他社との差別化
```

| 複雑さ | 差別化 | 分類 | 対処方針 |
|-------|-------|------|---------|
| 大 | 大 | **Core** | 最大限投資、Domain Model / Event Sourcing |
| 大 | 小 | **Generic** | 既製品・SaaS活用 |
| 小 | 大 | **Supporting** | シンプル実装（Transaction Script） |
| 小 | 小 | **Generic or Supporting** | 既製品・SaaS、またはシンプル実装 |

### 判定方法

#### ステップ1: 競合差別化の確認
経営層（CEO等）に以下の質問をします:

> **「この業務は競合他社に対する優位性に直結しますか?」**

- **YES** → Core or Supporting候補
- **NO** → Generic or Supporting候補

#### ステップ2: 複雑さの確認
開発チームと業務エキスパートに以下を確認します:

> **「この業務ロジックは複雑ですか? 頻繁に変更されますか?」**

- **複雑 & 頻繁** → Core
- **標準的** → Generic
- **単純** → Supporting

#### ステップ3: マトリクスへのプロット
上記の判定結果をマトリクスにプロットして分類を決定します。

---

## 4. Subdomain分類の注意点

### 4.1 時間経過による変化

Subdomainの分類は固定ではなく、時間経過や戦略変更により変化します。

**例**:
- **かつてのCore → 現在のGeneric**: Google Mapsの地図データ管理（他社が追いついた）
- **かつてのSupporting → 現在のCore**: UberのAI配車（競争力の源泉へ進化）

### 4.2 組織により分類が異なる

同じ業務でも、組織により分類が異なります。

**例: 顧客サービス**
- **Zappos**: Core Subdomain（優れた顧客サービスが競争力）
- **一般的なEC**: Supporting Subdomain（標準的なサポート業務）

### 4.3 細分化の必要性

大きなSubdomainは、さらに細分化する必要がある場合があります。

**例: 顧客サービスの細分化**

```
顧客サービス
  ├─ ヘルプデスクシステム（Generic）
  ├─ 案件の担当者選び（Core）
  ├─ チケット管理（Generic）
  ├─ 検索（Generic）
  ├─ 架電システム（Generic）
  ├─ シフト管理（Supporting）
  ├─ 知識ベース（Generic）
  └─ 通知システム（Generic）
```

**判定基準**:
- **案件の担当者選び**: Zapposの差別化要因 → **Core**
- **ヘルプデスクシステム**: 既製品で対応可能 → **Generic**
- **シフト管理**: 標準的な管理業務 → **Supporting**

---

## 5. ユビキタス言語（Ubiquitous Language）

### 5.1 定義と目的

**Ubiquitous Language（ユビキタス言語）**: チーム内で統一された用語体系。ビジネス専門家と開発者が共通の言語を使用します。

**目的**:
1. **翻訳による情報損失の防止**
2. **モデルの一貫性の保証**
3. **コミュニケーションコストの削減**

### 5.2 翻訳による情報損失

ビジネス専門家の知識を開発者が理解する際、翻訳により情報が失われます。

```
業務エキスパート → 要求分析担当者 → 要求仕様書 → 開発者
 (業務知識)       (概念モデル)    (要求仕様)   (解決モデル) → ソースコード
     ↓              ↓               ↓             ↓
   発見            設計             実装          実装
```

**問題点**:
- 各段階で情報が変換・損失される
- 業務知識とソースコードが乖離する
- 要求の変更が反映されにくい

**解決策**: ビジネス専門家と開発者が同じ言語を使用し、モデルを共同で構築します。

### 5.3 ユビキタス言語の構築

#### 5.3.1 イベントストーミング

**Event Storming**: 業務フローとイベントを可視化するワークショップ技法。

**参加者**:
- ビジネス専門家
- 開発者
- UI/UXデザイナー

**プロセス**:
1. **ドメインイベントの抽出**: 業務で発生するイベントを洗い出す
2. **コマンドの特定**: イベントを引き起こすアクションを特定
3. **集約の発見**: イベントとコマンドをグループ化
4. **Bounded Contextの境界を特定**: モデルの適用範囲を定義

#### 5.3.2 継続的な改善

ユビキタス言語は静的ではなく、継続的に改善します。

**改善方法**:
1. **チームミーティング**: 用語の曖昧さを議論
2. **コードレビュー**: 用語の一貫性を確認
3. **wiki・用語集**: 用語を文書化
4. **Gherkinによる形式化**: BDD（Behavior-Driven Development）で仕様を記述

#### 5.3.3 曖昧さの排除

**例: 「policy」の曖昧さ**

保険業界では「policy」が複数の意味を持ちます:
- **insurance contract（保険契約）**: 契約書
- **regulatory rule（規制ルール）**: 業界規則

**解決策**: 文脈に応じて異なる用語を使用
- **InsuranceContract**: 契約書
- **RegulatoryRule**: 規制ルール

### 5.4 Gherkinによる形式化

**Gherkin**: BDDで使用される形式言語。Given-When-Then形式で仕様を記述します。

**例**:

```gherkin
Scenario: AWS Infinidashの利用申請
  Given 利用者が以下のデータを入力:
    """
    {
      "serviceName": "AWS Infinidash",
      "region": "us-east-1",
      "budget": 10000
    }
    """
  When 利用申請を送信
  Then 申請が承認され、利用可能になる
```

**利点**:
- 曖昧さの排除
- テストコードとの連携（Cucumber等）
- 非エンジニアも理解可能

### 5.5 ユビキタス言語の維持

**wiki**: 用語集を管理するプラットフォーム。

**コードレビュー**: 用語の一貫性をチェック。

**自動化ツール**: 用語の一貫性をチェックするlintツール（例: NDepend）。

---

## 6. Bounded Context（区切られた文脈）

### 6.1 定義

**Bounded Context（区切られた文脈）**: モデルの適用範囲と境界。同じ用語でも文脈により意味が異なる場合、別のBounded Contextに分離します。

**重要性**:
- モデルの一貫性を保証
- チーム間の責任を明確化
- 技術スタックの独立性を確保

### 6.2 用語の多義性

同じ用語でも文脈により意味が異なる場合があります。

**例: 「見込み客（lead）」**

- **販売促進の文脈（Marketing）**:
  - 複雑な管理対象
  - キャンペーン経由、イベント参加等の多様な属性
  - ステータス遷移（新規 → 接触済み → 育成中）

- **営業の文脈（Sales）**:
  - シンプルな連絡先情報
  - 名前、電話番号、メールアドレス
  - 営業活動の対象

**問題点**: 同じモデルで両方の文脈を表現しようとすると、複雑さが増大します。

**解決策**: 別々のBounded Contextに分離します。

```
【販売促進の文脈】                【営業の文脈】
- 見込み客（Lead）                - 見込み客（Lead）
  - キャンペーンID                  - 名前
  - イベント参加履歴                - 電話番号
  - スコア                          - メールアドレス
  - ステータス                      - 担当営業
```

### 6.3 Bounded Contextの境界

Bounded Contextの境界は以下の基準で判定します。

#### 6.3.1 モデルの一貫性

**判定基準**: 同じ用語が異なる意味を持つ場合、別のBounded Contextに分離します。

**例**:
- **Lead（販売促進）** ≠ **Lead（営業）**
- **Order（EC注文）** ≠ **Order（倉庫出荷指示）**

#### 6.3.2 業務領域との対応

**原則**: 1つのSubdomainに複数のBounded Contextが存在する場合があります。

**例: 広告配信システム**

```
【販売促進Subdomain】
  ├─ 広告キャンペーン Context
  ├─ 公開 Context
  ├─ 承認 Context
  ├─ 顧客管理 Context
  ├─ 効果測定 Context
  └─ 会計 Context
```

**注意**: 無闇に分離すると連係コストが増大します。モデルの一貫性が保てる範囲で統合します。

#### 6.3.3 所有権の境界

**原則**: Bounded Contextの境界は、チームの所有権境界と一致させることが望ましいです。

**理由**:
- チーム間の調整コストを削減
- 責任の明確化
- デプロイの独立性

**例**:

```
【販売促進の文脈】                 【営業の文脈】
- チーム1                         - チーム2
- 広告キャンペーン管理             - 電話営業管理
- 顧客管理                         - 案件管理
```

### 6.4 モデルの独立性

**重要**: 各Bounded Contextは独立したモデルを持ちます。

**例: 顧客（Customer）モデル**

```
【販売促進の文脈】
class Customer {
  CustomerId id;
  List<Campaign> campaigns;
  Score score;
  Status status;
}

【営業の文脈】
class Customer {
  CustomerId id;
  Name name;
  PhoneNumber phone;
  EmailAddress email;
}
```

**同じエンティティ（Customer）でも、文脈により属性が異なります。**

### 6.5 技術的な境界

Bounded Contextは物理的な境界も持ちます。

#### 6.5.1 データベースの分離

**原則**: 各Bounded Contextは独立したデータベーススキーマを持ちます。

**理由**:
- データモデルの独立性
- スケーラビリティ
- 障害の影響範囲を限定

#### 6.5.2 デプロイの独立性

**原則**: 各Bounded Contextは独立してデプロイ可能です。

**例**:
- マイクロサービスアーキテクチャ
- モジュラーモノリス

#### 6.5.3 技術スタックの独立性

**原則**: 各Bounded Contextは異なる技術スタックを選択できます。

**例**:
- **販売促進の文脈**: TypeScript + React + PostgreSQL
- **営業の文脈**: Go + GraphQL + MongoDB

---

## 7. 文脈間の連係パターン（Context Mapping）

Bounded Context間の関係を定義するパターン群。

### 7.1 緊密な協力（Collaborative Patterns）

#### 7.1.1 Partnership（良きパートナー）

**定義**: 2つのBounded Context間で緊密に協力するパターン。

**特徴**:
- 共同で設計・開発
- APIの変更を調整
- 双方向の依存関係

**適用場面**:
- 密接に関連する機能
- 同じチームが所有

**図**:

```
[区切られた文脈1] ←───良き───→ [区切られた文脈2]
                   パートナー
```

**例**:
- ECの注文管理と決済処理
- 配車システムとドライバー管理

#### 7.1.2 Shared Kernel（共有カーネル）

**定義**: 2つのBounded Context間でモデルの一部を共有するパターン。

**特徴**:
- 共有部分は慎重に管理
- 変更には両チームの合意が必要
- 共有範囲は最小限に

**適用場面**:
- 認証・認可モデルの共有
- 共通のドメインエンティティ

**図**:

```
[文脈1] ←─ [認可モデル] ─→ [文脈2]
          モデルの共有
```

**注意点**:
1. **共有範囲を明確化**: 共有されるコード・スキーマを文書化
2. **変更管理**: 共有部分の変更は両チームの合意が必要
3. **テスト**: 共有部分の変更は両Context側でテスト必須

**リスク**: 共有範囲が拡大すると、密結合が増大します。

---

### 7.2 利用者と供給者（Customer-Supplier Patterns）

上流（Upstream）と下流（Downstream）の関係。

```
[上流（供給者）] ──→ [下流（利用者）]
```

#### 7.2.1 Conformist（従属者）

**定義**: 下流が上流のモデルに従属するパターン。

**特徴**:
- 上流のAPIをそのまま使用
- 下流は上流に依存
- 上流の変更に影響を受ける

**適用場面**:
- 既存システムとの統合（変更不可）
- 外部APIの利用

**図**:

```
[上流] ──→ [下流]
       従属する
```

**例**:
- 外部決済API（Stripe）の利用
- クラウドサービス（AWS、GCP）の利用

**注意点**: 上流の変更に脆弱であるため、長期的には別パターンへの移行を検討します。

#### 7.2.2 Anticorruption Layer（腐敗防止層）

**定義**: 下流が上流のモデルから独立するための変換層を設けるパターン。

**特徴**:
- 変換装置（Adapter）で上流モデルを変換
- 下流モデルの独立性を保証
- 上流の変更の影響を限定

**適用場面**:
- レガシーシステムとの統合
- 外部APIのラッピング

**図**:

```
[区切られた文脈1] ──→ [変換装置] ──→ [モデル] ──→ [区切られた文脈2]
                   (ACL)
```

**例**:

```csharp
// 上流の外部APIクライアント
class ExternalPaymentAPI {
  PaymentResponse ProcessPayment(PaymentRequest request);
}

// 変換装置（Anticorruption Layer）
class PaymentAdapter {
  public PaymentResult Process(Order order) {
    var request = MapToExternalRequest(order); // 変換
    var response = _externalAPI.ProcessPayment(request);
    return MapToInternalResult(response); // 変換
  }
}

// 下流の独立したモデル
class Order {
  OrderId id;
  Money totalAmount;
  PaymentMethod paymentMethod;
}
```

**利点**:
- 下流モデルの独立性
- 上流APIの変更の影響を限定
- テストの容易性（モックに置き換え可能）

#### 7.2.3 Open-Host Service（共用サービス）

**定義**: 上流が標準化されたAPIを提供し、複数の下流が利用するパターン。

**特徴**:
- Published Language（公開された言葉）で定義されたAPI
- バージョン管理
- 複数の下流が利用可能

**適用場面**:
- 共通サービスの提供（認証、決済等）
- 外部パートナーへのAPI公開

**図**:

```
         [共用サービス]
              ↓
    ┌─────────┼─────────┐
    ↓         ↓         ↓
[文脈1]   [文脈2]   [文脈3]
   ↓         ↓         ↓
[PL V1]   [PL V2]   [PL V1]

公開された言葉（Published Languages）
```

**例**:

```yaml
# OpenAPI (Swagger) による公開API
openapi: 3.0.0
info:
  title: Payment API
  version: 2.0.0
paths:
  /payments:
    post:
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/PaymentRequest'
      responses:
        '200':
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/PaymentResponse'
```

**重要**:
- **バージョン管理必須**: APIの破壊的変更は新バージョンとして公開
- **下位互換性**: 既存のクライアントに影響を与えない変更を心がける

---

### 7.3 互いに独立（Separate Ways）

**定義**: 2つのBounded Contextが完全に独立し、連係しないパターン。

**特徴**:
- データの複製
- 統合コストの削減
- 完全な独立性

**適用場面**:
- 統合コストが高い
- 共通の業務プロセスがない

**例**:
- 広告配信システムと会計システム（それぞれ独立したデータを管理）
- マーケティングツールとエンジニアリングツール

**トレードオフ**:
- **利点**: 統合コストの削減、完全な独立性
- **欠点**: データの重複、整合性の問題

---

## 8. Context Map（文脈地図）

### 8.1 定義

**Context Map（文脈地図）**: Bounded Context間の関係を可視化した図。

**目的**:
- システム全体の構造を理解
- 依存関係の把握
- 統合戦略の計画

### 8.2 Context Mapの例

```
[認証と認可]
    ↓ 上流
  従属する
    ↓ 下流
[販売促進] ←───良きパートナー───→ [請求]
    ↓
    ↓ 従属する
    ↓
[変換装置] ──→ [モデル]
    ↓
[既存広告配信システム]

[顧客管理] ←─ [モデルの共有] ─→ [請求]
    ↓
[共用サービス]
    ↓
[メッセージング]
```

### 8.3 Context Mapの作成方法

#### ステップ1: Bounded Contextの列挙
システム内のすべてのBounded Contextを洗い出します。

#### ステップ2: 関係の特定
各Bounded Context間の関係を特定します:
- Partnership
- Shared Kernel
- Conformist
- Anticorruption Layer
- Open-Host Service
- Separate Ways

#### ステップ3: 可視化
図示ツール（Context Mapper、Mermaid等）で可視化します。

### 8.4 Context Mapperツール

**Context Mapper**: Context Mapを作成するDSLおよびツール。

**URL**: https://contextmapper.org

**例**:

```
ContextMap {
  contains MarketingContext, SalesContext

  MarketingContext [U]->[D] SalesContext {
    implementationTechnology "RESTful API"
  }
}

BoundedContext MarketingContext {
  Aggregate Lead {
    Entity Lead {
      aggregateRoot
      LeadId id
      String campaignSource
      Score score
    }
  }
}

BoundedContext SalesContext {
  Aggregate Lead {
    Entity Lead {
      aggregateRoot
      LeadId id
      String name
      PhoneNumber phone
    }
  }
}
```

### 8.5 Context Mapの維持

**重要**: Context Mapは静的ではなく、継続的に更新します。

**更新タイミング**:
- 新しいBounded Contextの追加
- 関係パターンの変更
- 組織再編

**ツール**:
- **Context Mapper**: DSLベースの自動生成
- **Mermaid**: Markdownに埋め込み可能な図
- **PlantUML**: コードベースのUML生成

---

## まとめ

### 戦略的設計の実践ステップ

```
1. 事業領域の分析
   └─ Subdomain分類（Core / Generic / Supporting）

2. ユビキタス言語の構築
   └─ イベントストーミング、Gherkin形式化

3. Bounded Contextの定義
   └─ モデルの適用範囲と境界を明確化

4. Context Mappingの実施
   └─ Bounded Context間の関係パターンを選択

5. Context Mapの作成
   └─ システム全体の構造を可視化
```

### 戦略的設計の原則

1. **ビジネス価値優先**: Core Subdomainに最大限投資
2. **モデルの一貫性**: Bounded Context内で用語を統一
3. **独立性の確保**: Bounded Context間の疎結合
4. **継続的改善**: ユビキタス言語とContext Mapを定期的に更新

---

## 次のステップ

戦略的設計が完了したら、次は実装方法を選択します。

→ [TACTICAL-PATTERNS.md](./TACTICAL-PATTERNS.md) へ進む
