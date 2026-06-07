# JavaScript関数型プログラミング基礎（Part 1: 発想の転換とキーコンセプト）

JavaScript/TypeScriptにおける関数型プログラミングの基礎概念と、OOPとの比較・JavaScript固有の特性を体系化したリファレンス。

---

## 関数型プログラミングのコアとなる4つの柱

| 概念 | 定義 | 違反時の問題 |
|------|------|-------------|
| **宣言型プログラミング** | 「何を」するかを記述、「どのように」は隠蔽 | 制御フローが複雑化し再利用が困難 |
| **純粋関数** | 同じ入力→常に同じ出力、副作用なし | テスト困難、バグの温床 |
| **参照透過性** | 関数呼び出しをその戻り値で置き換え可能 | 等式推論が成立しない |
| **不変性** | データを変更するのではなく新しいデータを生成 | 状態管理が複雑化 |

---

## 宣言型 vs 命令型プログラミング

### 命令型アプローチ（問題点）

```typescript
// 命令型: 「どのように」やるかを逐一指示
const numbers = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
const result: number[] = [];
for (let i = 0; i < numbers.length; i++) {
  result[i] = Math.pow(numbers[i], 2);
}
// 問題: ループカウンタの管理、インデックスミスのリスク、再利用不可
```

### 宣言型アプローチ（関数型）

```typescript
// 宣言型: 「何を」したいかを記述
const result = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
  .map(num => Math.pow(num, 2));
// 利点: ループ制御をシステムに委譲、再利用可能、テスト容易
```

### 選択基準

| 状況 | 推奨アプローチ |
|------|--------------|
| コレクション変換 | 宣言型（map/filter/reduce） |
| 複雑な状態遷移 | 関数型（モナド） |
| パフォーマンスクリティカル | 必要に応じて命令型 |
| ビジネスロジック | 宣言型（テスト容易性を優先） |

---

## OOPと関数型プログラミングの比較

### OOPアプローチ（継承ベース）

```typescript
class Person {
  constructor(
    protected firstname: string,
    protected lastname: string
  ) {}
}

class Student extends Person {
  constructor(
    firstname: string,
    lastname: string,
    private school: string
  ) {
    super(firstname, lastname);
  }

  // データと振る舞いが密結合
  studentsInSameSchool(friends: Student[]): Student[] {
    return friends.filter(f => f.school === this.school);
  }
}
```

### 関数型アプローチ（合成ベース）

```typescript
// データは単純なオブジェクト
interface Student {
  firstname: string;
  lastname: string;
  school: string;
}

// 振る舞いは独立した純粋関数
const sameSchoolSelector = (school: string) =>
  (student: Student) => student.school === school;

const findStudentsBy = (
  students: Student[],
  selector: (s: Student) => boolean
): Student[] => students.filter(selector);

// 再利用可能: 任意の条件で学生を検索
findStudentsBy(students, sameSchoolSelector('Princeton'));
```

### パラダイムの違い

| 観点 | OOP | 関数型 |
|------|-----|--------|
| 焦点 | データの関係性 | 振る舞い・処理 |
| 拡張方法 | 継承 | 関数合成 |
| 状態 | オブジェクトに内包 | 最小化・排除 |
| テスト | モックが必要なことが多い | 純粋関数は直接テスト可 |

---

## JavaScript固有の不変性実装パターン

### パターン1: Object.freeze（シャローフリーズ）

```typescript
// Object.freezeは浅いフリーズ（shallow freeze）
interface PersonData {
  firstname: string;
  lastname: string;
  address?: { country: string };
}

const person = Object.freeze({
  firstname: 'Haskell',
  lastname: 'Curry',
  address: { country: 'US' }
} as PersonData);

// person.firstname = 'Bob'; // Error: Cannot assign to read only property

// 注意: ネストしたオブジェクトは変更可能
person.address!.country = 'France'; // エラーにならない！（シャローフリーズの制限）
```

### パターン2: deepFreeze（ディープフリーズ）

```typescript
function isObject(val: unknown): val is Record<string, unknown> {
  return val !== null && typeof val === 'object';
}

function deepFreeze<T>(obj: T): Readonly<T> {
  if (isObject(obj) && !Object.isFrozen(obj)) {
    // 関数はフリーズ対象外、データのプロパティのみフリーズ
    Object.keys(obj).forEach(name => {
      deepFreeze((obj as Record<string, unknown>)[name]);
    });
    Object.freeze(obj);
  }
  return obj as Readonly<T>;
}

const immutablePerson = deepFreeze({
  name: 'Haskell',
  address: { country: 'US' }
});
// immutablePerson.address.country = 'UK'; // Error: ディープフリーズで保護
```

### パターン3: 値オブジェクト（Value Object）パターン

