# 生成パターン（Creational Patterns）

## パターン選択ガイド

| パターン | 目的 | 使用条件 |
|---------|------|---------|
| **Singleton** | 単一インスタンス保証 | グローバルな状態管理、DB接続プール、ロガー等 |
| **Prototype** | オブジェクトのクローン作成 | 既存オブジェクトのコピーが必要、複雑な初期化の回避 |
| **Builder** | 複雑なオブジェクトの段階的構築 | 多数のパラメータ、オプション設定、可読性向上 |
| **Factory Method** | サブクラスでインスタンス生成決定 | 実行時の型決定、抽象化された生成ロジック |
| **Abstract Factory** | 関連オブジェクト群の生成 | プラットフォーム/テーマ別のファミリー生成 |

---

## 1. Singleton パターン

### 目的
クラスのインスタンスが1つだけ存在することを保証し、グローバルなアクセスポイントを提供する。

### 使用場面

| 場面 | 具体例 |
|-----|--------|
| グローバル状態管理 | アプリケーション設定、環境変数 |
| 共有リソース制御 | DB接続プール、ファイルシステムアクセス |
| キャッシュ層 | データキャッシュの一元管理 |
| ロギング・エラーハンドリング | 集中ログ管理 |
| オブジェクトプール | スレッドプール、コネクションプール |

**判断基準**:
- ✅ 単一インスタンスが必須（DB接続マネージャー等）
- ✅ グローバルアクセスが必要
- ❌ 複数インスタンスが必要な場合は使用しない
- ❌ 疎結合が優先される場合は DI/IoC を検討

### TypeScript実装

#### Classic実装
```typescript
class UserService {
  private static instance: UserService;
  private users: Map<string, User>;

  // コンストラクタをprivateに
  private constructor() {
    this.users = new Map();
  }

  // 単一アクセスポイント
  static getInstance(): UserService {
    if (!UserService.instance) {
      UserService.instance = new UserService();
    }
    return UserService.instance;
  }

  addUser(user: User): void {
    this.users.set(user.id, user);
  }

  getUser(id: string): User | undefined {
    return this.users.get(id);
  }
}

// 使用例
const service1 = UserService.getInstance();
const service2 = UserService.getInstance();
console.log(service1 === service2); // true
```

#### Modern実装（ES Module）
```typescript
// logger.ts
class Logger {
  private logs: string[] = [];

  log(message: string): void {
    const timestamp = new Date().toISOString();
    this.logs.push(`[${timestamp}] ${message}`);
    console.log(`[${timestamp}] ${message}`);
  }

  getLogs(): readonly string[] {
    return this.logs;
  }
}

// モジュールスコープで単一インスタンスを生成
export const logger = new Logger();
```

```typescript
// 使用側
import { logger } from './logger';

logger.log('Application started');
logger.log('Processing request');
```

#### Thread-safe実装（Node.js Worker Threads対応）
```typescript
class DatabaseConnection {
  private static instance: DatabaseConnection | null = null;
  private static lock = false;
  private connection: any;

  private constructor() {
    // 重い初期化処理をシミュレート
    this.connection = this.initializeConnection();
  }

  static async getInstance(): Promise<DatabaseConnection> {
    if (!DatabaseConnection.instance) {
      // ダブルチェックロッキング
      while (DatabaseConnection.lock) {
        await new Promise(resolve => setTimeout(resolve, 10));
      }

      if (!DatabaseConnection.instance) {
        DatabaseConnection.lock = true;
        try {
          DatabaseConnection.instance = new DatabaseConnection();
        } finally {
          DatabaseConnection.lock = false;
        }
      }
    }
    return DatabaseConnection.instance;
  }

  private initializeConnection(): any {
    // DB接続初期化ロジック
    return { connected: true };
  }

  query(sql: string): any {
    return this.connection;
  }
}
```

