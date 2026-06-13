# PostgreSQL セキュリティ（AAAフレームワーク）

PostgreSQLのセキュリティは、**Authentication（認証）、Authorization（認可）、Audit（監査）**の3つの柱で構成されます。このガイドでは、PostgreSQLの機能を活用したAAA実装の体系的なアプローチを示します。

---

## 1. AAAフレームワーク概要

マイクロサービスアーキテクチャでは、接続ポイント・API・可動部分が増えるため、体系的でスケーラブルなセキュリティアプローチが不可欠です。AAAフレームワークは以下の問いに答えます:

| フェーズ | 問い | PostgreSQL機能 |
|---------|------|---------------|
| **Authentication（認証）** | 誰が接続しているのか？ | Password, LDAP, Kerberos, AD, OAuth, 証明書, hba.conf |
| **Authorization（認可）** | その人に何をする権限があるのか？ | ROLE, GRANT, REVOKE, INHERIT, SECURITY DEFINER |
| **Audit（監査）** | 誰がいつ何をしたのか？ | pgAudit, log_statement, カスタムトリガー |

### マイクロサービスとAAAの相性

マイクロサービスアーキテクチャでは、**データサービスごとにAAA定義を独立管理**できます。これにより、モノリスで発生する複雑なルール管理から解放されます。

```
例: モノリスの場合
→ 全社のデータに対する統一的なAAA定義（複雑・管理困難）

例: マイクロサービスの場合
→ 製品参照サービスのAAA定義（シンプル）
→ 東海岸eコマースサービスのAAA定義（シンプル）
→ 中央分析サービスのAAA定義（シンプル）
```

---

## 2. 認証（Authentication）

認証は「誰が接続しているのか」を確認します。PostgreSQLは複数の認証メカニズムをサポートしています。

### 認証メカニズム

| メカニズム | 用途 | PostgreSQL設定 |
|-----------|------|---------------|
| **内蔵パスワード認証** | 開発環境、小規模環境 | `CREATE USER ... PASSWORD '...'` |
| **LDAP** | エンタープライズ環境、既存ディレクトリ統合 | hba.conf: `ldap` |
| **Kerberos** | エンタープライズ環境、シングルサインオン | hba.conf: `gss` |
| **Active Directory** | Windows環境、既存AD統合 | hba.conf: `sspi` (Windows) または `ldap` |
| **OAuth** | クラウドネイティブ環境（PostgreSQL 18新機能） | hba.conf: `oauth` |
| **証明書認証** | アプリケーション間通信、高セキュリティ環境 | hba.conf: `cert` |

### hba.conf による接続制御

`pg_hba.conf`（Host-Based Authentication）は、接続元と認証方式を定義します。

```
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# 管理者はローカル接続のみ許可、peer認証
local   all             postgres                                peer

# 製品管理者はVPN経由でLDAP認証
host    ecommerce_reference_data  product_management  10.0.1.0/24     ldap ldapserver=ldap.internal ldapbasedn="dc=company,dc=com"

# アプリケーション間通信は証明書認証
hostssl ecommerce_service  app_service_user  10.0.2.0/24     cert

# 一般アプリケーションはパスワード認証（md5またはscram-sha-256）
host    ecommerce_service  application_role  10.0.3.0/24     scram-sha-256
```

### 証明書認証の設定例

```bash
# サーバー証明書・鍵の配置
cp server.crt /var/lib/postgresql/data/server.crt
cp server.key /var/lib/postgresql/data/server.key
chmod 600 /var/lib/postgresql/data/server.key

# postgresql.conf
ssl = on
ssl_cert_file = 'server.crt'
ssl_key_file = 'server.key'
ssl_ca_file = 'root.crt'  # クライアント証明書の検証に使用

# pg_hba.conf
hostssl all all 0.0.0.0/0 cert clientcert=verify-full
```

---

## 3. 認可（Authorization）

認可は「接続した人に何をする権限があるのか」を管理します。PostgreSQLでは**ロール（ROLE）**と**権限（PRIVILEGES）**の2つの概念で実現します。

### 3.1 ロールとユーザー

