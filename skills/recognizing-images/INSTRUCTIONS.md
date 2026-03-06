# LM Studio 画像テキスト認識

lmstudio Python SDK（`lms.prepare_image` + `lms.Chat`）で画像→Markdown変換。

## 実行

```bash
python3 -c "import lmstudio" 2>/dev/null || pip install lmstudio -q
python3 ${CLAUDE_PLUGIN_ROOT}/skills/recognizing-images/scripts/recognize-image.py \
  --model "qwen/qwen3.5-9b" \
  --path "$ARGUMENTS"
```

## エラー時

> LM Studio が起動中でモデルがロードされていることを確認してください。
