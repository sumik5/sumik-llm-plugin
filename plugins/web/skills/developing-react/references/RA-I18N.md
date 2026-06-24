# React i18n（国際化）アーキテクチャ

i18n（internationalization、"i" と "n" の間に18文字）は、アプリケーションを複数言語に対応させる設計。テキストをコードに直接埋め込まず、翻訳キー経由で参照することで、言語追加時にコンポーネントを変更せず翻訳ファイルの追加だけで対応できる。

翻訳対象は文字列だけではない。日付フォーマット・数値フォーマット・複数形（1 item vs 2 items）・テキスト方向（アラビア語・ヘブライ語は右→左）も考慮が必要。

---

## 翻訳の保管場所

| アプローチ | メリット | デメリット | 推奨場面 |
|---|---|---|---|
| コードベース内（JSON/TS） | バージョン管理統合・型安全・シンプル | 翻訳更新にデプロイが必要 | ほとんどのプロジェクト |
| 外部翻訳サービス（Lokalise, Crowdin, Phrase 等） | プロ翻訳者がコードを触らない・翻訳メモリ・ワークフロー管理 | コスト・複雑さ・連携オーバーヘッド | 大規模チーム・プロ翻訳者利用時 |

**推奨**: TypeScript ファイルとしてコードベース内に保管することで型安全と開発ワークフローの統合を実現。プロジェクト拡大後に外部サービスへ移行も可能。

---

## i18n システムフロー

```
1. リクエスト受信
   └─ 言語 cookie を読み取り（未設定ならデフォルト言語）

2. サーバーサイドレンダリング（SSR）
   └─ 検出言語で全翻訳を読み込み
   └─ 翻訳済み HTML を返却（SEO・初期表示の最適化）

3. クライアントハイドレーション
   └─ HTML の lang 属性から言語を検出
   └─ バンドル済み翻訳（common/navigation）を使用
   └─ サーバーと同一翻訳で hydrate → ちらつきなし

4. 動的翻訳ロード
   └─ ページ遷移時に必要な namespace だけ API 経由で取得
   └─ 積極的なキャッシュで2回目以降は即時

5. 言語切替
   └─ API で cookie を更新 + client-side i18next を changeLanguage()
   └─ 未ロードの翻訳を fetch → UI を新言語で再レンダー
```

---

## セットアップ

### Namespace による翻訳ファイルの構成

翻訳ファイルを機能・ページ単位で分割することで、巨大な単一ファイルを避けつつオンデマンドロードを実現する。

#### アプリレベル翻訳（`src/app/locales/`）

```typescript
// src/app/locales/en/common.ts
export default {
  cancel: 'Cancel',
  delete: 'Delete',
  deleting: 'Deleting...',
  languageChanged: 'Language changed to {{lng}}',
};
```

```typescript
// src/app/locales/en/home.ts
export default {
  meta: {
    description: 'Application description',
    title: 'App Title',
  },
  title: 'Welcome',
  subtitle: 'Subtitle text',
};
```

ネストでグループ化（例: `meta` に SEO 関連翻訳をまとめる）するとキーの在処が明確になる。

#### フィーチャースコープ翻訳（`src/features/<feature>/locales/`）

フィーチャーを自己完結させるため、翻訳ファイルもフィーチャーディレクトリ内に配置する:

```typescript
// src/features/auth/locales/en.ts
export default {
  alreadyHaveAccount: 'Already have an account?',
  creatingAccount: 'Creating account...',
  dontHaveAccount: "Don't have an account?",
};
```

#### 翻訳の統合（index.ts）

```typescript
// src/app/locales/en/index.ts
import type { ResourceLanguage } from 'i18next';
import authTranslations from '@/features/auth/locales/en';
import ideasTranslations from '@/features/ideas/locales/en';
import common from './common';
import home from './home';
import navigation from './navigation';

export default {
  common,
  home,
  navigation,
  auth: authTranslations,
  ideas: ideasTranslations,
} satisfies ResourceLanguage;

// 使用時: common:cancel / auth:loginTitle
```

### 中央設定ファイル

```typescript
// src/config/i18n.ts
export const languages = {
  en: 'English',
  es: 'Español',
} as const;

export type Language = keyof typeof languages;
const supportedLanguages = Object.keys(languages) as Language[];

export const i18nConfig = {
  defaultNS: 'common' as const,
  fallbackLng: 'en' as const,
  supportedLanguages,
  backend: {
    loadPath: '/api/locales/{{lng}}/{{ns}}',
  },
  detection: {
    order: ['htmlTag'], // HTML lang 属性から言語検出
    caches: [],         // cookie を検出結果のキャッシュに使わない
  },
  cookieName: 'lng' as const,
};
```

