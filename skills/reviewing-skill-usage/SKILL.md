---
name: reviewing-skill-usage
description: Guides periodic skill usage review based on session log analysis. Use when auditing skill portfolio, identifying unused skills, or planning skill consolidation. Provides usage analytics and lifecycle management. Distinct from authoring-skills (creation) by focusing on analytics.
---

# Skill Usage Review Guide

## 概要

このスキルは、Claude Code のセッションログ分析に基づくスキル利用状況の定期的なレビュー手順を提供します。

**目的:**
- スキルポートフォリオの健全性を維持
- 未使用・低使用スキルの棚卸し
- description改善による発見可能性の向上
- 重複・類似スキルの統合判断

**価値:**
- コンテキストウィンドウの効率化（不要スキルの削減）
- スキル品質の継続的改善
- 利用実績に基づく客観的な判断

---

## 前提ツール

### `skills/reviewing-skill-usage/scripts/analyze-skill-usage.sh` — ログ解析スクリプト

スキル利用状況を自動集計するスクリプト。全プロジェクトのセッションログ（`~/.claude/projects/*/*.jsonl`）をスキャンし、以下を集計します：

1. **Skillツール呼び出し回数**（スキル名別）
2. **スラッシュコマンド実行回数**（コマンド名別）
3. **未使用スキル検出**（呼び出し0回のスキル一覧）

#### 基本的な使い方

```bash
# 全期間の利用状況を分析（デフォルト）
./skills/reviewing-skill-usage/scripts/analyze-skill-usage.sh

# 期間指定
./skills/reviewing-skill-usage/scripts/analyze-skill-usage.sh --since 2026-01-01

# 期間範囲指定
./skills/reviewing-skill-usage/scripts/analyze-skill-usage.sh --since 2026-01-01 --until 2026-02-01

# JSON形式で出力
./skills/reviewing-skill-usage/scripts/analyze-skill-usage.sh --format json --output report.json

# CSV形式で出力
./skills/reviewing-skill-usage/scripts/analyze-skill-usage.sh --format csv --output report.csv
```

#### 出力例

```
=== Skill Usage Report (2025-12-26 〜 2026-02-09) ===

📊 Skill Tool Invocations (top 20):
  330  sumik:implementing-as-tachikoma
  289  using-serena / sumik:using-serena
   56  managing-agent-hierarchy
   42  sumik:coordinating-as-kusanagi
   ...

📊 Slash Commands (top 20):
  105  /plugin
   16  /converting-markdown-to-skill
   15  /mcp
   10  /convert-to-skill
   ...

⚠️  未使用スキル（Skillツール呼び出し0回）:
  - designing-web-apis
  - writing-latex
  - ...

📁 出力: ~/.claude/usage-data/skill-usage-report.json
```

---

## レポートの読み方

### 1. Skillツール呼び出し（Skill Tool Invocations）

- **高頻度スキル（10+回）**: コアスキルとして機能している。品質改善を検討する価値あり
- **低頻度スキル（1-9回）**: 特定用途向けの可能性。直近1ヶ月以内の利用があれば正常
- **0回**: 発見不可能、または不要な可能性

### 2. スラッシュコマンド（Slash Commands）

- スキルがスラッシュコマンドとしても提供されている場合、こちらの利用回数も確認
- スラッシュコマンド経由の利用が多い場合、ユーザーが明示的に呼び出すワークフロー型スキルである

### 3. 未使用スキル（Unused Skills）

- **0回スキル**: 以下のいずれかに該当
  - descriptionが不明瞭で発見されない
  - トリガー条件が狭すぎる
  - 実際に不要（廃止候補）
  - 最近追加されたばかり（様子見）

---

## 判断基準テーブル

| 利用回数 | 最終利用 | 判断 | アクション |
|---------|---------|------|----------|
| 高（10+） | 直近1ヶ月 | ✅ 維持 | 品質改善を検討（SKILL.mdのブラッシュアップ、サブファイル分離等） |
| 高（10+） | 1ヶ月以上前 | ⚠️ 確認 | トリガー条件の見直し。最近使われなくなった理由を調査 |
| 低（1-9） | 直近1ヶ月 | ✅ 維持 | 用途が限定的で正常。description改善で発見可能性向上を検討 |
| 低（1-9） | 1ヶ月以上前 | ⚠️ 改善 | description改善（三部構成の徹底、トリガー条件の明確化） or 類似スキルと統合 |
| 0 | - | 🔴 棚卸し | 廃止 or description大幅改善 or 保留（最近追加された場合） |

**注意事項:**
- **最終利用日時**: スクリプトの出力にはまだ含まれていないため、手動でログを確認するか、今後の機能追加を検討
- **季節性**: 年次・四半期イベント向けスキルは利用頻度が低くても維持する場合あり

---

## 棚卸しアクション詳細

### ✅ 維持（Maintain）

そのまま保持。品質向上施策を検討：
- SKILL.mdの記述を簡潔化・明確化
- 500行を超えている場合は Progressive Disclosure（REFERENCE.md等への分離）
- サンプルコード・テンプレートの追加

### ⚠️ description改善（Improve Description）

発見可能性を高めるため、frontmatter description を改善：
- **三部構成の徹底**（authoring-skills スキル参照）:
  1. 機能の端的な説明
  2. 使用タイミング（"Use when ..."）
  3. 補足的なトリガー情報・類似スキルとの差別化
- **具体的なキーワードを含める**:
  - NG: "Helps with development tasks"
  - OK: "Guides Next.js 16 development with React 19. Use when implementing Server Actions, Cache Components, or RSC patterns."

