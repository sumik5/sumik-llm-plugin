# 誤用防止：物理的に間違いにくいコードの設計

コードの誤用は、ドキュメントを整備してもなくならない。人がコードを読むとき「名前」と「型」しか確実に確認されない。コントラクトの「Small Print」（コメント・ドキュメント）はしばしば見落とされる。このドキュメントでは、設計レベルで誤用を困難または不可能にするパターンを体系化する。

---

## 1. 浅い不変性（Shallow Immutability）

**ミュータブルなクラスは誤用されやすい**。setter関数があると、クラスを渡した先でいつでも変更できてしまう。

### 問題のある設計：setter の存在

```java
// Bad: setFont() / setFontSize() が存在することで誰でも変更できる
class TextOptions {
    private Font font;
    private Double fontSize;

    void setFont(Font font) { this.font = font; }    // いつでも変更可能
    void setFontSize(Double fontSize) { this.fontSize = fontSize; }
}

// 誤用のシナリオ
void sayHello() {
    TextOptions defaultStyle = new TextOptions(Font.ARIAL, 12.0);
    messageBox.renderTitle("重要なメッセージ", defaultStyle);
    // renderTitle() が内部で defaultStyle.setFontSize(18.0) を呼んでしまった！
    messageBox.renderMessage("Hello", defaultStyle);  // フォントサイズ 18 になっている
}
```

### 解決策1: 構築時のみ値を設定する

```java
// Good: final で不変を保証、setter を削除
class TextOptions {
    private final Font font;      // final = 再代入不可
    private final Double fontSize;

    TextOptions(Font font, Double fontSize) {
        this.font = font;
        this.fontSize = fontSize;
    }

    Font getFont() { return font; }
    Double getFontSize() { return fontSize; }
    // setFont / setFontSize は存在しない → コンパイルレベルで変更不可能
}
```

### 解決策2: Builderパターン（オプション引数がある場合）

```java
// TextOptions クラス: 読み取り専用
class TextOptions {
    private final Font font;          // 必須
    private final Double? fontSize;   // オプション

    TextOptions(Font font, Double? fontSize) { ... }
    Font getFont() { return font; }
    Double? getFontSize() { return fontSize; }
}

// TextOptionsBuilder クラス: mutableな構築専用
class TextOptionsBuilder {
    private final Font font;          // 必須 → コンストラクタで受け取る
    private Double? fontSize;         // オプション → setter で設定

    TextOptionsBuilder(Font font) { this.font = font; }

    TextOptionsBuilder setFontSize(Double fontSize) {
        this.fontSize = fontSize;
        return this;  // メソッドチェーンを可能にする
    }

    TextOptions build() {
        return new TextOptions(font, fontSize);  // 不変オブジェクトを生成
    }
}

// 使用例
TextOptions options = new TextOptionsBuilder(Font.ARIAL)
    .setFontSize(12.0)
    .build();  // build() 後は変更不可
```

### 解決策3: コピーオンライトパターン（変更した版が必要な場合）

```java
// TextOptions に "with" 関数を追加
class TextOptions {
    private final Font font;
    private final Double? fontSize;

    TextOptions(Font font) { this(font, null); }
    private TextOptions(Font font, Double? fontSize) {
        this.font = font;
        this.fontSize = fontSize;
    }

    // 元のオブジェクトは変更せず、変更した版のコピーを返す
    TextOptions withFont(Font newFont) {
        return new TextOptions(newFont, fontSize);
    }
    TextOptions withFontSize(Double newFontSize) {
        return new TextOptions(font, newFontSize);
    }
}

// 呼び出し側: 元オブジェクトを汚染しない
void renderTitle(String title, TextOptions baseStyle) {
    titleField.display(
        title,
        baseStyle.withFontSize(18.0));  // baseStyle 自体は変わらない
}
```

---

## 2. 深い不変性（Deep Immutability）

`final` を使っても、メンバー変数が「ミュータブルなオブジェクトへの参照」である場合、その中身は変更可能。これが「深い可変性（Deep Mutability）」問題。

### 問題のあるシナリオ

