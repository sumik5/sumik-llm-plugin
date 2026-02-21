# Keycloak IAM ガイド

## 概要

Keycloakはオープンソースの統合アイデンティティ・アクセス管理（IAM）ソリューションです。OpenID Connect（OIDC）とSAML 2.0プロトコルをサポートし、SSO、ユーザー管理、認証・認可、トークン管理、マルチテナント対応を提供します。

## Keycloakアーキテクチャ階層

Keycloakは以下の階層構造で設計されています：

```
Realm（認証ドメイン）
└── Client（認証を要求するアプリケーション）
    └── User（エンドユーザー）
        ├── Role（権限）
        │   ├── Realm Role（グローバル権限）
        │   └── Client Role（Client固有権限）
        └── Group（ユーザーグループ）
```

### コア概念クイックリファレンス

| 概念 | 説明 | 用途例 |
|------|------|--------|
| **Realm** | 独立した認証ドメイン（ユーザー、Client、Roleを隔離） | マルチテナント環境（internal-realm, external-realm） |
| **Client** | 認証を要求するアプリケーション・サービス | Webアプリ、モバイルアプリ、REST API |
| **User** | Realm内のエンドユーザー（外部IdP連携可能） | 従業員、顧客、パートナー |
| **Role** | ユーザーの権限を定義（Realm Role / Client Role） | admin, editor, viewer |
| **Group** | 複数ユーザーをまとめて管理（Roleを継承） | engineering-team, sales-team |
| **User Federation** | 外部ユーザーデータベース連携（LDAP/AD） | 既存社内LDAPとの統合 |
| **Identity Provider** | 外部IdP連携（Social Login, SAML IdP） | Google, GitHub, Azure AD |
| **Client Scope** | Clientが要求できるスコープ（トークンに含まれるクレーム） | profile, email, roles |
| **Protocol Mapper** | トークン/アサーションに含まれる属性をカスタマイズ | カスタムクレーム追加 |
| **Authentication Flow** | 認証プロセスのステップ定義（MFA含む） | ブラウザフロー、Direct Grant、Registration |
| **Authorization Policy** | リソースベース認可ポリシー（UMA 2.0対応） | ファイルアクセス制御、APIエンドポイント保護 |
| **Session** | ユーザーの認証状態（SSO対応） | オンライン/オフラインセッション、Remember Me |
| **Token** | 認証・認可情報を含むトークン（JWT/SAML） | Access Token, ID Token, Refresh Token |

---

## よく使うCLI/APIコマンド一覧

### kcadm.sh（Admin CLI）主要コマンド

```bash
# ログイン → Realm作成 → Client作成 → User作成 → Role割当
kcadm.sh config credentials --server http://localhost:8080/auth --realm master --user admin
kcadm.sh create realms -s realm=my-realm -s enabled=true
kcadm.sh create clients -r my-realm -s clientId=my-client -s protocol=openid-connect
kcadm.sh create users -r my-realm -s username=john -s enabled=true
kcadm.sh set-password -r my-realm --username john --new-password secret
kcadm.sh create roles -r my-realm -s name=admin
kcadm.sh add-roles -r my-realm --uusername john --rolename admin
```

### Admin REST API主要エンドポイント

```bash
# Token取得 → Realm/Client/User作成
TOKEN=$(curl -X POST "http://localhost:8080/auth/realms/master/protocol/openid-connect/token" \
  -d "username=admin&password=admin&grant_type=password&client_id=admin-cli" | jq -r '.access_token')
curl -X POST "http://localhost:8080/auth/admin/realms" -H "Authorization: Bearer $TOKEN" \
  -d '{"realm": "my-realm", "enabled": true}'
```

### OIDC Token取得（Application側）

