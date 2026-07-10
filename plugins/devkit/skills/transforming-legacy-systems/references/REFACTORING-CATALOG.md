# 変革リファクタリングカタログ（Refactoring Catalog）

> レガシー変革は大きな一撃では進まない。小さく安全な手順に分解し、常にデプロイ可能な状態を保ちながら積み重ねる。本ファイルは変革で繰り返し使う手順を、統一形式（名称・目的・適用条件・手順概要・関連）でまとめたカタログである。

## カタログの読み方

カタログは4つのカテゴリに分かれる。上から順に、大きな戦略的な一手→それを支える戦術的な手順→チーム再編→ドメイン知識を強化する仕上げ、という関係にある。

| カテゴリ | 役割 |
|---------|------|
| A. 戦略的リファクタリング | モノリスから境界づけられたコンテキストを生み出す大きな一手 |
| B. 戦略を支える戦術的リファクタリング | 戦略的リファクタリングを構成する、より小さな実装手順 |
| C. 社会技術的リファクタリング | 戦略的リファクタリングと並行して行うチーム再編 |
| D. ドメイン知識を強化する戦術的リファクタリング | 切り出した（または切り出す前の）コードの内部を磨き上げる |

各エントリは次の項目を持つ。**別名・関連が存在しない場合は省略する。**

- **目的**: このリファクタリングが解決する課題
- **適用条件**: いつ使うか、代替との使い分け
- **手順概要**: 一般化した手順（実装は状況に応じて調整する）
- **関連**: 前後や代替のリファクタリング

汎用的に確立したリファクタリング名（Extract Class、Move Method、Rename Method 等）は業界共有の用語として使用し、個々のコード例は独自に書き起こしたものである。

---

## A. 戦略的リファクタリング

モノリスから境界づけられたコンテキストを生み出す方法は大きく2つ。既存コードから切り出すか、ゼロから作るかである。

### Extract Bounded Context

*別名*: モノリスからのコンテキスト切り出し

- **目的**: モノリスに埋もれたドメイン知識を、独立した境界づけられたコンテキストとして掘り出す。往々にして、その知識を知るドメインエキスパートすら失われかけている。
- **適用条件**: ドメイン分析の結果、切り出すべき境界づけられたコンテキストの候補が定まったとき。Implement Bounded Context from Scratch の代替。
- **手順概要**:
  1. ドメインを分析し、存在すべき境界づけられたコンテキストを洗い出す
  2. 最初に切り出す候補を1つ選ぶ
  3. 状況に応じて Extract Specialized Entity / Extract Specialized Anemic Entity / Extract Specialized Service / Extract Specialized Table を適用する
- **関連**: B章の戦術的リファクタリング一式、Implement Bounded Context from Scratch（代替）

### Implement Bounded Context from Scratch

- **目的**: 理想形として描いたコンテキストマップに基づき、境界づけられたコンテキストを新規実装する。
- **適用条件**: 別の言語・プラットフォームへの移行を伴うなど、既存コードからの切り出しでは対応できない場合に選ぶ。ただしモノリスに眠るドメイン知識を失うリスクと、いわゆる**セカンドシステム症候群**（作り直しに際して過剰設計に陥りやすい傾向）に注意する。Extract Bounded Context の代替。
- **手順概要**:
  1. 理想形のコンテキストマップから、実装すべきコンテキストと他コンテキスト（モノリス含む）との関係を把握する
  2. 対象コンテキストを選び、社会技術的リファクタリング（C章）で担当チームを編成する
  3. 最初のプロトタイプを実装する
  4. 既存の他コンテキストと整合する形で外部インターフェースを設計する
  5. モノリス側に、あたかも未分離のコンテキストであるかのように振る舞う接続層を追加する
- **関連**: C章の社会技術的リファクタリング、Extract Bounded Context（代替）

---

## B. 戦略を支える戦術的リファクタリング

戦略的リファクタリングは依然として大きいため、より小さな手順に分解する。分解の仕方は、切り出す対象がどんな状態かによって変わる。

- 貧血なドメインモデル → Extract Specialized Anemic Entity と Extract Specialized Service
- 振る舞いの豊かなドメインモデル → Extract Specialized Entity と Extract Specialized Service
- モノリシックなデータモデル → Extract Specialized Table

### Extract Specialized Service

*別名*: モノリシックサービスからの専用サービス切り出し ／ 汎用リファクタリング「Extract Class」の一種

