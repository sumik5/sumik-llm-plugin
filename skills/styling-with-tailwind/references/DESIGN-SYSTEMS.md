# デザインシステムと Tailwind CSS

Tailwind CSS をデザインシステムの基盤として活用するための設計原則と実践ガイド。
デザイントークン設計、チーム運用、Tailwind では担保できない領域を網羅する。

---

## デザインシステムの定義

### Tailwind CSS との適合

「デザインシステム」＝**デザイナーと開発者がスタイリングにおいて同じ用語を用いること、およびその状態を達成するための一連のしくみ**。

Tailwind CSS はこの意味でのデザインシステムに適合する：

- `tailwind.config.js`（v3）/ CSS `@theme`（v4）が **single source of truth** になる
- テーマからユーティリティが生成されるため、デザイナーと開発者が同じトークン名を使える
- 例外的なスタイルは **Arbitrary Values**（`py-[5px]` など）として可視化される

```html
<!-- デザインシステムに沿っている箇所 -->
<div class="leading-none text-12 py-4">...</div>

<!-- ガイドライン外であることが一目でわかる（コメント推奨） -->
<!-- NOTICE: 高さの合計を4の倍数にしたいので、タブレット以上では例外的に5pxのpaddingを使う -->
<div class="leading-none text-12 py-4 tablet:text-14 tablet:py-[5px]">...</div>
```

Arbitrary Values を使うぐらいなら生の `.css` で書いたほうがよいという意見もある。しかしすべてのスタイルがユーティリティで表現される前提のもと、デザインシステムに沿っている箇所と沿っていない箇所を可視化することには価値がある。

### ピクセルパーフェクトは目的ではなく結果

「ピクセルパーフェクト」を規範的に用いることには問題がある：

- マルチデバイス環境でどの画面・解像度を基準にするか明確にできない
- 選択肢が無限（任意の `padding: 5px`）だと「正しい」と「誤り」を区別できない
- **契約（デザインシステム）を守ることによって、ピクセルパーフェクトは結果としてついてくる**

> 無造作に書かれた `padding: 5px` が本来 4px であるべきか意図的な 5px かは、ルールがなければ区別できない。

### ボトムアップ戦略（コンポーネント集から始めない）

デザインシステムをコンポーネント集として始めると：

- コンポーネントが出そろうまでリリースできない
- コンポーネントが提供されない領域ではデザインシステムが無視される

**ボトムアップ戦略の目指す状態**：「`<Modal>` コンポーネントはまだないが、そのページで必要な Modal を作るためのツールはすべてそろっている」

Tailwind CSS のユーティリティファーストの思想はこのボトムアップアプローチに適合する。

---

## デザイントークン設計

### 3層構造

```
┌─────────────────────────────────┐
│  コンポーネント（挙動 + スタイル）  │  ← Tailwind の範囲外
├─────────────────────────────────┤
│     ユーティリティ（CSS クラス）     │  ← Tailwind が担当
├─────────────────────────────────┤
│  デザイントークン（プラットフォーム独立の値）│  ← デザイナーが定義
└─────────────────────────────────┘
```

- **デザイントークン**：プラットフォームから独立した値の定義（JSON/YAML で書けるほど静的）
- **ユーティリティ**：トークンを CSS クラスとして表現（Web 固有）
- **コンポーネント**：ユーティリティで構築した再利用可能 UI + 挙動

最初のマイルストーン：ページ内のすべての要素が共通コンポーネントでなくても、**すべての要素をトークン由来のユーティリティで表現できる状態**。

### 命名方針：リテラル vs セマンティック

| 方針 | 例 | 特徴 |
|------|-----|------|
| リテラル | `8`、`blue-400` | 値そのまま。わかりやすいが用途が不明 |
| セマンティック | `small`、`primary` | 意図が伝わる。ダークモード対応が容易 |

- Tailwind CSS のデフォルトスペーシング（`p-4` = 16px）はやや**セマンティック寄り**
- どちらに寄せるかはチームが判断する（調整が必要）

### カラーパレット：1 階層 vs 2 階層

**1 階層（リテラルのみ）** ─ Tailwind CSS のデフォルト：

