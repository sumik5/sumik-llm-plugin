# AI API統合パターン

Next.js SaaSアプリケーションにAI機能を統合する際のベストプラクティスとパターン集。

---

## 1. AI APIプロバイダ統合

### サーバーサイド統合の原則

AI APIの呼び出しは必ずサーバーサイド（Next.js API Route）で実行する。クライアントサイドからの直接呼び出しはAPIキー漏洩のリスクがあるため禁止。

### API Route パターン

```typescript
// app/api/generate/route.ts
import { NextRequest, NextResponse } from 'next/server';
import Replicate from 'replicate';

const replicate = new Replicate({
  auth: process.env.REPLICATE_API_TOKEN
});

export async function POST(request: NextRequest) {
  try {
    const { imageUrl, roomType, designType, additionalReq } = await request.json();

    const input = {
      image: imageUrl,
      prompt: `A ${roomType} with a ${designType} style interior ${additionalReq}`
    };

    const output = await replicate.run("model-name:version", { input });

    return NextResponse.json({ success: true, output });
  } catch (error) {
    return NextResponse.json(
      { success: false, error: error.message },
      { status: 500 }
    );
  }
}
```

### 環境変数管理

```bash
# .env.local
REPLICATE_API_TOKEN=r8_xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
OPENAI_API_KEY=sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
FIREBASE_API_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**セキュリティチェックリスト:**
- [ ] `.env.local` が `.gitignore` に含まれている
- [ ] 本番環境ではVercel/Netlify等の環境変数機能を使用
- [ ] APIキーはサーバーサイドコード（API Route）でのみ参照
- [ ] クライアントサイドで必要な設定は `NEXT_PUBLIC_` プレフィックスのみ使用

---

## 2. 画像処理パイプライン

### 全体フロー

```
[1. ユーザー画像アップロード]
    ↓
[2. 元画像をクラウドストレージに保存]
    ↓
[3. ストレージURLを取得]
    ↓
[4. AI APIにURL送信]
    ↓
[5. AI生成画像URLを受信]（⚠️ 一時URL: 30-40分で失効）
    ↓
[6. AI画像をBase64変換]
    ↓
[7. Base64画像をクラウドストレージに永続保存]
    ↓
[8. 永続URLをDBに記録]
    ↓
[9. ユーザーに結果表示]
```

### なぜBase64変換が必要か

**問題:** AI APIが返す画像URLは一時的（30-40分で失効）

**解決策:** Base64変換して自社ストレージに再アップロード

| 方法 | メリット | デメリット |
|------|---------|-----------|
| AI APIのURL直接保存 | シンプル | 画像が失効する |
| Base64変換→再アップロード | 永続保存 | 追加処理が必要 |
| CDN連携 | 高速配信 | コスト増加 |

**推奨:** Base64変換→再アップロード（無料枠内で運用可能）

---

## 3. ファイルストレージ統合（Firebase Storage例）

### Firebase初期設定

```typescript
// lib/firebase.ts
import { initializeApp } from 'firebase/app';
import { getStorage } from 'firebase/storage';

const firebaseConfig = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID
};

const app = initializeApp(firebaseConfig);
export const storage = getStorage(app);
```

### 画像アップロード（バイナリ）

```typescript
import { ref, uploadBytes, getDownloadURL } from 'firebase/storage';
import { storage } from '@/lib/firebase';

async function uploadOriginalImage(file: File): Promise<string> {
  const fileName = `${Date.now()}_raw.png`;
  const imageRef = ref(storage, `project-name/${fileName}`);

  await uploadBytes(imageRef, file);
  const downloadUrl = await getDownloadURL(imageRef);

  return downloadUrl;
}
```

### Base64画像アップロード

```typescript
import { ref, uploadString, getDownloadURL } from 'firebase/storage';