- **目的**: Extract Bounded Context の一部として、肥大化したドメインサービスを分割する。
- **適用条件**: 切り出し対象のコンテキストに属すべき機能が、既存の大きなサービスクラスに混在している場合。
- **手順概要**:
  1. 切り出し先のコンテキストに空のクラスを新設する
  2. 元のクラスに新クラス型のフィールドを追加する
  3. 移動対象のメソッドを1つずつ新クラスへコピーし、元のメソッド本体は新クラスへの委譲に置き換える
  4. 呼び出し元を段階的に新クラスの呼び出しへ置き換える
  5. 元のクラスから実装を削除する。他の移動対象メソッドについて繰り返す
  6. すべて移動し終えたら、委譲用フィールドも元のクラスから削除する
- **コード例**:
  ```typescript
  // Before: 単一クラスに複数コンテキストの責務が同居している
  class ContractService {
    vote(contract: Contract): void { /* 契約コンテキストの責務 */ }
    calculateInstallment(offer: Offer): Money { /* 見積りコンテキストの責務 */ }
  }

  // After: 委譲を介して段階的に責務を分離する
  class ContractService {
    constructor(private offeringService: OfferingService) {}
    vote(contract: Contract): void { /* ... */ }
    calculateInstallment(offer: Offer): Money {
      return this.offeringService.calculateInstallment(offer); // 委譲
    }
  }
  class OfferingService {
    calculateInstallment(offer: Offer): Money { /* 移動後の実装 */ }
  }
  ```
- **関連**: Extract Specialized Entity、Extract Specialized Anemic Entity と併用されることが多い

### Extract Specialized Entity

*別名*: モノリシックエンティティからの専用エンティティ切り出し ／ Extract Class の一種

- **目的**: 振る舞いの豊かなドメインモデルにおいて、肥大化したエンティティを分割する。
- **適用条件**: ドメインモデルが貧血モデルでなく、十分に振る舞いを持つ場合。貧血モデルの場合は Extract Specialized Anemic Entity を使う。多くの場合 Extract Specialized Table を伴う。
- **手順概要**:
  1. 切り出し先に空のクラスを新設する
  2. 移動対象のフィールドを新クラスへコピーする
  3. 移動対象メソッドを1つずつ新クラスへコピーし、元のメソッドは委譲に置き換える
  4. 呼び出し元を段階的に新クラス呼び出しへ置き換え、元の実装と不要フィールドを削除する
  5. 他のメソッド・フィールドについて繰り返し、最終的に委譲用フィールドも取り除く
- **関連**: Extract Specialized Table、Extract Specialized Anemic Entity（代替）

### Extract Specialized Anemic Entity

*別名*: モノリシックエンティティからの専用貧血エンティティ切り出し ／ Extract Class の一種

- **目的**: 貧血なドメインモデル（データの入れ物と化したエンティティ）において、肥大化したエンティティを分割する。
- **適用条件**: ドメインモデルが貧血モデルの場合。振る舞いが豊かな場合は Extract Specialized Entity を使う。Extract Specialized Service の後続としてよく現れ、Extract Specialized Table を伴う。切り出し後は Heal Entity Anemia で貧血を解消するとよい。
- **手順概要**: Extract Specialized Entity と同様（フィールド・メソッドの移動 → 委譲への置き換え → 呼び出し元の切り替え → 旧実装の削除、を1メソッドずつ繰り返す）
- **関連**: Extract Specialized Entity（代替）、Heal Entity Anemia

### Extract Specialized Table

*種別*: データベースリファクタリング ／ 汎用パターン「Split Table」の一種

- **目的**: モノリシックなデータモデルから、切り出し対象のコンテキストに属するテーブル部分を分離する。
- **適用条件**: エンティティやサービスの切り出しと並行して、永続化層のテーブルも分割する必要がある場合。
- **手順概要**（スキーマ更新 → データ移行 → アクセスプログラム更新の3段階で進める）:
  1. **スキーマ更新**: 切り出し先スキーマに空テーブルを作り、複製すべき列・移動すべき列をコピーする。新旧テーブル間に同期トリガーを張り（トリガーが互いを再度発火させないよう注意する）、廃止予定日を設定する
  2. **データ移行**: 複製列のデータをコピーする（モノリス側の全行が切り出し先に必要とは限らない）。移動列のデータもあわせてコピーする
  3. **アクセスプログラム更新**: 移行期間中はアクセスコードを丁寧に分析し追随させる。必要なら切り出し先専用のリポジトリを抽出する
- **関連**: Extract Specialized Entity / Extract Specialized Anemic Entity

---

## C. 社会技術的リファクタリング

