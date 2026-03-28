# TypeScript 5.0 デコレータ完全リファレンス

## 概要

TypeScript 5.0（2023年3月）でデコレータが**正式機能**としてデフォルトサポートされた（ECMAScript Stage 3相当）。

| 仕様 | バージョン | 有効化 |
|------|-----------|--------|
| **新仕様（本リファレンス対象）** | TS 5.0+ | デフォルト有効 |
| レガシー仕様（experimentalDecorators） | TS 5.0未満 / 旧プロジェクト | `tsconfig.json` に `"experimentalDecorators": true` が必要 |

> **互換性なし**: 新旧仕様は互換性がない。TS 5.0以降でも旧仕様はオプションで継続利用可能だが、新規プロジェクトは新仕様を使用すること。

デコレータは**メタプログラミング**のための構文（`@式`）。クラスやメンバー宣言に付与することで、元のコードを変更せず再利用可能な方法で振る舞いを変更・拡張できる。

---

## デコレータ一覧

| 種類 | 適用対象 | Context型 | 戻り値 |
|------|---------|-----------|--------|
| **メソッドデコレータ** | クラスメソッド | `ClassMethodDecoratorContext` | 置換関数 or `void` |
| **ゲッターデコレータ** | getter | `ClassGetterDecoratorContext` | 置換getter or `void` |
| **セッターデコレータ** | setter | `ClassSetterDecoratorContext` | 置換setter or `void` |
| **フィールドデコレータ** | フィールド宣言 | `ClassFieldDecoratorContext` | 初期値変換関数 or `void` |
| **クラスデコレータ** | クラス定義 | `ClassDecoratorContext` | サブクラス or `void` |
| **Auto-Accessorデコレータ** | `accessor` キーワードのプロパティ | `ClassAccessorDecoratorContext` | `{get?, set?, init?}` or `void` |

---

## メソッドデコレータ

```typescript
// シグネチャ（型安全版）
function logged<This, Args extends any[], Return>(
  originalMethod: (this: This, ...args: Args) => Return,
  context: ClassMethodDecoratorContext<This, (this: This, ...args: Args) => Return>
) {
  return function loggedMethod(this: This, ...args: Args): Return {
    console.log(`${context.name.toString()} メソッド呼び出し！`);
    const result = originalMethod.call(this, ...args);
    console.log(`${context.name.toString()} メソッド終了！`);
    return result;
  };
}

class Person {
  @logged
  greet() { console.log("Hello!"); }
}
```

### ClassMethodDecoratorContext の主要プロパティ

```typescript
interface ClassMethodDecoratorContext<This, Value extends (this: This, ...args: any) => any> {
  readonly kind: "method";
  readonly name: string | symbol;       // デコレート対象メソッド名
  readonly static: boolean;             // static メンバーか
  readonly private: boolean;            // private メンバーか
  readonly access: {
    has(object: This): boolean;
    get(object: This): Value;
  };
  addInitializer(initializer: (this: This) => void): void;
}
```

> **注意**: `context.name` は `string | symbol` 型。テンプレートリテラルに埋め込む場合は `.toString()` で変換が必要。

---

## ゲッター / セッターデコレータ

```typescript
// ゲッターデコレータ
function loggedGetter<This, Return>(
  target: (this: This) => Return,
  context: ClassGetterDecoratorContext<This, Return>
) {
  return function (this: This): Return {
    console.log(`${context.name.toString()} を取得`);
    return target.call(this);
  };
}

// セッターデコレータ
function loggedSetter<This, Value>(
  target: (this: This, value: Value) => void,
  context: ClassSetterDecoratorContext<This, Value>
) {
  return function (this: This, value: Value): void {
    console.log(`${context.name.toString()} を ${value} に設定`);
    return target.call(this, value);
  };
}

class Person {
  private _name = "John";

  @loggedGetter
  get name() { return this._name; }

  @loggedSetter
  set name(v: string) { this._name = v; }
}
```

| Context型 | `target` の型 | 戻り値の型 |
|-----------|--------------|-----------|
| `ClassGetterDecoratorContext<This, Return>` | `(this: This) => Return` | 置換getter |
| `ClassSetterDecoratorContext<This, Value>` | `(this: This, value: Value) => void` | 置換setter |

---

## フィールドデコレータ

フィールドデコレータの `target`（第1引数）は**常に `undefined`**。戻り値は初期値を変換する関数。

```typescript
function loggedField<This, V>(
  _target: undefined,  // 常にundefined（フィールドはクラス定義時に値を持たないため）
  context: ClassFieldDecoratorContext<This, V>
) {
  // 戻り値 = 初期値変換関数（引数: 元の初期値、戻り値: 新しい初期値）
  return function (this: This, initialValue: V): V {
    console.log(`${context.name.toString()} を ${initialValue} で初期化`);
    return initialValue;
  };
}

class Person {
  @loggedField
  name = "John";  // インスタンス化時に「name を John で初期化」が出力される
}
```

---

## クラスデコレータ

クラス自体に適用。`target` はクラスコンストラクタ。戻り値で元クラスを置換（通常はサブクラスを返す）。

