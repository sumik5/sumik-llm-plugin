# JavaScript関数型プログラミング実践（Part 3: 実践テクニックのスキルアップ）

関数型コードのテスト手法・最適化・非同期処理・リアクティブプログラミングの実践パターン。
基本的なPromise/Observable/AsyncIteratorはDP-FUNCTIONAL-REACTIVE.mdを参照。本ファイルはJS固有の最適化とテスト戦略に焦点を当てる。

---

## 関数型コードのユニットテスト

### 純粋関数のテスト戦略

```typescript
// 純粋関数: 入力と出力だけに注目すればテスト可能
const computeAverageGrade = (grades: number[]): string => {
  const avg = grades.reduce((sum, g) => sum + g, 0) / grades.length;
  if (avg >= 90) return 'A';
  if (avg >= 80) return 'B';
  if (avg >= 70) return 'C';
  if (avg >= 60) return 'D';
  return 'F';
};

// シンプルなテスト（モック不要）
describe('computeAverageGrade', () => {
  it('平均90点以上はA', () => {
    expect(computeAverageGrade([80, 90, 100])).toBe('A');
  });
  it('負の点数はF', () => {
    expect(computeAverageGrade([-10])).toBe('F');
  });
  // 参照透過性の確認: 同じ入力→同じ出力
  it('同じ入力は常に同じ結果', () => {
    const grades = [85, 90, 95];
    const result1 = computeAverageGrade(grades);
    const result2 = computeAverageGrade(grades);
    expect(result1).toBe(result2);
  });
});
```

### 命令型 vs 関数型のテスト可能性比較

```typescript
// 命令型: 副作用が混在しテストが困難
class ImperativeStudentProcessor {
  process(ssn: string): void {
    // DB参照・バリデーション・DOM操作が一緒に
    const student = db.find(ssn);
    if (!student) { alert('Not found'); return; }
    document.querySelector('#info')!.textContent = student.name;
  }
  // テストには: DBモック + DOMモック + alertモック が必要
}

// 関数型: 純粋な関数を分離してテストを容易に
const cleanInput = (str: string): string => str.replace(/-/g, '').trim();
const checkLength = (ssn: string): boolean => ssn.length === 9;
const formatStudent = (s: { name: string; ssn: string }): string =>
  `${s.name} (${s.ssn})`;

// 各関数を独立してテスト
describe('cleanInput', () => {
  test.each([
    [' 444-44-4444 ', '444444444'],
    ['  4  4 4 ', '444'],
    ['', ''],
  ])('"%s" -> "%s"', (input, expected) => {
    expect(cleanInput(input)).toBe(expected);
  });
});
```

### モナドの状態をテスト

```typescript
// Either の isLeft/isRight でモナド内容をアサート
describe('validateSsn', () => {
  it('有効なSSNはRight', () => {
    const result = validateSsn('444444444');
    expect(result.isRight()).toBe(true);
  });

  it('空文字はLeft（エラー情報付き）', () => {
    const result = validateSsn('');
    expect(result.isLeft()).toBe(true);
  });

  it('8桁はLeft', () => {
    const result = validateSsn('44444444');
    expect(result.isLeft()).toBe(true);
  });
});
```

### 外部依存のモック（副作用のテスト）

```typescript
// Vitestでの依存性モック
import { vi } from 'vitest';

// カリー化でモックを注入
const fetchStudent = (store: { get: (id: string) => Student | null }) =>
  (id: string): Student | null => store.get(id);

describe('fetchStudent', () => {
  it('Rightを返す（学生が見つかった場合）', () => {
    const mockStore = { get: vi.fn().mockReturnValue({ name: 'Alice', ssn: '111111111' }) };
    const find = fetchStudent(mockStore);
    const student = find('111111111');
    expect(student).not.toBeNull();
    expect(mockStore.get).toHaveBeenCalledOnce();
  });

  it('nullを返す（学生が見つからない場合）', () => {
    const mockStore = { get: vi.fn().mockReturnValue(null) };
    const find = fetchStudent(mockStore);
    expect(find('xxx-xx-xxxx')).toBeNull();
  });
});
```

---

## プロパティベーステスト

### 概念: 具体例から仕様（プロパティ）へ

```
従来のユニットテスト:
  「入力A → 出力B」という具体的なケースを手動で列挙

プロパティベーステスト:
  「任意の入力Xに対して、常に条件Yが成立する」という普遍的な仕様をテスト
  ランダムに大量のテストケースを自動生成して検証
```

### fast-check を使ったプロパティテスト

```typescript
import * as fc from 'fast-check';

// プロパティ1: 平均90点以上 → 必ずAが返る（if-and-only-if）
it('90-100の範囲のグレードは必ずAになる', () => {
  fc.assert(
    fc.property(
      fc.array(fc.float({ min: 90, max: 100 }), { minLength: 1 }),
      (grades) => computeAverageGrade(grades) === 'A'
    )
  );
});

// プロパティ2: 90未満の平均ではAにならない
it('90未満の平均はAにならない', () => {
  fc.assert(
    fc.property(
      fc.array(fc.float({ min: 0, max: 89.99 }), { minLength: 1 }),
      (grades) => computeAverageGrade(grades) !== 'A'
    )
  );
});

// プロパティ3: 加算の交換法則
it('加算は交換法則を満たす', () => {
  fc.assert(
    fc.property(
      fc.integer(),
      fc.integer(),
      (a, b) => add(a, b) === add(b, a)
    )
  );
});
```

