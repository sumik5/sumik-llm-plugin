# APIスタイルの選定

REST・GraphQL・gRPC・Webhook・WebSocket・ブローカー型メッセージング・Webフィードの7スタイルをトレードオフで比較し、要件に適したAPIスタイルを選ぶ意思決定ガイド。

---

## 参照ファイル一覧

| ファイル | 内容 |
|---------|------|
| `references/CONCEPTS-AND-COMMUNICATION.md` | API定義・伝送/通信モード・ライフサイクル・API-as-a-Product |
| `references/PROTOCOL-FOUNDATIONS.md` | TCP/IP・HTTP進化(0.9→3/QUIC)・HoLブロッキング（性能差の根拠） |
| `references/CROSS-STYLE-PATTERNS.md` | スタイル横断パターン（ページネーション/レートリミット/キャッシュ/OWASP） |
| `references/STYLE-REST.md` | REST成熟度・冪等性・Trade-Offs・When to Use |
| `references/STYLE-GRAPHQL.md` | GraphQL・Code/Schema-First・攻撃と防御・Trade-Offs・When to Use |
| `references/STYLE-GRPC.md` | gRPC・4 RPC型・Protobuf・Trade-Offs・When to Use |
| `references/STYLE-WEBFEEDS-WEBHOOKS.md` | Webフィード・Webhook・配信保証・Trade-Offs・When to Use |
| `references/STYLE-WEBSOCKET-MESSAGING.md` | WebSocket・ブローカー型・Trade-Offs・When to Use |
| `references/SELECTION-MATRIX.md` | 6次元×7スタイル選定マトリクス・決定木・チェックリスト |

---

## APIスタイルとは

APIスタイルとは、APIを設計・実装・公開するためのパターン・慣行・プロトコルを組み合わせたパラダイム。各スタイルはその**支配的特性**（プロトコル・通信制約・設計原則）で識別される。同じプロトコルを使っていても支配的な特性が異なれば別スタイルに分類される（例: WebSocket を使う GraphQL Subscription と WebSocket ネイティブ API）。

### 7スタイル確定分類表

| 特性 | REST | GraphQL | Webフィード | gRPC | Webhook | WebSocket | ブローカー型 |
|------|------|---------|------------|------|---------|-----------|------------|
| 代表技術 | REST | GraphQL | Atom/RSS | gRPC | Webhook | WebSocket | RabbitMQ/Kafka |
| プロトコル | HTTP | HTTP(+WS) | HTTP | HTTP/2 | HTTP | WebSocket | AMQP 等 |
| 通信種別 | 同期 | 同期 | 非同期 | 同期 | 非同期 | 非同期 | 非同期 |
| バイナリ対応 | Yes | Partial | Partial | Yes | Yes | Yes | Yes |
| 応答性 | 中 | 中 | 中 | 高 | 中 | 高 | 高 |
| 開発労力 | 中 | 中 | 低 | 高 | 低 | 中 | 高 |
| スタイル分類 | Resource | Query | Web feed | RPC | Callback | Bidirectional | Broker-based |

> **補足**: GraphQL の Subscription は WebSocket を併用可（`HTTP(+WS)` はこの意味）。gRPC の full-duplex streaming は双方向にも属する。バイナリ対応の Partial は Base64 等のアプリケーション層エンコードが必要であることを意味する。

### 各スタイルの支配的特性

| スタイル | 支配的特性 | 代表ユースケース |
|---------|----------|----------------|
| **REST** | HTTP メソッドとURIによるリソース指向 | Web公開API・CRUD操作 |
| **GraphQL** | クライアントがクエリで返却形状を指定 | SPA・BFF・フロントエンド多様化 |
| **Webフィード** | 継続更新コンテンツの構造化配信（pull型） | ブログ更新・ニュース配信 |
| **gRPC** | Protobuf+HTTP/2によるリモート関数呼び出し | サービス間高速通信・型安全 |
| **Webhook** | イベント発生時に source が destination へ HTTP POST | 外部サービス連携・CI/CD通知 |
| **WebSocket** | HTTP アップグレードで確立するfull-duplex接続 | チャット・ゲーム・ダッシュボード |
| **ブローカー型** | ブローカー経由の非同期メッセージ配信 | イベント駆動・分散処理・疎結合 |

---

## 通信の基礎（選定の前提）

