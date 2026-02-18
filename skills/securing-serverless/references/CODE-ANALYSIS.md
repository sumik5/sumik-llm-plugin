# コード分析リファレンス

サーバーレスアプリケーションのセキュリティを確保するには、インフラ設定だけでなく、コードレベルでの脆弱性検証が不可欠です。このリファレンスでは、Semgrepによる静的解析、セキュアなコーディングパターン、依存関係の検証、OSV-Scannerによる脆弱性スキャンなど、コード分析の実践的手法を解説します。

---

## 1. サーバーレスコード分析の重要性

### なぜコード分析が必要か

- **手動レビューの限界**: 人間によるコードレビューは時間がかかり、見落としが発生しやすい
- **自動化による早期検出**: ツールを使用することで、開発プロセスの早い段階でセキュリティ問題を発見できる
- **継続的な保護**: CI/CDパイプラインに組み込むことで、新しいコードが本番環境に到達する前にチェック可能

### コード分析の対象

- **セキュリティ脆弱性**: SQLインジェクション、コードインジェクション、XSS等
- **危険なコーディングパターン**: `eval()`, `exec()` などの動的コード実行
- **ハードコードされた機密情報**: APIキー、パスワード、トークン等
- **依存関係の脆弱性**: 既知の脆弱性を持つパッケージ
- **悪意ある依存関係**: サプライチェーン攻撃による汚染パッケージ

---

## 2. Semgrepによるセキュリティスキャン

### Semgrepとは

Semgrepは、コードのセキュリティ脆弱性と危険なパターンを検出する静的解析ツールです。プログラミング言語のセマンティクスを理解し、単純なテキストマッチングよりも高度な検出が可能です。

### 基本的な使い方

```bash
# Semgrepのインストール（Python環境）
python3 -m venv venv
source venv/bin/activate
pip install semgrep

# バージョン確認
semgrep --version

# 公式ルールリポジトリのクローン
git clone https://github.com/semgrep/semgrep-rules.git

# JavaScriptファイルのスキャン
semgrep --config=semgrep-rules/javascript src/functions/evaluate.js
```

### プリビルドルールの活用

Semgrepには、一般的なセキュリティベストプラクティスをカバーするプリビルドルールが用意されています：

```bash
# JavaScript向けルールでスキャン
semgrep --config=semgrep-rules/javascript vulnerable-function/src/functions/

# 特定のルールを除外
semgrep --config=semgrep-rules/javascript \
  --exclude-rule=semgrep-rules.javascript.lang.correctness.useless-assignment \
  src/functions/evaluate.js
```

### カスタムルールの作成

プロジェクト固有のセキュリティ要件に対応するため、カスタムルールを作成できます。

#### 例1: eval()の使用を禁止

```yaml
# custom-rules/no-eval.yml
rules:
  - id: no-eval
    patterns:
      - pattern: eval($EXPR)
    message: "Avoid using eval() — dangerous with user input."
    languages: [javascript, typescript]
    severity: ERROR
```

#### 例2: ハードコードされたシークレットの検出

```yaml
# custom-rules/no-hardcoded-keys.yml
rules:
  - id: hardcoded-secret-detection
    languages: [javascript, typescript]
    message: "Possible hardcoded secret or API key"
    severity: ERROR
    pattern: |
      const $VAR = "$SECRET"
    metadata:
      category: security
    condition:
      metavariable-regex:
        metavariable: $VAR
        regex: (?i)(key|secret|token|password)
```

#### カスタムルールの実行

```bash
# カスタムルールでスキャン
semgrep --config=custom-rules src/functions/evaluate.js
```

### Semgrep出力例

```
┌─────────────────┐
│ 2 Code Findings │
└─────────────────┘

    vulnerable-function/src/functions/evaluate.js
   ❯❯❱ custom-rules.hardcoded-secret-detection
          Possible hardcoded secret or API key

            3┆ const HARDCODED_KEY = "67890ghijkl";

   ❯❯❱ custom-rules.no-eval
          Avoid using eval() — dangerous with user input.

           13┆ result = eval(expression);
```

