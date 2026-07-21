# データ永続化（SQLAlchemy・SQLModel・MongoDB）

> リレーショナルDB（SQLAlchemy 2.0 / SQLModel）と NoSQL（MongoDB）の双方で、CRUD・リレーション・マイグレーション・非同期永続化を実装するための実践ガイド。

---

## ユーザー確認事項（推測で進めない）

**判断分岐がある場合、推測で進めず必ず AskUserQuestion ツールでユーザーに確認する。**

| # | 分岐 | 選択肢 |
|---|------|--------|
| Q1 | DB 種別 | RDB（SQL） / NoSQL（MongoDB） |
| Q2 | ORM/レイヤ | SQLAlchemy ORM / SQLModel / SQLAlchemy Core |
| Q3 | DB ドライバ | 同期 / 非同期（asyncpg・aiosqlite・motor） |

```python
AskUserQuestion(
    questions=[
        {
            "question": "永続化するデータベースの種別を確認させてください。",
            "header": "DB種別",
            "options": [
                {"label": "RDB（PostgreSQL/MySQL/SQLite）", "description": "スキーマ・リレーション・トランザクションを重視する場合"},
                {"label": "NoSQL（MongoDB）", "description": "スキーマレス・柔軟なドキュメント構造が必要な場合"},
            ],
            "multiSelect": False,
        },
        {
            "question": "RDBの場合、どのORM/レイヤを使いますか？",
            "header": "ORM選択",
            "options": [
                {"label": "SQLAlchemy ORM（推奨）", "description": "Mapped/mapped_columnによる型安全なORM。柔軟なリレーション定義"},
                {"label": "SQLModel", "description": "PydanticモデルとSQLAlchemyテーブルを1クラスで統合したい場合"},
                {"label": "SQLAlchemy Core", "description": "ORMの抽象を避け、SQL式を直接組み立てたい場合"},
            ],
            "multiSelect": False,
        },
        {
            "question": "DBドライバは同期/非同期どちらを使いますか？",
            "header": "ドライバ",
            "options": [
                {"label": "非同期（推奨）", "description": "asyncpg/aiosqlite/motor。FastAPIのasync def routeと自然に統合"},
                {"label": "同期", "description": "psycopg2等。小規模・既存コードとの統合を優先する場合"},
            ],
            "multiSelect": False,
        },
    ]
)
```

確認**不要**（ベストプラクティスが明確）な場面: `Annotated[T, Depends(...)]` によるセッション注入、`response_model` の指定、全パラメータへの型注釈。これらは確認せず適用する。

---

## SQLAlchemy 2.0 の基礎: モデル定義

SQLAlchemy 2.0 系では、`DeclarativeBase` を継承した基底クラスと `Mapped[T]` / `mapped_column()` によるカラム定義がモダンな標準スタイル。旧来の `declarative_base()` + `Column(Integer, ...)` という書き方は互換性のために残っているが、型チェッカーとの相性が悪いため新規実装では避ける。

```python
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    """すべてのORMモデルの基底クラス"""


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str]
    email: Mapped[str] = mapped_column(unique=True, index=True)
    # Optional[T] は Mapped[T | None] で表現する
    bio: Mapped[str | None] = mapped_column(default=None)
```

**設計原則:** `Mapped[str]` はカラムを `NOT NULL` として推論する（null許容は `Mapped[str | None]` で明示）。一意制約・インデックスは `mapped_column(unique=True, index=True)` で宣言する。`Base.metadata` がテーブルカタログとして機能し、`Base.metadata.create_all(engine)` で全テーブルを作成できる（本番運用では後述の Alembic マイグレーションに置き換える）。

---

## エンジンとセッション: 同期/非同期

**エンジン**が接続プールを管理し、**セッション**がトランザクション単位の作業領域を提供する。FastAPI の非同期エンドポイントと組み合わせる場合は、非同期ドライバ + `AsyncSession` を使うのが基本。

```python
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

DATABASE_URL = "postgresql+asyncpg://user:password@localhost/mydb"

engine = create_async_engine(DATABASE_URL, echo=False, pool_size=10, max_overflow=20)

AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
)
```

