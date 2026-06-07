# 4章　型設計

優れた型設計は、コードの正確性を高め、バグを防ぎ、開発体験を向上させます。

---

## 項目29　有効な状態のみ表現する型を作る

**判断基準**: 有効な状態と不正な状態の両方を許容する型は、混乱を招きエラーを起こしやすい。有効な状態のみを表現する型を作る。

```typescript
// ❌ 不正な状態を許容
interface State {
  pageText: string | undefined;
  isLoading: boolean;
  error: string | undefined;
}
// { isLoading: true, error: 'error' } のような不正な状態が可能

// ✅ 有効な状態のみ表現
type State =
  | { status: 'loading' }
  | { status: 'success'; pageText: string }
  | { status: 'error'; error: string };

function renderPage(state: State) {
  switch (state.status) {
    case 'loading':
      return 'Loading...';
    case 'success':
      return state.pageText;  // pageText は確実に存在
    case 'error':
      return state.error;
  }
}
```

### 覚えておくべきこと
- 有効な状態と不正な状態の両方を許容する型は、混乱を招きエラーを起こしやすい
- 有効な状態のみ表現する型を作る。たとえ長くなっても表現が難しくなっても、最終的には時間と労力を節約できる

---

## 項目30　入力には寛容に、出力には厳格に

**判断基準**: 入力の型は出力の型より広くする。オプションプロパティやユニオン型は、戻り値の型よりパラメーターの型によく現れる。

```typescript
// 正規の形式（戻り値の型に使用）
interface Position {
  x: number;
  y: number;
}

// 寛容な形式（パラメーターの型に使用）
interface LoosePosition {
  x: number | string;
  y: number | string;
}

function setCamera(position: LoosePosition): Position {
  // 入力を正規化
  return {
    x: typeof position.x === 'number' ? position.x : parseFloat(position.x),
    y: typeof position.y === 'number' ? position.y : parseFloat(position.y)
  };
}

// ✅ 様々な入力を受け入れる
setCamera({ x: 10, y: 20 });
setCamera({ x: '10', y: '20' });

// パラメーターに対して反復処理を行う場合
function processItems<T>(items: Iterable<T>) {  // T[] より寛容
  for (const item of items) {
    // 処理
  }
}
```

### 覚えておくべきこと
- 入力の型は一般的に出力の型より広くする
- 戻り値に広い型を用いるのは、クライアントから使いにくくなるため避ける
- パラメーターの型と戻り値の型の間で型を再利用できるよう、正規の形式と寛容な形式を導入する
- 関数のパラメーターに対して反復処理を行うだけなら、`T[]`ではなく`Iterable<T>`をパラメーターの型に使う

---

## 項目31　型情報をドキュメントで繰り返さない

**判断基準**: コメントで型情報を繰り返すと重複と不整合が生じる。型宣言自体にドキュメントとしての役割を持たせる。

```typescript
// ❌ 型情報を繰り返す
/**
 * 色を返します
 * @param {string} color - 色名
 * @returns {string} RGB文字列
 */
function getColor(color: string): string { /* ... */ }

// ✅ 型に任せて簡潔に
/**
 * 色名をRGB値に変換します
 */
function getColor(color: string): RGBColor { /* ... */ }

// ❌ コメントで不変を説明
// このパラメーターを変更しないでください
function process(data: Data[]) { /* ... */ }

// ✅ readonly で宣言
function process(data: readonly Data[]) { /* ... */ }

// 単位が不明な場合は変数名に含める
interface Temperature {
  temperatureC: number;  // 摂氏
  timeMs: number;        // ミリ秒
}
```

### 覚えておくべきこと
- コメントや変数名での型情報の繰り返しを避ける。良くても型宣言の重複になり、悪ければ情報の不整合を引き起こす
- パラメーターを変更しないとコメントで述べる代わりに、`readonly`と宣言する
- 単位が型から明らかでない場合は、変数名に単位を含めることを検討する

---

## 項目32　`null`や`undefined`を型エイリアスに含めない

**判断基準**: 型エイリアスに`null`や`undefined`を含めると、使用する側で常にnullチェックが必要になり、APIが使いにくくなる。

