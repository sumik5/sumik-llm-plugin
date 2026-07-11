---
name: architecting-security
description: >-
  Artifact-based methodology for designing security architecture for hybrid and multi-cloud
  systems across the solution lifecycle (Plan, Design, Build, Run, Close): artifact dependency
  framework, threat modeling (STRIDE, attack trees, LINDDUN), zero trust integration, data-centric
  security (data classification, information asset register), compliance and governance mapping,
  security requirements engineering, shared responsibility models, and architecture decision
  records. Use when designing an information system's security, threat modeling, planning zero
  trust, producing security architecture artifacts, or defining a security architect's deliverables.
  For infrastructure and microservices patterns use architecting-infrastructure; for secure-by-
  default coding use devkit:software-security; for OWASP code security use devkit:securing-code; for
  authorization models (ABAC/ReBAC/Cedar) use implementing-dynamic-authorization; for cloud-vendor
  security use developing-aws or developing-google-cloud instead.
---

# セキュリティアーキテクチャ設計（architecting-security）

情報システムにセキュリティを組み込むための**アーティファクト駆動方法論**。ソリューションライフサイクル全体（Plan / Design / Build / Run / Close）を通じて、成果物を段階的に積み重ねながら堅牢なセキュリティアーキテクチャを設計する体系的手法を提供する。4つの基礎技法（データ中心セキュリティ・脅威モデリング・Zero Trust・コンプライアンス管理）を統合することで、個別技法を並列適用する際に生じる一貫性の欠如を防ぐ。

---

## このスキルを使うタイミング

- 新規または改修する情報システムのセキュリティアーキテクチャを設計するとき
- 脅威モデリング（STRIDE / アタックツリー / LINDDUN）を実施するとき
- Zero Trust 導入計画を立案・設計するとき
- システムコンテキスト図・コンポーネント図・デプロイメント図などのセキュリティ成果物を作成するとき
- セキュリティアーキテクトとしての成果物定義・RACI 整理を行うとき
- ハイブリッドクラウド・マルチクラウド環境の責任共有モデルを整理するとき
- コンプライアンス要件（ISO/IEC 27001・PCI DSS・個人データ保護規制等）を設計にトレースするとき

---

## 全体像：ソリューションライフサイクルと主要成果物

| フェーズ | 主な活動 | 主要成果物 | 対応 references |
|---------|---------|-----------|-----------------|
| **Plan** | エンタープライズコンテキスト収集・要件定義 | エンタープライズコンテキスト文書・ユースケース・ユーザーストーリー・要件トレーサビリティマトリクス | R5・R6 |
| **Design** | システムコンテキスト・コンポーネント設計・インフラ設計・パターン選択 | システムコンテキスト図・情報資産登録簿・コンポーネントアーキテクチャ図・脅威モデル・デプロイメント図・クラウドアーキテクチャ図・ADR | R2・R4・R7 |
| **Build** | セキュア開発・保証 | RAIDログ・テスト戦略・テスト計画 | R8 |
| **Run** | セキュリティ運用 | RACI・プロセス/手順書・脅威検知ユースケース・インシデント対応ランブック・脅威トレーサビリティマトリクス | R8 |
| **Close** | 継続的アーキテクチャ・総括 | 方法論の振り返り・改善記録 | R1・R8 |

---

## アーティファクトフレームワーク（6グループ）

セキュリティアーキテクチャの成果物群を以下の6グループに分類する。各グループの成果物は **アーティファクト依存関係**（上流成果物が下流成果物のインプット）に従って順序付けられる。

| グループ | 概要 | 主な成果物例 |
|---------|------|------------|
| **エンタープライズコンテキスト** | 組織外部の法規制・業界標準・内部ポリシー・エンタープライズアーキテクチャ | コンプライアンス要件・ガイディング原則 |
| **要件** | 機能要件・非機能要件・品質特性・制約 | ユースケース・ユーザーストーリー・非機能要件定義・要件トレーサビリティマトリクス |
| **アーキテクチャ** | システム境界から展開アーキテクチャまでのトップダウン分解 | システムコンテキスト図・コンポーネント図・デプロイメント/クラウドアーキテクチャ図・ADR |
| **オペレーション** | 実稼働後の継続的セキュリティ担保 | RACI・プロセス図・脅威検知ユースケース・ランブック |
| **ガバナンス** | アーキテクチャ開発全段階を支えるリスク管理 | RAIDログ・アーキテクチャ決定記録 |
| **アシュアランス** | 設計・実装の有効性を確認する活動 | テスト計画・侵入テスト・コンプライアンス監査 |

