# テレメトリーシステム組織別ユースケース

企業規模・業種別のテレメトリーシステム設計パターンと成長に伴う進化の実例。

---

## 1. クラウドスタートアップの成長パターン

### 1.1 成長段階別テレメトリー特徴

| 段階 | 従業員数 | テレメトリースタイル | 推奨ツール | 課題 |
|-----|---------|------------------|-----------|------|
| **小規模** | 3-20人 | Metrics + AWS Console Logs | Datadog（SaaS） | コスト意識・シンプルさ最優先 |
| **中規模初期** | 20-100人 | +Distributed Tracing | +Sumo Logic | SaaSコスト増大 |
| **中規模後期** | 100-250人 | +Centralized Logging（自社管理） | ELK Stack自社構築 | コスト削減・カスタマイズニーズ |
| **大規模** | 250-1000人 | +SIEM（セキュリティ） | Splunk/Sumo Logic併用 | コンプライアンス要件 |
| **エンタープライズ** | 1000人以上 | 4スタイル完全自社管理 | OpenTelemetry基盤 | 多地域レプリケーション |

### 1.2 小規模（Small-Company Stage）

#### 組織特性

- 創業メンバー3-5人
- MVP（Minimally Viable Product）探索中
- 最大リスク: **運転資金の枯渇**

#### テレメトリーアーキテクチャ

```
Production (AWS ECS Fargate)
    ↓
Datadog Agent（Emitter/Shipper統合）
    ↓
Datadog Cloud（SaaS）
    ├─ Metrics Dashboard
    └─ AWS Console Logs
```

**特徴:**
- ✅ Shipping/Presentation全委譲 → エンジニアは製品開発に集中
- ✅ Datadog SDKで簡単に計装
- ❌ トレーシング未導入（複雑性不要）

**判断基準:**
- 「テレメトリーに時間を使うより、顧客獲得を優先」
- SaaSコストは投資家資金でカバー可能な範囲

### 1.3 中規模初期（Early Medium-Size）

#### 組織変化

- DevOpsチーム独立
- CI/CDシステム導入
- Series A/B資金調達完了

#### アーキテクチャ進化

```
Production (複数ECS Cluster)
    ↓ Emit
Datadog Agent + Sumo Logic Forwarder
    ↓ Ship
Datadog（Metrics/Tracing） + Sumo Logic（Logging）
```

**追加された理由:**
- AWS ECS Consoleの限界: 検索・可視化機能が不足
- Sumo Logic追加でログ分析強化

**⚠️ コスト圧力の始まり:**
- Datadog: $150-300/host/month
- Sumo Logic: $90-150/GB/month
- → 次段階でコスト削減検討開始

### 1.4 中規模後期（Late Medium-Size）

#### 組織変化

- SREチーム設立
- 自社データセンター検討開始
- コスト最適化が経営課題に

#### アーキテクチャ転換

```
Production (ECS + EKS)
    ↓ Emit to SQS
Fluentd（EKS上で稼働）
    ↓ Ship & Enrich
Elasticsearch + Kibana（AWS Elasticsearch）
    ↑
Prometheus（自社管理Metrics）
```

**削減効果:**
- Sumo Logic → ELK Stack: 年間$300K削減
- Datadog Metrics → Prometheus: 年間$100K削減
- Datadog Tracingは継続（高価だが代替困難）

**トレードオフ:**
- 運用負荷増加（Fluentd、Elasticsearch管理）
- DevOps/SREチームの存在が前提

### 1.5 大規模（Large-Company Stage）

#### 組織変化

- セキュリティチーム新設（SOC 2対応）
- Fortune 500企業との取引開始
- コンプライアンス監査必須に

#### アーキテクチャ全面改訂

```
Production (EKS + EC2 + RDS)
    ↓ Emit
RabbitMQ（メッセージブローカー）
    ↓ Route
┌─────────────┬────────────┬──────────┐
│ Log Parser  │ Metrics    │ Tracing  │
│ (Fluentd)   │ Parser     │ (Datadog)│
└─────────────┴────────────┴──────────┘
    ↓ Store        ↓           ↓
Elasticsearch   Prometheus   (SaaS)
    │               │
Kibana          Grafana
    ↓
Sumo Logic（SIEM専用フィード）
```

