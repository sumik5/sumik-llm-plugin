# securing-cloud 実行ガイド

ベンダー非依存のクラウドセキュリティ知識体系。CCSP（Certified Cloud Security Professional・ISC2 管理）の 6 ドメイン構成に沿って、クラウドワークロードの保護・セキュリティ統制の設計・プロバイダー評価・認定学習を支援する。個別クラウドベンダーの製品知識ではなく、マルチクラウド前提で通用する上位概念（CIA トライアド・IAM・暗号化・データライフサイクル等の情報セキュリティ基礎をクラウドへ適用する能力）を扱う。

## 使い方（3 ステップ）

1. **タスクのドメインを特定する** — 下の「CCSP 6 ドメインマップ」でタスクが属するドメインを見極める
2. **references/ へルーティングする** — 「ドメイン × references ルーティング表」で該当ファイルを読み込む
3. **最重要原則を常に前提に置く** — 特に「共有責任モデル」は全ドメイン共通の前提（本ファイル末尾に要約）

---

## CCSP 6 ドメインマップ

### ドメイン全体像

| # | ドメイン | 焦点 | 平均出題比重 |
|---|---------|------|------------|
| 1 | Cloud Concepts, Architecture, and Design | クラウドの定義・参照アーキテクチャ・設計原則 | 17% |
| 2 | Cloud Data Security | データライフサイクル全体の保護 | 20% |
| 3 | Cloud Platform and Infrastructure Security | 物理〜仮想基盤・データセンター・BCP/DR | 17% |
| 4 | Cloud Application Security | SDLC・脅威モデリング・アプリ層 IAM | 17% |
| 5 | Cloud Security Operations | 基盤実装・IT サービス管理・SOC/検知対応 | 16% |
| 6 | Legal, Risk, and Compliance | 法規制・プライバシー・監査・リスク・契約 | 13% |

比重は平均値であり個々の試験フォームでは変動しうる。

### Domain 1: Cloud Concepts, Architecture, and Design

| トピック群 | 主要項目 |
|-----------|---------|
| 基礎概念 | クラウドの定義、ロール（customer / provider / broker 等）と各ロールの責任 |
| サービス/展開モデル | サービスカテゴリと提供技術、public / private / hybrid / community / multicloud |
| 参照アーキテクチャ | クラウド活動・ケイパビリティ・カテゴリ、関連技術との相互作用 |
| セキュリティ概念 | 暗号化、IAM、ネットワークセキュリティ、共通脅威、仮想化セキュリティ、セキュリティハイジーン |
| ビジネス整合 | BIA、事業継続、機能的セキュリティ要件、ベンダー vs 顧客の責任分界（Shared Responsibility Model） |
| 評価 | 各種セキュリティフレームワークの理解、業界標準基準によるクラウドプロバイダー評価 |

### Domain 2: Cloud Data Security

| トピック群 | 主要項目 |
|-----------|---------|
| データ基礎 | データライフサイクル、データフロー、データ分散（dispersion） |
| ストレージ設計 | データストレージのアーキテクチャ・技術・戦略の設計と実装 |
| 分類と発見 | データディスカバリ（構造化・半構造化）、ビジネス要件に基づく分類設計 |
| 権利管理 | IRM（Information Rights Management）の設計・実装 |
| 保持と廃棄 | 保持要件、アーカイブ、適切なデータ破棄、リーガルホールド対応 |
| 追跡性 | データ移動の監査証跡、ロギング、chain of custody、否認防止（nonrepudiation） |

### Domain 3: Cloud Platform and Infrastructure Security

| トピック群 | 主要項目 |
|-----------|---------|
| 基盤構成要素 | 物理環境、仮想環境、ネットワーク/通信、コンピュート、ストレージ、管理プレーン |
| データセンター設計 | 論理・物理・環境設計、レジリエンス（回復性）の織り込み |
| 脆弱性・リスク | 脆弱性管理プログラム、設計/実装に紐づくビジネスリスクの特定 |
| BCP/DR | 事業継続計画・災害復旧計画の設計 |
| セキュリティ統制 | 物理/環境保護、システム・ストレージ・通信統制、識別/認証/認可、統制の有効性を検証する監査メカニズム |

