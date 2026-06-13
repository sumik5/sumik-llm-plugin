# アルゴリズム設計: 再帰・バックトラッキング・マルチスレッド

## 第1部: 再帰とバックトラッキング

## 再帰の基本原則

問題を「より小さな同じ構造の問題」に分解し、解を積み上げる手法。

**3つの必須要素:**

| 要素 | 説明 | forループとの対応 |
|------|------|-----------------|
| 初期条件 | 元の問題 | `i = INITIAL_VALUE` |
| 更新 | 問題をより小さな類似問題に縮小 | `i` を次の値へ更新 |
| 終了条件 | 基底条件（base case）: 解が即座・自明な状態 | `i >= LIMIT_VALUE` |

**設計の鉄則:**
- 各再帰呼び出しは必ず基底条件に近づくこと
- 基底条件に到達しない実装は無限再帰（`RecursionError`）を引き起こす

---

## 再帰 vs ループの選択基準

| 状況 | 推奨 | 理由 |
|------|------|------|
| 問題が再帰的に定義されるデータ構造（木・グラフ）を扱う | 再帰 | コードが自然で簡潔になる |
| 分割統治（Divide & Conquer）が本質的な問題 | 再帰 | Quicksort、Merge Sortなど |
| 単純な繰り返し処理（リストの最大値など） | ループ | オーバーヘッドが小さく高速 |
| コールスタックが深くなる可能性がある処理 | ループまたはメモ化 | `RecursionError`を回避 |
| 大量データの逐次処理 | ループ | 関数呼び出しコストを回避 |

---

## 主要な再帰パターン

### 分割統治 (Divide & Conquer)

問題を独立したサブ問題に分割し、各サブ問題の解を結合して元の問題を解く。

**いつ使うか:**

| 条件 | 例 |
|------|-----|
| 問題を同じ構造の独立したサブ問題に分解できる | Quicksort、Merge Sort |
| 最適部分構造を持つ（部分問題の最適解 → 全体の最適解） | 二分探索 |
| サブ問題が重複しない | （重複する場合は動的計画法を検討） |

```python
from typing import Sequence, TypeVar

T = TypeVar("T", int, float, str)


def quicksort(data: list[T], left: int, right: int) -> None:
    """インプレースのQuicksort（分割統治の典型例）。"""
    size = right - left + 1
    if size < 2:
        return
    if size == 2:
        if data[left] > data[right]:
            data[left], data[right] = data[right], data[left]
        return

    pivot_index = _partition(data, left, right)
    quicksort(data, left, pivot_index - 1)
    quicksort(data, pivot_index + 1, right)


def _partition(data: list[T], left: int, right: int) -> int:
    """ピボットを選択してリストを2つのサブリストに分割する。"""
    mid = (left + right) // 2
    pivot = data[mid]
    data[mid], data[right] = data[right], data[mid]  # ピボットを退避

    i, j = left - 1, right
    while i < j:
        i += 1
        while i < right and data[i] <= pivot:
            i += 1
        j -= 1
        while j >= left and data[j] > pivot:
            j -= 1
        if i < j:
            data[i], data[j] = data[j], data[i]

    data[i], data[right] = data[right], data[i]  # ピボットを最終位置へ
    return i
```

**注意点:**
- ピボット選択が偏ると最悪 O(n²) になる（ランダム選択や中央値で緩和）
- Python の組み込み `sorted()` / `.sort()` は Timsort で常に O(n log n) を保証するため、実務では通常 Quicksort を自前実装する必要はない

---

### 二分探索木 (BST) の再帰操作

再帰的に定義されたデータ構造は再帰アルゴリズムと自然にマッチする。

```python
from __future__ import annotations
from dataclasses import dataclass, field
from typing import Optional


@dataclass
class BSTNode:
    value: int
    left: Optional["BSTNode"] = field(default=None, repr=False)
    right: Optional["BSTNode"] = field(default=None, repr=False)


def bst_insert(node: Optional[BSTNode], value: int) -> BSTNode:
    """BST に値を再帰的に挿入する。基底条件: node が None。"""
    if node is None:
        return BSTNode(value=value)
    if value <= node.value:
        node.left = bst_insert(node.left, value)
    else:
        node.right = bst_insert(node.right, value)
    return node


def bst_inorder(node: Optional[BSTNode]) -> list[int]:
    """中順巡回（inorder traversal）でソート済みリストを返す。"""
    if node is None:
        return []
    return bst_inorder(node.left) + [node.value] + bst_inorder(node.right)
```

