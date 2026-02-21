# React Testing Library クエリリファレンス

RTL のクエリメソッドとクエリタイプの包括的リファレンス。要素の検索方法を選択する際に参照する。

> **関連ファイル:** ユーザーインタラクション（click/type/hover/blur/waitFor）は [RTL-INTERACTIONS.md](./RTL-INTERACTIONS.md)、高度テスト（within/props/rerender/snapshot/renderHook）は [RTL-ADVANCED.md](./RTL-ADVANCED.md) を参照。コード規約は [VITEST-RTL-GUIDELINES.md](./VITEST-RTL-GUIDELINES.md) を参照。

---

## クエリメソッド決定ガイド

RTL は 3 つのクエリメソッドを提供する。要素の状態に応じて使い分ける:

| メソッド | 要素がない場合 | 用途 | async |
|---------|--------------|------|-------|
| **getBy** | エラーをスロー | 即座に存在すべき要素 | No |
| **queryBy** | `null` を返す | 要素の**不在**を検証 | No |
| **findBy** | タイムアウトまで待機 | 非同期で出現する要素 | Yes |

### 使い分けフローチャート

```
要素は即座にDOMに存在する？
├─ Yes → getBy を使用
│         要素が存在しない場合はテスト失敗（意図通り）
│
└─ No → 要素は後から出現する？
         ├─ Yes → findBy を使用（Promise を返す、await 必須）
         └─ No → queryBy を使用（不在の検証に最適）
```

### 典型パターン

```tsx
// 即座に存在する要素の検証
expect(screen.getByText('送信')).toBeInTheDocument()

// 非同期で出現する要素の検証
expect(await screen.findByText('ようこそ！')).toBeInTheDocument()

// 要素の不在を検証（queryBy + not）
expect(screen.queryByText('読み込み中...')).not.toBeInTheDocument()
```

### 非同期テストの組み合わせパターン

初期状態と非同期状態の両方をテストする例:

```tsx
it('読み込み完了後、ウェルカムメッセージを表示すべき', async () => {
  render(<App />)

  // 初期状態: ローディング表示
  expect(screen.getByText('loading...')).toBeInTheDocument()

  // 非同期: メッセージ出現を待機
  expect(await screen.findByText('Welcome!')).toBeInTheDocument()

  // 非同期完了後: ローディング非表示
  expect(screen.queryByText('loading...')).not.toBeInTheDocument()
})
```

---

## クエリタイプ（検索基準）

クエリタイプは要素を**どの属性で検索するか**を決める。ユーザー視点に近いものを優先する。

### 選択優先度

| 優先度 | クエリタイプ | 理由 |
|--------|------------|------|
| 1 | **ByRole** | ユーザーが認識する役割。アクセシビリティ最優先 |
| 2 | **ByLabelText** | フォーム要素のラベル。ユーザーが見る情報 |
| 3 | **ByPlaceholderText** | プレースホルダー。ラベルがない場合の代替 |
| 4 | **ByText** | テキストコンテンツ。汎用的だが特定性が低い |
| 5 | **ByDisplayValue** | フォーム要素の現在値 |
| 6 | **ByAltText** | 画像の alt 属性 |
| 7 | **ByTitle** | title 属性。ツールチップ等 |
| 8 | **ByTestId** | `data-testid`。**最終手段** |

---

### ByRole

ユーザーが認識する要素の**役割**で検索。アクセシビリティベストプラクティスに直結する。

**HTML要素とデフォルトロールの対応:**

| HTML要素 | ロール | name の参照先 |
|----------|--------|-------------|
| `<button>` | `button` | テキストコンテンツ |
| `<a href>` | `link` | テキストコンテンツ |
| `<input>` | `textbox` | `<label>` のテキスト |
| `<select>` | `combobox` | `<label>` のテキスト |
| `<h1>`~`<h6>` | `heading` | テキストコンテンツ |
| `<table>` | `table` | - |
| `<tr>` | `row` | - |
| `<td>` | `cell` | - |
| `<div role="alert">` | `alert` | テキストコンテンツ |

```tsx
// ボタンをテキストで特定
screen.getByRole('button', { name: 'count is 0' })

// 正規表現で部分一致（大文字小文字無視）
screen.getByRole('button', { name: /count/i })

// 見出しレベルを指定
screen.getByRole('heading', { level: 3, name: 'Dashboard' })

// リンクの検索
screen.getByRole('link', { name: 'Sign up' })

// alert ロールで検索
screen.getByRole('alert', { name: 'Something went wrong' })
```

**重要**: `name` オプションはHTML `name` 属性ではなく、**アクセシブルネーム**（ラベル、テキストコンテンツ等）を参照する。`<input name="username">` は `name: 'username'` では見つからない。ラッピング `<label>` のテキストを使う。

---

### ByLabelText

フォーム要素を `<label>` テキストで検索。入力フィールドの特定に最適。

```tsx
// 基本的な使い方
screen.getByLabelText('Username')

// userEvent との組み合わせ（よく使うパターン）
await userEvent.type(screen.getByLabelText('Username'), 'joel')
```

---

### ByText

テキストコンテンツで要素を検索。最も直感的だが特定性は低い。

```tsx
// 完全一致
screen.getByText('Something went wrong')

// 正規表現で部分一致
screen.getByText(/Upcoming date/)

// selector オプションで絞り込み（最終手段）
screen.getByText('Something went wrong', { selector: '.alert.alert-error' })
```