PostgreSQLの用語において、「ユーザー」と「グループ」は両方とも**ロール**の別名です。

| SQL文 | 実際の意味 |
|-------|----------|
| `CREATE USER` | `CREATE ROLE ... WITH LOGIN` のエイリアス |
| `CREATE GROUP` | `CREATE ROLE ... WITH NOLOGIN` のエイリアス |

**推奨:**
- ログイン可能なロール → `CREATE USER`
- ログイン不可能なロール（グループ） → `CREATE ROLE`

### 3.2 ロール階層とINHERIT

ロールは階層構造を持つことができ、**INHERIT**により上位ロールの権限を自動継承します。

```sql
-- 製品管理の基本ロール
CREATE ROLE product_management;

-- 製品価格管理の特権ロール（product_managementを継承）
CREATE ROLE product_price_management
  INHERIT  -- 自動的に product_management の権限を継承
  IN ROLE product_management;

-- 個人ユーザー: Jim Miller（一般製品管理者）
CREATE USER jim_miller
  IN ROLE product_management;

-- 個人ユーザー: Jane Doe（価格管理者）
CREATE USER jane_doe
  IN ROLE product_price_management;
```

**INHERITの効果:**
- Jane Doeは `product_price_management` と `product_management` の両方の権限を持つ
- Jim Millerは `product_management` の権限のみを持つ

### 3.3 アクセス制御の原則: ロールレベルで定義する

**重要:** アクセス制御は**必ずロールレベル**で定義し、個人ユーザーレベルでは定義しません。

| ❌ 悪い例 | ✅ 良い例 |
|----------|----------|
| `GRANT SELECT ON sales TO jane_doe;` | `GRANT SELECT ON sales TO analysts;`<br>`GRANT analysts TO jane_doe;` |

**理由:**
- 個人の役割変更時、ロールを変更するだけでよい
- 新規入社・退社時、ロールに追加・削除するだけでよい
- 個別権限を調査する必要がない

### 3.4 最小権限の原則（Principle of Least Privilege）

最小権限の原則は以下の2ステップで実現します:

1. **すべてのデフォルト権限を剥奪**（必要ないと思うものだけではなく、すべて）
2. **必要な権限のみをGRANT**

#### ステップ1: すべてのデフォルト権限を剥奪

PostgreSQLでは、`PUBLIC`ロール（すべてのユーザーが自動的に所属）がデフォルトで持つ権限があります。これをすべて剥奪します。

```sql
-- データベースへの接続権限を剥奪
REVOKE CONNECT ON DATABASE ecommerce_reference_data FROM PUBLIC;

-- スキーマ使用権限を剥奪
REVOKE USAGE ON SCHEMA internal, product, api FROM PUBLIC;

-- 関数・プロシージャ実行権限を剥奪
REVOKE EXECUTE ON PROCEDURE api.update_current_price_flags FROM PUBLIC;

REVOKE EXECUTE ON FUNCTION
  api.manage_product_price,
  api.manage_product,
  api.manage_brand,
  api.manage_category
FROM PUBLIC;

-- ビュー・テーブルへのSELECT権限を剥奪（必要に応じて）
REVOKE SELECT ON ALL TABLES IN SCHEMA api FROM PUBLIC;
```

#### ステップ2: 必要な権限のみをGRANT

次に、各ロールに必要な権限のみを付与します。

```sql
-- 製品管理ロール: データベース接続を許可
GRANT CONNECT ON DATABASE ecommerce_reference_data TO product_management;

-- 製品管理ロール: APIスキーマの使用を許可
GRANT USAGE ON SCHEMA api TO product_management;

-- 製品管理ロール: APIスキーマ内の全テーブル・ビューへのSELECT権限
GRANT SELECT ON ALL TABLES IN SCHEMA api TO product_management;

-- 製品管理ロール: 製品・ブランド・カテゴリ管理関数の実行権限
GRANT EXECUTE ON FUNCTION
  api.manage_product,
  api.manage_brand,
  api.manage_category
TO product_management;

-- 価格管理ロール: 価格変更関数の実行権限（INHERITにより他の権限も継承）
GRANT EXECUTE ON FUNCTION
  api.manage_product_price
TO product_price_management;

GRANT EXECUTE ON PROCEDURE
  api.update_current_price_flags
TO product_price_management;
```

