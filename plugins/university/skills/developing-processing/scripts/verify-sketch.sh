#!/usr/bin/env bash
#
# verify-sketch.sh — Processing 4.5.2 のスケッチを CLI でコンパイル/実行し、
#                    成否を堅牢に判定するヘルパー。
#
# Processing 4.4.3 以降、旧 `processing-java` は廃止され、Java Mode の
# コマンドライン版は `processing cli` サブコマンドに集約された。
# 本スクリプトはこの新 CLI を前提に動作する。
#
# サブコマンド:
#   build  <sketch_dir> [output_dir]               プリプロセス+コンパイルのみ（ウィンドウを開かない）
#   run    <sketch_dir> [timeout_sec] [output_dir]  プリプロセス+コンパイル+実行（ウィンドウを開く）
#   format <pde_file>                               .pde を整形して標準出力へ
#
# バイナリは PROCESSING_BIN 環境変数で上書き可能。
# 既定: /Applications/Processing.app/Contents/MacOS/Processing
#
set -euo pipefail

# ============================================================================
# 設定
# ============================================================================

# Processing バイナリ。PROCESSING_BIN が設定されていればそれを優先。
PROCESSING_BIN="${PROCESSING_BIN:-/Applications/Processing.app/Contents/MacOS/Processing}"

# run サブコマンドの既定タイムアウト秒数。
DEFAULT_TIMEOUT_SEC=20

# 出力フォルダの既定名（スケッチフォルダの隣に作る）。
# Processing CLI は output を sketch と同一フォルダにできないため別ディレクトリにする。
OUTPUT_SUFFIX=".verify-out"

# ============================================================================
# ユーティリティ
# ============================================================================

# 標準エラーへメッセージを出すだけのログ関数。
log() {
  printf '%s\n' "$*" >&2
}

# usage を表示する。引数不足や不正サブコマンド時に呼ぶ。
usage() {
  cat >&2 <<'EOF'
Usage:
  verify-sketch.sh build  <sketch_dir> [output_dir]
  verify-sketch.sh run    <sketch_dir> [timeout_sec] [output_dir]
  verify-sketch.sh format <pde_file>

サブコマンド:
  build   スケッチをコンパイルのみ実行（ウィンドウを開かない・ヘッドレス検証向き）。
          exit code / stderr のエラー行 / <sketch>.class 生成 の三点で成否を判定する。

  run     スケッチを実行（ウィンドウを開く）。timeout で包んで暴走を防ぐ。
          timeout_sec の既定は 20 秒。コンパイルエラー・実行時例外を検出すると FAIL。

  format  .pde ファイルを整形して標準出力へ書き出す（ファイルは上書きしない）。

環境変数:
  PROCESSING_BIN   Processing バイナリのパス。
                   既定: /Applications/Processing.app/Contents/MacOS/Processing

例:
  verify-sketch.sh build  ~/sketches/my_sketch
  verify-sketch.sh run    ~/sketches/my_sketch 10
  verify-sketch.sh format ~/sketches/my_sketch/my_sketch.pde
EOF
}

# Processing バイナリの存在を確認する。無ければ明確なエラーで終了。
require_binary() {
  if [[ ! -x "$PROCESSING_BIN" ]]; then
    log "エラー: Processing バイナリが見つからないか実行できません: $PROCESSING_BIN"
    log "       PROCESSING_BIN 環境変数で正しいパスを指定してください。"
    log "       例: PROCESSING_BIN=/path/to/Processing verify-sketch.sh build <dir>"
    exit 1
  fi
}

# timeout コマンドを解決する。GNU の gtimeout があれば優先、無ければ timeout、
# どちらも無ければ空文字（= timeout なしで実行）を返す。
resolve_timeout_cmd() {
  if command -v gtimeout >/dev/null 2>&1; then
    command -v gtimeout
  elif command -v timeout >/dev/null 2>&1; then
    command -v timeout
  else
    printf ''
  fi
}

