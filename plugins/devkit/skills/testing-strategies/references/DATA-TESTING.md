# データ層テスト

アプリケーションの信頼はデータ整合性の上に成り立つ。残高が反映されない送金、消えた投稿、二重に引き当てられた在庫——データ不整合はユーザー離脱と信用失墜に直結する。UI・API 経由の機能テストだけではデータ層の欠陥を取りこぼすため、ストレージ・処理系（RDB・キャッシュ・バッチ処理・イベントストリーム）それぞれの特性に応じたテスト戦略と、SQL / JDBC / data contract / ストリームテスト等の専用ツールが必要になる。本リファレンスはその要点をパターン・チェックリスト・判断基準として整理する。

## 機能テストとの関係

| 観点 | 機能テスト | データ層テスト |
|------|-----------|---------------|
| 発想の起点 | ユーザーが取りうる操作 | 起こりうる障害・不整合（テストケースの約9割は障害系） |
| 検証経路 | UI / API | ストレージ・処理系を直接検証（SQL、コンシューマ、契約スキャン） |
| 主な脅威 | 仕様逸脱 | 並行性・分散・非同期通信・ネットワーク障害による破損 |

原則: **データ層テストを終えるまで機能テストは完了しない**。同じ機能でも「データがどこをどう流れるか」で追跡し直すと新しいテストケースが見つかる。障害はまれだと楽観せず、起こりにくい障害も含めてテスト環境で人工的に再現して挙動を確かめる姿勢が基本になる。

## データ層の構成要素と役割

典型的な Web/モバイルアプリのデータ系は次の4系統で構成される（例: EC アプリ）。

| 系統 | 役割 | 特性 | 例 |
|------|------|------|-----|
| RDB（中央データベース） | 業務データの永続化・CRUD | 耐久性（ディスク書込）・スキーマ・SQL | PostgreSQL, MySQL |
| キャッシュ | 高頻度アクセスの短命データをメモリ保持 | サブミリ秒応答・TTL・耐久性は低い | Redis, Memcached |
| バッチ処理 | 蓄積した入力をまとめて変換（非リアルタイム） | 大容量・スケジュール実行・再実行前提 | Spring Batch, Apache Spark |
| イベントストリーム | 準リアルタイムの非同期イベント連携 | pub/sub・保持期間・耐久性あり | Apache Kafka, RabbitMQ, Cloud Pub/Sub |

データフローの典型例: 認証サービスがアクセストークンをキャッシュへ保存 → 注文サービスがトークン検証後に RDB へ注文作成 → 注文イベントをストリームへ発行 → 倉庫・配送などの下流システムが購読して処理 → ベンダーのカタログファイルは夜間バッチが RDB へ取込。

---

## 1. RDB のテスト

### 基本テストケース

- [ ] UI から入力した情報が正しいテーブルに保存され、関連（外部キー・UUID）が張られる（正常系）
- [ ] 列のデータ型・最大長に基づく境界値: DB 制約（例: varchar(20)）と UI 側バリデーションが一致し、超過時に適切なエラーを表示する
- [ ] SQL 構文を含む入力: アポストロフィを含む氏名（O'Brien 等）が正しく保存されるか。エスケープ/サニタイズの要否
- [ ] 書込途中のネットワーク断: 関連テーブルへの部分書込が起きないか。複数サービスにまたがる書込とリトライの相互作用
- [ ] DB 操作のタイムアウトとリトライ時のユーザー体験

### 並行性（レースコンディション）のテストケース

| パターン | 症状の例 |
|---------|---------|
| Lost update | 2ユーザーが同一商品を同時購入 → 在庫が1しか減らない |
| 部分更新の読取 | 「在庫ありフラグ更新」と「数量更新」の間を読む → 在庫あり・数量0 に見える |
| 共有資源の競合 | 最後の1点を同時購入 → 商品は A に引当、請求書は B に発行 |
| 性能限界 | 並行アクセスは性能上限を規定 → 実運用相当のデータ量での負荷テストが必須 |

落とし穴: 並行性バグはタイミング依存でテスト実行では再現しにくい。**テストで検出するより、分析フェーズで洗い出して設計段階で予防する**のが現実的。

### レプリケーションと結果整合性

読み取りスケールや地理分散のためにレプリカ（リーダー/フォロワー）を置くと、フォロワーへの反映遅延（replication lag）が生じ、一定時間後に一致する「結果整合性」モデルになる。SNS のタイムライン程度なら許容できるが、次の症状はユーザーの信頼を毀損しうる。

