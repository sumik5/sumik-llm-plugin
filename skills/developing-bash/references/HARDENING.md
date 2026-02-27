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

---

## 5. セキュリティアップデート自動化

### 5.1 Ubuntu（unattended-upgrades）

`/etc/apt/apt.conf.d/20auto-upgrades` で自動更新の頻度を制御する:

```
# 毎日更新（デフォルト）
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";

# 3日ごとに更新
APT::Periodic::Update-Package-Lists "3";
APT::Periodic::Unattended-Upgrade "3";

# 自動更新を無効化
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Unattended-Upgrade "0";
```

自動リブートは `/etc/apt/apt.conf.d/50unattended-upgrades` で設定する:

```
# ログイン中ユーザーがいない場合にリブート
Unattended-Upgrade::Automatic-Reboot "true";

# ログイン中でも強制リブート
Unattended-Upgrade::Automatic-Reboot-WithUsers "true";

# リブート時刻の指定
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
```

**注意**: 大規模フリートには `unattended-upgrades` ではなく Landscape/Ansible/Puppet 等のフリート管理ツールを使用すること。

### 5.2 Red Hat系（dnf-automatic）

```bash
# パッケージインストール
sudo dnf install dnf-automatic

# /etc/dnf/automatic.conf の編集
# upgrade_type = security（セキュリティ更新のみ）
# reboot = when-needed（必要時にリブート）

# タイマーを有効化
sudo systemctl enable --now dnf-automatic-install.timer
```

### 5.3 openSUSE（os-update）

```bash
sudo zypper in os-update

# /etc/os-update.conf を作成して設定を上書き
cat > /etc/os-update.conf <<'EOF'
UPDATE_CMD=security
SERVICES_TRIGGERING_REBOOT="dbus dbus-broker"
SERVICES_TRIGGERING_SOFT_REBOOT=""
EOF

sudo systemctl enable --now os-update.timer
```

---

## 6. sudoアクティビティ監査

ユーザーの `sudo` 使用履歴をシステムログから抽出してレポートを生成するスクリプト:

```bash
#!/bin/sh
# sudoアクティビティ監査スクリプト
# 使用法: sudo ./user_activity.sh <username>

if [ "$1" = "" ]; then
    echo "使用法: sudo $0 <username>"
    exit 1
fi

timestamp="$(date +"%F_%H-%M")"
username="$1"

# ディストリビューション別ログファイル検出
if [ -f /var/log/secure ]; then
    logfile=/var/log/secure          # Red Hat系
elif [ -f /var/log/auth.log ]; then
    logfile=/var/log/auth.log        # Debian/Ubuntu系
elif [ -n "$(awk /suse/ /etc/os-release)" ]; then
    logfile=/var/log/messages        # openSUSE
elif [ -n "$(awk /openmandriva/ /etc/os-release)" ]; then
    logfile=/var/log/sudo.log        # OpenMandriva
else
    echo "未知のOS: ログファイルを特定できません" >&2
    exit 1
fi

outfile="user_activity_for_${username}_${timestamp}.txt"

# レポート生成
echo "=== User Account Activity ===" > "$outfile"
echo "=== Recent Logins ===" >> "$outfile"
last | grep "$username" >> "$outfile"

echo "=== Sudo Command Usage ===" >> "$outfile"
if [ -n "$(awk /openmandriva/ /etc/os-release)" ]; then
    grep "$username" "$logfile" >> "$outfile"
else
    grep sudo "$logfile" | grep "$username" >> "$outfile"
fi

echo "レポート生成完了: $outfile"
```

**運用ポイント**:
- 日次実行を推奨（cron または systemd timer）
- ログローテーションは通常4週間サイクル。それ以上古いログは自動削除されるため定期実行が必須

---

## 7. rootアカウント監査

有効な `root` アカウントを検出し、必要に応じて無効化するポータブルスクリプト（`#!/bin/sh` でFreeBSD/OpenIndiana対応）:

```bash
#!/bin/sh
# rootアカウント監査スクリプト（ポータブル sh）
# 使用法: sudo ./rootlock.sh

os=$(uname)
quantity=$(cut -f3 -d: /etc/passwd | grep -w 0 | wc -l)

# Linux/Solaris向け処理
linux_sunos() {
    if [ "$quantity" -gt 1 ]; then
        echo "CRITICAL: UID 0アカウントが ${quantity}個 存在します"
    else
        echo "OKAY: UID 0アカウントは1つのみです"
    fi

    # /etc/shadow の2フィールド目先頭が '$' なら有効なパスワードが存在
    rootlock=$(awk 'BEGIN {FS=":"}; /root/ {print $2}' /etc/shadow | cut -c1)
    if [ "$rootlock" = '$' ]; then
        echo "CRITICAL: rootアカウントが有効です"
        echo "無効化しますか？ (y/n)"
        read answer
        if [ "$answer" = y ]; then
            passwd -d root
            passwd -l root
            echo "rootアカウントを無効化しました"
        fi
    else
        echo "OKAY: rootアカウントはロックされています"
    fi
}

# FreeBSD向け処理（/etc/master.passwd 使用、UID 0が2つ正常）
freebsd() {
    if [ "$quantity" -gt 2 ]; then
        echo "CRITICAL: UID 0アカウントが ${quantity}個 存在します"
    else
        echo "OKAY: UID 0アカウントは2つのみです（root, toor）"
    fi

    rootlock=$(awk 'BEGIN {FS=":"}; $1 ~ /root/ {print $2}' /etc/master.passwd | cut -c1)
    if [ "$rootlock" = '$' ]; then
        echo "CRITICAL: rootアカウントが有効です"
        echo "無効化しますか？ (y/n)"
        read answer
        [ "$answer" = y ] && pw mod user root -w no
    else
        echo "OKAY: rootアカウントはロックされています"
    fi

    toorlock=$(awk 'BEGIN {FS=":"}; /toor/ {print $2}' /etc/master.passwd | cut -c1)
    if [ "$toorlock" = '$' ]; then
        echo "CRITICAL: toorアカウントが有効です"
        echo "無効化しますか？ (y/n)"
        read answer
        [ "$answer" = y ] && pw mod user toor -w no
    else
        echo "OKAY: toorアカウントはロックされています"
    fi
}

# OS判定して関数実行
if [ "$os" = Linux ] || [ "$os" = SunOS ]; then
    linux_sunos
elif [ "$os" = FreeBSD ]; then
    freebsd
else
    echo "未知のOS: $os" >&2
    exit 1
fi
```

**ポータビリティのポイント**:
- `[[...]]` の代わりに `[...]` を使用（ash/dash/ksh対応）
- 配列は使用しない（POSIX sh非対応のため）
- FreeBSDは通常 UID 0 が `root` と `toor` の2つ存在する（正常）

---

## 8. Apacheアクセスログ監査

クロスサイトスクリプティング（XSS）・Nmap・Niktoスキャンの痕跡をApacheログから検出するスクリプト:

```bash
#!/bin/sh
# Apacheアクセスログ監査スクリプト（ポータブル sh）
# 使用法: sudo ./xss_detect.sh <ログディレクトリ> <出力ファイル>
# 例: ./xss_detect.sh /var/log/apache2 xss_results.txt

inputpath="$1"
output_file="$2"
BLACK=$(tput setaf 0)
RED=$(tput setaf 1)
os="$(uname)"

if [ "$#" -ne 2 ]; then
    echo "使用法: $0 <ログディレクトリ> <出力ファイル>"
    exit 1
fi
if [ -f "$output_file" ]; then
    echo "エラー: 出力ファイルが既に存在します: $output_file" >&2
    exit 1
fi

# === XSSアタックパターン検出 ===
# パーセントエンコードを含むURLはXSSの兆候（位置1・2・3文字目）
echo "${RED}Apparent Cross-site scripting attack${BLACK}" >> "$output_file"
find "$inputpath" -iname '*.gz' -exec zcat {} \; | grep 'GET /%' >> "$output_file"
find "$inputpath" -iname '*.gz' -exec zcat {} \; | grep 'GET /.%' >> "$output_file"
find "$inputpath" -iname '*.gz' -exec zcat {} \; | grep 'GET /.=%' >> "$output_file"

# アクティブなアクセスログ（FreeBSDはhttpd-access.log）
if [ "$os" = FreeBSD ]; then
    grep 'GET /%'  "$inputpath/httpd-access.log" >> "$output_file"
    grep 'GET /.%' "$inputpath/httpd-access.log" >> "$output_file"
    grep 'GET /.=%' "$inputpath/httpd-access.log" >> "$output_file"
else
    grep 'GET /%'  "$inputpath/access.log" >> "$output_file"
    grep 'GET /.%' "$inputpath/access.log" >> "$output_file"
    grep 'GET /.=%' "$inputpath/access.log" >> "$output_file"
fi

# === Nmapスクリプトスキャン検出 ===
echo "***************************************" >> "$output_file"
echo "${RED}Nmap Scripting Scans${BLACK}" >> "$output_file"
find "$inputpath" -iname '*.gz' -exec zcat {} \; | grep -i 'nmap' >> "$output_file"
if [ "$os" = FreeBSD ]; then
    grep -i 'nmap' "$inputpath/httpd-access.log" >> "$output_file"
else
    grep -i 'nmap' "$inputpath/access.log" >> "$output_file"
fi

# === Niktoスキャン検出 ===
echo "***************************************" >> "$output_file"
echo "${RED}Nikto Scanner Attacks${BLACK}" >> "$output_file"
find "$inputpath" -iname '*.gz' -exec zcat {} \; | grep -i 'nikto' >> "$output_file"
if [ "$os" = FreeBSD ]; then
    grep -i 'nikto' "$inputpath/httpd-access.log" >> "$output_file"
else
    grep -i 'nikto' "$inputpath/access.log" >> "$output_file"
fi

echo "監査完了: $output_file"
```

