# promptfoo によるLLM評価・レッドチーミング

## Overview

promptfooはLLMアプリケーションの評価・レッドチーミングのためのOSSツール。YAML宣言的テストケース、40以上のプロバイダー統合、134以上のレッドチーミングプラグインを提供。

開発ワークフロー（5フェーズ）:
1. テストケース定義（コアユースケース + 失敗モード）
2. 評価設定（プロンプト、テスト、プロバイダー）
3. 評価実行・出力記録
4. 結果分析（自動採点 or 手動レビュー）
5. フィードバックループ（テストケース拡充）

## Quick Start

### インストール
- `npm install -g promptfoo` (グローバル)
- `npx promptfoo@latest` (インストール不要)
- `brew install promptfoo`
- 要件: Node.js 20.20+ or 22.22+

### 初期化・初回実行
```bash
promptfoo init           # promptfooconfig.yaml生成
promptfoo eval           # 評価実行
promptfoo view           # 結果UI表示
```

## Configuration (promptfooconfig.yaml)

### 基本構造
```yaml
description: "評価の説明"
tags: { env: production }
prompts:
  - file://prompt1.txt
  - "インラインプロンプト {{variable}}"
providers:
  - openai:gpt-4
  - anthropic:messages:claude-sonnet-4-5-20250929
tests:
  - vars:
      language: French
      input: Hello world
    assert:
      - type: contains
        value: bonjour
defaultTest:
  vars:
    shared_var: value
  assert:
    - type: llm-rubric
      value: does not refer to itself as AI
evaluateOptions:
  maxConcurrency: 4
  cache: true
outputPath: results.json
```

### 主要設定プロパティ

| プロパティ | 型 | 必須 | 説明 |
|-----------|------|------|------|
| `description` | string | No | 評価の説明 |
| `providers` | string/array/object | Yes | LLM API（エイリアス: `targets`） |
| `prompts` | string/array | Yes | プロンプトテンプレート |
| `tests` | string/TestCase[] | Yes | テストケースまたはファイルパス |
| `defaultTest` | Partial<TestCase> | No | 全テストのデフォルトプロパティ |
| `evaluateOptions` | Object | No | 実行パラメータ |
| `scenarios` | Scenario[] | No | グループ化テストシナリオ |
| `extensions` | string[] | No | ライフサイクルフック |
| `outputPath` | string | No | 結果出力ファイル |

### テストケースプロパティ

| プロパティ | 説明 |
|-----------|------|
| `description` | テスト内容の説明 |
| `vars` | プロンプト変数（Record or ファイルパス） |
| `provider` | プロバイダーオーバーライド |
| `assert` | バリデーションチェック |
| `threshold` | 最低合格スコア |
| `metadata` | フィルタリング用メタデータ |
| `options.transform` | アサーション前の出力変換 |
| `options.storeOutputAs` | 後続テスト用に出力を変数保存 |

### 変数の種類
- **文字列**: `var1: "some value"`
- **オブジェクト**: ネスト可、ドット記法でアクセス
- **配列**: 組み合わせテスト自動生成
- **ファイル参照**: `file://path/to/file.txt`
- **動的生成**: JS (`file://script.js`), Python (`file://script.py`)

**組み合わせテスト**:
```yaml
tests:
  - vars:
      language: [French, German, Spanish]
      input: ['Hello world', 'Good morning']
# 6テスト自動生成（3 × 2）
```

### テンプレート構文（Nunjucks）
- `{{ variable }}` — 変数展開
- `{{ env.VAR_NAME }}` — 環境変数
- `{{ variable | dump }}` — JSON直列化
- `{{ list | join(', ') }}` — 配列結合

### Transform（変換）

出力変換（アサーション前に適用）:
```yaml
options:
  transform: output.toUpperCase()
  # ファイルベース:
  transform: file://transform.js:customTransform
```

変数変換（プロンプト挿入前）:
```yaml
options:
  transformVars: |
    return { uppercase_topic: vars.topic.toUpperCase() };
```

Transform実行順序:
1. Provider `transformResponse`（API構造正規化）
2. Test `options.transform`（アサーション用変換）
3. `contextTransform`（コンテキスト抽出）
4. アサーションレベル `transform`（最終）

### シナリオ

データとテストをグループ化して組み合わせ実行:
```yaml
scenarios:
  - description: "翻訳テスト"
    config:
      - vars: { language: French }
      - vars: { language: German }
    tests:
      - vars: { input: "Hello" }
        assert:
          - type: contains
            value: "{{expected}}"
  - file://scenarios/*.yaml  # globサポート
```

### テスト整理
```yaml
tests:
  - file://tests/tests2.yaml
  - file://tests/*              # globパターン
```
YAML, JSON, JSONL, CSV, TypeScript/JavaScript, Google Sheets に対応。

### YAML参照
```yaml
tests:
  - assert:
      - $ref: '#/assertionTemplates/startsUpperCase'
assertionTemplates:
  startsUpperCase:
    type: javascript
    value: output[0] === output[0].toUpperCase()
```

