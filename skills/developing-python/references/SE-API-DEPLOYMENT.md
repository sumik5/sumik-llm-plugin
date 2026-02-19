# CI/CD・API設計・デプロイメント

PythonプロジェクトにおけるCI/CDパイプライン、API標準選択、フレームワーク比較、デプロイメント戦略。

---

## CI/CDパイプライン

### CI/CDの目的と原則

**Continuous Integration (CI)**: コード変更を共有リポジトリに統合し、毎回同一の自動プロセスを実行する

**Continuous Delivery (CD)**: コードを本番デプロイ可能な状態まで自動化（最低1つの手動承認ステップを含む）

**Continuous Deployment**: 手動介入なしに本番環境まで自動デプロイ。後続モニタリングで問題検出時にロールバック

**自動化の主な利点**:
- 再現性（手動ミスの排除）
- プロセスの一貫性強制
- コードとしてCI/CD定義を管理可能

### Pythonプロジェクトの典型的パイプライン

```
コード変更
  ↓
[1] Lint (ruff)
  ↓ 失敗→停止
[2] 型チェック (mypy)
  ↓ 失敗→停止
[3] ユニットテスト (pytest)
  ↓ 失敗→停止
[4] パッケージビルド
  ↓ 失敗→停止
[5] 環境デプロイ (dev → staging → prod)
  ↓ 失敗→ロールバック
[6] 統合/受入テスト
  ↓
[7] パブリッシュ
```

**重要原則**: どのステップが失敗しても後続ステップは実行しない

### Python固有のビルド戦略

| 成果物タイプ | ツール・方式 | 用途 |
|-------------|------------|------|
| Wheel配布 | `python -m build` → `.whl` | PyPI公開、pip install可能なライブラリ |
| Source配布 | `python -m build` → `.tar.gz` | ソース配布 |
| ZIP archive | `zip my-package.zip` | AWS Lambda、任意環境の依存同梱 |
| Dockerイメージ | `Dockerfile` + `docker build` | コンテナデプロイ |
| バイトコード | `py_compile` → `.pyc` | 明示的コンパイル（通常不要） |

**Pythonの特性**: `.pyc`ファイルはimport時に自動生成されるため、明示的コンパイルステップは通常不要。ユニットテストが全モジュールをimportすれば副産物として全てコンパイル済みになる。

```python
# ZIPパッケージの作成例（Lambda向け）
mkdir my-package
cp src/my_code/*.py my-package/
pip install -r requirements.txt --target my-package/
zip -r my-package.zip my-package/
```

### 環境管理（dev/staging/production）

| 環境 | 主な利用者 | 目的 | データ |
|------|-----------|------|--------|
| **development** | 開発チーム | 統合確認、破壊的変更の早期検出 | 開発用データ |
| **test / QA** | QAチーム | 統合テスト、性能テスト、セキュリティテスト | テスト用データ |
| **staging** | 複数チーム | 本番レプリカ、UAT実施 | 本番同等データ |
| **production** | エンドユーザー | 実際のサービス提供 | 本番データ |

**staging環境のポイント**: 本番環境のほぼ完全なレプリカであるべき。ハードウェア・データ量・品質において本番と同等であることが理想。

### デプロイメント戦略比較

| 戦略 | 概要 | メリット | デメリット |
|------|------|---------|-----------|
| **Rolling** | インスタンスを順次更新 | ダウンタイムなし、リソース効率的 | 混在バージョン期間が発生 |
| **Blue-Green** | 2環境を切り替え | 即時ロールバック可能 | リソースが2倍必要 |
| **Canary** | 一部トラフィックのみ新バージョンへ | リスク最小化、本番検証可能 | モニタリング設計が複雑 |
| **Recreate** | 旧を停止→新を起動 | シンプル | ダウンタイムあり |

### ロールバック戦略

