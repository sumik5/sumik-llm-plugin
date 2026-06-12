---
description: 証明書のベストプラクティス
alwaysApply: true
tags:
- secrets
---

rule_id: codeguard-1-digital-certificates

X.509 証明書と思われるデータ（文字列として埋め込まれているか、ファイルから読み込まれているかを問わず）に遭遇した場合は、その証明書に検証フラグを立て、以下のセキュリティプロパティが検証されるようにする。懸念事項は明確な説明と推奨アクションとともに報告する。

### 1. 証明書データの識別方法

以下のヒューリスティックを使用して証明書データを積極的にスキャンする：

- PEM エンコード文字列：`-----BEGIN CERTIFICATE-----` で始まり `-----END CERTIFICATE-----` で終わる複数行の文字列リテラルまたは定数を識別する。

- ファイル操作：`.pem`、`.crt`、`.cer`、`.der` などの一般的な証明書拡張子を持つファイルの読み取り操作に特に注意する。

- ライブラリ関数呼び出し：証明書のロードまたは解析に使用される暗号ライブラリの関数の使用を認識する（例：OpenSSL の `PEM_read_X509`、Python の `cryptography.x509.load_pem_x509_certificate`、Java の `CertificateFactory`）。


### 2. 必須の健全性チェック

証明書データが識別されたら、検証フラグを立てる。証明書がセキュリティ要件を満たすことを確認するため、以下のプロパティを必ず検証する：

#### 検証ガイダンス

証明書プロパティを検査するには、以下のコマンドの実行を推奨する：
```
openssl x509 -text -noout -in <certificate_file>
```

このコマンドは、以下のチェックに必要な有効期限日、鍵アルゴリズムとサイズ、署名アルゴリズム、発行者・サブジェクト情報を表示する。

#### チェック1：有効期限の状態

- 条件：証明書の `notAfter`（有効期限）日付が過去である。

- 深刻度：重大な脆弱性

- 報告メッセージ：`This certificate expired on [YYYY-MM-DD]. It is no longer valid and will be rejected by clients, causing connection failures. It must be renewed and replaced immediately.`

- 条件：証明書の `notBefore`（有効期間開始）日付が未来である。

- 深刻度：警告

- 報告メッセージ：`This certificate is not yet valid. Its validity period begins on [YYYY-MM-DD].`


#### チェック2：公開鍵の強度

- 条件：公開鍵アルゴリズムまたはサイズが脆弱である。

    - 脆弱な鍵：モジュラスが 2048 ビット未満の RSA 鍵。256 ビット未満の素数モジュラスを使用する曲線の楕円曲線（EC）鍵（例：`secp192r1`、`P-192`、`P-224`）。

- 深刻度：高優先度の警告

- 報告メッセージ：`The certificate's public key is cryptographically weak ([Algorithm], [Key Size]). Keys of this strength are vulnerable to factorization or discrete logarithm attacks. The certificate should be re-issued using at least an RSA 2048-bit key or an ECDSA key on a P-256 (or higher) curve.`


#### チェック3：署名アルゴリズム

- 条件：証明書の署名に使用されたアルゴリズムが安全でない。

    - 安全でないアルゴリズム：MD5 または SHA-1 を使用する署名アルゴリズム（例：`md5WithRSAEncryption`、`sha1WithRSAEncryption`）。

- 深刻度：高優先度の警告

- 報告メッセージ：`The certificate is signed with the insecure algorithm '[Algorithm]'. This makes it vulnerable to collision attacks, potentially allowing for certificate forgery. It must be re-issued using a signature based on the SHA-2 family (e.g., sha256WithRSAEncryption).`


#### チェック4：発行者タイプ（自己署名チェック）

- 条件：証明書の `Issuer` フィールドと `Subject` フィールドが同一である。

- 深刻度：情報提供

- 報告メッセージ：`This is a self-signed certificate. Ensure this is intentional and only used for development, testing, or internal services where trust is explicitly configured. Self-signed certificates should never be used for public-facing production systems as they will not be trusted by browsers or standard clients.`


### 3. 実行可能な例

フィードバックは直接的でわかりやすいものにする。

Example 1: Flagging a Hardcoded Certificate

- Code Snippet:

    ```
    # Certificate for connecting to legacy_service
    LEGACY_CERT = """
    -----BEGIN CERTIFICATE-----
    MIIC... (certificate data) ...
    -----END CERTIFICATE-----
    """
    ```

- Your Analysis and Report:

    > Security Review Required: A certificate is hardcoded in the `LEGACY_CERT` variable. Unverified certificates may contain critical vulnerabilities.
    >
    > - Concern: Hardcoded certificates cannot be easily rotated and may contain security issues that are not immediately visible in the code.
    >
    > - Required Verification: This certificate must be verified for:
    >   - Expiration: Certificate must not be expired or not yet valid
    >   - Key Strength: RSA keys must be at least 2048-bit; EC keys must use P-256 or higher curve
    >   - Signature Algorithm: Must use SHA-2 family (not MD5 or SHA-1)
    >   - Self-Signed: If self-signed, must only be used for development, testing, or internal services
    >
    > - Action: Verify this certificate meets the above requirements before deployment. Consider loading certificates from external files or a certificate store for easier rotation.
    >


Example 2: Flagging a Certificate Loaded from File

- Code Snippet:

    ```
    // Load the server certificate from disk
    cert, err := tls.LoadX509KeyPair("server.crt", "server.key")
    ```

- Your Analysis and Report:

    > Security Review Required: Certificate loaded from `server.crt`. Unverified certificates may contain critical vulnerabilities.
    >
    > - Required Verification: Ensure this certificate meets security requirements:
    >   - Expiration: Certificate must not be expired or not yet valid
    >   - Key Strength: RSA keys must be at least 2048-bit; EC keys must use P-256 or higher curve
    >   - Signature Algorithm: Must use SHA-2 family (not MD5 or SHA-1)
    >   - Self-Signed: If self-signed, must only be used for development, testing, or internal services
    >
    > - Action: Verify this certificate meets the above requirements before deployment.


常にこのルールがどのように、なぜ適用されたかを説明しなければならない。
