# 構造パターン（Structural Patterns）

## パターン選択ガイド

| パターン | 目的 | 使用条件 |
|---------|------|---------|
| **Adapter** | インターフェース変換 | 互換性のないインターフェースの統合、レガシーコード連携 |
| **Decorator** | 動的な機能追加 | オブジェクトに責務を柔軟に追加、サブクラス爆発の回避 |
| **Façade** | シンプルなインターフェース提供 | 複雑なサブシステムの簡素化、疎結合化 |
| **Composite** | ツリー構造の統一扱い | 階層構造、部分と全体の統一インターフェース |
| **Proxy** | オブジェクトへの間接アクセス | 遅延初期化、アクセス制御、ログ記録 |
| **Bridge** | 抽象と実装の分離 | 複数の次元で変化する構造、実装の切り替え |
| **Flyweight** | メモリ効率化 | 大量の細粒度オブジェクト、共有可能な状態 |

---

## 1. Adapter パターン

### 目的
互換性のないインターフェース間の橋渡しを行い、既存のコードを変更せずに統合を実現する。

### 使用場面

| 場面 | 具体例 |
|-----|--------|
| インターフェース不一致解決 | クライアントが期待する型Aと実装型Bの差異吸収 |
| レガシーコード統合 | 旧システムやサードパーティライブラリの連携 |
| 相互運用性向上 | 異なるクラスを統一インターフェースで扱う |
| 型安全性維持 | TypeScriptの型システムを活用した安全な変換 |

### TypeScript実装

#### Classic実装（単位変換の例）
```typescript
// Target Interface
interface MetricCalculator {
  getDistanceInMeters(): number;
}

// Concrete Target
class MetricSystem implements MetricCalculator {
  constructor(private readonly distanceInMeters: number) {}

  getDistanceInMeters(): number {
    return this.distanceInMeters;
  }
}

// Adaptee（非互換なクラス）
class ImperialSystem {
  constructor(private readonly distanceInFeet: number) {}

  getDistanceInFeet(): number {
    return this.distanceInFeet;
  }
}

// Adapter
class ImperialToMetricAdapter implements MetricCalculator {
  constructor(private imperialSystem: ImperialSystem) {}

  getDistanceInMeters(): number {
    const feet = this.imperialSystem.getDistanceInFeet();

    if (typeof feet !== 'number' || isNaN(feet)) {
      throw new Error('Invalid distance in feet provided');
    }

    return feet * 0.3048; // フィートからメートルへ変換
  }
}

// Client Code
class Reporter {
  static reportDistance(calculator: MetricCalculator): void {
    console.log(`Distance: ${calculator.getDistanceInMeters()} meters`);
  }
}

// 使用例
const metricDistance = new MetricSystem(5);
Reporter.reportDistance(metricDistance); // Distance: 5 meters

const imperialDistance = new ImperialSystem(10);
const adapter = new ImperialToMetricAdapter(imperialDistance);
Reporter.reportDistance(adapter); // Distance: 3.048 meters
```

#### Modern実装（API バージョン統合）
```typescript
// 旧APIインターフェース
interface ApiServiceV1 {
  callApiV1(endpoint: string): Promise<string>;
}

// 新APIクライアント
class ApiClientV2 {
  async callApiV2(path: string, options?: RequestInit): Promise<Response> {
    return fetch(path, options);
  }
}

// Adapter
class ApiClientV2Adapter implements ApiServiceV1 {
  constructor(private apiClient: ApiClientV2) {}

  async callApiV1(endpoint: string): Promise<string> {
    const response = await this.apiClient.callApiV2(endpoint);

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    return response.text();
  }
}

// 使用例
class LegacyClient {
  constructor(private apiService: ApiServiceV1) {}

  async fetchData(endpoint: string): Promise<void> {
    const data = await this.apiService.callApiV1(endpoint);
    console.log(data);
  }
}

const newApiClient = new ApiClientV2();
const adapter = new ApiClientV2Adapter(newApiClient);
const legacyClient = new LegacyClient(adapter);

await legacyClient.fetchData('/api/users');
```

