# オブザーバビリティ・監視・インシデント対応

## 運用監視

効果的な運用監視はKeycloakの堅牢性・スケーラビリティ・セキュリティを保証するために不可欠。

### KPIとヘルスメトリクス

Keycloakの計装は以下のカテゴリに分類されるメトリクスを取得する。

#### システムリソース利用

| メトリクス | 説明 | しきい値例 |
|----------|------|----------|
| **CPU使用率** | JVM・OS レベルのCPU消費 | > 80%でアラート |
| **メモリ使用量** | ヒープメモリ・非ヒープメモリ | ヒープ > 85%でアラート |
| **GC頻度・停止時間** | ガベージコレクション影響 | 停止時間 > 500msでアラート |
| **スレッドプール** | アクティブ・待機スレッド数 | 枯渇でアラート |

#### リクエスト処理

| メトリクス | 説明 | しきい値例 |
|----------|------|----------|
| **レスポンスタイム** | 認証リクエスト処理時間 | P95 > 1秒でアラート |
| **スループット** | 秒あたりのリクエスト数 | キャパシティプランニング指標 |
| **エラーレート** | 4xx/5xxレスポンス率 | > 5%でアラート |

#### 認証固有指標

| メトリクス | 説明 | しきい値例 |
|----------|------|----------|
| **認証成功率** | 成功した認証の割合 | < 95%でアラート |
| **トークン発行数** | 発行されたAccess Token・ID Token数 | 異常増加で調査 |
| **セッション数** | アクティブSSOセッション数 | キャパシティ管理 |
| **ログイン失敗回数** | 失敗ログイン試行数 | 急増でセキュリティアラート |

### Prometheus設定・メトリクスSPI

Keycloak 17+はPrometheus統合をサポート。

#### Prometheusエンドポイント有効化

```bash
# Keycloak起動時にmetricsエンドポイント有効化
kc.sh start --metrics-enabled=true --http-enabled=true --hostname=localhost
```

**メトリクスエンドポイント**:
```
http://localhost:8080/metrics
```

#### Prometheus設定例（prometheus.yml）

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'keycloak'
    static_configs:
      - targets: ['localhost:8080']
    metrics_path: '/metrics'
    scheme: 'http'
```

#### カスタムメトリクスSPI実装

Keycloak SPIを使用してビジネス固有のメトリクスを追加する。

```java
// カスタムメトリクスプロバイダー例
public class CustomMetricsProvider implements MetricsProvider {
    private final MeterRegistry registry;

    @Override
    public void recordLogin(String realm, String userId) {
        Counter.builder("keycloak.custom.login.count")
            .tag("realm", realm)
            .register(registry)
            .increment();
    }

