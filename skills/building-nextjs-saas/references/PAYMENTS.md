# 決済・課金パターン

Next.js SaaSアプリケーションにおける決済機能と課金システムの実装パターン。

---

## 1. クレジットベース課金モデル

### 概要

従量課金型SaaSでよく採用されるクレジットシステムの実装パターン。ユーザーごとにクレジット残高を管理し、サービス利用に応じて消費する。

### データベーススキーマ

```ts
// users テーブルにクレジットフィールドを追加
export const Users = pgTable('users', {
  id: serial('id').primaryKey(),
  email: text('email').notNull(),
  credits: integer('credits').default(10).notNull(), // デフォルトクレジット
  createdAt: timestamp('created_at').defaultNow(),
})
```

### 新規ユーザーへのデフォルトクレジット付与

```ts
// 新規登録時にデフォルト10クレジットを付与
const newUser = await db.insert(Users).values({
  email: user.email,
  credits: 10,
}).returning()
```

### クレジット残高表示

```tsx
// ヘッダーコンポーネントでクレジット表示
export function Header() {
  const { userDetail } = useUser()

  return (
    <header>
      <Badge variant="secondary">
        <Coins className="w-4 h-4" />
        {userDetail?.credits ?? 0}
      </Badge>
    </header>
  )
}
```

### クレジット消費ロジック

```ts
// 1操作 = 1クレジット消費のパターン
async function executeOperation(userId: number) {
  const user = await db.query.Users.findFirst({
    where: eq(Users.id, userId),
  })

  if (!user || user.credits <= 0) {
    throw new Error('クレジット残高が不足しています')
  }

  // 操作実行
  await performOperation()

  // クレジット減算
  await db.update(Users)
    .set({ credits: user.credits - 1 })
    .where(eq(Users.id, userId))
}
```

---

## 2. 料金プラン設計

### プラン定義パターン

```ts
// クレジットパッケージの定義
interface CreditOption {
  credits: number
  amount: number
  popular?: boolean
}

const creditOptions: CreditOption[] = [
  { credits: 5, amount: 0.99 },
  { credits: 10, amount: 1.99 },
  { credits: 25, amount: 3.99, popular: true },
  { credits: 50, amount: 6.99 },
  { credits: 100, amount: 9.99 },
]
```

### UIカード表示パターン

```tsx
export function PricingCard({ option, onSelect, isSelected }: PricingCardProps) {
  return (
    <Card
      className={cn(
        "cursor-pointer transition-all",
        isSelected && "ring-2 ring-primary"
      )}
      onClick={() => onSelect(option)}
    >
      <CardHeader>
        {option.popular && (
          <Badge className="w-fit">人気</Badge>
        )}
        <CardTitle>{option.credits} クレジット</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="text-3xl font-bold">
          ${option.amount.toFixed(2)}
        </div>
        <p className="text-sm text-muted-foreground">
          1クレジット ${(option.amount / option.credits).toFixed(2)}
        </p>
      </CardContent>
    </Card>
  )
}
```

### 選択状態管理

```tsx
export function BuyCreditsPage() {
  const [selectedOption, setSelectedOption] = useState<CreditOption | null>(null)

  return (
    <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
      {creditOptions.map((option) => (
        <PricingCard
          key={option.credits}
          option={option}
          onSelect={setSelectedOption}
          isSelected={selectedOption?.credits === option.credits}
        />
      ))}
    </div>
  )
}
```

---

## 3. 決済ゲートウェイ統合

### PayPal統合例

#### プロバイダー設定

```tsx
// app/layout.tsx
import { PayPalScriptProvider } from '@paypal/react-paypal-js'

export default function RootLayout({ children }: { children: React.ReactNode }) {
  const initialOptions = {
    clientId: process.env.NEXT_PUBLIC_PAYPAL_CLIENT_ID!,
    currency: 'USD',
    intent: 'capture',
  }

  return (
    <PayPalScriptProvider options={initialOptions}>
      {children}
    </PayPalScriptProvider>
  )
}
```

#### PayPalボタンコンポーネント

```tsx
import { PayPalButtons } from '@paypal/react-paypal-js'

export function PaymentButton({ selectedOption, onSuccess }: PaymentButtonProps) {
  const { userDetail, setUserDetail } = useUser()
  const router = useRouter()

  return (
    <PayPalButtons
      style={{ layout: 'vertical' }}
      disabled={!selectedOption}
      createOrder={(data, actions) => {
        return actions.order.create({
          purchase_units: [{
            amount: {
              value: selectedOption.amount.toFixed(2),
              currency_code: 'USD',
            },
            description: `${selectedOption.credits} クレジットの購入`,
          }],
        })
      }}
      onApprove={async (data, actions) => {
        const order = await actions.order?.capture()

        if (order?.status === 'COMPLETED') {
          // クレジット更新処理
          await updateUserCredits(userDetail.id, selectedOption.credits)

          // Context即時更新
          setUserDetail(prev => ({
            ...prev,
            credits: prev.credits + selectedOption.credits,
          }))

          toast.success(`${selectedOption.credits}クレジットを追加しました`)
          router.push('/dashboard')
        }
      }}
      onCancel={() => {
        toast.info('決済がキャンセルされました')
      }}
      onError={(err) => {
        console.error('PayPal Error:', err)
        toast.error('決済処理中にエラーが発生しました')
      }}
    />
  )
}
```

