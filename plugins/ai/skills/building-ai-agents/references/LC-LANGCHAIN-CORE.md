# LangChain Core: LCEL・プロンプト・Chain合成

## 目次

1. [LCEL（LangChain Expression Language）](#1-lcellangchain-expression-language)
2. [PromptTemplate](#2-prompttemplate)
3. [ChatModel / LLM](#3-chatmodel--llm)
4. [OutputParser](#4-outputparser)
5. [Chain合成パターン](#5-chain合成パターン)
6. [判断テーブル: ChainかAgentか](#6-判断テーブル-chainかagentか)

---

## 1. LCEL（LangChain Expression Language）

### Runnable Protocol

LangChainのすべてのコンポーネントは `Runnable` インターフェースを実装する。これにより統一された方法でコンポーネントを組み合わせることができる。

| メソッド | 説明 | 使用場面 |
|--------|------|---------|
| `invoke(input)` | 同期実行・単一入力 | 通常の実行 |
| `stream(input)` | ストリーミング出力 | リアルタイム表示 |
| `batch([inputs])` | バッチ処理 | 複数入力の並列処理 |
| `ainvoke(input)` | 非同期実行 | async/await環境 |
| `astream(input)` | 非同期ストリーミング | 非同期リアルタイム |
| `abatch([inputs])` | 非同期バッチ | 高スループット処理 |

### pipe演算子（`|`）によるChain合成

```python
from langchain_core.prompts import ChatPromptTemplate
from langchain_openai import ChatOpenAI
from langchain_core.output_parsers import StrOutputParser

prompt = ChatPromptTemplate.from_template("{topic}について説明してください")
llm = ChatOpenAI(model="gpt-4o-mini")
parser = StrOutputParser()

# Chain合成: prompt → llm → parser
chain = prompt | llm | parser

# 実行
result = chain.invoke({"topic": "LangChain"})
```

### RunnablePassthrough

```python
from langchain_core.runnables import RunnablePassthrough

# 入力をそのまま次のステップに渡す
chain = (
    {"context": retriever, "question": RunnablePassthrough()}
    | prompt
    | llm
    | StrOutputParser()
)
# "What is RAG?" という文字列を渡すと
# question="What is RAG?" として扱われ、
# contextにはretrieverの結果が入る
```

### RunnableLambda

```python
from langchain_core.runnables import RunnableLambda

# Python関数をRunnableに変換
def preprocess(text: str) -> dict:
    return {"cleaned_text": text.strip().lower()}

preprocess_step = RunnableLambda(preprocess)

# チェーンに組み込み可能
chain = preprocess_step | prompt | llm | StrOutputParser()
```

### RunnableParallel

```python
from langchain_core.runnables import RunnableParallel

# 複数の処理を並列実行
parallel_chain = RunnableParallel(
    {
        "summary": summary_chain | StrOutputParser(),
        "keywords": keyword_chain | StrOutputParser(),
        "original": RunnablePassthrough(),
    }
)

# 結果はdictで返される: {"summary": ..., "keywords": ..., "original": ...}
result = parallel_chain.invoke(input_text)
```

### .map() による並列バッチ処理

```python
# リストの各要素に対してchainを並列実行
summarize_chain = prompt | llm | StrOutputParser()
results = summarize_chain.map().invoke(
    [{"chunk": chunk} for chunk in text_chunks]
)
# 各chunkが並列で処理される
```

---

## 2. PromptTemplate

### PromptTemplate（テキスト用）

```python
from langchain_core.prompts import PromptTemplate

# テンプレート文字列からの作成
prompt = PromptTemplate.from_template(
    "あなたは経験豊富なエンジニアです。{technology}について{tone}な説明をしてください。"
)

# フォーマット
formatted = prompt.format(technology="Python", tone="わかりやすい")
```

### ChatPromptTemplate（会話型）

```python
from langchain_core.prompts import ChatPromptTemplate

# メッセージリストからの作成
prompt = ChatPromptTemplate.from_messages([
    ("system", "あなたは{role}です。{task}を行ってください。"),
    ("human", "{user_input}"),
])

# 変数への値の注入
messages = prompt.format_messages(
    role="技術ライター",
    task="コードの説明",
    user_input="このコードを説明してください"
)
```

### 会話履歴の組み込み

```python
from langchain_core.prompts import MessagesPlaceholder

prompt = ChatPromptTemplate.from_messages([
    ("system", "あなたは親切なアシスタントです。"),
    MessagesPlaceholder(variable_name="chat_history"),  # 会話履歴を挿入
    ("human", "{input}"),
])
```

### FewShotPromptTemplate

```python
from langchain_core.prompts.few_shot import FewShotPromptTemplate
from langchain_core.prompts import PromptTemplate

# サンプル例
examples = [
    {"input": "happy", "output": "嬉しい"},
    {"input": "sad", "output": "悲しい"},
    {"input": "angry", "output": "怒っている"},
]

# 例のフォーマット
example_prompt = PromptTemplate(
    input_variables=["input", "output"],
    template="英語: {input}\n日本語: {output}"
)

# Few-Shot プロンプト
few_shot_prompt = FewShotPromptTemplate(
    examples=examples,
    example_prompt=example_prompt,
    suffix="英語: {input}\n日本語:",
    input_variables=["input"]
)
```

### プロンプト設計のベストプラクティス

| 要素 | 説明 | 例 |
|------|------|-----|
| Persona | LLMに演じさせるロール | `あなたはベテランエンジニアです` |
| Context | 背景情報・制約 | `これは医療情報システムです` |
| Instruction | タスクの指示 | `以下の文章を要約してください` |
| Input | 処理対象のデータ | `{text}` |
| Steps | 処理手順の明示 | `1) 〜を確認 2) 〜を実行` |
| Tone | 出力のトーン | `簡潔にわかりやすく` |
| Output Format | 出力形式 | `JSON形式で回答してください` |
| Examples | Few-shot例 | Few-shotプロンプト参照 |

---

## 3. ChatModel / LLM

### ChatOpenAI

```python
from langchain_openai import ChatOpenAI

llm = ChatOpenAI(
    model="gpt-4o-mini",
    temperature=0,          # 決定論的出力（テスト用）
    max_tokens=1000,
    timeout=30,
)
```

### temperature設定の指針

| temperature | 用途 |
|------------|------|
| 0.0 | 分類・抽出・構造化出力（決定論的） |
| 0.3〜0.5 | Q&A・要約（一貫性重視） |
| 0.7〜1.0 | 創作・多様なアイデア生成 |

### LLMキャッシュ（コスト削減）

```python
from langchain_community.cache import InMemoryCache
from langchain.globals import set_llm_cache

# インメモリキャッシュ（開発用）
set_llm_cache(InMemoryCache())

# SQLiteキャッシュ（永続化）
from langchain_community.cache import SQLiteCache
set_llm_cache(SQLiteCache(database_path=".langchain.db"))
```

---

## 4. OutputParser

### StrOutputParser（文字列抽出）

```python
from langchain_core.output_parsers import StrOutputParser

chain = prompt | llm | StrOutputParser()
# AIMessage.content を文字列として返す
```

### JsonOutputParser（JSON出力）

```python
from langchain_core.output_parsers import JsonOutputParser

chain = prompt | llm | JsonOutputParser()
# JSON文字列をdictとして返す
```

### PydanticOutputParser（型安全なJSON出力）

```python
from langchain_core.output_parsers import PydanticOutputParser
from pydantic import BaseModel, Field
from typing import List

class MovieReview(BaseModel):
    title: str = Field(description="映画タイトル")
    rating: float = Field(description="評価（1-5）")
    pros: List[str] = Field(description="良い点のリスト")
    cons: List[str] = Field(description="改善点のリスト")

parser = PydanticOutputParser(pydantic_object=MovieReview)

# フォーマット指示をプロンプトに自動注入
prompt = ChatPromptTemplate.from_template(
    "映画 {movie} のレビューを書いてください。\n{format_instructions}"
)
prompt = prompt.partial(format_instructions=parser.get_format_instructions())

chain = prompt | llm | parser
result: MovieReview = chain.invoke({"movie": "インターステラー"})
```

---

## 5. Chain合成パターン

### シーケンシャルChain

```python
# 基本的な直列Chain
chain = step1 | step2 | step3
```

### 並列Chain（RunnableParallel）

```python
# 同じ入力を複数のChainに並列送信
parallel = RunnableParallel({
    "branch_a": chain_a,
    "branch_b": chain_b,
})
# 入力はbranch_aとbranch_bに同時に送られる
```

### 条件分岐Chain

```python
from langchain_core.runnables import RunnableBranch

branch = RunnableBranch(
    (lambda x: x["topic"] == "technical", technical_chain),
    (lambda x: x["topic"] == "casual", casual_chain),
    default_chain,  # デフォルト
)
```

### フォールバック設定

```python
# メインChain失敗時にフォールバック実行
chain_with_fallback = main_chain.with_fallbacks([fallback_chain])
```

### エラーハンドリング

```python
# リトライ設定
chain_with_retry = chain.with_retry(
    stop_after_attempt=3,
    wait_exponential_jitter=True
)
```

---

## 6. 判断テーブル: ChainかAgentか

| 観点 | Chain（LCEL） | Agent（LangGraph） |
|------|-------------|------------------|
| 処理フロー | 固定された線形・並列フロー | 動的・条件分岐・ループ |
| 状態管理 | 暗黙的（辞書で受け渡し） | 明示的（TypedDict State） |
| ツール呼び出し | 固定されたツールシーケンス | LLMが動的にツール選択 |
| デバッグ容易性 | 比較的簡単 | LangSmith必須 |
| 実装複雑度 | 低い | 高い |
| 適した場面 | バッチ処理・定型ワークフロー | 複雑な推論・自律タスク |

### Chain推奨の場合
- 処理ステップが事前に確定している
- 分岐が少ない（2〜3パターン以内）
- 高スループット・低レイテンシが必要
- テスト・デバッグを簡単にしたい

### Agent推奨の場合
- 中間結果に基づいて次のアクションを動的に決定する
- ループ処理が必要（条件を満たすまで繰り返す）
- 複数のツールを状況に応じて使い分ける
- 複数エージェントの協調が必要

→ エージェント実装の詳細は `LANGGRAPH-AGENTS.md` を参照
