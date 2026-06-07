# Behavioral Design Patterns（振る舞いパターン）

オブジェクト間の責務分担とアルゴリズムのカプセル化に関するパターン。

## パターン概要

| パターン | 目的 | 使用場面 |
|---------|------|---------|
| Template Method | アルゴリズムの骨格を定義し、一部のステップをサブクラスに委譲 | 処理手順が固定で、一部の実装が異なる複数のバリエーションがある場合 |
| Strategy | アルゴリズムのファミリを定義・カプセル化し、実行時に交換可能にする | 複数のアルゴリズムを実行時に切り替えたい場合 |
| Iterator | コレクションの内部表現を隠蔽しつつ要素を順次アクセスする | 異なる種類のコレクションを統一インターフェースで走査したい場合 |
| Visitor | データ構造を変更せずに新しい操作を追加する | 単一のデータ構造に対して複数の異なるアルゴリズムを適用したい場合 |
| Observer | オブジェクトの状態変化を複数の依存オブジェクトに自動通知する | Publisher-Subscriberモデルが必要な場合 |
| State | オブジェクトの内部状態に応じて振る舞いを変える | 状態遷移を明示的に管理したい場合 |

---

## Template Method

**目的**: アルゴリズムの骨格を抽象クラスで定義し、可変ステップをサブクラスに委譲する。

**問題**: 複数のクラスで同じ処理手順（ヘッダー→データ取得→解析→レポート→フッター）を踏むが、一部ステップの実装が異なる。骨格コードが重複する。

**解決策**: 抽象スーパークラスが「テンプレートメソッド」で手順を固定し、共通ステップを実装する。可変ステップは `@abstractmethod` でサブクラスに委譲する。

```python
from abc import ABC, abstractmethod

class GameReport(ABC):
    def __init__(self, title: str) -> None:
        self._title = title

    # 共通ステップ（スーパークラスが実装）
    def _print_header(self) -> None:
        print(self._title)

    def _print_footer(self) -> None:
        print("End of report")

    # 可変ステップ（サブクラスに委譲）
    @abstractmethod
    def _acquire_data(self) -> None: ...

    @abstractmethod
    def _analyze_data(self) -> None: ...

    @abstractmethod
    def _print_report(self) -> None: ...

    # テンプレートメソッド（手順を固定）
    def generate_report(self) -> None:
        self._print_header()
        self._acquire_data()
        self._analyze_data()
        self._print_report()
        self._print_footer()

class BaseballReport(GameReport):
    def __init__(self) -> None:
        super().__init__("BASEBALL GAME REPORT")

    def _acquire_data(self) -> None: ...
    def _analyze_data(self) -> None: ...
    def _print_report(self) -> None: ...
```

**Python固有のポイント**:
- `abc.ABC` と `@abstractmethod` でインターフェースを強制
- フックメソッド（省略可能な拡張点）は `pass` の代わりに `...` で示すとPythonicに見える

---

## Strategy

**目的**: アルゴリズムのファミリを定義・カプセル化し、クライアントから独立して切り替えられるようにする。

**問題**: 複数のアルゴリズムをサブクラスに実装すると固定されてコードが重複し、実行時の切り替えができない。

**解決策**: 各アルゴリズムを独立したStrategyクラスにカプセル化。クライアントはCompositionで集約し、実行時に差し替えられる。

```python
from abc import ABC, abstractmethod
from typing import Protocol

class PlayerStrategy(ABC):
    @abstractmethod
    def execute(self) -> str: ...

class BaseballPlayers(PlayerStrategy):
    def execute(self) -> str:
        return "baseball players"

class FootballPlayers(PlayerStrategy):
    def execute(self) -> str:
        return "football players"

class Sport:
    def __init__(self, player_strategy: PlayerStrategy) -> None:
        self._player_strategy = player_strategy

    @property
    def player_strategy(self) -> PlayerStrategy:
        return self._player_strategy

    @player_strategy.setter
    def player_strategy(self, strategy: PlayerStrategy) -> None:
        self._player_strategy = strategy  # 実行時に切り替え可能

    def recruit_players(self) -> str:
        return self._player_strategy.execute()
```

**第一級関数を使ったStrategy（クラス不要なケース）**:

```python
from typing import Callable

StrategyFn = Callable[[], str]

def recruit(strategy: StrategyFn) -> str:
    return strategy()

# 関数やラムダをStrategyとして渡す
recruit(lambda: "baseball players")
```

**`typing.Protocol` による構造的サブタイピング**:

```python
class HasExecute(Protocol):
    def execute(self) -> str: ...

# ABCを継承しなくても execute() を持つ任意のオブジェクトを受け入れる
def use_strategy(s: HasExecute) -> str:
    return s.execute()
```

---

## 使い分け判断テーブル: Template Method vs Strategy

