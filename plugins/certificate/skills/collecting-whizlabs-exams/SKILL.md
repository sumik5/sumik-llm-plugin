---
name: collecting-whizlabs-exams
description: >-
  Whizlabs のコース practice test 一覧URLから、配下の全クイズ（Free Test・Practice Test 1〜N 等）を
  practice mode で巡回し、各問題（問題文・選択肢・正解・解説・参考資料）を取得して 1 クイズ 1 JSON ファイルに
  保存する。出力は creating-flashcards スキルへ渡してクイズごとに Anki フラッシュカード化できる。
  Use when Whizlabs のコースURL（/learn/course/<slug>/<course-id>/pt 形式）を渡され
  「問題を全部保存したい」「Anki カードにしたい」等と言われたとき。
  補足トリガー: whizlabs, ホイズラボ, 資格試験, 問題集, practice test, quiz 収集, JSON 保存, Anki 連携。
  ブラウザ操作自体の汎用ガイドは web:automating-browser、E2E テストは web:testing-e2e-with-playwright を使う。
  本スキルは Whizlabs 専用の収集ワークフロー + bundled script（scripts/collect-whizlabs.sh）＋
  ログイン認証（agent-browser Auth Vault）を提供する。
---

## このスキルは何か

Whizlabs は認証必須の資格・検定対策プラットフォーム。人間はコース一覧ページから対象クイズ（Free Test・
Practice Test 1〜N 等）の「Start」（または「Free」）ボタンを押し、「Start quiz as practice mode」を選んで
開始し、1 問ずつ回答しながら進める。

本スキルの実装（`scripts/collect-whizlabs.sh`）は、kentei-lab 版（`/quiz/<slug>/<n>` への直接 URL 反復）とは
異なり、Whizlabs の practice test URL は固定されたまま SPA 内部状態で問題が切り替わるため **直接 URL 反復は
使えない**。代わりに、画面下部の問題番号 `li` を `eval` で直接クリックして SPA 内をジャンプし、各問題では
選択肢を選ばず `show Answer` ボタンをクリックするだけで正解・解説・参考資料を開示する（kentei-lab とは逆で
選択肢クリック不要）。ログインは agent-browser の Auth Vault でセッションを永続化する。

kentei-lab との主な相違点:

- URL 固定・SPA 内ジャンプ方式（直接 URL 反復不可）
- 選択肢クリック不要（`show Answer` ボタンのみで全開示）
- resume は同一ブラウザプロセス内でのみ有効（ブラウザが落ちると該当クイズは最初からになる弱い resume）
- ログイン必須（Free Test も含めアカウントが必要）

出力は 1 クイズ 1 JSON ファイル（`<course-slug>__<quiz-slug>.json`）で、`creating-flashcards` スキルの
`whizlabs_import.py` ファストパスにそのまま渡して Anki へ一括登録できる。

詳細な導線・実行方法・出力フォーマット・resume の制約・トラブルシュートは `INSTRUCTIONS.md` を参照。
