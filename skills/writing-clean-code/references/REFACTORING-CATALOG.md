# リファクタリングカタログ

## 概要

体系的リファクタリングとは、**ルール → パターンの機械的適用**というアプローチで、感覚や経験に頼らずコードを改善する手法である。

核心的な哲学は以下の一点に集約される：

> **コンパイラをチームメンバーとして扱う。その強みを設計に組み込み、弱みを避ける。**

ルールは「常に守るべき絶対的制約」ではなく、「コードを改善するための出発点（smell検出器）」として機能する。ルールに違反しているコードは、改善の機会を示すシグナルだ。

---

## 基本ルール一覧

| ルール | 内容 | 目的 |
|--------|------|------|
| **FIVE LINES** | 関数は「基本データ構造を通過するのに必要な行数」以内に保つ（目安: 5行） | 責務の明確化、抽象化レベルの統一 |
| **EITHER CALL OR PASS** | 関数はオブジェクトのメソッドを呼び出すか、引数として渡すかのどちらか一方のみ | 抽象化レベルの混在防止 |
| **IF ONLY AT START** | `if` を使う場合、それは関数の先頭に配置する | 早期リターン/ガード節パターンの強制 |
| **NEVER USE IF WITH ELSE** | `if-else` を使わない（自分が管理しない外部型との比較を除く） | ポリモーフィズムへの誘導 |
| **NEVER USE SWITCH** | `switch` は `default` なし・全 `case` に `return` あり・コンパイラが網羅性を検証する場合のみ許容 | 型安全な分岐の強制 |
| **ONLY INHERIT FROM INTERFACES** | 継承はインターフェースからのみ行う（クラスや抽象クラスからの継承禁止） | 継承階層の浅さと柔軟性を保証 |
| **DO NOT USE GETTERS OR SETTERS** | boolean 以外のフィールドを直接返却・代入するメソッドを使わない | 振る舞いをデータの近くに移動する圧力を生む |
| **NEVER HAVE COMMON AFFIXES** | メソッドや変数に共通の接頭辞・接尾辞を持たせない | カプセル化不足のシグナルとして検出 |
| **USE PURE CONDITIONS** | 条件式内で変数代入・例外発生・I/O操作を行わない | 副作用の分離、テスト容易性の向上 |
| **NO INTERFACE WITH ONLY ONE IMPLEMENTATION** | 実装クラスが1つだけのインターフェースを作らない | YAGNI・過剰設計の防止 |

### ルール適用の判断基準

```
違反を検出したら:
  → 意図的な違反か？（外部API制約・パフォーマンス要件）
  → Yes: コメントで理由を明記し、TODO/FIXMEでマーク
  → No: 該当リファクタリングパターンを適用
```

---

## ルール詳細

### FIVE LINES

**Why（なぜ必要か）**

長い関数は複数の責務を持つ。読者は関数全体を頭に入れながらコードを追う必要があり、認知負荷が高まる。5行という制約は、「この関数が一つのことをしているか」を機械的にチェックする指標として機能する。

```typescript
// Before: 22行の関数 — 在庫確認・料金計算・割引適用・決済・通知が混在
function processOrder(order: Order) {
  const stock = inventory.find(order.items);
  if (!stock || stock.quantity < order.quantity) {
    throw new Error("Out of stock");
  }
  let price = 0;
  for (const item of order.items) {
    price += item.unitPrice * item.quantity;
  }
  if (order.customer.isPremium) {
    price *= 0.9;
  }
  const tax = price * TAX_RATE;
  payment.charge(order.customer.cardId, price + tax);
  email.send(order.customer.email, "Order confirmed");
}

// After: 各責務が独立したメソッドに分離
function processOrder(order: Order) {
  validateStock(order);
  const total = calculateTotal(order);
  payment.charge(order.customer.cardId, total);
  notifyCustomer(order.customer);
}
```

**判断基準**
- ループのネスト・条件分岐がある → 抽出候補
- 空行で区切られたブロックがある → 各ブロックが一つのメソッド候補
- 例外: 単純なデータ変換・初期化のみの関数は5行を超えても許容

---

### EITHER CALL OR PASS

**Why（なぜ必要か）**

一つの関数内で、オブジェクトのメソッドを呼びながら（高レベル抽象）、同じオブジェクトをプロパティ参照（低レベル操作）すると、読者は二つの抽象化レベルを同時に追わなければならない。

```typescript
// Before: sum(arr) は高レベル抽象、arr.length は低レベル操作が混在
function average(arr: number[]) {
  return sum(arr) / arr.length;  // arr をメソッド呼び出しで使いつつ直接参照
}

// After: 抽象化レベルを統一
function average(arr: number[]) {
  return sum(arr) / size(arr);   // すべて高レベルのメソッド呼び出し
}

function size(arr: number[]): number {
  return arr.length;
}
```

**判断基準**
- 同一パラメータ/変数に `.method()` と直接プロパティアクセスが混在 → 違反
- 例外: プリミティブ型や標準ライブラリのプロパティアクセスは許容されることが多い

---

### IF ONLY AT START

**Why（なぜ必要か）**

`if` は「条件をチェックする」という一つの責務を持つ。ループや他の処理の途中に `if` が埋め込まれると、その関数は「繰り返し処理」と「条件チェック」の二つの責務を担ってしまう。

```typescript
// Before: ループの中に if が埋め込まれている
function reportPrimes(n: number) {
  for (let i = 2; i < n; i++)
    if (isPrime(i))
      console.log(`${i} is prime`);
}

// After: if を先頭に持つ関数に分離
function reportPrimes(n: number) {
  for (let i = 2; i < n; i++)
    reportIfPrime(i);
}

function reportIfPrime(n: number) {
  if (isPrime(n))
    console.log(`${n} is prime`);
}
```

**判断基準**
- `if` の前に別の処理（ループ、代入）がある → 違反
- `if` の後に別の処理がある → 違反（`else` で対応するか、後続処理を別関数に）
- 例外: ガード節（早期リターン）として関数先頭で使う場合はこのルールに準拠済み

---

### NEVER USE IF WITH ELSE

**Why（なぜ必要か）**

