# 認証・認可（Authentication & Authorization）

API セキュリティの第一防衛線は認証・認可である。入力検証・サニタイズ・クエリのパラメータ化といった他の対策は、そもそも「誰がアクセスしているか」を正しく検証できていなければ意味をなさない。本ファイルでは、JWT・OAuth 2.0・sender-constrained tokens・OpenID Connect・RBAC の標準と、それらを実装する際のパターンを扱う。

## Authentication と Authorization

**Authentication（認証）**は identity（ユーザーやサービスなどの主体）を検証するプロセス、**Authorization（認可）**はその identity が特定のリソースや操作へのアクセス権を持つかを検証するプロセスである。API アクセスは人間のユーザーだけでなく、アプリケーション・サービス・デバイスといった非人間 identity（M2M 通信、サードパーティ API 連携、自動化タスク）にも許可される。

認証・認可は API リクエストに含まれる**アクセストークン**によって成立する。トークンには不透明な(opaque)ものと、JWT のような構造化されたものがある。トークン以外にも以下の方式が実務で使われる。

| 方式 | 特徴 |
|------|------|
| アクセストークン | 短命・opaque または構造化 |
| API キー | 非人間 identity 向け・長期間有効（数週間〜数ヶ月）・失効とローテーションの仕組みが必須 |
| Cookie | Web アプリ向け・opaque/構造化どちらも可 |
| mTLS | TLS ハンドシェイク時にサーバー・クライアント双方の証明書で相互に身元を検証。エンタープライズの非人間 identity 認証に多用 |
| HMAC | クライアント・サーバー間の共有秘密鍵とハッシュ関数（例: SHA-256）でリクエスト要素（URL・payload・ヘッダ）のダイジェストを生成し認証 |
| SRP（secure remote password） | パスワードそのものを送らずハッシュと salt で知識証明する方式。マイナーだが強力 |

認可は2段階で構成される。

1. **トークンの妥当性検証**: フォーマット・有効期限・署名の正しさを確認する
2. **リソースアクセスの検証**: ユーザーが要求されたグループ/ロールに属し、必要なアクセススコープを持ち、当該リソース/操作の実行を許可されているかを確認する

この2段階の検証は**すべてのリクエストで**行う必要がある。例えば、患者・受付・医師という3種のユーザーロールを持つ医療アプリでは、医師が患者記録にアクセスするたびに「トークンは有効か」「医師ロールに属するか」「その患者データへのアクセス権があるか」の全てをチェックしなければならない。

## JWTの構造と検証

JSON Web Token（JWT、"ジョット"と発音）は API アクセストークンの最も一般的な標準（RFC 7519）。JWT は JSON オブジェクトをURLセーフに表現したもので、ユーザーの識別子・所属グループ・アクセス範囲などの情報（**claims**）を含む。

### ID トークン vs アクセストークン

- **ID トークン**: OpenID Connect の文脈で使う。主体が人間 identity の場合に発行され、氏名・メールアドレス等の個人情報（claims）を含む。**API アクセスの検証に使ってはならない**
- **アクセストークン**: ユーザーや非人間 identity が API にアクセスする権利についての claims を含む。API アクセス検証にはこちらを使う

### 構造（Header.Payload.Signature）

JWT は header・payload・signature の3要素を base64url エンコードし、ドットで連結したもの。

**Header（JOSE header）**: トークンのメタデータ。

| フィールド | 内容 |
|-----------|------|
| `typ` | メディアタイプ（`JWT`） |
| `alg` | 署名アルゴリズム |
| `kid` | 署名鍵/シークレットの ID |

**Payload**: RFC 7519 が定義する7つの登録済み claims（必須ではないが相互運用性のため推奨）。

| claim | 意味 |
|-------|------|
| `iss` (issuer) | トークンを発行した認可サーバー |
| `sub` (subject) | トークンの主体（ユーザーまたは M2M クライアント） |
| `aud` (audience) | トークンがアクセスを許可する API |
| `exp` (expiration) | 有効期限 |
| `nbf` (not before) | これより前は無効というタイムスタンプ |
| `iat` (issued at) | 発行時刻 |
| `jti` (JWT ID) | トークンの一意識別子 |

