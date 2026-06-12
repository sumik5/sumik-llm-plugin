---
name: software-security
description: Project CodeGuard-based secure-by-default coding rules (23 rule files spanning injection, authentication/MFA, cryptography, secrets, authorization, sessions, cloud/Kubernetes, IaC, supply chain, MCP, mobile, logging, privacy) for writing and reviewing secure code across 25+ languages. Use when writing, reviewing, or modifying code, handling user input/credentials/cryptographic operations, or configuring cloud infrastructure/CI-CD/containers. Japanese-localized adaptation of cosai-oasis/project-codeguard (CC-BY-4.0). For organizational AI-development security strategy use securing-ai-development; for dynamic authorization model design (ABAC/ReBAC/Cedar) use implementing-dynamic-authorization; for OWASP-oriented code security and penetration testing use securing-code.
codeguard-version: "1.3.1"
codeguard-commit: "a557e7ea6b7a2897178fd97cd60792eebc0a957c"
framework: "Project CodeGuard"
purpose: "Embed secure-by-default practices into AI coding workflows"
license: "CC-BY-4.0"
source: "https://github.com/cosai-oasis/project-codeguard"
sync-command: "/update-software-security"
---

# ソフトウェアセキュリティスキル（Project CodeGuard）

このスキルは、AIコーディングエージェントがセキュアなコードを生成し、一般的な脆弱性を防ぐための包括的なセキュリティガイダンスを提供する。**Project CodeGuard**（オープンソースかつモデル非依存の、セキュアバイデフォルトの実践をAIコーディングワークフローへ組み込むセキュリティフレームワーク）に基づいている。

