# 13章: テストとデバッグ

## 概要
Pythonの動的な性質により、実行時エラーのリスクが高まるため、テストがより重要となる。unittest、Mock、デバッグ技術を活用して、堅牢で保守しやすいコードを実現する。

## 項目一覧

| 項目 | タイトル | 核心ルール |
|------|---------|-----------|
| 108 | TestCaseでテストを実装する | アサーションメソッドで詳細なエラー情報を取得 |
| 109 | setUp/tearDown/addCleanupでテスト環境管理 | テスト間の独立性を保証 |
| 110 | subtestで重複コードを削減 | パラメータ化テストで可読性向上 |
| 111 | Mockで依存関係を分離 | 外部システムなしで単体テスト可能に |
| 112 | pdbでインタラクティブデバッグ | ブレークポイントで実行時状態を調査 |
| 113 | assertAlmostEqualで浮動小数点を比較 | 丸め誤差を許容した数値比較 |
| 114 | tracebackでスタックトレース解析 | エラー原因の迅速な特定 |
| 115 | warningsで非推奨機能を警告 | 段階的な移行を支援 |

## 各項目の詳細

### 項目108: TestCaseでテストを実装する

**核心ルール:**
- TestCaseを継承してtestで始まるメソッドを定義
- assertEqual等のヘルパーメソッドで詳細なエラー情報を取得
- assertRaisesで例外を検証

**推奨パターン:**
```python
from unittest import TestCase, main

class MyTestCase(TestCase):
    def test_basic(self):
        result = my_function(5)
        self.assertEqual(10, result)

    def test_exception(self):
        with self.assertRaises(ValueError):
            my_function(-1)

if __name__ == "__main__":
    main()
```

### 項目109: setUp/tearDown/addCleanupでテスト環境管理

**核心ルール:**
- setUpで各テスト前の初期化
- tearDownで各テスト後のクリーンアップ
- addCleanupで例外発生時も確実にクリーンアップ

**推奨パターン:**
```python
class ResourceTest(TestCase):
    def setUp(self):
        self.resource = create_resource()
        self.addCleanup(self.resource.close)

    def test_operation(self):
        self.resource.process()
        self.assertTrue(self.resource.is_valid())
```

### 項目110: subtestで重複コードを削減

**核心ルール:**
- with self.subTestでパラメータ化テスト
- 1つの失敗が他のテストケースをブロックしない
- テストデータと検証ロジックを分離

**推奨パターン:**
```python
class ParameterizedTest(TestCase):
    def test_multiple_cases(self):
        test_cases = [
            (1, 2, 3),
            (2, 3, 5),
            (10, 20, 30),
        ]
        for a, b, expected in test_cases:
            with self.subTest(a=a, b=b):
                result = my_add(a, b)
                self.assertEqual(expected, result)
```

### 項目111: Mockで依存関係を分離

**核心ルール:**
- unittest.mockで外部依存を置き換え
- patch()で関数・メソッドを動的にモック化
- assert_called_with()で呼び出しを検証

**推奨パターン:**
```python
from unittest.mock import Mock, patch

class ApiTest(TestCase):
    def test_api_call(self):
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {'data': 'test'}

        with patch('requests.get', return_value=mock_response):
            result = my_api_function()
            self.assertEqual('test', result['data'])
```

### 項目112: pdbでインタラクティブデバッグ

**核心ルール:**
- breakpoint()で実行を一時停止
- 対話的に変数を検査、式を評価
- step、next、continueで実行制御

**推奨パターン:**
```python
def debug_function(data):
    result = process_data(data)
    breakpoint()  # ここで一時停止
    return finalize(result)

# pdbコマンド:
# p variable   - 変数表示
# n            - 次の行
# s            - ステップイン
# c            - 継続
# q            - 終了
```

### 項目113: assertAlmostEqualで浮動小数点を比較

**核心ルール:**
- 浮動小数点は完全一致比較を避ける
- placesで小数点以下の桁数を指定
- deltaで許容誤差を指定

**推奨パターン:**
```python
class FloatTest(TestCase):
    def test_calculation(self):
        result = 0.1 + 0.2
        # 0.3と完全一致しないため失敗
        # self.assertEqual(0.3, result)

        # 許容誤差付き比較
        self.assertAlmostEqual(0.3, result, places=7)
        # または
        self.assertAlmostEqual(0.3, result, delta=1e-9)
```

### 項目114: tracebackでスタックトレース解析

**核心ルール:**
- traceback.format_exc()でスタックトレース文字列化
- logging経由でエラー情報を記録
- 例外チェーンで根本原因を追跡

**推奨パターン:**
```python
import traceback
import logging

try:
    risky_operation()
except Exception:
    logging.error("Operation failed:\n%s", traceback.format_exc())
    # または
    logging.exception("Operation failed")
```

### 項目115: warningsで非推奨機能を警告

**核心ルール:**
- warnings.warn()で将来の変更を予告
- DeprecationWarningで非推奨API通知
- filterwarnings()で警告の表示制御

**推奨パターン:**
```python
import warnings

def deprecated_function():
    warnings.warn(
        "deprecated_function() is deprecated, use new_function() instead",
        DeprecationWarning,
        stacklevel=2
    )
    # 古い実装

# 警告の制御
warnings.filterwarnings('error', category=DeprecationWarning)
```

## テスト戦略のベストプラクティス

### AAAパターン
```python
def test_feature(self):
    # Arrange（準備）
    data = create_test_data()

    # Act（実行）
    result = process(data)

    # Assert（検証）
    self.assertEqual(expected, result)
```

### テストカバレッジ目標
- ビジネスロジック: 100%
- エラーハンドリング: 重要なパスは必須
- エッジケース: 境界値、空入力、異常値

### テストの独立性
- 各テストは他のテストに依存しない
- 実行順序に依存しない
- setUp/tearDownで環境を初期化/クリーンアップ

### モックの使用指針
- 外部システム（DB、API、ファイル）
- 時間依存の処理
- ランダム性のある処理
- 過度なモックは避ける（実装の詳細に依存）
