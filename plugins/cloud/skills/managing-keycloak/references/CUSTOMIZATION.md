# Keycloak カスタマイズ・拡張

## SPI拡張ポイント選択ガイド

| 拡張用途 | SPI名 | 実装難易度 | 推奨ケース |
|---------|------|----------|----------|
| **カスタム認証** | Authenticator SPI | 中 | 外部API認証、独自MFA、カスタム検証ロジック |
| **ユーザーストレージ** | UserStorageProvider SPI | 高 | 外部DB連携、レガシーシステム統合 |
| **パスワードハッシュ** | PasswordHashProvider SPI | 中 | 独自ハッシュアルゴリズム、レガシーDB移行 |
| **トークンマッパー** | ProtocolMapper SPI | 低 | カスタムクレーム追加、コンテキスト依存トークン |
| **イベントリスナー** | EventListener SPI | 低 | 外部ログ送信、Webhook連携、監査 |
| **テーマカスタマイズ** | Theme SPI | 低 | ブランディング、UI変更 |

### 選択判断基準

1. **Authenticator SPI**: 外部システム認証、カスタム認証フロー
2. **UserStorageProvider SPI**: 外部ユーザーDB統合（LDAP以外）
3. **PasswordHashProvider SPI**: レガシーシステムのハッシュアルゴリズム移行
4. **ProtocolMapper SPI**: トークンへの動的クレーム追加
5. **Theme SPI**: ログイン画面・メールテンプレートのカスタマイズ

---

## SPI（Service Provider Interface）

### 概要

Keycloakコア機能を拡張するためのインターフェース群。

### 主要SPI一覧

| SPI | インターフェース | 用途 |
|-----|---------------|------|
| **Authenticator** | `Authenticator` | カスタム認証プロバイダ |
| **UserStorageProvider** | `UserStorageProvider` | 外部ユーザーストレージ |
| **PasswordHashProvider** | `PasswordHashProvider` | カスタムパスワードハッシュ |
| **ProtocolMapper** | `ProtocolMapper` | トークンマッパー |
| **EventListener** | `EventListenerProvider` | イベントリスナー |
| **RequiredAction** | `RequiredActionProvider` | 必須アクション（パスワード変更等） |
| **Theme** | `ThemeProvider` | テーマプロバイダ |

### SPI開発フロー

1. **インターフェース実装**: 該当SPIを継承
2. **Factory実装**: Providerインスタンス生成
3. **SPI登録**: `META-INF/services/`に登録ファイル作成
4. **JARパッケージング**: `mvn clean package`
5. **デプロイ**: `providers/`ディレクトリに配置
6. **Keycloak再起動**

---

## Custom Authentication Provider

### 概要

外部REST APIを使用した認証プロバイダ実装例。

### 実装例

#### CustomAuthenticator.java

```java
package com.example.keycloak;

import org.keycloak.authentication.AuthenticationFlowContext;
import org.keycloak.authentication.AuthenticationFlowError;
import org.keycloak.authentication.Authenticator;
import org.keycloak.authentication.authenticators.browser.AbstractUsernameFormAuthenticator;
import org.keycloak.models.UserModel;
import org.keycloak.services.messages.Messages;

public class CustomAuthenticator extends AbstractUsernameFormAuthenticator {
    @Override
    public void authenticate(AuthenticationFlowContext context) {
        String username = context.getHttpRequest().getDecodedFormParameters().getFirst("username");
        String password = context.getHttpRequest().getDecodedFormParameters().getFirst("password");

        UserModel user = context.getSession().users().getUserByUsername(username, context.getRealm());

        if (user != null && validatePassword(user, password)) {
            context.setUser(user);
            context.success();
        } else {
            context.failureChallenge(AuthenticationFlowError.INVALID_CREDENTIALS,
                context.form().setError(Messages.INVALID_USER).createLogin());
        }
    }

    private boolean validatePassword(UserModel user, String password) {
        // カスタム検証ロジック
        return true; // Placeholder
    }

    @Override
    public void action(AuthenticationFlowContext context) {
        // フォーム送信・マルチステップ認証処理
    }

    @Override
    public boolean requiresUser() {
        return false;
    }

    @Override
    public boolean configuredFor(KeycloakSession session, RealmModel realm, UserModel user) {
        return true;
    }

    @Override
    public void setRequiredActions(KeycloakSession session, RealmModel realm, UserModel user) {
        // 必須アクション設定
    }

    @Override
    public void close() {
        // リソースクリーンアップ
    }
}
```

