# GCP コンプライアンス・ガバナンス リファレンス

GCPセキュリティ基盤・コンプライアンスフレームワーク・データプライバシー・アクセス透明性の実践ガイド。

---

## GCPセキュリティの基本原則

### Defense in Depth（多層防御）

GCPは単一技術に依存せず、複数のセキュリティレイヤーを段階的に配置。

| レイヤー | 概要 | 主要技術 |
|---------|------|---------|
| 運用セキュリティ | ソフトウェアデプロイ、デバイス・認証情報保護、内部脅威対策、侵入検知 | BeyondCorp Enterprise、2FA、Red Team演習 |
| ネットワークセキュリティ | プライベート暗号化ネットワーク、TLS強制、DDoS保護 | Google Front End (GFE)、Perfect Forward Secrecy |
| データセキュリティ | 転送中・保管中の暗号化、鍵管理、データ削除保証 | デフォルト暗号化、Cloud KMS、CMEK、EKM |
| サービス・ID | 暗号化認証、ゼロトラスト、サンドボックス | サービスアカウント、RPC暗号化、カーネル分離 |
| 物理・ハードウェア | カスタム設計ハードウェア、セキュアブート、サプライチェーン管理 | Titan セキュリティチップ、データセンター物理制御 |

### Zero Trust（ゼロトラスト）

- サービス間に暗黙の信頼なし
- すべてのID（ユーザー・サービス）を暗号化認証
- 承認済みアプリケーションバイナリのみ実行許可
- ネットワーク境界だけでなくアプリケーション層で認証・認可

### End-to-End Provenance（エンドツーエンド来歴）

- カスタムビルドサーバー・ネットワーク機器（不要コンポーネント除外）
- Titan セキュリティチップ（ハードウェア信頼の起点、ブート整合性検証）
- 自社開発OS（Linuxベース強化版）、BIOS・ブートローダー・カーネルの署名検証
- サプライチェーンリスク排除（ベンダー審査、第三者干渉最小化）

---

## 共有責任モデル（Shared Responsibility）と Shared Fate

### 共有責任モデルの境界

GCPと顧客の責任分界点はサービスモデルによって異なる。この理解がコンプライアンス設計の起点となる。

| サービスタイプ | GCP責任範囲 | 顧客責任範囲 | リスク例（顧客側） |
|--------------|------------|------------|------------------|
| IaaS（Compute Engine等） | 物理インフラ、ネットワーク、ハイパーバイザー | 仮想インフラ、OS、アプリ、データ、アクセス制御、監視 | 未パッチOSの悪用、過剰権限IAM、公開ストレージバケット |
| PaaS（Cloud SQL等） | 物理インフラ、ネットワーク、ランタイム、ミドルウェア | アプリケーション、データ、アクセス制御 | SQLインジェクション脆弱性、暗号化設定ミス |
| SaaS（Google Workspace等） | アプリケーション全体、インフラ全体 | データ分類、アクセス制御、利用ポリシー | フィッシングによる認証情報漏洩、データ共有設定ミス |

#### 詳細な責任分解

**GCPが担保する領域（すべてのサービス共通）**:
- データセンター物理セキュリティ（CCTV、生体認証、侵入検知）
- Titanセキュリティチップによるハードウェア信頼の起点
- グローバルネットワーク暗号化（WAN間通信）
- デフォルト保管時暗号化（全ストレージサービス）
- TLS強制（すべてのAPI通信）

**顧客が構成・管理する領域**:
- IAMポリシー設計・最小権限適用
- ファイアウォールルール・VPC構成
- 暗号化鍵管理（CMEK/EKM選択時）
- アプリケーションコード・依存関係のセキュリティ
- 監査ログの有効化・保存期間設定
- コンプライアンス制御の継続的検証

### Shared Fate（共有運命）への進化

GCPは従来の境界線モデルを超え、顧客とのパートナーシップを前提とする「Shared Fate」概念を提唱。

**Shared Fateの実践例**:
- **Day 1セキュアオンボーディング**: Assured Workloads、セキュリティブループリント、ベストプラクティス自動適用
- **協働インシデント対応**: 顧客のセキュリティイベントに対してGoogleサポートチームが技術支援（Premium/Enterprise サポート）
- **NIST SP 800-61準拠プロセス**: 検知→対応→封じ込め→根絶→復旧→教訓フィードバック
- **透明性の提供**: Access Transparency（Google従業員アクセスのリアルタイムログ）、Security Bulletin（脆弱性公開）