### False PositiveとTrue Positive

- **True Positive**: 実際の脆弱性を正しく検出したもの
- **False Positive**: 誤検出。リスクのないコードを問題として報告したもの

False Positiveへの対応：
- ルールを調整して検出精度を向上させる
- `--exclude-rule` で特定のルールを無効化（プロジェクト全体で誤検出が多い場合のみ）

---

## 3. セキュアなサーバーレスコードの書き方

### コードインジェクション対策

#### 危険なパターン

```javascript
// ❌ 脆弱: eval()による動的コード実行
const { app } = require('@azure/functions');

app.http('evaluate', {
  handler: async (request, context) => {
    const expression = await request.text();
    let result;
    try {
      result = eval(expression);  // 任意のコード実行が可能
    } catch (err) {
      result = `Error: ${err.message}`;
    }
    return { body: `Evaluation result: ${result}` };
  }
});
```

この実装では、以下のような攻撃が可能になります（実際に使用しないでください）：

```javascript
// ファイルシステムの読み取り
require('fs').readdirSync('./')

// 環境変数の取得
JSON.stringify(process.env)

// コマンド実行（サーバー側で実行される危険なコード）
require("child_process").execSync("malicious-command")
```

#### セキュアなパターン

```javascript
// ✅ 安全: expr-evalによる制限された評価
const { app } = require('@azure/functions');
const { Parser } = require('expr-eval');

app.http('evaluate', {
  handler: async (request, context) => {
    const expression = await request.text() || '"No expression provided"';

    let result;
    try {
      const parser = new Parser({
        operators: {
          add: true,
          subtract: true,
          multiply: true,
          divide: true,
          power: false,      // 危険な演算は無効化
          factorial: false
        }
      });
      result = parser.evaluate(expression);
    } catch (err) {
      result = `Error: ${err.message}`;
    }

    return { body: `Evaluation result: ${result}` };
  }
});
```

### 安全な入力処理のパターン

#### Allowlistベースのバリデーション

```javascript
// ✅ 許可リストによる入力検証
const ALLOWED_OPERATIONS = ['add', 'subtract', 'multiply', 'divide'];

function validateInput(input) {
  // 数式の構造を検証
  const tokens = input.match(/\d+|[+\-*/]/g);
  if (!tokens) {
    throw new Error('Invalid expression format');
  }

  // 許可された文字のみを含むか確認
  const validPattern = /^[\d\s+\-*/()]+$/;
  if (!validPattern.test(input)) {
    throw new Error('Expression contains invalid characters');
  }

  return true;
}

// 使用例
try {
  validateInput(userInput);
  const result = safeEvaluate(userInput);
} catch (err) {
  return { body: 'Invalid input', statusCode: 400 };
}
```

### 動的コード実行の回避

以下の関数・メソッドは使用を避けるべき：

- JavaScript: `eval()`, `Function()`, `setTimeout(string)`, `setInterval(string)`
- Python: `eval()`, `exec()`, `compile()`, `__import__()`
- その他: `vm.runInNewContext()` など

### エラーメッセージの一般化

```javascript
// ❌ 実装の詳細が漏洩
catch (err) {
  return { body: `Error: parse error [1:26]: Expected EOF` };
}

// ✅ 一般的なエラーメッセージ
catch (err) {
  return { body: 'Invalid input format', statusCode: 400 };
}
```

---

## 4. 悪意ある依存関係の検出

### サプライチェーン攻撃のリスク

2025年9月のnpmサプライチェーン攻撃では、以下のような事象が発生：

- 複数のメンテナーがフィッシング攻撃により侵害
- 人気ライブラリ（週20億ダウンロード超）に悪意あるバージョンが公開
- `chalk`, `debug`, `ansi-styles`, `strip-ansi` などが影響
- 数時間で削除されたが、その間にダウンロードしたプロジェクトは汚染

