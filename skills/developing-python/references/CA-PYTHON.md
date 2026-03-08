# Python × Clean Architecture

PythonでClean Architectureを実践するための実装ガイド。依存性ルール、4レイヤー構造、テスト戦略、オブザーバビリティ、レガシー移行の全領域を網羅。

---

## 概要

Clean Architectureは「依存性ルール」を核とする同心円状のレイヤーモデルで、ビジネスロジックをフレームワーク・DB・UIから分離する。Pythonはこのアーキテクチャと自然に親和する言語だ。

**Clean Architectureが解決する問題:**

| 問題 | CAによる解決 |
|------|------------|
| フレームワーク変更コストが高い | フレームワーク層を外側に封じ込める |
| テストが難しい | 内側の層がDBや外部サービスに依存しない |
| ビジネスロジックの散在 | ユースケース層に集約 |
| 変更時の影響範囲が広い | 依存性ルールで影響を一方向に制限 |

**4レイヤーの概要:**

```
[エンティティ層]        ← ビジネスルール（最内層）
[ユースケース層]        ← アプリケーションロジック
[インターフェースアダプター層] ← 変換・整形
[フレームワーク・ドライバー層] ← FastAPI/DB/CLI（最外層）
```

**依存性ルール:** 外側の層が内側の層を知ってよい。逆は禁止。

---

## Python固有のCA基盤

### ABC と Protocol による抽象化

依存性逆転原則をPythonで実現する主な手段は2つ。

**ABC（明示的な継承を使う場合）:**

```python
from abc import ABC, abstractmethod

class NotificationPort(ABC):
    @abstractmethod
    def send(self, message: str, recipient: str) -> None:
        ...

class EmailNotification(NotificationPort):
    def send(self, message: str, recipient: str) -> None:
        print(f"Email to {recipient}: {message}")
```

**Protocol（構造的サブタイピング — Duck Typing × 型ヒント）:**

```python
from typing import Protocol

class NotificationPort(Protocol):
    def send(self, message: str, recipient: str) -> None:
        ...

class SMSNotification:  # 明示的継承不要
    def send(self, message: str, recipient: str) -> None:
        print(f"SMS to {recipient}: {message}")
```

**ABC vs Protocol の選択基準:**

| 観点 | ABC | Protocol |
|------|-----|----------|
| 継承の強制 | ✅ 必須 | ❌ 不要 |
| サードパーティクラスとの互換性 | ❌ 難しい | ✅ 容易 |
| ランタイム型チェック | ✅ `isinstance()` | ❌ 不可（`runtime_checkable`で部分的に対応） |
| 推奨用途 | 内部実装での明示的契約 | 外部システムとのインターフェース |

実践的には **内側のレイヤー境界にはABC**、**外部システム連携にはProtocol** が多用される。

---

### 型ヒントによるCA強化

型ヒントはCA境界を明示的に文書化し、mypyによる静的検証を可能にする。

```python
from typing import Optional
from uuid import UUID

# インターフェース境界の明示
class RoomRepository(ABC):
    @abstractmethod
    def list(self, filters: Optional[dict] = None) -> list["Room"]:
        ...

    @abstractmethod
    def get(self, room_id: UUID) -> Optional["Room"]:
        ...
```

**CA強化における型ヒントの役割:**

- **インターフェース契約の明示化:** ABCのメソッドシグネチャが仕様書になる
- **レイヤー越境の検出:** mypy が誤った依存方向を静的に検出
- **リファクタリングの安全網:** 型不整合を変更時に即座に発見

---

### dataclasses × Entity パターン

エンティティはビジネスの概念を表すオブジェクト。`@dataclass` がその実装に適している。

```python
import dataclasses
import uuid
from datetime import datetime
from enum import Enum

class TaskStatus(Enum):
    TODO = "todo"
    IN_PROGRESS = "in_progress"
    DONE = "done"

class Priority(Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"

@dataclasses.dataclass
class Task:
    title: str
    description: str
    code: uuid.UUID = dataclasses.field(default_factory=uuid.uuid4)
    status: TaskStatus = TaskStatus.TODO
    priority: Priority = Priority.MEDIUM
    created_at: datetime = dataclasses.field(default_factory=datetime.now)

    # ビジネスルールをメソッドとして持つ
    def complete(self) -> None:
        if self.status == TaskStatus.DONE:
            raise ValueError("Task is already completed")
        self.status = TaskStatus.DONE

    def is_high_priority(self) -> bool:
        return self.priority == Priority.HIGH

    @classmethod
    def from_dict(cls, d: dict) -> "Task":
        return cls(**d)

    def to_dict(self) -> dict:
        return dataclasses.asdict(self)
```