**木の巡回パターン:**

| 名称 | 順序 | 用途 |
|------|------|------|
| Inorder | 左 → 自分 → 右 | BST のソート済み出力 |
| Preorder | 自分 → 左 → 右 | 木の複製・シリアライズ |
| Postorder | 左 → 右 → 自分 | 木の削除・依存関係解決 |

---

## メモ化と動的計画法: Fibonacci の教訓

### なぜナイーブな再帰は危険か

```python
# 危険: 指数的な呼び出し回数
def fib_naive(n: int) -> int:
    if n < 2:
        return n
    return fib_naive(n - 2) + fib_naive(n - 1)
    # fib(6) だけで 25 回呼び出し、fib(40) で 10 億回超
```

`f(n)` の再帰木は同じ引数で繰り返し呼ばれる（重複サブ問題）。これが指数的爆発の原因。

### `functools.lru_cache` によるメモ化

```python
from functools import lru_cache, cache


@cache  # Python 3.9+: lru_cache(maxsize=None) の糖衣構文
def fib_cached(n: int) -> int:
    """メモ化により O(n) に改善。"""
    if n < 2:
        return n
    return fib_cached(n - 2) + fib_cached(n - 1)


# キャッシュサイズを制限したい場合
@lru_cache(maxsize=128)
def fib_lru(n: int) -> int:
    if n < 2:
        return n
    return fib_lru(n - 2) + fib_lru(n - 1)
```

### 動的計画法（反復版）: 最も安全

```python
def fib_dp(n: int) -> int:
    """ボトムアップDP: スタックオーバーフローのリスクなし。"""
    if n < 2:
        return n
    prev, curr = 0, 1
    for _ in range(2, n + 1):
        prev, curr = curr, prev + curr
    return curr
```

**判断基準:**

| アプローチ | 時間 | 空間 | 推奨場面 |
|-----------|------|------|---------|
| ナイーブ再帰 | O(2^n) | O(n) | デモのみ（実用禁止） |
| `@cache` 付き再帰 | O(n) | O(n) | 自然な再帰表現を活かしたい時 |
| ボトムアップDP | O(n) | O(1) | パフォーマンスが重要な時 |

### `sys.setrecursionlimit` の注意点

Python のデフォルト再帰上限は約 1000（環境依存）。`sys.setrecursionlimit(5000)` で増やせるが根本的な解決にはならない。再帰深度が深くなる処理は反復またはメモ化に変換すること。

---

## バックトラッキングの設計手法

問題を段階的に解き、行き詰まったら直前の選択を取り消して別の選択肢を試す。

**基本構造（決定木探索）:**
1. 現在の段階で選択可能なパスを列挙する
2. 選択を適用して次の段階へ再帰
3. 制約を満たさなくなったら（または解が見つかったら）選択を取り消してバックトラック

**いつ使うか:**

| 問題の性質 | バックトラッキングが有効 |
|-----------|----------------------|
| 制約を満たす配置・組み合わせを全列挙したい | 8-Queens、数独 |
| 複数のステップがあり各ステップに複数の選択肢がある | 迷路探索、パズル |
| 深さ優先で解空間を探索できる | グラフ彩色問題 |

### N-Queens（8-Queens の一般化）

```python
def solve_n_queens(n: int) -> list[list[str]]:
    """N-Queens: バックトラッキングで全解を列挙する。"""
    solutions: list[list[str]] = []
    occupied = [[False] * n for _ in range(n)]

    def _is_safe(row: int, col: int) -> bool:
        # 同じ行を左方向にチェック
        if any(occupied[row][c] for c in range(col)):
            return False
        # 左上対角線
        r, c = row - 1, col - 1
        while r >= 0 and c >= 0:
            if occupied[r][c]:
                return False
            r -= 1
            c -= 1
        # 左下対角線
        r, c = row + 1, col - 1
        while r < n and c >= 0:
            if occupied[r][c]:
                return False
            r += 1
            c -= 1
        return True

    def _find(col: int) -> None:
        for row in range(n):
            if _is_safe(row, col):
                occupied[row][col] = True          # 配置
                if col == n - 1:
                    # 基底条件: 全列に配置完了 → 解として記録
                    board = [
                        "".join("Q" if occupied[r][c] else "." for c in range(n))
                        for r in range(n)
                    ]
                    solutions.append(board)
                else:
                    _find(col + 1)                 # 次の列へ再帰
                occupied[row][col] = False         # バックトラック: 取り消し

    _find(0)
    return solutions
```