### プロパティベーステストが有効なシナリオ

| シナリオ | プロパティの例 |
|---------|--------------|
| 数学的演算 | 交換法則・結合法則 |
| エンコード/デコード | `decode(encode(x)) === x` |
| ソート | 結果が常にソート済み |
| 正規化 | `normalize(normalize(x)) === normalize(x)`（冪等性） |
| バリデーション | 有効な入力のみを通過させる |

---

## メモ化（Memoization）による最適化

### 基本実装

```typescript
// 純粋関数専用のメモ化ラッパー
function memoize<Args extends unknown[], R>(
  fn: (...args: Args) => R
): (...args: Args) => R {
  const cache = new Map<string, R>();

  return (...args: Args): R => {
    const key = JSON.stringify(args);

    if (cache.has(key)) {
      return cache.get(key)!; // キャッシュヒット
    }

    const result = fn(...args);
    cache.set(key, result);   // キャッシュに保存
    return result;
  };
}

// 計算コストの高い関数に適用
const expensiveCompute = memoize((n: number): number => {
  // 複雑な計算（例: ROT13エンコード）
  return n * n + n; // 簡略化
});

console.time('first');
expensiveCompute(1000); // 計算実行
console.timeEnd('first'); // ~0.7ms

console.time('second');
expensiveCompute(1000); // キャッシュから即返却
console.timeEnd('second'); // ~0.02ms
```

### カリー化との組み合わせ

```typescript
// 多引数関数は先にカリー化してからメモ化
const fetchStudent = (storeId: string) =>
  memoize((ssn: string): Student | null => {
    // 高コストなDB検索（同一storeIdとssnの組み合わせはキャッシュ）
    return store.get(storeId, ssn);
  });

const findFromStudentDB = fetchStudent('students');
findFromStudentDB('444-44-4444'); // DB検索
findFromStudentDB('444-44-4444'); // キャッシュから即返却
```

### 再帰へのメモ化適用

```typescript
// メモ化で再帰のパフォーマンスを劇的に改善
const factorial = memoize((n: number): number => {
  if (n <= 1) return 1;
  return n * factorial(n - 1);
});

factorial(100);  // ~0.3ms (100フレーム分の再帰)
factorial(101);  // ~0.02ms (101 × cached(100) だけ計算)
// 101! = 101 × 100! なので、100!はキャッシュから再利用

// ⚠️ メモ化の制限
// - 引数がJSONシリアライズ可能な場合のみ正確なキーを生成
// - 副作用のある関数には使用しない（参照透過性が前提）
// - 循環参照オブジェクトはJSON.stringifyが失敗
```

### メモ化の判断基準

```
メモ化を検討すべき状況:
✅ 純粋関数（参照透過）である
✅ 計算コストが高い（CPU集約型）
✅ 同じ引数で繰り返し呼ばれる可能性がある
✅ 結果が時間経過で変わらない

メモ化を避けるべき状況:
❌ 副作用のある関数
❌ 引数が毎回異なる場合（キャッシュが膨大になる）
❌ メモリが制約されている環境
❌ 非同期処理（別途Promise対応のメモ化が必要）
```

---

## 末尾再帰最適化（TCO）

```typescript
// 通常の再帰: スタックが積み上がる
function factorialNaive(n: number): number {
  if (n <= 1) return 1;
  return n * factorialNaive(n - 1); // 末尾でない（乗算が残る）
}
// factorialNaive(100000) → スタックオーバーフロー

// 末尾再帰: 最後の操作が再帰呼び出しのみ
function factorialTail(n: number, acc: number = 1): number {
  if (n <= 1) return acc;
  return factorialTail(n - 1, n * acc); // 末尾位置
}
// ES6 TCOが有効な場合は単一スタックフレームで実行

// ⚠️ JavaScript/TypeScriptの注意点
// TCOはES6仕様だがほとんどのエンジン（V8含む）では未実装
// 大きな入力には trampoline パターンを使用

// Trampolineパターン: TCOをエミュレート
type Thunk<T> = () => T | Thunk<T>;

function trampoline<T>(fn: Thunk<T>): T {
  let result: T | Thunk<T> = fn;
  while (typeof result === 'function') {
    result = (result as Thunk<T>)();
  }
  return result;
}

// Trampolineを使った安全な再帰
const factorialSafe = (n: number, acc = 1): number | Thunk<number> =>
  n <= 1 ? acc : () => factorialSafe(n - 1, n * acc);

trampoline(() => factorialSafe(100000)); // スタックオーバーフローなし
```

---

