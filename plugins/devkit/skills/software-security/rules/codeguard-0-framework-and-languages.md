---
description: フレームワーク・言語別セキュリティガイド（Django/DRF、Laravel/Symfony/Rails、.NET、Java/JAAS、Node.js、PHP設定）
languages:
- c
- java
- javascript
- kotlin
- php
- python
- ruby
- typescript
- xml
- yaml
alwaysApply: false
---

rule_id: codeguard-0-framework-and-languages

## フレームワーク・言語ガイド

各プラットフォームにセキュアバイデフォルトのパターンを適用する。設定を堅牢化し、組み込み保護機能を活用し、よくある落とし穴を避けること。

### Django
- 本番環境ではDEBUGを無効化する。Djangoおよび依存ライブラリを常に最新に保つ。
- `SecurityMiddleware`、クリックジャッキング対策ミドルウェア、MIMEスニッフィング保護を有効化する。
- HTTPS強制（`SECURE_SSL_REDIRECT`）、HSTS設定、セキュアなCookieフラグ（`SESSION_COOKIE_SECURE`、`CSRF_COOKIE_SECURE`）を設定する。
- CSRF: `CsrfViewMiddleware`とフォーム内の`{% csrf_token %}`を確実に使用し、AJAXのトークン処理も適切に行う。
- XSS: テンプレートの自動エスケープに依存し、信頼できるデータ以外には`mark_safe`を使わず、JSには`json_script`を使用する。
- 認証: `django.contrib.auth`を使用し、`AUTH_PASSWORD_VALIDATORS`でバリデーターを設定する。
- 機密情報: `get_random_secret_key`で生成し、環境変数またはシークレットマネージャーに保存する。

### Django REST Framework (DRF)
- `DEFAULT_AUTHENTICATION_CLASSES`と制限的な`DEFAULT_PERMISSION_CLASSES`を設定する。保護されたエンドポイントに`AllowAny`を絶対に残してはならない。
- オブジェクトレベルの認可には常に`self.check_object_permissions(request, obj)`を呼び出す。
- シリアライザー: 明示的な`fields=[...]`を使用し、`exclude`や`"__all__"`は避ける。
- スロットリング: レート制限を有効化する（ゲートウェイ/WAFとの併用も可）。
- 不要なHTTPメソッドは無効化する。生のSQLは避け、ORM/パラメーターバインドを使用する。

### Laravel
- 本番環境: `APP_DEBUG=false`、アプリケーションキーを生成し、ファイルパーミッションを適切に設定する。
- Cookie/セッション: 暗号化ミドルウェアを有効化し、`http_only`、`same_site`、`secure`フラグと短い有効期限を設定する。
- マスアサインメント: `$request->only()` / `$request->validated()`を使用し、`$request->all()`は避ける。
- SQLインジェクション: Eloquentのパラメーター化を使用し、動的識別子を検証する。
- XSS: Bladeのエスケープに依存し、信頼できないデータには`{!! ... !!}`を使わない。
- ファイルアップロード: `file`、サイズ、`mimes`を検証し、`basename`でファイル名をサニタイズする。
- CSRF: ミドルウェアとフォームトークンが有効になっていることを確認する。

### Symfony
- XSS: Twigの自動エスケープを使用し、信頼できるデータ以外には`|raw`を避ける。
- CSRF: 手動フローには`csrf_token()`と`isCsrfTokenValid()`を使用する。Formsはデフォルトでトークンを含む。
- SQLインジェクション: Doctrineのパラメーター化クエリを使用し、入力値を絶対に連結してはならない。
- コマンド実行: `exec/shell_exec`を避け、Filesystemコンポーネントを使用する。
- アップロード: `#[File(...)]`で検証し、publicディレクトリ外に保存し、ユニークなファイル名を使用する。
- ディレクトリトラバーサル: `realpath`/`basename`を検証し、許可されたルートを強制する。
- セッション/セキュリティ: セキュアなCookieと認証プロバイダー/ファイアウォールを設定する。

### Ruby on Rails
- 以下の危険な関数を避ける:

```ruby
eval("ruby code here")
system("os command here")
`ls -al /` # (backticks contain os command)
exec("os command here")
spawn("os command here")
open("| os command here")
Process.exec("os command here")
Process.spawn("os command here")
IO.binread("| os command here")
IO.binwrite("| os command here", "foo")
IO.foreach("| os command here") {}
IO.popen("os command here")
IO.read("| os command here")
IO.readlines("| os command here")
IO.write("| os command here", "foo")
```

