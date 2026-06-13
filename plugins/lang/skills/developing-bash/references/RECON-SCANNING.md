# Nmap偵察・スキャニング自動化

> **⚠️ 重要**: 本リファレンスの技術は**認可されたセキュリティテスト・防御的セキュリティ**の目的のみに使用すること。
> 対象ネットワーク・システムの所有者から書面による許可を得た上で実施すること。

---

## Nmapとは

**Nmap（Network Mapper）** はオープンソースのネットワーク探索・セキュリティ監査ツール。認可されたネットワーク上でオープンポート特定・サービス検出・OS識別などを行うためにセキュリティ専門家・ネットワーク管理者が活用する。

### Bash自動化の利点

| 利点 | 説明 |
|------|------|
| **一貫性** | スキャンを同じ手順で繰り返し実行でき、ヒューマンエラーを排除 |
| **効率性** | 複雑なスキャンシーケンスを最小の手動操作で実行 |
| **スケジューリング** | cronで定期的な監視・脆弱性評価を自動実行 |
| **再現性** | スクリプト化により、チーム間でスキャン手順を共有・再現 |
| **スケーラビリティ** | 複数ターゲット・IPレンジ・サブネット全体を一括管理 |

---

## スキャンタイプ

### TCPスキャンタイプ一覧

| スキャン | オプション | 特徴 | 検出リスク |
|---------|-----------|------|-----------|
| TCP Connect | `-sT` | 完全な3ウェイハンドシェイク。信頼性高い | 高 |
| SYN（ステルス） | `-sS` | SYNパケットのみ送信。ハンドシェイク未完了 | 低 |
| UDP | `-sU` | UDPポートをスキャン。コネクションレス | 中 |
| Null | `-sN` | フラグなしTCPパケット。一部FWをバイパス | 低 |
| FIN | `-sF` | FINフラグのみ。一部FWをバイパス | 低 |
| Xmas | `-sX` | FIN+PSH+URGフラグ。特殊な応答を誘発 | 低 |
| バージョン検出 | `-sV` | サービス・バージョン情報を取得 | 中 |

### SYNスキャンが無効なケース

- ステートフルFW（不完全なハンドシェイクをブロック）
- SYNフラッド対策機構を実装しているネットワーク
- プロキシサーバーやNATデバイス配下のシステム

---

## 基本的なNmapスクリプト

### シンプルなTCP Connectスキャン

```bash
#!/usr/bin/env bash
set -euo pipefail

# スキャン対象のIPレンジ（認可済みの範囲のみ）
readonly TARGET_RANGE="${1:?使用法: $0 <target_range>}"
readonly OUTPUT_FILE="scan_$(date +%Y%m%d_%H%M%S).txt"

# TCP connectスキャンを実行し結果をファイルに保存
nmap -sT -oN "${OUTPUT_FILE}" "${TARGET_RANGE}"

echo "スキャン完了: ${OUTPUT_FILE}"
```

### 複数ターゲットをファイルから読み込む

```bash
#!/usr/bin/env bash
set -euo pipefail

readonly TARGETS_FILE="${1:?使用法: $0 <targets_file>}"
readonly OUTPUT_DIR="./scan_results"

# 出力ディレクトリ作成
mkdir -p "${OUTPUT_DIR}"

# ターゲット一覧を配列に読み込む
mapfile -t targets < "${TARGETS_FILE}"

echo "スキャン対象: ${#targets[@]} ホスト"

for target in "${targets[@]}"; do
    echo "スキャン中: ${target}"
    nmap -sT -sV -oN "${OUTPUT_DIR}/${target//\//_}.txt" "${target}"
done

echo "全スキャン完了"
```

---

## 結果のパース・フォーマット

### テーブル形式で出力する関数

