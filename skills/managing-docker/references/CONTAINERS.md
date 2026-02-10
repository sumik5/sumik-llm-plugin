---
name: managing-docker
description: Container lifecycle management including starting, stopping, restart policies, exec sessions, logging, and debugging.
---

# Docker コンテナ管理

コンテナはイメージのランタイムインスタンスです。1つのイメージから複数のコンテナを起動できます。

## コンテナの基本概念

### コンテナ vs VM

| 特性 | コンテナ | VM |
|-----|---------|-----|
| **仮想化対象** | OS | ハードウェア |
| **サイズ** | MB単位 | GB単位 |
| **起動速度** | 秒以下 | 分単位 |
| **リソース効率** | 高（OSを共有） | 低（各VMがOS保持） |
| **ポータビリティ** | 非常に高い | 中程度 |
| **セキュリティ** | 適切な設定で高い | カーネル分離で高い |

### コンテナの設計思想

| 原則 | 説明 |
|-----|------|
| **Stateless** | 状態を持たない |
| **Ephemeral** | 一時的・使い捨て |
| **Immutable** | 変更不可（修正時は新しいコンテナに置換） |
| **Single process** | 1コンテナ = 1プロセス |

### マイクロサービスアーキテクチャ

アプリケーション例（4機能）:
```
Web server container
Auth service container
Catalog container
Store container
```

各機能を独立したコンテナで実行。

## イメージとコンテナの関係

### 読み取り専用 vs 読み書き可能

```
Container 1 (R/W layer)  ←─ 書き込み可能
Container 2 (R/W layer)  ←─ 書き込み可能
Container 3 (R/W layer)  ←─ 書き込み可能
        ↓
Shared Image (Read-only) ←─ 共有・読み取り専用
```

**仕組み**:
- イメージは読み取り専用
- 各コンテナに薄いR/Wレイヤーを追加
- 変更はコンテナ固有のR/Wレイヤーに記録
- コンテナ停止時もR/Wレイヤーは保持
- コンテナ削除時にR/Wレイヤーも削除

## コンテナの起動

### docker runコマンド

#### 基本形式

```bash
docker run [arguments] <image> [command]
```

#### 実行例

```bash
# バックグラウンドで起動
docker run -d --name webserver -p 5005:8080 myuser/web-app:v0.1

# インタラクティブモード
docker run -it --name mycontainer ubuntu bash

# 自動削除付き
docker run --rm -d alpine sleep 60
```

### 主要フラグ

| フラグ | 説明 | 例 |
|-------|------|-----|
| **-d** | デタッチモード（バックグラウンド実行） | `-d` |
| **-it** | インタラクティブ + TTY割り当て | `-it` |
| **--name** | コンテナ名指定 | `--name webserver` |
| **-p** | ポートマッピング | `-p 5005:8080` |
| **--rm** | 終了時に自動削除 | `--rm` |
| **--restart** | 再起動ポリシー | `--restart always` |

### コンテナ起動フロー

1. **CLIからAPIへ**: コマンドをAPIリクエストに変換
2. **イメージ検索**: ローカル→なければレジストリから取得
3. **コンテナ作成**: containerd経由でruncが実行
4. **アプリ起動**: Entrypoint/Cmdで指定されたコマンド実行
5. **ポートマッピング**: 指定されたポート公開

### コンテナ確認

```bash
# 実行中のコンテナ
docker ps

# すべてのコンテナ（停止中含む）
docker ps -a

# 特定フォーマットで表示
docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}"
```

## アプリケーション起動方法

コンテナがアプリを起動する3つの方法：

| 方法 | 優先度 | 上書き |
|-----|-------|-------|
| **Entrypoint instruction** | 高 | 不可（CLI引数は追加） |
| **Cmd instruction** | 中 | 可能 |
| **CLI argument** | 低 | - |

### Entrypoint vs Cmd

```bash
# Entrypointの確認
docker inspect myuser/web-app:v0.1 | grep Entrypoint -A 3

"Entrypoint": [
    "node",
    "./app.js"
],
```

**特徴**:
- **Entrypoint**: CLI引数で上書き不可（追加のみ）
- **Cmd**: CLI引数で完全上書き可能

