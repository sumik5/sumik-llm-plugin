# システム堅牢化・攻撃面最小化

Bashスクリプトの競合条件回避、ファイルパーミッション設定、一時ファイル管理、攻撃面最小化の実践ガイド。

---

## 1. TOCTOU（Time-of-Check to Time-of-Use）回避

### 1.1 競合条件の具体例

```bash
# 危険: TOCTOU脆弱性
if [[ -f "$file" ]]; then
    # ここで他プロセスがファイル削除・置換可能
    cat "$file"
fi

# 攻撃シナリオ:
# 1. スクリプトがファイル存在確認
# 2. 攻撃者がファイルをシンボリックリンク(/etc/shadow)に置換
# 3. スクリプトが/etc/shadowを読み込む
```

**安全なパターン: 原子性操作**

```bash
# 良い例: ファイルを直接開く
if content=$(cat "$file" 2>/dev/null); then
    echo "$content"
else
    echo "Error: Cannot read file" >&2
fi

# リダイレクトで原子性確保
if exec 3< "$file" 2>/dev/null; then
    cat <&3
    exec 3<&-
else
    echo "Error: Cannot open file" >&2
fi
```

### 1.2 `flock` によるファイルロック

```bash
# 排他ロック
safe_file_operation() {
    local file="$1"
    local lockfile="${file}.lock"

    # ロック取得（10秒タイムアウト）
    {
        flock -x -w 10 200 || {
            echo "Error: Cannot acquire lock" >&2
            return 1
        }

        # クリティカルセクション
        if [[ -f "$file" ]]; then
            # ファイル操作
            content=$(cat "$file")
            echo "$content" | sed 's/foo/bar/g' > "$file.tmp"
            mv "$file.tmp" "$file"
        fi

    } 200>"$lockfile"

    rm -f "$lockfile"
}

# 使用例
safe_file_operation "data.txt"
```

**共有ロック（読み取り専用）**

```bash
read_with_lock() {
    local file="$1"
    local lockfile="${file}.lock"

    {
        flock -s 200  # 共有ロック
        cat "$file"
    } 200>"$lockfile"
}
```

### 1.3 `mktemp` による一時ファイル安全作成

```bash
# 危険: 予測可能なファイル名
tmpfile="/tmp/myapp_$$"
echo "data" > "$tmpfile"
# 攻撃者が事前にシンボリックリンク作成可能

# 安全: mktemp でランダム名生成
tmpfile=$(mktemp) || {
    echo "Error: Cannot create temp file" >&2
    exit 1
}
trap "rm -f '$tmpfile'" EXIT

echo "data" > "$tmpfile"

# 一時ディレクトリ作成
tmpdir=$(mktemp -d) || exit 1
trap "rm -rf '$tmpdir'" EXIT

# テンプレート指定
tmpfile=$(mktemp /tmp/myapp.XXXXXX)
```

### 1.4 アトミック操作パターン

**ファイル書き込み**

```bash
# 安全: 一時ファイル経由でアトミック更新
atomic_write() {
    local target_file="$1"
    local content="$2"
    local tmpfile

    tmpfile=$(mktemp "${target_file}.XXXXXX") || return 1

    # クリーンアップ設定
    trap "rm -f '$tmpfile'" RETURN

    # 一時ファイルに書き込み
    echo "$content" > "$tmpfile" || return 1

    # パーミッションとオーナーをコピー
    if [[ -f "$target_file" ]]; then
        chmod --reference="$target_file" "$tmpfile"
        chown --reference="$target_file" "$tmpfile"
    fi

    # アトミックに置換（mvはアトミック操作）
    mv "$tmpfile" "$target_file"
}

# 使用例
atomic_write "config.txt" "new configuration data"
```

---

## 2. ファイルパーミッション・監査

### 2.1 `umask` の適切な設定

```bash
# デフォルト umask を確認
umask
# 出力例: 0022 (新規ファイル: 644, 新規ディレクトリ: 755)

# より制限的な umask 設定（グループ・その他から読み取り不可）
umask 077
# 新規ファイル: 600 (rw-------), 新規ディレクトリ: 700 (rwx------)

# スクリプト内で一時的に変更
script_with_secure_umask() {
    local old_umask
    old_umask=$(umask)

    # より厳格な umask
    umask 077

    # セキュアなファイル作成
    echo "secret data" > secure_file.txt

    # 元に戻す
    umask "$old_umask"
}
```

### 2.2 セキュアなファイル作成パターン

