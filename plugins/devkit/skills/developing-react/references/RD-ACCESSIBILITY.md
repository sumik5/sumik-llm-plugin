# RD-ACCESSIBILITY.md — React アクセシビリティ実装ガイド

> WCAG 2.1 AA 準拠のReactアプリケーション構築。セマンティックHTML優先、ARIA補助的利用、フォーカス管理の3本柱。

---

## 1. セマンティックHTML

**原則**: 「ARIAは最後の手段」— セマンティックHTMLが先、ARIAは補完。

### ✅ button vs div onClick

```tsx
// ❌ BAD: div はキーボード・スクリーンリーダーで動作しない
const BadButton = () => (
  <div onClick={handleClick} className="btn">送信</div>
);

// ✅ GOOD: button はキーボード・フォーカス・スクリーンリーダー対応が標準内蔵
const GoodButton = () => (
  <button type="button" onClick={handleClick} className="btn">
    送信
  </button>
);
```

### ランドマーク要素の使い分け

| 要素 | 役割 | 使用場面 |
|------|------|---------|
| `<header>` | バナー | サイトヘッダー（`<main>` 外） |
| `<nav>` | ナビゲーション | メニュー、パンくずリスト |
| `<main>` | メインコンテンツ | ページの主要コンテンツ（1ページに1つ） |
| `<section>` | セクション | 見出しを持つ意味のあるグループ |
| `<article>` | 記事 | 単体で完結するコンテンツ（ブログ記事、コメント） |
| `<aside>` | 補足情報 | サイドバー、関連リンク |
| `<footer>` | 補足情報 | フッター |

```tsx
// ✅ GOOD: ランドマーク構造
const PageLayout: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <>
    <header>
      <nav aria-label="メインナビゲーション">...</nav>
    </header>
    <main id="main-content">{children}</main>
    <aside aria-label="関連情報">...</aside>
    <footer>...</footer>
  </>
);
```

### 見出し階層（h1–h6）

```tsx
// ❌ BAD: 見出し順序が飛ぶ
<h1>サイトタイトル</h1>
<h3>セクションタイトル</h3>  {/* h2 が抜けている */}

// ✅ GOOD: 連続した階層
<h1>サイトタイトル</h1>
<h2>セクションタイトル</h2>
<h3>サブセクション</h3>
```

---

## 2. ARIAライブリージョン

動的に変化するコンテンツをスクリーンリーダーに通知するパターン。

### role="alert" vs aria-live

| 属性/ロール | 割込みタイミング | 用途 |
|------------|----------------|------|
| `role="alert"` | 即時（assertive相当） | エラー通知、重要なシステムメッセージ |
| `aria-live="assertive"` | 即時 | 緊急通知（現在の読み上げを中断） |
| `aria-live="polite"` | 読み上げ完了後 | 成功通知、ステータス更新 |
| `aria-live="off"` | 通知しない | 頻繁に変わる非重要コンテンツ |

```tsx
// ✅ GOOD: 通知コンポーネント
interface NotificationProps {
  message: string;
  type: "error" | "success" | "info";
}

const Notification: React.FC<NotificationProps> = ({ message, type }) => {
  if (type === "error") {
    return (
      // role="alert" は暗黙的に aria-live="assertive" + aria-atomic="true"
      <div role="alert" className="notification error">
        {message}
      </div>
    );
  }

  return (
    // polite: 現在の読み上げ完了後に通知
    <div aria-live="polite" aria-atomic="true" className="notification">
      {message}
    </div>
  );
};
```

### aria-atomic の使い分け

```tsx
// aria-atomic="true": リージョン全体を1つのまとまりとして読み上げ
// aria-atomic="false"（デフォルト）: 変化した部分だけを読み上げ

// ✅ タイマー: 変化した数値だけ読み上げ（false）
<div aria-live="polite" aria-atomic="false">
  残り <span>{secondsLeft}</span> 秒
</div>

// ✅ フォーム送信結果: メッセージ全体を読み上げ（true）
<div aria-live="polite" aria-atomic="true">
  {submitResult}
</div>
```

### 動的通知の実装パターン（トースト）