| フェーズ | GCPアクション | 顧客アクション |
|---------|-------------|--------------|
| 検知 | Security Command Center脅威検知、Event Threat Detection | Cloud Logging/Monitoring アラート設定 |
| 対応 | サポートチケット受付、初動支援 | インシデント対応チーム招集、スコープ特定 |
| 封じ込め | 影響範囲の技術分析支援 | 侵害リソース隔離（VPC隔離、IAM無効化等） |
| 復旧 | ベストプラクティス提案 | クリーン環境再構築、セキュリティ強化 |
| 教訓 | ポストモーテムレビュー参加 | RCA作成、再発防止策実装 |

**判断基準**: 「GCPの責任」と「顧客の責任」の線引きではなく、「共に解決する」マインドセットで設計すること。インシデント発生時は境界を越えた協働が成功の鍵。

---

## Security by Design（6つの柱）

### 1. Operational Security（運用セキュリティ）

| 対策領域 | 主要技術・プロセス |
|---------|------------------|
| セキュアデプロイ | 中央管理、二段階レビュー、XSS防止ライブラリ、静的解析、専門家による手動セキュリティテスト |
| 脆弱性報奨金 | Vulnerability Rewards Program（一般公開） |
| デバイス・認証情報保護 | BeyondCorp Enterprise、2FA、継続的デバイス・ユーザー監視、パッチ自動化 |
| 内部脅威対策 | 特権ユーザーアクセスの監視・ログ記録、自動化可能な特権操作の自動化 |
| 侵入検知 | ホスト・ネットワーク信号統合、機械学習による脅威検知、24x7 SOC、Red Team演習 |

### 2. Network Security（ネットワークセキュリティ）

| 対策 | 詳細 |
|-----|------|
| プライベートネットワーク | Google所有・運用のグローバル暗号化ネットワーク（公衆インターネット未経由） |
| TLS強制 | すべての外部API・ネットワーク通信でTLS必須、Perfect Forward Secrecy |
| Google Front End (GFE) | 証明書管理、TLS終端、DDoS保護（マルチティア・マルチレイヤー） |
| ロードバランサー | ネットワーク・アプリケーション認識型ハードウェア/ソフトウェアLB |
| ユーザー認証 | リスクベース認証（デバイス情報・IP・地理的位置）、2FA |

### 3. Data Security（データセキュリティ）

| 暗号化タイプ | デフォルト対応 | オプション |
|------------|-------------|----------|
| 転送中データ | TLS強制（すべてのAPI通信） | WAN間データも自動暗号化 |
| 保管中データ | デフォルト暗号化（全ストレージサービス） | Cloud KMS（CMEK）、Cloud HSM（FIPS 140-2 Level 3）、EKM（外部HSM統合）、BYOK |

**データ削除保証**:
1. 削除リクエスト → スケジュール削除（誤削除復旧可能）
2. サービス固有ポリシーに従って物理メディアから削除
3. データ処理・削除ライフサイクルの詳細はホワイトペーパー "Trusting your Data with Google Cloud Platform" 参照

### 4. Services and Identity（サービス・ID）

| 技術 | 用途 |
|-----|------|
| 暗号化認証・認可 | アプリケーション層での人-システム間・システム間通信の認証（ゼロトラスト） |
| サービスアカウント | 各サービスに暗号化認証情報を付与（RPCアクセス時） |
| サンドボックス | 言語・カーネルベース、ハードウェア仮想化、Linuxユーザー分離 |
| RPC暗号化 | サービスオーナーが保護レベルを構成可能（完全性保護・暗号化） |

### 5. Physical and Hardware Security（物理・ハードウェア）

| 制御レイヤー | 対策 |
|------------|------|
| データセンター物理制御 | CCTV、車両バリア、生体認証、レーザー侵入検知、金属探知機、従業員バックグラウンドチェック |
| カスタムハードウェア | Google設計サーバー・ネットワーク機器、Titanセキュリティチップ（ハードウェアID・認証） |
| サプライチェーン管理 | コンポーネントベンダー審査、セキュリティ監査、来歴検証 |
| セキュアブート | BIOS・ブートローダー・カーネル・OS署名検証、ハードウェア信頼の起点 |
| 自動管理 | 大規模サーバーフリートのパッチ自動化、ハード・ソフト問題の自動診断・除外 |

