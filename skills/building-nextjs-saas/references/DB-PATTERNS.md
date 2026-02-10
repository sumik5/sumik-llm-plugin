# データベース設計パターン

Next.js SaaS アプリケーションにおけるデータベース設計と実装の実践的パターン。

---

## 1. ORM選定と初期設定

### Drizzle ORM + Neon PostgreSQL の統合

サーバーレス環境に最適化されたORM構成。

#### 接続設定

```js
// config/db.js
import { drizzle } from 'drizzle-orm/neon-http';

export const db = drizzle(process.env.DATABASE_URL);
```

#### Drizzle Kit設定

```js
// drizzle.config.js
import { defineConfig } from 'drizzle-kit';

export default defineConfig({
  schema: './config/schema.js',
  dialect: 'postgresql',
  dbCredentials: {
    url: process.env.DATABASE_URL,
  },
});
```

**主な利点:**
- HTTP経由の接続でサーバーレス環境に対応
- コールドスタートに強い
- TypeScriptの型推論が強力

---

## 2. SaaSスキーマ設計

### ユーザーテーブル

認証連携とクレジット管理を含むユーザー情報。

```js
import { pgTable, serial, varchar, integer } from 'drizzle-orm/pg-core';

export const Users = pgTable('users', {
  id: serial('id').primaryKey(),
  name: varchar('name').notNull(),
  email: varchar('email').notNull(),
  imageUrl: varchar('image_url').notNull(),
  credits: integer('credits').default(3)
});
```

**設計ポイント:**
- `email` をユニーク制約で管理（認証連携時のキー）
- `credits` でフリーミアムモデル実装
- `imageUrl` で認証プロバイダーのプロフィール画像を保存

### 生成コンテンツテーブル

AI出力や生成アセットの管理。

```js
export const AiGeneratedContent = pgTable('ai_generated_content', {
  id: serial('id').primaryKey(),
  contentType: varchar('content_type').notNull(),
  style: varchar('style').notNull(),
  originalUrl: varchar('original_url').notNull(),
  generatedUrl: varchar('generated_url').notNull(),
  userEmail: varchar('user_email')
});
```

**設計ポイント:**
- `contentType` でコンテンツ種別を識別
- `style` で生成時のパラメータを記録
- `originalUrl` と `generatedUrl` でBefore/Afterを管理
- `userEmail` で外部キー的な関連付け（正規化とのトレードオフ）

---

## 3. CRUD操作パターン

### SELECT（条件付き検索）

```js
import { eq } from 'drizzle-orm';

const result = await db.select()
  .from(Users)
  .where(eq(Users.email, userEmail));
```

**パターン:**
- `eq()` で等価条件
- 単一レコード取得時も配列で返る（`result[0]` でアクセス）

### INSERT（returning付き）

```js
const saved = await db.insert(Users)
  .values({ name, email, imageUrl })
  .returning({ Users });
```

**パターン:**
- `.returning()` で挿入したレコードを取得
- IDの自動生成を含む全カラム取得可能

### UPDATE（クレジット更新等）

```js
const currentUser = await db.select().from(Users).where(eq(Users.email, userEmail));
const currentCredits = currentUser[0].credits;

await db.update(Users)
  .set({ credits: currentCredits - 1 })
  .where(eq(Users.email, userEmail))
  .returning({ id: Users.id });
```

**パターン:**
- 既存値を取得してから計算（トランザクション考慮）
- `.set()` で更新値指定
- `.where()` で更新対象を限定

### ORDER BY（新しい順表示）

```js
import { desc } from 'drizzle-orm';

const list = await db.select()
  .from(AiGeneratedContent)
  .where(eq(AiGeneratedContent.userEmail, email))
  .orderBy(desc(AiGeneratedContent.id));
```

**パターン:**
- `desc()` で降順ソート
- 時系列表示はシリアルIDの降順が簡単

---

## 4. スキーママイグレーション

### マイグレーション実行

```bash
# スキーマをDBに適用
npx drizzle-kit push
```

**フロー:**
1. `config/schema.js` でスキーマ定義
2. `drizzle-kit push` で差分を自動検出・適用
3. Drizzle Studioで確認

### Drizzle Studio でのデータ確認

```bash
npx drizzle-kit studio
```

ブラウザベースの管理UIが起動し、データのCRUDが可能。

### マイグレーション戦略

| 戦略 | 用途 | コマンド |
|------|------|----------|
| **Push** | 開発中の迅速な反映 | `drizzle-kit push` |
| **Generate** | 本番環境向けマイグレーションファイル生成 | `drizzle-kit generate` |
| **Migrate** | 生成したマイグレーションを実行 | `drizzle-kit migrate` |

**推奨:**
- 開発初期は `push` で迅速にイテレーション
- 本番デプロイ前に `generate` でマイグレーションファイル化

---

## 5. API Route でのDB操作

### Next.js API Route内でのDB呼び出し

