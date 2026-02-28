# コンポーネント設計パターン

## @layer components の位置づけ

### レイヤ設計の基本

Tailwind CSS の @layer は `base` → `components` → `utilities` の順番で適用される。
`components` に定義したクラスは必ず `utilities` のクラスで上書き可能。
これはコンポーネントクラスがユーティリティによる細かい調整を常に受け入れるべきという設計原則を反映している。

```css
/* v4: @import "tailwindcss" でbase/components/utilitiesが自動ロード */
@layer components {
  .card {
    @apply p-8 bg-gray-100 rounded-lg;
  }
}
```

v4 では `@utility` でプロジェクト固有のカスタムユーティリティが定義できる。
コンポーネントクラス（`.card`）はユーティリティで上書きされることを前提に設計する。

```html
<!-- .card の bg-gray-100 をユーティリティで上書きできる -->
<div class="card bg-white">...</div>
```

### CSS コンポーネントクラスの適切な用途

CSSのコンポーネントクラス（`.prose` など）は「スタイリングだけを責務にした抽象化」に限定する。

| ✅ 適切 | ❌ 不適切 |
|---------|----------|
| `.prose`（Typographyプラグイン） | `.btn`（`<Button>` コンポーネントで代替） |
| マークアップの共有が不要な純粋スタイリング | 挙動・アクセシビリティを含む UI |
| ユーティリティで上書き可能な設計 | 内部実装を隠蔽した閉じたスタイル |

UIコンポーネント（Reactなど）が存在する場合、対応する CSSクラスを @layer components に作る必要はほぼない。

---

## コンポーネントの粒度と命名

### 命名を最小限にする

Tailwindではユーティリティをそのまま要素に書くため、ラッパーに`.ProfileCard__wrapper` などの名前が不要になる。

```tsx
// 不要な中間命名なしに書ける
export const ProfileCard = ({ avatarUrl, children }) => {
  return (
    <div className="p-8 bg-gray-100">
      <img className="w-24 h-24 rounded-full" src={avatarUrl} />
      <div>{children}</div>
    </div>
  );
};
```

コンポーネントを切るタイミング = 「命名に値する単位か」を考えるタイミング。両者が一致する。

### クラスの変数化とコンポーネント化の使い分け

同ファイル内での繰り返しに対してはクラスを変数化する。
グローバルに共有する必要があるならコンポーネント化する。

```tsx
// ファイル内での共通クラスは変数化
const wrapperClass = "p-8 bg-gray-100";

export const ProfileCard = ({ avatarUrl, children }) => (
  <div className={wrapperClass}>
    <img className="w-24 h-24 rounded-full" src={avatarUrl} />
    <div>{children}</div>
  </div>
);

export const ItemCard = ({ itemPhoto, children }) => (
  // 同じクラスを別の要素に適用できる
  <li className={`${wrapperClass} border`}>
    <img className="w-48 h-48" src={itemPhoto} />
    <div>{children}</div>
  </li>
);
```

`@apply` と異なり、変数化はグローバルなCSSを汚染しない。
`export` しない限り、ほかのコンポーネントから誤使用される心配もない。

### すべてがコンポーネントである必要はない

ページコンポーネントの中に、抽象化されたコンポーネントとユーティリティを書いた `<div>` が混在してもよい。

```tsx
// これでよい
export function ProfilePage({ profile }) {
  return (
    <div className="flex flex-row">
      <ProfileCard src={profile} />
      <FilterableItemList userId={profile.userId}>
        {(item) => <div className="flex">...</div>}
      </FilterableItemList>
    </div>
  );
}
```

「命名が実装上不要になる」とは、コーディングの手数を減らすだけでなく、デザイナーが使っていない名前を実装都合で付けることを避けるということでもある。

---

## 「基底コンポーネント」の誘惑に抗う

### アンチパターン：大量のスタイリングpropsを受け取る `<Box>`

```tsx
// ❌ 避けるべきパターン（MUI <Box> スタイル）
<Box
  sx={{
    width: 300,
    height: 300,
    backgroundColor: "primary.dark",
    "&:hover": { backgroundColor: "primary.main" },
  }}
/>
```

Tailwind CSS ではすべての HTML 要素にユーティリティクラスを直接当てられるため、`<Box>` のような基底コンポーネントは不要。

```tsx
// ✅ ユーティリティを直接使う
<div className="w-[300px] h-[300px] bg-primary-dark hover:bg-primary-main" />
```

### 正しい最小単位のコンポーネント

UIとして意味のある単位（`<Button>`、`<Checkbox>` など）が最小単位で十分。
`<Box>`、`<Text>` などにすべてを還元しようとしない。

```tsx
// ✅ UIとして意味のある単位だけをコンポーネントにする
<Button color="primary" onClick={handleClick}>送信</Button>
<Checkbox checked={isChecked} onChange={handleChange} label="同意する" />
```

