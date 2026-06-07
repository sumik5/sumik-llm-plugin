# デザイン思考・UXリサーチ実践ガイド

## スキル構成

| セクション | 対象領域 | 主な用途 |
|-----------|---------|---------|
| デザイン思考プロセス（DT-*） | d.school/IDEO 5ステップ・HCDプロセス・チーム協業 | ワークショップ設計・問題定義・プロトタイピング |
| UX実践原則（PRINCIPLES-*） | Consider/Empathize/Define/Research/Design/Validate | フェーズ別チェックリスト・設計判断 |
| UXメソッド実践（PRACTICE-*） | ユーザビリティ評価・ユーザーリサーチ・ジャーニーマップ | 実務での段階的導入手順 |

---

## デザイン思考プロセス（d.school/IDEO 5ステップ）

ユーザー体験を中心に置いた問題解決・価値創造の方法論。「何を作るべきか」を探索するために使う。

```
共感（Empathize）→ 問題定義（Define）→ 発想（Ideate）→ プロトタイプ（Prototype）→ テスト（Test）
```

各ステップは線形ではなく、フィードバックによって反復するプロセス。

### クイックリファレンス

| ツール | フェーズ | 目的 |
|--------|---------|------|
| インタビュー・共感マップ | 共感 | Say/Do/Think/Feel でユーザー深層を収集 |
| タテマエメソッド | 問題定義 | POV を TCS（矛盾・驚き）で鋭くする |
| HMW（How Might We） | 発想 | 課題を「どうすれば？」に変換してアイデアを引き出す |
| 雑っぴんぐ（CEP/CFP/DHP） | プロトタイプ | クイック＆ダーティで検証サイクルを高速化 |
| KPT・カンバン | チーム | ふりかえりと WIP 制限でチーム協業を促進 |

### 詳細リファレンス

| ファイル | 内容 |
|---------|------|
| [DT-DESIGN-THINKING-GUIDE.md](references/DT-DESIGN-THINKING-GUIDE.md) | d.school/IDEO 5ステップ完全ガイド |
| [DT-UX-THEORY.md](references/DT-UX-THEORY.md) | UX理論基盤: UX定義・時間軸分類・利用文脈・認知工学 |
| [DT-DESIGN-PROCESS.md](references/DT-DESIGN-PROCESS.md) | ISO 9241-210 HCDプロセス: 7段階プロセス・忠実度選択 |
| [DT-RESEARCH-METHODS.md](references/DT-RESEARCH-METHODS.md) | リサーチ手法: エスノグラフィ・ペルソナ・ジャーニーマップ・KA法 |
| [DT-DESIGN-EVALUATION-METHODS.md](references/DT-DESIGN-EVALUATION-METHODS.md) | 設計・評価手法: シナリオ法・ユーザビリティテスト・SUS |
| [DT-TEAM-KAIZEN-PROCESS.md](references/DT-TEAM-KAIZEN-PROCESS.md) | チームカイゼン: OODAループ・ダブルダイヤモンド・プロセス可視化 |
| [DT-DATA-DRIVEN-IMPROVEMENT.md](references/DT-DATA-DRIVEN-IMPROVEMENT.md) | データドリブン改善: 定量/定性データ・KGI/KPI・プロトタイプ活用 |
| [DT-TEAM-USER-RESEARCH.md](references/DT-TEAM-USER-RESEARCH.md) | チーム参加型リサーチ: インタビュー実践・軽量UT・ゲリラインタビュー |
| [DT-TEAM-PROTOTYPING.md](references/DT-TEAM-PROTOTYPING.md) | チーム協業プロトタイピング: パラレルトラック・軽量UT設計 |
| [DT-CREATIVE-PROCESS-PATTERNS.md](references/DT-CREATIVE-PROCESS-PATTERNS.md) | クリエイティブプロセスパターン: プロの制作プロセス5ステップ・発想法カタログ・試作サイクル・身体感覚とデザイン |

---

## UX実践原則（100 Principles）

UXデザインの全工程をカバーする100の実践原則。
各フェーズに分類されており、プロジェクトの現在フェーズに応じて参照する。

### フェーズ別インデックス