スタイルの性能差・適合性を理解するための基礎概念。詳細は `references/CONCEPTS-AND-COMMUNICATION.md` 参照。

### 伝送モード（Transmission Mode）

| モード | 方向性 | 特徴 | 代表スタイル |
|--------|--------|------|------------|
| Simplex | 一方向のみ | 送信側→受信側の単方向 | Webフィード（pull方向） |
| Half-duplex | 双方向だが同時送受信不可 | 要求→応答の交互通信 | REST・GraphQL・Webhook |
| Full-duplex | 双方向同時送受信 | 送受信を同時に行える | WebSocket・gRPC streaming |

### 通信種別（Communication Type）

- **同期（Synchronous）**: 送信者がレスポンスを待つ（ブロッキング）。REST・GraphQL・gRPC (unary)。
- **非同期（Asynchronous）**: 送信者はレスポンスを待たずに進む（ノンブロッキング）。Webhook・WebSocket・ブローカー型。

プロトコル基盤（HTTP/1.1 → HTTP/2 → HTTP/3/QUIC の進化・TLS 1-RTT・TCP Head-of-Line ブロッキングがパフォーマンス差を生む仕組み）の詳細は `references/PROTOCOL-FOUNDATIONS.md` を参照。

---

## 選定フロー（意思決定の骨子）

4ステップで候補を絞り込む。詳細な選定マトリクスと決定木は `references/SELECTION-MATRIX.md` を参照。

### ステップ 1: 主要な通信パターンを確認する

> **AskUserQuestion で確認**: 主要な通信パターンは何ですか？
>
> 1. 要求-応答（同期）: クライアントがリクエストし、レスポンスを待つ
> 2. サーバからのイベント通知（非同期）: サーバが状態変化を能動的に通知する
> 3. 双方向リアルタイム: クライアント・サーバが同時に送受信する
> 4. 大量非同期処理: メッセージをキューに溜め非同期で処理する
>
> ツールが使えない環境では、同じ選択肢を通常のテキスト質問として提示して確認してください。

| 回答 | 有力候補 |
|------|---------|
| 1（要求-応答） | REST・GraphQL・gRPC (unary) |
| 2（イベント通知） | Webhook（push）・Webフィード（pull定期取得） |
| 3（双方向リアルタイム） | WebSocket・gRPC (bidirectional streaming) |
| 4（大量非同期処理） | ブローカー型（RabbitMQ/Kafka） |

### ステップ 2: API消費者を確認する

> **AskUserQuestion で確認**: APIの主要な消費者は誰ですか？
>
> 1. ブラウザ/フロントエンド中心（Web SPA・モバイルアプリ）
> 2. サービス間（内部マイクロサービス・バックエンド間）
> 3. サードパーティ公開（外部開発者・パートナー向け）
>
> ツールが使えない環境では、同じ選択肢を通常のテキスト質問として提示して確認してください。

| 回答 | 示唆 |
|------|------|
| 1（ブラウザ/フロント） | REST・GraphQL・WebSocket が適合。gRPC はブラウザ直接接続に制約（grpc-web またはゲートウェイが必要）。 |
| 2（サービス間） | gRPC（高スループット・型安全）・ブローカー型（疎結合・耐障害性）が強み。 |
| 3（サードパーティ公開） | REST・GraphQL（普及度・エコシステム・SDKが充実）が有利。 |

### ステップ 3: データ形状・特性を確認する

| データ形状の要件 | 有力候補 |
|----------------|---------|
| 固定リソースの CRUD | REST |
| クライアントが返却形状を自由に指定したい | GraphQL |
| バイナリデータ・高スループット | gRPC |
| イベント発生時にサーバから push | Webhook |
| リアルタイムストリーム（チャット・センサー） | WebSocket / gRPC streaming |
| 定期配信コンテンツ（ブログ更新・RSSリーダー） | Webフィード |
| 疎結合な非同期処理・順序保証・再試行 | ブローカー型 |

### ステップ 4: 非機能特性で絞り込む

非機能要件の重点によって最終候補を絞る。詳細は `references/SELECTION-MATRIX.md` の意思決定チェックリストを参照。

| 重視する非機能特性 | 有利なスタイル |
|-----------------|--------------|
| 開発速度・エコシステムの豊富さ | REST・GraphQL |
| 低レイテンシ・高スループット | gRPC・WebSocket・ブローカー型 |
| クライアント側の柔軟なデータ取得 | GraphQL |
| 疎結合・高耐障害性・スケーラビリティ | ブローカー型 |
| 最小の開発労力（シンプルな配信） | Webフィード・Webhook |

