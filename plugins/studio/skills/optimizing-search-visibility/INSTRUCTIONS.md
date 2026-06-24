# 検索可視性最適化（optimizing-search-visibility）

> 古典SEO・生成AI活用・AI検索最適化の3層を統合したリファレンス。各ドメインの詳細は `references/` 配下の7本を参照。このファイルは全体ナビゲーション・核心原則・用語集・鮮度注記の集約地点。

---

## このスキルの守備範囲

検索可視性最適化は、現在3層の積み重ねで成り立っている。

```
┌─────────────────────────────────────────────────────────┐
│  Layer 3: AI検索最適化（GEO / AEO / LLMO）               │
│  AI Overviews・AI Mode・ChatGPT search に引用される施策   │
├─────────────────────────────────────────────────────────┤
│  Layer 2: 生成AI活用（SEO業務の効率化・スケール化）        │
│  プロンプト設計・カスタムGPT・RAG・AIエージェント自動化     │
├─────────────────────────────────────────────────────────┤
│  Layer 1: 古典SEO（普遍の基盤）                           │
│  ランキング要因・E-E-A-T・検索意図・テクニカル・コンテンツ  │
└─────────────────────────────────────────────────────────┘
```

Layer 3 を追いかけても Layer 1 が崩れていれば効果は出ない。実務では Layer 1 の監査・修正を先行させる。

---

## 参照ルーティング表

「何をしたいか」から直接参照先へ飛ぶための早見表。

| やりたいこと | 参照先ファイル | 主な見出し |
|---|---|---|
| Googleアルゴリズム・アップデート動向を把握する | [`FOUNDATIONS-RANKING-EEAT.md`](references/FOUNDATIONS-RANKING-EEAT.md) | Googleアルゴリズムの全体像 / アップデート年表（2024–2026） |
| E-E-A-T を高める施策を設計する | [`FOUNDATIONS-RANKING-EEAT.md`](references/FOUNDATIONS-RANKING-EEAT.md) | E-E-A-T / YMYL領域 / 施策チェックリスト |
| 検索意図を分析してコンテンツ設計する | [`FOUNDATIONS-RANKING-EEAT.md`](references/FOUNDATIONS-RANKING-EEAT.md) | 検索意図（Search Intent）/ SERP分析 |
| トピッククラスター・内部リンクを構築する | [`FOUNDATIONS-RANKING-EEAT.md`](references/FOUNDATIONS-RANKING-EEAT.md) | トピッククラスター / トピカルオーソリティ |
| Core Web Vitals（LCP/INP/CLS）を改善する | [`TECHNICAL-SEO.md`](references/TECHNICAL-SEO.md) | Core Web Vitals（現行3指標）/ 指標別改善手法 |
| クロール・インデックス・レンダリングを診断する | [`TECHNICAL-SEO.md`](references/TECHNICAL-SEO.md) | クロール・インデックス・レンダリング |
| 構造化データ（JSON-LD）を実装・審査する | [`TECHNICAL-SEO.md`](references/TECHNICAL-SEO.md) | 構造化データ / Schema.org / 廃止・縮小施策まとめ |
| hreflang・国際化・リダイレクトを設計する | [`TECHNICAL-SEO.md`](references/TECHNICAL-SEO.md) | hreflang・国際化・正規化・リダイレクト |
| サイト移行・EC技術SEOを実施する | [`TECHNICAL-SEO.md`](references/TECHNICAL-SEO.md) | ページネーション / サイト移行 / EC技術SEO |
| キーワードリサーチ・意図グルーピングをする | [`CONTENT-KEYWORDS.md`](references/CONTENT-KEYWORDS.md) | キーワードリサーチ / 検索意図グルーピング |
| タイトル・メタ・見出し・URLを最適化する | [`CONTENT-KEYWORDS.md`](references/CONTENT-KEYWORDS.md) | オンページ最適化 |
| コンテンツ網羅性・品質を向上させる | [`CONTENT-KEYWORDS.md`](references/CONTENT-KEYWORDS.md) | コンテンツ網羅性と品質 |
| ホワイトハットなリンクビルディングをする | [`CONTENT-KEYWORDS.md`](references/CONTENT-KEYWORDS.md) | リンクビルディング |
| ローカルSEO・GBP最適化をする | [`CONTENT-KEYWORDS.md`](references/CONTENT-KEYWORDS.md) | ローカルSEO |
| 生成AIでSEO業務を効率化・自動化する | [`GENAI-WORKFLOWS.md`](references/GENAI-WORKFLOWS.md) | プロンプトエンジニアリング / コンテンツ制作支援パターン |
| カスタムGPT・RAG・AIエージェントを構築する | [`GENAI-WORKFLOWS.md`](references/GENAI-WORKFLOWS.md) | スケール化・自動化 |
| AI Overviews / AI Mode の仕組みを理解する | [`AI-SEARCH-GEO.md`](references/AI-SEARCH-GEO.md) | AI検索の現状 |
| GEO・AEO・LLMO の施策を設計する | [`AI-SEARCH-GEO.md`](references/AI-SEARCH-GEO.md) | GEO（Generative Engine Optimization）/ AEO / LLMO |
| `llms.txt` の設置要否を判断する | [`AI-SEARCH-GEO.md`](references/AI-SEARCH-GEO.md) | llms.txt（採用状況・有効性の中立評価） |
| AI可視性を自己採点する / AIO用プロンプトを使う | [`AI-VISIBILITY-PLAYBOOK.md`](references/AI-VISIBILITY-PLAYBOOK.md) | AI可視性 自己診断ワークシート / AIO実行チェックリスト / AIOプロンプト・ライブラリ |
| SEO KPI・ROI を設計する | [`MEASUREMENT.md`](references/MEASUREMENT.md) | SEO KPI設計 / ROI算出 |
| GA4・GSC・ランクトラッキングを活用する | [`MEASUREMENT.md`](references/MEASUREMENT.md) | GA4 / Google Search Console / ランクトラッキング |
| ゼロクリック時代の計測設計をする | [`MEASUREMENT.md`](references/MEASUREMENT.md) | AI検索流入の計測 / ゼロクリック計測の限界 |
| AI生成コンテンツのリスクとガバナンスを整備する | [`RISK-GOVERNANCE.md`](references/RISK-GOVERNANCE.md) | Googleポリシー / 主要リスクと対策 |
| Scaled content abuse / ペナルティ対応をする | [`RISK-GOVERNANCE.md`](references/RISK-GOVERNANCE.md) | スパムポリシー / ペナルティ・順位喪失への対応 |

