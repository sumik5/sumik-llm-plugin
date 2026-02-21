# Bash シェルスクリプト開発ガイド

## 概要

このスキルはBashシェルスクリプトの作成時にClaude Codeが参照する包括的なガイドである。基礎から上級テクニックまで、堅牢で保守性の高いシェル自動化スクリプトの作成に必要な知識を提供する。

**対象ユーザー**: シェルスクリプトを作成・保守するClaude Code（`.sh` ファイル検出時に自動ロード）

**スコープ**:
- Bash固有の機能とベストプラクティス
- シェル自動化・システム管理タスク
- スクリプトの堅牢性・保守性・セキュリティ

**除外スコープ**:
- Docker固有のパターン → `managing-docker` スキルを使用
- DevOps方法論全般 → `practicing-devops` スキルを使用

---

## Bash Strict Mode（必須設定）

すべてのBashスクリプトは以下のstrict modeで開始すること:

```bash
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
```

### オプション解説

| オプション | 効果 | トレードオフ |
|-----------|------|------------|
| `set -e` | コマンド失敗時に即座にスクリプト終了 | パイプライン内の失敗検知には不十分。`set -o pipefail` と併用必須 |
| `set -u` | 未定義変数参照時にエラー | デフォルト値を持つ変数には `${VAR:-default}` を使用 |
| `set -o pipefail` | パイプライン内の任意のコマンド失敗を検知 | 一部のコマンド（`grep` 等）は「見つからない」を非ゼロで返すため注意 |
| `IFS=$'\n\t'` | Internal Field Separatorを改行とタブに制限 | スペース区切りの処理には明示的にIFSを再設定 |

### 例外的にstrict modeを無効化する場合

```bash
# 特定のコマンドのみエラーを許容
set +e
some_command_that_may_fail || true
set -e

# パイプライン内の特定ステージの失敗を許容
grep "pattern" file.txt || true | process_results
```

---

## クイックリファレンス

### 変数展開

| 構文 | 説明 | 例 |
|------|------|-----|
| `${var}` | 基本的な変数展開 | `echo "${HOME}"` |
| `${var:-default}` | 未定義/空の場合デフォルト値を使用 | `${PORT:-8080}` |
| `${var:=default}` | 未定義/空の場合デフォルト値を代入 | `${CONFIG:=/etc/app.conf}` |
| `${var:+alt}` | 定義済みの場合代替値を使用 | `${DEBUG:+--verbose}` |
| `${var:?error}` | 未定義/空の場合エラーメッセージを表示 | `${API_KEY:?API key required}` |
| `${#var}` | 文字列長 | `if [[ ${#input} -gt 100 ]]; then` |
| `${var##pattern}` | 前方から最長マッチを削除 | `${path##*/}` (basename) |
| `${var#pattern}` | 前方から最短マッチを削除 | `${file#*.}` (拡張子取得) |
| `${var%%pattern}` | 後方から最長マッチを削除 | `${file%%.*}` (拡張子削除) |
| `${var%pattern}` | 後方から最短マッチを削除 | `${path%/*}` (dirname) |
| `${var/old/new}` | 最初のマッチを置換 | `${str/foo/bar}` |
| `${var//old/new}` | すべてのマッチを置換 | `${str//foo/bar}` |
| `${var^}` | 先頭文字を大文字化 | `${name^}` |
| `${var^^}` | 全文字を大文字化 | `${name^^}` |
| `${var,}` | 先頭文字を小文字化 | `${name,}` |
| `${var,,}` | 全文字を小文字化 | `${name,,}` |

### テスト演算子

#### ファイルテスト

| 演算子 | 条件 |
|--------|------|
| `-f file` | 通常ファイルが存在 |
| `-d dir` | ディレクトリが存在 |
| `-e path` | パスが存在（ファイル・ディレクトリ・その他） |
| `-L link` | シンボリックリンクが存在 |
| `-r file` | 読み取り可能 |
| `-w file` | 書き込み可能 |
| `-x file` | 実行可能 |
| `-s file` | ファイルサイズが0より大きい |
| `-z string` | 文字列が空 |
| `-n string` | 文字列が非空 |

