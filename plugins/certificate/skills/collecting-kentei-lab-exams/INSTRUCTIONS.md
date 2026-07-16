# kentei-lab 問題収集ワークフロー

## 1. このスキルは何か / いつ使うか

kentei-lab.com は認証不要・全問無料公開の資格・検定問題集サイト（147 資格・58,950 問収録・教育目的）。
このスキルは、指定された資格の URL から**その資格の全問題**（問題文・選択肢・正解・解説）を巡回取得し、
1 資格 1 Markdown ファイルへ保存する。

対応する入力 URL の形式（いずれでも可）:

- `https://kentei-lab.com/exams/<slug>`（概要ページ）
- `https://kentei-lab.com/exams/<slug>/start`（開始ページ）
- `https://kentei-lab.com/quiz/<slug>/<n>`（問題ページ）

## 2. 人間の導線と実装方式

人間の操作は、概要ページの「問題を解く →」ボタン → 開始ページの「全問題を始める N問」ボタン → 問題ページを
1 問ずつ進める、という順序を辿る。

本スキルの実装（`scripts/collect-kentei-lab.sh`）は、この操作を模倣せず、**同じ問題集合を
`/quiz/<slug>/<n>`（n=1..N）への直接 URL 遷移で決定的に取得する**。これは以下のサイト特性を利用している。

- `/quiz/<slug>/<n>` は認証・セッション状態に関わらず直接アクセスでき、**同一 n は常に同一問題**を返す
  （ランダム出題設定の影響は問題の「提示順序」のみで、URL→問題内容の対応は固定）
- 問題ページで任意の選択肢ボタンを 1 つクリックすると、追加のネットワークリクエストなしに
  正誤・正解・解説がクライアント側で開示される。不正解を選んでも「正解は …」の行に正答が出るため、
  **正解を当てるロジックは不要**で、1 つ押して開示するだけでよい

したがって「全問題を始める」ボタンや「次の問題へ」リンクを一切クリックせず、n を 1 から N まで単純に
ループするだけで、全問題を確定的・再開可能に収集できる。

## 3. 前提ツール

- **agent-browser**（Vercel Labs 製・Rust ネイティブ・CDP 直結のブラウザ自動化 CLI）。未導入なら
  `web:automating-browser` スキルの `scripts/install.sh` で導入する（内部で `agent-browser install` を実行し
  Chrome for Testing を取得する。これは省略できない）。
- **jq**（JSON 整形・検証）。

導入確認:

```bash
which agent-browser && agent-browser --version
which jq
```

## 4. 実行方法

```bash
scripts/collect-kentei-lab.sh <input-url> [output-dir]
```

| 引数/環境変数 | 説明 |
|---|---|
| `<input-url>`（必須） | kentei-lab の URL（`/exams/<slug>` ・ `/exams/<slug>/start` ・ `/quiz/<slug>/<n>` のいずれか） |
| `[output-dir]`（任意） | 出力先ディレクトリ。省略時 `./kentei-lab-output` |
| `KENTEI_LAB_WAIT_MS` | 問題間の待機ミリ秒（既定 300） |
| `KENTEI_LAB_MAX_N` | 取得上限（スモークテスト/部分取得用・既定 0=全件） |
| `AGENT_BROWSER` | agent-browser バイナリパス上書き（既定: `which agent-browser`） |

```bash
# 例: 世界遺産検定2級を全問取得
scripts/collect-kentei-lab.sh https://kentei-lab.com/exams/sekai2kyu/start ./kentei-lab-output

# 例: 最初の10問だけ試しに取得（スモークテスト）
KENTEI_LAB_MAX_N=10 scripts/collect-kentei-lab.sh https://kentei-lab.com/exams/sake3/start /tmp/sake3-test
```

大規模資格（数百〜1015 問）は取得に時間がかかる。**`run_in_background: true` での実行を推奨する**。
中断しても resume（§6）により安全に再開できる。

## 5. 出力 Markdown フォーマット

- 1 資格 = 1 ファイル: `<output-dir>/<slug>.md`
- ファイル先頭にメタ見出し、以降 1 問 1 セクション

```markdown
# <試験名>（<slug>）

- 出典: https://kentei-lab.com/exams/<slug>
- 総問題数: <N>
- 取得日時: <ISO8601>

---

## 第1問

<問題文>

**選択肢**

- A. <選択肢A>
- B. <選択肢B>
- C. <選択肢C>
- D. <選択肢D>

**正解**: C. 1972年

**解説**

<解説文>

---
```

選択肢は取得できた数だけ列挙する（A–D 決め打ちではなく試験により可変）。「正解」行はサイトの
「正解は …」の完全文言をそのまま採用する。

## 6. 中断・再開（resume）

サイドカー進捗ファイル `<output-dir>/<slug>.progress` に「最後に保存成功した問題番号 n」を記録する。

- 起動時、progress ファイルがあればその値 +1 から再開する
- progress ファイルが無く既存 `<slug>.md` があれば、`## 第<n>問` 見出しの最大値 +1 から再開する
- どちらも無ければ第1問から開始する

各問題は 1 問読み取り・開示・検証が完了してから Markdown へ追記し、直後に progress を更新する。
そのため任意のタイミングで中断しても、次回実行時にその続きから安全に再開できる（同一問題の重複保存は起きない）。

## 7. サイトへの配慮

kentei-lab.com は無料公開・認証不要の教育目的サイトである。本スクリプトは既定で問題間に 300ms の待機を
挟み、サーバへの負荷を抑える（`KENTEI_LAB_WAIT_MS` で調整可）。大量取得を行う際も、教育・個人利用目的での
節度ある利用に留めること。

## 8. トラブルシュート

| 症状 | 対処 |
|---|---|
| 総問題数(N)が取得できずエラー終了する | サイトのボタン文言が変わった可能性がある。`agent-browser open <slug>/start` してボタン文言を目視確認し、スクリプトの `get-n.js` の正規表現を調整する |
| 問題文/選択肢/正解/解説が取得できずエラー終了する | DOM 構造が変わった可能性がある。`agent-browser eval --stdin` で `read-before-click.js`/`read-after-click.js` 相当を手動実行し、セレクタを調整する |
| agent-browser デーモンが不調（接続エラー等） | `agent-browser doctor --fix` で診断・修復し、必要なら `agent-browser close --all` してから再実行する |
| 選択肢の数が資格により異なる | 想定内。スクリプトは選択肢数を決め打ちせず、取得できた分だけ列挙する |

## 9. やってはいけないこと

kentei-lab の全問題データはクライアント側の巨大 JS バンドル（数十 MB）に埋め込まれている。**この
バンドルを直接パースして問題データを抜き出す実装は行わない**。サイト更新で容易に壊れる上、意図された
表示範囲を超えてデータへアクセスすることになるため、本スキルは常にレンダリング後の DOM を読む方式のみを
採用する。

## 補足: agent-browser eval の呼び出し方

`agent-browser` の一部バージョン（導入検証時点: 0.31.1）には、外部ドキュメントに記載のある
`eval --file <path>` オプションが実装されておらず指定すると構文エラーになる。JS を渡す際は
`agent-browser eval --stdin < script.js`（またはヒアドキュメント）を使う。`scripts/collect-kentei-lab.sh`
はこの方式で実装済み。
