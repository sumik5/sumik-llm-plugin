# マルチテナンシーとRealm設計

## Realm設計パターン

### Realm-Level リソース分離

Keycloak RealmはIDデータをカプセル化するセキュリティドメインとして機能する。適切な設計により、厳格な境界を強制し、テナント間の不正アクセスやデータ漏洩を防止できる。

| 分離レベル | 内容 |
|-----------|------|
| **管理分離** | Realm単位でスコープされた管理者権限。テナント横断管理を防止 |
| **データ分離** | ユーザー資格情報、OAuth2クライアント、ロールマッピングがRealm内で独立 |
| **設定独立** | 認証フロー、パスワードポリシー、User Federationをテナント要件に合わせてカスタマイズ |

**推奨パターン**: 各テナントに専用Realmを割り当てる。Shared Realmパターンはテナント固有ロール/グループを使用するが、複雑でセキュリティリスクが高い。

### ポリシー適用とFine-Grained制御

Keycloakのポリシーフレームワークは、Authorization Services、Client Scopes、Protocol MappersをRealm境界内で動作させる。

**Realm-Scoped Authorization Policies**:
- リソースベース権限をRealm内リソースに明示的に紐付け
- 決定はテナント境界内でのみ適用される
- Client-Level Policy Separation: クライアントのスコープとProtocol MapperをRealm内に閉じる
- 別Realmのクライアント参照はサポートされない（厳格なテナンシーを強制）

**Identity Brokering & Federation制約**:
- テナント固有Realmは異なるBrokerを使用可能
- 他テナントへの影響なし

### インフラ・コンポーネント分離

| デプロイパターン | 説明 |
|----------------|------|
| **Single Instance + Multiple Realms** | 複数RealmをサーバーDBスキーマで共有。リソース効率化だがDB/サーバー層の侵害が複数テナントに影響 |
| **Separate Databases per Realm** | 大規模デプロイ向け。Realm単位でDB・暗号化・バックアップ・アクセス制御を分離 |
| **Clustered Environments** | Realmがノード分散。ネットワーク分離・ノード間認証・通信プロトコル保護が必須 |

## マルチテナント管理戦略

### Realm per Tenant パターン

最も直接的で安全なアーキテクチャ。各テナントに専用Realmを割り当てる。

**メリット**:
- 完全なデータ分離（ユーザー・クライアント・ロール・セッション）
- テナント単位のカスタマイズ自由度（認証フロー・パスワードポリシー・テーマ）
- 障害の局所化（1つのRealmの問題が他に波及しない）

**トレードオフ**:
- 運用複雑性（更新・バックアップ・監視の管理オーバーヘッド）
- リソース消費増加（設定要素の重複）
- グローバル設定共有機会の損失

### Shared Realm パターン（非推奨）

1つのRealm内でテナント固有ロール/グループを使用。

**課題**:
- 認可チェックの複雑化
- 誤設定によるテナント横断アクセスリスク
- セキュリティ検証の困難さ

### テナントオンボーディング自動化

宣言的JSONまたはYAMLスキーマでテナント設定を定義し、オーケストレーションエンジンで実行する。

```python
import identity_mgmt_api as idm

tenant_config = {
    "tenant_id": "tenant42",
    "user_store": "ldap://tenant42.example.com",
    "password_policy": {
        "min_length": 12,
        "complexity": "high",
        "mfa_required": True
    },
    "role_mappings": {
        "admin": ["tenant42_admin_group"],
        "user": ["tenant42_user_group"]
    }
}

def provision_tenant(config):
    idm.create_tenant(config["tenant_id"])
    idm.configure_user_store(config["tenant_id"], config["user_store"])
    idm.set_password_policy(config["tenant_id"], config["password_policy"])
    idm.assign_roles(config["tenant_id"], config["role_mappings"])
    print(f"Tenant {config['tenant_id']} provisioned successfully.")

provision_tenant(tenant_config)
```

