# データ読み込みパイプライン

RAGシステムにおけるデータ読み込みの実践的レシピ集。各ソースタイプに対して、Problem → Solution → コード例 → Discussion の形式で記述。

---

## 1. Word文書の読み込み

**課題**: Word (.docx) ファイルからテキストを抽出したい

**方法**:
- `python-docx`: 基本的なテキスト抽出（段落単位）
- `unstructured`: 要素タイプ（Title, NarrativeText, ListItem等）の分類付き抽出

```python
# python-docxによる基本読み込み
from docx import Document

doc = Document(file_path)
text = "\n".join([p.text for p in doc.paragraphs])
```

```python
# unstructuredによる構造化抽出
from unstructured.partition.docx import partition_docx

elements = partition_docx(filename=file_path)
for element in elements:
    print(f"[{element.category}] {element.text}")
```

**ポイント**:
- 単純なテキスト抽出なら python-docx で十分
- RAGシステムで要素タイプ別処理（見出し→チャプター検索、テーブル→要約生成）が必要なら unstructured を使用
- ドキュメント構造を活かしてRetrieval最適化が可能（例: 章タイトルでまず絞り込み→章内検索）

---

## 2. PDF文書の読み込み

**課題**: PDF (.pdf) ファイルからテキストとメタデータを抽出したい

**方法**: PyPDF2でページ単位のテキスト・メタデータ抽出

```python
import PyPDF2

with open(file_path, "rb") as file:
    reader = PyPDF2.PdfReader(file)
    pages = []
    for i, page in enumerate(reader.pages):
        pages.append({
            "text": page.extract_text(),
            "page_number": i + 1,
            "file_name": reader.metadata.get("/Title"),
            "images": page.images,
        })
```

**ポイント**:
- PDFは最も一般的なドキュメント形式。多くの文書は最終的にPDFに変換される
- メタデータ（タイトル、著者、作成日等）をチャンクに紐付けることで、後の検索精度が向上
- 画像やテーブルを含むPDFはRecipe 10（マルチメディアPDF）を参照
- PDFを中心にパイプラインを構築し、他形式はPDFに変換するアプローチも有効

---

## 3. CSV/Excelファイルの読み込み

**課題**: 構造化データ（CSV/Excel）をRAGシステムで扱いたい

**3つのアプローチ**:

| アプローチ | 適用場面 | 特徴 |
|-----------|---------|------|
| **行→テキスト変換** | 個別レコードへの質問 | 各行を自然言語テキストに変換 |
| **テーブル全体をプロンプトに埋め込み** | 小規模テーブル | Markdown形式でプロンプトに直接挿入 |
| **Text-to-SQL** | 集計・分析クエリ | SQLデータベースにアップロードしてLLMがSQL生成 |

**行→テキスト変換の例**:
```python
import pandas as pd

df = pd.read_excel(file_path)

def row_to_text(row):
    return (
        f"候補者は{row['age']}歳、{row['workclass']}セクターで"
        f"{row['occupation']}として勤務。"
        f"学歴: {row['education']}、収入: {row['income']}"
    )

df["text_chunk"] = df.apply(row_to_text, axis=1)
```

**選定ガイド**:
- 小規模テーブル（数十行）→ Markdown形式でプロンプトに直接挿入
- 大規模テーブル → 行単位でテキスト変換、個別質問に対応
- 集計・分析（「学歴がBachelorの候補者の何%が50k以上稼いでいるか?」）→ Text-to-SQL（Vanna AI等）

---

## 4. PostgreSQLデータベースからの読み込み

**課題**: リレーショナルDBからRAGシステムにデータを取り込みたい

```python
from sqlalchemy import create_engine
import pandas as pd

connection_string = f"postgresql+psycopg2://{user}:{password}@{host}:{port}/{database}"
engine = create_engine(connection_string)

with engine.connect() as conn:
    df = pd.read_sql("SELECT * FROM categories ORDER BY category_id", conn)
```

**ポイント**:
- PostgreSQLは `pgvector` 拡張でベクトル embedding の保存と類似検索も可能
- 認証情報は必ず `.env` ファイルで管理（ハードコーディング禁止）
- SQLAlchemy を使用することで、MySQL/SQLite等の他DBにも応用可能

---

## 5. 音声ファイルの読み込み（Speech-to-Text）

**課題**: 音声ファイルをテキストに変換してRAGシステムに取り込みたい

```python
import openai

client = openai.OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

with open(audio_path, "rb") as audio_file:
    transcription = client.audio.transcriptions.create(
        model="whisper-1", file=audio_file
    )
```

**選定ガイド**:
| 要件 | 推奨 |
|------|------|
| 素早いセットアップ・スケーラビリティ | クラウドAPI (OpenAI Whisper API, AWS, Azure, GCP) |
| 機密データの取り扱い | オンプレミスでWhisperをホスティング |

---

## 6. 画像からのテキスト抽出（OCR）

**課題**: スキャン文書や画像からテキストを抽出したい（オンプレミス対応）

```python
from PIL import Image
import pytesseract

# 画像からテキスト抽出
image = Image.open(image_path)
text = pytesseract.image_to_string(image)
```

```python
# PDFの各ページをOCR処理
from pdf2image import convert_from_path

images = convert_from_path(pdf_path)
texts = [pytesseract.image_to_string(img) for img in images]
```

