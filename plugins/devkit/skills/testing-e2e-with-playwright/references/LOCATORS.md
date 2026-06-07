# ロケーター戦略ガイド

Playwrightのロケーター選択はテストの保守性と信頼性に直結します。このドキュメントでは優先順位・アンチパターン・実践パターンを解説します。

---

## ロケーター優先順位（セマンティックファースト）

### 1位: `getByRole()`

**最優先**。WAI-ARIAロールとアクセシブル名で要素を特定します。

```typescript
// ボタン
page.getByRole("button", { name: "ログイン" })
page.getByRole("button", { name: /送信|確認/ })  // 正規表現

// タブ
page.getByRole("tab", { name: "未発送" })

// テキストボックス
page.getByRole("textbox", { name: "メールアドレス" })

// combobox（select要素）
page.getByRole("combobox", { name: "都道府県" })

// リンク
page.getByRole("link", { name: "詳細を見る" })
```

**メリット**:
- アクセシビリティ準拠が保証される
- UI変更に強い（テキストが変わらない限り動作する）

---

### 2位: `getByLabel()`

フォーム要素で**label要素のテキスト**から特定します。

```typescript
page.getByLabel("メールアドレス")
page.getByLabel("パスワード")
page.getByLabel("配送日時")

// チェックボックス・ラジオボタンにも使用可能
page.getByLabel("利用規約に同意する")
```

**メリット**:
- フォームのアクセシビリティが保証される
- ラベルとinputの関連が明示的

---

### 3位: `getByText()`

**表示テキスト**で要素を特定します。ボタン以外の要素（見出し・段落等）に有効。

```typescript
page.getByText("送り状の情報")
page.getByText(/エラー|失敗/)  // 正規表現

// 部分一致（contains）
page.getByText("配送", { exact: false })

// 完全一致（exact）
page.getByText("送信", { exact: true })
```

**注意**:
- `page.locator("text=XXX")` は旧構文。`getByText()` を使用すること
- テキストが動的に変化する場合は不安定

---

### 4位: `getByAltText()`

**画像のalt属性**から特定します。アイコンボタンやロゴに有効。

```typescript
page.getByAltText("ゆうパック", { exact: true })
page.getByAltText("クロネコヤマト")

// 画像をクリック
await page.getByAltText("ヤマト運輸", { exact: true }).click();
```

**ユースケース**:
- 配送サービス選択（画像ラジオボタン）
- アイコンボタン
- ロゴクリック

**注意**:
- alt属性が正しく設定されていることが前提
- `exact: true` で完全一致推奨（部分一致だと意図しない要素を取得）

---

### 5位: `getByTestId()`

**data-testid属性**で特定します。UI変更に最も強い。

```typescript
page.getByTestId("submit-button")
page.getByTestId("order-table")
page.getByTestId("tracking-number")
```

**メリット**:
- UI表示が変わっても動作する
- セマンティックロケーターが使えない場合の代替策

**デメリット**:
- 実装コードに `data-testid` 属性を追加する必要がある

---

### 6位: CSSセレクタ（最終手段）

他に方法がない場合のみ使用。

```typescript
page.locator("#email")
page.locator('[role="progressbar"]')
page.locator("table tbody tr")
```

**使用を検討すべき場面**:
- 動的要素（ローディングスピナー、トースト通知）
- 特定のDOM構造を検証する必要がある場合

**デメリット**:
- 実装依存度が高い
- UI変更で壊れやすい

---

## アンチパターン集

### ❌ 旧構文の使用

```typescript
// ❌ 旧構文
page.locator("text=ログイン")
page.locator("button:has-text('送信')")

// ✅ 新構文
page.getByText("ログイン")
page.getByRole("button", { name: "送信" })
```

---

### ❌ CSSクラス・IDに依存

```typescript
// ❌ 実装依存
page.locator(".btn-primary")
page.locator("#submit-button")

// ✅ セマンティックロケーター
page.getByRole("button", { name: "送信" })
```

---

### ❌ 複雑なCSSセレクタ

```typescript
// ❌ 保守性が低い
page.locator("div.container > ul.list > li:nth-child(2) > a")

// ✅ テキストまたはロールで特定
page.getByRole("link", { name: "詳細を見る" })
```

---

### ❌ `nth-child()` への依存

```typescript
// ❌ 順序変更で壊れる
page.locator("table tbody tr:nth-child(3)")

// ✅ データ内容で特定
page.locator("table tbody tr").filter({ hasText: "#1001" })
```

