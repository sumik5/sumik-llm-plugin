---
description: >-
  software-security スキル（Project CodeGuard 日本語版）を上流 cosai-oasis/project-codeguard と同期するコマンド。
  記録済み基準コミットと上流 main を gh compare で突き合わせ、変更された rule ファイルだけを再取得→
  初回と同一の翻訳CONTRACT（凍結境界・用語集）で日本語へ再翻訳し、SKILL.md・ATTRIBUTION・version を更新する。
  Use when refreshing the software-security skill against upstream Project CodeGuard updates, or
  periodically checking whether the bundled CodeGuard rules have drifted from the source repository.
  差分のみ再翻訳・全件再翻訳の無駄撃ち回避・帰属表示の改変ログ追記・diff提示→承認→version bump→commit+tag まで一気通貫。
allowed-tools: Read, Edit, Write, Glob, Grep, Bash, AskUserQuestion
user-invocable: true
argument-hint: "[--check（差分確認のみ・更新しない） | 補足メモ]"
---

# /update-software-security

`software-security` スキル（`plugins/devkit/skills/software-security/`）を上流 [cosai-oasis/project-codeguard](https://github.com/cosai-oasis/project-codeguard)（CC-BY-4.0・日々更新）と同期する自己完結コマンド。

## 概要

| 項目 | 内容 |
|------|------|
| 対象スキル | `plugins/devkit/skills/software-security/`（`SKILL.md` + `rules/*.md`） |
| 同期元 | `cosai-oasis/project-codeguard` の `skills/software-security/` |
| 基準点 | `SKILL.md` frontmatter の `codeguard-commit`（記録済み上流コミットSHA） |
| 差分検知 | `gh api .../compare/<基準SHA>...main` で変更ファイルのみ抽出 |
| 翻訳方針 | 初回と同一の CONTRACT（下記）で**変更ファイルのみ**再翻訳 |
| 出力 | スキル更新・ATTRIBUTION改変ログ追記・version bump（3ファイル同期）・commit・tag |

`$ARGUMENTS` に `--check` が含まれる場合は**差分の報告のみ**を行い、ファイルは一切変更しない。

---

## ワークフロー

### Step 1: 基準点の取得

`plugins/devkit/skills/software-security/SKILL.md` の frontmatter から以下を読む:

```bash
DST=plugins/devkit/skills/software-security
/usr/bin/grep -E "^codeguard-(version|commit):" "$DST/SKILL.md"
```

- `codeguard-commit`（例 `a557e7ea...`）= 前回同期した上流コミットSHA = **差分の基準点**
- `codeguard-version`（例 `1.3.1`）= 上流フレームワークのバージョン表示

`gh` 認証が無い場合はここで中断し、ユーザーに `gh auth login` を促す。

### Step 2: 上流の差分検知

```bash
BASE=<codeguard-commit の値>
# 上流 main の最新 SHA
gh api repos/cosai-oasis/project-codeguard/commits/main --jq '.sha'
# 基準...main の差分（software-security 配下のみ）
gh api "repos/cosai-oasis/project-codeguard/compare/${BASE}...main" \
  --jq '.status, (.files[]? | select(.filename|startswith("skills/software-security/")) | .status + "\t" + .filename)'
```

- `status` が `identical`（差分なし）→ 「既に最新」と報告して**終了**。
- `skills/software-security/` 配下に変更がある場合のみ次へ進む。`.files[].status` は `added` / `modified` / `removed` / `renamed`。
- 上流の `skills/software-security/SKILL.md` 自体が変わっていれば、ルーティング表（タグ別・言語別）に新言語/新タグ/新ルールが増えた可能性があるため必ず確認する。

`--check` の場合: ここで変更ファイル一覧・上流最新SHA・現基準SHAを表で提示して**終了**。

### Step 3: 変更ファイルの取得と再翻訳

上流の最新コンテンツを取得（tarball 推奨・API無駄撃ち回避）:

```bash
mkdir -p .tmp-cg-sync
gh api repos/cosai-oasis/project-codeguard/tarball/main > .tmp-cg-sync/cg.tar.gz
tar xzf .tmp-cg-sync/cg.tar.gz -C .tmp-cg-sync
# 展開ルート: .tmp-cg-sync/cosai-oasis-project-codeguard-<sha>/
```

> ⚠️ **cwドリフト注意**: `cd` を使わず**絶対パス**で操作する。Bash ツールはコール間で作業ディレクトリが持続するため、`cd .tmp-cg-sync` は次コール以降のパスを破壊する。

変更種別ごとの処理:

| status | 処理 |
|--------|------|
| `added` / `modified` | 上流英語版を取得し、下記 CONTRACT で日本語へ翻訳して `rules/<name>` へ上書き |
| `removed` | ローカル `rules/<name>` を削除（`SKILL.md` のルーティング表からも該当行/参照を除去） |
| `renamed` | 旧名を削除し新名で追加翻訳。ファイル名は**英語のまま維持**（このスキルの規約） |
| `SKILL.md` 変更 | 上流の新ルーティング表（タグ/言語/ファイル対応）を反映。本文は日本語へ再翻訳、frontmatter の devkit 拡張（`name`/`license`/`source`/`codeguard-commit` 等）と帰属注記ブロックは保持 |

独立した複数ファイルは**並列タチコマ**（general-purpose, model: sonnet）に担当ファイルを排他割当して翻訳させてよい（初回と同じ scribe 分担パターン）。各タチコマのプロンプトに下記 CONTRACT を丸ごと埋め込む。

### Step 4: 翻訳 CONTRACT（初回と同一・厳守）

**翻訳する**: 見出しテキスト・本文の散文・箇条書きの説明文・frontmatter の `description:` の値。

**絶対に翻訳せず凍結する（原文英語のまま）**:
- frontmatter のキー名、および `tags:` / `languages:` 配下の値（`secrets`, `authentication`, `web`, `infrastructure`, `c`, `go`, `java` 等）、`alwaysApply:` の真偽値
- `rule_id: codeguard-...` の行（識別子）
- コードブロック（``` ～ ```）の中身、インラインコード（`...`）、関数名・設定キー
- アルゴリズム名・規格名・技術トークン（Argon2id, scrypt, OAuth, OIDC, SAML, JWT, AES-GCM, CWE-xx, OWASP 等）
- 数値・パラメータ（`m=19 MiB` 等）
- Markdown 構造（見出しレベル・表のパイプ・リスト記号）。行の追加/削除/並べ替え禁止（原文と1対1対応）

**用語集（統一訳）**:
authentication=認証 / authorization=認可 / credential(s)=認証情報 / secret(s)=機密情報 / vulnerability=脆弱性 / input validation=入力検証 / injection=インジェクション / session=セッション / cookie=Cookie / token=トークン / hash, hashing=ハッシュ, ハッシュ化 / encryption=暗号化 / certificate=証明書 / sanitize=サニタイズ / escape=エスケープ / least privilege=最小権限 / supply chain=サプライチェーン / container=コンテナ / serialization=シリアライゼーション / deserialization=デシリアライゼーション / logging=ロギング / best practice(s)=ベストプラクティス / secure by default=セキュアバイデフォルト
強調語: NEVER=「絶対に〜してはならない」, MUST=「必ず〜する」, ALWAYS=「常に」 のニュアンスを保つ。

### Step 5: メタデータ更新

- `SKILL.md` frontmatter: `codeguard-commit` を上流最新SHAへ、上流の `codeguard-version` が変わっていれば `codeguard-version` も更新。
- `ATTRIBUTION.md`: 「取得時点」のコミット/バージョンを更新し、「原典からの変更点」に今回の同期日と変更ファイルを追記（CC-BY-4.0 の改変明示義務）。
- ルール数が増減した場合は `README.md` の該当記述（スキル説明の「全N ルール」等）を実数に合わせる。

### Step 6: 検証（機械突き合わせ・必須）

```bash
DST=plugins/devkit/skills/software-security
# 🔴 固有名チェック（書籍/著者/出版社）— このリポジトリの絶対ルール
/usr/bin/grep -rnE "『|』|著者|〜著|出版|オライリー|オーム社|技術評論|翔泳社|日経BP|インプレス|Effective [A-Z]" "$DST/SKILL.md" "$DST/rules/"
# ルーティング整合: SKILL.md 参照 = rules 実体（完全一致を確認）
/usr/bin/grep -oE "codeguard-[0-9]-[a-z-]+\.md" "$DST/SKILL.md" | sort -u > /tmp/refs.txt
ls "$DST/rules/" | sort > /tmp/actual.txt
comm -3 /tmp/refs.txt /tmp/actual.txt   # 出力が空なら一致
```

- 固有名チェックでヒットが LICENSE 本文（"Effective Technological Measures" 等の法的文言）のみであることを確認（スキル本文は0件であるべき）。
- ルーティング不一致（`comm -3` に出力）があれば SKILL.md を修正してから先へ進む。

### Step 7: version bump とコミット

- **bump 判定**: ルール内容の更新のみ=**PATCH** / 新ルール追加で適用範囲拡大=**MINOR**（`applying-semantic-versioning` スキル参照）。
- **3ファイル同期**（このリポジトリの🔴ルール）:
  - `plugins/devkit/.claude-plugin/plugin.json`
  - `.codex-plugin/plugin.json`
  - `.agents/plugins/marketplace.json` の `plugins[].version`
  - 同期確認スクリプトは CLAUDE.md「同期チェック」参照。
- **後始末**: `rm -rf .tmp-cg-sync`（絶対パス・コミット前に必ず撤去）。
- **diff 提示 → ユーザー承認**（git書込は確認必須）→ Conventional Commits でコミット（`feat`/`fix(software-security): 上流 <version> へ同期`）→ 必要なら tag。
- コミットメッセージ・本文に**書籍名・著者名・出版社名を含めない**（このリポジトリの絶対ルール）。

---

## 注意点

| If X | then Y |
|------|--------|
| 上流が `identical`（差分なし） | 何も変更せず「既に最新（codeguard <version> / <sha短縮>）」と報告して終了 |
| 上流 SKILL.md のルーティング表に新言語/新タグ | 該当行を追記し、新規参照ルールファイルの取得・翻訳漏れがないか Step 6 の `comm` で必ず検証 |
| 翻訳を並列タチコマに委譲 | 担当ファイルを排他割当し CONTRACT を全文埋め込む。完了後に本体が固有名grep・ルーティング整合を再検証（タチコマ自己申告を鵜呑みにしない） |
| `gh` 未認証・レート制限 | 中断してユーザーに通知（黙って部分更新しない） |