```html
<!-- ダークモードはマークアップ上の分岐 -->
<div class="bg-blue-400 dark:bg-blue-500">...</div>
```

**2 階層（リテラル + セマンティック）**：

```css
/* v4: CSS 変数ベースで表現 */
@theme {
  --color-primary: var(--semantic-color-primary);
}

:root {
  --literal-color-blue-400: #60a5fa;
  --semantic-color-primary: var(--literal-color-blue-400);
}

@media (prefers-color-scheme: dark) {
  :root {
    --semantic-color-primary: var(--literal-color-blue-500);
  }
}
```

```js
// v3: tailwind.config.js
module.exports = {
  theme: {
    colors: {
      primary: 'var(--semantic-color-primary)',
    },
  },
};
```

| 方式 | メリット | デメリット |
|------|----------|------------|
| 1 階層 | シンプル、Tailwind のデフォルトと相性◎ | ダークモード分岐がマークアップに散在 |
| 2 階層 | ダークモード管理が CSS 変数に集中 | セマンティック名が増えすぎるリスク |

**2 階層を採用する場合の注意**：
- セマンティックな色名に用途を含めない（`modal-background-color` → `background1`）
- 用途を含める命名は際限なく増えていく（GitHub の CSS Variables 参照）
- 例外的な色（セマンティック外の直接指定）は `dark:` モディファイアに頼るしかなくなる

どちらの方式をとるかは**最初の段階で決める**。

### スペーシング：判断負荷を減らす

「4の倍数」ルールだけでは不十分。128px と 132px のどちらが適切か、4の倍数ルールでは答えられない。

**原則：より大きい値ほど、より大きいステップで増加する**

実践例（一般化フィボナッチ数列）：

```
4, 8, 16, 24, 40, 64, 104, ...
```

（24 = 16 + 8、64 = 24 + 40）

- この範囲外の値は Arbitrary Values（例外的な扱い）
- 「40px と 44px のどちらが適切か」という議論を原則的に不要にする
- Tailwind CSS のデフォルトには 40px と 44px の両方が存在 → チームの方針で削ることも可

### タイポグラフィ：大きさと行送りを一体化

#### フォントサイズと行送りは一体化させる

あるユーティリティを使ったときの**バウンディングボックスが予測可能**になるため、大きさのルールには行送りも含めるのが原則。

Tailwind CSS のデフォルトは `text-sm`、`text-md` などで**行送りも一緒に設定**する設計。行送りだけを独立に変更するクラスも別途提供。

```html
<!-- text-sm はフォントサイズ + 行送りを一緒に設定 -->
<p class="text-sm">通常のテキスト</p>

<!-- 行送りだけ変更したい場合 -->
<p class="text-sm leading-tight">コンパクトなテキスト</p>
```

見出し用に「ウェイト + 大きさ」を一体化したユーティリティを作りたくなることもある。しかし見出しと見なすのかはコンポーネント設計に任せるべきで、ユーティリティファーストの考えに反する。**大きさのバリエーション（フォントサイズ + 行送り）のみにとどめる**のが柔軟。

#### フォントサイズと 4 の倍数グリッド

14px など 4 の倍数でないサイズを使うと、コンポーネント高さの 4 の倍数ルールと競合する場合がある。

**解決策：行送りで調整**

```
12px + 行送り 8px → バウンディングボックス 20px（4の倍数）
14px + 行送り 6px → バウンディングボックス 20px（4の倍数）
16px + 行送り 8px → バウンディングボックス 24px（4の倍数）
```

この問題を根本から防ぐかどうかは**事前に方針を決める**。

#### half leading の扱い

`font-size: 16px; line-height: 24px` のとき、行の上下に各 4px の half leading が発生。

```html
<!-- p 要素間のマージン 40px のとき -->
<!-- 文字と文字の実際の距離は 40 + 4 + 4 = 48px になる -->
<div class="space-y-[40px]">
  <p class="text-[16px] leading-[24px]">段落 1</p>
  <p class="text-[16px] leading-[24px]">段落 2</p>
</div>
```

