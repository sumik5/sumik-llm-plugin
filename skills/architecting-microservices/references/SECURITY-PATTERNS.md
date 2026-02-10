# マイクロサービスセキュリティパターン

## 概要

マイクロサービスアーキテクチャでは、サービスが分散し、内部ネットワーク上で多数のサービス間通信が発生します。API Gatewayを保護するだけでは不十分であり、各マイクロサービス（Resource Server）も適切に保護する必要があります。このドキュメントでは、OAuth 2.0、JWT、API Gatewayセキュリティパターンを解説します。

---

## OAuth 2.0フロー

### OAuth 2.0 の役割（Roles）

OAuth 2.0は、以下の4つの役割を定義します：

| 役割 | 説明 | マイクロサービスでの例 |
|-----|------|----------------------|
| **Resource Owner** | 保護されたリソースへのアクセスを許可できるエンティティ（通常はエンドユーザー） | 顧客、管理者 |
| **Resource Server** | 保護されたリソースをホストするサーバー。アクセストークンを検証し、リクエストを受け入れる | 各マイクロサービス（Order Service、Product Service等） |
| **Client** | Resource Ownerの代わりに保護されたリソースへリクエストを行うアプリケーション | API Gateway、Webアプリケーション |
| **Authorization Server** | Resource Ownerの認証と認可を行い、Clientにアクセストークンを発行するサーバー | 独立した認証サービス |

### OAuth 2.0 Authorization Code Grant Flow（9ステップ）

Authorization Code Grant TypeはOAuth 2.0で最も安全なフローであり、Clientがサーバーサイドで実行され、クライアントシークレットを安全に保持できる場合に適しています。

**フロー図（テキストベース）：**

```
┌──────────────┐
│  Resource    │
│   Owner      │  (1) ブラウザでURLにアクセス
│ (End User)   │
└──────┬───────┘
       │
       v (2) SPAダウンロード・レンダリング
┌──────────────┐
│  User Agent  │
│  (Browser)   │  (3) ユーザーアクション（保護されたリソースへのアクセス）
└──────┬───────┘
       │
       v (4) 認証要求（client_id, redirect_uri, scope含む）
┌──────────────┐
│    Client    │ ← API Gateway
│ (API Gateway)│
└──────┬───────┘
       │
       v (5) ユーザーをAuthorization Endpointへリダイレクト
┌──────────────────────┐
│ Authorization Server │  (6) Resource Ownerの認証（username/password等）
│                      │
└──────┬───────────────┘
       │
       v (7) 内部認証サーバーで検証（Username/Password、証明書、SSO等）
       │
       v (8) 認証成功 → Authorization Code発行 → Clientへリダイレクト
       │
┌──────────────┐
│    Client    │
│ (API Gateway)│  (9) Authorization CodeをToken Endpointへ送信
└──────┬───────┘
       │
       v (10) Authorization Code検証 → Access Token + Refresh Token発行
       │
┌──────────────────────┐
│ Authorization Server │
└──────────────────────┘
       │
       v (11) Access Tokenを保護されたリソースへ送信（Authorization: Bearer <token>）
┌──────────────┐
│   Resource   │
│    Server    │  (12) Token検証（Validation Endpoint / Public Key検証）
└──────┬───────┘
       │
       v (13) Token有効 → 保護されたリソースを返す
       │
       v (14) Clientがリソースを User Agent (Browser) へ返す
```

**各ステップの詳細：**

1. **Resource OwnerがブラウザでURLにアクセス**
2. **User Agentが SPA（Single Page Application）をダウンロードし、レンダリング**
3. **ユーザーアクション（保護されたリソースへのアクセスを要求）**
4. **Client（API Gateway）が認証要求を開始**
   - `client_id`, `redirect_uri`, `scope`, `state` を含む
