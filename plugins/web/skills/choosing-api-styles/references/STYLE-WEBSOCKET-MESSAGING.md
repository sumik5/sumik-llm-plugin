# STYLE-WEBSOCKET-MESSAGING.md

WebSocket（双方向リアルタイム）とブローカー型メッセージング（非同期・疎結合）の
選定ガイド。両スタイルのプロトコル・特性・トレードオフ・利用判断基準を記述する。

---

## WebSocket

### 概要

WebSocket は RFC 6455 で標準化された双方向通信プロトコル。HTTP の要求-応答モデルを
離れ、1本の永続 TCP 接続上でクライアントとサーバーが同時にメッセージを送受信できる
**full-duplex** 伝送モードを提供する。

HTTP ベースの SSE（Server-Sent Events）やロングポーリングは "サーバー → クライアント"
の単方向性に留まるが、WebSocket は両方向の独立したメッセージ送信を可能にする点が本質的
な差異である。

---

### オープニングハンドシェイク

接続確立は HTTP/1.1 のプロトコルアップグレード機構（101 Switching Protocols）を使う
3ステップ手順。

**クライアントリクエスト（必須ヘッダー）**

```http
GET /ws/v1/events HTTP/1.1
Host: api.example.com
Connection: keep-alive, Upgrade
Upgrade: websocket
Sec-WebSocket-Key: <base64-encoded-16-bytes>
Sec-WebSocket-Version: 13
```

| ヘッダー | 役割 |
|---------|------|
| `Upgrade: websocket` | プロトコル切り替え要求 |
| `Sec-WebSocket-Key` | ハンドシェイク検証用ランダム値（Base64・16バイト） |
| `Sec-WebSocket-Version: 13` | WebSocket プロトコルバージョン（13 が唯一の有効値） |
| `Origin` | クライアントの origin（サーバー側 Origin 検証に使用） |

**サーバーレスポンス**

```http
HTTP/1.1 101 Switching Protocols
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Accept: <derived-from-key>
```

101 受信後、TCP コネクションは WebSocket プロトコルに切り替わり、以後 HTTP は使わない。

---

### 伝送特性

| 特性 | 内容 |
|------|------|
| 伝送モード | full-duplex（同時双方向送受信） |
| 接続 | 単一の永続 TCP 接続を維持 |
| ヘッダーオーバーヘッド | メッセージごとのHTTPヘッダーなし（data frame のみ） |
| データ型 | テキスト／バイナリ両対応（data frame 単位） |
| 同期性 | プロトコル規格は非依存。非同期実装が主流（接続多重管理・応答性向上） |

> **gRPC streaming との双方向重複について**: gRPC も bidirectional streaming RPC で
> 双方向通信を提供する。プロトコル特性・ブラウザ対応・型安全性の軸での両者比較は
> `SELECTION-MATRIX.md` の決定木を参照。

---

### セキュリティ

WebSocket は HTTP ベースの標準認証が「ハンドシェイク時に1回だけ」適用される点が設計上
の特徴。接続確立後は HTTP ヘッダーを送れないため、以下の対策を組み合わせる。

#### Origin 検証

WebSocket 仕様は origin-based セキュリティモデルを定義する。サーバーはオープニング
ハンドシェイクの `Origin` ヘッダーを検証し、許可された origin からの接続のみを受け入れる
（same-origin policy に類似した役割）。

#### Trusted Host 制限

`Host` ヘッダーを許可リストと照合し、HTTP host header attack を防止する。

#### トークン認証（JWT）

WebSocket ではハンドシェイク時にカスタムヘッダーを送れない制約があるため、アクセストークン
（JWT 等）は**クエリパラメーター**として渡すことが一般的。

```
wss://api.example.com/ws/v1/events?access_token=<base64-encoded-jwt>&topic_id=<uuid>
```

サーバーはハンドシェイク時にトークンを検証し、接続確立後は以降のフレームを信頼する
（ポスト接続の追加認証が必要な場合は application レベルで各フレームを検証する）。

#### TLS（WebSocket Secure）