```bash
create_secure_file() {
    local filename="$1"

    # ファイルが既に存在する場合はエラー
    if [[ -e "$filename" ]]; then
        echo "Error: File already exists" >&2
        return 1
    fi

    # umask で最も厳格な権限設定
    (
        umask 077
        touch "$filename"
    )

    # さらに明示的にパーミッション設定
    chmod 600 "$filename"

    echo "Created secure file: $filename (permissions: 600)"
}

# ディレクトリも同様
create_secure_dir() {
    local dirname="$1"

    if [[ -e "$dirname" ]]; then
        echo "Error: Directory already exists" >&2
        return 1
    fi

    (
        umask 077
        mkdir -p "$dirname"
    )

    chmod 700 "$dirname"
    echo "Created secure directory: $dirname (permissions: 700)"
}
```

### 2.3 setuid/setgid スクリプトの危険性

**絶対に避けるべき:**

```bash
# 極めて危険: シェルスクリプトにsetuid設定
chmod u+s script.sh  # 実行されない（セキュリティ上の理由で無効）

# なぜ危険か:
# - 環境変数汚染
# - LD_PRELOAD によるライブラリ差し替え
# - PATH 操作
# - IFS 操作
```

**代替手段:**

```bash
# 1. sudo 経由で実行（推奨）
sudo /path/to/script.sh

# 2. C/C++ラッパーでsetuid実装
// setuid_wrapper.c
#include <unistd.h>
#include <stdlib.h>

int main(int argc, char *argv[]) {
    setuid(0);
    setgid(0);
    execl("/path/to/script.sh", "script.sh", NULL);
    return 1;
}

// コンパイル & setuid設定
// gcc -o setuid_wrapper setuid_wrapper.c
// sudo chown root:root setuid_wrapper
// sudo chmod 4755 setuid_wrapper
```

### 2.4 監査ログの実装

```bash
# セキュリティ監査ログ関数
audit_log() {
    local action="$1"
    local user="${2:-$USER}"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_file="/var/log/security_audit.log"

    # ログメッセージ作成
    local log_message
    printf -v log_message '[%s] USER=%s ACTION=%s PID=%d' \
        "$timestamp" "$user" "$action" "$$"

    # ログファイルに追記（排他ロック）
    {
        flock -x 200
        echo "$log_message" >> "$log_file"
    } 200>/var/lock/audit.lock

    # syslogにも送信
    logger -t "security_audit" -p auth.info "$log_message"
}

# 使用例
audit_log "User attempted to access secure resource"
audit_log "File permissions changed" "admin"

# 機密操作の監査
perform_sensitive_operation() {
    audit_log "Sensitive operation started"

    # 操作実行
    if sudo systemctl restart service; then
        audit_log "Sensitive operation completed successfully"
    else
        audit_log "Sensitive operation FAILED"
        return 1
    fi
}
```

---

## 3. 一時ファイルの安全な扱い

### 3.1 `mktemp` の使い方

```bash
# 一時ファイル作成
tmpfile=$(mktemp)

# テンプレート指定
tmpfile=$(mktemp /tmp/myapp.XXXXXX)

# 一時ディレクトリ作成
tmpdir=$(mktemp -d)

# ドライラン（実際には作成しない）
tmpname=$(mktemp -u)  # 非推奨: TOCTOU脆弱性

# エラーハンドリング付き
tmpfile=$(mktemp) || {
    echo "Error: Failed to create temp file" >&2
    exit 1
}
```

### 3.2 trap EXIT によるクリーンアップ

```bash
#!/bin/bash
set -euo pipefail

# 一時ファイル作成
TMPFILE=$(mktemp)
TMPDIR=$(mktemp -d)

# クリーンアップ関数
cleanup() {
    local exit_code=$?

    # 一時ファイル削除
    rm -f "$TMPFILE"
    rm -rf "$TMPDIR"

    # 終了コードで分岐
    if [[ $exit_code -eq 0 ]]; then
        echo "Script completed successfully"
    else
        echo "Script failed with exit code $exit_code" >&2
    fi
}

# trap設定（EXIT, INT, TERM）
trap cleanup EXIT INT TERM

# メイン処理
echo "Working with temp file: $TMPFILE"
echo "Working with temp dir: $TMPDIR"

# 処理...
```

**複数の一時ファイル管理**

```bash
#!/bin/bash
set -euo pipefail

# 一時ファイルリスト
declare -a TEMP_FILES=()

create_temp_file() {
    local tmpfile
    tmpfile=$(mktemp) || return 1

    # リストに追加
    TEMP_FILES+=("$tmpfile")

    echo "$tmpfile"
}

cleanup_all_temps() {
    for file in "${TEMP_FILES[@]}"; do
        rm -f "$file"
    done
}

trap cleanup_all_temps EXIT

# 複数の一時ファイル作成
file1=$(create_temp_file)
file2=$(create_temp_file)
file3=$(create_temp_file)

# 処理...
```

