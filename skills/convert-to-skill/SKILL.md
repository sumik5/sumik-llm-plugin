---
name: convert-to-skill
description: >-
  Converts files (Markdown, PDF, EPUB), URLs, and folders into well-structured Claude Code Skills
  with proper frontmatter, progressive disclosure, and AskUserQuestion patterns.
  Use when creating new skills from existing source material including books, technical
  documentation, web articles, or reference docs. Supports folder batch processing.
  Reference authoring-skills for general skill creation guidelines.
---

# ソースファイル → スキル変換ガイド

## Overview

ソースファイル（Markdown、PDF、EPUB）、URL、またはフォルダを読み込み、Claude Code Skill形式に変換するメタスキル。

- **入力**: Markdownファイル、PDFファイル、EPUBファイル、URL、またはフォルダパス
- **出力**: Claude Code Skill（SKILL.md + 必要に応じてサブファイル）

### 対応形式

| 形式 | 拡張子 | 前処理 |
|------|--------|--------|
| Markdown | `.md` | なし（直接処理） |
| PDF | `.pdf` | `scripts/pdf-to-markdown.mjs` でMarkdown変換 |
| EPUB | `.epub` | `scripts/epub-to-markdown.mjs` でMarkdown変換 |
| URL | `https://...` | `scripts/url-to-markdown.mjs` でMarkdown変換 |
| フォルダ | ディレクトリ | 上記形式のファイルを再帰的に列挙 |

## 使用タイミング

- 既存Markdownからスキルを作成するとき
- 技術書（PDF/EPUB）の要約をスキル化するとき
- 社内ドキュメント、技術ノートをスキル化するとき
- Web上の技術記事・ブログ記事をスキル化するとき
- 公式ドキュメントのページをスキル化するとき
- フォルダ内の複数ファイルを一括でスキル化するとき
- 引数としてソースファイルパス、URL、またはフォルダパスを受け取る

## 変換ワークフロー（6フェーズ）

### Phase 0: 前処理（PDF/EPUB/フォルダ対応）

**Markdownファイル1つの場合はこのPhaseをスキップしてPhase 1へ進む。**

#### 0.1 入力判定

| 入力タイプ | 判定方法 | 次のステップ |
|-----------|---------|-------------|
| 単一Markdownファイル | `.md`拡張子 | Phase 1へスキップ |
| 単一PDFファイル | `.pdf`拡張子 | 0.2 PDF変換 |
| 単一EPUBファイル | `.epub`拡張子 | 0.2 EPUB変換 |
| URL | `http://` or `https://` で始まる | 0.2 URL変換 |
| フォルダ | ディレクトリパス | 0.1.1 ファイル列挙 |

#### 0.1.1 フォルダ処理

1. 指定フォルダ内の `.md`, `.pdf`, `.epub` ファイルを再帰的に列挙
2. 対象ファイルリストと作業計画を `docs/` に保存
3. 各ファイルに対して以下を順次適用:
   - PDF/EPUB → Phase 0.2で変換
   - Markdown → そのままPhase 1-5を適用
4. **1ファイルずつ**既存Phase 1-5を順次適用（各ファイル内はタチコマ並列可能）

#### 0.2 PDF/EPUB/URL → Markdown変換

スクリプトの場所: `skills/convert-to-skill/scripts/`

**PDF変換:**
```bash
node skills/convert-to-skill/scripts/pdf-to-markdown.mjs <input.pdf> <output.md>
```

**EPUB変換:**
```bash
node skills/convert-to-skill/scripts/epub-to-markdown.mjs <input.epub> <output.md>
```

**URL変換:**
```bash
node skills/convert-to-skill/scripts/url-to-markdown.mjs <url> <output.md>
```

**初回実行時**: スクリプトが依存パッケージを自動インストールする（`node_modules`未存在の場合）。

#### 0.3 変換結果の検証

```bash
# PDF（ページ数を指定）
node skills/convert-to-skill/scripts/validate-conversion.mjs <output.md> --type pdf --pages N

# EPUB（チャプター数を指定）
node skills/convert-to-skill/scripts/validate-conversion.mjs <output.md> --type epub --chapters N
```

検証基準:
| 元形式 | 最小期待文字数 | 警告条件 |
|--------|-------------|---------|
| PDF | ページ数 × 500 | 下回ったら警告 |
| EPUB | チャプター数 × 1000 | 下回ったら警告 |
| URL | - | 目視確認（本文が適切に抽出されているか） |