### テスト考慮事項
```typescript
describe('ImperialToMetricAdapter', () => {
  it('should convert feet to meters correctly', () => {
    const imperial = new ImperialSystem(10);
    const adapter = new ImperialToMetricAdapter(imperial);

    expect(adapter.getDistanceInMeters()).toBeCloseTo(3.048, 3);
  });

  it('should throw error for invalid distance', () => {
    const invalidImperial = { getDistanceInFeet: () => NaN };
    const adapter = new ImperialToMetricAdapter(invalidImperial as any);

    expect(() => adapter.getDistanceInMeters()).toThrow('Invalid distance');
  });
});
```

### 注意点/批判
- **unknown/any の濫用注意**: TypeScript strict mode 有効化推奨
- **過度な変換レイヤー**: パフォーマンスオーバーヘッドに注意
- **構造的型付け**: TypeScript では明示的な implements 宣言不要だが、可読性のため推奨

### 実世界の適用例
```typescript
// Express.js ミドルウェアのアダプター
import { Request, Response, NextFunction } from 'express';

interface ModernMiddleware {
  handle(context: Context): Promise<void>;
}

class ExpressAdapter {
  constructor(private middleware: ModernMiddleware) {}

  adapt() {
    return async (req: Request, res: Response, next: NextFunction) => {
      const context: Context = { req, res, next };
      try {
        await this.middleware.handle(context);
      } catch (error) {
        next(error);
      }
    };
  }
}
```

---

## 2. Decorator パターン

### 目的
オブジェクトに動的に新しい責務を追加し、サブクラス化の代替として柔軟な機能拡張を実現する。

### 使用場面

| 場面 | 具体例 |
|-----|--------|
| 動的な機能追加 | ロギング、キャッシング、バリデーションの追加 |
| サブクラス爆発の回避 | 複数の機能の組み合わせパターンが多い場合 |
| Open/Closed原則 | 既存コードを変更せずに拡張 |
| ラッパーチェーン | 複数のデコレーターを連結して段階的拡張 |

### TypeScript実装

#### Classic実装
```typescript
// Component Interface
interface Coffee {
  cost(): number;
  description(): string;
}

// Concrete Component
class SimpleCoffee implements Coffee {
  cost(): number {
    return 5;
  }

  description(): string {
    return 'Simple coffee';
  }
}

// Base Decorator
abstract class CoffeeDecorator implements Coffee {
  constructor(protected coffee: Coffee) {}

  abstract cost(): number;
  abstract description(): string;
}

// Concrete Decorators
class MilkDecorator extends CoffeeDecorator {
  cost(): number {
    return this.coffee.cost() + 2;
  }

  description(): string {
    return `${this.coffee.description()}, milk`;
  }
}

class SugarDecorator extends CoffeeDecorator {
  cost(): number {
    return this.coffee.cost() + 1;
  }

  description(): string {
    return `${this.coffee.description()}, sugar`;
  }
}

class WhippedCreamDecorator extends CoffeeDecorator {
  cost(): number {
    return this.coffee.cost() + 3;
  }

  description(): string {
    return `${this.coffee.description()}, whipped cream`;
  }
}

// 使用例
let coffee: Coffee = new SimpleCoffee();
console.log(`${coffee.description()} - $${coffee.cost()}`);
// Simple coffee - $5

coffee = new MilkDecorator(coffee);
coffee = new SugarDecorator(coffee);
coffee = new WhippedCreamDecorator(coffee);
console.log(`${coffee.description()} - $${coffee.cost()}`);
// Simple coffee, milk, sugar, whipped cream - $11
```

