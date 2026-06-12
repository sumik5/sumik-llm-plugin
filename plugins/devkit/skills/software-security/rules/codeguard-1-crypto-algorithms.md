---
description: 暗号セキュリティガイドライン & ポスト量子対応
alwaysApply: true
---

rule_id: codeguard-1-crypto-algorithms

# 暗号セキュリティガイドライン & ポスト量子対応

## 1. 禁止済み（安全でない）アルゴリズム

以下のアルゴリズムは破られているか、根本的に安全でないことが知られている。これらのアルゴリズムを使用したコードは絶対に生成・使用してはならない。

*   ハッシュ: `MD2`, `MD4`, `MD5`, `SHA-0`
*   対称: `RC2`, `RC4`, `Blowfish`, `DES`, `3DES`
*   鍵交換: 静的RSA、匿名Diffie-Hellman
*   古典: `Vigenère`

理由: これらは暗号学的に破られており、衝突攻撃または中間者攻撃に対して脆弱である。

## 2. 非推奨（レガシー/弱い）アルゴリズム

以下のアルゴリズムには既知の弱点があるか、時代遅れとみなされている。新しい設計では使用を避け、移行を優先する。

*   ハッシュ: `SHA-1`
*   対称: `AES-CBC`, `AES-ECB`
*   署名: `PKCS#1 v1.5` パディングを使用したRSA
*   鍵交換: 弱い/一般的な素数を使用したDHE

## 3. 推奨・ポスト量子対応アルゴリズム

古典的脅威と量子的脅威の両方に対する耐性を確保するために、これらの現代的かつ安全なアルゴリズムを実装する。

### 対称暗号化
*   標準: `AES-GCM`（AEAD）、`ChaCha20-Poly1305`（許可されている場合）。
*   PQC要件: 量子攻撃（Groverのアルゴリズム）に耐性があるAES-256鍵（またはそれ以上）を優先する。
*   避けること: カスタム暗号または認証なしモード。

### 鍵交換（KEM）
*   標準: ECDHE（`X25519` または `secp256r1`）
*   PQC要件: サポートされている場合はハイブリッド鍵交換（古典 + PQC）を使用する。
    *   推奨: `X25519MLKEM768`（X25519 + ML-KEM-768）
    *   代替: `SecP256r1MLKEM768`（P-256 + ML-KEM-768）
    *   高保証: `SecP384r1MLKEM1024`（P-384 + ML-KEM-1024）
*   純粋PQC: ML-KEM-768（ベースライン）またはML-KEM-1024。明示的にリスク受容しない限りML-KEM-512は避ける。
*   制約:
    *   ベンダーが文書化した識別子を使用する（RFC 9242/9370）。
    *   レガシー/ドラフトの「Hybrid-Kyber」グループ（例: `X25519Kyber`）およびドラフトまたはハードコードされたOIDを削除する。

### 署名・証明書
*   標準: ECDSA（`P-256`）
*   PQC移行: ハードウェアバックアップ（HSM/TPM）のML-DSAが利用可能になるまで、mTLSとコード署名にはECDSA（`P-256`）を引き続き使用する。
*   ハードウェア要件: ソフトウェアのみの鍵を使用したPQC ML-DSA署名は有効化しない。HSM/TPMストレージを要求する。

### プロトコルバージョン
*   (D)TLS: (D)TLS 1.3のみ（またはそれ以降）を強制する。
*   IPsec: IKEv2のみを強制する。
    *   AEADを使用したESPを使用する（AES-256-GCM）。
    *   ECDHEによるPFSを要求する。
    *   ハイブリッドPQC（ML-KEM + ECDHE）のためにRFC 9242およびRFC 9370を実装する。
    *   再鍵交換（CREATE_CHILD_SA）がハイブリッドアルゴリズムを維持することを確認する。
*   SSH: ベンダーがサポートするPQC/ハイブリッドKEXのみを有効化する（例: `sntrup761x25519`）。

## 4. 安全な実装ガイドライン

### 一般的なベストプラクティス
*   コードよりも設定: コード変更なしでアジリティを持てるよう、アルゴリズムの選択を設定/ポリシーに公開する。
*   鍵管理:
    *   鍵の保管にはKMS/HSMを使用する。
    *   CSPRNGで鍵を生成する。
    *   暗号化鍵と署名鍵を分離する。
    *   ポリシーに従って鍵をローテーションする。
    *   鍵・機密情報・実験的OIDを絶対にハードコードしてはならない。
*   テレメトリ: PQC採用を監視するために、ネゴシエートされたグループ、ハンドシェイクサイズ、失敗原因を記録する。

### 非推奨SSL/Crypto API（C/OpenSSL）- 使用禁止
これらの非推奨関数は絶対に使用してはならない。代替のEVP高レベルAPIを使用する。

#### 対称暗号化（AES）
- 非推奨: `AES_encrypt()`, `AES_decrypt()`
- 代替:

  EVP_EncryptInit_ex()   // Use EVP_aes_256_gcm() for PQC readiness
  EVP_EncryptUpdate()
  EVP_EncryptFinal_ex()


#### RSA/PKEY操作
- 非推奨: `RSA_new()`, `RSA_free()`, `RSA_get0_n()`
- 代替:

  EVP_PKEY_new()
  EVP_PKEY_up_ref()
  EVP_PKEY_free()
 

#### ハッシュ・MAC関数
- 非推奨: `SHA1_Init()`, `HMAC()`（特にSHA1使用時）
- 代替:

  EVP_DigestInit_ex() // Use SHA-256 or stronger
  EVP_Q_MAC()         // For one-shot MAC


## 5. Broccoliプロジェクト固有の要件
- SHA1を使用した`HMAC()`: 非推奨。
- 代替: SHA-256以上を使用したHMACを使用する:


// Example: Secure replacement for HMAC-SHA1
```c
EVP_Q_MAC(NULL, "HMAC", NULL, "SHA256", NULL, key, key_len, data, data_len, out, out_size, &out_len);
```

## 6. 安全な暗号実装パターン


// Example: Secure AES-256-GCM encryption (PQC-Ready Symmetric Strength)
```c
EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
if (!ctx) handle_error();

// Use AES-256-GCM
if (EVP_EncryptInit_ex(ctx, EVP_aes_256_gcm(), NULL, key, iv) != 1)
    handle_error();

int len, ciphertext_len;
if (EVP_EncryptUpdate(ctx, ciphertext, &len, plaintext, plaintext_len) != 1)
    handle_error();
ciphertext_len = len;

if (EVP_EncryptFinal_ex(ctx, ciphertext + len, &len) != 1)
    handle_error();
ciphertext_len += len;

EVP_CIPHER_CTX_free(ctx);
```
