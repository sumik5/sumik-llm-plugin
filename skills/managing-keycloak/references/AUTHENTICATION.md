# Keycloak 認証

## Identity Brokering

Identity Brokeringは外部IdP（Identity Provider）を統合し、ユーザーが外部アカウントでKeycloakにログインできるようにする機能。

### 外部IdP連携設定（Google例）

```bash
# kcadm.shでGoogle IdP追加
./kcadm.sh config credentials --server http://localhost:8080/auth \
  --realm master --user admin --password admin

./kcadm.sh create identity-provider/instances -r myrealm \
  -s provider=google \
  -s 'config={"clientId":"YOUR_GOOGLE_CLIENT_ID","clientSecret":"YOUR_GOOGLE_CLIENT_SECRET"}'
```

**設定パラメータ**:
| パラメータ | 説明 |
|-----------|------|
| `clientId` | GoogleでのアプリケーションID |
| `clientSecret` | Googleでの秘密鍵 |

**ポイント**:
- SAML、OpenID Connect両方のIdPをサポート
- ユーザーは外部アカウント認証後、Keycloak内で統一管理される

---

## Social Login

Social Loginを利用すると、Google、Facebook、GitHubなどのソーシャルアカウントでログイン可能になる。

### Social Login設定手順（Admin Console）

1. Keycloak Admin Consoleにログイン
2. **Identity Providers** セクションに移動
3. ドロップダウンから **Google** を選択
4. 以下を設定:
   - **Client ID**: `YOUR_GOOGLE_CLIENT_ID`
   - **Client Secret**: `YOUR_GOOGLE_CLIENT_SECRET`
5. 保存後、ログインページに「Sign in with Google」オプションが表示される

**セキュリティ考慮事項**:
- Redirect URIをKeycloakとGoogle側で一致させる
- Client Secretは安全に管理
- スコープ（email、profile等）を適切に設定

**サポート対象**:
- Google, Facebook, GitHub, LinkedIn, Twitter等

---

## 管理ツール

### Admin Console

Keycloak Admin Consoleは**GUI管理インターフェース**で、Realm、ユーザー、クライアント設定を視覚的に管理できる。

**主な機能**:
- Realm設定
- ユーザー作成・ロール割当
- Client設定（redirectURI、プロトコル選択）
- Authentication Flows管理

**例: 新規ユーザー作成**
1. **Users** セクションに移動
2. **Add user** をクリック
3. 以下を入力:
   - Username: `newuser`
   - Email: `newuser@example.com`
   - First Name: `New`
   - Last Name: `User`
4. **Credentials** タブでパスワード設定
5. **Role Mappings** タブでロール割当

---

### Admin CLI (kcadm.sh)

Keycloak Admin CLIはコマンドラインからKeycloakを管理・自動化できるツール。

**基本操作**:

```bash
# ログイン
kcadm.sh config credentials --server http://localhost:8080/auth \
  --realm master --user admin --password yourpassword

# ユーザー一覧取得
kcadm.sh get users -r your-realm

# Realm更新
kcadm.sh update realms/{realm-name} -s 'eventsEnabled=true'

# Client作成
kcadm.sh create clients -r myrealm -s clientId=my-client -s publicClient=false
```

**利点**:
- スクリプト化・自動化可能
- CI/CDパイプラインに統合可能
- 大規模デプロイに最適

---

### Account Console

Account Consoleはユーザーが**自分のプロフィールを管理**するセルフサービスポータル。

**機能**:
- プロフィール情報更新（名前、メール等）
- パスワード変更
- セッション管理
- アカウントアクティビティ確認
- リンクされた外部アカウント管理

**パスワード変更手順**:
1. Account Consoleにログイン
2. **Password** メニューに移動
3. 現在のパスワードと新しいパスワードを入力
4. **Save** をクリック

**カスタマイズ**:
- テーマ変更可能
- 多言語対応
- 組織ブランディングに合わせて拡張可能

---

## Custom Attributes

Keycloakではユーザープロフィールに**カスタム属性**を追加でき、追加メタデータを保存可能。

### カスタム属性の追加（Admin Console）

1. **Users** セクションでユーザーを選択
2. **Attributes** タブに移動
3. Key-Valueペアを追加:
   - Key: `employeeId`, Value: `12345`
   - Key: `department`, Value: `IT`

### REST APIで取得

