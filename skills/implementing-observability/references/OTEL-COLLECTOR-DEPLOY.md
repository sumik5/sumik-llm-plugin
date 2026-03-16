# OpenTelemetry Collector設定・デプロイ・サンプリング

OpenTelemetry Collectorの設定、デプロイモデルの選択、トレースサンプリング戦略を解説します。

---

## 1. OTLPプロトコル

### 1.1 OTLP設計原則

**OTLP（OpenTelemetry Protocol）の主要特性:**
- **高スループット**: 大量のテレメトリーデータの効率的な転送
- **圧縮**: gzip圧縮によるネットワーク帯域の最適化
- **暗号化**: TLS/mTLSによるセキュアな通信
- **信頼性**: リトライメカニズムとエラーハンドリング
- **バックプレッシャー**: クライアント側のフロー制御

### 1.2 OTLP/gRPC

**並行Unary呼び出しモデル:**
- 各リクエストは独立したUnary RPC呼び出し
- 複数のリクエストを並行して送信可能
- HTTP/2多重化による効率的な通信

**応答コード:**

| ステータス | 説明 | 対応 |
|----------|------|------|
| **OK** | 完全成功 | すべてのデータが受信・処理された |
| **PARTIAL_SUCCESS** | 部分成功 | 一部のデータが拒否された（`rejected_*`フィールド参照） |
| **UNAVAILABLE** | 失敗 | サーバーが一時的に利用不可（リトライ推奨） |
| **RESOURCE_EXHAUSTED** | 失敗 | サーバーのリソース不足（バックオフしてリトライ） |

**エンドポイント例:**
```
grpc://collector:4317
```

**設定例（Java SDK）:**
```java
import io.opentelemetry.exporter.otlp.trace.OtlpGrpcSpanExporter;

OtlpGrpcSpanExporter exporter = OtlpGrpcSpanExporter.builder()
    .setEndpoint("http://collector:4317")
    .setCompression("gzip")
    .setTimeout(10, TimeUnit.SECONDS)
    .build();
```

### 1.3 OTLP/HTTP

**プロトコルバリアント:**
- **OTLP/HTTP/Protobuf**: バイナリProtobuf（デフォルト、推奨）
- **OTLP/HTTP/JSON**: JSON形式（デバッグ用）

**URLパス:**

| シグナル | パス |
|---------|------|
| トレース | `/v1/traces` |
| メトリクス | `/v1/metrics` |
| ログ | `/v1/logs` |

**エンドポイント例:**
```
http://collector:4318/v1/traces
http://collector:4318/v1/metrics
http://collector:4318/v1/logs
```

**設定例（Java SDK）:**
```java
import io.opentelemetry.exporter.otlp.http.trace.OtlpHttpSpanExporter;

OtlpHttpSpanExporter exporter = OtlpHttpSpanExporter.builder()
    .setEndpoint("http://collector:4318/v1/traces")
    .setCompression("gzip")
    .setTimeout(10, TimeUnit.SECONDS)
    .build();
```

**HTTPヘッダーのカスタマイズ:**
```java
Map<String, String> headers = new HashMap<>();
headers.put("Authorization", "Bearer " + apiToken);
headers.put("X-Tenant-ID", tenantId);

OtlpHttpSpanExporter exporter = OtlpHttpSpanExporter.builder()
    .setEndpoint("http://collector:4318/v1/traces")
    .addHeader("Authorization", "Bearer " + apiToken)
    .addHeader("X-Tenant-ID", tenantId)
    .build();
```

### 1.4 環境変数による設定

**共通設定:**
```bash
# エンドポイント（トレース、メトリクス、ログで共通）
export OTEL_EXPORTER_OTLP_ENDPOINT=http://collector:4317

# プロトコル（grpc | http/protobuf | http/json）
export OTEL_EXPORTER_OTLP_PROTOCOL=grpc

# 圧縮（gzip | none）
export OTEL_EXPORTER_OTLP_COMPRESSION=gzip

# タイムアウト（ミリ秒）
export OTEL_EXPORTER_OTLP_TIMEOUT=10000

# ヘッダー（カンマ区切り）
export OTEL_EXPORTER_OTLP_HEADERS="authorization=Bearer token,x-tenant-id=12345"
```

