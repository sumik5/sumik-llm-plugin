# テレメトリーデータライフサイクル管理

テレメトリーデータのライフサイクル全体にわたる整合性確保、秘匿化、保持・集約ポリシー、法的対応の実践ガイド。

---

## 1. テレメトリー整合性の確保

### 1.1 Emittingステージでの保護

#### Write-only APIキーの使用

プロダクションシステムからSaaSテレメトリープロバイダーへの送信には、**書き込み専用APIキー**を使用する。読み取り権限を持つキーの漏洩は、競合他社や攻撃者への情報流出リスクを生む。

| プロバイダー | キー種別 | 推奨設定 |
|------------|---------|---------|
| **Datadog** | Application Key (write-only) | Metrics/Logs送信専用、UI access権限なし |
| **Honeycomb** | Ingest Key | データ送信のみ、Query権限分離 |
| **New Relic** | License Key | 送信専用、Admin Keyと分離 |
| **Splunk** | HEC Token (HTTP Event Collector) | Index権限のみ、Search権限なし |
| **Sumo Logic** | Collector Token | データ送信専用、Dashboard access分離 |

#### 最小権限原則

プロダクションコードに埋め込むキーは以下の権限のみ保持：

- ✅ テレメトリー送信（POST）
- ❌ テレメトリー読み取り（GET）
- ❌ 設定変更（PUT/DELETE）
- ❌ ユーザー管理

### 1.2 内部攻撃者への防御

#### 認証とアクセス制御

テレメトリーパイプラインの各段階で**個別認証**を実施：

```
Emitter → Shipper → Enrichment → Storage → Presentation
  [Auth1]   [Auth2]    [Auth3]      [Auth4]     [Auth5]
```

**実装例（Kafka + mTLS）:**
- Emitter: クライアント証明書でShipper（Kafka）に認証
- Enrichment: Kafka Consumer Group権限で特定トピックのみ読み取り
- Storage Writer: 専用サービスアカウントで書き込み専用権限
- Presentation: ユーザー単位のACLでクエリ権限制御

#### 設定ファイルの整合性防御

テレメトリーシステムの設定変更は、以下の手法で保護：

| 手法 | 説明 | 実装例 |
|-----|------|-------|
| **構成管理ツール強制** | Ansible/Chef/Puppetによる上書き | 手動変更を5分ごとに検出・復元 |
| **GitOps** | Git commitを唯一の信頼源とする | ArgoCD/Fluxでmanifest自動適用 |
| **不変インフラ** | 設定変更時はインスタンス再作成 | Terraformで完全リビルド |
| **コード署名** | 設定ファイルのデジタル署名検証 | GPG署名付きconfigのみロード |

#### テレメトリー改ざんの検出

##### ハッシュチェーン方式

各テレメトリーイベントに前イベントのハッシュを含める：

```
Event 1: { data: "...", hash: null }
Event 2: { data: "...", hash: SHA256(Event1) }
Event 3: { data: "...", hash: SHA256(Event2) }
```

**検証**: 任意のイベント削除・順序変更でチェーン断絶を検出。

##### Append-onlyストレージ

**特性:**
- 書き込み後は削除・変更不可
- タイムスタンプ順の追記のみ許可

**実装技術:**
- **Write-Ahead Log (WAL)**: Kafka、Kinesis等のストリーミングプラットフォーム
- **Ledger Database**: Amazon QLDB、Azure Confidential Ledger
- **Object Storage Versioning**: S3 Object Lock (WORM mode)

##### HMAC（Hash-based Message Authentication Code）

送信時にシークレットキーでHMAC生成 → 受信側で同一キーで検証：

```python
import hmac
import hashlib

# Emitter側
secret = b'shared-secret-key'
message = '{"metric":"cpu","value":75}'.encode()
signature = hmac.new(secret, message, hashlib.sha256).hexdigest()
# 送信: message + signature

# Shipper/Storage側
received_message, received_signature = ...
expected_signature = hmac.new(secret, received_message, hashlib.sha256).hexdigest()
assert received_signature == expected_signature  # 改ざん検出
```

**利点**:
- 共有シークレットを知る者のみが正当なイベント生成可能
- 中間者による改ざんを検出

