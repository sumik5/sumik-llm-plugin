---
description: >-
  Guides relational database design from requirements to implementation covering
  entity modeling, ER diagrams, normalization (1NF-BCNF), optimization, and
  PostgreSQL-specific implementation (microservices data architecture, ACID transactions,
  functions/stored procedures, AAA security).
  Use when designing database schemas, creating ER diagrams, normalizing tables,
  implementing SQL DDL, or developing PostgreSQL-backed applications.
  For database internals (storage engines, distributed systems), use understanding-database-internals instead.
  For SQL antipattern detection and avoidance, use avoiding-sql-antipatterns instead.
---

# リレーショナルデータベース設計ガイド

要件分析から実装まで、構造化されたデータベース設計プロセスを体系的に進めるための実践的ガイド。

---

## 設計目標

成功するデータベース設計は以下5つの目標を達成する：

1. **データ整合性（Data Consistency and Integrity）** - 適切な制約・データ型・リレーションシップでデータの一貫性を保ち、冗長性を排除し、異常を防止する
2. **保守性と使いやすさ（Maintainability and Ease of Use）** - 命名規則の一貫性により、管理者・アナリスト・開発者が直感的に使用・保守できる構造を提供する
3. **性能と最適化（Performance and Optimization）** - インデックス・キャッシング等でクエリ性能を最適化し、アプリケーション全体のUXを向上させる
4. **セキュリティ（Data Security）** - 不正アクセス・改ざん・削除を防止し、機密データを保護・復旧可能にする（暗号化、アクセス制御）
5. **拡張性と柔軟性（Scalability and Flexibility）** - 将来の成長・要件変更に対応可能な構造（テーブル分離、キャッシング等）

---

## 設計プロセス

データベース設計は以下5つのフェーズで構成される：

```
Phase 1: 要件分析
    ↓
Phase 2: データモデリング
    ↓
Phase 3: 正規化
    ↓
Phase 4: 実装
    ↓
Phase 5: セキュリティ・最適化レビュー
```

### Phase 1: 要件分析（Requirements Gathering）

**目的：** ステークホルダーへのインタビューで「主語（Subject）」「特性（Characteristics）」「関係（Relationships）」を収集し、エンティティ候補・属性候補を抽出する。

**手順：**
1. **インタビューグループの選定** - Stakeholders（オーナー・マネージャー）、SME（業務専門家）、IT/技術スタッフの3グループを区別
2. **主語→エンティティ候補の抽出** - 要件文から「人・場所・モノ・イベント」を識別（例: "ユーザーが商品を購入" → user, product, purchase）
3. **特性→属性候補の抽出** - 各主語の特徴を列挙（例: userの名前・メール・電話番号）
4. **データサンプル取得** - 既存のスプレッドシート・紙フォーム・レガシーDBからサンプルデータを入手し、属性の型と制約を把握

**成果物：** エンティティ候補一覧、属性候補一覧、サンプルデータ

**参照：** [ENTITIES-AND-KEYS.md](references/ENTITIES-AND-KEYS.md)（エンティティ識別プロセスの詳細）

---

### Phase 2: データモデリング（Data Modeling）

**目的：** エンティティ・属性・キーを確定し、ER図（Entity-Relationship Diagram）を作成して、リレーションシップとカーディナリティを定義する。

**手順：**
1. **エンティティ・属性の定義** - Phase 1で抽出した候補からエンティティ名と属性名を確定（命名規則適用）
2. **主キー（Primary Key）の選定** - Candidate Key（username, email等）を比較評価してPKを決定。適切なNatural Keyがなければ Surrogate Key（ID列）を新規作成
3. **データ型の割り当て** - VARCHAR, INT, DECIMAL, TIMESTAMPをサンプルデータから判断して割り当て
4. **ER図の作成** - Crow's Foot notationでエンティティ間のリレーションシップ（1:1, 1:N, M:N）を線で結ぶ
5. **カーディナリティとオプショナリティの設定** - 最大カーディナリティ（N対1等）と最小カーディナリティ（0 or 1）を確定

**成果物：** ER図（エンティティ・属性・主キー・外部キー・リレーションシップが記載されたもの）

**参照：**
- [ENTITIES-AND-KEYS.md](references/ENTITIES-AND-KEYS.md)（命名規則・キー選択・データ型）
- [RELATIONSHIPS.md](references/RELATIONSHIPS.md)（ER図記法・カーディナリティ）

---

### Phase 3: 正規化（Normalization）

