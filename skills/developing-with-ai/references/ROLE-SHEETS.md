# ロールシート & TDP詳細

役割別LLM活用シートおよびTest-Driven Prompting詳細方法論。

---

## 1. Test-Driven Prompting (TDP) 詳細

### 目的

意図と成功基準を先に定義してからプロンプトを書くことで、LLMとのインタラクションを厳密かつ検証可能な形に構造化する。

### Before vs With TDP

| Before | With TDP |
|--------|----------|
| アドホックに質問する | 先に意図と成功基準を定義する |
| 失敗後にプロンプトを修正する | テストケースを先読みで準備する |
| 都度応答に反応する | 明示的な評価・調整ループを使う |
| 共有・発展しにくい | テスト可能・移転可能・文書化可能な成果物を生む |

### Anatomy（5ステップ）

| ステップ | 内容 |
|---------|------|
| **Intent** | 何を生成・探索・確認したいか |
| **Success Criteria** | 答えを使えると判断する条件 |
| **Initial Prompt** | 最初の構造化プロンプト |
| **Test Cases** | 入出力データ・期待フォーマット・反例 |
| **Adjustment Loop** | 観察したギャップに基づきプロンプトを改訂 |

### Example

```
Intent: Generate a basic Node.js REST API with Express

Success criteria:
  - Must include at least two routes
  - Use express.json()
  - Include a clean folder structure

Initial prompt:
  "Create an Express REST API with two routes (GET/POST),
   using express.json() and a clean structure."

Test cases:
  - Presence of index.js with clear routes
  - Usage of express.json()
  - MVC structure → needs to be specified

Adjustment loop:
  → Add to prompt: "Organize the code following a simple MVC model."
```

### Tips

- テスト→プロンプト順で作成する（TDDと同じ思想）
- TDPをバージョン管理して再利用・チームと共有する
- 同じIntentで複数プロンプトを比較し、Success Criteriaを固定する
- Counter-example・Mirrorなどのパターンをテスト生成に活用する
- 後日「コールドレビュー」して盲点を確認する

### Associated Postures

| Posture | TDPでの役割 |
|---------|-----------|
| Prompt Designer | 意図を精確に定式化する |
| Critical Explorer | 実際のケースで出力品質を検証する |
| Augmented Editor | 文言を調整してモデルを誘導する |
| Rigorous Curator | テスト済み有効プロンプトを収集・共有する |

### Watch-outs

- TDPは完璧な答えを保証しない（反復・明確・共有可能なアプローチを提供する）
- 単純なリクエストを過剰形式化しない（コンテキストに応じた労力配分）
- 逆に曖昧すぎるプロンプトもランダムに解釈される

---

## 2. ツールシートテンプレート

### Sheet 1 — LLMインタラクションパターン記録

| 要素 | 説明 |
|------|------|
| パターン名 | 短く印象的なタイトル |
| 使用コンテキスト | いつ・なぜ活性化するか |
| 解決する問題 | どの繰り返す課題に対処するか |
| 典型的なプロンプト形式 | 表現方法の汎用例 |
| 推奨アプローチ | ステップまたはインタラクション順序 |
| ポジティブな結果 | このパターンが可能にすること・強化すること |
| バリアント・適応 | コンテキスト応じた調整例（個人・チーム・言語等） |
| 注意点 | リスク・限界・よくある落とし穴 |
| 実世界の例 | プロジェクト・状況・具体的エピソード |
| タグ | 関連テーマ（探索・リファクタ・テスト・ドキュメント・セキュリティ等） |

### Sheet 2 — プロンプトデザイン

| 要素 | 内容 |
|------|------|
| プロンプトのタイトル・目標 | インタラクションへの期待 |
| LLMに提供するコンテキスト | 言語・FW・ビジネス制約・ユーザーレベル |
| タスク依頼 | 求めるアクション・アウトプット |
| 具体的な意図 | なぜこのプロンプトが重要か・目的 |
| 期待する応答形式 | コード・テキスト・表・サマリー・図等 |
| 期待テスト（任意） | 有効な出力例・成功基準 → TDP参照 |
| 試すバリアント | 言い換え・追加詳細の可能性 |
| 得られた教訓 | うまくいったこと / うまくいかなかったこと |

### Sheet 3 — Test-Driven Prompting (TDP)

