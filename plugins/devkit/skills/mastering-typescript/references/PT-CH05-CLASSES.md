# クラスとインターフェース

> TypeScriptのクラスシステム、継承、抽象化、インターフェース、ポリモーフィズムの実践パターン

## 目次

1. [クラスと継承の基本](#1-クラスと継承の基本)
2. [アクセス修飾子とカプセル化](#2-アクセス修飾子とカプセル化)
3. [抽象クラスとメソッド](#3-抽象クラスとメソッド)
4. [super の型安全な使い方](#4-super-の型安全な使い方)
5. [戻り値の型としての this](#5-戻り値の型としての-this)
6. [インターフェース](#6-インターフェース)
7. [implements と型チェック](#7-implements-と型チェック)
8. [クラスは構造的に型付けされる](#8-クラスは構造的に型付けされる)
9. [クラスは値と型の両方を宣言する](#9-クラスは値と型の両方を宣言する)
10. [ポリモーフィズム](#10-ポリモーフィズム)
11. [ミックスイン](#11-ミックスイン)
12. [デコレーター](#12-デコレーター)
13. [final クラスのシミュレート](#13-final-クラスのシミュレート)
14. [デザインパターン](#14-デザインパターン)
15. [まとめ](#15-まとめ)

---

## 1. クラスと継承の基本

```typescript
class Piece {
  protected position: Position
  constructor(private readonly color: Color, file: File, rank: Rank) {
    this.position = new Position(file, rank)
  }
}

class King extends Piece {
  canMoveTo(position: Position) {
    let distance = this.position.distanceFrom(position)
    return distance.rank < 2 && distance.file < 2
  }
}
```

---

## 2. アクセス修飾子とカプセル化

| 修飾子 | アクセス範囲 | コンストラクター自動割り当て | readonly併用 |
|--------|------------|-------------------|------------|
| `public` | どこからでも（デフォルト） | ✅ | ✅ |
| `protected` | クラスとサブクラス | ✅ | ✅ |
| `private` | このクラスのみ | ✅ | ✅ |

```typescript
class Position {
  constructor(
    private file: File,
    private rank: Rank
  ) {}
}
```

---

## 3. 抽象クラスとメソッド

```typescript
abstract class Piece {
  abstract canMoveTo(position: Position): boolean
  moveTo(position: Position) { this.position = position }
}

class King extends Piece {
  canMoveTo(position: Position): boolean {
    let distance = this.position.distanceFrom(position)
    return distance.rank < 2 && distance.file < 2
  }
}
```

---

## 4. super の型安全な使い方

```typescript
class Queen extends Piece {
  constructor(color: Color, file: File, rank: Rank) {
    super(color, file, rank)  // 親クラスコンストラクター（必須）
  }
  moveTo(position: Position) {
    super.moveTo(position)    // 親クラスメソッド呼び出し
  }
}
```

**注意**: メソッドのみアクセス可（プロパティ不可）

---

## 5. 戻り値の型としての this

```typescript
class Set {
  add(value: number): this { /* ... */ }
}

class MutableSet extends Set {
  delete(value: number): boolean { /* ... */ }
}

new MutableSet().add(1).add(2).delete(1)  // サブクラスでも型安全
```

**利点**: メソッドチェーン型安全、サブクラスで自動的に適切な型に解決

---

## 6. インターフェース

### 3つの主な違い（型エイリアス vs インターフェース）

| 特性 | 型エイリアス | インターフェース |
|------|------------|---------------|
| 右辺の型 | 任意の型 | 形状のみ |
| 継承構文 | `&` | `extends` |
| 宣言マージ | ❌ | ✅（同名interfaceが自動統合） |
| 拡張時の型チェック | なし | 反変性チェックあり |

```typescript
// 宣言マージ例
interface User { name: string }
interface User { age: number }
let user: User = { name: 'Alice', age: 30 }  // 自動統合される
```

---

## 7. implements と型チェック

```typescript
interface Animal {
  readonly name: string
  eat(food: string): void
}

class Cat implements Animal {
  name = 'Whiskers'
  eat(food: string) { console.info('Ate some', food) }
}
```

| 特徴 | インターフェース | 抽象クラス |
|------|----------------|----------|
| ランタイムコード | なし | あり |
| デフォルト実装 | ❌ | ✅ |
| アクセス修飾子 | ❌ | ✅ |
| 使い分け | 軽量な型制約 | 実装共有 |

---

## 8. クラスは構造的に型付けされる

```typescript
class Zebra { trot() {} }
class Poodle { trot() {} }

function ambleAround(animal: Zebra) { animal.trot() }
ambleAround(new Poodle)  // OK（構造が一致）
```

**例外**: `private`/`protected`フィールドを持つクラスは名前的型付け（同じ構造でもクラスインスタンスでなければNG）

---

## 9. クラスは値と型の両方を宣言する

```typescript
class C {}
let c: C = new C  // C は型でもあり値でもある

class StringDatabase {
  static from(state: State) { /* ... */ }
}

// typeof でコンストラクター型を取得
type Constructor = typeof StringDatabase

// コンストラクターシグネチャ
interface StringDatabaseConstructor {
  new(state?: State): StringDatabase
  from(state: State): StringDatabase
}
```

---

## 10. ポリモーフィズム

```typescript
class MyMap<K, V> {
  get(key: K): V { /* ... */ }
  merge<K1, V1>(map: MyMap<K1, V1>): MyMap<K | K1, V | V1> { /* ... */ }
  static of<K, V>(k: K, v: V): MyMap<K, V> { /* ... */ }
}

let b = new MyMap('k', true)  // 推論: MyMap<string, boolean>
```

**ポイント**: 静的メソッドはクラスジェネリックにアクセス不可（独自宣言）

---

## 11. ミックスイン

### ミックスインパターンの実装

```typescript
type ClassConstructor<T> = new(...args: any[]) => T

function withEZDebug<C extends ClassConstructor<{
  getDebugValue(): object
}>>(Class: C) {
  return class extends Class {
    debug() {
      let Name = this.constructor.name
      let value = this.getDebugValue()
      return Name + '(' + JSON.stringify(value) + ')'
    }
  }
}
```

### 使用例

```typescript
class HardToDebugUser {
  constructor(
    private id: number,
    private firstName: string,
    private lastName: string
  ) {}

  getDebugValue() {
    return {
      id: this.id,
      name: this.firstName + ' ' + this.lastName
    }
  }
}

let User = withEZDebug(HardToDebugUser)
let user = new User(3, 'Emma', 'Gluzman')
user.debug()  // 'HardToDebugUser({"id": 3, "name": "Emma Gluzman"})'
```

**ミックスインの特徴:**
- 状態（インスタンスプロパティ）を持てる
- 具象メソッドのみ提供
- コンストラクターを持てる（ミックスされた順序で呼び出される）

---

## 12. デコレーター

```typescript
@serializable
class APIPayload {
  getValue(): Payload { /* ... */ }
}

// 実装
type ClassConstructor<T> = new(...args: any[]) => T
function serializable<T extends ClassConstructor<{ getValue(): Payload }>>(C: T) {
  return class extends C {
    serialize() { return this.getValue().toString() }
  }
}
```

**制限**: 追加メソッドは型チェックに反映されない。本番では通常関数推奨

---

## 13. final クラスのシミュレート

```typescript
class MessageQueue {
  private constructor(private messages: string[]) {}
  static create(messages: string[]) { return new MessageQueue(messages) }
}

class BadQueue extends MessageQueue {}  // エラー: 拡張不可
```

---

## 14. デザインパターン

### ファクトリーパターン

```typescript
type Shoe = {
  purpose: string
}

class BalletFlat implements Shoe {
  purpose = 'dancing'
}

class Boot implements Shoe {
  purpose = 'woodcutting'
}

class Sneaker implements Shoe {
  purpose = 'walking'
}

let Shoe = {
  create(type: 'balletFlat' | 'boot' | 'sneaker'): Shoe {
    switch (type) {
      case 'balletFlat': return new BalletFlat
      case 'boot': return new Boot
      case 'sneaker': return new Sneaker
    }
  }
}

Shoe.create('boot')  // Shoe
```

**ポイント:**
- コンパニオンオブジェクトパターンを使用
- 型安全な型パラメーター
- 完全性チェックによる網羅性保証

### ビルダーパターン

```typescript
class RequestBuilder {
  private data: object | null = null
  private method: 'get' | 'post' | null = null
  private url: string | null = null

  setMethod(method: 'get' | 'post'): this {
    this.method = method
    return this
  }

  setData(data: object): this {
    this.data = data
    return this
  }

  setURL(url: string): this {
    this.url = url
    return this
  }

  send() { /* ... */ }
}

new RequestBuilder()
  .setURL('/users')
  .setMethod('get')
  .setData({firstName: 'Anna'})
  .send()
```

**ポイント:**
- `this` 型で型安全なメソッドチェーン
- Fluent API の実現

---

## 15. まとめ

### 重要ポイント

- アクセス修飾子（`public`/`protected`/`private`）とカプセル化
- 抽象クラスでサブクラス実装強制
- `this` 型で型安全なメソッドチェーン
- インターフェースで軽量な型制約（Declaration Merging）
- 構造的型付け（例外: `private`/`protected`は名前的型付け）
- ポリモーフィズム（ジェネリック）
- ミックスイン（状態・具象メソッド提供）
- `final` クラスシミュレート（privateコンストラクター）
- ファクトリー/ビルダーパターン
