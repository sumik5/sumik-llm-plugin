# 外部データ統合パターン

Node サービスが外部の HTTP リソース・フィード・Web ページからデータを取得・変換するための実装パターン集。

---

## 1. ネイティブ `fetch` API

### 概念

Node v18 以降はブラウザと同じ `Fetch API` が標準で利用可能（それ以前は `node-fetch` パッケージが必要）。
`fetch` は `Promise` ベースで、`async/await` と自然に組み合わせられる。

### 汎用パターン

```
fetch(url, options?)
  → Response { ok, status, headers, text(), json(), arrayBuffer() }
```

| レスポンス変換 | 用途 |
|--------------|------|
| `response.text()` | HTML / XML / プレーンテキスト |
| `response.json()` | JSON API |
| `response.arrayBuffer()` | バイナリ（画像・PDF） |

### 最小コード例

```js
// ESM / top-level await（Node 18+・"type": "module" 必須）
const url = "https://api.example.com/data";

try {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}`);
  }
  const data = await response.json();
  console.log(data);
} catch (err) {
  console.error("取得失敗:", err.message);
}
```

POST リクエストの場合:

```js
const response = await fetch(url, {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({ key: "value" }),
});
```

### 落とし穴

- **`response.ok` チェック漏れ**: 4xx/5xx でもエラーが throw されないため、`if (!response.ok)` による明示的な検証が必須。
- **ボディの二重読み取り**: `response.json()` と `response.text()` は一方しか呼べない（ストリームは一度だけ消費できる）。
- **タイムアウト制御**: `fetch` 自体にタイムアウト引数がない。`AbortController` + `AbortSignal.timeout(ms)` を使う。

```js
const ac = new AbortController();
const timer = setTimeout(() => ac.abort(), 5000);
try {
  const res = await fetch(url, { signal: ac.signal });
  // ...
} finally {
  clearTimeout(timer);
}
```

---

## 2. フィード取得と集約

### 概念

RSS フィードは XML 形式で配信される構造化コンテンツ。`<channel>` → `<item>` の階層で、
タイトル・リンク・公開日などが含まれる。複数フィードを並列取得して統合するのが一般的なパターン。

### 汎用パターン

```
フィード URL リスト
  → rss-parser でパース（XML を JS オブジェクトに変換）
  → Promise.all で並列取得
  → aggregate 関数でフィルタリング・正規化
  → 統合結果を返す
```

`rss-parser` は XML の fetch とパースを一括担当する npm パッケージ。

```
npm install rss-parser
```

### 最小コード例

```js
import Parser from "rss-parser";

const parser = new Parser();

// 単一フィードのパース
const feed = await parser.parseURL("https://example.com/feed/rss");
// feed.title, feed.items[].title, feed.items[].link などが利用可能

// 複数フィードを並列取得して集約
const urls = [
  "https://source-a.example.com/feed",
  "https://source-b.example.com/feed",
];

const responses = await Promise.all(urls.map((u) => parser.parseURL(u)));

const aggregate = (responses, keyword) => {
  const results = [];
  for (const { items } of responses) {
    for (const { title, link, pubDate } of items) {
      if (title.toLowerCase().includes(keyword.toLowerCase())) {
        results.push({ title, link, pubDate });
      }
    }
  }
  return results;
};

const filtered = aggregate(responses, "node");
console.table(filtered);
```

### リアルタイム更新

定期ポーリングには `setInterval` を使う:

```js
const INTERVAL_MS = 60_000; // 1分ごと
setInterval(async () => {
  const responses = await Promise.all(urls.map((u) => parser.parseURL(u)));
  // 集約・表示...
}, INTERVAL_MS);
```

**Fastify ルートへの統合**: 取得処理をサービス関数として切り出し、GET ルートのハンドラから呼び出す。

```js
app.get("/feeds", async (_req, reply) => {
  const items = await fetchAggregatedFeeds(urls, "keyword");
  reply.send(items);
});
```

### 落とし穴

- **RSS URL の変更・廃止**: フィードは予告なく変わる。定期的に疎通確認を行う。
- **`Promise.all` の失敗伝播**: いずれか 1 URL が失敗すると全体が reject される。個別エラーを吸収したい場合は `Promise.allSettled` を使い、失敗分を除外する。

```js
const settled = await Promise.allSettled(urls.map((u) => parser.parseURL(u)));
const succeeded = settled
  .filter((r) => r.status === "fulfilled")
  .map((r) => r.value);
```

---

## 3. Web スクレイピング

### 概念

HTML を取得し、DOM 要素を選択してデータを抽出する。
アプローチは 2 系統:

| 手法 | パッケージ | 適合ケース |
|------|----------|-----------|
| 静的 HTML パース | `cheerio` | 静的ページ・SSR ページ（JS 不要） |
| ヘッドレスブラウザ | `puppeteer` | SPA・遅延ロード・認証付きページ |

### 3-1. cheerio（jQuery スタイルの静的パーサ）

```
npm install cheerio
```

```
fetch(url) → response.text() → load(html) → $("selector") → テキスト/属性を抽出
```

#### 最小コード例

```js
import { load } from "cheerio";

const response = await fetch("https://example.com/articles");
const html = await response.text();

const $ = load(html);

const articles = [];
$("article").each((_i, el) => {
  const title = $(el).find("h2").text().trim();
  const url   = $(el).find("a").attr("href");
  if (title && url) articles.push({ title, url });
});

