# リファレンス：チェックリスト、ツール設定、型チェッカー（Python編）

このファイルでは、Python型安全性を確保するための実践的なリファレンス情報を提供します。

## 📋 目次

- [型安全性チェックリスト（Python）](#型安全性チェックリスト-python)
- [Python設定](#python設定)
- [型チェッカー実行コマンド（Python）](#型チェッカー実行コマンド-python)
- [トラブルシューティング（Python）](#トラブルシューティング-python)
- [CI/CD統合（Python）](#cicd統合-python)

## ✅ 型安全性チェックリスト（Python）

### 実装前チェックリスト

コードを書く前に確認する項目：

- [ ] **Any型の使用を避ける計画か？**
  - Python: `Any` → `Union`、`Optional`、`Protocol`、または明示的な型ヒント

- [ ] **型定義ファイルの確認**
  - 既存の型を再利用できないか確認
  - 新しい型定義が必要な場合、適切な場所に配置する計画

- [ ] **外部ライブラリの型定義**
  - Python: 型スタブ（`types-*`）の確認

- [ ] **型の共有範囲**
  - ローカル型で十分か、共有型として定義すべきか
  - 型定義ファイルの配置場所（`types/`、`models/`等）

### 実装中チェックリスト（Python）

- [ ] **型ヒントの徹底**
  - すべての関数の引数と戻り値に型ヒントがあるか
  - クラスの属性に型ヒントがあるか

- [ ] **Any型の不使用**
  - `Any` 型を使用していないか
  - `Union`、`Optional`、`Protocol` で代替できているか

- [ ] **TypedDictの活用**
  - 辞書型のデータには `TypedDict` を使用しているか

- [ ] **dataclassの活用**
  - データクラスには `@dataclass` を使用しているか
  - 可変デフォルト引数を避けているか（`field(default_factory=list)`）

- [ ] **Protocolの活用**
  - ダックタイピングが必要な場合は `Protocol` を使用しているか

- [ ] **型ガードの実装**
  - `TypeGuard` を使用した型ガード関数を実装したか

- [ ] **例外処理の具体化**
  - bare `except` を使用していないか
  - 具体的な例外クラスを指定しているか

### 実装後チェックリスト

コードを書き終えた後に確認する項目：

- [ ] **型チェッカーの実行**
  - Python: `mypy` / `pyright` でエラーがないか

- [ ] **コードレビュー観点**
  - [ ] Any型が使用されていないか
  - [ ] すべての関数に型注釈があるか
  - [ ] 型ガードが適切に実装されているか
  - [ ] エラーハンドリングが適切か
  - [ ] ユニットテストが型安全か

- [ ] **ドキュメントの更新**
  - 型定義のドキュメントコメントが適切か
  - 使用例が型安全か

## 🐍 Python設定

### mypy.ini（推奨設定）

```ini
[mypy]
# === 基本設定 ===
python_version = 3.11
warn_return_any = True
warn_unused_configs = True
disallow_untyped_defs = True
disallow_incomplete_defs = True

# === Any型の厳格な禁止 ===
disallow_any_unimported = True       # インポートされた型でのAny使用を禁止
disallow_any_expr = False             # 完全に厳格にする場合はTrue
disallow_any_decorated = True         # デコレータでのAny使用を禁止
disallow_any_explicit = True          # 明示的なAny使用を禁止
disallow_any_generics = True          # ジェネリクスでのAny使用を禁止
disallow_subclassing_any = True       # Anyのサブクラス化を禁止

# === 型チェックの厳格化 ===
check_untyped_defs = True            # 型ヒントなし関数もチェック
strict_optional = True                # Optionalの厳密チェック
strict_equality = True                # 等価性チェックの厳格化
strict_concatenate = True             # 文字列結合の厳格化

# === エラー・警告設定 ===
warn_redundant_casts = True          # 冗長なキャストを警告
warn_unused_ignores = True           # 未使用の# type: ignoreを警告
warn_no_return = True                # 戻り値がない関数を警告
warn_unreachable = True              # 到達不能コードを警告
warn_incomplete_stub = True          # 不完全な型スタブを警告

# === インポート設定 ===
ignore_missing_imports = False       # インポートの型定義がない場合エラー
follow_imports = normal              # インポートを追跡
namespace_packages = True            # 名前空間パッケージをサポート

# === その他 ===
pretty = True                        # エラーメッセージを見やすく
show_error_codes = True              # エラーコードを表示
show_column_numbers = True           # カラム番号を表示
show_error_context = True            # エラーコンテキストを表示

# === プラグイン ===
plugins = pydantic.mypy              # Pydantic使用時

# === サードパーティライブラリ ===
# 型定義がないライブラリは個別に設定
[mypy-pytest.*]
ignore_missing_imports = True

[mypy-requests.*]
ignore_missing_imports = True

[mypy-celery.*]
ignore_missing_imports = True

# === Pydanticプラグイン設定 ===
[pydantic-mypy]
init_forbid_extra = True
init_typed = True
warn_required_dynamic_aliases = True
```

### pyrightconfig.json（推奨設定）

```json
{
  "include": ["src"],
  "exclude": [
    "**/node_modules",
    "**/__pycache__",
    "**/.*",
    "tests"
  ],

  "typeCheckingMode": "strict",

  "reportMissingImports": true,
  "reportMissingTypeStubs": false,
  "reportImportCycles": true,
  "reportUnusedImport": true,
  "reportUnusedClass": true,
  "reportUnusedFunction": true,
  "reportUnusedVariable": true,
  "reportDuplicateImport": true,
  "reportOptionalSubscript": true,
  "reportOptionalMemberAccess": true,
  "reportOptionalCall": true,
  "reportOptionalIterable": true,
  "reportOptionalContextManager": true,
  "reportOptionalOperand": true,
  "reportTypedDictNotRequiredAccess": true,
  "reportUntypedFunctionDecorator": true,
  "reportUntypedClassDecorator": true,
  "reportUntypedBaseClass": true,
  "reportUntypedNamedTuple": true,
  "reportPrivateUsage": true,
  "reportConstantRedefinition": true,
  "reportIncompatibleMethodOverride": true,
  "reportIncompatibleVariableOverride": true,
  "reportUnnecessaryIsInstance": true,
  "reportUnnecessaryCast": true,
  "reportAssertAlwaysTrue": true,
  "reportSelfClsParameterName": true,
  "reportUnusedCoroutine": true,

  "pythonVersion": "3.11",
  "pythonPlatform": "Linux",

  "executionEnvironments": [
    {
      "root": "src",
      "pythonVersion": "3.11",
      "pythonPlatform": "Linux",
      "extraPaths": ["lib"]
    }
  ],

  "venvPath": ".",
  "venv": ".venv"
}
```

### Ruff設定（.ruff.toml）

```toml
# Pythonバージョン
target-version = "py311"

# チェック対象
select = [
    "E",      # pycodestyle errors
    "W",      # pycodestyle warnings
    "F",      # pyflakes
    "I",      # isort
    "N",      # pep8-naming
    "UP",     # pyupgrade
    "ANN",    # flake8-annotations
    "ASYNC",  # flake8-async
    "B",      # flake8-bugbear
    "C4",     # flake8-comprehensions
    "DTZ",    # flake8-datetimez
    "T10",    # flake8-debugger
    "EXE",    # flake8-executable
    "ISC",    # flake8-implicit-str-concat
    "G",      # flake8-logging-format
    "PIE",    # flake8-pie
    "T20",    # flake8-print
    "PT",     # flake8-pytest-style
    "Q",      # flake8-quotes
    "RSE",    # flake8-raise
    "RET",    # flake8-return
    "SIM",    # flake8-simplify
    "TCH",    # flake8-type-checking
    "ARG",    # flake8-unused-arguments
    "PTH",    # flake8-use-pathlib
    "ERA",    # eradicate (コメントアウトされたコード)
    "PL",     # pylint
    "TRY",    # tryceratops
    "RUF",    # Ruff-specific rules
]

# 除外するルール
ignore = [
    "ANN101",  # Missing type annotation for self
    "ANN102",  # Missing type annotation for cls
]

# 1行あたりの最大文字数
line-length = 100

# 除外するディレクトリ
exclude = [
    ".git",
    "__pycache__",
    ".venv",
    "venv",
    "build",
    "dist",
]

[per-file-ignores]
"tests/**/*.py" = [
    "S101",    # Use of assert
    "ANN201",  # Missing return type annotation
]
```

## 🚀 型チェッカー実行コマンド（Python）

```bash
# === mypy ===
# 基本的な型チェック
mypy src/

# 厳格モード
mypy --strict src/

# 特定のファイルのみチェック
mypy src/main.py

# HTMLレポート生成
mypy --html-report ./mypy-report src/

# キャッシュをクリア
mypy --no-incremental src/

# === pyright ===
# 基本的な型チェック
pyright

# 特定のファイルのみチェック
pyright src/main.py

# 設定ファイル指定
pyright --project pyrightconfig.json

# === Ruff ===
# コードチェック
ruff check src/

# 自動修正
ruff check --fix src/

# フォーマット
ruff format src/

# === すべてまとめて実行 ===
# Makefileで管理する例
make type-check
```

**Makefile例**:
```makefile
.PHONY: type-check lint format check

type-check:
	mypy src/
	pyright

lint:
	ruff check src/

format:
	ruff format src/

check: type-check lint
	@echo "All checks passed!"
```

## 🔧 トラブルシューティング（Python）

### Q1. `Cannot find implementation or library stub` エラー

**問題**:
```
error: Cannot find implementation or library stub for module named "requests"
```

**解決策**:
```bash
# 型スタブをインストール
pip install types-requests

# または mypy.ini で無視
[mypy-requests.*]
ignore_missing_imports = True
```

### Q2. `Incompatible types in assignment` エラー

**問題**:
```python
def get_user() -> User:
    return None  # エラー: Incompatible return value type
```

**解決策**:
```python
from typing import Optional

def get_user() -> Optional[User]:
    return None  # OK
```

### Q3. `Name "X" is not defined` エラー（前方参照）

**問題**:
```python
class User:
    def get_friend(self) -> User:  # エラー: Name "User" is not defined
        pass
```

**解決策**:
```python
from __future__ import annotations  # Python 3.7+

class User:
    def get_friend(self) -> User:  # OK
        pass

# またはクォートで囲む
class User:
    def get_friend(self) -> 'User':  # OK
        pass
```

## 🔄 CI/CD統合（Python）

### GitHub Actions（Python）

```yaml
name: Type Check (Python)

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  type-check:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'

      - name: Cache dependencies
        uses: actions/cache@v3
        with:
          path: ~/.cache/pip
          key: ${{ runner.os }}-pip-${{ hashFiles('**/requirements.txt') }}

      - name: Install dependencies
        run: |
          pip install -r requirements.txt
          pip install mypy pyright ruff
          pip install types-requests  # 型スタブ

      - name: mypy type check
        run: mypy src/

      - name: pyright type check
        run: pyright

      - name: Ruff lint
        run: ruff check src/
```

### pre-commit設定（Python）

```yaml
repos:
  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.7.0
    hooks:
      - id: mypy
        args: [--strict]
        additional_dependencies:
          - types-requests

  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.1.6
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format
```

## 🔗 関連ファイル

- **[INSTRUCTIONS.md](../INSTRUCTIONS.md)** - developing-python 概要に戻る
- **[TYPE-SAFETY-PYTHON.md](./TYPE-SAFETY-PYTHON.md)** - Python型安全性詳細
- **[TYPE-SAFETY-ANTI-PATTERNS.md](./TYPE-SAFETY-ANTI-PATTERNS.md)** - 避けるべきパターン