#### CustomAuthenticatorFactory.java

```java
package com.example.keycloak;

import org.keycloak.authentication.Authenticator;
import org.keycloak.authentication.AuthenticatorFactory;
import org.keycloak.models.KeycloakSession;
import org.keycloak.provider.ProviderConfigProperty;
import java.util.List;

public class CustomAuthenticatorFactory implements AuthenticatorFactory {
    @Override
    public Authenticator create(KeycloakSession session) {
        return new CustomAuthenticator();
    }

    @Override
    public String getId() {
        return "custom-authenticator";
    }

    @Override
    public String getHelpText() {
        return "A custom authenticator example";
    }

    @Override
    public List<ProviderConfigProperty> getConfigProperties() {
        return List.of();
    }

    @Override
    public boolean isUserSetupAllowed() {
        return true;
    }
}
```

#### SPI登録

```
# META-INF/services/org.keycloak.authentication.AuthenticatorFactory
com.example.keycloak.CustomAuthenticatorFactory
```

### デプロイ

```bash
# JARビルド
mvn clean package

# Keycloak providersディレクトリにコピー
cp target/custom-authenticator.jar /opt/keycloak/providers/

# Keycloak再起動
systemctl restart keycloak
```

---

## Custom User Storage Provider

### 概要

外部ユーザーDBと連携するカスタムストレージプロバイダ。

### 実装例

```java
import org.keycloak.models.*;
import org.keycloak.storage.user.UserStorageProvider;
import org.keycloak.storage.user.UserStorageProviderFactory;

public class CustomUserStorageProvider implements UserStorageProvider {
    private final KeycloakSession session;

    public CustomUserStorageProvider(KeycloakSession session) {
        this.session = session;
    }

    @Override
    public void close() {
        // リソースクリーンアップ
    }

    public UserModel getUserById(String id, RealmModel realm) {
        // 外部DBからユーザー取得ロジック
        return null; // Placeholder
    }

    public UserModel getUserByUsername(String username, RealmModel realm) {
        // ユーザー名でユーザー取得
        return null; // Placeholder
    }

    public UserModel getUserByEmail(String email, RealmModel realm) {
        // メールアドレスでユーザー取得
        return null; // Placeholder
    }

    // その他必須メソッド実装...
}

public class CustomUserStorageProviderFactory implements UserStorageProviderFactory<CustomUserStorageProvider> {
    @Override
    public CustomUserStorageProvider create(KeycloakSession session) {
        return new CustomUserStorageProvider(session);
    }

    @Override
    public String getId() {
        return "custom-user-storage";
    }

    // その他Factory メソッド...
}
```

### ユースケース

- レガシーユーザーDBとの統合
- 外部API経由のユーザー管理
- カスタム属性の動的取得

---

## Custom Password Hashing

### 概要

独自ハッシュアルゴリズム実装（レガシーDB移行等）。

### 実装例

```java
import org.keycloak.credential.hash.PasswordHashProvider;
import org.keycloak.credential.hash.PasswordHashProviderFactory;

public class CustomPasswordHashProvider implements PasswordHashProvider {
    @Override
    public String hash(String password) {
        // カスタムハッシュロジック（例: SHA-256 + カスタムSalt）
        return "hashed_" + password; // Placeholder
    }

    @Override
    public boolean verify(String password, String hashedPassword) {
        // 検証ロジック
        return hashedPassword.equals(hash(password));
    }

    @Override
    public void close() {
        // リソースクリーンアップ
    }
}

public class CustomPasswordHashProviderFactory implements PasswordHashProviderFactory<CustomPasswordHashProvider> {
    @Override
    public CustomPasswordHashProvider create() {
        return new CustomPasswordHashProvider();
    }

    @Override
    public String getId() {
        return "custom-password-hash";
    }

    // その他Factory メソッド...
}
```

### セキュリティベストプラクティス

- **Salt使用必須**: ユーザーごとにランダムSalt
- **計算コスト**: bcrypt/Argon2等の計算コスト高いアルゴリズム推奨
- **ハッシュ長**: 最低256bit以上

---

## テーマカスタマイズ

### テーマ構造