---

## className props の設計戦略

### 基本方針：バリエーションを定義する

`className` props は最終手段（脱出ハッチ）として位置づける。
正規のカスタマイズは専用の props を提供する。

```tsx
// ✅ バリエーションはpropsで定義
interface Props {
  color?: 'primary' | 'default' | 'danger';
  className?: string; // ← 最終手段（想定外の用途のみ）
  children?: React.ReactNode;
}

export function Button({ color = 'default', children, className }: Props) {
  return (
    <button
      className={[
        'inline-grid',
        color === 'primary' && 'text-white bg-blue-500 hover:bg-blue-600',
        color === 'default' && 'text-gray-600 bg-gray-300 hover:bg-gray-400',
        color === 'danger' && 'text-white bg-red-600 hover:bg-red-700',
        className,
      ].filter(Boolean).join(' ')}
    >
      {children}
    </button>
  );
}
```

### cva（Class Variance Authority）

Tailwind CSS に依存しない汎用的なバリエーション定義ライブラリ。

```bash
npm install class-variance-authority
```

```tsx
import { cva } from 'class-variance-authority';

const buttonClass = cva(
  // ベース（全バリアント共通）クラス
  ['inline-grid', 'px-4', 'py-2', 'rounded', 'font-medium'],
  {
    variants: {
      color: {
        primary: ['text-white', 'bg-blue-500', 'hover:bg-blue-600'],
        default: ['text-gray-600', 'bg-gray-300', 'hover:bg-gray-400'],
        danger: ['text-white', 'bg-red-600', 'hover:bg-red-700'],
      },
      size: {
        sm: ['text-sm', 'px-3', 'py-1'],
        md: ['text-base', 'px-4', 'py-2'],
        lg: ['text-lg', 'px-6', 'py-3'],
      },
    },
    defaultVariants: {
      color: 'default',
      size: 'md',
    },
  }
);

export function Button({ color, size, className, children }: Props) {
  return (
    <button className={buttonClass({ color, size, className })}>
      {children}
    </button>
  );
}
```

### tailwind-variants

Tailwind CSS 専用に設計されたバリエーション定義ライブラリ。
レスポンシブなバリアント切り替えなど Tailwind 固有の API が特徴。

```bash
npm install tailwind-variants
```

```tsx
import { tv } from 'tailwind-variants';

const buttonClass = tv({
  base: 'inline-grid px-4 py-2 rounded font-medium',
  variants: {
    color: {
      primary: 'text-white bg-blue-500 hover:bg-blue-600',
      default: 'text-gray-600 bg-gray-300 hover:bg-gray-400',
    },
  },
  // 画面幅に応じてバリアントを切り替えるAPI（tailwind-variants固有）
  responsiveVariants: ['sm'],
});

// 使用例：スマホでは default、sm以上では primary
buttonClass({
  color: { initial: 'default', sm: 'primary' },
});
```

### 複数 className を受け取るケース

`headerClassName`、`bodyClassName` のように複数の className を受け取る設計は避ける。
代わりにコンポーネントを分割して、それぞれに `className` を渡す。

```tsx
// ❌ 避ける
<Modal headerClassName="!text-gray-400" bodyClassName="!text-gray-600" />

// ✅ コンポーネントを分割して個別にclassNameを渡す
<Modal>
  <ModalHeader className="!text-gray-400" />
  <ModalBody className="!text-gray-600" />
</Modal>
```

### tailwind-merge でクラス衝突を解決

`className` 経由で渡したクラスがコンポーネント内部のクラスと衝突する場合は `tailwind-merge` を使う。

```bash
npm install tailwind-merge
```

```tsx
import { twMerge } from 'tailwind-merge';

// p-4 と !p-6 の衝突 → !p-6 が勝つ
<div className={twMerge('p-4', '!p-6')}>...</div>
// → <div class="!p-6">

// コンポーネント内での使用
export function Button({ className, children }: Props) {
  return (
    <button className={twMerge('p-4 bg-blue-500', className)}>
      {children}
    </button>
  );
}
```

---

## コンポーネント配布方法

### 方法1：コピー&ペースト（Tailwind UI / shadcn/ui）

利用者にマークアップをコピーして自プロジェクトに取り込んでもらう方式。
Tailwind CSS のスタイルがプロジェクトに閉じているという特性と相性がよい。

| ライブラリ | 特徴 |
|-----------|------|
| **Tailwind UI** | 公式チーム製。有料。コンポーネント & テンプレートを HTML/React/Vue で提供 |
| **shadcn/ui** | CLI でコンポーネントのコードをプロジェクト内に生成。カスタマイズが前提 |