### Stripe統合例

```tsx
import { loadStripe } from '@stripe/stripe-js'
import { Elements, PaymentElement, useStripe, useElements } from '@stripe/react-stripe-js'

const stripePromise = loadStripe(process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY!)

export function StripePaymentForm({ selectedOption }: StripePaymentFormProps) {
  return (
    <Elements stripe={stripePromise}>
      <CheckoutForm selectedOption={selectedOption} />
    </Elements>
  )
}

function CheckoutForm({ selectedOption }: CheckoutFormProps) {
  const stripe = useStripe()
  const elements = useElements()

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()

    if (!stripe || !elements) return

    const { error } = await stripe.confirmPayment({
      elements,
      confirmParams: {
        return_url: `${window.location.origin}/payment-success`,
      },
    })

    if (error) {
      toast.error(error.message)
    }
  }

  return (
    <form onSubmit={handleSubmit}>
      <PaymentElement />
      <Button type="submit" disabled={!stripe}>
        ${selectedOption.amount.toFixed(2)} で購入
      </Button>
    </form>
  )
}
```

### サンドボックス/本番モードの切り替え

```ts
// .env.local
NEXT_PUBLIC_PAYPAL_CLIENT_ID=sandbox_xxxxx  # サンドボックス
# NEXT_PUBLIC_PAYPAL_CLIENT_ID=live_xxxxx   # 本番

NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_test_xxxxx  # テスト
# NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_live_xxxxx  # 本番
```

---

## 4. 支払い後のクレジット更新

### サーバーアクション

```ts
'use server'

import { db } from '@/lib/db'
import { Users } from '@/lib/schema'
import { eq } from 'drizzle-orm'
import { revalidatePath } from 'next/cache'

export async function updateUserCredits(userId: number, creditsToAdd: number) {
  try {
    // 現在のユーザー情報を取得
    const user = await db.query.Users.findFirst({
      where: eq(Users.id, userId),
    })

    if (!user) {
      throw new Error('ユーザーが見つかりません')
    }

    // クレジット更新
    const [updatedUser] = await db
      .update(Users)
      .set({
        credits: user.credits + creditsToAdd,
      })
      .where(eq(Users.id, userId))
      .returning()

    // キャッシュ再検証
    revalidatePath('/dashboard')

    return { success: true, credits: updatedUser.credits }
  } catch (error) {
    console.error('Credit update error:', error)
    return { success: false, error: 'クレジット更新に失敗しました' }
  }
}
```

### Context即時更新（リフレッシュ不要）

```tsx
'use client'

import { createContext, useContext, useState } from 'react'

interface UserContextType {
  userDetail: User | null
  setUserDetail: React.Dispatch<React.SetStateAction<User | null>>
  refreshUser: () => Promise<void>
}

const UserContext = createContext<UserContextType | undefined>(undefined)

export function UserProvider({ children, initialUser }: UserProviderProps) {
  const [userDetail, setUserDetail] = useState<User | null>(initialUser)

  const refreshUser = async () => {
    const response = await fetch('/api/user')
    const data = await response.json()
    setUserDetail(data)
  }

  return (
    <UserContext.Provider value={{ userDetail, setUserDetail, refreshUser }}>
      {children}
    </UserContext.Provider>
  )
}

export function useUser() {
  const context = useContext(UserContext)
  if (!context) {
    throw new Error('useUser must be used within UserProvider')
  }
  return context
}
```

### 決済完了後の処理フロー

```tsx
onApprove={async (data, actions) => {
  const order = await actions.order?.capture()

  if (order?.status === 'COMPLETED') {
    // 1. サーバーでクレジット更新
    const result = await updateUserCredits(
      userDetail.id,
      selectedOption.credits
    )

    if (result.success) {
      // 2. Context即時更新（ページリフレッシュ不要）
      setUserDetail(prev => ({
        ...prev!,
        credits: result.credits,
      }))

      // 3. 成功通知
      toast.success(`${selectedOption.credits}クレジットを追加しました`)

      // 4. リダイレクト
      router.push('/dashboard')
    } else {
      toast.error(result.error)
    }
  }
}}
```

---

## 5. クレジット消費パターン

