# クラウドネイティブ実践アプリ実装パターン集

モバイル・IoT・リアルタイム分析を中心とした、AWSクラウドネイティブアプリの11種の実装パターン。
AWSサービスの組み合わせ・データフロー・設計判断軸を言語非依存のアーキテクチャ観点で整理。

> **関連ファイル**: `DESIGN-CASE-STUDIES.md` は大規模汎用サービス（URL短縮・検索エンジン等）の設計を扱う。本ファイルはモバイル/IoT時代の実践的なアプリ実装パターンに特化。

---

## パターン概要一覧

| # | パターン名 | 主要サービス | 分類 |
|---|-----------|------------|------|
| 4-1 | Cognito+S3+SNS 写真共有アプリ | Cognito, S3, SNS | モバイル / 認証 |
| 4-2 | API Gateway+Lambda サーバ連携モバイルアプリ | API Gateway, Lambda, DynamoDB, S3 | モバイル / 3-Tier |
| 4-3 | API Gateway+Cognito+Lambda 認証・認可サービス | API Gateway, Lambda, Cognito, IAM, DynamoDB | 認証・認可 |
| 4-4 | API Gateway スタブAPI（モック） | API Gateway, Lambda, S3 | 開発効率化 |
| 4-5 | DynamoDB+ウェアラブル 健康情報収集 | API Gateway, Lambda, DynamoDB Triggers, Elasticsearch | IoT / 可視化 |
| 4-6 | iBeacon+Lambda+DynamoDB 勤怠管理 | Cognito, API Gateway, Lambda, DynamoDB | IoT / BLE |
| 4-7 | Device Farm 多端末自動テスト | Device Farm | テスト自動化 |
| 4-8 | S3+Lambda イベント駆動キュレーション | Lambda, S3 | サーバーレス / 定期実行 |
| 4-9 | Kinesis+DynamoDB Streams リアルタイムデータ収集 | Kinesis Streams, DynamoDB, DynamoDB Streams | リアルタイム |
| 4-10 | Machine Learning 予測サービス | API Gateway, Lambda, DynamoDB, Amazon ML | AI / 機械学習 |
| 4-11 | Cognito Sync データ同期メモアプリ | Cognito Sync | モバイル / データ同期 |

---

## アーキテクチャ構成パターン比較

| パターン | Tier構成 | 認証 | データ永続化 | リアルタイム性 |
|---------|---------|------|------------|-------------|
| 4-1 | 2-Tier (直接SDK) | Cognito (Federation) | S3 | SNS Push |
| 4-2 | 3-Tier (API Gateway) | なし | S3 (静的) + DynamoDB (動的) | なし |
| 4-3 | 3-Tier | Cognito + OAuth 2.0 | DynamoDB | なし |
| 4-4 | 3-Tier (スタブ) | なし | S3 (JSONファイル) | なし |
| 4-5 | 3-Tier | なし (開発者1人) | DynamoDB + Elasticsearch | Kibana可視化 |
| 4-6 | 3-Tier | Cognito 独自認証 | DynamoDB | BLEイベント |
| 4-7 | クラウドテスト基盤 | IAM | なし (テスト結果) | CI/CD連携 |
| 4-8 | イベント駆動 | なし | S3 (RSS) | 定期バッチ |
| 4-9 | ストリーミング | なし | DynamoDB | Kinesis + DynamoDB Streams |
| 4-10 | 3-Tier + ML | なし | DynamoDB + S3 (教師データ) | 推論リアルタイム |
| 4-11 | 2-Tier (直接SDK) | Cognito (Federation) | Cognito Sync データセット | 端末間同期 |

---

## 各パターン詳細

### Pattern 4-1: Cognito+S3+SNS 写真共有アプリ

スマートフォンのカメラで撮影した写真を他ユーザーと共有するアプリ。SNSプッシュ通知で写真共有を通知する。

#### 使用AWSサービス

| サービス | 役割 |
|---------|------|
| Amazon Cognito | Facebook認証 / IAMロール付与 |
| Amazon S3 | 写真のアップロード・ダウンロード先 |
| Amazon SNS | モバイルプッシュ通知 (APNS/GCM) |

