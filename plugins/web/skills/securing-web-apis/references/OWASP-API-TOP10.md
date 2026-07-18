# OWASP API Security Top 10 (2023) 脆弱性カタログ

OWASP API Security Top 10 (2023) が定義する10種類のAPI脆弱性を、検出シグナル・悪用パターン・修正パターンの観点でまとめる。Webアプリケーション向けのOWASP Top 10（SQLi・XSS等の汎用的な脆弱性）とは異なり、API固有の設計・認可・運用に根ざしたリスクを扱う。コード例はFastAPI+SQLAlchemy相当の疑似コードで統一しており、脆弱パターンと修正パターンを対で示す。

10項目は大きく「認可系」（誰が何にアクセスできるか）と「リソース・設定・運用系」（システムがどう構成・運用されているか）の2系統に分けられる。

## 認可系の脆弱性

### 1. BOLA (Broken Object-Level Authorization)

**概要**: リソースIDだけで検索し、リクエストしたユーザーがそのリソースの所有者かどうかを確認しないために起きる。Insecure Direct Object Reference (IDOR) とも呼ばれる旧称で、同じ問題を指す。

**検出シグナル**:
- データベースクエリの`WHERE`条件がリソースIDのみで、ユーザーID/テナントIDを含まない
- パスパラメータ（`/orders/{id}`等）や連番IDをそのままクエリキーに使っている
- 認証（authentication）はあるが認可（authorization）チェックが別工程として存在しない
- レスポンス内容やレイテンシがリソースの存在有無によって変わり、サイドチャネル的に列挙が可能

**悪用例**:
```python
# 脆弱: 所有者チェックがなく、有効なorder_idを知っていれば誰でも閲覧できる
@app.get("/orders/{order_id}")
def get_order(order_id: int, user=Depends(authenticate)):
    order = db.query(Order).filter(Order.id == order_id).first()
    return order

# 安全: クエリ条件に所有者(user.sub)を追加する
@app.get("/orders/{order_id}")
def get_order(order_id: int, user=Depends(authenticate)):
    order = db.query(Order).filter(
        Order.id == order_id, Order.user_id == user.sub
    ).first()
    if order is None:
        raise HTTPException(status_code=404)
    return order
```

**修正パターン**:
- すべてのリソースアクセスに「所有者/テナント一致」条件をクエリレベルで必須化する
- リソースの存在有無を隠したい場合は`404`、既知のリソースへの権限不足を示してよい場合は`403`を返す（下表）
- レスポンス時間が一定になるよう配慮し、タイミング攻撃によるリソース列挙を防ぐ
- 全エンドポイントを対象にBOLAの手動/自動テストを定期実施する

| 状況 | 返すべきステータス | 理由 |
|------|------------------|------|
| リソースの存在自体を隠したい（機密性が高い） | `404 Not Found` | 存在の有無を漏らさない |
| リソースの存在を知らせてよい（例: 同一組織内チケット） | `403 Forbidden` | ユーザーに次のアクション（アクセス申請等）を促せる |

### 2. Broken Authentication

**概要**: 認証フロー（ログイン・トークン発行・トークン検証）の実装不備により、他ユーザーへのなりすましやトークン偽造が可能になる。

**検出シグナル**:
- 弱いパスワードポリシー、ブルートフォース対策の欠如
- ログインで自前実装の認証システムを使っている（IDaaS/OIDCプロバイダ未使用）
- JWT検証時に`aud`（audience）や`iss`（issuer）クレームを検証していない
- JWTの`alg`フィールドの値を大文字小文字を区別せず検証している、または`none`アルゴリズムを許容している
- アクセストークンやパスワードなどの機密情報をURLクエリパラメータに含めている（ブラウザ履歴・アクセスログに残る）
- パスワード確認なしにメールアドレス・パスワードなどの機微情報を変更できる

**悪用例**:
```python
# 脆弱: audクレームを検証しないため、他API向けに発行されたトークンも通ってしまう
token = jwt.JWT(key=public_key, jwt=raw_token, algs=["RS256"])
claims = token.claims

# 安全: 想定するaudience/issuerを明示的に検証する
token = jwt.JWT(
    key=public_key, jwt=raw_token, algs=["RS256"],
    check_claims={
        "aud": "https://api.example.com/admin",
        "iss": "https://auth.example.com/",
    },
)
claims = token.claims
```

