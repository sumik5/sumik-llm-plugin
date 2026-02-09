#!/usr/bin/env bash
# スキル利用状況分析ツール
# Claude Code のセッションログ（JSONL）から全プラグインのスキル利用状況を集計する

set -euo pipefail

# デフォルト設定
SINCE=""
UNTIL=""
FORMAT="table"
OUTPUT=""
JSON_OUTPUT="$HOME/.claude/usage-data/skill-usage-report.json"
CLAUDE_DIR="$HOME/.claude"
PROJECT_DIR="$CLAUDE_DIR/projects"
PLUGINS_DIR="$CLAUDE_DIR/plugins"

# 組み込みコマンド一覧（除外対象）
BUILTIN_COMMANDS=(
  "clear" "compact" "context" "mcp" "skills" "plugin" "help"
  "config" "vim" "status" "resume" "ide" "theme" "usage" "insights" "tasks"
)

# ヘルプ表示
usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Claude Code のセッションログから全プラグインのスキル利用状況を集計します。

OPTIONS:
  --since YYYY-MM-DD     この日以降のセッションのみ対象
  --until YYYY-MM-DD     この日以前のセッションのみ対象
  --format FORMAT        出力形式 [table|csv|json] (default: table)
  --output FILE          出力ファイルパス（指定なしの場合はstdout）
  --json-output FILE     JSON形式で常にこのファイルにも出力 (default: ~/.claude/usage-data/skill-usage-report.json)
  -h, --help             このヘルプを表示

EXAMPLES:
  # 全期間のスキル利用状況をテーブル表示
  $(basename "$0")

  # 2026年1月以降のスキル利用状況をCSV出力
  $(basename "$0") --since 2026-01-01 --format csv --output skill-usage.csv

  # 特定期間のスキル利用状況をJSON出力
  $(basename "$0") --since 2025-12-01 --until 2026-01-31 --format json
EOF
  exit 0
}

# オプション解析
while [[ $# -gt 0 ]]; do
  case "$1" in
    --since)
      SINCE="$2"
      shift 2
      ;;
    --until)
      UNTIL="$2"
      shift 2
      ;;
    --format)
      FORMAT="$2"
      shift 2
      ;;
    --output)
      OUTPUT="$2"
      shift 2
      ;;
    --json-output)
      JSON_OUTPUT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      ;;
  esac
done

# JSONLファイル一覧取得
if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "Error: Project directory not found: $PROJECT_DIR" >&2
  exit 1
fi

# 一時ファイル
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

SKILL_CALLS="$TMP_DIR/skill_calls.txt"
SLASH_COMMANDS="$TMP_DIR/slash_commands.txt"
ALL_SKILLS="$TMP_DIR/all_skills.txt"
FILTERED_LINES="$TMP_DIR/filtered_lines.txt"

# JSONLログから期間フィルタリング + Skillツール呼び出し抽出
if [[ -n "$SINCE" || -n "$UNTIL" ]]; then
  # 期間指定あり: ファイルごとに処理
  > "$SKILL_CALLS"
  find "$PROJECT_DIR" -name "*.jsonl" -type f | while read -r jsonl_file; do
    if grep -q '"name":"Skill"' "$jsonl_file" 2>/dev/null; then
      grep '"name":"Skill"' "$jsonl_file" 2>/dev/null | while read -r line; do
        timestamp=$(echo "$line" | grep -o '"timestamp":"[^"]*"' | head -1 | cut -d'"' -f4 | cut -dT -f1)
        if [[ -n "$timestamp" ]]; then
          skip=false
          [[ -n "$SINCE" && "$timestamp" < "$SINCE" ]] && skip=true
          [[ -n "$UNTIL" && "$timestamp" > "$UNTIL" ]] && skip=true
          if [[ "$skip" == "false" ]]; then
            echo "$line" | grep -o '"skill":"[^"]*"' | cut -d'"' -f4
          fi
        fi
      done
    fi
  done >> "$SKILL_CALLS"
else
  # 期間指定なし: 高速処理
  find "$PROJECT_DIR" -name "*.jsonl" -type f -print0 2>/dev/null | \
    xargs -0 grep -oh '"skill":"[^"]*"' 2>/dev/null | cut -d'"' -f4 > "$SKILL_CALLS" || true
