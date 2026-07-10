# サービス統合パターン

Node サービスからメール送信・タスクスケジューリング・外部生成 AI API を呼び出す実装パターン集。
プロンプト設計の深掘りは `ai:integrating-ai-web-apps` を参照。

---

## 1. メール送信（nodemailer）

### 概念

`nodemailer` は SMTP トランスポートを抽象化する Node 向けメールライブラリ。
自前の SMTP サーバーは不要で、既存のメールサービス（Gmail・SendGrid・Mailgun 等）を経由して送信する。

```
npm install nodemailer
```

### 汎用パターン

```
createTransport(config) → transporter
transporter.sendMail(mailOptions) → Promise<info>
```

#### transporter 設定

```js
import { createTransport } from "nodemailer";

const transporter = createTransport({
  service: "gmail",          // または host/port を直接指定
  auth: {
    user: process.env.MAIL_USER,
    pass: process.env.MAIL_APP_PASSWORD,  // アプリパスワード（平文パスワードを使わない）
  },
});
```

> ⚠️ 認証情報は必ず環境変数に保持し、コード・リポジトリには含めない。

#### メール送信の最小コード例

```js
export const sendMail = async (to, html, subject = "通知") => {
  const mailOptions = {
    from: process.env.MAIL_FROM,
    to,
    subject,
    html,
  };

  try {
    const info = await transporter.sendMail(mailOptions);
    console.log("送信完了:", info.response);
  } catch (err) {
    console.error("送信失敗:", err.message);
  }
};
```

### HTML テンプレートの分離

メール本文を生成する関数をテンプレートモジュールとして切り出すと再利用しやすい:

```js
// mailTemplates.js
const wrap = (content) => `
<html><body>${content}</body></html>
`;

export const welcomeMail = () =>
  wrap("<h1>ご登録ありがとうございます</h1>");

export const confirmMail = (verifyUrl) =>
  wrap(`<a href="${verifyUrl}"><h1>メールアドレスを確認する</h1></a>`);

export const campaignMail = (text, campaignKey, email, baseUrl) => {
  const pixelUrl = `${baseUrl}/campaign/${campaignKey}/user/${email}/image.png`;
  return wrap(`
    <h1>${text}</h1>
    <img src="${pixelUrl}" style="display:none" width="1" height="1" />
  `);
};
```

### Fastify との統合

Fastify ルートでフォーム受信 → メール送信をつなぐ:

```js
import "@fastify/formbody";   // application/x-www-form-urlencoded 対応
import { sendMail } from "./services/mailer.js";
import { welcomeMail } from "./mailTemplates.js";

app.post("/subscribe", async (request, reply) => {
  const { email } = request.body;

  try {
    await db.save(email);               // 保存（詳細は DATA-PERSISTENCE-PATTERNS.md）
    await sendMail(email, welcomeMail());
    reply.send({ message: "registered" });
  } catch (err) {
    reply.status(500).send({ error: err.message });
  }
});
```

---

## 2. メールトラッキング（検証・エンゲージメント計測）

### 概念

- **検証リンク**: メール内にリンクを埋め込み、クリック時にサーバーで `verified = true` に更新する。
- **トラッキングピクセル**: 1px 画像を非表示で埋め込み、メール開封時に画像 URL へ GET リクエストが飛ぶことを利用してエンゲージメントを記録する。

### 汎用パターン

```
メール送信時: 動的 URL（email をパラメータに含む）を埋め込む
  受信者がリンク/画像をロード → GET リクエスト → サーバーで DB 更新
```

### 最小コード例

```js
// 検証ルート
app.get("/verify/:email", async (request, reply) => {
  const { email } = request.params;

  try {
    const user = await db.findByEmail(email);
    if (user) {
      await db.update(email, { verified: true });
      reply.send({ message: "確認完了" });
      return;
    }
  } catch (err) {
    console.error(err.message);
  }
  reply.send({ message: "確認できませんでした" });
});

// トラッキングピクセルルート
app.get("/campaign/:key/user/:email/image.png", async (request, reply) => {
  const { key, email } = request.params;

  try {
    const user = await db.findByEmail(email);
    if (user) {
      await db.update(email, { lastCampaign: key });
      console.log(`${email} が ${key} を開封`);
    }
  } catch (err) {
    console.error(err.message);
  }
  reply.send({ ok: true });
});
```

### 落とし穴

