# Unicode 深掘り・型強制アルゴリズム

JavaScript における文字列の内部表現（UTF-16・サロゲートペア・正規化・書記素クラスタ）と、
型強制の内部アルゴリズム（ToPrimitive・抽象等価ステップ）および数値型の拡張
（BigInt 内部表現・Decimals 提案）を扱う。

> 基礎的な API（`codePointAt`・`fromCodePoint` 等）や falsy 値一覧、テンプレートリテラルの
> 基礎構文は `JS-FUNDAMENTALS`・`JS-STDLIB` に格納済み。本ファイルは **内部表現と強制アルゴリズムの手順** に特化する。

---

## 1. ECMAScript 文字列の内部表現

ECMAScript 仕様は文字列を「16-bit 符号なし整数値（code unit）の順序付きシーケンス」と定義する。
この設計が UTF-16 エンコーディングと密接に結びついており、多くの罠の根源となっている。

### 1.1 UTF-16 とコードユニット

| コードポイント範囲 | code unit 数 | 表現方法 |
|---|---|---|
| U+0000 〜 U+FFFF（BMP） | 1 | 単一 16-bit code unit |
| U+10000 〜 U+10FFFF | 2 | サロゲートペア |

BMP（Basic Multilingual Plane）内の文字は 1 code unit で表現できる。
BMP 外（絵文字の大半・古代文字等）は **サロゲートペア** を使う。

### 1.2 サロゲートペアの仕組み

- **High surrogate**: U+D800 〜 U+DBFF（高位サロゲート）
- **Low surrogate**: U+DC00 〜 U+DFFF（低位サロゲート）

コードポイント算出アルゴリズム（U+10437 の例）:

```
High surrogate: (0xD801 − 0xD800) × 0x400 = 0x0400
Low surrogate:  0xDC37 − 0xDC00            = 0x0037
Codepoint:      0x0400 + 0x0037 + 0x10000  = 0x10437
```

**アンペアードサロゲート**（対になっていないサロゲート）は不正なシーケンスとなり、
表示時に U+FFFD（Unicode 置換文字）で代替される。

```javascript
'\ud800'.toWellFormed(); // '�'  (DOMString → USVString 変換)
```

### 1.3 `length` が「文字数」でない理由

`String.prototype.length` は code unit の数を返す（コードポイント数でも書記素クラスタ数でもない）。

```javascript
const a = 'café';     // é = U+00E9（1 code unit）
const b = 'café';     // é = U+0065 + U+0301（e + 結合アクセント = 2 code units）
a === b;              // false — 見た目は同一だが code unit 列が異なる
a.length;             // 4
b.length;             // 5

const emoji = '😀ABC';
emoji.length;         // 5  （😀 はサロゲートペア = 2 code units）
[...emoji].length;    // 4  （スプレッドはコードポイント単位）

// 正規表現: u フラグなしはサロゲートペアを 2 文字として扱う
/^./.exec(emoji)[0].length;   // 1（サロゲートの片割れのみ）
/^./u.exec(emoji)[0];         // '😀'（正しくコードポイント単位でマッチ）
/[😀-😎]/.test('😀');         // Error: Invalid regular expression
/[😀-😎]/u.test('😀');        // true（u フラグが必要）
```

---

## 2. Unicode 正規化

### 2.1 等価な複数表現と比較の落とし穴

Unicode では視覚的に同一の文字が異なる code unit 列で表現できる。
JavaScript は code unit を逐次比較するため、**正規化なしでは等価でも `===` で false になる**。

```javascript
const a = 'café';    // é = U+00E9（合成済み）
const b = 'café';    // é = U+0065 + U+0301（e + 結合アクセント）
a === b;             // false
a.length;            // 4
b.length;            // 5
```

### 2.2 4つの正規化形式

| 形式 | 名前 | 説明 | 例: 入力 → 出力 |
|------|------|------|---|
| NFC | Canonical Composition | 分解してから再合成 | `café(e+́)` → `café`（U+00E9） |
| NFD | Canonical Decomposition | 基底文字と結合文字に分解 | `café` → `café(e+́)` |
| NFKC | Compatibility Composition | NFC ＋ 互換分解・再合成 | `ﬁ`（1字） → `fi`（2字） |
| NFKD | Compatibility Decomposition | NFD ＋ 互換分解 | `½`（1字） → `1⁄2`（3字） |

