---
name: managing-docker
description: Docker Engine architecture and internals. Reference for containerd, runc, and shim components.
---

# Docker Engine 内部構造

Docker Engineはコンテナを実行・管理するサーバーサイドコンポーネント群です。モジュラー設計で、OCI、CNCF、Mobyプロジェクトから提供される小さな専門特化ツールで構成されています。

## アーキテクチャ概要

Docker Engineは以下の主要コンポーネントで構成されています：

| コンポーネント | 役割 | 特徴 |
|-------------|------|------|
| **Docker daemon** | APIサーバー | REST API提供、リクエスト処理 |
| **containerd** | 高レベルランタイム | ライフサイクル管理（開始、停止、削除） |
| **runc** | 低レベルランタイム | カーネルインターフェース、コンテナ実行 |
| **shim** | プロセス管理 | runcとcontainerdの間で動作 |

### コンポーネント間の関係

```
Docker CLI → Docker daemon → containerd → runc → Linux kernel
                                    ↓
                                   shim (各コンテナごと)
```

## Docker daemon

### 歴史的変遷

#### 初期アーキテクチャ（2014年以前）
- モノリシック構造
- LXCに依存
- すべての機能がdaemonに統合

#### モノリシックからの脱却
モノリシック設計の問題点：
1. **パフォーマンス低下** - 機能追加で肥大化
2. **エコシステムとの不一致** - 独自仕様の弊害
3. **イノベーション阻害** - 変更の影響範囲が広い

#### 現在のアーキテクチャ
- 機能ごとに独立ツール化
- containerdとruncへの分離
- イメージ管理もcontainerdに移管（Docker Desktop 4.27.0以降）

### 現在の責務

Docker daemonの主な役割：
- Docker API提供
- CLIからのリクエスト受信
- containerdへのタスク委譲

**注意**: コンテナ作成・実行ロジックはdaemonから分離済み。

### API通信

| 環境 | ソケット場所 |
|-----|-------------|
| Linux | `/var/run/docker.sock` |
| Windows | `\pipe\docker_engine` |

通信プロトコル：
- CLI → daemon: REST API
- daemon → containerd: gRPC (CRUD操作)

## containerd

### 概要

- **発音**: "container dee"
- **表記**: 小文字 "c" 必須
- **分類**: 高レベルランタイム
- **プロジェクト**: CNCF graduated project

### 主な機能

| 機能 | 詳細 |
|-----|------|
| ライフサイクル管理 | コンテナの開始・停止・削除 |
| イメージ管理 | pull/push操作（モジュラー設計） |
| ネットワーク管理 | ネットワーク設定 |
| ボリューム管理 | ストレージマウント |

### 設計思想

- 元々は最小機能のみを提供
- Kubernetesなどの要求で機能追加
- モジュラー設計でプロジェクトごとに必要な機能のみ利用可能

### 他プロジェクトでの利用

- Docker
- Kubernetes
- Firecracker
- AWS Fargate

### リリース情報

最新リリース: https://github.com/containerd/containerd/releases

## runc

### 概要

- **発音**: "run see"
- **表記**: 小文字 "r" 必須
- **役割**: OCI runtime-specの参照実装
- **分類**: 低レベルランタイム

### 特徴

| 特徴 | 説明 |
|-----|------|
| **軽量CLI** | libcontainerのラッパー |
| **OCI準拠** | OCI-compliantコンテナ作成 |
| **カーネル連携** | namespaces/cgroupsの構築 |
| **独立実行可能** | スタンドアロンツールとして利用可 |

### 動作フロー

1. OCI bundleを受け取る
2. カーネルとインターフェース
3. namespaces/cgroupsを構築
4. コンテナを子プロセスとして起動
5. **コンテナ起動後にruncは終了**

### 他ツールとの組み合わせ

- containerdがデフォルト
- Kubernetesもデフォルトで利用
- shimを介して他の低レベルランタイムと交換可能

### リリース情報

最新リリース: https://github.com/opencontainers/runc/releases

## shim

### 目的

shimはcontainerdとOCIレイヤーの間に位置し、以下の利点を提供：

1. **Daemonlessコンテナ**
2. **効率向上**
3. **プラガブルOCIレイヤー**

### Daemonlessコンテナの仕組み

- Docker daemonを停止・再起動してもコンテナは影響を受けない
- shimがコンテナの親プロセスとして継続動作

### 効率化メカニズム

```
containerd → shim1 + runc1 → コンテナ1 (runc1終了後もshim1が存続)
          → shim2 + runc2 → コンテナ2 (runc2終了後もshim2が存続)
```

**プロセスフロー**:
1. containerdがshimとruncをfork
2. runcがコンテナを起動
3. **runcが終了**（軽量化）
4. shimが親プロセスとして残る

### shimの責務

- コンテナステータス報告
- STDIN/STDOUT streamの維持
- 低レベルタスク処理

### プラガビリティ

shimを介してruncを他の低レベルランタイムに置換可能。
- 例: WebAssembly runtimeへの切り替え

## OCI標準

### OCI仕様の影響