### 3.5 SECURITY DEFINERによる内部スキーマ保護

`SECURITY DEFINER`を使うと、関数の実行権限を**所有者の権限**で実行できます。これにより、内部スキーマへの直接アクセスを防ぎつつ、API経由のアクセスのみを許可できます。

```sql
-- 内部スキーマへの直接アクセスを禁止
REVOKE ALL ON SCHEMA product FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA product FROM PUBLIC;

-- API関数をSECURITY DEFINERで定義
CREATE FUNCTION api.manage_product_price(
  p_product_id INT,
  p_new_price DECIMAL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER  -- ← 関数所有者（通常はスーパーユーザー）の権限で実行
SET search_path = product, pg_temp  -- SQLインジェクション対策
AS $$
BEGIN
  -- 内部スキーマのテーブルを更新
  UPDATE product.product_variant_price
  SET price = p_new_price, updated_at = NOW()
  WHERE product_id = p_product_id;
END;
$$;

-- 関数実行権限のみを付与
GRANT EXECUTE ON FUNCTION api.manage_product_price TO product_price_management;
```

**結果:**
- `product_price_management`ロールのユーザーは`product.product_variant_price`テーブルに直接アクセスできない
- しかし、`api.manage_product_price`関数経由でのみ価格変更が可能
- データ整合性ルール・ビジネスロジックをAPI層で一元管理

---

## 4. 監査（Audit）

監査は「誰がいつ何をしたのか」を記録します。すべての操作を記録するのではなく、**ビジネス駆動の選択的監査**を推奨します。

### 4.1 監査の基本方針

| アプローチ | 説明 | 推奨度 |
|-----------|------|--------|
| `log_statement = all` | すべてのSQL文をログ | ❌ 性能劣化、ディスク消費、情報過多 |
| **ビジネス駆動監査** | ビジネス上重要な操作のみをログ | ✅ 推奨 |

**ビジネス駆動監査の例:**
- HR系システム: 給与情報へのSELECTアクセスをすべて記録
- eコマースシステム: 顧客特定割引の変更を記録
- 製品参照システム: 製品情報・価格の変更（INSERT/UPDATE/DELETE）を記録

### 4.2 pgAudit 拡張

**pgAudit**はPostgreSQLの監査拡張で、オブジェクトレベル・セッションレベルの監査を柔軟に設定できます。

#### pgAuditのインストールと基本設定

```sql
-- 拡張のインストール
CREATE EXTENSION pgaudit;

-- 監査ロールの作成
CREATE ROLE auditor;

-- システム全体で監査ロールを有効化
ALTER SYSTEM SET pgaudit.role = 'auditor';

-- DDL操作をすべて監査
ALTER SYSTEM SET pgaudit.log = 'ddl';

-- 設定を反映
SELECT pg_reload_conf();
```

#### オブジェクトレベル監査（テーブル・ビュー）

特定のテーブルへのDML操作（INSERT/UPDATE/DELETE）を監査します。

```sql
-- 製品参照サービスで製品データの変更を監査
GRANT INSERT, UPDATE, DELETE
  ON
    product.product,
    product.brand,
    product.category,
    product.product_variant,
    product.product_variant_price
TO auditor;
```

**動作:**
- `auditor`ロールに権限が付与されたテーブルへのDML操作が記録される
- ログには実行ユーザー、実行時刻、SQL文が含まれる

#### セッションレベル監査（関数・プロシージャ）

pgAuditは関数・プロシージャのオブジェクトレベル監査をサポートしていないため、**データベース全体で関数実行を監査**します。

```sql
-- ecommerce_reference_dataデータベースで関数・プロシージャ実行を監査
ALTER DATABASE ecommerce_reference_data SET pgaudit.log = 'function';
```

**注意:** この設定はデータベース内のすべての関数実行を記録します。監査対象を絞りたい場合、カスタムトリガーやアプリケーションログとの組み合わせを検討してください。

### 4.3 監査ログの出力先