登録済み claims に加え、ロールやアクセススコープなど独自のカスタム claims を含められる。**カスタム claims には氏名・メールアドレス等の機微な個人情報を含めてはならない**。ユーザー識別子は `sub` claim で既に取得できており、追加情報が必要なら ID サービスに直接問い合わせる（OIDC の `UserInfo` エンドポイント等）べきである。理由は、アクセストークンが安全でない接続や CORS 誤設定・XSS 等で漏洩し得るため、含めた機微情報がそのまま攻撃者に渡ってしまうことにある。

**Signature**: header と payload を base64url エンコードし連結した文字列に署名アルゴリズムを適用した結果。トークンが改ざんされていないことを保証する。

### 署名アルゴリズムの選定

| アルゴリズム | 種別 | 特徴 |
|------------|------|------|
| HS256 (HMAC-SHA256) | 対称鍵 | 署名・検証に同一の秘密鍵を使うため鍵の漏洩リスクが高い |
| RS256 (RSA-SHA256) | 非対称鍵 | 広く普及しているが、実装不備があると署名偽造攻撃（2006年発見の Bleichenbacher 攻撃）に脆弱になり得る |
| PS256 / EdDSA / ECDSA | 非対称鍵（改良） | RS256 の既知の弱点を踏まえ、より堅牢な代替として推奨される |

非対称アルゴリズムは秘密鍵で署名し公開鍵で検証するため、鍵が複数箇所に存在する対称鍵方式より漏洩リスクが低い。秘密性の高い claims をトークンに含めたい場合は、署名だけでなく暗号化（JWE: JSON Web Encryption）を検討する。

### トークン検証のベストプラクティス

過去には JWT 検証の不備によるインシデントが繰り返し発生している（`alg` フィールドを `none` に書き換えて署名検証を回避する攻撃、対称/非対称アルゴリズムを混同させる algorithm confusion 攻撃など）。検証時は以下を徹底する。

- [ ] 必要な署名アルゴリズムをすべてサポートし、かつ広く使われている(コミュニティが大きい)実績あるライブラリを使う
- [ ] 既知の攻撃パターン（`none` アルゴリズム攻撃・algorithm confusion 攻撃）に対して自ライブラリをテストする
- [ ] **許容する署名アルゴリズムをコード側でハードコードする**（トークンヘッダの `alg` フィールドを信用しない）
- [ ] RS256 を使う場合、RSA 鍵の指数を高く・鍵長を最低 2048 ビット以上にする
- [ ] `iss`（発行者）・`aud`（対象オーディエンス）を含め、検証可能な claims はすべて検証する

## OAuth 2.0とOAuthフロー

OAuth はアクセス委譲（access delegation）のプロトコルであり、パスワードを共有せずに自分のデータへのアクセスを他アプリケーションに許可する仕組みを提供する。OAuth は以下の3概念で制約付きアクセスを実現する。

| 概念 | 役割 |
|------|------|
| Authorization flow（認可フロー） | クライアントアプリがユーザーのデータへアクセスする許可を得るプロセス。クライアントの制約に応じて複数のフローがある |
| Scopes（スコープ） | クライアントがアクセスを要求するデータ・操作の範囲 |
| Access token（アクセストークン） | 限られた期間・スコープでクライアントにアクセスを許可するトークン |

認可フローには4つの主体が登場する。

| 主体 | 役割 |
|------|------|
| Authorization server（認可サーバー） | ユーザー identity を管理しアクセストークンを発行するサーバー |
| Resource server（リソースサーバー） | ユーザーデータを保持しアクセスを制御するサーバー |
| Resource owner（リソースオーナー） | リソースサーバー上のデータを所有するユーザー |
| Client（クライアント） | リソースオーナーのデータにアクセスしようとするアプリケーション |

