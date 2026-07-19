#!/usr/bin/env bash
# Whizlabs のコース practice test 一覧ページを巡回し、配下の全クイズ（Free Test・Practice Test 1〜N 等）を
# practice mode で収集する。各クイズは問題文・選択肢・正解・解説・参考資料を取得し、
# <course-slug>__<quiz-slug>.json（最終成果物）へ保存、進捗を同名 .jsonl へ逐次追記する。
#
# 🔴 kentei-lab とは異なり URL 直接反復は使えない（URLは固定・SPA内部状態で問題送りされる）。
#    問題間ナビゲーションは番号 li の eval クリックで行う。選択肢クリックは不要
#    （show Answer ボタンで正解・解説が全開示される）。resume は同一ブラウザプロセス内でのみ
#    有効なため、本スクリプトはクイズ処理開始時に既存の進捗ファイルを破棄し、常に最初から
#    収集し直す設計にしている（詳細: INSTRUCTIONS.md §6）。
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: collect-whizlabs.sh <course-list-url> [output-dir]

  <course-list-url>  Whizlabs のコース practice test 一覧URL
                      （例: https://www.whizlabs.com/learn/course/<slug>/<course-id>/pt）
  [output-dir]        出力先ディレクトリ（省略時 ./whizlabs-output）。
                      クイズごとに <course-slug>__<quiz-slug>.json（最終成果物）と
                      <course-slug>__<quiz-slug>.jsonl（進捗）を出力する。

環境変数:
  WHIZLABS_USERNAME    ログイン用メールアドレス（state未保存時に必須）
  WHIZLABS_PASSWORD    ログイン用パスワード（state未保存時に必須。agent-browser fill の引数として渡す）
  WHIZLABS_STATE_FILE  agent-browser state ファイルパス（既定 <output-dir>/.whizlabs-state.json）
  WHIZLABS_WAIT_MS     問題間の待機ミリ秒（既定 300・サイトへのレート配慮）
  WHIZLABS_MAX_N       1クイズあたりの取得上限（スモークテスト/部分取得用・既定 0=全件）
  AGENT_BROWSER        agent-browser バイナリパス上書き（既定: which agent-browser）
USAGE
  exit 1
}

[ "$#" -ge 1 ] || usage

COURSE_URL="$1"
OUTPUT_DIR="${2:-./whizlabs-output}"

BASE_URL="https://www.whizlabs.com"
WHIZLABS_WAIT_MS="${WHIZLABS_WAIT_MS:-300}"
WHIZLABS_MAX_N="${WHIZLABS_MAX_N:-0}"
WHIZLABS_STATE_FILE="${WHIZLABS_STATE_FILE:-${OUTPUT_DIR}/.whizlabs-state.json}"
AGENT_BROWSER="${AGENT_BROWSER:-$(command -v agent-browser || true)}"

log() { printf '%s\n' "$*" >&2; }

if [ -z "${AGENT_BROWSER}" ]; then
  log "エラー: agent-browser が見つかりません。web:automating-browser スキルの scripts/install.sh を実行して導入してください。"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  log "エラー: jq が見つかりません。導入してから再実行してください。"
  exit 1
fi

# --- コース slug 抽出（/learn/course/<slug>/<course-id>/pt から） ---
COURSE_SLUG=""
if [[ "${COURSE_URL}" =~ /course/([A-Za-z0-9_-]+)/ ]]; then
  COURSE_SLUG="${BASH_REMATCH[1]}"
fi
if [ -z "${COURSE_SLUG}" ]; then
  log "エラー: URL からコース slug を抽出できません: ${COURSE_URL}"
  exit 1
fi

mkdir -p "${OUTPUT_DIR}"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/whizlabs.XXXXXX")"
cleanup() { rm -rf "${TMP_DIR}"; }
trap cleanup EXIT

WAIT_SEC="$(awk -v ms="${WHIZLABS_WAIT_MS}" 'BEGIN { printf "%.3f", ms / 1000 }')"

ab() { "${AGENT_BROWSER}" "$@"; }

