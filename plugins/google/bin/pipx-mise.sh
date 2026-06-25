#!/usr/bin/env bash
set -euo pipefail
# mise があれば mise 経由（プロジェクト指定の Python/pipx を使う）、無ければ素の pipx にフォールバック。
# analytics-mcp は Google Analytics 公式の PyPI パッケージ。pipx run で一時環境に取得して MCP サーバーを起動する。
if command -v mise >/dev/null 2>&1; then
  exec mise exec -- pipx run "$@"
elif command -v pipx >/dev/null 2>&1; then
  exec pipx run "$@"
else
  echo "pipx-mise.sh: 'mise' も 'pipx' も PATH に見つかりません。Python 3.10+ と pipx を導入してください。" >&2
  exit 127
fi
