#!/usr/bin/env bash
set -euo pipefail

# レビュー資材(.md)をブラウザで読みやすいスタンドアロンHTMLへ変換する。
# 生HTML・危険URLスキームの無害化は同梱の md-to-html-sanitize.lua が主経路。
# 使い方: md-to-html.sh <input.md> [output.html]

usage() {
  echo "Usage: md-to-html.sh <input.md> [output.html]" >&2
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
  exit 1
fi

input="$1"

if [[ "$input" != *.md ]]; then
  echo "md-to-html.sh: error: 入力は.mdファイルを指定してください: $input" >&2
  exit 1
fi

if [[ ! -f "$input" ]]; then
  echo "md-to-html.sh: error: 入力ファイルが見つかりません: $input" >&2
  exit 1
fi

output="${2:-${input%.md}.html}"

if [[ "$output" != *.html ]]; then
  echo "md-to-html.sh: error: 出力パスは.htmlで終わる必要があります: $output" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
lua_filter="$script_dir/md-to-html-sanitize.lua"

if [[ ! -f "$lua_filter" ]]; then
  echo "md-to-html.sh: error: サニタイズ用Luaフィルタが見つかりません: $lua_filter" >&2
  exit 1
fi

if ! command -v pandoc >/dev/null 2>&1; then
  echo "md-to-html.sh: warning: pandoc未検出のためHTMLは生成しませんでした。brew install pandocで有効化されます" >&2
  exit 0
fi

title="$(basename "$input" .md)"
first_heading="$(/usr/bin/grep -m1 '^# ' "$input" 2>/dev/null || true)"
if [[ -n "$first_heading" ]]; then
  title="${first_heading#\# }"
fi

header_file="$(mktemp "${TMPDIR:-/tmp}/md-to-html-header.XXXXXX.html")"
trap 'rm -f "$header_file"' EXIT

cat > "$header_file" <<'HEADER_EOF'
<meta http-equiv="Content-Security-Policy"
      content="default-src 'none'; img-src data:; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'">
<style>
  body {
    max-width: 860px;
    margin: 2rem auto;
    padding: 0 1.5rem;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
    line-height: 1.7;
    color: #1f2328;
  }
  h1, h2, h3, h4, h5, h6 {
    line-height: 1.3;
    margin-top: 2em;
    margin-bottom: 0.6em;
  }
  h1 { border-bottom: 1px solid #d0d7de; padding-bottom: 0.3em; }
  h2 { border-bottom: 1px solid #eaeef2; padding-bottom: 0.3em; }
  table {
    border-collapse: collapse;
    width: 100%;
    margin: 1em 0;
    overflow-x: auto;
    display: block;
  }
  th, td {
    border: 1px solid #d0d7de;
    padding: 0.4em 0.8em;
    text-align: left;
  }
  th { background: #f6f8fa; }
  code {
    font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
    background: #f6f8fa;
    padding: 0.15em 0.4em;
    border-radius: 4px;
  }
  pre {
    background: #f6f8fa;
    padding: 1em;
    border-radius: 6px;
    overflow-x: auto;
  }
  pre code { background: none; padding: 0; }
  blockquote {
    margin: 1em 0;
    padding: 0 1em;
    color: #57606a;
    border-left: 4px solid #d0d7de;
  }
  a { color: #0969da; }
</style>
HEADER_EOF

pandoc "$input" \
  -f gfm-raw_html-raw_attribute \
  -t html5 \
  --standalone \
  --lua-filter "$lua_filter" \
  --metadata title="$title" \
  --metadata document-css=false \
  --include-in-header "$header_file" \
  -o "$output"

echo "md-to-html.sh: 生成しました: $output"
