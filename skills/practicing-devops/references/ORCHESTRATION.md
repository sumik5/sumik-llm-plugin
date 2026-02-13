# オーケストレーション詳細比較

## 概要

オーケストレーションは、複数のアプリケーションインスタンスを展開・管理する方法です。4つのアプローチがあり、それぞれ異なるトレードオフを持ちます。

---

## オーケストレーション 4分類

### 1. Server Orchestration（サーバーオーケストレーション）

**定義**: Configuration Managementツール（Ansible等）を使用して、複数の物理サーバーに直接アプリをデプロイ・管理する手法。

**例**: Ansible Playbook

#### アーキテクチャ

```
Ansible Controller
      ↓
   SSH接続
      ↓
[Server 1] [Server 2] [Server 3]
  App       App       App
```

#### 特徴

| 項目 | 評価 | 説明 |
|------|------|------|
| Replicas | 手動設定 | Playbookで台数を指定 |
| Load Balancing | 外部LB | 別途ロードバランサー（Nginx、HAProxy等）が必要 |
| Auto Scaling | ❌ | 手動でサーバー追加・Playbook再実行 |
| Auto Healing | ❌ | 障害検知・復旧は手動 |
| Zero-Downtime Deployment | 手動実装 | Ansibleのローリングデプロイ機能で可能だが、設定が必要 |

#### メリット
- ✅ 学習コストが低い（SSH・Ansibleの基礎知識で可）
- ✅ 追加のインフラ不要（既存サーバーで動作）
- ✅ シンプル（複雑な抽象化レイヤーなし）

#### デメリット
- ❌ Auto Scaling / Auto Healing なし
- ❌ ロードバランサーを手動設定
- ❌ スケールに限界（数十台が限度）

#### ユースケース
- 小規模プロジェクト（サーバー数台〜数十台）
- 学習・プロトタイピング
- レガシーシステムの移行段階

#### 推奨アプローチ
**学習目的・小規模プロジェクトに最適。スケールが必要になったら、VM/Container Orchestrationに移行。**

---

### 2. VM Orchestration（仮想マシンオーケストレーション）

**定義**: クラウドプロバイダーの仮想マシン管理機能（AWS Auto Scaling Group等）を使用して、VM群を自動管理する手法。

**例**: AWS Auto Scaling Group (ASG) + Application Load Balancer (ALB)

#### アーキテクチャ

```
         ALB
          ↓
  Auto Scaling Group
  ┌─────┬─────┬─────┐
  │ VM1 │ VM2 │ VM3 │
  └─────┴─────┴─────┘
  ↑ Auto Scaling / Healing
```

#### 特徴

| 項目 | 評価 | 説明 |
|------|------|------|
| Replicas | ✅ | Desired/Min/Max Capacityで設定 |
| Load Balancing | ✅ | ALB/NLBがトラフィック分散 |
| Auto Scaling | ✅ | CloudWatch Metrics（CPU、メモリ等）ベースで自動スケール |
| Auto Healing | ✅ | Health Check失敗時に自動再起動 |
| Zero-Downtime Deployment | ✅ | Instance Refresh（ローリングデプロイ）で実現 |

#### コア機能詳細

**Replicas（レプリカ管理）**:
- Desired Capacity: 通常時の台数
- Min Capacity: 最小台数
- Max Capacity: 最大台数
- ASGが自動的に台数を維持

**Load Balancing**:
- ALB: HTTP/HTTPSトラフィック、パスベースルーティング、ホストベースルーティング
- NLB: TCP/UDPトラフィック、超低レイテンシー
- Health Check: 定期的にインスタンスをチェック、失敗時はトラフィックを停止

**Auto Scaling**:
- Target Tracking Scaling: CPU使用率50%を維持するようにスケール
- Step Scaling: メトリクスに応じて段階的にスケール
- Scheduled Scaling: 時間ベースでスケール

**Auto Healing**:
- Health Check失敗時、ASGが自動的にインスタンスを終了・再起動
- ELB Health CheckとEC2 Health Checkの両方をサポート

**Zero-Downtime Deployment**:
- Instance Refresh: 新しいAMI/Launch Templateでインスタンスをローリング置換
- Blue-Green Deployment: 新しいASGを作成 → トラフィック切り替え → 旧ASG削除

#### メリット
- ✅ クラウドプロバイダーのマネージドサービス（運用コスト低）
- ✅ Auto Scaling / Auto Healing が標準機能
- ✅ ロードバランサー統合が容易
- ✅ 学習コストが比較的低い（クラウドの基礎知識で可）

