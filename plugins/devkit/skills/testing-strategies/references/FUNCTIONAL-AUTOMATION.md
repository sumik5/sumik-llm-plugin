# 機能テスト自動化リファレンス

自動機能テストの設計と実装を、micro/macro のテストタイプ分類・テストピラミッド戦略・レイヤー別フレームワーク構築（Selenium WebDriver / Playwright / REST Assured / JUnit / Pact）・エージェント型テスト作成（agentic test authoring）・アンチパターン検出の観点で整理した実践リファレンス。自動テストは手動テストの置き換えではなく、手動の探索的テストで新しいテストケースを発見し、それを自動化して回帰テストに充てる、という役割分担が基本戦略となる。

---

## なぜ自動化するか（コストモデル）

| 状況 | 手動テストのコスト | 帰結 |
|------|------------------|------|
| 1機能 = 20ケース × 2分 | 40分/機能 | 機能追加ごとに回帰テストが線形増加 |
| 15機能到達時 | 約600分（10時間）/リリース | リリース遅延・回帰漏れ |
| サービスが2バージョン並存 | 約1,200分/リリース | バージョン数に比例して増加 |
| 人員増で並列化（12人） | それでも約100分 | 自動テストなら適切なレイヤー配置で1時間以内 |

- 手動テストはテストケース文書と実行の品質に依存し、ミスが混入しやすい。
- 深夜の緊急本番修正でも、自動テストがあれば人を集めずに検証できる。
- 自動テストの作成・維持コストは、「迅速かつ頻繁なデリバリー」「開発中・障害対応中の確信」という価値と天秤にかける。

---

## Micro / Macro テストタイプ

テストタイプは4つの特性で比較する: **スコープ**（検証範囲）・**目的**・**フィードバック速度**・**作成/維持の労力**。

| タイプ | 層 | スコープ | 主な書き手 | 速度 | 労力 | 置き場所 |
|--------|-----|---------|-----------|------|------|---------|
| Unit | micro | メソッド/クラス単位 | 開発者 | 最速 | 最小 | アプリのコードベース内 |
| Integration | micro | 統合ポイント（DB・キャッシュ・外部サービス等）の疎通 | 開発者 | 外部応答に依存 | 小 | アプリのコードベース内 |
| Contract | micro | 契約（スキーマ）構造のみ | 消費者チーム | 非常に速い | 小〜中（チーム間連携要） | アプリのコードベース内 |
| Service | macro | APIエンドポイント単位のドメインロジック | テスター中心 | UIテストより速い | 中（DBテストデータ設定要） | サービスコンポーネントと同居推奨 |
| UI functional | macro | 実ブラウザでの重要ユーザーフロー | テスター（開発者と共有可） | 遅い | 大（脆弱・全スタック依存） | 別コードベースが一般的 |
| End-to-end | macro | ダウンストリーム含む全ドメインワークフロー | テスター | 最遅 | 最大 | 少数に絞る |

### Unit テスト

- 最小単位の振る舞いを検証。基本的な入力バリデーションはこの層に置く。
- 例（`return_order_total(item_prices)` に対するケース設計）:
  - 割引による負値を含む価格リスト / 空リスト / 不正値（文字・記号）/ 通貨記号・桁区切りの違い（ローカライズ対応時）/ 小数の丸め
- TDD では失敗するテストを先に書き、通る最小限のコードを追加する。未テストロジックの混入を防ぐ。
- 代表フレームワーク: JUnit / TestNG / NUnit（バックエンド）、Jest / Mocha / Jasmine（フロントエンド）。
- ビルド段階・ローカルで実行され、shift-left の要となる。

### Integration テスト

- サービス・UI・DB・キャッシュ・ファイルシステム等、**実際の統合先**に対して疎通の正常系/異常系を検証する。
- 焦点は統合フローであり、詳細な E2E 機能ではない。理想的には unit テスト並みに小さく保つ。
- Unit と同じフレームワーク + 統合用ツール（例: JUnit + Spring Data JPA で DB 統合テスト）で書ける。

### Contract テスト

- 統合先も開発中（stub 利用）だと、**相手の契約変更に気づけない**まま壊れた契約の上に開発を続けるリスクがある。これが contract テストの主目的。
- stub を実際の契約と突き合わせ、**契約構造**を検証する（返却データの中身までは見ない）。スコープが小さいため高速。
- Postman や Pact でチーム横断のワークフローを自動化できる（Pact の詳細は後述）。