fi

# JSONLログからスラッシュコマンド抽出
if [[ -n "$SINCE" || -n "$UNTIL" ]]; then
  # 期間指定あり: ファイルごとに処理
  > "$SLASH_COMMANDS"
  find "$PROJECT_DIR" -name "*.jsonl" -type f | while read -r jsonl_file; do
    if grep -q '<command-name>' "$jsonl_file" 2>/dev/null; then
      grep '<command-name>' "$jsonl_file" 2>/dev/null | while read -r line; do
        timestamp=$(echo "$line" | grep -o '"timestamp":"[^"]*"' | head -1 | cut -d'"' -f4 | cut -dT -f1)
        if [[ -n "$timestamp" ]]; then
          skip=false
          [[ -n "$SINCE" && "$timestamp" < "$SINCE" ]] && skip=true
          [[ -n "$UNTIL" && "$timestamp" > "$UNTIL" ]] && skip=true
          if [[ "$skip" == "false" ]]; then
            cmd=$(echo "$line" | grep -o '<command-name>/[^<]*</command-name>' | sed 's|<command-name>/||;s|</command-name>||')
            if [[ -n "$cmd" && ! "$cmd" =~ [^a-zA-Z0-9_:/-] ]]; then
              is_builtin=false
              for builtin in "${BUILTIN_COMMANDS[@]}"; do
                [[ "$cmd" == "$builtin" ]] && is_builtin=true && break
              done
              [[ "$is_builtin" == "false" ]] && echo "$cmd"
            fi
          fi
        fi
      done
    fi
  done >> "$SLASH_COMMANDS"
else
  # 期間指定なし: 高速処理
  find "$PROJECT_DIR" -name "*.jsonl" -type f -print0 2>/dev/null | \
    xargs -0 grep -oh '<command-name>/[^<]*</command-name>' 2>/dev/null | \
    sed 's|<command-name>/||;s|</command-name>||' | while read -r cmd; do
    if [[ -n "$cmd" && ! "$cmd" =~ [^a-zA-Z0-9_:/-] ]]; then
      is_builtin=false
      for builtin in "${BUILTIN_COMMANDS[@]}"; do
        [[ "$cmd" == "$builtin" ]] && is_builtin=true && break
      done
      [[ "$is_builtin" == "false" ]] && echo "$cmd"
    fi
  done > "$SLASH_COMMANDS" || true
fi

# 現在のインストール済みスキル一覧取得
# 1. 自プロジェクト
if [[ -d "skills" ]]; then
  find skills -mindepth 1 -maxdepth 1 -type d 2>/dev/null | while read -r skill_dir; do
    basename "$skill_dir"
  done >> "$ALL_SKILLS" || true
fi

# 2. プラグイン
if [[ -d "$PLUGINS_DIR" ]]; then
  find "$PLUGINS_DIR" -path "*/skills/*/SKILL.md" -type f 2>/dev/null | while read -r skill_file; do
    skill_name=$(basename "$(dirname "$skill_file")")
    plugin_name=$(basename "$(dirname "$(dirname "$(dirname "$skill_file")")")")
    echo "$plugin_name:$skill_name"
  done >> "$ALL_SKILLS" || true
fi

[[ -s "$ALL_SKILLS" ]] && sort -u "$ALL_SKILLS" -o "$ALL_SKILLS"

# 集計
if [[ -s "$SKILL_CALLS" ]]; then
  skill_counts=$(sort "$SKILL_CALLS" | uniq -c | sort -rn)
else
  skill_counts=""
fi

if [[ -s "$SLASH_COMMANDS" ]]; then
  slash_counts=$(sort "$SLASH_COMMANDS" | uniq -c | sort -rn)
else
  slash_counts=""
fi

# 未使用スキル検出
unused_skills=()
if [[ -s "$ALL_SKILLS" ]]; then
  while read -r skill; do
    if [[ -s "$SKILL_CALLS" ]]; then
      if ! grep -qFx "$skill" "$SKILL_CALLS" 2>/dev/null; then
        unused_skills+=("$skill")
      fi
    else
      unused_skills+=("$skill")
    fi
  done < "$ALL_SKILLS"
fi

