# Dependency Injection 実践

## 目的

Dependency Injection（DI）は、クラスや関数が外部依存を自分で生成せず、外から受け取るための設計パターンです。目的は「DIコンテナを使うこと」ではなく、変更しやすく、テストしやすく、依存関係が公開APIから読み取れるコードにすることです。

DIで扱うべき依存は、実装差し替え・外部I/O・時間・乱数・設定・DB・HTTP・メッセージング・フレームワーク・ログ/計測などの揺らぎを持つ依存です。値オブジェクト、純粋関数、同じモジュール内の安定した実装まで機械的に注入すると、設計が重くなります。

---

## 判断フロー

1. **揺らぐ依存を特定する**: DB、HTTPクライアント、時刻、乱数、ファイル、環境変数、外部SDK、フレームワークAPIを洗い出す。
2. **利用側が欲しい抽象を定義する**: サードパーティAPIの形ではなく、利用側のユースケースに合わせた小さいインターフェースを作る。
3. **Constructor Injectionを既定にする**: 必須依存はコンストラクタ引数で受け取り、生成後は不変に保つ。
4. **Composition Rootで組み立てる**: `main`、`bootstrap`、`app factory`、NestJS module、Angular provider設定など、アプリ起動境界に生成処理を集約する。
5. **ライフタイムを明示する**: Singleton / Scoped / Transient のどれかを選び、短命依存を長命オブジェクトに閉じ込めない。
6. **テストで差し替える**: テスト用Fake/Stub/Mockを注入できるか確認する。グローバル状態のリセットに依存するテストは設計を見直す。
7. **コンテナは必要な時だけ使う**: オブジェクトグラフが小さいならPure DIで十分。コンテナを使う場合も、コンテナ参照はComposition Rootに閉じ込める。

---

## 基本パターン

### Composition Root

Composition Rootは、アプリケーション内で依存グラフを組み立てる単一の論理的な場所です。ここだけが具象実装、設定、ライフタイム、DIコンテナを知ってよい場所です。

| 場所 | 例 |
|------|----|
| CLI / Worker | `main.ts`, `main.py`, `bootstrap()` |
| Web API | `createApp()`, FastAPI app factory, NestJS root module |
| Frontend | Angular providers, React app initialization, feature bootstrap |
| Tests | fixture factory, test-specific app factory |

Composition Root以外のアプリケーションコードで `container.resolve()` / `getService()` / `Depends()` 相当を直接呼び出すと、依存が公開APIから見えなくなり、Service Locatorになります。

### Constructor Injection

必須依存はConstructor Injectionを既定にします。

- コンストラクタは依存の宣言と保存だけにする。
- 公開コンストラクタは1つに絞る。
- 依存フィールドは再代入しない。
- Null / None / undefined を許す設計にしない。
- 依存が多すぎる場合は、Property Injectionで隠さず、責務分割やDecorator化を検討する。

### Method Injection

依存が呼び出しごとに変わる場合、またはRepositoryから復元されたEntityのようにComposition Rootで生成されないオブジェクトへ一時的な協力者を渡す場合に使います。

適した例:

- 現在ユーザー、時刻、ロケールなど、操作ごとの文脈。
- Entityの特定メソッドだけで必要なDomain Service。
- プラグイン処理や画像処理など、呼び出しごとに文脈が変わる処理。

避ける例:

- 呼び出し側に関係ない実装詳細を全階層で引き回す。
- Composition Root内で作成済みオブジェクトを後から初期化する。

### Property / Setter Injection

Property Injectionは、再利用ライブラリが安全なLocal Defaultを持ち、利用者が任意で差し替えたい場合に限定します。アプリケーションの必須依存には使いません。

避ける理由:

- 依存を設定し忘れても生成できてしまう。
- 実行途中で依存を差し替えられる。
- 初期化順序に依存するTemporal Couplingを作る。
- 必須依存の多さを隠し、責務過多を見えにくくする。

### Decorator / Proxyによる横断的関心事

ログ、計測、キャッシュ、リトライ、認可、トランザクションなどは、対象サービスへ直接埋め込むよりDecorator / Proxyで包みます。

```text
UserRepository
  <- CachedUserRepository
  <- MeteredUserRepository
  <- RetryingUserRepository
```

横断的関心事をグローバルロガーやAmbient Contextで取り出すと、依存が隠れます。必要な場合も、Composition RootでDecoratorとして組み立てる方がテストしやすくなります。

---

## アンチパターン

