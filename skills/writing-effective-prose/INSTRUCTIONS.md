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
8. **テックブログ・技術記事** -- ネタ出し、構成パターン、コード解説、Web特有の工夫
9. **書く力の基礎強化** -- 日本語作文技術、わかりやすい文章術、説明・伝達の技法、テクニカルライティング実践

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

**テーマのWhy-What-How分解**: テーマを「なぜ（背景・目的）」「何を（内容・ゴール）」「どうやって（手順・方法）」の3軸に分解することで、書くべきことが具体化され、構成の骨格が自然に生まれる。ゴールデンサークル理論（サイモン・シネック）に従い、Whyを前に出すと読み手の共感を得やすい。

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
  8. エンジニア設計書（要件定義書、仕様書、機能設計書、運用設計書）

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
| [TECHNICAL-WRITING-ADVANCED.md](references/TECHNICAL-WRITING-ADVANCED.md) | テクニカルライティング実践（構成・文章テクニック・文書種別・生成AI活用） |

**優先順位**: 正確性 → 明確性 → 簡潔性 → 丁寧さ

---

### エンジニア設計書

ソフトウェア開発で必要な設計書（要件定義書、仕様書、機能設計書、運用設計書）を作成するためのガイド。

**参照ファイル**: [ENGINEERING-DESIGN-DOCS.md](references/ENGINEERING-DESIGN-DOCS.md)

カバー範囲: ドキュメント体系（V字モデル）、要件定義書テンプレート、外部仕様書テンプレート、機能設計書の標準化、非機能要件の定義、運用設計書（3部構成）、アジャイル開発の設計書、設計書の3大原則（なぜ・何を、全体から部分へ、One Fact One Place）

**設計書の3大原則**:
1. **「なぜ・何を」の構成** -- 仕様（何を）だけでなく目的（なぜ）を併記。変更判断の基準になる
2. **「全体から部分へ」の展開** -- 概要→構成図→機能一覧→個別機能詳細の順でドリルダウン
3. **One Fact One Place** -- 同じ情報を複数箇所に書かない。変更時の不整合を防ぐ

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

### テックブログ・技術記事

技術ブログ（Zenn、Qiita等）や技術書の執筆に特化した実践ガイド。

**参照ファイル**: [TECH-BLOG-WRITING.md](references/TECH-BLOG-WRITING.md)

カバー範囲: ネタ出し・読者設定、タイトル・見出し設計、構成パターン（Problem-Solution/Tutorial/比較/概念解説）、冒頭・導入の書き方、技術的説明とコード要素、文体、推敲チェックリスト、Web特有ポイント

> Zennプラットフォーム固有のフロントマター・公開フローは `writing-zenn-articles` を参照。

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

### 書く力の基礎強化

文章を書く5つの段階を補完する、実践的な基礎技法リファレンス群。

| ファイル | 内容 |
|---------|------|
| [JAPANESE-PROSE-CRAFT.md](references/JAPANESE-PROSE-CRAFT.md) | 日本語作文技術（修飾語の順序4原則、句読点の二大原則、助詞の使い方、漢字/カナバランス、欠陥文パターン） |
| [CLARITY-WRITING.md](references/CLARITY-WRITING.md) | わかりやすい文章術（一文一義100技法、文章整形術、「極み」の全技術、感情の言語化） |
| [EXPLANATION-TECHNIQUES.md](references/EXPLANATION-TECHNIQUES.md) | 説明・伝達の技法（説明の基本モデル、論理的伝え方、池上彰メソッド、図解技法、技術の伝え方） |
| [NATALIE-METHOD.md](references/NATALIE-METHOD.md) | ナタリー式文章メソッド（完読概念、主眼と骨子、構造シート、多階層重複チェック、速度制御、文章改善テクニック集） |
| [DOCUMENT-ARCHITECTURE.md](references/DOCUMENT-ARCHITECTURE.md) | 文書の構造設計（5要素階層、辞書形式vs読み物形式、認知心理学的基盤） |

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
        +-- 「技術ブログの書き方がわからない」
        |       -> テックブログ -> TECH-BLOG-WRITING.md
        |
        +-- 「日本語の文法・語順がおかしい」
        |       -> 日本語作文技術 -> JAPANESE-PROSE-CRAFT.md
        |
        +-- 「説明がうまく伝わらない」
        |       -> 説明技法 -> EXPLANATION-TECHNIQUES.md
        |
        +-- 「レポートの書き方がわからない」
        |       -> レポート基礎 -> REPORT-STRUCTURE.md, REPORT-THESIS-TYPES.md
        |
        +-- 「論文の論証が弱い」
        |       -> 論理構成の問題 -> ARGUMENTATION-FRAMEWORK.md
        |
        +-- 「実験レポートの書き方」
        |       -> 理系レポート -> EXPERIMENTAL-REPORT.md
        |
        +-- 「設計書の書き方がわからない」
        |       -> 設計書 -> ENGINEERING-DESIGN-DOCS.md
        |
        +-- 「書く前の準備が足りない・構造シートで整理したい」
        |       -> 主眼と骨子・構造シート -> NATALIE-METHOD.md
        |
        +-- 「文書の構造が伝わらない・情報の階層が崩れている」
                -> 文書構造設計 -> DOCUMENT-ARCHITECTURE.md
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
| **writing-latex** | LaTeX文書作成（upLaTeX+dvipdfmx環境、日本語学術文書のコンパイル） |
| **creating-presentations** | プレゼンコンテンツ改善・HTMLスライド生成・Google Slides生成 |