**新機能:**
- **マルチテナンシー**: セキュリティチーム用SIEM分離
- **Router導入**: RabbitMQでスタイル別トピック振り分け
- **コンプライアンス対応**: OS/ハードウェアログを全記録

**SIEMにSumo Logic復活:**
- Elasticsearch: アプリケーションログ
- Sumo Logic: OS/ハードウェアセキュリティイベント

### 1.6 エンタープライズ（Enterprise Stage）

#### 組織変化

- グローバル展開（米国・EU・APACデータセンター）
- 従業員数1000人超
- Unicorn企業（評価額$1B以上）

#### ストリームベースアーキテクチャ

```
Production (Multi-Region)
    ↓ Emit to Stream
Apache Kafka（6 Topics）
    ├─ logging
    ├─ metrics
    ├─ tracing
    ├─ linux
    ├─ windows
    └─ syslog
    ↓ Parse & Enrich
Parser Pool（Horizontal Scaling）
    ↓ Store
OpenTelemetry Collector → Storage
    ├─ Logging: Elasticsearch（米/EU別クラスタ）
    ├─ Metrics: Prometheus（グローバルレプリケーション）
    └─ Tracing: Jaeger（地域別）
```

**地域別戦略:**

| データ種別 | 米国⇔EU間レプリケーション | 理由 |
|----------|------------------------|------|
| **Logging** | ❌ 禁止 | GDPR: EUユーザーデータは域内保持必須 |
| **Metrics** | ✅ 許可 | 数値のみ、PII含まず |
| **Tracing** | 🔄 開発中 | OpenTelemetry成熟待ち |

**自社開発への転換:**
- Datadog Tracing廃止 → OpenTelemetry + Jaeger
- 年間コスト$2M削減
- OSSコミュニティへの貢献（採用ブランディング効果）

---

## 2. 非ソフトウェア企業のパターン

### 2.1 小規模組織（Small Organization）

#### 典型例

- 従業員20人以下
- ピザ屋、獣医クリニック、設計事務所

#### テレメトリー実態

**一般企業:**
```
SaaS製品群（QuickBooks、Square、Office 365）
    → 各製品内でのみデータ完結
    → テレメトリーシステム不在
```

**医療機関（規制業界）:**
```
Practice Management Software（診療記録管理）
    ├─ アクセスログ（HIPAA対応）
    └─ 監査レポート

Office 365
    ├─ ログイン/ログアウトログ
    └─ エンドポイント保護ログ
```

**差異の理由:**
- 医療: HIPAA、個人情報保護法で監査ログ義務
- 一般: 法的要件なし → テレメトリー不要

### 2.2 中規模組織（Medium-Size Organization）

#### 組織特性

- 従業員30-500人
- 専門ITスタッフ採用開始
- HRISシステム導入

#### テレメトリー導入の転機

**プロフェッショナルIT部門の影響:**

```
Endpoint Management（Intune/JAMF）
    ↓ Forward
Sumo Logic Cloud（Centralized Logging）
    ├─ Azure AD（認証ログ）
    ├─ Microsoft Intune（ポリシー適用ログ）
    ├─ Office 365（ドキュメントアクセス）
    └─ 従業員PC（Windowsイベントログ）
```

**特徴:**
- 初めての「真のCentralized Logging」
- ビジネス部門も利用開始（誰がどのファイルにアクセスしたか）

### 2.3 大規模組織（Large Organization）

#### 組織特性

- 従業員500-1000人
- サーバー管理歴20年以上
- 内製ソフトウェア開発開始

#### デュアルテレメトリーシステム

**IT部門:**
```
Splunk（オンプレミス）
    ├─ AD認証ログ
    ├─ Windowsサーバーログ
    └─ エンドポイントログ

SolarWinds（ネットワーク監視）
    └─ ネットワーク機器メトリクス
```

**開発部門:**
```
InfluxDB + Grafana（自社管理Metrics）
    └─ 内製アプリケーション

Honeycomb（SaaSでTracing）
    └─ 分散トレーシング

Splunk（共有）
    └─ アプリケーションログ
```

**統合の試み:**
- SolarWindsライセンスコスト削減のため、InfluxDB + Telegraf Agentで置き換え検討
- 結果: ネットワーク監視はSolarWinds継続（機能差が大きい）

