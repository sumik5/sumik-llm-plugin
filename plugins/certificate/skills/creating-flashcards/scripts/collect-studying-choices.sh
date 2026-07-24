#!/usr/bin/env bash
# collect-studying.sh が生成した1科目分のJSON（choice_type: "multi_blank" の複数空欄穴埋め問題を
# 含む）を対象に、「解説一覧表示」ページには含まれない語群（各空欄の選択肢一覧）を、
# 個別の出題ページ（練習モード）を1問ずつ辿って追加取得し、対応する問題の choices フィールドを
# 更新して同じパスへ上書き保存する。
#
# 🔴 実機確認済み（practice_id=223631「判例ビジュアルチェック200-労働基準法（労働者、強行法規）」で
#    検証）: 「解説一覧表示」ページ（collect-studying.sh が使う一括表示ページ）には語群情報が
#    一切含まれない。語群は科目トップページ → 練習モード「問題を開始」/「問題を再開」→
#    個別出題ページ（course/question/index/q/<question_id>/）にのみ存在する。question_id は
#    動的に決まり事前列挙できないため、「次の問題へ」で1問ずつ辿るしかない。
# 🔴 出題順序が「解説一覧表示」ページの number と一致する保証がないため（科目トップページに
#    出題順序ラジオボタンが存在＝ランダム順オプションがありうる）、number には依存せず
#    問題文の内容一致でマッチングする（詳細は merge 処理・INSTRUCTIONS.md 参照）。
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: collect-studying-choices.sh <json-file>

  <json-file>  collect-studying.sh が生成した1科目分のJSON（practice_idフィールドを持つ）。
               このファイルを直接読み込み、語群取得後に同じパスへ上書き保存する。

環境変数:
  STUDYING_STATE_FILE            agent-browser state ファイルパス（必須。既にログイン済みの
                                  state を指定する）
  STUDYING_CHOICES_WAIT_MIN_SEC  各問題処理後の待機秒数の下限（既定 10）
  STUDYING_CHOICES_WAIT_MAX_SEC  各問題処理後の待機秒数の上限（既定 15）
  STUDYING_CHOICES_MAX_N         スモークテスト用の処理問題数上限（既定 0=全件）
  AGENT_BROWSER                  agent-browser バイナリパス上書き（既定: which agent-browser）
USAGE
  exit 1
}

[ "$#" -ge 1 ] || usage

JSON_FILE="$1"
BASE_URL="https://member.studying.jp"
STUDYING_STATE_FILE="${STUDYING_STATE_FILE:?エラー: STUDYING_STATE_FILE が未設定です（既存のログイン済みstateファイルパスを指定してください）}"
STUDYING_CHOICES_WAIT_MIN_SEC="${STUDYING_CHOICES_WAIT_MIN_SEC:-10}"
STUDYING_CHOICES_WAIT_MAX_SEC="${STUDYING_CHOICES_WAIT_MAX_SEC:-15}"
STUDYING_CHOICES_MAX_N="${STUDYING_CHOICES_MAX_N:-0}"
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

if [ ! -f "${JSON_FILE}" ]; then
  log "エラー: 入力JSONファイルが見つかりません: ${JSON_FILE}"
  exit 1
fi

if [ ! -f "${STUDYING_STATE_FILE}" ]; then
  log "エラー: state ファイルが見つかりません: ${STUDYING_STATE_FILE}"
  exit 1
fi

PRACTICE_ID="$(jq -r '.practice_id // empty' "${JSON_FILE}")"
if [ -z "${PRACTICE_ID}" ]; then
  log "エラー: 入力JSONに practice_id フィールドがありません: ${JSON_FILE}"
  exit 1
fi

MULTI_BLANK_TOTAL="$(jq '[.questions[] | select(.choice_type=="multi_blank")] | length' "${JSON_FILE}")"
FILL_IN_SINGLE_TOTAL="$(jq '[.questions[] | select(.choice_type=="fill_in_single")] | length' "${JSON_FILE}")"
if [ "${MULTI_BLANK_TOTAL}" -eq 0 ] && [ "${FILL_IN_SINGLE_TOTAL}" -eq 0 ]; then
  log "[info] この科目には choice_type=\"multi_blank\"/\"fill_in_single\" の問題がありません。選択肢取得をスキップします: ${JSON_FILE}"
  exit 0