#### デメリット
- ❌ VMの起動が遅い（数分）
- ❌ リソースオーバーヘッド（VMごとに独立したOS）
- ❌ クラウドプロバイダー固有（ポータビリティ低）

#### ユースケース
- 中規模プロジェクト（数十〜数百台）
- クラウドネイティブアプリ
- 標準的なWebアプリ・APIサーバー

#### 推奨アプローチ
**クラウドで中規模プロジェクトを始める際のデファクトスタンダード。**

---

### 3. Container Orchestration（コンテナオーケストレーション）

**定義**: Kubernetes等のコンテナオーケストレーションプラットフォームを使用して、コンテナ群を自動管理する手法。

**例**: Kubernetes (EKS、GKE、AKS)

#### アーキテクチャ

```
    Kubernetes Cluster
    ┌──────────────────┐
    │  Control Plane   │
    │  (API, Scheduler)│
    └──────────────────┘
           ↓
    ┌──────────────────┐
    │  Worker Nodes    │
    │ ┌────┬────┬────┐ │
    │ │Pod1│Pod2│Pod3│ │
    │ └────┴────┴────┘ │
    └──────────────────┘
           ↑
       Service (LB)
```

#### 特徴

| 項目 | 評価 | 説明 |
|------|------|------|
| Replicas | ✅ | Deployment/ReplicaSetで設定 |
| Load Balancing | ✅ | Service（ClusterIP/NodePort/LoadBalancer）で自動 |
| Auto Scaling | ✅ | HPA（Horizontal Pod Autoscaler）、VPA（Vertical Pod Autoscaler）、Cluster Autoscaler |
| Auto Healing | ✅ | Liveness/Readiness Probeで自動検知・再起動 |
| Zero-Downtime Deployment | ✅ | Rolling Update、Blue-Green、Canary が標準機能 |

#### Kubernetesコア概念

**Pod**:
- 最小デプロイ単位
- 1つ以上のコンテナをグループ化
- 共有ネットワーク・ストレージ

**Deployment**:
- Podのレプリカ管理
- Rolling Update、Rollback機能
- 望ましい状態を宣言的に記述

**Service**:
- Pod群への安定したネットワークエンドポイント
- 負荷分散
- Service Discovery（DNS）

**ConfigMap / Secret**:
- 設定・機密情報の外部化
- Podに環境変数・ファイルとして注入

#### コア機能詳細

**Replicas**:
- Deploymentで `replicas: 3` を指定 → Kubernetes が自動的に3つのPodを維持
- Pod障害時は自動再作成

**Load Balancing**:
- Service（LoadBalancer型）: クラウドLB（ALB/NLB等）を自動作成
- Service（ClusterIP型）: クラスター内部LB
- Ingress: L7ルーティング（パスベース、ホストベース）

**Auto Scaling**:
- **HPA（Horizontal Pod Autoscaler）**: CPU/メモリ使用率に応じてPod数を自動スケール
- **VPA（Vertical Pod Autoscaler）**: リソース要求を自動調整
- **Cluster Autoscaler**: Node数を自動スケール（EKS Managed Node Group等）

**Auto Healing**:
- **Liveness Probe**: Podが生きているか定期チェック、失敗時は再起動
- **Readiness Probe**: Podがトラフィックを受け入れ可能か定期チェック、失敗時はServiceから除外
- **Startup Probe**: 起動時の初期化完了をチェック

**Zero-Downtime Deployment**:
- **Rolling Update**: 少しずつPodを置き換え（maxSurge / maxUnavailable設定可）
- **Blue-Green Deployment**: 新バージョンのDeploymentを作成 → Serviceのセレクタ切り替え
- **Canary Deployment**: 新バージョンを少数のPodにデプロイ → 徐々に比率を増加

#### メリット
- ✅ コンテナ高速起動（秒単位）
- ✅ リソース効率（OS共有）
- ✅ 高度なデプロイ戦略が標準機能
- ✅ ポータブル（クラウド・オンプレミス両対応）
- ✅ 豊富なエコシステム（Helm、Istio、ArgoCD等）
- ✅ 宣言的設定（YAML）

#### デメリット
- ❌ 学習曲線が急（Kubernetesの概念が多い）
- ❌ クラスター運用コスト（マネージドサービスで緩和可能）
- ❌ YAMLの冗長性（Helm等で緩和可能）
- ❌ デバッグが困難（多層抽象化）