`if-else` は「型コード（種類を表す値）」に基づく分岐の多くを意味する。新しい種類が追加されると、すべての `if-else` チェーンを探して修正しなければならない（Open-Closed 原則違反）。ポリモーフィズムを使えば、新しいクラスを追加するだけで対応できる。

```typescript
// Before: 新しい InputType を追加するたびに、この else-if チェーンを探して修正が必要
function handleInput(input: InputType) {
  if (input === InputType.LEFT)        moveHorizontal(-1);
  else if (input === InputType.RIGHT)  moveHorizontal(1);
  else if (input === InputType.UP)     moveVertical(-1);
  else if (input === InputType.DOWN)   moveVertical(1);
}

// After: 新しい入力種類は新しいクラスを追加するだけ — 既存コードは変更不要
interface Input {
  handle(): void;
}
class Left  implements Input { handle() { moveHorizontal(-1); } }
class Right implements Input { handle() { moveHorizontal(1);  } }
class Up    implements Input { handle() { moveVertical(-1);   } }
class Down  implements Input { handle() { moveVertical(1);    } }

// 呼び出し側
function handleInput(input: Input) {
  input.handle();
}
```

**判断基準**
- `if-else` の各分岐が「型の種類」に基づく → Replace Type Code with Classes
- 例外: 自分が管理しない外部の型（ライブラリの戻り値など）との比較は許容
- 例外: `true/false` の二択でビジネスルールが単純な場合

---

### NEVER USE SWITCH

**Why（なぜ必要か）**

`switch` はフォールスルー（意図しない次 case への実行）のリスクがある。また、`default` がある `switch` はコンパイラが網羅性を検証できなくなる。

```typescript
// Before: default があるためコンパイラが網羅性を検証できない
switch (tile) {
  case Tile.STONE: drawStone(g, x, y); break;
  case Tile.BOX:   drawBox(g, x, y);   break;
  default:         drawAir(g, x, y);   // 新しい Tile を追加してもコンパイルエラーにならない
}

// After（許容される switch）: default なし・全 case に return
// TypeScript では never 型を使って網羅性を強制できる
function assertNever(x: never): never {
  throw new Error(`Unhandled case: ${x}`);
}

switch (tile) {
  case Tile.STONE: return drawStone(g, x, y);
  case Tile.BOX:   return drawBox(g, x, y);
  case Tile.AIR:   return drawAir(g, x, y);
  default:         return assertNever(tile);  // 網羅されていない case があればコンパイルエラー
}

// さらに良い: Replace Type Code with Classes でクラスポリモーフィズムに
```

**判断基準**
- `switch` に `default` がある → まず `assertNever` 相当の網羅性検証を追加
- `switch` の各 `case` が `break` を使っている → `return` に変えてフォールスルーを排除
- 最終的には Replace Type Code with Classes でクラスに変換することを検討

---

### ONLY INHERIT FROM INTERFACES

**Why（なぜ必要か）**

クラスから継承すると、基底クラスの非公開な実装詳細に依存する「もろい基底クラス問題」が発生する。新しいメソッドが基底クラスに追加されると、派生クラスが気づかずに誤った振る舞いを継承してしまう。

```typescript
// Before: クラス継承 — CommonBird に canSwim() が追加されたとき
//         Penguin は「泳げない」と自動的に仮定されてしまう
class CommonBird {
  hasBeak() { return true; }
  canFly()  { return true; }
  canSwim() { return false; }  // 新たに追加
}
class Penguin extends CommonBird {
  canFly() { return false; }   // canSwim の override を忘れた！
}

// After: インターフェース継承 + 合成
interface Bird {
  hasBeak(): boolean;
  canFly():  boolean;
  canSwim(): boolean;          // インターフェースに追加 → 全実装クラスでコンパイルエラー
}
class CommonBird implements Bird {
  hasBeak() { return true;  }
  canFly()  { return true;  }
  canSwim() { return false; }
}
class Penguin implements Bird {
  private bird = new CommonBird();      // 合成
  hasBeak() { return this.bird.hasBeak(); }
  canFly()  { return false; }
  canSwim() { return true;  }           // 明示的に override
}
```

**判断基準**
- `extends ClassName` がある → インターフェース + 合成に変換を検討
- 例外: フレームワーク提供の基底クラス（React.Component 等）は実用上許容
- 抽象クラスも避ける（共有ロジックが必要なら、コンポジションで委譲する）

---

### DO NOT USE GETTERS OR SETTERS

**Why（なぜ必要か）**

ゲッターを使ってデータを外部に取り出すと、そのデータに関するロジックが呼び出し側に散在する。データと振る舞いが分離し、変更時に複数箇所を修正しなければならなくなる。

```typescript
// Before: getHour() で取得した値に基づくロジックが呼び出し側に散在
class Clock {
  private hour: number;
  getHour(): number { return this.hour; }
}
// 呼び出し側に判断ロジックが漏れる
const h = clock.getHour();
const greeting = h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening";

// After: ロジックをデータの近くに押し込む
class Clock {
  private hour: number;
  getGreeting(): string {
    if (this.hour < 12) return "Good morning";
    if (this.hour < 18) return "Good afternoon";
    return "Good evening";
  }
}
// 呼び出し側はシンプル
const greeting = clock.getGreeting();
```

**判断基準**
- ゲッターの戻り値に基づく `if-else` が呼び出し側にある → ロジックをクラスに押し込む
- 例外: `boolean` の getter は許容（`isEnabled()`, `isEmpty()` 等）
- 例外: DTOやValueObject の純粋なデータ保持クラス

---

### NEVER HAVE COMMON AFFIXES

**Why（なぜ必要か）**

メソッド名や変数名に共通の接頭辞・接尾辞がある場合（例: `playerX`, `playerY`, `playerAlive`）、それらは一つのクラスに属すべきデータが散在しているシグナルだ。

