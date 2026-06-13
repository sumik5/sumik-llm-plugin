# OpenTelemetry 計装API/SDK実践ガイド

OpenTelemetryの計装API/SDKを使用した実践的なトレース・メトリクス・ログの実装方法を解説します。

---

## 1. リソースSDK

### 1.1 Resourceの概念

**Resource**はテレメトリー生成元を識別する情報（サービス名、ホスト名、プロセスID等）を保持する不変オブジェクトです。

**基本原則:**
- Resourceは作成後変更できない（イミュータブル）
- 複数のResourceは `merge()` で結合可能（重複キーは上書き）
- SDKは自動的にデフォルトResourceを提供

### 1.2 リソース属性の設定

**Javaコード例:**
```java
import io.opentelemetry.api.common.Attributes;
import io.opentelemetry.sdk.resources.Resource;
import io.opentelemetry.semconv.ResourceAttributes;

Resource resource = Resource.getDefault().merge(
    Resource.create(Attributes.of(
        ResourceAttributes.SERVICE_NAME, "my-service",
        ResourceAttributes.SERVICE_VERSION, "1.0.0",
        ResourceAttributes.DEPLOYMENT_ENVIRONMENT, "production"
    ))
);
```

### 1.3 リソースプロバイダー

OpenTelemetry SDKは以下のリソースプロバイダーを自動的に使用します：

| プロバイダー | 提供する属性 |
|------------|------------|
| **OsResource** | os.type, os.description |
| **HostResource** | host.name, host.arch |
| **ProcessResource** | process.pid, process.executable.name |
| **ProcessRuntimeResource** | process.runtime.name, process.runtime.version |

### 1.4 環境変数による設定

**推奨される設定方法:**
```bash
# サービス名（最重要）
export OTEL_SERVICE_NAME=my-service

# 追加のリソース属性（カンマ区切り）
export OTEL_RESOURCE_ATTRIBUTES="deployment.environment=production,service.version=1.0.0"
```

**優先順位:**
1. コードで明示的に設定したResource
2. 環境変数 `OTEL_RESOURCE_ATTRIBUTES`
3. 環境変数 `OTEL_SERVICE_NAME`
4. リソースプロバイダーによる自動検出

---

## 2. 自動計装（ゼロコード計装）

### 2.1 自動計装のモデル

| モデル | 説明 | 導入方法 |
|--------|------|---------|
| **ゼロタッチ** | コード変更不要 | エージェント/サイドカー |
| **実装モデル** | コードでAPI呼び出し | SDK依存ライブラリ追加 |

### 2.2 Javaエージェントによる自動計装

**起動コマンド:**
```bash
java -javaagent:/path/to/opentelemetry-javaagent.jar \
     -Dotel.service.name=my-service \
     -Dotel.traces.exporter=otlp \
     -Dotel.metrics.exporter=otlp \
     -Dotel.exporter.otlp.endpoint=http://collector:4317 \
     -jar myapp.jar
```

**設定の優先順位（高い順）:**
1. システムプロパティ（`-Dotel.*`）
2. 環境変数（`OTEL_*`）
3. 設定ファイル（`otel.properties`）
4. デフォルト値

### 2.3 エクステンションによるカスタマイズ

**Java SPIによるエクステンション:**
```java
import io.opentelemetry.sdk.autoconfigure.spi.AutoConfigurationCustomizer;
import io.opentelemetry.sdk.autoconfigure.spi.AutoConfigurationCustomizerProvider;

public class CustomConfigProvider implements AutoConfigurationCustomizerProvider {
    @Override
    public void customize(AutoConfigurationCustomizer autoConfiguration) {
        autoConfiguration
            .addTracerProviderCustomizer((sdkTracerProviderBuilder, configProperties) -> {
                // TracerProviderのカスタマイズ
                return sdkTracerProviderBuilder
                    .addSpanProcessor(new CustomSpanProcessor());
            })
            .addResourceCustomizer((resource, configProperties) -> {
                // Resourceの追加
                return resource.merge(Resource.create(
                    Attributes.of(AttributeKey.stringKey("custom.key"), "value")
                ));
            });
    }
}
```