- **ローカル開発では検証できない**: メールクライアントは `localhost` のリンクを開けない。本番 URL またはトンネリングツール（ngrok 等）でテストする。
- **プライバシー規制**: トラッキングピクセルは GDPR/各国プライバシー法の規制対象になり得る。ユーザーへの開示・同意取得が必要なケースがある。
- **メールクライアントの画像ブロック**: 多くのクライアントはデフォルトで画像をブロックするため、開封率の数値は過小評価される。

---

## 3. タスクスケジューラ（node-schedule）

### 概念

`node-schedule` は cron ライクな構文でタスクを定期実行するライブラリ。
メール配信・データ集計・キャッシュ更新など、定時処理が必要な場面で使う。

```
npm install node-schedule
```

### 汎用パターン

```
scheduleJob(timeOptions, callback)
  → timeOptions に一致したタイミングで callback を実行
```

| timeOptions 例 | 意味 |
|---------------|------|
| `{ second: 0 }` | 毎分 0 秒 |
| `{ hour: 9, minute: 0 }` | 毎日 9:00 |
| `{ dayOfWeek: 1, hour: 13 }` | 毎週月曜 13:00 |
| `"0 9 * * 1"` | cron 構文（同上） |

### 最小コード例

```js
// services/scheduler.js
import { scheduleJob } from "node-schedule";
import { sendMail } from "./mailer.js";
import { campaignMail } from "../mailTemplates.js";

export const startScheduler = (recipients) => {
  scheduleJob({ dayOfWeek: 1, hour: 9, minute: 0 }, async () => {
    console.log("スケジュールメール送信開始");
    for (const email of recipients) {
      await sendMail(
        email,
        campaignMail("週刊ニュース", "weekly-2024", email, process.env.BASE_URL)
      );
    }
  });
};
```

```js
// index.js
import { startScheduler } from "./services/scheduler.js";

const subscribers = await db.findVerifiedEmails();
startScheduler(subscribers);
```

### 落とし穴

- **プロセス再起動でジョブが消える**: `node-schedule` はインメモリ管理のため、プロセスが落ちるとスケジュールがリセットされる。本番環境では PM2 / systemd 等でプロセスを永続化するか、永続キュー（BullMQ 等）との組み合わせを検討する。
- **非同期コールバックのエラー処理**: `scheduleJob` のコールバックが async の場合、内部で try-catch しないと未処理の Promise rejection になる。
- **タイムゾーン**: デフォルトはサーバーのローカルタイム。`timeZone` オプションで明示的に指定する（例: `{ tz: "Asia/Tokyo" }`）。

---

## 4. 生成 AI API 統合（実装面）

### 概念

REST ベースの生成 AI API は、HTTP クライアントで `POST` リクエストを送り、
レスポンスからテキストを抽出するパターンが基本。Fastify サービスへの組み込みは
「ルートがプロンプトを受け取り → API 呼び出し → レスポンスを返す」3 ステップで完結する。

> プロンプト設計・モデル選択・コンテキスト管理の深掘りは `ai:integrating-ai-web-apps` を参照。

### 汎用パターン

```
環境変数で API キーを管理
  → axios / fetch で POST
  → リクエストボディ: { contents: [{ role, parts: [{ text }] }] }
  → レスポンス: candidates[0].content.parts[0].text を抽出
  → エラーはオプショナルチェーンでフォールバック
```

#### 必要なパッケージ

```
npm install axios dotenv
```

- `axios`: 充実したエラーオブジェクトを返し、リトライ拡張が容易
- `dotenv`: `.env` からの環境変数読み込み（Node 20.6 以降は `--env-file` フラグで代替可）

### 最小コード例

```js
// services/ai.js
import axios from "axios";

const API_URL = process.env.AI_API_URL;          // エンドポイント（.env で管理）
const API_KEY = process.env.AI_API_KEY;          // API キー

/**
 * テキストプロンプトを生成 AI API に送信し、テキスト回答を返す
 * @param {string} systemPrompt - AI の役割・制約を指定するシステムプロンプト
 * @param {string} userPrompt   - ユーザーからの入力
 * @returns {Promise<string>}
 */
export const generateText = async (systemPrompt, userPrompt) => {
  try {
    const { data } = await axios.post(
      `${API_URL}?key=${API_KEY}`,
      {
        contents: [
          { role: "user", parts: [{ text: systemPrompt }] },
          { role: "user", parts: [{ text: userPrompt }] },
        ],
      },
      { headers: { "Content-Type": "application/json" } }
    );

    return (
      data?.candidates?.[0]?.content?.parts?.[0]?.text ??
      "レスポンスなし"
    );
  } catch (err) {
    const detail = err.response?.data ?? err.message;
    console.error("AI API エラー:", detail);
    return `エラーが発生しました: ${JSON.stringify(detail)}`;
  }
};
```

