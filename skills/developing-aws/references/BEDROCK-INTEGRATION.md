# Bedrock AWS統合パターンリファレンス

## 概要

Amazon Bedrockを既存のAWSインフラに統合する際のアーキテクチャパターンとベストプラクティスを解説する。Bedrockは既存スタックに組み込むことで機能を強化するサービスであり、既存システムの再構築を求めない設計になっている。

---

## API/SDK アーキテクチャ

### Control Plane vs Runtime Plane の分離

Amazon BedrockのAPIは2つの異なるドメインに分離されている。この設計はAWSの成熟したサービスが採用するアーキテクチャパターンであり、セキュリティと安定性の両立を実現する。

| 特性 | `boto3.client('bedrock')` | `boto3.client('bedrock-runtime')` |
|-----|--------------------------|----------------------------------|
| **プレーン** | Control Plane（管理） | Data Plane（推論） |
| **主な用途** | 管理・設定操作 | モデル推論実行 |
| **代表的なAPI呼び出し** | `ListFoundationModels`<br>`CreateModelCustomizationJob`<br>`CreateProvisionedModelThroughput`<br>`CreateGuardrail` | `InvokeModel`<br>`InvokeModelWithResponseStream`<br>`Converse`<br>`ConverseStream` |
| **典型的な利用シーン** | DevOpsスクリプトによるProvisioned Throughput管理 | 本番Webアプリのチャットボットバックエンド |
| **IAMアクション接頭辞** | `bedrock:*` | `bedrock-runtime:*` |
| **呼び出し頻度** | 低頻度・高信頼性 | 高頻度・低レイテンシ |

**設計上の重要な含意**: 推論スパイクはRuntime Planeに閉じ込められ、Control Planeのパフォーマンスに影響しない。高負荷時でも管理操作（Provisioned Throughputの調整等）が安定して実行できる。

### boto3クライアントの初期化

```python
import boto3
from botocore.exceptions import ClientError

aws_region = "us-east-1"

try:
    # Control Plane クライアント（管理・設定用）
    bedrock_admin = boto3.client('bedrock', region_name=aws_region)

    # Data Plane クライアント（推論実行用）
    bedrock_runtime = boto3.client('bedrock-runtime', region_name=aws_region)

except ClientError as e:
    print(f"クライアント作成エラー: {e}")
```

### IAM 最小権限設計

| ロール | 必要な権限 | 禁止する権限 |
|-------|-----------|-------------|
| **本番アプリ（Lambda実行ロール）** | `bedrock-runtime:InvokeModel`<br>`bedrock-runtime:InvokeModelWithResponseStream`<br>`bedrock-runtime:Converse` | `bedrock:*`（管理操作）<br>ファインチューニングジョブの作成 |
| **CI/CDパイプラインロール** | `bedrock:CreateProvisionedModelThroughput`<br>`bedrock:ListFoundationModels`<br>`bedrock:CreateGuardrail` | `bedrock-runtime:InvokeModel`（推論実行） |

---

## アーキテクチャパターン選択

AWSサービスと統合する前に最初に決定すべきことは「バッチ処理」か「リアルタイム処理」かの選択である。この選択が使用するサービス構成、コストモデル、スケーリング戦略を決定する。

| 特性 | バッチ推論アーキテクチャ | リアルタイム推論アーキテクチャ |
|-----|---------------------|--------------------------|
| **主な用途** | 大規模データセットの非同期処理（文書要約、データ分類、埋め込み生成） | インタラクティブな低レイテンシアプリ（チャットボット、バーチャルアシスタント） |
| **レイテンシ** | 分〜時間単位（リアルタイム対話には不適） | ミリ秒〜秒単位（即時レスポンス設計） |
| **コストモデル** | スループット最適化（最大50%削減可能） | オンデマンド課金（リクエスト/トークン単位） |
| **コアサービス構成** | S3・Lambda・DynamoDB・EventBridge・Bedrock Batch Inference API（`CreateModelInvocationJob`） | API Gateway・Lambda・DynamoDB・Bedrock Converse/InvokeModel API |
| **スケーリング** | ジョブキューイングと並列処理 | Lambdaの同時実行とAPI Gatewayスロットリング |
| **エラーハンドリング** | DynamoDBでジョブステータス追跡、EventBridge+Lambdaでリトライ管理 | Lambda内の同期エラーハンドリング |

