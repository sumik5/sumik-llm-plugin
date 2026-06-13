# WORKFLOW-SCRIPT: 問ごと並列求解の Workflow テンプレート

このファイルは `answering-genai-exam` スキルの **Workflow 並列求解パス**（Claude Code・第一推奨）で本体が使うスクリプト雛形・`args` 仕様・求解契約を集約する。INSTRUCTIONS.md の Step 3 から参照される。

> **前提（崩してはいけない掟）**: Workflow の各 agent も background 実行のため **AskUserQuestion を使えない**。曖昧点は本体が Step 2 で解消済みであること。Workflow の標準 agent は **スキルを preload しない**ため、求解契約（§3）をプロンプトに全文埋め込んで自己完結させる。

---

## 1. なぜ Workflow か（background-Agent 手動起動との違い）

| 観点 | Workflow（推奨） | background-Agent 手動起動（代替） |
|------|-----------------|-------------------------------|
| ファンアウト | `parallel()` で画像配列を一斉起動 | 画像ごとに `Agent(run_in_background: true)` を手動発行 |
| 完了監視 | スクリプトが自動 await・集約 | 本体が各 agent の完了を手動待機 |
| 進捗可視化 | `/workflows` でライブ表示 | 個別 task 通知のみ |
| 結果集約 | `schema` で構造化値を直接受領 | 各報告テキストを本体が手動パース |
| 失敗時 | journal resume で求解済み以外だけ再実行 | 落ちた agent を本体が手動再起動 |

> **opt-in の根拠**: Workflow ツールは無断起動禁止だが、本スキルの指示が Workflow 呼び出しを命じることが正当な opt-in 経路（スキル/コマンドの指示による起動は許可される）。

---

## 2. `args` の形（本体が Step 1・Step 2 の成果を詰める）

本体は Step 1（抽出）と Step 2（AskUserQuestion 確定）の結果を、以下の JSON 値として Workflow の `args` に渡す。**文字列化せず実 JSON 値として渡す**（配列/オブジェクトのまま）。

```jsonc
{
  "approach": "確定方針テキスト（試験分野・到達レベル・解答方針・既存answers上書き可否を1ブロックに集約）",
  "questions": [
    {
      "q": "問一",
      "outputDir": "/abs/path/to/exam/answers/問一",
      "memo": "[問一] SECTION xx / テーマ: ...\n状況設定: ...\n回答指示: ...\n小問:\n  (1) <タイトル> / 指示: ... / 提出物: q1_1.md\n  (2) <タイトル> / 指示: ... / 提出物: q1_2.png"
    },
    { "q": "問二", "outputDir": "/abs/.../answers/問二", "memo": "..." }
  ]
}
```

- `approach`: Step 2 で確定した全方針を1テキストに集約（各 agent 共通）。
- `questions[].q`: 問番号（`問一` 等）。読めなければ `問<連番>`。
- `questions[].outputDir`: **絶対パス**で `<入力画像dir>/answers/<問番号>`。
- `questions[].memo`: Step 1 で抽出したその大問1つ分の構造化メモ（小問リスト・提出物名含む）。

> 求解契約（§3）は全 agent 共通なのでスクリプト内の定数に持つ（`args` に重複させない）。

> 🔴 **型ガード必須**: `args` は「実 JSON 値で渡せ」が建前だが、実行環境によっては **JSON 文字列で届く**（検証で確認済み・ガード無しだと `questions.map` で即死）。雛形（§4）冒頭で `const input = typeof args === 'string' ? JSON.parse(args) : args` を必ず通すこと。

---

## 3. 求解契約（agent プロンプトに全文埋め込む・自己完結用）

Workflow の標準 agent はスキル未 preload。以下を各 agent プロンプトに埋め込み、画像なしテキストだけで求解を完結させる。`exam-solver.md` / `OUTPUT-FORMAT.md` の凝縮版。

```text
あなたは生成AI活用試験の「1大問（1画像分）」を解く担当です。渡された情報だけで完結させ、
成果物を Write ツールでファイルとして保存してください。画像は読みません（テキストのみで求解）。

【各小問につき2成果物を生成】
1. 対話の要点: 答えに至る思考過程を「自分: ○○ → AI: ○○ → 自分: ○○ → AI: ○○ → …」形式で再構成。
   最大1000文字（厳守・超過は要約）。末尾に（XX/1000字）を付記。実ログ転記でなく模範対話の再構成。
   「自分」＝提問・追及・検証・要約要求／「AI」＝回答・定義・例示・反証・整理。結論は提出物本体と一致させる。
2. 提出物: 提出物名の拡張子で種類を決める（拡張子分岐）。

【拡張子分岐】
- .md            → markdown 回答本文（結論先行PREP・見出し/表/箇条書き）。ファイル名は提出物名そのまま（q1_1.md）
- 画像系(.png/.jpg/.jpeg/.gif/.svg/.webp) → 画像生成AIへのテキスト指示。ファイル名は <basename>_画像生成指示.md
  （冒頭に「対象提出物: q1_2.png」を明記。描画要素・配置・矢印/線・ラベル・スタイル・制約反映の6要素を自然言語で詳述。
   「手描き指定・画像生成AI不可」の図でも指示文として出す＝人/別AIが再現できる設計図）
- コード系(.py/.ts/.js/.tsx/.sql/.ipynb/.go/.java 等) → 動作する完全なソースコード（コメント付き）。ファイル名は提出物名そのまま
- データ系(.csv/.json/.yaml/.yml/.tsv) → 該当形式の妥当なデータ。ファイル名は提出物名そのまま
- 不明/読み取り不可 → AskUserQuestion は使えないので自己判断（best-effort）し、採用した解釈を結果に明記

【出力先・ファイル名】
- 出力先は指定の outputDir（絶対パス）。Write は親ディレクトリを自動生成する。
- 対話の要点は全小問 <basename>_対話の要点.md。提出物は上記拡張子分岐に従う。

【禁止事項】
- 特定の試験ブランド名・主催団体名・書籍名・著者名・出版社名を成果物に一切含めない（汎用記述に置換）。
- git 書込・ブランチ操作は行わない。
```