**修正パターン**:
- 認証は自前実装せず、外部IdP（OAuth 2.0/OIDC準拠のIdentity as a Serviceプロバイダ）を利用する（詳細は`AUTHN-AUTHZ.md`参照）
- トークン検証では署名アルゴリズム・`aud`・`iss`・有効期限のすべてを明示的に検証する
- ログイン試行回数の制限・多要素認証（MFA）の推奨・CAPTCHAをログインなど機微エンドポイントに適用する
- 機密情報はリクエストボディまたは`Authorization`ヘッダーで渡し、URLには含めない

### 3. BOPLA (Broken Object Property Level Authorization)

**概要**: 2023年版で新設されたカテゴリで、2019年版の「Mass Assignment」と「Excessive Data Exposure」を統合したもの。ユーザーが変更すべきでないプロパティを上書きする（mass assignment）か、不要な情報が漏れる（excessive data exposure）かの2つの側面を持つ。

#### 3a. Mass Assignment

**検出シグナル**:
- リクエストボディをそのままORMモデルにアンパックしている（`Model(**payload)`のようなパターン）
- 入力用スキーマと出力用スキーマが同一で、`status`・`role`・`is_admin`のようなサーバー管理項目も書き込み可能に見える

**悪用例**:
```python
# 脆弱: リクエストJSONをそのままDBモデルへ束縛するため、statusも上書きできる
@app.post("/payments")
async def create_payment(request: Request):
    payload = await request.json()
    payment = Payment(**payload)  # {"amount": ..., "status": "accepted"} を送れば承認済み扱いにできる
    db.add(payment)
    db.commit()
    return payment

# 安全: 入力専用スキーマで受け付ける属性を限定する
class CreatePaymentInput(BaseModel):
    amount: float
    currency: str

@app.post("/payments")
def create_payment(input: CreatePaymentInput):
    payment = Payment(**input.dict())  # statusはサーバー側の初期値のみ
    db.add(payment)
    db.commit()
    return payment
```

#### 3b. Excessive Data Exposure

**検出シグナル**:
- レスポンスがDBモデルをほぼそのままシリアライズしている（内部専用フィールド・他ユーザーの内部IDを含む）
- スコープ（同一組織/プロジェクト等）を問わず、識別子（メールアドレス等）だけで他ユーザーの情報を検索できる
- クライアント側でのフィルタリングを前提に、本来非公開のオブジェクトをAPIレスポンスへ丸ごと含めている

**悪用例**:
```python
# 脆弱: 所属組織を問わず、メールアドレスだけで誰でも検索できる
@app.get("/users/lookup")
def lookup(email: str, user=Depends(authenticate)):
    target = db.query(User).filter(User.email == email).first()
    return target

# 安全: 呼び出し元と同じスコープ(組織/プロジェクト)に限定する
@app.get("/users/lookup")
def lookup(email: str, user=Depends(authenticate)):
    target = db.query(User).filter(
        User.email == email, User.org_id == user.org_id
    ).first()
    if target is None:
        raise HTTPException(status_code=404)
    return target
```

**修正パターン**（mass assignment / excessive data exposure共通）:
- 入力用スキーマ（許可属性のみ受け付ける）と出力用スキーマ（公開してよいフィールドのみ返す）を必ず分離する
- サーバー管理フィールド（status、role、price、loyalty pointsなど）はAPI経由での直接書き込みを禁止し、専用の内部処理でのみ変更する
- レスポンスは「必要最小限の原則」でフィールドを絞り、内部データモデルをAPIレスポンスへ直接露出しない
- 他ユーザーのレコードを検索・参照するエンドポイントには、常にスコープ（テナント/組織/プロジェクト）条件を付与する

### 4. Unrestricted Resource Consumption

**概要**: リクエスト数・計算量・ペイロードサイズに制限がなく、サービス拒否（DoS/DDoS）やブルートフォース攻撃、クラウド従量課金の高騰（denial-of-wallet攻撃）を招く。

**検出シグナル**:
- ログイン・パスワードリセットなど機微なエンドポイントにレート制限がない
- 全エンドポイントに一律のレート制限ポリシーしか設定していない（CPU/データ集約的な処理には別枠の制限が必要）
- サーバーレス関数やオートスケール基盤に上限（同時実行数・支出アラート）を設定していない
- リクエストボディサイズ・ページネーションの上限・タイムアウトが未設定

**悪用例**:
```python
# 脆弱: ログイン試行回数を一切制限していない
@app.post("/login")
def login(body: LoginInput):
    user = find_user(body.email, body.password)
    if user is None:
        raise HTTPException(status_code=401)
    return issue_token(user)

# 安全: IPとアカウント単位で試行回数を追跡し、閾値超過時に制限する
@app.middleware("http")
async def rate_limit_login(request: Request, call_next):
    if request.url.path == "/login":
        ip = request.client.host
        email = await extract_email(request)
        if ip in blocked_ips or email in locked_accounts:
            return JSONResponse(status_code=429, content={"error": "rate limited"})
        attempts_by_ip[ip] += 1
        attempts_by_account[email] += 1
        if attempts_by_ip[ip] >= MAX_ATTEMPTS:
            blocked_ips.add(ip)
        if attempts_by_account[email] >= MAX_ATTEMPTS:
            locked_accounts.add(email)
    return await call_next(request)
```

