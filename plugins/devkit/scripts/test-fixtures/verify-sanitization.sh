#!/usr/bin/env bash
set -euo pipefail

# md-to-html.sh のサニタイズ回帰テスト。
# malicious-sample.md を変換し、5種の攻撃ベクタが無害化されていることを機械的に検証する。
# 使い方: test-fixtures/verify-sanitization.sh

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fixture_md="$script_dir/malicious-sample.md"
fixture_html="$script_dir/malicious-sample.html"
md_to_html="$script_dir/../md-to-html.sh"

fail=0

assert_absent() {
  local description="$1"
  local pattern="$2"
  if /usr/bin/grep -qE "$pattern" "$fixture_html"; then
    echo "FAIL: $description"
    fail=1
  else
    echo "PASS: $description"
  fi
}

assert_present() {
  local description="$1"
  local pattern="$2"
  if /usr/bin/grep -qE "$pattern" "$fixture_html"; then
    echo "PASS: $description"
  else
    echo "FAIL: $description"
    fail=1
  fi
}

"$md_to_html" "$fixture_md" "$fixture_html"

if [[ ! -f "$fixture_html" ]]; then
  echo "FAIL: HTMLが生成されていない: $fixture_html"
  exit 1
fi

assert_absent "生scriptタグが残っていない" '<script[ >]'
assert_absent "生iframeタグが残っていない" '<iframe[ >]'
assert_absent "生onerror属性つきimgタグが残っていない" '<img [^>]*onerror='
assert_absent "javascript:リンクが無害化されている" 'href="javascript:'
assert_present "CSP metaタグが存在する" 'Content-Security-Policy'
assert_present "CSPがimg-srcをdata:のみに制限している(外部画像フェッチをブロック)" 'img-src data:'

exit $fail
