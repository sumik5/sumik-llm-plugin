# クロスリファレンス整合性ガイド

改善提案INTAKE のステップ4（整合検証）から呼ばれる。スキルのリネーム・統合・削除時に「実在しないスキル名への参照（ダングリング参照）」を取りこぼさないための完全ガイド。

---

## 🔴 問題提起: ダングリング参照とは

スキルを **リネーム・統合・削除** すると、そのスキル名への参照が「実在しないスキル名（ダングリング参照）」として散在したまま残る。

**引き起こされる障害:**

| 参照の種別 | 障害 |
|-----------|------|
| 他スキルのdescriptionに `use X` が残る | Claude が存在しないスキルへルーティング → ルーティング失敗 |
| 本文に `see X` / `→X` が残る | 幽霊推奨・機能しないポインタ |
| hook のシェル配列にスキル名が残る | 自動推奨の誤検知・hook実行エラー |
| 自スキル内が旧名を自己参照 | 統合・リネーム後も誤参照が再生産される |

**規模感**: 1スキルのリネームが数十ファイルに波及した実例がある。1か所の更新漏れが潜伏し続ける。

---

## 参照が潜む4層（取りこぼし防止の核心）

操作前に必ず以下の4層すべてをスキャンする。

### Layer 1: 他スキルの frontmatter（description / when_to_use）

ルーティングヒントとして他スキルが旧名を参照するパターン:

```
use old-skill-name
use old-skill-name instead
see old-skill-name
→ old-skill-name
For X, use old-skill-name.
```

**検出コマンド:**
```bash
/usr/bin/grep -rn "old-skill-name" skills/*/SKILL.md
```

### Layer 2: 他スキルの本文（INSTRUCTIONS.md / references/*.md）

本文中の `use/see/→` 参照 + パス参照:

```
# 本文中のキーワード参照
use old-skill-name
see old-skill-name

# パス参照
skills/old-skill-name/
${CLAUDE_PLUGIN_ROOT}/skills/old-skill-name/
```

**検出コマンド:**
```bash
/usr/bin/grep -rn "old-skill-name" skills/*/INSTRUCTIONS.md skills/*/references/
```

### Layer 3: hook（hooks/detect-project-skills.sh 等）

シェルスクリプト内の配列・case文:

```bash
PROJECT_SKILLS=("old-skill-name" "other-skill")  # 配列キー
ALWAYS_SKILLS=("old-skill-name")
case "$skill" in
  "old-skill-name") ...  # case文のキー
esac
```

**検出コマンド:**
```bash
/usr/bin/grep -n "old-skill-name" hooks/*.sh
```

### Layer 4: README.md / rules/ ＋ 自スキル内の自己参照

- `README.md` のスキル一覧表
- `rules/skill-triggers.md` のルーティング表
- **自スキル内の自己参照**（統合先スキルの本文が旧名を参照するケース）

```bash
/usr/bin/grep -rn "old-skill-name" README.md rules/ skills/new-skill-name/
```

---

## ⚠️ 検出は多角的パターンで

**`use X` だけ追うと取りこぼす。** 以下のパターンをすべて検索すること:

| パターン | 理由 |
|---------|------|
| `use old-name` | 最も一般的なルーティングヒント |
| `see old-name` | 参照ポインタ |
| `→ old-name` / `→old-name` | 矢印記法（全角・半角） |
| `old-name instead` | 代替案として言及 |
| `skills/old-name` | パス参照 |
| `"old-name"` | hookのシェル配列・ダブルクォート |
| `'old-name'` | シングルクォート（shスクリプト） |

**実証された取りこぼし例**: `use X` のみ検索 → hook のシェル配列 `"old-skill-name"` が残存 → 自動推奨が壊れた状態で稼働。

---

## ダングリング参照の一括検出スクリプト

リポジトリ全体のダングリング参照を一覧化するスクリプト（コピペ可能）:

### Bash版