| 症状 | 内容 |
|------|------|
| Read-your-own-writes 違反 | プロフィール更新直後に遅延フォロワーから読み、古い情報が見える → 再入力の悪循環で負荷増大 |
| 時間旅行（moving backward） | リロードのたびに異なるフォロワーから読み、スコアが進んだり戻ったりする |
| 順序不整合 | 質問より先に回答コメントが表示される（因果順序の崩れ） |
| 書込競合 | マルチリーダー構成で別リーダーが別の編集を受理 → マージ時に競合 |

多くの DBMS はこれらへの定石対策を内蔵しているが、アプリ側でどの整合性保証に依存しているかを把握し、テスト観点として維持する。整合性モデルの分類は Jepsen の公開ガイド（https://jepsen.io/consistency）が参考になる。

---

## 2. キャッシュのテスト

### 設計前提

- キャッシュに置くのは「短命かつ高頻度アクセス」のデータのみ（例: アクセストークン）。全損しても再ログイン程度で復旧できるものが適する
- DB とキャッシュに同一データを複製する構成では、同期・パージ・キャッシュ障害時の DB フォールバックをアプリコードが担う → そのライフサイクル自体がテスト対象

### テストケース

- [ ] TTL 満了後の挙動: 期限切れトークンで 404 → ログイン画面へリダイレクトされるフロー
- [ ] TTL 満了後の再生成: 認証サービスが新トークンを発行しキャッシュへ格納する
- [ ] キャッシュが単一障害点になるケース: 全ユーザー強制ログアウト → 再ログイン導線の検証
- [ ] 分散キャッシュ（例: Redis Cluster）: インスタンス間リダイレクトを含めて機能フローが成立するか
- [ ] 最大負荷での性能テスト

---

## 3. バッチ処理のテスト

### 特性

- 性能指標は応答時間ではなく「どのサイズの入力を何時間で処理できるか」
- 入力はファイル・DB レコード・画像など多様。ベンダーごとにキー名やフォーマット（JSON/CSV）が異なる雑多なデータを共通構造へ変換するのが典型ユースケース
- 失敗時は再実行し、前回失敗分のデータを破棄/上書きするのが通例（冪等性）

### テストケース

- [ ] 入力ファイルが最後まで処理され、途中放棄がないこと
- [ ] 破損入力（予期しない null・巨大整数・異常値）のハンドリング
- [ ] 変換不能な不完全レコードのフラグ付けと隔離（quarantine）
- [ ] リトライ機構が失敗実行分のデータをクリーンアップ/上書きすること
- [ ] バッチ実行がオンライン系の性能を圧迫しないこと（実行時間帯・リソース分離）

### 落とし穴

| 罠 | 対策 |
|----|------|
| 新フォーマットのデータが届き始める | データ提供元から事前に複数サンプルを入手し、変換ロジック更新を計画 |
| data skew（特定カテゴリへの偏り） | 偏った入力での性能劣化を事前検証。パーティショニング戦略を確認 |

---

## 4. イベントストリームのテスト

### 特性

- publisher がトピックへイベントを発行し、subscriber が非同期に消費する「準リアルタイム」処理。発行側は下流の完了を待たない（ACK 不要）
- 削除ポリシーは製品で異なる: 全購読者の消費後に削除する系（RabbitMQ, Cloud Pub/Sub）と、保持期間経過後に削除する系（Kafka）。保持型は障害後のキャッチアップを可能にする
- バッチとの違いは時間軸: バッチは「所定時刻以降にまとめて」、ストリームは「発生直後にほぼ即時」

### テストケース

- [ ] イベント構造は publisher/subscriber 間の契約 → 構造変更時は機能フロー全体を再テスト
- [ ] 新旧イベント構造の後方互換性
- [ ] 順序依存の処理（例: 倉庫の在庫確認前に出荷できない）が非同期でも成立すること
- [ ] 障害復旧後、subscriber が正しい順序で未消費イベントに追いつけること
- [ ] リトライ上限超過イベントが dead letter queue へ移動し、エラー詳細が付与されること
- [ ] ストリーム自体のダウン時: publisher/subscriber のリトライ戦略（いつ・どう再試行するか）
- [ ] subscriber の消費速度が publisher より遅い場合の滞留（bloat）と消費追従性

---

## データ層テスト戦略（4本柱）