**DB 種別ごとの接続 URL とドライバ対応表:**

| DB | 同期ドライバ | 非同期ドライバ | 接続URL例（非同期） |
|----|------------|---------------|---------------------|
| SQLite | 標準（sqlite3） | `aiosqlite` | `sqlite+aiosqlite:///./app.db` |
| PostgreSQL | `psycopg2` | `asyncpg` | `postgresql+asyncpg://user:pass@host/db` |
| MySQL | `mysql-connector-python` | `aiomysql` | `mysql+aiomysql://user:pass@host/db` |

🔴 **落とし穴: 同期/非同期ドライバの混在**。非同期の `async def` エンドポイント内で同期ドライバのブロッキング呼び出し（`requests` や同期版 SQLAlchemy セッション）を行うと、イベントループ全体が停止し他リクエストの処理が止まる。**同期処理が避けられない場合は `run_in_executor` で別スレッドに退避する**か、そのエンドポイントだけ `def`（同期）で定義し FastAPI のスレッドプールに任せる。

---

## FastAPI 依存性としての DB セッション

セッションのライフサイクル（生成・yield・確実なクローズ）は FastAPI の依存性に閉じ込める。`Annotated` で型エイリアス化するのが規約。

```python
from typing import Annotated
from collections.abc import AsyncGenerator
from fastapi import Depends


async def get_db_session() -> AsyncGenerator[AsyncSession, None]:
    async with AsyncSessionLocal() as session:
        yield session


SessionDep = Annotated[AsyncSession, Depends(get_db_session)]
```

以降、エンドポイントは `db: SessionDep` を引数に加えるだけでセッションを受け取れる（実例は「CRUD リポジトリパターン」の節を参照）。

**起動時のテーブル作成/接続確認は `lifespan` に集約する**（`@app.on_event("startup")` は非推奨。`lifespan` コンテキストマネージャを使う）。

```python
from contextlib import asynccontextmanager
from fastapi import FastAPI


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)  # 開発用。本番は Alembic に委譲
    yield
    await engine.dispose()


app = FastAPI(lifespan=lifespan)
```

`Base.metadata.create_all` は開発時の簡易セットアップに限定し、本番運用のスキーマ変更は「Alembic によるマイグレーション」の節で管理する。

---

## CRUD リポジトリパターン

エンドポイント関数に直接クエリを書くと、テストが難しくビジネスロジックとデータアクセスが混在する。**リポジトリ層**に永続化操作を分離し、エンドポイントはリポジトリを呼び出すだけにする。

```python
from sqlalchemy import delete, select, update


class UserRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def create(self, name: str, email: str) -> User:
        user = User(name=name, email=email)
        self._session.add(user)
        await self._session.flush()
        await self._session.refresh(user)
        return user

    async def get(self, user_id: int) -> User | None:
        result = await self._session.execute(select(User).where(User.id == user_id))
        return result.scalar_one_or_none()

    async def update_email(self, user_id: int, new_email: str) -> bool:
        stmt = update(User).where(User.id == user_id).values(email=new_email)
        result = await self._session.execute(stmt)
        await self._session.commit()
        return result.rowcount > 0

    async def delete(self, user_id: int) -> bool:
        result = await self._session.execute(delete(User).where(User.id == user_id))
        await self._session.commit()
        return result.rowcount > 0
```

リポジトリ自体も `Annotated[UserRepository, Depends(get_user_repository)]` で依存性化し、エンドポイントは `repo.create(...)` / `repo.get(...)` を呼ぶだけの薄いレイヤーに保つ。`get()` の読み取りには `.scalar_one_or_none()`（0件は`None`、1件は値、2件以上は例外）を、更新/削除には `result.rowcount` で「対象が存在したか」を判定するパターンが再利用しやすい。

---

## リレーションシップ

`relationship()` でテーブル間の関連を Python オブジェクトとして扱える。

