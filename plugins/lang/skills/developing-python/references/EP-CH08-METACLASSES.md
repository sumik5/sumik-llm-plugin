# 8章: メタクラスと属性

## 概要
Pythonの動的な属性参照とメタクラスを活用した高度な機能。`@property`、ディスクリプタ、`__getattr__`/`__setattr__`、`__init_subclass__`などで柔軟なクラス設計を実現。

## 項目一覧

| 項目 | タイトル | 核心ルール |
|------|---------|-----------|
| 58 | getter/setterの代わりにパブリック属性を使う | 単純なパブリック属性から開始。`@property`で特殊な振る舞いを追加。副作用は避ける |
| 59 | @propertyでリファクタリング | `@property`で既存属性に新機能を付与し、段階的にデータモデルを改善 |
| 60 | ディスクリプタで@propertyを再利用 | ディスクリプタで`@property`の動作を再利用。`__set_name__()`でメモリリーク回避 |
| 61 | `__getattr__`/`__setattr__`で遅延属性 | 存在しない属性は`__getattr__`、全属性は`__getattribute__`。無限再帰に注意 |
| 62 | `__init_subclass__`で派生クラス検証 | メタクラスより`__init_subclass__`が簡潔。クラス定義時に検証実行 |
| 63 | `__init_subclass__`でクラス登録 | 派生クラス定義時に自動登録。メタクラスより理解しやすい |
| 64 | `__set_name__`で属性にアノテーション | ディスクリプタの`__set_name__`で属性名を自動取得。メタクラス不要 |
| 65 | クラス本文の定義順序を考慮 | `__dict__`の挿入順序を利用してCSV列順を保持 |
| 66 | `__init_subclass__`でクラスデコレータを優先 | クラスデコレータよりメタクラス、メタクラスより`__init_subclass__` |

## 各項目の詳細

### 項目58: getter/setterの代わりにパブリック属性を使う

**核心ルール:**
- 単純なパブリック属性でクラスインタフェースを定義（`getter()`/`setter()`不要）
- 特殊な振る舞いが必要な場合は`@property`を使う
- 驚き最小の原則に従い、`@property`で副作用を伴う奇妙な動きを実装しない
- `@property`は高速であること。遅い作業や複雑な処理は通常のメソッドを使用

**推奨パターン:**
```python
# シンプルなパブリック属性
class Resistor:
    def __init__(self, ohms):
        self.ohms = ohms
        self.voltage = 0
        self.current = 0

# @propertyで検証を追加
class BoundedResistance(Resistor):
    @property
    def ohms(self):
        return self._ohms

    @ohms.setter
    def ohms(self, ohms):
        if ohms <= 0:
            raise ValueError(f"ohms must be > 0; got {ohms}")
        self._ohms = ohms
```

---

### 項目59: @propertyでリファクタリング

**核心ルール:**
- 既存のインスタンス属性に新機能を付与する際に`@property`を使用
- `@property`でよりよいデータモデルに向けて段階的に進化
- `@property`を過度に使う場合はクラスをリファクタリング

**推奨パターン:**
```python
class NewBucket:
    def __init__(self, period):
        self.period_delta = timedelta(seconds=period)
        self.reset_time = datetime.now()
        self.max_quota = 0
        self.quota_consumed = 0

    @property
    def quota(self):
        return self.max_quota - self.quota_consumed

    @quota.setter
    def quota(self, amount):
        delta = self.max_quota - amount
        if amount == 0:
            self.quota_consumed = 0
            self.max_quota = 0
        elif delta < 0:
            self.max_quota = amount + self.quota_consumed
        else:
            self.quota_consumed = delta
```

---

### 項目60: ディスクリプタで@propertyを再利用

**核心ルール:**
- ディスクリプタクラスで`@property`の動作とバリデーションを再利用
- `__set_name__()`や`setattr()`/`getattr()`でインスタンス辞書にデータを保存し、メモリリーク回避
- `__getattribute__()`の動作理解に時間をかけすぎない

**推奨パターン:**
```python
class NamedGrade:
    def __set_name__(self, owner, name):
        self.internal_name = "_" + name

    def __get__(self, instance, instance_type):
        if instance is None:
            return self
        return getattr(instance, self.internal_name)

    def __set__(self, instance, value):
        if not (0 <= value <= 100):
            raise ValueError("Grade must be between 0 and 100")
        setattr(instance, self.internal_name, value)

class Exam:
    math_grade = NamedGrade()
    writing_grade = NamedGrade()
```

---

### 項目61: `__getattr__`/`__setattr__`で遅延属性

