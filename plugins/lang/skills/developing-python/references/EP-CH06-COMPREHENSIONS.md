# 6章: 内包表記とジェネレータ

## 概要
Pythonの内包表記とジェネレータは、データ構造の反復処理と派生データ生成を簡潔に記述するための強力な機能。可読性、パフォーマンス、メモリ効率の向上を実現する。

## 項目一覧

| 項目 | タイトル | 核心ルール |
|------|---------|-----------|
| 40 | mapやfilterの代わりに内包表記を使う | リスト内包表記は`lambda`式不要で`map()`/`filter()`より明確 |
| 41 | 内包表記では式を3つ以上使わない | 式が3つ以上の内包表記は可読性が低いので避ける |
| 42 | 代入式を使って内包表記の繰り返しを減らす | 代入式(`:=`)で重複計算を排除し、パフォーマンス向上 |
| 43 | リストではなくジェネレータを返す | `yield`でメモリ効率的に値を生成、任意長入力に対応 |
| 44 | 大きな内包表記にはジェネレータ式を使う | `()`で囲んだジェネレータ式でメモリ消費を抑える |
| 45 | yield fromでジェネレータを組み合わせる | `yield from`で複数ジェネレータを簡潔に結合 |
| 46 | send()の代わりにイテレータを渡す | `send()`より入力イテレータ渡しが明確で保守しやすい |
| 47 | throw()ではなくクラスで状態遷移を管理 | `throw()`より状態管理クラスが可読性高く、ネスト不要 |

## 各項目の詳細

### 項目40: mapやfilterの代わりに内包表記を使う

**核心ルール:**
- リスト内包表記は`lambda`式を必要としないため、`map()`や`filter()`よりも明確
- リスト内包表記は`if`文で簡単にフィルタリングできる。`map()`単独ではフィルタリング不可
- 辞書や集合も内包表記が利用できる
- リスト内包表記は評価時にリスト全体を生成するため、大量メモリを使用する恐れあり

**推奨パターン:**
```python
# リスト内包表記（Good）
a = [1, 2, 3, 4, 5]
squares = [x**2 for x in a]  # [1, 4, 9, 16, 25]

# フィルタリング
even_squares = [x**2 for x in a if x % 2 == 0]  # [4, 16]

# 辞書・集合内包表記
even_squares_dict = {x: x**2 for x in a if x % 2 == 0}
threes_cubed_set = {x**3 for x in a if x % 3 == 0}
```

**アンチパターン:**
```python
# map + lambda（可読性低い）
squares = map(lambda x: x**2, a)

# map + filter（煩雑）
even_squares = map(lambda x: x**2, filter(lambda x: x % 2 == 0, a))

# 辞書をmap + filterで生成（複雑）
alt_dict = dict(
    map(
        lambda x: (x, x**2),
        filter(lambda x: x % 2 == 0, a),
    )
)
```

---

### 項目41: 内包表記では式を3つ以上使わない

**核心ルール:**
- 内包表記は多重ループとループごとの条件文をサポート
- 式が3つ以上存在する内包表記は非常に可読性が低いので避ける

**推奨パターン:**
```python
# 2つまでのループ/条件は許容範囲
matrix = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
flat = [x for row in matrix for x in row]  # OK

# 2つの条件（暗黙のand）
a = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
b = [x for x in a if x > 4 if x % 2 == 0]  # OK
# 同等: [x for x in a if x > 4 and x % 2 == 0]
```

**アンチパターン:**
```python
# 3つ以上のループ（可読性低い）
my_lists = [[[1, 2, 3], [4, 5, 6]], ...]
flat = [x for sublist1 in my_lists
        for sublist2 in sublist1
        for x in sublist2]

# 通常のforループのほうが明確
flat = []
for sublist1 in my_lists:
    for sublist2 in sublist1:
        flat.extend(sublist2)

# 複雑な条件付きフィルタリング（避ける）
filtered = [[x for x in row if x % 4 == 0]
            for row in matrix if sum(row) >= 10]
```

---