**シグナル別設定（優先される）:**
```bash
# トレース専用エンドポイント
export OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://collector:4317

# メトリクス専用エンドポイント（別サーバー）
export OTEL_EXPORTER_OTLP_METRICS_ENDPOINT=http://metrics-collector:4317

# ログ専用エンドポイント
export OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=http://logs-collector:4317
```

---

## 2. OpenTelemetry Collector

### 2.1 Collectorの概要

**OpenTelemetry Collectorの役割:**
- **受信**: 複数のプロトコルでテレメトリーを受信
- **処理**: データの変換、フィルタリング、集約
- **エクスポート**: 複数のバックエンドへデータを送信

**アーキテクチャ図:**
```
[SDK] --OTLP--> [Receiver] --> [Processor] --> [Exporter] --> [Backend]
                    ↓              ↓              ↓
                 [Extension]   [Extension]   [Extension]
```

### 2.2 ディストリビューション

| ディストリビューション | 用途 | コンポーネント数 |
|------------------|------|----------------|
| **Core** | 本番環境 | 最小限のコンポーネント |
| **Contrib** | 開発/テスト | 100以上のコンポーネント |

**ダウンロード:**
```bash
# Core
wget https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v0.91.0/otelcol_0.91.0_linux_amd64.tar.gz

# Contrib
wget https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v0.91.0/otelcol-contrib_0.91.0_linux_amd64.tar.gz
```

### 2.3 パイプラインコンポーネント

#### レシーバー（Receiver）

**主要なレシーバー:**

| レシーバー | プロトコル | ポート | 用途 |
|----------|----------|--------|------|
| **otlp** | gRPC/HTTP | 4317/4318 | OTLP受信（標準） |
| **prometheus** | HTTP | 9090 | Prometheusメトリクススクレイプ |
| **jaeger** | gRPC/Thrift | 14250/14268 | Jaegerトレース受信 |
| **zipkin** | HTTP | 9411 | Zipkinトレース受信 |
| **filelog** | - | - | ログファイル収集 |
| **hostmetrics** | - | - | ホストメトリクス収集 |

**otlpレシーバー設定例:**
```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318
        cors:
          allowed_origins:
            - "http://localhost:3000"
```

**Prometheusレシーバー設定例:**
```yaml
receivers:
  prometheus:
    config:
      scrape_configs:
        - job_name: 'my-service'
          scrape_interval: 30s
          static_configs:
            - targets: ['localhost:9464']
```

**Filelogレシーバー設定例:**
```yaml
receivers:
  filelog:
    include:
      - /var/log/myapp/*.log
    operators:
      - type: regex_parser
        regex: '^(?P<time>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) \[(?P<level>\w+)\] (?P<message>.*)$'
        timestamp:
          parse_from: attributes.time
          layout: '%Y-%m-%d %H:%M:%S'
```

#### プロセッサー（Processor）

**主要なプロセッサー:**

| プロセッサー | 機能 | 推奨用途 |
|------------|------|---------|
| **batch** | バッチ処理 | 必須（すべてのパイプライン） |
| **memory_limiter** | メモリ制限 | 必須（OOM防止） |
| **attributes** | 属性の追加/削除/変更 | 属性の標準化 |
| **filter** | データフィルタリング | 不要データの除外 |
| **resource** | リソース属性の変更 | 環境情報の追加 |
| **transform** | 高度な変換 | 複雑なデータ変換 |
| **tail_sampling** | テイルサンプリング | ゲートウェイ構成 |

**batchプロセッサー設定例:**
```yaml
processors:
  batch:
    timeout: 10s
    send_batch_size: 1024
    send_batch_max_size: 2048
```

**memory_limiterプロセッサー設定例:**
```yaml
processors:
  memory_limiter:
    check_interval: 1s
    limit_mib: 512
    spike_limit_mib: 128
```

**attributesプロセッサー設定例:**
```yaml
processors:
  attributes:
    actions:
      - key: environment
        value: production
        action: insert
      - key: sensitive_data
        action: delete
      - key: http.url
        action: hash
```

**filterプロセッサー設定例:**
```yaml
processors:
  filter:
    traces:
      span:
        - 'attributes["http.target"] == "/health"'
        - 'attributes["http.target"] == "/readiness"'
```

**resourceプロセッサー設定例:**
```yaml
processors:
  resource:
    attributes:
      - key: cloud.provider
        value: aws
        action: insert
      - key: deployment.environment
        from_attribute: env
        action: insert
```