#### 数値比較

| 演算子 | 条件 |
|--------|------|
| `-eq` | 等しい |
| `-ne` | 等しくない |
| `-lt` | より小さい |
| `-le` | 以下 |
| `-gt` | より大きい |
| `-ge` | 以上 |

#### 文字列比較

```bash
[[ "$str1" == "$str2" ]]  # 等しい
[[ "$str1" != "$str2" ]]  # 等しくない
[[ "$str1" < "$str2" ]]   # 辞書順で小さい
[[ "$str1" > "$str2" ]]   # 辞書順で大きい
[[ "$str" =~ regex ]]     # 正規表現マッチ
```

### よく使うイディオム

```bash
# コマンド失敗時のエラーハンドリング
command || { echo "Error: command failed" >&2; exit 1; }

# 配列の安全な展開（クォートで要素を保護）
for item in "${array[@]}"; do
  process "$item"
done

# コマンド実行結果の取得（サブシェル）
result=$(command)

# コマンド存在チェック
if command -v docker &>/dev/null; then
  echo "Docker is installed"
fi

# 一時ファイル・ディレクトリの安全な作成
tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"' EXIT

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# ヒアドキュメント
cat <<EOF > output.txt
複数行の
テキストを
出力
EOF

# プロセス置換
diff <(sort file1.txt) <(sort file2.txt)

# 並列実行と待機
command1 &
pid1=$!
command2 &
pid2=$!
wait "$pid1" "$pid2"
```

---

## 標準スクリプトテンプレート

```bash
#!/usr/bin/env bash
#
# スクリプト名: example.sh
# 説明: スクリプトの目的を簡潔に記述
# 使用法: ./example.sh [options] <arguments>
#

set -euo pipefail
IFS=$'\n\t'

# グローバル変数
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

# デフォルト設定
DEFAULT_TIMEOUT=30
VERBOSE=false

# 使用法表示
usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS] <argument>

Description:
  スクリプトの詳細な説明をここに記述

Options:
  -h, --help       このヘルプメッセージを表示
  -v, --verbose    詳細出力を有効化
  -t, --timeout N  タイムアウト秒数（デフォルト: $DEFAULT_TIMEOUT）

Examples:
  $SCRIPT_NAME input.txt
  $SCRIPT_NAME --verbose --timeout 60 data/
EOF
}

# ログ出力関数
log_info() {
  echo "[INFO] $*" >&2
}

log_error() {
  echo "[ERROR] $*" >&2
}

# クリーンアップ処理
cleanup() {
  local exit_code=$?
  # 一時ファイル削除等のクリーンアップ処理
  exit "$exit_code"
}

trap cleanup EXIT INT TERM

# 引数パース
parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)
        usage
        exit 0
        ;;
      -v|--verbose)
        VERBOSE=true
        shift
        ;;
      -t|--timeout)
        if [[ -z ${2:-} ]]; then
          log_error "Option $1 requires an argument"
          exit 1
        fi
        DEFAULT_TIMEOUT=$2
        shift 2
        ;;
      -*)
        log_error "Unknown option: $1"
        usage
        exit 1
        ;;
      *)
        # 位置引数
        POSITIONAL_ARGS+=("$1")
        shift
        ;;
    esac
  done
}

# メイン処理
main() {
  local -a POSITIONAL_ARGS=()

  parse_args "$@"

  if [[ ${#POSITIONAL_ARGS[@]} -eq 0 ]]; then
    log_error "Missing required argument"
    usage
    exit 1
  fi

  # メインロジック
  log_info "Starting processing..."

  for arg in "${POSITIONAL_ARGS[@]}"; do
    log_info "Processing: $arg"
    # 処理内容
  done

  log_info "Completed successfully"
}

# スクリプトが直接実行された場合のみmainを実行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
```

---

## サブファイルナビゲーション

このスキルは15サブファイルに分割されている。以下の判断基準テーブルを参照し、適切なファイルを選択すること。

