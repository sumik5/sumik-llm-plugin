# 制御フロー

## 概要

if文・switch文・null・早すぎる最適化は、現代的なソフトウェア開発において最も議論される設計課題である。goto文と同様、これらの制御構造は構造化されたフローに見せかけた低レベルの概念であり、多くの場合、偶発的な決定と結びついている。この結びつきが波及効果を生み、コードの保守を困難にする。

このセクションでは、条件分岐の置換・null処理・早すぎる最適化に関するレシピを扱う。

## コードスメル検出チェックリスト

- [ ] **偶発的なif文**が多数存在する（実装の都合による分岐）
- [ ] **switch/case/elseif**が多用されている
- [ ] 真偽値変数に**曖昧な名前**がつけられている（flag、flg等）
- [ ] 真偽値変数が**フラグとして使用**されている
- [ ] **ネストされたif文**が深い（階段状・矢印状コード）
- [ ] 条件分岐で**真偽値を直接返却**している
- [ ] **null**が使用されている
- [ ] **オプショナルチェーン**（?.）が多用されている
- [ ] **null合体演算子**（??）が使用されている
- [ ] ハードコードされた**ビジネス条件**がある
- [ ] パフォーマンス測定なしで**最適化**されている
- [ ] **ビット演算子**が不必要に使用されている
- [ ] オブジェクトに**ID・主キー**が含まれている（外部システム連携以外）
- [ ] コンストラクタやデストラクタで**副作用**のある処理をしている

---

## 14章 If（Ch.14, 行7751-9003）

### 問題パターン

プログラミング言語の次の進化は、ほとんどのif文を取り除くこと。if文は構造化されたフローに見せかけたgoto文と言える。ほとんどのif文は偶発的な決定と結びつき、開放/閉鎖原則に反する。

### 重要レシピ（詳細）

#### 14.1 偶発的なif文のポリモーフィズムを用いた書き換え

**問題**: コード内に偶発的なif文が存在している。

**解決策**: 偶発的なif文をポリモーフィズムを活用したオブジェクトに置き換える。

**本質的vs偶発的の判断**:
- **本質的**: 現実世界の人々が自然言語で表現する条件（例: 年齢制限）
- **偶発的**: プログラム上の便宜的な実装（例: 文字列によるレーティング判定）

**コード例**:
```javascript
// Before（偶発的if文の氾濫）
class Movie { constructor(rate) { this.rate = rate; } }
class MovieWatcher {
  watchMovie(movie) {
    if ((this.age < 18) && (movie.rate === 'Adults Only'))
      throw new Error("視聴不可");
    else if ((this.age < 13) && (movie.rate === 'PG 13'))
      throw new Error("視聴不可");
    // 新しいレーティング追加ごとにif文が増える
    playMovie();
  }
}

// After（ポリモーフィズム）
class MovieRate { } // 抽象クラス
class PG13MovieRate extends MovieRate {
  warnIfNotAllowed(age) {
    if (age < 13) throw new Error("視聴不可");
  }
}
class AdultsOnlyMovieRate extends MovieRate {
  warnIfNotAllowed(age) {
    if (age < 18) throw new Error("視聴不可");
  }
}
class Movie {
  constructor(rate) { this.rate = rate; }
  warnIfNotAllowed(age) {
    this._rate.warnIfNotAllowed(age);
  }
}
class MovieWatcher {
  watchMovie(movie) {
    movie.warnIfNotAllowed(this.age);
    // 新しいレーティング追加時はポリモーフィックな
    // 新しいクラスを作成するだけ
  }
}
```

**利点**:
- 新しい要件はモデルを拡張するだけで対応
- タイプミスの問題が発生しない
- デフォルト処理は例外/nullオブジェクトで対応

**指針**: 同じドメインの要素は共通の抽象概念を作成、異なるドメインにまたがる要素は無理に共通化しない。

**関連**: レシピ14.4（switch置換）、レシピ15.1（Nullオブジェクト）

#### 14.4 switch/case/elseifの置き換え

**問題**: switch文・case節・elseif節が存在する。

**解決策**: これらをポリモーフィズムを活用したオブジェクトに置き換える。