| 柱 | 要点 |
|----|------|
| 手動探索的テスト | 障害系ケースの発見に最も有効。SQL・API テストツールを使い、使用プロダクト（Kafka, Redis 等）固有の特性を学んで探索観点を導く |
| 自動機能テスト | ユニット・統合テストを厚い土台にし、UI/API 層は薄く。CI に組み込み高速フィードバック。データ集約型アプリではデータ品質チェックも CI に追加 |
| 性能テスト | データ系はアプリ全体性能を左右する重要コンポーネント → 全系統に負荷・ストレステスト |
| セキュリティ・プライバシーテスト | データ漏えいは重い損失・罰則に直結。国・地域のデータ保護法制への準拠検証も含める |

横断観点: **データ型とバリエーション／並行性／分散性／ネットワーク障害**。タイミング依存のケース（特に並行性）はテストで暴けないことがあるため、分析フェーズでの議論を欠かさない。

---

## SQL による手動検証

DB を含むアプリのテストでは SQL は必須スキル。AI アシスタントに生成させたクエリをレビューするためにも、頻出構文の理解が要る。

### 頻出クエリ・チートシート（PostgreSQL 例）

```sql
-- テーブル作成（型・最大長が境界値テストの根拠になる）
CREATE TABLE items (item_sku varchar(10), color varchar(3),
                    size varchar(3), price int);

-- 挿入（型・長さ違反は失敗する → それ自体が制約の検証になる）
INSERT INTO items VALUES ('ABCD0001', 'Blk', 'S', 200),
                         ('ABCD0002', 'Yel', 'M', 200);

-- 読取・絞り込み
SELECT * FROM items;
SELECT item_sku, size FROM items LIMIT 3;
SELECT color FROM items WHERE size = 'S';

-- 集約（GROUP BY / HAVING は集約後の絞り込み）
SELECT color, count(*) FROM items WHERE size = 'S'
GROUP BY color HAVING count(*) > 1;

-- ソート（複数キー・昇順降順の混在可）
SELECT * FROM items ORDER BY price ASC, size DESC;

-- 集約関数・論理演算・式・述語
SELECT * FROM items WHERE size = 'S' AND color = 'Blk';
SELECT * FROM items WHERE price = 100 + 50 AND color IS NOT NULL;
-- sum() / avg() / min() / max() は count() と同様に使える

-- ネストした副問合せ
SELECT count(*), (SELECT avg(price) FROM items) FROM items;

-- 結合（テーブル間の関連検証に必須）
SELECT * FROM orders o INNER JOIN items i ON o.item_sku = i.item_sku;

-- 更新・削除
UPDATE items SET color = 'BK' WHERE color = 'Blk';
DELETE FROM items WHERE price = 180;
```

### JOIN の使い分け

| 種類 | 返す行 | 不一致行の扱い |
|------|--------|---------------|
| INNER JOIN | 両表に一致がある行のみ | 除外 |
| LEFT JOIN | 左表の全行＋右表の一致行 | 右側列を NULL 埋め |
| RIGHT JOIN | 右表の全行＋左表の一致行 | 左側列を NULL 埋め |
| FULL OUTER JOIN | 両表の全行 | 不一致側を NULL 埋め |

補足: SQL キーワードは大文字小文字を区別しない。`psql` では `\l`（DB 一覧）・`\dt`（テーブル一覧）が調査に便利。GUI が必要なら pgAdmin。

### AI 支援によるテストデータ生成

テーブルスキーマと値域をプロンプトに含めれば、AI アシスタントに大量の INSERT スクリプトを生成させられる。

```text
EC アプリの items テーブル用に 50 件のテストデータが必要。
スキーマ: items (item_sku varchar(10), color varchar(3), size varchar(3), price int)
値域: item_sku は ABC0001〜ABC20000、color は RED/BLUE/GREEN、
size は M/L/S/XS/XXL、price は 5〜50。
PostgreSQL 用の INSERT スクリプトを生成して。
```

要点: **関連テーブル（orders.item_sku は items に存在する値のみ）を作るときは、両方のスキーマと参照整合性の条件を明示する**。

---

## JDBC による DB 検証の自動化

JDBC は Java から RDB へ接続して SQL を実行する API 群。UI/API 自動テストスイートに組み込み、DB のレコードを直接アサートできる。

### 使いどころの判断基準

| 状況 | 推奨 |
|------|------|
| 通常の DB 検証 | ユニット・統合テストとして実装（UI/API テストにしない） |
| テストデータ作成 | アプリの API 経由が原則（スキーマ変更に強い。API 契約は滅多に変わらない） |
| 下流がレガシーで API がない | DB 直結が唯一の選択肢（例: 注文作成後、配送システムの DB を直接検証） |

