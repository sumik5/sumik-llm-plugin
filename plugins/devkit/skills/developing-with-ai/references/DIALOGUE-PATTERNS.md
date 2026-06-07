# LLM対話パターン集

LLMとの対話を設計言語として捉えた8つの対話パターン。各パターンは「繰り返し現れる状況」に対する「再利用可能な対話フレーム」である。

---

## パターン一覧

| # | パターン名 | 主な目的 | 典型的な状況 |
|---|-----------|---------|------------|
| 1 | Socratic Questioning | 曖昧な要件を明確化する | 要求が漠然としている、何を求めているか自分でも不明 |
| 2 | Guided Exploration | 複雑なテーマを構造化する | 大きすぎる問題、どこから手をつけるか不明 |
| 3 | Reverse Specification | 未文書化コードの意図を抽出する | レガシーコード、ドキュメントなし |
| 4 | Mirror Model | 複数の選択肢を比較・判断する | アーキテクチャ選択、技術選定で迷っている |
| 5 | Clarification by Counterexample | 提案の堅牢性を検証する | 「良さそうな答え」に疑念がある |
| 6 | Test-Driven Prompting (TDP) | プロンプトの品質を安定させる | 同じプロンプトで結果がバラつく |
| 7 | Visual Reformulation | テキスト提案の曖昧さを解消する | 長い回答に不整合・抜け漏れの疑い |
| 8 | Systemic Care | 問題の根本原因を探る | 繰り返す問題、パッチで解決しない |

---

## Pattern 1 — Socratic Questioning: 問い直して理解する

| 項目 | 内容 |
|------|------|
| **Context** | 要求が曖昧・不完全・不正確。プロジェクト開始時、探索フェーズ、学際的な議論で頻出 |
| **Problem** | 曖昧なプロンプトが汎用的・的外れな回答を生む。LLMが暗黙の前提で補完し、本来の意図とズレる |
| **Solution** | ソクラテス式問答を採用する。答えを求める前に、標的を絞った進行的な問いで要求の輪郭を探る |
| **Consequences** | 元の意図が明確化される / 対話を通じてプロンプトが精緻化される / LLMとの共同推論が始まる / 方向ミスのリスクが下がる |

### 実践例

初期: `"アラートスクリプトを作成して"` → 汎用的すぎて使えない

改善: `"CSVの請求エラー検出スクリプトです。監視できるエラーの種類を提案してください"`
→ LLMが「金額不整合 / 無効な日付 / 参照欠損 / 重複」を提案 → 正確な要求に再定式化

### Variants

| バリアント | プロンプト例 |
|-----------|------------|
| ビジネス要件の枠組み定め | "やりたいことを明確にする5つの質問をしてください" |
| ステークホルダー支援 | "制約に基づいて選択肢を探索する手伝いをして" |

### Prompt to Remember
> "Help me clarify my request by asking me questions. Don't propose a solution yet."

---

## Pattern 2 — Guided Exploration: 分解して前進する

| 項目 | 内容 |
|------|------|
| **Context** | 複雑・新規・不明確なテーマに取り組む必要がある。タスクが広大または形のない印象 |
| **Problem** | 初期プロンプトへの回答が広すぎ・表面的すぎる。認知過負荷、散漫、時間の無駄が生じる |
| **Solution** | LLMを「構造化ファシリテーター」として使う。段階・カテゴリ・分析レベルに分解した「領域マップ」を求める |
| **Consequences** | 知覚複雑性の低減 / タスクの優先順位付け向上 / 反復的・インクリメンタルなアプローチ / 当初考慮されなかった観点の発見 |

### 実践例

初期: `"このモジュールをどう設計すべき？"` → 長く密で使いにくい回答

改善: `"このモジュール構築の機能・技術的分解を提案してください"`
→ LLMがデータソース / バリデーションルール / 処理ステータス / 通知 / エラー / 会計エクスポートに分解
→ バックログ・MVPプラン・PO対話の基盤として活用

### Variants

| バリアント | アプローチ |
|-----------|----------|
| Funnel探索 | 全体計画 → 1ステップにズームイン → サブステップ詳細化 |
| Multi-angle探索 | 役割別（技術・業務・UX）または優先度別（コスト・影響・リスク）に分解 |
| Critical探索 | 最もリスクの高いステップやPoCが必要な箇所を抽出 |

### Prompt to Remember
> "I'm working on [topic]. Propose a breakdown into concrete, progressive steps to help me structure my approach."

---

