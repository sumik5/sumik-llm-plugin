# オブザーバビリティ実装ガイド

監視設計・OpenTelemetry実装・ログ設計の統合ガイド。
監視戦略の策定からテレメトリーシグナルの実装、ログ基盤の構築まで網羅する。

---

## 監視設計

### 監視のアンチパターン（5つを避ける）

| アンチパターン | 説明 | 対策 |
|--------------|------|------|
| **1. ツール依存** | 単一ツールで全て解決できるという誤解 | 組み合わせ可能な監視（Composable Monitoring）を採用 |
| **2. 役割としての監視** | 「監視専任チーム」を作り開発者は責任を持たない | 開発者全員の責務にする |
| **3. チェックボックス監視** | OSメトリクスだけでアラートを出す | 「動いている」の定義を明確にし、ユーザー視点で監視 |
| **4. 監視を支えにする** | 壊れやすいアプリを監視でカバーしようとする | アプリケーションの品質を向上させる |
| **5. 手動設定** | クラウド環境で手動でホスト登録・設定更新 | サービスディスカバリと自動設定を採用 |

### 監視のデザインパターン（4つ）

| パターン | 説明 | 主なメリット |
|---------|------|------------|
| **1. 組み合わせ可能な監視** | データ収集・メトリクス・ログ・可視化・アラートを個別コンポーネントとして組み合わせ | 柔軟性、拡張性 |
| **2. ユーザ視点での監視** | ユーザーに最も近いところ（LB等）から監視を始め下流へ | ユーザー影響を即座に検知 |
| **3. 作るのではなく買う** | SaaS監視を推奨（コスト・専門性・フォーカスの観点） | コスト削減、専門知見活用 |
| **4. 継続的改善** | 最初は完璧でなくてよい。継続的に改善し続ける | 段階的な改善、学習と適応 |

### レイヤー別監視戦略（6レイヤー）

| レイヤー | 監視対象 | 主な目的 |
|---------|---------|---------|
| **1. ビジネス監視** | ビジネスKPI（売上、コンバージョン率等） | ビジネス価値と技術指標を紐付ける |
| **2. フロントエンド監視** | ブラウザパフォーマンス、ユーザー体験 | 遅いアプリケーションのコストを可視化 |
| **3. アプリケーション監視** | アプリケーションコード、API | コードの動作状況、エラー率を追跡 |
| **4. サーバ監視** | OS、Web/DB/LB/MQ/Cache/DNS | インフラの健全性、リソース使用率 |
| **5. ネットワーク監視** | SNMP、フロー監視 | ネットワークの可用性、帯域幅 |
| **6. セキュリティ監視** | auditd、HIDS/NIDS | 侵入検知、監査対応 |

### テレメトリーパイプライン概要

```
[Production Systems]
        ↓
[Emitting Stage]  テレメトリーを発信（ログファイル、Syslog、標準出力）
        ↓
[Shipping Stage]  テレメトリーを移送・格納（フォーマット統一、エンリッチメント）
        ↓
[Presentation Stage]  テレメトリーを表示（グラフ・ダッシュボード・アラート）
```

### ユーザー確認が必要な場面

- **監視ツールの選定方針**: SaaS（Datadog等）vs OSS（Prometheus+Grafana）vs ハイブリッド
- **SaaS vs 自社構築**: コスト（SaaS: 月額$6,000〜）vs 専門人件費（年間$150,000以上）
- **アラート通知方法**: PagerDuty/VictorOps（推奨）vs Slack vs メール

**詳細**: [MONITORING-STRATEGY.md](./references/MONITORING-STRATEGY.md), [MONITORING-OPERATIONS.md](./references/MONITORING-OPERATIONS.md), [MONITORING-TELEMETRY-PIPELINE.md](./references/MONITORING-TELEMETRY-PIPELINE.md), [MONITORING-OBSERVABILITY.md](./references/MONITORING-OBSERVABILITY.md), [MONITORING-SLO-RELIABILITY.md](./references/MONITORING-SLO-RELIABILITY.md)

---

## OpenTelemetry実装

### シグナル選択ガイド

| シグナル | 適用場面 | コスト | 使用例 |
|---------|---------|-------|-------|
| **トレース** | 分散トランザクションのデバッグ | サンプリング必須（1-10%典型） | 「この注文リクエストがなぜ遅い？」 |
| **メトリクス** | KPI監視、SLI/SLO測定、アラート | 低（データ量安定） | 「過去1週間のエラー率」 |
| **ログ** | レガシー計装統合、監査・コンプライアンス | 中〜高（量次第） | 「cron実行履歴」 |