> **詳細度の調整原則**: プロジェクトの規制対象度とリスク許容度に応じて成果物の深さを調整する。高規制環境（例: 監査対応が必須の金融・医療系）は詳細文書を必須とし、低リスク環境では「ちょうど十分（just enough）」な成果物に絞る。
>
> **所有権の考え方**: インフラ・アプリケーションアーキテクトが一部の成果物を所有し、セキュリティアーキテクトはコンテンツ追記または所有者不在分の担当を引き受ける。運用成果物は自分で作成しないケースもあるが、デリバリー責任は負う。

---

## 4つの基礎技法（要約）

これら4技法は独立して使われることが多いが、本方法論では統合して適用する。

### データ中心セキュリティ（Data-Centric Security）
データがシステムを通過するフロー（転送中・保存時・使用中）に着目し、各ステップで必要なセキュリティコントロールを特定する技法。取引フローと集約処理の把握から始まり、データの機密度分類・情報資産登録簿の整備へと続く。→ **[DATA-CENTRIC-SECURITY.md](references/DATA-CENTRIC-SECURITY.md)**

### 脅威モデリング（Threat Modeling with Secure by Design）
設計段階でシステム固有のリスクを識別し、リスクベースのセキュリティコントロールを組み込む技法。信頼境界特定 → 資産・脅威アクター特定 → STRIDE / アタックツリー / LINDDUN による脅威分析 → コントロール特定 → 優先順位付けの手順で進める。→ **[THREAT-MODELING.md](references/THREAT-MODELING.md)**

### Zero Trust アーキテクチャ（Zero Trust Architecture）
「決して信頼せず、常に検証する（never trust, always verify）」原則に基づき、ネットワーク境界への暗黙的信頼を排除する設計方針。継続的認証・適応型アクセス制御・最小権限・マイクロセグメンテーション・全域暗号化・脅威検知と対応の6実践で構成される。→ **[ZERO-TRUST-ARCHITECTURE.md](references/ZERO-TRUST-ARCHITECTURE.md)**

### コンプライアンス管理（Compliance Management）
外部の法規制・業界標準（ISO/IEC 27001・PCI DSS・NIST CSF 等）と組織内部ポリシーへの準拠を、設計から運用までの全段階でトレースする枠組み。**コンプライアンスはセキュリティの代替ではない**—セキュリティへの注力とトレーサビリティによる準拠証明の両立が重要。→ **[COMPLIANCE-AND-GOVERNANCE.md](references/COMPLIANCE-AND-GOVERNANCE.md)**

---

## セキュリティアーキテクトの役割

セキュリティ設計は「セキュリティアーキテクト専用」ではなく、幅広い役割が担う。

| 役割 | 主な責務 |
|------|---------|
| **エンタープライズセキュリティアーキテクト** | 組織全体のセキュリティ戦略・ガイディング原則・エンタープライズアーキテクチャの策定 |
| **ソリューションセキュリティアーキテクト** | 特定プロジェクトのセキュリティアーキテクチャ設計（全成果物を主導） |
| **プロダクトセキュリティアーキテクト** | セキュリティ製品・サービスのアーキテクチャ設計 |
| **アドバイザリ / コンサルティングセキュリティアーキテクト** | 他アーキテクトへのセキュリティ設計支援（T字型スキル：深いセキュリティ知識 ＋ 広いインフラ・アプリ知識） |
| **インフラ・アプリケーションアーキテクト** | 専任セキュリティアーキテクトがいない場合に自ら統合セキュリティ設計を担う |
| **セキュリティチャンピオン** | Agile / DevSecOps 環境でアーキテクト思考とエンジニアリングスキルを兼備し開発者に助言 |