```bash
#!/usr/bin/env bash
set -euo pipefail

# TCP スキャン結果をテーブル形式で表示
print_tcp_table() {
    local scan_results="$1"

    echo "+-----------------+------------+"
    echo "|      Port       |   Status   |"
    echo "+-----------------+------------+"

    while IFS= read -r line; do
        local port status
        port=$(echo "${line}" | awk '{print $1}')
        status=$(echo "${line}" | awk '{print $2}')
        printf "| %-15s | %-10s |\n" "${port}" "${status}"
    done <<< "${scan_results}"

    echo "+-----------------+------------+"
}

# バージョン検出結果をテーブル形式で表示
print_version_table() {
    local scan_results="$1"

    echo "+----------+--------+----------+------------------------------------------+"
    echo "| Port     | Status | Protocol | Version                                  |"
    echo "+----------+--------+----------+------------------------------------------+"

    while IFS= read -r line; do
        local port status protocol version
        port=$(echo "${line}" | awk '{print $1}')
        status=$(echo "${line}" | awk '{print $2}')
        protocol=$(echo "${line}" | awk '{print $3}')
        version=$(echo "${line}" | cut -d' ' -f4-)
        printf "| %-8s | %-6s | %-8s | %-40s |\n" \
            "${port}" "${status}" "${protocol}" "${version}"
    done <<< "${scan_results}"

    echo "+----------+--------+----------+------------------------------------------+"
}

# メイン処理
readonly TARGET="${1:?使用法: $0 <target>}"

tcp_results=$(nmap -sT -oN - "${TARGET}" | grep -E 'open|filtered' || true)
version_results=$(nmap -sV -oN - "${TARGET}" | grep -E 'open|filtered' || true)

echo "=== スキャン対象: ${TARGET} ==="
echo ""
echo "TCP Connect スキャン結果:"
print_tcp_table "${tcp_results}"
echo ""
echo "バージョン検出スキャン結果:"
print_version_table "${version_results}"
```

### XMLをパースしてレポート生成

```bash
#!/usr/bin/env bash
set -euo pipefail

readonly TARGET_RANGE="${1:?使用法: $0 <target_range>}"
readonly REPORT_FILE="report_$(date +%Y%m%d_%H%M%S).txt"

# XML形式でスキャン実行
nmap_output=$(nmap -oX - -p- -sV "${TARGET_RANGE}")

# xmllintでオープンポートとサービスを抽出
open_ports=$(echo "${nmap_output}" | \
    xmllint --format - | \
    awk -F'[<>]' '/<port/{print $5}' || true)

services=$(echo "${nmap_output}" | \
    xmllint --format - | \
    awk -F'[<>]' '/<service/{print $7}' || true)

# レポート生成
{
    echo "ネットワークスキャンレポート"
    echo "==========================="
    echo "日時: $(date)"
    echo "スキャン対象: ${TARGET_RANGE}"
    echo ""
    echo "オープンポートとサービス:"
    echo "--------------------------"
    paste <(echo "${open_ports}") <(echo "${services}") | \
        sed 's/\t/:  /'
} > "${REPORT_FILE}"

echo "レポート生成完了: ${REPORT_FILE}"
```

---

## HTMLレポート自動生成

### XSLTを使ったHTMLレポート

```bash
#!/usr/bin/env bash
set -euo pipefail

readonly TARGET="${1:?使用法: $0 <target>}"
readonly XML_FILE="nmap-scan.xml"
readonly HTML_FILE="nmap-report.html"

# XMLとウェブスタイルシート参照を含む形式でスキャン
echo "スキャン実行中: ${TARGET}"
nmap --webxml -oX "${XML_FILE}" "${TARGET}"

# XML → HTML変換（xsltproc必須）
if command -v xsltproc &>/dev/null; then
    xsltproc "${XML_FILE}" -o "${HTML_FILE}"
    echo "HTMLレポート生成完了: ${HTML_FILE}"
else
    echo "警告: xsltprocが見つかりません。sudo apt install xsltproc でインストール" >&2
fi
```

### カスタムHTMLレポート（Bashで直接生成）

```bash
#!/usr/bin/env bash
set -euo pipefail

readonly TARGET_RANGE="${1:?使用法: $0 <target_range>}"
readonly HTML_FILE="nmap-custom-report.html"

# スキャン実行
nmap_output=$(nmap -sT -sV -oN - "${TARGET_RANGE}")

# HTMLレポート生成
cat << EOF > "${HTML_FILE}"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <title>Nmapスキャンレポート</title>
    <style>
        body { font-family: sans-serif; margin: 2rem; }
        table, th, td {
            border: 1px solid #333;
            border-collapse: collapse;
            padding: 6px 12px;
        }
        th { background-color: #eee; }
        .open { color: green; }
    </style>
</head>
<body>
    <h1>Nmapスキャンレポート</h1>
    <p>日時: $(date)</p>
    <p>スキャン対象: ${TARGET_RANGE}</p>
    <table>
        <tr>
            <th>IPアドレス</th>
            <th>ポート</th>
            <th>状態</th>
            <th>サービス</th>
            <th>バージョン</th>
        </tr>
$(echo "${nmap_output}" | awk -F'[ /]' '/open/ {
    printf "<tr><td>%s</td><td>%s</td><td class=\"open\">open</td><td>%s</td><td>%s</td></tr>\n",
    $5, $1, $3, $4
}')
    </table>
</body>
</html>
EOF

echo "HTMLレポート生成完了: ${HTML_FILE}"
```

