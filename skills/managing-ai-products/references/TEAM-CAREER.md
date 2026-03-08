# チーム・キャリア

出典: *AI Product Manager's Handbook 2nd Ed.* (Irene Bratsis, Packt 2024) Ch.17-19
出典: *The AI Product Playbook* (Nika & Granados, Wiley 2026) Ch.5-7, Ch.12

---

## AI PM 3専門化 — 詳細比較

出典: *The AI Product Playbook* Part II（Ch.5-7）

### AI-Experiences PM（体験設計スペシャリスト）

**コアミッション**: AIがユーザーと触れる全ての接点（UI/UX）を最適化する

#### 主要責任（Key Responsibilities）
```
1. AI機能のユーザー体験戦略の定義
2. AI出力の品質基準（Eval基準）の設定
3. ユーザーリサーチ・フィードバックの収集・分析
4. 説明可能性・透明性のUX設計
5. AI体験に関するA/Bテスト設計・分析
6. AI利用に関するユーザー期待値管理
```

#### 日常業務（Day-to-Day Activities）
```
- GenAI機能のEval（評価）セッションに参加
- ユーザーフィードバックを分析してMLチームにフィード
- プロンプトエンジニアリングチームと協働
- モデルアップデートのUXインパクト評価
- ユーザーテストセッションのファシリテーション
```

#### 必要スキルセット（Toolkit）
```
Core PM Craft:
  ✓ ユーザーリサーチ・ユーザビリティテスト
  ✓ プロダクトロードマップ管理
  ✓ データドリブンな意思決定

Engineering Foundations for PMs:
  ✓ API基礎知識（REST・GraphQL）
  ✓ プロンプトエンジニアリングの基礎
  ✓ AI/MLの出力形式と限界の理解

Leadership & Collaboration:
  ✓ UX/デザインチームとの協働
  ✓ ステークホルダーへのAI体験の説明・説得
  ✓ 倫理的AI実践の推進

AI Lifecycle Awareness:
  ✓ Evals（AI評価）の種類と実施方法
  ✓ Model Driftがユーザー体験に与える影響
  ✓ Human-in-the-Loop設計
```

---

### AI-Builder PM（インフラアーキテクト）

**コアミッション**: AIシステムの基盤・プラットフォームを構築し、エンジニアリングチームを率いる

#### 主要責任（Key Responsibilities）
```
1. MLプラットフォーム・インフラのPRD作成
2. データパイプラインの要件定義
3. APIインターフェースの設計とガバナンス
4. モデル訓練・評価・デプロイパイプラインの監督
5. Build vs Buy vs Open Source意思決定
6. AIインフラのコスト管理（AI is expensive）
```

#### 日常業務（Day-to-Day Activities）
```
- Feature Storeやモデルレジストリの要件化
- ML Engineerとのスプリントプランニング
- システムアーキテクチャレビューへの参加
- AI/ML技術的負債の管理・優先度付け
- クラウドプロバイダーとのコスト交渉・最適化
```

#### 必要スキルセット（Toolkit）
```
Core PM Craft:
  ✓ 技術的なPRD・API仕様書の作成
  ✓ テクニカルロードマップの管理
  ✓ エンジニアリングチームのスコープ調整

Engineering Foundations for PMs:
  ✓ MLOps基礎（CI/CD for ML）
  ✓ クラウドインフラ（AWS/GCP/Azure）
  ✓ データエンジニアリング概念
  ✓ APIデザインパターン

Leadership & Collaboration:
  ✓ ML Engineer・Data Scientist・Data Engineerとの橋渡し
  ✓ CTO/VPEngへのテクニカル戦略提言
  ✓ インフラ投資のROI説明

AI Lifecycle Awareness:
  ✓ ML訓練パイプラインの全段階
  ✓ Feature Engineering要件の定義
  ✓ モデル評価メトリクス（Precision/Recall/F1等）
```

---

### AI-Enhanced PM（AIツール活用スペシャリスト）

**コアミッション**: PMの業務プロセス自体をAIツールで強化し、意思決定の質とスピードを上げる

#### 主要責任（Key Responsibilities）
```
1. PM業務のAI活用プロセス設計・標準化
2. AIツール（Copilot・Analytics・リサーチ支援）の評価・導入
3. データ収集・分析・インサイト抽出の自動化
4. AIが生成したプロダクト仮説の検証フロー設計
5. 組織全体へのAI活用文化の普及
```

#### 日常業務（Day-to-Day Activities）
```
- AIツールを使ったユーザーフィードバック分析
- 競合分析の自動化・整理
- ロードマップ生成・優先度付けのAI活用
- 会議・インタビューの自動文字起こし・要約
- データ分析ダッシュボードの整備
```

#### 必要スキルセット（Toolkit）
```
Core PM Craft:
  ✓ プロセス設計・最適化
  ✓ ツール評価・導入プロジェクト管理
  ✓ 変更管理（チームへのAI活用浸透）

Engineering Foundations for PMs:
  ✓ プロンプトエンジニアリング（実務レベル）
  ✓ APIインテグレーション基礎
  ✓ データ分析・BI ツール活用

Leadership & Collaboration:
  ✓ AI活用のROI測定・報告
  ✓ 組織横断的なAI活用ベストプラクティス共有
  ✓ AIリスク（誤情報・バイアス）の啓蒙

AI Lifecycle Awareness:
  ✓ 使用するAIツールの能力・限界を理解
  ✓ AI出力の批判的評価
```

---

## 3専門化のスキル比較マトリクス

出典: The AI Product Playbook p.177