```tsx
// ✅ GOOD: DOMにマウント済みのライブリージョンに動的注入
const useAnnouncer = () => {
  const [message, setMessage] = React.useState("");

  const announce = React.useCallback((text: string) => {
    setMessage(""); // 同一メッセージの再通知を確実にトリガー
    requestAnimationFrame(() => setMessage(text));
  }, []);

  const AnnouncerRegion = (
    <div
      aria-live="polite"
      aria-atomic="true"
      className="sr-only"  // 視覚的に非表示
    >
      {message}
    </div>
  );

  return { announce, AnnouncerRegion };
};
```

---

## 3. フォーカス管理

### useRef + focus() の基本

```tsx
// ✅ GOOD: エラー発生時に最初のエラーフィールドにフォーカス
const FormWithFocus: React.FC = () => {
  const firstErrorRef = React.useRef<HTMLInputElement>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const errors = validate();
    if (errors.length > 0) {
      firstErrorRef.current?.focus();  // 任意のDOM要素にフォーカス
    }
  };

  return (
    <form onSubmit={handleSubmit}>
      <input ref={firstErrorRef} type="text" aria-invalid="true" />
    </form>
  );
};
```

### フォーカストラップ（モーダル）— 詳細実装

モーダルはTabキーでフォーカスがモーダル内に留まる必要がある。

```tsx
// ✅ GOOD: フォーカストラップの完全実装
const FOCUSABLE_SELECTORS = [
  "button:not([disabled])",
  "input:not([disabled])",
  "select:not([disabled])",
  "textarea:not([disabled])",
  "a[href]",
  "[tabindex]:not([tabindex='-1'])",
].join(", ");

interface ModalProps {
  isOpen: boolean;
  onClose: () => void;
  title: string;
  children: React.ReactNode;
}

const Modal: React.FC<ModalProps> = ({ isOpen, onClose, title, children }) => {
  const overlayRef = React.useRef<HTMLDivElement>(null);
  const previousFocusRef = React.useRef<HTMLElement | null>(null);

  // モーダルを開く時: 開く前の要素を記憶して最初のフォーカス可能要素に移動
  React.useEffect(() => {
    if (!isOpen) return;

    previousFocusRef.current = document.activeElement as HTMLElement;

    const firstFocusable = overlayRef.current?.querySelector<HTMLElement>(
      FOCUSABLE_SELECTORS
    );
    firstFocusable?.focus();

    // クリーンアップ: モーダルを閉じる時に元の要素に戻す
    return () => {
      previousFocusRef.current?.focus();
    };
  }, [isOpen]);

  // Tab/Shift+Tab でフォーカスをモーダル内に閉じ込める
  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "Escape") {
      onClose();
      return;
    }

    if (e.key !== "Tab") return;

    const focusableElements = Array.from(
      overlayRef.current?.querySelectorAll<HTMLElement>(FOCUSABLE_SELECTORS) ??
        []
    );

    if (focusableElements.length === 0) return;

    const firstEl = focusableElements[0];
    const lastEl = focusableElements[focusableElements.length - 1];

    if (e.shiftKey) {
      // Shift+Tab: 最初の要素からさらに戻ろうとしたら最後の要素へ
      if (document.activeElement === firstEl) {
        e.preventDefault();
        lastEl.focus();
      }
    } else {
      // Tab: 最後の要素からさらに進もうとしたら最初の要素へ
      if (document.activeElement === lastEl) {
        e.preventDefault();
        firstEl.focus();
      }
    }
  };

  if (!isOpen) return null;

  return (
    // ポータルで body 直下にレンダリングすることを推奨
    <div
      className="modal-overlay"
      onClick={onClose}
      aria-hidden="true"
    >
      <div
        ref={overlayRef}
        role="dialog"
        aria-modal="true"
        aria-labelledby="modal-title"
        onKeyDown={handleKeyDown}
        onClick={(e) => e.stopPropagation()}
        className="modal"
      >
        <h2 id="modal-title">{title}</h2>
        {children}
        <button type="button" onClick={onClose}>閉じる</button>
      </div>
    </div>
  );
};
```

### tabIndex の使い分け