**判断フロー**:
```
ユーザーリクエストごとに異なる状態を追跡？ → Yes: トレース
リアルタイムアラートが必要？ → Yes: メトリクス
既存のログ基盤を活用したい？ → Yes: ログ（トレース相関を追加推奨）
それ以外 → メトリクス（コスト最安）
```

### アーキテクチャ概要（API/SDK分離設計）

```
┌─────────────────────────────────┐
│   Application Code              │
│  ┌───────────────────────────┐  │
│  │  OpenTelemetry API (安定) │  │ ← アプリが直接依存
│  └───────────────────────────┘  │
│           ↓ 依存                │
│  ┌───────────────────────────┐  │
│  │  OpenTelemetry SDK (実装) │  │ ← 環境変数で設定変更可能
│  └───────────────────────────┘  │
└─────────────────────────────────┘
           ↓ OTLPプロトコル
┌─────────────────────────────────┐
│   OpenTelemetry Collector       │
│  Receivers → Processors → Exporters (Jaeger, Prometheus)
└─────────────────────────────────┘
```

### 計装の基本原則

1. **API/SDK分離**: アプリは`opentelemetry-api`のみに依存（安定保証）
2. **セマンティック規約**: 必須属性 `service.name`, `http.request.method`, `http.response.status_code`
3. **エラー処理**: `span.recordException(e)` と `span.setStatus(StatusCode.ERROR)` の両方必須
4. **コンテキスト伝搬**: W3C TraceContext がデフォルト推奨（HTTPヘッダー: `traceparent`）

### Collector使用判断

| 状況 | 推奨 |
|------|------|
| 本番環境、複数バックエンド送信が必要 | **Collector推奨** |
| サンプリング/データ変換が必要 | **Collector推奨** |
| ローカル開発環境、シンプルなモノリシック | Collectorなしでも可 |

**詳細**: [OTEL-INSTRUMENTATION-API.md](./references/OTEL-INSTRUMENTATION-API.md), [OTEL-COLLECTOR-DEPLOY.md](./references/OTEL-COLLECTOR-DEPLOY.md), [OTEL-SEMANTIC-CONVENTIONS.md](./references/OTEL-SEMANTIC-CONVENTIONS.md), [OTEL-ADOPTION-STRATEGY.md](./references/OTEL-ADOPTION-STRATEGY.md)

---

## ログ設計・実装

### ログ設計原則（5W1H）

```
When  （いつ）   : タイムスタンプ（ISO 8601 / Unix時間）
Where （どこで）  : サーバーID・サービス名・コンポーネント名
Who   （誰が）   : ユーザーID・セッションID・IPアドレス
What  （何を）   : 操作内容・リソース名・変更前後の値
Why   （なぜ）   : エラーコード・原因区分
How   （どのように）: 処理結果・レスポンスコード・実行時間
```

### ログに記録してはいけない情報（必須遵守）

```
❌ パスワード・秘密鍵・APIキー
❌ クレジットカード番号（PCI DSS）
❌ 氏名・住所・電話番号（個人情報保護法・GDPR）
❌ マイナンバー・パスポート番号
❌ 医療情報
```

### ログレベル設計（syslog標準）

| レベル | 数値 | 使用場面 |
|--------|------|----------|
| emerg  | 0    | システム全体が使用不能 |
| crit   | 2    | ハードウェア障害など深刻な障害 |
| err    | 3    | エラー（処理続行は可能） |
| warning| 4    | 警告（注意が必要だが処理は継続） |
| info   | 6    | 一般的な情報 |
| debug  | 7    | デバッグ用詳細情報（本番では無効化） |

### 構造化ログ実装（JSON形式）

```json
{
  "timestamp": "2025-07-10T09:00:00+00:00",
  "level": "ERROR",
  "service": "payment-api",
  "message": "決済処理失敗: タイムアウト",
  "user_id": "u123",
  "request_id": "req-abc-456"
}
```

**構造化ログのメリット**: フィールド単位で検索可能、集約・分析が容易、正規表現が不要。

### ログ収集アーキテクチャ

| 規模 | 推奨構成 |
|------|---------|
| 小規模 | rsyslog / journald |
| 中・大規模 | Fluentd → Elasticsearch + S3 |

### ログ保管ポリシー（主要規制）

| 規制・標準 | 保管期間 | 対象 |
|-----------|---------|------|
| PCI DSS   | 1年（直近3ヶ月はオンライン） | カード決済関連 |
| FISC      | 3〜7年 | 金融機関 |
| GDPR      | 目的達成後速やかに削除 | EU居住者の個人データ |
| 医療情報  | 最低5年 | 医療機関 |

### 実装チェックリスト

#### 開発時
- [ ] 5W1H を含む構造化ログ（JSON）を実装した
- [ ] 機密情報（パスワード・カード番号等）をマスクしている
- [ ] ログレベルを環境変数で切り替えられるようにした
- [ ] request_id / correlation_id でリクエストを追跡できる

