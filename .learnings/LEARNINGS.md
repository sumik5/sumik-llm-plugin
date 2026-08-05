# LEARNINGS — sumik-claude-plugin

作業中に得た非自明な学び・調査結果の記録（capturing-learnings 形式）。

## [LRN-20260806-001] best_practice: herdr CLI自体が公式スキルの一次配布源になる

**Recurrence-Count**: 1

herdr バイナリは `herdr --skill` フラグでインストール済みバイナリに埋め込まれた公式 SKILL.md をそのまま出力する。ローカル環境で `herdr --skill`（v0.8.0）と GitHub `herdrdev/herdr` v0.8.0 タグの `skills/herdr/SKILL.md`（raw fetch）を突き合わせ、内容が完全一致することを確認した。

**Why**: GitHub raw fetch はネットワーク到達性・レート制限・タグと実インストール版のバージョン不一致リスクを伴うが、`herdr --skill` は「今このマシンで動いているバージョン」と常に一致する。

**How to apply**: herdr 関連スキル（`operating-herdr`）の同期作業では、ローカルに herdr バイナリがあり `HERDR_ENV=1` の場合は `herdr --version`/`herdr --skill` を最優先ソースとし、GitHub 経由は herdr 未インストール時のフォールバックに位置付ける（`/update-operating-herdr` コマンドに実装済み）。同種の「CLIツール自身のドキュメント同期」タスクでは、まず対象バイナリに自己文書化フラグ（`--skill`/`--docs`/`--help` 系）がないか確認する価値がある。

## [LRN-20260806-002] correction: 公式ドキュメント本文の記述だけでは実際のCLI仕様差分を検知できない場合がある

**Recurrence-Count**: 1

herdr 公式 SKILL.md 本文は "Use the read source that matches the task: visible/recent/recent-unwrapped/detection" と `pane read`/`agent read` を区別せず併記していたため文章だけでは両コマンドの対応が同一か読み取りづらかった。旧 `operating-herdr` スキルには「`pane read` は `detection` 非対応（`agent read` のみ対応）」という誤記があり、実機 `herdr pane read --help` / `herdr agent read --help` を突き合わせて初めて「0.8.0時点では両方とも同一の4択」と確定できた。

**Why**: 公式ドキュメントの自然文は網羅的な仕様表として書かれていないことがあり、コマンド間の対応差を暗黙の前提で書いていたり、旧バージョンの記述がそのまま残っていたりする。

**How to apply**: CLIツールの操作スキルを外部ドキュメントと同期する際は、ドキュメント本文の翻訳・転記だけで終えず、可能なら実機 `<command> --help` の出力で主要コマンドのオプション一覧を裏取りする。今回は `pane read`/`agent read`/`pane move`/`agent start`/`agent prompt`/`agent wait`/`agent send-keys` の `--help` 出力を横並びで確認し、`pane move` の `--target-pane`/`--tab-label` 追加等、本文だけでは気づけなかった差分も発見した。

## [LRN-20260806-003] best_practice: 並列タチコマは「担当ファイル本体」の外側にある整合修正を自発的にはやらない

**Recurrence-Count**: 1

`operating-herdr` スキル本体の更新と `/update-operating-herdr` コマンド新規作成を2タチコマに並列委譲した際、両者とも自分の担当ファイルのみを正確に仕上げたが、`README.md` 内の `operating-herdr` 説明行（スキル内容の要約）は担当範囲の境界に落ちて誰も更新しなかった。加えて `.codex-plugin/plugin.json`/`.agents/plugins/marketplace.json` の description 内「14個のコマンド」という散在した数値も、version bump タスク（`version` フィールドのみ指示）の担当タチコマが見つけて報告してくれるまで本体も見落としていた。

**Why**: 「ファイル所有権を分割して競合を防ぐ」パターンは並列実行の安全策として正しいが、それぞれのファイルに影響する"要約"や"派生した数値"が別ファイルに散らばっている場合、境界線上のその整合更新は誰の担当にも入らず抜け落ちる。`python3 scripts/check-version-sync.py` は3ファイルの `version` フィールド一致は保証するが、description内の自由文中の数値までは検証しない。

**How to apply**: 既存コンポーネントの内容を大きく更新する・新規コンポーネントを追加するタスクでは、担当ファイル本体の完了後に必ず「README.mdの該当説明行」と「plugin.json/marketplace.json の description 内の実数表現（コマンド数・スキル数等）」を本体が明示的に `grep` して実数と突き合わせる一手順を検証フェーズに組み込む（[[feedback_parallel_contract_verification]] と同系統の教訓）。
