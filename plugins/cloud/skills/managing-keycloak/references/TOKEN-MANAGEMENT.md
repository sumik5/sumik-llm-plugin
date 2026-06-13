# Keycloak トークン管理

## OAuth 2.0 フロー選択ガイド

アプリケーションの種類とセキュリティ要件に応じて適切なフローを選択する。

| フロー | アプリ種別 | セキュリティ | ユーザー介入 | 推奨用途 |
|--------|----------|------------|-----------|---------|
| **Authorization Code + PKCE** | SPA、モバイルアプリ | 高 | あり | パブリッククライアント（推奨） |
| **Authorization Code** | サーバーサイドWebアプリ | 高 | あり | Confidentialクライアント |
| **Client Credentials** | サービス間通信 | 中 | なし | バックエンドAPI、マイクロサービス |
| **Implicit** | SPA（非推奨） | 低 | あり | 廃止予定（PKCEを使用） |
| **Device Authorization Grant** | TV、IoTデバイス | 中 | あり（別デバイス） | ブラウザなしデバイス |
| **Resource Owner Password** | レガシー（非推奨） | 低 | あり | 移行時の一時的な使用のみ |

### 判断基準フローチャート

```
アプリ種別は？
├─ ブラウザなしデバイス（TV、IoT）
│  └─ Device Authorization Grant
│
├─ サーバーサイドWebアプリ（Java、Node.js等）
│  └─ Authorization Code Flow
│
├─ SPA（React、Vue.js等）またはモバイルアプリ
│  └─ Authorization Code + PKCE
│
└─ サービス間通信（マイクロサービス、バックグラウンドジョブ）
   └─ Client Credentials Grant
```

---

## JWT（JSON Web Token）

KeycloakはOIDC/OAuth 2.0トークンとしてJWTを発行。JWTは3部構成（Header.Payload.Signature）。

### JWT構造

```
eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.    ← Header（Base64URL）
eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6...  ← Payload（Base64URL）
SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c  ← Signature
```

#### Header（ヘッダー）

```json
{
  "alg": "RS256",
  "typ": "JWT",
  "kid": "key-id"
}
```

- `alg`: 署名アルゴリズム（RS256 = RSA SHA-256）
- `typ`: トークンタイプ（JWT固定）
- `kid`: 公開鍵のID（Keycloakの鍵ローテーション対応）

#### Payload（ペイロード）

```json
{
  "iss": "https://keycloak.example.com/auth/realms/myrealm",
  "sub": "user-id-123",
  "aud": "my-client",
  "exp": 1678322234,
  "iat": 1678321234,
  "name": "John Doe",
  "email": "john.doe@example.com",
  "roles": ["user", "admin"]
}
```

- `iss`（Issuer）: トークン発行者（Keycloakの URL）
- `sub`（Subject）: ユーザーID
- `aud`（Audience）: トークンの対象クライアント
- `exp`（Expiration Time）: 有効期限（UNIX timestamp）
- `iat`（Issued At）: 発行時刻
- カスタムクレーム: `name`, `email`, `roles` 等

#### Signature（署名）

```
HMACSHA256(
  base64UrlEncode(header) + "." + base64UrlEncode(payload),
  secret
)
```

Keycloakは秘密鍵で署名、クライアントは公開鍵で検証。

### JWTデコード例（Python）

```python
import jwt

token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

# 署名検証なしでデコード（検証は本番環境では必須）
decoded = jwt.decode(token, options={"verify_signature": False})
print(decoded)
```

### JWT検証（署名確認）

Keycloakの公開鍵を取得して署名を検証：

```bash
# 公開鍵エンドポイント
curl https://keycloak.example.com/auth/realms/myrealm/protocol/openid-connect/certs

# OpenSSLで署名検証（例）
echo -n "<header>.<payload>" | openssl dgst -sha256 -verify public_key.pem -signature <signature>
```

---

## OIDC Token種類

OpenID Connect（OIDC）は3種類のトークンを発行：ID Token、Access Token、Refresh Token。

| トークン種類 | 用途 | 有効期限 | 含まれる情報 |
|------------|------|---------|------------|
| **ID Token** | ユーザー認証情報 | 短い（5分程度） | ユーザーID、名前、メール等 |
| **Access Token** | APIアクセス認可 | 短い（5-15分） | スコープ、ロール、権限 |
| **Refresh Token** | Access Token更新 | 長い（数時間〜数日） | トークン更新用の認可情報 |

