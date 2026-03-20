# サードパーティコードとの境界管理

境界（Boundary）はアプリケーションと外部世界の接点。自分がコントロールできない外部コードとどう向き合うかを定義する技法を扱います。

---

## 境界問題の本質

サードパーティコードには自然な緊張関係がある。

- **提供者側**: 広い適用性を求める → できるだけ多くの環境で動くよう汎用的なAPIを設計
- **利用者側**: 特定のニーズに集中したい → アプリケーション固有のシンプルなインターフェースが欲しい

この緊張関係が境界の問題を生む。

---

## サードパーティAPIを直接流通させない

`java.util.Map` の例で考えると、Mapは強力だが、その広さが問題になる。`clear()`メソッドで誰でも全データを消せてしまうし、型の制約もない。

**悪い例: Mapをそのまま受け渡す**

```java
// Mapがシステム全体に流通する
Map sensors = new HashMap();
// ... あちこちで:
Sensor s = (Sensor) sensors.get(sensorId);  // キャストが至るところに散在
```

**良い例: 境界インターフェースをラッパーの中に隠す**

```java
public class Sensors {
    private Map sensors = new HashMap();  // 境界インターフェースは内部に隠蔽

    public Sensor getById(String id) {
        return (Sensor) sensors.get(id);  // キャストはここだけ
    }
    // アプリケーション固有のメソッドのみを公開
    // ビジネスルールをここで強制できる
}
```

**ルール**: Mapのような境界インターフェースは、クラスの内部か密接な関係にあるクラスの内部にとどめる。publicなAPIの引数や戻り値として返してはならない。

---

## 学習テスト（Learning Tests）

サードパーティAPIを学ぶために**本番コードではなく**テストを書く手法。Jim Newkirkが提唱。

### log4j での実践例

```java
// Step 1: 最初の試み（失敗する）
@Test
public void testLogCreate() {
    Logger logger = Logger.getLogger("MyLogger");
    logger.info("hello");  // → Appenderが必要だとエラー
}

// Step 2: Appenderを追加（まだ失敗する）
@Test
public void testLogAddAppender() {
    Logger logger = Logger.getLogger("MyLogger");
    ConsoleAppender appender = new ConsoleAppender();
    logger.addAppender(appender);
    logger.info("hello");  // → 出力ストリームがないとエラー
}

// Step 3: 正しい形（成功する）
// 最終的に理解をテストとして結晶化する
public class LogTest {
    private Logger logger;

    @Before
    public void initialize() {
        logger = Logger.getLogger("logger");
        logger.removeAllAppenders();
        Logger.getRootLogger().removeAllAppenders();
    }

    @Test
    public void basicLogger() {
        BasicConfigurator.configure();
        logger.info("basicLogger");
    }

    @Test
    public void addAppenderWithStream() {
        logger.addAppender(new ConsoleAppender(
            new PatternLayout("%p %t %m%n"),
            ConsoleAppender.SYSTEM_OUT));
        logger.info("addAppenderWithStream");
    }
}
```

### 学習テストが「無料以上」の理由

- **コストはほぼゼロ**: APIを学ぶことは必要。テストを書くのはその学習の一形態にすぎない
- **理解の検証**: 制御された実験として、APIに対する自分の理解が正しいか確認できる
- **API変更の検出**: 新バージョンリリース時に学習テストを再実行 → 非互換な変更を即座に発見
- **マイグレーションガイド**: 境界テストがないと古いバージョンに留まりがちになる

---

## まだ存在しないコードへの適応

境界の向こう側が未定義の場合、ブロックされずに作業を進める手法。

**実例**: 無線通信システムの「Transmitter」サブシステムのAPIがまだ定義されていなかった。

**解決策: 自分が欲しいインターフェースを先に定義する**

```java
// Step 1: 自分たちが望むインターフェースを定義
//         "指定周波数でキーイングし、このストリームのアナログ表現を送信せよ"
interface Transmitter {
    void transmit(Frequency frequency, DataStream stream);
}

// Step 2: このインターフェースで CommunicationsController を実装
// → Transmitter APIが未定義でも作業を継続できる

// Step 3: APIが決まったらアダプターで接続
class TransmitterAdapter implements Transmitter {
    private final RealTransmitterAPI api;

    @Override
    public void transmit(Frequency frequency, DataStream stream) {
        // 実際のAPIへの変換ロジックをここに集約
        api.doActualTransmission(frequency.toHz(), stream.toBytes());
    }
}
```

**この設計の利点**:
- `CommunicationsController` のコードがクリーンで表現力を保てる
- アダプターがAPIとの接続を1箇所に集約 → API変更時の修正箇所が最小化
- `FakeTransmitter` を使ったテストが容易になる「継ぎ目（seam）」を提供

---

## クリーンな境界の原則

> "Good software designs accommodate change without huge investments and rework."
> ― Clean Code Ch.8

1. **依存の方向を逆転する**: 自分がコントロールできないものではなく、自分がコントロールできるものに依存する
2. **境界への参照を最小化する**: サードパーティを直接参照する場所をコードベース全体で少なくする
3. **ラッパーかアダプターで包む**: 変更時の影響範囲を1箇所に限定する
4. **境界テストで期待を文書化する**: 本番コードと同じ使い方でAPIを呼ぶテストを書く

---

## 実践ガイド

| 状況 | 推奨アプローチ |
|------|--------------|
| サードパーティAPIを使い始める | 学習テストを書いて理解を確認 |
| APIを複数箇所で使う | ラッパークラスに隠蔽して流通させない |
| 依存APIが未定義 | 自分が欲しいインターフェースを先に定義し、アダプターで後付け接続 |
| サードパーティのバージョンアップ | 境界テストを実行して非互換な変更を即座に検出 |

---

## 関連スキル

- `writing-clean-code`: SOLID原則（依存関係逆転の原則と深く関係）
- `testing-code`: 学習テストと境界テストの実装
- `enforcing-type-safety`: 境界でのキャストを型安全なラッパーに閉じ込める