**継続デプロイパイプライン統合**:
- 反復可能・監査可能なテナントセットアップ
- 標準化されたプロトコル（Syslog、HTTP Event Collector）でテレメトリ収集
- ダッシュボードでアクションに変換

### グローバル設定の適用

階層的ポリシーストアでベースポリシーをグローバルレベルで定義し、テナント管理者が拡張・上書き可能。

**ポリシー評価エンジン**:
- ルール結合アルゴリズム（permit-overrides、deny-overridesなど）
- 中央ガバナンス目標とテナント固有運用柔軟性のバランス

**共通グローバル設定**:
- パスワード複雑性要件
- セッションタイムアウトポリシー
- MFA強制レベル
- 監査パラメータ

### リソース割り当てと動的スケーリング

| 戦略 | 内容 |
|------|------|
| **仮想化・コンテナオーケストレーション** | Realm/テナント単位で専用インスタンス・コンテナをプロビジョニング |
| **動的スケーリングポリシー** | 認証リクエストレート・ディレクトリ検索レイテンシに基づきワークロード適応 |
| **クォータ・リミット** | テナント単位でリソース使用制限。乱用防止と公平な共有を促進 |

### 監視とオブザーバビリティ

- 全テナント・Realmのログ・メトリクス・イベントを集約
- 分散トレーシング（Federated Identityフロー全体の可視性）
- Realm単位のダッシュボード（認証成功率・トークン発行時間など）
- **RBAC**: 監視ツール内でテナント管理者は自Realmデータのみアクセス
- コンプライアンスレポートテンプレートをパラメータ化（規制差異対応）

## 委任管理（Delegated Administration）

### テナント管理者の権限分離

**Role-Based Delegation Patterns**:
- 全権限管理者ロールではなく、ドメイン固有スコープ権限を割り当て
- 最小権限原則を強制

**レイヤードモデル**:
| ロール | 権限 |
|--------|------|
| **Global Administrators** | システム全体権限（テナント作成・グローバル設定） |
| **Domain-Specific Administrators** | 特定テナント/ドメインに限定された管理権限（TenantAdmin） |
| **Regular Users** | 管理権限なし。ユーザーロール内でのみ動作 |

### 境界設計（Boundary Design）

**Logical Boundaries**:
- ドメイン識別子に紐付いたロール割り当て
- アクセストークンにスコープクレーム含む → リクエストごとに強制

**Physical Boundaries**:
- テナント単位でDB/名前空間を分離
- データ暗号化（不正読み取り防止）
- 必要に応じて別サービスインスタンスをデプロイ

### Just-in-Time Delegation・Time-Limited特権

- 一時的に特権を付与し、再検証を要求
- 資格情報侵害時の攻撃ウィンドウを縮小

### ベストプラクティス

- **Granular Role Definitions**: ドメインタスクに必要な権限のみを含むロール定義
- **Audit Trail & Monitoring**: 管理アクション詳細ログ（ロール割り当て・特権変更）
- **Separation of Duties**: 重大な管理操作を複数ロール/個人に分散
- **Policy Enforcement Automation**: 自動化ポリシーエンジンで権限ルール統一強制
- **Periodic Reviews**: ロールメンバーシップ・委任特権の定期レビュー

**実例**:
- マルチテナントクラウドサービスでドメイン管理者が自ユーザー管理・アプリ設定カスタマイズ可能
- ネットワーク設定変更や他テナントデータアクセスは不可
- Authorization Serviceがドメインスコープロール検証・境界強化（テナント固有暗号化鍵・分離リソースプール）

## User Federation・外部ディレクトリ統合

### LDAP/AD統合の高度なパターン

Keycloakは外部ディレクトリ（LDAP/AD）と連携し、既存ユーザーリポジトリを統合する。

**Synchronization Strategies**:
| 戦略 | 説明 |
|------|------|
| **On-demand同期** | 認証リクエストごとにLDAPからユーザー情報取得。ローカルストレージ不要だがレイテンシ増加 |
| **Periodic同期** | スケジュール設定でユーザー/グループデータ定期インポート。LDAP負荷軽減だが陳腐化データリスク |
| **Import with cache** | 初回ログイン時にインポート・キャッシュ。パフォーマンスとデータ新鮮度のバランス |

