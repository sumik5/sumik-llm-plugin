# 9章: 並行性と並列性

## 概要

並行性（同時実行の見かけ）と並列性（真の同時実行）は異なる概念。Pythonはスレッド、コルーチン、マルチプロセスの仕組みを提供するが、それぞれに適した用途がある。

## 項目一覧

| 項目 | タイトル | 核心ルール |
|------|---------|-----------|
| 67 | subprocessでサブプロセスを管理する | subprocessでCPUコアを最大活用 |
| 68 | スレッドはブロッキングI/Oのために使う | GILによりスレッドは並列化できない |
| 69 | Lockを使ってデータ競合を防ぐ | スレッド間の競合状態をLockで保護 |
| 70 | Queueを使ってスレッド間の作業を調整する | パイプライン構築にはQueue使用 |
| 71 | 並行性が必要な状況を認識する | ファンアウト・ファンインで並行処理 |
| 72 | オンデマンドファンアウト用に新しいスレッド生成しない | スレッド生成はコストが高い |
| 73 | Queueによる並行性にはリファクタリングが必要 | Queue使用には複雑なリファクタが必要 |
| 74 | ThreadPoolExecutorを検討する | 固定数スレッドプールで効率化 |
| 75 | コルーチンで高い並行I/Oを実現する | async/awaitで数万の並行処理 |
| 76 | スレッド化I/Oをasyncioに移植する | asyncioへの段階的移行が可能 |
| 77 | asyncioへの移行を容易にする | トップダウン/ボトムアップで移行 |
| 78 | asyncioイベントループの応答性を最大化する | 非同期対応ワーカースレッドで最適化 |
| 79 | 真の並列処理にはProcessPoolExecutorを検討する | CPU並列処理にはmultiprocessing |

## 各項目の詳細

### 項目67: subprocessでサブプロセスを管理する

**核心ルール:**
- サブプロセスは独立して並列実行されるため、CPUコアを最大活用できる
- subprocess.run()で簡単に実行、Popenで高度な制御
- communicate()にtimeout指定でデッドロック回避

**推奨パターン:**
```python
import subprocess

# 簡単な実行
result = subprocess.run(
    ["echo", "Hello"],
    capture_output=True,
    encoding="utf-8"
)

# 並列実行
procs = [subprocess.Popen(["sleep", "1"]) for _ in range(5)]
for proc in procs:
    proc.communicate()
```

### 項目68: スレッドはブロッキングI/Oのために使う

**核心ルール:**
- GIL（グローバルインタプリタロック）により同時実行スレッドは常に1つ
- スレッドはCPU並列化には使えないが、I/O並列化には有効
- システムコール実行時はGIL解放されるため、I/O処理は並列化可能

**推奨パターン:**
```python
from threading import Thread

# ブロッキングI/O処理を並列化
threads = []
for _ in range(5):
    thread = Thread(target=slow_systemcall)
    thread.start()
    threads.append(thread)

for thread in threads:
    thread.join()
```

### 項目69: Lockを使ってデータ競合を防ぐ

**核心ルール:**
- GILがあってもスレッド間のデータ競合は発生する
- バイトコード命令の途中でスレッド切り替えが起こりうる
- Lockを使って共有データへの同時アクセスを保護

**推奨パターン:**
```python
from threading import Lock

lock = Lock()
counter = 0

def worker():
    global counter
    with lock:
        counter += 1  # 安全に更新
```

### 項目70: Queueを使ってスレッド間の作業を調整する

**核心ルール:**
- パイプライン構築にはQueue使用でビジーウェイト排除
- get()はデータ利用可能まで自動ブロック
- task_done()とjoin()で完了待機、shutdown()でスレッド終了

**推奨パターン:**
```python
from queue import Queue
from threading import Thread

in_queue = Queue()
out_queue = Queue()

def worker():
    while True:
        try:
            item = in_queue.get()
        except ShutDown:
            return
        result = process(item)
        out_queue.put(result)
        in_queue.task_done()
```

### 項目71: 並行性が必要な状況を認識する

**核心ルール:**
- ファンアウト: 並行作業単位を生成
- ファンイン: 並行作業完了を待機
- ブロッキングI/Oが多い場合に並行処理が有効