### Service テスト

- API を製品として、UI から独立して検証する。macro レベルのテストはここから始まる。
- サービスはビジネスルール・エラー基準・リトライ・データ保存などドメインロジックの本体。例:
  - 認証済みユーザーのみ注文を作成できる
  - 在庫がある場合のみ注文が作成される
  - 正常/異常入力に対して正しい HTTP ステータスコードが返る
- 全サービスの全エンドポイントに必要。ツール: REST Assured / Karate / Postman。

### UI functional テスト

- 実ブラウザでユーザー操作を模倣し、複数コンポーネント統合を検証。**重要ユーザーフローに限定**する。
- 下位レイヤーで検証済みの内容（例: 金額計算の組み合わせ）を再検証しない — 冗長で実行時間を増やすだけ。
- 全スタック（インフラ・ネットワーク）の安定性に依存するため brittle で、要素ID変更・ページロード遅延・環境障害など失敗要因が広い。

> UI テスト追加前の自問: ①このテストの目的は何か ②同じ目的を下位の micro テストで達成できないか。

### End-to-end テスト

- ダウンストリームシステムを含むドメインワークフロー全幅を検証（例: 注文後の倉庫システム連携まで）。
- 目的は「全コンポーネントが正しく繋がっているか」であり、各コンポーネントの機能検証ではない。**全コンポーネントを起動させる少数のテスト**で足りる。
- UI functional テストが文脈上 E2E を兼ねる場合も多い。兼ねない場合は UI・サービス・DB ツールを組み合わせて別途作成する。

---

## 自動化戦略

### テストピラミッド

- 原則: 「適切なレイヤーに適切なスコープのテストを置き、チームに最速のフィードバックを返す」。
- micro テストを広い土台とし、スコープが広がるにつれ macro テストの数を絞る（例: unit/integration 10x : service 5x : UI 1x）。
- スコープが大きいテストほど実行時間・作成/維持コストが増えるため。
- 実例: 200本超の UI 駆動 E2E（8時間実行・末尾で環境要因により失敗）をピラミッドへ再編し、約470テストを35分で完走させた事例がある。

### ピラミッドが成立しない場合

- 完全な E2E 環境の不在、特定機能（バーコードスキャン等）の自動化ツール不足、スキル不足などで理想形が組めないことはある。
- その場合もトレードオフを自覚し、**制約下で最速のフィードバックを返すテスト**を選ぶ。
- honeycomb / test trophy などの派生形もあるが、原則は同じ: micro テストは macro テストより書きやすく走らせやすい。形はスコープの取り方で変わるだけ。

### 自動化カバレッジの追跡

| プラクティス | 内容 |
|------------|------|
| 追跡は必須 | テスト管理ツール（TestRail）・PM ツール（Jira）・スプレッドシートいずれでもよいが必ず追跡する |
| バックログ化を防ぐ | 自動化をユーザーストーリーのスコープから外すと、フィードバック遅延→自動化スイートへの信頼低下の悪循環に陥る |
| Done の定義 | ストーリーの micro/macro テストを全て自動化して初めて「done」とする |

### 技術スタック選定の指針

- **開発スタックに揃える**: 開発と別スタックにすると開発者がテストの所有を嫌がり、shift-left と高速フィードバックを阻害する。
- **共通コードベースに寄せない**: テストは各レイヤーのコンポーネント内に置く。コンポーネント再利用時にテストも一緒に配布される。

---

## Selenium WebDriver フレームワーク（Java）

### 構成要素

| コンポーネント | 役割 |
|--------------|------|
| Apache Maven | ビルド自動化・依存管理（`pom.xml` に依存ライブラリとバージョンを宣言、中央リポジトリから取得しチーム全員が同一バイナリを使用） |
| TestNG | テストランナー（テスト作成・アサーション・setup/teardown・グループ化・実行・サマリー） |
| Selenium WebDriver | ブラウザ操作専用（アサーションやレポートは持たない → ランナー/ビルドツールと組み合わせて完成する） |
| Page Object Model | UI 自動化の標準デザインパターン（後述） |

- Maven 主要コマンド: `mvn compile`（コンパイル）/ `mvn clean`（成果物削除）/ `mvn test`（テスト実行）。
- TestNG 主要機能: `@Test`、`@BeforeMethod`/`@AfterMethod` 等のライフサイクル注釈、`assertEquals()`/`assertTrue()` 等。

