#!/usr/bin/env bash
# skills/ 配下の各スキルフォルダを個別にzip化するスクリプト
set -euo pipefail

# ヘルプメッセージ
usage() {
  cat << EOF
Usage: $(basename "$0") [OUTPUT_DIR]

skills/ 配下の各スキルフォルダを個別にzip化し、指定ディレクトリに出力します。

Arguments:
  OUTPUT_DIR  zip ファイルの出力先ディレクトリ (デフォルト: $HOME/Desktop)

Options:
  -h, --help  このヘルプメッセージを表示

除外対象:
  - node_modules/
  - .DS_Store

Zip 内部構造:
  SKILL.md がzipのルート直下に来るように圧縮します。

例:
  $(basename "$0")                    # デフォルト出力先 (Desktop)
  $(basename "$0") ./dist             # ./dist に出力
EOF
}

# ヘルプオプション処理
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

# 出力先ディレクトリ（引数がなければデフォルト: $HOME/Desktop）
OUTPUT_DIR="${1:-$HOME/Desktop}"

# skills ディレクトリの存在確認
if [[ ! -d "skills" ]]; then
  echo "Error: skills/ ディレクトリが見つかりません。リポジトリルートから実行してください。" >&2
  exit 1
fi

# 出力先ディレクトリを作成（存在しない場合）
mkdir -p "$OUTPUT_DIR"

# zip ファイル数カウンタ
count=0

# skills/ 配下の各ディレクトリを処理
for skill_dir in skills/*/; do
  # ディレクトリが存在しない場合（globが展開されなかった場合）はスキップ
  [[ -d "$skill_dir" ]] || continue

  # スキル名を取得（末尾のスラッシュを削除してbasenameを取得）
  skill_name=$(basename "$skill_dir")

  # 出力zipファイル名
  zip_file="$OUTPUT_DIR/${skill_name}.zip"

  # 既存zipがあれば削除（上書きのため）
  [[ -f "$zip_file" ]] && rm -f "$zip_file"

  # サブシェル内でスキルディレクトリに移動してzip作成
  # -r: 再帰的に圧縮
  # -q: 静かに実行（進捗を表示しない）
  # -x: 除外パターン
  (
    cd "$skill_dir"
    zip -r -q "$zip_file" . -x "node_modules/*" -x "*.DS_Store" -x "*/__pycache__/*"
  )

  ((count++))
  echo "Created: $zip_file"
done

# 完了メッセージ
echo ""
echo "✅ $count 個のzipファイルを作成しました"
echo "出力先: $OUTPUT_DIR"
