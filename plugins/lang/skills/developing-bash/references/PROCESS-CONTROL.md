# PROCESS-CONTROL.md

Bash におけるプロセス制御、並列実行、シグナル処理の実践的リファレンス。

---

## 1. バックグラウンドジョブとサブシェル

### バックグラウンド実行の基本

```bash
# バックグラウンドで実行
sleep 60 &

# 最後のバックグラウンドプロセスの PID を取得
pid=$!
echo "Started process $pid"

# パイプラインをバックグラウンドで実行
(ls -l | grep "pattern") &

# 複数コマンドをグループ化してバックグラウンド実行
{ command1; command2; command3; } &
```

### サブシェルとコマンドグループの違い

```bash
# サブシェル: 独立したプロセス、変数変更は親に影響しない
count=0
(count=$((count + 1)); echo "Subshell: $count")
echo "Parent: $count"  # 出力: Parent: 0

# コマンドグループ: 同じプロセス、変数変更は親に影響する
count=0
{ count=$((count + 1)); echo "Group: $count"; }
echo "Parent: $count"  # 出力: Parent: 1
```

### サブシェルのスコープ

```bash
# 環境変数は継承されるが、変更は親に伝わらない
export VAR="parent"
(
    echo "Child sees: $VAR"  # parent
    VAR="child"
    echo "Child modified: $VAR"  # child
)
echo "Parent still has: $VAR"  # parent

# ファイルディスクリプタも独立
exec 3> parent.txt
(
    exec 3> child.txt
    echo "child data" >&3
)
echo "parent data" >&3
exec 3>&-
```

---

## 2. ジョブ制御

### ジョブ制御コマンド

```bash
# ジョブ一覧表示
jobs

# ジョブをフォアグラウンドに移動
fg %1        # ジョブ番号 1
fg %?sleep   # "sleep" を含むジョブ

# ジョブをバックグラウンドで再開
bg %1

# Ctrl+Z でフォアグラウンドジョブを停止
# Ctrl+C でフォアグラウンドジョブを終了
# Ctrl+D で EOF を送信
```

### nohup と disown

```bash
# nohup: SIGHUP を無視してバックグラウンド実行
nohup long_running_command &

# disown: 既存のジョブをシェルのジョブテーブルから削除
sleep 1000 &
disown %1

# 全ジョブを disown
disown -a

# シェル終了時にバックグラウンドジョブを維持
shopt -s huponexit  # SIGHUP を送る (デフォルト)
shopt -u huponexit  # SIGHUP を送らない
```

### 実用パターン

```bash
# ログファイルをバックグラウンドで監視
tail -f /var/log/app.log &
TAIL_PID=$!

# 作業完了後に終了
# ... do work ...
kill $TAIL_PID

# SSH 経由でバックグラウンドジョブを開始
ssh user@host 'nohup ./script.sh > /dev/null 2>&1 &'
```

---

## 3. シグナル処理

### trap コマンドの基本

```bash
# 基本構文
trap 'commands' SIGNAL

# シグナル番号またはシグナル名
trap 'echo "Caught SIGINT"' INT
trap 'echo "Caught SIGTERM"' TERM
trap 'echo "Caught SIGINT or SIGTERM"' INT TERM
```

### EXIT trap (クリーンアップパターン)

```bash
#!/bin/bash

cleanup() {
    echo "Cleaning up..."
    rm -f /tmp/temp_file_$$
    kill $(jobs -p) 2>/dev/null
}

trap cleanup EXIT

# 一時ファイル作成
temp_file="/tmp/temp_file_$$"
echo "data" > "$temp_file"

# スクリプトが終了すると自動的にクリーンアップされる
exit 0
```

### ERR trap (エラー捕捉)

```bash
#!/bin/bash
set -e

error_handler() {
    local line=$1
    echo "Error on line $line" >&2
    # エラー通知やログ記録
}

trap 'error_handler $LINENO' ERR

# エラーが発生すると error_handler が呼ばれる
false  # この行でエラー発生
```

### DEBUG trap (デバッグ用途)

```bash
#!/bin/bash

debug_trace() {
    echo "Executing: $BASH_COMMAND" >&2
}

trap debug_trace DEBUG

# 各コマンド実行前に呼ばれる
echo "Hello"
ls /tmp
```

### よく使うシグナル一覧

| シグナル | 番号 | 説明 | デフォルト動作 | trap 可能 |
|---------|------|------|---------------|---------|
| SIGHUP | 1 | ハングアップ (端末切断) | 終了 | ✅ |
| SIGINT | 2 | 割り込み (Ctrl+C) | 終了 | ✅ |
| SIGQUIT | 3 | 終了 (Ctrl+\) | コアダンプ | ✅ |
| SIGKILL | 9 | 強制終了 | 即座に終了 | ❌ |
| SIGTERM | 15 | 終了要求 | 終了 | ✅ |
| SIGSTOP | 19 | 停止 | 停止 | ❌ |
| SIGCONT | 18 | 再開 | 再開 | ✅ |
| SIGUSR1 | 10 | ユーザー定義 1 | 終了 | ✅ |
| SIGUSR2 | 12 | ユーザー定義 2 | 終了 | ✅ |

### 実用シグナルハンドラ

```bash
#!/bin/bash

# 設定ファイル再読み込み
reload_config() {
    echo "Reloading configuration..."
    source /etc/myapp.conf
}

trap reload_config HUP

# グレースフルシャットダウン
shutdown_gracefully() {
    echo "Shutting down gracefully..."
    # 処理中のタスクを完了
    wait
    exit 0
}

trap shutdown_gracefully TERM INT

# メインループ
while true; do
    # 処理
    sleep 1
done
```

---

## 関連ガイド

並列実行、プロセス間通信、リソース制限の詳細については以下を参照:

- **[PARALLELISM.md](./PARALLELISM.md)** - 並列実行パターン、IPC、リソース制限、ゾンビ/孤児プロセス回避