### WebDriver の3要素

| 要素 | 内容 |
|------|------|
| API | ブラウザ内要素への操作メソッド群（click・型入力等） |
| Client library | 多言語で提供される API バンドル |
| Driver | ブラウザへ命令を伝える実体。各ブラウザベンダーが提供（Selenium 4.6+ は Selenium Manager が自動取得） |

### 要素特定と操作の要点

```java
driver.findElement(By.id("login"));            // ID（最優先・最も安定）
driver.findElement(By.cssSelector("#login"));  // CSS セレクター
driver.findElement(By.className("card"));      // クラス名
driver.findElements(By.cssSelector("#u li"));  // 複数要素
```

- **ID を最優先**する。CSS セレクター/XPath は UI 変更で壊れやすい。
- 相対ロケーター（`above`/`below`/`toLeftOf`）や `Actions` クラス（`dragAndDrop` 等）も利用可。
- ブラウザ制御: `driver.get(url)` / `navigate().back()` / `manage().window().setSize(...)` / `close()` / `quit()`。

### 待機戦略（hardcoded sleep 禁止）

| 戦略 | 挙動 |
|------|------|
| Implicit wait | DOM を最大 x 秒ポーリングして要素出現を待つ（デフォルト0秒・driver 初期化時に標準値を設定） |
| Explicit wait | 期待条件（`ExpectedConditions`）が真になるまで最大 x 秒待つ |
| Fluent wait | 最大 x 秒・y 秒間隔でポーリング、無視する例外も指定可 |

```java
driver.manage().timeouts().implicitlyWait(Duration.ofSeconds(10));

WebElement btn = new WebDriverWait(driver, Duration.ofSeconds(10))
    .until(ExpectedConditions.elementToBeClickable(By.id("submit")));
```

- 固定 sleep は環境ごとのロード時間差で fragile になるため使わない。

### Page Object Model（POM）

- アプリのページ構造をそのままフレームワーク内に再現する: **1ページ = 1クラス**、そのページの要素とアクションをクラスに定義。
- 抽象化とカプセル化により、UI 変更時の修正箇所が局所化される。

```java
public class LoginPage {
    private WebDriver driver;
    private By email    = By.id("user_email");
    private By password = By.id("user_password");
    private By signIn   = By.cssSelector("input.submit");

    public LoginPage(WebDriver driver) { this.driver = driver; }

    public HomePage login(String user, String pass) {
        driver.findElement(email).sendKeys(user);
        driver.findElement(password).sendKeys(pass);
        driver.findElement(signIn).click();
        return new HomePage(driver);   // ページ遷移 = 次ページのオブジェクトを返す（チェーン）
    }
}
```

- **アサーションはページクラスに書かない**（テストクラスの責務）。
- ベースクラス（`BaseTests`）に `@BeforeMethod` での driver 生成・implicit wait 設定・URL オープン、`@AfterMethod` での `driver.quit()` を集約する。
- テストクラスはベースを継承し、ページオブジェクト経由で操作 + アサート:

```java
public class LoginTest extends BaseTests {
    @Test
    public void verifySuccessfulLogin() {
        LoginPage loginPage = new LoginPage(driver);
        assertEquals(loginPage.login(user, pass).getTitle(), "Home page");
    }
}
```

- 実行: IDE から、または `mvn clean test`（Surefire プラグインが HTML レポートを `target/surefire-reports/` に生成）。
- CI での失敗デバッグ用に、teardown で `ITestResult.FAILURE` 判定 → `TakesScreenshot` でスクリーンショットを保存する。
- 拡張: TestNG のグループ/マルチブラウザ実行、Selenium Grid / TestNG 並列実行、Cucumber 等の BDD フレームワーク（Given/When/Then 形式でビジネス側と要件を共有）。ただし UI テストは最小限に保つ。

---

## Playwright フレームワーク（TypeScript）+ AI 支援構築

- Playwright は JavaScript/TypeScript 用。テストランナー・アサーション・並列化を1パッケージに内包するため、構成が Selenium より単純。
- Selenium は多言語対応で企業の既存資産が多く安定実績が長い。両方を扱えると有利。
- **初学者への推奨**: まず AI なしでフレームワークを一度組む（Java–Selenium など）。テストランナー・アサーション・依存管理というエコシステム理解が、AI 生成コードのレビューとデバッグに必須になる。

