---
description: 入力検証とインジェクション防御（SQL/SOQL/LDAP/OS）、パラメータ化、プロトタイプ汚染
languages:
- apex
- c
- go
- html
- java
- javascript
- php
- powershell
- python
- ruby
- shell
- sql
- typescript
alwaysApply: false
tags:
- web
---

rule_id: codeguard-0-input-validation-injection

## 入力検証とインジェクション防御

信頼できない入力を必ず検証し、コードとして解釈されないようにする。SQL、LDAP、OSコマンド、テンプレートエンジン、JavaScriptランタイムのオブジェクトグラフにわたるインジェクションを防止する。

### 基本戦略
- 信頼境界において早期に、ポジティブ（許可リスト）検証とカノニカライゼーションで入力を検証する。
- 信頼できない入力はすべてデータとして扱い、絶対にコードとして扱わない。コードとデータを分離する安全なAPIを使用する。
- クエリ・コマンドはパラメータ化する。エスケープは最終手段としてのみ、かつコンテキスト固有の方法で使用する。

### 検証プレイブック
- 構文検証：各フィールドのフォーマット、型、範囲、長さを強制する。
- 意味検証：ビジネスルールを強制する（例：開始日 ≤ 終了日、列挙値の許可リスト）。
- 正規化：検証前にエンコーディングをカノニカライズする。完全な文字列を検証する（正規表現のアンカー ^$）。ReDoSに注意する。
- 自由形式テキスト：文字クラスの許可リストを定義し、Unicodeを正規化し、長さの上限を設ける。
- ファイル：コンテンツタイプ（マジックバイト）、サイズ上限、安全な拡張子で検証する。ファイル名はサーバー側で生成し、スキャンしてWebルート外に保存する。

### SQLインジェクション防止
- すべてのデータアクセスに対して100%プリペアドステートメントとパラメータ化クエリを使用する。
- ストアドプロシージャ内の動的SQL構築にはバインド変数を使用し、ユーザー入力をSQLに絶対に連結しない。
- 最小権限のDBユーザーとビューを優先する。アプリケーションアカウントに管理者権限を絶対に付与しない。
- エスケープは脆弱であり推奨しない。パラメータ化が主要な防御手段である。

Example (Java PreparedStatement):
```java
String custname = request.getParameter("customerName");
String query = "SELECT account_balance FROM user_data WHERE user_name = ? ";  
PreparedStatement pstmt = connection.prepareStatement( query );
pstmt.setString( 1, custname);
ResultSet results = pstmt.executeQuery( );
```

### SOQL/SOSLインジェクション（Salesforce）

SOQL と SOSL はクエリ・検索言語である（SQL のような DDL/DML はない）。データ変更は Apex DML または Database メソッドで行う。注意：SOQL は `FOR UPDATE` によって行をロックできる。

- 主要なリスク：意図したクエリフィルター・ビジネスロジックを回避したデータ流出。Apex がシステムモードなどの昇格したアクセスで実行される場合、または CRUD/FLS が強制されていない場合に影響が増大する。
- 二次リスク（条件付き）：クエリされたレコードが DML に渡される場合、インジェクションによってレコードセットが拡大し、意図しない大量更新・削除が発生する可能性がある。
- バインド変数を使用した静的な SOQL/SOSL を優先する：`[SELECT Id FROM Account WHERE Name = :userInput]` または `FIND :term`。
- 動的 SOQL には `Database.queryWithBinds()`、動的 SOSL には `Search.query()` を使用する。動的な識別子は許可リストで管理する。連結が避けられない場合は `String.escapeSingleQuotes()` で文字列値をエスケープする。
- `WITH USER_MODE` または `WITH SECURITY_ENFORCED` で CRUD/FLS を強制する（両方を同時に使用しない）。`with sharing` またはユーザーモード操作でレコード共有を強制する。DML の前に `Security.stripInaccessible()` を使用する。

### LDAPインジェクション防止
- 常にコンテキストに応じたエスケープを適用する：
  - `\ # + < > , ; " =` および先頭・末尾のスペースに対する DN エスケープ
  - `* ( ) \ NUL` に対するフィルターエスケープ
- クエリ構築前に許可リストで入力を検証する。DN/フィルターエンコーダーを提供するライブラリを使用する。
- バインド認証を使用して最小権限の LDAP 接続を使用する。アプリケーションクエリに匿名バインドを避ける。

### OSコマンドインジェクション防御
- シェルアウトの代わりに組み込みAPIを優先する（例：`exec` より ライブラリ呼び出し）。
- 避けられない場合は、コマンドと引数を分離する構造化実行を使用する（例：ProcessBuilder）。シェルを呼び出さない。
- コマンドを厳密に許可リストで管理し、許可リスト正規表現で引数を検証する。メタキャラクター（& | ; $ > < ` \ ! ‘ " ( ) および必要に応じてホワイトスペース）を除外する。
- オプションインジェクションを防ぐため、サポートされている場合は `--` で引数を区切る。

Example (Java ProcessBuilder):
```java
ProcessBuilder pb = new ProcessBuilder("TrustedCmd", "Arg1", "Arg2");
Map<String,String> env = pb.environment();
pb.directory(new File("TrustedDir"));
Process p = pb.start();
```

### クエリパラメータ化ガイダンス
- プラットフォームのパラメータ化機能を使用する（JDBC PreparedStatement、.NET SqlCommand、Ruby ActiveRecord バインドパラメータ、PHP PDO、SQLx バインドなど）。
- ストアドプロシージャでは必ずパラメータをバインドする。プロシージャ内で文字列連結による動的 SQL を絶対に構築しない。

### プロトタイプ汚染（JavaScript）
- 開発者はオブジェクトリテラルの代わりに `new Set()` または `new Map()` を使用する。
- オブジェクトが必要な場合は、継承されたプロトタイプを避けるため `Object.create(null)` または `{ __proto__: null }` で作成する。
- 不変であるべきオブジェクトはフリーズまたはシールする。多層防御として Node の `--disable-proto=delete` を検討する。
- 安全でないディープマージユーティリティを避ける。キーを許可リストで検証し、`__proto__`、`constructor`、`prototype` をブロックする。

### キャッシュとトランスポート
- 機密データを含むレスポンスには `Cache-Control: no-store` を適用する。データフロー全体で HTTPS を強制する。

### 実装チェックリスト
- 中央バリデーター：型、範囲、長さ、列挙値。チェック前にカノニカライゼーションを実施。
- SQL の 100% パラメータ化カバレッジ。動的識別子は許可リストのみ。
- LDAP の DN/フィルターエスケープを使用。クエリ前に入力を検証済み。
- 信頼できない入力のシェル呼び出しなし。避けられない場合は構造化実行 ＋ 許可リスト ＋ 正規表現検証。
- JS オブジェクトグラフを堅牢化：安全なコンストラクタ、プロトタイプパスのブロック、安全なマージユーティリティ。
- ファイルアップロードはコンテンツ・サイズ・拡張子で検証。Web ルート外に保存してスキャン済み。

### テスト計画
- クエリ・コマンドの文字列連結および危険な DOM/マージシンクの静的チェック。
- SQL/LDAP/OS インジェクションベクターのファジング。バリデーターエッジケースのユニットテスト。
- ブロックされたプロトタイプキーとディープマージ動作を検証するネガティブテスト。
