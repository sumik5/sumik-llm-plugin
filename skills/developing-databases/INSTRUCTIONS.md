# データベース開発ガイド

リレーショナルDB設計・SQLアンチパターン回避・データベース内部構造の統合ガイド。
設計から実装、パフォーマンスチューニング、分散システム設計まで網羅する。

---

## リレーショナルDB設計

### 設計プロセス（5フェーズ）

```
Phase 1: 要件分析 → Phase 2: データモデリング → Phase 3: 正規化
    → Phase 4: 実装 → Phase 5: セキュリティ・最適化レビュー
```

| フェーズ | 主な作業 | 成果物 |
|---------|---------|--------|
| **1. 要件分析** | ステークホルダーインタビュー、エンティティ候補抽出 | エンティティ候補一覧 |
| **2. データモデリング** | ER図作成、主キー選定、カーディナリティ設定 | ER図 |
| **3. 正規化** | 1NF→2NF→3NF→BCNF、関数従属の排除 | 正規化済みテーブル定義 |
| **4. 実装** | DDL生成、制約・インデックス作成 | DDLスクリプト |
| **5. セキュリティ・最適化** | FK制約確認、暗号化設計、インデックス戦略 | セキュリティ仕様書 |

### キー選択判断テーブル

| 判断基準 | Natural Key推奨 | Surrogate Key推奨 |
|---------|----------------|------------------|
| 候補キーの安定性 | 変更されない（例: product_code） | 変更される可能性（例: email） |
| 複合キーの必要性 | 単一列でユニーク | 複合キーになる（2列以上） |
| 検索性能 | Natural Keyが短い（≤12文字） | Natural Keyが長い（>12文字） |

**推奨**: 迷ったらSurrogate Key（自動採番INT）。Natural Keyはビジネス要件で明確に必要な場合のみ。

### 正規化レベル判断テーブル

| 正規化レベル | 確認内容 | 違反例 | 対処 |
|-------------|---------|--------|------|
| **1NF** | 主キー存在、原子性（多値排除） | `tags: "sci-fi,fantasy"` | tags列を別テーブルに分割 |
| **2NF** | 部分関数従属がない | 複合PKの一部にのみ従属 | 従属先を別テーブルに移動 |
| **3NF** | 推移的従属がない | user_id→zip_code→city | zip_codeとcityを別テーブルに分離 |
| **BCNF** | 全決定項が候補キー | 決定項が候補キーでない | 決定項を新テーブルのPKに設定 |

**推奨**: 原則3NFまで正規化。BCNFは学術的厳密性が必要な場合のみ。

### インデックス追加判断テーブル

| 判断基準 | インデックス推奨 | 不要 |
|---------|----------------|------|
| SELECT頻度 | 高頻度（毎秒数百回以上） | 低頻度（1日数回程度） |
| WHERE句での使用 | 検索条件として頻繁に使われる | ほぼ使われない |
| JOIN条件 | 外部キー（JOIN ON句） | JOINに使われない |
| カーディナリティ | 高い（ユニーク値が多い） | 低い（性別等2-3値） |

### ユーザー確認が必要な場面

- **Natural Key vs Surrogate Key の選択** — emailを主キーにするか新規user_idを作るか
- **正規化レベルの決定** — 3NFで停止するかBCNFまで進めるか
- **非正規化の採否** — 集計カラムをuserテーブルに追加するか

**詳細**: [DESIGN-ENTITIES-AND-KEYS.md](./references/DESIGN-ENTITIES-AND-KEYS.md), [DESIGN-RELATIONSHIPS.md](./references/DESIGN-RELATIONSHIPS.md), [DESIGN-NORMALIZATION.md](./references/DESIGN-NORMALIZATION.md), [DESIGN-SECURITY-OPTIMIZATION.md](./references/DESIGN-SECURITY-OPTIMIZATION.md), [DESIGN-POSTGRESQL-ARCHITECTURE.md](./references/DESIGN-POSTGRESQL-ARCHITECTURE.md)

---

## SQLアンチパターン

### クイックリファレンス：全25パターン

#### 第Ⅰ部：論理設計のアンチパターン

