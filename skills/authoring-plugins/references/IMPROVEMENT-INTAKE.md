# 改善提案INTAKE ガイド（スキル自己改善ループの消費側）

スキル改善提案を global `~/.claude/CLAUDE.md` の inbox セクションから取り込み、実際のスキル編集まで通す 5 ステップの実践ガイド。各章にコピペ可能なコマンドを収録する。

---

## 1. 位置づけ — 捕捉(C)→消費(D)の閉ループ

### 役割分担

| 役割 | 担当 | 場所 |
|------|------|------|
| **捕捉(C)** | global CLAUDE.md の「🔄メンテナンス」捕捉ルールがセッション中の気づきを拾い上げ inbox へ append | `~/.claude/CLAUDE.md` 内「## 📥 スキル改善提案 (inbox)」セクション |
| **消費(D)** | 本ガイドが inbox を読み込んでスキルを実際に改善する | `skills/` 配下の各スキルファイル |

> **inbox の場所**: `~/.claude/CLAUDE.md` 内のセクション（専用ファイルではない・ユーザー選択）。ファイルパスではなくセクション見出しで識別する。

### USAGE-REVIEW.md との棲み分け

| 観点 | 本INTAKE（消費側） | USAGE-REVIEW.md（棚卸し） |
|------|-------------------|--------------------------|
| 駆動タイミング | イベント駆動（open 3件 or ユーザー指示） | バッチ駆動（月次/四半期） |
| 起点 | CLAUDE.md inbox の提案エントリ | セッションログ分析・利用頻度統計 |
| 対象 | 特定の改善提案を消費 | ポートフォリオ全体の俯瞰・棚卸し |
| 統合 | しない（役割が異なる） | しない |

### 閉ループ流れ図

```
[セッション中の気づき]
        │
        ▼
[捕捉(C): CLAUDE.md 捕捉ルールが inbox へ append]
        │
        ▼  ← open 3件以上 or ユーザー指示
[消費(D): 本INTAKE が起動]
        │
        ├─ 取り込み＆トリアージ（Step 1）
        ├─ 規約検証（Step 2）
        ├─ 編集委譲（Step 3）
        ├─ 整合検証（Step 4）
        └─ 完了ワークフロー接続（Step 5）
                │
                ▼
        [スキル改善完了 + inbox クリーンアップ]
```

---

## 2. 入力フォーマット（提案エントリのスキーマ）

### エントリ構造

各提案は `~/.claude/CLAUDE.md` 内の「## 📥 スキル改善提案 (inbox)」セクションに以下の形式で記述する。

```markdown
## [PROPOSAL] <skill-name> / <種別> / <YYYY-MM-DD>

- skill: <skill-name>
- 種別: <description改善 | 分割 | 統合 | 内容追記 | 参照修正 | 規約違反>
- 改善点: <具体的な改善内容>
- 対象ファイル: <SKILL.md | INSTRUCTIONS.md | references/XXX.md 等>
- 理由: <なぜこの改善が必要か>
- 確度: <高 | 中 | 低>
- 影響範囲: <自スキルのみ | 他スキル参照 | hook | README | rules>
- status: <open | triaged | done | rejected>
```

### 8フィールド定義

| フィールド | 必須 | 説明 |
|-----------|------|------|
| `skill` | 必須 | 対象スキルのディレクトリ名（例: `authoring-plugins`） |
| `種別` | 必須 | 下記6値のいずれか |
| `改善点` | 必須 | 具体的に何をどう変えるか（抽象禁止） |
| `対象ファイル` | 必須 | 変更するファイルを明示（`SKILL.md`・`INSTRUCTIONS.md`・`references/XXX.md`等） |
| `理由` | 推奨 | なぜこの改善が必要か（省略時は `確度=低` として扱う） |
| `確度` | 推奨 | 高/中/低。高を優先処理 |
| `影響範囲` | 必須 | 整合検証（Step 4）の要否判定に使う |
| `status` | 必須 | ライフサイクル管理に使う（後述） |

### 種別の6値

| 種別 | 内容 |
|------|------|
| `description改善` | frontmatter description の文言・構成を変える |
| `分割` | 肥大化したファイルを複数に分離する |
| `統合` | 重複する複数スキルを1つにまとめる |
| `内容追記` | 既存ファイルに節・手順・例を追加する |
| `参照修正` | 壊れたリンク・ダングリング参照を修正する |
| `規約違反` | 書籍名・著者名・出版社名等の禁止事項を除去する |