### 3.3 `/tmp` vs `/var/tmp` の使い分け

| ディレクトリ | 再起動後 | 用途 | クリーンアップ |
|------------|---------|------|--------------|
| `/tmp` | 削除される | 短期（セッション内） | 頻繁（日次） |
| `/var/tmp` | 保持される | 長期（複数セッション） | 低頻度 |

```bash
# 短期的な一時データ（/tmp）
short_term_temp=$(mktemp)
echo "session data" > "$short_term_temp"

# 長期的な一時データ（/var/tmp）
long_term_temp=$(mktemp -p /var/tmp)
echo "persistent data" > "$long_term_temp"
```

### 3.4 tmpfs の活用

```bash
# メモリ上の一時ファイルシステム
# /dev/shm (通常デフォルトでマウント済み)

# メモリ上に一時ファイル作成（高速・セキュア）
secure_mem_temp=$(mktemp -p /dev/shm)
echo "sensitive data" > "$secure_mem_temp"
trap "rm -f '$secure_mem_temp'" EXIT

# ディスクに書き込まれない（メモリのみ）
# 再起動で自動削除
```

---

## 4. 攻撃面の最小化

### 4.1 不要な外部コマンド依存の排除

```bash
# 悪い例: 外部コマンド依存
count=$(echo "$string" | wc -c)
uppercase=$(echo "$string" | tr '[:lower:]' '[:upper:]')

# 良い例: Bash組み込み機能
count=${#string}
uppercase=${string^^}

# 判断基準テーブル
```

| 操作 | 外部コマンド | Bash組み込み |
|------|------------|-------------|
| 文字列長 | `echo \| wc -c` | `${#str}` |
| 大文字化 | `tr '[:lower:]' '[:upper:]'` | `${str^^}` |
| 小文字化 | `tr '[:upper:]' '[:lower:]'` | `${str,,}` |
| 置換 | `echo \| sed 's/foo/bar/'` | `${str//foo/bar}` |
| 前方一致削除 | `echo \| sed 's/^prefix//'` | `${str#prefix}` |
| 後方一致削除 | `echo \| sed 's/suffix$//'` | `${str%suffix}` |

### 4.2 PATH の制限

```bash
# 安全なPATH設定
export PATH="/usr/local/bin:/usr/bin:/bin"

# 現在のPATHに追加する場合
PATH="/safe/path:$PATH"

# スクリプト内で固定PATH設定
#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH

# コマンドをフルパスで実行（PATH依存を排除）
/usr/bin/find /var/log -name "*.log"
/bin/grep "ERROR" /var/log/syslog
```

### 4.3 環境のサニタイズ

```bash
# クリーンな環境でコマンド実行
env -i \
    PATH="/usr/local/bin:/usr/bin:/bin" \
    HOME="$HOME" \
    USER="$USER" \
    bash -c 'command_to_run'

# 関数化
run_in_clean_env() {
    env -i \
        PATH="/usr/local/bin:/usr/bin:/bin" \
        HOME="$HOME" \
        bash -c "$@"
}

# 使用例
run_in_clean_env 'ls -la'

# 最小限の環境変数のみ許可
sanitize_environment() {
    local allowed_vars=(PATH HOME USER LANG LC_ALL)

    # 全環境変数を削除
    for var in $(compgen -e); do
        # 許可リストにない変数を削除
        if [[ ! " ${allowed_vars[@]} " =~ " ${var} " ]]; then
            unset "$var"
        fi
    done
}
```

### 4.4 ネットワークアクセスの制限

```bash
# curl/wget にタイムアウト設定
safe_curl() {
    local url="$1"

    # タイムアウト・リトライ・最大サイズ制限
    curl --max-time 30 \
         --retry 3 \
         --retry-delay 5 \
         --max-filesize 10485760 \
         --silent \
         --show-error \
         "$url"
}

# HTTPSのみ許可
safe_download() {
    local url="$1"

    # URLプロトコル検証
    if [[ ! "$url" =~ ^https:// ]]; then
        echo "Error: Only HTTPS URLs allowed" >&2
        return 1
    fi

    safe_curl "$url"
}

# ホストホワイトリスト
safe_api_call() {
    local url="$1"
    local allowed_hosts=(
        "api.example.com"
        "api.staging.example.com"
    )

    # ホスト抽出
    local host
    host=$(echo "$url" | sed -E 's|^https?://([^/]+).*|\1|')

    # ホワイトリストチェック
    if [[ ! " ${allowed_hosts[@]} " =~ " ${host} " ]]; then
        echo "Error: Host not in whitelist: $host" >&2
        return 1
    fi

    safe_curl "$url"
}
```
