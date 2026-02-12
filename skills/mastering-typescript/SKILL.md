---
name: mastering-typescript
description: Comprehensive TypeScript guide covering type system, advanced patterns, design patterns (GoF Creational/Structural/Behavioral), functional/reactive programming, framework integration, and 83 best practice decision criteria. MUST load when working in TypeScript projects detected by tsconfig.json. Covers Generics, Conditional Types, type inference, type design, SOLID/DDD in TypeScript, anti-patterns, and practical migration tips. For strict type safety rules, use enforcing-type-safety instead.
---

# TypeScript マスターガイド

TypeScript言語機能の包括的リファレンス。型システムの基礎から高度なパターン、フレームワーク統合まで、実践的なTypeScript開発知識を提供する。

---

## 1. 使用タイミング

- **TypeScriptコードを書くとき**: 型アノテーション、ジェネリクス、型ガードの正しい使い方を確認
- **型設計・アーキテクチャ**: Interface、Enum、Union/Intersection型の設計判断
- **フレームワーク統合時**: React、Angular、Vue.js、Node.js/ExpressでのTypeScript活用パターン
- **エラーハンドリング設計**: Promise、async/awaitでの型安全なエラー処理
- **コード保守性向上**: TypeScriptのベストプラクティスに基づくリファクタリング

---

## 2. コアプリンシプル

### 2.1 型は契約である

**型はコードと他の開発者（または未来の自分）との間の契約。データの形状を明確に定義することで、コンパイル時にエラーを検出する。**

- 変数、関数パラメータ、戻り値には適切な型を付与
- `any` は原則禁止（`unknown` + 型ガードを使用）
- 型推論を活用しつつ、複雑な箇所では明示的な型アノテーションを使用

### 2.2 静的型付けの3つの恩恵

| 恩恵 | 説明 |
|------|------|
| **コード補完の向上** | IDEが正確な補完候補を提示。型情報に基づく自動補完でtypoやAPI誤用を防止 |
| **コンパイル時エラー検出** | ランタイムではなくビルド時にバグを発見。`Type 'null' is not assignable to type 'number'` のような明確なエラー |
| **自己文書化コード** | 型アノテーション自体がドキュメントの役割を果たす。関数シグネチャを見るだけで使い方が分かる |

### 2.3 型推論を信頼しつつ、明示的に書くべき場所を見極める

```typescript
// ✅ 型推論に任せる（シンプルな代入）
const name = 'John';        // string と推論
const count = 42;            // number と推論
const items = [1, 2, 3];    // number[] と推論

// ✅ 明示的に書く（関数シグネチャ）
function add(a: number, b: number): number {
  return a + b;
}

// ✅ 明示的に書く（複雑なオブジェクト）
interface UserResponse {
  id: number;
  name: string;
  email: string;
}
```

| 場面 | 推奨 | 理由 |
|------|------|------|
| 変数の初期化 | 型推論 | 冗長な型アノテーション不要 |
| 関数パラメータ | 明示的 | 呼び出し側の安全性を保証 |
| 関数戻り値 | 明示的 | APIの契約を明確化 |
| 空配列 | 明示的 | `never[]` 推論を避ける |

### 2.4 ユーザー確認の原則（AskUserQuestion）

**判断分岐がある場合、推測で進めず必ずAskUserQuestionツールでユーザーに確認する。**

確認すべき場面:
- **型定義の設計方針**: `interface` vs `type` の選択（拡張性が必要か）
- **Enum vs Union型**: `enum Color { Red, Green }` vs `type Color = 'red' | 'green'`
- **型の厳密度**: `strict: true` の全オプションを有効にするか
- **フレームワーク選択**: React/Angular/Vue.jsの型定義パターン

確認不要な場面:
- `any` の禁止（常に `unknown` + 型ガードを推奨）
- 関数パラメータへの型アノテーション（常に推奨）
- `null` / `undefined` の明示的なハンドリング（常に推奨）

---

## 3. クイックリファレンス

### 基本型一覧

| 型 | 説明 | 例 |
|----|------|-----|
| `number` | 数値 | `let age: number = 25;` |
| `string` | 文字列 | `let name: string = 'John';` |
| `boolean` | 真偽値 | `let isAdmin: boolean = true;` |
| `Array<T>` | 配列 | `let nums: number[] = [1, 2, 3];` |
| `void` | 戻り値なし | `function log(): void { ... }` |
| `null` / `undefined` | 空値 | `let user: string \| null;` |
| `unknown` | 型不明（安全） | `let data: unknown;` |
| `never` | 到達不能 | `function fail(): never { throw new Error(); }` |

### interface vs type

| 特性 | `interface` | `type` |
|------|------------|--------|
| extends / implements | ✅ | ❌（`&` で代用） |
| Declaration Merging | ✅ | ❌ |
| Computed Properties | ❌ | ✅ |
| Union / Intersection | ❌ | ✅ |
| **推奨場面** | オブジェクト形状定義、クラス実装 | ユニオン型、ユーティリティ型 |

---

## 4. 詳細ガイド

トピック別の詳細ガイドは以下を参照:

- **[TYPE-SYSTEM.md](./references/TYPE-SYSTEM.md)**: 基本型、型推論、型アノテーション、変数・関数・モジュール、Interface、Enum
- **[ADVANCED-PATTERNS.md](./references/ADVANCED-PATTERNS.md)**: Generics、Union Types、Intersections、Type Guards、Conditional Types、エラーハンドリング
- **[FRAMEWORK-INTEGRATION.md](./references/FRAMEWORK-INTEGRATION.md)**: React、Angular、Vue.js/Nuxt、Node.js/Express統合パターン

