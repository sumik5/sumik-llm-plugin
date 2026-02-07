---
name: designing-web-apis
description: "Guides Web API design with best practices for endpoints, responses, HTTP spec usage, versioning, and security. Use when designing REST-style HTTP APIs, creating new endpoints, or reviewing API architecture. For framework-specific API implementation (Express, NestJS, FastAPI), use the respective framework skill instead."
---

# Web API Design

このスキルは、Web API設計のベストプラクティスを網羅します。エンドポイント設計、レスポンスデータ構造、HTTP仕様活用、バージョニング、セキュリティの5つの柱で構成されています。

## 対象読者

このスキルは以下の2つのユースケースを想定しています:

- **LSUDs（Large Set of Unknown Developers）**: 不特定多数の開発者向けAPI（公開API、パートナーAPI等）
- **SSKDs（Small Set of Known Developers）**: 特定の開発者向けAPI（社内API、マイクロサービス間API等）

設計の厳密さはターゲットに応じて調整しますが、基本原則は共通です。

---

## 二つの根本原則

Web API設計における判断は、以下の優先順位に従います:

1. **仕様が決まっているものに関しては仕様に従う**
   - HTTP仕様（RFC 9110等）で定義されている事項は仕様通りに実装
   - 例: ステータスコード、HTTPメソッドのセマンティクス、ヘッダー

2. **仕様が存在していないものに関してはデファクトスタンダードに従う**
   - 業界で広く採用されている慣習を優先
   - 例: JSON形式、RESTful URI設計、OAuth 2.0

---

## コア原則

### 1. エンドポイント設計の原則

#### 覚えやすく、機能がひと目でわかるURI

優れたURIの6つの特徴:

| 特徴 | 説明 | 例 |
|------|------|-----|
| **短く入力しやすい** | タイプしやすい長さと文字 | `/v1/users` |
| **人間が読んで理解できる** | 一目で意味が分かる | `/v1/orders/:id` |
| **小文字統一** | 大文字小文字を混在させない | `/v1/products`（❌ `/v1/Products`） |
| **Hackable** | パスを削ると上位リソースになる | `/v1/users/123/orders/456` → `/v1/users/123/orders` |
| **サーバ側アーキテクチャ非反映** | 実装詳細を隠蔽 | `/v1/items`（❌ `/cgi-bin/get_items.php`） |
| **ルール統一** | API全体で一貫性を保つ | 複数形統一、動詞不使用 |

#### リソース指向設計

Web APIはリソースを中心に設計します:

- **リソース名は複数形の名詞**を使用（`/users`, `/orders`, `/products`）
- **HTTPメソッドで操作を表現**（URI中に動詞を含めない）

基本パターン:

| 目的 | エンドポイント | HTTPメソッド | 説明 |
|------|--------------|-------------|------|
| 一覧取得 | `/v1/resources` | GET | リソースのコレクション取得 |
| 新規登録 | `/v1/resources` | POST | 新しいリソースを作成 |
| 個別取得 | `/v1/resources/:id` | GET | 特定リソースの詳細取得 |
| 更新（全体） | `/v1/resources/:id` | PUT | リソースの完全置換 |
| 更新（部分） | `/v1/resources/:id` | PATCH | リソースの部分更新 |
| 削除 | `/v1/resources/:id` | DELETE | リソースの削除 |

#### リレーションシップの表現

親子関係やリソース間の関連は、ネストしたURIで表現します:

```
GET  /v1/users/123/orders          # ユーザー123の注文一覧
POST /v1/users/123/orders          # ユーザー123の新規注文
GET  /v1/users/123/orders/456      # ユーザー123の注文456
```

**ネストは2階層まで**を推奨。深すぎるネストは避け、クエリパラメータで代替します:

```
❌ /v1/users/123/orders/456/items/789
✅ /v1/order-items/789?order_id=456
```

---

### 2. レスポンス設計の原則

#### JSONをデフォルト

- 現在のWeb APIのデファクトスタンダードはJSON
- `Content-Type: application/json` を使用
- 他フォーマット（XML等）が必要な場合のみ、`Accept`ヘッダーでネゴシエーション

#### 不要なエンベロープで包まない

データを余計なラッパーで包まず、直接返します:

```json
✅ Good:
[
  {"id": 1, "name": "Alice"},
  {"id": 2, "name": "Bob"}
]

❌ Bad:
{
  "response": {
    "data": [
      {"id": 1, "name": "Alice"},
      {"id": 2, "name": "Bob"}
    ]
  }
}
```

例外: ページネーション情報やメタデータが必要な場合は最小限のラッパーを使用:

```json
{
  "items": [...],
  "page": 1,
  "per_page": 20,
  "total": 100
}
```

#### フラットな構造

深いネストを避け、可能な限りフラットな構造にします:

```json
✅ Good:
{
  "id": 1,
  "name": "Alice",
  "city": "Tokyo",
  "country": "Japan"
}

❌ Bad:
{
  "id": 1,
  "name": "Alice",
  "address": {
    "location": {
      "city": "Tokyo",
      "country": "Japan"
    }
  }
}
```

#### 命名規則の統一

API全体で統一した命名規則を使用します:

- **camelCase**: JavaScript/TypeScript系で一般的（`userId`, `createdAt`）
- **snake_case**: Python/Ruby系で一般的（`user_id`, `created_at`）

どちらを選んでも構いませんが、**API全体で統一すること**が重要です。

#### エラーレスポンス

エラーは適切なHTTPステータスコードと詳細情報を返します:

```json
{
  "code": "VALIDATION_ERROR",
  "message": "Invalid input parameters",
  "details": [
    {
      "field": "email",
      "issue": "Invalid email format"
    }
  ]
}
```

必須フィールド:
- `code`: エラーの種類を識別する文字列（例: `VALIDATION_ERROR`, `NOT_FOUND`）
- `message`: 人間が読める説明

推奨フィールド:
- `details`: エラーの詳細情報（配列）
- `request_id`: トレーシング用のリクエストID

---

### 3. HTTP仕様活用の原則

#### 適切なステータスコード

HTTPステータスコードを正しく使用します:

| カテゴリ | 主な用途 | 代表例 |
|---------|---------|--------|
| **2xx 成功** | リクエストが正常に処理された | 200 OK, 201 Created, 204 No Content |
| **3xx リダイレクト** | リソースの移動 | 301 Moved Permanently, 304 Not Modified |
| **4xx クライアントエラー** | リクエストに問題がある | 400 Bad Request, 401 Unauthorized, 404 Not Found |
| **5xx サーバエラー** | サーバ側で問題が発生 | 500 Internal Server Error, 503 Service Unavailable |

よく使うステータスコード:

```
200 OK              - GET/PUT/PATCHの成功
201 Created         - POSTでリソース作成成功
204 No Content      - DELETEの成功（レスポンスボディなし）
400 Bad Request     - 入力パラメータ不正
401 Unauthorized    - 認証が必要/失敗
403 Forbidden       - 認証済みだが権限不足
404 Not Found       - リソースが存在しない
422 Unprocessable Entity - バリデーションエラー
500 Internal Server Error - サーバ内部エラー
503 Service Unavailable - サーバメンテナンス中
```

#### キャッシュの活用

パフォーマンス向上のため、適切なキャッシュヘッダを設定します:

**条件付きリクエスト（Conditional Requests）:**

```http
# サーバ → クライアント（初回）
ETag: "abc123"
Last-Modified: Wed, 01 Feb 2024 12:00:00 GMT

# クライアント → サーバ（2回目）
If-None-Match: "abc123"
If-Modified-Since: Wed, 01 Feb 2024 12:00:00 GMT

# サーバ → クライアント（変更なし）
304 Not Modified
```

**キャッシュ制御:**

```http
Cache-Control: max-age=3600, public    # 1時間キャッシュ可能（共有キャッシュOK）
Cache-Control: max-age=3600, private   # 1時間キャッシュ可能（プライベートのみ）
Cache-Control: no-cache                # 都度検証が必要
Cache-Control: no-store                # キャッシュ禁止
```

#### CORS対応

クロスオリジンリクエストに対応するため、適切なCORSヘッダを設定します:

```http
Access-Control-Allow-Origin: https://example.com
Access-Control-Allow-Methods: GET, POST, PUT, DELETE, PATCH
Access-Control-Allow-Headers: Content-Type, Authorization
Access-Control-Max-Age: 86400
```

#### メディアタイプ

適切な`Content-Type`を使用します:

```
application/json              - JSON形式
application/xml               - XML形式
application/x-www-form-urlencoded - フォームデータ
multipart/form-data          - ファイルアップロード
text/plain                   - プレーンテキスト
```

---

### 4. バージョニングの原則

#### URIパスにメジャーバージョンを埋め込む

最も一般的で推奨される方式:

```
https://api.example.com/v1/users
https://api.example.com/v2/users
```

他の方式との比較:

| 方式 | 例 | メリット | デメリット |
|------|-----|---------|----------|
| **URIパス** | `/v1/users` | 明示的、ブラウザで確認しやすい | URIが変わる |
| クエリパラメータ | `/users?version=1` | URIを保持 | キャッシュに不利 |
| カスタムヘッダ | `X-API-Version: 1` | URIを保持 | 見えにくい |
| メディアタイプ | `application/vnd.example.v1+json` | REST理念に近い | 複雑 |

**URIパス方式を推奨**（デファクトスタンダード）。

#### セマンティックバージョニング

バージョン番号は `MAJOR.MINOR.PATCH` 形式:

- **MAJOR**: 互換性のない変更（破壊的変更）
- **MINOR**: 後方互換性のある機能追加
- **PATCH**: 後方互換性のあるバグ修正

**URIには MAJOR バージョンのみ含める** (`/v1/`, `/v2/`)。

#### バージョンを上げない変更

以下は既存バージョン内で実施可能（後方互換性を保つため）:

- レスポンスへのフィールド追加（既存フィールドは維持）
- 新しいエンドポイントの追加
- オプショナルなリクエストパラメータの追加
- バグ修正

#### バージョンを上げる変更

以下は新しいメジャーバージョンが必要:

- レスポンスからフィールドを削除
- フィールド名の変更
- フィールドの型変更
- 必須パラメータの追加
- エンドポイントの削除
- 認証方式の変更

#### API提供終了（Deprecation）

古いバージョンを終了する際は:

1. **事前告知**: 最低6ヶ月前にアナウンス
2. **Deprecationヘッダ**: `Deprecation: true` をレスポンスに含める
3. **移行ガイド**: 新バージョンへの移行手順を提供
4. **段階的終了**: 警告期間を設けてから完全停止

---

### 5. セキュリティの原則

#### HTTPS必須

- すべてのAPIエンドポイントでHTTPSを使用
- HTTP（80番ポート）へのアクセスはHTTPSへリダイレクト
- `Strict-Transport-Security`ヘッダでHSTSを有効化

```http
Strict-Transport-Security: max-age=31536000; includeSubDomains
```

#### OAuth 2.0による認証

業界標準の認証フレームワークを使用:

**主なGrant Type:**

| Grant Type | 用途 | ユースケース |
|-----------|------|-------------|
| **Authorization Code** | 最も安全 | Webアプリケーション |
| **Client Credentials** | M2M認証 | サーバ間通信 |
| **Resource Owner Password** | 非推奨 | レガシーアプリ（新規では使わない） |
| **Implicit** | 非推奨 | SPAアプリ（新規では使わない） |

**推奨構成:**
- Webアプリ: Authorization Code Flow + PKCE
- SPAアプリ: Authorization Code Flow + PKCE
- モバイルアプリ: Authorization Code Flow + PKCE
- サーバ間: Client Credentials Flow

**アクセストークンの扱い:**