### 最小コード

```java
// 接続
Connection connection = DriverManager.getConnection(
    "jdbc:postgresql://localhost/postgres", "user", "password");

// クエリ実行
Statement statement = connection.createStatement();
ResultSet results = statement.executeQuery(
    "select * from orders where order_id='PR125'");
while (results.next()) {
    assertEquals(results.getString("quantity"), "1");
    assertEquals(results.getString("item_sku"), "ABCD0006");
}

// 後始末
results.close();
statement.close();
```

手順の要点: ①DB ベンダーの JDBC ドライバを依存に追加（Maven 等） ②テストクラスで接続を `@BeforeTest`/`@AfterTest`（TestNG）や JUnit のライフサイクルで開閉 ③接続系メソッドは utils クラスへ抽出して再利用。

落とし穴: AI アシスタントに丸投げすると Spring Boot 等の過剰なセットアップへ脱線しがち。**「JDBC ドライバを直接使う」と明示的に方向付けし、段階的にプロンプトする**。

---

## Data Contract CLI によるデータ契約テスト

外部から届くデータ（ベンダーのカタログファイル等）には古い値・null・キー欠落が混入し、バッチ取込後に DB とアプリを汚染する。フィールド単位の品質期待を「データ契約」として YAML（Open Data Contract 系仕様）で定義し、実データをスキャンして違反を検出するのが Data Contract CLI（https://datacontract.com 参照）。CLI 実行のほか CI/CD の自動テストとしても回せる。

### セットアップと実行

```bash
docker pull datacontract/cli
alias datacontract='docker run --rm -v "${PWD}:/home/datacontract" datacontract/cli:latest'
datacontract test ./items_odcs.yaml
```

### 契約定義の骨子（YAML）

```yaml
dataContractSpecification: 1.2.1
id: items-data-contract
servers:
  postgres:
    type: postgres
    host: localhost
    port: 5432
    database: postgres
    schema: public
models:
  items:
    type: table
    fields:
      item_sku:
        type: varchar
        required: true
        unique: true        # 一意性を契約化
      price:
        type: integer       # 範囲・regex 等の品質条件も定義可能
```

実行すると契約の各チェックが実データに対して pass/fail で報告される。値の範囲制約・他フィールドとの整合・regex パターンも定義できる。

### 関連ツールの使い分け

| ツール | 位置づけ |
|--------|---------|
| Data Contract CLI | 宣言的 YAML 契約＋CLI/CI スキャン。契約テストの入口 |
| Deequ | Spark 上のプログラマブルなデータ品質ユニットテスト。バッチ処理の前後で実行し、要件を満たさぬレコードを隔離。品質メトリクス・異常検知・検証候補の自動提案も持つ |
| GX Core | プログラマブルなデータ品質検証フレームワーク |
| Soda 等の AI 品質プラットフォーム | 本番データの ML ベース可観測性・自動異常検知まで拡張したい場合 |

Deequ の検証例（バッチ入力ファイルの事前検証）:

```scala
VerificationSuite().onData(data).addCheck(
  Check(CheckLevel.Error, "vendor file checks")
    .hasSize(_ > 100000)
    .isComplete("item_sku")            // NULL 禁止
    .isUnique("item_sku")              // 重複禁止
    .isContainedIn("size", Array("S", "M", "L", "XL"))
    .isNonNegative("price")
).run()
```

---

## Kafka のテスト（Zerocode）

### Kafka の基礎概念（テスト観点で押さえる用語）

| 用語 | 意味 | テストへの含意 |
|------|------|---------------|
| Message | イベントの単位。ディスクに書かれ耐久性を持つ | 内容・構造のアサート対象 |
| Topic | メッセージの論理分類名 | 発行先/購読元の指定に使う |
| Partition | トピック内の分割単位。追記型で順序を保持 | 順序保証が必要な処理はキー（例: 顧客 ID）で同一パーティションへ誘導されているか検証 |
| Offset | メッセージ毎の単調増加番号 | 障害後の再開位置・message replaying（過去分の再消費）の検証に使う |
| Broker | 仲介サーバ。オフセット付与・格納・配信を担う | テスト環境の接続先 |
| Schema / Schema Registry | producer/consumer 間のデータ構造契約と、その版管理・互換性チェック機構 | スキーマ進化時の前方/後方互換テスト |
| Retention | 保持期間（既定 7 日またはパーティション 1 GB 到達まで、メッセージ単位で設定可） | 遅延 consumer のキャッチアップ可否に影響 |