#### アーキテクチャ構成

```
認証プロバイダ (Facebook)
        ↓ ①ログイン
スマートフォンアプリ
        ↓ ②検証・認証依頼
Amazon Cognito
        ↓ ③IAMロール付与
        ↓
   [認証済みユーザーのみ許可]
        ↓
     Amazon S3         Amazon SNS
        ↑↓                 ↑
写真アップ/ダウン    プッシュ通知送信請求
        ↓                  ↓
                  通知プロバイダ (APNS/GCM)
                           ↓
                  他のスマートフォン
                  (プッシュ通知受信)
```

#### データフロー

1. Facebookにログイン → アクセストークン取得
2. Cognitoに検証依頼 → 認証済みIAMロール取得
3. S3バケットに写真をアップロード (UUID付きファイル名で重複回避)
4. SNSトピックに通知メッセージを発行 (ユーザーID + ファイル名を含む)
5. SNSがAPNS/GCMへプッシュ通知送信
6. 通知を受信したユーザーがアプリ起動 → S3から写真ダウンロード

#### 実装ポイント

| ポイント | 内容 |
|---------|------|
| Cognitoロール分離 | 認証済みユーザー / 未認証ユーザーに別IAMロールを割り当て |
| S3アクセス制御 | 未認証ユーザーはS3リソースにアクセス不可 |
| ファイル名衝突回避 | UUIDをファイル名に付与 |
| プッシュ通知の代替設計 | 本来はS3イベント→Lambda→SNSが望ましい (本例はクライアント直接呼び出し) |

---

### Pattern 4-2: API Gateway+Lambda サーバ連携モバイルアプリ

静的データと動的データを使い分けるAndroidアプリ。静的なリスト表示はS3、動的な詳細表示はAPI Gateway+Lambda+DynamoDBで実現。

#### 使用AWSサービス

| サービス | 役割 |
|---------|------|
| Amazon S3 | リスト用静的JSONファイルのホスティング |
| Amazon API Gateway | 動的データ取得APIのエンドポイント |
| AWS Lambda | DynamoDBからの動的データ取得処理 |
| Amazon DynamoDB | 動的データの永続化 |

#### アーキテクチャ構成

```
モバイルクライアント (Android)
    │
    ├─ ① S3リクエスト ──────────────────→ Amazon S3
    │       ← リストJSON取得 ───────────────────┘
    │
    └─ ② API Gatewayリクエスト ─────────→ API Gateway
              (アイテムID付き)                    ↓
              ← 詳細JSON取得 ←────────────   Lambda
                                               ↓
                                          DynamoDB
```

#### データフロー

1. モバイルアプリ起動 → S3からリスト用JSONを取得・表示
2. ユーザーがリストアイテムを選択 → アイテムIDをパラメータにAPI Gatewayへリクエスト
3. API GatewayがLambda Functionを呼び出し
4. LambdaがDynamoDBから詳細データを取得・返却
5. モバイルアプリが詳細画面を表示

#### 実装ポイント

| ポイント | 内容 |
|---------|------|
| 静的/動的の使い分け | 頻繁に変わらないリストはS3、頻繁に更新される詳細はDynamoDB |
| ライブラリ | Android: Volley (HTTP通信) + Gson (JSON解析) |
| セキュリティ | インターネット通信パーミッション設定必須 |

---

### Pattern 4-3: API Gateway+Cognito+Lambda 認証・認可サービス

Cognitoへの認証をLambda経由で行うことで、フロントエンドからAWS依存を隠蔽しつつ細かい認可制御を実現するパターン。

#### 使用AWSサービス

| サービス | 役割 |
|---------|------|
| Amazon API Gateway | 認証APIのエンドポイント |
| AWS Lambda | Cognito認証・認可ロジック |
| Amazon Cognito | Identity Federation / IAMロール付与 |
| AWS IAM | ロールベースのアクセス制御 |
| Amazon DynamoDB | ユーザー情報・ロール情報の管理 |

#### アーキテクチャ構成