### Domain 4: Cloud Application Security

| トピック群 | 主要項目 |
|-----------|---------|
| SDLC | セキュア開発ライフサイクルの基礎と実装、トレーニングと意識向上の正当化 |
| 脅威モデリング | STRIDE / DREAD / PASTA 等のフレームワーク |
| 脆弱性対策 | OWASP の共通脆弱性リストへの対処、検証済みツール/技術の利用、OSS の検証（上流由来の脆弱性対策） |
| 検証と保証 | セキュリティバリデーション、共通テストプラクティス |
| 設計パターン | WAF、暗号化、サンドボックス、マイクロサービス/コンテナ、ファイアウォール、API ゲートウェイ |
| アプリ層 IAM | フェデレーション、IdP、SSO、MFA、CASB、シークレット管理（アーキテクチャ内コンポーネント間認証の秘密情報を含む） |

### Domain 5: Cloud Security Operations

| トピック群 | 主要項目 |
|-----------|---------|
| 基盤実装 | 物理/論理インフラの構築、ハイパーバイザーの種別差異、TPM / HSM 等のハードウェア保護 |
| デプロイと構成 | IaC によるアプリ展開、セキュアなネットワーク構成（VLAN、DHCP、TLS、VPN） |
| ITSM プロセス | 問題・インシデント・リリース・変更・デプロイ・構成・資産・サービスレベル・キャパシティの各管理 |
| フォレンジック | 証拠収集・管理のためのデジタルフォレンジック支援 |
| コミュニケーション | ベンダー・顧客・パートナー・規制当局等ステークホルダーとの連携 |
| SOC/検知対応 | SOC 運用、ログ収集、ホスト/ネットワーク双方の侵害検知、SIEM による横断的情報集約 |

### Domain 6: Legal, Risk, and Compliance

| トピック群 | 主要項目 |
|-----------|---------|
| 法的要件 | クラウド固有の法的論点、管轄間の要件衝突（データの利用地と保存地の分離）、法的フレームワーク |
| プライバシー | PII / PHI の管轄別定義、GDPR 等の各国プライバシー法 |
| 監査 | 監査要件の理解、ポリシー管理とその実装の監査、クラウド内検証を支える技術 |
| リスク管理 | ERM への組み込み、data owner/controller と data custodian/processor の区別、リスク対応（treatment）の選択、リスクフレームワークとメトリクス |
| 契約・ベンダー管理 | ビジネス要件の理解、ベンダー管理プラクティス、監査権（right to audit）、メトリクス・解約・保証・コンプライアンス条項、サイバーリスク保険の適用 |

---

## ドメイン × references ルーティング表

タスク・質問が属するドメインから、読むべき references/ ファイルへ誘導する。1 ドメインに複数ファイルが対応する場合は「主」を最初に読み、必要に応じて「補」を追加読込する。

