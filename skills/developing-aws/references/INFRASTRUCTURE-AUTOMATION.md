# Infrastructure Automation

EC2仮想マシン運用・IaC（Infrastructure as Code）・AWS CLI/SDK・CloudFormation・デプロイ自動化（Elastic Beanstalk / OpsWorks）の実践ガイド。CDKを使わない直接記述アプローチに特化。

---

## EC2 仮想マシン運用

### 仮想マシンの起動手順

EC2インスタンスはウィザード形式で起動する。主要な選択項目:

| ステップ | 内容 | 主要選択肢 |
|---------|------|-----------|
| 1. AMI選択 | OSとプリインストールソフトのバンドル | Amazon Linux 2 / Ubuntu / Windows Server |
| 2. インスタンスタイプ | CPU/メモリ/ネットワーク | t2.micro（開発）/ m4.large（汎用）/ r4.large（メモリ） |
| 3. 詳細設定 | VPC・サブネット・IAMロール・UserData | デフォルトVPC推奨（初期段階） |
| 4. ストレージ | EBSボリューム | gp2 SSD（汎用）/ 暗号化オプション |
| 5. タグ | リソース識別・コスト分析 | Name タグ必須、環境・チームタグ推奨 |
| 6. セキュリティグループ | ファイアウォールルール | SSH(22)・HTTP(80)・HTTPS(443) |
| 7. キーペア | SSH認証 | .pem ファイルを安全に保管 |

```bash
# SSH接続（Linux/macOS）
ssh -i <パス>/mykey.pem ubuntu@<パブリックDNS>
ssh -i <パス>/mykey.pem ec2-user@<パブリックDNS>  # Amazon Linux
```

### インスタンスファミリー

| ファミリー | 用途 | 例 |
|-----------|------|-----|
| T（バースト） | 低コスト、開発・テスト | t2.micro / t3.small |
| M（汎用） | CPU/メモリバランス | m4.large / m5.xlarge |
| C（コンピューティング最適化） | 高CPU要求 | c5.large |
| R（メモリ最適化） | インメモリキャッシュ | r4.large / r5.xlarge |
| I（ストレージ最適化 SSD） | 大容量SSD | i3.large |
| D（ストレージ最適化 HDD） | 大容量HDD | d2.xlarge |
| P/G/CG（GPU） | ML推論・グラフィック | p3.2xlarge |
| X（超大メモリ） | 最大1,952GB RAM | x1e.xlarge |

インスタンス名の読み方: `t2.micro` → `t`=ファミリー、`2`=世代、`micro`=サイズ

### 仮想マシンの状態管理

```
[起動] → running
running → [停止] → stopped → [開始] → running
running → [再起動] → running（同一ホスト継続）
running/stopped → [終了] → terminated（削除・復元不可）
```

**停止と終了の違い（重要）**:
- **停止（stop）**: 課金停止、再起動可能、EBSデータ保持、IPアドレス変更
- **終了（terminate）**: インスタンス削除、復元不可、依存リソースも削除

### 仮想マシンの監視・デバッグ

**システムログの確認**:
- EC2コンソール → インスタンス選択 → アクション → インスタンスの設定 → システムログの取得
- SSH不要でブート時のログを確認可能

**CloudWatch メトリクス** (モニタリングタブ):

| メトリクス | 更新間隔 | 説明 |
|-----------|---------|------|
| CPU使用率 | 5分（基本）/ 1分（詳細） | 処理負荷 |
| ネットワーク入出力 | 5分 | トラフィック量 |
| ディスクI/O | 5分 | ストレージ読み書き |
| メモリ | 要追加設定 | AWSはOS外部から監視のため標準外 |

詳細モニタリング（1分更新）は追加料金が発生。

### インスタンスタイプの変更（スケールアップ）

インスタンスタイプ変更には一旦停止が必要:

```bash
# 手順
1. インスタンスを停止（アクション → インスタンスの状態 → 停止）
2. アクション → インスタンスの設定 → インスタンスタイプの変更
3. 新しいタイプを選択（例: t2.micro → m4.large）
4. インスタンスを再起動
```

変更後はパブリックIPアドレスが変わる点に注意。パブリックDNSを再確認すること。

### リージョン（AZ）切替

リージョンを切替えると、キーペア・セキュリティグループ等のリソースは引き継がれない:

