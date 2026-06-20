#!/usr/bin/env bash
set -euo pipefail
# fff-mcp ランチャー（devkit）
# fff MCP サーバ（高速ファイル検索・https://github.com/dmtrKovalenko/fff.nvim）を
# どのプロジェクトからでも起動できるようにするラッパー。
# fff-mcp はネイティブバイナリ（npx 不可）のため、PATH→~/.local/bin の順に解決し、
# 無ければ公式インストーラ（SHA256 検証付き）で ~/.local/bin に自動取得する。
# frecency / history DB を XDG 準拠パスで永続化し、検索ランキングをユーザー横断で蓄積する。

INSTALL_DIR="${FFF_MCP_INSTALL_DIR:-$HOME/.local/bin}"

resolve_parent_cwd() {
  local parent_pid="${1:-}"
  local parent_cwd=""

  if [[ -z "$parent_pid" ]]; then
    return 1
  fi

  if [[ -e "/proc/$parent_pid/cwd" ]]; then
    parent_cwd="$(cd "/proc/$parent_pid/cwd" 2>/dev/null && pwd -P)" || true
    if [[ -n "$parent_cwd" && -d "$parent_cwd" ]]; then
      printf '%s\n' "$parent_cwd"
      return 0
    fi
  fi

  if command -v lsof >/dev/null 2>&1; then
    parent_cwd="$(lsof -a -p "$parent_pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | tail -n 1)" || true
    if [[ -n "$parent_cwd" && -d "$parent_cwd" ]]; then
      printf '%s\n' "$parent_cwd"
      return 0
    fi
  fi

  if command -v pwdx >/dev/null 2>&1; then
    parent_cwd="$(pwdx "$parent_pid" 2>/dev/null | sed 's/^[^:]*: //')" || true
    if [[ -n "$parent_cwd" && -d "$parent_cwd" ]]; then
      printf '%s\n' "$parent_cwd"
      return 0
    fi
  fi

  return 1
}

resolve_base_path() {
  local current_pwd=""
  local parent_cwd=""

  if [[ -n "${FFF_MCP_BASE_PATH:-}" ]]; then
    if [[ ! -d "$FFF_MCP_BASE_PATH" ]]; then
      echo "fff-mcp.sh: FFF_MCP_BASE_PATH が存在するディレクトリではありません: $FFF_MCP_BASE_PATH" >&2
      exit 64
    fi
    (cd "$FFF_MCP_BASE_PATH" && pwd -P)
    return 0
  fi

  current_pwd="$(pwd -P)"
  case "$current_pwd" in
    *"/.codex/plugins/cache/"*|*"/.codex/.tmp/marketplaces/"*|*"/.claude/plugins/cache/"*)
      if parent_cwd="$(resolve_parent_cwd "$PPID")" && [[ -n "$parent_cwd" && "$parent_cwd" != "$current_pwd" ]]; then
        printf '%s\n' "$parent_cwd"
        return 0
      fi
      ;;
  esac

  printf '%s\n' "$current_pwd"
}

has_positional_arg() {
  local skip_next=false
  local arg

  for arg in "$@"; do
    if [[ "$skip_next" == true ]]; then
      skip_next=false
      continue
    fi

    case "$arg" in
      --frecency-db|--history-db|--log-file|--log-level|--max-cached-files)
        skip_next=true
        ;;
      --*=*|--*)
        ;;
      *)
        return 0
        ;;
    esac
  done

  return 1
}

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

# 4. 起動
# Codex の plugin MCP は cwd="." をプラグインキャッシュに解決するため、
# 明示 PATH がない場合は親 Codex プロセスの cwd を fff-mcp の base path として渡す。
base_path="$(resolve_base_path)"
args=("$@")
if ! has_positional_arg "$@"; then
  args+=("$base_path")
fi

exec "$fff_bin" \
  --no-update-check \
  --frecency-db "$frecency_db" \
  --history-db "$history_db" \
  "${args[@]}"