### inbox からの見出し抽出

```bash
# open 件数確認（起動条件チェック）
grep -c "status: open" ~/.claude/CLAUDE.md

# 全提案見出しを一覧表示
grep "^## \[PROPOSAL\]" ~/.claude/CLAUDE.md

# open の提案のみ抽出（ブロックごと）
awk '/^## \[PROPOSAL\]/{block=$0; next} block{block=block"\n"$0} /status: open/{print block; block=""} /^## \[PROPOSAL\]/{block=$0}' \
  ~/.claude/CLAUDE.md
```

---

## 3. 起動条件と抑制

### 起動条件

以下のいずれかを満たす時に INTAKE を開始する。

| 条件 | 確認コマンド |
|------|------------|
| `status: open` が **3件以上** | `grep -c "status: open" ~/.claude/CLAUDE.md` |
| ユーザーが「スキル改善まわして」と明示指示 | — |

```bash
# 起動判定スクリプト（0=起動不要, 1=起動）
open_count=$(grep -c "status: open" ~/.claude/CLAUDE.md 2>/dev/null || echo 0)
if [[ "$open_count" -ge 3 ]]; then
  echo "INTAKE 起動条件成立 (open=${open_count})"
else
  echo "INTAKE 起動条件未達 (open=${open_count}/3)"
fi
```

### 抑制ルール

以下の場合はエントリを処理しない・後回しにする。

| 規則 | 理由 |
|------|------|
| **重複マージ**: 同一 skill×種別 の open エントリが複数ある場合、最新1件に統合 | 重複処理を防ぐ |
| **確度=低 の除外**: 理由が乏しく確度が低い提案は `triaged` に格上げせず保留 | 低品質な改善を防ぐ |
| **1スキル1セッション1件の原則**: 同一スキルへの複数改善が同時にある場合、優先度の高い1件から処理 | 競合編集・整合性崩壊を防ぐ |

---

## 4. 5ステップ処理フロー

### Step 1: 取り込み＆トリアージ

```bash
# 1. inbox セクションをファイルに切り出し（作業用）
awk '/^## 📥 スキル改善提案/,/^## [^#]/' ~/.claude/CLAUDE.md \
  | head -n -1 > /tmp/inbox_snapshot.md

# 2. open エントリの一覧（skill × 種別）
grep -E "^- (skill|種別|確度|status):" /tmp/inbox_snapshot.md \
  | paste - - - - \
  | grep "status: open"

# 3. 確度=高の提案を優先キューに
grep -B10 "確度: 高" /tmp/inbox_snapshot.md \
  | grep "## \[PROPOSAL\]"
```

処理手順:
1. `status: open` のエントリを全件抽出
2. `種別` でグルーピング（同種別は連続処理でコンテキスト効率化）
3. `確度=高` を先頭に並べ替え
4. 同一 skill×種別 の重複があればマージし、片方を `status: rejected（重複マージ）` に

### Step 2: 規約検証（採否判定）

採用・却下の判定を行い、`status: triaged`（採用）または `status: rejected`（却下）に更新する。

#### 却下基準

| 却下基準 | 確認方法 | 却下メッセージ例 |
|---------|---------|---------------|
| 書籍名・著者名・出版社名を含む改善点 | 下記 grep | `rejected: 書籍名含む（公開リポジトリ禁止）` |
| description 1,024字超過になる改善 | `wc -c` で計算 | `rejected: description 上限超過（現在XXX字→改善後XXX字）` |
| description 三部構成が崩れる | 手動確認 | `rejected: 三部構成欠落（2行目Use when なし）` |
| 移行先不在の参照修正 | 対象ファイルの存在確認 | `rejected: 移行先不在（残存課題化）` |

```bash
# 書籍名・著者名・出版社名の混入チェック（改善点フィールドを対象）
grep -n "改善点:" /tmp/inbox_snapshot.md \
  | grep -E "『|』|著者|出版社|TAC|オライリー|技術評論|翔泳社|日経BP|インプレス|オーム社"
# 出力ゼロであること

# description 文字数チェック（採用前に改善後の文字数を見積もる）
python3 -c "
skill = 'authoring-plugins'  # 対象スキルに変更
import yaml, pathlib
sk = pathlib.Path(f'skills/{skill}/SKILL.md').read_text()
fm = yaml.safe_load(sk.split('---')[1])
desc = fm.get('description', '')
print(f'現在: {len(desc)}字 / 上限: 1024字 / 余裕: {1024 - len(desc)}字')
"
```

