---
description: >-
  Unified writing craft guide: prose fundamentals, AI smell detection (always active), technical docs (7Cs),
  academic writing (Harvard, dissertation), university report/thesis writing (reports, graduation
  thesis, experimental reports), web/digital writing, FAQ writing, and revision techniques.
  REQUIRED for all text output — AI smell check is always active regardless of document type.
  Use when writing, reviewing, proofreading, or creating any document (technical docs, reports, slides,
  emails, academic papers, essays, dissertations, university reports, graduation theses,
  experimental reports, business documents, web content, FAQ/help docs).
  Covers: general prose craft, technical documentation (7Cs), academic writing (Harvard referencing,
  PEEL method, dissertation structure), university report/thesis (structure, argumentation, citation format,
  plagiarism prevention, thesis process, scientific writing), web/digital writing, FAQ writing,
  and AI text refinement (6 smell patterns, rewrite rules).
  For Zenn articles, use writing-zenn-articles instead.
  For LaTeX document compilation, use writing-latex instead.
---

# 効果的な文章を書く技術

## Overview

このスキルは、あらゆる文章に適用できる**統合ライティングガイド**です。6つの軸で文章の品質を高めます:

1. **普遍的ライティング原則** -- 読者分析、問い設計、パラグラフ構築、文レベル技術、リズム・表現、体系的推敲
2. **AI臭の検出と除去** -- 全出力で常時適用。不自然な表現パターンを検出し、人間らしい文章に書き換える
3. **技術文書の作法** -- 7Csの原則、README、API仕様書、報告書テンプレート
4. **学術文書の作法（英語）** -- 論文構造、Harvard参照、批判的思考、Dissertation、AI活用
5. **大学レポート・論文** -- 序論・本論・結論、問い→主張→論証、理系実験レポート、引用・剽窃防止、卒論プロセス
6. **Web・デジタルライティング** -- UXライティング、PREP法、SEO、読み手ファースト
7. **FAQ・ヘルプドキュメント** -- 一問一答原則、6W1H、カテゴリ設計

### 入力として受け取るもの

- **テキスト引数**: `writing-effective-prose "改善したい文章"` のように直接渡されたテキスト
- **ファイルパス**: `.tex`, `.md`, `.docx`, `.pptx`, `.txt` などのファイル
- **レビュー依頼**: 「この文章を見てほしい」「読みやすくして」などの依頼
- **新規作成依頼**: 「報告書を書いて」「論文の構成を考えて」などの作成依頼

---

## AI臭チェック（常時適用）

**全てのテキスト出力時に必ず適用する。** 目的の確認やAskUserQuestionは不要。

### 6パターン概要

| # | パターン | 検出の目安 | 対処 |
|---|---------|-----------|------|
| 1 | **記号の残留** | emダッシュ、「」の過剰使用、（）での責任回避、／で並列 | 記号を削り、本文に溶かす |
| 2 | **単調なリズム** | 同じ語尾が3回連続、接続詞の過多、段落末が毎回きれいに閉じる | 語尾を混ぜる、文の長短を変える |
| 3 | **構造の形骸化** | 「まず」「次に」「最後に」の機械的連番、見出しと中身の不一致 | 接続詞を減らし、文脈で繋ぐ |
| 4 | **曖昧な網羅** | 「などが挙げられます」で逃げる、「様々な」「多くの」で濁す | 具体的に3つ挙げるか、断定する |
| 5 | **過剰な丁寧さ** | 「〜と言えるでしょう」「〜かもしれません」の連発 | 言い切る。断定を恐れない |
| 6 | **空虚な強調** | 「非常に重要」「大きな意義」など中身のない修飾 | 削るか、数値や事例で裏付ける |

### 書き換えの基本原則

1. **簡潔さ最優先** -- 削れる語は全て削る。「〜することが可能です」は「〜できる」
2. **記号に逃げない** -- emダッシュ、括弧、スラッシュを減らし、接続詞や別文にする
3. **事なかれ禁止** -- 「〜と言えるかもしれません」ではなく「〜だ」と書く
4. **具体動詞で書く** -- 「検討を行う」ではなく「検討する」。名詞化を動詞に戻す
5. **比喩禁止** -- 「〜の礎」「〜の羅針盤」のような比喩は情報量ゼロ。事実を書く