### テスト考慮事項
- **問題点**: グローバル状態のため、テスト間で状態が漏れる
- **対策1**: リセットメソッドの提供
  ```typescript
  class Singleton {
    static resetInstance(): void {
      Singleton.instance = null;
    }
  }
  ```
- **対策2**: Dependency Injection を使用
  ```typescript
  class UserController {
    constructor(private userService: UserService) {}
  }
  // テスト時はモックインスタンスを注入
  ```

### 注意点/批判

#### アンチパターン化のリスク
- **グローバル変数の濫用**: 隠れた依存関係を作る
- **テスタビリティ低下**: モック化が困難
- **密結合**: コンポーネント間の結合度が上がる

#### 代替案検討
```typescript
// ❌ Singleton濫用
class Config {
  private static instance: Config;
  // ...
}

// ✅ DI/IoC推奨
interface IConfig {
  get(key: string): string;
}

class Config implements IConfig {
  get(key: string): string {
    return process.env[key] || '';
  }
}

// DIコンテナで管理
container.register('config', Config, { lifecycle: Lifecycle.Singleton });
```

### 実世界の適用例

#### Node.js Express
```typescript
import express from 'express';

// express() は Singleton ではないが、app インスタンスは通常1つ
const app = express();

// アプリケーション全体で共有される設定
app.set('view engine', 'ejs');
```

#### React Context（概念的類似）
```typescript
// Context は Singleton 的に動作
const ThemeContext = React.createContext<Theme>(defaultTheme);

export const useTheme = () => useContext(ThemeContext);
```

#### TypeScript Compiler API
```typescript
// ts.createProgram は内部で Singleton 的なキャッシュを持つ
const program = ts.createProgram(fileNames, options);
```

---

## 2. Prototype パターン

### 目的
既存オブジェクトをテンプレートとして、新しいオブジェクトを複製（クローン）することで生成する。

### 使用場面

| 場面 | 具体例 |
|-----|--------|
| 複雑な初期化の回避 | 設定済みオブジェクトの再利用 |
| パフォーマンス最適化 | 重い初期化処理のスキップ |
| 動的型生成 | 実行時に決まる型のクローン |
| 履歴・Undo機能 | 状態のスナップショット保存 |

### TypeScript実装

#### Classic実装
```typescript
interface Prototype<T> {
  clone(): T;
}

class ConcretePrototype implements Prototype<ConcretePrototype> {
  constructor(
    public field1: string,
    public field2: number,
    public complexObject: { data: string[] }
  ) {}

  clone(): ConcretePrototype {
    // Shallow copy
    return Object.create(this);
  }

  deepClone(): ConcretePrototype {
    // Deep copy
    return new ConcretePrototype(
      this.field1,
      this.field2,
      { data: [...this.complexObject.data] }
    );
  }
}

// 使用例
const original = new ConcretePrototype('test', 42, { data: ['a', 'b'] });
const shallowCopy = original.clone();
const deepCopy = original.deepClone();
```

#### Modern実装（Structured Clone API）
```typescript
class Document {
  constructor(
    public title: string,
    public content: string,
    public metadata: Map<string, any>,
    public createdAt: Date
  ) {}

  clone(): Document {
    // structuredClone は Map, Date, Set 等をサポート
    const cloned = structuredClone({
      title: this.title,
      content: this.content,
      metadata: this.metadata,
      createdAt: this.createdAt
    });

    return new Document(
      cloned.title,
      cloned.content,
      cloned.metadata,
      cloned.createdAt
    );
  }
}
```

#### Registry Pattern との組み合わせ
```typescript
class PrototypeRegistry<T extends Prototype<T>> {
  private prototypes = new Map<string, T>();

  register(key: string, prototype: T): void {
    this.prototypes.set(key, prototype);
  }

  create(key: string): T | undefined {
    const prototype = this.prototypes.get(key);
    return prototype?.clone();
  }
}

// 使用例
const registry = new PrototypeRegistry<ConcretePrototype>();
registry.register('default', new ConcretePrototype('default', 0, { data: [] }));

const instance1 = registry.create('default');
const instance2 = registry.create('default');
// instance1 と instance2 は異なるインスタンス
```