**目的：** テーブル構造を1NF → 2NF → 3NF → BCNFの順に正規化し、冗長性を排除して異常（挿入・更新・削除異常）を防止する。

**手順：**
1. **1NF（First Normal Form）チェック** - 主キー存在、多値カラム（カンマ区切りリスト等）がないことを確認。違反があればテーブル分割
2. **2NF（Second Normal Form）チェック** - 部分関数従属（複合キーの一部に従属する非キー属性）を排除。違反があれば従属先を別テーブルに移動
3. **3NF（Third Normal Form）チェック** - 推移的従属（A→B, B→C のとき A→C が非キー属性間で発生）を排除。Bを独立テーブルにする
4. **BCNF（Boyce-Codd Normal Form）チェック** - 全ての決定項（Determinant）が候補キーであることを確認。違反があれば分割
5. **関数従属の文書化** - 各正規化ステップで関数従属図（A → B, C）を記録し、3テーブル間のサイクル（推移的従属）がないか検証

**成果物：** 正規化済みテーブル定義、関数従属図、正規化の根拠ドキュメント

**参照：** [NORMALIZATION.md](references/NORMALIZATION.md)（各正規形のルールと違反検出手法）

---

### Phase 4: 実装（Implementation）

**目的：** ER図と正規化済み設計をSQL DDL（Data Definition Language）に変換し、テーブル・制約・インデックスを実際のRDBMSに構築する。

**手順：**
1. **CREATE TABLE文の生成** - エンティティごとにテーブル定義を記述（列名・データ型・NOT NULL制約）
2. **PRIMARY KEY制約の追加** - 主キー列に `PRIMARY KEY` を設定
3. **FOREIGN KEY制約の追加** - リレーションシップに基づいてFKを定義し、CASCADE動作（ON DELETE CASCADE等）を設定
4. **UNIQUE制約の追加** - Candidate Keyだったが主キーにならなかった属性（例: email, username）に `UNIQUE` を設定
5. **CHECK制約の追加** - 値範囲・フォーマット制約（例: `price > 0`, `email LIKE '%@%'`）を定義
6. **インデックスの作成** - 検索頻度の高い列（外部キー、検索条件で使われる列）にインデックスを作成

**成果物：** DDLスクリプト、初期データINSERT文

**参照：**
- [NORMALIZATION.md](references/NORMALIZATION.md)（DDL生成の実践例）
- [SECURITY-OPTIMIZATION.md](references/SECURITY-OPTIMIZATION.md)（インデックス戦略）

---

### Phase 5: セキュリティ・最適化レビュー（Security and Optimization Review）

**目的：** 整合性・セキュリティ・性能を総合的にレビューし、必要に応じてインデックス追加・非正規化を実施する。

**手順：**
1. **整合性チェック** - FK制約の網羅性、NOT NULL制約の適切性、データ型の精度確認
2. **セキュリティ設計** - 機密カラム（password, card_number等）の暗号化、アクセス制御（RBAC/MAC）の設計
3. **冗長テーブルの統合** - 同じエンティティを表す複数テーブルがあれば統合し、ストレージ効率を改善
4. **カテゴリカルデータの分離** - ENUMやlookupテーブル化を検討
5. **インデックス追加判断** - SELECT頻度・WHERE句の条件列・JOIN列を分析し、標準インデックス・複合インデックス・フルテキストインデックスを追加
6. **非正規化の検討** - 頻繁なJOINで性能問題がある場合のみ、集計カラム追加等の非正規化を実施（トレードオフを文書化）

**成果物：** セキュリティ仕様書、インデックス設計書、非正規化の根拠ドキュメント、性能テスト結果

**参照：** [SECURITY-OPTIMIZATION.md](references/SECURITY-OPTIMIZATION.md)（セキュリティ・インデックス・非正規化の詳細）

---

## クイックリファレンス

設計中の判断を迅速に行うための基準テーブル。

### キー選択判断テーブル

| 判断基準 | Natural Key推奨 | Surrogate Key推奨 |
|---------|----------------|------------------|
| 候補キーの安定性 | 変更されない（例: product_code） | 変更される可能性（例: email, username） |
| 複合キーの必要性 | 単一列でユニーク | 複合キーになる（2列以上） |
| 冗長性排除の重要性 | 必須（user, product等） | 許容可能（review, purchase等） |
| 検索性能 | Natural Keyが短い（≤12文字） | Natural Keyが長い（>12文字） |
| 外部キーとしての使用頻度 | 低頻度 | 高頻度（多数のテーブルから参照） |

