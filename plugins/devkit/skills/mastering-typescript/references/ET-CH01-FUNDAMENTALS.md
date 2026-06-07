# 第1-2章: 基礎と型システム理解 (項目1-17)

> **注**: 1章(項目1-5)は既存スキルと重複する基礎のため簡略化。2章(項目6-17)は通常レベルで記述。

---

## 1章: TypeScriptとは何か (項目1-5) - 簡略版

### 項目1: TypeScript/JavaScript関係の理解
**判断基準**: TypeScriptはJavaScriptのスーパーセット。すべてのJSはTS、逆は非。

**覚えておくべきこと:**
- TypeScriptはJavaScriptのスーパーセット
- 型システムは実行時動作をモデリング。例外を事前検出
- 型チェックパスしても実行時例外は起こりうる
- 疑わしいJS(引数数違い等)も検出

### 項目2: コンパイラーオプションの把握
**判断基準**: `tsconfig.json`で管理。`noImplicitAny`と`strictNullChecks`は必須レベル。

**覚えておくべきこと:**
- `tsconfig.json`使用(コマンドライン非推奨)
- `noImplicitAny`: 移行時以外オン
- `strictNullChecks`: 実行時エラー防止
- `strict`: 最終目標

### 項目3: コード生成は型に依存しない
**判断基準**: 型は実行時に消去される。型チェックと出力生成は独立。

**覚えておくべきこと:**
- 型エラーがあってもコード生成可能
- 型は実行時利用不可。再構築が必要(タグ付きユニオン、プロパティチェック)
- `class`は型と値の両方を作る
- 型は実行時パフォーマンスに影響なし

### 項目4: 構造的型付けへの慣れ
**判断基準**: 宣言以外のプロパティを持つ値も代入可能。型は「開いている」。

**覚えておくべきこと:**
- 構造が合えば代入可能(ダックタイピングのモデリング)
- 追加プロパティを持つ可能性を常に考慮
- クラスも構造的型付けに従う
- ユニットテストでモック作成に活用

### 項目5: any型の使用制限
**判断基準**: 可能な限り使わない。型安全性・契約・言語サービスを失う。

**覚えておくべきこと:**
- anyは型チェックをほぼ無効化
- 型安全性喪失、契約破棄、開発体験悪化、リファクタリング困難、型設計隠蔽、信頼性低下
- 可能な限り使用しない

---

## 2章: TypeScriptの型システム (項目6-17)

### 項目6: エディターで型システムを調査・探求
**判断基準**: エディターの言語サービスを最大活用。型の直感を養う訓練ツールとして使う。

**覚えておくべきこと:**
- TypeScript言語サービス対応エディター使用
- ホバーで型推論を確認、直感を養う
- シンボルリネーム等のリファクタリングツールに慣れる
- 型宣言ファイルに移動して振る舞いモデリング確認

**実践例:**
```typescript
// ホバーで型を確認
const x = 12;  // const x: 12 (リテラル型)
let y = 12;    // let y: number (拡大された型)

// エディターのリネーム機能で一括変更
interface User {
  name: string;  // ここを firstName に変更すると全箇所更新
}
```

---

### 項目7: 型を値の集合として考える
**判断基準**: 型は値の集合(ドメイン)。階層構造でなくベン図的な重なり。

**覚えておくべきこと:**
- 型はドメイン(値の集合)。有限(`boolean`)または無限(`number`)
- 厳密な階層でなく重なりを持つ集合
- オブジェクトは宣言外プロパティを持ちうる
- `A | B`は和集合、`A & B`は積集合
- 「拡張」「代入可能」「サブタイプ」=「部分集合」

**実践例:**
```typescript
type A = 'a' | 'b';
type B = 'b' | 'c';
type Union = A | B;      // 'a' | 'b' | 'c' (和集合)
type Intersection = A & B; // 'b' (積集合)

// never型は空集合
type Empty = string & number; // never
```

**判断のポイント:**
- `extends`は部分集合関係を表す
- `never`(空集合)からすべての型へ、すべての型から`unknown`(全体集合)へ代入可能

---

### 項目8: 型空間と値空間のシンボル見分け
**判断基準**: 文脈で判断。`typeof`、`this`等は両空間で意味が異なる。