クライアントは、認証情報を安全に保管できる **confidential client**（Web サーバー等）と、ソースコードが公開され認証情報を安全に保管できない **public client**（Web/モバイルアプリ）に区別される。

### OAuth 2.1でサポートされる4フロー

| フロー | 用途 |
|--------|------|
| Authorization code flow | confidential client（Web サーバー等）向け。認可コードとアクセストークンを交換する |
| Client credentials flow | M2M 通信向け。CI/CD からの API 呼び出し、サードパーティ API との統合、マイクロサービス間通信等 |
| Device authorization grant | 入力制約デバイス（スマートTV等）・エージェントレスデバイス（IoT機器・プリンタ等）向け |
| Refresh token flow | アクセストークン失効後の再認可なしでの更新 |

> **廃止済みフロー**: OAuth 2.1 では **Implicit flow**（アクセストークンを URL 経由で渡すため漏洩リスクが高い）と **Resource owner password flow**（ユーザー認証情報をクライアントにそのまま渡すため危険）が非推奨化されている。

### Authorization code flow の要点

1. クライアントが認可 URL（`client_id` / `redirect_uri` / `response_type=code` を含む）へユーザーをリダイレクト
2. ユーザーが認可サーバーでログインし、クライアントへのアクセスを許可(consent)
3. 認可サーバーが `redirect_uri` へ **認可コード** を付けてリダイレクト
4. クライアントが認可コード + `client_id` + `client_secret` をアクセストークンに交換する

認可コードは一度きりの使用に限定するのがベストプラクティス。認可コード横取りによる **OAuth CSRF 攻撃**（`redirect_uri` の値が制約されず open redirect が可能な場合に成立）を防ぐため `state` パラメータを含めることが推奨される。

**PKCE（Proof of Key Exchange、RFC 7636）**: 認可コード横取り攻撃をさらに防ぐ仕組み。OAuth 2.1 では必須。

1. クライアントは高エントロピーな `code_verifier`（43〜128文字のランダム値）を生成
2. `code_verifier` を SHA-256 でハッシュし base64url エンコードした `code_challenge` を認可リクエストに含める
3. トークン交換時に `code_verifier` を提示し、認可サーバーが同じ方法でハッシュして `code_challenge` と一致するか検証する

### Client credentials flow

ブラウザを介さず、consent ステップも不要な単純な直接交換フロー。M2M 統合で、クライアントをあらかじめ認可サーバーに登録する際に権限と境界を定義しておく。

### Device authorization flow

デバイス（スマートTV等）が `device_code` / `end-user code` / 検証URL を認可サーバーから受け取り、ユーザーが別デバイス(スマホ等)で検証URLにアクセスしてログイン・認可する。デバイス側は認可サーバーをポーリングして完了を待つ。

### Refresh token flow

アクセストークンは通常 1〜24時間で失効する。リフレッシュトークンで再ログインなしにアクセスを更新する。漏洩時のリプレイ攻撃を防ぐため、認可サーバーは以下のいずれかを行う。

- **リフレッシュトークンローテーション**: 毎回新しいリフレッシュトークンを発行し、旧トークンは一度きりの使用に限定する（Web アプリの authorization code flow で一般的）
- **クライアントバインディング**: sender-constrained tokens の手法（後述）で M2M クライアントに紐付ける

## Sender-Constrained Tokens

アクセストークンが漏洩した場合、正規の所有者以外がそれを使ってなりすませてしまう。**Sender-constrained tokens** はトークンを正規の所有者に紐付けることでこのリスクを軽減する。OAuth 2.1 は2つの方式を規定する。

### mTLS による証明書バインド