> 各役割の成果物への関与度（リード / 支援 / 確認）は文脈（組織・プロジェクト規模・規制環境）に応じて変動する。RACI による明確化が重要（詳細: [ARTIFACT-METHOD.md](references/ARTIFACT-METHOD.md)）。

---

## 章×技法マッピング（全方法論のナビゲーション）

本方法論が扱う技法と対応する成果物の全体一覧。

| フェーズ | 技法 | 主要成果物 |
|---------|------|-----------|
| Plan（エンタープライズコンテキスト） | エンタープライズセキュリティアーキテクチャ | セキュリティドメイン図・コントロールマッピング・RAIDログ |
| Plan（要件） | ユースケース・ジャーニーマップ | ユースケース・ジャーニーマップ |
| Plan（要件） | ユーザーストーリー・スイムレーン | ユーザーストーリー・スイムレーン図・職務分掌マトリクス |
| Plan（要件） | 非機能要件定義 | 非機能要件リスト・要件トレーサビリティマトリクス |
| Design（システムコンテキスト） | システムコンテキスト図・情報資産 | システムコンテキスト図・情報資産登録簿 |
| Design（アプリケーション） | コンポーネント図・データフロー図 | コンポーネントアーキテクチャ図・DFD・シーケンス図 |
| Design（アプリケーション） | 脅威モデリング（高レベル） | 脅威モデル文書 |
| Design（インフラ） | 共有責任図 | 共有責任スタック図 |
| Design（インフラ） | デプロイメント / クラウドアーキテクチャ図 | デプロイメントアーキテクチャ図・クラウドアーキテクチャ図 |
| Design（インフラ） | 脅威モデリング（インフラレベル） | 脅威モデル文書（インフラ版） |
| Design（パターン・決定） | アーキテクチャパターン・ADR | デプロイ可能アーキテクチャ・ADR |
| Build | RAIDログ・テスト計画 | RAIDログ・テスト戦略・テスト計画 |
| Run | RACI・プロセス | RACI表・プロセス図・手順書・作業指示書 |
| Run | 脅威検知・インシデント対応 | 脅威検知ユースケース・インシデント対応ランブック・脅威トレーサビリティマトリクス |

---

## 意思決定の分岐点（使用時に確認すべき項目）

本スキルで設計を進める際、以下が不明な場合は **AskUserQuestion** で確認してから作業を開始する（自明な場合は推論で進める）。

| 確認タイミング | 質問 | 影響する成果物 |
|-------------|------|--------------|
| **設計開始時** | デプロイ形態は？（パブリック / ハイブリッド / プライベート / マルチクラウド） | 責任共有図・クラウドアーキテクチャ図（R7） |
| **コンテキスト定義時** | 適用されるコンプライアンス要件は？（PCI DSS / 個人データ保護規制 / 医療情報 / 金融規制 / 特になし） | コントロールマッピング・要件カタログ（R5・R6） |
| **要件段階** | 組織のリスク許容度・規制対象度は？（高規制: 詳細文書必須 / 中 / 低リスク: 軽量成果物） | 全成果物の詳細度（R1 調整原則） |
| **クラウド設計時** | クラウドサービスモデルは？（IaaS / PaaS / SaaS / 混在） | 責任共有スタックの境界（R7） |
| **脅威モデリング時** | 重視する脅威観点は？（セキュリティ全般: STRIDE / 攻撃経路: アタックツリー / プライバシー: LINDDUN / 複合） | 脅威モデルの手法選択（R2） |
| **初期検証段階** | 初期検証の狙いは？（技術検証: PoC / 市場価値検証: MVP） | 初期スコープ・アーキテクチャ思考の適用範囲（R1） |

---

## QAチェックリスト運用の原則

各成果物（アーティファクト）には**QAチェックリスト**を設けることで品質と一貫性を保証する。

- チェックリストは成果物の「十分な品質」を確認するための最低基準であり、全項目を機械的に消化するものではない
- プロジェクトの規制環境・リスクレベルに応じてチェック項目の深さを調整する（高規制環境では全項目、低リスク環境では代表項目のみ）
- 演習問題の設問・解答をそのまま転記するのではなく、実務で再利用可能な汎用チェックリスト形式に落とし込む
- QAチェックリストの例は各 references ファイル内に掲載