```typescript
// ❌ 型エイリアスに null を含める
type Extent = [number, number] | null;

function getExtent(nums: number[]): Extent {
  let min = null;
  let max = null;
  // min が 0 のとき上書きされる問題
  for (const num of nums) {
    if (!min) min = num;
    if (!max) max = num;
    if (num < min) min = num;
    if (num > max) max = num;
  }
  if (min === null || max === null) return null;
  return [min, max];
}

// ✅ null を型の外側に
type Extent = [number, number];

function getExtent(nums: number[]): Extent | null {
  if (nums.length === 0) return null;

  let min = nums[0];
  let max = nums[0];
  for (const num of nums) {
    if (num < min) min = num;
    if (num > max) max = num;
  }
  return [min, max];
}
```

### 覚えておくべきこと
- `null`や`undefined`を含む型エイリアスを定義するのを避ける

---

## 項目33　`null`値を型の外側に押しやる

**判断基準**: ある値の`null`と別の値の`null`が暗黙的に関連する設計を避ける。オブジェクト全体を`null`または非`null`にする。

```typescript
// ❌ 暗黙的な関連
interface UserInfo {
  name: string | null;
  age: number | null;
}
// name が null なのに age が非 null、という不整合が可能

// ✅ 全体を null または非 null に
interface UserInfo {
  name: string;
  age: number;
}

function getUserInfo(id: string): UserInfo | null {
  // ユーザーが見つからなければ null を返す
  // 見つかれば完全な UserInfo を返す
}

// クラスの場合
class UserInfo {
  constructor(
    public readonly name: string,
    public readonly age: number
  ) {}

  static create(id: string): UserInfo | null {
    // すべての値が利用可能になってからインスタンス化
  }
}
```

### 覚えておくべきこと
- ある値が`null`または非`null`であることが、別の値の`null`と暗黙的に関連する設計を避ける
- `null`値をAPIの外側に押しやり、オブジェクトが完全に`null`または非`null`になるようにする
- 完全に非`null`なクラスを作り、すべての値が利用可能になってからそのインスタンスを生成することを検討する

---

## 項目34　ユニオンを含むインターフェイスよりも、インターフェイスのユニオンを選択する

**判断基準**: 複数のユニオン型のプロパティを持つインターフェイスは、しばしば間違い。インターフェイスのユニオンを使用する。

```typescript
// ❌ ユニオンを含むインターフェイス
interface Layer {
  layout: 'fill' | 'line' | 'point';
  paint: FillPaint | LinePaint | PointPaint;
}
// layout が 'fill' なのに paint が LinePaint、という不整合が可能

// ✅ インターフェイスのユニオン（タグ付きユニオン）
type Layer =
  | { type: 'fill'; layout: FillLayout; paint: FillPaint }
  | { type: 'line'; layout: LineLayout; paint: LinePaint }
  | { type: 'point'; layout: PointLayout; paint: PointPaint };

function drawLayer(layer: Layer) {
  switch (layer.type) {
    case 'fill':
      // layer.paint は FillPaint と確定
      applyFillPaint(layer.paint);
      break;
    case 'line':
      // layer.paint は LinePaint と確定
      applyLinePaint(layer.paint);
      break;
    case 'point':
      // layer.paint は PointPaint と確定
      applyPointPaint(layer.paint);
      break;
  }
}
```

### 覚えておくべきこと
- 複数のユニオン型のプロパティを持つインターフェイスは、しばしば間違い。プロパティ間の関係を明確に表現できていない
- インターフェイスのユニオンはより正確で、TypeScriptも正しく理解できる
- 制御フロー解析を容易にするため、タグ付きユニオンを使用する
- データをより正確にモデリングするため、複数のオプションプロパティをグループ化できないか検討する

---

## 項目35　`string`よりもそれに代わる、より精度の高い型を選択する

**判断基準**: 「stringly typed」なコードを避ける。あらゆる`string`を受け入れるわけでない場合は、より適切な型を選ぶ。