### カスタムスクリプトによる検出

#### bad_versions.jsonの準備

```json
{
  "debug": ["4.4.2"],
  "color-convert": ["3.1.1"],
  "backslash": ["0.2.1"],
  "error-ex": ["1.3.3"],
  "simple-swizzle": ["0.2.3"],
  "chalk": ["5.6.1"],
  "ansi-styles": ["6.2.2"]
}
```

#### 検出スクリプトの実装（Ruby例）

```ruby
require 'json'
require 'optparse'

# コマンドライン引数のパース
options = {}
OptionParser.new do |opts|
  opts.on("--project_dir DIR", "Project directory") do |dir|
    options[:project_dir] = dir
  end
  opts.on("--bad_versions FILE", "Bad versions file") do |file|
    options[:bad_versions_file] = file
  end
end.parse!

# lockfileの読み込み
lockfile_path = File.join(options[:project_dir], "package-lock.json")
bad_versions = JSON.parse(File.read(options[:bad_versions_file]))
lockfile = JSON.parse(File.read(lockfile_path))

installed = {}
issues = []

# npm v7+ lockfileのチェック
if lockfile.key?("packages")
  lockfile["packages"].each do |path, data|
    next unless data.is_a?(Hash) && data["version"]

    name = data["name"] || File.basename(path)
    version = data["version"]

    if bad_versions.key?(name)
      installed[name] ||= []
      installed[name] << version unless installed[name].include?(version)

      if bad_versions[name].include?(version)
        issues << "#{name}@#{version}"
      end
    end
  end
end

# 結果レポート
if issues.any?
  puts "\nDetected malicious versions in your lockfile!"
  issues.each { |i| puts " - #{i}" }
  exit 1
else
  puts "\nNo malicious versions detected"
end
```

#### スクリプトの実行

```bash
ruby check_lockfile.rb \
  --project_dir vulnerable-function \
  --bad_versions bad_versions.json
```

### CI/CDパイプラインへの統合

```yaml
# .github/workflows/security-check.yml
name: Security Check
on: [push, pull_request]

jobs:
  check-dependencies:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Check malicious dependencies
        run: |
          ruby check_lockfile.rb \
            --project_dir . \
            --bad_versions bad_versions.json
```

### pre-commitフックでの実行

```bash
#!/bin/bash
# .git/hooks/pre-commit

ruby check_lockfile.rb \
  --project_dir . \
  --bad_versions bad_versions.json

if [ $? -ne 0 ]; then
  echo "Commit blocked: malicious dependencies detected"
  exit 1
fi
```

---

## 5. OSV-Scannerによる脆弱性検出

### OSV-Scannerとは

OSV-Scannerは、Open Source Vulnerabilities (OSV) データベースに対してアプリケーション依存関係をスキャンし、既知の脆弱性を検出するツールです。

### インストールと基本的な使い方

```bash
# バイナリのダウンロード
curl -LO https://github.com/google/osv-scanner/releases/latest/download/osv-scanner_linux_amd64

# 実行可能にする
mv osv-scanner_linux_amd64 osv-scanner
chmod +x osv-scanner

# バージョン確認
./osv-scanner --version
```

### プロジェクトのスキャン

```bash
# 再帰的にプロジェクトをスキャン
./osv-scanner --recursive vulnerable-function/

# JSON形式で出力
./osv-scanner --recursive vulnerable-function/ --format json

# HTML形式でレポート生成
./osv-scanner --recursive vulnerable-function/ --format=html > report.html
```

### スキャン結果の解析

#### CLI出力例