### Step 3: 編集委譲

採用提案を **tachikoma-doc-document** に委譲する。本体はオーケストレーターに徹し、直接ファイルを編集しない。

#### 委譲プロンプトの6要素

委譲時は以下を必ず含める:

1. **コンテキスト**: 改善提案の背景・目的（inbox エントリ全文を貼り付ける）
2. **作業ディレクトリ**: `/Users/{user}/repo/{repo}/skills/{skill-name}/`
3. **必読ファイル**: 種別に対応する主担当 reference（下記マッピング表参照）
4. **担当タスク詳細**: 対象ファイル・変更箇所・変更内容
5. **厳守ルール**: 書籍名/著者名/出版社名禁止・description 1,024字以内・三部構成遵守
6. **完了条件と報告フォーマット**: 変更ファイル・変更内容・grep検証結果を含む報告

#### 種別→主担当 reference マッピング表

| 種別 | 主担当 reference | README同期 | version既定 | 整合スキャン |
|------|-----------------|-----------|------------|-------------|
| `description改善` | [USAGE-REVIEW.md](USAGE-REVIEW.md)（description三部構成ガイド） | 不要 | PATCH | 不要 |
| `分割` | [STRUCTURE.md](STRUCTURE.md)（Progressive Disclosure） | 条件付き（refs配下なら不要） | PATCH（大構成変更は MINOR） | 要 |
| `統合` | [USAGE-REVIEW.md](USAGE-REVIEW.md) + [CROSS-REFERENCE-INTEGRITY.md](CROSS-REFERENCE-INTEGRITY.md) | 🔴必要 | MAJOR 想定 | 要 |
| `内容追記` | [SKILL-GUIDE.md](SKILL-GUIDE.md) / 該当 refs | 不要 | PATCH | 不要 |
| `参照修正` | [CROSS-REFERENCE-INTEGRITY.md](CROSS-REFERENCE-INTEGRITY.md)（4層スキャン） | 条件付き | PATCH | 要 |
| `規約違反` | [CHECKLIST.md](CHECKLIST.md)（+固有名は CROSS-REFERENCE-INTEGRITY.md） | 違反次第 | PATCH | 条件付き |

#### 複数スキル並行時のファイル所有権分割

複数スキルを並列処理する場合、各タチコマに担当ファイルを明示し衝突を防ぐ:

```
tachikoma-doc-document-1: skills/skill-a/ 配下のみ
tachikoma-doc-document-2: skills/skill-b/ 配下のみ
README.md 更新: 最後に1体が担当（or 全完了後に本体が別途委譲）
```

### Step 4: 整合検証

以下のいずれかに該当する場合、[CROSS-REFERENCE-INTEGRITY.md](CROSS-REFERENCE-INTEGRITY.md) の4層スキャン＋ダングリング検出を実行する。

**整合検証が必要な条件:**
- 種別が `分割` / `統合` / `参照修正`
- `影響範囲` フィールドに「他スキル参照」「hook」「README」「rules」が含まれる

```bash
# 4層ダングリング検出（編集後に実行）
SKILL_NAME="authoring-plugins"  # 変更したスキル名に合わせる

# Layer 1: 他スキル frontmatter
/usr/bin/grep -rn "$SKILL_NAME" skills/*/SKILL.md

# Layer 2: 他スキル本文
/usr/bin/grep -rn "$SKILL_NAME" skills/*/INSTRUCTIONS.md skills/*/references/

# Layer 3: hook
/usr/bin/grep -n "$SKILL_NAME" hooks/*.sh

# Layer 4: README / rules / 自スキル内
/usr/bin/grep -rn "$SKILL_NAME" README.md rules/ "skills/$SKILL_NAME/"

# 全層まとめて（旧名が残っていないことを確認）
/usr/bin/grep -rn "$SKILL_NAME" \
  skills/ agents/ hooks/ README.md rules/ \
  --include="*.md" --include="*.sh" \
  | /usr/bin/grep -v "^Binary"
```