# ファイル名安全化（英数字以外はハイフンへ・連続ハイフン圧縮・前後トリム・小文字化）
slugify() {
  local s
  s="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  s="$(printf '%s' "${s}" | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
  printf '%s' "${s}"
}

# --- JS 抽出ロジック（agent-browser eval --stdin へ渡す）---
# 🔴 agent-browser 0.31.1 は `eval --file` を持たない（--stdin / -b base64 のみ）。
#    kentei-lab版と同様、常に --stdin へヒアドキュメントで渡す。

# --- 認証用 JS（実機確認済み: Whizlabs のログインフォームはモーダル型。
#     専用ログインページ（/login）は存在せず、トップページ右上の「Sign In」ボタンを
#     クリックして初めてフォーム要素がDOMに現れる） ---

# ログイン判定: 実機確認済み。ログイン前はヘッダーに textContent 完全一致 "Sign In" の
# button が存在し、ログイン後はこの button が0件になる（"Hello, " 文言はハンバーガーメニュー
# 展開時のみ現れ通常表示のDOMには含まれないため判定に使えない・実機で確認済み）。
cat > "${TMP_DIR}/check-login.js" <<'JS'
(() => {
  const buttons = Array.from(document.querySelectorAll('button'));
  const hasSignIn = buttons.some((b) => (b.textContent || '').trim() === 'Sign In');
  return { loggedIn: !hasSignIn };
})()
JS

# トップページ（またはどのページからでも）ヘッダーの「Sign In」ボタンをクリックしてモーダルを開く。
cat > "${TMP_DIR}/click-sign-in-header.js" <<'JS'
(() => {
  const buttons = Array.from(document.querySelectorAll('button'));
  const btn = buttons.find((b) => (b.textContent || '').trim() === 'Sign In');
  if (!btn) return { error: 'sign-in-button-not-found' };
  btn.click();
  return { ok: true };
})()
JS

# モーダル内フォーム送信用の「Sign In」ボタン。ヘッダーのボタンとは別要素で、
# fill 後にモーダル内に複数の "Sign In" テキストが存在しうるため、
# input[type=password] の近傍（同じフォーム/コンテナ内）にあるボタンに絞って選ぶ。
cat > "${TMP_DIR}/click-sign-in-modal.js" <<'JS'
(() => {
  const pwInput = document.querySelector('input[type=password]');
  if (!pwInput) return { error: 'password-input-not-found' };
  const container = pwInput.closest('form') || pwInput.closest('div');
  if (!container) return { error: 'form-container-not-found' };
  const buttons = Array.from(container.querySelectorAll('button'));
  const btn = buttons.find((b) => (b.textContent || '').trim() === 'Sign In');
  if (!btn) return { error: 'modal-sign-in-button-not-found' };
  btn.click();
  return { ok: true };
})()
JS

cat > "${TMP_DIR}/get-course-title.js" <<'JS'
(() => {
  const h1 = document.querySelector('h1');
  return { title: h1 ? h1.textContent.trim() : null };
})()
JS

# 一覧ページ内の各クイズ行（`.box-item .name`）からタイトルのみを取得する。
# 🔴 実機確認済み: 一覧ページのクイズ行は <a href> を一切持たない（quiz-id は一覧ページの
#    DOMに埋め込まれておらず、React のイベントハンドラで .name をクリックした遷移後URLから
#    初めて取得できる）。したがって quiz-id はここでは取得せず、後段でインデックス順に
#    .name をクリック→遷移後URLから抽出する方式にフォールバックする。
cat > "${TMP_DIR}/get-quiz-titles.js" <<'JS'
(() => {
  const names = Array.from(document.querySelectorAll('.box-item .name'));
  if (names.length === 0) return { error: 'no-quiz-items-found' };
  const titles = names.map((el) => (el.textContent || '').trim());
  return { titles };
})()
JS

cat > "${TMP_DIR}/click-start-quiz.js" <<'JS'
(() => {
  const buttons = Array.from(document.querySelectorAll('button, a'));
  const btn = buttons.find((b) => /start quiz|^\s*(start|free)\s*$/i.test((b.textContent || '').trim()));
  if (!btn) return { error: 'start-quiz-button-not-found' };
  btn.click();
  return { ok: true };
})()
JS

# モーダル内「Start quiz as practice mode」選択。ラジオ/チェックボックスがあればそれを、
# 無ければテキストを含む要素自体をクリックする。
cat > "${TMP_DIR}/select-practice-mode.js" <<'JS'
(() => {
  const candidates = Array.from(document.querySelectorAll('label, div, span, li'));
  const target = candidates.find(
    (el) => /practice mode/i.test((el.textContent || '').trim()) && (el.textContent || '').trim().length < 200
  );
  if (!target) return { error: 'practice-mode-option-not-found' };
  const input = target.querySelector('input[type=radio], input[type=checkbox]')
    || (target.closest('label') ? target.closest('label').querySelector('input') : null);
  if (input) {
    input.click();
  } else {
    target.click();
  }
  return { ok: true };
})()
JS

cat > "${TMP_DIR}/click-start.js" <<'JS'
(() => {
  const buttons = Array.from(document.querySelectorAll('button'));
  const btn = buttons.find((b) => /^\s*start\s*$/i.test((b.textContent || '').trim()));
  if (!btn) return { error: 'start-button-not-found' };
  btn.click();
  return { ok: true };
})()
JS

cat > "${TMP_DIR}/get-total.js" <<'JS'
(() => {
  const el = document.querySelector('.total-questions');
  if (!el) return { error: 'total-questions-not-found' };
  const m = el.textContent.match(/Question\s+\d+\s+of\s+(\d+)/i);
  if (!m) return { error: 'total-pattern-not-matched', text: el.textContent };
  return { total: parseInt(m[1], 10) };
})()
JS

# 問題文・ドメイン・選択肢（レター＋テキスト＋input type）を読み取る。
# 選択肢は全てクリックせず読み取るだけ（Whizlabsは show Answer ボタンで開示するため不要）。
cat > "${TMP_DIR}/read-question.js" <<'JS'
(() => {
  const domainEl = document.querySelector('.que-category');
  const domain = domainEl ? domainEl.textContent.replace(/^\s*Domain:\s*/i, '').trim() : '';
  const qP = document.querySelector('.content > div > p');
  const question = qP ? qP.textContent.trim() : '';
  const choiceEls = Array.from(document.querySelectorAll('.content fieldset.Questions-list .radio-ans'));
  const choices = [];
  let choiceType = 'single';
  for (const el of choiceEls) {
    const input = el.querySelector('input[type=radio], input[type=checkbox]');
    if (input && input.type === 'checkbox') choiceType = 'multiple';
    // 🔴 実機確認済み: span は "A. <div class=dangerouslySetInnerHTML><p>本文</p></div>" という
    //    構造で子要素(div)のテキストも含む。span.textContent をそのまま使うと本文が二重連結
    //    される（"A. Management Plane Management Plane"）ため、span 直下のテキストノードのみ
    //    を取得する。
    const span = el.querySelector('span');
    let letter = '';
    if (span) {
      const textNode = Array.from(span.childNodes).find((n) => n.nodeType === Node.TEXT_NODE);
      letter = textNode ? textNode.textContent.trim() : '';
    }
    const textEl = el.querySelector('.dangerouslySetInnerHTML > p') || el.querySelector('p');
    const text = textEl ? textEl.textContent.trim() : '';
    const combined = (letter + ' ' + text).trim();
    if (combined) choices.push(combined);
  }
  if (!question || choices.length === 0) {
    return { error: 'question-or-choices-empty', question, choicesLength: choices.length };
  }
  return { domain, question, choices, choice_type: choiceType };
})()
JS

cat > "${TMP_DIR}/click-show-answer.js" <<'JS'
(() => {
  const btn = document.querySelector('.content button.btn-showAnswer');
  if (!btn) return { error: 'show-answer-button-not-found' };
  btn.click();
  return { ok: true };
})()
JS

# 解答ブロック（生HTML）を読み取り、"Correct Answer: X" の行を除去したHTMLと
# 正解レター配列を返す。MCMR（複数選択）は実例未確認のため、
# "A, C" / "A and C" 等の区切りを広めに許容して分割する（実装時に要調整の可能性あり）。
cat > "${TMP_DIR}/read-explanation.js" <<'JS'
(() => {
  const block = document.querySelector('.content .explanation-block');
  if (!block) return { error: 'explanation-block-not-found' };
  const clone = block.cloneNode(true);
  const ps = Array.from(clone.querySelectorAll('p'));
  const correctP = ps.find((p) => /correct answer\s*:/i.test(p.textContent || ''));
  let correctText = '';
  if (correctP) {
    correctText = (correctP.textContent || '').replace(/^.*correct answer\s*:\s*/i, '').trim();
    correctP.remove();
  }
  const html = clone.innerHTML.trim();
  let correct = [];
  if (correctText) {
    correct = correctText
      .split(/\s*,\s*|\s+and\s+|\s*\/\s*/i)
      .map((s) => s.trim())
      .filter(Boolean)
      .map((s) => {
        const m = s.match(/^([A-Za-z])/);
        return m ? m[1].toUpperCase() : s;
      })
      .filter((s) => /^[A-Z]$/.test(s));
  }
  return { html, correct };
})()
JS

# Exit Quiz は3段階フロー: ①Exit Quizリンク → ②カスタムモーダル（Submit/Resume Later/
# 離脱確認ボタンの3ボタン）→ ③ネイティブ window.confirm()。ここは①のみを担当する。
cat > "${TMP_DIR}/click-exit-quiz.js" <<'JS'
(() => {
  const buttons = Array.from(document.querySelectorAll('button, a'));
  const btn = buttons.find((b) => /exit quiz/i.test((b.textContent || '').trim()));
  if (!btn) return { error: 'exit-quiz-button-not-found' };
  btn.click();
  return { ok: true };
})()
JS

# カスタムモーダル内の離脱確認ボタン（②）。🔴 実機確認済み: 長い確認文
# （"You'll lose your progress, are you sure you want to leave?"）は button の aria-label
# 属性の値であり、textContent は "Quit"（class に btn-quit を持つ）。当初の調査で
# agent-browser snapshot（accessibility tree表示のため aria-label を優先表示）を見て
# textContent と誤認していたため、textContent 完全一致 "Quit" で判定する。
cat > "${TMP_DIR}/click-leave-confirm.js" <<'JS'
(() => {
  const buttons = Array.from(document.querySelectorAll('button'));
  const btn = buttons.find((b) => (b.textContent || '').trim() === 'Quit');
  if (!btn) return { error: 'leave-confirm-button-not-found' };
  btn.click();
  return { ok: true };
})()
JS

# --- 最終 JSON 組み立て（.jsonl 全行から再構築する派生物） ---
build_final_json() {
  local quiz_title="$1" quiz_id="$2" jsonl_file="$3" json_file="$4" total="$5"
  [ -f "${jsonl_file}" ] || return 0
  local collected_at
  collected_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  jq -n \
    --arg course_title "${COURSE_TITLE}" \
    --arg course_url "${COURSE_URL}" \
    --arg quiz_title "${quiz_title}" \
    --arg quiz_id "${quiz_id}" \
    --arg collected_at "${collected_at}" \
    --argjson total_questions "${total}" \
    --slurpfile questions "${jsonl_file}" \
    '{
       course_title: $course_title,
       course_url: $course_url,
       quiz_title: $quiz_title,
       quiz_id: $quiz_id,
       collected_at: $collected_at,
       total_questions: $total_questions,
       questions: ($questions | sort_by(.number))
     }' > "${json_file}"
}

