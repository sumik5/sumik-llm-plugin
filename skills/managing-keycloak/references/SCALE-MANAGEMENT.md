# 大規模ユーザー・ロール管理

## ローカルユーザー管理

### ユーザー作成・基本操作

**ユーザー作成に必須の情報:**
- **Username**: 必須（一意）
- **Email**、**First Name**、**Last Name**: オプションだが推奨
- **Enabled**: アカウント有効化フラグ

**作成方法:**
1. **Admin Console**: 手動作成（少数ユーザー向け）
2. **Self-Registration**: ユーザー自身が登録（Realm Settings > Login > User registration: ON）
3. **Admin REST API**: プログラマティック作成（大量ユーザー向け）

#### Admin Console操作

```
Users > Create new user:
- Username: alice
- Email: alice@example.com
- First Name: Alice
- Last Name: Smith
- Email Verified: ON（メール確認済みの場合）
→ Create
```

#### セルフレジストレーション有効化

```
Realm Settings > Login:
- User registration: ON
→ ログインページに「Register」リンク表示
```

**セルフレジストレーションフロー:**
1. ユーザーがログインページで「Register」クリック
2. 登録フォーム表示（Username、Email、First Name、Last Name、Password入力）
3. 情報送信 → Keycloakがユーザー作成
4. Email Verification有効時はメール確認リンク送信

---

### 資格情報管理

**サポートされる資格情報タイプ:**
- **Password**: 基本認証
- **OTP（One-Time Password）**: 2要素認証
- **WebAuthn**: セキュリティキー・生体認証
- **X.509 Certificates**: クライアント証明書認証

#### パスワード設定

```
Users > [ユーザー選択] > Credentials:
- Set password
- Password: <new_password>
- Password confirmation: <new_password>
- Temporary: OFF（一時パスワードでない場合）
→ Save
```

**Temporary設定:**
- `ON`: 初回ログイン時にパスワード変更強制
- `OFF`: 永続的パスワード

---

### Required User Actions（必須アクション）

**ユーザーに特定の操作を強制:**

| アクション | 用途 |
|----------|------|
| **Verify Email** | メールアドレス確認 |
| **Update Password** | パスワード変更強制 |
| **Update Profile** | プロファイル情報入力要求 |
| **Configure OTP** | 2要素認証設定強制 |
| **Terms and Conditions** | 利用規約同意 |

#### 設定方法

```
Users > [ユーザー選択] > Details:
- Required User Actions: Update Profile, Verify Email
→ Save
```

**動作:**
- ユーザーがログイン時に該当アクションの画面が表示される
- 完了するまで認証フロー進行不可

---

### ユーザー属性（カスタムメタデータ）

**用途:**
- 追加ユーザー情報の格納（部署、従業員ID、電話番号等）
- アプリケーションへのカスタムクレーム渡し
- ABAC（Attribute-Based Access Control）実装

#### 属性追加

```
Users > [ユーザー選択] > Attributes:
- Key: employeeId, Value: 12345
- Key: department, Value: IT
- Key: phoneNumber, Value: +81-90-1234-5678
→ Save
```

#### Protocol Mapperで属性をトークンに含める

```
Clients > [クライアント選択] > Client Scopes > [Scope選択] > Mappers > Create:
- Mapper Type: User Attribute
- User Attribute: employeeId
- Token Claim Name: employee_id
- Claim JSON Type: String
→ Save
```

**結果:**
- ID Token・Access Tokenに`employee_id`クレームが追加される

---

## ユーザープロビジョニング・ライフサイクル自動化

Keycloakは堅牢なコネクター、包括的なAPI、カスタムスクリプト統合によりユーザーのオンボーディング、属性同期、更新、デプロビジョニングを自動化する。

### Identity Providers・User Federationによる同期

Keycloakは外部システム（LDAP、Active Directory、Social IdP）との連携により、ユーザー属性・ロール・グループメンバーシップを継続的に同期する。

