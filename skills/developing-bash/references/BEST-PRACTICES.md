# Bashスクリプトのベストプラクティス集

プロフェッショナルなBashスクリプト作成のためのベストプラクティス、命名規則、品質管理。

---


### 3.1 Strict Mode の適用

```bash
#!/usr/bin/env bash

# Strict mode (常に設定すべき)
set -euo pipefail
IFS=$'\n\t'

# 説明:
# -e : コマンド失敗時に即座に終了
# -u : 未定義変数使用時にエラー
# -o pipefail : パイプライン内の失敗を検出
# IFS : 安全なフィールド区切り設定
```

**個別オプションの使い分け:**

```bash
# 一部のコマンドでエラーを許容
command_that_may_fail || true

# サブシェルで一時的に無効化
(
    set +e
    command_that_may_fail
    echo "Continuing regardless of failure"
)

# 再び strict mode
command_that_must_succeed
```

### 3.2 エラーハンドリングの標準パターン

**基本パターン:**

```bash
#!/usr/bin/env bash
set -euo pipefail

# エラーハンドラー
error_exit() {
    local exit_code="${1:-1}"
    local message="${2:-An error occurred}"

    echo "ERROR: $message" >&2
    exit "$exit_code"
}

# 使用例
[[ -f "config.txt" ]] || error_exit 2 "Config file not found"

# 条件付きエラー
if ! process_data; then
    error_exit 3 "Data processing failed"
fi
```

**try-catch 相当の実装:**

```bash
try() {
    local exit_code=0
    "$@" || exit_code=$?

    if (( exit_code != 0 )); then
        return $exit_code
    fi
}

catch() {
    local exit_code=$?

    if (( exit_code != 0 )); then
        "$@" "$exit_code"
    fi
}

# 使用例
try risky_command || catch handle_error
```

**trap ERR パターン:**

```bash
#!/usr/bin/env bash
set -eEuo pipefail  # -E: ERR トラップをサブシェルに継承

error_handler() {
    local exit_code=$?
    local line_number=$1

    echo "Error occurred in script at line $line_number (exit code: $exit_code)" >&2
    # スタックトレース風表示
    for ((i=0; i<${#FUNCNAME[@]}; i++)); do
        echo "  at ${FUNCNAME[$i]} (${BASH_SOURCE[$i]}:${BASH_LINENO[$i-1]})" >&2
    done
    exit "$exit_code"
}

trap 'error_handler ${LINENO}' ERR

# メイン処理
risky_operation
another_risky_operation
```

### 3.3 ログ出力の標準化

**ログレベル付きロギング**

```bash
# ログレベル定義
declare -A LOG_LEVELS=(
    [DEBUG]=0
    [INFO]=1
    [WARN]=2
    [ERROR]=3
)

LOG_LEVEL="${LOG_LEVEL:-INFO}"

log() {
    local level="$1"
    shift

    # レベルチェック
    if (( LOG_LEVELS[$level] < LOG_LEVELS[$LOG_LEVEL] )); then
        return 0
    fi

    # タイムスタンプ付きログ
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # レベルに応じて出力先変更
    case "$level" in
        ERROR)
            echo "[$timestamp] $level: $*" >&2
            ;;
        *)
            echo "[$timestamp] $level: $*"
            ;;
    esac
}

# 使用例
log DEBUG "Starting process"
log INFO "Processing file: $filename"
log WARN "Cache miss, fetching from network"
log ERROR "Failed to connect to database"

# 環境変数でログレベル変更
LOG_LEVEL=DEBUG ./script.sh
```

**構造化ログ（JSON形式）**

```bash
log_json() {
    local level="$1"
    local message="$2"
    shift 2

    # 追加フィールド（key=value形式）
    local extra_fields=""
    for arg in "$@"; do
        extra_fields+=", \"${arg%%=*}\": \"${arg#*=}\""
    done

    # JSON出力
    printf '{"timestamp":"%s","level":"%s","message":"%s"%s}\n' \
        "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
        "$level" \
        "$message" \
        "$extra_fields"
}

# 使用例
log_json INFO "User logged in" "user=john" "ip=192.168.1.10"
log_json ERROR "Database connection failed" "host=db.example.com" "port=5432"
```

### 3.4 命名規則

**変数命名**