「リファクタリング」という言葉をここでは広い意味で使う。システムを直接変更するのではなく、チーム構造という間接的な手段を通じて変化を起こすためである。詳しい背景は `TEAM-ORGANIZATION.md` を参照。最初の1チームを立ち上げたあと、2チーム目以降の作り方には選択肢がある。

### Form Cross-Functional Team out of Layer-Team Members

*別名*: レイヤーチームからの機能横断チーム編成

- **目的**: レイヤー別チーム編成の組織に、最初の機能横断チームを立ち上げる。
- **適用条件**: Extract Bounded Context や Implement Bounded Context from Scratch を適用する際、「新設した境界づけられたコンテキストを誰が担当するか」という問いに答える必要がある場面。どのレイヤーチームも単独では適任でなく、複数チームに責任を分散させるのも避けたいときに使う。
- **手順概要**:
  1. 各レイヤーチームから最低1名ずつ選出する。懐疑的な人ではなく、新しい取り組みに前向きな人を選ぶ
  2. 9人未満の新チームを編成する
  3. 新チームに新設コンテキストの責任を持たせる
  4. チーム内でT字型スキル（自分の専門性に加え周辺領域も理解する姿勢）の育成を促す
  5. 残りのレイヤーチームは当面そのまま維持する。モノリスの保守は引き続き必要なため
- **関連**: Implement Bounded Context from Scratch、Extract Bounded Context

### Form Second Cross-Functional Team out of Partly Layer-Team and First-Team Members

*別名*: 混成メンバーによる2チーム目の機能横断チーム編成

- **目的**: 2チーム目の機能横断チームを、最初のチームの経験者とレイヤーチーム残留者の混成で編成する。
- **適用条件**: 最初のチーム編成で得た知見を2チーム目に引き継ぎたい場合。ただし最初のチームは、送り出した人数分だけ再びチームビルディングをやり直すコストを払う。Form Second Team out of Only Layer-Team Members の代替。
- **手順概要**:
  1. 最初のチームから最低1名、知見を伝えたい人を選ぶ
  2. 残りをレイヤーチームのメンバーで埋め、必要な専門性（UIなど）が欠けていないか確認する
  3. 9人未満のチームを編成し、新設コンテキストの責任を持たせる
  4. 残りのレイヤーチームはこの時点でかなり縮小しているはず
- **関連**: Form Second Team out of Only Layer-Team Members（代替）

### Form Second Team out of Only Layer-Team Members

*別名*: レイヤーチーム残留者のみによる2チーム目編成

- **目的**: 2チーム目をレイヤーチームの残留者だけで編成し、最初のチームには手を付けない。
- **適用条件**: 最初のチームの活動を乱したくない場合、あるいは複数の新チームを同時並行で立ち上げたい場合。欠点は、新チームがチーム再編の学びをゼロから積み直す必要があること。Form Second Cross-Functional Team out of Partly Layer-Team and First-Team Members の代替。
- **手順概要**: Form Cross-Functional Team out of Layer-Team Members と同じ手順を踏む
- **関連**: Form Second Cross-Functional Team out of Partly Layer-Team and First-Team Members（代替）

---

## D. ドメイン知識を強化する戦術的リファクタリング

目的が伝わらないコードは保守もしにくい。ここに集めた手順は、濁ったコードをドメイン概念がくっきり見える形へ変えるためのものである。多くは戦略的リファクタリングの前後に、単独でも実施できる。

### Enforce Ubiquitous Language

*別名*: ユビキタス言語の徹底

- **目的**: コード中の名前を、現在のドメイン理解を反映したユビキタス言語に揃える。
- **適用条件**: 不適切な名前・不可解な技術用語・意味不明な略語・実態と乖離した名前がコードに残っている場合。
- **手順概要**:
  1. クラス名・メソッド名・フィールド名・変数名を、汎用的な改名リファクタリング（Rename Class / Rename Method / Rename Field / Rename Variable）でドメイン用語に合わせる
  2. データモデル側もテーブル名・カラム名・ビュー名を同様に改名する
  3. ユーザーインターフェースの表記も合わせて更新する
- **関連**: ドメインへの理解が深まるたびに繰り返し適用する

### Replace Primitive with Value Object

*別名*: プリミティブ型から値オブジェクトへの置き換え ／ 汎用パターン「Replace Primitive with Object」の一種