### Step 5: 完了ワークフローへ接続

整合検証が通ったら INSTRUCTIONS.md の「🔴 完了ワークフロー」へ移行する。

#### version 決定

`種別→version既定` 列（上記マッピング表）を参照して bump 量を決定する。

```bash
# 現行 version を実ファイルから読む（記憶・推測を使わない）
python3 -c "import json; print(json.load(open('.claude-plugin/plugin.json'))['version'])"

# 両 plugin.json のバージョン一致確認（bump 後に必ず実行）
diff \
  <(python3 -c "import json; print(json.load(open('.claude-plugin/plugin.json'))['version'])") \
  <(python3 -c "import json; print(json.load(open('.codex-plugin/plugin.json'))['version'])")
# 出力が空であること（差分なし）
```

> ⚠️ `.claude-plugin/plugin.json` を更新したら `.codex-plugin/plugin.json` も**必ず同じ値に同期**する（片方だけ更新すると配布物の整合性が崩れる）。

#### 処理済み提案の退避

commit 完了後、CLAUDE.md inbox を整理して open を空に近づける。

```bash
# inbox の open 残件数を確認
grep -c "status: open" ~/.claude/CLAUDE.md

# 目視確認（退避または削除対象）
grep -A15 "## \[PROPOSAL\]" ~/.claude/CLAUDE.md | grep -B15 "status: done\|status: rejected"
```

CLAUDE.md 内での退避先: 「## 処理済み」セクション（なければ inbox セクション直後に作成）。

> CLAUDE.md の 300 行原則を死守するため、「## 処理済み」が肥大化した場合は古いエントリから削除する。

---

## 5. 種別 → 処理経路マッピング表（完全版）

| 種別 | 主担当 reference | README同期 | version既定 | 整合スキャン | 備考 |
|------|-----------------|-----------|------------|-------------|------|
| `description改善` | USAGE-REVIEW.md | 不要 | PATCH | 不要 | 三部構成・1,024字遵守を必ず確認 |
| `分割` | STRUCTURE.md | refs配下のみなら不要 / スキル追加なら🔴必要 | PATCH（大構成変更は MINOR） | 要 | 新ファイルへの参照漏れに注意 |
| `統合` | USAGE-REVIEW.md + CROSS-REFERENCE-INTEGRITY.md | 🔴必要（スキル数が減る） | MAJOR 想定 | 要 | 吸収元の4層ダングリング全消去 |
| `内容追記` | SKILL-GUIDE.md / 該当 refs | 不要 | PATCH | 不要 | 500行原則を超えないか確認 |
| `参照修正` | CROSS-REFERENCE-INTEGRITY.md（4層スキャン） | 条件付き | PATCH | 要 | 捏造禁止（移行先不在は残存課題化） |
| `規約違反` | CHECKLIST.md + CROSS-REFERENCE-INTEGRITY.md | 違反次第 | PATCH | 条件付き | 固有名は多角パターン grep で全検出 |

---

## 6. 規約検証ルール（却下基準の詳細）

### 6-1. 固有名混入（無条件却下）

書籍名・著者名・出版社名を含む改善提案は無条件却下し `status: rejected` とする。

```bash
# 固有名残存チェック（採用前・編集後の両方で実行）
/usr/bin/grep -nE \
  "『|』|著者|出版社|TAC|オライリー|オーム社|技術評論|翔泳社|日経BP|インプレス" \
  skills/*/SKILL.md \
  skills/*/INSTRUCTIONS.md \
  skills/*/references/*.md \
  agents/*.md
# 出力がゼロ行であること
```

### 6-2. description 上限超過・三部構成欠落（差し戻し）

| 違反 | 処置 |
|------|------|
| 改善後 description が 1,024字を超える | 差し戻し。提案者に「XX字削減して再提出」と返す |
| 三部構成（機能説明 / Use when / 補足）が欠落 | 差し戻し。欠落部分を明示して修正を要求 |

```bash
# 改善後の description 文字数を事前試算（Python）
python3 << 'EOF'
new_desc = """
[ここに改善後の description 全文を貼り付ける]
""".strip()
print(f"文字数: {len(new_desc)} / 上限: 1024 / {'OK' if len(new_desc) <= 1024 else 'NG: 超過'}")
EOF
```

