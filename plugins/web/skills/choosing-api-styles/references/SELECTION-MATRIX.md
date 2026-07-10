# APIスタイル選定マトリクス

7つのAPIスタイルを6つの評価軸で比較し、ユースケースに最適なスタイルを選定するためのリファレンス。
確定分類表・ユースケース別早見表・決定木・チェックリストで意思決定を一元支援する。

---

## 1. スタイル分類表（確定値）

> この表の数値・区分は本スキルの他のファイルと共有する確定値。創作・変更不可。

| 特性 | REST | GraphQL | Webフィード | gRPC | Webhook | WebSocket | ブローカー型 |
|-----|------|---------|-----------|------|---------|----------|------------|
| **代表技術** | REST | GraphQL | Atom/RSS | gRPC | Webhook | WebSocket | RabbitMQ/Kafka |
| **プロトコル** | HTTP | HTTP(+WS) | HTTP | HTTP/2 | HTTP | WebSocket | AMQP 等 |
| **通信種別** | 同期 | 同期 | 非同期 | 同期 | 非同期 | 非同期 | 非同期 |
| **バイナリ対応** | Yes | Partial | Partial | Yes | Yes | Yes | Yes |
| **応答性** | 中 | 中 | 中 | 高 | 中 | 高 | 高 |
| **開発労力** | 中 | 中 | 低 | 高 | 低 | 中 | 高 |
| **スタイル分類** | Resource | Query | Web feed | RPC | Callback | Bidirectional | Broker-based |

### gRPC の二重帰属

gRPC は **RPC（主分類）** として分類されるが、4 種類の RPC 型のうち **bidirectional streaming** は
WebSocket と同様の双方向全二重通信を実現する。

| gRPC の RPC 型 | 通信方向 | WebSocket との比較 |
|-------------|---------|-----------------|
| Unary | 要求-応答（1:1） | HTTP と同等・WebSocket 不要 |
| Server streaming | 1 要求:複数応答 | SSE に近い（サーバー→クライアント） |
| Client streaming | 複数送信:1 応答 | クライアント→サーバーの one-way stream |
| **Bidirectional streaming** | **双方向同時** | **WebSocket と競合・型安全性で優位** |

**gRPC vs WebSocket の選択基準:**
- 型安全性・コード生成（Protobuf）・マイクロサービス間通信 → **gRPC bidirectional streaming**
- ブラウザからの直接接続・柔軟なメッセージ形式・広いクライアント互換性 → **WebSocket**

> gRPC はネイティブでブラウザ非対応（grpc-web / プロキシが必要）。この制約が選択の分岐点になる。

### GraphQL の Subscription

GraphQL の通常の Query / Mutation は HTTP 同期通信だが、**Subscription** は WebSocket を利用する（非同期・双方向）。
Subscription を多用する場合は WebSocket インフラが必要になるため、WebSocket との比較検討が必要。

---

## 2. 6次元評価の詳細解説

### 通信種別（Communication Type）

| 種別 | 意味 | 対応スタイル |
|-----|-----|-----------|
| **同期（Synchronous）** | クライアントがレスポンスを待機（ブロッキング） | REST, GraphQL, gRPC（Unary/Server streaming） |
| **非同期（Asynchronous）** | クライアントは待機せず処理を継続 | Webフィード, Webhook, WebSocket, ブローカー型 |

### バイナリ対応（Binary Data Support）

| 値 | 意味 | 対象スタイル |
|---|-----|-----------|
| **Yes** | デフォルトでバイナリ転送をサポート | REST, gRPC, Webhook, WebSocket, ブローカー型 |
| **Partial** | アプリ層での実装が必要（Base64 エンコード等） | GraphQL, Webフィード |

gRPC は Protobuf によりバイナリが標準。REST はバイナリを `multipart/form-data` 等で転送可能。

### 応答性（Responsiveness）

"Reactive Manifesto" の定義に基づく分類:

- **高（High）**: 低レイテンシ・リアルタイム要件に適合 — gRPC・WebSocket・ブローカー型
  - gRPC: HTTP/2 多重化 + Protobuf の低オーバーヘッドで高スループット
  - WebSocket: 常時接続でメッセージ往復のヘッダー削減
  - ブローカー型: キューによる高スループット処理（ただし遅延あり）
