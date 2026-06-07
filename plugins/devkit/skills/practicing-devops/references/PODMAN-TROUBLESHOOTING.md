---
description: |
  コンテナ実行時・ビルド時の主要トラブルシューティング手法、Health Check 設計、nsenter による高度な Namespace デバッグの実践ガイド。
  Use when diagnosing container permission errors, health check failures, build errors, or network connectivity issues inside containers.
  Supplements SKILL.md with diagnostic procedures and root cause analysis patterns.
---

# トラブルシューティングリファレンス

## 1. パーミッション問題

### SELinux レイヤー

ボリュームマウント時に `Permission denied` が発生する主な原因:

```bash
# 症状確認
podman logs <container>
# → open /mnt/data/file: permission denied

# SELinux コンテキスト確認
ls -Z /path/to/volume
```

| ボリュームオプション | SELinux ラベル動作 | 用途 |
|---------------------|-------------------|------|
| `:z` | 共有ラベルを付与（複数コンテナ共有可） | 複数コンテナで同一ボリューム共有 |
| `:Z` | プライベートラベルを付与（単一コンテナ専用） | 1コンテナ専用の安全なマウント |

```bash
# 共有ラベル付きマウント（複数コンテナでの共有向け）
podman run -v /data:/mnt/data:z myimage

# プライベートラベル（そのコンテナ専用）
podman run -v /data:/mnt/data:Z myimage
```

**注意**: `:Z` を使うと他のコンテナ・ホストプロセスがそのディレクトリにアクセスできなくなる。

### Rootless レイヤー

Rootless コンテナでは User Namespace マッピングにより、コンテナ内 UID とホスト UID が異なる。

```bash
# ボリューム自動 chown（マウント時にコンテナ内 UID に合わせて変更）
podman run -v /data:/mnt/data:U myimage

# 手動 chown（User Namespace 内で実行）
podman unshare chown -R 1000:1000 /path/to/dir

# ホスト側 UID をそのままコンテナ内で使用
podman run --userns=keep-id -v /home/user/data:/data myimage
```

### `ping` コマンド問題

Rootless コンテナで `ping` が失敗する場合:

```bash
# 症状
ping: socket: Operation not permitted

# 原因確認
cat /proc/sys/net/ipv4/ping_group_range
# → 1  0  (デフォルトで ping を許可するグループ範囲が狭い)

# 修正（永続化する場合は /etc/sysctl.d/ に追記）
sudo sysctl -w net.ipv4.ping_group_range="0 2000000"
```

---

## 2. Health Check 設計

### 5 コンポーネント

| コンポーネント | 説明 | 必須 |
|--------------|------|-----|
| **Command** | 実行するヘルスチェックコマンド（exit 0=成功、非0=失敗） | ✅ |
| **Interval** | チェック実行間隔（短すぎると負荷増、長すぎると検出遅延） | ✅ |
| **Retries** | Unhealthy 判定までの失敗許容回数 | 任意 |
| **Timeout** | コマンド実行タイムアウト | 任意 |
| **Start period** | 起動後の猶予期間（この間の失敗は無視） | 任意 |

### ステート遷移

```
コンテナ起動
    ↓
[ starting ]  ← Start period 中は失敗を無視
    ↓（チェック成功）
[ healthy ]
    ↓（Retries 回連続失敗）
[ unhealthy ]
```

### CLI での設定

```bash
# 手動モード（--health-interval=0 で自動スケジューリング無効）
podman run -dt --name myapp \
  --health-cmd 'curl http://localhost || exit 1' \
  --health-interval=0 \
  myimage

# 手動実行
podman healthcheck run myapp
echo $?  # 0=healthy

# 自動スケジューリング（systemd timer が作成される）
podman run -d --name myapp \
  --health-cmd 'curl -f http://localhost/ || exit 1' \
  --health-interval=10s \
  myimage

# フィルタリング
podman ps -a --filter health=healthy
podman ps -a --filter health=unhealthy
```

### systemd との統合

interval を指定したコンテナには、Podman が transient な systemd unit ファイルを自動生成:

```bash
# 確認場所（Rootless の場合）
ls /run/user/$UID/systemd/transient/<container_id>*.{service,timer}
```

- `.service`: `podman healthcheck run <ID>` を実行
- `.timer`: `OnUnitInactiveSec=<interval>` でスケジューリング
- コンテナ停止で削除 → 再起動時に再生成（永続化不要）

### 障害時の自動対応（--health-on-failure）

```bash
# none（デフォルト）: ステータス更新のみ
podman run -d --health-on-failure=none myimage

# restart: 自動再起動（self-healing）
podman run -d \
  --name self_healing_web \
  --health-cmd "curl -f http://localhost/ || exit 1" \
  --health-on-failure=restart \
  nginx

# stop: コンテナ停止（データ破損防止）
# kill: SIGKILL で即時終了
```

### Containerfile への埋め込み（推奨）

```dockerfile
FROM registry.access.redhat.com/ubi9/ubi-minimal

RUN microdnf install -y python3 && microdnf clean all

# interval/timeout/start-period/retries は任意
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s \
  --retries=3 CMD curl -f http://localhost:8080/ || exit 1

EXPOSE 8080
CMD ["python3", "-m", "http.server", "8080"]
```