# スケッチフォルダの妥当性を検証する。
# - フォルダが存在するか
# - メインタブ <フォルダ名>.pde が存在するか
# Processing はメインタブが「<フォルダ名>.pde」でないと認識しないため事前に親切に弾く。
# 成功時はメイン .pde の絶対パスを標準出力へ返す。
validate_sketch_dir() {
  local sketch_dir="$1"

  if [[ ! -d "$sketch_dir" ]]; then
    log "エラー: スケッチフォルダが存在しません: $sketch_dir"
    exit 1
  fi

  # 末尾スラッシュを除去してフォルダ名を取り出す。
  local sketch_name
  sketch_name="$(basename "${sketch_dir%/}")"
  local main_pde="${sketch_dir%/}/${sketch_name}.pde"

  if [[ ! -f "$main_pde" ]]; then
    log "エラー: メインタブの .pde が見つかりません。"
    log "       Processing はフォルダ名と同名の .pde をメインタブとして要求します。"
    log "       期待されるファイル: $main_pde"
    # ヒントとして実在する .pde を列挙する。
    local found
    found="$(find "$sketch_dir" -maxdepth 1 -name '*.pde' 2>/dev/null || true)"
    if [[ -n "$found" ]]; then
      log "       フォルダ内に存在する .pde:"
      printf '         %s\n' $found >&2
      log "       フォルダ名または .pde 名をリネームして一致させてください。"
    fi
    exit 1
  fi

  printf '%s\n' "$main_pde"
}

# 出力フォルダを決定する。引数で指定があればそれを、無ければスケッチ隣の既定名を使う。
# sketch_dir と同一は Processing が拒否するため、ここでも保険で弾く。
resolve_output_dir() {
  local sketch_dir="$1"
  local explicit="${2:-}"
  local out_dir

  if [[ -n "$explicit" ]]; then
    out_dir="$explicit"
  else
    out_dir="${sketch_dir%/}${OUTPUT_SUFFIX}"
  fi

  # 正規化して同一判定する（末尾スラッシュ差異を吸収）。
  if [[ "${out_dir%/}" == "${sketch_dir%/}" ]]; then
    log "エラー: 出力フォルダをスケッチフォルダと同一にはできません: $out_dir"
    exit 1
  fi

  printf '%s\n' "$out_dir"
}

# stderr ログから Processing のエラー行（<file>.pde:l:c:l:c: メッセージ 形式）を抽出する。
# コンパイルエラーも実行時例外も同じ位置情報付き形式で出るため共通で使える。
# 行が見つかれば標準出力に流し、戻り値 0。無ければ戻り値 1。
extract_pde_errors() {
  local stderr_file="$1"
  # 例: bad_sketch.pde:3:0:3:0: The function ... does not exist.
  #     sketch.pde:5:2:5:2: ArrayIndexOutOfBoundsException: Index 5 ...
  if /usr/bin/grep -nE '\.pde:[0-9]+:[0-9]+:' "$stderr_file" >/dev/null 2>&1; then
    /usr/bin/grep -nE '\.pde:[0-9]+:[0-9]+:' "$stderr_file"
    return 0
  fi
  return 1
}