| フェーズ | 原則番号 | テーマ | ファイル |
|---------|---------|--------|---------|
| **Consider** | 01–17 | UXの本質・哲学・認知効果・倫理・時間軸 | [PRINCIPLES-CONSIDER.md](references/PRINCIPLES-CONSIDER.md) |
| **Empathize** | 18–37 | アクセシビリティ・多様性・認知・タッチ・文脈 | [PRINCIPLES-EMPATHIZE.md](references/PRINCIPLES-EMPATHIZE.md) |
| **Define** | 38–51 | 要件定義・MVP・ユーザーフロー・情報設計 | [PRINCIPLES-DEFINE.md](references/PRINCIPLES-DEFINE.md) |
| **Research** | 52–63 | リサーチ手法・ペルソナ・競合分析・IA検証 | [PRINCIPLES-RESEARCH.md](references/PRINCIPLES-RESEARCH.md) |
| **Design** | 64–87 | IA・ナビゲーション・タイポグラフィ・アニメーション | [PRINCIPLES-DESIGN.md](references/PRINCIPLES-DESIGN.md) |
| **Validate** | 88–100 | テスト・メトリクス・ローンチ後改善・期待値管理 | [PRINCIPLES-VALIDATE.md](references/PRINCIPLES-VALIDATE.md) |

### 各原則の構造

```
### XX. タイトル

**核心**: 1行で核心メッセージ

- 要点1
- 要点2
- 要点3（あれば）

**If/Then**: If [状況] then [アクション]
```

### 使い方

- **プロジェクト開始前**: Consider（01–17）で哲学的準備を行う
- **ユーザー理解段階**: Empathize（18–37）でユーザー多様性を把握する
- **問題定義段階**: Define（38–51）でスコープと要件を確定する
- **リサーチ計画時**: Research（52–63）で適切な手法を選択する
- **設計段階**: Design（64–87）で具体的なUI設計の判断基準にする
- **テスト・リリース段階**: Validate（88–100）で品質検証と改善計画を立てる
- **特定の問いに答えたいとき**: If/Then 形式で該当する状況の原則を検索する

---

## UXメソッド実践

UXデザインを「知る」から「やる」へ。実際のWeb制作現場でUXメソッドを段階的に導入するための実践ガイド。

### 理論層（DT-*）と実践層（PRACTICE-*）の使い分け

| 層 | プレフィックス | 性格 | 使うとき |
|---|---|---|---|
| **理論層** | `DT-*` | 概念・フレームワーク・設計プロセス | 「UXとは何か」「なぜこの手法か」を理解したいとき |
| **実践層** | `PRACTICE-*` | ステップバイステップ手順・テンプレート・導入戦略 | 「実際にどうやるか」「明日から始めるには」 |

**補完関係**: DT-* で理論的根拠を把握し、PRACTICE-* で具体的な実施手順を参照する。

---

### 3段階導入フレームワーク

UXメソッドを組織に浸透させるための段階的アプローチ。いきなり「全部やる」ではなく、実績を積み重ねながら範囲を広げる。

#### Level 1: こっそり練習

- 個人の作業の中でUXの視点を静かに取り入れる
- クライアントへの説明不要。制作物の品質を上げることが目的
- 推奨メソッド: ユーザビリティ評価（専門家評価）・ペーパープロトタイプ

#### Level 2: 一部業務でトライアル

- 特定のプロジェクトや工程でUXメソッドを試験的に導入
- 「こういう方法を試してみたい」と社内で共有する段階
- 推奨メソッド: ユーザーリサーチ（少人数）・構造化シナリオ法

#### Level 3: クライアント巻き込み

- クライアントをステークホルダーとしてUXプロセスに参加させる
- UX活動を提案・受注の一部として位置づける
- 推奨メソッド: カスタマージャーニーマップワークショップ・組織導入戦略

---

### メソッド一覧と選択ガイド

