# Bashスクリプトのデザインパターン・アンチパターン・ベストプラクティス

実用的なデザインパターン、避けるべきアンチパターン、プロフェッショナルのベストプラクティス集。

---

## 1. デザインパターン

### 1.1 テンプレートパターン

```bash
# メインフロー定義
main() {
    initialize && validate "$@" && process && output && cleanup
}

initialize() { echo "Init..."; }
validate() { [[ $# -gt 0 ]] || { echo "No args" >&2; return 1; }; }
process() { echo "Processing..."; }
output() { echo "Output..."; }
cleanup() { echo "Cleanup..."; }

main "$@"
```

### 1.2 ストラテジーパターン

```bash
# 環境別設定
set_env() {
    case "$1" in
        dev)  DB_HOST=localhost LOG_LEVEL=DEBUG ;;
        prod) DB_HOST=prod-db.com LOG_LEVEL=WARN ;;
        *) echo "Unknown env" >&2; return 1 ;;
    esac
}

# 関数ポインタ
process_json() { jq '.' "$1"; }
process_xml() { xmllint --format "$1"; }

select_proc() {
    case "${1##*.}" in
        json) echo process_json ;;
        xml) echo process_xml ;;
    esac
}

proc=$(select_proc "$file")
[[ -n "$proc" ]] && $proc "$file"
```

### 1.3 オブザーバーパターン（trap）

```bash
# イベントハンドラー
cleanup() { rm -f /tmp/app_*; }
log_error() { echo "$(date): Error" >> /var/log/app.log; }

trap cleanup EXIT
trap log_error ERR
trap 'echo "Interrupted" >&2; exit 130' INT
```

### 1.4 デコレーターパターン

```bash
# ログラッパー
with_log() {
    local func=$1; shift
    echo "[$(date '+%H:%M:%S')] $func $*" >&2
    $func "$@"
}

# リトライラッパー
with_retry() {
    local func=$1 max=${2:-3}; shift 2
    for ((i=1; i<=max; i++)); do
        $func "$@" && return 0
        echo "Retry $i/$max..." >&2; sleep 2
    done
    return 1
}

with_log with_retry risky_cmd arg1
```

### 1.5 シングルトンパターン（flock）

```bash
# 同時実行防止
LOCK="/var/lock/$(basename "$0").lock"
exec 200>"$LOCK"
flock -n 200 || { echo "Already running" >&2; exit 1; }
echo $$ >&200
```

---

## 2. アンチパターン

### 2.1 クォート忘れ（Word Splitting）

**アンチパターン:**

```bash
# 危険: クォート忘れ
file_name="my document.txt"
cat $file_name  # エラー: "my" と "document.txt" の2ファイル

# 危険: ループでのクォート忘れ
for file in $(ls *.txt); do
    echo $file  # スペース含むファイル名で失敗
done

# 危険: コマンド置換でのクォート忘れ
result=$(grep pattern file.txt)
echo $result  # 改行が失われる
```

**正しいパターン:**

```bash
# 安全: ダブルクォート
file_name="my document.txt"
cat "$file_name"  # 正常動作

# 安全: グロブ展開を使用
for file in *.txt; do
    echo "$file"
done

# 安全: クォートで改行保持
result=$(grep pattern file.txt)
echo "$result"
```

**判断基準テーブル:**

| 状況 | クォート必須 | 理由 |
|------|------------|------|
| 変数展開 | ✓ | ワード分割・グロブ展開防止 |
| コマンド置換 | ✓ | 空白・改行保持 |
| 算術式 | × | `$(( ))` 内は不要 |
| 配列全体 | ✓ | `"${arr[@]}"` で各要素保持 |
| リダイレクト | △ | 可変ファイル名は必要 |

### 2.2 UUOC（Useless Use of Cat）

**アンチパターン:**

```bash
# 無駄なcat使用
cat file.txt | grep pattern

# さらに悪い例
cat file.txt | grep pattern | wc -l
```

**正しいパターン:**

```bash
# 直接リダイレクト
grep pattern < file.txt

# またはファイル引数
grep pattern file.txt

# パイプライン
grep pattern file.txt | wc -l
```

**判断基準テーブル:**

| 操作 | ❌ UUOC | ✅ 正解 |
|------|---------|--------|
| 検索 | `cat file \| grep` | `grep pattern file` |
| 行数 | `cat file \| wc -l` | `wc -l < file` |
| ソート | `cat file \| sort` | `sort file` |
| 置換 | `cat file \| sed` | `sed 's/old/new/' file` |
| 先頭表示 | `cat file \| head` | `head file` |

