---
name: implementing-opentelemetry
description: >-
  Guides OpenTelemetry implementation for distributed system observability covering instrumentation API/SDK, Collector deployment, semantic conventions, and organizational adoption.
  Use when implementing tracing, metrics, or logging with OpenTelemetry, configuring OTel Collector pipelines, designing telemetry architecture, or planning OTel adoption across teams.
  Distinct from monitoring/infrastructure skills - focuses specifically on OpenTelemetry ecosystem and observability best practices.
---

# OpenTelemetry実装ガイド

## 概要

OpenTelemetryは、分散システムにおけるオブザーバビリティを実現するための統合フレームワークです。トレース、メトリクス、ログという3つのテレメトリーシグナルを単一の標準化されたアプローチで収集・処理します。

### 核心価値

OpenTelemetryが提供する3つの中核的価値：

1. **相互運用性（Interoperability）**
   - ベンダー中立な標準により、複数のバックエンド（Jaeger、Prometheus、Datadog等）へ同じ計装コードでデータ送信可能
   - 計装とバックエンドを疎結合に保ち、ベンダーロックインを回避

2. **ポータビリティ（Portability）**
   - 言語横断的な共通API仕様により、Java、Python、Go、.NET等で一貫した計装体験
   - 環境変数やCollectorによる実行時設定変更で、コード変更なしにテレメトリー動作をカスタマイズ

3. **ユビキタス計装（Ubiquitous Instrumentation）**
   - ライブラリ・フレームワークレベルでの自動計装により、アプリケーションコード変更を最小化
   - 標準化されたセマンティック規約により、異なるサービス間でも一貫した属性名・構造でテレメトリーを生成

---

## オブザーバビリティの基本

### なぜオブザーバビリティが重要か

現代の分散システムでは、単一サービスの監視だけでは不十分です。以下の理由からオブザーバビリティが必要になります：

- **複雑性の増大**: マイクロサービス、コンテナ、サーバーレスなどの採用により、システム構成要素が増加
- **動的性**: 自動スケーリング、カナリアリリース、カオスエンジニアリングなど、システム状態が常に変化
- **未知の未知**: 事前に予測できない障害シナリオへの対応が必要

### 重要メトリクス: MTTD/MTTK/MTTF/MTTV

障害対応能力を測定する4つの指標：

| 指標 | 意味 | 目的 | OpenTelemetryでの強化 |
|-----|------|------|---------------------|
| **MTTD** (Mean Time To Detect) | 障害検出までの平均時間 | 問題の早期発見 | アラート用メトリクス、異常検知 |
| **MTTK** (Mean Time To Know) | 根本原因特定までの時間 | デバッグ効率化 | 分散トレース、クロスシグナル相関 |
| **MTTF** (Mean Time To Fix) | 修正完了までの時間 | 復旧速度向上 | トレースベースのデバッグ |
| **MTTV** (Mean Time To Verify) | 修正検証までの時間 | 再発防止 | 継続的テレメトリー監視 |

**OpenTelemetryの強み**: MTTDはメトリクスで、MTTKは分散トレースで劇的に改善可能。特にMTTKの短縮（数時間→数分）が開発生産性に直結します。

### コンテキストと相関関係

オブザーバビリティの本質は「コンテキストの保持」です：

- **垂直相関**: 単一サービス内でのトレース→メトリクス→ログの関連付け
- **水平相関**: サービス境界を超えたトレースの伝搬（Context Propagation）
- **時間軸相関**: 過去のテレメトリーと現在のパターンの比較

OpenTelemetryは**Context API**を用いて、トレースID/スパンIDをプロセス内およびプロセス間で自動伝搬します。

---

## シグナル選択ガイド

3つのシグナルの使い分け判断基準：

| シグナル | 適用場面 | データ特性 | コスト | 使用例 |
|---------|---------|-----------|-------|-------|
| **トレース** | 分散トランザクションのデバッグ<br>リクエスト単位のパフォーマンス分析 | 高粒度、短期保存<br>カーディナリティ: 高 | サンプリング必須<br>（1-10%典型） | 「この注文リクエストがなぜ遅い？」<br>「どのサービスがエラーを起こした？」 |
| **メトリクス** | KPI監視、SLI/SLO測定<br>アラート、長期トレンド分析<br>ダッシュボード | 集約済み、長期保存<br>カーディナリティ: 低〜中 | 低（データ量安定） | 「過去1週間のエラー率」<br>「CPU使用率が閾値超過」 |
| **ログ** | レガシー計装との統合<br>バックグラウンドタスク<br>監査・コンプライアンス | 非構造化/半構造化<br>カーディナリティ: 不定 | 中〜高（量次第） | 「cron実行履歴」<br>「セキュリティ監査ログ」 |

