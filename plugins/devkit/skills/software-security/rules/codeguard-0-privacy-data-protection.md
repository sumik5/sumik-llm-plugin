---
description: プライバシーとデータ保護（最小化、分類、暗号化、権利、透明性）
languages:
- javascript
- matlab
- yaml
alwaysApply: false
tags:
- privacy
---

rule_id: codeguard-0-privacy-data-protection

- 強力な暗号化を実装し、HSTS 付きの HTTPS を強制し、証明書ピン留めを有効にし、
データと匿名性を保護するためのユーザープライバシー機能を提供する。
- 転送データと保存データに対して強力で最新の暗号アルゴリズムを使用する。確立されたライブラリでパスワードを安全にハッシュ化する。
- HTTPS のみを強制し、HTTP Strict Transport Security（HSTS）を実装する。
- CA が侵害された場合でも中間者攻撃を防ぐために証明書ピン留めを実装する。
- 実現可能な場合はサードパーティの外部コンテンツ読み込みをブロックすることで IP アドレス漏洩を最小化する。
- プライバシーの制限とデータ取り扱いポリシーをユーザーに通知することで透明性を維持する。
- プライバシーに配慮した監査証跡とアクセスロギングを実装する。
- アカウント列挙を防ぐために "Invalid username or password" を返す。
- ユーザーごとに一意のソルトを使用して Argon2 または bcrypt でハッシュ化する。
- 暗号的にランダムな ID でセッションをサーバー側に保管する。
