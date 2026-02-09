# TypeScript × React 実践パターン

ReactをTypeScriptで使う際の実践的な型付けパターンとベストプラクティスを解説します。

---

## 1. ジェネリックコンポーネント

### 基本パターン

ジェネリクスを使うことで、型安全性を保ちながら再利用可能なコンポーネントを作成できます。

```typescript
interface ListProps<T> {
  items: T[];
  renderItem: (item: T) => React.ReactNode;
  keyExtractor: (item: T) => string;
}

function List<T>({ items, renderItem, keyExtractor }: ListProps<T>) {
  return (
    <ul>
      {items.map((item) => (
        <li key={keyExtractor(item)}>{renderItem(item)}</li>
      ))}
    </ul>
  );
}

// 使用例
interface User {
  id: string;
  name: string;
}

const users: User[] = [
  { id: "1", name: "Alice" },
  { id: "2", name: "Bob" },
];

<List
  items={users}
  renderItem={(user) => <span>{user.name}</span>}
  keyExtractor={(user) => user.id}
/>
```

### ジェネリックPaginationコンポーネント

```typescript
interface PaginationProps<T> {
  items: T[];
  pageSize: number;
  renderItem: (item: T) => React.ReactNode;
  keyExtractor: (item: T) => string;
}

function Pagination<T>({
  items,
  pageSize,
  renderItem,
  keyExtractor,
}: PaginationProps<T>) {
  const [currentPage, setCurrentPage] = useState(0);

  const pageCount = Math.ceil(items.length / pageSize);
  const currentItems = items.slice(
    currentPage * pageSize,
    (currentPage + 1) * pageSize
  );

  return (
    <div>
      <ul>
        {currentItems.map((item) => (
          <li key={keyExtractor(item)}>{renderItem(item)}</li>
        ))}
      </ul>
      <nav>
        <button
          disabled={currentPage === 0}
          onClick={() => setCurrentPage((p) => p - 1)}
        >
          前へ
        </button>
        <span>
          {currentPage + 1} / {pageCount}
        </span>
        <button
          disabled={currentPage === pageCount - 1}
          onClick={() => setCurrentPage((p) => p + 1)}
        >
          次へ
        </button>
      </nav>
    </div>
  );
}
```

### forwardRefとジェネリクスの組み合わせ

```typescript
interface InputProps<T> extends Omit<ComponentPropsWithoutRef<"input">, "value" | "onChange"> {
  value: T;
  onChange: (value: T) => void;
  parser: (raw: string) => T;
  formatter: (value: T) => string;
}

const Input = forwardRef(function Input<T>(
  { value, onChange, parser, formatter, ...props }: InputProps<T>,
  ref: ForwardedRef<HTMLInputElement>
) {
  return (
    <input
      {...props}
      ref={ref}
      value={formatter(value)}
      onChange={(e) => onChange(parser(e.target.value))}
    />
  );
}) as <T>(props: InputProps<T> & { ref?: ForwardedRef<HTMLInputElement> }) => ReactElement;

// 使用例: 数値入力
<Input
  value={count}
  onChange={setCount}
  parser={(s) => parseInt(s, 10) || 0}
  formatter={(n) => n.toString()}
/>
```

---

## 2. React Hook型付けパターン

### useState

```typescript
// 基本: 初期値から型推論
const [count, setCount] = useState(0); // number

// 明示的な型指定（Union型や複雑な型の場合）
const [user, setUser] = useState<User | null>(null);

// 配列の場合
const [items, setItems] = useState<string[]>([]);
```

### useRef

```typescript
// DOM参照（初期値null必須）
const inputRef = useRef<HTMLInputElement>(null);

useEffect(() => {
  inputRef.current?.focus(); // Optional chaining必須
}, []);

// 値保持（ミュータブル）
const timerRef = useRef<number | null>(null);

timerRef.current = window.setTimeout(() => {
  // ...
}, 1000);
```

### useContext

