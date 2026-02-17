# クォート・データ型・パラメータ展開

Bashにおける文字列操作、データ型、パラメータ展開の実践的リファレンス。

---

## 目次

1. [クォートルール](#クォートルール)
2. [データ型](#データ型)
3. [パラメータ展開](#パラメータ展開)

---

## クォートルール

### クォートの種類

| クォート | 展開される要素 | 例 |
|---------|---------------|-----|
| シングルクォート `'...'` | なし（全てリテラル） | `echo '$HOME'` → `$HOME` |
| ダブルクォート `"..."` | 変数、コマンド置換、算術展開 | `echo "$HOME"` → `/home/user` |
| バッククォート `` `...` `` | コマンド置換 | `` echo `date` `` → `Mon Jan 1 00:00:00 JST 2024` |
| `$(...)` | コマンド置換（推奨） | `echo $(date)` → `Mon Jan 1 00:00:00 JST 2024` |
| `$'...'` | ANSI-Cクォート | `echo $'line1\nline2'` → 改行を含む出力 |

### ワードスプリッティングとグロブ展開

```bash
# 危険：クォートなし
FILES=$(ls)
for file in $FILES; do  # スペースを含むファイル名が分割される
  echo "$file"
done

# 安全：ダブルクォート
FILES=$(ls)
for file in "$FILES"; do  # 全体が1つの文字列として扱われる
  echo "$file"
done

# 最適：配列を使用
mapfile -t FILES < <(ls)
for file in "${FILES[@]}"; do
  echo "$file"
done
```

### ANSI-Cクォート（`$'...'`）

```bash
# エスケープシーケンスを展開
echo $'Line 1\nLine 2\nLine 3'
# 出力：
# Line 1
# Line 2
# Line 3

# タブ
echo $'Name:\tJohn\tAge:\t30'
# 出力：Name:	John	Age:	30

# Unicode文字
echo $'\u2713 Done'
# 出力：✓ Done
```

### 安全なクォート実践

```bash
# ❌ 危険：変数をクォートしない
rm $file  # スペースを含むファイル名で問題が発生

# ✓ 安全：変数をクォート
rm "$file"

# ❌ 危険：コマンド置換をクォートしない
echo The current date is $(date)

# ✓ 安全：コマンド置換をクォート
echo "The current date is $(date)"

# ❌ 危険：配列をクォートしない
files=("file 1.txt" "file 2.txt")
cp ${files[@]} /tmp/  # 間違ったファイル数

# ✓ 安全：配列をクォート
files=("file 1.txt" "file 2.txt")
cp "${files[@]}" /tmp/
```

---

## データ型

Bashは動的型付けだが、変数の型を宣言することで挙動を制御できる。

### 文字列操作

```bash
text="Hello, Bash World!"

# 長さ
echo ${#text}  # 18

# 大文字・小文字変換
echo ${text^^}  # HELLO, BASH WORLD!
echo ${text,,}  # hello, bash world!
echo ${text^}   # Hello, bash world! (先頭のみ大文字)

# 部分文字列抽出
echo ${text:0:5}   # Hello
echo ${text:7}     # Bash World!
echo ${text: -6}   # World! (後ろから6文字)

# パターン削除
echo ${text#*,}    # " Bash World!" (最短一致で先頭から削除)
echo ${text##*,}   # " Bash World!" (最長一致で先頭から削除)
echo ${text%,*}    # "Hello" (最短一致で末尾から削除)
echo ${text%%,*}   # "Hello" (最長一致で末尾から削除)

# 置換
echo ${text/Bash/Shell}   # "Hello, Shell World!" (最初の1つのみ)
echo ${text//o/0}         # "Hell0, Bash W0rld!" (全て)
```

### インデックス配列

```bash
# 宣言
colors=("red" "green" "blue")

# 要素追加
colors+=("yellow")

# 要素アクセス
echo ${colors[0]}   # red
echo ${colors[1]}   # green
echo ${colors[-1]}  # yellow (最後の要素)

# 全要素
echo "${colors[@]}"  # red green blue yellow
echo "${colors[*]}"  # red green blue yellow

# 要素数
echo ${#colors[@]}  # 4

# インデックス一覧
echo "${!colors[@]}"  # 0 1 2 3

# ループ
for color in "${colors[@]}"; do
  echo "Color: $color"
done

# インデックス付きループ
for i in "${!colors[@]}"; do
  echo "colors[$i] = ${colors[$i]}"
done

# スライス
echo "${colors[@]:1:2}"  # green blue (インデックス1から2つ)

# 要素削除
unset colors[1]  # greenを削除
echo "${colors[@]}"  # red blue yellow
```

### 連想配列

```bash
# 宣言（必須）
declare -A config

# 要素設定
config[host]="localhost"
config[port]=8080
config[user]="admin"

# 要素アクセス
echo ${config[host]}  # localhost

# 全キー
echo "${!config[@]}"  # host port user

# 全値
echo "${config[@]}"   # localhost 8080 admin

# ループ
for key in "${!config[@]}"; do
  echo "$key = ${config[$key]}"
done

# 要素の存在確認
if [[ -v config[host] ]]; then
  echo "host is set"
fi

# 初期化構文
declare -A user_ages=(
  [alice]=30
  [bob]=25
  [charlie]=35
)
```

---

## パラメータ展開

### デフォルト値

```bash
# ${var:-default} : varが未設定またはnullなら default を使用（var自体は変更されない）
echo ${UNDEFINED:-"default value"}  # "default value"
echo $UNDEFINED  # （空文字）

# ${var:=default} : varが未設定またはnullなら default を設定して使用
echo ${UNDEFINED:="default value"}  # "default value"
echo $UNDEFINED  # "default value"

# ${var:+alternate} : varが設定されていれば alternate を使用
VAR="value"
echo ${VAR:+"alternate"}  # "alternate"
echo ${UNDEFINED:+"alternate"}  # （空文字）

# ${var:?message} : varが未設定ならエラーメッセージを表示して終了
echo ${REQUIRED_VAR:?"REQUIRED_VAR must be set"}
```

### 実用例：設定ファイルとデフォルト値

```bash
#!/bin/bash

# 環境変数からの読み込み、未設定ならデフォルト値
: ${CONFIG_FILE:="/etc/app/config.conf"}
: ${LOG_LEVEL:="INFO"}
: ${MAX_RETRIES:=3}

echo "Config file: $CONFIG_FILE"
echo "Log level: $LOG_LEVEL"
echo "Max retries: $MAX_RETRIES"

# 必須変数のチェック
: ${DATABASE_URL:?"DATABASE_URL environment variable is required"}
```

### 文字列操作

```bash
filename="document.backup.tar.gz"

# パターン削除（先頭から）
echo ${filename#*.}    # backup.tar.gz (最短一致)
echo ${filename##*.}   # gz (最長一致)

# パターン削除（末尾から）
echo ${filename%.*}    # document.backup.tar (最短一致)
echo ${filename%%.*}   # document (最長一致)

# 実用例：拡張子の取得
extension=${filename##*.}
echo $extension  # gz

# 実用例：ベース名の取得
basename=${filename%%.*}
echo $basename  # document
```

### 置換

```bash
text="The quick brown fox jumps over the lazy dog"

# 最初の1つを置換
echo ${text/the/a}  # "The quick brown fox jumps over a lazy dog"

# 全て置換
echo ${text//o/0}   # "The quick br0wn f0x jumps 0ver the lazy d0g"

# 先頭一致で置換
echo ${text/#The/A}  # "A quick brown fox jumps over the lazy dog"

# 末尾一致で置換
echo ${text/%dog/cat}  # "The quick brown fox jumps over the lazy cat"

# 実用例：パスの置換
path="/home/user/documents/file.txt"
echo ${path/\/home\/user/~}  # "~/documents/file.txt"
```

### 長さとスライス

```bash
text="Hello, World!"

# 文字列長
echo ${#text}  # 13

# 配列長
array=(a b c d e)
echo ${#array[@]}  # 5

# スライス
echo ${text:0:5}   # "Hello"
echo ${text:7}     # "World!"
echo ${text: -6}   # "World!" (後ろから)
echo ${text: -6:5} # "World" (後ろから6文字目から5文字)
```

---

## 関連リファレンス

- [FUNDAMENTALS.md](./FUNDAMENTALS.md): シェルアーキテクチャ、起動ファイル、変数、ビルトインコマンド
- [CONTROL-FLOW.md](./CONTROL-FLOW.md): 条件分岐、ループ、関数の実装パターン
- [IO-PIPELINES.md](./IO-PIPELINES.md): 入出力、パイプライン、プロセス置換