### テスト考慮事項
- **Deep vs Shallow Clone の検証**
  ```typescript
  test('deep clone creates independent copy', () => {
    const original = new Document('Test', 'Content', new Map([['key', 'value']]), new Date());
    const cloned = original.clone();

    cloned.metadata.set('key', 'modified');
    expect(original.metadata.get('key')).toBe('value'); // 元は変更されない
  });
  ```

### 注意点/批判
- **循環参照の問題**: Deep clone 時に無限ループの危険
- **パフォーマンス**: 大きなオブジェクトのcloneはコスト高
- **代替案**: Immutable データ構造（Immer.js, Immutable.js）の検討

### 実世界の適用例
```typescript
// React における状態のクローン
const [state, setState] = useState(initialState);

// 新しい状態を作成（クローン + 変更）
setState(prevState => ({ ...prevState, newField: 'value' }));

// Immer.js を使った簡潔な実装
import produce from 'immer';

const nextState = produce(state, draft => {
  draft.newField = 'value';
});
```

---

## 3. Builder パターン

### 目的
複雑なオブジェクトの構築プロセスをステップバイステップで行い、同じ構築プロセスで異なる表現を作成可能にする。

### 使用場面

| 場面 | 具体例 |
|-----|--------|
| 多数のパラメータ | 10個以上のコンストラクタ引数 |
| オプション設定 | デフォルト値と必須値の混在 |
| 可読性向上 | メソッドチェーンで意図を明確化 |
| 不変オブジェクト構築 | ビルド完了後は変更不可 |

### TypeScript実装

#### Classic実装
```typescript
class Product {
  constructor(
    public readonly name: string,
    public readonly price: number,
    public readonly description?: string,
    public readonly category?: string,
    public readonly tags?: string[],
    public readonly images?: string[]
  ) {}
}

class ProductBuilder {
  private name!: string;
  private price!: number;
  private description?: string;
  private category?: string;
  private tags: string[] = [];
  private images: string[] = [];

  setName(name: string): this {
    this.name = name;
    return this;
  }

  setPrice(price: number): this {
    if (price < 0) throw new Error('Price must be positive');
    this.price = price;
    return this;
  }

  setDescription(description: string): this {
    this.description = description;
    return this;
  }

  setCategory(category: string): this {
    this.category = category;
    return this;
  }

  addTag(tag: string): this {
    this.tags.push(tag);
    return this;
  }

  addImage(url: string): this {
    this.images.push(url);
    return this;
  }

  build(): Product {
    if (!this.name || this.price === undefined) {
      throw new Error('Name and price are required');
    }

    return new Product(
      this.name,
      this.price,
      this.description,
      this.category,
      this.tags.length > 0 ? this.tags : undefined,
      this.images.length > 0 ? this.images : undefined
    );
  }
}

// 使用例
const product = new ProductBuilder()
  .setName('Laptop')
  .setPrice(1299.99)
  .setDescription('High-performance laptop')
  .setCategory('Electronics')
  .addTag('computer')
  .addTag('portable')
  .addImage('https://example.com/laptop.jpg')
  .build();
```

#### Modern実装（Type-safe Builder）
```typescript
type RequiredKeys = 'name' | 'price';
type OptionalKeys = 'description' | 'category' | 'tags' | 'images';

type BuilderState<T extends Record<string, any>> = {
  [K in keyof T]?: T[K];
};

class TypeSafeProductBuilder<
  R extends RequiredKeys = never
> {
  private state: BuilderState<Product> = {};

  setName(name: string): TypeSafeProductBuilder<R | 'name'> {
    this.state.name = name;
    return this as any;
  }

  setPrice(price: number): TypeSafeProductBuilder<R | 'price'> {
    this.state.price = price;
    return this as any;
  }

  setDescription(description: string): this {
    this.state.description = description;
    return this;
  }

  // build は全ての必須フィールドが設定された時のみ呼び出し可能
  build(this: TypeSafeProductBuilder<RequiredKeys>): Product {
    return new Product(
      this.state.name!,
      this.state.price!,
      this.state.description,
      this.state.category,
      this.state.tags,
      this.state.images
    );
  }
}

// 使用例
const builder = new TypeSafeProductBuilder();
// builder.build(); // コンパイルエラー: name, price が未設定

const validProduct = new TypeSafeProductBuilder()
  .setName('Laptop')
  .setPrice(1299)
  .build(); // OK
```