**コード例**:
```javascript
// Before（switch）
class Mp3Converter {
  convertToMp3(source, mimeType) {
    switch (mimeType) {
      case "audio/mpeg":
        this.convertMpegToMp3(source); break;
      case "audio/wav":
        this.convertWavToMp3(source); break;
      default:
        throw new Error("未対応: " + mimeType);
    }
  }
}

// After（ストラテジーパターン）
class Mp3Converter {
  convertToMp3(source, mimeType) {
    const foundConverter = this.registeredConverters
      .find(converter => converter.handles(mimeType));
    if (!foundConverter) {
      throw new Error('コンバータが見つかりません ' + mimeType);
    }
    foundConverter.convertToMp3(source);
  }
}
```

**関連**: レシピ10.7（メソッドオブジェクト）、レシピ14.10（ネストif）

#### 14.10 ネストされたif文の書き換え

**問題**: 入れ子になったif文でコードが読みにくくテストも困難。

**解決策**: 入れ子になったif文の使用を避け、偶発的なif文も避ける。

**コード例**:
```javascript
// Before（階段状）
if (actualIndex < totalItems) {
  if (product[actualIndex].Name.Contains("arrow")) {
    do {
      if (product[actualIndex].price == null) {
        // 処理
      } else {
        if (!(product[actualIndex].priceIsCurrent())) {
          // 処理
        } else {
          // さらにネスト...
        }
      }
    } while (...);
  }
}

// After（リファクタリング）
foreach (products as currentProduct) {
  addPriceIfDefined(currentProduct)
}
function addPriceIfDefined() {
  // ルールに従う場合にのみ価格を追加
}
```

**関連**: レシピ6.13（コールバック地獄）、レシピ14.8（階段状条件）

### その他の重要レシピ（簡潔版）

#### 14.2 状態を表す真偽値変数の名前の改善
`$flag`のような曖昧な名前を`$atLeastOneElementWasFound`のような具体的な名前に変更する。

#### 14.3 真偽値変数の具体的なオブジェクトへの置き換え
真偽値フラグを避け、状態を表す具体的なオブジェクトを作成する。開放/閉鎖原則に従う。

#### 14.5 固定値と比較するif文のコレクションによる置き換え
ハードコードされた比較値をコレクション（マップ・辞書）で管理する。

#### 14.6 条件式の短絡評価の活用
論理演算において、式全体の結果が確定した時点で部分式の評価を終了する（&&や||の適切な利用）。

#### 14.7 else節の明示的な記述
if文には常に対応するelse節を明示的に記述する（早期リターンを除く）。フェイルファストを促進。

#### 14.8 階段状の条件分岐の簡素化
複数の条件チェックを経てtrue/falseを返すより、ビジネスロジックを反映した単一の論理式として表現する。

**コード例**:
```python
# Before（階段状）
def is_platypus(self):
  if self.is_mammal():
    if self.has_fur():
      if self.has_beak():
        return True
  return False

# After（論理式）
def is_platypus(self):
  return self.is_mammal() and self.has_fur() and self.has_beak()
```

#### 14.9 短絡評価を利用したハックの回避
副作用のある関数呼び出しを論理演算子で制御せず、明示的なif文を使用する。

#### 14.11 条件分岐において真偽値を直接返却することの回避
if文の中でtrue/falseを直接返すのではなく、条件式自体の評価結果を返す。

**コード例**:
```javascript
// Before
function canWeMoveOn() {
  if (work.hasPendingTasks()) return false;
  else return true;
}

// After
function canWeMoveOn() {
  return !work.hasPendingTasks();
}
```

#### 14.12 真偽値への暗黙的な型変換の防止
非真偽値を真偽値が要求される場所で使用することを避ける。

#### 14.13 複雑で長い三項演算子の簡素化
三項演算子は複雑なロジックではなく、シンプルな条件分岐にのみ使用する。複雑なロジックは別メソッドに抽出。

#### 14.14 非ポリモーフィック関数からポリモーフィック関数への変換
同じ機能を持つメソッドが複数存在する場合、ポリモーフィズムを活用する。

**コード例**:
```php
// Before（非ポリモーフィック）
class Array { public function arraySort() { } }
class List { public function listSort() { } }

// After（ポリモーフィック）
interface Sortable { public function sort(); }
class Array implements Sortable { public function sort() { } }
class List implements Sortable { public function sort() { } }
```

#### 14.15 オブジェクトの等価性の比較の改善
オブジェクトの属性を外部で比較するのではなく、オブジェクト自身に等価性を判断するメソッドを実装する。

#### 14.16 ハードコードされたビジネス条件の具象化
ハードコードされたビジネスルールを、適切なオブジェクトのメソッドに移動する。

