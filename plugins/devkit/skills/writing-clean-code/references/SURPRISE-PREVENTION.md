# サプライズ防止：予期しない動作を排除する設計

コードは「コントラクトの明示的な部分（名前・型）」と「暗黙的な部分（コメント・Small Print）」から成る。エンジニアが「こう動くはず」という精神的モデルを持ったとき、それが現実と乖離していると予期しないバグが生まれる。このドキュメントでは、コードが引き起こすサプライズのパターンと、それを回避する具体的手法を体系化する。

---

## 1. マジック値を返さない

**マジック値**とは、通常の戻り値型に収まるが特別な意味を持つ値（例：-1 = 「値なし」）。型システムが「正常な値」として扱うため、コンパイラが問題を検出できない。

### なぜ危険か

```java
// Bad: コメントに隠れたSmall Print
class User {
    // Returns -1 if no age has been provided.
    Int getAge() {
        if (age == null) return -1;  // マジック値
        return age;
    }
}

// 呼び出し側: マジック値を知らない場合
Double getMeanAge(List<User> users) {
    Double sumOfAges = 0.0;
    for (User user : users) {
        sumOfAges += user.getAge().toDouble();  // -1 が混入してしまう
    }
    return sumOfAges / users.size().toDouble();  // 誤った平均が返る
}
```

### 危険ポイント

| 問題 | 説明 |
|------|------|
| **コンパイルを通る** | マジック値は型として正常なため、エラーにならない |
| **テストが捕捉できない** | 呼び出し側がマジック値の存在を知らなければ、テストケースを書かない |
| **言語間の不一致** | `Integer.MAX_VALUE`（Java）と `Number.MAX_SAFE_INTEGER`（JS）は異なる |

### 解決策：null / Optional / エラーを返す

```java
// Good: Null安全な型で「値がない」ことを明示
class User {
    Int? getAge() {  // "?" で null返却の可能性を型に組み込む
        return age;
    }
}

// 呼び出し側: コンパイラが null チェックを強制
Double? getMeanAge(List<User> users) {
    Double sumOfAges = 0.0;
    Int countWithAge = 0;
    for (User user : users) {
        Int? age = user.getAge();
        if (age != null) {  // null チェックをしないとコンパイルエラー
            sumOfAges += age.toDouble();
            countWithAge++;
        }
    }
    if (countWithAge == 0) return null;
    return sumOfAges / countWithAge.toDouble();
}
```

### 意図せずマジック値を返してしまう例

```java
// Bad: 空リストの場合 Int.MAX_VALUE が返る（意図せず）
Int minValue(List<Int> values) {
    Int minValue = Int.MAX_VALUE;
    for (Int value : values) {
        minValue = Math.min(value, minValue);
    }
    return minValue;  // 空リストでは Int.MAX_VALUE = マジック値
}

// Good: 空リストは null を返す
Int? minValue(List<Int> values) {
    if (values.isEmpty()) return null;  // 明示的に「値なし」を表現
    Int minValue = Int.MAX_VALUE;
    for (Int value : values) {
        minValue = Math.min(value, minValue);
    }
    return minValue;
}
```

---

## 2. Nullオブジェクトパターンの適切な使用

**Nullオブジェクトパターン**とは、null の代わりに「何もしない」有効な値を返すこと。適切に使えばコードが簡潔になるが、誤用するとエラーを隠蔽する。

### 判断フレームワーク

```
nullの代わりに何か返すべきか？
        ↓
「値がない」ことが呼び出し側にとって重要な情報か？
    ├─ いいえ（コレクション・汎用文字列） → Nullオブジェクト（空コレクション等）を返す ✓
    └─ はい（ID・状態・ビジネス上意味のある値） → null / Optional を返す ✓
```

### ケース1: 空コレクション（良い例）

```java
// Good: クラス属性の有無を区別しても意味がないため、空 Set を返す
Set<String> getClassNames(HtmlElement element) {
    String? attribute = element.getAttribute("class");
    if (attribute == null) {
        return new Set();  // 空 Set = null より扱いやすく、情報の欠落もない
    }
    return new Set(attribute.split(" "));
}

// 呼び出し側がシンプルになる
Boolean isElementHighlighted(HtmlElement element) {
    return getClassNames(element).contains("highlighted");  // null チェック不要
}
```

