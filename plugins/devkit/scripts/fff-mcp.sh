#!/usr/bin/env bash
set -euo pipefail
# fff-mcp ランチャー（devkit）
# fff MCP サーバ（高速ファイル検索・https://github.com/dmtrKovalenko/fff.nvim）を
# どのプロジェクトからでも起動できるようにするラッパー。
# fff-mcp はネイティブバイナリ（npx 不可）のため、PATH→~/.local/bin の順に解決し、
# 無ければ公式インストーラ（SHA256 検証付き）で ~/.local/bin に自動取得する。
# frecency / history DB を XDG 準拠パスで永続化し、検索ランキングをユーザー横断で蓄積する。

INSTALL_DIR="${FFF_MCP_INSTALL_DIR:-$HOME/.local/bin}"

# 1. バイナリ解決
fff_bin=""
if command -v fff-mcp >/dev/null 2>&1; then
  fff_bin="$(command -v fff-mcp)"
elif [ -x "$INSTALL_DIR/fff-mcp" ]; then
  fff_bin="$INSTALL_DIR/fff-mcp"
fi

# 2. 無ければ公式インストーラで自動取得
if [ -z "$fff_bin" ]; then
  echo "fff-mcp.sh: fff-mcp が見つかりません。公式インストーラで取得します..." >&2
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL https://raw.githubusercontent.com/dmtrKovalenko/fff.nvim/main/install-mcp.sh | bash >&2 \
      || { echo "fff-mcp.sh: 自動インストールに失敗。'brew install dmtrKovalenko/fff/fff-mcp' を試してください。" >&2; exit 127; }
    fff_bin="$INSTALL_DIR/fff-mcp"
  else
    echo "fff-mcp.sh: curl が見つかりません。fff-mcp を手動導入してください: https://github.com/dmtrKovalenko/fff.nvim" >&2
    exit 127
  fi
fi

if [ ! -x "$fff_bin" ]; then
  echo "fff-mcp.sh: fff-mcp バイナリを実行できません: $fff_bin" >&2
  exit 127
fi

# 3. frecency / history DB を XDG 準拠で永続化（ユーザー横断で蓄積）
frecency_db="${XDG_CACHE_HOME:-$HOME/.cache}/fff/frecency.db"
history_db="${XDG_DATA_HOME:-$HOME/.local/share}/fff/history.db"
mkdir -p "$(dirname "$frecency_db")" "$(dirname "$history_db")"

# 4. 起動（PATH 引数は省略 = MCP クライアントの作業ディレクトリをインデックス）
exec "$fff_bin" \
  --no-update-check \
  --frecency-db "$frecency_db" \
  --history-db "$history_db" \
  "$@"