| 値 | 動作 | 用途 |
|----|------|------|
| `tabIndex={0}` | Tab順序に追加 | 本来フォーカス不可要素をフォーカス可能に |
| `tabIndex={-1}` | Tab順序から除外、focus()で移動可能 | プログラム的フォーカス移動先 |
| 正の整数（非推奨） | Tab順序を指定 | 使用禁止（自然なDOM順序を優先） |

### フォーカスリング

```tsx
// ✅ GOOD: フォーカスリングを隠さない（:focus-visible を活用）
// CSS
// button:focus-visible { outline: 2px solid #005fcc; outline-offset: 2px; }
// button:focus:not(:focus-visible) { outline: none; }  // マウスクリック時は非表示
```

---

## 4. キーボードナビゲーション

### onKeyDown パターン

```tsx
// ✅ GOOD: キーボードイベントの型安全な処理
const KeyboardButton: React.FC = () => {
  const handleKeyDown = (e: React.KeyboardEvent<HTMLDivElement>) => {
    switch (e.key) {
      case "Enter":
      case " ":  // Space
        e.preventDefault();
        handleActivate();
        break;
      case "Escape":
        handleClose();
        break;
    }
  };

  return (
    <div
      role="button"
      tabIndex={0}
      onKeyDown={handleKeyDown}
      onClick={handleActivate}
    >
      アクション
    </div>
  );
};
```

### ロービングtabindex パターン（リスト/グリッドナビゲーション）

矢印キーでリスト内を移動し、Tabでウィジェット全体を飛び越えるパターン。

```tsx
// ✅ GOOD: ロービングtabindex
const MenuList: React.FC<{ items: string[] }> = ({ items }) => {
  const [activeIndex, setActiveIndex] = React.useState(0);
  const itemRefs = React.useRef<(HTMLButtonElement | null)[]>([]);

  const handleKeyDown = (e: React.KeyboardEvent, index: number) => {
    let nextIndex = index;

    switch (e.key) {
      case "ArrowDown":
        e.preventDefault();
        nextIndex = (index + 1) % items.length;
        break;
      case "ArrowUp":
        e.preventDefault();
        nextIndex = (index - 1 + items.length) % items.length;
        break;
      case "Home":
        e.preventDefault();
        nextIndex = 0;
        break;
      case "End":
        e.preventDefault();
        nextIndex = items.length - 1;
        break;
      default:
        return;
    }

    setActiveIndex(nextIndex);
    itemRefs.current[nextIndex]?.focus();
  };

  return (
    <ul role="menu">
      {items.map((item, index) => (
        <li key={item} role="none">
          <button
            ref={(el) => { itemRefs.current[index] = el; }}
            role="menuitem"
            // ロービングtabindex: アクティブな要素のみ tabIndex=0
            tabIndex={index === activeIndex ? 0 : -1}
            onKeyDown={(e) => handleKeyDown(e, index)}
          >
            {item}
          </button>
        </li>
      ))}
    </ul>
  );
};
```

---

## 5. フォームアクセシビリティ

```tsx
// ✅ GOOD: 完全なフォームアクセシビリティ実装
interface FormFieldProps {
  id: string;
  label: string;
  hint?: string;
  error?: string;
  required?: boolean;
}

const FormField: React.FC<FormFieldProps & React.InputHTMLAttributes<HTMLInputElement>> = ({
  id,
  label,
  hint,
  error,
  required,
  ...inputProps
}) => {
  const hintId = hint ? `${id}-hint` : undefined;
  const errorId = error ? `${id}-error` : undefined;

  // aria-describedby で複数の補足情報を関連付け
  const describedBy = [hintId, errorId].filter(Boolean).join(" ") || undefined;

  return (
    <div className="form-field">
      <label htmlFor={id}>
        {label}
        {required && <span aria-hidden="true"> *</span>}
        {required && <span className="sr-only">（必須）</span>}
      </label>

      {hint && (
        <p id={hintId} className="hint">
          {hint}
        </p>
      )}

      <input
        id={id}
        aria-describedby={describedBy}
        aria-invalid={error ? "true" : undefined}
        aria-required={required}
        {...inputProps}
      />

      {/* エラーはinput直後に配置、role="alert" で即時通知 */}
      {error && (
        <p id={errorId} role="alert" className="error-message">
          {error}
        </p>
      )}
    </div>
  );
};

// グループ化フィールド: fieldset + legend
const AddressGroup: React.FC = () => (
  <fieldset>
    <legend>配送先住所</legend>
    <FormField id="postal" label="郵便番号" required />
    <FormField id="prefecture" label="都道府県" required />
    <FormField id="city" label="市区町村" required />
  </fieldset>
);
```