```bash
#!/usr/bin/env bash
# ダングリング参照検出スクリプト
# 使用法: bash check-dangling-refs.sh [repo-root]

REPO="${1:-.}"
SKILLS_DIR="$REPO/skills"

# 実在スキルのセット
existing_skills=$(ls -d "$SKILLS_DIR"/*/  2>/dev/null | xargs -I{} basename {} | sort)

# 許容リスト（正当な旧名言及・歴史的記述等 — 誤検知を防ぐ）
ALLOWLIST=(
  # 例: "deprecated-skill-name"  # 廃止履歴として言及
)

echo "=== ダングリング参照チェック ==="
echo "実在スキル数: $(echo "$existing_skills" | wc -l)"
echo ""

# 参照パターンを全ファイルから抽出
found_dangling=0
while IFS= read -r file; do
  # use X / see X / → X / skills/X パターンを抽出
  refs=$(/usr/bin/grep -oE \
    '(use|see|→)\s+([a-z][a-z0-9-]{0,62}[a-z0-9])|skills/([a-z][a-z0-9-]{0,62}[a-z0-9])/' \
    "$file" 2>/dev/null \
    | /usr/bin/grep -oE '[a-z][a-z0-9-]{2,62}[a-z0-9]' \
    | sort -u)

  for ref in $refs; do
    # 許容リストチェック
    allowed=false
    for item in "${ALLOWLIST[@]}"; do
      [[ "$ref" == "$item" ]] && allowed=true && break
    done
    $allowed && continue

    # 実在チェック
    if ! echo "$existing_skills" | /usr/bin/grep -qx "$ref"; then
      echo "⚠️  ダングリング: '$ref' in $file"
      found_dangling=1
    fi
  done
done < <(find "$REPO" \
  -name "*.md" -o -name "*.sh" \
  | /usr/bin/grep -v "node_modules\|\.git\|cache" \
  | sort)

# hook の配列・case文から抽出
while IFS= read -r hookfile; do
  refs=$(/usr/bin/grep -oE '"([a-z][a-z0-9-]{2,62}[a-z0-9])"' "$hookfile" 2>/dev/null \
    | tr -d '"' | sort -u)
  for ref in $refs; do
    if echo "$existing_skills" | /usr/bin/grep -qx "$ref" || \
       printf '%s\n' "${ALLOWLIST[@]}" | /usr/bin/grep -qx "$ref"; then
      continue
    fi
    # スキル名らしい形式のみ警告（動名詞形: verb-ing-*）
    if echo "$ref" | /usr/bin/grep -qE '^[a-z]+-ing(-[a-z]+)*$|^[a-z]+-[a-z]+-[a-z]+'; then
      echo "⚠️  Hook配列ダングリング: '$ref' in $hookfile"
      found_dangling=1
    fi
  done
done < <(find "$REPO/hooks" -name "*.sh" 2>/dev/null | sort)

if [[ $found_dangling -eq 0 ]]; then
  echo "✅ ダングリング参照なし"
fi
```

### Python版（より精密な抽出が必要な場合）

```python
#!/usr/bin/env python3
"""ダングリング参照検出スクリプト"""
import os, re, sys
from pathlib import Path

repo = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
skills_dir = repo / "skills"

# 実在スキルのセット
existing = {p.name for p in skills_dir.iterdir() if p.is_dir()} if skills_dir.exists() else set()

# 許容リスト（正当な旧名言及など）
ALLOWLIST: set[str] = set()

# 参照パターン
REF_PATTERNS = [
    re.compile(r'(?:use|see|→)\s+([a-z][a-z0-9-]{2,62}[a-z0-9])'),
    re.compile(r'skills/([a-z][a-z0-9-]{2,62}[a-z0-9])/'),
]
HOOK_PATTERN = re.compile(r'["\']([a-z][a-z0-9-]{2,62}[a-z0-9])["\']')

danglers: list[tuple[str, str, str]] = []

for filepath in sorted(repo.rglob("*.md")) + sorted(repo.rglob("*.sh")):
    if any(p in filepath.parts for p in [".git", "node_modules", "cache"]):
        continue
    try:
        text = filepath.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        continue

    for pat in REF_PATTERNS:
        for m in pat.finditer(text):
            ref = m.group(1)
            if ref not in existing and ref not in ALLOWLIST:
                danglers.append((str(filepath.relative_to(repo)), ref, m.group(0)))

    # hook の配列
    if filepath.suffix == ".sh":
        for m in HOOK_PATTERN.finditer(text):
            ref = m.group(1)
            if re.match(r'^[a-z]+-ing', ref) and ref not in existing and ref not in ALLOWLIST:
                danglers.append((str(filepath.relative_to(repo)), ref, m.group(0)))

if danglers:
    print(f"⚠️  ダングリング参照 {len(danglers)} 件:")
    for fpath, ref, ctx in danglers:
        print(f"  {fpath}: '{ref}' (context: {ctx!r})")
    sys.exit(1)
else:
    print("✅ ダングリング参照なし")
    sys.exit(0)
```

---

## 🔴 捏造禁止の原則

> **正しい移行先が存在しない参照は、無理に別名へ書き換えない。**

スキルが削除・廃止されたが後継が存在しない場合、または移行先が不明な場合:

| ❌ やってはいけないこと | ✅ 正しい対応 |
|----------------------|-------------|
| 存在しないスキル名Aを、別の存在するスキルBへ機械的に書き換える | 「残存課題」として明記し、ユーザー判断を仰ぐ |
| 推測で類似名のスキルへリダイレクトする | 参照を削除した上で「削除済み」コメントを残す |

