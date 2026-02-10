# MCPプロトコル仕様

MCPプロトコルの低レベル実装詳細。Transport層、JSON-RPCメッセージフォーマット、インタラクションフロー、エラーハンドリングをカバー。

---

## Transport層

MCPメッセージが移動する通信経路。2つの標準Transportを定義。

### 1. Standard I/O (stdio)

**概要**

プロセスの標準入力（stdin）、標準出力（stdout）、標準エラー（stderr）ストリームを使用したシンプルな通信。

**使用ケース**

- 同一マシン上のプロセス間通信専用
- 典型例: IDE等のHostアプリケーションが同一コンピュータ上でMCPサーバーを子プロセスとして起動
- 子プロセスのstdoutを介してHostから応答を受信

**動作原理**

- 改行区切りJSON-RPCメッセージ
- 各JSONメッセージは1行に記述され、改行文字（`\n`）で終了
- テキストベースで高速、ネットワークスタックやポート管理不要
- 密結合デスクトップアプリ、開発、テストに最適

**例**

```
// Host → Server's stdin:
{"jsonrpc":"2.0","method":"mcp/discover","id":1}\n

// Server → Host's stdout:
{"jsonrpc":"2.0","result":{...},"id":1}\n
```

### 2. Streamable HTTP

**概要**

標準HTTPメソッド上に構築された、長期存続・双方向・非同期なAI会話をサポートする高度なプロトコル。リモート通信推奨Transport。

**使用ケース**

- ネットワーク越しのClient-Server通信
- 例: WebアプリケーションがクラウドホストMCPサーバーに接続

**動作原理**

単純なREST APIと異なり、単一エンドポイント（例: `/mcp`）上に永続的な**セッション**を確立。標準HTTPテクニックを組み合わせてセッション管理を実現。

**HTTPエンドポイント**

| メソッド | エンドポイント | 用途 |
|---------|--------------|------|
| **POST /mcp** | ClientとServerの主要通信チャネル | すべてのリクエスト（`tools/call`、`resources/read`等）をPOSTリクエストのボディとして送信 |
| **GET /mcp** | Server-to-Client通知チャネル | ClientがGETリクエストを送信し、Serverが接続を保持してServer-Sent Events (SSE) でデータストリームを返す。`listChanged`通知等に使用。プロトコルではSSEは非推奨、StreamableHTTPを推奨 |
| **DELETE /mcp** | セッション終了 | Clientが終了時にDELETEリクエストを送信し、Server側リソースを解放 |

**セッション管理**

- `mcp-session-id` HTTPヘッダーで全セッションを紐付け
- Server初回初期化リクエスト後に一意のセッションIDを生成してClientに返却
- Client後続リクエストで必須
- 単一ステートフルServerが複数Client接続を同時管理可能

**選択基準**

| 条件 | 推奨Transport |
|------|-------------|
| ローカル同一マシン通信 | stdio |
| ネットワーク越しリモート通信 | Streamable HTTP |
| 開発・テスト環境 | stdio（簡便性） |
| 本番環境・分散システム | Streamable HTTP（セッション管理・拡張性） |

---

## メッセージフォーマット: JSON-RPC 2.0

Transport層を経由して送信されるすべてのMCPメッセージは、**JSON-RPC 2.0**仕様に準拠。人間・機械双方にとって読み書き容易な軽量ステートレスRPCプロトコル。

### リクエストオブジェクト

**必須フィールド**

| フィールド | 型 | 説明 |
|----------|---|------|
| `jsonrpc` | string | 必ず `"2.0"` |
| `method` | string | 呼び出すメソッド名（例: `"tools/call"`） |
| `params` | object/array | メソッドに渡す引数 |
| `id` | string/number | Client生成の一意識別子。Serverはレスポンスで同じIDを返す |

**例: tools/call リクエスト**

```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "getNpmPackageInfo",
    "arguments": {
      "packageName": "zod"
    }
  },
  "id": "request-001"
}
```

### レスポンスオブジェクト

**成功時**

| フィールド | 型 | 説明 |
|----------|---|------|
| `jsonrpc` | string | 必ず `"2.0"` |
| `result` | any | 成功実行のペイロード |
| `id` | string/number | リクエストと同じID |

**例: 成功レスポンス**

```json
{
  "jsonrpc": "2.0",
  "result": {
    "content": [
      {
        "type": "text",
        "text": "Package: zod\nDescription: TypeScript-first schema validation...\nLicense: MIT"
      }
    ]
  },
  "id": "request-001"
}
```

