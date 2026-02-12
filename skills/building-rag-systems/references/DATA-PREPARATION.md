# データ準備パイプライン

RAGシステムにおけるデータ前処理とテキスト分割の実践的レシピ集。

---

## 概要

RAGパイプラインにおけるデータ準備の主要ステップ:

1. **テキストクリーニング**: 略語展開、コンテキスト補完でチャンクの自己完結性を向上
2. **メタデータ収集・生成**: 検索フィルタリングの高速化・精度向上
3. **テキスト分割**: 適切なチャンキング戦略でembedding品質を最大化

---

## 1. メタデータ付与によるフィルタリング強化

**課題**: ベクトル検索の前にメタデータで検索空間を絞り込みたい

**3段階のメタデータ収集**:

### Step 1: ドキュメント既存メタデータの抽出

```python
import PyPDF2

with open(file_path, "rb") as f:
    reader = PyPDF2.PdfReader(f)
    metadata = reader.metadata  # 著者、作成日、修正日、タイトル等
    text = "".join(page.extract_text() for page in reader.pages)
```

### Step 2: カスタムメタデータの追加

```python
import os

metadata = dict(metadata)
metadata["page_count"] = len(reader.pages)
metadata["file_size"] = os.path.getsize(file_path)
metadata["file_name"] = os.path.basename(file_path)
metadata["text_length"] = len(text)
```

### Step 3: LLMによるメタデータ生成

テキスト内の情報（著者名、連絡先、ドキュメント分類等）をLLMで構造化抽出:

```python
from pydantic import BaseModel
from openai import OpenAI

class AuthorContact(BaseModel):
    name: str
    company: str
    email: list[str]

class Contacts(BaseModel):
    entries: list[AuthorContact]

client = OpenAI()
completion = client.beta.chat.completions.parse(
    model="gpt-4o",
    messages=[
        {"role": "system", "content": "Extract the contact information of all authors."},
        {"role": "user", "content": text},
    ],
    response_format=Contacts,
)
contacts = completion.choices[0].message.parsed
```

**ポイント**:
- セマンティック類似度が高くても文脈的に無関係な情報がある（例: 医学における「抗酸化物質の効果」vs 工学における「原材料への抗酸化物質の影響」）
- メタデータフィルタリングでこの問題を緩和
- 有効なフィルタ例: ドキュメント種別、発行期間、著者、特定のキーワードやエンティティ
- Pydantic model で構造化出力を定義し、LLMが期待するフォーマットで応答するよう制約

---

## 2. 略語展開によるデータ品質改善

**課題**: ドメイン固有の略語がチャンクの理解を困難にしている

### Challenge 1: 辞書ベースの略語展開

```python
import re

abbreviations = {
    "NLP": "Natural Language Processing",
    "LSTM": "Long Short-Term Memory",
    "FFN": "Feed-Forward Network",
}

for abbr, full_form in abbreviations.items():
    text = re.sub(rf"\b{abbr}\b", f"{full_form} ({abbr})", text)
```

### Challenge 2: LLMによるコンテキスト補完

```python
from openai import OpenAI

prompt = f"""
以下のテキストには専門用語と略語が多数含まれています。
略語を正式名称に置き換え、技術用語に簡潔な説明を追加してください。

テキスト:
{text}
"""

client = OpenAI()
response = client.chat.completions.create(
    model="gpt-4o",
    messages=[{"role": "user", "content": prompt}],
)
enhanced_text = response.choices[0].message.content
```

**テキスト品質改善のベストプラクティス**:
1. コンテキスト文の追加: 「It improved efficiency by 40%」→「新しいインデクシングアルゴリズムが検索効率を40%向上させた」
2. 代名詞・暗黙的参照の排除: 「It was implemented」→「顧客フィードバックシステムが実装された」
3. エンティティのフルネーム保持: 「Google launched it」→「GoogleがBERT言語モデルをローンチした」
4. 曖昧な表現の具体化: 「動作が改善された」→「応答時間が500msから200msに短縮された」

---

## 3. 仮想質問（Hypothetical Questions）による検索精度向上

**課題**: ユーザー質問とドキュメントコンテンツの embedding 空間でのミスマッチを解消したい

**概念**: テキストチャンクから「そのチャンクで回答可能な質問」を事前に生成し、質問の embedding を検索インデックスに使用する。