| ドメイン | 主 references | 補完 references |
|---------|--------------|----------------|
| **1. Concepts, Architecture, and Design** | [FUNDAMENTALS-AND-MODELS.md](references/FUNDAMENTALS-AND-MODELS.md)（定義・サービス/展開モデル・責任分界・ロール）<br>[ARCHITECTURE-AND-DESIGN.md](references/ARCHITECTURE-AND-DESIGN.md)（暗号技術・IAM・ネットワーク・ゼロトラスト・設計原則・BIA・BC/DR・プロバイダー評価） | [EMERGING-TRENDS.md](references/EMERGING-TRENDS.md)（ゼロトラスト詳細・モダン IAM） |
| **2. Data Security** | [DATA-SECURITY.md](references/DATA-SECURITY.md)（データライフサイクル・分散・ストレージアーキテクチャ・分類/発見・DLP・IRM・保持/廃棄・監査証跡） | [LEGAL-AND-PRIVACY.md](references/LEGAL-AND-PRIVACY.md)（データロケーション規制・リーガルホールド） |
| **3. Platform and Infrastructure Security** | [PLATFORM-INFRASTRUCTURE-SECURITY.md](references/PLATFORM-INFRASTRUCTURE-SECURITY.md)（インフラアーキテクチャ・データセンター物理・IAM・クラウド内ネットワーク・仮想化/ハイパーバイザー） | [ARCHITECTURE-AND-DESIGN.md](references/ARCHITECTURE-AND-DESIGN.md)（BC/DR 設計）<br>[GOVERNANCE-RISK-COMPLIANCE.md](references/GOVERNANCE-RISK-COMPLIANCE.md)（BC/DR ガバナンス面） |
| **4. Application Security** | [APPLICATION-SECURITY.md](references/APPLICATION-SECURITY.md)（アプリ脅威・統制メカニズム・SaaS 利用・Web/API セキュリティ・WAF）<br>[SECURE-DEVELOPMENT.md](references/SECURE-DEVELOPMENT.md)（SDLC・DevSecOps・脅威モデリング・CI/CD ゲート・シフトレフト） | [EMERGING-TRENDS.md](references/EMERGING-TRENDS.md)（クラウドネイティブ・コンテナ） |
| **5. Security Operations** | [SECURITY-OPERATIONS.md](references/SECURITY-OPERATIONS.md)（敵対者タイプ・運用フレームワーク・SOC・ログ/監視・SIEM/SOAR・セキュリティエンジニアリング） | [SECURE-DEVELOPMENT.md](references/SECURE-DEVELOPMENT.md)（IaC・SRE・信頼性メトリクス）<br>[LEGAL-AND-PRIVACY.md](references/LEGAL-AND-PRIVACY.md)（フォレンジック・証拠収集） |
| **6. Legal, Risk, and Compliance** | [GOVERNANCE-RISK-COMPLIANCE.md](references/GOVERNANCE-RISK-COMPLIANCE.md)（ガバナンス・リスクマネジメント・コンプライアンス・ポリシー3層構造）<br>[LEGAL-AND-PRIVACY.md](references/LEGAL-AND-PRIVACY.md)（プライバシー規制・契約/SLA・ベンダー管理・フォレンジック） | [DATA-SECURITY.md](references/DATA-SECURITY.md)（データロケーションと規制） |
| **横断（新潮流）** | [EMERGING-TRENDS.md](references/EMERGING-TRENDS.md)（クラウドネイティブセキュリティ・パスワードレス/ワークロードアイデンティティ・ゼロトラスト・AI/ML セキュリティ） | — |

### タスク別クイックルーティング

| よくあるタスク・質問 | 読むファイル |
|--------------------|-------------|
| IaaS/PaaS/SaaS で誰が何を守るか整理したい | [FUNDAMENTALS-AND-MODELS.md](references/FUNDAMENTALS-AND-MODELS.md) |
| 暗号化方式・鍵管理・IAM の設計判断 | [ARCHITECTURE-AND-DESIGN.md](references/ARCHITECTURE-AND-DESIGN.md) |
| データ分類・DLP・IRM・保持と廃棄の設計 | [DATA-SECURITY.md](references/DATA-SECURITY.md) |
| ハイパーバイザー・仮想化・データセンターの防御 | [PLATFORM-INFRASTRUCTURE-SECURITY.md](references/PLATFORM-INFRASTRUCTURE-SECURITY.md) |
| API セキュリティ・WAF・SaaS 利用時の統制 | [APPLICATION-SECURITY.md](references/APPLICATION-SECURITY.md) |
| DevSecOps・CI/CD セキュリティゲート・IaC | [SECURE-DEVELOPMENT.md](references/SECURE-DEVELOPMENT.md) |
| SOC 構築・SIEM/SOAR・検知と対応 | [SECURITY-OPERATIONS.md](references/SECURITY-OPERATIONS.md) |
| リスク評価・監査・ポリシー体系の整備 | [GOVERNANCE-RISK-COMPLIANCE.md](references/GOVERNANCE-RISK-COMPLIANCE.md) |
| GDPR 等プライバシー法・SLA/契約・フォレンジック | [LEGAL-AND-PRIVACY.md](references/LEGAL-AND-PRIVACY.md) |
| コンテナ/クラウドネイティブ・ゼロトラスト・AI/ML | [EMERGING-TRENDS.md](references/EMERGING-TRENDS.md) |

