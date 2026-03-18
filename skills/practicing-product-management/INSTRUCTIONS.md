# プロダクトマネジメント実践ガイド

## 目次

1. [使用タイミング](#1-使用タイミング)
2. [コアプリンシプル](#2-コアプリンシプル)
3. [クイックリファレンス](#3-クイックリファレンス)
4. [ユーザー確認の原則](#4-ユーザー確認の原則askuserquestion)
5. [詳細ガイドへのリンク](#5-詳細ガイド)
6. [AI時代のPM実践](#6-ai時代のpm実践)
7. [レジリエントPM実践（ケーススタディ駆動）](#7-レジリエントpm実践ケーススタディ駆動)
8. [まとめ](#8-まとめ)

---

## 1. 使用タイミング

- PMとしての意思決定（What to build）が必要な場面
- ロードマップ策定・優先順位付け
- PM-UX協働関係の設計
- プロダクトアナリティクスの分析
- 成長施策の立案・グロースメトリクスの解釈
- 収益モデルの選定・改善
- AI成熟度評価・組織のAI readiness判断
- AI導入によるPM役割の変化への対応
- 不確実性下でのプロダクト意思決定
- 測定フレームワークの設計
- 優先順位付けワークショップの運営
- クロスファンクショナル協働の設計
- 根本原因分析
- MLサービスのプロダクト化戦略の策定
- 既存プロダクトへのAI統合計画
- AI PMキャリアの設計・成長計画
- バーティカル別AIプロダクト戦略

---

## 2. コアプリンシプル

### 2.1 PM ＝ 価値に責任を持つ人

PMの役割は「価値への責任」であり、権限ではない。

| よくある誤解 | 実態 |
|------------|------|
| PM ＝ プロジェクトマネージャー（PjM） | PM = Whatに責任、PjM = How/Whenに責任 |
| PM ＝ プロダクトオーナー（PO） | POはスクラム文脈の役割。PMはより広いビジネス責任を持つ |
| PM ＝「プロダクトのCEO」（権限あり） | 権限なき責任が実態。サーバントリーダーシップが基本 |

優秀なPMに共通する3つの素質:
1. **好奇心**: ユーザー・市場・技術すべてへの関心
2. **接続力**: UX・エンジニア・ビジネスの橋渡し
3. **度胸**: 不確実な状況での意思決定を恐れない

### 2.2 構築-計測-学習サイクル

```
学習 → ディスカバリー → 構築 → 計測 → 学習（繰り返し）
```

- **構築から始めない**: 仮説を立ててからMVPを作る
- **仮説駆動開発**: 「〜すれば〜になる」形式で仮説を明確化
- **定量 + 定性の組み合わせ**: 数字だけでなくユーザーインタビューで文脈を掴む

実験タイプの選択:
| タイプ | 適用場面 | 例 |
|--------|---------|-----|
| Build（構築） | 新機能の検証 | MVP・プロトタイプ |
| Fix（修正） | 既知の問題解決 | バグ修正・UX改善 |
| Tune（調整） | 既存機能の最適化 | A/Bテスト・コピー変更 |

### 2.3 PM-UXスペクトル

PMとUXは対立するのではなく、スキルが重複するスペクトル上に存在する。

| 役割 | 主な責任 | 所有するもの |
|------|---------|------------|
| PM | What（何を作るか）・Why（なぜ作るか） | プロダクト戦略・ロードマップ・成功指標 |
| UX | How（どう作るか）・How well（品質） | デザイン・リサーチ・ユーザビリティ |
| 重複領域 | ユーザーリサーチ・ペルソナ・情報アーキテクチャ | 協議・交渉が必要 |

チーム健全度の判別:
- **良いチーム**: 役割が明確で相互尊重。PMはUXをスキル活用パートナーとして扱う
- **悪いチーム**: PMがUXを軽視。UXがビジネス目標を無視
- **不愉快なチーム**: 縄張り争い・意思決定の曖昧さ・リソース競合

---

## 3. クイックリファレンス

### アジャイルケイデンス表

| タイムスケール | セレモニー | PMの主な役割 |
|--------------|-----------|------------|
| 日次 | スタンドアップ（15分） | 進捗確認・ブロッカー除去 |
| 週次 | ウィークリーシンク | 優先順位の再確認・ステークホルダー更新 |
| 2〜4週 | スプリント | プランニング・レビュー・レトロスペクティブ |
| 月次 | ロードマップレビュー | Now/Next/Later の更新 |
| 四半期 | OKRプランニング | 目標設定・年間計画進捗確認 |
| 年次 | 年間計画 | ミッション・長期目標の再考 |

### AARRR 海賊指標

| 指標 | 意味 | 最適化のポイント |
|------|------|----------------|
| **A**cquisition（獲得） | ユーザーをどこで認知・獲得するか | チャネル分析・CAC最小化 |
| **A**ctivation（活性化） | ユーザーが初めて価値を体験する | Aha!モーメント設計・オンボーディング |
| **R**etention（継続） | ユーザーが戻り続けるか | コホート分析・チャーン率削減 |
| **R**eferral（紹介） | ユーザーが他者に紹介するか | バイラル係数 K = 招待数 × 転換率 |
| **R**evenue（収益） | どう収益化するか | 収益モデル選定・LTV最大化 |

> **注意すべき2つの指標**: バニティメトリクス（見た目の良い数字）と虚栄のDAU。真の健全性は**リテンション率**とコホート分析で測る。

### PM活動タイプ判定テーブル

| 場面 | PMの行動 | UXの行動 | 境界線 |
|------|---------|---------|--------|
| 新機能の優先順位付け | ビジネス価値・技術リスクで判断 | ユーザビリティ影響を評価 | PMが最終決定 |
| ユーザーインタビュー設計 | 調査目標・仮説を設定 | インタビューガイド・モデレーション | 協働 |
| UI/UXデザイン変更 | 変更のビジネス根拠を承認 | デザイン・プロトタイプ作成 | UXが主導 |
| 成功指標の定義 | KPI・OKRを設定 | タスク成功率・SUS等を提案 | PMが最終決定 |
| ロードマップ公開タイミング | ステークホルダーへの開示戦略 | ユーザー影響のインプット提供 | PMが主導 |

### 「ノー」の伝え方フレームワーク

ステークホルダーからの要求を断る際の原則:

1. **理由を示す**: 優先順位付けの基準（OKR・ビジネス価値・技術リスク）で説明
2. **代替案を提示**: 「今は難しいが、Next/Laterに検討する」と伝える
3. **データで語る**: 機会費用・ROI見積もりを添える
4. **関係性を維持**: 断りながらも次の対話の機会を作る

### ロードマップ構造: Now-Next-Later

| 区分 | 期間目安 | 内容 | 粒度 |
|------|---------|------|------|
| **Now** | 現在のスプリント〜1ヶ月 | 確定・着手済みの作業 | 詳細な機能レベル |
| **Next** | 1〜3ヶ月 | 次に取り組む予定 | テーマ・エピックレベル |
| **Later** | 3ヶ月以上先 | 将来の方向性 | 戦略テーマレベル |

---

## 4. ユーザー確認の原則（AskUserQuestion）

**判断分岐がある場合、推測で進めず必ずAskUserQuestionツールでユーザーに確認する。**

### 確認すべき場面

```python
AskUserQuestion(
    questions=[
        {
            "question": "この機能をロードマップのどこに配置しますか？",
            "header": "ロードマップスコープの判断",
            "options": [
                {"label": "Now（今スプリントで着手）", "description": "ビジネス価値が高く・技術リスクが低い・ユーザーインパクトが大きい"},
                {"label": "Next（1〜3ヶ月以内）", "description": "重要だが依存関係がある・リソース調整が必要"},
                {"label": "Later（3ヶ月以上先）", "description": "将来的に検討。現在の戦略的優先度は低い"},
                {"label": "Backlog（未分類）", "description": "要件整理が必要。優先度未確定"}
            ],
            "multiSelect": False
        }
    ]
)
```

```python
AskUserQuestion(
    questions=[
        {
            "question": "このタスクの責任所在を確認します。チームの構成はどうなっていますか？",
            "header": "PM-UX線引きの判断",
            "options": [
                {"label": "PMとUXが別チーム（明確な役割分担あり）", "description": "境界を守りながら協働する"},
                {"label": "PM兼UX（同一人物または小規模チーム）", "description": "意識的に役割を切り替えて進める"},
                {"label": "UX不在（PMがUX判断もする）", "description": "ユーザーリサーチを最優先で組み込む"},
                {"label": "PMが曖昧（ハイブリッド体制）", "description": "責任の所在を明文化してから進める"}
            ],
            "multiSelect": False
        }
    ]
)
```

### 確認不要な場面

- ベストプラクティスが一義的に決まる場合（例: OKRは組織目標に紐付ける）
- データが明確に優先順位を示している場合
- スプリント中の微小な調整（ビジネスインパクトが軽微）

---

## 5. 詳細ガイド

| ファイル | 対象章 | 内容 |
|---------|--------|------|
| **[PM-FUNDAMENTALS.md](references/PM-FUNDAMENTALS.md)** | Ch1-3 | PMの定義・UXスキルの活用法・キャリア転身ガイド |
| **[EXECUTION-CADENCES.md](references/EXECUTION-CADENCES.md)** | Ch4-5 | アジャイルケイデンス・エンジニア管理・ビジネススキル |
| **[GROWTH-STRATEGY.md](references/GROWTH-STRATEGY.md)** | Ch6-11 | アナリティクス・実験・収益モデル・ロードマップ・PM-UX協働・リーダーシップ |
| **[AI-PM-EVOLUTION.md](references/AI-PM-EVOLUTION.md)** | AI時代 | AI時代のPM役割進化・スキルシフト・組織変革 |
| **[AI-MATURITY-ASSESSMENT.md](references/AI-MATURITY-ASSESSMENT.md)** | AI成熟度 | 5ピラー×12フォーカスエリア成熟度評価フレームワーク |
| **[AI-CASE-STUDIES.md](references/AI-CASE-STUDIES.md)** | AIケース | 4つのAIプロダクト事例（CV・GenAI・動的価格・広告AI） |
| **[MEASUREMENT-FRAMEWORKS.md](references/MEASUREMENT-FRAMEWORKS.md)** | メトリクス | HEART Framework、計測スキーマ、ダッシュボード設計 |
| **[PRIORITIZATION-METHODS.md](references/PRIORITIZATION-METHODS.md)** | 優先順位付け | Feature Prioritization Matrix、Impact-Effort Scoring |
| **[COLLABORATION-WORKSHOPS.md](references/COLLABORATION-WORKSHOPS.md)** | ワークショップ | ジャーニーマッピング、フィッシュボーン、協働リチュアル |
| **[EXPERIMENTATION-DESIGN.md](references/EXPERIMENTATION-DESIGN.md)** | 実験設計 | A/Bテスト、信頼区間、サンプリング戦略 |
| **[ROOT-CAUSE-ANALYSIS.md](references/ROOT-CAUSE-ANALYSIS.md)** | 根本原因分析 | ファネル分析、フィッシュボーン、データ収集 |
| **[PROCESS-WORKFLOWS.md](references/PROCESS-WORKFLOWS.md)** | プロセス | Kanban、Sprint Zero、リリース計画 |
| **[CASE-STUDY-PATTERNS.md](references/CASE-STUDY-PATTERNS.md)** | ケーススタディ | 7つの横断パターン（状況→課題→アプローチ→成果→教訓） |
| **[AI-PLAYBOOK-FOUNDATIONS.md](references/AI-PLAYBOOK-FOUNDATIONS.md)** | AI基礎 | AI/ML基礎知識、用語集、学習プロセス、AIライフサイクル8段階 |
| **[AI-PLAYBOOK-ROLES.md](references/AI-PLAYBOOK-ROLES.md)** | AI PMロール | AI-Experiences/AI-Builder/AI-Enhanced PM 3専門化、比較、キャリア選択 |
| **[AI-PLAYBOOK-STRATEGY.md](references/AI-PLAYBOOK-STRATEGY.md)** | AI戦略 | AI機会評価、ケイパビリティマッチング、ROI算出9ステップ、AI A/Bテスト |
| **[AI-PLAYBOOK-OPERATIONS.md](references/AI-PLAYBOOK-OPERATIONS.md)** | AI運用 | MLOps概要、バイアス緩和、責任あるAI、法的コンプライアンス |
| **[AIPM-PRODUCTIZING-ML.md](references/AIPM-PRODUCTIZING-ML.md)** | MLプロダクト化 | MLサービスのプロダクト化・商業化戦略・バーティカル特化 |
| **[AIPM-MANAGING-AI-PRODUCT.md](references/AIPM-MANAGING-AI-PRODUCT.md)** | AI管理 | Head/Heart/Gutsフレームワーク・ビジョン・アラインメント |
| **[AIPM-AI-INTEGRATION.md](references/AIPM-AI-INTEGRATION.md)** | AI統合 | 既存プロダクトへのAI統合・導入パターン・業界トレンド |
| **[AIPM-CAREER-MASTERY.md](references/AIPM-CAREER-MASTERY.md)** | PMキャリア | AI PMキャリア開始〜成熟・24ロール・4レベルロードマップ |

---

## 6. AI時代のPM実践

AI技術の普及により、PMの役割と求められるスキルが大きく変化している。

### 6.1 PM役割の進化

AIツールの導入により、PMの業務はルーティンタスクの自動化から戦略的判断へシフトしている。詳細は [AI-PM-EVOLUTION.md](references/AI-PM-EVOLUTION.md) を参照。

### 6.2 組織AI成熟度評価

AI導入の成功は、組織の成熟度に大きく依存する。5ピラー×12フォーカスエリアの成熟度フレームワークで現状を評価し、段階的な導入計画を策定する。詳細は [AI-MATURITY-ASSESSMENT.md](references/AI-MATURITY-ASSESSMENT.md) を参照。

### 6.3 AIプロダクトケーススタディ

実際のAIプロダクト事例（Computer Vision、GenAIチャットボット、動的価格設定、広告AI）から、PMの判断ポイントと教訓を学ぶ。詳細は [AI-CASE-STUDIES.md](references/AI-CASE-STUDIES.md) を参照。

### 6.4 AI/ML基礎知識

AIプロダクトを扱うPMが知るべきAI/MLの基本概念（AI vs ML、学習プロセス、Confusion Matrix、過学習/未学習、HITL）とAIライフサイクル8段階。詳細は [AI-PLAYBOOK-FOUNDATIONS.md](references/AI-PLAYBOOK-FOUNDATIONS.md) を参照。

### 6.5 AI PM専門化ロール

AI PMの3つの専門化（AI-Experiences / AI-Builder / AI-Enhanced）の役割・スキルセット・キャリアパス。詳細は [AI-PLAYBOOK-ROLES.md](references/AI-PLAYBOOK-ROLES.md) を参照。

### 6.6 AI機会評価とROI

プロダクトにAIを導入する機会の発見・評価方法、ROI算出9ステップ、AI特有のA/Bテスト設計。詳細は [AI-PLAYBOOK-STRATEGY.md](references/AI-PLAYBOOK-STRATEGY.md) を参照。

### 6.7 MLOpsと責任あるAI

MLOpsの5コンポーネント（PM視点）、AIバイアス緩和、倫理的AI構築チェックリスト、法的コンプライアンス。詳細は [AI-PLAYBOOK-OPERATIONS.md](references/AI-PLAYBOOK-OPERATIONS.md) を参照。

---

## 7. レジリエントPM実践（ケーススタディ駆動）

不確実性・制約・プレッシャー下でのプロダクトマネジメント実践知識。7つのケーススタディから抽出した実践パターン。

### 7.1 コアプリンシプル

| 原則 | 説明 |
|------|------|
| メトリクス階層 | 北極星メトリクス → コアメトリクス → 先行/遅行指標の3層構造 |
| 仮説駆動実験 | 仮説設計 → 計測スキーマ → A/Bテスト → 統計検証のサイクル |
| 制約下の適応 | インフラ・リソース制約を前提とした意思決定フレームワーク |
| ケーススタディ学習 | 実例の「状況→課題→アプローチ→成果→教訓」パターンで学ぶ |

### 7.2 クイックリファレンス

#### メトリクス選択判断テーブル

| 場面 | 推奨フレームワーク | 参照 |
|------|-------------------|------|
| ユーザー体験の総合評価 | HEART Framework | MEASUREMENT-FRAMEWORKS.md |
| エンゲージメント計測 | コアvs虚栄メトリクス判定 | MEASUREMENT-FRAMEWORKS.md |
| 先行/遅行指標の設計 | リキャリブレーション手法 | MEASUREMENT-FRAMEWORKS.md |

#### 優先順位付け手法選択ガイド

| 状況 | 推奨手法 | 参照 |
|------|---------|------|
| 機能の優先順位付け | Feature Prioritization Matrix | PRIORITIZATION-METHODS.md |
| リスク緩和の優先順位 | Impact-Effort Scoring | PRIORITIZATION-METHODS.md |
| 制約下での取捨選択 | MoSCoW + 制約マッピング | PRIORITIZATION-METHODS.md |

#### ワークショップ種別選択ガイド

| 目的 | ワークショップ | 参照 |
|------|-------------|------|
| 顧客体験の理解 | ジャーニーマッピングWS | COLLABORATION-WORKSHOPS.md |
| 問題の根本原因特定 | フィッシュボーンWS | COLLABORATION-WORKSHOPS.md |
| チーム連携の強化 | 協働リチュアル設計 | COLLABORATION-WORKSHOPS.md |

---

## 8. AIプロダクトマネジメント

AIプロダクト特有の課題（モデルドリフト、データ品質、期待値管理）に対応するPMの実践知識。

### AIプロダクトの3専門化

| 専門化 | 担当領域 | 核心スキル |
|--------|---------|-----------|
| **AI-Experiences PM** | AIとユーザーの接点を設計 | UXリサーチ、AI UX原則、説明可能性 |
| **AI-Builder PM** | AIシステムの基盤を構築 | MLOps、データパイプライン、モデル評価 |
| **AI-Enhanced PM** | PMの業務をAIで強化 | AI活用プロセス設計、ワークフロー自動化 |

### AIプロダクトライフサイクル（8段階）

```
Problem Definition → Data Collection → Preprocessing → Feature Engineering
→ Model Training → Evaluation → Deployment → Retraining
```

各段階でのPM役割、MLOps用語、ROI算出9ステップ → **[AIP-AI-PM-GUIDE.md](references/AIP-AI-PM-GUIDE.md)**

詳細リファレンス:
- AIプロダクトライフサイクル → **[AIP-AI-LIFECYCLE.md](references/AIP-AI-LIFECYCLE.md)**
- AI戦略・データ品質（PROMT/EDGE） → **[AIP-AI-STRATEGY.md](references/AIP-AI-STRATEGY.md)**
- グロースメトリクス・RAD・PLG → **[AIP-GROWTH-METRICS.md](references/AIP-GROWTH-METRICS.md)**
- 責任あるAI・倫理チェックリスト → **[AIP-RESPONSIBLE-AI.md](references/AIP-RESPONSIBLE-AI.md)**
- プロダクト設計・HEART詳細 → **[AIP-PRODUCT-DESIGN.md](references/AIP-PRODUCT-DESIGN.md)**
- 3専門化比較・キャリアパス → **[AIP-TEAM-CAREER.md](references/AIP-TEAM-CAREER.md)**
- MLプロダクト化・商業化戦略・バーティカル特化 → **[AIPM-PRODUCTIZING-ML.md](references/AIPM-PRODUCTIZING-ML.md)**
- Head/Heart/Gutsフレームワーク・AI管理 → **[AIPM-MANAGING-AI-PRODUCT.md](references/AIPM-MANAGING-AI-PRODUCT.md)**
- 既存プロダクトへのAI統合・業界トレンド → **[AIPM-AI-INTEGRATION.md](references/AIPM-AI-INTEGRATION.md)**
- AI PMキャリア・24ロール・4レベルロードマップ → **[AIPM-CAREER-MASTERY.md](references/AIPM-CAREER-MASTERY.md)**

---

## 9. A/Bテスト実践

オンラインコントロール実験（A/Bテスト）の設計・実行・解析の体系的手法。

### A/Bテストの核心概念

**OEC（Overall Evaluation Criterion）**: 実験の成否を判断する単一の総合評価基準。正規化が重要（「ユーザーあたり収益」など）。

**実験設計の4決定**: ランダム化単位 → ターゲット母集団 → サンプルサイズ → 実験期間

**必要サンプルサイズ**: `≈ 16 × σ² / δ²`（σ²=分散、δ=検出したい最小差）

### 信用性チェック（トワイマンの法則）

> 面白そうな結果はたいてい間違っている

| 落とし穴 | 対策 |
|---------|------|
| p値ピーキング | 事前に決めた期間が経過後に判定 |
| SRM（サンプル比率ミスマッチ） | 実験前に比率確認。SRM検出時は結果を無効化 |
| ノベルティ効果 | 効果の時間変化をプロット、安定まで実験延長 |

統計的検定・サンプルサイズ計算 → **[AB-STATISTICS.md](references/AB-STATISTICS.md)**
実験プラットフォーム・組織文化 → **[AB-PLATFORM-AND-CULTURE.md](references/AB-PLATFORM-AND-CULTURE.md)**
A/Bテスト全手法ガイド → **[AB-EXPERIMENTATION-GUIDE.md](references/AB-EXPERIMENTATION-GUIDE.md)**

---

## 10. Claude Code PM活用

PMがClaude Codeを使ってコードベース調査・要件定義・競合分析を効率化する実践ガイド。

### 5つのコア能力

| 能力 | PM活用例 |
|------|---------|
| ファイル読み書き | コードベース調査結果をMarkdownで保存、PRDをリポジトリに生成 |
| シェルコマンド実行 | git logで変更履歴調査 |
| 永続コンテキスト（CLAUDE.md） | プロダクト用語集・主要ユーザージャーニーを永続化 |
| Subagent並列処理 | 競合3社を並列調査、フィードバック500件を分割分析 |
| MCP外部連携 | Jira/Slack/Figma/DBに直接接続 |

### PM調査の4パターン

| パターン | 質問例 |
|---------|--------|
| 「Xはどう動く？」 | 割引コード検証はどう実装されている？ |
| 「Xはどのデータにアクセス？」 | 購入履歴機能はどのデータを使う？ |
| 「Xが起きたら？」 | 決済が途中で失敗したらどうなる？ |
| 「なぜXが起きる？」 | 検索フィルタが「もっと見る」で消えるのはなぜ？ |

**Permission Mode推奨**: plan mode（読み取り専用）でコードベース調査。成果物生成時はacceptEdits。

コードベース調査・バグトリアージ → **[CCPM-INVESTIGATION-PATTERNS.md](references/CCPM-INVESTIGATION-PATTERNS.md)**
競合分析・フィードバック分析 → **[CCPM-RESEARCH-SYNTHESIS.md](references/CCPM-RESEARCH-SYNTHESIS.md)**
PRD・ユーザーストーリー生成 → **[CCPM-REQUIREMENTS-DOCS.md](references/CCPM-REQUIREMENTS-DOCS.md)**
スキル設計・MCP・Subagent → **[CCPM-ADVANCED-WORKFLOWS.md](references/CCPM-ADVANCED-WORKFLOWS.md)**
PMプロンプトテンプレート集 → **[CCPM-PROMPT-TEMPLATES.md](references/CCPM-PROMPT-TEMPLATES.md)**
Claude Code PM総合ガイド → **[CCPM-GUIDE.md](references/CCPM-GUIDE.md)**

---

## 11. まとめ

**優先すべき3原則:**

1. **顧客に価値を届けること（完璧より出荷）**
   - 仮説を立てて試し、学びを重ねる。最初から完璧を目指さない

2. **データと定性調査の両方で意思決定**
   - 数字は「何が起きているか」を示す。ユーザーインタビューは「なぜ起きているか」を示す

3. **PM-UXの役割を明確にしつつ協働する**
   - 境界を設けるのは排除のためでなく、責任の明確化のため
   - UXの強みをPMとして最大限活用する
