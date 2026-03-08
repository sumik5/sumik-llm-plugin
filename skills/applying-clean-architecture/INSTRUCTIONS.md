# Clean Architecture 実践ガイド

## 目次

1. [核心原則：依存性ルール](#依存性ルール)
2. [同心円モデル（4レイヤー）](#同心円モデル)
3. [境界横断パターン](#境界横断パターン)
4. [コンポーネント設計原則](#コンポーネント設計原則)
5. [アーキテクチャパターン](#アーキテクチャパターン)
6. [実践ガイド](#実践ガイド)
7. [適用判断フロー](#適用判断フロー)
8. [相互参照マップ](#相互参照マップ)

---

## 依存性ルール

**The Dependency Rule：ソースコードの依存関係は内側に向かってのみ指向しなければならない。**

これがClean Architectureを機能させる唯一の絶対ルールである。同心円の内側にあるものは、外側にあるものを一切知ってはならない。

```
外側（メカニズム） → 内側（ポリシー）
Frameworks & Drivers → Interface Adapters → Use Cases → Entities
```

**依存性ルール違反のチェック：**
- 内側のレイヤーが外側のクラス名・関数名・変数名を参照していないか
- 外側のフレームワークで定義されたデータ構造を内側が使用していないか
- DBの行構造（Row Structure）を内側に渡していないか

境界を越えるデータは必ず**シンプルなデータ構造**（DTO、プリミティブ型）のみ。Entity オブジェクトや DB 行構造をそのまま渡してはならない。

---

## 同心円モデル

### レイヤー1：エンティティ（Entities）

エンタープライズ規模のビジネスルールをカプセル化する。最も内側で変化に最も強い。

- メソッドを持つオブジェクト、またはデータ構造と関数のセット
- フレームワーク、DB、UI の変化に影響されない
- 複数のアプリケーション間で共有可能な高レベルルール

### レイヤー2：ユースケース（Use Cases）

アプリケーション固有のビジネスルールを含む。エンティティへの操作を指揮する。

- ユースケースの入出力は**Request/Response モデル**（単純な DTO）
- エンティティの変化はユースケースに影響しない（逆も同様）
- DB、UI、フレームワークの変化に影響されない

### レイヤー3：インターフェースアダプター（Interface Adapters）

ユースケース/エンティティに最適なフォーマット ↔ 外部（DB、Web）に最適なフォーマット の変換を担う。

- MVC の Controller、Presenter、View はすべてこの層に属する
- SQL はこの層に閉じ込める（ユースケース層には SQL を書かない）
- 外部サービスとの変換アダプターもここに配置

### レイヤー4：フレームワーク＆ドライバー（Frameworks & Drivers）

DB、Webフレームワーク、UI フレームワーク等が位置する最外層。

- ほとんどのコードは「接着剤コード」（Glue Code）
- Web はここでの詳細（Detail）に過ぎない
- DB はここでの詳細に過ぎない

> **アーキテクチャの目標**：DB、Web、フレームワークを**詳細**として扱い、高レベルポリシー（ビジネスルール）から決定を遅らせる。

---

## 境界横断パターン

### 制御フローと依存方向の解決

制御フローが外から内（Controller → UseCase）に流れる場合は自然。しかし内から外（UseCase → Presenter）に制御が流れる場合は**依存性逆転の原則（DIP）**を適用する。

```
UseCase → [OutputBoundary interface] ← Presenter
                   ↑
            依存性逆転で解決
```

ユースケースが Presenter を直接呼び出すと依存性ルール違反。代わりに内側に `OutputBoundary` インターフェースを定義し、外側の `Presenter` がそれを実装する。

### 典型的なデータフロー

```
Web Request
  → Controller（Request DTO 生成）
  → UseCase Interactor（InputBoundary 経由）
    → Entity 操作
    → DataAccessInterface 経由で DB アクセス
  → OutputData 生成（OutputBoundary 経由）
  → Presenter（ViewModel 生成）
  → View（HTML レンダリング）
```

---

## コンポーネント設計原則

詳細は [references/COMPONENT-PRINCIPLES.md](references/COMPONENT-PRINCIPLES.md) を参照。

### 凝集性の3原則（何をコンポーネントに含めるか）

| 原則 | 略称 | 内容 | ポイント |
|------|------|------|---------|
| Reuse/Release Equivalence | REP | リリース単位 = 再利用単位 | リリース管理された粒度でコンポーネントを形成する |
| Common Closure | CCP | 同じ理由・同じタイミングで変わるものを集める | SRP のコンポーネント版 |
| Common Reuse | CRP | 一緒に使われるものだけを同一コンポーネントに | ISP のコンポーネント版 |

**テンションダイアグラム：** REP・CCP は包含的（コンポーネントを大きくする）。CRP は排他的（小さくする）。プロジェクトフェーズや優先度に応じてバランスを取る。

### 結合の3原則（コンポーネント間の関係）

| 原則 | 略称 | 内容 |
|------|------|------|
| Acyclic Dependencies | ADP | コンポーネント依存グラフに循環を許さない |
| Stable Dependencies | SDP | 安定したコンポーネントに依存する。不安定なものに依存するな |
| Stable Abstractions | SAP | 安定なコンポーネントは抽象的であるべき |

**安定度メトリクス：**
```
不安定度（I）= Fan-out / (Fan-in + Fan-out)
抽象度（A）= 抽象クラス数 / 全クラス数
理想: I ≈ 0 かつ A ≈ 1（安定した抽象コンポーネント）
      I ≈ 1 かつ A ≈ 0（不安定な具体コンポーネント）
```

**循環依存の解消法：**
1. 新しいコンポーネントを作成して依存を再配置する
2. Dependency Inversion Principle（DIP）を適用してインターフェースを経由させる

---

## アーキテクチャパターン

### Screaming Architecture（叫ぶアーキテクチャ）

システムのトップレベルディレクトリ構造を見たとき、フレームワーク名ではなく**ビジネスドメイン名**が見えるべき。

```
❌ 悪い例（フレームワークが叫んでいる）
src/
  controllers/
  models/
  views/

✅ 良い例（ユースケースが叫んでいる）
src/
  billing/
  ordering/
  inventory/
```

ディレクトリ構造はユースケースを表明し、フレームワークは詳細として端に追いやられるべき。

### Humble Object パターン

**テストしにくい振る舞い**と**テストしやすい振る舞い**を分離するパターン。アーキテクチャ境界の識別に有効。

| Humble Object（テスト困難） | Testable Object（テスト容易） |
|---------------------------|----------------------------|
| View（画面表示） | Presenter（データ整形） |
| DB 実装（SQL 実行） | Gateway Interface（ビジネスロジック） |
| ORM/Data Mapper | UseCase Interactor |

- Presenter: データを ViewModel（文字列・boolean・enum のみ）に変換。View は ViewModel をそのまま表示するだけ
- Database Gateway: ユースケースに必要な操作をインターフェースとして定義。SQL はこのインターフェースの実装側（Humble Object）に閉じ込める

### Partial Boundaries（部分的境界）

完全な境界構築のコストが高い場合の代替戦略。YAGNI との兼ね合いでアーキテクトが判断する。

| 戦略 | 方法 | コスト | リスク |
|------|------|--------|--------|
| 境界準備型 | 相互インターフェース・DTO を作るが、同一コンポーネントとしてビルド | コード量は完全境界と同等 | 時間経過で境界が薄れる危険あり |
| 一方向境界（Strategy） | `ServiceBoundary` インターフェースで片側のみ逆転 | 中程度 | 逆方向の依存が徐々に混入するリスク |
| Facade | Facade クラスで境界を定義、DI なし | 最小 | クライアントが実装クラスに推移的依存する |

### Main Component

アプリケーションで唯一、汚れること（具体的詳細を知ること）が許される最外層コンポーネント。

- すべての Factory、Strategy、グローバル設定を生成
- DI フレームワークはここでのみ使用し、内側には注入しない
- Dev/Test/Prod 等の環境ごとに異なる Main コンポーネントを持つことができる

---

## 実践ガイド

### DB・Web・フレームワークは詳細

```
// ❌ Bad: UseCase が DB 実装に直接依存
class CreateOrderUseCase {
  constructor(private db: PostgresDatabase) {}
}

// ✅ Good: UseCase は抽象インターフェースにのみ依存
interface OrderRepository {
  save(order: Order): void;
}
class CreateOrderUseCase {
  constructor(private repo: OrderRepository) {}
}
// PostgresRepository: OrderRepository は外側のレイヤーに配置
```

### テスト境界の設計

- ユースケース層はフレームワークなしでテスト可能にする
- DB Gateway を stub に差し替えてユースケースをテスト
- 画面テストは Presenter の出力（ViewModel）を検証する（View はテスト不要）
- テスト自体もアーキテクチャの一コンポーネントとして扱う

### ユーザー確認の原則（AskUserQuestion）

**判断分岐がある場合、推測で進めず必ずAskUserQuestionツールでユーザーに確認する。**

確認すべき場面:
- 何層の同心円にするか（最小4層 or プロジェクト規模に合わせた拡張）
- Partial Boundary の採用（完全境界 vs 3段階の簡略化戦略）
- モノリス vs マイクロサービス（CA はどちらにも適用可能）
- 既存システムへの CA 段階的導入方針

確認不要な場面:
- 依存性ルール（外→内 の一方向）の適用（絶対ルール）
- SQL をユースケース層に書かない（絶対ルール）
- DB行構造を内側に渡さない（絶対ルール）

---

## 適用判断フロー

```
Q1: システムは長期保守が必要か？
  No → 軽量アーキテクチャで十分（CA 不要の場合あり）
  Yes ↓

Q2: フレームワーク・DB・UI が将来変わる可能性があるか？
  No → 依存性ルールのみ適用（簡易 CA）
  Yes ↓

Q3: ビジネスルールが複雑か？
  No → Use Cases + Entities の2層でも可
  Yes → 4層 CA を完全適用

Q4: チームが大きく並行開発が必要か？
  Yes → コンポーネント原則（ADP/SDP/SAP）を厳密適用
  No → CCP を優先（変更の局所化）
```

---

## 相互参照マップ

| 関心事 | 参照先スキル |
|--------|------------|
| コードレベルの SOLID・リファクタリング | `writing-clean-code` |
| ドメイン設計・境界コンテキスト（Bounded Context） | `applying-domain-driven-design` |
| マイクロサービス・CQRS・Saga パターン | `architecting-microservices` |
| レガシーシステムのモダナイゼーション | `modernizing-architecture` |
| アーキテクチャトレードオフ分析 | `analyzing-software-tradeoffs` |
| React 固有の CA 実装 | `developing-react` (CLEAN-ARCHITECTURE.md) |
| Python 固有の CA 実装 | `developing-python` (CA-PYTHON.md) |

---

## 詳細参照ファイル

| ファイル | 内容 |
|---------|------|
| [FOUNDATIONS.md](references/FOUNDATIONS.md) | プログラミングパラダイムと CA の哲学的基盤 |
| [LAYER-DESIGN.md](references/LAYER-DESIGN.md) | 各レイヤーの詳細設計・エンタープライズ構造 |
| [COMPONENT-PRINCIPLES.md](references/COMPONENT-PRINCIPLES.md) | 凝集・結合原則の詳細と安定度メトリクス |
| [ANTI-PATTERNS.md](references/ANTI-PATTERNS.md) | よくあるアーキテクチャアンチパターン5種 |
| [ARCHITECTURE-STYLES.md](references/ARCHITECTURE-STYLES.md) | 他アーキテクチャスタイルとの比較 |
| [MDE-INTEGRATION.md](references/MDE-INTEGRATION.md) | Model-Driven Engineering との統合 |
| [CASE-STUDIES.md](references/CASE-STUDIES.md) | ケーススタディ・実例 |
| [AGILE-INTEGRATION.md](references/AGILE-INTEGRATION.md) | アジャイル開発との統合 |
