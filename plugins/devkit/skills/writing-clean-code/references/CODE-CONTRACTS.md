# コードコントラクトと抽象化レイヤー

コードが「どう使われるべきか」を確実に伝えるための設計パターン集。抽象化レイヤーの適切な粒度から、明示的・暗黙的契約の使い分け、そしてランタイム強制の手法までを体系化する。

---

## 抽象化レイヤー設計

### なぜ抽象化が必要か

複雑な問題を扱う際、適切な抽象化レイヤーがあれば、エンジニアは一度に数個の概念しか扱わずに済む。

```
// Bad: 実装詳細がすべて露出している
byte[] data = serialize(message.getContent());
TCPSocket socket = new TCPSocket(serverIp, port);
socket.setKeepAlive(true);
socket.setTimeoutMs(5000);
socket.write(data);
socket.flush();

// Good: 抽象化された3行のコード
HttpConnection connection = HttpConnection.connect("http://example.com/server");
connection.send("Hello server");
connection.close();
```

### 適切な粒度の判断基準

| 状態 | 症状 | 対策 |
|------|------|------|
| 粒度が粗すぎる | 1関数が100行超え、複数の責務を持つ | 責務ごとに関数を分割 |
| 粒度が細かすぎる | 1行しかない関数が多数、呼び出し先が多重になる | 関連する処理をグループ化 |
| 適切 | 関数名を読むだけで何をするか分かる | - |

### 抽象化レイヤーが達成する品質の柱

1. **可読性**: エンジニアはすべての実装詳細を理解せずとも、高レベルの抽象を使える
2. **モジュール性**: 各レイヤーを独立して変更・置き換えできる
3. **再利用性**: 下位レイヤーが上位レイヤーに依存しないため、様々な文脈で再利用できる
4. **テスタビリティ**: 抽象に依存するコードはモックで置き換えやすい

---

## コードコントラクト

コードのコントラクトとは「呼び出し側が満たすべき条件（事前条件）」と「呼ばれた側が保証すること（事後条件）」の合意。

### 明示的契約 vs 暗黙的契約（比較表）

| 種類 | 例 | 信頼性 | 特徴 |
|------|-----|--------|------|
| **明示的（Explicit）** | 関数名・パラメータ型・戻り値型・Checked例外 | 高い | コンパイルエラーで強制される |
| **明示的（Explicit）** | null安全の戻り値型 | 高い | コンパイラが使用前チェックを強制 |
| **暗黙的（Implicit）** | コメント・ドキュメント | 低い | 読まれないことが多い、古くなる |
| **暗黙的（Implicit）** | Unchecked例外 | 低い | 呼び出し側が知らないことがある |

### Small Printの危険性

コントラクトには「誰が見ても分かる部分」と「小さな文字（Small Print）」がある。

```
// Bad: Small Printだらけのコード
class UserSettings {
    UserSettings() { ... }

    // loadSettings()を呼んでから使うこと
    Boolean loadSettings(File location) { ... }

    // init()はloadSettings()の後に呼ぶこと
    void init() { ... }

    // null = ユーザーが色を選んでいない OR 初期化未完了
    Color? getUiColor() { ... }
}
```

上記の問題：
- 呼び出し順序がコメントにしか書かれていない
- `getUiColor()`の`null`が2つの異なる状態を表している（過負荷な意味）
- どのコメントも読まなければ誤用してしまう

```
// Good: Small Printを排除したコード
class UserSettings {
    // コンストラクタをprivateにして誤用を不可能に
    private UserSettings() { ... }

    // 唯一の作成方法。無効な状態のインスタンスは存在できない
    static UserSettings? create(File location) {
        UserSettings settings = new UserSettings();
        if (!settings.loadSettings(location)) {
            return null;  // 失敗 = null（理由は1つだけ）
        }
        settings.init();
        return settings;
    }

    // null = ユーザーが色を選んでいない（この意味だけ）
    Color? getUiColor() { ... }

    private Boolean loadSettings(File location) { ... }
    private void init() { ... }
}
```

### Small Printを排除する方法

1. **型システムを使う**: 無効な状態を型レベルで表現不可能にする
2. **可視性を制限する**: privateコンストラクタ・ファクトリメソッドパターン
3. **戻り値を明確にする**: 1つの戻り値が1つの意味だけを持つように設計する

---

## 他のエンジニアがコードを理解する方法

エンジニアが未知のコードを理解するために使う手段（信頼性の高い順）：

