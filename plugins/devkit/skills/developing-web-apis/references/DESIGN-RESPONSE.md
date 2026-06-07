# レスポンスデータの設計

## 1. データフォーマット

### JSON がデファクトスタンダード

現代のWeb APIではJSONが標準的なデータフォーマットとなっています。

**JSON を選ぶ理由:**
- XMLより軽量・シンプル
- JavaScriptとの相性が良い
- 可読性が高い
- パース処理が高速

**他のフォーマット:**
- XML: 必要に応じて対応（レガシーシステム連携等）
- MessagePack等のバイナリフォーマット: SSKD向け高速通信に検討可能

### データフォーマットの指定方法

| 方法 | 例 | 推奨度 |
|------|-----|--------|
| クエリパラメータ | `?format=json` | ✅ 最も一般的で使いやすい |
| 拡張子 | `/users.json` | △ あまり使われない |
| Acceptヘッダ | `Accept: application/json` | ✅ HTTP仕様に忠実 |

**推奨:** クエリパラメータを基本とし、Acceptヘッダにも対応するのがベストプラクティスです。

```http
GET /v1/users?format=json
Accept: application/json
```

---

## 2. レスポンスデータ構造の原則

### エンベロープを避ける

HTTPヘッダ自体がエンベロープの役割を担うため、レスポンスボディに不要なラッパーを追加しないでください。

```json
// ❌ 不要なエンベロープ
{
  "header": { "status": "success" },
  "response": { "user": { ... } }
}

// ✅ シンプルな構造
{
  "id": 123,
  "name": "Taro",
  "email": "taro@example.com"
}
```

**ステータス情報はHTTPヘッダで表現:**
- 成功: `200 OK`
- エラー: `400 Bad Request`, `404 Not Found` 等

### フラットな構造を心がける

不必要なネストを避け、シンプルなデータ構造にします。

```json
// ❌ 不必要なネスト
{
  "user": {
    "profile": {
      "personal": {
        "name": "Taro",
        "age": 30
      }
    }
  }
}

// ✅ フラットな構造
{
  "name": "Taro",
  "age": 30,
  "email": "taro@example.com"
}
```

**ネストが必要なケース:**
- 関連エンティティの包含（埋め込み）
- 明確な階層関係がある場合

```json
{
  "id": 123,
  "name": "Taro",
  "address": {
    "zip": "100-0001",
    "city": "Tokyo",
    "street": "1-1-1 Chiyoda"
  }
}
```

### トップレベルはオブジェクトにする

配列をトップレベルに置くことは避けます。

```json
// ❌ 配列をトップレベルに
[
  {"id": 1, "name": "Taro"},
  {"id": 2, "name": "Hanako"}
]

// ✅ オブジェクトで包む
{
  "users": [
    {"id": 1, "name": "Taro"},
    {"id": 2, "name": "Hanako"}
  ],
  "total_count": 100,
  "page": 1
}
```

**理由:**
- セキュリティ上の懸念（JSON Hijacking対策）
- メタ情報を追加しやすい（件数、ページネーション情報等）
- 将来の拡張性が高い

---

## 3. データ命名規則

### 統一された命名規則

API全体で一貫した命名規則を使用します。

**推奨規則:**
- `snake_case`: `created_at`, `user_id`
- `camelCase`: `createdAt`, `userId`

**どちらでも良いが、必ず統一すること。** 混在は絶対に避けます。

### 命名のベストプラクティス

| ルール | 例 |
|--------|-----|
| 一般的な単語を使用 | `id`, `name`, `created_at`, `updated_at` |
| 省略形を避ける | `description` ✅ / `desc` ❌ |
| 単数形/複数形を正しく | `user`（単一オブジェクト）, `users`（配列） |
| なるべく少ない単語数 | `created_at` ✅ / `date_of_creation` ❌ |
| ブール値は疑問形 | `is_active`, `has_permission` |

**具体例:**

```json
{
  "id": 123,
  "name": "Taro Yamada",
  "email": "taro@example.com",
  "is_active": true,
  "created_at": "2024-01-15T09:30:00Z",
  "updated_at": "2024-02-20T14:45:00Z"
}
```

---

## 4. 各データのフォーマット

### 日時・日付

**RFC 3339（ISO 8601）形式を使用:**

```json
{
  "created_at": "2024-01-15T09:30:00Z",
  "updated_at": "2024-02-20T14:45:00+09:00",
  "date_of_birth": "1990-05-15"
}
```

**ポイント:**
- タイムゾーン情報を含める（`Z` はUTC、`+09:00` は日本時間）
- 日付のみの場合は `YYYY-MM-DD` 形式

### 大きな整数ID

JavaScriptの数値型は53ビットまでしか正確に扱えないため、大きなIDは文字列として返します。

```json
{
  "id": "240859602684612608",
  "user_id": "123456789012345678"
}
```

**目安:** 16桁以上のIDは文字列にする

### 列挙型データ

文字列として返します。

```json
{
  "gender": "male",
  "status": "active",
  "role": "admin"
}
```

**理由:**
- 可読性が高い
- デバッグしやすい
- 値の追加が容易

### 金額