- **中（Medium）**: 標準的な要求-応答 — REST・GraphQL・Webフィード・Webhook

### 開発労力（Development Effort）

最小限の機能 API を構築するための主観的工数:

| 工数 | 理由 | 対象スタイル |
|-----|-----|-----------|
| **低（Low）** | 既存 HTTP インフラを流用・専用プロトコル不要 | Webフィード, Webhook |
| **中（Medium）** | 成熟したライブラリ・標準的な HTTP | REST, GraphQL, WebSocket |
| **高（High）** | 専用インフラ・ツールチェーンが必要 | gRPC（Protobuf 定義・コード生成・HTTP/2）, ブローカー型（ブローカー運用・耐障害設計） |

---

## 3. ユースケース別早見表

| ユースケース | 推奨スタイル | 推奨理由 |
|-----------|-----------|---------|
| 公開 API（汎用 CRUD・広い互換性） | REST | HTTP クライアントの広範サポート・サードパーティ親和性 |
| モバイルアプリの柔軟なデータ取得 | GraphQL | 必要フィールドのみ取得（オーバーフェッチ防止） |
| マイクロサービス間の高性能 RPC | gRPC | Protobuf・HTTP/2 多重化・型安全なコード生成 |
| リアルタイムチャット・共同編集 | WebSocket | 双方向・低遅延・全二重通信 |
| 決済・在庫更新（SaaS パートナー連携） | Webhook | シンプルな HTTP コールバック・既存インフラ流用 |
| コンテンツ配信（ブログ・ポッドキャスト） | Webフィード（RSS/Atom） | pull 型・クライアントが能動的に購読 |
| 非同期ジョブキュー・大量メッセージ処理 | ブローカー型 | 疎結合・耐障害性・コンシューマーのスケールアウト容易 |
| gRPC ＋ ブラウザクライアント | gRPC（grpc-web 経由） | grpc-web / Envoy プロキシが必要 |
| 型安全な双方向通信（マイクロサービス） | gRPC bidirectional streaming | Protobuf + ストリーミング |
| 柔軟な双方向通信（ブラウザ） | WebSocket | ブラウザネイティブ対応・柔軟なメッセージ形式 |

---

## 4. ユースケース別決定木

```
スタイル選定フロー
│
├── [1] API消費者はブラウザか？
│   ├── Yes → gRPC native は直接利用不可（grpc-web / プロキシ必要）→ [2] へ
│   └── No  → すべてのスタイルが技術的に選択可 → [2] へ
│
├── [2] 通信の方向性は？
│   │
│   ├── 双方向リアルタイム（クライアント ↔ サーバー同時送受信）
│   │   ├── 型安全性・マイクロサービス間 → gRPC bidirectional streaming
│   │   └── ブラウザ・柔軟なメッセージ形式 → WebSocket
│   │
│   ├── サーバー → クライアントへの一方向通知（イベント駆動）
│   │   ├── 大量メッセージ・疎結合・コンシューマーのスケールが必要
│   │   │   → ブローカー型（RabbitMQ / Kafka）
│   │   ├── シンプルな HTTP コールバック（SaaS パートナー連携等）
│   │   │   → Webhook
│   │   └── コンテンツ配信（記事フィード・ポッドキャスト等）
│   │       → Webフィード（RSS/Atom）
│   │
│   └── 要求-応答（クライアント → サーバーへの明示的なリクエスト）→ [3] へ
│
├── [3] データ形状の要件は？
│   │
│   ├── クライアントが必要なフィールドを自由に指定したい
│   │   → GraphQL（Query-based）
│   │
│   ├── バイナリ性能重視・低レイテンシ・型安全なサービス間通信
│   │   → gRPC（Unary または Server streaming）
│   │
│   └── 標準的なリソース操作（CRUD）・広い互換性
│       → REST
│
└── [4] 補助判断（消費者・チーム習熟度）
    ├── ブラウザ / モバイル / サードパーティ（公開 API）
    │   → REST（広い互換性） / GraphQL（柔軟取得）
    ├── サービス間（内部 API・マイクロサービス）
    │   → gRPC（高性能） / ブローカー型（疎結合）
    ├── イベント購読者（パートナー・SaaS 連携）
    │   → Webhook / Webフィード
    └── チームの習熟度が低い → 開発労力の低いスタイルを優先（REST / Webhook / Webフィード）
```