**`META-INF/services` に登録:**
```
# META-INF/services/io.opentelemetry.sdk.autoconfigure.spi.AutoConfigurationCustomizerProvider
com.example.CustomConfigProvider
```

### 2.4 計装の選択的無効化

**特定のライブラリの計装を無効化:**
```bash
# JDBCの計装を無効化
export OTEL_INSTRUMENTATION_JDBC_ENABLED=false

# 複数の計装を無効化
export OTEL_INSTRUMENTATION_SPRING_WEBMVC_ENABLED=false
export OTEL_INSTRUMENTATION_NETTY_ENABLED=false
```

### 2.5 リソース属性の最適化

**本番環境での推奨設定:**
```bash
# 自動検出されるリソースプロバイダーを制限
export OTEL_RESOURCE_PROVIDERS=os,host,process

# 不要な属性を削除（カーディナリティ削減）
export OTEL_RESOURCE_ATTRIBUTES_EXCLUDE=process.command_args
```

---

## 3. トレースAPI

### 3.1 TracerProviderとTracerの初期化

**Javaコード例:**
```java
import io.opentelemetry.api.OpenTelemetry;
import io.opentelemetry.api.trace.Tracer;
import io.opentelemetry.api.trace.TracerProvider;
import io.opentelemetry.sdk.OpenTelemetrySdk;
import io.opentelemetry.sdk.trace.SdkTracerProvider;

// SDKの初期化（通常は1回のみ）
SdkTracerProvider tracerProvider = SdkTracerProvider.builder()
    .addSpanProcessor(/* プロセッサーの設定 */)
    .build();

OpenTelemetry openTelemetry = OpenTelemetrySdk.builder()
    .setTracerProvider(tracerProvider)
    .build();

// Tracerの取得
Tracer tracer = openTelemetry.getTracer("my-instrumentation-library", "1.0.0");
```

### 3.2 スパンの作成と管理

**基本的なスパン作成:**
```java
import io.opentelemetry.api.trace.Span;
import io.opentelemetry.context.Scope;

Span span = tracer.spanBuilder("operation-name")
    .setSpanKind(SpanKind.SERVER)
    .startSpan();

try (Scope scope = span.makeCurrent()) {
    // スパンのスコープ内での処理
    // このスレッド内で作成される新しいスパンは自動的に親子関係が設定される
    doWork();
} catch (Exception e) {
    span.recordException(e);
    span.setStatus(StatusCode.ERROR, "Operation failed");
    throw e;
} finally {
    span.end();
}
```

**try-with-resourcesパターン（推奨）:**
```java
Span span = tracer.spanBuilder("operation-name").startSpan();
try (Scope scope = span.makeCurrent()) {
    doWork();
} finally {
    span.end();
}
```

### 3.3 スパンのプロパティ

#### SpanKind（スパンの種類）

| SpanKind | 用途 | 使用例 |
|----------|------|--------|
| **INTERNAL** | 内部処理 | ビジネスロジック、計算処理 |
| **SERVER** | サーバー処理 | HTTP/gRPCリクエスト受信 |
| **CLIENT** | クライアント処理 | HTTP/gRPCリクエスト送信、DB呼び出し |
| **PRODUCER** | メッセージ送信 | Kafka/RabbitMQ メッセージ送信 |
| **CONSUMER** | メッセージ受信 | Kafka/RabbitMQ メッセージ受信 |

**SpanKind設定例:**
```java
Span span = tracer.spanBuilder("GET /users/:id")
    .setSpanKind(SpanKind.SERVER)
    .startSpan();
```

#### 属性（Attributes）

**属性の追加:**
```java
import io.opentelemetry.api.common.AttributeKey;
import io.opentelemetry.api.common.Attributes;

Span span = tracer.spanBuilder("database-query").startSpan();
span.setAttribute("db.system", "postgresql");
span.setAttribute("db.statement", "SELECT * FROM users WHERE id = ?");
span.setAttribute(AttributeKey.longKey("db.rows_affected"), 1L);
span.setAttribute(AttributeKey.booleanKey("cache.hit"), false);
```

**属性設計のベストプラクティス:**
- セマンティック規約に従う（`db.*`, `http.*`, `messaging.*`）
- カーディナリティに注意（ユーザーIDなど高カーディナリティ値は慎重に）
- 属性値は不変かつプリミティブ型（String, Long, Double, Boolean）