### トークン取得例（Python）

```python
import requests

keycloak_url = "http://localhost:8080/auth/realms/myrealm/protocol/openid-connect/token"

data = {
    'grant_type': 'password',
    'client_id': 'my-client',
    'client_secret': 'client-secret',
    'username': 'john.doe',
    'password': 'password123'
}

response = requests.post(keycloak_url, data=data)
tokens = response.json()

print(f"Access Token: {tokens['access_token']}")
print(f"ID Token: {tokens['id_token']}")
print(f"Refresh Token: {tokens['refresh_token']}")
```

**レスポンス例:**
```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expires_in": 300,
  "refresh_expires_in": 1800,
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "id_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

### ID Token vs Access Token

| 項目 | ID Token | Access Token |
|------|----------|-------------|
| **目的** | ユーザー認証 | API認可 |
| **対象** | クライアントアプリ | リソースサーバー（API） |
| **内容** | ユーザープロフィール | スコープ、権限 |
| **検証** | クライアントが検証 | リソースサーバーが検証 |

### Refresh Token使用例

```bash
curl -X POST \
  "http://localhost:8080/auth/realms/myrealm/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=refresh_token" \
  -d "client_id=my-client" \
  -d "refresh_token={refresh_token}"
```

---

## Session管理

Keycloakは複数クライアント間でユーザーセッションを共有（SSO実現）。トークンの有効性はセッションの状態に依存する。

### Session階層

Keycloakは2レベルのセッションを管理：

**SSO Session（User Session）:**
- ユーザー単位のトップレベルセッション
- 複数クライアント間で共有
- SSOの基盤

**Client Session:**
- クライアント単位のセッション
- トークンの有効性を管理
- SSO Sessionに紐付く

**有効期限設定（Realm Settings → Sessions）:**
```plaintext
SSO Session Max: 10時間（デフォルト）
SSO Session Idle: 30分（デフォルト）
Client Session Max: SSO Session Maxに従う（デフォルト0）
Client Session Idle: SSO Session Idleに従う（デフォルト0）
```

**挙動:**
- アイドルタイムアウト内にアクティビティがあれば、最大時間までセッション継続
- SSO Session期限切れ → すべてのClient Sessionも無効化
- Client Session期限切れ → ユーザーは再認証不要、クライアントのみ再認証

### Session種類

| Session種類 | 説明 | 有効期限 | ユースケース |
|-----------|------|---------|------------|
| **Online Session** | アクティブなユーザーセッション | 短い（数時間） | 通常のWebアプリ |
| **Offline Session** | 長期リフレッシュトークン用 | 長い（数日〜無期限） | モバイルアプリ、バックグラウンドサービス |

### Session情報取得（Admin REST API）

```bash
curl -X GET \
  "https://keycloak.example.com/auth/admin/realms/myrealm/clients/{client-id}/user-sessions" \
  -H "Authorization: Bearer {admin-access-token}"
```

**レスポンス例:**
```json
[
  {
    "id": "session-id-123",
    "username": "john.doe",
    "ipAddress": "192.168.1.100",
    "start": 1678321234000,
    "lastAccess": 1678322234000,
    "clients": [
      {
        "clientId": "web-app",
        "clientSession": "client-session-id"
      }
    ]
  }
]
```

### Offline Session有効化

Offline Sessionを使うには `offline_access` スコープをリクエスト。

```bash
curl -X POST \
  "http://localhost:8080/auth/realms/myrealm/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=my-client" \
  -d "client_secret=client-secret" \
  -d "grant_type=password" \
  -d "username=john.doe" \
  -d "password=password123" \
  -d "scope=openid offline_access"
```

**レスポンスに `offline_token` が含まれる:**
```json
{
  "access_token": "...",
  "refresh_token": "...",
  "offline_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "scope": "openid offline_access"
}
```

### Session無効化（Admin Console）

**ユーザー単位:**
```plaintext
1. Users → 対象ユーザーを選択
2. Sessions タブ
3. "Logout" または "Logout all sessions"
```

**レルム全体:**
```plaintext
1. Sessions → Realm Sessions
2. Action: "Sign out all active sessions"
```

### Sessionライフタイム設計指針

**セキュリティ vs ユーザビリティ:**
```
短いライフタイム（5分）:
├─ セキュリティ: 高（トークン盗難リスク低減）
└─ ユーザビリティ: 低（頻繁な再認証）