#### 運用時
- [ ] logrotate でローテーションを設定した
- [ ] 保管ポリシー（規制要件）を満たしている
- [ ] 異常検知ルールの閾値を定期的に見直している

**詳細**: [LOGGING-COLLECTION.md](./references/LOGGING-COLLECTION.md), [LOGGING-ANALYSIS.md](./references/LOGGING-ANALYSIS.md), [LOGGING-SECURITY-COMPLIANCE.md](./references/LOGGING-SECURITY-COMPLIANCE.md), [LOGGING-AI-ANALYSIS.md](./references/LOGGING-AI-ANALYSIS.md)

---

## 詳細ガイド

### 監視設計 references/

| ファイル | 内容 |
|---------|------|
| [MONITORING-STRATEGY.md](./references/MONITORING-STRATEGY.md) | レイヤー別監視戦略（ビジネス〜セキュリティ） |
| [MONITORING-OPERATIONS.md](./references/MONITORING-OPERATIONS.md) | アラート設計、オンコール運用、インシデント管理 |
| [MONITORING-TELEMETRY-PIPELINE.md](./references/MONITORING-TELEMETRY-PIPELINE.md) | Emit/Ship/Presentステージの詳細設計 |
| [MONITORING-STORAGE-SYSTEMS.md](./references/MONITORING-STORAGE-SYSTEMS.md) | ストレージシステム比較（Elasticsearch, Prometheus等） |
| [MONITORING-DATA-LIFECYCLE.md](./references/MONITORING-DATA-LIFECYCLE.md) | 保持ポリシー、集約、サンプリング、法的対応 |
| [MONITORING-TECHNIQUES.md](./references/MONITORING-TECHNIQUES.md) | 正規表現最適化、構造化ログ、カーディナリティ管理 |
| [MONITORING-USE-CASES.md](./references/MONITORING-USE-CASES.md) | 組織規模別のテレメトリーシステム設計 |
| [MONITORING-CHECKLIST.md](./references/MONITORING-CHECKLIST.md) | 監視アセスメント実施ガイド |
| [MONITORING-OBSERVABILITY.md](./references/MONITORING-OBSERVABILITY.md) | オブザーバビリティの定義・哲学、構造化イベント |
| [MONITORING-SLO-RELIABILITY.md](./references/MONITORING-SLO-RELIABILITY.md) | SLI/SLO/SLA、エラーバジェット、SLOベースアラート |
| [MONITORING-SAMPLING-STRATEGIES.md](./references/MONITORING-SAMPLING-STRATEGIES.md) | ヘッド/テール/動的サンプリング戦略 |
| [MONITORING-OBSERVABILITY-PRACTICES.md](./references/MONITORING-OBSERVABILITY-PRACTICES.md) | ODD、計装イテレーション、ビジネス事例 |
| [MONITORING-MATURITY-MODEL.md](./references/MONITORING-MATURITY-MODEL.md) | オブザーバビリティ成熟度モデル（OMM） |

### OpenTelemetry references/

| ファイル | 内容 |
|---------|------|
| [OTEL-INSTRUMENTATION-API.md](./references/OTEL-INSTRUMENTATION-API.md) | トレース/メトリクス/ログAPI詳細 |
| [OTEL-COLLECTOR-DEPLOY.md](./references/OTEL-COLLECTOR-DEPLOY.md) | OTLPプロトコル、Collectorアーキテクチャ、サンプリング |
| [OTEL-SEMANTIC-CONVENTIONS.md](./references/OTEL-SEMANTIC-CONVENTIONS.md) | リソース/トレース/メトリクス規約 |
| [OTEL-ADOPTION-STRATEGY.md](./references/OTEL-ADOPTION-STRATEGY.md) | 導入判断、移行パス、コスト管理 |

### ログ設計 references/

| ファイル | 内容 |
|---------|------|
| [LOGGING-COLLECTION.md](./references/LOGGING-COLLECTION.md) | syslog/rsyslog/Fluentd/Logstash/logrotate の詳細設定 |
| [LOGGING-ANALYSIS.md](./references/LOGGING-ANALYSIS.md) | ELK Stack/Grafana/Splunk/grep の詳細と可視化手法 |
| [LOGGING-SECURITY-COMPLIANCE.md](./references/LOGGING-SECURITY-COMPLIANCE.md) | 攻撃検知・Tripwire・コンプライアンス詳細 |
| [LOGGING-AI-ANALYSIS.md](./references/LOGGING-AI-ANALYSIS.md) | ML異常検知（RandomForest/LSTM/BERT/Isolation Forest）|