#### リンク（Links）

**スパン間の因果関係を表現:**
```java
import io.opentelemetry.api.trace.SpanContext;

SpanContext linkedContext = /* 別のスパンのコンテキスト */;

Span span = tracer.spanBuilder("batch-processing")
    .addLink(linkedContext)
    .addLink(anotherContext, Attributes.of(
        AttributeKey.stringKey("link.type"), "dependency"
    ))
    .startSpan();
```

**リンクのユースケース:**
- バッチ処理が複数のリクエストトレースに関連
- メッセージングで複数のプロデューサーからのメッセージを集約
- 分散トランザクションでの複数サービス間の関連

#### イベント（Events）

**スパン内の時系列イベント記録:**
```java
import io.opentelemetry.api.common.Attributes;

span.addEvent("cache-miss");
span.addEvent("retry-attempt", Attributes.of(
    AttributeKey.longKey("retry.count"), 2L,
    AttributeKey.stringKey("retry.reason"), "timeout"
));
```

**イベントのユースケース:**
- リトライの記録
- キャッシュミス/ヒットの記録
- ステートマシンの状態遷移

#### ステータス（Status）

**スパンの成否を明示:**
```java
import io.opentelemetry.api.trace.StatusCode;

// 成功（デフォルト）
span.setStatus(StatusCode.OK);

// エラー
span.setStatus(StatusCode.ERROR, "Database connection timeout");

// 未設定（デフォルト値）
span.setStatus(StatusCode.UNSET);
```

**ステータス設定の判断:**
- `OK`: 明示的な成功（通常は設定不要）
- `ERROR`: エラーが発生した場合（必須）
- `UNSET`: ステータスが不明確な場合（デフォルト）

### 3.4 エラーと例外の記録

**例外の記録:**
```java
try {
    riskyOperation();
} catch (Exception e) {
    span.recordException(e);
    span.setStatus(StatusCode.ERROR, e.getMessage());
    throw e;
}
```

**例外記録の内部動作:**
- イベントとして記録（`exception` イベント）
- 自動的に以下の属性を追加:
  - `exception.type`: 例外クラス名
  - `exception.message`: 例外メッセージ
  - `exception.stacktrace`: スタックトレース

### 3.5 非同期タスクのトレース

**Context伝搬パターン:**
```java
import io.opentelemetry.context.Context;

Span parentSpan = tracer.spanBuilder("parent-operation").startSpan();
try (Scope scope = parentSpan.makeCurrent()) {

    // Contextをキャプチャ
    Context context = Context.current();

    // 非同期タスク
    CompletableFuture.supplyAsync(() -> {
        // Contextを復元
        try (Scope asyncScope = context.makeCurrent()) {
            Span childSpan = tracer.spanBuilder("async-operation").startSpan();
            try {
                return doAsyncWork();
            } finally {
                childSpan.end();
            }
        }
    });

} finally {
    parentSpan.end();
}
```

**wrapSupplierパターン（推奨）:**
```java
Context context = Context.current();

CompletableFuture.supplyAsync(
    context.wrapSupplier(() -> {
        Span span = tracer.spanBuilder("async-operation").startSpan();
        try (Scope scope = span.makeCurrent()) {
            return doAsyncWork();
        } finally {
            span.end();
        }
    })
);
```

### 3.6 ファイア・アンド・フォーゲットパターン

**親スパンを持たない非同期タスク:**
```java
SpanContext originalContext = Span.current().getSpanContext();

CompletableFuture.runAsync(() -> {
    Span span = tracer.spanBuilder("fire-and-forget")
        .setNoParent()  // 親スパンを設定しない
        .addLink(originalContext)  // 代わりにリンクで関連を保持
        .startSpan();

    try (Scope scope = span.makeCurrent()) {
        doBackgroundWork();
    } finally {
        span.end();
    }
});
```

**使用例:**
- 監査ログの非同期記録
- メトリクス集計のバックグラウンド処理
- 通知送信

---

## 4. トレースSDK

### 4.1 TracerProviderの設定