TLS ハンドシェイク時にクライアント証明書の情報を認可サーバーが捕捉し、証明書のサムプリント（SHA-1ダイジェストの base64url エンコード）をアクセストークンの `cnf`（confirmation）claim に含める（`x5t#S256` メンバー、RFC 8705）。リソースサーバーは、TLS ハンドシェイクで得たクライアント証明書のサムプリントとトークン内の値を突き合わせて検証する。実装は堅牢だが、プロトコルレベルでの証明書情報捕捉とアプリケーション層への伝搬が必要なため難易度が高い。

### DPoP（Demonstrating Proof of Possession、RFC 9449）

クライアント生成の暗号鍵ペアでトークンを送信者に紐付けるより実装しやすい方式。

1. クライアントが署名鍵ペアを生成し、認可リクエストに公開鍵の JWK サムプリント（`dpop_jkt`）を含める
2. アクセストークン取得時、秘密鍵で署名した DPoP JWT（`typ: dpop+jwt`、HTTPメソッド `htm`・URI `htu`・一意識別子 `jti` を含む）をヘッダに含めて所有証明する
3. 認可サーバーは DPoP JWT の署名を JWK サムプリントで検証し、確認できればアクセストークンの `cnf.jkt` にサムプリントを紐付けて発行する
4. リソースサーバーへの以降のすべてのリクエストでも、新しく署名した DPoP JWT をヘッダに含める必要がある（DPoP JWT は一度きりの使用）

`jti` による再送検知と、リクエストごとに新規署名する仕組みにより、トークン漏洩時のリプレイを防止する。

## OpenID Connect

**OpenID Connect（OIDC）**は OAuth 2.0 の上に構築された認証プロトコルで、あるサイトの identity を別サイトへ持ち込む仕組みを提供する（外部アカウントでの新規サイトへのログインなど）。OIDC の認証フローには以下の主体が登場する。

| 主体 | 役割 |
|------|------|
| OpenID Provider（OP）/ IdP | ユーザー identity を管理・認証するサーバー（OAuth の認可サーバーに相当） |
| Relying Party（RP） | 認証を外部 IdP に委ねるクライアントアプリケーション。IdP へ事前登録が必要 |
| User | RP が identity を検証しようとするユーザー（OAuth のリソースオーナーに相当） |

フローは OAuth の認可リクエストに似ているが、スコープに `openid` を含める点が異なり、結果として ID トークン（＋任意でアクセストークン）を得る。

ID トークンのペイロードには RFC 7519 の登録済み claims に加え、以下のような認証プロセス・ユーザー識別情報の claims が含まれる。

| claim | 内容 |
|-------|------|
| `auth_time` | ユーザーがログインした時刻（UTC） |
| `acr` | 認証時に使われた認証コンテキストクラス（認証強度のレベル）を示すURI |
| `amr` | 認証手段の配列（例: パスワード認証は `pwd`、ワンタイムパスワードは `otp`） |
| `azp` | ID トークンの発行対象クライアント（client_id と一致） |
| `name` / `email` / `picture` 等 | ユーザー識別情報。ID トークンに不足する場合は OP の `UserInfo` エンドポイントに問い合わせる |

相互運用性を高めるため、OIDC は **discovery**（`/.well-known/openid-configuration`）というエンドポイントを標準化している。ここには `claims_supported`・`userinfo_endpoint`・`authorization_endpoint`・`token_endpoint`・署名検証鍵の一覧を提供する `jwks_uri` 等、統合に必要な情報がすべて含まれる。

## RBAC（ロールベースアクセス制御）

**RBAC（Role-Based Access Controls）**はユーザーロールに基づく認可チェックである。ロールはアプリケーションへのアクセスレベルを定義する権限の集合を表し、多くの場合アプリケーションのユーザー種別に対応する（例: 患者・受付・医師）。

一般的な実装は、ユーザーロールをトークンのペイロードにカスタム claim（例: `permissions`、`roles`）として含める方式である。ログイン時に IdP がユーザーのロールを把握し、アクセストークンに含める。API サーバーは操作ごとに、期待するロールがトークンに含まれているかを検証する。**すべての API・操作でロールチェックを行わないと BFLA（Broken Function-Level Authorization）に繋がる**。