---

## 5. 意思決定チェックリスト

選定前に以下を確認する:

### 機能要件
- [ ] 通信の方向（一方向 / 双方向 / イベント駆動）を定義したか
- [ ] 同期（即時レスポンスが必要）か非同期か判断したか
- [ ] クライアントの種類（ブラウザ / モバイル / サービス間）を特定したか
- [ ] データ形状（固定スキーマ / 柔軟取得 / バイナリ）を定義したか

### 非機能要件
- [ ] 応答性の要件（低レイテンシ / 許容範囲）を設定したか
- [ ] 開発リソース・チームの習熟度を考慮したか
- [ ] スケーラビリティ要件（大量メッセージ / 高スループット）を評価したか
- [ ] セキュリティ要件（認証方式・TLS・ペイロード検証）を確認したか

### 運用・エコシステム
- [ ] クライアントエコシステム（SDK・ライブラリの成熟度）を調査したか
- [ ] インフラ制約（HTTP/2 対応・WebSocket Upgrade・ブローカー運用）を確認したか
- [ ] 既存 API との整合性（同一スタイル統一 vs ハイブリッド）を検討したか
- [ ] ブラウザからの直接呼び出しが必要か（gRPC native の制約を確認）

---

## 6. ハイブリッドアーキテクチャのパターン

実際のシステムでは複数スタイルを組み合わせる場合が多い。

| パターン | 組み合わせ | ユースケース |
|---------|----------|-----------|
| **BFF（Backend for Frontend）** | REST + GraphQL | モバイル向け GraphQL BFF → 内部 REST / gRPC へルーティング |
| **イベント駆動 + REST** | REST + ブローカー型 | REST で操作受付 → ブローカーで非同期処理（注文・決済フロー等） |
| **通知ハイブリッド** | REST + Webhook + WebSocket | データ取得 = REST / 軽量通知 = Webhook / リアルタイム = WebSocket |
| **サービス間 gRPC + 公開 REST** | gRPC + REST | 内部マイクロサービス = gRPC / 外部公開 = REST（ゲートウェイで変換） |

> **Trade-Off**: ハイブリッドアーキテクチャは柔軟性が高い反面、設計の複雑性・運用コスト・
> チームの学習コスト・API Gateway の設定量が増加する。スタイルを増やすほどトレードオフは拡大する。

---

## 7. AskUserQuestion: 選定支援

スタイル選定で判断が分かれる場合、以下の質問でユーザーに確認する
（ツール不可環境では同じ選択肢をテキスト質問として確認）:

**最重視する非機能特性は何か？**
1. 開発速度・普及度・クライアント互換性（→ REST 有力）
2. 低レイテンシ・高スループット・型安全性（→ gRPC 有力）
3. クライアントが必要なデータ形状を柔軟に指定（→ GraphQL 有力）
4. 疎結合・耐障害性・大量非同期メッセージ（→ ブローカー型 有力）

---

## 参照先

| 参照先 | 内容 |
|-------|-----|
| `CONCEPTS-AND-COMMUNICATION.md` | 通信モード・伝送モード（simplex / half / full-duplex）・同期/非同期の定義 |
| `PROTOCOL-FOUNDATIONS.md` | HTTP/1.1 vs HTTP/2 vs HTTP/3 QUIC のプロトコル基盤（応答性差の根拠） |
| `CROSS-STYLE-PATTERNS.md` | ページネーション・バージョニング・キャッシュ等のスタイル横断パターン |
| `STYLE-REST.md` | REST の詳細 Trade-Offs・When to Use |
| `STYLE-GRAPHQL.md` | GraphQL の詳細 Trade-Offs・When to Use |
| `STYLE-GRPC.md` | gRPC の詳細・4 RPC 型・双方向帰属の整理 |
| `STYLE-WEBFEEDS-WEBHOOKS.md` | Webフィード / Webhook の詳細 Trade-Offs・When to Use |
| `STYLE-WEBSOCKET-MESSAGING.md` | WebSocket / ブローカー型の詳細 Trade-Offs・When to Use |
| `INSTRUCTIONS.md` | スキル全体の選定フロー・7スタイルサマリ |