**修正パターン**:
- エンドポイントの性質に応じてレート制限のしきい値を分ける（下表）
- IP・アカウント・セッションID・デバイスフィンガープリントを組み合わせて追跡する（velocity check）
- クラウド支出に上限アラートを設定し、denial-of-wallet攻撃による予期しない課金を早期検知する
- WAFやDoS対策サービス（マネージドの異常検知・自動レート制限機能を持つもの）を多層防御の一部として使う

| エンドポイントの性質 | 推奨されるレート制限方針 |
|---------------------|------------------------|
| ログイン・パスワードリセット等の認証系 | 厳格な試行回数制限＋アカウントロック＋CAPTCHA |
| CPU/データ集約的な処理（レポート生成等） | 低いしきい値・キューイングまたは非同期化 |
| 通常の読み取り系エンドポイント | ユーザー体験を損なわない緩やかな制限 |

### 5. BFLA (Broken Function-Level Authorization)

**概要**: ロール（管理者・一般ユーザー等）ごとに区分されるべき機能へのアクセス制御が欠落し、権限のないユーザーが本来アクセスできない機能を実行できる。BOLAが「同一ロール内の他ユーザーのデータ」への横方向のアクセス（horizontal privilege escalation）であるのに対し、BFLAは「上位ロールの機能」への縦方向のアクセス（vertical privilege escalation）である点が異なる。

**検出シグナル**:
- 管理者用エンドポイントにロールチェックが実装されていない、または「隠しておけば安全」という前提（security through obscurity）に依存している
- ロール・権限情報がアクセストークンのクレームに含まれているのに、サーバー側でそれを検証していない
- 管理者用APIが専用サブドメイン/パスに分離されているだけで、認可チェックはアプリケーション全体で共通のミドルウェアに任されている

**悪用例**:
```python
# 脆弱: ロールチェックがなく、認証済みなら誰でも管理API を呼べる
@app.get("/admin/users")
def list_all_users(user=Depends(authenticate)):
    return db.query(User).all()

# 安全: アクセストークンのpermissions/rolesクレームを検証する
@app.get("/admin/users")
def list_all_users(user=Depends(authenticate)):
    if "admin" not in user.permissions:
        raise HTTPException(status_code=403)
    return db.query(User).all()
```

**修正パターン**:
- ユーザーのロール・権限をアクセストークンのクレームとして明示的に発行する（RBACの実装、詳細は`AUTHN-AUTHZ.md`参照）
- すべての機能（エンドポイント・操作）に対して、要求されるロール・権限を明示的に検証する。「管理者用サブドメインだから安全」という前提は置かない
- 機密性の高い管理機能を隠したい場合は、認可失敗時に`404`を返して存在自体を秘匿することも検討する

### 6. Unrestricted Access to Sensitive Business Flows

**概要**: 技術的には正しく実装されているビジネスフロー（購入・レビュー投稿・友人紹介プログラム等）が、自動化されたアクセス（ボット）によって本来の想定を超えて悪用される。認可の欠落ではなく、ビジネスロジックが「悪意ある人間的でない反復操作」を想定していないことが原因。

**検出シグナル**:
- 在庫確認・購入・チェックアウトのフローに、人間による操作かどうかを判定する仕組み（CAPTCHA・User-Agent検証等）がない
- 同一ユーザー/デバイスによる短時間の反復操作（連続購入、大量レビュー投稿、大量紹介登録等）を検知・制限していない
- 友人紹介プログラムなどの報酬系フローで、招待先アカウントの実在性・正当性を検証していない
- 業務上想定されるユーザーの行動パターン（閲覧→カート追加→購入までの所要時間等）からの逸脱を監視していない

**悪用例**:
```python
# 脆弱: 在庫確認から購入までに速度制限も人間検証もない
@app.post("/checkout")
def checkout(ticket_id: str, user=Depends(authenticate)):
    return purchase(ticket_id, user)

# 安全: 簡易ボット対策とユーザー単位のクールダウンを課す
@app.middleware("http")
async def guard_checkout(request: Request, call_next):
    if request.url.path == "/checkout":
        if not looks_like_browser(request.headers.get("user-agent", "")):
            return JSONResponse(status_code=401, content={"error": "unauthorized"})
        user_id = current_user_id(request)
        if purchased_within(user_id, hours=24):
            return JSONResponse(status_code=409, content={"error": "conflict"})
    return await call_next(request)
```

