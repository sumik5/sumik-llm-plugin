# Python開発環境（Modern Python Development）

## 🎯 使用タイミング
- **Pythonプロジェクト新規作成時**
- **FastAPI + FastMCP実装時**
- **FastAPI DI設計・テスト時**
- **Python開発環境の構成時**
- **CI/CDパイプライン構築時**
- **Dockerイメージ作成時**
- **システム設計・アーキテクチャ検討時**
- **開発方法論の選択時（Scrum/Kanban等）**
- **API標準・フレームワーク選定時**

## 📚 ドキュメント構成

このスキルは以下のドキュメントで構成されています：

### 1. [プロジェクト構造](./references/PROJECT-STRUCTURE.md)
Pythonプロジェクトの推奨ディレクトリ構成：
- src/パッケージレイアウト
- tests/ディレクトリの構成
- 設定ファイルの配置
- ドキュメント構成

### 2. [FastAPI + FastMCPガイド](./references/FASTAPI-GUIDE.md)
FastAPIとFastMCPを使用したベストプラクティス：
- FastAPIアプリケーション構成
- FastMCPサーバー実装パターン
- 依存性注入（DI）の活用
- エラーハンドリング戦略
- Pydanticによるバリデーション

### 2.5 [FastAPI DI パターン](./references/DI-FASTAPI.md)
FastAPI の依存性注入を体系的に理解・設計するためのガイド：
- IoC / DIP の概念とDIコンテナとしての `Depends`
- 関数依存性・クラス依存性・サブ依存性チェーン
- エラーハンドリング・バリデーション依存性パターン
- スコープ管理（リクエストスコープ・Singleton・lifespan）
- `dependency_overrides` と pytest fixtures によるテスト設計

### 3. [テスト戦略](./references/TESTING.md)
pytest + カバレッジ80%以上を達成する方法：
- pytest設定とマーカー
- 単体テスト/統合テストの分離
- fixtureの活用パターン
- モックとスタブの使い分け
- カバレッジ最適化戦略

### 4. [開発ツール](./references/TOOLING.md)
uv + ruff + mypyの統合開発環境：
- uvによる高速依存関係管理
- ruffによるlintとformat
- mypyによる型チェック
- mise.tomlによるツールバージョン管理
- pre-commit設定

### 5. [Docker構成](./references/DOCKER.md)
uvマルチステージビルドの最適化：
- マルチステージビルド戦略
- .venvの効率的なコピー
- イメージサイズ最適化
- ヘルスチェック設定
- Cloud Run対応

### 6. [実装例](./references/EXAMPLES.md)
実際のコード例とパターン：
- FastMCP基本実装
- 認証/認可パターン
- データベース接続
- 構造化ロギング
- エラーハンドリング

## 🎯 技術スタック概要

### コアツール
- **Python 3.13**: 推奨バージョン
- **uv**: 超高速パッケージマネージャー（Rust製）
- **ruff**: 最速linter + formatter（Rust製）
- **mypy**: 静的型チェッカー

### Webフレームワーク
- **FastAPI 0.115+**: 高性能非同期Webフレームワーク
- **FastMCP 2.12+**: MCP (Model Context Protocol) SDK
- **Pydantic 2.9+**: データバリデーション

### テスト
- **pytest 8.3+**: テストフレームワーク
- **pytest-asyncio**: 非同期テスト対応
- **pytest-cov**: カバレッジ測定（目標80%以上）

### その他
- **structlog**: 構造化ロギング
- **SQLAlchemy 2.0+**: ORMとデータベース抽象化

## 🚀 クイックスタート

### 1. プロジェクト初期化
```bash
# uvのインストール（まだの場合）
curl -LsSf https://astral.sh/uv/install.sh | sh

# プロジェクト作成
mkdir my-project && cd my-project
uv init

# pyproject.toml作成（詳細は TOOLING.md 参照）
```

### 2. 依存関係のインストール
```bash
# 本番依存関係のみ
uv sync --frozen

# 開発依存関係を含む
uv sync --frozen
```

### 3. 開発ツールの実行
```bash
# Lint + Format
uv run ruff check .
uv run ruff format .

# 型チェック
uv run mypy src/

# テスト実行
uv run pytest
```

## 💡 重要な原則

### 型安全性
- **any型の使用禁止**（詳細は `enforcing-type-safety` スキル参照）
- strict型チェックモードの活用
- Pydanticモデルによるランタイムバリデーション