### EvaluateOptions

| プロパティ | デフォルト | 説明 |
|-----------|----------|------|
| `maxConcurrency` | 4 | 同時API呼び出し数 |
| `repeat` | 1 | テスト繰り返し回数 |
| `delay` | 0 | 各呼び出し後の遅延(ms) |
| `cache` | true | ディスクキャッシュ使用 |
| `timeoutMs` | 0 | テスト毎タイムアウト(0=無制限) |

### Extension Hooks
```yaml
extensions:
  - file://hooks.js:extensionHook
```
ライフサイクルイベント: `beforeAll`, `afterAll`, `beforeEach`, `afterEach`

## Assertions（アサーション）

アサーションはLLM出力を検証するルール。3カテゴリに大別:

### 基本構造
```yaml
assert:
  - type: <assertion-type>
    value: <expected-value>
    threshold: <number>      # 閾値
    weight: <number>         # 重要度（デフォルト1.0）
    provider: <string>       # モデルグレード用
    metric: <string>         # UI集計ラベル
    transform: <string>      # 出力前処理
```

### 決定的アサーション（主要）

| タイプ | 説明 |
|--------|------|
| `equals` / `iequals` | 完全一致（大文字小文字区別/不区別） |
| `contains` / `icontains` | 部分文字列チェック |
| `contains-all` / `contains-any` | 全部/いずれかを含む |
| `regex` | 正規表現マッチ |
| `starts-with` | プレフィックスチェック |
| `is-json` | JSON有効性（スキーマ検証可） |
| `contains-json` | テキスト中のJSON検証 |
| `cost` | コスト閾値超過チェック |
| `latency` | レイテンシー閾値超過チェック |
| `javascript` | カスタムJS検証 |
| `python` | カスタムPython検証 |

**否定**: `not-` プレフィックス（例: `not-equals`, `not-regex`）

### モデルグレードアサーション（主要）

| タイプ | 説明 |
|--------|------|
| `llm-rubric` | 汎用LLMグレーディング |
| `factuality` | 事実準拠チェック |
| `answer-relevance` | クエリ整合性 |
| `select-best` | 出力比較・最良選択 |
| `moderation` | OpenAI モデレーションAPI |

### RAG評価アサーション

| タイプ | 説明 |
|--------|------|
| `context-faithfulness` | 出力がコンテキストに裏付けられるか |
| `context-recall` | 正解がコンテキストに含まれるか |
| `context-relevance` | コンテキストがクエリに関連するか |
| `answer-relevance` | 出力がクエリに対応するか |

詳細は [ASSERTIONS.md](references/ASSERTIONS.md) を参照。

## Providers（プロバイダー）

### 主要プロバイダー

| プロバイダー | フォーマット |
|------------|-------------|
| OpenAI | `openai:chat:<model>`, `openai:responses:<model>` |
| Anthropic | `anthropic:messages:<model>` |
| Google | `google:<model>` |
| Ollama | `ollama:chat:<model>` |
| HTTP API | `https` (カスタムURL) |
| カスタムJS | `file://provider.js` |
| カスタムPython | `file://provider.py` |

### プロバイダー設定例
```yaml
providers:
  - id: openai:chat:gpt-4
    label: "My GPT-4"
    config:
      temperature: 0.7
      max_tokens: 2048

  - id: anthropic:messages:claude-sonnet-4-5-20250929
    config:
      temperature: 0.0
      max_tokens: 512

  - id: https
    config:
      url: 'https://api.example.com/generate'
      method: POST
      headers:
        Authorization: 'Bearer {{env.API_TOKEN}}'
      body:
        prompt: '{{prompt}}'
      transformResponse: 'json.choices[0].message.content'
```

詳細は [PROVIDERS.md](references/PROVIDERS.md) を参照。

## Red Teaming（レッドチーミング）

LLM脆弱性を体系的に発見するための敵対的テスト。

### 基本ワークフロー
```bash
promptfoo redteam init     # 設定初期化
promptfoo redteam run      # 生成 + 評価
promptfoo redteam report   # 結果表示
```

### 基本設定
```yaml
targets:
  - id: openai:gpt-4
    label: my-chatbot
redteam:
  purpose: |
    Healthcare assistant for patients.
  injectVar: user_input
  numTests: 10
  plugins:
    - 'harmful:hate'
    - id: 'policy'
      config:
        policy: "Must not provide investment advice."
  strategies:
    - jailbreak:meta
    - jailbreak:hydra
    - prompt-injection
```

### プラグインカテゴリ（134+）
- **有害コンテンツ**: `harmful:hate`, `harmful:cybercrime`, `harmful:self-harm` 等
- **プライバシー**: `pii:direct`, `pii:api-db`, `cross-session-leak`, `data-exfil`
- **セキュリティ**: `sql-injection`, `ssrf`, `shell-injection`, `prompt-extraction`
- **ブランド**: `competitors`, `hallucination`, `excessive-agency`, `off-topic`
- **コンプライアンス**: `contracts`, COPPA, FERPA, healthcare等
- **カスタム**: `policy`（カスタムポリシー）, `intent`（特定動作）