```bash
# アクセストークン取得（Client Credentials Flow）
TOKEN=$(curl -X POST "http://localhost:8080/realms/{realm}/protocol/openid-connect/token" \
  --data "client_id={client_id}" \
  --data "client_secret={client_secret}" \
  --data "grant_type=client_credentials" | jq -r '.access_token')

# ユーザー情報（カスタム属性含む）取得
curl -X GET "http://localhost:8080/admin/realms/{realm}/users/{user_id}" \
  -H "Authorization: Bearer $TOKEN"
```

**結果**:
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

**活用シーン**:
- カスタムクレーム生成
- 外部システム連携
- 独自のビジネスロジック実装

---

## テーマカスタマイズ

Keycloakテーマでログインページ、メール、Account Consoleの外観をカスタマイズできる。

### ログインページカスタマイズ例

**1. テーマディレクトリ作成**
```bash
mkdir -p themes/my-custom-theme/login
```

**2. カスタムログインテンプレート作成（login.ftl）**
```html
<!-- themes/my-custom-theme/login/login.ftl -->
<!DOCTYPE html>
<html>
<head>
  <title>Custom Login</title>
</head>
<body>
  <h1>Welcome to My Custom Login Page</h1>
  <form action="${url.loginAction}" method="post">
    <label for="username">Username:</label>
    <input type="text" name="username" id="username"><br>
    <label for="password">Password:</label>
    <input type="password" name="password" id="password"><br>
    <input type="submit" value="Login">
  </form>
</body>
</html>
```

**3. Admin Consoleで有効化**
1. **Realm Settings** → **Themes** に移動
2. **Login Theme** を `my-custom-theme` に設定

**FreeMarkerテンプレート機能**:
- 動的値注入（`${url.loginAction}`等）
- 条件分岐、ループ、マクロ利用可能
- CSSカスタマイズでブランディング統一

---

## Authentication Flow

Authentication Flowは認証プロセスのステップを定義し、カスタマイズ可能。

### Flowの基本構造

**階層構造:**
- Flowは複数のExecutionまたはSubflowで構成
- Executionは実際の認証ステップ（パスワード入力、OTP検証等）
- Subflowは別のFlowを含む入れ子構造

**Execution設定（Requirement）:**
| 設定 | 動作 |
|------|------|
| **REQUIRED** | 必ず成功が必要。失敗時はフロー停止 |
| **ALTERNATIVE** | 成功すればOK。失敗しても次に進む |
| **CONDITIONAL** | 条件付き実行（Subflowに適用） |
| **DISABLED** | 無効化 |

### デフォルトBrowser Flowの実行順序

1. **Cookie** (ALTERNATIVE): 既存セッションでの自動再認証
2. **Kerberos** (DISABLED): Kerberos認証（デフォルト無効）
3. **Identity Provider Redirector** (ALTERNATIVE): 外部IdPへの自動リダイレクト
4. **Forms** Subflow (ALTERNATIVE):
   - **Username Password Form** (REQUIRED): ユーザー名・パスワード入力
   - **Conditional OTP** Subflow (CONDITIONAL):
     - **Condition - User Configured** (REQUIRED): OTP設定済み確認
     - **OTP Form** (REQUIRED): OTP検証

### カスタムフロー作成例（Identifier First Login）

```bash
# 既存フローを複製
# Admin Console: Authentication → Browser → Duplicate → "My Browser"

# Username Password Formを削除し、2ステップに分割
# 1. Username Form (REQUIRED) を追加
# 2. Password Form (REQUIRED) を追加
# 3. Browser Flowにバインド
```

**結果**: ユーザー名とパスワードを別々の画面で収集

### カスタムフロー作成例（OTP追加）

```bash
# カスタムフロー作成
kcadm.sh create authentication/flows -r myrealm \
  -s alias="MyCustomFlow" \
  -s description="Custom authentication flow with OTP" \
  -s providerId="basic-flow"

# パスワード認証ステップ追加
kcadm.sh create authentication/flows/MyCustomFlow/executions/execution -r myrealm \
  -b '{ "provider": "auth-username-password-form", "requirement": "REQUIRED" }'

# OTP認証ステップ追加
kcadm.sh create authentication/flows/MyCustomFlow/executions/execution -r myrealm \
  -b '{ "provider": "auth-otp-form", "requirement": "REQUIRED" }'

# カスタムフローをデフォルトに設定
kcadm.sh update authentication/flows/bindings -r myrealm \
  -s browserFlow="MyCustomFlow"
```

### 判断基準テーブル