```
Scanning 1 file (only git-tracked) with 182 Code rules:

┌────────────────┐
│ 1 Code Finding │
└────────────────┘

    vulnerable-function/src/functions/evaluate.js
     ❱ semgrep-rules.javascript.browser.security.eval-detected
          Detected the use of eval(). eval() can be dangerous...

           13┆ result = eval(expression);

┌──────────────┐
│ Scan Summary │
└──────────────┘
Total 1 package affected by 1 known vulnerability
(0 Critical, 0 High, 0 Medium, 1 Low) from 1 ecosystem.
1 vulnerability can be fixed.

╭─────────────────────────────────────┬──────┬───────────┬──────────╮
│ OSV URL                             │ CVSS │ ECOSYSTEM │ PACKAGE  │
├─────────────────────────────────────┼──────┼──────────┼──────────┤
│ https://osv.dev/GHSA-gxpj-cx7g-858c │ 3.7  │ npm       │ debug    │
╰─────────────────────────────────────┴──────┴───────────┴──────────╯
```

#### JSON出力例

```json
{
  "packages": [
    {
      "vulnerabilities": [
        {
          "summary": "Regular Expression Denial of Service in debug",
          "details": "Affected versions of `debug` are vulnerable...",
          "severity": [
            {
              "type": "CVSS_V3",
              "score": "CVSS:3.1/AV:N/AC:H/PR:N/UI:N/S:U/C:N/I:N/A:L"
            }
          ]
        }
      ]
    }
  ]
}
```

### npmツールとの連携

```bash
# 依存関係ツリーの表示
npm list debug

# アウトデートなパッケージの確認
npm outdated --json

# 脆弱性レポートの生成
npm audit --verbose
```

### HTMLレポートの活用

HTMLレポートには以下の情報が含まれます：

- 脆弱性のサマリー（Critical/High/Medium/Low）
- 影響を受けるパッケージと推奨される修正バージョン
- CVE/GHSA IDへのリンク
- National Vulnerability Database (NVD) へのリンク
- CWE (Common Weakness Enumeration) 情報

---

## 6. コード分析チェックリスト

### 開発フェーズ

- [ ] Semgrepカスタムルールを作成し、プロジェクト固有のセキュリティ要件を定義
- [ ] `eval()`, `exec()` などの危険な関数を禁止するルールを設定
- [ ] ハードコードされたシークレット検出ルールを有効化
- [ ] 入力バリデーションにallowlistベースのアプローチを採用
- [ ] エラーメッセージを一般化し、実装の詳細を露出しない

### CI/CDパイプライン

- [ ] Semgrepスキャンをpull request時に自動実行
- [ ] OSV-Scannerによる依存関係スキャンを自動化
- [ ] カスタムスクリプトで悪意ある依存関係を検出
- [ ] セキュリティチェック失敗時にビルドを中断
- [ ] スキャン結果をチームに自動通知

### 定期メンテナンス

- [ ] `bad_versions.json` を定期的に更新
- [ ] OSV-Scannerを最新バージョンに保つ
- [ ] 依存関係を定期的に更新（ただし互換性に注意）
- [ ] False Positiveを記録し、ルールを改善
- [ ] セキュリティアドバイザリを監視

### デプロイ前

- [ ] 全てのSemgrepスキャンをパス
- [ ] OSV-Scannerで脆弱性がゼロであることを確認
- [ ] カスタムスクリプトで悪意ある依存関係が検出されないことを確認
- [ ] 手動コードレビューで自動化ツールが見落とした問題をチェック
- [ ] Defense in Depth戦略（多層防御）を実装

---

## 7. IaCセキュリティスキャン（Checkov）

### なぜIaCのセキュリティスキャンが必要か

IaCテンプレートの設定ミスは、ストレージの公開設定漏れ・暗号化の欠落・ログ無効化など深刻な脆弱性を引き起こす。手動レビューはスケールしないため、自動スキャンツールを活用する。

### Checkovのインストールと基本的な使い方

```bash
# Python仮想環境でCheckovをインストール
python3 -m venv checkov-env
source checkov-env/bin/activate
pip install checkov

# IaCディレクトリをスキャン
checkov -d ./infrastructure/

# 特定のチェックをスキップ（False Positive等）
checkov -d ./infrastructure/ --skip-check CKV_GCP_62
```