# --- 1クイズの収集（失敗時は return 1 でスキップし、呼び出し側で継続する） ---
# 🔴 呼び出し時点で既にクイズ詳細ページへ遷移済みであること（メインループが一覧ページの
#    .name をインデックスクリックして遷移させ、遷移後URLから quiz_id を取得してから呼ぶ）。
#    この関数自体はページ遷移を行わない。
process_quiz() {
  local quiz_id="$1" quiz_title="$2"
  local quiz_slug basename jsonl_file json_file
  local r total end_n n
  local domain question choices_json choice_type explanation_html correct_json

  quiz_slug="$(slugify "${quiz_title}")"
  [ -n "${quiz_slug}" ] || quiz_slug="${quiz_id}"

  basename="${COURSE_SLUG}__${quiz_slug}"
  jsonl_file="${OUTPUT_DIR}/${basename}.jsonl"
  json_file="${OUTPUT_DIR}/${basename}.json"

  log "[info] クイズ処理開始: ${quiz_title} (quiz_id=${quiz_id})"

  # 🔴 resume は同一ブラウザプロセス内でのみ有効なため、再実行時は既存進捗を破棄し
  #    常にこのクイズを最初から収集し直す（INSTRUCTIONS.md §6）。
  rm -f "${jsonl_file}"

  r="$(ab eval --stdin < "${TMP_DIR}/click-start-quiz.js")" || return 1
  if ! printf '%s' "${r}" | jq -e '.ok' >/dev/null 2>&1; then
    log "[warn] ${quiz_title}: Start Quiz ボタンが見つかりませんでした: ${r}"
    return 1
  fi
  ab wait --load networkidle >&2 || true

  r="$(ab eval --stdin < "${TMP_DIR}/select-practice-mode.js")" || return 1
  if ! printf '%s' "${r}" | jq -e '.ok' >/dev/null 2>&1; then
    log "[warn] ${quiz_title}: practice mode の選択に失敗しました: ${r}"
    return 1
  fi

  r="$(ab eval --stdin < "${TMP_DIR}/click-start.js")" || return 1
  if ! printf '%s' "${r}" | jq -e '.ok' >/dev/null 2>&1; then
    log "[warn] ${quiz_title}: Start ボタンが見つかりませんでした: ${r}"
    return 1
  fi
  ab wait --load networkidle >&2 || true

  r="$(ab eval --stdin < "${TMP_DIR}/get-total.js")" || return 1
  total="$(printf '%s' "${r}" | jq -er '.total')" || {
    log "[warn] ${quiz_title}: 総問題数を取得できませんでした: ${r}"
    return 1
  }
  log "[info] ${quiz_title}: 総問題数 = ${total}"

  end_n="${total}"
  if [ "${WHIZLABS_MAX_N}" -gt 0 ] 2>/dev/null && [ "${WHIZLABS_MAX_N}" -lt "${total}" ]; then
    end_n="${WHIZLABS_MAX_N}"
  fi

  n=1
  while [ "${n}" -le "${end_n}" ]; do
    if [ "${n}" -gt 1 ]; then
      cat > "${TMP_DIR}/jump-to.js" <<JS
(() => {
  const target = "${n}";
  const items = Array.from(document.querySelectorAll('li'));
  const li = items.find((el) => el.textContent.trim() === target);
  if (!li) return { error: 'question-number-not-found', target };
  li.click();
  return { ok: true };
})()
JS
      r="$(ab eval --stdin < "${TMP_DIR}/jump-to.js")" || return 1
      if ! printf '%s' "${r}" | jq -e '.ok' >/dev/null 2>&1; then
        log "[warn] ${quiz_title}: 第${n}問へのジャンプに失敗しました（番号liが画面に無い可能性。Nextリンクへのフォールバックを検討）: ${r}"
        return 1
      fi
      ab wait --load networkidle >&2 || true
    fi

    r="$(ab eval --stdin < "${TMP_DIR}/read-question.js")" || return 1
    if ! printf '%s' "${r}" | jq -e '.question and (.choices | length > 0)' >/dev/null 2>&1; then
      log "エラー: ${quiz_title} 第${n}問の問題文/選択肢を取得できませんでした: ${r}"
      return 1
    fi
    domain="$(printf '%s' "${r}" | jq -r '.domain')"
    question="$(printf '%s' "${r}" | jq -r '.question')"
    choices_json="$(printf '%s' "${r}" | jq -c '.choices')"
    choice_type="$(printf '%s' "${r}" | jq -r '.choice_type')"

    r="$(ab eval --stdin < "${TMP_DIR}/click-show-answer.js")" || return 1
    if ! printf '%s' "${r}" | jq -e '.ok' >/dev/null 2>&1; then
      log "エラー: ${quiz_title} 第${n}問の show Answer ボタンをクリックできませんでした: ${r}"
      return 1
    fi
    ab wait --text "Correct Answer" >&2 || true

    r="$(ab eval --stdin < "${TMP_DIR}/read-explanation.js")" || return 1
    if ! printf '%s' "${r}" | jq -e '.html != null' >/dev/null 2>&1; then
      log "エラー: ${quiz_title} 第${n}問の正解/解説を取得できませんでした: ${r}"
      return 1
    fi
    explanation_html="$(printf '%s' "${r}" | jq -r '.html')"
    correct_json="$(printf '%s' "${r}" | jq -c '.correct')"

    jq -nc \
      --argjson number "${n}" \
      --arg domain "${domain}" \
      --arg question "${question}" \
      --argjson choices "${choices_json}" \
      --arg choice_type "${choice_type}" \
      --argjson correct "${correct_json}" \
      --arg explanation_html "${explanation_html}" \
      '{number: $number, domain: $domain, question: $question, choices: $choices,
        choice_type: $choice_type, correct: $correct, explanation_html: $explanation_html}' \
      >> "${jsonl_file}"

    log "[${n}/${end_n}] ${quiz_title} 第${n}問 saved"

    n=$((n + 1))
    if [ "${n}" -le "${end_n}" ]; then
      sleep "${WAIT_SEC}"
    fi
  done

  # --- Exit Quiz（3段階: ①Exit Quizリンク → ②カスタムモーダルの離脱確認ボタン →
  #     ③ネイティブ window.confirm()。本番受験扱いを避けるため Submit・Resume Later は
  #     絶対に押さない）。
  r="$(ab eval --stdin < "${TMP_DIR}/click-exit-quiz.js")" || true
  if ! printf '%s' "${r}" | jq -e '.ok' >/dev/null 2>&1; then
    log "[warn] ${quiz_title}: Exit Quiz リンクが見つかりませんでした（手動確認を推奨）: ${r}"
  else
    # カスタムモーダルの表示待ち。🔴 実機確認済み: "lose your progress" は button の
    #    textContent ではなく aria-label のため --text 待機はマッチせず毎回タイムアウトして
    #    いた。textContent が "Quit" の button（class btn-quit）のセレクタ出現待ちに変更する。
    ab wait ".btn-quit" >&2 || true
    # 🔴 実機確認済み: click-leave-confirm.js の click() は同期的に window.confirm() を発火
    #    させるため、その eval コマンド自体が「confirm dialog にブロックされている」エラーで
    #    返ってくる（"A JavaScript confirm dialog is blocking the page"）。これは eval の
    #    応答が返せなかっただけでボタンクリック自体は成功しているため、eval の成否（.ok の
    #    有無）で分岐して dialog accept を呼ぶかどうかを決めてはならない（旧実装は eval が
    #    エラー扱いになるケースで accept を一度も呼ばずダイアログが残留し、以降の全 ab
    #    open/eval がブロックされ続けて後続クイズが総崩れになった）。eval の成否に関わらず
    #    必ず dialog accept を呼ぶ（離脱確認ボタン自体が本当に見つからなかった場合は
    #    accept も "No dialog is showing" で失敗するだけで、どちらも || true で許容し
    #    後続処理を止めない）。
    ab eval --stdin < "${TMP_DIR}/click-leave-confirm.js" >/dev/null 2>&1 || true
    ab dialog accept >&2 || true
  fi
  ab wait --load networkidle >&2 || true

  build_final_json "${quiz_title}" "${quiz_id}" "${jsonl_file}" "${json_file}" "${total}"
  log "[done] ${quiz_title}: ${json_file} を生成しました（進捗: ${jsonl_file}）。"
  return 0
}

