# Bashスクリプトのセキュリティ

Bashスクリプトのセキュリティベストプラクティスと脆弱性対策の包括的ガイド。

---

## 1. 入力サニタイゼーション

### 1.1 ユーザー入力の安全な受け取り

**`read -r` の使用**

```bash
# 悪い例: バックスラッシュエスケープが処理される
read user_input

# 良い例: raw入力として扱う
read -r user_input
```

**必ず `-r` オプションを使用する理由:**
- バックスラッシュエスケープシーケンスを無効化
- 予期しない文字列解釈を防止
- 入力をそのまま保持

### 1.2 変数展開の安全な使い方

**必ずダブルクォートで変数を囲む**

```bash
# 危険: ワード分割とグロブ展開が発生
cp $source_file $dest_dir

# 安全: 文字列として扱う
cp "$source_file" "$dest_dir"

# 複数変数も同様
echo "$var1" "$var2" "$var3"
```

**判断基準テーブル:**

| 状況 | クォート | 理由 |
|------|---------|------|
| 変数展開 | `"$var"` | ワード分割防止 |
| コマンド置換 | `"$(cmd)"` | スペース含む出力保護 |
| パス操作 | `"$file_path"` | スペース・特殊文字対策 |
| 配列全体 | `"${arr[@]}"` | 各要素を個別に保持 |
| 数値比較 | `"$num"` | 空文字列対策 |

### 1.3 ファイル名のサニタイズ

```bash
sanitize_filename() {
    local filename="$1"

    # 危険な文字を削除または置換
    filename="${filename//[^a-zA-Z0-9._-]/}"

    # 先頭のドット・ハイフンを削除（隠しファイル防止）
    filename="${filename#[.-]}"

    # 拡張子を検証
    case "$filename" in
        *.txt|*.log|*.dat) ;;
        *) filename="${filename}.txt" ;;
    esac

    echo "$filename"
}

# 使用例
user_filename="../../etc/passwd; rm -rf /"
safe_filename=$(sanitize_filename "$user_filename")
touch "$safe_filename"  # 安全に作成
```

### 1.4 入力バリデーションパターン

**数値検証**

```bash
validate_number() {
    local input="$1"

    # 正規表現で数値チェック
    if [[ "$input" =~ ^[0-9]+$ ]]; then
        return 0
    else
        echo "Error: Not a valid number" >&2
        return 1
    fi
}

# 範囲チェック付き
validate_port() {
    local port="$1"

    if [[ "$port" =~ ^[0-9]+$ ]] && (( port >= 1 && port <= 65535 )); then
        return 0
    else
        echo "Error: Port must be 1-65535" >&2
        return 1
    fi
}
```

**Email検証**

```bash
validate_email() {
    local email="$1"
    local pattern='^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'

    if [[ "$email" =~ $pattern ]]; then
        return 0
    else
        echo "Error: Invalid email format" >&2
        return 1
    fi
}
```

**URL検証**

```bash
validate_url() {
    local url="$1"
    local pattern='^https?://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(/.*)?$'

    if [[ "$url" =~ $pattern ]]; then
        return 0
    else
        echo "Error: Invalid URL format" >&2
        return 1
    fi
}
```

---

## 2. コマンドインジェクション防止

### 2.1 `eval` の危険性と代替手段

**eval は絶対に避ける**

```bash
# 極めて危険: コマンドインジェクション脆弱性
user_input="rm -rf /"
eval "$user_input"  # システム破壊

# 危険な例: ユーザー入力を eval に渡す
cmd="ls"
user_args="-la; cat /etc/passwd"
eval "$cmd $user_args"  # /etc/passwd が表示される
```

**代替手段: 配列を使用**

```bash
# 安全: 配列で引数を保持
cmd=(ls -la)
"${cmd[@]}"

# 動的コマンド構築
command_args=()
if [[ "$verbose" == "true" ]]; then
    command_args+=(-v)
fi
command_args+=("$target_file")

grep "${command_args[@]}"
```

**どうしても動的実行が必要な場合**

```bash
# ホワイトリスト方式で許可されたコマンドのみ実行
execute_safe_command() {
    local cmd="$1"
    shift

    case "$cmd" in
        list)   ls "$@" ;;
        show)   cat "$@" ;;
        count)  wc -l "$@" ;;
        *)
            echo "Error: Command not allowed" >&2
            return 1
            ;;
    esac
}

# 使用例
execute_safe_command "list" /var/log
execute_safe_command "show" data.txt
execute_safe_command "hack"  # エラー: 拒否される
```