```typescript
interface ThemeContextValue {
  theme: "light" | "dark";
  toggleTheme: () => void;
}

const ThemeContext = createContext<ThemeContextValue | undefined>(undefined);

function useTheme() {
  const context = useContext(ThemeContext);
  if (!context) {
    throw new Error("useTheme must be used within ThemeProvider");
  }
  return context;
}

// Provider
function ThemeProvider({ children }: PropsWithChildren) {
  const [theme, setTheme] = useState<"light" | "dark">("light");

  const toggleTheme = () => {
    setTheme((prev) => (prev === "light" ? "dark" : "light"));
  };

  return (
    <ThemeContext.Provider value={{ theme, toggleTheme }}>
      {children}
    </ThemeContext.Provider>
  );
}
```

### useReducer（Discriminated Union）

```typescript
type State<T> = T[];

type Action<T> =
  | { type: "add"; item: T }
  | { type: "remove"; index: number }
  | { type: "moveUp"; index: number }
  | { type: "moveDown"; index: number }
  | { type: "reset"; items: T[] };

function reorder<T>(state: State<T>, action: Action<T>): State<T> {
  switch (action.type) {
    case "add":
      return [...state, action.item];
    case "remove":
      return state.filter((_, i) => i !== action.index);
    case "moveUp":
      if (action.index === 0) return state;
      const newStateUp = [...state];
      [newStateUp[action.index - 1], newStateUp[action.index]] = [
        newStateUp[action.index],
        newStateUp[action.index - 1],
      ];
      return newStateUp;
    case "moveDown":
      if (action.index === state.length - 1) return state;
      const newStateDown = [...state];
      [newStateDown[action.index], newStateDown[action.index + 1]] = [
        newStateDown[action.index + 1],
        newStateDown[action.index],
      ];
      return newStateDown;
    case "reset":
      return action.items;
  }
}

function useReorderable<T>(initial: State<T>) {
  const [state, dispatch] = useReducer<Reducer<State<T>, Action<T>>>(
    reorder,
    initial
  );

  const add = (item: T) => dispatch({ type: "add", item });
  const remove = (index: number) => dispatch({ type: "remove", index });
  const moveUp = (index: number) => dispatch({ type: "moveUp", index });
  const moveDown = (index: number) => dispatch({ type: "moveDown", index });
  const reset = (items: T[]) => dispatch({ type: "reset", items });

  return { list: state, add, remove, moveUp, moveDown, reset };
}
```

### useMemo / useCallback

```typescript
// useMemoは戻り値の型が自動推論される
const sortedItems = useMemo(() => {
  return items.sort((a, b) => a.name.localeCompare(b.name));
}, [items]); // sortedItems: Item[]

// useCallbackも引数と戻り値が自動推論される
const handleClick = useCallback((id: string) => {
  console.log(`Clicked: ${id}`);
}, []); // handleClick: (id: string) => void

// 明示的な型指定が必要な場合
const fetchData = useCallback<(id: number) => Promise<Data>>(
  async (id) => {
    const response = await fetch(`/api/data/${id}`);
    return response.json();
  },
  []
);
```

---

## 3. 高度な型パターン

### Discriminated Unions（判別可能な共用体型）

プロパティの値によって型を分岐させるパターン。

```typescript
interface ProductCardSaleProps {
  productName: string;
  price: number;
  isOnSale: true;
  salePrice: number;
  saleExpiry: string;
}

interface ProductCardNoSaleProps {
  productName: string;
  price: number;
  isOnSale: false;
}

type ProductCardProps = ProductCardSaleProps | ProductCardNoSaleProps;

function ProductCard(props: ProductCardProps) {
  return (
    <div>
      <h2>{props.productName}</h2>
      <p>通常価格: ¥{props.price}</p>
      {props.isOnSale && (
        <>
          <p>セール価格: ¥{props.salePrice}</p>
          <p>期限: {props.saleExpiry}</p>
        </>
      )}
    </div>
  );
}

// 使用例
<ProductCard
  productName="商品A"
  price={1000}
  isOnSale={true}
  salePrice={800}
  saleExpiry="2025-12-31"
/>

<ProductCard
  productName="商品B"
  price={2000}
  isOnSale={false}
  // salePrice, saleExpiryは不要（型エラーになる）
/>
```

### ComponentPropsWithoutRef（HTML要素の拡張）

既存のHTML要素やコンポーネントのpropsを拡張する。

