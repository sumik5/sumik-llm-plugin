# 避けるべきコード規則（アンチパターン）- Python編

このファイルでは、Pythonで避けるべきコードパターンを説明します。

## 📋 目次

- [共通アンチパターン（Python）](#共通アンチパターン-python)
- [Python固有のアンチパターン](#python固有のアンチパターン)
- [その他の一般的なアンチパターン（Python）](#その他の一般的なアンチパターン-python)

## 🚫 共通アンチパターン（Python）

### 1. マジックナンバー

#### ❌ 悪い例

```python
# Python
def calculate_discount(price: float) -> float:
    if price > 10000:
        return price * 0.1  # 0.1って何？
    return 0
```

**問題点**:
- 数値の意味が不明
- 変更時に漏れが発生しやすい
- テストが困難

#### ✅ 良い例

```python
# Python
DISCOUNT_THRESHOLD = 10000
DISCOUNT_RATE = 0.1

def calculate_discount(price: float) -> float:
    if price > DISCOUNT_THRESHOLD:
        return price * DISCOUNT_RATE
    return 0
```

### 2. グローバル変数の濫用

#### ❌ 悪い例

```python
# Python - グローバル変数
user_cache: Dict[str, User] = {}

def get_user(user_id: str) -> User:
    return user_cache[user_id]  # グローバル状態に依存

def set_user(user: User) -> None:
    user_cache[user.id] = user  # 副作用
```

**問題点**:
- テストが困難
- 並行処理で問題が発生
- 依存関係が不明確

#### ✅ 良い例

```python
# Python - 依存性注入
class UserRepository:
    def __init__(self) -> None:
        self._cache: Dict[str, User] = {}

    def get_user(self, user_id: str) -> Optional[User]:
        return self._cache.get(user_id)

    def set_user(self, user: User) -> None:
        self._cache[user.id] = user

# 使用時
user_repo = UserRepository()
user = user_repo.get_user('123')
```

### 3. 過度なネスト

#### ❌ 悪い例

```python
# Python
def process_user(user: Optional[User]) -> str:
    if user is not None:
        if user.profile is not None:
            if user.profile.name is not None:
                if len(user.profile.name) > 0:
                    return user.profile.name
    return 'Unknown'
```

**問題点**:
- 可読性が低い
- 保守が困難
- バグが混入しやすい

#### ✅ 良い例

```python
# Python - 早期リターン
def process_user(user: Optional[User]) -> str:
    if user is None:
        return 'Unknown'
    if user.profile is None:
        return 'Unknown'
    if user.profile.name is None:
        return 'Unknown'
    if len(user.profile.name) == 0:
        return 'Unknown'

    return user.profile.name

# さらに良い: getattr と or
def process_user_better(user: Optional[User]) -> str:
    return (
        getattr(getattr(user, 'profile', None), 'name', None)
        or 'Unknown'
    )
```

### 4. 巨大な関数

#### ❌ 悪い例

```python
# Python - 100行を超える巨大関数
def process_order(order: Order) -> OrderResult:
    # 検証処理（20行）
    # 在庫確認（30行）
    # 支払い処理（30行）
    # 通知送信（20行）
    # 合計100行以上...
```

**問題点**:
- 単一責任の原則違反
- テストが困難
- 再利用できない

#### ✅ 良い例

```python
# Python - 小さな関数に分割
def process_order(order: Order) -> OrderResult:
    validate_order(order)
    check_inventory(order)
    process_payment(order)
    send_notification(order)
    return create_result(order)

def validate_order(order: Order) -> None:
    # 検証処理のみ（5-10行）
    pass

def check_inventory(order: Order) -> None:
    # 在庫確認のみ（5-10行）
    pass

def process_payment(order: Order) -> None:
    # 支払い処理のみ（5-10行）
    pass

def send_notification(order: Order) -> None:
    # 通知送信のみ（5-10行）
    pass
```

### 5. コメントアウトされたコード

#### ❌ 悪い例

```python
# Python
def calculate_total(items: List[Item]) -> float:
    # tax = 0.1  # 古い税率
    tax = 0.08
    # return sum(item.price for item in items)  # 古い実装
    return sum(item.price * (1 + tax) for item in items)
```

**問題点**:
- コードが肥大化
- 混乱を招く
- バージョン管理で履歴を見れば十分

#### ✅ 良い例

```python
# Python - コメントアウトされたコードは削除
def calculate_total(items: List[Item]) -> float:
    tax = 0.08
    return sum(item.price * (1 + tax) for item in items)
```

## 🐍 Python固有のアンチパターン

### 1. 可変デフォルト引数

#### ❌ 悪い例（絶対禁止）

```python
# ❌ 可変オブジェクトをデフォルト引数に使用
def add_item(item: str, items: List[str] = []) -> List[str]:
    items.append(item)
    return items

# 問題: すべての呼び出しで同じリストが共有される
list1 = add_item('a')  # ['a']
list2 = add_item('b')  # ['a', 'b'] ← 期待と異なる！
```

**問題点**:
- すべての呼び出しで同じオブジェクトが共有される
- 予期しない副作用が発生
- デバッグが困難

#### ✅ 良い例

```python
# ✅ None をデフォルトにして関数内で初期化
def add_item(item: str, items: Optional[List[str]] = None) -> List[str]:
    if items is None:
        items = []
    items.append(item)
    return items

# または dataclass の field(default_factory=list) を使用
from dataclasses import dataclass, field

@dataclass
class Container:
    items: List[str] = field(default_factory=list)
```

### 2. bare `except` の使用

#### ❌ 悪い例

```python
# ❌ すべての例外をキャッチ
try:
    result = risky_operation()
except:  # KeyboardInterrupt や SystemExit もキャッチ
    print("Error occurred")
```

**問題点**:
- システム例外もキャッチしてしまう
- デバッグが困難
- プログラムの強制終了ができない

#### ✅ 良い例

```python
# ✅ 具体的な例外クラスを指定
try:
    result = risky_operation()
except ValueError as e:
    logger.error(f"Invalid value: {e}")
except KeyError as e:
    logger.error(f"Missing key: {e}")
except Exception as e:  # 最後の手段としてのみ使用
    logger.exception("Unexpected error")
    raise  # 再送出する
```

### 3. `lambda` の過度な使用

#### ❌ 悪い例

```python
# ❌ 複雑な処理を lambda に詰め込む
process = lambda x: x * 2 if x > 0 else x / 2 if x < 0 else 0
```

**問題点**:
- 可読性が低い
- デバッグが困難
- 名前がないため理解しづらい

#### ✅ 良い例

```python
# ✅ 通常の関数として定義
def process_value(x: float) -> float:
    """値を処理する"""
    if x > 0:
        return x * 2
    elif x < 0:
        return x / 2
    return 0

# lambda は単純な処理のみに使用
items.sort(key=lambda x: x.name)  # これはOK
```

### 4. 辞書の `get()` を使わない

#### ❌ 悪い例

```python
# ❌ KeyError が発生する可能性
def get_user_name(user_dict: Dict[str, str]) -> str:
    return user_dict['name']  # 'name' キーが存在しない場合エラー

# ❌ 冗長なチェック
def get_user_name_verbose(user_dict: Dict[str, str]) -> str:
    if 'name' in user_dict:
        return user_dict['name']
    else:
        return 'Unknown'
```

**問題点**:
- KeyError が発生しやすい
- コードが冗長

#### ✅ 良い例

```python
# ✅ get() メソッドを使用
def get_user_name(user_dict: Dict[str, str]) -> str:
    return user_dict.get('name', 'Unknown')

# ✅ TypedDict を使用すればさらに型安全
class UserDict(TypedDict):
    name: str
    email: str

def get_user_name_typed(user: UserDict) -> str:
    return user['name']  # 型チェックで存在が保証される
```

### 5. 文字列の非効率な結合

#### ❌ 悪い例

```python
# ❌ ループ内での文字列結合（非効率）
result = ''
for item in items:
    result += item + ','  # 毎回新しい文字列オブジェクトを生成

# ❌ 非効率な文字列フォーマット
message = 'Hello, ' + name + '! You have ' + str(count) + ' messages.'
```

**問題点**:
- 文字列は不変なため、毎回新しいオブジェクトが生成される
- メモリ効率が悪い
- パフォーマンスが低下

#### ✅ 良い例

```python
# ✅ join() を使用
result = ','.join(items)

# ✅ f-string を使用
message = f'Hello, {name}! You have {count} messages.'

# ✅ リスト内包表記と join の組み合わせ
result = ','.join(str(item) for item in items)
```

## 🔧 その他の一般的なアンチパターン（Python）

### 1. 長すぎる引数リスト

#### ❌ 悪い例

```python
# ❌ 引数が多すぎる
def create_user(
    id: str,
    first_name: str,
    last_name: str,
    email: str,
    age: int,
    address: str,
    phone: str,
    country: str,
    is_active: bool = True
) -> User:
    # ...
    pass
```

**問題点**:
- 引数の順序を覚えるのが困難
- 呼び出し時にミスしやすい
- 可読性が低い

#### ✅ 良い例

```python
# Python - dataclass を使用
@dataclass
class CreateUserParams:
    id: str
    first_name: str
    last_name: str
    email: str
    age: int
    address: str
    phone: str
    country: str
    is_active: bool = True

def create_user(params: CreateUserParams) -> User:
    # ...
    pass

# 使用時
create_user(CreateUserParams(
    id='123',
    first_name='John',
    last_name='Doe',
    email='john@example.com',
    age=30,
    address='123 Main St',
    phone='555-1234',
    country='US'
))
```

## 🔗 関連ファイル

- **[INSTRUCTIONS.md](../INSTRUCTIONS.md)** - developing-python 概要に戻る
- **[TYPE-SAFETY-PYTHON.md](./TYPE-SAFETY-PYTHON.md)** - Python型安全性詳細
- **[TYPE-SAFETY-REFERENCE.md](./TYPE-SAFETY-REFERENCE.md)** - チェックリストとツール設定
