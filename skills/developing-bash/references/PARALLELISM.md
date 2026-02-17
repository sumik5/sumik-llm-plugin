# 並列実行・IPC・リソース制限

Bash における並列実行パターン、プロセス間通信、リソース制御、ゾンビ/孤児プロセス回避の実践ガイド。

---

## 1. 並列実行パターン

### wait による同期

```bash
# 基本的な並列実行
task1 &
pid1=$!
task2 &
pid2=$!

# 両方の完了を待機
wait $pid1 $pid2

# または全ジョブを待機
wait

# 終了ステータス取得
wait $pid1
status1=$?
wait $pid2
status2=$?
```

### 並列実行の基本パターン

```bash
#!/bin/bash

# 並列実行数を制御しない (すべて同時起動)
for i in {1..10}; do
    process_item "$i" &
done
wait

# 結果確認
echo "All tasks completed"
```

### 並列実行数の制御 (セマフォパターン)

```bash
#!/bin/bash

MAX_JOBS=4

# 現在の実行中ジョブ数をカウント
count_jobs() {
    jobs -r | wc -l
}

# ジョブ数が上限未満になるまで待機
wait_for_slot() {
    while [ $(count_jobs) -ge $MAX_JOBS ]; do
        sleep 0.1
    done
}

# 並列実行
for i in {1..100}; do
    wait_for_slot
    process_item "$i" &
done

wait
```

### xargs による並列実行

```bash
# -P で並列実行数を指定
find . -name "*.txt" | xargs -P 4 -I {} process_file {}

# -n で一度に渡す引数数を指定
seq 1 100 | xargs -n 1 -P 8 process_number

# 複雑なコマンド
cat urls.txt | xargs -P 4 -I {} bash -c 'curl -o "$(basename {})" "{}"'
```

### GNU parallel の活用

```bash
# インストール: apt-get install parallel または brew install parallel

# 基本的な並列実行
parallel echo {} ::: 1 2 3 4 5

# ファイルリストを並列処理
ls *.txt | parallel gzip {}

# 複数引数
parallel echo {1} {2} ::: A B C ::: 1 2 3

# ジョブ数制御
parallel -j 4 process_item {} ::: $(seq 1 100)

# 進捗表示
parallel --progress process_item {} ::: $(seq 1 100)

# 失敗時の再試行
parallel --retries 3 curl {} ::: $(cat urls.txt)
```

### ワーカープールパターン

```bash
#!/bin/bash

WORKER_COUNT=4
JOB_QUEUE="/tmp/job_queue_$$"
mkfifo "$JOB_QUEUE"

# ワーカープロセス
worker() {
    local id=$1
    while read -r job; do
        echo "Worker $id processing: $job"
        process_job "$job"
    done < "$JOB_QUEUE"
}

# ワーカー起動
for i in $(seq 1 $WORKER_COUNT); do
    worker $i &
done

# ジョブをキューに投入
for job in $(seq 1 100); do
    echo "$job" > "$JOB_QUEUE"
done

# クリーンアップ
wait
rm "$JOB_QUEUE"
```

---

## 2. プロセス間通信 (IPC)

### 匿名パイプ

```bash
# 標準的なパイプライン
command1 | command2

# プロセス置換を使った複雑なパイプ
diff <(command1) <(command2)
```

### 名前付きパイプ (FIFO)

```bash
# FIFO 作成
mkfifo /tmp/myfifo

# 読み取りプロセス (バックグラウンド)
(
    while read -r line; do
        echo "Received: $line"
    done < /tmp/myfifo
) &

# 書き込みプロセス
for i in {1..5}; do
    echo "Message $i" > /tmp/myfifo
    sleep 1
done

# クリーンアップ
wait
rm /tmp/myfifo
```

### シグナルによる通信