# --- 認証（agent-browser state save/load によるセッション永続化） ---
# 🔴 Whizlabs に専用ログインページ（/login）は存在せず（404）、ログインフォームは
#    トップページ右上の「Sign In」ボタンをクリックして開くモーダル型。agent-browser の
#    auth save/auth login（Auth Vault）はページを開けばフォームが見えていることを前提に
#    フィールドを自動検出する仕様のためモーダルを開けず使用できない。
#    代わりに state save/load でブラウザセッションそのものを保存・復元する
#    （詳細: INSTRUCTIONS.md §3）。

is_logged_in() {
  local r
  r="$(ab eval --stdin < "${TMP_DIR}/check-login.js")" || return 1
  printf '%s' "${r}" | jq -e '.loggedIn' >/dev/null 2>&1
}

perform_login() {
  local r
  log "[info] Whizlabs へログイン中..."
  : "${WHIZLABS_USERNAME:?エラー: WHIZLABS_USERNAME が未設定です（state 未保存時は必須）}"
  : "${WHIZLABS_PASSWORD:?エラー: WHIZLABS_PASSWORD が未設定です（state 未保存時は必須）}"

  ab open "${BASE_URL}/" >&2
  ab wait --load networkidle >&2

  r="$(ab eval --stdin < "${TMP_DIR}/click-sign-in-header.js")"
  if ! printf '%s' "${r}" | jq -e '.ok' >/dev/null 2>&1; then
    log "エラー: Sign In ボタン（ヘッダー）が見つかりませんでした: ${r}"
    exit 1
  fi

  ab wait "input[type=email]" >&2
  ab fill "input[type=email]" "${WHIZLABS_USERNAME}" >&2
  # 🔴 agent-browser fill はパスワードを標準入力ではなくコマンド引数として渡す仕様のため、
  #    ログ・シェルトレースへ出力しないこと（本スクリプトは set -x を使わない）。
  ab fill "input[type=password]" "${WHIZLABS_PASSWORD}" >&2

  r="$(ab eval --stdin < "${TMP_DIR}/click-sign-in-modal.js")"
  if ! printf '%s' "${r}" | jq -e '.ok' >/dev/null 2>&1; then
    log "エラー: モーダル内 Sign In ボタンが見つかりませんでした: ${r}"
    exit 1
  fi
  ab wait --load networkidle >&2

  if ! is_logged_in; then
    log "エラー: ログインに失敗した可能性があります（Sign In ボタンがまだ存在します）"
    exit 1
  fi

  mkdir -p "$(dirname "${WHIZLABS_STATE_FILE}")"
  ab state save "${WHIZLABS_STATE_FILE}" >&2
  log "[info] ログインに成功し state を保存しました: ${WHIZLABS_STATE_FILE}"
}