## ES6ジェネレータと遅延評価

### 無限シーケンスの遅延生成

```typescript
// ジェネレータ: 必要な時だけデータを生成（遅延評価）
function* range(start = 0, end = Number.POSITIVE_INFINITY): Generator<number> {
  for (let i = start; i < end; i++) {
    yield i; // 呼び出された時だけ値を提供
  }
}

// 無限シーケンスから最初の5つだけ取得
function take<T>(n: number, gen: Generator<T>): T[] {
  const result: T[] = [];
  for (const value of gen) {
    result.push(value);
    if (result.length >= n) break;
  }
  return result;
}

take(5, range(1)); // [1, 2, 3, 4, 5]

// 2乗数の遅延ストリーム
function* squares(start = 1): Generator<number> {
  for (let n = start; ; n++) {
    yield n * n;
  }
}

take(5, squares()); // [1, 4, 9, 16, 25]
```

### ジェネレータによる木構造走査

```typescript
interface TreeNode {
  value: string;
  children?: TreeNode[];
}

// ジェネレータで深さ優先走査（再帰委譲）
function* depthFirstTraversal(node: TreeNode): Generator<string> {
  yield node.value;
  for (const child of node.children ?? []) {
    yield* depthFirstTraversal(child); // yield* で他のジェネレータに委譲
  }
}

const root: TreeNode = {
  value: 'Church',
  children: [
    { value: 'Rosser', children: [{ value: 'Mendelson' }] },
    { value: 'Turing' }
  ]
};

for (const name of depthFirstTraversal(root)) {
  console.log(name); // Church → Rosser → Mendelson → Turing
}
```

### ジェネレータ vs 配列

| 観点 | ジェネレータ | 配列 |
|------|------------|------|
| メモリ | 1要素分のみ | 全要素分 |
| 評価タイミング | 要求時（遅延） | 即時（早期） |
| 無限シーケンス | 対応可 | 不可 |
| 再使用 | 不可（使い捨て） | 可（何度でも） |
| パフォーマンス | 大規模データで有利 | 小規模データで有利 |

---

## RxJSリアクティブプログラミングの実践パターン

> 基本的なObservable/subscribeはDP-FUNCTIONAL-REACTIVE.mdを参照。
> 本セクションはFPとリアクティブの統合パターンに焦点を当てる。

### オブザーバブルを関数型パイプラインに統合

```typescript
import { Observable, from, of } from 'rxjs';
import { map, filter, reduce, catchError, mergeMap } from 'rxjs/operators';

interface Student { ssn: string; country: string; grade: number; }

// イベントストリームにFPパターンを適用
const studentsStream$: Observable<Student[]> = from(fetch('/students'))
  .pipe(
    mergeMap(res => res.json() as Promise<Student[]>),
    // 関数型フィルタリングをストリームに適用
    map(students => students.filter(s => s.country === 'US')),
    map(students => students.sort((a, b) => a.ssn.localeCompare(b.ssn))),
    catchError(err => {
      console.error('Error:', err);
      return of([]); // エラー時は空配列のストリームにフォールバック
    })
  );

studentsStream$.subscribe(students => {
  console.log('Fetched students:', students.length);
});
```

### Promise と Observable の使い分け

| 観点 | Promise | Observable |
|------|---------|-----------|
| 値の数 | 単一 | 複数（ストリーム） |
| キャンセル | 不可 | 可（unsubscribe） |
| 遅延実行 | 不可（即時実行） | 可（cold observable） |
| 演算子 | then/catch/finally | map/filter/merge等100+ |
| 推奨シーン | 1回きりのAPI呼び出し | イベント・ポーリング・WebSocket |

```typescript
// 適切な使い分け
import { firstValueFrom } from 'rxjs';

// 1回きりのAPI呼び出し → Promise（シンプル）
const user = await fetch('/api/user').then(r => r.json());

// 継続的なイベント → Observable
const clicks$ = fromEvent(button, 'click').pipe(
  debounceTime(300),
  map(e => (e.target as HTMLInputElement).value)
);

// ObservableをPromiseに変換（必要な場合）
const firstClick = await firstValueFrom(clicks$);
```

---

## 実践的なパフォーマンス最適化戦略

```
1. 純粋関数の分解（分解が細かいほどメモ化の恩恵が大きい）
   showStudent = cleanInput → checkLength → findStudent → csv → render
   ↓ 各ステップをメモ化すると前回呼び出しの結果を再利用

2. 遅延評価の活用
   大量データ: ジェネレータ or Lodash chains（中間配列を生成しない）
   UI更新: Observable + debounceTime（不要な再レンダリングを防ぐ）

3. キャッシュ戦略の選択
   - メモ化: 同一引数の繰り返し計算
   - Observable: ストリームのマルチキャスト（share/shareReplay）
   - WeakMap: オブジェクト参照をキーとするキャッシュ（GC対応）

4. 測定して最適化
   console.time / Performance API でホットスポットを特定してから適用
   闇雲なメモ化はメモリ圧迫の原因になる
```
