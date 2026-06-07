# Bash 制御フロー

条件分岐、ループ、関数、モジュール化、算術演算、引数処理の実装パターン。

## 目次

1. [条件文](#条件文)
2. [比較演算子](#比較演算子)
3. [ループ](#ループ)
4. [関数](#関数)
5. [モジュール化](#モジュール化)
6. [算術演算](#算術演算)
7. [コマンドライン引数処理](#コマンドライン引数処理)

---

## 条件文

### test / [ / [[ の違い（重要）

| 構文 | 種類 | 特徴 | 使用場面 |
|------|------|------|---------|
| `test expr` | 外部コマンド | POSIX互換 | 移植性が最優先 |
| `[ expr ]` | ビルトイン | POSIX互換、`test` のエイリアス | POSIX互換が必要 |
| `[[ expr ]]` | キーワード | Bash拡張、パターンマッチング、正規表現 | Bash専用スクリプト（推奨） |

#### 判断基準テーブル

```bash
# シェルスクリプトの移植性
if [[ "Bash専用でOK" ]]; then
  # [[ ]] を使用（パターンマッチング、正規表現、&&/|| 使用可）
  [[ $var == pattern* ]]
elif [[ "POSIX互換が必要（sh, dash等でも動作）" ]]; then
  # [ ] を使用（POSIX標準）
  [ "$var" = "value" ]
fi
```

### [ ] と [[ ]] の違い（Bash固有の落とし穴）

```bash
# [[ ]] の利点（Bash専用）:
# 1. クォート不要（空変数でエラーにならない）
[[ $var = "test" ]]  # 安全

# 2. パターンマッチング
[[ $file == *.txt ]]  # ワイルドカード展開

# 3. 正規表現
[[ $email =~ ^[a-z]+@[a-z]+\.[a-z]+$ ]]

# 4. && / || 使用可能
[[ $age -gt 18 && $age -lt 65 ]]

# [ ] はPOSIX互換が必要な場合のみ使用
```

### case文（パターンマッチング）

```bash
case "$1" in
  start|stop|restart) echo "$1 service..." ;;
  *.txt) echo "Text file" ;;
  [Dd]ocument*) echo "Document" ;;
  *) echo "Unknown"; exit 1 ;;
esac
```

### 条件結合（&& と ||）

```bash
# コマンドの成功時のみ次を実行
mkdir /tmp/test && cd /tmp/test && touch file.txt

# コマンドの失敗時のみ次を実行
command || echo "Command failed"

# 実用例：ディレクトリの存在確認
[ -d "$dir" ] || mkdir -p "$dir"

# 実用例：ファイルの存在確認とバックアップ
[ -f "$file" ] && cp "$file" "$file.backup"

# 複雑な条件
[[ -f "$file" && -r "$file" ]] && cat "$file" || echo "File not found or not readable"
```

---

## 比較演算子

### 文字列比較

| 演算子 | 説明 | 例 |
|--------|------|-----|
| `=` | 等しい（POSIX） | `[ "$a" = "$b" ]` |
| `==` | 等しい（Bash拡張） | `[[ $a == $b ]]` |
| `!=` | 等しくない | `[[ $a != $b ]]` |
| `<` | 辞書順で小さい | `[[ $a < $b ]]` |
| `>` | 辞書順で大きい | `[[ $a > $b ]]` |
| `-z` | 文字列が空 | `[[ -z $var ]]` |
| `-n` | 文字列が非空 | `[[ -n $var ]]` |
| `=~` | 正規表現マッチ（[[ ]] のみ） | `[[ $str =~ ^[0-9]+$ ]]` |

```bash
# 文字列比較の例
str1="apple"
str2="banana"

if [[ $str1 == $str2 ]]; then
  echo "Equal"
fi

if [[ $str1 < $str2 ]]; then
  echo "$str1 comes before $str2"  # 出力：apple comes before banana
fi

# 空文字列チェック
if [[ -z $empty_var ]]; then
  echo "Variable is empty or unset"
fi

# 正規表現マッチ
email="user@example.com"
if [[ $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
  echo "Valid email format"
fi
```

### 数値比較

| 演算子 | 説明 | 例 |
|--------|------|-----|
| `-eq` | 等しい | `[ $a -eq $b ]` |
| `-ne` | 等しくない | `[ $a -ne $b ]` |
| `-lt` | より小さい | `[ $a -lt $b ]` |
| `-le` | 以下 | `[ $a -le $b ]` |
| `-gt` | より大きい | `[ $a -gt $b ]` |
| `-ge` | 以上 | `[ $a -ge $b ]` |

```bash
age=25

if [ $age -ge 18 ]; then
  echo "Adult"
fi

if [[ $age -gt 12 && $age -lt 20 ]]; then
  echo "Teenager"
fi

# (( )) 構文（算術評価、C言語風）
if (( age >= 18 )); then
  echo "Adult"
fi

if (( age > 12 && age < 20 )); then
  echo "Teenager"
fi
```

### ファイルテスト

| 演算子 | 説明 | 例 |
|--------|------|-----|
| `-f` | 通常ファイル | `[[ -f $file ]]` |
| `-d` | ディレクトリ | `[[ -d $dir ]]` |
| `-e` | ファイル存在（種類問わず） | `[[ -e $path ]]` |
| `-r` | 読み取り可能 | `[[ -r $file ]]` |
| `-w` | 書き込み可能 | `[[ -w $file ]]` |
| `-x` | 実行可能 | `[[ -x $file ]]` |
| `-s` | サイズが0より大きい | `[[ -s $file ]]` |
| `-L` | シンボリックリンク | `[[ -L $link ]]` |
| `-nt` | より新しい（newer than） | `[[ $file1 -nt $file2 ]]` |
| `-ot` | より古い（older than） | `[[ $file1 -ot $file2 ]]` |

```bash
config_file="/etc/app/config.conf"

# ファイル存在確認
if [[ -f $config_file ]]; then
  echo "Config file exists"
fi

# 複数条件
if [[ -f $config_file && -r $config_file ]]; then
  echo "Config file exists and is readable"
  source "$config_file"
else
  echo "Error: Cannot read config file"
  exit 1
fi

# ディレクトリ確認と作成
data_dir="/var/lib/app/data"
if [[ ! -d $data_dir ]]; then
  mkdir -p "$data_dir" || {
    echo "Error: Cannot create directory"
    exit 1
  }
fi

# ファイルの更新日時比較
if [[ source.txt -nt target.txt ]]; then
  echo "Source is newer, rebuilding target..."
  cp source.txt target.txt
fi
```

---

## ループ

```bash
# for: 配列・ファイル・範囲
for file in *.txt; do echo "$file"; done
for i in {1..5}; do echo "$i"; done
for (( i=0; i<10; i++ )); do echo "$i"; done

# while: ファイル読み込み・条件ループ
while IFS= read -r line; do echo "$line"; done < input.txt
while [[ -f /tmp/lock ]]; do sleep 1; done

# until: サービス待機
until curl -s localhost:8080 >/dev/null; do sleep 2; done

# select: メニュー
PS3="Select: "
select opt in "Install" "Exit"; do
  case $opt in
    "Exit") break ;;
    *) [[ -n "$opt" ]] && echo "Selected: $opt" ;;
  esac
done

# break/continue: ループ制御
for i in {1..10}; do
  [[ $i -eq 5 ]] && continue  # スキップ
  [[ $i -eq 8 ]] && break     # 終了
  echo "$i"
done
```

### ループ内パイプの落とし穴（サブシェル問題）

```bash
# ❌ 問題：パイプはサブシェルを生成するため、変数が更新されない
count=0
cat file.txt | while read line; do
  ((count++))
done
echo "Lines: $count"  # 0（更新されていない！）

# ✓ 解決策1：プロセス置換を使用
count=0
while read line; do
  ((count++))
done < <(cat file.txt)
echo "Lines: $count"  # 正しいカウント

# ✓ 解決策2：リダイレクトを使用
count=0
while read line; do
  ((count++))
done < file.txt
echo "Lines: $count"  # 正しいカウント
```


## 算術演算

```bash
# $(( )) 算術展開
a=10; b=3
echo $((a + b))    # 13
echo $((a % b))    # 1
echo $((a ** b))   # 1000
((a++))            # インクリメント
max=$((a > b ? a : b))  # 三項演算子

# ビット演算
echo $((5 & 3))    # 1 (AND)
echo $((5 | 3))    # 7 (OR)
echo $((5 << 1))   # 10 (左シフト)

# bc で浮動小数点
result=$(echo "scale=2; 10 / 3" | bc)  # 3.33
percentage=$(awk "BEGIN {printf \"%.2f\", (75/100)*100}")  # 75.00
```

---

## まとめ

### チェックリスト

- [ ] `[[ ]]` と `[ ]` の違いを理解し、適切に使い分けている
- [ ] case 文でパターンマッチングを活用している
- [ ] ループの種類（for、while、until、select）を使い分けている
- [ ] 算術演算で $(( )) を活用している

### 次のステップ

- [FUNCTIONS.md](./FUNCTIONS.md): 関数・モジュール化・引数処理
- [PATTERNS.md](./PATTERNS.md): デザインパターン・アンチパターン・ベストプラクティス集
- [CLI-TOOLS.md](./CLI-TOOLS.md): CLIツール構築・API連携・インタラクティブスクリプト
