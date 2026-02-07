# 1章: Pythonicな考え方

## 概要
Pythonicなコードとは、Pythonコミュニティで共有される独自のイディオムに従ったコードです。明示性、シンプルさ、可読性を重視し、言語の特性を最大限に活用します。

## 項目一覧

| 項目 | タイトル | 核心ルール |
|------|---------|-----------|
| 1 | Pythonバージョンの把握 | Python 3最新版を使用、Python 2は非推奨 |
| 2 | PEP 8スタイルガイド | 一貫したスタイルで可読性向上、Black等で自動化 |
| 3 | コンパイル時エラー検出 | 実行時エラー検出が主、静的解析ツール活用 |
| 4 | 複雑な式の回避 | ヘルパー関数で明確化、DRY原則遵守 |
| 5 | アンパック優先 | インデックス参照よりアンパックで可読性向上 |
| 6 | 単一要素タプルの注意 | 必ず丸括弧で囲み、末尾カンマ |
| 7 | 条件式の適切な使用 | 単純なインラインロジックのみ、複雑なら`if`文 |
| 8 | 代入式で繰り返し削減 | セイウチ演算子`:=`で冗長性削減 |
| 9 | パターンマッチ活用 | 分割と制御構造、`if`文で十分なら不要 |

## 各項目の詳細

### 項目1: Pythonバージョンの把握

**核心ルール:**
- Python 3最新版を使用（本ガイドはPython 3.13対応）
- システム上の実行バージョンを確認（`python --version`）
- Python 2は公式サポート終了済み

**推奨パターン:**
```python
import sys
print(sys.version_info)
# sys.version_info(major=3, minor=12, micro=3, ...)
```

**確認コマンド:**
```bash
$ python3 --version
Python 3.12.3
```

### 項目2: PEP 8スタイルガイド

**核心ルール:**
- 常にPEP 8に従う
- 自動フォーマッタ（Black）で一貫性維持
- 静的解析（Pylint）でエラー検出

**主要ルール:**
- インデント: スペース4つ
- 行長: 79文字以下
- 命名: `lowercase_underscore`（関数・変数）、`CapitalizedWord`（クラス）
- インポート: ファイル先頭、標準→サードパーティ→ファーストパーティ順

**自動フォーマット:**
```bash
$ pip install black
$ python -m black example.py
```

### 項目3: コンパイル時エラー検出への期待禁止

**核心ルール:**
- Pythonはほぼすべてのエラーチェックを実行時まで遅延
- 静的解析ツール（flake8、mypy）で事前検出可能
- テストファースト開発が重要

**例（実行時エラー）:**
```python
def bad_reference():
    print(my_var)  # 定義前に参照
    my_var = 123

# 実行時にUnboundLocalError
```

**対策:**
- 静的解析ツール活用
- 自動テストによる検証

### 項目4: 複雑な式の回避

**核心ルール:**
- 複雑な式はヘルパー関数に移植
- DRY原則（Don't Repeat Yourself）遵守
- 可読性 > 簡潔性

**アンチパターン:**
```python
# 読みにくい
red = int(my_values.get("red", [""])[0] or 0)
```

**推奨パターン:**
```python
def get_first_int(values, key, default=0):
    found = values.get(key, [""])
    if found[0]:
        return int(found[0])
    return default

red = get_first_int(my_values, "red")
```

### 項目5: アンパック優先

**核心ルール:**
- インデックス参照よりアンパック
- スワップも一時変数不要
- `enumerate()`、`zip()`でも活用

**推奨パターン:**
```python
# アンパック
first, second = item

# スワップ
a[i-1], a[i] = a[i], a[i-1]

# enumerate + アンパック
for rank, (name, calories) in enumerate(snacks, 1):
    print(f"{rank}: {name} has {calories} calories")
```

**アンチパターン:**
```python
# インデックス参照
name = item[0]
calories = item[1]
```

### 項目6: 単一要素タプルの丸括弧

**核心ルール:**
- 単一要素タプルは必ず丸括弧で囲む
- 末尾カンマ必須
- 予期しないバグ防止

**推奨パターン:**
```python
single_with = (1,)  # 正しい
```

**アンチパターン:**
```python
single_without = (1)  # タプルではなく整数

# 関数呼び出しで予期しないタプル
to_refund = calculate_refund(
    value1,
    value2,
    value3,)  # 末尾カンマでタプル化（バグ）
```

### 項目7: 条件式の適切な使用

**核心ルール:**
- 単純なインラインロジックのみ使用
- 複雑なら`if`文またはヘルパー関数
- 可読性を損なう場合は避ける

**推奨パターン:**
```python
# 単純なケース
x = "even" if i % 2 == 0 else "odd"

# 複雑なケースはヘルパー関数
def number_group(i):
    if i % 2 == 0:
        return "even"
    else:
        return "odd"

x = number_group(i)
```

**アンチパターン:**
```python
# 複雑すぎて読みにくい
x = (
    my_long_function_call(1, 2, 3)
    if i % 2 == 0
    else my_other_long_function_call(4, 5, 6)
)
```

### 項目8: 代入式で繰り返し削減

**核心ルール:**
- セイウチ演算子`:=`で変数代入と評価を同時実行
- 冗長性削減、可読性向上
- 大きな式の一部なら丸括弧で囲む

**推奨パターン:**
```python
# if文内で代入と評価
if count := fresh_fruit.get("lemon", 0):
    make_lemonade(count)

# while文でloop-and-a-half回避
while fresh_fruit := pick_fruit():
    process(fresh_fruit)

# switch/case風
if (count := fresh_fruit.get("banana", 0)) >= 2:
    make_smoothies(count)
elif (count := fresh_fruit.get("apple", 0)) >= 4:
    make_cider(count)
```

**アンチパターン:**
```python
# 冗長
count = fresh_fruit.get("lemon", 0)
if count:
    make_lemonade(count)
```

### 項目9: パターンマッチで分割

**核心ルール:**
- 異種オブジェクトグラフ、半構造化データで威力発揮
- 単純な`if`文で十分なら不要
- キャプチャパターンに注意

**推奨パターン:**
```python
# 二分木検索
def contains_match(tree, value):
    match tree:
        case pivot, left, _ if value < pivot:
            return contains_match(left, value)
        case pivot, _, right if value > pivot:
            return contains_match(right, value)
        case (pivot, _, _) | pivot:
            return pivot == value

# JSON分解
def deserialize(data):
    record = json.loads(data)
    match record:
        case {"customer": {"last": last_name, "first": first_name}}:
            return PersonCustomer(first_name, last_name)
        case {"customer": {"entity": company_name}}:
            return BusinessCustomer(company_name)
```

**注意点:**
- `case`文の変数は値パターンではなくキャプチャパターン
- ドット演算子`.`またはenum使用で値パターン化

## まとめ

Pythonicなコードは、明示性・シンプルさ・可読性を重視します。PEP 8に従い、アンパックや代入式で冗長性を削減し、適切なツール（Black、Pylint）で品質を維持しましょう。
