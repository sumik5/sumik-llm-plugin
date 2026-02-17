# React コンポーネント TDD パターン

> **関連ファイル:** クエリメソッド全網羅は [RTL-QUERIES.md](./RTL-QUERIES.md)、インタラクションパターンは [RTL-INTERACTIONS.md](./RTL-INTERACTIONS.md)、高度テスト（within/props/rerender/snapshot/renderHook）は [RTL-ADVANCED.md](./RTL-ADVANCED.md) を参照。

## 🔄 コンポーネントTDDワークフロー

### stub → test → pass → iterate

最小限の実装から段階的に機能を追加:

```tsx
// stub作成 → テスト追加 → 実装を進化
const CarouselButton = () => <button />;
const CarouselButton = ({ children }: { children?: ReactNode }) => <button>{children}</button>;
```

### ComponentPropsWithRef による型安全props

全ての標準HTML propsを受け入れつつ型安全性を保つ:

```tsx
import { ComponentPropsWithRef } from "react";

const CarouselButton = (props: ComponentPropsWithRef<"button">) => (
  <button {...props} />
);
```

### rest/spread パターン

特定propsのみ抽出し、残りを下位要素に渡す:

```tsx
const CarouselSlide = ({
  imgUrl,
  description,
  ...rest
}: {
  imgUrl?: string;
  description?: ReactNode;
} & ComponentPropsWithRef<"figure">) => (
  <figure {...rest}>
    <img src={imgUrl} />
    <figcaption><strong>{description}</strong></figcaption>
  </figure>
);
```

---

## 🖱️ ユーザーインタラクションテスト

### userEvent.setup() パターン

`fireEvent` より実際のユーザー操作に近いシミュレーション:

```tsx
import userEvent from "@testing-library/user-event";

it("advances the slide when the Next button is clicked", async () => {
  render(<Carousel slides={slides} />);
  const user = userEvent.setup();

  await user.click(screen.getByTestId("next-button"));
  expect(screen.getByRole("img")).toHaveAttribute("src", slides[1].imgUrl);
});
```

**必須:**
- `userEvent.setup()` でインスタンス作成
- すべてのイベントに `await` 必須
- テスト関数は `async` 宣言

### ブラックボックステスト哲学

内部状態にアクセスせず、DOM出力のみをテスト:

```tsx
// ❌ Enzyme時代のアンチパターン
wrapper.state('slideIndex') // RTLでは不可能

// ✅ 推奨: レンダリング結果を検証
it("reverses the slide when Prev is clicked", async () => {
  render(<Carousel slides={slides} />);
  const user = userEvent.setup();

  await user.click(screen.getByTestId("prev-button"));
  expect(screen.getByRole("img")).toHaveAttribute("src", slides[2].imgUrl);
});
```

---

## 🎨 CSS-in-JS / スタイルテスト

### toHaveStyleRule()

`jest-styled-components` でスタイルをテスト:

```tsx
// test-setup.ts
import "@testing-library/jest-dom/vitest";
import "jest-styled-components";

// テスト
it("has the expected static styles", () => {
  render(<CarouselSlide />);
  expect(screen.getByRole("img")).toHaveStyleRule("object-fit", "cover");
  expect(screen.getByRole("img")).toHaveStyleRule("width", "100%");
});

it("uses `imgHeight` as the height", () => {
  render(<CarouselSlide imgHeight="123px" />);
  expect(screen.getByRole("img")).toHaveStyleRule("height", "123px");
});
```

### styled() 拡張テスト

```tsx
export const ScaledImg = styled.img<{ $height?: string | number }>`
  object-fit: cover;
  width: 100%;
  height: ${(props) => typeof props.$height === "number" ? `${props.$height}px` : props.$height};
`;

// 拡張テスト
it("allows styles to be overridden", () => {
  const TestImg = styled(ScaledImg)`
    width: auto;
    object-fit: fill;
  `;
  render(<CarouselSlide ImgComponent={TestImg} imgHeight={250} />);
  expect(screen.getByRole("img")).toHaveStyleRule("width", "auto");
  expect(screen.getByRole("img")).toHaveStyleRule("object-fit", "fill");
});
```

### babel-plugin-styled-components

