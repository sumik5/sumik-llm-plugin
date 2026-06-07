# Amazon SageMaker & 機械学習リファレンス

SageMakerを中心としたAWS機械学習サービスの包括的ガイド。

> **関連**: Bedrock/生成AIは [BEDROCK-API.md](./BEDROCK-API.md) および [GENAI-ARCHITECTURE.md](./GENAI-ARCHITECTURE.md) を参照

---

## 目次

1. [機械学習ライフサイクル](#機械学習ライフサイクル)
2. [SageMaker Studio](#sagemaker-studio)
3. [データ準備](#データ準備)
4. [モデル開発](#モデル開発)
5. [モデルトレーニング](#モデルトレーニング)
6. [モデルデプロイ](#モデルデプロイ)
7. [モデル監視](#モデル監視)
8. [MLOps](#mlops)
9. [セキュリティとガバナンス](#セキュリティとガバナンス)

---

## 機械学習ライフサイクル

### フェーズ概要

```
ビジネス理解 → データ収集 → データ準備 → 特徴量エンジニアリング
     ↓
モデル選択 → モデルトレーニング → モデル評価 → ハイパーパラメータ調整
     ↓
モデルデプロイ → モデル監視 → 再トレーニング
```

### AWS MLスタック

| レイヤー | サービス |
|---------|---------|
| AI Services | Rekognition, Comprehend, Transcribe, Translate, Polly |
| ML Platform | SageMaker |
| ML Frameworks | TensorFlow, PyTorch, MXNet |
| Infrastructure | EC2 (GPU/CPU), Inferentia, Trainium |

---

## SageMaker Studio

### 概要

**統合ML開発環境**
- JupyterLab ベース
- コード編集、実験管理、デプロイまで一元化
- チームコラボレーション

### コンポーネント

| コンポーネント | 説明 |
|--------------|------|
| Studio Notebooks | フルマネージド Jupyter |
| Code Editor | VS Code ベースのIDE |
| Canvas | ノーコードML |
| Data Wrangler | データ準備 |
| Feature Store | 特徴量管理 |
| Experiments | 実験追跡 |
| Pipelines | MLワークフロー |
| Model Registry | モデル管理 |

### ドメインとユーザープロファイル

**ドメイン**
- SageMaker Studio のコンテナ
- VPC設定、認証設定を含む
- 複数ユーザープロファイルを管理

**ユーザープロファイル**
- 個人の設定とリソース
- 実行ロールの指定
- ストレージ設定

---

## データ準備

### ストレージオプション

| サービス | 特徴 | 適用 |
|---------|------|------|
| S3 | スケーラブル、低コスト | 大規模データセット |
| EFS | 共有ファイルシステム | チーム共有データ |
| FSx for Lustre | 高スループット | 大規模トレーニング |

**データアクセスパターン**

| モード | 説明 | 適用 |
|--------|------|------|
| File Mode | S3からローカルにダウンロード | 小〜中規模 |
| Pipe Mode | ストリーミング読み取り | 大規模データ |
| Fast File Mode | S3直接アクセス | 柔軟性重視 |

### SageMaker Data Wrangler

**機能**
- データインポート（S3, Athena, Redshift等）
- データ変換（300+の組み込み変換）
- データ可視化
- Data Quality レポート

**出力**
- S3へのエクスポート
- Feature Store への登録
- Pipelines へのエクスポート

### 特徴量エンジニアリング

**数値特徴量**
- 正規化（Min-Max Scaling）
- 標準化（Z-score）
- 対数変換
- ビニング

**カテゴリカル特徴量**
- One-Hot Encoding
- Label Encoding
- Target Encoding
- Feature Hashing

**外れ値処理**
- IQR法
- Z-score法
- ロバストスケーリング

### SageMaker Feature Store

**特徴**
- 特徴量の一元管理
- オンライン/オフラインストア
- 特徴量グループによる整理
- ポイントインタイム検索

**ストアタイプ**

| タイプ | 特徴 | 用途 |
|--------|------|------|
| Online | 低レイテンシ | リアルタイム推論 |
| Offline | S3バックエンド | トレーニング |

---

## モデル開発

### 組み込みアルゴリズム

**教師あり学習**

| アルゴリズム | タスク | 用途 |
|------------|--------|------|
| Linear Learner | 回帰/分類 | 線形関係のデータ |
| XGBoost | 回帰/分類 | 構造化データ |
| K-NN | 分類/回帰 | 類似度ベース |
| Factorization Machines | 推薦 | 疎なデータ |

**教師なし学習**

| アルゴリズム | タスク | 用途 |
|------------|--------|------|
| K-Means | クラスタリング | グループ化 |
| PCA | 次元削減 | 特徴量圧縮 |
| Random Cut Forest | 異常検出 | 外れ値検出 |
| IP Insights | IP異常検出 | セキュリティ |

**深層学習**

| アルゴリズム | タスク | 用途 |
|------------|--------|------|
| Image Classification | 画像分類 | CNN |
| Object Detection | 物体検出 | SSD/Faster R-CNN |
| Semantic Segmentation | セグメンテーション | 画素分類 |
| Sequence-to-Sequence | 翻訳 | RNN/Transformer |
| BlazingText | テキスト分類/埋め込み | 高速テキスト処理 |

### BYOM（Bring Your Own Model）

**コンテナ要件**
- `/opt/ml/model` へのモデル配置
- `train` スクリプト（トレーニング用）
- `serve` スクリプト（推論用）

**フレームワークコンテナ**
- TensorFlow
- PyTorch
- MXNet
- Scikit-learn

### SageMaker JumpStart

**機能**
- 事前トレーニング済みモデル
- ソリューションテンプレート
- ワンクリックデプロイ
- ファインチューニング

---

## モデルトレーニング

### トレーニングジョブ

**設定項目**
- アルゴリズム/コンテナ指定
- インスタンスタイプ/数
- 入力データチャネル
- ハイパーパラメータ
- 出力先（S3）

**インスタンスタイプ選択**

| ファミリー | 用途 |
|----------|------|
| ml.m5 | 汎用 |
| ml.c5 | CPU集約 |
| ml.p3/p4 | GPU（トレーニング） |
| ml.g4dn | GPU（コスト効率） |
| ml.trn1 | Trainium |

### 分散トレーニング

**データ並列**
- 同一モデルを複数GPUで
- データを分割して並列処理
- 勾配の集約

**モデル並列**
- 大規模モデルを分割
- 各GPUがモデルの一部を保持
- パイプライン並列

**SageMaker分散ライブラリ**
- Data Parallel Library
- Model Parallel Library
- Horovod統合

### ハイパーパラメータ最適化（HPO）

**自動モデルチューニング**
- ベイズ最適化
- ランダム検索
- グリッド検索

**設定項目**
- 目的メトリクス（最大化/最小化）
- パラメータ範囲（連続/整数/カテゴリカル）
- 最大ジョブ数
- 並列ジョブ数

### モデル評価

**分類メトリクス**
- Accuracy
- Precision / Recall
- F1 Score
- AUC-ROC
- 混同行列

**回帰メトリクス**
- MSE / RMSE
- MAE
- R-squared

**バイアス/バリアンス**
- 過学習（Overfitting）: 高バリアンス
- 未学習（Underfitting）: 高バイアス

**正則化**

| 手法 | 説明 |
|------|------|
| L1 (Lasso) | 係数を0に |
| L2 (Ridge) | 係数を小さく |
| Elastic Net | L1 + L2 |
| Dropout | ニューロン無効化 |
| Early Stopping | 早期終了 |

### 交差検証

**K-fold Cross Validation**
- データをK分割
- K-1で訓練、1で検証
- K回繰り返し平均

---

## モデルデプロイ

### 推論オプション

| オプション | 特徴 | 用途 |
|----------|------|------|
| Real-time | 常時稼働エンドポイント | 低レイテンシ要件 |
| Serverless | 自動スケーリング | 間欠的トラフィック |
| Batch Transform | 大量データ一括処理 | バッチ推論 |
| Asynchronous | キュー処理 | 長時間推論 |

### リアルタイム推論

**エンドポイント構成**
- Model: モデルアーティファクト
- Endpoint Configuration: インスタンス設定
- Endpoint: デプロイされたエンドポイント

**マルチモデルエンドポイント（MME）**
- 複数モデルを単一エンドポイントに
- コスト効率
- 動的モデルロード

**マルチコンテナエンドポイント（MCE）**
- 複数コンテナを直列/並列実行
- 推論パイプライン

### Serverless Inference

**特徴**
- 使用時のみ課金
- 自動スケーリング（0まで）
- コールドスタートあり

**設定**
- Memory Size: 1024-6144 MB
- Max Concurrency: 1-200

### Batch Transform

**特徴**
- S3からS3への変換
- 大量データ処理
- コスト効率

### 推論パイプライン

**構成**
- 前処理コンテナ
- 推論コンテナ
- 後処理コンテナ

### デプロイ戦略

| 戦略 | 説明 |
|------|------|
| All At Once | 即時切り替え |
| Canary | 段階的移行 |
| Linear | 線形移行 |
| Blue/Green | 環境切り替え |

### インスタンス選択（推論）

| ファミリー | 用途 |
|----------|------|
| ml.c5 | CPU推論 |
| ml.g4dn | GPU推論（コスト効率） |
| ml.inf1 | Inferentia |
| ml.inf2 | Inferentia2 |

---

## モデル監視

### SageMaker Model Monitor

**監視タイプ**

| タイプ | 説明 |
|--------|------|
| Data Quality | データドリフト検出 |
| Model Quality | 精度劣化検出 |
| Bias Drift | バイアス変化検出 |
| Feature Attribution Drift | 特徴量重要度変化 |

**ベースライン**
- トレーニングデータから統計量計算
- 制約条件の自動生成

**スケジュール**
- 定期的な監視ジョブ
- CloudWatch統合

### SageMaker Clarify

**機能**
- バイアス検出
- 説明可能性（SHAP）
- 特徴量重要度

**バイアスメトリクス**
- 事前トレーニングバイアス
- 事後トレーニングバイアス

---

## MLOps

### SageMaker Pipelines

**特徴**
- MLワークフロー自動化
- DAGベースのパイプライン
- 再利用可能なコンポーネント

**ステップタイプ**
- Processing Step
- Training Step
- Tuning Step
- Model Step
- Transform Step
- Condition Step
- Callback Step

### SageMaker Model Registry

**機能**
- モデルバージョン管理
- 承認ワークフロー
- モデルグループ化
- デプロイ履歴

**モデルステータス**
- PendingManualApproval
- Approved
- Rejected

### CI/CD統合

**パイプライン構成例**

```
CodeCommit → CodeBuild → SageMaker Pipelines
                              ↓
                         Model Registry
                              ↓
                    CodePipeline (Approval)
                              ↓
                      Endpoint Deploy
```

### SageMaker Projects

**特徴**
- MLOpsテンプレート
- Service Catalog統合
- 標準化されたプロジェクト構造

---

## セキュリティとガバナンス

### ネットワーク分離

**VPC設定**
- プライベートサブネット配置
- VPCエンドポイント使用
- セキュリティグループ設定

**ネットワーク分離モード**
- Internet Access なし
- VPCエンドポイント必須

### 暗号化

**保存時暗号化**
- S3: SSE-S3, SSE-KMS
- EBS: KMS
- ノートブック: KMS

**転送時暗号化**
- TLS 1.2
- インターコンテナ暗号化

### IAMロール

**実行ロール**
- SageMaker 用の IAM ロール
- S3、ECR、CloudWatch等へのアクセス

**最小権限の原則**
- 必要なアクションのみ許可
- リソースレベルの制限

### SageMaker Role Manager

**機能**
- MLペルソナ別の権限テンプレート
- 事前定義されたロール

**ペルソナ例**
- Data Scientist
- ML Engineer
- ML Admin

---

## コスト最適化

### 料金モデル

| モデル | 説明 |
|--------|------|
| On-Demand | 時間課金 |
| Savings Plans | 1/3年コミット割引 |
| Spot Instances | 中断可能（最大90%割引） |

### Spot トレーニング

**設定**
- チェックポイント有効化
- 最大待機時間設定
- フォールバック設定

### インファレンス最適化

**SageMaker Neo**
- モデルコンパイル
- ハードウェア最適化
- レイテンシ削減

**量子化**
- INT8/FP16
- 精度とパフォーマンスのトレードオフ

---

## 関連リファレンス

- [BEDROCK-API.md](./BEDROCK-API.md) - Amazon Bedrock API
- [GENAI-ARCHITECTURE.md](./GENAI-ARCHITECTURE.md) - 生成AIアーキテクチャ
- [DATA-ENGINEERING.md](./DATA-ENGINEERING.md) - データパイプライン
- [SECURITY.md](./SECURITY.md) - セキュリティ設定
- [COST-OPTIMIZATION.md](./COST-OPTIMIZATION.md) - コスト最適化