**注意点:**
- `occupied[row][col] = False`（取り消し）を忘れると誤った解が生成される
- 大きな `n` では解空間が爆発的に増大する（`n=20` でも数百万解）

## 第2部: マルチスレッド設計

## 並行処理の基本概念

| 概念 | 説明 |
|------|------|
| 並行 (Concurrent) | 複数スレッドが交互に実行（シングルコア） |
| 並列 (Parallel) | 複数スレッドが同時に実行（マルチコア） |
| クリティカルリージョン | 共有リソースにアクセスするコードの範囲 |
| レースコンディション | スレッドの実行順序に結果が依存するバグ |

**Python の GIL と使い分け:**

| 条件 | 推奨 |
|------|------|
| I/O バウンド（ネットワーク・ファイル待機） | `threading` または `asyncio`（GIL が I/O 待機中に解放される） |
| CPU バウンド（計算集約） | `multiprocessing` または `ProcessPoolExecutor`（GIL を回避） |
| 本質的に並行な問題（プロデューサー・コンシューマー） | `threading` + 同期プリミティブ |

GIL により CPython では同時に1スレッドのみ Python バイトコードを実行できる。Python 3.14 以降で無効化オプションが導入される予定。

---

## Mutex（排他制御）: `threading.Lock`

1つのスレッドのみが同時にクリティカルリージョンに入れることを保証する。

**いつ使うか:**

| 状況 | 使う | 使わない |
|------|------|---------|
| 複数スレッドが同じ変数に書き込む | はい | - |
| 読み取り専用の共有データ | - | 基本的に不要 |
| 同時アクセスで整合性が壊れるリソース | はい | - |

```python
import time
from threading import Thread, Lock


def print_message(msg: str, count: int, mutex: Lock) -> None:
    for _ in range(count):
        time.sleep(0.05)
        with mutex:  # acquire() + release() を自動化: デッドロック防止の推奨パターン
            print(msg)


mutex = Lock()
threads = [Thread(target=print_message, args=(msg, 3, mutex)) for msg in ["Hello", "World"]]
for t in threads:
    t.start()
for t in threads:
    t.join()  # メインスレッドが全スレッドの完了を待機
```

**注意点・落とし穴:**

| 問題 | 原因 | 対策 |
|------|------|------|
| デッドロック | `release()` を呼び忘れる | `with` 文を使う |
| デッドロック | 複数の Lock を異なる順序で取得 | 取得順序を全スレッドで統一 |
| レースコンディション | Lock なしで共有データにアクセス | すべての書き込みを Lock で保護 |
| 予測不能な実行順序 | ランタイムがスレッド順を決定 | 順序依存の設計を避ける |

---

## Semaphore（セマフォ）: `threading.Semaphore`

指定した数のスレッドが同時にクリティカルリージョンに入れることを許可する。

**概要:** 内部カウンタを持ち、`acquire()` でデクリメント（0になるとブロック）、`release()` でインクリメント。

**いつ使うか:**

| 状況 | 例 |
|------|-----|
| 同時に N スレッドの読み取りを許可したい（リーダー・ライター問題） | DBのread replica |
| リソースプールの同時利用数を制限したい | DB接続プール |
| 書き込みスレッドは1つ、読み取りは複数許可したい | ログ収集システム |

```python
from threading import Lock, Semaphore, Event
import time


MAX_READERS = 3
_value: int = 0
_write_lock = Lock()
_read_semaphore = Semaphore(MAX_READERS)  # 最大 MAX_READERS スレッドが同時に読み取れる
_started = Event()


def write(writer_id: int, new_value: int) -> None:
    with _write_lock:
        # リーダーがアクティブなうちは待機（セマフォが最大値でない = リーダーが読み取り中）
        while _read_semaphore._value != MAX_READERS:
            time.sleep(0.01)
        global _value
        _value = new_value
        _started.set()
        print(f"Writer {writer_id}: set to {new_value}")


def read(reader_id: int) -> int:
    _started.wait()                          # 初回書き込みを待機
    while _write_lock.locked():
        time.sleep(0.01)
    with _read_semaphore:                    # 最大 MAX_READERS スレッドが同時に入れる
        print(f"Reader {reader_id}: read {_value}")
        return _value
```

**注意点:** ライターが枯死（Starvation）しないよう設計上の制限を設ける。セマフォの初期値は最大同時スレッド数と一致させること。`_value` への直接アクセスは実装依存のため `BoundedSemaphore` を使う方が安全。