async function uploadBase64Image(base64Image: string): Promise<string> {
  const fileName = `${Date.now()}_generated.png`;
  const storageRef = ref(storage, `project-name/${fileName}`);

  await uploadString(storageRef, base64Image, 'data_url');
  const downloadUrl = await getDownloadURL(storageRef);

  return downloadUrl;
}
```

### ストレージプロバイダ比較

| プロバイダ | 無料枠 | CDN | 推奨用途 |
|-----------|--------|-----|---------|
| Firebase Storage | 5GB/月 | ✅ | 中小規模SaaS |
| AWS S3 | 5GB/12ヶ月（初年度） | CloudFront併用 | エンタープライズ |
| Vercel Blob | 500MB/月 | ✅ | Vercelホスティング時 |
| Supabase Storage | 1GB | ✅ | Supabase DB併用時 |

---

## 4. Base64画像変換

### URL→ArrayBuffer→Base64変換パターン

```typescript
import axios from 'axios';

async function convertImageToBase64(imageUrl: string): Promise<string> {
  // ArrayBufferとして画像を取得
  const response = await axios.get(imageUrl, {
    responseType: 'arraybuffer'
  });

  // BufferからBase64に変換
  const base64Raw = Buffer.from(response.data).toString('base64');

  // Data URL形式に整形
  return `data:image/png;base64,${base64Raw}`;
}
```

### フロントエンド実装（ブラウザ環境）

```typescript
async function convertImageToBase64Browser(imageUrl: string): Promise<string> {
  const response = await fetch(imageUrl);
  const blob = await response.blob();

  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onloadend = () => resolve(reader.result as string);
    reader.onerror = reject;
    reader.readAsDataURL(blob);
  });
}
```

### エラーハンドリング

```typescript
async function safeConvertToBase64(imageUrl: string): Promise<string | null> {
  try {
    return await convertImageToBase64(imageUrl);
  } catch (error) {
    console.error('Base64変換エラー:', error);

    // リトライロジック
    if (error.response?.status === 404) {
      throw new Error('画像URLが無効です');
    }

    // フォールバック
    return null;
  }
}
```

---

## 5. プロンプト構築パターン

### 動的プロンプト生成

```typescript
interface PromptParams {
  roomType: string;
  designType: string;
  additionalReq?: string;
  style?: string;
  mood?: string;
}

function buildPrompt(params: PromptParams): string {
  const { roomType, designType, additionalReq, style, mood } = params;

  let prompt = `A ${roomType} with a ${designType} style interior`;

  if (style) {
    prompt += `, featuring ${style} elements`;
  }

  if (mood) {
    prompt += `, with a ${mood} atmosphere`;
  }

  if (additionalReq) {
    prompt += ` ${additionalReq}`;
  }

  return prompt;
}
```

### テンプレートベースのプロンプト

```typescript
const PROMPT_TEMPLATES = {
  modern: "Modern {roomType} with clean lines, minimalist furniture, and neutral color palette",
  vintage: "Vintage {roomType} with antique furniture, warm lighting, and classic patterns",
  industrial: "Industrial {roomType} with exposed brick, metal accents, and urban aesthetic"
};

function buildPromptFromTemplate(
  template: keyof typeof PROMPT_TEMPLATES,
  roomType: string,
  additionalReq?: string
): string {
  let prompt = PROMPT_TEMPLATES[template].replace('{roomType}', roomType);

  if (additionalReq) {
    prompt += `. ${additionalReq}`;
  }

  return prompt;
}
```

### ネガティブプロンプト

```typescript
interface AdvancedPromptParams extends PromptParams {
  negativePrompt?: string[];
}

function buildAdvancedPrompt(params: AdvancedPromptParams): {
  prompt: string;
  negative_prompt: string;
} {
  const prompt = buildPrompt(params);

  const defaultNegativePrompt = [
    'blurry',
    'low quality',
    'distorted',
    'unrealistic'
  ];

  const negativePrompt = [
    ...defaultNegativePrompt,
    ...(params.negativePrompt || [])
  ].join(', ');

  return { prompt, negative_prompt: negativePrompt };
}
```

---

## 6. ローディング・UX管理

### ローディング状態管理

```typescript
'use client';

import { useState } from 'react';