pgAuditはPostgreSQLの標準ログファイルに監査情報を出力します。監査ログを別ファイルに分離するには、以下のアプローチがあります:

| アプローチ | 説明 |
|-----------|------|
| **ログパーサーで分離** | `log_line_prefix`で`AUDIT`を識別し、別ファイルに振り分け |
| **EDB Postgres Advanced Server** | 独立した監査ログファイルをサポート |
| **カスタムトリガー** | アプリケーション固有の監査テーブルに記録 |

#### ログパーサー例（rsyslogを使用）

```bash
# /etc/rsyslog.conf
:msg, contains, "AUDIT:" /var/log/postgresql/audit.log
& stop
```

### 4.4 監査設計の判断基準

| 監査対象 | DDL | DML (INSERT/UPDATE/DELETE) | SELECT | 関数実行 |
|---------|-----|------------------------|--------|---------|
| **全システム共通** | ✅ 常に監査 | ビジネス判断 | ビジネス判断 | ビジネス判断 |
| **製品参照サービス** | ✅ | ✅ 製品・価格変更 | ❌ | ✅ 価格変更関数 |
| **eコマースサービス** | ✅ | ✅ 在庫変更 | ❌ | ❌ |
| **中央分析サービス** | ✅ | ❌ | ✅ 分析レポートアクセス | ❌ |

---

## 5. マイクロサービスとセキュリティの統合

マイクロサービスアーキテクチャでは、**データサービスごとにAAA定義を独立管理**することで、セキュリティルールをシンプルに保てます。

### 5.1 認可のマイクロサービス分離

各データサービスで独立した認可ルールを定義します。

```
製品参照サービス:
  - product_management ロール: 製品情報の読み書き
  - product_price_management ロール: 価格変更権限

東海岸eコマースサービス:
  - inventory_manager ロール: 在庫管理
  - sales_analyst ロール: 売上データ参照

中央分析サービス:
  - analyst ロール: 全社分析レポート参照
```

**重要:** Jane Doeが製品価格管理者である場合、彼女は**製品参照サービスのみ**にアクセス権を持ち、他のサービスでは一切言及されません（最小権限の原則により、デフォルトで権限なし）。

### 5.2 監査のマイクロサービス分離

監査ルールもサービスごとに定義します。

```
製品参照サービス:
  - 価格変更のみを監査（価格は製品参照サービスでのみ変更可能）

東海岸eコマースサービス:
  - 在庫変更を監査

中央分析サービス:
  - 分析レポートへのアクセスを監査（アナリストのみアクセス可能）
```

この分離により、「誰が価格を変更したか」を調べる際、製品参照サービスの監査ログのみを調査すれば済みます。

### 5.3 認証の外部化

認証はできるだけ**データベース外部**で処理することを推奨します。

```
[推奨アプローチ]
アプリケーション → LDAP/AD/OAuth で認証 → PostgreSQL接続

[pg_hba.conf]
hostssl ecommerce_service product_management 10.0.1.0/24 ldap ...
```

これにより、データベース管理者はパスワード管理から解放され、企業全体の認証基盤を再利用できます。

---

## まとめ

PostgreSQLのAAAフレームワークは以下の原則で実装します:

### Authentication（認証）
- LDAP/Kerberos/AD/OAuthで既存認証基盤と統合
- アプリケーション間通信は証明書認証
- hba.confで接続元と認証方式を制御

### Authorization（認可）
- **CREATE USER / CREATE ROLE でロール階層を構築**
- **INHERITで権限継承**
- **個人ユーザーではなくロールレベルで権限定義**
- **最小権限の原則（REVOKE ALL → 必要な権限のみGRANT）**
- **SECURITY DEFINERで内部スキーマ保護**

### Audit（監査）
- **ビジネス駆動の選択的監査（log_statement=allは禁止）**
- **pgAuditでオブジェクトレベル監査**
- **DDLは常に監査、DML/SELECT/関数実行はビジネス判断**

### マイクロサービスとの統合
- データサービスごとにAAA定義を独立管理
- 認可・監査ルールがシンプルになる
- 認証は外部システムに委譲

