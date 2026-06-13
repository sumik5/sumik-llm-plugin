# Webアプリケーションセキュリティ評価 リファレンス

> **前提**: 本リファレンスの全技術は、**自組織が管理・所有するシステムへの認可された評価**を前提とする。
> 外部サービス・他者のシステムへの無断スキャンは違法である。

---

## 1. Webアプリケーションセキュリティ評価の概要

### なぜ定期的な脆弱性評価が必要か

現代のWebアプリケーションはSQL DBとスクリプト言語で構成され、複雑な攻撃面を持つ。定期的な評価を実施することで:

- **悪意ある第三者より先に脆弱性を発見・修正**できる
- **OWASP Top 10**（SQLインジェクション、コマンドインジェクション等）を自組織環境で検証できる
- コンプライアンス（PCI DSS、SOC2等）要件を満たすエビデンスを取得できる

### 評価フロー（防御者視点）

```
1. 認可確認・スコープ確定（文書化必須）
2. 偵察・サーバー設定監査（Nikto）
3. ディレクトリ・リソース棚卸し（dirb / gobuster）
4. 情報漏洩リスク確認（robots.txt監査）
5. 入力バリデーション検証（SQLMap / Commix）
6. 結果の文書化・レポート生成
7. 修正・再評価
```

---

## 2. Niktoによるサーバー設定監査

Niktoは自組織Webサーバーの設定ミス・既知脆弱性を検出するFOSSスキャナー。

### Niktoが検出するもの

| 検出カテゴリ | 内容 |
|------------|------|
| 危険なファイル | `/phpinfo.php`、テストスクリプト等の公開 |
| ソフトウェアバージョン | 古いApache、PHP等（CVE参照） |
| 設定ミス | X-Frame-Options欠落（クリックジャッキング）、ディレクトリ一覧公開 |
| 情報漏洩 | パスワードファイル、設定ファイルの公開 |

### 基本スキャンコマンド

```bash
# HTTP（port 80）の基本スキャン
./nikto.pl -h <対象IPまたはURL>

# HTTPS（port 443）スキャン - HTMLレポートを出力
./nikto.pl -ssl -h <対象URL> -output audit_report.html

# 非標準ポートのスキャン
./nikto.pl -h <対象IP> -ssl -port <ポート番号> -output report.html

# SQLインジェクション脆弱性のみに絞ったスキャン（-Tuning 9）
./nikto.pl -h <対象IP> -Tuning 9 -output sqli_audit.html
```

### 出力形式

`-output` オプションに拡張子を指定するだけで形式が変わる:
- `.html` / `.txt` / `.csv` / `.json` / `.xml` / `.sql` / `.nbe`

### 複数ターゲットの自動スキャンスクリプト

認可された複数サーバーをまとめて評価する場合:

```bash
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# 注意: 以下の対象はすべて自組織の管理下にあること（認可確認済み）
REPORT_DIR="nikto_audit_$(date +%Y%m%d_%H%M%S)"
mkdir -p "${REPORT_DIR}"

log_msg() { echo "[$(date +%H:%M:%S)] $*" | tee -a "${REPORT_DIR}/scan.log"; }

scan_host() {
    local HOST="${1:?ホストが必要}"
    local LABEL="${2:-host}"
    log_msg "スキャン開始: ${HOST}"
    ./nikto.pl -h "${HOST}" -output "${REPORT_DIR}/${LABEL}.html"
    log_msg "完了: ${REPORT_DIR}/${LABEL}.html"
}

# 認可された対象のみスキャン（IPアドレスはダミー）
scan_host "192.0.2.10"              "webserver-main"
scan_host "http://192.0.2.10/api"  "webserver-api"

log_msg "全スキャン完了。レポート: ${REPORT_DIR}/"
```

### 評価ポイント（修正推奨事項）

- `phpinfo.php` 等のテストページは本番環境から削除する
- `X-Frame-Options` ヘッダーを設定してクリックジャッキングを防止する
- 古いソフトウェアバージョンは速やかにパッチ適用または更新する
- TLS暗号スイートを量子耐性アルゴリズム（SHA384/SHA512等）へ移行計画を立てる

---

