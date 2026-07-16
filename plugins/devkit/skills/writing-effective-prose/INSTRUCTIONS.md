# 効果的な文章を書く技術

## 目的

文章の新規作成、要約、翻訳、校閲、レビューを、読者、目的、根拠、媒体に合わせて行う。全テキスト出力に文章完全性チェックを適用する。AI使用の隠蔽や検出器の攻略は目的にしない。

このスキルが扱う領域:

- 文章の準備、構成、執筆、表現、推敲
- 根拠、引用、確度、生成痕跡の監査
- 技術文書、設計書、README、FAQ、技術記事
- 学術文書、大学レポート、論文、実験レポート
- Web文章、UXコピー、説得文書、感性表現

## 入力

- 直接渡された文章
- `.md`、`.txt`、`.tex`などのファイル
- 「書いて」「要約して」「自然にして」「校正して」「レビューして」などの依頼
- 読者、目的、媒体、字数、文体、引用形式などの制約

目的や制約が成果を大きく変え、ローカル資料から判断できない場合だけ確認する。既存文の改善では、意味、確度、用語、話者の声を勝手に変えない。

## 文章完全性チェック

全てのテキスト出力で、次の不変条件を守る。

1. **捏造しない** — 事実、引用、数値、固有名詞、URL、DOI、ISBNを作らない。
2. **出典を越えない** — 資料が実際に支える範囲だけを述べ、少数意見を総意に広げない。
3. **意義を水増ししない** — 「重要」「画期的」「転換点」は、変化と根拠を示せる場合だけ使う。
4. **確度を保つ** — 事実、推論、意見、不明点を分け、情報不足を推測で埋めない。
5. **媒体と話者に合わせる** — 用語、文体、表記、見出し階層、マークアップを出力先にそろえる。
6. **生成痕跡を残さない** — チャット前置き、プレースホルダー、内部ID、引用UI、JSON、追跡パラメータを除く。
7. **構造を目的化しない** — 見出し、3項列挙、箇条書き、表、結論は、読者に機能する場合だけ使う。
8. **検出回避を保証しない** — 品質を具体性、正確性、検証可能性、目的適合で評価する。

emダッシュ、括弧、比喩、太字、絵文字、箇条書き、表、限定表現は一律禁止しない。必要性と効果で判断する。自然さを演出するために語尾や文長を機械的に散らさない。

- 71項目の診断カタログと誤判定防止: [AI-SMELL-PATTERNS.md](references/AI-SMELL-PATTERNS.md)
- 12の恒久原則、常設プロンプト、書き換え手順: [AI-SMELL-REWRITE-RULES.md](references/AI-SMELL-REWRITE-RULES.md)

## 標準ワークフロー

### 1. 準備

読者、目的、読後に期待する行動、制約、必要な根拠を定める。テーマではなく、文章が答える問いを1文にする。

- [PREPARATION.md](references/PREPARATION.md)
- [RESEARCH-QUESTION-DESIGN.md](references/RESEARCH-QUESTION-DESIGN.md)
- [OUTLINE-CONSTRUCTION.md](references/OUTLINE-CONSTRUCTION.md)

### 2. 構成

主張と根拠の関係を決め、1段落1トピックで並べる。テンプレートに内容を合わせず、読者が必要とする順番を選ぶ。

- [LOGICAL-STRUCTURE.md](references/LOGICAL-STRUCTURE.md)
- [ARGUMENTATION-FRAMEWORK.md](references/ARGUMENTATION-FRAMEWORK.md)
- [DOCUMENT-ARCHITECTURE.md](references/DOCUMENT-ARCHITECTURE.md)

### 3. 執筆

一文一義を基本に、主語と述語、修飾先、用語を明確にする。単純な動詞で足りる箇所は飾らない。

- [SENTENCE-CRAFT.md](references/SENTENCE-CRAFT.md)
- [CLARITY-WRITING.md](references/CLARITY-WRITING.md)
- [PROSE-TECHNIQUES.md](references/PROSE-TECHNIQUES.md)
- [JAPANESE-PROSE-CRAFT.md](references/JAPANESE-PROSE-CRAFT.md)

### 4. 表現

簡潔さ、リズム、語彙、比喩を文書の目的に合わせる。限定表現は、根拠の確度に必要なら残す。

- [EXPRESSION-STYLE.md](references/EXPRESSION-STYLE.md)
- [PRACTICAL-PATTERNS.md](references/PRACTICAL-PATTERNS.md)
- [EXPLANATION-TECHNIQUES.md](references/EXPLANATION-TECHNIQUES.md)

### 5. 推敲

事実と出典、主張と論理、語彙と文、構造と媒体、話者の声の順に分けて読む。修正後は、意味や確度が変わっていないか再確認する。