| 要件 | 推奨フロー |
|------|-----------|
| パスワードのみ | Browser Flow (デフォルト) |
| MFA必須 | Browser + OTP/TOTP |
| 外部IdP統合 | Identity Provider Redirector |
| 条件付き認証 | Conditional Authenticator + カスタムロジック |
| Identifier First | Username Form + Password Form（別ステップ） |

**ポイント**:
- フローは階層構造（サブフロー対応）
- Execution単位でREQUIRED/OPTIONAL/ALTERNATIVE設定可能
- フロー変更時は必ず複製を作成（ロールバック可能）

### Required Actions（必須アクション）

ログイン時に特定のアクションを強制する機能。

| アクション | 用途 |
|-----------|------|
| **Configure OTP** | 初回ログイン時にMFA設定 |
| **Update Password** | 一時パスワードからの移行 |
| **Update Profile** | プロフィール情報入力 |
| **Verify Email** | メールアドレス検証 |
| **Terms and Conditions** | 利用規約への同意 |

**ユーザーへの割当（CLI）:**
```bash
kcadm.sh update users/{user-id}/execute-actions -r myrealm \
  -b '["CONFIGURE_TOTP","UPDATE_PASSWORD"]'
```

---

## Password管理詳細

### パスワードハッシュアルゴリズム

**デフォルト設定:**
- **アルゴリズム**: PBKDF2（HMAC-SHA-256）
- **反復回数**: 27,500回
- **Salt**: ランダム生成（ユーザーごと）

**推奨設定（Admin Console: Authentication → Policies）:**
- **HMAC-SHA-512**: より強力なハッシュ
- **反復回数**: 600,000回以上（OWASP推奨）

**注意**: 反復回数増加はCPU負荷増大につながる。パフォーマンスとセキュリティのバランスを考慮すること。

### パスワードポリシー設定

**利用可能なポリシー:**
| ポリシー | 説明 |
|---------|------|
| **Minimum Length** | 最小文字数（例: 8文字以上） |
| **Special Characters** | 特殊文字必須個数 |
| **Uppercase Characters** | 大文字必須個数 |
| **Lowercase Characters** | 小文字必須個数 |
| **Digits** | 数字必須個数 |
| **Expire Password** | パスワード有効期限（日数） |
| **Not Username** | ユーザー名を含まない |
| **Password Blacklist** | 禁止パスワードリスト |
| **Password History** | 過去N個のパスワード再利用禁止 |

**設定例（Admin Console）:**
```
Authentication → Policies → Add policy
- Minimum Length: 12
- Special Characters: 1
- Uppercase Characters: 1
- Lowercase Characters: 1
- Digits: 2
- Expire Password: 90
- Password History: 5
```

### パスワードリセット

**管理者経由:**
1. **Users** → ユーザー選択 → **Credentials** タブ
2. **Set Password** → 新パスワード入力
3. **Temporary**: ONで次回ログイン時に変更強制

**ユーザー自身（Forgot Password）:**
1. **Realm Settings** → **Login** → **Forgot password** をON
2. ログインページに「Forgot Password?」リンク表示
3. ユーザー名/メール入力 → リセットリンク送信

**前提条件**: SMTP設定が必要（`Realm Settings → Email`）

---

## MFA（多要素認証）

MFAは追加の認証要素を要求することでセキュリティを強化する。

### OTP（One-Time Password）

#### OTPアルゴリズム

| アルゴリズム | 特徴 | 有効期限 | 用途 |
|------------|------|---------|------|
| **TOTP** | 時刻ベース | 30秒（デフォルト） | 一般的なMFA |
| **HOTP** | カウンタベース | 使用まで無期限 | 特殊用途 |

**デフォルト設定（Admin Console: Authentication → OTP Policy）:**
- **OTP Type**: Time-Based (TOTP)
- **OTP Hash Algorithm**: SHA1
- **Number of Digits**: 6
- **Look Ahead Window**: 1（時刻ずれ補償）
- **OTP Token Period**: 30秒

**推奨モバイルアプリ:**
- FreeOTP
- Google Authenticator

#### OTP有効化手順（条件付き）

**デフォルト動作（Conditional OTP）:**
- ユーザーがOTP設定済み → OTP入力必須
- ユーザーがOTP未設定 → パスワードのみでOK

**強制有効化（全ユーザー必須）:**
```bash
# Browser Flowの Conditional OTP SubflowをREQUIREDに変更
# Admin Console: Authentication → Browser → Conditional OTP → REQUIRED
```

