# マルチプラグイン構成の管理ガイド（分割・追加）

1 つの marketplace から **複数プラグイン**を配布するリポジトリの管理ガイド。INSTRUCTIONS.md の各章が単一プラグイン前提で書かれているのに対し、本ファイルは「1 repo・N プラグイン」構成の解剖・分割判断・分割/追加レシピ・クロスプラグイン preload・Codex 配布・version 同期・検証ゲートを汎用かつ将来耐性のある形で扱う。

- スキルのリネーム/統合/削除に伴う参照追従は [CROSS-REFERENCE-INTEGRITY.md](CROSS-REFERENCE-INTEGRITY.md) を参照（本ガイドはプラグイン**間**移動の上位視点を扱い、参照層の詳細は同ファイルに委ねる）。
- ファイル構造と Progressive Disclosure の原則は [STRUCTURE.md](STRUCTURE.md) を参照。

---

## (a) マルチプラグイン repo の解剖

1 つの marketplace を 1 リポジトリで運用し、その配下に **N 個のプラグイン**を `plugins/<plugin>/` として並置する。各プラグインは独立した配布単位（独立 version・独立 README・独立 manifest）であり、リポジトリルートに「全プラグインを列挙する共有 marketplace 定義」を 2 つ（Claude 用・Codex 用）置く。

```
<repo-root>/
├── .claude-plugin/marketplace.json     # ★ 共有: Claude が読む marketplace（全プラグインを name+source で列挙）
├── .agents/plugins/marketplace.json    # ★ 共有: Codex が読む marketplace（全プラグインを name+source+version で列挙）
├── .cache/<marketplace>/<plugin>       # 各プラグインの Codex source.path symlink（git 同梱・後述）
├── .gitignore                          # .cache/** を ignore しつつ各 symlink を negation で打ち消す
└── plugins/
    ├── <pluginA>/                      # プラグイン = 独立配布単位
    │   ├── .claude-plugin/plugin.json  # Claude 用マニフェスト（name/description/version/author）
    │   ├── .codex-plugin/plugin.json   # Codex 用マニフェスト（skills パス・任意 mcpServers）
    │   ├── README.md                   # プラグイン単位の README
    │   ├── skills/                      # 必須でない: skills-only プラグインはこれだけ
    │   ├── commands/ agents/ hooks/     # 任意: 持つプラグインと持たないプラグインが混在してよい
    │   ├── bin/                         # 任意: MCP 起動ラッパー等
    │   ├── .mcp.json                    # 任意: Claude 用 MCP 設定
    │   └── .mcp-codex.json              # 任意: Codex 用 MCP 設定
    └── <pluginB>/ ...                  # 同型の兄弟プラグイン
```

### プラグインごとに構成が異なってよい

マルチプラグイン構成の要点は「すべてのプラグインが同じ部品を持つ必要はない」こと。

| 構成タイプ | 持つもの | 例 |
|-----------|---------|-----|
| フル装備プラグイン | skills + commands + agents + hooks + bin + MCP(x2) | agent/コマンド/hook/MCP を提供する中核プラグイン |
| ドキュメント・素材系 | skills + commands + bin + MCP(x2) | 図表生成等で MCP のみ必要なプラグイン |
| skills-only プラグイン | skills + README + manifest(x2) のみ | ドメイン知識スキル群だけを束ねるプラグイン |

skills-only プラグインは `.mcp.json` / `.mcp-codex.json` / `bin/` / `commands/` / `agents/` / `hooks/` を**作らず**、`.codex-plugin/plugin.json` から `mcpServers` キーも省略する。manifest が空配列より「キー不在」のほうが意図が明確。

### plugin-root スタイルの 2 系統（混在可）

Codex の plugin root（manifest と skills を解決する基準ディレクトリ）には 2 系統があり、同一 repo 内で混在してよい:

| スタイル | symlink ターゲット | manifest 位置 | skills パス | 使いどころ |
|---------|------------------|--------------|------------|-----------|
| **repo-root スタイル** | `../..`（repo ルート） | ルートの `.codex-plugin/plugin.json` | `"./plugins/<plugin>/skills/"` | 中核プラグインが repo ルートの清潔なマニフェストを共有する場合 |
| **subdirectory スタイル** | `../../plugins/<plugin>` | `plugins/<plugin>/.codex-plugin/plugin.json` | `"./skills/"` | 後から追加した兄弟プラグイン（自己完結・推奨） |

> 新規追加プラグインは **subdirectory スタイル**を推奨する（プラグインディレクトリ内で自己完結し、ルートを汚さない）。

> 🔴 repo-root スタイルの罠: `.cache/<marketplace>/<plugin> → ../..` の symlink は**自己再帰パス**を作る（`.cache/<mp>/<plugin>/.cache/<mp>/<plugin>/...` と無限に潜れる）。symlink を追跡するツール（コード分析 MCP の activate 等）がこの再帰を辿って `File name too long` で起動失敗する原因になる。該当ツール側に `.cache/` 除外を設定するか、そもそも subdirectory スタイル（この罠が構造的に発生しない）を選ぶ。

---

## (b) いつ分割・追加するか（結合度ティア）

プラグインを分割・追加する動機は「配布単位の凝集」と「ルートの肥大抑制」。判断の中心は **スキルとエージェントの結合度**である。スキルが「どのエージェントから preload されているか」で移動コストが決まる。

### 分割・追加のトリガー

| トリガー | 説明 |
|---------|------|
| 単一プラグインのスキル数が肥大 | 1 プラグインに数十スキルが集中し、ドメイン凝集で切り出せる塊がある |
| ドメインで明確に区切れる | 言語・クラウド・AI・デザイン等、関心事が独立した束が存在する |
| 配布粒度を分けたい | 一部利用者には特定ドメインのスキルだけを配りたい |

### 結合度ティア（移動コストの早見表）

| ティア | スキルの性質 | エージェント結合 | 移動コスト | 扱い |
|-------|------------|----------------|-----------|------|
| **ユニバーサルコア** | 多くのエージェントが preload する横断スキル（クリーンコード・テスト・型安全・セキュリティ・文章作法等） | 多数のエージェントに密結合 | 高 | **エージェントと同じプラグインに留める**（分割しない） |
| **ドメインスキル** | 単一ドメインの実装知識（特定言語・特定クラウド等） | 1〜数エージェントに結合 | 低 | 切り出しが安い。preload する側を `plugin:skill` へ修飾すれば移動可 |
| **メタ/リファレンス** | エージェントから一切 preload されない参照系（プラグイン作成ガイド・命名規則集等） | エージェント結合ゼロ | 最低 | 最も安価。修飾すべき preload 参照すら無い |

> 原則: **ユニバーサルコアはエージェントの近く（同一プラグイン）に置く**。多数の `plugin:skill` 修飾が発生し、1 つの修飾漏れが preload 失敗（空注入）を生むため。ドメインスキル・メタスキルから切り出していくのがセオリー。

---

## (c) 汎用の分割/追加レシピ（順序付きフェーズ）

新規プラグインを「立てる（追加）」場合も、既存プラグインから「切り出す（分割）」場合も、フェーズは共通。スキルを移さない純粋な新規追加では Phase 2（mv）と Phase 3（修飾）が空になるだけ。

### Phase 1: scaffold（土台作成）

1. `mkdir -p plugins/<plugin>/skills`（skills-only の場合）。必要なら `commands/ agents/ hooks/ bin/` も作る。
2. 2 つの manifest を Write:
   - `plugins/<plugin>/.claude-plugin/plugin.json`（`name` / `description` / `version` / `author`）
   - `plugins/<plugin>/.codex-plugin/plugin.json`（`name` / `version` / `description` / `skills: "./skills/"` / 任意 `keywords` / `interface`。MCP がなければ `mcpServers` を**書かない**）
3. `plugins/<plugin>/README.md` を Write（タイトル + 概要 + インストール手順 + ディレクトリ構成 + スキル一覧表 + 依存関係メモ）。