```bash
# shadcn/ui の初期セットアップ
npx shadcn-ui@latest init

# コンポーネントを追加（ソースコードがプロジェクト内に生成される）
npx shadcn-ui@latest add button
npx shadcn-ui@latest add dialog
```

shadcn/ui は内部で Tailwind CSS と Radix UI を使用している。
生成されたコードをそのまま使うか、自由に改変して使う。

### 方法2：node_modules の content に含める（Flowbite 方式）

ライブラリ内部でTailwindクラスを使用する場合、利用側の `tailwind.config.js` の `content` にライブラリパスを追加させる方式。

```js
// tailwind.config.js（v3）
module.exports = {
  content: [
    './src/**/*.{js,ts,jsx,tsx}',
    // ライブラリが使うクラスもビルドに含める
    './node_modules/@rewind-ui/core/dist/theme/styles/*.js',
  ],
};
```

v4 では `@source` で指定できる。

```css
/* v4: styles.css */
@import "tailwindcss";
@source "../../node_modules/@rewind-ui/core/dist";
```

---

## ヘッドレス UI ライブラリ

挙動・アクセシビリティを担保し、見た目（スタイリング）は Tailwind CSS で自由に制御できるライブラリ群。

| ライブラリ | 提供者 | 特徴 |
|-----------|--------|------|
| **Headless UI** | Tailwind Labs | Tailwind公式。React/Vue対応。コンポーネント数はやや少なめ |
| **Radix UI** | WorkOS | コンポーネント数が豊富。React向け（Vue版: Radix Vue） |
| **React Aria** | Adobe | フック提供。アクセシビリティ最重視。React Aria Components も提供 |

### Headless UI

```bash
npm install @headlessui/react   # React
npm install @headlessui/vue     # Vue.js
```

```tsx
import { Dialog } from '@headlessui/react';

export function MyDialog({ title, description }) {
  const [isOpen, setIsOpen] = useState(true);

  return (
    <Dialog open={isOpen} onClose={() => setIsOpen(false)} className="relative z-50">
      {/* バックドロップ */}
      <div className="fixed inset-0 bg-black/30" aria-hidden="true" />
      {/* モーダル本体 */}
      <div className="fixed inset-0 flex items-center justify-center p-4">
        <Dialog.Panel className="w-full max-w-sm rounded bg-white p-6">
          <Dialog.Title>{title}</Dialog.Title>
          <Dialog.Description>{description}</Dialog.Description>
          <button onClick={() => setIsOpen(false)} className="mt-4 px-4 py-2 bg-blue-500 text-white rounded">
            OK
          </button>
        </Dialog.Panel>
      </div>
    </Dialog>
  );
}
```

コンポーネントの状態に応じたスタイリングには `@headlessui/tailwindcss` プラグインを使う。

```bash
npm install @headlessui/tailwindcss
```

```tsx
// ui-active: / ui-not-active: などのモディファイアで状態別スタイリング
<Menu.Item>
  <a
    className="
      ui-active:bg-blue-500 ui-active:text-white
      ui-not-active:bg-white ui-not-active:text-black
    "
    href="..."
  >
    リンク
  </a>
</Menu.Item>
```

主なコンポーネント: `Menu`（ドロップダウン）、`Listbox`、`Combobox`、`Switch`、`Disclosure`（アコーディオン）、`Dialog`、`Popover`、`RadioGroup`、`Tab`、`Transition`

### Radix UI

```bash
# コンポーネントごとに個別インストール
npm install @radix-ui/react-popover
```

```tsx
import * as Popover from '@radix-ui/react-popover';

export default () => (
  <Popover.Root>
    <Popover.Trigger className="...">開く</Popover.Trigger>
    <Popover.Portal>
      <Popover.Content className="...">
        <Popover.Close className="...">閉じる</Popover.Close>
        <Popover.Arrow className="fill-white" />
      </Popover.Content>
    </Popover.Portal>
  </Popover.Root>
);
```

`data-state` 属性（`open` / `closed`）を使ったアニメーション。

```tsx
<DialogOverlay className="data-[state='open']:animate-[fadeIn_300ms_ease]">
  {/* ... */}
</DialogOverlay>
```

Vue.js 向けには `radix-vue`（単一パッケージで全コンポーネントを提供）が存在する。

### React Aria / React Aria Components

```bash
npm install react-aria
# または個別パッケージ
npm install @react-aria/dialog
```

フックベースの API でアクセシビリティ要件を実装する。

```tsx
import { useRef } from 'react';
import { useDialog, AriaDialogProps } from 'react-aria';

export function Dialog({ title, children, ...props }: Props) {
  const ref = useRef<HTMLDivElement>(null);
  const { dialogProps, titleProps } = useDialog(props, ref);

  return (
    <div {...dialogProps} ref={ref} className="p-8 bg-white rounded-lg shadow-lg">
      {title && <h3 {...titleProps} className="text-xl font-bold">{title}</h3>}
      {children}
    </div>
  );
}
```

