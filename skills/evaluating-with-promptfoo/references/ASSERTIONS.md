# Assertions リファレンス

## アサーション構造

```yaml
assert:
  - type: <assertion-type>
    value: <expected-value>
    threshold: <number>
    weight: <number>        # 重要度（デフォルト1.0）
    provider: <string>      # モデルグレード用
    metric: <string>        # UI集計ラベル
    transform: <string>     # 出力前処理
```

---

## 決定的アサーション

### 文字列マッチング

| タイプ | 説明 | 例 |
|--------|------|-----|
| `equals` / `iequals` | 完全一致（i=大文字小文字無視） | `value: "expected output"` |
| `contains` / `icontains` | 部分文字列を含む | `value: "hello"` |
| `contains-all` / `icontains-all` | すべての文字列を含む | `value: ["hello", "world"]` |
| `contains-any` / `icontains-any` | いずれかの文字列を含む | `value: ["hi", "hello"]` |
| `starts-with` | 指定プレフィックスで始まる | `value: "Hello"` |
| `regex` | 正規表現にマッチ | `value: "\\d{3}-\\d{4}"` |

**否定**: `not-` プレフィックスで反転（例: `not-equals`, `not-contains`, `not-regex`）

### 構造化データ

| タイプ | 説明 |
|--------|------|
| `is-json` | JSON として有効（オプション: JSON Schema バリデーション） |
| `contains-json` | テキスト中に JSON を含む（オプション: スキーマ） |
| `is-xml` / `contains-xml` | XML 検証 |
| `is-sql` / `contains-sql` | SQL 検証 |
| `is-html` / `contains-html` | HTML 検証 |

**JSON Schema 例:**

```yaml
assert:
  - type: is-json
    value:
      type: object
      required: ['name', 'age']
      properties:
        name: { type: string }
        age: { type: number, minimum: 0 }
```

### パフォーマンス

| タイプ | 説明 |
|--------|------|
| `cost` | コスト閾値（threshold 以下で合格） |
| `latency` | レイテンシー ms 閾値 |
| `perplexity` / `perplexity-score` | パープレキシティ（モデルの確信度） |

### テキスト類似度

| タイプ | 説明 | 用途 |
|--------|------|------|
| `levenshtein` | 編集距離 | タイポ検出 |
| `rouge-n` | 再現率指向の類似度 | 要約評価 |
| `bleu` | 精度指向の類似度 | 翻訳評価 |
| `meteor` | 同義語対応の意味類似度 | 翻訳評価 |
| `similar` | 埋め込みコサイン類似度 | 意味的類似性 |

### ツール / 関数呼び出し検証

| タイプ | 説明 |
|--------|------|
| `is-valid-function-call` | スキーマ準拠チェック |
| `is-valid-openai-tools-call` | OpenAI Tools コール検証 |
| `tool-call-f1` | 実際 vs 期待の F1 スコア |

### Trajectory（エージェントテスト）

エージェントが複数ステップで実行される際の軌跡を検証する。

| タイプ | 説明 |
|--------|------|
| `trajectory:tool-used` | 特定ツールが呼び出されたか確認 |
| `trajectory:tool-args-match` | ツール引数が期待値と一致するか |
| `trajectory:tool-sequence` | 実行順序の検証 |
| `trajectory:step-count` | ステップタイプ別カウント |

### その他の決定的アサーション

| タイプ | 説明 |
|--------|------|
| `word-count` | 単語数が指定範囲内か |
| `finish-reason` | モデルの停止理由（stop, length 等） |
| `is-refusal` | 拒否パターンの検出 |
| `webhook` | 外部 HTTP エンドポイントで検証 |

---

## モデルグレードアサーション

LLM を審査員として使用し、定性的評価を行う。

### 出力ベース

| タイプ | 説明 | 用途 |
|--------|------|------|
| `llm-rubric` | 汎用 LLM グレーディング | カスタム基準で評価 |
| `factuality` | 事実準拠チェック | ハルシネーション検出 |
| `answer-relevance` | クエリ整合性 | 質問と回答の関連性 |
| `g-eval` | Chain-of-Thought 評価 | 詳細な推論ベース評価 |
| `search-rubric` | Web 検索 + ルーブリック | 最新情報との照合 |
| `model-graded-closedqa` | クローズド QA 評価 | 特定質問の正答率 |
| `select-best` | 出力比較・最良選択 | A/B テスト |
| `classifier` | HuggingFace 分類モデル | カテゴリ分類 |
| `moderation` | OpenAI Moderation API | コンテンツモデレーション |