### 6-3. 移行先不在の参照修正（残存課題化）

正しい移行先が存在しない参照修正提案は、推測で別スキル名に書き換えない。

| 対応 | 手順 |
|------|------|
| 参照を削除し「削除済み」コメントを残す | ファイル内に `<!-- 参照削除: 旧名 YYYY-MM-DD -->` を挿入 |
| inbox に「残存課題」として記録 | `status: rejected（移行先不在・残存課題）` と追記 |

---

## 7. inbox ライフサイクル管理（CLAUDE.md を肥大させない規律）

### status 遷移

```
open → triaged（採否判定済み）→ done（編集完了）
                             └→ rejected（却下）
```

| status | 意味 | 次のアクション |
|--------|------|--------------|
| `open` | 未処理 | INTAKE Step 1 でトリアージ |
| `triaged` | 採否判定済み・採用 | Step 3 編集委譲を待つ |
| `done` | 編集・commit 完了 | 処理済みセクションへ退避 |
| `rejected` | 却下（理由付き） | 処理済みセクションへ退避 |

### 1サイクル完了後の inbox クリーンアップ手順

```bash
# 1. done / rejected の件数確認
grep -c "status: done\|status: rejected" ~/.claude/CLAUDE.md

# 2. CLAUDE.md の行数確認（300行原則）
wc -l ~/.claude/CLAUDE.md

# 3. 300行超過の場合: 古い処理済みエントリから削除
#    （EDITOR で ~/.claude/CLAUDE.md を開き「## 処理済み」セクションの古い行を除去）

# 4. open が残っていないことを確認
grep "status: open" ~/.claude/CLAUDE.md && echo "残存 open あり" || echo "inbox クリーン"
```

---

## 8. ループ健全性チェック

### 異常検知と対処

| 異常パターン | 検知方法 | 対処 |
|------------|---------|------|
| 同一提案が3サイクル連続で open に戻る | 提案見出しの日付が3件以上 | CLAUDE.md 捕捉ルールに「罠追記」（managing-claude-md へ委譲） |
| rejected 多発（1サイクルで5件以上） | `grep -c "status: rejected"` | 捕捉側の粒度見直し（粗すぎる提案を抑制する捕捉ルール修正） |
| inbox が 50 行を超えて肥大 | `grep -c "PROPOSAL" ~/.claude/CLAUDE.md` | INTAKE を即時起動して消化 or 低確度エントリを一括 rejected |

### inbox パース & トリアージ用コマンド集

```bash
# 提案件数の内訳（status 別）
grep "status:" ~/.claude/CLAUDE.md | sort | uniq -c | sort -rn

# 種別別の open 数
grep -A5 "## \[PROPOSAL\]" ~/.claude/CLAUDE.md \
  | grep -E "^- 種別:" \
  | sort | uniq -c | sort -rn

# 確度=高 の open 提案を一覧
awk '/^## \[PROPOSAL\]/{p=1; block=$0; next}
     p{block=block"\n"$0}
     /status: open/ && /確度: 高/{print block"\n---"; p=0}
     /^---/{p=0}' ~/.claude/CLAUDE.md

# 最古の open 提案（日付で判定）
grep "## \[PROPOSAL\]" ~/.claude/CLAUDE.md \
  | grep -oE "[0-9]{4}-[0-9]{2}-[0-9]{2}" \
  | sort | head -1
```

### 健全性ダッシュボード（1コマンドで全指標表示）

```bash
echo "=== INTAKE 健全性チェック ===" && \
echo "open   : $(grep -c 'status: open' ~/.claude/CLAUDE.md 2>/dev/null || echo 0)" && \
echo "triaged: $(grep -c 'status: triaged' ~/.claude/CLAUDE.md 2>/dev/null || echo 0)" && \
echo "done   : $(grep -c 'status: done' ~/.claude/CLAUDE.md 2>/dev/null || echo 0)" && \
echo "rejected: $(grep -c 'status: rejected' ~/.claude/CLAUDE.md 2>/dev/null || echo 0)" && \
echo "CLAUDE.md 行数: $(wc -l < ~/.claude/CLAUDE.md) / 300行原則" && \
echo "提案総数: $(grep -c '## \[PROPOSAL\]' ~/.claude/CLAUDE.md 2>/dev/null || echo 0)"
```