### 6. Threat and Vulnerability Management（脅威・脆弱性管理）

| 活動 | 主要技術・プロセス |
|-----|------------------|
| 脆弱性スキャン | 自動・手動ペネトレーションテスト、ソースコードスキャン、セキュリティ保証プログラム |
| 優先度管理 | 重大度ベースの優先度付け、担当チーム割り当て |
| マルウェア対策 | 自動・手動検知ツール、Google Safe Browsing、VirusTotal、複数アンチウイルスエンジン（Gmail・Drive） |
| セキュリティ監視 | 内部ネットワークテレメトリ、特権ユーザーアクション、外部脆弱性情報統合 |
| 脅威インテリジェンス | Threat Analysis Group、Project Zero、ブログ・Wiki・メーリングリスト監視、ボットネット検知 |
| インシデント対応 | NIST SP 800-61準拠プロセス、24x7対応、顧客協働 |

---

## データプライバシー原則

### Google Cloud Enterprise Privacy Commitments

| 原則 | 説明 | 保証 |
|-----|------|------|
| データ所有権・制御 | 顧客がデータを所有・制御。リージョン選択、移動・コピーの決定権は顧客のみ | Google はデータを無断で移動・複製しない |
| 広告利用禁止 | 顧客データは広告・ターゲティングに一切使用しない | ポリシーと契約で明文化 |
| 透明なデータ収集 | 事業機能に必要なデータのみ収集（ISO 27001、SOC 2、GDPR準拠） | 第三者独立監査で検証 |
| データ販売禁止 | 顧客データをパートナー・第三者に販売しない | 法的合意と手続き・技術制御 |
| Security & Privacy by Design | すべてのプロダクトに初期段階からセキュリティ・プライバシーを組み込む | ポリシーと設計レビュー |

### Access Transparency（アクセス透明性）

Google従業員による顧客データアクセスをリアルタイムログで可視化。

**適用条件**:
- Premium/Enterprise/Gold/Platinum サポートレベル
- 組織レベルで有効化（IAM role: `roles/axt.admin`）
- プロジェクトに課金アカウント紐付け必須

**ベストプラクティス**:
- **最小権限**: Google従業員はデフォルトでアクセス拒否、必要時のみ一時的・条件付き許可
- **単独アクセス制限**: 定足数ベースのアクセス制御（複数人の承認が必要）
- **正当化必須**: 権限・業務上の正当な理由・同意が必要
- **監視・アラート**: 違反検知・トリアージ・是正プロセス

**ログ内容**:
- 影響を受けたリソース
- 実行されたアクション
- アクションのタイムスタンプ
- アクセス理由（例: サポートチケット番号）
- アクセスしたGoogle従業員情報

**有効化**（コンソール操作のみ、CLI非対応）:
```bash
# 1. IAM & Admin > Settings に移動
# 2. "ENABLE ACCESS TRANSPARENCY FOR ORGANIZATION" ボタンをクリック

# ログ確認（有効化後）
gcloud logging read \
  'logName="projects/PROJECT_ID/logs/cloudaudit.googleapis.com%2Faccess_transparency"' \
  --limit 50
```

**活用例**:
- サポートリクエストの正当性検証
- コンプライアンス要件の監査証跡
- SIEMツールへのログ取り込み・分析

### Access Approval（アクセス承認）

Google従業員による顧客データアクセスに顧客の明示的承認を必須化。

**適用条件**:
- Premium/Enterprise/Gold/Platinum サポートレベル
- サポート対象サービスのみ（リスト: https://cloud.google.com/access-approval/docs/supported-services）

**承認オプション**:
- すべてのサポート対象サービスで自動有効化（デフォルト）
- GA レベルサポートサービスのみ選択
- 特定サービスのみ選択

**例外（承認不要）**:
- 非人間の自動処理（圧縮タスク、ディスク破棄等）
- 法的拘束力のある要求（Legal Access）
- サービス障害修正のための緊急アクセス
- Access Transparency 例外ログが記録されたアクティビティ