#### 14.17 不要な条件式の削除
条件式に不要な部分式が含まれている場合、慎重に見直し削除する。

#### 14.18 ネストされた三項演算子の書き換え
ネストされた三項演算子を、条件を満たした時点で即座に値を返すif文に変更する。

---

## 15章 Null（Ch.15, 行9004-9439）

### 問題パターン

nullは実装の容易さから導入されたが、過去40年間に無数のエラー・脆弱性・システムクラッシュを引き起こし、数十億ドルの損害をもたらした（Tony Hoare）。nullは文脈によって異なる意味を持ち、現実世界には存在しない。

### 主要レシピ

#### 15.1 Nullオブジェクトの作成

**問題**: nullを使っている。

**解決策**: nullの代わりに、nullオブジェクトを使用する。

**nullの問題**:
- 呼び出し元と呼び出し先の間に不必要な結合
- nullチェックのためのif/switch/caseの過剰使用
- ポリモーフィズムを持たない（nullポインタ例外の原因）
- 全単射の原則に反する（現実世界に対応する概念がない）

**コード例**:
```javascript
// Before（null使用）
class Cart {
  total() {
    if (this.discountCoupon == null)
      return this.subtotal();
    else
      return this.subtotal() * (1 - this.discountCoupon.rate);
  }
}
cart = new Cart([...], null);

// After（nullオブジェクトパターン）
class DiscountCoupon {
  discount(subtotal) {
    return subtotal * (1 - this.rate);
  }
}
class NullCoupon {
  discount(subtotal) {
    return subtotal;
  }
}
class Cart {
  total() {
    return this.discountCoupon.discount(this.subtotal());
  }
}
cart = new Cart([...], new NullCoupon());
```

**言語サポート**:
- TypeScript: 厳格な型チェック
- Rust: Option型（Some/None）
- Kotlin: null安全性機能

**関連**: Tony Hoare「Null References: The Billion Dollar Mistake」

#### 15.2 オプショナルチェーンの排除

**問題**: メソッド呼び出しの連鎖でnullの可能性を無視している。

**解決策**: nullや未定義値の使用を避ける。完全に排除できれば、オプショナル型は不要。

**コード例**:
```javascript
// Before（オプショナルチェーン）
if (user?.credentials?.notExpired) {
  user.login();
}
user.functionDefinedOrNot?.();

// After（明示的）
if (!user.credentials.expired) {
  login();
}
// userは実際のユーザーか、nullオブジェクト
// credentialsも実際のオブジェクトか、InvalidCredentials
```

**優先順位**:
- 良い: コードから全てのnullを取り除く
- 悪い: オプショナルチェーンを使用する
- 酷い: nullにまったく対処しない

**関連**: レシピ14.6（短絡評価）、レシピ14.9（短絡ハック）、レシピ24.2（真値）

#### 15.3 オプショナルな属性のコレクションによる表現

**問題**: オプショナルな属性をモデル化する必要がある。

**解決策**: コレクションを使用して、オプショナルな属性をモデル化する。空のコレクションと要素を含むコレクションは自然にポリモーフィズムを持つ。

**コード例**:
```javascript
// Before（null許容）
class Person {
  constructor(name, email) {
    this.email = email; // nullの可能性あり
  }
  email() {
    return this.email; // 呼び出し側で常にnullチェック必要
  }
}

// After（コレクション）
class Person {
  constructor(name, emails) {
    this.emails = emails; // 常に配列、空も許容
    if (emails.length > 1) {
      throw new Error("メールアドレスは最大1つまで");
    }
  }
  emails() {
    return this.emails; // nullチェック不要
  }
}
```

**関連**: レシピ15.1（Nullオブジェクト）、レシピ17.7（オプション引数）

#### 15.4 null表現のための既存オブジェクトの活用

**問題**: nullを表現するオブジェクトを作成する必要がある。

**解決策**: デザインパターンを過度に使用せず、現実世界に対応した既存のクラスでnullの状態を表現する。

**nullを表現する例**:
| クラス | nullを表現するオブジェクト |
|--------|--------------------------|
| Number | 0 |
| String | "" |
| Array | [] |

**コード例**:
```java
// Before（専用クラス）
abstract class Address { }
public class NullAddress extends Address {
  public String city() { return ""; }
  public String state() { return ""; }
  public String zipCode() { return ""; }
}

// After（既存クラス活用）
public class Address {
  private String city;
  private String state;
  private String zipCode;
}
Address nullAddress = new Address("", "", "");
```

