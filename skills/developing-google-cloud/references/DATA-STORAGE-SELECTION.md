# GCP ストレージサービス選択ガイド

Google Cloud Platform (GCP) におけるデータストレージサービスの選択基準、コスト最適化、パフォーマンス最適化、アクセスパターンに基づくライフサイクル管理を解説する。

---

## ストレージサービス選択決定木

データストレージサービスは、データの構造・用途・スケールに基づいて選択する。

### 判断フロー

```
データ形式の判断
    ├─ オブジェクト（ファイル単位）
    │   → Cloud Storage
    │
    ├─ 半構造化（スキーマが柔軟）
    │   ├─ 低レイテンシ・リアルタイム要件
    │   │   → Firestore
    │   │
    │   └─ 大量データ分析・AI活用
    │       → BigQuery
    │
    ├─ 構造化（厳密なスキーマ）
    │   ├─ リレーショナル不要・数列のみ・大量行
    │   │   → Bigtable
    │   │
    │   └─ リレーショナル
    │       ├─ グローバルスケール要件
    │       │   → Cloud Spanner
    │       │
    │       └─ 通常スケール
    │           → Cloud SQL
    │
    └─ 複数フォーマット混在・分析用途
        → BigQuery（データレイク/ウェアハウス）
```

---

## サービス別ユースケース比較

| サービス | データ形式 | スキーマ | スケール | 主要ユースケース |
|---------|-----------|---------|---------|-----------------|
| **Cloud Storage** | オブジェクト（ファイル） | なし | 無制限 | アーカイブバックアップ、法的保持、DBバックアップ、Webサイトホスティング、画像/動画コンテンツ、バージョン管理 |
| **Firestore** | 半構造化（JSON） | 柔軟 | 高 | 低レイテンシアプリ、ゲーム、リアルタイムデータ、単純なクエリ |
| **Bigtable** | 構造化（Wide Column） | 固定（少数列） | 超高 | IoTデータ収集、時系列ログ、数百万行・数列のデータ |
| **Cloud SQL** | 構造化（SQL） | リレーショナル | 中 | トランザクション整合性（金融等）、通常規模アプリ |
| **Cloud Spanner** | 構造化（SQL） | リレーショナル | グローバル | グローバル低レイテンシ、超大規模リレーショナルDB |
| **BigQuery** | 複数形式 | 柔軟 | 無制限 | データウェアハウス、分析、可視化、AI/MLモデル、複数データソース統合 |

### 選択基準詳細

#### Cloud Storage
- **Bucketは全GCPアカウントで一意**の識別名を持つ
- **無制限ストレージ**（保存量・アクセスで課金）
- ファイル単位の操作、パース不要なデータに最適

**バケット設計の考慮事項**:

| 設定項目 | 説明 | 選択基準 |
|---------|------|---------|
| **リージョン** | データの保存場所（単一リージョン or マルチリージョン） | レイテンシ要件、冗長性要件、コスト |
| **ストレージクラス** | Standard / Nearline / Coldline / Archive | アクセス頻度（後述のライフサイクルで自動変更可能） |
| **アクセス制御** | Uniform（バケット全体）/ Fine-grained（オブジェクト個別） | セキュリティ粒度の要件 |
| **公開設定** | 認証必須 / 公開アクセス許可 | Webサイトホスティング等では公開、通常は認証必須 |

#### Firestore
- **JSON形式の半構造化データ**に対応
- 同一テーブル内で異なるスキーマのドキュメントを許容
- 低レイテンシ・高速読み書き・リアルタイムクエリ
- アプリ開発に最適（ゲーム、チャット等）

#### Bigtable
- **Wide Columnデータベース**（数列・数百万行）
- IoTセンサーデータ、固定期間ログに最適
- リレーショナル機能なし

#### Cloud SQL vs Cloud Spanner
- **Cloud SQL**: コスト効率的、通常スケール、リージョナル
- **Cloud Spanner**: 高コスト、グローバルスケール、低レイテンシ
- 両者ともSQL対応・リレーショナル