### 2.4 エンタープライズ組織（Enterprise Organization）

#### 組織特性

- 従業員1000人以上、多地域展開
- 「複数の小組織がトレンチコートを着ている」状態
- テレメトリー島（Telemetry Islands）の乱立

#### Paved Roads Project（舗装道路プロジェクト）

**目的**: 標準化されたテレメトリー基盤を提供し、各部門の車輪の再発明を防ぐ

**アーキテクチャ例（Metrics）:**

```
Production Systems（多様なソース）
    ├─ Hardware → Cisco Prime（プロキシ）
    ├─ OS → Metrics Agent
    ├─ Legacy App → Syslog（ラッパー）
    └─ Modern App → Direct Emit
        ↓
Apache Kafka（raw_metrics Topic）
        ↓ Parse & Enrich
Metrics Parser Pool（水平スケール）
        ↓
Kafka（store_metrics Topic）
        ↓ Write
OpenTSDB（Hadoop上に構築）
        ↓ Present
Grafana Enterprise（マルチテナント対応）
```

**マルチテナンシー:**
- 部門別にOpenTSDBインスタンス分離
- Grafanaのフォルダ権限で可視化制御
- 政治的理由で必須（部門間の不信感）

**対応フォーマット:**
- ✅ Prometheus Remote Write
- ✅ StatsD
- ✅ Syslog wrapped metrics
- ✅ Cisco Prime API

---

## 3. レガシーIT企業のパターン

### 3.1 メインフレーム時代の遺産

#### 特徴

- 1960-70年代にコンピューター化
- バッチ処理文化
- RS-232シリアル接続時代

#### 現代への影響

**システム例:**
```
Mainframe（z/OS）
    ├─ CICS（オンライン処理）
    ├─ Batch Jobs（夜間処理）
    └─ SYSLOG（メインフレーム専用ログ）
        ↓ Convert
    Tectia Connector（メインフレーム→モダン変換）
        ↓
    Splunk
```

**課題:**
- メインフレームログフォーマットが独自
- 変換コストが高い
- 専門知識を持つ人材不足

### 3.2 部門別テレメトリー乱立

**典型的な構成（大企業）:**

| 部門 | テレメトリーシステム | 理由 |
|-----|------------------|------|
| **倉庫管理** | IBM AIXベース独自システム | 1990年代導入、変更リスク高 |
| **ウェブサイト** | Datadog（最新SaaS） | 外部エンジニア採用で導入 |
| **オフィスIT** | Microsoft Sentinel（Azure） | Office 365統合で自然採用 |
| **ビジネスインテリジェンス** | Elastic Stack | データ分析チームが独自構築 |

**統合プロジェクトの困難:**
- 政治的抵抗（「うちの部署は特別」）
- 技術的負債（レガシーシステムの移行コスト）
- 予算承認の難航（ROI証明困難）

### 3.3 Paved Roads vs 強制統一

| アプローチ | 内容 | 成功率 | 適用ケース |
|----------|------|-------|----------|
| **Paved Roads** | 標準基盤提供、利用は任意 | 中～高 | エンタープライズ |
| **強制統一** | 全システムを単一基盤に移行 | 低 | スタートアップ |
| **ハイブリッド** | 新規は標準、既存は段階移行 | 高 | レガシーIT企業 |

---

## 4. 組織規模別判断基準テーブル

### 4.1 SaaS vs Self-hosted

| 組織規模 | SaaS推奨度 | Self-hosted推奨度 | 判断要因 |
|---------|-----------|-----------------|---------|
| **小規模（<20人）** | ⭐⭐⭐⭐⭐ | ☆☆☆☆☆ | コストよりスピード |
| **中規模（20-100人）** | ⭐⭐⭐⭐☆ | ⭐☆☆☆☆ | コスト意識芽生え |
| **中規模（100-250人）** | ⭐⭐⭐☆☆ | ⭐⭐☆☆☆ | 部分的自社管理開始 |
| **大規模（250-1000人）** | ⭐⭐☆☆☆ | ⭐⭐⭐☆☆ | コスト・カスタマイズ重視 |
| **エンタープライズ（1000人以上）** | ⭐☆☆☆☆ | ⭐⭐⭐⭐☆ | 完全自社管理志向 |

