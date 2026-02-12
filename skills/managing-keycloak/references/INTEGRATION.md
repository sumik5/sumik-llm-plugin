# Keycloak アプリケーション統合

## 統合アーキテクチャの選択

### 統合スタイル

アプリケーション統合には2つの主要なスタイルが存在する：

| スタイル | 説明 | 統合場所 | 適用ケース |
|---------|------|---------|----------|
| **Embedded（組込型）** | ライブラリ・フレームワーク統合 | アプリケーション内部 | 単一アプリ、自己完結型システム |
| **Proxied（プロキシ型）** | リバースプロキシ・ゲートウェイ統合 | アプリケーション外部 | レガシーシステム、マルチアプリ環境 |

#### Embedded統合の特徴

- サードパーティライブラリ・フレームワークによる統合
- アプリケーション自身がOIDCリクエスト・レスポンスを直接処理
- 設定変更時はアプリケーション再デプロイ必須
- シンプルで自己完結的、フレームワークの機能を最大限活用可能

#### Proxied統合の特徴

- アプリケーションとKeycloakの間に中間レイヤー（プロキシ）が介在
- プロキシがOIDCリクエスト・レスポンスを代理処理
- アプリケーションはHTTPヘッダーからトークン・セキュリティデータを取得
- 統合コード・設定は外部サービスで管理、レガシーコード対応に最適

### 統合オプション選定基準

良好な統合実装の要件：

1. **広範な採用・活発なメンテナンス**: 強力なコミュニティバックアップ
2. **最新仕様準拠**: OAuth2・OIDC最新バージョン対応
3. **セキュリティベストプラクティス準拠**: PKCE、適切なトークン管理等
4. **優れたUX**: シンプルな設定、簡単なデプロイ
5. **適切な抽象化**: 詳細を隠蔽しつつセキュアなデフォルト提供
6. **ベンダーロックイン回避**: 標準準拠、移植性の高い実装

---

## アダプター選択ガイド

| アダプター種別 | 適用環境 | プロトコル | 状態管理 | 推奨ケース |
|------------|---------|----------|---------|----------|
| **Java Servlet Adapter** | Tomcat、Jetty、Java EE | OIDC/SAML | サーバーサイドセッション | エンタープライズJavaアプリ、レガシーServlet |
| **Node.js Adapter** | Express、Node.js環境 | OIDC | express-session | 軽量REST API、マイクロサービス |
| **Spring Boot Adapter** | Spring Boot 2.x/3.x | OIDC | Spring Security統合 | モダンJavaアプリ、RESTful API |
| **Generic OIDC** | 任意の言語・フレームワーク | OIDC | 自前実装 | 多言語環境、カスタムロジック |

### 選択判断基準

1. **Java Servlet Adapter**: 既存Java EEアプリケーション、Tomcat/Jetty上のServletベースアプリ
2. **Node.js Adapter**: Express.js中心のNode.js環境、軽量APIサーバー
3. **Spring Boot Adapter**: Spring Bootエコシステム、Spring Securityとの統合
4. **Generic OIDC**: 上記以外の言語（Python、Go、Ruby等）、カスタム要件

---

## Java Servlet Adapter

### 概要

Servlet環境でのKeycloak統合。Servlet Filter/Listenerを利用してOIDC/SAML認証を実装。

### 依存関係設定

```xml
<!-- pom.xml -->
<dependency>
    <groupId>org.keycloak</groupId>
    <artifactId>keycloak-servlet-adapter</artifactId>
    <version>20.0.1</version>
</dependency>
<dependency>
    <groupId>org.keycloak</groupId>
    <artifactId>keycloak-tomcat-adapter</artifactId>
    <version>20.0.1</version>
</dependency>
```

### web.xml設定

```xml
<!-- web.xml -->
<filter>
    <filter-name>Keycloak Filter</filter-name>
    <filter-class>org.keycloak.adapters.servlet.KeycloakOIDCFilter</filter-class>
</filter>
<filter-mapping>
    <filter-name>Keycloak Filter</filter-name>
    <url-pattern>/*</url-pattern>
</filter-mapping>

<listener>
    <listener-class>org.keycloak.adapters.servlet.KeycloakOIDCFilter</listener-class>
</listener>

<login-config>
    <auth-method>BASIC</auth-method>
    <realm-name>myrealm</realm-name>
</login-config>

<security-constraint>
    <web-resource-collection>
        <web-resource-name>Protected Resources</web-resource-name>
        <url-pattern>/secure/*</url-pattern>
    </web-resource-collection>
    <auth-constraint>
        <role-name>user</role-name>
    </auth-constraint>
</security-constraint>
```

### 特徴

- Servlet仕様準拠のFilter/Listener統合
- 複数認証方式対応（Form-based、Basic）
- SSO・Logout伝播サポート

---

## Node.js Adapter

