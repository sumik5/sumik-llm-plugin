# Infrastructure HA & Resilience — 実装詳細ガイド

AWS インフラの高可用性・耐障害性・動的スケーリングを実装するための具体的パターン集。
CloudWatch 回復・AZ 障害対策・ELB/SQS デカップリング・べき等設計・Auto Scaling を網羅する。

> **`RESILIENCE.md` との差別化**: こちらはパターン概要ではなく「実装コード・落とし穴・べき等設計」観点。

---

## 1. CloudWatch によるEC2 インスタンス自動回復

### 1.1 回復の仕組みと前提条件

物理ホスト障害が検知されると CloudWatch → EC2 回復アクションが連鎖する。

```
1. 物理ホストのハードウェア障害 → EC2 インスタンスがダウン
2. EC2 サービスが機能停止を検知 → CloudWatch メトリクスに報告
3. CloudWatch アラームが回復プロセスを開始
4. 別の物理ホストで EC2 インスタンスが起動
5. EBS ボリュームと Elastic IP は新インスタンスに再リンク
```

**回復後も同一になるもの:**
- インスタンス ID
- プライベート IP アドレス / Elastic IP
- EBS ボリュームデータ

**回復要件（インスタンス制約）:**
- VPC ネットワーク上で実行されていること
- インスタンスファミリー: C3/C4/C5、M3/M4/M5、R3/R4、T2、X1 のいずれか
- ストレージは EBS ボリュームのみ（インスタンスストアは非対応）

### 1.2 CloudWatch 回復アラームの実装

```yaml
# CloudFormation: ステータスチェック失敗時に EC2 を回復させるアラーム
RecoveryAlarm:
  Type: 'AWS::CloudWatch::Alarm'
  Properties:
    AlarmDescription: 'Recover EC2 instance on system status check failure'
    Namespace: 'AWS/EC2'
    MetricName: 'StatusCheckFailed_System'   # システムステータスチェックのメトリクス
    Statistic: Maximum
    Period: 60                               # 60 秒おきにチェック
    EvaluationPeriods: 5                     # 直近 5 回（5 分間）で評価
    ComparisonOperator: GreaterThanThreshold
    Threshold: 0
    AlarmActions:
      - !Sub 'arn:aws:automate:${AWS::Region}:ec2:recover'  # 組み込み回復アクション
    Dimensions:
      - Name: InstanceId
        Value: !Ref VM
```

**動作まとめ:**
- 60 秒ごとにチェック → 5 回連続失敗 → アラーム作動 → 回復開始
- `StatusCheckFailed_System`: ホスト側の障害（電源・ネットワーク・ハードウェア）を検出

---

## 2. アベイラビリティゾーン（AZ）とマルチAZ 回復

### 2.1 AZ の概念

| 項目 | 説明 |
|------|------|
| AZ とは | リージョン内の独立したデータセンターのグループ |
| AZ 間接続 | 低遅延リンクで接続（インターネット越えより高速） |
| AZ 数 | リージョンによって異なる（us-east-1 は 6 AZ: a〜f） |
| ID の注意点 | `us-east-1a` が指す物理 AZ はアカウントごとにランダム |

```bash
# 利用可能なリージョンを確認
aws ec2 describe-regions

# 特定リージョンの AZ を確認
aws ec2 describe-availability-zones --region us-east-1
```

**サービスとスコープの関係:**

| スコープ | サービス例 |
|----------|-----------|
| グローバル（複数リージョン） | Route 53 (DNS)、CloudFront (CDN) |
| リージョン内（複数 AZ） | S3、DynamoDB |
| マルチ AZ フェイルオーバー | RDS (Multi-AZ モード) |
| 単一 AZ（デフォルト） | EC2 インスタンス |

### 2.2 Auto Scaling による別AZ 自動回復

CloudWatch 回復はプライベート IP・AZ を変更しない。AZ 障害への対応は Auto Scaling グループが必要。

```yaml
# 起動設定: AMI・インスタンスタイプ・ブートストラップを定義
LaunchConfiguration:
  Type: 'AWS::AutoScaling::LaunchConfiguration'
  Properties:
    AssociatePublicIpAddress: true
    ImageId: !FindInMap [RegionMap, !Ref 'AWS::Region', AMI]
    InstanceType: 't2.micro'
    KeyName: !Ref KeyName
    SecurityGroups:
      - !Ref SecurityGroup
    UserData:
      'Fn::Base64': !Sub |
        #!/bin/bash -x
        # アプリケーションのブートストラップスクリプト
        ...

# Auto Scaling グループ: 複数 AZ にまたがって仮想マシンを常時1台維持
AutoScalingGroup:
  Type: 'AWS::AutoScaling::AutoScalingGroup'
  Properties:
    LaunchConfigurationName: !Ref LaunchConfiguration
    DesiredCapacity: 1
    MinSize: 1
    MaxSize: 1
    VPCZoneIdentifier:
      - !Ref SubnetA   # AZ A のサブネット
      - !Ref SubnetB   # AZ B のサブネット
    HealthCheckGracePeriod: 600
    HealthCheckType: EC2
```