### CLI引数での指定

```bash
# Alpineコンテナで60秒sleep実行
docker run --rm -d alpine sleep 60
```

## 実行中コンテナへの接続

### docker execコマンド

2つのモード：

| モード | 用途 | フラグ |
|-------|------|-------|
| **Interactive** | シェルセッション | `-it` |
| **Remote execution** | コマンド実行のみ | なし |

### インタラクティブセッション

```bash
# シェルに接続
docker exec -it webserver sh

# 作業完了後
exit  # 終了
```

**注意**: Slim imageはシェル未搭載の場合あり。

### リモート実行

```bash
# コマンド実行（出力のみ表示）
docker exec webserver ps
docker exec webserver cat /etc/hosts
```

### docker attach

```bash
# メインプロセスに直接アタッチ
docker attach mycontainer
```

**デタッチ方法**: `Ctrl+P`, `Ctrl+Q` で安全に切断。

## プロセス管理

### PID 1の重要性

- コンテナのメインプロセスは常にPID 1
- **PID 1が終了するとコンテナも終了**
- 追加プロセスはexecセッション等で起動

### プロセス確認

```bash
# コンテナ内で実行
/src # ps
PID   USER     TIME  COMMAND
    1 root      0:00 node ./app.js    ← メインプロセス
   13 root      0:00 sh               ← execセッション
   22 root      0:00 ps               ← 一時プロセス
```

### PID 1終了時の挙動

```bash
# インタラクティブコンテナ起動
$ docker run --name ddd-ctr -it ubuntu:24.04 bash

# bashがPID 1
root@d3c892ad0eb3:/# ps
  PID TTY          TIME CMD
    1 pts/0    00:00:00 bash

# exitするとコンテナも終了
root@d3c892ad0eb3:/# exit

$ docker ps -a
CONTAINER ID   IMAGE          STATUS                  NAMES
d3c892ad0eb3   ubuntu:24.04   Exited (0) 3 secs ago   ddd-ctr
```

## docker inspectコマンド

詳細な設定・ランタイム情報を取得：

```bash
$ docker inspect webserver

"State": {
    "Status": "running"
},
"Name": "/webserver",
"PortBindings": {
    "8080/tcp": [
        {
            "HostIp": "",
            "HostPort": "5005"
        }
    ]
},
"RestartPolicy": {
    "Name": "no",
    "MaximumRetryCount": 0
},
"Image": "myuser/web-app:v0.1",
"WorkingDir": "/src",
"Entrypoint": [
    "node",
    "./app.js"
],
```

**活用例**:
- 設定確認
- トラブルシューティング
- スクリプトでの情報抽出

## コンテナへのデータ書き込み

### アンチパターン警告

**本番環境での書き込みは非推奨**:
- Immutable原則に反する
- 追跡困難
- 再現性低下

**正しいアプローチ**:
1. 新しいコンテナを作成
2. 変更を適用してテスト
3. 既存コンテナを置換

### 書き込みの動作（デモ用）

```bash
# execでコンテナに接続
docker exec -it webserver sh

# ファイル編集
/src # vi views/home.pug
# （変更を保存）

# 確認
/src # cat views/home.pug
```

**重要**: 変更はR/Wレイヤーに保存され、再起動後も保持される。

## ライフサイクル管理

### 停止

```bash
# 通常停止（10秒のgrace period）
docker stop webserver

# 即座に停止
docker stop webserver --time 0
```

**停止プロセス**:
1. SIGTERMをPID 1に送信
2. 10秒待機（アプリのクリーンアップ）
3. 応答なしならSIGKILL送信

### 再起動

```bash
# 停止中コンテナの再起動
docker restart webserver

# 実行中コンテナの再起動
docker restart webserver
```

**データ保持**: R/Wレイヤーの変更は保持される。

### 削除

```bash
# 停止後に削除
docker stop webserver
docker rm webserver

# 強制削除（停止不要）
docker rm webserver -f

# 複数削除
docker rm container1 container2 container3 -f
```

### 一括操作

```bash
# すべてのコンテナを停止
docker stop $(docker ps -q)

# すべてのコンテナを削除
docker rm $(docker ps -aq) -f
```