#### ユースケース
- 大規模プロジェクト（数百〜数千コンテナ）
- マイクロサービスアーキテクチャ
- 高頻度デプロイ（1日複数回）
- マルチクラウド・ハイブリッドクラウド

#### 推奨アプローチ
**大規模・複雑なプロジェクトに最適。学習・運用コストを許容できる場合に選択。**
マネージドKubernetes（EKS、GKE、AKS）を使用して運用負荷を削減。

---

### 4. Serverless Orchestration（サーバーレスオーケストレーション）

**定義**: 関数単位でコードをデプロイし、クラウドプロバイダーがサーバー・スケーリング・ヒーリングをすべて管理する手法。

**例**: AWS Lambda、Google Cloud Functions、Azure Functions

#### アーキテクチャ

```
       Trigger
   (HTTP/S3/Queue等)
          ↓
    Lambda Function
    (自動スケール)
          ↓
       Response
```

#### 特徴

| 項目 | 評価 | 説明 |
|------|------|------|
| Replicas | 自動管理 | トリガーの数に応じて自動スケール |
| Load Balancing | 自動管理 | クラウドプロバイダーが管理 |
| Auto Scaling | ✅ | トリガーに応じて自動スケール（0〜数千インスタンス） |
| Auto Healing | ✅ | 関数失敗時は自動リトライ |
| Zero-Downtime Deployment | ✅ | 新バージョンを即座にデプロイ、Version/Aliasでトラフィック制御 |

#### FaaS（Functions as a Service）モデル

**デプロイフロー**:
1. 関数コードをZip/JARにパッケージ
2. クラウドプロバイダーにアップロード
3. トリガー設定（HTTP、S3イベント、Queue等）
4. トリガー発火時、クラウドが関数を実行

**スケール to ゼロ**:
- トリガーがなければ、関数は実行されない（コストゼロ）
- トリガー発火時、クラウドが自動的にインスタンスを起動

#### メリット
- ✅ サーバー管理不要（OSアップデート・パッチ適用等もクラウド任せ）
- ✅ 超高速デプロイ（数秒〜数十秒）
- ✅ スケール to ゼロ（未使用時はコストゼロ）
- ✅ 使用量に応じた完全従量課金
- ✅ 超高速オートスケール（ミリ秒単位）

#### デメリット
- ❌ サイズ制限（デプロイパッケージ、イベントペイロード、レスポンスペイロード）
- ❌ 時間制限（AWS Lambda: 15分）
- ❌ ディスク容量制限（一時的・エフェメラル）
- ❌ パフォーマンスチューニング困難（ハードウェア抽象化）
- ❌ デバッグ困難（SSH不可）
- ❌ コールドスタート（初回実行時に数秒の遅延）
- ❌ 長時間接続困難（DB接続プール、WebSocket等）

#### Serverless Containers

**AWS Fargate、Google Cloud Run**:
- コンテナをサーバーレスで実行
- 長時間実行可能（コールドスタート回避）
- ただし、スケール to ゼロはなし（長時間実行コンテナは常時起動）

#### ユースケース
- イベント駆動型アプリ（S3アップロード、Queue処理等）
- 短時間実行タスク（15分以内）
- トラフィック変動が激しいアプリ（ゼロ〜数千リクエスト/秒）
- コスト最適化重視

#### 推奨アプローチ
**イベント駆動・短時間実行・トラフィック変動が大きい場合に最適。**
コールドスタート・長時間接続が許容できない場合は、Serverless Containersを検討。

---

## コア問題別比較

| 問題 | Server | VM | Container | Serverless |
|------|--------|-----|-----------|------------|
| **Replicas** | 手動 | ASG設定 | Deployment設定 | 自動 |
| **Load Balancing** | 外部LB | ALB/NLB | Service | 自動 |
| **Auto Scaling** | ❌ | CloudWatch | HPA/VPA | ✅ |
| **Auto Healing** | ❌ | Health Check | Liveness Probe | ✅ |
| **Zero-Downtime Deploy** | Ansible Rolling | Instance Refresh | Rolling/Blue-Green/Canary | Version/Alias |

---

## コア属性別比較

