# エンドポイント設計とリクエストの形式

## 美しいURIの6原則

### 1. 短く入力しやすい
- 重複を排除する
- 冗長なパスセグメントを避ける

```
❌ api.example.com/service/api/search
✅ api.example.com/search
```

### 2. 人間が読んで理解できる
- 省略形を避ける
- 英語を使用する
- スペルミスに注意する

```
❌ /usr/reg
✅ /users/register

❌ /regist  （registではなくregister）
✅ /register
```

### 3. 小文字統一
- 大文字小文字混在は禁止
- ホスト名に合わせて小文字に統一

```
❌ /Users/Profile
✅ /users/profile
```

### 4. Hackable（推測可能）
- URIを見て他のURIを推測できる構造
- IDの範囲でエンドポイントが変わる設計は避ける

```
✅ /v1/users/123
   /v1/users/456  （パターンが推測できる）

❌ /v1/user-details?id=123  （他のURIが推測しにくい）
```

### 5. サーバ側アーキテクチャを反映しない
- 実装の詳細をURIに含めない
- セキュリティリスクを避ける

```
❌ /cgi-bin/search.php
❌ /api/v1/users.jsp
✅ /api/v1/users
```

### 6. ルール統一
- 複数形/単数形の使い方を統一
- パス/クエリパラメータの使い分けを統一
- 単語の連結方法を統一

---

## HTTPメソッドとリソース操作

### メソッド一覧

| メソッド | 用途 | 冪等性 | 安全性 | 説明 |
|---------|------|--------|--------|------|
| GET | リソース取得 | ✅ | ✅ | サーバ側のデータを変更しない |
| POST | 新規作成 | ❌ | ❌ | 指定URIの配下にリソースを作成 |
| PUT | 全体更新 | ✅ | ❌ | 指定URIのリソースを置換 |
| PATCH | 部分更新 | ❌ | ❌ | 指定URIのリソースの一部を変更 |
| DELETE | 削除 | ✅ | ❌ | 指定URIのリソースを削除 |
| HEAD | メタ情報取得 | ✅ | ✅ | GETと同じだがボディを返さない |

### 用語の定義

- **冪等性**: 同じリクエストを複数回実行しても結果が同じになる性質
- **安全性**: サーバ側のデータを変更しない性質

### POSTとPUTの使い分け

```
POST /v1/users
→ サーバがIDを決定してリソースを作成
  レスポンス: 201 Created, Location: /v1/users/123

PUT /v1/users/123
→ クライアントが指定したIDでリソースを作成/置換
  冪等性があるため何度実行しても結果が同じ
```

### PATCHの使い所

巨大なリソースの一部だけを更新したい場合に有効:

```
PATCH /v1/users/123
Content-Type: application/json

{
  "email": "new@example.com"
}

→ emailフィールドのみ更新、他のフィールドは変更なし
```

### X-HTTP-Method-Override

GET/POST以外のメソッドが使えない環境向けの回避策:

```
POST /v1/users/123
X-HTTP-Method-Override: DELETE

→ DELETEメソッドとして処理される
```

---

## リソース指向エンドポイント設計パターン

### 基本パターン（CRUDマッピング）

```
GET    /v1/users          → ユーザー一覧取得
POST   /v1/users          → ユーザー新規登録
GET    /v1/users/:id      → 特定ユーザー取得
PUT    /v1/users/:id      → ユーザー情報更新（全体）
PATCH  /v1/users/:id      → ユーザー情報更新（一部）
DELETE /v1/users/:id      → ユーザー削除
```

### ネストしたリソース

親子関係のあるリソースはURIにネストして表現:

```
GET    /v1/users/:id/friends           → 特定ユーザーの友達一覧
POST   /v1/users/:id/friends           → 友達追加
DELETE /v1/users/:id/friends/:friendId → 友達削除
GET    /v1/users/:id/updates           → 特定ユーザーの近況一覧
```

### ネストの深さの制限

3階層以上のネストは避ける:

```
❌ /v1/users/:userId/friends/:friendId/posts/:postId/comments
✅ /v1/comments?postId=xxx&userId=yyy  （クエリパラメータで代用）
```

---

## エンドポイント設計の注意点

### 複数形の名詞を使う

リソースは集合として扱うため複数形を使用:

```
✅ GET /v1/users
✅ GET /v1/users/123
✅ POST /v1/users

❌ GET /v1/user
❌ POST /v1/user
```

### 動詞を避ける

HTTPメソッドが動詞を担当するため、URI内に動詞を含めない:

```
❌ GET /v1/getUsers
❌ POST /v1/createUser
❌ DELETE /v1/deleteUser/123

✅ GET /v1/users
✅ POST /v1/users
✅ DELETE /v1/users/123
```

例外: 動詞でしか表現できない操作（検索、変換等）の場合は許容:

```
POST /v1/convert      （形式変換）
GET  /v1/search       （検索）
POST /v1/translate    （翻訳）
```

### エンコード文字を避ける

パーセントエンコーディングが必要なURIは避ける:

```
❌ /v1/users/山田太郎  → /v1/users/%E5%B1%B1%E7%94%B0%E5%A4%AA%E9%83%8E
✅ /v1/users/123
```

### 単語の連結はハイフン

複数単語を連結する場合はハイフン（-）を使用:

```
✅ /v1/profile-image    （推奨）
△ /v1/profile_image    （スネークケース）
△ /v1/profileImage     （キャメルケース）

最も良いのは単語連結自体を避けること:
✅ /v1/users/popular   （2つの独立した単語）
△ /v1/popular-users    （連結）
```

### よく使われる単語を選ぶ

複数のAPI設計を参考にし、一般的な語彙を選択:

```
✅ /v1/search
❌ /v1/find

✅ /v1/users/123/friends
❌ /v1/users/123/connections
```

---

## 検索とクエリパラメータ設計

### ページネーション方式の比較

#### offset/limit方式

```
GET /v1/users?offset=100&limit=50
```

- **offset**: 0-based（0から開始）
- **limit**: 取得件数
- 自由度が高いが、データ量が増えるとパフォーマンスが悪化

#### page/per_page方式

```
GET /v1/users?page=3&per_page=50
```

- **page**: 1-based（1から開始）
- **per_page**: 1ページあたりの件数
- 直感的だが、offset方式と同様のパフォーマンス問題あり

#### カーソルベース方式

```
GET /v1/users?cursor=xxx&count=50
```

- **cursor**: 前回レスポンスで返された次ページのトークン
- **count**: 取得件数
- 大量データに最適、パフォーマンス良好
- データの追加/削除による不整合が起きにくい

### 相対位置指定の問題点

**offset/page方式の課題:**

1. **パフォーマンス**: データ量が増えるとoffset指定が遅くなる（先頭からスキャン）
   ```sql
   SELECT * FROM users ORDER BY id LIMIT 50 OFFSET 10000;
   -- 10000件読み飛ばしてから50件取得（非効率）
   ```

2. **データ不整合**: 取得間にデータ追加/削除があるとずれる
   ```
   1回目: offset=0, limit=10  → 1-10件目を取得
   （この間に5件追加）
   2回目: offset=10, limit=10 → 16-25件目を取得（11-15がスキップされる）
   ```

**解決策: 絶対位置指定**

```
GET /v1/posts?max_id=100&count=20
→ ID 100以前の投稿を20件取得

GET /v1/posts?since_id=200&count=20
→ ID 200以降の投稿を20件取得

GET /v1/videos?publishedBefore=2024-01-01T00:00:00Z&count=20
→ 指定日時以前の動画を20件取得
```

### 絞り込み（検索）パラメータ

#### フィールド指定検索（完全一致）

```
GET /v1/users?first-name=John&company=Acme
→ first-name="John" AND company="Acme"のユーザーを取得
```

#### 全文検索（部分一致）

```
GET /v1/posts?q=keyword
→ キーワードを含む投稿を全文検索
```

#### 組み合わせ検索

```
GET /v1/articles?q=keyword&lang=ja&category=tech&sort=published_at
→ キーワード、言語、カテゴリで絞り込み、公開日順にソート
```