---

## 実践パターン

### パターン1: フィルタ連鎖

複数条件で要素を絞り込む。

```typescript
// テーブル行のうち「#1001」を含む行をクリック
await page.locator("table tbody tr")
  .filter({ hasText: "#1001" })
  .first()
  .click();

// ボタンのうち「削除」を含むものを選択
await page.getByRole("button")
  .filter({ hasText: "削除" })
  .click();
```

---

### パターン2: 親要素からのスコープ

特定のセクション内で要素を探す。

```typescript
const dialog = page.locator('[role="dialog"]');
await dialog.getByRole("button", { name: "確認" }).click();

const sidebar = page.locator('aside[aria-label="サイドバー"]');
await sidebar.getByRole("link", { name: "設定" }).click();
```

---

### パターン3: `or()` で複数候補

```typescript
// 「送信」または「確認」ボタンを探す
const submitBtn = page.getByRole("button", { name: "送信" })
  .or(page.getByRole("button", { name: "確認" }));
await submitBtn.click();
```

---

### パターン4: 動的コンテンツの待機

```typescript
// テーブルのデータ行が表示されるまで待機
await page.locator("table tbody tr")
  .first()
  .waitFor({ state: "visible", timeout: 10_000 });

// その後カウント取得
const count = await page.locator("table tbody tr").count();
```

---

## よくある罠

### 罠1: `domcontentloaded` だけでは不十分

SSRでDOM構造は即表示されるが、クライアントサイドfetchのデータ行やReact hydrationのフォーム要素はまだない。

```typescript
// ❌ 不十分
await page.waitForLoadState("domcontentloaded");
const count = await page.locator("table tbody tr").count();  // 0になる可能性

// ✅ 対象要素の出現を待機
await page.waitForLoadState("domcontentloaded");
await page.locator("table tbody tr").first().waitFor({ state: "visible" });
const count = await page.locator("table tbody tr").count();
```

---

### 罠2: `getByText()` が画像のalt属性にマッチしない

```typescript
// ❌ 見つからない（画像のalt属性には getByText() は使えない）
page.getByText("ゆうパック")

// ✅ getByAltText() を使用
page.getByAltText("ゆうパック", { exact: true })
```

**前提条件の確認**:
```typescript
// キャリア名が表示されているか確認してから画像クリック
await expect(page.getByText("日本郵便")).toBeVisible();
await page.getByAltText("ゆうパック", { exact: true }).click();
```

---

### 罠3: `tbody` が visible でも行数が0

```typescript
// ❌ テーブル構造は即レンダリングされるが、データ行は後から来る
await page.locator("table tbody").waitFor({ state: "visible" });
const count = await page.locator("table tbody tr").count();  // 0の可能性

// ✅ データ行の出現を待つ
await page.locator("table tbody tr").first().waitFor({ state: "visible" });
const count = await page.locator("table tbody tr").count();
```

---

## ベストプラクティス

### 1. セマンティック > 実装

```typescript
// ✅ Good: セマンティック
page.getByRole("button", { name: "ログイン" })

// ❌ Bad: 実装依存
page.locator(".login-btn")
```

---

### 2. テキスト > セレクタ

```typescript
// ✅ Good: テキストで特定
page.getByText("送り状の情報")

// ❌ Bad: クラス名で特定
page.locator(".slip-info-header")
```

---

### 3. フィルタで絞り込む

```typescript
// ✅ Good: フィルタ
page.locator("table tbody tr").filter({ hasText: "#1001" })

// ❌ Bad: nth-child
page.locator("table tbody tr:nth-child(5)")
```

---

### 4. スコープを限定

```typescript
// ✅ Good: ダイアログ内のボタンに限定
const dialog = page.locator('[role="dialog"]');
await dialog.getByRole("button", { name: "確認" }).click();

// ❌ Bad: ページ全体から検索（意図しないボタンを取得する可能性）
await page.getByRole("button", { name: "確認" }).click();
```

---

## まとめ

- **優先順位**: `getByRole()` > `getByLabel()` > `getByText()` > `getByAltText()` > `getByTestId()` > CSSセレクタ
- **セマンティックファースト**: アクセシビリティと保守性を両立
- **待機は必須**: データ行・フォーム要素の出現を待つ
- **フィルタ活用**: 複数条件で絞り込む