log "[info] Whizlabs 認証状態を確認中..."
if [ -f "${WHIZLABS_STATE_FILE}" ]; then
  log "[info] 既存の state ファイルを読み込み中: ${WHIZLABS_STATE_FILE}"
  ab --state "${WHIZLABS_STATE_FILE}" open "${COURSE_URL}" >&2
  ab wait --load networkidle >&2
  if is_logged_in; then
    log "[info] state からログイン状態を復元しました。"
  else
    log "[info] state の有効期限が切れているため再ログインします。"
    perform_login
  fi
else
  log "[info] state ファイルが見つからないため新規ログインします。"
  perform_login
fi
# 🔴 ログイン確立後は同一ブラウザプロセス内でログイン状態が保持されるため、
#    以降のコース一覧オープン・クイズ処理では --state / 再ログインとも不要。

# --- コース一覧の解析（タイトルのみ取得。quiz-id は一覧DOMに埋め込まれていないため、
#     後段でインデックス順に .name をクリック→遷移後URLから取得する） ---
log "[info] コース一覧を取得中: ${COURSE_URL}"
ab open "${COURSE_URL}" >&2
ab wait --load networkidle >&2

TITLE_JSON="$(ab eval --stdin < "${TMP_DIR}/get-course-title.js")"
COURSE_TITLE="$(printf '%s' "${TITLE_JSON}" | jq -r '.title // empty')"
[ -n "${COURSE_TITLE}" ] || COURSE_TITLE="${COURSE_SLUG}"