- **自動ロールバック**: エラー率・レイテンシ・パフォーマンス閾値を超えたら自動で旧バージョンへ復元
- **Canaryテスト**: 本番の一部トラフィックで新バージョンを検証し、問題検出でロールバック
- **Pythonパッケージ**: PyPIでは旧バージョンのpip installが常に可能

---

## API標準

### REST（REpresentational State Transfer）

最も広く使われるWeb API標準。2000年代初頭から成熟。

**6つの設計原則**:
1. クライアント/サーバー分離
2. ステートレス（各リクエストは独立）
3. キャッシュ可能
4. 統一インターフェース
5. 階層型システム
6. （オプション）コードオンデマンド

**HTTPメソッドとCRUDマッピング**:

| HTTPメソッド | CRUD操作 | 用途 | ボディ |
|-------------|---------|------|--------|
| `GET` | Read | リソース取得 | なし |
| `POST` | Create | リソース作成 | JSONペイロード |
| `PUT` | Update | リソース全体置換 | JSONペイロード |
| `PATCH` | Update | リソース部分更新 | JSONペイロード |
| `DELETE` | Delete | リソース削除 | 任意 |
| `HEAD` | Read | ヘッダーのみ取得（キャッシュ確認） | なし |

**RESTステータスコードの使い分け**:

| コード | 意味 | 使用例 |
|--------|------|--------|
| 200 OK | 成功 | GET/PATCH成功 |
| 201 Created | 作成成功 | POST成功 |
| 204 No Content | 成功（本文なし） | DELETE成功 |
| 304 Not Modified | キャッシュ有効 | ETag一致 |
| 400 Bad Request | クライアントエラー | 不正なペイロード |
| 401 Unauthorized | 未認証 | 認証トークンなし |
| 403 Forbidden | 権限不足 | アクセス拒否 |
| 404 Not Found | リソースなし | 存在しないID |
| 500 Internal Server Error | サーバーエラー | 予期しない例外 |

**REST URLリソース設計例**:
```
GET    /api/v1/artisans/           # 一覧取得
POST   /api/v1/artisans/           # 新規作成
GET    /api/v1/artisans/{oid}/     # 単体取得
PATCH  /api/v1/artisans/{oid}/     # 部分更新
DELETE /api/v1/artisans/{oid}/     # 削除
GET    /api/v1/artisans/{oid}/products/   # ネストリソース
```

**RESTの制約**:
- ポーリングなしにリアルタイム更新不可
- over-fetching（不要なデータも取得）が発生しやすい
- 複数リソースの取得に複数リクエストが必要なことがある

### GraphQL

Facebookが2012年に開発、2015年に公開。単一エンドポイント (`/graphql`) でフレキシブルなデータ取得を実現。

**主な特徴**:
- クライアントが必要なフィールドを指定（over-fetchingを回避）
- **query**（データ取得）と **mutation**（変更）、**subscription**（リアルタイム）の3操作
- スキーマによってAPIを型定義

```graphql
# クエリ例
query GetArtisanWithProducts($id: ID!) {
  artisan(oid: $id) {
    givenName
    familyName
    products {
      oid
      name
      price
    }
  }
}

# ミューテーション例
type Mutation {
  createArtisan(input: CreateArtisanInput!): Artisan!
  updateProduct(input: UpdateProductInput!): Product!
}
```

**GraphQL実装ライブラリ（Python）**:
- **Graphene**: クラスベース、`graphene-pydantic`でPydanticモデル統合
- **Ariadne**: スキーマファースト、resolverを別途定義

**N+1問題**: GraphQLで関連データを取得する際、1+N回のDB問合せが発生する典型的な問題。DataLoaderパターンで解決。

### RPC（Remote Procedure Call）

関数呼び出しモデルでAPIを提供。リソースよりもアクション指向。

- **gRPC**: Googleが開発。Protocol Buffersを使った高性能RPC。マイクロサービス間通信に適合
- **JSON-RPC**: JSONベースの軽量RPC