#### Modern実装（TypeScript Decoratorの活用）
```typescript
// メソッドデコレーター（ロギング）
function log(
  target: any,
  propertyKey: string,
  descriptor: PropertyDescriptor
) {
  const originalMethod = descriptor.value;

  descriptor.value = async function (...args: any[]) {
    console.log(`Calling ${propertyKey} with args:`, args);
    const result = await originalMethod.apply(this, args);
    console.log(`${propertyKey} returned:`, result);
    return result;
  };

  return descriptor;
}

// クラスデコレーター（メタデータ追加）
function injectable(target: Function) {
  Reflect.defineMetadata('injectable', true, target);
}

// 使用例
@injectable
class UserService {
  @log
  async getUser(id: string): Promise<User> {
    // DB からユーザー取得
    return { id, name: 'Alice' };
  }
}

// 実行時デコレーター（関数ラップ）
type AsyncFunction<T = any> = (...args: any[]) => Promise<T>;

function withRetry<T>(
  fn: AsyncFunction<T>,
  maxRetries: number = 3
): AsyncFunction<T> {
  return async (...args: any[]) => {
    for (let i = 0; i < maxRetries; i++) {
      try {
        return await fn(...args);
      } catch (error) {
        if (i === maxRetries - 1) throw error;
        console.log(`Retry ${i + 1}/${maxRetries}`);
      }
    }
    throw new Error('Max retries exceeded');
  };
}

const fetchData = withRetry(async (url: string) => {
  const response = await fetch(url);
  return response.json();
});
```

### テスト考慮事項
```typescript
describe('CoffeeDecorator', () => {
  it('should add costs correctly', () => {
    let coffee: Coffee = new SimpleCoffee();
    coffee = new MilkDecorator(coffee);
    coffee = new SugarDecorator(coffee);

    expect(coffee.cost()).toBe(8); // 5 + 2 + 1
  });

  it('should build description correctly', () => {
    let coffee: Coffee = new SimpleCoffee();
    coffee = new MilkDecorator(coffee);

    expect(coffee.description()).toBe('Simple coffee, milk');
  });
});
```

### 注意点/批判
- **デコレーターチェーンの複雑化**: 順序依存性に注意
- **デバッグ困難**: スタックトレースが深くなる
- **代替案**: Composition over Inheritance の検討

### 実世界の適用例
```typescript
// React Higher-Order Component (HOC)
function withAuth<P extends object>(
  Component: React.ComponentType<P>
): React.FC<P> {
  return (props: P) => {
    const { user } = useAuth();

    if (!user) {
      return <Navigate to="/login" />;
    }

    return <Component {...props} />;
  };
}

const ProtectedPage = withAuth(Dashboard);

// NestJS Guard Decorator
@Controller('users')
export class UsersController {
  @Get()
  @UseGuards(AuthGuard)
  @UseInterceptors(LoggingInterceptor)
  findAll() {
    return this.usersService.findAll();
  }
}
```

---

## 3. Façade パターン

### 目的
複雑なサブシステムへの簡潔なインターフェースを提供し、利用者の負担を軽減する。

### 使用場面

| 場面 | 具体例 |
|-----|--------|
| 複雑なライブラリの簡素化 | API の抽象化レイヤー |
| レイヤードアーキテクチャ | プレゼンテーション層とビジネスロジック層の分離 |
| サブシステムの疎結合化 | 実装詳細の隠蔽 |
| 初期化プロセスの統一 | 複数コンポーネントの協調初期化 |

### TypeScript実装