**同期モード**:
- **スケジュール同期**: 定期的なバッチ同期
- **オンデマンド同期**: イベント駆動の即時同期

### Admin REST APIによる自動プロビジョニング

Admin REST APIを活用してユーザーライフサイクル全体をプログラマティックに制御する。

**典型的な統合パターン**:
- HRMSイベント → プロビジョニングジョブ → Keycloakユーザー作成
- 職務に応じたロール自動割当
- オーケストレーションツール・ミドルウェア統合

#### ユーザー作成例（REST API）

```json
{
  "username": "jdoe",
  "enabled": true,
  "email": "jdoe@example.com",
  "firstName": "John",
  "lastName": "Doe",
  "credentials": [{
    "type": "password",
    "value": "SecurePass123",
    "temporary": false
  }],
  "realmRoles": [
    "user",
    "finance"
  ],
  "clientRoles": {
    "account": ["manage-account"]
  }
}
```

```bash
# ユーザー作成リクエスト
curl -X POST "http://localhost:8080/auth/admin/realms/myrealm/users" \
  -H "Authorization: Bearer <ACCESS_TOKEN>" \
  -H "Content-Type: application/json" \
  -d @user_payload.json
```

### デプロビジョニング戦略

**自動デプロビジョニング**:
- 従業員退職時のアカウント無効化・削除
- スケジュールされた同期ジョブによるロール取り消し・属性変更の検知
- 孤立アカウント・古いアカウントのリスク最小化

### カスタムスクリプティング・イベント駆動プロビジョニング

**実装方法**:
| 方法 | 用途 |
|------|------|
| **JavaScript Protocol Mappers** | 認証イベント時の動的ロールマッピング |
| **Event Listeners** | 管理イベント時のプロビジョニングワークフロートリガー |
| **Javaベース拡張** | Enterprise Service Bus・メッセージキューとの統合 |

### 属性同期・スキーママッピング

**マッピング例（LDAP → Keycloak）**:
| LDAP属性 | Keycloak属性 |
|---------|-------------|
| `cn` | `firstName` |
| `mail` | `email` |
| `memberOf` | `realmRoles` |

**ポリシー設定**:
- **競合解決**: 信頼できる情報源の優先順位設定
- **属性変換**: データ型・フォーマット変換
- **条件付きプロビジョニング**: ビジネスルールに基づくフィルタリング

### 定期的なアイデンティティレビュー

**監査・レビューツール**:
- アクティブユーザー一覧レポート生成
- ソースシステムとの差分ハイライト
- レビュー・無効化対象アカウント特定
- GRC（ガバナンス・リスク・コンプライアンス）ツールとの同期

### 分散・ハイブリッドクラウド統合

Keycloakのプロビジョニング機能をIaC（Infrastructure as Code）ツールと統合し、システムアクセス・アプリケーション権限・ネットワーク許可を含む大規模ワークフローを自動化する。

---

## グループ構造・動的ロール割当

Keycloakのグループはユーザーを組織化し、ロールをまとめて管理する強力な仕組みを提供する。

### 階層型グループ設計

**特徴**:
- ネストされたサブグループ対応
- グループ内すべてのユーザーがロールを継承
- 組織構造を反映した柔軟な設計

#### グループ作成・ロール割当例

```bash
# グループ作成
curl -X POST "http://localhost:8080/auth/admin/realms/{realm}/groups" \
  -H "Authorization: Bearer {access_token}" \
  -H "Content-Type: application/json" \
  -d '{ "name": "Developers" }'

# グループにロール割当
curl -X POST "http://localhost:8080/auth/admin/realms/{realm}/groups/{group-id}/role-mappings/realm" \
  -H "Authorization: Bearer {access_token}" \
  -H "Content-Type: application/json" \
  -d '[{"name": "developer-role"}]'

# ユーザーをグループに追加
curl -X PUT "http://localhost:8080/auth/admin/realms/{realm}/users/{user-id}/groups/{group-id}" \
  -H "Authorization: Bearer {access_token}"
```

