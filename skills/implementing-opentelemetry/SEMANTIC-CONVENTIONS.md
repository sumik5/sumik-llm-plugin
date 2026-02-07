# セマンティック規約（Semantic Conventions）

## 概要

セマンティック規約は、OpenTelemetryにおける「命名のルールブック」です。トレース、メトリクス、ログの属性名・値の標準化により、以下を実現します：

- **相関関係の構築**: 異なるサービス・言語で生成されたテレメトリーを統一的に検索・分析
- **認知負荷の低減**: チーム間で同じ属性名を使用することで、ドキュメント参照が不要に
- **ツール統合の簡易化**: ダッシュボード・アラートテンプレートを再利用可能

**重要原則**: セマンティック規約は「推奨」ではなく「必須」として扱うべきです。独自の命名規則は相互運用性を損ないます。

---

## なぜ命名規則が重要か

### 問題事例: 命名規則がない場合

```java
// サービスA（チームX）
span.setAttribute("request_method", "GET");
span.setAttribute("status", 200);

// サービスB（チームY）
span.setAttribute("http.verb", "GET");
span.setAttribute("http_status_code", "200");
```

**影響**:
- 統一クエリが書けない（`request_method` OR `http.verb`？）
- ダッシュボード重複作成（チームごとに別々）
- 属性のデータ型不一致（`200` vs `"200"`）

### 解決: セマンティック規約を適用

```java
// すべてのサービスで統一
span.setAttribute("http.request.method", "GET");  // 文字列
span.setAttribute("http.response.status_code", 200);  // 整数
```

---

## リソース規約（Resource Conventions）

リソースは「テレメトリーを生成するエンティティ」を表します。すべてのスパン・メトリクス・ログに自動的に付与されるため、一度設定すれば全シグナルで共通化されます。

### 必須属性

| 属性名 | 説明 | 例 | 必須度 |
|--------|------|-----|--------|
| `service.name` | サービス名（論理的な名前） | `order-service` | **必須** |
| `service.namespace` | サービスのグループ化（テナント、環境等） | `production`, `tenant-123` | 強く推奨 |
| `service.instance.id` | サービスインスタンスの一意ID | `pod-abc123`, `i-0e12345` | 推奨 |
| `service.version` | サービスバージョン | `1.2.3`, `commit-abc123` | 推奨 |

### 実装例（Java）

```java
import io.opentelemetry.sdk.resources.Resource;
import io.opentelemetry.semconv.ResourceAttributes;

Resource resource = Resource.getDefault().toBuilder()
    .put(ResourceAttributes.SERVICE_NAME, "order-service")
    .put(ResourceAttributes.SERVICE_NAMESPACE, "production")
    .put(ResourceAttributes.SERVICE_INSTANCE_ID, System.getenv("HOSTNAME"))
    .put(ResourceAttributes.SERVICE_VERSION, "1.2.3")
    .put(ResourceAttributes.DEPLOYMENT_ENVIRONMENT, "production")
    .build();

SdkTracerProvider tracerProvider = SdkTracerProvider.builder()
    .setResource(resource)
    .build();
```

### クラウド規約

| 属性名 | 説明 | 例 |
|--------|------|-----|
| `cloud.provider` | クラウドプロバイダー | `aws`, `gcp`, `azure` |
| `cloud.region` | リージョン | `us-east-1`, `asia-northeast1` |
| `cloud.account.id` | アカウントID | `123456789012` |
| `cloud.availability_zone` | AZ | `us-east-1a` |

### コンテナ規約

| 属性名 | 説明 | 例 |
|--------|------|-----|
| `container.name` | コンテナ名 | `order-service-container` |
| `container.id` | コンテナID | `abc123def456...` |
| `container.image.name` | イメージ名 | `myregistry/order-service` |
| `container.image.tag` | イメージタグ | `1.2.3`, `latest` |

### Kubernetes規約

| 属性名 | 説明 | 例 |
|--------|------|-----|
| `k8s.namespace.name` | K8s Namespace | `production`, `staging` |
| `k8s.pod.name` | Pod名 | `order-service-abc123` |
| `k8s.deployment.name` | Deployment名 | `order-service` |
| `k8s.node.name` | ノード名 | `node-1` |

**自動検出**: OpenTelemetry SDKはクラウド/K8s環境を自動検出し、これらの属性を自動設定します。環境変数`OTEL_RESOURCE_ATTRIBUTES`でも設定可能：

```bash
export OTEL_RESOURCE_ATTRIBUTES="service.name=order-service,deployment.environment=production"
```

