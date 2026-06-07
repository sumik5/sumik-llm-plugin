# Terraform Provider開発ガイド

カスタムProviderの設計・実装・公開の実践パターン。Terraform Plugin Framework (Protocol v6) を使用したGo言語実装。

---

## 📋 目次

1. [Provider開発が必要な場面](#provider開発が必要な場面)
2. [開発環境のセットアップ](#開発環境のセットアップ)
3. [Plugin Frameworkの基礎機能](#plugin-frameworkの基礎機能)
4. [Providerインターフェース実装](#providerインターフェース実装)
5. [データソース実装](#データソース実装)
6. [リソース実装](#リソース実装)
7. [関数実装](#関数実装)
8. [テスト戦略](#テスト戦略)
9. [公開とリリース](#公開とリリース)

---

## Provider開発が必要な場面

### 判断基準テーブル

| 状況 | Provider開発 | 理由 |
|------|-------------|------|
| 開発者向けプラットフォーム提供 | ✅ 推奨 | Terraformでのプラットフォーム制御を可能にする |
| 既存Providerのない新規サービス | ✅ 推奨 | コミュニティ貢献の機会 |
| データ処理ロジックの共有 | ✅ 検討 | 関数を使った再利用可能なロジック提供 |
| 既存Providerで十分 | ❌ 不要 | モジュールでカスタマイズ |
| 一時的な社内ツール | ❌ 不要 | External Providerや`local-exec`で代替 |

### Provider開発の利点

- **統一されたインターフェース**: Terraform言語での操作
- **状態管理の自動化**: TerraformのState管理を活用
- **型安全性**: スキーマによる入力検証
- **バージョン管理**: Providerのバージョニングとレジストリ配布

---

## 開発環境のセットアップ

### 前提条件

- Go 1.21以上（最新バージョン推奨）
- Terraform 1.5以上
- IDE拡張（VSCodeならGo言語拡張）

### テンプレートからの開始

```bash
# HashiCorp公式テンプレートをクローン
git clone https://github.com/hashicorp/terraform-provider-scaffolding-framework.git terraform-provider-myservice
cd terraform-provider-myservice

# モジュール名を変更
go mod edit -module github.com/myorg/terraform-provider-myservice
go mod tidy

# テンプレートのクリーンアップ
# 1. .github/dependabot.yml の @TODO コメントを処理
# 2. .github/CODEOWNERS を自組織の情報に更新
# 3. .copywrite.hcl を削除（HashiCorp内部用）
# 4. README.md のdescriptionを更新
# 5. main.go のモジュール名を更新
```

### Developer Overrides設定

ローカル開発時にレジストリからダウンロードせず、ビルド済みProviderを使用する設定。

```bash
# GOBINパスを確認
go env GOBIN  # 空ならば $HOME/go/bin を使用
```

`~/.terraformrc` に以下を追加:

```hcl
provider_installation {
  dev_overrides {
    "myorg/myservice" = "/Users/username/go/bin/"  # 自分のGOBINパス
  }

  # 他のProviderは通常通りレジストリから取得
  direct {}
}
```

この設定により、`go install` で作成されたバイナリがTerraformから直接参照される。

---

## Plugin Frameworkの基礎機能

### スキーマ定義

すべてのProvider、リソース、データソースはスキーマでパラメータを定義する。

#### スキーマの構成要素

```go
resp.Schema = schema.Schema{
    Attributes: map[string]schema.Attribute{
        "host": schema.StringAttribute{
            MarkdownDescription: "接続先ホスト",
            Optional:            true,
            Default:             stringdefault.StaticString("example.com"),
        },
        "api_key": schema.StringAttribute{
            MarkdownDescription: "API認証キー",
            Optional:            true,
            Sensitive:           true,  // ログから除外
        },
        "timeout": schema.Int64Attribute{
            MarkdownDescription: "タイムアウト（秒）",
            Optional:            true,
            Computed:            true,
            Default:             int64default.StaticInt64(30),
        },
    },
}
```

#### スキーマ属性の種類

| 属性 | 説明 | 使用場面 |
|------|------|----------|
| `Required` | 必須パラメータ | ユーザーが必ず指定する値 |
| `Optional` | 省略可能パラメータ | デフォルト値がある、または任意 |
| `Computed` | 計算される値 | Providerが生成する値（IDなど） |
| `Sensitive` | 機密情報 | ログに出力されない値 |
| `Default` | デフォルト値 | `Optional` + `Computed` 必須 |
| `DeprecationMessage` | 非推奨警告 | 将来削除予定の属性 |

### エラーハンドリングとロギング

#### Diagnosticsによるエラー収集

```go
func (p *MyProvider) Configure(ctx context.Context, req provider.ConfigureRequest, resp *provider.ConfigureResponse) {
    var data MyProviderModel
    resp.Diagnostics.Append(req.Config.Get(ctx, &data)...)

    // 複数のエラーを収集（即座にreturnしない）
    if data.APIKey.IsUnknown() {
        resp.Diagnostics.AddAttributeError(
            path.Root("api_key"),
            "Unknown API Key",
            "APIキーが不明です。静的な値を設定するか、環境変数を使用してください。",
        )
    }

    apiKey := os.Getenv("MYSERVICE_API_KEY")
    if !data.APIKey.IsNull() {
        apiKey = data.APIKey.ValueString()
    }
    if apiKey == "" {
        resp.Diagnostics.AddAttributeError(
            path.Root("api_key"),
            "Missing API Key",
            "APIキーが設定されていません。",
        )
    }

    // すべてのエラーを収集してから終了
    if resp.Diagnostics.HasError() {
        return
    }

    // クライアント初期化
}
```

#### tflogによる構造化ロギング

```go
import "github.com/hashicorp/terraform-plugin-log/tflog"

func (r *MyResource) Create(ctx context.Context, req resource.CreateRequest, resp *resource.CreateResponse) {
    tflog.Debug(ctx, "リソース作成開始")

    // フィールドをログに追加（マスク可能）
    ctx = tflog.SetField(ctx, "resource_id", id)
    ctx = tflog.MaskFieldValuesWithFieldKeys(ctx, "api_key")

    tflog.Info(ctx, "リソース作成完了", map[string]any{
        "id": id,
        "name": name,
    })
}
```

**重要**: `log.Fatal()` や `panic()` は使用しない。Terraformに適切なエラーを返せず、状態が破損する可能性がある。

### テストフレームワーク

#### Unit TestとAcceptance Testの使い分け

| テストタイプ | 実行条件 | 用途 | コスト |
|-------------|---------|------|--------|
| Unit Test | 常に実行 | ロジックのみテスト（関数等） | 無料 |
| Acceptance Test | `TF_ACC=1` 設定時 | 実際のAPI呼び出しテスト | リソース課金 |

```go
// Unit Test（関数のテスト）
func TestMyFunction_Logic(t *testing.T) {
    // TF_ACC不要、API呼び出しなし
}

// Acceptance Test（リソースのテスト）
func TestAccMyResource_Basic(t *testing.T) {
    // TF_ACC=1 必須、実際にリソース作成
}
```

---

## Providerインターフェース実装

### Providerインターフェース構造

| 関数 | 役割 |
|------|------|
| `Metadata` | Providerのバージョンと型プレフィックス |
| `Schema` | Providerの設定スキーマ |
| `Configure` | クライアント初期化とリソース/データソースへの共有 |
| `Resources` | リソースのコンストラクタリスト |
| `DataSources` | データソースのコンストラクタリスト |
| `Functions` | 関数のコンストラクタリスト |
| `New` | Providerインスタンス作成 |

### Providerモデルとスキーマ

```go
// Provider構造体
type MyProvider struct {
    version string
}

// Providerモデル（Terraformとの値のやり取り）
type MyProviderModel struct {
    Host      types.String `tfsdk:"host"`
    APIKey    types.String `tfsdk:"api_key"`
    Timeout   types.Int64  `tfsdk:"timeout"`
}

func (p *MyProvider) Metadata(ctx context.Context, req provider.MetadataRequest, resp *provider.MetadataResponse) {
    resp.TypeName = "myservice"  // リソース名のプレフィックスになる
    resp.Version = p.version
}

func (p *MyProvider) Schema(ctx context.Context, req provider.SchemaRequest, resp *provider.SchemaResponse) {
    resp.Schema = schema.Schema{
        Attributes: map[string]schema.Attribute{
            "host": schema.StringAttribute{
                MarkdownDescription: "接続先ホスト",
                Optional:            true,
            },
            "api_key": schema.StringAttribute{
                MarkdownDescription: "API認証キー",
                Optional:            true,
                Sensitive:           true,
            },
            "timeout": schema.Int64Attribute{
                MarkdownDescription: "タイムアウト（秒）",
                Optional:            true,
                Computed:            true,
                Default:             int64default.StaticInt64(30),
            },
        },
    }
}
```

### Configure実装パターン

環境変数とProvider blockの両方をサポートする標準パターン:

```go
func (p *MyProvider) Configure(ctx context.Context, req provider.ConfigureRequest, resp *provider.ConfigureResponse) {
    var data MyProviderModel
    resp.Diagnostics.Append(req.Config.Get(ctx, &data)...)

    // パラメータごとに処理
    // 1. Unknown状態のチェック
    if data.APIKey.IsUnknown() {
        resp.Diagnostics.AddAttributeError(
            path.Root("api_key"),
            "Unknown API Key",
            "APIキーが不明です。",
        )
    }

    // 2. 環境変数からデフォルト値を取得
    apiKey := os.Getenv("MYSERVICE_API_KEY")

    // 3. Provider blockの値で上書き
    if !data.APIKey.IsNull() {
        apiKey = data.APIKey.ValueString()
    }

    // 4. 複雑なバリデーション
    if apiKey == "" {
        resp.Diagnostics.AddAttributeError(
            path.Root("api_key"),
            "Missing API Key",
            "APIキーが設定されていません。",
        )
    }

    // すべてのパラメータを処理後、エラーチェック
    if resp.Diagnostics.HasError() {
        return
    }

    // クライアント初期化
    config := myservice.Config{
        Host:    host,
        APIKey:  apiKey,
        Timeout: timeout,
    }
    client := myservice.NewClient(&config)

    // リソースとデータソースにクライアントを渡す
    resp.DataSourceData = client
    resp.ResourceData = client
    // 注意: FunctionData は存在しない（関数は外部APIを呼ばない設計）
}
```

### リソース・データソース・関数の登録

```go
func (p *MyProvider) Resources(ctx context.Context) []func() resource.Resource {
    return []func() resource.Resource{
        NewMyResource,
        NewAnotherResource,
    }
}

func (p *MyProvider) DataSources(ctx context.Context) []func() datasource.DataSource {
    return []func() datasource.DataSource{
        NewMyDataSource,
    }
}

func (p *MyProvider) Functions(ctx context.Context) []func() function.Function {
    return []func() function.Function{
        NewMyFunction,
    }
}
```

### Providerテスト

```go
package provider

import (
    "os"
    "testing"

    "github.com/hashicorp/terraform-plugin-framework/providerserver"
    "github.com/hashicorp/terraform-plugin-go/tfprotov6"
    "github.com/stretchr/testify/assert"
)

// テスト用Providerファクトリー（全テストで共通使用）
var testAccProtoV6ProviderFactories = map[string]func() (tfprotov6.ProviderServer, error){
    "myservice": providerserver.NewProtocol6WithError(New("test")()),
}

// テスト前チェック（Acceptance Testで必須環境変数を確認）
func testAccPreCheck(t *testing.T) {
    apiKey := os.Getenv("MYSERVICE_API_KEY")
    assert.NotEmpty(t, apiKey, "MYSERVICE_API_KEY must be set for acceptance tests")

    host := os.Getenv("MYSERVICE_HOST")
    assert.NotEmpty(t, host, "MYSERVICE_HOST must be set for acceptance tests")
}
```

---

## データソース実装

### データソースインターフェース

| 関数 | 役割 |
|------|------|
| `Metadata` | データソースの名前 |
| `Schema` | データソースのスキーマ |
| `Configure` | Providerからクライアントを取得 |
| `Read` | パラメータでデータを検索し、状態に保存 |

### スキーマ定義（パラメータとAttributesの区別）

```go
type AccountDataSourceModel struct {
    Username    types.String `tfsdk:"username"`      // パラメータ（Required）
    Id          types.String `tfsdk:"id"`           // Attribute（Computed）
    DisplayName types.String `tfsdk:"display_name"` // Attribute（Computed）
    Email       types.String `tfsdk:"email"`        // Attribute（Computed）
}

func (d *AccountDataSource) Schema(ctx context.Context, req datasource.SchemaRequest, resp *datasource.SchemaResponse) {
    resp.Schema = schema.Schema{
        MarkdownDescription: "アカウント情報を取得",
        Attributes: map[string]schema.Attribute{
            "username": schema.StringAttribute{
                MarkdownDescription: "検索するユーザー名",
                Required:            true,  // ユーザーが指定する検索条件
            },
            "id": schema.StringAttribute{
                MarkdownDescription: "アカウントID",
                Computed:            true,  // APIから取得する値
            },
            "display_name": schema.StringAttribute{
                MarkdownDescription: "表示名",
                Computed:            true,
            },
            "email": schema.StringAttribute{
                MarkdownDescription: "メールアドレス",
                Computed:            true,
            },
        },
    }
}
```

### Configure実装（クライアント取得）

```go
type AccountDataSource struct {
    client *myservice.Client
}

func (d *AccountDataSource) Configure(ctx context.Context, req datasource.ConfigureRequest, resp *datasource.ConfigureResponse) {
    if req.ProviderData == nil {
        return
    }

    client, ok := req.ProviderData.(*myservice.Client)
    if !ok {
        resp.Diagnostics.AddError(
            "Unexpected Data Source Configure Type",
            fmt.Sprintf("Expected *myservice.Client, got: %T", req.ProviderData),
        )
        return
    }

    d.client = client
}
```

### Read実装（データ取得とState保存）

```go
func (d *AccountDataSource) Read(ctx context.Context, req datasource.ReadRequest, resp *datasource.ReadResponse) {
    var data AccountDataSourceModel

    // ユーザーが設定したパラメータを取得
    resp.Diagnostics.Append(req.Config.Get(ctx, &data)...)
    if resp.Diagnostics.HasError() {
        return
    }

    // APIでデータ検索
    account, err := d.client.LookupAccount(ctx, data.Username.ValueString())
    if err != nil {
        resp.Diagnostics.AddError(
            "Failed to lookup account",
            fmt.Sprintf("API error: %s", err),
        )
        return
    }

    // モデルにデータを格納
    data.Id = types.StringValue(account.ID)
    data.DisplayName = types.StringValue(account.DisplayName)
    data.Email = types.StringValue(account.Email)

    tflog.Trace(ctx, "データソースを読み込み完了")

    // Stateに保存
    resp.Diagnostics.Append(resp.State.Set(ctx, &data)...)
}
```

### Registration（Providerへの登録）

```go
func (p *MyProvider) DataSources(ctx context.Context) []func() datasource.DataSource {
    return []func() datasource.DataSource{
        NewAccountDataSource,  // コンストラクタを追加
    }
}

func NewAccountDataSource() datasource.DataSource {
    return &AccountDataSource{}
}
```

### 使用例

```hcl
terraform {
  required_providers {
    myservice = {
      source = "myorg/myservice"
    }
  }
}

provider "myservice" {
  # 環境変数で設定済みなら省略可能
}

data "myservice_account" "admin" {
  username = "admin@example.com"
}

output "admin_id" {
  value = data.myservice_account.admin.id
}
```

### データソーステスト

```go
func TestAccAccountDataSource(t *testing.T) {
    resource.Test(t, resource.TestCase{
        PreCheck:                 func() { testAccPreCheck(t) },
        ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
        Steps: []resource.TestStep{
            {
                Config: `
data "myservice_account" "test" {
  username = "testuser@example.com"
}
`,
                Check: resource.ComposeAggregateTestCheckFunc(
                    resource.TestCheckResourceAttr("data.myservice_account.test", "username", "testuser@example.com"),
                    resource.TestCheckResourceAttrSet("data.myservice_account.test", "id"),
                    resource.TestCheckResourceAttrSet("data.myservice_account.test", "display_name"),
                ),
            },
        },
    })
}
```

---

## リソース実装

### リソースインターフェース

| 関数 | 役割 |
|------|------|
| `Metadata` | リソースの名前 |
| `Schema` | リソースのスキーマ |
| `Configure` | Providerからクライアントを取得 |
| `Create` | 新規リソース作成 |
| `Read` | 既存リソースの読み込み |
| `Update` | リソースの更新 |
| `Delete` | リソースの削除 |
| `ImportState` | 既存リソースのインポート |

### スキーマ定義（Computed属性とPlan Modifiers）

```go
type PostResourceModel struct {
    Id         types.String `tfsdk:"id"`
    CreatedAt  types.String `tfsdk:"created_at"`
    Content    types.String `tfsdk:"content"`
    Visibility types.String `tfsdk:"visibility"`
    Sensitive  types.Bool   `tfsdk:"sensitive"`
}

func (r *PostResource) Schema(ctx context.Context, req resource.SchemaRequest, resp *resource.SchemaResponse) {
    resp.Schema = schema.Schema{
        MarkdownDescription: "投稿リソース",
        Attributes: map[string]schema.Attribute{
            "id": schema.StringAttribute{
                MarkdownDescription: "投稿ID",
                Computed:            true,
                PlanModifiers: []planmodifier.String{
                    stringplanmodifier.UseStateForUnknown(), // "known after apply"を防ぐ
                },
            },
            "created_at": schema.StringAttribute{
                MarkdownDescription: "作成日時",
                Computed:            true,
                PlanModifiers: []planmodifier.String{
                    stringplanmodifier.UseStateForUnknown(),
                },
            },
            "content": schema.StringAttribute{
                MarkdownDescription: "投稿内容",
                Required:            true, // ユーザー必須入力
            },
            "visibility": schema.StringAttribute{
                MarkdownDescription: "公開範囲（public, unlisted, private, direct）",
                Optional:            true,
                Computed:            true,  // デフォルト値があるのでComputed必須
                Default:             stringdefault.StaticString("public"),
            },
            "sensitive": schema.BoolAttribute{
                MarkdownDescription: "センシティブコンテンツフラグ",
                Optional:            true,
                Computed:            true,
                Default:             booldefault.StaticBool(false),
            },
        },
    }
}
```

### Create実装

```go
func (r *PostResource) Create(ctx context.Context, req resource.CreateRequest, resp *resource.CreateResponse) {
    var data PostResourceModel

    // Planからパラメータ取得
    resp.Diagnostics.Append(req.Plan.Get(ctx, &data)...)
    if resp.Diagnostics.HasError() {
        return
    }

    // APIでリソース作成
    post, err := r.client.CreatePost(ctx, myservice.PostRequest{
        Content:    data.Content.ValueString(),
        Visibility: data.Visibility.ValueString(),
        Sensitive:  data.Sensitive.ValueBool(),
    })
    if err != nil {
        resp.Diagnostics.AddError("Failed to create post", err.Error())
        return
    }

    // サーバーから返された値をモデルに反映（正規化が必要な場合も含む）
    data.Id = types.StringValue(post.ID)
    data.CreatedAt = types.StringValue(post.CreatedAt.String())
    data.Content = types.StringValue(normalizeContent(post.Content))  // HTML削除等
    data.Visibility = types.StringValue(post.Visibility)
    data.Sensitive = types.BoolValue(post.Sensitive)

    tflog.Trace(ctx, "リソース作成完了")

    // Stateに保存
    resp.Diagnostics.Append(resp.State.Set(ctx, &data)...)
}
```

### Read実装

```go
func (r *PostResource) Read(ctx context.Context, req resource.ReadRequest, resp *resource.ReadResponse) {
    var data PostResourceModel

    // Stateから現在の値を取得
    resp.Diagnostics.Append(req.State.Get(ctx, &data)...)
    if resp.Diagnostics.HasError() {
        return
    }

    // IDでリソース取得
    post, err := r.client.GetPost(ctx, data.Id.ValueString())
    if err != nil {
        resp.Diagnostics.AddError("Failed to read post", err.Error())
        return
    }

    // サーバーの最新状態をモデルに反映（Createと同じ正規化が必要）
    data.Id = types.StringValue(post.ID)
    data.CreatedAt = types.StringValue(post.CreatedAt.String())
    data.Content = types.StringValue(normalizeContent(post.Content))
    data.Visibility = types.StringValue(post.Visibility)
    data.Sensitive = types.BoolValue(post.Sensitive)

    // Stateを更新
    resp.Diagnostics.Append(resp.State.Set(ctx, &data)...)
}
```

### Update実装

```go
func (r *PostResource) Update(ctx context.Context, req resource.UpdateRequest, resp *resource.UpdateResponse) {
    var data PostResourceModel

    // 新しいPlanを取得
    resp.Diagnostics.Append(req.Plan.Get(ctx, &data)...)
    if resp.Diagnostics.HasError() {
        return
    }

    // 既存リソースを更新
    post, err := r.client.UpdatePost(ctx, data.Id.ValueString(), myservice.PostRequest{
        Content:    data.Content.ValueString(),
        Visibility: data.Visibility.ValueString(),
        Sensitive:  data.Sensitive.ValueBool(),
    })
    if err != nil {
        resp.Diagnostics.AddError("Failed to update post", err.Error())
        return
    }

    // サーバーの応答をモデルに反映
    data.Id = types.StringValue(post.ID)
    data.CreatedAt = types.StringValue(post.CreatedAt.String())
    data.Content = types.StringValue(normalizeContent(post.Content))
    data.Visibility = types.StringValue(post.Visibility)
    data.Sensitive = types.BoolValue(post.Sensitive)

    // Stateを更新
    resp.Diagnostics.Append(resp.State.Set(ctx, &data)...)
}
```

### Delete実装

```go
func (r *PostResource) Delete(ctx context.Context, req resource.DeleteRequest, resp *resource.DeleteResponse) {
    var data PostResourceModel

    // Stateから削除対象の情報を取得
    resp.Diagnostics.Append(req.State.Get(ctx, &data)...)
    if resp.Diagnostics.HasError() {
        return
    }

    // APIでリソース削除
    err := r.client.DeletePost(ctx, data.Id.ValueString())
    if err != nil {
        resp.Diagnostics.AddError("Failed to delete post", err.Error())
        return
    }

    // Deleteが成功すれば、TerraformがStateから自動削除（明示的なState操作不要）
}
```

### リソーステスト（Create/Update/Import）

```go
func TestAccPostResource(t *testing.T) {
    resource.Test(t, resource.TestCase{
        PreCheck:                 func() { testAccPreCheck(t) },
        ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
        Steps: []resource.TestStep{
            // Step 1: Create
            {
                Config: testAccPostResourceConfig("First Post"),
                Check: resource.ComposeAggregateTestCheckFunc(
                    resource.TestCheckResourceAttr("myservice_post.test", "content", "First Post"),
                    resource.TestCheckResourceAttr("myservice_post.test", "visibility", "public"),
                    resource.TestCheckResourceAttrSet("myservice_post.test", "id"),
                ),
            },
            // Step 2: Import
            {
                ResourceName:      "myservice_post.test",
                ImportState:       true,
                ImportStateVerify: true,
            },
            // Step 3: Update
            {
                Config: testAccPostResourceConfig("Updated Post"),
                Check: resource.ComposeAggregateTestCheckFunc(
                    resource.TestCheckResourceAttr("myservice_post.test", "content", "Updated Post"),
                ),
            },
        },
    })
}

func testAccPostResourceConfig(content string) string {
    return fmt.Sprintf(`
resource "myservice_post" "test" {
  content = %[1]q
}
`, content)
}
```

---

## 関数実装

### 関数インターフェース

| 関数 | 役割 |
|------|------|
| `Metadata` | 関数の名前 |
| `Definition` | パラメータと戻り値の定義 |
| `Run` | 関数のロジック実行 |

### 関数の制約

- **外部API呼び出し禁止**: 関数は純粋なロジックのみ（データソースやリソースと異なる）
- **Terraform 1.8以降**: 関数機能は新しいため、古いバージョンでは無視される

### Definition実装

```go
type IdentityFunction struct{}

func (r IdentityFunction) Metadata(_ context.Context, req function.MetadataRequest, resp *function.MetadataResponse) {
    resp.Name = "identity"  // provider::myservice::identity として呼び出し可能
}

func (r IdentityFunction) Definition(_ context.Context, _ function.DefinitionRequest, resp *function.DefinitionResponse) {
    resp.Definition = function.Definition{
        Summary:             "Identity生成関数",
        MarkdownDescription: "ユーザー名とサーバーからIdentity文字列を生成します。",
        Parameters: []function.Parameter{
            function.StringParameter{
                Name:                "username",
                MarkdownDescription: "ユーザー名",
            },
            function.StringParameter{
                Name:                "server",
                MarkdownDescription: "サーバードメイン",
            },
        },
        Return: function.StringReturn{},  // 戻り値の型
    }
}
```

### Run実装

```go
func (r IdentityFunction) Run(ctx context.Context, req function.RunRequest, resp *function.RunResponse) {
    var username string
    var server string

    // 引数を取得
    resp.Error = function.ConcatFuncErrors(req.Arguments.Get(ctx, &username, &server))
    if resp.Error != nil {
        return
    }

    // ロジック実行（外部API呼び出しはしない）
    identity := fmt.Sprintf("@%s@%s", username, server)

    // 結果を設定
    resp.Error = function.ConcatFuncErrors(resp.Result.Set(ctx, identity))
}
```

### 関数テスト（Null/Unknown/Known）

```go
func TestIdentityFunction_Known(t *testing.T) {
    resource.UnitTest(t, resource.TestCase{
        TerraformVersionChecks: []tfversion.TerraformVersionCheck{
            tfversion.SkipBelow(tfversion.Version1_8_0),  // 1.8未満ではスキップ
        },
        ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
        Steps: []resource.TestStep{
            {
                Config: `
output "test" {
  value = provider::myservice::identity("user", "example.com")
}
`,
                Check: resource.ComposeAggregateTestCheckFunc(
                    resource.TestCheckOutput("test", "@user@example.com"),
                ),
            },
        },
    })
}

func TestIdentityFunction_Null(t *testing.T) {
    resource.UnitTest(t, resource.TestCase{
        TerraformVersionChecks: []tfversion.TerraformVersionCheck{
            tfversion.SkipBelow(tfversion.Version1_8_0),
        },
        ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
        Steps: []resource.TestStep{
            {
                Config: `
output "test" {
  value = provider::myservice::identity(null, null)
}
`,
                ExpectError: regexp.MustCompile(`argument must not be null`),
            },
        },
    })
}

func TestIdentityFunction_Unknown(t *testing.T) {
    resource.UnitTest(t, resource.TestCase{
        TerraformVersionChecks: []tfversion.TerraformVersionCheck{
            tfversion.SkipBelow(tfversion.Version1_8_0),
        },
        ProtoV6ProviderFactories: testAccProtoV6ProviderFactories,
        Steps: []resource.TestStep{
            {
                Config: `
resource "terraform_data" "test" {
  input = "user"
}

output "test" {
  value = provider::myservice::identity(terraform_data.test.output, "example.com")
}
`,
                Check: resource.ComposeAggregateTestCheckFunc(
                    resource.TestCheckOutput("test", "@user@example.com"),
                ),
            },
        },
    })
}
```

---

## テスト戦略

### テスト構成のベストプラクティス

| コンポーネント | テストタイプ | テスト内容 |
|--------------|------------|-----------|
| Provider | Acceptance | 環境変数チェック、ファクトリー登録 |
| データソース | Acceptance | APIからのデータ取得、Attribute検証 |
| リソース | Acceptance | Create/Read/Update/Delete/Import |
| 関数 | Unit | Known/Null/Unknown値の処理 |

### Acceptance Test実行

```bash
# 環境変数を設定
export MYSERVICE_API_KEY="your-api-key"
export MYSERVICE_HOST="https://api.example.com"

# テスト実行（makeコマンド推奨）
make testacc

# 手動実行の場合
TF_ACC=1 go test -v ./...
```

### テストヘルパー関数の共通化

```go
// provider_test.go に共通ヘルパーを配置

// すべてのAcceptance Testで共通使用するファクトリー
var testAccProtoV6ProviderFactories = map[string]func() (tfprotov6.ProviderServer, error){
    "myservice": providerserver.NewProtocol6WithError(New("test")()),
}

// すべてのAcceptance Testで共通使用する前提条件チェック
func testAccPreCheck(t *testing.T) {
    apiKey := os.Getenv("MYSERVICE_API_KEY")
    assert.NotEmpty(t, apiKey, "MYSERVICE_API_KEY must be set")

    host := os.Getenv("MYSERVICE_HOST")
    assert.NotEmpty(t, host, "MYSERVICE_HOST must be set")
}
```

---

## 公開とリリース

### ドキュメント自動生成

```bash
# tfplugindocsでドキュメント生成
go generate

# examples/ ディレクトリにサンプルを配置
# - examples/provider/provider.tf
# - examples/data-sources/myservice_account/data-source.tf
# - examples/resources/myservice_post/resource.tf
```

### GPGキーペア作成（初回のみ）

```bash
# GPGキー生成（RSA 4096bit）
gpg --full-generate-key
# - 種類: RSA and RSA
# - キーサイズ: 4096
# - 有効期限: デフォルト（Enter）
# - 名前/メール: 入力
# - パスフレーズ: 安全な値を設定

# USER-IDを記録（例: "Your Name <email@example.com>"）

# 公開鍵・秘密鍵をエクスポート
gpg --armor --export "USER-ID" > public.pem
gpg --armor --export-secret-keys "USER-ID" > private.pem

# GitHub Actionsのシークレットに登録
# - GPG_PRIVATE_KEY: private.pemの内容
# - PASSPHRASE: パスフレーズ
```

### レジストリ登録

#### Terraform Registry

1. [Terraform Registry](https://registry.terraform.io) にログイン
2. User Settings → Signing Keys → 公開鍵を追加
3. Publish → Provider → リポジトリを選択

#### OpenTofu Registry

1. [OpenTofu Registry GitHub](https://github.com/opentofu/registry) にIssue作成
2. Signing Key登録 Issue
3. Provider登録 Issue

### リリース作成

GitHub Releasesでセマンティックバージョンのタグを作成すると、`.github/workflows/release.yml` が自動的に:

1. Go Releaserでマルチアーキテクチャビルド
2. GPGキーで署名
3. GitHubリリースにアップロード
4. レジストリに反映

```bash
# リリース例
git tag v1.0.0
git push origin v1.0.0
# GitHub Actionsが自動ビルド・署名・公開
```

---

## まとめ

### Provider開発チェックリスト

- [ ] 開発環境セットアップ（Go、IDE拡張、developer overrides）
- [ ] Providerインターフェース実装（Metadata、Schema、Configure）
- [ ] データソース実装（必要に応じて）
- [ ] リソース実装（CRUD操作）
- [ ] 関数実装（必要に応じて）
- [ ] テスト作成（Acceptance Test + Unit Test）
- [ ] ドキュメント生成（`go generate`）
- [ ] GPGキー作成・登録
- [ ] レジストリ登録
- [ ] リリース作成

### 保守運用の推奨事項

- **Dependabot有効化**: Go依存関係の自動更新
- **pre-commit hooks**: `terraform fmt`、`go generate` の自動実行
- **CI/CDパイプライン**: テスト自動実行、リリース自動化
- **セマンティックバージョニング**: 破壊的変更は`MAJOR`バージョンアップ
- **ChangeLog管理**: リリースノートの自動生成