---

## 2. データ秘匿化と再処理

### 2.1 有害データ（Toxic Data）の定義

| カテゴリ | 具体例 | 法的根拠 |
|---------|-------|---------|
| **PII (Personally Identifiable Information)** | 氏名、住所、電話番号、メールアドレス | GDPR、CCPA |
| **健康情報** | 病歴、処方薬、遺伝子情報 | HIPAA (米国)、GDPR |
| **金融データ** | クレジットカード番号、銀行口座、取引履歴 | PCI DSS、GLBA |
| **認証情報** | パスワード、APIキー、トークン | 各種セキュリティ標準 |

### 2.2 有害データの発生源

#### 1. 例外トレース（Exception Traces）

```python
# ❌ 悪い例
try:
    process_payment(card_number="4532-1234-5678-9010")
except Exception as e:
    logger.error(f"Payment failed: {e}")  # カード番号がログに含まれる
```

#### 2. パラメータログ

```python
# ❌ 悪い例
def login(username, password):
    logger.info(f"Login attempt: user={username}, pass={password}")
```

#### 3. デバッグログ

開発時に追加した詳細ログが本番環境に残留：

```javascript
// ❌ 悪い例
console.log('User data:', JSON.stringify(req.body));
```

### 2.3 秘匿化（Redaction）テクニック

#### ストレージ内直接書き換え

**用途**: すでに保存済みのデータから有害情報を削除

**Elasticsearchでの実装例:**

```bash
POST /logs/_update_by_query
{
  "script": {
    "source": "ctx._source.message = ctx._source.message.replaceAll(/\\d{4}-\\d{4}-\\d{4}-\\d{4}/, '****-****-****-****')",
    "lang": "painless"
  },
  "query": {
    "regexp": {
      "message": ".*\\d{4}-\\d{4}-\\d{4}-\\d{4}.*"
    }
  }
}
```

**注意**:
- ⚠️ 元データは復元不可
- 法的係争中は実行前に弁護士確認必須

#### Shippingステージでのフィルタリング

**利点**: 有害データをストレージに到達させない

**Fluentd設定例:**

```ruby
<filter app.logs>
  @type record_transformer
  enable_ruby true
  <record>
    message ${record["message"].gsub(/\b\d{16}\b/, "****-****-****-****")}
    email ${record["email"].gsub(/(.{3}).*(@.*)/, '\1***\2')}
  </record>
</filter>
```

#### 再処理パイプラインの構築

既存データを秘匿化版として再生成：

```
Original Storage → Export → Redaction Script → Clean Storage
```

**ステップ:**
1. 元ストレージから範囲指定でエクスポート
2. スクリプトで正規表現/機械学習ベースの秘匿化
3. 別の「クリーン」ストレージに保存
4. 元データは法的保持期間後に削除

### 2.4 有害データ分離によるコスト削減

**戦略**: PII含有イベントを専用パーティションに分離し、短期間で削除。

| パーティション | データ種別 | 保持期間 | コスト |
|--------------|----------|---------|-------|
| **clean-logs** | 秘匿化済み | 1年 | 低 |
| **toxic-logs** | PII含有 | 30日 | 高（短期・小容量） |

**実装パターン（Kafka）:**

```yaml
# Routerがトピック振り分け
topics:
  - clean-metrics  # PII無し → 長期保存
  - toxic-logs     # PII有り → 30日後自動削除
```

### 2.5 構造化ログによる予防

**原則**: 静的メッセージ + コンテキスト分離

```python
# ✅ 良い例
logger.info(
    "Payment processed",
    extra={
        "transaction_id": tx_id,
        "amount": amount,
        "user_id_hash": sha256(user_id)  # ハッシュ化
        # card_number は含めない
    }
)
```

**利点**:
- フィールド単位で秘匿化可能
- `user_id`のみ削除、`transaction_id`は保持

---

## 3. 保持ポリシー（Retention Policy）

### 3.1 テレメトリースタイル別の保持期間