- **目的**: 値のようなドメイン概念をプリミティブ型（`int`、`String` 等）で表現している状態を解消し、専用の値オブジェクト型を導入する。
- **適用条件**: コード中に裸のプリミティブ型が多用され、意図が読み取りにくく誤用のリスクが高い場合（いわゆるプリミティブ型への執着）。
- **手順概要**:
  1. 単純な値オブジェクトクラスを作る（同一性を持たず、不変であることを徹底する）
  2. プリミティブ型が使われている箇所を、段階的に新しい値オブジェクト型へ置き換える
  3. 妥当性検証や演算といったドメインロジックを値オブジェクトへ移す
- **コード例**:
  ```typescript
  // Before: プリミティブ型への執着（単位も検証も不明瞭）
  class Contract {
    price: number;
  }

  // After: 値オブジェクトで意図と検証を凝集する
  class Amount {
    private constructor(private readonly cents: number, private readonly currency: string) {}
    static of(cents: number, currency: string): Amount {
      if (cents < 0) throw new Error("金額は負値にできない");
      return new Amount(cents, currency);
    }
    add(other: Amount): Amount {
      return Amount.of(this.cents + other.cents, this.currency); // 通貨一致は別途検証
    }
  }
  class Contract {
    price: Amount;
  }
  ```
- **関連**: Heal Entity Anemia

### Heal Entity Anemia

*上位リファクタリング（傘）*: Replace Setter・Remove Setter・Move Logic from Service to Entity をまとめる

- **目的**: データと振る舞いを分離してしまう貧血ドメインモデルを解消し、エンティティに振る舞いを取り戻す。
- **適用条件**: エンティティが「データの入れ物」と化し、整合性の維持をサービス層に依存している場合。Extract Specialized Anemic Entity の後、あるいは Extract Specialized Entity の前段としてよく現れる。
- **手順概要**:
  1. Replace Setter または Remove Setter でエンティティのデータをカプセル化する
  2. Move Logic from Service to Entity でサービス層の振る舞いをエンティティへ移す
- **関連**: Replace Setter、Remove Setter、Move Logic from Service to Entity

### Replace Setter

- **目的**: setter経由でフィールドを外部から直接変更させる設計をやめ、ドメインの語彙で意図を表すメソッドに置き換える。
- **適用条件**: setterが実際に使われている（呼び出し元がある）場合。使われていないなら直接 Remove Setter でよい。
- **手順概要**:
  1. 置き換えたいsetterを特定する
  2. ドメインエキスパートと業務プロセスを確認し、適切なメソッド名を決める
  3. 新しいメソッドを対象クラスに追加する
  4. setterの呼び出し箇所を洗い出し、段階的に新メソッドの呼び出しへ置き換える
  5. すべて置き換え終えたらsetterを削除する
  6. 新メソッドに事前条件・事後条件があれば Introduce Contract で明示する
- **リスク・注意**: 汎用的な改名リファクタリングと似ているが、新しいメソッドは単なる値の代入に留まらず、追加の業務ロジックを伴うことが多い点が異なる。
- **関連**: Remove Setter、Introduce Contract

### Remove Setter

*別名*: 汎用リファクタリング「Remove Setting Method」の一種

- **目的**: 使われていないsetterを削除し、不要な公開面を減らす。
- **適用条件**: IDEの自動生成などで機械的に作られ、実際には呼ばれていないsetterがある場合。
- **手順概要**:
  1. setterへの全呼び出しを洗い出す
  2. 呼び出しが1件もなければ削除する
- **リスク・注意**: リフレクションでgetter/setterを利用するフレームワークがあるため、静的解析だけでは呼び出しを見落とすことがある。削除前に実行時の利用状況も確認する。
- **関連**: Replace Setter

### Move Logic from Service to Entity

*別名*: 汎用リファクタリング「Move Method」の一種

- **目的**: 1つのエンティティのデータのみを扱うドメインロジックを、サービスからエンティティへ移し、凝集度を高める。
- **適用条件**: ドメインサービスのロジックが単一のエンティティのみを操作し、そのためにエンティティのデータを外部へ晒している場合。Heal Entity Anemia の一部として使う。
- **手順概要**:
  1. 対象メソッドをサービスからエンティティへコピーする
  2. サービス側の実装をエンティティへの委譲に置き換える
  3. 呼び出し元を確認し、直接エンティティを呼んで問題なければそちらへ切り替える
  4. サービス側に呼び出しが残らなくなったら削除する
  5. 併せて Replace Setter / Remove Setter でデータのカプセル化を進められないか検討する
- **関連**: Heal Entity Anemia

### Introduce Contract