### コンテキストベース（RAG）

RAG パイプラインの品質評価に特化したアサーション。

| タイプ | 説明 | 用途 |
|--------|------|------|
| `context-faithfulness` / `context-adherence` | 出力がコンテキストに裏付けられるか | ハルシネーション防止 |
| `context-recall` | 正解がコンテキストに含まれるか | 検索品質 |
| `context-relevance` | コンテキストがクエリに関連するか | 検索精度 |

### Trajectory（LLM ジャッジ）

| タイプ | 説明 |
|--------|------|
| `trajectory:goal-success` | LLM ジャッジによる目標達成評価 |

### グレーダーオーバーライド

```yaml
# CLI レベル
promptfoo eval --grader openai:gpt-4o-mini

# テストレベル（全アサーションに適用）
defaultTest:
  options:
    provider: openai:gpt-4o-mini

# アサーションレベル（個別オーバーライド）
assert:
  - type: llm-rubric
    value: "回答は簡潔で正確か"
    provider: openai:gpt-4o-mini
```

### カスタムルーブリックプロンプト

```yaml
defaultTest:
  options:
    rubricPrompt: |
      [{"role": "system", "content": "Grade output: {{output}} against rubric: {{rubric}}"}]
```

---

## JavaScript アサーション

カスタムロジックで柔軟な検証が可能。

```yaml
assert:
  - type: javascript
    value: |
      if (output.includes('expected')) {
        return { pass: true, score: 1.0, reason: 'Contains expected text' };
      }
      return { pass: false, score: 0, reason: 'Missing expected text' };
```

**利用可能なコンテキスト変数:**

| 変数 | 説明 |
|------|------|
| `output` | モデルの出力テキスト |
| `context.vars` | テスト変数 |
| `context.prompt` | 送信したプロンプト |
| `context.test` | テスト定義オブジェクト |
| `context.provider` | プロバイダー情報 |
| `context.logProbs` | ログ確率（対応モデルのみ） |
| `context.trace` | エージェント実行トレース |

**外部ファイル参照:**

```yaml
assert:
  - type: javascript
    value: file://path/to/assert.js:functionName
```

---

## Python アサーション

```yaml
assert:
  - type: python
    value: |
      result = 'expected' in output
      return result
```

**戻り値の形式:**

```python
# ブール値（シンプル）
return True

# 詳細オブジェクト
return {
    "pass": True,
    "score": 0.85,
    "reason": "Contains required keywords"
}
```

---

## アサーションセット

複数アサーションを束ねて部分合格をサポート。

```yaml
assert:
  - type: assert-set
    threshold: 0.5   # 50% 以上で合格
    assert:
      - type: contains
        value: hello
      - type: contains
        value: world
      - type: regex
        value: "\\d+"
```

---

## RAG 評価パターン

### 動的コンテキスト抽出

```yaml
assert:
  - type: context-faithfulness
    contextTransform: 'JSON.parse(output).sources.join(". ")'
    threshold: 0.8
```

### 推奨構成（多言語 RAG）

多言語環境では文字列メトリクスより LLM ベースを優先:

```yaml
assert:
  # ✅ LLM ベース（多言語対応）
  - type: context-relevance
    threshold: 0.8
  - type: context-faithfulness
    threshold: 0.8
  - type: llm-rubric
    value: "回答は日本語で提供されているか"
  # ❌ 不適切（文字列マッチングは多言語で精度低下）
  # - type: context-recall
  # - type: rouge-n
```

### スコア閾値の目安

| メトリクス | 本番 | 開発 |
|---------|------|------|
| `context-faithfulness` | ≥ 0.85 | ≥ 0.70 |
| `context-relevance` | ≥ 0.80 | ≥ 0.65 |
| `answer-relevance` | ≥ 0.80 | ≥ 0.65 |
| `similar` | ≥ 0.85 | ≥ 0.75 |

---

## アサーション設計のベストプラクティス

1. **決定的 → モデルグレード の順で追加**: まず `contains` / `is-json` 等で基本を固め、定性評価が必要な場合にのみ LLM グレードを追加
2. **`weight` で優先度を調整**: クリティカルなアサーションは `weight: 2.0` 以上に設定
3. **`metric` でグループ化**: 同一指標のアサーションを `metric: "safety"` 等でまとめて UI で集計
4. **`transform` で前処理**: JSON レスポンスの場合は `transform: JSON.parse(output).answer` でフィールド抽出してからアサート
