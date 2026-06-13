# Keycloak 認可

## 認可モデル選択ガイド

Keycloakは複数の認可モデルをサポートしており、ユースケースに応じて選択できる。

| 認可モデル | 適用シーン | 主要概念 | 実装複雑度 | ユーザー制御 |
|-----------|----------|---------|-----------|------------|
| **RBAC（Role-Based）** | 組織内アプリケーション、シンプルな権限管理 | Roles、Groups | 低 | なし |
| **Resource-Based** | API保護、リソースごとのアクセス制御 | Resources、Scopes、Policies | 中 | なし |
| **UMA 2.0（User-Managed Access）** | ヘルスケア、金融、プライバシー重視アプリ | Permission Tickets、User Consent | 高 | あり（ユーザーが許可を管理） |
| **Fine-Grained（ABAC要素含む）** | マルチテナント、複雑な条件付きアクセス | Policies（Role/Group/Time/JavaScript）、Permissions | 高 | なし |

### 判断基準

```
組織構造ベースのアクセス制御
├─ シンプルな役割区分 → RBAC（Role-Based Policy）
└─ 複雑な条件（時間、IP、属性） → Fine-Grained（ABAC）

API・リソース保護
├─ サービス間認証 → Client Credentials Grant
├─ リソース単位の保護 → Resource-Based Permissions
└─ ユーザーがアクセス権を管理 → UMA 2.0

パブリッククライアント
└─ PKCE必須（Authorization Code Flow + PKCE）
```

---

## Realm Export/Import

Keycloakはレルム設定（ユーザー、ロール、クライアント等）をJSON形式でエクスポート・インポート可能。

### エクスポート

```bash
# Admin CLI経由でレルム設定をエクスポート
./kcadm.sh get realms/myrealm -o - > myrealm-export.json
```

### インポート

```bash
# JSON形式のレルム設定をインポート
./kcadm.sh create realms -f myrealm-export.json
```

**注意事項:**
- 同名のレルムが存在する場合、デフォルトではインポート失敗
- 本番環境への適用前に、エクスポートJSONファイルの内容を必ず確認
- ユーザー、ロール、クライアント、認証フロー等すべての設定が含まれる

---

## Fine-Grained Permissions

詳細なアクセス制御を実現する機能。Policies（条件）とPermissions（ポリシーとリソースの紐付け）で構成。

### ポリシー設定（Admin Console）

```plaintext
1. Keycloak Admin Consoleにログイン
2. 対象レルム → Clients → 対象クライアントを選択
3. Permissions タブ → Authorization Enabled を有効化
4. Policies タブでポリシー定義（Role-Based、Group-Based、Time-Based等）
5. Permissions タブでリソース・スコープとポリシーを紐付け
```

### ポリシー種類

| ポリシータイプ | 説明 | ユースケース |
|--------------|------|------------|
| **Role-Based** | 特定ロールを持つユーザーに許可 | 「管理者のみアクセス」 |
| **Group-Based** | 特定グループに所属するユーザーに許可 | 「開発チームのみアクセス」 |
| **User-Based** | 個別ユーザーを指定 | 特定ユーザーへの一時的なアクセス |
| **Time-Based** | 時間帯・曜日で制御 | 営業時間内のみアクセス許可 |
| **JavaScript** | カスタムロジック実装 | 複雑な条件判定 |

### CLI例: Role-Based Policy作成

```bash
# ロール作成
kcadm.sh create roles -r myrealm -s name=admin

# ユーザーにロール割り当て
kcadm.sh add-roles -r myrealm --uusername john --rolename admin

# Client作成（Authorization Services有効化）
kcadm.sh create clients -r myrealm -s clientId=myclient -s publicClient=false -s authorizationServicesEnabled=true

# Role-Based Policy作成
kcadm.sh create 'clients/myclient/authz/resource-server/policy/role' -r myrealm -b '{
  "name": "Admin Only Policy",
  "roles": [
    {"id": "admin"}
  ]
}'
```

---

## Client Scopes

トークンに含めるクレーム（ロール、属性等）をグループ化し、複数クライアントで再利用可能にする機能。

### スコープ種類