**Auto Scaling グループの必須パラメータ:**

| パラメータ | 説明 | 例 |
|-----------|------|----|
| `DesiredCapacity` | 実行すべき正常インスタンスの数 | 1〜N |
| `MinSize` | インスタンス数の下限 | 1 以上 |
| `MaxSize` | インスタンス数の上限 | MinSize 以上 |
| `VPCZoneIdentifier` | インスタンスを起動するサブネットリスト（複数 AZ） | サブネット ID リスト |
| `HealthCheckType` | ヘルスチェック方式 | EC2 or ELB |

---

## 3. マルチAZ 構成の落とし穴

### 3.1 落とし穴①: ネットワーク接続型ストレージ（EBS）の制約

```
問題:
  EBS ボリュームは「1 つの AZ にのみ」存在する
  → AZ が機能停止 → 別 AZ で EC2 が起動 → EBS にアクセス不可

  例: データが us-east-1a にある → AZ B で新 EC2 起動 → データにアクセスできない
  (データは消失しないが、AZ が戻るまでアクセス不可)
```

**解決策の選択肢:**

| 解決策 | 説明 | 適用場面 |
|--------|------|---------|
| マネージドサービス利用 | RDS、DynamoDB、EFS、S3 にデータを移す | ステートフルなデータ |
| EBS スナップショット | 定期的に S3 に保存 → 別 AZ で復元 | バックアップ戦略 |
| EFS | NFSv4.1 で複数 AZ 間でデータを自動レプリケート | ファイルシステムが必要な場合 |
| 分散ストレージ | GlusterFS、DRBD、MongoDB 等 | カスタム要件 |

**EFS を使った Jenkins の Multi-AZ 対応例:**

```yaml
FileSystem:
  Type: 'AWS::EFS::FileSystem'
  Properties: {}

# 各 AZ にマウントターゲットを作成（高可用性には少なくとも 2 つ）
MountTargetA:
  Type: 'AWS::EFS::MountTarget'
  Properties:
    FileSystemId: !Ref FileSystem
    SecurityGroups:
      - !Ref MountTargetSecurityGroup
    SubnetId: !Ref SubnetA

MountTargetB:
  Type: 'AWS::EFS::MountTarget'
  Properties:
    FileSystemId: !Ref FileSystem
    SecurityGroups:
      - !Ref MountTargetSecurityGroup
    SubnetId: !Ref SubnetB
```

```bash
# ブートストラップ時に EFS をマウント（UserData 内）
echo -n "${FileSystem}.efs.${AWS::Region}.amazonaws.com:/var/lib/jenkins \
  nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0" >> /etc/fstab
mount -a
```

### 3.2 落とし穴②: ネットワークインターフェイス（IP アドレス）の変化

```
問題:
  Auto Scaling で別 AZ に起動 → 別サブネット → プライベート IP が変化
  デフォルトでは Elastic IP も引き継がれない
```

**静的エンドポイントを提供する 3 つの方法:**

| 方法 | 実装 | 特徴 |
|------|------|------|
| Elastic IP をブートストラップ時に関連付け | EC2 起動時に AWS CLI で `ec2:AssociateAddress` を実行 | IAM ロール必要 |
| Route 53 DNS エントリを動的更新 | ブートストラップ時に現在の IP で DNS を更新 | 登録済みドメインが必要 |
| ELB を静的エンドポイントとして使用 | ELB の DNS 名は変わらない | 第 15 章で詳述 |

**Elastic IP をブートストラップ時に関連付ける実装:**

```yaml
ElasticIP:
  Type: 'AWS::EC2::EIP'
  Properties:
    Domain: vpc

IamRole:
  Type: 'AWS::IAM::Role'
  Properties:
    Policies:
      - PolicyName: elastic-ip
        PolicyDocument:
          Statement:
            - Action: 'ec2:AssociateAddress'
              Resource: '*'
              Effect: Allow
```

```bash
# UserData 内: インスタンスメタデータから ID 取得 → Elastic IP を関連付け
INSTANCE_ID="$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
aws --region ${AWS::Region} ec2 associate-address \
  --instance-id ${INSTANCE_ID} \
  --allocation-id ${ElasticIP.AllocationId}
```