5. **Authorization ServerのAuthorization Endpointへリダイレクト**
6. **Resource Ownerの認証（Username/Password入力等）**
7. **内部認証サーバーで検証**（Username/Password、証明書、SSO、LDAP等）
8. **認証成功 → Authorization Code発行 → Clientへリダイレクト**
9. **ClientがAuthorization CodeをToken Endpointへ送信**（client_id, client_secret, authorization_code, redirect_uri含む）
10. **Authorization ServerがAuthorization Codeを検証 → Access Token + Refresh Token発行**
11. **ClientがAccess TokenをResource Serverへ送信**（`Authorization: Bearer <access_token>`ヘッダー）
12. **Resource ServerがTokenを検証**（Validation Endpoint呼び出し or Public Key検証）
13. **Token有効 → 保護されたリソースを返す**
14. **Clientがリソースを User Agent（Browser）へ返す**

---

## JWT（JSON Web Token）設計

### JWTの構造

JWTは、以下の3つのパートから構成されます（Base64エンコード、`.`で連結）：

```
[Base64Encoded(HEADER)].[Base64Encoded(PAYLOAD)].[Base64Encoded(SIGNATURE)]
```

**1. Header（ヘッダー）:**
- トークンのメタデータ（署名アルゴリズム、トークンタイプ）

```json
{
  "alg": "RS256",
  "typ": "JWT"
}
```

**2. Claims（ペイロード）:**
- ユーザー情報、権限、有効期限等のデータ

```json
{
  "sub": "1234567890",
  "name": "John Doe",
  "iat": 1516239022,
  "exp": 1516242622,
  "scope": "user",
  "roles": ["CUSTOMER"]
}
```

**標準的なClaim：**

| Claim | 説明 |
|-------|------|
| `iss` (Issuer) | トークン発行者 |
| `sub` (Subject) | トークンの主体（ユーザーID等） |
| `aud` (Audience) | トークンの受信者 |
| `exp` (Expiration Time) | 有効期限（UNIX timestamp） |
| `nbf` (Not Before) | トークンが有効になる時刻 |
| `iat` (Issued At) | 発行時刻 |
| `jti` (JWT ID) | トークンの一意識別子（nonce） |

**3. Signature（署名）:**
- Header + Claimsを秘密鍵で署名（改ざん防止）

```
HMACSHA256(
  base64UrlEncode(header) + "." + base64UrlEncode(payload),
  secret
)
```

### Access Token vs Refresh Token

| トークンタイプ | 有効期限 | 用途 | セキュリティ特性 |
|--------------|---------|------|----------------|
| **Access Token** | 短期（例：15分〜1時間） | Resource Serverへのアクセス | 漏洩時の影響を最小化 |
| **Refresh Token** | 長期（例：7日〜30日） | Access Token再発行 | 安全に保管、HTTPSのみで送信 |

**Refresh Token活用フロー：**

```
1. Access Token有効期限切れ
2. ClientがRefresh TokenをAuthorization Serverへ送信
3. Refresh Token検証成功 → 新しいAccess Token発行
4. 新しいAccess Tokenで保護されたリソースへアクセス
```

### トークン検証パターン

#### パターン1: Validation Endpoint方式

```
[Resource Server] ---(1) Token検証リクエスト--->  [Authorization Server]
                  <---(2) 検証結果（有効/無効）---
```

**メリット:** トークンの即座無効化が可能（リアルタイム検証）
**デメリット:** Authorization Serverへの追加通信が発生、スケーラビリティ課題

#### パターン2: Public Key検証方式（推奨）

```
[Resource Server]
    |
    +--- (1) Public Key取得（初回のみ、またはキャッシュ）
    |         from Authorization Server
    |
    +--- (2) トークン署名をPublic Keyで検証
             （Authorization Serverへの通信不要）
```

**メリット:** スケーラブル、Authorization Serverへの負荷軽減
**デメリット:** トークン有効期限前の無効化が困難（短い有効期限で対応）

---

## API Gatewayセキュリティパターン

### DMZ内のAPI GatewayでOAuth認証・認可

**アーキテクチャ概念図：**

