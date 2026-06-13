# コンテナライフサイクル管理・イメージ・Pods

## 目次

1. [コンテナライフサイクルコマンド](#1-コンテナライフサイクルコマンド)
2. [コンテナ実行オプション](#2-コンテナ実行オプション)
3. [コンテナへのアクセス・デバッグ](#3-コンテナへのアクセスデバッグ)
4. [イメージ管理](#4-イメージ管理)
5. [Pods（Kubernetes対応）](#5-podskubernetes対応)
6. [クリーンアップ](#6-クリーンアップ)

---

## 1. コンテナライフサイクルコマンド

### コンテナ状態遷移

```
Created → Running → Paused → Running → Stopped → Removed
```

### 基本コマンド

```bash
# コンテナの実行（フォアグラウンド）
$ podman run --name myapp nginx

# バックグラウンド実行
$ podman run -d --name myapp nginx

# コンテナ一覧（実行中のみ）
$ podman ps

# すべてのコンテナ一覧
$ podman ps -a

# コンテナの開始・停止・再起動
$ podman start <name|id>
$ podman stop <name|id>
$ podman restart <name|id>

# コンテナの一時停止（cgroup freeze）
$ podman pause <name|id>
$ podman unpause <name|id>

# コンテナ削除（停止済み）
$ podman rm <name|id>

# 実行中コンテナを強制削除
$ podman rm -f <name|id>
```

### コンテナ情報確認

```bash
# コンテナの詳細情報（JSON）
$ podman inspect <name|id>

# コンテナのリソース使用状況
$ podman stats <name|id>

# プロセス一覧
$ podman top <name|id>

# ポートマッピング確認
$ podman port <name|id>
```

---

## 2. コンテナ実行オプション

### よく使うrunオプション

| オプション | 説明 | 例 |
|-----------|------|-----|
| `-d` | バックグラウンド実行 | `podman run -d nginx` |
| `-it` | インタラクティブ + TTY | `podman run -it fedora bash` |
| `--rm` | 終了時自動削除 | `podman run --rm alpine echo "hi"` |
| `--name` | コンテナ名指定 | `podman run --name web nginx` |
| `-p <host>:<container>` | ポートマッピング | `podman run -p 8080:80 nginx` |
| `-v <host>:<container>` | ボリューム/バインドマウント | `podman run -v /data:/app/data nginx` |
| `-e KEY=VAL` | 環境変数設定 | `podman run -e APP_ENV=prod nginx` |
| `--user <uid>` | 実行ユーザー指定 | `podman run --user 1001 nginx` |
| `--network` | ネットワーク指定 | `podman run --network mynet nginx` |
| `--cap-add` | Linux Capability追加 | `podman run --cap-add NET_ADMIN` |
| `--security-opt` | セキュリティオプション | `podman run --security-opt label=disable` |
| `--read-only` | ルートfsを読み取り専用 | `podman run --read-only nginx` |

### リソース制限

```bash
# メモリ制限
$ podman run --memory 512m nginx

# CPU制限（コア数）
$ podman run --cpus 1.5 nginx

# CPU共有（cgroups weight）
$ podman run --cpu-shares 512 nginx
```

### ネットワークモード

```bash
# デフォルト（bridge）
$ podman run nginx

# ホストネットワーク（ポートマッピング不要）
$ podman run --network host nginx

# ネットワークなし
$ podman run --network none nginx

# Podのネットワーク共有
$ podman run --pod mypod nginx
```

---

## 3. コンテナへのアクセス・デバッグ

### execコマンド

実行中コンテナに新しいプロセスを起動する。コンテナの主プロセス（PID 1）とは独立して動作する。

```bash
# インタラクティブシェル
$ podman exec -ti <id> /bin/bash

# 単一コマンド実行
$ podman exec <id> ls /app

# 特定ユーザーで実行
$ podman exec -u root <id> cat /etc/shadow

# 環境変数指定
$ podman exec -e DEBUG=true <id> /app/debug-tool
```

### ログ確認

```bash
# ログ表示（全量）
$ podman logs <name|id>

# リアルタイム追跡（tail -f相当）
$ podman logs -f <name|id>

# 直近の行数を指定
$ podman logs --tail 100 <name|id>

# タイムスタンプ付き
$ podman logs -t <name|id>
```

### ファイルコピー

```bash
# コンテナ → ホスト
$ podman cp <container>:/path/to/file /host/path

# ホスト → コンテナ
$ podman cp /host/path <container>:/path/to/file
```

### デバッグ用の一時コンテナ起動

```bash
# 同じイメージでシェルを起動（本番コンテナに影響しない）
$ podman run -it --rm nginx bash

# 実行中コンテナと同じnamespaceで起動
$ podman run -it --pid container:<id> --network container:<id> alpine sh
```

---

## 4. イメージ管理

### イメージ取得と確認

```bash
# イメージのpull
$ podman pull docker.io/library/nginx:latest

# ローカルイメージ一覧
$ podman images

# イメージの詳細情報
$ podman inspect <image>

# イメージのレイヤー確認
$ podman image tree <image>

# 履歴確認
$ podman history <image>
```

### イメージ操作

```bash
# タグ付け
$ podman tag localhost/myapp quay.io/<user>/myapp:v1.0

# レジストリへのpush
$ podman push quay.io/<user>/myapp:v1.0

# イメージ削除
$ podman rmi <image>

# 未使用イメージの一括削除
$ podman image prune

# 全イメージ削除（dangling含む）
$ podman image prune -a
```

### イメージ検索

```bash
# Dockerhubで検索
$ podman search nginx

# フィルタ付き検索
$ podman search --filter=is-official nginx

# 詳細情報付き
$ podman search --format "{{.Name}}\t{{.Description}}" nginx
```

### コンテナからイメージを作成

```bash
# 実行中コンテナの変更を新イメージとして保存
# -p: コミット前に一時停止（一貫性確保）
$ podman commit -p <container> <image-name>

# メッセージ付きでコミット
$ podman commit -m "added custom config" <container> myimage:v2
```

---

## 5. Pods（Kubernetes対応）

### Podの概念

PodはKubernetesのコンセプトをPodmanがネイティブサポートしたもの。Pod内のコンテナは以下のnamespaceを共有する:

- **network namespace**: 同一IPアドレス、同一ポート空間
- **IPC namespace**: POSIX共有メモリ・Semaphoreを共有

各Podには**infra container**（pause imageとも呼ばれる）が存在し、PodのnamespaceライフサイクルをPod内コンテナの実行状態から独立して管理する。

### Podコマンド

```bash
# Pod作成
$ podman pod create --name myhttp

# Podの一覧
$ podman pod ls

# Podにコンテナを追加して実行
$ podman run -d --pod myhttp nginx
$ podman run -d --pod myhttp php-fpm

# Pod内コンテナ一覧（Pod名付き）
$ podman ps -p

# Pod全体の操作
$ podman pod start myhttp
$ podman pod stop myhttp
$ podman pod restart myhttp
$ podman pod rm myhttp

# Pod詳細情報
$ podman pod inspect myhttp

# Pod内のリソース使用量
$ podman pod stats myhttp
```

### ポートマッピングはPodレベルで設定

```bash
# Pod作成時にポートマッピングを設定（コンテナ側では設定不可）
$ podman pod create --name webpod -p 8080:80

# Pod作成と同時にコンテナを追加
$ podman run -d --pod new:webpod -p 8080:80 nginx
```

### KubernetesのYAML生成

```bash
# PodのKubernetes YAML生成
$ podman generate kube mypod > pod.yaml

# YAMLからPodを作成
$ podman play kube pod.yaml
```

---

## 6. クリーンアップ

### コンテナの一括削除

```bash
# 停止済みコンテナを全削除
$ podman rm --all

# 実行中も含めて全強制削除
$ podman rm --all --force

# システム全体のリセット（コンテナ・イメージ・ネットワーク・ボリュームを削除）
$ podman system reset
```

### ディスク使用量確認

```bash
# ストレージ使用量の概要
$ podman system df

# 詳細内訳
$ podman system df -v
```

### 不要リソースの一括削除

```bash
# 停止済みコンテナ・未使用イメージ・未使用ネットワーク・キャッシュを削除
$ podman system prune

# ボリュームも含めて削除
$ podman system prune --volumes
```

---

## 関連参照

| トピック | 参照先 |
|---------|--------|
| アーキテクチャ理解 | [ARCHITECTURE.md](ARCHITECTURE.md) |
| ストレージ（volumes/bind mounts） | [STORAGE.md](STORAGE.md) |
| Buildahによるイメージビルド | [BUILDAH.md](BUILDAH.md) |
| インストール手順 | [INSTALLATION.md](INSTALLATION.md) |
