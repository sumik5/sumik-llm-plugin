# プロジェクト実装パターン

Pythonプロジェクトにおけるビジネスオブジェクト設計・データ永続化・テスト戦略の実践パターン集。
API開発・マイクロサービス・バックエンドサービスを対象とした設計判断の基準を提供する。

---

## プロジェクト構造の進化

### レガシーコード評価アプローチ

既存コードベースの改善前に、以下を体系的に評価する：

```
評価カテゴリ:
1. プロジェクト構造・パッケージ管理
2. ビジネスオブジェクト定義の品質
3. データ永続化の実装
4. テスト戦略・カバレッジ
5. ビルド・デプロイプロセス
```

**リファクタリングの原則**: コードが「何をするか」を変えずに「どうするか」を改善する。
段階的変更により、各ステップで既存コードとの置き換え可能性を維持する。

### Namespace Packageパターン

複数パッケージを単一トップレベル名前空間の下にまとめる設計：

```
myapp/                    ← トップレベル名前空間
  core/                   ← 共通基底クラス（全パッケージの内部依存）
    business_objects/     ← 業務オブジェクトの抽象基底クラス群
    data_objects/         ← データ永続化の抽象基底クラス群
  domain_a/               ← ドメインA固有（例: Artisan相当）
    data_storage/
    objects/
  domain_b/               ← ドメインB固有（例: BackOffice相当）
    data_storage/
    objects/
```

**メリット**: 関心事ごとに独立してインストール可能（composable packages）。
`domain_a` のみインストールすると `core` が自動的に取り込まれ、`domain_b` は含まれない。

### パッケージ管理ツール選択基準

| 条件 | 推奨ツール | 理由 |
|------|-----------|------|
| 最終成果物がすべてパッケージ | `poetry` | ビルドツールチェーンが自動構成 |
| パッケージ以外の成果物を含む（サーバーレス関数等） | `pipenv` | 汎用的、制約が少ない |
| セキュリティ脆弱性チェックが必要 | `pipenv` | `pipenv check` が組み込み |
| ロックファイルを確定的ビルドに使いたい | `pipenv` | `Pipfile.lock` + SHA-256ハッシュ |

**注意**: `Pipfile.lock` と `requirements.txt` は一方のみをSCMに保存。両方保存すると不整合リスクがある。

### Linting/Formatting標準の導入

```bash
# 開発依存として追加
pipenv install --dev flake8 pytest

# .flake8 設定（プロジェクトルート）
[flake8]
max-line-length = 88
max-complexity = 8   # McCabe複雑度の警告閾値（10を超えると危険）

# SCMフック・CIで実行
pipenv run flake8 --exit-zero --max-complexity 8 src/
```

`--exit-zero`: lintエラーでビルドを止めず、情報として報告。
`--max-complexity 8`: 複雑度8以上を警告（公式上限10の手前で検知）。

---

## ビジネスオブジェクト設計

### 4つの実装アプローチ比較

| アプローチ | 型安全性 | バリデーション | JSON化 | OASスキーマ自動生成 | 依存パッケージ | 推奨シーン |
|-----------|---------|--------------|--------|-------------------|--------------|-----------|
| `dict` + JSON Schema | なし | 明示的呼び出し時のみ | 自動 | 手動調整が必要 | `fastjsonschema` (~370kB) | 単純な構造 |
| Pythonクラス + `@property` | `typeguard` | setter実行時 | 手動実装 | 手動作成 | `typeguard` (~75kB) | 複雑なバリデーション |
| `dict` 派生クラス | `typeguard` | setter実行時 | 自動（dict継承） | 手動作成 | `typeguard` | dict互換が必要 |
| **Pydantic BaseModel** | **組み込み** | **フィールド定義時** | **自動** | **自動生成** | `pydantic` (~770kB) | **API開発・標準推奨** |

**決定基準**: API開発でOAS（OpenAPI Specification）ドキュメントが必要なら、Pydanticを選択。

### ABCによる抽象基底クラスパターン

