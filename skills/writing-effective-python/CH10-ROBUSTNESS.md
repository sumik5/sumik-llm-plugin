# 10章: ロバストネス

## 概要

本番環境で確実に動作するコードを書くための例外処理、リソース管理、デバッグ技術を習得する。予期せぬ事態に対処できるロバストなプログラムを構築する。

## 項目一覧

| 項目 | タイトル | 核心ルール |
|------|---------|-----------|
| 80 | try/except/else/finallyブロックを使う | 各ブロックの役割を正しく理解する |
| 81 | assertで前提条件検証、raiseで例外通知 | raiseはAPI、assertは内部検証 |
| 82 | contextlibとwith文で再利用可能なtry/finally実現 | @contextmanagerで簡潔にコンテキスト作成 |
| 83 | tryブロックを可能な限り短く保つ | 予期されるエラー要因を1つに絞る |
| 84 | 例外変数が消失することに注意する | except外からは例外変数参照不可 |
| 85 | Exceptionクラスを注意して捕捉する | 広範な例外捕捉は問題を隠蔽する |
| 86 | ExceptionとBaseExceptionの違いを理解する | BaseExceptionはKeyboardInterrupt等を含む |
| 87 | tracebackによる高度な例外報告 | traceback使用で詳細なエラー処理 |
| 88 | 例外を明示的に連鎖させる | raise ... from で例外の起点を明示 |
| 89 | ジェネレータには常にリソースを渡す | ジェネレータ外でリソース準備・管理 |
| 90 | \_\_debug\_\_をFalseにしない | assert無効化は妥当性を損なう |
| 91 | 開発者ツール以外でevalを使わない | 動的コード実行は開発者ツールのみ |

## 各項目の詳細

### 項目80: try/except/else/finallyブロックを使う

**核心ルール:**
- try/finally: 例外発生有無に関わらずクリーンアップ実行
- try/except/else: 成功時処理をelseに分離して可読性向上
- try/except/else/finally: 一連の処理を単一複合文として扱う

**推奨パターン:**
```python
# try/finally
handle = open(path)
try:
    return handle.read()
finally:
    handle.close()

# try/except/else
try:
    data = json.loads(text)
except ValueError:
    raise KeyError(key)
else:
    return data[key]
```

### 項目81: assertで前提条件検証、raiseで例外通知

**核心ルール:**
- raiseはインタフェースの一部、ドキュメント化必須
- assertは実装の前提条件検証、呼び出し元での捕捉不要
- assertは開発者向けデバッグメッセージ

**推奨パターン:**
```python
# raiseを使う場合（公開API）
def rate(self, value):
    if not (0 < value <= self.max_rating):
        raise RatingError("Invalid rating")

# assertを使う場合（内部実装）
def rate_internal(self, value):
    assert 0 < value <= self.max_rating, f"Invalid {value=}"
```

### 項目82: contextlibとwith文で再利用可能なtry/finally実現

**核心ルール:**
- @contextmanagerデコレータで関数をコンテキストマネージャ化
- yieldで制御を渡し、finally相当の処理を自動実行
- as節でリソースオブジェクトを取得可能

**推奨パターン:**
```python
from contextlib import contextmanager

@contextmanager
def debug_logging(level):
    logger = logging.getLogger()
    old_level = logger.getEffectiveLevel()
    logger.setLevel(level)
    try:
        yield logger
    finally:
        logger.setLevel(old_level)

with debug_logging(logging.DEBUG) as logger:
    logger.debug("Message")
```

### 項目83: tryブロックを可能な限り短く保つ

**核心ルール:**
- tryに複数のエラー要因を詰め込まない
- 予期されるエラーのみtryに入れる
- その他の処理はelseまたは後続のtryに分離

**推奨パターン:**
```python
# 良い例
try:
    request = lookup_request(connection)
except RpcError:
    close_connection(connection)
else:
    if is_cached(connection, request):
        request = None
```

### 項目84: 例外変数が消失することに注意する

**核心ルール:**
- except内で定義した例外変数はexcept外から参照不可
- 例外情報をfinally等で使う場合は別変数に代入
- tryの前に結果保存用変数を定義