### 戦略
- **静的**: `base64`, `rot13`, `leetspeak`, `homoglyph`
- **動的**: `jailbreak`, `jailbreak:meta`, `jailbreak:composite`, `best-of-n`
- **マルチターン**: `crescendo`, `goat`, `jailbreak:hydra`

### フレームワーク
`owasp:llm`, `nist:ai:measure`, `mitre:atlas`, `iso:42001`, `gdpr`, `eu:ai-act`

詳細は [RED-TEAMING.md](references/RED-TEAMING.md) を参照。

## CLI Commands

### コアコマンド

| コマンド | 説明 |
|---------|------|
| `promptfoo eval` | 評価実行 |
| `promptfoo init` | プロジェクト初期化 |
| `promptfoo view` | 結果UI表示 |
| `promptfoo share [evalId]` | 共有URL生成 |
| `promptfoo cache clear` | キャッシュクリア |
| `promptfoo validate` | 設定スキーマ検証 |
| `promptfoo retry <evalId>` | ERROR結果リトライ |

### 主要 eval フラグ
- `-c, --config <paths...>`: 設定ファイル指定
- `-o, --output <paths...>`: 出力形式（csv, json, html, yaml）
- `-j, --max-concurrency <n>`: 同時API呼び出し数
- `--no-cache`: キャッシュ無効
- `--watch`: 変更時自動再実行
- `--filter-failing <path>`: 失敗テストのみ再実行

### Red Teamコマンド

| コマンド | 説明 |
|---------|------|
| `promptfoo redteam init` | 初期化 |
| `promptfoo redteam run` | 生成 + 評価 |
| `promptfoo redteam report` | 結果UI |
| `promptfoo redteam discover` | ターゲット探索 |
| `promptfoo redteam plugins` | プラグイン一覧 |

終了コード: `100` = テスト失敗, `1` = その他のエラー

## Caching

- **場所**: `~/.promptfoo/cache`
- **TTL**: 14日（デフォルト）
- **無効化**: `--no-cache` or `evaluateOptions: { cache: false }`
- **クリア**: `promptfoo cache clear`
- キャッシュキー: provider ID + prompt + config + context vars の複合
- エラーはキャッシュされない（リトライ可能）

## CI/CD統合

詳細は [CI-CD.md](references/CI-CD.md) を参照。

基本パターン（GitHub Actions）:
```yaml
- uses: actions/setup-node@v4
  with:
    node-version: 22
- run: npx promptfoo@latest eval -c promptfooconfig.yaml -o results.json
  env:
    OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
```

## 主要環境変数

| 変数 | 説明 |
|------|------|
| `OPENAI_API_KEY` | OpenAI認証 |
| `ANTHROPIC_API_KEY` | Anthropic認証 |
| `GOOGLE_API_KEY` | Google AI認証 |
| `PROMPTFOO_CACHE_ENABLED` | キャッシュ有効/無効 |
| `PROMPTFOO_CACHE_TTL` | キャッシュ有効期限 |
| `PROMPTFOO_FAILED_TEST_EXIT_CODE` | カスタム終了コード（デフォルト100） |
| `PROMPTFOO_PYTHON` | Python実行パス |
| `PROMPTFOO_DISABLE_TEMPLATING` | Nunjucks無効化 |
| `PROMPTFOO_RETRY_5XX` | サーバーエラーリトライ |
| `OLLAMA_BASE_URL` | OllamaサーバーURL |
| `LOG_LEVEL` | debug で詳細ログ |

## Best Practices

1. **決定的アサーションから始める**（contains, regex, is-json）
2. **モデルグレードをレイヤーする**（llm-rubric, factuality）
3. **`defaultTest`でDRY化**（共通アサーション・設定）
4. **キャッシュを活用**してコスト削減
5. **RAGは検索と生成を分離テスト**
6. **Transformで出力を正規化**してからアサーション
7. **Red teamは`jailbreak:meta` + `jailbreak:hydra`から開始**
8. **`purpose`を明確に定義**して攻撃・採点品質を向上
9. **カスタムpolicyでビジネス制約をテスト**
10. **CI/CDに品質ゲートとして統合**
11. **`--watch`で高速イテレーション**
12. **`$ref`でアサーションテンプレートを再利用**

## 関連ドキュメント

- [ASSERTIONS.md](references/ASSERTIONS.md) — 全アサーション詳細リファレンス
- [PROVIDERS.md](references/PROVIDERS.md) — プロバイダー設定詳細
- [RED-TEAMING.md](references/RED-TEAMING.md) — レッドチーミング詳細
- [CI-CD.md](references/CI-CD.md) — CI/CD統合パターン
