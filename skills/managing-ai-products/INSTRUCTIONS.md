# AI/Growth プロダクトマネジメント ガイド

## 概要

このスキルは、AIプロダクトマネージャー（AI PM）が直面する意思決定を支援する実践的な参照ガイドだ。
AI/MLの基礎知識から組織戦略、グロースメトリクス、責任あるAI、キャリア設計まで、5冊の書籍から抽出した
フレームワークと実践知識を体系化している。

**対象読者**: AI機能を担当するPM、グロースPM、AI-nativeプロダクトを構築するPM

---

## 1. AIプロダクトマネジメントの基礎

### AI vs ML の区別（PMにとって重要な理由）

| 特性 | AI（人工知能） | ML（機械学習） |
|------|--------------|--------------|
| スコープ | 広義：知的なシステムを作る目標 | 具体的：データから学習する手法 |
| 学習 | 必須ではない | 本質的。経験で改善 |
| PM上の含意 | 実装シンプル・適応性低 | データ・イテレーションが必要 |

AI ⊃ ML ⊃ Deep Learning（入れ子構造）

### AI PMが持つべき4つのマインドセット

1. **Feasibility判断**: ルールベースAI vs データ駆動MLの見極め
2. **Resource Allocation**: MLはデータ・ラベリング・エンジニアリング時間を要する
3. **Iteration Cycles**: MLモデルは継続的に改善・劣化（model drift）する
4. **User Expectations**: ML出力はルールベースより予測困難——丁寧な期待値管理が必要

### AI PMの4大誤解（Myths vs Reality）

| 誤解（Myth） | 現実（Reality） |
|------------|----------------|
| 「AIは魔法の黒箱」 | 成功はデータ品質・アルゴリズム選択・問題定義次第。PMが影響できる |
| 「完璧なデータが必要」 | 小さく精度の高いデータセットから始められる（AI MVP） |
| 「AIはユーザーリサーチ不要にする」 | AIはwhatを教えるが、whyはわからない。定性リサーチは必須 |
| 「AI機能は一度作れば完成」 | モデルはliving system。常に監視・再訓練・保守が必要 |

---

## 2. AIプロダクトライフサイクル（8段階）

出典: *The AI Product Playbook* (Nika & Granados, 2026) Ch.4

```
1. Problem Definition    → なぜ作るか？ビジネスゴールの明確化
2. Data Collection       → どんなデータが必要か？データ探索
3. Data Preprocessing    → データのクリーニング・変換・正規化
4. Feature Engineering   → モデルへの入力を設計する
5. Model Selection & Training → アルゴリズム選択と学習
6. Model Evaluation & Tuning  → 品質確認・パラメータ調整
7. Deployment & Monitoring    → 本番稼働・健全性監視
8. Retraining & Maintenance   → モデル劣化への対応・継続改善
```

各段階でのPMの役割 → **Read references/AI-LIFECYCLE.md**

---

## 3. AI PM 3つの専門化

出典: *The AI Product Playbook* (Nika & Granados, 2026) Part II

### AI-Experiences PM（UXフォーカス）
**担当領域**: AIがユーザーと接触する界面を設計
**核心スキル**: UXリサーチ、AI UX原則、期待値管理、説明可能性
**代表的な業務**: チャットボット・推薦システム・生成AIフィーチャーのPM

### AI-Builder PM（インフラフォーカス）
**担当領域**: AIシステムの基盤・プラットフォームを構築
**核心スキル**: MLOps、データパイプライン、モデル評価、テクニカル深度
**代表的な業務**: MLプラットフォーム・データ基盤・APIのPM

### AI-Enhanced PM（AI活用フォーカス）
**担当領域**: PMの業務そのものをAIツールで強化
**核心スキル**: AI活用プロセス設計、意思決定オートメーション、ツール統合
**代表的な業務**: AI使用率・生産性メトリクスの設計、PMワークフロー自動化