**核心ルール:**
- `__getattr__()`と`__setattr__()`でオブジェクト属性の遅延参照を実現
- `__getattr__()`は存在しない属性のみ、`__getattribute__()`は任意の属性で呼び出される
- `super().__getattribute__()`と`super().__setattr__()`で無限再帰を回避

**推奨パターン:**
```python
class LazyRecord:
    def __init__(self):
        self.exists = 5

    def __getattr__(self, name):
        value = f"Value for {name}"
        setattr(self, name, value)
        return value

# __getattribute__使用時は無限再帰に注意
class FixedDictionaryRecord:
    def __init__(self, data):
        self._data = data

    def __getattribute__(self, name):
        if name == "_data":
            return super().__getattribute__(name)
        return self._data[name]
```

---

### 項目62: `__init_subclass__`で派生クラス検証

**核心ルール:**
- メタクラスの`__new__()`はクラス文処理後に実行されるが、重くなりがち
- `__init_subclass__()`でオブジェクト生成前に派生クラスの妥当性を確認
- `super().__init_subclass__()`で複雑な継承関係や多重継承も検証可能

**推奨パターン:**
```python
class BetterPolygon:
    sides = None

    def __init_subclass__(cls):
        super().__init_subclass__()
        if cls.sides < 3:
            raise ValueError("Polygons need 3+ sides")

    @classmethod
    def interior_angles(cls):
        return (cls.sides - 2) * 180

class Hexagon(BetterPolygon):
    sides = 6

# class Point(BetterPolygon):
#     sides = 1  # ValueError: Polygons need 3+ sides
```

---

### 項目63: `__init_subclass__`でクラス登録

**核心ルール:**
- クラス登録はモジュール性の高いPythonプログラムの有用なパターン
- メタクラスで基底クラス継承時に登録コードを自動実行可能
- メタクラスより`__init_subclass__`が明確で初心者に理解しやすい

**推奨パターン:**
```python
REGISTRY = {}

def register_class(target_class):
    REGISTRY[target_class.__name__] = target_class

def deserialize(data):
    params = json.loads(data)
    name = params["class"]
    target_class = REGISTRY[name]
    return target_class(*params["args"])

class BetterRegisteredSerializable(BetterSerializable):
    def __init_subclass__(cls):
        super().__init_subclass__()
        register_class(cls)

class Vector1D(BetterRegisteredSerializable):
    def __init__(self, magnitude):
        super().__init__(magnitude)
        self.magnitude = magnitude
```

---

### 項目64: `__set_name__`で属性にアノテーション

**核心ルール:**
- メタクラスでクラス定義前に属性を変更可能だが複雑
- ディスクリプタとメタクラスの組み合わせは宣言的動作と動的イントロスペクションを実現
- ディスクリプタの`__set_name__()`で自動的にクラスと属性名を扱う

**推奨パターン:**
```python
class Field:
    def __init__(self):
        self.column_name = None
        self.internal_name = None

    def __set_name__(self, owner, column_name):
        self.column_name = column_name
        self.internal_name = "_" + column_name

    def __get__(self, instance, instance_type):
        if instance is None:
            return self
        return getattr(instance, self.internal_name, "")

    def __set__(self, instance, value):
        setattr(instance, self.internal_name, value)

class Customer:  # 基底クラス不要
    first_name = Field()
    last_name = Field()
```

---

### 項目65: クラス本文の定義順序を考慮

**核心ルール:**
- `__init_subclass__()`で派生クラス定義時にコード実行
- クラスオブジェクトの`__dict__`で属性にアクセス
- 辞書の挿入順序保持を利用してCSV列順を維持

**推奨パターン:**
```python
class BetterRowMapper(RowMapper):
    def __init_subclass__(cls):
        fields = []
        for key, value in cls.__dict__.items():
            if value is Ellipsis:  # ...
                fields.append(key)
        cls.fields = tuple(fields)

class DeliveryMapper(BetterRowMapper):
    destination = ...
    method = ...
    weight = ...
```

---

### 項目66: クラスデコレータより`__init_subclass__`

**核心ルール:**
- クラスデコレータは適用忘れやすく、継承時に適用されない
- メタクラスは複雑でクラス定義ごとに1つのみ
- `__init_subclass__`が最も簡潔で柔軟、多重継承対応

**推奨パターン:**
```python
# __init_subclass__が最適（Good）
class BetterPolygon:
    def __init_subclass__(cls):
        super().__init_subclass__()
        if cls.sides < 3:
            raise ValueError("Polygons need 3+ sides")

# クラスデコレータ（適用忘れリスク）
@validate_polygon
class Triangle:
    sides = 3  # デコレータ適用忘れると検証されない

# メタクラス（複雑）
class ValidatePolygon(type):
    def __new__(meta, name, bases, class_dict):
        # 複雑な実装
        ...
```
