# LEARNINGS — sumik-claude-plugin

作業中に得た非自明な学び・調査結果の記録（capturing-learnings 形式）。

## [LRN-20260806-001] Codexプランレビューループは「参照追加」レベルの計画でも実行可能性の穴を6回反復で炙り出す

- **Recurrence-Count**: 1
- **状況**: docs/plan-add-anydoc-skill.md（anydoc活用スキル新設計画）のCodexプランレビューを6回実施。v1は「既存スキルから参照させる」という軽量な統合方針だったが、Codexは毎回「注記を追加しただけで実際にPlannerの実行コマンドへ到達しない」という核心を突き、以下を段階的に要求した: (1) 入力判定表とPlanner起動プロンプト本体〈JSON文字列内〉の両方を更新しないと実行分岐が成立しない (2) Node.jsバージョンpreflightは判定するだけでなく実際に分岐制御（fallback/停止）する必要がある (3) フォルダ入力・複数ファイル入力時の出力ファイル名は単純な文字置換（`/`→`_`）では衝突する具体例が必ず存在する (4) 外部ツールのバージョン・commit SHAは`<version>`のようなプレースホルダのままでは「固定した」と認められない (5) 環境のpandocバイナリが実際にどの拡張子を読めるか（`pandoc --list-input-formats`）を確認しないと既存ツールとの使い分け表が不正確になる。
- **Why**: 「既存スキルに新しい外部ツールを参照させる」という一見軽量な計画でも、Plannerがbackground実行である・AskUserQuestionが使えない・入力判定と実行コマンドが別ファイル/別セクションに分散している、といったこのリポジトリ特有の構造により、参照を1文追加するだけでは絵に描いた餅になる。
- **How to apply**: 同種の計画（既存ワークフローへの新規変換ツール等の統合）では、最初から「入力判定表→Planner起動プロンプト本体（実際のコマンド文字列）→変換コマンドリファレンス→結果検証→失敗時の通知経路」の全経路を対象拡張子ごとに洗い出し、実行可能な疑似コード（Node preflightならif分岐の中身まで、出力名規則なら衝突しない具体的な命名規則まで）を計画に書いてからレビューに出す。Codexレビューは「本質的でない指摘は無視してよい」运用だが、実行可能性に関する指摘はほぼ全て本質的であり無視できない。
- 関連: [[reference_background_agent_message_lag]]

## [LRN-20260806-002] codex-companion.mjs の `task --resume-last`/`--resume` ジョブはプロセスクラッシュ後も job status が `running` のまま停滞することがある

- **Recurrence-Count**: 1
- **状況**: `codex-companion.mjs task ... --resume-last --wait` で計画書の再レビューを実行した際、`status --all --json` で確認した`pid`が既に存在しない（`ps -p <pid>`が空）にもかかわらず、job の `status` は10分以上 `running` のまま更新されなかった。
- **Why**: resume系のジョブでスレッド復元やターン処理中に何らかの理由でプロセスが異常終了した場合、ジョブマネージャ側の状態更新が追従しないケースがある（原因はランタイム側の異常終了検知漏れと推測されるが未確定）。
- **How to apply**: `status` の `pid` を `ps -p <pid>` で生存確認する。プロセスが既に存在しないのに `status: running` が続き `updatedAt` が更新されないなら、`cancel <job-id>` で明示的に終了させてから、同じスレッドへの `--resume` ではなく `--fresh` で新規スレッドとして再実行する（計画書自体にレビュー履歴を自己完結的に記録しておけば `--fresh` でも文脈は再構築できる）。
- 関連: [[reference_background_task_dies_across_session]]

## [LRN-20260806-003] このリポジトリの pandoc バイナリは実際には csv/xlsx/pptx を読める（対応形式表の記述が古い可能性）

- **Recurrence-Count**: 1
- **状況**: `plugins/devkit/skills/authoring-plugins/references/CONVERTING.md` の「対応形式」表は pandoc の対応形式として EPUB/DOCX/ODT/RST/LaTeX/HTML/Org/AsciiDoc/RTF/PPTX を列挙し csv/xlsx への言及がない。しかし実機で `pandoc --list-input-formats`（pandoc 3.10.1）を実行すると `csv`/`pptx`/`xlsx` が実際に含まれていた（pandoc 公式リリースノートでも3.8.3でXLSX/PPTX readerが追加されたと記録されている）。
- **Why**: CONVERTING.md 作成時点の pandoc バージョンでは対応していなかった可能性が高く、pandoc 側のアップデートに追従していない（陳腐化）。
- **How to apply**: 外部CLIツールの対応フォーマットをドキュメントに列挙する際は、記述だけでなく `<tool> --list-input-formats` 等のコマンドで実機の実対応状況を確認する。今回は anydoc 追加計画の一環で CONVERTING.md の対応形式表に csv/xlsx/pptx の pandoc対応を追記する設計変更を計画に含めた（docs/plan-add-anydoc-skill.md 1.5節）が、CONVERTING.md 本体側の表記自体の陳腐化是正は別タスクとして残っている。