| # | パターン名 | 問題 | 検出シグナル | 解決策 |
|---|-----------|------|------------|--------|
| 1 | ジェイウォーク | カンマ区切りでリスト値を1列に格納 | LIKE検索、文字列分割処理 | 交差テーブル（1行1値） |
| 2 | ナイーブツリー | 隣接リストのみで階層を表現 | 再帰クエリ、深さ制限 | 経路列挙/入れ子集合/閉包テーブル |
| 3 | IDリクワイアド | 全テーブルに`id`列を無条件に追加 | 自然キーが存在するのに疑似キー使用 | 状況に応じた主キー選択 |
| 4 | キーレスエントリ | 外部キー制約を宣言しない | 孤児レコード | `FOREIGN KEY`制約の宣言 |
| 5 | EAV | 汎用的な属性テーブルで全属性を格納 | `(entity_id, attr_name, attr_value)` 構造 | サブタイプモデリング/JSONB |
| 6 | ポリモーフィック関連 | 1つのFKが複数テーブルを参照 | `object_type`+`object_id`列 | 交差テーブル分離/共通スーパータイプ |
| 7 | マルチカラムアトリビュート | `tag1`, `tag2`, `tag3`のように列を複製 | 連番付き列名 | 従属テーブル（1行1値） |
| 8 | メタデータトリブル | テーブルや列を年度別に分割 | `bugs_2023`, `bugs_2024` | パーティショニング/単一テーブル |

#### 第Ⅱ部：物理設計のアンチパターン

| # | パターン名 | 問題 | 解決策 |
|---|-----------|------|--------|
| 9 | ラウンディングエラー | FLOAT/DOUBLEで通貨・精密値を格納 | `NUMERIC`/`DECIMAL`固定小数点型 |
| 10 | サーティワンフレーバー | ENUMでコード値を固定 | 参照テーブル（ルックアップテーブル） |
| 11 | ファントムファイル | ファイルパスのみDB格納、実体は外部 | `BLOB`/オブジェクトストレージ+メタデータ |
| 12 | インデックスショットガン | 闇雲にインデックスを作成/削除 | MENTOR原則（測定・説明・指名・検証・整理・再構築） |

#### 第Ⅲ部：クエリのアンチパターン

| # | パターン名 | 問題 | 解決策 |
|---|-----------|------|--------|
| 13 | フィア・オブ・ジ・アンノウン | `NULL`を避ける、誤った比較 | `IS NULL`/`IS NOT NULL`/`COALESCE` |
| 14 | アンビギュアスグループ | GROUP BYに含まれない列をSELECT | 集約関数/`GROUP BY`追加/導出テーブル |
| 15 | ランダムセレクション | `ORDER BY RAND()`でランダム行取得 | オフセット法/キーベース法 |
| 16 | プアマンズ・サーチエンジン | LIKE/REGEXPで全文検索を実装 | 全文検索インデックス/検索エンジン |
| 17 | スパゲッティクエリ | 1つの巨大クエリで全処理を実装 | 分割統治、CTE、一時テーブル |
| 18 | インプリシットカラム | `SELECT *`/`INSERT`で列名省略 | 明示的な列名指定 |

#### 第Ⅳ部：アプリケーション開発のアンチパターン

| # | パターン名 | 問題 | 解決策 |
|---|-----------|------|--------|
| 19 | リーダブルパスワード | パスワードを平文/可逆暗号化で格納 | ソルト付きハッシュ（bcrypt/Argon2） |
| 20 | SQLインジェクション | SQL文字列を動的に連結 | プリペアドステートメント/パラメータ化 |
| 21 | シュードキー・ニートフリーク | 疑似キーの欠番を詰める | 欠番を許容、ビジネスキーと分離 |
| 22 | シー・ノー・エビル | データベースエラーを無視 | 適切なエラーハンドリング・ロギング |
| 23 | ディプロマティック・イミュニティ | SQL文だけ品質基準を除外 | アプリコードと同等の品質基準適用 |
| 24 | マジックビーンズ | ActiveRecordクラス=ドメインモデル | ドメインモデルとORMの分離 |
| 25 | 砂の城 | 本番環境の想定不足 | 容量計画/バックアップ/HA/DR戦略 |

### リファクタリング優先順位

**Critical（即座に修正）**: パターン20(SQLインジェクション), 19(平文パスワード), 4(FK制約の欠如)
**High（次回スプリント）**: パターン1,5,7(正規化), 9(浮動小数点型), 22(エラー処理の欠如)
**Medium（計画的に）**: パターン2,8(テーブル構造), 12,15,16,17(パフォーマンス)

**詳細**: [ANTIPATTERN-LOGICAL-DESIGN.md](./references/ANTIPATTERN-LOGICAL-DESIGN.md), [ANTIPATTERN-PHYSICAL-DESIGN.md](./references/ANTIPATTERN-PHYSICAL-DESIGN.md), [ANTIPATTERN-QUERY-PATTERNS.md](./references/ANTIPATTERN-QUERY-PATTERNS.md), [ANTIPATTERN-APPLICATION-DEV.md](./references/ANTIPATTERN-APPLICATION-DEV.md), [ANTIPATTERN-NORMALIZATION.md](./references/ANTIPATTERN-NORMALIZATION.md), [ANTIPATTERN-FOREIGN-KEYS.md](./references/ANTIPATTERN-FOREIGN-KEYS.md)

