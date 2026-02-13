# IaCツール詳細比較

## 概要

Infrastructure as Code（IaC）ツールは4つのカテゴリに分類され、それぞれ特定の用途に最適化されています。このドキュメントでは、各カテゴリの特徴・メリット・デメリット・ユースケースを詳細に解説します。

---

## IaC 4カテゴリ

### 1. Ad hoc scripts（アドホックスクリプト）

**定義**: Bash、Python、Rubyなどの汎用スクリプト言語で記述した、インフラ管理用スクリプト。

**例**:
- Bashスクリプトでサーバー起動
- Pythonスクリプトでデプロイ自動化

#### 特徴

| 項目 | 評価 | 説明 |
|------|------|------|
| CRUD | C（Create）のみ | 作成のみサポート。読み取り・更新・削除は自前実装が必要 |
| スケール | ❌ | 大規模インフラ管理には不向き |
| 冪等性 | ❌ | 再実行で異なる結果になることが多い |
| エラー処理 | ❌ | 部分的完了状態での復旧が困難 |
| 一貫性 | ❌ | 各開発者が独自のスタイルで記述 |
| 簡潔性 | ❌ | CRUD・冪等性・エラー処理を含めると数百〜数千行 |

#### メリット
- ✅ 学習コストが低い
- ✅ 既存の言語知識を活用可能
- ✅ 柔軟性が高い（何でもできる）

#### デメリット
- ❌ CRUD操作が不完全（Createのみ）
- ❌ 冪等性なし（同じスクリプトを再実行すると失敗することが多い）
- ❌ スケールしない（大規模インフラには不向き）
- ❌ 一貫性なし（スパゲッティコード化しやすい）
- ❌ 冗長（適切なエラー処理・冪等性を含めると膨大なコード量）

#### ユースケース
- 小規模・一時的タスク（1回限りのセットアップ等）
- プロトタイピング・実験
- 他のIaCツールの補完（グルー・ダクトテープ的役割）

#### 推奨アプローチ
**アドホックスクリプトは主要なIaC管理ツールとして使用しない。**
専用IaCツールと組み合わせて、補完的に使用するのが適切。

---

### 2. Configuration Management（設定管理ツール）

**定義**: サーバー上のソフトウェア・設定を管理する専用ツール。

**例**:
- Ansible
- Chef
- Puppet
- SaltStack

#### 特徴

| 項目 | 評価 | 説明 |
|------|------|------|
| CRUD | CRU（Create/Read/Update） | サーバー設定のCRUをサポート。Deleteは限定的 |
| スケール | ✅ | 複数サーバー管理に最適化 |
| 冪等性 | △ | タスクによる（yum等は冪等、shell実行は非冪等） |
| エラー処理 | △ | ツールによるが、一般的にアドホックより優れる |
| 一貫性 | ✅ | 標準化されたディレクトリ構造・ベストプラクティス |
| 簡潔性 | ✅ | DSL（Domain Specific Language）により簡潔 |

#### アーキテクチャパターン

**1. Master-Agent型（Chef、Puppet）**:
- Masterサーバーが設定を管理
- 各サーバーにAgentをインストール
- Reconciliation Loop（調整ループ）で常に望ましい状態を維持

**メリット**:
- 設定のドリフト（drift）を自動検出・修正
- 集中管理

**デメリット**:
- Masterサーバーの運用コスト
- Agent のインストール・更新・保守が必要

**2. Agentless型（Ansible）**:
- Masterサーバー不要
- SSH経由でサーバーに接続
- CLIツールをどこからでも実行可能

**メリット**:
- Masterサーバー不要
- Agent不要

**デメリット**:
- SSH設定が必要（鶏と卵問題）
- Reconciliation Loopなし（手動実行）

#### メリット
- ✅ サーバー設定管理に特化した機能
- ✅ 複数サーバー管理が容易
- ✅ ローリングデプロイ等の高度なデプロイ戦略サポート
- ✅ 標準化されたコード構造
- ✅ 再利用可能なモジュール（Ansible Roles等）

#### デメリット
- ❌ サーバー自体のプロビジョニングには不向き
- ❌ Mutableインフラ（長期運用でConfiguration Drift発生）
- ❌ セットアップコスト（Master/Agent or SSH設定）
- ❌ Deleteサポートが限定的

#### ユースケース
- サーバー設定管理（OS設定、依存関係インストール、アプリデプロイ）
- 既存サーバーへのソフトウェア展開
- Mutableインフラアプローチ

#### 推奨アプローチ
**サーバー設定管理には最適だが、サーバー自体のデプロイには別ツール（Provisioningツール）を使用する。**

---

### 3. Server Templating（サーバーテンプレートツール）

**定義**: サーバーのイメージ（スナップショット）を作成し、そのイメージから複数のサーバーをデプロイするツール。

**例**:
- **VM Image**: Packer、Vagrant
- **Container Image**: Docker

#### VM vs Container