---

## トレース規約（Trace Conventions）

### スパン名設計原則

**ルール**:
1. **低カーディナリティ**: パラメータを含めない
   - ❌ `/users/12345/orders/67890`
   - ✅ `GET /users/{userId}/orders/{orderId}`
2. **意味のある名前**: 操作を明確に表現
   - ❌ `doWork`, `handleRequest`
   - ✅ `HTTP GET`, `processPayment`, `database query`
3. **SpanKindに応じた命名**:
   - `CLIENT`: `HTTP GET`, `gRPC my.service.Method`
   - `SERVER`: `HTTP POST /api/orders`, `message receive`
   - `PRODUCER`: `message send`, `kafka produce`
   - `CONSUMER`: `message process`, `kafka consume`
   - `INTERNAL`: `processPayment`, `validateOrder`

### HTTP規約

#### リクエスト属性

| 属性名 | 型 | 例 | 説明 |
|--------|------|-----|------|
| `http.request.method` | string | `GET`, `POST` | HTTPメソッド（大文字） |
| `url.full` | string | `https://api.example.com/users?id=123` | フルURL（**注意**: カーディナリティ高） |
| `url.path` | string | `/users` | URLパス（パラメータ除く） |
| `url.query` | string | `id=123&sort=asc` | クエリ文字列（**注意**: カーディナリティ高） |
| `server.address` | string | `api.example.com` | サーバーホスト |
| `server.port` | int | `443` | サーバーポート |
| `http.request.header.<name>` | string | `http.request.header.user-agent` | リクエストヘッダー（小文字化） |

#### レスポンス属性

| 属性名 | 型 | 例 | 説明 |
|--------|------|-----|------|
| `http.response.status_code` | int | `200`, `404`, `500` | HTTPステータスコード |
| `http.response.header.<name>` | string | `http.response.header.content-type` | レスポンスヘッダー |

#### 実装例

```java
import io.opentelemetry.api.trace.Span;
import io.opentelemetry.api.trace.SpanKind;
import io.opentelemetry.semconv.SemanticAttributes;

Span span = tracer.spanBuilder("GET /api/orders")
    .setSpanKind(SpanKind.SERVER)
    .startSpan();

try (Scope scope = span.makeCurrent()) {
    // 必須属性
    span.setAttribute(SemanticAttributes.HTTP_REQUEST_METHOD, "GET");
    span.setAttribute(SemanticAttributes.URL_PATH, "/api/orders");
    span.setAttribute(SemanticAttributes.SERVER_ADDRESS, "api.example.com");
    span.setAttribute(SemanticAttributes.SERVER_PORT, 443);

    // 処理後
    span.setAttribute(SemanticAttributes.HTTP_RESPONSE_STATUS_CODE, 200);
    span.setStatus(StatusCode.OK);
} finally {
    span.end();
}
```

**カーディナリティの注意**:
- `url.query`や`url.full`を含めるとカーディナリティが爆発的に増加
- 代わりに`url.path`を使用し、パスパラメータは`{userId}`等のプレースホルダーに置換

### データベース規約

| 属性名 | 型 | 例 | 説明 |
|--------|------|-----|------|
| `db.system` | string | `postgresql`, `mysql`, `redis` | DB種別 |
| `db.name` | string | `customers` | データベース名 |
| `db.statement` | string | `SELECT * FROM users WHERE id = ?` | クエリ（**注意**: サニタイズ） |
| `db.operation` | string | `SELECT`, `INSERT`, `UPDATE` | 操作種別 |
| `server.address` | string | `db.example.com` | DBサーバーアドレス |
| `server.port` | int | `5432` | DBポート |

**重要**: `db.statement`には実際の値を含めず、プレースホルダーを使用：
- ❌ `SELECT * FROM users WHERE id = 12345`
- ✅ `SELECT * FROM users WHERE id = ?`

### RPC規約

| 属性名 | 型 | 例 | 説明 |
|--------|------|-----|------|
| `rpc.system` | string | `grpc`, `java_rmi` | RPC種別 |
| `rpc.service` | string | `myapp.OrderService` | サービス名（完全修飾） |
| `rpc.method` | string | `CreateOrder` | メソッド名 |
| `server.address` | string | `api.example.com` | サーバーアドレス |
| `server.port` | int | `50051` | サーバーポート |

### SpanKind（スパン種別）