**警告**: 確認なしで実行されるため慎重に使用。

## Docker Debug

### 概要

**対象**: Docker Desktop Pro/Team/Businessサブスクリプション

**用途**:
- Slim imageのデバッグ
- シェル未搭載コンテナへのアクセス
- トラブルシューティングツールの一時注入

### 仕組み

| 対象 | 動作 | 変更の永続性 |
|-----|------|------------|
| **実行中コンテナ** | 直接アタッチ | ✅ 永続（即座に反映） |
| **イメージ** | サンドボックス作成 | ❌ 一時的 |
| **停止中コンテナ** | サンドボックス作成 | ❌ 一時的 |

**ツールボックス**:
- `/nix`ディレクトリにマウント
- コンテナからは不可視
- セッション終了で削除

### 基本操作

```bash
# ログイン（必須）
docker login

# プラグイン確認
docker info | grep -A 3 "Plugins:"

# デバッグセッション開始
docker debug <container>|<image>
```

### 実行例

```bash
# 実行中コンテナをデバッグ
$ docker debug ddd-ctr

docker > ping example.com
PING example.com (93.184.216.34) 56(84) bytes of data.
64 bytes from 93.184.216.34: icmp_seq=1 ttl=63

docker > vim  # 正常動作

docker > nslookup example.com
zsh: command not found: nslookup  # デフォルトで未インストール
```

### ツール追加

```bash
# 追加パッケージインストール
docker > install bind

# 以降のセッションでも利用可能
docker > nslookup example.com
Server:   192.168.65.7
Address:  192.168.65.7#53

Name:     example.com
Address:  93.184.216.34
```

パッケージ検索: https://search.nixos.org/packages

### entrypointコマンド

```bash
# Entrypoint/Cmdの確認
docker > entrypoint --print
node ./app.js

# Lintチェック
docker > entrypoint --lint

# テスト実行
docker > entrypoint --test
```

## 再起動ポリシー

### ポリシー一覧

| ポリシー | 説明 |
|---------|------|
| **no** | 再起動しない（デフォルト） |
| **on-failure** | 非ゼロ終了コード時のみ |
| **always** | 常に再起動 |
| **unless-stopped** | 手動停止以外は再起動 |

### 挙動比較表

| シナリオ | no | on-failure | always | unless-stopped |
|---------|-----|-----------|--------|---------------|
| 非ゼロ終了 | N | Y | Y | Y |
| ゼロ終了 | N | N | Y | Y |
| docker stop | N | N | N | N |
| daemon再起動 | N | Y | Y | N |

### 設定方法

```bash
# コンテナ起動時に指定
docker run --restart always --name neversaydie -it alpine sh

# 確認
docker inspect neversaydie | grep RestartCount
"RestartCount": 1,
```

### alwaysポリシーの特殊挙動

1. `--restart always`でコンテナ起動
2. `docker stop`で手動停止
3. Docker daemon再起動
4. **コンテナが自動的に再起動される**

**回避**: `unless-stopped`ポリシーを使用。

### Docker Compose/Stack

```yaml
services:
  myservice:
    restart_policy:
      condition: always | unless-stopped | on-failure
      delay: 5s
      max_attempts: 3
      window: 120s
```

## ログ管理

### ログ確認

```bash
# すべてのログ
docker logs webserver

# リアルタイム追跡
docker logs -f webserver

# 最新N行
docker logs --tail 20 webserver

# タイムスタンプ付き
docker logs -t webserver
```

### ログドライバー

| ドライバー | 用途 |
|----------|------|
| **json-file** | デフォルト |
| **syslog** | syslogへ転送 |
| **journald** | systemd journal |
| **gelf** | Graylog |
| **fluentd** | Fluentd |
| **awslogs** | CloudWatch Logs |

設定例：
```bash
docker run --log-driver=syslog --name myapp nginx
```

## 主要コマンドリファレンス

