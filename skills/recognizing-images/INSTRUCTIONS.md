# LM Studio を使った画像テキスト認識

LM Studio のローカル VLM を使って画像→Markdown変換。単一ファイル/ディレクトリ一括処理対応。

## 前提

- LM Studio 起動中、`qwen/qwen3.5-9b` ロード済み
- API: `http://localhost:1234`

---

## 実行

**$ARGUMENTS にパスが指定されている場合、依存チェック後に即座に実行する。モデル一覧取得・選択は不要。**

### Step 1: 依存関係チェック

```bash
python3 -c "import openai" 2>/dev/null || pip install openai -q
```

### Step 2: 画像認識実行

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/skills/recognizing-images/scripts/recognize-image.py recognize \
  --model "qwen/qwen3.5-9b" \
  --path $ARGUMENTS
```

ディレクトリ指定時は画像（`.png`, `.jpg`, `.jpeg`, `.webp`）を自動検出し、各ファイルごとにAPI呼び出し。結果はまとめて出力。

### エラー時

> LM Studio の API がエラーを返しています。LM Studio が起動中でモデルがロードされていることを確認してください。