**覚えておくべきこと:**
- 型空間と値空間を見分ける方法を習得
- すべての値に静的型あり(型空間のみアクセス可)
- `type`/`interface`は消去される(値空間からアクセス不可)
- `class`/`enum`は型と値の両方を導入
- 演算子の意味は空間で異なる

**主要な違い:**
| 構文 | 値空間 | 型空間 |
|------|--------|--------|
| `typeof` | JavaScript typeof演算子 | TypeScript型演算子 |
| `this` | JavaScript thisキーワード | ポリモーフィックthis型 |
| `&` / `\|` | ビット演算 | インターセクション/ユニオン |
| `const` | 変数宣言 | - |
| `as const` | - | リテラル推論変更 |
| `extends` | サブクラス定義 | サブタイプ/制約定義 |
| `in` | forループ | マップ型 |
| `!` | 論理not | 非nullアサーション |

**実践例:**
```typescript
// 型空間
type T1 = typeof String;  // StringConstructor型

// 値空間
const s = typeof "hello"; // "string" (文字列値)

// 両方導入
class Rectangle {}
const r: Rectangle = new Rectangle();
//       ^^^^^^^^^ 型空間      ^^^^^^^^^^^^^ 値空間
```

---

### 項目9: 型アノテーション優先、型アサーション最小化
**判断基準**: `: Type`を`as Type`より優先。TypeScriptが知らない情報がある場合のみアサーション。

**覚えておくべきこと:**
- 型アノテーション(`: Type`)を型アサーション(`as Type`)より優先
- アロー関数の戻り値型アサーション方法を知る
- TypeScriptが知らない情報を持つ場合のみアサーション使用
- アサーション使用時はコメントで理由説明

**実践例:**
```typescript
// 良い: 型アノテーション
const person: Person = { name: 'Alice', age: 30 };

// 悪い: 型アサーション(型チェックが弱まる)
const person = { name: 'Alice' } as Person; // ageが欠けてもエラーにならない

// 許容: DOMで確実に存在を知っている場合
const button = document.getElementById('myButton') as HTMLButtonElement;
// 理由: getElementByIdの戻り値はHTMLElement | nullだが、このIDは確実に存在すると知っている
```

**判断のポイント:**
- アサーションは型チェックを弱める→原則回避
- 非nullアサーション(`x!`)も慎重に。実行時例外リスク

---

### 項目10: ラッパーオブジェクト型を使用しない
**判断基準**: `String`/`Number`/`Boolean`/`Symbol`/`BigInt`でなく小文字のプリミティブ型を使用。

**覚えておくべきこと:**
- `string`(`number`/`boolean`/`symbol`/`bigint`)使用、大文字版は非推奨
- プリミティブのメソッド呼び出し時、自動的にラッパー生成・破棄される
- `Symbol`と`BigInt`以外、直接インスタンス化・使用を避ける

**実践例:**
```typescript
// 良い
function length(s: string): number {
  return s.length;
}

// 悪い
function lengthBad(s: String): number {
  return s.length;
}

// 実行時の自動ラップ(開発者が意識する必要なし)
"hello".toUpperCase(); // 内部で一時的にString("hello")が作られる
```

---

### 項目11: 余剰プロパティチェックと型チェックを区別
**判断基準**: オブジェクトリテラル代入時のみ余剰プロパティチェック発動。構造的代入可能性とは別物。

**覚えておくべきこと:**
- オブジェクトリテラルの代入/関数引数渡しで余剰プロパティチェック発動
- 通常の構造的代入可能性チェックとは異なる
- 中間変数導入でチェック回避される
- 弱い型(オプションのみ)は最低1プロパティ一致必須

**実践例:**
```typescript
interface Point {
  x: number;
  y: number;
}

// エラー: 余剰プロパティチェック
const p: Point = { x: 1, y: 2, z: 3 };
//                             ~ Object literal may only specify known properties

// OK: 中間変数でチェック回避
const obj = { x: 1, y: 2, z: 3 };
const p2: Point = obj; // 構造的には代入可能
```