```typescript
// ❌ string を使いすぎ
function playMusic(track: string, volume: string) { }

// ✅ 文字列リテラル型のユニオン
type MediaType = 'audio' | 'video' | 'image';
type Volume = 'low' | 'medium' | 'high';

function playMusic(track: MediaType, volume: Volume) { }

// ✅ keyof を使用
interface Album {
  artist: string;
  title: string;
  releaseDate: Date;
}

function getAlbumValue<K extends keyof Album>(album: Album, key: K): Album[K] {
  return album[key];
}

// ❌ string を使用
function getAlbumValue(album: Album, key: string): any {
  return album[key];  // 型安全でない
}
```

### 覚えておくべきこと
- 「stringly typed」なコードを避ける。あらゆる`string`を受け入れるわけでない場合は、より適切な型を選ぶ
- `string`より文字列リテラル型のユニオンを使用する。型チェックが厳しくなり、開発体験が向上する
- オブジェクトのプロパティ名であることが期待される関数パラメーターには、`string`ではなく`keyof T`を使用する

---

## 項目36　特別な値には専用の型を使用する

**判断基準**: 通常のケースで用いられる値を特別な意味で使用するのを避ける。`null`や`undefined`、タグ付きユニオンを使用する。

```typescript
// ❌ 特別な値として -1 や 0 を使用
function indexOf(arr: string[], target: string): number {
  for (let i = 0; i < arr.length; i++) {
    if (arr[i] === target) return i;
  }
  return -1;  // 「見つからない」を -1 で表現
}

// ✅ null または undefined を使用
function indexOf(arr: string[], target: string): number | null {
  for (let i = 0; i < arr.length; i++) {
    if (arr[i] === target) return i;
  }
  return null;  // 「見つからない」を明示的に表現
}

// ✅ タグ付きユニオン（より詳細な情報が必要な場合）
type SearchResult =
  | { success: true; index: number }
  | { success: false; reason: 'not-found' | 'invalid-input' };

function indexOf(arr: string[], target: string): SearchResult {
  if (!target) {
    return { success: false, reason: 'invalid-input' };
  }
  for (let i = 0; i < arr.length; i++) {
    if (arr[i] === target) {
      return { success: true, index: i };
    }
  }
  return { success: false, reason: 'not-found' };
}
```

### 覚えておくべきこと
- 通常のケースで用いられる値を特別な意味で使用するのを避ける。そのような特別な値は、TypeScriptがバグを発見する能力を低下させる
- `0`、`-1`、`""`の代わりに、`null`や`undefined`を特別な値として使用する
- `null`や`undefined`では意味するところが明確にならない状況では、タグ付きユニオンの使用を検討する

---

## 項目37　オプションプロパティは限定的に使用する

**判断基準**: オプションプロパティは型チェッカーがバグを発見するのを妨げ、デフォルト値を埋めるコードの繰り返しを招く。必須プロパティにできないかよく考える。

```typescript
// ❌ オプションプロパティが多い
interface DrawOptions {
  x?: number;
  y?: number;
  width?: number;
  height?: number;
  opacity?: number;
  lineWidth?: number;
}
// x, y, width, height の組み合わせが曖昧

// ✅ 必須プロパティにする
interface Rectangle {
  x: number;
  y: number;
  width: number;
  height: number;
}

interface DrawOptions {
  rect: Rectangle;
  opacity?: number;  // 真にオプショナルなもののみ
  lineWidth?: number;
}

// ✅ 正規化された型と正規化されていない型を分ける
interface DrawOptionsInput {
  rect?: Rectangle;
  opacity?: number;
  lineWidth?: number;
}

interface DrawOptions {
  rect: Rectangle;
  opacity: number;
  lineWidth: number;
}

function normalizeOptions(input: DrawOptionsInput): DrawOptions {
  return {
    rect: input.rect ?? { x: 0, y: 0, width: 100, height: 100 },
    opacity: input.opacity ?? 1.0,
    lineWidth: input.lineWidth ?? 1
  };
}
```

### 覚えておくべきこと
- オプションプロパティは型チェッカーがバグを発見するのを妨げ、デフォルト値を埋めるコードの繰り返しや一貫性の欠如を招く
- インターフェイスにオプションプロパティを追加する前に、本当にそれを必須プロパティにできないかよく考える
- 正規化されていない入力データと正規化されたデータを表現するため、それぞれ別の型を作成することを検討する
- オプションの組み合わせ爆発を避ける

