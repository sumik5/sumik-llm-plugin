# LEARNINGS — sumik-claude-plugin

作業中に得た非自明な学び・調査結果の記録（capturing-learnings 形式）。

> 2026-07-13: 蓄積エントリ（LRN-20260625-001 〜 LRN-20260703-002）を全消費・削除済み。
> 恒久化先: authoring-plugins（HOOK-GUIDE.md / MANAGING-MULTI-PLUGIN.md / CONVERTING.md / INSTRUCTIONS.md）・
> repo CLAUDE.md（git 罠表・Codex 配布表）・RTK.md・Claude Code memory。
>
> 2026-07-15: 蓄積エントリ（LRN-20260713-001・LRN-20260713-002・LRN-20260714-001）を全消費・削除済み。
> 恒久化先: RTK.md（環境の罠表に symlink 罠を追記）・
> orchestrating-teams/INSTRUCTIONS.md（herdr Codex限定運用の優先順位を追記）・
> plugins/devkit/agents/*.md 24件 + plugins/exam/agents/exam-solver.md 1件（実測25件、`model: sonnet` → `model: claude-sonnet-5` へ実適用・grep実証済み）。
> LRN-20260714-001 が「統一済み」と誤って記載していた内容は、この消費作業で実際に適用し裏取り済み（ERR-20260715-001 も併せて消費）。
>
> 2026-07-24: 蓄積エントリ（LRN-20260722-003・LRN-20260719-003）を全消費・削除済み。
> LRN-20260722-003（studying収集の一括表示ページ限界・nosubcat・語群欠落）は
> `plugins/certificate/skills/creating-flashcards/references/URL-COLLECTION.md` の studying節へ
> 既に反映済みであることを実grepで確認（nosubcat構造フォールバック・multi_blank/fill_in_single
> 選択肢取得の記述が実在）。LRN-20260719-003（herdr上のClaude Code CLIが完了報告直後に入力欄へ
> テキストをプリフィルする）はERR-20260724-007（同型の2回目の発生）と統合し
> `plugins/devkit/skills/operating-herdr/INSTRUCTIONS.md` の「Escape で中断した直後の多段送信は
> 要注意」ブロック直後へ恒久化済み（ERRORS.md側と同時消費）。
>
> 2026-07-24（2巡目）: 蓄積エントリ（LRN-20260722-001・LRN-20260722-002・LRN-20260724-001・
> LRN-20260719-002）を全消費・削除済み（ユーザー承認によりRecurrence-Count<3のものも前倒し恒久化）。
> LRN-20260722-001（タチコマの虚偽ユーザー指示捏造）は
> `plugins/devkit/skills/implementing-as-tachikoma/references/REFERENCE.md` の「## 報告フォーマット」
> 節冒頭へ新規小見出し「### 完了報告における事実確認の徹底」として恒久化。LRN-20260722-002
> （choice_type等の複数分類データ形式は1形式の欠落発見で終わらせず全形式横断点検すべき）は
> `plugins/certificate/skills/creating-flashcards/INSTRUCTIONS.md` のStep 3節末尾へ`⚠️`ブロックとして
> 恒久化。LRN-20260724-001（収集元ごとのexam_title表記ゆれによるAnkiデッキツリー分裂）は同ファイルの
> shikaku-drill節末尾へ`🔴`ブロックとして恒久化（kentei-lab・whizlabs・studying・shikaku-drill共通の
> 注意点として1箇所にまとめた）。LRN-20260719-002（planner指示逸脱）は恒久化先「なし・スキル変更不要」
> の判断が既に確定済みのためスキル本体への追記は行わず削除のみ（同型事案が再発したら新規LRNとして
> 起こし直す）。3件とも `git diff` で追加行のみ・禁止語なし・`.learnings`参照残存なしを実機検証済み。
> certificate 2.0.1→2.0.2・devkit 14.12.3→14.12.4（いずれもPATCH・内容追記のため）。

> 2026-07-22: 蓄積エントリ（LRN-20260719-001×2件・LRN-20260716-001・LRN-20260717-001・LRN-20260717-002・
> LRN-20260722-001「herdr 0.7.5」）を全消費・削除済み。恒久化先: collecting-whizlabs-exams/INSTRUCTIONS.md・
> operating-herdr/INSTRUCTIONS.md・orchestrating-teams/references・devkit/hooks/notify-complete.sh（いずれも
> 実ファイルで反映済みを確認）。RTK.md「環境の罠と回避策」表へ dotfiles symlink 実体化の罠を追記。
> tesseract 学びは creating-flashcards/references/OCR-CONVERSION.md が既により発展した形（Apple Vision + VLM
> 併用のハイブリッド判断基準）で対応済みと確認したため追記不要と判断。