**判断のポイント:**
- 余剰プロパティチェックはエラー発見に有効
- 型は「閉じていない」ことを忘れない

---

### 項目12: 関数式全体に型を適用
**判断基準**: パラメーター個別でなく関数式全体に型アノテーション。再利用性向上。

**覚えておくべきこと:**
- 関数式全体に型アノテーション適用を検討
- 同じ型シグネチャ繰り返しなら関数型定義
- ライブラリ作者はコールバック型提供
- 既存関数に合わせるなら`typeof fn`、戻り値変更なら`Parameters`とレストパラメーター

**実践例:**
```typescript
// 悪い: 個別にアノテーション
function add(a: number, b: number): number { return a + b; }
function subtract(a: number, b: number): number { return a - b; }

// 良い: 関数型を定義
type BinaryOp = (a: number, b: number) => number;
const add: BinaryOp = (a, b) => a + b;
const subtract: BinaryOp = (a, b) => a - b;

// 既存関数に合わせる
function fetchData(url: string): Promise<string> { /* ... */ }
const fetchData2: typeof fetchData = (url) => { /* ... */ };
```

---

### 項目13: typeとinterfaceの違い理解
**判断基準**: オブジェクト型は`interface`優先。ユニオン・条件型は`type`必須。

**覚えておくべきこと:**
- `type`と`interface`の違いと類似点理解
- 同じ型を両方の構文で書けるようにする
- `interface`は宣言マージ、`type`は型インライン化
- スタイル未確立プロジェクトではオブジェクト型に`interface`優先

**主要な違い:**
| 機能 | interface | type |
|------|-----------|------|
| オブジェクト型 | ◯ | ◯ |
| ユニオン型 | × | ◯ |
| タプル | △ | ◯ |
| 宣言マージ | ◯ | × |
| 拡張 | `extends` | `&` |
| パフォーマンス | わずかに良 | - |

**実践例:**
```typescript
// interface推奨: オブジェクト型
interface User {
  name: string;
  age: number;
}

// type必須: ユニオン型
type Status = 'active' | 'inactive' | 'pending';

// type必須: 条件型
type NonNullable<T> = T extends null | undefined ? never : T;

// interface: 宣言マージ(拡張可能)
interface Window {
  customProp: string;
}
```

**判断のポイント:**
- 迷ったら`interface`
- ユニオン・条件型なら`type`
- 既存コードのスタイルに従う

---

### 項目14: readonlyで変更エラー回避
**判断基準**: パラメーターを変更しない関数は`readonly`/`Readonly`宣言。契約明確化。

**覚えておくべきこと:**
- パラメーター非変更なら`readonly`(配列)/`Readonly`(オブジェクト)宣言
- 関数契約明確化、不用意な変更防止
- 効果は浅い。`Readonly`はプロパティのみ、メソッドは影響なし
- 変更箇所の特定に活用
- `const`は再代入防止、`readonly`は変更防止

**実践例:**
```typescript
// 良い: readonlyで契約明示
function printArray(arr: readonly number[]) {
  console.log(arr);
  // arr.push(1); // エラー: readonlyなので変更不可
}

// オブジェクトもReadonly
function processUser(user: Readonly<User>) {
  console.log(user.name);
  // user.name = 'Bob'; // エラー: Readonlyなので変更不可
}

// const vs readonly
const arr = [1, 2, 3];
// arr = [4, 5]; // エラー: 再代入不可
arr.push(4);     // OK: 変更は可能

const arr2: readonly number[] = [1, 2, 3];
// arr2.push(4); // エラー: readonlyなので変更不可
```

**判断のポイント:**
- デフォルトで`readonly`を検討
- 変更が本当に必要な場合のみ省略

---

### 項目15: 型演算とジェネリック型で重複回避
**判断基準**: DRY原則を型にも適用。型のマッピング機能とジェネリックを活用。

**覚えておくべきこと:**
- DRY原則は型にも当てはまる
- 同じ型繰り返しでなく命名。`extends`でフィールド重複回避
- `keyof`/`typeof`/インデックスアクセス/マップ型を理解
- ジェネリック型は型空間の関数。繰り返し型演算に使用
- `Pick`/`Partial`/`ReturnType`等の標準ライブラリ習得
- DRYやりすぎ注意

