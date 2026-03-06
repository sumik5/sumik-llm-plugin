# LM Studio を使った画像テキスト認識

LM Studio のローカル VLM（Vision Language Model）を使って画像からテキストを抽出し、Markdown 形式で返すスキル。
単一ファイルまたはディレクトリ指定による一括処理に対応。

## 前提条件

- LM Studio が起動中であること
- `qwen/qen3.5-9b` モデル（または他の Vision 対応モデル）がロード済みであること
- デフォルトの API エンドポイント: `http://localhost:1234`

---

## ワークフロー

### Step 1: 依存関係チェック

`openai` パッケージが存在するか確認し、なければインストールする。

```bash
python3 -c "import openai" 2>/dev/null || pip install openai -q
```

---

### Step 2: LM Studio 接続確認 + モデル選択（セッション初回のみ）

**モデル一覧取得:**

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/skills/recognizing-images/scripts/recognize-image.py list-models
```

**モデル選択:**

取得したモデル一覧を選択肢として AskUserQuestion でユーザーに選択してもらう。
デフォルトは `qwen/qen3.5-9b`。

**重要:** セッション内で一度選択したモデルはそのまま記憶して使い続ける。

---

### Step 3: 画像認識実行

**単一ファイル:**

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/skills/recognizing-images/scripts/recognize-image.py recognize \
  --model "qwen/qen3.5-9b" \
  --path /path/to/image.png
```

**ディレクトリ（一括処理）:**

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/skills/recognizing-images/scripts/recognize-image.py recognize \
  --model "qwen/qen3.5-9b" \
  --path /path/to/image-directory/
```

ディレクトリ指定時は、含まれる画像ファイル（`.png`, `.jpg`, `.jpeg`, `.webp`）を自動検出し、
各ファイルごとに LM Studio API を呼び出す。結果は全ファイル分をまとめて1回で stdout に出力する。

**出力形式（複数ファイル時）:**

```markdown
## image1.png

[画像1のMarkdown内容]

---

## image2.jpg

[画像2のMarkdown内容]
```

---

### Step 4: エラーハンドリング

API が失敗した場合、**フォールバックは行わない**。

スクリプトが stderr にエラーメッセージを出力し exit code 1 で終了する。
その場合はユーザーに以下を通知する:

> LM Studio の API がエラーを返しています。
> LM Studio が起動中でモデルがロードされていることを確認してください。
> 準備ができたらお知らせください。

---

## 対応画像フォーマット

- PNG (`.png`)
- JPEG (`.jpg`, `.jpeg`)
- WebP (`.webp`)

---

## 関連スキル

- `translating-with-lmstudio`: LM Studio を使ったテキスト翻訳（画像ではなくテキスト処理）