- **Default Scopes**: すべてのクライアントに自動適用
- **Optional Scopes**: クライアントが認証時にリクエスト可能

### JSON設定例

```json
{
  "id": "email-scope",
  "name": "email",
  "protocol": "openid-connect",
  "attributes": {
    "include.in.token.scope": "true"
  },
  "protocolMappers": [
    {
      "name": "email-mapper",
      "protocol": "openid-connect",
      "protocolMapper": "oidc-usermodel-attribute-mapper",
      "consentRequired": false,
      "config": {
        "user.attribute": "email",
        "claim.name": "email",
        "jsonType.label": "String"
      }
    }
  ]
}
```

---

## Protocol Mappers

ユーザー情報をトークン内のクレームに変換する機能。

### マッパー種類

| マッパータイプ | 説明 | 例 |
|--------------|------|-----|
| **User Attribute Mapper** | ユーザー属性をクレームに追加 | `department` 属性を `department` クレームにマッピング |
| **Role Mapper** | ユーザーロールをクレームに追加 | ユーザーのロール一覧を `roles` クレームに含める |
| **Hardcoded Claim Mapper** | 固定値をクレームに追加 | `tenant_id: "abc123"` を常に含める |

### JSON例: カスタム属性マッパー

```json
{
  "name": "department-mapper",
  "protocol": "openid-connect",
  "protocolMapper": "oidc-usermodel-attribute-mapper",
  "consentRequired": false,
  "config": {
    "user.attribute": "department",
    "claim.name": "department",
    "jsonType.label": "String"
  }
}
```

---

## OAuth 2.0 Grant Types

OAuth 2.0は認可フレームワークとして複数のGrantタイプを提供し、アクセストークンを取得する方法を標準化している。

### Authorization Code Flow

最も一般的で安全な認可フロー。ユーザーがアプリケーションにアクセス権を委譲する標準的な方法。

**フロー:**
```
1. アプリ → ユーザーをKeycloakの認可エンドポイントへリダイレクト
2. ユーザー → Keycloakでログイン（未認証の場合）
3. ユーザー → アプリへのアクセス許可（Consent Required有効時）
4. Keycloak → Authorization Codeをアプリへ返却
5. アプリ → Authorization CodeをAccess Tokenと交換（Token Endpoint）
6. アプリ → Access TokenでAPIを呼び出し
```

**Authorization Request例:**
```bash
https://keycloak.example.com/auth/realms/myrealm/protocol/openid-connect/auth?
  response_type=code&
  client_id=my-app&
  redirect_uri=https://my-app.com/callback&
  scope=openid profile email&
  state=xyz123
```

**Token Request例:**
```bash
curl -X POST \
  "http://localhost:8080/auth/realms/myrealm/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=authorization_code" \
  -d "client_id=my-app" \
  -d "client_secret={client-secret}" \
  -d "code={authorization-code}" \
  -d "redirect_uri=https://my-app.com/callback"
```

**適用シーン:**
- サーバーサイドWebアプリケーション
- Confidentialクライアント（Client Secret保持可能）

### Client Credentials Grant（サービス間認証）

ユーザー介在なしのサーバー間認証。

```bash
curl -X POST \
  "http://localhost:8080/auth/realms/{realm-name}/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id={client-id}" \
  -d "client_secret={client-secret}"
```

