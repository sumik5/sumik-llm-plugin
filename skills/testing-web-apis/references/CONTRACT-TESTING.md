# コントラクトテスト

## 1. コントラクトテストとは

### 1.1 基本概念

コントラクトテストは、API間の「契約（Contract）」をプログラムで自動検証する手法である。ここでの契約とは、あるAPIが別のAPIに対して送るリクエストの形式と、それに対して返されるレスポンスの形式についての合意を指す。

マイクロサービスアーキテクチャでは、複数のAPIが相互に依存しながら動作する。コントラクトテストは、これらのAPI間の「約束事」が守られているかどうかを、各APIを個別にテストすることで検証する。

### 1.2 E2Eテストとの違い

| 観点 | コントラクトテスト | E2Eテスト |
|------|-------------------|-----------|
| スコープ | API間のインターフェース | システム全体のフロー |
| 実行速度 | 高速（各APIを個別にテスト） | 低速（全サービス起動が必要） |
| 安定性 | 高い（外部依存が少ない） | 不安定になりやすい |
| フィードバック | 「どのAPIの契約が破られたか」が明確 | 失敗原因の特定が困難 |
| 環境要件 | 軽量（モック使用） | 本番相当の環境が必要 |

コントラクトテストは「2つのAPI間の約束が守られているか」だけに集中する。システム全体が正しく動作するかの確認はE2Eテストの役割であり、両者は補完的な関係にある。

---

## 2. なぜコントラクトテストが必要か

### 2.1 マイクロサービス環境での統合テストの限界

マイクロサービスが増えると、統合テストには深刻な問題が生じる。

- **環境の複雑化** --- 全サービスを同時に起動・維持するコストが高い
- **テストの脆弱性** --- 1つのサービスの不調が全テストを失敗させる
- **フィードバックの遅延** --- 実行に時間がかかり、開発サイクルが鈍化する
- **責任の曖昧化** --- テスト失敗時に、どのサービスに問題があるか特定しにくい

### 2.2 テストダブルの乖離問題

統合テストの代替としてモックを使うアプローチにも落とし穴がある。

```
Consumer側のモック:「Provider APIは POST /message/ に 201 を返すはず」
Provider側の実装:「POST /message/ には 200 を返すように変更した」
```

モックが実際のAPIの挙動と乖離すると、テストは通っているのに本番で障害が発生する。コントラクトテストは、この「モックと実装のズレ」を検出する仕組みを提供する。

### 2.3 チーム間コミュニケーションの仕組み化

コントラクトテストの真の価値は、技術的な検証だけではない。コンシューマチームとプロバイダチームの間に「契約が変わったら必ず対話が生まれる」というフローを構築できる点にある。契約の変更がテスト失敗として可視化されるため、暗黙の前提や認識のズレが早期に顕在化する。

---

## 3. Consumer-Driven Contract Testing

### 3.1 コンシューマ駆動の考え方

Consumer-Driven Contract Testing（CDCT）は、APIの利用者（コンシューマ）側が「自分が必要とするリクエスト/レスポンスの形式」を契約として定義し、提供者（プロバイダ）側がその契約を満たしているかを検証するアプローチである。

```
コンシューマ                    プロバイダ
    |                              |
    |  1. 契約を定義               |
    |  （期待するリクエスト/       |
    |    レスポンスの形式）         |
    |                              |
    |  2. 契約をBrokerに公開  ---> |
    |                              |
    |                  3. Brokerから契約を取得
    |                              |
    |                  4. 契約に従って検証
    |                              |
    |  <--- 5. 検証結果をBrokerに報告
    |                              |
```

### 3.2 コンシューマ側: 契約の定義

コンシューマ側では、プロバイダAPIに送るリクエストと期待するレスポンスをペアで定義する。この定義がモックとして機能し、コンシューマのテストではこのモックに対してリクエストを送る。テストが成功すると、契約を記述したJSONファイル（Pactファイル）が生成される。