**完全な設定例:**
```java
import io.opentelemetry.sdk.trace.SdkTracerProvider;
import io.opentelemetry.sdk.trace.samplers.Sampler;
import io.opentelemetry.sdk.trace.SpanLimits;
import io.opentelemetry.sdk.trace.IdGenerator;

SdkTracerProvider tracerProvider = SdkTracerProvider.builder()
    // サンプラー
    .setSampler(Sampler.parentBasedBuilder(Sampler.traceIdRatioBased(0.1)).build())

    // スパン制限
    .setSpanLimits(SpanLimits.builder()
        .setMaxNumberOfAttributes(128)
        .setMaxNumberOfEvents(128)
        .setMaxNumberOfLinks(128)
        .setMaxAttributeValueLength(4096)
        .build())

    // IDジェネレーター
    .setIdGenerator(IdGenerator.random())

    // リソース
    .setResource(resource)

    // スパンプロセッサー
    .addSpanProcessor(spanProcessor)

    .build();
```

### 4.2 スパンプロセッサー

#### BatchSpanProcessor（推奨）

**設定例:**
```java
import io.opentelemetry.sdk.trace.export.BatchSpanProcessor;
import io.opentelemetry.exporter.otlp.trace.OtlpGrpcSpanExporter;

OtlpGrpcSpanExporter exporter = OtlpGrpcSpanExporter.builder()
    .setEndpoint("http://collector:4317")
    .build();

BatchSpanProcessor processor = BatchSpanProcessor.builder(exporter)
    .setMaxQueueSize(2048)              // キューの最大サイズ
    .setMaxExportBatchSize(512)         // 1回のエクスポートバッチサイズ
    .setScheduleDelay(5000)             // エクスポート間隔（ミリ秒）
    .setExporterTimeout(30000)          // エクスポートタイムアウト（ミリ秒）
    .build();

tracerProvider.addSpanProcessor(processor);
```

**BatchSpanProcessorのパラメータ判断:**

| パラメータ | デフォルト | 低遅延 | 高スループット |
|-----------|----------|--------|---------------|
| maxQueueSize | 2048 | 512 | 8192 |
| maxExportBatchSize | 512 | 128 | 2048 |
| scheduleDelay (ms) | 5000 | 1000 | 10000 |
| exporterTimeout (ms) | 30000 | 10000 | 60000 |

#### SimpleSpanProcessor（開発用）

**即座にエクスポート（本番環境非推奨）:**
```java
import io.opentelemetry.sdk.trace.export.SimpleSpanProcessor;

SimpleSpanProcessor processor = SimpleSpanProcessor.create(exporter);
tracerProvider.addSpanProcessor(processor);
```

**使用例:**
- ローカル開発環境
- デバッグ
- テスト環境

### 4.3 スパンエクスポーター

#### OtlpGrpcSpanExporter（推奨）

```java
OtlpGrpcSpanExporter exporter = OtlpGrpcSpanExporter.builder()
    .setEndpoint("http://collector:4317")
    .setCompression("gzip")
    .setTimeout(10, TimeUnit.SECONDS)
    .build();
```

#### その他のエクスポーター

| エクスポーター | 用途 | 設定例 |
|-------------|------|--------|
| **OtlpHttpSpanExporter** | HTTP/Protobuf | `.setEndpoint("http://collector:4318/v1/traces")` |
| **JaegerGrpcSpanExporter** | Jaeger直接送信 | `.setEndpoint("http://jaeger:14250")` |
| **ZipkinSpanExporter** | Zipkin互換 | `.setEndpoint("http://zipkin:9411/api/v2/spans")` |
| **LoggingSpanExporter** | ログ出力（開発用） | `LoggingSpanExporter.create()` |

**エクスポーター選択ガイド:**
- **本番環境**: OtlpGrpcSpanExporter + Collector（標準）
- **開発環境**: LoggingSpanExporter
- **レガシー統合**: JaegerGrpcSpanExporter, ZipkinSpanExporter

---

## 5. メトリクスAPI

### 5.1 MeterProviderとMeterの初期化

