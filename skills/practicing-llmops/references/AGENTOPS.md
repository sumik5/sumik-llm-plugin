# AgentOps詳細リファレンス

MLOps → GenAIOps → AgentOpsの進化における実践的な設計パターン、組織構造、アーキテクチャのリファレンス。

---

## GenAIOps: People & Process

### 主要ロール定義

GenAIアプリケーション開発では以下の3ロールが中核を担う:

| ロール | 役割 | 必要スキル |
|--------|------|-----------|
| **Prompt Engineer** | ドメイン専門家として最適なプロンプトを設計・テスト | ドメイン知識・評価設計・プロンプトテンプレート設計 |
| **AI Engineer** | 特定モデルファミリーを最適に活用するバックエンド実装 | モデルAPI・バックエンド開発・評価自動化 |
| **DevOps/App Developer** | チャットbot・インタラクティブUIなど次世代フロントエンド構築 | CI/CD・コンテナ・UI開発 |

**補足**: これらはペルソナであり、人数ではない。小規模チームでは1人が複数ロールを兼任することが多い。

### MLOps チームとの協働

```
Cloud Platform Team（インフラ基盤）
  ↓
Data Engineering Team（データパイプライン）
  ↓
Data Science & MLOps Team（モデル訓練・実験）
  ↓
Machine Learning Governance（制御タワー・承認フロー）
```

GenAIアプリ開発チーム（Prompt Engineer / AI Engineer / DevOps）は
上記MLOpsチームが提供するデータ・インフラの上に構築する。

---

## FM選定3ステップ

20,000超の利用可能なFMから最適なモデルを選ぶための体系的プロセス。

### Step 1: FM Reference Tableの作成

組織として承認済みの5〜20モデルのショートリストを作成する。

**フィルタリング基準**:

| 基準 | チェック内容 |
|------|------------|
| オープンソース vs プロプライエタリ | ライセンス・商用利用可否 |
| **EULA法的審査** | データ使用条件・IP保護（必須） |
| コンテキストウィンドウサイズ | タスクの長文要件に対応可能か |
| マルチモーダル・ライブストリーミング対応 | ユースケースの技術要件 |
| ファインチューニング可否 | 将来的なカスタマイズ計画 |
| チームの既存スキル | 習熟済みモデルファミリーで開発加速 |

### Step 2: 上位3モデルを自社データで評価

公開リーダーボードは汎用ベンチマーク。**自社データ・ユースケース**での評価が本質。

- Reference Tableから上位2〜3モデルを候補選定
- Prompt Catalogの評価データセット（5〜10プロンプト）で比較測定
- 精度・一貫性・エッジケース対応を計測

### Step 3: ビジネス優先度で最終決定

精度スコアだけでなく**トレードオフ分析**で選定:

| 優先度設定例 | 選定ロジック |
|------------|------------|
| コスト最優先 | 精度が許容範囲内で最もコストが低いモデル |
| 精度最優先 | コスト・レイテンシを妥協してでも精度最高モデル |
| レイテンシ最優先 | リアルタイム応答が必須なユースケース（Live Agent等） |

**実践パターン**: 優先度0・優先度1の2つを設定し、残り1つは無視する（3軸同時最適化は非現実的）。

---

## Prompt Template Catalog 設計

### プロンプト進化の4段階

```
Stage 1: 単発プロンプト
  AIエンジニア + プロンプトエンジニアが5〜10プロンプトを手動作成

Stage 2: Prompt Catalog
  プロンプト + 期待出力のペアを蓄積（数百〜数千レコード）
  → 自動評価のGround Truthとして機能

Stage 3: Prompt Template Catalog（組織規模）
  バージョン管理・オーナーシップ・モデルファミリー別バリエーションを管理
  → プロンプトエンジニアが再利用・改善・モデル移行を効率化

Stage 4: Prompt Optimization
  別のFMが既存プロンプトを自動改善（フィードバックループ）
  → 継続的な品質向上の自動化
```

### Prompt Template Catalogのメタデータ

各エントリーに含めるべき情報:

