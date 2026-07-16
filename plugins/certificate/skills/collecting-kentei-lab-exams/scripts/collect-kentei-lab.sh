#!/usr/bin/env bash
# kentei-lab.com の資格試験ページを直接URL反復で巡回し、
# 問題文・選択肢・正解・解説を1資格1Markdownファイルへ逐次追記する。
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: collect-kentei-lab.sh <input-url> [output-dir]

  <input-url>   kentei-lab.com の URL。/exams/<slug> ・ /exams/<slug>/start ・
                /quiz/<slug>/<n> のいずれの形式でも slug を抽出できる（必須）
  [output-dir]  出力先ディレクトリ（省略時 ./kentei-lab-output）

環境変数:
  KENTEI_LAB_WAIT_MS   問題間の待機ミリ秒（既定 300・サイトへのレート配慮）
  KENTEI_LAB_MAX_N     取得上限（スモークテスト/部分取得用・既定 0=全件）
  AGENT_BROWSER        agent-browser バイナリパス上書き（既定: which agent-browser）
USAGE
  exit 1
}

[ "$#" -ge 1 ] || usage

INPUT_URL="$1"
OUTPUT_DIR="${2:-./kentei-lab-output}"

BASE_URL="https://kentei-lab.com"
KENTEI_LAB_WAIT_MS="${KENTEI_LAB_WAIT_MS:-300}"
KENTEI_LAB_MAX_N="${KENTEI_LAB_MAX_N:-0}"
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

# --- slug 抽出（/exams/<slug> ・ /exams/<slug>/start ・ /quiz/<slug>/<n> のいずれにも対応） ---
SLUG=""
if [[ "${INPUT_URL}" =~ /exams/([A-Za-z0-9_-]+) ]]; then
  SLUG="${BASH_REMATCH[1]}"
elif [[ "${INPUT_URL}" =~ /quiz/([A-Za-z0-9_-]+)/ ]]; then
  SLUG="${BASH_REMATCH[1]}"
fi
if [ -z "${SLUG}" ]; then
  log "エラー: URL から slug を抽出できません: ${INPUT_URL}"
  exit 1
fi

mkdir -p "${OUTPUT_DIR}"
MD_FILE="${OUTPUT_DIR}/${SLUG}.md"
PROGRESS_FILE="${OUTPUT_DIR}/${SLUG}.progress"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kentei-lab.XXXXXX")"
cleanup() { rm -rf "${TMP_DIR}"; }
trap cleanup EXIT

WAIT_SEC="$(awk -v ms="${KENTEI_LAB_WAIT_MS}" 'BEGIN { printf "%.3f", ms / 1000 }')"

# --- JS 抽出ロジック（agent-browser eval --stdin へ渡す）---
# 🔴 agent-browser 0.31.1 は `eval --file` を持たない（--stdin / -b base64 のみ）。
#    ドキュメント記載の --file は実バイナリと乖離しているため使わない。

cat > "${TMP_DIR}/get-n.js" <<'JS'
(() => {
  const buttons = Array.from(document.querySelectorAll('button'));
  for (const b of buttons) {
    const t = b.textContent.trim();
    const m = t.match(/^(?:🔀\s*)?全問(?:題を始める|ランダムで開始)(\d+)問$/);
    if (m) return { n: parseInt(m[1], 10) };
  }
  const bodyText = document.body.textContent || '';
  const nums = Array.from(bodyText.matchAll(/(\d+)問/g)).map((x) => parseInt(x[1], 10));
  if (nums.length > 0) return { n: Math.max(...nums) };
  return { error: 'n-not-found' };
})()
JS

cat > "${TMP_DIR}/get-title.js" <<'JS'
(() => {
  const h1 = document.querySelector('h1');
  return { title: h1 ? h1.textContent.trim() : null };
})()
JS

# 問題文・選択肢を読み取り、最初の選択肢ボタンをクリックして正解を開示させる。
# 開示前の状態を読んでから click() するため React の再レンダ前後を跨がない。
cat > "${TMP_DIR}/read-before-click.js" <<'JS'
(() => {
  const section = document.querySelector('section');
  if (!section) return { error: 'section-not-found' };
  const buttons = Array.from(section.querySelectorAll('button'));
  if (buttons.length === 0) return { error: 'no-buttons' };
  const grid = buttons[0].parentElement;
  const card = grid ? grid.parentElement : null;
  const questionP = card ? card.querySelector('p') : null;
  const question = questionP ? questionP.textContent.trim() : '';
  const choices = buttons.map((b) => b.textContent.trim()).filter(Boolean);
  buttons[0].click();
  return { question, choices };
})()
JS

cat > "${TMP_DIR}/read-after-click.js" <<'JS'
(() => {
  const section = document.querySelector('section');
  if (!section) return { error: 'section-not-found' };
  const ps = Array.from(section.querySelectorAll('p'));
  const answerP = ps.find((p) => p.textContent.trim().startsWith('正解は'));
  if (!answerP) return { error: 'answer-not-found' };
  const answer = answerP.textContent.trim();
  const box = answerP.parentElement;
  const boxPs = box ? Array.from(box.querySelectorAll(':scope > p')) : [];
  const idx = boxPs.indexOf(answerP);
  const explanation = idx >= 0 && boxPs[idx + 1] ? boxPs[idx + 1].textContent.trim() : '';
  return { answer, explanation };
})()
JS