| アンチパターン | 症状 | 修正 |
|---------------|------|------|
| Control Freak | サービス内部でDB/HTTP/SDKを `new` する | 抽象を受け取り、Composition Rootで具象を注入する |
| Service Locator | `container.resolve()` / `Locator.get()` を通常コードから呼ぶ | 依存をコンストラクタまたはメソッド引数に出す |
| Ambient Context | グローバルな現在ユーザー/時刻/DBセッションを読む | 文脈オブジェクトを明示的に渡す |
| Required Setter | 必須依存をプロパティで後入れする | Constructor Injectionへ移す |
| Constructor Over-Injection | コンストラクタ引数が多すぎる | 責務分割、Parameter Object、Decorator、Facadeを検討 |
| Captive Dependency | 長命オブジェクトが短命依存を保持する | ライフタイムを揃えるか、Factory/Scopeを使う |

---

## ライフタイム管理

| ライフタイム | 意味 | 適用例 | 注意 |
|--------------|------|--------|------|
| Singleton | アプリ期間で同じインスタンスを再利用 | stateless service, immutable config, thread-safe cache | リクエスト状態や非スレッドセーフ依存を持たせない |
| Scoped | リクエスト/ジョブ/トランザクションごとに再利用 | DB session, Unit of Work, request context | scope外へ漏らさない |
| Transient | 解決ごとに新規作成 | 状態を持つ短命サービス、安価なオブジェクト | disposable/resource管理を忘れない |

長命オブジェクトは依存を保持します。そのため、SingletonにScoped/Transientな状態ful依存を注入すると、短命であるはずの依存がアプリ全体に延命されます。これがCaptive Dependencyです。

---

## Pythonでの実践

### Pure DI + Protocol

Pythonでは、`typing.Protocol` で利用側が必要とする構造的な抽象を定義し、Bootstrap関数で具象実装を注入します。

```python
from typing import Protocol


class Mailer(Protocol):
    def send(self, to: str, subject: str, body: str) -> None: ...


class SignupService:
    def __init__(self, mailer: Mailer) -> None:
        self._mailer = mailer

    def welcome(self, email: str) -> None:
        self._mailer.send(email, "Welcome", "Thanks for signing up")


def build_signup_service() -> SignupService:
    mailer = SmtpMailer(host="smtp.example.com")
    return SignupService(mailer)
```

実装クラスが明示的に継承しなくても、必要なメソッドを満たせばProtocolに適合します。ドメイン層を軽く保ちたい場合は、ABCよりProtocolが自然です。実行時チェックが必要な場合は `@runtime_checkable` を検討します。

### FastAPI

FastAPIの `Depends` はHTTP境界の依存解決に使います。ドメインサービス自体は通常のConstructor Injectionで設計し、エンドポイントや依存関数で組み立てます。

```python
from typing import Annotated
from fastapi import Depends, FastAPI

app = FastAPI()


def get_user_repo() -> UserRepository:
    return SqlUserRepository(session_factory=get_session_factory())


def get_signup_service(
    repo: Annotated[UserRepository, Depends(get_user_repo)],
) -> SignupService:
    return SignupService(repo)


@app.post("/signup")
def signup(
    command: SignupCommand,
    service: Annotated[SignupService, Depends(get_signup_service)],
) -> None:
    service.signup(command)
```

テストでは `app.dependency_overrides` とpytest fixtureで差し替えます。DB接続やHTTPクライアントのようなリソースは、`yield` dependency または lifespan で開始/終了を管理します。

### dependency-injector / injector 系ライブラリ

PythonのDIライブラリを使う場合も、コンテナ定義とprovider overrideはComposition Rootまたはテスト境界に閉じ込めます。ドメインサービスがコンテナを受け取る設計にしてはいけません。

採用が向く場面:

- オブジェクトグラフが大きく、手動DIの重複が増えた。
- 設定、Factory、Resource、Scope管理を宣言的に扱いたい。
- テストでprovider単位のoverrideを標準化したい。

採用を見送る場面:

- 数個のサービスだけで構成できる。
- フレームワークがすでにDIを持っている。
- コンテナのauto-wiringで依存が見えにくくなる。

---

## TypeScriptでの実践

### Pure DI

TypeScriptでは、公開APIの型を明示し、Composition Rootで具象実装を組み立てます。小規模なNode.js/CLI/ライブラリでは、コンテナなしのPure DIが最も読みやすいことが多いです。