### 概要

`keycloak-connect`パッケージを使用したExpress.js統合。middlewareベースのOIDC認証。

### インストール

```bash
npm install express express-session keycloak-connect
```

### Express統合コード

```javascript
const express = require('express');
const session = require('express-session');
const Keycloak = require('keycloak-connect');

const app = express();

// Session設定
app.use(session({
  secret: 'mySecret',
  resave: false,
  saveUninitialized: true,
  cookie: { secure: false }
}));

// Keycloak初期化
const memoryStore = new session.MemoryStore();
const keycloak = new Keycloak({ store: memoryStore });

app.use(keycloak.middleware());

// Public endpoint
app.get('/', (req, res) => {
  res.send('Hello, this is a public endpoint.');
});

// Secured endpoint
app.get('/secure', keycloak.protect(), (req, res) => {
  res.send('You have accessed a secured endpoint.');
});

const port = 3000;
app.listen(port, () => {
  console.log(`Server running on http://localhost:${port}`);
});
```

### Session管理

- **開発環境**: `MemoryStore`
- **本番環境**: Redis、Memcachedなど永続化ストア推奨

### 特徴

- Express.jsとのシームレスな統合
- `keycloak.protect()`でルート単位の保護
- JWT自動検証

---

## Spring Boot統合

### 概要

Spring SecurityとKeycloakの統合。`keycloak-spring-boot-starter`を使用。

### 依存関係設定

```xml
<!-- pom.xml -->
<dependency>
    <groupId>org.keycloak</groupId>
    <artifactId>keycloak-spring-boot-starter</artifactId>
    <version>19.0.1</version>
</dependency>
```

### application.properties設定

```properties
spring.security.oauth2.client.provider.keycloak.issuer-uri=http://localhost:8080/realms/{your-realm}
spring.security.oauth2.client.registration.keycloak.client-id={your-client-id}
spring.security.oauth2.client.registration.keycloak.client-secret={your-client-secret}
spring.security.oauth2.client.registration.keycloak.scope=openid,profile,email
```

### Security設定

```java
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.web.SecurityFilterChain;

@SpringBootApplication
public class DemoApplication {
    public static void main(String[] args) {
        SpringApplication.run(DemoApplication.class, args);
    }

    @EnableWebSecurity
    public class SecurityConfig {
        public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
            http
                .authorizeRequests(auth -> auth
                    .antMatchers("/public").permitAll()
                    .anyRequest().authenticated()
                )
                .oauth2Login()
                .and()
                .oauth2ResourceServer().jwt();
            return http.build();
        }
    }
}
```

### コントローラ例

```java
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class DemoController {
    @GetMapping("/public")
    public String publicEndpoint() {
        return "This is a public endpoint.";
    }

    @GetMapping("/secure")
    public String secureEndpoint() {
        return "This is a secured endpoint. User is authenticated.";
    }
}
```

### 特徴

- Spring Securityとの深い統合
- `oauth2Login()`による自動リダイレクト
- JWT Resource Server対応

---

## Admin REST API

### 概要

プログラマティックなRealm/User/Client管理。自動化・CI/CDパイプライン統合に最適。

### アクセストークン取得

```bash
# Step 1: トークン取得（admin-cli）
TOKEN=$(curl -X POST "http://localhost:8080/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=admin-cli&username=admin&password=admin&grant_type=password" | jq -r .access_token)
```

### 主要エンドポイント

#### Realm作成

```bash
curl -X POST "http://localhost:8080/admin/realms" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "realm": "new-realm",
    "enabled": true
  }'
```

#### User取得

```bash
curl -X GET "http://localhost:8080/admin/realms/{realm}/users/{user_id}" \
  -H "Authorization: Bearer $TOKEN"
```

**Response:**
```json
{
  "id": "user_id",
  "username": "john.doe",
  "attributes": {
    "employeeId": ["12345"],
    "department": ["IT"]
  }
}
```

#### Client登録

```bash
curl -X POST "http://localhost:8080/admin/realms/{realm}/clients" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "clientId": "my-client",
    "enabled": true,
    "protocol": "openid-connect",
    "redirectUris": ["http://localhost:3000/*"]
  }'
```

### REST API活用パターン

- CI/CDパイプラインでのRealm自動構成
- ユーザー一括登録・削除スクリプト
- Role/Permission管理自動化

---

## User Info Endpoint

### 概要

OIDC標準のUserInfoエンドポイント。アクセストークンを使用してユーザープロファイル情報を取得。

### リクエスト例

```bash
curl -X GET "https://<keycloak-server>/auth/realms/<realm-name>/protocol/openid-connect/userinfo" \
  -H "Authorization: Bearer {token}"
