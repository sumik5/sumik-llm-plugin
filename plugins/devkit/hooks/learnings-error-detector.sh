#!/bin/bash
set -e

# PostToolUse(Bash) フック: エラーパターンを検出し .learnings/ERRORS.md への記録を促す
# capturing-learnings スキルと連携。agent非依存（Claude Code / Codex / Copilot 対応）

# stdin を取り込む
INPUT="$(cat)"

# --- JSON抽出関数 (jq優先・python3フォールバック) ---
json_extract() {
  local key="$1"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$INPUT" | jq -r "$key // empty" 2>/dev/null || true
  else
    python3 - "$key" "$INPUT" <<'PYEOF'
import sys, json
key = sys.argv[1]
data = sys.argv[2]
try:
    obj = json.loads(data)
    keys = key.lstrip('.').split('.')
    val = obj
    for k in keys:
        if isinstance(val, dict):
            val = val.get(k)
        else:
            val = None
            break
    if val is not None:
        print(val, end='')
except Exception:
    pass
PYEOF
  fi
}

json_extract_output_text() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$INPUT" | jq -r '
      def textish:
        if type == "string" then .
        elif type == "object" then
          [
            .stdout?,
            .stderr?,
            .output?,
            .text?,
            .message?
          ] | map(select(. != null) | tostring) | join("\n")
        else "" end;
      (.tool_response // empty) | textish
    ' 2>/dev/null || true
  else
    python3 - "$INPUT" <<'PYEOF'
import json
import sys

try:
    obj = json.loads(sys.argv[1])
except Exception:
    sys.exit(0)

response = obj.get("tool_response")
if isinstance(response, str):
    print(response, end="")
elif isinstance(response, dict):
    parts = []
    for key in ("stdout", "stderr", "output", "text", "message"):
        value = response.get(key)
        if value is not None:
            parts.append(str(value))
    print("\n".join(parts), end="")
PYEOF
  fi
}

first_numeric_value() {
  local value
  for key in \
    '.tool_response.exit_code' \
    '.tool_response.exitCode' \
    '.tool_response.status' \
    '.tool_response.code' \
    '.toolResult.exitCode' \
    '.toolResult.exit_code' \
    '.exit_code' \
    '.exitCode' \
    '.status'
  do
    value="$(json_extract "$key")"
    if printf '%s' "$value" | /usr/bin/grep -Eq '^[0-9]+$'; then
      printf '%s' "$value"
      return 0
    fi
  done
  return 1
}

is_inspection_command() {
  local command_text
  command_text="$(printf '%s' "$1" | sed 's/^[[:space:]]*//')"

  # Compound read-only probes such as:
  #   for f in ...; do printf ...; tail -40 "$f"; done
  # still only display files, but their output can contain this hook's own
  # error-pattern literals. Treat them like tail/cat/sed inspection commands.
  if printf '%s' "$command_text" | /usr/bin/grep -Eq '^(for|while)[[:space:]].*(cat|sed|head|tail|nl|wc|rg|grep|git (diff|status|show|ls-files|cat-file)|rtk git (diff|status|show|ls-files|cat-file))' \
    && ! printf '%s' "$command_text" | /usr/bin/grep -Eq '(^|[[:space:];|&])(bash|sh|zsh|python|python3|node|npm|pnpm|yarn|pytest|go test|cargo|terraform|make)([[:space:];|&]|$)'; then
    return 0
  fi

  case "$command_text" in
    pwd|pwd\ *|\
    ls\ *|/bin/ls\ *|\
    find\ *|/usr/bin/find\ *|\
    cat\ *|/bin/cat\ *|\
    sed\ *|/usr/bin/sed\ *|\
    head\ *|/usr/bin/head\ *|\
    tail\ *|/usr/bin/tail\ *|\
    nl\ *|/usr/bin/nl\ *|\
    wc\ *|/usr/bin/wc\ *|\
    rg\ *|grep\ *|/usr/bin/grep\ *|\
    git\ diff*|git\ status*|git\ show*|git\ ls-files*|git\ cat-file*|\
    rtk\ git\ diff*|rtk\ git\ status*|rtk\ git\ show*|rtk\ git\ ls-files*|rtk\ git\ cat-file*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# --- ツール名チェック (Copilot向け: bash/shell以外は処理しない) ---
# Claude Code / Codex は matcher="Bash" で既にフィルタ済みだが念のため確認
TOOL_NAME="$(json_extract '.tool_name')"
if [ -n "$TOOL_NAME" ]; then
  TOOL_NAME_LOWER="$(printf '%s' "$TOOL_NAME" | tr '[:upper:]' '[:lower:]')"
  case "$TOOL_NAME_LOWER" in
    bash|shell) : ;;  # 処理続行
    *) exit 0 ;;     # Bash/Shell以外はスキップ
  esac
