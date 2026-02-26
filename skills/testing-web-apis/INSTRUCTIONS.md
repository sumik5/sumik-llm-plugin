# Web API テスト戦略ガイド

## 1. テスト戦略の全体像

### 1.1 品質とリスクの定義

**品質の定義**:「品質とは、ある大切な人にとってのある時点での価値のことである」

テスト戦略を立てる前に、以下の3ステップで目標を定める：

1. **品質特性の特定** — ユーザーインタビュー・ふるまい観察・フィードバック分析から、ルックアンドフィール・セキュリティ・正確度・可用性・安定性などの品質特性を洗い出す
2. **リスクの特定** — 特定した品質特性に影響を与えるリスクを以下の手法で発見する
3. **優先順位付け** — 発生確率 × 深刻度でリスクに優先順位を付ける

**リスク特定手法**:

| 手法 | 概要 |
|------|------|
| ヘッドラインゲーム | 架空の悪い見出し記事を考え、その原因となるリスクを逆算する |
| オブリーク・テスティング | 1つ星レビューカードをきっかけに、ユーザーが不満を感じるシナリオを想像する |
| リスクストーミング | TestSphereカードを使い、品質特性ごとにリスクをチームでブレインストーミングする |

### 1.2 テストピラミッドにおける API テストの位置づけ

- **ユニットテスト** — 個々のロジックを高速にテスト（APIを介してテストするケースはここに落とす）
- **API統合テスト** — APIのエンドポイント動作を直接テスト（APIをテストするケース）
- **E2Eテスト** — ユーザーフロー全体を通したテスト

**TaTTa 判断基準**:「APIをテストするのか、APIを介してテストするのか」を問う。税額計算のようなビジネスロジックはAPIを介したテスト → ユニットテストへ。ステータスコード検証はAPIをテスト → 統合テストへ。

---

## 2. API 設計テスト

コードを書く前の設計段階でテストする。チームの共通理解を築き、早期にイシューを発見する。

### 2.1 5W1H による問い立て

```
Who（誰が）     — 誰がこのAPIを使うか、誰にアクセスを許可するか
What（何を）    — 誤った値を送ったら何が起きるか、What if で仮定を問う
Where（どこで） — データはどこに保存されるか、どこで使われるか
When（いつ）    — バージョン変更のタイミング、本番稼働時の挙動
Why（なぜ）     — なぜこの設計判断をしたのか、なぜこのデータ型か
How（どのように）— どのような仕組みで動くか、どのようにテストするか
```

**問いを深める追加テクニック**:
- **else** — 「ほかに誰が使うか？」「ほかに何が起きるか？」と水平思考を広げる
- **ファネルクエスチョン** — 答えに対してさらに深く掘り下げる問いを続ける
- **データ型分析** — 整数型に浮動小数点数を送ったら、境界値（0以下）を送ったら何が起きるか

### 2.2 OpenAPI / Swagger による設計ドキュメント

OpenAPI 3スキーマを使って設計を可視化し、思い込みを排除する：

```yaml
openapi: 3.0.0
info:
  title: Booking API
  version: 1.0.0
paths:
  /booking/:
    post:
      parameters:
        - in: cookie
          name: token
          required: true
          schema:
            type: string
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
        bookingdates:
          type: object
      required:
        - roomid
        - firstname
        - bookingdates
```

**OpenAPI 活用ツール**:
- **Swagger UI** — 対話的なAPIドキュメントを生成し、リクエストを送って動作確認できる
- **Swagger Codegen** — 設計ドキュメントからスタブコードを生成できる

### 2.3 チームへの導入方法

- **スリーアミーゴスセッション** — テスター・開発者・プロダクトオーナーが集まり、新機能を実装前に議論する
- **ペアリング** — 実装前に2人でアイデアをテストする
- **スプリントプランニングへの組み込み** — 既存のセレモニーでAPI設計テストを実施する

---

## 3. API 探索テスト

目的を持ち、チャーターに基づいて構造化された探索テストを実施する。

### 3.1 テストチャーターの作り方

チャーターはセッションの目的・範囲・アプローチを定義する。

```
探索する: [テスト対象のAPIエンドポイントや機能]
以下の観点で: [使用するヒューリスティクスや確認軸]
以下を発見するために: [期待する学習内容やリスク]
```

**チャーター例**:
```
探索する: POST /booking/ エンドポイント
以下の観点で: 異常値・境界値の入力パターン
以下を発見するために: バリデーションエラーの挙動と適切なエラーメッセージの確認
```

### 3.2 探索テストで活用するヒューリスティクス

| ヒューリスティクス | 活用シーン |
|------------------|-----------|
| BINMEN (Boundaries, Invalid data, Null, Method, Encoding, Number) | 入力値のテストアイデア生成 |
| POISED (Parameters, Output, Interoperability, Security, Exceptions, Data) | APIの多面的なリスク探索 |
| Test Heuristic Cheat Sheet | データ型別のテストアイデア |