```

### レスポンス例

```json
{
  "sub": "248289761001",
  "name": "John Doe",
  "given_name": "John",
  "family_name": "Doe",
  "preferred_username": "johndoe",
  "email": "johndoe@example.com"
}
```

### 活用シーン

- ユーザープロファイル取得
- アプリケーション内でのパーソナライズ
- 動的UI表示（ユーザー名表示等）

---

## IdP Role Mapping

### 概要

外部IdP（SAML、OIDC）からのロールをKeycloak内部ロールにマッピング。

### SAML Role Mapper設定

```bash
kcadm.sh create identity-provider/instances/<provider-id>/mappers \
  -r <realm-name> \
  -s name=<mapper-name> \
  -s identityProviderMapper=saml-role-idp-mapper \
  -s config.role='<external-role>' \
  -s config.roleAttributeName='<keycloak-role>'
```

### ユースケース

- 外部IdPの`employee`ロールをKeycloakの`user`ロールにマッピング
- LDAP/AD groupをKeycloak realm roleに変換
- 複数IdP間でのロール統一

---

## Custom Token Mappers

### 概要

コンテキスト依存のカスタムクレームをトークンに追加。

### 実装例

```java
package com.example.tokenmapper;

import org.keycloak.models.*;
import org.keycloak.protocol.oidc.TokenMapper;
import org.keycloak.protocol.oidc.mappers.AbstractOIDCProtocolMapper;
import org.keycloak.protocol.oidc.mappers.OIDCAttributeMapperHelper;
import org.keycloak.representations.IDToken;
import java.util.Map;

public class CustomContextAwareTokenMapper extends AbstractOIDCProtocolMapper implements TokenMapper {
    private static final String PROVIDER_ID = "custom-context-aware-token-mapper";

    @Override
    protected void setClaim(IDToken token, ProtocolMapperModel mappingModel, UserSessionModel userSession,
                            ClientSessionContext clientSessionCtx) {
        // 特定クライアントにのみクレーム追加
        String clientId = clientSessionCtx.getClientSession().getClient().getClientId();
        if ("specific-client-id".equals(clientId)) {
            Map<String, Object> customClaims = token.getOtherClaims();
            customClaims.put("custom-claim", "special-value");
        }
    }

    @Override
    public String getDisplayType() {
        return "Custom Context-Aware Token Mapper";
    }

    @Override
    public String getId() {
        return PROVIDER_ID;
    }

    public static ProtocolMapperModel create(String name) {
        ProtocolMapperModel mapper = new ProtocolMapperModel();
        mapper.setName(name);
        mapper.setProtocolMapper(PROVIDER_ID);
        OIDCAttributeMapperHelper.addTokenClaimName(mapper, "custom-claim");
        return mapper;
    }
}
```

### デプロイ

1. JARファイルにコンパイル
2. `providers/`ディレクトリに配置
3. Admin Consoleでclientのprotocol mappersに登録

---

## Registration Workflows

### 概要

ユーザー登録フロー設計（Email検証、管理者承認等）。

### フロー設計パターン

#### 1. Email検証のみ

**設定:**
- `Realm Settings > Login > Verify email`: 有効化
- `Realm Settings > Email`: SMTP設定

**フロー:**
1. ユーザーが登録フォーム送信
2. 確認メール送信
3. リンククリックでアカウント有効化

#### 2. 管理者承認フロー

**設定:**
- Email検証有効化（上記）
- カスタムユーザー属性`approvalStatus`追加
- Required Action設定

**フロー:**
1. ユーザー登録
2. Email検証
3. 管理者が`approvalStatus`を`approved`に変更
4. ログイン許可

#### 3. ソーシャルログイン統合

**設定:**
- `Identity Providers`でGoogle/Facebook等設定
- Registration flowに統合

**フロー:**
1. ユーザーがGoogle/Facebook選択
2. 外部IdP認証
3. 初回ログイン時に追加情報入力（オプション）

### 設定例（Admin Console）

```
Realm Settings > Login:
- User registration: ON
- Email as username: ON
- Verify email: ON

Realm Settings > Email:
- Host: smtp.example.com
- Port: 587
- From: noreply@example.com
- Enable SSL: ON
- Enable Authentication: ON
- Username: smtp_user
- Password: smtp_password
```

---

## AWS Cognito連携

### 概要

AWS CognitoをKeycloakの外部IdPとして統合。

### 設定手順

#### Step 1: Cognito User Pool設定

1. AWS Consoleで User Pool作成
2. App Client作成（Client IDとSecretを取得）
3. OAuth2.0 設定（Callback URLにKeycloakを追加）

#### Step 2: Keycloak設定

**Admin Console:**
1. `Identity Providers > Add provider > OpenID Connect v1.0`
2. 以下を入力:
   - **Alias**: cognito
   - **Client ID**: `{your_cognito_client_id}`
   - **Client Secret**: `{your_cognito_client_secret}`
   - **Discovery URL**: `https://cognito-idp.{region}.amazonaws.com/{user_pool_id}/.well-known/openid-configuration`