3専門化の詳細比較（スキルセット・キャリアパス） → **Read references/TEAM-CAREER.md**

---

## 4. グロースPMフレームワーク

出典: *Growth Product Manager's Handbook* (Eve Chen, 2024)

### RADフレームワーク（Growth PMの核心）

グロースPMは **Retention（保持）・Acquisition（獲得）・Development（顧客開発）** を
戦略的に組み合わせてビジネス成長を駆動する。

- **Retention**: 既存ユーザーを維持する（最も費用対効果が高い）
- **Acquisition**: 新規ユーザーを獲得する
- **Development**: アクティベーション・拡張収益・クロスセル

### PLG（Product-Led Growth）の4モデル

| モデル | 成長メカニズム | 代表的プロダクト |
|--------|-------------|----------------|
| **Product Engagement** | 高頻度利用が習慣化 → 離脱困難 | Slack, Notion |
| **Viral Loop** | ユーザーが他ユーザーを招待 | Dropbox, WhatsApp |
| **Expansion** | ユーザーが増えるほど価値増加 | GitHub, Figma |
| **Platform Ecosystem** | 外部開発者がエコシステム構築 | Salesforce, Stripe |

グロースメトリクス詳細・実験設計8ステップ → **Read references/GROWTH-METRICS.md**

---

## 5. メトリクス設計

### HEARTフレームワーク（Google発）

出典: *The Resilient Product Manager* (Kaelin Rhun)

| 指標 | 意味 | 測定例 |
|------|------|--------|
| **H**appiness | ユーザー満足度 | NPS、CSAT、評価レーティング |
| **E**ngagement | 関与深度 | DAU/MAU比、セッション時間 |
| **A**doption | 新機能採用率 | 新規フィーチャーの利用率 |
| **R**etention | 継続利用 | 7日/30日リテンション率 |
| **T**ask Success | タスク達成率 | エラー率・完了率 |

### North Star Metric設計

```
1. ビジネスゴールの定義（収益/成長/エンゲージメント）
2. ユーザーが価値を感じる瞬間（Aha Moment）の特定
3. その瞬間を最もよく代表する単一指標の選定
4. North Starにつながる先行指標（Leading Indicators）の設計
```

HEARTとOKR・KPIの統合設計 → **Read references/GROWTH-METRICS.md**

---

## 6. 責任あるAI

出典: *The AI Product Playbook* (Nika & Granados, 2026) Ch.11

### AIバイアスの種類

| バイアス種類 | 発生箇所 | PM対策 |
|------------|---------|--------|
| **Training Data Bias** | 学習データの偏り | 多様なデータソース確保 |
| **Algorithmic Bias** | モデル設計の偏り | 公平性メトリクスの定義 |
| **Measurement Bias** | 測定方法の不公平 | Protected Classesの考慮 |
| **Human Bias** | 評価者の主観 | 評価者の多様性確保 |

### 倫理的AI構築チェックリスト（要約）

- [ ] Protected Classes（人種・性別・宗教等）への影響を評価したか
- [ ] 公平性メトリクスを定義・測定しているか
- [ ] モデルの判断に説明可能性があるか
- [ ] ユーザーにAI利用を開示しているか
- [ ] GDPR/AI Act等の規制要件を満たしているか

詳細な倫理チェックリスト・法的コンプライアンス → **Read references/RESPONSIBLE-AI.md**

---

## 7. データ品質とAI戦略

出典: *AI Meets Strategy* (Srivastava et al., 2026)

### AI実装失敗の根本原因（業界統計: 85%失敗率）

AIプロジェクトが失敗する主な理由は技術的な問題ではなく、**アライメントの崩壊**だ：

1. チーム間のゴール不整合
2. サイロ化・古いデータによるモデル訓練
3. 不十分なデータ・テックインフラ
4. 組織全体のAIデータ戦略の欠如

### データオペレーティングモデル（EDGE）

組織のAI-readinessを高めるため、データを戦略的資産として扱う：