### 動的ロールマッピング

**実装パターン**:
| パターン | 説明 |
|---------|------|
| **グループベースマッピング** | グループメンバーシップに基づく自動ロール付与 |
| **属性ベースマッピング** | ユーザー属性（department、jobTitle等）に基づく動的割当 |
| **条件付きロール** | 認証コンテキスト（時間帯、IPアドレス等）に応じた動的制御 |

### グループベースのポリシー適用

**活用例**:
- 部門ごとのアクセス制御
- プロジェクトチームベースの権限管理
- 地域・拠点別のポリシー適用

---

## 一括管理（Admin API・スクリプティング）

大規模環境ではバッチ操作とスクリプティングが不可欠。

### バッチユーザー作成

```bash
#!/bin/bash
# 複数ユーザーを一括作成

REALM="myrealm"
TOKEN="<ACCESS_TOKEN>"
USER_LIST="users.csv"

while IFS=, read -r username email firstName lastName role; do
  curl -X POST "http://localhost:8080/auth/admin/realms/${REALM}/users" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
      \"username\": \"${username}\",
      \"enabled\": true,
      \"email\": \"${email}\",
      \"firstName\": \"${firstName}\",
      \"lastName\": \"${lastName}\",
      \"realmRoles\": [\"${role}\"]
    }"
done < "${USER_LIST}"
```

### ロール一括割当

```bash
# 全ユーザーに特定ロールを一括割当
USER_IDS=$(curl -X GET "http://localhost:8080/auth/admin/realms/${REALM}/users" \
  -H "Authorization: Bearer ${TOKEN}" | jq -r '.[].id')

ROLE_ID=$(curl -X GET "http://localhost:8080/auth/admin/realms/${REALM}/roles/${ROLE_NAME}" \
  -H "Authorization: Bearer ${TOKEN}" | jq -r '.id')

for uid in $USER_IDS; do
  curl -X POST "http://localhost:8080/auth/admin/realms/${REALM}/users/${uid}/role-mappings/realm" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "[{\"id\":\"${ROLE_ID}\",\"name\":\"${ROLE_NAME}\"}]"
done
```

### 一括操作のベストプラクティス

| プラクティス | 理由 |
|------------|------|
| **バッチサイズ制限** | APIレート制限を回避（100-500件/バッチ推奨） |
| **トランザクション整合性** | エラー時のロールバック機構実装 |
| **並列処理** | スループット向上（ただしサーバー負荷に注意） |
| **監査ログ記録** | すべてのバッチ操作を記録 |

---

## セルフサービス・プロファイル管理

エンドユーザーが自身のアカウントを管理できる機能により、管理負荷を軽減する。

### Account Console設定

**提供機能**:
- プロファイル情報編集
- パスワード変更
- 2要素認証設定
- セッション管理
- アプリケーション権限確認

#### Account Console有効化

```bash
# Realm設定でAccount Consoleを有効化
curl -X PUT "http://localhost:8080/auth/admin/realms/${REALM}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "accountTheme": "keycloak.v2",
    "userManagedAccessAllowed": true
  }'
```

### パスワードリセット・リカバリフロー

**リカバリオプション**:
| オプション | 説明 |
|----------|------|
| **Email Recovery** | メール経由の確認リンク |
| **Security Questions** | 秘密の質問による本人確認 |
| **OTP Recovery Codes** | 事前生成されたリカバリコード |

#### パスワードリセットフロー設定

```bash
# Email送信設定
curl -X PUT "http://localhost:8080/auth/admin/realms/${REALM}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "resetPasswordAllowed": true,
    "smtpServer": {
      "host": "smtp.example.com",
      "port": "587",
      "from": "noreply@example.com",
      "auth": true,
      "user": "smtp_user",
      "password": "smtp_password"
    }
  }'
```

