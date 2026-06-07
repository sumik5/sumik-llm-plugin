# Keycloak デプロイ・運用

## デプロイ方式選択ガイド

| デプロイ方式 | 規模 | 可用性 | 管理複雑度 | 推奨ケース |
|-----------|-----|-------|----------|----------|
| **Docker単体** | 小規模（~100ユーザー） | 単一障害点 | 低 | 開発環境、PoC、個人プロジェクト |
| **K8s Operator** | 中規模（100~10,000ユーザー） | 中（Pod再起動） | 中 | クラウドネイティブアプリ、マイクロサービス |
| **HA Cluster** | 大規模（10,000+ユーザー） | 高（冗長化） | 高 | エンタープライズ、ミッションクリティカル |

### 選択判断基準

1. **Docker単体**: 開発環境、検証環境、トラフィック少量
2. **K8s Operator**: Kubernetesクラスタ既存、スケーラビリティ重視
3. **HA Cluster**: 24/7可用性必須、大規模トラフィック

---

## Docker デプロイ

### 概要

Keycloak公式Dockerイメージを使用した最速セットアップ。

### 基本実行

```bash
# Keycloak Docker イメージ取得
docker pull jboss/keycloak

# Keycloak コンテナ実行
docker run -d \
  --name keycloak \
  -p 8080:8080 \
  -e KEYCLOAK_USER=admin \
  -e KEYCLOAK_PASSWORD=admin \
  jboss/keycloak
```

### docker-compose例

```yaml
version: '3.8'

services:
  keycloak:
    image: jboss/keycloak:latest
    container_name: keycloak
    environment:
      KEYCLOAK_USER: admin
      KEYCLOAK_PASSWORD: admin
      DB_VENDOR: postgres
      DB_ADDR: postgres
      DB_DATABASE: keycloak
      DB_USER: keycloak
      DB_PASSWORD: password
    ports:
      - "8080:8080"
    depends_on:
      - postgres

  postgres:
    image: postgres:13
    container_name: postgres
    environment:
      POSTGRES_DB: keycloak
      POSTGRES_USER: keycloak
      POSTGRES_PASSWORD: password
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

### 環境変数

| 変数 | 説明 | デフォルト |
|-----|------|----------|
| `KEYCLOAK_USER` | 管理者ユーザー名 | （必須） |
| `KEYCLOAK_PASSWORD` | 管理者パスワード | （必須） |
| `DB_VENDOR` | DB種類（h2/postgres/mysql/mariadb/oracle） | h2 |
| `DB_ADDR` | DBホスト名 | localhost |
| `DB_DATABASE` | DB名 | keycloak |
| `DB_USER` | DBユーザー名 | keycloak |
| `DB_PASSWORD` | DBパスワード | （必須） |

### アクセス確認

```bash
# コンテナ状態確認
docker ps

# ログ確認
docker logs keycloak

# Admin Console
http://localhost:8080/auth
```

---

## Kubernetes Operator

### 概要

Keycloak Operatorを使用した自動化デプロイ・管理。

### Operatorインストール

```bash
# Keycloak Operator インストール（Helm）
helm repo add codecentric https://codecentric.github.io/helm-charts
helm install keycloak-operator codecentric/keycloak
```

### KeycloakRealmImport設定例

```yaml
# keycloak-deployment.yaml
apiVersion: keycloak.org/v1
kind: Keycloak
metadata:
  name: my-keycloak
spec:
  instances: 1
  externalAccess:
    enabled: true
    service:
      type: LoadBalancer
```

### デプロイ実行

```bash
kubectl apply -f keycloak-deployment.yaml
```

### Realmインポート

```yaml
apiVersion: keycloak.org/v1alpha1
kind: KeycloakRealmImport
metadata:
  name: example-realm-import
spec:
  keycloakCRName: my-keycloak
  realm:
    realm: example-realm
    enabled: true
    clients:
      - clientId: my-client
        enabled: true
        protocol: openid-connect
        redirectUris:
          - "http://localhost:3000/*"