```python
import abc
from typing import Optional
from pydantic import BaseModel, Field
from uuid import UUID, uuid4
from datetime import datetime

# 共通データフィールドのミックスイン（ABCとして定義）
class BaseDataObject(metaclass=abc.ABCMeta):
    """全ビジネスオブジェクト共通フィールドと抽象メソッドのミックスイン。"""
    oid = Field(default_factory=uuid4, frozen=True)   # UUID、生成後変更不可
    is_active = Field(default=False)
    is_deleted = Field(default=False)
    created = Field(default_factory=datetime.utcnow, frozen=True)
    modified = Field(default=None)

    @classmethod
    def from_record(cls, data) -> "BaseDataObject":
        """DBクエリ結果（dict または tupleリスト）からインスタンスを生成。"""
        if isinstance(data, (list, tuple)) and not isinstance(data[0], str):
            data = dict(data)
        return cls(**data)

    @abc.abstractmethod
    def save(self) -> None:
        """状態をDBに保存（新規作成または更新）。派生クラスで実装必須。"""
        raise NotImplementedError

    @classmethod
    @abc.abstractmethod
    def get(cls, **filters) -> list:
        """DB から条件付き取得。ページネーション・ソート対応。派生クラスで実装必須。"""
        raise NotImplementedError

    @classmethod
    @abc.abstractmethod
    def delete(cls, oid: UUID) -> None:
        """物理削除。派生クラスで実装必須。"""
        raise NotImplementedError
```

**設計判断**: `save` を抽象メソッドにする理由は、各クラスが固有のSQLを持つため。
将来的にSQLをテンプレート化して `BaseDataObject` に共通実装を持たせることも可能。

### Pydanticによる具体クラス実装

```python
from pydantic import BaseModel, field_validator
from pydantic import EmailStr   # pydantic[email] 必要
import re

PHONE_PATTERN = re.compile(
    r'^(\+\d{1,2}\s)?\(?\d{3}\)?[\s.-]\d{3}[\s.-]\d{4}$'
)

class Address(BaseModel):
    """住所（他のオブジェクトへの合成・集約で再利用可能）。"""
    street_address: str
    building_address: Optional[str] = None
    city: str
    region: str
    postal_code: str
    country: Optional[str] = None


class Entity(BaseDataObject, BaseModel):
    """具体的な業務オブジェクト（例: ユーザー、顧客等）。"""
    honorific: Optional[str] = None
    given_name: str
    family_name: str
    suffix: Optional[str] = None
    address: Address
    email_address: EmailStr   # pydantic組み込みバリデーション
    phone: Optional[str] = None

    @field_validator('honorific', 'suffix')
    @classmethod
    def validate_honorific(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return v
        v = v.strip()
        if v and (len(v) < 2 or len(v) > 7):
            raise ValueError('2〜7文字で入力してください')
        return v or None

    @field_validator('given_name', 'family_name')
    @classmethod
    def validate_name(cls, v: str) -> str:
        v = v.strip()
        if len(v) < 2:
            raise ValueError('2文字以上必要です')
        return v

    @field_validator('phone')
    @classmethod
    def validate_phone(cls, v: Optional[str]) -> Optional[str]:
        if v and not PHONE_PATTERN.match(v):
            raise ValueError(f'電話番号の形式が正しくありません: {v}')
        return v

    def save(self) -> None:
        # 具体的なSQL実装はサブクラスで
        raise NotImplementedError

    @classmethod
    def get(cls, **filters) -> list:
        raise NotImplementedError

    @classmethod
    def delete(cls, oid) -> None:
        raise NotImplementedError
```

### プロパティ設計の判断基準

| 項目 | 必須フィールド | オプションフィールド |
|------|--------------|-------------------|
| Pydanticでの定義 | `field_name: str` | `field_name: Optional[str] = None` |
| 欠損時の動作 | ValidationError | `None` を返す |
| JSON出力 | 常に含む | `None` の場合は省略可能（`model_config` で制御） |
| バリデーション | 値が存在する前提で検証 | `if v is None: return v` で早期リターン |