**修正パターン**:
- スカルピング（在庫の買い占め）・レビュー不正操作・紹介プログラム悪用・コンテンツスクレイピングなど、自社ビジネスモデル固有の悪用シナリオを洗い出す
- 自動化されたアクセスに対してCAPTCHAやUser-Agent検証などの一次防御を設ける（ただし単独では不十分）
- 想定されるユーザー行動のタイミング・頻度から逸脱するパターンをリアルタイムで検知し、スロットリングまたはブロックする
- 正当なパートナー（業務提携先）による自動アクセスが必要な場合は、専用のAPIキー発行とAPI利用の詳細な監査ログで対応する

## リソース・設定・運用系の脆弱性

### 7. SSRF (Server-Side Request Forgery)

**概要**: ユーザーが指定したURLをサーバー側がそのまま呼び出してしまうことで、内部ネットワークや外部サービスへの不正なリクエストを引き起こす。アバターURL設定やWebhook登録機能が典型的な攻撃経路になる。

**検出シグナル**:
- ユーザー入力のURLを検証なしに`requests.get(url)`のような形でそのまま呼び出している
- 内部専用エンドポイント（管理API、クラウドのメタデータサービス等）へのアクセスを遮断していない
- Webhook・アバターURL・外部連携設定などの機能でURLの宛先を制限していない

**悪用例**:
```python
# 脆弱: ユーザー指定URLをそのまま呼び出すため、内部ネットワークやクラウドメタデータサービスへの到達に使われる
@app.get("/webhook-test")
def call_url(url: str):
    return requests.get(url).content

# 安全: 内部アドレス・クラウドメタデータエンドポイントをdenylistで遮断する
BLOCKED_HOSTS = {"localhost", "127.0.0.1", "169.254.169.254"}

@app.get("/webhook-test")
def call_url(url: str):
    host = urlparse(url).hostname
    if host in BLOCKED_HOSTS or is_private_ip(host):
        raise HTTPException(status_code=422, detail="forbidden destination")
    return requests.get(url, timeout=3).content
```

**修正パターン**:
- ユーザー指定URLの宛先を許可できる範囲に応じて、allowlist（アバターURL等、少数の信頼済みドメインのみ許可）またはdenylist（Webhook等、任意URLが必要だが内部宛先だけは遮断）を使い分ける（下表）
- クラウドのインスタンスメタデータサービス（AWS EC2 IMDS等）のような高価値な内部エンドポイントは必ず遮断対象に含める。IMDSv2のようなトークン必須方式が利用可能なら有効化する
- 可能であれば、外部URL呼び出し用のサンドボックス環境や、リクエストの妥当性を検査するアウトバウンドプロキシを経由させる
- SSRFは完全な防止が難しい前提を持ち、多層防御（ネットワーク分離＋アプリ層検証＋監視）で臨む

| ユーザー入力URLの用途 | 推奨戦略 |
|---------------------|---------|
| アバター画像URLなど、少数の信頼済みドメインで足りる場合 | allowlist（許可ドメインのみ受け付け） |
| Webhookなど、任意の外部URLを許可する必要がある場合 | denylist＋プライベートIP/メタデータエンドポイントの遮断 |

### 8. Security Misconfiguration

**概要**: サービスの設定不備（デバッグモードの有効化、内部APIの誤公開、シークレットのハードコードなど）により、意図せず内部情報や機密情報が露出する。

**検出シグナル**:
- 本番環境でデバッグモードが有効になっており、エラー時にスタックトレースがそのままレスポンスに含まれる
- 内部専用API・管理画面が誤って公開ネットワークからアクセス可能になっている
- APIキーやシークレットがクライアントサイドのコード（Webアプリのバンドル等）に直接埋め込まれている
- CORS設定が過度に緩い（`Access-Control-Allow-Origin: *`を認証付きエンドポイントに適用している等）
- ソート・フィルタなどのクエリパラメータをそのままSQL文へ埋め込み、存在しないカラム名を渡すとエラーとして内部情報が漏れる

**悪用例**:
```python
# 脆弱: 本番でdebugモードが有効なままスタックトレースを露出し、
# order_byにDBカラム名以外を渡すと内部エラー詳細が丸見えになる
app = FastAPI(debug=True)

@app.get("/users")
def list_users(order_by: str = "email"):
    return db.query(User).order_by(text(order_by)).all()

# 安全: debugを無効化し、許可された並び替えキーのみ受け付ける
app = FastAPI(debug=False)

class OrderBy(str, Enum):
    email = "email"
    created_at = "created_at"

@app.get("/users")
def list_users(order_by: OrderBy = OrderBy.email):
    return db.query(User).order_by(order_by.value).all()
```