```bash
# プロセス A
#!/bin/bash
trap 'echo "Received SIGUSR1"' USR1
trap 'echo "Received SIGUSR2"' USR2

echo $$ > /tmp/procA.pid

while true; do
    sleep 1
done

# プロセス B
#!/bin/bash
pid=$(cat /tmp/procA.pid)
kill -USR1 $pid  # SIGUSR1 送信
sleep 2
kill -USR2 $pid  # SIGUSR2 送信
```

### 共有ファイル / ロックファイル

```bash
# ロックファイルによる排他制御
acquire_lock() {
    local lockfile="/tmp/myapp.lock"
    local timeout=10
    local elapsed=0

    while [ -e "$lockfile" ]; do
        if [ $elapsed -ge $timeout ]; then
            echo "Failed to acquire lock" >&2
            return 1
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done

    echo $$ > "$lockfile"
    return 0
}

release_lock() {
    rm -f "/tmp/myapp.lock"
}

# 使用例
if acquire_lock; then
    trap release_lock EXIT
    # クリティカルセクション
    critical_operation
fi
```

### flock による排他制御

```bash
# flock を使った安全なロック
(
    flock -x 200 || exit 1
    # クリティカルセクション
    critical_operation
) 200>/tmp/myapp.lock

# タイムアウト付き
(
    flock -x -w 10 200 || exit 1
    critical_operation
) 200>/tmp/myapp.lock

# 関数としてラップ
with_lock() {
    local lockfile=$1
    shift
    (
        flock -x 200 || return 1
        "$@"
    ) 200>"$lockfile"
}

with_lock /tmp/myapp.lock critical_operation arg1 arg2
```

---

## 3. リソース制限

### ulimit の主要オプション

```bash
# 現在の制限を表示
ulimit -a

# ファイルサイズ制限 (ブロック単位)
ulimit -f 10000

# コアダンプサイズ (ブロック単位)
ulimit -c unlimited

# プロセス数
ulimit -u 100

# オープンファイル数
ulimit -n 1024

# メモリ使用量 (KB)
ulimit -m 1048576

# 仮想メモリ (KB)
ulimit -v 2097152

# CPU 時間 (秒)
ulimit -t 600

# スタックサイズ (KB)
ulimit -s 8192
```

### スクリプトでの制限設定

```bash
#!/bin/bash

# リソース制限を設定
ulimit -n 1024        # ファイルディスクリプタ
ulimit -u 50          # プロセス数
ulimit -t 300         # CPU 時間 (5分)
ulimit -v 1048576     # 仮想メモリ (1GB)

# メイン処理
main() {
    # 制限内で実行される
    exec_program
}

main
```

### cgroups の概要

cgroups (control groups) はより高度なリソース制限を提供するが、通常は systemd や Docker で管理される。

```bash
# systemd での CPU 制限例
systemctl set-property myservice.service CPUQuota=50%

# Docker でのメモリ制限例
docker run --memory="512m" --cpus="1.5" myimage
```

---

## 4. ゾンビ/孤児プロセス回避

### ゾンビプロセスの原因と対策

```bash
# ❌ 悪い例: wait せずに終了 → ゾンビプロセス発生
bad_example() {
    sleep 10 &
    # wait しないとゾンビになる
}

# ✅ 良い例: wait で回収
good_example() {
    sleep 10 &
    pid=$!
    # 他の処理
    wait $pid
}

# ✅ 全ジョブを wait
cleanup_all_jobs() {
    wait
}

trap cleanup_all_jobs EXIT
```

### 孤児プロセスの扱い

```bash
# 孤児プロセスは init (PID 1) が養子にする
# シェル終了時にバックグラウンドジョブが孤児になる

# ❌ シェル終了時にプロセスが残る
long_running_task &
exit 0

# ✅ nohup で意図的に孤児化
nohup long_running_task &

# ✅ disown でシェルから切り離し
long_running_task &
disown
```

### デーモン化パターン