### Terraformテンプレートのスキャン例

以下のようなTerraformリソース定義をCheckovでスキャンすると、セキュリティの問題を自動検出できる：

```hcl
# ❌ 問題あり: バージョニングなし、アクセスログなし
resource "google_storage_bucket" "default" {
  name                        = var.bucket_name
  location                    = var.region
  force_destroy               = false
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
}
```

Checkovの出力例：

```
terraform scan results:
Passed checks: 2, Failed checks: 2, Skipped checks: 0

Check: CKV_GCP_78: "Ensure Cloud storage has versioning enabled"
FAILED for resource: google_storage_bucket.default

Check: CKV_GCP_62: "Bucket should log access"
FAILED for resource: google_storage_bucket.default
```

```hcl
# ✅ 修正後: バージョニングを追加
resource "google_storage_bucket" "default" {
  name                        = var.bucket_name
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  versioning {
    enabled = true
  }
}
```

### 主要なCheckovチェック（サーバーレス関連）

| チェックID | 内容 | 対象 |
|-----------|------|------|
| `CKV_AWS_18` | S3アクセスログを有効化 | AWS S3 |
| `CKV_AWS_19` | S3暗号化を有効化 | AWS S3 |
| `CKV_AWS_56` | S3パブリックアクセスブロック有効化 | AWS S3 |
| `CKV_AWS_50` | Lambda関数のX-Rayトレース有効化 | AWS Lambda |
| `CKV_GCP_29` | Cloud Storageのuniform bucket-level access有効化 | GCP Storage |
| `CKV_GCP_78` | Cloud Storageのバージョニング有効化 | GCP Storage |
| `CKV_GCP_62` | Cloud Storageのアクセスログ有効化 | GCP Storage |
| `CKV_GCP_114` | Cloud Storageのパブリックアクセス防止 | GCP Storage |

### CI/CDパイプラインへの統合

```yaml
# .github/workflows/iac-security.yml
name: IaC Security Scan
on: [push, pull_request]

jobs:
  checkov-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Checkov
        uses: bridgecrewio/checkov-action@master
        with:
          directory: infrastructure/
          soft_fail: false          # 問題検出時にビルドを失敗させる
          skip_check: CKV_GCP_62   # プロジェクトポリシーで承認済みのスキップ
```

---

## 8. Semgrepルール拡張（サーバーレス固有パターン）

### 機密情報の過剰なログ出力を検出

サーバーレス関数では、デバッグ目的で環境変数やリクエスト全体をログに出力するコードが混入しやすい。これらはCloudWatch Logs等に機密情報を露出させる危険なパターンである。

```yaml
# custom-rules/no-sensitive-logging.yml
rules:
  - id: no-env-logging
    patterns:
      - pattern: console.log(process.env)
      - pattern: console.log(process.env.$VAR)
      - pattern: context.log(process.env)
    message: "Avoid logging environment variables — may expose secrets to CloudWatch/Application Insights logs."
    languages: [javascript, typescript]
    severity: ERROR

  - id: no-full-request-logging
    patterns:
      - pattern: console.log($REQ)
      - pattern: context.log($REQ)
    message: "Avoid logging entire request objects — may expose sensitive headers or body data."
    languages: [javascript, typescript]
    severity: WARNING
```

```yaml
# custom-rules/no-sensitive-logging-python.yml
rules:
  - id: no-env-logging-python
    patterns:
      - pattern: print(os.environ)
      - pattern: logging.info(os.environ)
      - pattern: logger.info(os.environ)
    message: "Avoid logging os.environ — may expose secrets to cloud logging services."
    languages: [python]
    severity: ERROR
```

### 動的コード実行パターンの拡張検出

既存の `eval()` ルールに加え、Python固有の危険パターンも検出する：