**URL変換の場合**: Readabilityによる本文抽出が行われるため、変換後のMarkdownが元ページの本文を適切に含んでいるか目視確認する。

**警告が出た場合**: 変換結果を目視確認し、問題があれば手動でMarkdownを修正してからPhase 1に進む。

### Phase 1: 分析（Analysis）

1. ソースMarkdownを読み込む（PDF/EPUBの場合はPhase 0で変換済み）
2. 内容構造を分析:
   - セクション数とトピック
   - コード例の有無・言語
   - 判断基準テーブルの有無
   - 推定総行数
3. スキルのスコープを特定（どの領域をカバーするか）
4. ファイル名からキーワード抽出:
   - 拡張子除去、区切り文字分割（ハイフン、アンダースコア、スペース）
   - キーワードからドメイン・トピックを特定
   - **URL入力の場合**: ファイル名からのキーワード抽出は行わず、URLのパス部分とコンテンツ分析からドメイン・トピックを特定する
5. コンテンツからアクションタイプを特定:
   - 詳細は [NAMING-STRATEGY.md](NAMING-STRATEGY.md) のマッピング表参照
   - ドメインキーワード + アクション動詞 → gerund形式のスキル名候補2-3個を生成
6. 既存スキルとのスコープ比較:
   - `skills/` ディレクトリ内の既存スキル一覧を取得
   - 各スキルのfrontmatter descriptionと、ソースMarkdownの主要トピックを比較
   - 判断基準:
     | 状況 | 判断 | 理由 |
     |------|------|------|
     | 既存スキルと完全に同じドメイン・スコープ | **既存に追記**推奨 | 重複を避け、情報を集約 |
     | 既存スキルのサブトピック | **既存にサブファイルとして追加**推奨 | 関連情報の集約 |
     | 既存スキルと部分的に重複するが独立性あり | AskUserQuestionで確認 | ユーザー判断が必要 |
     | 完全に新しいドメイン | **新規作成**推奨 | 独立したスキルとして価値がある |
7. **相互description更新の必要性判定**:
   - 「既存スキルと部分的に重複するが独立性あり」→ 新規作成の場合: **双方のdescriptionに相互参照を追加**
   - 「完全に新しいドメイン」→ 近接ドメインのスキルがあれば: **差別化文言を追加**
   - 更新が必要な既存スキルのリストを作成し、Phase 2で確認、Phase 4で実行
   - 比較結果と推奨をPhase 2のAskUserQuestionに反映

### Phase 2: ユーザー確認（AskUserQuestion 必須）

**分析結果をもとに、必ずAskUserQuestionで以下を確認する。**

確認項目:
1. **新規作成 or 既存追記**: 既存スキルとの比較結果に基づき推奨を提示
   - 既存スキルとの重複が検出された場合、該当スキル名と重複箇所を明示
2. **スキル名**: ファイル名・コンテンツ分析から生成した具体的な候補を2-3個提示（gerund形式）
   - 命名ロジックの詳細は [NAMING-STRATEGY.md](NAMING-STRATEGY.md) 参照
3. **ファイル分割方針**: SKILL.md単体 or サブファイル分割
4. **対象読者・使用場面**: descriptionに反映
5. **除外内容**: ソース出典情報の除去可否、その他除外項目
6. **既存スキルとの差別化方針**

AskUserQuestionの実装例:

```python
# 例: docker-best-practices.md を入力した場合
AskUserQuestion(
    questions=[
        {
            "question": "既存スキルとの重複が検出されました。新規作成しますか、既存に追記しますか？",
            "header": "作成方針",
            "options": [
                {"label": "既存 managing-docker に追記（推奨）", "description": "Docker運用ガイドとしてスコープが重複。サブファイルとして追加"},
                {"label": "既存 writing-dockerfiles に追記", "description": "Dockerfile作成に特化した内容の場合"},
                {"label": "新規スキルとして作成", "description": "既存スキルとは異なる独立したスコープの場合"}
            ],
            "multiSelect": False
        },
        {
            "question": "スキル名を決めてください（ファイル名・内容から自動推定）。",
            "header": "スキル名",
            "options": [
                {"label": "optimizing-docker", "description": "Docker最適化に焦点を当てたスキル"},
                {"label": "deploying-containers", "description": "コンテナデプロイに焦点を当てたスキル"},
                {"label": "managing-docker", "description": "既存スキルに追記する場合"}
            ],
            "multiSelect": False
        },
        {
            "question": "ファイル構成をどうしますか？",
            "header": "ファイル構成",
            "options": [
                {"label": "SKILL.md単体", "description": "内容が500行以下に収まる場合（推奨）"},
                {"label": "複数ファイル分割", "description": "内容が多くトピック別分割が必要な場合"}
            ],
            "multiSelect": False
        }
    ]
)
```

