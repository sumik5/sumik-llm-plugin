---
name: collecting-kentei-lab-exams
description: >-
  kentei-lab.com の資格・検定問題を、指定 URL からその資格の全問題（問題文・選択肢・正解・解説）を巡回取得し
  1 資格 1 JSON ファイル（Anki 登録に適した構造化データ）に保存する。出力はそのまま creating-flashcards
  スキルへ渡して試験名ごとに Anki フラッシュカード化できる。
  Use when kentei-lab の資格 URL（/exams/<slug> ・ /exams/<slug>/start ・ /quiz/<slug>/<n> のいずれか）を渡され
  「問題を全部保存したい」「問題集を収集したい」「Anki カードにしたい」等と言われたとき。
  補足トリガー: kentei-lab, ケンテイラボ, 検定, 資格試験, 問題集, quiz 収集, JSON 保存, Anki 連携。
  ブラウザ操作自体の汎用ガイドは web:automating-browser、E2E テストは web:testing-e2e-with-playwright を使う。
  本スキルは kentei-lab 専用の収集ワークフローと bundled script（scripts/collect-kentei-lab.sh）を提供する。
---

## このスキルは何か

kentei-lab.com は認証不要・全問無料公開の資格・検定問題集サイト（147 資格・58,950 問収録）。人間は概要ページの
「問題を解く →」から開始ページの「全問題を始める N問」を選び、問題ページを 1 問ずつ進める。

本スキルの実装（`scripts/collect-kentei-lab.sh`）は、この人間の導線と同じ問題集合を **`/quiz/<slug>/<n>`（n=1..N）
への直接 URL 反復**で決定的に取得する。同一 n は常に同一問題であり（ランダム出題設定は提示順序のみに影響）、
「全問題を始める」ボタンや「次の問題へ」リンクのクリックには一切依存しない。そのため中断・再開に強く、
1 資格分（最大 1015 問）を長時間の `run_in_background` ジョブとして安全に走らせられる。

出力は 1 資格 1 JSON ファイル（`<slug>.json`）で、`creating-flashcards` スキルの `kentei_lab_import.py`
ファストパスにそのまま渡して `検定試験::<検定名>::<級>::kentei-lab`（級を検出できない試験は
`検定試験::<検定名>::kentei-lab`）デッキへ一括登録できる。

詳細な導線・実行方法・出力フォーマット・resume の仕組み・トラブルシュートは `INSTRUCTIONS.md` を参照。