```yaml
# custom-rules/no-dynamic-exec-python.yml
rules:
  - id: no-exec-python
    patterns:
      - pattern: exec($EXPR)
    message: "Avoid using exec() — enables arbitrary code execution."
    languages: [python]
    severity: ERROR

  - id: no-compile-with-exec-python
    patterns:
      - pattern: compile($CODE, ...)
    message: "Avoid using compile() with untrusted input — can be used for code injection."
    languages: [python]
    severity: WARNING
```

---

## 9. サプライチェーン攻撃の検出アプローチ拡張

### PyPI（Python）向けの検出スクリプト

npmだけでなく、Pythonプロジェクトでも同様の悪意パッケージ検出が必要。`pip-audit`ツールを活用する：

```bash
# pip-auditのインストール
pip install pip-audit

# プロジェクトの依存関係をスキャン
pip-audit -r requirements.txt

# JSON形式で出力
pip-audit -r requirements.txt -f json -o audit-report.json
```

### Dependency Confusion攻撃への対策

Dependency Confusion攻撃では、プライベートパッケージと同名の高バージョン偽パッケージをパブリックレジストリに公開することで、正規パッケージに置き換える手法を使う。

**攻撃パターン**:
- 内部パッケージ名（例: `mycompany-utils`）がパブリックレジストリに存在しない
- 攻撃者が同名のパッケージをnpm/PyPIに公開（高いバージョン番号を指定）
- npm/pipがパブリックレジストリの高バージョンを優先して取得

**防御策**:

```bash
# npm: スコープ付きパッケージを使用（@mycompany/utils）
# 内部パッケージは必ずスコープを付けてパブリックレジストリと名前空間を分離する
# npm install @mycompany/utils

# .npmrc でプライベートレジストリを強制
# @mycompany:registry=https://npm.mycompany.internal/

# pip: --index-url でプライベートインデックスを強制
# pip install mypackage --index-url https://pypi.mycompany.internal/simple/
# ※ --extra-index-url ではなく --index-url を使用（後者はパブリックへフォールバックしない）
```

### Typosquattingパッケージの警戒

Typosquattingでは、よく使われるパッケージ名の誤字バリエーションを悪意あるパッケージ名として登録する（例: `requests` → `requets`, `reqeusts`）。

**防御策**:
- パッケージ名はオートコンプリートや公式サイトURLから確認する
- package.jsonやrequirements.txtをコードレビューの必須対象とする
- Dependabotや`npm audit`で継続的に依存関係を監視する
- lockファイル（`package-lock.json`/`poetry.lock`）をコミットして意図しないバージョン変更を防ぐ

### bad_versions.jsonの管理ベストプラクティス

```json
// bad_versions.jsonの管理方針
// - セキュリティアドバイザリ（GitHub Advisory Database等）を定期監視
// - 悪意パッケージが検出されたらすぐに追加
// - チームで共有されるCIパイプラインで自動参照する
{
  "compromised-package": ["1.2.3"],
  "typosquatted-lib": ["0.0.1", "0.0.2"]
}
```

---

## ベストプラクティス

### ツールの組み合わせ

単一のツールに依存せず、複数の手法を組み合わせる：

- **Semgrep**: コードパターンの検出
- **OSV-Scanner**: 既知の脆弱性の検出
- **カスタムスクリプト**: プロジェクト固有の脅威検出
- **手動レビュー**: 自動化ツールが見落とす微妙な問題のキャッチ

### 段階的な導入

1. **Phase 1**: 既存コードをスキャンし、現状を把握
2. **Phase 2**: Critical/High severity の問題を修正
3. **Phase 3**: CI/CDパイプラインに統合
4. **Phase 4**: カスタムルールを追加し、プロジェクト固有の要件に対応
5. **Phase 5**: 定期的な見直しと改善

### 継続的な改善

- スキャン結果を分析し、False Positiveを記録
- チームでセキュリティパターンを共有
- 新しい脅威に対応するルールを追加
- ツールのアップデート情報を追跡

---

**注意**: このリファレンスは技術情報の要約です。ツールの詳細な仕様や最新情報は、各ツールの公式ドキュメントを参照してください。