**推奨：** 迷ったらSurrogate Key（自動採番INT）を使う。Natural Keyはビジネス要件で明確に必要な場合のみ。

---

### 正規化レベル判断テーブル

| 正規化レベル | 確認内容 | 違反例 | 対処 |
|-------------|---------|--------|------|
| **1NF** | 主キー存在、原子性（多値排除） | カラムにカンマ区切りリスト `tags: "sci-fi,fantasy"` | tags列を別テーブルに分割 |
| **2NF** | 部分関数従属がない | 複合PK (user_id, product_id) で product_name が product_id のみに従属 | product_name を product テーブルに移動 |
| **3NF** | 推移的従属がない | user_id → zip_code, zip_code → city（推移的従属 user_id → city） | zip_code と city を別テーブル（zipcode_city）に分離 |
| **BCNF** | 全決定項が候補キー | 決定項が候補キーでない関数従属が存在 | 決定項を新テーブルのPKに設定 |

**推奨：** 原則3NFまで正規化する。BCNFは学術的厳密性が必要な場合のみ。

---

### インデックス追加判断テーブル

| 判断基準 | インデックス推奨 | インデックス不要 |
|---------|----------------|----------------|
| SELECT頻度 | 高頻度（毎秒数百回以上） | 低頻度（1日数回程度） |
| WHERE句での使用 | 検索条件として頻繁に使われる | ほぼ使われない |
| JOIN条件 | 外部キー（JOIN ON句） | JOINに使われない |
| ORDER BY/GROUP BY | ソート・集計対象列 | ソートしない |
| カーディナリティ | 高い（ユニーク値が多い） | 低い（性別等2-3値） |
| テーブルサイズ | 数千行以上 | 数百行以下 |

**推奨：** 外部キー・検索条件列は原則インデックス追加。ただし INSERT/UPDATE 性能とのトレードオフを検証すること。

---

### 非正規化判断テーブル

| 判断基準 | 非正規化検討 | 正規化維持 |
|---------|------------|----------|
| JOIN性能 | 3テーブル以上の頻繁なJOIN | 単純な1-2テーブルJOIN |
| 集計クエリ頻度 | COUNT/SUM等が毎秒数百回 | 集計は稀 |
| データ更新頻度 | ほぼ読み取り専用 | 頻繁な更新（INSERT/UPDATE） |
| 整合性リスク許容度 | 許容（ログ・キャッシュ等） | 不許容（トランザクション中核） |

**警告：** 非正規化は最後の手段。必ずトリガー・アプリケーションロジックで整合性維持機構を実装し、文書化すること。

---

## ユーザー確認の原則（AskUserQuestion）

データベース設計では、ビジネス要件・パフォーマンストレードオフ・将来の拡張性が絡む判断で、ユーザーに確認すべき場面と確認不要な場面を明確に区別する。

### 確認すべき場面（必須）

以下の状況では**AskUserQuestionツールで必ずユーザーに選択肢を提示**すること：

1. **Natural Key vs Surrogate Key の選択**
   - 例: `email` を主キーにするか、`user_id` を新規作成するか
   - 選択肢:
     - Natural Key（email）使用 - 利点：直感的、欠点：変更時のFK更新コスト
     - Surrogate Key（user_id）使用 - 利点：安定、欠点：ビジネスキーが別に必要

2. **正規化レベルの決定**
   - 例: 3NFで停止するか、BCNFまで進めるか
   - 選択肢:
     - 3NFで停止 - 実用的、JOIN数が少ない
     - BCNFまで正規化 - 理論的に完全だがJOIN増加

3. **非正規化の採否**
   - 例: 集計カラム（total_orders）を user テーブルに追加するか
   - 選択肢:
     - 非正規化する - 性能向上、整合性リスク
     - 正規化維持 - 整合性保証、JOIN必要

4. **テーブル統合の判断**
   - 例: `address` テーブルを独立させるか、`user` テーブルに統合するか
   - 選択肢:
     - 独立テーブル - 正規化、複数住所対応可
     - 統合 - シンプル、単一住所のみ

**AskUserQuestion 記述例：**