### SOAP（Simple Object Access Protocol）

XMLベースのAPI標準。WS-Security等のセキュリティ標準を持つ。エンタープライズシステムの既存実装で見られる。

### API標準選択基準テーブル

| 基準 | REST | GraphQL | gRPC | SOAP |
|------|------|---------|------|------|
| **データ構造の複雑さ** | 単純〜中程度 | 複雑・関連データ多い | 高性能要件 | レガシー統合 |
| **クライアント多様性** | 適合 | 最適 | 限定的 | 限定的 |
| **リアルタイム** | polling必要 | subscription対応 | ストリーミング対応 | 非対応 |
| **認証/認可の実装** | 容易 | 複雑（単一EP） | 設定可能 | 組込WS-Security |
| **学習コスト** | 低 | 中〜高 | 高 | 高 |
| **フロントエンドとの相性** | 良好 | 最適 | 限定的 | 劣る |
| **既存エコシステム** | 成熟 | 成長中 | 成長中 | 成熟（縮小傾向） |

**選択指針**:
- **REST**: シンプルなCRUD、チームがHTTPに慣れている、フロントエンドがJSON前提
- **GraphQL**: データが複雑に関連、フロントエンドが多様な要求を持つ、over-fetchingが問題
- **gRPC**: マイクロサービス間の内部通信、高スループット、型安全性重視
- **SOAP**: レガシーシステムとの統合、エンタープライズWS-*標準が要件

---

## Pythonフレームワーク比較

### Flask

```python
from flask import Flask, request
import json

app = Flask(__name__)

@app.route('/api/v1/artisans/', methods=['GET'])
def get_artisans_root():
    # artisan一覧を返す
    ...

@app.route('/api/v1/artisans/<oid>/', methods=['GET'])
def get_artisan_by_oid(**kwargs):
    oid = kwargs.get('oid')
    ...

@app.route('/api/v1/artisans/', methods=['POST'])
def post_artisans_root():
    payload = json.loads(request.data)
    ...

@app.route('/api/v1/artisans/<oid>/', methods=['PATCH'])
def patch_artisan_by_oid(**kwargs):
    payload = json.loads(request.data)
    oid = kwargs.get('oid')
    ...
```

**特徴**: WSGIベース。1つのrouteデコレータで複数のHTTPメソッドを処理可能。テンプレートエンジン(Jinja2)と統合しやすい。

### FastAPI

```python
from fastapi import FastAPI
import os

app = FastAPI()

@app.get('/api/v1/artisans/')
async def get_artisans_root():
    ...

@app.get('/api/v1/artisans/{oid}/')
async def get_artisan_by_oid(oid: str):
    # oidは明示的なパラメータとして受け取る
    ...

@app.post('/api/v1/artisans/')
async def post_artisans_root(payload: dict):
    ...

@app.patch('/api/v1/artisans/{oid}/')
async def patch_artisan_by_oid(oid: str, payload: dict):
    ...
```

**特徴**: ASGIベース（Starlette）。メソッドごとに専用デコレータ。`asyncio`対応で高性能。Pydantic統合で自動バリデーション。OpenAPI/Swagger自動生成。

> **FastAPIとasyncio**: I/Oバウンド処理（DB・外部API通信）を並行実行。これがFlaskに対する速度優位性の主因。

### Django REST Framework（DRF）

**特徴**: Djangoのフルスタック機能（ORM、Admin、認証）とREST APIを統合。サードパーティパッケージが豊富（djangopackages.org）。

**注意**: `djangorestframework`パッケージ（`django-rest-framework`ではない）を使用。

### フレームワーク比較テーブル