---

## サービス統合パターン

### S3統合

S3はBedrockアーキテクチャにおける中央データハブとして3つの役割を担う。

1. **バッチ推論の入出力**: 入力ファイルをJSONL形式（`.jsonl`）でステージングし、出力も`.jsonl`で指定S3ロケーションに書き込まれる
2. **モデルカスタマイズのトレーニングデータ**: ファインチューニングや蒸留ジョブ用の学習・検証データセットのストレージ
3. **Knowledge Basesのデータソース**: RAGアプリケーション向けのソースドキュメントリポジトリ（Bedrockが自動的にインジェスト・チャンク・ベクトル化）

**アーキテクチャ必須要件**:
- Bedrockが信頼するIAMロールにS3バケット/プレフィックスの最小権限読み書き権限を付与
- KMS暗号化を有効化し、Bedrock実行ロールがKMSキーにアクセス可能なキーポリシーを設定
- エンタープライズ環境ではVPCエンドポイント経由でS3アクセスをルーティング（ゼロトラストネットワーク原則）

---

### Lambda統合

#### シンプルなバッチ文書処理パターン（入門）

```
S3（文書アップロード）
  → S3 ObjectCreated イベント
  → Lambda（処理ロジック）
    - S3から文書を取得
    - Bedrockにサマリー要求（InvokeModel / Converse API）
    - 結果をDynamoDBに書き込み（文書キー・サマリー・タイムスタンプ・モデルバージョン）
```

**制限事項（本番環境での落とし穴）**:
- Lambda最大実行タイムアウトは15分。大規模文書や複雑なモデル呼び出しでタイムアウトリスク
- 1000件の同時アップロードが1000件の同時Lambda実行を引き起こし、Bedrockエンドポイントをスロットリングする
- コスト・同時実行の管理が困難になる

#### 本番対応バッチアーキテクチャ

シンプルなパターンの制限を克服する本番対応パターン：

```
S3（文書アップロード）
  → ObjectCreated イベント
  → Lambda A（エンキュー専用：ジョブエントリをDynamoDB/SQSに追加）
  → EventBridge Scheduler（定期実行、例：15分間隔）
  → Lambda B（バッチ送信：保留ジョブをバンドルしてBedrock Batch Inference APIに投入）
  → Bedrock Batch Inference API（CreateModelInvocationJob）
  → S3（バッチ出力）
```

この「S3 → Lambda（エンキュー）→ Queue → EventBridge Scheduler → Lambda（バッチ送信）→ Bedrock → S3」パターンは、本番環境での信頼性・スケーラビリティ・コスト効率を大幅に向上させる。

#### Lambda設計のベストプラクティス

| 設定項目 | 推奨値 | 理由 |
|---------|-------|------|
| **タイムアウト** | 30秒〜5分（ユースケース依存） | Bedrock推論の想定レイテンシ + マージン |
| **メモリ** | 512MB〜1GB以上 | 大規模文書処理時のメモリ不足対策 |
| **Dead Letter Queue（DLQ）** | 必須設定 | 失敗したイベントの消失防止 |
| **IAM実行ロール** | `bedrock-runtime:InvokeModel`のみ付与 | 最小権限原則 |
| **環境変数** | modelId・リージョンを外部化 | コード変更なしでモデル切り替え可能 |

---

### API Gateway統合

フロントエンドWebアプリ・モバイルクライアント・サードパーティサービスにBedrockの推論機能を公開する場合の標準パターン：

