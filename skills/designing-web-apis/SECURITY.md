# 堅牢なWeb APIを作る

このドキュメントでは、Web APIのセキュリティ設計における重要な原則と実装手法を示します。

---

## 1. APIセキュリティの3つの脅威

Web APIは以下の3つの主要な脅威カテゴリにさらされています。

| 脅威カテゴリ | 内容 |
|-------------|------|
| 通信経路の盗聴 | パケットスニッフィング、セッションハイジャック、中間者攻撃 |
| サーバの脆弱性 | XSS、SQLインジェクション、パラメータ不正、JSONインジェクション |
| ブラウザ経由の攻撃 | XSRF（CSRF）、JSONハイジャック |

これらの脅威に対して多層防御の仕組みを構築することが重要です。

---

## 2. HTTPS（TLS）

### 原則

**すべてのAPIエンドポイントをHTTPSで提供すること。**

HTTPS（TLS）による暗号化は以下を保護します：
- URIパス
- クエリ文字列
- リクエストヘッダ
- リクエストボディ
- レスポンスヘッダ
- レスポンスボディ

公衆WiFi等でのカジュアルな盗聴を防止し、通信の機密性と完全性を確保します。

### HTTPS利用時の注意点

- **SSL証明書の検証を必ず行う**（コモンネーム検証含む）
- デバッグ目的で検証を無効にしたままリリースしない
- HSTS（HTTP Strict Transport Security）を活用してHTTPSアクセスを強制

#### HSTSヘッダの例

```
Strict-Transport-Security: max-age=31536000; includeSubDomains
```

- `max-age`: HTTPS強制期間（秒単位）
- `includeSubDomains`: サブドメインにも適用

### HTTPSの限界

HTTPSだけでは以下のリスクを完全に排除できません：

- ライブラリのバグ（OpenSSL Heartbleed等）
- 認証局への攻撃（不正証明書発行）
- クライアント側の証明書検証不備

**「HTTPSだけで100%安全」ではない。多層防御が必要です。**

---

## 3. ブラウザアクセスAPI固有の脅威と対策

ブラウザから直接アクセスされるAPIには、Webアプリケーション特有の脅威が存在します。

### XSS（Cross-Site Scripting）

#### 脅威

APIレスポンスに悪意あるスクリプトが含まれ、ブラウザ上で実行される可能性があります。

#### 対策

- レスポンスのJSON文字列を適切にエスケープ
- `Content-Type: application/json` を明示
- `X-Content-Type-Options: nosniff` ヘッダを設定

### XSRF / CSRF（Cross-Site Request Forgery）

#### 脅威

ユーザーの意図しないリクエストが攻撃者によって送信される可能性があります。

#### 対策

ブラウザからアクセスするAPIではXSRFトークンを使用：

1. サーバがセッション開始時にランダムなトークンを生成
2. トークンをフォームやカスタムヘッダに含めてリクエスト
3. サーバがトークンの一致を検証

**実装例:**

```javascript
// カスタムヘッダでトークン送信
fetch('/api/resource', {
  method: 'POST',
  headers: {
    'X-XSRF-Token': getCookie('XSRF-TOKEN'),
    'Content-Type': 'application/json'
  },
  body: JSON.stringify(data)
});
```

### JSONハイジャック対策

#### 脅威

script要素を使ってJSONを直接読み込まれ、データが窃取される可能性があります。

#### 対策

- `X-Requested-With` ヘッダの検証（AJAX以外からのアクセスを防止）
- script要素でJSONを直接読み込めないようにする
- トップレベルの配列を避ける（オブジェクトで包む）

**悪い例:**

```json
[
  {"id": 1, "name": "Alice"},
  {"id": 2, "name": "Bob"}
]
```

**良い例:**

```json
{
  "users": [
    {"id": 1, "name": "Alice"},
    {"id": 2, "name": "Bob"}
  ]
}
```

---

## 4. パラメータバリデーション

### 原則

**すべての入力パラメータを信頼してはいけません。**

### 検証項目

- 型の検証（文字列、数値、真偽値等）
- 範囲の検証（マイナス値、最小値/最大値）
- フォーマットの検証（日付、メールアドレス、URL等）
- 必須/任意の検証
- 許可リスト（ホワイトリスト）による値の検証

### SQLインジェクション対策

**プリペアドステートメント（パラメータ化クエリ）を必須とする。**

**悪い例:**

```python
# SQLインジェクションの危険性
query = f"SELECT * FROM users WHERE id = {user_id}"
```

**良い例:**

```python
# プリペアドステートメントで安全に
query = "SELECT * FROM users WHERE id = ?"
cursor.execute(query, (user_id,))
```

### リクエストの冪等性確保

