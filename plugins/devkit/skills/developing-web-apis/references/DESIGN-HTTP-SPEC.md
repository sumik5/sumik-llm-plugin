# HTTPの仕様を最大限利用する

## 1. HTTP仕様活用の意義

HTTPはRFCで定義された標準仕様です。準拠することでクライアントとの互換性が向上します。

- **ヘッダとボディの分離**: HTTPにはヘッダ（メタ情報）とボディ（データ本体）があるため、レスポンスデータのエンベロープは不要
- **標準準拠の利点**: 独自仕様を避け、既存の仕組みを最大限活用することで、既存のライブラリやツールとの親和性が高まる

---

## 2. ステータスコード詳細

### 200番台（成功）

| コード | 名前 | 用途 |
|--------|------|------|
| 200 | OK | 一般的な成功。GET, PUT, PATCH の成功時 |
| 201 | Created | リソース作成成功。POST の成功時 |
| 202 | Accepted | 非同期処理の受付完了 |
| 204 | No Content | 成功だがレスポンスボディなし。DELETE の成功時 |

**推奨される使い分け:**
- **PUT/PATCH**: 200 + 更新後データを返す（ETag取得のため）
- **DELETE**: 204を返す（削除データを返す必要は通常ない）
- **202**: 非同期処理（ファイル変換、通知送信等）の受付時に使用

---

### 300番台（リダイレクト）

| コード | 名前 | 用途 |
|--------|------|------|
| 301 | Moved Permanently | 恒久的移動（POSTからGETへの変更を許可） |
| 302 | Found | 一時的移動（POSTからGETへの変更を許可） |
| 303 | See Other | 常にGETでリダイレクト先にアクセス |
| 304 | Not Modified | キャッシュ有効（レスポンスボディ空） |
| 307 | Temporary Redirect | 一時的移動（メソッド変更不可） |
| 308 | Permanent Redirect | 恒久的移動（メソッド変更不可） |

**注意点:**
- APIでリダイレクトは極力避ける（クライアントが適切に処理しない可能性）
- 304はキャッシュ機構で重要

---

### 400番台（クライアントエラー）

| コード | 名前 | 用途 |
|--------|------|------|
| 400 | Bad Request | パラメータ不正等、他の4xxに該当しないエラー |
| 401 | Unauthorized | **認証**エラー（「あなたが誰かわからない」） |
| 403 | Forbidden | **認可**エラー（「あなたには権限がない」） |
| 404 | Not Found | リソースが存在しない |
| 405 | Method Not Allowed | 指定メソッド不可（GET専用にPOSTした等） |
| 406 | Not Acceptable | 指定されたデータ形式に非対応 |
| 408 | Request Timeout | リクエスト送信タイムアウト |
| 409 | Conflict | リソース競合（重複キー等） |
| 410 | Gone | リソースが過去に存在したが削除済み |
| 413 | Request Entity Too Large | リクエストボディが大きすぎる |
| 414 | Request-URI Too Long | URIが長すぎる |
| 415 | Unsupported Media Type | Content-Typeが非対応 |
| 429 | Too Many Requests | レートリミット超過 |

**重要な区別:**

- **401 vs 403**
  - 401: 認証（Authentication）エラー - 「あなたが誰かわからない」
  - 403: 認可（Authorization）エラー - 「あなたには権限がない」

- **404 vs 410**
  - 404: リソースが存在しない
  - 410: かつて存在したが削除済み

- **406 vs 415**
  - 406: Acceptヘッダで指定された形式に非対応
  - 415: Content-Typeヘッダで指定された形式に非対応

---

### 500番台（サーバエラー）

| コード | 名前 | 用途 |
|--------|------|------|
| 500 | Internal Server Error | サーバ側バグ。ログ監視・通知設定必須 |
| 503 | Service Unavailable | メンテナンス中・過負荷。Retry-Afterヘッダを返す |

**重要:**
- 500エラーはサーバ側のバグを示すため、ログ監視と通知設定が必須
- 503エラーには`Retry-After`ヘッダを含めることが推奨される

---

## 3. キャッシュ

### キャッシュ関連ヘッダ