```tsx
// vite.config.ts
export default defineConfig({
  plugins: [
    react({
      babel: {
        plugins: [
          ["babel-plugin-styled-components", {
            displayName: true,
            fileName: true,
          }],
        ],
      },
    }),
  ],
});
```

メリット: デバッグ時にコンポーネント名が判別可能（`CarouselSlide__ScaledImg-xxx`）

---

## 📸 スナップショット戦略

### 使用すべき場面

**✅ 有効:**
- 静的マークアップ構造の保護
- CSS-in-JSスタイルルール全体の把握

```tsx
it("matches snapshot", () => {
  render(<CarouselSlide />);
  expect(screen.getByRole("figure")).toMatchSnapshot();
});
```

**生成例:**
```tsx
exports[`CarouselSlide > matches snapshot 1`] = `
.c0 {
  object-fit: cover;
  width: 100%;
  height: 500px;
}

<figure>
  <img class="c0" />
  <figcaption data-testid="caption">
    <strong />
  </figcaption>
</figure>
`;
```

### 避けるべき場面

**❌ 不適切:** 動的propsテスト、頻繁に変更される部分、非決定的な出力

**個別アサーション優先:**
```tsx
it("passes `imgUrl` through to the <img>", () => {
  const imgUrl = "https://example.com/image.png";
  render(<CarouselSlide imgUrl={imgUrl} />);
  expect(screen.getByRole("img")).toHaveAttribute("src", imgUrl);
});
```

### テストプルーニング

スナップショット追加後、冗長な個別テストは削除。
削除前: 5-6テスト → 削除後: スナップショット1つ + 動的振る舞いテスト

### バージョン管理連携

1. コード変更
2. テスト実行→不一致
3. diff確認
4. `npm test -- -u` で更新
5. スナップショットをコミット

---

## 🪝 Custom Hooks テスト

> `renderHook` によるフック単体テストは [RTL-ADVANCED.md](./RTL-ADVANCED.md) を参照。以下はコンポーネント経由の間接テストパターン。

### as const パターン

配列返却時の型推論を正確にする:

```tsx
export const useSlideIndex = () => {
  const [slideIndex, setSlideIndex] = useState(0);
  return [slideIndex, setSlideIndex] as const;
};

// as const なし: (number | React.Dispatch<...>)[] → 順序不定
// as const あり: readonly [number, React.Dispatch<...>] → 正確なタプル
```

### 間接テスト

フック単体でなく、使用するコンポーネントを通してテスト:

```tsx
export const useSlideIndex = (slides?: unknown[]) => {
  const [slideIndex, setSlideIndex] = useState(0);
  const incrementSlideIndex = () => {
    if (!slides) return;
    setSlideIndex((i) => (i + 1) % slides.length);
  };
  return [slideIndex, incrementSlideIndex] as const;
};

// コンポーネント経由でテスト
it("advances the slide when Next is clicked", async () => {
  render(<Carousel slides={slides} />);
  const user = userEvent.setup();

  await user.click(screen.getByTestId("next-button"));
  expect(screen.getByRole("img")).toHaveAttribute("src", slides[1].imgUrl);
});
```

### Controllable Pattern

内部状態と外部制御を両立:

```tsx
export const useSlideIndex = (
  slides?: unknown[],
  slideIndexProp?: number,
  onSlideIndexChange?: (newSlideIndex: number) => void
) => {
  const [slideIndexState, setSlideIndexState] = useState(0);
  const slideIndex = slideIndexProp ?? slideIndexState; // propが優先

  const incrementSlideIndex = () => {
    if (!slides) return;
    setSlideIndexState((i) => (i + 1) % slides.length);
    onSlideIndexChange?.((slideIndex + 1) % slides.length);
  };

  return [slideIndex, incrementSlideIndex] as const;
};
```

**テスト:**
```tsx
describe("with controlled slideIndex", () => {
  const onSlideIndexChange = vi.fn();
  beforeEach(() => onSlideIndexChange.mockReset());

  it("calls onSlideIndexChange when Next is clicked", async () => {
    render(<Carousel slides={slides} slideIndex={1} onSlideIndexChange={onSlideIndexChange} />);
    const user = userEvent.setup();

    await user.click(screen.getByTestId("next-button"));
    expect(onSlideIndexChange).toHaveBeenCalledWith(2);
  });
});
```