fi
log "[info] 対象科目: ${JSON_FILE}"
log "[info] practice_id=${PRACTICE_ID} / multi_blank問題数=${MULTI_BLANK_TOTAL} / fill_in_single問題数=${FILL_IN_SINGLE_TOTAL}"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/studying-choices.XXXXXX")"
cleanup() { rm -rf "${TMP_DIR}"; }
trap cleanup EXIT

ab() { "${AGENT_BROWSER}" "$@"; }

COLLECTED_JSONL="${TMP_DIR}/collected.jsonl"
: > "${COLLECTED_JSONL}"

# --- JS 抽出/操作ロジック（agent-browser eval --stdin へ渡す）---

# 🔴 実機確認済み: 練習モード開始ボタンは button.mode-0（本番モードは mode-1）。
#    onclick="coursePractice.onStartButtonClick(event);" は3種のボタン/リンクに共通で
#    付与されているため、class名（mode-0）で練習モードを一意に特定する。
#    「問題を開始」（初回）/「問題を再開」（2回目以降）のいずれのテキストでもクラスは変わらない
#    前提（初回のみ実機確認済み。再開時のクラス変化は未確認のためフォールバックとして
#    テキストマッチも行う）。
cat > "${TMP_DIR}/click-start-practice.js" <<'JS'
(() => {
  let btn = document.querySelector('button.mode-0');
  if (!btn) {
    // フォールバック: クラス構造が変わっている場合、テキストで探す
    const candidates = Array.from(document.querySelectorAll('button, a'));
    btn = candidates.find((el) => {
      const t = (el.textContent || '').trim();
      return t === '問題を開始' || t === '問題を再開';
    });
  }
  if (!btn) return { error: 'start-button-not-found' };
  btn.click();
  return { ok: true };
})()
JS

# 🔴 実機確認済み（スモークテストで検出・修正）: 既に「未完了の問題」が残っている状態で
#    button.mode-0（練習モード開始ボタン）をクリックすると、直接1問目へは遷移せず
#    「新規に問題を開始しますか？（未完了の問題は削除されます）」という確認モーダルが開くだけに
#    留まる。このモーダル内の「問題を開始」リンク（a.m-practice-container__modal-practice-start）
#    を追加でクリックしないと実際には進まない（未完了の問題が無い＝初回実行時はこのモーダル自体が
#    出ないため、モーダルが無い場合は found:false を返すだけで何もしない設計にする）。
cat > "${TMP_DIR}/click-modal-confirm-start.js" <<'JS'
(() => {
  const link = document.querySelector('a.m-practice-container__modal-practice-start');
  if (!link) return { found: false };
  link.click();
  return { found: true };
})()
JS

