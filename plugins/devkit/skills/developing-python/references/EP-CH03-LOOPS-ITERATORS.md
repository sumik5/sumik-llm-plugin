# 3章: ループとイテレータ

## 概要
Pythonのループは組み込み型に自然に対応し、イテレータで効率的なデータストリーム処理が可能です。`enumerate()`、`zip()`、イテレータプロトコルを理解し、効率的な反復処理を実装しましょう。

## 項目一覧

| 項目 | タイトル | 核心ルール |
|------|---------|-----------|
| 17 | enumerate優先 | `range()`よりインデックス+値取得 |
| 18 | zip並列処理 | 複数イテレータ同時処理 |
| 19 | else避ける | ループ後`else`は混乱招く |
| 20 | ループ変数注意 | ループ後の変数参照避ける |
| 21 | 防御的イテレート | イテレータ vs コンテナ判定 |
| 22 | イテレート中変更禁止 | コピーまたはキャッシュ使用 |
| 23 | any/all活用 | 短絡評価で効率化 |
| 24 | itertools活用 | （詳細は標準ライブラリ参照） |

## 各項目の詳細

### 項目17: enumerate優先

**核心ルール:**
- `range(len())`よりenumerate()
- インデックス+値を同時取得
- 開始値指定可能

**推奨パターン:**
```python
flavor_list = ["vanilla", "chocolate", "pecan"]

# enumerate
for i, flavor in enumerate(flavor_list):
    print(f"{i + 1}: {flavor}")

# 開始値指定
for i, flavor in enumerate(flavor_list, 1):
    print(f"{i}: {flavor}")
```

**アンチパターン:**
```python
# range(len())（冗長）
for i in range(len(flavor_list)):
    flavor = flavor_list[i]
    print(f"{i + 1}: {flavor}")
```

### 項目18: zip並列処理

**核心ルール:**
- 複数イテレータ並列反復
- 最短イテレータで終了
- `strict=True`で長さチェック

**推奨パターン:**
```python
names = ["Cecilia", "Lise", "Marie"]
counts = [7, 4, 5]

# zip
for name, count in zip(names, counts):
    print(f"{name}: {count}")

# 長さチェック
for name, count in zip(names, counts, strict=True):
    print(f"{name}: {count}")
```

**アンチパターン:**
```python
# range(len())とインデックス
for i in range(len(names)):
    name = names[i]
    count = counts[i]
    print(f"{name}: {count}")
```

### 項目19: else避ける

**核心ルール:**
- ループ後`else`は直感に反する
- ヘルパー関数で代替
- 早期リターンまたはフラグ変数

**推奨パターン:**
```python
# 早期リターン
def coprime(a, b):
    for i in range(2, min(a, b) + 1):
        if a % i == 0 and b % i == 0:
            return False
    return True

# フラグ変数
def coprime_alternate(a, b):
    is_coprime = True
    for i in range(2, min(a, b) + 1):
        if a % i == 0 and b % i == 0:
            is_coprime = False
            break
    return is_coprime
```

**アンチパターン:**
```python
# else（混乱）
for i in range(2, min(a, b) + 1):
    if a % i == 0 and b % i == 0:
        print("互いに素ではない")
        break
else:
    print("互いに素")
```

### 項目20: ループ変数注意

**核心ルール:**
- ループ終了後も変数存在
- ループ未実行なら`NameError`
- ループ後の参照避ける

**推奨パターン:**
```python
# ループ変数をループ外で使わない
categories = ["Hydrogen", "Uranium", "Iron", "Other"]
for i, name in enumerate(categories):
    if name == "Iron":
        break

# 結果を別変数に保存
result = None
for i, name in enumerate(categories):
    if name == "Iron":
        result = i
        break
```

**アンチパターン:**
```python
# ループ後の変数参照
for i, name in enumerate(categories):
    if name == "Iron":
        break
print(i)  # 空イテレータならNameError
```

### 項目21: 防御的イテレート

**核心ルール:**
- イテレータは一度のみ消費
- コンテナは複数回イテレート可能
- `__iter__()`でイテレータプロトコル実装

**推奨パターン:**
```python
# イテラブルコンテナクラス
class ReadVisits:
    def __init__(self, data_path):
        self.data_path = data_path

    def __iter__(self):
        with open(self.data_path) as f:
            for line in f:
                yield int(line)

# 防御的チェック
def normalize_defensive(numbers):
    if iter(numbers) is numbers:
        raise TypeError("コンテナを提供してください")
    total = sum(numbers)
    result = []
    for value in numbers:
        percent = 100 * value / total
        result.append(percent)
    return result
```

### 項目22: イテレート中変更禁止

**核心ルール:**
- イテレート中のコンテナ変更は予測困難
- コピーをイテレート
- 変更を別コンテナに段階的実行

**推奨パターン:**
```python
# コピーをイテレート
my_dict = {"red": 1, "blue": 2, "green": 3}
keys_copy = list(my_dict.keys())

for key in keys_copy:
    if key == "blue":
        my_dict["green"] = 4

# 変更用コンテナ
modifications = {}
for key in my_dict:
    if key == "blue":
        modifications["green"] = 4
my_dict.update(modifications)
```

**アンチパターン:**
```python
# イテレート中に変更
for key in my_dict:
    if key == "blue":
        my_dict["yellow"] = 4  # RuntimeError
```

### 項目23: any/all活用

**核心ルール:**
- 短絡評価で効率化
- ジェネレータ式と組み合わせ
- 常に`True`/`False`返却

**推奨パターン:**
```python
# all() - すべて真
all_heads = all(flip_is_heads() for _ in range(20))

# any() - いずれか真
has_tails = any(flip_is_tails() for _ in range(20))
```

**アンチパターン:**
```python
# リスト内包表記（全評価）
all_heads = all([flip_is_heads() for _ in range(20)])
```

## まとめ

ループではenumerate()とzip()を優先し、イテレータプロトコルを理解してコンテナクラスを実装します。イテレート中の変更は避け、any()/all()で効率的な短絡評価を行いましょう。
