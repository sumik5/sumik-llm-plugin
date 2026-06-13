# テキスト処理・正規表現・構造化データ

Bashにおけるテキスト処理ツール、正規表現、構造化データ処理の実践的リファレンス。

---

## 目次

1. [テキスト処理ツール群](#テキスト処理ツール群)
2. [正規表現](#正規表現)
3. [構造化データ処理](#構造化データ処理)

---

## テキスト処理ツール群

### grep

```bash
# 基本検索
grep "pattern" file.txt

# 正規表現 (拡張)
grep -E "pattern1|pattern2" file.txt

# Perl 正規表現
grep -P "\d{3}-\d{4}" file.txt

# 再帰検索
grep -r "pattern" /path/to/dir

# マッチファイル名のみ表示
grep -l "pattern" *.txt

# カウント
grep -c "pattern" file.txt

# 反転マッチ
grep -v "exclude" file.txt

# マッチ部分のみ表示
grep -o "pattern" file.txt

# 前後の行も表示
grep -A 2 -B 2 "pattern" file.txt  # 前後2行
```

### sed

```bash
# 置換 (最初のマッチのみ)
sed 's/old/new/' file.txt

# 置換 (すべて)
sed 's/old/new/g' file.txt

# インプレース編集
sed -i 's/old/new/g' file.txt

# 削除
sed '/pattern/d' file.txt

# 挿入
sed '/pattern/i\New line' file.txt

# 追加
sed '/pattern/a\New line' file.txt

# 範囲指定
sed '10,20s/old/new/g' file.txt

# 複数コマンド
sed -e 's/foo/bar/' -e 's/baz/qux/' file.txt
```

### awk

```bash
# フィールド処理
awk '{print $1, $3}' file.txt

# 区切り文字指定
awk -F: '{print $1}' /etc/passwd

# 条件処理
awk '$3 > 100 {print $1}' data.txt

# 組み込み変数
awk '{print NR, NF, $0}' file.txt  # 行番号、フィールド数、全体

# 合計計算
awk '{sum += $2} END {print sum}' numbers.txt

# パターンマッチ
awk '/pattern/ {print $0}' file.txt

# 複数区切り文字
awk -F'[,:]' '{print $1, $2}' file.txt
```

### その他のテキストツール

```bash
# cut: フィールド切り出し
cut -d',' -f1,3 data.csv

# sort: ソート
sort -n numbers.txt        # 数値ソート
sort -r file.txt           # 逆順
sort -u file.txt           # 重複削除
sort -k2,2 file.txt        # 2番目のフィールドでソート

# uniq: 重複処理 (事前にソート必要)
sort file.txt | uniq       # 重複削除
sort file.txt | uniq -c    # カウント付き
sort file.txt | uniq -d    # 重複行のみ

# tr: 文字変換/削除
tr '[:lower:]' '[:upper:]' < file.txt
tr -d '\r' < dos_file.txt

# wc: カウント
wc -l file.txt             # 行数
wc -w file.txt             # 単語数
wc -c file.txt             # バイト数

# head / tail: 先頭/末尾表示
head -n 10 file.txt
tail -n 10 file.txt
tail -f logfile.log        # 追跡モード

# column: 整形
column -t -s, data.csv     # カラム整列
```

### ツール選択の判断基準

| タスク | 推奨ツール | 理由 |
|--------|-----------|------|
| 単純なパターン検索 | grep | 高速、シンプル |
| 複雑な正規表現 | grep -P または awk | Perl 互換正規表現 |
| フィールドベース処理 | awk | 組み込み変数、計算機能 |
| 簡単な置換 | sed | ストリーム編集に最適 |
| 複数行にまたがる置換 | awk または perl | sed は行単位 |
| CSV/TSV 処理 | awk または cut | フィールド区切り対応 |
| 大規模ファイル | grep, sed | メモリ効率が良い |
| 集計/統計 | awk | 数値演算が得意 |

---

## 正規表現

### 基本正規表現 (BRE) vs 拡張正規表現 (ERE)

```bash
# BRE (デフォルトの grep, sed)
grep 'pattern\+' file.txt     # + をエスケープ
sed 's/\(foo\)\1/bar/' file.txt  # グループをエスケープ

# ERE (grep -E, awk)
grep -E 'pattern+' file.txt   # + をそのまま使用
awk '/pattern+/ {print}' file.txt
```

### Bash 組み込み正規表現

```bash
# =~ 演算子
if [[ $string =~ ^[0-9]+$ ]]; then
    echo "Number: $string"
fi

# BASH_REMATCH でキャプチャグループ取得
if [[ $email =~ ^([^@]+)@([^@]+)$ ]]; then
    user="${BASH_REMATCH[1]}"
    domain="${BASH_REMATCH[2]}"
    echo "User: $user, Domain: $domain"
fi
```

### よく使うパターン集

```bash
# メールアドレス
^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$

# URL
^https?://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(/.*)?$

# IPv4 アドレス
^([0-9]{1,3}\.){3}[0-9]{1,3}$

# 日付 (YYYY-MM-DD)
^[0-9]{4}-[0-9]{2}-[0-9]{2}$

# 電話番号 (XXX-XXXX-XXXX)
^[0-9]{3}-[0-9]{4}-[0-9]{4}$

# 英数字のみ
^[a-zA-Z0-9]+$
```

---

## 構造化データ処理

### JSON (jq)

```bash
# 基本フィルタ
jq '.' data.json                    # 整形表示
jq '.key' data.json                 # キー取得
jq '.items[]' data.json             # 配列展開
jq '.items[0]' data.json            # 最初の要素

# 条件フィルタ
jq '.items[] | select(.price > 100)' data.json

# マップ
jq '.items[] | {name: .name, total: (.price * .quantity)}' data.json

# 複数キー取得
jq '.items[] | {name, price}' data.json

# 配列から値抽出
jq '[.items[].name]' data.json

# ソート
jq '.items | sort_by(.price)' data.json

# グループ化
jq 'group_by(.category)' data.json

# 集計
jq '[.items[].price] | add' data.json
```

### CSV

```bash
# awk での処理
awk -F',' '{print $1, $3}' data.csv

# ヘッダーをスキップ
awk -F',' 'NR>1 {print $1}' data.csv

# 条件フィルタ
awk -F',' '$3 > 1000 {print $0}' data.csv

# 集計
awk -F',' 'NR>1 {sum += $2} END {print sum}' data.csv

# csvkit (高度なツール)
csvcut -c 1,3 data.csv              # カラム選択
csvgrep -c name -m "John" data.csv  # 検索
csvstat data.csv                    # 統計情報
```

### XML

```bash
# xmlstarlet での処理
xmlstarlet sel -t -v "//item/name" data.xml     # XPath クエリ
xmlstarlet sel -t -m "//item" -v "name" -n data.xml

# xmllint での整形
xmllint --format data.xml

# XPath 評価
xmllint --xpath "//item[@id='1']/name/text()" data.xml
```

---

## 関連リファレンス

- [IO-PIPELINES.md](./IO-PIPELINES.md): ファイルディスクリプタ、リダイレクト、パイプライン
- [FUNDAMENTALS.md](./FUNDAMENTALS.md): シェルアーキテクチャ、起動ファイル、変数
- [CONTROL-FLOW.md](./CONTROL-FLOW.md): 条件分岐、ループ、関数の実装パターン