# 🔴 実機確認済み（practice_id=223631の問題1・2で確認）: 個別出題ページの問題文は
#    .redactor-editor のtextContent（「解説一覧表示」ページのquestionフィールドと同一内容）。
#    語群見出しは h3（textContentに「語群」を含む。例:「[Ａの語群]」）、その直後の兄弟要素が
#    ul#question_multi_words（複数存在時はidが重複するが nextElementSibling で個別に辿るため
#    問題ない）。ラベル（Ａ/Ｂ/Ｃ…）は h3 テキストから正規表現で抽出する。
# 🔴 実機確認済み（practice_id=223631の問題7「江東ダイハツ自動車事件」で確認）:
#    choice_type: "fill_in_single"（単一空欄穴埋め）形式の選択肢は、multi_blankのh3+ulとは
#    別のマークアップ ul.ipt-button > li.notosans-mark で存在する。各liのdata-item属性
#    （無ければtextContentへフォールバック）が選択肢テキストになる。multi_blankのような複数
#    ラベル（Ａ/Ｂ/Ｃ）は無く単一の空欄用選択肢一覧のため、単純な文字列配列として抽出する。
#    1問につきどちらか一方のみ存在する想定だが、念のため両方チェックし存在する方を採用する。
# 🔴 questionText は HTML保持（sanitizeHtml、collect-studying.sh と同一の厳格な許可リスト方式）で
#    取得する（当初は normWS(textContent) によるプレーンテキストだったが、一部の問題で解説一覧表示
#    ページ側の question〈HTML→タグ除去したプレーンテキスト〉と冒頭が一致せずマッチング失敗する
#    ケースがあったため、両者を同じ経路〈HTML→plain_text〉で正規化して比較できるようにするために
#    HTML化した。ユーザー承認済み）。
cat > "${TMP_DIR}/get-question-and-word-groups.js" <<'JS'
(() => {
  function normWS(s) {
    return (s || '').replace(/[ \t]+/g, ' ').replace(/\s*\n\s*/g, '\n').trim();
  }

  // 🔴 collect-studying.sh の sanitizeHtml() と同一の厳格な許可リスト方式（クライアントサイド
  //    Webセキュリティレビューの指摘に基づく設計をそのまま踏襲）。
  function sanitizeHtml(el) {
    if (!el) return '';
    const clone = el.cloneNode(true);

    const REMOVE_ENTIRELY_SELECTOR =
      'script, style, iframe, object, embed, svg, math, form, input, button, textarea, select, link, meta';
    clone.querySelectorAll(REMOVE_ENTIRELY_SELECTOR).forEach((n) => n.remove());

    const ALLOWED_TAGS = new Set([
      'p', 'br', 'span', 'strong', 'em', 'b', 'i', 'u', 'del',
      'div', 'table', 'thead', 'tbody', 'tr', 'td', 'th', 'ol', 'ul', 'li', 'img', 'a',
    ]);
    const CLASS_VALUE_RE = /^[A-Za-z0-9_\- ]+$/;

    function unwrap(node) {
      const parent = node.parentNode;
      if (!parent) return;
      while (node.firstChild) {
        parent.insertBefore(node.firstChild, node);
      }
      parent.removeChild(node);
    }

    function filterAttributes(node) {
      const tag = node.tagName.toLowerCase();
      const keep = new Set(['class']);
      if (tag === 'img') {
        keep.add('src');
        keep.add('alt');
      } else if (tag === 'a') {
        keep.add('href');
      }
      for (const attr of Array.from(node.attributes)) {
        const name = attr.name.toLowerCase();
        if (!keep.has(name)) {
          node.removeAttribute(attr.name);
          continue;
        }
        if (name === 'class' && !CLASS_VALUE_RE.test(attr.value || '')) {
          node.removeAttribute(attr.name);
        }
      }
      if (tag === 'a' && node.hasAttribute('href')) {
        const href = node.getAttribute('href') || '';
        if (!/^https?:\/\//i.test(href)) {
          node.removeAttribute('href');
        }
      }
      if (tag === 'img' && node.hasAttribute('src')) {
        const src = node.getAttribute('src') || '';
        if (/^\s*(javascript|vbscript):/i.test(src)) {
          node.removeAttribute('src');
        }
      }
    }

    const nodesDeepFirst = Array.from(clone.querySelectorAll('*')).reverse();
    for (const node of nodesDeepFirst) {
      if (!node.parentNode) continue;
      const tag = node.tagName.toLowerCase();
      if (!ALLOWED_TAGS.has(tag)) {
        unwrap(node);
        continue;
      }
      filterAttributes(node);
    }

    clone.querySelectorAll('img[src]').forEach((img) => {
      const src = img.getAttribute('src') || '';
      if (src && !/^(https?:)?\/\//i.test(src) && !/^data:/i.test(src)) {
        try {
          img.setAttribute('src', new URL(src, document.baseURI).href);
        } catch (e) {
          // 変換失敗時は元の src のまま維持する
        }
      }
    });

    return clone.innerHTML.trim();
  }

  const questionEditor = document.querySelector('.redactor-editor');
  const questionText = sanitizeHtml(questionEditor);

  const wordGroups = {};
  const h3s = Array.from(document.querySelectorAll('h3')).filter((h) => (h.textContent || '').includes('語群'));
  for (const h3 of h3s) {
    const m = (h3.textContent || '').match(/[\[［]\s*(.+?)\s*の語群\s*[\]］]/);
    const label = m ? m[1].trim() : (h3.textContent || '').trim();
    const ul = h3.nextElementSibling;
    if (ul && ul.tagName === 'UL') {
      const items = Array.from(ul.querySelectorAll(':scope > li'))
        .map((li) => normWS(li.textContent))
        .filter(Boolean);
      if (items.length > 0) {
        wordGroups[label] = items;
      }
    }
  }

  let singleChoices = [];
  const singleUl = document.querySelector('ul.ipt-button');
  if (singleUl) {
    singleChoices = Array.from(singleUl.querySelectorAll(':scope > li.notosans-mark'))
      .map((li) => {
        const dataItem = li.getAttribute('data-item');
        return dataItem ? dataItem.trim() : normWS(li.textContent);
      })
      .filter(Boolean);
  }

  return {
    questionText,
    wordGroups,
    singleChoices,
    hasWordGroups: Object.keys(wordGroups).length > 0,
    hasSingleChoices: singleChoices.length > 0,
  };
})()
JS