---

## NSE（Nmap Scripting Engine）

### スクリプトカテゴリ一覧

| カテゴリ | 用途 | 注意 |
|---------|------|------|
| `default` | 一般的に安全・有用なスクリプト群 | 標準的な用途に推奨 |
| `auth` | 認証関連のタスク | - |
| `discovery` | サービス・ホスト情報の探索 | - |
| `vuln` | 脆弱性検出 | 要認可 |
| `intrusive` | クラッシュや障害を引き起こす可能性 | **要注意・要認可** |
| `dos` | サービス拒否攻撃スクリプト | **要注意・要認可** |
| `exploit` | 脆弱性の悪用 | **要注意・要認可** |
| `malware` | マルウェア検出 | - |

> ⚠️ `intrusive`・`dos`・`exploit` カテゴリは本番環境や認可のない環境で使用してはならない。

### スクリプト確認コマンド

```bash
# 利用可能なスクリプト一覧
ls /usr/share/nmap/scripts/

# スクリプト検索（例: httpに関連するもの）
ls /usr/share/nmap/scripts/ | grep http

# defaultスクリプト実行
nmap --script=default <target>

# 脆弱性検出スクリプト実行（認可済み環境のみ）
nmap --script=vuln <target>
```

### NSEを活用した総合スキャンスクリプト

```bash
#!/usr/bin/env bash
set -euo pipefail

# 認可されたネットワーク範囲のみ使用すること
readonly TARGET_NETWORK="${1:?使用法: $0 <target_network>}"
readonly OUTPUT_DIR="./nse_results"

mkdir -p "${OUTPUT_DIR}"

# ライブホストを特定（ping scan）
echo "ライブホスト探索中..."
live_hosts=$(nmap -sn -oG - "${TARGET_NETWORK}" | \
    awk '/Up/{print $2}' || true)

if [[ -z "${live_hosts}" ]]; then
    echo "ライブホストが見つかりませんでした"
    exit 0
fi

# 各ライブホストに対してスキャンを実行
for host in ${live_hosts}; do
    echo "スキャン中: ${host}"
    host_dir="${OUTPUT_DIR}/${host//\//_}"
    mkdir -p "${host_dir}"

    # ポート・バージョン検出スキャン
    nmap -sV -p- -oN "${host_dir}/ports.nmap" "${host}"

    # 脆弱性検出（認可済み環境のみ実行）
    nmap --script=vuln "${host}" -oN "${host_dir}/vulns.nmap"

    # Webサーバー情報取得
    nmap -p80,8080,443 --script=http-title "${host}" \
        -oN "${host_dir}/http.nmap"

    echo "完了: ${host}"
done

echo "全スキャン完了。結果: ${OUTPUT_DIR}"
```

---

## スケジュールスキャン

### cron による定期スキャン

```bash
# crontab -e で以下を追記
# 毎日 00:00 に認可済みネットワークのスキャンを実行
0 0 * * * /opt/scripts/nmap_scan.sh > ~/nmap-logs/scan_$(date +\%Y\%m\%d).txt

# 毎週月曜 9:00 に週次スキャン
0 9 * * 1 /opt/scripts/nmap_weekly.sh >> ~/nmap-logs/weekly.log 2>&1

# 環境変数の明示的設定（cron環境ではPATHが限定的）
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
MAILTO=security-team@example.com
```

### スキャン結果の差分検出