```python
from sqlalchemy import ForeignKey, Table, Column
from sqlalchemy.orm import relationship


# 1対1: Ticket - TicketDetails
class Ticket(Base):
    __tablename__ = "tickets"
    id: Mapped[int] = mapped_column(primary_key=True)
    details: Mapped["TicketDetails"] = relationship(back_populates="ticket")


class TicketDetails(Base):
    __tablename__ = "ticket_details"
    id: Mapped[int] = mapped_column(primary_key=True)
    ticket_id: Mapped[int] = mapped_column(ForeignKey("tickets.id"))
    ticket: Mapped["Ticket"] = relationship(back_populates="details")
    seat: Mapped[str | None]


# 多対1: Ticket -> Event（1つのEventに複数のTicket）
class Event(Base):
    __tablename__ = "events"
    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str]
    tickets: Mapped[list["Ticket"]] = relationship(back_populates="event")
```

```python
# 多対多: Event <-> Sponsor（中間テーブル経由）
sponsorships = Table(
    "sponsorships",
    Base.metadata,
    Column("event_id", ForeignKey("events.id"), primary_key=True),
    Column("sponsor_id", ForeignKey("sponsors.id"), primary_key=True),
)


class Sponsor(Base):
    __tablename__ = "sponsors"
    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(unique=True)
    events: Mapped[list["Event"]] = relationship(secondary=sponsorships, back_populates="sponsors")
```

多対多の中間テーブルに関連自体の属性（例: 協賛金額）を持たせたい場合は、`Table` の代わりに中間テーブルを独立したモデルクラス（`ForeignKey` を複合主キーに持つ）として定義し、`relationship(secondary=...)` の代わりに直接そのモデルを介して読み書きする。

---

## クエリ最適化

### N+1 問題の回避

一覧取得後にループで関連レコードを1件ずつ取得すると、N+1回のクエリが発行される。`selectinload`（別クエリでまとめて取得・多くのケースで推奨）または `joinedload`（JOINで一度に取得）で**eager loading** する。

```python
from sqlalchemy.orm import selectinload


async def list_events_with_sponsors(db: AsyncSession) -> list[Event]:
    stmt = select(Event).options(selectinload(Event.sponsors))
    result = await db.execute(stmt)
    return list(result.scalars().all())
```

JOIN も同様に、最終的に使わないテーブルまで含めると無駄な走査が発生するため、必要なテーブルのみを JOIN する。

### 必要なカラムだけ取得する

`load_only()` で選択カラムを絞ることで、転送量とメモリ使用量を削減できる。

```python
from sqlalchemy.orm import load_only


async def list_ticket_summaries(db: AsyncSession, event_id: int) -> list[Ticket]:
    stmt = (
        select(Ticket)
        .where(Ticket.event_id == event_id)
        .options(load_only(Ticket.id, Ticket.price))
    )
    result = await db.execute(stmt)
    return list(result.scalars().all())
```

`load_only` で除外したカラムに後からアクセスすると `InvalidRequestError` が発生する（未取得を検出する安全機構であり、バグではない）。

---

## Alembic によるマイグレーション

Alembic は SQLAlchemy モデルの変更をスキーママイグレーションとして管理するツール。

```console
$ pip install alembic && alembic init alembic
```

```python
# alembic/env.py: モデルのメタデータを紐付ける
from app.database import Base

target_metadata = Base.metadata
```

```console
$ alembic revision --autogenerate -m "add sold field to tickets"  # 差分検出→スクリプト生成
$ alembic upgrade head      # 生成済みスクリプトを適用（既存データは保持される）
$ alembic downgrade -1      # 直前のマイグレーションを取り消す
```

🔴 **非同期エンジンを使う場合の注意**: Alembic 自体は同期的に動作するため、`env.py` 内で非同期エンジンのメタデータ検出を行うには `asyncio.run()` でラップしたヘルパー、または同期用の接続URL（`postgresql+psycopg2://...`）をマイグレーション専用に別途用意する。アプリ本体の非同期エンジンとマイグレーション実行時のエンジンを混同しない。

`--autogenerate` は既存スキーマとモデル定義の差分を検出するが、カラムのリネームやデータ移行を伴う変更は自動検出できないため、生成されたスクリプトは必ず目視レビューする。

---

## SQLModel: Pydantic と SQLAlchemy の統合