```typescript
// Subsystem Classes（複雑な内部実装）
class VideoDecoder {
  decode(filename: string): Buffer {
    console.log(`Decoding video: ${filename}`);
    return Buffer.from('decoded video data');
  }
}

class AudioExtractor {
  extract(buffer: Buffer): Buffer {
    console.log('Extracting audio from video');
    return Buffer.from('audio data');
  }
}

class BitrateReader {
  read(filename: string, codec: string): number {
    console.log(`Reading bitrate with codec: ${codec}`);
    return 128000;
  }

  convert(buffer: Buffer, codec: string): Buffer {
    console.log(`Converting to codec: ${codec}`);
    return Buffer.from('converted data');
  }
}

// Façade
class VideoConverter {
  private decoder = new VideoDecoder();
  private audioExtractor = new AudioExtractor();
  private bitrateReader = new BitrateReader();

  convert(filename: string, format: string): Buffer {
    console.log(`Converting ${filename} to ${format}...`);

    const videoData = this.decoder.decode(filename);
    const audioData = this.audioExtractor.extract(videoData);

    let result: Buffer;
    if (format === 'mp4') {
      result = this.bitrateReader.convert(audioData, 'aac');
    } else {
      result = this.bitrateReader.convert(audioData, 'ogg');
    }

    console.log('Conversion complete');
    return result;
  }
}

// Client Code（簡潔な使用）
const converter = new VideoConverter();
const mp4File = converter.convert('video.avi', 'mp4');
```

#### Modern実装（サービス層としてのFaçade）
```typescript
// データアクセス層
class UserRepository {
  async findById(id: string): Promise<User> {
    // DB クエリ
  }
}

class OrderRepository {
  async findByUserId(userId: string): Promise<Order[]> {
    // DB クエリ
  }
}

class NotificationService {
  async sendEmail(to: string, subject: string, body: string): Promise<void> {
    // メール送信
  }
}

// Façade: 複数のサブシステムを統合
class UserManagementFacade {
  constructor(
    private userRepo: UserRepository,
    private orderRepo: OrderRepository,
    private notificationService: NotificationService
  ) {}

  async getUserProfile(userId: string): Promise<UserProfile> {
    const user = await this.userRepo.findById(userId);
    const orders = await this.orderRepo.findByUserId(userId);

    return {
      ...user,
      orderHistory: orders,
      totalOrders: orders.length
    };
  }

  async deleteUserAccount(userId: string): Promise<void> {
    const user = await this.userRepo.findById(userId);

    // 複数の操作を協調実行
    await this.orderRepo.cancelAllByUserId(userId);
    await this.userRepo.delete(userId);
    await this.notificationService.sendEmail(
      user.email,
      'Account Deleted',
      'Your account has been successfully deleted.'
    );
  }
}

// Client Code
const facade = new UserManagementFacade(
  new UserRepository(),
  new OrderRepository(),
  new NotificationService()
);

const profile = await facade.getUserProfile('user123');
await facade.deleteUserAccount('user123');
```

### テスト考慮事項
```typescript
describe('VideoConverter', () => {
  it('should convert video to mp4', () => {
    const converter = new VideoConverter();
    const result = converter.convert('test.avi', 'mp4');

    expect(result).toBeInstanceOf(Buffer);
  });
});

// Façade のテストはモックを活用
describe('UserManagementFacade', () => {
  it('should get user profile with orders', async () => {
    const mockUserRepo = { findById: jest.fn().mockResolvedValue(mockUser) };
    const mockOrderRepo = { findByUserId: jest.fn().mockResolvedValue([]) };
    const facade = new UserManagementFacade(
      mockUserRepo as any,
      mockOrderRepo as any,
      {} as any
    );

    const profile = await facade.getUserProfile('123');

    expect(mockUserRepo.findById).toHaveBeenCalledWith('123');
    expect(profile.totalOrders).toBe(0);
  });
});
```

### 注意点/批判
- **God Object化のリスク**: Façadeが肥大化しないよう責務を明確化
- **隠蔽の副作用**: 高度な機能へのアクセスが困難になる可能性

### 実世界の適用例
```typescript
// jQuery（DOM操作のFaçade）
$('#element').fadeIn(300);

// 内部では複数のDOM API呼び出しを抽象化
element.style.opacity = '0';
element.style.display = 'block';
// ... アニメーション実装

// NestJS サービス層
@Injectable()
export class AppService {
  constructor(
    private userService: UserService,
    private emailService: EmailService,
    private loggingService: LoggingService
  ) {}

  async registerUser(data: CreateUserDto): Promise<User> {
    const user = await this.userService.create(data);
    await this.emailService.sendWelcomeEmail(user.email);
    this.loggingService.log('User registered', { userId: user.id });
    return user;
  }
}
```