| 参照ファイル | 参照すべき状況 | 主なトピック |
|-------------|--------------|------------|
| [FUNDAMENTALS.md](references/FUNDAMENTALS.md) | シェル環境の理解、変数・環境変数の扱い | シェルアーキテクチャ、起動ファイル、変数、ビルトイン |
| [DATA-TYPES.md](references/DATA-TYPES.md) | データ型の操作、文字列加工、配列処理 | クォート、配列、パラメータ展開 |
| [CONTROL-FLOW.md](references/CONTROL-FLOW.md) | 条件分岐やループの実装 | 条件分岐、ループ、算術演算 |
| [FUNCTIONS.md](references/FUNCTIONS.md) | 関数設計、コードの再利用、引数パース | 関数、モジュール化、引数処理 |
| [IO-PIPELINES.md](references/IO-PIPELINES.md) | I/O処理、リダイレクト、パイプライン構築 | fd、リダイレクト、Here Doc、パイプ |
| [TEXT-PROCESSING.md](references/TEXT-PROCESSING.md) | テキスト処理、データ変換 | grep/sed/awk、正規表現、JSON/CSV |
| [PROCESS-CONTROL.md](references/PROCESS-CONTROL.md) | プロセス管理、trap、シグナルハンドリング | バックグラウンド、ジョブ制御、シグナル |
| [PARALLELISM.md](references/PARALLELISM.md) | 並列処理、プロセス間通信 | 並列実行、IPC、リソース制限 |
| [AUTOMATION.md](references/AUTOMATION.md) | 運用自動化、スケジューリング | システム管理、cron、バックアップ、監視 |
| [TESTING-DEBUGGING.md](references/TESTING-DEBUGGING.md) | テスト、デバッグ、品質保証 | ShellCheck、BATS、デバッグ、CI/CD |
| [SECURITY.md](references/SECURITY.md) | セキュリティ対策の実装 | 入力正規化、インジェクション防止、認証情報 |
| [HARDENING.md](references/HARDENING.md) | システム堅牢化 | TOCTOU、パーミッション、一時ファイル、攻撃面最小化 |
| [PATTERNS.md](references/PATTERNS.md) | 設計パターンの選択 | デザインパターン、アンチパターン |
| [BEST-PRACTICES.md](references/BEST-PRACTICES.md) | コード品質の向上 | ベストプラクティス集 |
| [CLI-TOOLS.md](references/CLI-TOOLS.md) | CLIツール開発、API統合 | CLIツール構築、API連携、インタラクティブ |

### ファイル選択のフローチャート

```
タスクの性質は？
├─ シェル環境・変数・ビルトイン → FUNDAMENTALS.md
├─ クォート・配列・パラメータ展開 → DATA-TYPES.md
├─ 条件分岐・ループ → CONTROL-FLOW.md
├─ 関数・モジュール化 → FUNCTIONS.md
├─ ファイル入出力・リダイレクト・パイプ → IO-PIPELINES.md
├─ テキスト処理・正規表現 → TEXT-PROCESSING.md
├─ プロセス管理・シグナル → PROCESS-CONTROL.md
├─ 並列実行・IPC → PARALLELISM.md
├─ システム管理・cron・監視 → AUTOMATION.md
├─ テスト・デバッグ → TESTING-DEBUGGING.md
├─ 入力検証・インジェクション対策 → SECURITY.md
├─ システム堅牢化 → HARDENING.md
├─ デザインパターン → PATTERNS.md
├─ コード品質 → BEST-PRACTICES.md
└─ CLIツール構築 → CLI-TOOLS.md
```

---

## AskUserQuestion指示

スクリプト作成時に判断分岐がある場合、AskUserQuestionツールで確認すること。

### 確認すべき判断ポイント

#### 1. シェルバージョンとPOSIX互換性

