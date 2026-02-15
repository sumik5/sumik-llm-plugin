# E2E-ACCESSIBILITY.md

PlaywrightとAxe-coreを統合したアクセシビリティテストの自動化ガイド。WCAG準拠を確認し、早期に問題を発見する方法を解説します。

---

## アクセシビリティテストの重要性

### なぜ自動化が必要か

手動でのアクセシビリティ確認は遅く、エラーが発生しやすいプロセスです。自動テストを追加することで:

- **早期発見**: コミットごとに問題を検出
- **時間・コスト削減**: 本番環境前に修正
- **50%以上のWCAG問題を検出**: axe-coreは偽陽性なしで多くの問題を発見

**a11y** (アクセシビリティの略称):
- "a"と"y"の間に11文字 → a11y

---

## axe-core と Playwright の統合

### 必要なツール

- **`axe-core`**: WCAGルールに基づいてページを分析するJavaScriptライブラリ
- **`@axe-core/playwright`**: PlaywrightとAxe-coreを接続する公式コミュニティパッケージ

### インストール

```bash
npm install @axe-core/playwright --save-dev
```

### ページ全体のスキャン

```typescript
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test.describe('Accessibility Tests', () => {
  test('should pass accessibility scan', async ({ page }) => {
    // ページに移動
    await page.goto('https://www.wikipedia.org/');

    // Axe-coreスキャン実行
    const results = await new AxeBuilder({ page })
      .withTags(['wcag2aa', 'section508'])
      .analyze();

    // 違反をログ出力（デバッグ用）
    if (results.violations.length > 0) {
      console.log('Accessibility violations:', results.violations);
    }

    // 違反がないことをアサート
    expect(results.violations).toEqual([]);
  });
});
```

**違反が見つかった場合の出力例**:

```typescript
Accessibility violations: [
  {
    id: 'color-contrast',
    impact: 'serious',
    tags: ['cat.color', 'wcag2aa', 'wcag143', ...],
    description: 'Ensure the contrast between foreground and background colors meets WCAG 2 AA minimum contrast ratio thresholds',
    help: 'Elements must meet minimum color contrast ratio thresholds',
    ...
  }
]
```

### 主要メソッド

- **`AxeBuilder({ page })`**: スキャンのセットアップ
- **`withTags()`**: 特定のWCAG基準でフィルタリング
- **`analyze()`**: スキャン実行してresultsオブジェクトを返す
- **`results.violations`**: 検出されたアクセシビリティ問題の配列

---

## WCAG準拠の理解

### WCAGとは

**Web Content Accessibility Guidelines (WCAG)** は、W3C (World Wide Web Consortium) が策定したWebアクセシビリティの国際標準です。

### POUR原則

WCAGは4つの基本原則で構成されています:

1. **Perceivable (知覚可能)**
   - 情報をユーザーが認識できる形式で提示
   - 例: 画像のalt text、動画の字幕

2. **Operable (操作可能)**
   - UIコンポーネントが操作できること
   - 例: キーボードナビゲーション、音声コマンド

3. **Understandable (理解可能)**
   - 情報と操作方法が理解しやすいこと
   - 例: 明確な言語、予測可能な機能、一貫したナビゲーション

4. **Robust (堅牢)**
   - 支援技術を含む多様なユーザーエージェントで動作すること
   - 例: 標準に準拠したHTML、支援技術との互換性

### 適合レベル

WCAGには3つの適合レベルがあり、累積的な構造になっています（Level AAはLevel Aを含み、Level AAAはLevel A+AAを含む）:

#### Level A (最低限)

- **対象**: 基本的なアクセシビリティ
- **カバー範囲**: 主要な障壁を除去するが、すべての障壁は除去しない
- **実装の難易度**: Webサイトがアクセス可能と見なされる最低限のレベル
- **例**:
  - 画像のalt text (Success Criterion 1.1.1: Non-text Content)
  - キーボードアクセス (SC 2.1.1: Keyboard)

#### Level AA (推奨)

- **対象**: 最も一般的な目標レベル
- **法的要件**: 多くの国の法令で要求される（米国 Section 508、欧州 EN 301 549）
- **カバー範囲**: Level A + より広範なユーザーをサポートする追加基準
- **例**:
  - 色コントラスト比4.5:1以上 (SC 1.4.3: Contrast Minimum)
  - 2次元スクロール不要 (SC 1.4.10: Reflow)
  - ページタイトルの提供 (SC 2.4.2: Page Titled)

#### Level AAA (最高)