**dataclass の利点:**
- `__eq__` が自動実装される（同値比較が自然に動く）
- `__repr__` が自動実装される（デバッグが容易）
- `asdict()` でシリアライズが簡単
- ミュータブルなドメインオブジェクトにも対応

---

## 4レイヤー実装

### エンティティ層 — ドメインモデル・ビジネスルール

エンティティ層はフレームワーク・DBへの依存ゼロで設計する。

**ディレクトリ構成例:**

```
src/
└── domain/
    ├── entities/
    │   ├── task.py      # Taskエンティティ
    │   └── project.py   # Projectエンティティ
    ├── value_objects/
    │   ├── task_status.py
    │   └── priority.py
    └── repositories/
        └── task_repository.py  # ABCインターフェース定義
```

**Pydantic vs dataclasses の選択:**

| 用途 | 推奨 |
|------|------|
| フレームワーク非依存のドメインモデル | `@dataclass` |
| 外部入力（APIリクエスト）のバリデーション | `pydantic.BaseModel` |
| 厳密な不変性が必要なValue Object | `@dataclass(frozen=True)` |

**Pydanticの注意点:** Pydanticはサードパーティライブラリのため、エンティティ層での直接使用は依存性ルール違反になりやすい。Pydanticはフレームワーク・ドライバー層（入力バリデーション）で使用し、変換後に内側のドメインオブジェクトに渡すパターンが推奨される。

---

### ユースケース層 — アプリケーションサービス

ユースケースはビジネスプロセスを表す。外部システム（Repository）をインターフェース経由で受け取る。

**シンプルなユースケース関数:**

```python
# use_cases/room_list.py
from typing import Optional
from domain.repositories.room_repository import RoomRepository
from domain.entities.room import Room

def room_list_use_case(
    repo: RoomRepository,
    filters: Optional[dict] = None
) -> list[Room]:
    return repo.list(filters)
```

**クラスを使う場合（複数の依存がある場合）:**

```python
# use_cases/create_task.py
from dataclasses import dataclass
from domain.repositories.task_repository import TaskRepository
from domain.repositories.project_repository import ProjectRepository
from domain.entities.task import Task

@dataclass
class CreateTaskInput:
    title: str
    description: str
    project_id: str

@dataclass
class CreateTaskOutput:
    task_id: str
    title: str

class CreateTaskUseCase:
    def __init__(
        self,
        task_repo: TaskRepository,
        project_repo: ProjectRepository
    ) -> None:
        self._task_repo = task_repo
        self._project_repo = project_repo

    def execute(self, input_dto: CreateTaskInput) -> CreateTaskOutput:
        project = self._project_repo.get(input_dto.project_id)
        if project is None:
            raise ValueError(f"Project {input_dto.project_id} not found")

        task = Task(
            title=input_dto.title,
            description=input_dto.description,
        )
        self._task_repo.save(task)
        return CreateTaskOutput(task_id=str(task.code), title=task.title)
```

**関数 vs クラスの選択基準:**

| 状況 | 推奨 |
|------|------|
| 依存するコンポーネントが1-2個 | 関数 |
| 依存が3個以上 / 内部状態が必要 | クラス |
| テストでDIが必要 | どちらでも（クラスが明確） |

---

### インターフェースアダプター層 — 変換・整形

**シリアライザ:**

```python
# serializers/room.py
import json

class RoomJsonEncoder(json.JSONEncoder):
    def default(self, obj):
        try:
            return {
                "code": str(obj.code),
                "size": obj.size,
                "price": obj.price,
                "latitude": obj.latitude,
                "longitude": obj.longitude,
            }
        except AttributeError:
            return super().default(obj)
```

**リクエストDTO（バリデーション付き）:**