**注意**: グローバル・シングルトン・staticとして定義しない。

**関連**: レシピ17.2（シングルトン）、レシピ18.1（グローバル関数）

#### 15.5 未知の位置情報のnull以外による表現

**問題**: 位置情報が不明な場合に、特別な値（nullや0）を使用している。

**解決策**: 位置情報が不明でも、nullや特別な数値を使用せずに表現する。

**Null島の概念**: 緯度0度・経度0度（大西洋上の架空の点）。多くのGPSシステムが位置情報が不明な場合にこの点を使用する。

**コード例**:
```kotlin
// Before（0を特別ケース）
class Person(val name: String, val latitude: Double, val longitude: Double)
// Tony Hoare: (0.0, 0.0) // Null島

// After（適切なモデル化）
abstract class Location { }
class EarthLocation(val latitude: Double, val longitude: Double) : Location() { }
class UnknownLocation : Location() {
  override fun calculateDistance(other: Location): Double {
    throw IllegalArgumentException("未知の場所からの距離は計算不可")
  }
}
class Person(val name: String, val location: Location)
```

**関連**: レシピ15.1（Nullオブジェクト）、レシピ17.5（特殊値回避）

---

## 16章 早すぎる最適化（Ch.16, 行9440-10133）

### 問題パターン

「プログラマは重要でない部分の速度について膨大な時間を費やすが、これらの効率化の試みは実際には強い負の影響を与える。小さな効率化については約97%の時間は忘れるべきです。早すぎる最適化はすべての悪の根源」（Donald Knuth）

### 主要レシピ

#### 16.1 オブジェクトにおけるIDの回避

**問題**: オブジェクトモデル内に、現実世界には存在しないID・主キー・参照を使用している。

**解決策**: オブジェクトからIDを取り除き、オブジェクト同士を直接関連づける。

**コード例**:
```javascript
// Before（ID依存）
class Student {
  constructor(id, firstName, lastName, teacherId, schoolId) {
    this.teacherId = teacherId;
    this.schoolId = schoolId;
  }
  school() { return School.getById(this.schoolId); }
  teacher() { return Teacher.getById(this.teacherId); }
}

// After（直接参照）
class Student {
  constructor(firstName, lastName, teacher, school) {
    this.teacher = teacher;
    this.school = school;
  }
}
// 外部システム連携が必要な場合のみ、別のマッピングオブジェクトでID管理
```

**原則**: IDは本質的ではなく、システム外部との連携に必要な場合のみ使用。GUIDのような一意識別子を推奨。

**関連**: レシピ3.6（DTO除去）、レシピ16.2（早すぎる最適化）

#### 16.2 早すぎる最適化の排除

**問題**: 実際のパフォーマンス問題が確認されていないのに、推測で最適化している。

**解決策**: 実際の使用環境での測定結果に基づいて最適化を行う。

**コード例**:
```php
// Before（過剰な最適化）
class Person {
  ancestors() {
    cachedResults = GlobalCache.getInstance().relativesCache(this.id);
    if (cachedResults != null) {
      return cachedResults.getAllParents();
    }
    return database().getAllParents(this.id);
  }
}

// After（シンプル）
class Person {
  ancestors() {
    return this.mother.meAndAncestors()
      .concat(this.father.meAndAncestors());
  }
}
```

**原則**: 読みやすいコードを優先し、実測データで問題が確認されてから最適化する。

**関連**: レシピ10.4（過度な技巧）

#### 16.3 ビット演算子を用いた早すぎる最適化の排除

**問題**: パフォーマンス向上を目的として、不必要にビット演算子を使用している。

**解決策**: ビット操作がビジネスロジックの本質でない限り、ビット演算子の使用を避ける。

**コード例**:
```javascript
// Before（技巧的）
const nowInSeconds = ~~(Date.now() / 1000)
// ~~は二重のビット反転（小数点以下切り捨て）

// After（明確）
const nowInSeconds = Math.floor(Date.now() / 1000)
```

**関連**: レシピ10.4（過度な技巧）、レシピ24.2（真値）

#### 16.4 過度な一般化の抑制

**問題**: 実際の要件を超えて、過度に抽象化・一般化されている。

**解決策**: 現在の要件・知識に基づいて設計し、将来を過度に予測しない。

**関連**: レシピ10.1（重複コード除去）

#### 16.5 根拠のない複雑なデータ構造の見直し

**問題**: 実際の要件・性能測定なしで、複雑なデータ構造・最適化手法が使用されている。

