# fff によるファイル検索（高速・frecency 順位付け）

## (1) fff とは何か

Rust 製の**常駐型**高速ファイル検索エンジン。プロセスを起動しっぱなしにし、warm cache とバックグラウンドのファイルシステムウォッチャーで差分更新する。500k ファイル級リポでも 10ms 未満の応答を謳う。検索結果は **frecency**（頻度・新しさ・git-dirty を加味したランキング）で並び、使えば使うほどランキングが賢くなる。

### ripgrep との違い

| 観点 | fff | ripgrep (rg) |
|------|-----|-------------|
| 動作形態 | 常駐（warm cache・差分更新） | 毎回プロセス起動 |
| 検索速度 | 10ms 未満（キャッシュ済み） | 数秒（.gitignore も毎回舐め直す） |
| 結果の順序 | frecency 順（使うほど賢くなる） | マッチ出現順 |
| 得意な用途 | 反復的な検索作業 | 単発・一度きりの検索 |

> **短距離走の rg、長距離戦の fff。**

### devkit での提供形態

`scripts/fff-mcp.sh` ラッパー経由で MCP サーバとして起動される。Claude Code では `mcp__plugin_devkit_fff__grep` のような名前のツールとして現れる。配布物は fff-mcp v0.9.5（ネイティブバイナリ）。

---

## (2) 3つの MCP ツールと引数スキーマ

### ツール① grep（デフォルト・ファイル内容検索）

**ファイルの CONTENTS を検索する。**識別子の定義・使用箇所・特定パターンを探す時に使う。具体的な名前やパターンがある場合はまずこれ。

| 引数 | 型 | 既定値 | 説明 |
|------|----|--------|------|
| `query` | string | **必須** | 検索テキスト。制約プレフィックスをインラインで前置可 |
| `maxResults` | number | 20 | 一致行の上限 |
| `output_mode` | string | `'content'` | 出力形式 |
| `cursor` | string | — | 前回結果の続き（ページネーション） |

> grep は**単一行内マッチ**。1クエリ＝1識別子（bare identifier）で検索する。

### ツール② find_files（ファイル名 fuzzy 検索）

**ファイル名を fuzzy 検索する（内容ではない）。**具体的な識別子が無い・ファイルを探したい時に使う。path プレフィックス（`'src/'`）や glob 制約（`'name **/src/*.{ts,tsx} !test/'`）に対応。

| 引数 | 型 | 既定値 | 説明 |
|------|----|--------|------|
| `query` | string | **必須** | fuzzy 検索クエリ。1〜2語が推奨。複数語は OR ではなく絞り込みの滝（各語でさらに narrow） |
| `maxResults` | number | 20 | 結果の上限 |
| `cursor` | string | — | ページネーション |

### ツール③ multi_grep（複数パターン OR 検索）

**複数パターンのいずれかに一致するファイルを一度に返す（OR・AND ではない）。**命名規則の違い（snake_case / PascalCase / camelCase）や 2つ以上の異なる識別子を同時に探す時に使う。

| 引数 | 型 | 既定値 | 説明 |
|------|----|--------|------|
| `patterns` | string[] | **必須** | OR で照合するパターン。リテラルテキスト（特殊文字をエスケープ**しない**） |
| `constraints` | string | — | ファイル制約（`'*.{ts,tsx} !test/'` 等）。可能な限り指定する |
| `context` | number | — | 各一致の前後コンテキスト行数 |
| `maxResults` | number | 20 | 結果の上限 |
| `output_mode` | string | `'content'` | 出力形式 |
| `cursor` | string | — | ページネーション |

> ⚠️ `mode`（plain/regex/fuzzy）引数は **MCP ツールには存在しない**。Neovim/SDK 側 API であり混同しないこと。

---

## (3) コアルール

### ルール 1: bare identifier だけで検索する

grep は単一行マッチのため、1クエリ＝1識別子。

```
✅ 良い例
  'InProgressQuote'     → 定義＋全使用箇所が出る
  'ActorAuth'           → enum/struct/全呼び出し箇所

❌ 悪い例
  'load.*metadata.*InProgressQuote'  → 複数トークンに跨る regex → 0件
  'ctx.data::<ActorAuth>'            → コード構文・過剰に具体的 → 0件
  'struct ActorAuth'                 → キーワード追加で enum/trait/type alias を取りこぼす
  'TODO.*#\d+'                       → 複雑な regex → 'TODO' で検索して目視フィルタ
```

### ルール 2: regex を避ける

本当に alternation（OR）が要る時以外、regex は使わない。`.*` `\d+` `\s+` 等は単一行内マッチを試みてほぼ 0件になる。OR が要るなら multi_grep にリテラルパターンを渡す。

### ルール 3: grep は 2回までで打ち切り、Read する

2回 grep すれば十分なパス候補が揃う。トップ結果を読んで理解する。バリエーションを足して grep し続けない（**grep 回数 ≠ 理解度**）。

### ルール 4: 複数識別子は multi_grep で 1回

```
✅ multi_grep(['ActorAuth', 'PopulatedActorAuth', 'actor_auth'])

❌ grep('ActorAuth') → grep('PopulatedActorAuth') → grep('actor_auth') と 3連発しない
```

### 推奨ワークフロー

| 状況 | 手順 |
|------|------|
| 具体的な識別子名がある | `grep` で bare identifier を検索 |
| 名前のバリアントが複数 | `multi_grep` に全バリアントを 1回で渡す |
| トピック探索・ファイルを探したい | `find_files` |
| 結果が出た | トップのファイルを `Read`。再 grep しない |

