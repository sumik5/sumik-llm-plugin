# トラブルシューティング

> スキル開発でよくある問題と解決策。品質チェックリストは [CHECKLIST.md](CHECKLIST.md) を参照。

## 1. アップロード問題

### 1.1 "Could not find SKILL.md"

**症状**: スキルフォルダをアップロードしようとすると "Could not find SKILL.md in uploaded folder" エラーが表示される。

**原因**: ファイル名が正確に `SKILL.md` ではない。

**解決策**:
- ファイル名を正確に `SKILL.md`（大文字、拡張子 `.md`）にリネーム
- `ls -la` でファイル名を確認（`SKILL.MD`, `skill.md`, `Skill.md` などは不可）
- macOS/Linuxの場合: `mv skill.md SKILL.md` で修正

### 1.2 "Invalid frontmatter"

**症状**: アップロード時に "Invalid frontmatter" エラーが表示される。

**原因**: YAMLフォーマットのエラー。

**よくある間違い例と解決策**:

```yaml
# ❌ 間違い1: デリミタが欠落
name: my-skill
description: Does things

# ✅ 正解: 3つのハイフンで囲む
---
name: my-skill
description: Does things
---

# ❌ 間違い2: 引用符が閉じていない
---
name: my-skill
description: "Does things
---

# ✅ 正解: 引用符を閉じるか引用符なしで記述
---
name: my-skill
description: Does things
---

# ❌ 間違い3: コロンの後にスペースがない
---
name:my-skill
description:Does things
---

# ✅ 正解: コロンの後にスペース
---
name: my-skill
description: Does things
---
```

### 1.3 "Invalid skill name"

**症状**: "Invalid skill name" エラーが表示される。

**原因**: スキル名にスペース、大文字、アンダースコアが含まれている。

**解決策**:

```yaml
# ❌ 間違い
name: My Cool Skill          # スペース・大文字
name: My_Cool_Skill          # アンダースコア・大文字
name: myCoolSkill           # キャメルケース

# ✅ 正解: ケバブケース（小文字＋ハイフン）
name: my-cool-skill
```

---

## 2. トリガー問題

### 2.1 スキルが発火しない（Undertriggering）

**症状**:
- スキルが自動的にロードされない
- ユーザーが手動でスキルを有効化する必要がある
- サポート問い合わせ「いつこのスキルを使うのか？」

**原因と対策**:

| 原因 | 対策 |
|------|------|
| `description` が曖昧すぎる | 具体的なトリガーフレーズを追加 |
| ユーザーが実際に使う言葉が含まれていない | ユースケースのキーワードを記述 |
| 技術用語のみで説明されている | ユーザーが言いそうなフレーズを含める |

**デバッグ手法**: Claudeに「When would you use the [skill name] skill?」と尋ねる。Claudeが引用する説明文を分析し、不足している情報を追加する。

**改善例**:

```yaml
# ❌ 発火しない例
description: Processes documents

# ✅ 改善後
description: Processes PDF legal documents for contract review. Use when user uploads .pdf files, asks for "contract analysis", "legal review", or "extract contract terms".
```

### 2.2 スキルが過剰に発火する（Overtriggering）

**症状**:
- 無関係なクエリでスキルがロードされる
- ユーザーがスキルを無効化する
- 目的について混乱

**対策**:

**1. ネガティブトリガーを追加**

```yaml
description: Advanced data analysis for CSV files. Use for statistical modeling, regression, clustering. Do NOT use for simple data exploration (use data-viz skill instead).
```

**2. スコープを限定**

```yaml
# ❌ 広すぎる
description: Processes documents

# ✅ スコープ限定
description: Processes PDF legal documents for contract review. Use specifically for contract analysis, not for general PDF manipulation.
```

**3. ドメインを明確化**

```yaml
description: PayFlow payment processing for e-commerce. Use specifically for online payment workflows, not for general financial queries.
```

---

## 3. 指示遵守問題

### 3.1 指示が冗長すぎる

**症状**: Claudeが指示の一部を無視する、または重要な指示を見落とす。

**原因**: コンテキストウィンドウは共有リソース。冗長な説明はトークンを無駄にし、重要な情報が埋もれる。

**解決策**:
- 簡潔な箇条書きを使用
- 詳細は別ファイル（`references/`）に分離
- 「Claudeがすでに知っている情報か？」を自問

```markdown
# ❌ 冗長
このステップでは、ユーザーから提供されたプロジェクト名を使用して、Linear MCPサーバーのcreate_projectツールを呼び出し、新しいプロジェクトを作成します。プロジェクト名は必須であり、空でないことを確認してください。

# ✅ 簡潔
Call `create_project` with non-empty project name.
```

### 3.2 重要指示が埋もれる

**症状**: 重要なバリデーションや制約がスキップされる。

**解決策**:
- 重要指示をファイルの先頭に配置
- `## Important` または `## Critical` ヘッダーを使用
- 必要に応じて繰り返す

```markdown
## Critical Requirements

Before calling `create_project`, verify:
- Project name is non-empty
- At least one team member assigned
- Start date is not in the past

## Workflow

[詳細な手順...]
```

### 3.3 曖昧な言語

**症状**: 指示の解釈がバラつく。

**解決策**: 具体的・実行可能な指示を記述。