```java
// コンシューマ側: 契約の定義
@Pact(consumer = "Booking API", provider = "Message API")
public RequestResponsePact createPact(PactDslWithProvider builder) {
    return builder
        .uponReceiving("Message")       // 契約の説明
        .path("/message/")              // リクエスト先URI
        .method("POST")                 // HTTPメソッド
        .body(payload.toString())       // リクエストボディ
        .willRespondWith()
        .status(201)                    // 期待するステータスコード
        .toPact();                      // 契約（Pactファイル）を生成
}
```

### 3.3 プロバイダ側: 契約の検証

プロバイダ側では、Brokerから契約を取得し、契約に記述されたリクエストを実際のAPIに送って、レスポンスが契約通りかを検証する。

```java
// プロバイダ側: 契約の検証
@Provider("Message API")
@PactBroker(url = "https://broker.example.com",
    authentication = @PactBrokerAuth(token = "TOKEN"))
public class MessageBookingVerifyIT {

    @BeforeEach
    void before(PactVerificationContext context) {
        // 検証結果をBrokerに公開する設定
        System.setProperty("pact.verifier.publishResults", "true");
        context.setTarget(new HttpTestTarget("localhost", 3006, "/"));
    }

    @TestTemplate
    @ExtendWith(PactVerificationInvocationContextProvider.class)
    void pactVerificationTestTemplate(PactVerificationContext context) {
        // 契約ごとに動的にテストを生成し検証
        context.verifyInteraction();
    }
}
```

### 3.4 双方向の検証フロー

1. **コンシューマテスト実行** --- 契約を定義し、モックに対してテスト。成功するとPactファイル（JSON）が生成される
2. **Pactファイル公開** --- 生成されたPactファイルをBrokerにパブリッシュ
3. **プロバイダテスト実行** --- BrokerからPactファイルを取得し、プロバイダAPIが契約を満たすか検証
4. **検証結果の報告** --- 検証結果をBrokerに報告。成功・失敗が一元管理される
5. **契約変更時** --- コンシューマが契約を変更すると、プロバイダの検証が失敗し、チーム間の対話が発生する

---

## 4. Pact フレームワークの基本

### 4.1 Pactの概要

Pactは、Consumer-Driven Contract Testingを実現するためのツールセットである。以下の特徴を持つ。

- コンシューマAPI用・プロバイダAPI用の両方のライブラリを提供
- Java、JavaScript/TypeScript、Python、Go、Ruby、.NET等の主要言語をサポート
- 契約を格納・管理するBrokerを提供

### 4.2 Pact DSLによる契約定義

Pactは流暢なDSL（Domain-Specific Language）で契約を定義する。

```java
return builder
    .given("A room exists")                // プロバイダの事前条件（State）
    .uponReceiving("A booking request")    // インタラクションの説明
    .path("/booking/")
    .method("POST")
    .headers("Content-Type", "application/json")
    .body(new PactDslJsonBody()
        .integerType("roomid", 1)
        .stringType("firstname", "Mark")
        .booleanType("depositpaid", true)
        .object("bookingdates")
            .stringType("checkin", "2024-01-01")
            .stringType("checkout", "2024-01-03")
        .closeObject())
    .willRespondWith()
    .status(201)
    .body(new PactDslJsonBody()
        .integerType("bookingid"))
    .toPact();
```

### 4.3 Pact Broker

Pact Brokerは、契約の共有リポジトリとして機能する。

**主な機能**:

- **一元管理** --- すべてのAPI間の契約を1か所で管理。API間の依存関係を可視化する
- **バージョン管理** --- 契約の履歴を追跡し、破壊的変更を防ぐためのバージョン選択を支援する
- **検証状態の管理** --- どの契約が検証済みか、未検証か、失敗しているかを追跡する
- **API関係の可視化** --- すべてのAPIの依存関係をネットワーク図として描画できる

**デプロイ形態**:
- セルフホスト型: Pact Broker（OSS）をプライベートにセットアップ
- クラウド型: Pactflow（SaaS）を利用

### 4.4 バージョニングとタグ付け

Pact Brokerは契約のバージョン管理を行う。コンシューマがパブリッシュするたびに新しいバージョンが記録される。

- **バージョン番号** --- コンシューマのアプリケーションバージョンと紐付け
- **タグ** --- 環境（`dev`、`staging`、`production`）やブランチ名を付与し、どの環境のどのバージョンと検証すべきかを制御
- **Can I Deploy** --- Pact CLIの `can-i-deploy` コマンドで、デプロイ前に全契約が検証済みかを確認