- **目的**: メソッドが成立する条件（事前条件・事後条件・不変条件）をコードとして明示し、可読性と堅牢性を高める（契約による設計の考え方に基づく）。
- **適用条件**: メソッドの前提や保証が暗黙のままになっている場合。多くの言語では表明（assertion）程度の支援しかないため、コメントでの明文化も有効な代替手段になる。
- **手順概要**:
  1. 事前条件を表明として書き起こす
  2. 事後条件を表明として書き起こす
  3. クラスが満たすべき不変条件があれば、同様に表明として明示する
  4. 意味のあるまとまりには、チェック内容に名前を与える述語メソッドを抽出する
  5. 述語メソッドは、対象メソッドと同じ可視性で公開する
- **コード例**:
  ```typescript
  class BankAccount {
    private balanceCents: number;
    isCovered(amount: Amount): boolean {
      return this.balanceCents >= amount.cents; // 述語メソッドとして公開
    }
    withdraw(amount: Amount): void {
      if (!this.isCovered(amount)) throw new Error("残高不足"); // 事前条件
      this.balanceCents -= amount.cents;
    }
  }
  ```
- **関連**: Replace Setter

### Split Active Record into Aggregate and Repository

- **目的**: ドメイン概念の表現と永続化という2つの責務を兼ねるActive Recordを分離する。
- **適用条件**: 1つのクラスがドメインロジックとデータアクセスロジックの両方を担っている場合。
- **手順概要**:
  1. メソッドをドメインロジックとデータアクセスロジックに仕分ける。混在しているものは先にメソッド抽出で分ける
  2. リポジトリクラスを新設し、データアクセスロジックをすべて移す
  3. 元クラスのデータアクセスメソッドを非推奨としてマークする
  4. 呼び出し元をリポジトリ経由の呼び出しへ置き換える
  5. 元クラスからデータアクセスメソッドを削除する。これで集約（アグリゲート）やエンティティとして振る舞うクラスになる
- **関連**: 後続として Split Repository into Interface and Implementation がよく続く

### Split Repository into Interface and Implementation

- **目的**: リポジトリの定義（ドメイン層）と実装（インフラ層）を分離し、ドメイン層がデータベースの詳細を知らなくてよいようにする。
- **適用条件**: リポジトリがドメイン層に実装ごと存在している場合。
- **手順概要**:
  1. 汎用的なインターフェース抽出リファクタリング（Extract Interface）をリポジトリへ適用する
  2. 実装をインフラ層へ移し、インターフェースはドメイン層に残す
  3. 既存リポジトリの利用箇所を新インターフェースへ置き換える。実装を知るべきなのは依存性注入の設定のみにする
- **関連**: Split Active Record into Aggregate and Repository

### Extract Entity from Smart UI

- **目的**: UIコードと業務ロジックが混在するSmart UI（アンチパターン）から、エンティティを抽出する。
- **適用条件**: 抽出した業務ロジックが、クラスが保持するフィールドを利用している場合。パラメータのみで完結するロジックなら Extract Service from Smart UI の方が適する。
- **手順概要**:
  1. Smart UIクラス内で業務ロジックをメソッド抽出によりUIロジックから分離する
  2. 抽出したメソッドがフィールドを利用しているか確認する
  3. クラス抽出を適用し、業務ロジックとデータを新設のエンティティへ移す
- **関連**: Extract Service from Smart UI（使い分け）

### Extract Service from Smart UI

- **目的**: Smart UIから業務ロジックを、状態を持たないサービスとして抽出する。
- **適用条件**: 抽出した業務ロジックがパラメータのみで完結し、クラスのフィールドに依存しない場合。フィールドに依存する場合は Extract Entity from Smart UI の方が適する。
- **手順概要**:
  1. Smart UIクラス内で業務ロジックをメソッド抽出によりUIロジックから分離する
  2. 抽出したメソッドがパラメータのみで完結するか確認する
  3. クラス抽出を適用し、業務ロジックメソッドを新設のサービスへ移す
- **関連**: Extract Entity from Smart UI（使い分け）

---

## 関連参照

- 戦略的リファクタリングの選定・優先順位づけ → `STRATEGIC-STEPS-ALIGNMENT-EXECUTION.md`
- チーム編成の背景・Team Topologiesとの関係 → `TEAM-ORGANIZATION.md`
- 貧血モデル解消の詳細な文脈・凝集/結合の議論 → `DOMAIN-KNOWLEDGE-IN-CODE.md`
- 一般的なリファクタリング手法（Extract Method・Extract Class・Rename 等）そのものの定義 → `devkit:writing-clean-code`
