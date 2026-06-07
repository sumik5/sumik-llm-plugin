# GCE 仮想マシン運用（Compute Engine 詳細ガイド）

Google Compute Engine（GCE）は Google のインフラストラクチャで稼働する IaaS 型仮想マシンサービスで、2013年に正式公開された。ライブマイグレーション・カスタムマシンタイプ・継続利用割引（SUD）という他社クラウドとの差別化機能を持ち、エンタープライズシステムの基盤として最も広く利用される。本リファレンスではマシンタイプ・ディスク・ネットワーク・MIG・ライブマイグレーション・起動スクリプト・運用自動化を網羅する。

## マシンタイプ（ファミリー別詳細）

### マシンファミリー選択ガイド

| マシンファミリー | 代表モデル | 1コアあたりメモリ | 最適なワークロード |
|--------------|----------|--------------|-----------------|
| **汎用 E2** | e2-standard-4 | 4GB | コスト重視・一般的な Web アプリ（N1 比最大 31% 削減） |
| **汎用 N2** | n2-standard-8 | 4GB | バランス型・第2世代（N1 比 20%以上コスト性能改善） |
| **汎用 N2D** | n2d-standard-16 | 4GB | 最大コア数・メモリ（AMD EPYC） |
| **汎用 N1** | n1-standard-4 | 3.75GB | GPU アタッチが必要な場合 |
| **コンピューティング最適化 C2** | c2-standard-8 | 4GB | HPC・ゲームサーバー・低レイテンシ API |
| **メモリ最適化 M1/M2** | m1-megamem-96 | 14.4〜24GB | インメモリ DB・分析（最大 12TB メモリ） |
| **アクセラレータ最適化 A2** | a2-highgpu-1g | 85GB + A100 GPU | ML トレーニング・推論・HPC |
| **共有コア F1/G1/E2-micro** | e2-micro | 共有（バースト可） | 低負荷・開発環境・軽量 Web |

### カスタムマシンタイプ

汎用ファミリー（E2/N2/N2D/N1）では vCPU 数とメモリサイズをカスタマイズできる。事前定義のマシンタイプで「CPU は不足しないがメモリが多すぎる」という無駄コストを削減。

```bash
# カスタムマシンタイプ（6vCPU + 20GB RAM）でインスタンス作成
gcloud compute instances create my-instance \
  --zone=asia-northeast1-a \
  --machine-type=n2-custom-6-20480  # 6vCPU / 20480MB
```

**設計指針:**
- 新規サービスは余裕のあるサイズでスタートし、負荷実績を見てダウンサイジング
- E2/N2 の最新世代を優先（旧 N1 は GPU 利用時のみ）
- Recommender を活用して過剰リソースを定期的に検出

### GCE ベンチマーク特性（ゲームインフラ実績から）

| 特性 | 内容 |
|------|------|
| **インスタンス起動速度** | リージョン・数に依存せず 30〜40秒で起動（競合他社より高速） |
| **インスタンスガチャなし** | 同一スペック指定でも性能ばらつきが極めて少ない |
| **ライブマイグレーション効果** | ハイパーバイザーのパッチ適用中もブラックアウトほぼなし |
| **カスタマイズ性** | サービス開始後でもインスタンスサイズを柔軟に変更可能 |

## ストレージ（ディスク）タイプ

### ディスクタイプ比較

| ディスクタイプ | IOPS（読取最大） | レイテンシ | コスト | 推奨用途 |
|-------------|--------------|---------|-------|---------|
| **標準永続ディスク（pd-standard）** | 低 | 高め | 最安 | シーケンシャルアクセス・大規模データ処理・バックアップ |
| **バランス永続ディスク（pd-balanced）** | 中 | 中 | 中 | 汎用アプリケーション（SSD と Standard の中間コスト） |
| **SSD 永続ディスク（pd-ssd）** | 高 | 10ms未満 | 高め | エンタープライズ DB・高性能アプリ |
| **エクストリーム永続ディスク（pd-extreme）** | 最高（プロビジョニング可） | 最低 | 最高 | ハイエンド DB（IOPS を明示的に設定） |
| **ローカル SSD** | 最高 | 最低（物理直結） | VM 停止でデータ消失 | キャッシュ・一時データ・高 IO ステートレス処理 |

### ゾーン永続ディスク vs リージョン永続ディスク

