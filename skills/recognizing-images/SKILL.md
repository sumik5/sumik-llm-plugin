---
name: recognizing-images
description: >-
  Converts images to markdown text using LM Studio's local VLM (qwen/qwen3.5-9b) via lmstudio Python SDK.
  Use when extracting text from images (OCR), converting handwritten notes, or processing visual documents.
  Supports single file or directory (batch processing). For text translation, use translating-with-lmstudio instead.
disable-model-invocation: true
argument-hint: "<path-to-image-or-directory>"
---

## 禁止事項

- 画像ファイルを Read ツールで読み込んではならない（トークン浪費。スクリプトが処理する）
- INSTRUCTIONS.md の Read は不要
- Claude自身のVision能力で画像を解釈してはならない。必ず以下のスクリプトを実行すること

## 実行（以下の Bash コマンドを即座に実行すること）

```bash
python3 -c "import lmstudio" 2>/dev/null || pip install lmstudio -q
python3 ${CLAUDE_PLUGIN_ROOT}/skills/recognizing-images/scripts/recognize-image.py \
  --model "qwen/qwen3.5-9b" \
  --path "$ARGUMENTS"
```

スクリプトの stdout がMarkdown形式の認識結果。そのまま出力する。

## エラー時

> LM Studio が起動中でモデルがロードされていることを確認してください。