| 観点 | Template Method | Strategy |
|------|----------------|---------|
| 関係の種類 | 継承（is-a） | 合成（has-a） |
| アルゴリズムの範囲 | 手順の一部をカスタマイズ | アルゴリズム全体を交換 |
| 実行時の切り替え | 不可（サブクラスで固定） | 可能（setterで切り替え） |
| 適した場面 | 処理の流れが固定で一部だけ違う場合 | 独立したアルゴリズムを実行時に選択したい場合 |

---

## Iterator

**目的**: コレクションの内部表現を公開せずに、要素を順次アクセスする手段を提供する。

**問題**: list・generator・dictなど異なるコレクションを扱うと、クライアントコードがコレクション実装に依存し、コレクションごとに別々のループ処理が必要になる。

**解決策**: 各コレクションにIteratorオブジェクトを返させ、クライアントは `has_next()`/`next()` インターフェースを通じてアクセスする。

```python
from abc import ABC, abstractmethod
from typing import Generic, TypeVar

T = TypeVar("T")

class Iterator(ABC, Generic[T]):
    @abstractmethod
    def next(self) -> T: ...

    @abstractmethod
    def has_next(self) -> bool: ...

class ListIterator(Iterator[tuple[int, str, str]]):
    def __init__(self, items: list[tuple[int, str, str]]) -> None:
        self._items = items
        self._index = -1

    def next(self) -> tuple[int, str, str]:
        self._index += 1
        return self._items[self._index]

    def has_next(self) -> bool:
        return self._index < len(self._items) - 1

# クライアントコード: コレクション種別に依存しない
def print_items(it: Iterator[tuple[int, str, str]]) -> None:
    while it.has_next():
        player_id, last, first = it.next()
        print(f"{player_id} {last}, {first}")
```

**Pythonネイティブの `__iter__` / `__next__` プロトコル**:

```python
class PlayerIterator:
    def __init__(self, players: list[tuple[int, str, str]]) -> None:
        self._players = players
        self._index = 0

    def __iter__(self) -> "PlayerIterator":
        return self

    def __next__(self) -> tuple[int, str, str]:
        if self._index >= len(self._players):
            raise StopIteration
        item = self._players[self._index]
        self._index += 1
        return item

# for文・list()・next()などPythonの組み込み機能と自動的に連携する
for player_id, last, first in PlayerIterator(players):
    print(f"{player_id} {last}, {first}")
```

---

## Visitor

**目的**: オブジェクト構造のクラスを変更せずに、そのオブジェクトに対する新しい操作を定義する。

**問題**: ツリー構造のデータに対して複数の異なるアルゴリズムを適用したい。アルゴリズムをデータクラスに直接書くと単一責任原則に違反し、新規レポート追加のたびにデータクラスを変更しなければならない。

**解決策**: データクラスは `accept(visitor)` インターフェースのみ持ち、アルゴリズムをVisitorクラスにカプセル化する（ダブルディスパッチ）。

```python
from abc import ABC, abstractmethod

class Visitor(ABC):
    @abstractmethod
    def visit_sport(self, node: "Sport") -> None: ...

    @abstractmethod
    def visit_game(self, node: "Game") -> None: ...

class Node(ABC):
    @abstractmethod
    def accept(self, visitor: Visitor) -> None: ...

class Sport(Node):
    def __init__(self, sport_type: str) -> None:
        self._type = sport_type
        self._games: list["Game"] = []

    @property
    def type(self) -> str:
        return self._type

    @property
    def games_count(self) -> int:
        return len(self._games)

    def accept(self, visitor: Visitor) -> None:
        visitor.visit_sport(self)
        for game in self._games:
            game.accept(visitor)

# Visitor実装（アルゴリズムをカプセル化）
class ActivitiesReportVisitor(Visitor):
    def visit_sport(self, node: Sport) -> None:
        print(f"{node.type}: {node.games_count} game(s)")

    def visit_game(self, node: "Game") -> None:
        return  # このレポートでは不要

# 新しいレポートはVisitorを追加するだけ。データクラスは無変更。
```

---

## 使い分け判断テーブル: Iterator vs Visitor

| 観点 | Iterator | Visitor |
|------|---------|---------|
| コレクション数 | 複数の異なるコレクション | 単一のデータ構造 |
| アルゴリズム数 | 単一のアルゴリズム | 複数の異なるアルゴリズム |
| データ型の均質性 | 同一型の要素 | 異なる型のノード（ツリー等） |
| 主な解決課題 | コレクション実装の隠蔽 | アルゴリズムとデータの分離 |

---

## Observer

**目的**: オブジェクト間に一対多の依存関係を定義し、あるオブジェクトが状態変化するとすべての依存オブジェクトに自動通知される。

**問題**: PublisherがSubscriberをハードコードしていると、新しいSubscriberを追加するたびにPublisherクラスを変更しなければならない。

