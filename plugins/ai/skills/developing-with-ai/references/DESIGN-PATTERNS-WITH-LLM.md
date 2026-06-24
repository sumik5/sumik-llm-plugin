# デザインパターン × LLM活用リファレンス

LLMを用いてGoFパターン・アーキテクチャパターン・新興パターンを実践的に探索するためのリファレンス。パターンを「答え」ではなく「対話の足場」として使う手法を整理する。

---

## GoFパターン拡張プロンプト

各パターンにLLMを活用するための「Augmented Prompt（強化プロンプト）」、LLMが提供できる価値、注意点をまとめる。

### 生成系パターン

| パターン | 目的 | Augmented Prompt | LLM Contributions | Caution |
|---------|------|-----------------|-------------------|---------|
| **Factory** | 環境別のオブジェクト生成を委譲 | `"I have several implementations of a service depending on environment (prod, test, mock). Suggest a design that's testable and extensible."` | Factory / Service Locator提案、DI導入を示唆、Singleton過用を警告 | テスタビリティへの影響を明示しないと過複雑になる |
| **Builder** | 複雑なオブジェクトを段階的に構築 | `"I have an object with many optional parameters. How can I build it without an unreadable constructor?"` | Fluent Builder提案、設定ミスを防ぐ構造化、immutableバージョン提示 | クラス爆発（class explosion）に注意 |

### 構造系パターン

| パターン | 目的 | Augmented Prompt | LLM Contributions | Caution |
|---------|------|-----------------|-------------------|---------|
| **Adapter** | 既存実装を期待するインターフェースに適合 | `"I have an external API with different names from mine. How do I integrate it without touching client code?"` | シンプルなアダプターIF提案、変換・レイテンシコスト警告、オーケストレーション層代替案提示 | 変換コストの見落とし |
| **Decorator** | オブジェクトに動的に振る舞いを追加 | `"I have a logging service but want to add optional features (caching, metrics) without modifying the existing code."` | Decorator特定、chain-of-responsibility版提案、組み合わせの図示 | 深いネストは保守困難 |
| **Proxy** | オブジェクトへのアクセスを制御 | `"I want to protect access to a remote resource with logs and caching. What structure would you suggest?"` | Virtual/Remote/Protective Proxyの種別説明、実装例（実体を注入）提示 | 制御意図とメトリクスを可視化することが重要 |
| **Composite** | 階層オブジェクト群を単一エンティティとして扱う | `"I want to apply the same operation to a group of elements, some of which are groups themselves."` | Composite提案、ツリー例の構築、再帰とポリモーフィズムの利点説明 | 過度な汎化 |

### 振る舞い系パターン

| パターン | 目的 | Augmented Prompt | LLM Contributions | Caution |
|---------|------|-----------------|-------------------|---------|
| **Strategy** | アルゴリズムを交換可能にカプセル化 | `"Here are three ways to compute a user score. Suggest a structure that lets me select one dynamically based on context and explain your choice."` | インターフェースベース実装提案、切り替え基準の特定、A/Bテストシミュレーション | コンテキストデータが曖昧だと過剰汎化 |
| **Observer** | イベント発生時に依存コンポーネントへ通知 | `"I want my module to send a notification every time its state changes, but I don't want tight coupling. Which pattern applies?"` | Observerパターン説明、TypeScript/Python実装生成、pub-sub代替提示 | 間接結合が生む複雑性を把握すること |
| **Command** | アクションをオブジェクトとしてカプセル化 | `"I want to be able to undo or reschedule certain user operations. What structure should I use?"` | Command特定、`execute()`/`undo()`/`redo()` IF提案、バッファ・キューの示唆 | 状態の可逆性を設計の中心に据える思考を促す |

---

## アーキテクチャパターン拡張

| パターン | 目的 | Augmented Prompt | LLM Contributions | Caution |
|---------|------|-----------------|-------------------|---------|
| **Event Sourcing** | 状態変化の完全な履歴をイベントとして保持 | `"I want to replay business decisions over time and audit an object's evolution."` | Event Sourcing提案、Command/Event/Projectionの説明 | イベントのバージョニング管理が必須 |
| **CQRS** | 読み書きモデルを分離して各々を最適化 | `"I need a system with very fast reads but robust business logic on writes."` | CommandHandler/QueryModel/ReadStore構造化、適用ケース（高読取・スケーラブル）提示 | 追加される複雑性を過小評価しない |
| **Circuit Breaker** | 障害サービスがシステム全体に波及するのを防ぐ | `"How can I isolate an unstable service without impacting the whole system?"` | Closed/Open/Half-Open状態遷移の説明、HTTP呼び出しへの統合、閾値メトリクス生成 | カオスエンジニアリング支援にも活用可 |

---

## 5つのアーキテクチャ対話モチーフ

LLMとのアーキテクチャ探索で繰り返し現れる対話の型。