| スタイル | オンライン保持 | オフライン保持 | コスト削減手法 | 主な用途 |
|---------|--------------|--------------|--------------|---------|
| **Centralized Logging** | 2-4週間 | 数年 | N/A | デバッグ、監査 |
| **Metrics** | 1-2年 | なし | 集約（Aggregation） | パフォーマンス監視 |
| **Distributed Tracing** | 2-4週間 | 数ヶ月 | サンプリング | リクエスト追跡 |
| **SIEM** | 3-7年 | 7年以上 | N/A | セキュリティ監査 |

#### オンライン vs オフライン保持

| 項目 | オンライン（Hot Storage） | オフライン（Cold Storage） |
|-----|------------------------|--------------------------|
| **アクセス速度** | ミリ秒～秒 | 分～時間 |
| **コスト** | 高（SSD、メモリDB） | 低（S3 Glacier、テープ） |
| **用途** | リアルタイムクエリ | 過去分析、コンプライアンス |
| **復元必要性** | 常時 | 監査時のみ |

#### スタイル別コスト要因

**Centralized Logging:**
- 💰 コスト要因: データ量（非圧縮時）、インデックス数
- 💡 対策: 古いログは圧縮・S3移行

**Metrics:**
- 💰 コスト要因: カーディナリティ（一意な時系列数）
- 💡 対策: 高カーディナリティラベル削減、集約

**Distributed Tracing:**
- 💰 コスト要因: トレース数（リクエスト数に比例）
- 💡 対策: サンプリング率調整（1%→0.1%）

**SIEM:**
- 💰 コスト要因: 法的要件による長期保存
- 💡 対策: オフライン移行の自動化

---

## 4. 集約ポリシー（Aggregation Policy）

### 4.1 時間解像度削減

**目的**: 古いメトリクスの粒度を下げてストレージコスト削減

| 保存期間 | 元解像度 | 集約後解像度 | データ量削減率 |
|---------|---------|------------|--------------|
| 0-7日 | 1秒 | 1秒（無変更） | 0% |
| 8-30日 | 1秒 | 1分 | 98.3% |
| 31-365日 | 1秒 | 1時間 | 99.97% |
| 366日以降 | 1秒 | 1日 | 99.998% |

**実装例（Prometheus）:**

```yaml
global:
  evaluation_interval: 15s

rule_files:
  - /etc/prometheus/rules/*.yml

# /etc/prometheus/rules/aggregation.yml
groups:
  - name: downsampling
    interval: 1h
    rules:
      # 1分平均を計算して保存
      - record: cpu_usage:1m_avg
        expr: avg_over_time(cpu_usage[1m])
```

### 4.2 集約関数の選択

| 関数 | 用途 | 精度損失 | 注意点 |
|-----|------|---------|-------|
| **sum** | 累積値（リクエスト総数） | なし | 単調増加メトリクス向き |
| **avg** | 平均応答時間 | あり | 異常値の影響を受ける |
| **min/max** | 最小/最大レイテンシ | なし | 外れ値のみ保持 |
| **percentile (p50/p95/p99)** | レイテンシ分布 | あり | 元データ再計算不可 |
| **count** | イベント発生回数 | なし | カウンターに最適 |

**⚠️ 精度損失の例:**

```
元データ（1秒解像度）:
  cpu=10%, 20%, 80%, 10%, 10%  → avg=26%

集約後（5秒平均）:
  cpu=26%

この時点で以下の情報が失われる:
  - 80%のスパイクの存在
  - スパイクの発生時刻
```

### 4.3 集約における注意点

#### Percentile計算の非加算性

**問題**: 複数サーバーのp95レイテンシを単純平均してもグローバルp95にならない

```
Server A: p95 = 200ms (100リクエスト)
Server B: p95 = 150ms (1000リクエスト)

誤: グローバルp95 = (200+150)/2 = 175ms
正: 全1100リクエストを再集計 → 例: 155ms（Server Bが支配的）
```

**解決策:**
- T-Digest、HyperLogLogなどのスケッチアルゴリズム使用
- 各サーバーでヒストグラム保持 → 中央で統合計算

---

## 5. サンプリング

### 5.1 Head-based vs Tail-based サンプリング

| 方式 | 判断タイミング | 利点 | 欠点 |
|-----|--------------|------|------|
| **Head-based** | リクエスト開始時 | シンプル、低コスト | エラートレースを見逃す可能性 |
| **Tail-based** | リクエスト完了後 | エラー/遅延を優先保存可能 | ステートフル、高コスト |