---

## 項目38　同じ型のパラメーターの繰り返しを避ける

**判断基準**: 同じ型のパラメーターを連続して受け取る関数は、引数の順番を間違えやすい。リファクタリングして単一のオブジェクトパラメーターを受け取るようにする。

```typescript
// ❌ 同じ型のパラメーターが連続
function drawRect(x: number, y: number, width: number, height: number) {
  // x と width を間違える可能性
}

// ✅ オブジェクトパラメーター
interface Rectangle {
  x: number;
  y: number;
  width: number;
  height: number;
}

function drawRect(rect: Rectangle) {
  // 各パラメーターに名前が付いているので間違えにくい
}

// 呼び出し側も明確
drawRect({ x: 10, y: 20, width: 100, height: 50 });
```

### 例外: 引数の順番が交換可能または自然な順番がある場合
```typescript
// 交換可能な場合は問題ない
function max(a: number, b: number): number { }
function isEqual(a: string, b: string): boolean { }

// 自然な順番がある場合
function slice(start: number, end: number) { }
```

### 覚えておくべきこと
- 同じ型のパラメーターを連続して受け取る関数を書かない
- 多くのパラメーターを受け取る関数をリファクタリングし、少数の異なる型を持つパラメーター、または単一のオブジェクトパラメーターを受け取るようにする

---

## 項目39　差異のモデリングより型の統一を優先する

**判断基準**: 同じ型の異なるバリエーションを持つことは認知的オーバーヘッドを生み、多くの変換コードを必要とする。型を統一できるようにする。

```typescript
// ❌ データソースごとに異なる型
interface DatabaseUser {
  user_id: number;
  user_name: string;
  created_at: Date;
}

interface APIUser {
  userId: number;
  userName: string;
  createdAt: string;
}

// ✅ 統一された型
interface User {
  userId: number;
  userName: string;
  createdAt: Date;
}

// データソース層でアダプターを用意
function fromDatabase(dbUser: DatabaseUser): User {
  return {
    userId: dbUser.user_id,
    userName: dbUser.user_name,
    createdAt: dbUser.created_at
  };
}

function fromAPI(apiUser: APIUser): User {
  return {
    userId: apiUser.userId,
    userName: apiUser.userName,
    createdAt: new Date(apiUser.createdAt)
  };
}
```

### 覚えておくべきこと
- 同じ型の異なるバリエーションを持つことは、認知的オーバーヘッドを生み、多くの変換コードを必要とする
- 型のわずかな違いをモデリングするより、違いを排除して単一の型に統一できるようにする
- 型を統一するためには、ランタイムコードの調整が必要になる場合がある
- 型が自分の管理下になければ、違いをモデリングする必要があるかもしれない
- 同じものを表現していない型は統一しない

---

## 項目40　正確でない型より精度の低い型を選択する

**判断基準**: 複雑で不正確な型は、シンプルで精度の低い型より悪い。型を正確にモデリングできないときは、ギャップを受け入れ、`any`や`unknown`を使用する。

```typescript
// ❌ 複雑で不正確な型
type Expression = number | string | CallExpression;
interface CallExpression {
  fn: Expression;
  args: Expression[];
}
// 無限にネストした型を生成し、型チェッカーのパフォーマンスを悪化させる

// ✅ シンプルで精度の低い型
type Expression = any;

// または
type Expression = unknown;
```

### 覚えておくべきこと
- 型安全性の不気味の谷を避ける。複雑で不正確な型は、シンプルで精度の低い型より悪いことが多い
- 型を正確にモデリングできないとき、不正確なモデルを採用しない。ギャップを受け入れ、`any`や`unknown`を使用する
- 型の精度を向上させる際、エラーメッセージやオートコンプリートにも注意を払う。型の正確さだけでなく、開発者体験も考慮する
- 型が複雑になるのに合わせて、テストスイートを拡張する

---

## 項目41　ドメインの言語を使って型を命名する

**判断基準**: コードの可読性と抽象度を高めるため、可能なかぎり扱っているドメインで使われる名前を再利用する。

