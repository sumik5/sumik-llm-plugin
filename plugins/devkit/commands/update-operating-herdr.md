---
description: >-
  operating-herdr スキル（herdr CLI 操作ガイド）を herdr 公式スキル（herdrdev/herdr の skills/herdr/SKILL.md）と同期するコマンド。
  ローカルに herdr バイナリがあれば `herdr --version` / `herdr --skill` で確実に最新版を取得し、無ければ GitHub 最新リリースから
  フォールバック取得する。上流の英語版は機械的な逐語翻訳ではなく、既存の日本語実務ガイド（検知遅延対処・report-agentパターン等の
  独自Tips）を維持したまま新規ルールを該当章へ統合する半自動フローで、frontmatter更新・diff提示→承認→version bump→commit+tag まで一気通貫。
  Use when refreshing the operating-herdr skill against upstream herdr CLI releases, or periodically checking whether
  the bundled herdr operational guide has drifted from the herdr binary's own bundled skill.
allowed-tools: Read, Edit, Write, Glob, Grep, Bash, AskUserQuestion, WebFetch
user-invocable: true
argument-hint: "[--check（差分確認のみ・更新しない） | 補足メモ]"
---

# /update-operating-herdr

`operating-herdr` スキル（`plugins/devkit/skills/operating-herdr/`）を herdr 公式スキル（[herdrdev/herdr](https://github.com/herdrdev/herdr) の `skills/herdr/SKILL.md`）と同期する自己完結コマンド。

## 概要

| 項目 | 内容 |
|------|------|
| 対象スキル | `plugins/devkit/skills/operating-herdr/`（`SKILL.md` + `INSTRUCTIONS.md`） |
| 同期元 | `herdrdev/herdr` の `skills/herdr/SKILL.md`（英語・抽象的な運用原則） |
| 基準点 | `SKILL.md` frontmatter の `metadata.herdr-version`（未整備なら本文中の最終確認バージョンから代替特定） |
| 差分検知 | ローカル `herdr --version`/`herdr --skill` 優先、無ければ GitHub 最新リリースをフォールバック取得 |
| 統合方針 | `software-security` の逐語翻訳 CONTRACT とは異なり、**判断を伴う統合**（既存Tips維持＋新規差分のみ該当章へ反映） |
| 出力 | スキル更新・frontmatter鮮度更新・version bump（3ファイル同期）・commit・tag |

`$ARGUMENTS` に `--check` が含まれる場合は**差分の報告のみ**を行い、ファイルは一切変更しない。

---

## ワークフロー

### Step 1: 基準点の取得

`plugins/devkit/skills/operating-herdr/SKILL.md` の frontmatter を確認する:

```bash
DST=plugins/devkit/skills/operating-herdr
/usr/bin/grep -A3 "^metadata:" "$DST/SKILL.md"
```

- `metadata.herdr-version` が存在する場合 → その値を基準点として使う。
- 存在しない場合 → 本文中の最終確認バージョンを grep で代替特定する:

  ```bash
  /usr/bin/grep -oE "herdr [0-9]+\.[0-9]+\.[0-9]+" plugins/devkit/skills/operating-herdr/INSTRUCTIONS.md | tail -1
  ```

  代替特定できたら、**今後の自動追跡をしやすくするため** frontmatter に `metadata: {herdr-version: "X.Y.Z"}` を追加することを提案する（AskUserQuestion で確認してから追加）。すでに別タスクで追加済みの場合はこの提案を省略し、単に読み取るだけにする。
- どちらの方法でも基準点が特定できない場合は中断し、ユーザーに手動確認を促す。

### Step 2: 現在の最新バージョンの検知

二系統のソースを**この優先順**で使う:

**(a) ローカル優先**（最も確実・GitHubのレート制限やネットワーク到達性に依存しない）:

```bash
command -v herdr && [ "$HERDR_ENV" = "1" ] && herdr --version
```

- herdr バイナリが PATH にあり `HERDR_ENV=1` なら、`herdr --version` でインストール済みバージョンを取得する。
- 続けて `herdr --skill` で**インストール済みバイナリに埋め込まれた公式スキル本文**をそのまま取得できる。これは GitHub 経由の取得より確実な herdr 特有の利点であり、`update-software-security` の上流同期にはない最適化。

**(b) フォールバック**（ローカルに herdr が無い、または `HERDR_ENV` 未設定の場合）:

```bash
gh api repos/herdrdev/herdr/releases/latest --jq '.tag_name'
```

取得した `<tag>` を使い、`WebFetch` で公式スキル本文を取得する:

```
https://raw.githubusercontent.com/herdrdev/herdr/<tag>/skills/herdr/SKILL.md
```

**判定**:

- 取得したバージョンが Step 1 の基準点と同じ → 「既に最新（herdr <version>）」と報告して**終了**（ファイル変更なし）。
- `--check` が指定されている場合 → 新旧バージョンと差分有無をここで報告して**終了**（ファイル変更なし）。
- バージョンが進んでいる場合のみ Step 3 へ進む。

### Step 3: 差分の把握

Step 2 で取得した公式スキル本文（英語）を、現行の `plugins/devkit/skills/operating-herdr/INSTRUCTIONS.md`（日本語）と比較し、以下の観点で差分を洗い出す:

- 新規コマンド名前空間の追加/削除（例: 過去に `herdr worktree`/`herdr terminal` が追加された事例がある）
- 既存コマンドのオプション追加/削除/意味変更
- lifecycle state（`idle`/`working`/`blocked`/`done`/`unknown`）の定義変更
- JSON レスポンス構造の変更（`.result.xxx` パス）
- エラーコード・exit code の仕様変更

**可能なら実機 `--help` 検証も併用する**（ローカルに herdr があれば）。公式スキル本文だけでは伝わらない詳細（オプション一覧・デフォルト値）を `herdr <group> <subcommand> --help` で裏取りする。このリポジトリでは実際に v0.7.5→v0.8.0 更新作業でこの手法を使い、公式スキル本文だけでは判明しなかった `pane move` の新オプションや `pane read --source detection` 対応差の訂正など複数の発見があった実績がある。

### Step 4: 統合方針（機械的翻訳にしない）

`software-security` の「CONTRACT に従った逐語翻訳」とは異なり、このコマンドでは以下の判断を伴う統合を行う:

- 既存の日本語実務 Tips（検知遅延対処・report-agent パターン・lifecycle authority 区分等、公式スキルに存在しない独自知見）は**削除せず維持**する。
- 公式スキル本文の新規ルール・新規コマンド名前空間のみを、既存の章構成（Step0/concepts/pane名前空間/agent名前空間/integration/wait/recipes/検知遅延対処/notes）に適切な章へ統合する。
- 廃止されたコマンド・オプションは既存本文から該当箇所を削除し、置き換え後の正しい構文に更新する。
- 差分が大きい場合は、独立した章ごとに複数の並列タチコマ（`general-purpose`, `devkit:tachikoma-doc-document` 等）に担当章を排他割当して執筆させてよい（`software-security` の並列翻訳パターンを踏襲）。各タチコマには「削除せず維持すべき既存Tips範囲」を明示すること。

### Step 5: メタデータ更新

- `SKILL.md` の「herdr 公式ドキュメントの鮮度確認」節: 「確認日」を本日日付へ更新。
- `SKILL.md` frontmatter の `metadata.herdr-version`（Step 1 で追加/確認した場合）を今回取得した最新バージョンへ更新。
- 破壊的変更があった場合は SKILL.md 本文の🔴注記（バージョン間の変更点サマリ）も更新する。

### Step 6: 検証（機械突き合わせ・必須）

```bash
DST=plugins/devkit/skills/operating-herdr
# 🔴 固有名チェック（書籍/著者/出版社）— このリポジトリの絶対ルール
/usr/bin/grep -nE "『|』|著者|〜著|出版|オライリー|オーム社|技術評論|翔泳社|日経BP|インプレス|Effective [A-Z]" "$DST/SKILL.md" "$DST/INSTRUCTIONS.md"
# description 文字数チェック（1024文字以内）
python3 -c "import yaml; d=yaml.safe_load(open('$DST/SKILL.md').read().split('---')[1]); print(len(d['description']))"
```

- 固有名チェックはヒット0件であることを確認する。
- description が1024文字を超えていないか確認する。

### Step 7: README.md 同期

```bash
/usr/bin/grep -n "operating-herdr" README.md
```

`operating-herdr` の説明行に今回の新機能（新規コマンド名前空間対応等）が反映されているか確認し、必要なら更新する。

### Step 8: version bump とコミット

`authoring-plugins` スキルの完了ワークフローに従う:

- **bump 判定**: 既存内容の修正のみ → **PATCH**。新規コマンド名前空間の追加等で機能追加相当 → **MINOR**（`applying-semantic-versioning` スキル参照）。
- **devkit プラグインの3ファイル同期**（このリポジトリの🔴ルール）:
  - `plugins/devkit/.claude-plugin/plugin.json`
  - `.codex-plugin/plugin.json`
  - `.agents/plugins/marketplace.json` の devkit エントリ
  - 同期確認: `python3 scripts/check-version-sync.py`
- **diff 提示 → ユーザー承認**（git書込は確認必須）→ Conventional Commits でコミット（`fix(operating-herdr): herdr <version> へ同期` / 機能追加相当なら `feat(...)`）→ tag 付与（devkit のみ prefix なし `v{version}` 形式）。
- コミットメッセージ・本文に**書籍名・著者名・出版社名を含めない**（このリポジトリの絶対ルール）。

---

## 注意点

| If X | then Y |
|------|--------|
| ローカルに herdr バイナリがあり `HERDR_ENV=1` | `herdr --version` / `herdr --skill` を必ず優先（GitHub API 経由より確実・レート制限の影響を受けない） |
| ローカルに herdr が無い、または `HERDR_ENV` 未設定 | `gh api repos/herdrdev/herdr/releases/latest` → `WebFetch` で公式 raw SKILL.md を取得するフォールバックへ切り替える |
| Step 2 で取得したバージョンが基準点と同一 | 何も変更せず「既に最新（herdr <version>）」と報告して終了 |
| 公式スキル本文だけでは変更の詳細（新オプション・デフォルト値）が判明しない | ローカルに herdr があれば実機 `--help` で裏取りする（過去 v0.7.5→v0.8.0 更新でこの手法により複数の見落としを発見した実績あり） |
| 上流の変更を既存の日本語実務ガイドへ統合する時 | 逐語翻訳にせず、既存Tips（検知遅延対処・report-agentパターン等）は維持したまま新規差分のみ該当章へ統合する。廃止されたコマンド/オプションは該当箇所を削除し正しい構文へ置き換える |
| 翻訳・統合を並列タチコマに委譲 | 担当章を排他割当し、「削除せず維持すべき既存Tips範囲」を明示する。完了後に本体が固有名grep・README整合を再検証（タチコマ自己申告を鵜呑みにしない） |
| `gh` 未認証・レート制限、かつローカルにも herdr が無い | 中断してユーザーに通知（黙って部分更新しない） |