**有効化**（コンソール操作）:
```bash
# 1. Access Approval ページに移動
# 2. "ENROLL" ボタンをクリック

# API経由での設定確認
gcloud access-approval settings get \
  --organization=ORG_ID
```

**ワークフロー例（Cloud Storage ACL 確認）**:
1. 顧客がファイルアクセス失敗 → サポートチケット作成
2. Google エンジニアがバケットACL取得を試行 → Access Approval リクエスト送信
3. 顧客が承認 → Google エンジニアがACL取得 → Transparency Log 記録
4. Google エンジニアがファイル読込を試行 → 再度 Access Approval リクエスト
5. 顧客が承認/拒否を判断（機密性に応じて）

---

## データレジデンシー（Data Residency）

### 利用可能な制御

| 制御方法 | 概要 | 実装 |
|---------|------|------|
| リージョン選択 | データを特定のGCPリージョン（地理的位置）に保存 | リソース作成時にリージョン指定、Organization Policy で許可リージョンを制限 |
| Cloud KMS リージョナライゼーション | 暗号化鍵を特定リージョンに制限 | Key Ring作成時にリージョン指定（`gcloud kms keyrings create`) |
| VPC Service Controls | 特定地理的位置・IPアドレスからのみアクセス許可 | Service Perimeter で Egress/Ingress ポリシー定義 |
| CMEK（Customer-Managed Encryption Keys） | リソース作成者が適切なロケーションを選択 | Cloud KMS でリージョン固有 Key Ring 作成 → リソース作成時に指定 |

**Organization Policy による地理的制限**:
```bash
# 許可リージョンを asia-northeast1（東京）と us-central1 に制限
gcloud resource-manager org-policies set-policy \
  --organization=YOUR_ORG_ID \
  constraints/gcp.resourceLocations \
  --allowed-values=in:asia-northeast1-locations,in:us-central1-locations
```

**Cloud KMS Key Ring のリージョン指定**:
```bash
# 東京リージョンに Key Ring 作成
gcloud kms keyrings create my-keyring \
  --location=asia-northeast1
```

**Key Access Justifications (KAJ)**:
- Cloud KMS または外部KMS を使用したデータ復号化リクエスト時、詳細な正当化理由を提供
- 自動化ポリシーで復号化アクセスの承認/拒否を制御
- Google の復号化能力を顧客がコントロール

---

## コンプライアンスフレームワーク

### 国際標準

| 標準 | スコープ | 監査サイクル |
|-----|---------|------------|
| ISO 27001 | ISMS（14グループ・35制御目標・114制御）、すべての組織タイプ適用可 | 年次第三者監査 |
| ISO 27002 | ISO 27001 制御の実装詳細（アドバイザリ文書） | - |
| ISO 27017 | クラウドコンピューティング情報セキュリティ（ISO 27001拡張） | 年次第三者監査 |
| ISO 27018 | PII処理・保護ガイドライン（ISO 27002拡張） | 年次第三者監査 |
| SOC 2 / SOC 3 | セキュリティ・可用性・処理整合性・機密性・プライバシー | 年次第三者監査 |

### 国・地域別コンプライアンス

| 地域 | 標準・規制 |
|-----|----------|
| 米国 | FedRAMP、PCI DSS、HIPAA |
| シンガポール | MTCS |
| オーストラリア | IRAP |
| ドイツ | 国内プライバシー・コンプライアンス要件 |
| EU | GDPR |

**重要な注意点**:
- すべてのGCPリージョンは一貫したコンプライアンス標準に準拠
- ただし、地域の法律・規制により一部標準が適用されない場合あり
- 新規プロダクトは数ヶ月の遅延後にコンプライアンススコープに追加（SOC 2・ISO優先、その後市場別認証）

### コンプライアンスレポート取得

**Compliance Reports Manager**:
```bash
# コンソールからアクセス（CLI非対応）
# https://cloud.google.com/security/compliance/offerings

# Security Command Center でコンプライアンス違反を確認
gcloud scc findings list organizations/ORG_ID \
  --filter="category=\"COMPLIANCE_VIOLATION\" AND state=\"ACTIVE\"" \
  --source="organizations/ORG_ID/sources/-"
```