### 項目42: 代入式を使って内包表記の繰り返しを減らす

**核心ルール:**
- 代入式(`:=`)を使うと、内包表記やジェネレータ式の`if`文で定義した値を再利用でき、可読性とパフォーマンスが向上
- 代入式を内包表記の`if`文以外で使用することも可能だが、信頼性が低いため避けるべき
- 内包表記内の代入式からの変数は外部スコープにリークする。一方、内包表記のループ変数はリークしない

**推奨パターン:**
```python
stock = {"nails": 125, "screws": 35, "wingnuts": 8, "washers": 24}
order = ["screws", "wingnuts", "clips"]

def get_batches(count, size):
    return count // size

# 代入式で重複排除（Good）
found = {
    name: batches
    for name in order
    if (batches := get_batches(stock.get(name, 0), 8))
}

# ジェネレータ式でも使用可能
found_gen = (
    (name, batches)
    for name in order
    if (batches := get_batches(stock.get(name, 0), 8))
)
```

**アンチパターン:**
```python
# 重複した計算（Bad）
found = {
    name: get_batches(stock.get(name, 0), 8)
    for name in order
    if get_batches(stock.get(name, 0), 8)
}

# 引数の不一致によるバグ
has_bug = {
    name: get_batches(stock.get(name, 0), 4)  # 4と8で不一致
    for name in order
    if get_batches(stock.get(name, 0), 8)
}

# if文以外で代入式（動作不安定）
result = {name: (tenth := count // 10)
          for name, count in stock.items() if tenth > 0}  # NameError
```

---

### 項目43: リストではなくジェネレータを返す

**核心ルール:**
- ジェネレータを返すと、リストより意味が明確になる場合がある
- ジェネレータから返されるイテレータは、`yield`式に渡された値を生成
- ジェネレータは作業メモリに以前の入出力の実体化が含まれないため、任意長入力に対応可能

**推奨パターン:**
```python
# ジェネレータ（Good）
def index_words_iter(text):
    if text:
        yield 0
    for index, letter in enumerate(text):
        if letter == " ":
            yield index + 1

# ファイル処理（メモリ効率的）
def index_file(handle):
    offset = 0
    for line in handle:
        if line:
            yield offset
        for letter in line:
            offset += 1
            if letter == " ":
                yield offset

# 使用例
it = index_words_iter(address)
result = list(it)  # 必要に応じてリスト化
```

**アンチパターン:**
```python
# リストを返す（メモリ消費大）
def index_words(text):
    result = []
    if text:
        result.append(0)
    for index, letter in enumerate(text):
        if letter == " ":
            result.append(index + 1)
    return result

# 問題点:
# - コードが密集して可読性低い
# - append()呼び出しが多く冗長
# - 入力が巨大だとメモリ不足の恐れ
```

---

### 項目44: 大きな内包表記にはジェネレータ式を使う

**核心ルール:**
- 内包表記は大きな入力に対して大量メモリを消費し、問題を引き起こす恐れあり
- ジェネレータ式はイテレータとして出力を1つずつ生成し、メモリ問題を回避
- ジェネレータ式は組み合わせて使うことで、高速かつメモリ効率的に動作

**推奨パターン:**
```python
# ジェネレータ式（Good）
it = (len(x) for x in open("my_file.txt"))  # メモリ効率的
print(next(it))  # 100
print(next(it))  # 57

# ジェネレータ式の組み合わせ（連鎖的に動作）
roots = ((x, x**0.5) for x in it)
print(next(roots))  # (15, 3.872983346207417)
```

**アンチパターン:**
```python
# リスト内包表記（メモリ消費大）
value = [len(x) for x in open("my_file.txt")]
# ファイルが巨大だとメモリオーバーの恐れ
```

---

### 項目45: yield fromでジェネレータを組み合わせる

**核心ルール:**
- `yield from`を使えば、ネストされた複数のジェネレータを単一の結合されたジェネレータとして構成できる
- `yield from`を使えばコードの可読性やパフォーマンスも向上

