# バックエンド開発戦略ガイド

> O'Reilly書籍「Full Stack JavaScript Strategies」に基づくバックエンド開発の包括的ガイド

## 目次

1. [アーキテクチャ判断](#1-アーキテクチャ判断)
2. [API設計規約](#2-api設計規約)
3. [データスキーマ設計](#3-データスキーマ設計)
4. [エラーハンドリングとログ](#4-エラーハンドリングとログ)
5. [キャッシング戦略](#5-キャッシング戦略)
6. [バックグラウンドジョブ](#6-バックグラウンドジョブ)
7. [サードパーティサービス統合](#7-サードパーティサービス統合)
8. [スケーリング](#8-スケーリング)
9. [モニタリングとインシデント対応](#9-モニタリングとインシデント対応)

---

## 1. アーキテクチャ判断

### モノリス vs マイクロサービス

#### モノリスが適切な場合

**推奨シナリオ:**
- 小〜中規模チーム（1-10人）
- 初期プロジェクト・MVPフェーズ
- ドメインの境界が不明確
- 迅速なデプロイとイテレーションが必要
- チームのマイクロサービス運用経験が少ない

**メリット:**
- シンプルなデプロイメントパイプライン
- トランザクション処理が容易
- デバッグが簡単（単一のコードベース）
- インフラコストが低い
- チーム間の調整が不要

**デメリット:**
- スケールの柔軟性に欠ける
- デプロイリスクが高い（全体が影響を受ける）
- 技術スタックが固定される
- コードベースが肥大化しやすい

#### マイクロサービスが適切な場合

**推奨シナリオ:**
- 大規模チーム（10人以上）
- 明確なドメイン境界が存在
- 独立したデプロイが必要
- 部分的なスケーリングが必要
- 技術スタックの多様性が必要

**メリット:**
- 独立したデプロイとスケーリング
- 技術スタックの柔軟性
- チームの自律性向上
- 障害の局所化

**デメリット:**
- 複雑なインフラ管理
- ネットワークレイテンシ
- 分散トランザクションの困難さ
- デバッグが複雑
- 運用コストが高い

#### 判断基準テーブル

| 要素 | モノリス | マイクロサービス |
|------|----------|------------------|
| チームサイズ | 1-10人 | 10人以上 |
| デプロイ頻度 | 週1回程度 | 日に複数回 |
| スケール要件 | 均一 | 部分的 |
| ドメイン理解 | 発展途上 | 明確 |
| インフラ経験 | 限定的 | 高度 |
| トランザクション | 重要 | 限定的 |
| 技術スタック | 統一 | 多様 |

#### Bounded Contextsの使い方

**Domain-Driven Design (DDD)** の核心概念である **Bounded Context** は、マイクロサービスの境界を決定する際の指針となります。

**Bounded Contextとは:**
- ドメインモデルが適用される明確な境界
- 各コンテキスト内で用語が一意の意味を持つ
- コンテキスト間の依存関係を明示化

**実践例: ECサイト**

```typescript
// ❌ 悪い例: 境界が曖昧
// すべてが一つのモデルに混在
interface Order {
  id: string;
  userId: string;
  items: Product[];
  totalPrice: number;
  shippingAddress: Address;
  paymentMethod: PaymentMethod;
  inventoryReserved: boolean;
  recommendedProducts: Product[];
}

// ✅ 良い例: Bounded Contextで分離
// 注文コンテキスト
interface Order {
  id: string;
  userId: string;
  items: OrderItem[];
  totalPrice: number;
  status: OrderStatus;
}

// 配送コンテキスト
interface Shipment {
  orderId: string;
  address: Address;
  trackingNumber: string;
  carrier: string;
}

// 在庫コンテキスト
interface InventoryReservation {
  orderId: string;
  productId: string;
  quantity: number;
  expiresAt: Date;
}

// レコメンデーションコンテキスト
interface Recommendation {
  userId: string;
  recommendedProducts: ProductReference[];
  basedOn: string[];
}
```

**コンテキスト間の通信:**

```typescript
// Anti-Corruption Layer (ACL) パターン
// 他のコンテキストのモデルを自分のコンテキストのモデルに変換

// 注文サービス
class OrderService {
  async createOrder(userId: string, items: OrderItem[]): Promise<Order> {
    const order = await this.orderRepository.create({ userId, items });

    // 在庫サービスに通知（イベント駆動）
    await this.eventBus.publish(new OrderCreatedEvent({
      orderId: order.id,
      items: items.map(item => ({
        productId: item.productId,
        quantity: item.quantity,
      })),
    }));

    return order;
  }
}

// 在庫サービス
class InventoryService {
  @EventHandler(OrderCreatedEvent)
  async handleOrderCreated(event: OrderCreatedEvent): Promise<void> {
    // 他のコンテキストのイベントを自分のドメインモデルに変換
    const reservations = event.items.map(item => ({
      orderId: event.orderId,
      productId: item.productId,
      quantity: item.quantity,
      expiresAt: new Date(Date.now() + 15 * 60 * 1000), // 15分
    }));

    await this.reservationRepository.createBatch(reservations);
  }
}
```

### NestJSセットアップパターン

#### プロジェクト構造

```
src/
├── modules/
│   ├── users/
│   │   ├── users.controller.ts
│   │   ├── users.service.ts
│   │   ├── users.module.ts
│   │   ├── dto/
│   │   │   ├── create-user.dto.ts
│   │   │   └── update-user.dto.ts
│   │   ├── entities/
│   │   │   └── user.entity.ts
│   │   └── users.repository.ts
│   ├── orders/
│   └── products/
├── common/
│   ├── decorators/
│   ├── filters/
│   ├── guards/
│   ├── interceptors/
│   └── pipes/
├── config/
│   ├── database.config.ts
│   └── app.config.ts
├── app.module.ts
└── main.ts
```

#### モジュール構成

```typescript
// users/users.module.ts
import { Module } from '@nestjs/common';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';
import { UsersRepository } from './users.repository';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [PrismaModule], // 依存モジュールをインポート
  controllers: [UsersController],
  providers: [UsersService, UsersRepository],
  exports: [UsersService], // 他のモジュールで使用可能にする
})
export class UsersModule {}
```

#### Controller（ルーティング）

```typescript
// users/users.controller.ts
import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Body,
  Param,
  Query,
  HttpCode,
  HttpStatus,
  UseGuards,
} from '@nestjs/common';
import { UsersService } from './users.service';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@Controller('users')
@UseGuards(JwtAuthGuard) // 認証ガード適用
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  async create(@Body() createUserDto: CreateUserDto) {
    return this.usersService.create(createUserDto);
  }

  @Get()
  async findAll(
    @Query('page') page: number = 1,
    @Query('limit') limit: number = 10,
  ) {
    return this.usersService.findAll({ page, limit });
  }

  @Get(':id')
  async findOne(@Param('id') id: string) {
    return this.usersService.findOne(id);
  }

  @Put(':id')
  async update(
    @Param('id') id: string,
    @Body() updateUserDto: UpdateUserDto,
  ) {
    return this.usersService.update(id, updateUserDto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async remove(@Param('id') id: string) {
    await this.usersService.remove(id);
  }
}
```

#### Service（ビジネスロジック）

```typescript
// users/users.service.ts
import { Injectable, NotFoundException } from '@nestjs/common';
import { UsersRepository } from './users.repository';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import * as bcrypt from 'bcrypt';

@Injectable()
export class UsersService {
  constructor(private readonly usersRepository: UsersRepository) {}

  async create(createUserDto: CreateUserDto) {
    const hashedPassword = await bcrypt.hash(createUserDto.password, 10);

    return this.usersRepository.create({
      ...createUserDto,
      password: hashedPassword,
    });
  }

  async findAll({ page, limit }: { page: number; limit: number }) {
    const skip = (page - 1) * limit;

    const [users, total] = await Promise.all([
      this.usersRepository.findMany({ skip, take: limit }),
      this.usersRepository.count(),
    ]);

    return {
      data: users,
      meta: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  async findOne(id: string) {
    const user = await this.usersRepository.findById(id);

    if (!user) {
      throw new NotFoundException(`User with ID ${id} not found`);
    }

    return user;
  }

  async update(id: string, updateUserDto: UpdateUserDto) {
    await this.findOne(id); // 存在チェック

    return this.usersRepository.update(id, updateUserDto);
  }

  async remove(id: string) {
    await this.findOne(id); // 存在チェック

    return this.usersRepository.delete(id);
  }
}
```

#### DTOとバリデーション

```typescript
// users/dto/create-user.dto.ts
import {
  IsEmail,
  IsString,
  IsNotEmpty,
  MinLength,
  MaxLength,
  Matches,
  IsOptional,
  IsEnum,
} from 'class-validator';
import { Transform } from 'class-transformer';

enum UserRole {
  USER = 'USER',
  ADMIN = 'ADMIN',
  MODERATOR = 'MODERATOR',
}

export class CreateUserDto {
  @IsEmail({}, { message: '有効なメールアドレスを入力してください' })
  @Transform(({ value }) => value?.toLowerCase().trim())
  email: string;

  @IsString()
  @IsNotEmpty({ message: 'パスワードは必須です' })
  @MinLength(8, { message: 'パスワードは8文字以上である必要があります' })
  @Matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/, {
    message: 'パスワードは大文字、小文字、数字を含む必要があります',
  })
  password: string;

  @IsString()
  @IsNotEmpty()
  @MinLength(2)
  @MaxLength(50)
  @Transform(({ value }) => value?.trim())
  name: string;

  @IsOptional()
  @IsEnum(UserRole, { message: '無効なロールです' })
  role?: UserRole;
}
```

```typescript
// users/dto/update-user.dto.ts
import { PartialType, OmitType } from '@nestjs/mapped-types';
import { CreateUserDto } from './create-user.dto';

// パスワードを除外し、すべてのフィールドをオプショナルにする
export class UpdateUserDto extends PartialType(
  OmitType(CreateUserDto, ['password', 'email'] as const),
) {}
```

**バリデーションの有効化:**

```typescript
// main.ts
import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // グローバルバリデーションパイプ
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true, // DTOに定義されていないプロパティを削除
      forbidNonWhitelisted: true, // 未定義プロパティがあればエラー
      transform: true, // 自動的に型変換（例: '123' → 123）
      transformOptions: {
        enableImplicitConversion: true,
      },
    }),
  );

  await app.listen(3000);
}
bootstrap();
```

#### 環境変数管理

```typescript
// config/app.config.ts
import { registerAs } from '@nestjs/config';
import { IsString, IsNumber, IsEnum, validateSync } from 'class-validator';
import { plainToClass } from 'class-transformer';

enum Environment {
  Development = 'development',
  Production = 'production',
  Test = 'test',
}

class EnvironmentVariables {
  @IsEnum(Environment)
  NODE_ENV: Environment;

  @IsNumber()
  PORT: number;

  @IsString()
  DATABASE_URL: string;

  @IsString()
  JWT_SECRET: string;

  @IsNumber()
  JWT_EXPIRATION: number;

  @IsString()
  REDIS_URL: string;
}

export default registerAs('app', () => {
  const validatedConfig = plainToClass(
    EnvironmentVariables,
    {
      NODE_ENV: process.env.NODE_ENV,
      PORT: parseInt(process.env.PORT || '3000', 10),
      DATABASE_URL: process.env.DATABASE_URL,
      JWT_SECRET: process.env.JWT_SECRET,
      JWT_EXPIRATION: parseInt(process.env.JWT_EXPIRATION || '3600', 10),
      REDIS_URL: process.env.REDIS_URL,
    },
    { enableImplicitConversion: true },
  );

  const errors = validateSync(validatedConfig, {
    skipMissingProperties: false,
  });

  if (errors.length > 0) {
    throw new Error(`Config validation error: ${errors.toString()}`);
  }

  return validatedConfig;
});
```

```typescript
// app.module.ts
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import appConfig from './config/app.config';
import databaseConfig from './config/database.config';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true, // すべてのモジュールで利用可能
      load: [appConfig, databaseConfig],
      validationSchema: null, // class-validatorを使用するためnull
      envFilePath: ['.env.local', '.env'], // 優先順位順
    }),
    // その他のモジュール
  ],
})
export class AppModule {}
```

**使用例:**

```typescript
// users/users.service.ts
import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class UsersService {
  constructor(private readonly configService: ConfigService) {}

  getJwtSecret(): string {
    return this.configService.get<string>('app.JWT_SECRET');
  }
}
```

---

## 2. API設計規約

### REST API設計

#### URLの命名規則

**基本原則:**
- **複数形を使用**: `/users`, `/orders`, `/products`
- **kebab-caseを使用**: `/user-profiles`, `/order-items`
- **小文字のみ**: `/Users` ❌ → `/users` ✅
- **動詞を避ける**: `/getUsers` ❌ → `/users` ✅
- **階層関係を表現**: `/users/123/orders`

```typescript
// ❌ 悪い例
GET /getUser?id=123
POST /user/create
GET /User
GET /user_profile

// ✅ 良い例
GET /users/123
POST /users
GET /users
GET /user-profiles
```

**リソース階層:**

```typescript
// 親子関係を表現
GET    /users/123/orders          // ユーザー123の注文一覧
POST   /users/123/orders          // ユーザー123の注文作成
GET    /users/123/orders/456      // ユーザー123の注文456の詳細
PUT    /users/123/orders/456      // 注文456の更新
DELETE /users/123/orders/456      // 注文456の削除

// フィルタはクエリパラメータで
GET /orders?userId=123&status=pending
```

#### HTTPメソッドの正しい使い分け

| メソッド | 用途 | 冪等性 | リクエストボディ | レスポンスボディ |
|----------|------|--------|------------------|------------------|
| **GET** | リソース取得 | ✅ あり | ❌ なし | ✅ あり |
| **POST** | リソース作成 | ❌ なし | ✅ あり | ✅ あり（作成されたリソース） |
| **PUT** | リソース全体更新 | ✅ あり | ✅ あり | ✅ あり |
| **PATCH** | リソース部分更新 | ❌ なし* | ✅ あり | ✅ あり |
| **DELETE** | リソース削除 | ✅ あり | ❌ なし | ❌ なし（または削除されたリソース） |

*PATCHは実装によっては冪等にできる

**詳細な使い分け:**

```typescript
// GET: データ取得（副作用なし）
@Get('users/:id')
async getUser(@Param('id') id: string) {
  return this.usersService.findOne(id);
}

// POST: 新規作成（同じリクエストを複数回送ると複数のリソースが作成される）
@Post('users')
@HttpCode(HttpStatus.CREATED)
async createUser(@Body() dto: CreateUserDto) {
  const user = await this.usersService.create(dto);
  return user; // 作成されたリソースを返す
}

// PUT: 全体更新（同じリクエストを複数回送っても結果は同じ）
// すべてのフィールドを送信する必要がある
@Put('users/:id')
async updateUser(
  @Param('id') id: string,
  @Body() dto: UpdateUserDto,
) {
  // dtoにはすべてのフィールドが含まれる
  return this.usersService.replace(id, dto);
}

// PATCH: 部分更新（変更するフィールドのみ送信）
@Patch('users/:id')
async patchUser(
  @Param('id') id: string,
  @Body() dto: Partial<UpdateUserDto>,
) {
  // dtoには変更するフィールドのみが含まれる
  return this.usersService.update(id, dto);
}

// DELETE: 削除（同じリクエストを複数回送っても結果は同じ）
@Delete('users/:id')
@HttpCode(HttpStatus.NO_CONTENT)
async deleteUser(@Param('id') id: string) {
  await this.usersService.remove(id);
  // 204 No Contentなのでボディは返さない
}
```

#### ステータスコード設計

**成功レスポンス（2xx）:**

| コード | 意味 | 使用例 |
|--------|------|--------|
| **200 OK** | リクエスト成功 | GET、PUT、PATCH |
| **201 Created** | リソース作成成功 | POST |
| **204 No Content** | 成功、レスポンスボディなし | DELETE、PUT（更新のみ） |

**クライアントエラー（4xx）:**

| コード | 意味 | 使用例 |
|--------|------|--------|
| **400 Bad Request** | 不正なリクエスト | 構文エラー、不正なJSON |
| **401 Unauthorized** | 認証が必要 | トークンなし、トークン無効 |
| **403 Forbidden** | 権限不足 | アクセス権限なし |
| **404 Not Found** | リソースが存在しない | 存在しないID |
| **422 Unprocessable Entity** | バリデーションエラー | ビジネスロジック違反 |
| **429 Too Many Requests** | レート制限超過 | API制限超過 |

**サーバーエラー（5xx）:**

| コード | 意味 | 使用例 |
|--------|------|--------|
| **500 Internal Server Error** | サーバー内部エラー | 予期しないエラー |
| **502 Bad Gateway** | 上流サーバーエラー | プロキシ、ゲートウェイエラー |
| **503 Service Unavailable** | サービス利用不可 | メンテナンス、過負荷 |

**実装例:**

```typescript
// users/users.controller.ts
import {
  Controller,
  Post,
  Get,
  Put,
  Delete,
  Body,
  Param,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';

@Controller('users')
export class UsersController {
  // 201 Created
  @Post()
  @HttpCode(HttpStatus.CREATED)
  async create(@Body() dto: CreateUserDto) {
    return this.usersService.create(dto);
  }

  // 200 OK（デフォルト）
  @Get(':id')
  async findOne(@Param('id') id: string) {
    return this.usersService.findOne(id);
  }

  // 200 OK
  @Put(':id')
  async update(@Param('id') id: string, @Body() dto: UpdateUserDto) {
    return this.usersService.update(id, dto);
  }

  // 204 No Content
  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async remove(@Param('id') id: string) {
    await this.usersService.remove(id);
  }
}
```

#### エラーレスポンス形式の統一

**標準エラーレスポンス構造:**

```typescript
interface ErrorResponse {
  statusCode: number;
  message: string | string[];
  error: string;
  timestamp: string;
  path: string;
  details?: Record<string, unknown>;
}
```

**実装例:**

```typescript
// common/filters/http-exception.filter.ts
import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { Request, Response } from 'express';

@Catch(HttpException)
export class HttpExceptionFilter implements ExceptionFilter {
  catch(exception: HttpException, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();
    const status = exception.getStatus();
    const exceptionResponse = exception.getResponse();

    const errorResponse = {
      statusCode: status,
      timestamp: new Date().toISOString(),
      path: request.url,
      method: request.method,
      message:
        typeof exceptionResponse === 'string'
          ? exceptionResponse
          : (exceptionResponse as any).message,
      error:
        typeof exceptionResponse === 'string'
          ? HttpStatus[status]
          : (exceptionResponse as any).error,
    };

    response.status(status).json(errorResponse);
  }
}
```

**グローバル適用:**

```typescript
// main.ts
import { NestFactory } from '@nestjs/core';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.useGlobalFilters(new HttpExceptionFilter());
  await app.listen(3000);
}
bootstrap();
```

**レスポンス例:**

```json
// 400 Bad Request
{
  "statusCode": 400,
  "timestamp": "2024-01-15T10:30:00.000Z",
  "path": "/users",
  "method": "POST",
  "message": [
    "email must be a valid email",
    "password must be longer than 8 characters"
  ],
  "error": "Bad Request"
}

// 404 Not Found
{
  "statusCode": 404,
  "timestamp": "2024-01-15T10:30:00.000Z",
  "path": "/users/999",
  "method": "GET",
  "message": "User with ID 999 not found",
  "error": "Not Found"
}

// 422 Unprocessable Entity
{
  "statusCode": 422,
  "timestamp": "2024-01-15T10:30:00.000Z",
  "path": "/orders",
  "method": "POST",
  "message": "Insufficient stock for product ID 123",
  "error": "Unprocessable Entity"
}
```

#### APIバージョニング

**方法1: URI Versioning（推奨）**

```typescript
// main.ts
import { VersioningType } from '@nestjs/common';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  app.enableVersioning({
    type: VersioningType.URI,
    defaultVersion: '1',
  });

  await app.listen(3000);
}
bootstrap();
```

```typescript
// users/users.controller.ts
import { Controller, Get, Version } from '@nestjs/common';

@Controller('users')
export class UsersController {
  // GET /v1/users
  @Get()
  @Version('1')
  findAllV1() {
    return this.usersService.findAllV1();
  }

  // GET /v2/users
  @Get()
  @Version('2')
  findAllV2() {
    return this.usersService.findAllV2();
  }
}
```

**方法2: Header Versioning**

```typescript
app.enableVersioning({
  type: VersioningType.HEADER,
  header: 'X-API-Version',
});

// リクエスト例
// GET /users
// X-API-Version: 2
```

**方法3: Media Type Versioning**

```typescript
app.enableVersioning({
  type: VersioningType.MEDIA_TYPE,
  key: 'v=',
});

// リクエスト例
// GET /users
// Accept: application/json;v=2
```

**バージョニング戦略:**

```typescript
// ❌ 悪い例: すべてのマイナーチェンジでバージョンアップ
// v1: { id, name }
// v2: { id, name, email } // フィールド追加だけ
// v3: { id, name, email, phone } // さらに追加

// ✅ 良い例: 破壊的変更のみバージョンアップ
// v1: { id, name, email }
// v1: { id, name, email, phone } // 後方互換性あり（追加のみ）
// v2: { userId, fullName, contactInfo } // 破壊的変更（フィールド名変更）
```

#### ページネーション、ソート、フィルタリングの標準化

**ページネーション:**

```typescript
// Cursor-based Pagination（推奨：リアルタイムデータ）
interface CursorPaginationQuery {
  cursor?: string; // 最後のアイテムのID
  limit: number; // デフォルト: 10
}

interface CursorPaginationResponse<T> {
  data: T[];
  meta: {
    nextCursor: string | null;
    hasMore: boolean;
  };
}

// Offset-based Pagination（シンプル：静的データ）
interface OffsetPaginationQuery {
  page: number; // デフォルト: 1
  limit: number; // デフォルト: 10
}

interface OffsetPaginationResponse<T> {
  data: T[];
  meta: {
    total: number;
    page: number;
    limit: number;
    totalPages: number;
  };
}
```

**実装例:**

```typescript
// common/decorators/pagination.decorator.ts
import { createParamDecorator, ExecutionContext } from '@nestjs/common';

export const Pagination = createParamDecorator(
  (data: unknown, ctx: ExecutionContext) => {
    const request = ctx.switchToHttp().getRequest();
    const page = parseInt(request.query.page) || 1;
    const limit = parseInt(request.query.limit) || 10;

    return {
      page,
      limit,
      skip: (page - 1) * limit,
    };
  },
);
```

```typescript
// users/users.controller.ts
import { Controller, Get, Query } from '@nestjs/common';
import { Pagination } from '../common/decorators/pagination.decorator';

@Controller('users')
export class UsersController {
  @Get()
  async findAll(@Pagination() pagination: PaginationParams) {
    return this.usersService.findAll(pagination);
  }
}
```

**ソート:**

```typescript
// クエリ例: GET /users?sortBy=createdAt&order=desc

interface SortQuery {
  sortBy?: string; // デフォルト: 'createdAt'
  order?: 'asc' | 'desc'; // デフォルト: 'desc'
}

// common/decorators/sort.decorator.ts
export const Sort = createParamDecorator(
  (data: unknown, ctx: ExecutionContext) => {
    const request = ctx.switchToHttp().getRequest();
    return {
      sortBy: request.query.sortBy || 'createdAt',
      order: request.query.order || 'desc',
    };
  },
);
```

**フィルタリング:**

```typescript
// クエリ例: GET /users?status=active&role=admin&search=john

interface FilterQuery {
  status?: string;
  role?: string;
  search?: string;
  // その他のフィルタ
}

// users/users.controller.ts
@Get()
async findAll(
  @Query('status') status?: string,
  @Query('role') role?: string,
  @Query('search') search?: string,
  @Pagination() pagination?: PaginationParams,
  @Sort() sort?: SortParams,
) {
  return this.usersService.findAll({
    filters: { status, role, search },
    pagination,
    sort,
  });
}
```

**統合例:**

```typescript
// users/users.service.ts
async findAll({
  filters,
  pagination,
  sort,
}: {
  filters: FilterQuery;
  pagination: PaginationParams;
  sort: SortParams;
}) {
  const where: any = {};

  // フィルタ適用
  if (filters.status) {
    where.status = filters.status;
  }
  if (filters.role) {
    where.role = filters.role;
  }
  if (filters.search) {
    where.OR = [
      { name: { contains: filters.search, mode: 'insensitive' } },
      { email: { contains: filters.search, mode: 'insensitive' } },
    ];
  }

  // データ取得
  const [users, total] = await Promise.all([
    this.prisma.user.findMany({
      where,
      skip: pagination.skip,
      take: pagination.limit,
      orderBy: {
        [sort.sortBy]: sort.order,
      },
    }),
    this.prisma.user.count({ where }),
  ]);

  return {
    data: users,
    meta: {
      total,
      page: pagination.page,
      limit: pagination.limit,
      totalPages: Math.ceil(total / pagination.limit),
    },
  };
}
```

### GraphQL vs REST

#### RESTが適切な場合

**推奨シナリオ:**
- シンプルなCRUD操作
- キャッシングが重要（CDN、HTTPキャッシュ）
- ファイルアップロード/ダウンロード
- チームのGraphQL経験が少ない
- 既存のRESTエコシステムとの統合

**メリット:**
- シンプルで理解しやすい
- HTTPキャッシングが容易
- 広く採用されている（ツール、ライブラリが豊富）
- ステータスコードが明確

**デメリット:**
- Over-fetching/Under-fetching
- 複雑なリレーションの取得が困難
- バージョニングが必要

#### GraphQLが適切な場合

**推奨シナリオ:**
- 複雑なデータ構造とリレーション
- モバイルアプリ（データ転送量削減）
- 頻繁に変わるデータ要件
- リアルタイム機能（Subscription）

**メリット:**
- クライアントが必要なデータのみ取得
- 単一エンドポイント
- 強い型システム
- リレーションの取得が容易

**デメリット:**
- 学習コストが高い
- HTTPキャッシングが困難
- ファイルアップロードが複雑
- N+1クエリ問題（DataLoaderで解決）

#### ハイブリッドアプローチ

**実践例:**

```typescript
// REST: シンプルな認証
POST /auth/login
POST /auth/logout
POST /auth/refresh

// GraphQL: 複雑なデータ取得
POST /graphql
{
  user(id: "123") {
    name
    email
    orders {
      id
      total
      items {
        product {
          name
          price
        }
        quantity
      }
    }
    friends {
      name
      email
    }
  }
}

// REST: ファイルアップロード
POST /files/upload
```

**判断フローチャート:**

```
データ要件が複雑？
├─ Yes → モバイルアプリ？
│   ├─ Yes → GraphQL
│   └─ No → リアルタイムが必要？
│       ├─ Yes → GraphQL
│       └─ No → チームのGraphQL経験は？
│           ├─ 十分 → GraphQL
│           └─ 不足 → REST
└─ No → ファイル操作が必要？
    ├─ Yes → REST
    └─ No → キャッシングが重要？
        ├─ Yes → REST
        └─ No → どちらでも可（RESTがシンプル）
```

---

## 3. データスキーマ設計

### ORM選択

#### Prisma推奨理由

**主な利点:**
1. **型安全性**: TypeScriptの型が自動生成される
2. **直感的なAPI**: クエリが読みやすく書きやすい
3. **マイグレーション**: 宣言的スキーマから自動生成
4. **パフォーマンス**: 最適化されたクエリ
5. **開発体験**: 優れたVSCode補完

**比較表:**

| 特徴 | Prisma | TypeORM | Sequelize |
|------|--------|---------|-----------|
| 型安全性 | ✅ 完全 | ⚠️ 部分的 | ❌ なし |
| クエリAPI | 直感的 | Active Record | Promise-based |
| マイグレーション | 宣言的 | コード生成 | CLI |
| パフォーマンス | 高速 | 中程度 | 中程度 |
| 学習曲線 | 緩やか | 急 | 緩やか |
| TypeScript対応 | ✅ ネイティブ | ✅ サポート | ⚠️ 型定義のみ |

#### Prismaセットアップ

```bash
# インストール
npm install prisma @prisma/client
npx prisma init
```

**スキーマ定義:**

```prisma
// prisma/schema.prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id        String   @id @default(uuid())
  email     String   @unique
  name      String
  password  String
  role      Role     @default(USER)
  isActive  Boolean  @default(true)
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  profile Profile?
  orders  Order[]
  posts   Post[]

  @@index([email])
  @@map("users")
}

model Profile {
  id        String   @id @default(uuid())
  userId    String   @unique
  bio       String?
  avatar    String?
  phone     String?
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@map("profiles")
}

model Post {
  id          String   @id @default(uuid())
  title       String
  content     String
  published   Boolean  @default(false)
  authorId    String
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt

  author User @relation(fields: [authorId], references: [id])

  @@index([authorId])
  @@index([published])
  @@map("posts")
}

model Order {
  id        String      @id @default(uuid())
  userId    String
  total     Decimal     @db.Decimal(10, 2)
  status    OrderStatus @default(PENDING)
  createdAt DateTime    @default(now())
  updatedAt DateTime    @updatedAt

  user  User        @relation(fields: [userId], references: [id])
  items OrderItem[]

  @@index([userId])
  @@index([status])
  @@map("orders")
}

model OrderItem {
  id        String   @id @default(uuid())
  orderId   String
  productId String
  quantity  Int
  price     Decimal  @db.Decimal(10, 2)
  createdAt DateTime @default(now())

  order   Order   @relation(fields: [orderId], references: [id], onDelete: Cascade)
  product Product @relation(fields: [productId], references: [id])

  @@index([orderId])
  @@index([productId])
  @@map("order_items")
}

model Product {
  id          String   @id @default(uuid())
  name        String
  description String?
  price       Decimal  @db.Decimal(10, 2)
  stock       Int      @default(0)
  isActive    Boolean  @default(true)
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt

  orderItems OrderItem[]

  @@index([isActive])
  @@map("products")
}

enum Role {
  USER
  ADMIN
  MODERATOR
}

enum OrderStatus {
  PENDING
  PROCESSING
  SHIPPED
  DELIVERED
  CANCELLED
}
```

**NestJS統合:**

```typescript
// prisma/prisma.module.ts
import { Module, Global } from '@nestjs/common';
import { PrismaService } from './prisma.service';

@Global()
export class PrismaModule {
  constructor(private readonly prisma: PrismaService) {}

  async onModuleInit() {
    await this.prisma.$connect();
  }

  async onModuleDestroy() {
    await this.prisma.$disconnect();
  }
}
```

```typescript
// prisma/prisma.service.ts
import { Injectable, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService
  extends PrismaClient
  implements OnModuleInit, OnModuleDestroy
{
  async onModuleInit() {
    await this.$connect();
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }
}
```

**使用例:**

```typescript
// users/users.repository.ts
import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Prisma } from '@prisma/client';

@Injectable()
export class UsersRepository {
  constructor(private readonly prisma: PrismaService) {}

  async create(data: Prisma.UserCreateInput) {
    return this.prisma.user.create({ data });
  }

  async findMany(args?: Prisma.UserFindManyArgs) {
    return this.prisma.user.findMany(args);
  }

  async findById(id: string) {
    return this.prisma.user.findUnique({
      where: { id },
      include: {
        profile: true,
        orders: {
          orderBy: { createdAt: 'desc' },
          take: 5,
        },
      },
    });
  }

  async update(id: string, data: Prisma.UserUpdateInput) {
    return this.prisma.user.update({
      where: { id },
      data,
    });
  }

  async delete(id: string) {
    return this.prisma.user.delete({
      where: { id },
    });
  }

  async count(where?: Prisma.UserWhereInput) {
    return this.prisma.user.count({ where });
  }
}
```

---

## 4. エラーハンドリングとログ

### ログレベル設計

**標準ログレベルとその用途:**

| レベル | 用途 | 環境 | 例 |
|--------|------|------|-----|
| **trace** | 詳細デバッグ情報 | 開発のみ | 関数の入出力、ループの各イテレーション |
| **debug** | デバッグ情報 | 開発・ステージング | SQL クエリ、API リクエスト詳細 |
| **info** | 正常な操作記録 | 全環境 | ユーザーログイン、注文作成 |
| **warn** | 注意が必要だが正常動作 | 全環境 | 非推奨 API 使用、再試行成功 |
| **error** | エラー発生（復旧可能） | 全環境 | バリデーションエラー、外部 API エラー |
| **fatal** | 致命的エラー（アプリ停止） | 全環境 | DB 接続失敗、必須サービス停止 |

**実装例（winston）:**

```typescript
// common/logger/logger.service.ts
import { Injectable, LoggerService } from '@nestjs/common';
import * as winston from 'winston';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class CustomLogger implements LoggerService {
  private logger: winston.Logger;

  constructor(private readonly configService: ConfigService) {
    const environment = this.configService.get('NODE_ENV');

    this.logger = winston.createLogger({
      level: environment === 'production' ? 'info' : 'debug',
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.errors({ stack: true }),
        winston.format.json(),
      ),
      defaultMeta: {
        service: 'api',
        environment,
      },
      transports: [
        // Console transport
        new winston.transports.Console({
          format: winston.format.combine(
            winston.format.colorize(),
            winston.format.printf(({ timestamp, level, message, ...meta }) => {
              return `${timestamp} [${level}]: ${message} ${
                Object.keys(meta).length ? JSON.stringify(meta, null, 2) : ''
              }`;
            }),
          ),
        }),
        // File transport（本番環境）
        ...(environment === 'production'
          ? [
              new winston.transports.File({
                filename: 'logs/error.log',
                level: 'error',
              }),
              new winston.transports.File({
                filename: 'logs/combined.log',
              }),
            ]
          : []),
      ],
    });
  }

  log(message: string, context?: string, meta?: Record<string, unknown>) {
    this.logger.info(message, { context, ...meta });
  }

  error(
    message: string,
    trace?: string,
    context?: string,
    meta?: Record<string, unknown>,
  ) {
    this.logger.error(message, { trace, context, ...meta });
  }

  warn(message: string, context?: string, meta?: Record<string, unknown>) {
    this.logger.warn(message, { context, ...meta });
  }

  debug(message: string, context?: string, meta?: Record<string, unknown>) {
    this.logger.debug(message, { context, ...meta });
  }

  verbose(message: string, context?: string, meta?: Record<string, unknown>) {
    this.logger.verbose(message, { context, ...meta });
  }
}
```

### 構造化ログ

**ベストプラクティス:**

1. **[Object object]を避ける**
2. **リクエスト/レスポンスのパラメータを含める**
3. **機密情報を含めない**
4. **一貫したフォーマット**
5. **コンテキスト情報を追加**

```typescript
// ❌ 悪い例
logger.log('User created', user); // [Object object]
logger.log('Error occurred', error); // スタックトレースが含まれない
logger.log('Payment processed'); // コンテキスト不足

// ✅ 良い例
logger.log('User created', {
  userId: user.id,
  email: user.email, // パスワードは含めない
  role: user.role,
});

logger.error('Error occurred', {
  error: error.message,
  stack: error.stack,
  context: 'UsersService.create',
});

logger.log('Payment processed', {
  orderId: order.id,
  amount: order.total,
  paymentMethod: payment.method,
  transactionId: payment.transactionId,
});
```

**リクエストロギングミドルウェア:**

```typescript
// common/middleware/request-logger.middleware.ts
import { Injectable, NestMiddleware } from '@nestjs/common';
import { Request, Response, NextFunction } from 'express';
import { CustomLogger } from '../logger/logger.service';

@Injectable()
export class RequestLoggerMiddleware implements NestMiddleware {
  constructor(private readonly logger: CustomLogger) {}

  use(req: Request, res: Response, next: NextFunction) {
    const { method, originalUrl, ip } = req;
    const userAgent = req.get('user-agent') || '';
    const startTime = Date.now();

    // レスポンス完了時にログ出力
    res.on('finish', () => {
      const { statusCode } = res;
      const duration = Date.now() - startTime;

      const logData = {
        method,
        url: originalUrl,
        statusCode,
        duration: `${duration}ms`,
        ip,
        userAgent,
        // 機密情報は含めない
        query: this.sanitizeQuery(req.query),
        params: req.params,
      };

      if (statusCode >= 500) {
        this.logger.error('HTTP Request', undefined, 'HTTP', logData);
      } else if (statusCode >= 400) {
        this.logger.warn('HTTP Request', 'HTTP', logData);
      } else {
        this.logger.log('HTTP Request', 'HTTP', logData);
      }
    });

    next();
  }

  private sanitizeQuery(query: Record<string, unknown>): Record<string, unknown> {
    const sanitized = { ...query };
    // パスワードやトークンを除外
    const sensitiveFields = ['password', 'token', 'apiKey', 'secret'];
    sensitiveFields.forEach((field) => {
      if (field in sanitized) {
        sanitized[field] = '[REDACTED]';
      }
    });
    return sanitized;
  }
}
```

**適用:**

```typescript
// app.module.ts
import { Module, NestModule, MiddlewareConsumer } from '@nestjs/common';
import { RequestLoggerMiddleware } from './common/middleware/request-logger.middleware';

@Module({
  // ...
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(RequestLoggerMiddleware).forRoutes('*');
  }
}
```

### try-catchパターン

#### NestJSでのエラーハンドリング

**基本パターン:**

```typescript
// users/users.service.ts
import {
  Injectable,
  NotFoundException,
  BadRequestException,
  InternalServerErrorException,
} from '@nestjs/common';
import { CustomLogger } from '../common/logger/logger.service';

@Injectable()
export class UsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly logger: CustomLogger,
  ) {}

  async create(createUserDto: CreateUserDto) {
    try {
      // メールアドレスの重複チェック
      const existingUser = await this.prisma.user.findUnique({
        where: { email: createUserDto.email },
      });

      if (existingUser) {
        throw new BadRequestException('Email already exists');
      }

      const user = await this.prisma.user.create({
        data: createUserDto,
      });

      this.logger.log('User created successfully', 'UsersService', {
        userId: user.id,
        email: user.email,
      });

      return user;
    } catch (error) {
      // NestJSのHttpExceptionはそのまま投げる
      if (error instanceof HttpException) {
        throw error;
      }

      // その他のエラーはログを残して500エラーに変換
      this.logger.error('Failed to create user', error.stack, 'UsersService', {
        email: createUserDto.email,
        error: error.message,
      });

      throw new InternalServerErrorException('Failed to create user');
    }
  }

  async findOne(id: string) {
    try {
      const user = await this.prisma.user.findUnique({
        where: { id },
      });

      if (!user) {
        throw new NotFoundException(`User with ID ${id} not found`);
      }

      return user;
    } catch (error) {
      if (error instanceof HttpException) {
        throw error;
      }

      this.logger.error('Failed to find user', error.stack, 'UsersService', {
        userId: id,
        error: error.message,
      });

      throw new InternalServerErrorException('Failed to find user');
    }
  }
}
```

#### カスタムHttpException

```typescript
// common/exceptions/business-logic.exception.ts
import { HttpException, HttpStatus } from '@nestjs/common';

export class InsufficientStockException extends HttpException {
  constructor(productId: string, requested: number, available: number) {
    super(
      {
        statusCode: HttpStatus.UNPROCESSABLE_ENTITY,
        error: 'Insufficient Stock',
        message: `Product ${productId} has insufficient stock. Requested: ${requested}, Available: ${available}`,
        details: {
          productId,
          requested,
          available,
        },
      },
      HttpStatus.UNPROCESSABLE_ENTITY,
    );
  }
}

export class PaymentFailedException extends HttpException {
  constructor(reason: string, orderId: string) {
    super(
      {
        statusCode: HttpStatus.PAYMENT_REQUIRED,
        error: 'Payment Failed',
        message: `Payment failed: ${reason}`,
        details: {
          orderId,
          reason,
        },
      },
      HttpStatus.PAYMENT_REQUIRED,
    );
  }
}
```

**使用例:**

```typescript
// orders/orders.service.ts
async createOrder(createOrderDto: CreateOrderDto) {
  try {
    // 在庫チェック
    const product = await this.prisma.product.findUnique({
      where: { id: createOrderDto.productId },
    });

    if (product.stock < createOrderDto.quantity) {
      throw new InsufficientStockException(
        product.id,
        createOrderDto.quantity,
        product.stock,
      );
    }

    // 注文作成
    const order = await this.prisma.order.create({
      data: createOrderDto,
    });

    return order;
  } catch (error) {
    if (error instanceof HttpException) {
      throw error;
    }

    this.logger.error('Failed to create order', error.stack, 'OrdersService', {
      productId: createOrderDto.productId,
      error: error.message,
    });

    throw new InternalServerErrorException('Failed to create order');
  }
}
```

#### エラーレスポンスの統一

```typescript
// common/filters/all-exceptions.filter.ts
import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { Request, Response } from 'express';
import { CustomLogger } from '../logger/logger.service';

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  constructor(private readonly logger: CustomLogger) {}

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let message = 'Internal server error';
    let error = 'Internal Server Error';
    let details: Record<string, unknown> | undefined;

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const exceptionResponse = exception.getResponse();

      if (typeof exceptionResponse === 'object') {
        message = (exceptionResponse as any).message || message;
        error = (exceptionResponse as any).error || error;
        details = (exceptionResponse as any).details;
      } else {
        message = exceptionResponse;
      }
    } else if (exception instanceof Error) {
      message = exception.message;

      // Prismaエラーのハンドリング
      if (exception.constructor.name.startsWith('Prisma')) {
        status = HttpStatus.BAD_REQUEST;
        error = 'Database Error';
        message = 'Database operation failed';
      }
    }

    const errorResponse = {
      statusCode: status,
      timestamp: new Date().toISOString(),
      path: request.url,
      method: request.method,
      message,
      error,
      ...(details && { details }),
    };

    // エラーログ
    this.logger.error('Exception caught', undefined, 'ExceptionFilter', {
      ...errorResponse,
      stack: exception instanceof Error ? exception.stack : undefined,
    });

    response.status(status).json(errorResponse);
  }
}
```

**グローバル適用:**

```typescript
// main.ts
import { NestFactory } from '@nestjs/core';
import { AllExceptionsFilter } from './common/filters/all-exceptions.filter';
import { CustomLogger } from './common/logger/logger.service';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  const logger = app.get(CustomLogger);
  app.useGlobalFilters(new AllExceptionsFilter(logger));

  await app.listen(3000);
}
bootstrap();
```

---

## 5. キャッシング戦略

### キャッシュレイヤー

**3層キャッシング戦略:**

```
リクエスト
    ↓
① CDNキャッシュ（静的コンテンツ、公開API）
    ↓ キャッシュミス
② アプリケーションキャッシュ（Redis、頻繁にアクセスされるデータ）
    ↓ キャッシュミス
③ データベースキャッシュ（クエリ結果キャッシュ）
    ↓
データベース
```

#### ① CDNキャッシュ

**適用対象:**
- 静的アセット（画像、CSS、JavaScript）
- 公開API（認証不要、全ユーザー共通）
- 頻繁に変わらないコンテンツ

**実装例（Cache-Controlヘッダー）:**

```typescript
// common/interceptors/cache-control.interceptor.ts
import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';

@Injectable()
export class CacheControlInterceptor implements NestInterceptor {
  constructor(private readonly maxAge: number) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    return next.handle().pipe(
      tap(() => {
        const response = context.switchToHttp().getResponse();
        response.set('Cache-Control', `public, max-age=${this.maxAge}`);
      }),
    );
  }
}
```

```typescript
// products/products.controller.ts
import { Controller, Get, UseInterceptors } from '@nestjs/common';
import { CacheControlInterceptor } from '../common/interceptors/cache-control.interceptor';

@Controller('products')
export class ProductsController {
  // 1時間キャッシュ
  @Get()
  @UseInterceptors(new CacheControlInterceptor(3600))
  async findAll() {
    return this.productsService.findAll();
  }

  // キャッシュなし（認証が必要なエンドポイント）
  @Get('my-orders')
  @UseGuards(JwtAuthGuard)
  async getMyOrders() {
    return this.ordersService.findMyOrders();
  }
}
```

#### ② アプリケーションレベルキャッシュ（Redis）

**適用対象:**
- 頻繁にアクセスされるデータ（ユーザープロフィール、商品情報）
- 計算コストの高いデータ（集計、レポート）
- セッションデータ

**Redisセットアップ:**

```bash
npm install @nestjs/cache-manager cache-manager cache-manager-redis-store redis
```

```typescript
// cache/cache.module.ts
import { Module } from '@nestjs/common';
import { CacheModule as NestCacheModule } from '@nestjs/cache-manager';
import { ConfigModule, ConfigService } from '@nestjs/config';
import * as redisStore from 'cache-manager-redis-store';

@Module({
  imports: [
    NestCacheModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: async (configService: ConfigService) => ({
        store: redisStore,
        host: configService.get('REDIS_HOST'),
        port: configService.get('REDIS_PORT'),
        ttl: 60, // デフォルトTTL（秒）
      }),
    }),
  ],
  exports: [NestCacheModule],
})
export class CacheModule {}
```

### Redis統合

#### キャッシュキー設計

**ベストプラクティス:**

```typescript
// ❌ 悪い例
const key = 'user'; // 曖昧すぎる
const key = '123'; // 何のIDか不明

// ✅ 良い例
const key = 'user:123'; // ユーザーID 123
const key = 'user:123:profile'; // ユーザー123のプロフィール
const key = 'product:456:details'; // 商品456の詳細
const key = 'orders:user:123:page:1'; // ユーザー123の注文（1ページ目）
const key = 'stats:daily:2024-01-15'; // 2024年1月15日の統計
```

**キーパターン:**

```
<resource>:<id>:<subresource>:<qualifier>

例:
- user:123
- user:123:orders
- product:456
- product:456:reviews:page:2
- cart:session:abc123
```

#### TTL（Time to Live）設定

**推奨TTL:**

| データタイプ | TTL | 理由 |
|-------------|-----|------|
| ユーザーセッション | 1-24時間 | セキュリティとUXのバランス |
| 商品情報 | 5-15分 | 在庫変動への対応 |
| ユーザープロフィール | 30分-1時間 | 頻繁な変更はない |
| 統計・集計データ | 1-24時間 | 計算コスト削減 |
| 静的コンテンツ | 1週間-1ヶ月 | ほとんど変わらない |
| リアルタイムデータ | 10-60秒 | 鮮度が重要 |

**実装例:**

```typescript
// products/products.service.ts
import { Injectable, Inject } from '@nestjs/common';
import { CACHE_MANAGER } from '@nestjs/cache-manager';
import { Cache } from 'cache-manager';

@Injectable()
export class ProductsService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(CACHE_MANAGER) private readonly cacheManager: Cache,
  ) {}

  async findOne(id: string) {
    const cacheKey = `product:${id}`;

    // キャッシュチェック
    const cached = await this.cacheManager.get(cacheKey);
    if (cached) {
      return cached;
    }

    // DBから取得
    const product = await this.prisma.product.findUnique({
      where: { id },
    });

    if (!product) {
      throw new NotFoundException(`Product with ID ${id} not found`);
    }

    // キャッシュに保存（TTL: 10分）
    await this.cacheManager.set(cacheKey, product, 600);

    return product;
  }

  async update(id: string, updateProductDto: UpdateProductDto) {
    const product = await this.prisma.product.update({
      where: { id },
      data: updateProductDto,
    });

    // キャッシュ無効化
    const cacheKey = `product:${id}`;
    await this.cacheManager.del(cacheKey);

    return product;
  }
}
```

#### キャッシュ無効化戦略

**1. Write-through（書き込み時に更新）**

```typescript
async updateUser(id: string, data: UpdateUserDto) {
  // DBを更新
  const user = await this.prisma.user.update({
    where: { id },
    data,
  });

  // キャッシュを更新
  const cacheKey = `user:${id}`;
  await this.cacheManager.set(cacheKey, user, 3600);

  return user;
}
```

**2. Cache-aside（読み取り時にキャッシュ）**

```typescript
async getUser(id: string) {
  const cacheKey = `user:${id}`;

  // キャッシュチェック
  let user = await this.cacheManager.get(cacheKey);

  if (!user) {
    // キャッシュミス：DBから取得
    user = await this.prisma.user.findUnique({ where: { id } });
    await this.cacheManager.set(cacheKey, user, 3600);
  }

  return user;
}
```

**3. Invalidation on write（書き込み時に削除）**

```typescript
async updateUser(id: string, data: UpdateUserDto) {
  const user = await this.prisma.user.update({
    where: { id },
    data,
  });

  // キャッシュを削除（次回読み取り時に再キャッシュ）
  const cacheKey = `user:${id}`;
  await this.cacheManager.del(cacheKey);

  return user;
}
```

**パターン選択:**

| パターン | メリット | デメリット | 適用場面 |
|---------|---------|-----------|---------|
| Write-through | 常に最新データ | 書き込みが遅い | 読み取りが多い |
| Cache-aside | 書き込みが速い | 一時的に古いデータ | バランス型 |
| Invalidation | シンプル | 読み取り時にDBアクセス | 更新頻度が低い |

#### キャッシュの落とし穴

**1. デバッグが困難**

```typescript
// 問題: キャッシュされたデータが古いが、気づかない
async getProduct(id: string) {
  const cached = await this.cache.get(`product:${id}`);
  if (cached) {
    // ここで古いデータが返される可能性
    return cached;
  }
  // ...
}

// 解決策: デバッグモードでキャッシュをバイパス
async getProduct(id: string, bypassCache = false) {
  if (!bypassCache) {
    const cached = await this.cache.get(`product:${id}`);
    if (cached) {
      return { ...cached, _cached: true }; // キャッシュされたことを示す
    }
  }
  // ...
}
```

**2. キャッシュの不整合**

```typescript
// 問題: 関連データのキャッシュが同期されない
async updateProduct(id: string, data: UpdateProductDto) {
  const product = await this.prisma.product.update({
    where: { id },
    data,
  });

  // 商品キャッシュは削除するが...
  await this.cache.del(`product:${id}`);

  // 商品リストのキャッシュは残ったまま！
  // `products:list` には古いデータが残る
}

// 解決策: 関連キャッシュもすべて削除
async updateProduct(id: string, data: UpdateProductDto) {
  const product = await this.prisma.product.update({
    where: { id },
    data,
  });

  // すべての関連キャッシュを削除
  await Promise.all([
    this.cache.del(`product:${id}`),
    this.cache.del('products:list'), // リスト
    this.cache.del(`products:category:${product.categoryId}`), // カテゴリ別
  ]);

  return product;
}
```

**3. キャッシュスタンピード**

```typescript
// 問題: キャッシュ期限切れ時に大量のリクエストがDBに到達
async getPopularProducts() {
  const cached = await this.cache.get('products:popular');
  if (cached) return cached;

  // 期限切れ時、複数のリクエストが同時にここに到達
  const products = await this.prisma.product.findMany({
    orderBy: { views: 'desc' },
    take: 10,
  });

  await this.cache.set('products:popular', products, 3600);
  return products;
}

// 解決策: ロックを使用
import { Mutex } from 'async-mutex';

class ProductsService {
  private mutex = new Mutex();

  async getPopularProducts() {
    const cacheKey = 'products:popular';
    const cached = await this.cache.get(cacheKey);
    if (cached) return cached;

    // ロックを取得（最初のリクエストのみDBにアクセス）
    return this.mutex.runExclusive(async () => {
      // 再度キャッシュチェック（ロック待ち中に他のリクエストが保存したかも）
      const recheck = await this.cache.get(cacheKey);
      if (recheck) return recheck;

      const products = await this.prisma.product.findMany({
        orderBy: { views: 'desc' },
        take: 10,
      });

      await this.cache.set(cacheKey, products, 3600);
      return products;
    });
  }
}
```

### パフォーマンスメトリクス

#### レイテンシとパーセンタイル

**主要メトリクス:**

| メトリクス | 意味 | 目標値 | 重要度 |
|-----------|------|--------|--------|
| **平均レイテンシ** | 全リクエストの平均応答時間 | < 200ms | ⚠️ 参考程度 |
| **P50（中央値）** | 50%のリクエストがこの時間以下 | < 100ms | ⚡ 重要 |
| **P90** | 90%のリクエストがこの時間以下 | < 300ms | ⚡⚡ 非常に重要 |
| **P95** | 95%のリクエストがこの時間以下 | < 500ms | ⚡⚡⚡ 最重要 |
| **P99** | 99%のリクエストがこの時間以下 | < 1000ms | ⚡ 重要 |

**なぜ平均ではダメか:**

```
リクエスト10回の応答時間:
100ms, 100ms, 100ms, 100ms, 100ms, 100ms, 100ms, 100ms, 100ms, 5000ms

平均: 600ms（悪くない？）
P90:  100ms（実際は90%のユーザーが100ms以下）
P99:  5000ms（1%のユーザーが5秒待たされている！）

→ 平均だけ見ると問題に気づかない
```

**実装例（カスタムインターセプター）:**

```typescript
// common/interceptors/performance.interceptor.ts
import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';
import { CustomLogger } from '../logger/logger.service';

@Injectable()
export class PerformanceInterceptor implements NestInterceptor {
  constructor(private readonly logger: CustomLogger) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const request = context.switchToHttp().getRequest();
    const { method, url } = request;
    const startTime = Date.now();

    return next.handle().pipe(
      tap(() => {
        const duration = Date.now() - startTime;

        // 500ms以上は警告
        if (duration > 500) {
          this.logger.warn('Slow request detected', 'Performance', {
            method,
            url,
            duration: `${duration}ms`,
          });
        }

        // メトリクスをDatadogなどに送信
        // this.metricsService.recordLatency(url, duration);
      }),
    );
  }
}
```

#### Apdexスコア

**Application Performance Index（アプリケーション性能指標）:**

```
Apdex = (満足数 + 許容数 / 2) / 総数

満足: レイテンシ <= T
許容: T < レイテンシ <= 4T
不満: レイテンシ > 4T

T = 目標応答時間（例: 500ms）

スコア:
1.0 = 完璧
0.94-1.0 = 優秀
0.85-0.93 = 良好
0.7-0.84 = 普通
0.5-0.69 = 悪い
0.0-0.49 = 非常に悪い
```

**実装例:**

```typescript
// metrics/apdex.service.ts
@Injectable()
export class ApdexService {
  private readonly TARGET_TIME = 500; // 500ms

  calculateApdex(latencies: number[]): number {
    let satisfied = 0;
    let tolerating = 0;
    let frustrated = 0;

    for (const latency of latencies) {
      if (latency <= this.TARGET_TIME) {
        satisfied++;
      } else if (latency <= this.TARGET_TIME * 4) {
        tolerating++;
      } else {
        frustrated++;
      }
    }

    const total = latencies.length;
    const apdex = (satisfied + tolerating / 2) / total;

    return Math.round(apdex * 100) / 100; // 小数点2桁
  }

  getApdexRating(score: number): string {
    if (score >= 0.94) return 'Excellent';
    if (score >= 0.85) return 'Good';
    if (score >= 0.7) return 'Fair';
    if (score >= 0.5) return 'Poor';
    return 'Unacceptable';
  }
}
```

#### サーバー負荷

**主要メトリクス:**

```typescript
// metrics/server-metrics.service.ts
import * as os from 'os';

@Injectable()
export class ServerMetricsService {
  getCpuUsage(): number {
    const cpus = os.cpus();
    let totalIdle = 0;
    let totalTick = 0;

    cpus.forEach((cpu) => {
      for (const type in cpu.times) {
        totalTick += cpu.times[type];
      }
      totalIdle += cpu.times.idle;
    });

    const idle = totalIdle / cpus.length;
    const total = totalTick / cpus.length;
    const usage = 100 - (100 * idle) / total;

    return Math.round(usage * 100) / 100;
  }

  getMemoryUsage(): {
    total: number;
    used: number;
    free: number;
    usagePercent: number;
  } {
    const total = os.totalmem();
    const free = os.freemem();
    const used = total - free;
    const usagePercent = Math.round((used / total) * 10000) / 100;

    return {
      total: Math.round(total / 1024 / 1024), // MB
      used: Math.round(used / 1024 / 1024),
      free: Math.round(free / 1024 / 1024),
      usagePercent,
    };
  }

  getLoadAverage(): { '1min': number; '5min': number; '15min': number } {
    const loadAvg = os.loadavg();
    return {
      '1min': Math.round(loadAvg[0] * 100) / 100,
      '5min': Math.round(loadAvg[1] * 100) / 100,
      '15min': Math.round(loadAvg[2] * 100) / 100,
    };
  }
}
```

**ヘルスチェックエンドポイント:**

```typescript
// health/health.controller.ts
import { Controller, Get } from '@nestjs/common';
import { ServerMetricsService } from '../metrics/server-metrics.service';

@Controller('health')
export class HealthController {
  constructor(private readonly serverMetrics: ServerMetricsService) {}

  @Get()
  check() {
    const cpuUsage = this.serverMetrics.getCpuUsage();
    const memoryUsage = this.serverMetrics.getMemoryUsage();
    const loadAverage = this.serverMetrics.getLoadAverage();

    const status =
      cpuUsage < 80 && memoryUsage.usagePercent < 90 ? 'healthy' : 'unhealthy';

    return {
      status,
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      cpu: {
        usage: cpuUsage,
        cores: require('os').cpus().length,
      },
      memory: memoryUsage,
      load: loadAverage,
    };
  }
}
```

---

## 6. バックグラウンドジョブ

### キュー設計（BullMQ/Bull）

**BullMQ推奨理由:**
- Redisベース（高速、スケーラブル）
- 優先度キュー対応
- 自動リトライ
- ジョブの進捗追跡
- スケジューリング機能

**インストール:**

```bash
npm install @nestjs/bull bullmq
```

#### 基本セットアップ

```typescript
// queue/queue.module.ts
import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bull';
import { ConfigModule, ConfigService } from '@nestjs/config';

@Module({
  imports: [
    BullModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        redis: {
          host: configService.get('REDIS_HOST'),
          port: configService.get('REDIS_PORT'),
        },
      }),
    }),
  ],
})
export class QueueModule {}
```

#### キュー定義

```typescript
// emails/emails.module.ts
import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bull';
import { EmailsService } from './emails.service';
import { EmailProcessor } from './email.processor';

export const EMAIL_QUEUE = 'emails';

@Module({
  imports: [
    BullModule.registerQueue({
      name: EMAIL_QUEUE,
      defaultJobOptions: {
        attempts: 3, // 最大3回リトライ
        backoff: {
          type: 'exponential', // 指数バックオフ
          delay: 1000, // 初回は1秒後
        },
        removeOnComplete: true, // 完了後に削除
        removeOnFail: false, // 失敗時は保持
      },
    }),
  ],
  providers: [EmailsService, EmailProcessor],
  exports: [EmailsService],
})
export class EmailsModule {}
```

#### ジョブの追加

```typescript
// emails/emails.service.ts
import { Injectable } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bull';
import { Queue } from 'bull';
import { EMAIL_QUEUE } from './emails.module';

interface SendEmailJobData {
  to: string;
  subject: string;
  body: string;
  priority?: number;
}

@Injectable()
export class EmailsService {
  constructor(@InjectQueue(EMAIL_QUEUE) private readonly emailQueue: Queue) {}

  async sendWelcomeEmail(email: string, name: string) {
    await this.emailQueue.add(
      'welcome', // ジョブ名
      {
        to: email,
        subject: 'Welcome!',
        body: `Hello ${name}, welcome to our platform!`,
      } as SendEmailJobData,
      {
        priority: 1, // 高優先度
        delay: 0, // 即座に実行
      },
    );
  }

  async sendPasswordResetEmail(email: string, token: string) {
    await this.emailQueue.add(
      'password-reset',
      {
        to: email,
        subject: 'Password Reset',
        body: `Your reset token: ${token}`,
      } as SendEmailJobData,
      {
        priority: 1, // 高優先度
        attempts: 5, // 重要なので5回リトライ
      },
    );
  }

  async sendNewsletter(email: string, content: string) {
    await this.emailQueue.add(
      'newsletter',
      {
        to: email,
        subject: 'Newsletter',
        body: content,
      } as SendEmailJobData,
      {
        priority: 10, // 低優先度
        delay: 60000, // 1分後に送信
      },
    );
  }
}
```

#### ジョブの処理

```typescript
// emails/email.processor.ts
import { Processor, Process, OnQueueActive, OnQueueCompleted, OnQueueFailed } from '@nestjs/bull';
import { Job } from 'bull';
import { EMAIL_QUEUE } from './emails.module';
import { CustomLogger } from '../common/logger/logger.service';

interface SendEmailJobData {
  to: string;
  subject: string;
  body: string;
}

@Processor(EMAIL_QUEUE)
export class EmailProcessor {
  constructor(private readonly logger: CustomLogger) {}

  @Process('welcome')
  async handleWelcomeEmail(job: Job<SendEmailJobData>) {
    this.logger.log(`Processing welcome email for ${job.data.to}`, 'EmailProcessor');

    // 実際のメール送信ロジック
    await this.sendEmail(job.data);

    return { sent: true, to: job.data.to };
  }

  @Process('password-reset')
  async handlePasswordResetEmail(job: Job<SendEmailJobData>) {
    this.logger.log(`Processing password reset email for ${job.data.to}`, 'EmailProcessor');

    await this.sendEmail(job.data);

    return { sent: true, to: job.data.to };
  }

  @Process('newsletter')
  async handleNewsletterEmail(job: Job<SendEmailJobData>) {
    this.logger.log(`Processing newsletter for ${job.data.to}`, 'EmailProcessor');

    await this.sendEmail(job.data);

    return { sent: true, to: job.data.to };
  }

  private async sendEmail(data: SendEmailJobData): Promise<void> {
    // 実際のメール送信（SendGrid、AWS SESなど）
    // await this.emailProvider.send(data);

    // シミュレーション
    await new Promise((resolve) => setTimeout(resolve, 1000));
  }

  @OnQueueActive()
  onActive(job: Job) {
    this.logger.log(`Processing job ${job.id} of type ${job.name}`, 'EmailProcessor');
  }

  @OnQueueCompleted()
  onCompleted(job: Job, result: unknown) {
    this.logger.log(`Completed job ${job.id}`, 'EmailProcessor', { result });
  }

  @OnQueueFailed()
  onFailed(job: Job, error: Error) {
    this.logger.error(
      `Failed job ${job.id} after ${job.attemptsMade} attempts`,
      error.stack,
      'EmailProcessor',
      {
        jobId: job.id,
        jobName: job.name,
        data: job.data,
      },
    );
  }
}
```

### ジョブの優先度設計

**優先度レベル:**

| 優先度 | 値 | 用途 | 例 |
|--------|-----|------|-----|
| **Critical** | 1 | 即座に処理が必要 | パスワードリセット、支払い確認 |
| **High** | 2-3 | 重要だが若干遅延可能 | ウェルカムメール、注文確認 |
| **Normal** | 4-6 | 通常の処理 | 通知メール、レポート生成 |
| **Low** | 7-9 | 遅延しても問題ない | ニュースレター、クリーンアップ |
| **Batch** | 10 | バッチ処理 | データエクスポート、統計集計 |

**実装例:**

```typescript
// notifications/notifications.service.ts
export enum NotificationPriority {
  CRITICAL = 1,
  HIGH = 2,
  NORMAL = 5,
  LOW = 8,
  BATCH = 10,
}

@Injectable()
export class NotificationsService {
  async sendNotification(
    userId: string,
    message: string,
    priority: NotificationPriority = NotificationPriority.NORMAL,
  ) {
    await this.notificationQueue.add(
      'send',
      { userId, message },
      { priority },
    );
  }

  // Critical: 即座に処理
  async sendSecurityAlert(userId: string, message: string) {
    await this.sendNotification(userId, message, NotificationPriority.CRITICAL);
  }

  // Batch: 低優先度
  async sendDailySummary(userId: string, summary: string) {
    await this.sendNotification(userId, summary, NotificationPriority.BATCH);
  }
}
```

### リトライ戦略

**エクスポネンシャルバックオフ:**

```typescript
// Retry schedule:
// 1st retry: 1秒後
// 2nd retry: 2秒後 (2^1 * 1秒)
// 3rd retry: 4秒後 (2^2 * 1秒)
// 4th retry: 8秒後 (2^3 * 1秒)
// 5th retry: 16秒後 (2^4 * 1秒)

BullModule.registerQueue({
  name: 'emails',
  defaultJobOptions: {
    attempts: 5,
    backoff: {
      type: 'exponential',
      delay: 1000,
    },
  },
});
```

**カスタムバックオフ:**

```typescript
// 固定間隔（5秒ごと）
backoff: {
  type: 'fixed',
  delay: 5000,
}

// カスタムロジック
backoff: {
  type: 'custom',
}

// プロセッサー内でカスタム処理
@Process('send-email')
async handleEmail(job: Job) {
  try {
    await this.sendEmail(job.data);
  } catch (error) {
    // 特定のエラーの場合は即座にリトライ
    if (error.code === 'RATE_LIMIT') {
      throw new Error('Rate limited, retry after 60s');
    }

    // その他のエラーは通常のバックオフ
    throw error;
  }
}
```

**条件付きリトライ:**

```typescript
@Process('payment')
async handlePayment(job: Job) {
  try {
    await this.processPayment(job.data);
  } catch (error) {
    // 一時的なエラーのみリトライ
    if (this.isTemporaryError(error)) {
      throw error; // リトライされる
    }

    // 永続的なエラーはリトライしない
    this.logger.error('Permanent payment error', error.stack, 'PaymentProcessor', {
      jobId: job.id,
      error: error.message,
    });

    // ジョブを完了扱いにして Dead Letter Queue に移動
    await this.moveToDeadLetter(job);
  }
}

private isTemporaryError(error: Error): boolean {
  const temporaryErrors = [
    'NETWORK_ERROR',
    'TIMEOUT',
    'SERVICE_UNAVAILABLE',
    'RATE_LIMIT',
  ];

  return temporaryErrors.some((code) => error.message.includes(code));
}
```

### デッドレターキュー

**失敗したジョブの管理:**

```typescript
// dead-letter/dead-letter.module.ts
import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bull';

export const DEAD_LETTER_QUEUE = 'dead-letter';

@Module({
  imports: [
    BullModule.registerQueue({
      name: DEAD_LETTER_QUEUE,
      defaultJobOptions: {
        removeOnComplete: false, // 完了後も保持
        removeOnFail: false,
      },
    }),
  ],
})
export class DeadLetterModule {}
```

```typescript
// emails/email.processor.ts
import { InjectQueue } from '@nestjs/bull';
import { Queue } from 'bull';
import { DEAD_LETTER_QUEUE } from '../dead-letter/dead-letter.module';

@Processor(EMAIL_QUEUE)
export class EmailProcessor {
  constructor(
    @InjectQueue(DEAD_LETTER_QUEUE) private readonly deadLetterQueue: Queue,
    private readonly logger: CustomLogger,
  ) {}

  @OnQueueFailed()
  async onFailed(job: Job, error: Error) {
    // 最大リトライ回数に達した場合
    if (job.attemptsMade >= job.opts.attempts) {
      this.logger.error(
        `Job ${job.id} exhausted all retries, moving to dead letter queue`,
        error.stack,
        'EmailProcessor',
      );

      // Dead Letter Queue に移動
      await this.deadLetterQueue.add('failed-email', {
        originalQueue: EMAIL_QUEUE,
        originalJobId: job.id,
        originalJobName: job.name,
        data: job.data,
        error: {
          message: error.message,
          stack: error.stack,
        },
        failedAt: new Date().toISOString(),
      });
    }
  }
}
```

**Dead Letter Queueの監視:**

```typescript
// dead-letter/dead-letter.processor.ts
@Processor(DEAD_LETTER_QUEUE)
export class DeadLetterProcessor {
  @Process('failed-email')
  async handleFailedEmail(job: Job) {
    // アラート送信（Slack、PagerDutyなど）
    await this.alertService.sendAlert({
      title: 'Failed Email Job',
      message: `Job ${job.data.originalJobId} failed after all retries`,
      severity: 'high',
      details: job.data,
    });

    // 管理者ダッシュボードに記録
    await this.prisma.failedJob.create({
      data: {
        queue: job.data.originalQueue,
        jobId: job.data.originalJobId,
        jobName: job.data.originalJobName,
        data: job.data.data,
        error: job.data.error,
        failedAt: job.data.failedAt,
      },
    });
  }
}
```

---

## 7. Cronジョブ

### スケジュール設計

**@nestjs/schedule使用:**

```bash
npm install @nestjs/schedule
```

```typescript
// app.module.ts
import { Module } from '@nestjs/common';
import { ScheduleModule } from '@nestjs/schedule';

@Module({
  imports: [
    ScheduleModule.forRoot(),
    // その他のモジュール
  ],
})
export class AppModule {}
```

#### Cron式の基本

```
# ┌───────────── 分 (0 - 59)
# │ ┌───────────── 時 (0 - 23)
# │ │ ┌───────────── 日 (1 - 31)
# │ │ │ ┌───────────── 月 (1 - 12)
# │ │ │ │ ┌───────────── 曜日 (0 - 7) (0と7は日曜日)
# │ │ │ │ │
# * * * * *
```

**よく使うパターン:**

| Cron式 | 意味 |
|--------|------|
| `0 0 * * *` | 毎日深夜0時 |
| `0 */6 * * *` | 6時間ごと |
| `*/15 * * * *` | 15分ごと |
| `0 9 * * 1-5` | 平日の午前9時 |
| `0 0 1 * *` | 毎月1日の深夜0時 |
| `0 0 * * 0` | 毎週日曜日の深夜0時 |

#### 実装例

```typescript
// tasks/tasks.service.ts
import { Injectable } from '@nestjs/common';
import { Cron, CronExpression, Interval, Timeout } from '@nestjs/schedule';
import { CustomLogger } from '../common/logger/logger.service';

@Injectable()
export class TasksService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly logger: CustomLogger,
  ) {}

  // 毎日深夜0時にデータクリーンアップ
  @Cron(CronExpression.EVERY_DAY_AT_MIDNIGHT)
  async handleDailyCleanup() {
    this.logger.log('Starting daily cleanup', 'TasksService');

    // 30日以上前の一時データを削除
    const result = await this.prisma.tempData.deleteMany({
      where: {
        createdAt: {
          lt: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000),
        },
      },
    });

    this.logger.log(`Daily cleanup completed: ${result.count} records deleted`, 'TasksService');
  }

  // 1時間ごとにキャッシュをウォームアップ
  @Cron('0 * * * *') // 毎時0分
  async handleCacheWarmup() {
    this.logger.log('Warming up cache', 'TasksService');

    // 人気商品をキャッシュに事前ロード
    const popularProducts = await this.prisma.product.findMany({
      orderBy: { views: 'desc' },
      take: 100,
    });

    await this.cacheManager.set('products:popular', popularProducts, 3600);
  }

  // 毎週月曜日の午前9時にレポート生成
  @Cron('0 9 * * 1')
  async handleWeeklyReport() {
    this.logger.log('Generating weekly report', 'TasksService');

    const report = await this.generateWeeklyReport();

    // レポートをメールで送信
    await this.emailService.sendWeeklyReport(report);
  }

  // 10秒ごとにヘルスチェック
  @Interval(10000)
  async handleHealthCheck() {
    const isHealthy = await this.checkSystemHealth();

    if (!isHealthy) {
      this.logger.error('System health check failed', undefined, 'TasksService');
      await this.alertService.sendAlert('System unhealthy');
    }
  }

  // アプリ起動5秒後に初期化処理
  @Timeout(5000)
  async handleInitialization() {
    this.logger.log('Running initialization tasks', 'TasksService');

    await this.initializeCache();
    await this.loadConfigurations();
  }
}
```

### 冪等性の確保

**問題: 同じジョブが複数回実行される可能性**

```typescript
// ❌ 悪い例: 冪等性がない
@Cron('0 0 * * *')
async handleDailyNotifications() {
  // ユーザー全員に通知を送信
  const users = await this.prisma.user.findMany();

  for (const user of users) {
    // 複数回実行されると重複通知が送られる
    await this.sendNotification(user.id, 'Daily summary');
  }
}

// ✅ 良い例: 冪等性がある
@Cron('0 0 * * *')
async handleDailyNotifications() {
  const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
  const lockKey = `daily-notification:${today}`;

  // ロックを取得（既に実行済みならスキップ）
  const lock = await this.cacheManager.get(lockKey);
  if (lock) {
    this.logger.log('Daily notifications already sent today', 'TasksService');
    return;
  }

  // ロックを設定（24時間有効）
  await this.cacheManager.set(lockKey, true, 86400);

  // 通知送信
  const users = await this.prisma.user.findMany();

  for (const user of users) {
    // 個別にも冪等性を確保
    const userLockKey = `notification:${user.id}:${today}`;
    const userLock = await this.cacheManager.get(userLockKey);

    if (!userLock) {
      await this.sendNotification(user.id, 'Daily summary');
      await this.cacheManager.set(userLockKey, true, 86400);
    }
  }
}
```

**データベースを使った冪等性:**

```typescript
// Prisma schema
model CronJob {
  id          String   @id @default(uuid())
  jobName     String
  executionDate String   // YYYY-MM-DD
  completedAt DateTime @default(now())

  @@unique([jobName, executionDate])
  @@map("cron_jobs")
}

// 実装
@Cron('0 0 * * *')
async handleDailyReport() {
  const today = new Date().toISOString().split('T')[0];
  const jobName = 'daily-report';

  try {
    // 重複実行を防止
    await this.prisma.cronJob.create({
      data: {
        jobName,
        executionDate: today,
      },
    });

    // レポート生成
    await this.generateReport();

    this.logger.log(`Daily report completed for ${today}`, 'TasksService');
  } catch (error) {
    // ユニーク制約違反 = 既に実行済み
    if (error.code === 'P2002') {
      this.logger.log(`Daily report already generated for ${today}`, 'TasksService');
      return;
    }

    throw error;
  }
}
```

### タイムゾーン考慮（UTC推奨）

**問題: サーバーのタイムゾーンに依存する**

```typescript
// ❌ 悪い例: サーバーのローカルタイムゾーンに依存
@Cron('0 9 * * *') // サーバーが東京にあれば JST 9:00
async handleMorningTask() {
  // サーバーを別のリージョンに移動すると実行時刻が変わる
}

// ✅ 良い例: UTC指定
@Cron('0 0 * * *', {
  timeZone: 'UTC', // UTC 0:00（JST 9:00）
})
async handleMorningTask() {
  // タイムゾーン明示で予測可能
}

// ✅ 良い例: 特定のタイムゾーン指定
@Cron('0 9 * * *', {
  timeZone: 'Asia/Tokyo', // JST 9:00
})
async handleMorningTaskJST() {
  // 日本時間の朝9時に実行
}
```

**タイムゾーン変換:**

```typescript
import { zonedTimeToUtc, utcToZonedTime, format } from 'date-fns-tz';

// ユーザーのタイムゾーンで通知を送る
async sendScheduledNotification(userId: string, userTimezone: string) {
  // ユーザーのタイムゾーンで午前9時
  const userTime = new Date();
  userTime.setHours(9, 0, 0, 0);

  // UTCに変換
  const utcTime = zonedTimeToUtc(userTime, userTimezone);

  // スケジュール
  await this.notificationQueue.add(
    'scheduled',
    { userId },
    { delay: utcTime.getTime() - Date.now() },
  );
}
```

---

## 8. サードパーティサービス統合

### 統合パターン

#### 抽象化レイヤーの作成

**問題: サードパーティサービスに直接依存すると変更が困難**

```typescript
// ❌ 悪い例: Stripeに直接依存
import Stripe from 'stripe';

@Injectable()
export class OrdersService {
  private stripe = new Stripe(process.env.STRIPE_SECRET_KEY);

  async createOrder(orderDto: CreateOrderDto) {
    // Stripeに直接依存
    const paymentIntent = await this.stripe.paymentIntents.create({
      amount: orderDto.total * 100,
      currency: 'usd',
    });

    // Stripe を PayPal に変更する場合、全コードを書き換える必要がある
  }
}
```

```typescript
// ✅ 良い例: 抽象化レイヤーを作成

// payments/interfaces/payment-provider.interface.ts
export interface PaymentProvider {
  createPaymentIntent(amount: number, currency: string): Promise<PaymentIntent>;
  confirmPayment(paymentIntentId: string): Promise<PaymentResult>;
  refund(paymentIntentId: string, amount?: number): Promise<RefundResult>;
}

export interface PaymentIntent {
  id: string;
  amount: number;
  currency: string;
  clientSecret: string;
}

export interface PaymentResult {
  success: boolean;
  transactionId: string;
}

export interface RefundResult {
  success: boolean;
  refundId: string;
}

// payments/providers/stripe.provider.ts
@Injectable()
export class StripeProvider implements PaymentProvider {
  private stripe: Stripe;

  constructor(private readonly configService: ConfigService) {
    this.stripe = new Stripe(this.configService.get('STRIPE_SECRET_KEY'));
  }

  async createPaymentIntent(amount: number, currency: string): Promise<PaymentIntent> {
    const paymentIntent = await this.stripe.paymentIntents.create({
      amount: amount * 100, // Stripeは cents単位
      currency,
    });

    return {
      id: paymentIntent.id,
      amount,
      currency,
      clientSecret: paymentIntent.client_secret,
    };
  }

  async confirmPayment(paymentIntentId: string): Promise<PaymentResult> {
    const paymentIntent = await this.stripe.paymentIntents.confirm(paymentIntentId);

    return {
      success: paymentIntent.status === 'succeeded',
      transactionId: paymentIntent.id,
    };
  }

  async refund(paymentIntentId: string, amount?: number): Promise<RefundResult> {
    const refund = await this.stripe.refunds.create({
      payment_intent: paymentIntentId,
      amount: amount ? amount * 100 : undefined,
    });

    return {
      success: refund.status === 'succeeded',
      refundId: refund.id,
    };
  }
}

// payments/providers/paypal.provider.ts（将来の実装）
@Injectable()
export class PayPalProvider implements PaymentProvider {
  // PayPal SDKを使った実装
  async createPaymentIntent(amount: number, currency: string): Promise<PaymentIntent> {
    // PayPal固有の実装
  }

  // ...
}

// orders/orders.service.ts
@Injectable()
export class OrdersService {
  constructor(
    @Inject('PAYMENT_PROVIDER') private readonly paymentProvider: PaymentProvider,
  ) {}

  async createOrder(orderDto: CreateOrderDto) {
    // 抽象化されたインターフェースを使用
    const paymentIntent = await this.paymentProvider.createPaymentIntent(
      orderDto.total,
      'usd',
    );

    // StripeからPayPalに変更してもこのコードは変わらない
  }
}

// payments/payments.module.ts
@Module({
  providers: [
    StripeProvider,
    {
      provide: 'PAYMENT_PROVIDER',
      useClass: StripeProvider, // 環境変数で切り替え可能
    },
  ],
  exports: ['PAYMENT_PROVIDER'],
})
export class PaymentsModule {}
```

### エラーハンドリング

**サードパーティのエラーをラップする:**

```typescript
// payments/exceptions/payment.exception.ts
export class PaymentException extends HttpException {
  constructor(
    message: string,
    public readonly provider: string,
    public readonly originalError?: Error,
  ) {
    super(
      {
        statusCode: HttpStatus.PAYMENT_REQUIRED,
        error: 'Payment Failed',
        message,
        provider,
      },
      HttpStatus.PAYMENT_REQUIRED,
    );
  }
}

// payments/providers/stripe.provider.ts
async createPaymentIntent(amount: number, currency: string): Promise<PaymentIntent> {
  try {
    const paymentIntent = await this.stripe.paymentIntents.create({
      amount: amount * 100,
      currency,
    });

    return {
      id: paymentIntent.id,
      amount,
      currency,
      clientSecret: paymentIntent.client_secret,
    };
  } catch (error) {
    // Stripeのエラーを自前のエラーにラップ
    this.logger.error('Stripe payment intent creation failed', error.stack, 'StripeProvider', {
      amount,
      currency,
      error: error.message,
    });

    throw new PaymentException(
      `Failed to create payment intent: ${error.message}`,
      'stripe',
      error,
    );
  }
}
```

### テスト/本番クレデンシャルの管理

```typescript
// config/payment.config.ts
import { registerAs } from '@nestjs/config';

export default registerAs('payment', () => {
  const isProduction = process.env.NODE_ENV === 'production';

  return {
    stripe: {
      secretKey: isProduction
        ? process.env.STRIPE_SECRET_KEY
        : process.env.STRIPE_TEST_SECRET_KEY,
      publishableKey: isProduction
        ? process.env.STRIPE_PUBLISHABLE_KEY
        : process.env.STRIPE_TEST_PUBLISHABLE_KEY,
      webhookSecret: isProduction
        ? process.env.STRIPE_WEBHOOK_SECRET
        : process.env.STRIPE_TEST_WEBHOOK_SECRET,
    },
    mode: isProduction ? 'live' : 'test',
  };
});

// payments/providers/stripe.provider.ts
@Injectable()
export class StripeProvider implements PaymentProvider {
  private stripe: Stripe;
  private readonly isTestMode: boolean;

  constructor(private readonly configService: ConfigService) {
    const paymentConfig = this.configService.get('payment');
    this.stripe = new Stripe(paymentConfig.stripe.secretKey);
    this.isTestMode = paymentConfig.mode === 'test';

    this.logger.log(`Stripe initialized in ${paymentConfig.mode} mode`, 'StripeProvider');
  }

  async createPaymentIntent(amount: number, currency: string): Promise<PaymentIntent> {
    if (this.isTestMode) {
      this.logger.warn('Creating payment intent in TEST mode', 'StripeProvider');
    }

    // ...
  }
}
```

### レート制限の考慮

```typescript
// common/decorators/rate-limit.decorator.ts
import { SetMetadata } from '@nestjs/common';

export const RATE_LIMIT_KEY = 'rateLimit';

export interface RateLimitOptions {
  ttl: number; // 時間窓（秒）
  limit: number; // 最大リクエスト数
}

export const RateLimit = (options: RateLimitOptions) =>
  SetMetadata(RATE_LIMIT_KEY, options);

// common/guards/rate-limit.guard.ts
import { Injectable, CanActivate, ExecutionContext, HttpException, HttpStatus } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { RATE_LIMIT_KEY, RateLimitOptions } from '../decorators/rate-limit.decorator';

@Injectable()
export class RateLimitGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    @Inject(CACHE_MANAGER) private readonly cacheManager: Cache,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const rateLimitOptions = this.reflector.get<RateLimitOptions>(
      RATE_LIMIT_KEY,
      context.getHandler(),
    );

    if (!rateLimitOptions) {
      return true; // レート制限なし
    }

    const request = context.switchToHttp().getRequest();
    const key = `rate-limit:${request.ip}:${request.url}`;

    const current = (await this.cacheManager.get<number>(key)) || 0;

    if (current >= rateLimitOptions.limit) {
      throw new HttpException(
        {
          statusCode: HttpStatus.TOO_MANY_REQUESTS,
          message: 'Too many requests',
          retryAfter: rateLimitOptions.ttl,
        },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    await this.cacheManager.set(key, current + 1, rateLimitOptions.ttl);

    return true;
  }
}

// 使用例
@Controller('api')
@UseGuards(RateLimitGuard)
export class ApiController {
  // 1分間に10リクエストまで
  @Get('expensive-operation')
  @RateLimit({ ttl: 60, limit: 10 })
  async expensiveOperation() {
    // サードパーティAPIを呼び出す
  }
}
```

### Stripe統合例

#### Webhookハンドリング

```typescript
// webhooks/stripe-webhook.controller.ts
import { Controller, Post, Req, Headers, BadRequestException } from '@nestjs/common';
import { Request } from 'express';
import Stripe from 'stripe';

@Controller('webhooks/stripe')
export class StripeWebhookController {
  private stripe: Stripe;

  constructor(
    private readonly configService: ConfigService,
    private readonly orderService: OrdersService,
  ) {
    this.stripe = new Stripe(this.configService.get('payment.stripe.secretKey'));
  }

  @Post()
  async handleWebhook(
    @Req() request: Request,
    @Headers('stripe-signature') signature: string,
  ) {
    if (!signature) {
      throw new BadRequestException('Missing stripe-signature header');
    }

    let event: Stripe.Event;

    try {
      // Webhookの署名検証
      event = this.stripe.webhooks.constructEvent(
        request.body,
        signature,
        this.configService.get('payment.stripe.webhookSecret'),
      );
    } catch (error) {
      throw new BadRequestException(`Webhook signature verification failed: ${error.message}`);
    }

    // イベントタイプに応じて処理
    switch (event.type) {
      case 'payment_intent.succeeded':
        await this.handlePaymentSuccess(event.data.object as Stripe.PaymentIntent);
        break;

      case 'payment_intent.payment_failed':
        await this.handlePaymentFailure(event.data.object as Stripe.PaymentIntent);
        break;

      case 'charge.refunded':
        await this.handleRefund(event.data.object as Stripe.Charge);
        break;

      default:
        this.logger.log(`Unhandled event type: ${event.type}`, 'StripeWebhook');
    }

    return { received: true };
  }

  private async handlePaymentSuccess(paymentIntent: Stripe.PaymentIntent) {
    this.logger.log(`Payment succeeded: ${paymentIntent.id}`, 'StripeWebhook');

    // 注文ステータスを更新
    await this.orderService.updatePaymentStatus(
      paymentIntent.metadata.orderId,
      'paid',
      paymentIntent.id,
    );
  }

  private async handlePaymentFailure(paymentIntent: Stripe.PaymentIntent) {
    this.logger.error(
      `Payment failed: ${paymentIntent.id}`,
      undefined,
      'StripeWebhook',
      {
        paymentIntentId: paymentIntent.id,
        orderId: paymentIntent.metadata.orderId,
      },
    );

    await this.orderService.updatePaymentStatus(
      paymentIntent.metadata.orderId,
      'failed',
    );
  }

  private async handleRefund(charge: Stripe.Charge) {
    this.logger.log(`Refund processed: ${charge.id}`, 'StripeWebhook');

    // 注文ステータスを更新
    await this.orderService.processRefund(charge.metadata.orderId);
  }
}
```

#### 冪等性キー

```typescript
// payments/providers/stripe.provider.ts
async createPaymentIntent(
  amount: number,
  currency: string,
  orderId: string,
): Promise<PaymentIntent> {
  // 冪等性キーを生成（同じorderIdなら同じキー）
  const idempotencyKey = `order_${orderId}_${amount}_${currency}`;

  try {
    const paymentIntent = await this.stripe.paymentIntents.create(
      {
        amount: amount * 100,
        currency,
        metadata: {
          orderId, // Webhookで使用
        },
      },
      {
        idempotencyKey, // 冪等性を保証
      },
    );

    return {
      id: paymentIntent.id,
      amount,
      currency,
      clientSecret: paymentIntent.client_secret,
    };
  } catch (error) {
    // 同じ冪等性キーで再試行しても安全
    throw new PaymentException(
      `Failed to create payment intent: ${error.message}`,
      'stripe',
      error,
    );
  }
}
```

---

## 9. スケーリング

### 垂直スケーリング（Scale Up）

**定義**: サーバーのスペック（CPU、メモリ、ディスク）を増強する

#### メリット

- **シンプル**: アプリケーションコードの変更不要
- **管理が容易**: サーバー1台のみ
- **低レイテンシ**: ネットワーク通信が不要
- **トランザクション処理**: 複雑なトランザクションも容易

#### デメリット

- **単一障害点**: サーバーダウンでサービス全停止
- **ダウンタイム**: スペックアップ時にサービス停止が必要
- **コスト効率が悪い**: 高スペックサーバーは非線形的に高価
- **上限がある**: 物理的な限界が存在

#### 適用シナリオ

```typescript
// ✅ 垂直スケーリングが適切な場合

1. **初期段階のアプリケーション**
   - トラフィックが少ない（< 10,000 req/day）
   - 迅速なMVP開発が必要

2. **データベース**
   - 単一のマスターDBが必要
   - トランザクション整合性が重要

3. **モノリシックアーキテクチャ**
   - アプリケーションが分散に対応していない
   - ステートフルな処理が多い

4. **予測可能な成長**
   - トラフィックの増加が緩やか
   - スケールダウンの必要がない
```

**実装例:**

```yaml
# docker-compose.yml（開発環境）
services:
  api:
    image: my-api:latest
    deploy:
      resources:
        limits:
          cpus: '2.0'    # 2コア
          memory: 4G     # 4GB RAM
        reservations:
          cpus: '1.0'
          memory: 2G

  # スペックアップ後
  api:
    deploy:
      resources:
        limits:
          cpus: '8.0'    # 8コアに増強
          memory: 16G    # 16GBに増強
```

### 水平スケーリング（Scale Out）

**定義**: サーバーの台数を増やして負荷を分散する

#### メリット

- **高可用性**: 1台ダウンしても他がカバー
- **柔軟性**: 需要に応じて動的に追加・削除
- **コスト効率**: 低スペックサーバーを多数使用
- **理論的に無制限**: 台数を増やせば無限にスケール

#### デメリット

- **複雑性**: ロードバランサー、セッション管理が必要
- **コスト**: 小規模では割高
- **レイテンシ**: ネットワーク通信のオーバーヘッド
- **データ整合性**: 分散トランザクションが困難

#### 適用シナリオ

```typescript
// ✅ 水平スケーリングが適切な場合

1. **高トラフィック**
   - > 100,000 req/day
   - ピーク時の急激な増加

2. **グローバル展開**
   - 複数リージョンでサービス提供
   - 地理的に分散したユーザー

3. **マイクロサービス**
   - サービス単位で独立してスケール
   - ステートレスなAPI

4. **変動の大きい負荷**
   - イベント駆動（セール、キャンペーン）
   - 時間帯による変動が大きい
```

#### 実装の前提条件

**1. ステートレス化:**

```typescript
// ❌ 悪い例: サーバーにセッションを保存
@Injectable()
export class AuthService {
  private sessions = new Map<string, UserSession>(); // メモリに保存

  login(userId: string) {
    const sessionId = uuid();
    this.sessions.set(sessionId, { userId, expiresAt: Date.now() + 3600000 });
    return sessionId;
  }

  getSession(sessionId: string) {
    return this.sessions.get(sessionId); // 他のサーバーからはアクセス不可
  }
}

// ✅ 良い例: Redisに保存
@Injectable()
export class AuthService {
  constructor(@Inject(CACHE_MANAGER) private cache: Cache) {}

  async login(userId: string) {
    const sessionId = uuid();
    await this.cache.set(
      `session:${sessionId}`,
      { userId, expiresAt: Date.now() + 3600000 },
      3600,
    );
    return sessionId;
  }

  async getSession(sessionId: string) {
    return this.cache.get(`session:${sessionId}`); // すべてのサーバーからアクセス可能
  }
}
```

**2. 共有ストレージ:**

```typescript
// ❌ 悪い例: ローカルファイルシステムに保存
@Injectable()
export class FileService {
  async uploadFile(file: Express.Multer.File) {
    const path = `./uploads/${file.filename}`;
    await fs.writeFile(path, file.buffer); // ローカルに保存
    return { url: `/files/${file.filename}` };
  }
}

// ✅ 良い例: S3に保存
@Injectable()
export class FileService {
  constructor(private readonly s3: S3Client) {}

  async uploadFile(file: Express.Multer.File) {
    const key = `uploads/${uuid()}-${file.originalname}`;

    await this.s3.send(
      new PutObjectCommand({
        Bucket: 'my-bucket',
        Key: key,
        Body: file.buffer,
        ContentType: file.mimetype,
      }),
    );

    return { url: `https://my-bucket.s3.amazonaws.com/${key}` };
  }
}
```

**3. ロードバランサー:**

```nginx
# nginx.conf
upstream api_servers {
    least_conn; # 最小接続数のサーバーに振り分け

    server api1.example.com:3000 weight=3; # 重み付け
    server api2.example.com:3000 weight=2;
    server api3.example.com:3000 weight=1;
}

server {
    listen 80;

    location /api {
        proxy_pass http://api_servers;

        # ヘルスチェック
        proxy_next_upstream error timeout http_500;

        # ヘッダー転送
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

### オートスケーリング（エラスティックスケーリング）

**定義**: 負荷に応じて自動的にインスタンス数を増減

#### AWS Auto Scaling設定例

```yaml
# ECS Service Auto Scaling
Resources:
  AutoScalingTarget:
    Type: AWS::ApplicationAutoScaling::ScalableTarget
    Properties:
      MaxCapacity: 10 # 最大10インスタンス
      MinCapacity: 2 # 最小2インスタンス
      ResourceId: !Sub service/${ECSCluster}/${ECSService}
      ScalableDimension: ecs:service:DesiredCount
      ServiceNamespace: ecs

  # CPU使用率ベースのスケーリング
  CPUScalingPolicy:
    Type: AWS::ApplicationAutoScaling::ScalingPolicy
    Properties:
      PolicyName: cpu-scaling
      PolicyType: TargetTrackingScaling
      ScalingTargetId: !Ref AutoScalingTarget
      TargetTrackingScalingPolicyConfiguration:
        TargetValue: 70.0 # CPU 70%を目標
        PredefinedMetricSpecification:
          PredefinedMetricType: ECSServiceAverageCPUUtilization
        ScaleInCooldown: 300 # 5分
        ScaleOutCooldown: 60 # 1分

  # リクエスト数ベースのスケーリング
  RequestCountScalingPolicy:
    Type: AWS::ApplicationAutoScaling::ScalingPolicy
    Properties:
      PolicyName: request-count-scaling
      PolicyType: TargetTrackingScaling
      ScalingTargetId: !Ref AutoScalingTarget
      TargetTrackingScalingPolicyConfiguration:
        TargetValue: 1000.0 # インスタンスあたり1000リクエスト/分
        PredefinedMetricSpecification:
          PredefinedMetricType: ALBRequestCountPerTarget
          ResourceLabel: !Sub
            - '${LoadBalancerFullName}/${TargetGroupFullName}'
            - LoadBalancerFullName: !GetAtt LoadBalancer.LoadBalancerFullName
              TargetGroupFullName: !GetAtt TargetGroup.TargetGroupFullName
```

#### Kubernetes HPA（Horizontal Pod Autoscaler）

```yaml
# hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api
  minReplicas: 2
  maxReplicas: 10
  metrics:
    # CPU使用率
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70

    # メモリ使用率
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80

    # カスタムメトリクス（リクエスト数）
    - type: Pods
      pods:
        metric:
          name: http_requests_per_second
        target:
          type: AverageValue
          averageValue: '1000'
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300 # 5分間安定してから縮小
      policies:
        - type: Percent
          value: 50 # 一度に50%まで縮小
          periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0 # 即座に拡大
      policies:
        - type: Percent
          value: 100 # 一度に2倍まで拡大
          periodSeconds: 15
```

### スケーリング判断基準

#### パフォーマンス改善 vs スケーリング

```
問題: レスポンスが遅い

↓
【1. まずパフォーマンス改善を試みる】
├─ DBクエリ最適化（インデックス、N+1問題）
├─ キャッシング（Redis、CDN）
├─ 不要な処理の削除
└─ コードの最適化

↓ 改善したが不十分
【2. 垂直スケーリング検討】
├─ CPU使用率が常に80%以上？
├─ メモリ不足？
└─ 単純にリソース不足か？

↓ まだ不十分
【3. 水平スケーリング検討】
├─ トラフィックが多い（> 100k req/day）
├─ ピーク時の負荷が高い
└─ グローバル展開が必要
```

**判断フローチャート:**

```typescript
// スケーリング判断ロジック
interface PerformanceMetrics {
  avgResponseTime: number; // ms
  p95ResponseTime: number;
  cpuUsage: number; // %
  memoryUsage: number; // %
  requestsPerSecond: number;
  errorRate: number; // %
}

function determineScalingStrategy(metrics: PerformanceMetrics): string {
  // 1. パフォーマンス問題をチェック
  if (metrics.avgResponseTime > 1000 || metrics.p95ResponseTime > 2000) {
    // まず最適化を試みる
    if (!hasOptimizedDatabase() || !hasCaching()) {
      return 'OPTIMIZE_FIRST';
    }
  }

  // 2. リソース不足をチェック
  if (metrics.cpuUsage > 80 || metrics.memoryUsage > 85) {
    if (currentServerSize < 'xlarge') {
      return 'SCALE_UP'; // 垂直スケーリング
    } else {
      return 'SCALE_OUT'; // 水平スケーリング
    }
  }

  // 3. トラフィックをチェック
  if (metrics.requestsPerSecond > 1000) {
    return 'SCALE_OUT'; // 水平スケーリング
  }

  // 4. エラー率をチェック
  if (metrics.errorRate > 1) {
    return 'INVESTIGATE'; // スケーリングではなく調査が必要
  }

  return 'NO_ACTION';
}
```

### コスト分析の重要性

**スケーリングの費用対効果:**

| 戦略 | 月額コスト例 | 適用トラフィック | コスト効率 |
|------|-------------|----------------|-----------|
| **単一サーバー（小）** | $50 | < 10k req/day | 高 |
| **垂直スケーリング（大）** | $200 | 10k-50k req/day | 中 |
| **水平スケーリング（小×3）** | $150 | 50k-100k req/day | 高 |
| **オートスケーリング（2-10）** | $100-500 | 100k+ req/day | 最高 |

**コスト最適化の実践:**

```typescript
// 1. 不要なリソースの削除
// - 開発環境は夜間停止
// - ステージング環境は必要時のみ起動

// 2. Reserved Instances（AWS）の活用
// - 常時稼働するインスタンスは予約購入（最大75%割引）

// 3. Spot Instances（AWS）の活用
// - バッチ処理など中断可能なワークロードに使用（最大90%割引）

// 4. オートスケーリングの適切な設定
const autoScalingConfig = {
  minCapacity: 2, // 最小限に抑える
  maxCapacity: 10, // 適切な上限を設定
  targetCPU: 70, // 過剰に低く設定しない
  scaleInCooldown: 300, // 急激な縮小を避ける
};

// 5. モニタリングとアラート
// - 予算アラートを設定
// - コスト異常を即座に検知
```

### クラウドプラットフォームのロックイン考慮

**問題: 特定のクラウドサービスに依存すると移行が困難**

```typescript
// ❌ 悪い例: AWS固有のサービスに直接依存
import { DynamoDB } from 'aws-sdk';

@Injectable()
export class UsersService {
  private dynamoDB = new DynamoDB.DocumentClient();

  async findUser(id: string) {
    return this.dynamoDB
      .get({
        TableName: 'users',
        Key: { id },
      })
      .promise();
  }
}

// ✅ 良い例: 抽象化レイヤーを作成
interface DatabaseClient {
  get(key: string): Promise<unknown>;
  put(key: string, value: unknown): Promise<void>;
  delete(key: string): Promise<void>;
}

// AWS実装
@Injectable()
export class DynamoDBClient implements DatabaseClient {
  private dynamoDB = new DynamoDB.DocumentClient();

  async get(key: string) {
    return this.dynamoDB.get({ TableName: 'users', Key: { id: key } }).promise();
  }
  // ...
}

// GCP実装（将来の移行用）
@Injectable()
export class FirestoreClient implements DatabaseClient {
  // Firestoreを使った実装
}

// 使用側
@Injectable()
export class UsersService {
  constructor(@Inject('DATABASE_CLIENT') private db: DatabaseClient) {}

  async findUser(id: string) {
    return this.db.get(id); // プラットフォーム非依存
  }
}
```

**マルチクラウド対応のベストプラクティス:**

1. **標準プロトコルを使用**: HTTP、gRPC、AMQP など
2. **オープンソースを優先**: PostgreSQL、Redis、Kafka など
3. **抽象化レイヤー**: 各クラウドサービスをラップ
4. **Infrastructure as Code**: Terraform（クラウド非依存）を使用
5. **コンテナ化**: Docker、Kubernetesでポータビリティ確保

---

## 10. モニタリングとインシデント対応

### モニタリングツール

#### 主要ツール比較

| ツール | 用途 | 価格 | 特徴 |
|--------|------|------|------|
| **Datadog** | APM、ログ、メトリクス | 💰💰💰 | 包括的、高機能 |
| **Sentry** | エラートラッキング | 💰💰 | フロント/バックエンド対応 |
| **LogRocket** | セッションリプレイ | 💰💰 | フロントエンド中心 |
| **Prometheus + Grafana** | メトリクス、可視化 | 無料 | オープンソース、自己ホスト |
| **CloudWatch（AWS）** | AWS統合監視 | 💰 | AWS専用 |

#### Datadog統合例

```bash
npm install dd-trace
```

```typescript
// main.ts
import tracer from 'dd-trace';

// Datadog APMを初期化
tracer.init({
  service: 'my-api',
  env: process.env.NODE_ENV,
  version: process.env.APP_VERSION,
  logInjection: true, // ログにトレースIDを注入
  runtimeMetrics: true, // ランタイムメトリクスを収集
});

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  await app.listen(3000);
}
bootstrap();
```

**カスタムメトリクス:**

```typescript
// common/services/metrics.service.ts
import tracer from 'dd-trace';

@Injectable()
export class MetricsService {
  private readonly metrics = tracer.dogstatsd;

  increment(metric: string, tags?: Record<string, string>) {
    this.metrics.increment(metric, 1, tags);
  }

  gauge(metric: string, value: number, tags?: Record<string, string>) {
    this.metrics.gauge(metric, value, tags);
  }

  histogram(metric: string, value: number, tags?: Record<string, string>) {
    this.metrics.histogram(metric, value, tags);
  }
}

// 使用例
@Injectable()
export class OrdersService {
  constructor(private readonly metrics: MetricsService) {}

  async createOrder(orderDto: CreateOrderDto) {
    const startTime = Date.now();

    try {
      const order = await this.prisma.order.create({ data: orderDto });

      // メトリクスを記録
      this.metrics.increment('order.created', { status: 'success' });
      this.metrics.histogram('order.creation_time', Date.now() - startTime);

      return order;
    } catch (error) {
      this.metrics.increment('order.created', { status: 'failure' });
      throw error;
    }
  }
}
```

#### Sentry統合例

```bash
npm install @sentry/node @sentry/tracing
```

```typescript
// main.ts
import * as Sentry from '@sentry/node';
import * as Tracing from '@sentry/tracing';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // Sentry初期化
  Sentry.init({
    dsn: process.env.SENTRY_DSN,
    environment: process.env.NODE_ENV,
    tracesSampleRate: 1.0, // 本番では0.1など低めに設定
    integrations: [
      new Sentry.Integrations.Http({ tracing: true }),
      new Tracing.Integrations.Prisma({ client: prisma }),
    ],
  });

  // エラーハンドラー
  app.useGlobalFilters(new SentryExceptionFilter());

  await app.listen(3000);
}
bootstrap();
```

```typescript
// common/filters/sentry-exception.filter.ts
import * as Sentry from '@sentry/node';

@Catch()
export class SentryExceptionFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const request = ctx.getRequest();

    // Sentryにエラーを送信
    Sentry.withScope((scope) => {
      scope.setContext('http', {
        method: request.method,
        url: request.url,
        headers: request.headers,
      });

      if (request.user) {
        scope.setUser({
          id: request.user.id,
          email: request.user.email,
        });
      }

      Sentry.captureException(exception);
    });

    // 通常のエラーハンドリング
    // ...
  }
}
```

### ダッシュボード設計

**重要なメトリクスの可視化:**

```typescript
// Grafanaダッシュボード設定例（JSON）
{
  "dashboard": {
    "title": "API Performance",
    "panels": [
      {
        "title": "Request Rate",
        "targets": [
          {
            "expr": "rate(http_requests_total[5m])",
            "legendFormat": "{{method}} {{path}}"
          }
        ]
      },
      {
        "title": "Response Time (P95)",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))"
          }
        ]
      },
      {
        "title": "Error Rate",
        "targets": [
          {
            "expr": "rate(http_requests_total{status=~\"5..\"}[5m])"
          }
        ]
      },
      {
        "title": "CPU Usage",
        "targets": [
          {
            "expr": "avg(rate(process_cpu_seconds_total[1m])) * 100"
          }
        ]
      },
      {
        "title": "Memory Usage",
        "targets": [
          {
            "expr": "process_resident_memory_bytes / 1024 / 1024"
          }
        ]
      }
    ]
  }
}
```

### アラート設定

**段階的アラート:**

| レベル | 条件 | 通知先 | 対応 |
|--------|------|--------|------|
| **Info** | リクエスト数が通常の2倍 | Slackチャネル | 監視のみ |
| **Warning** | P95レイテンシ > 1秒 | Slackチャネル | 確認 |
| **Error** | エラー率 > 1% | Slack + メール | 即座に調査 |
| **Critical** | サービスダウン | Slack + メール + PagerDuty | 緊急対応 |

**Prometheus Alerting Rules:**

```yaml
# alerting-rules.yml
groups:
  - name: api_alerts
    interval: 30s
    rules:
      # エラー率が高い
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.01
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: 'High error rate detected'
          description: 'Error rate is {{ $value | humanizePercentage }} (threshold: 1%)'

      # レスポンスが遅い
      - alert: SlowResponse
        expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 1
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: 'Slow API response'
          description: 'P95 latency is {{ $value }}s (threshold: 1s)'

      # メモリ使用率が高い
      - alert: HighMemoryUsage
        expr: (process_resident_memory_bytes / 1024 / 1024 / 1024) > 14
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: 'High memory usage'
          description: 'Memory usage is {{ $value }}GB (threshold: 14GB)'

      # サービスダウン
      - alert: ServiceDown
        expr: up{job="api"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: 'API service is down'
          description: 'API instance {{ $labels.instance }} is unreachable'
```

### インシデントプレイブック

**標準対応手順:**

#### 1. 検出（Detection）

```typescript
// 自動検出
- Prometheusアラート
- Sentryエラー急増
- ヘルスチェック失敗
- ユーザーからの報告

// 手動検出
- モニタリングダッシュボード確認
- ログ分析
```

#### 2. コミュニケーション設定

```typescript
// インシデント発生時の初動
1. Slackで専用チャネル作成: #incident-2024-01-15-api-down
2. インシデント管理ツールでチケット作成（Jira、PagerDuty）
3. ステータスページ更新（例: status.example.com）
```

**Slack通知例:**

```typescript
// common/services/alert.service.ts
@Injectable()
export class AlertService {
  async notifyIncident(incident: {
    title: string;
    severity: 'low' | 'medium' | 'high' | 'critical';
    description: string;
    affectedServices: string[];
  }) {
    const color = {
      low: '#36a64f',
      medium: '#ff9800',
      high: '#ff5722',
      critical: '#f44336',
    }[incident.severity];

    await this.slack.send({
      channel: '#incidents',
      attachments: [
        {
          color,
          title: `🚨 ${incident.title}`,
          fields: [
            {
              title: 'Severity',
              value: incident.severity.toUpperCase(),
              short: true,
            },
            {
              title: 'Affected Services',
              value: incident.affectedServices.join(', '),
              short: true,
            },
            {
              title: 'Description',
              value: incident.description,
            },
          ],
          footer: 'Incident Response System',
          ts: Math.floor(Date.now() / 1000),
        },
      ],
    });
  }
}
```

#### 3. 影響・重大度の判定

**重大度レベル:**

| レベル | 定義 | 例 | 対応時間 |
|--------|------|-----|---------|
| **P0（Critical）** | サービス完全停止 | API全体がダウン | 即座（15分以内） |
| **P1（High）** | 主要機能が使用不可 | 決済システム停止 | 1時間以内 |
| **P2（Medium）** | 一部機能に影響 | 検索機能が遅い | 4時間以内 |
| **P3（Low）** | 軽微な問題 | UIの表示崩れ | 24時間以内 |

```typescript
// インシデント重大度判定
function determineSeverity(incident: {
  errorRate: number;
  affectedUsers: number;
  downtime: number; // 分
}): 'P0' | 'P1' | 'P2' | 'P3' {
  // P0: サービス完全停止
  if (incident.errorRate > 50 || incident.affectedUsers > 10000) {
    return 'P0';
  }

  // P1: 主要機能停止
  if (incident.errorRate > 10 || incident.affectedUsers > 1000) {
    return 'P1';
  }

  // P2: 一部機能に影響
  if (incident.errorRate > 1 || incident.affectedUsers > 100) {
    return 'P2';
  }

  // P3: 軽微な問題
  return 'P3';
}
```

#### 4. ユーザー通知

```typescript
// ステータスページ更新
await statusPage.createIncident({
  title: 'API Performance Degradation',
  status: 'investigating', // investigating → identified → monitoring → resolved
  impact: 'major', // none | minor | major | critical
  message: 'We are currently investigating elevated error rates on our API.',
  components: ['api', 'database'],
});
```

#### 5. 関連チーム通知

```typescript
// 通知対象の決定
const notificationMap = {
  'api-down': ['backend-team', 'devops-team', 'cto'],
  'database-issue': ['database-team', 'backend-team'],
  'payment-failed': ['backend-team', 'finance-team', 'ceo'],
};

// PagerDuty経由で緊急連絡
await pagerDuty.triggerIncident({
  title: 'API Service Down',
  urgency: 'high',
  escalationPolicy: 'backend-on-call',
});
```

#### 6. 責任分担・調査

```typescript
// インシデント対応の役割分担
interface IncidentRoles {
  incidentCommander: string; // 全体統括
  communications: string; // ステータス更新、通知
  technical: string[]; // 技術調査・修正
  support: string[]; // ユーザーサポート
}

// 例
const roles: IncidentRoles = {
  incidentCommander: 'alice@example.com',
  communications: 'bob@example.com',
  technical: ['carol@example.com', 'dave@example.com'],
  support: ['support-team@example.com'],
};
```

**調査チェックリスト:**

```markdown
## インシデント調査チェックリスト

### 1. 現象確認
- [ ] エラーログを確認
- [ ] メトリクスを確認（CPU、メモリ、レイテンシ）
- [ ] 影響範囲を特定（全ユーザー or 特定機能）

### 2. 原因調査
- [ ] 最近のデプロイを確認
- [ ] インフラ変更を確認
- [ ] 外部サービスの状態を確認
- [ ] データベースの状態を確認

### 3. 応急処置
- [ ] ロールバック可能か？
- [ ] 手動で復旧可能か？
- [ ] スケールアップで対応可能か？

### 4. 恒久対策
- [ ] 根本原因を特定
- [ ] 再発防止策を立案
- [ ] モニタリング強化
```

#### 7. 解決・テスト

```typescript
// 解決確認
async function verifyResolution(): Promise<boolean> {
  // エラー率が正常に戻ったか
  const errorRate = await getErrorRate();
  if (errorRate > 0.1) return false;

  // レスポンスタイムが正常か
  const p95Latency = await getP95Latency();
  if (p95Latency > 500) return false;

  // ヘルスチェックが成功するか
  const health = await checkHealth();
  if (!health.healthy) return false;

  return true;
}
```

### ブレームレスポストモーテム

**原則: 個人を責めず、プロセスの改善に焦点**

```markdown
# ポストモーテム: API障害（2024-01-15）

## サマリー
2024年1月15日 14:30-15:45（JST）に API サービスが停止。原因はデータベース接続プールの枯渇。影響を受けたユーザー数: 約5,000人。

## タイムライン
| 時刻 | イベント | 対応者 |
|------|---------|--------|
| 14:30 | エラー率急増アラート発火 | Alice（自動） |
| 14:32 | インシデント対応開始 | Bob |
| 14:35 | DB接続プールの枯渇を確認 | Carol |
| 14:40 | 接続プール設定を増やして再デプロイ | Dave |
| 14:50 | サービス復旧確認 | Bob |
| 15:45 | 完全解決を宣言 | Alice |

## 根本原因
- データベース接続プールのサイズが小さすぎた（10 → 50に変更）
- 新機能のデプロイでDB接続が増加したが、事前にテストしていなかった

## 影響
- ユーザー: 約5,000人が75分間サービスを利用できなかった
- ビジネス: 推定$10,000の機会損失

## やったこと（うまくいった）
✅ アラートが即座に発火（2分以内）
✅ チームが迅速に集結（5分以内）
✅ 原因を素早く特定（8分以内）

## やらなかったこと（改善点）
❌ 新機能のロードテストを実施していなかった
❌ 接続プール設定のモニタリングがなかった
❌ ステージング環境が本番と同じ構成ではなかった

## アクションアイテム
| タスク | 担当者 | 期限 |
|--------|--------|------|
| 本番と同じ構成のステージング環境を構築 | DevOps | 1週間 |
| 接続プール使用率のモニタリングを追加 | Backend | 3日 |
| デプロイ前のロードテスト自動化 | QA | 2週間 |
| DB接続プールの適切なサイズを算出 | Backend | 1週間 |

## 学び
- パフォーマンステストは本番相当の負荷で実施する必要がある
- インフラ設定値もコードレビューの対象にすべき
- アラートは機能したが、予防的なモニタリングが不足していた

---

**作成者**: Alice
**レビュアー**: Bob, Carol, Dave
**承認**: CTO
```

**ポストモーテムのベストプラクティス:**

1. **24時間以内に作成**: 記憶が新しいうちに
2. **全員参加**: 技術者だけでなく関係者全員
3. **タイムラインを詳細に**: 何が起こったかを正確に記録
4. **非難しない**: "誰が"ではなく"何が"問題だったか
5. **アクションアイテムを明確に**: 担当者と期限を設定
6. **定期的にレビュー**: アクションアイテムの進捗を追跡

---

## まとめ

このガイドでは、以下のバックエンド開発戦略を網羅しました：

1. **アーキテクチャ判断**: モノリス vs マイクロサービス、NestJSセットアップ
2. **API設計**: REST規約、バージョニング、ページネーション
3. **データスキーマ**: Prisma、マイグレーション、リレーション設計
4. **エラーハンドリング**: ログレベル、構造化ログ、try-catchパターン
5. **キャッシング**: Redis統合、TTL設計、キャッシュ無効化
6. **バックグラウンドジョブ**: BullMQ、優先度、リトライ、Cron
7. **サードパーティ統合**: 抽象化、エラーハンドリング、レート制限
8. **スケーリング**: 垂直 vs 水平、オートスケーリング、コスト分析
9. **モニタリング**: ツール選定、ダッシュボード、アラート設計
10. **インシデント対応**: プレイブック、ポストモーテム

### 重要な原則（再掲）

- **型安全性**: `any`/`Any`の使用禁止
- **SOLID原則**: すべての実装で遵守
- **テストファースト**: AAAパターン、高カバレッジ
- **セキュリティ**: 入力検証、機密情報の管理
- **可観測性**: ログ、メトリクス、トレーシング
- **スケーラビリティ**: ステートレス設計、水平スケール対応
- **レジリエンス**: リトライ、サーキットブレーカー、フォールバック

### 次のステップ

1. プロジェクトの要件に応じてアーキテクチャを選択
2. NestJSでプロジェクトをセットアップ
3. Prismaでデータベーススキーマを設計
4. API設計規約に従ってエンドポイントを実装
5. 適切なログとモニタリングを設定
6. 本番環境にデプロイする前にロードテストを実施
7. インシデント対応プレイブックを準備

---

**参考文献:**
- O'Reilly「Full Stack JavaScript Strategies」
- NestJS公式ドキュメント: https://docs.nestjs.com/
- Prisma公式ドキュメント: https://www.prisma.io/docs/
- BullMQ公式ドキュメント: https://docs.bullmq.io/