`ws://` → `wss://` で TLS を有効化。転送中データを暗号化・完全性保護する。
本番環境では必須。自己署名証明書はテスト用途に限定する。

---

### AsyncAPI によるドキュメント

WebSocket API の仕様は AsyncAPI（Linux Foundation 傘下のオープン仕様）で記述する。
OpenAPI の非同期版に相当し、YAML/JSON 形式でポータブルに共有できる。

```yaml
asyncapi: 3.0.0
defaultContentType: application/json
info:
  title: イベント通知 API
  version: v1
operations:
  receiveEvent:
    action: receive
    summary: イベントチャンネルからメッセージを受信
    channel:
      $ref: '#/channels/event'
    bindings:
      ws:
        query:
          type: object
          required: [access_token, topic_id]
          properties:
            access_token: { type: string }
            topic_id: { type: string }
channels:
  event:
    address: /ws/v1/events
    messages:
      notification:
        $ref: '#/components/messages/Notification'
components:
  messages:
    Notification:
      contentType: application/json
      payload:
        type: object
        properties:
          message: { type: string }
```

---

### Trade-Offs

#### 利点

| 利点 | 説明 |
|------|------|
| 双方向 full-duplex | クライアント・サーバー双方が独立してメッセージを送信可能 |
| 低レイテンシ | 永続接続により毎回 TCP ハンドシェイクが不要。data frame にHTTPヘッダーなし |
| 高応答性 | チャット・ダッシュボード・ゲーム・アラートなどリアルタイム UX に最適 |
| バイナリ対応 | テキスト・バイナリ両データ型をネイティブサポート |
| HTTP 互換性 | ポート 80/443 を使用するため多くのプロキシ・ロードバランサーを通過可能 |
| 拡張性 | プロトコル拡張（multiplexing 等）をハンドシェイク時のネゴシエーションで追加可能 |

#### 欠点

| 欠点 | 説明 |
|------|------|
| ステートフル・スケール難 | 接続ごとにサーバーがセッション状態を保持。水平スケールで既存接続の移行が複雑 |
| キャッシュ不可 | メッセージは都度異なる可能性があり、HTTP キャッシュ機構が適用できない |
| 脆弱な接続 | ネットワーク障害による切断が発生しやすい。指数バックオフ付き再接続ロジックが必要（thundering herd 問題に注意） |
| アプリ層 ACK なし | TCP の信頼性は継承するが、接続断時の in-flight メッセージはアプリ側で再送制御が必要 |
| 認証の課題 | 接続確立後に追加認証が必要な場合はフレームレベルでの実装が必要。Origin ヘッダーは偽装可能 |
| バックプレッシャー管理 | アプリ層でのバックプレッシャー制御（集約・圧縮・重複排除・剪定）は手動実装が必要 |
| 大量接続時のメモリ負荷 | 各接続の状態を保持するためサーバーメモリ消費が増加 |

---

### When to Use WebSocket

**推奨シナリオ:**

- **双方向リアルタイム通信**が必要（チャット・コラボレーションツール・オンラインゲーム）
- **低レイテンシのプッシュ通知**（アラート・モニタリングダッシュボード・金融ティッカー）
- **インタラクティブ UI**でサーバーからの任意タイミングのデータ送信が必要
- ブラウザクライアントが存在し、ネイティブ WebSocket API が利用可能な環境

**避けるべきシナリオ:**

- 単純な要求-応答で十分な場合（REST/gRPC が適切）
- サーバー→クライアントの一方向通知のみ（SSE が低コスト）
- 大量の独立したステートレスクライアントを水平スケールする場合（ブローカー型が適切）
- 長時間の非同期ジョブ処理（ブローカー型メッセージングが適切）

---

---

## ブローカー型メッセージング

### 概要

ブローカー型メッセージングは、プロデューサー（送信側）とコンシューマー（受信側）の間に
**ブローカー（仲介サーバー）**を挟み、メッセージを非同期に配送するアーキテクチャスタイル。
代表的な実装: RabbitMQ（AMQP）・Apache Kafka（分散ログ）・Amazon SQS 等。

