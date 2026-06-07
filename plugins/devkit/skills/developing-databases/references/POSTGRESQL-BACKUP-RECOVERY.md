# PostgreSQL バックアップとリストア

> "You're only as good as your last restore." — Kimberly Tripp

バックアップ設計の本質は**リストア戦略から逆算すること**。「どんなバックアップを取るか」ではなく「いつ、どこまで、どれくらいの時間でリストアできるか」を先に定義する。

---

## 1. リストア戦略：RPO と RTO

### 1.1 定義

| 指標 | 正式名 | 問い |
|------|--------|------|
| **RPO** | Recovery Point Objective | 「どれだけのデータ損失まで許容できるか？」 |
| **RTO** | Recovery Time Objective | 「リストアに許容できる最大時間は？」 |

### 1.2 RPOとバックアップ頻度の関係

| RPO | 必要なバックアップ手段 | 例 |
|-----|-------------------|-----|
| 1日 | 日次フルバックアップ | `pg_dump` を毎日実行 |
| 10分未満 | フルバックアップ + WALアーカイブ | `pg_basebackup` + WAL連続アーカイブ |
| ゼロ（データ損失なし） | 同期レプリケーション | ストリーミングレプリケーション（同期モード） |

### 1.3 RTOとバックアップ方式の関係

RPO ＝ 10分の場合:
```
RTO = フルバックアップのリストア時間 + WALリプレイ時間
```

WALリプレイ時間が長すぎる場合 → フルバックアップの頻度を上げてWALチェーンを短くする。

---

## 2. バックアップ方式の概要

PostgreSQLには3つのバックアップ方式がある:

| 方式 | ツール | 単位 | オンライン | PITR対応 |
|------|--------|------|-----------|---------|
| **SQL Dump（論理）** | `pg_dump` / `pg_dumpall` | データベース単位 | ✅ | ❌ |
| **ファイルシステムバックアップ** | OS コマンド（cp等） | クラスター全体 | ❌（要シャットダウン）| ❌ |
| **ベースバックアップ（物理）** | `pg_basebackup` | クラスター全体 | ✅ | ✅ |

---

## 3. SQL Dump（論理バックアップ）

### 3.1 pg_dump の基本

```bash
# 最もシンプルなダンプ（プレーンテキスト形式）
pg_dump bluebox > bluebox.sql

# リモートサーバーから
pg_dump -U postgres -h db_server bluebox > bluebox.sql

# 特定ディレクトリに出力
pg_dump -U postgres -h db_server bluebox > /bu/bluebox.sql
```

**ファイル拡張子の慣習**（Robert Treat 推奨）:
- `.sql` — pg_restore不要のプレーンテキスト
- `.pgr` — pg_restore必須
- `.pgdump` — pg_dumpで作成したことを明示

### 3.2 主要オプション

| オプション | 説明 |
|-----------|------|
| `-F c` | カスタム形式（圧縮、pg_restore必須） |
| `-F t` | tar形式（pg_restore必須） |
| `-F d` | ディレクトリ形式（並列リストアが可能） |
| `-c` | DROPコマンドをダンプに含める |
| `-C` | CREATE DATABASEコマンドをダンプに含める |
| `-s` | スキーマのみ（データなし） |
| `-a` | データのみ（スキーマなし） |
| `-N schema_name` | 指定スキーマを除外 |
| `-t table_name` | 特定テーブルのみ |
| `-j jobs` | 並列ダンプ（ディレクトリ形式のみ） |

```bash
# 圧縮カスタム形式でダンプ（推奨）
pg_dump -U postgres -F c -f bluebox.pgr bluebox

# スキーマとデータを分離
pg_dump -s -f schema_only.sql bluebox  # スキーマのみ
pg_dump -a -f data_only.sql bluebox    # データのみ
```

### 3.3 pg_dumpall（クラスター全体）

```bash
# ロール、テーブルスペースを含むクラスター全体のダンプ
pg_dumpall -U postgres > all_databases.sql
```

**注意**: `pg_dumpall` は圧縮フォーマット非対応。`pg_restore` の全機能は使えない。ロール（ユーザー・グループ）を含めたい場合に使用。

---

## 4. ベースバックアップ（物理バックアップ）

### 4.1 pg_basebackup の基本