```javascript
// String.prototype.normalize(form?)  デフォルト: 'NFC'
'café'.normalize() === 'café'.normalize();  // true
'café'.normalize('NFKC');                   // compat 正規化

// 比較・検索には必ず正規化してから行う
function safeCompare(a, b) {
  return a.normalize() === b.normalize();
}
```

### 2.3 セキュリティ上の注意点

- **バリデーション前に正規化**（後で正規化しても防御にならない）
- セキュリティ上重要な比較（ユーザー名の重複チェック等）には **NFKC** を推奨
  → より多くの等価パターン（ホモグラフ・互換文字）を統合する
- 重要な識別子は ASCII のみに制限することも検討する

```javascript
// NG: 正規化なしで重複チェック → 同一見た目のユーザー名が複数登録される
existingUsers.includes(username);

// OK: NFKC 正規化後に比較
existingUsers.some(u => u.normalize('NFKC') === username.normalize('NFKC'));
```

---

## 3. 書記素クラスタ

人が「1文字」として認識する単位が **書記素クラスタ（grapheme cluster）**。
コードポイント・code unit とは異なる概念。

```javascript
const family = '👨‍👩‍👧‍👦';   // ZWJ シーケンス（複数コードポイントの結合）
family.length;                     // 11  （code unit 数）
[...family].length;                // 7   （コードポイント数）

// 書記素クラスタ単位で操作するには Intl.Segmenter を使う
const seg = new Intl.Segmenter('ja', { granularity: 'grapheme' });
[...seg.segment(family)].length;   // 1   （人間が認識する文字数）
```

| 計測対象 | 方法 | 返す値 |
|---|---|---|
| code unit 数 | `str.length` | UTF-16 code unit 数 |
| コードポイント数 | `[...str].length` | Unicode コードポイント数 |
| 書記素クラスタ数 | `Intl.Segmenter` | 人が認識する文字数 |

---

## 4. DOMString / ByteString / USVString

ECMAScript の文字列定義は汎用的だが、Web 標準はより厳密な区別を設けている。

| 型 | 定義 | 主な用途 |
|---|---|---|
| ByteString | 16-bit 整数列（バイト列として未解釈） | HTTP ヘッダー値など |
| DOMString | UTF-16 code unit 列（アンペアードサロゲート許容） | 通常の JS 文字列 |
| USVString | 有効な UTF-16 列（アンペアードサロゲートを U+FFFD に置換済み） | URL・API 境界など |

```javascript
// DOMString → USVString 変換
'\ud800'.toWellFormed();
// '�'（U+FFFD: Unicode 置換文字）

// URL 解析では自動的に DOMString → USVString 変換が行われる
new URL('http://example.org/\ud800').href;
// 'http://example.org/%EF%BF%BD'（U+FFFD の percent-encoded 形式）
```

バイナリデータには `Buffer`（Node.js）または `Uint8Array` を使うこと。
ByteString で生バイト列を扱うのは型的に不適切。

---

## 5. BigInt の内部表現（V8）

### 5.1 64-bit チャンク配列

ECMAScript 仕様は BigInt の実装方法を広く委ねる。V8 では **64-bit 整数のチャンク配列** として実装されている。

例: `123456789012345678901234567890n`（30桁）

| チャンク | 値 | 役割 |
|---|---|---|
| 0 | 3,584,949,746 | 下位 64-bit |
| 1 | 6,692,605,942 | 上位 64-bit |

符号は別フラグで保持。再構成: `chunk[1] << 64n + chunk[0]`

Number（Binary64）の安全整数範囲（±2⁵³−1）を超える精度が必要な場合にのみ BigInt は意味を持つ。

### 5.2 固定幅整数との相互変換

C++ の `int64_t`/`uint64_t` 等の固定幅型との境界では **手動の範囲検証** が必須:

```javascript
function toInt64Safe(bigint) {
  const MIN = -(2n ** 63n);
  const MAX = 2n ** 63n - 1n;
  if (bigint < MIN || bigint > MAX) {
    throw new RangeError(`Value ${bigint} out of range`);
  }
  return bigint;
}
```

Number と BigInt の混合演算は **TypeError**。比較演算子は混合使用可。

```javascript
10n + 5;           // TypeError: Cannot mix BigInt and other types
10n + BigInt(5);   // 15n  （明示的変換）
Number(10n) + 5;   // 15   （精度損失に注意）
10n > 5;           // true  （比較は変換不要）
10n === 10;        // false （厳密等価は型も比較）
10n == 10;         // true  （緩い等価は変換あり）
```

**パフォーマンス**: BigInt 算術は Number より加算で 10〜20 倍、除算で 100〜200 倍遅い。
値が大きくなるほど複数チャンク処理が増え、さらに低下する。

---

## 6. Decimals 提案（TC39）

> ⚠️ **提案段階**（2025年現在 Stage 2）。構文・API は未確定。本番コードへの採用不可。

**背景**: Binary64 の限界 — `0.1 + 0.2 !== 0.3`（2進法で 0.1 が循環小数になるため）

提案される `Decimal` 型は IEEE 754 **Decimal128** ベース:

```javascript
const price = 19.99m;         // m サフィックス（提案中の構文）
const tax   = price * 0.0825m;
console.log(tax);             // 1.649175m（正確！）
0.1m + 0.2m === 0.3m;         // true（ついに！）
```

| 項目 | Number（Binary64） | Decimal（提案） |
|---|---|---|
| 精度 | 約 17 桁 | 34 桁 |
| `0.1 + 0.2` | 0.30000000000000004 | 0.3（正確） |
| 性能 | 高速（CPU ネイティブ演算） | 低速（ソフトウェア演算） |
| 用途 | 一般計算 | 金融・正確な小数演算 |

型の使い分け方針: Number（一般計算）→ BigInt（大きな整数）→ Decimal（正確な小数）

---

## 7. 型強制の内部アルゴリズム

JavaScript の暗黙的型変換は ECMAScript 仕様で定義された 16 個の **抽象変換操作** によって実行される。
ユーザーコードから直接呼び出すことはできないが、演算子・メソッドが内部的に呼び出す。

### 7.1 ToPrimitive（オブジェクト → プリミティブ変換）

オブジェクトをプリミティブに変換する際の内部手順:

1. `Symbol.toPrimitive` メソッドが存在すれば、hint を渡して呼び出す
2. hint が `"string"` の場合:
   1. `toString()` を試みる → プリミティブが返れば使用
   2. `valueOf()` を試みる → プリミティブが返れば使用
3. hint が `"number"` または `"default"` の場合:
   1. `valueOf()` を試みる → プリミティブが返れば使用
   2. `toString()` を試みる → プリミティブが返れば使用
4. いずれも失敗 → TypeError

hint の決まり方:

| 演算コンテキスト | hint |
|---|---|
| テンプレートリテラル `` `${obj}` `` | `"string"` |
| 算術演算子 `-`, `*`, `/` | `"number"` |
| 加算演算子 `+` | `"default"` |
| 文字列連結 `"str" + obj` | `"default"` |
| 比較演算子 `<`, `>` 等 | `"number"` |

```javascript
const obj = {
  [Symbol.toPrimitive](hint) {
    if (hint === 'string') return 'hello';
    return 42;   // number / default 両方
  }
};

`${obj}`;    // 'hello'  （hint: 'string'）
obj + 1;     // 43       （hint: 'default' → 42 + 1）
obj - 1;     // 41       （hint: 'number'  → 42 - 1）
```

### 7.2 抽象等価 `==` の評価ステップ

`x == y` の評価（仕様準拠の簡略版）:

| ステップ | 条件 | 処理 |
|---|---|---|
| 1 | `typeof x === typeof y` | 厳密等価（`===`）と同じ処理へ |
| 2 | `x` が null かつ `y` が undefined（逆も同様） | `true` を返す |
| 3 | `x` が Number、`y` が String | `y` を ToNumber に変換して再比較 |
| 4 | `x` が String、`y` が Number | `x` を ToNumber に変換して再比較 |
| 5 | いずれかが Boolean | Boolean を ToNumber に変換して再比較（`true→1`, `false→0`） |
| 6 | `x` がオブジェクト、`y` が Number/String/Symbol/BigInt | `ToPrimitive(x, "default")` して再比較 |
| 7 | その他 | `false` を返す |