export default function AIGenerationForm() {
  const [isLoading, setIsLoading] = useState(false);
  const [progress, setProgress] = useState(0);

  async function handleSubmit(formData: FormData) {
    setIsLoading(true);
    setProgress(0);

    try {
      // 1. 画像アップロード（25%）
      setProgress(25);
      const imageUrl = await uploadImage(formData.get('image'));

      // 2. AI生成（50%）
      setProgress(50);
      const result = await generateAI(imageUrl);

      // 3. 結果保存（75%）
      setProgress(75);
      const savedUrl = await saveResult(result);

      // 4. 完了（100%）
      setProgress(100);

    } catch (error) {
      console.error(error);
    } finally {
      setIsLoading(false);
    }
  }

  if (isLoading) {
    return (
      <div className="flex flex-col items-center gap-4">
        <div className="loader" />
        <p>生成中... {progress}%</p>
        <p className="text-sm text-gray-600">
          ⚠️ ページをリフレッシュしないでください
        </p>
      </div>
    );
  }

  return <form onSubmit={handleSubmit}>...</form>;
}
```

### プログレスバーコンポーネント

```typescript
interface ProgressBarProps {
  progress: number;
  steps: string[];
}

export function ProgressBar({ progress, steps }: ProgressBarProps) {
  const currentStepIndex = Math.floor((progress / 100) * steps.length);

  return (
    <div className="w-full space-y-2">
      <div className="w-full bg-gray-200 rounded-full h-2">
        <div
          className="bg-blue-600 h-2 rounded-full transition-all duration-300"
          style={{ width: `${progress}%` }}
        />
      </div>
      <p className="text-sm text-gray-700">
        {steps[currentStepIndex] || '完了'}
      </p>
    </div>
  );
}
```

### タイムアウト処理

```typescript
async function generateWithTimeout(
  generateFn: () => Promise<any>,
  timeoutMs: number = 60000
): Promise<any> {
  const timeoutPromise = new Promise((_, reject) =>
    setTimeout(() => reject(new Error('生成がタイムアウトしました')), timeoutMs)
  );

  return Promise.race([generateFn(), timeoutPromise]);
}
```

---

## 7. 結果表示パターン

### Before/Afterスライダー

```typescript
'use client';

import { useState } from 'react';
import Image from 'next/image';

interface BeforeAfterSliderProps {
  beforeImage: string;
  afterImage: string;
}

export function BeforeAfterSlider({ beforeImage, afterImage }: BeforeAfterSliderProps) {
  const [sliderPosition, setSliderPosition] = useState(50);

  return (
    <div className="relative w-full h-[500px] overflow-hidden">
      {/* Before画像（下層） */}
      <Image
        src={beforeImage}
        alt="Before"
        fill
        className="object-cover"
      />

      {/* After画像（上層・クリップ） */}
      <div
        className="absolute inset-0"
        style={{ clipPath: `inset(0 ${100 - sliderPosition}% 0 0)` }}
      >
        <Image
          src={afterImage}
          alt="After"
          fill
          className="object-cover"
        />
      </div>

      {/* スライダー */}
      <input
        type="range"
        min="0"
        max="100"
        value={sliderPosition}
        onChange={(e) => setSliderPosition(Number(e.target.value))}
        className="absolute top-1/2 left-0 w-full -translate-y-1/2 z-10"
      />
    </div>
  );
}
```

### モーダルダイアログでの結果表示

```typescript
'use client';

import { useEffect, useState } from 'react';
import { Dialog, DialogContent } from '@/components/ui/dialog';

interface ResultModalProps {
  resultUrl: string | null;
  onClose: () => void;
}