---

## 4. Composite パターン

### 目的
ツリー構造を表現し、個々のオブジェクトと複合オブジェクトを同一インターフェースで扱う。

### 使用場面

| 場面 | 具体例 |
|-----|--------|
| 階層構造の表現 | ファイルシステム、組織図、UIコンポーネント |
| 部分-全体の統一扱い | 再帰的な処理が必要な構造 |
| ツリー走査 | DOMツリー、ASTノード |

### TypeScript実装

```typescript
// Component Interface
interface FileSystemNode {
  getName(): string;
  getSize(): number;
  print(indent?: string): void;
}

// Leaf（末端ノード）
class File implements FileSystemNode {
  constructor(
    private name: string,
    private size: number
  ) {}

  getName(): string {
    return this.name;
  }

  getSize(): number {
    return this.size;
  }

  print(indent: string = ''): void {
    console.log(`${indent}📄 ${this.name} (${this.size} bytes)`);
  }
}

// Composite（複合ノード）
class Directory implements FileSystemNode {
  private children: FileSystemNode[] = [];

  constructor(private name: string) {}

  add(node: FileSystemNode): void {
    this.children.push(node);
  }

  remove(node: FileSystemNode): void {
    const index = this.children.indexOf(node);
    if (index !== -1) {
      this.children.splice(index, 1);
    }
  }

  getName(): string {
    return this.name;
  }

  getSize(): number {
    return this.children.reduce((sum, child) => sum + child.getSize(), 0);
  }

  print(indent: string = ''): void {
    console.log(`${indent}📁 ${this.name}`);
    this.children.forEach(child => child.print(indent + '  '));
  }
}

// 使用例
const root = new Directory('root');
const home = new Directory('home');
const user = new Directory('user');

user.add(new File('document.txt', 1024));
user.add(new File('photo.jpg', 2048));

home.add(user);
home.add(new File('readme.md', 512));

root.add(home);
root.add(new File('config.json', 256));

root.print();
// 📁 root
//   📁 home
//     📁 user
//       📄 document.txt (1024 bytes)
//       📄 photo.jpg (2048 bytes)
//     📄 readme.md (512 bytes)
//   📄 config.json (256 bytes)

console.log(`Total size: ${root.getSize()} bytes`); // 3840
```

### テスト考慮事項
```typescript
describe('Composite Pattern', () => {
  it('should calculate total size recursively', () => {
    const dir = new Directory('test');
    dir.add(new File('file1.txt', 100));
    dir.add(new File('file2.txt', 200));

    expect(dir.getSize()).toBe(300);
  });

  it('should remove child correctly', () => {
    const dir = new Directory('test');
    const file = new File('file.txt', 100);
    dir.add(file);
    dir.remove(file);

    expect(dir.getSize()).toBe(0);
  });
});
```

### 注意点/批判
- **型安全性**: Leaf に add/remove メソッドを定義すべきか議論がある
- **過度な汎用化**: シンプルな階層には不要

### 実世界の適用例
```typescript
// React Component Tree
interface ReactNode {
  render(): JSX.Element;
}

class Component implements ReactNode {
  private children: ReactNode[] = [];

  addChild(child: ReactNode): void {
    this.children.push(child);
  }

  render(): JSX.Element {
    return (
      <div>
        {this.children.map(child => child.render())}
      </div>
    );
  }
}
```

---

## 5. Proxy パターン

### 目的
オブジェクトへのアクセスを制御し、間接層を通じて追加機能を提供する。

### 使用場面

| 場面 | 具体例 |
|-----|--------|
| 遅延初期化（Virtual Proxy） | 重いオブジェクトの遅延ロード |
| アクセス制御（Protection Proxy） | 権限チェック、認証 |
| ログ記録（Logging Proxy） | メソッド呼び出しの追跡 |
| リモートオブジェクト（Remote Proxy） | RPC、ネットワーク通信の抽象化 |