| SpanKind | 用途 | 例 |
|----------|------|-----|
| `CLIENT` | アウトバウンドリクエスト送信側 | HTTPクライアント、gRPCクライアント、DBクエリ |
| `SERVER` | インバウンドリクエスト受信側 | HTTPサーバー、gRPCサーバー |
| `PRODUCER` | メッセージ送信（非同期） | Kafka Producer、SQS送信 |
| `CONSUMER` | メッセージ受信（非同期） | Kafka Consumer、SQS受信 |
| `INTERNAL` | 内部処理（プロセス内） | ビジネスロジック、ヘルパー関数 |

**重要**: SpanKindを正しく設定しないと、分散トレースの親子関係が正しく構築されません。

```java
// HTTPクライアント（下流サービスへのリクエスト）
Span clientSpan = tracer.spanBuilder("GET /downstream")
    .setSpanKind(SpanKind.CLIENT)  // 必須
    .startSpan();

// HTTPサーバー（リクエスト受信）
Span serverSpan = tracer.spanBuilder("GET /api/orders")
    .setSpanKind(SpanKind.SERVER)  // 必須
    .startSpan();
```

---

## メトリクス規約（Metric Conventions）

### 命名ガイド

**構造**: `{namespace}.{name}[.{unit}]`

**ルール**:
1. **階層構造**: ドット区切りで論理的にグループ化
   - ✅ `http.server.request.duration`
   - ❌ `http_server_request_duration` (アンダースコア非推奨)
2. **単位を名前に含めない**: 単位はメタデータで指定
   - ❌ `http.request.duration_ms`
   - ✅ `http.request.duration` (単位: `ms`)
3. **複数形を避ける**: 集約されることを前提
   - ❌ `http.requests`
   - ✅ `http.request.count`
4. **低カーディナリティ**: 属性の組み合わせが爆発的に増加しないよう注意

### HTTP メトリクス規約

| メトリクス名 | 型 | 単位 | 説明 | 必須属性 |
|------------|------|------|------|----------|
| `http.server.request.duration` | Histogram | `ms` | リクエスト処理時間 | `http.request.method`, `http.response.status_code`, `url.path` |
| `http.server.request.count` | Counter | `{request}` | リクエスト数 | 同上 |
| `http.server.active_requests` | UpDownCounter | `{request}` | 同時処理数 | 同上 |

### データベース メトリクス規約

| メトリクス名 | 型 | 単位 | 説明 | 必須属性 |
|------------|------|------|------|----------|
| `db.client.operation.duration` | Histogram | `ms` | クエリ実行時間 | `db.system`, `db.operation` |
| `db.client.connections.usage` | UpDownCounter | `{connection}` | アクティブ接続数 | `db.system`, `server.address` |

### 実装例

```java
import io.opentelemetry.api.metrics.Meter;
import io.opentelemetry.api.metrics.LongCounter;
import io.opentelemetry.api.metrics.DoubleHistogram;
import io.opentelemetry.semconv.SemanticAttributes;

public class HttpMetrics {
    private final LongCounter requestCounter;
    private final DoubleHistogram requestDuration;

    public HttpMetrics(Meter meter) {
        // カウンター: リクエスト数
        this.requestCounter = meter.counterBuilder("http.server.request.count")
            .setDescription("Total HTTP requests")
            .setUnit("{request}")
            .build();

        // ヒストグラム: リクエスト処理時間
        this.requestDuration = meter.histogramBuilder("http.server.request.duration")
            .setDescription("HTTP request duration")
            .setUnit("ms")
            .build();
    }

    public void recordRequest(String method, int statusCode, String path, double durationMs) {
        // 共通属性を使用
        Attributes attributes = Attributes.of(
            SemanticAttributes.HTTP_REQUEST_METHOD, method,
            SemanticAttributes.HTTP_RESPONSE_STATUS_CODE, statusCode,
            SemanticAttributes.URL_PATH, path
        );

        requestCounter.add(1, attributes);
        requestDuration.record(durationMs, attributes);
    }
}
```

### カーディナリティ管理（重要）

**問題**: 属性の組み合わせが多すぎるとバックエンドが処理できなくなる

```java
// ❌ 悪い例: カーディナリティ爆発
span.setAttribute("user.id", "12345");  // 数百万通り
span.setAttribute("url.full", "https://api.example.com/users/12345?timestamp=1234567890");  // 無限

// ✅ 良い例: 低カーディナリティ
span.setAttribute("http.request.method", "GET");  // 9通り（GET, POST等）
span.setAttribute("http.response.status_code", 200);  // 約60通り（HTTPステータスコード）
span.setAttribute("url.path", "/users/{userId}");  // 数十〜数百通り（エンドポイント数）
```