```yaml
template:
  id: "summarize-customer-feedback-v2"
  version: "2.1.0"
  owner: "ai-team@example.com"
  model_family: ["gemini-2.0", "claude-4.x"]
  task_type: "summarization"
  prompt_template: |
    あなたは{role}です。以下の顧客フィードバックを{format}形式で要約してください。
    フィードバック: {input}
  examples:
    - input: "..."
      expected_output: "..."
  evaluation_metrics: ["rouge-l", "semantic_similarity"]
  last_evaluated: "2026-03-13"
  performance:
    gemini-2.0: {precision: 0.87, latency_ms: 320}
    claude-4.x: {precision: 0.91, latency_ms: 450}
```

### Materialized View パターン

```
Prompt Template（構造体）
  ×
Instruction/Context/Response Table（データ）
  ↓
Materialized Prompt Catalog
  （テンプレート × データの全組み合わせを実体化）
  ↓
大規模評価データセットとして自動生成
```

---

## 評価メトリクス選択フロー

### 判断木

```
ラベルデータ（正解データ）が利用可能か？
├── YES → タスクの性質は？
│     ├── 単一正解（QA等）  → Precision / Recall / F1
│     ├── 類似テキスト      → Cosine Similarity / ROUGE / BLEU
│     ├── 事実正確性        → HELM
│     └── 安全性・バイアス  → Toxigen / Stereotype metrics
│
└── NO → 精度要件は高いか？
      ├── HIGH  → Human-in-the-Loop (HIL)
      │     （人間が入出力を評価・スコアリング）
      └── LOW   → LLM as a Judge（Autorater）
            （別LLMが出力を自動評価）
```

### エンタープライズ評価の進化パターン

```
Phase 1: 完全HIL（高精度・高コスト）
  ↓ 評価データが蓄積されたら
Phase 2: 半自動（HIL + LLM-as-Judge混合）
  ↓ ラベルデータが十分揃ったら
Phase 3: 完全自動（タスク固有メトリクス）
```

### AgentOps固有の評価メトリクス

| メトリクス | 説明 | 計算方法 |
|----------|------|---------|
| **Tool Selection Accuracy** | 正しいツールを選択した割合 | 正解ツール選択数 / 全シナリオ数 |
| **Parameter Precision** | ツールパラメータの正確性 | 正解パラメータ / 全パラメータ |
| **Trajectory Match Rate** | 期待ツール呼び出し列との一致率 | 一致したstep数 / 総step数 |
| **No-Tool Precision** | ツール不要時に正しくツールを呼ばない率 | 正解ケース / ツール不要シナリオ数 |
| **End-to-End Latency** | ユーザー入力→最終応答の合計時間 | Wall clock time（ms） |
| **Cost per Interaction** | 1インタラクションあたりのトークンコスト | Input+Output tokens × price |

---

## GenAIOps Reference Architecture（GCP版）

### 環境構成

```
┌─────────────────────────────────────────────────────┐
│ Shared Service Project                              │
│   VPC / Subnet / IAM / KMS / Monitoring / Budget   │
└─────────────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────┐
│ Data Project（Data Lake / Data Mesh）               │
│   ├── データ収集・前処理                              │
│   ├── RAG向けデータ準備（chunking / vectorization） │
│   └── Evaluation Prompt Catalog                    │
└─────────────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────┐
│ Development Project                                 │
│   ├── モデル選定・Prompt Catalog構築                 │
│   ├── GenAI Backend開発（コンテナ）                  │
│   └── GenAI Frontend開発                           │
└─────────────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────┐
│ Staging / Testing Project                           │
│   ├── 統合テスト・ストレステスト                      │
│   └── Human-in-the-Loop（Prompt Tester）評価        │
└─────────────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────┐
│ Production Project                                  │
│   ├── GenAI Backend（コンテナ / Cloud Run）          │
│   ├── GenAI Frontend                               │
│   ├── Continuous Monitoring                        │
│   └── Feedback Mechanism（サムズアップ/ダウン）      │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ AI Governance Project（制御タワー）                  │
│   ├── Code Repository                              │
│   ├── Artifact Registry（カスタムコンテナ）          │
│   ├── Prompt Template Catalog                      │
│   └── FM Reference Table / Model Registry          │
└─────────────────────────────────────────────────────┘
```