### 粒度モデルの選択

| モデル | 特徴 | 弱点 |
|--------|------|------|
| ロール（RBAC） | ユーザー種別ごとの権限集合。単純で管理しやすい | 粒度が粗くなりがち |
| granular access scopes（細粒度アクセススコープ） | エンドポイント単位でアクセス可否をトークンに明示。動的な権限管理に向く | (1) 各ユーザーの権限リスト更新の手間 (2) セキュリティ構成の詳細露出リスク (3) リストが長大化しトークンサイズ・HTTPヘッダ上限に影響し得る |
| ABAC（属性ベースアクセス制御） | ユーザー属性（職務・地域・プロジェクト所属等）をDBで管理し動的判定。トークンへの権限埋め込み不要 | 実装が複雑化しやすく、暗黙の前提が入り込むとテスト・検証が困難になる |

長大な権限リストは「ロールへの集約を検討すべき」というコードスメルである。柔軟性とシンプルさのバランスを取り、ABAC を採用する場合は前提を排した明示的で詳細なアクセスモデルを設計すること。

## 実装パターン（外部IdP連携・トークン検証・認可ミドルウェア）

### OpenAPI によるセキュリティ定義

OpenAPI はセキュリティスキームで API の保護方式を記述する。`components.securitySchemes` で定義し、仕様全体のトップレベル `security` またはオペレーション単位の `security` で適用する（オペレーションレベルの指定はグローバル設定を上書きする）。

```yaml
components:
  securitySchemes:
    JWTBearer:
      description: Bearer JSON Web Token
      type: http
      scheme: Bearer
      bearerFormat: JWT
security:
  - JWTBearer: []
paths:
  /public-endpoint:
    get:
      security: []          # このエンドポイントのみ認証を無効化
```

OpenAPI 3 は `http`（Basic/Bearer）・`apiKey`・`oauth2`・`openIdConnect`・`mutualTLS` の5種のセキュリティスキームをサポートする。

### JWT の発行

1. ペイロードに登録済み claims（`iss` / `sub` / `aud` / `iat` / `exp`）と必要なカスタム claims を設定する
2. 非対称鍵で署名する場合は事前に鍵ペアを生成する（例: `openssl genpkey -algorithm RSA -out private_key.pem -outpubkey public_key.pem -pkeyopt rsa_keygen_bits:3072`。RFC 7518 は最低2048ビットを要求）
3. 秘密鍵と署名アルゴリズム（PS256 / EdDSA 等の非対称アルゴリズムを推奨）でトークンを署名する

```python
# 概念パターン: JWTライブラリでの署名（言語・ライブラリは環境に応じ選定）
payload = {
    "iss": issuer_url,
    "sub": user_id,
    "aud": api_audience,
    "iat": now,
    "exp": now + expiry_delta,
}
token = jwt_library.encode(payload=payload, key=private_key, algorithm="PS256")
```

### JWT の検証

対称鍵の場合は共有シークレット、非対称鍵の場合は公開鍵を読み込んで検証する。許容アルゴリズム・`audience`・`issuer` は必ず明示的に指定する。

```python
# 概念パターン: JWTライブラリでの検証
def validate_token(token, audience):
    return jwt_library.decode(
        jwt=token,
        key=signing_key,             # 対称鍵 or 公開鍵オブジェクト
        algorithms=["PS256"],        # 許容アルゴリズムをハードコード
        audience=audience,
        issuer=expected_issuer,
    )
```

### 外部IdP連携

自前でトークン発行基盤を構築するのはリスクが高いため、外部 IdP（Identity Provider・IDaaS）へ認証を委譲するのが一般的である。外部 IdP を使う場合、統合手順は概ね以下の流れになる。

