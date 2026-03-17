# CI/CD統合リファレンス

## Overview

promptfooをCI/CDパイプラインに統合することで、LLM品質の継続的監視とリグレッション防止を実現する。
JSON出力とexit codeを活用した品質ゲートにより、パイプラインの一部として自動的に品質チェックを行える。

## GitHub Actions

### 基本設定

```yaml
name: LLM Evaluation
on:
  push:
    branches: [main]
  pull_request:

jobs:
  evaluate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 22
      - run: npx promptfoo@latest eval -c promptfooconfig.yaml -o results.json
        env:
          OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
      - uses: actions/upload-artifact@v4
        with:
          name: eval-results
          path: results.json
```

### キャッシュ設定

API呼び出しコストを削減するためキャッシュを活用:

```yaml
      - uses: actions/cache@v4
        with:
          path: ~/.cache/promptfoo
          key: promptfoo-cache-${{ github.sha }}
          restore-keys: |
            promptfoo-cache-${{ github.ref }}
            promptfoo-cache-
```

### 品質ゲート

テスト合格率に基づいてパイプラインの成否を制御:

```yaml
      - name: Run evaluation
        run: npx promptfoo@latest eval -c promptfooconfig.yaml -o results.json

      - name: Check quality gate
        run: |
          TOTAL=$(jq '.results.stats.total' results.json)
          SUCCESSES=$(jq '.results.stats.successes' results.json)
          PASS_RATE=$(echo "scale=2; $SUCCESSES * 100 / $TOTAL" | bc)
          echo "Pass rate: ${PASS_RATE}%  (${SUCCESSES}/${TOTAL})"
          if (( $(echo "$PASS_RATE < 90" | bc -l) )); then
            echo "::error::Quality gate failed: pass rate ${PASS_RATE}% is below threshold 90%"
            exit 1
          fi
          echo "::notice::Quality gate passed: ${PASS_RATE}%"
```

### マトリクス戦略（複数モデル並列テスト）

```yaml
jobs:
  evaluate:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        model: [gpt-4o, claude-sonnet-4-5-20250929, gemini-2.5-pro]
      fail-fast: false    # 1モデル失敗でも他モデルのテストを継続
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 22
      - name: Run evaluation for ${{ matrix.model }}
        run: |
          npx promptfoo@latest eval \
            -c config-${{ matrix.model }}.yaml \
            -o results-${{ matrix.model }}.json
        env:
          OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
          GOOGLE_API_KEY: ${{ secrets.GOOGLE_API_KEY }}
      - uses: actions/upload-artifact@v4
        with:
          name: eval-results-${{ matrix.model }}
          path: results-${{ matrix.model }}.json
```

### スケジュール実行（定期レッドチーム）

```yaml
name: Weekly Red Team Scan
on:
  schedule:
    - cron: '0 0 * * 1'  # 毎週月曜 00:00 UTC
  workflow_dispatch:      # 手動トリガーも可能

jobs:
  redteam:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 22
      - name: Run red team scan
        run: npx promptfoo@latest redteam run -c redteam.yaml -o redteam-results.json
        env:
          OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
      - uses: actions/upload-artifact@v4
        with:
          name: redteam-results-${{ github.run_id }}
          path: redteam-results.json
          retention-days: 90    # 3ヶ月保持
      - name: Create issue if vulnerabilities found
        if: failure()
        uses: actions/github-script@v7
        with:
          script: |
            await github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: `Red Team: Vulnerabilities detected (${new Date().toISOString().split('T')[0]})`,
              body: 'Weekly red team scan detected potential vulnerabilities. Check the workflow artifacts.',
              labels: ['security', 'llm-safety']
            })
```

### PR差分レポート

プルリクエストでモデル変更の影響を可視化:

```yaml
      - name: Post results as PR comment
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const results = JSON.parse(fs.readFileSync('results.json', 'utf8'));
            const stats = results.results.stats;
            const passRate = (stats.successes / stats.total * 100).toFixed(1);

            await github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body: `## LLM Evaluation Results\n\n` +
                    `| Metric | Value |\n|--------|-------|\n` +
                    `| Pass Rate | ${passRate}% |\n` +
                    `| Total Tests | ${stats.total} |\n` +
                    `| Passed | ${stats.successes} |\n` +
                    `| Failed | ${stats.failures} |`
            });
```

## GitLab CI

```yaml
stages:
  - evaluate
  - redteam

variables:
  PROMPTFOO_CACHE_DIR: "$CI_PROJECT_DIR/.promptfoo-cache"

llm-eval:
  image: node:22-slim
  stage: evaluate
  script:
    - npx promptfoo@latest eval -c promptfooconfig.yaml -o results.json --output-format json
    - npx promptfoo@latest eval -c promptfooconfig.yaml -o junit.xml --output-format junit
  artifacts:
    reports:
      junit: junit.xml
    paths:
      - results.json
    expire_in: 30 days
  cache:
    key: $CI_COMMIT_REF_SLUG
    paths:
      - $PROMPTFOO_CACHE_DIR
  variables:
    OPENAI_API_KEY: $OPENAI_API_KEY
    ANTHROPIC_API_KEY: $ANTHROPIC_API_KEY