---

## 4. ディザスタリカバリ（DR）分析: RTO / RPO

### 4.1 RTO / RPO の定義

- **RTO (Recovery Time Objective)**: 障害発生からシステムが正常状態に戻るまでの時間
- **RPO (Recovery Point Objective)**: 障害発生時に許容されるデータ消失の時間幅

### 4.2 単一 EC2 インスタンスの RTO/RPO 比較

| 構成 | RTO | RPO | 可用性範囲 |
|------|-----|-----|-----------|
| EBS ルートボリューム + CloudWatch アラーム回復 | 約 10 分 | 0（データ消失なし） | 仮想マシン障害のみ（AZ 障害は非対応） |
| EBS ルートボリューム + Auto Scaling 回復 | 約 10 分 | **全データ消失** | VM 障害 + AZ 障害 |
| EBS + 定期スナップショット + Auto Scaling | 約 10 分 | スナップショット間隔（30 分〜24 時間） | VM 障害 + AZ 障害 |
| **EFS ファイルシステム + Auto Scaling** | 約 10 分 | **0（データ消失なし）** | VM 障害 + AZ 障害 |

> **推奨**: AZ 障害対応かつ RPO=0 が必要なら、EFS（または RDS/S3/DynamoDB）を使ったステートレスサーバー構成が最適解。

---

## 5. 同期デカップリング: ELB によるロードバランシング

### 5.1 なぜデカップリングが必要か

```
問題: EC2 インスタンスの IP を直接公開する場合
  - クライアントが IP に依存 → IP 変更が不可能
  - 新 EC2 を追加しても既存クライアントには無視される
  - DNS キャッシュの問題（TTL が尊重されないケース）

解決: ロードバランサーをエントリポイントに置く
  → クライアントは LB の DNS 名だけを知っていればよい
  → バックエンドの EC2 台数変化を隠蔽できる
```

### 5.2 ALB の構成要素

| コンポーネント | 役割 |
|---------------|------|
| **ロードバランサー** | サブネット・パブリック/プライベート設定を定義 |
| **リスナー** | 受け付けるポートとプロトコル（HTTP/HTTPS）を定義。デフォルトのターゲットグループにリンク |
| **ターゲットグループ** | バックエンド EC2 を管理。定期的なヘルスチェックを実行 |
| **リスナールール**（オプション） | HTTP パス・ホストに基づいて異なるターゲットグループへルーティング |

**ELB の種類:**

| タイプ | プロトコル | 用途 |
|--------|-----------|------|
| ALB (Application LB) | HTTP/HTTPS | Web アプリケーション、パスベースルーティング |
| NLB (Network LB) | TCP | 低遅延・高スループット |
| CLB (Classic LB) | HTTP/HTTPS/TCP | レガシー（新規プロジェクトでは非推奨） |

### 5.3 ALB と Auto Scaling グループの連携実装

```yaml
LoadBalancer:
  Type: 'AWS::ElasticLoadBalancingV2::LoadBalancer'
  Properties:
    SecurityGroups:
      - !Ref LoadBalancerSecurityGroup
    Scheme: 'internet-facing'         # 外部公開。内部向けは 'internal'
    Subnets:
      - !Ref SubnetA
      - !Ref SubnetB
    Type: application

Listener:
  Type: 'AWS::ElasticLoadBalancingV2::Listener'
  Properties:
    LoadBalancerArn: !Ref LoadBalancer
    Port: 80
    Protocol: HTTP
    DefaultActions:
      - TargetGroupArn: !Ref TargetGroup
        Type: forward

TargetGroup:
  Type: 'AWS::ElasticLoadBalancingV2::TargetGroup'
  Properties:
    HealthCheckIntervalSeconds: 10
    HealthCheckPath: '/index.html'
    HealthCheckProtocol: HTTP
    HealthCheckTimeoutSeconds: 5
    HealthyThresholdCount: 3
    UnhealthyThresholdCount: 2
    Matcher:
      HttpCode: '200-299'
    Port: 80
    Protocol: HTTP
    VpcId: !Ref VPC

AutoScalingGroup:
  Type: 'AWS::AutoScaling::AutoScalingGroup'
  Properties:
    LaunchConfigurationName: !Ref LaunchConfiguration
    MinSize: !Ref NumberOfVirtualMachines
    MaxSize: !Ref NumberOfVirtualMachines
    DesiredCapacity: !Ref NumberOfVirtualMachines
    TargetGroupARNs:
      - !Ref TargetGroup              # ← ここで ALB と ASG を連携
    VPCZoneIdentifier:
      - !Ref SubnetA
      - !Ref SubnetB
```