# ============================================================================
# build サブコマンド
# ============================================================================
#
# processing cli --sketch=... --output=... --force --build を実行する。
# パイプは使わず（パイプ末尾の終了コードに化けるのを防ぐ）、stdout/stderr を
# 一時ファイルへ退避してから読む。三点照合で成否を判定する:
#   (1) exit code        … 0=成功 / 1=コンパイル失敗
#   (2) stderr のエラー行 … *.pde:l:c: 形式があれば失敗
#   (3) <sketch>.class    … 成功時のみ output に生成される
#
cmd_build() {
  local sketch_dir="${1:-}"
  local output_dir_arg="${2:-}"

  if [[ -z "$sketch_dir" ]]; then
    usage
    exit 1
  fi

  require_binary

  # スケッチ検証（メイン .pde の絶対パスを取得）。
  local main_pde
  main_pde="$(validate_sketch_dir "$sketch_dir")"
  local sketch_name
  sketch_name="$(basename "${sketch_dir%/}")"

  # 出力フォルダを決定し、毎回クリーンにする（--force 相当）。
  local output_dir
  output_dir="$(resolve_output_dir "$sketch_dir" "$output_dir_arg")"
  /bin/rm -rf "$output_dir"
  mkdir -p "$output_dir"

  # stdout/stderr の退避先。
  local out_log err_log
  out_log="$(mktemp -t verify-sketch-build-out.XXXXXX)"
  err_log="$(mktemp -t verify-sketch-build-err.XXXXXX)"
  # 関数終了時に必ず後始末する。
  trap 'rm -f "${out_log:-}" "${err_log:-}"' RETURN

  log "==> build: $sketch_name"
  log "    sketch: $sketch_dir"
  log "    output: $output_dir"

  # set -e 下でも exit code を取りこぼさないよう、明示的に捕捉する。
  # 🔴 パイプ禁止: パイプすると $? がパイプ末尾コマンドの終了コードに化ける。
  #    --build は必ず最後の引数（これより後ろはスケッチ側へ渡るため）。
  local rc=0
  "$PROCESSING_BIN" cli \
    --sketch="$sketch_dir" \
    --output="$output_dir" \
    --force \
    --build \
    >"$out_log" 2>"$err_log" || rc=$?

  # (3) .class 成果物の有無。Processing は output 直下に <sketch>.class を生成する。
  local class_file="${output_dir%/}/${sketch_name}.class"
  local class_exists=0
  if [[ -f "$class_file" ]]; then
    class_exists=1
  fi

  # (2) stderr のエラー行抽出。
  local pde_errors=""
  if pde_errors="$(extract_pde_errors "$err_log")"; then
    : # エラー行あり
  else
    pde_errors=""
  fi

  # ---- 三点照合による判定 ----
  # 成功条件: exit 0 かつ エラー行なし かつ .class が生成された。
  if [[ "$rc" -eq 0 && -z "$pde_errors" && "$class_exists" -eq 1 ]]; then
    log "==> BUILD PASS: $sketch_name"
    log "    生成物: $class_file"
    # 参考: 成功時の stdout は通常 "Finished." を含む。
    if [[ -s "$out_log" ]]; then
      log "    --- stdout ---"
      cat "$out_log" >&2
    fi
    return 0
  fi

  # ---- ここから FAIL ----
  log "==> BUILD FAIL: $sketch_name"
  log "    exit code     : $rc"
  log "    .class 生成    : $([[ "$class_exists" -eq 1 ]] && echo yes || echo no)"

  if [[ -n "$pde_errors" ]]; then
    log "    --- コンパイルエラー (<file>.pde:行:列: メッセージ) ---"
    printf '%s\n' "$pde_errors" >&2
  fi

  # エラー行が拾えなかった場合に備えて stderr 全文も出す。
  if [[ -z "$pde_errors" && -s "$err_log" ]]; then
    log "    --- stderr 全文 ---"
    cat "$err_log" >&2
  fi

  return 1
}

