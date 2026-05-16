---
description: >-
  creating-flashcards スキルを実行した直後のセッションを分析し、新たに発見したパーサー罠・
  OCRアーティファクト・構造パターン・判定マーカー表記揺れ等の知見を CONTENT-PROCESSING.md /
  INSTRUCTIONS.md に追記してスキルを進化させるコマンド。
  Use when a flashcard creation session has just completed and you want to capture
  newly discovered parsing patterns or edge cases into the skill files.
  会話履歴を自動抽出し、追記案を diff 提示 → ユーザー承認後に PATCH bump + commit + タグ付与まで一気通貫で実行。
allowed-tools: Read, Edit, Write, Glob, Grep, Bash, AskUserQuestion
user-invocable: true
argument-hint: "[追記したい知見の補足メモ]"
---

# /improve-creating-flashcards

`creating-flashcards` スキルの自己進化コマンド。フラッシュカード作成セッションで発見した新知見をスキルファイルへ自動追記し、次回以降の精度を向上させる。

## 概要

| 項目 | 内容 |
|------|------|
| 実行タイミング | `creating-flashcards` によるカード作成・パーサー実装を終えた直後 |
| 入力 | 現セッションの会話履歴（自動抽出）＋ 任意の補足メモ（`$ARGUMENTS`） |
| 出力 | スキルファイル更新・PATCH バージョン bump・コミット・タグ |

## 前提

直近セッションで以下のいずれかを実施していること:

- `creating-flashcards` スキルを使ったフラッシュカード生成
- EPUB/PDF パーサーの実装・デバッグ
- AnkiConnect / Anki MCP の操作

---

## ワークフロー

### Step 1: セッション履歴の自動分析

現セッションの会話履歴を見返し、以下カテゴリで知見候補を抽出する:

| カテゴリ | 抽出対象 |
|---------|---------|
| (a) パーサーバグ修正 | クリーニング・正規表現・型変換等で発生したバグと修正方法 |
| (b) pandoc/OCR アーティファクト | 新しいアーティファクトパターン・エスケープ文字の変異 |
| (c) 構造パターン | pages accumulate-flush・テーマ分離型サブパターン等の新変種 |
| (d) 判定マーカー表記揺れ | ○×・◯✕・Unicode 変種の新ケース |
| (e) フォーマット/HTML/ノートタイプ干渉 | 予期しないレンダリング・フィールド干渉の新ケース |
| (f) AnkiConnect/MCP の罠 | per-note エラー・重複処理・接続失敗の新パターン |

`$ARGUMENTS` に補足メモが渡された場合は、それも分析対象に加える。

### Step 2: 既存スキルとの重複チェック

以下のファイルを Read/Grep で精査し、抽出候補のうち**既に記載済みのもの**を除外する。  
重複判定は語彙ではなく**意味レベル**で行うこと（例: 「Unicode `◯` 追加」は既存記述あり）。

- `skills/creating-flashcards/SKILL.md`
- `skills/creating-flashcards/INSTRUCTIONS.md`
- `skills/creating-flashcards/references/CONTENT-PROCESSING.md`
- `skills/creating-flashcards/references/ANKI-MCP-GUIDE.md`
- `skills/creating-flashcards/references/ANKI-MCP-TOOLS.md`

### Step 3: 追記案の構造化

新規知見それぞれについて以下の要素を整理する:

1. **対象ファイル**: 追記先のスキルファイルパス
2. **追記位置**: 挿入先の既存セクション名と行番号の目安
3. **追記文面**: 既存の警告ブロック形式に揃える:
   ```
   > ⚠️ **[タイトル]**: [説明文]
   ```
4. **発見経緯**: どの作業で問題化したか（1〜2文）

### Step 4: 追記案の提示と承認

#### 抽出ゼロ件の場合

「新規知見なし。スキル進化不要」と報告して終了。

#### 1件以上の場合

以下の形式で diff プレビューを出力する:

```
## 抽出した知見 N 件

### 知見1: [タイトル]
**対象ファイル**: skills/creating-flashcards/references/CONTENT-PROCESSING.md
**追記位置**: line XXX 付近（[既存セクション名] の直後）
**追記内容**:
> ⚠️ **[タイトル]**: [本文]

**発見経緯**: [1〜2文]

### 知見2: ...
```

AskUserQuestion で以下を選択させる:

```python
AskUserQuestion(
    questions=[{
        "question": "抽出した知見をスキルに反映しますか？",
        "header": "スキル自己改善 確認",
        "options": [
            {"label": "全件採用してファイル編集・コミット・タグまで実行（推奨）",
             "description": "N件すべてを採用。編集 → PATCH bump → コミット → タグまで一気通貫"},
            {"label": "一部のみ採用",
             "description": "採用する知見番号を Other で指定してください"},
            {"label": "ファイル編集のみ（コミット・タグはスキップ）",
             "description": "スキルファイルだけ更新し、git 操作は行わない"},
            {"label": "全部却下・終了",
             "description": "変更なしで終了"}
        ],
        "multiSelect": False
    }]
)
```

### Step 5: ファイル編集

承認された知見を Edit ツールで対象ファイルへ追記した後、書籍名・著者名・出版社名の混入がないか機械チェックする:

```bash
grep -nE "『|』|TAC|オライリー|オーム社|技術評論|翔泳社|日経BP|インプレス" \
  skills/creating-flashcards/references/CONTENT-PROCESSING.md \
  skills/creating-flashcards/INSTRUCTIONS.md
```

検出ゼロを確認する。検出された場合は該当知見をユーザーへ返送し、汎用表現への置換を求める。

### Step 6: バージョン更新・コミット・タグ付与

> ⚠️ Step 4 で「コミット・タグまで実行」が承認された場合のみ実施する

1. `.claude-plugin/plugin.json` の `version` を **PATCH bump**（パッチ番号 +1）
   - 理由: 既存スキルへの知見追記 = PATCH（新規コマンド追加の MINOR とは別の意味論）

2. Conventional Commits 形式でコミット:

   ```bash
   git add skills/creating-flashcards/ .claude-plugin/plugin.json
   git commit -m "docs(creating-flashcards): N件の追加知見を CONTENT-PROCESSING.md に反映"
   ```

3. アノテーション付きタグを付与:

   ```bash
   git tag -a "v<new-version>" -m "docs(creating-flashcards): スキル自己改善 N件"
   ```

4. **push は実行しない**（ユーザーが明示的に指示した場合のみ）

---

## 完了報告フォーマット

```
## 採用した知見 N 件
- 対象ファイル: [ファイル名]（+X 行）
- 新バージョン: 9.X.Y
- タグ: v9.X.Y
- push: 未実施（必要な場合は `git push && git push --tags` を実行）
```

---

## 既存スキル Step 9 との関係

`INSTRUCTIONS.md` の **Step 9「スキル自己改善」** は手動チェックリストとして引き続き有効。  
本コマンドはその**自動エントリポイント**として設計されており、セッション末に `/improve-creating-flashcards` を実行することで Step 9 の作業を一気通貫で完了できる。