**フィルター条件**:
- Industry: Industry-agnostic（ISO/SOC/CSA等）、Government/Public（FedRAMP/IRAP等）
- Region: Global、特定リージョン
- Report Type: Audit Report、Certification、Assessment
- Product Area: Google Cloud

**利用可能なレポート**:
- ISO 27001/27017/27018 監査レポート
- SOC 2 Type II レポート
- PCI-DSS AOC（Attestation of Compliance）
- CSA STAR 自己評価

### 第三者リスクアセスメント

**利用可能な自己評価アンケート**:
- CSA STAR 自己評価
- SIG Core Questionnaire（18リスクドメイン）
- IHS Markit KY3P Due Diligence Questionnaire
- Google Cloud Data Processing and Security Terms

**アクセス方法**:
- Compliance Manager: https://cloud.google.com/security/compliance/compliance-reports-manager
- セキュリティホワイトペーパー: https://cloud.google.com/security/overview/whitepaper

---

## Assured Workloads

コンプライアンス要件に特化した環境を自動構成するサービス。

**主要機能**:
- 特定コンプライアンス標準（FedRAMP、CJIS、EU Sovereign Cloud等）に必要な制御を自動適用
- データ所在地制限、アクセス制御、Access Transparency 統合
- 継続的なコンプライアンス監視

**対象顧客**:
- 高度に規制された業界（政府、医療、金融）
- 厳格なデータ主権要件を持つ組織

**作成コマンド**:
```bash
# Assured Workloads 環境作成
gcloud assured workloads create \
  --organization=ORG_ID \
  --location=us-central1 \
  --display-name="fedramp-env" \
  --compliance-regime=FEDRAMP_MODERATE \
  --billing-account=BILLING_ACCOUNT_ID

# 作成済み環境の確認
gcloud assured workloads list --organization=ORG_ID --location=us-central1
```

---

## 継続的コンプライアンス（Continuous Compliance）

クラウド環境では、変更が頻繁かつ高速に発生するため、年次監査やポイントインタイム検証では不十分。継続的コンプライアンス戦略により、リアルタイムで準拠性を担保し、ドリフト（設定逸脱）を即座に検知・是正する。

### 継続的コンプライアンスが必要な理由

| 従来の監査アプローチ | 継続的コンプライアンス |
|------------------|---------------------|
| 年次・四半期の定期監査 | リアルタイム・自動スキャン |
| 監査時点でのスナップショット検証 | 全変更の継続的追跡 |
| 設定ミスの事後検出（監査後に発覚） | 設定ミスの事前ブロック or 即時検知 |
| 手動レポート作成 | 自動ダッシュボード・コンプライアンススコア |
| インシデント発生後の対応 | インシデント予防・早期封じ込め |

**規制要件の変化**:
- HIPAA/PCI-DSS: 継続的なアクセス監視と即時異常検知要求
- GDPR: データ処理活動の透明性・監査証跡（72時間以内の侵害通知）
- SOC 2 Type II: 制御の「運用上の有効性」を継続的に証明

### パイプライン構成

```
クラウド資産変更（VM作成・IAMポリシー変更等）
  ↓
① Cloud Asset Inventory: 変更検知・履歴記録
  ↓
② Policy as Code 検証（IaC段階）: Terraform Validator / Policy Controller
  ↓
③ ランタイムポリシー実行（Compliance as Code）: Organization Policy / SCC
  ↓
状態チェック → 準拠/非準拠判定
  ↓
[準拠] → アクション不要、監査証跡記録
[非準拠] → 通知 / 自動是正 / 予防的ブロック
```

### 成熟度レベル別アクション

| レベル | アプローチ | 実装例 | 適用タイミング |
|-------|----------|--------|---------------|
| **Level 1: 検知・通知** | 違反を検知し、セキュリティチームへ通知 | SCC結果 → Pub/Sub → Slack/Email | 初期導入・ポリシー策定中 |
| **Level 2: 自動是正** | Cloud Functions で設定を自動修正 | 公開バケット検知 → Cloud Functions で非公開化 | ポリシー成熟後 |
| **Level 3: 予防的制御** | Organization Policy で違反設定を事前ブロック | 外部IPアタッチ禁止、リージョン制限強制 | ベストプラクティス確立後 |