```bash
# Authorization Code Flow
curl -X POST "http://localhost:8080/auth/realms/my-realm/protocol/openid-connect/token" \
  -d "grant_type=authorization_code&code=CODE&client_id=my-client&client_secret=SECRET"
# Token Introspection
curl -X POST "http://localhost:8080/auth/realms/my-realm/protocol/openid-connect/token/introspect" \
  -d "token=TOKEN&client_id=my-client&client_secret=SECRET"
```

---

## 典型的なセットアップワークフロー

### 基本セットアップ（8ステップ）

```bash
# 1. Realm作成 → 2. Client登録 → 3. User作成 → 4. Role作成 → 5. Role割当
kcadm.sh create realms -s realm=prod-realm -s enabled=true
kcadm.sh create clients -r prod-realm -s clientId=webapp -s protocol=openid-connect
kcadm.sh create users -r prod-realm -s username=alice -s enabled=true
kcadm.sh create roles -r prod-realm -s name=admin
kcadm.sh add-roles -r prod-realm --uusername alice --rolename admin
# 6. SSO設定 → 7. MFA有効化 → 8. テスト
```

### LDAP/AD連携（Admin Console）

```
User Federation > Add provider > ldap
- Connection URL: ldap://ldap.example.com:389
- Users DN: ou=users,dc=example,dc=com
- Mappers: uid→username, mail→email, memberOf→roles
- Sync all users
```

### Social Login統合（Google例・Admin Console）

```
Identity Providers > Add provider > Google
- Client ID: GOOGLE_CLIENT_ID
- Client Secret: GOOGLE_CLIENT_SECRET
- Mappers: email → user role
```

---

## 判断基準テーブル

### 認証プロトコル選択（OIDC vs SAML）

| 基準 | OIDC（推奨） | SAML 2.0 |
|------|-------------|---------|
| **用途** | 最新Webアプリ、モバイルアプリ、API、SPA | エンタープライズ統合、レガシーシステム |
| **トークン形式** | JWT（JSON形式） | XML形式 |
| **軽量性** | 軽量・高速 | 重い（XMLオーバーヘッド） |
| **モバイル対応** | ネイティブ対応 | 複雑 |
| **API統合** | 容易（REST API） | 困難 |
| **エンタープライズ** | 普及中 | 成熟・広く使われている |
| **選択** | 新規プロジェクト、SaaS、API | 既存SAMLシステム統合、エンタープライズSSO |

### OAuth 2.0 Grant Type選択

| Grant Type | 用途 | セキュリティ | Client Type |
|-----------|------|------------|-------------|
| **Authorization Code** | Webアプリケーション（最も安全） | 高 | Confidential（サーバーサイド） |
| **Authorization Code + PKCE** | SPA、モバイルアプリ（推奨） | 高 | Public（ブラウザ/モバイル） |
| **Client Credentials** | サービス間通信（M2M） | 高 | Confidential（バックエンド） |
| **Implicit Flow** | SPA（非推奨・レガシー） | 低（脆弱性あり） | Public |
| **Resource Owner Password** | 信頼されたアプリのみ（非推奨） | 低 | Confidential |
| **Device Authorization** | IoTデバイス、スマートTV | 中 | Public |

**推奨選択フロー:**
1. **Webアプリ（サーバーサイド）** → Authorization Code
2. **SPA（React/Vue/Angular）** → Authorization Code + PKCE
3. **モバイルアプリ** → Authorization Code + PKCE
4. **バックエンドサービス（API to API）** → Client Credentials
5. **IoTデバイス** → Device Authorization
6. **レガシーSPA** → Implicit Flow（可能ならPKCEに移行）

### デプロイ方式選択

| デプロイ方式 | 用途 | 複雑度 | HA対応 | スケーラビリティ |
|------------|------|--------|--------|----------------|
| **Docker単体** | 開発環境、PoC | 低 | なし | 低 |
| **Docker Compose** | 小規模環境、テスト | 低 | なし | 低 |
| **Kubernetes Operator** | プロダクション、マルチテナント | 高 | あり | 高 |
| **クラスタリング（Infinispan）** | 高可用性、大規模 | 高 | あり | 高 |
| **マネージドサービス（Red Hat SSO）** | エンタープライズ | 低（運用委託） | あり | 高 |