長いライフタイム（1時間）:
├─ セキュリティ: 低（トークン盗難時の影響大）
└─ ユーザビリティ: 高（再認証頻度低）

推奨設定:
- SSO Session Max: 10時間
- SSO Session Idle: 30分
- Access Token: 5-15分
- Refresh Token: 1-2時間
- Offline Token: 30-60日（モバイル）
```

---

## Token有効期限設定

トークンの有効期限はレルム設定で調整可能。

### 有効期限種類

| 設定項目 | デフォルト | 説明 |
|---------|----------|------|
| **Access Token Lifespan** | 5分 | Access Tokenの有効期限 |
| **Access Token Lifespan For Implicit Flow** | 15分 | Implicit Flow用（廃止予定） |
| **Client Session Idle** | 30分 | クライアントセッションのアイドルタイムアウト |
| **SSO Session Idle** | 30分 | SSOセッションのアイドルタイムアウト |
| **SSO Session Max** | 10時間 | SSOセッションの最大有効期限 |
| **Offline Session Idle** | 30日 | Offline Sessionのアイドルタイムアウト |
| **Offline Session Max** | 60日 | Offline Sessionの最大有効期限 |

### Admin REST API経由で設定

```bash
curl -X PUT \
  "http://localhost:8080/auth/admin/realms/myrealm" \
  -H "Authorization: Bearer {admin-access-token}" \
  -H "Content-Type: application/json" \
  -d '{
    "accessTokenLifespan": 600,
    "ssoSessionIdleTimeout": 1800,
    "ssoSessionMaxLifespan": 36000
  }'
```

### セキュリティ vs ユーザビリティのトレードオフ

```
短い有効期限（5分）
├─ セキュリティ: 高（トークン盗難リスク低減）
└─ ユーザビリティ: 低（頻繁な再認証）

長い有効期限（1時間）
├─ セキュリティ: 低（トークン盗難時の影響大）
└─ ユーザビリティ: 高（再認証頻度低）

推奨設定:
- Access Token: 5-15分
- Refresh Token: 1-2時間
- Offline Token: 30-60日（モバイルアプリ用）
```

---

## Token Exchange

既存のトークンを別のトークンに交換。マイクロサービス間のトークン委譲に使用。

### Token Exchange例

```bash
curl -X POST \
  "http://localhost:8080/auth/realms/myrealm/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=urn:ietf:params:oauth:grant-type:token-exchange" \
  -d "client_id=my-service" \
  -d "subject_token={existing-access-token}" \
  -d "requested_token_type=urn:ietf:params:oauth:token-type:access_token"
```

**レスポンス:**
```json
{
  "access_token": "new-access-token",
  "expires_in": 300,
  "refresh_token": "new-refresh-token"
}
```

**ユースケース:**
- サービスAのトークン → サービスBのトークンに交換
- 異なるスコープのトークン取得
- トークンのダウングレード（権限削減）

---

## Token検証

### 外部トークン検証（公開鍵）

Keycloakの公開鍵でトークン署名を検証（オフライン検証）。

```bash
# 公開鍵取得
curl https://keycloak.example.com/auth/realms/myrealm/protocol/openid-connect/certs
```

**レスポンス例（JWKS）:**
```json
{
  "keys": [
    {
      "kid": "key-id-123",
      "kty": "RSA",
      "alg": "RS256",
      "use": "sig",
      "n": "modulus...",
      "e": "AQAB"
    }
  ]
}
```

### Token Introspection（リアルタイム検証）

Keycloakに問い合わせてトークンの有効性を確認。トークン検証の標準的で移植性の高い方法（RFC 7662）。

**利点:**
- Keycloak固有の実装に依存しない
- セッション状態を含めた完全な検証
- トークン失効が即座に反映

**欠点:**
- 追加のネットワークラウンドトリップ
- Keycloakへの負荷増加

**緩和策:**
- 検証結果のキャッシュ（数分間）
- 重要な操作のみIntrospection使用

```bash
curl -X POST \
  "http://localhost:8080/auth/realms/myrealm/protocol/openid-connect/token/introspect" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=my-client" \
  -d "client_secret=client-secret" \
  -d "token={access_token}"
