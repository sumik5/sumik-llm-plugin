# APIスタイル横断パターン

どのAPIスタイルを選んでも、設計フェーズで必ず直面するパターン群を整理する。
本ファイルは**選定文脈での要約**を提供する。詳細な実装ガイドは `developing-web-apis/references/DESIGN-*` ファイルを参照すること。

---

## 1. 命名規則（Naming）

APIのインターフェース名・フィールド名・パラメータ名には英語（American English 推奨）を使う。
名称は表現力・直感性・文脈一致性を優先し、命名規則（camelCase / snake_case / kebab-case）をスタイル全体で統一する。

### Resource-Oriented vs Intent-Oriented

| 設計方針 | 名前の特徴 | 採用スタイル | 例 |
|---------|----------|------------|-----|
| **Resource-Oriented（リソース指向）** | 名詞中心・HTTP 動詞で操作 | REST | `GET /orders`, `DELETE /orders/{id}` |
| **Intent-Oriented（意図指向）** | 動詞中心・操作名を表現 | gRPC, GraphQL Mutation, ブローカー型 | `CreateOrder()`, `archiveUser` |

- REST は**宣言的**（「リソースの最終状態」を指定）— リソースを名詞で表し、HTTP 動詞が操作を担う
- gRPC は**命令的**（「操作の手順」を指定）— アクション名でRPCメソッドを定義する
- GraphQL は宣言的クエリ＋命令的ミューテーションの**混合**

---

## 2. 後方互換性・前方互換性

### 後方互換性（Backward Compatibility）

既存クライアントを壊さない変更のこと。**追加的変更（Additive Changes）** は後方互換を維持しやすい。

| 変更種別 | 後方互換性 |
|---------|----------|
| フィールド追加 | ✅ 維持（クライアントが無視できる） |
| データ型変更 | ❌ 破壊的変更 |
| フィールド名変更・削除 | ❌ 破壊的変更 |
| エンドポイント削除 | ❌ 破壊的変更 |

クライアント-サーバー型（REST, GraphQL, gRPC）では特に重要。破壊的変更が必要な場合は新バージョンをリリースし、旧バージョンの廃止計画を消費者に事前通知する。

### 前方互換性（Forward Compatibility）

新しいコンシューマーが旧バージョンのメッセージを読める能力。

- **ブローカー型・EDA（イベント駆動型）** では前方互換性が特に重要
  - メッセージが長期間キューに残る可能性があるため
  - 異なるバージョンのプロデューサーとコンシューマーが同時に稼働する

> **Trade-Off**: コンポーネントの疎結合（メリット）と前方・後方の両互換性保証（コスト）はトレードオフ。
> ブローカー型は疎結合で柔軟性が高い半面、メッセージスキーマの後方・前方互換性の管理が複雑になる。

---

## 3. APIバージョニング

APIは**契約（Contract）** と見なす。コントラクト変更を安全に管理するためのバージョニング戦略が必要。

### バージョニング方式の比較

| 方式 | 例 | 粒度 | 向いているスタイル |
|-----|---|------|-----------------|
| **パス指定** | `/api/v1/orders` | API 全体 | REST |
| **クエリパラメータ** | `/orders?api-version=v1` | リクエスト単位 | REST |
| **ヘッダー指定** | `Api-Version: v1` | リクエスト単位 | REST |
| **メッセージペイロード** | `{"version": "v1", "data": ...}` | メッセージ単位 | ブローカー型, EDA |
| **フィールドリネーム** | `updateOrderV2` | 操作単位 | GraphQL |
| **パッケージ/サービス名** | `package orders.v2;` | サービス単位 | gRPC |

### バージョンフォーマット

- **Semantic Versioning**: `MAJOR.MINOR.PATCH`（破壊的変更 → MAJOR）
- **Calendar Versioning**: `2024-11-01`（日付ベース）
- **Hash Versioning**: `237a2b4f`（コミットハッシュ等）

バージョン変更は changelog・Atom フィード・レスポンスのメタデータフィールド等で事前通知する。

> 詳細な実装パターンは `developing-web-apis/references/DESIGN-VERSIONING.md` を参照。

---

## 4. ページネーション

大量データを「ページ」（チャンク）単位で返す設計パターン。
主なアプローチは**オフセットベース**と**カーソルベース**の2種類。

### オフセットベースページネーション（Offset-Based）

```
GET /api/orders?page=2&page_size=100
→ { "count": 1478, "next": "?page=3&page_size=100", "results": [...] }

GET /api/orders?limit=100&offset=400
→ { "count": 1478, "next": "?limit=100&offset=500", "results": [...] }
```

| 評価軸 | 内容 |
|-------|-----|
| ✅ 利点 | 全ページ数の推定が可能・任意ページへのジャンプが容易 |
| ❌ 欠点 | 大規模データで遅延（DB が全 offset を読み飛ばす）・削除/挿入時に重複・欠落が生じる |