---

## 6. 動的コンテンツ

### ルート変更時のフォーカス移動

```tsx
// ✅ GOOD: Next.js / React Router でのページ遷移フォーカス管理
const PageTitle: React.FC<{ title: string }> = ({ title }) => {
  const titleRef = React.useRef<HTMLHeadingElement>(null);

  // ルート変更を検出してh1にフォーカス
  React.useEffect(() => {
    document.title = title;
    titleRef.current?.focus();
  }, [title]);

  return (
    // tabIndex={-1}: Tab順序には含まれず、focus()のみで移動可能
    <h1 ref={titleRef} tabIndex={-1} className="page-title">
      {title}
    </h1>
  );
};
```

### ローディング通知（aria-busy）

```tsx
// ✅ GOOD: 非同期操作中の状態通知
const DataTable: React.FC<{ isLoading: boolean; data: Row[] }> = ({
  isLoading,
  data,
}) => (
  <div>
    {/* aria-busy: スクリーンリーダーに「まだ変化中」を伝える */}
    <table aria-busy={isLoading} aria-label="データ一覧">
      {isLoading && (
        <caption>
          <span aria-live="polite">データを読み込み中...</span>
        </caption>
      )}
      <tbody>
        {data.map((row) => <tr key={row.id}>...</tr>)}
      </tbody>
    </table>
  </div>
);
```

### トースト通知（スクリーンリーダー対応）

```tsx
// ✅ GOOD: マウント済みライブリージョンへの動的注入
// ポイント: コンテナは常にDOMに存在し、メッセージだけを動的に変える
const ToastContainer: React.FC = () => {
  const { toasts } = useToastStore();

  return (
    <>
      {/* スクリーンリーダー用の非表示ライブリージョン */}
      <div aria-live="polite" aria-atomic="true" className="sr-only">
        {toasts.map((t) => t.message).join(". ")}
      </div>

      {/* 視覚的なトースト表示 */}
      <div className="toast-container" aria-hidden="true">
        {toasts.map((toast) => (
          <div key={toast.id} className={`toast toast-${toast.type}`}>
            {toast.message}
          </div>
        ))}
      </div>
    </>
  );
};
```

---

## 7. テスト

### jest-axe による自動チェック

```tsx
import { render } from "@testing-library/react";
import { axe, toHaveNoViolations } from "jest-axe";

expect.extend(toHaveNoViolations);

describe("FormField アクセシビリティ", () => {
  it("WCAG違反がないこと", async () => {
    const { container } = render(
      <FormField
        id="email"
        label="メールアドレス"
        type="email"
        required
      />
    );
    const results = await axe(container);
    expect(results).toHaveNoViolations();
  });

  it("エラー状態でもWCAG準拠であること", async () => {
    const { container } = render(
      <FormField
        id="email"
        label="メールアドレス"
        type="email"
        error="有効なメールアドレスを入力してください"
      />
    );
    const results = await axe(container);
    expect(results).toHaveNoViolations();
  });
});
```

### RTL の getByRole / getByLabelText を優先

