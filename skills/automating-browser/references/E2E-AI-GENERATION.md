# E2E-AI-GENERATION.md

PlaywrightとAIを活用したテスト生成のベストプラクティス。Codegen、Playwright MCP、GitHub Copilotを組み合わせて、効率的にテストを作成・改善する方法を解説します。

---

## Playwright Codegen の活用

### 基本的な使い方

Playwright Codegenは、ブラウザでの操作を記録してテストスクリプトに変換するツールです。

```bash
npx playwright codegen https://www.google.com/
```

起動すると2つのウィンドウが表示されます:

- **ブラウザ**: 実際に操作を行う
- **Playwright Inspector**: 生成されたコードをリアルタイムで表示

### Pick Locator 機能

記録モードを使わない場合でも、要素にホバーするだけで最適なロケーターを確認できます。

### アサーションの追加

1. Inspectorツールバーのアサーションアイコンをクリック
2. 検証したい要素を選択
3. アサーションタイプを選択（visibility、text、value等）

```typescript
// 自動生成されたアサーション例
await expect(page.getByText('Success')).toBeVisible();
```

**重要**: アサーションなしでは、テストは操作を実行するだけで、実際の動作を検証しません。

### 言語の選択

対応言語: TypeScript、JavaScript、Python、C#、Java

```bash
# 例: Pythonでコード生成
npx playwright codegen --lang=python
```

### Codegenの制限

- **基本的なスクリプト**: 複雑なシナリオには手動調整が必要
- **ロジックなし**: 条件分岐、ループ、エラーハンドリングは含まれない
- **ロケーターの精度**: 一部のロケーターは安定性のため調整が必要

---

## Playwright MCP によるAI連携

### Playwright MCPとは

**Playwright Model Context Protocol (MCP)** は、AIモデル（ChatGPT、Claude等）にブラウザ操作能力を付与するツールです。

- **Eyes (目)**: 構造化されたWebページスナップショットでページを「見る」
- **Hands (手)**: クリック、入力、ファイルアップロード等で「操作する」

MCPはPlaywrightのaccessibility treeを解析し、AIが直接Webページと対話できるようにします。

### インストール方法

#### VS Code CLIでのインストール（推奨）

```bash
code --add-mcp '{"name":"playwright","command":"npx","args": ["@playwright/mcp@latest"]}'
```

**エラー発生時** (`code: command not found`):

1. VS Codeのコマンドパレット (`Ctrl+Shift+P` / `Cmd+Shift+P`) を開く
2. `Shell Command: Install 'code' command in PATH` を実行
3. ターミナルを再起動

#### GitHubリポジトリからの直接インストール

