---
name: orchestrating-teams
description: >-
  Agent Teamオーケストレーション（planner-first 2フェーズ方式: planner タチコマによる要件分析・docs/plan 作成 → ドメイン別専門タチコマの並列実装）。非herdr環境の Agent（run_in_background）/ SendMessage / TaskCreate・TaskList と、HERDR_ENV=1 環境の `herdr pane split` + `agent start --kind <kind> --pane <id>` / read / prompt / wait --until によるペイン起動・進捗管理、ファイル所有権パターンによる競合防止をカバー。
  Use when multiple files need parallel changes with independent concerns (2+ files, frontend+backend, UI+API+test).
  Triggers: 複数ファイル並列変更、マルチ関心事開発、フロントエンド+バックエンド同時変更。
  HERDR_ENV=1 では operating-herdr を必ず併用し、Claude Code の split-pane を使わず herdr CLI でエージェントを起動する。
  For Codex CLI orchestration (config.toml max_threads, agents/*.toml), use orchestrating-codex instead.
  For operating as a single Tachikoma implementation worker, use implementing-as-tachikoma instead.
---

詳細な手順・ガイドラインは `INSTRUCTIONS.md` を参照してください。