```
API Gateway（REST APIエンドポイント: POST /chatbot）
  → 認証（IAM / Cognito JWT / API Key）
  → Lambda（ビジネスロジック: プロンプト構築・Bedrock呼び出し）
  → Amazon Bedrock（InvokeModel / Converse API）
  → Lambda（レスポンス処理）
  → API Gateway（クライアントへの返却）
```

**このパターンのメリット**:
- **デカップリング**: フロントエンドはBedrock・使用モデル・内部ロジックを知る必要がない
- **セキュリティ**: API Gatewayが認証・認可の強制ポイントとなる
- **スケーラビリティ**: API Gateway + Lambdaはサーバーレスで自動スケーリング
- **管理機能**: リクエスト/レスポンス変換、キャッシング、スロットリングが組み込まれている

#### 認証戦略

| 用途 | 推奨認証方式 | 理由 |
|-----|------------|------|
| **本番バックエンドのサービス間通信** | IAMロール（SigV4署名） | 最もセキュアな方式。LambdaがIAM実行ロールを引き受け`bedrock:InvokeModel`権限で呼び出し |
| **開発者ツール・CLI・ローカル実験** | Short-Term API Keys（IAMセッション資格情報から動的生成） | 利便性とセキュリティのバランス。最大12時間で自動失効 |
| **Long-Term API Keys** | 極力使用しない | ソースコードへの誤コミットリスク。初期探索・サードパーティ統合にのみ限定使用 |

---

### リアルタイムチャットボット（コンテキスト対応）

API Gateway + Lambda + DynamoDB + Bedrockを組み合わせたステートフル会話アーキテクチャ：

```
1. ユーザー入力
   クライアント → POST /chat（メッセージ + session_id）

2. API Gateway
   → 認証処理
   → Lambda関数を呼び出し

3. Lambda内部フロー
   a. session_idでDynamoDBから直近N件の会話履歴を取得
   b. 会話履歴と新規メッセージを組み合わせてプロンプト構築（コンテキスト付与）
   c. Bedrock Converse API呼び出し（コンテキスト付きプロンプト）
   d. 生成されたレスポンスをDynamoDBに保存（ユーザーメッセージ + AI応答を同じsession_idで記録）

4. 返却
   Lambda → API Gateway → クライアント（AIレスポンス文字列のみ）
```

**DynamoDB会話履歴の設計**:
- パーティションキー: `session_id`（高カーディナリティ・メインアクセスパターンに合致）
- ソートキー: `timestamp`（時系列取得のため）
- TTL属性: セッション終了後の自動削除（コスト最適化）
- Pythonでの実装にはLangChainの`DynamoDBChatMessageHistory`クラスが推奨（PutItem/Queryの実装不要）

---

### EventBridge統合

EventBridgeは3種類のトリガーパターンでBedrockワークフローを起動する。

#### スケジュールベーストリガー（定期バッチジョブ）

```python
# EventBridge Schedulerルール設定例
# cron(0 17 ? * FRI *)  # 毎週金曜17時に実行
# ターゲット: Lambda関数（CRMデータ取得 → Bedrock推論 → DynamoDB/SNS出力）
```

**ユースケース**: 週次CRMインサイト自動生成、日次データサマリー、夜間レポート生成

#### イベントベーストリガー（リアクティブ処理）

| トリガー元 | Bedrockワークフロー |
|-----------|------------------|
| S3 ObjectCreated | 新規文書のリアルタイム要約・分類 |
| DynamoDBストリーム | レコード更新時のAI分析 |
| SQSキュー | メッセージ到着時のインテリジェント処理 |
| EventBridgeカスタムイベント | アプリケーションイベント駆動AI処理 |

#### CI/CDパイプライントリガー

プロンプトテンプレートをGitで管理し、変更時にCI/CDパイプラインが自動デプロイするパターン：

```
プロンプトファイル変更（prompts/ ディレクトリ）
  → Git Push
  → CodePipeline / GitHub Actions
  → S3にプロンプトファイルをデプロイ
  → サンプル入力でBedrock呼び出してリグレッションテスト
  → 合格後に本番環境へプロモート
```

