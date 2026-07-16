# 多言語対応リファレンス

英語（外国語）ソースのフラッシュカード作成時に参照するガイド。翻訳ワークフロー・HTMLフォーマット・大規模処理の詳細を集約。

**位置付け**:
- メインワークフロー（Step 2: 言語検出）から参照される
- 翻訳インフラ: `converting-content` スキルの LM Studio パイプラインを使用
- 投入インフラ: `scripts/anki_toolkit.py` の `upload()` に任せる（手書き不要）

---

## 英語（外国語）コンテンツの処理方針

ソースが英語等の外国語の場合、以下の方針で処理する:

1. **`converting-content` スキルのワークフローで翻訳**する（LM Studioのローカル LLMを使用）。セッション内初回の翻訳時はモデル選択が必要。
2. **問題文・選択肢・解答・解説を日本語に翻訳**してカードのメインコンテンツとする
3. **原文は折りたたみセクション（`<details>`）として保持**する
4. 折りたたみはデフォルトで閉じており、タップ/クリックで展開できる

---

## 翻訳コマンド（少量: 30問以下）

各テキストブロックを以下のコマンドで翻訳する:

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/skills/converting-content/scripts/lmstudio-translate.py translate --model <選択済みモデル> --text "翻訳対象テキスト"
```

### エラーハンドリング

LM Studio APIがエラーを返した場合、フォールバックなしでユーザーに通知する:

> 「LM StudioのAPIがエラーを返しています。LM Studioが起動しモデルがロードされていることを確認してください。準備完了まで待ちます。」

---

## HTMLフォーマット（英語ソース）

### Frontフィールド

```html
[日本語に翻訳された問題文]<br><br>
<ol style="list-style-type: none; padding-left: 0;">
  <li>A. [日本語の選択肢]</li>
  <li>B. [日本語の選択肢]</li>
  <li>C. [日本語の選択肢]</li>
  <li>D. [日本語の選択肢]</li>
</ol>
<br>
<details>
<summary>📄 原文（English）</summary>
<br>
[Original English question text]<br><br>
A. [Original English choice]<br>
B. [Original English choice]<br>
C. [Original English choice]<br>
D. [Original English choice]
</details>
```

### Backフィールド

```html
<b>正解の選択肢:</b><br><br>
[日本語の正解テキスト]<br><br>
<b>解説:</b><br><br>
[日本語の解説]<br><br>
<b>不正解の選択肢の解説:</b><br><br>
<b>B:</b> [日本語の不正解解説]<br><br>
<b>C:</b> [日本語の不正解解説]<br><br>
<details>
<summary>📄 原文（English）</summary>
<br>
<b>Correct Answer:</b><br><br>
[Original English answer]<br><br>
<b>Explanation:</b><br><br>
[Original English explanation]
</details>
```

---

## 翻訳時の注意事項

- **コード値の翻訳スキップ**: `response.model`, `$INPUT` 等の短いコード値は翻訳モデルが「テキストが提供されていません」等のエラーを返すことがある。翻訳パイプラインに `is_code_like()` ヒューリスティックを実装し、以下のパターンはスキップする:
  - `$` プレフィックス付き（例: `$ARGUMENTS`, `$INPUT`）
  - ドット区切り識別子（例: `response.model`, `client.messages.create()`）
  - バッククォートで囲まれた値（例: `` `tool_use` ``）
  - 2つ以上のコード文字（`.`, `_`, `()`, `[]`, `{}`, `::`, `/`）を含む60文字未満の文字列
- **バッククォートアーティファクト**: translategemma等の翻訳モデルはMarkdownバッククォートを出力に付加することがある。翻訳後に `` ` `` + `<code>` や `</code>` + `` ` `` の組み合わせを除去するポスト処理を実装すること
- **技術用語**: サービス名、プロダクト名、コマンド名等はそのまま英語で保持（例: Cloud Run, kubectl, Binary Authorization）
- **翻訳品質**: 直訳ではなく、自然な日本語にする。ただし原文の意味を変えない
- **選択肢の対応**: 翻訳後の選択肢と原文の選択肢の順序を一致させる

---

## 大規模翻訳の処理（100問以上）

100問以上の英語コンテンツを翻訳する場合、**自己完結型パイプラインスクリプト**を生成してバックグラウンド実行する:

1. **パース**: 全Q&AペアをJSON（英語）に抽出（パーサースクリプト）
2. **パイプラインスクリプト生成**: 翻訳→HTMLフォーマット→Ankiアップロードを1つのPythonスクリプトにまとめる
   - LM Studio API（`http://127.0.0.1:1234/v1/chat/completions`）を`urllib.request`で直接呼び出す
   - 問題文、各選択肢、解説を個別に翻訳。🔴 翻訳スキップ判定には `anki_toolkit.is_code_like(text)` を使う（`$` プレフィックス・ドット区切り識別子・バッククォート囲み・コード文字を多く含む短文を `True` 判定。「翻訳時の注意事項」参照）
   - HTMLフォーマット: 翻訳結果と原文を `QAPair`（`original_front` / `original_back` に英語原文を格納）に詰める。`<details>` 折りたたみ英語原文の整形は `build_front_html()` / `build_back_html()` が担う
   - 投入は `anki_toolkit.upload()` に任せる（`addNotes` バッチ・冪等性・進捗出力は toolkit が処理。手書きしない）
3. **バックグラウンド実行**: Bashツールの `run_in_background: true` で起動し、`TaskOutput` で進捗を監視

> ⚠️ 大規模翻訳パイプラインでも投入インフラ（`addNotes` バッチ・冪等性）と翻訳スキップ判定（`is_code_like()`）は toolkit から使い、毎回書き起こさない。パイプラインのうち**ソース固有なのは parse と翻訳呼び出しのオーケストレーションだけ**。

> ⚠️ **スクリプト呼び出しではなくAPI直接呼び出しの理由**: `lmstudio-translate.py` スクリプトを毎回プロセス起動すると、149問 × (問題文+選択肢4つ+解説) = 約900回のプロセス生成オーバーヘッドが発生する。API直接呼び出しなら1プロセスで全翻訳を処理でき、大幅に効率的。