```
themes/
└── my-custom-theme/
    ├── login/           # ログイン画面
    │   ├── login.ftl
    │   ├── resources/
    │   │   ├── css/
    │   │   │   └── styles.css
    │   │   └── img/
    │   │       └── logo.png
    │   └── messages/
    │       ├── messages_en.properties
    │       └── messages_ja.properties
    ├── account/         # アカウント管理画面
    │   └── account.ftl
    ├── email/           # メールテンプレート
    │   ├── login.ftl
    │   └── password-reset.ftl
    └── admin/           # Admin Console（高度）
        └── index.ftl
```

### Login テーマ作成

#### 1. ディレクトリ作成

```bash
mkdir -p themes/my-custom-theme/login
```

#### 2. login.ftl作成

```html
<!-- themes/my-custom-theme/login/login.ftl -->
<!DOCTYPE html>
<html>
<head>
    <title>Custom Login</title>
    <link rel="stylesheet" href="${url.resourcesPath}/css/styles.css">
</head>
<body>
    <div class="login-container">
        <img src="${url.resourcesPath}/img/logo.png" alt="Logo">
        <h1>Welcome to My Custom Login Page</h1>
        <form action="${url.loginAction}" method="post">
            <label for="username">Username:</label>
            <input type="text" name="username" id="username">
            <br>
            <label for="password">Password:</label>
            <input type="password" name="password" id="password">
            <br>
            <input type="submit" value="Login">
        </form>
    </div>
</body>
</html>
```

#### 3. CSS追加

```css
/* themes/my-custom-theme/login/resources/css/styles.css */
.login-container {
    max-width: 400px;
    margin: 100px auto;
    text-align: center;
}

.login-container img {
    width: 100px;
    margin-bottom: 20px;
}

.login-container input[type="text"],
.login-container input[type="password"] {
    width: 100%;
    padding: 10px;
    margin: 5px 0;
}
```

#### 4. Admin Consoleで有効化

1. `Realm Settings > Themes`
2. `Login Theme`: `my-custom-theme`選択
3. Save

### FreeMarker変数

| 変数 | 説明 |
|-----|------|
| `${url.loginAction}` | ログインフォーム送信先URL |
| `${url.resourcesPath}` | リソースパス（CSS/画像等） |
| `${user.firstName}` | ユーザー名（First Name） |
| `${realmName}` | Realm名 |
| `${locale}` | 現在のロケール |

---

## Email Templates

### カスタマイズ手順

#### 1. テーマディレクトリ作成

```bash
mkdir -p /opt/keycloak/themes/my-custom-theme/email
```

#### 2. 既存テンプレートコピー

```bash
cp /opt/keycloak/themes/base/email/*.ftl /opt/keycloak/themes/my-custom-theme/email/
```

#### 3. テンプレート編集

```html
<!-- /opt/keycloak/themes/my-custom-theme/email/login.ftl -->
<#assign subject="Login Notification">
Hello ${user.firstName},

You have successfully logged into ${realmName}.

Thank you,
${realmName} Team
```

#### 4. Admin Consoleで有効化

1. `Realm Settings > Themes`
2. `Email Theme`: `my-custom-theme`選択
3. Save

### 多言語化

```properties
# messages/messages_en.properties
loginNotification=Login Notification
loginMessage=You have successfully logged in.

# messages/messages_ja.properties
loginNotification=ログイン通知
loginMessage=正常にログインしました。
```

### テンプレート内で使用

```html
<#assign subject=msg("loginNotification")>
${msg("loginMessage")}
```

---

## Localization（多言語対応）

### JSON設定例

```json
{
  "locale": "ja",
  "messages": {
    "welcome": "ようこそ",
    "login": "ログイン",
    "logout": "ログアウト"
  }
}
```

### サポート言語追加

#### 1. messages_XX.propertiesファイル作成

```properties
# themes/my-custom-theme/login/messages/messages_fr.properties
welcome=Bienvenue
login=Connexion
logout=Déconnexion
```

#### 2. Realm設定で言語有効化

1. `Realm Settings > Localization`
2. `Supported Locales`: `en`, `ja`, `fr`追加
3. `Default Locale`: `en`

### ユーザー言語選択

ログイン画面に言語選択ドロップダウン自動表示（`Internationalization`有効時）。

---

## User Impersonation

### 概要

管理者が他ユーザーのアカウントに一時的にログイン。トラブルシューティング・サポート用。

### 実行手順（Admin Console）

1. Keycloak Admin Consoleにログイン
2. `Users`セクションに移動
3. 偽装対象ユーザーを検索
4. ユーザー詳細ページで`Impersonate`ボタンクリック
5. 偽装セッション開始（バナー表示）