**OCR vs Multimodal modelの比較**:
| 項目 | OCR (Tesseract) | Multimodal Model (GPT-4o等) |
|------|----------------|---------------------------|
| 速度 | ✅ 高速 | ❌ 低速 |
| コスト | ✅ 低コスト | ❌ 高コスト |
| データプライバシー | ✅ ローカル実行可能 | ❌ クラウドAPI（多くの場合） |
| 柔軟性 | ❌ テキスト中心の画像のみ | ✅ あらゆる画像タイプに対応 |
| プロンプト調整 | ❌ 不可 | ✅ プロンプトで出力制御可能 |

**判断基準**: テキスト中心の一貫した構造のドキュメントが大量にある → OCR。それ以外 → Multimodal model。

---

## 7. 画像からのテキスト抽出（Multimodal Model）

**課題**: 画像から柔軟にテキストを抽出したい

```python
import base64
import openai

with open(image_path, "rb") as f:
    b64_image = base64.b64encode(f.read()).decode("utf-8")

response = openai.chat.completions.create(
    model="gpt-4o",
    messages=[{
        "role": "user",
        "content": [
            {"type": "text", "text": "Extract the text from the image. If no text, return 'No text found'."},
            {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{b64_image}"}},
        ],
    }],
    max_tokens=500,
)
text = response.choices[0].message.content
```

**ポイント**: プロンプトを変えるだけで、テキスト抽出・画像説明・テーブル解析など多様なタスクに対応可能。

---

## 8. 画像の要約テキスト生成

**課題**: 画像の内容をテキストに変換して embedding 生成に使いたい

**2つのアプローチ**:
1. 画像 embedding model を直接使用（CLIP等）
2. Multimodal model で画像をテキスト要約 → テキスト embedding 生成（**推奨**: より実用的・柔軟）

```python
prompt = "You are an assistant for visually impaired users. Describe the image in detail."
# ... (Recipe 7と同じAPI呼び出しパターン、プロンプトのみ変更)
```

**ポイント**:
- 写真、風景、技術チャート等、あらゆる画像タイプに対応
- 画像タイプに応じてプロンプトを調整（例: 写真→人物描写に注力、チャート→プロセスステップに注力）
- 数百枚程度ならMultimodal modelが推奨

---

## 9. テーブルの要約テキスト生成

**課題**: PDF内の埋め込みテーブルからキーインサイトを抽出したい

```python
from unstructured.partition.pdf import partition_pdf

# PDFをパーティション分割
elements = partition_pdf(filename=pdf_path, strategy="hi_res")
tables = [str(e) for e in elements if "Table" in str(type(e))]
```

```python
# 各テーブルをLLMで要約
from openai import OpenAI

client = OpenAI()

def summarize_table(table_text):
    response = client.chat.completions.create(
        model="gpt-4o",
        messages=[{"role": "user", "content": f"Summarize the key points of this table: {table_text}"}],
        max_tokens=150,
    )
    return response.choices[0].message.content
```

**ポイント**:
- テーブルの生テキストだけでは embedding model がキーインサイトを捉えにくい
- 要約を embedding に使用し、Retrieval時には**元のテーブル全体**をプロンプトに含める
- メタデータとして元テーブルへのリンクを必ず保持

---

## 10. マルチメディアPDFの解析

**課題**: テキスト・画像・テーブルが混在するPDFを統合的に処理したい

**パイプライン**:
1. `unstructured` でPDFを要素分類（テキスト、画像、テーブル）
2. Multimodal modelで画像・テーブルのテキスト要約を生成
3. テキスト embedding を生成
4. ベクトルストアに格納（メタデータ付き）

```python
from unstructured.partition.pdf import partition_pdf
import os

os.environ["OCR_AGENT"] = "tesseract"

elements = partition_pdf(
    filename=pdf_path,
    extract_images_in_pdf=True,
    extract_image_block_types=["Image", "Table"],
    extract_image_block_output_dir=image_output_dir,
)

tables, texts, titles = [], [], []
for element in elements:
    if "Table" in str(type(element)):
        tables.append(str(element))
    elif "NarrativeText" in str(type(element)):
        texts.append(str(element))
    elif "Title" in str(type(element)):
        titles.append(str(element))
```

**各要素の処理方針**:
| 要素 | 処理 |
|------|------|
| テキスト・タイトル | チャンキング（Recursive/Semantic等）→ embedding |
| 画像 | OCR or Multimodal modelでテキスト化 → embedding |
| テーブル | LLMでキーインサイト要約 → embedding（元テーブルはメタデータに保持） |

---

## 11. 動画の読み込み

**課題**: 動画コンテンツをRAGシステムのナレッジベースに取り込みたい

**パイプライン**:
1. タイムスタンプ定義 → フレーム画像として保存
2. 各フレーム画像をMultimodal modelでテキスト要約
3. タイムスタンプ間の音声を分離 → Speech-to-Text で文字起こし
4. テキスト embedding 生成
5. ベクトルストアに格納

```python
from moviepy.editor import VideoFileClip

clip = VideoFileClip(video_path)
time_step = 10  # seconds

timestamps = list(range(0, int(clip.duration) - time_step, time_step))

# フレーム画像の抽出
for ts in timestamps:
    clip.save_frame(f"frame_{ts}.png", t=ts)

# 音声セグメントの抽出
for ts in timestamps:
    audio = clip.subclip(ts, ts + time_step).audio
    audio.write_audiofile(f"audio_{ts}.mp3")
```

**ポイント**:
- 動画のスタイルに応じてタイムスタンプを調整（スライドショー: 30秒間隔、議論: 10秒間隔等）
- フレームの変化が少ない区間の自動検出には画像処理ライブラリを活用
- メタデータにタイムスタンプを保持し、元動画の該当箇所に直接リンク可能に