### 4.2 テレメトリースタイル優先順位

| 規模 | 1st | 2nd | 3rd | 4th |
|-----|-----|-----|-----|-----|
| **小規模** | Metrics | Logging（SaaS任せ） | - | - |
| **中規模** | Metrics | Logging | Tracing | - |
| **大規模** | Logging | Metrics | Tracing | SIEM |
| **エンタープライズ** | すべて必須（並列導入） |

### 4.3 アーキテクチャパターン選択

| パターン | 適用規模 | 複雑性 | コスト | メリット |
|---------|---------|-------|-------|---------|
| **Full SaaS** | 小～中 | 低 | 高 | 運用負荷ゼロ |
| **Hybrid（SaaS + Self）** | 中～大 | 中 | 中 | 柔軟性とコストバランス |
| **Stream-based** | 大～エンタープライズ | 高 | 中～低 | 水平スケール、マルチテナント対応 |
| **Federated（連邦型）** | エンタープライズ | 最高 | 低～中 | 部門自律性維持 |

---

## 5. 成長に伴う移行パターン

### 5.1 Logging移行

```
Stage 1（小規模）: AWS CloudWatch Logs
    ↓ コスト増大
Stage 2（中規模初期）: Sumo Logic（SaaS）
    ↓ さらなるコスト増大
Stage 3（中規模後期）: ELK Stack（自社管理）
    ↓ 複雑性増大
Stage 4（大規模）: Elasticsearch + Kafka + Parser Pool
    ↓ 地域展開
Stage 5（エンタープライズ）: Multi-region Replication
```

### 5.2 Metrics移行

```
Stage 1: Datadog（SaaS）
    ↓
Stage 2: Prometheus（単一インスタンス）
    ↓
Stage 3: Prometheus + Thanos（長期ストレージ）
    ↓
Stage 4: Victoria Metrics / M3DB（大規模分散）
```

### 5.3 Tracing移行

```
Stage 1: なし（不要）
    ↓
Stage 2: Datadog APM（SaaS）
    ↓
Stage 3: Jaeger（自社管理）
    ↓
Stage 4: OpenTelemetry + 自社Collector
```

---

## 6. 失敗パターンと回避策

### 6.1 典型的失敗

| 失敗パターン | 原因 | 回避策 |
|-----------|------|-------|
| **早すぎる自社管理** | 小規模段階で複雑なシステム構築 | 100人までSaaS継続 |
| **統一の強制** | トップダウンで全部門に単一システム | Paved Roads方式採用 |
| **技術的負債無視** | レガシーシステム統合を後回し | 最初から統合計画策定 |
| **マルチテナント未対応** | 部門間の政治的対立を軽視 | 初期からACL設計 |

### 6.2 成功の鍵

- **段階的導入**: 一度にすべて変えない
- **Quick Win重視**: 可視化ダッシュボードで早期に価値提示
- **ステークホルダー巻き込み**: セキュリティ・コンプライアンス部門を初期から参加
- **教育投資**: 新システムのトレーニング予算確保

---

## 7. まとめ

### 組織タイプ別推奨アプローチ

| 組織タイプ | 推奨戦略 | 重点領域 |
|----------|---------|---------|
| **クラウドスタートアップ** | SaaS → 段階的自社化 | コスト最適化タイミング見極め |
| **非ソフトウェア企業** | IT主導のCentralized Logging | ビジネス部門への価値訴求 |
| **レガシーIT企業** | Paved Roads + 段階移行 | 政治的調整・レガシー統合 |

### テレメトリー成熟度モデル

| レベル | 特徴 | 典型的規模 |
|-------|------|----------|
| **Level 0** | テレメトリー不在 | 小規模非IT企業 |
| **Level 1** | 個別SaaS製品内ログのみ | 小規模スタートアップ |
| **Level 2** | Centralized Logging導入 | 中規模企業 |
| **Level 3** | Metrics + Logging統合 | 大規模企業 |
| **Level 4** | 4スタイル完備 + マルチテナント | エンタープライズ |
| **Level 5** | グローバルレプリケーション + AI活用 | グローバル企業 |