```
認証プロバイダ (Google / Facebook / Twitter等)
        ↓ ①認証
        ↓ ②アクセストークン取得
モバイル / フロントエンドアプリ
        ↓ ③トークンをリクエストに含めAPI Gatewayへ送信
Amazon API Gateway
        ↓ ④Lambda呼び出し
AWS Lambda
        ↓ ⑤トークンの有効性確認
Amazon Cognito
        ↓ ⑥確認結果返却
        ↓ ⑦IAMロール付与
Lambda (認可ロジック)
        ↓ ⑧ユーザー情報保存・取得
Amazon DynamoDB
        ↓ ⑨処理結果返却
```

#### データフロー

1. OAuth 2.0プロバイダ (Google等) でユーザー認証 → トークン取得
2. APIリクエストにトークンを付与してAPI Gatewayへ送信
3. Lambda がトークンをCognitoに渡してID検証
4. Cognitoが検証結果とIAMロールを返却
5. Lambda がDynamoDBにユーザー情報を保存 (`role` フィールドで権限管理)
6. 細かい認可制御はLambda内で実装

#### 実装ポイント

| ポイント | 内容 |
|---------|------|
| AWS依存の隠蔽 | Lambdaで認証処理を包むことでクライアントはAWSを意識しない |
| 細粒度認可 | CognitoのIAMロールは粗粒度、Lambda内でユーザー毎の細粒度制御を追加 |
| 認証プロバイダ設定 | Google: OAuth 2.0 Client ID + IAM IDプロバイダへの登録が必要 |
| Cognito設定順序 | ①OAuthプロバイダ登録 → ②IAM IDプロバイダ登録 → ③Cognito Identity Pool作成 |

---

### Pattern 4-4: API Gateway スタブAPI（モック）

本番APIが未完成の段階でモバイル開発を進めるためのスタブAPI。S3に静的JSONを置き、API Gateway+Lambdaで返却する。

#### 使用AWSサービス

| サービス | 役割 |
|---------|------|
| Amazon API Gateway | スタブAPIエンドポイント / モデル・マッピングテンプレート |
| AWS Lambda | S3からJSONを取得して返却 |
| Amazon S3 | テストデータ用JSONファイルの保存 |

#### アーキテクチャ構成

```
モバイルアプリ (開発中)
        ↓ APIリクエスト
Amazon API Gateway
   ├─ モデル定義 (スキーマ)
   └─ マッピングテンプレート (ステータスコード変換)
        ↓
AWS Lambda
        ↓ S3からJSON取得
Amazon S3
└─ テストデータ (test.json 等)
```

#### データフロー

1. S3バケットにテストデータ用JSONを配置 (`Content-Type: application/json` 設定)
2. Lambda Function がバケット名・キーを受け取り S3からJSON取得
3. API GatewayでLambdaを統合 → スタブAPIエンドポイントを公開
4. マッピングテンプレートで任意のHTTPステータスコードを返却 (テストフェーズ用)

#### 実装ポイント

| ポイント | 内容 |
|---------|------|
| 利用シーン | 本番API未完成時の並行開発、テストフェーズのエラーコードシミュレーション |
| HTTPステータス変更 | API Gatewayのモデル + マッピングテンプレートで200以外のコードを返却 |
| 本番切り替え | API GatewayのステージとLambdaエイリアスで環境切り替え |
| S3ファイル更新 | JSONファイルを差し替えるだけでスタブデータを更新可能 |

---

### Pattern 4-5: DynamoDB+ウェアラブル 健康情報収集

Apple Watchから心拍数を収集してDynamoDBに保存し、DynamoDB Streams経由でElasticsearch+Kibanaで可視化する3-Tierパターン。

#### 使用AWSサービス

| サービス | 役割 |
|---------|------|
| Amazon API Gateway | iOSアプリからのデータ受付エンドポイント |
| AWS Lambda | DynamoDBへのデータ書き込み / Elasticsearchへの転送 |
| Amazon DynamoDB | 心拍数データの永続化 |
| DynamoDB Triggers (Streams) | データ追加イベントでLambdaを起動 |
| Amazon Elasticsearch Service | データのインデックス化・検索 |
| Kibana | データ可視化ダッシュボード |