**レスポンス例:**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expires_in": 3600,
  "token_type": "Bearer"
}
```

**適用シーン:**
- マイクロサービス間の認証
- バックグラウンドジョブのAPI呼び出し
- 管理ツールからのAPI操作

### PKCE（Proof Key for Code Exchange）

Authorization Code Flowのセキュリティ強化版。パブリッククライアント（モバイルアプリ、SPAなど）で必須。

**クライアント設定（JSON）:**
```json
{
  "clientId": "my-mobile-app",
  "enabled": true,
  "publicClient": true,
  "protocol": "openid-connect",
  "redirectUris": ["http://localhost:8080/callback"],
  "attributes": {
    "pkce.code.challenge.method": "S256"
  }
}
```

**フロー:**
```
1. クライアント: code_verifier生成（ランダム文字列）
2. クライアント: code_challenge = BASE64URL(SHA256(code_verifier))
3. クライアント → Keycloak: Authorization Request（code_challenge含む）
4. Keycloak → クライアント: Authorization Code
5. クライアント → Keycloak: Token Request（code_verifier含む）
6. Keycloak: code_challengeとcode_verifierを検証
7. Keycloak → クライアント: Access Token
```

**なぜ必要か:**
- Authorization Codeの傍受攻撃（Interception Attack）を防止
- Client Secretを安全に保存できないPublic Clientで必須
- Keycloak 7.0以降は公式サポート

---

## Access Token制限戦略

アクセストークンの権限を制限し、セキュリティを強化する3つの主要戦略。

### Audience制限

トークンを受け入れるべきリソースサーバーを明示的に指定。

**設定方法（Admin Console）:**
```plaintext
1. Clients → 対象クライアント → Client Scopes
2. 専用Client Scope（{client-id}-dedicated）を選択
3. Mappers → Configure a new mapper → Audience
4. Name: "backend audience"
5. Included Client Audience: "{resource-server-client-id}"
6. Add to access token: ON
```

**結果:**
```json
{
  "aud": ["oauth-backend", "account"]
}
```

**自動Audience追加:**
- クライアントが他のクライアントのロールにスコープを持つ場合、そのクライアントが自動的に`aud`に追加される

### Role制限

トークンに含まれるロールを制限。

**原則:**
```
トークン内のロール = ユーザーのロール ∩ クライアントのスコープ
```

**Full Scope Allowed無効化:**
```plaintext
1. Clients → 対象クライアント → Client Scopes
2. 専用Client Scope → Scope タブ
3. Full Scope Allowed: OFF
4. Assign role: 必要なロールのみ選択
```

**結果:**
```json
{
  "aud": "oauth-backend",
  "realm_access": {
    "roles": ["myrole"]
  }
}
```

### Scope制限

OAuth 2.0スコープでアクセス権を細分化。

**Client Scopeベースのスコープ:**
```plaintext
1. Client Scopes → Create client scope
2. Name: albums:view
3. Consent Screen Text: "View photo albums"
4. Clients → 対象クライアント → Client Scopes → Add client scope
5. albums:view → Add → Default（常に含む）または Optional（要求時のみ）
```

**Incremental Authorization（段階的認可）:**
```
初回リクエスト: scope=openid albums:view
  → ユーザーに「View photo albums」許可を要求

追加機能使用時: scope=albums:create
  → ユーザーに「Create photo albums」許可を要求
```

**スコープ命名ガイドライン:**
```
推奨:
- albums:view
- albums:create
- albums:delete
- https://api.acme.org/bombs/bombs.purchase

非推奨:
- view_albums（動詞が後）
- album（複数形でない）
```

---

## Resource-Based Permissions

リソース単位でアクセス制御を定義。

### リソース定義例（JSON）

```json
{
  "name": "Document Access",
  "type": "resource",
  "owner": {"id": "user-id"},
  "scopes": ["view", "edit"],
  "attributes": {
    "owner": "user-id"
  }
}
```

### リソースサーバー設定手順

```bash
# リソース定義
curl -X POST \
  "http://localhost:8080/auth/realms/{realm}/authz/protection/resource_set" \
  -H "Authorization: Bearer {access_token}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Sensitive Document",
    "type": "urn:myapp:sensitive-document",
    "scopes": ["read", "write"],
    "ownerManagedAccess": false
  }'

# ポリシー定義（Role-Based）
curl -X POST \
  "http://localhost:8080/auth/realms/{realm}/authz/protection/policy" \
  -H "Authorization: Bearer {access_token}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Manager Only Policy",
    "type": "role",
    "roles": ["manager"],
    "logic": "POSITIVE",
    "decisionStrategy": "AFFIRMATIVE"
  }'

# ポリシーをリソースに適用
curl -X POST \
  "http://localhost:8080/auth/realms/{realm}/authz/protection/resource/{resource_id}/policies" \
  -H "Authorization: Bearer {access_token}" \
  -H "Content-Type: application/json" \
  -d '{
    "policies": ["Manager Only Policy"]
  }'
