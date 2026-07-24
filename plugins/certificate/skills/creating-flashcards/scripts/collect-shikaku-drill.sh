#!/usr/bin/env bash
# shikaku-drill.com の資格試験ページ（SPA・単一URL）をボタン操作で巡回し、
# 問題文・カテゴリ・選択肢・正解・解説を JSON（<slug>.json）へ保存し、進捗を <slug>.jsonl に逐次追記する。
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: collect-shikaku-drill.sh <input-url-or-slug> [output-dir]

  <input-url-or-slug>  shikaku-drill.com の URL（https://shikaku-drill.com/<slug>.html）
                        または slug 単体（必須）
  [output-dir]          出力先ディレクトリ（省略時 ./shikaku-drill-output）。
                         <slug>.json（最終成果物）と <slug>.jsonl（進捗）を出力する。

環境変数:
  SHIKAKU_DRILL_WAIT_MS   問題間の待機ミリ秒（既定 300・サイトへのレート配慮）
  SHIKAKU_DRILL_MAX_N     取得上限（スモークテスト/部分取得用・既定 0=全件）
  AGENT_BROWSER           agent-browser バイナリパス上書き（既定: which agent-browser）
USAGE
  exit 1
}

[ "$#" -ge 1 ] || usage

INPUT_URL="$1"
OUTPUT_DIR="${2:-./shikaku-drill-output}"

BASE_URL="https://shikaku-drill.com"
SHIKAKU_DRILL_WAIT_MS="${SHIKAKU_DRILL_WAIT_MS:-300}"
SHIKAKU_DRILL_MAX_N="${SHIKAKU_DRILL_MAX_N:-0}"
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