| メソッド | 難易度 | 適用フェーズ | Light Case | Heavy Case | 詳細 |
|---------|--------|------------|-----------|-----------|------|
| UX基礎・マインドセット | ★☆☆ | 全フェーズ | UX視点の獲得・自己評価 | チーム全体へのUX啓蒙 | [PRACTICE-UX-BASICS.md](references/PRACTICE-UX-BASICS.md) |
| ユーザビリティ評価 | ★★☆ | 設計〜改善 | 専門家評価（1人）・チェックリスト点検 | 5ユーザー以上のテスト・NEM分析 | [PRACTICE-USABILITY-EVAL.md](references/PRACTICE-USABILITY-EVAL.md) |
| プロトタイピング | ★☆☆ | 設計・検証 | ペーパープロト（1時間以内） | 高忠実度プロト・ユーザビリティテスト | [PRACTICE-PROTOTYPING.md](references/PRACTICE-PROTOTYPING.md) |
| 構造化シナリオ法 | ★★☆ | 要件定義・設計 | バリューシナリオのみ | 3層（バリュー→アクション→オペレーション）完全作成 | [PRACTICE-SCENARIO-METHOD.md](references/PRACTICE-SCENARIO-METHOD.md) |
| ユーザーリサーチ | ★★★ | 課題発見・共感 | ゲリラインタビュー（5〜10分） | 感情曲線インタビュー・弟子入りリサーチ | [PRACTICE-USER-RESEARCH.md](references/PRACTICE-USER-RESEARCH.md) |
| カスタマージャーニーマップ | ★★☆ | 課題発見・改善 | 既存データから個人作成 | チームワークショップ・課題抽出 | [PRACTICE-JOURNEY-MAP.md](references/PRACTICE-JOURNEY-MAP.md) |
| 共感ペルソナ | ★★☆ | 要件定義 | リサーチなし仮説ペルソナ | データ収集+チーム共同作成 | [PRACTICE-EMPATHY-PERSONA.md](references/PRACTICE-EMPATHY-PERSONA.md) |
| 組織へのUX導入 | ★★★ | 組織変革 | 個人実践→社内発表 | ステークホルダーマップ+段階的導入計画 | [PRACTICE-ORG-ADOPTION.md](references/PRACTICE-ORG-ADOPTION.md) |

---

### Light Case / Heavy Case の使い分け

**Light Case**（最小投資で始める）:
- 時間・リソースが限られている
- 初めてそのメソッドを試す
- クライアントへの説明コストをかけたくない
- 実績を積むためのリハーサルとして

**Heavy Case**（本格的に実施する）:
- プロジェクト予算・スケジュールに余裕がある
- ステークホルダーの合意が得られている
- 重要なプロジェクトで品質を担保したい
- UX活動の価値を定量的に示したい場合

**原則**: まず Light Case で実績を作り、信頼と知見が蓄積されたら Heavy Case に移行する。

---

### DT-* リファレンスとの連携ポイント

| やりたいこと | PRACTICE-* | 理論的根拠（DT-*） |
|------------|-----------|-----------------|
| 評価基準を理解したい | PRACTICE-USABILITY-EVAL.md | [DT-DESIGN-EVALUATION-METHODS.md](references/DT-DESIGN-EVALUATION-METHODS.md) |
| ユーザーリサーチ手法を選びたい | PRACTICE-USER-RESEARCH.md | [DT-RESEARCH-METHODS.md](references/DT-RESEARCH-METHODS.md) |
| プロトタイプの忠実度を決めたい | PRACTICE-PROTOTYPING.md | [DT-DESIGN-PROCESS.md](references/DT-DESIGN-PROCESS.md) |
| ペルソナの作り方を知りたい | PRACTICE-EMPATHY-PERSONA.md | [DT-RESEARCH-METHODS.md](references/DT-RESEARCH-METHODS.md) |
| チームにUXを広めたい | PRACTICE-ORG-ADOPTION.md | [DT-TEAM-KAIZEN-PROCESS.md](references/DT-TEAM-KAIZEN-PROCESS.md) |

---

## 他スキルへの参照

| 参照先スキル | 参照タイミング |
|------------|--------------|
| `designing-ux` | UIデザインガイドライン・グラフィックデザイン・インターフェイス哲学・UXエレメント5段階モデル |
| `designing-ai-experiences` | AI体験のUXフレームワーク・AIインターフェース設計 |
| `applying-behavior-design` | 行動変容設計（習慣化、CREATE Action Funnel） |
| `building-design-systems` | デザインシステム構築・ガバナンス |
