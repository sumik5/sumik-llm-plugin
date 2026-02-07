# 14章: コラボレーション

## 概要
Pythonコミュニティのベストプラクティスとツールを活用して、チーム開発や長期保守性を向上させる。PyPI、仮想環境、バージョン管理、ドキュメント、パッケージングを通じて協力しやすいコードベースを構築する。

## 項目一覧

| 項目 | タイトル | 核心ルール |
|------|---------|-----------|
| 116 | サードパーティライブラリの探し方 | PyPIとpipでコミュニティの資産を活用 |
| 117 | 仮想環境を使う | venvで依存関係を分離管理 |
| 118 | requirements.txtで依存関係を管理 | 再現可能な環境構築 |
| 119 | APIの後方互換性を保つ | バージョン管理と段階的な移行 |
| 120 | docstringでAPIをドキュメント化 | 関数・クラスの使用方法を明示 |
| 121 | type hintsで型情報を提供 | 静的解析とIDEサポート向上 |
| 122 | モジュールスコープでシングルトン実現 | モジュール読み込みは1回のみ |
| 123 | __init__.pyでパッケージを構成 | 名前空間の制御と初期化 |
| 124 | __all__で公開APIを明示 | from module import *の制御 |
| 125 | パッケージングで配布 | setup.pyとwheelで簡単インストール |

## 各項目の詳細

### 項目116: サードパーティライブラリの探し方

**核心ルール:**
- PyPI（Python Package Index）で目的のライブラリを検索
- pipでインストール・管理
- ライセンスを確認して利用可能性を判断

**推奨パターン:**
```bash
# ライブラリ検索
pip search keyword

# インストール
python3 -m pip install package-name

# バージョン指定
python3 -m pip install package-name==1.2.3
```

### 項目117: 仮想環境を使う

**核心ルール:**
- venvで分離されたPython環境を作成
- プロジェクトごとに独立した依存関係を管理
- グローバル環境の汚染を防止

**推奨パターン:**
```bash
# 仮想環境作成
python3 -m venv myproject

# 有効化（Linux/Mac）
source myproject/bin/activate

# 有効化（Windows）
myproject\Scripts\activate.bat

# 無効化
deactivate
```

### 項目118: requirements.txtで依存関係を管理

**核心ルール:**
- pip freezeで現在の依存関係を出力
- requirements.txtで環境を再現可能に
- バージョン固定で一貫性を保証

**推奨パターン:**
```bash
# 依存関係の出力
pip freeze > requirements.txt

# 依存関係のインストール
pip install -r requirements.txt

# requirements.txt例
numpy==1.24.0
pandas>=2.0.0,<3.0.0
requests~=2.28.0
```

### 項目119: APIの後方互換性を保つ

**核心ルール:**
- セマンティックバージョニング（major.minor.patch）
- 非推奨警告で段階的に移行
- 破壊的変更はメジャーバージョンアップ時のみ

**推奨パターン:**
```python
import warnings

def old_function():
    warnings.warn(
        "old_function is deprecated, use new_function instead",
        DeprecationWarning,
        stacklevel=2
    )
    return new_function()

def new_function():
    return "new implementation"
```

### 項目120: docstringでAPIをドキュメント化

**核心ルール:**
- 関数・クラス・モジュールにdocstringを記述
- パラメータ、戻り値、例外を説明
- Sphinxなどで自動ドキュメント生成可能

**推奨パターン:**
```python
def calculate_area(width, height):
    """矩形の面積を計算する。

    Args:
        width: 矩形の幅（正の数値）
        height: 矩形の高さ（正の数値）

    Returns:
        矩形の面積（浮動小数点数）

    Raises:
        ValueError: widthまたはheightが負の場合
    """
    if width < 0 or height < 0:
        raise ValueError("Dimensions must be positive")
    return width * height
```

### 項目121: type hintsで型情報を提供

**核心ルール:**
- 関数シグネチャに型アノテーションを追加
- mypyなどで静的型チェック
- IDEの補完・リファクタリング支援向上

**推奨パターン:**
```python
from typing import List, Optional, Dict

def process_items(items: List[str],
                  config: Optional[Dict[str, int]] = None) -> int:
    """アイテムを処理してカウントを返す。"""
    if config is None:
        config = {}
    return len(items)
```

### 項目122: モジュールスコープでシングルトン実現

**核心ルール:**
- モジュールは初回インポート時に1回だけ実行
- モジュールレベルの変数でグローバル状態管理
- 明示的なシングルトンパターンより簡潔

**推奨パターン:**
```python
# config.py
DATABASE_URL = "postgresql://localhost/mydb"
cache = {}

def get_config():
    return DATABASE_URL

# 使用側
import config
print(config.DATABASE_URL)  # モジュールは1回だけ実行
```

### 項目123: __init__.pyでパッケージを構成

**核心ルール:**
- __init__.pyでディレクトリをパッケージ化
- サブモジュールのインポートを簡略化
- パッケージレベルの初期化処理

**推奨パターン:**
```python
# mypackage/__init__.py
from .module_a import ClassA
from .module_b import ClassB

__version__ = "1.0.0"

# 使用側
from mypackage import ClassA, ClassB
```

### 項目124: __all__で公開APIを明示

**核心ルール:**
- __all__リストで公開シンボルを定義
- from module import *の挙動を制御
- ドキュメント生成ツールのヒント

**推奨パターン:**
```python
# mymodule.py
__all__ = ['public_function', 'PublicClass']

def public_function():
    pass

def _private_helper():
    pass

class PublicClass:
    pass
```

### 項目125: パッケージングで配布

**核心ルール:**
- setup.pyまたはpyproject.tomlで設定
- wheelフォーマットで高速インストール
- PyPIへのアップロードで共有

**推奨パターン:**
```python
# setup.py
from setuptools import setup, find_packages

setup(
    name='mypackage',
    version='1.0.0',
    packages=find_packages(),
    install_requires=[
        'numpy>=1.20.0',
        'requests>=2.25.0',
    ],
    python_requires='>=3.8',
)
```

```bash
# ビルドとインストール
python setup.py sdist bdist_wheel
pip install dist/mypackage-1.0.0-py3-none-any.whl
```

## コラボレーションのベストプラクティス

### バージョン管理
- **MAJOR**: 破壊的変更
- **MINOR**: 新機能追加（後方互換）
- **PATCH**: バグ修正

### ドキュメント戦略
1. README.md: プロジェクト概要、セットアップ手順
2. docstring: API仕様
3. type hints: 型情報
4. CHANGELOG.md: バージョン履歴

### 依存関係管理
- 仮想環境で開発環境を分離
- requirements.txtで依存関係を固定
- 定期的な依存関係の更新とテスト

### コードレビュー
- 型チェック（mypy）
- リンター（pylint、flake8）
- フォーマッター（black）
- テストカバレッジ