### よく使われる検索パラメータ

| パラメータ | 用途 | 例 |
|----------|------|-----|
| `q` | 全文検索 | `?q=keyword` |
| `sort` | ソート順 | `?sort=created_at` |
| `order` | 昇順/降順 | `?order=desc` |
| `fields` | 取得フィールド指定 | `?fields=id,name,email` |
| `include` | 関連リソース取得 | `?include=author,comments` |
| `filter` | 複雑なフィルタ | `?filter[status]=active` |

### クエリパラメータとパスの使い分け

| 判断基準 | パス | クエリパラメータ |
|---------|------|----------------|
| リソースの一意識別に必要 | ✅ | ❌ |
| 省略可能 | ❌ | ✅ |
| フィルタリング・ソート | ❌ | ✅ |
| ページネーション | ❌ | ✅ |

```
✅ /v1/users/123              （必須: ユーザー識別子）
✅ /v1/users?offset=0&limit=20 （省略可能: ページネーション）
✅ /v1/users?q=john&sort=name  （省略可能: 検索・ソート）

❌ /v1/users?id=123           （IDは一意識別子なのでパスに）
```

---

## 認証: OAuth 2.0

### Grant Type一覧

| Grant Type | 用途 | 特徴 |
|-----------|------|------|
| Authorization Code | サーバサイドWebアプリ | 最もセキュア。リダイレクトベース |
| Implicit | SPA/モバイルアプリ | 非推奨（PKCEを使ったAuthorization Code推奨） |
| Resource Owner Password Credentials | 自社アプリ | ユーザーがパスワードを直接入力 |
| Client Credentials | ユーザー単位認可不要 | サーバ間通信向け |

### Authorization Code Flow（推奨）

```
1. クライアント → 認可サーバ: 認可リクエスト
   GET /oauth/authorize?response_type=code&client_id=xxx&redirect_uri=xxx

2. ユーザー: ログイン・認可承認

3. 認可サーバ → クライアント: 認可コード発行
   Redirect to: https://client.example.com/callback?code=xxx

4. クライアント → 認可サーバ: アクセストークンリクエスト
   POST /oauth/token
   {
     "grant_type": "authorization_code",
     "code": "xxx",
     "client_id": "xxx",
     "client_secret": "xxx",
     "redirect_uri": "xxx"
   }

5. 認可サーバ → クライアント: アクセストークン発行
   {
     "access_token": "xxx",
     "token_type": "Bearer",
     "expires_in": 3600,
     "refresh_token": "xxx"
   }

6. クライアント → APIサーバ: リソースリクエスト
   GET /v1/users/me
   Authorization: Bearer xxx
```

### PKCE（Proof Key for Code Exchange）

SPA/モバイルアプリではPKCEを使ったAuthorization Code Flowが推奨:

```
1. code_verifier（ランダム文字列）を生成
2. code_challenge = BASE64URL(SHA256(code_verifier))
3. 認可リクエストにcode_challengeを含める
4. トークンリクエストにcode_verifierを含める
```

### アクセストークンの使用

```
GET /v1/users/me
Authorization: Bearer xxx
```

---

## HATEOAS（参考）

### 概要

HATEOASはREST成熟度モデルのLevel 3に相当する考え方。レスポンスにリンク情報を含め、クライアントがURIを構築する必要をなくす。

### 例

```json
{
  "id": 123,
  "name": "John Doe",
  "links": {
    "self": "/v1/users/123",
    "friends": "/v1/users/123/friends",
    "posts": "/v1/users/123/posts"
  }
}
```

### 実用性

完全なHATEOASを実装するAPIは少なく、以下のような部分的な採用が現実的:

- ページネーションのリンク情報（next, prev）
- 関連リソースへのリンク（self, related）
- 実行可能なアクションのリンク（edit, delete）

```json
{
  "data": [...],
  "pagination": {
    "next": "/v1/users?cursor=xxx",
    "prev": "/v1/users?cursor=yyy"
  }
}
```