#### Head-based サンプリング実装例

```python
import random

SAMPLE_RATE = 0.01  # 1%のみ送信

def should_sample():
    return random.random() < SAMPLE_RATE

if should_sample():
    tracer.start_span("database_query")
```

#### Tail-based サンプリング実装例

```python
def complete_trace(trace):
    if trace.has_error() or trace.duration > 1000:
        send_to_backend(trace)  # エラー/遅延は必ず送信
    elif random.random() < 0.01:
        send_to_backend(trace)  # 正常系は1%のみ
```

### 5.2 サンプリング率の決定要因

| 要因 | 低レート（0.01%） | 高レート（10%） |
|-----|------------------|----------------|
| **トラフィック量** | 1億req/日 | 10万req/日 |
| **予算** | 限定的 | 潤沢 |
| **エラー頻度** | 0.01%以下 | 1%以上 |
| **調査ニーズ** | 傾向分析のみ | 詳細デバッグ |

### 5.3 分散トレーシングでのサンプリング戦略

#### 一貫性のあるサンプリング

**課題**: マイクロサービス間で異なるサンプリング判定 → トレース断片化

**解決**: TraceIDベースの決定的サンプリング

```python
def should_sample_trace(trace_id: str, rate: float) -> bool:
    # TraceIDのハッシュ値を0-1に正規化
    hash_val = int(hashlib.md5(trace_id.encode()).hexdigest(), 16)
    normalized = (hash_val % 100000) / 100000.0
    return normalized < rate
```

**利点**: すべてのサービスが同じTraceIDで同じ判定 → 完全なトレース保証

---

## 6. 法的対応（eDiscovery）

### 6.1 eDiscoveryプロセスの概要

```
Legal Matter発生
    ↓
Legal Hold（記録保全）← タスク開始点
    ↓
Early Case Assessment（ECA）
    ↓
Collection（収集）
    ↓
Review（レビュー）
    ↓
Production（文書提出）
    ↓
訴訟・和解
```

### 6.2 記録保全（Records Retention / Legal Hold）

#### 定義

**Legal Hold**: 訴訟に関連する可能性のあるテレメトリーデータを削除・変更から保護する法的義務。

#### 対象となるテレメトリーシステム

| システム | 曝露リスク | 理由 |
|---------|----------|------|
| **SIEM** | 最高 | アクセスログ、認証履歴が法的証拠になりやすい |
| **Centralized Logging** | 高 | 詳細なイベント記録が証拠価値高い |
| **Distributed Tracing** | 中 | 特定トランザクションの追跡が必要な場合 |
| **Metrics** | 低 | 数値のみで証拠価値が限定的（ただしパフォーマンス問題の場合は対象） |

#### Legal Hold実施手順

##### 1. 保持データの範囲決定

**弁護士からの指示例:**
- "2024年1月1日～3月31日の`user_id=12345`関連ログすべて"
- "決済APIの全アクセスログ（日付制限なし）"

**質問すべき項目:**
- 対象期間の明確化
- 特定ユーザー/システムに限定するか
- 関連メトリクス/トレースも含めるか

##### 2. 通常の削除ポリシー停止

**Elasticsearch例:**

```bash
# 既存のILMポリシーを一時停止
PUT /legal-hold-logs-*/_settings
{
  "index.lifecycle.name": null
}

# 手動で削除禁止フラグ設定
PUT /legal-hold-logs-*/_settings
{
  "index.blocks.write": false,
  "index.blocks.delete": true
}
```

**Kafka例:**

```bash
# 対象トピックのretention.msを無制限に変更
kafka-configs.sh --alter --entity-type topics \
  --entity-name legal-hold-topic \
  --add-config retention.ms=-1
```

##### 3. 未秘匿化データの分離

**問題**: 通常運用では秘匿化するPIIも、法的証拠として原本保持が必要。

**解決策**: 専用クラスタ/パーティション

```
Production Cluster → Legal Hold Cluster（秘匿化なし）
                  ↓
            Regular Users（秘匿化版）
```

