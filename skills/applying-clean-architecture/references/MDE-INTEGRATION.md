# Model-Driven Engineering（MDE）統合

## MDE とは

Model-Driven Engineering（MDE）は、ソフトウェア開発においてモデルを中心的な成果物として扱う手法。コードよりも高い抽象レベルでシステムを記述し、そこからコードや設計を導出する。

---

## MDE の基本概念

### コンポーネントとコネクター

ソフトウェアアーキテクチャを記述する2つの要素：

| 要素 | 定義 | CA での対応 |
|------|------|-----------|
| **コンポーネント** | 独立したシステム構成単位（処理・データを保持） | Entity, UseCase, Controller 等 |
| **コネクター** | コンポーネント間の相互作用のメカニズム | インターフェース、イベント、呼び出し |

```
[ComponentA] ──connector──> [ComponentB]

UML コンポーネント図での表現：
[ComponentA] ─●──○─ [ComponentB]
              提供   要求
              インターフェース
```

### アーキテクチャの属性（Quality Properties）

| 属性 | 定義 | CA での保証方法 |
|------|------|--------------|
| **再利用性** | コンポーネントが複数システムで使えること | Entity 層の普遍性 |
| **置換可能性** | 同じインターフェースの別実装に交換できること | DIP による抽象依存 |
| **持続可能性** | 進化する要件に追随できること | 依存性ルールによる変更局所化 |
| **保守性** | 修正・拡張のコストが低いこと | レイヤー分離 |
| **拡張性** | 機能追加が容易なこと | CCP・OCP の適用 |

---

## CA 原則の仕様段階での分析

### SOLID 原則のアーキテクチャレベル適用

**SRP（単一責任）at アーキテクチャレベル：**
```
コンポーネントは1つの変更理由のみを持つ。
= 1つのアクター（ビジネスロール）のためにのみ変更される。
```

**OCP（開放閉鎖）at アーキテクチャレベル：**
```
コンポーネントは拡張に開き、修正に閉じている。
= 新機能は新コンポーネントの追加で対応し、既存コンポーネントは修正しない。
```

**DIP（依存逆転）at アーキテクチャレベル：**
```
高レベルポリシーは低レベル詳細に依存しない。
= エンティティ・ユースケースはフレームワーク・DBに依存しない。
```

---

## 要件モデルからアーキテクチャを導出

### ステップ1：ユースケース分析

要件からアクターとユースケースを抽出する：

```
アクター識別の問い：
Q: 誰がシステムを使うか？ → 各役割がアクター
Q: 誰がシステムに影響を与えるか？ → 外部システムもアクター

ユースケース識別の問い：
Q: 各アクターはシステムに何を期待するか？
Q: どの変化理由がアクターによって異なるか？
```

### ステップ2：責任分割（SRP based）

```
アクターごとに変更理由が異なる
→ アクターごとにコンポーネントを分ける

例：
- Viewer（閲覧ユーザー）向けコンポーネント
- Purchaser（購入者）向けコンポーネント
- Admin（管理者）向けコンポーネント
- Author（コンテンツ作成者）向けコンポーネント
```

### ステップ3：依存性ルールの検証

```
各コンポーネントの依存方向を確認：
Entity ← UseCase ← Interface Adapter ← Framework

違反チェック：
- UseCase が Controller を知っていないか？
- Entity が DB ライブラリを import していないか？
```

---

## モデルからアーキテクチャを生成（MDE アプローチ）

### 要件モデル（Requirements Model）の例

```
# ユースケースモデル（疑似 UML）
Actor: Viewer
UseCase: ViewCatalog
  includes: SearchProducts
  precondition: システムにアクセス可能

Actor: Purchaser
UseCase: PurchaseProduct
  includes: ViewCatalog, AddToCart, Checkout
  postcondition: 注文が作成される
```

### アーキテクチャへのマッピング

```
要件モデル → CA コンポーネント

Actor(Viewer) →
  ViewerViewsComponent（Interface Adapter）
  ViewCatalogUseCase（Use Cases）

Actor(Purchaser) →
  PurchaserPurchasesComponent（Interface Adapter）
  PurchaseProductUseCase（Use Cases）

共通 Entity → CatalogEntity, ProductEntity（Entities）
```

---

## 3層アーキテクチャと CA の対応

従来の 3 層アーキテクチャと CA の概念マッピング：

| 3層アーキテクチャ | Clean Architecture |
|-----------------|-------------------|
| Presentation Layer | Interface Adapters（View/Controller）|
| Business Logic Layer | Use Cases + Entities |
| Data Access Layer | Interface Adapters（Repository）+ Frameworks（DB Driver）|

**重要な違い：**
3層では「Data Access Layer が最下層（基盤）」と見なすが、CA では「DB は詳細（最外層）」と見なす。この認識の転換が CA の本質の一つ。

---

## アジャイルプロセスとの MDE 統合

### スプリント内での CA 設計

```
Sprint Planning:
  1. ユースケースを UseCases 層のインターフェースとして定義
  2. 必要な Entity を特定
  3. 外部依存（DB, API）のインターフェースを定義

Sprint Implementation:
  1. Entity + UseCase の TDD 実装
  2. Interface Adapters 実装
  3. Framework 統合テスト

Sprint Review:
  1. ビジネスルールのデモ（フレームワークなし）
  2. 依存違反の確認（CI チェック）
```

### アーキテクチャリファクタリング（インクリメンタル）

```
Phase 1: Entity 抽出（ビジネスルールをサービスから移動）
Phase 2: UseCase 境界定義（Controller からビジネスロジックを分離）
Phase 3: Gateway インターフェース導入（DB 直接依存を排除）
Phase 4: Framework 分離（フレームワーク固有コードを外層に移動）
```

各フェーズでテストを先に書き、リファクタリング後もテストが通ることを確認する（TDD/リファクタリング）。
