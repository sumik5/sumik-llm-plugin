---
description: >-
  Unified writing craft guide: prose fundamentals, AI smell detection (always active), technical docs (7Cs),
  academic writing (Harvard, dissertation), and revision techniques.
  REQUIRED for all text output — AI smell check is always active regardless of document type.
  Use when writing, reviewing, proofreading, or creating any document (technical docs, reports, slides,
  emails, academic papers, essays, dissertations, business documents).
  Covers: general prose craft (logical structure, sentence techniques, expression style, revision),
  technical documentation (7Cs, README, API specs, reports), academic writing (Harvard referencing,
  PEEL method, dissertation structure, AI-assisted workflows), and AI text refinement (6 smell patterns,
  rewrite rules). For Zenn articles, use writing-zenn-articles instead.
  For LaTeX document compilation, use writing-latex instead.
---

# 効果的な文章を書く技術

## Overview

このスキルは、あらゆる文章に適用できる**統合ライティングガイド**です。4つの軸で文章の品質を高めます:

1. **普遍的ライティング原則** -- 論理構成、文レベルの技術、表現スタイル、推敲プロセス
2. **AI臭の検出と除去** -- 全出力で常時適用。不自然な表現パターンを検出し、人間らしい文章に書き換える
3. **技術文書の作法** -- 7Csの原則、README、API仕様書、報告書テンプレート
4. **学術文書の作法** -- 論文構造、Harvard参照、批判的思考、Dissertation、AI活用

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

**よくある失敗**: テーマだけ決めて書き始め、途中で「何が言いたいのかわからない」状態になる。書く前に「この文章を読んだ人に何をしてほしいか」を1行で書いてから始める。

### 段階2: 構成 -- 論理の骨格を作る

全体構造（総論→各論→結論）、パラグラフ設計（1パラ=1トピック）、MECE分解、So What?/Why So?の往復で論理的な骨格を作る。

**2つの論理パターン**:
- **並列型**: 複数の根拠をMECEに並べる
- **解説型**: 要約文を詳しく説明していく

### 段階3: 執筆 -- 一文一義で書く

1文=1ポイント（50〜100字目安）。修飾語は被修飾語の近くに置く。接続助詞「が」を避け、明確な接続詞に置き換える。

### 段階4: 表現 -- 削ぎ落として磨く

冗長表現の除去、具体的な記述（数値・before/after）、リズムの調整。

| 冗長な表現 | 簡潔な表現 |
|-----------|-----------|
| 〜することができる | 〜できる |
| 〜に関する検討を行った | 〜を検討した |
| 〜というふうに考えられる | 〜と考えられる |

### 段階5: 推敲 -- 客観的に読み直す

パラグラフの要約文だけを繋げて意味が通るか確認する。批判的態度で読み、誤字・脱字・論理の欠落を発見する。声に出して読み、つかえる箇所を直す。

---

## Quick Reference: 文章の基本原則

### 思考・設計

| 原則 | 要点 |
|------|------|
| **7つの要件を確認する** | 意見・望む結果・論点・読み手・自分の立場・論拠・根本思想を書く前に整理する |
| **「問い」を立てて意見を引き出す** | 「〇〇について書く」ではなく「〇〇はなぜ△△なのか？」と問い直す |
| **読み手のメンタルモデルに配慮する** | 読み手が既に知っていることを起点に、未知の情報へ展開する |

### 構成・論理

| 原則 | 要点 |
|------|------|
| **冒頭に重要情報をまとめる** | 総論→各論→結論の流れで、結論を最初に示す |
| **1パラグラフ = 1トピック** | 冒頭の要約文で主張を明示し、以降の文で補足する |
| **So What?/Why So?を往復する** | 「だから何？」「なぜそう言える？」の問いで論理の穴を塞ぐ |

### 文・表現

| 原則 | 要点 |
|------|------|
| **1文 = 1ポイント（50〜100字目安）** | 複数の主張を1文に詰め込まない |
| **修飾語は被修飾語の近くに置く** | 長い修飾節は前に、短い修飾語は後ろに配置する |
| **簡潔に書く** | 「〜することが重要です」→「〜が重要だ」のように削ぎ落とす |
| **具体的に書く** | 変化のbefore/after、数値、「誰が何をどうする」を明示する |

### 推敲

| 原則 | 要点 |
|------|------|
| **要約文だけ読んで意味が通るか確認** | 各パラグラフの冒頭文を繋げて読み、論旨が伝わるかチェックする |
| **声に出して読む** | 違和感のある箇所は必ず問題がある |

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
  2. 学術文書（論文、エッセイ、レポート、Dissertation）
  3. ビジネス・一般文書（メール、企画書、スライド）
  4. 校正・レビュー（既存文書の改善）

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

### 学術文書

5つの柱に基づいて学術文書を作成する。

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

### ビジネス・一般文書

説得・依頼・謝罪・議事録・メール・企画書など、実務で頻出するパターン。

**参照ファイル**: [PRACTICAL-PATTERNS.md](references/PRACTICAL-PATTERNS.md)

カバー範囲: 上司を説得する文章、依頼文、議事録、お詫び文、志望理由書、メール、報告書・提案書、企画書

---

### 校正・レビュー

既存文書の品質改善を行う場合のガイド。

**参照ファイル**:
- [REVISION-CHECKLIST.md](references/REVISION-CHECKLIST.md) -- 推敲の4アプローチと体系的チェック
- [ANTI-PATTERNS.md](references/ANTI-PATTERNS.md) -- よくある悪文パターンと修正法

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
                -> 校正の問題 -> REVISION-CHECKLIST.md
```

---

## 統合チェックリスト

### 構成・論理

- [ ] 文章の目的と読み手が明確になっている
- [ ] 冒頭で主張・結論が示されている
- [ ] 各パラグラフの冒頭文だけを繋げても意味が通る
- [ ] 並列情報はMECEに整理され、表現がパラレルになっている

### 文・表現

- [ ] 1文が長すぎない（目安50〜100字）
- [ ] 修飾語が被修飾語の近くにある
- [ ] 冗長表現を削っている
- [ ] 抽象的な表現に具体的な数値・事例が伴っている

### 表記・校正

- [ ] 表記揺れがない
- [ ] 誤字・脱字がない
- [ ] 漢字とひらがなのバランスが読みやすい

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