- **対象**: 最も包括的なアクセシビリティレベル
- **適用範囲**: すべてのコンテンツに適用するのは実用的でない場合が多い
- **推奨事項**: WCAG自体もすべてのコンテンツでLevel AAAを推奨していない
- **カバー範囲**: Level A + AA + 最高水準の追加基準
- **例**:
  - 音声コンテンツへの手話通訳 (SC 1.2.6: Sign Language Prerecorded)
  - 色コントラスト比7:1以上 (SC 1.4.6: Contrast Enhanced)
  - 文脈に応じたヘルプの提供 (SC 3.3.5: Help)

### WCAGバージョン

- **WCAG 2.0, 2.1, 2.2**: すべて現行標準
- 新しいバージョンは追加基準を含む（モバイル、認知障害等）
- **WCAG 2.2** が最新版（2024年時点）

---

## Axe-coreルールのカスタマイズ

### 標準プロファイル

| プロファイル | タグ | 使用場面 |
|------------|-----|---------|
| **Standard baseline** | `['wcag21aa']` | デフォルト。WCAG 2.1 AA準拠（法的要件） |
| **Enhanced quality** | `['wcag21aa', 'best-practice']` | 推奨。法的基準 + 業界ベストプラクティス |
| **Future-proof** | `['wcag22aa']` | WCAG 2.2 AA準拠。将来の規制に備える |

### 推奨プロファイル

実際のプロジェクトでは以下のプロファイルを使用することが推奨されます:

| プロファイル | タグ | 使用場面 |
|------------|-----|---------|
| **Standard baseline** | `['wcag21aa']` | デフォルト。WCAG 2.1 AA準拠（法的要件）|
| **Enhanced quality** | `['wcag21aa', 'best-practice']` | 推奨。法的基準 + 業界ベストプラクティス |
| **Future-proof** | `['wcag22aa']` | WCAG 2.2 AA準拠。将来の規制に備える |

### タグの説明

- **`wcag2a`**: WCAG 2.0/2.1 Level A
- **`wcag2aa`**: WCAG 2.0/2.1 Level AA (Level Aを含む)
- **`wcag21a`**: WCAG 2.1 Level A（モバイル、視覚障害、認知障害対応）
- **`wcag21aa`**: WCAG 2.1 Level AA
- **`wcag22aa`**: WCAG 2.2 Level AA (axe-core 4.5+)
- **`best-practice`**: WCAGに明記されていない業界ベストプラクティス（例: すべてのページに`<h1>`、厳密な見出し階層）

**重要**: WCAGレベルは累積的です。Level AAを指定すれば、Level Aも自動的に含まれます。

---

## WCAG準拠テストの作成

### WCAG 2.1 AA準拠スキャン

```typescript
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test('should comply with WCAG 2.1 AA', async ({ page }) => {
  await page.goto('https://example.com');

  const results = await new AxeBuilder({ page })
    .withTags(['wcag21aa'])
    .analyze();

  expect(results.violations).toEqual([]);
});
```

### コンポーネント単位のスキャン

```typescript
test('Login form should be accessible', async ({ page }) => {
  await page.goto('https://example.com/login');

  const results = await new AxeBuilder({ page })
    .include('#login-form') // 特定の要素のみスキャン
    .withTags(['wcag21aa'])
    .analyze();

  expect(results.violations).toEqual([]);
});
```

### 特定のルールを除外

開発途中で特定ルールを一時的に除外したい場合:

```typescript
const results = await new AxeBuilder({ page })
  .withTags(['wcag21aa'])
  .disableRules(['color-contrast']) // 色コントラストルールを除外
  .analyze();
```

**注意**: 本番環境ではすべてのルールを有効化してください。`disableRules()` は開発中の一時的な回避策としてのみ使用し、Issue trackingで管理すること。

### CI/CDへの統合

```typescript
// playwright.config.ts
export default defineConfig({
  projects: [
    {
      name: 'accessibility',
      testMatch: '**/accessibility.spec.ts',
      use: {
        // アクセシビリティテスト専用の設定
      },
    },
  ],
});
```

---

## よくあるアクセシビリティ問題と修正

### 1. 色コントラスト不足

**問題**: テキストと背景の色コントラスト比がWCAG基準を満たさない

**修正**:
```css
/* ❌ 悪い例: コントラスト比 2.5:1 */
color: #777;
background-color: #fff;

/* ✅ 良い例: コントラスト比 4.5:1 以上 */
color: #595959;
background-color: #fff;
```

### 2. 画像のalt属性が欠落

**問題**: `<img>` タグに `alt` 属性がない

**修正**:
```html
<!-- ❌ 悪い例 -->
<img src="logo.png">

<!-- ✅ 良い例 -->
<img src="logo.png" alt="Company Logo">

<!-- ✅ 装飾画像の場合 -->
<img src="decoration.png" alt="">
```