**推奨選択フロー:**
1. **開発・PoC** → Docker単体
2. **小規模本番（< 1000ユーザー）** → Docker Compose + PostgreSQL
3. **大規模本番（> 1000ユーザー）** → Kubernetes Operator + クラスタリング
4. **エンタープライズ** → Red Hat SSO（マネージドサービス）

### データベース選択

| DB | 推奨用途 | パフォーマンス | HA対応 |
|----|---------|--------------|--------|
| **H2（デフォルト）** | 開発・テストのみ | 低 | なし |
| **PostgreSQL** | プロダクション（推奨） | 高 | あり |
| **MySQL/MariaDB** | プロダクション | 高 | あり |
| **Oracle** | エンタープライズ | 高 | あり |
| **MS SQL Server** | Windows環境 | 高 | あり |

**推奨:** PostgreSQL（オープンソース、高パフォーマンス、Keycloak最適化）

---

## AskUserQuestionパターン

Keycloakの設計・実装時に判断が必要な場合、以下のパターンでユーザーに確認してください。

### 1. 認証プロトコル選択

```python
AskUserQuestion(
    questions=[{
        "question": "どの認証プロトコルを使用しますか？",
        "header": "認証プロトコル選択",
        "options": [
            {
                "label": "OpenID Connect (OIDC)",
                "description": "最新Webアプリ、モバイルアプリ、SPA、API向け（推奨）。JWT形式、軽量、REST API対応"
            },
            {
                "label": "SAML 2.0",
                "description": "エンタープライズ統合、レガシーシステム向け。XML形式、成熟した標準"
            },
            {
                "label": "両方対応",
                "description": "OIDC（新規アプリ）とSAML（既存システム）を併用"
            }
        ],
        "multiSelect": False
    }]
)
```

### 2. OAuth 2.0 Grant Type選択

```python
AskUserQuestion(
    questions=[{
        "question": "どのOAuth 2.0 Grant Typeを使用しますか？",
        "header": "Grant Type選択",
        "options": [
            {
                "label": "Authorization Code + PKCE",
                "description": "SPA（React/Vue）、モバイルアプリ向け（最も安全・推奨）"
            },
            {
                "label": "Authorization Code",
                "description": "サーバーサイドWebアプリ向け（Confidential Client）"
            },
            {
                "label": "Client Credentials",
                "description": "サービス間通信（M2M）、バックエンドAPI向け"
            },
            {
                "label": "Device Authorization",
                "description": "IoTデバイス、スマートTV向け"
            }
        ],
        "multiSelect": False
    }]
)
```

### 3. デプロイ戦略選択

```python
AskUserQuestion(
    questions=[{
        "question": "どのデプロイ方式を選択しますか？",
        "header": "デプロイ戦略",
        "options": [
            {
                "label": "Docker単体",
                "description": "開発環境、PoC向け。複雑度低、HA非対応"
            },
            {
                "label": "Kubernetes Operator + クラスタリング",
                "description": "プロダクション、大規模環境向け。HA対応、自動スケーリング"
            },
            {
                "label": "Docker Compose",
                "description": "小規模本番（< 1000ユーザー）、テスト環境向け"
            }
        ],
        "multiSelect": False
    }]
)
```

### 4. User Federation選択

```python
AskUserQuestion(
    questions=[{
        "question": "外部ユーザーデータベースと連携しますか？",
        "header": "User Federation",
        "options": [
            {
                "label": "LDAP/Active Directory連携",
                "description": "既存社内LDAP/ADとユーザー情報を同期"
            },
            {
                "label": "Social Login（Google/GitHub等）",
                "description": "外部IdP（Google、GitHub、Azure AD等）で認証"
            },
            {
                "label": "Keycloak内でユーザー管理",
                "description": "Keycloakにユーザーを直接登録・管理"
            },
            {
                "label": "カスタムUser Storage Provider",
                "description": "独自のユーザーデータベース（API連携等）"
            }
        ],
        "multiSelect": True
    }]
)
```