## 3. ディレクトリ・リソース列挙（dirb / gobuster）

### 目的

意図せず公開されているディレクトリ・ファイルを棚卸しし、不要な公開を排除する。

### dirbによるディレクトリスキャン

```bash
# 基本スキャン（結果をファイルに保存）
dirb http://<対象IP> -o audit_dirb.txt

# 大文字小文字を区別しないスキャン
dirb http://<対象IP>/app1 -o app1_dirb.txt -i

# 特定のワードリストを使用（Apache固有の検索）
dirb https://<対象URL> /usr/share/dirb/wordlists/vulns/apache.txt
```

### ワードリスト（Kali Linux標準）

| ファイル | 用途 |
|---------|------|
| `common.txt` | 一般的なパス（4,612語） |
| `big.txt` | より広範な検索 |
| `vulns/apache.txt` | Apache固有の脆弱パス |

### 要注意パターン（公開されていたら修正）

```
/admin/       → 管理パネル（アクセス制御を必ず確認）
/backup/      → バックアップファイル（機密情報漏洩リスク）
/dev/ /test/  → 開発用ファイル（本番に残存していないか確認）
/config.ini   → 設定ファイル（認証情報漏洩リスク）
/phpMyAdmin/  → データベース管理UI（外部公開は危険）
```

### インデックス可能ディレクトリ検出スクリプト

```bash
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

TARGET_FILE="${1:?使用方法: $0 target_list.txt}"
REPORT_DIR="${2:-indexable_scan_reports}"

mapfile -t SCAN_TARGETS < "${TARGET_FILE}"

for TARGET in "${SCAN_TARGETS[@]}"; do
    echo "インデックス確認中: ${TARGET}"
    # "Index of /" または "[PARENTDIR]" が含まれていればディレクトリ一覧公開
    if curl -L -s "${TARGET}" | grep -q -e "Index of /" -e "\[PARENTDIR\]"; then
        echo "  → 公開ディレクトリを検出: ${TARGET}"
        mkdir -p "${REPORT_DIR}"
        # 証拠収集・修正確認用にダウンロード（-np: 親ディレクトリには遡らない）
        wget -q -r -np -R "index.html*" "${TARGET}" -P "${REPORT_DIR}"
    fi
done
```

> **注意**: ダウンロードには大量のストレージが必要な場合がある。大規模サイトでは対象ディレクトリを絞ること。

---

## 4. robots.txt監査

### robots.txtとは

Webクローラー向けに「インデックス除外」を指示するファイル。セキュリティ上の問題として:

- 「除外」したいパス（管理画面、バックアップ等）が**逆に機密情報の露出**になる
- 検索エンジンはこれを尊重するが、アクセス制御は行わない

### robots.txtの典型的な危険パターン

以下がDisallowに記載されていると、機密情報の存在を示唆してしまう:

```
Disallow: /?server-status   → サーバー状態（パスワードを含む場合あり）
Disallow: /admin/           → 管理パネル
Disallow: /backup/          → バックアップファイル
Disallow: /config.ini       → 設定ファイル
```

### 自動監査スクリプト

```bash
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

TARGET_FILE="${1:?使用方法: $0 target_list.txt}"
OUTPUT_DIR="robots_audit_results"

# 一時ファイルクリーンアップ
rm -f robots.txt tmpfile.txt

mapfile -t SCAN_TARGETS < "${TARGET_FILE}"

for TARGET in "${SCAN_TARGETS[@]}"; do
    echo "robots.txt確認中: ${TARGET}"
    curl -s "${TARGET}/robots.txt" -o robots.txt

    if [[ -f robots.txt ]] && grep -q 'Disallow: ' robots.txt; then
        echo "  → robots.txtを検出: ${TARGET}"
        mkdir -p "${OUTPUT_DIR}/${TARGET}"

        # Disallowされた各パスのHTTPステータスを確認
        awk -F'Disallow: ' '{print $2}' robots.txt > tmpfile.txt
        mapfile -t LINES < tmpfile.txt

        for ENTRY in "${LINES[@]}"; do
            [[ -z "${ENTRY}" ]] && continue
            STATUS="$(curl -s -o /dev/null -w "%{http_code}" "${TARGET}/${ENTRY}")"
            echo "ステータス ${STATUS}: ${TARGET}/${ENTRY}" \
                | tee -a "${OUTPUT_DIR}/${TARGET}/robots_audit.txt"
        done

        rm -f robots.txt tmpfile.txt
    else
        echo "  → robots.txtなし: ${TARGET}"
    fi
done
```