最小通貨単位の整数で返します。

```json
{
  "amount": 1000,
  "currency": "USD"
}
```

**例:** 10.00ドル → `1000`（セント単位）

**理由:**
- 浮動小数点演算の誤差を避ける
- 整数演算は高速で正確

---

## 5. レスポンスフィールドの選択

### フィールド指定機能

クライアントが必要なフィールドだけを取得できるようにします。

```http
GET /v1/users/123?fields=id,name,email
```

**レスポンス:**
```json
{
  "id": 123,
  "name": "Taro",
  "email": "taro@example.com"
}
```

### 利点

- 通信量の削減（特にモバイル向け）
- クライアントの柔軟性向上
- 不要なデータの取得を避ける

### 実装のポイント

- デフォルトフィールドセットを定義
- ネストしたフィールドへの対応: `fields=id,name,address.city`
- ワイルドカード対応: `fields=*,address.city`

---

## 6. エラーの表現

### 基本原則

1. **適切なHTTPステータスコードを返す**
   - 200番台: 成功
   - 400番台: クライアントエラー
   - 500番台: サーバエラー

2. **レスポンスボディにエラー詳細を含める**
   - エラーコード
   - エラーメッセージ
   - 追加情報へのリンク

3. **エラー時にHTMLを返さない**
   - 常にJSON形式で返す

### エラーレスポンスの推奨構造

**単一エラー:**

```json
{
  "error": {
    "code": 2013,
    "message": "Bad authentication token",
    "info": "https://docs.example.com/api/v1/authentication"
  }
}
```

**複数エラー:**

```json
{
  "errors": [
    {
      "code": 1001,
      "message": "name is required",
      "field": "name"
    },
    {
      "code": 1002,
      "message": "email format is invalid",
      "field": "email"
    }
  ]
}
```

### 開発者向け/ユーザー向けメッセージの分離

エンドユーザーと開発者の両方に有用な情報を提供します。

```json
{
  "error": {
    "developer_message": "Invalid OAuth token. Token has expired at 2024-02-20T15:30:00Z",
    "user_message": "ログインセッションが切れました。再度ログインしてください。",
    "code": 2013,
    "info": "https://docs.example.com/api/errors/2013"
  }
}
```

**フィールドの役割:**
- `developer_message`: 技術的詳細（ログ記録・デバッグ用）
- `user_message`: エンドユーザー向けの分かりやすいメッセージ
- `code`: エラー種別を一意に識別
- `info`: ドキュメントへのリンク

### バリデーションエラー

```json
{
  "error": {
    "code": 400,
    "message": "Validation failed",
    "validation_errors": [
      {
        "field": "email",
        "message": "Invalid email format",
        "code": "INVALID_FORMAT"
      },
      {
        "field": "age",
        "message": "Must be 18 or older",
        "code": "MIN_VALUE"
      }
    ]
  }
}
```

### メンテナンス時のレスポンス

**ステータスコード:** `503 Service Unavailable`

**ヘッダ:**
```http
HTTP/1.1 503 Service Unavailable
Retry-After: Mon, 2 Dec 2024 03:00:00 GMT
```

**ボディ:**
```json
{
  "error": {
    "code": 503,
    "message": "Service temporarily unavailable for maintenance",
    "retry_after": "2024-12-02T03:00:00Z"
  }
}
```

### 意図的に不正確な情報を返すケース

セキュリティを重視して、情報量を意図的に制限する場面があります。

**ブロック機能:**
- ブロックされた側には `404 Not Found` を返す
- `403 Forbidden` を返すとブロックが露見する

**ログイン失敗:**
- 「メールアドレスが存在しない」「パスワードが違う」を区別しない
- 統一されたメッセージ: "Invalid email or password"

**理由:** アカウント存在確認による情報漏洩を防ぐ

---

## 7. JSONP（レガシー対応）

### JSONP とは

同一生成元ポリシーを回避するための歴史的なテクニックです。

**現在の推奨:** CORSを使用する（JSONPは非推奨）

### やむを得ず対応する場合

**リクエスト:**
```http
GET /v1/users/123?callback=handleResponse
```

**レスポンス:**
```javascript
handleResponse({
  "id": 123,
  "name": "Taro"
});
```

**重要なポイント:**
- Content-Type: `application/javascript`（`application/json` ではない）
- コールバック関数名のバリデーション（XSS対策）
- 英数字とアンダースコアのみ許可

**セキュリティリスク:**
- CSRF攻撃のリスクが高い
- 可能な限りCORSへの移行を推奨

---

## まとめ: レスポンス設計のチェックリスト

- [ ] JSONをデフォルトフォーマットとしている
- [ ] 不要なエンベロープを使用していない
- [ ] フラットで分かりやすいデータ構造になっている
- [ ] 命名規則がAPI全体で統一されている
- [ ] 日時はRFC 3339形式で返している
- [ ] 大きな整数IDは文字列で返している
- [ ] 適切なHTTPステータスコードを使用している
- [ ] エラー時に詳細情報をJSONで返している
- [ ] フィールド選択機能を提供している（推奨）
- [ ] CORSを適切に設定している（JSONPは避ける）