```typescript
// Before: player という接頭辞が付いた変数が散在
let playerX = 0;
let playerY = 0;
let playerHealth = 100;
let playerAlive = true;

function movePlayerLeft()  { playerX -= 1; }
function movePlayerRight() { playerX += 1; }
function damagePlayer(n)   { playerHealth -= n; if (playerHealth <= 0) playerAlive = false; }

// After: Player クラスにカプセル化
class Player {
  private x = 0;
  private y = 0;
  private health = 100;
  private alive = true;

  moveLeft()       { this.x -= 1; }
  moveRight()      { this.x += 1; }
  takeDamage(n: number) {
    this.health -= n;
    if (this.health <= 0) this.alive = false;
  }
  isAlive(): boolean { return this.alive; }
}
```

**判断基準**
- 変数名や関数名に同じプレフィックス/サフィックスが3つ以上ある → カプセル化候補
- 関数が特定のデータグループのみを操作している → そのデータを含むクラスにメソッドを移動

---

### USE PURE CONDITIONS

**Why（なぜ必要か）**

条件式の中で副作用（代入・I/O・例外）が発生すると、コードの実行順序が条件の評価に依存し、テストが困難になる。さらに短絡評価（`&&`, `||`）によって副作用が実行されないケースが生じる。

```typescript
// Before: 条件式内で代入と副作用が発生
let result;
if ((result = fetchData()) !== null && result.isValid()) {
  process(result);
}

// Before（別の問題）: 例外発生が条件に紛れている
if (validateInput(data) && (parsed = JSON.parse(rawData)) !== null) {
  // JSON.parse が例外を投げても、validateInput が false なら実行されない
}

// After: 副作用を条件から分離
const result = fetchData();
if (result !== null && result.isValid()) {
  process(result);
}

// After（パース）
let parsed;
try {
  parsed = JSON.parse(rawData);
} catch {
  return;
}
if (validateInput(data) && parsed !== null) {
  process(parsed);
}
```

**判断基準**
- `if` の中に `=` 代入がある → 条件の外に移動
- `if` の中に関数呼び出しがある（副作用の可能性） → 純粋なboolean返却関数かを確認
- `&&` や `||` の右辺に副作用がある → 短絡評価の影響を検討

---

### NO INTERFACE WITH ONLY ONE IMPLEMENTATION

**Why（なぜ必要か）**

実装クラスが一つしかないインターフェースは、テストや拡張のためという正当な理由がない限り、YAGNI（You Ain't Gonna Need It）の観点から不要な間接層を生む。将来必要になったときに追加すれば十分。

```typescript
// Before: 実装が一つしかないインターフェース
interface UserRepository {
  findById(id: string): User;
  save(user: User): void;
}
class PostgresUserRepository implements UserRepository {
  findById(id: string): User { /* ... */ }
  save(user: User): void { /* ... */ }
}
// PostgresUserRepository しか使われていない場合、インターフェースは不要

// After: インターフェースを除去（必要になったら追加）
class UserRepository {
  findById(id: string): User { /* ... */ }
  save(user: User): void { /* ... */ }
}

// 例外: テストでモックが必要になった時点でインターフェースを導入
// Extract Interface from Implementation パターンを使う
```

**判断基準**
- インターフェースの実装クラスが1つのみ → 除去を検討
- テストでモック/スタブを作成する必要がある → 例外として許容（Extract Interface from Implementation）
- 外部公開APIで安定したコントラクトが必要 → 例外として許容

---

## 13のリファクタリングパターン

### パターン1: Extract Method（メソッド抽出）

| 項目 | 内容 |
|------|------|
| **目的** | 長いメソッドの一部を独立したメソッドに切り出す |
| **適用タイミング** | FIVE LINES 違反時、複数の責務が混在する時 |
| **手順** | コードブロックを特定 → 新メソッドとして抽出 → 元のコードを呼び出しに置換 → コンパイル確認 |

**Motivation（なぜ）**

長い関数は一度に多くのことをしている。空行で区切られたブロックは「自然な境界」を示し、各ブロックは独立したメソッドに変換できる。Extract Method はすべてのリファクタリングパターンの基盤であり、他のほぼすべてのパターンと組み合わせて使われる。

**Mechanics（どう）**

```
1. 抽出したい行に空行でマーキングする
2. 新しいメソッドを作成（メソッド名は作業開始前から決める）
3. 呼び出し箇所に新メソッドの呼び出しを置く
4. ブロックをカットして新メソッドのボディに貼り付け
5. コンパイル（→ 未定義変数のエラーが出る）
6. エラーになった変数をパラメータとして追加
7. もし抽出した部分が変数に代入していた場合:
   a. 新メソッドの末尾に return を追加
   b. 呼び出し箇所で戻り値を受け取る
8. コンパイル
9. エラーになった引数を渡す
10. 不要な空行・コメントを削除
```

```typescript
// Before
function processOrder(order: Order) {
  // 在庫確認（複数行）
  const stock = inventory.check(order.items);
  if (!stock.available) return;
  // 料金計算（複数行）
  const price = order.items.reduce((sum, item) => sum + item.price, 0);
  const tax = price * 0.1;
  // 決済処理（複数行）
  payment.charge(order.customer, price + tax);
}

// After
function processOrder(order: Order) {
  if (!isStockAvailable(order)) return;
  const total = calculateTotal(order);
  payment.charge(order.customer, total);
}

function isStockAvailable(order: Order): boolean {
  return inventory.check(order.items).available;
}

function calculateTotal(order: Order): number {
  const price = order.items.reduce((sum, item) => sum + item.price, 0);
  return price * 1.1;
}
```

---

### パターン2: Replace Type Code with Classes（型コードをクラスで置換）

| 項目 | 内容 |
|------|------|
| **目的** | enum をインターフェースに変換し、各値をクラスに |
| **適用タイミング** | `if-else` や `switch` で enum 値を分岐している時 |
| **手順** | enum → インターフェース定義 → 各値をクラスで実装 → 呼び出し側を更新 |

**Motivation（なぜ）**

`if-else` の各分岐は、将来の変更で修正が必要になる可能性が高い。分岐をクラスに変換することで、新しい種類の追加は新しいクラスの追加だけで完結し、既存コードへの影響を最小化できる（Open-Closed 原則）。

**Mechanics（どう）**

```
1. 既存の enum を持つインターフェースを作成
   - interface InputType { handle(): void; }
2. enum の各値に対するクラスを作成し、インターフェースを実装
3. enum の値を参照している if-else / switch を見つける
4. 各 case のロジックを対応するクラスのメソッドに移動
5. if-else を削除し、インターフェースメソッドの呼び出しに置換
6. 元の enum を削除（Try Delete Then Compile で確認）
```