### ステータスコードの評価

| ステータス | 意味 | 対応 |
|-----------|------|------|
| 200 | アクセス可能 | 内容確認・アクセス制御を検討 |
| 301/302 | リダイレクト | リダイレクト先を確認 |
| 403 | Forbidden | 適切に保護されている |
| 404 | 存在しない | 問題なし |

---

## 5. SQLインジェクション脆弱性検証（SQLMap）

### 評価の目的

自組織のWebアプリケーションにSQLインジェクション脆弱性が存在しないかを検証する。認可された環境でのみ実施する。

### SQLインジェクションとは

SQLを使うWebアプリに対し、不正なSQLコードを入力することでデータベースを不正操作できる脆弱性。OWASPが最重要脆弱性の一つとして分類。

悪影響の例: ユーザーIDのなりすまし・機密データへの不正アクセス・データ改ざん・破壊

### GETパラメーターの脆弱性検証

```bash
# 前提: 自組織アプリへの認可済み評価
# セッションCookieはブラウザの開発者ツールで取得（ネットワーク → ヘッダー → Cookie）

# 基本的な脆弱性検証
sqlmap -u "http://<対象IP>/app/page?id=1&Submit=Submit" \
    --cookie="PHPSESSID=<セッションID>" \
    --risk=3 --level=5

# データベース一覧の確認
sqlmap -u "http://<対象IP>/app/page?id=1&Submit=Submit" \
    --cookie="PHPSESSID=<セッションID>" \
    --risk=3 --level=5 --dbs

# テーブル一覧の確認
sqlmap -u "http://<対象IP>/app/page?id=1&Submit=Submit" \
    --cookie="PHPSESSID=<セッションID>" \
    --risk=3 --level=5 \
    --tables -D <データベース名>
```

### POSTパラメーターの脆弱性検証

```bash
# ログインフォームの検証（--data でPOSTパラメーターを指定）
sqlmap -u "http://<対象IP>/app/login.php" \
    --data="username=user&password=pass&login-button=Login" \
    --level=5 --risk=3

# データベース一覧確認
sqlmap -u "http://<対象IP>/app/login.php" \
    --data="username=user&password=pass&login-button=Login" \
    --level=5 --risk=3 --dbs
```

### 脆弱性検出時の推奨修正事項

| 発見事項 | 修正推奨 |
|---------|---------|
| MD5ハッシュでパスワード保存 | SHA384/SHA512等の量子耐性アルゴリズムへ移行 |
| 辞書攻撃で解読可能なパスワード | 強力なパスワードポリシーを適用 |
| 機密データが平文で保存されている | AES256等で暗号化 |
| SQLインジェクション脆弱性 | **プリペアドステートメント / パラメーター化クエリ**を使用 |

---

## 6. コマンドインジェクション脆弱性検証（Commix）

### 評価の目的

Webアプリケーションのユーザー入力フィールドがOSコマンドの実行を許していないかを確認する。

### 脆弱性の原理

ユーザー入力を適切に検証せずにOSコマンドに渡すと、`;`・`|`・`&`・`||`・`&&`等の文字を使って任意のOSコマンドが実行可能になる。

### 入力バリデーションのアプローチ比較

| アプローチ | 安全性 | 説明 |
|-----------|-------|------|
| **ホワイトリスト方式** | ✅ 高 | 許可する入力形式を明示的に定義（例: IPアドレスのみ受け付ける場合、4オクテットの数値のみ許可） |
| **ブラックリスト方式** | ⚠️ 低 | 危険な文字を除外するが漏れが出やすい（`&&`・`;` を除外しても `\|`・`\|\|` でバイパス可能） |

**推奨**: 入力バリデーションは常にホワイトリスト方式で実装する。

### Commixによるスキャン（認可された環境）