```bash
# クラスター全体をディレクトリにバックアップ
pg_basebackup -D /bu/mybase

# 実行ユーザーにREPLICATION権限が必要
# 出力先ディレクトリは空である必要がある
```

### 4.2 主要オプション

| オプション | 説明 |
|-----------|------|
| `-D directory` | 出力先ディレクトリ |
| `-F p` | プレーンテキスト（デフォルト） |
| `-F t` | tar形式 |
| `-X f` | バックアップ完了後にWALをfetch |
| `-X s` | バックアップ中にWALをストリーミング（デフォルト、推奨） |
| `-X n` | WALを含めない |
| `-Z level` | 圧縮レベル（0-9） |
| `-P` | 進捗表示 |

```bash
# 推奨設定（WALストリーミング + tar圧縮）
pg_basebackup -D /bu/mybase -F t -X s -Z 5 -P
```

---

## 5. バックアップ方式の比較

| 比較軸 | pg_dump（論理） | pg_basebackup（物理） |
|--------|---------------|-------------------|
| **対象範囲** | データベース単位（指定可能） | クラスター全体のみ |
| **オンライン実行** | ✅ 可能 | ✅ 可能 |
| **PITR（時刻指定復元）** | ❌ 不可 | ✅ WALと組み合わせで可 |
| **バックアップサイズ** | 小さい（論理的なSQL） | 大きい（ファイルコピー） |
| **バックアップ速度** | 遅い（全データをSQL化） | 速い（ファイルコピー） |
| **リストア速度** | 遅い（SQLを再実行） | 速い（ファイルコピー） |
| **バージョン間移行** | ✅ 可能（旧→新） | ❌ 同一バージョンのみ |
| **個別オブジェクト復元** | ✅ テーブル・関数単位で可能 | ❌ 不可 |
| **レプリケーション基盤** | ❌ | ✅ スタンバイサーバーの基盤 |
| **WALファイルが必要** | ❌ | ✅ PITR時に必要 |

**使い分け指針**:
- RPOが「1日」なら → `pg_dump` で十分
- RPOが「10分未満」なら → `pg_basebackup` + WALアーカイブ
- バージョンアップグレード時 → `pg_dump` で新バージョンへ移行
- 本番のスタンバイ構築 → `pg_basebackup`

---

## 6. リストア手順

### 6.1 pg_restore（論理バックアップのリストア）

```sql
-- 1. リストア先のデータベースを準備
DROP DATABASE bluebox;
-- template0を使うこと（template1にカスタムオブジェクトがある場合の競合を避ける）
CREATE DATABASE bluebox WITH TEMPLATE template0;
```

```bash
# 2a. プレーンテキストダンプの場合: psqlで実行
psql -U postgres -d bluebox -f bluebox.sql

# 2b. カスタム/tar形式の場合: pg_restore を使用
pg_restore -C -d postgres bluebox.pgr
# -C: ダンプ内のCREATE DATABASEを実行
# -d postgres: 接続先DB（CREATE DATABASEを発行するだけ）
```

```bash
# 特定オブジェクトのみリストア（個別関数の復元等）
pg_restore -d bluebox -P 'film_crew_info()' bluebox.pgr

# ダンプ内のオブジェクト一覧表示（実際のリストアなし）
pg_restore -l bluebox.pgr

# 並列リストア（マルチCPU環境で高速化）
pg_restore -j 4 -d bluebox bluebox.pgr

# データのみリストア
pg_restore -a -d bluebox bluebox.pgr

# スキーマのみリストア
pg_restore -s -d bluebox bluebox.pgr
```

---

## 7. PITR（Point-In-Time Recovery）

### 7.1 PITR の仕組み

```
[ベースバックアップ]  [WALファイル1]  [WALファイル2]  [WALファイル3]
      t=0              t=0〜1時間       t=1〜2時間      t=2〜現在

PITRで t=1時間30分 に復元 → ベースバックアップ + WAL1 + WAL2の途中まで再生
```

### 7.2 WALアーカイブの設定

**Step 1: WALアーカイブ先の準備**

```bash
mkdir -p /walarchive
chown postgres:postgres /walarchive
```

**Step 2: postgresql.conf の設定**