### 必須アクション設定

**典型的な必須アクション**:
- `VERIFY_EMAIL`: 初回ログイン時のメール確認
- `UPDATE_PASSWORD`: パスワード変更強制
- `CONFIGURE_TOTP`: 2要素認証設定強制
- `UPDATE_PROFILE`: プロファイル情報更新要求
- `TERMS_AND_CONDITIONS`: 利用規約同意

```bash
# ユーザーに必須アクションを設定
curl -X PUT "http://localhost:8080/auth/admin/realms/${REALM}/users/${USER_ID}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "requiredActions": ["VERIFY_EMAIL", "CONFIGURE_TOTP"]
  }'
```

---

## 外部アイデンティティ管理

大規模環境では外部IdPとの統合が不可欠。

### Social Login大規模運用

**主要プロバイダー統合**:
- Google
- Facebook
- GitHub
- LinkedIn
- Microsoft Azure AD

#### Social IdP設定例（Google）

```bash
# Google IdP追加
curl -X POST "http://localhost:8080/auth/admin/realms/${REALM}/identity-provider/instances" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "alias": "google",
    "providerId": "google",
    "enabled": true,
    "config": {
      "clientId": "YOUR_GOOGLE_CLIENT_ID",
      "clientSecret": "YOUR_GOOGLE_CLIENT_SECRET",
      "defaultScope": "openid profile email"
    }
  }'
```

### IdP統合パターン

| パターン | 用途 |
|---------|------|
| **Hub & Spoke** | 中央Keycloakが複数IdPを統合 |
| **Federation Chain** | IdP間の連携チェーン構築 |
| **IdP Discovery** | ユーザーのメールドメイン等から適切なIdPを自動選択 |

### アカウントリンク・統合

**戦略**:
- **自動リンク**: メールアドレスベースの自動アカウント統合
- **手動リンク**: ユーザーが明示的に外部アカウントをリンク
- **強制IdP**: 特定ドメインユーザーに対してIdP強制

---

## 委任管理モデル

大規模組織では管理権限を分散化する必要がある。

### テナント管理者パターン

**設計**:
- マルチテナントSaaSで各テナントに管理者を配置
- テナント固有のRealmまたはGroup単位で権限委任
- 上位管理者が委任範囲を制御

#### テナント管理者ロール作成

```bash
# Realm管理者ロール作成（特定Realmのみ）
TENANT_REALM="tenant1"

curl -X POST "http://localhost:8080/auth/admin/realms/master/users" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "tenant1-admin",
    "enabled": true,
    "credentials": [{"type": "password", "value": "AdminPass123"}]
  }'

# クライアントロールで権限制限
USER_ID="<tenant1-admin-user-id>"
curl -X POST "http://localhost:8080/auth/admin/realms/master/users/${USER_ID}/role-mappings/clients/${CLIENT_ID}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '[
    {"name": "manage-users"},
    {"name": "view-users"},
    {"name": "manage-clients"}
  ]'
```

### 部門別管理者パターン

**実装**:
- グループ管理者: 特定グループ内のユーザーのみ管理可能
- ロール管理者: 特定ロール範囲内の権限付与のみ可能
- アプリケーション管理者: 特定クライアント設定のみ変更可能

### 委任管理のベストプラクティス

| プラクティス | 理由 |
|------------|------|
| **最小権限原則** | 必要最小限の権限のみ委任 |
| **監査ログ必須** | すべての委任管理操作を記録 |
| **定期レビュー** | 委任権限の定期的な見直し |
| **エスカレーションパス** | 上位管理者へのエスカレーション経路確保 |

### Fine-Grained Admin Permissions

Keycloak 20+では細粒度の管理権限設定が可能。

**権限種別**:
- `manage-users`: ユーザー作成・編集・削除
- `view-users`: ユーザー情報閲覧のみ
- `manage-clients`: クライアント管理
- `view-realm`: Realm設定閲覧
- `manage-identity-providers`: IdP設定管理