```http
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

- トークンは `Authorization` ヘッダで送信
- URLクエリパラメータでトークンを送信しない（ログに残るリスク）
- トークンには適切な有効期限を設定（短命 + Refresh Token）

#### XSRF（Cross-Site Request Forgery）対策

- **Double Submit Cookie**: CSRFトークンをCookieとカスタムヘッダの両方で送信
- **SameSite Cookie属性**: `SameSite=Strict` または `SameSite=Lax` を設定
- **Origin/Refererヘッダ検証**: リクエストの送信元を確認

#### パラメータバリデーション

すべての入力を検証します:

- **型チェック**: 期待する型（string, number, boolean等）
- **範囲チェック**: 数値の最小/最大、文字列の長さ
- **フォーマットチェック**: email, URL, UUID等
- **ホワイトリスト**: 許可する値のリストと照合

バリデーションエラーは `422 Unprocessable Entity` で返します。

#### レートリミット

APIの過度な使用を防ぐため、レート制限を実装:

```http
X-RateLimit-Limit: 5000        # 制限値
X-RateLimit-Remaining: 4999    # 残り回数
X-RateLimit-Reset: 1625097600  # リセット時刻（UNIX時間）
```

制限超過時は `429 Too Many Requests` を返します。

#### セキュリティヘッダ

以下のセキュリティヘッダを設定:

```http
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
Content-Security-Policy: default-src 'self'
Referrer-Policy: strict-origin-when-cross-origin
```

---

## ユーザー確認の原則

設計時に複数の選択肢がある場合、**推測で進めずAskUserQuestionツールで確認**してください。

### 確認すべき場面

以下の判断は必ずユーザーに確認:

1. **認証方式の選択**
   - OAuth 2.0のGrant Type選択
   - カスタム認証スキーム
   - API Key vs JWT

2. **バージョニング戦略**
   - URIパス vs クエリパラメータ vs メディアタイプ
   - バージョン番号の採番ルール

3. **ページネーション方式**
   - offset/limit方式
   - page/per_page方式
   - カーソルベースページネーション

4. **エラーレスポンスの詳細度**
   - 開発者向けメッセージの詳細度
   - 本番環境でのスタックトレース露出

5. **CORS設定のスコープ**
   - 許可するOriginの範囲
   - 許可するHTTPメソッド

6. **レートリミットの設定値**
   - リクエスト数の上限
   - 時間ウィンドウ（1分/1時間/1日）

### 確認不要な場面

以下は業界標準・必須要件のため確認不要:

- JSONをデフォルトフォーマットにする（デファクトスタンダード）
- HTTPSを使用する（必須セキュリティ要件）
- URIを小文字で統一する（慣習）
- リソース名に複数形の名詞を使う（RESTful設計原則）
- 適切なHTTPステータスコードを使う（HTTP仕様）

---

## サブファイルナビゲーション

詳細なガイドラインは、以下のサブファイルを参照してください:

| ファイル | 内容 |
|---------|------|
| [ENDPOINT-DESIGN.md](ENDPOINT-DESIGN.md) | エンドポイント設計詳細・HTTPメソッド・URI設計原則・検索とページネーション |
| [RESPONSE-DESIGN.md](RESPONSE-DESIGN.md) | レスポンスデータ構造・JSON設計・エラー表現・ページネーション形式 |
| [HTTP-SPEC.md](HTTP-SPEC.md) | HTTPステータスコード詳細・キャッシュ戦略・CORS・メディアタイプ |
| [VERSIONING.md](VERSIONING.md) | バージョン管理戦略・セマンティックバージョニング・API廃止プロセス |
| [SECURITY.md](SECURITY.md) | HTTPS設定・OAuth 2.0詳細・XSRF対策・レートリミット・セキュリティヘッダ |
| [CHECKLIST.md](CHECKLIST.md) | Web API設計チェックリスト（完全版） |

---

## Web API設計チェックリスト（コンパクト版）

設計時に最低限確認すべき項目をカテゴリ別にまとめました。完全版は [CHECKLIST.md](CHECKLIST.md) を参照してください。

### URI設計

- [ ] URIは小文字で統一されているか
- [ ] リソース名は複数形の名詞を使用しているか
- [ ] URIに動詞が含まれていないか
- [ ] ネストは2階層以内に収まっているか
- [ ] URIがHackableな構造になっているか

### HTTPメソッド

- [ ] 適切なHTTPメソッドを使用しているか（GET/POST/PUT/PATCH/DELETE）
- [ ] GETリクエストは冪等性を保っているか（副作用なし）
- [ ] PUT/DELETE は冪等性を保っているか
- [ ] POST は非冪等性を正しく扱っているか

### レスポンス

- [ ] JSONをデフォルトフォーマットとしているか
- [ ] 不要なエンベロープで包んでいないか
- [ ] 命名規則（camelCase/snake_case）が統一されているか
- [ ] 成功時に適切なステータスコード（200/201/204）を返しているか
- [ ] レスポンス構造がフラットになっているか

### エラー処理

- [ ] エラー時に適切なHTTPステータスコード（400番台/500番台）を返しているか
- [ ] エラーレスポンスに `code` と `message` が含まれているか
- [ ] バリデーションエラーには詳細情報（`details`フィールド）があるか
- [ ] 本番環境でスタックトレースを露出していないか

### キャッシュ

- [ ] 変更頻度の低いリソースに `ETag` または `Last-Modified` を設定しているか
- [ ] `Cache-Control` ヘッダで適切なキャッシュポリシーを設定しているか
- [ ] 条件付きリクエスト（`If-None-Match`, `If-Modified-Since`）に対応しているか

### セキュリティ

- [ ] すべてのエンドポイントでHTTPSを使用しているか
- [ ] 認証が必要なエンドポイントで認証チェックを実装しているか
- [ ] XSRF対策を実装しているか（Double Submit Cookie, SameSite Cookie等）
- [ ] すべての入力パラメータをバリデーションしているか
- [ ] レートリミットを実装しているか
- [ ] セキュリティヘッダ（`X-Content-Type-Options`, `X-Frame-Options`等）を設定しているか

### バージョニング

- [ ] URIにメジャーバージョン（`/v1/`）を含めているか
- [ ] セマンティックバージョニングに基づいているか
- [ ] 後方互換性のない変更時に新バージョンを作成しているか
- [ ] 古いバージョン廃止時に十分な移行期間を設けているか

### CORS

- [ ] クロスオリジンリクエストに対して適切な `Access-Control-Allow-Origin` を設定しているか
- [ ] プリフライトリクエストに対応しているか
- [ ] `Access-Control-Max-Age` でプリフライト結果をキャッシュしているか

---

## まとめ

このスキルで紹介した原則を適用することで、以下の特性を持つWeb APIを設計できます:

- **理解しやすい**: 直感的なURI、予測可能な振る舞い
- **使いやすい**: 一貫性のあるインターフェース、明確なエラーメッセージ
- **拡張しやすい**: 後方互換性を保ったバージョニング、柔軟な設計
- **高速**: 適切なキャッシュ活用、効率的なデータ構造
- **安全**: HTTPS、認証、入力検証、レート制限

詳細なガイドラインは各サブファイルを参照し、設計前に[CHECKLIST.md](CHECKLIST.md)で漏れがないか確認してください。