```
主要リージョン一覧:
- us-east-1    バージニア北部（デフォルト・最多サービス）
- us-east-2    オハイオ
- us-west-1    北カリフォルニア
- us-west-2    オレゴン
- ap-northeast-1  東京
- ap-northeast-2  ソウル
- ap-southeast-1  シンガポール
- ap-southeast-2  シドニー
- eu-west-1    アイルランド
- eu-central-1  フランクフルト
```

リージョン選択の判断軸:
1. **遅延**: ユーザーとの地理的距離
2. **コンプライアンス**: データ保存要件
3. **サービス可用性**: 利用サービスが当該リージョンで提供されているか
4. **料金**: リージョン間で料金差あり

### Elastic IP（固定パブリックIPアドレス）

デフォルトのパブリックIPは停止/起動のたびに変更される。固定IPが必要な場合はElastic IPを使用:

```bash
# 手順
1. EC2コンソール → Elastic IP → 新しいアドレスの割り当て
2. IPアドレスを選択 → アクション → アドレスの関連付け
3. インスタンスとプライベートIPを指定
```

**注意**: Elastic IPはインスタンスに関連付けていない状態だと課金される（IPv4枯渇対策）。

**ブルーグリーン切替パターン**:
```
1. 旧インスタンスA（Elastic IP割当）で稼働中
2. 新インスタンスBを起動・アプリ設定完了
3. AのElastic IPを解放し、Bに関連付け
4. Aを終了
```

### ネットワークインターフェイス（NI）の追加

複数のパブリックIPアドレスやサブネットを利用したい場合はNIを追加:

```
ユースケース:
- 複数のTLS証明書（SNI未対応のレガシークライアント対応）
- アプリケーションネットワークと管理ネットワークの分離
- ネットワーク・セキュリティアプライアンス要件
```

```bash
# 手順
1. EC2コンソール → ネットワークインターフェイス → 作成
2. サブネット・セキュリティグループを指定
3. 作成されたNIをインスタンスにアタッチ
4. 新しいElastic IPを割り当て、NIに関連付け
```

---

## EC2 コスト最適化

### 料金モデルの比較

| | オンデマンド | リザーブド | スポット |
|---|---|---|---|
| 料金水準 | 高 | 中（最大63%割引） | 低（最大90%割引） |
| 柔軟性 | 高（いつでも停止） | 低（1〜3年契約） | 中（入札価格次第） |
| 信頼性 | 中 | 高（キャパシティ予約） | 低（強制終了リスク） |
| 主な用途 | 動的WL・概念実証 | 本番・静的WL | バッチ・データ分析 |

**課金単位**: Linuxは秒単位（最低60秒）。WindowsとRHELは時間単位。

### リザーブドインスタンス

特定のインスタンスタイプ・リージョンを長期契約で予約し割引を受ける:

| 契約種別 | 最大割引率 | 備考 |
|---------|-----------|------|
| 前払いなし・1年 | 〜38% | 月額払い |
| 一部前払い・1年 | 〜40% | 初期費用 + 月額 |
| 全額前払い・1年 | 〜42% | 最大割引 |
| 前払いなし・3年 | 〜57% | |
| 一部前払い・3年 | 〜60% | |
| 全額前払い・3年 | 〜63% | 最大割引 |

**キャパシティ予約の有無**:
- **あり**: 特定AZで確実にキャパシティ確保。障害時の他AZ需要急増に対応
- **なし**: リージョン全体で有効。同一ファミリー内でインスタンスタイプ間を按分可能

**スタンダード vs コンバーティブル**（3年契約の場合）:
- **スタンダード**: 特定ファミリーに固定。安価
- **コンバーティブル**: 別ファミリーへの交換可能。将来の世代切替に対応。やや高価

推奨アプローチ: まずオンデマンドで開始 → 安定後にリザーブドへ移行。

### スポットインスタンス

未使用のAWSキャパシティに入札するモデル。価格は需要と供給で変動:

```
リクエスト種別:
- Load balancing workloads  同一スペックを複数AZで
- Flexible workloads        任意スペック（バッチ・CI/CD向け）
- Big data workloads        MapReduceジョブ
- Defined duration          1〜6時間のスポットブロック
```

**注意点**:
- スポット価格が入札上限を超えると2分後に強制終了
- Webサーバー・メールサーバーなど継続稼働が必要なサービスには不向き
- データ分析・メディアエンコード・リンクチェッカーなど非同期タスクに最適