### 4.5 CI/CDパイプラインへの組み込み

```yaml
# コンシューマ側パイプライン
- name: Run Consumer Contract Tests
  run: mvn test -Dtest="*ContractIT"

- name: Publish Pact
  run: mvn pact:publish
  env:
    PACT_BROKER_URL: ${{ secrets.PACT_BROKER_URL }}
    PACT_BROKER_TOKEN: ${{ secrets.PACT_BROKER_TOKEN }}

# プロバイダ側パイプライン
- name: Verify Provider Contracts
  run: mvn test -Dtest="*VerifyIT"
  env:
    PACT_BROKER_URL: ${{ secrets.PACT_BROKER_URL }}

- name: Can I Deploy Check
  run: pact-broker can-i-deploy --pacticipant "Message API" --version $VERSION
```

---

## 5. OpenAPI/Swagger スキーマベースの検証

### 5.1 スキーマを契約として利用

OpenAPI（Swagger）スキーマは、APIの入出力仕様を定義する。このスキーマ自体を「契約」として扱い、実装がスキーマに準拠しているかを検証するアプローチがある。

```yaml
# OpenAPI 3.0 スキーマ例
paths:
  /booking/:
    post:
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Booking'
      responses:
        '201':
          description: Created
        '403':
          description: Forbidden
components:
  schemas:
    Booking:
      type: object
      properties:
        roomid:
          type: integer
        firstname:
          type: string
        depositpaid:
          type: boolean
      required:
        - roomid
        - firstname
```

### 5.2 PactとOpenAPIの使い分け

| 観点 | Pact（Consumer-Driven） | OpenAPIスキーマ検証 |
|------|------------------------|-------------------|
| 契約の定義者 | コンシューマ | API設計者（プロバイダ寄り） |
| 検証範囲 | 実際のユースケースに基づく | スキーマ全体の準拠性 |
| チーム間対話 | 契約変更で自然に対話が発生 | スキーマレビューで対話 |
| 適用場面 | マイクロサービス間通信 | パブリックAPI、内部API仕様管理 |

両者は排他的ではなく、併用が効果的な場面も多い。OpenAPIでAPIの全体像を定義し、Pactで個別のコンシューマ・プロバイダ間の契約を検証するという組み合わせが一般的である。

---

## 6. コントラクトテストの導入パターン

### 6.1 既存サービスへの段階的導入

コントラクトテストを既存のマイクロサービス環境に導入する際は、段階的に進める。

1. **最も重要なAPI関係から着手** --- 障害時のインパクトが大きいAPI間の契約から定義する
2. **コンシューマ側から始める** --- まずコンシューマテストを作り、Pactファイルを生成する
3. **Brokerをセットアップ** --- Pactファイルの共有基盤を用意する
4. **プロバイダ検証を追加** --- プロバイダ側にPact検証テストを追加する
5. **CI/CDに組み込む** --- パイプラインでの自動実行を設定する
6. **他のAPI関係に拡大** --- 成功パターンを横展開する

### 6.2 コントラクトテスト vs E2Eテストのバランス

コントラクトテストはE2Eテストを完全に置き換えるものではない。

- **コントラクトテストで担保**: API間のインターフェースの整合性、個別のリクエスト/レスポンスの形式
- **E2Eテストで担保**: 複数サービスを横断するビジネスフロー全体の正しさ、実環境での統合動作

コントラクトテストを充実させることで、E2Eテストの数を最小限に抑えられる。E2Eテストは最も重要なユーザーシナリオに絞り、API間の整合性はコントラクトテストに委ねるのが実践的なバランスである。

### 6.3 テスト戦略における位置づけ

コントラクトテストは、テスト戦略の中で独自の役割を果たす。機能の正しさを検証する通常のテストに加えて、チーム間の認識のズレや暗黙の前提を可視化する効果がある。コントラクトテストが失敗したとき、それは単なるバグ報告ではなく、チーム間の対話の起点として機能する。コードを修正すれば済む場合もあるが、より広範な設計議論に発展し、新たなリスクが発見されることも少なくない。