```

### 特徴

- 自動スケーリング（HPA連携）
- ローリングアップデート
- Realm設定のGitOps管理

---

## クラスタリング（HA構成）

### 概要

複数Keycloakインスタンスによる高可用性構成。Infinispan分散キャッシュを使用。

### standalone.xml設定

```xml
<subsystem xmlns="urn:jboss:domain:infinispan:5.0">
    <cache-container name="keycloak" default-cache="sessions" module="org.keycloak.cache.infinispan">
        <local-cache name="sessions">
            <expiration lifespan="600" max-idle="300"/>
        </local-cache>
        <replicated-cache name="realms">
            <expiration lifespan="600" max-idle="300"/>
        </replicated-cache>
    </cache-container>
</subsystem>
```

### クラスタ構成パターン

#### 1. 2-Node HA（最小構成）

```
Load Balancer (HAProxy/Nginx)
    |
    |-- Keycloak Node 1 (Primary)
    |-- Keycloak Node 2 (Standby)
         |
         └── PostgreSQL (HA)
```

#### 2. Multi-Node HA（推奨）

```
Load Balancer
    |
    |-- Keycloak Node 1
    |-- Keycloak Node 2
    |-- Keycloak Node 3
         |
         └── PostgreSQL Cluster (Patroni/Replication)
```

### Infinispanキャッシュ設定

| キャッシュ名 | 種別 | 用途 |
|------------|------|------|
| `sessions` | local-cache | ユーザーセッション |
| `realms` | replicated-cache | Realm設定 |
| `users` | distributed-cache | ユーザーデータ |
| `offlineSessions` | distributed-cache | オフラインセッション |

---

## データベース

### サポートDB比較テーブル

| DB | バージョン | トランザクション | パフォーマンス | 推奨環境 |
|----|----------|--------------|-------------|----------|
| **PostgreSQL** | 10+ | ✅ ACID | 高 | 本番環境（推奨） |
| **MySQL** | 5.7+ | ✅ ACID | 中 | 既存MySQL環境 |
| **MariaDB** | 10.3+ | ✅ ACID | 中 | MySQL代替 |
| **Oracle** | 12c+ | ✅ ACID | 高 | エンタープライズ |
| **SQL Server** | 2016+ | ✅ ACID | 高 | Windowsエコシステム |
| **H2** | 1.4+ | ❌ 単一プロセス | 低 | 開発環境のみ |

### PostgreSQL設定例

```bash
# PostgreSQL DB作成
CREATE DATABASE keycloak;
CREATE USER keycloak_user WITH PASSWORD 'securepassword';
GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak_user;
```

### Keycloak DB接続設定

```bash
# 環境変数（Docker）
docker run -e DB_VENDOR=postgres \
  -e DB_ADDR=postgres.example.com \
  -e DB_DATABASE=keycloak \
  -e DB_USER=keycloak_user \
  -e DB_PASSWORD=securepassword \
  jboss/keycloak
```

---

## キャッシュ（Infinispan）

### 概要

Infinispanによる分散キャッシュ。セッション・トークン・Realm設定を高速化。

### キャッシュ設定チェック

```bash
./bin/kc.sh get-config --config cache
```

**レスポンス例:**
```json
{
  "session": {
    "enabled": true,
    "maxIdle": 1800,
    "maxSize": 1000
  },
  "token": {
    "enabled": true,
    "maxIdle": 3600,
    "maxSize": 500
  }
}
```

### カスタムキャッシュ設定

```xml
<cache-container name="keycloak" default-cache="sessions">
    <local-cache name="sessions">
        <expiration max-idle="1800" />
        <memory>
            <object-count max="1000" />
        </memory>
    </local-cache>
    <local-cache name="tokens">
        <expiration max-idle="3600" />
        <memory>
            <object-count max="500" />
        </memory>
    </local-cache>
</cache-container>
```

### キャッシュ戦略

- **Local Cache**: 単一ノード環境
- **Replicated Cache**: 全ノードに複製（小規模クラスタ）
- **Distributed Cache**: ハッシュ分散（大規模クラスタ）

---

## 監視

### Prometheus Metrics

#### Metricsエンドポイント有効化

Keycloak起動時に`--metrics-enabled=true`オプション追加。

#### Prometheus設定

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'keycloak'
    metrics_path: '/realms/master/metrics'
    static_configs:
      - targets: ['localhost:8080']
```