| ヘッダ | 方向 | 用途 |
|--------|------|------|
| Cache-Control | レスポンス | キャッシュポリシー指定 |
| ETag | レスポンス | リソースのバージョン識別子 |
| Last-Modified | レスポンス | 最終更新日時 |
| If-None-Match | リクエスト | ETagによる条件付きGET |
| If-Modified-Since | リクエスト | 日時による条件付きGET |
| Vary | レスポンス | キャッシュキーに含めるリクエストヘッダ |

### Cache-Control の主な値

- `public`: 共有キャッシュ（CDN等）に保存可能
- `private`: ブラウザのみキャッシュ可能
- `no-cache`: キャッシュ前にサーバに検証が必要
- `no-store`: キャッシュ禁止（機密情報等）
- `max-age=3600`: 秒数指定（3600秒 = 1時間）

### 条件付きGET（Conditional GET）

キャッシュを活用した効率的な通信フロー:

1. **初回リクエスト**: サーバがETagまたはLast-Modifiedをレスポンスに含める
2. **2回目以降**: クライアントがIf-None-MatchまたはIf-Modified-Sinceを送信
3. **更新なし**: 304 Not Modified（ボディなし、通信量削減）
4. **更新あり**: 200 OK + 新しいデータ

**例:**

```
# 初回レスポンス
HTTP/1.1 200 OK
ETag: "33a64df551425fcc55e4d42a148795d9f25f89d4"
Content-Type: application/json

# 2回目以降のリクエスト
GET /api/resource HTTP/1.1
If-None-Match: "33a64df551425fcc55e4d42a148795d9f25f89d4"

# 更新なし
HTTP/1.1 304 Not Modified
```

---

## 4. メディアタイプ

### Content-Type設定

レスポンスには適切なContent-Typeを設定:

- **JSON**: `application/json`
- **XML**: `application/xml`
- **JSONP**: `application/javascript`
- **HTML**: `text/html; charset=utf-8`
- **プレーンテキスト**: `text/plain; charset=utf-8`

### セキュリティ設定

**X-Content-Type-Options: nosniff** を設定してMIME sniffingを防止:

```
X-Content-Type-Options: nosniff
```

これによりブラウザがContent-Typeを推測せず、サーバが指定した型を厳密に使用します。

---

## 5. CORS（Cross-Origin Resource Sharing）

### 背景

- **同一生成元ポリシー**: ブラウザはデフォルトで異なるオリジンへのリクエストを制限
- **CORS**: この制限を安全に緩和する仕組み

### レスポンスヘッダ

```
Access-Control-Allow-Origin: https://example.com
Access-Control-Allow-Methods: GET, POST, PUT, DELETE
Access-Control-Allow-Headers: Content-Type, Authorization
Access-Control-Max-Age: 86400
```

### プリフライトリクエスト（OPTIONS）

PUT/DELETE等の「非単純リクエスト」の前にブラウザが自動送信:

```
OPTIONS /api/resource HTTP/1.1
Origin: https://example.com
Access-Control-Request-Method: PUT
Access-Control-Request-Headers: Content-Type
```

### セキュリティ注意点

- `Access-Control-Allow-Origin: *` は認証が不要な公開APIのみ
- 認証を伴う場合は具体的なオリジンを指定
- 認証情報を含むリクエストは`Access-Control-Allow-Credentials: true`が必要

---

## 6. 独自HTTPヘッダの定義

### 命名規則

- `X-` プレフィックスはRFC 6648で非推奨に変更されましたが、既存の慣習として広く使われています
- 新規作成時は `X-` なしの独自名前空間を使うことが推奨されます

### 実用例: レートリミット情報

```
X-Rate-Limit-Limit: 100
X-Rate-Limit-Remaining: 95
X-Rate-Limit-Reset: 1609459200
```

### その他の一般的な独自ヘッダ

- `X-Request-ID`: リクエスト追跡用の一意ID
- `X-Response-Time`: サーバ処理時間（ミリ秒）
- `X-API-Version`: APIバージョン情報

---

## まとめ

HTTPの標準仕様を最大限活用することで:

- クライアント実装の互換性が向上
- 既存ツール・ライブラリとの連携が容易
- キャッシュによるパフォーマンス最適化
- セキュリティベストプラクティスの適用

独自仕様は最小限に抑え、HTTP標準で表現できることはHTTP標準で表現することが推奨されます。