**ステップ**:
1. テキストをチャンクに分割
2. 各チャンクに対してLLMで仮想質問を5個程度生成
3. 仮想質問の embedding を生成
4. ベクトルDBに格納（メタデータとして元テキストチャンクへのリンクを保持）
5. 検索時: ユーザー質問と仮想質問の類似度を比較
6. マッチした仮想質問に紐づく**元テキストチャンク**をLLMに渡す

```python
from pydantic import BaseModel
from openai import OpenAI

class HypotheticalQuestions(BaseModel):
    questions: list[str]

client = OpenAI()

prompt = f"""
以下のテキストチャンクから回答可能な仮想質問を5つ生成してください。
質問はキーとなる詳細、定義、情報に焦点を当ててください。

テキスト:
{chunk_text}
"""

completion = client.beta.chat.completions.parse(
    model="gpt-4o",
    messages=[{"role": "user", "content": prompt}],
    response_format=HypotheticalQuestions,
)
questions = completion.choices[0].message.parsed.questions
```

**なぜ効果があるか**:
- 基本的なRAGではユーザー質問をテキストチャンクと直接比較する
- テキストチャンクの形式は多様（コードスニペット、テーブル、会話ログ等）で、質問との意味的整合性が低い場合がある（Semantic Alignment Problem）
- 仮想質問は「質問」形式同士の比較になるため、embedding 空間での類似度が向上

---

## 4. Character Splitting（文字数ベース分割）

**課題**: テキストを固定長のチャンクに分割したい

```python
from langchain.text_splitter import CharacterTextSplitter

splitter = CharacterTextSplitter(
    chunk_size=100,
    chunk_overlap=0,
    separator=" ",
    length_function=len,
)
chunks = splitter.create_documents([text])
```

**特徴**:
- 最もシンプルな分割手法
- ドキュメント構造を一切考慮しない
- 段落や文の途中で分割される可能性

**適用場面**: 構造のないログファイル、リアルタイムデータストリーム等
**非推奨**: 一般的なテキストドキュメント → Recursive Text Splitting を推奨

---

## 5. Recursive Text Splitting（再帰的分割）

**課題**: ドキュメント構造（段落、見出し）を考慮してテキストを分割したい

```python
from langchain_text_splitters import RecursiveCharacterTextSplitter

splitter = RecursiveCharacterTextSplitter(
    chunk_size=200,
    chunk_overlap=0,
    length_function=len,
    is_separator_regex=False,
)
chunks = splitter.split_text(text)
```

**仕組み**: デフォルトセパレータの優先順位:
1. `\n\n`（段落区切り）
2. `\n`（改行）
3. ` `（スペース）
4. `.`（文末）

chunk_sizeに達したら、最も優先度の高いセパレータで分割。

**ポイント**:
- **ほとんどのケースでデフォルト推奨**
- 推奨チャンクサイズ: 1,000-2,000 tokens（約4,000-8,000文字）
- デモ100文字は概念説明用。実運用ではもっと大きいサイズを使用
- 日本語・中国語・タイ語等の単語境界がない言語ではカスタムセパレータが必要
- 各チャンクは1つのアイデアを明確にカバーすることが理想

---

## 6. Document-Aware Splitting（構文認識分割）

**課題**: Markdown、HTML、LaTeX、Python等の構文を理解した分割をしたい

```python
from langchain_text_splitters import (
    PythonCodeTextSplitter,
    LatexTextSplitter,
    MarkdownHeaderTextSplitter,
)

extension = os.path.splitext(file_path)[1]

if extension == ".py":
    splitter = PythonCodeTextSplitter(chunk_size=500, chunk_overlap=50)
elif extension == ".tex":
    splitter = LatexTextSplitter(chunk_size=500, chunk_overlap=50)
elif extension == ".md":
    splitter = MarkdownHeaderTextSplitter(chunk_size=500, chunk_overlap=50)

chunks = splitter.split_text(file_text)
```

**適用場面**: マークアップ言語で記述されたドキュメント
**メリット**: 言語固有の構文要素（見出し、コードブロック、セクション）を認識して適切に分割

---

## 7. Semantic Chunking（意味ベース分割）

**課題**: 構造がないドキュメント（音声文字起こし、チャットログ等）を意味単位で分割したい

**仕組み**:
1. テキストを文単位に分割
2. 各文の embedding を生成
3. 連続する文間の意味的類似度を計算
4. 類似度が閾値を下回る箇所で分割