**実践例:**
```typescript
// 悪い: 重複
interface Person {
  name: string;
  age: number;
}
interface PersonUpdate {
  name?: string;
  age?: number;
}

// 良い: Partial利用
interface Person {
  name: string;
  age: number;
}
type PersonUpdate = Partial<Person>;

// 良い: Pick利用
type PersonName = Pick<Person, 'name'>;

// 良い: typeof利用
const defaultPerson = { name: 'Unknown', age: 0 };
type Person = typeof defaultPerson;
```

**よく使う型演算:**
- `Pick<T, K>`: Kのプロパティのみ抽出
- `Omit<T, K>`: Kのプロパティを除外
- `Partial<T>`: 全プロパティをオプション化
- `Required<T>`: 全プロパティを必須化
- `ReturnType<T>`: 関数の戻り値型

---

### 項目16: インデックスシグネチャより適切な代替
**判断基準**: `[key: string]: Type`は最終手段。`interface`/`Map`/`Record`/マップ型を優先。

**覚えておくべきこと:**
- インデックスシグネチャの欠点理解(anyと同様、型安全性低下)
- 可能なら代替手段: `interface`/`Map`/`Record`/マップ型/制約付きインデックス

**実践例:**
```typescript
// 悪い: インデックスシグネチャ
interface Rocket {
  [key: string]: string | number;
  name: string;
  thrust: number;
}
// 問題: どんなキーも受け入れ、特定キー不要、型ごとに異なる型持てない、言語サービス効かない

// 良い: 明示的interface
interface Rocket {
  name: string;
  thrust: number;
}

// 良い: Record型(既知のキーセット)
type Model = 'Falcon9' | 'FalconHeavy' | 'Starship';
type Rockets = Record<Model, Rocket>;

// 良い: Map(動的キー)
const rockets = new Map<string, Rocket>();

// 良い: マップ型(既存型から生成)
type RocketKeys = { [K in keyof Rocket]: string };
```

---

### 項目17: 数値型インデックスシグネチャ回避
**判断基準**: `[n: number]: Type`より`Array`/タプル/`ArrayLike`/`Iterable`を使用。

**覚えておくべきこと:**
- 配列はオブジェクト。キーは文字列(数値でない)
- インデックスシグネチャの`number`はTypeScriptのみの構成要素
- `number`使用より`Array`/タプル/`ArrayLike`/`Iterable`型使用

**実践例:**
```typescript
// 悪い: 数値インデックスシグネチャ
interface NumberArray {
  [n: number]: number;
}

// 良い: Array型
type NumberArray = number[];

// 良い: タプル型(固定長)
type Point = [number, number];

// 良い: ArrayLike(length持つオブジェクト)
function processArrayLike(arr: ArrayLike<number>) {
  for (let i = 0; i < arr.length; i++) {
    console.log(arr[i]);
  }
}
```

**判断のポイント:**
- 配列操作なら素直に`Array<T>`
- 固定長なら`[T1, T2, ...]`タプル
- 配列風オブジェクトなら`ArrayLike<T>`

---

## 全体まとめ: 1-2章の判断フロー

```
コード記述時
  ↓
型アノテーション必要? (項目18参照)
  ├─ 関数シグネチャ → 付ける
  ├─ オブジェクトリテラル → 付ける(余剰プロパティチェック)
  └─ ローカル変数 → 推論に任せる
  ↓
interface vs type? (項目13)
  ├─ オブジェクト型 → interface
  ├─ ユニオン/条件型 → type
  └─ 既存スタイル → 従う
  ↓
readonly必要? (項目14)
  ├─ パラメーター非変更 → readonly/Readonly
  └─ 変更必要 → 省略
  ↓
型の重複ある? (項目15)
  ├─ 重複あり → 型演算/ジェネリックで統合
  └─ 重複なし → そのまま
  ↓
コンパイラーオプション確認 (項目2)
  ├─ noImplicitAny → 有効
  ├─ strictNullChecks → 有効
  └─ strict → 最終目標
```

**次章への橋渡し:**
- CH02では型推論の詳細と制御フロー解析
- CH03では実践的な型設計パターン