直接クライアント-サーバー通信と異なり、プロデューサーとコンシューマーは互いの存在を
意識せず、ブローカーとのみ接続する（**疎結合**）。

---

### 主要コンセプト

#### RabbitMQ / AMQP のメッセージフロー

```
Producer → Exchange → Queue → Consumer
```

| コンポーネント | 役割 |
|--------------|------|
| Producer | メッセージをブローカーに送信するクライアント |
| Consumer | ブローカーからメッセージを受信するクライアント |
| Exchange | ルーティングキー・exchange 種別に基づきキューへメッセージを転送（direct / fanout / topic / headers） |
| Queue | FIFO 順でメッセージを格納するバッファ |
| Channel | 単一 TCP 接続内の仮想接続路（AMQP 多重化） |
| Routing Key | exchange がメッセージをキューへルーティングする際に参照するアドレス |
| Binding | exchange とキューの関連付け |
| Correlation ID (CID) | 要求-応答パターンでリクエストとレスポンスを対応付けるユニーク ID |
| Acknowledgment | コンシューマーからブローカーへの「受信成功」確認信号 |

---

### メッセージングパターン

| パターン | 概要 | 主な用途 |
|---------|------|---------|
| **Work Queue** | 1つのキューから複数コンシューマーが競合取得（ラウンドロビン分配） | 負荷分散・並列タスク処理 |
| **Pub/Sub** | 1メッセージを複数コンシューマーへファンアウト配信 | 通知・アラート・ブロードキャスト |
| **Routing** | ルーティングキーに基づいてコンシューマーを選別（完全一致） | ログレベル分岐・カテゴリ振り分け |
| **Topics** | ワイルドカード（`*`・`#`）パターンでコンシューマーを選別 | 属性ベースの柔軟なルーティング |
| **Request-Response** | ブローカー経由でリクエスト→レスポンスを実現（CID で対応付け） | 非同期 RPC・マイクロサービス間連携 |

#### AsyncAPI スニペット（Work Queue 例）

```yaml
asyncapi: 3.0.0
defaultContentType: application/json
channels:
  TaskQueue:
    address: task_queue
    bindings:
      amqp:
        is: queue
        queue: { durable: true, vhost: / }
operations:
  Publish:
    action: send
    channel: { $ref: '#/channels/TaskQueue' }
    bindings:
      amqp: { deliveryMode: 2 }   # 2 = persistent
  Consume:
    action: receive
    channel: { $ref: '#/channels/TaskQueue' }
    bindings:
      amqp: { ack: true }         # 手動 ACK
```

---

### 配信保証

| 保証レベル | 動作 | RabbitMQ での実現 |
|-----------|------|-----------------|
| At-least-once | 必ず1回以上配信（重複あり） | 手動 ACK + publisher confirms |
| At-most-once | 最大1回配信（消失リスクあり） | 自動 ACK（`auto_ack=True`） |
| Exactly-once | 正確に1回（難易度高） | at-least-once + アプリレベル重複排除 |

> **重要**: キューを `durable=True`・メッセージを `PERSISTENT_DELIVERY_MODE` に設定しても、
> ブローカークラッシュ時の時間窓でメッセージが消失するリスクは残る。強固な配信保証には
> "publisher confirms" パターンを組み合わせる。

---

### セキュリティ

| 手法 | 説明 |
|------|------|
| TLS（AMQPS） | AMQP over TLS。転送中メッセージを暗号化。ポート 5671 を使用（5672 は平文） |
| mTLS | クライアント・サーバー双方の証明書を相互検証（強固な認証） |
| SASL 認証 | PLAIN（ユーザー名/パスワード）・EXTERNAL 等の認証メカニズム。PLAIN は TLS と組み合わせて使用 |
| 仮想ホスト（vhost） | マルチテナント分離。リソース（exchange・queue）を論理的に分割 |
| ACL（アクセス制御） | ユーザーへの `read` / `write` / `configure` 権限を正規表現パターンで付与 |

デフォルト認証情報の変更は必須（OWASP API Security Top 10 の指摘事項に該当）。

---

### Trade-Offs

#### 利点