---

## README作成

プロジェクトの README.md を設計・構成・作成するためのガイド。

### Quick Start（最小限テンプレート）

```markdown
# プロジェクト名

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

一言説明（高校生でも理解できるレベルで、専門用語を最小限に）。

## インストール

\`\`\`bash
npm install your-package
\`\`\`

## クイックスタート

\`\`\`bash
your-package --help
\`\`\`

## ドキュメント

詳細ドキュメントは [docs/](docs/) を参照。

## ライセンス

MIT
```

### 対象読者の特定

README作成前に対象読者を決定する。

| 対象 | 主なニーズ | 優先セクション |
|------|-----------|--------------|
| **ユーザー** | インストール・使い方・トラブルシューティング | Getting Started・クイックスタート・リファレンス |
| **開発者** | ローカル環境構築・テスト・アーキテクチャ | セットアップ・テスト・コントリビューション |
| **両方** | 概要・バッジ・ライセンス | プロジェクト概要・コミュニティ |

主要閲覧者の言語でREADMEを書く。OSS国際プロジェクトは英語、社内ツールは日本語が一般的。

### 必須セクション構成

**1. プロジェクト概要（名前 + 説明）**
- H1（`# プロジェクト名`）は文書に1つだけ
- 説明は1〜3文で完結させる。高校生レベルの読みやすさを目指す
- エコシステムでの位置づけ、類似ツールとの差異を明記する

**2. バッジ** — 推奨は3〜5個まで

```markdown
[![npm version](https://img.shields.io/npm/v/your-package.svg)](https://www.npmjs.com/package/your-package)
[![CI](https://github.com/user/repo/actions/workflows/ci.yml/badge.svg)](...)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
```

shields.io 技術スタックバッジフォーマット:
```
https://img.shields.io/badge/-{name}-{color}.svg?logo={logo}&style=for-the-badge
```

**3. インストール・セットアップ**
- 前提条件（Node.js バージョン等）を明記
- コマンドにはコードブロックと言語指定を必ず付ける

**4. クイックスタート / 使い方**
- READMEに複数のチュートリアルを含めない（1つに絞るかリンクにする）
- 最短で動作確認できる例を示す

**5. ドキュメントリンク** — 外部ドキュメントへのリンクをまとめる

**6. 開発者向け情報**
- ローカル環境構築手順。アーキテクチャが長い場合は `ARCHITECTURE.md` に分離してリンク

**7. コミュニティ / コントリビューション**
- バグ報告・機能要望リンク、`CONTRIBUTING.md`、`CODE_OF_CONDUCT.md` へのリンク

**8. ライセンス**
```markdown
## ライセンス

[MIT](LICENSE) © 2024 Your Name
```

### プロジェクトタイプ別の追加推奨

| タイプ | 追加推奨セクション |
|--------|-----------------|
| ライブラリ/パッケージ | 類似ライブラリとの比較表・ブラウザ/Node.jsサポート表・Peer dependencies |
| Webアプリケーション | スクリーンショット/デモURL・環境変数テーブル・デプロイ手順 |
| CLIツール | コマンドリファレンス表（コマンド・操作内容・等価コマンド） |
| OSSプロジェクト | 動的バッジ（スター数等）・GitHub Template機能・引用セクション |

### Markdown書式規範

- H1は文書に1つのみ（プロジェクト名）。見出し階層は4レベル以内（H2〜H4）
- 太字は `**text**`（段落の10%以下）
- リストはハイフン（`-`）で統一
- コードブロックに言語指定を必ず付ける（`\`\`\`bash`, `\`\`\`typescript` 等）
- 全画像に Alt テキスト: `![説明](path/to/image.png)`
- 目次は1000文字未満なら省略可

### 品質チェックリスト（公開前）

- [ ] H1見出しが1つのみ
- [ ] 全リンクが有効（404なし）
- [ ] コードブロックに言語指定がある
- [ ] 全画像にAltテキストがある
- [ ] インストール手順を実際に試した
- [ ] 古いバージョン情報が残っていない
- [ ] モバイル表示で読みやすい（行が長すぎない）

### アンチパターン

| アンチパターン | 改善策 |
|--------------|--------|
| 複数チュートリアルをREADMEに詰め込む | 1つに絞るかdocs/に分離 |
| バッジを10個以上使う | 3〜5個に絞る |
| コードブロックに言語指定なし | 必ず言語を指定 |
| 「このREADMEは随時更新されます」 | 削除。実際に更新する |
| リリースノートをREADMEに書く | CHANGELOG.mdに分離 |

---

## Zenn記事作成

Zenn CLIベースの技術記事リポジトリにおける記事作成・品質管理のワークフロー。

### ファイル仕様