#### Prometheusサービス再起動

```bash
systemctl restart prometheus
```

#### 主要メトリクス

| メトリクス名 | 説明 |
|-----------|------|
| `keycloak_authentication_requests_total` | 認証リクエスト総数 |
| `keycloak_authorization_permissions_total` | 認可パーミッション総数 |
| `keycloak_session_active_total` | アクティブセッション数 |
| `keycloak_token_issued_total` | 発行トークン総数 |
| `keycloak_login_failures_total` | ログイン失敗数 |

### Grafana ダッシュボード

#### Prometheus DataSource追加

1. Grafana > Configuration > Data Sources
2. Add data source > Prometheus
3. URL: `http://prometheus:9090`

#### Keycloakダッシュボードインポート

1. Grafana > Dashboards > Import
2. Dashboard ID: `10441` (Keycloak公式)
3. Data source: Prometheus

#### カスタムパネル例

```
# 認証リクエストレート（1分平均）
rate(keycloak_authentication_requests_total[1m])

# ログイン失敗率
rate(keycloak_login_failures_total[5m]) / rate(keycloak_authentication_requests_total[5m])
```

---

## Realm Export/Import

### Export（エクスポート）

```bash
# Docker経由でRealm設定をエクスポート
docker run --rm \
  -e KEYCLOAK_USER=admin \
  -e KEYCLOAK_PASSWORD=admin \
  -e DB_VENDOR=h2 \
  jboss/keycloak:latest \
  -Dkeycloak.migration.action=export \
  -Dkeycloak.migration.realmName=new-realm \
  -Dkeycloak.migration.provider=singleFile \
  -Dkeycloak.migration.file=/tmp/new-realm.json
```

### Import（インポート）

```bash
# エクスポートしたRealmをインポート
docker run --rm \
  -v /path/to/new-realm.json:/tmp/new-realm.json \
  -e KEYCLOAK_USER=admin \
  -e KEYCLOAK_PASSWORD=admin \
  -e DB_VENDOR=h2 \
  jboss/keycloak:latest \
  -Dkeycloak.migration.action=import \
  -Dkeycloak.migration.provider=singleFile \
  -Dkeycloak.migration.file=/tmp/new-realm.json
```

### CI/CD統合

```yaml
# .gitlab-ci.yml 例
deploy_keycloak:
  stage: deploy
  script:
    - kubectl apply -f keycloak-realm-import.yaml
    - kubectl wait --for=condition=complete keycloakrealmimport/example-realm-import
```

---

## CORS設定

### CLI経由設定

```bash
kcadm.sh update clients/<client_id> -r <realm> -s 'attributes={"cors": "true", "cors-allowed-origins": ["http://example.com"], "cors-allowed-methods": "GET,POST,PUT,DELETE"}'
```

### Admin Console設定

1. `Clients > {client_id} > Settings`
2. `Web Origins`: `http://example.com`追加
3. Save

### CORS Headers

Keycloak自動生成:
- `Access-Control-Allow-Origin`
- `Access-Control-Allow-Methods`
- `Access-Control-Allow-Headers`

---

## Session管理

### Client Session Tracking

#### Admin CLI経由でSession取得

```bash
# ログイン
kcadm.sh config credentials --server http://localhost:8080/auth --realm master --user admin --password admin

# クライアントセッション数取得
kcadm.sh get clients/$(kcadm.sh get clients -r your_realm -q clientId=your_client_id --fields id --format csv | tail -n 1)/session-count -r your_realm

# ユーザーセッション詳細取得
kcadm.sh get clients/$(kcadm.sh get clients -r your_realm -q clientId=your_client_id --fields id --format csv | tail -n 1)/user-sessions -r your_realm
```

### Session Limits

時間ベースのセッション制限設定（Admin Console）:

1. `Realm Settings > Tokens`
2. `SSO Session Max`: セッション最大時間（秒）
3. `SSO Session Idle`: アイドル時間（秒）

### Session Expiration

```bash
# セッション有効期限設定（例: 10時間）
kcadm.sh update-realm -r sso-realm -s ssoSessionMaxLifespan=36000
```

### Remember Me

1. `Realm Settings > Login`
2. `Remember Me`: ON
3. ログイン画面に「Remember Me」チェックボックス表示

---

## Audit Logging

### イベントログ有効化

1. `Realm Settings > Events`
2. `Save Events`: ON
3. `Event Listeners`: `jboss-logging`追加
4. `Saved Types`: ログ対象イベント選択（LOGIN、LOGOUT、REGISTER等）

### ログ出力先

```bash
# Keycloak ログファイル
tail -f /opt/keycloak/standalone/log/server.log
```

### 主要イベントタイプ

- `LOGIN`: ユーザーログイン
- `LOGIN_ERROR`: ログイン失敗
- `LOGOUT`: ユーザーログアウト
- `REGISTER`: ユーザー登録
- `UPDATE_PASSWORD`: パスワード更新
- `CLIENT_LOGIN`: クライアント認証

---

## Password Policies

### ポリシー設定（Admin Console）

1. `Realm Settings > Security Defenses > Password Policy`
2. `Add policy`から以下を選択:
   - `Minimum Length`: 最小文字数
   - `Not Username`: ユーザー名と一致禁止
   - `Uppercase Characters`: 大文字必須
   - `Lowercase Characters`: 小文字必須
   - `Special Characters`: 特殊文字必須
   - `Digits`: 数字必須
   - `Not Recently Used`: 過去N回のパスワード使用禁止

### CLI経由設定

```bash
kcadm.sh update realms/myrealm -s 'passwordPolicy="length(8) and upperCase(1) and lowerCase(1) and digits(1) and specialChars(1)"'
```

---

## Master Realm

### 概要

全Realmを管理する特殊Realm。

### 役割

- 管理者アカウント管理
- 他Realmの作成・削除
- グローバル設定

### セキュリティベストプラクティス

- Master Realmの管理者アカウントを最小限に
- 本番環境ではMaster Realmへの直接アクセス制限
- 各RealmごとにRealm Adminロール割り当て

---

## デプロイモデル比較（オンプレミス・クラウド・ハイブリッド）

### デプロイモデル選択ガイド

| デプロイモデル | 規模 | 制御レベル | コスト構造 | 推奨ケース |
|-------------|-----|----------|----------|----------|
| **オンプレミス** | 中～大規模 | 最大 | CAPEX中心 | データ主権・コンプライアンス重視 |
| **パブリッククラウド** | 小～大規模 | 中 | OPEX中心 | 迅速な展開・弾力的スケーリング |
| **プライベートクラウド** | 大規模 | 高 | CAPEX+OPEX | エンタープライズ・厳格なセキュリティ |
| **ハイブリッド** | 大規模 | 中～高 | 混合 | 段階的クラウド移行・ワークロード分離 |

### オンプレミスデプロイ

**利点:**
- ハードウェア・ソフトウェアスタックの完全な管理制御
- データプライバシー・コンプライアンス対応（データローカライゼーション）
- サードパーティプラットフォームへの依存なしのカスタマイズ柔軟性

**考慮事項:**
- 運用オーバーヘッド（ハードウェアメンテナンス・パッチ適用・バックアップ・災害復旧）
- 物理リソース制約によるスケーラビリティ限界
- 高可用性には高度なクラスタリング・フェイルオーバー設定が必要

**典型的構成:**
- VM/物理ホスト上にKeycloakサーバーをデプロイ
- LDAP/Active Directoryとの統合（既存ディレクトリサービス活用）
- ファイアウォールルール・ネットワークセグメンテーションによる保護

### クラウドデプロイ（パブリック・プライベート）

**パブリッククラウド（AWS・Azure・GCP）:**
- Kubernetes/コンテナオーケストレーション活用による自動スケーリング・ローリングアップデート
- マネージドデータベース・オブジェクトストレージ利用による耐久性向上
- クラウドIDプロバイダー・APIゲートウェイとのシームレスな統合