## Pattern 3 — Reverse Specification: コードから意図を浮かび上がらせる

| 項目 | 内容 |
|------|------|
| **Context** | 既存コードを理解する必要がある。古い・ドキュメントなし・他人が書いた。ユーザーストーリーなし・明確な意図なし |
| **Problem** | コードは「どう」を示すが「なぜ」は示さない。元の意図・業務制約・暗黙の前提を推測するしかない |
| **Solution** | LLMを「遡及的意図検出器」として使う。コード断片を与え、暗黙の機能意図・業務ルール・想定ユーザーストーリーを抽出させる |
| **Consequences** | 未知コードの分析時間短縮 / 遡及的ドキュメント生成 / コードレビュー・引き継ぎ・リファクタリング支援 |

### 実践例

800行のPHPモジュール（テスト・ドキュメントなし）を引き継いだチーム。
プロンプト: `"このブロックはどんな業務ルールを実装しているように見えますか？"`
→ LLMが重複検出 / VAT制御 / 条件付き丸め / 未記載の特殊ケースを検出
→ 意図の再構築 → ユースケース文書化 → リファクタリング計画策定

### Variants

| バリアント | プロンプト例 |
|-----------|------------|
| ユーザーストーリー再構築 | "このコードが製品機能に対応するとしたら、どんなユーザーストーリーが推測できますか？" |
| 暗黙の前提推定 | "このコードはデータ・実行コンテキスト・アクセス権についてどんな前提を置いているように見えますか？" |

### Prompt to Remember
> "Here's an undocumented function. Can you explain what it does, why, and what assumptions it seems to make?"

---

## Pattern 4 — Mirror Model: 選択肢を比較して決断を明確にする

| 項目 | 内容 |
|------|------|
| **Context** | 複数の解決策の間で迷っている。アーキテクチャ・アルゴリズム・コーディングスタイル・ツールの選択 |
| **Problem** | LLMはデフォルトで単一解を返す。代替案を比較しないと、最初に「良さそう」な提案に固執してしまう |
| **Solution** | LLMを「比較鏡」として使う。複数バリアントを生成させ、定義した基準（可読性・パフォーマンス・保守性など）で比較させる |
| **Consequences** | 批判的分析の促進 / 意思決定基準の明確化 / 集合的意思決定の支援 / 確証バイアスの低減 / 決定文書化の基盤形成 |

### 実践例

```
決済システム再設計でKafka vs REST RESTアーキテクチャを選択中

プロンプト:
"1秒あたり100トランザクションを処理する高可用性システムに対して、
この2つの選択肢を比較してください。トレードオフは何ですか？"

→ LLMの比較:
  - Kafka: 障害耐性が高いがモニタリングが困難
  - REST: テストが容易だが負荷スパイクに弱い

→ 「なんとなくこうしてきた」ではなく、論拠のある決断が可能に
```

### Variants

| バリアント | 用途 |
|-----------|------|
| Style Mirror | 命令型 vs 関数型、オブジェクト指向 vs 宣言型の比較 |
| Paradigm Mirror | ポーリング vs イベント駆動、同期 vs 非同期の比較 |
| Tool Mirror | フロントエンドフレームワーク、DBエンジン、テストライブラリの比較 |

### Prompt to Remember
> "Propose several alternatives for this need, then compare them according to these criteria: [X, Y, Z]."

---

## Pattern 5 — Clarification by Counterexample: 提案の限界を探る

| 項目 | 内容 |
|------|------|
| **Context** | LLMが満足のいく回答（コード・解決策・推奨）を出した。しかし微妙な疑念が残る |
| **Problem** | LLMは「理想的・典型的」な解を生成し、エッジケースや失敗モードを隠しがち。検証なしで信頼するとリスクがある |
| **Solution** | 否定によって回答を問い直す。解が失敗する状況・非効率になるケース・予期せぬ効果をもたらす入力を求める |
| **Consequences** | エッジケースの早期発見 / 解の堅牢性向上 / 批判的思考の醸成 / 本番での副作用・サプライズ低減 |

### 実践例

```
DijkstraアルゴリズムのJavaScript実装を依頼、一見正しい回答が返ってきた

フォローアッププロンプト: "グラフに負のサイクルが含まれていたら？"

→ LLM回答:
  "Dijkstraはその場合には適していません。
  負の重みを処理できるBellman–Fordアルゴリズムが必要です"

→ 見えなかった前提を可視化 → 生成セッションが学習の瞬間に変わる
```

### Variants