### ケース2: 意味のある文字列 ID（悪い例）

```java
// Bad: cardTransactionId が "ない" ことには意味がある
class Payment {
    String getCardTransactionId() {
        if (cardTransactionId == null) return "";  // 空文字 = カード決済なし？エラー？不明
    }
}

// Good: null で「カード決済ではなかった」を明示
class Payment {
    String? getCardTransactionId() {
        return cardTransactionId;  // null = カード決済なし（意味が1つだけ）
    }
}
```

### ケース3: 複雑なNullオブジェクト（危険な例）

```java
// Bad: CoffeeMug(0, 0) を返しても誰も気づかない
class CoffeeMugInventory {
    CoffeeMug getRandomMug() {
        if (mugs.isEmpty()) {
            return new CoffeeMug(diameter: 0.0, height: 0.0);  // ゼロサイズのマグ = 偽の値
        }
        return mugs[Math.randomInt(0, mugs.size())];
    }
}

// Good: null で「在庫なし」を明示
CoffeeMug? getRandomMug(List<CoffeeMug> mugs) {
    if (mugs.isEmpty()) return null;  // 「取得できない」ことを明示
    return mugs[Math.randomInt(0, mugs.size())];
}
```

### Nullオブジェクト判断表

| 状況 | 推奨 | 理由 |
|------|------|------|
| コレクション（Set, List, Map） | 空コレクションを返す | ほとんどの呼び出し側が区別しない |
| 汎用的な文字列（備考欄など） | 空文字列を返す | "未入力" と "空入力" の区別が不要 |
| ID文字列（cardTransactionId等） | null を返す | 「値がない」ことに意味がある |
| ビジネス上重要なオブジェクト | null を返す | ゼロ値オブジェクトがデータを汚染する可能性 |

---

## 3. 予期しない副作用を避ける

**副作用**（Side Effect）とは、関数が戻り値以外で外部の状態を変更すること。意図的で明示的な副作用は問題ないが、予期しない副作用はサプライズの温床となる。

### 副作用の種類

| 種類 | 例 |
|------|-----|
| ユーザー表示の更新 | UI に何か描画する |
| ファイル・DBへの書き込み | データを保存する |
| ネットワーク通信 | 他システムへのリクエスト |
| キャッシュの更新・無効化 | 状態をキャッシュに書く |

### 意図的な副作用（問題なし）

```java
// 関数名からキャンバスが更新されることは明らか
class UserDisplay {
    void displayErrorMessage(String message) {
        canvas.drawText(message, Color.RED);  // 副作用が「目的」そのもの
    }
}
```

### 予期しない副作用（問題あり）

```java
// Bad: getPixel() が redraw() を呼んでいることは名前から分からない
class UserDisplay {
    Color getPixel(Int x, Int y) {
        canvas.redraw();  // 予期しない副作用！ 10ms の負荷
        PixelData data = canvas.getPixel(x, y);
        return new Color(data.getRed(), data.getGreen(), data.getBlue());
    }
}

// 呼び出し側: スクリーンショット取得で 47 分フリーズ
Image captureScreenshot() {
    for (Int x = 0; x < image.getWidth(); ++x) {
        for (Int y = 0; y < image.getHeight(); ++y) {
            image.setPixel(x, y, getPixel(x, y));  // 各ピクセルで redraw() が走る！
        }
    }
}
```

**更に深刻な例：プライバシー侵害**

```java
// Bad: captureRedactedScreenshot() が captureScreenshot() の副作用を知らない
Image captureRedactedScreenshot() {
    for (Box area : getPrivacySensitiveAreas()) {
        canvas.delete(area.getX(), area.getY(), area.getWidth(), area.getHeight());
    }
    Image screenshot = captureScreenshot();  // 内部で canvas.redraw() が呼ばれ、削除部分が復元される！
    return screenshot;
}
```

### 解決策：副作用を排除するか、名前で明示する