### Phase 2: スキルディレクトリを移動（plain `mv` / R100 rename）

```bash
# リポジトリルートで実行（cd を先頭に置かない）
mv plugins/<src>/skills/<skill>  plugins/<plugin>/skills/
```

- **`git mv` ではなく plain `mv`** を使う。git は内容同一の移動を R100 rename として自動検出する。スキル内バンドル（`scripts/install.sh` 等の skill ディレクトリ配下の相対参照ファイル）は一緒に動き rename に含まれる。
- 全 git-index 書込（add/commit）は**ユーザー確認後の最終 commit まで遅延**する。移動直後は `git status` で R100 rename が並ぶことだけ確認する。

### Phase 3: preload するエージェント `skills:` と hook を `plugin:skill` へ修飾

移動したスキルを preload しているエージェントの `skills:` リスト項目を `plugin:skill` 形式へ書き換える。移動しないスキルは bare のまま。

```yaml
skills:
  - <plugin>:<moved-skill>     # 別プラグインへ移動 → 修飾
  - writing-clean-code         # 同一プラグインに残留 → bare 維持
  - studio:writing-latex       # 既存の別プラグイン参照 → 維持
```

- アンカーは絶対行番号でなく `  - <skillname>` のリスト項目文字列にする（ファイル内で一意・順序とインデント維持）。
- hook（`detect-project-skills.sh` 等）も同様に **3 サイト**（GROUP 配列リテラル・`get_skill_description` の case ラベル・`PROJECT_SKILLS+=` push サイト）を**すべて同じ修飾文字列に揃える**。push が `web:developing-react` なのに case ラベルが `"developing-react"` のままだと、エラーを出さず空 description になる（サイレント破損）。

### Phase 4: marketplace にエントリ追加（Claude + Codex）

1. `.claude-plugin/marketplace.json` の `plugins` 配列に追加（`name` / `source: "./plugins/<plugin>"` / `description`）。
2. `.agents/plugins/marketplace.json` の `plugins` 配列に追加（`name` / `source.source: "local"` / `source.path: "./.cache/<marketplace>/<plugin>"` / `version` / `description` / `policy` / `category`）。

### Phase 5: `.cache` symlink + `.gitignore` negation 行（symlink ごと）

```bash
ln -s ../../plugins/<plugin>  .cache/<marketplace>/<plugin>   # subdirectory スタイル
```

`.gitignore` に negation 行を **symlink ごと 1 行**追加する:

```
.cache/**
!.cache/
!.cache/<marketplace>/
!.cache/<marketplace>/<plugin>     # ← 新 symlink ごとに 1 行
```

> 🔴 罠: negation 行を追加し忘れると新 symlink が黙って ignore され、`git add` から漏れ、clone に含まれず Codex の `source.path` が壊れる。`git check-ignore` は negation でも exit 0 を返すため判定に使わない。commit 後に `git ls-tree`（Phase 9 / (g)）で実体検証する。

### Phase 6: version 1.0.0 を設定し 3 ファイルを同期

新規プラグインは `1.0.0` から始める。プラグイン**ごとに**自分の 3 ファイル（Claude manifest / Codex manifest / Codex marketplace カタログの当該エントリ）を同じ値に揃える（詳細は (f)）。

### Phase 7: README 群と repo CLAUDE.md を更新

- 新規プラグインの per-plugin README を確定（Phase 1 で作成済み）。
- 分割元プラグインの README を更新（スキル一覧表から移動行を削除・カウント調整・subtable 再構成・install 行追記）。
- repo の `CLAUDE.md`（ディレクトリ構成 tree・version 同期表・Codex 配布 note・プラグイン数の prose）を N プラグイン化。

### Phase 8: 外部 dotfiles を更新

ルーティング表・ルールファイルが**移動スキルを bare 名で参照**している場合、`plugin:skill` へ修飾する。詳細な対象とパターンは INSTRUCTIONS.md「外部設定ファイル同期」節と [CROSS-REFERENCE-INTEGRITY.md](CROSS-REFERENCE-INTEGRITY.md) の Layer 5 を参照。