```typescript
// img要素の拡張（altを除外して独自実装）
interface UserImageProps extends Omit<ComponentPropsWithoutRef<"img">, "alt"> {
  name: string;
  title: string;
}

function UserImage({ name, title, ...imgProps }: UserImageProps) {
  return (
    <div>
      <img {...imgProps} alt={`${name}, ${title}`} />
      <p>
        {name} - {title}
      </p>
    </div>
  );
}

// button要素の拡張
interface PrimaryButtonProps extends ComponentPropsWithoutRef<"button"> {
  variant?: "solid" | "outline";
}

function PrimaryButton({ variant = "solid", children, className, ...props }: PrimaryButtonProps) {
  const variantClass = variant === "solid" ? "btn-solid" : "btn-outline";
  return (
    <button {...props} className={`btn ${variantClass} ${className || ""}`}>
      {children}
    </button>
  );
}
```

### Pick / Omit（部分型の作成）

既存の型から必要なプロパティのみを選択・除外する。

```typescript
// Ratingコンポーネントがあると仮定
type RatingProps = ComponentPropsWithoutRef<typeof Rating>;

// Ratingのpropsから一部だけ受け取る
interface BookReviewProps extends Pick<RatingProps, "value" | "icon"> {
  title: string;
  reviewer: string;
  comment: string;
}

function BookReview({ title, reviewer, comment, value, icon }: BookReviewProps) {
  return (
    <article>
      <h3>{title}</h3>
      <Rating value={value} icon={icon} />
      <p>{comment}</p>
      <footer>レビュアー: {reviewer}</footer>
    </article>
  );
}

// Omitの例: 特定のpropsを除外
interface CustomInputProps extends Omit<ComponentPropsWithoutRef<"input">, "type" | "onChange"> {
  onValueChange: (value: string) => void;
}

function CustomInput({ onValueChange, ...props }: CustomInputProps) {
  return (
    <input
      {...props}
      type="text"
      onChange={(e) => onValueChange(e.target.value)}
    />
  );
}
```

---

## 4. PropsWithChildrenとchildren型付け

### PropsWithChildren（標準パターン）

```typescript
import { PropsWithChildren } from "react";

interface CardProps {
  title: string;
  variant?: "default" | "outlined";
}

// PropsWithChildrenを使うと自動的にchildren: ReactNodeが追加される
function Card({ title, variant = "default", children }: PropsWithChildren<CardProps>) {
  return (
    <div className={`card card-${variant}`}>
      <h2>{title}</h2>
      <div className="card-body">{children}</div>
    </div>
  );
}
```

### childrenの制約（特定のコンポーネント型のみ受け入れ）

```typescript
interface TabsProps {
  children: ReactElement<TabProps> | ReactElement<TabProps>[];
}

function Tabs({ children }: TabsProps) {
  const [activeIndex, setActiveIndex] = useState(0);

  const tabs = React.Children.toArray(children) as ReactElement<TabProps>[];

  return (
    <div>
      <nav>
        {tabs.map((tab, index) => (
          <button
            key={index}
            onClick={() => setActiveIndex(index)}
            aria-selected={index === activeIndex}
          >
            {tab.props.label}
          </button>
        ))}
      </nav>
      <div>{tabs[activeIndex]}</div>
    </div>
  );
}

interface TabProps {
  label: string;
  children: ReactNode;
}

function Tab({ children }: TabProps) {
  return <div>{children}</div>;
}

// 使用例
<Tabs>
  <Tab label="タブ1">コンテンツ1</Tab>
  <Tab label="タブ2">コンテンツ2</Tab>
</Tabs>
```

### render propsパターン

```typescript
interface DataFetcherProps<T> {
  url: string;
  children: (data: T | null, loading: boolean, error: Error | null) => ReactNode;
}

function DataFetcher<T>({ url, children }: DataFetcherProps<T>) {
  const [data, setData] = useState<T | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    fetch(url)
      .then((res) => res.json())
      .then((data) => {
        setData(data);
        setLoading(false);
      })
      .catch((err) => {
        setError(err);
        setLoading(false);
      });
  }, [url]);

  return <>{children(data, loading, error)}</>;
}

// 使用例
<DataFetcher<User> url="/api/user/1">
  {(user, loading, error) => {
    if (loading) return <p>読み込み中...</p>;
    if (error) return <p>エラー: {error.message}</p>;
    if (!user) return <p>ユーザーが見つかりません</p>;
    return <p>{user.name}</p>;
  }}
</DataFetcher>
```

