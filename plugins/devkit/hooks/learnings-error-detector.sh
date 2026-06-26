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

# --- 出力テキストの取得 ---
# Claude Code/Codex: .tool_response
# Copilot: .toolResult.textResultForLlm
OUTPUT_TEXT=""
OUTPUT_TEXT="$(json_extract '.tool_response')"
if [ -z "$OUTPUT_TEXT" ]; then
  OUTPUT_TEXT="$(json_extract '.toolResult.textResultForLlm')"
fi

# Copilot の resultType=="failure" は直接シグナル（出力テキスト不要）
RESULT_TYPE="$(json_extract '.toolResult.resultType')"
if [ "$RESULT_TYPE" = "failure" ]; then
  OUTPUT_TEXT="failure"
fi

# 出力テキストが空なら何もしない
if [ -z "$OUTPUT_TEXT" ]; then
  exit 0
fi

# --- エラーパターン検出 ---
ERROR_PATTERNS=(
  "error:"
  "Error:"
  "ERROR:"
  "failed"
  "command not found"
  "No such file"
  "Permission denied"
  "fatal:"
  "Exception"
  "Traceback"
  "npm ERR!"
  "ModuleNotFoundError"
  "SyntaxError"
  "TypeError"
  "exit code"
  "non-zero"
  "FAILED"
  "ENOENT"
  "EACCES"
  "Cannot find"
  "cannot find"
  "is not defined"
  "undefined"
  "null"
  "segfault"
  "Segmentation fault"
  "killed"
  "Killed"
  "timeout"
  "Timeout"
  "connection refused"
  "Connection refused"
  "failure"
)

DETECTED=0
for PATTERN in "${ERROR_PATTERNS[@]}"; do
  if printf '%s' "$OUTPUT_TEXT" | /usr/bin/grep -qF "$PATTERN" 2>/dev/null; then
    DETECTED=1
    break
  fi
done

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