### セキュリティ考慮事項

- 偽装セッションはログに記録
- 監査要件への対応
- 偽装権限を最小限のAdmin Roleに制限

---

## Read-Only Attributes

### 概要

外部フェデレーション（LDAP/AD）からの属性を読み取り専用に設定。

### 設定手順

1. Admin Console > `User Federation`
2. 外部プロバイダ（例: LDAP）選択
3. `Mappers`タブ
4. 新規Mapper作成
5. `Mapper Type`: `User Attribute`
6. `Read-Only`: 有効化

### ユースケース

- LDAPの`email`属性をKeycloakで変更不可に
- 外部システムを唯一のデータソースとして維持

---

## Federation Links管理

### 概要

外部IdPとのフェデレーションリンク管理・削除。

### Admin Console操作

1. `Users`セクション
2. ユーザー選択
3. `Federated Identity`タブ
4. 外部IdPリンク確認・削除

### CLI操作

```bash
# Federation Link削除
kcadm.sh delete users/{user-id}/federated-identity/{identity-provider-alias} -r {realm}
```

---

## Backchannel Authentication (CIBA)

### 概要

Client Initiated Backchannel Authentication。デバイス外認証フロー（例: スマホで認証、PCでログイン）。

### 有効化手順

1. `Realm Settings > Advanced`
2. `CIBA Supported`: ON
3. Client設定で`CIBA Grant Enabled`: ON

### フロー概要

1. クライアントがBackchannel Authentication Requestを送信
2. Keycloakがユーザーにプッシュ通知
3. ユーザーがスマホで承認
4. クライアントがトークン取得

### ユースケース

- IoTデバイス認証
- TV・ゲーム機等の入力困難デバイス
- セキュアなデバイス外認証

---

## SPIデプロイメント戦略

### 開発環境

```bash
# ローカルビルド
mvn clean package

# providersディレクトリにコピー
cp target/my-spi.jar /opt/keycloak/providers/

# Keycloak再起動
./bin/kc.sh start-dev
```

### 本番環境（Docker）

```dockerfile
FROM jboss/keycloak:latest

COPY my-spi.jar /opt/jboss/keycloak/providers/

CMD ["-b", "0.0.0.0"]
```

### Kubernetes

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: keycloak-providers
data:
  my-spi.jar: |
    <base64-encoded-jar>
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: keycloak
spec:
  template:
    spec:
      containers:
      - name: keycloak
        image: jboss/keycloak:latest
        volumeMounts:
        - name: providers
          mountPath: /opt/jboss/keycloak/providers
      volumes:
      - name: providers
        configMap:
          name: keycloak-providers
```

---

## SPIアーキテクチャ詳細

### SPI（Service Provider Interface）概念

Keycloak SPIは、プラグイン方式でコア機能を拡張可能にするアーキテクチャパターン。各SPIは以下3要素で構成:

1. **Provider Interface**: 実装すべき機能を定義するJavaインターフェース
2. **ProviderFactory**: Providerインスタンスを生成・初期化するファクトリークラス
3. **SPI登録**: `META-INF/services/`ディレクトリ内のファイルでProviderFactoryを登録

### SPIライフサイクル

```
Keycloak起動
  ↓
SPIローダーがMETA-INF/services/を読み込み
  ↓
ProviderFactory.init()実行（サーバー起動時1回）
  ↓
リクエストごとにFactory.create()でProviderインスタンス生成
  ↓
Providerメソッド実行（認証・ユーザー取得等）
  ↓
Provider.close()でリソースクリーンアップ
  ↓
Keycloak終了時にFactory.close()
```

### デプロイメントモデル

#### 1. JARデプロイ（開発・カスタムSPI）

```bash
# JARビルド
mvn clean package

# Keycloak providersディレクトリにコピー
cp target/my-custom-spi.jar /opt/keycloak/providers/

# Keycloak再起動
/opt/keycloak/bin/kc.sh start
```

#### 2. モジュールデプロイ（レガシー・複雑な依存関係）

```xml
<!-- module.xml例 -->
<module xmlns="urn:jboss:module:1.9" name="com.example.keycloak.custom">
    <resources>
        <resource-root path="my-custom-spi.jar"/>
    </resources>
    <dependencies>
        <module name="org.keycloak.keycloak-services"/>
        <module name="javax.api"/>
    </dependencies>