Docker Engine開発とOCI仕様策定は並行して進行し、相互に影響を与えました。

### OCI仕様一覧

| 仕様 | バージョン | 説明 | リリース |
|-----|-----------|------|---------|
| **Runtime Specification** | 1.2.0 | コンテナランタイム標準 | 2017年7月 (v1.0) |
| **Image Specification** | 1.1.0 | イメージフォーマット標準 | 2017年7月 (v1.0) |
| **Distribution Specification** | 1.1.0 | レジストリ配布標準 | - |

### Dockerの対応状況

| コンポーネント | OCI準拠状況 |
|--------------|-----------|
| runc | runtime-spec準拠 |
| BuildKit | image-spec準拠 |
| Docker Hub | distribution-spec準拠 |

**注意**: Dockerは2016年以降すべてのバージョンでOCI仕様を実装しています。

## コンテナ起動フロー

### `docker run` コマンドの内部動作

```bash
$ docker run -d --name ctr1 nginx
```

**ステップ1: CLIからAPIへ**
- Docker CLIがコマンドをAPIリクエストに変換
- daemonのAPIエンドポイントに送信

**ステップ2: daemonの処理**
- リクエストを解釈
- イメージの有無を確認
- containerdにコンテナ作成を依頼

**ステップ3: containerdの処理**
- Docker imageをOCI bundleに変換
- runcに作成を指示

**ステップ4: runcの実行**
- カーネルとインターフェース
- namespaces/cgroupsを構築
- コンテナを起動
- **runc自身は終了**

**ステップ5: shimの継続動作**
- コンテナの親プロセスとして動作継続
- daemonとコンテナの分離が完了

### コンテナ作成フロー図解

```
Docker CLI
    ↓ (APIリクエスト)
Docker daemon
    ↓ (gRPC)
containerd
    ↓ (OCI bundle)
runc → カーネル (namespaces/cgroups作成)
    ↓
コンテナ起動 → runc終了
    ↓
shim継続動作
```

## Linux実装

### バイナリ構成

Dockerは以下の独立バイナリで実装されています：

| バイナリ | パス | 役割 |
|---------|------|------|
| dockerd | `/usr/bin/dockerd` | Docker daemon |
| containerd | `/usr/bin/containerd` | 高レベルランタイム |
| shim | `/usr/bin/containerd-shim-runc-v2` | プロセス管理 |
| runc | `/usr/bin/runc` | 低レベルランタイム |

### プロセス確認方法

```bash
# 実行中のプロセス確認
ps aux | grep docker
ps aux | grep containerd
ps aux | grep runc
```

**注意**:
- コンテナ実行時のみshim/runcプロセスが表示される
- Docker Desktop (Mac/Windows) ではVM内で動作するため直接確認不可

## daemonの現在の役割

### 必要性の再検討

ほとんどの機能が分離された現在でも、daemonは以下の理由で必要：
- Docker APIの提供
- CLIからのリクエスト処理
- 各コンポーネントの調整

### 将来の展望

Docker社はdaemonのさらなる機能分離を継続的に検討しています。

## チェックリスト: Engine理解度確認

- [ ] Docker Engineの4大コンポーネントを説明できる
- [ ] containerdとruncの役割の違いを理解している
- [ ] shimの3つの利点を説明できる
- [ ] `docker run`コマンドの内部フローを説明できる
- [ ] OCI仕様の3つの標準を挙げられる
- [ ] Daemonlessコンテナの仕組みを理解している
- [ ] runcがコンテナ起動後に終了する理由を説明できる

## トラブルシューティング

### daemon未起動

**症状**: `docker version`でServer情報が表示されない

**確認方法**:
```bash
# Systemd環境
systemctl is-active docker

# 非Systemd環境
service docker status
```

**起動方法**:
```bash
# Systemd環境
systemctl start docker

# 非Systemd環境
service docker start
```

### 権限エラー

**症状**: ソケットへのアクセス拒否

**解決策**:
```bash
# dockerグループにユーザー追加
sudo usermod -aG docker <username>

# シェル再起動
exit
```

または各コマンドに`sudo`を付与。

## ベストプラクティス

1. **モジュラー設計の活用**
   - 必要なコンポーネントのみ利用
   - 他プロジェクトでのcontainerd/runc再利用

2. **バージョン管理**
   - OCI仕様準拠バージョンの確認
   - 各コンポーネントの互換性確認

3. **パフォーマンス最適化**
   - shimによるruncプロセスの効率化
   - daemonレス設計の活用

4. **セキュリティ**
   - 最新バージョンへの更新
   - CVE情報の定期確認

## まとめ

Docker Engineは以下の特徴を持つモジュラーシステム：
- **Docker daemon**: API提供
- **containerd**: ライフサイクル管理（高レベル）
- **runc**: コンテナ実行（低レベル）
- **shim**: 効率化とdaemonレス実現

この設計により、Docker daemonを停止・再起動してもコンテナは影響を受けません。また、containerdとruncは他プロジェクト（Kubernetes、Firecracker等）でも広く利用されています。
