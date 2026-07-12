---
description: >-
  .learnings/（LEARNINGS.md・ERRORS.md）の蓄積エントリを実ファイル裏取りのうえ恒久化先へ消費し、処理済みエントリを削除する。恒久化先は実行コンテキストで決まる（一般プロジェクト: プロジェクトCLAUDE.md・.claude/配下・~/.claude/CLAUDE.md・~/.codex/AGENTS.md・memory ／ sumik-claude-plugin repo: 加えてスキルreferences・version bump）。capturing-learnings（捕捉）と対になる消費側コマンド
allowed-tools: Bash, Read, Grep, Glob, Edit, Write, Agent, AskUserQuestion, SendMessage, ToolSearch, Skill
argument-hint: "[追加指示（例: スキルのみ / コミットなし）省略可]"
user-invocable: true
---

# Consume Learnings Command

`.learnings/` の蓄積エントリ（LRN- / ERR- / FEAT-）を恒久化先へ「消費」し、処理済みエントリを削除する。capturing-learnings（捕捉 = C）と対になる消費（D）側のコマンド。

## 使用方法

```bash
/consume-learnings                # .learnings/ の全エントリを消費
/consume-learnings スキルのみ      # 引数で恒久化先・範囲を限定
/consume-learnings コミットなし    # git 書込をスキップ（編集と削除のみ）
```

## 前提と権限

- 本コマンドの発動は「CLAUDE.md・dotfiles（`~/.claude` 配下）を改善してよい」というユーザー確認に相当する（無断編集にはあたらない）。ただし **git 書込（commit / tag / push）は別途 AskUserQuestion で確認必須**。
- 編集は必ずソースリポジトリに対して行う（`~/.claude/plugins/cache/...` は読取専用コピー）。
- sumik-claude-plugin repo で実行する場合は、作業開始時に `authoring-plugins` スキルをロードする（規約・検証ゲートの参照元。一般プロジェクトでは不要）。

## 対象と棲み分け

| 対象 | 処理 |
|------|------|
| `.learnings/LEARNINGS.md`・`ERRORS.md`（あれば `FEATURE_REQUESTS.md`） | 本コマンドで消費 |
| CLAUDE.md「📥 スキル改善提案 (inbox)」の `[PROPOSAL]` | 対象外。`authoring-plugins` の「🔄 改善提案INTAKE」で処理する |
| .learnings 内のスキル改善提案の性質を持つエントリ | inbox への回送を提案（ユーザーが直接編集を指示済みなら消費してよい） |

## Phase 0: 実行コンテキストの判定（🔴 恒久化先はプロジェクトで変わる）

本コマンドは**任意のプロジェクトで使える**。まず cwd がどちらかを判定する（判定例: `.claude-plugin/marketplace.json` と `plugins/*/skills/` が存在すれば sumik-claude-plugin repo）:

| コンテキスト | 恒久化先の範囲 |
|------------|--------------|
| **一般プロジェクト** | プロジェクト配下（CLAUDE.md・`.claude/` 配下の設定/ルール）・グローバル設定（`~/.claude/CLAUDE.md`・`~/.claude/rules/*.md`・`~/.codex/AGENTS.md`）・Claude Code memory。**プラグインのスキル（authoring-plugins 等）は更新しない**——スキル改善の気づきは global CLAUDE.md inbox の `[PROPOSAL]` へ回送を提案する |
| **sumik-claude-plugin repo** | 上記に加えて、スキルの INSTRUCTIONS.md / references/・repo CLAUDE.md の罠表・version bump ＋タグ付きリリース |

## Phase 1: 裏取り（🔴 エントリの自己申告を信じない）

各エントリを読み、**実ファイルで反映状況を検証**してから分類する:

- 「推奨修正」対象のファイル（hook・スキル・設定）を実読 / grep し、修正が既に適用済みか確認する
- 「昇格候補」の行き先（memory・CLAUDE.md・スキル）に同内容が既にあるか確認する
- `status: pending` でも修正済み、`resolved` でも未反映のことがある（実例あり）

| 分類 | 処理 |
|------|------|
| A: 反映済み | 削除のみ（Phase 5 へ） |
| B: 未反映 | 恒久化（Phase 2 へ） |
| C: 判断不能・方針が必要 | AskUserQuestion で確認 |

## Phase 2: 恒久化先ルーティング