```bash
# 特定グループ管理者に限定権限付与
curl -X PUT "http://localhost:8080/auth/admin/realms/${REALM}/groups/${GROUP_ID}/management/permissions" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "enabled": true,
    "permissions": {
      "manage-members": true,
      "view": true
    }
  }'
```

---

## SCIMプロトコル対応

SCIM（System for Cross-domain Identity Management）はクラウド間のアイデンティティプロビジョニングを標準化する。

### Keycloak SCIM実装

**Keycloak SCIM拡張機能**:
- Keycloak公式ではSCIMネイティブサポートなし
- コミュニティ拡張: `keycloak-scim` プロジェクト
- カスタム実装: REST APIラッパーでSCIM互換エンドポイント実装

### SCIM統合パターン

| パターン | 説明 |
|---------|------|
| **Keycloak as SCIM Server** | Keycloakがアイデンティティソースとして他システムにプロビジョニング |
| **Keycloak as SCIM Client** | Keycloakが外部SCIMサーバーからユーザーを取得 |

---

## LDAP/Active Directory統合

### User Federation基本概念

**User Federation:**
- 外部アイデンティティストア（LDAP、Active Directory等）との統合機能
- ユーザー情報をKeycloakにインポート、または認証を外部に委任

**統合モード:**

| モード | 説明 | ユーザー保存場所 |
|--------|------|----------------|
| **Stateful Broker** | LDAPデータをKeycloak DBにインポート + 同期 | Keycloak DB + LDAP |
| **Stateless Broker** | 認証のみLDAPに委任 | LDAP のみ |

---

### LDAP Provider設定

#### 基本設定項目

```
User Federation > Add Ldap providers:

Connection Settings:
- Vendor: Active Directory / Red Hat Directory Server / Other
- Connection URL: ldap://ldap.example.com:389
- Bind DN: cn=admin,dc=example,dc=com
- Bind Credential: <LDAP_ADMIN_PASSWORD>

Search Base:
- Users DN: ou=users,dc=example,dc=com
- Username LDAP attribute: uid (or sAMAccountName for AD)
- RDN LDAP attribute: uid
- UUID LDAP attribute: entryUUID (or objectGUID for AD)
- User Object Classes: inetOrgPerson, organizationalPerson

Synchronization:
- Import Users: ON（LDAPユーザーをKeycloakにインポート）
- Edit Mode: READ_ONLY / WRITABLE / UNSYNCED
- Sync Registrations: OFF（新規ユーザーをLDAPに書き戻さない）
```

---

### Edit Mode戦略

| モード | 動作 | 用途 |
|--------|------|------|
| **READ_ONLY** | LDAPは読取専用、変更は反映されない | LDAPが唯一の真実の情報源 |
| **WRITABLE** | Keycloakの変更をLDAPに書き戻し | LDAP移行中、双方向同期 |
| **UNSYNCED** | ローカル変更可能、LDAPには反映せず | 一時的なローカル変更許可 |

**推奨:**
- **レガシーLDAP維持**: READ_ONLY
- **LDAP移行計画中**: WRITABLE（移行期間中のみ）
- **LDAP廃止予定**: UNSYNCED → 最終的にUser Federation解除

---

### 同期設定

#### 手動同期

```
User Federation > [LDAP Provider] > Action:
- Sync all users: 全ユーザー同期（初回推奨）
- Sync changed users: 変更されたユーザーのみ同期
- Remove imported users: インポート済みユーザー削除
- Unlink users: ユーザーとLDAPのリンク解除（ローカルユーザー化）
```

**初回設定後の推奨手順:**
1. `Sync all users`を実行（初回フル同期）
2. 定期同期設定（以下参照）

#### 定期同期設定

```
User Federation > [LDAP Provider]:

Periodic Full Sync:
- Full Sync Period: 86400（秒）= 1日ごと
→ 全ユーザー情報を定期的に同期

Periodic Changed Users Sync:
- Changed Users Sync Period: 900（秒）= 15分ごと
→ 変更されたユーザーのみ効率的に同期
```