console.table(articles);
```

- `$("selector")` は CSS セレクタ構文をそのまま使用できる
- `.text()` でテキスト内容、`.attr("name")` で属性値を取得

### 3-2. puppeteer（ヘッドレス Chromium）

```
npm install puppeteer
# Chromium のインストール（バージョン 22 以降は手動）
npx puppeteer browsers install chrome
# または package.json script: "install-browser": "puppeteer browsers install chrome"
```

```
puppeteer.launch()
  → browser.newPage()
  → page.goto(url, { waitUntil: "networkidle2" })
  → page.$$(selector)（= querySelectorAll）
  → el.$eval(selector, fn) でテキスト/属性を抽出
  → browser.close()
```

#### 最小コード例

```js
import puppeteer from "puppeteer";

const URL = "https://example.com/articles";

const browser = await puppeteer.launch();          // headless: true がデフォルト
const page    = await browser.newPage();

await page.setUserAgent(
  "Mozilla/5.0 (compatible; MyBot/1.0)"
);
await page.goto(URL, { waitUntil: "networkidle2" });

// JS レンダリング完了まで余裕を持つ
await new Promise((r) => setTimeout(r, 2000));

const articles = await page.$$("article");
for (const el of articles) {
  const title = await el.$eval("h2", (e) => e.textContent.trim()).catch(() => null);
  const url   = await el.$eval("a",  (e) => e.href).catch(() => null);
  if (title && url) console.log(title, url);
}

await browser.close();
```

#### Fastify API としての提供

スクレイピング結果を Fastify ルートから返す:

```js
app.get("/api/articles", async (_req, reply) => {
  const results = await scrapeArticles();   // 上記ロジックをラップした関数
  reply.send(results);
});
```

### 落とし穴

- **User-Agent の必要性**: デフォルトの Headless User-Agent はブロック対象になることがある。実ブラウザに近い文字列を設定する。
- **CSS セレクタのフラジリティ**: 対象サイトの HTML 構造が変わるとセレクタが機能しなくなる。メンテナンス頻度を考慮して適用範囲を限定する。
- **`$eval` の失敗ハンドリング**: 要素が存在しない場合に例外が飛ぶ。`.catch(() => null)` で無害化する。
- **Puppeteer の起動コスト**: フル Chromium を起動するため時間がかかる。頻繁な呼び出しにはインスタンスをプロセスライフサイクルで共有する。
- **法的・倫理的考慮**: スクレイピング対象サイトの利用規約・robots.txt を確認すること。

---

## 4. 文字列処理と感情分析

### 概念

NLP（自然言語処理）パイプラインの基本ステップ:

```
入力テキスト
  1. スペル補正（spelling correction）
  2. トークン化（tokenization）
  3. ステミング（stemming）・ストップワード除去
  4. 感情スコア（sentiment score）算出
```

`natural` パッケージは Node 向けの NLP ツールキットで、トークン化・ステミング・感情分析を一括提供。

```
npm install natural spellchecker stopword
```

### 汎用パターン

```
correctSpelling(text)
  → tokenize(correctedText)
  → SentimentAnalyzer.getSentiment(tokens) → score
```

スコアの解釈:
- 正値 → ポジティブ傾向
- 負値 → ネガティブ傾向
- 0 → 中立

### 最小コード例

```js
import SpellChecker from "spellchecker";
import natural from "natural";

// 1. スペル補正
const correctSpelling = (input) => {
  const words = input.split(" ");
  return words
    .map((word) => {
      if (SpellChecker.isMisspelled(word)) {
        const suggestions = SpellChecker.getCorrectionsForMisspelling(word);
        return suggestions[0] ?? word; // 最も確度の高い候補
      }
      return word;
    })
    .join(" ");
};

// 2. トークン化
const tokenizer = new natural.WordTokenizer();
const tokenize  = (text) => tokenizer.tokenize(text);

// 3. 感情分析（PorterStemmer + AFINN 語彙セット）
const { SentimentAnalyzer, PorterStemmer } = natural;
const analyzer = new SentimentAnalyzer("English", PorterStemmer, "afinn");

const analyzeText = (input) => {
  const corrected = correctSpelling(input);
  const tokens    = tokenize(corrected);
  const score     = analyzer.getSentiment(tokens);
  return { corrected, tokens, score };
};

const result = analyzeText("I am feling grat today!");
console.log(result);
// { corrected: "I am feeling great today!", tokens: [...], score: 1.25 }
```

### CLI インタラクティブ版（`prompt` パッケージ）

```js
import prompt from "prompt";

prompt.start({});
prompt.message = "";

(async () => {
  try {
    const { input } = await prompt.get([
      { name: "input", description: "テキストを入力:" },
    ]);
    const { score } = analyzeText(input);
    console.log(`感情スコア: ${score}`);
  } catch (e) {
    console.error(e.message);
  }
})();
```

### 落とし穴

- **ストップワードの扱い**: 「not」「never」のような否定語は感情スコアに重要な意味を持つため、盲目的に除去しない。
- **スペルチェックの限界**: 略語・固有名詞・専門用語を誤変換する。`isMisspelled` で true になっても候補が空の場合はオリジナルを保持。
- **言語依存**: `SentimentAnalyzer` は English 専用。日本語テキストには別ライブラリ（`kuromoji` 等）が必要。
- **感情スコアの絶対値依存**: スコアはトークン数で正規化されるため文長による比較は可能だが、ドメイン固有の語彙には対応しない。カスタム辞書の追加を検討する。

---

## 関連リファレンス

| リファレンス | 参照先 |
|------------|--------|
| REST API 設計・CRUD 実装 | `REST-API-DESIGN.md` |
| Fastify ルーティング・プラグイン | `FASTIFY-FUNDAMENTALS.md` |
| メール送信・生成 AI API 統合 | `SERVICE-INTEGRATIONS.md` |
| サービスの品質・テスト | `QUALITY-CHECKLIST.md` |