**例:**
```
Client ID: 1a2b3c4d5e6f7g8h9i0j
Client Secret: abcdefghijklmnopqrstuvwxyz123456
Discovery URL: https://cognito-idp.us-west-2.amazonaws.com/us-west-2_example/.well-known/openid-configuration
```

#### Step 3: テスト

1. Keycloakログイン画面で`Log in with cognito`を選択
2. Cognito認証画面にリダイレクト
3. 認証成功後、Keycloakにリダイレクト

### OAuth Scope・Role Mapping

- Cognitoの`groups`クレームをKeycloak rolesにマッピング
- `Identity Provider > cognito > Mappers`でカスタムマッパー作成

---

## OAuth2クライアント設定ベストプラクティス

### セキュリティ設定

#### PKCE（Proof Key for Code Exchange）有効化

**パブリッククライアント（SPA・モバイル）では必須:**

```json
{
  "clientId": "spa-app",
  "publicClient": true,
  "standardFlowEnabled": true,
  "attributes": {
    "pkce.code.challenge.method": "S256"
  }
}
```

#### Client Secret管理

**Confidential Clientのシークレットローテーション:**

```bash
# 新しいシークレット生成
NEW_SECRET=$(kcadm.sh get clients/<client-uuid> -r myrealm | jq -r '.secret')

# アプリケーションに新シークレットデプロイ後、古いシークレット無効化
kcadm.sh update clients/<client-uuid> -r myrealm \
  -s 'attributes."client.secret.rotation"=true'
```

#### リダイレクトURI厳格化

```json
{
  "redirectUris": [
    "https://app.example.com/callback",
    "https://app.example.com/silent-refresh"
  ],
  "webOrigins": [
    "https://app.example.com"
  ]
}
```

**ワイルドカード使用は最小限に:**
- ❌ 危険: `"*"`、`"http://localhost:*"`
- ✅ 安全: `"https://app.example.com/*"` (同一ドメイン内)

### スコープ設計

#### カスタムスコープ定義

```bash
# Scopeを作成
kcadm.sh create client-scopes -r myrealm \
  -s name=profile:read \
  -s protocol=openid-connect

# Mapperを追加（スコープに応じた claims）
kcadm.sh create client-scopes/<scope-id>/protocol-mappers/models -r myrealm \
  -s name=profile-read-mapper \
  -s protocol=openid-connect \
  -s protocolMapper=oidc-usermodel-attribute-mapper \
  -s 'config."user.attribute"=profile' \
  -s 'config."claim.name"=profile' \
  -s 'config."jsonType.label"=String'
```

#### スコープ最小化原則

**アプリケーションは必要最小限のスコープのみ要求:**

| スコープ | 用途 | リスク |
|---------|------|--------|
| `openid` | 基本OIDC認証 | 低 |
| `profile` | ユーザープロファイル情報 | 中 |
| `email` | メールアドレス | 中 |
| `roles` | ロール情報 | 高（権限昇格リスク） |
| `offline_access` | リフレッシュトークン | 高（長期アクセス） |

---

## OIDC適応パターン

### PKCE統合（パブリッククライアント）

**フロー概要:**
1. クライアントがCode Verifier（ランダム文字列）を生成
2. Code VerifierからCode Challenge（SHA256ハッシュ）を作成
3. Authorization Requestに`code_challenge`・`code_challenge_method=S256`を含める
4. Token Requestに元の`code_verifier`を含めて検証

**JavaScript（SPA）実装例:**

```javascript
// Code Verifier生成
function generateCodeVerifier() {
  const array = new Uint8Array(32);
  crypto.getRandomValues(array);
  return base64URLEncode(array);
}

// Code Challenge生成
async function generateCodeChallenge(verifier) {
  const encoder = new TextEncoder();
  const data = encoder.encode(verifier);
  const hash = await crypto.subtle.digest('SHA-256', data);
  return base64URLEncode(new Uint8Array(hash));
}

// Authorization Request
const codeVerifier = generateCodeVerifier();
const codeChallenge = await generateCodeChallenge(codeVerifier);

window.location.href = `https://keycloak.example.com/auth/realms/myrealm/protocol/openid-connect/auth?
  client_id=spa-app&
  redirect_uri=https://app.example.com/callback&
  response_type=code&
  scope=openid%20profile&
  code_challenge=${codeChallenge}&
  code_challenge_method=S256`;

// Token Request
const response = await fetch('https://keycloak.example.com/auth/realms/myrealm/protocol/openid-connect/token', {
  method: 'POST',
  headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
  body: new URLSearchParams({
    grant_type: 'authorization_code',
    code: authorizationCode,
    redirect_uri: 'https://app.example.com/callback',
    client_id: 'spa-app',
    code_verifier: codeVerifier
  })
});
```

