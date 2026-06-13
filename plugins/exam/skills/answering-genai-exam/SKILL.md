---
name: answering-genai-exam
disable-model-invocation: false
user-invocable: true
description: >-
  生成AI活用試験の問題画像（左=問題文・右=回答欄の見開きスクリーンショット）を読み取り、各小問について「対話の要点」（自分: ○○ → AI: ○○ → … 形式・最大1000字）と提出物（拡張子で分岐: .md=markdown回答本文 / 画像系=画像生成AIへのテキスト指示 / コード系=ソースコード）を生成し、入力画像と同じディレクトリの answers/<問番号>/ 配下にファイルとして保存する。
  Use when 生成AI活用試験・資格試験の問題スクリーンショット（ローカル画像パス・複数可）を渡され、各小問の対話の要点と回答提出物を一括作成して保存したいとき。「この試験問題を解いて」「対話の要点と提出物を作って」等の依頼が該当する。
  複数画像は Workflow で問ごとに並列求解する（第一推奨）。Workflow 不可時は exam-solver agent を画像ごとに background 並列起動する代替経路、単一エージェント環境（agent も Workflow も不可）では逐次処理にフォールバックする。曖昧点（試験分野・提出物形式・解答方針・既存answers上書き）は並列起動前に AskUserQuestion で必ず一括解消する。詳細手順は INSTRUCTIONS.md、Workflow 雛形は references/WORKFLOW-SCRIPT.md、出力規約は references/OUTPUT-FORMAT.md、出力サンプルは assets/answer-template.md を参照。
---

詳細な手順・ガイドラインは `INSTRUCTIONS.md` を参照してください。

## サブファイル一覧

| ファイル | 内容 |
|---------|------|
| `INSTRUCTIONS.md` | 解答生成ワークフロー本文（Step 0〜5・AskUserQuestion 集約・経路A=Workflow/経路B=background-Agent/経路C=逐次の振り分け） |
| `references/WORKFLOW-SCRIPT.md` | Workflow 並列求解パス（第一推奨）のスクリプト雛形・`args` 仕様・埋め込む求解契約・本体側の集約手順 |
| `references/OUTPUT-FORMAT.md` | 出力ファイル名規則・拡張子分岐の詳細表・対話要点テンプレート・画像生成指示文の書き方ガイド |
| `assets/answer-template.md` | 1大問分（小問複数）の出力サンプル（穴埋めテンプレート） |
