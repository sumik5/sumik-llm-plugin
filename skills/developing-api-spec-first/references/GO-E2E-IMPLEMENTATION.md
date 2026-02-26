# Go言語によるE2Eテストフレームワーク実装リファレンス

Go言語（gRPC）でのE2Eテストフレームワーク実装パターン。
INSTRUCTIONS.md の Section 3「E2Eテストフレームワークのアーキテクチャ」の
Go実装詳細として参照する。

---

## 1. E2Eテストの基本的な流れ

E2Eテストは**2プロセス構成**で実行する：

- **テスト対象サービス**（本番と同じバイナリ）：別プロセスで起動
- **Test Suiteプロセス**：フェイクサービスを内包してテストを実行

### Test Suiteプロセスの実行順序

| ステップ | 内容 |
|---------|------|
| ❶ フェイクサービス起動 | 依存サービスのフェイクを同一プロセス内で起動 |
| ❷ テスト対象サービス起動 | 環境変数でフェイクアドレスを指定して別プロセスで起動 |
| ❸ 準備待ち | gRPC Health Checking Protocol の `Check` でポーリング |
| ❹ テスト実行 | `m.Run()` でテスト関数群を実行 |
| ❺ 終了 | TERM シグナル送信 → プロセス終了待ち |

---

## 2. courierライブラリの構成

gRPC + Go 向け E2E フレームワークライブラリの主要コンポーネント：

| コンポーネント | 役割 |
|--------------|------|
| `courier.InvokeService(config)` | サービスビルド・起動・ヘルスチェック・TERM終了 |
| `fakegrpc.NewGRPCServer()` | 自動ポート割り当ての gRPC サーバ |
| `fakegrpc.Generate(config)` | `.proto` からフェイクサーバコードを自動生成 |
| `tid.New(ctx)` | Testing ID 生成と Context への埋め込み（並列テスト対応） |

---

## 3. TestMain関数パターン

E2Eテスト全体の起動・終了制御は `TestMain` に集約する。

```go
//go:build e2e
package e2etest

var (
    fakeShippingServer  *fakeshipping_v1.ShippingServer
    fakeWarehouseServer *fakewarehouse_v1.WarehouseServer
    shopGRPCPort        int
)

func TestMain(m *testing.M) {
    flag.Parse()
    os.Exit(e2eCoverage(m))
}

func e2eCoverage(m *testing.M) (exitCode int) {
    // ❶ フェイクサービス用 gRPC サーバ起動（1サーバに複数フェイクを登録可）
    grpcServer := fakegrpc.NewGRPCServer()
    fakeShippingServer = fakeshipping_v1.NewShippingServer(grpcServer.Server())
    fakeWarehouseServer = fakewarehouse_v1.NewWarehouseServer(grpcServer.Server())
    go func() { grpcServer.Serve() }()

    port := grpcServer.Port()
    shopGRPCPort = dynaport.Get(1)[0]

    // ❷ テスト対象サービスの起動設定
    config := &courier.Config{
        MakeDir:           "..",
        MakeBuildTarget:   "coverage_build",
        ServiceBinaryPath: "bin/shop_server",
        ServiceName:       "Shop",
        GRPCPort:          shopGRPCPort,
        Verbose:           testing.Verbose(),
        CoverageDir:       "coverage",
        Envs: []string{
            fmt.Sprintf("GRPC_SERVER_PORT=%d", shopGRPCPort),
            fmt.Sprintf("SHIPPING_SERVICE_ADDR=localhost:%s", port),
            fmt.Sprintf("WAREHOUSE_SERVICE_ADDR=localhost:%s", port),
        },
    }

    // ❸❹ 起動（ヘルスチェック成功まで待機）→ テスト実行
    terminateService, err := courier.InvokeService(config)
    if err != nil { return 1 }
    exitCode = m.Run()

    // ❺ TERM シグナルでサービス終了
    if err := terminateService(); err != nil { return 1 }
    return exitCode
}
```

### courier.Config の主要フィールド

| フィールド | 説明 |
|-----------|------|
| `MakeBuildTarget` | カバレッジビルド用 make ターゲット |
| `ServiceName` | gRPC ヘルスチェックに渡すサービス名 |
| `Verbose` | `testing.Verbose()` で `-v` 時にログ表示 |
| `Envs` | 環境変数スライス（`"KEY=VALUE"` 形式） |

---

## 4. フェイクサービスの構築

### 自動生成スクリプト

```go
// scripts/shipping_v1/main.go
func main() {
    fakegrpc.Generate(&fakegrpc.TemplateConfig{
        ServerPackageName:      "fakeshipping_v1",
        ProtoPackageImportPath: "yourorg/api/shipping_v1",
        ProtoPackageImportName: "v1",
        ServiceName:            "Shipping",
        ServiceClientType:      reflect.TypeOf(shipping_v1.NewShippingClient(nil)),
    })
}
```

```makefile
$(SERVICES):
    go run scripts/$@/main.go > fakeservers/$@/server.go
    gofmt -w fakeservers/$@/server.go && goimports -w fakeservers/$@/server.go
```

### 自動生成されるメソッド

各エンドポイントに対して以下が自動生成される：

| メソッド | 用途 |
|---------|------|
| `NewXxxServer(grpcServer)` | フェイクサーバ生成・gRPC サーバへ登録 |
| `ClearAllResponses(tid)` | 設定済みレスポンスをクリア（`t.Cleanup` で呼ぶ） |
| `SetYyyResponse(tid, res, err)` | 固定レスポンスを設定 |
| `SetYyyResponseCreator(tid, func)` | リクエスト内容に応じた動的レスポンス設定 |