| スキルエリア | AI-Experiences | AI-Builder | AI-Enhanced |
|------------|---------------|------------|-------------|
| UXリサーチ | ★★★★★ | ★★★ | ★★★ |
| MLOps知識 | ★★ | ★★★★★ | ★★ |
| AI活用ツール | ★★★ | ★★★ | ★★★★★ |
| データエンジニアリング | ★★ | ★★★★ | ★★★ |
| プロンプトエンジニアリング | ★★★★ | ★★★ | ★★★★★ |
| ステークホルダー管理 | ★★★★ | ★★★★ | ★★★★ |
| 倫理・公平性 | ★★★★★ | ★★★ | ★★★ |

---

## AI PM キャリアパス

出典: *AI PM Handbook 2nd Ed.* Ch.19

### 4レベルキャリアロードマップ

```
Level 1: Foundation（基盤構築）
  期間: 0-2年
  フォーカス:
    - AI/MLの基礎理解（コードは不要、概念は必須）
    - 1つの専門化分野での経験積み上げ
    - メンターの確保・コミュニティ参加
  マイルストーン:
    - AI機能を含む製品の0→1リリース経験
    - 技術チームとの効果的な協働を確立
    - AI評価・Evals設計の経験

Level 2: Strategic Growth（戦略的成長）
  期間: 2-5年
  フォーカス:
    - 複数AIプロダクトの同時マネジメント
    - OKR設計・財務計画への参画
    - チームリーダーシップ経験
  マイルストーン:
    - AIプロダクトのGrowth・Scalingの経験
    - ROIの定量的証明
    - クロスファンクショナルチームのリード経験

Level 3: Specializing & Leading（専門化・リード）
  期間: 5-10年
  フォーカス:
    - 3専門化のうち1-2つでのエキスパート化
    - 組織AIロードマップへの戦略的関与
    - 後進の育成・メンタリング
  マイルストーン:
    - AI部門・チームのリード
    - 業界イベントでの発信・Thought Leadership
    - 組織横断的なAI文化の牽引

Level 4: Light for Others（灯台になる）
  期間: 10年+
  フォーカス:
    - 組織・業界全体へのAI戦略的インパクト
    - 次世代PM・リーダーの育成
    - AI倫理・政策への関与
  マイルストーン:
    - VP of Product AI / CPO / AI Strategy Leader
    - 書籍・論文・講演による知識共有
    - 組織のAI成熟度を複数段階引き上げた実績
```

---

## AI PMに必要なスキルセット全体像

出典: *AI PM Handbook 2nd Ed.* Ch.18「A Job Family of Many Hats」

### Technical Proficiency（技術習熟度）
```
Technologist: テクノロジートレンドの継続的な把握
AI Expert: ML/DL/GenAIの実用的理解
Technical Translator: 技術↔ビジネス言語変換能力
Data Steward: データ品質・ガバナンスへの責任感
Data Strategist: データをプロダクト戦略に統合
Quality Controller: AI出力品質の管理・改善
Analyst: データからインサイト抽出
```

### Business Acumen（ビジネス洞察）
```
Strategist: 市場・競合分析・戦略立案
Revenue Driver: AI投資のROI最大化
Partnership Builder: エコシステム・パートナーシップ設計
Innovator: AI新機会の発掘・事業化
Market Researcher: ユーザーニーズ・市場調査
Competitor Analyst: 競合AI製品の分析
```

### Communication（コミュニケーション）
```
Project Manager: AI開発プロジェクトの進行管理
Change Agent: 組織のAI変革推進
Stakeholder Manager: 技術・事業・法務との橋渡し
Educator: チーム・組織へのAI教育
Risk Assessor: AI導入リスクの評価・説明
```

### Leadership（リーダーシップ）
```
Visionary: AI時代のプロダクトビジョン提示
Ethicist: 責任あるAI実践の旗手
Team Leader: 多様な専門家チームの率い方
Storyteller: AI価値を物語で伝える力
AI Whisperer: 技術的AIと人間の橋渡し
```

---

## チームビルディング

### AI PMがチームに求めるもの

```
強いAIチームの構成原則:
1. T字型人材（広いAI理解 × 深い専門性）を中核に置く
2. 技術チームとPMの定期的な「AI知識共有」セッション
3. データサイエンティストとPMのペアリング（週1回の同期）
4. 倫理・法務・セキュリティの早期組み込み（Shift Left）
```

### AI時代のステークホルダーマネジメント

```
経営層への報告:
  - AI投資をビジネス成果（収益・コスト・ユーザー数）で語る
  - 技術的詳細より「AIが解決するビジネス問題」を前面に
  - リスクを隠さず、対策とともに提示

技術チームとの関係:
  - 「なぜ」（ビジネスゴール）を常に共有する
  - ML Engineer・Data Scientistの制約を尊重する
  - 技術的負債を可視化し、優先度付けに参加する

ユーザーとの関係:
  - AI使用を透明に開示する
  - フィードバックを積極的に収集しモデル改善に反映
  - AIミスへの誠実な対応・改善コミュニケーション
```

---

## 自己学習・継続成長のための推奨リソース

```
基礎知識:
  - Coursera: Machine Learning Specialization（Andrew Ng）
  - Google: Responsible AI Practices
  - Fast.ai: Practical Deep Learning for Coders

コミュニティ:
  - AI Product Hub（aiproduct.com）
  - Women in AI
  - Mind the Product

資格:
  - AWS Certified Machine Learning Specialty
  - Google Professional Machine Learning Engineer
  - IAPP CIPT（プライバシー技術者資格）

フォロー推奨:
  - 業界カンファレンス: NeurIPS, ICML, AI4People
  - ニュースレター: The Batch（deeplearning.ai）、Import AI
```