### カーソルベースページネーション（Cursor-Based）

```
GET /api/orders?limit=100
→ { "next": "123abc", "results": [...] }

GET /api/orders?limit=100&next=123abc
→ { "next": "456cde", "results": [...] }
```

カーソルはデータセット内の位置ポインター（一意かつ順序を持つ値を Base64 エンコード）。
`next` が空の場合は末尾到達を示す。

| 評価軸 | 内容 |
|-------|-----|
| ✅ 利点 | 大規模・動的データに高性能（カーソル位置から直接取得）・削除/挿入による重複・欠落が少ない |
| ❌ 欠点 | 任意ページへのジャンプが困難・実装が複雑 |

**選定基準:**
- ライブフィード・頻繁な変更データ → カーソルベース
- 管理画面・固定データセット → オフセットベース

> 詳細は `developing-web-apis/references/DESIGN-RESPONSE.md` を参照。

---

## 5. 長時間タスク（Long-Running Tasks）

処理時間がリクエストタイムアウトを超えるタスク（動画処理・バッチ集計・機械学習等）の管理パターン。

```
POST /api/jobs         → 202 Accepted, { "job_id": "xxx" }
GET  /api/jobs/xxx     → { "status": "processing", "progress": 45 }
GET  /api/jobs/xxx     → { "status": "completed", "result_url": "..." }
```

- タスクの状態を State Machine で管理（`queued` → `processing` → `completed` / `failed`）
- キャンセル・一時停止等のカスタムアクションは `?action=cancel` 等のクエリパラメータで表現
- 完了通知の戦略:
  - **ポーリング**: シンプルだがリクエスト過多になりうる
  - **Webhook**: 完了イベントを push（ポーリング不要・サーバー → クライアント一方向）
  - **WebSocket / SSE**: リアルタイム進捗通知（双方向接続が必要）

---

## 6. リクエスト重複排除・冪等性

### リクエスト重複排除（Request Deduplication）

クライアントが一意な `request_id`（UUID 推奨）をリクエストに含め、
APIは同じ `request_id` の二重送信を検知して同一レスポンスを返す（または重複エラー）。

```
POST /api/orders
Idempotency-Key: "550e8400-e29b-41d4-a716-446655440000"
→ 初回: 201 Created / 二回目: 200 OK (前回と同じレスポンスを返す)
```

### リトライ戦略

| 戦略 | 説明 |
|-----|-----|
| **最大リトライ数** | 上限回数を超えたらリトライ停止 |
| **指数バックオフ** | リトライ間隔を指数的に増加（2s → 4s → 8s…） |
| **タイミングジッター** | ランダム遅延を追加して集中リトライ（リトライストーム）を防ぐ |
| **サーキットブレーカー** | 失敗率が閾値を超えたら一時的にリクエストを遮断 |

HTTP サーバーは `Retry-After` ヘッダーでリトライタイミングを指示できる。

> **冪等性の原則:** 非冪等な操作（決済・注文確定等）は `Idempotency-Key` ヘッダーで重複排除する。
> HTTP 標準の冪等メソッド（GET / PUT / DELETE）はリトライが安全。POST は非冪等なため要注意。

> 詳細設計は `developing-web-apis/references/DESIGN-ENDPOINT.md` を参照。

---

## 7. レートリミット（Rate Limiting / Throttling）

単位時間あたりのリクエスト数を制限し、APIを過負荷・悪用から保護する。

**基本戦略:**
- クライアント識別子（IP アドレス・API キー・ユーザーID）でスロットリング
- ネットワークパスの早い段階（API Gateway 等）で適用することで後段のリソースを保護
- DoS / DDoS 攻撃の軽減に有効（ただし分散型 DDoS への完全対策は不十分）

**HTTP レスポンス例:**
```
HTTP/1.1 429 Too Many Requests
Retry-After: 60
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1735689600
```

**スタイル別の適用形態:**

| スタイル | レートリミットの適用点 |
|---------|-------------------|
| REST / GraphQL | API Gateway / リバースプロキシで HTTP レベルに適用 |
| gRPC | HTTP/2 フロー制御＋ API Gateway のリクエスト数制限 |
| Webhook | ソースシステム側の送信頻度制限・受信側での制限 |
| WebSocket | 接続数制限＋メッセージ送信レートの制限 |
| ブローカー型 | キューの深さ制限・コンシューマーの処理速度でバックプレッシャー制御 |

> 詳細な実装パターンは `developing-web-apis/references/DESIGN-SECURITY.md` を参照。

---

## 8. キャッシング（Caching）

レスポンスを一時保存し、繰り返しリクエストのコストを削減する。

### クライアントサイドキャッシング

