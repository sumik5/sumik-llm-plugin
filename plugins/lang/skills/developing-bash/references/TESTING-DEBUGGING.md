# テスト・デバッグ

## ShellCheck（静的解析）

```bash
# インストール
sudo apt-get install shellcheck  # Ubuntu/Debian
brew install shellcheck          # macOS

# チェック実行
shellcheck script.sh
shellcheck -S error script.sh    # 重要度フィルタ
```

### よく検出されるエラーと修正

| エラー | 悪い例 | 良い例 |
|--------|--------|--------|
| SC2086 引用符なし変数展開 | `cp $file $dest` | `cp "$file" "$dest"` |
| SC2046 コマンド置換の引用符なし | `for file in $(ls *.txt)` | `for file in *.txt` |
| SC2006 古いスタイル | ``result=`cmd` `` | `result=$(cmd)` |
| SC2155 宣言と代入の分離 | `local result=$(cmd)` | `local result; result=$(cmd)` |

### CI/CD統合

```yaml
# GitHub Actions
name: ShellCheck
on: [push, pull_request]
jobs:
  shellcheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: ludeeus/action-shellcheck@master
```

### エラー抑制

```bash
# shellcheck disable=SC2034
unused_var="value"
```

---

## BATS（Bash Automated Testing System）

```bash
# インストール
npm install -g bats
git clone https://github.com/bats-core/bats-support.git test/test_helper/bats-support
git clone https://github.com/bats-core/bats-assert.git test/test_helper/bats-assert
```

### テストファイル構造

```bash
#!/usr/bin/env bats

setup() { TEST_TEMP_DIR="$(mktemp -d)"; }
teardown() { rm -rf "$TEST_TEMP_DIR"; }

@test "addition works" {
    result=$(( 2 + 2 ))
    [ "$result" -eq 4 ]
}
```

### アサーション

```bash
#!/usr/bin/env bats
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

@test "assert examples" {
    run echo "hello"
    assert_success
    assert_output "hello"
    assert_output --regexp "^hello"
}
```

### テスト実行

```bash
bats test/              # 全テスト実行
bats -j 4 test/         # 並列実行
bats -f "pattern" test/ # フィルタ
```

---

## テスト手法

### ユニットテスト

```bash
# src/calculator.sh
add() { echo $(( $1 + $2 )); }

# test/calculator.bats
#!/usr/bin/env bats
load '../src/calculator.sh'

@test "add: 2 + 2 = 4" {
    result=$(add 2 2)
    [ "$result" -eq 4 ]
}
```

### 統合テスト

```bash
# script.sh
#!/bin/bash
set -euo pipefail

main() {
    [[ ! -f "$1" ]] && { echo "Config not found" >&2; return 1; }
    source "$1"
    echo "Processing: $DATABASE_URL"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then main "$@"; fi

# test/integration.bats
@test "valid config" {
    echo 'DATABASE_URL="postgres://localhost/test"' > "$TEST_TEMP_DIR/config"
    run ./script.sh "$TEST_TEMP_DIR/config"
    assert_success
}
```

### モック（テストダブル）

```bash
#!/usr/bin/env bats

# 関数モック
setup() {
    curl() { echo '{"status":"ok"}'; }
    export -f curl
}

# コマンドモック
@test "mocked command" {
    mkdir -p "$TEST_TEMP_DIR/bin"
    echo '#!/bin/bash\necho "Mocked"' > "$TEST_TEMP_DIR/bin/git"
    chmod +x "$TEST_TEMP_DIR/bin/git"
    PATH="$TEST_TEMP_DIR/bin:$PATH"
    run ./script.sh
}
```

### テスト可能な設計

```bash
#!/bin/bash
set -euo pipefail

validate_input() { [[ -n "$1" ]] || return 1; }
process_data() { echo "Processing: $1"; }

main() {
    validate_input "$1" || { echo "Invalid" >&2; return 1; }
    process_data "$1"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then main "$@"; fi
```

---

## デバッグ技法

### set -x / PS4 カスタマイズ