**Javaコード例:**
```java
import io.opentelemetry.api.OpenTelemetry;
import io.opentelemetry.api.metrics.Meter;
import io.opentelemetry.api.metrics.MeterProvider;
import io.opentelemetry.sdk.OpenTelemetrySdk;
import io.opentelemetry.sdk.metrics.SdkMeterProvider;

SdkMeterProvider meterProvider = SdkMeterProvider.builder()
    .registerMetricReader(/* MetricReader */)
    .build();

OpenTelemetry openTelemetry = OpenTelemetrySdk.builder()
    .setMeterProvider(meterProvider)
    .build();

Meter meter = openTelemetry.getMeter("my-instrumentation-library", "1.0.0");
```

### 5.2 計装型の選択

**計装型判断テーブル:**

| 計装型 | 同期/非同期 | 単調性 | 集約方法 | ユースケース |
|--------|-----------|--------|---------|------------|
| **Counter** | 同期 | 単調増加のみ | 合計 | リクエスト処理数、販売数、バイト送信数 |
| **ObservableCounter** | 非同期 | 単調増加のみ | 合計 | GC回数、CPU時間、プロセス起動回数 |
| **Histogram** | 同期 | 任意 | 分布 | 応答時間、ペイロードサイズ、データベースクエリ時間 |
| **UpDownCounter** | 同期 | 増減可能 | 合計 | キュー内アイテム数、接続数変化 |
| **ObservableUpDownCounter** | 非同期 | 増減可能 | 最後の値 | メモリ使用量、スレッドプール活性スレッド数 |
| **ObservableGauge** | 非同期 | 任意 | 最後の値 | CPU温度、CPU使用率、現在のスレッド数 |

**選択フローチャート:**
```
測定値は単調増加のみ？
├─ Yes → 同期的に測定？
│   ├─ Yes → Counter
│   └─ No  → ObservableCounter
│
└─ No  → 分布の把握が必要？
    ├─ Yes → Histogram
    └─ No  → 同期的に測定？
        ├─ Yes → UpDownCounter
        └─ No  → 増減可能？
            ├─ Yes → ObservableUpDownCounter
            └─ No  → ObservableGauge
```

### 5.3 Counter（同期カウンター）

**基本的な使用:**
```java
import io.opentelemetry.api.metrics.LongCounter;

LongCounter requestCounter = meter.counterBuilder("http.server.requests")
    .setDescription("Total number of HTTP requests")
    .setUnit("requests")
    .build();

// リクエスト処理時
requestCounter.add(1, Attributes.of(
    AttributeKey.stringKey("http.method"), "GET",
    AttributeKey.stringKey("http.route"), "/users/:id",
    AttributeKey.longKey("http.status_code"), 200L
));
```

**浮動小数点カウンター:**
```java
import io.opentelemetry.api.metrics.DoubleCounter;

DoubleCounter revenueCounter = meter.counterBuilder("store.revenue")
    .ofDoubles()
    .setDescription("Total revenue in USD")
    .setUnit("USD")
    .build();

revenueCounter.add(99.99, Attributes.of(
    AttributeKey.stringKey("product.category"), "electronics"
));
```

### 5.4 ObservableCounter（非同期カウンター）

**システムメトリクスの収集:**
```java
import io.opentelemetry.api.metrics.ObservableLongCounter;
import java.lang.management.ManagementFactory;
import java.lang.management.GarbageCollectorMXBean;

meter.counterBuilder("jvm.gc.count")
    .setDescription("Total number of GC collections")
    .setUnit("collections")
    .buildWithCallback(measurement -> {
        for (GarbageCollectorMXBean gc : ManagementFactory.getGarbageCollectorMXBeans()) {
            measurement.record(gc.getCollectionCount(), Attributes.of(
                AttributeKey.stringKey("gc.name"), gc.getName()
            ));
        }
    });
```

### 5.5 Histogram（ヒストグラム）

**応答時間の測定:**
```java
import io.opentelemetry.api.metrics.DoubleHistogram;

DoubleHistogram responseTimeHistogram = meter.histogramBuilder("http.server.duration")
    .setDescription("HTTP server response time")
    .setUnit("ms")
    .build();

// リクエスト処理
long startTime = System.currentTimeMillis();
try {
    processRequest();
} finally {
    long duration = System.currentTimeMillis() - startTime;
    responseTimeHistogram.record(duration, Attributes.of(
        AttributeKey.stringKey("http.method"), "GET",
        AttributeKey.stringKey("http.route"), "/api/users",
        AttributeKey.longKey("http.status_code"), 200L
    ));
}
```