#### アーキテクチャ構成

```
Apple Watch
        ↓ WatchConnectivity (WatchOS 2)
iPhone (HealthKit)
        ↓ 送信ボタン押下時 → HTTP POST
Amazon API Gateway
        ↓
AWS Lambda (データ書き込み)
        ↓ putItem
Amazon DynamoDB
        ↓ DynamoDB Triggers (Streams)
AWS Lambda (データ転送)
        ↓
Amazon Elasticsearch Service
        ↓
Kibana (可視化)
```

#### データフロー

1. Apple WatchがHealthKitから心拍数データを取得
2. WatchConnectivityでiPhoneアプリに心拍数を通知
3. iPhoneアプリが送信ボタン押下を検知 → API GatewayへPOST
4. LambdaがDynamoDBにデータをputItem
5. DynamoDB TriggersがLambdaを起動 → データをElasticsearchへ転送
6. KibanaでリアルタイムにグラフやチャートでData可視化

#### 実装ポイント

| ポイント | 内容 |
|---------|------|
| WatchConnectivity | watchOS 2から利用可能なWatch-iPhone間通信フレームワーク |
| DynamoDB Streams活用 | データ追加イベントを契機にElasticsearchへの転送をトリガー |
| Kibana統合 | Elasticsearch ServiceにはKibanaプラグインが組み込み済み |
| スケール考慮 | 今回は単一ユーザー想定、複数ユーザー対応は別途設計が必要 |

---

### Pattern 4-6: iBeacon+Lambda+DynamoDB 勤怠管理

BLE iBeaconを活用してオフィスへの入室を自動検出し、勤怠情報をDynamoDBに記録するパターン。Cognito独自認証で認可を実現。

#### 使用AWSサービス

| サービス | 役割 |
|---------|------|
| Amazon Cognito | 独自認証 (Developer Authenticated Identities) |
| Amazon API Gateway | ログイン・勤怠情報APIのエンドポイント |
| AWS Lambda | 認証ロジック / 勤怠登録・取得ロジック |
| Amazon DynamoDB | ユーザーテーブル / 勤怠テーブル |

#### アーキテクチャ構成

```
iBeacon (BLE / オフィス設置)
        ↓ ビーコン受信 (Bluetooth Low Energy)
モバイルアプリ (iOS / Android)
        ├─ ①ログイン (ユーザーID + パスワード)
        ├─ ②出社登録 (iBeacon近接時に自動)
        └─ ③勤怠情報取得
                ↓ API呼び出し
Amazon API Gateway
        ↓ Lambda呼び出し
AWS Lambda
    ├─ 認証処理: ユーザー情報 → DynamoDB照合 → Cognitoトークン取得
    ├─ 出社登録: ユーザーID + 登録日 → DynamoDB書き込み
    └─ 勤怠取得: ユーザーID → DynamoDB検索
        ↓
Amazon DynamoDB
    ├─ ユーザーテーブル (ユーザーID, ユーザー名, パスワード)
    └─ 勤怠テーブル (ユーザーID, 登録日)
```

#### データフロー

1. アプリ起動・ログイン → Lambda経由でユーザー情報をDynamoDBで照合
2. Cognito Developer Authenticated Identitiesでトークン取得 → IAMロール付与
3. iBeaconのUUID/Major/Minorを受信してオフィス認識
4. ログイン済みの状態でビーコン受信 → 自動で出社登録APIを呼び出し
5. DynamoDBに `{ユーザーID, 登録日}` を書き込み
6. 勤怠確認: 当日レコードがあれば「出勤」、なければ「欠勤」と判定

#### iBeacon識別パラメータ

| パラメータ | 概要 | 例 |
|-----------|------|-----|
| UUID | ビーコン領域 (ビル・組織単位) | `550e8400-e29b-41d4-a716-446655440000` |
| Major | 区域 (フロア・部門単位) | `1` (1F) |
| Minor | 個別ビーコン識別 | `1` (入口) |

#### 実装ポイント