```

---

## UMA 2.0（User-Managed Access）

ユーザーが自身のリソースへのアクセス権を管理。プライバシー重視のアプリケーション向け。

### UMA有効化（Admin Console）

```plaintext
1. Clients → 対象クライアントを選択
2. Authorization Settings → User-Managed Access を有効化
```

### リソース登録（API）

```bash
curl -X POST \
  "http://localhost:8080/auth/realms/{realm}/authz/protection/resource_set" \
  -H "Authorization: Bearer {access_token}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "User Medical Record",
    "type": "urn:healthcare:medical-record",
    "scopes": ["view", "edit"],
    "owner": "{user_id}",
    "ownerManagedAccess": true
  }'
```

### ユーザーが許可を付与

```bash
curl -X POST \
  "http://localhost:8080/auth/realms/{realm}/authz/uma/permission" \
  -H "Authorization: Bearer {access_token}" \
  -H "Content-Type: application/json" \
  -d '{
    "resource_id": "{resource_id}",
    "resource_scopes": ["view"],
    "requester": "{requester_id}"
  }'
```

**UMAフロー:**
```
1. リソースオーナー: リソースを登録
2. リクエスター: リソースへのアクセスを試行
3. Keycloak: Permission Ticketを発行
4. リクエスター: Permission Ticketを使って許可をリクエスト
5. リソースオーナー: 許可を付与（またはAdmin Consoleで事前設定）
6. Keycloak: RPT（Requesting Party Token）を発行
7. リクエスター: RPTを使ってリソースにアクセス
```

**適用シーン:**
- 医療記録の共有（患者が医師へのアクセス権を制御）
- 金融データの共有（ユーザーがサードパーティアプリへのアクセス権を管理）
- クラウドストレージのファイル共有

---

## Permission Tickets

リソースアクセスリクエストを表すチケット。UMA 2.0フローで使用。

### Permission Ticket発行例（Java）

```java
import org.keycloak.authorization.client.AuthzClient;
import org.keycloak.authorization.client.resource.AuthorizationResource;
import org.keycloak.authorization.client.representation.AuthorizationRequest;
import org.keycloak.authorization.client.representation.AuthorizationResponse;

public class RequestPermissionTicket {
    public static void main(String[] args) {
        AuthzClient authzClient = AuthzClient.create();
        AuthorizationResource authorization = authzClient.authorization("client-id", "client-secret");

        // Permission Ticketをリクエスト
        AuthorizationRequest request = new AuthorizationRequest();
        request.addPermission("resource-id", "scope-name");

        AuthorizationResponse response = authorization.authorize(request);
        String ticket = response.getToken();

        System.out.println("Permission Ticket: " + ticket);
    }
}
```

**使用フロー:**
```
1. クライアント: リソースアクセスを試行
2. リソースサーバー: 401 Unauthorized + Permission Ticketを返却
3. クライアント: Permission TicketをKeycloakに送信
4. Keycloak: ポリシー評価 → RPT（Requesting Party Token）発行
5. クライアント: RPTでリソースアクセス
```

---

## Built-in Policies（組み込みポリシー）

Keycloakが標準提供するポリシー種類。

### ポリシー種類一覧

| ポリシー | 説明 | 設定例 |
|---------|------|--------|
| **Role-Based** | 特定ロールを持つユーザーに許可 | `roles: ["admin", "manager"]` |
| **Group-Based** | 特定グループに所属するユーザーに許可 | `groups: ["/engineering/backend"]` |
| **User-Based** | 個別ユーザーを指定 | `users: ["user-id-123"]` |
| **Time-Based** | 時間帯で制御 | `notBefore: "09:00", notOnOrAfter: "18:00"` |
| **Aggregated** | 複数ポリシーを組み合わせ | `policies: ["PolicyA", "PolicyB"]` |
| **JavaScript** | カスタムロジック | `function(context) { return context.attributes.department === 'IT'; }` |

### Role-Based Policyの実装例（Admin Console）

```plaintext
1. Authorization → Policies → Create
2. Policy Type: Role
3. Policy Name: "AdminRolePolicy"
4. Roles: ["Admin"]
5. Logic: POSITIVE（ロールを持っていればアクセス許可）
6. Decision Strategy: AFFIRMATIVE（1つでもポリシーが承認すればOK）
```

### Group-Based Policyの適用パターン

```plaintext
組織構造:
  /engineering
    /backend
    /frontend
  /sales
    /enterprise
    /smb