```python
# adapters/requests.py
from dataclasses import dataclass, field
from typing import Optional

@dataclass
class RoomListRequest:
    filters: Optional[dict] = field(default_factory=dict)

    @classmethod
    def build(cls, filters: Optional[dict] = None) -> "RoomListRequest":
        invalid_args = {}
        if filters:
            # バリデーション
            valid_keys = {"price__lt", "price__gt", "size__lt", "size__gt"}
            invalid_keys = set(filters.keys()) - valid_keys
            if invalid_keys:
                for key in invalid_keys:
                    invalid_args[key] = f"Key {key} cannot be used"
        if invalid_args:
            return InvalidRoomListRequest(invalid_args)
        return cls(filters=filters or {})
```

**プレゼンター（ViewModel変換）:**

```python
# adapters/presenters.py
from dataclasses import dataclass

@dataclass
class TaskViewModel:
    title: str
    status_display: str
    priority_display: str

class TaskPresenter:
    def present(self, task_response) -> TaskViewModel:
        status_map = {
            "todo": "[ ]",
            "in_progress": "[~]",
            "done": "[✓]",
        }
        return TaskViewModel(
            title=task_response.title,
            status_display=status_map.get(task_response.status, "?"),
            priority_display=f"{task_response.priority.upper()} PRIORITY",
        )
```

---

### フレームワーク・ドライバー層 — FastAPI / SQLAlchemy

**FastAPI統合:**

Pydanticモデルはフレームワーク層（=最外層）で使用し、内側のドメインオブジェクトに変換する。

```python
# frameworks/web/app.py
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from use_cases.create_task import CreateTaskUseCase, CreateTaskInput

app = FastAPI()

class CreateTaskRequest(BaseModel):  # PydanticはFW層のみ
    title: str
    description: str
    project_id: str

@app.post("/tasks")
def create_task(request: CreateTaskRequest):
    # FW層→ユースケース層への変換（Pydanticを内側に浸透させない）
    input_dto = CreateTaskInput(
        title=request.title,
        description=request.description,
        project_id=request.project_id,
    )
    use_case = CreateTaskUseCase(
        task_repo=get_task_repository(),
        project_repo=get_project_repository(),
    )
    output = use_case.execute(input_dto)
    return {"task_id": output.task_id, "title": output.title}
```

**SQLAlchemyを使ったRepositoryの実装:**

```python
# frameworks/database/room_repository.py
from sqlalchemy.orm import Session
from domain.entities.room import Room
from domain.repositories.room_repository import RoomRepository

class SqlAlchemyRoomRepository(RoomRepository):
    def __init__(self, session: Session) -> None:
        self._session = session

    def list(self, filters=None) -> list[Room]:
        query = self._session.query(RoomModel)
        if filters:
            if "price__lt" in filters:
                query = query.filter(RoomModel.price < filters["price__lt"])
        return [
            Room(code=r.code, size=r.size, price=r.price,
                 latitude=r.latitude, longitude=r.longitude)
            for r in query.all()
        ]

    def save(self, room: Room) -> None:
        room_model = RoomModel(
            code=str(room.code), size=room.size, price=room.price,
            latitude=room.latitude, longitude=room.longitude,
        )
        self._session.merge(room_model)
        self._session.commit()
```

**設計ポイント:** Repositoryは内側のドメインオブジェクトを返す。SQLAlchemyのモデルオブジェクトを呼び出し元（ユースケース層）には見せない。

---

## テストパターン

### ユニットテスト — モックによる境界テスト

```python
# tests/use_cases/test_room_list.py
import pytest
from unittest import mock
from domain.entities.room import Room
from use_cases.room_list import room_list_use_case

@pytest.fixture
def domain_rooms():
    return [
        Room(code=uuid.uuid4(), size=200, price=39,
             longitude=-0.09998975, latitude=51.75436293),
        Room(code=uuid.uuid4(), size=405, price=66,
             longitude=0.18228006, latitude=51.74640997),
    ]

def test_room_list_returns_all_rooms(domain_rooms):
    # Arrange
    repo = mock.Mock()
    repo.list.return_value = domain_rooms

    # Act
    result = room_list_use_case(repo)

    # Assert
    repo.list.assert_called_with()
    assert result == domain_rooms
```

**ユニットテストのルール:**
- ユースケースには実際のRepositoryを渡さない（モック必須）
- エンティティのテストはフレームワーク依存なしで書く
- 「アウトゴーイングクエリ」はどのパラメータで呼ばれたかを検証