---

## 5. 型安全なrefフォワーディング

### forwardRefの型パラメータ

```typescript
interface CustomInputProps extends ComponentPropsWithoutRef<"input"> {
  label: string;
  error?: string;
}

// forwardRef<要素の型, Propsの型>
const CustomInput = forwardRef<HTMLInputElement, CustomInputProps>(
  function CustomInput({ label, error, ...props }, ref) {
    return (
      <div>
        <label>
          {label}
          <input ref={ref} {...props} aria-invalid={!!error} />
        </label>
        {error && <span className="error">{error}</span>}
      </div>
    );
  }
);

// 使用例
function Form() {
  const inputRef = useRef<HTMLInputElement>(null);

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault();
    inputRef.current?.focus();
  };

  return (
    <form onSubmit={handleSubmit}>
      <CustomInput ref={inputRef} label="ユーザー名" />
      <button type="submit">送信</button>
    </form>
  );
}
```

### ジェネリックコンポーネント + forwardRef

```typescript
interface SelectProps<T> extends Omit<ComponentPropsWithoutRef<"select">, "value" | "onChange"> {
  options: T[];
  value: T;
  onChange: (value: T) => void;
  getOptionLabel: (option: T) => string;
  getOptionValue: (option: T) => string;
}

const Select = forwardRef(function Select<T>(
  { options, value, onChange, getOptionLabel, getOptionValue, ...props }: SelectProps<T>,
  ref: ForwardedRef<HTMLSelectElement>
) {
  return (
    <select
      {...props}
      ref={ref}
      value={getOptionValue(value)}
      onChange={(e) => {
        const selectedOption = options.find(
          (opt) => getOptionValue(opt) === e.target.value
        );
        if (selectedOption) onChange(selectedOption);
      }}
    >
      {options.map((option) => (
        <option key={getOptionValue(option)} value={getOptionValue(option)}>
          {getOptionLabel(option)}
        </option>
      ))}
    </select>
  );
}) as <T>(props: SelectProps<T> & { ref?: ForwardedRef<HTMLSelectElement> }) => ReactElement;
```

### React 19のref as prop

React 19以降では、forwardRefを使わずに直接refをpropsとして受け取れます。

```typescript
interface CustomButtonProps extends ComponentPropsWithoutRef<"button"> {
  variant: "primary" | "secondary";
}

function CustomButton({ variant, ref, ...props }: CustomButtonProps) {
  return (
    <button
      ref={ref}
      className={`btn btn-${variant}`}
      {...props}
    />
  );
}

// 使用例（forwardRef不要）
const buttonRef = useRef<HTMLButtonElement>(null);
<CustomButton ref={buttonRef} variant="primary">クリック</CustomButton>
```

---

## 6. TypeScript導入の判断基準

### メリット

1. **型安全性**: 実行前にバグを検出
2. **IDE支援**: 自動補完、リファクタリング、ドキュメント表示
3. **リファクタリング容易**: 型エラーで影響箇所を即座に把握
4. **ドキュメント効果**: 型定義がインターフェース仕様書として機能
5. **チーム開発**: 暗黙の仕様を型で明示化

### デメリット

1. **学習コスト**: ジェネリクス、Utility Types、高度な型推論の習得が必要
2. **ビルド時間増**: 型チェックによるビルド時間の増加
3. **複雑な型のデバッグ困難**: エラーメッセージが難解な場合がある
4. **ボイラープレート増**: 型定義のコード量増加
5. **外部ライブラリの型定義**: `@types/*`パッケージが不完全な場合の対応

### 判断基準

**TypeScript推奨:**
- 中〜大規模プロジェクト（10,000行以上）
- 複数人での長期開発
- 複雑なビジネスロジック・状態管理
- APIレスポンスの型安全性が重要
- リファクタリング頻度が高い

**JavaScript継続検討:**
- 小規模プロジェクト（1,000行未満）
- プロトタイプ・PoC段階
- チーム全体のTypeScriptスキルが不足
- 高速な開発スピード重視（スタートアップ初期等）

**段階的導入のアプローチ:**
1. JSDocでの型コメント記述
2. `allowJs: true`で既存JSと共存
3. 重要なモジュールから順次`.ts`化
4. `strict: true`へ段階的に移行