### 3.3 探索セッションの記録と共有

- **ノート** — セッション中に発見したこと・立てた問い・バグを記録する
- **バグレポート** — 再現手順・期待動作・実際の動作を明確に記録する
- **レトロスペクティブ** — セッション後にチームで学んだことを共有する

---

## 4. API テスト自動化

### 4.1 自動化対象の選択原則

- **リスクを尺度に** — コードカバレッジではなく、特定したリスクの優先順位順に自動化する
- **変化検出器として使う** — 自動チェックはシステムの変化を検出するためのもの。変化の意味の解釈は人間が行う
- **過剰な期待を避ける** — 自動チェックは設定した通りにしか動かない。探索的な観察は人間が担う

### 4.2 API 自動チェックの設計パターン

3層構造でフレームワークを構築する：

```
checks/     — テストの意図とアサーションを記述（読みやすさを最優先）
requests/   — APIごとのHTTPリクエストをメソッドとして抽象化
payloads/   — リクエスト/レスポンスのデータモデル（POJO等）
```

**チェック実装例（REST Assured + JUnit 5）**:

```java
@Test
void getBookings_shouldReturn200() {
    Response response = BookingRequests.getAll();

    int actual = response.statusCode();
    int expected = 200;

    assertThat(actual).isEqualTo(expected);
}
```

```java
// requests/BookingRequests.java
public class BookingRequests {
    private static final String BASE_URL = "https://api.example.com";

    public static Response getAll() {
        return RestAssured.given()
            .accept(ContentType.JSON)
            .when()
            .get(BASE_URL + "/booking/");
    }

    public static Response create(Booking payload) {
        return RestAssured.given()
            .contentType(ContentType.JSON)
            .body(payload)
            .when()
            .post(BASE_URL + "/booking/");
    }
}
```

### 4.3 ATDD（受け入れテスト駆動開発）

ビジネス要件を Given-When-Then 形式で表現し、自動チェックに変換する：

```gherkin
Feature: Booking reports

  Scenario: User requests total earnings of all bookings
    Given I have multiple bookings
    When I ask for a report on my total earnings
    Then I will receive a total amount based on all my bookings
```

**ATDD の進め方**:
1. ビジネスサイドとの対話から受け入れ基準を Gherkin で定義
2. 失敗する自動チェックを作成（ステップ定義の実装）
3. チェックが通るまで本番コードを実装
4. コードのリファクタリング

### 4.4 API モッキング

依存する外部APIをモックして、テストの独立性と安定性を確保する：

```java
// WireMock を使ったモック例
stubFor(post(urlEqualTo("/message/"))
    .willReturn(aResponse()
        .withStatus(201)
        .withHeader("Content-Type", "application/json")
        .withBody("{\"id\": 1}")));
```

**モックを使う場面**:
- 依存するAPIがまだ開発中の場合
- 外部APIのエラーシナリオを再現したい場合
- コントラクトテストのコンシューマ側検証

### 4.5 CI/CD パイプライン統合

```yaml
# GitHub Actions 例
- name: Run API Integration Tests
  run: mvn test -Dtest="*IT"
  env:
    API_BASE_URL: ${{ secrets.API_BASE_URL }}
```

**パイプライン統合パターン**:
- **コードベース統合型** — アプリコードと同じリポジトリにテストを配置。デプロイ前に実行
- **コードベース分割型** — テスト専用リポジトリを用意。複数のAPIをまたがるシナリオに適する

---

## 5. テスト戦略の確立と実現

### 5.1 コンテキストに合った戦略

すべてのリスクをテストすることは不可能。以下の判断軸で優先するアクティビティを選ぶ：

| 判断軸 | 内容 |
|--------|------|
| 品質特性の優先度 | ユーザーにとって何が最重要か |
| リスクの発生確率 | そのリスクが実際に起きる可能性 |
| リスクの深刻度 | 起きた場合のダメージの大きさ |
| テスタビリティ | そのリスクのテストがどれだけ困難か |

### 5.2 テスト計画の要素

- **テスト環境** — 本番相当の環境をどのように用意するか
- **テストデータ** — 必要なデータセットを事前に用意する手順
- **実行頻度** — 毎コミット・日次・リリース前など
- **フィードバックループ** — テスト結果を誰がいつレビューするか
- **テスト戦略の更新** — 定期的に品質特性・リスクを見直し、戦略を進化させる

---

## 参照

- コントラクトテスト（Pact）: `references/CONTRACT-TESTING.md`
- パフォーマンス・セキュリティ・本番テスト: `references/PERFORMANCE-SECURITY.md`