# --- slug 抽出（https://shikaku-drill.com/<slug>.html 形式、または slug 単体）---
SLUG=""
if [[ "${INPUT_URL}" =~ /([A-Za-z0-9_-]+)\.html([?#].*)?$ ]]; then
  SLUG="${BASH_REMATCH[1]}"
elif [[ "${INPUT_URL}" =~ ^[A-Za-z0-9_-]+$ ]]; then
  SLUG="${INPUT_URL}"
fi
if [ -z "${SLUG}" ]; then
  log "エラー: URL から slug を抽出できません: ${INPUT_URL}"
  exit 1
fi

mkdir -p "${OUTPUT_DIR}"
JSONL_FILE="${OUTPUT_DIR}/${SLUG}.jsonl"   # 進捗（resumeの防御用・1問1行）
JSON_FILE="${OUTPUT_DIR}/${SLUG}.json"     # 最終成果物

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/shikaku-drill.XXXXXX")"
cleanup() { rm -rf "${TMP_DIR}"; }
trap cleanup EXIT

WAIT_SEC="$(awk -v ms="${SHIKAKU_DRILL_WAIT_MS}" 'BEGIN { printf "%.3f", ms / 1000 }')"

ab() { "${AGENT_BROWSER}" "$@"; }

# --- ボタンテキスト部分一致クリック（$1..$N を順に試し、最初にヒットしたものをクリック） ---
click_first_matching() {
  local text result
  for text in "$@"; do
    local text_json
    text_json="$(printf '%s' "${text}" | jq -Rs '.')"
    cat > "${TMP_DIR}/click-btn.js" <<JS
(() => {
  const target = Array.from(document.querySelectorAll('button'))
    .find((b) => b.textContent.includes(${text_json}));
  if (!target) return { clicked: false };
  target.click();
  return { clicked: true };
})()
JS
    result="$(ab eval --stdin < "${TMP_DIR}/click-btn.js")"
    if printf '%s' "${result}" | jq -e '.clicked' >/dev/null 2>&1; then
      log "[info] ${SLUG}: クリック実行「${text}」"
      return 0
    fi
  done
  return 1
}

# --- DOM要素の出現をポーリングで待つ（agent-browser の CSS セレクタ待機に依存しない） ---
poll_for_selector() {
  local selector="$1"
  local max_attempts="${2:-20}"
  local i=0
  local selector_json
  selector_json="$(printf '%s' "${selector}" | jq -Rs '.')"
  cat > "${TMP_DIR}/poll.js" <<JS
(() => ({ found: !!document.querySelector(${selector_json}) }))()
JS
  while [ "${i}" -lt "${max_attempts}" ]; do
    local result
    result="$(ab eval --stdin < "${TMP_DIR}/poll.js")"
    if printf '%s' "${result}" | jq -e '.found' >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.3
    i=$((i + 1))
  done
  return 1
}

# --- JS 抽出ロジック ---
cat > "${TMP_DIR}/get-n.js" <<'JS'
(() => {
  const buttons = Array.from(document.querySelectorAll('button'));
  for (const b of buttons) {
    const m = b.textContent.match(/全問\s*(\d+)問/);
    if (m) return { n: parseInt(m[1], 10) };
  }
  return { error: 'n-not-found' };
})()
JS

cat > "${TMP_DIR}/get-title.js" <<'JS'
(() => {
  // 実機確認済み: shikaku-drill.com のページには <h1> が存在せず、試験名は
  // document.title に "<試験名> | 資格ドリル" の形式で入る（サイト名サフィックスを除去）。
  const raw = (document.title || '').trim();
  const title = raw.replace(/\s*\|\s*資格ドリル\s*$/, '').trim();
  return { title: title || null };
})()
JS

cat > "${TMP_DIR}/get-nav.js" <<'JS'
(() => {
  const el = document.querySelector('.quiz-nav');
  if (!el) return { error: 'nav-not-found' };
  return { nav: el.textContent.trim() };
})()
JS

# 問題文・カテゴリ・選択肢を読み取り、最初の選択肢ボタンをクリックして解説を開示させる。
# 開示前の状態を読んでから click() する（読み取りとクリックを1回のevalで完結させ、
# 再レンダ前後を跨がないようにする。kentei-labのread-before-click.jsと同じ設計）。
cat > "${TMP_DIR}/read-and-click.js" <<'JS'
(() => {
  const card = document.querySelector('.q-card');
  if (!card) return { error: 'q-card-not-found' };
  const navEl = document.querySelector('.quiz-nav');
  const nav = navEl ? navEl.textContent.trim() : '';
  const catEl = card.querySelector('.q-cat-badge');
  let category = catEl ? catEl.textContent.trim() : '';
  category = category.replace(/^\S+\s*/, '');
  const textEl = card.querySelector('.q-text');
  const question = textEl ? textEl.textContent.trim() : '';
  const choiceButtons = Array.from(document.querySelectorAll('.choices .choice'));
  if (choiceButtons.length === 0) return { error: 'no-choices' };
  const choices = choiceButtons.map((btn) => {
    const alpha = btn.querySelector('.ch-alpha');
    const body = btn.querySelector('.ch-body');
    const alphaText = alpha ? alpha.textContent.trim() : '';
    const bodyText = body ? body.textContent.trim() : btn.textContent.trim();
    return alphaText ? `${alphaText}. ${bodyText}` : bodyText;
  });
  choiceButtons[0].click();
  return { nav, category, question, choices };
})()
JS

cat > "${TMP_DIR}/click-first-choice.js" <<'JS'
(() => {
  const buttons = Array.from(document.querySelectorAll('.choices .choice'));
  if (buttons.length === 0) return { error: 'no-choices' };
  buttons[0].click();
  return { clicked: true };
})()
JS

cat > "${TMP_DIR}/read-after-click.js" <<'JS'
(() => {
  const exp = document.querySelector('.exp-card');
  if (!exp) return { error: 'exp-card-not-found' };
  const correctEl = exp.querySelector('.exp-correct-bar.ok .exp-correct-text');
  const answer = correctEl ? correctEl.textContent.trim() : '';
  const bodyEl = exp.querySelector('.exp-body');
  const explanation = bodyEl ? bodyEl.textContent.trim() : '';
  if (!answer) return { error: 'answer-not-found' };
  return { answer, explanation };
})()
JS

cat > "${TMP_DIR}/next-question.js" <<'JS'
(() => {
  const target = Array.from(document.querySelectorAll('button'))
    .find((b) => b.textContent.includes('次の問題'));
  if (!target) return { clicked: false };
  target.click();
  return { clicked: true };
})()
JS

# --- ページを開き、絞り込み・タイマー・シャッフルを既定状態に統一 ---
log "[info] ${SLUG}: ページを開いています..."
ab open "${BASE_URL}/${SLUG}.html" >&2
ab wait --load networkidle >&2

click_first_matching "全て" || log "[warn] ${SLUG}: 「全て」ボタンが見つかりませんでした（既に絞り込み解除済みの可能性）"
click_first_matching "なし" || log "[warn] ${SLUG}: 「なし」ボタン（タイマー設定）が見つかりませんでした"
click_first_matching "🔀 順番通り" || log "[warn] ${SLUG}: 「🔀 順番通り」ボタンが見つかりませんでした"

# --- 総問題数(N)取得 ---
N_JSON="$(ab eval --stdin < "${TMP_DIR}/get-n.js")"
N="$(printf '%s' "${N_JSON}" | jq -er '.n')" || {
  log "エラー: 総問題数(N)を取得できませんでした。サイトのボタン文言が変わっている可能性があります。"
  exit 1
}
log "[info] ${SLUG}: 総問題数 = ${N}"

# --- 試験名取得 ---
TITLE_JSON="$(ab eval --stdin < "${TMP_DIR}/get-title.js")"
EXAM_TITLE="$(printf '%s' "${TITLE_JSON}" | jq -er '.title // empty')" || EXAM_TITLE="${SLUG}"
[ -n "${EXAM_TITLE}" ] || EXAM_TITLE="${SLUG}"

# --- 取得上限の決定 ---
END_N="${N}"
if [ "${SHIKAKU_DRILL_MAX_N}" -gt 0 ] 2>/dev/null && [ "${SHIKAKU_DRILL_MAX_N}" -lt "${N}" ]; then
  END_N="${SHIKAKU_DRILL_MAX_N}"
fi

# --- 最終 JSON 組み立て（.jsonl 全行から再構築する派生物） ---
build_final_json() {
  [ -f "${JSONL_FILE}" ] || return 0
  local collected_at
  collected_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  jq -n \
    --arg exam_title "${EXAM_TITLE}" \
    --arg slug "${SLUG}" \
    --arg source_url "${BASE_URL}/${SLUG}.html" \
    --arg collected_at "${collected_at}" \
    --argjson total_questions "${N}" \
    --slurpfile questions "${JSONL_FILE}" \
    '{
       exam_title: $exam_title,
       slug: $slug,
       source_url: $source_url,
       collected_at: $collected_at,
       total_questions: $total_questions,
       questions: ($questions | sort_by(.number))
     }' > "${JSON_FILE}"
}

# --- 問題番号 n が既に jsonl に記録済みか判定（サイト側resumeとjsonlのズレに対する防御） ---
is_collected() {
  local n="$1"
  [ -f "${JSONL_FILE}" ] && [ -s "${JSONL_FILE}" ] || return 1
  jq -s --argjson n "${n}" 'any(.[]; .number == $n)' "${JSONL_FILE}" | grep -q '^true$'
}

# --- 開始/続きボタンのクリック ---
if click_first_matching "続きから学習"; then
  log "[info] ${SLUG}: 続きから学習ボタンで再開します。"
elif click_first_matching "学習スタート" "修行開始"; then
  log "[info] ${SLUG}: 学習スタート/修行開始ボタンで新規開始します。"
else
  log "エラー: 開始/続きボタンが見つかりませんでした。サイトのボタン文言が変わっている可能性があります。"
  exit 1
fi

poll_for_selector ".quiz-nav" 30 || {
  log "エラー: 問題ページの読み込みを検出できませんでした（.quiz-nav が出現しません）。"
  exit 1
}

if [ "${END_N}" -lt 1 ]; then
  log "[info] ${SLUG}: 取得対象がありません（END_N=${END_N}）。"
  build_final_json
  exit 0
fi

log "[info] ${SLUG}: 第${END_N}問まで収集します（既収集分はスキップ）。"

# --- メインループ（サイト側の「続きから学習」機構が示す現在位置に追従する） ---
while true; do
  NAV_JSON="$(ab eval --stdin < "${TMP_DIR}/get-nav.js")"
  NAV_TEXT="$(printf '%s' "${NAV_JSON}" | jq -r '.nav // empty')"
  if [ -z "${NAV_TEXT}" ]; then
    log "エラー: 進捗表示(.quiz-nav)を読み取れませんでした: ${NAV_JSON}"
    exit 1
  fi
  if [[ "${NAV_TEXT}" =~ ^([0-9]+)/([0-9]+) ]]; then
    CURR="${BASH_REMATCH[1]}"
  else
    log "エラー: 進捗表示から現在番号を抽出できませんでした: ${NAV_TEXT}"
    exit 1
  fi

  if [ "${CURR}" -gt "${END_N}" ]; then
    log "[info] ${SLUG}: 第${END_N}問まで到達しました。ループを終了します。"
    break
  fi

  if is_collected "${CURR}"; then
    # サイト側resumeとjsonlがズレていた場合の防御パス: 記録せず選択肢クリック→次の問題へ進むだけ
    log "[${CURR}/${END_N}] 第${CURR}問 既に記録済み（スキップ）"
    CLICK_JSON="$(ab eval --stdin < "${TMP_DIR}/click-first-choice.js")"
    if ! printf '%s' "${CLICK_JSON}" | jq -e '.clicked' >/dev/null 2>&1; then
      log "エラー: 第${CURR}問の選択肢をクリックできませんでした: ${CLICK_JSON}"
      exit 1
    fi
  else
    BEFORE_JSON="$(ab eval --stdin < "${TMP_DIR}/read-and-click.js")"
    if ! printf '%s' "${BEFORE_JSON}" | jq -e '.question and .choices and (.choices | length > 0)' >/dev/null 2>&1; then
      log "エラー: 第${CURR}問の問題文/選択肢を取得できませんでした: ${BEFORE_JSON}"
      exit 1
    fi
  fi

  poll_for_selector ".exp-card" 30 || {
    log "エラー: 第${CURR}問の解説開示を検出できませんでした（.exp-card が出現しません）。"
    exit 1
  }

  if ! is_collected "${CURR}"; then
    AFTER_JSON="$(ab eval --stdin < "${TMP_DIR}/read-after-click.js")"
    if ! printf '%s' "${AFTER_JSON}" | jq -e '.answer and (.explanation != null)' >/dev/null 2>&1; then
      log "エラー: 第${CURR}問の正解/解説を取得できませんでした: ${AFTER_JSON}"
      exit 1
    fi

    CATEGORY="$(printf '%s' "${BEFORE_JSON}" | jq -r '.category')"
    QUESTION="$(printf '%s' "${BEFORE_JSON}" | jq -r '.question')"
    CHOICES_JSON="$(printf '%s' "${BEFORE_JSON}" | jq -c '.choices')"
    ANSWER="$(printf '%s' "${AFTER_JSON}" | jq -r '.answer')"
    EXPLANATION="$(printf '%s' "${AFTER_JSON}" | jq -r '.explanation')"

    jq -nc \
      --argjson number "${CURR}" \
      --arg category "${CATEGORY}" \
      --arg question "${QUESTION}" \
      --argjson choices "${CHOICES_JSON}" \
      --arg answer "${ANSWER}" \
      --arg explanation "${EXPLANATION}" \
      '{number: $number, category: $category, question: $question, choices: $choices, answer: $answer, explanation: $explanation}' \
      >> "${JSONL_FILE}"

    log "[${CURR}/${END_N}] 第${CURR}問 saved"
  fi

  NEXT_JSON="$(ab eval --stdin < "${TMP_DIR}/next-question.js")"
  if ! printf '%s' "${NEXT_JSON}" | jq -e '.clicked' >/dev/null 2>&1; then
    log "[info] ${SLUG}: 「次の問題」ボタンが見つかりません。最終問題に到達したとみなし終了します。"
    break
  fi

  sleep "${WAIT_SEC}"
done

ab close >&2 || true
build_final_json
log "[done] ${SLUG}: 第${END_N}問までを収集し、${JSON_FILE} を生成しました（進捗: ${JSONL_FILE}）。"
