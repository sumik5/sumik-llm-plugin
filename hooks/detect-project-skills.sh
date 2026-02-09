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
    "testing-code"
    "securing-code"
    "removing-ai-smell"
)

# 共通開発スキル（言語プロジェクト検出時に適用）
COMMON_DEV_SKILLS=(
    "researching-libraries"
    "architecting-microservices"
    "modernizing-architecture"
)

# 言語プロジェクトが検出されたかのフラグ
HAS_LANGUAGE_PROJECT=false

# プロジェクト固有スキル（検出結果を格納）
declare -a PROJECT_SKILLS=()

# スキル説明文を取得する関数（bash 3.2互換）
get_skill_description() {
    local skill="$1"
    case "$skill" in
        "writing-clean-code") echo "コード実装前に必ずロード" ;;
        "enforcing-type-safety") echo "TypeScriptコード記述時にロード" ;;
        "testing-code") echo "テスト作成・修正時にロード" ;;
        "securing-code") echo "実装完了後に必ずロード" ;;
        "removing-ai-smell") echo "コメント・ドキュメント記述時にロード" ;;
        "researching-libraries") echo "実装前のライブラリ調査（車輪の再発明禁止）" ;;
        "architecting-microservices") echo "マイクロサービス設計パターン" ;;
        "modernizing-architecture") echo "アーキテクチャモダナイゼーション" ;;
        "developing-nextjs") echo "Next.js 16 / React 19開発" ;;
        "using-next-devtools") echo "Next.js DevTools MCP活用" ;;
        "mastering-typescript") echo "TypeScript型システム・パターン" ;;
        "designing-frontend") echo "フロントエンドUI/UXコンポーネント" ;;
        "developing-go") echo "Go開発ガイド" ;;
        "developing-python") echo "Python開発ガイド" ;;
        "developing-terraform") echo "Terraform IaC開発" ;;
        "managing-docker") echo "Docker開発環境・コンテナ管理" ;;
        "writing-latex") echo "LaTeX文書作成（日本語対応）" ;;
        "developing-fullstack-javascript") echo "NestJS/Express フルスタックJS" ;;
        "automating-browser") echo "Playwright ブラウザ自動化・E2Eテスト" ;;
        "implementing-opentelemetry") echo "OpenTelemetry 分散トレーシング" ;;
        "building-adk-agents") echo "Google ADK AIエージェント開発" ;;
        "building-nextjs-saas") echo "Next.js SaaSアプリケーション構築" ;;
        "implementing-dynamic-authorization") echo "Cedar/ABAC/ReBAC 動的認可" ;;
        *) echo "" ;;
    esac
}

# 作業ディレクトリ
WORK_DIR="${PWD}"

# package.json の依存関係をチェック
check_package_json() {
    local package_json="$WORK_DIR/package.json"

    if [[ ! -f "$package_json" ]]; then
        return
    fi

    local deps
    deps=$(jq -r '(.dependencies // {} | keys[]) , (.devDependencies // {} | keys[])' "$package_json" 2>/dev/null) || return

    local has_next=false has_react=false

    # Next.js チェック
    if echo "$deps" | grep -qx "next"; then
        has_next=true
        HAS_LANGUAGE_PROJECT=true
        PROJECT_SKILLS+=("developing-nextjs" "using-next-devtools")

        # Next.js SaaS チェック（stripe / next-auth / @auth/core / @clerk/nextjs）
        if echo "$deps" | grep -qE '^(stripe|next-auth|@auth/core|@clerk/nextjs)$'; then
            PROJECT_SKILLS+=("building-nextjs-saas")
        fi
    fi

    # React チェック（Next.jsがない場合）
    # developing-nextjs はReact Internals/Performance統合済みなのでReact単独でも有用
    if [[ "$has_next" == "false" ]] && echo "$deps" | grep -qx "react"; then
        has_react=true
        HAS_LANGUAGE_PROJECT=true
        PROJECT_SKILLS+=("developing-nextjs")
    fi

    # フルスタックJS チェック（express / @nestjs/core / fastify / koa / @hapi/hapi）
    if echo "$deps" | grep -qE '^(express|@nestjs/core|fastify|koa|@hapi/hapi)$'; then
        HAS_LANGUAGE_PROJECT=true
        PROJECT_SKILLS+=("developing-fullstack-javascript")
    fi

    # Playwright チェック（package.json内）
    if echo "$deps" | grep -qx "@playwright/test"; then
        PROJECT_SKILLS+=("automating-browser")
    fi

    # OpenTelemetry チェック（JS）
    if echo "$deps" | grep -q "^@opentelemetry/"; then
        PROJECT_SKILLS+=("implementing-opentelemetry")
    fi
}

# TypeScript プロジェクトチェック
check_typescript() {
    if [[ -f "$WORK_DIR/tsconfig.json" ]]; then
        HAS_LANGUAGE_PROJECT=true
        PROJECT_SKILLS+=("mastering-typescript")
    fi
}

# shadcn/ui チェック
check_shadcn() {
    if [[ -f "$WORK_DIR/components.json" ]]; then
        PROJECT_SKILLS+=("designing-frontend")
    fi
}