**検出パターンの原理**:
- `GET /%` : URLの1文字目にパーセントエンコードがある（典型的なXSS）
- `GET /.%` : 2文字目にパーセントエンコード（ディレクトリトラバーサルの変形）
- `GET /.=%` : `=` 後にパーセントエンコード（パラメータ操作）
- `nmap` / `nikto` : スキャナーのUser-Agentや特徴的なリクエスト文字列

カラー出力の閲覧には `bat` / `batcat` パッケージを使用する:

```bash
# Debian/Ubuntu系
sudo apt install bat
batcat xss_results.txt

# その他のディストリビューション
bat xss_results.txt
```

---

## 9. LinPEAS/Lynisによる自動監査

### 9.1 LinPEAS（権限昇格経路の検出）

LinPEAS（Linux Privilege Escalation Awesome Script）はシェルスクリプト形式のセキュリティ監査ツール:

```bash
# Kali Linuxの場合 /usr/share/peass/linpeas/ に収録
# スクリプト種別:
#   linpeas.sh      - 全チェック実行（推奨）
#   linpeas_fat.sh  - 追加サードパーティスクリプト含む（バグあり、非推奨）
#   linpeas_small.sh - 基本チェックのみ（高速・ステルス向け）

# 対象マシンにコピーして実行（sudo付きでより詳細な情報を取得）
sudo ./linpeas.sh | tee linpeas_report.txt

# 結果をカラー保持したまま閲覧
batcat linpeas_report.txt
```

**カラーコードの見方**:
- `RED/YELLOW`（赤文字+黄背景）: 95%確率で権限昇格可能な脆弱性
- `RED`（赤文字のみ）: 問題の可能性あり（要判断）

**LinPEASが検出する例**:
- 悪意ある `cron` ジョブ（バックドア）
- NFSの危険な設定（`no_root_squash`）
- SUID/SGIDビット付きファイル
- Exploit Suggesterによる既知脆弱性

### 9.2 Lynis（設定・コンプライアンス監査）

Lynis は Linux/Unix/macOS対応のセキュリティ監査スクリプト:

```bash
# ダウンロードと展開
tar xzvf lynis-3.x.x.tar.gz
cd lynis

# システム監査実行（カラー保持のためteeで出力）
sudo ./lynis audit system | tee ~/lynis_report.txt

# カラー保持したまま閲覧
batcat ~/lynis_report.txt

# カーネル設定の確認
sudo systemd-analyze cat-config sysctl.d
```

**Lynisの特徴**:
- `WARNING` / `SUGGESTION` ラベルで問題を分類
- カーネルパラメータの推奨値と現在値を比較
- 具体的な修正手順をプレーンテキストで提示
- Enterprise版はPCI-DSS/HIPAAコンプライアンス対応

### 9.3 LinPEAS vs Lynis 使い分け

| ツール | 強み | 弱み |
|--------|------|------|
| LinPEAS | 権限昇格経路の詳細検出（NFS・cronバックドア等） | 生データ中心、解釈が必要 |
| Lynis | 具体的な修正提案、コンプライアンス対応 | LinPEASが検出する細かい設定漏れを見落とすことも |

**結論: 両方を使用する**

---

## 10. ファイアウォール設定スクリプト

### 10.1 Linuxファイアウォールの構成