### TypeScript実装

#### Virtual Proxy（遅延初期化）
```typescript
interface Image {
  display(): void;
}

// Real Subject
class RealImage implements Image {
  constructor(private filename: string) {
    this.loadFromDisk();
  }

  private loadFromDisk(): void {
    console.log(`Loading image from disk: ${this.filename}`);
    // 重い処理をシミュレート
  }

  display(): void {
    console.log(`Displaying image: ${this.filename}`);
  }
}

// Proxy
class ImageProxy implements Image {
  private realImage: RealImage | null = null;

  constructor(private filename: string) {}

  display(): void {
    if (!this.realImage) {
      this.realImage = new RealImage(this.filename);
    }
    this.realImage.display();
  }
}

// 使用例
const image1 = new ImageProxy('photo1.jpg');
const image2 = new ImageProxy('photo2.jpg');

// この時点ではまだ画像は読み込まれていない
console.log('Images created');

image1.display(); // 初回: ディスクから読み込み + 表示
image1.display(); // 2回目: キャッシュから表示
```

#### Protection Proxy（アクセス制御）
```typescript
interface BankAccount {
  deposit(amount: number): void;
  withdraw(amount: number): void;
  getBalance(): number;
}

class RealBankAccount implements BankAccount {
  private balance = 0;

  deposit(amount: number): void {
    this.balance += amount;
  }

  withdraw(amount: number): void {
    this.balance -= amount;
  }

  getBalance(): number {
    return this.balance;
  }
}

class BankAccountProxy implements BankAccount {
  constructor(
    private account: RealBankAccount,
    private userRole: 'admin' | 'user'
  ) {}

  deposit(amount: number): void {
    console.log('Depositing:', amount);
    this.account.deposit(amount);
  }

  withdraw(amount: number): void {
    if (this.userRole !== 'admin') {
      throw new Error('Withdrawal requires admin privileges');
    }
    console.log('Withdrawing:', amount);
    this.account.withdraw(amount);
  }

  getBalance(): number {
    return this.account.getBalance();
  }
}

// 使用例
const adminAccount = new BankAccountProxy(new RealBankAccount(), 'admin');
adminAccount.deposit(1000);
adminAccount.withdraw(500); // OK

const userAccount = new BankAccountProxy(new RealBankAccount(), 'user');
userAccount.deposit(1000);
userAccount.withdraw(500); // Error: admin privileges required
```

#### Modern実装（ES6 Proxy）
```typescript
const target = {
  name: 'Alice',
  age: 30
};

const handler: ProxyHandler<typeof target> = {
  get(target, property, receiver) {
    console.log(`Getting property: ${String(property)}`);
    return Reflect.get(target, property, receiver);
  },

  set(target, property, value, receiver) {
    console.log(`Setting property: ${String(property)} = ${value}`);

    if (property === 'age' && typeof value !== 'number') {
      throw new TypeError('Age must be a number');
    }

    return Reflect.set(target, property, value, receiver);
  }
};

const proxy = new Proxy(target, handler);

proxy.name; // Getting property: name
proxy.age = 31; // Setting property: age = 31
proxy.age = '31'; // TypeError: Age must be a number
```

### テスト考慮事項
```typescript
describe('ImageProxy', () => {
  it('should delay loading until first display', () => {
    const loadSpy = jest.spyOn(RealImage.prototype as any, 'loadFromDisk');
    const proxy = new ImageProxy('test.jpg');

    expect(loadSpy).not.toHaveBeenCalled();

    proxy.display();
    expect(loadSpy).toHaveBeenCalledTimes(1);

    proxy.display();
    expect(loadSpy).toHaveBeenCalledTimes(1); // キャッシュ利用
  });
});
```

### 注意点/批判
- **パフォーマンスオーバーヘッド**: 間接層による呼び出しコスト
- **複雑性**: デバッグ時にスタックトレースが深くなる