---

## (4) 制約構文

### grep / find_files: 検索テキストの前にインライン前置

```
'*.rs query'           → .rs ファイルのみで query を検索
'src/ query'           → src/ 配下のみで query を検索
'schema.rs TODO'       → schema.rs 内の TODO を検索
'!test/ query'         → test/ を除外して query を検索
'!*.spec.ts query'     → .spec.ts を除外して query を検索
```

### multi_grep: 別引数 `constraints` に指定

```json
{
  "patterns": ["ActorAuth", "actor_auth"],
  "constraints": "*.{ts,tsx} !test/"
}
```

### 制約の形式

| 形式 | 例 | 意味 |
|------|----|------|
| 拡張子 | `*.rs` / `*.{ts,tsx}` | 指定拡張子のみ |
| ディレクトリ | `src/` / `quotes/` | **末尾スラッシュ必須** |
| ファイル名 | `schema.rs` / `src/main.rs` | 特定ファイルのみ |
| 除外 | `!test/` / `!*.spec.ts` | 除外パターン |

### ⚠️ よくある罠: 裸の単語は制約にならない

```
❌ 'quote TODO'    → リテラル 'quote TODO' を探してしまう（ノーヒット）
✅ 'quotes/ TODO'  → quotes/ ディレクトリ内の TODO を検索
✅ '*.ts TODO'     → .ts ファイル内の TODO を検索
```

拡張子（`*.ext`）・スラッシュ（`dir/`）・除外（`!...`）のない裸の単語は制約として機能しない。

### 制約は広めに指定する

```
✅ '*.rs query'              → ファイル型で絞る（適切）
✅ 'quotes/ query'           → トップ階層ディレクトリで絞る
❌ 'quotes/storage/db/ query' → 具体的すぎて取りこぼす
```

### デフォルト除外（結果がノイズの時）

```
!tests/       → tests ディレクトリを除外
!*.spec.ts    → テストファイルを除外
!generated/   → 生成コードを除外
```

---

## (5) 出力の読み方

- grep 結果は定義を本文コンテキスト付き（struct フィールド・関数シグネチャ）で自動展開する。多くの場合、追加の `Read` なしで十分な情報が得られる。
- `|` 始まりの行: 定義の本文コンテキスト行
- `[def]`: 定義ファイルを示すラベル
- `-> Read` 提案: 最も関連するファイルへの誘導。もっと文脈が必要な時は従う

---

## (6) 他検索手段との使い分け

| 状況 | 使う手段 |
|------|---------|
| コード内容のキーワード・識別子検索（最優先・最速・frecency 順） | **fff grep** |
| ファイル名で探す（識別子不明・ファイルを探したい） | **fff find_files** |
| 命名規則違い（snake/Pascal/camel）・複数識別子を一度に | **fff multi_grep** |
| シンボル単位の意味的検索・参照検索・定義ジャンプ・リネーム等の編集 | **serena**（MCP） |
| 単純なパスパターンの列挙（glob で足りる） | **Glob ツール** |
| fff MCP が無い環境・ごく単発の検索 | **ripgrep(rg) / 組込 Grep ツール** |

> **fff と serena は補完関係。**「どこにあるか」を速く広く当てるのが fff、「シンボルとして何か・どう参照されるか」を構造的に扱うのが serena。

---

## (7) DB 永続化と起動オプション

`scripts/fff-mcp.sh` ラッパーが起動を担うため、通常は意識不要。

### 永続化 DB

| DB | 既定パス | 役割 |
|----|---------|------|
| frecency DB | `~/.cache/fff/frecency.db` | 検索ランキング学習（使うほど賢くなる） |
| history DB | `~/.local/share/fff/history.db` | 検索履歴 |

### 主要オプション（ラッパーが設定済み・通常意識不要）

| オプション | 説明 |
|-----------|------|
| `--frecency-db` | frecency DB パス指定 |
| `--history-db` | history DB パス指定 |
| `--no-watch` | ファイルシステムウォッチャー無効 |
| `--no-warmup` | mmap warmup 無効 |
| `--max-cached-files` | キャッシュ上限（既定 30000・env: `FFF_MAX_CACHED_FILES`） |
| `--no-update-check` | 起動時の更新チェック無効（常時稼働安定化） |
| `--healthcheck` | 診断して終了 |

### インデックス対象

起動時の作業ディレクトリ（cwd）をインデックスする。Claude Code は通常プロジェクト直下で MCP を起動するため自然に正しい。Codex 等で意図しないディレクトリをインデックスする場合は、対象プロジェクトのルートでクライアントを起動すること。

---

## (8) トラブルシュート

| 症状 | 原因 | 対処 |
|------|------|------|
| ツールが現れない | fff-mcp 未導入（ラッパーが初回起動時に自動取得するが失敗した） | `brew install dmtrKovalenko/fff/fff-mcp` または公式インストーラ `curl -fsSL https://raw.githubusercontent.com/dmtrKovalenko/fff.nvim/main/install-mcp.sh \| bash` |
| 0件ばかり返る | regex や複数トークンで検索している | bare identifier に直す。OR が要るなら multi_grep にリテラルパターンを渡す |
| 結果がノイズだらけ | 制約なしで全ファイルを検索している | `!tests/` 等で除外、または `*.ext` / `dir/` で絞り込む |