```ini
# WALレベル（replicaまたはlogical）が必要
wal_level = replica           # デフォルト。PITRに使用可能

# WALアーカイブの有効化
archive_mode = on             # off（デフォルト）→ on

# アーカイブコマンド（WALファイルをアーカイブ先にコピー）
archive_command = 'test ! -f /walarchive/%f && cp %p /walarchive/%f'
# %f = ファイル名, %p = フルパス
```

> 設定変更後はクラスターの**再起動が必要**。

**Step 3: ベースバックアップを定期実行**

```bash
# 毎日深夜に実行（例: cronジョブ）
pg_basebackup -D /bu/base_$(date +%Y%m%d) -X s -Z 5
```

### 7.3 PITR リカバリ手順

```bash
# 1. 可能であれば、現在のWALをアーカイブへ強制フラッシュ
psql -c "SELECT pg_switch_wal();"

# 2. PostgreSQLサービスを停止
pg_ctl stop -D /var/lib/postgresql/16/data

# 3. データディレクトリをクリア（または新ディレクトリへ）
rm -rf /var/lib/postgresql/16/data/*

# 4. ベースバックアップを展開
cp -r /bu/base_20240710/* /var/lib/postgresql/16/data/

# 5. pg_walディレクトリをクリア（WALはアーカイブから取得するため）
rm -rf /var/lib/postgresql/16/data/pg_wal/*

# 6. ディレクトリの所有者を確認
sudo chown -R postgres:postgres /var/lib/postgresql/16/data
sudo chmod 700 /var/lib/postgresql/16/data
```

**Step 4: postgresql.conf にリカバリ設定を追加**

```ini
# WALアーカイブからファイルを取得するコマンド
restore_command = 'cp /walarchive/%f %p'

# リカバリの停止時刻を指定
recovery_target_time = '2024-07-10 15:24:00 EDT'

# LSN（Log Sequence Number）での指定も可能
# recovery_target_lsn = '0/3A00000'

# リカバリ後の動作（promote = 通常稼働に移行）
recovery_target_action = 'promote'
```

```bash
# 7. recovery.signal ファイルを作成（リカバリモードを有効化）
touch /var/lib/postgresql/16/data/recovery.signal
# このファイルが存在するとPostgreSQLはリカバリモードで起動
# リカバリ完了後、自動的に recovery.done にリネームされる

# 8. PostgreSQLサービスを起動
pg_ctl start -D /var/lib/postgresql/16/data

# 9. ログでリカバリの進捗を監視
tail -f /var/log/postgresql/postgresql.log
```

### 7.4 WALアーカイブの確認

```sql
-- 現在のWAL位置を確認
SELECT pg_current_wal_lsn();

-- アーカイブ状態を確認
SELECT * FROM pg_stat_archiver;
```

---

## 8. バックアップ運用チェックリスト

### 設計フェーズ

- [ ] RPO（許容データ損失）を業務部門と合意する
- [ ] RTO（許容リストア時間）を業務部門と合意する
- [ ] バックアップ方式を選択する（論理 / 物理 / 両方）
- [ ] バックアップ保持期間を決定する
- [ ] バックアップ先ストレージの容量を確保する（WALは16MB×本数）

### 実装フェーズ

- [ ] `wal_level = replica` であることを確認する
- [ ] `archive_mode = on` と `archive_command` を設定する
- [ ] `pg_basebackup` の定期実行をスケジュールする（cron等）
- [ ] WALアーカイブの蓄積を監視する（`pg_stat_archiver.last_failed_wal`）

### テストフェーズ（**必須**）

- [ ] **テスト環境でPITRを実際に実行して検証する**
- [ ] リカバリスクリプトを事前に作成・テストしておく
- [ ] リストア時間を計測してRTOと照合する

---

## まとめ

| やること | ツール | 使用場面 |
|---------|--------|---------|
| 単一DBのバックアップ | `pg_dump -F c` | 日次バックアップ、バージョン移行 |
| クラスター全体（ロール含む） | `pg_dumpall` | 完全なクラスター移行 |
| PITR対応バックアップ | `pg_basebackup` + WALアーカイブ | 本番環境の標準バックアップ |
| 特定時刻へのリストア | PITR（`recovery_target_time`）| 誤操作からの復旧 |
| 個別オブジェクトのリストア | `pg_restore -P 'function_name()'` | 誤ってDROPした関数の復元 |
