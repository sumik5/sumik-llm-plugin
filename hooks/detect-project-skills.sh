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
    "writing-effective-prose"
)

# 共通開発スキル（言語プロジェクト検出時に適用）
COMMON_DEV_SKILLS=(
    "researching-libraries"
    "architecting-microservices"
    "modernizing-architecture"
)

# ライティングスキル（.tex検出時に適用）
WRITING_SKILLS=(
    "writing-latex"
    "writing-effective-prose"
    "searching-web"
)

# デザインスキル（フロントエンド/デザイン検出時に適用）
DESIGN_SKILLS=(
    "applying-design-guidelines"
    "applying-behavior-design"
    "implementing-design"
)

# データベーススキル（DB関連検出時に適用）
DATABASE_SKILLS=(
    "avoiding-sql-antipatterns"
    "understanding-database-internals"
    "designing-relational-databases"
)

# オブザーバビリティスキル（監視・可観測性検出時に適用）
OBSERVABILITY_SKILLS=(
    "designing-monitoring"
)

# MCP開発スキル（MCP開発検出時に適用）
MCP_DEV_SKILLS=(
    "developing-mcp"
)

# 言語プロジェクトが検出されたかのフラグ
HAS_LANGUAGE_PROJECT=false
HAS_WRITING_PROJECT=false
HAS_DESIGN_PROJECT=false
HAS_DATABASE_PROJECT=false
HAS_OBSERVABILITY_PROJECT=false
HAS_MCP_DEV_PROJECT=false

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
        "writing-effective-prose") echo "効果的な文章術（論理構成・文レベル技術・表現・推敲・AI臭除去・技術文書・学術文書）" ;;
        "researching-libraries") echo "実装前のライブラリ調査（車輪の再発明禁止）" ;;
        "architecting-microservices") echo "CQRS/Saga/粒度決定/データ所有権/ワークフロー・コントラクト" ;;
        "modernizing-architecture") echo "社会技術的モダナイゼーション・トレードオフ分析手法" ;;
        "applying-domain-driven-design") echo "DDD戦略/戦術パターン・データ分解・データメッシュ" ;;
        "developing-nextjs") echo "Next.js 16 / React 19開発" ;;
        "using-next-devtools") echo "Next.js DevTools MCP活用" ;;
        "mastering-typescript") echo "TypeScript型システム・パターン" ;;
        "designing-frontend") echo "フロントエンドUI/UXコンポーネント" ;;
        "developing-go") echo "Go開発ガイド" ;;
        "developing-python") echo "Python開発ガイド" ;;
        "developing-bash") echo "Bash shell scripting and automation (fundamentals, I/O, process control, testing, security, patterns)" ;;
        "developing-terraform") echo "Terraform IaC開発" ;;
        "managing-docker") echo "Docker開発環境・コンテナ管理" ;;
        "writing-latex") echo "LaTeX文書作成（日本語対応）" ;;
        "developing-fullstack-javascript") echo "NestJS/Express フルスタックJS" ;;
        "automating-browser") echo "Browser Agent CLI ブラウザ操作自動化" ;;
        "testing-e2e-with-playwright") echo "Playwright E2Eテスト設計・実装" ;;
        "implementing-opentelemetry") echo "OpenTelemetry 分散トレーシング" ;;
        "building-adk-agents") echo "Google ADK AIエージェント開発" ;;
        "building-nextjs-saas") echo "Next.js SaaSアプリケーション構築" ;;
        "implementing-dynamic-authorization") echo "Cedar/ABAC/ReBAC 動的認可" ;;
        "searching-web") echo "gemini CLI によるWeb検索" ;;
        "applying-design-guidelines") echo "UI/UX設計原則（理論）" ;;
        "applying-behavior-design") echo "行動変容デザイン（CREATEファネル）" ;;
        "implementing-design") echo "Figmaデザイン→コード変換" ;;
        "avoiding-sql-antipatterns") echo "SQLアンチパターン回避（25パターン）" ;;
        "understanding-database-internals") echo "DB内部構造（ストレージエンジン・分散システム）" ;;
        "designing-relational-databases") echo "リレーショナルDB設計（エンティティ・ER図・正規化・最適化・PostgreSQL実装ガイド）" ;;
        "designing-monitoring") echo "監視・オブザーバビリティ設計" ;;
        "developing-mcp") echo "MCP（Model Context Protocol）開発" ;;
        "developing-google-cloud") echo "Google Cloud 開発・セキュリティ（Cloud Run + IAM/VPC/KMS/DLP/SCC）" ;;
        "developing-aws") echo "AWS開発（システム設計・サーバーレス・CDK・EKS・SRE・コスト最適化・Bedrock）" ;;
        "architecting-micro-frontends") echo "マイクロフロントエンドアーキテクチャ" ;;
        "integrating-ai-web-apps") echo "AI web app integration with Vercel AI SDK, LangChain.js, and MCP (streaming, RAG, tool calling, structured data)" ;;
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
        PROJECT_SKILLS+=("testing-e2e-with-playwright")
    fi

    # OpenTelemetry チェック（JS）
    if echo "$deps" | grep -q "^@opentelemetry/"; then
        PROJECT_SKILLS+=("implementing-opentelemetry")
    fi

    # AI Web App チェック（Vercel AI SDK / LangChain.js）
    if echo "$deps" | grep -qx "ai" || echo "$deps" | grep -q "^@langchain/"; then
        PROJECT_SKILLS+=("integrating-ai-web-apps")
    fi
}