**ペイロードサイズの測定:**
```java
LongHistogram payloadSizeHistogram = meter.histogramBuilder("http.server.request.size")
    .ofLongs()
    .setDescription("HTTP request payload size")
    .setUnit("bytes")
    .build();

payloadSizeHistogram.record(request.getContentLength(), Attributes.of(
    AttributeKey.stringKey("http.route"), "/api/upload"
));
```

### 5.6 UpDownCounter（増減カウンター）

**キュー内アイテム数の追跡:**
```java
import io.opentelemetry.api.metrics.LongUpDownCounter;

LongUpDownCounter queueSizeCounter = meter.upDownCounterBuilder("queue.items")
    .setDescription("Number of items in the queue")
    .setUnit("items")
    .build();

// アイテム追加時
queueSizeCounter.add(1, Attributes.of(
    AttributeKey.stringKey("queue.name"), "orders"
));

// アイテム取り出し時
queueSizeCounter.add(-1, Attributes.of(
    AttributeKey.stringKey("queue.name"), "orders"
));
```

### 5.7 ObservableUpDownCounter（非同期増減カウンター）

**メモリ使用量の監視:**
```java
meter.upDownCounterBuilder("jvm.memory.used")
    .setDescription("Used JVM memory")
    .setUnit("bytes")
    .buildWithCallback(measurement -> {
        long used = Runtime.getRuntime().totalMemory() - Runtime.getRuntime().freeMemory();
        measurement.record(used, Attributes.of(
            AttributeKey.stringKey("memory.type"), "heap"
        ));
    });
```

### 5.8 ObservableGauge（非同期ゲージ）

**CPU使用率の監視:**
```java
import java.lang.management.ManagementFactory;
import com.sun.management.OperatingSystemMXBean;

meter.gaugeBuilder("system.cpu.usage")
    .setDescription("System CPU usage")
    .setUnit("percent")
    .buildWithCallback(measurement -> {
        OperatingSystemMXBean osBean = (OperatingSystemMXBean)
            ManagementFactory.getOperatingSystemMXBean();
        measurement.record(osBean.getSystemCpuLoad() * 100);
    });
```

**スレッドプールの監視:**
```java
import java.util.concurrent.ThreadPoolExecutor;

ThreadPoolExecutor executor = /* ... */;

meter.gaugeBuilder("threadpool.threads.active")
    .setDescription("Number of active threads")
    .setUnit("threads")
    .ofLongs()
    .buildWithCallback(measurement -> {
        measurement.record(executor.getActiveCount(), Attributes.of(
            AttributeKey.stringKey("pool.name"), "worker-pool"
        ));
    });
```

---

## 6. メトリクスSDK

### 6.1 集約タイプ

**デフォルトの集約:**

| 計装型 | デフォルト集約 |
|--------|--------------|
| Counter | 合計（Sum） |
| ObservableCounter | 合計（Sum） |
| Histogram | 明示的バケットヒストグラム |
| UpDownCounter | 合計（Sum） |
| ObservableUpDownCounter | 最後の値（LastValue） |
| ObservableGauge | 最後の値（LastValue） |

**集約タイプの詳細:**

| 集約 | 説明 | 用途 |
|------|------|------|
| **Sum** | 測定値の合計 | Counter, UpDownCounter |
| **LastValue** | 最後に観測された値 | Gauge, ObservableUpDownCounter |
| **ExplicitBucketHistogram** | 固定バケット境界のヒストグラム | レイテンシ、サイズ分布 |
| **ExponentialHistogram** | 指数関数的バケット境界 | 広範囲な分布（高解像度） |

### 6.2 ビュー（View）

**ビューの目的:**
- カーディナリティの制御
- 属性のフィルタリング/集約
- 集約方法の変更
- メトリクス名の変更