| ポイント | 内容 |
|---------|------|
| Cognito独自認証 | Developer Authenticated Identities で自社のユーザーDB認証とCognitoを連携 |
| 技適マーク確認 | 日本国内使用のiBeaconモジュールは技術基準適合証明が必要 |
| パスワード管理 | 本番環境では平文保存禁止 (ハッシュ化必須) |
| SDK生成 | API Gatewayの「SDK Generation」でiOS/Android向けSDKを自動生成可能 |

---

### Pattern 4-7: Device Farm 多端末自動テスト

クラウド上の実機を使ってAndroid/iOS/FireOSアプリを多端末同時にテスト。CIツールと連携して自動化。

#### 使用AWSサービス

| サービス | 役割 |
|---------|------|
| AWS Device Farm | クラウド実機テスト環境の提供 |

#### アーキテクチャ構成

```
開発者
        ↓ コミット / Push
CIツール (Jenkins / CircleCI等)
        ↓ Device Farm API呼び出し
AWS Device Farm
    ├─ Android端末群
    │   ├─ Built-in:Explorer
    │   ├─ Built-in:Fuzz
    │   ├─ Appium Java JUnit
    │   ├─ Appium Java TestNG
    │   ├─ Calabash
    │   ├─ Instrumentation
    │   └─ uiautomator
    └─ iOS端末群
        ├─ Built-in:Fuzz
        ├─ Appium Java JUnit
        └─ Appium Java TestNG
        ↓
テスト結果 (スクリーンショット / ログ / レポート)
```

#### テストタイプ別の使い分け

| テストタイプ | 目的 | 向いているバグ |
|------------|------|--------------|
| Explorer | UI自動操作 (ログイン対応) | 機種依存・OS依存クラッシュ |
| Fuzz | ランダム操作 (モンキーテスト) | ランダム入力クラッシュ |
| Appium JUnit | メソッド単位のユニットテスト | 入出力仕様違反 |
| Appium TestNG | シナリオ結合テスト | リグレッション |
| Calabash | BDD (Cucumber形式) | ユーザーシナリオ違反 |
| Instrumentation | Androidライフサイクル制御 | ライフサイクル起因のクラッシュ |

#### 実装ポイント

| ポイント | 内容 |
|---------|------|
| CI連携 | Device Farm APIを通じてすべてのコンソール操作を自動化可能 |
| 完全従量制 | 端末分×時間で課金 |
| iOSテスト対応 | クラウドテストサービスの中でもiOS対応は希少 |
| テスト戦略 | Explorer/Fuzz = モンキーテスト、JUnit = ユニット、TestNG = 退行テスト |

---

### Pattern 4-8: S3+Lambda イベント駆動キュレーション

複数の外部フィード (Google / Twitter) をLambdaが定期実行で集約し、S3に保存するサーバーレスキュレーションサービス。

#### 使用AWSサービス

| サービス | 役割 |
|---------|------|
| AWS Lambda | フィード取得・集約・RSSファイル生成 (定期実行) |
| Amazon S3 | 生成したRSSフィードの保存 |

#### アーキテクチャ構成

```
外部サービス
    ├─ Googleアラート (Google検索フィード)
    └─ Query feed (Twitter検索フィード)
        ↓
AWS Lambda (CloudWatch Events / EventBridge による定期トリガー)
    ├─ 2つのフィードを取得
    ├─ 内容を集約してRSSを生成
    └─ S3バケットに保存
        ↓
Amazon S3 (RSS保存先)
        ↓
PC / モバイルのフィードリーダー
```

#### データフロー

1. CloudWatch Events がLambdaを一定周期でトリガー
2. Lambda が Googleアラートフィード (RSS/Atom) を取得
3. Lambda が Query feed経由でTwitter検索フィード (RSS) を取得
4. 2つのフィードを1つのRSSにマージ
5. S3バケットの特定パスにRSSファイルを保存 (上書き更新)
6. フィードリーダーがS3のRSSエンドポイントを定期ポーリング

#### 実装ポイント