```typescript
// Before
enum InputType { LEFT, RIGHT, UP, DOWN }

function handleInput(type: InputType) {
  if (type === InputType.LEFT)        moveHorizontal(-1);
  else if (type === InputType.RIGHT)  moveHorizontal(1);
  else if (type === InputType.UP)     moveVertical(-1);
  else if (type === InputType.DOWN)   moveVertical(1);
}

// After
interface Input {
  handle(): void;
}
class Left  implements Input { handle() { moveHorizontal(-1); } }
class Right implements Input { handle() { moveHorizontal(1);  } }
class Up    implements Input { handle() { moveVertical(-1);   } }
class Down  implements Input { handle() { moveVertical(1);    } }

// 呼び出し側: input.handle() のみ
function handleInput(input: Input) {
  input.handle();
}
```

---

### パターン3: Push Code into Classes（コードをクラスに押し込む）

| 項目 | 内容 |
|------|------|
| **目的** | 関数内のロジックを、それが操作するクラスのメソッドに移動する |
| **適用タイミング** | Replace Type Code with Classes の後続作業。データと振る舞いが分離している時 |
| **手順** | 各クラスに振る舞いを移動 → インターフェースにメソッドを追加 → 呼び出し側を簡略化 |

**Motivation（なぜ）**

Replace Type Code with Classes でクラスを作成したあと、元の分岐ロジックはまだ外部関数に残っている。このロジックをクラスの内部に移動することで、データとロジックの凝集度が上がり、クラス外からデータを取り出す必要がなくなる。

**Mechanics（どう）**

```
1. 外部関数の if-else / switch の各 case を確認する
2. 各 case のロジックを対応するクラスにメソッドとして追加
3. インターフェースに新しいメソッドシグネチャを追加
4. 外部関数の各 case を、対応クラスのメソッド呼び出しに置換
5. コンパイル → 全クラスが実装を持つかを確認
6. 外部関数の if-else を削除し、インターフェースメソッドの呼び出しのみに
```

```typescript
// Replace Type Code with Classes の直後（コードはまだ外部にある）
function drawTile(tile: Tile, g: CanvasContext, x: number, y: number) {
  if (tile instanceof Stone) {
    g.fillStyle = STONE_COLOR;
    g.fillRect(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE);
  } else if (tile instanceof Box) {
    g.fillStyle = BOX_COLOR;
    g.fillRect(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE);
  }
}

// Push Code into Classes 後
interface Tile {
  draw(g: CanvasContext, x: number, y: number): void;
}
class Stone implements Tile {
  draw(g: CanvasContext, x: number, y: number) {
    g.fillStyle = STONE_COLOR;
    g.fillRect(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE);
  }
}
class Box implements Tile {
  draw(g: CanvasContext, x: number, y: number) {
    g.fillStyle = BOX_COLOR;
    g.fillRect(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE);
  }
}

// 呼び出し側は完全にシンプルに
function drawTile(tile: Tile, g: CanvasContext, x: number, y: number) {
  tile.draw(g, x, y);
}
```

---

### パターン4: Inline Method（メソッドのインライン化）

| 項目 | 内容 |
|------|------|
| **目的** | 可読性を上げない中間メソッドを削除し、呼び出し側に直接展開する |
| **適用タイミング** | メソッド名がボディと同じ情報しか伝えない時、過度に分割された時 |
| **手順** | 呼び出し箇所を特定 → ボディの内容に置換 → 元メソッドを削除 → コンパイル確認 |

**Motivation（なぜ）**

Extract Method の過剰適用は、実体のない薄いラッパーメソッドを生む。名前とボディが同じ情報を伝えるだけのメソッドは、読む側に余計な間接参照のコストを課す。Inline Method はリファクタリングの「逆操作」として、不要な抽象化を削除する。

**Mechanics（どう）**

```
1. インライン化するメソッドのすべての呼び出し箇所を特定する
2. 各呼び出し箇所で、メソッド呼び出しをメソッドボディで置き換える
   （パラメータは実際の引数に置換）
3. 元のメソッドを削除する
4. コンパイル
```

```typescript
// Before: drawStone は一行のみで、名前とボディが同じ情報
function drawTile(g: CanvasContext, x: number, y: number, tile: Tile) {
  if (tile === Tile.STONE) drawStone(g, x, y);
}
function drawStone(g: CanvasContext, x: number, y: number) {
  g.fillRect(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE);
}

// After: インライン化
function drawTile(g: CanvasContext, x: number, y: number, tile: Tile) {
  if (tile === Tile.STONE)
    g.fillRect(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE);
}
```

---

### パターン5: Specialize Method（メソッドの特化）

| 項目 | 内容 |
|------|------|
| **目的** | 不必要・問題のある汎用性をメソッドから取り除く |
| **適用タイミング** | EITHER CALL OR PASS 違反時。引数で動作が大きく変わる時 |
| **手順** | 汎用メソッドを特化したバージョンに分割 → 各呼び出しを適切な特化版に置換 |

**Motivation（なぜ）**

「汎用的なメソッド」は一見コードの再利用に見えるが、引数によって振る舞いが大きく変わる場合、実際には複数の責務を一つのメソッドに詰め込んでいる。特化したメソッドの方が意図が明確で、誤用が減る。

**Mechanics（どう）**

```
1. 汎用メソッドの呼び出しパターンを分析する
2. 各呼び出しパターンに対して特化したメソッドを作成
3. 各特化メソッドのボディは、汎用メソッドに対応する引数を持つ呼び出し
4. 汎用メソッドの呼び出し箇所を対応する特化メソッドに置換
5. 汎用メソッドが不要になったら Try Delete Then Compile
```