---

### SageMaker統合

BedrockとSageMakerは競合ではなく、抽象化レベルと制御粒度のスペクトラム上にある補完的なサービスである。

| 判断要素 | Amazon Bedrock | Amazon SageMaker | 組み合わせが最適なケース |
|---------|---------------|-----------------|---------------------|
| **主な用途** | 事前学習済みFMのシンプルなAPI利用。RAG・Agents・マネージドファインチューニング | カスタムMLモデルのゼロからの構築・学習・デプロイ。完全なMLOpsライフサイクル管理 | カスタムな前処理・後処理ロジックをBedrock API呼び出しにラップしたい場合 |
| **制御とインフラ** | サーバーレス・フルマネージド。インフラ管理不要 | コンピュートインスタンス・コンテナ・ネットワークの完全制御 | Bedrockでコア生成タスク、SageMakerで特化チェーンタスク |
| **対象ユーザー** | アプリ開発者・ビルダー。深いML知識不要 | データサイエンティスト・MLエンジニア。深いML知識が必要 | 開発者がBedrock APIを使い、データサイエンティストがSageMakerでカスタムモデルを構築するコラボチーム |
| **モデル選択** | AmazonおよびパートナーのキュレートされたFMリスト | SageMaker JumpStart経由の豊富なオープンソースモデル + カスタムモデル | SageMakerホストモデルをBedrock AgentのツールやFlowのコンポーネントとして利用 |

#### PIIチェーニングパターン（Bedrock + SageMaker実践例）

複数サービスをチェーンして複合ワークフローを実現するパターン：

```
1. Bedrockでユーザー会話サマリーを生成
2. 生成されたテキストを以下のいずれかに渡す:
   a. SageMakerエンドポイント（PII検出特化のカスタム学習モデル / JumpStart微調整済みモデル）
   b. Amazon Comprehend（標準的なPII検出・リダクションAPI）
   c. Bedrock Guardrails（PIIリダクション機能をネイティブに実行）
3. PIIを除去したサマリーを安全に保存・分析
```

このパターンにより、FMのコア生成能力を特化モデルのカスタムロジックで拡張できる。

#### SageMaker Unified Studio統合

SageMaker Unified Studio内の **Bedrock Flows** を使用することで、プロンプト・モデル・Knowledge Bases・Lambda関数・SageMakerエンドポイントをビジュアルなドラッグ&ドロップでワークフローに接続できる。プロトタイピングと開発者/ビジネスステークホルダー間のコラボレーションに適している。

---

## ワークフロー自動化

### GenAIワークフロー自動化の定義

従来のワークフロー自動化（ルールベースの決定論的処理）とGenAIワークフロー自動化の違い：

| 従来のワークフロー | GenAIワークフロー |
|----------------|----------------|
| `IF チケットに"返金"という単語 → 請求部門にルーティング` | `チケット提出時、Bedrockモデルで問題を要約・感情分析し、顧客履歴に基づく共感的な返信案を生成 → サマリーと下書きを最適なエージェントにルーティング` |
| ルールベース・決定論的 | 推論・適応・コンテンツ生成を伴う |
| シンプルで剛直 | 複雑・曖昧さに対応・新規コンテンツ生成 |

### Step Functionsによるマルチステップオーケストレーション

複数のAI呼び出しや分岐点を含むワークフローにはStep Functionsを使用する。

**重要な注意点**: Step Functionsはタスクレベル（Lambdaの呼び出し）でリトライを行うため、Bedrock固有のスロットリング・レート制限・一時的なモデルエラーは**Lambda内部で個別に対処**する必要がある（Exponential Backoff + Jitter実装）。Step Functionsはより高いレベルで機能し、失敗が伝播した際にLambdaを再呼び出し、またはワークロードが並列実行パスに展開する際の調整を行う。