#### エクスポーター（Exporter）

**主要なエクスポーター:**

| エクスポーター | バックエンド | プロトコル |
|-------------|------------|----------|
| **otlp** | 汎用OTLPバックエンド | gRPC/HTTP |
| **jaeger** | Jaeger | gRPC |
| **zipkin** | Zipkin | HTTP |
| **prometheus** | Prometheus | HTTP（RemoteWrite） |
| **prometheusremotewrite** | Prometheus RemoteWrite | HTTP |
| **logging** | 標準出力 | - |
| **file** | ファイル | - |

**otlpエクスポーター設定例:**
```yaml
exporters:
  otlp:
    endpoint: backend:4317
    compression: gzip
    timeout: 10s
    retry_on_failure:
      enabled: true
      initial_interval: 1s
      max_interval: 30s
      max_elapsed_time: 300s
```

**Jaegerエクスポーター設定例:**
```yaml
exporters:
  jaeger:
    endpoint: jaeger:14250
    tls:
      insecure: false
      cert_file: /certs/cert.pem
      key_file: /certs/key.pem
```

**Prometheus RemoteWriteエクスポーター設定例:**
```yaml
exporters:
  prometheusremotewrite:
    endpoint: http://prometheus:9090/api/v1/write
    tls:
      insecure: true
    external_labels:
      cluster: production
```

**loggingエクスポーター設定例（開発用）:**
```yaml
exporters:
  logging:
    loglevel: debug
    sampling_initial: 5
    sampling_thereafter: 200
```

#### エクステンション（Extension）

**主要なエクステンション:**

| エクステンション | 機能 |
|---------------|------|
| **health_check** | ヘルスチェックエンドポイント |
| **pprof** | Go pprof プロファイリング |
| **zpages** | デバッグ用Webページ |

**health_checkエクステンション設定例:**
```yaml
extensions:
  health_check:
    endpoint: 0.0.0.0:13133
    path: /health
```

**zpagesエクステンション設定例:**
```yaml
extensions:
  zpages:
    endpoint: 0.0.0.0:55679
```

### 2.4 パイプライン設定

**完全な設定例（config.yaml）:**
```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  memory_limiter:
    check_interval: 1s
    limit_mib: 512
    spike_limit_mib: 128

  batch:
    timeout: 10s
    send_batch_size: 1024

  attributes:
    actions:
      - key: environment
        value: production
        action: insert

exporters:
  otlp:
    endpoint: backend:4317
    compression: gzip

  logging:
    loglevel: info

extensions:
  health_check:
    endpoint: 0.0.0.0:13133

service:
  extensions: [health_check]
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch, attributes]
      exporters: [otlp, logging]

    metrics:
      receivers: [otlp]
      processors: [memory_limiter, batch, attributes]
      exporters: [otlp]

    logs:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp]
```

**起動コマンド:**
```bash
./otelcol --config=config.yaml
```

---

## 3. デプロイモデル

### 3.1 デプロイモデル判断テーブル

| モデル | 構成 | メリット | デメリット | 推奨場面 |
|--------|------|---------|-----------|---------|
| **コレクターなし** | SDK → Backend直接 | - シンプル<br>- 低レイテンシ | - 集中管理不可<br>- バックエンド変更時にアプリ再デプロイ<br>- テイルサンプリング不可 | - 小規模環境<br>- PoC/開発環境 |
| **ノードエージェント** | SDK → DaemonSet → Backend | - ログファイル収集可能<br>- ホストメトリクス収集<br>- アプリのオーバーヘッド削減 | - ノードのリソース消費<br>- テイルサンプリング不可 | - Kubernetes標準構成<br>- ログ収集が必要 |
| **サイドカー** | SDK → Sidecar → Backend | - テナント分離<br>- 独立したリソース制限<br>- アプリ固有の処理 | - Podごとのリソース消費<br>- 管理の複雑化 | - マルチテナント環境<br>- 厳格な分離が必要 |
| **ゲートウェイ** | SDK → Gateway → Backend | - テイルサンプリング<br>- 集中管理<br>- データ集約 | - SPOF<br>- ネットワークホップ増加 | - 大規模本番環境<br>- テイルサンプリング必須 |
| **ハイブリッド** | SDK → Agent → Gateway → Backend | - 各レイヤーの利点を統合<br>- 柔軟な処理分散 | - 最も複雑<br>- 運用コスト高 | - エンタープライズ大規模環境 |