### 統合テスト — レイヤー境界の検証

```python
# tests/integration/test_file_repository.py
import pytest
from frameworks.database.file_task_repository import FileTaskRepository
from domain.entities.task import Task

@pytest.fixture
def repository(tmp_path):
    return FileTaskRepository(data_dir=tmp_path)

def test_repository_persists_and_retrieves_task(repository):
    # Arrange
    task = Task(title="Integration Test", description="Testing persistence")

    # Act
    repository.save(task)
    loaded = repository.get(task.code)

    # Assert
    assert loaded is not None
    assert loaded.title == "Integration Test"
    assert loaded.code == task.code
```

**統合テストの対象:**

| テスト対象 | 目的 |
|----------|------|
| Repository実装 | 実際のDB/ファイルシステムとの連携 |
| シリアライゼーション | データ往復（保存→取得）の整合性 |
| トランザクション境界 | コミット・ロールバックの動作 |

### テスト戦略のサマリー

```
エンティティ層        → ユニットテスト（フレームワーク不要）
ユースケース層        → ユニットテスト（Repositoryはモック）
アダプター層         → ユニットテスト（外部依存はモック）
インフラ層           → 統合テスト（実DB/tmpdir使用）
E2Eテスト           → API経由でフロー全体を検証
```

---

## オブザーバビリティ

### CAの自然な観測ポイント

Clean Architectureのレイヤー境界は観測の自然なポイントを提供する。

| レイヤー | 観測内容 |
|---------|---------|
| フレームワーク層 | HTTPリクエスト/レスポンス、レイテンシ、エラーレート |
| アダプター層 | 変換処理、バリデーションエラー |
| ユースケース層 | ビジネス操作の成功/失敗、処理時間 |
| エンティティ層 | ドメインイベント、状態遷移 |
| インフラ層 | DB接続数、クエリ時間、外部API応答 |

### フレームワーク結合を避けたロギング

```python
# ❌ フレームワーク固有のロギング（CAに違反）
from flask import current_app

class TaskUseCase:
    def execute(self, input_dto):
        current_app.logger.info("Creating task")  # Flaskに依存

# ✅ 標準ライブラリのロギングを使用
import logging

logger = logging.getLogger(__name__)

class TaskUseCase:
    def execute(self, input_dto):
        logger.info("Creating task", extra={"title": input_dto.title})
```

### 構造化ロギングのパターン

```python
import logging
import structlog  # または標準ライブラリのJSONFormatterでも可

# インフラ層でのDB操作ロギング
class SqlAlchemyTaskRepository:
    _logger = logging.getLogger("infrastructure.task_repository")

    def save(self, task):
        self._logger.info(
            "Saving task",
            extra={"task_id": str(task.code), "title": task.title}
        )
        # ... 実際の保存処理

# ユースケース層でのビジネス操作ロギング
class CreateTaskUseCase:
    _logger = logging.getLogger("use_cases.create_task")

    def execute(self, input_dto):
        self._logger.info("Task creation started",
                          extra={"title": input_dto.title})
        # ... ユースケース処理
        self._logger.info("Task creation completed",
                          extra={"task_id": created_task.code})
```

**原則:** 各レイヤーは自分が責任を持つ関心事だけをログに記録する。ビジネスイベントはユースケース層、技術的メトリクスはインフラ層。

---

## レガシーリファクタリング

### Strangler Fig パターン

既存コードを一度に書き直さず、新しい機能をCA構造で追加しながら段階的に移行するパターン。

```
フェーズ1: 既存コード（スパゲッティ）がそのまま動く
フェーズ2: 新機能を Clean Architecture で実装
フェーズ3: 既存機能を段階的にCA構造に移行
フェーズ4: 旧コードが完全に置き換えられる
```

### 段階的移行戦略

**Step 1: ドメインモデルの抽出**

```python
# 既存: ビジネスロジックがViewに混在
class TaskView:
    def complete_task(self, task_id):
        task = db.query(f"SELECT * FROM tasks WHERE id={task_id}")
        if task['status'] != 'done':
            db.execute(f"UPDATE tasks SET status='done' WHERE id={task_id}")

# 新: ドメインモデルを先に定義
@dataclasses.dataclass
class Task:
    code: uuid.UUID
    status: TaskStatus

    def complete(self) -> None:
        if self.status == TaskStatus.DONE:
            raise ValueError("Already completed")
        self.status = TaskStatus.DONE
```

