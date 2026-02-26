# gRPC API仕様の書き方

gRPC / Protocol Buffers を使ったバックエンドサービスにおける API仕様の記述方法リファレンス。

---

## 1. API仕様をどこに書くか

`.proto` ファイルにサービス定義と API仕様を一元管理し、**乖離を防ぐ**。
`.proto` のコメントはコンパイル時にスタブコードへコピーされる。
ドキュメント生成ツール（例：`protoc-gen-doc`）を使う場合はそのフォーマットに合わせる。

---

## 2. 仕様の記述場所：4つのポイント

```proto
/**
 * ❶ サービスレベルのコメント
 *   - サービスの概要説明
 *   - すべてのRPCに共通するエラー（Internal, Canceled, DeadlineExceeded 等）
 *   - 認証情報の要件（全RPC共通の場合）
 */
service Greeter {
  // ❷ RPCの1行サマリー（簡潔に）
  rpc SayHello (SayHelloRequest) returns (SayHelloResponse) {}
}

/**
 * ❸ リクエストメッセージ定義の前（RPCの詳細仕様を書く本拠地）
 *   - エンドポイントの詳細な振る舞い・他エンドポイントとの関係
 *   - 各フィールドの許容値の範囲
 *   - [エラー] セクション
 */
message SayHelloRequest {
  string name = 1;
}

// ❹ レスポンスメッセージ（定義から自明であれば省略可）
message SayHelloResponse {
  string message = 1;
}
```

**重要**: RPCの詳細な振る舞いは ❷ではなく ❸ に書く。フィールド定義に隣接しているため読みやすい。

---

## 3. サービスの概要説明（❶）

`service` 定義の前に記述する内容：

- サービスが提供する機能の概要
- **すべての RPC で共通して返すステータスコード**（`Internal`, `Canceled`, `DeadlineExceeded` 等）
- すべての RPC に共通する認証情報の要件

```proto
/**
 * Greeterサービスは、あるユーザーに対して挨拶を伝えるための機能を提供します。
 *  - 個々のRPCはInternal、Canceled、あるいはDeadlineExceededを返すかもしれませんが、
 *    [エラー]には列挙されません。
 */
service Greeter {
  ...
}
```

---

## 4. 個々のエンドポイントの説明（❸）

リクエストメッセージのコメントに以下を記述する：

| 記述項目 | 説明 |
|---------|------|
| 機能の詳細・他RPCとの関係 | 振る舞いと依存関係 |
| フィールドの制約 | 文字列の長さ・数値の正負・日付の範囲・フィールド間の組み合わせ制約 |
| エラー一覧 | `[エラー]` セクションに列挙 |

---

## 5. エラーの説明

gRPC には標準で17個のステータスコードが定義されている。

### エラーの記述場所分類

| 分類 | エラーコード | 記述場所 |
|------|-----------|---------|
| パラメータ不正 | `InvalidArgument`, `NotFound`, `OutOfRange` | ❸ |
| 呼び出し順序エラー | `FailedPrecondition` | ❸ |
| 認証・認可 | `Unauthenticated`, `PermissionDenied` | ❸ or ❶（全RPC共通なら❶） |
| サービス全体共通 | `Canceled`, `DeadlineExceeded`, `Unknown`, `Internal` | ❶ |
| 個別エンドポイント固有 | `AlreadyExists`, `ResourceExhausted`, `Aborted` | ❸ |
| 記述不要 | `Unavailable`, `DataLoss`, `Unimplemented` | 記述しない |

### パラメータの不正

**`InvalidArgument`**: システム状態に関係なく引数そのものが不正な場合。バリデーション自動生成を使う場合でも、ルールで表現できない複合制約は本文に記述すること。

**`NotFound`**: リソースが存在しない場合（`InvalidArgument` と混同しないこと）。

**`OutOfRange`**: データが動的に増えるシステムで指定範囲のデータがない場合。

### 呼び出し順序エラー

**`FailedPrecondition`**: 事前条件が成立していない場合（例：有効期限切れのトークン）。同じ値が以前は有効だった点で `InvalidArgument` と異なり、リトライで解決しない点で `Aborted` とも異なる。