# 期間表示文字列生成
period_str=""
if [[ -n "$SINCE" && -n "$UNTIL" ]]; then
  period_str="$SINCE 〜 $UNTIL"
elif [[ -n "$SINCE" ]]; then
  period_str="$SINCE 以降"
elif [[ -n "$UNTIL" ]]; then
  period_str="〜 $UNTIL"
else
  period_str="全期間"
fi

# JSON出力用データ構築
build_json_output() {
  local skill_json=""
  local slash_json=""
  local unused_json=""

  # Skill呼び出し
  if [[ -n "$skill_counts" ]]; then
    skill_json=$(echo "$skill_counts" | head -20 | while read -r count name; do
      name_escaped=$(echo "$name" | sed 's/"/\\"/g')
      echo "{\"skill\":\"$name_escaped\",\"count\":$count}"
    done | tr '\n' ',' | sed 's/,$//')
  fi

  # スラッシュコマンド
  if [[ -n "$slash_counts" ]]; then
    slash_json=$(echo "$slash_counts" | head -20 | while read -r count name; do
      name_escaped=$(echo "$name" | sed 's/"/\\"/g')
      echo "{\"command\":\"$name_escaped\",\"count\":$count}"
    done | tr '\n' ',' | sed 's/,$//')
  fi

  # 未使用スキル
  if [[ ${#unused_skills[@]} -gt 0 ]]; then
    unused_json=$(printf '"%s",' "${unused_skills[@]}" | sed 's/,$//')
  fi

  cat <<JSON
{
  "period": "$period_str",
  "generated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "skill_invocations": [$skill_json],
  "slash_commands": [$slash_json],
  "unused_skills": [$unused_json]
}
JSON
}

# 出力処理
output_table() {
  cat <<EOF

=== Skill Usage Report ($period_str) ===

📊 Skill Tool Invocations (top 20):
EOF
  if [[ -n "$skill_counts" ]]; then
    echo "$skill_counts" | head -20 | while read -r count name; do
      printf "  %5d  %s\n" "$count" "$name"
    done
  else
    echo "  (該当データなし)"
  fi

  cat <<EOF

📊 Slash Commands (top 20):
EOF
  if [[ -n "$slash_counts" ]]; then
    echo "$slash_counts" | head -20 | while read -r count name; do
      printf "  %5d  /%s\n" "$count" "$name"
    done
  else
    echo "  (該当データなし)"
  fi

  echo ""
  echo "⚠️  未使用スキル（Skillツール呼び出し0回）:"
  if [[ ${#unused_skills[@]} -gt 0 ]]; then
    for skill in "${unused_skills[@]}"; do
      echo "  - $skill"
    done
  else
    echo "  (すべてのスキルが使用されています)"
  fi

  echo ""
  echo "📁 JSON出力: $JSON_OUTPUT"
}

output_csv() {
  cat <<EOF
category,name,count
EOF
  if [[ -n "$skill_counts" ]]; then
    echo "$skill_counts" | head -20 | while read -r count name; do
      echo "skill,$name,$count"
    done
  fi
  if [[ -n "$slash_counts" ]]; then
    echo "$slash_counts" | head -20 | while read -r count name; do
      echo "command,/$name,$count"
    done
  fi
  if [[ ${#unused_skills[@]} -gt 0 ]]; then
    for skill in "${unused_skills[@]}"; do
      echo "unused,$skill,0"
    done
  fi
}

# メイン出力処理
OUTPUT_CONTENT=""
case "$FORMAT" in
  table)
    OUTPUT_CONTENT=$(output_table)
    ;;
  csv)
    OUTPUT_CONTENT=$(output_csv)
    ;;
  json)
    OUTPUT_CONTENT=$(build_json_output)
    ;;
  *)
    echo "Error: Unknown format: $FORMAT" >&2
    exit 1
    ;;
esac

# 標準出力またはファイルに出力
if [[ -z "$OUTPUT" ]]; then
  echo "$OUTPUT_CONTENT"
else
  echo "$OUTPUT_CONTENT" > "$OUTPUT"
  echo "Output written to: $OUTPUT" >&2
fi

# JSON出力（常に実行）
mkdir -p "$(dirname "$JSON_OUTPUT")"
build_json_output > "$JSON_OUTPUT"