### 適用タイミング

| 場面 | 適用 |
|------|------|
| コードコメント・docstring | 適用する |
| ドキュメント・README | 適用する |
| チャット応答・説明 | 適用する |
| コミットメッセージ | 適用する |
| エラーメッセージ | 適用する |
| ユーザー向けUI文言 | 適用する |

詳細な検出ルールと具体例 → [AI-SMELL-PATTERNS.md](references/AI-SMELL-PATTERNS.md)
コンテキスト別の書き換え手法 → [AI-SMELL-REWRITE-RULES.md](references/AI-SMELL-REWRITE-RULES.md)

---

## 文章を書く5つの段階

文章作成の基盤プロセス。どの目的の文書でも共通して適用する。

| 段階 | 概要 | 詳細 |
|------|------|------|
| **1. 準備** | 読み手・目的・論点の設計 | [PREPARATION.md](references/PREPARATION.md) |
| **2. 構成** | 論理構造・パラグラフ設計 | [LOGICAL-STRUCTURE.md](references/LOGICAL-STRUCTURE.md) |
| **3. 執筆** | 文レベルの技術 | [SENTENCE-CRAFT.md](references/SENTENCE-CRAFT.md) |
| **4. 表現** | 文体・リズム・簡潔さ | [EXPRESSION-STYLE.md](references/EXPRESSION-STYLE.md) |
| **5. 推敲** | 校正・品質チェック | [REVISION-CHECKLIST.md](references/REVISION-CHECKLIST.md) |

### 段階1: 準備 -- 書く前に考える

書き始める前に、文章の7つの要件（意見・望む結果・論点・読み手・立場・論拠・根本思想）を明確にする。「テーマ」ではなく「問い」を立てることで、意見を引き出す。

**読者分析の3層**: ①知識レベル（専門性）→ ②意欲と目的（なぜ読むのか）→ ③立場になる想像力（最重要）。読み手が予測する展開と実際のギャップを最小化する（驚き最小原則）。デジタル文書では「読者は20%しか読まない」前提で構成する。

**問いの3ステップ**: ①大きな問いを立てる → ②小さな問いに分解 → ③答えを出す。問いの型は7種類（同格型/対比型/変化型/ギャップ型/葛藤型/説話型/原因型）。

**よくある失敗**: テーマだけ決めて書き始め、途中で「何が言いたいのかわからない」状態になる。書く前に「この文章を読んだ人に何をしてほしいか」を1行で書いてから始める。

### 段階2: 構成 -- 論理の骨格を作る

全体構造（総論→各論→結論）、パラグラフ設計（1パラ=1トピック）、MECE分解、So What?/Why So?の往復で論理的な骨格を作る。

**パラグラフ・ライティング**: キーセンテンスをパラグラフ冒頭に配置、新情報は文末に配置（旧情報→新情報の順）、パラグラフ間は論理的に接続。キーパラグラフの各文が各パラグラフのキーセンテンスに対応する。

**接続詞の4分類**: 順接（だから）、付加（また）、逆接（しかし）、補足・換言・例示（ただし、つまり、たとえば）。論理関係が明確な場合は接続詞で明示するが、機械的な連番は避ける。

**2つの論理パターン**:
- **並列型**: 複数の根拠をMECEに並べる
- **解説型**: 要約文を詳しく説明していく

### 段階3: 執筆 -- 一文一義で書く

1文=1ポイント（50〜100字目安）。修飾語は被修飾語の近くに置く。接続助詞「が」を避け、明確な接続詞に置き換える。

**句読点（読点）の4ルール**（優先順位順）: ①長い修飾語の境界 → ②主語・述語関係の明確化 → ③並列表現の境界 → ④誤解防止。1行にひとつを目安とする。

**「は」と「が」**: 「は」=テーマ提示（既知の情報）、「が」=焦点・新情報の導入。「の」の3連鎖は避ける。

### 段階4: 表現 -- 削ぎ落として磨く

冗長表現の除去、具体的な記述（数値・before/after）、リズムの調整。

**文体とはリズムである**: 音声的リズム（語尾の変化、文の長短）、視覚的リズム（句読点、改行、漢字/ひらがなバランス）、論理的リズム（接続詞の配置、展開速度）の3要素。漢字率30〜40%が読みやすい目安。文の長さに意図的な起伏をつける。