### Phase 9: 検証 → commit

(g) の検証ゲートを全通過させてから、ユーザー明示確認の上で commit（git 書込はユーザー依頼時のみ）。

---

### (c-2) 既存プラグインへ新スキルを追加する時の同期チェックリスト

既存 skills-only プラグイン（例: `lang`）へ 1 スキルだけを追加する軽量な変更でも、スキルディレクトリ作成だけでは**配布面**と**自動ロード面**が不完全になる。以下を同一タスク内で同期する。

1. **version 3 ファイル同期**: 当該プラグインの Claude manifest / Codex manifest / Codex marketplace カタログを揃える（新規スキル追加 = MINOR）。
2. **Claude marketplace description**: `.claude-plugin/marketplace.json` には version が無いが、**利用者向け description の内容列挙**（対応言語一覧等）を新スキル分だけ更新する。
3. **README/CLAUDE.md のスキル数**: per-plugin README・root README・repo CLAUDE.md のディレクトリ構成 tree・スキル一覧テーブル・カウント見出しの実数を一致させる。
4. **SessionStart hook の自動検出**: `detect-project-skills.sh` に新スキルの 3 サイト（advisory 説明の case ラベル・検出ファイルパターン・push サイト）を追加する。パターン例: `.R` / `renv.lock` のような言語固有の拡張子・設定ファイル。3 サイトが不一致だとエラーを出さず空 description になる（(d) と同じサイレント破損の罠）。
5. **検証セット**: JSON parse・version 3 点同期（(f)）・description 1024 字以内・スキル数実数（`ls -d plugins/<plugin>/skills/*/ | wc -l`）・一時プロジェクトでの hook 検出動作・禁止語 grep を一括実行する。

---

## (d) クロスプラグイン preload（`plugin:skill` 修飾名）

別プラグインに住むエージェントから別プラグインのスキルを preload するには、`skills:` リスト項目を **`plugin:skill` 修飾名**で書く。

```yaml
# devkit のエージェントが lang プラグインのスキルを preload する例
skills:
  - lang:developing-python      # 別プラグインのスキル → 修飾名
  - cloud:developing-aws
  - writing-clean-code          # 自プラグインのスキル → bare
```

- この修飾形式によるクロスプラグイン preload は**検証済み**（debug log に `Preloaded skill <plugin>:<skill>` が出力され、skip warning が出ない）。
- hook の advisory text（自動推奨で表示するスキル名）も**同じ修飾形式**を使う。push サイト・配列・case ラベルすべてを修飾文字列で統一する。
- エージェント本文 prose 内のスキル名見出し（`### developing-python skill usage` 等）は **preload を発火しない**ため、移動時の修飾は任意（整形フォローアップ）。preload を司るのは frontmatter の `skills:` リストと hook の 3 サイトのみ。

---

## (e) Codex マルチプラグイン配布の固有事項

Codex CLI への配布はマルチプラグインでも 1 プラグインの作法を踏襲するが、以下が固有の罠になる。

| 項目 | 規約 |
|------|------|
| plugin-root スタイル | 新規プラグインは **subdirectory スタイル**（symlink ターゲット `../../plugins/<plugin>`・manifest を `plugins/<plugin>/.codex-plugin/plugin.json` に置き・skills は `"./skills/"`） |
| symlink ごとの gitignore negation | `.cache/<marketplace>/<plugin>` を git 同梱するため、negation 行を symlink ごと 1 行追加（Phase 5） |
| 🔴 MCP 設定で変数を使わない | Codex は plugin-root 変数を**展開しない**（非展開で `os error 2`）。Codex 用 MCP 設定は相対パス + `"cwd"` で書く。skills-only プラグインは MCP 設定自体を持たないので該当しない |
| git-source の marketplace スナップショット | Codex marketplace は git source。**repo を push 後**に install スクリプトで marketplace を add/upgrade してプラグインを取り込む。revert を push すれば AVAILABLE から消える |
| 検証 | `codex plugin list` で新プラグインが見えること、`git ls-tree -r HEAD --name-only` で `.cache/<marketplace>/<plugin>` symlink が全列挙されることを確認（(g)） |
| 実アクティブパスの検証 | プラグインの版・内容の確認は `codex plugin list` の **PATH 列**で実体パスを特定して行う。`~/.codex/plugins/cache/...` は陳腐化した別キャッシュで信用しない |
| marketplace 更新直後の一斉 `os error 2` | git marketplace の更新と plugin MCP 起動が競合すると、versioned cache の実行ファイル作成前に MCP を spawn してしまい、同梱サーバーが一斉に `No such file or directory (os error 2)` になることがある（一時的）。**設定ファイルを書き換えず**、cache 実在を確認して Codex を新規起動すれば解消する |