**理由**: 存在しないパスへのリネームは「別の壊れ方」を生む。現状の壊れ方より悪化する場合がある。

---

## 参照ファイルの実在検証

スキル本文が参照する外部ファイルは **必ず実在** すること。

```bash
# 本文内の references/X 参照を抽出して実在チェック
skill_dir="skills/your-skill"
/usr/bin/grep -oE '\[.*?\]\(references/[^)]+\)' "$skill_dir/INSTRUCTIONS.md" \
  | /usr/bin/grep -oE 'references/[^)]+' \
  | while read -r ref; do
      if [[ ! -f "$skill_dir/$ref" ]]; then
        echo "❌ 不在参照: $skill_dir/$ref"
      fi
    done

# scripts/X 参照の実在チェック
/usr/bin/grep -oE 'scripts/[a-zA-Z0-9_.-]+' "$skill_dir/INSTRUCTIONS.md" \
  | sort -u \
  | while read -r ref; do
      if [[ ! -f "$ref" ]]; then
        echo "❌ 不在スクリプト参照: $ref"
      fi
    done
```

**不在スクリプト参照は手順を機能不全にする**。リンクが存在しない状態での手順は完全に信頼できない。

---

## 検証コマンド集

### ① ダングリング名ゼロの確認

```bash
# 特定スキル名が残っていないことを全体確認
OLD_NAME="old-skill-name"
/usr/bin/grep -rn "$OLD_NAME" \
  skills/ agents/ hooks/ README.md rules/ \
  --include="*.md" --include="*.sh" \
  | /usr/bin/grep -v "^Binary"
# 出力がゼロ行であることを確認
```

### ② 参照スクリプトの実在確認

```bash
# 全スキルの INSTRUCTIONS.md が参照する scripts/* の実在チェック
for skill_dir in skills/*/; do
  instr="$skill_dir/INSTRUCTIONS.md"
  [[ -f "$instr" ]] || continue
  /usr/bin/grep -oE 'scripts/[a-zA-Z0-9_.-]+' "$instr" | sort -u | while read -r ref; do
    [[ -f "$ref" ]] || echo "❌ $skill_dir → $ref (不在)"
  done
done
```

### ③ hook の構文チェック

```bash
# シェルスクリプトの構文エラー検出
for hook in hooks/*.sh; do
  bash -n "$hook" && echo "✅ $hook" || echo "❌ $hook: 構文エラー"
done
```

### ④ 書籍名・著者名の残存チェック（公開リポジトリ必須）

```bash
/usr/bin/grep -nE "『|』|著者|出版社" \
  skills/authoring-plugins/INSTRUCTIONS.md \
  skills/authoring-plugins/SKILL.md \
  skills/authoring-plugins/references/*.md
# 出力がゼロ行であることを確認
```

---

## 許容例外（allowlist）の管理

以下は **ダングリング参照ではなく正当な言及** として検出スクリプトで除外してよい:

| パターン | 正当な理由 |
|---------|-----------|
| 命名規則の実例として旧名を示す | 例: 「`deprecated-pattern` は非推奨」という規則解説 |
| 歴史的変遷の記録（CHANGELOG・WORKFLOWS.md 等） | 移行経緯の文書化 |
| 廃止スキルの明示的な `## Deprecated` セクション | ユーザーへの移行ガイド |

**allowlist への追加は慎重に。** 安易な除外はダングリング検出を骨抜きにする。追加時はコメントで理由を明記すること。

---

## リネーム・統合・削除の操作チェックリスト

作業前に印刷（コピー）してチェックしながら進める:

```
操作: [ ] リネーム  [ ] 統合  [ ] 削除
旧スキル名: _______________
新スキル名（削除の場合は「削除」）: _______________

【事前スキャン】
- [ ] Layer 1: 他スキル frontmatter に旧名参照がないか確認
- [ ] Layer 2: 他スキル本文（INSTRUCTIONS.md / references/）に旧名参照がないか確認
- [ ] Layer 3: hooks/*.sh の配列・case文に旧名がないか確認
- [ ] Layer 4: README.md / rules/ / 自スキル内に旧名参照がないか確認

【更新実施】
- [ ] 各層の参照を新名に書き換え（または削除）
- [ ] 移行先が存在しない参照は「残存課題」として記録（捏造禁止）
- [ ] 参照スクリプト・ファイルの実在を確認

【事後検証】
- [ ] `/usr/bin/grep -rn "旧名"` でゼロ件確認
- [ ] `bash -n hooks/*.sh` で構文エラーなし
- [ ] ダングリング検出スクリプトを実行してゼロ件確認
```