### 3.2 コレクターなしモデル

**構成図:**
```
[Application + SDK] --OTLP--> [Backend]
```

**設定例（Java）:**
```java
OtlpGrpcSpanExporter exporter = OtlpGrpcSpanExporter.builder()
    .setEndpoint("https://backend.example.com:4317")
    .build();
```

**適用判断:**
- ✅ アプリケーション数が少ない（<10）
- ✅ バックエンドが変更されない
- ✅ シンプルな構成を優先
- ❌ テイルサンプリングが必要
- ❌ 複数バックエンドへの送信が必要

### 3.3 ノードエージェントモデル

**構成図（Kubernetes）:**
```
[Pod1 + SDK] ─┐
[Pod2 + SDK] ─┼─> [DaemonSet Collector] --OTLP--> [Backend]
[Pod3 + SDK] ─┘
```

**Kubernetes DaemonSet設定例:**
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: otel-collector
  namespace: observability
spec:
  selector:
    matchLabels:
      app: otel-collector
  template:
    metadata:
      labels:
        app: otel-collector
    spec:
      containers:
        - name: otel-collector
          image: otel/opentelemetry-collector-contrib:0.91.0
          ports:
            - containerPort: 4317  # OTLP gRPC
            - containerPort: 4318  # OTLP HTTP
          volumeMounts:
            - name: config
              mountPath: /etc/otel
            - name: varlog
              mountPath: /var/log
              readOnly: true
          env:
            - name: NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
          resources:
            requests:
              memory: "256Mi"
              cpu: "100m"
            limits:
              memory: "512Mi"
              cpu: "200m"
      volumes:
        - name: config
          configMap:
            name: otel-collector-config
        - name: varlog
          hostPath:
            path: /var/log
```

**アプリケーション設定（環境変数）:**
```bash
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
```

**適用判断:**
- ✅ Kubernetes環境
- ✅ ログファイル収集が必要
- ✅ ホストメトリクス収集が必要
- ❌ テイルサンプリングが必要

### 3.4 サイドカーモデル

**構成図（Kubernetes）:**
```
[Pod]
 ├─ [App Container + SDK] --OTLP--> [Sidecar Collector] --OTLP--> [Backend]
```

**Kubernetes Pod設定例:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp
spec:
  containers:
    - name: app
      image: myapp:latest
      env:
        - name: OTEL_EXPORTER_OTLP_ENDPOINT
          value: "http://localhost:4317"

    - name: otel-collector
      image: otel/opentelemetry-collector:0.91.0
      ports:
        - containerPort: 4317
      volumeMounts:
        - name: config
          mountPath: /etc/otel
      resources:
        requests:
          memory: "128Mi"
          cpu: "50m"
        limits:
          memory: "256Mi"
          cpu: "100m"

  volumes:
    - name: config
      configMap:
        name: otel-collector-config
```

**適用判断:**
- ✅ マルチテナント環境
- ✅ テナントごとに異なる処理が必要
- ✅ 厳格なリソース分離が必要
- ❌ リソース消費を最小化したい

### 3.5 ゲートウェイモデル

**構成図（Kubernetes）:**
```
[DaemonSet Agent] ─┐
[DaemonSet Agent] ─┼─> [Gateway Deployment] --OTLP--> [Backend]
[DaemonSet Agent] ─┘
```

**Kubernetes Deployment設定例:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: otel-collector-gateway
  namespace: observability
spec:
  replicas: 3
  selector:
    matchLabels:
      app: otel-collector-gateway
  template:
    metadata:
      labels:
        app: otel-collector-gateway
    spec:
      containers:
        - name: otel-collector
          image: otel/opentelemetry-collector-contrib:0.91.0
          ports:
            - containerPort: 4317
            - containerPort: 4318
          volumeMounts:
            - name: config
              mountPath: /etc/otel
          resources:
            requests:
              memory: "2Gi"
              cpu: "500m"
            limits:
              memory: "4Gi"
              cpu: "1000m"
      volumes:
        - name: config
          configMap:
            name: otel-collector-gateway-config
---
apiVersion: v1
kind: Service
metadata:
  name: otel-collector-gateway
  namespace: observability
