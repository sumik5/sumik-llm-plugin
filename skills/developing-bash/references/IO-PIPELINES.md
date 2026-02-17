# IO-PIPELINES.md

Bash における入出力リダイレクト、パイプライン、テキスト処理の実践的リファレンス。

---

## 1. ファイルディスクリプタとリダイレクト

### 基本リダイレクト

すべての Unix プロセスは 3 つの標準ストリームで開始される：

- **stdin (0)**: 標準入力
- **stdout (1)**: 標準出力
- **stderr (2)**: 標準エラー出力

```bash
# stdout を上書き
command > output.txt

# stdout を追記
command >> output.txt

# stdin からファイル読み込み
command < input.txt

# stderr を上書き
command 2> error.log

# stderr を追記
command 2>> error.log
```

### ストリーム結合

```bash
# stdout と stderr を同じファイルに (正しい順序)
command > output.log 2>&1

# ❌ 間違った順序 (stderr は端末に出力される)
command 2>&1 > output.log

# 両方を破棄
command > /dev/null 2>&1

# 短縮形 (Bash 4.0+)
command &> output.log
command &>> output.log  # 追記
```

**重要**: リダイレクトの順序は重要。`2>&1` は「現在の stdout の宛先に stderr を複製」を意味する。

### ファイルディスクリプタの複製

```bash
# stderr を stdout に複製
command 2>&1

# stdout を stderr に複製
command 1>&2

# fd を閉じる
command 2>&-

# stdout と stderr を入れ替え
command 3>&1 1>&2 2>&3 3>&-
```

### カスタムファイルディスクリプタ

```bash
# FD 3 を書き込み用に開く
exec 3> output.txt
echo "data" >&3
exec 3>&-  # 閉じる

# FD 4 を読み込み用に開く
exec 4< input.txt
while read -u 4 line; do
    echo "$line"
done
exec 4>&-

# FD 5 を読み書き用に開く
exec 5<> /tmp/datafile
```

### tee による分岐

```bash
# 端末とファイルの両方に出力
command | tee logfile.txt

# stderr も含める
command 2>&1 | tee logfile.txt

# 追記モード
command | tee -a logfile.txt

# 複数ファイルに分岐
command | tee file1.txt file2.txt file3.txt
```

### 複雑な出力分離

```bash
# stdout と stderr を別々にファイルと端末に送る
command > >(tee stdout.log) 2> >(tee stderr.log >&2)

# stderr のみキャプチャ
exec 3>&1
stderr=$(command 2>&1 1>&3 3>&-)
exec 3>&-

# stdout を保持したまま stderr を変数にキャプチャ
{
    error=$(command 2>&1 1>&3)
} 3>&1
```

---

## 2. プロセス置換

プロセス置換は一時的な名前付きパイプを作成し、コマンド出力/入力をファイルとして扱える。

### 基本構文

```bash
# 読み取り用プロセス置換
<(command)

# 書き込み用プロセス置換
>(command)
```

### diff での出力比較

```bash
# 2 つのコマンド出力を直接比較
diff <(sort file1.txt) <(sort file2.txt)

# パイプライン出力の比較
diff <(grep "pattern" logA.log) <(grep "pattern" logB.log)
```

### 並列データ処理

```bash
# 異なる処理パイプラインの出力を結合
paste <(cut -d, -f1 data.csv) <(awk '{print $2}' data.txt)

# 複数ソースからの並列読み込み
while read -r line1 && read -r line2 <&3; do
    echo "$line1 $line2"
done < <(cat file1.txt) 3< <(cat file2.txt)
```

### パイプとの違い

| 特性 | パイプ (`|`) | プロセス置換 (`<()`, `>()`) |
|------|-------------|---------------------------|
| データフロー | 左から右への1方向 | ファイル引数として扱える |
| 複数入力 | 不可 | 可能 |
| ランダムアクセス | 不可 | 可能 (実装依存) |
| 使用場面 | シーケンシャル処理 | ファイル引数が必要な場合 |

---

## 3. Here Document と Here String

### Here Document

```bash
# 基本形 (変数展開あり)
cat <<EOF
Hello $USER
Current directory: $PWD
EOF

# 変数展開なし
cat <<'EOF'
Literal $USER and $PWD
EOF

# インデント付き (タブのみ除去)
cat <<-EOF
	This line is indented
	But tabs are removed
EOF

# ファイルに書き込み
cat <<EOF > output.txt
Line 1
Line 2
EOF
```

### Here String

```bash
# 文字列を stdin に送る
grep "pattern" <<< "search this text"

# 変数の内容を処理
var="hello world"
tr '[:lower:]' '[:upper:]' <<< "$var"

# コマンド置換と組み合わせ
wc -l <<< "$(ls -l)"
```

### 実用例

```bash
# SQL クエリ実行
mysql -u user -p <<EOF
USE database;
SELECT * FROM table WHERE id = 1;
EOF

# 設定ファイル生成
cat <<EOF > /etc/config.conf
server_name=$HOSTNAME
port=8080
debug=true
EOF

# メール送信
sendmail -t <<EOF
To: user@example.com
Subject: Alert
From: system@example.com

System alert message here.
EOF
```