# ============================================================================
# run サブコマンド
# ============================================================================
#
# timeout で包んで processing cli ... --run を実行する。
# --run はウィンドウを開くため、スケッチが exit() を呼ばないと終わらない。
# よって必ず timeout で包む（GNU timeout はタイムアウト時 exit 124）。
#
# 判定:
#   - stderr に *.pde:l:c: 形式のエラー行（コンパイルエラー or 実行時例外）→ FAIL
#   - timeout (124) → ウィンドウが exit() で閉じなかった可能性として警告。
#                     コンパイルは通った扱い（位置情報付きエラーが無ければ PASS 相当）。
#   - それ以外で exit 0 → PASS
#
cmd_run() {
  local sketch_dir="${1:-}"
  local timeout_sec="${2:-}"
  local output_dir_arg="${3:-}"

  if [[ -z "$sketch_dir" ]]; then
    usage
    exit 1
  fi

  # timeout 秒数の既定と簡易バリデーション。
  if [[ -z "$timeout_sec" ]]; then
    timeout_sec="$DEFAULT_TIMEOUT_SEC"
  fi
  if ! [[ "$timeout_sec" =~ ^[0-9]+$ ]]; then
    log "エラー: timeout_sec は正の整数で指定してください: $timeout_sec"
    exit 1
  fi

  require_binary

  local main_pde
  main_pde="$(validate_sketch_dir "$sketch_dir")"
  local sketch_name
  sketch_name="$(basename "${sketch_dir%/}")"

  local output_dir
  output_dir="$(resolve_output_dir "$sketch_dir" "$output_dir_arg")"
  /bin/rm -rf "$output_dir"
  mkdir -p "$output_dir"

  local out_log err_log
  out_log="$(mktemp -t verify-sketch-run-out.XXXXXX)"
  err_log="$(mktemp -t verify-sketch-run-err.XXXXXX)"
  trap 'rm -f "${out_log:-}" "${err_log:-}"' RETURN

  # timeout コマンドを解決。
  local timeout_cmd
  timeout_cmd="$(resolve_timeout_cmd)"

  log "==> run: $sketch_name"
  log "    sketch : $sketch_dir"
  log "    output : $output_dir"
  if [[ -n "$timeout_cmd" ]]; then
    log "    timeout: ${timeout_sec}s ($timeout_cmd)"
  else
    log "    timeout: なし（timeout/gtimeout が見つかりません。無限ループに注意）"
  fi

  # 実行。--run は必ず最後の引数。
  # 🔴 パイプ禁止。stdout/stderr はファイルへ退避。
  local rc=0
  if [[ -n "$timeout_cmd" ]]; then
    "$timeout_cmd" "${timeout_sec}" \
      "$PROCESSING_BIN" cli \
      --sketch="$sketch_dir" \
      --output="$output_dir" \
      --force \
      --run \
      >"$out_log" 2>"$err_log" || rc=$?
  else
    "$PROCESSING_BIN" cli \
      --sketch="$sketch_dir" \
      --output="$output_dir" \
      --force \
      --run \
      >"$out_log" 2>"$err_log" || rc=$?
  fi

  # スケッチの println() 出力（stdout）は常に表示する。
  if [[ -s "$out_log" ]]; then
    log "    --- stdout (スケッチ出力) ---"
    cat "$out_log" >&2
  fi

  # stderr のエラー行抽出（コンパイルエラー / 実行時例外の双方）。
  local pde_errors=""
  if pde_errors="$(extract_pde_errors "$err_log")"; then
    : # あり
  else
    pde_errors=""
  fi

  # ---- 判定 ----

  # 位置情報付きエラーがあれば、コンパイルエラーか実行時例外。常に FAIL。
  if [[ -n "$pde_errors" ]]; then
    log "==> RUN FAIL: $sketch_name"
    log "    exit code: $rc"
    log "    --- エラー (<file>.pde:行:列: メッセージ) ---"
    printf '%s\n' "$pde_errors" >&2
    log "    （コンパイルエラー、または実行時例外です）"
    return 1
  fi

  # timeout (124) は「ウィンドウが exit() で閉じなかった」可能性。
  # 位置情報付きエラーが無いので、少なくともコンパイルは通っている。
  if [[ "$rc" -eq 124 ]]; then
    log "==> RUN WARN: $sketch_name"
    log "    timeout (${timeout_sec}s) で打ち切りました（exit 124）。"
    log "    スケッチが exit() を呼ばずウィンドウが開いたままだった可能性があります。"
    log "    位置情報付きエラーは検出されなかったため、コンパイルは成功した扱いとします。"
    log "    （ヘッドレスでコンパイルのみ検証したい場合は build サブコマンドを使ってください）"
    return 0
  fi

  # 正常終了。スケッチ内で exit() が呼ばれれば Finished. が出て exit 0 になる。
  if [[ "$rc" -eq 0 ]]; then
    log "==> RUN PASS: $sketch_name"
    log "    正常終了しました（exit 0）。"
    return 0
  fi

  # それ以外の非ゼロ終了。位置情報付きエラーは無いが念のため stderr を出す。
  log "==> RUN FAIL: $sketch_name"
  log "    exit code: ${rc}（想定外の終了コード）"
  if [[ -s "$err_log" ]]; then
    log "    --- stderr 全文 ---"
    cat "$err_log" >&2
  fi
  return 1
}

# ============================================================================
# format サブコマンド
# ============================================================================
#
# processing sketch format <file> を実行する。既定は標準出力へ整形結果を書き出す
# （-i / --inplace を付けない限りファイルは上書きされない）。本ヘルパーは安全側に倒し、
# 常に標準出力へ出す。整形結果を保存したい場合は呼び出し側でリダイレクトする。
#
cmd_format() {
  local pde_file="${1:-}"

  if [[ -z "$pde_file" ]]; then
    usage
    exit 1
  fi

  require_binary

  if [[ ! -f "$pde_file" ]]; then
    log "エラー: .pde ファイルが存在しません: $pde_file"
    exit 1
  fi

  log "==> format: ${pde_file}（整形結果を標準出力へ。元ファイルは変更しません）"

  # format の整形結果は標準出力に出すため、ここではパイプ・退避をせず素通しする。
  "$PROCESSING_BIN" sketch format "$pde_file"
}

# ============================================================================
# エントリポイント
# ============================================================================

main() {
  local subcommand="${1:-}"

  if [[ -z "$subcommand" ]]; then
    usage
    exit 1
  fi
  shift

  case "$subcommand" in
    build)
      cmd_build "$@"
      ;;
    run)
      cmd_run "$@"
      ;;
    format)
      cmd_format "$@"
      ;;
    -h | --help | help)
      usage
      exit 0
      ;;
    *)
      log "エラー: 不正なサブコマンド: $subcommand"
      usage
      exit 1
      ;;
  esac
}

main "$@"
