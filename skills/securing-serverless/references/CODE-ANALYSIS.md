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