```typescript
// ❌ 曖昧な名前
interface Animal {
  name: string;  // どのような名前？学名？一般名？
  endangered: boolean;  // 絶滅したらどうする？
  habitat: string;  // 非常に曖昧
}

// ✅ ドメインの言語を使用
interface Animal {
  commonName: string;  // 一般名
  genus: string;       // 属
  species: string;     // 種
  status: ConservationStatus;  // IUCN の標準分類
  climates: Climate[];         // ケッペンの気候区分
}

type ConservationStatus =
  | 'least-concern'
  | 'near-threatened'
  | 'vulnerable'
  | 'endangered'
  | 'critically-endangered'
  | 'extinct-in-wild'
  | 'extinct';

type Climate = 'tropical' | 'dry' | 'temperate' | 'continental' | 'polar';
```

### 命名のガイドライン
- 区別に意味を持たせる。同義語を使う場合、その区別に意味があることを確認する
- 「Data」「Info」「Thing」「Item」「Object」「Entity」のような曖昧で意味のない名前を避ける
- 何を持つかやどうやって作られたかよりも、何であるかに基づいて命名する

### 覚えておくべきこと
- コードの可読性と抽象度を高めるため、可能なかぎり扱っているドメインで使われる名前を再利用する
- 同じものに対して異なる名前を使うことを避ける。名前の区別に意味を持たせる
- 「Info」や「Entity」のような曖昧な名前を避ける。型の形状ではなく、その型が何であるかに基づいて命名する

---

## 項目42　たまたま目にしたデータに基づく型を避ける

**判断基準**: たまたま目にしたデータに基づいて自ら型を書くことを避ける。スキーマから型を生成するか、公式のクライアントや型を使用する。

```typescript
// ❌ APIレスポンスの例から型を手書き
interface User {
  id: number;
  name: string;
  email: string;
}
// null の可能性、オプションプロパティの見落とし

// ✅ スキーマから型を生成
// OpenAPI/Swagger から生成
import { User } from './generated/api';

// ✅ 公式クライアントの型を使用
import { Octokit } from '@octokit/rest';
type RepoInfo = Awaited<ReturnType<Octokit['repos']['get']>>['data'];

// ✅ JSON Schema から生成
// json-schema-to-typescript などのツールを使用
```

### 覚えておくべきこと
- たまたま目にしたデータに基づいて自ら型を書くことを避ける。スキーマを誤解したり、`null`の可能性を間違えたりしやすい
- 公式のクライアントやコミュニティが提供する型を使う。そのような型が存在しない場合は、スキーマから型を生成する

---

## 型設計チェックリスト

設計時に以下を確認してください：

### 1. 状態の表現
- [ ] 有効な状態のみ表現する型になっているか？
- [ ] 不正な状態を許容していないか？
- [ ] タグ付きユニオンを使用できないか？

### 2. null/undefined の扱い
- [ ] `null`値を型の外側に押しやっているか？
- [ ] オブジェクト全体を`null`または非`null`にしているか？
- [ ] 型エイリアスに`null`や`undefined`を含めていないか？

### 3. 型の構造
- [ ] インターフェイスのユニオンとユニオンを含むインターフェイスのどちらが適切か検討したか？
- [ ] 複数のオプションプロパティをグループ化できないか？
- [ ] オプションプロパティを本当に必須プロパティにできないか？

### 4. 精度と表現力
- [ ] `string`より具体的な型（文字列リテラル型のユニオン、`keyof`）を使用できないか？
- [ ] 特別な値に専用の型（`null`、タグ付きユニオン）を使用しているか？
- [ ] 型は正確すぎて複雑になっていないか？

### 5. API設計
- [ ] 入力には寛容に、出力には厳格になっているか？
- [ ] 同じ型のパラメーターが連続していないか？
- [ ] 型の統一を優先しているか？

### 6. 命名とドキュメント
- [ ] ドメインの言語を使用しているか？
- [ ] 曖昧な名前（Info、Entity等）を避けているか？
- [ ] 型情報をコメントで繰り返していないか？
- [ ] 単位が不明な場合、変数名に単位を含めているか？

### 7. 型の生成
- [ ] たまたま目にしたデータに基づいて手書きしていないか？
- [ ] スキーマや公式クライアントの型を使用しているか？