SQLModel は Pydantic のデータ検証と SQLAlchemy の ORM を1つのクラス定義に統合するライブラリ。リクエスト/レスポンスモデルと DB テーブルモデルを別々に書く手間を減らせる一方、責務が1クラスに集中するため、大規模なドメインモデルでは SQLAlchemy ORM + 個別 Pydantic モデルの構成の方が見通しが良いこともある（判断が難しい場合は「ユーザー確認事項」の節の Q2〈ORM/レイヤ〉で確認する）。

```python
from sqlmodel import Field, SQLModel, create_engine, Session, select


class Hero(SQLModel, table=True):  # table=True: SQLAlchemyのテーブルモデルとして振る舞う
    id: int | None = Field(default=None, primary_key=True)
    name: str
    secret_name: str
    age: int | None = None


# API入出力用は table=True を付けない継承クラスで、テーブルモデルと分離する
class HeroCreate(SQLModel):  # リクエストボディ用（table=Falseの通常Pydanticモデル）
    name: str
    secret_name: str
    age: int | None = None


class HeroRead(SQLModel):  # レスポンス用（idを含む）
    id: int
    name: str
    age: int | None = None
```

```python
from collections.abc import Generator


def get_session() -> Generator[Session, None, None]:
    with Session(engine) as session:
        yield session


SessionDep = Annotated[Session, Depends(get_session)]


@app.post("/heroes/", response_model=HeroRead)
def create_hero(hero: HeroCreate, session: SessionDep) -> Hero:
    db_hero = Hero.model_validate(hero)  # HeroCreate(Pydantic) -> Hero(テーブル行) へ変換
    session.add(db_hero)
    session.commit()
    session.refresh(db_hero)
    return db_hero
```

非同期で使う場合は `sqlmodel` の `Session`/`create_engine` を SQLAlchemy の `AsyncSession`/`create_async_engine` に置き換え、`session.exec(select(...))` を `await session.execute(select(...))` に読み替える（「エンジンとセッション: 同期/非同期」から「CRUD リポジトリパターン」までの非同期パターンがそのまま適用できる）。

---

## MongoDB（motor）による NoSQL 永続化

MongoDB は非同期ドライバ **motor**（`pymongo` ベース）を使うのが FastAPI との組み合わせでは標準的。

```python
from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorDatabase

mongo_client = AsyncIOMotorClient("mongodb://localhost:27017")


def get_mongo_db() -> AsyncIOMotorDatabase:
    return mongo_client.get_database("app_db")


MongoDep = Annotated[AsyncIOMotorDatabase, Depends(get_mongo_db)]
```

```python
@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    await mongo_client.admin.command("ping")  # 起動時に接続確認
    yield
    mongo_client.close()
```

### CRUD 操作

MongoDB のドキュメント ID（`ObjectId`）は文字列と直接比較できないため、変換が必要。

```python
from typing import Any
from bson import ObjectId
from fastapi import HTTPException
from fastapi.encoders import ENCODERS_BY_TYPE

ENCODERS_BY_TYPE[ObjectId] = str  # レスポンスシリアライズ時に str へ変換


async def create_song(db: AsyncIOMotorDatabase, song: dict[str, Any]) -> str:
    result = await db.songs.insert_one(song)
    return str(result.inserted_id)


async def get_song(db: AsyncIOMotorDatabase, song_id: str) -> dict[str, Any]:
    if not ObjectId.is_valid(song_id):
        raise HTTPException(status_code=404, detail="Song not found")
    song = await db.songs.find_one({"_id": ObjectId(song_id)})
    if song is None:
        raise HTTPException(status_code=404, detail="Song not found")
    return song


async def update_song(db: AsyncIOMotorDatabase, song_id: str, patch: dict[str, Any]) -> bool:
    result = await db.songs.update_one({"_id": ObjectId(song_id)}, {"$set": patch})
    return result.modified_count == 1


async def delete_song(db: AsyncIOMotorDatabase, song_id: str) -> bool:
    result = await db.songs.delete_one({"_id": ObjectId(song_id)})
    return result.deleted_count == 1
```

### リレーション: embedding vs referencing