**修正パターン**:
- 全環境でデバッグモードを明示的に無効化し、フレームワークのデフォルト値に依存しない
- Infrastructure as Code (IaC) で設定を一元管理し、手動変更を許さないデプロイパイプラインを構築する
- 「スタックトレースが漏れていないか」「CORSヘッダーが適切か」等を検証するスモークテストをデプロイごとに実行する
- ユーザー入力を直接SQL文やソートキーへ埋め込まず、許可された値のenum等で制約する
- シークレットは環境変数やシークレット管理サービスで扱い、クライアントコードやリポジトリへ絶対に含めない

### 9. Improper Inventory Management

**概要**: APIのバージョン・エンドポイント・環境・ドキュメントの管理が不十分なために、退役済みのはずのAPI（zombie API）や未把握のAPI（shadow API）が攻撃対象領域として残ってしまう。

**検出シグナル**:
- 新バージョンをリリースした後も、旧バージョンの実際のデプロビジョニング（退役）が手作業のまま放置されている
- ドキュメント化・監視・品質チェックを経ずにリリースされたAPI（shadow API）が存在する
- APIゲートウェイ等でバージョン・エンドポイントの一覧を一元管理しておらず、実際に公開されているAPIの全体像を把握できていない
- 廃止予告のための標準ヘッダー（`Deprecation`・`Sunset`）を使っていない

**修正パターン**:
- バージョンのライフサイクル管理を自動化し、退役作業を手作業に依存させない（下表）
- APIゲートウェイ・WAFで、公開してよいバージョン・エンドポイントを明示的に制限する
- ネットワークトラフィックを継続的に監視し、ドキュメント化されていないエンドポイント（shadow API）を検出する仕組みを導入する
- APIカタログ・インベントリを常に最新化し、「今どのAPIが何を公開しているか」を一元的に把握できるようにする

| ライフサイクルの段階 | 対応 | 使用ヘッダー |
|---------------------|------|------------|
| 新バージョン公開 | v2を公開し、v1は稼働継続 | - |
| 廃止予告 | v1に廃止予定日・退役予定日を明示 | `Deprecation`, `Sunset`, `Link` |
| 退役 | v1を実際にデプロビジョニングし、再公開を防止 | - |

### 10. Unsafe Consumption of APIs

**概要**: 自社が呼び出す側の第三者API・内部APIからの応答を無条件に信頼することで、その応答に含まれる不正なデータがSQLインジェクションやXSS、あるいは処理の異常終了を引き起こす。

**検出シグナル**:
- 外部APIのレスポンス値を、検証なしにSQL文へ直接埋め込んでいる（文字列フォーマットによるクエリ構築）
- 外部APIから取得した文字列を、サニタイズなしにHTML・フロントエンドへ直接描画している（XSS経路）
- 外部APIが失敗・タイムアウト・不正な形式のレスポンスを返した場合の処理（サーキットブレーカー等）が実装されていない
- 外部APIのレスポンスに対する自前のバリデーションスキーマが存在しない

**悪用例**:
```python
# 脆弱: 外部APIの応答を無検証でSQL文字列に埋め込む
status = requests.get(external_url).json()["status"]
db.execute(text(
    f"UPDATE account SET status = '{status}' WHERE id = '{account_id}'"
))

# 安全: 許可値のenumで検証してからパラメータ化クエリに渡す
class AccountStatus(str, Enum):
    active = "active"
    suspended = "suspended"
    pending = "pending"

payload = AccountStatus(requests.get(external_url).json()["status"])
db.execute(
    text("UPDATE account SET status = :status WHERE id = :id"),
    {"status": payload.value, "id": account_id},
)
```

**修正パターン**:
- 外部API（内部・第三者を問わず）からのレスポンスは常に「信頼できない入力」として扱い、自前のバリデーションモデル（OpenAPI仕様がある場合はそこから導出したスキーマ）で検証する
- 検証に失敗したレスポンスは処理を中断し、エラーとしてログに残す（`500`または`400`を返す）
- データベースクエリは必ずパラメータ化し、外部API由来の値を文字列フォーマットでSQL文に埋め込まない
- フロントエンドへ描画する外部由来の文字列はサニタイズ、またはコンテンツセキュリティポリシー（CSP）で軽減する
- 外部API依存先の障害がカスケード障害を起こさないよう、サーキットブレーカーパターンとグレースフルデグラデーションを実装する