React Aria Components ではアニメーション向けの data 属性（`data-entering`、`data-exiting`）が利用できる。

```tsx
<Popover className="data-[entering]:animate-[fadeIn_300ms_ease] data-[exiting]:animate-[fadeOut_200ms_ease]">
  {/* ... */}
</Popover>
```

---

## アニメーションライブラリ

### tailwindcss-animate

Tailwind CSS のユーティリティとして `animate-in`、`animate-out` などを追加するプラグイン。
shadcn/ui でも採用されており、React Aria Components の data 属性と相性がよい。

```bash
npm install tailwindcss-animate
```

```css
/* v3 */
plugins: [require('tailwindcss-animate')]
/* v4 */
@plugin "tailwindcss-animate";
```

```tsx
<Popover className="data-[entering]:animate-in data-[entering]:fade-in data-[exiting]:animate-out data-[exiting]:fade-out">
  {/* ... */}
</Popover>
```

### Headless UI `<Transition>`

CSSクラスで出現・消滅アニメーションを宣言的に記述する。
`enter`/`leave` と `From`/`To` の組み合わせでトランジションを定義する。

```tsx
import { Transition } from '@headlessui/react';

<Transition
  show={isShowing}
  enter="transition-opacity duration-75"
  enterFrom="opacity-0"
  enterTo="opacity-100"
  leave="transition-opacity duration-150"
  leaveFrom="opacity-100"
  leaveTo="opacity-0"
>
  フェードインする
</Transition>
```

複数の子要素が別々のアニメーションをする場合は `<Transition.Child>` を使う。

```tsx
<Transition show={isShowing}>
  {/* 背景：フェード */}
  <Transition.Child
    enter="transition-opacity ease-linear duration-300"
    enterFrom="opacity-0"
    enterTo="opacity-100"
    leave="transition-opacity ease-linear duration-300"
    leaveFrom="opacity-100"
    leaveTo="opacity-0"
  >
    <div className="fixed inset-0 bg-black/40" />
  </Transition.Child>

  {/* サイドバー：スライド */}
  <Transition.Child
    enter="transition ease-in-out duration-300 transform"
    enterFrom="-translate-x-full"
    enterTo="translate-x-0"
    leave="transition ease-in-out duration-300 transform"
    leaveFrom="translate-x-0"
    leaveTo="-translate-x-full"
  >
    <nav className="fixed left-0 top-0 h-full w-64 bg-white">...</nav>
  </Transition.Child>
</Transition>
```

### react-spring

物理法則（バネ）に基づくアニメーションライブラリ。
Tailwind CSS から完全に独立してアニメーションを定義する。

```bash
npm install @react-spring/web
```

```tsx
import { useSpring, animated } from '@react-spring/web';

export function FadeIn() {
  const [props] = useSpring(
    () => ({
      from: { opacity: 0 },
      to: { opacity: 1 },
    }),
    [],
  );

  // animated.div は className も受け付けるため Tailwind と組み合わせ可能
  return <animated.div style={props} className="p-4 bg-white rounded">Hello World</animated.div>;
}
```

デザインシステムでアニメーション定義を Tailwind CSS と切り離したい場合（ネイティブアプリと演出をそろえたい場合など）に有力な選択肢。

### framer-motion

多数の React フック（`useAnimation`、`useSpring`、`useVelocity` など）を提供するアニメーションライブラリ。
`framer-motion/dom` からインポートすることで React 以外の環境でも利用できる。

```bash
npm install framer-motion
```

```tsx
import { useAnimate } from 'framer-motion';

export function AnimatedList({ children }) {
  const [scope, animate] = useAnimate();

  useEffect(() => {
    animate('li', { opacity: 1 }, { duration: 1 });
  });

  return <ul ref={scope}>{children}</ul>;
}
```

---

## ライブラリ選定ガイド

| 用途 | 推奨 |
|------|------|
| コンポーネントの挙動・a11y | Headless UI（公式）または Radix UI（コンポーネント数重視） |
| アクセシビリティを最重視 | React Aria / React Aria Components |
| バリエーション定義 | cva（汎用）または tailwind-variants（Tailwind専用機能を使いたい場合） |
| クラス衝突解決 | tailwind-merge |
| 出現・消滅アニメーション | tailwindcss-animate または Headless UI `<Transition>` |
| 物理アニメーション | react-spring |
| 複雑なアニメーション制御 | framer-motion |
| コンポーネント配布（内部利用） | コピー&ペースト（Tailwind UI / shadcn/ui） |
| コンポーネント配布（ライブラリ） | node_modules を content に含める方式 |