| 利点 | 説明 |
|------|------|
| 配信保証 | at-least-once / at-most-once 配信をプロトコルレベルで選択可能 |
| 高スループット | メッセージングシステムは大量メッセージを低レイテンシで処理するよう設計されている |
| スケーラビリティ | コンシューマーの水平スケールアウト・ブローカーのクラスタリングが容易 |
| 耐障害性 | コンシューマーが停止中もキューがメッセージを保持。復帰後に継続処理可能 |
| 疎結合 | プロデューサーとコンシューマーがブローカーのみを知る。独立してデプロイ・スケール・保守可能 |
| 応答性 | 一部の実装では 2 ms 以下のレイテンシを達成（高頻度トレードシステム等に適用） |
| 非同期処理 | 長時間タスクをコンシューマーにオフロードし、プロデューサーをノンブロッキングに保てる |

#### 欠点

| 欠点 | 説明 |
|------|------|
| 実装の複雑さ | キュー・exchange・ACK 方式・配信保証の選択など設計判断が多い |
| プロトコル結合 | プロデューサーとコンシューマーは同一メッセージプロトコル（AMQP 等）に依存 |
| メッセージスキーマ結合 | スキーマ変更（フィールドの削除・リネーム）が両側に影響する破壊的変更になりうる |
| ブローカーの単一障害点 | ブローカー停止で全通信が途絶する。HA クラスタ設定が必要 |
| メッセージ重複 | at-least-once では重複が発生しうる。コンシューマーの冪等処理設計が必要 |
| 順序保証の困難 | FIFO 以外の順序（LIFO・優先度）は追加実装が必要 |
| 累積レイテンシ | プロデューサー→ブローカー→コンシューマーの複数ホップで遅延が増加 |
| デバッグの困難 | 非同期・分散環境でのトレース。CID を用いたログ相関が必要 |
| エラーハンドリング | 非同期ゆえ即時エラー検知が困難。DLQ（Dead Letter Queue）の設計が必要 |
| 高コスト | インフラ・運用・トレーニング・異種システムとの統合コストが高い |

---

### When to Use ブローカー型メッセージング

**推奨シナリオ:**

- **配信保証**が必要な業務（金融取引・医療通知・決済）
- **大量非同期ジョブ**の分散処理（動画変換・メール送信・バッチ ETL）
- **マイクロサービス間の疎結合連携**（独立スケール・異言語サービス間通信）
- **負荷の平滑化**（突発的なトラフィックピーク時にキューをバッファとして機能させる）
- **イベント駆動アーキテクチャ（EDA）**の構築
- 同期 REST 呼び出しを起点に後続処理を非同期化する「ファイア・アンド・フォーゲット」パターン

**避けるべきシナリオ:**

- 即時応答が必須の要求-応答（ユーザー認証・在庫確認など）→ REST / gRPC が適切
- ブラウザ-サーバー間のリアルタイム双方向通信 → WebSocket が適切
- シンプルなコールバック通知のみ → Webhook が低コスト
- チーム規模・運用リソースが限定的でブローカーの運用負荷に耐えられない場合

---

### WebSocket vs ブローカー型 早見表

| 軸 | WebSocket | ブローカー型 |
|----|-----------|------------|
| 接続モデル | クライアント-サーバー直接・永続接続 | クライアント-ブローカー-クライアント |
| 伝送モード | full-duplex（双方向同時） | 非同期（producer→broker→consumer） |
| 配信保証 | TCP 信頼性のみ（アプリ層は手動） | at-least/at-most/exactly-once を選択可 |
| スケール特性 | ステートフル・水平スケール困難 | ステートレス疎結合・水平スケール容易 |
| レイテンシ | 超低レイテンシ（永続接続） | ブローカー経由の累積レイテンシあり |
| ブラウザ対応 | ネイティブ WebSocket API | クライアントライブラリ要 |
| 主用途 | リアルタイム双方向 UI | 大量非同期処理・サービス間連携 |
| 運用コスト | 中（接続管理・再接続ロジック） | 高（ブローカー運用・クラスタ管理） |

> 詳細な7スタイル横断比較は `SELECTION-MATRIX.md` を参照。