| ポイント | 内容 |
|---------|------|
| 定期実行 | Lambda + CloudWatch Events (EventBridge) でcron式のスケジュール実行 |
| S3の静的ホスティング | S3バケットを公開してRSSエンドポイントとして利用 |
| 拡張性 | フィードソースを追加する場合はLambdaのみ変更すれば良い |
| コスト | Lambda実行分のみ課金 (EC2常駐不要) |

---

### Pattern 4-9: Kinesis+DynamoDB Streams リアルタイムデータ収集

Twitter Streaming APIのツイートをKinesisに流し込み、形態素解析・集約後にDynamoDBへ保存。DynamoDB Streamsで変更をリアルタイムWebにブロードキャストする。

#### 使用AWSサービス

| サービス | 役割 |
|---------|------|
| Amazon Kinesis Streams | ストリーミングデータのリアルタイム収集 |
| Amazon DynamoDB | 集約された単語カウントデータの永続化 |
| DynamoDB Streams | DynamoDBの変更イベントの検出 |

#### アーキテクチャ構成

```
Twitter Streaming API (statuses/sample)
        ↓
Twitter-to-Kinesis Producer (プロデューサ)
        ↓ putRecords
Amazon Kinesis Streams (twitter_stream)
        ↓ getRecords
Kinesis-to-DynamoDB Consumer (コンシューマ)
    ├─ Kuromojiで形態素解析
    ├─ 単語数カウント (10秒単位で集約)
    └─ putItem
        ↓
Amazon DynamoDB (集約結果)
        ↓ DynamoDB Streams
dynamodb-stream-socketio
        ↓ getRecords
Socket.io サーバ
        ↓ 更新情報をブロードキャスト
Webブラウザ (リアルタイム更新)
```

#### データフロー

1. Producerが Twitter Streaming APIに接続 → ツイートをKinesisにputRecords
2. ConsumerがKinesisからgetRecords → Kuromojiで日本語形態素解析
3. 10秒単位でツイート内の単語カウントを集約してDynamoDBにputItem
4. DynamoDB Streamsが変更イベントを検出
5. Socket.ioサーバがDynamoDB Streamsから最新集約結果を取得
6. Socket.ioが接続中のWebクライアントにリアルタイムでブロードキャスト

#### 設計上の判断

| 判断事項 | 選択 | 理由 |
|---------|------|------|
| コンシューマ実行環境 | EC2 (ローカルPC) | 形態素解析辞書が数十MBあり、Lambda (イベント駆動) では起動オーバーヘッドが大きい |
| Lambdaコンシューマ非採用 | Kinesisのソースを持つLambdaは可能だが今回は不採用 | 辞書ロード時間がLambdaのCold Startと相性が悪い |
| 集約単位 | 10秒ウィンドウ | トレンド変化の追跡に適した粒度 |

#### 実装ポイント

| ポイント | 内容 |
|---------|------|
| Kinesis vs Lambda | 継続デーモンが必要な場合はEC2/ECS、イベント駆動ならLambda |
| 形態素解析 | Kuromoji (Java/Node.js向け日本語形態素解析ライブラリ) |
| 本番化 | ローカルPCをEC2またはECS (Docker) に置き換えてデーモン化 |
| DynamoDB Streams | レコード変更を最大24時間保持 (順序保証あり) |

---

### Pattern 4-10: Machine Learning 予測サービス

Chrome拡張機能からWebアクセス履歴を収集し、Amazon MLでプログラミング言語カテゴリを予測、関連フィードをレコメンドするサービス。

#### 使用AWSサービス

| サービス | 役割 |
|---------|------|
| Amazon API Gateway | 履歴保存・カテゴリ予測APIのエンドポイント |
| AWS Lambda | DynamoDB書き込み / ML推論呼び出し |
| Amazon DynamoDB | Web閲覧履歴の永続化 |
| Amazon Machine Learning (Amazon ML) | プログラミング言語カテゴリの多値分類予測 |
| Amazon S3 | 教師データ (学習データセット) の保存 |

#### アーキテクチャ構成

