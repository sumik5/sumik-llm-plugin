---
name: applying-go-design-patterns
description: GoF design patterns, Go concurrency patterns, and advanced architectural patterns in Go. Use when designing Go systems or choosing design patterns. Covers DDD/CQRS/Event Sourcing and pattern testing. Complements developing-go with design-level guidance.
---

# Goデザインパターンガイド（Applying Go Design Patterns）

Goのインターフェース・組込み・first-class関数を活かしたデザインパターン適用の包括的ガイド。

## はじめに

Goは古典的なオブジェクト指向プログラミング（OOP）言語とは異なる特性を持つ:

- **継承なし**: クラスベースの継承機構は存在しない
- **組込み優先**: `type Dog struct { Animal }` のような構造体の組込み（composition）を推奨
- **暗黙的インターフェース実装**: `implements` キーワード不要、interfaceを満たせば自動的に実装
- **first-class関数**: 関数を値として扱い、戦略パターン等で活用
- **並行処理ファーストクラス**: goroutine/channelによる並行処理パターンが言語組込み

このガイドでは、各デザインパターンのGo idiomatic実装、使用判断基準、アンチパターン回避を網羅する。

---

## 🎯 使用タイミング

以下の場面でこのスキルを参照する:

- **Goシステム設計時のパターン選択**: 新規プロジェクトでアーキテクチャを決定する際
- **既存Goコードのリファクタリング**: Code Smellの検出と改善パターンの適用
- **並行処理の設計**: goroutine/channelを活用した並行処理パターンの実装
- **マイクロサービスアーキテクチャ構築**: Circuit Breaker、CQRS、Event Sourcing等の高度なパターン
- **テスト容易性の向上**: Dependency Injection、Strategy、Mock等の活用
- **コードレビューでのパターン適用評価**: パターンの適切性・Go idiomへの適合性の検証

---

## 📚 ドキュメント構成

本スキルは以下のサブファイルで構成される（Progressive Disclosure）:

| サブファイル | 内容 |
|-------------|------|
| [生成パターン（Creational）](./CREATIONAL.md) | Singleton, Factory Method, Abstract Factory, Builder, Prototype, Dependency Injection |
| [構造パターン（Structural）](./STRUCTURAL.md) | Adapter, Bridge, Composite, Decorator, Facade, Flyweight, Proxy |
| [振舞いパターン（Behavioral）](./BEHAVIORAL.md) | Chain of Responsibility, Command, Iterator, Mediator, Memento, Observer, State, Strategy, Template Method, Visitor, Interpreter |
| [並行処理パターン（Concurrency）](./CONCURRENCY.md) | Producer-Consumer, Fan-In/Fan-Out, Pipeline, Worker Pool, Circuit Breaker, Context管理 |
| [アンチパターンとリファクタリング](./ANTI-PATTERNS.md) | よくある失敗パターン、Code Smell検出、リファクタリング戦略 |
| [高度なパターン（Advanced）](./ADVANCED.md) | DI Framework、Event Sourcing、CQRS、マイクロサービスパターン、Domain-Driven Design、リアクティブパターン |
| [パターンのテスト戦略（Testing）](./TESTING.md) | ユニットテスト、統合テスト、パフォーマンステスト、TDD、Mock戦略 |

---

## 🔑 GoにおけるOOP基礎

Goのデザインパターンを理解するには、Go独自のOOPアプローチを把握する必要がある。

### カプセル化

パッケージスコープと識別子の大文字/小文字で制御:

- **大文字始まり**: パッケージ外からアクセス可能（exported）
- **小文字始まり**: パッケージ内でのみアクセス可能（unexported）

```go
type user struct {        // unexported型
    name string           // unexported フィールド
    age  int             // unexported フィールド
}

func (u *user) GetName() string {  // exportedメソッド
    return u.name
}
```

### 継承なし → 組込み（Composition）

Goにクラス継承はない。代わりに構造体の組込みを使う:

```go
type Animal struct {
    Name string
}

func (a Animal) Speak() string {
    return "..."
}

type Dog struct {
    Animal  // Animalを組込み
    Breed string
}

// Dogは自動的にAnimalのメソッドを持つ
dog := Dog{Animal: Animal{Name: "Rex"}, Breed: "Labrador"}
fmt.Println(dog.Speak())  // "..."
```

### ポリモーフィズム: Interface + 暗黙的実装

```go
type Speaker interface {
    Speak() string
}

type Dog struct{}
func (d Dog) Speak() string { return "Woof!" }

type Cat struct{}
func (c Cat) Speak() string { return "Meow!" }

// DogもCatもSpeakerインターフェースを満たす（暗黙的実装）
func MakeSound(s Speaker) {
    fmt.Println(s.Speak())
}
```

### 抽象化: Interface定義

Goのinterfaceは小さく保つのがidiomatic:

```go
// 悪い例: 大きすぎるinterface
type Repository interface {
    Create(ctx context.Context, entity Entity) error
    Read(ctx context.Context, id string) (Entity, error)
    Update(ctx context.Context, entity Entity) error
    Delete(ctx context.Context, id string) error
    List(ctx context.Context) ([]Entity, error)
}

// 良い例: 小さなinterface組み合わせ
type Creator interface {
    Create(ctx context.Context, entity Entity) error
}

type Reader interface {
    Read(ctx context.Context, id string) (Entity, error)
}

type Updater interface {
    Update(ctx context.Context, entity Entity) error
}
```

---

## 🗺️ パターン選択クイックリファレンス

### 生成パターン（Creational Patterns）

オブジェクト生成の柔軟性・再利用性を高める。