### OIDC Discovery活用

**Discovery Endpoint:**
```
https://keycloak.example.com/auth/realms/{realm}/.well-known/openid-configuration
```

**取得できる情報:**
- `authorization_endpoint`: 認証エンドポイント
- `token_endpoint`: トークン取得エンドポイント
- `jwks_uri`: 公開鍵エンドポイント（JWT署名検証用）
- `userinfo_endpoint`: ユーザー情報エンドポイント
- `end_session_endpoint`: ログアウトエンドポイント

**動的設定例（Node.js）:**

```javascript
const { Issuer } = require('openid-client');

const keycloakIssuer = await Issuer.discover(
  'https://keycloak.example.com/auth/realms/myrealm'
);

const client = new keycloakIssuer.Client({
  client_id: 'my-app',
  client_secret: 'secret',
  redirect_uris: ['https://app.example.com/callback'],
  response_types: ['code']
});
```

---

## SAML Federation・レガシーシステム統合

### SAML IdPとしてのKeycloak設定

**ユースケース:** 既存SAML SP（ServiceProvider）アプリケーションへのSSOを提供

#### SAML Client作成

```bash
kcadm.sh create clients -r myrealm \
  -s clientId=https://legacy-app.example.com/saml/metadata \
  -s protocol=saml \
  -s 'attributes."saml.authnstatement"=true' \
  -s 'attributes."saml.signing.certificate"=MIICnTCCAYUC...' \
  -s 'redirectUris=["https://legacy-app.example.com/saml/acs"]'
```

#### SAML Assertion設定

**Mapper追加（ユーザー属性をSAML Assertionに含める）:**

```json
{
  "name": "email-saml-mapper",
  "protocol": "saml",
  "protocolMapper": "saml-user-property-mapper",
  "config": {
    "user.attribute": "email",
    "attribute.name": "urn:oid:1.2.840.113549.1.9.1",
    "attribute.nameformat": "urn:oasis:names:tc:SAML:2.0:attrname-format:uri"
  }
}
```

### レガシーシステム統合パターン

#### パターン1: LDAP User Federationブリッジ

```
Keycloak
  └── User Federation (LDAP)
        └── 既存 Active Directory
              └── レガシーアプリケーション（LDAP認証）
```

**設定:**
- Keycloak User Federation > LDAP Provider
- Read-Only/Writable選択
- User・Group同期スケジュール設定

#### パターン2: カスタムUser Storage Provider

**Java SPI実装でレガシーDB直接接続:**

```java
public class LegacyUserStorageProvider implements UserStorageProvider, UserLookupProvider {
    @Override
    public UserModel getUserByUsername(String username, RealmModel realm) {
        // レガシーDBからユーザー取得ロジック
        return mapLegacyUserToKeycloak(legacyUser);
    }
}
```

---

## API・マイクロサービスセキュリティ

### API Gateway統合

#### Kong Gateway + Keycloak OIDC Plugin

```yaml
# Kong OIDC Plugin設定
plugins:
  - name: oidc
    config:
      client_id: api-gateway
      client_secret: ${KEYCLOAK_CLIENT_SECRET}
      discovery: https://keycloak.example.com/auth/realms/myrealm/.well-known/openid-configuration
      scope: openid profile
      bearer_only: "yes"
      introspection_endpoint_auth_method: client_secret_post
```

#### サービスメッシュ統合（Istio）

**RequestAuthentication設定（JWT検証）:**

```yaml
apiVersion: security.istio.io/v1beta1
kind: RequestAuthentication
metadata:
  name: keycloak-jwt
  namespace: default
spec:
  jwtRules:
  - issuer: "https://keycloak.example.com/auth/realms/myrealm"
    jwksUri: "https://keycloak.example.com/auth/realms/myrealm/protocol/openid-connect/certs"
```

**AuthorizationPolicy設定（スコープベース認可）:**

```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: require-admin-scope
  namespace: default
spec:
  action: ALLOW
  rules:
  - when:
    - key: request.auth.claims[scope]
      values: ["admin"]
```

### M2M認証（Machine-to-Machine）

#### Service Account Client設定

```bash
kcadm.sh create clients -r myrealm \
  -s clientId=backend-service \
  -s serviceAccountsEnabled=true \
  -s 'attributes."client.secret"=supersecret'

# Service Accountにロール割当
SERVICE_ACCOUNT_ID=$(kcadm.sh get clients -r myrealm --query clientId=backend-service --fields id --format csv | tail -n 1)
kcadm.sh add-roles -r myrealm --uusername service-account-backend-service --rolename api-consumer
```

#### Client Credentials Grantフロー

```bash
# トークン取得
curl -X POST "https://keycloak.example.com/auth/realms/myrealm/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=backend-service" \
  -d "client_secret=supersecret"

# レスポンス
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR...",
  "expires_in": 300,
  "token_type": "Bearer"
}
```

