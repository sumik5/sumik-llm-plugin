# FastAPI 本番デプロイとスケーリング

FastAPI アプリケーションを本番環境で稼働させるための構成——ASGI サーバーの起動方式・コンテナ化・環境変数/Settings 管理・パフォーマンス最適化・スケーリング戦略・Kubernetes デプロイ概要——をまとめる。CI/CD パイプライン設計や IaC 全般の DevOps プラクティスは対象外（`cloud:practicing-devops` を参照）。

> **Q6: デプロイ形態**（`uvicorn 単体` / `gunicorn+uvicorn workers` / `コンテナ+K8s`）は推測で進めず、実装前に必ずユーザーへ確認する。トラフィック規模・運用チームの習熟度・既存インフラ（VM かコンテナオーケストレータか）によって最適解が変わるため。

## uvicorn による起動

FastAPI は ASGI アプリケーションであり、uvicorn がそれを実行する ASGI サーバーになる。

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

| フラグ | 用途 | 環境 |
|--------|------|------|
| `--reload` | ファイル変更を検知して自動再起動 | 開発専用（本番では絶対に使わない。ファイル監視のオーバーヘッドが乗る） |
| `--proxy-headers` | リバースプロキシ/ロードバランサからの `X-Forwarded-*` ヘッダを信頼する | 本番（プロキシ配下で必須。クライアントの実 IP・スキームを正しく解釈するため） |
| `--forwarded-allow-ips` | `--proxy-headers` を信頼するプロキシの IP を制限 | 本番（未指定だと全ソースを信頼してしまう） |
| `--workers N` | N 個のワーカープロセスを事前起動 | VM/ベアメタルで手軽に複数コアを使いたい場合 |

`--workers` は uvicorn 単体でも複数プロセスを起動できるが、クラッシュしたワーカーを自動再起動する仕組みは持たない。本格的なプロセス管理が必要な場合は「マルチプロセス構成」（gunicorn）か、コンテナオーケストレータにレプリカ管理を委ねる「Kubernetes デプロイ概要」のいずれかを選ぶ。

起動処理・終了処理は `lifespan` コンテキストマネージャに集約する（DB 接続プールの初期化、モデルのロード、バックグラウンドタスクの停止待ちなど）。

```python
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    # 起動処理: 接続プール初期化・モデルロード等
    yield
    # 終了処理: 接続クローズ・進行中タスクの待機等


app = FastAPI(lifespan=lifespan)
```

## マルチプロセス構成（gunicorn + uvicorn workers）

Python の GIL により、単一プロセスの uvicorn は CPU コアを1つしか使えない。単一ホスト上で複数コアを活用したい場合、gunicorn をプロセスマネージャとして使い、各ワーカーで uvicorn の ASGI 実装（`UvicornWorker`）を動かす。

```bash
gunicorn app.main:app \
    --workers 4 \
    --worker-class uvicorn.workers.UvicornWorker \
    --bind 0.0.0.0:8000 \
    --timeout 30 \
    --graceful-timeout 30
```

ワーカー数の目安は `(2 × CPU コア数) + 1`（メモリ使用量とレイテンシのバランスを見て調整する）。設定が増える場合は `gunicorn.conf.py` に切り出す。

```python
# gunicorn.conf.py
import multiprocessing

bind = "0.0.0.0:8000"
workers = multiprocessing.cpu_count() * 2 + 1
worker_class = "uvicorn.workers.UvicornWorker"
timeout = 30
graceful_timeout = 30
keepalive = 5
```

**コンテナ環境では別のアプローチを検討する**: コンテナ1つにつき uvicorn プロセス1つを起動し、複数コアの活用とプロセスの障害復旧はコンテナオーケストレータ（Kubernetes のレプリカ管理）に委ねる構成もよく使われる。gunicorn によるプロセス管理は VM・ベアメタル・単一ホストの docker compose 構成に向き、コンテナオーケストレータ配下では責務が重複しがちである。どちらを取るかは Q6 の確認結果に従う。

## Docker化

マルチステージビルドでビルド依存とランタイムを分離し、イメージサイズと攻撃対象領域を減らす。

```dockerfile
# syntax=docker/dockerfile:1

FROM python:3.13-slim AS builder

WORKDIR /app
RUN pip install --no-cache-dir uv

COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev --no-install-project

COPY . .
RUN uv sync --frozen --no-dev


FROM python:3.13-slim AS runtime

RUN useradd --create-home --shell /bin/bash appuser
WORKDIR /app

COPY --from=builder --chown=appuser:appuser /app /app
ENV PATH="/app/.venv/bin:$PATH"

USER appuser
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import httpx; httpx.get('http://localhost:8000/health').raise_for_status()"

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--proxy-headers"]
```

要点:

- **non-root ユーザー**: `USER appuser` でコンテナ内権限を最小化する（root での実行は脆弱性の影響範囲を広げる）
- **`--no-dev`**: 開発用依存（pytest 等）を本番イメージに含めない
- **`HEALTHCHECK`**: Docker/オーケストレータがコンテナの死活を判定する起点（後述の readiness/liveness probe と役割が重なる）
- **`.dockerignore`**: `__pycache__/`・`.venv/`・`.env`・`.git/`・`tests/` をビルドコンテキストから除外し、ビルド時間とイメージ汚染を防ぐ

