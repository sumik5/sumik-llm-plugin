#!/bin/bash
set -euo pipefail

# SessionStart hook: プロジェクトのファイル構成から推奨スキルを検出

# mise環境をロード（存在する場合）
if [[ -d "$HOME/.local/share/mise/shims" ]]; then
    export PATH="$HOME/.local/share/mise/shims:$PATH"
fi

# 常時適用スキル
ALWAYS_SKILLS=(
    "writing-clean-code"
    "enforcing-type-safety"
    "testing"
    "securing-code"
    "removing-ai-smell"
)

# プロジェクト固有スキル（検出結果を格納）
declare -a PROJECT_SKILLS=()

# 作業ディレクトリ
WORK_DIR="${PWD}"

# package.json の依存関係をチェック
check_package_json() {
    local package_json="$WORK_DIR/package.json"

    if [[ -f "$package_json" ]]; then
        # next.js をチェック
        if jq -e '.dependencies.next // .devDependencies.next' "$package_json" &>/dev/null; then
            PROJECT_SKILLS+=("developing-nextjs" "using-next-devtools" "react-best-practices")
            return
        fi

        # react をチェック（nextがない場合のみ）
        if jq -e '.dependencies.react // .devDependencies.react' "$package_json" &>/dev/null; then
            PROJECT_SKILLS+=("mastering-react-internals" "react-best-practices")
        fi
    fi
}

# TypeScript プロジェクトチェック
check_typescript() {
    if [[ -f "$WORK_DIR/tsconfig.json" ]]; then
        PROJECT_SKILLS+=("mastering-typescript" "writing-effective-typescript")
    fi
}

# shadcn/ui チェック
check_shadcn() {
    if [[ -f "$WORK_DIR/components.json" ]]; then
        PROJECT_SKILLS+=("using-shadcn")
    fi
}

# Storybook チェック
check_storybook() {
    if find "$WORK_DIR" -maxdepth 3 -name "*.stories.tsx" -o -name "*.stories.ts" 2>/dev/null | grep -q .; then
        PROJECT_SKILLS+=("storybook-guidelines")
    fi
}

# Go プロジェクトチェック
check_go() {
    if [[ -f "$WORK_DIR/go.mod" ]]; then
        PROJECT_SKILLS+=("developing-go" "applying-go-design-patterns")
    fi
}

# Python プロジェクトチェック
check_python() {
    if [[ -f "$WORK_DIR/pyproject.toml" ]] || [[ -f "$WORK_DIR/requirements.txt" ]]; then
        PROJECT_SKILLS+=("developing-python" "writing-effective-python")
    fi
}

# Terraform チェック
check_terraform() {
    if find "$WORK_DIR" -maxdepth 3 -name "*.tf" 2>/dev/null | grep -q .; then
        PROJECT_SKILLS+=("developing-terraform")
    fi
}

# Docker チェック
check_docker() {
    if [[ -f "$WORK_DIR/Dockerfile" ]] || find "$WORK_DIR" -maxdepth 3 -name "docker-compose.*" 2>/dev/null | grep -q .; then
        PROJECT_SKILLS+=("managing-docker")
    fi
}

# LaTeX チェック
check_latex() {
    if find "$WORK_DIR" -maxdepth 3 -name "*.tex" 2>/dev/null | grep -q .; then
        PROJECT_SKILLS+=("writing-latex")
    fi
}

# 検出実行
check_package_json
check_typescript
check_shadcn
check_storybook
check_go
check_python
check_terraform
check_docker
check_latex

# 重複を除去（sortとuniqを使用）
if [[ ${#PROJECT_SKILLS[@]} -gt 0 ]]; then
    IFS=$'\n' PROJECT_SKILLS=($(printf '%s\n' "${PROJECT_SKILLS[@]}" | sort -u))
    unset IFS
fi

# Markdown形式でプロンプトテキストを生成
PROMPT_TEXT="## Auto-detected Skills for This Session

以下のスキルがプロジェクト構成から検出されました。関連タスク実行時に Skill ツールでロードしてください。

### 🔴 Always Required
- \`writing-clean-code\` - コード実装前に必ずロード
- \`enforcing-type-safety\` - TypeScriptコード記述時にロード
- \`testing\` - テスト作成・修正時にロード
- \`securing-code\` - 実装完了後に必ずロード
- \`removing-ai-smell\` - コメント・ドキュメント記述時にロード
"

if [[ ${#PROJECT_SKILLS[@]} -gt 0 ]]; then
    PROMPT_TEXT+="
### 🟡 Project-Specific (Auto-detected)
"
    # ソートして表示
    IFS=$'\n' SORTED_SKILLS=($(sort <<<"${PROJECT_SKILLS[*]}"))
    unset IFS

    for skill in "${SORTED_SKILLS[@]}"; do
        PROMPT_TEXT+="- \`$skill\`
"
    done
else
    PROMPT_TEXT+="
### 🟡 Project-Specific (Auto-detected)
（検出されたプロジェクト固有スキルはありません）
"
fi

PROMPT_TEXT+="
### 📌 Reminder
- 新機能実装前は必ず \`researching-libraries\` をロード
- 上記以外のスキルは \`/skill-name\` で明示的に呼び出し"

# JSON出力（jqでエスケープ）
jq -n \
    --arg prompt "$PROMPT_TEXT" \
    '{
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": $prompt
        }
    }'

exit 0