---

## 6. 非同期デカップリング: SQS メッセージキュー実装

### 6.1 同期プロセスを非同期に変換するパターン

**同期（変換前）:**
```
ユーザー → URL 送信 → Web サーバーがダウンロード+スクリーンショット+レスポンス返却
問題: Web サーバーがビジー or ダウンするとリクエストが失敗
```

**非同期（変換後: URL2PNG アーキテクチャ）:**
```
ユーザー → URL 送信
       ↓
Web サーバー → ランダム ID を生成 → SQS にメッセージを送信 → ユーザーに ID を返却
                                          ↓
                               バックグラウンドワーカーがポーリング
                               → URL ダウンロード → PNG 変換 → S3 にアップロード
                                          ↓
ユーザー → ID を使って S3 から画像をダウンロード
```

### 6.2 SQS キューの作成

```bash
# キューを作成
aws sqs create-queue --queue-name url2png
# → QueueUrl: https://queue.amazonaws.com/878533158213/url2png
```

### 6.3 メッセージの送信（プロデューサ実装）

```javascript
// Node.js + AWS SDK でメッセージを送信 (index.js)
const AWS = require('aws-sdk');
const uuid = require('uuid/v4');
const sqs = new AWS.SQS({ region: 'us-east-1' });

const id = uuid();           // 一意な ID を生成
const body = { id: id, url: process.argv[2] };

sqs.sendMessage({
    MessageBody: JSON.stringify(body),
    QueueUrl: config.QueueUrl
}, (err) => {
    if (err) { console.log('error', err); }
    else { console.log('PNG will be available soon at .../' + id + '.png'); }
});
```

### 6.4 メッセージの受信・処理・削除（コンシューマ実装）

**SQS メッセージ処理の 3 ステップ:**

```javascript
// ステップ 1: メッセージを受信
const receive = (cb) => {
    sqs.receiveMessage({
        QueueUrl: config.QueueUrl,
        MaxNumberOfMessages: 1,     // 一度に最大 10 まで指定可能
        VisibilityTimeout: 120,     // 処理保持時間（秒）= 平均処理時間 × 4 が目安
        WaitTimeSeconds: 10         // ロングポーリング（最大 10 秒待機）
    }, (err, data) => {
        if (err) { cb(err); }
        else { cb(null, data.Messages ? data.Messages[0] : null); }
    });
};

// ステップ 2: メッセージを処理（URL → PNG → S3 アップロード）
const process = (message, cb) => {
    const body = JSON.parse(message.Body);
    const file = body.id + '.png';
    webshot(body.url, file, (err) => {   // スクリーンショット作成
        if (!err) {
            fs.readFile(file, (err, buf) => {
                s3.putObject({
                    Bucket: config.Bucket, Key: file,
                    ACL: 'public-read', ContentType: 'image/png', Body: buf
                }, cb);
            });
        }
    });
};

// ステップ 3: 処理完了を示す ACK（メッセージをキューから削除）
const acknowledge = (message, cb) => {
    sqs.deleteMessage({
        QueueUrl: config.QueueUrl,
        ReceiptHandle: message.ReceiptHandle   // 受信時に発行される一意な ID
    }, cb);
};

// ループで継続実行
const run = () => {
    receive((err, message) => {
        if (!message) { setTimeout(run, 1000); }
        else {
            process(message, (err) => {
                acknowledge(message, (err) => { setTimeout(run, 1000); });
            });
        }
    });
};
run();
```

---

## 7. SQS メッセージングの制限と考慮事項

### 7.1 SQS の利点

| 利点 | 説明 |
|------|------|
| 無制限スケーリング | メッセージ数に上限なし。インフラは自動スケーリング |
| 高可用性 | デフォルトで耐障害性を備える |
| 従量課金 | メッセージごとに課金（100 万件で約 $0.4） |

### 7.2 SQS の制限（トレードオフ）

| 制限 | 詳細 | 対処法 |
|------|------|--------|
| **少なくとも 1 回配信** | まれに同じメッセージが 2 回配信されることがある | **べき等処理**で対応（後述） |
| **順序保証なし** | 生成順と異なる順序でメッセージが消費される可能性 | FIFO キューを使用（ただしスループット制限あり） |
| **メッセージブローカーではない** | ルーティング・優先順位付けは非対応 | Amazon MQ (ActiveMQ) を検討 |

### 7.3 FIFO キュー

| 項目 | 通常キュー | FIFO キュー |
|------|-----------|------------|
| 順序 | 保証なし | 保証あり |
| 重複 | 発生する可能性あり | 重複検出機構あり |
| スループット | 無制限 | 最大 300 オペレーション/秒 |
| コスト | 低 | 高 |