```typescript
// Before: tileAt は "何でも" できる汎用メソッド
function moveHorizontal(dx: number) {
  const newX = playerX + dx;
  if (tileAt(newX, playerY) === Tile.AIR ||
      (tileAt(newX, playerY) === Tile.STONE &&
       tileAt(newX + dx, playerY) === Tile.AIR)) {
    moveTo(newX, playerY);
  }
}

// After: moveLeft / moveRight に特化
function moveLeft() {
  const newX = playerX - 1;
  if (canMoveTo(newX, playerY)) {
    moveTo(newX, playerY);
  }
}

function moveRight() {
  const newX = playerX + 1;
  if (canMoveTo(newX, playerY)) {
    moveTo(newX, playerY);
  }
}
```

---

### パターン6: Try Delete Then Compile（削除してコンパイル）

| 項目 | 内容 |
|------|------|
| **目的** | 未使用のメソッドを安全に発見・削除する |
| **適用タイミング** | インターフェースのメソッドが未使用の可能性がある時（スコープが把握できる場合のみ） |
| **手順** | コンパイル（エラーなし確認）→ メソッドを削除 → コンパイル → エラーなし: 削除確定、エラーあり: 元に戻す |

**Motivation（なぜ）**

IDE は未使用コードをハイライトするが、インターフェースのメソッドは「外部から使われるかもしれない」として常に安全とみなす。インターフェースを自分たちで管理している場合、コンパイラを活用して安全に削除できる。削除したコードはバージョン管理で復元可能。

**Mechanics（どう）**

```
1. 削除候補のメソッド/インターフェースを特定する
2. 現在エラーがないことをコンパイルで確認する
3. 候補を削除する
4. コンパイルする
   → エラーなし: 削除を確定（誰も使っていなかった）
   → エラーあり: undo で元に戻す（まだ使われている）
```

```
⚠️ 注意: 新機能実装中は使用しない（「まだ使われていない」メソッドを誤って削除するリスク）
⚠️ 注意: スコープ外のコードから呼ばれる可能性があるpublicメソッドには慎重に
⚠️ 注意: ライブラリとして公開されているAPIには適用しない
```

---

### パターン7: Unify Similar Classes（類似クラスの統合）

| 項目 | 内容 |
|------|------|
| **目的** | 定数メソッドの集合のみが異なる2つ以上のクラスを1つに統合する |
| **適用タイミング** | 構造が同じで特定の値のみ異なるクラスが複数ある時 |
| **手順** | 差異を定数化 → 1つのクラスにマージ → コンパイル確認 |

**Motivation（なぜ）**

Replace Type Code with Classes を繰り返すと、構造がほぼ同じで定数値だけが異なるクラスが生まれることがある。これらを統合することで、DRY 原則に従いメンテナンスコストを下げる。

**Mechanics（どう）**

```
1. 統合対象の二つのクラスを特定する
2. 一方のクラスに「違いを生む値」をコンストラクタパラメータとして追加
3. もう一方のクラスの各メソッドを一方のクラスに移動する
4. もう一方のクラスの全インスタンス化を、一方のクラスに置換
5. もう一方のクラスを削除（Try Delete Then Compile）
```

```typescript
// Before: Stone と Box は color だけが異なる
class Stone implements Tile {
  draw(g: CanvasContext, x: number, y: number) {
    g.fillStyle = "#888";
    g.fillRect(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE);
  }
}
class Box implements Tile {
  draw(g: CanvasContext, x: number, y: number) {
    g.fillStyle = "#8B4513";
    g.fillRect(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE);
  }
}

// After: 色を外から渡す統合クラス
class ColoredTile implements Tile {
  constructor(private color: string) {}
  draw(g: CanvasContext, x: number, y: number) {
    g.fillStyle = this.color;
    g.fillRect(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE);
  }
}
const STONE = new ColoredTile("#888");
const BOX   = new ColoredTile("#8B4513");
```

---

### パターン8: Combine ifs（if の結合）

| 項目 | 内容 |
|------|------|
| **目的** | 同一のボディを持つ連続した `if` をまとめて重複を削減する |
| **適用タイミング** | 隣接する `if` が同じ処理を実行している時 |
| **手順** | ボディが同一の隣接 `if` を特定 → `&&` や `||` で条件を結合 |

**Motivation（なぜ）**

同じ処理をする複数の条件分岐は、条件が変わったときに各分岐を個別に修正する必要があり、修正漏れのリスクがある。条件を結合することでロジックを一箇所に集約できる。

**Mechanics（どう）**

```
1. 同じボディを持つ隣接した if 文を特定する
2. 二つの if 文の条件を || で結合する
3. 重複したボディを一つにする
4. コンパイル確認
```

```typescript
// Before: 同じボディを持つ if が重複
function isSpecialTile(tile: Tile) {
  if (tile instanceof Key)  return true;
  if (tile instanceof Lock) return true;
  if (tile instanceof Flux) return true;
  return false;
}

// After: 条件を結合
function isSpecialTile(tile: Tile) {
  if (tile instanceof Key ||
      tile instanceof Lock ||
      tile instanceof Flux) return true;
  return false;
}

// さらにシンプルに
function isSpecialTile(tile: Tile) {
  return tile instanceof Key  ||
         tile instanceof Lock ||
         tile instanceof Flux;
}
```

---

### パターン9: Introduce Strategy Pattern（ストラテジーパターン導入）

| 項目 | 内容 |
|------|------|
| **目的** | `if` による分岐をクラスのインスタンス化で置き換える |
| **適用タイミング** | NEVER USE IF WITH ELSE 違反時。動作の切り替えを `if` で実現している時 |
| **手順** | 共通インターフェースを定義 → 各分岐を別クラスに → `if` をクラス選択に置換 |

**Motivation（なぜ）**

異なるアルゴリズムや振る舞いを実行時に切り替えたい場合、`if-else` では新しい選択肢を追加するたびにコードを修正しなければならない。ストラテジーパターンでは新しいクラスを追加するだけで対応できる。

**Mechanics（どう）**

```
1. 分岐の各 case が「何をするか」を定義するインターフェースを作成
2. 各 case のロジックをクラスとして実装
3. if-else でクラスを選択するか、Map/配列で直接マッピングする
4. 呼び出し側は strategy.execute() のみ
```