```
[データ取得Lambda]
  → [Bedrock推論Lambda（エラーハンドリング + リトライ内包）]
  → [結果保存Lambda]
  （エラー時: Catch → [エラー通知Lambda]）
```

**メリット**: 状態管理・エラーハンドリング・リトライが一元化され、ワークフローロジックが個別のLambda関数の外部に移動し、保守性と信頼性が向上する。

---

## バッチ vs ストリーミング設計

| モード | ユースケース | トリガー機構 | 設計上の考慮事項 |
|-------|-----------|------------|---------------|
| **バッチ** | 大規模な定期ジョブ（時間非敏感）<br>週次レポート・夜次データ集計 | スケジュールトリガー（EventBridgeのcronルール）<br>大容量ファイルドロップ | 多数アイテムの並列処理が必要（Step Functions・Lambdaコンカレンシー）<br>バッチ実行中のモデルスナップショット/設定の一貫性を確保<br>総実行時間の監視とスループット最適化 |
| **ストリーミング** | 継続的なリアルタイム処理（低レイテンシ要求）<br>ライブチャットレスポンス・イベント駆動予測 | イベントベーストリガー（S3イベント・Kinesisストリーム・APIゲートウェイオンデマンド呼び出し） | バースト対応: Lambdaコンカレンシーと冪等性の確保<br>低レイテンシ重視: Bedrockのレスポンスストリーミング活用（token-level配信）<br>スロットリング監視: リトライ/バックオフの実装 |

多くの本番システムではバッチとストリーミングを組み合わせる（個別イベントのリアルタイム推論 + 集計レポートのバッチジョブ）。

---

## ベストプラクティス

### 1. モジュラリティ原則

BedrockをモノリシックなAIブロックとして扱わず、既存のデカップルされたシステムのサービスとして組み込む。Bedrock呼び出しの中核ロジックを独立したマイクロサービスに集中させることで:
- コンポーネントの独立スケーリングが可能
- コードの再利用によって冗長性を排除
- アジャイルチームによる独立開発・デプロイを実現

### 2. プロンプトをコードとして管理（Prompts as Code）

プロンプトをLambda関数にハードコードせず、外部化して動的に読み込む。

| 管理方式 | 実装方法 | メリット |
|---------|---------|---------|
| **ファイルストレージ** | S3にプロンプトファイル（YAML/JSON）を保管 | コード再デプロイなしで更新可能 |
| **バージョニング** | Semantic Versioning（MAJOR.MINOR.PATCH）で変更の影響を明示 | ロールバックと変更追跡が容易 |
| **Git管理** | プルリクエストワークフローによるレビュープロセス | 変更の文書化・査読・自動テストの実施 |
| **環境分離** | dev/staging/prod用のブランチ/フォルダ分離 | 環境ごとの適切なプロンプトバージョンを展開 |

### 3. 認証のゴールデンスタンダード

- **バックエンドのサービス間通信**: 必ずIAMロールを使用（最も安全で管理しやすいパターン）
- **開発者ツール・ローカル実験**: Short-Term API Keys（IAMセッション資格情報から動的生成、最大12時間）
- **Long-Term API Keys**: 本番コードに埋め込み禁止。初期探索・サードパーティ統合にのみ極めて慎重に使用

### 4. DynamoDB設計のベストプラクティス（Bedrockとの組み合わせ）

- **パーティションキー設計**: メインアクセスパターン（「このジョブのステータスを取得」→ `job_id`、「この会話のメッセージを取得」→ `session_id`）に合致した高カーディナリティキーを選択
- **TTL活用**: チャット履歴やバッチジョブログなど陳腐化するデータにTTL属性を設定し、自動削除でストレージコストを最適化
- **LangChain活用**: Python環境では`DynamoDBChatMessageHistory`クラスでPutItem/Queryの実装を省略

### 5. 監視・モニタリング

