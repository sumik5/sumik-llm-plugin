# 11章: パフォーマンス

## 概要
Pythonは高級言語としての利点を活かしながら、適切な手法でホストシステムのパフォーマンスを最大限引き出せる。プロファイリング、マイクロベンチマーク、ネイティブ統合、起動最適化、ゼロコピー処理などを活用する。

## 項目一覧

| 項目 | タイトル | 核心ルール |
|------|---------|-----------|
| 92 | 最適化前にプロファイリングを行う | 直感に頼らず、cProfileで測定してボトルネックを特定 |
| 93 | timeitでパフォーマンスが重要なコードを最適化 | マイクロベンチマークで複数の実装を定量比較 |
| 94 | Pythonを別言語に置き換えるタイミングと方法 | 最適化を尽くした後、局所的にネイティブ統合を検討 |
| 95 | ctypesでネイティブライブラリと迅速に統合 | 追加ビルド不要でネイティブライブラリを呼び出し可能 |
| 96 | C拡張APIでネイティブパフォーマンスを実現 | Python APIの強力な機能を活かした高速モジュール作成 |
| 97 | コンパイル済みバイトコードとキャッシュで起動時間短縮 | バイトコードの事前生成とメモリキャッシュで最速起動 |
| 98 | 動的インポートでモジュール遅延読み込み | 必要になるまで依存関係の初期化を遅延 |
| 99 | memoryviewとbytearrayでゼロコピー処理 | バッファプロトコルで大量メモリを高速処理 |

## 各項目の詳細

### 項目92: 最適化前にプロファイリングを行う

**核心ルール:**
- 推測ではなく測定でボトルネックを特定
- profileではなくcProfileを使用（C実装で高速）
- print_callers()とprint_callees()で呼び出し関係を分析

**推奨パターン:**
```python
from cProfile import Profile
from pstats import Stats

profiler = Profile()
profiler.runcall(test_function)

stats = Stats(profiler)
stats.strip_dirs()
stats.sort_stats("cumulative")
stats.print_stats()
```

### 項目93: timeitでパフォーマンスが重要なコードを最適化

**核心ルール:**
- 短いコードのパフォーマンスを正確に測定
- setup引数で準備コードを分離（測定時間に含めない）
- 試行回数を明示的に指定してノイズを軽減

**推奨パターン:**
```python
import timeit

count = 100_000
delay = timeit.timeit(
    setup="data = list(range(10_000))",
    stmt="7777 in data",
    globals=globals(),
    number=count,
)
print(f"{delay / count * 1e9:.2f} nanoseconds")
```

### 項目94: Pythonを別言語に置き換えるタイミングと方法

**核心ルール:**
- アルゴリズムとデータ構造の改良を最優先
- NumPy、Numba、Cython等のツールを先に検討
- 局所的な最適化（カーネル関数等）から始める

**判断基準:**
- プロファイリングとベンチマークを尽くした後
- クリティカルパスのレイテンシが要件を満たさない
- 特殊なアーキテクチャや配布要件がある

### 項目95: ctypesでネイティブライブラリと迅速に統合

**核心ルール:**
- 追加のビルドシステム不要で即座に利用可能
- restype/argtypesで型を明示的に指定
- C呼び出し規約準拠の言語（C、C++、Rust等）に対応

**推奨パターン:**
```python
import ctypes

lib = ctypes.cdll.LoadLibrary("./my_lib.so")
lib.my_func.restype = ctypes.c_double
lib.my_func.argtypes = (ctypes.c_int, ctypes.POINTER(ctypes.c_double))
```

### 項目96: C拡張APIでネイティブパフォーマンスを実現

**核心ルール:**
- Python APIのイテレータプロトコル、数値プロトコルを活用
- メモリ管理とエラー伝播を適切に処理
- ctypesより柔軟だが実装コストが高い

**適用場面:**
- Pythonの動的機能を最大限活用したい
- 任意のイテラブル、数値型に対応したい
- 使いやすいPythonic APIが必要

### 項目97: コンパイル済みバイトコードとキャッシュで起動時間短縮

**核心ルール:**
- バイトコードは__pycache__に自動キャッシュ
- python -m compileallで事前コンパイル可能
- メモリキャッシュとの組み合わせで最大効果

**測定方法:**
```bash
# ファイルシステムキャッシュの影響を確認
time python3 -c 'import my_module'

# バイトコード事前生成
python3 -m compileall my_package
```

### 項目98: 動的インポートでモジュール遅延読み込み

**核心ルール:**
- python -X importtimeで読み込み時間を測定
- 関数内部でimportして実際に必要になるまで遅延
- 動的インポートのオーバーヘッドは約50ナノ秒（許容範囲）

**推奨パターン:**
```python
def handle_command(command):
    if command == "enhance":
        import enhance  # 遅延読み込み
        enhance.process()
    elif command == "adjust":
        import adjust  # 遅延読み込み
        adjust.process()
```

### 項目99: memoryviewとbytearrayでゼロコピー処理

**核心ルール:**
- memoryviewでスライス時のコピーを回避
- bytearrayでミュータブルなバイトバッファを実現
- socket.recv_into()でゼロコピー受信

**推奨パターン:**
```python
# ゼロコピースライス
data = b"large data..."
view = memoryview(data)
chunk = view[1000:2000]  # コピー不要

# ゼロコピー書き込み
buffer = bytearray(1024 * 1024)
write_view = memoryview(buffer)
socket.recv_into(write_view[offset:offset+size])
```

## パフォーマンス最適化の優先順位

1. **測定**: cProfileでボトルネック特定
2. **アルゴリズム**: データ構造とアルゴリズムの改良
3. **ツール活用**: NumPy、Numba、Cython等
4. **ネイティブ統合**: ctypes、C拡張API
5. **起動最適化**: バイトコードキャッシュ、遅延読み込み
6. **I/O最適化**: ゼロコピー処理