```java
// TextOptions はリストへの参照を持つ（リスト自体は変更可能）
class TextOptions {
    private final List<Font> fontFamily;  // final = 参照先を変えられないが、中身は変えられる
    private final Double fontSize;

    TextOptions(List<Font> fontFamily, Double fontSize) {
        this.fontFamily = fontFamily;  // 外部のリストへの参照を保存
        this.fontSize = fontSize;
    }

    List<Font> getFontFamily() { return fontFamily; }  // 参照を渡してしまう
}
```

**シナリオ A: コンストラクタ呼び出し後に元リストが変更される**

```java
List<Font> fontFamily = [Font.ARIAL, Font.VERDANA];
TextOptions textOptions = new TextOptions(fontFamily, 12.0);
fontFamily.clear();
fontFamily.add(Font.COMIC_SANS);  // textOptions 内の fontFamily も変わる！
```

**シナリオ B: getterで取得した参照を変更される**

```java
List<Font> fontFamily = textOptions.getFontFamily();  // 同一リストへの参照
fontFamily.clear();
fontFamily.add(Font.COMIC_SANS);  // textOptions 内の fontFamily も変わる！
```

### 解決策1: 防御的コピー

```java
class TextOptions {
    private final List<Font> fontFamily;
    private final Double fontSize;

    TextOptions(List<Font> fontFamily, Double fontSize) {
        this.fontFamily = List.copyOf(fontFamily);  // コピーを保存（シナリオA解決）
        this.fontSize = fontSize;
    }

    List<Font> getFontFamily() {
        return List.copyOf(fontFamily);  // コピーを返す（シナリオB解決）
    }
}
```

**デメリット**: コピーコストがかかる。大量データや高頻度呼び出しでは問題になりうる。

### 解決策2: ImmutableList を使う（推奨）

```java
class TextOptions {
    private final ImmutableList<Font> fontFamily;  // 中身ごと変更不可
    private final Double fontSize;

    TextOptions(ImmutableList<Font> fontFamily, Double fontSize) {
        this.fontFamily = fontFamily;  // ImmutableList なのでコピー不要
        this.fontSize = fontSize;
    }

    ImmutableList<Font> getFontFamily() {
        return fontFamily;  // そのまま渡しても安全
    }
}
```

| 手法 | コスト | 安全性 | 推奨度 |
|------|--------|--------|--------|
| 何もしない | なし | 低 | ❌ |
| 防御的コピー | コピーコスト | 中（クラス内変更は防げない） | △ |
| ImmutableList | ほぼなし | 高（クラス内変更も防ぐ） | ✓ |

---

## 3. 汎用型の誤用

`List<List<Double>>` や `Pair<Double, Double>` のような汎用型を特定の概念に使うと、Small Print なしには正しく使えない。

### 危険なパターン: List<Double> で緯度経度を表現

```java
// Bad: List<List<Double>> は何も説明しない
/**
 * Accepts a list of lists, where the inner list should
 * contain exactly two values. The first value should
 * be the latitude and the second value the longitude.
 */
void markLocationsOnMap(List<List<Double>> locations) {
    for (List<Double> location : locations) {
        map.markLocation(location[0], location[1]);  // 0=lat? 0=lng?
    }
}
```

**誤用の可能性**:
```java
// すべてコンパイルを通過してしまう
List<Double> location = [-1.826111, 51.178889];   // 緯度と経度が逆
List<Double> location = [51.178889];               // 値が1つしかない
List<Double> location = [];                         // 値がない
List<Double> location = [4.0, 8.0, 15.0, 16.0];   // 値が多すぎる
```

### Pair 型を使っても解決しない

```java
// Still bad: Pair<Double, Double> も説明力がない
void markLocationsOnMap(List<Pair<Double, Double>> locations) {
    for (Pair<Double, Double> location : locations) {
        map.markLocation(location.getFirst(), location.getSecond());
        // getFirst() は緯度？経度？
    }
}
```

### 解決策: 専用型を定義する