| 比較軸 | ゾーン永続ディスク | リージョン永続ディスク |
|--------|----------------|---------------------|
| **データ複製** | ゾーン内の複数物理ディスク | リージョン内の 2 ゾーン間で同期レプリケーション |
| **ゾーン障害時** | データへのアクセス不可 | 稼働ゾーンのインスタンスにフェイルオーバー可 |
| **コスト** | 低い | 2倍程度 |
| **推奨用途** | 一般的なワークロード | 高可用性が必要な DB |

```bash
# リージョン永続ディスクの作成（HA DB 向け）
gcloud compute disks create ha-db-disk \
  --type=pd-ssd \
  --size=500GB \
  --region=asia-northeast1 \
  --replica-zones=asia-northeast1-a,asia-northeast1-b
```

## ネットワーク

### GCE インスタンスのネットワーク特性

- 同一 VPC 内の異なるリージョン間でも内部 IP で通信可能（プライベートネットワーク構成が容易）
- グローバル VPC によりリージョン間をまたいだプライベートネットワーク構築コスト・複雑さが大幅に減少（ゲームインフラでの実績: フェイルオーバーとロードバランシングを単一グローバル IP で実現）

```bash
# 内部 IP のみのインスタンス作成（外部 IP なし・セキュア）
gcloud compute instances create private-instance \
  --zone=asia-northeast1-a \
  --machine-type=n2-standard-4 \
  --no-address  # 外部 IP なし

# Cloud NAT 経由でインターネットアクセスを提供
gcloud compute routers create my-router \
  --region=asia-northeast1 \
  --network=my-vpc

gcloud compute routers nats create my-nat \
  --router=my-router \
  --region=asia-northeast1 \
  --auto-allocate-nat-external-ips \
  --nat-all-subnet-ip-ranges
```

## マネージドインスタンスグループ（MIG）

### MIG の役割と種類

同一機能を持つ複数の VM をグループ化し、高可用性・自動スケーリング・自動修復・ローリングアップデートを実現する。

| MIG タイプ | 対象ワークロード | 特徴 |
|----------|--------------|------|
| **ステートレス MIG** | Web アプリフロントエンド・API サーバー | スケール・自動修復・ローリングアップデート |
| **ステートフル MIG** | RDB（MySQL/PostgreSQL 等）・ステートフルアプリ | 永続ディスク・インスタンス固有メタデータを保持して修復 |

```bash
# インスタンステンプレートの作成
gcloud compute instance-templates create web-template \
  --machine-type=n2-standard-4 \
  --image-family=debian-11 \
  --image-project=debian-cloud \
  --tags=http-server \
  --metadata=startup-script='#!/bin/bash
    apt-get update
    apt-get install -y nginx
    systemctl start nginx'

# MIG の作成（マルチゾーン自動スケーリング）
gcloud compute instance-groups managed create web-mig \
  --template=web-template \
  --region=asia-northeast1 \
  --size=3

# オートスケーリング設定
gcloud compute instance-groups managed set-autoscaling web-mig \
  --region=asia-northeast1 \
  --min-num-replicas=2 \
  --max-num-replicas=20 \
  --target-cpu-utilization=0.60 \
  --cool-down-period=60
```

### ローリングアップデート

```bash
# 新しいインスタンステンプレートでローリングアップデート
gcloud compute instance-groups managed rolling-action start-update web-mig \
  --region=asia-northeast1 \
  --version=template=web-template-v2 \
  --max-surge=3 \      # 一時的に追加できる VM 数
  --max-unavailable=0  # 同時に停止できる VM 数

# アップデート状況確認
gcloud compute instance-groups managed describe web-mig \
  --region=asia-northeast1
```

## ライブマイグレーション

### ライブマイグレーションの概要と仕組み

GCE の最大の差別化機能の一つ。ハードウェア・ホスト OS のメンテナンス時に、稼働中のインスタンスを**無停止で同一ゾーン内の別物理サーバーへ自動移動**する。

**ライブマイグレーションの処理手順:**
1. (A) を稼働させたままメモリデータを (B) にコピー
2. (A) を一瞬停止し、Step 1 の差分を (B) にコピー（ブラックアウト期間を最小化）
3. (A) が受け取ったネットワークパケットを (B) に転送
4. (A) を廃棄

**業界での差別化:**
- 一般的なライブマイグレーション: 約 1 秒のブラックアウト + パケットロスあり
- GCE のライブマイグレーション: ブラックアウトほぼ0・パケットロスなし
- 事例: Heartbleed 脆弱性（2014年）対応時、他社クラウドでは多数の再起動が発生したが、GCE ユーザーへの影響はほぼゼロ

