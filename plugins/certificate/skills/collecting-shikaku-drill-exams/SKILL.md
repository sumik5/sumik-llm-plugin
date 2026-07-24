---
name: collecting-shikaku-drill-exams
description: >-
  shikaku-drill.com（59資格対応の無料4択問題集サイト）の資格試験ページURLから、その試験の
  全問題（問題文・カテゴリ・選択肢・正解・解説）を巡回取得し1試験1JSONファイル（Anki登録に
  適した構造化データ）に保存する。出力はそのまま creating-flashcards スキルへ渡して
  カテゴリ別のAnkiフラッシュカード化できる。
  Use when shikaku-drill の資格URL（https://shikaku-drill.com/<slug>.html 形式）を渡され
  「問題を全部保存したい」「問題集を収集したい」「Anki カードにしたい」等と言われたとき。
  補足トリガー: shikaku-drill, 資格ドリル, 検定, 資格試験, 問題集, 学習スタート, 修行開始,
  JSON 保存, Anki 連携。
  ブラウザ操作自体の汎用ガイドは web:automating-browser、E2E テストは
  web:testing-e2e-with-playwright を使う。本スキルは shikaku-drill 専用の収集ワークフローと
  bundled script（scripts/collect-shikaku-drill.sh）を提供する。
---

## このスキルは何か

shikaku-drill.com は認証不要・全問無料公開の資格・検定問題集サイト（59資格対応）。人間は資格ページの
「学習スタート」（既存進捗があれば「修行開始」＋「続きから学習」）ボタンから開始し、問題ページを1問ずつ
進める。

本スキルの実装（`scripts/collect-shikaku-drill.sh`）は kentei-lab（`collecting-kentei-lab-exams`）の
「直接URL反復」方式が使えない点が根本的に異なる。shikaku-drill は SPA 構造でURLが変化しないため、
同スクリプトはトップページ上のボタン操作（絞り込み解除・タイマー無効化・順番通り設定・開始/続きから学習）と
「次の問題へ」ボタンのクリックを繰り返して全問題を巡回する。サイト自体が localStorage ベースの「続きから
学習」resume機構を持つが、これとは独立に本スキル自身も進捗サイドカー（`<slug>.jsonl`）で二重の resume
防御を行う（サイト側resumeとjsonlの記録がズレていても、既収集分は再記録せずスキップして正しい位置まで
追従する）。

出力は1試験1JSONファイル（`<slug>.json`）で、`creating-flashcards` スキルの
`shikaku_drill_import.py` ファストパスにそのまま渡せる。kentei-lab と異なり各問題がカテゴリ
（`category`）を持つため、Anki投入時は問題単位で `検定試験::<検定名>::<級>::shikaku-drill::<カテゴリ名>`
（級を検出できない試験は `検定試験::<検定名>::shikaku-drill::<カテゴリ名>`）デッキへ自動振り分けされる。

詳細な導線・実行方法・出力フォーマット・resume の仕組み・トラブルシュートは `INSTRUCTIONS.md` を参照。