spec:
  selector:
    app: otel-collector-gateway
  ports:
    - name: otlp-grpc
      port: 4317
      targetPort: 4317
    - name: otlp-http
      port: 4318
      targetPort: 4318
  type: ClusterIP
```

**ゲートウェイ設定（テイルサンプリング含む）:**
```yaml
processors:
  tail_sampling:
    decision_wait: 10s
    num_traces: 100000
    expected_new_traces_per_sec: 1000
    policies:
      - name: errors
        type: status_code
        status_code:
          status_codes: [ERROR]

      - name: slow
        type: latency
        latency:
          threshold_ms: 500

      - name: probabilistic
        type: probabilistic
        probabilistic:
          sampling_percentage: 10
```

**適用判断:**
- ✅ テイルサンプリングが必要
- ✅ 大規模環境（>100サービス）
- ✅ 複数バックエンドへの送信
- ❌ シンプルさを優先

---

## 4. トレースサンプリング

### 4.1 なぜサンプリングが重要か

**サンプリングの目的:**
- **コスト削減**: ストレージ・転送コストの削減（サンプリングなしでは膨大）
- **パフォーマンス**: SDK/Collectorのオーバーヘッド削減
- **Signal-to-Noise**: 重要なトレースに集中

**サンプリングなしの場合のコスト例:**
- 1秒間に1000リクエスト
- 1トレースあたり10スパン
- 1スパンあたり1KB
- 1日あたり: 1000 * 10 * 1KB * 86400 = 864GB

### 4.2 ヘッドベースサンプリング

**概念:**
- トレース開始時点でサンプリング決定
- すべてのスパンが同じ決定を継承
- SDK側で実装

#### 確率サンプリング（TraceIdRatioBased）

**Javaコード例:**
```java
import io.opentelemetry.sdk.trace.samplers.Sampler;

// 10%のトレースをサンプリング
SdkTracerProvider tracerProvider = SdkTracerProvider.builder()
    .setSampler(Sampler.traceIdRatioBased(0.1))
    .build();
```

**環境変数:**
```bash
export OTEL_TRACES_SAMPLER=traceidratio
export OTEL_TRACES_SAMPLER_ARG=0.1
```

**特徴:**
- ✅ シンプル
- ✅ 低オーバーヘッド
- ✅ 分散トレース全体で一貫
- ❌ エラーや遅延トレースを見逃す可能性

#### 親ベースサンプリング（ParentBased）

**Javaコード例:**
```java
// 親スパンがサンプリングされていれば継続、なければ10%
Sampler sampler = Sampler.parentBasedBuilder(
    Sampler.traceIdRatioBased(0.1)
).build();

SdkTracerProvider tracerProvider = SdkTracerProvider.builder()
    .setSampler(sampler)
    .build();
```

**環境変数:**
```bash
export OTEL_TRACES_SAMPLER=parentbased_traceidratio
export OTEL_TRACES_SAMPLER_ARG=0.1
```

**特徴:**
- ✅ 分散トレースで一貫したサンプリング
- ✅ ルートサービスがサンプリング決定
- ❌ ルートサービスの決定が絶対

#### カスタムサンプラー

**特定の条件でサンプリング:**
```java
import io.opentelemetry.sdk.trace.samplers.Sampler;
import io.opentelemetry.api.common.Attributes;
import io.opentelemetry.sdk.trace.data.LinkData;
import io.opentelemetry.context.Context;

public class CustomSampler implements Sampler {
    private final Sampler defaultSampler = Sampler.traceIdRatioBased(0.1);

    @Override
    public SamplingResult shouldSample(
        Context parentContext,
        String traceId,
        String name,
        SpanKind spanKind,
        Attributes attributes,
        List<LinkData> parentLinks) {

        // エラーは常にサンプリング
        if (attributes.get(AttributeKey.longKey("http.status_code")) >= 400) {
            return SamplingResult.recordAndSample();
        }

        // 特定のエンドポイントは常にサンプリング
        if (attributes.get(AttributeKey.stringKey("http.route")).startsWith("/api/critical")) {
            return SamplingResult.recordAndSample();
        }

        // それ以外はデフォルトサンプラー
        return defaultSampler.shouldSample(parentContext, traceId, name, spanKind, attributes, parentLinks);
    }