---

## アプリケーション種別別保護パターン

### 内部（First-Party）vs 外部（Third-Party）アプリケーション

| 種別 | 説明 | Consent設定 | 信頼レベル |
|-----|------|------------|----------|
| **内部アプリケーション** | 組織が所有・管理するアプリ | `Consent required: OFF` | 事前承認済み |
| **外部アプリケーション** | サードパーティが提供するアプリ | `Consent required: ON` | ユーザー承認必須 |

#### 内部アプリケーション設定

```
Client Settings:
- Consent required: OFF
- 組織の管理者が事前承認
- ユーザーは認証のみ実施
```

#### 外部アプリケーション設定

```
Client Settings:
- Consent required: ON
- ユーザーが明示的にアクセス許可
- スコープ・権限の透明性確保
```

---

### Webアプリケーション保護パターン

#### パターン1: サーバーサイドWebアプリ

**特徴:**
- Confidential Client使用
- HTTPセッションベースの状態管理
- ID Tokenでセッション確立
- アクセストークンで外部API呼出

**フロー:**
1. Webサーバーがブラウザを認可エンドポイントにリダイレクト
2. ユーザーがKeycloakで認証
3. 認可コードがWebサーバーに返却
4. Webサーバーがトークンエンドポイントでコード交換（Client Secret使用）
5. ID Tokenでユーザー情報取得、HTTPセッション確立
6. ブラウザからのリクエストにセッションCookie含める

**セキュリティ設定:**
- PKCE推奨（必須ではないが防御層追加）
- 厳密なRedirect URI設定（オープンリダイレクト防止）
- Client Secret適切管理

---

#### パターン2: SPA + 専用REST API

**特徴:**
- サーバーサイドWebアプリと同様のセキュリティレベル
- Confidential Client + HTTPセッション
- Authorization Code Flow使用
- SPAとAPIが同一ドメイン

**推奨理由:**
- トークンがブラウザに直接露出しない
- Refresh Token漏洩リスク最小化
- セッションベース保護

---

#### パターン3: SPA + 中間API（BFF: Backend for Frontends）

**特徴:**
- 外部API呼出を中間APIで代理
- Confidential Client使用
- HTTPセッションでトークン管理
- CORS不要（同一ドメイン）

**フロー:**
1. ユーザーがログインリンククリック → Webサーバーに送信
2. WebサーバーがKeycloakログインページにリダイレクト
3. ユーザーが認証
4. 認可コードがWebサーバーに返却
5. Webサーバーがトークン取得、HTTPセッション確立
6. SPAからのリクエストにHTTPセッションCookie
7. Webサーバーがセッションからアクセストークン取得、外部APIに転送
8. レスポンスをSPAに返却

**利点:**
- トークンがブラウザに露出しない
- ポータビリティ向上
- 外部API変更の影響を中間APIで吸収
- CORS設定不要

---

#### パターン4: SPA + 外部API（Public Client）

**特徴:**
- Public Client使用（Client Secret不可）
- Authorization Code Flow + PKCE必須
- トークンがブラウザに直接露出
- CORS設定必須

**セキュリティ対策:**
- **Refresh Token短期有効期限**: Client Session Timeoutで30分等に設定
- **Refresh Token Rotation**: 前回使用トークンを無効化、不正使用時にセッション無効化
- **PKCE必須**: Public ClientではPKCE必須（認可コード漏洩対策）
- **トークン格納**: `window.sessionStorage`使用、推測困難なキー名
- **XSS対策**: OWASP推奨のセキュリティベストプラクティス遵守
- **サードパーティスクリプト注意**: 慎重に検証

**フロー:**
1. SPAがKeycloakログインページにリダイレクト
2. 認可コードがSPAに返却
3. SPAが認可コードをトークンと交換（Public Client）
4. SPAが直接アクセストークンをREST APIリクエストに含める
5. REST APIがCORSヘッダーを返却（ブラウザ制限回避）

---

### ネイティブ・モバイルアプリケーション保護

#### 基本原則

**避けるべき方法:**
- ❌ アプリ内でユーザー名・パスワード収集 → Resource Owner Password Credential使用
- ❌ 理由: ユーザー資格情報に直接アクセス、Keycloak機能活用不可

**推奨方法:**
- ✅ Authorization Code Flow + PKCE
- ✅ ブラウザ経由での認証

#### ブラウザ選択肢

| オプション | 説明 | セキュリティ | SSO |
|----------|------|------------|-----|
| **埋込WebView** | ❌ 非推奨 | 資格情報傍受リスク | 不可 |
| **In-App Browser Tab** | ✅ 推奨 | システムブラウザ活用 | 可能 |
| **外部ユーザーエージェント** | ✅ 最高 | ユーザーがブラウザ確認可能 | 可能 |

#### 認可コード返却方法