### 2.2 変数のクォーティングによる保護

```bash
# 危険: クォート忘れ
file_name="user data.txt"
cat $file_name  # "user" と "data.txt" の2つのファイルとして解釈

# 安全: ダブルクォート
cat "$file_name"  # 1つのファイル名として正しく解釈

# さらに危険: コマンドインジェクション
malicious_input="file.txt; rm -rf /"
cat $malicious_input  # file.txt表示後、システム削除

# 安全: クォートで無害化
cat "$malicious_input"  # "file.txt; rm -rf /" というファイル名として扱う（存在しないのでエラー）
```

### 2.3 `printf '%q'` によるシェルエスケープ

```bash
# 文字列を安全にクォート
safe_quote() {
    printf '%q' "$1"
}

# 使用例
user_input="'; rm -rf /"
safe_input=$(safe_quote "$user_input")
echo "Escaped: $safe_input"
# 出力: Escaped: \'\;\ rm\ -rf\ /

# ログ記録に使用
log_command() {
    local cmd="$1"
    shift
    printf 'Executing: %s' "$cmd"
    for arg in "$@"; do
        printf ' %q' "$arg"
    done
    printf '\n'
}

log_command "grep" "search term" "/path/to/file"
```

### 2.4 間接実行の安全パターン

```bash
# 危険: 文字列からコマンド実行
command_string="ls -la /tmp"
eval "$command_string"  # 危険

# 安全: 配列 + 関数
safe_execute() {
    local -a cmd=("$@")

    # コマンドの検証
    if ! command -v "${cmd[0]}" &>/dev/null; then
        echo "Error: Command not found: ${cmd[0]}" >&2
        return 127
    fi

    # 実行（evalを使わない）
    "${cmd[@]}"
}

# 使用例
safe_execute ls -la /tmp
```

---

## 3. 認証情報・シークレット管理

### 3.1 環境変数での管理

```bash
# 悪い例: スクリプト内にハードコード
API_KEY="sk-1234567890abcdef"
curl -H "Authorization: Bearer $API_KEY" https://api.example.com

# 良い例: 環境変数から読み込み
#!/usr/bin/env bash

if [[ -z "$API_KEY" ]]; then
    echo "Error: API_KEY environment variable not set" >&2
    exit 1
fi

curl -H "Authorization: Bearer $API_KEY" https://api.example.com
```

**環境変数の設定方法**

```bash
# シェルセッションで一時的に設定
export API_KEY="sk-1234567890abcdef"
./script.sh

# 1コマンドだけ有効
API_KEY="sk-..." ./script.sh

# systemdサービスの場合
# /etc/systemd/system/myservice.service
[Service]
Environment="API_KEY=sk-..."
EnvironmentFile=/etc/default/myservice
```

### 3.2 .env ファイルのセキュアな読み込み

```bash
load_env_file() {
    local env_file="${1:-.env}"

    # ファイル存在チェック
    if [[ ! -f "$env_file" ]]; then
        echo "Error: $env_file not found" >&2
        return 1
    fi

    # パーミッションチェック（600 or 400推奨）
    local perms
    perms=$(stat -c '%a' "$env_file" 2>/dev/null || stat -f '%A' "$env_file")
    if [[ "$perms" != "600" && "$perms" != "400" ]]; then
        echo "Warning: $env_file has insecure permissions ($perms)" >&2
    fi

    # 安全に読み込み
    while IFS='=' read -r key value; do
        # コメント・空行をスキップ
        [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue

        # キー名の検証（英数字とアンダースコアのみ）
        if [[ ! "$key" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
            echo "Warning: Invalid key name: $key" >&2
            continue
        fi

        # クォートを除去
        value="${value%\"}"
        value="${value#\"}"
        value="${value%\'}"
        value="${value#\'}"

        # エクスポート
        export "$key=$value"
    done < "$env_file"
}

# 使用例
load_env_file ".env.production"
```

**.env ファイル例**

```bash
# .env
DATABASE_URL="postgresql://user:pass@localhost/db"
API_KEY="sk-1234567890abcdef"
SECRET_TOKEN="xyz789"
```

**.gitignore に追加**

```bash
# .gitignore
.env
.env.*
!.env.example
```

### 3.3 パスワードのインタラクティブ入力