fi

COMMAND_TEXT="$(json_extract '.tool_input.command')"

# --- 出力テキストの取得 ---
# Claude Code/Codex: .tool_response
# Copilot: .toolResult.textResultForLlm
OUTPUT_TEXT=""
OUTPUT_TEXT="$(json_extract_output_text)"
if [ -z "$OUTPUT_TEXT" ]; then
  OUTPUT_TEXT="$(json_extract '.toolResult.textResultForLlm')"
fi

# Copilot の resultType=="failure" は直接シグナル（出力テキスト不要）
RESULT_TYPE="$(json_extract '.toolResult.resultType')"
if [ "$RESULT_TYPE" = "failure" ]; then
  OUTPUT_TEXT="failure"
fi

# exit code が取れる環境では、成功時に本文スキャンしない。
# Codex の Bash 出力は成功コマンドでもドキュメント内の "Error:" 等を含みうるため、
# スキャンは明示的な失敗シグナルがない場合のフォールバックに限定する。
EXIT_CODE="$(first_numeric_value || true)"
if [ -z "$EXIT_CODE" ] && [ -n "$OUTPUT_TEXT" ]; then
  EXIT_CODE="$(printf '%s\n' "$OUTPUT_TEXT" | sed -nE 's/.*Process exited with code ([0-9]+).*/\1/p' | tail -n 1)"
fi

if [ -n "$EXIT_CODE" ]; then
  if [ "$EXIT_CODE" -eq 0 ]; then
    exit 0
  fi
  DETECTED=1
else
  DETECTED=0
fi

# --- エラーパターン検出 ---
ERROR_REGEXES=(
  'Hook JSON output validation failed'
  '(^|[[:space:]])command not found($|[[:space:]])'
  'No such file or directory'
  'Permission denied'
  '^fatal:'
  '^npm ERR!'
  'Traceback \(most recent call last\):'
  '(^|[[:space:]])ModuleNotFoundError:'
  '(^|[[:space:]])SyntaxError:'
  '(^|[[:space:]])TypeError:'
  '(^|[[:space:]])exit code [1-9][0-9]*($|[[:space:]])'
  'exited with code [1-9][0-9]*'
  'Process exited with code [1-9][0-9]*'
  'non-zero exit'
  '^FAILED([[:space:]:]|$)'
  '(^|[[:space:]])ENOENT($|[[:space:]:])'
  '(^|[[:space:]])EACCES($|[[:space:]:])'
  'Cannot find module'
  'Segmentation fault'
  '(^|[[:space:]])[Tt]imed out($|[[:space:]])'
  'Connection refused'
)

if [ "$DETECTED" -eq 0 ]; then
  # 出力テキストが空なら何もしない
  if [ -z "$OUTPUT_TEXT" ]; then
    exit 0
  fi

  # exit code が渡らない環境では、ファイル閲覧や diff の本文に含まれる
  # エラー語を実行失敗として扱わない。
  if [ -n "$COMMAND_TEXT" ] && is_inspection_command "$COMMAND_TEXT"; then
    exit 0
  fi

  for PATTERN in "${ERROR_REGEXES[@]}"; do
    if printf '%s' "$OUTPUT_TEXT" | /usr/bin/grep -qE "$PATTERN" 2>/dev/null; then
      DETECTED=1
      break
    fi
  done
fi

# 検出ゼロなら何も出力しない
if [ "$DETECTED" -eq 0 ]; then
  exit 0
fi

# --- hookSpecificOutput.additionalContext 形式でリマインダーを出力 ---
# PostToolUse では plain stdout はモデルに渡らないため additionalContext を使用
TODAY="$(date +%Y%m%d)"
cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "エラーが検出されました。想定外・非自明・再発しうる・将来セッションに有益なエラーであれば .learnings/ERRORS.md に [ERR-${TODAY}-XXX] 形式で記録してください（capturing-learnings スキル参照）。"
  }
}
EOF