```

**レスポンス:**
```json
{
  "active": true,
  "exp": 1678322234,
  "iat": 1678321234,
  "sub": "user-id-123",
  "scope": "profile email",
  "client_id": "my-client",
  "username": "john.doe",
  "token_type": "Bearer"
}
```

### Token検証戦略比較

| 方式 | セキュリティ | パフォーマンス | 実装難易度 | ユースケース |
|------|------------|------------|----------|------------|
| **Introspection** | 最高（セッション状態確認） | 低（追加RTT） | 低 | 重要な操作、OAuth 2.0標準準拠 |
| **Local JWT検証** | 中（署名のみ） | 高（追加RTTなし） | 中 | 一般的なAPI呼び出し |
| **Introspection + Cache** | 高 | 中 | 中 | バランス重視 |

### JWS（JSON Web Signature）

Keycloakは非対称暗号（RSA）でトークンに署名。

**署名フロー:**
```
1. Keycloak: 秘密鍵でトークンに署名（RS256）
2. クライアント: 公開鍵で署名を検証
3. 検証成功 → トークンは改ざんされていない
```

**署名検証例（概念）:**
```
Signature = RSA_SHA256(base64(Header) + "." + base64(Payload), PrivateKey)
Verify = RSA_SHA256_Verify(Signature, PublicKey)
```

---

## Token Revocation

トークンを無効化するポリシー。セキュリティインシデント時やライフサイクル管理に不可欠。

### トークン無効化方法

#### 1. Token Revocation Endpoint（RFC 7009）

クライアントが明示的にトークンを無効化。

```bash
curl -X POST \
  "http://localhost:8080/auth/realms/myrealm/protocol/openid-connect/revoke" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=my-client" \
  -d "client_secret=client-secret" \
  -d "token={refresh_token}"
```

**用途:**
- ログアウト時のトークン無効化
- 不要になったトークンのクリーンアップ
- メモリ・CPU節約

#### 2. Session無効化

セッション削除によりトークンを間接的に無効化。

```plaintext
Admin Console:
- Sessions → Sign out all active sessions（レルム全体）
- Users → Sessions → Logout all sessions（ユーザー単位）
```

#### 3. Not-Before Revocation Policy

指定時刻以前のすべてのトークンを無効化。

```bash
# Admin Console:
# Sessions → Action → Revocation → Set to now

# Admin REST API:
curl -X PUT \
  "http://localhost:8080/auth/admin/realms/myrealm" \
  -H "Authorization: Bearer {admin-access-token}" \
  -H "Content-Type: application/json" \
  -d '{
    "notBefore": 1678321234
  }'
```

**用途:**
- セキュリティインシデント時の緊急対応
- 全ユーザー・全クライアントのトークン一斉無効化

### 無効化トリガー

| イベント | 動作 | 影響範囲 |
|---------|------|---------|
| **ユーザーログアウト** | 全セッション+トークン無効化 | ユーザーのすべてのクライアント |
| **パスワード変更** | 既存トークン無効化 | ユーザーのすべてのトークン |
| **Admin操作（Session削除）** | 個別セッション+トークン無効化 | 指定セッションのみ |
| **Not-Before Policy** | 指定時刻以前のトークン無効化 | レルム全体 |
| **Client呼び出し（Revoke Endpoint）** | 指定トークンのみ無効化 | 個別トークン |

### Refresh Token Rotation

Refresh Token漏洩時の影響を低減。

**有効化（Realm Settings → Tokens）:**
```plaintext
Revoke Refresh Token: ON
Refresh Token Max Reuse: 0（推奨）
```

**動作:**
```
1. Client → Refresh Token Request（token_1）
2. Keycloak → token_1を無効化
3. Keycloak → 新しいRefresh Token（token_2）を発行
4. Client → Refresh Token Request（token_1）← 再利用試行
5. Keycloak → エラー（token_1は無効）+ セッション無効化
```

**効果:**
- Refresh Token盗難の即座検出
- 攻撃者と正規クライアントの一方のみが再認証成功
- 正規クライアントのみが新しいRefresh Token取得可能

### Revocation戦略の比較

| 方式 | 即座性 | スコープ | パフォーマンス影響 | ユースケース |
|------|-------|---------|----------------|------------|
| **Revocation Endpoint** | 高 | 個別トークン | 低 | ログアウト、個別無効化 |
| **Session削除** | 高 | セッション単位 | 中 | ユーザー/クライアント単位の無効化 |
| **Not-Before Policy** | 中（バックグラウンドタスク待ち） | レルム全体 | 高 | 緊急対応、全体無効化 |
| **Short-lived Token + Refresh** | 低（有効期限待ち） | 自動 | 低 | 通常運用 |

---

## SAML Assertions

KeycloakはSAML 2.0もサポート。XML形式のアサーション。

### SAML Assertion設定例（JSON）

```json
{
  "attributes": {
    "email": "${user.email}",
    "firstName": "${user.firstName}",
    "lastName": "${user.lastName}"
  }
}
```

### SAML vs OIDC比較

| 項目 | SAML | OIDC |
|------|------|------|
| **形式** | XML | JSON（JWT） |
| **プロトコル** | SAML 2.0 | OAuth 2.0 + OpenID Connect |
| **用途** | エンタープライズSSO | モダンWeb/モバイルアプリ |
| **トークン** | SAML Assertion | ID Token、Access Token |
| **実装複雑度** | 高 | 低 |

**SAML Assertionの構造（簡略版）:**
```xml
<saml:Assertion>
  <saml:Subject>
    <saml:NameID>john.doe@example.com</saml:NameID>
  </saml:Subject>
  <saml:AttributeStatement>
    <saml:Attribute Name="email">
      <saml:AttributeValue>john.doe@example.com</saml:AttributeValue>
    </saml:Attribute>
  </saml:AttributeStatement>