このフレームワークにより、スケーラブルで管理しやすいセキュリティモデルを実現できます。

---

## 6. ロール属性の詳細リファレンス（Ch6補足）

ロール属性はクラスターレベルの権限設定であり、`CREATE ROLE` 時または `ALTER ROLE` で設定する。

### 6.1 ロール属性一覧

| 属性 | 反対属性 | デフォルト | 説明 |
|------|---------|-----------|------|
| `LOGIN` | **`NOLOGIN`** | NOLOGIN | クラスターへのログイン可否。LOGINはユーザー、NOLOGINはグループ |
| `SUPERUSER` | **`NOSUPERUSER`** | NOSUPERUSER | すべてのセキュリティチェックをバイパス |
| `CREATEROLE` | **`NOCREATEROLE`** | NOCREATEROLE | 他ロールの作成・変更・削除が可能 |
| `CREATEDB` | **`NOCREATEDB`** | NOCREATEDB | 新規データベースの作成が可能 |
| `REPLICATION` | **`NOREPLICATION`** | NOREPLICATION | レプリケーション接続・スロット管理 |
| `BYPASSRLS` | **`NOBYPASSRLS`** | NOBYPASSRLS | Row Level Security ポリシーのバイパス |
| **`INHERIT`** | `NOINHERIT` | INHERIT | メンバーであるロールの権限を自動継承 |
| `PASSWORD` | - | - | パスワードを設定（パスワード認証使用時） |
| `CONNECTION LIMIT` | - | -1（無制限） | 同時接続数の上限 |

```sql
-- スーパーユーザーに近いがSUPERUSERではない管理ロール（推奨パターン）
CREATE ROLE cluster_admin WITH LOGIN CREATEROLE CREATEDB
  PASSWORD 'secure_password'
  CONNECTION LIMIT 5;

-- レポートユーザー（接続数制限あり）
CREATE ROLE reporting_user WITH LOGIN
  PASSWORD 'report_pass'
  CONNECTION LIMIT 10;

-- ロール設定でパラメータを固定（接続時に自動適用）
ALTER ROLE reporting_user SET work_mem = '128MB';
ALTER ROLE reporting_user SET jit TO off;

-- 設定をリセット
ALTER ROLE reporting_user RESET jit;
```

### 6.2 スーパーユーザーの安全な運用

スーパーユーザーはすべてのセキュリティチェックをバイパスする危険な権限。推奨パターン:

```sql
-- 1. superuser-like ロールを作成（CREATEROLE + CREATEDBのみ）
CREATE ROLE cluster_admin WITH LOGIN CREATEROLE CREATEDB
  PASSWORD 'admin_password';

-- 2. cluster_admin を superuser ロールのメンバーにする
GRANT postgres TO cluster_admin;

-- 3. postgres（superuser）にNOLOGINを設定（直接ログイン禁止）
ALTER ROLE postgres WITH NOLOGIN;

-- 4. superuser権限が必要な作業時はSET ROLEで一時的に昇格
SET ROLE postgres;  -- 作業実行
RESET ROLE;         -- 通常ロールに戻る
```

> ⚠️ クラウド管理型PostgreSQL（RDS、Cloud SQL等）ではSUPERUSERロールへのアクセスは提供されない。代わりにsuperuser-likeな管理ロールが提供される。

---

## 7. GRANT / REVOKE 粒度別ガイド（Ch6補足）

### 7.1 Database 権限

```sql
-- 構文
GRANT { CREATE | CONNECT | TEMPORARY | TEMP } [, ...]
  ON DATABASE database_name
  TO role_name;

-- 実例
-- 全ロールに接続とTEMP テーブル作成を許可
GRANT CONNECT, TEMP ON DATABASE app_db TO app_users;

-- 管理者ロールにスキーマ作成権限
GRANT CREATE ON DATABASE app_db TO app_admins;
```

| 権限 | 説明 |
|------|------|
| `CONNECT` | データベースへの接続（hba.confの次のチェック） |
| `CREATE` | データベース内にスキーマを作成 |
| `TEMPORARY` / `TEMP` | テンポラリテーブルの作成 |

### 7.2 Schema 権限