```tsx
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

describe("Modal フォーカストラップ", () => {
  it("Escapeキーでモーダルが閉じること", async () => {
    const user = userEvent.setup();
    const onClose = jest.fn();

    render(<Modal isOpen title="テスト" onClose={onClose}>コンテンツ</Modal>);

    // getByRole: セマンティックロールで検索（アクセシブルな実装を強制）
    const dialog = screen.getByRole("dialog", { name: "テスト" });
    expect(dialog).toBeInTheDocument();

    await user.keyboard("{Escape}");
    expect(onClose).toHaveBeenCalledTimes(1);
  });

  it("Tabキーでフォーカスがループすること", async () => {
    const user = userEvent.setup();
    render(
      <Modal isOpen title="テスト" onClose={() => {}}>
        <button>ボタン1</button>
        <button>ボタン2</button>
      </Modal>
    );

    // getByLabelText: ラベルとの関連付けで検索
    const btn1 = screen.getByRole("button", { name: "ボタン1" });
    const btn2 = screen.getByRole("button", { name: "ボタン2" });
    const closeBtn = screen.getByRole("button", { name: "閉じる" });

    await user.tab();
    expect(btn1).toHaveFocus();
    await user.tab();
    expect(btn2).toHaveFocus();
    await user.tab();
    expect(closeBtn).toHaveFocus();
    await user.tab();
    // フォーカストラップ: 最後の要素の次は最初の要素に戻る
    expect(btn1).toHaveFocus();
  });
});
```

### Storybook a11y アドオン

```ts
// .storybook/main.ts
import type { StorybookConfig } from "@storybook/nextjs";

const config: StorybookConfig = {
  addons: [
    "@storybook/addon-a11y",  // axe-core をStorybookに統合
  ],
};

export default config;

// stories/FormField.stories.tsx
export default {
  title: "Components/FormField",
  parameters: {
    a11y: {
      // 特定のルールを無効化（理由が明確な場合のみ）
      config: { rules: [{ id: "color-contrast", enabled: false }] },
    },
  },
};
```

---

## 8. WCAG 2.1 AA チェックリスト

実装時に確認すべき主要項目（[参考: WCAG 2.1](https://www.w3.org/TR/WCAG21/)）。

| カテゴリ | チェック項目 | 判定基準 |
|---------|------------|---------|
| **知覚可能** | 画像に代替テキスト | `alt=""` または意味のある説明文 |
| | 色のみで情報を伝えない | アイコン・テキスト等と併用 |
| | 文字と背景のコントラスト比 | 通常テキスト: 4.5:1 以上、大テキスト: 3:1 以上 |
| | 動画に字幕 | 自動生成でなく正確な字幕 |
| | コンテンツが320px幅で横スクロールなし | レスポンシブ対応 |
| **操作可能** | すべての機能がキーボードで操作可能 | マウス不要でTab/Enterで操作 |
| | フォーカストラップがない（モーダル除く） | Tabで全ページ回遊可能 |
| | フォーカスインジケーター可視 | `:focus-visible` スタイル設定 |
| | リンク・ボタンのクリック領域 | 最小44×44px推奨 |
| | アニメーション停止手段 | `prefers-reduced-motion` 対応 |
| | スキップリンク | `<a href="#main-content">` がページ先頭に存在 |
| **理解可能** | ページ言語の設定 | `<html lang="ja">` |
| | フォームのラベル | `<label for>` または `aria-label` |
| | エラーの説明 | エラー箇所と修正方法を具体的に |
| | 入力形式のヒント | 例: `例: 03-1234-5678` |
| **堅牢** | ARIAロールの正しい使用 | 無効なARIA属性がない |
| | フォームコントロールの名前 | アクセシブルネームが存在する |
| | ステータスメッセージ | `role="status"` / `aria-live` で通知 |

```tsx
// ✅ スキップリンク実装
const SkipLink: React.FC = () => (
  <a
    href="#main-content"
    className="skip-link"  // 通常は視覚的に非表示、フォーカス時に表示
  >
    メインコンテンツにスキップ
  </a>
);
// CSS: .skip-link { position: absolute; transform: translateY(-100%); }
//      .skip-link:focus { transform: translateY(0); }
```

---

## 関連リファレンス

- **テスト**: `testing-code` スキル → jest-axe 設定詳細
- **UIコンポーネント**: `RD-DESIGN-PATTERNS.md` → Headless Components（Radix UI のアクセシビリティ実装例）
- **フォーム**: `RI-DATA-MANAGEMENT.md` → React Hook Form との組み合わせ
- **WCAG公式**: https://www.w3.org/TR/WCAG21/
- **WAI-ARIA patterns**: https://www.w3.org/WAI/ARIA/apg/patterns/