- [REVISION-CHECKLIST.md](references/REVISION-CHECKLIST.md)
- [ANTI-PATTERNS.md](references/ANTI-PATTERNS.md)
- [WRITING-PITFALLS.md](references/WRITING-PITFALLS.md)
- [NO-REVISION-PATTERNS.md](references/NO-REVISION-PATTERNS.md)

## 目的別リファレンス

必要な領域だけを読む。同じ内容を複数ファイルから重ねて読み込まない。

### 技術文書・開発者向け文書

| リファレンス | 用途 |
|-------------|------|
| [TECHNICAL-WRITING.md](references/TECHNICAL-WRITING.md) | 7Cs、README、API仕様、基本的な技術文書 |
| [TECHNICAL-WRITING-ADVANCED.md](references/TECHNICAL-WRITING-ADVANCED.md) | 高度な技術説明、情報設計、レビュー |
| [TECHNICAL-DOCS-PRINCIPLES.md](references/TECHNICAL-DOCS-PRINCIPLES.md) | 技術文書の品質原則 |
| [TECHNICAL-DOCS-STRUCTURE.md](references/TECHNICAL-DOCS-STRUCTURE.md) | 文書構造とセクション設計 |
| [TECHNICAL-DOCS-REPORTS.md](references/TECHNICAL-DOCS-REPORTS.md) | 状況報告、障害報告、調査報告 |
| [TECHNICAL-DOCS-ANTI-PATTERNS.md](references/TECHNICAL-DOCS-ANTI-PATTERNS.md) | 技術文書固有の失敗例 |
| [ENGINEERING-DESIGN-DOCS.md](references/ENGINEERING-DESIGN-DOCS.md) | 要件、設計、代替案、トレードオフ |
| [REPORT-STRUCTURE.md](references/REPORT-STRUCTURE.md) | 一般報告書の構成 |
| [FAQ-WRITING.md](references/FAQ-WRITING.md) | FAQとヘルプ文書 |
| [README-WRITING.md](references/README-WRITING.md) | READMEの構成、テンプレート、公開前確認 |

### 学術文書・大学レポート

| リファレンス | 用途 |
|-------------|------|
| [SCHOLARLY-WRITING-RULES.md](references/SCHOLARLY-WRITING-RULES.md) | 学術文体、確度、簡潔さ |
| [SCIENTIFIC-WRITING.md](references/SCIENTIFIC-WRITING.md) | 科学技術文書、測定と解釈の分離 |
| [REPORT-THESIS-TYPES.md](references/REPORT-THESIS-TYPES.md) | 文書種別の選択 |
| [EXPERIMENTAL-REPORT.md](references/EXPERIMENTAL-REPORT.md) | 理系実験レポート |
| [CITATION-FORMAT.md](references/CITATION-FORMAT.md) | 引用と参考文献の形式 |
| [PLAGIARISM-PREVENTION.md](references/PLAGIARISM-PREVENTION.md) | 剽窃防止とパラフレーズ |
| [THESIS-WRITING-PROCESS.md](references/THESIS-WRITING-PROCESS.md) | 卒論・論文の計画と執筆 |
| [THESIS-EVALUATION.md](references/THESIS-EVALUATION.md) | 提出前評価 |
| [ACADEMIC-WRITING-PROCESS.md](references/ACADEMIC-WRITING-PROCESS.md) | 英語学術文書の全体工程 |
| [ACADEMIC-ACADEMIC-STYLE.md](references/ACADEMIC-ACADEMIC-STYLE.md) | 英語学術文体 |
| [ACADEMIC-COHERENCE-ARGUMENTS.md](references/ACADEMIC-COHERENCE-ARGUMENTS.md) | 段落の一貫性と論証 |
| [ACADEMIC-CRITICAL-RESEARCH.md](references/ACADEMIC-CRITICAL-RESEARCH.md) | 批判的な資料調査 |
| [ACADEMIC-CRITIQUING-TEXTS.md](references/ACADEMIC-CRITIQUING-TEXTS.md) | 文献批評 |
| [ACADEMIC-INCORPORATING-THEORIES.md](references/ACADEMIC-INCORPORATING-THEORIES.md) | 理論やモデルの統合 |
| [ACADEMIC-REFERENCING-SOURCES.md](references/ACADEMIC-REFERENCING-SOURCES.md) | 英語文献の参照 |
| [ACADEMIC-REFLECTIVE-WRITING.md](references/ACADEMIC-REFLECTIVE-WRITING.md) | リフレクティブライティング |
| [ACADEMIC-DISSERTATION-WRITING.md](references/ACADEMIC-DISSERTATION-WRITING.md) | Dissertationの章構成 |
| [ACADEMIC-SUBMISSION-PREPARATION.md](references/ACADEMIC-SUBMISSION-PREPARATION.md) | 提出前準備 |
| [ACADEMIC-AI-RESEARCH.md](references/ACADEMIC-AI-RESEARCH.md) | AI支援を使う資料調査 |
| [ACADEMIC-AI-WRITING.md](references/ACADEMIC-AI-WRITING.md) | AI支援を使う執筆と検証 |
| [ACADEMIC-AI-DATA-ANALYSIS.md](references/ACADEMIC-AI-DATA-ANALYSIS.md) | データ分析支援 |
| [ACADEMIC-AI-PRESENTATIONS.md](references/ACADEMIC-AI-PRESENTATIONS.md) | 学術発表支援 |
| [ACADEMIC-AI-PRACTICAL-TIPS.md](references/ACADEMIC-AI-PRACTICAL-TIPS.md) | 実務上のAI活用 |
| [ACADEMIC-AI-ETHICS.md](references/ACADEMIC-AI-ETHICS.md) | 開示、責任、研究倫理 |

