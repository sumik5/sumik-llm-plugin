# Keycloak コアコンセプト

## OIDC vs SAML

Keycloakは認証プロトコルとして**OpenID Connect (OIDC)**と**SAML (Security Assertion Markup Language)**の両方をサポートしている。

| 項目 | OIDC | SAML |
|------|------|------|
| **ベース** | OAuth 2.0上の認証レイヤー | XML ベースの標準 |
| **データ形式** | JSON (JWT) | XML |
| **用途** | モダンなWebアプリ・モバイルアプリ | エンタープライズ・レガシーシステム |
| **特徴** | 軽量、RESTful、ID Token/Access Token | 複雑な連携シナリオに対応、堅牢 |
| **トークン** | JWT (JSON Web Token) | XMLベースのAssertion |
| **ユースケース** | シングルページアプリ、API認証、クラウドアプリ | 企業内SSO、レガシー統合 |

### Realm・Client作成例

```bash
# Realm作成
/opt/keycloak/bin/kc.sh create-realm -s realm=example-realm

# OIDCクライアント追加
/opt/keycloak/bin/kc.sh create-client -r example-realm \
  -s clientId=oidc-client -s protocol=openid-connect

# SAMLクライアント追加
/opt/keycloak/bin/kc.sh create-client -r example-realm \
  -s clientId=saml-client -s protocol=saml
```

### Discovery Endpoint（OIDC）

OIDCでは、クライアントが1つのIssuer URLから必要なメタデータを自動取得可能。

**エンドポイント形式:**
```
<base URL>/.well-known/openid-configuration
```

**例:**
```bash
curl http://localhost:8080/realms/myrealm/.well-known/openid-configuration
```

**取得可能な情報:**
| フィールド | 説明 |
|-----------|------|
| `authorization_endpoint` | 認証リクエストURL |
| `token_endpoint` | トークン交換URL |
| `introspection_endpoint` | トークン検証URL |
| `userinfo_endpoint` | ユーザー情報取得URL |
| `grant_types_supported` | サポートするGrant Type一覧 |
| `response_types_supported` | サポートするResponse Type一覧 |
| `jwks_uri` | 公開鍵セット（署名検証用） |

**活用例:**
- ライブラリが動的にエンドポイントを発見（手動設定不要）
- OpenID Providerの切り替えが容易
- 標準準拠により相互運用性が向上

**判断基準**:
- **OIDC推奨**: 新規開発、モバイル、クラウドネイティブアプリ
- **SAML推奨**: 既存エンタープライズシステムとの統合、SAML準拠が必須の環境

---

## SSO（シングルサインオン）

Keycloakは複数アプリケーション間でのSSOを提供し、ユーザーが一度ログインすれば他のアプリにも自動的にアクセスできる。

### 設定手順

```bash
# Realm作成
/opt/keycloak/bin/kc.sh create-realm -s realm=sso-realm

# 1つ目のクライアント（app1）
/opt/keycloak/bin/kc.sh create-client -r sso-realm \
  -s clientId=app1 -s protocol=openid-connect \
  -s redirectUris="http://localhost:8080/app1/*"

# 2つ目のクライアント（app2）
/opt/keycloak/bin/kc.sh create-client -r sso-realm \
  -s clientId=app2 -s protocol=openid-connect \
  -s redirectUris="http://localhost:8080/app2/*"

# SSOセッション最大時間を10時間（36000秒）に設定
/opt/keycloak/bin/kc.sh update-realm -r sso-realm \
  -s ssoSessionMaxLifespan=36000
```

**ポイント**:
- セッションはKeycloakが一元管理
- redirectUrisを正確に設定する必要がある
- セッションライフスパンで利便性とセキュリティをバランス調整

---

## Realm

Realmは**独立した認証ドメイン**であり、ユーザー・ロール・クライアントを管理する論理的な区分。

### 設計パターン

| パターン | 用途 | 例 |
|---------|------|-----|
| **単一Realm** | 小規模アプリ、統一ユーザーベース | 社内アプリ統合 |
| **マルチRealm** | マルチテナント、環境分離 | dev/staging/prod、顧客ごとのテナント |

### REST APIでのRealm作成

```bash
# curlでRealm作成
curl -X POST "http://localhost:8080/auth/admin/realms" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <access_token>" \
  -d '{
    "realm": "my-realm",
    "enabled": true
  }'
```

**結果**:
```json
{
  "id": "my-realm-id",
  "realm": "my-realm",
  "enabled": true
}
```