# 「スキップして解説を見る」リンクのクリック。
cat > "${TMP_DIR}/click-skip.js" <<'JS'
(() => {
  const els = Array.from(document.querySelectorAll('a, button'));
  const link = els.find((el) => (el.textContent || '').trim() === 'スキップして解説を見る');
  if (!link) return { error: 'skip-link-not-found' };
  link.click();
  return { ok: true };
})()
JS

# 「次の問題へ」リンクのクリック（科目最後の問題では見つからない想定。防御的に found:false を返す）。
cat > "${TMP_DIR}/click-next.js" <<'JS'
(() => {
  const els = Array.from(document.querySelectorAll('a, button'));
  const link = els.find((el) => (el.textContent || '').trim() === '次の問題へ');
  if (!link) return { found: false };
  link.click();
  return { found: true };
})()
JS

# --- ブラウザ操作フロー ---

TOP_URL="${BASE_URL}/course/practice/index/id/${PRACTICE_ID}/"
log "[info] 科目トップページを開いています: ${TOP_URL}"
ab --state "${STUDYING_STATE_FILE}" open "${TOP_URL}" >&2
ab wait --load networkidle >&2

START_RESULT="$(ab eval --stdin < "${TMP_DIR}/click-start-practice.js")"
if printf '%s' "${START_RESULT}" | jq -e '.error' >/dev/null 2>&1; then
  log "エラー: 練習モード開始ボタンが見つかりませんでした: ${START_RESULT}"
  ab close >&2 || true
  exit 1
fi
ab wait --load networkidle >&2

# 🔴 実機確認済み: 「未完了の問題」が残っている状態では上記クリックが確認モーダルを開くだけに
#    留まるため、モーダルが出ていれば追加でクリックする（無ければ何もしない）。
MODAL_RESULT="$(ab eval --stdin < "${TMP_DIR}/click-modal-confirm-start.js")" || true
MODAL_FOUND="$(printf '%s' "${MODAL_RESULT}" | jq -r '.found // "false"' 2>/dev/null || printf 'false')"
if [ "${MODAL_FOUND}" = "true" ]; then
  log "[info] 「未完了の問題」の新規開始確認モーダルを検出しクリックしました（未完了の問題を破棄して1問目から開始します）。"
  ab wait --load networkidle >&2
fi