> **設計原則**: 可能であれば順序依存をなくす方向でシステムを設計し、通常 SQS キューを活用するのが最良の方法。

---

## 8. 耐障害性設計原則

### 8.1 AWSサービスの障害処理分類

| 分類 | 内容 | サービス例 |
|------|------|-----------|
| **耐障害性** | 障害時にダウンタイムなしで自動回復 | S3、DynamoDB、Route 53、ELB、SQS、CloudWatch |
| **高可用性** | 障害時に短いダウンタイムで自動回復 | RDS (Multi-AZ)、EBS |
| **手動対応が必要** | デフォルトでは非対応。ツールは提供される | EC2 インスタンス |

### 8.2 冗長性による単一障害点の除去

```
単一障害点の問題:
  EC2 × 1台 → ダウン → ユーザーへの全サービスが停止

冗長化の解決:
  EC2 × 3台 → 1台がダウン → 残り 2 台で継続
  （コスト: 大きいインスタンス × 1 = 小さいインスタンス × 3 とコストは同程度）
```

**同期デカップリング + 冗長性（ELB + Auto Scaling）:**

```
インターネット
     ↓
ロードバランサー (ELB) ← 耐障害性: デフォルトで備わる
     ↓
Auto Scaling グループ ← 耐障害性: デフォルトで備わる
     ├── AZ A: Web サーバー × N
     └── AZ B: Web サーバー × N

EC2 がダウン → ELB がそのインスタンスへの転送を停止 → ASG が自動で置き換え
AZ がダウン → 残り AZ の EC2 に全トラフィックが集中 → ASG がスケールアウト
```

**非同期デカップリング + 冗長性（SQS + Auto Scaling）:**

```
SQS キュー ← 耐障害性: デフォルトで備わる
     ↓
Auto Scaling グループ
     ├── AZ A: ワーカー × N
     └── AZ B: ワーカー × N

ワーカーがダウン → VisibilityTimeout 後にメッセージが再配信 → 別ワーカーが処理
```

### 8.3 冗長性には分離が必要

| デカップリング方式 | エントリポイント | スケーリング対象 |
|------------------|----------------|----------------|
| 同期（HTTP リクエスト） | ELB | Web サーバー |
| 非同期（バックグラウンド処理） | SQS | ワーカー |

---

## 9. コードに耐障害性を持たせる

### 9.1 クラッシュ & リトライ（フェイルファスト）

```
原則: 処理できない状態になったらクラッシュさせる → 誰かがリトライする
```

**同期デカップリングのリトライ:**
```
リクエスト送信者がリトライロジックを実装
→ タイムアウト or エラー時に同じリクエストを再送
```

**非同期デカップリングのリトライ（SQS に内蔵）:**
```
メッセージ受信後、VisibilityTimeout 内に ACK されなければ自動で再配信
→ リトライが最初からシステムに組み込まれている
```

**リトライが有効な場合・無効な場合:**

| 状況 | リトライ | 理由 |
|------|---------|------|
| DB 接続失敗 | ✅ 有効 | 数秒後に回復する可能性がある |
| 無効なリクエスト内容 | ❌ 無効 | 何度リトライしても結果は変わらない |

### 9.2 べき等リトライ（Idempotent Retry）

```
べき等 = 同じオペレーションを何度実行しても結果が同じになる

重要: SQS は「少なくとも 1 回」配信を保証するため、
     コンシューマがべき等でないと重複処理が発生する
```

**べき等データベース挿入の実装パターン:**

```javascript
// NG: べき等でない実装
async function uploaded(processId, s3Key) {
    const process = await db.getItem(processId);
    if (process.state !== 'Created') {
        throw new Error('transition not allowed');
    }
    await db.updateItem(processId, { state: 'Uploaded', rawS3Key: s3Key });
    await sqs.sendMessage({ processId, action: 'process' });
    // 問題: SQS 送信失敗 → リトライ → updateItem が成功済みのため 'transition not allowed'
}

// OK: べき等な実装
async function uploaded(processId, s3Key) {
    const process = await db.getItem(processId);
    // Created または Uploaded いずれの状態も許可することでべき等を実現
    if (process.state !== 'Created' && process.state !== 'Uploaded') {
        throw new Error('transition not allowed');
    }
    await db.updateItem(processId, { state: 'Uploaded', rawS3Key: s3Key });
    await sqs.sendMessage({ processId, action: 'process' });
    // 2 回呼ばれても: DB は冪等更新、SQS はべき等コンシューマが処理
}
```