### 判断フロー

```
質問1: ユーザーリクエストごとに異なる状態を追跡する必要がある？
 └─ Yes → トレースを使用
 └─ No  → 質問2へ

質問2: リアルタイムアラートが必要？
 └─ Yes → メトリクスを使用
 └─ No  → 質問3へ

質問3: 既存のログ基盤を活用したい？
 └─ Yes → ログを使用（トレース相関を追加推奨）
 └─ No  → メトリクスを使用（コスト最安）
```

**推奨アプローチ**: まずメトリクスでアラート、異常検出したら該当期間のトレースをサンプリングで詳細調査。ログは補完的に使用。

---

## アーキテクチャ概要

### API/SDK分離設計

OpenTelemetryの核心的な設計原則：

```
┌─────────────────────────────────────────┐
│      Application Code                  │
│  ┌──────────────────────────────────┐  │
│  │  OpenTelemetry API (安定)        │  │ ← アプリが直接依存
│  │  - Tracer, Meter, Logger         │  │
│  │  - Context, Propagators          │  │
│  └──────────────────────────────────┘  │
│           ↓ 依存                       │
│  ┌──────────────────────────────────┐  │
│  │  OpenTelemetry SDK (実装)        │  │ ← 環境変数で設定変更可能
│  │  - SpanProcessor, Exporter       │  │
│  │  - MeterProvider, MetricReader   │  │
│  └──────────────────────────────────┘  │
└─────────────────────────────────────────┘
           ↓ OTLPプロトコル
┌─────────────────────────────────────────┐
│   OpenTelemetry Collector (オプション)  │
│  ┌──────────────────────────────────┐  │
│  │  Receivers → Processors          │  │
│  │    ↓                              │  │
│  │  Exporters (Jaeger, Prometheus)  │  │
│  └──────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

**重要ポイント**:
- **API**: 安定保証。アプリケーションはこのレイヤーのみに依存すべき
- **SDK**: 設定可能。環境変数（`OTEL_EXPORTER_OTLP_ENDPOINT`等）でエクスポート先変更
- **Collector**: オプショナル。本番環境では推奨（サンプリング、データ変換、バックプレッシャー対応）

### コンポーネント関係

| コンポーネント | 責務 | 安定性 | 実装例 |
|-------------|------|--------|-------|
| **API** | 計装用インターフェース定義 | 安定（破壊的変更なし） | `Tracer.startSpan()`, `Meter.createCounter()` |
| **SDK** | API実装、データ処理パイプライン | 安定（設定変更は可） | `TracerProvider`, `MeterProvider` |
| **Contrib** | 自動計装、計装ライブラリ | 実験的〜安定 | Spring Boot計装、gRPC計装 |
| **Collector** | テレメトリー中継・変換 | 安定（core）+ 実験的（contrib） | k8s属性追加、テイルベースサンプリング |

---

## コンテキスト伝搬の核心

OpenTelemetryは**Context API**でトレース情報をスレッドローカル/プロセス間で自動伝搬します。

**重要ポイント**:
- `span.makeCurrent()`でコンテキスト有効化（`try-with-resources`必須）
- **W3C TraceContext**がデフォルト推奨（HTTPヘッダー: `traceparent`, `tracestate`）
- **W3C Baggage**でキー・バリューペア伝搬可能（カーディナリティ注意）

```java
Span span = tracer.spanBuilder("myOperation").startSpan();
try (Scope scope = span.makeCurrent()) {
    doSomeWork();  // 子スパンは自動的に親子関係設定
} finally {
    span.end();
}
```

詳細な実装例は`INSTRUMENTATION-API.md`を参照。

---

## クイックスタート判断フロー

### 自動計装 vs 手動計装

**判断基準**:
- **自動計装**: フレームワーク（Spring Boot、Flask等）使用時。コード変更なし
- **手動計装**: ビジネスロジック固有のコンテキスト追加が必要な場合

**自動計装の例（Java）**:
```bash
java -javaagent:opentelemetry-javaagent.jar \
     -Dotel.service.name=my-service \
     -jar myapp.jar
```

**手動計装の例**:
```java
Span span = tracer.spanBuilder("processOrder")
    .setAttribute("order.id", orderId)
    .startSpan();