| 要素 | 内容 |
|------|------|
| プロンプト名・目的 | |
| LLMへの入力 | ソースコード・ビジネスコンテキスト・サンプルデータ等 |
| 期待する出力タイプ1 | 理想的な応答の例 |
| 期待する出力タイプ2（バリアント） | |
| 形式制約 | 長さ・トーン・フォーマット・スタイル・禁止コンテンツ |
| 失敗基準 | 応答が使用不可能になる条件 |
| 関連プロンプト | 上記テストに沿って構築する |

### Sheet 4 — LLMインタラクションレトロスペクティブ

| 要素 | 詳細 |
|------|------|
| 日付・コンテキスト | プロジェクト・フェーズ・目標 |
| 使用したプロンプト | |
| 得られた応答 | サマリーまたは抜粋 |
| 満足度（⭐/⭐⭐/⭐⭐⭐） | 関連性・有用性の評価 |
| うまくいったこと | |
| 問題があったこと | 幻覚・混乱・バイアス等 |
| 得られた教訓 | |
| 関連パターン（あれば） | |

---

## 3. 拡張POシート（Augmented Product Owner）

### Points of Attention

- **製品意図を委任しない**: LLMはユーザーも戦略も知らない
- **提案は必ずレビューする**: 良く書かれた出力でも不正確な場合がある
- **機密データを入力しない**: 内部優先度・機密ロードマップ・クライアント名等
- **有用なプロンプトをチームと共有する**: 共通リポジトリを構築する

### 推奨スタンスマッピング

| 状況 | 推奨パターン | POスタンス |
|------|------------|-----------|
| 曖昧・不明確なニーズ | Socratic Questioning | 明確化者 |
| 複数選択肢からの決定 | Mirror Model | 批判的意思決定者 |
| ストーリーの起草・言い換え | Reverse Specification | ライター・探索者 |
| 受け入れ基準の定義 | Test-Driven Prompt | 品質ガーディアン |
| 決定の形式化 | Prompt Journal | 説明責任保持者 |

### サンプルプロンプト

| ユースケース | プロンプト例 |
|------------|-----------|
| ワーディング探索 | "Here's a feature I want to describe. Can you propose three different ways of writing its user story, using user-centered approaches?" |
| 受け入れ基準定義 | "Here's a story and its objective. Suggest three measurable acceptance criteria inspired by the Gherkin format." |
| ビジネス検証 | "Here's a proposed feature. What questions should we ask to ensure its real business value?" |

---

## 4. 拡張デベロッパーシート（Augmented Developer）

### Augmented Professional Gestures

| Before | With LLM |
|--------|----------|
| ドキュメントを読む | コードを起点にターゲットを絞った質問をする |
| 機能を実装する | アプローチを共同設計し、コードについて対話する |
| コードをリファクタする | バリアントを要求し、堅牢性をテストする |
| テストを書く | 説明からテストケースを生成する |
| ソリューションを説明する | 簡略化・構造化バージョンを生成する |
| 技術調査をする | インタラクティブなステップでトピックを探索する |

### Activatable Postures

| Posture | 説明 |
|---------|------|
| Prompt Designer | 技術的意図を構造的に定式化する |
| Solution Editor | LLMが提案したコードを整形・改善する |
| Technical Explorer | 代替案を問い、反例を引き出す |
| Reasoned Critic | 論理的欠陥・近似値・バイアスを探す |
| Knowledge Curator | 有効なプロンプトを保存・共有する |
| Reflective Documentalist | 自己・チーム・将来のための有用なトレースを生成する |

### 状況マッピング

| 状況 | プロンプトタイプ | 活性化パターン |
|------|---------------|-------------|
| レガシーコード理解 | "What does this function do? What can I infer from it?" | Reverse Specification, Clarification |
| ターゲットテスト作成 | "Write a unit test for this edge case." | Test-Driven Prompt, Counter-Example |
| アーキテクチャ選択 | "Compare three patterns suited to this use case." | Mirror Model, Guided Exploration |
| 複雑な関数クリーンアップ | "Suggest a clearer, tested version." | Guided Refactor, Style Mirror |
| 推論の説明 | "Rephrase this solution for a non-technical profile." | Visual Reformulation, Transmission |
| 技術ドキュメント作成 | "Generate a clear summary of this component." | Targeted Summary, Curator |

### Points of Attention

- **LLMは正しそうでも信頼できない場合がある**: 採用前に必ずテストする
- **速度向上は理解不足を補えない**: 認知的怠惰に注意する
- **過剰委任は技術的直感を弱める**: 盲目的委任より対話を優先する

---

## 5. 拡張アジャイルコーチシート（Augmented Agile Coach）

