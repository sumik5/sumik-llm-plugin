#!/usr/bin/env bash
set -euo pipefail
# mise があれば mise 経由（プロジェクト指定のNode/npxを使う）、無ければ素の npx にフォールバック
if command -v mise >/dev/null 2>&1; then
  exec mise exec -- npx "$@"
elif command -v npx >/dev/null 2>&1; then
  exec npx "$@"
else
  echo "npx-mise.sh: 'mise' も 'npx' も PATH に見つかりません。Node.js / mise を導入してください。" >&2
  exit 127
fi