---

## IaC（Infrastructure as Code）概念

### なぜIaCを使うのか

| 課題 | IaCで解決 |
|------|----------|
| 手順書は陳腐化する | コードが最新かつ正確なドキュメント |
| 属人的な作業ミス | 自動化により再現性を担保 |
| 環境差異（test≠prod） | 同一テンプレートから複数環境を複製 |
| スケールアウト時の手動作業 | スクリプト1回で100台も1台も同じ |
| ロールバック困難 | バージョン管理システムで変更追跡 |

IaCは**ブループリント（設計図）から実際のインフラを自動生成**するアプローチ。ブループリントを現在のシステムと比較し、作成・更新・削除の手順を自動判断する。

### 宣言的アプローチ vs 手続き的アプローチ

| | 宣言的 | 手続き的 |
|---|---|---|
| 記述内容 | 「どんな状態にしたいか」 | 「どの手順を実行するか」 |
| 例 | CloudFormation / Terraform | Bash / PowerShell |
| 依存関係 | ツールが自動解決 | 手動で順序を管理 |
| 冪等性 | 保証される | 自分で担保が必要 |

### DevOpsとの関係

DevOpsムーブメントの目標: **品質を下げずにソフトウェアの開発と提供を高速化**。

IaCが実現すること:
- CI/CDパイプラインの自動化（コミット → ビルド → テスト → デプロイ）
- 本番同等の環境をコードから自動生成してテスト
- コードリポジトリでインフラ変更を追跡

---

## AWS CLI

### インストール

```bash
# Linux/macOS（pipを使用）
curl "https://bootstrap.pypa.io/get-pip.py" -o "get-pip.py"
sudo python get-pip.py
sudo pip install awscli
aws --version  # 1.11.136以上を確認

# Windows: MSIインストーラをダウンロードして実行
# http://aws.amazon.com/cli/
```

### 設定（aws configure）

IAMユーザー（プログラムによるアクセス）を作成し、認証情報を設定:

```bash
$ aws configure
AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
Default region name [None]: us-east-1
Default output format [None]: json
```

**セキュリティ原則**: rootアカウントでのCLI使用は禁止。最小権限のIAMユーザーを作成すること。

### 主要コマンドパターン

```bash
# 基本構文
aws <サービス> <アクション> [--key <値> ...]

# ヘルプ
aws help                           # 利用可能なサービス一覧
aws ec2 help                       # EC2のアクション一覧
aws ec2 describe-instances help    # 特定アクションのオプション一覧

# リージョン一覧
aws ec2 describe-regions

# EC2インスタンス一覧（フィルタ付き）
aws ec2 describe-instances --filters "Name=instance-type,Values=t2.micro"

# JMESPath クエリ（特定フィールド抽出）
aws ec2 describe-images --query "Images[0].ImageId"
aws ec2 describe-images --query "Images[0].ImageId" --output text
aws ec2 describe-images --query "Images[*].State"
```

### CLIスクリプトによるEC2自動化

```bash
#!/bin/bash -e

# AMI IDを動的取得
AMIID="$(aws ec2 describe-images \
  --filters "Name=name,Values=amzn-ami-hvm-2017.09.1.*-x86_64-gp2" \
  --query "Images[0].ImageId" --output text)"

# デフォルトVPCとサブネットを取得
VPCID="$(aws ec2 describe-vpcs \
  --filter "Name=isDefault,Values=true" \
  --query "Vpcs[0].VpcId" --output text)"

SUBNETID="$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPCID" \
  --query "Subnets[0].SubnetId" --output text)"

# セキュリティグループ作成
SGID="$(aws ec2 create-security-group \
  --group-name mysecuritygroup \
  --description "My security group" \
  --vpc-id "$VPCID" --output text)"

aws ec2 authorize-security-group-ingress \
  --group-id "$SGID" --protocol tcp --port 22 --cidr 0.0.0.0/0

# インスタンス起動
INSTANCEID="$(aws ec2 run-instances \
  --image-id "$AMIID" --key-name mykey \
  --instance-type t2.micro \
  --security-group-ids "$SGID" --subnet-id "$SUBNETID" \
  --query "Instances[0].InstanceId" --output text)"

# 起動待機
aws ec2 wait instance-running --instance-ids "$INSTANCEID"

# パブリックDNS取得
PUBLICNAME="$(aws ec2 describe-instances \
  --instance-ids "$INSTANCEID" \
  --query "Reservations[0].Instances[0].PublicDnsName" --output text)"

echo "ssh -i mykey.pem ec2-user@$PUBLICNAME"
read -r -p "Press [Enter] to terminate ..."

# 終了とクリーンアップ
aws ec2 terminate-instances --instance-ids "$INSTANCEID"
aws ec2 wait instance-terminated --instance-ids "$INSTANCEID"
aws ec2 delete-security-group --group-id "$SGID"
```