```bash
# Cookieとデータパラメーターを使用した検証
# （ブラウザ開発者ツールでCookieとPOSTデータを取得）
commix -u "http://<対象IP>/app/exec/" \
    --data="ip=192.168.1.1&submit=submit" \
    --cookie="PHPSESSID=<セッションID>"
```

### コマンドインジェクションの分類

| 種類 | 特徴 | 検証方法 |
|------|------|---------|
| Results-based（結果表示型） | コマンド出力がページに表示される | 比較的容易に確認可能 |
| Blind（盲目型） | 出力は見えないが実行は成功している | 時間差（SLEEP等）で確認 |

### 修正推奨事項

1. ユーザー入力は**ホワイトリスト方式**でバリデーション（許可する形式を明示的に定義）
2. OSコマンド呼び出し関数へのユーザー入力の直接渡しを避ける
3. `|`・`;`・`&`等を除外するブラックリストは不完全なため非推奨
4. どうしてもOSコマンドが必要な場合は引数をエスケープしてから渡す

---

## 7. 評価結果の自動レポート化

### 包括的評価スクリプト（テンプレート）

```bash
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ============================================================
# Webアプリケーションセキュリティ評価スクリプト
# 前提: すべての対象は自組織が管理・認可済みであること
# ============================================================

REPORT_BASE="web_security_audit_$(date +%Y%m%d)"
mkdir -p "${REPORT_BASE}"/{nikto,dirb,robots}

log_msg() { echo "[$(date +%H:%M:%S)] $*" | tee -a "${REPORT_BASE}/audit.log"; }

# Niktoスキャン
run_nikto_scan() {
    local TARGET="${1:?ターゲットが必要}"
    local LABEL="${2:-target}"
    log_msg "Niktoスキャン開始: ${TARGET}"
    ./nikto.pl -h "${TARGET}" -output "${REPORT_BASE}/nikto/${LABEL}.html"
}

# ディレクトリ列挙
run_dirb_scan() {
    local TARGET="${1:?ターゲットが必要}"
    local LABEL="${2:-target}"
    log_msg "ディレクトリ列挙開始: ${TARGET}"
    dirb "${TARGET}" -o "${REPORT_BASE}/dirb/${LABEL}.txt"
}

log_msg "評価開始: ${REPORT_BASE}"
# 認可された対象を指定
run_nikto_scan "http://192.0.2.10"      "main-server"
run_dirb_scan  "http://192.0.2.10"      "main-server"
log_msg "評価完了。レポート: ${REPORT_BASE}/"
```

### レポート構成（推奨）

```
web_security_audit_YYYYMMDD/
├── audit.log              # 実行ログ
├── nikto/                 # Niktoスキャン結果
│   └── main-server.html
├── dirb/                  # ディレクトリ列挙結果
│   └── main-server.txt
├── robots/                # robots.txt監査結果
│   └── target-robots_audit.txt
└── summary.md             # 発見事項まとめ・修正推奨事項
```

---

## 8. セキュリティ評価チェックリスト

### 実施前確認

- [ ] 評価スコープ（対象URL・IP・機能）を文書化した
- [ ] 権限保有者（組織管理者）から書面による認可を取得した
- [ ] 評価期間・メンテナンスウィンドウを確認した
- [ ] 機密データを発見した場合の取り扱い手順を確認した

### 評価項目

- [ ] Niktoスキャン（設定ミス・既知脆弱性）
- [ ] ディレクトリ列挙（公開リソースの棚卸し）
- [ ] robots.txt監査（情報漏洩リスク）
- [ ] SQLインジェクション脆弱性の有無（SQLMap）
- [ ] コマンドインジェクション脆弱性の有無（Commix）
- [ ] Cookie設定（secure/httponly フラグ）
- [ ] TLS暗号スイートの確認

### 修正優先度の基準

| 重要度 | 条件例 | 対応期限 |
|-------|-------|---------|
| 緊急 | 認証情報の平文公開、SQLi確認 | 即時（24時間以内） |
| 高 | ディレクトリ一覧公開、未認証admin | 1週間以内 |
| 中 | HTTPSヘッダー欠落、旧バージョン | 1ヶ月以内 |
| 低 | 情報漏洩の可能性（バージョン表示等） | 次回メンテナンス時 |