### 操作実行時のクレジット減算

```ts
'use server'

export async function consumeCreditsForOperation(userId: number, operation: string) {
  const user = await db.query.Users.findFirst({
    where: eq(Users.id, userId),
  })

  if (!user) {
    throw new Error('ユーザーが見つかりません')
  }

  if (user.credits <= 0) {
    throw new Error('クレジット残高が不足しています')
  }

  // 操作実行
  const result = await executeOperation(operation)

  // クレジット減算
  const [updatedUser] = await db
    .update(Users)
    .set({ credits: user.credits - 1 })
    .where(eq(Users.id, userId))
    .returning()

  return {
    success: true,
    result,
    remainingCredits: updatedUser.credits,
  }
}
```

### クライアントサイドでの統合

```tsx
'use client'

export function OperationButton() {
  const { userDetail, setUserDetail } = useUser()
  const [loading, setLoading] = useState(false)

  const handleOperation = async () => {
    if (userDetail.credits <= 0) {
      toast.error('クレジットが不足しています')
      router.push('/buy-credits')
      return
    }

    setLoading(true)

    try {
      const result = await consumeCreditsForOperation(userDetail.id, 'generate')

      if (result.success) {
        // Context即時更新
        setUserDetail(prev => ({
          ...prev!,
          credits: result.remainingCredits,
        }))

        toast.success('操作が完了しました')
      }
    } catch (error) {
      toast.error(error.message)
    } finally {
      setLoading(false)
    }
  }

  return (
    <Button onClick={handleOperation} disabled={loading || userDetail.credits <= 0}>
      {loading ? '処理中...' : `実行 (1クレジット)`}
    </Button>
  )
}
```

### 残高不足時のガード

```tsx
// 残高不足時の自動リダイレクト
export function useCreditsGuard(minRequired: number = 1) {
  const { userDetail } = useUser()
  const router = useRouter()

  useEffect(() => {
    if (userDetail && userDetail.credits < minRequired) {
      toast.warning('クレジットが不足しています')
      router.push('/buy-credits')
    }
  }, [userDetail, minRequired, router])
}

// 使用例
export function GeneratePage() {
  useCreditsGuard(1)

  return (
    <div>
      {/* ページコンテンツ */}
    </div>
  )
}
```

---

## 6. セキュリティ考慮事項

### サーバーサイド検証

```ts
'use server'

import { auth } from '@clerk/nextjs/server'
import { headers } from 'next/headers'

export async function updateUserCredits(userId: number, creditsToAdd: number) {
  // 1. 認証チェック
  const { userId: authUserId } = await auth()
  if (!authUserId) {
    throw new Error('認証されていません')
  }

  // 2. 権限チェック（自分のアカウントのみ更新可能）
  const user = await db.query.Users.findFirst({
    where: eq(Users.id, userId),
  })

  if (user.authId !== authUserId) {
    throw new Error('権限がありません')
  }

  // 3. 入力検証
  if (creditsToAdd <= 0 || creditsToAdd > 1000) {
    throw new Error('無効なクレジット数です')
  }

  // 4. レート制限チェック
  const headersList = await headers()
  const ip = headersList.get('x-forwarded-for') ?? 'unknown'
  const isRateLimited = await checkRateLimit(ip)

  if (isRateLimited) {
    throw new Error('リクエストが多すぎます。しばらくお待ちください')
  }

  // 5. DB更新
  return await db.update(Users).set({
    credits: user.credits + creditsToAdd,
  }).where(eq(Users.id, userId))
}
```

### クライアントサイドは表示のみ

```tsx
// ❌ 悪い例: クライアントで直接クレジットを操作
function BadExample() {
  const [credits, setCredits] = useState(10)

  const handlePurchase = () => {
    // クライアントサイドでのクレジット操作は検証できない
    setCredits(prev => prev + 100)
  }
}

// ✅ 良い例: サーバーアクションを経由
function GoodExample() {
  const { userDetail, setUserDetail } = useUser()

  const handlePurchase = async () => {
    // サーバーで検証・更新
    const result = await updateUserCredits(userDetail.id, 100)

    // クライアントは結果を反映するだけ
    if (result.success) {
      setUserDetail(prev => ({
        ...prev!,
        credits: result.credits,
      }))
    }
  }
}
```

### 環境変数管理

```bash
# .env.local
# ✅ 公開可能（フロントエンドで使用）
NEXT_PUBLIC_PAYPAL_CLIENT_ID=sandbox_xxxxx
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_test_xxxxx

# ❌ 非公開（サーバーサイドのみ）
PAYPAL_SECRET=xxxxxxx
STRIPE_SECRET_KEY=sk_test_xxxxx
DATABASE_URL=postgresql://...
```

### レースコンディション防止