**カーディナリティ削減例:**
```java
import io.opentelemetry.sdk.metrics.InstrumentSelector;
import io.opentelemetry.sdk.metrics.View;
import io.opentelemetry.sdk.metrics.Aggregation;

SdkMeterProvider meterProvider = SdkMeterProvider.builder()
    .registerView(
        InstrumentSelector.builder()
            .setName("http.server.duration")
            .build(),
        View.builder()
            .setAggregation(Aggregation.explicitBucketHistogram(
                Arrays.asList(0.0, 5.0, 10.0, 25.0, 50.0, 100.0, 250.0, 500.0, 1000.0)
            ))
            // 高カーディナリティ属性を除外
            .setAttributeFilter(key -> !key.getKey().equals("http.target"))
            .build()
    )
    .build();
```

**属性集約例（URLパスの汎化）:**
```java
meterProvider.registerView(
    InstrumentSelector.builder()
        .setName("http.server.requests")
        .build(),
    View.builder()
        // http.target を http.route に置き換え
        .setAttributeFilter(key -> !key.getKey().equals("http.target"))
        .build()
);
```

**指数ヒストグラムへの変更:**
```java
meterProvider.registerView(
    InstrumentSelector.builder()
        .setName("http.server.duration")
        .build(),
    View.builder()
        .setAggregation(Aggregation.base2ExponentialBucketHistogram(20, 160))
        .build()
);
```

### 6.3 イグザンプラー（Exemplar）

**イグザンプラーの目的:**
- メトリクスとトレースの相関
- 異常値のトレースIDを記録
- 高レイテンシリクエストの詳細調査

**設定例:**
```java
import io.opentelemetry.sdk.metrics.export.PeriodicMetricReader;

PeriodicMetricReader metricReader = PeriodicMetricReader.builder(exporter)
    .setInterval(60, TimeUnit.SECONDS)
    .build();

SdkMeterProvider meterProvider = SdkMeterProvider.builder()
    .registerMetricReader(metricReader)
    .setExemplarFilter(ExemplarFilter.traceBased())  // トレースベースのイグザンプラー
    .build();
```

**イグザンプラーフィルター:**

| フィルター | 説明 | 推奨ケース |
|----------|------|----------|
| **traceBased()** | サンプリングされたトレースのみ | 本番環境（デフォルト） |
| **alwaysOn()** | すべての測定値 | 開発環境 |
| **alwaysOff()** | イグザンプラー無効 | 低オーバーヘッド環境 |

### 6.4 MetricReader

#### PeriodicMetricReader（プッシュモデル）

```java
import io.opentelemetry.exporter.otlp.metrics.OtlpGrpcMetricExporter;

OtlpGrpcMetricExporter exporter = OtlpGrpcMetricExporter.builder()
    .setEndpoint("http://collector:4317")
    .build();

PeriodicMetricReader metricReader = PeriodicMetricReader.builder(exporter)
    .setInterval(60, TimeUnit.SECONDS)
    .build();

SdkMeterProvider meterProvider = SdkMeterProvider.builder()
    .registerMetricReader(metricReader)
    .build();
```

#### PrometheusHttpServer（プルモデル）

```java
import io.opentelemetry.exporter.prometheus.PrometheusHttpServer;

PrometheusHttpServer prometheusServer = PrometheusHttpServer.builder()
    .setHost("0.0.0.0")
    .setPort(9464)
    .build();

SdkMeterProvider meterProvider = SdkMeterProvider.builder()
    .registerMetricReader(prometheusServer)
    .build();
```

**MetricReader選択ガイド:**

| Reader | モデル | 用途 | 設定 |
|--------|--------|------|------|
| **PeriodicMetricReader** | プッシュ | OTLP、Datadog等 | エクスポート間隔設定 |
| **PrometheusHttpServer** | プル | Prometheus | HTTPポート設定 |

### 6.5 集約テンポラリティ

**テンポラリティの種類:**

| テンポラリティ | 説明 | 適用先 |
|------------|------|--------|
| **累積（Cumulative）** | プログラム開始からの累積値 | Prometheus |
| **差分（Delta）** | 前回エクスポートからの差分 | OTLP、Datadog |

**設定例:**
```java
import io.opentelemetry.sdk.metrics.export.AggregationTemporality;

OtlpGrpcMetricExporter exporter = OtlpGrpcMetricExporter.builder()
    .setEndpoint("http://collector:4317")
    .setAggregationTemporalitySelector(type -> {
        if (type == InstrumentType.COUNTER || type == InstrumentType.HISTOGRAM) {
            return AggregationTemporality.DELTA;
        }
        return AggregationTemporality.CUMULATIVE;
    })
    .build();
```