### 3. フォームラベルが欠落

**問題**: 入力フィールドに関連付けられた `<label>` がない

**修正**:
```html
<!-- ❌ 悪い例 -->
<input type="text" placeholder="Enter name">

<!-- ✅ 良い例 -->
<label for="name">Name:</label>
<input type="text" id="name">
```

### 4. 不適切なARIAロール

**問題**: 間違ったARIAロールや不要なARIA属性

**修正**:
```html
<!-- ❌ 悪い例 -->
<div role="button" onclick="submit()">Submit</div>

<!-- ✅ 良い例 -->
<button type="submit">Submit</button>
```

### 5. 見出し階層の欠落

**問題**: `<h1>` → `<h3>` のようにレベルを飛ばす

**修正**:
```html
<!-- ❌ 悪い例 -->
<h1>Title</h1>
<h3>Subtitle</h3>

<!-- ✅ 良い例 -->
<h1>Title</h1>
<h2>Subtitle</h2>
```

---

## 自動テストと手動テストの補完

### 自動テストで検出できるもの

- 色コントラスト
- 欠落したalt属性
- 不適切なARIA
- フォームラベルの欠落
- 見出し階層のエラー

### 手動テストが必要なもの

axe-coreは50%以上のWCAG問題を検出できますが、以下は手動テストが必要です:

- **キーボードナビゲーション**: Tabキーで全インタラクティブ要素に到達できるか
- **スクリーンリーダー体験**: 読み上げ順序が論理的か、情報の欠落がないか
- **フォーカス表示**: フォーカスが視覚的に明確で、フォーカス順序が論理的か
- **コンテキストの適切性**: alt textが画像の目的と文脈に合っているか
- **ARIAロール/属性の正確性**: ARIA属性が正しく動作しているか
- **動的コンテンツ**: 動的に追加されるコンテンツがスクリーンリーダーに通知されるか

### 手動テストのアプローチ

**キーボードナビゲーションテスト**:
1. マウスを使わずにTabキーで全要素を巡回
2. Enterキーでリンク・ボタンが動作するか確認
3. フォーカスがトラップされていないか確認

**スクリーンリーダーテスト**:
```typescript
// Playwrightでスクリーンリーダー互換性を確認
test('screen reader accessible navigation', async ({ page }) => {
  await page.goto('https://example.com');

  // ARIA属性の検証
  const nav = page.locator('nav');
  await expect(nav).toHaveAttribute('role', 'navigation');
  await expect(nav).toHaveAttribute('aria-label');
});
```

**ベストプラクティス**:
1. 自動テストをCI/CDに組み込む（継続的チェック）
2. 手動テストを定期的に実施（ユーザー体験の検証）
3. 実際の支援技術（スクリーンリーダー等）でテスト
4. 自動テスト→手動テストの順で実行（効率化）

### 手動テストツール

- **NVDA** (Windows): 無料のスクリーンリーダー
- **JAWS** (Windows): 商用スクリーンリーダー（業界標準）
- **VoiceOver** (macOS/iOS): OS標準のスクリーンリーダー
- **axe DevTools** (ブラウザ拡張): 手動でのAxe-core実行、要素の検査

---

## アクセシビリティテストのチェックリスト

### 実装時

- [ ] すべての画像に適切な `alt` 属性
- [ ] フォーム入力に `<label>` を関連付け
- [ ] キーボードで全インタラクティブ要素に到達可能
- [ ] 色コントラスト比が WCAG 2.1 AA 基準を満たす
- [ ] 見出し階層が論理的 (`<h1>` → `<h2>` → `<h3>`)
- [ ] ARIAロールが適切に使用されている

### テスト時

- [ ] Axe-coreでページ全体をスキャン
- [ ] 主要なコンポーネントを個別にスキャン
- [ ] キーボードナビゲーションを手動確認
- [ ] スクリーンリーダーで読み上げ順序を確認
- [ ] CI/CDでアクセシビリティテストを自動実行

---

## まとめ

PlaywrightとAxe-coreを統合することで:

- **早期発見**: 開発段階でWCAG違反を検出
- **自動化**: CI/CDで継続的にスキャン
- **50%以上の問題を検出**: 偽陽性なしで効率的
- **法的準拠**: Section 508、EN 301 549等の要件を満たす

**重要な原則**:
- 自動テストは基盤。手動テストで補完する
- Level AAが最も一般的な目標
- アクセシビリティは「後付け」ではなく「最初から」組み込む

**次のステップ**:
1. プロジェクトにaxe-core/playwrightを導入
2. 主要ページでテスト作成
3. CI/CDに統合
4. 定期的な手動テストの実施