| 設定項目 | 説明 |
|---|---|
| `defaultNS: 'common'` | namespace 未指定時のデフォルト |
| `fallbackLng: 'en'` | 指定言語が未対応の場合のフォールバック |
| `backend.loadPath` | 動的ロード用 API URL パターン（`{{lng}}` / `{{ns}}` は自動置換） |
| `detection.order: ['htmlTag']` | クライアントが HTML `lang` 属性から言語を検出 |
| `cookieName` | 言語設定を永続化する cookie 名 |

### i18next ミドルウェア（サーバー用）

```typescript
// src/app/middleware/i18next.ts
import { createCookie } from 'react-router';
import { createI18nextMiddleware } from 'remix-i18next/middleware';
import { resources } from '@/app/locales';
import { i18nConfig } from '@/config/i18n';

export const localeCookie = createCookie(i18nConfig.cookieName, {
  path: '/',
  sameSite: 'lax',
  secure: process.env.NODE_ENV === 'production',
  httpOnly: true,  // JS からアクセス不可のセキュアな cookie
});

export const [i18nextMiddleware, getLocale, getInstance] =
  createI18nextMiddleware({
    detection: {
      supportedLanguages: i18nConfig.supportedLanguages,
      fallbackLanguage: i18nConfig.fallbackLng,
      cookie: localeCookie,
    },
    i18next: {
      resources,
      defaultNS: i18nConfig.defaultNS,
    },
  });
```

このミドルウェアが行うこと: cookie から言語を検出 → 全翻訳を読み込んだ i18next インスタンスを初期化 → サーバーレンダリングで正しい言語を使用。

### サーバー初期化（entry.server.tsx）

```tsx
// src/app/entry.server.tsx
import { I18nextProvider } from 'react-i18next';
import { ServerRouter } from 'react-router';
import { getInstance } from './middleware/i18next';

export default function handleRequest(
  request: Request,
  responseStatusCode: number,
  responseHeaders: Headers,
  routerContext: EntryContext,
  loadContext: RouterContextProvider,
) {
  const { pipe } = renderToPipeableStream(
    <I18nextProvider i18n={getInstance(loadContext)}>
      <ServerRouter context={routerContext} url={request.url} />
    </I18nextProvider>,
    { /* ... */ },
  );
}
```

ルートレイアウトで `lang` / `dir` 属性を設定:

```tsx
// src/app/root.tsx
export const middleware = [nonceMiddleware, userMiddleware, i18nextMiddleware];

export function Layout({ children }: { children: React.ReactNode }) {
  const { i18n } = useTranslation();

  return (
    // lang: スクリーンリーダー・検索エンジン・ブラウザ翻訳提案に利用
    // dir: RTL 言語（アラビア語・ヘブライ語等）のレイアウト自動制御
    <html lang={i18n.language} dir={i18n.dir(i18n.language)}>
      {children}
    </html>
  );
}
```

`i18n.dir()` は LTR 言語で `'ltr'`、RTL 言語で `'rtl'` を返す。

### クライアント初期化（部分バンドル戦略）

全翻訳をバンドルするとダウンロードサイズが膨大になる。常時利用する namespace（`common` / `navigation`）のみバンドルし、残りはオンデマンドで取得する:

```tsx
// src/app/entry.client.tsx
import i18next from 'i18next';
import I18nextBrowserLanguageDetector from 'i18next-browser-languagedetector';
import Fetch from 'i18next-fetch-backend';
import { I18nextProvider, initReactI18next } from 'react-i18next';
import { hydrateRoot } from 'react-dom/client';
import { HydratedRouter } from 'react-router/dom';
import { i18nConfig } from '@/config/i18n';
import { resources } from './locales';

async function main() {
  await i18next
    .use(initReactI18next)           // React の useTranslation フックを有効化
    .use(Fetch)                       // API から翻訳を動的ロード
    .use(I18nextBrowserLanguageDetector) // HTML lang 属性から言語検出
    .init({
      defaultNS: i18nConfig.defaultNS,
      partialBundledLanguages: true,  // 一部バンドル・残りはオンデマンド
      resources: {
        en: {
          common: resources.en.common,
          navigation: resources.en.navigation,
        },
        es: {
          common: resources.es.common,
          navigation: resources.es.navigation,
        },
      },
      ns: ['common', 'navigation'],   // 起動時にプリロードする namespace
      fallbackLng: i18nConfig.fallbackLng,
      detection: i18nConfig.detection,
      backend: i18nConfig.backend,
    });

  startTransition(() => {
    hydrateRoot(
      document,
      <I18nextProvider i18n={i18next}>
        <StrictMode>
          <HydratedRouter />
        </StrictMode>
      </I18nextProvider>,
    );
  });
}

main().catch(console.error);
```