| 項目 | VM（Virtual Machine） | Container |
|------|----------------------|-----------|
| 仮想化レベル | ハードウェア全体（CPU、メモリ、HDD、ネットワーク） | ユーザースペースのみ |
| OS | 各VM独自のOS | ホストOSを共有 |
| 起動時間 | 数分 | 数ミリ秒〜数秒 |
| オーバーヘッド | 高（CPU・メモリ） | 低（ほぼゼロ） |
| 隔離性 | 完全隔離 | カーネル・ハードウェア共有（隔離はより困難） |
| ユースケース | 完全隔離が必要（マルチテナント等） | 高速起動・低オーバーヘッド重視 |

#### 特徴

| 項目 | 評価 | 説明 |
|------|------|------|
| CRUD | C（Create）のみ | イメージ作成のみ。デプロイは別ツール（Provisioningツール）が担当 |
| スケール | ✅ | 同じイメージを1台〜1000台にデプロイ可能 |
| 冪等性 | ✅ | 常に同じイメージを作成（設計上冪等） |
| エラー処理 | ✅ | 失敗時は再実行するだけ |
| 一貫性 | ✅ | 標準化されたテンプレート構造 |
| 簡潔性 | ✅ | DSLにより簡潔 |

#### Immutableインフラの利点

**Mutableインフラ（Configuration Management）**:
- 長期運用サーバーに変更を繰り返し適用
- Configuration Drift発生（各サーバーの履歴が微妙に異なる）
- デバッグが困難

**Immutableインフラ（Server Templating）**:
- 更新時は新しいイメージから新サーバーを起動
- 古いサーバーは廃棄
- すべてのサーバーが同一状態（Cattle, not Pets）
- 推論・デバッグが容易

#### メリット
- ✅ Immutableインフラ実践
- ✅ 高速デプロイ（特にContainer）
- ✅ 冪等性が設計上保証される
- ✅ スケーラビリティ
- ✅ Dev/Prod環境の完全一致

#### デメリット
- ❌ イメージデプロイは別ツール（Provisioningツール）が必要
- ❌ VMは起動が遅い（数分）
- ❌ Containerは完全隔離が困難

#### ユースケース
- Immutableインフラ実践
- マイクロサービスアーキテクチャ（Container）
- 高速デプロイ・ロールバック
- Dev/Prod環境の完全一致

#### 推奨アプローチ
**Server TemplatingとProvisioningツールを組み合わせる。**
- Packerでイメージ作成 → OpenTofu/Terraformでデプロイ
- DockerでContainer作成 → Kubernetesでデプロイ

---

### 4. Provisioning（プロビジョニングツール）

**定義**: サーバー・データベース・ロードバランサー・ネットワーク等、インフラ全体をプロビジョニング・管理するツール。

**例**:
- OpenTofu / Terraform
- AWS CloudFormation
- Azure Resource Manager
- Pulumi

#### 特徴

| 項目 | 評価 | 説明 |
|------|------|------|
| CRUD | CRUD（全対応） | 作成・読み取り・更新・削除すべてサポート |
| スケール | ✅ | 数千のリソースを管理可能 |
| 冪等性 | ✅ | 宣言的DSLにより設計上冪等 |
| エラー処理 | ✅ | 状態管理により自動復旧 |
| 一貫性 | ✅ | 標準化されたモジュール構造 |
| 簡潔性 | ✅ | 宣言的DSLにより簡潔 |

#### 宣言的 vs 手続き型

**手続き型（Ad hoc scripts）**:
- ステップバイステップで「どうやって」を指定
- 例: サーバー1を起動 → サーバー2を起動 → ロードバランサーを作成

**宣言的（Provisioning tools）**:
- 「何を」望むかを指定
- ツールが現在の状態から望ましい状態への移行を自動計算
- 例: サーバー3台 + ロードバランサー → ツールが差分を検出・実行

#### 状態管理

Provisioningツールは**状態ファイル**を管理し、現在のインフラ状態を記録：
- 初回実行: リソース作成 → 状態ファイルに記録
- 2回目以降: 状態ファイルと現実を比較 → 差分のみ実行
- 冪等性・CRUD操作が自動的に機能

#### メリット
- ✅ 完全なCRUDサポート
- ✅ 宣言的アプローチで冪等性・エラー処理が自動
- ✅ 数千のリソースを管理可能
- ✅ 再利用可能なモジュール
- ✅ サーバーだけでなく、ネットワーク・データベース・監視等すべてをコード管理

#### デメリット
- ❌ サーバー内部の設定管理には不向き（Configuration Managementツールと組み合わせる）
- ❌ クラウドプロバイダー固有のAPI依存（マルチクラウドは注意）

#### ユースケース
- インフラ全体のプロビジョニング・管理
- マルチクラウド・ハイブリッドクラウド
- Immutableインフラとの組み合わせ
- セルフサービスインフラ（開発者がモジュールを使ってインフラをデプロイ）

#### 推奨アプローチ
**Provisioningツールをインフラ管理の中心に据える。**
他のIaCツールと組み合わせて、包括的なインフラ管理を実現。

---

## IaCツール組み合わせパターン

実際のプロジェクトでは、複数のIaCツールを組み合わせます。

### パターン1: Provisioning + Configuration Management

