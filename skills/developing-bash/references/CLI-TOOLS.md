# CLIツール構築・API連携・インタラクティブスクリプト

プロフェッショナルなCLIツールの構築、API連携パターン、インタラクティブスクリプトの実装。

---

## 1. CLIツール構築

### 1.1 引数パース

**手動パース（長いオプション対応）**

```bash
#!/usr/bin/env bash

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        -v|--verbose) VERBOSE=true; shift ;;
        -o|--output) OUTPUT="$2"; shift 2 ;;
        --) shift; break ;;
        -*) echo "Unknown option: $1" >&2; exit 1 ;;
        *) break ;;
    esac
done
ARGS=("$@")
```

**getopts（短いオプションのみ、POSIX互換）**

```bash
while getopts "hvo:n:" opt; do
    case "$opt" in
        h) usage; exit 0 ;;
        v) VERBOSE=true ;;
        o) OUTPUT="$OPTARG" ;;
        \?) exit 1 ;;
    esac
done
shift $((OPTIND - 1))
```

### 1.2 カラー出力（ターミナル検出付き）

```bash
# tput でポータブルなカラー設定
if [[ -t 1 ]]; then
    C_RED=$(tput setaf 1)
    C_GREEN=$(tput setaf 2)
    C_YELLOW=$(tput setaf 3)
    C_RESET=$(tput sgr0)
else
    C_RED="" C_GREEN="" C_YELLOW="" C_RESET=""
fi

# ログレベル別カラー
log() {
    case "$1" in
        ERROR) echo "${C_RED}[ERROR]${C_RESET} ${*:2}" >&2 ;;
        WARN)  echo "${C_YELLOW}[WARN]${C_RESET} ${*:2}" ;;
        *)     echo "[INFO] ${*:2}" ;;
    esac
}
```

### 1.3 プログレスバー・スピナー

```bash
# プログレスバー
progress() {
    local c=$1 t=$2 w=50
    local p=$((c*100/t)) f=$((c*w/t))
    printf '\r[%-*s] %d%%' "$w" "$(printf '#%.0s' $(seq 1 $f))" "$p"
    [[ $c -eq $t ]] && echo
}

# スピナー（バックグラウンドプロセス監視）
spinner() {
    local pid=$! spin='-\|/' i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf '\r[%s] Processing...' "${spin:$i:1}"
        i=$(((i+1)%4)); sleep 0.1
    done
    printf '\r[✓] Done!\n'
}
```

### 1.4 設定ファイル読み込み（INIパース）

```bash
parse_ini() {
    local section=""
    while IFS='=' read -r key value; do
        [[ -z "$key" || "$key" =~ ^# ]] && continue
        if [[ "$key" =~ ^\[(.*)\]$ ]]; then
            section="${BASH_REMATCH[1]}"
        else
            eval "${section}_$(echo $key | xargs)=\"$(echo $value | xargs)\""
        fi
    done < "$1"
}
```

---

## 2. API連携（リトライ・認証・エラーハンドリング）

```bash
# curlラッパー: タイムアウト・リトライ・認証
api_call() {
    local method=$1 endpoint=$2 data=${3:-}
    [[ -z ${API_KEY:-} ]] && { echo "API_KEY not set" >&2; return 1; }

    curl -sSf --max-time 30 --retry 3 \
        -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type: application/json" \
        ${data:+-d "$data"} \
        -X "$method" "https://api.example.com$endpoint"
}
```

### 2.2 JSON処理（jqエラーハンドリング）

```bash
# JSON検証+エラー抽出+データ取得
process_json() {
    local json="$1"
    jq empty <<< "$json" 2>/dev/null || { echo "Invalid JSON" >&2; return 1; }
    local err=$(jq -r '.error // empty' <<< "$json")
    [[ -n "$err" ]] && { echo "API error: $err" >&2; return 1; }
    jq -r '.data' <<< "$json"
}

# 使用例
response=$(curl -s https://api.example.com/data)
process_json "$response" || exit 1
```

---

## 3. インタラクティブスクリプト

```bash
# Yes/No確認
confirm() {
    read -r -p "${1:-Confirm?} [y/N]: " response
    [[ "$response" =~ ^[Yy] ]]
}

# selectメニュー
PS3="Select: "
select opt in "Option 1" "Option 2" "Quit"; do
    case "$opt" in
        "Quit") break ;;
        *) [[ -n "$opt" ]] && echo "Selected: $opt" ;;
    esac
done

# ターミナル検出（-t 0: stdin, -t 1: stdout）
if [[ -t 0 ]]; then
    read -r -p "Enter value: " value
else
    value="default"  # パイプ入力時
fi
```

---

## 4. エラーハンドリング（trap ERR）

```bash
#!/usr/bin/env bash
set -eEuo pipefail  # -E: サブシェルにもERRトラップ継承

trap 'echo "Error at line $LINENO (exit: $?)" >&2; exit 1' ERR

# 使用例
risky_operation || { echo "Operation failed" >&2; exit 1; }
```

---

## 5. ポータブルスクリプティング（POSIX互換）

```bash
#!/bin/sh  # Bash依存を避ける

# ❌ Bash固有: [[ ]], local, declare -A, ${var^^}
# ✅ POSIX: [ ], サブシェル, awk, tr

# OS検出
case "$(uname -s)" in
    Linux*) OS=linux ;;
    Darwin*) OS=macos ;;
    *) echo "Unsupported OS" >&2; exit 1 ;;
esac
```

---

## まとめ

このドキュメントでは、プロフェッショナルなCLIツールの構築、API連携、インタラクティブスクリプトの実装パターンを解説しました。

### チェックリスト

- [ ] getopts または getopt で引数を解析している
- [ ] カラー出力をターミナル判定付きで実装している
- [ ] プログレスバー・スピナーでユーザー体験を向上している
- [ ] 設定ファイルを適切にパースしている
- [ ] API呼び出しにリトライ・タイムアウト機能を実装している
- [ ] jq でJSON処理を効率化している
- [ ] インタラクティブ/非インタラクティブを検出している
- [ ] ポータブルなスクリプトを意識している

### 関連ドキュメント

- [PATTERNS.md](./PATTERNS.md): デザインパターン・アンチパターン・ベストプラクティス集
- [CONTROL-FLOW.md](./CONTROL-FLOW.md): 制御フロー・条件文・ループ
- [FUNCTIONS.md](./FUNCTIONS.md): 関数・モジュール化・引数処理