**解決策**: 実際の使用状況でのパフォーマンス測定を行うまでは、単純で理解しやすいデータ構造を使用する。

**コード例**:
```javascript
// Before（過度な最適化）
for (k = 0; k < 3 * 3; ++k) {
  const i = Math.floor(k / 3);
  const j = k % 3;
  console.log(i + ' ' + j);
}

// After（明確）
for (outerIterator = 0; outerIterator < 3; outerIterator++) {
  for (innerIterator = 0; innerIterator < 3; innerIterator++) {
    console.log(outerIterator + ' ' + innerIterator);
  }
}
```

**原則**: パレートの法則（80%の問題を引き起こす20%の重要箇所に集中）に従って最適化する。

**関連**: レシピ10.4（過度な技巧）、レシピ16.2（早すぎる最適化）

#### 16.6 未使用コードの削除

**問題**: 将来必要になるかもしれないという理由で、未使用コードが残されている。

**解決策**: 将来の可能性を想定して作成したコードは削除する。

**関連**: レシピ10.9（ポルターガイスト）、レシピ12.1（デッドコード）

#### 16.7 ドメインオブジェクトにおけるキャッシュの見直し

**問題**: パフォーマンス向上のためにキャッシュを導入したが、複雑さ・保守性の問題が考慮されていない。

**解決策**: キャッシュの必要性と影響を十分に評価するまでは、シンプルな実装を維持する。

**コード例**:
```php
// Before（ドメインオブジェクトに直接組み込み）
final class Book {
  private $cachedBooks;
  public function getBooksFromDatabase($title) {
    if (!isset($this->cachedBooks[$title])) {
      $this->cachedBooks[$title] = $this->doGet($title);
    }
    return $this->cachedBooks[$title];
  }
}

// After（キャッシュ機能を分離）
final class Book { }
interface BookRetriever {
  public function bookByTitle(string $title);
}
final class DatabaseLibrarian implements BookRetriever { }
final class HotSpotLibrarian implements BookRetriever {
  // 現実世界の概念（最近返却された本のリスト）を参考にした名前
  private $inbox;
  public function bookByTitle(string $title) {
    if ($this->inbox->includesTitle($title)) {
      return $this->inbox->retrieveAndRemove($title);
    }
    return $this->realRetriever->bookByTitle($title);
  }
}
```

**原則**: キャッシュはドメインオブジェクトから分離し、現実世界の概念でモデル化する。

**関連**: レシピ13.6（ハッシュ値と等価性）、レシピ16.2（早すぎる最適化）

#### 16.8 イベント処理における命名と実装の分離

**問題**: イベントハンドラの名前が、イベント内容ではなく具体的な処理内容を示している。

**解決策**: イベントハンドラの名前は、起こったイベントの内容を反映させる。

**コード例**:
```jsx
// Before（処理名）
const Item = ({name, handlePageChange}) =>
  <li onClick={handlePageChange}>{name}</li>

// After（イベント名）
const Item = ({name, onItemSelected}) =>
  <li onClick={onItemSelected}>{name}</li>
```

**原則**: イベントには「何をすべきか」ではなく、「何が起こったか」に基づいて名前を付ける。

**関連**: レシピ17.13（UIからアプリケーションロジック分離）

#### 16.9 コンストラクタからのデータベースアクセスの分離

**問題**: コンストラクタ内でデータベースにアクセスしている。

**解決策**: コンストラクタの役割はオブジェクトの初期化に限定し、データベースアクセスは別メソッドで行う。

**関連**: レシピ16.10（デストラクタからのコード排除）

#### 16.10 デストラクタからのコードの排除

**問題**: デストラクタ内でリソースを解放するコードがある。

**解決策**: デストラクタの使用を避け、ゼロの法則に従い、言語のガベージコレクションを活用する。

**原則**: プログラミング言語や既存のライブラリが自動で行える処理は、開発者が明示的にコードを書くべきではない。

---

## まとめ

制御フロー管理の3つの柱:

1. **if文の削減**: 偶発的なif文をポリモーフィズムで置換、本質的なif文のみ残す
2. **nullの排除**: nullオブジェクトパターン、コレクション活用、オプショナルチェーン回避
3. **測定に基づく最適化**: 実測データなしの最適化を避け、可読性を優先

これらのレシピを組み合わせることで、拡張性が高く、保守しやすく、テストしやすいクリーンなコードを実現できる。