# Storybook チェック
check_storybook() {
    if find "$WORK_DIR" -maxdepth 3 -name "*.stories.tsx" -o -name "*.stories.ts" 2>/dev/null | grep -q .; then
        PROJECT_SKILLS+=("designing-frontend")
    fi
}

# Go プロジェクトチェック
check_go() {
    if [[ -f "$WORK_DIR/go.mod" ]]; then
        HAS_LANGUAGE_PROJECT=true
        PROJECT_SKILLS+=("developing-go")

        # Terraform provider/plugin 開発チェック
        if grep -q "hashicorp/terraform" "$WORK_DIR/go.mod"; then
            PROJECT_SKILLS+=("developing-terraform")
        fi
    fi
}

# Python プロジェクトチェック
check_python() {
    if [[ -f "$WORK_DIR/pyproject.toml" ]] || [[ -f "$WORK_DIR/requirements.txt" ]]; then
        HAS_LANGUAGE_PROJECT=true
        PROJECT_SKILLS+=("developing-python")
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

# Playwright 設定ファイルチェック
check_playwright_config() {
    if find "$WORK_DIR" -maxdepth 2 -name "playwright.config.*" 2>/dev/null | grep -q .; then
        PROJECT_SKILLS+=("automating-browser")
    fi
}

# Python 依存関係チェック（ADK、OpenTelemetry等）
check_python_deps() {
    local deps_content=""

    if [[ -f "$WORK_DIR/pyproject.toml" ]]; then
        deps_content+=$(cat "$WORK_DIR/pyproject.toml" 2>/dev/null)
    fi
    if [[ -f "$WORK_DIR/requirements.txt" ]]; then
        deps_content+=$(cat "$WORK_DIR/requirements.txt" 2>/dev/null)
    fi

    if [[ -z "$deps_content" ]]; then
        return
    fi

    # Google ADK チェック
    if echo "$deps_content" | grep -q "google-adk"; then
        PROJECT_SKILLS+=("building-adk-agents")
    fi

    # OpenTelemetry チェック（Python）
    if echo "$deps_content" | grep -q "opentelemetry-"; then
        PROJECT_SKILLS+=("implementing-opentelemetry")
    fi
}

# Cedar ポリシーファイルチェック
check_cedar() {
    if find "$WORK_DIR" -maxdepth 3 -name "*.cedar" 2>/dev/null | grep -q .; then
        PROJECT_SKILLS+=("implementing-dynamic-authorization")
    fi
}

# 検出実行
check_package_json
check_typescript
check_shadcn
check_storybook
check_playwright_config
check_go
check_python
check_python_deps
check_terraform
check_docker
check_latex
check_cedar

# 重複を除去（sortとuniqを使用）
if [[ ${#PROJECT_SKILLS[@]} -gt 0 ]]; then
    IFS=$'\n' PROJECT_SKILLS=($(printf '%s\n' "${PROJECT_SKILLS[@]}" | sort -u))
    unset IFS
fi

# Markdown形式でプロンプトテキストを生成
PROMPT_TEXT="## Auto-detected Skills for This Session

以下のスキルがプロジェクト構成から検出されました。関連タスク実行時に Skill ツールでロードしてください。

### 🔴 Always Required
"

for skill in "${ALWAYS_SKILLS[@]}"; do
    desc=$(get_skill_description "$skill")
    if [[ -n "$desc" ]]; then
        PROMPT_TEXT+="- \`$skill\` - $desc
"
    else
        PROMPT_TEXT+="- \`$skill\`
"
    fi
done

PROMPT_TEXT+=""

# 🟠 Common Development スキル（言語プロジェクト検出時のみ）
if [[ "$HAS_LANGUAGE_PROJECT" == "true" ]]; then
    PROMPT_TEXT+="
### 🟠 Common Development (言語プロジェクト検出時)
"
    for skill in "${COMMON_DEV_SKILLS[@]}"; do
        desc=$(get_skill_description "$skill")
        if [[ -n "$desc" ]]; then
            PROMPT_TEXT+="- \`$skill\` - $desc
"
        else
            PROMPT_TEXT+="- \`$skill\`
"
        fi
    done
    PROMPT_TEXT+=""
fi

if [[ ${#PROJECT_SKILLS[@]} -gt 0 ]]; then
    PROMPT_TEXT+="
### 🟡 Project-Specific (Auto-detected)
"
    # ソートして表示
    IFS=$'\n' SORTED_SKILLS=($(sort <<<"${PROJECT_SKILLS[*]}"))
    unset IFS

    for skill in "${SORTED_SKILLS[@]}"; do
        desc=$(get_skill_description "$skill")
        if [[ -n "$desc" ]]; then
            PROMPT_TEXT+="- \`$skill\` - $desc
"
        else
            PROMPT_TEXT+="- \`$skill\`
"
        fi
    done
else
    PROMPT_TEXT+="
### 🟡 Project-Specific (Auto-detected)
（検出されたプロジェクト固有スキルはありません）
"
fi

PROMPT_TEXT+="
### 📌 Reminder
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