**注意**: `selector` はユーザーに見えない実装詳細であるため、変更に弱い。可能な限り ByRole を優先する。

---

### ByAltText

画像の `alt` 属性で検索。`<img>` タグのテストに使用する。

```tsx
screen.getByAltText('Profile picture')

// 正規表現で部分一致
screen.getByAltText(/profile/i)
```

---

### ByDisplayValue

フォーム要素（`<input>`, `<select>`, `<textarea>`）の**現在の表示値**で検索。

```tsx
// 初期値やユーザー入力後の値を検証
screen.getByDisplayValue('joel')
```

`<input type="checkbox">` や `<input type="radio">` には使えない。それらには `toBeChecked()` や `toHaveFormValues()` を使用する。

---

### ByPlaceholderText

`placeholder` 属性で検索。ラベルの補助情報として使われる。

```tsx
screen.getByPlaceholderText('Enter username')
```

---

### ByTitle

`title` 属性で検索。ツールチップ等の追加情報に使用される。

```tsx
screen.getByTitle('More information')
```

---

### ByTestId

`data-testid` 属性で検索。**最終手段**として使用する。

```tsx
screen.getByTestId('user-profile')
```

**注意**: `data-testid` はエンドユーザーに不可視であり、セマンティックセレクタ（ロール・ラベル）が使えない場合のみ使用する。

---

## クエリバリアント完全マトリクス

各クエリタイプは `getBy` / `queryBy` / `findBy` の3メソッドと、それぞれの `All` バリアントを持つ。合計 **48 クエリ**（8タイプ × 3メソッド × 単数/複数）。

### メソッド × 単数/複数

| メソッド | 単数（0-1件） | 複数（0-N件） |
|---------|-------------|-------------|
| **get** | `getByRole` | `getAllByRole` |
| **query** | `queryByRole` | `queryAllByRole` |
| **find** | `findByRole` | `findAllByRole` |

- `get`: 0件でエラー、2件以上でもエラー（`getAll` は2件以上OK）
- `query`: 0件で `null`（`queryAll` は空配列）。**不在検証**専用
- `find`: Promise を返す。0件ならタイムアウトまでリトライ。**非同期テスト**専用

### 全クエリタイプの get / query / find 対応表

| クエリタイプ | get (単/複) | query (単/複) | find (単/複) |
|------------|-----------|-------------|-----------|
| **ByRole** | `getByRole` / `getAllByRole` | `queryByRole` / `queryAllByRole` | `findByRole` / `findAllByRole` |
| **ByLabelText** | `getByLabelText` / `getAllByLabelText` | `queryByLabelText` / `queryAllByLabelText` | `findByLabelText` / `findAllByLabelText` |
| **ByText** | `getByText` / `getAllByText` | `queryByText` / `queryAllByText` | `findByText` / `findAllByText` |
| **ByPlaceholderText** | `getByPlaceholderText` / `getAllByPlaceholderText` | `queryByPlaceholderText` / `queryAllByPlaceholderText` | `findByPlaceholderText` / `findAllByPlaceholderText` |
| **ByAltText** | `getByAltText` / `getAllByAltText` | `queryByAltText` / `queryAllByAltText` | `findByAltText` / `findAllByAltText` |
| **ByDisplayValue** | `getByDisplayValue` / `getAllByDisplayValue` | `queryByDisplayValue` / `queryAllByDisplayValue` | `findByDisplayValue` / `findAllByDisplayValue` |
| **ByTitle** | `getByTitle` / `getAllByTitle` | `queryByTitle` / `queryAllByTitle` | `findByTitle` / `findAllByTitle` |
| **ByTestId** | `getByTestId` / `getAllByTestId` | `queryByTestId` / `queryAllByTestId` | `findByTestId` / `findAllByTestId` |

### 使用例

```tsx
// getAllBy: 複数リンクの個数を検証
expect(screen.getAllByRole('link')).toHaveLength(2)

// queryAllBy: 不在時は空配列（エラーにならない）
expect(screen.queryAllByText('item')).toHaveLength(0)

// findAllBy: 非同期で複数要素の出現を待機
const items = await screen.findAllByRole('listitem')
expect(items).toHaveLength(3)
```

---

## クラス名テスト戦略

要素のクラス名を検証する必要がある場合の優先度:

| 優先度 | 手法 | 例 | 推奨度 |
|--------|------|-----|--------|
| 1 | **ByRole + toHaveClass** | `expect(screen.getByRole('alert', { name: 'Error' })).toHaveClass('alert', 'alert-error')` | ✅ 最推奨 |
| 2 | **ByText + selector** | `screen.getByText('Error', { selector: '.alert.alert-error' })` | ⚠️ 実装詳細依存 |
| 3 | **container.querySelector** | `container.querySelector('.alert.alert-error')` | ❌ 最終手段 |

```tsx
// ✅ 推奨: role でアクセシブルに検索し、クラスを検証
render(<Alert type="error" message="Something went wrong" />)
expect(
  screen.getByRole('alert', { name: 'Something went wrong' })
).toHaveClass('alert', 'alert-error')

// ❌ 最終手段: container の DOM API を直接使用
const { container } = render(<Alert type="error" message="Something went wrong" />)
expect(
  container.querySelector('.alert.alert-error')
).toHaveTextContent('Something went wrong')
```