**注意:**
- パスワードはKeycloak DBに保存されない（LDAP認証時に都度検証）
- Unlink users後はパスワード未設定（リセット必要）

---

### LDAP Mappers

**Mapperの役割:**
- ユーザー以外の情報（グループ、ロール、証明書等）をLDAPからマッピング
- 自動設定されるが、カスタマイズ可能

#### Group Mapper（group-ldap-mapper）

**設定:**
```
User Federation > [LDAP Provider] > Mappers > Create:

- Name: group-mapper
- Mapper Type: group-ldap-mapper
- LDAP Groups DN: ou=groups,dc=example,dc=com
- Group Name LDAP Attribute: cn
- Group Object Classes: groupOfNames
- Membership LDAP Attribute: member
- Membership Attribute Type: DN
- User Groups Retrieve Strategy: LOAD_GROUPS_BY_MEMBER_ATTRIBUTE
- Mode: READ_ONLY / LDAP_ONLY
- Groups Path: /（トップレベルグループとしてインポート）
```

**動作:**
- LDAPグループをKeycloakグループとしてインポート
- グループ階層を保持
- ユーザーのグループメンバーシップ自動割当

---

#### Role Mapper（role-ldap-mapper）

**設定:**
```
Mappers > Create:

- Name: role-mapper
- Mapper Type: role-ldap-mapper
- LDAP Roles DN: ou=roles,dc=example,dc=com
- Role Name LDAP Attribute: cn
- Role Object Classes: groupOfNames
- Membership LDAP Attribute: member
- Use Realm Roles Mapping: ON（Realm Roleとして作成）
- Mode: READ_ONLY
```

**動作:**
- LDAPロール情報をKeycloak Realm Roleとしてインポート
- ユーザー認証時に自動的にロール付与

**Client Roleとして作成する場合:**
- `Use Realm Roles Mapping: OFF`
- `Client ID: <target-client-id>`を指定

---

### トラブルシューティング

#### ユーザーがログインできない

**確認事項:**
1. `User Federation > [LDAP Provider] > Test connection` → 接続確認
2. `Test authentication` → 認証テスト（Bind DN/Credentialで検証）
3. `Sync all users` → 手動同期してユーザーが作成されるか確認
4. ユーザーのLDAP DNが正しいか確認

#### グループ・ロールが同期されない

**確認事項:**
1. Mapper設定の`LDAP Groups DN`/`LDAP Roles DN`が正しいか
2. `Group Object Classes`/`Role Object Classes`がLDAPスキーマと一致しているか
3. 手動同期トリガー後、Admin Consoleでグループ・ロール一覧確認

---

## 外部IdP・ソーシャルログイン統合

### Identity Brokering概念

**Identity Broker:**
- Keycloakが中間IdPとして機能
- ユーザーは外部IdP（OIDC/SAML）で認証
- Keycloakがトークン受領、ユーザー作成・認証

**Federated User:**
- 外部IdPとリンクされたKeycloakユーザー
- 初回認証時にKeycloak DBに作成
- 以降、外部IdP認証でログイン可能

---

### OpenID Connect IdP設定

**設定例（Google）:**

```
Identity Providers > Add provider > Google:

- Display Name: Sign in with Google
- Client ID: <GOOGLE_CLIENT_ID>
- Client Secret: <GOOGLE_CLIENT_SECRET>
- Default Scopes: openid profile email
- Store Tokens: ON（外部IdPトークン保存）
- Stored Tokens Readable: OFF
- Trust Email: ON（Googleのメール確認済みを信頼）
```

**設定後の動作:**
1. ログインページに「Sign in with Google」ボタン表示
2. ユーザークリック → Googleログインページにリダイレクト
3. Google認証成功 → Keycloakにリダイレクト
4. Keycloakがユーザー作成（初回のみ）、ログイン完了