---

## SEO の核心原則（時代不変の軸）

アルゴリズムが変わっても揺るがない4つの軸。

### 1. 検索意図を充足する

ユーザーが「なぜその言葉で検索したか」を満たすコンテンツだけがランキングに残る。意図の4分類（情報収集型 / 案内型 / 取引型 / 商業調査型）を特定し、SERPに現れる形式（記事・商品ページ・ツール等）に合わせてコンテンツタイプを選ぶ。

### 2. E-E-A-T を体現する

Experience（経験）・Expertise（専門性）・Authoritativeness（権威性）・Trust（信頼）の4要素。Trust が土台で他3つを支える構造。YMYL（金融・医療・法律等）では特に厳格に評価される。「誰がなぜ書いたか」を明示し、一次情報・実体験・出典明記で示す。

### 3. ユーザー価値を最優先にする

Googleの公式姿勢は「**制作方法でなく品質**」。AI生成か人間執筆かは問わない。「この記事でしか得られない価値は何か」という問いに答えられないコンテンツは、どれだけ最適化しても長期的には評価されない。

### 4. テクニカルの健全性を維持する

どれだけ優れたコンテンツでも、クロールされなければ評価されない。Core Web Vitals・クロール可能性・構造化データは「コンテンツを評価させるための土台」として継続的に保つ。

### 5. 100% AI生成は失敗する — 人間監督（human-in-the-loop）を核に置く

最小監督で生成・公開する完全自動運用（AI-first）は速くスケールするが、真正性・信頼性を欠き、検索とLLM双方の可視性・顧客関係・法的安全性を同時に損なう。人間をループ内に保つ運用（AI-assisted）を既定とし、生成物は公開前に必ず人手レビューを通す。とりわけ「記述自体は正しいが文脈が欠落して誤情報化する欠落エラー（error by omission）」は検知が難しく、領域知識を持つ人間でなければ見抜けない。AIは加速装置であって意思決定者ではない。詳細は [`GENAI-WORKFLOWS.md`](references/GENAI-WORKFLOWS.md) と [`RISK-GOVERNANCE.md`](references/RISK-GOVERNANCE.md)。

