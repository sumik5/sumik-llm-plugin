# securing-web-apis: Web API セキュリティ実装ガイド

## API セキュリティの全体像

API のセキュリティ問題は大きく2種類に分けられる。

| 種類 | 特徴 | 対処方法 |
|------|------|---------|
| **実装レベルの脆弱性** | SQL インジェクションのようなコーディングミス | 実行時のパッチ・修正で対処可能 |
| **設計レベルの脆弱性（vulnerable by design）** | 予測可能な識別子・無制約のページネーション・柔軟すぎるスキーマなど | 設計をやり直さない限り根本的に解消できない |

攻撃者が送るリクエストの多くは「一見正当」に見えるため、WAF やレート制限だけでは検知できず、認証・認可の突破やトークン改ざんのような分かりやすい攻撃よりも見逃されやすい。だからこそ、API 開発サイクルの初期段階でこれらのリスクを潰し込む「シフトレフト」の発想が欠かせない。

**OWASP API Security Top 10 (2023)** は、この領域における業界標準の脆弱性分類である。Web アプリケーション向けの OWASP Top 10（SQLi・XSS 等の汎用的な脆弱性）とは異なり、API 固有の設計・認可・運用に根ざしたリスクを扱う。10 項目は「認可系」（誰が何にアクセスできるか）と「リソース・設定・運用系」（システムがどう構成・運用されているか）の2系統に分けられる。

### API 開発サイクルにおける位置づけ

セキュリティは開発プロセスの最後に付け足すものではなく、各段階に対応する観点がある。

| 開発サイクルの段階 | 重要な観点 | 対応する reference |
|------------------|-----------|-------------------|
| **設計** | 脅威モデリング（STRIDE）・shift-left・ゼロトラスト API・secure-by-design（識別子・スキーマ・ユーザーフロー） | `API-SECURITY-PROGRAM.md`, `SECURE-BY-DESIGN.md` |
| **実装** | OWASP API Top 10 の各脆弱性への対処・JWT/OAuth 2.0/OIDC/RBAC の実装 | `OWASP-API-TOP10.md`, `AUTHN-AUTHZ.md` |
| **テスト** | API linter による設計検証・契約テスト/ファジング・アクセス制御テストの自動化 | `INFRA-FAPI-OBS-TESTING.md` |
| **運用** | API ゲートウェイ/WAF・ネットワークトポロジー・可観測性による異常検知・FAPI レベルの高保証要件 | `INFRA-FAPI-OBS-TESTING.md` |

この見取り図が示すとおり、単一のチェックリストや単一のツール（API ゲートウェイ・WAF 等）だけでは API を守り切れない。設計・実装・テスト・運用の各段階に対応策を組み込む多層防御が前提になる。

---

## 使いどころ

以下のような場面でこのスキルをロードする。

- HTTP/REST API の実装・既存コードをセキュリティ観点でレビューするとき
- OWASP API Security Top 10 の脆弱性（BOLA・BOPLA・BFLA・SSRF 等）を検出・修正するとき
- API の認証・認可を設計するとき（JWT 検証、OAuth 2.0 フロー選定、RBAC 実装、外部 IdP 連携）
- 金融・医療・法務等の高セキュリティ要件（FAPI 相当）を満たす API を設計するとき
- API セキュリティテスト（アクセス制御テスト・契約テスト・ファジング）を設計するとき
- API セキュリティの組織的な取り組み（脅威モデリング・セキュリティポスチャ評価・監査対応）を検討するとき

**隣接スキルとの境界**（判断に迷ったらこちらを先に確認する）:

| 相談内容 | 参照すべきスキル |
|---------|-----------------|
| エンドポイント設計・レスポンス構造・バージョニング等、セキュリティ以外の API 設計全般 | `developing-web-apis` |
| REST/GraphQL/gRPC 等の API スタイル選択そのもの | `choosing-api-styles` |
| コードレベルの汎用 OWASP Top 10（Web アプリの SQLi/XSS 等）・ペネトレーションテスト | `devkit:securing-code` |
| ABAC/ReBAC/Cedar/OPA 等の認可モデル選定そのもの | `cloud:implementing-dynamic-authorization` |
| STRIDE/LINDDUN を用いたアーキテクチャレベルの脅威モデリング手法そのもの | `cloud:architecting-security` |

---

## 目次