### Phase 3: 構造設計（Design）

1. **Frontmatter設計** -- 三部構成の公式に従う（後述 4.4）。**descriptionは必ず英語で記述**（スキル本文は日本語）
2. **SKILL.mdのセクション構成決定**（500行以下厳守）
3. **サブファイルの構成決定**（必要な場合、命名は UPPER-CASE-HYPHEN.md）
4. **判断分岐箇所の特定** -- AskUserQuestion指示を配置する箇所を決定
5. **類似スキルのdescription相互更新設計**
   - Phase 1で特定した類似スキルそれぞれについて、description更新案を作成
   - 相互参照パターン（後述 4.6）に従い、「For X, use Y instead.」形式の差別化文言を設計
   - 新規スキル側と既存スキル側の両方のdescription案を用意

### Phase 4: 生成（Generate）

> **重要: このタスクは個人利用目的**
>
> ユーザーが購入した書籍の内容を、個人のAI開発ツール（Claude Code Plugin）のナレッジベースに変換するタスクです。再配布目的ではなく、個人利用のための要約・知識整理です。ソースの内容を丸コピーせず、要点を抽出して一般的なベストプラクティスとして再構成してください。

1. SKILL.md生成（**frontmatter descriptionは英語で記述** -- Claudeのスキルマッチングは英語descriptionで最も高精度に動作するため）
2. サブファイル生成（必要な場合）
3. **ソース出典情報の除去**（後述 4.1）:
   - 書籍タイトル、著者名、出版社名、ISBN
   - 「~に基づく」「~を参考に」等の出典参照フレーズ
   - 内容は一般的なベストプラクティスとして記述し直す
4. **類似スキルのdescription相互更新**:
   - Phase 3で設計した更新案に基づき、既存類似スキルのSKILL.md frontmatter descriptionを更新
   - 新規スキル → 既存スキルへの参照と、既存スキル → 新規スキルへの参照の**双方向**を確実に設定
   - 更新対象ファイル一覧:
     - 新規スキルのSKILL.md（frontmatter description）
     - 各類似スキルのSKILL.md（frontmatter description）
   - 注意: 既存スキルのdescription更新は差別化文言の追加のみ。既存の「What」「When」部分は変更しない

### Phase 5: 品質チェック（Validate）

後述のセクション「品質チェックリスト」を適用し、全項目を確認する。

## 変換ルール

### 4.1 ソース出典の除去ルール

**書籍タイトル、著者名、出版社名、ISBN等を絶対に含めない。**

- 「~に基づく」「~を参考に」「~によると」等の出典参照フレーズを除去
- 引用ブロック (`>`) は出典を示さず、核心メッセージとして記述
- 内容は一般的なベストプラクティス・業界知識として記述

| 除去対象 | 変換後の記述 |
|---------|------------|
| 「Clean Code第3章によると...」 | 「関数設計のベストプラクティスとして...」 |
| `> -- Robert C. Martin` | `> 関数は一つのことだけを行うべきである` |
| 「ISBN 978-xxx」 | （完全に除去） |

### 4.2 AskUserQuestion配置基準

判断分岐のある箇所には、スキル内にAskUserQuestion使用を指示する文を配置する。

**配置すべき箇所:**
- アーキテクチャ選択（モノリス vs マイクロサービス等）
- ライブラリ・フレームワーク選択
- テスト戦略（範囲、ツール、対象）
- デプロイ戦略
- プロジェクト固有の要件に依存する判断

**配置不要な箇所:**
- ベストプラクティスが一義的に決まる場合（例: SQLインジェクション対策）
- セキュリティ必須対策（例: パスワードハッシュ化）
- スキル内で明確に推奨している場合

生成するスキル内に記述する指示文の例:

```markdown
### ユーザー確認の原則（AskUserQuestion）

**判断分岐がある場合、推測で進めず必ずAskUserQuestionツールでユーザーに確認する。**

確認すべき場面:
- [このスキル固有の判断分岐を列挙]

確認不要な場面:
- [明確なベストプラクティスがある場合を列挙]
```

### 4.3 Progressive Disclosure