weekly-redteam:
  image: node:22-slim
  stage: redteam
  only:
    - schedules
  script:
    - npx promptfoo@latest redteam run -c redteam.yaml -o redteam-results.json
  artifacts:
    paths:
      - redteam-results.json
    expire_in: 90 days
  variables:
    OPENAI_API_KEY: $OPENAI_API_KEY
```

## Jenkins

```groovy
pipeline {
    agent any

    environment {
        OPENAI_API_KEY = credentials('openai-api-key')
        ANTHROPIC_API_KEY = credentials('anthropic-api-key')
    }

    stages {
        stage('Setup') {
            steps {
                sh 'npm install -g promptfoo'
            }
        }

        stage('Evaluate') {
            steps {
                sh 'promptfoo eval -c promptfooconfig.yaml -o results.json'
            }
        }

        stage('Quality Gate') {
            steps {
                script {
                    def results = readJSON file: 'results.json'
                    def total = results.results.stats.total
                    def successes = results.results.stats.successes
                    def passRate = (successes / total) * 100

                    echo "Pass rate: ${passRate.round(1)}% (${successes}/${total})"

                    if (passRate < 90) {
                        error "Quality gate failed: pass rate ${passRate.round(1)}% is below threshold 90%"
                    }
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'results.json', fingerprint: true
            junit allowEmptyResults: true, testResults: 'junit.xml'
        }
        failure {
            emailext(
                subject: "LLM Quality Gate Failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                body: "Pass rate fell below threshold. See ${env.BUILD_URL}",
                to: '${DEFAULT_RECIPIENTS}'
            )
        }
    }
}
```

## 出力フォーマット

| フォーマット | オプション | 用途 |
|------------|---------|------|
| JSON | `-o results.json` | 品質ゲート・後続処理 |
| JUnit XML | `-o junit.xml` | CI/CDテストレポート統合 |
| CSV | `-o results.csv` | スプレッドシート分析 |
| HTML | `-o report.html` | 人間が読むレポート |
| YAML | `-o results.yaml` | 設定管理ツール連携 |

```bash
# 複数フォーマット同時出力
promptfoo eval -c config.yaml \
  -o results.json \
  -o junit.xml \
  -o report.html
```

## セキュリティ環境変数

CI/CD環境でのデータ保護:

| 変数 | 値 | 説明 |
|------|-----|------|
| `PROMPTFOO_STRIP_RESPONSE_OUTPUT` | `true` | LLM出力をCI結果から除去（機密漏洩防止） |
| `PROMPTFOO_STRIP_TEST_VARS` | `true` | テスト変数をCI結果から除去 |
| `PROMPTFOO_DISABLE_TELEMETRY` | `1` | テレメトリを無効化 |
| `PROMPTFOO_CACHE_PATH` | `~/.cache/promptfoo` | キャッシュディレクトリのカスタマイズ |

```yaml
# GitHub Actions での設定例
env:
  PROMPTFOO_STRIP_RESPONSE_OUTPUT: "true"
  PROMPTFOO_STRIP_TEST_VARS: "true"
  PROMPTFOO_DISABLE_TELEMETRY: "1"
```

## MCP Server統合

promptfooはMCPサーバーとしても動作可能。CI/CD外部からの評価実行に活用:

```bash
# MCPサーバーとして起動
promptfoo mcp --transport stdio

# 利用可能なツール
# - list_evaluations        評価一覧の取得
# - get_evaluation_details  評価詳細の取得
# - run_evaluation          評価の実行
# - share_evaluation        評価結果の共有
# - redteam_run             レッドチームの実行
```

## Best Practices

1. **キャッシュを活用** — `~/.cache/promptfoo` をCI間で共有してAPI呼び出しコストを削減
2. **`--fail-on-error`** — テスト失敗をCIエラーとして確実に報告
3. **マトリクス戦略** — 複数モデルを並列テストして比較
4. **スケジュール実行** — 定期的なレッドチームスキャン（週次/月次）で継続的な安全性監視
5. **セキュリティ環境変数** — 出力・変数をストリップして機密情報の漏洩を防止
6. **品質ゲート** — JSON出力をパースして合格率を数値で検証（閾値は用途に応じて設定）
7. **アーティファクト保存** — 結果JSONを保存して履歴追跡・トレンド分析
8. **シークレット管理** — APIキーは必ず環境変数/シークレットで管理（ハードコード禁止）
9. **JUnit出力** — CI/CDテストレポートとしてJUnit XML形式を活用
10. **PRコメント** — 評価結果を自動的にPRにコメントして変更の影響を可視化