ab() { "${AGENT_BROWSER}" "$@"; }

# --- N（総問題数）取得 ---
log "[info] ${SLUG}: 総問題数を取得中..."
ab open "${BASE_URL}/exams/${SLUG}/start" >&2
ab wait --load networkidle >&2
N_JSON="$(ab eval --stdin < "${TMP_DIR}/get-n.js")"
N="$(printf '%s' "${N_JSON}" | jq -er '.n')" || {
  log "エラー: 総問題数(N)を取得できませんでした。サイトのボタン文言が変わっている可能性があります。"
  exit 1
}
log "[info] ${SLUG}: 総問題数 = ${N}"

# --- 試験名取得 ---
ab open "${BASE_URL}/exams/${SLUG}" >&2
ab wait --load networkidle >&2
TITLE_JSON="$(ab eval --stdin < "${TMP_DIR}/get-title.js")"
EXAM_TITLE="$(printf '%s' "${TITLE_JSON}" | jq -er '.title // empty')" || EXAM_TITLE="${SLUG}"
[ -n "${EXAM_TITLE}" ] || EXAM_TITLE="${SLUG}"

# --- 取得上限の決定 ---
END_N="${N}"
if [ "${KENTEI_LAB_MAX_N}" -gt 0 ] 2>/dev/null && [ "${KENTEI_LAB_MAX_N}" -lt "${N}" ]; then
  END_N="${KENTEI_LAB_MAX_N}"
fi

# --- 出力ファイル初期化 / resume 開始位置決定 ---
START_N=1
if [ -f "${PROGRESS_FILE}" ]; then
  LAST_DONE="$(cat "${PROGRESS_FILE}")"
  if [[ "${LAST_DONE}" =~ ^[0-9]+$ ]]; then
    START_N=$((LAST_DONE + 1))
  fi
elif [ -f "${MD_FILE}" ]; then
  LAST_DONE="$(grep -oE '^## 第[0-9]+問' "${MD_FILE}" | grep -oE '[0-9]+' | sort -n | tail -1 || true)"
  if [[ "${LAST_DONE}" =~ ^[0-9]+$ ]]; then
    START_N=$((LAST_DONE + 1))
  fi
fi

if [ ! -f "${MD_FILE}" ]; then
  {
    printf '# %s（%s）\n\n' "${EXAM_TITLE}" "${SLUG}"
    printf -- '- 出典: %s/exams/%s\n' "${BASE_URL}" "${SLUG}"
    printf -- '- 総問題数: %s\n' "${N}"
    printf -- '- 取得日時: %s\n\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf -- '---\n'
  } >> "${MD_FILE}"
fi

if [ "${START_N}" -gt "${END_N}" ]; then
  log "[info] ${SLUG}: 第${END_N}問まで取得済みです。追加取得なし。"
  exit 0
fi

log "[info] ${SLUG}: 第${START_N}問から第${END_N}問まで取得します（既存分はスキップ）。"

# --- メインループ ---
n="${START_N}"
while [ "${n}" -le "${END_N}" ]; do
  ab open "${BASE_URL}/quiz/${SLUG}/${n}" >&2
  ab wait --text "第" >&2

  BEFORE_JSON="$(ab eval --stdin < "${TMP_DIR}/read-before-click.js")"
  if ! printf '%s' "${BEFORE_JSON}" | jq -e '.question and .choices and (.choices | length > 0)' >/dev/null 2>&1; then
    log "エラー: 第${n}問の問題文/選択肢を取得できませんでした: ${BEFORE_JSON}"
    exit 1
  fi

  ab wait --text "正解は" >&2
  AFTER_JSON="$(ab eval --stdin < "${TMP_DIR}/read-after-click.js")"
  if ! printf '%s' "${AFTER_JSON}" | jq -e '.answer and (.explanation != null)' >/dev/null 2>&1; then
    log "エラー: 第${n}問の正解/解説を取得できませんでした: ${AFTER_JSON}"
    exit 1
  fi

  QUESTION="$(printf '%s' "${BEFORE_JSON}" | jq -r '.question')"
  ANSWER="$(printf '%s' "${AFTER_JSON}" | jq -r '.answer' | sed 's/^正解は//')"
  EXPLANATION="$(printf '%s' "${AFTER_JSON}" | jq -r '.explanation')"
  CHOICES_MD="$(printf '%s' "${BEFORE_JSON}" | jq -r '.choices[] | "- " + .')"

  BLOCK="$(cat <<MDBLOCK

## 第${n}問

${QUESTION}

**選択肢**

${CHOICES_MD}

**正解**:${ANSWER}

**解説**

${EXPLANATION}

---
MDBLOCK
)"
  printf '%s\n' "${BLOCK}" >> "${MD_FILE}"
  printf '%s' "${n}" > "${PROGRESS_FILE}"

  log "[${n}/${END_N}] 第${n}問 saved"

  n=$((n + 1))
  if [ "${n}" -le "${END_N}" ]; then
    sleep "${WAIT_SEC}"
  fi
done

ab close >&2 || true
log "[done] ${SLUG}: 第${START_N}問〜第${END_N}問を ${MD_FILE} に保存しました。"