    @Override
    public String getDescription() {
        return "CustomSampler";
    }
}
```

### 4.3 テイルベースサンプリング

**概念:**
- トレース完了後にサンプリング決定
- すべてのスパンを一時的にバッファリング
- Collectorゲートウェイで実装

**メリット:**
- ✅ エラー・遅延トレースを確実にキャプチャ
- ✅ ビジネス重要度に基づくサンプリング
- ✅ 柔軟なポリシー

**デメリット:**
- ❌ Collectorのメモリ消費大
- ❌ レイテンシ増加（decision_wait）
- ❌ 複雑な設定

#### テイルサンプリングプロセッサー設定

**基本設定:**
```yaml
processors:
  tail_sampling:
    # トレース完了を待つ時間
    decision_wait: 10s

    # メモリに保持するトレース数
    num_traces: 100000

    # 1秒あたりの新規トレース予測（メモリ計算用）
    expected_new_traces_per_sec: 1000

    policies:
      # 1. エラートレースは100%サンプリング
      - name: errors
        type: status_code
        status_code:
          status_codes: [ERROR]

      # 2. 高レイテンシトレースは100%サンプリング
      - name: slow
        type: latency
        latency:
          threshold_ms: 500

      # 3. 特定の属性を持つトレース
      - name: critical-endpoint
        type: string_attribute
        string_attribute:
          key: http.route
          values:
            - /api/payment
            - /api/checkout

      # 4. 正常トレースは10%
      - name: normal
        type: probabilistic
        probabilistic:
          sampling_percentage: 10
```

**ポリシータイプ:**

| ポリシー | 説明 | 設定例 |
|---------|------|--------|
| **status_code** | スパンステータスでフィルタ | `status_codes: [ERROR]` |
| **latency** | レイテンシ閾値でフィルタ | `threshold_ms: 500` |
| **string_attribute** | 文字列属性でフィルタ | `key: http.route, values: ["/api/payment"]` |
| **numeric_attribute** | 数値属性でフィルタ | `key: http.status_code, min_value: 500` |
| **probabilistic** | 確率的サンプリング | `sampling_percentage: 10` |
| **rate_limiting** | レート制限 | `spans_per_second: 100` |
| **composite** | 複数条件の組み合わせ | `and` / `or` で結合 |

#### 複合ポリシー例

**ANDポリシー（遅延かつエラー）:**
```yaml
policies:
  - name: slow-and-error
    type: composite
    composite:
      max_total_spans_per_second: 1000
      policy_order: [latency-policy, error-policy]
      composite_sub_policy:
        - name: latency-policy
          type: latency
          latency:
            threshold_ms: 500
        - name: error-policy
          type: status_code
          status_code:
            status_codes: [ERROR]
      rate_allocation:
        - policy: latency-policy
          percent: 50
        - policy: error-policy
          percent: 50
```

#### ロードバランシング考慮

**トレースIDベースの一貫したルーティング:**
```yaml
# Kubernetesサービス設定
apiVersion: v1
kind: Service
metadata:
  name: otel-collector-gateway
spec:
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 3600
```

**または、Collectorでloadbalancingエクスポーター使用:**
```yaml
exporters:
  loadbalancing:
    protocol:
      otlp:
        timeout: 1s
    resolver:
      static:
        hostnames:
          - otel-gateway-1:4317
          - otel-gateway-2:4317
          - otel-gateway-3:4317
```

### 4.4 サンプリング戦略判断テーブル

| 戦略 | SDK負荷 | Collector負荷 | エラー検出 | コスト削減 | 推奨ケース |
|------|---------|--------------|-----------|-----------|----------|
| **サンプリングなし** | 高 | 高 | 完璧 | なし | 小規模/開発環境 |
| **ヘッド確率（10%）** | 低 | 低 | 不完全 | 90% | 均一なトラフィック |
| **ヘッドカスタム** | 中 | 低 | 良好 | 70-90% | 既知の重要エンドポイント |
| **テイルベース** | 中 | 高 | 完璧 | 70-95% | 大規模本番環境 |
| **ハイブリッド** | 中 | 中 | 完璧 | 80-95% | エンタープライズ |

**推奨構成:**

| 環境 | トラフィック | 推奨サンプリング |
|------|------------|----------------|
| 開発 | <100 req/s | サンプリングなし |
| ステージング | <1000 req/s | ヘッド確率（50%） |
| 本番（小） | <5000 req/s | ヘッド確率（10%） + カスタム（エラー100%） |
| 本番（大） | >5000 req/s | テイルベース（エラー100%, 遅延100%, 正常10%） |

---

## 5. Kubernetes環境でのベストプラクティス

### 5.1 ノードエージェント + ゲートウェイ構成

**推奨アーキテクチャ:**
```
[Pod + SDK] --> [DaemonSet Agent] --> [Gateway Deployment] --> [Backend]
```

**DaemonSet設定（エージェント）:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: otel-agent-config
  namespace: observability
data:
  config.yaml: |
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317

    processors:
      memory_limiter:
        check_interval: 1s
        limit_mib: 256
        spike_limit_mib: 64

      batch:
        timeout: 1s
        send_batch_size: 256

      resource:
        attributes:
          - key: k8s.node.name
            value: ${NODE_NAME}
            action: insert

    exporters:
      otlp:
        endpoint: otel-collector-gateway.observability.svc.cluster.local:4317

    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [memory_limiter, batch, resource]
          exporters: [otlp]
```