```java
// Good: 副作用が名前から明らかになる
Color redrawAndGetPixel(Int x, Int y) {  // "redraw" を関数名に含める
    canvas.redraw();
    PixelData data = canvas.getPixel(x, y);
    return new Color(data.getRed(), data.getGreen(), data.getBlue());
}

// 呼び出し側は副作用を認識した上で実装を見直す
Image captureScreenshot() {
    canvas.redraw();  // 事前に 1 回だけ redraw する
    Image image = new Image(canvas.getWidth(), canvas.getHeight());
    for (Int x = 0; x < image.getWidth(); ++x) {
        for (Int y = 0; y < image.getHeight(); ++y) {
            image.setPixel(x, y, canvas.getPixel(x, y));  // redraw なしで取得
        }
    }
    return image;
}
```

---

## 4. 入力パラメータを変更しない

関数に渡されたオブジェクトを変更することは、「借りた本に書き込みをして返す」ようなもの。呼び出し側はオブジェクトがそのまま戻ってくると思っている。

### バグの例

```java
// Bad: getBillableInvoices() が userInvoices を破壊的に変更している
List<Invoice> getBillableInvoices(
    Map<User, Invoice> userInvoices,
    Set<User> usersWithFreeTrial) {
    userInvoices.removeAll(usersWithFreeTrial);  // 入力パラメータを変更！
    return userInvoices.values();
}

void processOrders(OrderBatch orderBatch) {
    Map<User, Invoice> userInvoices = orderBatch.getUserInvoices();
    Set<User> usersWithFreeTrial = orderBatch.getFreeTrialUsers();

    sendInvoices(getBillableInvoices(userInvoices, usersWithFreeTrial));
    // usersWithFreeTrial のユーザーが userInvoices から消えている！
    enableOrderedServices(userInvoices);  // 無料トライアルユーザーのサービスが有効化されない
}
```

### 解決策：コピーしてから変更する

```java
// Good: 入力パラメータを変更せず、フィルタリングで新しいリストを作成
List<Invoice> getBillableInvoices(
    Map<User, Invoice> userInvoices,
    Set<User> usersWithFreeTrial) {
    return userInvoices
        .entries()
        .filter(entry -> !usersWithFreeTrial.contains(entry.getKey()))
        .map(entry -> entry.getValue());  // 新しいリストを生成（元の Map は変更しない）
}
```

**注意**: パフォーマンス上のやむを得ない場合（大規模なソートなど）は、関数名や仕様に「変更あり」を明示する。

---

## 5. 誤解を招く関数を書かない

「クリティカルなパラメータをnullable にする」と、呼び出し側が「nullを渡しても問題ない」と誤解しやすくなる。

### 危険なパターン

```java
// Bad: legalText が null の場合、何も表示しない（が、呼び出し側は気づかない）
void displayLegalDisclaimer(String? legalText) {
    if (legalText == null) return;  // ← サイレントに何もしない
    displayOverlay(
        title: messages.getLegalDisclaimerTitle(),
        message: legalText,
        textColor: Color.RED);
}

// 呼び出し側：disclaimerが必ず表示されると信じている
void ensureLegalCompliance() {
    userDisplay.displayLegalDisclaimer(  // getSignupDisclaimer() が null を返す可能性を見落とす
        messages.getSignupDisclaimer());  // null だった場合、コンプライアンス違反になる
}
```

### 解決策：クリティカルなパラメータを必須にする

```java
// Good: null を受け取らない → 呼び出し側が null チェックを強制される
void displayLegalDisclaimer(String legalText) {  // null 不可
    displayOverlay(
        title: messages.getLegalDisclaimerTitle(),
        message: legalText,
        textColor: Color.RED);
}

// 呼び出し側：null チェックが強制され、コンプライアンス違反を防げる
@CheckReturnValue  // 戻り値の無視をコンパイラ警告
Boolean ensureLegalCompliance() {
    String? signupDisclaimer = messages.getSignupDisclaimer();
    if (signupDisclaimer == null) {
        return false;  // 翻訳がない = コンプライアンスを保証できない
    }
    userDisplay.displayLegalDisclaimer(signupDisclaimer);
    return true;
}
```

**設計指針**: 関数が本来の目的を達成するためにどうしても必要なパラメータは、nullable にしないこと。

---

## 6. Enumの将来的な変更に備える

Enum に新しい値が追加されたとき、古いコードが「暗黙的に」新しい値を扱ってしまう問題。

### 問題のあるパターン