| 方法 | 説明 | 推奨度 |
|-----|------|-------|
| **Claimed HTTPS Scheme** | HTTPS URLをアプリが主張 | ✅ 最推奨 |
| **Custom URI Scheme** | `org.acme.app://oauth2/...` | ✅ 推奨 |
| **Loopback Interface** | `http://127.0.0.1:<port>/...` | ✅ CLI向け |
| **特殊リダイレクトURI** | `urn:ietf:wg:oauth:2.0:oob` | 手動コピー・ペースト |

#### Device Code Grant（入力制約デバイス）

**適用ケース:**
- Smart TV、IoTデバイス、ブラウザ不可環境

**フロー:**
1. デバイスがDevice Authorization Request送信
2. `user_code`、`verification_uri`、`device_code`取得
3. ユーザーが別デバイスで`verification_uri`開く、`user_code`入力
4. アクセス許可
5. デバイスがDevice Access Token Requestで`device_code`送信
6. トークン取得

---

### REST API・サービス保護

#### Bearer Token認証

**基本パターン:**
1. アプリケーションがKeycloakからアクセストークン取得
2. リクエストに`Authorization: bearer <token>`ヘッダー含める
3. サービスがトークン検証、アクセス許可判断

**トークン検証方法:**
- **JWT署名検証**: 公開鍵でローカル検証（低レイテンシ）
- **Token Introspection**: Keycloakエンドポイントで検証（オペークトークン）

#### マイクロサービス・エンドツーエンド認証

**パターン:**
```
User → App → Service A → Service B
                     ↘ Service C
```

**利点:**
- すべてのサービスが同一アクセストークン使用
- エンドツーエンドユーザー認証コンテキスト維持

#### Service Account（M2M認証）

**設定:**
```bash
# Service Account Client作成
Client ID: backend-service
Client authentication: ON
Service accounts roles: ON
Standard flow: OFF
```

**Client Credentials Grant:**
```bash
curl -X POST "https://keycloak.example.com/.../token" \
  -d "grant_type=client_credentials" \
  -d "client_id=backend-service" \
  -d "client_secret=supersecret"
```

**レスポンス:**
```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR...",
  "expires_in": 300,
  "token_type": "Bearer"
}
```

---

## SSO/SLO詳細

### Backchannel Logout

**概要:** ユーザーがひとつのアプリケーションでログアウトした際、Keycloakが全ての関連アプリケーションに対してバックチャネル（直接HTTP POST）でログアウト通知を送信。

#### Client設定

```json
{
  "clientId": "app1",
  "attributes": {
    "backchannel.logout.url": "https://app1.example.com/logout",
    "backchannel.logout.session.required": "true"
  }
}
```

#### アプリケーション側実装（Node.js）

```javascript
app.post('/logout', (req, res) => {
  const { logout_token } = req.body;

  // Logout Token検証（JWT署名検証）
  const decoded = jwt.verify(logout_token, publicKey, { algorithms: ['RS256'] });

  // Session ID取得してセッション無効化
  const sid = decoded.sid;
  sessionStore.destroy(sid, (err) => {
    if (err) console.error('Session destroy error:', err);
  });

  res.sendStatus(200);
});
```

### Front-channel Logout

**概要:** ブラウザを介したログアウト伝播（iframeまたはリダイレクト）。

**フロー:**
1. ユーザーがApp1でログアウト
2. Keycloakログアウトエンドポイントにリダイレクト
3. Keycloakが全アプリケーションのログアウトURLをiframeでロード
4. 各アプリケーションがCookieクリアしてログアウト

---

## リバースプロキシ統合

### Apache HTTP Server + mod_auth_openidc

**ユースケース:**
- レガシーアプリケーション保護（コード変更不可）
- 中央集権的な認証管理
- 複数アプリケーションの統一認証

#### 設定例

```apache
LoadModule auth_openidc_module modules/mod_auth_openidc.so
ServerName localhost

<VirtualHost *:80>
    # バックエンドアプリケーションへのプロキシ
    ProxyPass / http://localhost:8000/
    ProxyPassReverse / http://localhost:8000/

    # OIDC設定
    OIDCCryptoPassphrase CHANGE_ME
    OIDCProviderMetadataURL http://keycloak.example.com/realms/myrealm/.well-known/openid-configuration
    OIDCClientID proxy-client
    OIDCClientSecret CLIENT_SECRET
    OIDCRedirectURI http://localhost/callback

    # Cookie設定
    OIDCCookieDomain localhost
    OIDCCookiePath /
    OIDCCookieSameSite On

    # 保護対象パス
    <Location />
        AuthType openid-connect
        Require valid-user
    </Location>
</VirtualHost>
```

#### 動作フロー