---

### GitHub IdP設定

**事前準備:**
1. GitHub OAuth App作成（https://github.com/settings/developers）
2. Authorization callback URL: `http://keycloak.example.com/realms/myrealm/broker/github/endpoint`

**Keycloak設定:**

```
Identity Providers > Add provider > GitHub:

- Client ID: <GITHUB_CLIENT_ID>
- Client Secret: <GITHUB_CLIENT_SECRET>
```

---

### SAML IdP設定

**設定例（エンタープライズSAML IdP）:**

```
Identity Providers > Add provider > SAML v2.0:

- Display Name: Corporate IdP
- Service Provider Entity ID: http://keycloak.example.com/realms/myrealm
- Single Sign-On Service URL: https://idp.example.com/saml/sso
- Single Logout Service URL: https://idp.example.com/saml/slo
- NameID Policy Format: urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress
- Want AuthnRequests Signed: ON
- Signature Algorithm: RSA_SHA256
- SAML Signature Key Name: CERT_SUBJECT
```

**IdP Mapper追加（SAMLアトリビュートマッピング）:**

```
Identity Providers > [SAML IdP] > Mappers > Create:

- Name: email-mapper
- Mapper Type: Attribute Importer
- Attribute Name: email (SAML Assertionの属性名)
- User Attribute Name: email (Keycloakユーザー属性)
```

---

### First Login Flow（初回ログインフロー）

**デフォルト動作:**
- 外部IdP初回認証時、Keycloakがユーザー作成
- プロファイル情報不足時、`Update Profile`画面表示

**カスタマイズ:**

```
Identity Providers > [IdP] > First Login Flow:
- First Login Flow: first broker login（デフォルト）
```

**カスタムフローで追加可能な処理:**
- メールアドレス確認強制
- 利用規約同意
- 追加属性入力要求
- OTP設定強制

---

## 判断基準・推奨事項

### プロビジョニング方式の選択

| シナリオ | 推奨方式 |
|---------|---------|
| **既存LDAP/AD統合** | User Federation（自動同期） |
| **HRMSイベント駆動** | Admin REST API + オーケストレーション |
| **マルチクラウドSaaS** | SCIM + Admin API |
| **リアルタイム要件** | Event Listener + Webhook |

### グループ vs ロールの使い分け

| 用途 | 推奨 |
|-----|------|
| **組織構造反映** | Group（階層化対応） |
| **権限制御** | Role（Client Role推奨） |
| **動的割当** | Group + Role Mapping |
| **属性ベース制御** | Attribute + Dynamic Role |

### セルフサービス有効化判断

| 条件 | 推奨 |
|-----|------|
| **ユーザー数 > 1000** | 有効化（管理負荷軽減） |
| **高度なセキュリティ要件** | 無効化またはワークフロー承認必須 |
| **エンドユーザーITリテラシー高** | 積極的に有効化 |
| **規制対応必須** | 監査ログ + 承認フロー必須 |

---

## Account Console（ユーザーセルフサービス）

### 概要

**Account Console:**
- ユーザーが自身のアカウント情報を管理できるWebアプリケーション
- Keycloakが標準提供
- URL: `http://keycloak.example.com/realms/myrealm/account`

**提供機能:**
- プロファイル情報更新
- パスワード変更
- 2要素認証設定
- セッション管理（リモートサインアウト含む）
- アプリケーション権限確認

---

### アクセス・認証

#### アクセス方法

```
URL: http://keycloak.example.com/realms/{realm-name}/account
→ Sign Inボタンクリック
→ ログインページにリダイレクト
→ 認証後、Account Console表示
```

#### 自動生成クライアント

Keycloakは以下のクライアントを自動作成：

| クライアント | 役割 |
|-----------|------|
| `account-console` | Account Console UIの認証 |
| `account` | Account REST APIへのアクセス認可 |