</saml:Assertion>
```

---

## Logout管理

SSOにおけるログアウトは複雑。複数の手法があり、適切な選択が重要。

### Logout戦略の比較

| 手法 | 即座性 | 実装難易度 | ブラウザ依存 | 適用対象 | 推奨度 |
|------|-------|----------|----------|---------|-------|
| **Token/Session Expiration** | 低 | 低 | なし | すべて | ⭐⭐⭐ |
| **OIDC Backchannel Logout** | 高 | 中 | なし | サーバーサイド | ⭐⭐ |
| **OIDC Session Management** | 高 | 中 | あり（非推奨） | ブラウザ | ⭐ |
| **OIDC Front-Channel Logout** | 低 | 低 | あり（非推奨） | ブラウザ | 非推奨 |

### Token/Session Expiration（推奨）

最もシンプルで堅牢な方法。

**原理:**
```
1. Access Token: 短い有効期限（5-15分）
2. Refresh Token: 中程度の有効期限（1-2時間）
3. Session: Idle timeout（30分）
4. ログアウト → Session無効化
5. クライアント → Refresh試行 → 失敗（Sessionなし）
6. クライアント → ユーザーに再認証要求
```

**利点:**
- 実装が単純
- ネットワーク障害に強い
- すべてのクライアントタイプで有効

**欠点:**
- 即座のログアウトではない（数分のラグ）

### OIDC Backchannel Logout

サーバー間でセッション無効化を通知。フロントチャネル（ブラウザ経由）より確実。

**有効化（Client設定）:**
```json
{
  "clientId": "my-app",
  "protocol": "openid-connect",
  "backchannelLogout": true,
  "backchannelLogoutUrl": "https://my-app.com/logout-callback"
}
```

**フロー:**
```
1. ユーザー → Client A → Keycloak Logout Endpoint
2. Keycloak → Client B（Backchannel Logout URL）へLogout Token送信
3. Client B → Logout Token検証
4. Client B → セッション無効化
5. Keycloak → Client A へリダイレクト
```

**Logout Token例:**
```json
{
  "iss": "https://keycloak.example.com/realms/myrealm",
  "aud": "my-app",
  "iat": 1678321234,
  "jti": "logout-token-id",
  "events": {
    "http://schemas.openid.net/event/backchannel-logout": {}
  },
  "sid": "session-id-123"
}
```

**課題:**
- クラスタ環境でのセッション管理（Session Affinity不要な設計が必要）
- ステートレスアプリでの実装複雑化

### RP-Initiated Logout

クライアントがKeycloakへログアウトを要求。

**エンドポイント:**
```
https://keycloak.example.com/auth/realms/myrealm/protocol/openid-connect/logout
```

**パラメータ:**
```plaintext
id_token_hint: 以前発行されたID Token（推奨）
post_logout_redirect_uri: ログアウト後のリダイレクト先
state: クライアントが状態を維持するための値
```

**リクエスト例:**
```bash
curl -X POST \
  "https://keycloak.example.com/auth/realms/myrealm/protocol/openid-connect/logout" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=my-app" \
  -d "refresh_token={refresh-token}"