### テスト駆動開発
- テストカバレッジ80%以上を維持
- pytest markersによるテスト分類
- 環境変数の適切な管理（詳細は `TESTING.md` 参照）

### セキュリティ
- CodeGuardによるセキュリティチェック（`securing-code` スキル参照）
- 機密情報は環境変数で管理
- 入力値の厳格なバリデーション

### パフォーマンス
- 非同期処理の積極活用（async/await）
- データベース接続プール
- Dockerマルチステージビルドによるイメージ最適化

## ユーザー確認の原則（AskUserQuestion）

**判断分岐がある場合、推測で進めず必ずAskUserQuestionツールでユーザーに確認する。**

### 確認すべき場面

| 確認項目 | 例 |
|---|---|
| Pythonバージョン | 3.11, 3.12, 3.13 |
| Webフレームワーク | FastAPI, Flask, Django |
| パッケージマネージャー | uv, pip, poetry |
| DB選択 | PostgreSQL, SQLite, MongoDB |
| ORM | SQLAlchemy, Prisma, Tortoise |
| テストランナー | pytest, unittest |

### 確認不要な場面

- pyproject.toml が既に存在し設定が明確な場合
- CLAUDE.mdや既存コードで技術スタックが指定済みの場合
- linter/formatterの選択（ruff + mypy がデフォルト）

## 🔗 関連スキル

- **[writing-clean-code](../writing-clean-code/SKILL.md)**: SOLID原則とクリーンコード
- **[enforcing-type-safety](../enforcing-type-safety/SKILL.md)**: 型安全性の確保
- **[testing](../testing/SKILL.md)**: テストファーストアプローチ
- **[securing-code](../securing-code/SKILL.md)**: セキュアコーディング
- **[writing-effective-prose](../writing-effective-prose/SKILL.md)**: ドキュメント作成

## 📖 次のステップ

1. **初めての方**: [プロジェクト構造](./references/PROJECT-STRUCTURE.md)から始めてください
2. **FastAPI開発**: [FastAPI + FastMCPガイド](./references/FASTAPI-GUIDE.md)を参照
3. **テスト作成**: [テスト戦略](./references/TESTING.md)でpytest設定を確認
4. **ツール設定**: [開発ツール](./references/TOOLING.md)でuv/ruff/mypy設定
5. **Docker化**: [Docker構成](./references/DOCKER.md)でマルチステージビルド
6. **コード例**: [実装例](./references/EXAMPLES.md)で具体的なパターンを確認
7. **SE プロセス**: [SDLC・方法論](./references/SE-SDLC-METHODOLOGY.md)で開発ライフサイクルを理解
8. **システム設計**: [システムモデリング](./references/SE-SYSTEM-MODELING.md)でアーキテクチャ設計
9. **プロジェクト実装**: [実装パターン](./references/SE-PROJECT-PATTERNS.md)でビジネスオブジェクト設計
10. **API・デプロイ**: [CI/CD・API・デプロイ](./references/SE-API-DEPLOYMENT.md)で本番環境構築
11. **実践パターン**: [PW-PRACTICAL-IO.md](./references/PW-PRACTICAL-IO.md)からファイルI/Oパターンを確認

## Software Engineering Process（ソフトウェアエンジニアリングプロセス）

開発ライフサイクル、方法論、システム設計、プロジェクト実装パターン。

| ファイル | 内容 |
|---------|------|
| [SE-SDLC-METHODOLOGY.md](./references/SE-SDLC-METHODOLOGY.md) | SDLC 10フェーズ、Waterfall/Scrum/Kanban比較、方法論選択基準 |
| [SE-SYSTEM-MODELING.md](./references/SE-SYSTEM-MODELING.md) | 論理/物理アーキテクチャ、ユースケース、データフロー、IPC設計 |
| [SE-CODE-STANDARDS.md](./references/SE-CODE-STANDARDS.md) | コード構成、認知負荷管理、データ契約、可観測性 |
| [SE-PROJECT-PATTERNS.md](./references/SE-PROJECT-PATTERNS.md) | ビジネスオブジェクト設計、データ永続化、ABC/Repositoryパターン |
| [SE-API-DEPLOYMENT.md](./references/SE-API-DEPLOYMENT.md) | CI/CD、API標準比較、Flask vs FastAPI、デプロイメント戦略 |