---

## AWS SDK（Node.js）

### サポート言語

AWS SDKは以下の言語をサポート: JavaScript (Node.js/ブラウザ)・Python・Java・Go・Ruby・PHP・.NET・C++・Android・iOS

SDKが提供する機能:
- 認証の自動処理
- エラー発生時のリトライ
- HTTPS通信
- JSON/XMLシリアル化/デシリアル化

### nodecc（Node Control Center for AWS）

SDK を使ってEC2インスタンスを制御するNode.jsアプリケーションの例:

```javascript
// lib/listAMIs.js
const jmespath = require('jmespath');
const AWS = require('aws-sdk');
const ec2 = new AWS.EC2({ region: 'us-east-1' });

module.exports = (cb) => {
  ec2.describeImages({
    Filters: [{
      Name: 'name',
      Values: ['amzn-ami-hvm-2017.09.1.*-x86_64-gp2']
    }]
  }, (err, data) => {
    if (err) {
      cb(err);
    } else {
      const amiIds = jmespath.search(data, 'Images[*].ImageId');
      const descriptions = jmespath.search(data, 'Images[*].Description');
      cb(null, { amiIds, descriptions });
    }
  });
};
```

SDKはCLIと同じ認証情報（`aws configure`で設定したもの）を使用する。

---

## CloudFormation テンプレート構造

### 概要

CloudFormationはインフラの**宣言的な説明（テンプレート）**をAWS API呼び出しに変換するIaCサービス。依存関係を自動解決し、正しい順序でリソースを作成する。

**CloudFormationの利点**:
- AWSインフラを一貫した方法で定義
- 依存関係を自動解決（手動での順序管理不要）
- テスト環境と本番環境の完全複製
- カスタムパラメータによるテンプレート再利用
- インフラ更新をサポート（変更差分のみ適用）
- テンプレート自体がバージョン管理可能なドキュメント
- **追加料金なし**（CloudFormation利用は無料）

### テンプレートの5つのセクション

```yaml
---
AWSTemplateFormatVersion: '2010-09-09'   # 必須。現時点で唯一有効な値

Description: 'テンプレートの目的を記述'    # 推奨

Parameters: ...    # 入力値（ドメイン名・パスワード等）

Resources: ...     # 必須。作成するAWSリソースを定義

Outputs: ...       # 出力値（パブリックDNS・エンドポイント等）
```

### Parameters（パラメータ）

```yaml
Parameters:
  KeyName:
    Description: 'Key Pair name'
    Type: 'AWS::EC2::KeyPair::KeyName'   # AWS固有型で入力値を検証
  NumberOfVMs:
    Description: '起動する仮想マシン数'
    Type: Number
    Default: 1
    MinValue: 1
    MaxValue: 5      # コスト制御のため上限設定
  WordPressVersion:
    Description: 'WordPressのバージョン'
    Type: String
    AllowedValues: ['4.1.1', '4.0.1']   # 許可値を限定
```

**パラメータの型**:

| 型 | 説明 |
|----|------|
| String | 文字列 |
| Number | 整数/浮動小数点 |
| CommaDelimitedList | カンマ区切りリスト |
| AWS::EC2::KeyPair::KeyName | EC2キーペア名（存在確認） |
| AWS::EC2::Image::Id | AMI ID |
| AWS::EC2::Instance::Id | EC2インスタンスID |
| AWS::EC2::SecurityGroup::Id | セキュリティグループID |
| AWS::EC2::Subnet::Id | サブネットID |
| AWS::EC2::VPC::Id | VPC ID |
| AWS::EC2::AvailabilityZone::Name | AZ名 |
| AWS::Route53::HostedZone::Id | Route 53ホストゾーンID |