ポリシー設定:
- Backend Team Policy: group="/engineering/backend"
- Frontend Team Policy: group="/engineering/frontend"
- Engineering Team Policy: group="/engineering"（サブグループ含む）
```

---

## Credentials管理

ユーザーに割り当てる認証情報（パスワード、OTP等）の管理。

### パスワード設定（Admin Console）

```plaintext
1. Users → 対象ユーザーを選択
2. Credentials タブ
3. Set Password → 新しいパスワードを入力
4. Temporary: ON（次回ログイン時に変更を強制）
```

### OTP（TOTP）有効化

```plaintext
1. Users → 対象ユーザーを選択
2. Required Actions タブ
3. "Configure OTP" を追加
4. ユーザーは次回ログイン時にQRコードをスキャン（Google Authenticator等）
```

### パスワードポリシー設定

```plaintext
Realm Settings → Security Defenses → Password Policy

利用可能なポリシー:
- Minimum Length: 最小文字数
- Uppercase Characters: 大文字必須
- Lowercase Characters: 小文字必須
- Special Characters: 特殊文字必須
- Digits: 数字必須
- Not Username: ユーザー名と同じパスワード禁止
- Expire Password: パスワード有効期限
- Password History: 過去のパスワード再利用禁止
```

---

## Fine-Grained Permissions: RBAC/ABAC詳細

Keycloakの認可サービスは、シンプルなRBACから複雑なABACまで、幅広いポリシーモデルをサポート。

### ポリシー組み合わせパターン

複数のポリシーを組み合わせて複雑な認可ロジックを構築。

**Decision Strategy（決定戦略）:**
| 戦略 | 説明 | ユースケース |
|------|------|------------|
| **AFFIRMATIVE** | 1つ以上のポリシーが許可すればアクセス許可 | OR条件（管理者 **または** オーナー） |
| **UNANIMOUS** | すべてのポリシーが許可しないとアクセス拒否 | AND条件（管理者 **かつ** 営業時間内） |
| **CONSENSUS** | 多数決（許可 > 拒否） | 複雑な投票ロジック |

**Aggregated Policy例:**
```json
{
  "name": "Admin OR Owner Policy",
  "type": "aggregate",
  "decisionStrategy": "AFFIRMATIVE",
  "policies": [
    "Admin Role Policy",
    "Resource Owner Policy"
  ]
}
```

### スコープベースパーミッション

リソースの特定操作（スコープ）に対してポリシーを適用。

**スコープ定義例:**
```bash
# リソース定義
curl -X POST "http://localhost:8080/auth/realms/{realm}/authz/protection/resource_set" \
  -H "Authorization: Bearer {access_token}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Project-ABC",
    "type": "urn:myapp:project",
    "scopes": ["view", "edit", "delete"],
    "owner": "user-123"
  }'

# スコープベースパーミッション作成
curl -X POST "http://localhost:8080/auth/admin/realms/{realm}/clients/{client-id}/authz/resource-server/permission/scope" \
  -H "Authorization: Bearer {admin_token}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Edit Project Permission",
    "scopes": ["edit"],
    "policies": ["Manager Role Policy"],
    "decisionStrategy": "UNANIMOUS"
  }'
```

**結果:** "Manager Role Policy"を満たすユーザーのみが "Project-ABC" の "edit" スコープにアクセス可能。

### カスタムポリシープロバイダー（SPI）

JavaScript Policy以外に、Javaで完全カスタムポリシーロジックを実装可能。

**実装例（AttributeBasedPolicy）:**
```java
public class DepartmentPolicy implements Policy {
    @Override
    public void evaluate(Evaluation evaluation) {
        Identity identity = evaluation.getContext().getIdentity();
        String department = identity.getAttributes().getValue("department").asString(0);

        if ("Engineering".equals(department)) {
            evaluation.grant();
        } else {
            evaluation.deny();
        }
    }
}
```

**PolicyFactory実装:**
```java
public class DepartmentPolicyFactory implements PolicyProviderFactory {
    @Override
    public String getId() {
        return "department-policy";
    }