```typescript
// Before
function processInput(type: string) {
  if (type === 'left') moveLeft();
  else if (type === 'right') moveRight();
}

// After: Replace Type Code with Classes + Introduce Strategy Pattern
interface InputHandler {
  handle(): void;
}
const handlers: Map<string, InputHandler> = new Map([
  ['left',  { handle: () => moveLeft()  }],
  ['right', { handle: () => moveRight() }],
]);
function processInput(type: string) {
  handlers.get(type)?.handle();
}
```

---

### パターン10: Extract Interface from Implementation（実装からインターフェース抽出）

| 項目 | 内容 |
|------|------|
| **目的** | クラスへの依存をインターフェースへの依存に置き換える |
| **適用タイミング** | テスト容易性を高めたい時。クラスを直接参照しているコードがある時 |
| **手順** | クラスの使用されているメソッドを抽出 → インターフェース定義 → 呼び出し側の型をインターフェースに変更 |

**Motivation（なぜ）**

具体クラスに直接依存すると、その実装を差し替えることができない。テスト時にモックを使いたい、将来的に実装を変えたいという場合に、インターフェースへの依存が必要になる（依存関係逆転の原則）。

**Mechanics（どう）**

```
1. 呼び出し側が使用しているメソッドのみをリストアップ
2. そのメソッドシグネチャのみを持つインターフェースを作成
3. 元のクラスにそのインターフェースを implements させる
4. 呼び出し側の型宣言をインターフェース型に変更
5. コンパイル確認
```

```typescript
// Before: DatabaseConnection クラスに直接依存
class UserService {
  constructor(private db: DatabaseConnection) {}
  getUser(id: string) {
    return this.db.query(`SELECT * FROM users WHERE id = '${id}'`);
  }
}

// After: インターフェースに依存 → テストでモック可能
interface Database {
  query(sql: string): unknown;
}
class DatabaseConnection implements Database {
  query(sql: string) { /* 実際のDB処理 */ }
}
class MockDatabase implements Database {
  query(sql: string) { return { id: '1', name: 'Test' }; }  // テスト用
}

class UserService {
  constructor(private db: Database) {}  // インターフェースに依存
  getUser(id: string) {
    return this.db.query(`SELECT * FROM users WHERE id = '${id}'`);
  }
}
```

---

### パターン11: Eliminate Getter/Setter（ゲッター/セッターの除去）

| 項目 | 内容 |
|------|------|
| **目的** | ゲッター/セッターを削除し、ロジックをデータの近くに移動する |
| **適用タイミング** | DO NOT USE GETTERS OR SETTERS 違反時 |
| **手順** | ゲッター/セッターの使用箇所を特定 → ロジックをデータを持つクラスに移動 → アクセサを削除 |

**Motivation（なぜ）**

ゲッターはデータを外部に漏らし、そのデータに関するロジックが呼び出し側に散在することを促す。データとロジックを同じクラスに置くことで、変更時の影響範囲が最小化される。

**Mechanics（どう）**

```
1. ゲッターのすべての呼び出し箇所を収集する
2. 各呼び出し箇所で「取得した値で何をしているか」を分析する
3. そのロジックをゲッターのあるクラスのメソッドとして定義する
4. 呼び出し箇所をメソッド呼び出しに置換する
5. ゲッターが不要になったら削除（Try Delete Then Compile）
```

```typescript
// Before
class Temperature {
  private celsius: number;
  getCelsius() { return this.celsius; }
}
// 呼び出し側にロジックが漏れる
const tempStr = `${temp.getCelsius()}°C`;
const isHot   = temp.getCelsius() > 30;
const isCold  = temp.getCelsius() < 10;

// After: ロジックをクラスに押し込む
class Temperature {
  private celsius: number;
  toString()  { return `${this.celsius}°C`; }
  isHot()     { return this.celsius > 30;   }
  isCold()    { return this.celsius < 10;   }
}
// 呼び出し側
const tempStr = temp.toString();
const isHot   = temp.isHot();
const isCold  = temp.isCold();
```

---

### パターン12: Encapsulate Data（データのカプセル化）

| 項目 | 内容 |
|------|------|
| **目的** | 変数に関連する不変条件を局所化し、凝集度を高める |
| **適用タイミング** | NEVER HAVE COMMON AFFIXES 違反時。関連する変数が散在している時 |
| **手順** | 共通接頭辞/接尾辞を持つ変数を特定 → 新クラスに移動 → 元の参照を新クラス経由に変更 |

**Motivation（なぜ）**

共通のプレフィックスを持つ変数（例: `playerX`, `playerY`, `playerHealth`）は、一つのエンティティのデータが散在しているシグナルだ。このデータとそれに関連するロジックを一箇所に集めることで、不変条件の管理が容易になる。

**Mechanics（どう）**

```
1. 共通接頭辞/接尾辞を持つ変数・関数を特定する
2. 新しいクラスを作成し、変数をフィールドとして移動
3. 変数に関連するすべての関数をクラスのメソッドとして移動
4. 元のコードでは、クラスのインスタンス経由でアクセスするよう変更
5. 古い変数・関数を削除（Try Delete Then Compile）
```

```typescript
// Before: player_ プレフィックスの変数が散在
let playerX = 0;
let playerY = 0;
let playerFallHeight = 0;
let playerAlive = true;

function movePlayerLeft()  { playerX -= 1; }
function movePlayerRight() { playerX += 1; }
function playerFall()      { playerY += 1; playerFallHeight += 1; }
function playerLand()      { if (playerFallHeight > 3) playerAlive = false; playerFallHeight = 0; }

// After: Player クラスにカプセル化
class Player {
  x = 0;
  y = 0;
  private fallHeight = 0;
  private alive = true;

  moveLeft()  { this.x -= 1; }
  moveRight() { this.x += 1; }
  fall()      { this.y += 1; this.fallHeight += 1; }
  land()      {
    if (this.fallHeight > 3) this.alive = false;
    this.fallHeight = 0;
  }
  isAlive()   { return this.alive; }
}
```

---

### パターン13: Enforce Sequence（順序の強制）

| 項目 | 内容 |
|------|------|
| **目的** | 特定の処理が決まった順序で実行されることをコンパイラに保証させる |
| **適用タイミング** | 初期化順序・リソース管理などで実行順序が重要な時 |
| **手順** | 前のステップの戻り値を次のステップの引数にする → コンパイラが順序を強制 |