**利点:**
- 迅速なプロビジョニング・オンデマンドリソーススケーリング
- CAPEX削減（OPEXモデル）
- 組み込み監視・ログ・セキュリティサービス
- グローバルアベイラビリティゾーン対応

**考慮事項:**
- ベンダーロックインリスク
- データレジデンシー制約（規制要件）
- マルチテナント環境でのセキュリティポリシー調整
- トラブルシューティング・パフォーマンスチューニングの複雑化

### ハイブリッドデプロイ

**概要:**
オンプレミスとクラウド環境を組み合わせ、ワークロード特性・セキュリティ要件・レガシーシステム統合ニーズに基づいてKeycloakインスタンス/サービスを分散配置。

**典型的パターン:**
1. **権威ソースハイブリッド:** オンプレミスKeycloakを権威IDソースとし、クラウドベースKeycloakと同期/フェデレーション
2. **境界ベースハイブリッド:** 外部向けアプリはクラウドKeycloak経由で認証、内部アプリはオンプレミスKeycloakで認証、セキュアトンネル/IDフェデレーションプロトコル（SAML/OIDC）でブリッジ

**主要考慮要因:**
- オンプレミス・クラウド間のネットワークレイテンシー・帯域幅
- 同期/フェデレーションメカニズム維持の複雑性
- 多様なインフラにわたる認証エンドポイント公開のセキュリティ態勢
- データガバナンスポリシー（機密度によるワークロード分割）

### デプロイモデル選択判断基準

**制御 vs 利便性:**
- オンプレミス: 最大制御、高い内部専門知識要求
- クラウド: 一部制御を犠牲にして運用効率・スケーラビリティ向上

**コンプライアンス要件:**
- データ保護規制が物理的データローカリティを義務付ける場合 → オンプレミス/ハイブリッド

**統合複雑性:**
- 既存インフラ投資（プロプライエタリIdP・レガシーアプリ）がクラウド移行の実現可能性に影響

**スケーラビリティ・可用性:**
- クラウドネイティブモデルは弾性スケーリング・グローバル分散を容易に実現
- 従来型デプロイは慎重なキャパシティ・フェイルオーバー計画が必要

**コスト構造:**
- 長期的TCO（ハードウェア・ライセンス・人員・クラウド利用料）が重要な判断要素

---

## Configuration as Code（IaC統合）

### 概要

Infrastructure as Code（IaC）原則によるKeycloak設定管理により、一貫性・再現性・保守性が大幅に向上。手動操作やアドホックスクリプトに依存せず、Realm・Client・Role・User等のエンティティをバージョン管理可能な成果物として宣言的に定義。

### ツール選択

| ツール | 用途 | 特徴 |
|-------|------|------|
| **Terraform** | インフラ全体管理 | Keycloak Providerでリソース宣言的管理 |
| **Ansible** | 設定管理・自動化 | Playbookベースのべき等デプロイ |
| **Helm** | Kubernetesパッケージ管理 | Keycloak Chartでテンプレート化デプロイ |
| **keycloak-config-cli** | Keycloak専用設定管理 | JSON/YAMLファイルによるRealm設定適用 |

### Terraformによる宣言的管理例

```hcl
resource "keycloak_realm" "myrealm" {
  realm   = "production"
  enabled = true

  smtp_server {
    host = "smtp.example.com"
    from = "noreply@example.com"
    auth {
      username = var.smtp_username
      password = var.smtp_password
    }
  }
}

resource "keycloak_openid_client" "webapp" {
  realm_id              = keycloak_realm.myrealm.id
  client_id             = "webapp-client"
  name                  = "Web Application"
  enabled               = true
  access_type           = "confidential"
  valid_redirect_uris   = ["https://webapp.example.com/*"]
  standard_flow_enabled = true
  secret                = var.client_secret
}
```

### Ansibleによる自動化例