```bash
# read -s で入力を隠す
read_password() {
    local prompt="${1:-Password: }"
    local password

    # エコーバック無効化
    read -r -s -p "$prompt" password
    echo  # 改行

    # パスワードが空でないか確認
    if [[ -z "$password" ]]; then
        echo "Error: Password cannot be empty" >&2
        return 1
    fi

    echo "$password"
}

# 使用例
db_password=$(read_password "Enter database password: ")
if [[ $? -eq 0 ]]; then
    mysql -u user -p"$db_password" database
fi

# パスワード確認
read_password_confirm() {
    local password1 password2

    password1=$(read_password "Enter password: ")
    password2=$(read_password "Confirm password: ")

    if [[ "$password1" != "$password2" ]]; then
        echo "Error: Passwords do not match" >&2
        return 1
    fi

    echo "$password1"
}
```

### 3.4 一時ファイルでの秘密情報の扱い

```bash
# 悪い例: 通常のファイルに書き込み
echo "$SECRET_KEY" > /tmp/secret.txt
process_secret /tmp/secret.txt
rm /tmp/secret.txt  # 削除前に他ユーザーが読める

# 良い例: セキュアな一時ファイル作成
create_secure_temp() {
    local tmpfile
    tmpfile=$(mktemp)

    # パーミッション厳格化（所有者のみ読み書き）
    chmod 600 "$tmpfile"

    # クリーンアップトラップ設定
    trap "rm -f '$tmpfile'" EXIT INT TERM

    echo "$tmpfile"
}

# 使用例
secret_file=$(create_secure_temp)
echo "$SECRET_KEY" > "$secret_file"
process_secret "$secret_file"
# EXIT時に自動削除
```

### 3.5 Gitから機密情報を除外するパターン

```bash
# .gitignore
*.key
*.pem
*.p12
*.pfx
*_rsa
*_dsa
*_ecdsa
*_ed25519
.env
.env.*
!.env.example
secrets/
config/database.yml
config/credentials.yml
```

---

## 4. 最小権限原則・sudo自動化

### 4.1 `sudo` の安全な使い方

```bash
# 悪い例: スクリプト全体をrootで実行
#!/bin/bash
# このスクリプトは root で実行される
sudo ./entire_script.sh

# 良い例: 必要な部分だけ sudo
#!/bin/bash
# 通常ユーザーで実行開始
echo "Preparing..."

# 特定コマンドのみ権限昇格
sudo systemctl restart nginx

# 再び通常権限で継続
echo "Done"
```

### 4.2 sudoers 設定のベストプラクティス

```bash
# /etc/sudoers.d/deploy-user (visudo で編集)

# 特定コマンドのみ許可（パスワード不要）
deploy ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart myapp
deploy ALL=(ALL) NOPASSWD: /usr/bin/systemctl status myapp

# 複数コマンドをエイリアスで管理
Cmnd_Alias DEPLOYMENT_CMDS = /usr/bin/systemctl restart myapp, \
                              /usr/bin/systemctl reload myapp, \
                              /usr/bin/systemctl status myapp
deploy ALL=(ALL) NOPASSWD: DEPLOYMENT_CMDS

# ワイルドカード禁止（セキュリティリスク）
# 悪い例
deploy ALL=(ALL) NOPASSWD: /usr/bin/*

# 良い例: 明示的にコマンド指定
deploy ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart myapp
```

### 4.3 権限の一時的な昇格パターン

```bash
# sudo セッションキャッシュを利用
elevate_privileges() {
    # 最初に認証（15分間有効）
    sudo -v

    # バックグラウンドでタイムスタンプ更新
    while true; do
        sudo -v
        sleep 60
    done &
    local sudo_refresh_pid=$!

    # クリーンアップ
    trap "kill $sudo_refresh_pid 2>/dev/null" EXIT
}

# 使用例
elevate_privileges

# 以降、sudo コマンドはパスワード不要
sudo command1
sudo command2
```

### 4.4 `runuser` / `su -c` の活用

```bash
# root権限スクリプトから特定ユーザーでコマンド実行
if [[ $EUID -eq 0 ]]; then
    # runuser でユーザー切り替え（PAM不使用、高速）
    runuser -u appuser -- /usr/bin/app-command

    # su -c でも可能（PAM使用）
    su -c '/usr/bin/app-command' appuser
else
    echo "This script must be run as root" >&2
    exit 1
fi

# 環境変数を引き継ぐ
runuser -u appuser -g appgroup -G supplementary-groups \
    -m --preserve-environment=PATH,HOME \
    -- /usr/bin/app-command
```

---

## 関連ガイド

システム堅牢化とセキュリティ強化の詳細については以下を参照:

- **[HARDENING.md](./HARDENING.md)** - TOCTOU競合回避、ファイルパーミッション設定、一時ファイル管理、攻撃面最小化