**設計のポイント**:
- Realm単位で認証フロー、テーマ、パスワードポリシーをカスタマイズ可能
- マルチテナントSaaSではRealm分離が推奨

---

## Client

Clientは、ユーザーに代わって認証をリクエストする**アプリケーションまたはサービス**を表す。

### 設定項目

| 項目 | 説明 |
|------|------|
| **clientId** | クライアントの一意識別子 |
| **protocol** | `openid-connect` または `saml` |
| **redirectUris** | 認証後のリダイレクト先URL |
| **publicClient** | `true`: パブリッククライアント（例: SPA）<br>`false`: 機密クライアント（例: サーバーサイドアプリ） |

### Client登録例

```bash
# OIDCクライアント登録
curl -X POST "http://localhost:8080/auth/admin/realms/my-realm/clients" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <access_token>" \
  -d '{
    "clientId": "my-client",
    "enabled": true,
    "protocol": "openid-connect",
    "redirectUris": ["http://localhost:3000/*"]
  }'
```

**結果**:
```json
{
  "id": "my-client-id",
  "clientId": "my-client",
  "enabled": true,
  "protocol": "openid-connect"
}
```

**公開 vs 機密クライアント**:
- **公開**: SPAやモバイルアプリ（シークレット保存不可）
- **機密**: バックエンドサービス（シークレット保存可能）

---

## User

ユーザーは特定のRealmに属し、そのRealm内で管理される。

### ユーザー一覧取得

```bash
# RealmのユーザーをREST APIで取得
curl -X GET "http://localhost:8080/auth/admin/realms/myrealm/users" \
  -H "Authorization: Bearer <ACCESS_TOKEN>"
```

**結果**:
```json
[
  {
    "id": "user-id-123",
    "username": "john.doe",
    "enabled": true,
    "firstName": "John",
    "lastName": "Doe",
    "email": "john.doe@example.com"
  },
  {
    "id": "user-id-456",
    "username": "jane.smith",
    "enabled": true,
    "firstName": "Jane",
    "lastName": "Smith",
    "email": "jane.smith@example.com"
  }
]
```

**ポイント**:
- Realm単位でユーザー属性をカスタマイズ可能
- User Federationでexternal source（LDAP/AD）と連携可能

---

## Role

Roleは**ユーザーが実行可能な操作を定義する権限**。

### Realm Role vs Client Role

| 種類 | スコープ | 用途 |
|------|---------|------|
| **Realm Role** | Realm全体 | 全クライアントで共通の権限（例: `admin`, `user`） |
| **Client Role** | 特定クライアント | クライアント固有の権限（例: `editor`, `viewer`） |

### Role作成・割当例（kcadm.sh）

```bash
# Realm Role作成
kcadm.sh create roles -r myrealm -s name=admin

# Roleをユーザーに割当
kcadm.sh add-roles -r myrealm --uusername john --rolename admin

# Client Role作成
kcadm.sh create clients -r myrealm -s clientId=my-client
client_id=$(kcadm.sh get clients -r myrealm -q clientId=my-client | jq -r '.[0].id')
kcadm.sh create clients/$client_id/roles -r myrealm -s name=client_admin

# Client Roleを割当
kcadm.sh add-roles -r myrealm --uusername john --cclientid my-client --rolename client_admin
```

**ロール継承**:
- ロールは階層化可能
- 例: `admin`ロールが`editor`と`viewer`を継承すれば、両方の権限を自動取得

---

## Group

Groupはユーザーを組織化し、ロールをまとめて管理するための仕組み。

### Group管理例

```bash
# Group作成
curl -X POST "http://localhost:8080/auth/admin/realms/{realm}/groups" \
  -H "Authorization: Bearer {access_token}" \
  -H "Content-Type: application/json" \
  -d '{ "name": "Developers" }'

# Groupにロールを割当
curl -X POST "http://localhost:8080/auth/admin/realms/{realm}/groups/{group-id}/role-mappings/realm" \
  -H "Authorization: Bearer {access_token}" \
  -H "Content-Type: application/json" \
  -d '[{"name": "developer-role"}]'
```

**ポイント**:
- Groupは階層化可能（ネストされたサブグループ）
- Group内のすべてのユーザーがロールを継承

---

## User Federation

User FederationはKeycloakを外部ユーザーデータベース（LDAP/Active Directory等）と統合する機能。

### LDAP連携設定