**設計ガイドライン**: フロントエンドJSから参照する場合、`null` フィールドを含む方が安全（undefined チェック不要）。

---

## データ永続化

### データストア選択基準

| 要件 | SQL RDBMS | NoSQL (MongoDB等) |
|------|-----------|-----------------|
| ACID準拠必須 | ✅ | 限定的 |
| 構造化データ・リレーション | ✅ 強力 | ❌ 複雑になる |
| スキーマが頻繁に変化 | ❌ マイグレーション必要 | ✅ 柔軟 |
| JSON ドキュメント全体を保存 | ❌ 非効率 | ✅ ネイティブ対応 |
| 将来クラウド移行を考慮 | ✅ 主要クラウドで利用可 | ✅ 主要クラウドで利用可 |
| OASドキュメント自動生成が必要 | Pydanticで対応 | Pydanticで対応 |

**バリデーション配置の判断**:

| 戦略 | メリット | デメリット |
|------|---------|----------|
| コードのみ | 柔軟、APIドキュメント自動生成 | DB直接変更で無効データ混入のリスク |
| DBのみ | DB側で保証 | バリデーションにDB接続が必要、ドキュメント管理困難 |
| **両方** | **最も強固** | **二重管理が必要（コードとDBを同期）** |

### BaseDataObjectパターン詳細

**共通フィールドの意味**:

```python
# is_active / is_deleted の運用パターン
# 論理削除: レコードを実際に消さず、フラグで見えなくする
# ユースケース: 決済完了前のユーザーアカウントの閉鎖など

# UUIDをIDに使う理由（自動連番との比較）
# 連番: 毎秒100万試行なら数秒でヒット
# UUID v4: 1.8 × 10^19 通りの組み合わせ → 数千年必要
```

**対応する SQL テーブル定義テンプレート**:

```sql
-- すべての業務オブジェクトテーブルの共通フィールド
oid       CHAR(36)    NOT NULL PRIMARY KEY,     -- UUID文字列
is_active TINYINT(1)  DEFAULT 1  NOT NULL,      -- 公開フラグ
is_deleted TINYINT(1) DEFAULT 0  NOT NULL,      -- 論理削除フラグ
created   DATETIME    DEFAULT CURRENT_TIMESTAMP NOT NULL,
modified  DATETIME    ON UPDATE CURRENT_TIMESTAMP NULL,
-- 以降に業務オブジェクト固有フィールドを追加
data      JSON        NULL                      -- Pydanticモデルの全データ
```

**Pydanticモデルと JSONカラムの組み合わせパターン**:
クエリに使うフィールドのみ専用カラムとして定義し、残りは `data` JSONカラムに格納。
ORM採用を回避しながら、Pydanticのスキーマ自動生成能力を維持できる。

### マイグレーション管理（SQL ファイルベース）

```
database/
  setup/                          # 初回セットアップのみ
    001-create-database.sql
    002-create-user.sql
    003-grant-permissions.sql
  migrations/                     # 変更履歴（連番で管理）
    000010-create-entities-table.sql
    000020-create-products-table.sql   # entities への外部キー
    000030-add-status-column.sql       # チケット番号を含めてもよい
  apply-migrations.py             # 全SQLを順番通りに適用
```

**ファイル命名規則**:
- 10刻みの連番 → 後から途中に挿入可能
- `sort` コマンドで並べた順に実行
- MySQL: 既存テーブルへの重複実行はエラーを出すが処理継続（べき等性）

```python
# apply-migrations.py の骨格
import subprocess
from pathlib import Path

def apply_migrations(db_host, db_name, db_user, migrations_dir):
    """migrations/ 内のSQLファイルを連番順に適用。"""
    sql_files = sorted(Path(migrations_dir).glob('*.sql'))
    for sql_file in sql_files:
        # バックアップを取ってから適用
        subprocess.run(['mysql', '-h', db_host, '-u', db_user, db_name,
                        '-e', f'SOURCE {sql_file}'])
```