同一リクエストの再送信で二重処理しないように設計：

- 一意なリクエストID（`X-Request-ID`）の使用
- トランザクション管理
- 冪等なエンドポイント設計（PUT、DELETE等）

---

## 5. セキュリティ関連HTTPヘッダ

すべてのレスポンスに以下のセキュリティヘッダを設定することを推奨します。

| ヘッダ | 値の例 | 用途 |
|--------|--------|------|
| X-Content-Type-Options | `nosniff` | MIMEスニッフィング防止 |
| X-Frame-Options | `DENY` | クリックジャッキング防止 |
| X-XSS-Protection | `1; mode=block` | ブラウザのXSSフィルター有効化 |
| Content-Security-Policy | `default-src 'self'` | コンテンツ読み込み元制限 |
| Strict-Transport-Security | `max-age=31536000` | HTTPS強制（HSTS） |
| Cache-Control | `no-store` | 機密データのキャッシュ防止 |
| Pragma | `no-cache` | HTTP/1.0互換のキャッシュ防止 |

### レスポンス例

```http
HTTP/1.1 200 OK
Content-Type: application/json
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
Content-Security-Policy: default-src 'self'
Strict-Transport-Security: max-age=31536000; includeSubDomains
Cache-Control: no-store, no-cache, must-revalidate
Pragma: no-cache
```

---

## 6. レートリミット

### 目的

レートリミットは以下を実現します：

- サーバの負荷を制御
- 悪意ある大量アクセス（DDoS等）から保護
- APIの公平な利用を保証

### 設計

| 項目 | 推奨 |
|------|------|
| 単位 | 1時間あたりのリクエスト数が一般的 |
| 識別 | ユーザー単位（APIキー/トークン別）+ IP単位 |
| 超過時ステータス | 429 Too Many Requests |
| 復旧情報 | Retry-After ヘッダ |

### レスポンスヘッダ

制限状況をクライアントに通知するため、以下のヘッダを含めます：

```http
X-Rate-Limit-Limit: 100
X-Rate-Limit-Remaining: 42
X-Rate-Limit-Reset: 1609459200
```

- `X-Rate-Limit-Limit`: 制限回数
- `X-Rate-Limit-Remaining`: 残り回数
- `X-Rate-Limit-Reset`: リセット時刻（UNIXタイムスタンプ）

### 制限超過時のレスポンス

```http
HTTP/1.1 429 Too Many Requests
Content-Type: application/json
Retry-After: 3600
X-Rate-Limit-Limit: 100
X-Rate-Limit-Remaining: 0
X-Rate-Limit-Reset: 1609459200

{
  "error": {
    "code": "rate_limit_exceeded",
    "message": "レート制限を超えました。1時間後に再試行してください。"
  }
}
```

### 制限回数の決め方

- 想定ユースケースから逆算
- 少なすぎると正常利用が妨げられる
- 多すぎるとサーバ保護が不十分
- 段階的制限（無料プラン/有料プラン）も検討
- 初期値は控えめに設定し、運用データをもとに調整

---

## 7. セキュリティチェックリスト

API実装時に以下の項目を確認してください：

- [ ] すべてのエンドポイントがHTTPS
- [ ] SSL証明書の検証が有効
- [ ] HSTSヘッダを設定
- [ ] JSONエスケープが適切
- [ ] ブラウザ向けAPIにXSRFトークン実装
- [ ] パラメータのバリデーション実装（型、範囲、フォーマット）
- [ ] SQLインジェクション対策（プリペアドステートメント）
- [ ] リクエスト再送信による二重処理防止
- [ ] セキュリティヘッダを全レスポンスに設定
  - [ ] X-Content-Type-Options
  - [ ] X-Frame-Options
  - [ ] X-XSS-Protection
  - [ ] Content-Security-Policy
  - [ ] Strict-Transport-Security
- [ ] 機密データのキャッシュ防止（Cache-Control、Pragma）
- [ ] レートリミット実装
- [ ] レートリミットの制限値が適切
- [ ] 429 Too Many Requestsレスポンスの実装
- [ ] Retry-Afterヘッダの実装

---

## 8. まとめ

堅牢なWeb APIを構築するには、以下の多層防御アプローチが必要です：

1. **通信の暗号化**: すべてのエンドポイントでHTTPS/TLS
2. **入力の検証**: すべてのパラメータを厳格にバリデーション
3. **ブラウザ脅威への対応**: XSS、XSRF、JSONハイジャック対策
4. **セキュリティヘッダ**: すべてのレスポンスに適切なヘッダを設定
5. **レート制限**: サーバ保護と公平な利用の担保

「HTTPSさえあれば安全」ではなく、これらの対策を組み合わせることでセキュアなAPIを実現できます。