**Attribute Mappings**:
- LDAP属性を内部ユーザーモデル属性にマッピング（username、email、first name、last nameなど）
- カスタムLDAP属性をユーザー属性やロールにマッピング（ドメイン固有ポリシー強制・グループベースアクセス制御）

### User Lifecycle管理

| フェーズ | 戦略 |
|---------|------|
| **User creation** | 外部ディレクトリで一元管理。Write modeでKeycloakから新規ユーザーをLDAPに伝播可能 |
| **User updates** | 属性同期ポリシー（full import、merge、ignore）でKeycloak/外部間の変更伝播制御 |
| **User deletion** | 通常Keycloakは外部ディレクトリのユーザーを削除せず、キャッシュローカルコピーを無効化/削除。自動クリーンアップで孤立アカウント防止 |

**パスワード管理**:
- 外部システムへの認証委任（パスワードポリシー・複雑性ルールが外部で強制）
- パスワード更新許可時、Keycloakがプロキシとして下流へ安全に中継

### 統合の課題と対策

| 課題 | 対策 |
|------|------|
| **スキーマミスマッチ** | 柔軟な属性マッピングフレームワークで正規化。LDAPフィルター微調整で同期対象ユーザー限定 |
| **グループ・ロールマッピング** | LDAPグループをKeycloakロールにマッピング。グループメンバーシップをロールグラントとしてインポート |
| **パフォーマンス考慮** | キャッシュ・インポート戦略でデータ新鮮度とバランス。負荷テスト・LDAP応答監視で同期間隔・キャッシュ有効期限調整 |
| **セキュア通信** | LDAP接続にTLS設定。Bind資格情報やサービスアカウント慎重管理。Keycloakは機密データを暗号化・外部シークレットストアと統合 |

### カスタムUser Storage Provider

標準プロトコルで対応できない場合、カスタムFederation ProviderやSPI拡張を開発し、独自の同期・変換ロジックを実装できる。

## Identity Brokering

Keycloakは外部Identity Provider（IdP）に認証を委任し、複数認証ソース（Social IdP、企業SAML/OIDCプロバイダー）を統合する。

### Identity Brokering設定

**OIDCアイデンティティプロバイダー設定例**:
```xml
<identity-provider>
  <alias>google</alias>
  <provider-id>oidc</provider-id>
  <config>
    <clientId>your-google-client-id</clientId>
    <clientSecret>your-google-client-secret</clientSecret>
    <authorizationUrl>https://accounts.google.com/o/oauth2/auth</authorizationUrl>
    <tokenUrl>https://oauth2.googleapis.com/token</tokenUrl>
    <userInfoUrl>https://openidconnect.googleapis.com/v1/userinfo</userInfoUrl>
    <logoutUrl>https://accounts.google.com/o/oauth2/revoke</logoutUrl>
    <issuer>https://accounts.google.com</issuer>
    <defaultScope>openid email profile</defaultScope>
  </config>
</identity-provider>
```

### Trust関係の確立

**暗号化メカニズム**:
- **SAML**: 外部IdPメタデータ（署名証明書）をKeycloakにインポートし、受信Assertionの整合性・真正性を検証
- **OIDC**: クライアントシークレット・署名済みIDトークン検証（プロバイダーの公開鍵でJWKS経由）
- 厳格な検証ポリシー（audience/nonce checking）でリプレイ攻撃・トークン悪用を防止

### Attribute & Claim Mapping

外部IdPアサーションから内部ユーザーモデルへの属性マッピング。

```xml
<mapper>
  <name>email-mapper</name>
  <identity-provider-mapper>oidc-user-attribute-id-token</identity-provider-mapper>
  <config>
    <claim>email</claim>
    <user.attribute>email</user.attribute>
  </config>
</mapper>
```

**カスタムMapper**:
- グループメンバーシップ、ロケール、MFA要件など複雑なユース属性統合