---

## 7. ログAPI/SDK

### 7.1 Logging APIの位置づけ

**重要な前提:**
- Logging APIは**バックエンドAPI**（ログアペンダー等が使用）
- アプリケーションコードから直接使用することは推奨されない
- 既存のログフレームワーク（SLF4J, Log4j, Logback等）を使用し、OpenTelemetryアペンダーで統合

### 7.2 Events APIインターフェイス

**Events APIの概念:**
- ログの構造化表現
- トレースコンテキストの自動付加
- セマンティック規約に準拠

**将来的な使用例（実験的）:**
```java
import io.opentelemetry.api.logs.Logger;
import io.opentelemetry.api.common.Attributes;

Logger logger = openTelemetry.getLogsBridge().get("my-instrumentation");

logger.logRecordBuilder()
    .setSeverity(Severity.INFO)
    .setBody("User login successful")
    .setAttributes(Attributes.of(
        AttributeKey.stringKey("user.id"), "12345",
        AttributeKey.stringKey("user.role"), "admin"
    ))
    .emit();
```

### 7.3 既存ログフレームワークとの統合

#### SLF4J + Logback統合

**依存関係追加:**
```xml
<dependency>
    <groupId>io.opentelemetry.instrumentation</groupId>
    <artifactId>opentelemetry-logback-appender-1.0</artifactId>
</dependency>
```

**Logback設定（logback.xml）:**
```xml
<configuration>
    <appender name="OTEL" class="io.opentelemetry.instrumentation.logback.appender.v1_0.OpenTelemetryAppender">
        <captureExperimentalAttributes>true</captureExperimentalAttributes>
        <captureKeyValuePairAttributes>true</captureKeyValuePairAttributes>
    </appender>

    <root level="INFO">
        <appender-ref ref="OTEL"/>
    </root>
</configuration>
```

**アプリケーションコード:**
```java
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

Logger logger = LoggerFactory.getLogger(MyClass.class);

// トレースコンテキストは自動的に付加される
logger.info("Processing order: {}", orderId);
logger.error("Order processing failed", exception);
```

#### Log4j2統合

**依存関係追加:**
```xml
<dependency>
    <groupId>io.opentelemetry.instrumentation</groupId>
    <artifactId>opentelemetry-log4j-appender-2.17</artifactId>
</dependency>
```

**Log4j2設定（log4j2.xml）:**
```xml
<Configuration packages="io.opentelemetry.instrumentation.log4j.appender.v2_17">
    <Appenders>
        <OpenTelemetry name="OTEL"/>
    </Appenders>

    <Loggers>
        <Root level="info">
            <AppenderRef ref="OTEL"/>
        </Root>
    </Loggers>
</Configuration>
```

### 7.4 トレースコンテキストの自動付加

**自動的に追加される属性:**
- `trace_id`: 現在のトレースID
- `span_id`: 現在のスパンID
- `trace_flags`: トレースフラグ（サンプリング状態等）

**ログとトレースの相関:**
```
[INFO] 2024-01-15 10:23:45 [trace_id=4bf92f3577b34da6a3ce929d0e0e4736 span_id=00f067aa0ba902b7] Processing order: 12345
```

**相関によるメリット:**
- ログからトレースへのジャンプ
- トレースからログの検索
- 分散トレースとログの統合デバッグ

---

## まとめ

**計装実装の基本フロー:**
1. **リソース設定**: サービス名、環境、バージョンを設定
2. **自動計装の検討**: 既存ライブラリの自動計装を活用
3. **手動計装の追加**: ビジネスロジックに固有のトレース/メトリクスを追加
4. **SDK設定**: プロセッサー、エクスポーター、サンプリング戦略を設定
5. **ログ統合**: 既存ログフレームワークにOpenTelemetryアペンダーを追加

**次のステップ:**
- セマンティック規約の適用 → `SEMANTIC-CONVENTIONS.md`
- Collector設定とデプロイ → `COLLECTOR-DEPLOY.md`
- 組織導入戦略 → `ADOPTION-STRATEGY.md`
