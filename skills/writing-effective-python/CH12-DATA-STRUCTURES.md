# 12章: データ構造とアルゴリズム

## 概要
Pythonの標準ライブラリには最適化されたデータ構造とアルゴリズムが含まれ、最小限の労力で高パフォーマンスを実現できる。適切な選択でボトルネックを解消し、日付・時刻計算、ソート、キュー処理などの一般的なタスクを効率的に処理する。

## 項目一覧

| 項目 | タイトル | 核心ルール |
|------|---------|-----------|
| 100 | keyパラメータによる複雑なソート | key関数でソート基準を柔軟に指定、タプルで複数キー対応 |
| 101 | sort()とsorted()の違いを理解する | sort()はインプレース、sorted()は新リスト生成 |
| 102 | bisectでソート済みシーケンスを効率的に探索 | 二分探索でO(log n)の高速検索を実現 |
| 103 | heapqで優先度キューを実装 | ヒープでO(log n)の効率的な優先度管理 |
| 104 | 比較可能なクラスを作る | __lt__等の特殊メソッドで自然な順序を定義 |
| 105 | dequeで両端操作を効率化 | 両端からのpush/popがO(1)の効率 |
| 106 | Decimalで正確な小数計算 | 浮動小数点の丸め誤差を回避 |
| 107 | datetimeとzoneinfoで日時処理 | タイムゾーン対応の正確な日時計算 |

## 各項目の詳細

### 項目100: keyパラメータによる複雑なソート

**核心ルール:**
- sort()のkeyパラメータで任意の基準でソート可能
- タプル返却で複数キーによるソート実現
- 安定ソートの性質を活用して複雑なソート順も可能

**推奨パターン:**
```python
# 属性でソート
tools.sort(key=lambda x: x.weight)

# 複数キーでソート
tools.sort(key=lambda x: (x.weight, x.name))

# ソート方向の混在（数値のみ）
tools.sort(key=lambda x: (-x.weight, x.name))

# 大文字小文字を無視
places.sort(key=lambda x: x.lower())
```

### 項目101: sort()とsorted()の違いを理解する

**核心ルール:**
- sort()はリストをインプレースで変更（元の順序が失われる）
- sorted()は新しいリストを返す（元のオブジェクトは不変）
- sorted()は任意のイテラブルを受け取れる

**推奨パターン:**
```python
# インプレース変更
data = [3, 1, 2]
data.sort()  # [1, 2, 3]

# 新リスト生成
original = [3, 1, 2]
sorted_list = sorted(original)  # [1, 2, 3]
# original は [3, 1, 2] のまま

# イテレータも受け取れる
sorted_gen = sorted(x for x in range(10, 0, -1))
```

### 項目102: bisectでソート済みシーケンスを効率的に探索

**核心ルール:**
- bisect_leftで二分探索（O(log n)）
- ソート済みリストへの効率的な挿入
- 線形探索（O(n)）の代替として劇的な高速化

**推奨パターン:**
```python
from bisect import bisect_left, insort

# 挿入位置を検索
data = [1, 3, 5, 7, 9]
index = bisect_left(data, 6)  # 3

# ソート順を保ちながら挿入
insort(data, 6)  # [1, 3, 5, 6, 7, 9]
```

### 項目103: heapqで優先度キューを実装

**核心ルール:**
- heappushとheappopでO(log n)の優先度キュー
- 最小値を常に先頭に維持
- タプルで優先度付きアイテムを管理

**推奨パターン:**
```python
from heapq import heappush, heappop

heap = []
heappush(heap, (5, 'task5'))
heappush(heap, (1, 'task1'))
heappush(heap, (3, 'task3'))

while heap:
    priority, task = heappop(heap)
    print(f"{task}: priority {priority}")
```

### 項目104: 比較可能なクラスを作る

**核心ルール:**
- __lt__、__le__、__gt__、__ge__、__eq__、__ne__を定義
- functools.total_orderingで省力化
- 自然な順序でソートやmin/max使用可能に

**推奨パターン:**
```python
from functools import total_ordering

@total_ordering
class Person:
    def __init__(self, name, age):
        self.name = name
        self.age = age

    def __eq__(self, other):
        return self.age == other.age

    def __lt__(self, other):
        return self.age < other.age
```

### 項目105: dequeで両端操作を効率化

**核心ルール:**
- appendleft/popleftでO(1)の両端アクセス
- リストの先頭操作（O(n)）の代替
- 固定サイズバッファとして活用

**推奨パターン:**
```python
from collections import deque

# 両端からの効率的な操作
queue = deque()
queue.append('a')      # 右端に追加
queue.appendleft('b')  # 左端に追加
queue.pop()            # 右端から削除
queue.popleft()        # 左端から削除

# 固定サイズバッファ
recent = deque(maxlen=5)
for i in range(10):
    recent.append(i)  # 自動的に古いものを削除
```

### 項目106: Decimalで正確な小数計算

**核心ルール:**
- 浮動小数点の丸め誤差を回避
- 金融計算など正確性が必要な場面で使用
- 文字列から生成して精度を保証

**推奨パターン:**
```python
from decimal import Decimal, ROUND_HALF_UP

# 正確な計算
price = Decimal('1.10')
tax = Decimal('0.08')
total = price * (1 + tax)

# 丸め制御
result = total.quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
```

### 項目107: datetimeとzoneinfoで日時処理

**核心ルール:**
- datetimeでタイムゾーン対応の日時処理
- zoneinfoでIANA Time Zone Database使用
- UTCで保存、表示時にローカル変換が推奨

**推奨パターン:**
```python
from datetime import datetime
from zoneinfo import ZoneInfo

# タイムゾーン対応
utc_time = datetime.now(ZoneInfo("UTC"))
tokyo_time = utc_time.astimezone(ZoneInfo("Asia/Tokyo"))

# 日時演算
from datetime import timedelta
future = tokyo_time + timedelta(days=7)
```

## データ構造選択の指針

| 操作 | 推奨データ構造 | 時間計算量 |
|------|--------------|-----------|
| 順序付きコレクション | list | O(1) append, O(n) insert |
| 両端操作 | deque | O(1) 両端操作 |
| 重複なし集合 | set | O(1) 追加/削除/検索 |
| キー値ペア | dict | O(1) 取得/設定 |
| ソート済み検索 | bisect + list | O(log n) 検索 |
| 優先度管理 | heapq + list | O(log n) push/pop |
| 正確な小数 | Decimal | - |
| 日時処理 | datetime | - |