```sql
-- 構文
GRANT { CREATE | USAGE } [, ...]
  ON SCHEMA schema_name
  TO role_name;

-- 実例
-- USAGEなしではテーブル名が見えても実際にはアクセスできない
GRANT USAGE ON SCHEMA app_schema TO app_users;
GRANT CREATE ON SCHEMA app_schema TO app_admins;
```

| 権限 | 説明 |
|------|------|
| `USAGE` | スキーマ内のオブジェクトへのアクセスを許可（これがないとSELECTも不可）|
| `CREATE` | スキーマ内にオブジェクト（テーブル、ビュー等）を作成 |

### 7.3 Table 権限

```sql
-- 構文
GRANT { SELECT | INSERT | UPDATE | DELETE | TRUNCATE | REFERENCES | TRIGGER } [, ...]
  ON { TABLE table_name | ALL TABLES IN SCHEMA schema_name }
  TO role_name;

-- 実例（グループロール階層に対して付与）
GRANT SELECT ON ALL TABLES IN SCHEMA app_schema TO app_users;
GRANT INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA app_schema TO app_developers;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA app_schema TO app_admins;
```

| 権限 | 説明 |
|------|------|
| `SELECT` | データの読み取り。COPY TOにも必要 |
| `INSERT` | 行の挿入。COPY FROMにも必要 |
| `UPDATE` | 行の更新（SELECTも必要） |
| `DELETE` | 行の削除（SELECTも必要） |
| `TRUNCATE` | テーブルの全削除 |
| `REFERENCES` | 外部キー制約の作成 |
| `TRIGGER` | トリガーの作成 |

### 7.4 グループロールへのメンバーシップ付与

```sql
-- 構文
GRANT role_name TO user_or_group_role;

-- 実例：グループロール階層
-- グループロール（NOLOGIN）
CREATE ROLE app_users WITH NOLOGIN;
CREATE ROLE app_developers WITH NOLOGIN;
CREATE ROLE app_admins WITH NOLOGIN;

-- ユーザーロール（LOGIN）
CREATE ROLE app_read_only WITH LOGIN PASSWORD '...';
CREATE ROLE app_dev_jr WITH LOGIN PASSWORD '...';
CREATE ROLE app_dev_sr WITH LOGIN PASSWORD '...';

-- メンバーシップ付与（権限の継承）
GRANT app_users TO app_read_only, app_dev_jr, app_dev_sr;
GRANT app_developers TO app_dev_jr, app_dev_sr;
GRANT app_admins TO app_dev_sr;
```

**グループロールの特徴**:
- ロールへのGRANTはオブジェクトではなくメンバー全体に影響する（後から追加したメンバーにも適用）
- グループロールに権限変更すると、すべてのメンバーロールに即時反映

---

## 8. デフォルト権限（ALTER DEFAULT PRIVILEGES）

### 8.1 問題：新規オブジェクトは権限なし

```sql
-- ❌ 既存テーブルにGRANTしても新しく作るテーブルには権限がない
GRANT SELECT ON ALL TABLES IN SCHEMA app_schema TO app_users;
-- この後で CREATE TABLE すると → app_users は選択できない
```

### 8.2 DEFAULT PRIVILEGES で解決

```sql
-- 接続ロールが今後作成するオブジェクトに自動でGRANTを設定
ALTER DEFAULT PRIVILEGES IN SCHEMA app_schema
  GRANT SELECT ON TABLES TO app_users;

ALTER DEFAULT PRIVILEGES IN SCHEMA app_schema
  GRANT INSERT, UPDATE, DELETE ON TABLES TO app_developers;

-- これ以降に CREATE TABLE すると自動的に権限が付与される
CREATE TABLE app_schema.new_table (id SERIAL PRIMARY KEY, name TEXT);
-- → app_users は SELECT 可能、app_developers は DML 可能（追加のGRANT不要）
```

### 8.3 持続可能なアプローチ（一元管理ロール）

大規模アプリケーションで複数の開発者がオブジェクトを作成する場合、各自がデフォルト権限を設定すると管理が煩雑になる。**1つのグループロールにオブジェクト作成を集約**する。