| 冗長な表現 | 簡潔な表現 |
|-----------|-----------|
| 〜することができる | 〜できる |
| 〜に関する検討を行った | 〜を検討した |
| 〜というふうに考えられる | 〜と考えられる |

### 段階5: 推敲 -- 客観的に読み直す

パラグラフの要約文だけを繋げて意味が通るか確認する。批判的態度で読み、誤字・脱字・論理の欠落を発見する。声に出して読み、つかえる箇所を直す。

**帽子の切り替え**: 書く時は「著者の帽子」、読み返す時は「読者の帽子」に切り替える。読者が迷う6場面（似た語句、長文、言葉不足、無駄、指示語、言外の意味）を意識する。

**推敲の3大作戦**: ①ローラー作戦（全文通読）→ ②フェーズ作戦（観点別に繰り返し読む）→ ③メリハリ作戦（修正箇所とその周辺を念入りに）。時間を置いて推敲する（直後→数時間後→1日後→提出直前の段階的確認）。

---

## Quick Reference: 文章の基本原則

### 思考・設計

| 原則 | 要点 |
|------|------|
| **読者を3層で分析する** | ①知識レベル ②意欲と目的 ③立場になる想像力（最重要） |
| **驚き最小原則を守る** | 読み手の予測と実際の展開のギャップを最小化する |
| **「問い」を立てて意見を引き出す** | テーマではなく「問い」で考え、7つの型で分解する |
| **7つの要件を確認する** | 意見・望む結果・論点・読み手・自分の立場・論拠・根本思想を整理する |

### 構成・論理

| 原則 | 要点 |
|------|------|
| **冒頭に重要情報をまとめる** | 総論→各論→結論の流れで、結論を最初に示す |
| **1パラグラフ = 1トピック** | キーセンテンスを冒頭に配置、新情報は文末に配置 |
| **要約文テスト** | 各パラグラフの冒頭文だけ繋げて論旨が通るか確認する |
| **So What?/Why So?を往復する** | 「だから何？」「なぜそう言える？」の問いで論理の穴を塞ぐ |
| **接続詞で論理関係を明示する** | 順接・付加・逆接・補足の4分類を意識して使い分ける |

### 文・表現

| 原則 | 要点 |
|------|------|
| **1文 = 1ポイント（50〜100字目安）** | 複数の主張を1文に詰め込まない |
| **修飾語は被修飾語の近くに置く** | 長い修飾節は前に、短い修飾語は後ろに配置する |
| **読点は4ルールで打つ** | ①修飾語境界 ②主述明確化 ③並列境界 ④誤解防止（優先順位順） |
| **「は」=テーマ、「が」=焦点** | 既知情報には「は」、新情報には「が」を使う |
| **リズムに変化をつける** | 文の長短を混ぜ、語尾を変え、漢字率30〜40%を目安にする |
| **簡潔に書く** | 「〜することが重要です」→「〜が重要だ」のように削ぎ落とす |
| **具体的に書く** | 変化のbefore/after、数値、「誰が何をどうする」を明示する |

### 推敲

| 原則 | 要点 |
|------|------|
| **「読者の帽子」で読み返す** | 著者の立場を離れ、初見の読者として文章を検証する |
| **要約文だけ読んで意味が通るか確認** | 各パラグラフの冒頭文を繋げて読み、論旨が伝わるかチェックする |
| **3大作戦で段階的に推敲する** | ①ローラー（通読）②フェーズ（観点別）③メリハリ（修正箇所重点） |
| **時間を置いて読み返す** | 直後→数時間後→1日後の段階的確認で精度を上げる |
| **声に出して読む** | つかえる箇所は必ず問題がある |

---

## 目的別ガイド

文書の目的に応じて、追加で参照すべきリファレンスが変わる。

### 目的の確認

文書の目的が明確でない場合、AskUserQuestionツールでユーザーに確認する。

**自動判定できる場合（確認不要）**:
- `.tex` ファイル → 学術文書
- `README.md`, `API*.md`, `CHANGELOG.md` → 技術文書
- `.docx`, `.pptx` → ビジネス・一般

**自動判定できない場合** → AskUserQuestionで確認:

質問テンプレート:
- question: "この文書の目的は何ですか？"
- options:
  1. 技術文書（README、API仕様、設計書、報告書）
  2. 学術文書・英語（論文、エッセイ、Dissertation）
  3. 大学レポート・論文（レポート、卒論、修論、実験レポート）
  4. Web・デジタルコンテンツ（Webページ、UI文言、ブログ記事）
  5. FAQ・ヘルプドキュメント
  6. ビジネス・一般文書（メール、企画書、スライド）
  7. 校正・レビュー（既存文書の改善）

---

### 技術文書

7つのCの原則に基づいて技術文書を作成する。

| C | 原則 | 要点 |
|---|------|------|
| 1 | **Clear（明確）** | 曖昧さがなく、容易に理解できる |
| 2 | **Concise（簡潔）** | 必要な情報を最小限の言葉で表現 |
| 3 | **Correct（正確）** | 文法、事実、技術的内容に誤りがない |
| 4 | **Coherent（一貫）** | 論理的に結びつき、スムーズに流れる |
| 5 | **Concrete（具体的）** | 測定可能で明確な記述 |
| 6 | **Complete（完全）** | 必要な情報がすべて含まれている |
| 7 | **Courteous（丁寧）** | 読者を意識した適切なトーンと構成 |

**参照ファイル**:

| ファイル | 内容 |
|---------|------|
| [TECHNICAL-DOCS-PRINCIPLES.md](references/TECHNICAL-DOCS-PRINCIPLES.md) | 7Cs原則の詳細解説とBefore/After実例 |
| [TECHNICAL-DOCS-STRUCTURE.md](references/TECHNICAL-DOCS-STRUCTURE.md) | 文章構造、一文一義、README構造例、コードコメント |
| [TECHNICAL-DOCS-REPORTS.md](references/TECHNICAL-DOCS-REPORTS.md) | 報告書テンプレート（実装完了、技術調査、進捗） |
| [TECHNICAL-DOCS-ANTI-PATTERNS.md](references/TECHNICAL-DOCS-ANTI-PATTERNS.md) | 冗長表現、曖昧表現、技術用語統一チェック |
| [TECHNICAL-WRITING.md](references/TECHNICAL-WRITING.md) | IT表記ルール、コード掲載の鉄則、見出し設計 |

**優先順位**: 正確性 → 明確性 → 簡潔性 → 丁寧さ

---

### 学術文書（英語・国際標準）

5つの柱に基づいて英語の学術文書を作成する。日本語のレポート・論文については次の「日本語レポート・論文」セクションを参照。

#### 柱1: ライティングプロセス

反復的サイクルで進行: 計画（40%）→ 下書き（20%）→ 推敲（40%）

- **課題分析**: コマンドワード（discuss, analyse, evaluate等）を特定
- **リサーチクエスチョン設定**: トピック・制限ワードからキーワードリスト作成
- **批判的思考**: 分析・比較・評価・統合のレベルで文献を扱う

#### 柱2: 一貫性と論証

- **組織化原則**: Classification / Comparison and Contrast / Cause and Effect / Problem-Solution
- **Coherence**: General→Specific、Old→New
- **論証構築**: Claim → Evidence → Warrant → Qualifier → Rebuttal

#### 柱3: 引用・参照（Harvard System）

- **One-to-one match**: 本文引用とReferencesの一対一対応
- **著者名・年の記載**: 本文中は (Surname, Year) 形式
- **批判的ソース活用**: Author-prominent vs Information-prominent

#### 柱4: アカデミックスタイル

- **明確性**: 論理的順序、リンクバック、適切な繰り返し
- **簡潔・正確性**: 冗長表現排除、正確な語彙選択
- **フォーマル性**: 客観的トーン、非人称構造、短縮形禁止

#### 柱5: 提出準備

- **最終編集**: 意味・流れ・論理性
- **校正**: スペリング・文法・句読点
- **フォーマット**: 1.5/ダブルスペース、12pt、ワードカウント±10%以内

**参照ファイル**:

| ファイル | 内容 |
|---------|------|
| [ACADEMIC-WRITING-PROCESS.md](references/ACADEMIC-WRITING-PROCESS.md) | ライティングサイクル、課題分析、計画手法 |
| [ACADEMIC-COHERENCE-ARGUMENTS.md](references/ACADEMIC-COHERENCE-ARGUMENTS.md) | 段落構造、接続表現、6つの論証テンプレート |
| [ACADEMIC-REFERENCING-SOURCES.md](references/ACADEMIC-REFERENCING-SOURCES.md) | Harvard system、報告動詞、リサーチソースHack |
| [ACADEMIC-ACADEMIC-STYLE.md](references/ACADEMIC-ACADEMIC-STYLE.md) | フォーマル表現変換、文法、British/American English |
| [ACADEMIC-SUBMISSION-PREPARATION.md](references/ACADEMIC-SUBMISSION-PREPARATION.md) | 提出前チェックリスト、フォーマット |
| [ACADEMIC-DISSERTATION-WRITING.md](references/ACADEMIC-DISSERTATION-WRITING.md) | Dissertation章別テンプレート |
| [ACADEMIC-INCORPORATING-THEORIES.md](references/ACADEMIC-INCORPORATING-THEORIES.md) | 理論・モデル活用と批評 |
| [ACADEMIC-CRITIQUING-TEXTS.md](references/ACADEMIC-CRITIQUING-TEXTS.md) | テキスト批評の5アプローチ |
| [ACADEMIC-REFLECTIVE-WRITING.md](references/ACADEMIC-REFLECTIVE-WRITING.md) | リフレクティブライティング9手法 |
| [ACADEMIC-CRITICAL-RESEARCH.md](references/ACADEMIC-CRITICAL-RESEARCH.md) | 検索戦略、18種の情報ソース |
| [ACADEMIC-AI-WRITING.md](references/ACADEMIC-AI-WRITING.md) | AI支援ライティング・出版 |
| [ACADEMIC-AI-RESEARCH.md](references/ACADEMIC-AI-RESEARCH.md) | AI支援リサーチ |
| [ACADEMIC-AI-DATA-ANALYSIS.md](references/ACADEMIC-AI-DATA-ANALYSIS.md) | AIデータ管理・分析 |
| [ACADEMIC-AI-PRESENTATIONS.md](references/ACADEMIC-AI-PRESENTATIONS.md) | AIプレゼンテーション |
| [ACADEMIC-AI-ETHICS.md](references/ACADEMIC-AI-ETHICS.md) | AI倫理・規制 |
| [ACADEMIC-AI-PRACTICAL-TIPS.md](references/ACADEMIC-AI-PRACTICAL-TIPS.md) | AI活用の実践ガイド |

**エッセイ構造（標準）**:

| セクション | 割合 | 必須要素 |
|-----------|------|---------|
| Introduction | 10-15% | Hook, Context, Thesis Statement, Scope, Structure |
| Main Body | 70-80% | PEEL法（Point, Evidence, Explanation, Link） |
| Conclusion | 10-15% | Restatement, Summary, Synthesis, Implications |

---

### 大学レポート・論文

大学で求められるレポート・論文を作成するための総合ガイド。6つの領域をカバーする。

#### A. 基本構成

レポート・論文の定義から基本構成、学術文章のルールまで。

| ファイル | 内容 |
|---------|------|
| [REPORT-THESIS-TYPES.md](references/REPORT-THESIS-TYPES.md) | 感想文・小論文・レポート・論文の違い、学術的文章の要件 |
| [REPORT-STRUCTURE.md](references/REPORT-STRUCTURE.md) | 序論・本論・結論の三部構成、パラグラフ・ライティング |
| [SCHOLARLY-WRITING-RULES.md](references/SCHOLARLY-WRITING-RULES.md) | 明快・明確・簡潔の三原則、事実と意見の書き分け、文体ルール |

#### B. 論理構成

問いの設定から論証の組み立て、アウトライン作成まで。

| ファイル | 内容 |
|---------|------|
| [RESEARCH-QUESTION-DESIGN.md](references/RESEARCH-QUESTION-DESIGN.md) | テーマと問いの違い、問いの型（What/Why/How/Should）、絞り込みステップ |
| [ARGUMENTATION-FRAMEWORK.md](references/ARGUMENTATION-FRAMEWORK.md) | 問い→主張→論証のフレームワーク、演繹・帰納・アブダクション、ダメな論証パターン |
| [OUTLINE-CONSTRUCTION.md](references/OUTLINE-CONSTRUCTION.md) | トップダウン/ボトムアップ型アウトライン、MECE、分量配分 |

