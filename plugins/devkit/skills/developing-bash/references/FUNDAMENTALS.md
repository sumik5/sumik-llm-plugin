# Bash 基礎知識

Bashスクリプト開発における基礎的な概念と実装パターン。

## 目次

1. [シェルアーキテクチャ](#シェルアーキテクチャ)
2. [起動ファイル](#起動ファイル)
3. [変数](#変数)
4. [ビルトインコマンド vs 外部コマンド](#ビルトインコマンド-vs-外部コマンド)
5. [Unicode・エンコーディング・ロケール](#unicode-エンコーディング-ロケール)

---

## シェルアーキテクチャ

### シェルの種類

Bashシェルは、起動方法によって4つのモードに分類される：

| モード | login | interactive | 説明 | 起動例 |
|--------|-------|-------------|------|--------|
| login + interactive | ✓ | ✓ | ユーザーがログイン時に起動 | SSHログイン、コンソールログイン |
| non-login + interactive | ✗ | ✓ | ターミナルエミュレータで起動 | GNOME Terminal、iTerm2 |
| login + non-interactive | ✓ | ✗ | リモートコマンド実行 | `ssh user@host command` |
| non-login + non-interactive | ✗ | ✗ | スクリプト実行 | `bash script.sh` |

### 判定方法

```bash
# login shellかどうかを確認
shopt -q login_shell && echo "login shell" || echo "non-login shell"

# interactive shellかどうかを確認
[[ $- == *i* ]] && echo "interactive" || echo "non-interactive"

# $0の値で判定（login shellは先頭に'-'が付く）
case "$0" in
  -*) echo "login shell" ;;
  *) echo "non-login shell" ;;
esac
```

### シェルの起動プロセス

```
login shell (interactive):
  /etc/profile
    ↓
  ~/.bash_profile (存在すれば)
    ↓ (なければ)
  ~/.bash_login (存在すれば)
    ↓ (なければ)
  ~/.profile

non-login shell (interactive):
  /etc/bash.bashrc
    ↓
  ~/.bashrc

non-interactive shell:
  $BASH_ENV (指定されていれば)
```

---

## 起動ファイル

### ファイルの役割

| ファイル | 読み込まれるシェル | 用途 | 設定すべき内容 |
|---------|-------------------|------|---------------|
| `~/.bash_profile` | login (interactive) | ログイン時の初期化 | 環境変数、PATH、ログイン時のみ実行すべきコマンド |
| `~/.bashrc` | non-login (interactive) | 対話シェルの設定 | エイリアス、関数、プロンプト、シェルオプション |
| `~/.profile` | login (sh互換) | POSIX互換設定 | 環境変数（Bash以外のシェルでも有効） |
| `~/.bash_logout` | login終了時 | ログアウト処理 | 一時ファイル削除、画面クリア |

### 設定例：~/.bash_profile

```bash
# ~/.bash_profileから~/.bashrcを読み込むパターン（推奨）
if [ -f ~/.bashrc ]; then
  source ~/.bashrc
fi

# 環境変数（全子プロセスに継承）
export PATH="$HOME/bin:$PATH"
export EDITOR=vim
export LANG=ja_JP.UTF-8

# ログイン時のみ実行
if [ -x /usr/bin/fortune ]; then
  fortune
fi
```

### 設定例：~/.bashrc

```bash
# シェルオプション
shopt -s histappend    # 履歴を上書きせず追記
shopt -s checkwinsize  # ウィンドウサイズを自動調整

# エイリアス
alias ll='ls -lah'
alias grep='grep --color=auto'

# プロンプト
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

# 関数（このシェルセッション内のみ有効）
mkcd() {
  mkdir -p "$1" && cd "$1"
}
```

### 判断基準：どのファイルに何を書くか

```bash
# 判断フロー
if [[ "全子プロセスに継承したい" ]]; then
  # ~/.bash_profile または ~/.profile に書く
  export VARIABLE=value
elif [[ "対話シェルでのみ使う" ]]; then
  # ~/.bashrc に書く
  alias shortcut='command'
elif [[ "Bash以外のシェルでも使いたい" ]]; then
  # ~/.profile に書く（POSIX互換の構文のみ）
  export VARIABLE=value
fi
```

---

## 変数

### 変数の種類

| 種類 | 宣言方法 | スコープ | 子プロセスへの継承 |
|------|---------|---------|-------------------|
| ローカル変数 | `local var=value` | 関数内のみ | ✗ |
| グローバル変数 | `var=value` | 現在のシェルセッション | ✗ |
| 環境変数 | `export var=value` | 現在のシェル + 子プロセス | ✓ |
| 読み取り専用変数 | `readonly var=value` | 現在のシェルセッション（変更不可） | ✗ |

### 変数宣言の例

```bash
#!/bin/bash

# グローバル変数
GLOBAL_VAR="I'm global"

function demo_scope() {
  # ローカル変数（関数内のみ有効）
  local LOCAL_VAR="I'm local"

  # グローバル変数を上書き（関数外にも影響）
  GLOBAL_VAR="Modified global"

  echo "Inside function:"
  echo "  LOCAL_VAR: $LOCAL_VAR"
  echo "  GLOBAL_VAR: $GLOBAL_VAR"
}

demo_scope

echo "Outside function:"
# echo "  LOCAL_VAR: $LOCAL_VAR"  # エラー：未定義
echo "  GLOBAL_VAR: $GLOBAL_VAR"  # "Modified global"

# 環境変数
export API_KEY="secret123"
bash -c 'echo "Child process: $API_KEY"'  # "Child process: secret123"

# 読み取り専用変数
readonly CONFIG_FILE="/etc/app/config.conf"
# CONFIG_FILE="/tmp/config"  # エラー：読み取り専用
```

### 特殊変数一覧

| 変数 | 説明 | 例 |
|------|------|-----|
| `$0` | スクリプト名 | `./script.sh` → `./script.sh` |
| `$1`, `$2`, ... | 位置パラメータ（引数） | `script.sh foo bar` → `$1=foo`, `$2=bar` |
| `$#` | 引数の個数 | `script.sh a b c` → `$#=3` |
| `$@` | 全引数（個別の文字列） | `"$@"` → `"arg1" "arg2" "arg3"` |
| `$*` | 全引数（単一の文字列） | `"$*"` → `"arg1 arg2 arg3"` |
| `$$` | 現在のプロセスID | `echo $$` → `12345` |
| `$!` | 最後のバックグラウンドプロセスID | `sleep 10 &; echo $!` → `12346` |
| `$?` | 最後のコマンドの終了ステータス | 成功=0、失敗=1〜255 |
| `$_` | 最後のコマンドの最後の引数 | `ls /tmp; echo $_` → `/tmp` |
| `$LINENO` | 現在の行番号 | デバッグ時に有効 |
| `$FUNCNAME` | 現在の関数名 | デバッグ時に有効 |
| `$BASH_SOURCE` | スクリプトファイル名 | `source` で読み込まれた場合に有効 |

### $@ と $* の違い

```bash
#!/bin/bash

function show_args_at() {
  echo "Number of arguments: $#"
  for arg in "$@"; do
    echo "  [$arg]"
  done
}

function show_args_star() {
  echo "Number of arguments: $#"
  for arg in "$*"; do
    echo "  [$arg]"
  done
}

# 実行例
show_args_at "arg 1" "arg 2" "arg 3"
# 出力：
# Number of arguments: 3
#   [arg 1]
#   [arg 2]
#   [arg 3]

show_args_star "arg 1" "arg 2" "arg 3"
# 出力：
# Number of arguments: 1
#   [arg 1 arg 2 arg 3]
```

**推奨**: ほとんどの場合、`"$@"` を使用すべき。`"$*"` は引数をスペース区切りの単一文字列として扱いたい特殊なケースでのみ使用。

**クォートルール、データ型、パラメータ展開の詳細は [DATA-TYPES.md](./DATA-TYPES.md) を参照してください。**

---

## ビルトインコマンド vs 外部コマンド

### パフォーマンス差

```bash
# ビルトインコマンド（高速）
time for i in {1..1000}; do
  : # null command (builtin)
done
# 実行時間：約0.01秒

# 外部コマンド（遅い、フォークコスト）
time for i in {1..1000}; do
  /bin/true  # 外部コマンド
done
# 実行時間：約0.5秒〜1秒
```

### コマンドの種類を確認

```bash
# type コマンド
type cd        # cd is a shell builtin
type ls        # ls is /bin/ls
type echo      # echo is a shell builtin

# command -v（スクリプトで使用推奨）
if command -v git &> /dev/null; then
  echo "git is available"
fi

# builtin で明示的にビルトインを呼び出す
builtin cd /tmp
```

### 主要なビルトインコマンド

| コマンド | 用途 | 外部コマンドとの違い |
|---------|------|-------------------|
| `cd` | ディレクトリ移動 | シェルのカレントディレクトリを変更（外部プロセスでは不可能） |
| `echo` | テキスト出力 | `/bin/echo` より高速 |
| `read` | 入力読み込み | シェル変数に直接格納 |
| `source`, `.` | スクリプト読み込み | 現在のシェルで実行（外部プロセスを起動しない） |
| `export` | 環境変数設定 | 現在のシェルの環境を変更 |
| `set` | シェルオプション設定 | 現在のシェルの動作を変更 |
| `test`, `[` | 条件テスト | `/usr/bin/test` より高速 |
| `[[` | 拡張テスト | パターンマッチング、正規表現をサポート |
| `:` | null コマンド | 常に成功（true）を返す |
| `printf` | フォーマット出力 | `/usr/bin/printf` より高速 |

### ビルトインを優先すべきケース

```bash
# ❌ 非効率：外部コマンドを繰り返し呼び出し
for file in *.txt; do
  /bin/echo "Processing $file"  # フォークコスト
  /bin/cat "$file" | while read line; do
    # 処理
  done
done

# ✓ 効率的：ビルトインを使用
for file in *.txt; do
  echo "Processing $file"  # ビルトイン
  while IFS= read -r line; do
    # 処理
  done < "$file"
done
```

---

## Unicode・エンコーディング・ロケール

### ロケール環境変数

| 変数 | 用途 | 優先度 |
|------|------|--------|
| `LC_ALL` | 全ロケールを上書き | 最高 |
| `LC_CTYPE` | 文字分類とエンコーディング | |
| `LC_COLLATE` | 文字列比較順序 | |
| `LC_MESSAGES` | メッセージ言語 | |
| `LC_NUMERIC` | 数値フォーマット | |
| `LC_TIME` | 日付・時刻フォーマット | |
| `LANG` | デフォルトロケール | 最低 |

### ロケール設定

```bash
# 現在のロケール確認
locale

# 利用可能なロケール一覧
locale -a

# 日本語UTF-8環境の設定
export LANG=ja_JP.UTF-8
export LC_ALL=ja_JP.UTF-8

# C ロケール（POSIX標準、高速、ASCII のみ）
export LC_ALL=C
```

### マルチバイト文字の扱い

```bash
# UTF-8文字列の長さ
text="こんにちは"
echo ${#text}  # 5（文字数）

# バイト数の取得
echo -n "$text" | wc -c  # 15（UTF-8では1文字3バイト）

# 文字列の切り出し（UTF-8対応）
echo ${text:0:3}  # "こんに"

# 正規表現でのマルチバイト文字
if [[ "$text" =~ ^[ぁ-ん]+$ ]]; then
  echo "Hiragana only"
fi
```

### エンコーディング変換

```bash
# iconv でエンコーディング変換
iconv -f SHIFT-JIS -t UTF-8 input.txt -o output.txt

# nkf（日本語特化）
nkf -w input.txt > output.txt  # UTF-8に変換
nkf -s input.txt > output.txt  # Shift_JISに変換

# ファイルのエンコーディング検出
file -i filename.txt
# 出力：filename.txt: text/plain; charset=utf-8
```

### ロケール依存の落とし穴

```bash
# ❌ ロケール依存のソート（日本語環境では予期しない順序）
echo -e "b\na\nZ" | sort
# 出力（LC_ALL=ja_JP.UTF-8）：a b Z

# ✓ C ロケールで確実なソート
echo -e "b\na\nZ" | LC_ALL=C sort
# 出力：Z a b

# ❌ ロケール依存の大文字小文字変換
var="aBc"
echo ${var^^}  # ABC（期待通り）
var="straße"  # ドイツ語
echo ${var^^}  # STRASSE（ロケールに依存）

# ✓ tr コマンドで確実な変換
echo "aBc" | tr '[:lower:]' '[:upper:]'  # ABC
```

### スクリプトでのロケール設定

```bash
#!/bin/bash

# スクリプト全体で C ロケールを使用（移植性を確保）
export LC_ALL=C

# 日本語のログメッセージを出力する場合のみ一時的に変更
log_message() {
  local message="$1"
  LC_ALL=ja_JP.UTF-8 echo "[$(date)] $message"
}

# 処理（C ロケールで高速・確実）
sort input.txt > output.txt

# ログ出力（日本語）
log_message "処理が完了しました"
```

---

## まとめ

### チェックリスト

- [ ] シェルの種類（login/non-login、interactive/non-interactive）を理解している
- [ ] 起動ファイルの読み込み順序を把握している
- [ ] 変数のスコープ（local、global、環境変数）を使い分けている
- [ ] クォートルールを理解し、安全なスクリプトを書いている
- [ ] 配列（インデックス、連想）を使いこなしている
- [ ] パラメータ展開でデフォルト値や文字列操作を活用している
- [ ] ビルトインコマンドを優先してパフォーマンスを確保している
- [ ] ロケールとエンコーディングを適切に設定している

### 次のステップ

- [DATA-TYPES.md](./DATA-TYPES.md): クォートルール、データ型、パラメータ展開
- [CONTROL-FLOW.md](./CONTROL-FLOW.md): 条件分岐、ループ、関数の実装パターン
- [IO-PIPELINES.md](./IO-PIPELINES.md): 入出力、パイプライン、プロセス置換
- [AUTOMATION.md](./AUTOMATION.md): タスク自動化、スケジューリング、エラーハンドリング