1. [Playwright MCP GitHub](https://github.com/microsoft/playwright-mcp) にアクセス
2. **Install in VS Code** ボタンをクリック
3. VS Codeが自動的にMCPサーバーを設定

### GitHub Copilotとの統合

1. VS Codeの拡張機能で「GitHub Copilot」と「GitHub Copilot Chat」をインストール
2. セカンダリサイドバーを開く (`Ctrl+Alt+B` / `Cmd+Alt+B`)
3. Copilot Chatウィンドウで **Agent モード** に切り替え
4. モデルとして **Claude** を選択

### MCPを使ったテスト生成

**自然言語プロンプトでテスト作成**:

```
Playwrightを使って、mashable.comのブログページが読み込まれ、
検索入力が機能し、タグをクリックして投稿が正しくフィルタされることを確認するテストを生成してください。
```

Copilotは以下を実行します:

1. ブラウザを起動してページに移動
2. Playwrightのスナップショットツールでページ構造を取得
3. DOM構造を分析（ログインフォーム、ボタン、入力フィールド等を識別）
4. テストスクリプトを生成
5. テストを実行するかどうか確認

**認証が必要なページの処理**:

- Copilotは自動的に「Sign In」ボタンを検出
- パスワード入力はAIに共有しない（セキュリティ警告）
- 手動でログイン→Copilotが続きを処理

### MCP利用時の実行プロセス

```typescript
// Copilotが生成したテストをCLIで実行
npx playwright test
```

Copilotはテスト実行も支援できますが、失敗した場合は:

1. **Copy Prompt** ボタンでエラー詳細をコピー
2. LLM（ChatGPT/Claude等）に貼り付け
3. 根本原因の分析と修正案を取得

### プロンプトエンジニアリングのコツ

**明確な指示**:
```
❌ 悪い例: "テストを作って"
✅ 良い例: "ブログページの検索機能が動作し、タグフィルタが正しく動くことを確認するテストを生成"
```

**段階的な指示**:
```
1. "GitHubリポジトリを開く"
2. "Watchボタンをクリック"
3. "All activityを選択"
```

**リトライと改善**:
- Copilotが生成したコードが不完全な場合
- 「エッジケースを追加してください」
- 「エラーハンドリングを強化してください」

### リポジトリコンテキストの追加

`.github/copilot-instructions.md` を追加して、プロジェクト固有のルールをCopilotに伝えます:

- アプリの構成方法
- テスト・デプロイ方法
- コーディング規約

参考:
- [github/awesome-copilot](https://github.com/github/awesome-copilot) にフレームワーク別のテンプレートが用意
- [Playwright TypeScript Instructions](https://github.com/github/awesome-copilot/blob/main/instructions/playwright-typescript.instructions.md)

---

## AI生成スクリプトの改善

### 基本的な改善パターン

#### 1. ロケーターの改善

**悪い例**:
```typescript
await page.click('button');
```

**良い例**:
```typescript
await page.getByRole('button', { name: 'Submit' }).click();
```

**ベストプラクティス**:
- `getByRole()` や `getByText()` を使用
- `data-testid` 属性を活用
- CSS セレクター (`div:nth-child(3)`) は避ける

#### 2. エラーハンドリングの追加

```typescript
import { test, expect } from '@playwright/test';

test('improved test', async ({ page }) => {
  try {
    await page.goto('https://example.com', { timeout: 30000 });
    await expect(page.getByText('Welcome')).toBeVisible();
    await page.getByRole('link', { name: 'Browse' }).click();
  } catch (error) {
    console.error('Something went wrong:', error);
    throw error;
  }
});
```

**`catch` ブロックの活用**:
- エラーのロギング
- CI/CDでの失敗スクリーンショット取得

#### 3. アサーションの追加

**操作だけでは不十分**:
```typescript
// ❌ クリックしただけ
await page.getByRole('button', { name: 'Submit' }).click();
```

**結果を検証する**:
```typescript
// ✅ クリック後の結果を確認
await page.getByRole('button', { name: 'Submit' }).click();
await expect(page.getByText('Success')).toBeVisible();
```

#### 4. スタンドアロンスクリプトからテストランナーへの変換

**AI生成 (スタンドアロン)**:
```typescript
const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  await page.goto('url');
  await page.click('button');
  await browser.close();
})();
```

**改善版 (テストランナー)**:
```typescript
import { test, expect } from '@playwright/test';

test.describe('Login Tests', () => {
  test('should log in successfully', async ({ page }) => {
    await page.goto('url');
    await page.getByRole('button', { name: 'Log In' }).click();
    await expect(page.getByText('Welcome')).toBeVisible();
  });
});
```

---

## Copy Prompt 機能

テストが失敗した際、**Copy Prompt** ボタンが以下のツールに表示されます:

- HTML Report
- Trace Viewer
- UI Mode

### 使い方

1. Copy Promptボタンをクリック
2. 生成されたプロンプトをLLM（ChatGPT、Claude等）に貼り付け
3. エラーの説明、根本原因、修正案を取得

**メリット**:
- エラーを手動で説明する手間を削減
- デバッグが高速化・正確化

---

## レジリエントなロケーター戦略

### フォールバックロケーター

複数のロケーターを試して、最初に成功したものを使用します。

```typescript
import { test, expect } from '@playwright/test';

test('Google search button', async ({ page }) => {
  await page.goto('https://google.com');

  const locators = [
    page.getByTestId('submit-button'),
    page.getByRole("button", { name: "Google Search" }),
    page.getByText('Google Search'),
  ];

  for (const locator of locators) {
    try {
      await locator.click({ timeout: 5000 });
      console.log('Success!');
      return;
    } catch {
      console.warn(`Locator failed: ${locator}, trying next...`);
    }
  }
  throw new Error("All locators failed for Submit button");
});
```

### リトライロジック

```typescript
async function retryAction(action, maxAttempts = 3) {
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      await action();
      return;
    } catch (error) {
      console.warn(`Attempt ${attempt} failed: ${error}`);
      if (attempt === maxAttempts) throw error;
      await new Promise(res => setTimeout(res, 1000));
    }
  }
}

// 使用例
await retryAction(() => page.getByText("Login").click());
```

**注意**: リトライ回数を制限して、無限ループやリソース浪費を防ぐ。

### 動的コンテンツの処理

#### 明示的な待機

```typescript
// 要素が表示されるまで最大10秒待機
await page.waitForSelector('img', {
  state: 'visible',
  timeout: 10000,
});
```

#### カスタム条件の待機

```typescript
await page.waitForFunction(() =>
  document.querySelector('.loaded') !== null,
  { timeout: 15000 }
);
```

#### `expect().toPass()` の活用

```typescript
// ローダーが消えるまでリトライ
await expect(async () => {
  await expect(page.locator('.loader')).not.toBeVisible();
}).toPass({
  timeout: 3000,
  interval: 1000,
});
```

### フォールバック経路

```typescript
test('should navigate to sweets page', async ({ page }) => {
  await page.goto('https://sweetshop.netlify.app/',
                  { waitUntil: 'domcontentloaded' });
  try {
    // リンククリックを試行
    await page.getByRole('link', { name: 'Browse Sweets' })
              .click({ timeout: 5000 });
    await expect(page).toHaveURL(/sweets$/, { timeout: 5000 });
  } catch (error) {
    console.warn('Link click failed, navigating directly...');
    // フォールバック: 直接URLに移動
    await page.goto('https://sweetshop.netlify.app/sweets',
                    { waitUntil: 'domcontentloaded' });
    await expect(page).toHaveURL(/sweets$/, { timeout: 10000 });
  }
});
```

**`waitUntil: 'domcontentloaded'`**:
- HTMLの読み込み完了を待つ（画像・CSS・iframeは待たない）
- テストの高速化に有効

---

## AI駆動のセルフヒーリング

### セルフヒーリングとは

UI変更（ボタン移動、色変更等）に対して、テストが自動的に適応する仕組み。

### 仕組み

1. **初回実行**: AIエンジンがボタンの特徴を記録
   - テキスト ("Submit")
   - 外観（サイズ、色）
   - 位置（隣接する要素、親フォーム）
   - ID

2. **次回実行**: 元のIDで要素が見つからない場合
   - 他の特徴（テキスト、位置等）で検索
   - 一致する要素を発見 → 自動的にテストを更新

3. **ログ記録**: 変更内容を記録して、次回以降の学習に活用

### メリット

- **メンテナンス時間の削減**: 軽微なUI変更で壊れない
- **信頼性の向上**: 本当のバグだけが失敗を引き起こす

### 商用ツール例

- **Testim**
- **Mabl**

（注: Playwrightにはビルトインのセルフヒーリング機能はありません）

### デメリット

- **実行速度の低下**: 追加の分析処理が必要
- **大規模リデザインには無力**: 構造的変更には対応できない
- **偽陽性のリスク**: 過度に寛容な設定は本当の問題を隠す可能性
- **複雑性の増加**: 小規模プロジェクトには過剰な場合がある

---

## まとめ

AI駆動のテスト生成は、テスト自動化を加速させます:

- **Codegen**: ブラウザ操作から即座にコード生成
- **Playwright MCP + Copilot**: 自然言語でテストを作成
- **Copy Prompt**: 失敗したテストのデバッグを高速化
- **レジリエントなロケーター**: フォールバック・リトライで安定性向上
- **セルフヒーリング**: UI変更への自動適応（商用ツール）

**ベストプラクティス**:
- AIが生成したコードを必ずレビューする
- ロケーターを改善し、エラーハンドリングを追加
- アサーションで結果を検証する
- 複雑なシナリオには手動調整が必要

AI生成は「80-90%」を担当し、残りの「10-20%」は人間の洞察力で補完しましょう。