---

## 翻訳 API エンドポイント

動的ロードに必要なエンドポイント。Zod でパラメータを検証し、キャッシュヘッダーを付与する:

```typescript
// src/app/routes/api/locales.ts
import { cacheHeader } from 'pretty-cache-header';
import { data } from 'react-router';
import { z } from 'zod';
import { resources } from '@/app/locales';
import type { Language } from '@/config/i18n';

export async function loader({ params }: Route.LoaderArgs) {
  const lng = z
    .enum(Object.keys(resources) as Array<Language>)
    .safeParse(params.lng);
  if (lng.error) return data({ error: lng.error }, { status: 400 });

  const namespaces = resources[lng.data];
  const ns = z
    .enum(Object.keys(namespaces) as Array<keyof typeof namespaces>)
    .safeParse(params.ns);
  if (ns.error) return data({ error: ns.error }, { status: 400 });

  const headers = new Headers();
  if (process.env.NODE_ENV === 'production') {
    headers.set(
      'Cache-Control',
      cacheHeader({
        maxAge: '5m',
        sMaxage: '1d',
        staleWhileRevalidate: '7d',
        staleIfError: '7d',
      }),
    );
  }

  return data(namespaces[ns.data], { headers });
}
```

翻訳ファイルはほぼ変わらないため積極的にキャッシュする。初回ロード後はユーザーが待つことなく翻訳が利用できる。

---

## 翻訳の使用

### useTranslation フック

```tsx
import { useTranslation } from 'react-i18next';

export default function HomePage() {
  const { t } = useTranslation(['home']);

  return (
    <div>
      <h1>{t('title')}</h1>           {/* home namespace の title */}
      <p>{t('meta.description')}</p>  {/* ドット記法でネスト */}
    </div>
  );
}
```

デフォルト namespace（`common`）は namespace 指定なしでアクセス可能:

```tsx
function DeleteButton() {
  const { t } = useTranslation();
  return <button>{t('delete')}</button>; // common:delete
}
```

### 補間（Interpolation）

`{{変数名}}` プレースホルダーで動的な値を埋め込む:

```typescript
// 翻訳定義
export default {
  welcome: 'Welcome, {{username}}!',
};
```

```tsx
function WelcomeMessage({ username }: { username: string }) {
  const { t } = useTranslation();
  return <h1>{t('welcome', { username })}</h1>;
  // → "Welcome, John!"
}
```

語順が言語によって異なる場合でも、翻訳者がプレースホルダーの位置を自由に制御できる。

### 複数形（Pluralization）

`_one` / `_other` サフィックスで単数・複数形を定義する:

```typescript
// src/features/items/locales/en.ts
export default {
  itemsCount_one: '{{count}} Item by {{username}}',
  itemsCount_other: '{{count}} Items by {{username}}',
};

// src/features/items/locales/es.ts
export default {
  itemsCount_one: '{{count}} Elemento de {{username}}',
  itemsCount_other: '{{count}} Elementos de {{username}}',
};
```

```tsx
function ItemList({ count, username }: { count: number; username: string }) {
  const { t } = useTranslation(['items']);
  return <p>{t('items:itemsCount', { count, username })}</p>;
  // count=1 → "1 Item by John" / count=5 → "5 Items by John"
}
```

`count` の値に応じて i18next が自動的に適切な形式を選択する。コードは変わらず、翻訳ファイルだけが言語ごとに異なる。

### 日付・数値フォーマット

`Intl.DateTimeFormat` API でロケールに応じたフォーマットを適用する:

```typescript
// src/lib/date.ts
export function formatDate(date: string | Date, locale: string = 'en'): string {
  const d = date instanceof Date ? date : new Date(date);
  if (isNaN(d.getTime())) {
    console.error(`Invalid date: "${date}"`);
    return '';
  }
  return new Intl.DateTimeFormat(locale, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    timeZone: 'UTC',
  }).format(d);
  // en: "Jan 15, 2024" / es: "15 ene 2024"
}
```

コンポーネントで `i18n.language` を渡す:

```tsx
import { useTranslation } from 'react-i18next';
import { formatDate } from '@/lib/date';

export function ItemCard({ item }: ItemCardProps) {
  const { i18n } = useTranslation();
  return (
    <div>
      <h2>{item.title}</h2>
      <p>Created: {formatDate(item.createdAt, i18n.language)}</p>
    </div>
  );
}
```