### 認証・認可のエラー

**`Unauthenticated`**: 認証情報が不足・無効な場合。

**`PermissionDenied`**: 認証は成功しているが実行権限がない場合。
**セキュリティ上の注意**: 外部から直接呼び出される API では権限不足を示すことがリスクになる。その場合は `NotFound` を返し、意図を明記する：

```
 * - NotFound:
 *   - nameで指定されたユーザーは存在しません。
 * - NotFound (aka PermissionDenied):
 *   - nameで指定されたユーザーへのメッセージは許可されていません。
```

### サービスの概要（❶）に書くその他のエラー

**`Canceled`**: クライアントからのキャンセル。依存サービスからの `Canceled` を正しく伝搬させること（伝搬失敗で `Internal` に化けやすい）。

**`DeadlineExceeded`**: タイムアウト。`Canceled` 同様に伝搬を確実に行う。

**`Internal`**: サービス側の実装上の問題。個別 RPC の説明には書かない。書くなら ❶。

### 個別エンドポイントに書くその他のエラー

**`AlreadyExists`**: リソース作成時に既に存在する場合。冪等キーを使う生成では既存でも `OK` を返す必要があり、その旨を ❸ に記述すること。

**`Aborted`**: 処理が中断されたがリトライで成功する可能性がある場合。実装されている場合は必ず ❸ に記述。

### 記述不要なエラー

| エラーコード | 理由 |
|------------|------|
| `Unavailable` | gRPCライブラリがサービス接続失敗時に返す |
| `DataLoss` | API仕様に記述するケースはまれ |
| `Unimplemented` | gRPCフレームワークが返す |

---

## 6. リストオプション（ページネーション）の仕様記述

一覧を返す RPC では以下を必ず明記する。自明に見えても、記述がなければクライアント開発者が問い合わせることになる。

| 記述必須の項目 | 記述例 |
|-------------|-------|
| 最初のページの取得方法 | `page_token` に空文字列を指定する |
| 1回あたりの最大返却件数 | 「たかだか20個まで」 |
| 次ページの取得方法 | レスポンスの `next_page_token` を次のリクエストに指定 |
| 最終ページの判定 | `next_page_token` が空文字列ならこれ以上データなし |
| レスポンスの並び順 | 「price の昇順、同価格は name のアルファベット順」 |
| `page_token` 不正時のエラー | `InvalidArgument` |

```proto
/**
 * ListProductsは、商品の一覧を返します。ただし、返される商品数は一度にたかだか20個までです。
 * - page_tokenに指定できる値は、空文字列かレスポンスのnext_page_tokenで返される値を指定します。
 * - page_tokenが空文字列の場合、最初の20個の商品を返します。
 * - 返される商品一覧はpriceの値の昇順に返されます。priceが同じ場合にはnameのアルファベット順です。
 *
 * [エラー]
 * - Unauthenticated:
 *   - 認証情報が不正です。
 * - InvalidArgument:
 *   - page_tokenの値が不正です。
 */
message ListProductsRequest {
  string page_token = 1;
}

/**
 * 商品一覧を返すレスポンスです。
 * - productsで返される商品数は、たかだか20個です。
 * - 商品一覧にまだ商品がある場合、next_page_tokenに空文字列ではない値が返されます。
 * - 返された商品一覧で最後であり、これ以上商品がない場合、next_page_tokenとして空文字列が返されます。
 */
message ListProductsResponse {
  repeated Product products = 1;
  string next_page_token = 2;
}
```

---

## 7. GraphQL でのエラー設計（参考）

GraphQL では `extensions.code` フィールドでエラーを表現するが、標準はなくプロジェクト独自に定義する。
Apollo GraphQL Server では `GRAPHQL_PARSE_FAILED`, `BAD_USER_INPUT`, `INTERNAL_SERVER_ERROR` 等の組み込みエラーコードが定義されている。
gRPC と異なり、クエリの記述誤り関連のエラーも考慮する必要がある点に注意。
いずれにせよ、**エラーを分類・定義して API仕様の一部として記述すること**が重要である。