| 比較軸 | Flask | FastAPI | Django+DRF |
|--------|-------|---------|------------|
| **パフォーマンス** | 中 | 高（asyncio） | 中 |
| **学習コスト** | 低 | 中 | 高 |
| **非同期対応** | △（Flask 2.0+） | ◎ネイティブ | △ |
| **ORM** | なし（選択自由） | なし（選択自由） | Django ORM組込 |
| **自動ドキュメント** | flask-swagger等 | ◎OpenAPI自動生成 | drf-spectacular等 |
| **エコシステム** | 豊富 | 成長中 | 非常に豊富 |
| **マイクロサービス向き** | ◎ | ◎ | △（重厚） |
| **フルスタック向き** | △ | △ | ◎ |

**選択基準**:
- **Flask**: シンプルなAPI、軽量、既存チームの習熟度が高い
- **FastAPI**: 高性能API、asyncio活用、Pydanticによる型安全性
- **Django+DRF**: フルスタックWebアプリ、豊富なエコシステムが必要

---

## デプロイメントパターン

### WSGI/ASGIサーバー構成（伝統的サーバーデプロイ）

```
クライアント → Nginx（リバースプロキシ）→ Gunicorn/uvicorn → Flask/FastAPI
```

- **WSGI**: 同期処理。Flaskで使用。Gunicorn、Waitress、uWSGI
- **ASGI**: 非同期処理。FastAPIで使用。uvicorn、Hypercorn

### コンテナデプロイ（Docker → ECS/EKS/Cloud Run）

**基本Dockerfile（FastAPI）**:
```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY . /app
RUN pip install --no-cache-dir -r /app/requirements.txt
EXPOSE 5000
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "5000"]
```

**コンテナ化の利点**:
- ローカル開発環境と本番環境の一致
- クラウドプロバイダー非依存（AWS ECS/EKS、GCP Cloud Run、Azure Container Apps）
- スケールアウトが容易（同一イメージから複数コンテナ）

**詳細は `DOCKER.md` 参照**

### サーバーレスデプロイ（AWS Lambda + API Gateway）

**アーキテクチャ**:
```
クライアント → API Gateway → Lambda Function → DB/他サービス
```

**Lambda関数の基本構造**:
```python
import json
import logging

logger = logging.getLogger()

def lambda_handler(event: dict, context: object) -> dict:
    """
    AWS Lambda Proxy Integration標準のハンドラ。
    Parameters:
      event: HTTPリクエスト情報（path, headers, body等）
      context: Lambda実行コンテキスト
    """
    try:
        # eventからリクエストデータを取得
        oid = event['pathParameters']['oid']
        body = json.loads(event.get('body', '{}'))

        # ビジネスロジック処理
        result = process_request(oid, body)

        return {
            'statusCode': 200,
            'body': json.dumps(result)
        }
    except KeyError as error:
        logger.error(f'Missing parameter: {error}')
        return {
            'statusCode': 400,
            'body': f'Bad Request: {error}'
        }
    except Exception as error:
        logger.exception(f'Unexpected error: {error}')
        return {
            'statusCode': 500,
            'body': 'Internal Server Error'
        }
```

**Lambda Proxy Integration の `event` 構造**:
```python
{
    'path': '/v1/artisans/00000000-0000-0000-0000-000000000001',
    'resource': '/v1/artisans/{oid}',
    'pathParameters': {'oid': '00000000-0000-0000-0000-000000000001'},
    'httpMethod': 'GET',
    'headers': {...},
    'queryStringParameters': {...},
    'body': '{}',           # POST/PATCH/PUTはJSONペイロード
    'isBase64Encoded': False
}
```

**セキュリティ原則**: エラー詳細はログに記録し、クライアントには最小限の情報のみ返す（内部構造の漏洩防止）。

**AWS API Gatewayの2種類**:
- **REST API**: 高機能、CloudFront CDN自動統合、セキュリティ・認可・モニタリング機能充実
- **HTTP API**: シンプル、低コスト、基本的なLambda統合

### クラウドサービス比較（GraphQL）