```java
// Bad: if 文では「既知の2値以外はすべて安全」と暗黙的に扱う
enum PredictedOutcome {
    COMPANY_WILL_GO_BUST,
    COMPANY_WILL_MAKE_A_PROFIT,
}

Boolean isOutcomeSafe(PredictedOutcome prediction) {
    if (prediction == PredictedOutcome.COMPANY_WILL_GO_BUST) {
        return false;
    }
    return true;  // WORLD_WILL_END が追加されても true を返してしまう！
}
```

### 解決策1: 網羅的 switch 文

```java
// Good: switch で全ケースを明示し、未処理値は例外を投げる
Boolean isOutcomeSafe(PredictedOutcome prediction) {
    switch (prediction) {
        case COMPANY_WILL_GO_BUST:
            return false;
        case COMPANY_WILL_MAKE_A_PROFIT:
            return true;
    }
    // switch 文の後で例外を投げる（default ケースは使わない）
    throw new UncheckedException("未処理の予測値: " + prediction);
}
```

### 解決策2: 全 Enum 値を網羅するユニットテスト

```java
// 全 Enum 値に対してテストを実行
@Test
void testIsOutcomeSafe_allPredictedOutcomeValues() {
    for (PredictedOutcome prediction : PredictedOutcome.values()) {
        isOutcomeSafe(prediction);  // 未処理値があれば例外が投げられてテスト失敗
    }
}
```

### defaultケースの罠

```java
// Bad: default ケースで「なんとなくFalse」を返す
// → コンパイラがすべての値が処理済みと判断し、警告が出なくなる
Boolean isOutcomeSafe(PredictedOutcome prediction) {
    switch (prediction) {
        case COMPANY_WILL_GO_BUST:
            return false;
        case COMPANY_WILL_MAKE_A_PROFIT:
            return true;
        default:
            return false;  // WORLD_WILL_END, COMPANY_WILL_AVOID_LAWSUIT... 何でも false
    }
}
```

| アプローチ | コンパイラ警告 | テスト失敗 | 推奨 |
|-----------|--------------|----------|------|
| if 文（暗黙処理） | なし | なし | ❌ |
| switch + default で例外 | なし（C++等） | あり | △ |
| switch + 後置例外 | あり（C++等） | あり | ✓ |
| switch + 後置例外 + テスト | あり | あり | ✓✓ |

---

## 7. テストだけで解決できるか？

「コード品質の問題はテストで全部拾える」という考え方への反論。

### テストが追いつけない3つのシナリオ

| シナリオ | なぜテストで補えないか |
|---------|----------------------|
| **他のエンジニアのテスト不足** | 驚きのあるコードを書いた場合、呼び出し側も「驚くシナリオ」のテストを書かない傾向がある |
| **モックの誤った実装** | コードの挙動を誤解している場合、その誤解を前提にモックを作るため、バグが見つからない |
| **マルチスレッドの競合** | 発生確率が低く、スケール時にのみ顕在化するため、通常テストで再現できない |

### 結論

テストは不可欠だが、「テストだけ」で解決しようとするのは楽観的すぎる。
**「テスト」と「驚きのない設計」の両方が必要**。驚きのあるコードを書くと、テストを書く側も同じ誤解のもとでテストを書くため、バグが見逃されやすい。

```
良い設計 + 良いテスト = 堅牢なコード
驚きのあるコード + 良いテスト = 誤解を含むテスト = 虚偽の安心感
```

---

## 設計判断フローチャート

```
関数から値を返す
        ↓
「値がない」ケースはあるか？
    ├─ はい ↓
    │   その「値がない」ことは呼び出し側にとって重要な情報か？
    │   ├─ はい（ID・ビジネス上意味のある値）→ null / Optional / Result 型で返す
    │   └─ いいえ（コレクション・汎用文字列） → 空コレクション・空文字列を返す
    │       ただし「ゼロ値オブジェクト」は危険 → nullの方が安全
    └─ いいえ → 通常の型で返す（マジック値は絶対に使わない）
```

```
Enum を switch/if で処理する
        ↓
将来 Enum に値が追加される可能性があるか？
    ├─ はい（ほぼ常にそう） ↓
    │   すべての値を明示的に処理し、
    │   処理されていない値は UncheckedException を投げる（switch の後で）
    │   + 全 Enum 値のユニットテストを用意する
    └─ いいえ（外部システムの Enum で変更できない場合）→ default ケースを使うがリスクを文書化
```