**Motivation（なぜ）**

「接続してからクエリを実行する」「初期化してから使う」などの順序制約は、コメントに書いても見落とされる。戻り値の型を使って順序をコンパイラに強制させることで、順序間違いが実行時エラーではなくコンパイルエラーになる。

**Mechanics（どう）**

```
1. 順序が重要な操作のシーケンスを特定する
2. 各ステップを独立した関数として定義
3. 前のステップの結果を次のステップの引数型として使用
   → コンパイラが「前のステップを実行した後でしか呼べない」ことを強制する
4. 中間状態を表す専用の型（クラス）を作成することも有効
```

```typescript
// Before: 順序を間違えると実行時エラー
const conn = db.connect();
const result = db.query("SELECT ...");  // connect前に呼んでもエラーなし
conn.close();

// After: 型で順序を強制
function connect(db: Database): Connection { /* ... */ }
function query(conn: Connection, sql: string): QueryResult { /* ... */ }
function close(conn: Connection): void { /* ... */ }
// conn なしで query を呼べない（型エラー）

// さらに強力な例（中間型を使う）
class InitializedDB {
  private constructor(public readonly connection: Connection) {}
  static initialize(config: DBConfig): InitializedDB {
    return new InitializedDB(new Connection(config));
  }
}
// InitializedDB を経由しないと query が呼べない設計に
```

---

## コンパイラ協調

コンパイラをチームメンバーとして設計に組み込む。

### コンパイラの強み（活用すべき）

| 強み | 概要 | 活用方法 |
|------|------|---------|
| **到達可能性** | すべてのコードパスで `return` があるかを保証 | 網羅的な条件分岐の検証 |
| **確実な代入** | 初期化されていない変数へのアクセスを検出 | 変数の確実な初期化パターン |
| **アクセス制御** | `private`/`public` でカプセル化を強制 | 実装詳細の隠蔽 |
| **型チェック** | 型の不一致を事前に検出 | インターフェース経由の依存 |

### コンパイラの弱み（避けるべき依存）

| 弱み | 概要 | 対処法 |
|------|------|--------|
| **停止問題** | 実行時の振る舞いを完全には予測できない | ランタイム検証を追加 |
| **null参照** | null デリファレンスはコンパイル時に検出できない | Optional型・Nullオブジェクトパターン |
| **算術エラー** | オーバーフロー・ゼロ除算を検出できない | 事前条件の明示的な検証 |
| **境界外アクセス** | 配列の境界外アクセスを検出できない | 範囲チェックを明示的に追加 |
| **デッドロック** | 並行処理の競合状態を検出できない | 並行設計パターンの使用 |

### コンパイラをTODOリストとして活用

```typescript
// リファクタリング中: メソッド名を一時的に変更してコンパイルエラーを発生させる
// → エラー箇所がTODOリストになる
enum Color_handled { RED, GREEN, BLUE }
// コンパイラがColor_handledを使う全箇所をエラーとして指摘
// → 一つずつ対処しながら _handled を削除していく
```

### never型を使った網羅性保証

TypeScript の `never` 型を活用することで、`switch` や条件分岐の網羅性をコンパイル時に保証できる。

```typescript
// never 型の exhaustive check
type Direction = 'left' | 'right' | 'up' | 'down';

function handleDirection(dir: Direction): void {
  switch (dir) {
    case 'left':  moveLeft();  return;
    case 'right': moveRight(); return;
    case 'up':    moveUp();    return;
    case 'down':  moveDown();  return;
    default: assertNever(dir);  // 'down' を追加し忘れるとコンパイルエラー
  }
}

function assertNever(x: never): never {
  throw new Error(`Unhandled value: ${JSON.stringify(x)}`);
}
```

### 型でシーケンスを保護する

前の操作の戻り値の型を次の操作の引数型にすることで、実行順序をコンパイラが強制する。

```typescript
// 「未認証」「認証済み」「セッション確立済み」を別の型で表現
class AuthToken { private brand = 'auth'; }
class Session   { private brand = 'session'; }

function authenticate(user: string, password: string): AuthToken { /* ... */ }
function createSession(token: AuthToken): Session { /* ... */ }
function fetchData(session: Session): Data { /* ... */ }

// Session なしで fetchData は呼べない → コンパイルエラー
// AuthToken なしで createSession は呼べない → コンパイルエラー
```

### private で不変条件を守る

```typescript
// private で invariant を守る例
class PositiveNumber {
  private constructor(private readonly value: number) {}

  static create(value: number): PositiveNumber {
    if (value <= 0) throw new Error("Must be positive");
    return new PositiveNumber(value);
  }

  // value が常に正であることが保証された計算
  divide(divisor: PositiveNumber): PositiveNumber {
    return new PositiveNumber(this.value / divisor.value);
    // ゼロ除算が起きないことをコンパイラが保証（PositiveNumber は必ず正）
  }
}
```

---

## コード削除の哲学

> **コードは資産ではなく負債だ。コードが少ないほど、読む量・テストする量・バグの潜む量が減る。**

### コードが増える理由（インシデンタル複雑性の4カテゴリ）

| カテゴリ | 説明 | 対処法 |
|---------|------|--------|
| **技術的無知（Ignorance）** | 経験不足から生まれる不必要に複雑なコード | リファクタリングで改善 |
| **技術的浪費（Waste）** | 時間的プレッシャーから生まれたショートカット | 計画的なリファクタリングタイム |
| **技術的負債（Debt）** | 意図的な妥協（後で直す予定） | 計画的な返済 |
| **技術的引きずり（Drag）** | 成長に伴う設計の陳腐化 | アーキテクチャ見直し |

### Try Delete Then Compile パターンの背景

- IDEは未使用コードをハイライトするが、インターフェースのメソッドは「外部から使われるかもしれない」として常に安全とみなす
- 自分たちが導入したインターフェースのスコープを把握している場合のみ、安全に削除判断ができる
- 削除されたコードはバージョン管理システムで復元可能。恐れずに削除する

### 削除可否の判断フロー

