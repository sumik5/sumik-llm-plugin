#!/usr/bin/env bash
set -euo pipefail
# mise があれば mise 経由、無ければ素の uvx にフォールバック
if command -v mise >/dev/null 2>&1; then
  exec mise exec -- uvx "$@"
elif command -v uvx >/dev/null 2>&1; then
  exec uvx "$@"
else
  echo "uvx-mise.sh: 'mise' も 'uvx' も PATH に見つかりません。uv / mise を導入してください。" >&2
  exit 127
fi