### AI アシスタントによるフレームワーク生成

- コーディングアシスタント（GitHub Copilot 等）に「TypeScript + Playwright の UI テスト自動化フレームワークを作成」と指示すると、以下が数分で生成される:
  - `package.json`（Playwright 依存）
  - `playwright.config.ts`（対象ブラウザ・並列実行・ベース URL 等の設定）
  - `/tests`（サンプル spec）・`/playwright-report`（HTML レポート）
  - `README.md`・`.gitignore`・カスタム指示ファイル
- 実行: `npx playwright test`。ページクラスは `/pages` に追加していく。
- **カスタム指示ファイル**でプロジェクト規約を固定する。例:

```
## MUST DO
- テストは相互に独立させる。setup は各テスト前のフックで行う
- test.step() に Given/When/Then の説明を付ける
- 日付は DD-MM-YY 形式のみ
- Arrange, Act, Assert (AAA) パターンで作成する
## AVOID
- ハードコードされた wait を使わない
- 既存テストを複製しない
- 指示なしに既存テストを変更しない
```

- IDE 拡張（ロケーターピッカー・テスト録画・失敗ログからのインライン修正提案）も活用価値が高い。

---

## エージェント型テスト作成（Agentic Test Authoring）

### ワークフロー（2段階が原則）

| 段階 | 内容 | ツール例 |
|------|------|---------|
| 1. テストケース生成 | チケット管理システム（Jira 等）から受入基準を MCP 経由で取得し、テストケース一覧を生成 | Atlassian MCP + プロンプトファイル |
| 2. テストコード生成 | 選別したケースのみ、ブラウザ自動化 MCP で実アプリを操作しロケーターを取得 → コード生成 → POM リファクタ → パスするまでループ | Playwright MCP + コード生成ツール |

- **2段階に分ける理由**: 生成されたケースから「どのケースをどのレイヤーで自動化するか」を人間が能動的に選ぶため。全件を UI テスト化する事故を防ぐ。
- プロンプトファイル（mode・description・手順を記述した Markdown）はリポジトリにコミットし、チームで再利用・改善・バージョン管理する。
- 許可ツール一覧をプロンプトファイルに明記すると、実行中の許可確認を減らせる。

### テストコード生成プロンプトの手順例

```
Step-1: ブラウザ自動化 MCP でサイトを開き、シナリオを1ステップずつ操作する
Step-2: 各ステップの要素ロケーターを取得する
Step-3: コード生成ツールでテストコードを生成する
Step-4: 既存の関連テストファイルに追加、なければ新規作成する
Step-5: Page Object Model に沿ってリファクタリングする
Step-6: テストがパスするまでループする
```

### Skill / Custom Agent の使い分け

| 構造 | 用途 | 例 |
|------|------|-----|
| カスタム指示 | プロジェクト全体の規約 | AAA パターン強制・wait 禁止 |
| プロンプトファイル | 軽量な定型ワークフロー | ケース生成・コード生成 |
| Skill | 深い専門知識・ドメイン知識の注入（just-in-time ロード） | 安定ロケーター選定基準 |
| Custom agent | 広いプロセス自動化・専門ロール（計画/生成/修復） | test-planner / test-generator / test-healer |

- Playwright は計画・生成・修復のカスタムエージェント一式を提供する: `npx playwright init-agents --loop=<IDE>` で導入し、①planner にサイト URL を渡してテスト計画 Markdown を生成 → ②generator でコード化 → ③healer で失敗テストを修復、と繋ぐ。
- Skill ファイルの例（ページオブジェクト生成規則）:

```
## MUST DO
- ページオブジェクトには要素ロケーターとアクション（get/set/click 等）を持たせる
- 必ずブラウザ自動化 MCP で実アプリを探索して正しいロケーターを特定する
- ロケーターは ID または role を最優先にする
## AVOID
- ページクラスにアサーションを書かない
- 承認なしに XPath / CSS ロケーターを使わない
- ロケーターを推測しない。見つからなければ実行を止めて通知する
```

### フレームワーク進化の指針