**解決策**: `Subject`（Publisher）と `Observer`（Subscriber）インターフェースを定義する。Observerは `attach()`/`detach()` で動的に登録・解除できる。

```python
from abc import ABC, abstractmethod

class Observer(ABC):
    @abstractmethod
    def update(self, player_name: str | None) -> None: ...

class Subject:
    def __init__(self) -> None:
        self._observers: list[Observer] = []

    def attach(self, observer: Observer) -> None:
        self._observers.append(observer)

    def detach(self, observer: Observer) -> None:
        self._observers.remove(observer)

    def _notify(self, player_name: str | None) -> None:
        for obs in self._observers:
            obs.update(player_name)

class BaseballReporter(Subject):
    def __init__(self) -> None:
        super().__init__()
        self._current_event: "Event | None" = None

    @property
    def current_event(self) -> "Event | None":
        return self._current_event

    def report_hits(self) -> None:
        # イベント生成→通知のループ
        self._notify(None)  # ゲーム終了通知

class LogReport(Observer):
    def __init__(self, reporter: BaseballReporter) -> None:
        reporter.attach(self)  # コンストラクタで自己登録

    def update(self, player_name: str | None) -> None:
        if player_name is None:
            return
        event = ...  # current_eventを取得して処理

class FanClubReport(Observer):
    """特定プレイヤーのイベントのみ処理し、取得後に自動購読解除"""
    def __init__(self, reporter: BaseballReporter, idol: str) -> None:
        self._reporter = reporter
        self._idol = idol
        reporter.attach(self)

    def update(self, player_name: str | None) -> None:
        if player_name == self._idol:
            # ... 処理 ...
            self._reporter.detach(self)  # 購読解除
```

**Python固有のポイント**:
- `str | None` のUnion型でゲーム終了シグナルを型安全に表現
- `list[Observer]` で型安全なObserverリストを管理

---

## State

**目的**: オブジェクトの内部状態が変化するとオブジェクトの振る舞いを変える。

**問題**: チケット機が4状態×4アクション=16の組み合わせを `match self._state:` で実装すると、コードが膨大になり単一責任原則に違反する。状態追加時に全メソッドを変更しなければならない。

**解決策**: 各状態を独立したクラスにカプセル化し、Contextはアクションメソッドを現在のStateオブジェクトに委譲する。各Stateのアクションは次の状態を返す。

```python
from abc import ABC, abstractmethod
from enum import Enum

class Validity(Enum):
    YES = 1
    NO = 2
    UNKNOWN = 3

class State(ABC):
    def __init__(self, name: str, machine: "TicketMachine") -> None:
        self._name = name
        self._machine = machine

    @property
    def name(self) -> str:
        return self._name

    @property
    def states(self) -> "StatesBlock":
        return self._machine._states_block

    @abstractmethod
    def insert_credit_card(self) -> "State": ...

    @abstractmethod
    def take_ticket(self) -> "State": ...

class READY(State):
    def __init__(self, machine: "TicketMachine") -> None:
        super().__init__("READY", machine)

    def insert_credit_card(self) -> State:
        print("Validating your credit card.")
        return self.states.VALIDATING  # 状態遷移を返す

    def take_ticket(self) -> State:
        print("First insert your credit card.")
        return self  # 状態維持

class StatesBlock:
    """全Stateオブジェクトを集約。State間の疎結合を実現"""

    READY: State
    VALIDATING: State

    def initialize(self, machine: "TicketMachine") -> State:
        self.READY = READY(machine)
        # self.VALIDATING = VALIDATING(machine) ...
        return self.READY

class TicketMachine:
    """ContextはStateに委譲するのみ。状態ロジックを持たない"""

    def __init__(self, count: int) -> None:
        self._count = count
        self._card_validity = Validity.UNKNOWN
        self._states_block = StatesBlock()
        self._state: State = self._states_block.initialize(self)

    def _insert_credit_card(self) -> None:
        self._state = self._state.insert_credit_card()  # 委譲

    def _take_ticket(self) -> None:
        self._state = self._state.take_ticket()
```

**Python固有のポイント**:
- `match` 文（Python 3.10+）を使うと `if-elif` より可読性は上がるが、Stateパターンではそもそも不要（状態ごとにクラスを分離するため）
- `StatesBlock` への集約により、State同士の直接依存を排除し疎結合を実現する

---

## 使い分け判断テーブル: State vs Strategy

| 観点 | State | Strategy |
|------|-------|---------|
| 目的 | 状態に応じた振る舞いの変化 | 交換可能なアルゴリズムの選択 |
| 状態の自己管理 | Stateが次の状態に遷移する | クライアントが明示的に切り替える |
| 状態間の関係 | 状態遷移図に基づく関係がある | 各Strategyは独立 |
| 適した場面 | 有限状態機械（FSM）の実装 | プラグイン的にアルゴリズムを切り替えたい場合 |