```
Google Chrome (ブラウザ)
        ↓ Webページアクセス
Chrome拡張機能
    ├─ POST /history (URL + タイトル + Description)
    │       ↓
    │   API Gateway → Lambda → DynamoDB (履歴保存)
    │
    └─ POST /categorize (URL + タイトル + Description)
            ↓
        API Gateway → Lambda
                          ↓ リアルタイム予測
                   Amazon Machine Learning
                          ↑
                   S3 Bucket (教師データ)
                          ↓
                   カテゴリ予測結果 (プログラミング言語)
                          ↓
                   はてなブックマーク RSSフィード
                          ↓
                   Chrome拡張でおすすめ記事表示
```

#### データフロー

1. Chrome拡張がWebアクセス時にURL・タイトル・Descriptionをキャプチャ
2. `/history` エンドポイント → DynamoDBに閲覧履歴を保存 (UUID / url / timestamp)
3. `/categorize` エンドポイント → LambdaがAmazon MLに推論リクエスト
4. Amazon MLが7種のプログラミング言語カテゴリに分類して返却
5. 予測カテゴリに対応するはてなブックマークRSSフィードを取得
6. Chrome拡張のUIでおすすめ記事として表示

#### 機械学習の設計

| 要素 | 内容 |
|-----|------|
| 分類タスク | 多値分類 (7種のプログラミング言語) |
| 特徴量 | URL + ページタイトル + Meta Description |
| 教師データ | S3バケットにCSV形式で保存 |
| 推論方式 | リアルタイム予測 (Batch非採用) |
| DynamoDBスキーマ | `UUID` (PK), `url`, `timestamp` |

#### 実装ポイント

| ポイント | 内容 |
|---------|------|
| Chrome拡張機能 | content_script でページ情報を取得 → background.js でAPI呼び出し |
| 教師データ作成 | Kuromojiで形態素解析した単語とカテゴリラベルをCSV化 |
| 学習→デプロイフロー | S3 DataSource → ML Model → Real-time Endpoint |
| Lambdaの役割 | フロントエンドの言語非依存APIとして機能 |

---

### Pattern 4-11: Cognito Sync データ同期メモアプリ

Cognito Syncを使って複数端末間でメモデータを自動同期するシンプルなアプリ。認証はFacebook Federationを使用。

#### 使用AWSサービス

| サービス | 役割 |
|---------|------|
| Amazon Cognito | Facebook認証 / Identity管理 |
| Amazon Cognito Sync | 端末間データ同期 (データセット管理) |

#### アーキテクチャ構成

```
認証プロバイダ (Facebook)
        ↓ ①ログイン
モバイルアプリ (iOS / Android)
        ↓ ②Cognito Identity取得 (Credentials Provider)
Amazon Cognito
        ↓ ③Identity IDに紐づくデータセット同期開始
Amazon Cognito Sync (データセット)
        ↓ ④メモデータ取得 → 画面表示
        ↓ ⑤ユーザーがメモ編集 → 同期
Amazon Cognito Sync (データセット更新)

別の端末でログイン時:
        ↓ 同一FacebookアカウントのIdentity ID
Amazon Cognito Sync (同一データセット)
        ↓ メモを復元・表示
```

#### データフロー

1. Facebookにログイン → アクセストークン取得
2. Credentials ProviderからCognito Identity IDを取得
3. Cognito Syncが対応するデータセットの同期を開始
4. データセット内のメモキー・バリューを取得して画面に表示
5. ユーザーがメモを編集 → 入力完了時にCognito Syncで保存・同期
6. 他端末でログイン時 → 同一Identity IDのデータセットからメモを復元

#### Cognito Syncのデータ構造

| 概念 | 説明 | 例 |
|-----|------|-----|
| Identity Pool | アプリのユーザーグループ | PictureSharingApp |
| Identity ID | 認証済みユーザーの一意識別子 | `us-east-1:xxxxxx-xxxx-...` |
| Dataset | Identity IDに紐づくKVSコンテナ | `MemoDataset` |
| Record | データセット内のキーバリューペア | `"memo": "買い物リスト..."` |

#### 実装ポイント