- **agent は広いプロセス自動化、skill は深い規律・ドメイン知識**に使う。定義は意味のある階層に整理し、重複する skill は description で明確に区別、agent の指示から skill を明示参照する。
- 指示ファイルは長文化させない。長すぎると指示が読み飛ばされる傾向がある。少数のモジュール化された skill のほうが単一の網羅的 skill より性能が出るという研究報告もある。
- skill を書くのは「初期プロンプトを超えて AI を誘導する必要が生じたとき」。会話後に AI 自身へ「この会話を skill として抽象化して」と頼むのも有効。モデル更新で skill が陳腐化するため継続的メンテナンスが要る。
- **ハルシネーション対策**: ドメイン文脈を補助ドキュメントとして skill に添付する。ドメイン用語の誤解と操作コストを減らせる。
- **セキュリティ**: オープンソースの agent / skill は脆弱性を含み得る（大規模調査で公開 skill の約26%に少なくとも1件の脆弱性が報告されている）。導入前に精査する。
- **AIコスト**: skill は just-in-time ロードでトークン効率が良い。計画は高性能モデル・実行は軽量モデルに振り分ける。コード変更前に計画承認を挟む。コストを日次監視する。

### 注意点（レビューは必須）

- 「テストが通った」ことは受け入れの証明にならない: 生成コードが既存テストに影響する、ロケーターが不安定、既存テストと重複、といったリスクが常にある。
- **1テストずつ生成して丁寧にレビュー**する。ロケーター特定やユーザージャーニー完走で AI が詰まることは日常的にあるため、運転席に座り続けてプロンプトで誘導する。
- コーディングアシスタントは公開リポジトリで学習されており、生成コードが著作権保護対象である可能性がゼロではない。無償プランは IP 補償（indemnity）を含まないことが多い。プロプライエタリコードで使う前に自社の情報セキュリティ規程を確認する。

---

## サービステスト（REST Assured）

- REST Assured は REST API 自動テストの定番 Java ライブラリ。Given/When/Then 構文の DSL と hamcrest マッチャーを提供し、JUnit / TestNG いずれとも組める。公式: https://rest-assured.io
- フレームワークの3点セットは UI と同じ: 依存管理（Maven）+ テスト対象ライブラリ（REST Assured）+ テストランナー（TestNG）。

```java
@Test
public void verifyGetItemsReturnsSuccess() {
    given().
    when().
        get("http://localhost:1000/items/984058981").
    then().
        assertThat().statusCode(200);
}
```

- POST の JSON ボディは、生文字列でなく **dataObject クラス + JSON シリアライズライブラリ**（jackson-databind 等）で組むのがクリーン:

```java
@JsonPropertyOrder({"sku", "color", "size"})
public class ItemDetails {
    private String sku; private String color; private String size;
    // コンストラクタ + @JsonProperty 付き getter
}

@Test
public void verifyPostItemsReturnsCreated() {
    ItemDetails item = new ItemDetails("98765490", "Green", "M");
    given().contentType(ContentType.JSON).body(item).log().body().
    when().post("http://localhost:1000/items").
    then().assertThat().statusCode(201);
}
```

- `log().body()` でシリアライズ結果を確認できる。レスポンスボディの特定フィールド抽出・アサートも DSL で可能。
- 開発中エンドポイントは stub ツール（WireMock 等）でローカルに立てて練習・並行開発できる。

### OpenAPI 仕様からのエージェント生成

1. `/api-specs` フォルダに OpenAPI 仕様（YAML）を置く。
2. エージェント型コーディングツールで「/api-specs 配下の OpenAPI 仕様から REST Assured テストを生成するエージェント」を自然言語で定義させる（詳細な手順書 Markdown が自動生成される）。
3. エージェントに生成を指示 → 正常系（境界値含む・200 検証）と異常系（欠損フィールド・不正型・400 検証）のテスト一式が出力される。

**レビュー観点**:
- 入力バリデーション系テストは通常 **unit テスト層に置くべき**であり、API テスト層に混ぜない → エージェント指示を調整する。
- テストデータ・日付フィールド・認証トークン・検証すべきレスポンスフィールドなどプロジェクト固有文脈は指示に追記する。動く指示セットはリポジトリにコミットして共有する。
- 生成されたケースに加え、**プロジェクト知識に基づく新ケースを人間が考え続ける**必要がある。
- 手動テスターのみのチームでは、Postman コレクション → REST Assured テスト変換のエージェントワークフローも有効。

### レビュアーエージェント（LLM-as-judge）

- テストを一括生成する場合、人間レビューを AI レビュアーで補強する。生成に使ったのと**別の高性能モデル**に、初期プロンプト・出力・模範例を渡し、0〜1 でスコアリングさせる:

| 基準 | 問い |
|------|------|
| Coverage | OpenAPI 仕様の全エンドポイントをカバーしたか |
| Hallucination | 幻覚テストケースはないか |
| Syntax | 構文と DSL は正しいか |
| Quality | ケースは網羅的か |

- 閾値（例: 0.7）未満ならギャップの修正まで指示できる。

---

## Unit テスト（JUnit）

- unit テストのフレームワークはアプリの言語に合わせる（Java: JUnit/TestNG、.NET: NUnit、JS: Jest/Mocha、Ruby: RSpec）。
- 書き手は開発者だが、**テスターも基本構造を理解**しておくとテスト戦略全体を賢く設計できる。
- JUnit の基本機能: `@Test`、`@BeforeEach`/`@BeforeAll`/`@AfterEach`/`@AfterAll`、`@DisplayName`（可読なテスト名）、`@Tag("smoke")`（サブセット実行）、`assertTrue()`/`assertEquals()`/`assertAll()`/`assertThrows()`。

```java
@DisplayName("When managing new customers")
public class CustomerManagementTests {

    @Test
    @DisplayName("should return empty when there are no customers")
    public void shouldReturnEmptyWhenThereAreNoCustomers() {
        CustomerManagement customer = new CustomerManagement();
        assertTrue(customer.getCustomers().isEmpty());
    }

    @Test
    @DisplayName("should throw exception when customer name is invalid")
    public void shouldThrowExceptionForInvalidInput() {
        CustomerManagement customer = new CustomerManagement();
        assertThrows(IllegalArgumentException.class,
            () -> customer.addCustomers(List.of("", "Jackson", "20")));
    }
}
```

- モック（Mockito）やアプリフレームワーク機能を使って DB 等の外部システムへ実アクセスするようになった時点で、それは integration テストである。

---

## 良いテストの特性（全タイプ共通）

- [ ] **可読**: メソッド名・変数名が意図を表す。AAA（Arrange, Act, Assert）パターンに従う
- [ ] **単一の振る舞い**のみ検証: 高速で、失敗時に意図が明確
- [ ] **相互に独立**: チェーンされたテストはチェーンされたエラーを生む。テストごとの setup/teardown で独立性と並列実行を担保
- [ ] **環境非依存**: 特定環境の静的データに依存しない
- [ ] **1コマンド実行**: チェックアウトして単一コマンドでビルド・実行できる（依存の手動管理不要）

これらを欠くテストはメンテナンス災害に変わる。

---

## Pact による消費者駆動契約テスト

- 公式: https://docs.pact.io （Java 中心に Python/JavaScript/Go/Scala 等をサポート）
- **consumer** = 情報を受け取る側（サービスや Web UI）、**provider** = 情報を提供する側。
- 複数の consumer が同一 provider から**それぞれ異なる属性**を必要とするため、契約は consumer 駆動で変化し得る → 各 consumer は「自分が依存する属性が壊れていないこと」を継続検証する仕組みが要る。
- 両者が並行開発中だと統合テスト/サービステストは書けない・書けても brittle で遅い。契約テストは E2E 統合テストを分割する:
  1. consumer は provider を stub 化して自機能の micro/macro テストを書く
  2. consumer は stub に対して契約テストを書き、provider がそれを継続実行する
  3. provider は自機能の micro/macro テストを書く

### Pact ワークフロー

| 手順 | 内容 |
|------|------|
| 1 | consumer チームが統合テストケースを列挙（正常応答・存在しない場合の空配列・不正リクエストのエラーコード等） |
| 2 | Pact でそれらの stub を作成 |
| 3 | stub に対する consumer 契約テストを書く（期待する属性のみアサート）→ 実行すると `.pact` ファイル（リクエストと期待属性の記録）が自動生成 |
| 4 | `.pact` を Pact Broker（OSS・両チームで運用）経由で provider へ自動受け渡し。マネージドサービスやフォルダ共有でも可 |
| 5 | provider 側は `.pact` を受け取り、`@State` でテストデータ状態を再現 → Pact が実サービスへ実リクエストを発行し応答を検証 |
| 6 | Broker が結果を consumer へ返し、フィードバックループが無人で完結 |
| 7 | 双方の Pact テストを CI に組み込み継続フィードバック |

### コードの骨格