### Fastify ルートとの統合

```js
// index.js
import { generateText } from "./services/ai.js";

const SYSTEM_PROMPT =
  "You are a helpful assistant specializing in Node.js development. " +
  "Provide concise and practical answers.";

app.post("/query", async (request, reply) => {
  const { prompt } = request.body;

  if (!prompt) {
    return reply.status(400).send({ error: "prompt は必須です" });
  }

  try {
    const response = await generateText(SYSTEM_PROMPT, prompt);
    reply.send({ response });
  } catch (err) {
    reply.status(500).send({ error: "AI API との通信に失敗しました" });
  }
});
```

### JSON 出力の強制と解析

AI API にJSONを返させる場合は、レスポンスにMarkdownのコードフェンスが混入することがある:

```js
const cleanJson = (raw) =>
  raw.replace(/```json|```/g, "").trim();

const parseAiJson = (raw) => {
  try {
    return JSON.parse(cleanJson(raw));
  } catch {
    console.error("JSON パース失敗:", raw);
    return null;
  }
};
```

プロンプトへの明示指示例:

```
"Respond only in valid JSON with keys: { answer: string, summary: string }"
```

### パーソナライズ（ユーザープロファイルとの組み合わせ）

DB に保存した学習プロファイルをコンテキストとして注入することで、
ユーザーごとにパーソナライズされたレスポンスを生成できる:

```js
const buildPrompt = (profile, userQuery) => `
You are an AI assistant. The user's profile: "${profile}".
Answer their query and return valid JSON:
{ "answer": "...", "updatedProfile": "..." }

User query: ${userQuery}
`;

// 応答後は updatedProfile を DB に書き戻す
await db.run(
  "UPDATE users SET profile = ? WHERE id = ?",
  [parsed.updatedProfile, userId]
);
```

### JWT 認証との組み合わせ

保護されたルートでのみ AI API を呼び出す:

```js
import jwt from "jsonwebtoken";

const verifyJWT = async (request, reply) => {
  const auth = request.headers.authorization;
  if (!auth) return reply.status(401).send({ error: "認証トークンが必要です" });

  const token = auth.split(" ")[1];
  try {
    request.user = jwt.verify(token, process.env.JWT_SECRET);
  } catch {
    return reply.status(401).send({ error: "無効または期限切れのトークンです" });
  }
};

app.post("/query", { preHandler: verifyJWT }, async (request, reply) => {
  // ... 認証済みユーザーのみ到達
});
```

### 落とし穴

- **API キーをコードに直書きしない**: `.env` に保持し、`.gitignore` で除外する。
- **レスポンス構造の変化**: AI API はモデル更新でレスポンスの形式が変わる場合がある。オプショナルチェーン（`?.`）と フォールバック値で防御的に実装する。
- **過剰な API 呼び出し**: 課金に直結する。レート制限・リトライ制御・キャッシュ（Redis 等）を組み合わせる。
- **Markdown フェンスの混入**: 構造化出力（JSON 等）を指示しても AI がコードブロックで囲む場合がある。`replace(/```json|```/g, "")` で除去してからパースする。
- **プロンプトインジェクション**: ユーザー入力を直接プロンプトに連結すると、悪意ある入力で挙動を操作される。ユーザー入力部分を明確に分離し、システムプロンプトを別フィールドに置く。

---

## 関連リファレンス

| リファレンス | 参照先 |
|------------|--------|
| メッセージキュー・非同期処理 | `MESSAGING-AND-QUEUES.md` |
| JWT 認証フロー | `AUTHENTICATION-FLOWS.md` |
| 外部データ取得（fetch・スクレイピング） | `EXTERNAL-DATA-INTEGRATION.md` |
| 生成 AI プロンプト設計・LLM アーキテクチャ | `ai:integrating-ai-web-apps` |
| サービス品質・テスト | `QUALITY-CHECKLIST.md` |