#### C. 理系テキスト

理系特有のテクニカル・ライティングと実験レポートの書き方。

| ファイル | 内容 |
|---------|------|
| [SCIENTIFIC-WRITING.md](references/SCIENTIFIC-WRITING.md) | 科学的記述の原則、数値・単位・図表のルール、論理と接続表現 |
| [EXPERIMENTAL-REPORT.md](references/EXPERIMENTAL-REPORT.md) | 実験レポートの構成（目的・方法・結果・考察）、テンプレート |

#### D. 引用・参考文献

引用フォーマットと剽窃防止。

| ファイル | 内容 |
|---------|------|
| [CITATION-FORMAT.md](references/CITATION-FORMAT.md) | 直接引用・間接引用、注の種類、参考文献リストの書式 |
| [PLAGIARISM-PREVENTION.md](references/PLAGIARISM-PREVENTION.md) | 剽窃の定義と種類、パラフレーズ技法、AI時代の注意点 |

#### E. 卒業論文・修士論文

卒論の執筆プロセスと評価基準。

| ファイル | 内容 |
|---------|------|
| [THESIS-WRITING-PROCESS.md](references/THESIS-WRITING-PROCESS.md) | 全体スケジュール、テーマ設定、指導教員との関わり、口頭試問準備 |
| [THESIS-EVALUATION.md](references/THESIS-EVALUATION.md) | 評価基準、よくある減点ポイント、提出前チェックリスト |

#### F. 執筆技法

文章を磨く技法とよくある間違いの回避。

| ファイル | 内容 |
|---------|------|
| [PROSE-TECHNIQUES.md](references/PROSE-TECHNIQUES.md) | 要約・パラフレーズ技法、接続表現の体系、推敲の方法 |
| [WRITING-PITFALLS.md](references/WRITING-PITFALLS.md) | 論文禁句集、構成・文章・書式の間違い、最終チェックリスト |

**レポートの基本構造**:

| セクション | 割合 | 必須要素 |
|-----------|------|---------|
| 序論 | 10-15% | 背景、問い、主張の提示、本論の構成 |
| 本論 | 70-80% | 論証（根拠→分析→考察）、先行研究との対話 |
| 結論 | 10-15% | 主張の再確認、残された課題、展望 |

---

### Web・デジタルライティング

「読者は文章の20%しか読まない」前提で構成するデジタル媒体向けの文章術。

**参照ファイル**: [WEB-DIGITAL-WRITING.md](references/WEB-DIGITAL-WRITING.md)

カバー範囲: 読み手ファースト7ルール、UXライティング、PREP法、強調・装飾ルール、SEO基礎

---

### FAQライティング

ユーザーの自己解決率を高めるFAQ・ヘルプドキュメントの文章術。

**参照ファイル**: [FAQ-WRITING.md](references/FAQ-WRITING.md)

カバー範囲: 良いFAQの3条件、一問一答の原則、Q/Aの書き方、6W1H原則、カテゴリ設計

---

### ビジネス・一般文書

説得・依頼・謝罪・議事録・メール・企画書など、実務で頻出するパターン。

**参照ファイル**: [PRACTICAL-PATTERNS.md](references/PRACTICAL-PATTERNS.md)

カバー範囲: 上司を説得する文章、依頼文、議事録、お詫び文、志望理由書、メール、報告書・提案書、企画書、PREP法、つかみの技術

---

### 校正・レビュー

既存文書の品質改善を行う場合のガイド。

**参照ファイル**:
- [REVISION-CHECKLIST.md](references/REVISION-CHECKLIST.md) -- 帽子切替、3大作戦、時間戦略、迷い6場面、語句チェックリスト
- [ANTI-PATTERNS.md](references/ANTI-PATTERNS.md) -- 語句・文構造・論理レベルの悪文パターンと修正法

**レビュー時の優先順位**:
1. **論理・構成レベル**: 主張が明確か、論理の流れが正しいか
2. **パラグラフレベル**: 1パラ1トピックか、要約文はあるか
3. **文レベル**: 一文一義か、修飾関係は明確か
4. **表現レベル**: 冗長表現はないか、具体的か
5. **校正レベル**: 誤字脱字、表記揺れ

---

## 入力形式への対応