---

## 7スタイル 1行サマリ

| スタイル | 一言 | 詳細参照 |
|---------|------|---------|
| **REST** | HTTPメソッド＋URIでリソースを操作する。最も普及しており外部API公開の基本 | `references/STYLE-REST.md` |
| **GraphQL** | クライアント主導の柔軟なデータ取得。フロントエンド多様化環境で強み | `references/STYLE-GRAPHQL.md` |
| **gRPC** | Protobuf＋HTTP/2でサービス間高速通信。型安全・4 RPC型（streaming 対応） | `references/STYLE-GRPC.md` |
| **Webhook** | イベント発生を HTTP POST でコールバック通知。疎結合な外部サービス連携 | `references/STYLE-WEBFEEDS-WEBHOOKS.md` |
| **Webフィード** | RSS/Atom で継続更新コンテンツを配信（pull型）。開発労力が最低クラス | `references/STYLE-WEBFEEDS-WEBHOOKS.md` |
| **WebSocket** | HTTP アップグレードで確立するfull-duplex双方向通信。チャット・リアルタイム | `references/STYLE-WEBSOCKET-MESSAGING.md` |
| **ブローカー型** | ブローカー経由の非同期メッセージ配信。高耐障害性・スケーラブルな分散処理 | `references/STYLE-WEBSOCKET-MESSAGING.md` |

---

## スタイル横断で共通に効く設計パターン

APIスタイルを問わず共通して適用すべきパターン。詳細は `references/CROSS-STYLE-PATTERNS.md` を参照。

| カテゴリ | 概要 |
|---------|------|
| **APIバージョニング** | URI・ヘッダー・コンテントネゴシエーションによる後方/前方互換性維持 |
| **ページネーション** | オフセット・カーソル・ページベース。大量データ返却の抑制と安定性確保 |
| **レートリミット** | `429 Too Many Requests` と `Retry-After` ヘッダーによる流量制御 |
| **キャッシュ** | ETag・Cache-Control・conditional requests による帯域削減と整合性維持 |
| **リトライと冪等性** | 冪等キーによる安全な再送（POST の冪等化）。指数バックオフ |
| **OWASP API Top 10** | Broken Object Level Authorization・Excessive Data Exposure 等のセキュリティ対策 |

REST 固有の詳細設計（URI設計・OpenAPI仕様・ステータスコード・認証）は `developing-web-apis` スキルを参照。

---

## AskUserQuestion を使う5箇所

| 箇所 | 質問の要旨 | ファイル |
|------|-----------|--------|
| 選定フロー ステップ1 | 主要な通信パターンは？ | `INSTRUCTIONS.md`（本ファイル） |
| 選定フロー ステップ2 | API消費者は誰か？ | `INSTRUCTIONS.md`（本ファイル） |
| 選定マトリクス決定木末尾 | 最重視する非機能特性は？ | `references/SELECTION-MATRIX.md` |
| GraphQL スタイル解説 | Schema-First か Code-First か？ | `references/STYLE-GRAPHQL.md` |
| gRPC スタイル解説 | ブラウザから直接呼ぶ必要があるか？ | `references/STYLE-GRPC.md` |

> **AskUserQuestion 使用不可環境**: ツールが使えない場合は同じ選択肢をテキスト質問として提示し、同等の情報を収集してください。これはすべての AskUserQuestion 指示に共通するルールです。

---

## 委譲境界（実装・テストは他スキルへ）

本スキルの責務は**選定・比較・トレードオフの判断**に限定する。以下の領域は他スキルへ委譲する。

| 作業領域 | 委譲先スキル |
|---------|------------|
| REST API の詳細設計（URI設計・OpenAPI仕様・ステータスコード設計・テスト戦略） | `developing-web-apis` |
| gRPC の `.proto` ファイル記述実務・コード生成・サーバ実装 | `developing-web-apis` |
| Express / NestJS / Fastify によるフレームワーク実装 | `developing-fullstack-javascript` |
| MCP（Model Context Protocol）の仕様・実装・サーバ構築 | `lang:developing-mcp` |
| マイクロサービス粒度・サービスメッシュ・インフラ層のトレードオフ | `cloud:architecting-infrastructure` |