**Step 2: Repositoryインターフェースの導入**

```python
# レガシーコードをRepositoryでラップ（Anti-Corruption Layer）
class LegacyTaskRepository(TaskRepository):
    def __init__(self, legacy_db):
        self._db = legacy_db

    def get(self, task_id: uuid.UUID) -> Optional[Task]:
        row = self._db.query(f"SELECT * FROM tasks WHERE id='{task_id}'")
        if row is None:
            return None
        return Task(
            code=uuid.UUID(row['id']),
            status=TaskStatus(row['status']),
        )
```

**Step 3: ユースケースの実装 → 既存コードからの呼び出し**

段階的に既存のViewやControllerからユースケースを呼び出すように変更する。完全移行までレガシーコードとCAコードが共存する期間を許容する。

### 移行時の注意事項

- **一度に全部やらない:** 最も変化の激しい部分・最も価値が高い部分から始める
- **テストを先に書く:** レガシーコードの現在の動作をテストで固定してから変更
- **Anti-Corruption Layer:** レガシーシステムのデータモデルをドメインモデルに変換するレイヤーを用意し、レガシーの概念が内側に浸透しないようにする

---

## 実践チュートリアル — ステップバイステップ構築

### プロジェクト構成

```
src/
├── domain/
│   ├── entities/
│   │   └── room.py
│   └── repositories/
│       └── room_repository.py   # ABCインターフェース
├── use_cases/
│   └── room_list.py
├── adapters/
│   ├── serializers/
│   │   └── room.py
│   └── requests/
│       └── room_list_request.py
└── frameworks/
    ├── web/
    │   └── app.py               # FastAPI/Flask
    └── database/
        └── memory_room_repo.py  # インメモリ実装（開発用）
tests/
├── domain/
│   └── test_room.py
├── use_cases/
│   └── test_room_list.py
├── adapters/
│   └── test_serializers.py
└── integration/
    └── test_room_repository.py
```

### 実装順序

1. **エンティティ定義** — `domain/entities/room.py`（テスト先行）
2. **Repositoryインターフェース** — `domain/repositories/room_repository.py`（ABCで）
3. **ユースケース** — `use_cases/room_list.py`（モックRepoでテスト）
4. **インメモリRepository** — `frameworks/database/memory_room_repo.py`
5. **シリアライザ** — `adapters/serializers/room.py`
6. **Webフレームワーク統合** — `frameworks/web/app.py`
7. **DB Repository** — `frameworks/database/sqlalchemy_room_repo.py`

この順序はCAの「外側から内側に依存が向く」方向と逆（内側から外側に向けて実装）であり、各ステップでテストが書けることを確認しながら進む。

---

## ユーザー確認の原則（AskUserQuestion）

**判断分岐がある場合、必ずAskUserQuestionツールでユーザーに確認する。**

### 確認すべき場面

| 確認項目 | 選択肢例 |
|---------|---------|
| エンティティの実装方式 | dataclasses / Pydantic / 通常クラス |
| Webフレームワーク | FastAPI / Flask / Django |
| データストア | PostgreSQL / SQLite / MongoDB / インメモリ |
| テスト戦略 | TDDで先行 / 実装後にテスト |
| 移行フェーズ | 新規CA構造 / レガシー移行 |

### 確認不要な場面

- 既存プロジェクトにWebフレームワークが指定済みの場合
- `pyproject.toml` にDBライブラリが既に明記されている場合
- 明確にCAの全レイヤーを新規実装するよう指示された場合

---

## 相互参照

- **[applying-clean-architecture](../../applying-clean-architecture/SKILL.md)**: Clean Architecture一般原則（依存性ルール・同心円モデル・コンポーネント原則）
- **[writing-clean-code](../../writing-clean-code/SKILL.md)**: コードレベルSOLID原則・コードスメル・リファクタリング手法
- **[applying-domain-driven-design](../../applying-domain-driven-design/SKILL.md)**: DDD戦術パターン（Entity/Value Object/Aggregate/Repositoryの詳細設計）