---

## データベース内部構造

### ストレージエンジン選択：B-tree vs LSM-tree

| 特性 | B-tree | LSM-tree |
|------|--------|----------|
| **読み取り性能** | ✅ 高速（1〜2回のディスクシーク） | ⚠️ 中程度（複数のSSTableスキャン） |
| **書き込み性能** | ⚠️ 中程度（ランダムI/O） | ✅ 高速（シーケンシャルI/O） |
| **空間効率** | ⚠️ 低（断片化によるオーバーヘッド） | ✅ 高（圧縮率が高い） |
| **範囲クエリ** | ✅ 効率的（連続キー） | ⚠️ 中程度（マージスキャン） |
| **トランザクション** | ✅ 容易（WAL） | ⚠️ 複雑 |
| **代表的実装** | PostgreSQL, MySQL InnoDB, SQLite | Cassandra, HBase, RocksDB, LevelDB |

**B-treeが適している場合**: 読み取り重視・頻繁な更新・範囲クエリ・ACID要件
**LSM-treeが適している場合**: 書き込み重視・高スループット・ストレージコスト重要・時系列データ

### 一貫性モデル早見表

| 一貫性レベル | 保証内容 | レイテンシ | 可用性 | 代表的実装 |
|------------|---------|----------|-------|----------|
| **線形化可能性** | すべての操作が単一のグローバル順序 | 🔴 高 | 🔴 低 | etcd, Consul |
| **因果一貫性** | 因果関係のある操作のみ順序保証 | 🟢 低〜中 | 🟢 高 | Cassandra |
| **結果整合性** | 更新が最終的にすべてのレプリカに伝播 | ✅ 低 | ✅ 高 | DynamoDB, Cassandra |

**CAP定理**: CP（一貫性+分断耐性）vs AP（可用性+分断耐性）の選択が必要。

### 分散トランザクション選択ガイド

| アプローチ | 一貫性 | レイテンシ | 用途 |
|----------|-------|----------|------|
| **2-Phase Commit** | 🟢 強 | 🔴 高 | 従来のRDBMS |
| **Saga Pattern** | 🟠 結果整合性 | 🟢 低 | マイクロサービス |
| **Paxos/Raft** | 🟢 強 | 🟠 中 | 合意ベースの状態マシン |
| **Spanner** | 🟢 線形化+外部一貫性 | 🟠 中 | グローバル分散DB |

**詳細**: [INTERNALS-DBMS-ARCHITECTURE.md](./references/INTERNALS-DBMS-ARCHITECTURE.md), [INTERNALS-BTREE-FUNDAMENTALS.md](./references/INTERNALS-BTREE-FUNDAMENTALS.md), [INTERNALS-LOG-STRUCTURED-STORAGE.md](./references/INTERNALS-LOG-STRUCTURED-STORAGE.md), [INTERNALS-REPLICATION-CONSISTENCY.md](./references/INTERNALS-REPLICATION-CONSISTENCY.md), [INTERNALS-DISTRIBUTED-TRANSACTIONS.md](./references/INTERNALS-DISTRIBUTED-TRANSACTIONS.md), [INTERNALS-CONSENSUS-ALGORITHMS.md](./references/INTERNALS-CONSENSUS-ALGORITHMS.md)

---

## 詳細ガイド

### リレーショナルDB設計 references/

| ファイル | 内容 |
|---------|------|
| [DESIGN-ENTITIES-AND-KEYS.md](./references/DESIGN-ENTITIES-AND-KEYS.md) | エンティティ識別、命名規則、キー種別、データ型選択 |
| [DESIGN-RELATIONSHIPS.md](./references/DESIGN-RELATIONSHIPS.md) | ER図記法、カーディナリティ、接合テーブル設計 |
| [DESIGN-NORMALIZATION.md](./references/DESIGN-NORMALIZATION.md) | 正規化プロセス詳細、関数従属、実践例（DDL生成含む） |
| [DESIGN-SECURITY-OPTIMIZATION.md](./references/DESIGN-SECURITY-OPTIMIZATION.md) | セキュリティレビュー、インデックス戦略、非正規化 |
| [DESIGN-POSTGRESQL-ARCHITECTURE.md](./references/DESIGN-POSTGRESQL-ARCHITECTURE.md) | PostgreSQLマイクロサービスデータアーキテクチャ |
| [DESIGN-POSTGRESQL-TRANSACTIONS.md](./references/DESIGN-POSTGRESQL-TRANSACTIONS.md) | ACID、分離レベル、SCD Type 1-6 |
| [DESIGN-POSTGRESQL-FUNCTIONS.md](./references/DESIGN-POSTGRESQL-FUNCTIONS.md) | 関数・ストアドプロシージャ、PL/pgSQL |
| [DESIGN-POSTGRESQL-SECURITY.md](./references/DESIGN-POSTGRESQL-SECURITY.md) | AAAフレームワーク、RBAC、pgAudit |

