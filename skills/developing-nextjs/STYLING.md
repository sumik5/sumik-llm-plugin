# Tailwind CSS + shadcn/ui スタイリングガイド

## 概要

このプロジェクトでは、Tailwind CSS（最新版）とshadcn/uiを使用してスタイリングを行います。

## Tailwind CSS（最新版）

### セットアップ

> **重要**: Tailwind CSS最新版はCSS-first設定を採用。`@tailwind`ディレクティブは廃止され、`@import "tailwindcss"`を使用する。`tailwind.config.js`はプラグインやshadcn/ui互換のために共存可能。

**インストール:**
```bash
pnpm add tailwindcss @tailwindcss/postcss tailwindcss-animate autoprefixer
pnpm add -D tailwind-merge
```

**postcss.config.cjs:**
```javascript
module.exports = {
  plugins: {
    "@tailwindcss/postcss": {},
  },
};
```

> 注: `"type": "module"`のプロジェクトではCommonJS形式の`.cjs`拡張子を使用。

**globals.css:**
```css
/* src/app/globals.css */
@import "tailwindcss";

@theme {
  --color-background: 0 0% 100%;
  --color-foreground: 222.2 84% 4.9%;
  --radius: 0.5rem;
}

@layer base {
  :root {
    --background: 0 0% 100%;
    --foreground: 222.2 84% 4.9%;
    --primary: 222.2 47.4% 11.2%;
    --primary-foreground: 210 40% 98%;
    --secondary: 210 40% 96.1%;
    --secondary-foreground: 222.2 47.4% 11.2%;
    --muted: 210 40% 96.1%;
    --muted-foreground: 215.4 16.3% 46.9%;
    --accent: 210 40% 96.1%;
    --accent-foreground: 222.2 47.4% 11.2%;
    --destructive: 0 84.2% 60.2%;
    --destructive-foreground: 210 40% 98%;
    --border: 214.3 31.8% 91.4%;
    --input: 214.3 31.8% 91.4%;
    --ring: 222.2 84% 4.9%;
    --radius: 0.5rem;
  }

  .dark {
    --background: 222.2 84% 4.9%;
    --foreground: 210 40% 98%;
    --primary: 210 40% 98%;
    --primary-foreground: 222.2 47.4% 11.2%;
    --secondary: 217.2 32.6% 17.5%;
    --secondary-foreground: 210 40% 98%;
    --muted: 217.2 32.6% 17.5%;
    --muted-foreground: 215 20.2% 65.1%;
    --accent: 217.2 32.6% 17.5%;
    --accent-foreground: 210 40% 98%;
    --destructive: 0 62.8% 30.6%;
    --destructive-foreground: 210 40% 98%;
    --border: 217.2 32.6% 17.5%;
    --input: 217.2 32.6% 17.5%;
    --ring: 212.7 26.8% 83.9%;
  }
}

@layer base {
  * {
    border-color: hsl(var(--border));
  }
  body {
    @apply bg-background text-foreground;
  }
}
```

**tailwind.config.js:**
```javascript
export default {
  darkMode: ["class"],
  content: [
    "./src/app/**/*.{ts,tsx}",
    "./src/components/**/*.{ts,tsx}",
    "!./node_modules/**",
  ],
  theme: {
    extend: {
      borderRadius: {
        lg: "var(--radius)",
        md: "calc(var(--radius) - 2px)",
        sm: "calc(var(--radius) - 4px)",
      },
      colors: {
        background: "hsl(var(--background))",
        foreground: "hsl(var(--foreground))",
        primary: {
          DEFAULT: "hsl(var(--primary))",
          foreground: "hsl(var(--primary-foreground))",
        },
        secondary: {
          DEFAULT: "hsl(var(--secondary))",
          foreground: "hsl(var(--secondary-foreground))",
        },
        muted: {
          DEFAULT: "hsl(var(--muted))",
          foreground: "hsl(var(--muted-foreground))",
        },
        accent: {
          DEFAULT: "hsl(var(--accent))",
          foreground: "hsl(var(--accent-foreground))",
        },
        destructive: {
          DEFAULT: "hsl(var(--destructive))",
          foreground: "hsl(var(--destructive-foreground))",
        },
        border: "hsl(var(--border))",
        input: "hsl(var(--input))",
        ring: "hsl(var(--ring))",
      },
    },
  },
  plugins: [require("tailwindcss-animate")],
};
```