### 利用サービス

**継続的スキャン・検知**:
- **Security Command Center (SCC)**: 脆弱性・脅威・CIS Benchmarks準拠チェック
- **Cloud Asset Inventory**: 全リソースの変更履歴・構成追跡
- **Policy Analyzer**: IAM ポリシーの過剰権限検出

**ポリシー実行**:
- **Organization Policy**: リソース作成時の予防的制御（例: Shielded VM強制、リージョン制限）
- **Terraform Validator**: IaCコード段階でのポリシー検証
- **Policy Controller (Anthos)**: OPA (Open Policy Agent) ベースのKubernetesポリシー

**自動是正**:
- **Cloud Functions**: イベントトリガー型是正スクリプト（例: 非準拠リソースの自動修正）
- **Cloud Workflows**: 複雑な是正プロセスのオーケストレーション

**通知・レポート**:
- **Cloud Logging / Monitoring**: アラート生成、Slack/PagerDuty連携
- **Pub/Sub**: イベント駆動型通知パイプライン
- **Security Command Center ダッシュボード**: コンプライアンススコア可視化

### 実装例

#### Level 1: 検知・通知パイプライン

```bash
# Organization Policy で Shielded VM を強制（Level 3: 予防的制御）
cat << EOF > policy-shielded-vm.yaml
constraint: constraints/compute.requireShieldedVm
booleanPolicy:
  enforced: true
EOF

gcloud resource-manager org-policies set-policy \
  --organization=ORG_ID \
  policy-shielded-vm.yaml

# SCC の Security Health Analytics 結果確認
gcloud scc findings list organizations/ORG_ID \
  --source="organizations/ORG_ID/sources/SHA_SOURCE_ID" \
  --filter="state=\"ACTIVE\" AND category=\"POLICY_VIOLATION\""

# Pub/Sub トピックで SCC 結果を通知（Level 1: 検知・通知）
gcloud pubsub topics create scc-findings

gcloud scc notifications create scc-notify \
  --organization=ORG_ID \
  --pubsub-topic=projects/PROJECT_ID/topics/scc-findings \
  --filter="state=\"ACTIVE\" AND severity=\"HIGH\""
```

#### Level 2: 自動是正（Cloud Functions）

```python
# 公開バケット自動非公開化
from google.cloud import storage
import base64
import json

def remediate_public_bucket(event, context):
    """Pub/Subメッセージから公開バケットを検知し、非公開化"""
    pubsub_message = base64.b64decode(event['data']).decode('utf-8')
    finding = json.loads(pubsub_message)

    if finding['category'] == 'PUBLIC_BUCKET_ACL':
        bucket_name = finding['resourceName'].split('/')[-1]
        client = storage.Client()
        bucket = client.bucket(bucket_name)

        # allUsers権限を削除
        policy = bucket.get_iam_policy(requested_policy_version=3)
        policy.bindings = [b for b in policy.bindings if 'allUsers' not in b['members']]
        bucket.set_iam_policy(policy)

        print(f"Remediated bucket: {bucket_name}")
```

```bash
# Cloud Functions デプロイ
gcloud functions deploy remediate-public-bucket \
  --runtime=python39 \
  --trigger-topic=scc-findings \
  --entry-point=remediate_public_bucket \
  --region=us-central1
```

### コンプライアンススキャンの自動化

```bash
# Cloud Asset Inventory で全リソースのスナップショット取得
gcloud asset search-all-resources \
  --scope=organizations/ORG_ID \
  --asset-types="compute.googleapis.com/Instance" \
  --format=json > compute-instances.json

# Terraform Validator で IaC段階のポリシー検証
terraform plan -out=plan.tfplan
terraform show -json plan.tfplan > plan.json
gcloud beta terraform vet plan.json --policy-library=./policy-library
```

### ダッシュボード・レポーティング

**Security Command Center ダッシュボード活用**:
- **コンプライアンス概要**: CIS Benchmarks準拠率、重大度別違反数
- **カスタムダッシュボード**: Cloud Monitoring でコンプライアンスメトリクスを可視化