**パラメータのプロパティ**:

| プロパティ | 説明 | 例 |
|-----------|------|-----|
| Default | デフォルト値 | `Default: 'm5.large'` |
| NoEcho | 値を非表示（パスワード用） | `NoEcho: true` |
| AllowedValues | 有効な値のリスト | `AllowedValues: [1, 2, 3]` |
| AllowedPattern | 正規表現パターン | `AllowedPattern: '[a-zA-Z0-9]*'` |
| MinLength/MaxLength | 文字数制限 | `MinLength: 12` |
| MinValue/MaxValue | 数値範囲 | `MaxValue: 10` |
| ConstraintDescription | 制約違反時のメッセージ | `ConstraintDescription: '上限は10です'` |

### Resources（リソース）

```yaml
Resources:
  # セキュリティグループの例
  SecurityGroup:
    Type: 'AWS::EC2::SecurityGroup'
    Properties:
      GroupDescription: 'SSH and HTTP access'
      VpcId: !Ref VPC
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 22
          ToPort: 22
          CidrIp: 0.0.0.0/0
        - IpProtocol: tcp
          FromPort: 80
          ToPort: 80
          CidrIp: 0.0.0.0/0

  # EC2インスタンスの例
  VM:
    Type: 'AWS::EC2::Instance'
    Properties:
      ImageId: 'ami-6057e21a'
      InstanceType: !Ref InstanceType     # パラメータ参照
      KeyName: !Ref KeyName
      NetworkInterfaces:
        - AssociatePublicIpAddress: true
          DeleteOnTermination: true
          DeviceIndex: 0
          GroupSet:
            - !Ref SecurityGroup          # 別リソース参照（依存関係）
          SubnetId: !Ref Subnet
```

**組み込み関数**:

| 関数 | 説明 | 例 |
|------|------|-----|
| `!Ref <名前>` | パラメータ/リソースの参照 | `!Ref InstanceType` |
| `!GetAtt '<リソース>.<属性>'` | リソースの属性取得 | `!GetAtt 'VM.PublicDnsName'` |
| `!Sub '<文字列>'` | `${}` 内の参照を値に置換 | `!Sub 'VPC: ${VPC}'` |
| `!Base64 '<値>'` | Base64エンコード（UserData用） | `!Base64 'value'` |

### Outputs（出力）

```yaml
Outputs:
  InstanceID:
    Value: !Ref VM
    Description: 'EC2インスタンスのID'
  PublicName:
    Value: !GetAtt 'VM.PublicDnsName'
    Description: 'パブリックDNS名（SSH接続先）'
  VPNUser:
    Value: !Ref VPNUser
    Description: 'VPN接続ユーザー名'
```

### Mappings / Conditions（補足）

```yaml
# Mappings: 条件に応じた値の対応表（リージョン別AMI IDなど）
Mappings:
  RegionAMI:
    us-east-1:
      AMI: ami-0abcdef1
    ap-northeast-1:
      AMI: ami-0fedcba9

# Conditions: 条件によるリソース作成の制御
Conditions:
  IsProduction: !Equals [!Ref Environment, 'prod']

Resources:
  ProdOnlyResource:
    Type: '...'
    Condition: IsProduction
```

---

## CloudFormation テンプレート作成の実践

### UserData を使った起動時スクリプト実行

仮想マシン起動時にシェルスクリプトを自動実行する仕組み:

```yaml
Resources:
  VM:
    Type: 'AWS::EC2::Instance'
    Properties:
      ImageId: !FindInMap [RegionAMI, !Ref 'AWS::Region', AMI]
      InstanceType: !Ref InstanceType
      UserData:
        !Base64         # UserDataはBase64エンコード必須
          !Sub |        # !Sub で変数置換
            #!/bin/bash -ex
            # パッケージ更新
            yum update -y
            # アプリケーションのインストール
            yum install -y <package>
            # 設定ファイルの編集
            echo "config_value=${ConfigParam}" >> /etc/app/config
            # サービス起動
            service myapp start
```

**UserDataの特徴**:
- 容量制限: 16KB
- 実行タイミング: AMI起動プロセスの最後
- 実行ユーザー: root
- URLアクセス: `http://169.254.169.254/latest/user-data`（インスタンス内部のみ）

### スタックの作成・管理