```
[Internet]
    |
    v
┌─────────────────────────────────────────────┐
│  DMZ (Demilitarized Zone)                   │
│                                             │
│  ┌─────────────┐      ┌──────────────────┐ │
│  │ API Gateway │◄────►│ Authorization    │ │
│  │  (Client)   │      │     Server       │ │
│  └─────┬───────┘      └──────────────────┘ │
│        │                                    │
└────────┼────────────────────────────────────┘
         │ (Access Token付きリクエスト)
         v
┌─────────────────────────────────────────────┐
│  Internal Network                           │
│                                             │
│  ┌───────────┐  ┌───────────┐  ┌─────────┐ │
│  │  Order    │  │  Product  │  │Customer │ │
│  │  Service  │  │  Service  │  │ Service │ │
│  │(Resource  │  │(Resource  │  │(Resource│ │
│  │ Server)   │  │ Server)   │  │ Server) │ │
│  └───────────┘  └───────────┘  └─────────┘ │
└─────────────────────────────────────────────┘
```

**API Gatewayの責務：**

1. **OAuth Clientとして機能**
   - Client ID / Client Secretを安全に保持（DMZ内）
   - Authorization Code Grant Flowを実行

2. **Reference Token ↔ JWT変換**
   - ブラウザには**Reference Token**（短い識別子）を返す
   - 内部では**JWT（実際のAccess Token）**をキャッシュ
   - マイクロサービスへのリクエスト時、Reference TokenをJWTに変換して送信

3. **Rate Limiting（レート制限）**
   - 過度なリクエストを制限（DDoS対策）
   - ユーザーごと、IPごと、APIエンドポイントごとの制限

4. **リクエスト変換・フィルタリング**
   - 外部向けAPIと内部向けAPIのプロトコル変換
   - 不正なリクエストのフィルタリング（SQLインジェクション、XSS等）

### Reference Token パターン

**Reference Tokenを使用する理由：**
- JWTはサイズが大きい（数百〜数千バイト）→ HTTPヘッダーサイズ制限
- JWTに機密情報が含まれる場合、DMZ外に出したくない

**Reference Token生成例（擬似コード）：**

```
Function createReferenceToken(username, expiryTime):
    raw = username + ":" + expiryTime + ":" + SECRET_SALT
    return MD5(raw)  // 短い識別子を生成

Function cacheToken(referenceToken, jwt):
    cache.put(referenceToken, jwt)  // EHCache等

Function retrieveJWT(referenceToken):
    return cache.get(referenceToken)
```

**フロー：**

```
1. User Agentが認証成功 → Authorization ServerがJWT発行
2. API GatewayがJWTを受信 → Reference Tokenを生成
3. API GatewayがJWTをキャッシュに保存（Reference Token → JWT）
4. User AgentにはReference Tokenのみを返す（HTTPヘッダー: x-token）
5. 以降のリクエスト時、User AgentはReference Tokenを送信
6. API GatewayがReference TokenをキャッシュからJWTに変換
7. マイクロサービスへJWTを送信（Authorization: Bearer <JWT>）
```

---

## マイクロサービス間トークン伝播パターン

### Authorization Header自動伝播

マイクロサービス間の呼び出しでも、元のAccess Tokenを伝播させる必要があります。

**パターン1: 明示的伝播（手動）**

```
Service A:
    Function callServiceB(requestData):
        accessToken = getCurrentAccessToken()  // コンテキストから取得
        headers = { "Authorization": "Bearer " + accessToken }
        response = httpClient.post("http://service-b/api", requestData, headers)
        return response
```

**パターン2: インターセプター自動伝播（推奨）**

```
Global HTTP Interceptor:
    Before Request:
        accessToken = getCurrentAccessToken()
        request.headers.add("Authorization", "Bearer " + accessToken)

Service A:
    Function callServiceB(requestData):
        // Authorizationヘッダーは自動的に付与される
        response = httpClient.post("http://service-b/api", requestData)
        return response
```

### サービス間認証（Service-to-Service Auth）

**シナリオ:** バックグラウンドジョブやCronジョブがマイクロサービスを呼び出す場合、エンドユーザーがいない。

**解決策: Client Credentials Grant**

```
Background Job:
    Function callServiceB():
        // Client Credentials Grant でAccess Token取得
        token = authServer.getToken(clientId, clientSecret, scope="service-b")
        headers = { "Authorization": "Bearer " + token }
        response = httpClient.post("http://service-b/api", data, headers)
        return response
```

---

## セキュリティ判断基準テーブル

### OAuth 2.0 Grant Type選択