```typescript
// クロージャを使ったカプセル化された不変オブジェクト
function createZipCode(code: string, location: string = '') {
  // プライベート変数（クロージャで保護）
  const _code = code;
  const _location = location;

  return Object.freeze({
    code: () => _code,
    location: () => _location,
    fromString: (str: string) => {
      const [c, l] = str.split('-');
      return createZipCode(c, l);
    },
    toString: () => `${_code}-${_location}`
  });
}

const zip = createZipCode('08544', '3345');
zip.toString(); // '08544-3345'
// zip.code = 'xxx'; // Error: オブジェクトはfrozen
```

### パターン4: コピーオンライト（Copy-on-Write）

```typescript
// 変更の代わりに新しいオブジェクトを返す
function createCoordinate(lat: number, lon: number) {
  return Object.freeze({
    latitude: () => lat,
    longitude: () => lon,
    // 変換後の新しいオブジェクトを返す（元を変更しない）
    translate: (dx: number, dy: number) =>
      createCoordinate(lat + dx, lon + dy),
    toString: () => `(${lat},${lon})`
  });
}

const greenwich = createCoordinate(51.4778, 0.0015);
const moved = greenwich.translate(10, 10); // 新しいオブジェクト
console.log(greenwich.toString()); // '(51.4778,0.0015)' 変わらない
console.log(moved.toString());    // '(61.4778,10.0015)'
```

---

## クロージャとレキシカルスコープ

### クロージャによる状態管理

```typescript
// クロージャ: 外側のスコープの変数を記憶する関数
function createCounter(initial: number = 0) {
  let count = initial; // クロージャで捕捉

  return {
    increment: () => ++count,
    decrement: () => --count,
    value: () => count,
    reset: () => { count = initial; }
  };
}

const counter = createCounter(10);
counter.increment(); // 11
counter.increment(); // 12
counter.value();     // 12
```

### レキシカルスコープとカリー化の関係

```typescript
// レキシカルスコープ: 関数が定義された場所でスコープが決まる
function createMultiplier(factor: number) {
  // factor はクロージャで捕捉
  return function(number: number): number {
    return number * factor; // factorはレキシカルスコープから参照
  };
}

const double = createMultiplier(2);
const triple = createMultiplier(3);

double(5); // 10
triple(5); // 15
```

### 副作用の分離パターン

```typescript
interface Student {
  firstname: string;
  lastname: string;
  gpa: number;
}

// 純粋な関数（テスト容易）
const processStudents = (students: Student[]): string[] =>
  students
    .filter(s => s.gpa >= 3.0)
    .map(s => `${s.firstname} ${s.lastname}`);

// 不純な関数（IO）は境界に集める
const renderToList = (container: Element, items: string[]): void => {
  // XSSを避けるためにtextContentを使用
  container.replaceChildren(
    ...items.map(item => {
      const li = document.createElement('li');
      li.textContent = item; // innerHTMLは使用しない（XSSリスク）
      return li;
    })
  );
};

// 組み合わせ: 純粋処理→不純な出力
const showStudents = (students: Student[]): void => {
  const processed = processStudents(students); // テスト可能
  const container = document.querySelector('#student-list');
  if (container) renderToList(container, processed); // IOは境界で
};
```

---

## 参照透過性と等式推論

```typescript
// 参照透過: 関数呼び出しをその戻り値で置き換え可能
const add = (a: number, b: number): number => a + b;

// add(3, 4) を 7 で置き換えても結果が変わらない
const result1 = add(3, 4) + add(2, 1); // 10
const result2 = 7 + 3;                  // 10（等価）

// 参照透過でない例（副作用があるため等式推論不可）
let x = 0;
const impure = (n: number): number => {
  x += n; // 外部状態を変更（副作用）
  return n * 2;
};
// impure(3) + impure(3) ≠ 6 + 6（xが変わるため）
```

### 参照透過性の確認テスト

```typescript
// 参照透過な関数のテストはシンプル
describe('add', () => {
  it('同じ入力に対して常に同じ結果を返す', () => {
    expect(add(3, 4)).toBe(7);
    expect(add(3, 4)).toBe(7); // 何度呼んでも同じ
    expect(add(3, 4)).toBe(7);
  });
});
```

---

## まとめ: FP移行のチェックリスト

```
関数設計の確認:
[ ] 関数は同じ入力に対して常に同じ出力を返すか？
[ ] 外部変数を変更していないか？
[ ] グローバル状態を参照していないか？
[ ] DOM・ネットワーク等のIO操作を関数内に混在させていないか？

データ管理の確認:
[ ] Object.freeze() または deepFreeze() を使用しているか？
[ ] 変更の代わりに新しいオブジェクト/配列を返しているか？
[ ] const を積極的に使用しているか？

構造設計の確認:
[ ] 副作用は関数の境界（入口・出口）に集まっているか？
[ ] 純粋関数と不純な関数（IO）が明確に分離されているか？
[ ] 関数は単一の責任を持っているか？
```