```bash
# スタック作成
aws cloudformation create-stack \
  --stack-name my-stack \
  --template-url https://s3.amazonaws.com/bucket/template.yaml \
  --parameters \
    ParameterKey=KeyName,ParameterValue=mykey \
    ParameterKey=VPC,ParameterValue=$VpcId

# スタック作成完了まで待機
aws cloudformation wait stack-create-complete --stack-name my-stack

# スタックの出力確認
aws cloudformation describe-stacks \
  --stack-name my-stack \
  --query "Stacks[0].Outputs"

# スタック削除
aws cloudformation delete-stack --stack-name my-stack
```

---

## デプロイ方法の比較

### 3つのデプロイアプローチ

```
制御能力（柔軟性）↑
CloudFormation + カスタムスクリプト（UserData）
OpsWorks スタック
Elastic Beanstalk
従来型（手動）
```

| | CloudFormation + UserData | Elastic Beanstalk | OpsWorks |
|---|---|---|---|
| 構成管理ツール | 任意のツール | 専用ツール | Chef |
| 対応プラットフォーム | すべて | PHP / Node.js / Java / Python / Ruby / Go / Docker / .NET | PHP / Node.js / Java / Ruby / カスタム |
| 成果物形式 | すべて | S3上のZipアーカイブ | Git / SVN / Zip |
| 主なシナリオ | 中規模以上の企業 | 小企業・シンプルなWA | Chef経験者 |
| ダウンタイムなし更新 | 設定で可能 | 可能 | 可能 |
| ベンダーロックイン | 中 | 高 | 中 |
| 学習コスト | 中 | 低 | 高（Chef知識要） |

**推奨**: CloudFormation + UserData。柔軟性が高く、他のAWSサービスとの統合が優秀。

---

## Elastic Beanstalk

### 概要と解決する課題

Elastic Beanstalkは一般的なWebアプリケーションのデプロイを簡略化するPaaS的サービス:

| 課題 | Elastic Beanstalkによる解決 |
|------|---------------------------|
| Webアプリの実行環境構築 | 実行環境（PHP・Node.js等）を自動提供 |
| OS/ランタイムの更新 | 自動更新オプション |
| デプロイ作業の自動化 | アプリバージョンのデプロイを自動化 |
| スケーリング | Auto Scaling + ELBを自動設定 |
| 監視・デバッグ | ログ収集・ヘルスチェックを統合 |

### 構成要素

```
アプリケーション（論理コンテナ）
├── バージョン0.1（S3上のZipアーカイブへのポインタ）
├── バージョン0.2
├── バージョン0.3
├── 設定テンプレートA（インスタンスタイプ・Auto Scaling設定等）
├── 設定テンプレートB
├── 環境: prod（バージョン0.3 + 設定A → 実際に動く仮想マシン群）
└── 環境: staging（バージョン0.3 + 設定B）
```

- **アプリケーション**: 論理コンテナ（1リージョンに1つ）
- **バージョン**: 特定リリースのアーカイブへのポインタ
- **構成テンプレート**: インスタンスタイプ・待ち受けポート等の設定
- **環境**: バージョン + 設定で実際に実行される単位

### Etherpad デプロイ例

```bash
# 1. アプリケーション（論理コンテナ）作成
aws elasticbeanstalk create-application --application-name etherpad

# 2. バージョン作成（S3上のZipを参照）
aws elasticbeanstalk create-application-version \
  --application-name etherpad \
  --version-label 1 \
  --source-bundle "S3Bucket=awsinaction-code2,S3Key=chapter05/etherpad.zip"

# 3. 利用可能なソリューションスタック名を確認
aws elasticbeanstalk list-available-solution-stacks --output text \
  --query "SolutionStacks[?contains(@, 'running Node.js')]"

# 4. 環境（実行環境）作成
aws elasticbeanstalk create-environment \
  --environment-name etherpad \
  --application-name etherpad \
  --option-settings \
    Namespace=aws:elasticbeanstalk:environment,\
    OptionName=EnvironmentType,Value=SingleInstance \
  --solution-stack-name "<ソリューションスタック名>" \
  --version-label 1

# 5. デプロイ状態の確認
aws elasticbeanstalk describe-environments --environment-names etherpad
# Status: Ready、Health: Green を確認

# 6. 削除
aws elasticbeanstalk terminate-environment --environment-name etherpad
aws elasticbeanstalk delete-application --application-name etherpad
```