> **構成のポイント:**
> - `@import "tailwindcss"` + `@theme`ブロック: CSS-first設定（最新版の標準）
> - `tailwind.config.js`: プラグイン（`tailwindcss-animate`）、`darkMode`設定、shadcn/ui互換のために共存
> - CSS変数 `hsl(var(--xxx))` 形式: shadcn/uiとの統合パターン
> - `:root` / `.dark` セレクタ: ライト/ダークモードの切り替え

### 旧バージョンとの主な違い（旧バージョンの書き方は使わないこと）

| 項目 | ❌ 旧バージョン（禁止） | ✅ 最新版（必須） |
|---|---|---|
| CSS読み込み | `@tailwind base/components/utilities;` | `@import "tailwindcss";` |
| テーマトークン | JS内のみで定義 | CSS内の`@theme { }`で定義可能 |
| PostCSS | `tailwindcss`プラグイン直接指定 | `@tailwindcss/postcss` |
| 初期化 | `tailwindcss init -p` | 手動でファイル作成 |

### 基本的な使用方法

```tsx
<div className="flex items-center justify-between p-4 bg-gray-100">
  <h1 className="text-2xl font-bold">Title</h1>
  <button className="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600">
    Click Me
  </button>
</div>
```

### レスポンシブデザイン

```tsx
<div className="w-full md:w-1/2 lg:w-1/3">
  {/* モバイル: 100%, タブレット: 50%, デスクトップ: 33% */}
</div>
```

## shadcn/ui

### 初期設定

```bash
pnpm dlx shadcn@latest init
```

**components.json（自動生成）:**
```json
{
  "$schema": "https://ui.shadcn.com/schema.json",
  "style": "default",
  "rsc": true,
  "tsx": true,
  "tailwind": {
    "config": "tailwind.config.js",
    "css": "src/app/globals.css",
    "baseColor": "slate",
    "cssVariables": true
  },
  "aliases": {
    "utils": "@/lib/utils",
    "components": "@/components"
  }
}
```

### コンポーネントの追加

```bash
# 個別追加
pnpm dlx shadcn@latest add button
pnpm dlx shadcn@latest add card
pnpm dlx shadcn@latest add dialog

# 複数同時追加
pnpm dlx shadcn@latest add button card dialog form input
```

### 基本的な使用例

#### Button

```tsx
import { Button } from "@/components/ui/button";

export function Example() {
  return (
    <div className="flex gap-2">
      <Button>Default</Button>
      <Button variant="destructive">Destructive</Button>
      <Button variant="outline">Outline</Button>
      <Button variant="ghost">Ghost</Button>
    </div>
  );
}
```

#### Card

```tsx
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";

export function Example() {
  return (
    <Card>
      <CardHeader>
        <CardTitle>Card Title</CardTitle>
        <CardDescription>Card Description</CardDescription>
      </CardHeader>
      <CardContent>
        <p>Card Content</p>
      </CardContent>
      <CardFooter>
        <Button>Action</Button>
      </CardFooter>
    </Card>
  );
}
```

#### Dialog

```tsx
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";

export function Example() {
  return (
    <Dialog>
      <DialogTrigger asChild>
        <Button>Open</Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Are you sure?</DialogTitle>
          <DialogDescription>
            This action cannot be undone.
          </DialogDescription>
        </DialogHeader>
      </DialogContent>
    </Dialog>
  );
}
```

### フォーム統合（React Hook Form + Zod）