- SKILL.md本体は **500行以下**
- セクション数5つ以上 or 推定行数500行超 --> サブファイル分割必須
- サブファイル命名: `UPPER-CASE-HYPHEN.md`（例: `BACKEND-STRATEGIES.md`）
- SKILL.mdからサブファイルへのリンクを配置

詳細は [authoring-skills](../authoring-skills/SKILL.md) の Progressive Disclosure セクション参照。

### 4.4 Frontmatter 三部構成の公式

```
[What: 三人称で能力を明記]. [When: トリガー条件]. [差別化: 類似スキルとの区別（類似スキル存在時は必須）].
```

例:
- `"Guides Next.js 16 / React 19 development. Use when package.json contains 'next'."`
- `"Enforces type safety in TypeScript/Python. Any/any types strictly prohibited. Use when processing API responses."`
- `"Converts markdown files into well-structured Claude Code Skills. Use when creating new skills from existing markdown source material. Reference authoring-skills for general skill creation guidelines."`

**注意**: 類似スキルが存在する場合、第三部の差別化文言は必須。4.6の相互description更新パターンを参照すること。

### 4.5 日本語・スタイルルール

- スキル本文は **日本語** で記述（技術用語は原語のまま）
- Frontmatterのdescriptionは **英語**
- セクション数が多い場合は目次にアンカーリンク付き
- 判断基準テーブル（`| 要素 | 値 |` 形式）を活用
- コード例はソース内容に準じた言語で記述
- チェックリストは `- [ ]` 形式

### 4.6 相互description更新パターン

類似スキルが存在する場合、**新規スキルと既存スキルの双方のdescription**に差別化文言を追加する。片方だけの更新は不完全であり、Claude Codeがスキル選択を誤る原因となる。

差別化タイプ別パターン、相互更新の実装例、更新時の注意事項の詳細は [authoring-skills/NAMING.md](../authoring-skills/NAMING.md) の「Mutual Update Requirement」セクションを参照。

**要点:**
- 既存スキルの「What」（Part 1）と「When」（Part 2）は変更しない
- 追加するのは差別化文言（Part 3）のみ
- 1つのスキルに対して複数の差別化参照を持つことは可能

## 品質チェックリスト

作成したスキルに対して以下を全項目確認する。

### Frontmatter
- [ ] name: gerund形式、小文字ハイフン区切り
- [ ] description: What（三人称）+ When（トリガー）含む
- [ ] description: 英語で記述されている（日本語混入なし）
- [ ] description: 差別化（類似スキルとの区別）含む（該当する場合）

### 相互description更新
- [ ] 類似スキルが存在する場合、新規スキルのdescriptionに差別化文言が含まれている
- [ ] 類似スキル側のdescriptionにも新規スキルへの相互参照が追加されている
- [ ] [authoring-skills/NAMING.md](../authoring-skills/NAMING.md) の差別化パターンに従っている
- [ ] 既存スキルの「What」「When」部分が変更されていない（差別化文言の追加のみ）

### 構造
- [ ] SKILL.md本体が500行以下
- [ ] サブファイルへの適切な分割（必要な場合）
- [ ] 目次/ナビゲーションあり（サブファイルがある場合）

### AskUserQuestion
- [ ] 判断分岐箇所にAskUserQuestion使用指示が配置されている
- [ ] 確認すべき場面と確認不要な場面が明記されている
- [ ] AskUserQuestionのコード例が含まれている

### ソース出典
- [ ] 書籍タイトル・著者名・出版社名が含まれていない
- [ ] 「~に基づく」等の出典参照フレーズがない
- [ ] 内容が一般的なベストプラクティスとして記述されている

### コンテンツ品質
- [ ] 日本語で記述されている（技術用語は原語）
- [ ] コード例が含まれている（該当する場合）
- [ ] 判断基準テーブルが含まれている（該当する場合）
- [ ] 自己完結している（他スキルを参照しなくても理解可能）

## 命名戦略参照

スキル名の自動推定ロジック、コンテンツパターン→gerund動詞マッピング表は [NAMING-STRATEGY.md](NAMING-STRATEGY.md) を参照。

## 関連スキル

- **[authoring-skills](../authoring-skills/SKILL.md)**: 一般的なスキル作成ガイド。命名規則、ファイル構造、評価駆動開発。このスキルの基盤
- **[writing-technical-docs](../writing-technical-docs/SKILL.md)**: 技術ドキュメントの7つのC原則。スキル内の文章品質向上に参照

## テンプレート参照

詳細なテンプレート集は [TEMPLATES.md](TEMPLATES.md) を参照。