#### Fluent Interface with Director
```typescript
interface HouseBuilder {
  buildFoundation(): this;
  buildWalls(): this;
  buildRoof(): this;
  buildGarden(): this;
  getHouse(): House;
}

class House {
  parts: string[] = [];

  addPart(part: string): void {
    this.parts.push(part);
  }
}

class ModernHouseBuilder implements HouseBuilder {
  private house = new House();

  buildFoundation(): this {
    this.house.addPart('Modern foundation');
    return this;
  }

  buildWalls(): this {
    this.house.addPart('Glass walls');
    return this;
  }

  buildRoof(): this {
    this.house.addPart('Flat roof');
    return this;
  }

  buildGarden(): this {
    this.house.addPart('Zen garden');
    return this;
  }

  getHouse(): House {
    return this.house;
  }
}

// Director: 構築手順を管理
class ConstructionDirector {
  construct(builder: HouseBuilder): House {
    return builder
      .buildFoundation()
      .buildWalls()
      .buildRoof()
      .buildGarden()
      .getHouse();
  }
}

// 使用例
const director = new ConstructionDirector();
const modernBuilder = new ModernHouseBuilder();
const modernHouse = director.construct(modernBuilder);
```

### テスト考慮事項
```typescript
describe('ProductBuilder', () => {
  it('should enforce required fields', () => {
    const builder = new ProductBuilder();
    expect(() => builder.build()).toThrow('Name and price are required');
  });

  it('should validate price', () => {
    const builder = new ProductBuilder().setName('Test');
    expect(() => builder.setPrice(-10)).toThrow('Price must be positive');
  });

  it('should create product with all fields', () => {
    const product = new ProductBuilder()
      .setName('Laptop')
      .setPrice(1299)
      .setDescription('Test')
      .build();

    expect(product.name).toBe('Laptop');
    expect(product.price).toBe(1299);
  });
});
```

### 注意点/批判
- **Boilerplate コードの増加**: 小規模オブジェクトには過剰
- **代替案**: TypeScript の Optional Parameters や Partial Type の活用

```typescript
// シンプルな代替案
type ProductOptions = Partial<Omit<Product, 'name' | 'price'>>;

function createProduct(
  name: string,
  price: number,
  options?: ProductOptions
): Product {
  return new Product(name, price, options?.description, options?.category);
}
```

### 実世界の適用例
```typescript
// Jest test builder
const mockUser = jest.fn()
  .mockReturnValueOnce({ id: 1, name: 'Alice' })
  .mockReturnValueOnce({ id: 2, name: 'Bob' });

// Prisma Client
const user = await prisma.user.create({
  data: {
    email: 'alice@example.com',
    posts: {
      create: [
        { title: 'Post 1' },
        { title: 'Post 2' }
      ]
    }
  }
});

// TypeORM Query Builder
const users = await dataSource
  .getRepository(User)
  .createQueryBuilder('user')
  .where('user.age > :age', { age: 18 })
  .orderBy('user.name', 'ASC')
  .getMany();
```

---

## 4. Factory Method パターン

### 目的
オブジェクト生成のインターフェースを定義し、どのクラスをインスタンス化するかはサブクラスに委ねる。

### 使用場面

| 場面 | 具体例 |
|-----|--------|
| 実行時の型決定 | ユーザー入力に応じたオブジェクト生成 |
| プラグイン機構 | 動的なクラスローディング |
| テスト容易性向上 | モックオブジェクトへの差し替え |
| フレームワーク設計 | ライブラリ利用者がカスタム実装提供 |