デザイナーは「文字と文字の間隔 40px」のつもりで作ることがある。

**対処の選択肢**：

| 方針 | 内容 |
|------|------|
| デザイナー側が理解する | ブラウザのメンタルモデルに合わせてもらう（スペーシング値が存在しない数になる場合がある） |
| half leading をキャンセル | プラグインで half leading を削るクラスを提供（`CUSTOMIZATION.md` のプラグイン作成例を参照） |

文字サイズのルールを策定する際に**事前に議論しておく**ことが重要。

---

## v4 での設定配布

### v4 は CSS ベースで配布する

v4 では `@theme` ディレクティブで定義したトークンを CSS ファイルとして配布できる。

```css
/* design-system/tokens.css */
@theme {
  --color-primary: oklch(65% 0.2 260);
  --color-surface: oklch(98% 0.01 260);

  --spacing-1: 4px;
  --spacing-2: 8px;
  --spacing-4: 16px;
  --spacing-6: 24px;
  --spacing-10: 40px;

  --text-sm: 0.875rem;
  --text-sm--line-height: 1.25rem;
  --text-base: 1rem;
  --text-base--line-height: 1.5rem;
}
```

利用側：

```css
/* プロジェクト側の CSS */
@import "tailwindcss";
@import "design-system/tokens.css";
```

### v3：プリセットをライブラリとして配布

```js
// design-system/tailwind.config.js
module.exports = {
  theme: {
    // 完全上書き（デフォルトテーマを使わない場合）
    colors: {
      primary: 'var(--semantic-color-primary)',
      surface: '#fafafa',
    },
    spacing: {
      1: '4px',
      2: '8px',
      4: '16px',
      6: '24px',
      10: '40px',
      16: '64px',
    },
    // 追加（デフォルトに加える場合）
    extend: {
      opacity: {
        32: '0.32',
      },
    },
  },
};
```

### プリセットを関数でエクスポートする（複数バージョン対応）

```js
/**
 * @param {Object} options
 * @param {'v3' | 'v4'} [options.version='v3']
 * @return {import('tailwindcss').Config}
 */
module.exports = function createTailwindConfig({ version = 'v3' }) {
  switch (version) {
    case 'v3':
      return { theme: { /* v3 向け設定 */ } };
    case 'v4':
      return { theme: { /* v4 向け設定 */ } };
    default:
      throw new Error('サポートされていません');
  }
};
```

```js
// 利用側の tailwind.config.js
const { createTailwindConfig } = require('@my-org/design-system');

module.exports = {
  presets: [createTailwindConfig({ version: 'v3' })],
};
```

### プリセットに含めるべきでないもの

| 含めるべきもの | 含めるべきでないもの |
|----------------|----------------------|
| `theme`（デザイントークン） | `content`（ファイルパス） |
| 自作プラグイン | `prefix` |
| peerDependencies として宣言したプラグイン | `darkMode` |
| | `important` |

```json
// 共通ライブラリの package.json
{
  "peerDependencies": {
    "tailwindcss": ">=3.0.0 || >= 4.0.0-alpha.1",
    "@tailwindcss/forms": ">=0.4.0"
  }
}
```

サードパーティプラグインを `dependencies` に含めると、利用側がバージョンを独自にコントロールできなくなる。`peerDependencies` として宣言し、インストール判断を利用側に委ねる。

---

## チーム運用

### プロダクトが 1 つ・チームが小さい場合

- プロジェクトリポジトリの `tailwind.config.js` ≒ デザインシステム
- Figma とコードの分離が必須でない場合も（デザイナーがコーディングできる場合）
- ルール変更はチーム内のコミュニケーションで完結

### 複数チーム・設定ファイルを分離する場合

設定ファイルをライブラリとして別リポジトリに分離するタイミングが、**専任チームを作るタイミング**。

- 専任チームには**デザイナーと開発者の両方**が必要
- 初期は兼務でも可（プロダクトの実態を把握したまま開発できるメリット）
- デザインシステムが成熟したら真の専任メンバーに移行する戦略をとる

**ルール追加の暫定フロー**：