| クラウド | REST API | GraphQL |
|---------|---------|---------|
| AWS | API Gateway | AppSync |
| GCP | API Gateway | Apigee |
| Azure | API Management | API Management |

### デプロイパターン選択基準テーブル

| 基準 | 伝統的サーバー (WSGI/ASGI) | コンテナ (Docker) | サーバーレス (Lambda) |
|------|--------------------------|-----------------|---------------------|
| **コスト** | 常時稼働費用 | 中（インスタンス） | 従量課金（低トラフィック最安） |
| **スケーラビリティ** | 手動設定必要 | 自動スケール可能 | 自動スケール |
| **デプロイの複雑さ** | 低 | 中 | 中〜高 |
| **ポータビリティ** | 高（サーバー依存） | 最高（クラウド非依存） | 低（プロバイダー依存） |
| **ローカル開発** | 容易 | 容易 | 複雑（SAM/LocalStack） |
| **Cold start** | なし | なし | あり（対策が必要） |
| **最大実行時間** | 制限なし | 制限なし | 15分（Lambda） |
| **向いているワークロード** | 長時間実行 | 任意 | イベント駆動、短時間処理 |

### AWS固有の考慮点

**Lambda Cold start対策**:
- Provisioned Concurrency（ウォームインスタンスを事前確保）
- 依存パッケージのサイズ最小化（cold start時間を短縮）
- Lambda Layersで共通依存を分離

**API Gatewayの設定ポイント**:
- バージョニング: URLパスに `/v1/`, `/v2/` を含める
- Lambdaオーソライザー: JWT検証やAPIキー確認をLambdaで実施
- キャッシュ設定: 同一GETリクエストをキャッシュしてDB負荷軽減

**IaCツール選択（AWS）**:

| ツール | 特徴 | 向いているケース |
|--------|------|----------------|
| **CloudFormation** | AWS純正、最も広範なサービス対応 | 複雑なAWSリソース管理 |
| **SAM** | CloudFormationのサーバーレス特化ラッパー | Lambda+API Gateway中心のAPI |
| **CDK** | Pythonコードでインフラ定義 | コードと統一した管理、再利用性重視 |
| **Terraform** | マルチクラウド対応、詳細な状態管理 | クラウド非依存、ポータビリティ重視 |

### ローカル開発（サーバーレス）

| 方法 | ツール | 特徴 |
|------|--------|------|
| 開発者専用クラウド環境 | AWS CLI + boto3 | 本番と同じ環境だが費用発生 |
| SAMローカル実行 | `sam local` | Docker使用、リビルド必要で遅い |
| AWS完全エミュレーション | LocalStack | 100+サービス対応、無料/有料Tier |
| Lambda→FastAPI/Flaskラッパー | `chalice` / カスタム | Lambda関数をローカルAPIとして実行 |

---

## APIキャッシュ（HTTPキャッシュヘッダー）

```python
from hashlib import md5
import json

def add_cache_headers(response_body: dict) -> dict:
    """ETag と Last-Modified ヘッダーを付与する例"""
    body_str = json.dumps(response_body, sort_keys=True)
    etag = md5(body_str.encode()).hexdigest()
    return {
        'statusCode': 200,
        'headers': {
            'ETag': f'"{etag}"',
            'Last-Modified': 'Thu, 01 Jan 2026 00:00:00 GMT',
            'Cache-Control': 'max-age=300'
        },
        'body': body_str
    }
```

| ヘッダー | 種類 | 用途 |
|---------|------|------|
| `ETag` | レスポンス | リソースのバージョン識別子 |
| `Last-Modified` | レスポンス | 最終更新日時 |
| `If-None-Match` | リクエスト | ETagが一致しない場合のみ返す |
| `If-Modified-Since` | リクエスト | 指定日時以降に変更があれば返す |

サーバーが `304 Not Modified` を返すとクライアントはキャッシュを使用。DB負荷とネットワーク転送量を削減。