### エラーオブジェクト

**失敗時**

リクエスト失敗時、Serverは`result`の代わりに`error`オブジェクトを返却。

| フィールド | 型 | 説明 |
|----------|---|------|
| `jsonrpc` | string | 必ず `"2.0"` |
| `error` | object | エラー情報（`code`、`message`、`data`） |
| `id` | string/number | リクエストと同じID |

**例: エラーレスポンス**

```json
{
  "jsonrpc": "2.0",
  "error": {
    "code": -32601,
    "message": "Method not found",
    "data": "Tool with name 'getNpmInfo' does not exist."
  },
  "id": "request-002"
}
```

---

## インタラクションフロー

接続からレスポンスまでの完全な成功インタラクションシーケンス。

### 4フェーズ

1. **Initialize（初期化）**: Client → Server 接続確立、Capability通知
2. **Discover（発見）**: Client → Server Capability詳細取得（Tools/Resources/Prompts一覧）
3. **Call（呼び出し）**: Client → Server 具体的なTool/Resource実行リクエスト
4. **Response（応答）**: Server → Client 実行結果返却

### シーケンス図解

```
[Client] ────(1) mcp/initialize────> [Server]
   ↓                                     ↓
   ↓                               capabilities
   ↓                                 (serverInfo)
   ↓                                     ↓
   ↓  <────(2) capabilities response─── ↓
   ↓
   ↓ (内部: LLM推論、Tool選択判断)
   ↓
   ├────(3) tools/call────────────────> [Server]
   ↓                                     ↓
   ↓                            (API呼び出し等実行)
   ↓                                     ↓
   ↓  <────(4) result/error──────────── ↓
   ↓
   ↓ (内部: LLM結果合成)
   ↓
   └──> ユーザーに最終回答
```

### ステップ詳細

**Step 1-2: Handshake（握手）**

- Clientが`mcp/initialize`リクエストを送信
- Serverがcapabilities（serverName、利用可能機能）を返却

**Step 3: Internal Processing（内部処理）**

- Host内LLMがユーザークエリを処理
- 使用すべきToolを推論（例: `getNpmPackageInfo`）

**Step 4-5: Execution（実行）**

- Clientが`tools/call`リクエストを送信
- Serverが外部API呼び出し等を実行

**Step 6: Result（結果返却）**

- Serverが構造化データを含む`result`を返却
- LLMが生データを人間可読な回答に合成

---

## エラーコード一覧

JSON-RPC 2.0標準エラーコード。明確なアクションフィードバックを提供。

| コード | 名称 | 説明 |
|-------|------|------|
| **-32700** | Parse Error | 不正なJSON受信 |
| **-32600** | Invalid Request | 無効なJSON-RPCリクエストオブジェクト |
| **-32601** | Method not found | Tool/Resourceハンドラが存在しない |
| **-32602** | Invalid Params | ハンドラ存在するが引数が無効（型違い、必須フィールド欠落等） |
| **-32603** | Internal Error | Tool/Resource実行中のServer側エラー |

**ベストプラクティス**

- 適切なエラーコードで失敗原因を明確化
- `data`フィールドに詳細な診断情報を付加
- ClientはタイムアウトメカニズムをXX実装（例: 30秒で応答なければキャンセル）

---

## セッション管理

**mcp-session-id ヘッダー**

Streamable HTTP使用時、セッション識別に`mcp-session-id`ヘッダーを使用。

- Server初期化時に生成
- Client後続リクエストで必須送信
- ステートフル接続維持、複数Client並行管理を実現

**セッションライフサイクル**

```
Client → POST /mcp (initialize)
Server → 200 OK (mcp-session-id: abc123)

Client → POST /mcp (tools/call, header: mcp-session-id: abc123)
Server → 200 OK (result)

Client → DELETE /mcp (header: mcp-session-id: abc123)
Server → 200 OK (session terminated)
```

---

## プロトコル仕様まとめ

- **Transport**: stdio（ローカル）とStreamable HTTP（リモート）
- **メッセージ形式**: JSON-RPC 2.0標準
- **インタラクション**: Initialize → Discover → Call → Response
- **エラーハンドリング**: 標準エラーコード（-32700〜-32603）
- **セッション**: mcp-session-idヘッダーで管理

この低レベルプロトコル知識は、カスタムClient/Server実装、高度なデバッグ、本番環境対応に不可欠。