| ポイント | 内容 |
|---------|------|
| データセット分離 | Identity (認証済みユーザー) 毎にデータセットが用意され不特定多数に対応 |
| オフライン対応 | デバイス内にデータをキャッシュし、オンラインになった時に同期 |
| 競合解決 | Cognito Syncがデバイス間の更新競合を検出・解決 |
| 前提条件 | 4-1 (Cognito / Facebook認証) のセットアップと共通 |

---

## パターン選択ガイド

### 認証・認可方式の選択

| 要件 | 推奨パターン | 理由 |
|-----|------------|------|
| ソーシャルログイン + S3直接操作 | 4-1 (2-Tier / Cognito) | SDKでS3を直接操作、サーバー不要 |
| ソーシャルログイン + 細粒度認可 | 4-3 (Lambda経由) | Lambdaで任意の認可ロジックを実装 |
| 自社DB認証 + AWS連携 | 4-6 (Developer Authenticated) | Cognitoの独自認証でIAMロールを取得 |
| 端末間データ同期のみ | 4-11 (Cognito Sync) | サーバーレスで端末間同期を実現 |

### データ収集方式の選択

| データの性質 | 推奨パターン | 理由 |
|-----------|------------|------|
| ウェアラブルデバイス (単一ユーザー) | 4-5 | 3-Tier + DynamoDB Streams |
| 物理センサー (BLE / iBeacon) | 4-6 | モバイルアプリがハブになる |
| ストリーミング (大量ツイート等) | 4-9 | Kinesis で高スループット処理 |
| Webアクセス履歴 | 4-10 | Chrome拡張 + API Gateway |

### リアルタイム通知方式の選択

| 通知タイプ | 推奨サービス | 特徴 |
|---------|------------|------|
| モバイルプッシュ | SNS (4-1) | iOS/Android両対応、トピックで一斉配信 |
| Webリアルタイム | Socket.io + DynamoDB Streams (4-9) | WebSocketで低遅延ブロードキャスト |
| サーバーレスキュレーション | Lambda 定期実行 + S3 (4-8) | フィードリーダー向け |

### テスト自動化の選択

| テスト目的 | 推奨アプローチ | ツール |
|----------|-------------|------|
| モンキーテスト (機種依存検出) | Device Farm Explorer / Fuzz | Built-in |
| 仕様テスト (メソッド単位) | Device Farm + Appium JUnit | Appium |
| シナリオテスト (退行確認) | Device Farm + TestNG / Calabash | Appium / BDD |
| CI連携 (自動化) | Device Farm API | AWS CLI / SDK |

---

## 共通設計パターン

### 1. Cognitoの利用パターン比較

| パターン | 認証方式 | 利用シーン |
|---------|---------|---------|
| Federation (外部IdP) | Facebook / Google / Twitter | 4-1, 4-11 |
| User Pools | メール・パスワード | 独自ユーザー管理 |
| Developer Authenticated Identities | 自社DBの認証情報 | 4-6 |
| Lambda経由認証 | Cognito + Lambda | 4-3 (AWS依存隠蔽) |

### 2. Lambda実行トリガー比較

| トリガー | 実装例 | 特徴 |
|---------|------|------|
| API Gateway | 4-2, 4-3, 4-4, 4-5, 4-6, 4-10 | リクエスト/レスポンス型 |
| CloudWatch Events | 4-8 | cron形式のスケジュール実行 |
| DynamoDB Streams | 4-5, 4-9 | データ変更イベント駆動 |
| Kinesis Streams | 4-9 (代替) | ストリーム処理 |
| S3イベント | 4-1 (推奨改善案) | オブジェクト作成/削除イベント |

### 3. モバイル開発のTier構成選択

| 構成 | 特徴 | 採用パターン |
|-----|------|-----------|
| 2-Tier (直接SDK) | サーバー不要、AWSに依存 | 4-1 (S3/SNS直接), 4-11 (Cognito Sync) |
| 3-Tier (API Gateway経由) | AWS非依存のAPIとして公開 | 4-2〜4-10 |
| ハイブリッド | 静的データはS3、動的データはAPI Gateway | 4-2 |