</module>
```

#### 3. Dockerマルチステージビルド

```dockerfile
FROM maven:3.8-openjdk-17 AS builder
WORKDIR /build
COPY pom.xml .
COPY src ./src
RUN mvn clean package

FROM quay.io/keycloak/keycloak:latest
COPY --from=builder /build/target/my-custom-spi.jar /opt/keycloak/providers/
RUN /opt/keycloak/bin/kc.sh build
```

---

## カスタムプロトコル拡張

### Token Mapper SPI

**用途:** カスタムクレームをトークンに動的追加（コンテキスト・ユーザー属性に基づく）

#### 実装例: 組織情報Mapper

```java
package com.example.keycloak.mapper;

import org.keycloak.models.*;
import org.keycloak.protocol.oidc.mappers.*;
import org.keycloak.provider.ProviderConfigProperty;
import org.keycloak.representations.IDToken;

import java.util.ArrayList;
import java.util.List;

public class OrganizationMapper extends AbstractOIDCProtocolMapper implements OIDCAccessTokenMapper {

    private static final String PROVIDER_ID = "organization-mapper";

    @Override
    public String getDisplayType() {
        return "Organization Mapper";
    }

    @Override
    public String getHelpText() {
        return "Adds organization information to the token";
    }

    @Override
    public List<ProviderConfigProperty> getConfigProperties() {
        return new ArrayList<>();
    }

    @Override
    public String getId() {
        return PROVIDER_ID;
    }

    @Override
    protected void setClaim(IDToken token, ProtocolMapperModel mappingModel,
                           UserSessionModel userSession, KeycloakSession keycloakSession,
                           ClientSessionContext clientSessionCtx) {
        UserModel user = userSession.getUser();

        // ユーザー属性から組織情報取得
        String orgId = user.getFirstAttribute("organizationId");
        String orgName = user.getFirstAttribute("organizationName");

        // トークンにカスタムクレーム追加
        token.getOtherClaims().put("org_id", orgId);
        token.getOtherClaims().put("org_name", orgName);
    }
}
```

#### Factory実装

```java
public class OrganizationMapperFactory extends AbstractOIDCProtocolMapperFactory {

    @Override
    public ProtocolMapper create(KeycloakSession session) {
        return new OrganizationMapper();
    }

    @Override
    public String getId() {
        return "organization-mapper";
    }
}
```

#### SPI登録

```
# META-INF/services/org.keycloak.protocol.ProtocolMapperFactory
com.example.keycloak.mapper.OrganizationMapperFactory
```

### Authenticator SPI（高度な認証フロー）

**用途:** カスタム認証ステップ（外部API検証・ワンタイムパスワード・リスクベース認証）

#### 実装例: 外部APIベース認証

```java
public class ExternalApiAuthenticator implements Authenticator {

    @Override
    public void authenticate(AuthenticationFlowContext context) {
        String username = context.getUser().getUsername();

        // 外部API呼び出し
        boolean isAuthorized = callExternalAuthorizationApi(username);

        if (isAuthorized) {
            context.success();
        } else {
            context.failure(AuthenticationFlowError.INVALID_USER);
        }
    }

    private boolean callExternalAuthorizationApi(String username) {
        // HTTP client経由で外部APIを呼び出し
        try {
            HttpClient client = HttpClient.newHttpClient();
            HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create("https://api.example.com/authorize/" + username))
                .GET()
                .build();
            HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());
            return response.statusCode() == 200;
        } catch (Exception e) {
            return false;
        }
    }

    @Override
    public void action(AuthenticationFlowContext context) {
        // POST処理（フォーム送信時）
    }

    @Override
    public boolean requiresUser() {
        return true;
    }

    @Override
    public boolean configuredFor(KeycloakSession session, RealmModel realm, UserModel user) {
        return true;
    }

    @Override
    public void setRequiredActions(KeycloakSession session, RealmModel realm, UserModel user) {
        // 必須アクション設定（パスワード変更等）
    }

    @Override
    public void close() {
        // リソースクリーンアップ
    }
}
```

### Event Listener SPI（監査・外部連携）

**用途:** Keycloakイベント（ログイン・ログアウト・登録）を外部システムに通知

#### 実装例: Webhookイベントリスナー

```java
public class WebhookEventListener implements EventListenerProvider {

    private static final String WEBHOOK_URL = System.getenv("KEYCLOAK_WEBHOOK_URL");

    @Override
    public void onEvent(Event event) {
        // ユーザーイベント処理（LOGIN、REGISTER等）
        sendWebhook(event.getType().name(), event.getUserId(), event.getDetails());
    }