**推奨パターン:**
```python
def move(period, speed):
    for _ in range(period):
        yield speed

def pause(delay):
    for _ in range(delay):
        yield 0

# yield from使用（Good）
def animate_composed():
    yield from move(4, 5.0)
    yield from pause(3)
    yield from move(2, 3.0)

def run(func):
    for delta in func():
        print(f"Delta: {delta:.1f}")

run(animate_composed)
```

**アンチパターン:**
```python
# 手動でyield（冗長）
def animate():
    for delta in move(4, 5.0):
        yield delta
    for delta in pause(3):
        yield delta
    for delta in move(2, 3.0):
        yield delta
# 冗長で可読性低い
```

---

### 項目46: send()の代わりにイテレータを渡す

**核心ルール:**
- `send()`メソッドを使えば値を`yield`式に挿入できるが、複雑で理解困難
- `yield from`式と`send()`を一緒に使うと、予期しないタイミングで`None`が出現
- `send()`より、複数のジェネレータを組み合わせたものを入力イテレータとして渡すほうが優れている

**推奨パターン:**
```python
import math

# イテレータを渡す方式（Good）
def wave_cascading(amplitude_it, steps):
    step_size = 2 * math.pi / steps
    for step in range(steps):
        radians = step * step_size
        fraction = math.sin(radians)
        amplitude = next(amplitude_it)  # 次の入力を取得
        output = amplitude * fraction
        yield output

# 組み合わせ
def complex_wave_cascading(amplitude_it):
    yield from wave_cascading(amplitude_it, 3)
    yield from wave_cascading(amplitude_it, 4)
    yield from wave_cascading(amplitude_it, 5)

# 使用例
amplitudes = [7, 7, 7, 2, 2, 2, 2, 10, 10, 10, 10, 10]
it = complex_wave_cascading(iter(amplitudes))
for output in it:
    transmit(output)
```

**アンチパターン:**
```python
# send()使用（理解困難）
def wave_modulating(steps):
    step_size = 2 * math.pi / steps
    amplitude = yield  # 初期振幅を受信
    for step in range(steps):
        radians = step * step_size
        fraction = math.sin(radians)
        output = amplitude * fraction
        amplitude = yield output  # 次の振幅を受信

def run_modulating(it):
    amplitudes = [None, 7, 7, 7, 2, 2, 2, 2, 10, 10, 10, 10, 10]
    for amplitude in amplitudes:
        output = it.send(amplitude)
        transmit(output)

# yield fromとsend()の組み合わせ（Noneが多数出現）
def complex_wave_modulating():
    yield from wave_modulating(3)  # Noneが出力される
    yield from wave_modulating(4)
    yield from wave_modulating(5)
```

---

### 項目47: throw()ではなくクラスで状態遷移を管理

**核心ルール:**
- `throw()`メソッドは直近の`yield`式でジェネレータ内に例外を再発生させる
- `throw()`メソッドを使うと例外処理のための追加ネストやボイラープレートが必要となり、可読性が低下
- `throw()`メソッドを使わずに、状態を管理するクラスを定義する

**推奨パターン:**
```python
# クラスで状態管理（Good）
class Timer:
    def __init__(self, period):
        self.current = period
        self.period = period

    def reset(self):
        print("Resetting")
        self.current = self.period

    def tick(self):
        before = self.current
        self.current -= 1
        return before

    def __bool__(self):
        return self.current > 0

# シンプルな使用
def run():
    timer = Timer(4)
    while timer:
        if check_for_reset():
            timer.reset()
        announce(timer.tick())

run()
```

**アンチパターン:**
```python
# throw()使用（複雑で可読性低い）
class Reset(Exception):
    pass

def timer(period):
    current = period
    while current:
        try:
            yield current
        except Reset:
            print("Resetting")
            current = period
        else:
            current -= 1

def run():
    it = timer(4)
    while True:
        try:
            if check_for_reset():
                current = it.throw(Reset())
            else:
                current = next(it)
        except StopIteration:
            break
        else:
            announce(current)
# ネストが深く、理解困難
```