```bash
# SCC コンプライアンスレポートのエクスポート
gcloud scc findings list organizations/ORG_ID \
  --filter="state=\"ACTIVE\" AND category=\"COMPLIANCE_VIOLATION\"" \
  --format="csv(resourceName,category,severity,eventTime)" \
  > compliance-violations.csv

# BigQuery にエクスポートして分析
bq load --source_format=CSV compliance_dataset.violations \
  compliance-violations.csv
```

### 判断基準

| 状況 | 推奨アプローチ |
|------|-------------|
| コンプライアンスポリシー策定中 | Level 1（検知・通知）で違反パターンを収集 |
| ポリシー成熟後 | Level 2（自動是正）で運用負荷削減 |
| ベストプラクティス確立後 | Level 3（予防的制御）で違反を事前防止 |
| 高規制業界（金融・医療） | Level 3を最優先、Level 2で補完 |
| 開発スピード重視 | Level 1 + IaC段階検証（Terraform Validator） |

---

## 脅威・脆弱性管理サービス（概要）

### Security Command Center (SCC)

GCP資産全体の脅威・脆弱性・設定ミスを一元管理。

**主要機能**:
- 脆弱性スキャン（OS・コンテナイメージ）
- セキュリティ設定ミス検出（CIS Benchmarks準拠）
- 脅威検知（Event Threat Detection）
- コンプライアンス監視

**有効化コマンド**:
```bash
# SCC Premium を有効化（組織レベル）
gcloud services enable securitycenter.googleapis.com \
  --project=PROJECT_ID

# Security Health Analytics の結果確認
gcloud scc findings list organizations/ORG_ID \
  --source="organizations/ORG_ID/sources/SHA_SOURCE_ID"
```

### Web Security Scanner

App Engine/GCE/GKE上のWebアプリケーションの脆弱性を自動スキャン。

**検出可能な脆弱性**:
- XSS（クロスサイトスクリプティング）
- Flash Injection
- Mixed Content
- Outdated/Insecure Libraries

**制限事項**:
- App Engine Standard/Flexible、GCE、GKE のみ対応
- 認証が必要なページは範囲外（カスタムログイン可）

**スキャン実行**:
```bash
# Web Security Scanner スキャンの作成
gcloud web-security-scanner scan-configs create \
  --display-name="my-scan" \
  --starting-urls=https://example.com

# スキャン実行
gcloud web-security-scanner scan-runs start SCAN_CONFIG_NAME
```

---

## ベストプラクティス

### セキュリティ設計チェックリスト

- [ ] 共有責任モデルの境界を明確化（IaaS/PaaS/SaaSで異なる）
- [ ] ゼロトラストアーキテクチャを採用（サービス間通信も認証・暗号化）
- [ ] データレジデンシー要件を確認（リージョン選択、Cloud KMS、VPC Service Controls）
- [ ] Access Transparency/Approval の有効化判断（規制業界は必須）
- [ ] CMEK または EKM の必要性を評価（鍵制御レベル）
- [ ] Security Command Center 有効化（継続的脆弱性監視）
- [ ] コンプライアンスレポートの定期ダウンロード（監査対応）

### コンプライアンス対応チェックリスト

- [ ] 対象コンプライアンス標準の確認（ISO/SOC/PCI DSS/HIPAA等）
- [ ] GCP サービスのコンプライアンス対応状況を確認（サービスごとに異なる）
- [ ] 継続的コンプライアンスパイプライン構築（Compliance as Code）
- [ ] 第三者リスクアセスメント対応（SIG/CSA STAR等）
- [ ] Assured Workloads の利用検討（規制業界）
- [ ] インシデント対応計画の策定（NIST SP 800-61準拠、Google協働前提）

---

## 参考リソース

- [Google Security Whitepaper](https://cloud.google.com/security/overview/whitepaper)
- [Google Infrastructure Security Design Overview](https://cloud.google.com/security/infrastructure/design)
- [Trusting Your Data with Google Cloud Platform](https://cloud.google.com/security/trust)
- [Data Incident Response Process](https://cloud.google.com/security/incident-response)
- [Encryption in Transit in Google Cloud](https://cloud.google.com/security/encryption-in-transit)
- [Compliance Offerings](https://cloud.google.com/security/compliance/offerings)
- [Assured Workloads Overview](https://cloud.google.com/assured-workloads/docs/overview)