```bash
#!/bin/bash

# 基本トレース
set -x
echo "traced"
set +x

# PS4カスタマイズ
export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
set -x
some_function
set +x
```

### trap DEBUG によるステップ実行

```bash
#!/bin/bash
trap 'read -p "Debug: $BASH_COMMAND" _' DEBUG
echo "Step 1"
result=$(( 2 + 2 ))
trap - DEBUG
```

### bashdb

```bash
sudo apt-get install bashdb
bashdb script.sh
# コマンド: n(次), s(ステップイン), c(続行), l(表示), p $var, b 10, q
```

### BASH_XTRACEFD

```bash
#!/bin/bash
exec {BASH_XTRACEFD}> trace.log
set -x
echo "stdout"
```

### よくあるバグパターン

| パターン | 悪い例 | 良い例 |
|---------|--------|--------|
| 空白ファイル名 | `for file in $(ls *.txt)` | `for file in *.txt` |
| 未初期化変数 | `echo $var` | `set -u; value="${var:-default}"` |
| パイプラインエラー | `cmd1 \| cmd2` | `set -o pipefail; cmd1 \| cmd2` |

---

## プロファイリング・パフォーマンス

```bash
# time コマンド
time ./script.sh
/usr/bin/time -v ./script.sh

# タイムスタンプトレース
export PS4='[$(date "+%H:%M:%S.%N")] '
set -x
echo "op1"
set +x
```

### 最適化テクニック

```bash
# ❌ 遅い: 外部コマンド
for i in {1..1000}; do result=$(date +%s); done

# ✅ 速い: ビルトイン
for i in {1..1000}; do result=$SECONDS; done

# ❌ 遅い: 複数パイプ
cat file | grep pattern | sed 's/old/new/' | awk '{print $1}'

# ✅ 速い: 1コマンド
awk '/pattern/ {gsub(/old/, "new"); print $1}' file

# 並列処理
parallel process ::: *.txt
find . -name "*.txt" | xargs -P 4 -I {} process {}
```

---

## モッキング・DI

```bash
# 関数オーバーライド
fetch_data() { curl -s "https://api.example.com/data"; }
process_data() { echo "Processing: $(fetch_data)"; }

# テスト
source ./api_client.sh
fetch_data() { echo '{"status":"ok"}'; }

@test "mocked API" {
    run process_data
    assert_output --partial "ok"
}
```

```bash
# PATH操作
setup() {
    MOCK_DIR="$(mktemp -d)"
    echo '#!/bin/bash\necho "Mocked"' > "$MOCK_DIR/aws"
    chmod +x "$MOCK_DIR/aws"
    export OLD_PATH="$PATH"
    export PATH="$MOCK_DIR:$PATH"
}

teardown() {
    export PATH="$OLD_PATH"
    rm -rf "$MOCK_DIR"
}
```

```bash
# 環境変数DI
DATABASE_URL="${DATABASE_URL:-postgres://localhost/prod}"

@test "test DB" {
    DATABASE_URL="postgres://localhost/test" run ./script.sh
    assert_output --partial "test"
}
```

---

## CI/CDパイプライン統合

### GitHub Actions

```yaml
name: Bash Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install Bats
        run: |
          git clone https://github.com/bats-core/bats-core.git
          cd bats-core && sudo ./install.sh /usr/local
      - name: Install helpers
        run: |
          git clone https://github.com/bats-core/bats-support.git test/test_helper/bats-support
          git clone https://github.com/bats-core/bats-assert.git test/test_helper/bats-assert
      - uses: ludeeus/action-shellcheck@master
      - run: bats test/
```

### GitLab CI

```yaml
stages:
  - lint
  - test

shellcheck:
  stage: lint
  image: koalaman/shellcheck-alpine:stable
  script: shellcheck -f gcc src/**/*.sh

bats_test:
  stage: test
  image: bats/bats:latest
  before_script:
    - apk add --no-cache bash git
    - git clone https://github.com/bats-core/bats-support.git test/test_helper/bats-support
    - git clone https://github.com/bats-core/bats-assert.git test/test_helper/bats-assert
  script: bats test/
```