# TypeScript プロジェクトチェック
check_typescript() {
    if [[ -f "$WORK_DIR/tsconfig.json" ]]; then
        HAS_LANGUAGE_PROJECT=true
        PROJECT_SKILLS+=("mastering-typescript")
    fi
}

# デザインプロジェクトチェック（shadcn/ui + Storybook + Tailwind + Pencil統合）
check_design() {
    # components.json（shadcn/ui）
    if [[ -f "$WORK_DIR/components.json" ]]; then
        HAS_DESIGN_PROJECT=true
        PROJECT_SKILLS+=("designing-frontend")
    fi

    # Storybook
    if find "$WORK_DIR" -maxdepth 3 -name "*.stories.tsx" -o -name "*.stories.ts" 2>/dev/null | grep -q .; then
        HAS_DESIGN_PROJECT=true
        PROJECT_SKILLS+=("designing-frontend")
    fi

    # Tailwind CSS
    if find "$WORK_DIR" -maxdepth 2 -name "tailwind.config.*" 2>/dev/null | grep -q .; then
        HAS_DESIGN_PROJECT=true
    fi

    # .pen ファイル（Pencil MCP）
    if find "$WORK_DIR" -maxdepth 3 -name "*.pen" 2>/dev/null | grep -q .; then
        HAS_DESIGN_PROJECT=true
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

# Bash スクリプトプロジェクトチェック
check_bash() {
    # .sh ファイルを検出（hooks/ ディレクトリは除外）
    if find "$WORK_DIR" -maxdepth 3 -name "*.sh" ! -path "*/hooks/*" 2>/dev/null | grep -q .; then
        HAS_LANGUAGE_PROJECT=true
        PROJECT_SKILLS+=("developing-bash")
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

# Cloud Run チェック
check_cloud_run() {
    # cloudbuild.yaml
    if [[ -f "$WORK_DIR/cloudbuild.yaml" ]] || [[ -f "$WORK_DIR/cloudbuild.json" ]]; then
        PROJECT_SKILLS+=("developing-google-cloud")
        return
    fi

    # .gcloudignore
    if [[ -f "$WORK_DIR/.gcloudignore" ]]; then
        PROJECT_SKILLS+=("developing-google-cloud")
        return
    fi

    # package.json の @google-cloud パッケージ
    local package_json="$WORK_DIR/package.json"
    if [[ -f "$package_json" ]]; then
        local deps
        deps=$(jq -r '(.dependencies // {} | keys[]) , (.devDependencies // {} | keys[])' "$package_json" 2>/dev/null) || return
        if echo "$deps" | grep -q "^@google-cloud/"; then
            PROJECT_SKILLS+=("developing-google-cloud")
        fi
    fi
}

# ライティングプロジェクトチェック（LaTeX等）
check_writing() {
    if find "$WORK_DIR" -maxdepth 3 -name "*.tex" 2>/dev/null | grep -q .; then
        HAS_WRITING_PROJECT=true
        PROJECT_SKILLS+=("writing-latex")
    fi
}

# Playwright 設定ファイルチェック
check_playwright_config() {
    if find "$WORK_DIR" -maxdepth 2 -name "playwright.config.*" 2>/dev/null | grep -q .; then
        PROJECT_SKILLS+=("testing-e2e-with-playwright")
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

# AWS プロジェクトチェック
check_aws() {
    # CDK プロジェクト
    if [[ -f "$WORK_DIR/cdk.json" ]]; then
        PROJECT_SKILLS+=("developing-aws")
        return
    fi

    # SAM プロジェクト
    if [[ -f "$WORK_DIR/samconfig.toml" ]] || [[ -f "$WORK_DIR/template.yaml" ]] || [[ -f "$WORK_DIR/template.yml" ]]; then
        PROJECT_SKILLS+=("developing-aws")
        return
    fi

    # Serverless Framework
    if [[ -f "$WORK_DIR/serverless.yml" ]] || [[ -f "$WORK_DIR/serverless.yaml" ]]; then
        PROJECT_SKILLS+=("developing-aws")
        return
    fi

    # CodeBuild
    if [[ -f "$WORK_DIR/buildspec.yml" ]]; then
        PROJECT_SKILLS+=("developing-aws")
        return
    fi

    # package.json の AWS SDK / CDK パッケージ
    local package_json="$WORK_DIR/package.json"
    if [[ -f "$package_json" ]]; then
        local deps
        deps=$(jq -r '(.dependencies // {} | keys[]) , (.devDependencies // {} | keys[])' "$package_json" 2>/dev/null) || return
        if echo "$deps" | grep -qE '^(@aws-sdk/|aws-cdk|@aws-cdk/)'; then
            PROJECT_SKILLS+=("developing-aws")
            return
        fi
    fi

    # Python AWS依存関係（boto3, aws-cdk-lib）
    local deps_content=""
    if [[ -f "$WORK_DIR/pyproject.toml" ]]; then
        deps_content+=$(cat "$WORK_DIR/pyproject.toml" 2>/dev/null)
    fi
    if [[ -f "$WORK_DIR/requirements.txt" ]]; then
        deps_content+=$(cat "$WORK_DIR/requirements.txt" 2>/dev/null)
    fi
    if [[ -n "$deps_content" ]] && echo "$deps_content" | grep -qE "(boto3|aws-cdk-lib|aws-lambda-powertools)"; then
        PROJECT_SKILLS+=("developing-aws")
    fi
}

# Cedar ポリシーファイルチェック
check_cedar() {
    if find "$WORK_DIR" -maxdepth 3 -name "*.cedar" 2>/dev/null | grep -q .; then
        PROJECT_SKILLS+=("implementing-dynamic-authorization")
    fi
}

# データベースプロジェクトチェック
check_database() {
    # Prisma
    if find "$WORK_DIR" -maxdepth 3 -name "schema.prisma" 2>/dev/null | grep -q .; then
        HAS_DATABASE_PROJECT=true
        return
    fi

    # SQLファイル
    if find "$WORK_DIR" -maxdepth 3 -name "*.sql" 2>/dev/null | grep -q .; then
        HAS_DATABASE_PROJECT=true
        return
    fi

    # Knex / Drizzle
    if find "$WORK_DIR" -maxdepth 2 -name "knexfile.*" -o -name "drizzle.config.*" 2>/dev/null | grep -q .; then
        HAS_DATABASE_PROJECT=true
        return
    fi

    # package.json の DB パッケージチェック
    local package_json="$WORK_DIR/package.json"
    if [[ -f "$package_json" ]]; then
        local deps
        deps=$(jq -r '(.dependencies // {} | keys[]) , (.devDependencies // {} | keys[])' "$package_json" 2>/dev/null) || return
        if echo "$deps" | grep -qE '^(prisma|@prisma/client|typeorm|sequelize|drizzle-orm|knex|better-sqlite3|pg|mysql2)$'; then
            HAS_DATABASE_PROJECT=true
        fi
    fi
}

# オブザーバビリティプロジェクトチェック
check_observability() {
    # package.json の OpenTelemetry はcheck_package_jsonで個別検出済み
    # ここではグループフラグのみ設定

    local package_json="$WORK_DIR/package.json"
    if [[ -f "$package_json" ]]; then
        local deps
        deps=$(jq -r '(.dependencies // {} | keys[]) , (.devDependencies // {} | keys[])' "$package_json" 2>/dev/null) || return
        if echo "$deps" | grep -q "^@opentelemetry/"; then
            HAS_OBSERVABILITY_PROJECT=true
        fi
    fi

    # Python OpenTelemetry
    local deps_content=""
    if [[ -f "$WORK_DIR/pyproject.toml" ]]; then
        deps_content+=$(cat "$WORK_DIR/pyproject.toml" 2>/dev/null)
    fi
    if [[ -f "$WORK_DIR/requirements.txt" ]]; then
        deps_content+=$(cat "$WORK_DIR/requirements.txt" 2>/dev/null)
    fi
    if [[ -n "$deps_content" ]] && echo "$deps_content" | grep -q "opentelemetry-"; then
        HAS_OBSERVABILITY_PROJECT=true
    fi

    # Prometheus/Grafana設定
    if [[ -f "$WORK_DIR/prometheus.yml" ]] || [[ -d "$WORK_DIR/grafana" ]]; then
        HAS_OBSERVABILITY_PROJECT=true
    fi
}

# MCP開発プロジェクトチェック
check_mcp_dev() {
    # package.json
    local package_json="$WORK_DIR/package.json"
    if [[ -f "$package_json" ]]; then
        local deps
        deps=$(jq -r '(.dependencies // {} | keys[]) , (.devDependencies // {} | keys[])' "$package_json" 2>/dev/null) || return
        if echo "$deps" | grep -qE '^(@modelcontextprotocol/sdk|@modelcontextprotocol/server)$'; then
            HAS_MCP_DEV_PROJECT=true
        fi
    fi

    # Python MCP
    local deps_content=""
    if [[ -f "$WORK_DIR/pyproject.toml" ]]; then
        deps_content+=$(cat "$WORK_DIR/pyproject.toml" 2>/dev/null)
    fi
    if [[ -f "$WORK_DIR/requirements.txt" ]]; then
        deps_content+=$(cat "$WORK_DIR/requirements.txt" 2>/dev/null)
    fi
    if [[ -n "$deps_content" ]] && echo "$deps_content" | grep -qE "(mcp|fastmcp)"; then
        HAS_MCP_DEV_PROJECT=true
    fi
}

# 検出実行
check_package_json
check_typescript
check_design
check_playwright_config
check_go
check_python
check_python_deps
check_bash
check_terraform
check_docker
check_cloud_run
check_aws
check_writing
check_cedar
check_database
check_observability
check_mcp_dev

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

# 🔵 Skill Groups セクション（グループ検出時のみ）
HAS_ANY_GROUP=false

# グループが1つでも検出されているかチェック
if [[ "$HAS_WRITING_PROJECT" == "true" ]] || [[ "$HAS_DESIGN_PROJECT" == "true" ]] || \
   [[ "$HAS_DATABASE_PROJECT" == "true" ]] || [[ "$HAS_OBSERVABILITY_PROJECT" == "true" ]] || \
   [[ "$HAS_MCP_DEV_PROJECT" == "true" ]]; then
    HAS_ANY_GROUP=true
fi

if [[ "$HAS_ANY_GROUP" == "true" ]]; then
    PROMPT_TEXT+="

### 🔵 Skill Groups (Auto-detected)
"

    # ✏️ Writing グループ
    if [[ "$HAS_WRITING_PROJECT" == "true" ]]; then
        PROMPT_TEXT+="
#### ✏️ Writing (.tex検出)
"
        for skill in "${WRITING_SKILLS[@]}"; do
            desc=$(get_skill_description "$skill")
            if [[ -n "$desc" ]]; then
                PROMPT_TEXT+="- \`$skill\` - $desc
"
            else
                PROMPT_TEXT+="- \`$skill\`
"
            fi
        done
    fi

    # 🎨 Design グループ
    if [[ "$HAS_DESIGN_PROJECT" == "true" ]]; then
        PROMPT_TEXT+="
#### 🎨 Design (コンポーネント/デザイン検出)
"
        for skill in "${DESIGN_SKILLS[@]}"; do
            desc=$(get_skill_description "$skill")
            if [[ -n "$desc" ]]; then
                PROMPT_TEXT+="- \`$skill\` - $desc
"
            else
                PROMPT_TEXT+="- \`$skill\`
"
            fi
        done
    fi

    # 🗄️ Database グループ
    if [[ "$HAS_DATABASE_PROJECT" == "true" ]]; then
        PROMPT_TEXT+="
#### 🗄️ Database (DB関連検出)
"
        for skill in "${DATABASE_SKILLS[@]}"; do
            desc=$(get_skill_description "$skill")
            if [[ -n "$desc" ]]; then
                PROMPT_TEXT+="- \`$skill\` - $desc
"
            else
                PROMPT_TEXT+="- \`$skill\`
"
            fi
        done
    fi

    # 📊 Observability グループ
    if [[ "$HAS_OBSERVABILITY_PROJECT" == "true" ]]; then
        PROMPT_TEXT+="
#### 📊 Observability (監視・可観測性検出)
"
        for skill in "${OBSERVABILITY_SKILLS[@]}"; do
            desc=$(get_skill_description "$skill")
            if [[ -n "$desc" ]]; then
                PROMPT_TEXT+="- \`$skill\` - $desc
"
            else
                PROMPT_TEXT+="- \`$skill\`
"
            fi
        done
    fi

    # 🔌 MCP Development グループ
    if [[ "$HAS_MCP_DEV_PROJECT" == "true" ]]; then
        PROMPT_TEXT+="
#### 🔌 MCP Development (MCP SDK検出)
"
        for skill in "${MCP_DEV_SKILLS[@]}"; do
            desc=$(get_skill_description "$skill")
            if [[ -n "$desc" ]]; then
                PROMPT_TEXT+="- \`$skill\` - $desc
"
            else
                PROMPT_TEXT+="- \`$skill\`
"
            fi
        done
    fi
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