```js
// とあるプロダクトの tailwind.config.js（暫定追加）
module.exports = {
  theme: {
    extend: {
      colors: {
        // TODO: 共通ライブラリに追加されたら削除
        danger: '#ff0000',
      },
    },
  },
};
```

共通ライブラリに取り込まれたら削除する合意をチームで取っておく。

---

## Tailwind CSS では担保できない領域

### コンポーネント挙動

Tailwind CSS が提供するのはユーティリティクラスのみ。コンポーネントの挙動（「トリガをクリックするとメニューが出現する」「キーボード操作に反応する」）は別途用意が必要。

**ヘッドレス UI ライブラリ**（見た目を持たない挙動のみのコンポーネント群）が有用：

| ライブラリ | 特徴 |
|-----------|------|
| Headless UI | Tailwind CSS チームが開発。React / Vue.js 向け |
| Radix UI | React 向け。豊富なコンポーネント |
| React Aria | Adobe 製。アクセシビリティ重視。フック + ヘッドレスコンポーネント |
| Radix Vue / Oku UI | Vue.js エコシステム向け |

```jsx
// Headless UI の Listbox 例（見た目はクラスで決定）
import { Listbox } from '@headlessui/react';

<Listbox value={selected} onChange={setSelected}>
  <Listbox.Button className="relative w-full rounded-lg bg-white py-2 pl-3 pr-10 text-left shadow-md">
    {selected.name}
  </Listbox.Button>
  <Listbox.Options>
    {items.map((item) => (
      <Listbox.Option key={item.id} value={item}>
        {item.name}
      </Listbox.Option>
    ))}
  </Listbox.Options>
</Listbox>
```

### アイコンライブラリ

アイコンは Tailwind CSS では賄えない。選定時に確認すべきポイント：

**1. 色を変更できるか**

`<img>` タグで読み込まれた SVG は外から色を変えられない。`currentcolor` を内部で使いつつ `class` を受け取れるインターフェースが必要。

```jsx
// heroicons の例（currentcolor で文字色に追従）
import { BeakerIcon } from '@heroicons/react/24/solid';

<BeakerIcon className="w-6 h-6 text-blue-500" />
```

**2. スクリーンリーダーへの対応**

Web フォント方式のアイコン（旧 Glyphicon など）はスクリーンリーダーで謎の文字として読まれる。**SVG 方式を選ぶ**のが現在の標準。

### アクセシビリティ

Tailwind CSS 単独でカラーアクセシビリティを担保することはできない。デザイントークン策定時に組み込む必要がある。

**WCAG（Web Content Accessibility Guidelines）**：

- W3C が定めるアクセシビリティガイドライン
- カラーコントラストに AA / AAA の 2 適合レベルが存在
- 日本の JIS X 8341-3:2016 は ISO/IEC 40500:2012 と一致 → 実質 WCAG 2.0

**ツール**：

| ツール | 対象 |
|-------|------|
| Figma プラグイン | デザイン段階でコントラスト確認 |
| Adobe Photoshop 拡張機能 | 画像確認 |
| Storybook アクセシビリティアドオン | コンポーネント確認 |
| Chrome DevTools Lighthouse | ページ全体確認 |

ヘッドレス UI ライブラリはアクセシビリティの一部（キーボード操作・ARIA 属性）を担保してくれるため、積極的に活用する。

---

## AskUserQuestion ガイド

**確認すべき場面**：
- 1 階層（リテラルのみ）と 2 階層（リテラル + セマンティック）のどちらを採用するか
- スペーシングの値をどこまで絞るか（4 の倍数のみ、フィボナッチ数列風など）
- half leading をキャンセルするプラグインを提供するか
- 設定ファイルをプロジェクト内に置くか、共通ライブラリとして分離するか
- ダークモードを `dark:` モディファイア方式にするか、CSS 変数（セマンティックカラー）方式にするか

**確認不要な場面**：
- ボトムアップ戦略（コンポーネント集から始めない）の採用（原則的に推奨）
- プリセットに `content` や `prefix` を含めないこと（プロジェクト側が決めることのため）
- SVG 方式のアイコンライブラリを選ぶこと（Web フォント方式は現在の標準から外れている）