### CRUD 抽象化と REST マッピング

| CRUD操作 | HTTP動詞 | SQL | 注意点 |
|---------|---------|-----|--------|
| Create | `POST` | `INSERT` | UUIDをコード側で生成する場合は `uuid4()` 使用 |
| Read（単体） | `GET /resources/{id}` | `SELECT WHERE oid=?` | 返却フィールドを明示指定 |
| Read（一覧） | `GET /resources/?page=1&max=10` | `SELECT ... LIMIT OFFSET` | ページネーション必須 |
| Update（部分） | `PATCH` | `UPDATE SET field=?` | 変更フィールドのみ送信 |
| Update（全体） | `PUT` | `UPDATE SET all=?` | べき等性あり、競合に注意 |
| Delete | `DELETE /resources/{id}` | `DELETE` or `is_deleted=1` | 論理削除 vs 物理削除を設計で決定 |

**PATCHとPUTの使い分け**: 複数ユーザーが同じレコードを編集する可能性がある場合は `PATCH`（変更フィールドのみ送信）を推奨。`PUT` は完全置き換えのため、並行編集で上書き消失が発生しやすい。

---

## テスト設計パターン

> **注意**: ユニットテストの基本（pytest, Vitest, AAA パターン等）は `TESTING.md` を参照。
> このセクションは業務オブジェクト・データ永続化層に特化したパターンを扱う。

### テスト種別と責務

| テスト種別 | スコープ | 外部依存 | ブロッカー条件 |
|-----------|---------|---------|--------------|
| ユニット | 関数・クラスメソッド単体 | モック必須 | 全て |
| 統合 | モジュール間の連携 | 内部コードのみ（外部はモック） | 重要パス |
| システム | システム全体の機能 | 実DB・API接続可 | リリース前 |
| E2E | ユーザーシナリオ | 実環境接続 | リリース前 |
| UAT | ユーザー視点の受け入れ | 実環境接続 | ステージング確認時 |

**環境分離の原則**:
```
開発環境 → テスト環境 → ステージング（本番レプリカ）→ 本番
```
各環境は独立させ、テストデータが本番に混入しないよう管理。

### 業務オブジェクトのテスト標準（9つのガイドライン抜粋）

1. **すべての関数・メソッドにテストを用意**（未実装でも `pass` またはスタブで存在を示す）
2. **ハッピーパス**: 有効な入力で期待通りの出力を確認
3. **アンハッピーパス**: 無効な入力（型違反・バリデーション失敗）で期待どおりのエラーを確認
4. **プロパティテスト**: 設定（setter）→取得（getter）→削除後の取得を各々テスト
5. **外部依存（DB・API）は必ずモック**: ユニットテストはローカル環境外でも実行できるように
6. **カバレッジレポートを実行・確認**: 目標値を強制せず、未実行コードの特定に利用
7. **統合テストは同一プロジェクト内のコード間連携を許可**（外部サービスはモック継続）
8. **DBに対するテストは統合テスト以上**: ユニットテストではDBコネクションをモック
9. **テスト失敗はビルドをブロック**: CI/CDパイプラインへの統合を前提に設計

### ABCクラスのテストアプローチ

```python
import pytest
from unittest.mock import patch, MagicMock
from myapp.core.data_objects import BaseDataObject

# ABCは直接インスタンス化できないため、テスト用の具体クラスを作成
class ConcreteEntity(BaseDataObject, BaseModel):
    name: str

    def save(self) -> None:
        pass   # テスト用の最小実装

    @classmethod
    def get(cls, **filters) -> list:
        return []

    @classmethod
    def delete(cls, oid) -> None:
        pass


class TestBaseDataObject:
    def test_oid_generated_on_create(self):
        entity = ConcreteEntity(name='test')
        assert entity.oid is not None

    def test_oid_immutable(self):
        entity = ConcreteEntity(name='test')
        with pytest.raises(Exception):
            entity.oid = 'new-id'   # frozenなので変更不可

    def test_is_deleted_defaults_false(self):
        entity = ConcreteEntity(name='test')
        assert entity.is_deleted is False

    def test_from_record_accepts_dict(self):
        record = {
            'name': 'test',
            'is_active': True,
            'is_deleted': False,
        }
        entity = ConcreteEntity.from_record(record)
        assert entity.name == 'test'
```