### TypeScript実装

#### Classic実装
```typescript
// Product インターフェース
interface Logger {
  log(message: string): void;
}

// Concrete Products
class ConsoleLogger implements Logger {
  log(message: string): void {
    console.log(`[Console] ${message}`);
  }
}

class FileLogger implements Logger {
  constructor(private filePath: string) {}

  log(message: string): void {
    // ファイルに書き込むロジック
    console.log(`[File: ${this.filePath}] ${message}`);
  }
}

class RemoteLogger implements Logger {
  constructor(private endpoint: string) {}

  log(message: string): void {
    // リモートサーバーに送信するロジック
    console.log(`[Remote: ${this.endpoint}] ${message}`);
  }
}

// Creator 抽象クラス
abstract class Application {
  abstract createLogger(): Logger;

  run(): void {
    const logger = this.createLogger();
    logger.log('Application started');
    // ビジネスロジック
    logger.log('Processing...');
    logger.log('Application finished');
  }
}

// Concrete Creators
class DevelopmentApp extends Application {
  createLogger(): Logger {
    return new ConsoleLogger();
  }
}

class ProductionApp extends Application {
  createLogger(): Logger {
    return new FileLogger('/var/log/app.log');
  }
}

class CloudApp extends Application {
  createLogger(): Logger {
    return new RemoteLogger('https://logging.example.com/api');
  }
}

// 使用例
const env = process.env.NODE_ENV;
let app: Application;

if (env === 'production') {
  app = new ProductionApp();
} else if (env === 'cloud') {
  app = new CloudApp();
} else {
  app = new DevelopmentApp();
}

app.run();
```

#### Modern実装（関数型アプローチ）
```typescript
type LoggerFactory = () => Logger;

const createConsoleLogger: LoggerFactory = () => new ConsoleLogger();
const createFileLogger = (filePath: string): LoggerFactory =>
  () => new FileLogger(filePath);
const createRemoteLogger = (endpoint: string): LoggerFactory =>
  () => new RemoteLogger(endpoint);

// Registry Pattern との組み合わせ
class LoggerFactoryRegistry {
  private factories = new Map<string, LoggerFactory>();

  register(key: string, factory: LoggerFactory): void {
    this.factories.set(key, factory);
  }

  create(key: string): Logger {
    const factory = this.factories.get(key);
    if (!factory) {
      throw new Error(`No factory registered for key: ${key}`);
    }
    return factory();
  }
}

// 使用例
const registry = new LoggerFactoryRegistry();
registry.register('console', createConsoleLogger);
registry.register('file', createFileLogger('/var/log/app.log'));
registry.register('remote', createRemoteLogger('https://api.example.com'));

const logger = registry.create(process.env.LOGGER_TYPE || 'console');
logger.log('Message');
```

### テスト考慮事項
```typescript
class TestApp extends Application {
  createLogger(): Logger {
    return {
      log: jest.fn()
    };
  }
}

describe('Application', () => {
  it('should use injected logger', () => {
    const app = new TestApp();
    const logger = app.createLogger();

    app.run();

    expect(logger.log).toHaveBeenCalledWith('Application started');
  });
});
```

### 注意点/批判
- **過度な抽象化**: シンプルなケースでは不要
- **代替案**: DI コンテナの使用

### 実世界の適用例
```typescript
// React.createElement
const element = React.createElement('div', { className: 'container' }, 'Hello');

// Express.js ミドルウェア
app.use((req, res, next) => {
  // ファクトリーメソッドでロガーを生成
  req.logger = createLogger(req.headers['x-request-id']);
  next();
});
```

---

## 5. Abstract Factory パターン

### 目的
関連するオブジェクトのファミリーを、具体的なクラスを指定せずに生成するインターフェースを提供する。

### 使用場面