```bash
# kcadm.shでLDAP User Federation作成
./kcadm.sh config credentials --server http://localhost:8080/auth \
  --realm master --user admin --password admin

./kcadm.sh create user-federation/instances -r myrealm \
  -s name=myldap -s provider=ldap \
  -s 'config={"connectionUrl":"ldap://localhost:389","usersDn":"ou=users,dc=example,dc=com","bindDn":"cn=admin,dc=example,dc=com","bindCredential":"password"}'
```

**設定パラメータ**:
| パラメータ | 説明 |
|-----------|------|
| `connectionUrl` | LDAPサーバーのURL |
| `usersDn` | ユーザーエントリのベースDN |
| `bindDn` | LDAPサーバーに接続するユーザーのDN |
| `bindCredential` | bindDnのパスワード |

**ポイント**:
- ユーザー属性の同期が可能
- グループメンバーシップやロールマッピングも連携可能
- 既存ユーザーデータベースをKeycloakで活用できる

---

---

## OAuth 2.0 詳細

### OAuth 2.0の役割

| 役割 | 説明 |
|------|------|
| **Resource Owner** | リソース所有者（通常はエンドユーザー） |
| **Resource Server** | 保護されたリソースをホストするサービス |
| **Client** | リソースへのアクセスを要求するアプリケーション |
| **Authorization Server** | アクセス許可を発行するサーバー（Keycloakの役割） |

### Grant Type選択基準

| 条件 | Grant Type |
|------|-----------|
| アプリ自身がリソース所有者 | **Client Credentials** |
| ブラウザ非搭載デバイス（Smart TV等） | **Device Flow** |
| 上記以外 | **Authorization Code** |

**⚠️ 非推奨（使用禁止）:**
- **Implicit Flow**: セキュリティリスク大
- **Resource Owner Password Credentials**: ユーザー認証情報をアプリに直接公開

### Authorization Code Flowの詳細ステップ

1. **Authentication Request生成**: アプリがリダイレクトURLを準備
2. **ユーザーエージェントリダイレクト**: Keycloak Authorization Endpointへ
3. **ユーザー認証**: Keycloakがログイン画面表示・認証実施
4. **Authorization Code発行**: Keycloakがアプリにcodeを返す
5. **Token Request**: アプリがcodeをToken Endpointに送信
6. **Token Response**: Access Token・Refresh Token・ID Token（OIDC）受領
7. **Resource Access**: Access Tokenでリソースサーバーにアクセス

### Confidential vs Public Client

| 項目 | Confidential Client | Public Client |
|------|---------------------|---------------|
| **定義** | Client Secretを安全に保存可能 | Client Secretを保存不可 |
| **例** | サーバーサイドアプリ | SPA、モバイルアプリ |
| **認証** | Client Secret使用 | 認証なし（PKCE必須） |
| **PKCE** | 推奨 | 必須 |

**PKCE（RFC 7636）:**
- Public Client向けのセキュリティ拡張
- Authorization Code傍受時の悪用を防止
- Code Verifier（ランダム値）とCode Challenge（ハッシュ値）を使用

### OAuth 2.0関連仕様

| 仕様 | 説明 |
|------|------|
| **Bearer Tokens (RFC 6750)** | Access Tokenの送信方法（HTTP Authorization Header推奨） |
| **Token Introspection (RFC 7662)** | Token内容の検証エンドポイント |
| **Token Revocation (RFC 7009)** | Token失効エンドポイント |

---

## OpenID Connect（OIDC）詳細

### OIDCの役割

| 役割 | 説明 |
|------|------|
| **End User** | 認証されるエンドユーザー（OAuth 2.0のResource Owner） |
| **Relying Party (RP)** | ユーザー認証を依頼するアプリ（OAuth 2.0のClient） |
| **OpenID Provider (OP)** | ユーザーを認証するサーバー（Keycloakの役割） |

### OIDCとOAuth 2.0の違い

| 項目 | OAuth 2.0 | OpenID Connect |
|------|-----------|---------------|
| **目的** | 認可（Authorization） | 認証（Authentication） |
| **返却** | Access Token | ID Token + Access Token |
| **scopeパラメータ** | 任意 | `openid`必須 |
| **UserInfo Endpoint** | なし | あり |

### Authorization Code Flowの比較

**OAuth 2.0:**
1. Authorization Request (`scope=api.read`)
2. Authorization Code受領
3. Token Request → **Access Token**のみ

**OpenID Connect:**
1. Authentication Request (`scope=openid profile email`)
2. Authorization Code受領
3. Token Request → **ID Token + Access Token + Refresh Token**

