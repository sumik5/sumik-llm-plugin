# テクニカルSEO: Core Web Vitals / クロール / 構造化データ / 国際化 / サイト移行

> **このファイルの範囲**: テクニカルSEOの全領域を扱う。Core Web Vitals（LCP / INP / CLS）の現行3指標と指標別改善手法、クロール・インデックス・レンダリング（SSR/SSG推奨・動的レンダリング非推奨）、構造化データ（Schema.org / JSON-LD）のリッチリザルト対象タイプと廃止事項、hreflang・canonical・リダイレクト、モバイルファースト・HTTPS・URL設計・内部リンク、ページネーション・重複コンテンツ・サイト移行、EC技術SEO（ファセット/フィルタ・在庫切れ）を網羅する。ランキング要因の全体像・E-E-A-T・検索意図は `FOUNDATIONS-RANKING-EEAT.md` を参照。

---

## 目次

- [Core Web Vitals（現行3指標）](#core-web-vitals現行3指標)
- [クロール・インデックス・レンダリング](#クロールインデックスレンダリング)
- [構造化データ / Schema.org](#構造化データ--schemaorg)
- [hreflang・国際化・正規化・リダイレクト](#hreflang国際化正規化リダイレクト)
- [モバイルファースト / HTTPS / URL設計 / 内部リンク](#モバイルファースト--https--url設計--内部リンク)
- [ページネーション / 重複コンテンツ / サイト移行](#ページネーション--重複コンテンツ--サイト移行)
- [EC技術SEO](#ec技術seo)
- [アクセス制御（.htaccess）](#アクセス制御htaccess)
- [廃止・縮小施策まとめ](#廃止縮小施策まとめ)
- [関連リファレンス](#関連リファレンス)

---

## Core Web Vitals（現行3指標）

凡例: 🟢=Google公式 / 🔵=業界コンセンサス・第三者分析

### 現行3指標と閾値

🟢 2024年3月、**INP（Interaction to Next Paint）がFID（First Input Delay）を正式に置換**。現行のCore Web Vitals（CWV）は **LCP / INP / CLS** の3指標。

> **鮮度注記**: FIDは2024年3月に廃止。古い資料でFIDを推奨している記述がある場合は、現行はINPへ置換されていることに留意。

| 指標 | 計測内容 | Good | Needs Improvement | Poor |
|------|---------|------|-------------------|------|
| **LCP**（Largest Contentful Paint） | 読み込み速度（最大コンテンツ要素の描画完了まで） | **≤ 2.5秒** | 2.5〜4.0秒 | > 4.0秒 |
| **INP**（Interaction to Next Paint） | 応答性（全インタラクションの遅延・FIDの後継） | **≤ 200ms** | 200〜500ms | > 500ms |
| **CLS**（Cumulative Layout Shift） | 視覚的安定性（予期せぬレイアウト移動） | **≤ 0.1** | 0.1〜0.25 | > 0.25 |

**合格判定**: 各指標について、訪問の**75パーセンタイル**（全ページ訪問の75%以上）が "Good" 閾値を満たすこと。

**INPとFIDの違い**: FIDは最初の操作のみ計測。INPは**全インタラクション**（クリック・タップ・キー入力）の遅延を計測するため、より厳格。INPは3フェーズ（Input Delay / Processing Time / Presentation Delay）で構成される。

出典: 🟢 https://developers.google.com/search/docs/appearance/core-web-vitals / https://web.dev/articles/defining-core-web-vitals-thresholds

### フィールドデータ vs ラボデータ

**ランキング判定はフィールドデータ（実ユーザーデータ）を使用**する。ラボデータはランキングに直接使われない。

| 種別 | ツール | 用途 |
|------|--------|------|
| **フィールドデータ（実ユーザー）** | Chrome User Experience Report（CrUX）・Search Console・PageSpeed Insights | 🟢 ランキング判定の一次ソース。過去28日間のローリングデータ |
| **ラボデータ（シミュレーション）** | PageSpeed Insights / Lighthouse / Chrome DevTools | 再現性が高く改善検証に有用。ランキングには直接使われない |

計測チェックリスト:
- [ ] Search Console の Core Web Vitals レポートでURLグループ別の合格状況を確認
- [ ] PageSpeed Insights でフィールド（CrUX）とラボ（Lighthouse）を併読
- [ ] 実環境計測には `web-vitals` JSライブラリ（フィールド計測）を導入
- [ ] モバイル/デスクトップを**別々に評価**（モバイルファーストインデックス前提）

### 指標別改善手法（チェックリスト）

**LCP（≤ 2.5秒を目標）**
- [ ] LCP要素（多くはヒーロー画像）を `fetchpriority="high"` でプリロード
- [ ] 画像を WebP / AVIF などモダンフォーマット化・適切にリサイズ
- [ ] レンダリングブロッキングのCSS/JSを削減（クリティカルCSSのインライン化）
- [ ] サーバー応答時間（TTFB）短縮・CDN活用
- [ ] 🔴 遅延読み込み（lazy loading）は**LCP要素には適用しない**（above-the-fold画像をlazyにしない）

**INP（≤ 200ms を目標）**
- [ ] 長いJSタスクを分割（`scheduler.yield()` / `setTimeout` でメインスレッドをyield）
- [ ] メインスレッドの負荷を軽減・不要なサードパーティスクリプトを削減
- [ ] イベントハンドラを軽量化、重い処理を Web Worker へ移譲
- [ ] DOMサイズを抑制し再計算コストを削減
- [ ] Input Delay / Processing Time / Presentation Delay の各フェーズを個別に計測・改善

**CLS（≤ 0.1 を目標）**
- [ ] 画像・動画・iframe・広告枠に明示的な `width`/`height`（またはアスペクト比）を指定
- [ ] フォントをプリロードし FOIT/FOUT を抑制（`font-display: optional` または `swap`）
- [ ] 動的に挿入されるコンテンツ用にスペースを予約（既存コンテンツを押し下げない）
- [ ] アニメーションは `transform`/`opacity` を使い、レイアウトを変えるプロパティ（top/left/width等）を避ける

---

## クロール・インデックス・レンダリング

### クロールバジェット

大規模サイト（数万URL以上）や頻繁に更新するサイトで主に問題化。小規模サイトでは通常気にする必要は薄い。

- [ ] URLインベントリを管理（重複・低価値URL・無限ファセットを抑制）
- [ ] CSSやJSリソースはCDN/別ホスト名に置き、本体サイトのクロールバジェットを本文ページへ配分
- [ ] サーバー応答を高速・安定化（5xx/タイムアウト多発はクロール頻度低下を招く）
- [ ] robots.txt で不要なパラメータURL・無限空間をブロック
- 注: JS主体サイトは静的HTMLより**約9倍**のクロール時間を要するとされる（🔵業界調査）

出典: 🟢 https://developers.google.com/crawling/docs/crawl-budget

### JavaScriptレンダリング（CSR / SSR / SSG / 動的レンダリング）

Googleの処理フロー: **クロール → レンダリング → インデックス** の3段階。レンダリングには「レンダリングバジェット」の制約がある。

**推奨レンダリング方式**:

| 方式 | 向いているケース |
|------|-----------------|
| **SSR（サーバーサイドレンダリング）** | ライブデータ・頻繁に更新するコンテンツ |
| **SSG（静的サイト生成）/ ISR（増分静的再生成）** | 安定したコンテンツ・高トラフィック |
| **ハイブリッド（SSR+SSG）** | 複雑なルート構成・複合要件 |

> **🔴 鮮度注記: 動的レンダリング（Dynamic Rendering）は非推奨**。Googleは長年ワークアラウンド扱いとし、関連ドキュメントの多くを削除。ボットとユーザーで配信内容が乖離しインデックス不整合を招くため、**長期解決策としては採用しない**。新規プロジェクトはSSR/静的レンダリングへ。既存の動的レンダリング構成は段階的に移行する。

- [ ] 重要コンテンツ・内部リンク・構造化データがレンダリング後のHTMLに含まれることを確認
- [ ] `Rich Results Test` / `URL検査ツール（Search Console）` で実際にGoogleが見るDOMを検証

出典: 🟢 https://developers.google.com/search/docs/crawling-indexing/javascript/dynamic-rendering / 🔵 https://searchengineland.com/google-no-longer-recommends-using-dynamic-rendering-for-google-search-387054

### インデックス制御

**noindex**: ページをインデックスから除外。

- 実装方法: `<meta name="robots" content="noindex">` またはHTTPヘッダ `X-Robots-Tag: noindex`
- 🔴 **noindexしたいページを robots.txt でブロックしてはならない**。ブロックされるとクローラが `noindex` を読めず、除外が機能しない

**canonical（rel=canonical）**: 重複/類似URL群の正規版を示す（ディレクティブではなく「示唆」）。

- [ ] 同一ページに対し複数手法で**異なる**canonicalを指定しない（例: サイトマップとrel=canonicalで別URLを示さない）
- [ ] 自己参照canonicalを基本とする（正規版を明示的に宣言）

**robots.txt**: クローラのアクセス制御が目的（過負荷防止）。インデックス制御の手段ではない。

- [ ] インデックスから外したいページは noindex を使い、robots.txt でブロックしない
- [ ] サイトマップの場所を `Sitemap:` ディレクティブで記載
- [ ] 公開前にSearch Consoleのrobots.txtテスターで検証

出典: 🟢 https://developers.google.com/search/docs/crawling-indexing/robots/intro / https://developers.google.com/search/docs/crawling-indexing/block-indexing

### XMLサイトマップ

- [ ] **正規・インデックス可能・200を返すクリーンなURLのみ**を列挙
- [ ] リダイレクト・noindex・重複・破損・低価値ユーティリティURLは除外
- [ ] `<lastmod>` は**実際のコンテンツ更新を反映する時のみ**設定（虚偽の鮮度信号はサイトマップ全体の信頼性低下を招く）
- [ ] 1ファイル上限: **50,000 URL / 50MB（非圧縮）**。超える場合はサイトマップインデックスで分割
- [ ] 大規模変更後はSearch Consoleで再送信
- 🔴 **robots.txt でブロックしたURLをサイトマップに載せるのは典型的な矛盾**（クロールバジェット浪費）

---

## 構造化データ / Schema.org

**実装形式**: **JSON-LD が標準・推奨**（Microdata / RDFa も有効だが新規はJSON-LD）。

### 現在もリッチリザルト対象の主要タイプ

- **Product**（+ Review / AggregateRating / Offer）
- **Article**（NewsArticle / BlogPosting 含む）
- **Recipe**
- **Video**（VideoObject）
- **Organization**
- **LocalBusiness**
- **BreadcrumbList**（パンくず）
- そのほか Event / JobPosting / Course / Dataset など多数（最新の対応タイプ一覧はGoogle Search Central を確認）

### 【廃止・縮小】FAQ・HowTo のリッチリザルト

> **🔴 鮮度注記**: 古い資料ではFAQPage/HowToスキーマが検索結果でのリッチリザルト表示のために推奨されている場合がある。現行の状況は以下のとおり。

| 種別 | 状態 | 時期 |
|------|------|------|
| **HowTo リッチリザルト** | **廃止**（デスクトップ・モバイルともに非表示） | 2023年9月13日 |
| **FAQ リッチリザルト（一般サイト）** | **縮小→完全廃止**（権威ある政府・医療系のみに限定後、全廃） | 2023年8月縮小→**2026年5月7日完全終了** |

**重要な区別**:

- **FAQPage Schema.orgタイプは有効**であり、Googleはマークアップの解析自体は継続している
- ただし**検索結果上での視覚的なリッチリザルト効果はない**（2026年5月7日以降）
- Search ConsoleのFAQ関連レポート/フィルタは2026年6月に削除、API対応は2026年8月削除予定
- **既存のFAQPageマークアップを慌てて削除する必要はない**（害はない。コンテンツ自体の価値・AI検索向け構造化データとしては依然有用）

HowTo/FAQ以外の構造化データ施策は引き続き有効であり、AI検索（AI Overviews / GEO）での引用獲得にも構造化データが寄与するとされる（詳細は `AI-SEARCH-GEO.md`）。

出典: 🟢 https://developers.google.com/search/blog/2023/08/howto-faq-changes / 🔵 https://www.searchenginejournal.com/google-drops-faq-rich-results-from-search/574429/

### 実装チェックリスト

- [ ] JSON-LDで記述し、`<head>` または `<body>` に配置
- [ ] マークアップ内容はページの**可視コンテンツと一致**させる（隠しコンテンツのマークアップ禁止）
- [ ] Rich Results Test / Schema Markup Validator で検証
- [ ] Search Consoleの拡張レポートでエラー・警告を定期監視
- [ ] AI/構造化データ目的でのFAQPage実装は引き続き有効（リッチリザルト目的の投資価値は低下）
- [ ] 🔴 JSで注入する構造化データはAIクローラが取りこぼすことがある → サーバーサイドレンダリング/静的HTMLで実装

---

## hreflang・国際化・正規化・リダイレクト

### hreflang（国際化SEO）

言語・地域別バージョンを検索エンジンに伝えるHTML属性。

- [ ] 言語コードは **ISO 639-1**、地域コードは **ISO 3166-1 Alpha-2** に厳密準拠
  - 例: 英国は `en-uk` は**無効**、正しくは **`en-gb`**（誤りはhreflangグループ全体を無効化）
- [ ] **双方向（return link）必須**: AがBを指すなら、BもAを指す
- [ ] **`x-default`** でデフォルト/言語選択ページを指定
- [ ] hreflangは**最終的なURL（リダイレクトしないURL）**を指す（リダイレクト先ではなく着地URL自体を指定）
- [ ] 実装方法: HTMLヘッダ / HTTPヘッダ / XMLサイトマップ のいずれか（大規模サイトはサイトマップが管理容易）

> 🔵 国際サイトの65%以上がhreflang実装エラーを抱えるとの調査。最多は「return link欠如」「言語コード誤り」「canonicalとの競合」。

### 正規化（canonical）と hreflang の併用

- [ ] **各言語バージョンは自分自身をcanonicalにする**（単一マスターURLを指してはならない）
- [ ] hreflangセットを全バリアント間で一致させる
- [ ] hreflangとcanonicalが矛盾しないよう整合を確認

出典: 🟢 https://developers.google.com/search/docs/crawling-indexing/consolidate-duplicate-urls

### リダイレクト（301 / 302 / 308 / 307）

| コード | 意味 | 用途 |
|--------|------|------|
| **301** | 恒久リダイレクト | ランキング信号の大半を移転。サイト移転・URL恒久変更 |
| **302** | 一時リダイレクト | 一時的な移動（恒久移転に302を使うと信号移転が不安定） |
| **308** | 恒久リダイレクト（メソッド保持） | POSTリクエストを保持した恒久リダイレクト |
| **307** | 一時リダイレクト（メソッド保持） | POSTリクエストを保持した一時リダイレクト |

- [ ] リダイレクトチェーンを避ける（Googlebotは最大10ホップ追従するが**3ホップ以内**が望ましい）
- [ ] サーバーサイドリダイレクト（.htaccess / Nginx / アプリ層）を優先。JSリダイレクトは可能だが低速・非推奨
- 301 vs canonical: 旧URLを残さず統合するなら301、複数URLを残しつつ正規版を示すならcanonical

---

## モバイルファースト / HTTPS / URL設計 / 内部リンク

### モバイルファーストインデックス

🟢 **2024年7月5日に全サイトで全面移行完了**。100%のサイトがモバイル版を主たるインデックス入力として使用。

> 🔴 モバイル版にデスクトップ未満のコンテンツ・内部リンク・構造化データしかない場合、ランキングはモバイル版基準で劣化する（デスクトップ専用最適化はGoogleに見えない）。

**推奨構成**: **レスポンシブデザイン**（同一URL・同一HTML、CSSでレイアウト切替）がGoogle推奨。

| 構成 | 特徴 |
|------|------|
| レスポンシブデザイン | 同一URL・同一HTML。Google推奨 |
| 動的配信 | 同一URL・デバイス別HTML。可（Vary: User-Agent ヘッダを追加） |
| 別URL（m-dot） | `rel=canonical` / `rel=alternate` の関連付けが必須。管理が複雑 |

チェックリスト:
- [ ] モバイルとデスクトップで本文・内部リンク・構造化データ・メタデータ（title/description/見出し）を等価に保つ
- [ ] モバイルでの可読性（フォントサイズ・タップターゲット・ビューポート設定）を確認

出典: 🟢 https://developers.google.com/search/docs/crawling-indexing/mobile/mobile-sites-mobile-first-indexing / 🔵 https://searchengineland.com/mobile-first-indexing-everything-you-need-to-know-450286

### HTTPS

- [ ] サイト全体をHTTPS化（軽微なランキング要因かつユーザー信頼の前提）
- [ ] 混在コンテンツ（mixed content）を排除し、HTTPからHTTPSへ301リダイレクト
- [ ] HSTS設定を検討（HTTPS強制の追加保護）

### URL設計

- [ ] フラットな階層（重要ページはトップから数クリック以内、目安**3クリック以内**）
- [ ] URLは短く・意味のある語・**小文字**・**ハイフン区切り**（アンダースコアは非推奨）
- [ ] 不要なパラメータ・セッションID・大文字小文字違いによる重複URLを抑制
- [ ] 論理的なディレクトリ構造でトピッククラスターを形成

### 内部リンク（技術面）

- [ ] 重要な内部リンク（ナビ・関連コンテンツ・フッタ）を**モバイル版にも全て**含める
- [ ] HTMLの `<a href>` でリンク（JSのみで生成されるリンクはクロールされにくい）
- [ ] 説明的なアンカーテキストを使用（「こちら」「詳細」等の無意味なテキストを避ける）
- [ ] 重要ページにリンクエクイティを集約（孤立ページを作らない）

---

## ページネーション / 重複コンテンツ / サイト移行

### ページネーション

> **【廃止】rel=prev / rel=next**: 2019年3月、Googleは長期間これを使っていなかったと公表。インデックス信号としては冗長。ただし既存実装を**急いで削除する必要はない**（害はなく、サイト移行時にGoogleが参照する場合もあるとの報告がある）。

**正しいcanonical運用**:

| ケース | 推奨設定 |
|--------|---------|
| View All ページが存在する | 各ページネーションページのcanonical → View All / View All自身 → 自己参照canonical |
| View All がない | **各ページネーションページは自己参照canonical**（page2がpage1を指す設定は誤り） |

- 🔴 **ページネーションをrobots.txtでブロックしない**（深層ページ・商品・ロングテールが発見不能になる）
- [ ] ページネーションは実際の `<a href>` リンクで辿れるようにする（クローラはリンクを辿る）

出典: 🔵 https://searchengineland.com/pagination-seo-what-you-need-to-know-453707 / https://ahrefs.com/blog/rel-prev-next-pagination/

### 重複コンテンツ

- [ ] canonicalで正規版を明示
- [ ] パラメータ違い・印刷用・トラッキング付与URLの重複を統合
- [ ] 同一/酷似コンテンツの大量生成を避ける（Scaled content abuse にも関連）
- [ ] サイトマップには正規URLのみ収録

### サイト移行（ドメイン変更・URL構造変更・HTTPS化）

計画的に実施しないと大幅なランキング低下を招く。

- [ ] **旧URL → 新URLの1対1の301マッピング**を作成（構造変更時は必須）
- [ ] サーバーサイド永続リダイレクト（301/308）を使用、チェーンは3〜5ホップ以内
- [ ] Search Consoleの **アドレス変更ツール（Change of Address）** で意図的移転を通知（完全処理に最大180日）
- [ ] 新サイトマップをSearch Consoleで再送信
- [ ] hreflang・canonical・内部リンクを新URLに合わせて更新（リダイレクト先ではなく新URL自体を指す）
- [ ] 移行後はインデックス/カバレッジレポートで 404・ソフト404・「クロール済み—未インデックス」を監視
- [ ] 旧・新両プロパティをSearch Consoleに登録し、トラフィック/インデックス推移を追跡

出典: 🟢 https://developers.google.com/search/docs/crawling-indexing/site-move-with-url-changes

---

## EC技術SEO

ECサイト固有の技術課題。商品コンテンツの最適化・ローカルSEOは `CONTENT-KEYWORDS.md` も参照。

### ファセット・フィルタ（絞り込み）の技術制御

絞り込みページ（例: カラー・サイズ・価格帯）は大量の重複URLを生成しクロールバジェットを圧迫する。

- [ ] インデックス不要なファセットURLは `noindex` または robots.txt でブロック（ただし有意なロングテールは例外扱い）
- [ ] URL パラメータの構造を統一し、Search Consoleのパラメータ設定で整理
- [ ] canonical を適切に設定（フィルタ適用ページ → 対応する正規ページ）
- [ ] 重要なカテゴリ/フィルタの組み合わせはSEO対象としてインデックス可能なURLを設計

### 在庫切れ商品ページの扱い

- [ ] **一時的な在庫切れ**: ページを維持（inStock=false / availability=OutOfStock をSchema.orgに反映）。301リダイレクトしない
- [ ] **廃番商品（復活予定なし）**: 301で関連カテゴリ/類似商品ページへリダイレクト
- [ ] **季節商品**: オフシーズンはnoindexまたは維持を選択し、翌シーズンにクロールさせる

### Schema.org（Product・Review）

- [ ] Product スキーマに `name` / `description` / `image` / `sku` / `brand` を含める
- [ ] `AggregateRating` で平均評価・レビュー数を構造化データ化（リッチリザルト対象）
- [ ] `Offer` で価格・在庫状況・通貨を正確にマークアップ（Search Consoleで検証）

---

## アクセス制御（.htaccess）

特定IPや地域からのアクセス制限が必要な場合（開発環境の誤公開防止・スパムBOT対策等）。

- [ ] Googlebot（クローラ）をブロックしないよう注意。不用意な制御はインデックスを妨げる
- [ ] IPブロックはサーバーサイド（.htaccess / Nginx / CDN のアクセス制御）で実装
- [ ] ブロック後は Search Console で「クロールエラー」が増加していないか確認
- [ ] 開発環境は `noindex` ヘッダまたはrobots.txtでGooglebotをブロックし、誤インデックスを防止

---

## 廃止・縮小施策まとめ

| 施策 | 状態 | 時期 |
|------|------|------|
| **FID**（First Input Delay） | **廃止**（INPが置換） | 2024年3月 |
| **動的レンダリング**（Dynamic Rendering） | **非推奨**（ワークアラウンド扱い・ドキュメント大幅削除） | 〜2025 |
| **HowTo リッチリザルト** | **廃止** | 2023年9月 |
| **FAQ リッチリザルト** | **縮小（政府/医療限定）→完全廃止**（FAQPageタイプ自体は有効） | 2023年8月縮小→2026年5月7日完全終了 |
| **rel=prev / rel=next**（インデックス信号） | **廃止（不使用）** | 2019年3月公表 |

---

## 関連リファレンス

| 参照先 | 用途 |
|--------|------|
| `FOUNDATIONS-RANKING-EEAT.md`（本スキル内） | ランキング要因全体像・E-E-A-T・検索意図・トピッククラスター |
| `CONTENT-KEYWORDS.md`（本スキル内） | キーワードリサーチ・オンページ最適化・EC商品ページ・ローカルSEO |
| `AI-SEARCH-GEO.md`（本スキル内） | AI Overviews / GEO / AEO / LLMO / llms.txt と構造化データのAI引用効果 |
| `MEASUREMENT.md`（本スキル内） | GA4/GSC を使ったCWV監視・インデックスカバレッジ監視の実装 |
| `creating-diagrams`（studio スキル） | サイトアーキテクチャ図・リダイレクトマップの作図 |