---

## カバレッジ・ログ・トレーサビリティ

```bash
# bashcov
gem install bashcov
bashcov bats test/  # HTMLレポート生成（coverage/）
```

### 構造化ログ

```bash
#!/bin/bash

# JSON構造化ログ
log_json() {
    local level="$1" message="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
    echo "{\"timestamp\":\"$timestamp\",\"level\":\"$level\",\"message\":\"$message\",\"script\":\"${BASH_SOURCE[1]}\",\"line\":${BASH_LINENO[0]}}"
}

log_json "INFO" "Starting"

# syslog統合
log_syslog() { logger -t "$(basename "$0")" -p "user.$1" "$2"; }
```

### エラートレーサビリティ

```bash
#!/bin/bash
set -euo pipefail

print_trace() {
    local frame=0
    echo "Traceback:" >&2
    while caller $frame >&2; do ((frame++)); done
}

trap 'print_trace' ERR
```

### スタックトレース

```bash
#!/bin/bash
set -euo pipefail

error_handler() {
    local exit_code=$? line_no=$1
    echo "Error in ${BASH_SOURCE[1]} at line $line_no (exit: $exit_code)" >&2
    local i=0
    while caller $i; do ((i++)); done | awk '{print "  " $2 " (" $3 ":" $1 ")"}'
    exit "$exit_code"
}

trap 'error_handler ${LINENO}' ERR
```

### ログレベル

```bash
#!/bin/bash

readonly LOG_LEVEL_DEBUG=0 LOG_LEVEL_INFO=1 LOG_LEVEL_WARNING=2 LOG_LEVEL_ERROR=3
CURRENT_LOG_LEVEL="${LOG_LEVEL:-$LOG_LEVEL_INFO}"

log() {
    local level=$1 message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    if [[ $level -ge $CURRENT_LOG_LEVEL ]]; then
        case $level in
            $LOG_LEVEL_DEBUG) echo "[$timestamp] [DEBUG] $message" ;;
            $LOG_LEVEL_INFO) echo "[$timestamp] [INFO] $message" ;;
            $LOG_LEVEL_WARNING) echo "[$timestamp] [WARNING] $message" >&2 ;;
            $LOG_LEVEL_ERROR) echo "[$timestamp] [ERROR] $message" >&2 ;;
        esac
    fi
}

log $LOG_LEVEL_INFO "Started"
```

---

## 品質ゲート

### pre-commit フック

```bash
#!/bin/bash
echo "Running pre-commit checks..."

if ! shellcheck src/**/*.sh; then
    echo "ShellCheck failed" >&2
    exit 1
fi

if ! bats test/; then
    echo "Tests failed" >&2
    exit 1
fi

echo "All checks passed"
```

### 品質ゲートスクリプト

```bash
#!/bin/bash
set -euo pipefail

shellcheck -S error src/**/*.sh || { echo "ShellCheck failed" >&2; exit 1; }
bats test/ || { echo "Tests failed" >&2; exit 1; }

bashcov bats test/
coverage=$(jq '.metrics.covered_percent' coverage/.resultset.json)

if (( $(echo "$coverage < 80" | bc -l) )); then
    echo "Coverage $coverage% below threshold" >&2
    exit 1
fi

echo "All gates passed (Coverage: $coverage%)"
```

### テストピラミッド

```
        /\
       /  \        E2E Tests (少ない)
      /----\
     /      \      Integration Tests (中程度)
    /--------\
   /          \    Unit Tests (多い)
  /------------\
```

### 境界値テスト

```bash
#!/usr/bin/env bats

@test "validate_port: minimum (1)" { run validate_port 1; assert_success; }
@test "validate_port: maximum (65535)" { run validate_port 65535; assert_success; }
@test "validate_port: rejects 0" { run validate_port 0; assert_failure; }
@test "validate_port: rejects negative" { run validate_port -1; assert_failure; }
@test "validate_port: rejects non-numeric" { run validate_port "abc"; assert_failure; }
```