**UUID を使ったべき等挿入:**
```javascript
// クライアント側で UUID を生成してリクエストに含める
const id = uuid();   // 550e8400-e29b-11d4-a716-446655440000

// DB 側: 同一 UUID の重複挿入をエラーなく処理
db.putItem({
    Item: { id: { S: id }, state: { S: 'created' } },
    ConditionExpression: 'attribute_not_exists(id)'  // すでに存在する場合は INSERT をスキップ
});
// 結果:
// 1. ID が存在しない場合 → 正常挿入
// 2. 同じ UUID が既存の場合 → エラーを受け入れて処理完了
// 3. 異なるエラー → クラッシュ
```

---

## 10. Imagery アプリ: べき等状態機械の実装

### 10.1 アーキテクチャ概要

画像をアップロードすると非同期でセピアフィルタを適用するアプリ。

```
状態遷移:
  (Created) → (Uploaded) → (Processed)

データストア役割:
  DynamoDB: プロセス状態の管理
  S3:       元画像・変換後画像の格納
  SQS:      ワーカーへの処理指示キュー
```

```
[ユーザー]
    │ POST /image → プロセス ID 返却
    ↓
  [ELB]
    │ リクエストを複数 EC2 に分配
    ↓
  [Web サーバー (EC2 × N)]
    │ 画像を S3 にアップロード → DynamoDB を Uploaded に更新 → SQS メッセージ送信
    ↓
  [SQS キュー]
    │ ワーカーがポーリング
    ↓
  [ワーカー (EC2 × N)]
    │ S3 から元画像ダウンロード → セピアフィルタ適用 → S3 にアップロード
    │ DynamoDB を Processed に更新
    ↓
[ユーザーが ID で S3 から変換後の画像を取得]
```

### 10.2 べき等の状態遷移実装（DynamoDB 楽観的ロック）

```javascript
// Uploaded → Processed の状態遷移（べき等実装）
db.updateItem({
    Key: { id: { S: image.id } },
    UpdateExpression: 'SET #s=:newState, version=:newVersion, processedS3Key=:processedS3Key',
    // べき等チェック: Uploaded または Processed 状態であれば遷移を許可
    ConditionExpression:
        'attribute_exists(id) AND version=:oldVersion AND #s IN (:stateUploaded, :stateProcessed)',
    ExpressionAttributeValues: {
        ':newState': { S: 'processed' },
        ':oldVersion': { N: image.version.toString() },
        ':newVersion': { N: (image.version + 1).toString() },  // 楽観的ロック
        ':processedS3Key': { S: processedS3Key },
        ':stateUploaded': { S: 'uploaded' },
        ':stateProcessed': { S: 'processed' }
    }
});
```

**楽観的ロックの仕組み:**
```
プロセス A: アイテム X (version=0) を取得 → version=0 で更新 → 成功 → DB は version=1 に更新
プロセス B: アイテム X (version=0) を取得 → version=0 で更新 → 失敗 (DB は version=1)
             → リトライ → version=1 で再取得 → 成功
```

### 10.3 SQS Dead Letter Queue（DLQ）の設定

```yaml
SQS_DLQueue:
  Type: 'AWS::SQS::Queue'
  Properties:
    QueueName: 'message-dlq'

SQSQueue:
  Type: 'AWS::SQS::Queue'
  Properties:
    QueueName: message
    RedrivePolicy:
      deadLetterTargetArn: !Sub '${SQS_DLQueue.Arn}'
      maxReceiveCount: 10    # 10 回リトライ失敗後に DLQ へ転送
```

**DLQ の運用:**
- DLQ 監視 CloudWatch アラームを必ず作成する
- DLQ にメッセージが届いた場合 = コードにバグがある可能性 → 手動調査が必要

### 10.4 最小権限 IAM ロール設計

**サーバー（Web サーバー）の権限:**
```
sqs:SendMessage              # 画像処理ジョブをキューに送信
s3:PutObject                 # 元画像を S3 の upload/ 以下にアップロード
dynamodb:GetItem
dynamodb:PutItem
dynamodb:UpdateItem
```

**ワーカーの権限:**
```
sqs:ChangeMessageVisibility  # VisibilityTimeout 延長
sqs:DeleteMessage            # 処理完了後に ACK
sqs:ReceiveMessage           # キューからメッセージ受信
s3:PutObject                 # 変換後画像を S3 の processed/ 以下にアップロード
dynamodb:GetItem
dynamodb:UpdateItem
```

---

## 11. 動的スケーリング: Auto Scaling グループ管理

### 11.1 前提条件