**判断基準テーブル**:

| 属性 | カーディナリティ | トレース | メトリクス |
|------|-----------------|---------|-----------|
| `user.id` | 高（数百万） | ⚠️ 許容（サンプリング前提） | ❌ 禁止 |
| `url.full` | 極高（無限） | ❌ 禁止 | ❌ 禁止 |
| `url.path` | 中（数十〜数百） | ✅ 推奨 | ✅ 推奨 |
| `http.response.status_code` | 低（約60） | ✅ 推奨 | ✅ 推奨 |
| `http.request.method` | 極低（9） | ✅ 推奨 | ✅ 推奨 |

**ルール**:
- **トレース**: サンプリング前提なので中カーディナリティまで許容
- **メトリクス**: 100%収集されるため低カーディナリティ必須（目安: 属性組み合わせで1万通り以下）

---

## ログ規約（Log Conventions）

### ログ属性

| 属性名 | 型 | 例 | 説明 |
|--------|------|-----|------|
| `log.level` | string | `INFO`, `ERROR`, `DEBUG` | ログレベル |
| `log.logger.name` | string | `com.example.OrderService` | ロガー名（通常はクラス名） |
| `log.message` | string | `Order processed successfully` | ログメッセージ |
| `log.file.name` | string | `OrderService.java` | ソースファイル名 |
| `log.file.line` | int | `42` | ソースファイル行番号 |

### 例外（Exception）規約

| 属性名 | 型 | 例 | 説明 |
|--------|------|-----|------|
| `exception.type` | string | `java.lang.NullPointerException` | 例外クラス名（完全修飾） |
| `exception.message` | string | `User not found` | 例外メッセージ |
| `exception.stacktrace` | string | `at com.example...` | スタックトレース全文 |

### イベント規約

| 属性名 | 型 | 例 | 説明 |
|--------|------|-----|------|
| `event.domain` | string | `browser`, `device` | イベントのドメイン |
| `event.name` | string | `click`, `page.load` | イベント名 |

### トレース相関

ログとトレースを相関させるための必須属性：

| 属性名 | 型 | 説明 |
|--------|------|------|
| `trace_id` | string | トレースID（16進数、32文字） |
| `span_id` | string | スパンID（16進数、16文字） |
| `trace_flags` | string | トレースフラグ（サンプリング状態等） |

**実装例（Logback + OpenTelemetry）**:

```xml
<!-- logback.xml -->
<configuration>
    <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
        <encoder>
            <pattern>%d{HH:mm:ss.SSS} [%thread] %-5level %logger{36} trace_id=%X{trace_id} span_id=%X{span_id} - %msg%n</pattern>
        </encoder>
    </appender>

    <appender name="OTEL" class="io.opentelemetry.instrumentation.logback.appender.v1_0.OpenTelemetryAppender">
        <captureExperimentalAttributes>true</captureExperimentalAttributes>
        <captureCodeAttributes>true</captureCodeAttributes>
    </appender>

    <root level="INFO">
        <appender-ref ref="CONSOLE" />
        <appender-ref ref="OTEL" />
    </root>
</configuration>
```

**結果**:
```
14:32:15.123 [http-nio-8080-exec-1] INFO  com.example.OrderService trace_id=abc123def456... span_id=789ghi... - Order processed successfully
```

---

## テレメトリースキーマ（Telemetry Schema）

### 目的

セマンティック規約はバージョンアップにより変更される可能性があります。例：
- 1.20.0: `http.method` → 1.21.0: `http.request.method`

テレメトリースキーマは、異なるバージョン間でテレメトリーを変換するための仕組みです。

### schema_url の設定

```java
import io.opentelemetry.sdk.resources.Resource;
import io.opentelemetry.semconv.SchemaUrls;

Resource resource = Resource.getDefault().toBuilder()
    .put(ResourceAttributes.SERVICE_NAME, "order-service")
    .setSchemaUrl(SchemaUrls.V1_24_0)  // セマンティック規約バージョンを明示
    .build();
```

**推奨**: 常に最新の安定版スキーマURLを使用してください。古いバージョンから新バージョンへの自動変換がサポートされます。

### バージョン間変換

Collectorの`schematransform`プロセッサーを使用：

```yaml
processors:
  schematransform:
    # 1.20.0 → 1.21.0 への変換
    transformations:
      - from: https://opentelemetry.io/schemas/1.20.0
        to: https://opentelemetry.io/schemas/1.21.0
        mappings:
          - from: http.method
            to: http.request.method
          - from: http.status_code
            to: http.response.status_code

service:
  pipelines:
    traces:
      processors: [schematransform]
```