---

## 3つの時代区分とパラダイム変化

| 時代 | 中心軸 | 主要施策 |
|------|--------|---------|
| ①リンク中心（〜2011年頃） | 被リンク数・ドメイン権威 | リンクビルディング・ディレクトリ登録 |
| ②コンテンツ/意図中心（2012〜2022年頃） | 検索意図充足・E-E-A-T・トピック網羅性 | コンテンツマーケ・トピッククラスター・テクニカルSEO |
| ③AI検索/引用中心（2023年〜現在） | AI Overviewsに引用される・ゼロクリック対応 | GEO・AEO・LLMO・answer-first構造・構造化データ |

現在は②の施策が③の基盤でもある。「AI検索に引用されやすいコンテンツ」は「人間にとっても価値あるコンテンツ」とほぼ重なる。

---

## 用語の統一（用語集）

このスキル全体で使う表記を統一する。揺れが生じた場合は以下を正とする。

| 用語 | 統一表記 | 備考 |
|------|---------|------|
| E-E-A-T | `E-E-A-T`（ハイフン4要素） | Experience, Expertise, Authoritativeness, Trust。`E-A-T` とは書かない |
| Core Web Vitals | `Core Web Vitals`（略記 CWV 可・初出はフル） | 現行3指標を必ず `LCP / INP / CLS` の順で表記 |
| LCP | `LCP（Largest Contentful Paint）` | 閾値 ≤2.5s |
| INP | `INP（Interaction to Next Paint）` | 閾値 ≤200ms。**FIDの後継**（FID は「廃止」と注記） |
| CLS | `CLS（Cumulative Layout Shift）` | 閾値 ≤0.1 |
| FID | `FID`（廃止指標として言及時のみ） | 「2024年3月にINPへ置換され廃止」と必ず添える |
| AI Overviews | `AI Overviews`（複数形・先頭大文字） | `AIO` `AI概要` と混在させない |
| AI Mode | `AI Mode` | GoogleのAIモード |
| GEO | `GEO（Generative Engine Optimization）` | 生成エンジン最適化。初出はフル表記 |
| AEO | `AEO（Answer Engine Optimization）` | 回答エンジン最適化 |
| LLMO | `LLMO`（LLM最適化 / LLM SEO とも） | 技術レイヤ。定義は「議論あり」と明記 |
| llms.txt | `llms.txt`（全小文字・コードスパン） | `llms-full.txt` は別物として区別 |
| トピッククラスター | `トピッククラスター` | ピラーページ＋クラスターページ構成 |
| 構造化データ | `構造化データ`（Schema.org / JSON-LD） | 実装形式は JSON-LD を推奨表記 |
| 検索意図 | `検索意図`（Search Intent） | 4分類: 情報収集型 / 案内型 / 取引型 / 商業調査型 |
| Scaled content abuse | `Scaled content abuse`（大規模コンテンツ不正） | 初出は英語＋括弧で日本語 |
| ゼロクリック | `ゼロクリック検索` | クリックせず完結する検索行動 |
| GBP | `GBP（Googleビジネスプロフィール）` | 旧 Googleマイビジネス。略記前に初出フル |
| GA4 / GSC | `GA4`（Google Analytics 4）/ `GSC`（Google Search Console） | 初出フル |
| YMYL | `YMYL`（Your Money or Your Life） | E-E-A-T が特に重要な領域 |
| RAG | `RAG`（Retrieval-Augmented Generation） | 実装詳細は ai 系スキルへ委譲 |
| Mentions / Citations | `Mentions`（応答本文にブランド名が出る）/ `Citations`（出典として提示されクリック可能） | AI可視性計測では**分離して計測**する。Citationはクリック追跡が容易だが、Mentionのみ（無リンク）はユーザーが反応しない限り検知できない |
| プロンプトトラッカー | `プロンプトトラッカー` | 特定プロンプトへのAI応答で自社が `Mentions`/`Citations` されるかを追跡するツール類。従来のランクトラッカーとは追跡対象が異なる |
| fan-out queries | `fan-out queries`（派生クエリ展開） | 生成AIがユーザーの複合プロンプトを内部で複数の派生クエリに分解して検索する挙動。各派生のどれかに `Mentions`/`Citations` され得る |
| alligator mouth | `alligator mouth`（ワニの口） | AIO拡大後にGSCで頻出する、impression上昇線とCTR下落線の乖離パターン |
| AIO 4コンポーネント | `AIO 4コンポーネント`（Quality / Context / Authority / Format） | AI検索に引用されるための暗記フレーム。1つ欠けると引用確率が大きく下がる |
| AI-first / AI-assisted | `AI-first`（最小監督で生成・公開）/ `AI-assisted`（人間をループ内に保つ・augmented とも） | コンテンツ運用の二分法。ブランド・コンプラ重視は AI-assisted を選ぶ |
| Prohibited Inputs | `Prohibited Inputs`（禁止入力） | 公開LLMに投入してはならない情報分類（IP・機密・認証データ・PII・機微個人データ等） |
| 品質比率 | `品質比率`（quality ratio） | 公開コンテンツ全体に占める低品質物の比率。例: 50:1（低品質1/50）が量産で崩れると全体評価を毀損する |
| error by omission | `error by omission`（欠落による誤り） | 記述自体は正しいが文脈が欠落して誤情報化するエラー。AI生成物で最も検知困難・危険 |