export function ResultModal({ resultUrl, onClose }: ResultModalProps) {
  const [isOpen, setIsOpen] = useState(false);

  useEffect(() => {
    if (resultUrl) {
      setIsOpen(true);
    }
  }, [resultUrl]);

  return (
    <Dialog open={isOpen} onOpenChange={setIsOpen}>
      <DialogContent className="max-w-4xl">
        <div className="space-y-4">
          <h2 className="text-2xl font-bold">生成完了</h2>
          {resultUrl && (
            <Image
              src={resultUrl}
              alt="Generated result"
              width={800}
              height={600}
              className="w-full rounded-lg"
            />
          )}
          <div className="flex gap-2">
            <button onClick={onClose}>閉じる</button>
            <a href={resultUrl || '#'} download>ダウンロード</a>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}
```

### グリッド表示（複数結果）

```typescript
interface ResultGridProps {
  results: Array<{
    id: string;
    imageUrl: string;
    prompt: string;
    createdAt: Date;
  }>;
}

export function ResultGrid({ results }: ResultGridProps) {
  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
      {results.map((result) => (
        <div key={result.id} className="border rounded-lg overflow-hidden">
          <Image
            src={result.imageUrl}
            alt={result.prompt}
            width={400}
            height={300}
            className="w-full h-48 object-cover"
          />
          <div className="p-4">
            <p className="text-sm text-gray-600">{result.prompt}</p>
            <p className="text-xs text-gray-400 mt-2">
              {result.createdAt.toLocaleDateString()}
            </p>
          </div>
        </div>
      ))}
    </div>
  );
}
```

---

## 8. 判断基準テーブル

### AI APIプロバイダ選定

| 要件 | 推奨プロバイダ | 理由 |
|------|--------------|------|
| 画像生成（汎用） | Replicate | モデル選択の柔軟性、従量課金 |
| 画像生成（高品質） | Stability AI | Stable Diffusion公式、高速 |
| 画像編集 | OpenAI DALL-E | 自然な編集、マスク対応 |
| テキスト生成 | OpenAI GPT-4 / Anthropic Claude | 高品質テキスト、長文対応 |
| 音声認識 | OpenAI Whisper | 多言語対応、高精度 |
| 動画生成 | Runway ML / Pika Labs | 動画特化、API提供 |

### ストレージプロバイダ選定

| 要件 | 推奨ストレージ | 理由 |
|------|--------------|------|
| 中小規模SaaS | Firebase Storage | 無料枠5GB/月、CDN付き |
| Vercelホスティング | Vercel Blob | Vercel統合、エッジ配信 |
| Supabase利用時 | Supabase Storage | DB統合、Row Level Security |
| エンタープライズ | AWS S3 + CloudFront | スケーラビリティ、機能豊富 |

### 画像処理戦略

| 状況 | 推奨戦略 | 実装方法 |
|------|---------|---------|
| AI APIのURL一時的 | Base64変換→再アップロード | 本ドキュメント4章参照 |
| AI APIのURL永続的 | URL直接保存 | DBにURL文字列保存 |
| CDN配信必須 | ストレージ+CDN | Firebase Storage / Vercel Blob |
| 画像編集機能 | クライアントサイド処理 | Canvas API / Fabric.js |

### ローディングUX

| 処理時間 | 推奨UI | 実装 |
|---------|--------|------|
| 〜3秒 | スピナー | シンプルなローディングアニメーション |
| 3〜10秒 | プログレスバー | 本ドキュメント6章参照 |
| 10秒〜 | ステップ表示+進捗率 | プログレスバー+テキスト説明 |
| 非同期処理 | Webhook通知 | 完了時にメール/プッシュ通知 |

### エラーハンドリング

| エラー種別 | 対応方法 | ユーザーへの表示 |
|-----------|---------|----------------|
| API Rate Limit | リトライ（指数バックオフ） | 「混雑中です。しばらくお待ちください」 |
| タイムアウト | タイムアウト時間延長 or Webhook化 | 「処理に時間がかかっています」 |
| 不適切なコンテンツ | プロンプトフィルタリング | 「入力内容を見直してください」 |
| 画像URL失効 | Base64変換→再アップロード | 自動処理（ユーザーには見せない） |

---

## まとめ

### チェックリスト

AI機能実装時の必須確認項目:

- [ ] API Keyはサーバーサイドのみで使用（環境変数管理）
- [ ] AI生成画像は永続ストレージに保存（Base64変換）
- [ ] ローディング状態を適切に管理（3秒以上ならプログレスバー）
- [ ] エラーハンドリングを実装（リトライ・タイムアウト）
- [ ] ユーザーへのフィードバックを明確に表示
- [ ] 結果表示UIを最適化（Before/Afterスライダー等）

### 参考リソース

- [Replicate Docs](https://replicate.com/docs)
- [OpenAI API Reference](https://platform.openai.com/docs/api-reference)
- [Firebase Storage Guide](https://firebase.google.com/docs/storage)
- [Vercel Blob Storage](https://vercel.com/docs/storage/vercel-blob)