```
未使用のメソッド/クラスを発見
  ↓
スコープを把握しているか？（自分たちが導入したインターフェースか）
  ├─ Yes → Try Delete Then Compile
  └─ No  → IDEの未使用警告を参考に慎重に判断
              ↓
          削除してコンパイル成功？
            ├─ Yes → 削除確定
            └─ No  → 元に戻す（undo）
```

### 削除すべきコードの種類別チェックリスト

```
コメント削除:
  ✅ アウトデートしたコメント（実装と乖離している）
  ✅ コメントアウトされたコード（バージョン管理で復元可能）
  ✅ コードをそのまま繰り返すコメント（// returns the sum → function sum()）
  ❌ 不変条件を説明するコメント（なぜこの値でなければならないか）
  ❌ TODO/FIXME（将来の作業の記録）

デッドコード削除:
  ✅ 到達不可能なコード（return の後のコード）
  ✅ 未使用の変数（コンパイラが警告）
  ✅ 使われていないインターフェースメソッド（Try Delete Then Compile で確認）
  ❌ 実装中の機能（「まだ使われていない」コード）

テストコード削除:
  ✅ 楽観的テスト（常にパスするテスト）
  ✅ 悲観的テスト（常に失敗するテスト）
  ✅ フレーキーなテスト（修正が困難な場合は削除して書き直し）
  ❌ ビジネスロジックをカバーするテスト
```

### ブランチのライフサイクル管理

技術的なブランチの放棄は、コードベースに「ゴースト」コードを生む。ブランチ数の上限（例: チームメンバー数と同じ）を設定することで、未マージコードの蓄積を防ぐ。

### Strangler Fig パターン（レガシーコード移行）

レガシーシステムを安全に削除するためのアプローチ。

```
1. 新しいコードで既存機能を並行実装（新旧共存）
2. 呼び出しを徐々に新実装に移行
3. 旧実装への呼び出しがゼロになったら削除
```

---

## 悪いコードを悪く見せる（Anti-Refactoring）

通常のリファクタリングとは逆の発想：**修正できない悪いコードは、見た目にも悪く見えるようにする**。

### なぜ重要か

- 「それほど悪くない」コードは見過ごされる → 技術的負債が蓄積
- 「明らかに悪い」コードは注目を集め、改善される確率が高まる
- 壊れた窓理論: 一つの問題が放置されると、他の問題も放置されやすくなる
- 心理的安全性の観点: 悪いコードは「制約が持続不可能」というシグナルとして機能する

### 「匂い」を表面化させるテクニック

| 手法 | 内容 | 効果 |
|------|------|------|
| **コメント追加** | `// FIXME:` や `// HACK:` でレガシーコードの問題を明示 | 問題箇所が検索で発見可能になる |
| **インライン化** | 抽象化を除去し、問題を表面化させる | 隠れていた複雑さが露見する |
| **名前空間分離** | プリスティン（良い）コードとレガシーコードを明確に分ける | 品質の差が視覚化される |
| **型の厳格化** | `any` や緩い型を使っている箇所を `unknown` に変更 | 型安全でない操作が全てコンパイルエラーになる |

### インライン化で問題を表面化する

```typescript
// Before: 問題が抽象化の陰に隠れている
function processUserData(userId: string) {
  const user = getUser(userId);         // この中で何をしているか見えない
  const score = calculateScore(user);   // DB を叩いている? キャッシュ? 副作用は?
  return formatOutput(score);
}

// After: インライン化で全ての問題が露出する（意図的に汚く見せる）
function processUserData(userId: string) {
  // FIXME: 毎回DBを叩いている — N+1問題
  const user = db.query(`SELECT * FROM users WHERE id = '${userId}'`);
  // FIXME: 複雑な計算がインライン — 別サービスに切り出すべき
  let score = 0;
  for (const activity of user.activities) {
    if (activity.type === 'login') score += 10;
    else if (activity.type === 'purchase') score += 50;
    // FIXME: 7種類のactivityが未処理
  }
  // HACK: HTMLエスケープなし — XSS脆弱性
  return `<div>Score: ${score}</div>`;
}
```

### プリスティン vs レガシーの分離

```
src/
├── pristine/     # 新しいルールに準拠したコード
│   └── ...
└── legacy/       # 古いルールで書かれたコード（明示的にマーク）
    └── ...
```

**原則**: 「良くできないなら、目立たせよ（If you cannot make it good, make it stand out）」

### FIXME/HACK コメントの書き方

効果的なコメントは問題を具体的に記述し、対処の方向性も示す。

```typescript
// ❌ 曖昧な FIXME
// FIXME: この関数は遅い

// ✅ 具体的な FIXME（問題・原因・影響・対策方針）
// FIXME: N+1クエリ — ループ内でDB呼び出し(loop: ~500回/リクエスト)
//        → 影響: P95レイテンシ 2000ms超え
//        → 対策: user_activities を一括 JOIN するか、Redis キャッシュを導入
//        → チケット: PROJECT-1234

// ❌ コードをそのまま繰り返すコメント
// Process the user
function processUser(user: User) { /* ... */ }

// ✅ 不変条件や設計上の制約を伝えるコメント
// この関数は必ず premiumTier の検証後に呼ぶこと
// （直接呼ぶと課金制限を無視することになる）
function unlockPremiumFeature(user: User) { /* ... */ }
```

### 「悪いコードの可視化」ワークフロー

```
1. 修正できない（または今は修正しない）悪いコードを発見
   ↓
2. FIXME/HACK コメントを追加（具体的に問題を記述）
   ↓
3. 可能であれば Inline Method で問題を表面化
   ↓
4. pristine/ vs legacy/ に分類
   ↓
5. コードレビュー時に問題のある箇所を明示的に議論
   ↓
6. 技術的負債として管理 → 計画的にリファクタリング
```

---

## 関連ドキュメント

- [クリーンコード基礎](./CLEAN-CODE-BASICS.md) — 命名・関数設計の基本
- [制御フロー改善](./CONTROL-FLOW.md) — if文・Nullの体系的な除去
- [オブジェクト設計](./OBJECT-DESIGN.md) — ゲッター/セッター除去の実践
- [複雑さ管理](./COMPLEXITY-MANAGEMENT.md) — YAGNI・フェイルファスト
- [アーキテクチャ品質](./ARCHITECTURE.md) — 依存関係・継承の改善