```python
# カスタムメトリクス例: Lambda内でBedrockレイテンシを計測してCloudWatchに発行
import time
import boto3

cloudwatch = boto3.client('cloudwatch')
start_time = time.time()

response = bedrock_runtime.invoke_model(...)

latency_ms = (time.time() - start_time) * 1000
cloudwatch.put_metric_data(
    Namespace='MyApp/Bedrock',
    MetricData=[{
        'MetricName': 'InvocationLatency',
        'Value': latency_ms,
        'Unit': 'Milliseconds'
    }]
)
```

バッチ・ストリーミングともにCloudWatch LogsとMetricsでBedrock呼び出し時間・成功率・失敗率・コンカレンシーを追跡する。カスタムメトリクスでスパイク時のアラームを設定し、過負荷や新バージョンの性能劣化を早期検知する。

---

## 統合アンチパターン

### アンチパターン1: 同期呼び出しの過剰使用

**問題**: 大量のS3ファイルに対してLambdaを直接S3イベントトリガーで1:1同期呼び出しするパターン
- 1000ファイルの同時アップロード → 1000の同時Lambda実行 → Bedrockエンドポイントのスロットリング
- Lambda 15分タイムアウトの超過リスク
- コストと同時実行の制御不能

**解決策**: キューイング機構（DynamoDB/SQS）+ EventBridge Schedulerによる定期バッチ送信パターンに移行

### アンチパターン2: 不十分なエラーハンドリング

**問題**: Step Functionsのタスクレベルリトライのみに依存し、Lambda内にBedrock固有のエラーハンドリングがない
- ThrottlingExceptionはLambda内部で処理されずStep Functionsに伝播
- Exponential Backoff + Jitterなしのシンプルリトライが過負荷を増幅

**解決策**: Lambda内で以下のBedrock固有エラーを個別に処理する

```python
from botocore.exceptions import ClientError
import time
import random

def invoke_with_retry(bedrock_client, model_id, request_body, max_retries=3):
    for attempt in range(max_retries):
        try:
            return bedrock_client.invoke_model(
                modelId=model_id,
                body=request_body
            )
        except ClientError as e:
            error_code = e.response['Error']['Code']
            if error_code == 'ThrottlingException':
                # Exponential Backoff + Jitter
                wait_time = (2 ** attempt) + random.uniform(0, 1)
                time.sleep(wait_time)
                if attempt == max_retries - 1:
                    raise
            elif error_code == 'ModelNotReadyException':
                time.sleep(5)
            else:
                raise
```

### アンチパターン3: プロンプトのハードコーディング

**問題**: Lambda関数のコード内にプロンプトを埋め込む
- プロンプト更新のたびにコードの再デプロイが必要
- 非技術者がプロンプト改善に参加できない
- A/Bテストやロールバックが困難

**解決策**: S3/Systems Manager Parameter StoreにプロンプトテンプレートをYAML/JSON形式で外部化し、Lambda実行時に動的にロード

### アンチパターン4: 用途に関係なく最大モデルを選択

**問題**: 全タスクにClaude Opusのような最高コストのモデルを使用
- 簡単な分類タスクに高コストモデルが過剰品質
- コスト構造が不必要に高い

**解決策**: タスクの複雑さに応じてモデルを選定する
- シンプルな分類・要約 → Claude Haiku / Titan Text Express（低コスト・高速）
- 汎用テキスト生成 → Claude Sonnet / Llama 70B（バランス重視）
- 複雑な推論・高品質出力 → Claude Opus / Llama 405B（コスト許容時のみ）

---

## 関連リファレンス

- `BEDROCK-API.md` — Foundation Modelの種類、API仕様（InvokeModel/Converse）、プロンプトエンジニアリング基礎、SDK統合（LangChain/LlamaIndex）
- `BEDROCK-SCALING.md` — 信頼性・パフォーマンス・コスト・可観測性・UXの5柱スケーリングフレームワーク
- `GENAI-ARCHITECTURE.md` — GenAIアーキテクチャの基本設計原則、Provisioned Throughput、ストリーミング