```

### OIDC Session Management（非推奨）

iframe経由でセッション状態を監視。

**非推奨理由:**
- ブラウザのサードパーティCookie制限により機能不全
- Chrome、Safariで動作しないケースが増加

### OIDC Front-Channel Logout（非推奨）

iframeでログアウトURLを呼び出し。

**非推奨理由:**
- 信頼性が低い（完了確認不可）
- サードパーティCookie制限で動作しない

### 推奨Logout実装パターン

**パターン1: シンプル（推奨）**
```
- Access Token: 5分
- Refresh Token: 1時間
- Session Idle: 30分
- Logout: Session無効化のみ
- クライアント: Token expirationで自然にログアウト
```

**パターン2: 即座のLogout必要**
```
- Backchannel Logout有効化
- サーバーサイドアプリのみ対象
- ステートフルセッション管理
```

---

## OIDC Discovery Endpoint

クライアントがKeycloakの設定を動的に取得。

### Discovery Endpoint

```
https://keycloak.example.com/auth/realms/{realm}/.well-known/openid-configuration
```

### レスポンス例

```json
{
  "issuer": "https://keycloak.example.com/auth/realms/myrealm",
  "authorization_endpoint": "https://keycloak.example.com/auth/realms/myrealm/protocol/openid-connect/auth",
  "token_endpoint": "https://keycloak.example.com/auth/realms/myrealm/protocol/openid-connect/token",
  "userinfo_endpoint": "https://keycloak.example.com/auth/realms/myrealm/protocol/openid-connect/userinfo",
  "jwks_uri": "https://keycloak.example.com/auth/realms/myrealm/protocol/openid-connect/certs",
  "response_types_supported": ["code", "id_token", "token id_token"],
  "subject_types_supported": ["public"],
  "id_token_signing_alg_values_supported": ["RS256"],
  "scopes_supported": ["openid", "profile", "email"]
}
```

### 利点

- ハードコード不要（設定を動的取得）
- Keycloak設定変更への自動対応
- 標準仕様（OpenID Connect Discovery）準拠

---

## Device Authorization Grant

ブラウザなしデバイス（TV、IoT）向けOAuth 2.0フロー。

### フロー

```
1. デバイス → Keycloak: Device Authorization Request
2. Keycloak → デバイス: device_code, user_code, verification_uri
3. デバイス: ユーザーに user_code を表示
4. ユーザー: スマホ・PCで verification_uri にアクセス、user_code 入力
5. ユーザー: 認証・承認
6. デバイス → Keycloak: device_code でポーリング
7. Keycloak → デバイス: Access Token発行
```

### Device Authorization Request

```bash
curl -X POST \
  "http://localhost:8080/auth/realms/myrealm/protocol/openid-connect/device/auth" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=tv-app"
```

**レスポンス:**
```json
{
  "device_code": "abc123",
  "user_code": "XYZ456",
  "verification_uri": "http://keycloak.example.com/device",
  "expires_in": 1800,
  "interval": 5
}
```

### Token取得（ポーリング）

```bash
curl -X POST \
  "http://localhost:8080/auth/realms/myrealm/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=urn:ietf:params:oauth:grant-type:device_code" \
  -d "client_id=tv-app" \
  -d "device_code=abc123"
```

---

## Token Binding

トークンを特定のクライアントに紐付け、他のクライアントでの使用を防止。

### Token Binding有効化（Client設定）

```json
{
  "clientId": "my-app",
  "enabled": true,
  "authorizationServicesEnabled": true,
  "serviceAccountsEnabled": true,
  "attributes": {
    "oauth2.token.exchange.enabled": "true"
  }
}
```

### セキュリティ効果

```
通常のトークン:
  クライアントA → Token → クライアントB（使用可能）

Token Binding:
  クライアントA → Token → クライアントB（使用不可）
```

**防止できる攻撃:**
- Token Replay Attack（トークン再利用攻撃）
- Token Theft（トークン盗難）