| コンポーネント | 役割 |
|--------------|------|
| `netfilter` | Linuxカーネル内蔵のパケットフィルタリングエンジン |
| `iptables` | 旧来のCLI（IPv4/IPv6を別デーモンで管理） |
| `nftables` | 現代的なCLI（IPv4/IPv6を一元管理、kernel 3.13以降） |
| `ufw` | Ubuntu向けフロントエンド（シンプルな構文） |
| `firewalld` | RHEL/SUSE向けフロントエンド（ゾーン・リッチルール） |

### 10.2 ufw スクリプト（Ubuntu）

**Webサーバー基本設定スクリプト**:

```bash
#!/bin/bash
# ufw-setup.sh: Webサーバー向けファイアウォール設定
# 注意: 管理者の固定IPアドレスに合わせてADMIN_IPを変更すること

ADMIN_IP="192.168.0.201"

# 管理者のIPからのSSHのみ許可（ログ有効）
ufw allow log from "${ADMIN_IP}" to any port 22 proto tcp

# ApacheのHTTP/HTTPSを全許可
ufw allow "Apache Full"

# --force オプションでプロンプトをスキップ（スクリプト自動化用）
ufw --force enable
ufw reload
ufw status verbose
```

**悪意あるIPブロックスクリプト**（`bad_ipaddresses.txt` からリスト読み込み）:

```bash
#!/bin/bash
# ufw-block.sh: IPブロックリストをufwに適用
# bad_ipaddresses.txt フォーマット: 1行1エントリ（IP or CIDR）

# prepend でブロックルールをALLOWルールより前に挿入
xargs -i ufw prepend deny from {} to any port 80,443 proto tcp < bad_ipaddresses.txt
ufw reload
```

**ufwルール構文のポイント**:
- シンプルルール: サービス名・appプロファイル・ポート番号のいずれかで指定
- 拡張構文（特定IP指定時）: ポート番号 + `proto` キーワードが必須
- `prepend` でブロックルールをリストの先頭に挿入（順序が重要）

### 10.3 firewalld スクリプト（RHEL/AlmaLinux）

**firewalldゾーンのターゲット**:

| ターゲット | 動作 |
|-----------|------|
| `default` | ICMPを除くすべてをブロック |
| `ACCEPT` | すべての接続を許可 |
| `DROP` | すべてをブロック（ソースへの通知なし） |
| `REJECT` | すべてをブロック（ソースに拒否通知） |

**Webサーバー基本設定スクリプト**:

```bash
#!/bin/bash
# firewalld-setup.sh: Webサーバー向けfirewalld設定
# ADMIN_IP を管理者の固定IPに変更すること

ADMIN_IP="192.168.0.201"

# デフォルトゾーンをdmzに変更（SSHのみ許可のシンプルなゾーン）
firewall-cmd --set-default-zone=dmz

# SSHの全体許可を削除して特定IPからのみ許可（リッチルール）
firewall-cmd --permanent --remove-service=ssh
firewall-cmd --permanent --add-rich-rule="rule family=ipv4 source address=\"${ADMIN_IP}\" service name=ssh accept"

# Cockpit（Webコンソール）も管理者IPからのみ許可
firewall-cmd --permanent --add-rich-rule="rule family=ipv4 source address=\"${ADMIN_IP}\" service name=cockpit accept"

# HTTP/HTTPSは全体に許可
firewall-cmd --permanent --add-service={http,https}

# --permanent ルールを有効化（--reloadが必要）
firewall-cmd --reload
```

**IPブロックリストスクリプト**（`firewalld` は自動的にブロックルールを優先順位付け）:

```bash
#!/bin/bash
# firewalld-block.sh: IPブロックリストをfirewalldに適用
# bad_ipaddresses.txt フォーマット: 1行1エントリ（IP or CIDR）

# リッチルールではサービスを個別に指定する必要あり
xargs -i firewall-cmd --permanent --add-rich-rule="rule family=\"ipv4\" source address={} service name=http drop" < bad_ipaddresses.txt
xargs -i firewall-cmd --permanent --add-rich-rule="rule family=\"ipv4\" source address={} service name=https drop" < bad_ipaddresses.txt
firewall-cmd --reload
```

**firewalldのポイント**:
- `--permanent` なしでは再起動時にルールが消える
- `--permanent` 後は必ず `--reload` が必要
- `firewalld` は自動的にブロックルールをALLOWルールより前に配置（順序を気にしなくてよい）
- リッチルールは1ルール1サービス制約（`ufw` と異なる）