```java
// Good: LatLong クラスを定義（数分の作業で実装可能）
/**
 * 緯度・経度を度数で表現する。
 */
class LatLong {
    private final Double latitude;
    private final Double longitude;

    LatLong(Double latitude, Double longitude) {
        this.latitude = latitude;
        this.longitude = longitude;
    }

    Double getLatitude() { return latitude; }
    Double getLongitude() { return longitude; }
}

// ドキュメント不要で自己説明的
void markLocationsOnMap(List<LatLong> locations) {
    for (LatLong location : locations) {
        map.markLocation(
            location.getLatitude(),   // 緯度であることが明白
            location.getLongitude()); // 経度であることが明白
    }
}
```

**パラダイムの拡散を防ぐ**: ハックな型を1か所に使うと、それに依存するコードも同じハックな型を採用せざるを得なくなる（技術的負債の連鎖）。

---

## 4. 時間の扱い

時間は単純に見えて複雑。整数（Int/Long）で時間を表現すると、誤用のリスクが高い。

### 整数での時間表現が引き起こす問題

**問題1: 「瞬間」vs「期間」の混同**

```java
// Bad: deadline が 「Unixエポックからの秒数」なのか「待機する秒数」なのか不明
Boolean sendMessage(String message, Int64 deadline) { ... }
```

**問題2: 単位の不一致（秒 vs ミリ秒）**

```java
// Bad: 秒で取得して、ミリ秒を期待する関数に渡してしまう
Int64 getMessageTimeout() { return 5; }  // 5 秒を意図
void showMessage(String message, Int64 timeoutMs) { ... }  // ミリ秒を期待

// コンパイルを通過するが、5ms でメッセージが消える（5秒のつもりが）
showMessage("警告", uiSettings.getMessageTimeout());
```

**問題3: タイムゾーンの混乱**

```java
// Bad: 誕生日をタイムスタンプ（瞬間）として保存
// ベルリン（UTC+1）: 1990-12-02 00:00 → UTC: 1990-12-01 23:00
// ニューヨーク（UTC-5）からアクセス: 1990-12-01 18:00 → 12月1日表示になる！
```

### 解決策: 専用の時間型を使う

```java
// Good: Duration 型で「期間」を明確に表現
Boolean sendMessage(String message, Duration deadline) { ... }

// 単位が型に内包されているため混在しない
class UiSettings {
    Duration getMessageTimeout() {
        return Duration.ofSeconds(5);  // 5秒と明示
    }
}

void showMessage(String message, Duration timeout) {
    // Duration は ofSeconds/ofMillis など単位付きで作成し、toMillis() などで変換
}

// 単位不一致バグが物理的に不可能になる
showMessage("警告", uiSettings.getMessageTimeout());  // Duration 同士なので型安全
```

| 概念 | 推奨型 | 例 |
|------|--------|-----|
| 時刻（瞬間） | `Instant` | `Instant.now()` |
| 期間（長さ） | `Duration` | `Duration.ofSeconds(5)` |
| カレンダー日付 | `LocalDate` | `LocalDate.of(1990, 12, 2)` |
| 日時 | `LocalDateTime` | タイムゾーン不要の場合 |

---

## 5. データの単一真実源

**プライマリデータ**（入力として提供される唯一の情報）と**派生データ**（プライマリから計算できる情報）を区別し、派生データを別途保存しないことが原則。

### 問題のある設計: 派生データを別途コンストラクタで受け取る

```java
// Bad: credit, debit から balance を計算できるのに、別途受け取っている
class UserAccount {
    private final Double credit;
    private final Double debit;
    private final Double balance;  // 冗長！

    UserAccount(Double credit, Double debit, Double balance) {
        this.credit = credit;
        this.debit = debit;
        this.balance = balance;  // 「debit - credit」と誤って渡される可能性
    }
}

// 論理的に矛盾した状態を作れてしまう
UserAccount account = new UserAccount(credit, debit, debit - credit);  // 逆！
```

### 解決策: 派生データは計算で求める

```java
// Good: balance は計算するのみ、矛盾した状態は作れない
class UserAccount {
    private final Double credit;
    private final Double debit;

    UserAccount(Double credit, Double debit) {
        this.credit = credit;
        this.debit = debit;
    }

    Double getBalance() {
        return credit - debit;  // 常に整合する
    }
}
```

### 高コストな派生計算: 遅延計算 + キャッシュ