**組み合わせ**: OpenTofu + Ansible

**役割分担**:
- OpenTofu: ネットワーク（VPC、サブネット）、データストア（MySQL、Redis）、ロードバランサー、サーバーをプロビジョニング
- Ansible: サーバー上にアプリをデプロイ・設定

**メリット**:
- 導入が容易
- OpenTofuのタグをAnsibleのInventory Pluginで自動検出可能

**デメリット**:
- Mutableインフラ（Configuration Drift）
- 大規模化すると保守が困難

**推奨ユースケース**: 小〜中規模プロジェクト、Immutableインフラへの移行前

---

### パターン2: Provisioning + Server Templating

**組み合わせ**: OpenTofu + Packer

**役割分担**:
- Packer: VMイメージ（AMI等）を作成
- OpenTofu: VMイメージを使ってサーバーをデプロイ、ネットワーク・データストア・ロードバランサーもプロビジョニング

**メリット**:
- Immutableインフラ
- 保守が容易

**デメリット**:
- VMは起動が遅い（デプロイに数分）
- デプロイ戦略の実装が限定的（OpenTofuネイティブではBlue-Green等が困難）

**推奨ユースケース**: 中規模プロジェクト、Immutableインフラ重視、VM起動時間が許容可能

---

### パターン3: Provisioning + Server Templating + Orchestration

**組み合わせ**: OpenTofu + Packer + Docker + Kubernetes

**役割分担**:
- Packer: Docker・Kubernetes Agentがインストール済みのVMイメージ作成
- OpenTofu: VMイメージを使ってKubernetesクラスター（サーバー群）をデプロイ、ネットワーク・データストア・ロードバランサーもプロビジョニング
- Kubernetes: クラスター内でDockerコンテナを管理（デプロイ・スケーリング・ヒーリング）

**メリット**:
- Dockerイメージは高速ビルド・高速デプロイ
- Kubernetesの高度な機能（Auto Scaling、Auto Healing、Rolling Deployment、Blue-Green、Canary等）
- Immutableインフラ

**デメリット**:
- 複雑性が高い（Kubernetes運用コスト）
- 学習曲線が急
- マネージドKubernetes（EKS、GKE等）でコストを削減可能

**推奨ユースケース**: 大規模プロジェクト、高度なデプロイ戦略が必要、学習・運用コストが許容可能

---

## IaCカテゴリ選定フローチャート

```
タスクは何か？
│
├─ 小規模・一時的タスク
│  └→ Ad hoc scripts
│
├─ サーバー設定管理
│  ├─ Immutableインフラ？
│  │  ├─ Yes → Server Templating + Provisioning
│  │  └─ No  → Configuration Management + Provisioning
│  └→
│
├─ サーバー・インフラプロビジョニング
│  └→ Provisioning
│
└─ 複雑なアプリケーションデプロイ
   └→ Provisioning + Server Templating + Orchestration
```

---

## ツール別比較表

### 宣言的 vs 手続き型

| ツール | アプローチ | 特徴 |
|--------|-----------|------|
| Bash、Python | 手続き型 | ステップバイステップで指示 |
| Ansible | 手続き型 + 宣言的要素 | Playbookは手続き的だがTaskは宣言的 |
| OpenTofu、CloudFormation | 宣言的 | 望ましい状態を記述 |

### Mutable vs Immutable

| ツール | インフラタイプ | 特徴 |
|--------|--------------|------|
| Ansible、Chef、Puppet | Mutable | 長期運用サーバーを更新 |
| Packer、Docker | Immutable | イメージ作成 → 新サーバーデプロイ |
| OpenTofu | どちらも可能 | Configuration Management併用でMutable、Server Templating併用でImmutable |

### Master/Agent vs Agentless

| ツール | アーキテクチャ | 特徴 |
|--------|--------------|------|
| Chef、Puppet | Master + Agent | Reconciliation Loop、集中管理 |
| Ansible | Agentless（SSH） | Master不要、Agent不要 |
| OpenTofu、CloudFormation | API駆動 | Master/Agent不要、クラウドAPIを直接呼び出し |

---

## まとめ

### Key Takeaways

1. **Ad hoc scripts**: 小規模・一時的タスクに最適。インフラ全体の管理には不向き
2. **Configuration Management**: サーバー設定管理に最適。サーバー自体のデプロイには不向き
3. **Server Templating**: Immutableインフラ実践に最適
4. **Provisioning**: サーバー・インフラのデプロイ・管理に最適
5. **組み合わせ**: 実際のプロジェクトでは複数カテゴリを組み合わせる

### 推奨アプローチ

**基本戦略**: Provisioningツールを中心に、必要に応じて他カテゴリを組み合わせる。

- 小〜中規模: Provisioning + Configuration Management
- 中〜大規模（Immutable重視）: Provisioning + Server Templating
- 大規模（高度な機能）: Provisioning + Server Templating + Orchestration

---

## 関連ドキュメント

- `ORCHESTRATION.md` - オーケストレーション詳細比較
- `../SKILL.md` - DevOps実践ガイド（親スキル）