**結果**: OTP未設定ユーザーは初回ログイン時にOTP設定画面が表示される。

#### ユーザーのOTP設定（Account Console）

1. `http://localhost:8080/realms/{realm}/account` にアクセス
2. **Signing in** → **Set up authenticator application**
3. モバイルアプリでQRコードをスキャン
4. 生成されたコードを入力して完了

### Email OTP vs TOTP

| 項目 | Email OTP | TOTP |
|------|-----------|------|
| **配信方法** | メール送信 | アプリ生成（Google Authenticator等） |
| **セキュリティ** | メールセキュリティに依存 | ローカル生成（高セキュリティ） |
| **利便性** | メールアクセス必要 | アプリインストール必要 |
| **推奨用途** | 利便性優先環境 | 高セキュリティ環境 |

### 設定手順

**Email OTP追加**:
```bash
# Email Execution追加
kcadm.sh create authentication/flows/Browser/executions/execution -r myrealm \
  -b '{ "provider": "auth-email", "requirement": "REQUIRED" }'
```

**TOTP追加**:
```bash
# OTP Form追加
kcadm.sh create authentication/flows/Browser/executions/execution -r myrealm \
  -b '{ "provider": "auth-otp-form", "requirement": "REQUIRED" }'
```

---

## WebAuthn（FIDO2）

### WebAuthn概要

**特徴:**
- 公開鍵暗号方式（秘密鍵はデバイス内保持）
- 共有鍵なし（OTPより安全）
- フィッシング耐性
- パスワードレス認証対応

**対応デバイス:**
- セキュリティキー（YubiKey、Titan Key等）
- スマートフォン（指紋認証、Face ID対応）
- NFC対応デバイス

### WebAuthn設定（Admin Console）

**Authentication → WebAuthn Policy:**
| 設定項目 | 説明 |
|---------|------|
| **Relying Party Name** | サービス名（ユーザーに表示） |
| **Signature Algorithms** | RS256、ES256等 |
| **Attestation Preference** | none/indirect/direct（デバイス検証レベル） |
| **Authenticator Attachment** | platform（内蔵）/cross-platform（外部キー） |
| **User Verification** | required/preferred/discouraged（生体認証要否） |

### WebAuthn有効化手順（2FA）

**FlowカスタマイズOTP → WebAuthn**:
1. Browser Flowを複製（"My WebAuthn"）
2. Conditional OTP SubflowからOTP Formを削除
3. WebAuthn Authenticator Executionを追加
4. Browser FlowにMy WebAuthnをバインド

**CLI設定例:**
```bash
kcadm.sh create authentication/flows/Browser/executions/execution -r myrealm \
  -b '{
    "provider": "webauthn-authenticator",
    "requirement": "ALTERNATIVE",
    "config": {
      "rpEntityName": "MyApp",
      "signatureAlgorithms": "ES256,RS256"
    }
  }'
```

### デバイス登録（Account Console）

1. `http://localhost:8080/realms/{realm}/account` にアクセス
2. **Signing in** → **Security key** → **Set up Security key**
3. **Register** → ブラウザプロンプトでデバイス操作（タッチ等）
4. デバイス名を入力して完了

**認証フロー:**
- ユーザー名/パスワード入力 → デバイス認証プロンプト（コード入力不要）

### Password-less認証（WebAuthnのみ）

**実装ポイント:**
- Username FormのみでPassword Formを削除
- WebAuthn Authenticatorを直接REQUIREDに設定
- ユーザーはデバイス操作のみで認証完了

---

## 強認証（Strong Authentication）

### 強認証の定義

- **2FA**: パスワード + OTP/WebAuthn
- **MFA**: パスワード + OTP + 生体認証（WebAuthn内蔵）

### Step-up Authentication（段階的認証）

**概念:**
- 通常操作: パスワードのみ
- 機密操作: 追加でOTP/WebAuthn要求

**実装:**
```bash
# Authorization Code Flowで認証レベル指定
POST /auth/realms/{realm}/protocol/openid-connect/auth
  ?acr_values=urn:keycloak:acr:silver
```