    @Override
    public void recordLoginDuration(String realm, long durationMs) {
        Timer.builder("keycloak.custom.login.duration")
            .tag("realm", realm)
            .register(registry)
            .record(Duration.ofMillis(durationMs));
    }
}
```

### Grafanaダッシュボード設計

Grafanaを使用してKeycloakメトリクスを可視化する。

#### 推奨ダッシュボードパネル

| パネル | クエリ | 用途 |
|-------|------|------|
| **認証成功率** | `rate(keycloak_login_attempts{result="success"}[5m]) / rate(keycloak_login_attempts[5m])` | 認証ヘルス全体像 |
| **平均レスポンスタイム** | `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))` | パフォーマンス追跡 |
| **エラーレート** | `rate(http_requests_total{status=~"5.."}[5m])` | システムエラー検知 |
| **アクティブセッション** | `keycloak_sessions_active` | キャパシティ監視 |
| **JVMヒープ使用率** | `(jvm_memory_used_bytes{area="heap"} / jvm_memory_max_bytes{area="heap"}) * 100` | メモリ枯渇予測 |

#### Grafanaダッシュボード設定例（JSON）

```json
{
  "dashboard": {
    "title": "Keycloak Monitoring",
    "panels": [
      {
        "title": "Authentication Success Rate",
        "targets": [{
          "expr": "rate(keycloak_login_attempts{result=\"success\"}[5m]) / rate(keycloak_login_attempts[5m])"
        }],
        "type": "graph"
      },
      {
        "title": "Response Time (P95)",
        "targets": [{
          "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))"
        }],
        "type": "graph"
      }
    ]
  }
}
```

### アラート設定

PrometheusのAlertmanagerを使用した重要アラート設定。

#### Prometheusアラートルール例（alerts.yml）

```yaml
groups:
  - name: keycloak_alerts
    interval: 30s
    rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value }} (threshold: 0.05)"

      - alert: HighMemoryUsage
        expr: (jvm_memory_used_bytes{area="heap"} / jvm_memory_max_bytes{area="heap"}) > 0.85
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High JVM heap memory usage"
          description: "Heap usage is {{ $value }}%"

      - alert: LowAuthenticationSuccessRate
        expr: rate(keycloak_login_attempts{result="success"}[5m]) / rate(keycloak_login_attempts[5m]) < 0.95
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Low authentication success rate"
          description: "Success rate is {{ $value }} (threshold: 0.95)"

      - alert: DatabaseConnectionPoolExhausted
        expr: hikaricp_connections_active >= hikaricp_connections_max
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Database connection pool exhausted"
```

---

## 構造化・集中ログ管理

### ログフォーマット設定

Keycloak 17+はJSON形式のログ出力をサポート。

#### JSON形式ログ有効化

```bash
# keycloak.confに設定
log-console-format=json
log-level=INFO
```

**出力例**:
```json
{
  "timestamp": "2024-02-12T10:30:45.123Z",
  "level": "INFO",
  "logger": "org.keycloak.events",
  "message": "User authentication successful",
  "realm": "myrealm",
  "userId": "user-id-123",
  "clientId": "my-client",
  "ipAddress": "192.168.1.100"
}
```

### ELK/EFK Stack統合

#### Filebeat設定（filebeat.yml）

```yaml
filebeat.inputs:
  - type: log
    enabled: true
    paths:
      - /opt/keycloak/data/log/*.log
    json.keys_under_root: true
    json.add_error_key: true

output.elasticsearch:
  hosts: ["elasticsearch:9200"]
  index: "keycloak-logs-%{+yyyy.MM.dd}"

setup.kibana:
  host: "kibana:5601"
```

#### Fluentd設定（fluent.conf）

```conf
<source>
  @type tail
  path /opt/keycloak/data/log/*.log
  pos_file /var/log/fluentd/keycloak.pos
  tag keycloak
  <parse>
    @type json
  </parse>
</source>

<filter keycloak>
  @type record_transformer
  <record>
    service keycloak
    environment ${ENV_NAME}
  </record>
</filter>

<match keycloak>
  @type elasticsearch
  host elasticsearch
  port 9200
  logstash_format true
  logstash_prefix keycloak
</match>
```

### ログレベル設計

| レベル | 用途 | 本番推奨 |
|-------|------|---------|
| **ERROR** | システムエラー・障害 | ✅ 必須 |
| **WARN** | 潜在的な問題・非推奨機能使用 | ✅ 必須 |
| **INFO** | 認証イベント・重要操作 | ✅ 必須 |
| **DEBUG** | 詳細なトラブルシューティング | ❌ 開発・調査時のみ |
| **TRACE** | 非常に詳細なデバッグ | ❌ 本番使用禁止 |

#### カテゴリ別ログレベル設定

```bash
# 特定カテゴリのログレベル変更
kc.sh start \
  --log-level=INFO \
  --log-level=org.keycloak.events:DEBUG \
  --log-level=org.hibernate.SQL:DEBUG
```

### 監査ログ設計

**記録すべき重要イベント**:
- ユーザーログイン・ログアウト
- ロール・権限変更
- クライアント設定変更
- Realm設定変更
- パスワードリセット・アカウントロック

#### Event Listener設定（監査ログ永続化）

```bash
# Admin Console > Realm Settings > Events
# Event Listeners に "jboss-logging" を追加
# Saved Events: Login, Login Error, Register, Code to Token, etc.
```

---

## パフォーマンスチューニング・ボトルネック分析

### JVMチューニング（ヒープ、GC）

#### ヒープサイズ設定

```bash
# JAVA_OPTS環境変数で設定
export JAVA_OPTS="-Xms2g -Xmx4g -XX:MetaspaceSize=256m -XX:MaxMetaspaceSize=512m"

# または keycloak.confで設定
export JAVA_OPTS_APPEND="-Xms2g -Xmx4g"
```

**推奨設定**:
| ユーザー数 | 最小ヒープ | 最大ヒープ |
|----------|----------|----------|
| < 1,000 | 1GB | 2GB |
| 1,000 - 10,000 | 2GB | 4GB |
| 10,000 - 100,000 | 4GB | 8GB |
| > 100,000 | 8GB+ | 16GB+ |

#### GC設定（G1GC推奨）

```bash
# G1GCを使用（Java 11+のデフォルト）
export JAVA_OPTS="-XX:+UseG1GC \
  -XX:MaxGCPauseMillis=200 \
  -XX:InitiatingHeapOccupancyPercent=45 \
  -XX:G1HeapRegionSize=16m"
```

**GCパラメータ調整**:
| パラメータ | 説明 | 推奨値 |
|----------|------|-------|
| `MaxGCPauseMillis` | 最大GC停止時間目標 | 200ms |
| `InitiatingHeapOccupancyPercent` | Full GC開始ヒープ使用率 | 45% |
| `G1HeapRegionSize` | G1リージョンサイズ | 16m（大規模: 32m） |

### データベースクエリ最適化

#### コネクションプール設定

```bash
# keycloak.confまたは環境変数
db-pool-initial-size=10
db-pool-min-size=10
db-pool-max-size=100
```

**推奨コネクションプールサイズ**:
```
最大プールサイズ = (コア数 × 2) + スピンドル数
```

例: 8コアCPU、SSD使用 → 最大プール = (8 × 2) + 1 = 17

#### インデックス最適化

**重要なインデックス**:
```sql
-- ユーザー検索最適化
CREATE INDEX idx_user_username ON user_entity(username);
CREATE INDEX idx_user_email ON user_entity(email);

-- セッション検索最適化
CREATE INDEX idx_session_realm_user ON user_session(realm_id, user_id);

-- イベント検索最適化
CREATE INDEX idx_event_time ON event_entity(event_time);
CREATE INDEX idx_event_realm ON event_entity(realm_id);
```

### キャッシュ戦略

Keycloakは複数のキャッシュレイヤーを使用。

#### Infinispan設定（クラスター）

```xml
<!-- cache-ispn.xml -->
<infinispan xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
            xsi:schemaLocation="urn:infinispan:config:14.0 https://infinispan.org/schemas/infinispan-config-14.0.xsd"
            xmlns="urn:infinispan:config:14.0">

    <cache-container name="keycloak">
        <transport lock-timeout="60000"/>

        <distributed-cache name="sessions" owners="2">
            <expiration lifespan="-1"/>
        </distributed-cache>

        <distributed-cache name="authenticationSessions" owners="2">
            <expiration lifespan="1800000"/>
        </distributed-cache>

        <replicated-cache name="work">
            <expiration lifespan="-1"/>
        </replicated-cache>
    </cache-container>
</infinispan>
```

#### キャッシュサイズ調整

```bash
# キャッシュ最大エントリ数設定
cache-remote-name=keycloak
cache-remote-max-entries=10000
```

### ボトルネック分析手法

#### 診断手順

| ステップ | ツール | 確認項目 |
|---------|-------|---------|
| **1. メトリクス確認** | Prometheus/Grafana | CPU、メモリ、レスポンスタイム |
| **2. ログ分析** | ELK Stack | エラーログ、スロークエリ |
| **3. JVMプロファイリング** | JProfiler, VisualVM | ヒープ使用、スレッドブロック |
| **4. DBクエリ分析** | pg_stat_statements, EXPLAIN | スロークエリ、インデックス欠落 |
| **5. ネットワーク計測** | tcpdump, Wireshark | レイテンシ、パケットロス |

#### 一般的なボトルネックパターン

| 症状 | 原因 | 対策 |
|-----|------|-----|
| **高レスポンスタイム** | DB接続プール枯渇 | プールサイズ増加、クエリ最適化 |
| **メモリ枯渇** | キャッシュ肥大化 | キャッシュサイズ制限、エビクションポリシー調整 |
| **CPU高負荷** | GC頻発 | ヒープサイズ増加、GCアルゴリズム変更 |
| **セッションタイムアウト** | クラスター同期遅延 | Infinispanタイムアウト調整 |

---

## 認証・SSOトラブルシューティング

### 一般的な認証エラーパターン

#### 認証失敗: Invalid Credentials

**原因**:
- ユーザーパスワード誤り
- アカウント無効化
- 必須アクション未完了

**診断**:
```bash
# ユーザー状態確認
curl -X GET "http://localhost:8080/auth/admin/realms/${REALM}/users/${USER_ID}" \
  -H "Authorization: Bearer ${TOKEN}"

# 必須アクション確認
jq '.requiredActions'
```

**対策**:
- パスワードリセットフロー案内
- 必須アクション完了促進
- アカウント有効化（管理者）

#### トークン検証エラー: Invalid Token

**原因**:
- トークン有効期限切れ
- 署名検証失敗
- Issuer不一致

**診断**:
```bash
# トークン内容デコード（jwt.io等）
# Issuer、Expiration確認

# Keycloak公開鍵確認
curl "http://localhost:8080/auth/realms/${REALM}/protocol/openid-connect/certs"
```

**対策**:
- トークンリフレッシュフロー実装
- クライアント署名検証設定確認
- Realmエンドポイント設定修正

### SSOセッション問題

#### セッション共有失敗（クラスター環境）

**症状**:
- 一部ノードでログイン、他ノードで未認証扱い

**原因**:
- Infinispanクラスター設定ミス
- ネットワーク分断
- セッションレプリケーション遅延

**診断**:
```bash
# クラスターメンバー確認
kc.sh show-config | grep cluster

# Infinispanログ確認
tail -f /opt/keycloak/data/log/keycloak.log | grep infinispan
```

**対策**:
- クラスター通信確認（JGroups設定）
- セッションスティッキネス有効化（ロードバランサー）
- データベースセッション永続化検討

#### セッション予期せぬ終了

**原因**:
- セッションタイムアウト設定
- ブラウザCookie削除
- Keycloak再起動時のセッション喪失

**対策**:
```bash
# セッションタイムアウト延長
curl -X PUT "http://localhost:8080/auth/admin/realms/${REALM}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "ssoSessionIdleTimeout": 3600,
    "ssoSessionMaxLifespan": 36000,
    "accessTokenLifespan": 300
  }'
```

---

## セキュリティインシデント検知・対応

### 異常検知パターン

#### ブルートフォース攻撃検知

**Keycloak組み込み保護機能**:
```bash
# Realm Settings > Security Defenses > Brute Force Detection
# パラメータ:
# - Max Login Failures: 5
# - Wait Increment: 60 seconds
# - Max Wait: 900 seconds
# - Failure Reset Time: 43200 seconds
```

**監視アラート**:
```yaml
# Prometheus Alert
- alert: BruteForceAttackDetected
  expr: rate(keycloak_login_attempts{result="error"}[5m]) > 10
  for: 2m
  labels:
    severity: critical
  annotations:
    summary: "Possible brute force attack"
    description: "Failed login rate is {{ $value }}/s"
```

#### 異常なトークン発行数

**検知ロジック**:
```yaml
- alert: AbnormalTokenIssuance
  expr: rate(keycloak_token_issued_total[5m]) > avg_over_time(keycloak_token_issued_total[1h]) * 3
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Abnormal token issuance rate"
```

### インシデントレスポンスプレイブック

#### Step 1: 検知・トリアージ

**アクション**:
1. アラート確認（Prometheus Alertmanager）
2. ログ初期分析（ELK Stack）
3. 影響範囲評価（特定Realm/ユーザー/IP）

#### Step 2: 封じ込め

**即座の対応**:
```bash
# 疑わしいユーザーアカウント無効化
curl -X PUT "http://localhost:8080/auth/admin/realms/${REALM}/users/${USER_ID}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"enabled": false}'

# 特定IPのブロック（WAF/ファイアウォールで）
iptables -A INPUT -s <SUSPICIOUS_IP> -j DROP
```

#### Step 3: 調査

**ログ分析クエリ例（Kibana）**:
```
realm: "myrealm" AND event_type: "LOGIN_ERROR" AND ip_address: "192.168.1.100"
```

#### Step 4: 根絶・復旧

**対策実施**:
- パスワードポリシー強化
- MFA強制有効化
- セッション強制無効化

```bash
# 全ユーザーセッション無効化
curl -X POST "http://localhost:8080/auth/admin/realms/${REALM}/logout-all" \
  -H "Authorization: Bearer ${TOKEN}"
```

#### Step 5: 事後分析

**レポート作成項目**:
- インシデントタイムライン
- 影響を受けたユーザー・システム
- 根本原因分析
- 再発防止策

---

## テスト戦略

### 認証フロー統合テスト

#### 基本認証フローテスト例（Python）

```python
import requests

def test_password_grant_flow():
    token_url = "http://localhost:8080/auth/realms/myrealm/protocol/openid-connect/token"

    response = requests.post(token_url, data={
        "grant_type": "password",
        "client_id": "my-client",
        "client_secret": "my-secret",
        "username": "testuser",
        "password": "testpass"
    })

    assert response.status_code == 200
    assert "access_token" in response.json()
    assert "refresh_token" in response.json()
```

### 負荷テスト

#### JMeterシナリオ例

```xml
<!-- JMeter Test Plan -->
<ThreadGroup>
  <stringProp name="ThreadGroup.num_threads">1000</stringProp>
  <stringProp name="ThreadGroup.ramp_time">60</stringProp>
  <stringProp name="ThreadGroup.duration">300</stringProp>

  <HTTPSamplerProxy>
    <stringProp name="HTTPSampler.domain">localhost</stringProp>
    <stringProp name="HTTPSampler.port">8080</stringProp>
    <stringProp name="HTTPSampler.path">/auth/realms/myrealm/protocol/openid-connect/token</stringProp>
    <stringProp name="HTTPSampler.method">POST</stringProp>
    <elementProp name="HTTPsampler.Arguments">
      <collectionProp name="Arguments.arguments">
        <elementProp name="grant_type" elementType="HTTPArgument">
          <stringProp name="Argument.value">password</stringProp>
        </elementProp>
      </collectionProp>
    </elementProp>
  </HTTPSamplerProxy>
</ThreadGroup>
```

**負荷テストKPI**:
| 指標 | 目標値 |
|-----|-------|
| **平均レスポンスタイム** | < 500ms |
| **P95レスポンスタイム** | < 1000ms |
| **エラー率** | < 1% |
| **スループット** | > 100 req/s（ユーザー数に応じて調整） |

### セキュリティテスト

#### OWASPテストシナリオ

| テスト | ツール | 確認項目 |
|-------|-------|---------|
| **脆弱性スキャン** | OWASP ZAP, Burp Suite | SQL Injection, XSS, CSRF |
| **認証バイパス** | 手動ペネトレーション | セッション固定、権限昇格 |
| **トークン検証** | jwt.io + 手動検証 | 署名検証、有効期限、Issuer |
| **ブルートフォース** | Hydra, Medusa | アカウントロック動作確認 |

---

## コンプライアンス監査

### 監査ログ設計

**記録必須項目**:
- タイムスタンプ
- ユーザーID・Realm
- 操作種別（ログイン、ロール変更等）
- 送信元IPアドレス
- 結果（成功/失敗）

#### 監査ログ永続化設定

```bash
# Admin Console > Events > Save Events
# 有効化: Login, Login Error, Register, Logout, Code to Token Error
# ログ保持期間: 90日（規制要件に応じて調整）
```

### レポート生成

#### 監査レポートクエリ例（PostgreSQL）

```sql
-- 過去30日間のログイン成功数（ユーザー別）
SELECT user_id, COUNT(*) as login_count
FROM event_entity
WHERE event_time > NOW() - INTERVAL '30 days'
  AND type = 'LOGIN'
GROUP BY user_id
ORDER BY login_count DESC;

-- 権限変更履歴
SELECT event_time, user_id, details
FROM admin_event_entity
WHERE resource_type = 'USER'
  AND operation_type = 'UPDATE'
  AND details LIKE '%realmRoles%'
ORDER BY event_time DESC;
```

### 規制対応

#### GDPR対応チェックリスト

- [ ] ユーザー同意管理機能実装
- [ ] データエクスポート機能提供
- [ ] データ削除リクエスト対応
- [ ] 監査ログ保持期間設定（最長2年推奨）
- [ ] 個人データ暗号化（DB、バックアップ）

#### SOC 2対応

- [ ] アクセスログ集中管理
- [ ] 定期的なアクセスレビュー実施
- [ ] 多要素認証強制
- [ ] 脆弱性スキャン定期実施
- [ ] インシデントレスポンスプレイブック整備

---

## 判断基準・推奨事項

### 監視レベルの選択

| 環境 | メトリクス収集頻度 | ログレベル | ダッシュボード |
|-----|---------------|----------|-----------|
| **開発** | 60秒 | DEBUG | 基本 |
| **ステージング** | 30秒 | INFO | 詳細 |
| **本番（小規模）** | 15秒 | INFO | 詳細 + アラート |
| **本番（大規模）** | 10秒 | WARN | 詳細 + リアルタイムアラート |

### アラートしきい値設定

| メトリクス | 警告 | 重大 |
|----------|------|-----|
| **CPU使用率** | 70% | 85% |
| **メモリ使用率** | 80% | 90% |
| **レスポンスタイム（P95）** | 1秒 | 3秒 |
| **エラーレート** | 2% | 5% |
| **認証成功率** | 98% | 95% |