---

## 鮮度の整合注記（重要）

以下8項目は「古い資料の記述」と「現行事実」が乖離するポイント。参照先 reference でも同じ注記を記載しているが、ここに集約して確認できるようにしておく。

### ① FAQ / HowTo リッチリザルトの廃止

- **HowTo リッチリザルト**: 2023年9月廃止（Google公式）
- **FAQ リッチリザルト**: 2026年5月7日に完全終了（Google公式）
- **扱い方**: `FAQPage` は Schema.org タイプとして有効であり、AI検索・構造化データの解析には依然有用。リッチリザルト表示を目的とした実装は「廃止済み」だが、既存マークアップの慌てた削除は不要。
- **参照先**: [`TECHNICAL-SEO.md`](references/TECHNICAL-SEO.md) § 構造化データ

### ② INP が FID を置換（2024年3月）

- 現行の Core Web Vitals は `LCP / INP / CLS` の3指標のみ。FID は廃止。
- 古いドキュメントに「FID を改善する」という記述があれば、現在は INP（閾値 ≤200ms）を対象にする。
- **参照先**: [`TECHNICAL-SEO.md`](references/TECHNICAL-SEO.md) § Core Web Vitals

### ③ 動的レンダリングの非推奨化

- Googleは動的レンダリング（クローラー向けにサーバーサイドで別出力する手法）を長期的解決策として非推奨とした。
- SSR（サーバーサイドレンダリング）/ SSG（静的サイト生成）/ ハイドレーション への移行を推奨。
- **参照先**: [`TECHNICAL-SEO.md`](references/TECHNICAL-SEO.md) § クロール・インデックス・レンダリング

### ④ `llms.txt` は効果未実証

- 2026年6月時点で主要LLMの公式採用実績はゼロ。定量的な効果を示す査読済み研究も存在しない。
- 「設置コストは低い」が「効果の客観的証拠はほぼない」が公平な評価。断定的な推奨はしない。
- **参照先**: [`AI-SEARCH-GEO.md`](references/AI-SEARCH-GEO.md) § llms.txt

### ⑤ GEO の定量効果はソースを峻別する

- GEO-bench等の研究値とベンダー・業界記事値は区別して引用すること。
- 「XX% 引用率向上」のような数値はエンジン・クエリ・コンテンツ種別により大きく異なる。「目安」と明示し断定しない。
- **参照先**: [`AI-SEARCH-GEO.md`](references/AI-SEARCH-GEO.md) § GEO

### ⑥ AI可視性計測は不正確な指標として扱う

- プロンプトトラッカー等によるAI可視性（`Mentions`/`Citations`）の数値は**不正確**で、追跡LLMやプロンプトの選び方で大きくぶれる。**トレンド把握にのみ用い、投資判断の一次根拠にはしない**。
- 同様に GSC の impression は「クリックの代理指標」であり、AIO拡大後の `alligator mouth`（impression上昇×CTR下落）を悪兆候と早合点しない。一部観測例では残ったクリックは行動意図が高く、収益・予約・フォーム完了はほぼ横ばいだった（一般知識提供が中核のサイトは例外的に打撃を受け得る）。
- **参照先**: [`MEASUREMENT.md`](references/MEASUREMENT.md) § AI検索流入の計測