> **出典・ライセンス**: 本スキルは [cosai-oasis/project-codeguard](https://github.com/cosai-oasis/project-codeguard)（Coalition for Secure AI / OASIS Open Project、**CC-BY-4.0**）を**日本語へ翻訳した翻案物**です。原典からの変更点・帰属表示の詳細は [`ATTRIBUTION.md`](./ATTRIBUTION.md) を、ライセンス全文は [`LICENSE-CC-BY-4.0.md`](./LICENSE-CC-BY-4.0.md) を参照してください。

## このスキルを使うタイミング

このスキルは次の場合に有効化する:
- 任意の言語で新しいコードを書くとき
- 既存コードのレビューや変更を行うとき
- セキュリティ上重要な機能（認証、暗号、データ処理など）を実装するとき
- ユーザー入力・データベース・API・外部サービスを扱うとき
- クラウドインフラ・CI/CDパイプライン・コンテナを構成するとき
- 機密データ・認証情報・暗号処理を扱うとき

## このスキルの使い方

コードを書く・レビューするときは以下に従う:

1. 常時適用ルール（Always-Apply Rules）: 一部のルールは、**あらゆるコード操作で必ず**確認しなければならない:
- `codeguard-1-hardcoded-credentials.md` — 機密情報・パスワード・APIキー・トークンを絶対にハードコードしない
- `codeguard-1-crypto-algorithms.md` — 現代的で安全な暗号アルゴリズムのみを使用する
- `codeguard-1-digital-certificates.md` — デジタル証明書を安全に検証・管理する

2. タグベースルール（Tag-Based Rules）: コード中に以下のセキュリティコンテキストを特定したら、一致するタグを持つルールを**すべて**適用する:


| セキュリティコンテキスト（タグ） | 適用するルールファイル |
|------------------------|---------------------|
| authentication | codeguard-0-authentication-mfa.md, codeguard-0-session-management-and-cookies.md |
| data-security | codeguard-0-additional-cryptography.md, codeguard-0-data-storage.md |
| infrastructure | codeguard-0-cloud-orchestration-kubernetes.md, codeguard-0-data-storage.md, codeguard-0-devops-ci-cd-containers.md, codeguard-0-iac-security.md |
| privacy | codeguard-0-logging.md, codeguard-0-privacy-data-protection.md |
| secrets | codeguard-0-additional-cryptography.md, codeguard-1-digital-certificates.md, codeguard-1-hardcoded-credentials.md |
| web | codeguard-0-api-web-services.md, codeguard-0-authentication-mfa.md, codeguard-0-client-side-web-security.md, codeguard-0-input-validation-injection.md, codeguard-0-session-management-and-cookies.md |


3. 言語別ルール（Language-Specific Rules）: 実装する機能のプログラミング言語に応じて、`/rules` ディレクトリから以下の表に従ってルールを適用する:


| 言語 | 適用するルールファイル |
|----------|---------------------|
| apex | codeguard-0-input-validation-injection.md |
| c | codeguard-0-additional-cryptography.md, codeguard-0-api-web-services.md, codeguard-0-authentication-mfa.md, codeguard-0-authorization-access-control.md, codeguard-0-client-side-web-security.md, codeguard-0-data-storage.md, codeguard-0-file-handling-and-uploads.md, codeguard-0-framework-and-languages.md, codeguard-0-iac-security.md, codeguard-0-input-validation-injection.md, codeguard-0-logging.md, codeguard-0-safe-c-functions.md, codeguard-0-session-management-and-cookies.md, codeguard-0-xml-and-serialization.md |
| cpp | codeguard-0-safe-c-functions.md |
| d | codeguard-0-iac-security.md |
| docker | codeguard-0-devops-ci-cd-containers.md, codeguard-0-supply-chain-security.md |
| go | codeguard-0-additional-cryptography.md, codeguard-0-api-web-services.md, codeguard-0-authentication-mfa.md, codeguard-0-authorization-access-control.md, codeguard-0-file-handling-and-uploads.md, codeguard-0-input-validation-injection.md, codeguard-0-mcp-security.md, codeguard-0-session-management-and-cookies.md, codeguard-0-xml-and-serialization.md |
| hcl | codeguard-0-iac-security.md |
| html | codeguard-0-client-side-web-security.md, codeguard-0-input-validation-injection.md, codeguard-0-session-management-and-cookies.md |
| java | codeguard-0-additional-cryptography.md, codeguard-0-api-web-services.md, codeguard-0-authentication-mfa.md, codeguard-0-authorization-access-control.md, codeguard-0-file-handling-and-uploads.md, codeguard-0-framework-and-languages.md, codeguard-0-input-validation-injection.md, codeguard-0-mcp-security.md, codeguard-0-mobile-apps.md, codeguard-0-session-management-and-cookies.md, codeguard-0-xml-and-serialization.md |
| javascript | codeguard-0-additional-cryptography.md, codeguard-0-api-web-services.md, codeguard-0-authentication-mfa.md, codeguard-0-authorization-access-control.md, codeguard-0-client-side-web-security.md, codeguard-0-cloud-orchestration-kubernetes.md, codeguard-0-data-storage.md, codeguard-0-devops-ci-cd-containers.md, codeguard-0-file-handling-and-uploads.md, codeguard-0-framework-and-languages.md, codeguard-0-iac-security.md, codeguard-0-input-validation-injection.md, codeguard-0-logging.md, codeguard-0-mcp-security.md, codeguard-0-mobile-apps.md, codeguard-0-privacy-data-protection.md, codeguard-0-session-management-and-cookies.md, codeguard-0-supply-chain-security.md |
| kotlin | codeguard-0-additional-cryptography.md, codeguard-0-authentication-mfa.md, codeguard-0-framework-and-languages.md, codeguard-0-mobile-apps.md |
| matlab | codeguard-0-additional-cryptography.md, codeguard-0-authentication-mfa.md, codeguard-0-mobile-apps.md, codeguard-0-privacy-data-protection.md |
| perl | codeguard-0-mobile-apps.md |
| php | codeguard-0-additional-cryptography.md, codeguard-0-api-web-services.md, codeguard-0-authentication-mfa.md, codeguard-0-authorization-access-control.md, codeguard-0-client-side-web-security.md, codeguard-0-file-handling-and-uploads.md, codeguard-0-framework-and-languages.md, codeguard-0-input-validation-injection.md, codeguard-0-session-management-and-cookies.md, codeguard-0-xml-and-serialization.md |
| powershell | codeguard-0-devops-ci-cd-containers.md, codeguard-0-iac-security.md, codeguard-0-input-validation-injection.md |
| python | codeguard-0-additional-cryptography.md, codeguard-0-api-web-services.md, codeguard-0-authentication-mfa.md, codeguard-0-authorization-access-control.md, codeguard-0-file-handling-and-uploads.md, codeguard-0-framework-and-languages.md, codeguard-0-input-validation-injection.md, codeguard-0-mcp-security.md, codeguard-0-session-management-and-cookies.md, codeguard-0-xml-and-serialization.md |
| ruby | codeguard-0-additional-cryptography.md, codeguard-0-api-web-services.md, codeguard-0-authentication-mfa.md, codeguard-0-authorization-access-control.md, codeguard-0-file-handling-and-uploads.md, codeguard-0-framework-and-languages.md, codeguard-0-iac-security.md, codeguard-0-input-validation-injection.md, codeguard-0-session-management-and-cookies.md, codeguard-0-xml-and-serialization.md |
| rust | codeguard-0-mcp-security.md |
| shell | codeguard-0-devops-ci-cd-containers.md, codeguard-0-iac-security.md, codeguard-0-input-validation-injection.md |
| sql | codeguard-0-data-storage.md, codeguard-0-input-validation-injection.md |
| swift | codeguard-0-additional-cryptography.md, codeguard-0-authentication-mfa.md, codeguard-0-mobile-apps.md |
| typescript | codeguard-0-additional-cryptography.md, codeguard-0-api-web-services.md, codeguard-0-authentication-mfa.md, codeguard-0-authorization-access-control.md, codeguard-0-client-side-web-security.md, codeguard-0-file-handling-and-uploads.md, codeguard-0-framework-and-languages.md, codeguard-0-input-validation-injection.md, codeguard-0-mcp-security.md, codeguard-0-session-management-and-cookies.md |
| vlang | codeguard-0-client-side-web-security.md |
| xml | codeguard-0-additional-cryptography.md, codeguard-0-api-web-services.md, codeguard-0-devops-ci-cd-containers.md, codeguard-0-framework-and-languages.md, codeguard-0-mobile-apps.md, codeguard-0-xml-and-serialization.md |
| yaml | codeguard-0-additional-cryptography.md, codeguard-0-api-web-services.md, codeguard-0-authorization-access-control.md, codeguard-0-cloud-orchestration-kubernetes.md, codeguard-0-data-storage.md, codeguard-0-devops-ci-cd-containers.md, codeguard-0-framework-and-languages.md, codeguard-0-iac-security.md, codeguard-0-logging.md, codeguard-0-privacy-data-protection.md, codeguard-0-supply-chain-security.md |


4. プロアクティブセキュリティ（Proactive Security）: 脆弱性を避けるだけでなく、安全なパターンを能動的に実装する:
- データベースアクセスにはパラメータ化クエリを使う
- すべてのユーザー入力を検証・サニタイズする
- 最小権限の原則を適用する
- 現代的な暗号アルゴリズムとライブラリを使う
- 多層防御（defense-in-depth）戦略を実装する

## CodeGuard セキュリティルール

セキュリティルールは `rules/` ディレクトリに格納されている。

### 利用ワークフロー

コードを生成・レビューするときは、次のワークフローに従う:

### 1. 初期セキュリティチェック

コードを書く前に:
- 確認: これは認証情報を扱うか？ → codeguard-1-hardcoded-credentials を適用
- 確認: どのセキュリティタグが該当するか？ → 一致するタグ（例: "authentication", "web", "secrets"）を持つルールをすべてロード
- 確認: どの言語を使っているか？ → 該当する言語別ルールを特定

### 2. コード生成

コードを書きながら:
- 関連する Project CodeGuard ルールのセキュアバイデフォルトのパターンを適用する
- 選択理由を説明するセキュリティ関連コメントを追加する

### 3. セキュリティレビュー

コードを書いた後に:
- 各ルールの実装チェックリストと照合してレビューする
- ハードコードされた認証情報・機密情報が無いことを確認する
- 該当するすべてのルールが正しく守られているか検証する
- 適用したセキュリティルールを説明する
- 実装したセキュリティ機能を強調して示す