> skills-only プラグインは MCP を持たないため `.mcp-codex.json` を作らず、`.codex-plugin/plugin.json` に `mcpServers` を書かない。MCP を持つプラグインのみ「変数を使わない」罠が該当する。

### MCP 同梱プラグインの新規追加手順

MCP サーバーを同梱するプラグインを新設する場合、(c) の共通フェーズに加えて以下を行う。

**1. ランナー別 bin ラッパーを既存プラグインから複製する**

MCP サーバーの起動ランナーに応じて、既存プラグインの `bin/` からラッパーを `plugins/<plugin>/bin/` へ複製する（mise があれば mise 経由、無ければ素のランナーへフォールバックする同型構造。実行ビット維持）:

| ランナー | ラッパー | 複製元の例 |
|---------|---------|-----------|
| npx 系（npm パッケージ） | `npx-mise.sh` | devkit / studio |
| uvx 系（Python / uv） | `uvx-mise.sh` | devkit |
| pipx 系（Python / pipx run） | `pipx-mise.sh` | google |

**2. Claude 用 / Codex 用の MCP 設定を分けて書く**

| ファイル | `command` の書き方 |
|---------|-------------------|
| `plugins/<plugin>/.mcp.json`（Claude 用） | `"${CLAUDE_PLUGIN_ROOT}/bin/<wrapper>.sh"` |
| `plugins/<plugin>/.mcp-codex.json`（Codex 用） | `"./bin/<wrapper>.sh"` + `"cwd": "."`（plugin root 基準の相対パス） |

🔴 Codex 側で `${CLAUDE_PLUGIN_ROOT}` を**使わない**（Codex は変数を展開せず `os error 2` になる — (e) の罠と同一）。`.codex-plugin/plugin.json` には `"mcpServers": "./.mcp-codex.json"` を記述する（skills-only との違い）。

**3. `env` ブロックを置かない（秘匿値はシェル環境の継承で供給）**

`.mcp.json` / `.mcp-codex.json` のサーバー定義に `env` ブロックを置かない。秘匿値（例: `GOOGLE_APPLICATION_CREDENTIALS` / `GOOGLE_PROJECT_ID`）はシェルで `export` した値を MCP サーバーが親プロセス環境として継承する（既存の MCP 同梱プラグインすべてが `env` 無しの確立済み慣習）。`${VAR:-}` 展開は未設定時に**空文字**が渡り ADC 認証等を壊すリスクがあるため非推奨。

**実例（google プラグイン・`pipx run analytics-mcp`・subdirectory + MCP 方式）:**

```jsonc
// plugins/google/.mcp.json（Claude 用）
{ "mcpServers": { "google-analytics": {
    "command": "${CLAUDE_PLUGIN_ROOT}/bin/pipx-mise.sh",
    "args": ["analytics-mcp"] } } }

// plugins/google/.mcp-codex.json（Codex 用）
{ "mcpServers": { "google-analytics": {
    "command": "./bin/pipx-mise.sh",
    "args": ["analytics-mcp"],
    "cwd": "." } } }
```

---

## (f) version 同期はプラグイン**ごと**に

各プラグインは独立した version 系列を持つ。プラグインごとに**自分の 3 ファイル**を同一値に揃える（他プラグインの version とは無関係に進む）。

