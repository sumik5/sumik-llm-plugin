# システム管理自動化

## 自動化の原則

### 冪等性（Idempotency）

同じ操作を複数回実行しても同じ結果になることを保証する。

```bash
# 悪い例
echo "log_entry" >> config.log

# 良い例
if ! grep -q "log_entry" config.log; then
    echo "log_entry" >> config.log
fi
```

### エラーハンドリングとログ出力

```bash
#!/bin/bash
set -euo pipefail

# エラートラップ
trap 'echo "Error: Script failed at line $LINENO" >&2' ERR

# ログ関数
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[$timestamp] [$level] $message" | tee -a /var/log/automation.log
}

# 使用例
log_message "INFO" "Starting backup process"
log_message "ERROR" "Failed to connect to remote server"
```

### 自動化判断基準

| 基準 | 適している | 適していない |
|------|-----------|-------------|
| 頻度 | 定期的（毎日/毎週） | 稀・不定期 |
| 時間 | 5分以上 | 数秒で完了 |
| 複雑性 | 明確な手順 | 人間の判断が必要 |
| エラー | 対処が明確 | 対応が複雑 |
| 重要性 | 失敗リスク低 | 失敗が致命的 |

---

## スケジューリング

### cron 構文

```bash
# 分(0-59) 時(0-23) 日(1-31) 月(1-12) 曜日(0-7) コマンド
30 3 * * * /path/to/script.sh              # 毎日 3:30 AM
0 9 * * 1 /path/to/monday-job.sh          # 毎週月曜 9:00 AM
*/15 * * * * /path/to/check.sh            # 15分ごと
0 9-17 * * 1-5 /path/to/business.sh       # 平日 9-17時
0 6,12,18 * * * /path/to/three-times.sh   # 6:00, 12:00, 18:00
0 2 1 * * /path/to/monthly.sh             # 毎月1日 2:00 AM

# 環境変数設定
SHELL=/bin/bash
PATH=/usr/local/bin:/usr/bin:/bin
MAILTO=admin@example.com
```

### crontab 管理

```bash
crontab -e              # 編集
crontab -l              # 表示
crontab -r              # 削除
crontab -e -u username  # 他ユーザー編集
```

### systemd timer

```ini
# /etc/systemd/system/backup.timer
[Unit]
Description=Daily Backup Timer

[Timer]
OnCalendar=*-*-* 03:00:00
RandomizedDelaySec=30min
Persistent=true

[Install]
WantedBy=timers.target
```

```bash
sudo systemctl enable backup.timer
sudo systemctl start backup.timer
systemctl list-timers
```

### at コマンド

```bash
echo "/path/to/script.sh" | at 15:30
at 9:00 AM tomorrow <<EOF
/path/to/cleanup.sh
EOF

atq                     # スケジュール一覧
atrm 3                  # ジョブ削除
```

### cron vs systemd timer

| 機能 | cron | systemd timer | 推奨 |
|------|------|---------------|------|
| 学習曲線 | 簡単 | やや複雑 | cron（初心者） |
| ログ管理 | 基本的 | journald統合 | systemd |
| 依存関係 | なし | 可能 | systemd |
| ランダム遅延 | 不可 | 可能 | systemd |
| 移植性 | 高い | Linux限定 | cron |

---

## ユーザー・権限管理

### ユーザー管理

```bash
# 作成
sudo useradd -m -s /bin/bash -G sudo,docker newuser

# 削除
sudo userdel -r newuser

# 変更
sudo usermod -aG sudo newuser       # グループ追加
sudo usermod -L newuser             # ロック
sudo usermod -U newuser             # アンロック
```

### グループ管理

```bash
sudo groupadd developers
sudo groupadd -g 2000 marketing
sudo usermod -aG developers username
sudo gpasswd -d username groupname
```

### ファイルパーミッション

```bash
# 数値
chmod 755 script.sh    # rwxr-xr-x
chmod 644 file.txt     # rw-r--r--
chmod 600 secret.key   # rw-------

# シンボル
chmod u+x script.sh
chmod g-w file.txt
chmod o=r file.txt

# 所有者
chown user:group file.txt
chown -R user:group directory/
```

### ACL

```bash
setfacl -m u:username:rwx file.txt
setfacl -m g:groupname:rx file.txt
getfacl file.txt
setfacl -b file.txt                # 全ACL削除
setfacl -d -m u:username:rwx dir/  # デフォルトACL
```

---

## バックアップ戦略

### rsync

```bash
# 基本
rsync -avz --delete \
    --exclude='*.tmp' \
    /source/ /destination/

# リモート
rsync -avz -e ssh /local/ user@remote:/remote/

# 帯域制限
rsync -avz --bwlimit=1000 /source/ /dest/

# Dry-run
rsync -avn --delete /source/ /dest/
```

### tar アーカイブ

```bash
# 圧縮
tar -czf backup_$(date +%Y%m%d).tar.gz /data

# 増分バックアップ
tar -czf full.tar.gz --listed-incremental=backup.snar /data
tar -czf inc.tar.gz --listed-incremental=backup.snar /data

# 展開
tar -xzf backup.tar.gz -C /restore/
```

### バックアップローテーション

```bash
#!/bin/bash
BACKUP_DIR="/backup"
RETENTION_DAYS=7

# 古いバックアップ削除
find "$BACKUP_DIR" -name "backup_*.tar.gz" -mtime +"$RETENTION_DAYS" -delete

# 新規バックアップ
tar -czf "$BACKUP_DIR/backup_$(date +%Y%m%d).tar.gz" /data
```