1. **アプリケーション登録**: 外部 IdP の管理コンソールで API（リソースサーバー）とクライアントアプリケーションを登録し、クライアントID・クライアントシークレットを発行してもらう
2. **コールバック URI 設定**: 認可コード受け取り先の `redirect_uri` を登録する
3. **スコープ・権限（permission）設定**: API 側で許可する操作単位のスコープや、ロールに対応する permission を定義する
4. **discovery エンドポイント確認**: `https://<外部IdPのドメイン>/.well-known/openid-configuration` から authorization endpoint・token endpoint・JWKS endpoint を取得する
5. **認可コードフローの実装**:
   - `GET /login` でユーザーを外部 IdP の authorization endpoint（`response_type=code` / `client_id` / `redirect_uri` / 必要な `audience` 付き）へリダイレクトする
   - コールバックで受け取った認可コードを、`client_id` / `client_secret` とともに token endpoint へ `POST`（`application/x-www-form-urlencoded`）し、アクセストークンを取得する
6. **リフレッシュトークンの有効化**（必要な場合）: オフラインアクセスやリフレッシュトークンローテーションを IdP 側の設定で有効化する
7. **ロール・権限の払い出し**: 管理者ロール等が必要な場合、外部 IdP のユーザー管理機能でユーザーにロール/permission を割り当てる。多くの IdP はこれをアクセストークンの custom claim（例: `permissions` や `roles`）として自動的に埋め込む

### JWKS によるトークン検証（外部IdP発行トークン）

外部 IdP が発行したトークンは自前の公開鍵を持たないため、IdP の discovery エンドポイントが公開する **JWKS（JSON Web Key Set）エンドポイント**（`jwks_uri`）から検証鍵を取得する。

1. トークンヘッダの `kid` フィールドから使用された鍵の ID を取得する
2. JWKS エンドポイントのレスポンス（鍵の配列）から一致する `kid` の JWK を探す
3. JWK から公開鍵を構築し、署名検証に使う

```python
# 概念パターン: JWKSエンドポイントからの鍵取得と検証
jwks_client = JWKSClient(jwks_endpoint_url)

def validate_external_token(token, audience):
    signing_key = jwks_client.get_signing_key_from_jwt(token)
    return jwt_library.decode(
        jwt=token,
        key=signing_key,
        algorithms=["RS256"],
        audience=audience,
        issuer=expected_issuer,
    )
```

### 認可ミドルウェア

トークン検証はすべてのリクエストに共通する処理のため、個々のエンドポイントに埋め込むのではなく、ミドルウェアや依存性注入(dependency injection)の仕組みで一元化する。

```python
# 概念パターン: 依存性注入によるBearerトークン検証ミドルウェア
def authorize_access(credentials):
    try:
        return validate_token(token=credentials.token, audience=api_audience)
    except TokenError as error:
        raise UnauthorizedError(detail=str(error))

# 保護したいエンドポイントに authorize_access を依存として注入する
```

> **API ゲートウェイとの役割分担**: API ゲートウェイ（後述の INFRA-FAPI-OBS-TESTING.md 参照）がトークン検証を肩代わりできる場合でも、ゲートウェイ側の不具合やカスタム claim 検証の限界に備え、アプリケーション側にも検証ロジックを持たせるのが安全である。

### RBAC の実装パターン

ロール・権限単位でエンドポイントを保護する場合、通常の認可ミドルウェアに加えて「トークンの `permissions`（または `roles`）claim に必要な値が含まれるか」を検証する層を追加する。

```python
# 概念パターン: 管理者ロール限定の認可チェック
def authorize_admin_access(credentials):
    claims = validate_token(credentials.token, audience=admin_api_audience)
    if "admin" not in claims.get("permissions", []):
        raise ForbiddenError(detail="admin role required")
    return claims

# 管理者専用エンドポイントに authorize_admin_access を依存として注入する
```

管理者専用 API を用意する場合は、一般ユーザー向けクライアントとは別の管理者専用クライアント（別の `client_id` / `client_secret`）を IdP 側に登録し、管理者用ログインフローを分離しておくと、通常ユーザーが誤って管理者スコープの認可リクエストを行う経路自体を排除できる。