## Python実践パターン（Python Practical Patterns）

50の実践的パターンから抽出したPython実践テクニック。

| ファイル | 内容 |
|---------|------|
| [PW-PRACTICAL-IO.md](./references/PW-PRACTICAL-IO.md) | ファイルI/O実践（CSV/JSON/構造化テキスト/pathlib/StringIO） |
| [PW-DATA-MANIPULATION.md](./references/PW-DATA-MANIPULATION.md) | データ操作（sorted+key/Counter/dict蓄積/集合演算） |
| [PW-FUNCTION-DESIGN.md](./references/PW-FUNCTION-DESIGN.md) | 関数設計（ディスパッチテーブル/クロージャ/operator/LEGB） |
| [PW-OOP-COMPOSITION.md](./references/PW-OOP-COMPOSITION.md) | OOPコンポジション（has-a/多段構成/dict継承/ICPO） |
| [PW-ITERATOR-PROTOCOL.md](./references/PW-ITERATOR-PROTOCOL.md) | イテレータプロトコル（__iter__/__next__/ジェネレータ関数） |
| [PW-COMPREHENSION-IDIOMS.md](./references/PW-COMPREHENSION-IDIOMS.md) | 内包表記イディオム（集合/辞書内包表記/map-filter比較） |

## Software Design（ソフトウェア設計）

Python向けOOP設計原則とGoFデザインパターン。

| ファイル | 内容 |
|---------|------|
| [SD-FOUNDATIONS.md](./references/SD-FOUNDATIONS.md) | 設計プロセス基礎、反復設計 |
| [SD-REQUIREMENTS.md](./references/SD-REQUIREMENTS.md) | 要件定義、クラス設計、UML |
| [SD-PRINCIPLES.md](./references/SD-PRINCIPLES.md) | カプセル化、デメテルの法則、OCP、LSP、契約による設計 |
| [SD-BEHAVIORAL.md](./references/SD-BEHAVIORAL.md) | Template Method, Strategy, Iterator, Visitor, Observer, State |
| [SD-CREATIONAL.md](./references/SD-CREATIONAL.md) | Factory Method, Abstract Factory, Singleton |
| [SD-STRUCTURAL.md](./references/SD-STRUCTURAL.md) | Adapter, Facade, Composite, Decorator |
| [SD-ALGORITHMS.md](./references/SD-ALGORITHMS.md) | 再帰/バックトラッキング、マルチスレッド |

## Effective Python

125項目のPythonicコードベストプラクティス。

| ファイル | 内容 |
|---------|------|
| [EP-CH01-PYTHONIC.md](./references/EP-CH01-PYTHONIC.md) | Pythonicな考え方 |
| [EP-CH02-STRINGS-SLICES.md](./references/EP-CH02-STRINGS-SLICES.md) | 文字列とスライス |
| [EP-CH03-LOOPS-ITERATORS.md](./references/EP-CH03-LOOPS-ITERATORS.md) | ループとイテレータ |
| [EP-CH04-DICTIONARIES.md](./references/EP-CH04-DICTIONARIES.md) | 辞書 |
| [EP-CH05-FUNCTIONS.md](./references/EP-CH05-FUNCTIONS.md) | 関数 |
| [EP-CH06-COMPREHENSIONS.md](./references/EP-CH06-COMPREHENSIONS.md) | 内包表記とジェネレータ |
| [EP-CH07-CLASSES.md](./references/EP-CH07-CLASSES.md) | クラスと継承 |
| [EP-CH08-METACLASSES.md](./references/EP-CH08-METACLASSES.md) | メタクラスと属性 |
| [EP-CH09-CONCURRENCY.md](./references/EP-CH09-CONCURRENCY.md) | 並行処理と並列処理 |
| [EP-CH10-ROBUSTNESS.md](./references/EP-CH10-ROBUSTNESS.md) | 堅牢性と性能 |
| [EP-CH11-PERFORMANCE.md](./references/EP-CH11-PERFORMANCE.md) | パフォーマンス |
| [EP-CH12-DATA-STRUCTURES.md](./references/EP-CH12-DATA-STRUCTURES.md) | データ構造 |
| [EP-CH13-TESTING.md](./references/EP-CH13-TESTING.md) | テストとデバッグ |
| [EP-CH14-COLLABORATION.md](./references/EP-CH14-COLLABORATION.md) | コラボレーション |