try (Scope scope = span.makeCurrent()) {
    validateOrder(orderId);
} catch (Exception e) {
    span.recordException(e);
    span.setStatus(StatusCode.ERROR, e.getMessage());
    throw e;
} finally {
    span.end();
}
```

詳細は`INSTRUMENTATION-API.md`参照。

### Collector使用判断

**Collector推奨**: 本番環境、複数バックエンド送信、サンプリング/データ変換が必要な場合

**Collectorのメリット**: バックプレッシャー対応、データ変換、複数バックエンド対応

**不要なケース**: ローカル開発環境、シンプルなモノリシックアプリ

詳細は`COLLECTOR-DEPLOY.md`参照。

---

## ユーザー確認の原則（AskUserQuestion）

以下の判断分岐で**AskUserQuestion**を使用：

### 確認が必要な場面

1. **シグナル選択**: トレース/メトリクス/ログの優先度が曖昧な場合
2. **デプロイモデル**: Collector配置方法（ノードエージェント/サイドカー/ゲートウェイ等）
3. **サンプリング戦略**: 固定確率（1%/10%）vsテイルベースサンプリング
4. **エクスポーター**: バックエンド選択（OTLP/Jaeger/Prometheus/ベンダー固有）

**AskUserQuestion実装例**:
```python
AskUserQuestion(
    questions=[{
        "question": "どのテレメトリーシグナルを優先しますか？",
        "header": "シグナル選択",
        "options": [
            {"label": "トレース優先", "description": "分散トランザクションのデバッグ"},
            {"label": "メトリクス優先", "description": "SLI/SLO監視、アラート、コスト重視"},
            {"label": "ログ統合", "description": "既存ログ基盤活用+トレース相関"},
            {"label": "全シグナル統合", "description": "統一的なオブザーバビリティ"}
        ],
        "multiSelect": False
    }]
)
```

### 確認不要な場面

- **W3C TraceContext**: デフォルト使用（業界標準）
- **セマンティック規約**: 必ず適用（`http.request.method`, `http.response.status_code`等）
- **service.name属性**: 必須設定

---

## 計装の基本原則

### 1. API/SDK分離
- アプリは`opentelemetry-api`のみに依存（安定保証）
- SDKは実行時に環境変数で切り替え可能

### 2. セマンティック規約
- 必須: `service.name`, `http.request.method`, `http.response.status_code`
- カーディナリティ管理: `/users/123` → `/users/{id}`
- 詳細は`SEMANTIC-CONVENTIONS.md`参照

### 3. エラー処理
```java
try (Scope scope = span.makeCurrent()) {
    processPayment();
    span.setStatus(StatusCode.OK);
} catch (Exception e) {
    span.recordException(e);
    span.setStatus(StatusCode.ERROR, e.getMessage());  // 両方必須
    throw e;
} finally {
    span.end();
}
```

---

## 詳細リファレンス

### サブファイル参照

| ファイル | 内容 | 使用場面 |
|---------|------|----------|
| **INSTRUMENTATION-API.md** | トレース/メトリクス/ログAPI詳細、リソースSDK | 手動計装実装時、カスタム属性追加時 |
| **COLLECTOR-DEPLOY.md** | OTLPプロトコル、Collectorアーキテクチャ、デプロイモデル、サンプリング | Collector設定時、本番デプロイ時 |
| **SEMANTIC-CONVENTIONS.md** | リソース/トレース/メトリクス規約、テレメトリースキーマ | 属性命名時、クロスチーム統一時 |
| **ADOPTION-STRATEGY.md** | 導入判断、テレメトリー整備チーム、移行パス、コスト管理 | 組織導入計画時、ROI評価時 |

### 推奨学習パス

1. **初学者**: SKILL.md → INSTRUMENTATION-API.md（トレースのみ）→ 自動計装で試す
2. **実装担当**: SKILL.md → INSTRUMENTATION-API.md → SEMANTIC-CONVENTIONS.md
3. **運用担当**: SKILL.md → COLLECTOR-DEPLOY.md → SEMANTIC-CONVENTIONS.md
4. **導入責任者**: SKILL.md → ADOPTION-STRATEGY.md → 全ファイル

---

## まとめ

OpenTelemetryを効果的に導入するための重要ポイント：

1. **シグナル選択**: 目的に応じてトレース/メトリクス/ログを使い分け
2. **API/SDK分離**: アプリはAPIのみに依存、設定はSDKで柔軟に変更
3. **コンテキスト伝搬**: W3C TraceContextで分散トレース実現
4. **セマンティック規約**: 標準属性名を使用し、相互運用性確保
5. **Collector活用**: 本番環境では推奨。サンプリング・変換・バックプレッシャー対応
6. **段階的導入**: 自動計装から開始、必要に応じて手動計装を追加

次のステップ: 自分の役割に応じて上記「詳細リファレンス」のサブファイルを参照してください。
