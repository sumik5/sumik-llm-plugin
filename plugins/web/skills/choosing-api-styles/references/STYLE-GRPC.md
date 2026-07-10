# gRPC スタイルリファレンス

gRPC は Google が開発し、Cloud Native Computing Foundation（CNCF）に寄贈した
高性能な RPC（Remote Procedure Call）フレームワーク。
HTTP/2 を転送層とし、Protocol Buffers（protobuf）をデフォルトの直列化フォーマットとして採用する。

---

## RPC の概念

RPC（Remote Procedure Call）はリモートサービスの手続き（関数・メソッド）を
ローカル呼び出しに近い形で呼び出すことを目的としたスタイル。
インターフェースはリソースではなく**意図（intent）**で定義される。

例：
- `CreateUser(request)` → ユーザー作成
- `GenerateReport(request)` → レポート生成

これはリソース指向の REST（`POST /users`・`GET /reports`）と対比される。

---

## gRPC の概要

### プロトコル基盤

gRPC は **HTTP/2** を転送層として使用し、以下の恩恵を受ける。

| HTTP/2 機能 | gRPC への効果 |
|------------|--------------|
| ヘッダー圧縮（HPACK） | HTTP/1.1 より小さなオーバーヘッド |
| 多重化ストリーム | 4 種の RPC 型（ストリーミング含む）を実現 |
| バイナリフレーム | protobuf のバイナリフォーマットとの親和性が高い |
| サーバープッシュ | サーバー streaming RPC を効率化 |

HTTP/2 の詳細（HoL ブロッキング・QUIC との比較）は `PROTOCOL-FOUNDATIONS.md` を参照。

### Protocol Buffers（protobuf）

gRPC のデフォルト直列化フォーマット。`.proto` ファイルにサービスとメッセージを定義する。

```protobuf
syntax = "proto3";

package notification.v1;

// 通知サービスの定義
service NotificationService {
  rpc Send(SendRequest) returns (SendResponse);
}

message SendRequest {
  string recipient_id = 1;
  string content      = 2;
}

message SendResponse {
  string message_id = 1;
  bool   delivered  = 2;
}
```

protobuf の特徴：

| 特性 | 内容 |
|------|------|
| フォーマット | バイナリ（JSON/XML より小さく高速） |
| スキーマ | `.proto` ファイルで型を厳密に定義 |
| 進化性 | フィールド番号で下位互換を保ちながら変更可能 |
| コード生成 | `protoc` コンパイラが複数言語向けのスタブを自動生成 |

> `.proto` の実務的な記述方法・コード生成手順・スキーマ設計の詳細は
> `developing-web-apis` スキルを参照。

---

## 4 種の RPC 型

gRPC は通信パターンに応じて 4 つの RPC 型をサポートする。

### 1. Unary RPC（単項 RPC）

1 リクエスト → 1 レスポンス。REST の要求-応答モデルに対応する最もシンプルな型。

```protobuf
rpc Send(SendRequest) returns (SendResponse);
```

- **用途**: CRUD 操作・認証・ルックアップ
- **特徴**: 既存サービス間通信の置き換えに最適。ストリーミング RPC より扱いやすい

### 2. Server Streaming RPC（サーバーストリーミング）

1 リクエスト → 複数レスポンス。サーバーが一度の要求に対して連続したデータを返す。

```protobuf
rpc Subscribe(SubscribeRequest) returns (stream EventResponse);
```

- **用途**: ログ配信・ライブフィード・進捗通知
- **特徴**: クライアントが能動的に接続を開始するプッシュに近い動作

### 3. Client Streaming RPC（クライアントストリーミング）

複数リクエスト → 1 レスポンス。クライアントがデータを連続して送信し、
最後に集計結果を受け取る。

```protobuf
rpc Upload(stream DataChunk) returns (UploadResponse);
```

- **用途**: ファイルアップロード・センサーデータ収集・バルク挿入
- **特徴**: 大容量データを分割して転送できる

### 4. Bidirectional Streaming RPC（双方向ストリーミング）

複数リクエスト ↔ 複数レスポンス。クライアントとサーバーが同時に
メッセージを送受信できる **full-duplex** 通信。

```protobuf
rpc Chat(stream ChatMessage) returns (stream ChatMessage);
```

- **用途**: チャット・ゲームサーバー・リアルタイム協調作業・音声/動画ストリーミング
- **特徴**: HTTP/2 の独立ストリームが双方向を可能にする

> bidirectional streaming は WebSocket に近い動作を RPC スタイルで実現する。
> gRPC と WebSocket・ブローカー型メッセージングとの詳細な比較は
> `SELECTION-MATRIX.md` の選定マトリクスを参照。

---

## セキュリティ

gRPC は HTTP/2 ベースのため、HTTP に関連する一般的なセキュリティリスクを継承する
（OWASP API Top 10 の詳細は `CROSS-STYLE-PATTERNS.md` を参照）。

| セキュリティ手段 | 概要 |
|----------------|------|
| TLS | データの暗号化とサーバー認証 |
| mTLS（相互 TLS） | クライアント・サーバー双方の証明書で相互認証。ゼロトラスト網に適合 |
| トークン認証 | JWT 等のトークンをメタデータで渡す。mTLS と組み合わせ可 |
| リフレクション無効化 | `reflection` 機能はデフォルト無効を維持（有効化するとサービス一覧が公開される） |