---

## リファレンスファイル

詳細な実装ガイドは以下のリファレンスファイルを参照してください。

### [CORE-CONCEPTS.md](references/CORE-CONCEPTS.md)
- **内容:** OIDC vs SAML プロトコル、SSO設定、Realm設計、Client登録、User/Role/Group管理、User Federation（LDAP/AD）
- **対象章:** Ch 1-12

### [AUTHENTICATION.md](references/AUTHENTICATION.md)
- **内容:** Identity Brokering、Social Login統合、Admin Console/CLI操作、Custom Attributes、テーマカスタマイズ、Authentication Flow、MFA設定、Event Logging
- **対象章:** Ch 13-24

### [AUTHORIZATION.md](references/AUTHORIZATION.md)
- **内容:** Fine-Grained Permissions、Client Scopes、Protocol Mappers、Client Credentials Grant、PKCE、Resource-Based Permissions、UMA 2.0、Permission Tickets、Built-in Policies
- **対象章:** Ch 26-30, 48-53, 86-88, 103

### [TOKEN-MANAGEMENT.md](references/TOKEN-MANAGEMENT.md)
- **内容:** Session管理、Token有効期限、Token Exchange、JWT構造、ID/Access/Refresh Token、SAML Assertions、Authorization Code/Implicit Flow、Backchannel Logout、Token Introspection/Revocation、OIDC Discovery、Device Authorization Grant
- **対象章:** Ch 31-34, 54-60, 70-73, 90, 97-100

### [INTEGRATION.md](references/INTEGRATION.md)
- **内容:** Java Servlet Adapter、Node.js Adapter、Spring Boot連携、Admin REST API、User Info Endpoint、Role Mapping from IdP、Custom Token Mappers、Registration Workflows、AWS Cognito連携
- **対象章:** Ch 35-38, 75, 83-87

### [DEPLOYMENT.md](references/DEPLOYMENT.md)
- **内容:** Docker Image運用、Kubernetes Operator、クラスタリング（HA構成）、サポートDB一覧、Session/Token Caching、Infinispan設定、Grafana/Prometheus監視、Realm Export/Import、CORS設定、Master Realm
- **対象章:** Ch 39-44, 61-62, 76-77, 79-81, 91, 93-96, 99

### [CUSTOMIZATION.md](references/CUSTOMIZATION.md)
- **内容:** SPI（Service Provider Interface）拡張、Custom Authentication Provider、Localization、Custom User Storage Provider、Custom Password Hashing、Read-Only User Attributes、User Impersonation、Email Template Customization、Account/Admin Console テーマ、Custom Token Mappers、Federation Links管理、Backchannel Authentication
- **対象章:** Ch 45-47, 63-65, 67, 69, 82, 85, 101-102, 104

### [MULTI-TENANCY.md](references/MULTI-TENANCY.md)
- **内容:** Realm設計パターン、テナント分離戦略（Realm per Tenant / Shared Realm）、委任管理、User Federation高度パターン、Identity Brokering、Cross-Realm Trust
- **対象章:** マルチテナント・Realm設計

### [SCALE-MANAGEMENT.md](references/SCALE-MANAGEMENT.md)
- **内容:** ユーザープロビジョニング自動化、グループ構造・動的ロール割当、一括管理（Admin API・スクリプティング）、セルフサービス・プロファイル管理、外部アイデンティティ管理、委任管理モデル
- **対象章:** 大規模運用

