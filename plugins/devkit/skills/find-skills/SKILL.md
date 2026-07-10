---
name: find-skills
description: >-
  Discovers and installs agent skills from the open skills ecosystem using the Skills CLI
  (npx skills find / add / check / update) and the skills.sh registry and leaderboard,
  vetting candidates by install count and source reputation before recommending or installing them.
  Use when the user asks questions like "how do I do X", "find a skill for X",
  "is there a skill that can...", wants to search for tools, templates, or workflows,
  or expresses interest in extending agent capabilities with installable skills.
  For evaluating npm/pip/Go code libraries, use researching-libraries instead.
  For authoring local plugin/skill components, use authoring-plugins instead.
context: fork
agent: Explore
---

# Find Skills

オープンなエージェントスキルエコシステム（skills.sh レジストリ）からスキルを発見し、品質検証のうえでインストールを支援するスキル。

## Skills CLI とは

Skills CLI（`npx skills`）は、オープンなエージェントスキルエコシステムのパッケージマネージャー。スキルは専門知識・ワークフロー・ツールでエージェント能力を拡張するモジュール型パッケージであり、GitHub 等のソースから取得できる。レジストリとリーダーボードは https://skills.sh/ で閲覧できる。

## 主要コマンド

| コマンド | 用途 |
|---------|------|
| `npx skills find [query]` | スキルを対話的またはキーワードで検索 |
| `npx skills add <package>` | GitHub 等のソースからスキルをインストール |
| `npx skills check` | インストール済みスキルの更新確認 |
| `npx skills update` | インストール済みスキルを一括更新 |

## 基本フロー

ニーズ理解 → リーダーボード確認 → CLI 検索 → 品質検証（インストール数 1K+ / ソース信頼性 / GitHub stars）→ ユーザーへ提示 → インストール、の 6 ステップで進める。**検索結果だけを根拠に推奨しない**（品質検証を必ず挟む）。

詳細な手順・検証基準・カテゴリ別クエリ表・検索 Tips・スキルが見つからない場合の対応は `INSTRUCTIONS.md` を参照してください。