---

## AgentOps Reference Architecture（上記 + Registry/Memory拡張）

### GenAIOps → AgentOpsへの拡張ポイント

```
Data Project に追加:
  ├── Long-Term Memory（BigQuery / Firestore / Spanner）
  └── Trajectory Evaluation Data（ツール呼び出し列の正解データ）

Development Project に追加:
  └── Agents as a Service（専用repo + CI/CDパイプライン）

Production Project に追加:
  └── Short-Term Memory（Cloud Trace / OpenTelemetry）

AI Governance Project に追加:
  ├── Tool Registry（全ツールの権威あるカタログ）
  │     ← CI/CDパイプラインが自動登録
  └── Agent Registry（全AgentCardのディレクトリ）
        ← CI/CDパイプラインが自動登録
```

### A2Aプロトコル統合パターン

```
Router Agent
  ├── Agent Registryを検索（自然言語 or メタデータ）
  ├── 対象エージェントのAgentCardを取得
  └── A2Aプロトコルでサブエージェントを呼び出し
        ↓
  各エージェントは Tool Registryから tool listを取得
  各エージェントはShort-Term Memoryでセッション管理
  重要な会話はLong-Term Memoryに永続化 → RAG入力
```

---

## Unified MLOps + AgentOps Platform ブループリント

大規模企業（モデル創造者 + 消費者の両方）向けの統合アーキテクチャ。

### 2ストリームの統合

```
上位ストリーム: Model Development（MLOps / FMOps）
  データサイエンティストが:
  ├── 実験（Sandbox）→ 開発（ML Pipeline）→ Staging → Production
  └── Governance: Model Registry にカスタムFMを登録

        ↕ カスタムFMのAPI提供

下位ストリーム: Application Development（GenAIOps / AgentOps）
  AIエンジニアが:
  ├── 上位ストリームのProduction環境からカスタムFMをAPI経由で消費
  ├── FM Reference Tableに追加
  └── GenAIOps/AgentOpsライフサイクルでアプリ開発
```

### 判断基準: どちらのストリームが必要か

| 組織特性 | 推奨構成 |
|---------|---------|
| モデルAPIを使うだけ | 下位ストリームのみ（GenAIOps/AgentOps） |
| ファインチューニングあり | 上位 + 下位の両方 |
| FMをゼロから訓練 | 上位 + 下位の完全統合 |
| スタートアップ・中小企業 | 下位のみ（GenAIOps）、必要になったら拡張 |

### 環境数の柔軟性

書籍で示した5〜6環境構成はベストプラクティスだが、組織規模・成熟度に応じて調整可能:
- **最小構成**: 単一環境（Dev/Staging/Prod統合）でも核となる能力・サービス・人材は同一
- **推奨理由**: Separation of Concerns・開発ベストプラクティス・ネットワーク/IAMのセキュリティ設計

---

## 実装チェックリスト

### GenAIOps導入

- [ ] ユースケースのROI・ビジネス価値を評価
- [ ] FM Reference Table（5〜20モデル）をEULA審査済みで作成
- [ ] Prompt Catalog（最低10プロンプト）を構築
- [ ] 評価メトリクスを選定（ラベルデータ有無を確認）
- [ ] Development → Staging → Production環境を分離

### AgentOps追加

- [ ] 各ツールのUnit Testを整備
- [ ] Evaluation Prompt CatalogにTrajectory Dataを追加
- [ ] Tool RegistryをAI Governance Projectに設置
- [ ] Agent RegistryをAgentCard形式で整備
- [ ] Short-Term Memory（OpenTelemetry）を本番に組み込み
- [ ] Long-Term Memory（BigQuery/Firestore）をData Projectに設置
- [ ] メモリへのアクセス制御・PII保護ポリシーを定義
- [ ] Agents as a Serviceパターンを採用（専用CI/CD）