- **E**stablish: データガバナンス・ロール・ポリシーの確立
- **D**esign: データパイプライン・アーキテクチャの設計
- **G**overn: 品質・アクセス・セキュリティの継続監視
- **E**xecute: ビジネス目標に紐付いた実行・改善

### データ品質フレームワーク（PROMT）

AIに使えるデータの品質を評価する5次元：

- **P**rovenance（出所）: データの起源・信頼性
- **R**elevance（関連性）: ビジネス問題との関連度
- **O**bservability（観測可能性）: データパイプラインの可視性
- **M**etrics（指標）: 品質を数値で継続測定
- **T**imeliness（適時性）: データの鮮度・更新頻度

詳細な戦略フレームワーク → **Read references/AI-STRATEGY.md**

---

## 8. MLOps（MLOps概要）

出典: *The AI Product Playbook* (Nika & Granados, 2026) Ch.10

### MLOpsとは

機械学習のCI/CD——モデルを本番環境で信頼性高く運用するための実践体系。

**主要コンポーネント（AI Production Line）**:

```
データパイプライン → モデル訓練 → 評価 → パッケージング
    ↑                                           ↓
監視・再訓練 ← 本番モニタリング ← デプロイメント
```

### PMが知るべきMLOps用語集

| 用語 | 意味 | PMの関心ポイント |
|------|------|----------------|
| **Model Drift** | 時間とともにモデル精度が低下 | 再訓練サイクルをロードマップに組む |
| **Shadow Deployment** | 本番に影響せずテスト | リスク低減のデプロイ戦略 |
| **A/B Testing（AI版）** | モデルバージョン比較 | ビジネスメトリクスで評価 |
| **Feature Store** | 特徴量の再利用可能なライブラリ | データ効率・一貫性向上 |
| **Model Registry** | モデルのバージョン管理 | 本番/ステージングの追跡 |

---

## 9. AI機会評価と ROI

出典: *The AI Product Playbook* (Nika & Granados, 2026) Ch.8-9

### AI機会特定の5手法

1. **AI Feature Storming**: ユーザーの問題点を全洗い出し、AIで解決できるものを特定
2. **AI Scenario Planning**: 理想のユーザー体験からバックキャストしてAI必要性を評価
3. **Data Opportunity Mapping**: 保有データ資産からAI機会を発掘
4. **AI Capability Alignment**: 既存AI/MLケイパビリティと問題をマッチング
5. **AI-Powered Feature Reverse Engineering**: 競合・類似製品の成功AIフィーチャーを分析

### ROI算出の9ステップ

1. ビジネスゴールの定義
2. AI/MLアプリケーションと解決策の定義
3. データソースと特徴量エンジニアリングの特定
4. メトリクス選択（成功の定義）
5. ベースラインメトリクスの設定
6. モデル訓練と評価の実施
7. A/Bテストによる実世界インパクト測定
8. 結果とROIの算出
9. 長期的なモデル監視・保守

---

## 10. 参照ファイル一覧

| ファイル | 内容 | 参照タイミング |
|---------|------|--------------|
| `references/AI-STRATEGY.md` | Six-Layer AI戦略、EDGEモデル、AI成熟度評価 | AI戦略立案・組織変革時 |
| `references/AI-LIFECYCLE.md` | 8段階詳細、各段階でのPM役割、MLOps | AI製品開発・ロードマップ設計時 |
| `references/GROWTH-METRICS.md` | RAD詳細、PLG4モデル、実験設計、リテンション | グロース戦略・実験設計時 |
| `references/RESPONSIBLE-AI.md` | バイアス種類、倫理チェックリスト、法規制 | AI機能リリース前・監査時 |
| `references/PRODUCT-DESIGN.md` | AI-native UX原則、HEART詳細、スプリント | プロダクト設計・UX改善時 |
| `references/TEAM-CAREER.md` | 3専門化詳細比較、スキルセット、キャリアパス | 採用・育成・キャリア相談時 |