```typescript
export interface UserRepository {
  save(user: User): Promise<void>
}

export class SignupService {
  constructor(private readonly users: UserRepository) {}

  async signup(input: SignupInput): Promise<void> {
    await this.users.save(User.create(input))
  }
}

export function buildServices(config: AppConfig): SignupService {
  const users = new PostgresUserRepository(config.databaseUrl)
  return new SignupService(users)
}
```

`interface` は実行時に消えるため、コンテナで自動解決したい場合は runtime token が必要です。`symbol`、文字列リテラル、抽象クラス、ライブラリ固有のInjectionTokenを使い、型とtokenの対応をComposition Rootに寄せます。

### NestJS

NestJSでは `@Injectable()` とprovider登録を使います。アプリケーションサービスにはConstructor Injectionを使い、DB/外部SDKはcustom providerやadapterで包みます。

注意点:

- module/provider定義をComposition Rootとして扱い、ドメイン層にNestJS decoratorを広げない。
- interface注入はruntime tokenが必要。`@Inject(USER_REPOSITORY)` のような明示トークンを使う。
- request-scoped providerは必要な箇所だけに限定する。広げると性能と依存グラフが読みにくくなる。

### Angular

AngularではprovidersとInjectionTokenを使います。UIコンポーネントは画面の協調に集中させ、HTTPや永続化はserviceに閉じ込めます。

注意点:

- providerの階層によりインスタンス共有範囲が変わる。
- アプリ全体のSingleton serviceに、ルートやコンポーネント固有の状態を不用意に持たせない。
- InjectionTokenには用途が分かる名前を付け、設定値や抽象サービスを型安全に表現する。

### Inversify / TSyringe

InversifyやTSyringeはdecorator metadataを前提にする構成が多く、`reflect-metadata` や `experimentalDecorators` / `emitDecoratorMetadata` の設定確認が必要です。ライブラリを導入する前に、プロジェクトがdecorator前提を受け入れているか確認します。

採用が向く場面:

- Node.jsアプリでprovider数が多く、ライフタイムやauto-wiringを標準化したい。
- テストで登録差し替えを統一したい。
- 既存コードがdecoratorを許容している。

避ける場面:

- ドメイン層をフレームワーク非依存に保ちたい。
- bundle sizeや起動時間を抑えたいfrontend。
- runtime tokenやmetadata設定の複雑さが、手動DIより大きい。

---

## コンテナ採用基準

| 状況 | 推奨 |
|------|------|
| 小規模アプリ、依存が少ない | Pure DI |
| フレームワークが標準DIを持つ | フレームワークDIを境界で使う |
| 大規模アプリで登録・ライフタイム管理が増えた | DIコンテナをComposition Rootで使う |
| テスト容易性だけが目的 | まずConstructor InjectionとFakeで十分か確認 |
| ドメイン層を再利用したい | ドメインはコンテナ非依存に保つ |

コンテナ導入は設計を良くする魔法ではありません。悪い依存方向、巨大サービス、循環依存、グローバル状態は、コンテナ導入後も悪いままです。

---

## レビュー用チェックリスト

- [ ] 必須依存がコンストラクタで明示されている。
- [ ] 具象実装への依存がComposition Rootまたはadapter層に閉じている。
- [ ] 通常コードがDIコンテナやService Locatorを直接呼んでいない。
- [ ] Method Injectionは呼び出しごとの文脈に限定されている。
- [ ] Property Injectionは任意の拡張点かつLocal Defaultを持つ場合に限定されている。
- [ ] ライフタイムが明示され、Captive Dependencyがない。
- [ ] 時刻・乱数・外部I/Oはテストで差し替え可能。
- [ ] 横断的関心事はDecorator / Proxy / middleware / interceptorで扱われている。
- [ ] PythonではProtocol/ABCとBootstrap関数、FastAPIでは `Depends` / `dependency_overrides` の境界が明確。
- [ ] TypeScriptではruntime token、provider scope、decorator metadata前提が明確。

---

## 公式リファレンス

- Python `typing.Protocol`: <https://docs.python.org/3/library/typing.html#typing.Protocol>
- FastAPI dependencies: <https://fastapi.tiangolo.com/tutorial/dependencies/>
- FastAPI testing dependency overrides: <https://fastapi.tiangolo.com/advanced/testing-dependencies/>
- Dependency Injector providers: <https://python-dependency-injector.ets-labs.org/providers/index.html>
- TSyringe README: <https://github.com/microsoft/tsyringe>
- Inversify getting started: <https://inversify.io/docs/introduction/getting-started/>
- NestJS providers: <https://docs.nestjs.com/providers>
- Angular dependency providers: <https://angular.dev/guide/di/dependency-injection-providers>
