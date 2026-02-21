---
name: translating-with-lmstudio
description: >-
  Translates English text to Japanese using LM Studio's local LLM via OpenAI-compatible API.
  Use when English-to-Japanese translation is needed for flashcard creation or skill authoring.
  For general-purpose translation without local LLM, Claude handles it directly instead.
disable-model-invocation: true
---

# LM Studio を使った英語→日本語翻訳

LM Studio のローカル LLM を使って英語テキストを自然な日本語に翻訳するスキル。
`creating-flashcards` や `authoring-skills` での翻訳処理を一元化する。

## 前提条件

- LM Studio が起動中であること
- 翻訳に使用するモデルがロード済みであること
- デフォルトの API エンドポイント: `http://localhost:1234`

---

## ワークフロー

### Step 1: 依存関係チェック

`openai` パッケージが存在するか確認し、なければインストールする。

```bash
python3 -c "import openai" 2>/dev/null || pip install openai -q
```

スクリプト自体も起動時に自動インストールを試みるが、事前確認しておくと確実。

---

### Step 2: LM Studio 接続確認 + モデル選択（セッション初回のみ）

**モデル一覧取得:**

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/lmstudio-translate.py list-models
```

出力例:
```json
["lmstudio-community/gemma-3-12b-it-GGUF", "lmstudio-community/qwen2.5-7b-instruct-GGUF"]
```

**モデル選択:**

取得したモデル一覧を選択肢として AskUserQuestion でユーザーに選択してもらう。

```
どのモデルを使用しますか？
> lmstudio-community/gemma-3-12b-it-GGUF  ← 選択
  lmstudio-community/qwen2.5-7b-instruct-GGUF
```

**重要:** セッション内で一度選択したモデルはそのまま記憶して使い続ける。
次回以降の翻訳では「前回選択した `<モデル名>` を使用します」と明記し、再選択は不要。

---

### Step 3: 翻訳実行

**短文（コマンドライン引数で渡す場合）:**

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/lmstudio-translate.py translate \
  --model <選択したモデル名> \
  --text "Text to translate"
```

**長文（stdin から渡す場合）:**

```bash
echo "Long text to translate..." | \
  python3 ${CLAUDE_PLUGIN_ROOT}/scripts/lmstudio-translate.py translate \
    --model <選択したモデル名>
```

翻訳結果は stdout に出力される。

---

### Step 4: エラーハンドリング

API が失敗した場合、**フォールバックは行わない**。

スクリプトが stderr にエラーメッセージを出力し exit code 1 で終了する。
その場合はユーザーに以下を通知する:

> LM Studio の API がエラーを返しています。
> LM Studio が起動中でモデルがロードされていることを確認してください。
> 準備ができたらお知らせください。

準備完了の連絡を受けてから翻訳を再試行する。

---

## 翻訳時の注意事項

- **技術用語はそのまま英語で保持する**: サービス名・プロダクト名・コマンド名・ライブラリ名など
  - 例: "Next.js", "Docker", "kubectl", "OpenAI API" → 翻訳しない
- **直訳ではなく自然な日本語にする**: 文脈に応じて意訳を選ぶ
- **原文の意味を変えない**: ニュアンスや強調・構造を保持する

---

## 関連スキル

- `creating-flashcards`: フラッシュカード作成時の英語→日本語翻訳に使用
- `authoring-skills`: ソース素材の英語セクションを日本語に変換する際に使用