### [OBSERVABILITY.md](references/OBSERVABILITY.md)
- **内容:** 運用監視（KPI・Prometheus・Grafana）、構造化ログ管理、パフォーマンスチューニング、認証トラブルシューティング、セキュリティインシデント対応、テスト戦略、コンプライアンス監査
- **対象章:** 監視・運用

### [MIGRATION.md](references/MIGRATION.md)
- **内容:** マイグレーション戦略（フェーズ別移行・レガシーIAM共存）、アップグレード戦略、IDaaSモデル比較、将来動向（Decentralized Identity・WebAuthn・FIDO2・Passkeys）、大規模デプロイパターン
- **対象章:** マイグレーション・将来展望

---

## 関連スキル

- **securing-code:** 一般的なセキュリティベストプラクティス（入力検証、SQL Injection対策、XSS対策等）
- **implementing-dynamic-authorization:** Cedar/ABAC/ReBAC認可モデル（Keycloak外の認可フレームワーク）
- **designing-web-apis:** REST API設計（Keycloak統合時のAPI設計）
- **developing-nextjs:** Next.js統合（App Router + Server Components + Keycloak）
- **developing-fullstack-javascript:** NestJS/Express統合（バックエンドでKeycloak認証）
- **managing-docker:** Dockerデプロイ基礎（Keycloakコンテナ運用）
- **developing-google-cloud:** Google Cloud開発・セキュリティ（Cloud Run/GKE統合、IAM、Keycloak on Cloud Run）

---

## 基本的な使い方

### ユーザー登録・ログインフロー（7ステップ）

```
1. Admin Consoleでユーザー登録有効化
2. ユーザーがアプリにアクセス → Keycloakログイン画面
3. 新規登録 → トークン発行 → アプリにリダイレクト
4. アプリがトークンエンドポイントでAccess Token取得
5. Access TokenでAPIリクエスト
```

### JWT Token検証（Node.js/keycloak-connect）

```javascript
const keycloak = new Keycloak({}, {realm: 'my-realm', resource: 'my-client', credentials: {secret: 'SECRET'}});
app.use(keycloak.middleware());
app.get('/protected', keycloak.protect(), (req, res) => res.json({user: req.kauth.grant.access_token.content}));
```

---

## トラブルシューティング

### よくあるエラーと対処法

| エラー | 原因 | 対処法 |
|--------|------|--------|
| **invalid_grant** | Authorization Codeが無効/期限切れ | Code取得後すぐにトークンリクエスト（有効期限は通常1分） |
| **redirect_uri_mismatch** | リダイレクトURIが一致しない | Client設定のredirectUrisを確認（完全一致必須） |
| **invalid_client** | Client ID/Secretが間違っている | Client設定でSecretを再確認 |
| **unauthorized_client** | Grant Typeが許可されていない | Client設定でGrant Typeを有効化 |
| **Token署名検証失敗** | 公開鍵が古い | OIDC Discovery Endpointから最新のjwks_uriを取得 |
| **Session期限切れ** | SSO Sessionがタイムアウト | ssoSessionMaxLifespanを延長 |

---

## セキュリティベストプラクティス

1. **Client Secret保護**: Confidential Clientは必ずサーバーサイドで管理（フロントエンドに埋め込まない）
2. **PKCE使用**: Public Client（SPA/モバイル）は必ずPKCE有効化
3. **HTTPS必須**: プロダクション環境では必ずHTTPS使用
4. **Token有効期限短縮**: Access Token: 5分、Refresh Token: 30分〜1時間
5. **Scope最小化**: 必要最小限のScopeのみ要求
6. **Role-Based Access Control**: 細かい権限管理にRoleを活用
7. **MFA有効化**: 重要なアプリケーションはMFA必須
8. **Audit Logging**: Event Loggingで認証・管理操作をトラッキング

---

## まとめ

Keycloakは強力で柔軟なIAMソリューションです。このガイドではコア概念、CLI/API、セットアップワークフロー、判断基準を提供しました。詳細な実装は各リファレンスファイルを参照してください。