**mTLS の検討ポイント**: マイクロサービス間通信では mTLS が推奨されるが、
証明書の管理・ローテーションに追加の運用コストが発生する。
SPIRE/SPIFFE 等の自動化ツールの活用で管理負荷を軽減できる。

---

## ドキュメント

現時点で Swagger UI や GraphiQL に相当する公式の HTML ドキュメント生成ツールは存在しない。
代替手段：

- **`.proto` ファイル**: コメントを充実させたスタティックドキュメント
- **gRPC reflection**: `grpcurl` でサービス・RPC・メッセージを動的に探索可能
  （ただし有効化はセキュリティ上のリスクを伴う）
- **非公式ツール**: `buf` エコシステム・`protoc-gen-doc` 等のコミュニティツール

---

## Trade-Offs

### 利点

| 利点 | 説明 |
|------|------|
| **高性能** | protobuf バイナリ + HPACK ヘッダー圧縮により JSON/HTTP/1.1 より小さなペイロード。高頻度なサービス間通信で効果が高い |
| **型付き API 契約** | `.proto` がクライアント-サーバー間の厳密な型契約を定義。コード生成により実装が契約から逸脱しない |
| **4 種のストリーミング** | unary から bidirectional streaming まで多様な通信パターンをカバー。gRPC だけで同期・ストリーミングを統一して扱える |
| **多言語対応** | Java・Go・C++・Python・Ruby・Node.js・C# 等で公式サポート。protobuf により言語を跨いだ通信が可能 |
| **分散システム支援** | デッドライン・キャンセル・クライアント側ロードバランシング・フロー制御・ヘルスチェック・リトライ等が組み込み機能として利用可能 |

### 欠点

| 欠点 | 説明 |
|------|------|
| **ブラウザ非対応** | ネイティブブラウザは HTTP trailers をサポートしないため gRPC を直接呼び出せない。grpc-web・grpc-Gateway・Connect Protocol 等のプロキシが必要 |
| **コード生成の運用コスト** | `protoc` バージョン管理・生成コードの配布・CI/CD への組み込みが必要。Bazel 等の専用ビルドツールが推奨されるが導入コストが高い |
| **ドキュメントツール不足** | Swagger UI 相当の公式 HTML ドキュメント生成がない。`.proto` ファイルとリフレクションが代替手段だが利便性が劣る |
| **公式ツール不足** | protobuf の linting・breaking change 検出・ロードテスト等はサードパーティ（`buf`・`ghz`）依存 |
| **学習コスト** | REST と比べて RPC スタイル・バイナリフォーマット・コード生成フローの習得が必要。デバッグもバイナリのため難易度が上がる |
| **REST との非互換** | 既存 REST クライアントが gRPC サービスをそのまま呼べない。共存には grpc-Gateway 等が必要 |

---

## When to Use

### gRPC が適するシナリオ

| シナリオ | 理由 |
|---------|------|
| **マイクロサービス間の内部通信** | 高頻度・低レイテンシが求められるサービス間 RPC に最適。型契約がインターフェース崩壊を防ぐ |
| **多言語環境** | Python・Go・Java が混在するバックエンドでの統一通信レイヤー |
| **高スループット要件** | 大量のリクエストを低オーバーヘッドで処理する API |
| **ストリーミングデータ** | ログ転送・センサーデータ・動画フレームなど継続的データの送受信 |
| **リアルタイム双方向通信** | bidirectional streaming でチャット・ゲーム・リアルタイム更新を実現 |
| **ML バックエンド** | 推論サーバーとのやり取りに gRPC が多く採用される（高性能・多言語対応が理由） |

### gRPC が不向きなシナリオ

| シナリオ | 推奨代替 |
|---------|---------|
| **ブラウザからの直接呼び出し** | REST または GraphQL（grpc-web を使う場合は別途プロキシが必要） |
| **サードパーティ公開 API** | REST が標準的。外部開発者にとって gRPC の学習コストが障壁になる |
| **シンプルな CRUD API** | REST の方が実装・運用コストが低い |
| **ドキュメント重視の API** | OpenAPI 仕様を持つ REST が有利 |

> **確認ポイント（AskUserQuestion）**: ブラウザから直接 gRPC サービスを呼び出す要件がある場合、
> grpc-web または grpc-Gateway によるプロキシが必要になります。
> 「ブラウザからの直接呼び出しは必要ですか？（必要 / 不要・サービス間のみ）」
> を確認してください（ツールが使えない環境では同じ選択肢をテキスト質問として提示）。

---

## 分類表（共有確定値）

| 特性 | gRPC |
|------|------|
| 代表技術 | gRPC |
| プロトコル | HTTP/2 |
| 通信種別 | 同期 |
| バイナリ対応 | Yes |
| 応答性 | 高 |
| 開発労力 | 高 |
| スタイル分類 | RPC |

> gRPC は bidirectional streaming を通じて双方向（full-duplex）通信も実現可能。
> 詳細な横断比較は `SELECTION-MATRIX.md` を参照。

---

## 参照

| ファイル | 内容 |
|---------|------|
| `PROTOCOL-FOUNDATIONS.md` | HTTP/2・QUIC の詳細。gRPC 性能差の根拠 |
| `CROSS-STYLE-PATTERNS.md` | リトライ・フロー制御・OWASP API Top 10 の横断パターン |
| `SELECTION-MATRIX.md` | 6 次元 × 7 スタイル比較表と双方向ストリーミングの詳細整理 |
| `developing-web-apis` スキル | `.proto` 記述実務・コード生成・API テスト戦略（実装層） |