- 形式: `NNN-slug-name.md`（NNN: 3桁の連番、slug: ケバブケース）
- 配置: `articles/` ディレクトリ

### フロントマター（必須）

```yaml
---
title: "記事タイトル"
emoji: "🎯"
type: "tech"           # "tech"（技術記事）または "idea"（アイデア）
topics: ["tag1", "tag2"]  # 英数字小文字、最大5個（5個を目標に埋める）
published: false
---
```

### 本文の書き方

- H2（`##`）から開始。H1は使用しない
- 構成例: 始めに → 本題セクション群 → 終わりに
- prhルールにより「はじめに」「おわりに」はエラー → 漢字表記を使うこと

**Zenn固有のMarkdown記法:**

```markdown
:::message
情報ブロック（注意書き・補足情報）
:::

:::message alert
警告ブロック（重要な注意事項）
:::
```

### ワークフロー

**Step 0: トレンド調査とタイトル設計**

WebFetchで `https://zenn.dev` / `https://zenn.dev/trending` を確認してタイトルを設計する。

| パターン | 例 |
|---------|-----|
| 体験型 | 「〇〇してみた」「〇〇を導入した話」 |
| 数値型 | 「〇〇選」「N個の〇〇」「〇〇を50%削減した方法」 |
| 問題解決型 | 「〇〇で困ったときの対処法」 |
| 逆説・挑発型 | 「〇〇はもう古い」「〇〇をやめた理由」 |
| How-to型 | 「〇〇入門」「〇〇完全ガイド」 |

タイトルのチェック: 具体的か / 検索されそうか / クリックしたくなるか / 内容と一致しているか

**Step 0.5: topicsタグの設計**

`https://zenn.dev/topics/{タグ名}` で記事数を確認し、「大きなプール + ニッチ」戦略で5個を選定する:

| 枠 | 目的 | 例 |
|---|---|---|
| 1-2個 | 記事の中心テーマ | `claudecode`, `nextjs` |
| 1-2個 | 広い発見プール | `ai`, `typescript` |
| 1-2個 | ニッチだが検索意図が一致 | `ccusage`, `tmux` |

**Step 1〜6:**

```bash
# Step 1: 記事番号決定
ls articles/ | sort | tail -1

# Step 2: ファイル作成 (published: false で開始)
# articles/NNN-slug-name.md を作成

# Step 3: 本文執筆（です・ます調、技術用語は英語のまま）

# Step 4: 画像追加（必要に応じて）
mkdir -p images/NNN
# 参照: ![alt text](/images/NNN/filename.png)

# Step 5: 品質チェック
pnpm exec textlint articles/NNN-slug-name.md
pnpm exec markdownlint-cli2 articles/NNN-slug-name.md
pnpm exec textlint --fix articles/NNN-slug-name.md  # 自動修正
pnpm run lint  # 全件Lint

# Step 6: 公開
# published: true に変更 → GitHub push
```

### Lint環境

| ツール | 設定ファイル | 目的 |
|--------|------------|------|
| textlint | `.textlintrc.yml` | 日本語品質チェック |
| markdownlint-cli2 | `.markdownlint-cli2.jsonc` | Markdown形式統一 |
| Prettier | `.prettierrc.yml` | コード・Markdown整形 |
| prh | `prh/` | 表記揺れ検査 |
| cspell | `.cspell.json` | スペルチェック |

**既知のLintルール矛盾への対処:**

1. `ja-space-around-code` と `ja-space-between-half-and-full-width` が競合 → `pnpm exec textlint --fix` を実行すると自動解決
2. prh: 「はじめに」→「始めに」、「おわりに」→「終わりに」

Lintルール間の矛盾（循環エラー等）は **記事内容を言い換えるのではなく Lint 設定側を修正**する。

### 品質チェックリスト

- [ ] タイトルが具体的・検索性が高い・クリックしたくなる
- [ ] ファイル名が `NNN-slug-name.md` 形式
- [ ] フロントマターの5フィールドがすべて記入済み
- [ ] topicsが英数字小文字で5個（「大きなプール + ニッチ」）
- [ ] 見出しが `##` から開始
- [ ] コードブロックに言語指定あり
- [ ] `pnpm run lint` でエラーなし
- [ ] 全角スペースが混入していない
- [ ] Claude Code関連記事の場合、末尾に宣伝セクション（@CCChangelogJA）を追加済み

### 宣伝セクション（Claude Code関連記事のみ）

topicsに `claudecode` / `claude` を含む、またはタイトルに「Claude Code」を含む記事の末尾に追加する:

```markdown
## 宣伝

Claude CodeのCHANGELOGを日本語で随時ポストしているXアカウントを運用しています。アップデート情報をキャッチアップしたければぜひフォローしてください。

👉 [@CCChangelogJA](https://x.com/CCChangelogJA)
```

### 文体ルール

**このリポジトリの統一文体: です・ます調**

- 既存記事はすべてです・ます調で統一。だ・である調に変えない
- AI臭除去と文体変更は別問題。文体を維持しつつAI臭だけを除去する
- 自分の体験を交えた語り口。「〜してみました」「〜になりました」等
- 技術用語はそのまま英語