```bash
#!/usr/bin/env bash
set -euo pipefail

readonly TARGET_NETWORK="${1:?使用法: $0 <target_network>}"
readonly SCAN_DIR="/var/log/nmap-scans"
readonly TODAY_SCAN="${SCAN_DIR}/scan_$(date +%Y%m%d).txt"
readonly PREV_SCAN="${SCAN_DIR}/scan_prev.txt"

mkdir -p "${SCAN_DIR}"

# 前回スキャンをバックアップ
[[ -f "${TODAY_SCAN}" ]] && cp "${TODAY_SCAN}" "${PREV_SCAN}"

# 今日のスキャン実行
nmap -sT -oN "${TODAY_SCAN}" "${TARGET_NETWORK}"

# 前回との差分チェック
if [[ -f "${PREV_SCAN}" ]]; then
    diff_result=$(diff <(grep "open" "${PREV_SCAN}") \
                       <(grep "open" "${TODAY_SCAN}") || true)
    if [[ -n "${diff_result}" ]]; then
        echo "【警告】スキャン結果に変化を検出しました"
        echo "${diff_result}"
    else
        echo "変化なし"
    fi
fi
```

---

## 並列スキャン

### バックグラウンド並列実行

```bash
#!/usr/bin/env bash
set -euo pipefail

# 認可済みのIPレンジのみ指定すること
targets=("192.168.1.0/24" "192.168.2.0/24" "192.168.3.0/24")
readonly MAX_PARALLELISM=50  # ネットワーク規模に応じて調整

echo "並列スキャン開始: ${#targets[@]} ターゲット"

for target in "${targets[@]}"; do
    # バックグラウンドで並列実行
    nmap -sT --max-parallelism "${MAX_PARALLELISM}" \
        -oN "${target//\//_}_scan.txt" "${target}" &
done

# 全バックグラウンドプロセスの完了を待機
wait

echo "全スキャン完了"
```

> ⚠️ 高並列スキャンはネットワークに大量のトラフィックを発生させ、パフォーマンス低下やダウンタイムを引き起こす可能性がある。ネットワーク規模とキャパシティに応じて `--max-parallelism` 値を調整すること。

### 並列度の目安

| ネットワーク規模 | 推奨 `--max-parallelism` |
|----------------|------------------------|
| 小規模（〜10ホスト） | 10以下 |
| 中規模（10〜100ホスト） | 10〜30 |
| 大規模（100ホスト以上） | 30〜50 |
| 本番環境 | 保守的な値（5〜10） |

---

## 主要オプションリファレンス

### スキャンオプション

```bash
# スキャン対象
nmap <target>                      # 単一ホスト
nmap <target1> <target2>           # 複数ホスト
nmap 192.168.1.0/24                # サブネット全体
nmap -iL targets.txt               # ファイルからターゲット読み込み

# スキャンタイプ
nmap -sT <target>                  # TCP Connect スキャン
nmap -sS <target>                  # SYN（ステルス）スキャン（root必要）
nmap -sU <target>                  # UDPスキャン
nmap -sV <target>                  # バージョン検出
nmap -sn <target>                  # Pingスキャン（ポートスキャンなし）

# ポート指定
nmap -p 80,443 <target>            # 特定ポート
nmap -p 1-1000 <target>            # ポート範囲
nmap -p- <target>                  # 全65535ポート
nmap --top-ports 100 <target>      # 上位100ポート

# 出力形式
nmap -oN output.txt <target>       # 標準テキスト形式
nmap -oX output.xml <target>       # XML形式
nmap -oG output.gnmap <target>     # Grepable形式
nmap -oA output <target>           # 全形式で保存

# NSEスクリプト
nmap --script=default <target>     # デフォルトスクリプト
nmap --script=vuln <target>        # 脆弱性検出（認可必須）
nmap --script=<script-name> <target>  # 個別スクリプト指定
```

---

## セキュリティと倫理的ガイドライン

```
✅ 認可されたシステム・ネットワークのみスキャン
✅ スキャン前に書面による許可を取得
✅ スキャン範囲を明確に定義し、逸脱しない
✅ スキャンログを保存・記録
✅ 本番環境では低負荷設定（低並列度・タイミングオプション）を使用
✅ 発見した脆弱性は責任ある開示（Responsible Disclosure）に従い報告

❌ 認可なしのシステムへのスキャンは違法
❌ 意図的なサービス妨害スキャンの禁止
❌ intrusive/dos/exploitカテゴリのNSEスクリプトを本番環境で使用しない
```