Dockerfile の書き方全般のベストプラクティス（レイヤキャッシュ最適化・マルチアーキテクチャビルド等）は `cloud:practicing-devops` を参照。

単一ホストでの動作確認には Docker Compose が手早い。

```yaml
services:
  api:
    build: .
    ports:
      - "8000:8000"
    env_file: .env
    depends_on:
      db:
        condition: service_healthy
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
```

## 環境変数と Settings 管理

`pydantic-settings` の `BaseSettings` で環境変数を型安全に読み込む。ネストした設定はサブモデルに分割すると責務が明確になる。

```python
from functools import lru_cache
from typing import Literal

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class DatabaseSettings(BaseSettings):
    url: str = Field(..., alias="DATABASE_URL")
    pool_size: int = Field(default=10, ge=1)
    max_overflow: int = Field(default=5, ge=0)


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_nested_delimiter="__",
        case_sensitive=False,
    )

    environment: Literal["development", "staging", "production"] = "development"
    debug: bool = False
    secret_key: str = Field(..., min_length=32)
    database: DatabaseSettings

    @property
    def is_production(self) -> bool:
        return self.environment == "production"


@lru_cache
def get_settings() -> Settings:
    """設定をプロセス起動後1回だけ読み込みキャッシュする"""
    return Settings()
```

ハンドラからは他の依存性と同じく `Depends()` で受け取る（DI ファースト原則の一部、詳細は `references/DEPENDENCIES.md`）。

```python
from typing import Annotated

from fastapi import Depends

SettingsDep = Annotated[Settings, Depends(get_settings)]
```

運用上の注意:

- **`.env` はリポジトリにコミットしない**（`.gitignore` に必ず含める）。イメージに `.env` を焼き込むのも避ける
- **本番の秘密情報は環境変数の平文ファイルではなくシークレット管理機構から供給する**（クラウドのシークレットマネージャ、または後述の Kubernetes Secret）。秘密情報の取り扱い全般は `devkit:securing-code` を参照
- **テストでは `get_settings.cache_clear()` を呼び `dependency_overrides` で差し替える**（詳細は `references/TESTING.md`）。`lru_cache` を挟んだままテスト間で設定を共有すると意図しない値が残る

## パフォーマンス最適化

**最大の落とし穴は `async def` ハンドラ内でのブロッキング呼び出し**である。イベントループを1つのリクエストが専有している間、他の全リクエストの処理が止まる。

| ブロッキングの原因 | 対処 |
|-------------------|------|
| 同期 DB ドライバの呼び出し | 非同期ドライバ（asyncpg・motor 等）に置き換える |
| `time.sleep` | `asyncio.sleep` に置き換える |
| 同期 HTTP クライアント（`requests` 等） | `httpx.AsyncClient` に置き換える |
| CPU バウンドな処理（画像処理・重い計算） | `run_in_threadpool`（I/O バウンド寄り）やプロセスプールに切り出す。あるいはハンドラを `async def` ではなく `def` で定義し、FastAPI に自動でスレッドプール実行させる |

その他の最適化ポイント:

- **DB コネクションプール**: SQLAlchemy の `pool_size`/`max_overflow` を設定する。ワーカー数 × pool_size がデータベースの最大接続数を超えないよう調整する（後述の「スケーリング戦略」でレプリカ数を増やす際に特に注意）
- **レスポンス圧縮**: `GZipMiddleware` を追加し、大きな JSON レスポンスの転送量を減らす
- **高速な JSON シリアライズ**: 大きなペイロードが多いなら `default_response_class=ORJSONResponse` を検討する
- **キャッシュ**: 頻繁に読まれ更新頻度が低いデータは Redis 等でキャッシュする（cache-aside パターン。データアーキテクチャ全般は `cloud:architecting-data` を参照）
- **`uvicorn[standard]`**: `uvloop`・`httptools` を含む標準インストールを使うと、イベントループと HTTP パーサが高速化される（Linux/macOS）

## スケーリング戦略

**水平スケーリング**（プロセス/レプリカを増やす）が**垂直スケーリング**（1台のマシンを大きくする）より優先される。垂直スケーリングは単一障害点が残り、いずれハードウェアの上限に達する。水平スケーリングはステートレスな API であれば理論上いくらでも台数を増やせる。

水平スケーリングを機能させる前提は**ステートレス設計**である。

- リクエスト間で保持したい状態（セッション・レート制限カウンタ・キャッシュ）をアプリケーションプロセス内に置かない
- Redis や DB のような共有ストアに外部化し、どのレプリカがリクエストを受けても同じ結果になるようにする
- ロードバランサでの sticky session（特定レプリカへの固定）は極力避ける（ステートレス設計と矛盾し、負荷分散の効果を弱める）