### バックアップスクリプトテンプレート

```bash
#!/bin/bash
set -euo pipefail

BACKUP_DIR="/backup/daily"
SOURCE_DIR="/home/users"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="/var/log/backup.log"
MAX_BACKUPS=7

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

mkdir -p "$BACKUP_DIR"

log "Starting backup: $SOURCE_DIR"

if tar -czf "$BACKUP_DIR/backup_${TIMESTAMP}.tar.gz" "$SOURCE_DIR"; then
    log "Backup completed"
else
    log "Backup failed"
    exit 1
fi

# クリーンアップ
ls -t "$BACKUP_DIR"/backup_*.tar.gz | tail -n +$((MAX_BACKUPS + 1)) | xargs -r rm -v

log "Backup process finished"
```

---

## サービス監視

### systemctl

```bash
# 状態確認
systemctl status nginx

# 起動/停止/再起動
sudo systemctl start nginx
sudo systemctl stop nginx
sudo systemctl restart nginx

# 自動起動設定
sudo systemctl enable nginx
sudo systemctl disable nginx

# ログ
journalctl -u nginx -f
```

### ヘルスチェック

```bash
#!/bin/bash
SERVICES=("nginx" "mysql" "redis")

for service in "${SERVICES[@]}"; do
    if systemctl is-active --quiet "$service"; then
        echo "[OK] $service"
    else
        echo "[FAIL] $service" >&2
    fi
done
```

### リソース監視

```bash
#!/bin/bash
DISK_THRESHOLD=90

# ディスク使用量
df -h | awk 'NR>1 {
    gsub(/%/, "", $5);
    if ($5 > '"$DISK_THRESHOLD"') {
        printf "WARNING: %s is %s%% full\n", $6, $5
    }
}'

# メモリ
free | awk '/Mem:/ {printf "Memory: %.0f%%\n", $3/$2 * 100}'

# CPU
top -bn1 | grep "Cpu(s)" | awk '{print "CPU: " $2}'
```

### アラート通知

```bash
# メール
echo "Alert message" | mail -s "Subject" admin@example.com

# Slack
curl -X POST -H 'Content-type: application/json' \
    --data '{"text":"Alert message"}' \
    https://hooks.slack.com/services/YOUR/WEBHOOK
```

---

## パッケージ管理自動化

### 非対話操作

```bash
# Debian/Ubuntu
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -qq
sudo apt-get upgrade -y
sudo apt-get autoremove -y

# RHEL/CentOS
sudo yum update -y
sudo dnf upgrade -y
```

### パッケージリスト管理

```bash
# エクスポート
dpkg --get-selections > packages.list
rpm -qa > packages.list

# インポート
sudo dpkg --set-selections < packages.list
sudo apt-get dselect-upgrade
```

### セキュリティアップデート

```bash
#!/bin/bash
LOG_FILE="/var/log/security-updates.log"

log() {
    echo "[$(date)] $*" >> "$LOG_FILE"
}

log "Starting security updates"
sudo unattended-upgrade -v 2>&1 | tee -a "$LOG_FILE"

if [[ -f /var/run/reboot-required ]]; then
    log "Reboot required"
    mail -s "Reboot Required" admin@example.com <<< "System needs reboot"
fi

log "Updates completed"
```

---

## ネットワーク・リモート自動化

### SSH 鍵認証

```bash
# 鍵生成
ssh-keygen -t ed25519 -C "automation@example.com"

# 公開鍵コピー
ssh-copy-id user@remote-server

# パーミッション
ssh user@remote "chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
```

### SSH config

```bash
# ~/.ssh/config
Host prod
    HostName 192.168.1.100
    User deploy
    Port 2222
    IdentityFile ~/.ssh/prod_key

# 使用
ssh prod
rsync -avz /local/ prod:/remote/
```

### リモートコマンド実行

```bash
# 単一コマンド
ssh user@remote 'uptime'

# 複数コマンド
ssh user@remote 'cd /app && git pull && systemctl restart app'

# ヒアドキュメント
ssh user@remote 'bash -s' <<'EOF'
cd /app
git pull
composer install
php artisan migrate --force
EOF

# ローカルスクリプト実行
ssh user@remote 'bash -s' < local_script.sh
```

### 多サーバー操作

```bash
#!/bin/bash
SERVERS=("web1.com" "web2.com" "web3.com")

# 順次
for server in "${SERVERS[@]}"; do
    ssh "$server" "uptime"
done

# 並列
for server in "${SERVERS[@]}"; do
    ssh "$server" "uptime" &
done
wait

# GNU Parallel
parallel ssh {} "uptime" ::: "${SERVERS[@]}"
```

---

## 設定プロビジョニング

### envsubst

```bash
# テンプレート
cat > config.template <<'EOF'
server_name=${SERVER_NAME}
database_host=${DB_HOST}
EOF

# 環境変数設定
export SERVER_NAME="web-prod"
export DB_HOST="db.example.com"

# 置換
envsubst < config.template > config.conf
```

### 環境別設定

```bash
#!/bin/bash
ENVIRONMENT="${1:-development}"

case "$ENVIRONMENT" in
    production)
        export DB_HOST="prod-db.example.com"
        export DEBUG="false"
        ;;
    staging)
        export DB_HOST="staging-db.example.com"
        export DEBUG="true"
        ;;
    development)
        export DB_HOST="localhost"
        export DEBUG="true"
        ;;
esac

# 設定生成
for template in config-templates/*.template; do
    filename=$(basename "$template" .template)
    envsubst < "$template" > "config/$filename"
done
```