| バリアント | プロンプト例 |
|-----------|------------|
| Boundary Test | "配列が空だったら？値がnullだったら？" |
| Stress Test | "10,000ユーザーが同時アクセスしたら？" |
| Business Counter-Rule | "このルールを無効化するビジネス状況は？" |

### Prompt to Remember
> "Give a case that would make this solution fail. What does that reveal about its limits?"

---

## Pattern 6 — Test-Driven Prompting (TDP): 期待値を先に定義する

| 項目 | 内容 |
|------|------|
| **Context** | 再利用・共有・ツール統合したいプロンプトを設計している。しかしLLMの出力がばらつく |
| **Problem** | プロンプトが直感的に書かれ、期待値が明示されていない。後から修正するのではなく、最初から制御したい |
| **Solution** | TDD（テスト駆動開発）にインスパイアされたアプローチ。プロンプトを書く前に、回答が満たすべき期待値を定義する |
| **Consequences** | プロンプトが精密・安定・再利用可能になる / チーム共有・ツール統合が容易 / プロンプトがエンジニアリングアーティファクトとして扱われる |

### 期待値定義の例

```
- 回答は3文以内に収める
- 共感的かつプロフェッショナルなトーンを使う
- 法的免責事項には一切言及しない
- 顧客の要求を言い換えることから始める
```

### 実践例

```
カスタマーチケット対応アシスタントの構築

初期プロンプト: "顧客に共感的な返信を書いて"
→ 長すぎ・漠然・法的リスクあり

改善アプローチ（先に期待値を定義）:
  ✓ 最大2〜3文
  ✓ 法的免責事項なし
  ✓ 確約せずに安心させる
  ✓ 顧客のレベルに言語を合わせる

→ 期待値を満たすまでプロンプトを調整 → バージョン管理・共有・ツール統合
```

### Variants

| バリアント | 説明 |
|-----------|------|
| Visual TDP | 期待する出力例を作成し「このように出力して」と依頼 |
| Collaborative TDP | PO・UX・サポート・技術で共同で期待値を定義 |
| Embedded TDP | テスト基準をプロンプト内部に直接埋め込む |

### Prompt to Remember
> "Here's an example of the expected response. Can you formulate a prompt that produces this kind of output consistently?"

---

## Pattern 7 — Visual Reformulation: 表現で曖昧さを解消する

| 項目 | 内容 |
|------|------|
| **Context** | LLMがテキストで解を提示している。アーキテクチャ・アルゴリズム・プロセス等。回答は興味深いが密・曖昧 |
| **Problem** | 自然言語は「影の領域」を隠す。論理的ショートカット・未定義インターフェース・暗黙のステップ。視覚化なしでは構造的に検証できない |
| **Solution** | LLMのテキスト提案を視覚図（コンポーネント図・フロー・表・マインドマップ等）に変換する。その図を自然言語で再定式化してLLMに再提示し、検証・批判・充実化を求める |
| **Consequences** | 論理的不整合の早期発見 / チームによる集合的検証の容易化 / ソリューションのより深い人間的理解 / モデリング能力の向上 |

### 対話ループ

```
1. 初期リクエスト → LLMのテキスト回答
2. 手動で視覚化（draw.io / 表 / マインドマップ）
3. 理解内容を構造化テキストで再定式化
4. LLMへ再提示:
   "これは私の理解です。一貫していますか？不足しているものは？"
```

### 実践例

```
マルチチャネル通知システムのアーキテクチャ提案を受けたチーム

開発者がコンポーネント図を作成:
  - アラートマネージャー
  - 優先順位付けモジュール
  - キュー
  - webhook/メール送信
  - キャッシュ用Redis

再定式化プロンプト:
  "アラートがマネージャーに到達し、分類・保存・送信されると理解しました。
  Redisはキャッシュです。正しいですか？追加すべきものは？"

→ LLM回答: "障害処理機構がありません。ログ付きリトライキューを追加すべきです"
```

### Variants

| バリアント | 説明 |
|-----------|------|
| 双方向テーブル | 役割×責任、モジュール×依存関係 |
| 軽量UML | クラス図・シーケンス図・アクティビティ図 |
| 手描きスケッチ + 書き起こし | 紙に描いてLLMに言語化させる |

### Prompt to Remember
> "Here's a textual reformulation of my diagram. Can you check whether it's consistent with your initial proposal and suggest improvements?"

---

## Pattern 8 — Systemic Care: 問題の根本原因を調査する