### 🔄 統合（Consolidate）

類似スキルとマージ：
1. **統合先スキルの選定**: より一般的な名前、高頻度利用のスキルを優先
2. **内容のマージ**: authoring-skills の Progressive Disclosure 原則に従う
3. **plugin.json 更新**: 統合元スキルのエントリを削除
4. **README.md 更新**: スキルカウント・テーブルを更新

**統合判断の目安:**
- 対象領域が90%以上重複
- 片方が明らかに他方の上位互換
- 両方とも低頻度利用（統合してもコンテキスト増加が小さい）

### 🗑️ 廃止（Deprecate）

スキルを削除：
1. **ファイル削除**: `skills/<skill-name>/` ディレクトリごと削除
2. **plugin.json 更新**: スキルエントリを削除（該当する場合）
3. **README.md 更新**: スキルカウント・テーブルを更新
4. **コミットメッセージ**: `chore: remove unused skill <skill-name>`

**廃止判断の目安:**
- 3ヶ月以上未使用
- description改善を試みても利用されない
- 技術スタックの変更により不要になった

---

## レビューチェックリスト

### 月次レビュー（Monthly Review）

- [ ] `./skills/reviewing-skill-usage/scripts/analyze-skill-usage.sh` を実行してレポート生成
- [ ] トップ10スキルを確認（品質改善の優先順位付け）
- [ ] ボトム10スキルを確認（棚卸し候補の洗い出し）
- [ ] 未使用スキルのリストを確認
- [ ] 最近追加したスキルの初回利用を確認

### 四半期レビュー（Quarterly Review）

- [ ] 全スキルの利用状況を俯瞰
- [ ] 判断基準テーブルに基づく棚卸し実施
  - [ ] 廃止候補の最終確認（ユーザーに確認）
  - [ ] 統合候補の特定（ユーザーに確認）
  - [ ] description改善対象のリストアップ
- [ ] 前四半期の改善施策の効果検証
- [ ] description監査（三部構成の徹底）
  - [ ] 全スキルのfrontmatter descriptionをレビュー
  - [ ] "Use when ..." が含まれているか確認
  - [ ] 類似スキルとの差別化が明記されているか確認

---

## ユーザー確認の原則（AskUserQuestion）

**判断分岐がある場合、推測で進めず必ずAskUserQuestionツールでユーザーに確認する。**

### 確認すべき場面

以下のアクションを実行する前に必ずユーザーに確認：
- **未使用スキルの廃止**: 本当に不要か、description改善で復活可能か
- **スキル統合**: どちらを統合先にするか、コンテンツマージ方針
- **高頻度スキルの大幅な変更**: 既存ユーザーへの影響が大きい場合

### 確認不要な場面

以下は自動判断可能：
- description の軽微な改善（誤字修正、表現の明確化）
- レポート生成と現状分析
- チェックリストに基づく候補リストアップ

### AskUserQuestion使用例

#### 未使用スキルの処分方針確認

```python
AskUserQuestion(
    questions=[{
        "question": "未使用スキル 'designing-web-apis' の処分方針を選択してください。",
        "header": "未使用スキル処分",
        "options": [
            {
                "label": "廃止",
                "description": "ディレクトリ削除・plugin.json/README.md更新"
            },
            {
                "label": "description改善",
                "description": "frontmatter descriptionを書き換えて発見可能性向上"
            },
            {
                "label": "保留",
                "description": "最近追加されたばかりなので次回レビューまで様子見"
            }
        ],
        "multiSelect": False
    }]
)
```

#### 統合候補の確認

```python
AskUserQuestion(
    questions=[{
        "question": "'playwright' と 'agent-browser' の統合を検討しています。統合先を選択してください。",
        "header": "スキル統合",
        "options": [
            {
                "label": "agent-browser に統合",
                "description": "より高機能で、playwrightの用途をカバー可能"
            },
            {
                "label": "playwright に統合",
                "description": "軽量なユースケース向けとして保持"
            },
            {
                "label": "統合しない",
                "description": "現状維持。descriptionで差別化を強化（軽量 vs 高機能）"
            }
        ],
        "multiSelect": False
    }]
)
```

---

## Hook-Based Auto-Triggering レビュー

### SessionStart Hook 監査

1. **`detect-project-skills.sh` の検出ロジック確認**:
   - 検出条件が正しく動作しているか
   - 新しいスキルが追加漏れしていないか

2. **Auto-detected Skills の利用状況**:
   - `analyze-skill-usage.sh` の出力と照合
   - 自動検出されているはずのスキルが実際に使われているか
   - 未使用の自動検出スキル → 検出条件の見直し

3. **REQUIRED/MUST スキルの遵守状況**:
   - descriptionに「REQUIRED」を含むスキルが適切にロードされているか

### Hook 監査チェックリスト

- [ ] `detect-project-skills.sh` のスキルリストが最新
- [ ] 高頻度スキルで自動検出対象外のものを確認
- [ ] REQUIRED/MUST スキルの利用頻度が基準を満たしているか

---

## Related Skills

- **authoring-skills**: スキル作成・改善の原則。description改善や統合時に参照
- **convert-to-skill**: 既存ドキュメントからスキルを作成する場合に使用

---

## Notes

- このスキルは **運用・ライフサイクル管理** に焦点を当てており、**スキルの作成** は authoring-skills の役割
- スクリプトの改善・機能追加は `scripts/analyze-skill-usage.sh` に直接反映
- レビュー結果はプロジェクトの `.claude/usage-data/` に保存され、トレンド分析に活用可能