**アクセス制御:**
- Legal Holdクラスタは弁護士・限定ITスタッフのみアクセス可能
- 通常ユーザーには秘匿化版を提供

##### 4. 弁護士へのアクセス提供

**方法A: 読み取り専用アカウント発行**

```bash
# Elasticsearch例
POST /_security/user/legal_team
{
  "password" : "SecurePass123!",
  "roles" : [ "legal_hold_readonly" ],
  "full_name" : "Legal Team Access"
}
```

**方法B: エクスポートAPI提供**

```python
@app.route('/api/legal-export', methods=['POST'])
@require_legal_auth
def export_for_legal(request):
    query = request.json['query']
    data = elasticsearch.search(index='legal-hold-*', body=query)
    return jsonify(data), 200
```

### 6.3 文書提出（Document Production）

#### 求められるフォーマット

| フォーマット | 用途 | 変換方法 |
|------------|------|---------|
| **PDF** | 法廷提出標準 | ログをHTMLレンダリング → wkhtmltopdf |
| **TIFF** | 大量ページの画像化 | ImageMagick一括変換 |
| **CSV** | 統計分析用 | JSON → Pandas → CSV |
| **EDRM XML** | 専用レビューツール | 専用スクリプト（弁護士提供） |

#### Chain of Custody（証拠保全の連鎖）

**定義**: データの収集→転送→保存の全過程で「誰が・いつ・何をしたか」を記録。

**記録すべき情報:**

```json
{
  "collection_date": "2024-06-15T10:30:00Z",
  "collected_by": "john.doe@company.com",
  "source_system": "elasticsearch-prod-01",
  "query": "user_id:12345 AND @timestamp:[2024-01-01 TO 2024-03-31]",
  "record_count": 15234,
  "file_hash": "sha256:abcd1234...",
  "transfer_to": "legal@lawfirm.com",
  "transfer_date": "2024-06-15T14:00:00Z",
  "transfer_method": "Secure FTP"
}
```

**⚠️ Spoliation（証拠隠滅）のリスク:**
- Legal Hold中のデータを誤って削除・変更 → 法廷侮辱罪
- 変更前に**必ず弁護士に確認**

### 6.4 弁護士との協力体制

#### コミュニケーションの原則

| Do ✅ | Don't ❌ |
|------|---------|
| 社内弁護士を窓口にする | 相手方弁護士と直接やり取り |
| 技術的実現可能性を正直に伝える | 「できます」と安易に約束 |
| コスト見積もりを提示 | 無制限にリソース投入 |
| 外部弁護士の技術スタッフと協力 | 弁護士に技術詳細を直接説明 |

#### 典型的な要求と対応

**要求1**: "2023年の全ログを48時間以内に提出"

**対応**:
- 社内弁護士に「範囲が広すぎる」と伝える
- 具体的なユーザー/システム/期間への絞り込みを依頼
- 技術的に可能な範囲を提示（例: 1週間で特定ユーザーのログ）

**要求2**: "ログを元の状態のまま、編集せずに提出"

**対応**:
- 通常の秘匿化処理を停止
- Legal Holdクラスタから未加工データを提供
- PIIを含むため、アクセス制限を弁護士に説明

---

## 7. まとめ

### データライフサイクル管理のチェックリスト

#### 整合性確保

- [ ] Write-only APIキーを使用
- [ ] パイプライン各段階で個別認証実施
- [ ] 設定ファイルを構成管理ツールで保護
- [ ] Append-onlyストレージまたはハッシュチェーン導入

#### 秘匿化

- [ ] 有害データの発生源を特定
- [ ] Shippingステージでのフィルタリング設定
- [ ] 構造化ログで静的メッセージとコンテキスト分離
- [ ] 過去データの再処理パイプライン構築

#### 保持・集約

- [ ] テレメトリースタイル別に保持期間設定
- [ ] オンライン/オフラインストレージの境界定義
- [ ] 古いメトリクスの集約ルール設定
- [ ] サンプリング率の定期レビュー

#### 法的対応

- [ ] Legal Holdの手順をドキュメント化
- [ ] 未秘匿化データの分離方法を確立
- [ ] 弁護士へのアクセス提供方法を準備
- [ ] Chain of Custody記録テンプレート作成