| ファイル | 役割 |
|---------|------|
| `plugins/<plugin>/.claude-plugin/plugin.json` の `version` | Claude が読む version |
| `plugins/<plugin>/.codex-plugin/plugin.json` の `version` | Codex CLI が読む version |
| `.agents/plugins/marketplace.json` の `plugins[name=<plugin>].version` | Codex marketplace カタログ version（**更新漏れしやすい**） |

> repo-root スタイルの中核プラグインは Claude manifest がルートでなくプラグイン配下にあるか配置が異なる場合があるが、「3 ファイルを揃える」原則は同じ。version bump 前に現行値を実ファイルまたは `git show HEAD:<path>` から読む（HEAD で既に bump 済みのことがある）。

### N プラグイン一括同期チェック（コピペ可能）

```bash
python3 - <<'PY'
import json
# (plugin, claude_manifest, codex_manifest, expected_version) を列挙
plugins = [
    # ("<plugin>", "plugins/<plugin>/.claude-plugin/plugin.json",
    #              "plugins/<plugin>/.codex-plugin/plugin.json", "1.0.0"),
]
cat = json.load(open(".agents/plugins/marketplace.json"))
def cat_ver(name):
    return next(p["version"] for p in cat["plugins"] if p["name"] == name)
all_ok = True
for name, claude_path, codex_path, expected in plugins:
    vals = [
        json.load(open(claude_path))["version"],
        json.load(open(codex_path))["version"],
        cat_ver(name),
    ]
    ok = len(set(vals)) == 1 and vals[0] == expected
    all_ok &= ok
    print(f"{name:10} {'OK ' if ok else 'MISMATCH'} {vals} (expected {expected})")
print("ALL OK" if all_ok else "FAILED")
PY
```

---

## (g) 検証ゲート

分割/追加の commit 前に全項目を通す。クロスプラグイン preload は検証済みメカニズムのため重い再検証は不要だが、構造系の検証は必須。

| # | 検証 | コマンド/手順 | 合格基準 |
|---|------|--------------|---------|
| 1 | クロスプラグイン preload 確認 | Claude を **2 つの `--plugin-dir` フラグ**（移動元・移動先プラグインの両方）で起動し debug log を見る | `Preloaded skill <plugin>:<skill>` が出る・skip warning が出ない |
| 2 | JSON 妥当性 | 全 manifest を `python3 -c "import json; json.load(open(p))"` | 全ファイル parse 成功 |
| 3 | ダングリング参照 grep | 移動スキル名の **bare 残存**を `/usr/bin/grep -rn` で agents/hook/SKILL.md/README/dotfiles に探索 | 想定箇所以外に bare 残存なし（[CROSS-REFERENCE-INTEGRITY.md](CROSS-REFERENCE-INTEGRITY.md) のスキャン） |
| 4 | version 同期（per plugin） | (f) の python snippet | 全プラグイン `OK` + `ALL OK` |
| 5 | symlink git 追跡 | `git ls-tree -r HEAD --name-only \| /usr/bin/grep '^.cache/'`（commit 後） | 全プラグインの symlink が列挙される |
| 6 | 実行ビット維持 | `ls -l plugins/<plugin>/skills/<skill>/scripts/*.sh` | 移動後も実行可能ビット維持 |
| 7 | スキル数カウント | `ls -d plugins/<plugin>/skills/*/ \| wc -l` | 割当数と一致 |
| 8 | hook 整合 | 修飾 case ラベル数 = 修飾 push/配列 skill 数 | 一致・SessionStart で空 description が出ない |
| 9 | 固有名チェック | `/usr/bin/grep -nE "『\|』\|著\|出版"` を全変更ファイルに（多角パターンは [CROSS-REFERENCE-INTEGRITY.md](CROSS-REFERENCE-INTEGRITY.md) §④） | 0 hit（OSS 帰属・library 名は別途確認の上で許容） |

> 🔴 git 書込（add/commit/tag/push）は**ユーザー明示確認後のみ**実行する。`exit=0` を鵜呑みにせず `git log -1` 等で実体検証する。
