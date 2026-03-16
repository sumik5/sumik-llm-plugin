#!/usr/bin/env bash
set -euo pipefail

readonly MODEL="gpt-5.4"
readonly INITIAL_PROMPT_PREFIX="このプランをレビューしてください。瑣末な点へのクソリプはしないでください。致命的な点のみを指摘してください: "
readonly RESUME_PROMPT_PREFIX="プランを更新したのでレビューを再度してください。瑣末なクソリプはせず、致命的な点だけ指摘してください: "

usage() {
  cat <<'EOF'
Usage: codex-plan-review.sh <plan_file_path> [--resume]

Markdown のプランファイルを Codex CLI でレビューします。
モデルはスクリプト内で固定されており、呼び出し側で -m を都度組み立てる必要はありません。

Arguments:
  plan_file_path  レビュー対象の Markdown ファイル
  --resume        直近の Codex セッションを resume して再レビューする

Examples:
  codex-plan-review.sh /abs/path/docs/plan-example.md
  codex-plan-review.sh /abs/path/docs/plan-example.md --resume
EOF
}

if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 1 ]] || [[ $# -gt 2 ]]; then
  usage >&2
  exit 1
fi

plan_file_path="$1"
resume_mode="${2:-}"

if [[ ! -f "$plan_file_path" ]]; then
  echo "Error: 指定されたファイルが見つかりません: $plan_file_path" >&2
  exit 1
fi

if [[ "$plan_file_path" != /* ]]; then
  plan_file_path="$(cd "$(dirname "$plan_file_path")" && pwd)/$(basename "$plan_file_path")"
fi

if ! command -v codex >/dev/null 2>&1; then
  echo "Error: codex CLIが見つかりません。npm install -g @openai/codex でインストールしてください。" >&2
  exit 1
fi

if [[ -n "$resume_mode" ]] && [[ "$resume_mode" != "--resume" ]]; then
  echo "Error: 不正なオプションです: $resume_mode" >&2
  usage >&2
  exit 1
fi

if [[ "$resume_mode" == "--resume" ]]; then
  exec codex exec resume --last -m "$MODEL" "${RESUME_PROMPT_PREFIX}${plan_file_path}"
fi

exec codex exec -m "$MODEL" "${INITIAL_PROMPT_PREFIX}${plan_file_path}"