```bash
# テスト目的でライブマイグレーションを手動実行
gcloud compute instances move my-instance \
  --zone=asia-northeast1-a \
  --destination-zone=asia-northeast1-b
```

**注意:** ライブマイグレーションは VM レベルの機能。OS・アプリケーション起因の障害には MIG + ロードバランサによる冗長化が必要。プリエンプティブル VM は対象外。

## 起動スクリプト（Startup Script）

### 起動スクリプトの活用

VM 作成時にアプリケーションセットアップを自動化する。メタデータサーバーから起動スクリプトを取得して実行する。

```bash
# インラインで起動スクリプトを設定
gcloud compute instances create app-server \
  --zone=asia-northeast1-a \
  --machine-type=n2-standard-4 \
  --metadata=startup-script='#!/bin/bash
    set -e
    # システム更新
    apt-get update -y
    apt-get upgrade -y

    # アプリケーションインストール
    apt-get install -y docker.io

    # Secret Manager から設定を取得
    DB_PASSWORD=$(gcloud secrets versions access latest --secret="db-password")

    # Docker コンテナ起動
    docker run -d \
      -e DB_PASSWORD="$DB_PASSWORD" \
      -p 8080:8080 \
      asia-northeast1-docker.pkg.dev/PROJECT/REPO/app:latest'

# GCS に配置したスクリプトを参照
gcloud compute instances create app-server \
  --zone=asia-northeast1-a \
  --metadata=startup-script-url=gs://my-bucket/startup.sh
```

## 構成管理の自動化

### Ansible との統合

大量の VM を一括で管理・設定変更する際に Ansible が有効。GCE dynamic inventory で VM を自動検出して操作できる。

```yaml
# playbook.yml: Nginx インストールと設定
- name: Configure web servers
  hosts: tag_http-server  # GCE タグでフィルタリング
  become: yes
  tasks:
    - name: Install Nginx
      apt:
        name: nginx
        state: present
    - name: Copy configuration
      template:
        src: nginx.conf.j2
        dest: /etc/nginx/nginx.conf
      notify: Restart Nginx
  handlers:
    - name: Restart Nginx
      service:
        name: nginx
        state: restarted
```

```bash
# GCE dynamic inventory を使用して Ansible を実行
ansible-playbook playbook.yml -i gcp.yml
```

## 暗号化オプション

| 暗号化方式 | 概要 | 推奨場面 |
|-----------|------|---------|
| **Google 管理デフォルト暗号化** | 自動処理・追加コストなし | 一般用途 |
| **顧客指定暗号鍵（CSEK）** | ユーザーが独自鍵を指定 | 鍵の完全自己管理が必要な場合 |
| **顧客管理暗号鍵（CMEK）** | Cloud KMS で生成した鍵を利用 | 規制要件・鍵のライフサイクル管理が必要な場合 |

## 運用ポイント整理

### SLA とゾーン構成

| 構成 | SLA |
|------|-----|
| 単一ゾーン | 99.5% |
| マルチゾーン（MIG） | 99.99% |

**エンタープライズ本番環境の推奨:** MIG + マルチゾーン + リージョン永続ディスク（HA 構成）でゾーン障害に耐性を持たせる。

### コスト最適化チェックリスト

- [ ] 使用率の低い VM を Recommender で検出し、ダウンサイジングまたは停止
- [ ] バッチジョブはプリエンプティブル VM で実行（最大 91% 割引）
- [ ] 長期稼働インスタンスは CUD（Committed Use Discount）を検討
- [ ] SUD は自動適用されるが、利用状況レポートで割引額を確認
- [ ] カスタムマシンタイプで事前定義タイプとのコスト差を比較

### ユーザビリティ（管理ツール）

| ツール | 概要 |
|--------|------|
| **Cloud Console** | Web ブラウザから VM 管理・Logs・Metrics 確認 |
| **Cloud Shell** | ブラウザ上のターミナル（gcloud/docker プリインストール済み） |
| **gcloud CLI** | スクリプト化・CI/CD 統合に必須 |
| **メタデータサーバー** | 起動スクリプト・タグ・IP 等の情報をインスタンス内から取得 |
| **Ops Agent** | ホワイトボックス監視（CPU/メモリ/ディスク/カスタムメトリクス）|