```yaml
- name: Deploy Keycloak Realm Configuration
  hosts: keycloak_servers
  tasks:
    - name: Copy realm configuration file
      copy:
        src: files/myrealm.json
        dest: /tmp/myrealm.json

    - name: Import realm via kcadm.sh
      shell: |
        /opt/keycloak/bin/kcadm.sh config credentials \
          --server http://localhost:8080/auth \
          --realm master \
          --user admin \
          --password {{ admin_password }}
        /opt/keycloak/bin/kcadm.sh create realms \
          -f /tmp/myrealm.json
```

### CI/CDパイプライン統合

**典型的自動化ワークフロー:**

1. **Linting・静的解析:** 設定ファイルの構文チェック・ベストプラクティス検証
2. **検証:** 使い捨てKeycloakインスタンスに対する統合テスト（回帰・脆弱性確認）
3. **デプロイ:** IaCツール（Terraform/Ansible）による本番環境への変更適用
4. **検証:** デプロイ後スモークテスト（認証フロー・設定適用成功確認）

**CI/CD例（GitLab CI）:**

```yaml
stages:
  - validate
  - deploy
  - verify

validate:
  stage: validate
  script:
    - terraform fmt -check
    - terraform validate

deploy:
  stage: deploy
  script:
    - terraform apply -auto-approve
  only:
    - main

verify:
  stage: verify
  script:
    - ./scripts/smoke-test.sh
```

### シークレット管理

機密データ（クライアントシークレット・ユーザー認証情報）は、設定リポジトリにハードコードせず、外部Vault（HashiCorp Vault・AWS Secrets Manager等）または暗号化環境変数で管理。

**Terraform + Vault例:**

```hcl
data "vault_generic_secret" "keycloak" {
  path = "secret/keycloak/prod"
}

resource "keycloak_openid_client" "app" {
  # ...
  secret = data.vault_generic_secret.keycloak.data["client_secret"]
}
```

### ベストプラクティス

- **バージョン管理必須:** すべての設定ファイルをGit管理
- **べき等性担保:** 同じ設定を複数回適用しても同じ結果
- **環境分離:** dev/staging/prod環境ごとに設定を分離（変数化・ワークスペース活用）
- **コードレビュー:** 設定変更に対するプルリクエストベースのレビュープロセス
- **ロールバック戦略:** 変更失敗時の迅速なロールバック手順確立

---

## ロードバランシング・トラフィック管理

### ロードバランサー配置パターン

```
                   Internet
                       |
                  (TLS終端)
                       |
           +-------------------+
           | Load Balancer     |
           | (HAProxy/Nginx/   |
           |  ALB/NLB)         |
           +-------------------+
                 |   |   |
       +---------+   |   +---------+
       |             |             |
  +---------+  +---------+  +---------+
  | KC Node1|  | KC Node2|  | KC Node3|
  +---------+  +---------+  +---------+
       |             |             |
       +-------------+-------------+
                     |
              +--------------+
              | PostgreSQL   |
              | (HA Cluster) |
              +--------------+
```

### スティッキーセッション設定

Keycloakセッション管理にはスティッキーセッション（セッションアフィニティ）が重要。

**HAProxy設定例:**

```
backend keycloak_backend
    balance roundrobin
    cookie SERVERID insert indirect nocache
    server kc1 10.0.1.10:8080 check cookie kc1
    server kc2 10.0.1.11:8080 check cookie kc2
    server kc3 10.0.1.12:8080 check cookie kc3
```

**Nginx設定例:**

```nginx
upstream keycloak {
    ip_hash;
    server 10.0.1.10:8080;
    server 10.0.1.11:8080;
    server 10.0.1.12:8080;
}

server {
    listen 443 ssl;
    server_name keycloak.example.com;

    ssl_certificate /etc/ssl/certs/keycloak.crt;
    ssl_certificate_key /etc/ssl/private/keycloak.key;

    location / {
        proxy_pass http://keycloak;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### ヘルスチェック設定

**エンドポイント:** `/health/ready`、`/health/live`

**HAProxy ヘルスチェック:**

```
backend keycloak_backend
    option httpchk GET /health/ready
    http-check expect status 200
    server kc1 10.0.1.10:8080 check inter 5s