#### BigQuery
- 複数データソース・形式を統合
- データセット単位で管理
- ストリーミング取込・バルクアップロード対応
- 可視化・AI/MLモデル作成機能統合

---

## コスト最適化

### TCO（Total Cost of Ownership）削減

| 観点 | オンプレミス | クラウド（GCP） |
|------|------------|----------------|
| ハードウェア保守 | 企業負担 | Google Cloud負担 |
| 可用性管理 | 企業負担 | Google Cloud負担（SLA保証） |
| 初期投資 | 高額 | 従量課金 |
| スタッフ人件費 | 必要 | 削減可能 |

**推奨事項**:
- プライマリデータストレージはクラウドサービス利用
- オンプレミス保守コスト・可用性リスクを排除
- TCO（Total Cost of Ownership）を大幅削減

### ライブデータ vs 歴史データ

- **ライブデータ**: 頻繁な書き込み・即時アクセス → 高コスト
- **歴史データ**: 書き込み頻度低・アーカイブ可能 → 低コスト
- **実態**: ライブデータは全体の小部分、大半は歴史データ

### バルクディスカウント交渉

大規模ワークロード・長期利用の場合:
- Google Cloud（または認定パートナー）と直接交渉
- 予測使用量ベースの割引適用
- テスト・小規模ワークロードは即座利用可能

### Billing Alert設定

```bash
# コンソールでBilling Alert設定
gcloud alpha billing budgets create \
  --billing-account=<BILLING_ACCOUNT_ID> \
  --display-name="Data Storage Budget" \
  --budget-amount=1000USD \
  --threshold-rule=percent=50 \
  --threshold-rule=percent=90
```

- コスト閾値到達時に通知
- 予算超過前にワークロード調整判断可能

---

## パフォーマンス最適化

### Read Replicas（Cloud SQL）

**概念**:
- データベースのコピーを作成
- **読み取り専用レプリカ**から読み取り、**プライマリDB**に書き込み
- 読み書き分離によるパフォーマンス向上

**メリット**:
- 読み取りと書き込みが互いに影響しない
- 他リージョン配置でグローバルアクセス高速化
- レプリカをプライマリに昇格可能（障害時）

### Rightsizing（適正サイズ化）

**定義**: データストレージサービスが以下を同時に満たす状態
- データ量・操作に対して十分なパフォーマンス
- 過剰なコンピューティングリソース・スペックを持たない

**アプローチ**:
1. **履歴分析**: 過去のデータアクセスパターンを分析
2. **設定最適化**: 分析結果に基づき構成を調整
3. **継続的改善**: Logging・Monitoringで継続監視

---

## アクセスパターンとライフサイクル管理

### アクセスパターンの分類

| パターン | 頻度 | 最適ストレージ |
|---------|------|---------------|
| 高頻度アクセス | 毎秒・毎分 | 高速キャッシュ、Standard tier |
| 中頻度アクセス | 毎日 | Standard tier（デフォルト対応） |
| 低頻度アクセス | 月1回・年1回 | Nearline/Coldline tier |
| 超低頻度（アーカイブ） | 数年に1回 | Archive tier |

### データアクセスパターン進化

**典型例**: 企業財務ログ
1. **作成直後**: 頻繁にアクセス（Standard）
2. **四半期終了後**: アクセス頻度低下（Nearline/Coldline）
3. **法的保持期間**: 削除禁止・長期保管（Archive + Retention Policy）

---

## Cloud Storage ストレージクラス比較

| クラス | アクセスコスト | ストレージコスト | 最小保存期間 | ユースケース |
|--------|-------------|----------------|------------|-------------|
| **Standard** | 最低 | 最高 | なし | 頻繁にアクセスするデータ（ホットデータ） |
| **Nearline** | 低 | 高 | 30日 | 月1回程度のアクセス（バックアップ） |
| **Coldline** | 中 | 中 | 90日 | 四半期1回程度のアクセス（災害復旧） |
| **Archive** | 最高 | 最低 | 365日 | 年1回未満のアクセス（コンプライアンス保管） |