```tsx
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { Button } from "@/components/ui/button";
import {
  Form,
  FormControl,
  FormDescription,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form";
import { Input } from "@/components/ui/input";

const formSchema = z.object({
  username: z.string().min(2).max(50),
});

export function ProfileForm() {
  const form = useForm<z.infer<typeof formSchema>>({
    resolver: zodResolver(formSchema),
    defaultValues: {
      username: "",
    },
  });

  function onSubmit(values: z.infer<typeof formSchema>) {
    console.log(values);
  }

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-8">
        <FormField
          control={form.control}
          name="username"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Username</FormLabel>
              <FormControl>
                <Input placeholder="shadcn" {...field} />
              </FormControl>
              <FormDescription>
                This is your public display name.
              </FormDescription>
              <FormMessage />
            </FormItem>
          )}
        />
        <Button type="submit">Submit</Button>
      </form>
    </Form>
  );
}
```

## カスタムコンポーネント作成

### cn()ユーティリティ

```typescript
// src/lib/utils.ts
import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
```

**使用例:**
```tsx
import { cn } from "@/lib/utils";

export function CustomButton({ className, ...props }) {
  return (
    <button
      className={cn(
        "px-4 py-2 bg-blue-500 text-white rounded",
        className
      )}
      {...props}
    />
  );
}
```

## ダークモード対応

### next-themesのセットアップ

```bash
pnpm add next-themes
```

**ThemeProvider:**
```tsx
// src/components/common/base/ThemeProvider.tsx
"use client";

import { ThemeProvider as NextThemesProvider } from "next-themes";
import type { ReactNode } from "react";

export function ThemeProvider({ children }: { children: ReactNode }) {
  return (
    <NextThemesProvider attribute="class" defaultTheme="system">
      {children}
    </NextThemesProvider>
  );
}
```

**ルートレイアウトに追加:**
```tsx
// src/app/layout.tsx
import { ThemeProvider } from "@/components/common/base/ThemeProvider";

export default function RootLayout({ children }) {
  return (
    <html lang="ja" suppressHydrationWarning>
      <body>
        <ThemeProvider>{children}</ThemeProvider>
      </body>
    </html>
  );
}
```

**テーマ切り替えボタン:**
```tsx
"use client";

import { useTheme } from "next-themes";
import { Button } from "@/components/ui/button";

export function ThemeToggle() {
  const { theme, setTheme } = useTheme();

  return (
    <Button
      variant="ghost"
      onClick={() => setTheme(theme === "dark" ? "light" : "dark")}
    >
      {theme === "dark" ? "🌞" : "🌙"}
    </Button>
  );
}
```

## ベストプラクティス

### 1. コンポーネントの再利用性

**❌ 悪い例:**
```tsx
<div className="flex items-center justify-between p-4 bg-gray-100 rounded shadow">
  <h2 className="text-xl font-bold">Title</h2>
  <button className="px-4 py-2 bg-blue-500 text-white rounded">Action</button>
</div>
```

**✅ 良い例:**
```tsx
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";

<Card>
  <CardHeader>
    <CardTitle>Title</CardTitle>
  </CardHeader>
  <CardContent>
    <Button>Action</Button>
  </CardContent>
</Card>
```

### 2. 一貫性のあるスタイリング

**カラーパレット、スペーシング、フォントサイズを統一:**
```css
/* globals.css でテーマトークン定義 */
@theme {
  --color-brand: 222.2 47.4% 11.2%;
}

/* :root でCSS変数定義 */
:root {
  --brand: 222.2 47.4% 11.2%;
}
```

```javascript
// tailwind.config.js で参照
theme: {
  extend: {
    colors: {
      brand: "hsl(var(--brand))",
    },
  },
}
```

### 3. アクセシビリティ

**適切なARIA属性とキーボードナビゲーション:**
```tsx
<button
  aria-label="Close dialog"
  onClick={onClose}
  className="p-2 hover:bg-gray-100 rounded"
>
  <XIcon />
</button>
```

## 参考資料

- **Tailwind CSS公式**: https://tailwindcss.com
- **shadcn/ui公式**: https://ui.shadcn.com
- **next-themes**: https://github.com/pacocoursey/next-themes

---

**関連ドキュメント:**
- [EXAMPLES.md](./EXAMPLES.md) - 実装例
- [PROJECT-STRUCTURE.md](./PROJECT-STRUCTURE.md) - プロジェクト構造