```bash
# 定数: 大文字スネークケース
readonly MAX_RETRIES=3
readonly DATABASE_URL="postgresql://localhost/db"

# グローバル変数: 大文字スネークケース（readonly推奨）
CONFIG_FILE="/etc/myapp/config.conf"

# ローカル変数: 小文字スネークケース
local user_name="john"
local file_count=0

# 環境変数: 大文字スネークケース
export PATH="/usr/local/bin:$PATH"
export LOG_LEVEL="INFO"

# 配列: 小文字スネークケース + 複数形
local file_names=("a.txt" "b.txt" "c.txt")

# 連想配列: 小文字スネークケース
declare -A user_data=(
    [name]="John"
    [age]="30"
)
```

**関数命名**

```bash
# 動詞 + 名詞（スネークケース）
get_user_name() { ... }
set_config_value() { ... }
validate_email() { ... }
process_data() { ... }

# 真偽値を返す関数: is/has/can プレフィックス
is_valid_email() { ... }
has_permission() { ... }
can_access_file() { ... }

# プライベート関数: _ プレフィックス
_internal_helper() { ... }
```

**ファイル命名**

```bash
# 小文字ハイフン区切り
# user-management.sh
# database-backup.sh
# api-client.sh

# ライブラリファイル: lib- プレフィックス
# lib-logging.sh
# lib-config.sh
# lib-utils.sh
```

### 3.5 コメントの書き方

**関数ドキュメント**

```bash
# ユーザー情報を取得する
#
# 引数:
#   $1 - ユーザーID
# 戻り値:
#   0 - 成功
#   1 - ユーザーが見つからない
# 出力:
#   ユーザー名を標準出力に書き出す
get_user_name() {
    local user_id="$1"

    # データベースからユーザー名取得
    local user_name
    user_name=$(psql -c "SELECT name FROM users WHERE id = $user_id")

    if [[ -z "$user_name" ]]; then
        echo "User not found" >&2
        return 1
    fi

    echo "$user_name"
}
```

**セクション分割コメント**

```bash
#!/usr/bin/env bash
# スクリプト概要: データベースバックアップスクリプト
# 使用法: ./backup.sh [database_name]

set -euo pipefail

# ====================================================================
# 設定
# ====================================================================

readonly BACKUP_DIR="/var/backups/db"
readonly MAX_BACKUPS=7

# ====================================================================
# ヘルパー関数
# ====================================================================

log_info() { ... }
error_exit() { ... }

# ====================================================================
# メイン処理
# ====================================================================

main() {
    # バックアップディレクトリ作成
    mkdir -p "$BACKUP_DIR"

    # データベースダンプ
    # ...
}

main "$@"
```

**TODO/FIXME/HACK コメント**

```bash
# TODO: エラーハンドリングを改善する
process_data() {
    # FIXME: この実装は非効率（O(n^2)）
    for item in "${items[@]}"; do
        for other in "${items[@]}"; do
            compare "$item" "$other"
        done
    done

    # HACK: 一時的な回避策（次のリリースで修正予定）
    sleep 1  # API rate limit対策
}
```

### 3.6 ShellCheck 準拠

**ShellCheck導入**

```bash
# インストール
# Ubuntu/Debian
sudo apt install shellcheck

# macOS
brew install shellcheck

# 実行
shellcheck script.sh

# CI/CDパイプラインに組み込み
# .gitlab-ci.yml / .github/workflows/ci.yml
shellcheck:
  script:
    - shellcheck **/*.sh
```

**よくある警告と修正**

```bash
# SC2086: クォート忘れ
# ❌ Bad
cat $file

# ✅ Good
cat "$file"

# SC2046: コマンド置換のクォート忘れ
# ❌ Bad
for file in $(ls); do

# ✅ Good
for file in *; do

# SC2181: $? の直接チェック
# ❌ Bad
command
if [ $? -eq 0 ]; then

# ✅ Good
if command; then

# SC2155: declare + コマンド置換
# ❌ Bad
local result=$(command)

# ✅ Good
local result
result=$(command)
```

---

## 次のステップ

以下の関連ドキュメントも参照してください：

- [CLI-TOOLS.md](./CLI-TOOLS.md): CLIツール構築・API連携・インタラクティブスクリプト
- [CONTROL-FLOW.md](./CONTROL-FLOW.md): 制御フロー・条件文・ループ・算術演算
- [FUNCTIONS.md](./FUNCTIONS.md): 関数・モジュール化・引数処理