**カスタマイズ例:**
```
Clients > account-console:
- Consent Required: ON（GDPR対応等）
- Client Authentication: OFF（Public Client）
```

---

### 主要機能

#### 1. Personal Info（プロファイル管理）

**編集可能項目:**
- Email
- First Name
- Last Name
- カスタム属性（設定による）

**操作:**
```
Account Console > Personal Info:
- Email: alice@example.com
- First Name: Alice
- Last Name: Smith
→ Save
```

---

#### 2. Account Security

##### Password変更

```
Account Security > Signing In > Password:
- Current password: <current>
- New password: <new>
- Password confirmation: <new>
→ Save
```

##### 2要素認証（OTP）設定

```
Account Security > Signing In > Two-factor Authentication:
- Set up Authenticator application
→ QRコードスキャン（Google Authenticator等）
→ Verification code入力
→ Submit
```

**サポートされる2FA:**
- **OTP**: Google Authenticator、Authy等
- **WebAuthn**: YubiKey、Touch ID、Windows Hello等

##### WebAuthn（セキュリティキー）設定

```
Account Security > Signing In > Security Keys:
- Register Security Key
→ セキュリティキー挿入・タッチ
→ キー名入力
→ Submit
```

---

#### 3. Signing In（認証設定）

**表示内容:**
- 設定済み資格情報一覧（Password、OTP、WebAuthn等）
- 各資格情報の登録日時
- 削除・再設定オプション

---

#### 4. Device Activity（セッション管理）

**表示情報:**
- アクティブセッション一覧
- デバイス情報（ブラウザ、OS、IPアドレス）
- ログイン日時

**操作:**
```
Account Security > Device Activity:
- [セッション選択] > Sign out
→ リモートデバイスからサインアウト
```

**用途:**
- 不正アクセス検知
- 紛失デバイスからのセッション切断

---

#### 5. Applications（アプリケーション権限管理）

**表示情報:**
- ログイン履歴のあるアプリケーション一覧
- 各アプリに付与された権限（スコープ）
- 最終アクセス日時

**操作:**
```
Applications:
- [アプリケーション選択] > Remove access
→ アクセス許可取り消し
```

**用途:**
- 不要なアプリケーションアクセス削除
- GDPR準拠（データアクセス透明性）

---

### アクセス制御

#### ロールベースアクセス制御

**デフォルトロール:**
- `manage-account`: 全機能アクセス可能
- `view-profile`: プロファイル閲覧のみ

**ロール割当:**
```
Users > [ユーザー選択] > Role Mapping > Client Roles:
- Client: account
- Available Roles:
  - manage-account（デフォルトで全ユーザーに付与）
  - view-profile
  - manage-account-links（外部IdPリンク管理）
```

**機能制限例:**
- `manage-account`削除 → Account Console全体へのアクセス拒否
- `view-profile`のみ付与 → 閲覧専用モード

---

### カスタマイズ・拡張

#### テーマ適用

```
Realm Settings > Themes:
- Account Theme: <custom-theme>
```

**カスタムテーマで実現可能:**
- ロゴ・カラースキーム変更
- カスタムフィールド追加（JavaScript拡張）
- レイアウト変更

#### カスタム属性のUI表示

**方法:**
1. User Attributes定義（Admin Console）
2. Account Console拡張（カスタムテーマ・JavaScript）
3. Protocol Mapperでトークンに含める

**例: 電話番号入力フィールド追加**
- カスタムテーマで`account.ftl`編集
- JavaScriptで`phoneNumber`属性を読み書き

---

### Account REST API

**エンドポイント:**
```
GET /auth/realms/{realm}/account
GET /auth/realms/{realm}/account/sessions
DELETE /auth/realms/{realm}/account/sessions/{session-id}
```

**認証:**
- アクセストークン必須（`manage-account`ロール）

**用途:**
- カスタムAccount Consoleアプリ開発
- モバイルアプリからのアカウント管理