---

## references ナビゲーション

| ファイル | 内容 | 主な用途 |
|---------|------|---------|
| [ARTIFACT-METHOD.md](references/ARTIFACT-METHOD.md) | アーティファクト駆動設計の全体論・ライフサイクル5フェーズ・役割/RACI・PoC vs MVP・継続的アーキテクチャ | 方法論の全体像を把握したい時・役割整理時 |
| [THREAT-MODELING.md](references/THREAT-MODELING.md) | 脅威モデリングプロセス（信頼境界→STRIDE/アタックツリー/LINDDUN→コントロール→優先順位付け）・脅威トレーサビリティ | 脅威モデルを作成する時 |
| [ZERO-TRUST-ARCHITECTURE.md](references/ZERO-TRUST-ARCHITECTURE.md) | Zero Trust 基礎・NIST SP 800-207 コアコンポーネント・継続的認証・適応型アクセス制御・最小権限・マイクロセグメンテーション・ソリューション選択 | Zero Trust 設計時 |
| [DATA-CENTRIC-SECURITY.md](references/DATA-CENTRIC-SECURITY.md) | データ保護・データセキュリティライフサイクル・データ分類・情報資産登録簿・アクター×ユースケース×データマッピング | データ分類・情報資産整理時 |
| [COMPLIANCE-AND-GOVERNANCE.md](references/COMPLIANCE-AND-GOVERNANCE.md) | コンプライアンス管理・外部コンテキスト（法規制・ISO/IEC 27001・NIST CSF）・内部コンテキスト・エンタープライズセキュリティアーキテクチャ・RAIDログ | コンプライアンス要件整理・ガバナンス設計時 |
| [REQUIREMENTS-ENGINEERING.md](references/REQUIREMENTS-ENGINEERING.md) | 機能/非機能要件・品質特性・ユースケース・ジャーニーマップ・スイムレーン図・職務分掌マトリクス・要件トレーサビリティマトリクス | 要件定義・精緻化時 |
| [SYSTEM-CONTEXT-AND-COMPONENTS.md](references/SYSTEM-CONTEXT-AND-COMPONENTS.md) | システムコンテキスト図・コンポーネントアーキテクチャ（アクター特定・インターフェース記述・データフロー識別） | システム設計の起点・作図時 |
| [CLOUD-INFRA-AND-PATTERNS.md](references/CLOUD-INFRA-AND-PATTERNS.md) | 責任共有モデル・インフラセキュリティ・アーキテクチャパターン（N層/ハブ&スポーク等）・デプロイ可能アーキテクチャ・ADR | クラウド・インフラ設計時 |
| [BUILD-RUN-OPERATIONS.md](references/BUILD-RUN-OPERATIONS.md) | セキュア開発ライフサイクル・RAIDログ運用・テスト戦略・セキュリティ運用（RACI・手順書・作業指示・ランブック）・継続的アーキテクチャ | Build/Run フェーズの運用設計時 |

---

## 隣接スキルへの誘導

| 目的 | 使うべきスキル |
|------|-------------|
| インフラ・マイクロサービスのパターン設計（HA/DR・スケーリング等） | `cloud:architecting-infrastructure` |
| セキュアコーディング（入力値検証・SAST・依存関係管理） | `devkit:software-security` |
| OWASP トップ10対応・コードレベルのセキュリティ | `devkit:securing-code` |
| ABAC / ReBAC / Cedar による認可モデル実装 | `cloud:implementing-dynamic-authorization` |
| AWS 固有のセキュリティサービス（IAM・GuardDuty・KMS 等） | `cloud:developing-aws` |
| Google Cloud 固有のセキュリティサービス | `cloud:developing-google-cloud` |

ベンダー非依存のクラウドセキュリティ知識体系（CCSP 6ドメイン: 基礎/データ/インフラ/アプリ/運用/GRC/法規制）は `securing-cloud` を参照。