### SQLアンチパターン references/

| ファイル | 内容 |
|---------|------|
| [ANTIPATTERN-LOGICAL-DESIGN.md](./references/ANTIPATTERN-LOGICAL-DESIGN.md) | パターン1-8詳細（データモデリング、正規化） |
| [ANTIPATTERN-PHYSICAL-DESIGN.md](./references/ANTIPATTERN-PHYSICAL-DESIGN.md) | パターン9-12詳細（データ型、インデックス） |
| [ANTIPATTERN-QUERY-PATTERNS.md](./references/ANTIPATTERN-QUERY-PATTERNS.md) | パターン13-18詳細（SQL文、パフォーマンス） |
| [ANTIPATTERN-APPLICATION-DEV.md](./references/ANTIPATTERN-APPLICATION-DEV.md) | パターン19-25詳細（セキュリティ、アーキテクチャ） |
| [ANTIPATTERN-NORMALIZATION.md](./references/ANTIPATTERN-NORMALIZATION.md) | 第1-5正規形、ボイスコッド正規形の詳細解説 |
| [ANTIPATTERN-FOREIGN-KEYS.md](./references/ANTIPATTERN-FOREIGN-KEYS.md) | 外部キーのミニ・アンチパターン集 |

### データベース内部構造 references/

| ファイル | 内容 |
|---------|------|
| [INTERNALS-MODELS.md](./references/INTERNALS-MODELS.md) | 伝統的データベースモデル（リレーショナル、階層等） |
| [INTERNALS-NOSQL-MODELS.md](./references/INTERNALS-NOSQL-MODELS.md) | NoSQL・特殊用途モデル（ドキュメント、グラフ等） |
| [INTERNALS-STORAGE-AND-PROCESSING.md](./references/INTERNALS-STORAGE-AND-PROCESSING.md) | ストレージ戦略（SAN/NAS/DAS、RAID）・分散処理 |
| [INTERNALS-DBMS-ARCHITECTURE.md](./references/INTERNALS-DBMS-ARCHITECTURE.md) | DBMSアーキテクチャ、メモリ/ディスクベース、行/列指向 |
| [INTERNALS-BTREE-FUNDAMENTALS.md](./references/INTERNALS-BTREE-FUNDAMENTALS.md) | BST、ディスク構造、Bツリー階層・操作 |
| [INTERNALS-BTREE-IMPLEMENTATION.md](./references/INTERNALS-BTREE-IMPLEMENTATION.md) | ページヘッダ、二分探索、スプリット/マージ |
| [INTERNALS-BTREE-VARIANTS.md](./references/INTERNALS-BTREE-VARIANTS.md) | コピーオンライト、遅延Bツリー、FDツリー |
| [INTERNALS-LOG-STRUCTURED-STORAGE.md](./references/INTERNALS-LOG-STRUCTURED-STORAGE.md) | LSMツリー、SSTable、ブルームフィルタ |
| [INTERNALS-TRANSACTIONS-RECOVERY.md](./references/INTERNALS-TRANSACTIONS-RECOVERY.md) | バッファ管理、WAL、ARIES、同時実行制御 |
| [INTERNALS-DISTRIBUTED-FUNDAMENTALS.md](./references/INTERNALS-DISTRIBUTED-FUNDAMENTALS.md) | 分散コンピューティングの誤謬、障害モデル、FLP不可能性 |
| [INTERNALS-FAILURE-DETECTION-LEADER-ELECTION.md](./references/INTERNALS-FAILURE-DETECTION-LEADER-ELECTION.md) | ハートビート、φ故障検出器、リーダー選出 |
| [INTERNALS-REPLICATION-CONSISTENCY.md](./references/INTERNALS-REPLICATION-CONSISTENCY.md) | CAP定理、一貫性モデル、CRDTs |
| [INTERNALS-ANTI-ENTROPY-GOSSIP.md](./references/INTERNALS-ANTI-ENTROPY-GOSSIP.md) | 読み取り修復、Merkleツリー、ゴシップ散布 |
| [INTERNALS-DISTRIBUTED-TRANSACTIONS.md](./references/INTERNALS-DISTRIBUTED-TRANSACTIONS.md) | 2PC、3PC、Calvin、Spanner、Percolator |
| [INTERNALS-CONSENSUS-ALGORITHMS.md](./references/INTERNALS-CONSENSUS-ALGORITHMS.md) | Paxos全亜種、Raft、ビザンチン合意、PBFT |