### ログ・デバッグ

- AWSコンソール → Elastic Beanstalk → 環境 → ログ → [ログのリクエスト]
- 最後の100行をダウンロードして確認可能
- SSHなしでアプリケーションログを取得できる

---

## OpsWorks

### 概要

複数のサービス（レイヤ）で構成される**多層アプリケーション**のデプロイに適したサービス:

```
OpsWorksの種類:
1. OpsWorks スタック
   - Chef 11: 組み込みレイヤ豊富（初心者向け）
   - Chef 12: 組み込みレイヤなし（Chef経験者向け）
2. OpsWorks for Chef Automate
   - 既存のChef管理インフラをAWSへ移行する場合に使用
```

**標準レイヤ**（OpsWorks スタック組み込み）:

| レイヤ | 用途 |
|--------|------|
| HAProxy | ロードバランサー |
| 静的Webサーバー | 静的コンテンツ配信 |
| Rails | Ruby on Railsアプリ |
| PHP | PHPアプリ |
| Node.js | Node.jsアプリ |
| Java (Tomcat) | Javaアプリ |
| MySQL | データベース |
| Memcached | インメモリキャッシュ |
| Ganglia | 監視 |
| カスタム | 任意のアプリ（Chefレシピで定義） |

### スタックの構成要素

```
スタック（最上位コンテナ）
├── Webサーバーレイヤ（PHPアプリ）
│   ├── インスタンス → アプリケーション
│   └── インスタンス → アプリケーション
├── APIサーバーレイヤ（Java REST API）
│   └── インスタンス
└── データベースレイヤ（MySQL）
    └── インスタンス
```

- **スタック**: 全コンポーネントのコンテナ。本番/テスト環境の分離に使用
- **レイヤ**: 特定役割を担うEC2インスタンス群の論理グループ
- **インスタンス**: 実際のEC2仮想マシン
- **アプリケーション**: デプロイするアプリのソースコードと設定

### Chefとの関係

OpsWorksのデプロイメントはChef（構成管理ツール）を使って制御される:

```
Chefの概念:
- レシピ（Recipe）: 「このパッケージをインストール」「このサービスを起動」等のDSL
- クックブック（Cookbook）: 関連するレシピのコレクション
- Chef Supermarket: オープンソースのクックブック共有サイト
  https://supermarket.chef.io/

動作モード:
- 単独モード（solo）: 1台の仮想マシンでレシピを実行（OpsWorksが使用）
- クライアント/サーバーモード: 多数の仮想マシンを集中管理
```

OpsWorksはChefの**フリート管理を組み込み**、単独モードを統合して使用するため、クライアント/サーバーの構成が不要。

### OpsWorks スタックによるIRCサーバーデプロイ例

```bash
# 1. スタック作成
aws opsworks create-stack \
  --name my-stack \
  --region us-east-1 \
  --service-role-arn <ServiceRole ARN> \
  --default-instance-profile-arn <InstanceProfile ARN>

# 2. Webレイヤ作成
aws opsworks create-layer \
  --stack-id <StackId> \
  --type custom \
  --name "IRC Web Client" \
  --shortname "ircweb"

# 3. インスタンス追加
aws opsworks create-instance \
  --stack-id <StackId> \
  --layer-ids <LayerId> \
  --instance-type t2.micro

# 4. アプリケーション登録
aws opsworks create-app \
  --stack-id <StackId> \
  --name "IRC App" \
  --type other \
  --app-source '{"Type":"git","Url":"https://github.com/example/irc.git"}'

# 5. デプロイ実行
aws opsworks create-deployment \
  --stack-id <StackId> \
  --app-id <AppId> \
  --command '{"Name":"deploy"}'
```

---

## まとめ: ツール選択ガイド

| 状況 | 推奨ツール |
|------|-----------|
| 任意のソフトウェアを柔軟にデプロイしたい | CloudFormation + UserData |
| Node.js / PHP / Python等の標準的なWebアプリ | Elastic Beanstalk |
| 複数サービスの多層アプリ、Chefを使い慣れている | OpsWorks スタック |
| 既存のChef管理インフラをAWSに移行 | OpsWorks for Chef Automate |
| インフラを繰り返し複製（本番/テスト環境） | CloudFormation |
| 構成管理をコードとしてGit管理したい | CloudFormation / Terraform |