### テスト戦略

- 最適な層は**ユニットテスト**。エンドツーエンドのイベント連携は API テストで代替できる（例: 注文作成 API → 出荷処理の完了検証。準リアルタイムなので連結テストが成立する）
- サービスを分離してイベント自体を検証したいときに、以下の宣言的テストが有効

### Zerocode による宣言的テスト

Zerocode は REST/SOAP API と Kafka の自動テストを JSON/YAML の宣言で書けるツール。Kafka API 呼び出しやシリアライズ/デシリアライズを抽象化し、JUnit テストとして実行できる。

手順の要点:

1. Kafka＋Schema Registry を Docker Compose で起動（Zerocode の docker-factory リポジトリに構成ファイルがある）
2. Maven プロジェクトに `zerocode-tdd` と JUnit を依存追加
3. `src/main/resources` に broker/producer/consumer のプロパティファイルを配置（bootstrap servers・serializer/deserializer・`auto.offset.reset` 等）
4. テストケースを JSON で記述し、JUnit クラスへ配線

Producer テスト（発行＋ブローカー応答メタデータの検証）:

```json
{
  "scenarioName": "orders トピックへ注文メッセージを発行",
  "steps": [{
    "name": "produce order messages",
    "url": "kafka-topic:orders",
    "operation": "produce",
    "request": {
      "recordType": "JSON",
      "records": [{ "value": { "order_id": "PR125", "item_sku": "ABCD0006", "quantity": "1" } }]
    },
    "verify": {
      "status": "Ok",
      "recordMetadata": { "topicPartition": { "partition": 0, "topic": "orders" } }
    }
  }]
}
```

JUnit への配線:

```java
@TargetEnv("kafka_servers/broker.properties")   // ブローカー設定の場所
@RunWith(ZeroCodeUnitRunner.class)               // Zerocode と JUnit の結合
public class ProducerTest {
    @Test
    @JsonTestCase("testCases/orderMessages.json") // 実行する宣言的テスト
    public void verifyOrderMessageProduced() {}
}
```

Consumer テスト（同じ JSON の `steps` に追加）: `"operation": "consume"` で受信し、`assertions` で件数（`size`）と `records` の内容を検証する。offset・partition・key/value への検証も同じ宣言スタイルで追加できる。

デバッグ用にコンテナ内から直接消費して確認する:

```bash
docker exec -it <kafka_container> bash
kafka-console-consumer --bootstrap-server kafka:29092 --topic orders --from-beginning
```

---

## Testcontainers の使いどころ

Testcontainers は使い捨てのコンテナ化 DB/ミドルウェアをテスト実行時に起動するライブラリ。JUnit と統合でき、init スクリプトで初期状態を注入できる。

| 課題 | Testcontainers による解決 |
|------|--------------------------|
| ローカルに DB を建てる手間 | テストごとにフレッシュな DB インスタンスを起動・破棄 |
| 共有テスト環境 DB が開発で汚染されている | 毎回同一の安定状態から開始（テストの再現性） |
| DB 以外の依存（Kafka, RabbitMQ, ブラウザ等） | 1 行で各種コンテナを起動。カスタムコンテナも汎用 API で取込可 |
| ポータビリティテスト | 同一テストを MySQL/PostgreSQL/Cassandra/MongoDB 等に対して実行し、DB 差し替え可能性（製品要件になりうる）をユニット・統合テストで担保 |

```java
PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>(imageName);
postgres.start();   // テストセットアップで起動。JDBC URL を差し替えて接続
```

---

## チェックリスト（まとめ）

- [ ] 4系統（RDB・キャッシュ・バッチ・ストリーム）それぞれの固有テストケースを機能テストに追加したか
- [ ] データ型/バリエーション・並行性・分散性・ネットワーク障害の4横断観点を各系統で検討したか
- [ ] 並行性・レプリケーション起因のケースを分析フェーズで議論したか（テスト実行だけに頼らない）
- [ ] テストピラミッドはユニット・統合が厚く、UI/API 層は薄いか
- [ ] 外部由来データにデータ契約（YAML＋CI スキャン or Deequ 等）を適用したか
- [ ] 全データ系統に負荷・ストレステストを計画したか
- [ ] セキュリティ・プライバシー（法規制準拠含む）の検証を戦略に含めたか
- [ ] テストデータ作成は API 経由を優先し、DB 直結はレガシー下流等の必要時に限定したか