```python
AskUserQuestion(
    questions=[{
        "question": "このスクリプトのターゲット環境を教えてください",
        "header": "シェル環境",
        "options": [
            {
                "label": "Bash 4.0以降",
                "description": "モダンなLinux環境。連想配列等の高度な機能を使用可能"
            },
            {
                "label": "Bash 3.x（macOS互換）",
                "description": "macOS標準環境。連想配列は使用不可"
            },
            {
                "label": "POSIX互換（sh）",
                "description": "最大限の互換性。Bash固有機能は使用不可"
            }
        ],
        "multiSelect": False
    }]
)
```

#### 2. エラーハンドリング戦略

```python
AskUserQuestion(
    questions=[{
        "question": "エラー時の挙動をどうしますか？",
        "header": "エラー処理",
        "options": [
            {
                "label": "即座に停止（set -e）",
                "description": "任意のコマンド失敗で即座にスクリプト終了（推奨）"
            },
            {
                "label": "エラーログを記録して継続",
                "description": "エラーを記録しつつ処理を継続"
            },
            {
                "label": "カスタムエラーハンドリング",
                "description": "各コマンドで個別にエラーチェック"
            }
        ],
        "multiSelect": False
    }]
)
```

#### 3. 並列処理の必要性

```python
AskUserQuestion(
    questions=[{
        "question": "複数タスクを並列実行しますか？",
        "header": "並列処理",
        "options": [
            {
                "label": "並列実行（バックグラウンドジョブ）",
                "description": "複数タスクを同時実行して高速化。waitで同期"
            },
            {
                "label": "逐次実行",
                "description": "1つずつ順番に実行。シンプルで予測可能"
            },
            {
                "label": "GNU parallel使用",
                "description": "高度な並列処理フレームワーク。依存関係管理等が可能"
            }
        ],
        "multiSelect": False
    }]
)
```

#### 4. ロギング戦略

```python
AskUserQuestion(
    questions=[{
        "question": "ログ出力の詳細度は？",
        "header": "ロギング",
        "options": [
            {
                "label": "最小限（エラーのみ）",
                "description": "エラー発生時のみ出力"
            },
            {
                "label": "標準（info + error）",
                "description": "進捗情報とエラーを出力（推奨）"
            },
            {
                "label": "詳細（debug含む）",
                "description": "デバッグ情報を含むすべてのログレベル"
            }
        ],
        "multiSelect": False
    }]
)
```

---

## 重要な注意事項

### Bashとshの違い

- **Bash**: 高度な機能（配列、連想配列、`[[ ]]`、プロセス置換等）を提供
- **sh/POSIX**: 互換性最優先。基本機能のみ

スクリプトのshebangで明示的に指定:
```bash
#!/usr/bin/env bash  # Bash機能を使用
#!/bin/sh            # POSIX互換
```

### よくある間違い

1. **クォート忘れ**: `$var` ではなく `"$var"` を使用（空白を含むパスへの対応）
2. **配列展開**: `${array[*]}` ではなく `"${array[@]}"` を使用（要素を個別にクォート）
3. **数値比較演算子**: `==` ではなく `-eq` を使用（数値比較の場合）
4. **test vs [[]]**: `[[ ]]` は Bash拡張。POSIX互換には `[ ]` を使用

### パフォーマンス考慮事項

- **組み込みコマンド優先**: 外部コマンドよりBash組み込みコマンドが高速
- **パイプライン最適化**: 不要なコマンド呼び出しを削減
- **ループ内でのコマンド実行**: ループ外でまとめて処理できないか検討

---

## まとめ

このSKILL.mdは、Bashスクリプト作成時の入口として機能する。具体的な実装詳細は15サブファイルを参照し、段階的に知識を深めること。

**推奨アプローチ**:
1. まずこのSKILL.mdで全体像を把握
2. 実装する機能に応じて適切なサブファイルを参照
3. テンプレートを基に実装を開始
4. セキュリティとテストを忘れずに実施

**次のステップ**:
- 基礎から学ぶ → [FUNDAMENTALS.md](references/FUNDAMENTALS.md)
- すぐに実装 → 上記テンプレートを使用
- 特定トピック → 判断基準テーブルから選択