| HTTP ヘッダー | 役割 |
|------------|-----|
| `Cache-Control: max-age=3600` | TTL（有効期間）の指定 |
| `ETag: "abc123"` | リソースバージョン識別（条件付きリクエストに使用） |
| `Last-Modified: ...` | 最終更新日時によるキャッシュ検証 |

### サーバーサイドキャッシング

- バックエンド負荷軽減・応答速度向上
- インメモリキャッシュ（高速）または分散キャッシュ（水平スケール対応）
- キャッシュ無効化戦略が重要（stale data リスク）

**スタイル別キャッシュ適性:**

| スタイル | キャッシュ適性 | 備考 |
|---------|------------|------|
| REST | ✅ 高（HTTP キャッシュが標準） | `GET` はデフォルトでキャッシュ可 |
| GraphQL | ⚠️ 要工夫（`POST` ベース → HTTP キャッシュが効きにくい） | Persisted Query・CDN でカスタム対応が必要 |
| gRPC | ⚠️ 限定的（Unary RPC は条件付きで可） | streaming はキャッシュ不向き |
| Webhook | ❌ 非適用（プッシュ型） | — |
| WebSocket | ❌ 非適用（双方向通信） | — |
| ブローカー型 | ❌ 非適用（メッセージキューは別コンセプト） | — |

> 詳細は `developing-web-apis/references/DESIGN-HTTP-SPEC.md` のキャッシュ関連セクションを参照。

---

## 9. APIセキュリティ（OWASP API Top 10）

[OWASP API Security Top 10](https://owasp.org/API-Security/) の脅威カテゴリを3つに集約する。

### 主要リスクカテゴリ

**認証・認可の問題:**
- 不正実装による他ユーザーへのなりすまし
- 特権昇格攻撃（Privilege Escalation）
- 弱いパスワード・認証トークンへのブルートフォース攻撃

**インベントリ管理の問題:**
- ファイアウォール・TLS の設定ミス
- ログへの機密情報漏洩・パッチ未適用
- MITM（中間者）攻撃・SQL インジェクション・XSS

**リソース管理の問題:**
- API 使用量の未監視
- 外部有料サービス（SMS・メール等）への不正呼出による課金増大
- DoS 攻撃によるサービス停止

### スタイル別セキュリティ考慮点

| スタイル | 重点セキュリティ事項 |
|---------|-------------------|
| REST | OAuth 2.0 + JWT・HTTPS 強制・レートリミット |
| GraphQL | 深いクエリ制限（Depth Limit）・クエリコスト分析・本番でのイントロスペクション無効化 |
| gRPC | mTLS（相互 TLS）によるサービス間認証 |
| Webhook | ペイロード署名検証（HMAC）・HTTPS エンドポイント必須・配信リトライの冪等性 |
| WebSocket | Origin ヘッダー検証・JWT 認証・接続数制限 |
| ブローカー型 | メッセージ認証・TLS・ACL（アクセス制御リスト） |

> 詳細な脅威モデルと対策は `developing-web-apis/references/DESIGN-SECURITY.md` を参照。
> 体系的な各項目の検出・修正は `web:securing-web-apis` を参照。

---

## 10. ベストプラクティス（横断）

スタイルを問わず共通する設計原則の要約。

| 原則 | 内容 |
|-----|-----|
| **ドキュメント先行** | 設計前に API 仕様（OpenAPI / Protobuf Schema / AsyncAPI）を記述 |
| **一貫した命名** | スタイル内で camelCase / snake_case 等を統一 |
| **エラー応答の統一** | エラーコード・メッセージ形式を全エンドポイントで統一 |
| **ヘルスチェック** | `/health`, `/readiness` エンドポイントを提供 |
| **変更の事前通知** | changelog・Atom フィード・メタデータで破壊的変更を通知 |
| **削除方針の明確化** | soft-delete / hard-delete の使い分けとクライアントへの影響を事前設計 |

---

## 参照先（実装詳細）

本ファイルは選定文脈での概要を提供する。各パターンの詳細実装は以下を参照:

| 参照先 | 内容 |
|-------|-----|
| `developing-web-apis/references/DESIGN-VERSIONING.md` | バージョニング実装の詳細 |
| `developing-web-apis/references/DESIGN-SECURITY.md` | セキュリティ実装・OWASP 対策の詳細 |
| `developing-web-apis/references/DESIGN-ENDPOINT.md` | エンドポイント設計・冪等性・CRUD の詳細 |
| `developing-web-apis/references/DESIGN-HTTP-SPEC.md` | HTTP ヘッダー・キャッシュ・ステータスコードの詳細 |
| `developing-web-apis/references/DESIGN-RESPONSE.md` | レスポンス設計・ページネーション実装の詳細 |
| `developing-web-apis/references/DESIGN-CHECKLIST.md` | API 設計チェックリスト |