### ID Token構造（JWT）

**ヘッダー:**
```json
{
  "alg": "RS256",
  "typ": "JWT",
  "kid": "key-id-123"
}
```

**ペイロード（Claims）:**
| Claim | 説明 |
|-------|------|
| `iss` | 発行者（Keycloak URL） |
| `sub` | ユーザー一意識別子 |
| `aud` | 受信者（Client ID） |
| `exp` | 有効期限（Unix Epoch） |
| `iat` | 発行時刻 |
| `auth_time` | ユーザー認証時刻 |
| `nonce` | リプレイ攻撃防止 |

**カスタムClaims（例）:**
```json
{
  "sub": "user-123",
  "email": "alice@example.com",
  "given_name": "Alice",
  "family_name": "Smith",
  "realm_access": {
    "roles": ["admin", "user"]
  }
}
```

### UserInfo Endpoint

**リクエスト:**
```bash
curl -H "Authorization: Bearer {access_token}" \
  http://localhost:8080/realms/myrealm/protocol/openid-connect/userinfo
```

**レスポンス:**
```json
{
  "sub": "user-123",
  "email": "alice@example.com",
  "email_verified": true,
  "name": "Alice Smith",
  "preferred_username": "alice"
}
```

**ID Token vs UserInfo:**
- ID Token: クライアント側でオフライン検証可能
- UserInfo: 最新のユーザー情報を動的取得（リアルタイム性）

---

## JWT（JSON Web Token）詳細

### JWT構造

```
<Header>.<Payload>.<Signature>
```

**例:**
```
eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.
eyJzdWIiOiJ1c2VyLTEyMyIsImV4cCI6MTY3ODkwMTIzNH0.
signature_base64url
```

### JOSE仕様ファミリー

| 仕様 | 説明 |
|------|------|
| **JWT (RFC 7519)** | トークン基本構造（Header + Payload） |
| **JWS (RFC 7515)** | 署名追加 |
| **JWE (RFC 7516)** | 暗号化 |
| **JWA (RFC 7518)** | 暗号アルゴリズム定義 |
| **JWK (RFC 7517)** | 鍵のJSON表現 |

### JWT検証手順（Resource Server）

1. **Discovery Endpoint**からJWKS URLを取得
2. **JWKS URL**から公開鍵セットをダウンロード（キャッシュ推奨）
3. **JWTヘッダー**の`kid`で該当公開鍵を特定
4. **署名検証**: ペイロードとシグネチャの整合性確認
5. **Claimsチェック**: `exp`（有効期限）、`aud`（受信者）等を検証

### JWT脆弱性と対策

| 脆弱性 | 攻撃例 | 対策 |
|--------|--------|------|
| **alg=none** | 署名なしJWTを受理 | `alg=none`を拒否 |
| **RSA to HMAC** | 公開鍵をHMAC秘密鍵として悪用 | アルゴリズムと鍵タイプを厳密にチェック |
| **鍵混同** | 意図しない鍵で検証 | `kid`と`use`（signing/encryption）を検証 |

**推奨:**
- 信頼できるJWTライブラリを使用
- OpenID Connect/OAuth 2.0ライブラリに任せる
- 自前検証は最終手段（Token Introspection Endpointを優先）

---

## 分散認証の課題

モダンな分散システム（マイクロサービス、クラウドネイティブアプリケーション）では、認証機構の実装に特有の複雑性が存在する。

### クロスドメインIdentity管理

分散システムでは複数の管理境界、クラウド環境、サードパーティサービスにまたがる認証が必要となる。

**課題:**
- 異なるトークン形式・有効期限ポリシー・暗号要件の統合
- ドメイン間のトラスト確立
- プライバシーを保ちつつ過剰な負荷をかけずにIdentityを伝搬

**対策:**
- OAuth 2.0、OpenID Connect、SAMLといった標準プロトコルの活用
- トークンスコープとクレーム管理の適切な設計
- 特権昇格を防ぐための最小権限トークン発行

### セッション管理

従来のステートフルなセッション管理は、クラウドネイティブ・マイクロサービスのステートレス原則と衝突する。

**課題:**
- マイクロサービス間でのトークン伝搬時のセッション継続性維持
- トークン失効・更新・有効期限の同期
- リプレイ攻撃や不正アクセスを防ぐための一貫したトークン無効化

