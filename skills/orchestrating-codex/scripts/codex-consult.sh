#!/usr/bin/env bash
set -euo pipefail

readonly MODEL="gpt-5.4"
readonly REQUIRED_SUFFIX="確認や質問は不要です。具体的な提案・修正案・コード例まで自主的に出力してください。"

usage() {
  cat <<'EOF'
Usage: codex-consult.sh <project_directory> <request>

Codex CLI でコードレビュー・調査・設計相談を実行します。
モデルと安全寄りの実行オプションはスクリプト内で固定されています。

Arguments:
  project_directory  Codex に読ませる対象プロジェクトのディレクトリ
  request            Codex に渡す依頼文

Example:
  codex-consult.sh /path/to/project "このプロジェクトのコードをレビューしてください。"
EOF
}

if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -ne 2 ]]; then
  usage >&2
  exit 1
fi

project_directory="$1"
request="$2"

if [[ ! -d "$project_directory" ]]; then
  echo "Error: 指定されたディレクトリが見つかりません: $project_directory" >&2
  exit 1
fi

if ! command -v codex >/dev/null 2>&1; then
  echo "Error: codex CLIが見つかりません。npm install -g @openai/codex でインストールしてください。" >&2
  exit 1
fi

if [[ "$request" != *"$REQUIRED_SUFFIX"* ]]; then
  request="${request} ${REQUIRED_SUFFIX}"
fi

exec codex exec -m "$MODEL" --full-auto --sandbox read-only --cd "$project_directory" "$request"