| 条件 | 説明 |
|------|------|
| ステートレスサーバー | EC2 インスタンスをステートレスにする（ローカルディスクに状態を持たない） |
| デカップリング | ELB（同期）または SQS（非同期）でクライアントから EC2 を分離する |
| データの外部化 | RDS、DynamoDB、EFS、S3 などのサービスに状態を格納 |

### 11.2 起動設定と Auto Scaling グループの定義

```yaml
LaunchConfiguration:
  Type: 'AWS::AutoScaling::LaunchConfiguration'
  Properties:
    ImageId: 'ami-6057e21a'
    InstanceType: 't2.micro'
    SecurityGroups:
      - webapp
    KeyName: mykey
    UserData:
      'Fn::Base64': !Sub |
        #!/bin/bash -x
        yum -y install httpd
        # アプリケーションのインストール・設定スクリプト

AutoScalingGroup:
  Type: 'AWS::AutoScaling::AutoScalingGroup'
  Properties:
    TargetGroupARNs:
      - !Ref LoadBalancerTargetGroup    # ELB との連携
    LaunchConfigurationName: !Ref LaunchConfiguration
    MinSize: 2
    MaxSize: 4
    DesiredCapacity: 2
    HealthCheckGracePeriod: 300         # ブートストラップ完了まで 5 分猶予
    HealthCheckType: ELB                # ELB ヘルスチェックを使用
    VPCZoneIdentifier:
      - 'subnet-a55fafc'               # AZ A
      - 'subnet-fa224c5a'              # AZ B
```

**Auto Scaling グループの主要パラメータ:**

| パラメータ | 説明 |
|-----------|------|
| `DesiredCapacity` | 現在の目標インスタンス数（スケーリングポリシーが変更する） |
| `MinSize` | スケールインの下限（最小台数を保証） |
| `MaxSize` | スケールアウトの上限（コスト上限を保護） |
| `HealthCheckGracePeriod` | 新インスタンス起動後のヘルスチェック猶予期間（ELB 使用時は必須） |
| `HealthCheckType` | EC2 or ELB |

### 11.3 スケジュールベースのスケーリング

**1 回限りのスケーリング（テレビ CM 対応など）:**
```yaml
OneTimeScheduledActionUp:
  Type: 'AWS::AutoScaling::ScheduledAction'
  Properties:
    AutoScalingGroupName: !Ref AutoScalingGroup
    DesiredCapacity: 4
    StartTime: '2025-04-01T12:00:00Z'
```

**定期的なスケーリング（昼休み対応など）:**
```yaml
RecurringScheduledActionUp:
  Type: 'AWS::AutoScaling::ScheduledAction'
  Properties:
    AutoScalingGroupName: !Ref AutoScalingGroup
    DesiredCapacity: 4
    Recurrence: '0 8 * * *'   # 毎日 08:00 UTC にスケールアウト

RecurringScheduledActionDown:
  Type: 'AWS::AutoScaling::ScheduledAction'
  Properties:
    AutoScalingGroupName: !Ref AutoScalingGroup
    DesiredCapacity: 2
    Recurrence: '0 20 * * *'  # 毎日 20:00 UTC にスケールイン
```

**Cron 構文:**
```
* * * * *
| | | | +-- 曜日 (0-6, 日曜=0)
| | | +----- 月 (1-12)
| | +------- 日 (1-31)
| +--------- 時 (0-23)
+----------- 分 (0-59)
```

### 11.4 メトリクスベースのスケーリング

**スケーリングポリシーの種類:**

| ポリシー | 説明 | 用途 |
|---------|------|------|
| **ターゲット追跡** | 目標値を定義し自動調整（サーモスタット型） | CPU 使用率、リクエスト数など比例するメトリクス |
| **ステップスケーリング** | しきい値超過量に応じて段階的に調整 | SQS キュー長さなど非比例のメトリクス |
| **簡易スケーリング** | レガシー（ステップスケーリングに置き換え） | 非推奨 |

**CloudWatch アラームのパラメータ:**

| パラメータ | 説明 |
|-----------|------|
| `Statistic` | 統計関数（Average/Sum/Minimum/Maximum） |
| `Period` | メトリクスのスライス間隔（秒、60 の倍数） |
| `EvaluationPeriods` | 評価する Period の数 |
| `Threshold` | アラームを作動させるしきい値 |
| `ComparisonOperator` | しきい値との比較演算子 |

---

## 12. デカップリング + スケーリング: 実装パターン

### 12.1 同期デカップリング + 動的スケーリング（WordPress）

**構成:**
```
訪問者 → ALB → Auto Scaling グループ (Web サーバー) → RDS + EFS
                      ↑
               CloudWatch アラーム
               CPU 使用率 70% 超 → スケールアウト
               CPU 使用率 低下 → スケールイン
```