```bash
#!/bin/bash

daemonize() {
    # 二重 fork でデーモン化
    (
        # 最初の fork
        if [ "$(id -u)" != "0" ]; then
            echo "Must run as root" >&2
            exit 1
        fi

        # 新しいセッションを開始
        setsid bash -c "
            # 二番目の fork
            (
                # 作業ディレクトリを変更
                cd /

                # ファイルディスクリプタをクローズ
                exec > /dev/null 2>&1 < /dev/null

                # メイン処理
                while true; do
                    # デーモンの処理
                    sleep 60
                done
            ) &
        " &
    )
}

daemonize
```

---

## 5. 並列実行の実用パターン

### バッチ処理の並列化

```bash
#!/bin/bash
set -euo pipefail

PARALLEL_JOBS=8
INPUT_DIR="/data/input"
OUTPUT_DIR="/data/output"

process_file() {
    local input=$1
    local output="$OUTPUT_DIR/$(basename "$input")"

    echo "Processing: $input"
    # 実際の処理
    convert_file "$input" "$output"
}

export -f process_file
export OUTPUT_DIR

# 並列処理
find "$INPUT_DIR" -name "*.dat" | \
    xargs -P "$PARALLEL_JOBS" -I {} bash -c 'process_file "{}"'

echo "Batch processing completed"
```

### 失敗時の再試行付き並列実行

```bash
#!/bin/bash

MAX_RETRIES=3
PARALLEL_JOBS=4

process_with_retry() {
    local item=$1
    local attempt=0

    while [ $attempt -lt $MAX_RETRIES ]; do
        if process_item "$item"; then
            return 0
        fi
        attempt=$((attempt + 1))
        echo "Retry $attempt for $item" >&2
        sleep $((attempt * 2))
    done

    echo "Failed after $MAX_RETRIES attempts: $item" >&2
    return 1
}

export -f process_with_retry

# 並列実行
cat items.txt | xargs -P "$PARALLEL_JOBS" -I {} bash -c 'process_with_retry "{}"'
```

### 進捗表示付き並列実行

```bash
#!/bin/bash

TOTAL=100
COMPLETED=0
LOCK="/tmp/progress.lock"

update_progress() {
    (
        flock -x 200
        COMPLETED=$((COMPLETED + 1))
        echo "$COMPLETED"
        printf "\rProgress: %d/%d (%d%%)" \
            $COMPLETED $TOTAL $((COMPLETED * 100 / TOTAL))
    ) 200>"$LOCK"
}

process_with_progress() {
    local item=$1
    process_item "$item"
    update_progress
}

export -f process_with_progress update_progress
export TOTAL COMPLETED LOCK

seq 1 $TOTAL | xargs -P 4 -I {} bash -c 'process_with_progress {}'
echo  # 改行
```

---

## 6. デバッグとトラブルシューティング

### プロセスツリーの可視化

```bash
# pstree でプロセスツリー表示
pstree -p $$

# ps でプロセス階層表示
ps auxf | grep -A 5 $$

# プロセスグループ表示
ps -o pid,pgid,comm
```

### ハングしたプロセスの調査

```bash
# スタックトレース表示 (Linux)
gdb -batch -ex "thread apply all bt" -p $PID

# システムコール追跡
strace -p $PID

# オープンファイル確認
lsof -p $PID
```

### パフォーマンス測定

```bash
# time コマンド
time process_data

# より詳細な統計
/usr/bin/time -v process_data

# 並列実行の効果測定
time for i in {1..10}; do task; done       # 直列
time for i in {1..10}; do task & done; wait  # 並列
```

---

## ベストプラクティス

1. **PID を即座にキャプチャ**: `$!` を使って常に PID を保存
2. **wait を明示的に使用**: 依存関係のあるステップでは必ず wait
3. **出力ストリームを分離**: 競合を避けるためにファイル分割
4. **EXIT trap でクリーンアップ**: 一時ファイルやバックグラウンドジョブを確実に終了
5. **エラー処理を徹底**: `set -euo pipefail` と trap ERR の併用
6. **並列度を制限**: システムリソースに応じて並列数を調整
7. **シグナルハンドラでグレースフルシャットダウン**: SIGTERM/SIGINT に対応
8. **ゾンビプロセスを回避**: wait で子プロセスを回収