| コマンド | 説明 | 例 |
|---------|------|-----|
| **docker run** | 新規コンテナ起動 | `docker run -it ubuntu bash` |
| **docker ps** | コンテナ一覧 | `docker ps -a` |
| **docker exec** | コンテナ内でコマンド実行 | `docker exec -it <name> bash` |
| **docker stop** | コンテナ停止 | `docker stop webserver` |
| **docker restart** | コンテナ再起動 | `docker restart webserver` |
| **docker rm** | コンテナ削除 | `docker rm webserver -f` |
| **docker logs** | ログ表示 | `docker logs -f webserver` |
| **docker inspect** | 詳細情報表示 | `docker inspect webserver` |
| **docker attach** | メインプロセスに接続 | `docker attach mycontainer` |
| **docker debug** | デバッグセッション | `docker debug <container>` |

### キーボードショートカット

| 操作 | キー |
|-----|------|
| **安全な切断** | `Ctrl+P`, `Ctrl+Q` |
| **強制終了** | `Ctrl+C` |

## チェックリスト: コンテナ管理

- [ ] コンテナとVMの違いを説明できる
- [ ] R/Wレイヤーの仕組みを理解している
- [ ] PID 1の重要性を理解している
- [ ] Entrypoint vs Cmdの違いを説明できる
- [ ] docker exec と docker attach の違いを理解している
- [ ] 再起動ポリシーの挙動を説明できる
- [ ] Docker Debugの使い方を理解している
- [ ] ログ管理の基本を理解している

## ベストプラクティス

### 設計

1. **Stateless設計**
   - 状態はボリュームやDBに保存
   - コンテナは使い捨て

2. **Single process原則**
   - 1コンテナ = 1プロセス
   - 複数プロセスならComposeで複数コンテナ

3. **Immutability**
   - 実行中コンテナを変更しない
   - 変更は新しいイメージ→新しいコンテナ

### 運用

1. **適切な再起動ポリシー**
   - 本番: `always` or `unless-stopped`
   - 開発: `no` or `on-failure`

2. **リソース制限**
   ```bash
   docker run --memory=512m --cpus=0.5 myapp
   ```

3. **ヘルスチェック**
   ```bash
   docker run --health-cmd='curl -f http://localhost/ || exit 1' \
              --health-interval=30s nginx
   ```

### セキュリティ

1. **非rootユーザー実行**
   ```dockerfile
   USER appuser
   ```

2. **Read-only filesystem**
   ```bash
   docker run --read-only myapp
   ```

3. **Capabilities削減**
   ```bash
   docker run --cap-drop=ALL --cap-add=NET_BIND_SERVICE myapp
   ```

### デバッグ

1. **Docker Debug優先**
   - Slim imageに直接ツール追加しない
   - デバッグツールは一時的に注入

2. **ログ活用**
   - 標準出力/エラー出力へのログ出力
   - 適切なログレベル設定

3. **inspect活用**
   - 設定確認
   - ネットワーク/ボリューム情報確認

## トラブルシューティング

### コンテナが起動しない

```bash
# ログ確認
docker logs <container>

# 詳細情報確認
docker inspect <container>

# イベント確認
docker events --since 1h
```

### コンテナが即座に終了

**確認項目**:
- [ ] Entrypoint/Cmdが正しく設定されている
- [ ] アプリケーションエラーがないか（ログ確認）
- [ ] 必要な依存関係が揃っているか

### ネットワーク接続不可

```bash
# コンテナIPアドレス確認
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' <container>

# ポートマッピング確認
docker port <container>

# ネットワーク一覧
docker network ls
```

### リソース不足

```bash
# リソース使用状況
docker stats

# システム全体の使用状況
docker system df
```

## クリーンアップ

### 定期的なクリーンアップ

```bash
# 停止中コンテナすべて削除
docker container prune

# 未使用リソース一括削除
docker system prune

# ボリューム含めて削除（注意！）
docker system prune --volumes
```

**警告**: `prune`コマンドは確認後に実行されますが、慎重に使用してください。

## まとめ

Dockerコンテナは以下の特徴を持つ：
- **軽量**: VM比で圧倒的に小さい
- **高速**: 秒以下で起動
- **Immutable**: 変更時は新規作成
- **Ephemeral**: 使い捨て設計
- **Single process**: PID 1が終了するとコンテナも終了

適切な再起動ポリシーとDocker Debugを活用することで、安定した運用とトラブルシューティングが可能になります。