**ターゲット追跡スケーリングポリシー（ALB + CPU）:**
```yaml
ScalingPolicy:
  Type: 'AWS::AutoScaling::ScalingPolicy'
  Properties:
    AutoScalingGroupName: !Ref AutoScalingGroup
    PolicyType: TargetTrackingScaling
    TargetTrackingConfiguration:
      PredefinedMetricSpecification:
        PredefinedMetricType: ASGAverageCPUUtilization
      TargetValue: 70                    # CPU 70% を目標値に維持
      EstimatedInstanceWarmup: 60        # 新インスタンスのウォームアップ 60 秒
```

**事前定義メトリクス:**

| メトリクス | 説明 |
|-----------|------|
| `ASGAverageCPUUtilization` | ASG 全インスタンスの平均 CPU 使用率 |
| `ALBRequestCountPerTarget` | ALB からターゲットへのリクエスト数 |
| `ASGAverageNetworkIn` / `Out` | 平均ネットワーク受信/送信バイト数 |

### 12.2 非同期デカップリング + 動的スケーリング（URL2PNG）

**構成:**
```
プロデューサ → SQS キュー → Auto Scaling グループ (ワーカー) → S3
                   ↑
          CloudWatch アラーム
          ApproximateNumberOfMessagesVisible ≥ 5 → スケールアウト
          ApproximateNumberOfMessagesVisible < 5 → スケールイン
```

**SQS キュー長さを監視するアラーム:**
```yaml
HighQueueAlarm:
  Type: 'AWS::CloudWatch::Alarm'
  Properties:
    EvaluationPeriods: 1
    Statistic: Sum
    Threshold: 5
    Period: 300                           # SQS メトリクスは 5 分ごとに発行
    AlarmActions:
      - !Ref ScalingUpPolicy
    Namespace: 'AWS/SQS'
    Dimensions:
      - Name: QueueName
        Value: !Sub '${SQSQueue.QueueName}'
    ComparisonOperator: GreaterThanThreshold
    MetricName: ApproximateNumberOfMessagesVisible
```

**ステップスケーリングポリシー（SQS + ワーカー）:**
```yaml
ScalingUpPolicy:
  Type: 'AWS::AutoScaling::ScalingPolicy'
  Properties:
    AdjustmentType: 'ChangeInCapacity'
    AutoScalingGroupName: !Ref AutoScalingGroup
    PolicyType: 'StepScaling'
    MetricAggregationType: 'Average'
    EstimatedInstanceWarmup: 60
    StepAdjustments:
      - MetricIntervalLowerBound: 0
        ScalingAdjustment: 1              # アラーム作動時に 1 台追加
```

**同期 vs 非同期のスケーリング指標の選択基準:**

| デカップリング | 推奨スケーリングメトリクス | ポリシー |
|--------------|------------------------|---------|
| 同期（ELB） | CPU 使用率、リクエスト数/ターゲット | ターゲット追跡 |
| 非同期（SQS） | キュー長さ（ApproximateNumberOfMessagesVisible） | ステップスケーリング |

> **理由**: SQS のメッセージ数と必要なワーカー数は直接比例しないため、ターゲット追跡ポリシーは非適切。ステップスケーリングで閾値と調整ステップを明示的に定義する。

---

## まとめ: 設計チェックリスト

### 高可用性（AZ 障害まで対応）
- [ ] Auto Scaling グループを複数の AZ（サブネット）にまたがって設定
- [ ] ストレージを EBS 単体から EFS/RDS/S3/DynamoDB へ移行
- [ ] 静的エンドポイントを ELB または Elastic IP で確保
- [ ] CloudWatch 回復アラームを設定（単一インスタンスの場合）

### 耐障害性（ダウンタイムなし）
- [ ] ELB + Auto Scaling の組み合わせ（同期デカップリング）
- [ ] SQS + Auto Scaling の組み合わせ（非同期デカップリング）
- [ ] SQS コンシューマのべき等処理を実装
- [ ] DLQ を設定し CloudWatch アラームで監視
- [ ] DynamoDB 楽観的ロックでの並行更新制御

### 動的スケーリング
- [ ] EC2 インスタンスをステートレスに設計
- [ ] スケジュールが予測可能 → スケジュールベース
- [ ] 予測不能なスパイク → メトリクスベース（ターゲット追跡 or ステップ）
- [ ] `HealthCheckGracePeriod` を適切に設定（ELB 使用時は必須）
- [ ] バーストパフォーマンス (t2/t3) インスタンスは CPU ベーススケーリングに注意