**概念:**
ファンアウト・ファンインによって、数千のI/O処理を効率的に並行実行できる。

### 項目72: オンデマンドファンアウト用に新しいスレッド生成しない

**核心ルール:**
- スレッドは1つあたり8MBメモリ消費
- スレッド生成・切り替えにコストがかかる
- 例外がスレッド開始元に伝播しないためデバッグ困難

**理由:**
大量タスク並行実行にはスレッド以外の方法を検討すべき。

### 項目73: Queueによる並行性にはリファクタリングが必要

**核心ルール:**
- 固定数ワーカースレッド+Queueでスケーラビリティ向上
- 複数フェーズのパイプライン構築には大規模リファクタ必要
- 例外処理を手動で伝播させる必要あり

**理由:**
Queueはスレッド単独よりは優れているが、コードが複雑化する。

### 項目74: ThreadPoolExecutorを検討する

**核心ルール:**
- 固定数スレッドプールで起動コスト削減
- submit()が返すFutureでファンアウト・ファンイン実現
- 例外が自動伝播するためデバッグ容易

**推奨パターン:**
```python
from concurrent.futures import ThreadPoolExecutor

with ThreadPoolExecutor(max_workers=10) as pool:
    futures = [pool.submit(task, arg) for arg in args]
    for future in futures:
        result = future.result()
```

### 項目75: コルーチンで高い並行I/Oを実現する

**核心ルール:**
- async/awaitで数万のコルーチンを効率的に並行実行
- スレッドと異なりメモリオーバーヘッド・起動コスト・ロック不要
- asyncio.gather()でファンイン

**推奨パターン:**
```python
import asyncio

async def main():
    tasks = [async_task(i) for i in range(10000)]
    await asyncio.gather(*tasks)

asyncio.run(main())
```

### 項目76: スレッド化I/Oをasyncioに移植する

**核心ルール:**
- for/with/ジェネレータ等の非同期版が用意されている
- async for, async with, await等で置き換え可能
- asyncio.open_connection()等でソケットをasyncio化

**移行例:**
```python
# 同期版
for item in items:
    process(item)

# 非同期版
async for item in async_items:
    await process(item)
```

### 項目77: asyncioへの移行を容易にする

**核心ルール:**
- トップダウン: エントリポイントからコルーチン化、run_in_executor()でブロッキング処理を隔離
- ボトムアップ: 末端関数からコルーチン化、run_until_complete()で同期実行
- 段階的移行でリスク最小化

**トップダウン:**
```python
async def top():
    loop = asyncio.get_running_loop()
    result = await loop.run_in_executor(None, blocking_func)
```

### 項目78: asyncioイベントループの応答性を最大化する

**核心ルール:**
- イベントループでシステムコールを直接実行するとブロッキング発生
- 専用スレッドに独立イベントループを持たせてI/O処理を隔離
- asyncio.run(debug=True)でブロッキング検出

**推奨パターン:**
```python
class WriteThread(Thread):
    def __init__(self):
        self.loop = asyncio.new_event_loop()

    async def write(self, data):
        # 別スレッドで安全にI/O処理
        pass
```

### 項目79: 真の並列処理にはProcessPoolExecutorを検討する

**核心ルール:**
- GIL制約により、スレッドではCPU並列化不可
- ProcessPoolExecutorで複数CPUコア使用
- 独立かつ高レバレッジなタスクに最適

**推奨パターン:**
```python
from concurrent.futures import ProcessPoolExecutor

with ProcessPoolExecutor(max_workers=8) as pool:
    results = list(pool.map(cpu_bound_func, data))
```

## 覚えておくべき重要原則

1. **GILの制約**: スレッドはI/O並列化のみ、CPU並列化にはmultiprocessing
2. **コルーチンの優位性**: 数万の並行処理にはasync/await
3. **適切なツール選択**: ThreadPoolExecutor > Queue > 生スレッド
4. **段階的移行**: asyncio移行はトップダウンまたはボトムアップで
5. **真の並列**: CPU並列にはProcessPoolExecutor使用