| ファイル | 扱う内容 |
|---------|---------|
| [`references/OWASP-API-TOP10.md`](references/OWASP-API-TOP10.md) | OWASP API Security Top 10 (2023) の10項目（BOLA・Broken Authentication・BOPLA・Unrestricted Resource Consumption・BFLA・Unrestricted Access to Sensitive Business Flows・SSRF・Security Misconfiguration・Improper Inventory Management・Unsafe Consumption of APIs）を、各項目「検出シグナル／悪用例／修正パターン」の対で整理したカタログ |
| [`references/API-SECURITY-PROGRAM.md`](references/API-SECURITY-PROGRAM.md) | shift-left・ゼロトラスト API・すべてを検証する・「内部 API」概念の否定・API インベントリ管理・DevSecOps for APIs という6つのセキュリティ原則と、セキュリティポスチャ評価・チームでの脅威モデリング（STRIDE）・低リスク高効果の実践・セキュリティプログラムの立ち上げ・監査対応という組織アライメントの実践をまとめる |
| [`references/SECURE-BY-DESIGN.md`](references/SECURE-BY-DESIGN.md) | 設計フェーズで対処すべき脆弱性——予測可能な識別子・無制約のユーザー入力・柔軟すぎるスキーマ（マスアサインメント）・サーバー側プロパティの露出・安全でないユーザーフロー——への具体的な設計対策（OpenAPI スキーマ制約を中心に） |
| [`references/AUTHN-AUTHZ.md`](references/AUTHN-AUTHZ.md) | Authentication と Authorization の違い・JWT の構造と検証・OAuth 2.0 の4フローと PKCE・sender-constrained tokens（mTLS/DPoP）・OpenID Connect・RBAC の実装パターン（外部 IdP 連携・トークン検証・認可ミドルウェア） |
| [`references/INFRA-FAPI-OBS-TESTING.md`](references/INFRA-FAPI-OBS-TESTING.md) | セキュアな API インフラ（ゲートウェイ・ネットワークトポロジー・WAF）・金融グレード API（FAPI 2.0）の攻撃者モデルとセキュリティプロファイル・API セキュリティの可観測性（ログ/トレース/メトリクスによる攻撃検知）・API セキュリティテスト（設計検証・契約テスト・アクセス制御テストの自動化）・実務チェックリスト |

references は「脆弱性カタログ」「原則と組織」「設計」「認証認可」「インフラ/FAPI/可観測性/テスト」の5系統に対応しており、上の「API 開発サイクルにおける位置づけ」表と合わせて読むと、今取り組んでいる作業がどのファイルに対応するか判断しやすい。

---

## クイックチェックリスト

5本の reference にまたがる、俯瞰レベルで最初に確認すべき項目。各 reference 末尾の詳細なチェックリストと重複しすぎない範囲に絞っている。個別の実装判断はリンク先の詳細チェックリストを参照する。

- [ ] すべてのリソースアクセスに「所有者/テナント一致」条件をクエリレベルで課しているか（BOLA 対策、`OWASP-API-TOP10.md`）
- [ ] JWT 検証で署名アルゴリズム・`aud`・`iss`・有効期限をすべて明示的に検証しているか（`alg` フィールドを信用しない、`AUTHN-AUTHZ.md`）
- [ ] 入力用スキーマと出力用スキーマを分離しているか（マスアサインメント・過剰データ露出対策、`SECURE-BY-DESIGN.md`）
- [ ] リソース識別子に連番整数をそのまま露出していないか（UUID/サロゲート ID への置き換え検討、`SECURE-BY-DESIGN.md`）
- [ ] エンドポイントの性質（認証系/CPU集約系/通常読み取り系）に応じてレート制限のしきい値を分けているか（`OWASP-API-TOP10.md`）
- [ ] 管理機能・上位ロール専用の操作に明示的なロール/権限チェックを課しているか（BFLA 対策、「隠しておけば安全」に依存しない）
- [ ] ユーザー指定 URL を扱う機能で内部アドレス・クラウドメタデータエンドポイントを遮断しているか（SSRF 対策、`OWASP-API-TOP10.md`）
- [ ] 全環境でデバッグモードを明示的に無効化しているか（本番のスタックトレース露出防止）
- [ ] API 仕様・カタログを最新化し、zombie API（退役し忘れ）・shadow API（未文書化）が残っていないか（`API-SECURITY-PROGRAM.md`）
- [ ] 外部 API・サードパーティ・内部サービスからのレスポンスを「信頼できない入力」として検証しているか（`OWASP-API-TOP10.md`）
- [ ] API ゲートウェイ/WAF を単一エントリポイントとして構成しているか（ただしこれらだけで BOLA 等のビジネスロジック脆弱性は防げない、`INFRA-FAPI-OBS-TESTING.md`）
- [ ] 高感度データを扱う API で sender-constrained token（mTLS または DPoP）の採用を検討したか（`AUTHN-AUTHZ.md`）
- [ ] セキュリティ関連イベントのログ・トレース・メトリクスを収集し、エンドポイント単位の異常な反復呼び出しを検知できるか（`INFRA-FAPI-OBS-TESTING.md`）
- [ ] broken authentication / BOLA / RBAC の3種のアクセス制御テストを自動化し CI で継続実行しているか（`INFRA-FAPI-OBS-TESTING.md`）
- [ ] 大きな変更に着手する際、脅威モデリング（STRIDE の4ステップ）から始めているか（`API-SECURITY-PROGRAM.md`）