---

## 5. 関連スキル

| スキル | 関係 |
|--------|------|
| `enforcing-type-safety` | 型安全性の強制ルール（`any`禁止等）。本スキルは「学ぶ」、あちらは「強制する」 |
| `developing-nextjs` | Next.js固有のTypeScript設定・パターン（React性能最適化含む） |
| `developing-fullstack-javascript` | フルスタックJS/TSアーキテクチャ戦略 |

---

## 6. まとめ

**優先順位:**

1. **型安全性を常に最優先**: `any` は使わない、`unknown` + 型ガードを使う
2. **型推論を信頼しつつ、公開APIは明示的に型付け**: 関数シグネチャ、exportされる型は明示
3. **Interfaceでオブジェクト形状を定義**: Declaration Mergingが必要ならInterface、それ以外はtype aliasも可
4. **Genericsで再利用性を高める**: 同じロジックの型違いはジェネリクスで抽象化
5. **フレームワーク固有の型パターンを活用**: `React.FC<Props>`, `Request/Response` 型等

---

## Effective TypeScript

83項目のTypeScript実装判断基準。

| ファイル | 内容 |
|---------|------|
| [ET-CH01-FUNDAMENTALS.md](./references/ET-CH01-FUNDAMENTALS.md) | 基礎と設定 |
| [ET-CH03-TYPE-INFERENCE.md](./references/ET-CH03-TYPE-INFERENCE.md) | 型推論 |
| [ET-CH04-TYPE-DESIGN.md](./references/ET-CH04-TYPE-DESIGN.md) | 型設計 |
| [ET-CH05-UNSOUNDNESS-AND-ANY.md](./references/ET-CH05-UNSOUNDNESS-AND-ANY.md) | 型の不健全性とany |
| [ET-CH06-GENERICS.md](./references/ET-CH06-GENERICS.md) | ジェネリクス |
| [ET-CH07-RECIPES.md](./references/ET-CH07-RECIPES.md) | レシピ集 |
| [ET-CH08-TYPE-DECLARATIONS.md](./references/ET-CH08-TYPE-DECLARATIONS.md) | 型宣言 |
| [ET-CH09-PRACTICAL-TIPS.md](./references/ET-CH09-PRACTICAL-TIPS.md) | 実践的なTips |
| [ET-CH10-MIGRATION.md](./references/ET-CH10-MIGRATION.md) | 移行ガイド |

---

## Programming TypeScript

TypeScriptの型システム・関数・クラス・非同期処理・モジュール・ビルドの包括的ガイド。

| ファイル | 内容 |
|---------|------|
| [PT-CH03-TYPES.md](./references/PT-CH03-TYPES.md) | 型の基礎と階層構造 |
| [PT-CH04-FUNCTIONS.md](./references/PT-CH04-FUNCTIONS.md) | 関数の型付けとジェネリクス |
| [PT-CH05-CLASSES.md](./references/PT-CH05-CLASSES.md) | クラスとインターフェース |
| [PT-CH06-ADVANCED-TYPES.md](./references/PT-CH06-ADVANCED-TYPES.md) | 高度な型（変性・拡大・絞り込み・ブランド型） |
| [PT-CH07-ERROR-HANDLING.md](./references/PT-CH07-ERROR-HANDLING.md) | 型安全なエラー処理パターン |
| [PT-CH08-ASYNC.md](./references/PT-CH08-ASYNC.md) | 非同期プログラミングの型付け |
| [PT-CH09-10-MODULES.md](./references/PT-CH09-10-MODULES.md) | フレームワーク・モジュール・宣言マージ |
| [PT-CH11-JS-INTEROP.md](./references/PT-CH11-JS-INTEROP.md) | JavaScript相互運用と漸進的移行 |
| [PT-CH12-BUILD.md](./references/PT-CH12-BUILD.md) | ビルド・実行・npm公開 |
| [PT-APPENDICES.md](./references/PT-APPENDICES.md) | 型演算子・Utility Types・TSCフラグ等リファレンス |

---

## Design Patterns & Best Practices

TypeScript 5でのデザインパターンと設計原則の包括的ガイド。GoFパターン22種、関数型/リアクティブプログラミング、DDD/SOLID/MVC、アンチパターン回避を網羅。

| ファイル | 内容 |
|---------|------|
| [DP-FOUNDATIONS.md](./references/DP-FOUNDATIONS.md) | TS5新機能、OOP原則、環境構築、デザインパターン概論 |
| [DP-CREATIONAL.md](./references/DP-CREATIONAL.md) | Singleton, Prototype, Builder, Factory Method, Abstract Factory |
| [DP-STRUCTURAL.md](./references/DP-STRUCTURAL.md) | Adapter, Decorator, Façade, Composite, Proxy, Bridge, Flyweight |
| [DP-BEHAVIORAL.md](./references/DP-BEHAVIORAL.md) | Strategy, CoR, Command, Mediator, Observer, Iterator, Memento, State, Template Method, Visitor |
| [DP-FUNCTIONAL-REACTIVE.md](./references/DP-FUNCTIONAL-REACTIVE.md) | FP（Monads, Functors, Lenses）+ Reactive（Promises, Observables） |
| [DP-ARCHITECTURE.md](./references/DP-ARCHITECTURE.md) | DDD, SOLID, MVC、パターン結合、Utility Types活用 |
| [DP-ANTI-PATTERNS.md](./references/DP-ANTI-PATTERNS.md) | TypeScriptアンチパターン + OSSパターン（Apollo, tRPC） |