---

## 型安全な翻訳キー

TypeScript のモジュール拡張で i18next に翻訳構造を伝える:

```typescript
// src/app/types/i18next.d.ts
import 'i18next';
import type { resources } from '@/app/locales';
import { i18nConfig } from '@/config/i18n';

declare module 'i18next' {
  interface CustomTypeOptions {
    defaultNS: typeof i18nConfig.defaultNS;
    resources: typeof resources.en;  // 英語翻訳を型の真実のソースとして使用
  }
}
```

| 効果 | 詳細 |
|---|---|
| タイポ検出 | `t('welcom')` をコンパイル時にエラー |
| キー補完 | エディタで `t('` 入力時に利用可能なキー一覧が表示 |
| 欠落検出 | 他言語でキーが欠けていると TypeScript が警告 |
| ドット記法 | `t('home.meta.title')` のようなネストキーも型補完対象 |

英語翻訳を「真実のソース」とし、全言語のキーが一致することを型で保証する。

---

## 言語切替

### LanguageSwitcher コンポーネント

```tsx
// src/components/language-switcher.tsx
import { Check, Globe } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import { i18nConfig, languages, type Language } from '@/config/i18n';

export function LanguageSwitcher() {
  const { t, i18n } = useTranslation(['components', 'common']);

  const handleLanguageChange = async (language: Language) => {
    const formData = new FormData();
    formData.append(i18nConfig.cookieName, language);

    const response = await fetch('/api/set-language', {
      method: 'POST',
      body: formData,
    });

    if (response.ok) {
      await i18n.changeLanguage(language); // クライアント側を即座に更新
    }
  };

  return (
    <DropdownMenu>
      <DropdownMenuTrigger render={
        <Button variant="ghost" size="sm" className="h-8 w-8 p-0">
          <Globe className="h-4 w-4" />
        </Button>
      } />
      <DropdownMenuContent align="end">
        {Object.entries(languages).map(([key, value]) => (
          <DropdownMenuItem
            key={key}
            onClick={() => handleLanguageChange(key as Language)}
          >
            {i18n.language === key && <Check className="h-4 w-4" />}
            <span className={i18n.language === key ? '' : 'ml-6'}>{value}</span>
          </DropdownMenuItem>
        ))}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
```

言語変更の2ステップが両方必要な理由:
1. **サーバー（cookie 更新）**: ページリロード・次回訪問時も設定が維持される
2. **クライアント（`changeLanguage()`）**: リロードなしで即座に UI が新言語で再レンダーされる

### set-language API エンドポイント

```typescript
// src/app/routes/api/set-language.ts
import { data } from 'react-router';
import z from 'zod';
import { localeCookie } from '@/app/middleware/i18next';
import { i18nConfig, languages, type Language } from '@/config/i18n';

const languageSchema = z.enum(
  Object.keys(languages) as [Language, ...Language[]],
);

export async function action({ request }: Route.ActionArgs) {
  const formData = await request.formData();
  const language = languageSchema.safeParse(
    formData.get(i18nConfig.cookieName),
  );

  if (!language.success) {
    return data({ success: false }, { status: 400 });
  }

  return data(
    { success: true },
    {
      headers: {
        'Set-Cookie': await localeCookie.serialize(language.data),
      },
    },
  );
}
```

---

## 実装チェックリスト

- [ ] `src/config/i18n.ts` で言語・namespace・backend 設定を定義
- [ ] `src/app/locales/` にアプリレベル翻訳ファイルを配置し index.ts で統合
- [ ] `src/features/<feature>/locales/` にフィーチャーレベル翻訳ファイルを配置
- [ ] `createI18nextMiddleware` でサーバーミドルウェアを設定（httpOnly cookie）
- [ ] `entry.server.tsx` に `I18nextProvider` でラップ
- [ ] `root.tsx` の `<html>` に `lang` / `dir` 属性を設定
- [ ] `entry.client.tsx` で部分バンドル + Fetch backend を設定（hydrate 前に初期化）
- [ ] `/api/locales/:lng/:ns` エンドポイントを実装（Zod バリデーション + キャッシュ）
- [ ] `src/app/types/i18next.d.ts` で型安全な翻訳キーを設定
- [ ] `/api/set-language` エンドポイントを実装
- [ ] `LanguageSwitcher` コンポーネントを実装
- [ ] RTL 言語サポート時は CSS ロジカルプロパティ（`margin-inline-start` 等）を使用