---

## AskUserQuestion の使用指針

**判断分岐がある場合、推測で進めず必ず AskUserQuestion ツールでユーザーに確認する**（AskUserQuestion が使えない環境では、同じ選択肢を通常のテキスト質問として提示して確認する）。

### 確認すべき場面

- **高保証プロファイルの要否**: 金融・医療・法務・政府等、機微性の高いドメインで FAPI 2.0 相当のセキュリティプロファイル（confidential client 限定・JAR+PAR・sender-constrained token・署名アルゴリズム制限）まで要求するか、通常の OAuth 2.0/OIDC で十分か
- **認証基盤の選定**: 自前で認証システムを実装するか、外部 IdP（OAuth 2.0/OIDC 準拠の Identity as a Service）に委ねるか。委ねる場合はどの IdP か（特定 SaaS 名は本スキル内で扱わないため、選定は利用者側で行う）
- **sender-constrained token の方式**: トークン漏洩対策として mTLS による証明書バインドと DPoP のどちらを採用するか（実装難易度とインフラ構成のトレードオフ）
- **認可の粒度モデル**: ロールベース（RBAC）・細粒度アクセススコープ・属性ベース（ABAC）のどれを採用するか。ユーザー種別が少数で権限体系がシンプルなら RBAC、動的な権限管理が必要なら他の選択肢を検討
- **レート制限のしきい値・追跡単位**: 認証系エンドポイントの試行回数上限、IP/アカウント/デバイスフィンガープリントのどの組み合わせで追跡するか
- **SSRF 対策の方針**: ユーザー指定 URL の用途に応じて allowlist（少数の信頼済みドメインのみ）と denylist（内部アドレス/メタデータエンドポイントのみ遮断）のどちらを採用するか
- **API ゲートウェイ/WAF の導入・選定**: 導入するか、導入する場合はどの機能（トークン検証・レート制限・スキーマバリデーション等）を担わせるか
- **API 仕様の文書化・カタログ化の範囲**: 新規/既存 API のうちどこまでを OpenAPI 仕様化し API カタログに登録するか

### 確認不要な場面（明確なベストプラクティスが存在する）

- JWT 検証で署名アルゴリズム・`aud`・`iss`・有効期限を検証すべきか → 必須（検証しないと Broken Authentication に直結する）
- リクエスト用スキーマとレスポンス用スキーマを分離すべきか → 必須（マスアサインメント・過剰データ露出の根本対策）
- 入力パラメータに `minimum`/`maximum`/`maxLength`/`enum` 等の制約を設定すべきか → 必須（無制約入力は設計レベルの脆弱性に直結する）
- 本番環境でデバッグモードを無効化すべきか → 必須
- パスワード等の機密情報を URL クエリパラメータに含めるべきでないか → 必須（ブラウザ履歴・アクセスログに残るため禁止）
- OAuth 2.1 で非推奨化された Implicit flow・Resource owner password flow を新規実装で使うべきか → 使うべきでない（廃止済みフロー）

### 実装例

```python
AskUserQuestion(
    questions=[
        {
            "question": "このAPIは金融・医療等の高セキュリティ要件（FAPI相当）を満たす必要がありますか？",
            "header": "セキュリティプロファイル",
            "options": [
                {"label": "通常のOAuth 2.0/OIDCで十分", "description": "一般的なWeb/モバイルアプリ向けAPI"},
                {"label": "FAPI 2.0相当が必要", "description": "金融・医療・法務・政府等、機微性の高いドメイン"}
            ],
            "multiSelect": False
        },
        {
            "question": "認可の粒度モデルをどうしますか？",
            "header": "認可モデル",
            "options": [
                {"label": "RBAC（ロールベース）", "description": "ユーザー種別が少数で権限体系がシンプルな場合（推奨デフォルト）"},
                {"label": "細粒度アクセススコープ", "description": "エンドポイント単位の動的な権限管理が必要な場合"},
                {"label": "ABAC（属性ベース）", "description": "職務・地域・プロジェクト所属等の属性で動的判定したい場合"}
            ],
            "multiSelect": False
        }
    ]
)
```