### データ永続化層のモック戦略

```python
import pytest
from unittest.mock import patch, MagicMock, call
from myapp.core.data_objects import get_db_connector


class TestEntityPersistence:
    def test_save_creates_new_record(self):
        entity = ConcreteEntity(name='test')
        mock_cursor = MagicMock()
        mock_conn = MagicMock()
        mock_conn.__enter__ = lambda s: mock_conn
        mock_conn.__exit__ = MagicMock(return_value=False)
        mock_conn.cursor.return_value.__enter__ = lambda s: mock_cursor
        mock_conn.cursor.return_value.__exit__ = MagicMock(return_value=False)

        with patch('myapp.core.data_objects.get_db_connector',
                   return_value=mock_conn):
            entity.save()

        # INSERTが呼ばれたことを確認
        assert mock_cursor.execute.called
        sql_called = mock_cursor.execute.call_args[0][0]
        assert 'INSERT' in sql_called.upper()

    def test_get_filters_deleted_records(self):
        mock_cursor = MagicMock()
        mock_cursor.fetchall.return_value = []

        with patch('myapp.core.data_objects.get_db_connector') as mock_db:
            mock_db.return_value.__enter__.return_value.cursor\
                .return_value.__enter__.return_value = mock_cursor
            results = ConcreteEntity.get(is_deleted=False)

        sql_called = mock_cursor.execute.call_args[0][0]
        assert 'is_deleted' in sql_called.lower()
```

### テストデータ構築パターン

```python
import pytest

# pytestフィクスチャで再利用可能なテストデータを定義（階層的に組み合わせる）
@pytest.fixture
def valid_address_data():
    return {'street_address': '1-2-3 テスト通り', 'city': 'テスト市',
            'region': 'テスト県', 'postal_code': '100-0001'}

@pytest.fixture
def valid_entity_data(valid_address_data):
    return {'given_name': '太郎', 'family_name': 'テスト',
            'email_address': 'taro@example.com', 'address': valid_address_data}

@pytest.fixture
def saved_entity(valid_entity_data):
    """DBに保存済みのエンティティ（oid/created は自動生成）。"""
    return ConcreteEntity(**valid_entity_data)
```

### カバレッジ分析の活用

```bash
# テスト実行とカバレッジ計測
pipenv run coverage run -m pytest tests/unit

# 未実行行を表示（src/のみ対象）
pipenv run coverage report -m --include "src/*"
```

**カバレッジレポートの読み方**:
- `Miss` 列: 実行されなかった行数
- `Cover` 列: カバレッジ率（%）
- **Missing lines の活用**: 未実行コードを特定し、テストケースの追加またはデッドコードの削除を判断

```
Name                    Stmts  Miss  Cover
------------------------------------------
src/myapp/core/entity.py   58    10    83%
src/myapp/core/storage.py  180    9    95%
------------------------------------------
TOTAL                      238   19    92%
```

**実践的な基準**:
- ビジネスロジック（バリデーション、状態遷移）: 100%を目標
- データアクセス層（SQL生成、DB接続）: 統合テストで補完
- ユーティリティ・ヘルパー: 80%以上

---

## 関連リファレンス

- `TESTING.md` — pytest の基本、AAA パターン、フィクスチャ設計
- `SD-PRINCIPLES.md` — SOLID原則、設計判断の基準
- `SD-CREATIONAL.md` — Factory, Builder パターン（オブジェクト生成の複雑化時に参照）
- `SE-SDLC-METHODOLOGY.md` — ソフトウェア開発プロセス全体像
- `SE-SYSTEM-MODELING.md` — クラス図・ユースケース図の読み方と活用
