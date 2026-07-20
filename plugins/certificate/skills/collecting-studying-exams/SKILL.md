---
name: collecting-studying-exams
description: >-
  studying（スタディング, member.studying.jp）のコースレッスン一覧URLから、配下の「スマート問題集」
  「セレクト過去問集（学科試験対策・実技試験対策）」の全問題（問題文・選択肢・正解・解説）を科目単位で
  取得し、1科目1JSONファイルに保存する。出力は creating-flashcards スキルへ渡して科目ごとに
  Anki フラッシュカード化できる。
  Use when studying のコースレッスン一覧URL（https://member.studying.jp/course/id/<course_id>/ 形式）
  を渡され「問題を全部保存したい」「Anki カードにしたい」等と言われたとき。
  補足トリガー: studying, スタディング, 資格試験, スマート問題集, セレクト過去問集, 問題集,
  JSON 保存, Anki 連携。
  ブラウザ操作自体の汎用ガイドは web:automating-browser、E2E テストは web:testing-e2e-with-playwright
  を使う。本スキルは studying 専用の収集ワークフロー + bundled script（scripts/collect-studying.sh）
  ＋ログイン認証を提供する。
---

## このスキルは何か

studying は認証必須の資格・検定対策プラットフォーム。人間はコーストップページから「基本講座」
「スマート問題集」「セレクト過去問集（学科試験対策）」「セレクト過去問集（実技試験対策）」の各セクション内で
科目を1つずつクリックして展開し、科目ページへ進んで「解説一覧表示」を開いて問題・正解・解説を確認する。

本スキルの実装（`scripts/collect-studying.sh`）は、Whizlabs 版（`collecting-whizlabs-exams`）とは異なり
**1問ずつのブラウザ操作が一切不要**という大きな違いがある。studying の科目ページには「解説一覧表示」リンク
（`https://member.studying.jp/course/practice/list/id/<practice_id>/a/on/`）があり、**これに直接アクセスする
だけで、その科目に含まれる全問題・全選択肢・正解・解説が1回のページ読み込みで一括表示される**。したがって
本スキルの巡回ロジックは「コーストップページで対象3セクション配下の科目トグルを全部展開して
`practice_id` を収集 → 科目ごとに一括表示ページを開いて抽出 → 1科目1JSON保存」という単純な2段構成になる。

ログインは通常のフォームページ（`https://member.studying.jp/login/`）で行う。Whizlabsのようなモーダル型
ログインではないため、agent-browser の Auth Vault（`auth save`/`auth login`）が使える可能性が高く、
本スキルは Auth Vault を第一候補として試行し、機能しない場合は通常フォーム入力 + `state save`/`state load`
にフォールバックする。

出力は 1 科目 1 JSON ファイル（`<course-slug>__<category-slug>__<subject-slug>.json`）で、
`creating-flashcards` スキルの `studying_import.py` ファストパスにそのまま渡して Anki へ一括登録できる。

**利用上の注意（必読）**: studying は認証必須の有料コンテンツを含むプラットフォームであり、著作権について
の注意書きが明記されている。本スキルは**ユーザー自身が正規に受講権限を持つコースの個人学習目的（Anki個人
利用）でのみ使用する**前提とする。収集した問題文・解説の実例をスキル本文・コミットメッセージ・会話記録に
引用しない。

詳細な導線・実行方法・出力フォーマット・トラブルシュートは `INSTRUCTIONS.md` を参照。