```java
// Consumer 側: 契約の定義と検証
@Pact(consumer = "OrderService", provider = "PIMService")
RequestResponsePact getItems(PactDslWithProvider builder) {
    return builder.given("items are available")   // provider が再現すべき状態
        .uponReceiving("get item details")
        .method("GET").path("/items")
        .willRespondWith().status(200)
        .body(/* 期待する属性のみを型で記述 */)
        .toPact();
}

@Test
@PactTestFor(pactMethod = "getItems")
void getItemDetails(MockServer mockServer) {
    // mockServer = 上記契約どおりの stub。これに対して consumer コードを検証
}
```

```java
// Provider 側: .pact を受けて実サービスを検証
@Provider("PIMService")
@PactFolder("pacts")
public class ItemsPactProviderTest {
    @State("items are available")
    void setItemsAvailableState() { /* モックリポジトリ等で状態を再現 */ }

    @TestTemplate
    @ExtendWith(PactVerificationInvocationContextProvider.class)
    void verifyPact(PactVerificationContext context) { context.verifyInteraction(); }
}
```

- Pact テストはアプリコードと密結合で、アプリ側フレームワーク（Spring Boot 等）の知識が作成・デバッグに要る。エージェント型ワークフローでの生成も可能。HTML レポートを CI に統合できる。

---

## ReportPortal（テスト結果ダッシュボード）

- 公式: https://reportportal.io — オープンソースの AI 支援テスト自動化ダッシュボード。
- 大量のテストを毎晩回す体制では、失敗解析・原因分類・チーム間フォローが日単位の作業になりがち。エージェント生成でテスト数が急増するほど解析負荷も増える。
- 主要機能:

| 機能 | 内容 |
|------|------|
| 結果集約 | 言語の異なる複数テストスイートの実行結果を API で統合 |
| 自動トリアージ | 失敗ログを ML で解析し「プロダクト欠陥 / テストスクリプト問題 / 環境問題」の3分類に自動仕分け |
| 類似失敗のグルーピング | ログ類似性で失敗をまとめ解析時間を削減 |
| ダッシュボード | リリース単位・機能横断のカスタムビュー |
| Quality gate（有償） | 「既知の低優先度欠陥2件未満なら CI/CD を先へ進める」等のメトリクス定義 |

---

## その他の AI テストツール分類と採否基準

| カテゴリ | 特徴 | 留意点 |
|---------|------|--------|
| Prompts-as-tests（自然言語のテスト定義） | 実行のたびに LLM を呼び UI を操作。似たユーザージャーニーの複数ブランドサイトを1スイートで回すのに有効 | LLM は非決定的 → プロンプトの見落とし・ケース漏れリスク。実行ごとのモデル費用が発生（セルフホスト LLM で軽減可） |
| Spec-driven development | 仕様ファイルから AI が機能とテストを end-to-end で生成。要件変更時は spec 更新でテストも追随 | 「小さく漸進的に作る」より「精緻な文書の維持」に重心が移る、という批判もある |
| AI 駆動 API ワークフロー | Swagger/Postman コレクションから API テスト生成、OWASP Top 10 観点のセキュリティテスト、トラフィック録画からのテスト生成・契約テスト | プロジェクト固有のコレクション形式に対応するか確認 |
| E2E テストプラットフォーム | 3,000 以上のブラウザ/デバイスでの実行に加え、テスト作成・視覚/アクセシビリティ用モデル・失敗解析・修正提案 | 既に契約済みなら AI 機能を試す価値がある |

**採用前チェックリスト**:
- [ ] ツールのワークフローがチームの働き方に合うか（大きな変更を伴うなら change management 計画が先）
- [ ] プロジェクト固有の形式・文脈にカスタマイズできるか（できなければ自前エージェントの方がよい）
- [ ] AI 利用コストの内訳が明示されているか（会話が長くなるほどコンテキスト処理コストが増える点も含め）
- [ ] 深い AI 知識を要する特殊オーケストレーションはないか。演習レベルの自作ワークフローで代替できないか
- [ ] 大規模コードベースでの性能
- [ ] IP 補償の有無
- [ ] セキュリティ・プライバシー統制
- [ ] 良さそうなら**投資前にハンズオン実験**

---

## アンチパターン

### アイスクリームコーン（逆ピラミッド）

macro レベルの UI 駆動テストが多く、micro テストがほとんどない状態。