### Augmented Professional Gestures

| Before | With LLM |
|--------|----------|
| ワークショップを準備する | 代替フォーマット・指示を生成する |
| 力強い質問を考える | 代替表現をテストし、「なぜ」を探索する |
| ブロックされたチームをサポート | 仮説・可能な原因のマップを共同作成する |
| リチュアルを設計する | ハイブリッドリチュアルからインスピレーションを得、アイスブレーカーを生成する |
| チームダイナミクスを観察する | シナリオや視点をシミュレートする |
| 省察支援をする | LLMを対話的ミラーとして使う |

### Activatable Postures

| Posture | 説明 |
|---------|------|
| Augmented Facilitator | ワークショップフォーマットを生成・適応・構造化する |
| Strategic Questioner | 力強い質問を実験・洗練・再定式化する |
| Situation Curator | 実際のケース・チームシナリオ・ジレンマを収集する |
| Systemic Modeler | 根本原因と不可視のインタラクションを探索する |
| Individual Reflection Coach | 自己コーチング育成のためLLMをミラーとして活用する |
| Alternative Stimulator | 新しい視点を開き、視点転換を可能にする |

### 状況マッピング

| 状況 | プロンプトタイプ | 活性化パターン |
|------|---------------|-------------|
| レトロスペクティブ準備 | "Suggest three retrospective formats for a remote team." | Guided Exploration, Goal Reformulation |
| 潜在的コンフリクト対応 | "What kinds of tensions can emerge in this context?" | Root-Cause Tree, The 'Nine Whys' |
| ジュニアSMサポート | "What could they try with a team that bypasses the rules?" | Counter-Example, Posture Mirror |
| ワークショップ活動作成 | "Propose an icebreaker for an introverted team." | Creative Divergence, Co-Design |
| 省察促進 | "What questions could I ask a demotivated developer?" | Socratic Questioning, Contextual Reformulation |
| 介入のドキュメント化 | "Write a concise debrief of this coaching session." | Targeted Summary, Practice Curator |

### Points of Attention

- **LLMは感情も非言語キューも知覚できない**: ツールであり関係的存在ではない
- **創発的・曖昧・生きた何かを正規化・合理化することがある**
- **存在感・傾聴・人間的判断は決して代替できない**

---

## 6. 拡張マネージャーシート（Augmented Manager 3.0）

### Augmented Professional Gestures

| Before | With LLM |
|--------|----------|
| 1on1を準備する | 対話シナリオをシミュレートし、表現をテストする |
| 複雑な意思決定を明確にする | 基準を探索し、選択肢を比較する |
| ミーティングを運営する | アジェンダ構造・ファシリテーション順序を生成する |
| 緊張から距離を置く | 可能な原因をマップし、主要課題を再定式化する |
| フィードバックを与える | 表現を磨き、異なるトーンを探索する |
| ビジョン・意図を共有する | LLMでアイデアを合成・構造化する |

### Activatable Postures

| Posture | 説明 |
|---------|------|
| Strategic Clarifier | 意図を再定式化し、思考を構造化する |
| Tension Scout | デリケートな状況の原因と代替案を探索する |
| Meeting Facilitator | コンテキストに適したアニメーション順序を準備する |
| Intention Designer | アイデアを伝達可能・インスピレーショナルな形に形成する |
| Intentional Feedback-Giver | トーン・言葉・タイミングをニュアンスと精密さで選択する |
| Reflective Sparring Partner | LLMをミラーとして自己ポジショニングを改善する |

### 状況マッピング

| 状況 | プロンプトタイプ | 活性化パターン |
|------|---------------|-------------|
| 難しいフィードバック準備 | "Help me phrase feedback on this observed behavior." | Socratic Questioning, Impact-Based Reformulation |
| 曖昧な役割の明確化 | "Here's the context. Suggest a clear version of this role." | Inverted Specification, Structured Synthesis |
| チームメンバー間のコンフリクト | "What possible explanations could there be for this tension?" | Root-Cause Tree, Perception Mirror |
| 戦略的1on1準備 | "What powerful questions could I ask this team member?" | Guided Exploration, Socratic Curiosity |
| ビジョンのコミュニケーション | "Propose several ways to phrase this managerial intention." | Co-Design, Inspiring Reformulation |

### Points of Attention

- **LLMは感情も現場知識も持たない**: 照らすが決定はしない
- **社会的には丁寧でも文化的に不適切な提案をすることがある**
- **モデルへの過度な依存はマネジメントの説明責任を弱める**