| 属性 | Server | VM | Container | Serverless |
|------|--------|-----|-----------|------------|
| **Deployment Speed** | 遅い（数分〜数十分） | 遅い（数分） | 速い（1〜5分） | 超高速（数秒〜1分） |
| **Maintenance** | 高（手動パッチ） | 中（AMI管理） | 中（イメージ管理） | 低（クラウド任せ） |
| **Ease of Learning** | 易（SSH基礎） | 易〜中（クラウド基礎） | 難（Kubernetes） | 中（FaaS制約理解） |
| **Dev/Prod Parity** | 低（環境差異） | 中（AMI統一） | 高（イメージ統一） | 高（関数統一） |
| **Maturity** | 高（枯れた技術） | 高（標準技術） | 中〜高（急成長） | 中（制約あり） |
| **Debugging** | 易（SSH可） | 易（SSH可） | 中（kubectl exec） | 難（SSH不可） |
| **Long-running Tasks** | ✅ | ✅ | ✅ | ❌（15分制限） |
| **Performance Tuning** | ✅（直接制御） | ✅（インスタンスタイプ選択） | △（リソースリクエスト） | ❌（抽象化） |

---

## IaCツールとオーケストレーションの組み合わせ

### 推奨パターン

| オーケストレーション | IaCツール組み合わせ | 説明 |
|---------------------|-------------------|------|
| Server Orchestration | Provisioning + Configuration Management | OpenTofu（サーバープロビジョニング）+ Ansible（アプリデプロイ） |
| VM Orchestration | Provisioning + Server Templating | OpenTofu（ASG/ALBプロビジョニング）+ Packer（AMI作成） |
| Container Orchestration | Provisioning + Server Templating + Orchestration | OpenTofu（EKSプロビジョニング）+ Packer（Node AMI）+ Docker（イメージ）+ Kubernetes（デプロイ） |
| Serverless Orchestration | Provisioning | OpenTofu（Lambda/API Gateway等プロビジョニング） |

---

## オーケストレーション選定フローチャート

```
要件は何か？
│
├─ 学習・小規模プロジェクト（サーバー数台）
│  └→ Server Orchestration
│
├─ 中規模・クラウドネイティブ・標準Webアプリ
│  └→ VM Orchestration
│
├─ 大規模・マイクロサービス・高頻度デプロイ
│  ├─ 学習・運用コスト許容可能？
│  │  ├─ Yes → Container Orchestration
│  │  └─ No  → VM Orchestration（まず習熟してから移行）
│  └→
│
└─ イベント駆動・短時間実行・トラフィック変動大
   ├─ コールドスタート許容可能？
   │  ├─ Yes → Serverless FaaS
   │  └─ No  → Serverless Containers
   └→
```

---

## ユーザー確認が必要な判断ポイント

### Kubernetes採用判断時
- **学習コスト**: チームがKubernetesを学ぶ時間があるか？
- **運用コスト**: マネージドKubernetes（EKS等）の費用を許容できるか？
- **必要性**: 本当に高度なデプロイ戦略・スケーラビリティが必要か？

### Serverless採用判断時
- **制約許容**: サイズ制限・時間制限・コールドスタートを許容できるか？
- **コスト**: 常時トラフィックがある場合、Serverlessは割高になる可能性
- **長時間接続**: DB接続プール・WebSocketが必要か？

### VM vs Container
- **起動速度**: VMの数分起動は許容可能か？
- **複雑性**: Kubernetesの複雑性を受け入れられるか？
- **既存インフラ**: VMベースのインフラが既にある場合、移行コストは？

---

## まとめ

### Key Takeaways

1. **Server Orchestration**: 学習コスト低、小規模向け、手動管理多い
2. **VM Orchestration**: クラウド標準、中規模向け、マネージドサービス
3. **Container Orchestration**: 高速・高機能、大規模向け、学習曲線急
4. **Serverless Orchestration**: サーバー管理不要、イベント駆動向け、制約あり

### 推奨アプローチ

**段階的採用**:
1. 小規模: Server Orchestration（Ansible）
2. 中規模: VM Orchestration（ASG + ALB）
3. 大規模: Container Orchestration（Kubernetes）
4. 特定ユースケース: Serverless Orchestration（Lambda）

**マネージドサービス優先**:
- VM Orchestration: AWS ASG/ALB
- Container Orchestration: EKS、GKE、AKS
- Serverless: AWS Lambda、Cloud Functions

---

## 関連ドキュメント

- `IAC-TOOLS.md` - IaCツール詳細比較
- `../SKILL.md` - DevOps実践ガイド（親スキル）