```java
// 取引一覧からクレジット・デビットを計算する場合
class UserAccount {
    private final ImmutableList<Transaction> transactions;
    private Double? cachedCredit;  // キャッシュ（null = 未計算）
    private Double? cachedDebit;

    UserAccount(ImmutableList<Transaction> transactions) {
        this.transactions = transactions;
    }

    Double getCredit() {
        if (cachedCredit == null) {
            cachedCredit = transactions
                .map(t -> t.getCredit())
                .sum();  // 必要になったときだけ計算
        }
        return cachedCredit;
    }

    Double getBalance() {
        return getCredit() - getDebit();  // キャッシュを活用
    }
}
```

**注意**: キャッシュが安全なのは、クラスとデータ構造が**不変**であるとき。ミュータブルなら、変更時にキャッシュを `null` にリセットする必要があり、複雑化する。

---

## 6. ロジックの単一真実源

データだけでなく、「同じ形式・ルール」に従う複数の処理が独立した場所に実装されていると、片方を変更したとき他方がズレてバグになる。

### 問題のある設計: シリアライズとデシリアライズが別クラス

```java
// Bad: DataLogger と DataLoader が「同じフォーマット」を独自に実装
class DataLogger {
    void saveValues(FileHandler file) {
        String serialized = loggedValues
            .map(value -> value.toString(Radix.BASE_10))  // ← BASE_10 + カンマ
            .join(",");
        file.write(serialized);
    }
}

class DataLoader {
    List<Int> loadValues(FileHandler file) {
        return file.readAsString()
            .split(",")                                    // ← カンマ + BASE_10
            .map(str -> Int.parse(str, Radix.BASE_10));
    }
}
```

**リスク**: DataLogger のフォーマットを変更（例：タブ区切りへ）しても DataLoader は知らない。

### 解決策: フォーマットロジックを1か所に集約

```java
// Good: IntListFormat クラスがシリアライズ・デシリアライズを単一実装
class IntListFormat {
    private static final String DELIMITER = ",";         // デリミタは1か所のみ
    private static final Radix RADIX = Radix.BASE_10;   // 基数は1か所のみ

    String serialize(List<Int> values) {
        return values
            .map(value -> value.toString(RADIX))
            .join(DELIMITER);
    }

    List<Int> deserialize(String serialized) {
        return serialized
            .split(DELIMITER)
            .map(str -> Int.parse(str, RADIX));
    }
}

// DataLogger / DataLoader は IntListFormat に委譲するだけ
class DataLogger {
    private final IntListFormat intListFormat;
    void saveValues(FileHandler file) {
        file.write(intListFormat.serialize(loggedValues));
    }
}

class DataLoader {
    private final IntListFormat intListFormat;
    List<Int> loadValues(FileHandler file) {
        return intListFormat.deserialize(file.readAsString());
    }
}
```

---

## 誤用防止の総合チェックリスト

```
クラスを設計するとき:
    ├─ setter を提供しているか？
    │   ├─ はい → 本当に必要か？ Builder / CopyOnWrite パターンで代替できないか？
    │   └─ いいえ → ✓ 良い
    │
    ├─ メンバー変数がミュータブルなオブジェクトへの参照か？
    │   ├─ はい → ImmutableList 等を使うか、防御的コピーを実施
    │   └─ いいえ → ✓ 良い
    │
    ├─ 汎用型（List, Pair, int, String）で特定の概念を表現しているか？
    │   ├─ はい → 専用型を定義することを検討
    │   └─ いいえ → ✓ 良い
    │
    ├─ 時間を整数（Int, Long）で表現しているか？
    │   ├─ はい → Instant / Duration / LocalDate 等の専用型に切り替える
    │   └─ いいえ → ✓ 良い
    │
    ├─ 派生データをコンストラクタで受け取っているか？
    │   ├─ はい → 計算で求めるよう変更（必要なら遅延計算）
    │   └─ いいえ → ✓ 良い
    │
    └─ 同一ロジックが複数か所に実装されているか？
        ├─ はい → 単一クラスに抽出し、両者がそれを使うよう変更
        └─ いいえ → ✓ 良い
```