---

## カーディナリティ管理の実践

### 属性追加時のチェックリスト

新しい属性を追加する前に必ず確認：

| 質問 | 許容条件 | 禁止条件 |
|------|---------|---------|
| この属性の値は何通りあるか？ | <1000（トレース）<br><100（メトリクス） | >10000（トレース）<br>>1000（メトリクス） |
| セマンティック規約に定義されているか？ | ✅ 定義済み | ⚠️ カスタム属性の場合、チームで標準化 |
| 他の属性と組み合わせた場合の総数は？ | <10000 | >100000 |
| ユーザーID/セッションID等の一意識別子か？ | トレースのみ許容 | メトリクスでは禁止 |

### 高カーディナリティ属性の対処

**問題**: ユーザーIDを属性に含めたい

```java
// ❌ 悪い例: メトリクスで高カーディナリティ
meter.counterBuilder("orders.count")
    .build()
    .add(1, Attributes.of(
        AttributeKey.stringKey("user.id"), "12345"  // 数百万通り
    ));
```

**解決策1**: トレースでのみ記録

```java
// ✅ 良い例: トレースで記録（サンプリング前提）
span.setAttribute("user.id", "12345");
```

**解決策2**: エグザンプラーを使用

```java
// ✅ 良い例: メトリクスの集約データ + サンプルトレースへのリンク
// エグザンプラーにより、特定のトレースIDへリンク可能
DoubleHistogram histogram = meter.histogramBuilder("http.server.request.duration")
    .build();

histogram.record(123.45, Attributes.of(
    SemanticAttributes.HTTP_REQUEST_METHOD, "GET",
    SemanticAttributes.HTTP_RESPONSE_STATUS_CODE, 200
    // user.id はトレースで記録、エグザンプラーで関連付け
));
```

**解決策3**: 属性を一般化

```java
// ✅ 良い例: カーディナリティを下げる
// user.id = "12345" → user.tier = "premium"
span.setAttribute("user.tier", getUserTier(userId));  // 値は "free", "premium", "enterprise" の3通り
```

---

## AskUserQuestion: セマンティック規約の適用判断

ほとんどの場面でセマンティック規約は自動的に適用すべきですが、以下の場合はユーザーに確認：

### カスタム属性の追加判断

```python
from claude_code import AskUserQuestion

AskUserQuestion(
    questions=[{
        "question": "セマンティック規約に存在しないカスタム属性を追加します。命名規則を選択してください",
        "header": "カスタム属性の命名",
        "options": [
            {
                "label": "組織標準プレフィックス使用",
                "description": "例: mycompany.order.priority（チーム間で統一）"
            },
            {
                "label": "セマンティック規約拡張提案",
                "description": "OpenTelemetry仕様へのコントリビューションを検討"
            },
            {
                "label": "一時的な属性として追加",
                "description": "temp.* プレフィックスで将来的な見直し前提"
            }
        ],
        "multiSelect": False
    }]
)
```

### 高カーディナリティ属性の扱い

```python
AskUserQuestion(
    questions=[{
        "question": "高カーディナリティ属性（user.id等）をどう扱いますか？",
        "header": "カーディナリティ管理",
        "options": [
            {
                "label": "トレースのみで記録",
                "description": "サンプリング前提。メトリクスには含めない"
            },
            {
                "label": "エグザンプラーで関連付け",
                "description": "メトリクスの集約データからサンプルトレースへリンク"
            },
            {
                "label": "属性を一般化",
                "description": "user.id → user.tier（カーディナリティを下げる）"
            },
            {
                "label": "記録しない",
                "description": "プライバシー・カーディナリティの観点から除外"
            }
        ],
        "multiSelect": False
    }]
)
```

---

## まとめ

セマンティック規約の重要ポイント：

1. **リソース規約**: `service.name`は必須。`service.namespace`, `service.version`も強く推奨
2. **トレース規約**: スパン名は低カーディナリティ。SpanKindを正しく設定
3. **メトリクス規約**: 命名は階層構造。カーディナリティ管理が最重要
4. **ログ規約**: トレース相関（`trace_id`, `span_id`）を必ず含める
5. **カーディナリティ**: 属性追加時は必ずチェックリストで確認
6. **schema_url**: セマンティック規約バージョンを明示し、将来の互換性を確保

**次のステップ**: `INSTRUMENTATION-API.md`で実際のAPI使用方法を学習、または`COLLECTOR-DEPLOY.md`でCollectorによるデータ変換を実践してください。