**catが正当な場合:**

```bash
# 複数ファイルの連結
cat file1.txt file2.txt file3.txt | grep pattern

# ヒアドキュメント表示
cat << EOF
複数行の
テキスト
EOF
```

### 2.3 コマンド出力のパース失敗

**アンチパターン: `ls` のパース**

```bash
# 極めて危険: ls出力のパース
for file in $(ls); do
    echo "$file"
done
# 問題:
# - スペース含むファイル名で失敗
# - 改行含むファイル名で失敗
# - グロブ文字で意図しない展開
```

**正しいパターン:**

```bash
# グロブ展開を使用
for file in *; do
    [[ -e "$file" ]] || continue  # ファイルが存在しない場合スキップ
    echo "$file"
done

# find を使用（サブディレクトリも含む）
while IFS= read -r -d '' file; do
    echo "$file"
done < <(find . -type f -print0)

# 配列に格納
files=( * )
for file in "${files[@]}"; do
    echo "$file"
done
```

**判断基準テーブル:**

| 目的 | ❌ 悪い方法 | ✅ 良い方法 |
|------|-----------|-----------|
| カレントディレクトリのファイル一覧 | `for f in $(ls)` | `for f in *` |
| 特定パターンのファイル | `for f in $(ls *.txt)` | `for f in *.txt` |
| 再帰的検索 | `for f in $(find .)` | `while IFS= read -r -d '' f; do ... done < <(find . -print0)` |
| ファイル数カウント | `ls \| wc -l` | `files=(*); echo ${#files[@]}` |

### 2.4 `/bin/bash` のハードコード

**アンチパターン:**

```bash
#!/bin/bash
# 問題: Bashのパスが環境依存
```

**正しいパターン:**

```bash
#!/usr/bin/env bash
# 環境のPATHからbashを検索
```

**理由:**

| OS/環境 | Bashの場所 |
|---------|-----------|
| Linux (ほとんど) | `/bin/bash` |
| FreeBSD | `/usr/local/bin/bash` |
| macOS (Homebrew) | `/usr/local/bin/bash` or `/opt/homebrew/bin/bash` |
| Nix | `/nix/store/.../bin/bash` |

### 2.5 `eval` の乱用

**アンチパターン:**

```bash
# 極めて危険
user_input="ls -la"
eval "$user_input"  # コマンドインジェクション脆弱性

# 危険な例
cmd="rm -rf /"
eval "$cmd"  # システム破壊
```

**正しいパターン:**

```bash
# 配列を使用
cmd=(ls -la)
"${cmd[@]}"

# 関数で動的実行
execute_command() {
    case "$1" in
        list) ls -la ;;
        show) cat "$2" ;;
        *) echo "Unknown command" >&2; return 1 ;;
    esac
}

execute_command list
```

### 2.6 巨大スクリプト（分割すべきサイン）

**判断基準テーブル:**

| サイン | 行数 | 対策 |
|-------|------|------|
| 1つのスクリプトに複数の機能 | 500+ | 機能ごとにファイル分割 |
| 同じコードブロックの繰り返し | 3回以上 | 関数化 |
| 深いネスト（5階層以上） | - | 関数抽出・早期return |
| グローバル変数が10個以上 | - | 構造化・名前空間導入 |
| メンテナンス困難 | 1000+ | 複数スクリプトに分割 |

**リファクタリング例:**

```bash
# Before: 巨大スクリプト (1000行)
#!/bin/bash
# ... 1000行のコード ...

# After: 分割
# main.sh
#!/bin/bash
source lib/logging.sh
source lib/config.sh
source lib/database.sh
source lib/api.sh

main() {
    load_config
    init_database
    call_api
}

main "$@"

# lib/logging.sh (100行)
# lib/config.sh (150行)
# lib/database.sh (200行)
# lib/api.sh (250行)
```

---


## 次のステップ

以下の関連ドキュメントも参照してください：

- [BEST-PRACTICES.md](./BEST-PRACTICES.md): ベストプラクティス集・命名規則・品質管理
- [CLI-TOOLS.md](./CLI-TOOLS.md): CLIツール構築・API連携・インタラクティブスクリプト
- [CONTROL-FLOW.md](./CONTROL-FLOW.md): 制御フロー・条件文・ループ・算術演算
- [FUNCTIONS.md](./FUNCTIONS.md): 関数・モジュール化・引数処理