**実装パターン:**
| アプローチ | 特徴 | トレードオフ |
|-----------|------|------------|
| **JWT（短命）** | ステートレス、高速 | 失効が即座に反映されない |
| **Opaque Token + 集中セッションストア** | 即座の失効が可能 | レイテンシ・状態管理オーバーヘッド増 |
| **Token Blacklist** | JWT失効を補完 | Blacklist管理の複雑性 |

### スケーラビリティ

認証システムは負荷変動に対応し、レイテンシや信頼性を損なわずにスケールする必要がある。

**ボトルネック:**
- 集中型IdPやトークン検証エンドポイント
- トークン検証結果のキャッシュによる不整合リスク

**対策:**
- 水平スケーリング・弾力的スケーリング
- ロードバランシング
- 非同期トークンイントロスペクション
- 不変インフラ対応の自動状態同期

### 耐障害性

分散システムでは、一時的な障害・ネットワーク分断・サービス停止に対して、セキュリティ保証を損なわずに対処する必要がある。

**設計要件:**
- 外部IdP障害時のフォールバック・リトライ戦略
- サーキットブレーカー
- グレースフルデグレード（即座に認証検証できない場合）
- 複数認証プロトコル共存時の一貫性維持

### セキュリティ考慮事項

分散コンポーネントと通信チャネルの数に比例して攻撃対象領域が拡大する。

**リスク:**
- トークン傍受・偽造・リプレイ攻撃
- サービス間のラテラルムーブメント

**ベストプラクティス:**
- 広範なTLS採用とサービス間相互認証
- Zero Trustアーキテクチャ（継続的Identity検証、ネットワーク位置による暗黙の信頼を排除）
- 細粒度の認可モデル
- 継続的監視・異常検知・セキュアな監査証跡

---

## Zero Trust Architecture（ゼロトラスト）

従来の境界防御モデルを刷新し、すべてのアクター・システム・ネットワークセグメントを本質的に信頼しない前提で動作するアーキテクチャ。

### 主要原則

| 原則 | 説明 |
|------|------|
| **すべてのアクセス試行を検証** | ネットワーク起点に関わらず、すべてのユーザー・デバイス・ワークロード間の相互作用で認証・認可が必要 |
| **最小権限アクセス** | タスク実行に必要な最小限のリソースに権限を制限 |
| **マイクロセグメンテーション** | ネットワークリソースを細粒度のゾーンに分割し、ゾーン間通信を厳密に管理 |
| **継続的監視・ログ記録** | すべてのアクティビティをリアルタイムでログ・分析し、異常を検出して迅速に対応 |

### Keycloakとの連携

- **多要素認証（MFA）・適応型認証**: デバイス健全性、位置情報、アクセス時刻、ユーザー行動分析といったコンテキスト信号を統合
- **条件付きアクセスポリシー**: リスク要因に基づいた動的な認証要件調整
- **セッション継続的検証**: 異常動作検知時の即座のトークン失効・再認証

---

## コンプライアンス・規制対応

認証システムはGDPR、HIPAA、PCI DSS、SOX等の規制要件に適合する必要がある。

### GDPR（一般データ保護規則）

**要件:**
- データ最小化（必要最小限の個人データ収集）
- ユーザー同意の明示的取得
- データ処理活動の透明性

**Keycloak実装:**
- 認証プロセスで収集する個人データを必要最小限に制限
- ユーザーへのデータ処理に関する明確な情報提供
- 同意記録の監査可能性確保

### HIPAA（医療保険の携行性と責任に関する法律）

**要件:**
- 電子保護医療情報（ePHI）の保護
- アクセス制御による不正アクセス防止
- ユーザー活動の監査（改ざん防止、指定期間の保持）

**Keycloak実装:**
- Fine-Grained Permissionsによるアクセス制御
- Event LoggingとAdmin Event Trackingによる改ざん防止可能な監査証跡

### PCI DSS（ペイメントカード業界データセキュリティ基準）

**要件:**
- カード会員データアクセス権限を持つシステム管理者に多要素認証必須

**Keycloak実装:**
- Browser Flow + OTP/TOTP
- 条件付き認証によるMFA強制

### SOX（サーベンス・オクスリー法）

**要件:**
- 財務記録の正確性維持
- 財務システム・データへのアクセスが認可された者のみに制限

**Keycloak実装:**
- Role-Based Access Control（RBAC）
- 詳細な監査ログ

### 実装アーキテクチャ原則

