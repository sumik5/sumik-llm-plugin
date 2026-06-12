---
description: クライアントサイド Web セキュリティ（XSS/DOM XSS、CSP、CSRF、クリックジャッキング、XS-Leaks、サードパーティ JS）
languages:
- c
- html
- javascript
- php
- typescript
- vlang
alwaysApply: false
tags:
- web
---

rule_id: codeguard-0-client-side-web-security

## クライアントサイド Web セキュリティ

多層的かつコンテキスト対応のコントロールにより、ブラウザクライアントをコードインジェクション・リクエスト偽装・UI 詐欺・クロスサイトリーク・安全でないサードパーティスクリプトから保護してください。

### XSS 対策（コンテキスト対応）
- HTML コンテキスト：`textContent` を優先してください。HTML が必要な場合は、検証済みライブラリ（例: DOMPurify）と厳格な許可リストを使ってサニタイズしてください。
- 属性コンテキスト：常に属性をクォートし、値をエンコードしてください。
- JavaScript コンテキスト：信頼されていない文字列から JS を構築しないでください。インラインイベントハンドラーを避け、`addEventListener` を使用してください。
- URL コンテキスト：プロトコル/ドメインを検証してエンコードし、不適切な箇所では `javascript:` および data URL をブロックしてください。
- リダイレクト/フォワード：ユーザー入力をそのままリダイレクト先に使用してはいけません。サーバーサイドのマッピング（ID→URL）を使用するか、信頼済みドメインの許可リストに対して検証してください。
- CSS コンテキスト：値を許可リストで管理し、ユーザーからの生のスタイルテキストを絶対にインジェクトしないでください。

サニタイズの例：
```javascript
const clean = DOMPurify.sanitize(userHtml, {
  ALLOWED_TAGS: ['b','i','p','a','ul','li'],
  ALLOWED_ATTR: ['href','target','rel'],
  ALLOW_DATA_ATTR: false
});
```

### DOM ベース XSS と危険なシンク
- 信頼されていないデータに対して `innerHTML`、`outerHTML`、`document.write` を使用することを禁止してください。
- `eval`、`new Function`、文字列ベースの `setTimeout/Interval` を禁止してください。
- `location` やイベントハンドラープロパティに代入する前にデータを検証・エンコードしてください。
- DOM クロッバリングによるグローバル名前空間汚染を防ぐため、strict モードと明示的な変数宣言を使用してください。
- DOM シンクの悪用を防ぐため、Trusted Types を採用し厳格な CSP を適用してください。

Trusted Types + CSP の例：
```http
Content-Security-Policy: script-src 'self' 'nonce-{random}'; object-src 'none'; base-uri 'self'; require-trusted-types-for 'script'
```

### Content Security Policy (CSP)
- ドメイン許可リストよりも nonce ベースまたはハッシュベースの CSP を優先してください。
- Report‑Only モードから始めて違反を収集し、その後適用してください。
- 目指すべきベースライン：`default-src 'self'; style-src 'self' 'unsafe-inline'; frame-ancestors 'self'; form-action 'self'; object-src 'none'; base-uri 'none'; upgrade-insecure-requests`

### CSRF 対策
- まず XSS を修正し、その後 CSRF 対策を重ねてください。
- フレームワーク固有の CSRF 保護機能と、状態を変更するすべてのリクエストに対する同期トークンを使用してください。
- Cookie の設定：`SameSite=Lax` または `Strict`、セッションには `Secure` と `HttpOnly`、可能であれば `__Host-` プレフィックスを使用してください。
- Origin/Referer を検証し、SPA トークンモデルの API ミューテーションにはカスタムヘッダーを要求してください。
- 状態変更に GET を使用してはいけません。トークンの検証は POST/PUT/DELETE/PATCH のみで行ってください。すべてのトークン転送で HTTPS を強制してください。

### クリックジャッキング対策
- 優先：`Content-Security-Policy: frame-ancestors 'none'` または特定の許可リストを使用してください。
- レガシーブラウザへのフォールバック：`X-Frame-Options: DENY` または `SAMEORIGIN` を使用してください。
- フレーミングが必要な場合は、機密性の高い操作に対して UX 確認を検討してください。

### クロスサイトリーク（XS‑Leaks）対策
- `SameSite` Cookie を適切に使用し、機密性の高い操作では `Strict` を優先してください。
- 不審なクロスサイトリクエストをブロックするために Fetch Metadata 保護を採用してください。
- 該当箇所では COOP/COEP および CORP を使用してブラウジングコンテキストを分離してください。
- キャッシュプロービングを防ぐため、機密性の高いレスポンスのキャッシュを無効化してユーザー固有のトークンを追加してください。

### サードパーティ JavaScript
- 最小化と分離：`sandbox` および postMessage オリジン確認を伴うサンドボックス化された iframe を優先してください。
- 外部スクリプトにはサブリソースインテグリティ（SRI）を使用し、変更を監視してください。
- ファーストパーティのサニタイズ済みデータレイヤーを提供し、可能な限りタグからの直接 DOM アクセスを拒否してください。
- タグマネージャーコントロールとベンダー契約でガバナンスを行い、ライブラリを常に最新の状態に保ってください。

SRI の例：
```html
<script src="https://cdn.vendor.com/app.js"
  integrity="sha384-..." crossorigin="anonymous"></script>
```

### HTML5、CORS、WebSockets、ストレージ
- postMessage：常に正確なターゲットオリジンを指定し、受信時は `event.origin` を検証してください。
- CORS：`*` を避け、オリジンを許可リストで管理し、プリフライトを検証してください。認可に CORS を頼らないでください。
- WebSockets：`wss://`、オリジン確認、認証、メッセージサイズ制限、安全な JSON パースを必須としてください。
- クライアントストレージ：`localStorage`/`sessionStorage` に機密情報を保存してはいけません。HttpOnly Cookie を優先し、どうしても避けられない場合は Web Workers を通じて分離してください。
- リンク：外部の `target=_blank` リンクには `rel="noopener noreferrer"` を付与してください。

### HTTP セキュリティヘッダー（クライアントへの影響）
- HSTS：すべての場所で HTTPS を強制してください。
- X‑Content‑Type‑Options：`nosniff` を設定してください。
- Referrer‑Policy と Permissions‑Policy：機密性の高いシグナルと機能を制限してください。

### AJAX と安全な DOM API
- 動的コード実行を避け、文字列ではなく関数コールバックを使用してください。
- JSON は文字列連結ではなく `JSON.stringify` で構築してください。
- 生の HTML 挿入よりも、要素を作成して `textContent` や安全な属性を設定することを優先してください。

### 実装チェックリスト
- すべてのシンクに対するコンテキスト別エンコード/サニタイズ；ガードなしの危険な API を使用しない。
- nonce と Trusted Types を用いた厳格な CSP；違反を監視する。
- 状態を変更するすべてのリクエストに CSRF トークン；セキュアな Cookie 属性を設定する。
- フレーム保護を設定；XS-Leak 軽減策（Fetch Metadata、COOP/COEP/CORP）を有効化する。
- SRI とサンドボックスでサードパーティ JS を分離；検証済みデータレイヤーのみを使用する。
- HTML5/CORS/WebSocket の使用をハードニング；Web ストレージに機密情報を保存しない。
- セキュリティヘッダーを有効化して検証する。

### テスト計画
- 危険な DOM/API パターンの自動チェック。
- CSRF とクリックジャッキングの E2E テスト；CSP レポートの監視。
- XS-Leaks（フレームカウント・タイミング・キャッシュ）とオープンリダイレクトの挙動を手動で調査する。