| 優先度 | 手段 | 信頼性 | なぜ |
|--------|------|--------|------|
| 1位 | **関数・クラス名** | 高 | 使うために必ず見る |
| 2位 | **型情報** | 高 | コンパイルエラーが強制する |
| 3位 | **ドキュメント・コメント** | 中 | 読まれないことが多い、古くなる |
| 4位 | **直接質問** | 低 | スケールしない、将来は聞けない |
| 5位 | **実装を読む** | 最低 | 全依存関係を読む羽目になる |

**設計方針**: 信頼性の高い手段（名前・型）でコントラクトを表現し、ドキュメントへの依存を最小化する。

### 名前による契約伝達

```
// Bad: 名前だけで分からない
Boolean process(File f) { ... }

// Good: 名前でコントラクトが伝わる
Boolean loadSettingsFromFile(File location) { ... }
```

### 型による契約伝達

```
// Bad: 型情報が貧弱
void sendMessage(String message, Int timeout) { ... }
// timeoutは秒？ミリ秒？いつのタイムスタンプ？

// Good: 型がコントラクトを明確にする
void sendMessage(String message, Duration timeout) { ... }
// Durationは単位を内包するため誤用不可能
```

---

## チェックとアサーション

コンパイル時に強制できない契約は、ランタイムで強制する。

### 事前条件チェック（Precondition Check）

```java
// 設定が読み込まれていない状態でinit()を呼ぶと即失敗
void init() {
    if (!haveSettingsBeenLoaded()) {
        throw new StateException("init()をloadSettings()より前に呼ぶことはできません");
    }
    // ... 初期化処理
}
```

### 事後条件チェック（Postcondition Check）

```java
// 処理後の状態が期待通りか確認
void processTransaction(Account account) {
    double balanceBefore = account.getBalance();
    // ... 処理
    assert account.getBalance() >= 0 : "残高が負になりました: " + account.getBalance();
}
```

### チェック vs アサーション（比較表）

| 観点 | チェック（Check） | アサーション（Assertion） |
|------|-----------------|------------------------|
| リリース時の動作 | 通常は有効のまま | 多くの言語でコンパイル時に除去可能 |
| 用途 | 本番でも検出すべきエラー | 開発・テスト中の不変条件の検証 |
| 発見タイミング | テスト実行中・本番稼働中 | 開発中・テスト実行中 |
| 設計指針 | 回復可能なエラーに | プログラミングエラーの早期発見に |

### チェックの限界

- **テストされていないシナリオ**: チェックが機能するのはそのパスを通った時だけ
- **例外の握りつぶし**: 上位でcatch→logだけされると、開発チームが気づかない恐れ
- **Best Strategy**: チェックに頼る前に、Small Printを排除して「誤用を不可能にする」設計を優先する

```
// 優先順位
// 1位: 型システムで誤用を不可能にする（コンパイルエラー）
// 2位: チェック/アサーションで誤用を検出する（ランタイムエラー）
// 3位: ドキュメントで誤用を防ぐ（信頼性低）
```

---

## 事前条件・事後条件・不変条件

正式なコントラクトプログラミングの三要素：

| 種類 | 定義 | 例 |
|------|------|-----|
| **事前条件 (Precondition)** | コードを呼ぶ前に満たすべき条件 | `index >= 0 && index < list.size()` |
| **事後条件 (Postcondition)** | コードを呼んだ後に保証される条件 | `returnValue != null && returnValue.isValid()` |
| **不変条件 (Invariant)** | オブジェクトの生存期間中常に真である条件 | `balance >= 0`（銀行口座） |

### コード例

```java
// 事前条件チェック
List<Integer> getTopN(List<Integer> items, int n) {
    if (n < 0) {
        throw new IllegalArgumentException("nは0以上である必要があります: " + n);
    }
    if (n > items.size()) {
        throw new IllegalArgumentException("nはリストサイズを超えられません");
    }
    // ...
}

// 不変条件チェック（コンストラクタ）
class BankAccount {
    private final double balance;

    BankAccount(double initialBalance) {
        if (initialBalance < 0) {
            throw new IllegalArgumentException("初期残高は0以上であること");
        }
        this.balance = initialBalance;
    }
}
```

---

## 判断フローチャート

```
コードコントラクトを定義する時
        ↓
コントラクトの条件を「誰が見ても分かる」部分で表現できるか？
    ├─ Yes → 型・関数名・シグネチャで表現する（最優先）
    └─ No  ↓
        コンパイル時に強制できるか？
        ├─ Yes → 型システムを使う（null安全、Result型、カスタム型）
        └─ No  ↓
            コメント・ドキュメントで記述する
            さらに、ランタイムでチェックを追加する
            （Small Printは残しつつ、違反を早期に検出する）
```