    @Override
    public PolicyProvider create(KeycloakSession session) {
        return new DepartmentPolicyProvider();
    }
}
```

**デプロイ後のAdmin Console:**
1. Authorization → Policies → Create Policy
2. Type: "Department Policy"
3. 設定項目（カスタム）でポリシーパラメータを指定

### Context-Based Policy（コンテキストベース）

アクセス時のコンテキスト情報（IPアドレス、時刻、デバイス等）を評価。

**JavaScript Policy例（時間制限）:**
```javascript
var context = $evaluation.getContext();
var hour = new Date().getHours();

if (hour >= 9 && hour <= 17) {
  $evaluation.grant();
} else {
  $evaluation.deny();
}
```

**IPアドレス制限例:**
```javascript
var context = $evaluation.getContext();
var clientIp = context.getAttributes().getValue('kc.client.network.ip_address').asString(0);
var allowedIps = ["192.168.1.0/24", "10.0.0.0/8"];

if (isIpInRange(clientIp, allowedIps)) {
  $evaluation.grant();
} else {
  $evaluation.deny();
}

function isIpInRange(ip, ranges) {
  // IP範囲チェックロジック
}
```

### Attribute-Based Access Control（ABAC）

ユーザー・リソース・環境属性を組み合わせた高度な認可。

**実装例（User Attribute + Resource Attribute）:**
```javascript
var identity = $evaluation.getContext().getIdentity();
var resource = $evaluation.getPermission().getResource();

var userDept = identity.getAttributes().getValue('department').asString(0);
var resourceDept = resource.getAttribute('department')[0];

if (userDept === resourceDept) {
  $evaluation.grant(); // 同じ部署のリソースにアクセス可能
} else {
  $evaluation.deny();
}
```

### リソース階層とパーミッション継承

親リソースのポリシーを子リソースが継承する設計パターン。

**階層例:**
```
/projects
  /projects/project-a
    /projects/project-a/documents
      /projects/project-a/documents/doc1.pdf
```

**パーミッション設計:**
| リソース | ポリシー | 継承 |
|---------|---------|------|
| `/projects` | "Authenticated Users" | 全プロジェクトの存在確認可能 |
| `/projects/project-a` | "Project-A Members" | プロジェクトAのメンバーのみアクセス |
| `/projects/project-a/documents/doc1.pdf` | 親を継承 + "Document Viewer" | プロジェクトAメンバー **かつ** ドキュメント閲覧権限 |

**Admin Consoleでの設定:**
- Resource: 親リソースIDを指定
- Permission: "Apply to Resource Type"で同じtypeのすべてのリソースに適用

### 動的リソース登録（Protection API）

アプリケーション実行時にリソースを動的に登録・更新。

**リソース登録例（REST API）:**
```bash
# PAT（Protection API Token）取得
PAT=$(curl -X POST "http://localhost:8080/auth/realms/{realm}/protocol/openid-connect/token" \
  --data "grant_type=client_credentials" \
  --data "client_id=resource-server" \
  --data "client_secret={secret}" | jq -r '.access_token')

# リソース動的登録
curl -X POST "http://localhost:8080/auth/realms/{realm}/authz/protection/resource_set" \
  -H "Authorization: Bearer $PAT" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "User-123 Private Document",
    "type": "urn:myapp:private-document",
    "owner": "user-123",
    "scopes": ["view", "share"],
    "ownerManagedAccess": true
  }'
