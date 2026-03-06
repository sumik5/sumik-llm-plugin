# LM Studio 画像テキスト認識

## 禁止事項

- 画像ファイルを Read ツールで読み込んではならない（トークン浪費。スクリプトが処理する）
- モデル一覧取得は不要

## 実行（即座に実行すること）

```bash
python3 -c "import openai" 2>/dev/null || pip install openai -q
python3 ${CLAUDE_PLUGIN_ROOT}/skills/recognizing-images/scripts/recognize-image.py recognize \
  --model "qwen/qwen3.5-9b" \
  --path "$ARGUMENTS"
```

スクリプトの stdout がMarkdown形式の認識結果。そのまま出力する。

## エラー時

> LM Studio が起動中でモデルがロードされていることを確認してください。