| 入力 | 対応方針 |
|------|---------|
| **テキスト引数** | 文章を直接分析し、改善提案・書き直しを提示する |
| **`.tex` / `.md` ファイル** | Read toolでソースを読み込み、構成と文章を分析する |
| **`.docx` / `.pptx` ファイル** | Read toolで読み込み、全体構成から文章まで分析する |
| **レビュー依頼** | REVISION-CHECKLIST.mdに従い体系的にチェックする |
| **新規作成依頼** | PREPARATION.md→LOGICAL-STRUCTURE.md→執筆の順で段階的に進行する |

---

## 問題診断フロー

「この文章の何が悪いのかわからない」とき、以下のフローで問題を特定する。

```
文章を読んで「なんか変」と感じた
        |
        +-- 「何を言いたいのかわからない」
        |       -> 論理・構成の問題 -> LOGICAL-STRUCTURE.md
        |
        +-- 「読みにくい・理解に時間がかかる」
        |       -> 文レベルの問題 -> SENTENCE-CRAFT.md
        |
        +-- 「くどい・回りくどい」
        |       -> 表現・文体の問題 -> EXPRESSION-STYLE.md
        |
        +-- 「根拠がない」
        |       -> 準備・思考設計の問題 -> PREPARATION.md
        |
        +-- 「目的や結論が見えない」
        |       -> 構成の問題 -> 冒頭に結論を持ってくる
        |
        +-- 「AIっぽい」
        |       -> AI臭パターン -> AI-SMELL-PATTERNS.md
        |
        +-- 「誤字・脱字・表記揺れ」
        |       -> 校正の問題 -> REVISION-CHECKLIST.md
        |
        +-- 「Web/アプリの文言が伝わらない」
        |       -> デジタルライティング -> WEB-DIGITAL-WRITING.md
        |
        +-- 「FAQが役に立たない」
        |       -> FAQ特有の問題 -> FAQ-WRITING.md
        |
        +-- 「レポートの書き方がわからない」
        |       -> レポート基礎 -> REPORT-STRUCTURE.md, REPORT-THESIS-TYPES.md
        |
        +-- 「論文の論証が弱い」
        |       -> 論理構成の問題 -> ARGUMENTATION-FRAMEWORK.md
        |
        +-- 「実験レポートの書き方」
                -> 理系レポート -> EXPERIMENTAL-REPORT.md
```

---

## 統合チェックリスト

### 構成・論理

- [ ] 文章の目的と読み手（3層分析）が明確になっている
- [ ] 冒頭で主張・結論が示されている
- [ ] 各パラグラフの冒頭文（キーセンテンス）だけを繋げても意味が通る
- [ ] 並列情報はMECEに整理され、表現がパラレルになっている
- [ ] 接続詞が論理関係を正しく示している

### 文・表現

- [ ] 1文が長すぎない（目安50〜100字）
- [ ] 修飾語が被修飾語の近くにある
- [ ] 読点が4ルール（修飾語境界、主述明確化、並列、誤解防止）に従っている
- [ ] 「は」と「が」が正しく使い分けられている
- [ ] 「の」の3連鎖がない
- [ ] 文の長短にリズムの変化がある
- [ ] 冗長表現を削っている
- [ ] 抽象的な表現に具体的な数値・事例が伴っている

### 表記・校正

- [ ] 同一概念に同一表記（表記揺れがない）
- [ ] 誤字・脱字がない
- [ ] 漢字とひらがなのバランスが読みやすい（漢字率30〜40%目安）
- [ ] 二重否定がない
- [ ] 「こと」「という」の多用がない

### AI臭チェック（必須）

- [ ] emダッシュ、過剰な括弧、スラッシュ並列を使っていない
- [ ] 同じ語尾が3回以上連続していない
- [ ] 「などが挙げられます」「様々な」で逃げていない
- [ ] 「〜と言えるでしょう」の連発がない
- [ ] 「非常に重要」のような空虚な強調がない
- [ ] 比喩や装飾的表現を事実に置き換えている

---

## 関連スキル

| スキル | 使い分け |
|--------|---------|
| **writing-zenn-articles** | Zennプラットフォーム特化（フロントマター、公開フロー） |
| **writing-latex** | LaTeX文書作成（upLaTeX+dvipdfmx環境、日本語学術文書のコンパイル） |