QUESTION_INDEX=0
WORD_GROUPS_FOUND=0
SINGLE_CHOICES_FOUND=0
while true; do
  QUESTION_INDEX=$((QUESTION_INDEX + 1))
  if [ "${STUDYING_CHOICES_MAX_N}" -gt 0 ] 2>/dev/null && [ "${QUESTION_INDEX}" -gt "${STUDYING_CHOICES_MAX_N}" ]; then
    log "[info] STUDYING_CHOICES_MAX_N=${STUDYING_CHOICES_MAX_N} に達したため処理を打ち切ります。"
    QUESTION_INDEX=$((QUESTION_INDEX - 1))
    break
  fi

  Q_RESULT="$(ab eval --stdin < "${TMP_DIR}/get-question-and-word-groups.js")" || {
    log "[warn] 問題 ${QUESTION_INDEX}: 問題文/選択肢の読み取りに失敗しました。処理を中断します。"
    break
  }
  HAS_WG="$(printf '%s' "${Q_RESULT}" | jq -r '.hasWordGroups')"
  HAS_SC="$(printf '%s' "${Q_RESULT}" | jq -r '.hasSingleChoices')"
  if [ "${HAS_WG}" = "true" ]; then
    printf '%s' "${Q_RESULT}" | jq -c '{question_text: .questionText, word_groups: .wordGroups}' >> "${COLLECTED_JSONL}"
    WORD_GROUPS_FOUND=$((WORD_GROUPS_FOUND + 1))
    log "[info] 問題 ${QUESTION_INDEX}: 語群（multi_blank）を検出しました。"
  elif [ "${HAS_SC}" = "true" ]; then
    printf '%s' "${Q_RESULT}" | jq -c '{question_text: .questionText, single_choices: .singleChoices}' >> "${COLLECTED_JSONL}"
    SINGLE_CHOICES_FOUND=$((SINGLE_CHOICES_FOUND + 1))
    log "[info] 問題 ${QUESTION_INDEX}: 選択肢（fill_in_single）を検出しました。"
  else
    log "[info] 問題 ${QUESTION_INDEX}: 語群/選択肢なし（対象外の形式）。スキップします。"
  fi

  SKIP_RESULT="$(ab eval --stdin < "${TMP_DIR}/click-skip.js")" || {
    log "[warn] 問題 ${QUESTION_INDEX}: スキップリンクのクリックに失敗しました。処理を中断します。"
    break
  }
  if printf '%s' "${SKIP_RESULT}" | jq -e '.error' >/dev/null 2>&1; then
    log "[warn] 問題 ${QUESTION_INDEX}: 「スキップして解説を見る」リンクが見つかりませんでした。処理を中断します。"
    break
  fi
  ab wait --load networkidle >&2

  # 🔴 サイトへの配慮: 各問題処理後に10〜15秒のランダム待機を必ず入れる（固定間隔ではなく
  #    ばらつきを持たせる）。範囲は STUDYING_CHOICES_WAIT_MIN_SEC〜MAX_SEC で調整可能。
  WAIT_RANGE=$((STUDYING_CHOICES_WAIT_MAX_SEC - STUDYING_CHOICES_WAIT_MIN_SEC + 1))
  if [ "${WAIT_RANGE}" -lt 1 ]; then
    WAIT_RANGE=1
  fi
  WAIT_SEC=$((STUDYING_CHOICES_WAIT_MIN_SEC + (RANDOM % WAIT_RANGE)))
  log "[info] 問題 ${QUESTION_INDEX} 処理完了。${WAIT_SEC}秒待機します..."
  sleep "${WAIT_SEC}"

  NEXT_RESULT="$(ab eval --stdin < "${TMP_DIR}/click-next.js")" || {
    log "[info] 「次の問題へ」の判定に失敗しました。科目終了とみなします（問題 ${QUESTION_INDEX} で終了）。"
    break
  }
  FOUND="$(printf '%s' "${NEXT_RESULT}" | jq -r '.found')"
  if [ "${FOUND}" != "true" ]; then
    log "[info] 「次の問題へ」が見つかりません。科目終了とみなします（問題 ${QUESTION_INDEX} で終了）。"
    break
  fi
  ab wait --load networkidle >&2
done

ab close >&2 || true

log "[info] 巡回完了: 処理問題数=${QUESTION_INDEX} / 語群検出数=${WORD_GROUPS_FOUND} / 選択肢検出数=${SINGLE_CHOICES_FOUND}"

if [ "${WORD_GROUPS_FOUND}" -eq 0 ] && [ "${SINGLE_CHOICES_FOUND}" -eq 0 ]; then
  log "[warn] 語群・選択肢を1件も取得できませんでした。JSONは更新しません: ${JSON_FILE}"
  exit 0
fi

