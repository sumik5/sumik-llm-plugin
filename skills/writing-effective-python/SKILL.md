---
name: writing-effective-python
description: Pythonic code best practices covering 125 items on idioms, data structures, functions, and concurrency. MUST load when working in Python projects detected by .py files. Complements developing-python (project setup) with code-level best practices.
---

# Python ベストプラクティスガイド

## 使用タイミング
- Pythonコードの新規作成・レビュー・リファクタリング時
- Pythonicな書き方を確認したい時
- パフォーマンスや並行性の設計判断が必要な時
- Python固有の機能（デコレータ、ジェネレータ、メタクラス等）の実装時
- コードの保守性・可読性を向上させたい時

## クイックリファレンス

| 章 | テーマ | 項目数 | 主要トピック |
|---|--------|--------|-------------|
| [1章](./CH01-PYTHONIC.md) | Pythonicな考え方 | 9 | PEP 8、アンパック、代入式、パターンマッチ |
| [2章](./CH02-STRINGS-SLICES.md) | 文字列とスライス | 7 | bytes/str、f-string、スライス |
| [3章](./CH03-LOOPS-ITERATORS.md) | ループとイテレータ | 8 | enumerate、zip、itertools |
| [4章](./CH04-DICTIONARIES.md) | 辞書 | 5 | 挿入順序、get()、defaultdict、__missing__ |
| [5章](./CH05-FUNCTIONS.md) | 関数 | 10 | ミュータブル引数、キーワード引数、デコレータ |
| 6章 | 内包表記とジェネレータ | 8 | 内包表記、ジェネレータ式、yield from |
| 7章 | クラスとインタフェース | 10 | dataclasses、ポリモーフィズム、mix-in |
| 8章 | メタクラスと属性 | 9 | property、ディスクリプタ、__init_subclass__ |
| 9章 | 並行性と並列性 | 13 | スレッド、asyncio、concurrent.futures |
| 10章 | ロバストネス | 12 | 例外処理、assert、contextlib |
| 11章 | パフォーマンス | 8 | プロファイリング、ctypes、memoryview |
| 12章 | データ構造とアルゴリズム | 8 | sort、bisect、deque、heapq |
| 13章 | テストとデバッグ | 8 | unittest、mock、pdb、tracemalloc |
| 14章 | コラボレーション | 10 | 仮想環境、docstring、型解析、パッケージ |

## 場面別ガイド

### コードスタイル・基礎
- **新規Pythonプロジェクト開始**: [1章](./CH01-PYTHONIC.md) → PEP 8、アンパック、条件式
- **文字列処理**: [2章](./CH02-STRINGS-SLICES.md) → bytes/str、f-string
- **ループ最適化**: [3章](./CH03-LOOPS-ITERATORS.md) → enumerate、zip、itertools

### データ構造・関数設計
- **辞書の効率的な使い方**: [4章](./CH04-DICTIONARIES.md)
- **関数のインタフェース設計**: [5章](./CH05-FUNCTIONS.md) → キーワード引数、デコレータ
- **データ変換・処理**: 6章 → 内包表記、ジェネレータ

### オブジェクト指向・メタプログラミング
- **クラス設計**: 7章 → dataclasses、ポリモーフィズム
- **高度なクラス機能**: 8章 → property、ディスクリプタ

### 並行処理・堅牢性
- **並行・並列処理**: 9章 → スレッド、asyncio
- **例外処理・エラーハンドリング**: 10章

### パフォーマンス・品質
- **パフォーマンス最適化**: 11章 → プロファイリング
- **標準ライブラリ活用**: 12章 → sort、heapq、deque
- **テスト・デバッグ**: 13章
- **チーム開発**: 14章 → パッケージ、型解析

## 核心原則

### Pythonicなコード
1. **明示性**: 暗黙より明示を優先（Zen of Python）
2. **簡潔性**: 複雑な式よりヘルパー関数
3. **一貫性**: PEP 8スタイルガイド遵守
4. **可読性**: インデックス参照よりアンパック

### 実行時の柔軟性
- Pythonはコンパイル時ではなく実行時にエラー検出
- 静的解析ツール（flake8、型チェッカー）で事前検証
- テストファースト開発が重要

### 型安全性
- `any`/`Any`型の使用禁止
- 型ヒントの活用
- `unknown` + 型ガード

## ユーザー確認の原則（AskUserQuestion）

**判断分岐がある場合、推測で進めず必ずAskUserQuestionツールでユーザーに確認する。**

確認すべき場面:
- 並行処理の選択（スレッド vs asyncio vs マルチプロセス）
- クラス設計の選択（dataclass vs NamedTuple vs 通常クラス）
- テスト戦略（unittest vs pytest、単体テスト vs 統合テスト）
- パフォーマンス最適化の方針（pure Python vs C拡張）

確認不要な場面:
- PEP 8スタイルの適用
- f-stringの使用（str.formatよりf-string）
- enumerate/zipの使用（range(len())より）
- 型ヒントの追加

## 章別重要事項

### 1章: Pythonicな考え方
- Python 3.13対応、Python 2は非推奨
- PEP 8自動フォーマット（Black推奨）
- アンパックでインデックス参照削減
- 代入式（:=）で繰り返し削減
- パターンマッチで分割（`match`/`case`）

### 2章: 文字列とスライス
- `bytes`と`str`の明確な区別
- f-stringによるフォーマット（`%`演算子、`str.format()`非推奨）
- `repr()`でデバッグ情報明確化
- スライス構文の活用
- catch-allアンパック（`*rest`）

### 3章: ループとイテレータ
- `enumerate()`でインデックス取得
- `zip()`で並列イテレート
- イテレータプロトコル理解
- `for`/`while`の`else`ブロック回避
- ループ変数のスコープ注意

### 4章: 辞書
- 挿入順序保証（Python 3.7+）
- `get()`、`setdefault()`、`defaultdict`活用
- `__missing__()`でカスタマイズ
- 辞書の効率的な更新

### 5章: 関数
- ミュータブル引数のデフォルト値禁止
- キーワード専用引数（`*`）
- 位置専用引数（`/`）
- デコレータによる関数拡張
- クロージャのスコープ理解

## 関連スキル

| スキル | 関係 |
|--------|------|
| [developing-python](../developing-python/SKILL.md) | Python環境構築・プロジェクト設定（補完関係） |
| [testing](../testing/SKILL.md) | テストフレームワーク全般（本スキルはPython固有のテスト戦略） |
| [enforcing-type-safety](../enforcing-type-safety/SKILL.md) | 型安全性（本スキルは型解析を扱う） |
| [writing-clean-code](../writing-clean-code/SKILL.md) | SOLID原則・設計原則（本スキルはPython固有のクラス設計） |

## ツール推奨

### フォーマット・リント
- **Black**: PEP 8準拠の自動フォーマッタ
- **Pylint**: 静的解析・スタイルチェック
- **flake8**: エラー検出
- **mypy**: 型チェッカー

### テスト・デバッグ
- **pytest**: テストフレームワーク
- **unittest**: 標準ライブラリテストツール
- **pdb**: デバッガ

## 学習パス

### 初級（1-3章）
Pythonの基礎を固める段階。PEP 8、文字列操作、基本的なループとイテレータを習得。

### 中級（4-7章）
データ構造と関数設計を深める。辞書、関数の高度な機能、内包表記、ジェネレータを学習。

### 上級（8-14章）
メタプログラミング、並行処理、パフォーマンス最適化、テスト戦略を習得。