- SQLインジェクション: 常にパラメーター化を行い、LIKEパターンには`sanitize_sql_like`を使用する。
- XSS: デフォルトの自動エスケープを維持し、信頼できないデータには`raw`、`html_safe`を使わず、`sanitize`の許可リストを使用する。
- セッション: 機密性の高いアプリにはデータベースバックのストアを使用し、HTTPS強制（`config.force_ssl = true`）を設定する。
- 認証: DeviseまたはProvenなライブラリを使用し、ルートと保護エリアを設定する。
- CSRF: 状態変更アクションには`protect_from_forgery`を使用する。
- セキュアなリダイレクト: リダイレクト先を検証し許可リストに登録する。
- ヘッダー/CORS: セキュアなデフォルトを設定し、`rack-cors`を慎重に構成する。

### .NET (ASP.NET Core)
- ランタイムとNuGetパッケージを最新に保ち、CIでSCAを有効化する。
- 認可: `[Authorize]`属性を使用し、サーバーサイドで確認を行い、IDORを防止する。
- 認証/セッション: ASP.NET Identityを使用し、アカウントロックアウト、Cookie の`HttpOnly`/`Secure`フラグ、短いタイムアウトを設定する。
- 暗号: パスワードにはPBKDF2、暗号化にはAES‑GCM、ローカルシークレットにはDPAPIを使用し、TLS 1.2以上を強制する。
- インジェクション: SQL/LDAPはパラメーター化し、許可リストで検証する。
- 設定: HTTPSリダイレクトを強制し、バージョンヘッダーを除去し、CSP/HSTS/X‑Content‑Type‑Optionsを設定する。
- CSRF: 状態変更アクションにはアンチフォージェリートークンを使用し、サーバーサイドで検証する。

### Java と JAAS
- SQL/JPA: `PreparedStatement`/名前付きパラメーターを使用し、入力値を絶対に連結してはならない。
- XSS: 許可リストによる検証、信頼できるライブラリによる出力サニタイズ、コンテキストに応じたエンコードを行う。
- ロギング: ログインジェクションを防ぐためにパラメーター化ロギングを使用する。
- 暗号: AES‑GCM、セキュアなランダムnonce を使用し、キーを絶対にハードコードせず、KMS/HSMを使用する。
- JAAS: `LoginModule`スタンザを設定し、`initialize/login/commit/abort/logout`を実装し、認証情報の露出を避け、パブリック/プライベートの認証情報を分離し、サブジェクトのプリンシパルを適切に管理する。

### Node.js
- リクエストサイズを制限し、入力を検証・サニタイズし、出力をエスケープする。
- ユーザー入力に対して`eval`や`child_process.exec`を避け、ヘッダーには`helmet`、パラメーター汚染には`hpp`を使用する。
- 認証エンドポイントにレート制限を設け、イベントループの健全性を監視し、未捕捉例外をきれいに処理する。
- Cookie: `secure`、`httpOnly`、`sameSite`を設定し、`NODE_ENV=production`を設定する。
- パッケージを最新に保ち、`npm audit`を実行し、セキュリティリンターとReDoSテストを使用する。

### PHP 設定
- 本番環境のphp.ini: `expose_php=Off`、エラーはログに記録して表示しない、`allow_url_fopen/include`を制限し、`open_basedir`を設定する。
- 危険な関数を無効化し、セッションCookieフラグ（`Secure`、`HttpOnly`、`SameSite=Strict`）を設定し、厳格なセッションモードを有効化する。
- アップロードサイズ/件数を制限し、リソース制限（メモリ、POSTサイズ、実行時間）を設定する。
- Snuffleupagusまたは類似ツールを使用して追加の堅牢化を行う。

### 実装チェックリスト
- 各フレームワーク組み込みのCSRF/XSS/セッション保護とセキュアなCookieフラグを使用する。
- すべてのデータアクセスをパラメーター化し、信頼できない入力に対して危険なOS/exec関数を避ける。
- HTTPS/HSTSを強制し、セキュアなヘッダーを設定する。
- 機密情報管理を一元化し、シークレットを絶対にハードコードせず、本番環境ではデバッグを無効化する。
- リダイレクトと動的識別子を検証・許可リスト化する。
- 依存関係とフレームワークを最新に保ち、SCAと静的解析を定期的に実行する。