**Gateway設定（テイルサンプリング）:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: otel-gateway-config
  namespace: observability
data:
  config.yaml: |
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317

    processors:
      memory_limiter:
        check_interval: 1s
        limit_mib: 2048
        spike_limit_mib: 512

      tail_sampling:
        decision_wait: 10s
        num_traces: 100000
        expected_new_traces_per_sec: 1000
        policies:
          - name: errors
            type: status_code
            status_code:
              status_codes: [ERROR]
          - name: slow
            type: latency
            latency:
              threshold_ms: 500
          - name: normal
            type: probabilistic
            probabilistic:
              sampling_percentage: 10

      batch:
        timeout: 10s
        send_batch_size: 1024

    exporters:
      otlp:
        endpoint: backend.example.com:4317
        compression: gzip

    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [memory_limiter, tail_sampling, batch]
          exporters: [otlp]
```

### 5.2 Prometheusスクレイプ設定

**メトリクスエンドポイント公開:**
```yaml
# アプリケーションPod
apiVersion: v1
kind: Pod
metadata:
  name: myapp
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "9464"
    prometheus.io/path: "/metrics"
spec:
  containers:
    - name: app
      image: myapp:latest
      ports:
        - name: metrics
          containerPort: 9464
```

**Collector設定（Prometheusレシーバー）:**
```yaml
receivers:
  prometheus:
    config:
      scrape_configs:
        - job_name: 'kubernetes-pods'
          kubernetes_sd_configs:
            - role: pod
          relabel_configs:
            - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
              action: keep
              regex: true
            - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
              action: replace
              target_label: __metrics_path__
              regex: (.+)
            - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
              action: replace
              regex: ([^:]+)(?::\d+)?;(\d+)
              replacement: $1:$2
              target_label: __address__
```

### 5.3 Helmチャートによるデプロイ

**公式Helmチャート使用:**
```bash
# リポジトリ追加
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

# DaemonSetとしてデプロイ
helm install otel-agent open-telemetry/opentelemetry-collector \
  --namespace observability \
  --create-namespace \
  --set mode=daemonset \
  --set image.repository=otel/opentelemetry-collector-contrib \
  --set config.receivers.otlp.protocols.grpc.endpoint="0.0.0.0:4317" \
  --set config.exporters.otlp.endpoint="otel-gateway:4317"

# Deploymentとしてデプロイ（ゲートウェイ）
helm install otel-gateway open-telemetry/opentelemetry-collector \
  --namespace observability \
  --set mode=deployment \
  --set replicaCount=3 \
  --set image.repository=otel/opentelemetry-collector-contrib
```

---

## まとめ

**Collector導入の判断フロー:**
```
小規模環境（<10サービス）？
├─ Yes → コレクターなし
└─ No  → Kubernetes環境？
    ├─ Yes → ログ収集必要？
    │   ├─ Yes → DaemonSet
    │   └─ No  → テイルサンプリング必要？
    │       ├─ Yes → DaemonSet + Gateway
    │       └─ No  → DaemonSet
    └─ No  → テイルサンプリング必要？
        ├─ Yes → Gateway
        └─ No  → ノードエージェント
```

**次のステップ:**
- セマンティック規約の適用 → `SEMANTIC-CONVENTIONS.md`
- 組織導入戦略 → `ADOPTION-STRATEGY.md`