レプリカを増やす際に見落としやすいのが**データベース接続数の乗算**である。1レプリカあたり `pool_size` 個の接続を持つ場合、レプリカ数 × `pool_size` がデータベースの `max_connections` を超えると新規接続がエラーになる。レプリカ数が多い構成では、アプリケーション側の `pool_size` を絞るか、PgBouncer 等のコネクションプーラをデータベースの前段に置いて接続を多重化する。

ロードバランサ（クラウドのマネージドロードバランサ、または Kubernetes の Service/Ingress）は複数レプリカの手前に立ち、ラウンドロビンやレイテンシベースでリクエストを振り分ける。ヘルスチェックに失敗したレプリカへのルーティングを自動的に止められる構成にしておく。

## Kubernetes デプロイ概要

Kubernetes を使う場合、gunicorn による1ホスト内のマルチプロセス管理ではなく、**コンテナ1つ=uvicornプロセス1つ**とし、レプリカ数の管理と障害復旧を Kubernetes に委ねる構成が一般的である。

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fastapi-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: fastapi-app
  template:
    metadata:
      labels:
        app: fastapi-app
    spec:
      containers:
        - name: api
          image: registry.example.com/fastapi-app:1.0.0
          ports:
            - containerPort: 8000
          envFrom:
            - configMapRef:
                name: fastapi-config
            - secretRef:
                name: fastapi-secrets
          readinessProbe:
            httpGet:
              path: /health
              port: 8000
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /health
              port: 8000
            initialDelaySeconds: 15
            periodSeconds: 20
          resources:
            requests:
              cpu: "250m"
              memory: "256Mi"
            limits:
              cpu: "1000m"
              memory: "512Mi"
---
apiVersion: v1
kind: Service
metadata:
  name: fastapi-app
spec:
  selector:
    app: fastapi-app
  ports:
    - port: 80
      targetPort: 8000
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: fastapi-app
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: fastapi-app
  minReplicas: 3
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

要点:

- **readinessProbe と livenessProbe の違い**: readiness は「今このレプリカにトラフィックを流してよいか」（失敗中は Service のルーティング先から外れる）、liveness は「このコンテナは生存しているか」（失敗するとコンテナが再起動される）。両者を同じ `/health` に向けても構わないが、DB 接続確認のように時間のかかるチェックは readiness 側に置き、liveness は軽量にする
- **ConfigMap と Secret**: 環境別の非機微な設定（`environment`・ログレベル等）は ConfigMap、`secret_key`・DB 接続文字列等の機微情報は Secret に分離する。上の「環境変数と Settings 管理」の `Settings` モデルはどちらから注入されたかを区別しない
- **resources.requests/limits**: リクエストはスケジューリングの基準、リミットは超過時のスロットリング/OOM Kill の基準。両方を設定しないとノードリソースを使い切って他ワークロードに影響しうる
- **HorizontalPodAutoscaler**: CPU 使用率（または独自メトリクス）に応じてレプリカ数を自動調整する。`minReplicas` は可用性の下限、`maxReplicas` はデータベース接続数等の上流制約から逆算する
- **ローリングアップデート**: Deployment の既定戦略はローリングアップデート（新しいレプリカが readiness を通過してから旧レプリカを終了）。ゼロダウンタイムデプロイの前提として、readinessProbe の正確さと `lifespan` の終了処理（進行中リクエストの完了待ち）が重要になる

K8s クラスタの構築・運用そのもの（マニフェスト管理、GitOps、クラスタのセキュリティ強化）は `cloud:practicing-devops` を参照。特定クラウドのマネージドコンピュート選択（ECS/Fargate/Lambda、Cloud Run/GKE 等）は `cloud:developing-aws`・`cloud:developing-google-cloud` を参照。

## 本番運用チェックリスト

- [ ] `--reload` を本番コマンドに残していないか
- [ ] リバースプロキシ配下で `--proxy-headers`（および許可 IP の制限）を設定しているか
- [ ] gunicorn/K8s のいずれかで、クラッシュしたワーカー/コンテナが自動的に復旧するか
- [ ] Dockerfile が non-root ユーザーで実行され、開発用依存を含んでいないか
- [ ] `.env`・秘密情報がイメージやリポジトリに含まれていないか
- [ ] `async def` ハンドラ内に同期ブロッキング呼び出しが残っていないか
- [ ] DB コネクションプールの合計サイズ（レプリカ数 × `pool_size`）がデータベースの上限を超えていないか
- [ ] `/health` 等のヘルスチェックエンドポイントが readiness/liveness probe から到達可能か
- [ ] ステートレス設計（セッション・キャッシュの外部化）が徹底されているか
- [ ] 本番運用の監視・ログ・アラート設計を別途行っているか（`cloud:implementing-observability` を参照）

## 関連スキルへの相互参照

- **`cloud:practicing-devops`**: CI/CD パイプライン設計、Dockerfile ベストプラクティス、IaC 全般
- **`cloud:developing-aws` / `cloud:developing-google-cloud`**: クラウド固有のコンピュート選択とマネージドサービス連携
- **`cloud:implementing-observability`**: 本番運用の監視・ログ・SLO 設計
- **`devkit:securing-code`**: 秘密情報管理・コンテナセキュリティ全般の強化