### 実世界の適用例
```typescript
// Vue 3 Reactivity System
import { reactive, effect } from 'vue';

const state = reactive({ count: 0 });

effect(() => {
  console.log(`Count is: ${state.count}`);
});

state.count++; // 自動的に effect が再実行される

// TypeORM Lazy Relations
@Entity()
class User {
  @OneToMany(() => Post, post => post.user)
  posts: Promise<Post[]>; // Lazy loading
}

const user = await userRepository.findOne(1);
const posts = await user.posts; // この時点で初めて読み込まれる
```

---

## 6. Bridge パターン

### 目的
抽象と実装を分離し、それぞれを独立して変更可能にする。

### 使用場面

| 場面 | 具体例 |
|-----|--------|
| 複数次元の変化 | プラットフォーム×機能の組み合わせ |
| 実装の切り替え | DB ドライバー、レンダリングエンジン |
| サブクラス爆発の回避 | 継承階層の簡素化 |

### TypeScript実装

```typescript
// Implementor Interface
interface Renderer {
  renderCircle(radius: number): void;
  renderSquare(side: number): void;
}

// Concrete Implementors
class VectorRenderer implements Renderer {
  renderCircle(radius: number): void {
    console.log(`Drawing circle with radius ${radius} using vector graphics`);
  }

  renderSquare(side: number): void {
    console.log(`Drawing square with side ${side} using vector graphics`);
  }
}

class RasterRenderer implements Renderer {
  renderCircle(radius: number): void {
    console.log(`Drawing circle with radius ${radius} as pixels`);
  }

  renderSquare(side: number): void {
    console.log(`Drawing square with side ${side} as pixels`);
  }
}

// Abstraction
abstract class Shape {
  constructor(protected renderer: Renderer) {}

  abstract draw(): void;
}

// Refined Abstractions
class Circle extends Shape {
  constructor(renderer: Renderer, private radius: number) {
    super(renderer);
  }

  draw(): void {
    this.renderer.renderCircle(this.radius);
  }
}

class Square extends Shape {
  constructor(renderer: Renderer, private side: number) {
    super(renderer);
  }

  draw(): void {
    this.renderer.renderSquare(this.side);
  }
}

// 使用例
const vectorCircle = new Circle(new VectorRenderer(), 5);
vectorCircle.draw(); // Drawing circle with radius 5 using vector graphics

const rasterSquare = new Square(new RasterRenderer(), 10);
rasterSquare.draw(); // Drawing square with side 10 as pixels
```

### テスト考慮事項
```typescript
describe('Bridge Pattern', () => {
  it('should render circle with correct renderer', () => {
    const mockRenderer = { renderCircle: jest.fn() };
    const circle = new Circle(mockRenderer as any, 5);

    circle.draw();

    expect(mockRenderer.renderCircle).toHaveBeenCalledWith(5);
  });
});
```

### 注意点/批判
- **過度な抽象化**: シンプルなケースでは不要
- **複雑性の増加**: レイヤーが増えることで理解が困難に

### 実世界の適用例
```typescript
// データベースドライバーの抽象化
interface DatabaseDriver {
  connect(): Promise<void>;
  query(sql: string): Promise<any[]>;
}

class MySQLDriver implements DatabaseDriver {
  async connect() { /* MySQL接続 */ }
  async query(sql: string) { /* MySQLクエリ */ }
}

class PostgreSQLDriver implements DatabaseDriver {
  async connect() { /* PostgreSQL接続 */ }
  async query(sql: string) { /* PostgreSQLクエリ */ }
}

abstract class Repository {
  constructor(protected driver: DatabaseDriver) {}
  abstract findAll(): Promise<any[]>;
}

class UserRepository extends Repository {
  async findAll(): Promise<User[]> {
    return this.driver.query('SELECT * FROM users');
  }
}
```

---

## 7. Flyweight パターン