### First Login Flow

初回ログイン時、外部IdPからのユーザーをKeycloak内部ユーザーエントリとして作成・更新。

**デフォルトフロー**:
1. ユーザーがクライアントアプリにアクセス
2. Keycloakが外部IdP認証エンドポイントにリダイレクト
3. 外部IdPでログイン成功後、認証レスポンス（SAMLアサーションやOIDC IDトークン）をKeycloakに返送
4. Keycloak がアサーション/トークン検証・ユーザー属性抽出・ローカルストアと照合
5. 新規ユーザーの場合、First-Login Flow発火（登録プロファイル・同意画面など）
6. 処理後、Keycloak がクライアントアプリにトークン発行・ローカルSSOセッション確立

**カスタマイズ可能**:
- 追加認証ステップ（利用規約同意・リスクベース認証）を注入
- カスタムAuthenticatorで外部ログイン後のポリシー強制

### Cross-Domain SSOとセッション管理

Keycloakが中央セッション管理・トークン発行・失効を行い、外部IdPとの信頼関係に依存。

- SSO トークンはOIDC/SAML Assertionでユーザー識別・認可情報を安全に伝播
- Backchannel/Frontchannel Logoutメカニズムでログアウトイベント全RPとIdPに伝播

## Cross-Realm Trust

### Trust Relationships確立

| モデル | 説明 |
|--------|------|
| **Direct Trust** | 2つのRealm間でデジタル証明書・鍵交換により直接トラストリンク確立 |
| **Federated Trust** | 複数Realmが共通フェデレーション権限・アイデンティティブローカーを信頼。動的にRealm追加/削除可能 |

### Cross-Realm認証フロー

**標準トークンフォーマット・フェデレーテッドプロトコル（SAML/OAuth 2.0/OIDC）を使用**:

1. クライアントがホームRealmのIdPで認証し、署名付きセキュリティトークン（SAMLアサーション/JWT）を取得
2. クライアントがターゲットRealmのリライイングパーティ/ゲートウェイにアサーション提示
3. ターゲットRealmが確立されたTrust関係から派生したTrust Anchorでトークン署名検証
4. 検証成功後、ターゲットRealmがローカルトークン/セッション発行（クライアントID・権限をRealmポリシーにスコープ）

**Token Translation/Brokerage**:
- IDアサーションをターゲットRealmセキュリティコンテキストに変換
- OAuth 2.0 Token Exchange拡張で委任可能（rawクレデンシャル露出なし）

### Secure Inter-Realm Service Consumption

| 戦略 | 説明 |
|------|------|
| **ABAC** | ターゲットRealmがソースRealmトークン内属性に基づき認可決定 |
| **Mutual TLS (mTLS)** | クライアント/サーバー証明書検証で通信チャネル保護 |
| **Service Account Delegation** | スコープ委任トークン（OAuth 2.0 Refresh Token、On-Behalf-Of Token）で短命・最小特権アクセス継続 |

### スケーラビリティ考慮

**Trust Topology**:
| モデル | 説明 |
|--------|------|
| **Hierarchical Trust Models** | ルートフェデレーション権限が下位Realmを認証。推移的トラストパス確立。鍵配布簡素化だが中央集権依存 |
| **Mesh Trust Models** | Realmがピアツーピアで直接トラスト関係形成。柔軟・動的だが管理オーバーヘッド増加 |

**動的発見メカニズム**:
- OAuth 2.0 Authorization Server Metadata / OIDC Discoveryでランタイム設定
- 自動化鍵ローテーション・トラスト失効リスト・リアルタイムポリシー同期が大規模デプロイに不可欠

### 新興パターン・技術

**Decentralized Identity**:
- ブロックチェーン/分散台帳でDID/VCによる信頼基盤確立
- 中央集権不要の暗号証明

**Security Token Service (STS) Pattern**:
- プログラム的トークン発行・変換。Cross-Realm認証複雑性抽象化

**Zero Trust Architectures**:
- Realm境界に関係なく継続検証・ポリシー強制