| 戦略 | 適する場面 | トレードオフ |
|------|----------|--------------|
| **embedding**（ドキュメント内に埋め込む） | 変更頻度が低く親ドキュメントと強く紐づくデータ（例: 楽曲に紐づくアルバム情報） | 読み取りは高速（1クエリ）。重複が生じやすく、埋め込みデータの更新は追跡しづらい |
| **referencing**（IDで参照する） | 多対多・共有される・頻繁に更新されるデータ（例: プレイリストと楽曲） | 更新は独立して行える。読み取りは複数クエリになりやすい（`$in` でまとめて取得） |

```python
# referencing: プレイリストが保持する楽曲IDから、実データをまとめて取得
async def get_playlist_songs(db: AsyncIOMotorDatabase, song_ids: list[str]) -> list[dict[str, Any]]:
    cursor = db.songs.find({"_id": {"$in": [ObjectId(sid) for sid in song_ids]}})
    return await cursor.to_list(length=None)
```

### インデックス

頻繁に検索するフィールドにはインデックスを張る。テキスト検索には専用のテキストインデックスが必要。

```python
async def create_indexes(db: AsyncIOMotorDatabase) -> None:
    await db.songs.create_index("album.release_year")
    await db.songs.create_index([("artist", "text")])
```

インデックスの利用確認は `cursor.explain()` の `winningPlan.inputStage.indexName` で行える。開発中に意図したインデックスが使われているかを検証する習慣をつける。

---

## トランザクションと並行性制御

複数ユーザーが同一レコードを同時に更新する場合、**分離レベル（isolation level）**の理解が必須。SQL標準は4段階を定義する。

| 分離レベル | ダーティリード | 非再現リード | ファントムリード | 特徴 |
|-----------|:---:|:---:|:---:|------|
| READ UNCOMMITTED | 許容 | 許容 | 許容 | 最高の並行性・最低の一貫性 |
| READ COMMITTED | 防止 | 許容 | 許容 | 多くのDBのデフォルト |
| REPEATABLE READ | 防止 | 防止 | 許容 | トランザクション中は一貫したスナップショット |
| SERIALIZABLE | 防止 | 防止 | 防止 | 直列実行と等価。最も安全だがロック競合が増える |

分離レベルは `create_async_engine(DATABASE_URL, isolation_level="REPEATABLE READ")` のようにエンジン単位で指定できる。**条件付き UPDATE による競合制御の実例**（チケットの二重販売防止）:

```python
from sqlalchemy import and_


async def sell_ticket_to_user(db: AsyncSession, ticket_id: int, user: str) -> bool:
    stmt = (
        update(Ticket)
        .where(and_(Ticket.id == ticket_id, Ticket.sold.is_(False)))
        .values(user=user, sold=True)
    )
    result = await db.execute(stmt)
    await db.commit()
    return result.rowcount > 0
```

`WHERE sold = False` を条件に含めることで、同時に2つのリクエストが同じチケットの販売を試みても、後から `commit` する側は `rowcount == 0` となり販売失敗として扱える。明示的なロックを取得せずに「更新できたか」で競合を検出する軽量なパターンであり、高頻度の競合が想定される場合は行レベルロック（`SELECT ... FOR UPDATE`）や楽観的ロック用のバージョンカラムを検討する。

---

## まとめ

**実装の優先順位:**

1. **モデル定義は `DeclarativeBase` + `Mapped`/`mapped_column`** で型安全に行う（旧`Column`記法は避ける）。
2. **DBセッションは `Annotated[T, Depends(...)]` で依存性として注入**し、エンドポイントに直接クエリを書かずリポジトリ層に分離する。
3. **非同期ドライバを選んだら最後まで非同期で統一**する。同期呼び出しの混在はイベントループをブロックする。
4. **スキーマ変更は Alembic で管理**し、`Base.metadata.create_all` は開発用途に限定する。
5. **MongoDBはデータの変更頻度・共有範囲でembedding/referencingを選択**し、検索対象フィールドには必ずインデックスを張る。
6. **同時更新が発生する箇所は分離レベルと競合検出戦略を明示的に設計**する（無条件のUPDATEは避ける）。