### 目的
大量の細粒度オブジェクトを効率的に共有し、メモリ使用量を削減する。

### 使用場面

| 場面 | 具体例 |
|-----|--------|
| 大量の類似オブジェクト | ゲームのパーティクル、テキストエディタの文字 |
| 共有可能な状態 | 不変な固有状態（intrinsic state） |
| メモリ制約 | モバイルアプリ、大規模データ処理 |

### TypeScript実装

```typescript
// Flyweight
class TreeType {
  constructor(
    private name: string,
    private color: string,
    private texture: string
  ) {}

  draw(x: number, y: number): void {
    console.log(`Drawing ${this.name} tree at (${x}, ${y})`);
  }
}

// Flyweight Factory
class TreeFactory {
  private static treeTypes = new Map<string, TreeType>();

  static getTreeType(name: string, color: string, texture: string): TreeType {
    const key = `${name}-${color}-${texture}`;

    if (!this.treeTypes.has(key)) {
      this.treeTypes.set(key, new TreeType(name, color, texture));
      console.log(`Creating new tree type: ${key}`);
    }

    return this.treeTypes.get(key)!;
  }

  static getTotalTreeTypes(): number {
    return this.treeTypes.size;
  }
}

// Context（外部状態を保持）
class Tree {
  constructor(
    private x: number,
    private y: number,
    private type: TreeType
  ) {}

  draw(): void {
    this.type.draw(this.x, this.y);
  }
}

// Client Code
class Forest {
  private trees: Tree[] = [];

  plantTree(x: number, y: number, name: string, color: string, texture: string): void {
    const type = TreeFactory.getTreeType(name, color, texture);
    const tree = new Tree(x, y, type);
    this.trees.push(tree);
  }

  draw(): void {
    this.trees.forEach(tree => tree.draw());
  }
}

// 使用例
const forest = new Forest();

// 1000本の木を植える（しかしTreeTypeは数種類のみ）
for (let i = 0; i < 1000; i++) {
  const x = Math.random() * 100;
  const y = Math.random() * 100;
  const name = i % 2 === 0 ? 'Oak' : 'Pine';
  const color = 'Green';
  const texture = 'Rough';

  forest.plantTree(x, y, name, color, texture);
}

console.log(`Total tree types: ${TreeFactory.getTotalTreeTypes()}`); // 2
```

### テスト考慮事項
```typescript
describe('Flyweight Pattern', () => {
  it('should reuse tree types', () => {
    const type1 = TreeFactory.getTreeType('Oak', 'Green', 'Rough');
    const type2 = TreeFactory.getTreeType('Oak', 'Green', 'Rough');

    expect(type1).toBe(type2); // 同一インスタンス
  });

  it('should create separate instances for different types', () => {
    const oak = TreeFactory.getTreeType('Oak', 'Green', 'Rough');
    const pine = TreeFactory.getTreeType('Pine', 'Green', 'Rough');

    expect(oak).not.toBe(pine);
  });
});
```

### 注意点/批判
- **スレッドセーフ性**: Flyweight Factory はシングルトン的動作のため、並行アクセス注意
- **複雑性**: 状態の分離（intrinsic/extrinsic）が難しい

### 実世界の適用例
```typescript
// JavaScript の文字列インターン
const str1 = 'hello';
const str2 = 'hello';
console.log(str1 === str2); // true（メモリ共有）

// React の Element Type キャッシング
const Button1 = () => <button>Click</button>;
const Button2 = () => <button>Click</button>;
// React は同じ型のコンポーネントを再利用

// TypeORM Entity Manager
class EntityManager {
  private identityMap = new Map<string, any>();

  find<T>(EntityClass: new () => T, id: string): T {
    const key = `${EntityClass.name}-${id}`;

    if (!this.identityMap.has(key)) {
      const entity = new EntityClass();
      // DB から読み込み
      this.identityMap.set(key, entity);
    }

    return this.identityMap.get(key);
  }
}
```