    @Override
    public void onEvent(AdminEvent adminEvent, boolean includeRepresentation) {
        // 管理イベント処理（USER_CREATE、CLIENT_UPDATE等）
        sendWebhook("ADMIN_" + adminEvent.getOperationType().name(),
                   adminEvent.getAuthDetails().getUserId(),
                   adminEvent.getResourcePath());
    }

    private void sendWebhook(String eventType, String userId, Map<String, String> details) {
        try {
            HttpClient client = HttpClient.newHttpClient();
            String json = String.format(
                "{\"event\":\"%s\",\"userId\":\"%s\",\"details\":%s}",
                eventType, userId, new ObjectMapper().writeValueAsString(details)
            );

            HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(WEBHOOK_URL))
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(json))
                .build();

            client.sendAsync(request, HttpResponse.BodyHandlers.ofString());
        } catch (Exception e) {
            // エラーログ記録
        }
    }

    @Override
    public void close() {
        // リソースクリーンアップ
    }
}
```

#### Factory実装

```java
public class WebhookEventListenerProviderFactory implements EventListenerProviderFactory {

    @Override
    public EventListenerProvider create(KeycloakSession session) {
        return new WebhookEventListener();
    }

    @Override
    public String getId() {
        return "webhook-event-listener";
    }

    @Override
    public void init(Config.Scope config) {
        // 初期化処理
    }

    @Override
    public void postInit(KeycloakSessionFactory factory) {
        // ポスト初期化処理
    }

    @Override
    public void close() {
        // ファクトリクリーンアップ
    }
}
```

#### Realm設定で有効化

```bash
# Admin Consoleで有効化
# Realm Settings > Events > Event Listeners > webhook-event-listener
```

---

## カスタマイズベストプラクティス

### パフォーマンス考慮事項

1. **非同期処理:** 外部API呼び出しは非同期実行（認証フローブロック回避）
2. **キャッシング:** 頻繁にアクセスするデータ（ユーザー属性・外部APIレスポンス）をキャッシュ
3. **タイムアウト設定:** 外部依存サービスに適切なタイムアウト設定

### セキュリティ考慮事項

1. **入力検証:** ユーザー入力・外部データを厳格に検証
2. **機密情報保護:** APIキー・パスワードは環境変数または暗号化Vault管理
3. **エラーハンドリング:** 詳細なエラー情報を外部に漏らさない（ログは内部記録のみ）

### テスト戦略

#### 単体テスト例（Mockito）

```java
@Test
public void testOrganizationMapperAddsClaimsCorrectly() {
    // Mocks
    KeycloakSession session = mock(KeycloakSession.class);
    UserSessionModel userSession = mock(UserSessionModel.class);
    UserModel user = mock(UserModel.class);

    when(userSession.getUser()).thenReturn(user);
    when(user.getFirstAttribute("organizationId")).thenReturn("org-123");
    when(user.getFirstAttribute("organizationName")).thenReturn("Example Corp");

    // Test
    OrganizationMapper mapper = new OrganizationMapper();
    IDToken token = new IDToken();
    mapper.setClaim(token, null, userSession, session, null);

    // Verify
    assertEquals("org-123", token.getOtherClaims().get("org_id"));
    assertEquals("Example Corp", token.getOtherClaims().get("org_name"));
}
```

---

## カスタマイズチェックリスト

### 実装前

- [ ] SPIインターフェース選定
- [ ] 要件定義（認証ロジック・外部API等）
- [ ] 既存実装の調査（類似SPI）
- [ ] パフォーマンス・セキュリティ影響分析

### 実装中

- [ ] インターフェース実装
- [ ] Factory実装
- [ ] SPI登録ファイル作成（META-INF/services/）
- [ ] 単体テスト実施（Mockitoベース）
- [ ] 外部依存のタイムアウト・エラーハンドリング実装

### デプロイ前

- [ ] JARビルド確認
- [ ] Admin Consoleでプロバイダ表示確認
- [ ] 統合テスト実施（実Keycloak環境）
- [ ] パフォーマンステスト（負荷テスト）
- [ ] セキュリティレビュー

### 本番デプロイ後

- [ ] ログ監視（エラー・パフォーマンス）
- [ ] エラーハンドリング確認
- [ ] ロールバック手順確認
- [ ] ドキュメント更新（運用手順・トラブルシューティング）