```sql
-- 1. DDL専用グループロール（NOLOGIN）を作成
CREATE ROLE app_ddl_admin WITH NOLOGIN;

-- 2. 必要な権限を付与
GRANT USAGE, CREATE ON SCHEMA app_schema TO app_ddl_admin;

-- 3. 管理者ロールをメンバーにする
GRANT app_ddl_admin TO app_admins;

-- 4. app_ddl_adminとしてデフォルト権限を設定（一度だけ）
SET ROLE app_ddl_admin;

ALTER DEFAULT PRIVILEGES IN SCHEMA app_schema
  GRANT SELECT ON TABLES TO app_users;

ALTER DEFAULT PRIVILEGES IN SCHEMA app_schema
  GRANT INSERT, UPDATE, DELETE ON TABLES TO app_developers;

-- 5. このロールでテーブルを作成すると自動で権限が付与される
CREATE TABLE app_schema.orders (
  order_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id  BIGINT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- 6. 通常ロールに戻る
SET ROLE NONE;
```

```sql
-- デフォルト権限の削除も可能
ALTER DEFAULT PRIVILEGES IN SCHEMA app_schema
  REVOKE DELETE ON TABLES FROM app_developers;

-- PUBLIC ロールへの関数実行権限を削除
ALTER DEFAULT PRIVILEGES FOR ROLE app_ddl_admin
  REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
```

---

## 9. 定義済みロール（Predefined Roles）

PostgreSQL 14以降に追加された、よく使われる権限のプリセット。

| 定義済みロール | 付与される権限 | 注意点 |
|-------------|-------------|--------|
| `pg_read_all_data` | クラスター全テーブル・ビュー・シーケンスへのSELECT | クラスターレベル（全DB） |
| `pg_write_all_data` | クラスター全テーブル・ビュー・シーケンスへのINSERT/UPDATE/DELETE | クラスターレベル（全DB）|
| `pg_monitor` | 各種監視ビュー（`pg_stat_*`等）へのアクセス | 運用チーム向け |
| `pg_read_all_settings` | すべての設定値の参照 | - |
| `pg_read_all_stats` | 統計情報ビューへのアクセス | - |
| `pg_signal_backend` | バックエンドへのシグナル送信（pg_cancel_backend等） | - |

```sql
-- 読み取り専用アプリユーザーに付与
GRANT pg_read_all_data TO app_read_only;

-- 書き込みアプリユーザーに付与
GRANT pg_write_all_data TO app_write_user;

-- 監視ツール用ユーザーに付与
GRANT pg_monitor TO monitoring_user;
```

> ⚠️ `pg_read_all_data` と `pg_write_all_data` は**既存のGRANT/REVOKE設定を無視**する。細かなアクセス制御が必要な場合は使用を避ける。

---

## 10. PUBLIC ロールの注意点

`PUBLIC` ロールはすべてのロールが自動的にメンバーになる特殊なロール。

### デフォルトで付与されている権限（PostgreSQL 15以降）

| 権限 | 対象 | 説明 |
|------|------|------|
| `CONNECT` | すべてのDB | デフォルトで全ロールがDBに接続可能 |
| `USAGE` | publicスキーマ | publicスキーマの使用 |
| `TEMPORARY` | すべてのDB | テンポラリテーブルの作成 |
| `EXECUTE` | 関数・プロシージャ | デフォルトで全関数が実行可能 |

> ⚠️ PostgreSQL 14以前では `public` スキーマへの `CREATE` 権限もPUBLICに付与されていた。15以降は削除されたが、旧バージョンからの移行時は注意が必要。

### セキュリティ強化のためのREVOKE（推奨）

```sql
-- PUBLICからすべての権限を剥奪してから必要なロールにのみ付与
REVOKE ALL ON DATABASE myapp FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM PUBLIC;

-- その後、明示的に必要なロールに付与
GRANT CONNECT ON DATABASE myapp TO app_users;
GRANT USAGE ON SCHEMA public TO app_users;
```

これにより、意図しないアクセスを防ぎ、**デフォルト拒否（Default Deny）** の原則を実現できる。