**症状チェック**:
- [ ] テスト実行のフィードバック待ちが長い
- [ ] 欠陥がサイクル後半（時にリリーステスト）まで見つからない
- [ ] 自動テストがあるのに大掛かりな手動テストが必要
- [ ] 「自動テストが正しい結果を出さない」という不満

**最初期の兆候**は「手動のストーリーテスト中に回帰欠陥が見つかる」こと。即座に根本原因分析を行い、問題が複利化する前にプラクティスを直す。

### カップケーキ（レイヤー間重複）

同じテストを複数レイヤーに重複させ、底も中間も上も太い形になる状態。開発者とテスターがサイロ化していると起きやすい（例: 開発者が unit で検証済みの不正ログイン入力を、テスターが UI 層でも全部書く）。**AI での高速なテスト増産は、このアンチパターンの発生確率を上げる**。

**症状チェック**:
- [ ] 小さな機能のリリースにも長時間かかる
- [ ] バグのたびに開発者とテスターが「適切なテストを書かなかった」と責任を押し付け合う

**対策**: ユーザーストーリーのキックオフで、開発者とテスターが「どのレイヤーに誰がどのテストを書く（生成する）か」を合意し、ストーリーカードに記録する。

### エージェントワークフロー固有の罠

- 全テストケースを UI 駆動テストとして追加 → 何時間も走る肥大スイート
- unit / API / UI 層にまたがるテスト重複 → テストサイクル全体の長期化
- 防止策: ケース生成とコード生成を分離し、**自動化するケースとレイヤーを人間が選択**する工程を挟む。

---

## 「100% 自動化カバレッジ」の落とし穴

自動化カバレッジ% = 既知の全テストケースのうち自動化済みの割合。追跡自体は有益だが、解釈を誤ると危険。

| 落とし穴 | 実態 |
|---------|------|
| 100% = バグフリーではない | % は**既知の**ケースの自動化率にすぎない。新ケースは後から必ず見つかる。ステークホルダーに先に説明しないと、重大バグのたびに自動化スイートの価値が疑われる |
| 高い全体% がモジュールの穴を隠す | 他モジュールが高カバレッジなら、あるモジュールが 0 テストでも全体は 80% 超になり得る。**面での分布**を観察する |
| 機能テストのみ数えがち | 機能・非機能（cross-functional）双方のケースを分母に含める。非機能を数えないと後でバグ化する |
| 100% が構造的に不可能な場合 | 環境・自動化コスト・アプリ特性次第では達成不能。その場合は手動ケースを正しく追跡管理する。ただし手動リストは短く保つ（回帰の手動テスト時間爆発に戻らないこと） |

- メトリクスの本来の目的: **自動化バックログの可視化**と次イテレーションでのキャパシティ計画、およびアンチパターンへの漂流検知。

### コードカバレッジとミューテーションテスト（補完メトリクス）

- **コードカバレッジ**は unit テストが実行しないコード行を特定する別メトリクス。JaCoCo / Cobertura を CI に組み込み、閾値未満でビルドを落とせる。ただし高カバレッジ ≠ 全ケース自動化済み。
- **ミューテーションテスト**はコードを変異させてテストが失敗するか確認し、unit テストの漏れを発見する（失敗すれば mutation は「killed」、しなければ「survived」）。PIT が代表ツール（Maven 依存として追加・CLI 実行・生存ケース一覧と mutation スコアを出力）。効果は高いが時間がかかるため使い所を選ぶ。

---

## 要点まとめ

- 自動テスト = ツールで期待動作を検証し、開発中に高速なフィードバックを得る実践。手動探索で新ケースを発見 → 自動化して回帰に充てる、が capacity 配分の基本。
- unit / integration / contract / service / UI functional / E2E を適切に編み合わせる。UI 駆動テストだけが自動化ではない。AI コーディングツールは全タイプを支援できる。
- テストピラミッド（micro を広い土台に、スコープ拡大とともに数を絞る）が作成・実行時間を最小化する理想形。
- AI ツール採用時は、特殊なオーケストレーションワークフローと隠れた AI コストを必ず確認する。
- アイスクリームコーン / カップケーキの兆候を開発全期間で監視する。AI は不適切なレイヤーへのテスト量産を加速しやすい。
- 自動化カバレッジは追跡しつつ、「高い % = 安全」という誤解（分布の偏り・非機能の欠落）を許さない。
- 良い自動テストは、コードが人より長生きする現場で「唯一信頼できる生きたドキュメント」になる。長期投資として書く。