| 原則 | 説明 |
|------|------|
| **モジュラーな同意フレームワーク** | 同意管理を認証ロジックから分離し、コアプロセスを中断せずに動的更新可能 |
| **フェデレーテッドIdentityと最小開示** | 必要な属性のみを信頼境界間で共有（データ最小化） |
| **不変な監査証跡** | ブロックチェーンや暗号検証ログで監査証跡の整合性・証拠価値を確保 |
| **ユーザー中心のプライバシー制御** | ユーザーが自身の同意を閲覧・変更・取り消し可能 |
| **リスク適応型認証** | リスクシグナルに基づいて認証要件を動的調整 |

---

## データ永続化戦略

Keycloakはエンタープライズグレードのデータ永続化戦略を採用し、高可用性とスケーラビリティを実現。

### データベーススキーマ

**構成:**
- Realmメタデータ（認証フロー、テーマ、パスワードポリシー）
- ユーザー・ロール・グループ情報
- クライアント設定・リダイレクトURI
- セッション情報（短命セッションは別ストア推奨）

**サポートDB:**
- PostgreSQL（推奨）、MySQL、MariaDB、Oracle、Microsoft SQL Server
- 分散環境ではマスター/レプリカ構成やクラスタリングが可能

### キャッシュ層（Infinispan）

Keycloakは**Infinispan**を分散キャッシュとして使用し、データベース負荷を軽減しつつ低レイテンシを実現。

**キャッシュ対象:**
| キャッシュタイプ | 内容 |
|----------------|------|
| **Realm Cache** | Realm設定・クライアント設定・認証フロー定義 |
| **User Cache** | ユーザー属性・ロール・グループメンバーシップ |
| **Authorization Cache** | Resource-Based Permissions、Policies |
| **Session Cache** | アクティブなユーザーセッション・クライアントセッション |

**クラスタモード:**
- Infinispanクラスタにより、複数Keycloakインスタンス間でキャッシュデータを共有
- セッションのフェイルオーバーサポート
- キャッシュ無効化メッセージのブロードキャストによる一貫性維持

**設定例（standalone-ha.xml）:**
```xml
<cache-container name="keycloak" module="org.keycloak.keycloak-model-infinispan">
  <replicated-cache name="sessions">
    <transaction mode="NON_XA"/>
  </replicated-cache>
  <distributed-cache name="authenticationSessions">
    <transaction mode="NON_XA"/>
  </distributed-cache>
</cache-container>
```

### セッションストレージ戦略

| 戦略 | 用途 | 利点 | 注意点 |
|------|------|------|--------|
| **In-Memory（Infinispan）** | 短命セッション・高速アクセス | 超低レイテンシ | ノード障害時のデータロスリスク |
| **Database** | 長期セッション・監査要件 | 永続性・検索可能 | DB負荷増加 |
| **Hybrid** | 短命セッションはInfinispan、長期セッションはDB | パフォーマンスと永続性のバランス | 複雑な設定 |

---

## Keycloakセキュリティ基盤

### 暗号化

**トランスポート暗号化（TLS/SSL）:**
- すべてのクライアント・Keycloak間通信はHTTPSで保護
- サービス間通信（Infinispan、DB）もTLS推奨

**データ暗号化:**
- パスワードはbcrypt/PBKDF2でハッシュ化
- 機密属性（Client Secret等）は暗号化してDB保存

### 証明書管理

**Realm証明書:**
- 各RealmはJWT署名用の公開鍵・秘密鍵ペアを保持
- Admin ConsoleまたはCLIで証明書ローテーション可能

**鍵ローテーション:**
```bash
# 新しい鍵ペア生成
kcadm.sh create keys/generated -r myrealm \
  -s priority=110 -s algorithm=RS256

# 古い鍵の優先度を下げる（即座削除せず段階的移行）
kcadm.sh update keys/{key-id} -r myrealm -s priority=50
```

### Vault統合

機密情報（DB接続文字列、IdP Client Secret等）を外部Vault（HashiCorp Vault等）で管理。

**設定例（standalone.xml）:**
```xml
<spi name="vault">
  <default-provider>files-plaintext</default-provider>
  <provider name="files-plaintext" enabled="true">
    <properties>
      <property name="dir" value="${jboss.server.config.dir}/vault"/>
    </properties>
  </provider>
</spi>
```

**利用方法:**
```bash
# Vault参照記法（設定内）
${vault.db_password}
```

**利点:**
- 設定ファイルに平文パスワードを記述しない
- Vault側で集中的に機密情報を管理・ローテーション可能
- 監査証跡をVault側で一元管理