---

## 4. スクリプト雛形

本体は以下を Workflow の `script` に渡し、§2 の値を `args` に渡す（`agentType` は指定しない＝標準 agent で求解契約を埋め込む方式。`agentType` 解決失敗はワークフロー全体を落とすため使わない）。

```javascript
export const meta = {
  name: 'solve-genai-exam',
  description: '生成AI活用試験の各大問(画像)を並列に求解し answers/<問番号>/ へ出力する',
  phases: [
    { title: 'Solve', detail: '画像(大問)ごとに1 agentで並列求解しファイル出力' },
  ],
}

// 求解契約（§3 を1定数に固定。全 agent 共通）
const CONTRACT = `あなたは生成AI活用試験の「1大問（1画像分）」を解く担当です。渡された情報だけで完結させ、
成果物を Write ツールでファイルとして保存してください。画像は読みません（テキストのみで求解）。

【各小問につき2成果物を生成】
1. 対話の要点:「自分: ○○ → AI: ○○ → …」形式で答えに至る思考過程を再構成。最大1000文字（厳守・超過は要約）。
   末尾に（XX/1000字）を付記。模範対話の再構成。結論は提出物本体と一致させる。
2. 提出物: 提出物名の拡張子で種類を決める。

【拡張子分岐】
- .md → markdown回答本文（結論先行・見出し/表/箇条書き）。ファイル名=提出物名そのまま
- 画像系(.png/.jpg/.jpeg/.gif/.svg/.webp) → 画像生成AIへのテキスト指示。ファイル名=<basename>_画像生成指示.md
  （冒頭に対象提出物名を明記。描画要素・配置・矢印/線・ラベル・スタイル・制約反映の6要素を自然言語で詳述）
- コード系(.py/.ts/.js/.tsx/.sql/.ipynb 等) → 動作する完全なコード（コメント付き）。ファイル名=提出物名そのまま
- データ系(.csv/.json/.yaml/.yml/.tsv) → 妥当なデータ。ファイル名=提出物名そのまま
- 不明 → 自己判断（best-effort）し採用した解釈を結果に明記

【出力先】指定 outputDir（絶対パス）。Write は親ディレクトリを自動生成。対話の要点は全小問 <basename>_対話の要点.md。
【禁止】特定試験ブランド名・主催団体名・書籍名・著者名・出版社名を一切含めない。git書込・ブランチ操作をしない。`

const RESULT_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['question', 'subQuestionsSolved', 'files', 'charCounts', 'selfJudged'],
  properties: {
    question: { type: 'string', description: '問番号（問一 等）' },
    subQuestionsSolved: { type: 'integer', description: '求解した小問数' },
    files: { type: 'array', items: { type: 'string' }, description: '出力した絶対パス一覧' },
    charCounts: { type: 'array', items: { type: 'string' }, description: '各対話要点の文字数（例 "(1) 842/1000"）' },
    selfJudged: { type: 'array', items: { type: 'string' }, description: '自己判断した不明点と採用した解釈' },
  },
}

// 🔴 args は実 JSON 値で届く想定だが、実行環境によっては JSON 文字列で届くため必ず型ガードする
//    （ガード無しだと args.questions が undefined となり questions.map で即死する＝検証で確認済み）
const input = typeof args === 'string' ? JSON.parse(args) : args
const approach = input.approach
const questions = input.questions

phase('Solve')
const results = await parallel(questions.map((qq) => () =>
  agent(
    `${CONTRACT}\n\n` +
    `## 問番号\n${qq.q}\n\n` +
    `## 出力先（絶対パス）\n${qq.outputDir}\n\n` +
    `## 確定方針（本体がユーザー確認済み）\n${approach}\n\n` +
    `## 問題抽出メモ（この大問1つ分）\n${qq.memo}\n\n` +
    `全小問について対話の要点と提出物を生成し Write で保存後、構造化結果を返してください。`,
    { label: `solve:${qq.q}`, phase: 'Solve', schema: RESULT_SCHEMA }
  )
))

return { solved: results.filter(Boolean) }
```

---

## 5. 本体側の呼び出しと集約

1. Step 1・Step 2 完了後、§2 の `args` を組み立てる。
2. `Workflow({ script: <§4 の雛形>, args: <§2 の値> })` を呼ぶ（バックグラウンド実行・完了時に通知）。
3. 返却 `{ solved: [...] }` を受け取り、Step 5 の報告に使う:
   - 生成ファイル一覧（各 `files`）
   - 各小問の対話要点 文字数（`charCounts`）が ≤1000 か最終確認
   - 各 agent の `selfJudged`（自己判断した不明点）を集約しユーザーへ提示
4. 一部の問が `null`（agent 死亡・skip）なら、その問番号だけ background-Agent 代替 or 逐次で再求解する。

> **resume**: スクリプト編集なしで再実行すれば、求解済みの問は journal キャッシュで即返り、未完の問だけ再実行される（`Workflow({ scriptPath, resumeFromRunId })`）。