---

## 4. パイプライン構築パターン

### パイプラインの基礎

```bash
# 基本パイプライン
command1 | command2 | command3

# 複数行でも記述可能
command1 \
  | command2 \
  | command3
```

### PIPESTATUS と pipefail

```bash
# すべてのパイプラインコマンドの終了ステータス
cmd1 | cmd2 | cmd3
echo "${PIPESTATUS[@]}"  # 例: 0 1 0

# パイプライン内のいずれかが失敗したら全体を失敗にする
set -o pipefail
command1 | command2 | command3
if [ $? -ne 0 ]; then
    echo "Pipeline failed"
fi
```

### パイプラインエラー処理パターン

```bash
#!/bin/bash
set -euo pipefail

# パイプライン全体が安全にエラー終了
curl -fsSL https://example.com/data \
  | jq '.items[]' \
  | while read -r item; do
      process_item "$item"
    done
```

### 名前付きパイプ (FIFO)

```bash
# FIFO 作成
mkfifo /tmp/mypipe

# 読み取り側 (バックグラウンド)
cat /tmp/mypipe | process_data &

# 書き込み側
echo "data" > /tmp/mypipe

# クリーンアップ
rm /tmp/mypipe
```

### 双方向パイプライン

```bash
# 名前付きパイプで双方向通信
mkfifo pipe1 pipe2

# プロセス A
{
    while read -r cmd < pipe1; do
        echo "Response: $cmd" > pipe2
    done
} &

# プロセス B
{
    echo "Request" > pipe1
    read -r response < pipe2
    echo "$response"
}

# クリーンアップ
rm pipe1 pipe2
```

**テキスト処理ツール、正規表現、構造化データ処理の詳細は [TEXT-PROCESSING.md](./TEXT-PROCESSING.md) を参照してください。**

---

## 5. ログ管理パターン

### ログレベル実装

```bash
#!/bin/bash

LOG_FILE="/var/log/app.log"
LOG_LEVEL="${LOG_LEVEL:-INFO}"

log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"

    # 端末にも出力 (ERROR 以上)
    if [[ "$level" =~ ^(ERROR|FATAL)$ ]]; then
        echo "[$timestamp] [$level] $message" >&2
    fi
}

log_debug() { [[ "$LOG_LEVEL" == "DEBUG" ]] && log "DEBUG" "$@"; }
log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }

# 使用例
log_info "Application started"
log_warn "Configuration incomplete"
log_error "Failed to connect to database"
```

### ログローテーション

```bash
#!/bin/bash

LOG_FILE="/var/log/app.log"
MAX_SIZE=$((10 * 1024 * 1024))  # 10MB
KEEP_COUNT=5

rotate_logs() {
    if [ ! -f "$LOG_FILE" ]; then
        return
    fi

    local size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE")

    if [ "$size" -gt "$MAX_SIZE" ]; then
        # 古いログを削除
        [ -f "${LOG_FILE}.${KEEP_COUNT}" ] && rm "${LOG_FILE}.${KEEP_COUNT}"

        # ローテーション
        for i in $(seq $((KEEP_COUNT - 1)) -1 1); do
            [ -f "${LOG_FILE}.$i" ] && mv "${LOG_FILE}.$i" "${LOG_FILE}.$((i + 1))"
        done

        mv "$LOG_FILE" "${LOG_FILE}.1"
        touch "$LOG_FILE"

        echo "Log rotated: $(date)" >> "$LOG_FILE"
    fi
}

# 使用例
rotate_logs
```

### syslog 連携

```bash
# logger コマンドで syslog に送信
logger -t myapp -p user.info "Application started"
logger -t myapp -p user.err "Error occurred"

# スクリプト内での使用
log_to_syslog() {
    local level=$1
    shift
    local message="$@"

    case "$level" in
        ERROR) logger -t myapp -p user.err "$message" ;;
        WARN)  logger -t myapp -p user.warning "$message" ;;
        *)     logger -t myapp -p user.info "$message" ;;
    esac
}
```

---

## パフォーマンス考慮事項

### パイプライン最適化

```bash
# ❌ 非効率: 複数回ファイル読み込み
grep "pattern1" file.txt > tmp1
grep "pattern2" file.txt > tmp2

# ✅ 効率的: 1回の読み込み
awk '/pattern1/ {print > "tmp1"} /pattern2/ {print > "tmp2"}' file.txt

# ❌ 非効率: 不要な cat
cat file.txt | grep "pattern"

# ✅ 効率的: 直接ファイル指定
grep "pattern" file.txt
```

### 大規模ファイル処理

```bash
# バッファサイズ調整
grep --mmap "pattern" huge_file.txt

# 並列処理 (後述の PROCESS-CONTROL.md 参照)
split -n 4 huge_file.txt part_
for part in part_*; do
    grep "pattern" "$part" &
done
wait
```