**推奨パターン:**
```python
result = "Unexpected exception"
try:
    raise MyError(123)
except MyError as e:
    result = e
finally:
    print(f"Result: {result}")
```

### 項目85: Exceptionクラスを注意して捕捉する

**核心ルール:**
- 広範なException捕捉は問題を隠蔽する
- 捕捉した例外はログ出力またはreprで表示
- 特定の例外のみ捕捉する方が安全

**推奨パターン:**
```python
try:
    process_data(path)
except FileNotFoundError:  # 具体的な例外
    print("File not found")
except Exception as e:  # やむを得ない場合
    print("Error:", type(e), e)
```

### 項目86: ExceptionとBaseExceptionの違いを理解する

**核心ルール:**
- KeyboardInterrupt/SystemExit等はBaseException直接継承
- 自作例外はExceptionから継承すべき
- BaseException捕捉はクリーンアップのみ、その後raiseで伝播

**推奨パターン:**
```python
# クリーンアップ処理
try:
    process()
except Exception as e:
    print("Error:", e)
finally:
    cleanup()  # 常に実行

# BaseException捕捉の場合は再送出
except KeyboardInterrupt:
    cleanup()
    raise
```

### 項目87: tracebackによる高度な例外報告

**核心ルール:**
- traceback.print_tb()でスタックトレース出力
- traceback.extract_tb()で詳細情報取得
- 並行処理では例外情報を自分で整形する必要あり

**推奨パターン:**
```python
import traceback

try:
    risky_operation()
except Exception as e:
    traceback.print_tb(e.__traceback__)
    stack = traceback.extract_tb(e.__traceback__)
    for frame in stack:
        print(frame.name, frame.lineno)
```

### 項目88: 例外を明示的に連鎖させる

**核心ルール:**
- raise ... from で例外の起点を明示
- __cause__に明示的連鎖、__context__に暗黙的連鎖
- raise ... from None で連鎖を抑制

**推奨パターン:**
```python
# 明示的連鎖
try:
    return my_dict[key]
except KeyError as e:
    try:
        result = contact_server(key)
    except ServerError:
        raise MissingError from e  # eが起点

# 連鎖抑制
except ServerError:
    raise MissingError from None
```

### 項目89: ジェネレータには常にリソースを渡す

**核心ルール:**
- ジェネレータ内でfinallyが実行されるのはStopIteration時のみ
- GeneratorExitはガベージコレクション時に発生
- リソースはジェネレータ外で準備し、引数として渡す

**推奨パターン:**
```python
# 悪い例（ジェネレータ内でリソース管理）
def bad_generator(path):
    with open(path) as handle:
        for line in handle:
            yield len(line)

# 良い例（リソースを外で管理）
def good_generator(handle):
    for line in handle:
        yield len(line)

with open(path) as handle:
    for length in good_generator(handle):
        process(length)
```

### 項目90: \_\_debug\_\_をFalseにしない

**核心ルール:**
- __debug__はデフォルトTrue、-OオプションのみでFalse化
- assert無効化はプログラムの妥当性を損なう
- パフォーマンス最適化は他の方法を検討

**理由:**
assertは実行時検証・デバッグの重要な道具であり、無効化すべきでない。

### 項目91: 開発者ツール以外でevalを使わない

**核心ルール:**
- 動的コード実行関数は単一式評価と複雑なコード実行の2種類
- セキュリティリスクが高い
- 開発者ツール（デバッガ・REPL・ノートブック等）以外では使用禁止

**理由:**
通常のアプリケーションコードで動的コード実行は深刻な問題の兆候。メタプログラミングで代替可能。

## 覚えておくべき重要原則

1. **例外処理の分離**: try/except/else/finallyで責務を明確に分離
2. **raiseとassertの使い分け**: raiseは公開API、assertは内部検証
3. **with文活用**: コンテキストマネージャでリソース管理を簡潔に
4. **広範例外捕捉の危険性**: 必要最小限の例外のみ捕捉
5. **例外連鎖の明示**: raise ... from で起点を明確化
6. **ジェネレータのリソース管理**: リソースは外部で準備・管理
7. **assertの重要性**: __debug__無効化は避ける
8. **動的実行禁止**: 開発者ツール以外では使用しない