| パターン | 使用場面 | Goイディオム | サブファイル |
|---------|---------|-------------|-------------|
| **Singleton** | 共有リソース（設定、ログ、DB接続プール）を1インスタンスのみ作成 | `sync.Once`による遅延初期化 | [CREATIONAL.md](./CREATIONAL.md#singleton) |
| **Factory Method** | 型に基づくオブジェクト生成（抽象化された生成ロジック） | interface + コンストラクタ関数 `NewXxx()` | [CREATIONAL.md](./CREATIONAL.md#factory-method) |
| **Abstract Factory** | 関連するオブジェクト群の一括生成（テーマ、DB方言） | interface群の返却 | [CREATIONAL.md](./CREATIONAL.md#abstract-factory) |
| **Builder** | 複雑な設定のオブジェクト構築（多数のオプション、段階的構築） | メソッドチェーン / Functional Options | [CREATIONAL.md](./CREATIONAL.md#builder) |
| **Prototype** | オブジェクトのクローン（コストの高い初期化を避ける） | `Clone()` interface実装 | [CREATIONAL.md](./CREATIONAL.md#prototype) |
| **Dependency Injection** | テスト容易性・疎結合の実現 | コンストラクタインジェクション、interface依存 | [CREATIONAL.md](./CREATIONAL.md#dependency-injection) |

### 構造パターン（Structural Patterns）

クラス・オブジェクト間の関係を柔軟に構成。

| パターン | 使用場面 | Goイディオム | サブファイル |
|---------|---------|-------------|-------------|
| **Adapter** | 互換性のないインターフェース接続（外部ライブラリの統合） | ラッパーstruct + interface実装 | [STRUCTURAL.md](./STRUCTURAL.md#adapter) |
| **Bridge** | 抽象と実装の分離（複数の実装を切替可能に） | 組込み + interface | [STRUCTURAL.md](./STRUCTURAL.md#bridge) |
| **Composite** | ツリー構造の管理（ファイルシステム、UI階層） | 再帰的interface実装 | [STRUCTURAL.md](./STRUCTURAL.md#composite) |
| **Decorator** | 動的な振舞い追加（既存オブジェクトの拡張） | interface + ラッピングstruct | [STRUCTURAL.md](./STRUCTURAL.md#decorator) |
| **Facade** | 複雑システムの簡略化（統一されたシンプルなAPI） | シンプルなAPIを提供するstruct | [STRUCTURAL.md](./STRUCTURAL.md#facade) |
| **Flyweight** | メモリ使用量削減（大量の類似オブジェクト） | `sync.Pool` / 共有データ構造 | [STRUCTURAL.md](./STRUCTURAL.md#flyweight) |
| **Proxy** | アクセス制御・遅延初期化（リモートオブジェクト、キャッシュ） | 同一interface実装のラッパー | [STRUCTURAL.md](./STRUCTURAL.md#proxy) |

### 振舞いパターン（Behavioral Patterns）

オブジェクト間の責任分担・通信方法を定義。

| パターン | 使用場面 | Goイディオム | サブファイル |
|---------|---------|-------------|-------------|
| **Chain of Responsibility** | 順序付き処理チェーン（HTTPミドルウェア、承認ワークフロー） | handler interface + next参照 | [BEHAVIORAL.md](./BEHAVIORAL.md#chain-of-responsibility) |
| **Command** | リクエストのカプセル化（Undo/Redo、タスクキュー） | `func()` / Command interface | [BEHAVIORAL.md](./BEHAVIORAL.md#command) |
| **Iterator** | コレクション走査（カスタムデータ構造の反復処理） | channel / generics（Go 1.18+） | [BEHAVIORAL.md](./BEHAVIORAL.md#iterator) |
| **Mediator** | オブジェクト間通信の集約（複雑な相互依存の簡素化） | 仲介struct、channelベースの通信 | [BEHAVIORAL.md](./BEHAVIORAL.md#mediator) |
| **Memento** | 状態の保存・復元（Undo、チェックポイント） | スナップショットstruct、immutable設計 | [BEHAVIORAL.md](./BEHAVIORAL.md#memento) |
| **Observer** | イベント駆動通知（発行-購読パターン） | channel / callback関数 | [BEHAVIORAL.md](./BEHAVIORAL.md#observer) |
| **State** | 状態に応じた振舞い変更（ステートマシン） | state interface + context struct | [BEHAVIORAL.md](./BEHAVIORAL.md#state) |
| **Strategy** | アルゴリズムの動的切替（ソート、圧縮、認証方式） | `func` 型 / Strategy interface | [BEHAVIORAL.md](./BEHAVIORAL.md#strategy) |
| **Template Method** | アルゴリズムの骨格定義（共通処理 + カスタマイズポイント） | interface + デフォルト実装 | [BEHAVIORAL.md](./BEHAVIORAL.md#template-method) |
| **Visitor** | オブジェクトへの操作追加（構造を変えずに新機能追加） | accept/visit interface | [BEHAVIORAL.md](./BEHAVIORAL.md#visitor) |
| **Interpreter** | 言語文法の解釈（DSL、設定ファイルパーサ） | 抽象構文木（AST） + interface | [BEHAVIORAL.md](./BEHAVIORAL.md#interpreter) |

### 並行処理パターン（Concurrency Patterns）

Goのgoroutine/channelを活用した並行処理の設計。

| パターン | 使用場面 | Goイディオム | サブファイル |
|---------|---------|-------------|-------------|
| **Producer-Consumer** | 生産-消費の分離（ワークキュー、メッセージ処理） | buffered channel、goroutine | [CONCURRENCY.md](./CONCURRENCY.md#producer-consumer) |
| **Fan-In/Fan-Out** | 並列処理の分散・集約（データ並列処理、集約ポイント） | 複数goroutine + channel合成 | [CONCURRENCY.md](./CONCURRENCY.md#fan-in-fan-out) |
| **Pipeline** | データストリーム処理（ETLパイプライン、画像処理） | channel連鎖、`<-chan`/`chan<-`の型制約 | [CONCURRENCY.md](./CONCURRENCY.md#pipeline) |
| **Worker Pool** | タスク並列実行（スループット制御、リソース制限） | buffered channel + `sync.WaitGroup` | [CONCURRENCY.md](./CONCURRENCY.md#worker-pool) |
| **Circuit Breaker** | 障害の伝播防止（外部API障害の分離、フォールバック） | state管理struct + タイムアウト | [CONCURRENCY.md](./CONCURRENCY.md#circuit-breaker) |
| **Context管理** | キャンセル伝播・タイムアウト・値の伝播 | `context.Context` | [CONCURRENCY.md](./CONCURRENCY.md#context) |

---

## ⚠️ ユーザー確認の原則（AskUserQuestion）

**判断分岐がある場合、推測で進めず必ずAskUserQuestionツールでユーザーに確認する。**

### 確認すべき場面

以下のような場面ではユーザーに選択肢を提示する:

1. **複数パターンが適用可能な場合**
   - 例: Strategy vs State（状態遷移が複雑な場合はState、アルゴリズム切替のみならStrategy）
   - 例: Factory Method vs Abstract Factory（単一型の生成か、関連型群の生成か）

2. **パターンの組み合わせ方**
   - 例: Factory + Dependency Injection（DIコンテナの有無、手動配線かフレームワークか）
   - 例: Decorator + Chain of Responsibility（ミドルウェア設計の階層構造）

3. **並行処理パターンの選択**
   - 例: Worker Pool vs Pipeline（スループット優先か、メモリ効率優先か）
   - 例: Fan-Out数の決定（CPU数に基づくか、I/Oボトルネックを考慮するか）

4. **マイクロサービスパターンの採用**
   - 例: Circuit Breaker導入の必要性（外部依存の信頼性、フォールバック戦略）
   - 例: CQRS採用の是非（読込/書込の負荷特性、複雑性のトレードオフ）

### 確認不要な場面

以下はGo idiomとして確立されており、確認不要:

- `sync.Once`によるSingleton実装
- コンストラクタインジェクションによるDI
- interfaceを使ったポリモーフィズム
- `context.Context`の伝播
- エラーハンドリングの`if err != nil`パターン

### 確認時のテンプレート例

```go
// 悪い例: 推測で実装
// ユーザーが求めるのはStrategyかStateか不明なまま実装

// 良い例: AskUserQuestionで確認
AskUserQuestion(
    questions=[{
        "question": "アルゴリズムの切替設計について確認します。以下のどちらのアプローチを希望しますか？",
        "header": "パターン選択",
        "options": [
            {
                "label": "Strategy Pattern",
                "description": "アルゴリズムを動的に切替。状態遷移なし、単純な切替のみ。"
            },
            {
                "label": "State Pattern",
                "description": "状態遷移を管理。状態ごとに異なる振舞い、遷移ルールあり。"
            },
            {
                "label": "詳細確認",
                "description": "要件を詳しく聞いてから判断"
            }
        ],
        "multiSelect": False
    }]
)
```

---

## 🔗 関連スキル

| スキル | 関係性 |
|--------|-------|
| [`developing-go`](../developing-go/SKILL.md) | **Go言語基礎・クリーンコード**: 命名規則、エラーハンドリング、テスト戦略、パッケージ構成、関数設計、リファクタリング。本スキルの前提知識。 |
| [`writing-clean-code`](../writing-clean-code/SKILL.md) | **SOLID原則**: 言語非依存の設計原則。本スキルはGo固有の適用方法を扱う。 |
| [`testing`](../testing/SKILL.md) | **テスト全般**: テスト戦略、TDD、カバレッジ。本スキルの[TESTING.md](./TESTING.md)はパターン特化。 |
| [`modernizing-architecture`](../modernizing-architecture/SKILL.md) | **アーキテクチャモダナイゼーション**: マイクロサービス、イベント駆動。本スキルの[ADVANCED.md](./ADVANCED.md)で詳細解説。 |

---

## パターン適用のベストプラクティス

### 1. まず標準ライブラリとGo idiomを確認

デザインパターンを適用する前に、Go標準ライブラリや言語機能で解決できないか検討する:

- **Singleton**: `sync.Once`
- **Iterator**: channel、`range`
- **Strategy**: first-class関数
- **Template Method**: interface + デフォルト実装
- **Observer**: channel + `select`

### 2. 小さなinterfaceを優先

Goのinterfaceは小さく保つのがidiomatic:

```go
// 悪い例
type DataService interface {
    Create(...) error
    Read(...) error
    Update(...) error
    Delete(...) error
    List(...) error
    Count(...) error
}

// 良い例
type Creator interface { Create(...) error }
type Reader interface { Read(...) error }
type Updater interface { Update(...) error }
type Deleter interface { Delete(...) error }
```

### 3. 組込み（Composition）を活用

継承の代わりに組込みを使う:

```go
type BaseHandler struct {
    logger Logger
}

func (h *BaseHandler) Log(msg string) {
    h.logger.Info(msg)
}

type UserHandler struct {
    BaseHandler  // 組込み
    repo UserRepository
}
```

### 4. エラーハンドリングとパターンの統合

Goのエラーハンドリングをパターンに組み込む:

```go
type Result struct {
    Value interface{}
    Err   error
}

func (r Result) IsSuccess() bool {
    return r.Err == nil
}
```

### 5. テスト容易性を優先

パターン選択時はテストのしやすさを重視:

- Dependency Injectionでモック可能に
- interfaceを小さく保ち、テストダブル作成を容易に
- 並行処理パターンでは`context.Context`でテスト制御

---

## パターン学習のロードマップ

### 初級（Goデザインパターン入門）

1. **Dependency Injection**: テスト容易性の向上
2. **Factory Method**: オブジェクト生成の抽象化
3. **Strategy**: アルゴリズムの動的切替
4. **Decorator**: HTTP middleware実装

### 中級（実践的パターン活用）

1. **Builder（Functional Options）**: 複雑な設定管理
2. **Singleton（sync.Once）**: 共有リソース管理
3. **Chain of Responsibility**: ミドルウェアチェーン
4. **Observer（channel）**: イベント駆動設計
5. **Worker Pool**: 並行タスク処理

### 上級（高度なアーキテクチャパターン）

1. **Circuit Breaker**: 障害分離
2. **CQRS**: 読込/書込分離
3. **Event Sourcing**: イベントストア設計
4. **Domain-Driven Design**: ドメインモデリング
5. **マイクロサービスパターン**: サービス間通信、Saga

---

## クイックスタートガイド

### ステップ1: 問題の特定

以下の質問に答える:

- 何を生成する？ → **生成パターン**
- どう構成する？ → **構造パターン**
- どう振る舞う？ → **振舞いパターン**
- 並行処理が必要？ → **並行処理パターン**

### ステップ2: パターン候補の選定

上記の「パターン選択クイックリファレンス」を参照し、3つ程度に絞り込む。

### ステップ3: Go idiomとの適合性確認

- 標準ライブラリで解決可能か？
- 小さなinterfaceで表現可能か？
- テスト容易性は確保されるか？

### ステップ4: サブファイルで詳細確認

該当するサブファイル（CREATIONAL.md、STRUCTURAL.md等）で実装例とトレードオフを確認。

### ステップ5: 実装とテスト

TDDアプローチで実装:

1. テスト作成（期待される振舞いを定義）
2. パターン実装
3. リファクタリング

詳細は [TESTING.md](./TESTING.md) を参照。

---

## まとめ

このスキルでは、Goにおけるデザインパターンの適用方法を以下の観点から体系的に学習できる:

- **23のGoFパターン**（生成・構造・振舞い）のGo idiomatic実装
- **並行処理パターン**（goroutine/channel活用）
- **アンチパターン回避**とリファクタリング戦略
- **高度なパターン**（DDD、CQRS、Event Sourcing、マイクロサービス）
- **テスト戦略**（ユニットテスト、統合テスト、TDD）

各サブファイルで詳細な実装例、トレードオフ、使用判断基準を提供している。状況に応じて該当セクションを参照し、Go idiomに沿った設計を実践すること。