---

## Condition（条件変数）: `threading.Condition`

Lock と Event を組み合わせ、「特定の条件が満たされるまで待機→通知」を実現する。

**概要:** `acquire()` でロック取得、`wait()` でロック解放しブロック（通知まで）、`notify()` / `notify_all()` で待機中のスレッドを起こす。

**いつ使うか:**

| 状況 | 例 |
|------|-----|
| Mutex/Semaphore だけでは同期が不十分 | プロデューサー・コンシューマー |
| 「キューが空でなくなった」「キューが満杯でなくなった」などの状態変化を通知したい | 有界キュー |
| スレッド間で細粒度な協調が必要 | パイプライン処理 |

```python
from threading import Thread, Condition
from collections import deque
from typing import Deque


class BoundedQueue:
    """Condition を使った有界キュー（プロデューサー・コンシューマー問題の共有リソース）。"""

    def __init__(self, capacity: int) -> None:
        self._capacity = capacity
        self._data: Deque[int] = deque()
        self._condition = Condition()

    def produce(self, value: int) -> None:
        with self._condition:
            while len(self._data) == self._capacity:
                self._condition.wait()     # キューが満杯: ブロック（Lock を解放して待機）
            self._data.append(value)
            if len(self._data) == 1:      # 空→非空に変化: コンシューマーに通知
                self._condition.notify()

    def consume(self) -> int:
        with self._condition:
            while len(self._data) == 0:
                self._condition.wait()     # キューが空: ブロック
            value = self._data.popleft()
            if len(self._data) == self._capacity - 1:  # 満杯→非満杯: プロデューサーに通知
                self._condition.notify()
            return value
```

**注意点・落とし穴:**

| 問題 | 原因 | 対策 |
|------|------|------|
| `wait()` 後に条件を再チェックしない | 別スレッドが条件を変えた可能性 | `while` ループで条件を再確認（`if` は NG） |
| `notify()` を忘れる | 待機中スレッドが永久ブロック | 状態変化後に必ず `notify()` / `notify_all()` |
| `with condition` 外で `wait()` / `notify()` を呼ぶ | RuntimeError | 必ず `with` ブロック内で使う |

---

## `concurrent.futures.ThreadPoolExecutor`

スレッドの手動管理が不要な高水準 API。I/O バウンドな並行処理に最適。

```python
from concurrent.futures import ThreadPoolExecutor, as_completed


def fetch_all(urls: list[str], max_workers: int = 4) -> list[str]:
    """複数URLを並行フェッチする。"""
    results: list[str] = []
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = {executor.submit(lambda u: f"data:{u}", url): url for url in urls}
        for future in as_completed(futures):
            try:
                results.append(future.result())
            except Exception as exc:
                print(f"error: {exc}")
    return results
```

**API 選択基準:**

| ニーズ | 推奨 |
|--------|------|
| 細粒度な同期制御が必要 | `threading.Thread` + `Lock` / `Semaphore` / `Condition` |
| I/O 並行処理を手軽に実装したい | `ThreadPoolExecutor` |
| CPU バウンドな並列処理 | `ProcessPoolExecutor` または `multiprocessing` |
| 非同期 I/O（大量の並行接続） | `asyncio` |

---

## `asyncio` との関係（概要）

`asyncio` はスレッドではなく協調的マルチタスク（コルーチン）で並行性を実現する。`await` で明示的に制御を譲渡するため、GIL の影響は受けるが、大量の非同期 I/O には `threading` より適している。ブロッキングライブラリを使う既存コードには `threading`、新規の非同期 I/O 集約コードには `asyncio` を選択する。

---

## スレッド設計のベストプラクティス

| 原則 | 内容 |
|------|------|
| `with` 文を使う | `Lock`・`Semaphore`・`Condition` は常に `with` ブロックで使用し、解放漏れを防ぐ |
| 最小限の共有 | 共有リソースを最小化し、可能な限りスレッドローカルなデータを使う |
| 条件を `while` でチェック | `condition.wait()` 後は `if` でなく `while` で条件を再確認する |
| デッドロック対策 | 複数の Lock を取得する順序を全スレッドで統一する |
| CPU バウンドは `multiprocessing` | GIL により Python スレッドは CPU バウンドな処理を並列化できない |
| `ThreadPoolExecutor` を優先 | 手動スレッド管理より高水準 API を好む |
| テストが難しいことを認識する | マルチスレッドバグは再現性が低い; ストレステストと静的解析を活用する |