| 場面 | 具体例 |
|-----|--------|
| プラットフォーム別UI | Windows/Mac/Linux 向けコンポーネント |
| テーマシステム | Light/Dark テーマのUI要素群 |
| データベース抽象化 | MySQL/PostgreSQL/MongoDB クライアント |
| 複数プロダクトファミリー | 同一カテゴリの異なるブランド商品 |

### TypeScript実装

```typescript
// Abstract Products
interface Button {
  render(): void;
  onClick(handler: () => void): void;
}

interface Checkbox {
  render(): void;
  onCheck(handler: (checked: boolean) => void): void;
}

// Concrete Products - Windows
class WindowsButton implements Button {
  render(): void {
    console.log('Rendering Windows button');
  }
  onClick(handler: () => void): void {
    console.log('Windows button clicked');
    handler();
  }
}

class WindowsCheckbox implements Checkbox {
  render(): void {
    console.log('Rendering Windows checkbox');
  }
  onCheck(handler: (checked: boolean) => void): void {
    console.log('Windows checkbox checked');
    handler(true);
  }
}

// Concrete Products - MacOS
class MacButton implements Button {
  render(): void {
    console.log('Rendering Mac button');
  }
  onClick(handler: () => void): void {
    console.log('Mac button clicked');
    handler();
  }
}

class MacCheckbox implements Checkbox {
  render(): void {
    console.log('Rendering Mac checkbox');
  }
  onCheck(handler: (checked: boolean) => void): void {
    console.log('Mac checkbox checked');
    handler(true);
  }
}

// Abstract Factory
interface GUIFactory {
  createButton(): Button;
  createCheckbox(): Checkbox;
}

// Concrete Factories
class WindowsFactory implements GUIFactory {
  createButton(): Button {
    return new WindowsButton();
  }
  createCheckbox(): Checkbox {
    return new WindowsCheckbox();
  }
}

class MacFactory implements GUIFactory {
  createButton(): Button {
    return new MacButton();
  }
  createCheckbox(): Checkbox {
    return new MacCheckbox();
  }
}

// Client Code
class Application {
  private button: Button;
  private checkbox: Checkbox;

  constructor(factory: GUIFactory) {
    this.button = factory.createButton();
    this.checkbox = factory.createCheckbox();
  }

  render(): void {
    this.button.render();
    this.checkbox.render();
  }
}

// 使用例
const platform = process.platform;
let factory: GUIFactory;

if (platform === 'darwin') {
  factory = new MacFactory();
} else {
  factory = new WindowsFactory();
}

const app = new Application(factory);
app.render();
```

### テスト考慮事項
```typescript
class MockFactory implements GUIFactory {
  createButton(): Button {
    return { render: jest.fn(), onClick: jest.fn() };
  }
  createCheckbox(): Checkbox {
    return { render: jest.fn(), onCheck: jest.fn() };
  }
}

describe('Application', () => {
  it('should render components from factory', () => {
    const factory = new MockFactory();
    const app = new Application(factory);

    app.render();

    expect(factory.createButton().render).toHaveBeenCalled();
  });
});
```

### 注意点/批判
- **複雑性の増加**: 小規模システムには過剰
- **拡張性**: 新しいプロダクト追加時に全ファクトリーを変更

### 実世界の適用例
```typescript
// Material-UI テーマシステム
import { createTheme, ThemeProvider } from '@mui/material/styles';

const lightTheme = createTheme({ palette: { mode: 'light' } });
const darkTheme = createTheme({ palette: { mode: 'dark' } });

<ThemeProvider theme={userPrefersDark ? darkTheme : lightTheme}>
  <App />
</ThemeProvider>

// TypeORM データソース
import { DataSource } from 'typeorm';

const createDataSource = (type: 'mysql' | 'postgres'): DataSource => {
  if (type === 'mysql') {
    return new DataSource({ type: 'mysql', /* ... */ });
  } else {
    return new DataSource({ type: 'postgres', /* ... */ });
  }
};
```