| 項目 | 内容 |
|------|------|
| **Context** | プロジェクトやチームに問題が繰り返し発生している。繰り返すバグ・潜在的なモチベーション低下・蓄積された遅延・対人摩擦 |
| **Problem** | 反射的に「素早いローカルな修正」を求めてしまう。しかしその表面的症状だけ対処すると、複合的・絡み合った根本原因を見逃す |
| **Solution** | LLMを「システム的調査パートナー」として活用する。直接的な解決策を求めず、因果関係の掘り下げを共に行う |
| **Consequences** | 行動前の共有診断が可能に / 時期尚早・方向違いのアクションを防止 / 集合知性と内省が促進される / 現実により根ざした解決策が生まれる |

### Nine Whys技法

「なぜこれはあなたにとって重要ですか？」を9回繰り返すことで意味の深さを探る手法。LLMにファシリテーターを担わせることで、暗黙の矛盾や人間的緊張を浮かび上がらせる。

プロンプト例: `"Can you help me simulate a Nine Whys session on this problem: [describe situation]?"`

### 実践例

初期: `"チームを再度やる気にさせるには？"` → 汎用的な回答のみ

改善: `"モチベーション低下の可能な原因を技術・人間・組織の側面から探ってください"`
→ LLMが技術的負債による不安 / 品質基準の曖昧さ / 承認の欠如を提案
→ チームが原因を掘り下げ、品質ルール明確化・承認リチュアル新設・段階的リファクタリングの3アクションを特定

### Variants

| バリアント | 説明 |
|-----------|------|
| 原因ツリー | 原因/症状の分岐図 |
| Multi-Perspective | 開発者・PO・マネージャーの視点から分析させる |
| 相反する仮説 | 同じ症状に対して異なる説明を3つ生成させる |

### Prompt to Remember
> "Here's a problem that keeps coming up. Can you help me explore its root causes from several angles without immediately proposing a solution?"

---

## パターン選択フローチャート

```
[状況の診断]
     |
     ├─→ 要求が漠然としている・何を求めているか不明
     |        → Pattern 1: Socratic Questioning
     |
     ├─→ 問題が複雑すぎて手のつけどころがわからない
     |        → Pattern 2: Guided Exploration
     |
     ├─→ ドキュメントのないコードを理解する必要がある
     |        → Pattern 3: Reverse Specification
     |
     ├─→ 複数の選択肢の間で迷っている
     |        → Pattern 4: Mirror Model
     |
     ├─→ 「良さそうな回答」に疑念がある・堅牢性を確認したい
     |        → Pattern 5: Clarification by Counterexample
     |
     ├─→ 再利用可能なプロンプトを設計したい・出力が安定しない
     |        → Pattern 6: Test-Driven Prompting
     |
     ├─→ テキスト回答が長すぎ・抜け漏れが疑われる
     |        → Pattern 7: Visual Reformulation
     |
     └─→ 問題が繰り返す・パッチを当てても解決しない
              → Pattern 8: Systemic Care
```

### 組み合わせパターン

| 組み合わせ | 説明 |
|-----------|------|
| 1 → 2 | 要求明確化の後に構造化探索へ移行 |
| 5 → 6 | 堅牢性検証で判明した期待値をTDPに統合 |
| 3 → 4 | コードから意図を抽出後、代替設計の比較検討 |
| 7 → 5 | 視覚化で発見した曖昧さを反例で検証 |
| 8 → 2 | 根本原因特定後、解決策の段階的探索 |

---

## Prompts to Remember（一覧）

| パターン | プロンプト |
|---------|-----------|
| 1. Socratic Questioning | "Help me clarify my request by asking me questions. Don't propose a solution yet." |
| 2. Guided Exploration | "I'm working on [topic]. Propose a breakdown into concrete, progressive steps to help me structure my approach." |
| 3. Reverse Specification | "Here's an undocumented function. Can you explain what it does, why, and what assumptions it seems to make?" |
| 4. Mirror Model | "Propose several alternatives for this need, then compare them according to these criteria: [X, Y, Z]." |
| 5. Counterexample | "Give a case that would make this solution fail. What does that reveal about its limits?" |
| 6. Test-Driven Prompting | "Here's an example of the expected response. Can you formulate a prompt that produces this kind of output consistently?" |
| 7. Visual Reformulation | "Here's a textual reformulation of my diagram. Can you check whether it's consistent with your initial proposal and suggest improvements?" |
| 8. Systemic Care | "Here's a problem that keeps coming up. Can you help me explore its root causes from several angles without immediately proposing a solution?" |
