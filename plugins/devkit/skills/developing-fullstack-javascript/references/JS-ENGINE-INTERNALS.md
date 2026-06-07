# JS-ENGINE-INTERNALS — V8 内部実装: 文字列・数値・オブジェクト最適化

V8 が文字列・数値・オブジェクトを内部でどのように表現・最適化するかを示す。  
言語仕様レベルの API（文字列メソッド・数値型 API・プロパティ記述子・プロトタイプ等）は  
既存の `JS-STDLIB.md` / `JS-OOP-AND-PROTOTYPES.md` を参照し、本ファイルはエンジン内部実装に限定する。

---

## 目次

1. [V8 文字列実装](#1-v8-文字列実装)
   - 1.1 [ヒープとメモリ領域](#11-ヒープとメモリ領域)
   - 1.2 [文字列の内部型一覧](#12-文字列の内部型一覧)
   - 1.3 [ConsString の仕組み](#13-consstring-の仕組み)
   - 1.4 [Flattening（平坦化）](#14-flattening平坦化)
   - 1.5 [その他の文字列型](#15-その他の文字列型)
   - 1.6 [パフォーマンスパターン](#16-パフォーマンスパターン)
2. [V8 数値実装](#2-v8-数値実装)
   - 2.1 [SMI: 小整数高速パス](#21-smi-小整数高速パス)
   - 2.2 [HeapNumber](#22-heapnumber)
   - 2.3 [数値ストレージ決定プロセス](#23-数値ストレージ決定プロセス)
   - 2.4 [パフォーマンス最適化戦略](#24-パフォーマンス最適化戦略)
3. [Hidden Classes と Inline Caches](#3-hidden-classes-と-inline-caches)
   - 3.1 [Hidden Classes（shapes）の仕組み](#31-hidden-classesshapesの仕組み)
   - 3.2 [Shape 遷移とコスト](#32-shape-遷移とコスト)
   - 3.3 [Inline Caches（ICs）](#33-inline-cachesics)
   - 3.4 [Fast properties vs Slow properties](#34-fast-properties-vs-slow-properties)
   - 3.5 [ベストプラクティス](#35-ベストプラクティス)

---

## 1. V8 文字列実装

### 1.1 ヒープとメモリ領域

V8 はすべての文字列を**ヒープオブジェクト**として管理する。理解に必要な3つの概念:

| 概念 | 説明 |
|------|------|
| **Heap（ヒープ）** | JavaScript プロセスに割り当てられた動的データ格納領域。文字列・オブジェクト等を保持する大倉庫 |
| **Page（ページ）** | ヒープを構成する固定サイズ（約 256 KB）のメモリブロック。複数の heap オブジェクトを収容 |
| **Large Object Space** | 128 KB を超えるデータ専用の特別領域。各オブジェクトが専用ページを持ち、GC 時に移動されない |

- **Small String（小文字列）**: 128 KB 未満 → 通常の Page に格納
- **Large String（大文字列）**: 128 KB 超 → Large Object Space に格納。GC 時に不動のため断片化リスクがある

### 1.2 文字列の内部型一覧

V8 は JavaScript の単一文字列型に対して内部では複数の実装を使い分ける。
コンテンツや生成パターンに応じて V8 が自動選択する（開発者には不可視）。

| 内部型 | エンコード / 構造 | 生成される場面 |
|--------|-----------------|---------------|
| `INTERNALIZED_ONE_BYTE_STRING` | 8 bit/char（ASCII/Latin-1）+ 重複排除 | リテラル文字列、プロパティ名 |
| `INTERNALIZED_TWO_BYTE_STRING` | 16 bit/char（UTF-16）+ 重複排除 | 非 ASCII を含むリテラル |
| `SEQ_ONE_BYTE_STRING` | 8 bit/char, 連続バッファ | 小さな連結・フラット化後 |
| `SEQ_TWO_BYTE_STRING` | 16 bit/char, 連続バッファ | Unicode を含むフラット化後 |
| `CONS_ONE_BYTE_STRING` | 2 つの文字列への参照ポインタ（24〜32 バイト） | 大きな文字列の連結 |
| `SLICED_STRING` | 親文字列 + offset + length | `slice()` の結果 |
| `THIN_STRING` | 別文字列への単一ポインタ | dedup（重複文字列の排除） |
| `EXTERNAL_STRING` | ヒープ外ネイティブポインタ | C++ API 経由のデータ（Node.js ファイル読み込み等） |

```
// V8 内部型を観察するデバッグ機能（本番コードでは使用不可）
$ node --allow-natives-syntax
> let s = "hello"
> %DebugPrint(s)
// type: INTERNALIZED_ONE_BYTE_STRING_TYPE

> let m = "knock knock!", n = "who's there?"
> %DebugPrint(m + n)
// type: CONS_ONE_BYTE_STRING_TYPE  ← データコピーなし、ポインタのみ
```

### 1.3 ConsString の仕組み

文字列は不変（immutable）であるため、連結のたびに新バッファを確保するナイーブな実装では
二次時間計算量 O(n²) になる。V8 は **ConsString** によってこれを回避する。

**ナイーブな連結のコスト（25,000 行テーブル生成の場合）**:
- 最終文字列サイズ: 約 2.4 MB
- ナイーブ実装のピークメモリ: 最大 12 MB（コピーの積み重ね）

**ConsString の内部構造**:

```
// ConsString はデータをコピーせず参照ポインタだけを保持
ConsString（24〜32 バイト）
├── first  →  "knock knock!"  (INTERNALIZED_ONE_BYTE_STRING)
└── second →  "who's there?" (INTERNALIZED_ONE_BYTE_STRING)

// join() は ConsString の二分木を構築
ConsString (html)
├── ConsString (前半行群)
│   ├── "<table>"
│   └── "<tr>row1</tr>"
└── ConsString (後半行群)
    └── ...
```

V8 は文字列が十分に大きい場合に自動的に ConsString を選択する。
小さい文字列では即時コピー（`SEQ_ONE_BYTE_STRING`）のほうがコストが低いため、
V8 がケースバイケースで判断する。

```javascript
// ❌ アンチパターン: ループ内 += で累積 → O(n²) 時間・メモリ
function generateTableSlow(users, fields) {
  let html = '<table>';
  for (const user of users) {
    for (const field of fields) {
      html += `<td>${user[field]}</td>`;  // 毎回フルコピー
    }
  }
  html += '</table>';
  return html;
}

// ✅ 推奨: Array.push() + join() → ConsString ツリーで O(n)
function generateTableFast(users, fields) {
  const rows = ['<table>'];
  for (const user of users) {
    const cells = fields.map(f => `<td>${user[f]}</td>`);
    rows.push('<tr>' + cells.join('') + '</tr>');
  }
  rows.push('</table>');
  return rows.join('');
  // 最終文字列 ≈ 2.5 MB、ピークメモリ ≈ 2.7 MB（約 46% 削減）
}
```

### 1.4 Flattening（平坦化）

ConsString ツリーは構築時は高効率だが、一部の操作では連続バッファのほうが効率的なため
V8 が**遅延的にフラット化**（flatten）する。フラット化は全データを新バッファにコピーする操作であり、コストを伴う。

| 操作 | 自動フラット化 | 備考 |
|------|-------------|------|
| `length` 参照、ほとんどの String API | ✅ 実施 | ツリーを走査し連続バッファへコピー |
| Node.js `stream.write()` | ❌ 実施されない | C++ 側の処理のため V8 は関与しない |
| ビット演算 `s \| 0` | ✅ 実施 | 非公式テクニック。V8 バージョンで変化する可能性あり |

**フラット化の注意点**:
- 大文字列のフラット化は Large Object Space への移動を引き起こし、GC コストが増大する
- ConsString 構築後に `length` などを参照すると即座に平坦化が走る
- Node.js のストリーム書き込みでは ConsString のままだと内部変換が遅いため、
  明示的なフラット化が効果的な場面がある

```javascript
// Node.js ストリームへの書き込みで ConsString が遅いケース
stream.write(generateTable(users, fields));  // ConsString のまま → やや遅い

// 手動フラット化（V8 バージョン依存の非公式テクニック）
function flatstr(s) { s | 0; return s; }
stream.write(flatstr(generateTable(users, fields)));  // フラット化後 → やや速い
// ※ このトリガーは V8 バージョンにより変化する可能性がある
```

### 1.5 その他の文字列型

| 型 | 用途 | 開発者への影響 |
|----|------|--------------|
| **Internalized String** | プロパティ名・Symbol などで重複排除。ポインタ等値比較が O(1) | V8 が自動適用。リテラル文字列は概ねこの型 |
| **ThinString** | 同内容のインスタンス間でメモリを共有するラッパー | V8 が重複を自動検出。意識不要 |
| **SlicedString** | `slice()` の結果として親文字列の offset + length を参照 | コピーなしで部分文字列を表現。ただし**親文字列が GC されない**点に注意 |
| **External String** | ヒープ外ネイティブメモリへのポインタ | Node.js C++ API 経由で作成される。通常意識不要 |

### 1.6 パフォーマンスパターン

| パターン | 評価 | 理由 |
|---------|------|------|
| ループ内 `+=` で文字列を累積 | ❌ アンチパターン | O(n²) 時間・メモリ |
| `Array.push()` + `join('')` | ✅ 推奨 | ConsString ツリーを活用し O(n) |
| 再帰的文字列構築 + `join('')` | ✅ 推奨 | 再帰でも join がツリーを構築 |
| 大文字列を `stream.write()` に渡す | ⚠️ 注意 | 事前フラット化を検討 |
| 無制限キャッシュで大文字列を永続保持 | ❌ 危険 | Large Object Space 断片化・GC コスト増大 |

> **重要**: V8 の最適化はバージョンごとに変化する。特定の挙動（例: `s | 0` フラット化トリガー）への依存は将来のバージョンで失効する可能性がある。`Array.join()` パターン自体は安定している。

---

## 2. V8 数値実装

### 2.1 SMI: 小整数高速パス

V8 の最重要数値最適化が **SMI（Small Integer）** 表現である。
通常は数値格納にヒープオブジェクト（8 バイト）の割り当てとポインタ参照が必要だが、
SMI ではそのポインタ空間に値を直接エンコードする。

| 項目 | SMI | HeapNumber |
|------|-----|-----------|
| 格納方式 | ポインタ空間に値を直接エンコード | ヒープに 8 バイトオブジェクトを割り当て |
| 対象値 | 整数 かつ -2³¹ 〜 2³¹-1（約 ±21 億） | 浮動小数点・範囲外整数・NaN・Infinity |
| メモリ割り当て | **なし** | あり |
| アクセス速度 | 高速（間接参照不要） | 標準 |
| 整数演算速度 | 最速 | 2〜3x 遅い可能性あり（環境依存） |

```javascript
const MAX_SMI = 2147483647;   // 2^31 - 1  → SMI
const MIN_SMI = -2147483648;  // -2^31     → SMI

const a = 42;          // SMI
const b = -1000;       // SMI
const c = 2147483648;  // HeapNumber（SMI + 1、範囲超過）
const d = 3.14;        // HeapNumber（浮動小数点）
const e = NaN;         // HeapNumber
const f = Infinity;    // HeapNumber
```

### 2.2 HeapNumber

SMI 範囲外または浮動小数点値は **HeapNumber** オブジェクトとしてヒープに格納される。
これは 64-bit IEEE 754 double（float64）の実体であり、NaN-boxing 技術でポインタと区別される。

HeapNumber はメモリ割り当てとポインタ参照を伴うため、SMI と比較して
- 演算ごとのオーバーヘッドが増加する
- GC 対象オブジェクトが増加する

### 2.3 数値ストレージ決定プロセス

```
数値値
  ↓
整数か？（Number.isInteger）
  ├─ YES → SMI 範囲内か？（-2^31 〜 2^31-1）
  │          ├─ YES → SMI（ポインタ空間、割り当てなし）
  │          └─ NO  → HeapNumber（ヒープ割り当て）
  └─ NO  → HeapNumber（浮動小数点 / NaN / Infinity 等）
```

```javascript
// V8 内部決定プロセス（疑似コード）
function howV8StoresNumber(value) {
  if (Number.isInteger(value)) {
    if (value >= -2147483648 && value <= 2147483647) {
      return 'SMI: ポインタ空間に直接エンコード、割り当てなし';
    }
    return 'HeapNumber: 整数だが SMI 範囲超過';
  }
  return 'HeapNumber: 浮動小数点は常にヒープ';
}
```

### 2.4 パフォーマンス最適化戦略

| 戦略 | 良い例 | 避けるべき例 |
|------|--------|------------|
| ループカウンタ | `for (let i = 0; ...)` | `for (let i = 0.0; ...; i += 1.0)` |
| 整数演算優先 | `((value * 100) / total) \| 0` | `(value / total) * 100.0` |
| 配列の型均一化 | 整数のみの配列 | `[1, 2, 3.5, 4]`（1 つの float で全要素 HeapNumber に） |
| 金融計算 | セント単位整数演算し最後に割る | 最初から小数点付き計算 |

```javascript
// ❌ アンチパターン: ループ内で SMI → HeapNumber に昇格
function calculateTotalSlow(prices) {
  let total = 0;           // SMI
  for (const p of prices) {
    total += p * 1.0825;   // 浮動小数点加算で即 HeapNumber に昇格
  }
  return total;
}

// ✅ 推奨: 整数演算を維持し最後の1回だけ変換
function calculateTotalFast(pricesInCents) {
  let total = 0;           // SMI
  for (const p of pricesInCents) {
    total += Math.round(p * 10825 / 10000);  // SMI を維持
  }
  return total / 100;      // HeapNumber への変換は最後の1回のみ
}
```

**SMI 最適化が特に効果的な場面**:
- 数百万要素のタイトループ（差分が積み重なって顕著になる）
- メモリ制約環境（SMI はヒープ割り当てなし）
- ゲームエンジン・リアルタイム処理（予測可能な低遅延が必要）

> **注意**: SMI vs HeapNumber の差は環境・エンジンバージョン・CPU アーキテクチャによって大きく異なる。ほとんどのアプリケーションコードでは差は無視できる。ホットパスで実測した上で最適化すること。

---

## 3. Hidden Classes と Inline Caches

### 3.1 Hidden Classes（shapes）の仕組み

V8 はオブジェクトを作成するたびに **hidden class**（*shape* / *map* とも呼ばれる）を内部的に生成・管理する。
hidden class はオブジェクトの構造（プロパティの種類・型・メモリ上の配置）を記述した設計図であり、
プロパティ記述子はこの hidden class に格納される。

```javascript
// 同じファクトリ関数から生成されたオブジェクトは hidden class を共有
function createDrawer(label, contents) {
  return {
    label,        // 常に string
    contents,     // 常に string
    isOpen: false,     // 常に boolean
    accessCount: 0,    // 常に number
  };
}

const d1 = createDrawer('Tax', 'docs');        // → hidden class H1 を生成
const d2 = createDrawer('Legal', 'contracts'); // → H1 を共有（新規生成なし）
const d3 = createDrawer('HR', 'files');        // → H1 を共有
```

同じ構造のオブジェクトが hidden class を共有することで、プロパティアクセスを大幅に最適化できる。

### 3.2 Shape 遷移とコスト

プロパティの**追加・削除・再定義**のたびに新しい hidden class が作られ（*shape 遷移*）、
オブジェクトはそれまでのすべての shape の連鎖を追跡しなければならない。

```
// shape 遷移の連鎖イメージ
{} → S0（空）
  + label    → S1
  + isLocked → S2
// プロパティアクセス時: S0 → S1 → S2 ... と連鎖を検索
```

```javascript
// ❌ アンチパターン: 条件付きプロパティ追加 → 複数の異なる shape を生成
function createProblematicDrawer(label, contents, config = {}) {
  const drawer = { label, contents };       // shape S0

  if (config.secure) {
    drawer.lockCode = config.lockCode;      // shape S1（条件付き）
  }
  if (config.automated) {
    drawer.motorSpeed = config.motorSpeed;  // shape S2（条件付き）
    drawer.sensorType = config.sensorType; // shape S3（条件付き）
  }
  // 返却前に最大 5 回の shape 遷移が発生
  return drawer;
}

// ❌ プロパティの順序が異なると別の hidden class になる
const a = { label: 'A', isLocked: false };  // shape SA
const b = { isLocked: false, label: 'B' };  // shape SB（SA とは別物！）
```

**コンストラクタ関数の場合**:
コンストラクタ内でプロパティを逐次代入する際も技術的に shape 遷移は発生するが、
V8 は同じコンストラクタからの生成パターンを学習して最終 shape を予測し、将来の最適化に活かせる。
リテラルオブジェクト `{}` への逐次追加ではこの最適化が適用されない。

### 3.3 Inline Caches（ICs）

**Inline Cache（IC）** はプロパティアクセスの結果（どの hidden class のどのオフセット）を記憶し、
次回の同 shape オブジェクトへのアクセスでルックアップを省略する高速化機構。

```
// IC の動作イメージ
obj.name アクセス
  → V8: "このオブジェクトの shape は H1"
  → IC に記録: "H1 の name はオフセット 8 にある"

// 次回（同じ shape H1 のオブジェクト）
obj2.name アクセス
  → IC チェック: shape H1 → オフセット 8 を直接参照（ルックアップ省略）
```

| IC 状態 | 説明 | 速度 |
|---------|------|------|
| **Monomorphic（単一形態）** | 常に同じ shape → IC がそのまま機能 | 最速 |
| **Polymorphic（多形態）** | 2〜4 種の shape → IC が複数エントリを保持 | やや遅い |
| **Megamorphic（超多形態）** | shape の種類が多すぎる → V8 が最適化を断念してグローバルスタブに格下げ | 大幅に遅い |

shape が変わるたびに IC は無効化されて再ルックアップが必要になる。
頻繁な無効化が続くと V8 はその関数の最適化を断念し**スローモード**に落とす。

### 3.4 Fast properties vs Slow properties

| 分類 | ストレージ | 適用条件 | アクセス速度 |
|------|-----------|---------|------------|
| **Fast properties** | hidden class のオフセットで直接参照できる線形配列 | 形状が安定したオブジェクト | O(1)、間接参照なし |
| **Slow properties** | ハッシュテーブル（辞書） | 動的すぎるオブジェクト（頻繁なプロパティ追加・削除等） | O(1) 平均だがオーバーヘッド大 |

V8 は Fast から Slow へ自動的に降格させる。一度 Slow になったオブジェクトは原則として Fast に戻らない。

### 3.5 ベストプラクティス

| ルール | 理由 |
|--------|------|
| 全プロパティをコンストラクタ内で一括初期化する | shape を早期確定し IC が Monomorphic になる |
| 同じ構造のオブジェクトはプロパティを同じ順序で定義する | hidden class の共有を最大化する |
| `delete` を避ける | Slow properties への転落リスクがある |
| 配列のインデックスは数値のみ使用する | 文字列インデックスとの混在は shape 複雑化を招く |
| プロパティの型を途中で変えない | `string → number` 変更は shape 遷移を引き起こす |

```javascript
// ✅ 推奨: 生成時に全プロパティを一括定義
function createUser(id, name, email) {
  return { id, name, email };  // shape が一度で確定
}

// ✅ 推奨: クラス/コンストラクタで一括初期化（パターン学習が効く）
class User {
  constructor(id, name, email) {
    this.id = id;
    this.name = name;
    this.email = email;
  }
}

// ❌ 避ける: 生成後の逐次追加（shape 遷移 3 回）
const user = {};
user.id = id;
user.name = name;
user.email = email;

// ❌ 避ける: 同じ意味のオブジェクトでプロパティ順序を変える
const a = { x: 1, y: 2 };  // shape SA
const b = { y: 2, x: 1 };  // shape SB（SA と別の hidden class）
```

> **診断ツール**: Chrome DevTools の「Memory」タブや V8 の `--trace-ic` フラグを使うと、
> アプリケーションが生成している hidden class 数や IC の状態を確認できる。

---

*本ファイルは V8 エンジン内部実装（文字列型・数値表現・オブジェクト最適化）に特化した reference。*  
*文字列 API・数値型 API・オブジェクト言語仕様（プロパティ記述子・プロトタイプ等）は*  
*既存の `JS-STDLIB.md` / `JS-OOP-AND-PROTOTYPES.md` を参照すること。*