```ts
// トランザクションでアトミックな更新
export async function purchaseWithCredits(userId: number, itemId: number) {
  return await db.transaction(async (tx) => {
    // 1. ユーザー取得（FOR UPDATE でロック）
    const user = await tx.query.Users.findFirst({
      where: eq(Users.id, userId),
      // PostgreSQL: FOR UPDATE
    })

    if (user.credits < 1) {
      throw new Error('クレジット不足')
    }

    // 2. クレジット減算
    await tx.update(Users)
      .set({ credits: user.credits - 1 })
      .where(eq(Users.id, userId))

    // 3. アイテム作成
    const [item] = await tx.insert(Items).values({
      userId,
      itemId,
    }).returning()

    return item
  })
}
```

### Webhook検証（Stripe例）

```ts
// app/api/webhooks/stripe/route.ts
import { headers } from 'next/headers'
import Stripe from 'stripe'

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!)

export async function POST(req: Request) {
  const body = await req.text()
  const signature = (await headers()).get('stripe-signature')!

  let event: Stripe.Event

  try {
    // Webhook署名検証
    event = stripe.webhooks.constructEvent(
      body,
      signature,
      process.env.STRIPE_WEBHOOK_SECRET!
    )
  } catch (err) {
    console.error('Webhook signature verification failed:', err)
    return new Response('Webhook Error', { status: 400 })
  }

  // イベント処理
  if (event.type === 'checkout.session.completed') {
    const session = event.data.object as Stripe.Checkout.Session
    await fulfillOrder(session)
  }

  return new Response('OK', { status: 200 })
}
```

---

## 7. 判断基準

### 決済ゲートウェイの選択

| 要件 | 推奨 | 理由 |
|------|------|------|
| グローバル展開 | PayPal | 200以上の国・地域で利用可能 |
| サブスクリプション | Stripe | Billing APIが充実、柔軟な料金プラン |
| シンプルな一回購入 | PayPal Buttons | 統合が容易、UIコンポーネント提供 |
| 日本市場特化 | PAY.JP | 日本語サポート、国内決済手段充実 |
| 暗号資産対応 | Coinbase Commerce | 暗号資産決済に特化 |
| B2B請求書払い | Stripe Invoice | 請求書発行・管理機能 |

### 課金モデルの選択

| 課金モデル | 適用ケース | 実装パターン |
|----------|----------|------------|
| **クレジット制** | API呼び出し、AI生成、変換処理 | 従量課金、購入単位が柔軟 |
| **サブスクリプション** | 継続的なサービス利用 | 月額/年額固定、予測可能な収益 |
| **使用量ベース** | ストレージ、転送量、処理時間 | 実使用量に応じた課金 |
| **Freemium** | ユーザー獲得重視 | 基本機能無料、高度機能有料 |
| **階層プラン** | 多様なユーザーセグメント | Starter/Pro/Enterprise等 |

### クレジットパッケージ設計

| 考慮事項 | 推奨アプローチ |
|---------|--------------|
| **価格設定** | 大容量ほど単価を下げる（バルクディスカウント） |
| **最小単位** | 初回購入の心理的障壁を下げる（$0.99〜） |
| **人気プラン** | 中間プランを目立たせる（most popularバッジ） |
| **高額プラン** | アンカリング効果で中間プランの価値を高める |
| **無料クレジット** | 新規ユーザーに試用機会を提供（10クレジット等） |

### セキュリティレベル

| 機能 | 必須対策 |
|------|---------|
| **決済処理** | Webhook署名検証、サーバーサイド検証 |
| **クレジット更新** | トランザクション、認証・認可チェック |
| **API保護** | レート制限、CSRF対策、入力検証 |
| **環境変数** | Secret Keyは非公開、Clientのみ公開 |
| **ログ** | 決済ログ、エラーログの記録（個人情報除外） |

---

## 実装チェックリスト

### 基本機能
- [ ] ユーザーテーブルにcreditsフィールド追加
- [ ] 新規登録時のデフォルトクレジット付与
- [ ] クレジット残高表示UI
- [ ] クレジット購入ページ
- [ ] 決済ゲートウェイ統合
- [ ] 支払い成功後のクレジット更新

### セキュリティ
- [ ] サーバーサイド検証の実装
- [ ] Webhook署名検証
- [ ] 認証・認可チェック
- [ ] レート制限
- [ ] トランザクション処理

### UX
- [ ] 残高不足時の通知
- [ ] 購入完了時のフィードバック
- [ ] クレジット購入へのスムーズな導線
- [ ] Context更新でリアルタイム残高表示
- [ ] ローディング状態の表示

### テスト
- [ ] サンドボックス環境でのテスト決済
- [ ] クレジット消費フローのテスト
- [ ] エッジケース（残高0、同時購入等）のテスト
- [ ] Webhook受信テスト