---

## ⏱️ タイマーテスト

### vi.useFakeTimers() + shouldAdvanceTime

```tsx
// test-setup.ts
vi.useFakeTimers();

// vite.config.ts
export default defineConfig({
  test: {
    fakeTimers: { shouldAdvanceTime: true }, // user-event互換性
  },
});
```

### vi.advanceTimersByTime() + act()

```tsx
import { act } from "@testing-library/react";

it("advances the slide according to autoAdvanceInterval", () => {
  const autoAdvanceInterval = 5_000;
  render(<Carousel slides={slides} autoAdvanceInterval={autoAdvanceInterval} />);
  const img = screen.getByRole("img");

  act(() => {
    vi.advanceTimersByTime(autoAdvanceInterval);
  });
  expect(img).toHaveAttribute("src", slides[1].imgUrl);

  act(() => {
    vi.advanceTimersByTime(autoAdvanceInterval);
  });
  expect(img).toHaveAttribute("src", slides[2].imgUrl);
});
```

**act() が必要な理由:**
- `vi.advanceTimersByTime()` は状態変更するがDOMを自動更新しない
- `user-event` は内部で `act()` 使用するため不要

### タイマーリセット防止テスト

```tsx
it("does not reset timer on re-render", () => {
  const autoAdvanceInterval = 5_000;
  const { rerender } = render(
    <Carousel slides={slides} autoAdvanceInterval={autoAdvanceInterval} />
  );
  const img = screen.getByRole("img");

  act(() => vi.advanceTimersByTime(autoAdvanceInterval - 1));

  rerender(<Carousel slides={slides} autoAdvanceInterval={autoAdvanceInterval} />);

  act(() => vi.advanceTimersByTime(1));
  expect(img).toHaveAttribute("src", slides[1].imgUrl);
});
```

---

## 🔄 レンダリング安定性テスト

### useCallback による関数の再生成防止

```tsx
import { useCallback } from "react";

const incrementSlideIndex = useCallback(() => {
  if (!slides?.length) return;
  setSlideIndexState((i) => (i + 1) % slides.length);
}, [slides?.length, slideIndex]);
```

**useCallback なしの問題:**
- 毎回新しい関数が生成
- `useEffect` 依存配列に含まれると無限ループ
- タイマーが意図せずリセット

### useRef によるコールバック参照の安定化

依存配列に含めずに最新値を参照:

```tsx
import { useRef } from "react";

const onSlideIndexChangeRef = useRef(onSlideIndexChange);
onSlideIndexChangeRef.current = onSlideIndexChange;

const incrementSlideIndex = useCallback(() => {
  if (!slides?.length) return;
  onSlideIndexChangeRef.current?.((slideIndex + 1) % slides.length);
}, [slides?.length, slideIndex]); // onSlideIndexChangeは含めない
```

### rerender() によるタイマーリセット検証

```tsx
it("does not reset timer on irrelevant prop changes", () => {
  const autoAdvanceInterval = 5_000;
  const CarouselParent = () => (
    <Carousel
      slides={[...slides]}  // 毎回新しい配列
      onSlideIndexChange={vi.fn()}
      autoAdvanceInterval={autoAdvanceInterval}
    />
  );
  const { rerender } = render(<CarouselParent />);

  act(() => vi.advanceTimersByTime(autoAdvanceInterval - 1));
  rerender(<CarouselParent />);
  act(() => vi.advanceTimersByTime(1));

  expect(screen.getByRole("img")).toHaveAttribute("src", slides[1].imgUrl);
});
```

### useEffect 依存配列の最適化

ESLint `react-hooks/exhaustive-deps` ルールで過不足を検出:

```tsx
// ❌ 警告あり
useEffect(() => {
  console.log(slideIndex);
}, []);

// ✅ 正しい
useEffect(() => {
  console.log(slideIndex);
}, [slideIndex]);

// ✅ 意図的に空配列の場合はコメント
useEffect(() => {
  // マウント時のみ実行
  initializeComponent();
  // eslint-disable-next-line react-hooks/exhaustive-deps
}, []);
```

**依存配列最適化テクニック:**
- プリミティブ値を含める（`slides?.length`）
- 関数は `useCallback` でメモ化
- 最新値が必要だが依存したくない場合は `useRef`