```js
// app/api/user/route.js
import { db } from '@/config/db';
import { Users } from '@/config/schema';
import { eq } from 'drizzle-orm';
import { NextResponse } from 'next/server';

export async function POST(req) {
  const { user } = await req.json();

  try {
    const result = await db.select()
      .from(Users)
      .where(eq(Users.email, user?.primaryEmailAddress?.emailAddress));

    return NextResponse.json({ result: result[0] });
  } catch (e) {
    return NextResponse.json({ error: e.message }, { status: 500 });
  }
}
```

**パターン:**
- `try-catch` でDBエラーをハンドリング
- `NextResponse.json()` で統一的なレスポンス形式
- エラー時はステータスコード `500` を返す

### エラーハンドリングの実践例

```js
export async function PUT(req) {
  const { userEmail } = await req.json();

  try {
    const currentUser = await db.select()
      .from(Users)
      .where(eq(Users.email, userEmail));

    if (!currentUser.length) {
      return NextResponse.json({ error: 'User not found' }, { status: 404 });
    }

    const currentCredits = currentUser[0].credits;

    if (currentCredits <= 0) {
      return NextResponse.json({ error: 'Insufficient credits' }, { status: 403 });
    }

    await db.update(Users)
      .set({ credits: currentCredits - 1 })
      .where(eq(Users.email, userEmail));

    return NextResponse.json({ success: true });
  } catch (e) {
    return NextResponse.json({ error: e.message }, { status: 500 });
  }
}
```

---

## 6. 環境変数の命名規則

### Next.js の `NEXT_PUBLIC_` プレフィックス

| 変数種別 | プレフィックス | 露出範囲 | 例 |
|---------|---------------|---------|-----|
| **クライアント公開** | `NEXT_PUBLIC_` | ブラウザに露出 | `NEXT_PUBLIC_API_KEY` |
| **サーバーサイド専用** | なし | サーバーのみ | `DATABASE_URL` |

### ❌ 危険なパターン

```bash
# 絶対にしてはいけない
NEXT_PUBLIC_DATABASE_URL=postgresql://...
```

**理由:**
- `NEXT_PUBLIC_` 付きの環境変数はクライアントバンドルに含まれる
- データベース認証情報がブラウザに露出する
- 悪意のあるユーザーがDB URLを取得可能

### ✅ 安全なパターン

```bash
# サーバーサイドのみで使用
DATABASE_URL=postgresql://...

# クライアントで必要なAPI URL
NEXT_PUBLIC_API_BASE_URL=https://api.example.com
```

**原則:**
- **DB URL、API秘密鍵、JWTシークレット等はNEXT_PUBLIC_を絶対に付けない**
- クライアントで必要な公開情報のみ `NEXT_PUBLIC_` を使用

---

## 7. 判断基準テーブル

| 要件 | 推奨 | 理由 |
|------|------|------|
| **サーバーレスDB** | Neon / Supabase | サーバーレス接続対応、HTTP経由でコールドスタートに強い |
| **TypeScript型安全** | Drizzle ORM | 型推論が強力、エディタ補完が優秀 |
| **管理UI** | Drizzle Studio | 無料、ブラウザベース、別途デプロイ不要 |
| **スキーマ管理** | drizzle-kit push | シンプルなマイグレーション、開発中は迅速 |
| **本番マイグレーション** | drizzle-kit generate + migrate | マイグレーションファイルでバージョン管理 |
| **DB URLのセキュリティ** | 環境変数（NEXT_PUBLIC_なし） | クライアント非露出、サーバーサイド専用 |
| **認証連携** | email カラムをキーに | Clerk/Auth0等のemailと紐付け |
| **クレジット管理** | integer カラム + UPDATE | フリーミアムモデルの簡易実装 |

---

## 追加の実践パターン

### トランザクション処理

```js
import { db } from '@/config/db';

await db.transaction(async (tx) => {
  const user = await tx.select().from(Users).where(eq(Users.email, email));

  if (user[0].credits < 1) {
    throw new Error('Insufficient credits');
  }

  await tx.update(Users).set({ credits: user[0].credits - 1 }).where(eq(Users.email, email));
  await tx.insert(AiGeneratedContent).values({ userEmail: email, ... });
});
```

**用途:**
- クレジット減算と生成コンテンツ作成を原子的に実行
- エラー時は自動ロールバック

### ページネーション

```js
import { limit, offset } from 'drizzle-orm';

const page = 1;
const pageSize = 10;

const items = await db.select()
  .from(AiGeneratedContent)
  .where(eq(AiGeneratedContent.userEmail, email))
  .orderBy(desc(AiGeneratedContent.id))
  .limit(pageSize)
  .offset((page - 1) * pageSize);
```

---

## セキュリティチェックリスト

- [ ] DB URLに `NEXT_PUBLIC_` プレフィックスを付けていない
- [ ] API Route内でユーザー認証を検証している
- [ ] SQL文字列連結ではなくORM/プリペアドステートメントを使用
- [ ] クレジット残高チェックをサーバーサイドで実施
- [ ] エラーメッセージにDB詳細情報を含めていない

---

このパターン集は、Next.js SaaSアプリケーションにおける典型的なデータベース操作をカバーしています。プロジェクトの要件に応じてカスタマイズしてください。