### Web・記事・ビジネス・感性表現

| リファレンス | 用途 |
|-------------|------|
| [WEB-DIGITAL-WRITING.md](references/WEB-DIGITAL-WRITING.md) | Web文章と読み手中心設計 |
| [WEB-EDITORIAL-METHOD.md](references/WEB-EDITORIAL-METHOD.md) | Web編集、主眼と骨子 |
| [TECH-BLOG-WRITING.md](references/TECH-BLOG-WRITING.md) | 技術ブログの企画、執筆、推敲 |
| [ZENN-PUBLISHING.md](references/ZENN-PUBLISHING.md) | Zennのフロントマター、Lint、公開手順 |
| [UX-COPYWRITING.md](references/UX-COPYWRITING.md) | UI文言、エラー、マイクロコピー |
| [PERSUASIVE-WRITING.md](references/PERSUASIVE-WRITING.md) | 説得と行動喚起 |
| [WRITING-MINDSET-CAREER.md](references/WRITING-MINDSET-CAREER.md) | 執筆習慣とキャリア |
| [SENSORY-CRAFT.md](references/SENSORY-CRAFT.md) | 五感、固有の経験、比喩 |

## 入力形式への対応

| 入力 | 処理 |
|------|------|
| テキスト | 目的と制約を確認し、直接作成または改善する |
| `.md` / `.txt` | 構造、リンク、記法を含めて確認する |
| `.tex` | 内容面は本スキル、組版とコンパイルは `studio:writing-latex` を使う |
| `.docx` | 文書操作には `documents:documents` を使う |
| `.pptx` / スライド | 内容面は本スキル、デッキ操作には presentation系スキルを使う |
| URLや外部資料 | 一次資料を確認し、引用範囲と更新日を照合する |

## 診断フロー

1. 依頼の種類を、作成、改善、校正、レビュー、変換に分ける。
2. 読者、目的、媒体、文体、字数、引用形式を確認する。
3. 事実と出典を先に検証する。確認できない内容を表現の工夫で隠さない。
4. 主張と根拠、段落順、重複、欠落を直す。
5. 文、用語、リズム、確度を整える。
6. マークアップ、リンク、見出し、プレースホルダー、生成痕跡を確認する。
7. 元文と照合し、意味、確度、話者の声が保たれていることを確認する。

## 出力契約

- 文章成果物では、依頼された本文と形式を優先する。
- レビュー、監査、作業更新、完了報告、エラー説明では、所定の報告形式、根拠、検証結果、制約、残件を省略しない。
- 不要な社交辞令、作業実況、追加提案は成果物本文へ混ぜない。
- 変更理由を求められた場合は、元文、問題、修正、効果を対応させて説明する。
- AI使用の断定、人間執筆の偽装、検出器通過の保証をしない。

## 最終チェックリスト

- [ ] 読者、目的、媒体、文体に合っている
- [ ] 一段落一主張で、主張と根拠が対応している
- [ ] 事実、推論、意見、不明点を混同していない
- [ ] 事実、引用、数値、リンク、識別子を捏造していない
- [ ] 各出典が該当する主張を支えている
- [ ] 根拠のない意義、合意、将来予測を加えていない
- [ ] 同一概念の用語と表記が一貫している
- [ ] 限定表現の確度を勝手に強めたり弱めたりしていない
- [ ] 見出し、箇条書き、表、装飾を必要性で選んでいる
- [ ] 出力先のマークアップと見出し階層が正しい
- [ ] チャット前置き、プレースホルダー、内部ID、引用UIが残っていない
- [ ] 元の意味と話者の声を保っている

## 関連スキル

| スキル | 使い分け |
|--------|---------|
| `studio:writing-latex` | LaTeX組版、コンパイル、PDF確認 |
| `documents:documents` | Word文書の作成、編集、校閲 |
| `studio:creating-slides` | HTMLスライドの生成 |
| `presentations:Presentations` | PowerPointやGoogle Slidesの操作 |
| `studio:creating-content` | マーケティングコピーやコンテンツ企画 |
