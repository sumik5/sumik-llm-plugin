# 関数・モジュール化・引数処理

関数の定義と活用、コードのモジュール化、コマンドライン引数処理の実装パターン。

---

## 1. 関数

### 1.1 定義と引数

```bash
# POSIX互換（推奨）
greet() { echo "Hello, $1!"; }

# 引数アクセス: $1, $2, ..., $@, $#, $FUNCNAME
print_args() {
  echo "Function: $FUNCNAME, Args: $#, All: $@"
}
```

### 1.2 戻り値（return vs stdout）

```bash
# return: 終了ステータス（0-255）
is_even() { (( $1 % 2 == 0 )); }
is_even 4 && echo "Even"

# stdout: 文字列返却
get_user() { echo "admin"; }
user=$(get_user)

# 両方使用: stdout + return
divide() {
  [[ $2 -eq 0 ]] && { echo "Div by zero" >&2; return 1; }
  echo $(($1 / $2))
}
result=$(divide 10 2) && echo "Result: $result"
```

### 1.3 local変数（グローバル汚染回避）

```bash
# ❌ グローバル変数を変更
counter=10
increment() { counter=$((counter + 1)); }
increment; echo $counter  # 11（予期しない変更）

# ✅ localで分離
increment() { local c=$1; echo $((c + 1)); }
result=$(increment $counter)
echo "Global: $counter, Result: $result"  # 10, 11
```

### 1.4 nameref（参照渡し、Bash 4.3+）

```bash
# 配列の参照渡し
modify_array() {
  local -n arr=$1
  arr+=("new")
}
my_array=("a" "b")
modify_array my_array  # my_array が変更される

# 複数の戻り値
parse_name() {
  local -n first=$1 last=$2
  first="${3%% *}"; last="${3##* }"
}
parse_name f l "John Doe"
echo "$f $l"  # John Doe
```

### 1.5 再帰関数

```bash
factorial() {
  local n=$1
  (( n <= 1 )) && echo 1 || echo $((n * $(factorial $((n-1)))))
}
echo "5! = $(factorial 5)"  # 120
```

---

## 2. モジュール化

```bash
# lib.sh
[[ -n ${__LIB__} ]] && return  # 多重読み込み防止
readonly __LIB__=1

log() { echo "[$(date '+%H:%M:%S')] $1"; }

# main.sh
source ./lib.sh
log "Started"

# 名前空間パターン
mylib::init() { echo "Init v${mylib::version}"; }
mylib::version="1.0"
mylib::init
```

---

## 3. コマンドライン引数処理

```bash
# 基本アクセス: $0, $1, $2, $@, $#
echo "$0: $# args: $@"

# getopts（短いオプション）
while getopts "vf:o:h" opt; do
  case $opt in
    v) verbose=true ;;
    f) file=$OPTARG ;;
    h) usage; exit 0 ;;
    \?) exit 1 ;;
  esac
done
shift $((OPTIND - 1))

# getopt（長いオプション対応）
opts=$(getopt -o vf: --long verbose,file: -n "$0" -- "$@") || exit 1
eval set -- "$opts"
while true; do
  case "$1" in
    -v|--verbose) verbose=true; shift ;;
    -f|--file) file=$2; shift 2 ;;
    --) shift; break ;;
  esac
done

# 手動パース（長いオプション）
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help) usage; exit 0 ;;
    -v|--verbose) verbose=true; shift ;;
    -c|--config) config=$2; shift 2 ;;
    --) shift; break ;;
    -*) echo "Unknown: $1" >&2; exit 1 ;;
    *) break ;;
  esac
done
```

---

## まとめ

このドキュメントでは、関数の定義と活用、コードのモジュール化、コマンドライン引数処理の実装パターンを解説しました。

### チェックリスト

- [ ] 関数で local 変数を使い、名前空間を分離している
- [ ] 戻り値（return vs stdout）の使い分けを理解している
- [ ] nameref で参照渡しを活用している
- [ ] source でライブラリを読み込み、コードを再利用している
- [ ] 多重読み込み防止パターンを実装している
- [ ] getopts または getopt で引数を解析している
- [ ] usage 関数でヘルプメッセージを提供している

### 関連ドキュメント

- [CONTROL-FLOW.md](./CONTROL-FLOW.md): 制御フロー・条件文・ループ・算術演算
- [PATTERNS.md](./PATTERNS.md): デザインパターン・アンチパターン・ベストプラクティス集
- [CLI-TOOLS.md](./CLI-TOOLS.md): CLIツール構築・API連携・インタラクティブスクリプト