```markdown
# ❌ 曖昧
Make sure to validate things properly

# ✅ 具体的
Run `python scripts/validate.py --input {filename}` to check data format.
If validation fails, common issues include:
- Missing required fields (add them to the CSV)
- Invalid date formats (use YYYY-MM-DD)
```

### 3.4 モデルの「怠慢」対策

**症状**: Claudeが検証ステップをスキップしたり、簡略化したりする。

**解決策**: 明示的な奨励を追加（ユーザープロンプトに追加するのが最も効果的）。

```markdown
## Performance Notes

- Take your time to do this thoroughly
- Quality is more important than speed
- Do not skip validation steps
```

**高度なテクニック**: 重要なバリデーションは言語指示ではなく、実行可能スクリプトに実装する。コードは決定論的、言語解釈は非決定論的。

---

## 4. MCP接続問題

### 4.1 MCPサーバー未接続

**症状**: スキルはロードされるが、MCPツール呼び出しが失敗する。

**チェックリスト**:
1. MCPサーバーの接続状態を確認
   - Claude.ai: Settings > Extensions > [Your Service]
   - ステータスが「Connected」になっているか確認
2. 認証を確認
   - APIキーが有効で期限切れでない
   - 適切な権限/スコープが付与されている
   - OAuthトークンが更新されている
3. MCPを単独でテスト
   - スキルなしでMCPツールを直接呼び出す
   - 例: 「Use [Service] MCP to fetch my projects」
   - 失敗する場合、問題はMCPにあり（スキルではない）

### 4.2 認証エラー

**症状**: "Unauthorized", "Forbidden", "Invalid API key" エラー。

**解決策**:
- APIキーを再生成
- 必要な権限/スコープを確認
- MCPサーバー設定で認証情報を更新
- 環境変数が正しく設定されているか確認

### 4.3 ツール名不一致

**症状**: "Tool not found" エラー。

**原因**: スキル内のツール名がMCPサーバーで定義されているツール名と一致しない。

**解決策**:
- MCPサーバーのドキュメントでツール名を確認
- ツール名は大文字小文字を区別する
- スキル内のツール呼び出しを修正

```markdown
# ❌ 間違い
Call `CreateProject` tool

# ✅ 正解（MCPサーバーのツール名に一致）
Call `create_project` tool
```

---

## 5. コンテキスト肥大化

### 5.1 スキルコンテンツが大きすぎる

**症状**: スキルの応答が遅い、または品質が低下する。

**原因**: SKILL.mdが大きすぎる（5,000語超）。

**解決策**:
- 詳細ドキュメントを `references/` に移動
- Progressive Disclosureを活用
- SKILL.mdは概要とコアワークフローに限定
- 詳細をリンクする

```markdown
# SKILL.md（簡潔）
## Quick Start
[コアワークフロー]

## Advanced Usage
See [REFERENCE.md](references/REFERENCE.md) for detailed API documentation.

## Examples
See [EXAMPLES.md](references/EXAMPLES.md) for usage examples.
```

### 5.2 有効スキルが多すぎる

**症状**: 20-50個以上のスキルが同時に有効になっている。

**解決策**:
- 必要なスキルのみを有効化
- 選択的な有効化を推奨
- 関連スキルを「パック」としてグループ化

### 5.3 文字予算（SLASH_COMMAND_TOOL_CHAR_BUDGET）の上限

**症状**: 一部のスキルがコンテキストに入りきらず、情報が欠落する。スキルの指示が途中で途切れる。

**原因**: スキルのコンテキスト占有量は環境変数 `SLASH_COMMAND_TOOL_CHAR_BUDGET`（デフォルト15,000文字）で制御されている。多数のスキルを使用する場合、この上限に到達する可能性がある。

**解決策**:

1. **スキルの簡潔化を優先**: SKILL.md の不要な説明を削除し、Progressive Disclosure を徹底
2. **環境変数の調整**: 必要に応じて `SLASH_COMMAND_TOOL_CHAR_BUDGET` の値を増加

```bash
# 環境変数で文字予算を増加（例: 30,000文字に拡大）
export SLASH_COMMAND_TOOL_CHAR_BUDGET=30000
```

3. **スキルの優先度設定**: 重要度の低いスキルに `user-invocable: false` を設定し、必要時のみ手動ロード
4. **スキル統合**: 類似スキルを1つに統合してトークン消費を削減（1言語=1スキル原則）

**診断方法**:

```bash
# 各スキルの文字数を確認
for dir in skills/*/; do
  if [ -f "$dir/SKILL.md" ]; then
    chars=$(wc -c < "$dir/SKILL.md")
    echo "$chars $dir"
  fi
done | sort -rn
```

---

## 補足: イテレーション信号の活用

スキルの改善は継続的プロセス。以下の信号を監視してイテレーションを行う:

| 信号 | 対応 |
|------|------|
| Undertriggering（発火不足） | `description` を具体化、キーワード追加 |
| Overtriggering（過剰発火） | スコープ限定、ネガティブトリガー追加 |
| 実行の不一致 | 指示を明確化、エラーハンドリング追加 |
| APIコール失敗 | MCPツール名確認、認証チェック |
| ユーザー修正が必要 | ワークフロー改善、バリデーション追加 |