1. ユーザーがアプリケーションにアクセス
2. mod_auth_opendidcがKeycloakにリダイレクト
3. ユーザー認証後、ProxyがHTTPヘッダーにユーザー情報を付加
4. バックエンドアプリはヘッダーからユーザー情報取得

**利点:**
- アプリケーションコード変更不要
- 中央集権的設定管理
- レガシーシステム対応

---

### Nginx + OIDC Plugin

**設定例:**

```nginx
server {
    listen 80;
    server_name app.example.com;

    # OIDC認証
    location / {
        auth_request /_oauth2_token_introspection;
        proxy_pass http://backend:8080;
        proxy_set_header X-Auth-Request-User $auth_user;
        proxy_set_header X-Auth-Request-Email $auth_email;
    }

    location = /_oauth2_token_introspection {
        internal;
        proxy_pass http://keycloak.example.com/auth/realms/myrealm/protocol/openid-connect/userinfo;
        proxy_set_header Authorization $http_authorization;
    }
}
```

---

## 統合アプローチ比較

| 項目 | Java Servlet | Node.js | Spring Boot | Generic OIDC | Reverse Proxy |
|-----|-------------|---------|-------------|--------------|--------------|
| **設定複雑度** | 中 | 低 | 低 | 高 | 中 |
| **Session管理** | Servlet Session | express-session | Spring Security | 自前実装 | Proxy管理 |
| **Role/Permission** | web.xmlで定義 | middleware | @Secured注釈 | 自前実装 | HTTPヘッダー |
| **トークン検証** | 自動 | 自動 | 自動 | 手動 | Proxy側 |
| **エコシステム** | Java EE | Express.js | Spring Boot | 任意 | 汎用 |
| **PKCE対応** | 手動実装 | ライブラリ対応 | Spring Security対応 | 手動実装 | Proxy対応 |
| **API Gateway統合** | 可能 | 容易 | 容易 | 可能 | 最適 |
| **レガシー対応** | △ | △ | △ | △ | ✅ |

---

## ベストプラクティス・注意事項

### 避けるべきパターン

#### 1. 自前実装の禁止

**理由:**
- OAuth2/OIDCは使いやすいが、実装は複雑
- セキュリティ脆弱性リスク
- 仕様変更への追従困難

**推奨:**
- 確立されたライブラリ・フレームワーク使用
- 専門家がメンテナンスする実装に依存
- OpenID Connect認定実装を優先

#### 2. アプリ内ログインページ埋込の禁止

**避けるべき:**
- ❌ Resource Owner Password Credential Grant使用
- ❌ Keycloakログインページをiframe埋込

**理由:**
- ユーザー資格情報に直接アクセス（セキュリティリスク）
- 2要素認証等の高度な認証機能使用不可
- SSO・ソーシャルログインのメリット喪失
- iframe埋込はサードパーティCookieブロックで動作不可

**正しいパターン:**
- ✅ ユーザーを信頼できるIdPにリダイレクト
- ✅ Authorization Code Flow使用

#### 3. オープンリダイレクト対策

**設定:**
```
Client Settings:
- Valid redirect URIs: 厳密に定義
- 例: https://app.example.com/callback
- ワイルドカード最小限使用
```

**危険な設定:**
- ❌ `*`（すべてのURI）
- ❌ `http://localhost:*`（すべてのポート）

**安全な設定:**
- ✅ `https://app.example.com/*`（同一ドメイン内）

---

### セキュリティ設定チェックリスト

#### PKCE設定

**パブリッククライアント（必須）:**
```json
{
  "clientId": "spa-app",
  "publicClient": true,
  "attributes": {
    "pkce.code.challenge.method": "S256"
  }
}
```

#### Client Secretローテーション

**定期的なシークレット更新:**
```bash
# 新シークレット生成
NEW_SECRET=$(kcadm.sh get clients/<client-uuid> -r myrealm | jq -r '.secret')

# アプリデプロイ後、古いシークレット無効化
kcadm.sh update clients/<client-uuid> -r myrealm \
  -s 'attributes."client.secret.rotation"=true'
```

#### スコープ最小化

**必要最小限のスコープのみ要求:**

| スコープ | 用途 | リスクレベル |
|---------|------|------------|
| `openid` | 基本OIDC認証 | 低 |
| `profile` | プロファイル情報 | 中 |
| `email` | メールアドレス | 中 |
| `roles` | ロール情報 | 高（権限昇格リスク） |
| `offline_access` | リフレッシュトークン | 高（長期アクセス） |

---

### 実装選択フローチャート

```
Start
  ↓
[アプリケーションコード変更可能？]
  ├─ Yes → [技術スタック対応ライブラリ存在？]
  │         ├─ Yes → Embedded統合（推奨）
  │         └─ No → Generic OIDC実装
  │
  └─ No  → [複数アプリケーション？]
            ├─ Yes → Reverse Proxy統合（最適）
            └─ No → Reverse Proxy統合（レガシー対応）
```