QUIZ_TITLES_JSON="$(ab eval --stdin < "${TMP_DIR}/get-quiz-titles.js")"
if ! printf '%s' "${QUIZ_TITLES_JSON}" | jq -e '.titles and (.titles | length > 0)' >/dev/null 2>&1; then
  log "エラー: コース一覧からクイズを検出できませんでした: ${QUIZ_TITLES_JSON}"
  log "サイトのDOM構造が変わった可能性があります。get-quiz-titles.js のセレクタを調整してください。"
  exit 1
fi

QUIZ_COUNT="$(printf '%s' "${QUIZ_TITLES_JSON}" | jq '.titles | length')"
log "[info] ${COURSE_TITLE}: ${QUIZ_COUNT} 件のクイズを検出しました。"

# --- クイズごとに収集 ---
# 🔴 quiz-id は一覧ページの DOM に埋め込まれていないため、毎回コース一覧を開き直し
#    → インデックス i の .box-item .name をクリック → 遷移後の URL から
#    /quiz/<id>/ を正規表現抽出、という手順で取得する（インデックス順クリック方式）。
# 1件の失敗で全体を止めず、スキップして継続する。
QUIZ_OK=0
QUIZ_FAIL=0
QUIZ_INDEX=0
while [ "${QUIZ_INDEX}" -lt "${QUIZ_COUNT}" ]; do
  Q_TITLE="$(printf '%s' "${QUIZ_TITLES_JSON}" | jq -r --argjson i "${QUIZ_INDEX}" '.titles[$i]')"

  # 前のクイズ処理で別ページへ遷移しているため、毎回コース一覧を開き直す。
  ab open "${COURSE_URL}" >&2 || true
  ab wait --load networkidle >&2 || true

  cat > "${TMP_DIR}/click-quiz-index.js" <<JS