**参考**: [Step-up Authenticationドキュメント](https://www.keycloak.org/docs/latest/server_admin/#_step-up-flow)

### リスクベース認証（カスタム実装）

**Authenticator SPIで実装:**
```java
public class RiskBasedAuthenticator implements Authenticator {
    @Override
    public void authenticate(AuthenticationFlowContext context) {
        String clientIp = context.getConnection().getRemoteAddr();
        int hour = LocalTime.now().getHour();

        // リスクスコア算出
        int riskScore = 0;
        if (!isKnownIp(clientIp)) riskScore += 50;
        if (hour < 6 || hour > 22) riskScore += 30;

        if (riskScore > 50) {
            // 高リスク: MFA強制
            context.getAuthenticationSession().setAuthNote("mfaRequired", "true");
        }
        context.success();
    }
}
```

**外部リスクエンジン統合例:**
- AWS Fraud Detector
- Google reCAPTCHA Enterprise
- カスタムMLモデル

---

## Event Logging

Event LoggingはKeycloakの認証・管理アクティビティを記録・監査する機能。

### イベント種別

| イベントタイプ | 説明 |
|--------------|------|
| **LOGIN** | ログイン成功 |
| **LOGOUT** | ログアウト |
| **REGISTER** | ユーザー登録 |
| **UPDATE_PROFILE** | プロフィール更新 |
| **UPDATE_PASSWORD** | パスワード変更 |
| **CODE_TO_TOKEN** | 認可コード→トークン交換 |

### Event Logging有効化

```bash
# イベントロギング有効化
kcadm.sh update realms/{realm-name} -s 'eventsEnabled=true' \
  -s 'eventsListeners=["jboss-logging"]' \
  -s 'enabledEventTypes=["LOGIN", "REGISTER", "LOGOUT", "CODE_TO_TOKEN", "UPDATE_PROFILE", "UPDATE_PASSWORD"]'

# 管理イベントロギング有効化
kcadm.sh update realms/{realm-name} -s 'adminEventsEnabled=true' \
  -s 'adminEventsDetailsEnabled=true'
```

**設定例**:
```bash
kcadm.sh update realms/myrealm \
  -s eventsEnabled=true \
  -s 'eventsListeners=["jboss-logging"]' \
  -s 'enabledEventTypes=["LOGIN","LOGOUT","REGISTER"]'
```

**ログ確認**:
- Admin Consoleの **Events** セクションで確認
- 外部SIEM（Security Information and Event Management）システムへのエクスポート可能

---

## Admin Event Tracking

Admin Event Trackingは管理アクション（ユーザー作成、ロール変更等）を記録する。

### Admin Event有効化

```bash
# 詳細な管理イベントトラッキング有効化
kcadm.sh update realms/{realm-name} \
  -s 'adminEventsEnabled=true' \
  -s 'adminEventsDetailsEnabled=true'

# 管理イベント取得
kcadm.sh get events -r {realm-name} \
  --fields type,realmId,userId,clientId,ipAddress
```

**ログ内容**:
- イベントタイプ（CREATE, UPDATE, DELETE）
- 実行ユーザー
- 対象オブジェクト
- IPアドレス
- 変更前後の状態（`adminEventsDetailsEnabled=true`時）

**活用シーン**:
- セキュリティ監査
- 変更追跡
- コンプライアンス対応
- ロールバック・デバッグ

**ポイント**:
- Admin Consoleの **Admin Events** セクションで確認可能
- イベントフィルタリング（タイプ、ユーザー別）可能

---

## カスタム認証フローの詳細設計

Keycloakの認証フローは高度にカスタマイズ可能であり、複雑な要件に対応できる。

### Required Actions（必須アクション）

ユーザーログイン時に特定のアクションを強制する機能。

**主要なRequired Actions:**
| アクション | 説明 | 用途 |
|-----------|------|------|
| **Configure OTP** | OTP（TOTP）設定を強制 | 初回ログイン時にMFA設定 |
| **Update Password** | パスワード変更を強制 | 一時パスワードからの移行 |
| **Update Profile** | プロフィール情報入力を強制 | 初回ログイン時のプロフィール完成 |
| **Verify Email** | メールアドレス検証を強制 | メールアドレスの有効性確認 |
| **Terms and Conditions** | 利用規約への同意を強制 | コンプライアンス要件 |

**ユーザーへの割当（CLI）:**
```bash
# ユーザーにRequired Action割当
kcadm.sh update users/{user-id}/execute-actions -r myrealm \
  -b '["CONFIGURE_TOTP","UPDATE_PASSWORD"]'
```

**結果:** ユーザーは次回ログイン時にOTP設定とパスワード変更を完了するまで先に進めない。

### Authenticator SPI（カスタム認証ロジック）

Keycloakは**Service Provider Interface（SPI）**を通じてカスタム認証ロジックを実装可能。

**実装手順:**

1. **Authenticator インターフェース実装:**
```java
public class CustomAuthenticator implements Authenticator {
    @Override
    public void authenticate(AuthenticationFlowContext context) {
        // カスタムロジック（例: IPアドレス制限、デバイスフィンガープリント検証）
        String clientIp = context.getConnection().getRemoteAddr();
        if (isAllowedIp(clientIp)) {
            context.success();
        } else {
            context.failure(AuthenticationFlowError.ACCESS_DENIED);
        }
    }
}
```

2. **AuthenticatorFactory実装:**
```java
public class CustomAuthenticatorFactory implements AuthenticatorFactory {
    public static final String PROVIDER_ID = "custom-ip-authenticator";

    @Override
    public Authenticator create(KeycloakSession session) {
        return new CustomAuthenticator();
    }

    @Override
    public String getId() {
        return PROVIDER_ID;
    }
}
```

3. **デプロイ:** JARファイルを `providers/` ディレクトリに配置し、Keycloak再起動

4. **Admin Consoleで追加:** Authentication → Flows → 対象フローに `custom-ip-authenticator` を追加

**ユースケース:**
- 特定IPアドレスからのログインのみ許可
- デバイスフィンガープリント検証
- 外部APIを呼び出してリスクスコア算出

---

## MFA戦略

### TOTP（Time-based One-Time Password）

最も一般的なMFA手法。Google Authenticator、Microsoft Authenticatorなどのアプリを使用。

**有効化手順（Admin Console）:**
1. Authentication → Flows → Browser を選択
2. "Browser - Conditional OTP" サブフローを追加
3. "OTP Form" を **REQUIRED** に設定

**ユーザー体験:**
- 初回ログイン時にQRコードをスキャン
- 以降、ログイン時に6桁のコード入力が必須

### WebAuthn（FIDO2）

ハードウェアセキュリティキー（YubiKey等）やプラットフォーム認証（Touch ID、Face ID）を使用。

**有効化手順:**
1. Authentication → Flows → Browser
2. "WebAuthn Authenticator" を追加
3. REQUIRED または ALTERNATIVE に設定

**設定オプション:**
| 設定項目 | 説明 |
|---------|------|
| **Relying Party Name** | サービス名（ユーザーに表示） |
| **Signature Algorithms** | RS256、ES256等 |
| **Attestation Preference** | none/indirect/direct（デバイス検証レベル） |
| **Authenticator Attachment** | platform（内蔵）/cross-platform（外部キー） |
| **User Verification** | required/preferred/discouraged（生体認証要否） |

**CLI設定例:**
```bash
kcadm.sh create authentication/flows/Browser/executions/execution -r myrealm \
  -b '{
    "provider": "webauthn-authenticator",
    "requirement": "ALTERNATIVE",
    "config": {
      "rpEntityName": "MyApp",
      "signatureAlgorithms": "ES256,RS256"
    }
  }'
```

### SMS/Email OTP

一時コードをSMSまたはメールで送信。

**SMS OTP実装（カスタムAuthenticator）:**
```java
public class SmsOtpAuthenticator implements Authenticator {
    @Override
    public void authenticate(AuthenticationFlowContext context) {
        String phoneNumber = context.getUser().getFirstAttribute("phoneNumber");
        String code = generateCode();
        sendSms(phoneNumber, code);
        context.challenge(context.form().createForm("sms-otp.ftl"));
    }

    private void sendSms(String phoneNumber, String code) {
        // Twilio/AWS SNS等のSMS API呼び出し
    }
}
```

**Email OTP（Built-in）:**
- Authentication → Flows → "Email Authenticator" を追加

### 条件付きMFA

特定条件でのみMFAを要求（例: 未知のIPアドレスから）。

**実装例（Conditional Authenticator）:**
```bash
# Conditional Sub-Flow作成
kcadm.sh create authentication/flows -r myrealm -b '{
  "alias": "Conditional MFA",
  "providerId": "basic-flow",
  "topLevel": false
}'

# Condition: User Attribute追加
kcadm.sh create authentication/flows/Conditional\ MFA/executions/execution -r myrealm \
  -b '{
    "provider": "conditional-user-attribute",
    "config": {
      "attribute_name": "mfaRequired",
      "attribute_value": "true"
    }
  }'

# OTP Form追加
kcadm.sh create authentication/flows/Conditional\ MFA/executions/execution -r myrealm \
  -b '{ "provider": "auth-otp-form" }'
```

---

## 適応型・リスクベース認証

ユーザーのコンテキスト（位置情報、デバイス、時間帯等）に基づいて認証要件を動的に調整。

### Step-up Authentication（段階的認証）

通常は軽い認証で、機密操作時に追加認証を要求。

**実装パターン:**
1. 通常ログイン: パスワードのみ
2. 機密操作（例: 銀行送金）: OTP追加要求

**REST API例:**
```bash
# 追加認証要求
POST /auth/realms/{realm}/protocol/openid-connect/auth
  ?client_id={client_id}
  &response_type=code
  &scope=openid email profile
  &acr_values=urn:keycloak:acr:silver  # 認証レベル指定
```

### コンテキスト分析（カスタム実装）

**実装例（IPアドレス・時間帯ベース）:**
```java
public class RiskBasedAuthenticator implements Authenticator {
    @Override
    public void authenticate(AuthenticationFlowContext context) {
        String clientIp = context.getConnection().getRemoteAddr();
        int hour = LocalTime.now().getHour();

        // リスクスコア算出
        int riskScore = 0;
        if (!isKnownIp(clientIp)) riskScore += 50;
        if (hour < 6 || hour > 22) riskScore += 30;

        if (riskScore > 50) {
            // 高リスク: MFA強制
            context.getAuthenticationSession().setAuthNote("mfaRequired", "true");
            context.success();
        } else {
            // 低リスク: パスワードのみでOK
            context.success();
        }
    }
}
```

**外部リスクエンジン統合:**
- AWS Fraud Detector
- Google reCAPTCHA Enterprise
- カスタムML モデル

---

## 同意管理・プライバシー制御

GDPRやプライバシー規制対応のため、ユーザーがデータ利用に同意するフローを実装。

### Client Consent（クライアント同意）

クライアントがユーザーデータにアクセスする際、明示的な同意を要求。

**有効化（Admin Console）:**
1. Clients → 対象クライアント
2. **Consent Required** を有効化
3. 同意画面でどの情報を共有するか表示

**ユーザー体験:**
- ログイン後、「{クライアント名} に以下の情報へのアクセスを許可しますか？」と表示
- チェックボックスで選択後、「許可」ボタンをクリック

**CLI設定:**
```bash
kcadm.sh update clients/{client-id} -r myrealm -s consentRequired=true
```

### スコープベース同意

Client Scopesごとに同意を要求。

**設定例:**
```bash
# Optional Client Scope作成
kcadm.sh create client-scopes -r myrealm -b '{
  "name": "phone",
  "protocol": "openid-connect",
  "attributes": {
    "display.on.consent.screen": "true",
    "consent.screen.text": "電話番号へのアクセス"
  }
}'

# Clientに追加
kcadm.sh update clients/{client-id}/optional-client-scopes/{scope-id} -r myrealm
```

**結果:** クライアントがscope=phoneをリクエストした場合のみ、同意画面に「電話番号へのアクセス」が表示される。

### 同意の取り消し

ユーザーがAccount Consoleから同意を取り消し可能。

**Account Consoleでの操作:**
1. Account Console → Applications
2. 対象アプリケーションの「Revoke」ボタンをクリック
3. 次回ログイン時に再度同意が要求される

---

---

## Logout戦略

### RP-Initiated Logout（OpenID Connect）

**仕組み:**
1. アプリがKeycloakの `end_session_endpoint` にリダイレクト
2. Keycloakがセッション内の全クライアントに通知
3. セッション無効化（全トークンが無効に）

**パラメータ:**
| パラメータ | 説明 |
|-----------|------|
| `id_token_hint` | 以前発行されたID Token（セッション特定用） |
| `post_logout_redirect_uri` | Logout後のリダイレクトURI |
| `state` | 状態維持（クライアント側） |

**例:**
```
GET /realms/{realm}/protocol/openid-connect/logout
  ?id_token_hint={id_token}
  &post_logout_redirect_uri=https://myapp.com
```

### Token Expiration戦略（推奨）

**最もシンプルで堅牢な方法:**
- ID Token / Access Token: 短命（5分等）
- Refresh Token: セッション無効化時に使用不可
- アプリは定期的にRefresh TokenでToken更新を試行
- 失敗 → Logout済みと判断してアプリセッション削除

**利点:**
- 実装がシンプル
- ネットワーク不要（アプリ側判定のみ）
- Public Client（SPA等）に最適

**欠点:**
- Logout反映に数分かかる（Token有効期間分）

### OIDC Session Management（非推奨）

**仕組み:**
- 隠しiframeでKeycloakのセッションCookieを監視
- Cookie変化時にアプリに通知

**問題点:**
- 多くのブラウザがサードパーティCookieをブロック
- iframe内でCookieにアクセス不可

**結論**: 新規実装では使用しないこと

### OIDC Back-Channel Logout

**仕組み:**
1. ユーザーがアプリAでLogoutボタンをクリック
2. KeycloakがセッションIDに紐づく全アプリにLogout Tokenを送信
3. 各アプリはLogout Tokenを検証してセッション無効化

**Logout Token（署名済みJWT）:**
```json
{
  "iss": "http://localhost:8080/realms/myrealm",
  "sub": "user-id-123",
  "aud": "my-client",
  "iat": 1678901234,
  "jti": "logout-token-id",
  "events": {
    "http://schemas.openid.net/event/backchannel-logout": {}
  },
  "sid": "session-id-abc"
}
```

**クライアント設定（Admin Console）:**
```
Clients → {client-id} → Advanced → Backchannel logout URL
  例: https://myapp.com/logout-callback
```

#### 実装上の課題

**ステートフルアプリケーション（クラスタ構成）:**
- Logout Tokenがランダムなインスタンスに送信される
- セッションを保持するインスタンスと異なる可能性
- 対策: セッション分散（Redis等）またはアプリ層でブロードキャスト

**ステートレスアプリケーション:**
- セッションがCookieに保存されている
- Logout Tokenを受信してもCookieを直接無効化できない
- 対策: Logout TokenをBlacklistに保存、次回リクエスト時にチェック

**設定例（Spring Security）:**
```java
@PostMapping("/logout-callback")
public ResponseEntity<Void> backchannelLogout(@RequestParam("logout_token") String logoutToken) {
    // JWT検証
    Jwt jwt = jwtDecoder.decode(logoutToken);
    String sessionId = jwt.getClaimAsString("sid");

    // セッション無効化
    sessionRegistry.removeSessionInformation(sessionId);
    return ResponseEntity.ok().build();
}
```

### Logout戦略の選択

| 用途 | 推奨戦略 |
|------|---------|
| SPA・モバイル | Token Expiration |
| サーバーサイド（ステートフル） | Back-Channel Logout + セッション分散 |
| サーバーサイド（ステートレス） | Token Expiration |
| 即座のLogout必須 | Back-Channel Logout（クラスタ対応必要） |

---

## 監査ログ・イベントストリーム統合

エンタープライズ環境では、監査ログを外部SIEMやログ管理システムに統合する必要がある。

### Kafka統合

KeycloakイベントをKafkaトピックに送信。

**設定（standalone.xml）:**
```xml
<spi name="eventsListener">
  <provider name="kafka" enabled="true">
    <properties>
      <property name="topicEvents" value="keycloak-events"/>
      <property name="topicAdminEvents" value="keycloak-admin-events"/>
      <property name="bootstrapServers" value="localhost:9092"/>
    </properties>
  </provider>
</spi>
```

**イベントフォーマット（JSON）:**
```json
{
  "type": "LOGIN",
  "realmId": "myrealm",
  "clientId": "my-client",
  "userId": "user-id-123",
  "ipAddress": "192.168.1.10",
  "time": 1678901234567,
  "details": {
    "username": "john.doe",
    "auth_method": "openid-connect"
  }
}
```

### SysLog統合

標準的なSysLogプロトコルでログを送信。

**カスタムEventListener実装:**
```java
public class SyslogEventListener implements EventListenerProvider {
    @Override
    public void onEvent(Event event) {
        String syslogMessage = formatSyslog(event);
        sendToSyslog(syslogMessage);
    }

    private String formatSyslog(Event event) {
        return String.format("<%d>1 %s %s keycloak - - - %s",
            facility * 8 + severity,
            Instant.now(),
            hostname,
            event.toString()
        );
    }
}
```

### Splunk/Elasticsearch統合

**Fluent Bit経由:**
1. KeycloakログをJSON形式で出力
2. Fluent BitでログをパースしてSplunk/Elasticsearchに転送

**設定例（fluent-bit.conf）:**
```ini
[INPUT]
    Name tail
    Path /opt/keycloak/log/keycloak.log
    Parser json

[OUTPUT]
    Name es
    Match *
    Host elasticsearch.local
    Port 9200
    Index keycloak-events
```

**活用シーン:**
- リアルタイム異常検知
- コンプライアンスレポート自動生成
- セキュリティダッシュボード構築