```python
from langchain_experimental.text_splitter import SemanticChunker
from langchain_openai.embeddings import OpenAIEmbeddings

splitter = SemanticChunker(
    OpenAIEmbeddings(),
    breakpoint_threshold_type="percentile",
    breakpoint_threshold_amount=90,
)
chunks = splitter.split_text(text)
```

**閾値設定方法**:
| 方法 | 説明 |
|------|------|
| percentile | 全距離のN%ile以上で分割（例: 90th percentile） |
| standard_deviation | 平均+N×標準偏差を超えたら分割 |
| gradient | 距離の変化率（勾配）が急激な箇所で分割 |

**トレードオフ**:
- ✅ 構造のないテキストでも意味的に一貫したチャンク生成
- ❌ Embedding model の呼び出しが必要（コスト・時間）
- ❌ まだ実験的段階のライブラリが多い

---

## 8. Agentic Chunking（エージェント型分割）

**課題**: 複雑な長文ドキュメントで、関連情報を統合した意味のあるチャンクを作りたい

**概念**: LLMを使ってテキストを「命題（proposition）」に分解し、類似する命題をグループ化。

**命題の例**:
- 原文: 「Sarahは新しい本を買った。彼女はファンタジー小説を楽しんでいる。」
- 命題1: 「Sarahは新しい本を買った。」
- 命題2: 「Sarahはファンタジー小説を楽しんでいる。」
- 命題3: 「Sarahは暇な時間にファンタジー小説を読む。」（暗示）

```python
from langchain import hub
from langchain_openai import ChatOpenAI
from pydantic import BaseModel
from typing import List

# LangChain Hub からProposition Indexing用プロンプトを取得
prompt_template = hub.pull("wfh/proposal-indexing")

llm = ChatOpenAI(model="gpt-4o")

class Sentences(BaseModel):
    sentences: List[str]

extraction_chain = prompt_template | llm.with_structured_output(Sentences)

# テキストチャンクから命題を抽出
result = extraction_chain.invoke(text_chunk)
propositions = result.sentences
```

**パイプライン**:
1. テキストをRecursive splitterで大まかに分割（段落単位）
2. 各段落をLLMに渡して命題リストを生成
3. 命題を順次レビュー:
   - 既存チャンクと関連あり → 既存チャンクに追加
   - 新しいトピック → 新チャンク作成
4. 最終的な命題ベースのチャンクをベクトルDBに格納

**トレードオフ**:
- ✅ 散在する関連情報を統合した高品質チャンク
- ✅ 代名詞をフルネームに置換、自己完結したチャンク生成
- ❌ 全テキストをLLM処理するため高コスト
- ❌ 成熟したライブラリがまだ少ない

---

## チャンキング戦略の選定フローチャート

```
どのチャンキング戦略を使うべきか？

1. ドキュメントに構造（見出し・段落）があるか？
   ├── はい → マークアップ言語か？
   │   ├── はい (MD/HTML/LaTeX/Python) → Document-Aware Splitting
   │   └── いいえ → Recursive Text Splitting 【推奨デフォルト】
   └── いいえ → ドキュメントの複雑さは？
       ├── 低い（ログ、単純なストリーム）→ Character Splitting
       ├── 中程度（会話、音声文字起こし）→ Semantic Chunking
       └── 高い（契約書、技術文書、相互参照多）→ Agentic Chunking

追加考慮事項:
- コスト制約が厳しい → Recursive (無料) > Semantic (Embedding API) > Agentic (LLM API)
- 品質最優先 → Agentic > Semantic > Recursive > Character
```

---

## まとめ

データ準備はRAGシステムの品質を決定する重要なステップ。以下の原則を押さえる:

1. **メタデータでフィルタリング強化**: セマンティック検索の限界を補完
2. **テキスト品質を向上**: 略語展開、コンテキスト補完で自己完結したチャンク作成
3. **適切なチャンキング戦略選定**: ドキュメント構造・コスト・品質要件に応じて選択
4. **仮想質問の活用**: embedding 空間での質問-チャンク間のアライメント改善

ほとんどのユースケースでは **Recursive Text Splitting** がデフォルト推奨。構造のない複雑なドキュメントや高品質が求められる場合は Semantic / Agentic Chunking を検討する。