### ⑦ 米国でAI単独生成物は著作権保護されない

- 米国ではAI単独生成物（人間がプロンプトを与えただけのもの）は著作権保護の対象外。保護には**人間が十分な表現要素を決定した**ことが必要、という公的整理が示されている（米国著作権局の報告書 Part 2・2025年1月）。
- 含意: ソートリーダーシップ・主要ページ・ブランドコピー等、保護したい資産は人間が制作・refine する。
- **参照先**: [`RISK-GOVERNANCE.md`](references/RISK-GOVERNANCE.md) § コンプライアンス / 開示規制

### ⑧ AIコンテンツ開示規制（EU AI Act 施行）

- EU AI Act は2025年に施行段階に入り、AI出力を検出可能にすることと利用者への開示を求める（EU内、およびEU内の人に影響する全組織に適用）。ただし**人間がレビュー・編集し編集責任を持つAI生成物は開示不要**の例外がある。
- 米国では声・likeness の無断デジタル複製を規制する法案（NO FAKES Act）が提案段階にある。
- **参照先**: [`RISK-GOVERNANCE.md`](references/RISK-GOVERNANCE.md) § コンプライアンス / 開示規制

---

## 全体ワークフローの目安

SEO改善の典型的な進行順序。各ステップで参照すべき reference を明示する。

```
1. 現状監査
   ├─ テクニカル診断（Core Web Vitals・クロール・構造化データ）→ TECHNICAL-SEO.md
   └─ コンテンツ・KW診断（意図ミスマッチ・網羅性ギャップ）→ CONTENT-KEYWORDS.md

2. 基盤整備（Layer 1）
   ├─ E-E-A-T・トピッククラスター設計 → FOUNDATIONS-RANKING-EEAT.md
   ├─ テクニカル修正（CWV・インデックス最適化） → TECHNICAL-SEO.md
   └─ オンページ最適化（タイトル・見出し・内部リンク） → CONTENT-KEYWORDS.md

3. コンテンツ強化
   ├─ KWリサーチ・意図グルーピング → CONTENT-KEYWORDS.md
   └─ コンテンツ網羅性・品質向上 → CONTENT-KEYWORDS.md

4. 生成AI活用（Layer 2）
   ├─ 制作支援プロンプト・スケール化 → GENAI-WORKFLOWS.md
   └─ リスク管理・ガバナンス整備 → RISK-GOVERNANCE.md

5. AI検索最適化（Layer 3）
   ├─ AI可視性の自己診断（120点満点ワークシートで現状採点）→ AI-VISIBILITY-PLAYBOOK.md
   ├─ GEO・AEO・LLMO 施策 → AI-SEARCH-GEO.md
   └─ answer-first構造・構造化データ見直し → AI-SEARCH-GEO.md + TECHNICAL-SEO.md

6. 計測・改善ループ
   ├─ KPI設計・ROI算出 → MEASUREMENT.md
   ├─ GA4・GSC・ランクトラッキング運用 → MEASUREMENT.md
   └─ AI検索流入の計測（ゼロクリック対応） → MEASUREMENT.md
```

**ループの原則**: 計測結果を受けて 1（監査）に戻る。アルゴリズム更新後は必ず 2（基盤整備）から再確認する。

---

## 関連スキル

このスキルの範囲外・またはより専門的なスキルへの誘導。

| 状況 | 誘導先スキル |
|------|------------|
| 文章のAI臭を除去・推敲したい | `writing-effective-prose` |
| マーケコピー・見出し・SNS投稿を生成したい | `studio:creating-content` |
| RAG設計・LLMOps・プロンプトパターンを設計したい | `ai:designing-genai-patterns` |
| Web AI・RAGの実装コードを書きたい | `ai:integrating-ai-web-apps` |
| AIエージェントを構築したい | `ai:building-ai-agents` |
| UX・ユーザー体験設計をしたい | `design:designing-ux` |
| SEO KPIをプロダクト戦略・成長指標と連携させたい | `product:practicing-product-management` |
| トピッククラスター・サイト構造を図解したい | `studio:creating-diagrams` |

---

*このスキルは情報の鮮度を重視する。アルゴリズムの変更・新しい研究結果が出た場合は references を更新し、INSTRUCTIONS.md の鮮度注記セクションを同期させること。*