---

## 最重要原則（全ドメイン共通の前提）

### 1. Shared Responsibility Model（共有責任モデル）

**全ドメインの前提。** サービス種別（IaaS / PaaS / SaaS）ごとに「誰が何を守るか」が変わる。

- IaaS: プロバイダーは物理〜仮想化層まで、顧客は OS 以上（パッチ・ネットワーク構成・IAM・データ）を担う
- PaaS: プロバイダーがランタイムまで担い、顧客はアプリケーションとデータを担う
- SaaS: プロバイダーがアプリまで担うが、**データの分類・アクセス管理・利用統制は常に顧客責任として残る**
- 設計・評価の際は「自組織に該当部分を担うスキル・体制があるか」を常に確認する
- 詳細: [FUNDAMENTALS-AND-MODELS.md](references/FUNDAMENTALS-AND-MODELS.md)（責任分界表）・[APPLICATION-SECURITY.md](references/APPLICATION-SECURITY.md)（責任の残余）

### 2. クラウドとオンプレミスの差分を正しく捉える

- **6 ドメインの大半はオンプレミスにも通用する**。差分が最も大きいのはアーキテクチャ（クラウドで加速した設計パターン）と責任分界
- **インターネットベース技術での提供 ≒ インターネット公開ではない**。設計・アーキテクチャ判断とセキュリティ統制で保護境界を作れる
- **管理プレーン（management plane）はクラウド固有の最重要防御対象**。管理コンソール・API への強い認証（MFA）・最小権限・監査が必須

### 3. セキュリティ統制の集約を利点として使う

- プロバイダーの統合基盤とマーケットプレイス経由のサードパーティ製品を組み合わせ、オンプレのような多ベンダー寄せ集めを避けられる
- 運用の境界を明確化する: 監視・アラートの責任分担と、自組織側で統制を握る選択肢の把握が運用設計の鍵

### 4. データ中心で考える

- 比重最大の Domain 2 が示す通り、**データライフサイクル（生成→保存→利用→共有→アーカイブ→破棄）の各段階に統制を割り当てる**のがクラウドセキュリティの中核
- データロケーション（保存地・処理地・管轄）は法規制（Domain 6）と直結する

### 5. 学習・適用時の判断基準

| 状況 | 指針 |
|------|------|
| ベンダー固有機能を深掘りすべきか | 不要（本スキルはベンダー非依存）。ただし主要プラットフォームで概念の実装差を体感すると理解が深まる。ベンダー固有は `developing-aws` / `developing-google-cloud` へ |
| どのドメインから固めるか | 比重最大の Domain 2（データセキュリティ）と、全体の前提となる Domain 1（責任分界・参照アーキテクチャ） |
| オンプレ経験者の重点 | 責任分界（Shared Responsibility）、管理プレーン、クラウド固有の法域論点（Domain 6） |
| 資格学習の心得 | 資格保持者は倫理規範（社会の保護・誠実な行動・誠実なサービス提供・専門職の発展）への同意と継続教育が求められる |

---

## 隣接スキルへの誘導

| 目的 | 使うべきスキル |
|------|-------------|
| セキュリティアーキテクチャ設計の方法論（脅威モデリング成果物・アーティファクト駆動） | `architecting-security` |
| コードレベルのセキュリティ（OWASP・入力検証） | `devkit:securing-code` |
| セキュアバイデフォルトのコーディング規則 | `devkit:software-security` |
| 認可モデル実装（ABAC / ReBAC / Cedar） | `implementing-dynamic-authorization` |
| AWS 固有のセキュリティサービス | `developing-aws` |
| Google Cloud 固有のセキュリティサービス | `developing-google-cloud` |
| 監視・ログ・オブザーバビリティ設計 | `implementing-observability` |