| モチーフ | 意図 | プロンプト例 | リスク |
|---------|------|------------|--------|
| **Comparison（比較）** | 複数パターンから選択する | `"Compare Factory, Builder and AbstractFactory for this need"` | デフォルト解への偏り |
| **Guided Refactor（誘導リファクタ）** | パターンを使ってコードを再考する | `"Refactor this module with the Strategy pattern"` | コンテキストエラー（既存の文脈を誤解する） |
| **Diagnostic（診断）** | アンチパターンや構造問題を検出する | `"Do you see a God Object or structure issue here?"` | 偽陽性 |
| **Argumentation（論証）** | アーキテクチャ選択を説明する | `"Why use CQRS here rather than CRUD?"` | 存在しない利点のハルシネーション |
| **Synthesis（統合）** | 2つの構造を並べて比較する | `"Compare these two models for this functional need"` | 表面的な比較にとどまる |

---

## 7つの新興パターン（LLMエージェント時代）

まだ標準化されていないが、実験やツールで繰り返し観察されるパターン。

### Collaborative Agent

| 項目 | 内容 |
|------|------|
| **説明** | 人間の役割を支援する特化AIエージェントが再帰的ループで協働する |
| **役割** | 意思決定支援・分析・検証のサポート |
| **プロンプト例** | `"Act as a friendly reviewer: read this code and ask me the right questions."` |
| **効果** | 人間が責任を持ちながら視点を豊かにできる |
| **リスク** | 依存過多による人間の判断力低下 |

### Chain of Reason（Chain-of-Thought Engine）

| 項目 | 内容 |
|------|------|
| **説明** | 複雑なタスクを論理的ステップに分解し、1つ以上のLLMに割り当てる |
| **役割** | 計画・明確化・実行・検証の明示的な段階管理 |
| **プロンプト例** | `"Break the following problem into steps, then solve each step one by one."` |
| **効果** | 多ターン生成・自己評価・エージェント化に活用可能 |
| **リスク** | 監視なしでは不精度・バイアスが蓄積する |

### Prompt Chaining

| 項目 | 内容 |
|------|------|
| **説明** | 複数プロンプトを連鎖させて複雑な推論・生成を分解する |
| **役割** | 各ステップの出力を次のステップへ渡し、中間仮説を検証可能にする |
| **プロンプト例** | `"1) Summarize the business need. 2) Derive three test cases. 3) Generate test code for each."` |
| **効果** | 推論を再現可能・監査可能にする明確な思考パイプライン |
| **リスク** | 中間エラーの伝播 |

### Tree of Thought

| 項目 | 内容 |
|------|------|
| **説明** | 複数の推論経路を並行して探索し、最良のアイデアを選択・統合する |
| **役割** | アーキテクチャ選択・曖昧な意思決定・複雑な問題解決 |
| **プロンプト例** | `"Should we break this module into microservices?"` → LLMがパフォーマンス/保守性/コスト等を多角的に探索 |
| **効果** | 単一パスや局所最適バイアスを回避する高い再帰性 |
| **リスク** | 組み合わせ爆発・評価コストの増大 |

### Prompt as Interface

| 項目 | 内容 |
|------|------|
| **説明** | プロンプトを永続的・バージョン管理可能・テスト可能なアーティファクトとして扱う |
| **役割** | 人間の意図とAI実装の間のインターフェース。仕様書として「プロンプトが権威」 |
| **プロンプト例** | `ask_for_architecture_analysis.prompt.md` をプロジェクト横断で再利用 |
| **効果** | 自然言語の柔軟性を保ちながら定式化を工業化する |
| **リスク** | プロンプトの硬直化・文脈変化への追従遅れ |

### Agent Mesh

| 項目 | 内容 |
|------|------|
| **説明** | 固定階層を持たない特化AIエージェント群が協調する |
| **役割** | メッセージ・共有メモリ・ローカル仲裁で通信。マイクロサービスの認知的バージョン |
| **プロンプト例** | 診断エージェント・リフレーザー・シンセサイザーからなるサポートシステム |
| **効果** | 認知的スケーラビリティの向上 |
| **リスク** | 調整複雑性の増大 |

### Intention Router

| 項目 | 内容 |
|------|------|
| **説明** | 表現された意図に基づいて適切なツール・エージェント・LLMを動的に選択する |
| **役割** | 意図分類（分析/生成/批評…）→ルーティング。Plug & Promptアプローチと親和性高い |
| **プロンプト例** | `"From the following question, choose the right tool among A, B, C or me."` |
| **効果** | UX向上、プロンプト過負荷の回避 |
| **リスク** | 意図分類の誤りによるルーティングエラー |

---

## 活用上の注意点

- **パターンを偶像化しない**: LLMはパターンの有用性を過大評価することがある
- **選択理由を文書化する**: なぜこのパターンか、なぜ別のパターンでないかを記録
- **人間による検証必須**: すべてのパターン選択はチームの集合的な意思決定であり、自動応答ではない
- **新興パターンは実験的に検証**: LLMが提案するモチーフは観察・共同構築で精錬していく