```python
from claude_code import AskUserQuestion

# Natural Key vs Surrogate Key の確認
AskUserQuestion(
    questions=[{
        "question": "user テーブルの主キーを選択してください。",
        "header": "主キー選択",
        "options": [
            {
                "label": "Natural Key (email)",
                "description": "利点: 直感的、他テーブルから参照しやすい / 欠点: メールアドレス変更時に外部キー連鎖更新が必要"
            },
            {
                "label": "Surrogate Key (user_id)",
                "description": "利点: 安定（変更なし）、外部キー更新不要 / 欠点: email に UNIQUE 制約が別途必要"
            }
        ],
        "multiSelect": False
    }]
)
```

---

### 確認不要な場面（自動判断可）

以下の状況は**技術的な標準・ベストプラクティスに基づいて自動判断**してよい（ユーザー確認は不要）：

1. **外部キー制約の追加** - リレーションシップが明確なら必ず `FOREIGN KEY` を追加
2. **1NF違反の修正** - 多値カラム（カンマ区切りリスト）は必ず正規化
3. **SQL予約語の回避** - `user`, `order` 等の予約語を列名にしない（`users`, `user_order` に変更）
4. **NOT NULL制約の設定** - ビジネス要件から明らかに必須の属性（例: username）は `NOT NULL`
5. **TIMESTAMP のUTC使用** - タイムゾーン問題を避けるため UTC 保存が標準
6. **データ型の精度設定** - 金額は `DECIMAL(p, s)` でスケール2（小数点以下2桁）が標準

---

## 詳細ガイド

各フェーズの深掘り内容は以下のリファレンスファイルを参照：

1. **[ENTITIES-AND-KEYS.md](references/ENTITIES-AND-KEYS.md)** - エンティティ識別プロセス、命名規則（singular vs plural, snake_case）、キーの種類（Superkey → Candidate Key → Primary Key）、Natural Key vs Surrogate Key の判断基準、データ型選択ガイド（VARCHAR vs CHAR, INT vs BIGINT, DECIMAL vs FLOAT, 予約語回避）

2. **[RELATIONSHIPS.md](references/RELATIONSHIPS.md)** - ER図の記法（Crow's Foot notation）、リレーションシップ設計プロセス（主語-動詞-目的語パターンの利用）、カーディナリティ（1:1, 1:N, M:N）と判断基準、オプショナリティ（最小カーディナリティ0 or 1）、強エンティティ vs 弱エンティティ、接合テーブル（junction table）の設計

3. **[NORMALIZATION.md](references/NORMALIZATION.md)** - 正規化プロセス（1NF → 2NF → 3NF → BCNF）、各正規形のルール詳細、関数従属の識別方法、部分関数従属・推移的従属の検出とサイクル検出（3テーブル間）、正規化の実践例（DDL生成含む）

4. **[SECURITY-OPTIMIZATION.md](references/SECURITY-OPTIMIZATION.md)** - セキュリティレビュー（整合性チェック、FK制約、データ型検証、NOT NULL、機密性設計：RBAC vs MAC、暗号化）、ストレージ最適化（冗長テーブル統合、カテゴリカルデータ分離）、インデックス戦略（標準・複合・フルテキストインデックス、追加判断基準）、非正規化（判断基準、安全なパターン、整合性維持機構）

5. **[POSTGRESQL-ARCHITECTURE.md](references/POSTGRESQL-ARCHITECTURE.md)** - PostgreSQLマイクロサービスデータアーキテクチャ（データベースモジュール化、スキーマAPI定義、Foreign Data Wrappers、論理レプリケーション、接続プーリング、スケーリングパターン）

6. **[POSTGRESQL-TRANSACTIONS.md](references/POSTGRESQL-TRANSACTIONS.md)** - PostgreSQLトランザクション・データモデリング（ACID準拠、分離レベル Read Committed/Repeatable Read/Serializable、ロック制御 FOR UPDATE/FOR NO KEY UPDATE、Slowly Changing Dimensions Type 1-6、DATERANGE型）

7. **[POSTGRESQL-FUNCTIONS.md](references/POSTGRESQL-FUNCTIONS.md)** - PostgreSQL関数・ストアドプロシージャ（関数 vs プロシージャ、Volatility分類、PL/pgSQL制御構造・トリガー・例外処理、PL/Python3u、pg_background、plpgsql_check）

8. **[POSTGRESQL-SECURITY.md](references/POSTGRESQL-SECURITY.md)** - PostgreSQLセキュリティ（AAAフレームワーク: 認証・認可・監査、ロール階層、GRANT/REVOKE最小権限、pgAudit、マイクロサービスセキュリティ）

---

**設計の成功は、要件の正確な理解と各フェーズの丁寧な実行にかかっている。焦らず、一歩ずつ進めること。**