**複数変換が連鎖する例: `[] == false`**

| ステップ | 変換内容 | 状態 |
|---|---|---|
| 初期 | — | `[] == false` |
| ステップ 5 | `false` → `0`（Boolean → Number） | `[] == 0` |
| ステップ 6 | `[]` → ToPrimitive → `""` | `"" == 0` |
| ステップ 4 | `""` → `0`（String → Number） | `0 == 0` |
| 結果 | — | `true` |

**重要な非対称性**: `[] == false` は `true` だが、`if ([])` は **truthy**
（ToBoolean はオブジェクトを常に `true` とし、ToPrimitive を呼び出さない）

```javascript
[] == false;   // true
if ([]) console.log('runs');  // 実行される（配列は truthy）
```

### 7.3 整数変換操作

ビット演算子や一部の組み込みメソッドは仕様定義の整数変換操作を内部的に使用する:

| 操作 | 出力範囲 | 使用される場面 |
|---|---|---|
| ToInt32 | −2³¹ 〜 2³¹−1 | ビット演算子 `\|`, `&`, `~`, `<<`, `>>` |
| ToUint32 | 0 〜 2³²−1 | `>>>`, `String.fromCharCode()` 等 |
| ToInt16 / ToUint16 | ±2¹⁵ / 0〜2¹⁶−1 | Int16Array / Uint16Array への代入 |
| ToInt8 / ToUint8 | ±2⁷ / 0〜255 | Int8Array / Uint8Array への代入 |

```javascript
String.fromCharCode(65601);  // 'A'（65601 % 65536 = 65、ToUint16 が適用）
3.7 | 0;                     // 3  （ToInt32 で小数部を切り捨て）
-1 >>> 0;                    // 4294967295（ToUint32 で符号なし変換）
new Array(3.7);              // length 3 の配列（ToUint32 が適用）
new Array(2 ** 32);          // RangeError（ToUint32 の上限超過）
```

### 7.4 `+` 演算子の特殊ルール

`-`/`*`/`/` が常に ToNumber を適用するのと異なり、`+` は **string 優先** の特殊ルール:

1. 両オペランドに `ToPrimitive("default")` を適用
2. どちらかが string なら両方を ToString して **文字列連結**
3. それ以外は両方を ToNumber して **加算**

```javascript
[] + []    // '' + '' = ''
[] + {}    // '' + '[object Object]' = '[object Object]'
{} + []    // コンテキスト依存: 文頭の {} はブロック文として解析 → +[] → 0
({}) + []  // '[object Object]'（括弧で式として強制）
```

---

## 8. 演算子別強制ルール早見表

| 演算子 | 適用変換 | 注意点 |
|---|---|---|
| `-`, `*`, `/`, `%` | ToNumber（両辺） | 文字列も数値化される |
| `+` | ToPrimitive → 文字列優先 | string が含まれると連結になる |
| `<`, `>`, `<=`, `>=` | 両辺が string → 辞書順 / それ以外 → ToNumber | `'10' < '9'` は `true`（辞書順） |
| `==` | 多段変換（型依存） | `null == undefined` のみ相互に `true` |
| `===` | 変換なし | 型も値も一致するときのみ `true` |
| ビット演算 | ToInt32 / ToUint32 | 小数点切り捨て・オーバーフロー折り返し |

**パフォーマンス原則**: 型変換はシステム境界で 1 度だけ行う。ループ内の暗黙変換は致命的な性能低下を招く。

```javascript
// ❌ NG: ソート比較のたびに string → number 変換が走る（最大 40 倍超の低速化）
timestamps.sort((a, b) => a - b);   // timestamps が string 配列の場合

// ✅ OK: 境界で一度だけ変換してから処理
const nums = timestamps.map(Number);
nums.sort((a, b) => a - b);
```