**利点**: イメージを pull した人が CLI オプションを調べなくてもヘルスチェックが自動適用される。

---

## 3. ビルドエラーのトラブルシューティング

### RUN 命令の失敗

コマンドの exit code が非ゼロ → ビルド失敗:

```
error building at STEP "RUN yum install -y htpd && yum clean all -y": error while running runtime: exit status 1
```

**対処**: エラーメッセージで失敗した `RUN` 命令を特定 → コマンドを修正

### FROM イメージ関連エラー

| エラーパターン | 原因 | 対処 |
|-------------|------|------|
| `name unknown: Repo not found` | リポジトリ名のtypo | 正しいリポジトリ名に修正 |
| `manifest unknown: manifest unknown` | タグのtypo/存在しないタグ | `skopeo list-tags` で確認 |
| `unauthorized: authentication required` | 認証なしでプライベートレジストリへアクセス | `podman login <registry>` |

```bash
# 有効なタグ一覧を確認
skopeo list-tags docker://docker.io/library/fedora

# プライベートレジストリへ認証
podman login private-registry.example.com
```

### Buildah スクリプトのベストプラクティス

```bash
#!/bin/bash
# ❌ デフォルト: エラーがあっても続行してしまう
# ✅ 推奨: エラーで即停止
set -euo pipefail

container=$(buildah from registry.access.redhat.com/ubi9)
buildah run $container -- dnf install -y httpd
buildah config --cmd "httpd -DFOREGROUND" $container
buildah commit $container my-httpd
```

`-e`: コマンド失敗で即停止、`-u`: 未設定変数をエラー、`-o pipefail`: パイプライン内エラーを伝播

---

## 4. nsenter による高度なトラブルシューティング

### nsenter とは

コンテナ内にデバッグツールがない場合に、**ホストのバイナリをコンテナの Namespace 内で実行**できるツール。`podman exec` はコンテナ内バイナリに制限されるが、`nsenter` はホスト全体のバイナリが使える。

### 基本パターン

```bash
# コンテナのメインプロセス PID 取得
CNT_PID=$(podman inspect <container_name> --format '{{ .State.Pid }}')

# Namespace の確認（/proc/<pid>/ns/ にシンボリックリンクが存在）
ls -al /proc/$CNT_PID/ns

# ネットワーク Namespace のみに入る（ホストバイナリ使用可）
sudo nsenter -t $CNT_PID -n /bin/bash

# 全 Namespace に入る（podman exec と同等）
sudo nsenter -t $CNT_PID -a /bin/bash

# シェルを起動せずコマンドを直接実行
sudo nsenter -t $CNT_PID -n ip addr show
```

### nsenter オプション早見表

| オプション | Namespace | 用途 |
|-----------|----------|------|
| `-n` | Network | ネットワーク接続・ルーティングの調査 |
| `-m` | Mount | ファイルシステムの調査 |
| `-p` | PID | プロセスツリーの調査 |
| `-u` | UTS | hostname の確認 |
| `-i` | IPC | IPC リソースの確認 |
| `-U` | User | UID/GID マッピングの確認 |
| `-a` | All | 全 Namespace（完全なコンテナ視点） |

### ネットワーク調査の実践例

```bash
# PID 取得（rootful コンテナは sudo 必要）
CNT_PID=$(sudo podman inspect students_app --format '{{ .State.Pid }}')

# ネットワーク Namespace に入る
sudo nsenter -t $CNT_PID -n /bin/bash

# コンテナ内のネットワーク確認（ホストの ip コマンドを使用）
ip addr show   # コンテナの NIC/IP を表示
ip route       # ルーティングテーブルを確認

# アクティブな接続確認
ss -atunp
# → ESTABLISHED 接続がなければ接続失敗を示唆

# DNS 解決の確認
dig pghost.example.com
# → NXDOMAIN = DNS 解決失敗 → ホスト名の誤記を疑う

# 手動接続テスト（ホストの psql コマンドをコンテナ NS で実行）
psql -h pghost.example.com
```

### nsenter vs podman exec

| 比較項目 | `podman exec` | `nsenter` |
|---------|--------------|-----------|
| 使用バイナリ | コンテナ内のバイナリのみ | ホストの任意のバイナリ |
| 権限 | コンテナの権限 | root 権限（rootful コンテナ） |
| Namespace 指定 | 全 NS | 任意に組み合わせ可 |
| 用途 | 通常の操作 | ツールのない最小イメージのデバッグ |

### AskUserQuestion が必要なケース

以下の場合はユーザーに確認する:
- `sysctl` の永続変更（`/etc/sysctl.d/` への書き込み）
- SELinux モードの変更（Enforcing → Permissive）
- `--privileged` フラグを追加するセキュリティ緩和

---

## 5. 基本診断コマンド早見表

```bash
# コンテナ情報の詳細確認
podman inspect <container>                  # JSON で全設定を確認
podman inspect <container> --format '{{ .State.Pid }}'  # PID のみ取得

# ログ確認
podman logs <container>                     # 標準ログ
podman logs -f <container>                  # フォロー
podman logs --since 1h <container>          # 直近1時間

# プロセス確認
podman top <container>                      # コンテナ内プロセス一覧

# ファイルシステム差分（コンテナ内での変更を確認）
podman diff <container>

# イベントログ（Podman 操作の履歴）
podman events --filter container=<name>
```