> **外部サービスのフェイク化**: gRPC SDK があるクラウドサービス（例: Google PubSub）も
> `fakegrpc.Generate` で同様にフェイク化できる。SDK クライアント型を `ServiceClientType` に渡すだけ。

---

## 5. テストコードの実装パターン

### ビルドタグ（必須）

```go
//go:build e2e  // 通常の単体テストと混在しないよう分離
```

### パターン1: InvalidArgument（依存サービス不要）

```go
func TestFoo_InvalidArgument(t *testing.T) {
    t.Parallel()
    client := newShopClient(t)

    _, err := client.ListProductInventories(context.Background(),
        &shop_v1.ListProductInventoriesRequest{NumOfProducts: 0})

    if status.Code(err) != codes.InvalidArgument {
        t.Errorf("want InvalidArgument, got %v", err)
    }
}
```

### パターン2: エラー伝搬検証（テーブル駆動）

`DeadlineExceeded` や `Canceled` を `Internal` に誤変換していないか検証する：

```go
func TestFoo_ErrorPropagation(t *testing.T) {
    t.Parallel()
    client := newShopClient(t)
    tid, ctx := tid.New(context.Background())
    t.Cleanup(func() { fakeWarehouseServer.ClearAllResponses(tid) })

    for _, tc := range []struct{ code codes.Code }{
        {codes.Canceled}, {codes.DeadlineExceeded},
    } {
        fakeWarehouseServer.SetListProductInventoriesResponse(
            tid, nil, status.Error(tc.code, ""))

        _, err := client.ListProductInventories(ctx,
            &shop_v1.ListProductInventoriesRequest{NumOfProducts: 100})

        if status.Code(err) != tc.code {
            t.Errorf("want %v, got %v", tc.code, err)
        }
    }
}
```

### パターン3: 正常系

```go
func TestFoo_Normal(t *testing.T) {
    t.Parallel()
    client := newShopClient(t)
    tid, ctx := tid.New(context.Background())
    t.Cleanup(func() { fakeWarehouseServer.ClearAllResponses(tid) })

    fakeWarehouseServer.SetListProductInventoriesResponse(tid, &warehouse_v1.ListProductInventoriesResponse{
        ProductInventories: testProducts,
    }, nil)

    res, err := client.ListProductInventories(ctx,
        &shop_v1.ListProductInventoriesRequest{NumOfProducts: 10})
    if status.Code(err) != codes.OK {
        t.Fatalf("unexpected error: %v", err)
    }
    if diff := cmp.Diff(want, res.ProductInventories, opts); diff != "" {
        t.Errorf("(-want, +got)\n%s", diff)
    }
}
```

### Testing ID（tid）

並列テストでフェイクサービスが「どのテストからのリクエストか」を判別するための仕組み：

```go
tid, ctx := tid.New(context.Background())
// ctx を使ってエンドポイントを呼ぶと TID が gRPC ヘッダーで伝搬される
fakeWarehouseServer.SetXxxResponse(tid, response, nil)
```

サービス側では `tid.NewGRPCHeaderPropagator()` インタセプタが必要：

```go
grpcOpts := []grpc.ServerOption{
    grpc_middleware.WithUnaryServerChain(tid.NewGRPCHeaderPropagator()),
}
```

---

## 6. テストの並列化

### `t.Parallel()` の動作

| 動作 | 説明 |
|------|------|
| **動作1** | `t.Parallel()` 未呼び出しのトップレベルテスト関数が全て終了してから並列テストが再開 |
| **動作2** | サブテストが `t.Parallel()` を呼ぶと、**親が戻るまで** 一時停止 |

並列性最大化には**トップレベルとサブテストの両方で** `t.Parallel()` を呼ぶ。

### defer vs t.Cleanup()

| 状況 | 推奨 |
|------|------|
| サブテストに `t.Parallel()` なし | `defer` / `t.Cleanup()` どちらでも可 |
| サブテストに `t.Parallel()` あり | **`t.Cleanup()` 必須** |

> **プロジェクト規則**: 「後処理は常に `t.Cleanup()` で書く」と統一するのが推奨。

### 並列レベル指定

```bash
go test -tags=e2e -parallel 16  # デフォルトは GOMAXPROCS
# DB通信が多い場合はコア数より大きい値が効果的
```

---

## 7. カバレッジ取得

```makefile
coverage_build:
    rm -fr coverage && mkdir coverage
    go build -race -cover -o bin/shop_server -coverpkg=$(COVER_PKGS) .
    # 末尾の `.` を忘れるとカバレッジが収集されない
```

```bash
# テスト実行後
(cd ..; go tool covdata percent -i=coverage)
(cd ..; go tool covdata textfmt -i=coverage -o profile.txt; go tool cover -html=profile.txt)
```

---

## 8. ステージング・本番環境への対応

| 対応内容 | 実装方法 |
|---------|---------|
| 接続先切替 | 独自フラグ（例: `-e2emode=staging`）でモード指定 |
| ローカルサービス起動スキップ | ステージング・本番モード時はサービス起動処理を省略 |
| テストスキップ制御 | 本番非対応テストは `t.Skip()` でスキップ |
| ベンチマーク | 本番環境接続モードで `go test -bench=.` による性能測定が可能 |