```

**活用シーン:**
- SaaSアプリケーションでユーザーごとのリソースを動的作成
- ファイルアップロード時に即座にリソース登録
- UMA 2.0フローでユーザーが自身のリソースへのアクセス権を管理

### パーミッション評価の最適化

大量のリソース・ポリシーが存在する場合、評価パフォーマンスが重要。

**最適化手法:**
| 手法 | 説明 |
|------|------|
| **ポリシーキャッシュ** | Authorization Cacheで評価結果をキャッシュ（Infinispan） |
| **スコープ絞り込み** | リクエスト時に必要なスコープのみを評価 |
| **リソースタイプ別ポリシー** | 個別リソースではなくリソースタイプ単位でポリシー適用 |
| **非同期評価** | バックグラウンドでパーミッション再評価（定期バッチ） |

**スコープ絞り込み例:**
```bash
# 必要なスコープのみをリクエスト
curl -X POST "http://localhost:8080/auth/realms/{realm}/protocol/openid-connect/token" \
  --data "grant_type=urn:ietf:params:oauth:grant-type:uma-ticket" \
  --data "ticket={permission_ticket}" \
  --data "scope=view" \
  --data "client_id={client_id}" \
  --data "client_secret={client_secret}"
```

---

## 認可モデル統合パターン

### RBAC + Resource-Based（推奨パターン）

```
基本: Role-Based Policy（組織構造）
詳細: Resource-Based Permissions（APIエンドポイント単位）

例:
- Role "Developer" → リソース "/api/projects/*"（read, write）
- Role "Viewer" → リソース "/api/projects/*"（read）
```

### ABAC + UMA 2.0（高度なパターン）

```
基本: Attribute-Based Policy（ユーザー属性、時間、IP等）
詳細: UMA 2.0（ユーザー自身が許可を管理）

例:
- Policy: user.department == "Healthcare" AND time.between(09:00, 17:00)
- UMA: 患者が医師への診療記録アクセス権を個別に付与
```

---

## 認可戦略の使い分け

### OAuth 2.0 Scopes（委譲・第三者アクセス）

**適用シーン:**
- サードパーティアプリケーションがユーザーデータにアクセス
- ユーザーがアクセス権を制御

**特徴:**
- ユーザー同意ベース（Consent Required）
- スコープ単位でアクセス制限
- 「クライアント」を保護する（ユーザーではなく）

**実装例:**
```plaintext
1. Client → Consent Required: ON
2. Client Scopes → Optional Scopes: albums:view, albums:create
3. Authorization Request: scope=openid albums:view
4. ユーザーが許可 → トークンにscope含む
```

### RBAC（組織内アプリケーション）

**適用シーン:**
- 社内システム、管理ツール
- 組織構造に基づく権限管理

**特徴:**
- ロール爆発に注意（Role Explosion）
- Composite Rolesよりもグループ+ロールを推奨
- トークンサイズへの影響

**ベストプラクティス:**
```
推奨:
- Group → Roleを割り当て
- ユーザー → Groupに所属

非推奨:
- Composite Role過多
- ユーザーごとの個別ロール割り当て
```

### GBAC（組織ツリー・部署単位）

**適用シーン:**
- 部署・チーム単位のアクセス制御
- 組織階層の反映

**実装例:**
```plaintext
Group階層:
  /engineering
    /backend
    /frontend
  /sales
    /enterprise

Protocol Mapper:
- Type: Group Membership
- Token Claim Name: groups
- Full group path: ON
```

**トークン内容:**
```json
{
  "groups": ["/engineering/backend"]
}
```

### ABAC（柔軟・細粒度）

**適用シーン:**
- 複雑な条件付きアクセス
- 動的なポリシー評価

**特徴:**
- トークンのクレームを利用
- Protocol Mapperで任意の属性を追加可能
- 実装・管理が複雑

**Protocol Mapper例:**
```json
{
  "name": "department-mapper",
  "protocol": "openid-connect",
  "protocolMapper": "oidc-usermodel-attribute-mapper",
  "config": {
    "user.attribute": "department",
    "claim.name": "department",
    "jsonType.label": "String"
  }
}
```

### Centralized Authorization（Keycloak Authorization Services）

**適用シーン:**
- ポリシーを外部化したい
- 複数のアクセス制御メカニズムを統合

**特徴:**
- リソース・ポリシーの分離
- アプリケーションコードの変更なしにポリシー変更可能
- トークンベース認可（追加RTT不要）

**実装例:**
```java
if (User.canAccess("Manager Resource")) {
  // リソースへのアクセス許可
}
```