(() => {
  const names = Array.from(document.querySelectorAll('.box-item .name'));
  const el = names[${QUIZ_INDEX}];
  if (!el) return { error: 'quiz-index-not-found', idx: ${QUIZ_INDEX} };
  el.click();
  return { ok: true };
})()
JS
  R_CLICK="$(ab eval --stdin < "${TMP_DIR}/click-quiz-index.js")" || true
  if ! printf '%s' "${R_CLICK}" | jq -e '.ok' >/dev/null 2>&1; then
    log "[warn] クイズ一覧の${QUIZ_INDEX}番目（${Q_TITLE}）をクリックできませんでした: ${R_CLICK}"
    QUIZ_FAIL=$((QUIZ_FAIL + 1))
    QUIZ_INDEX=$((QUIZ_INDEX + 1))
    continue
  fi
  ab wait --load networkidle >&2 || true

  CURRENT_URL="$(ab get url)" || true
  Q_ID=""
  if [[ "${CURRENT_URL}" =~ /quiz/([A-Za-z0-9_-]+) ]]; then
    Q_ID="${BASH_REMATCH[1]}"
  fi
  if [ -z "${Q_ID}" ]; then
    log "[warn] ${Q_TITLE}: 遷移後URLから quiz-id を抽出できませんでした（url=${CURRENT_URL}）"
    QUIZ_FAIL=$((QUIZ_FAIL + 1))
    QUIZ_INDEX=$((QUIZ_INDEX + 1))
    continue
  fi

  if process_quiz "${Q_ID}" "${Q_TITLE}"; then
    QUIZ_OK=$((QUIZ_OK + 1))
  else
    QUIZ_FAIL=$((QUIZ_FAIL + 1))
    log "[warn] クイズをスキップしました: ${Q_TITLE} (quiz_id=${Q_ID})"
  fi

  QUIZ_INDEX=$((QUIZ_INDEX + 1))
done

ab close >&2 || true
log "[done] ${COURSE_TITLE}: 全 ${QUIZ_COUNT} 件中 ${QUIZ_OK} 件成功・${QUIZ_FAIL} 件失敗。出力先: ${OUTPUT_DIR}"