| エントリの性質 | 恒久化先 | 実行者 |
|--------------|---------|--------|
| プロジェクト固有の事実・規約・罠 | 実行プロジェクトの CLAUDE.md（If X then Y 表）・`.claude/` 配下の設定/ルール | 本体直接 |
| ユーザー横断・全プロジェクト共通の作業ルール | `~/.claude/CLAUDE.md`・`~/.claude/rules/*.md`（Claude）／ `~/.codex/AGENTS.md`（Codex） | 本体直接 |
| ユーザー横断の事実（反復 ≥3・2 タスク以上・30 日内で昇格） | Claude Code memory ＋ MEMORY.md 索引 | 本体直接 |
| rtk・dotfiles 系の罠 | `~/dotfiles/claude-code/RTK.md`・`rules/*.md` | 本体直接 |
| スキルの手順・ガイドに載せるべき知見（**sumik-claude-plugin repo のみ**） | 該当スキルの INSTRUCTIONS.md / references/ | tachikoma-doc-document へ委譲 |
| hook・スクリプトのコード修正 | 該当 `.sh` 等 | tachikoma-lang-bash 等へ委譲 |

- 🔴 dotfiles のファイルは symlink のことがあり、Edit が「Refusing to write through symlink」で拒否する → `readlink -f` で実体を解決してから編集する（例: RTK.md の実体は `~/.claude/RTK.md`・通常と逆向きの symlink。`~/.codex/AGENTS.md` の実体は `~/dotfiles/codex/AGENTS.md`）
- 🔴 スキル等のドキュメントが `.learnings` のエントリ ID やパスを参照している場合、**エントリ削除より先に参照をインライン化**する（ダングリング防止）

## Phase 3: 編集実行（タチコマ委譲時の必須条項）

委譲プロンプトには 6 要素（コンテキスト / 作業ディレクトリ / 必読ファイル / タスク詳細 / 厳守ルール / 完了条件・報告書式）に加えて以下を必ず含める:

- 書籍名・著者名・出版社名の禁止（公開リポジトリ）
- `.learnings` への参照（`[LRN-...]`・ファイルパス）を新規に書かない（知見は本文へインライン化）
- ファイル所有権の明示（担当外ファイルの編集禁止）・既存文体の維持・既存の正しい記述を削らない

## Phase 4: 機械検証（タチコマ報告を鵜呑みにしない）

```bash
# ダングリング参照（0 件期待。learnings-error-detector.sh の実出力例など正当な言及は除外判断）
/usr/bin/grep -rn "\[LRN-\|\[ERR-\|learnings/LEARNINGS" <編集した各ファイル>

# 禁止語（新規追加行のみを対象にする）
/usr/bin/git diff -U0 | /usr/bin/grep '^+' | /usr/bin/grep -E "『|』|オライリー|オーム社|技術評論|翔泳社|日経BP|インプレス"

# 注入内容の実在と削除行の正当性
/usr/bin/grep -c "<注入したキーワード>" <編集ファイル>
/usr/bin/git diff --stat && /usr/bin/git diff -U0 | /usr/bin/grep '^-' | /usr/bin/grep -v '^---'
```

## Phase 5: エントリ削除・リリース

1. 消費済みエントリを削除し、ヘッダ＋「恒久化先」の注記を残す（作業中に生まれた新知見は、その場で新エントリとして記録してよい）
2. **（sumik-claude-plugin repo のみ）**変更したプラグインを version bump（コミット type 基準: fix → PATCH / feat → MINOR）し、3 ファイル同期・repo CLAUDE.md の期待値更新・同期チェックスクリプトを実行する
3. AskUserQuestion で git 書込を確認 → 承認後に実行:
   - コミットメッセージは Write でファイル化して `git commit -F <file>`（全角記号の `-m` 直渡しはパース崩れで不発）
   - 一般プロジェクトでは `.learnings/` を版管理しているか（`git ls-files .learnings` が非空か）で commit に含めるかを判断する（既定はローカル留置）。sumik-claude-plugin repo では commit に含める——global `~/.gitignore` に ignore されているため **`git add -f .learnings/...`**（tracked 済みなので安全）
   - タグは `git tag -m "<要約>" v<version>`（`tag.gpgsign=true` のため `-m` なしは `fatal: no tag message?` で失敗）
   - Bash は `dangerouslyDisableSandbox: true` で実行する
   - push 後に `git log -1 --format='%H %s'`・`git tag --points-at HEAD`・`git ls-remote origin` で**実体検証**する（exit 0 を信じない）

## 完了報告

以下を表形式で報告する:

- 消費エントリ数と内訳（反映済み＝削除のみ / 新規恒久化 / 保留）
- 恒久化先の一覧（ファイル × 追記内容の要約）
- 機械検証の結果（ダングリング / 禁止語 / 注入実在 / diff 統計）
- version・commit hash（リモート実体検証済みの旨を明記）