### ライフサイクルポリシー自動化

```bash
# gsutil でライフサイクルルール設定
gsutil lifecycle set lifecycle.json gs://BUCKET_NAME
```

**lifecycle.json 例**:
```json
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "SetStorageClass", "storageClass": "NEARLINE"},
        "condition": {"age": 30, "matchesStorageClass": ["STANDARD"]}
      },
      {
        "action": {"type": "SetStorageClass", "storageClass": "COLDLINE"},
        "condition": {"age": 90, "matchesStorageClass": ["NEARLINE"]}
      },
      {
        "action": {"type": "SetStorageClass", "storageClass": "ARCHIVE"},
        "condition": {"age": 365, "matchesStorageClass": ["COLDLINE"]}
      }
    ]
  }
}
```

**ルール適用順序**:
- 削除ルールと移行ルールが競合する場合、**削除ルールが優先**

---

## データ保護機能（Cloud Storage）

### Retention Policy（保持ポリシー）

```bash
# バケットに保持ポリシー設定
gsutil retention set 5y gs://BUCKET_NAME

# バケットをロック（変更不可に）
gsutil retention lock gs://BUCKET_NAME
```

- 指定期間中、オブジェクトを削除・変更不可
- コンプライアンス要件に対応

### Soft Delete

- 削除後、一定期間オブジェクトを保持
- 保持期間中は復元可能
- 期間経過後に完全削除

### Versioning

- 同名オブジェクトを上書き時、旧バージョンを保持
- 必要に応じて過去バージョン復元可能

---

## ストレージサービス決定チェックリスト

以下の質問に順次答え、最適サービスを選択:

1. **データはファイル単位か？**
   - YES → Cloud Storage
   - NO → 次へ

2. **スキーマは厳密か？**
   - NO（柔軟） → 次へ（半構造化）
   - YES → 次へ（構造化）

3. **【半構造化】低レイテンシ・リアルタイム要件があるか？**
   - YES → Firestore
   - NO → BigQuery

4. **【構造化】リレーショナルか？**
   - NO → Bigtable
   - YES → 次へ

5. **【リレーショナル】グローバルスケールが必要か？**
   - YES → Cloud Spanner
   - NO → Cloud SQL

6. **複数フォーマット・分析用途か？**
   - YES → BigQuery

---

## 参考CLIコマンド

### Cloud Storage操作

```bash
# バケット作成
gsutil mb -l REGION gs://BUCKET_NAME

# ライフサイクルポリシー確認
gsutil lifecycle get gs://BUCKET_NAME

# オブジェクトアップロード
gsutil cp LOCAL_FILE gs://BUCKET_NAME/

# ストレージクラス変更
gsutil rewrite -s STORAGE_CLASS gs://BUCKET_NAME/OBJECT_NAME
```

### BigQuery操作

```bash
# データセット作成
bq mk --dataset PROJECT_ID:DATASET_NAME

# テーブル作成
bq mk --table PROJECT_ID:DATASET_NAME.TABLE_NAME schema.json

# データロード
bq load --source_format=CSV PROJECT_ID:DATASET_NAME.TABLE_NAME gs://BUCKET/file.csv

# クエリ実行
bq query --use_legacy_sql=false 'SELECT * FROM `PROJECT_ID.DATASET_NAME.TABLE_NAME` LIMIT 10'
```

---

## まとめ

GCPデータストレージ選択の原則:

1. **データ形式でサービスを選択**: オブジェクト/半構造化/構造化/複数形式
2. **コストとパフォーマンスのバランス**: TCO削減、ライブ/歴史データ分離、Rightsizing
3. **アクセスパターンに基づくライフサイクル管理**: Standard → Nearline → Coldline → Archive自動遷移
4. **保護機能活用**: Retention Policy、Versioning、Soft Deleteでコンプライアンス対応