```typescript
function loggedClass<This extends { new (...args: any[]): {} }>(
  target: This,
  context: ClassDecoratorContext<This>
) {
  // 元クラスを継承した無名クラスで置換
  return class extends target {
    constructor(...args: any[]) {
      super(...args);
      console.log(`${context.name} クラスを ${args.join(", ")} でインスタンス化`);
    }
  };
}

@loggedClass
class Person {
  constructor(public name: string) {}
}

new Person("John"); // ログ出力: Person クラスを John でインスタンス化
```

> **型制約**: `This extends { new (...args: any[]): {} }` でコンストラクタ関数を持つ任意のクラスに対応。

---

## Auto-Accessor デコレータ

`accessor` キーワードで宣言されたプロパティ専用。`target` には `get` / `set` を持つオブジェクトが渡される。

```typescript
// accessor キーワード: private フィールド + getter + setter をまとめて宣言
class Person {
  accessor age = 20; // === private #age + get age() + set age()
}
```

```typescript
function loggedAccessor<This, V>(
  target: { get: (this: This) => V; set: (this: This, value: V) => void },
  context: ClassAccessorDecoratorContext<This, V>
) {
  return {
    get(this: This): V {
      console.log(`${context.name.toString()} を取得`);
      return target.get.call(this);
    },
    set(this: This, value: V): void {
      console.log(`${context.name.toString()} を ${value} に設定`);
      target.set.call(this, value);
    },
    init(this: This, initialValue: V): V {
      console.log(`${context.name.toString()} を ${initialValue} に初期化`);
      return initialValue;
    },
  };
}

class Person {
  @loggedAccessor
  accessor age = 20;
}
// new Person()    → age を 20 に初期化
// person.age      → age を取得
// person.age = 21 → age を 21 に設定
```

---

## デコレータファクトリ

デコレータに引数を渡すためのパターン。**「デコレータを返す関数」** として定義する。

```typescript
// ファクトリ関数がデコレータを生成して返す
function logged(headMessage = "[LOG]") {
  return function actualDecorator<This, Args extends any[], Return>(
    originalMethod: (this: This, ...args: Args) => Return,
    context: ClassMethodDecoratorContext<This, (this: This, ...args: Args) => Return>
  ) {
    return function (this: This, ...args: Args): Return {
      console.log(`${headMessage} ${context.name.toString()} 呼び出し`);
      const result = originalMethod.call(this, ...args);
      console.log(`${headMessage} ${context.name.toString()} 終了`);
      return result;
    };
  };
}

class Person {
  @logged("[INFO]")  // ファクトリを呼び出して生成されたデコレータを適用
  greet() { console.log("Hello!"); }
}
```

---

## addInitializer — 初期化フック

`context.addInitializer()` に渡したコールバックは、クラスコンストラクタの先頭で実行される。

**ユースケース例: `this` バインディングの自動化**

```typescript
function bound(_originalMethod: any, context: ClassMethodDecoratorContext) {
  context.addInitializer(function (this: any) {
    // インスタンス化時に、メソッドの this をインスタンスに束縛
    this[context.name as string] = this[context.name as string].bind(this);
  });
}

class Person {
  constructor(public name: string) {}

  @bound
  greet() { console.log(`Hello, ${this.name}`); }
}

const person = new Person("John");
setTimeout(person.greet, 1000); // this が正しく束縛される → "Hello, John"
```

---

## 実行順序

複数デコレータを適用した場合の評価・実行順序：

```typescript
class ExampleClass {
  @A()  // ① ファクトリ評価（上から）
  @B()  // ② ファクトリ評価（上から）
  @C    // ③ デコレータ実行（下から）
  method() {}
}
// ログ出力順:
// "A ファクトリ 評価"   ← 上から評価
// "B ファクトリ 評価"   ← 上から評価
// "C デコレータ 呼び出し" ← 下から実行
// "B デコレータ 呼び出し" ← 下から実行
// "A デコレータ 呼び出し" ← 下から実行
```

| フェーズ | 順序 |
|---------|------|
| **ファクトリの評価**（`@A()` の `A()` 呼び出し） | 上から下 |
| **デコレータ関数の実行** | 下から上 |
| **実行タイミング** | クラス・メソッド宣言時（インスタンス化時ではない） |

---

## 型付きデコレータ — ジェネリクスパターン早見表

```typescript
// メソッドデコレータ（完全型安全版）
function decorator<This, Args extends any[], Return>(
  method: (this: This, ...args: Args) => Return,
  context: ClassMethodDecoratorContext<This, (this: This, ...args: Args) => Return>
): (this: This, ...args: Args) => Return | void

// フィールドデコレータ
function decorator<This, V>(
  _: undefined,
  context: ClassFieldDecoratorContext<This, V>
): (this: This, initialValue: V) => V | void

// クラスデコレータ
function decorator<This extends abstract new (...args: any[]) => any>(
  target: This,
  context: ClassDecoratorContext<This>
): This | void
```

> **実用指針**: デコレータの型が複雑になる場合は `any` から始めて段階的に型を厳格化する。ライブラリ提供のデコレータを使う場合は型定義を読む必要は通常ない。

---

## 参照

- 書籍: 「現場で使えるTypeScript詳解実践ガイド」Chapter 7
- TypeScript 5.0 リリースノート: Decorators（ECMAScript Stage 3準拠）