```

### AWS Application Load Balancer（ALB）統合

```bash
# ターゲットグループ作成
aws elbv2 create-target-group \
  --name keycloak-tg \
  --protocol HTTP \
  --port 8080 \
  --vpc-id vpc-12345678 \
  --health-check-path /health/ready

# ALB作成・リスナー設定
aws elbv2 create-load-balancer \
  --name keycloak-alb \
  --subnets subnet-abc subnet-def \
  --security-groups sg-12345678
```

---

## バックアップ・リストア・災害復旧

### バックアップ戦略

#### 1. データベースバックアップ

**PostgreSQL定期バックアップ（pg_dump）:**

```bash
#!/bin/bash
# backup-keycloak-db.sh

BACKUP_DIR="/backup/keycloak"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DB_NAME="keycloak"
DB_USER="keycloak"

pg_dump -U $DB_USER -Fc $DB_NAME > $BACKUP_DIR/keycloak_$TIMESTAMP.dump

# 古いバックアップ削除（30日以上）
find $BACKUP_DIR -name "keycloak_*.dump" -mtime +30 -delete
```

**Kubernetes CronJobによる自動化:**

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: keycloak-db-backup
spec:
  schedule: "0 2 * * *"  # 毎日午前2時
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: postgres:13
            command:
            - /bin/sh
            - -c
            - pg_dump -U keycloak -Fc keycloak > /backup/keycloak_$(date +\%Y\%m\%d).dump
            env:
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: keycloak-db-credentials
                  key: password
            volumeMounts:
            - name: backup-volume
              mountPath: /backup
          restartPolicy: OnFailure
          volumes:
          - name: backup-volume
            persistentVolumeClaim:
              claimName: keycloak-backup-pvc
```

#### 2. Realm Export/Importバックアップ

**全Realm一括エクスポート:**

```bash
# kcadm.sh経由で全Realmをエクスポート
kcadm.sh config credentials --server http://localhost:8080/auth \
  --realm master --user admin --password admin

for realm in $(kcadm.sh get realms --fields realm --format csv | tail -n +2); do
  kcadm.sh get realms/$realm > /backup/realm_${realm}_$(date +%Y%m%d).json
done
```

### リストア手順

#### データベースリストア

```bash
# PostgreSQLリストア
pg_restore -U keycloak -d keycloak /backup/keycloak_20260212.dump
```

#### Realmインポート

```bash
# 単一Realmインポート
kcadm.sh create realms -f /backup/realm_production_20260212.json
```

### 災害復旧（DR）計画

#### RTO/RPO定義例

| 環境 | RTO（目標復旧時間） | RPO（目標復旧時点） |
|------|---------------------|---------------------|
| 開発環境 | 24時間 | 24時間 |
| ステージング | 4時間 | 1時間 |
| 本番環境 | 1時間 | 15分 |

#### DR実行手順

1. **即時対応:** セカンダリサイト/リージョンへのフェイルオーバー起動
2. **データ復旧:** 最新バックアップからDB・Realm設定をリストア
3. **サービス検証:** 認証フロー・SSO・統合の動作確認
4. **トラフィック切り替え:** DNSまたはロードバランサー設定変更
5. **事後分析:** インシデント原因分析・改善策実施

---

## デプロイチェックリスト

### 本番環境デプロイ前

- [ ] PostgreSQL/MySQL等の永続DBを設定
- [ ] HA構成（2ノード以上）の構築
- [ ] Prometheus/Grafana監視設定
- [ ] CORS設定確認
- [ ] Password Policy設定
- [ ] Audit Logging有効化
- [ ] Realm Export/Import手順確認
- [ ] バックアップ戦略策定（DB + Realm Export自動化）
- [ ] ロードバランサー設定（スティッキーセッション・ヘルスチェック）
- [ ] SSL/TLS証明書設定
- [ ] Configuration as Code（IaC）セットアップ（Terraform/Ansible）
- [ ] CI/CDパイプライン統合
- [ ] 災害復旧計画・RTO/RPO定義