# --- マージ処理（jq）: number に依存せず問題文の内容一致でマッチングする ---
# 🔴 出題順序が「解説一覧表示」ページの number と一致する保証がないため、収集した問題文
#    （個別ページの .redactor-editor 由来・プレーンテキスト）の先頭 MATCH_PREFIX_LEN 文字が、
#    既存JSON側の question（HTML→タグ除去したプレーンテキスト）に部分一致(contains)するかで
#    対応付ける。一意にマッチしない場合（0件・複数件）は安全側に倒し、その問題の choices は
#    更新しない（既存の空配列のまま据え置く）。
# 🔴 multi_blank分岐は既存ロジックのまま（select(.word_groups != null)は、収集JSON Linesに
#    fill_in_single用エントリ〈single_choicesキー〉が混在するようになったことに伴い、
#    誤って別形式のエントリをマッチ候補にしないための絞り込みを明示しただけで、既存の
#    マッチング精度・判定条件自体は変更していない）。
# 🔴 マッチング精度改善（ユーザー承認済み）: question_text が HTML化されたことに伴い、
#    比較前に既存JSON側と同じ plain_text（タグ除去）を .question_text 側にも適用するよう変更した。
#    従来は「既存JSON側はタグ除去済み・収集側はプレーンテキスト」という非対称比較だったため、
#    HTML構造の違い（リスト・強調タグ等）によって冒頭の空白パターンが微妙にずれ、マッチ0件に
#    なるケースがあった。両者を同じ正規化経路に統一することで、この種の不一致を減らす狙い。
MATCH_PREFIX_LEN=60
cat > "${TMP_DIR}/merge.jq" <<JQ
def plain_text: gsub("<[^>]*>"; "");

(\$entries) as \$entries |
.questions |= map(
  if .choice_type == "multi_blank" then
    (.question | plain_text) as \$qtext |
    ([\$entries[] | select(.word_groups != null) | select((.question_text | plain_text | .[0:${MATCH_PREFIX_LEN}]) as \$probe | (\$probe | length) > 0 and (\$qtext | contains(\$probe)))]) as \$matches |
    if (\$matches | length) == 1 then
      . + {choices: \$matches[0].word_groups}
    else
      .
    end
  elif .choice_type == "fill_in_single" then
    (.question | plain_text) as \$qtext |
    ([\$entries[] | select(.single_choices != null) | select((.question_text | plain_text | .[0:${MATCH_PREFIX_LEN}]) as \$probe | (\$probe | length) > 0 and (\$qtext | contains(\$probe)))]) as \$matches |
    if (\$matches | length) == 1 then
      . + {choices: \$matches[0].single_choices}
    else
      .
    end
  else
    .
  end
)
JQ

jq --slurpfile entries "${COLLECTED_JSONL}" -f "${TMP_DIR}/merge.jq" "${JSON_FILE}" > "${TMP_DIR}/merged.json"

# 🔴 マージ結果が壊れていないこと（有効なJSON・questions配列を保持していること）を確認してから
#    上書きする（jq自体が不正なJSONを吐くことは通常ないが、念のための防御）。
if ! jq -e '.questions | type == "array"' "${TMP_DIR}/merged.json" >/dev/null 2>&1; then
  log "エラー: マージ後のJSONが不正です。上書きを中止します: ${JSON_FILE}"
  exit 1
fi

mv "${TMP_DIR}/merged.json" "${JSON_FILE}"

MATCHED_COUNT="$(jq '[.questions[] | select(.choice_type=="multi_blank" and (.choices | type=="object") and (.choices | length) > 0)] | length' "${JSON_FILE}")"
MATCHED_SINGLE_COUNT="$(jq '[.questions[] | select(.choice_type=="fill_in_single" and (.choices | type=="array") and (.choices | length) > 0)] | length' "${JSON_FILE}")"
log "[done] ${JSON_FILE}: multi_blank ${MULTI_BLANK_TOTAL}件中 ${MATCHED_COUNT}件・fill_in_single ${FILL_IN_SINGLE_TOTAL}件中 ${MATCHED_SINGLE_COUNT}件の choices を更新しました（収集した語群セット数=${WORD_GROUPS_FOUND}／選択肢セット数=${SINGLE_CHOICES_FOUND}）。"