| シナリオ | 推奨Grant Type | 理由 |
|---------|---------------|------|
| サーバーサイドWebアプリ（API Gateway） | **Authorization Code Grant** | Client Secretを安全に保持可能 |
| SPAアプリ（JavaScriptのみ） | **Authorization Code Grant + PKCE** | SPAはClient Secretを保持できないためPKCE必須 |
| モバイルアプリ | **Authorization Code Grant + PKCE** | モバイルアプリもClient Secretを安全に保持できない |
| サービス間通信（エンドユーザーなし） | **Client Credentials Grant** | サービスアカウント認証 |
| IoTデバイス | **Device Code Grant** | 入力制約のあるデバイス向け |

### トークン検証方式選択

| 条件 | 推奨方式 |
|-----|---------|
| 高トラフィック、低レイテンシ要求 | **Public Key検証** |
| リアルタイムトークン無効化が必要 | **Validation Endpoint** |
| Authorization Server負荷を軽減したい | **Public Key検証** |
| トークン有効期限が短い（< 15分） | **Public Key検証** |

### 対称鍵 vs 非対称鍵署名

| 方式 | 特徴 | 適用シーン |
|-----|------|-----------|
| **対称鍵（HMAC）** | 同じ秘密鍵で署名・検証 | Authorization ServerとResource Serverが同一組織 |
| **非対称鍵（RSA, ECDSA）** | 秘密鍵で署名、公開鍵で検証 | Resource Serverが複数、または外部組織 |

---

## Trust Zone / DMZ設計

### 3層セキュリティゾーン

```
┌──────────────────────────────────────┐
│  Internet (Untrusted Zone)           │
└────────────┬─────────────────────────┘
             │
             v
┌──────────────────────────────────────┐
│  DMZ (Demilitarized Zone)            │
│                                      │
│  ◆ HTTP Server / Load Balancer      │
│  ◆ API Gateway (OAuth Client)       │
│  ◆ Authorization Server              │
│                                      │
│  [厳格なアクセス制御・ファイアウォール]│
└────────────┬─────────────────────────┘
             │
             v
┌──────────────────────────────────────┐
│  Internal Network (Trusted Zone)     │
│                                      │
│  ◆ Microservices (Resource Servers) │
│  ◆ Databases                         │
│  ◆ Message Queues                    │
│  ◆ Cache Servers                     │
│                                      │
└──────────────────────────────────────┘
```

**DMZの役割：**
- 外部からの不正アクセスを防御（第1防御線）
- 内部ネットワークへの侵入を遅延・検知
- 認証・認可の集約ポイント

**Trust Zoneの保護：**
- DMZを通過したトラフィックのみ許可
- マイクロサービス間通信もトークン検証を実施（Zero Trust原則）
- 内部ネットワークも暗号化（TLS）を推奨

---

## セキュリティベストプラクティス

### トークン管理

1. **Access Tokenは短期間（15分〜1時間）**
   - 漏洩時の影響を最小化
2. **Refresh Tokenは安全に保管**
   - HttpOnly Cookie推奨（JavaScriptからアクセス不可）
3. **トークンはHTTPSでのみ送信**
   - 平文HTTP通信は禁止
4. **Nonce（jti）で再生攻撃を防止**
   - 各リクエストでユニークなトークン使用

### Resource Server実装

1. **Token検証は必須**
   - すべてのエンドポイントで検証
2. **Scope・Roleベースの認可**
   - `@PreAuthorize("hasAuthority('ORDER_WRITE')")`
3. **Rate Limiting実装**
   - API乱用を防止
4. **監査ログ記録**
   - すべてのアクセスをログに記録（GDPR対応）

---

## まとめ

マイクロサービスセキュリティは、以下の原則に基づきます：

1. **OAuth 2.0 Authorization Code Grant**: API Gatewayが安全にトークンを取得
2. **JWT**: 自己完結型トークンでスケーラブルな検証
3. **API GatewayでのDMZ保護**: 認証・認可・Rate Limitingの集約
4. **Reference Token**: JWTをDMZ内に留め、外部には短い識別子のみ公開
5. **マイクロサービス間トークン伝播**: Authorization Headerの自動伝播
6. **Public Key検証**: スケーラブルなトークン検証
7. **Trust Zone分離**: DMZと内部ネットワークの明確な分離
