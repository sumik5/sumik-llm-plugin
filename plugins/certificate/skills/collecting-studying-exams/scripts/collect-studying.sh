#!/usr/bin/env bash
# studying（スタディング, member.studying.jp）のコースレッスン一覧ページを巡回し、配下の
# 「スマート問題集」「セレクト過去問集（学科試験対策）」「セレクト過去問集（実技試験対策）」の
# 全科目を収集する。各科目は「解説一覧表示」ページ（1回の読み込みで全問題・全選択肢・正解・解説が
# 表示される）へ直接アクセスし、1科目1JSON（<course-slug>__<category-slug>__<subject-slug>.json）へ
# 保存する。
#
# 🔴 Whizlabs とは異なり、1問ずつの SPA ナビゲーション（番号クリック→選択肢確認→Show Answer→Next）は
#    一切不要。科目ページ内の「解説一覧表示」リンクに直接アクセスするだけで科目1件分の全データが
#    一括表示されるため、収集は「開く→読み取る」の2コマンドで完結する（詳細: INSTRUCTIONS.md §2）。
# 🔴 進捗サイドカー（.jsonl）は出力しない。単一ページ読み取りで科目データが完結するため、失敗した
#    科目は再実行時にその科目単体を再取得すればよい（Whizlabsのような擬似resumeは不要）。
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: collect-studying.sh <course-list-url> [output-dir]

  <course-list-url>  studying のコースレッスン一覧URL
                      （例: https://member.studying.jp/course/id/<course_id>/）
  [output-dir]        出力先ディレクトリ（省略時 ./studying-output）。
                      科目ごとに <course-slug>__<category-slug>__<subject-slug>.json を出力する。

環境変数:
  STUDYING_USERNAME     ログイン用メールアドレス（state/Auth Vault未確立時に必須）
  STUDYING_PASSWORD     ログイン用パスワード（state/Auth Vault未確立時に必須。agent-browser fill の引数として渡す）
  STUDYING_STATE_FILE   agent-browser state ファイルパス（既定 <output-dir>/.studying-state.json）
  STUDYING_AUTH_PROFILE Auth Vault のプロファイル名（既定 studying）
  STUDYING_WAIT_MS      科目間の待機ミリ秒（既定 300・サイトへのレート配慮）
  STUDYING_MAX_N        スモークテスト用の処理科目数上限（全カテゴリ合計・既定 0=全件）
  AGENT_BROWSER         agent-browser バイナリパス上書き（既定: which agent-browser）
USAGE
  exit 1
}

[ "$#" -ge 1 ] || usage

COURSE_URL="$1"
OUTPUT_DIR="${2:-./studying-output}"

BASE_URL="https://member.studying.jp"
LOGIN_URL="${BASE_URL}/login/"
STUDYING_WAIT_MS="${STUDYING_WAIT_MS:-300}"
STUDYING_MAX_N="${STUDYING_MAX_N:-0}"
STUDYING_STATE_FILE="${STUDYING_STATE_FILE:-${OUTPUT_DIR}/.studying-state.json}"
STUDYING_AUTH_PROFILE="${STUDYING_AUTH_PROFILE:-studying}"
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

# --- コース id 抽出（/course/id/<course_id>/ から） ---
COURSE_ID=""
if [[ "${COURSE_URL}" =~ /course/id/([0-9]+) ]]; then
  COURSE_ID="${BASH_REMATCH[1]}"
fi
if [ -z "${COURSE_ID}" ]; then
  log "エラー: URL からコース id を抽出できません: ${COURSE_URL}"
  exit 1
fi

mkdir -p "${OUTPUT_DIR}"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/studying.XXXXXX")"
cleanup() { rm -rf "${TMP_DIR}"; }
trap cleanup EXIT

WAIT_SEC="$(awk -v ms="${STUDYING_WAIT_MS}" 'BEGIN { printf "%.3f", ms / 1000 }')"

ab() { "${AGENT_BROWSER}" "$@"; }

# ファイル名安全化（日本語は保持しつつ、パス区切り文字・制御文字・空白のみ置換する）。
# 🔴 studying はコース名・科目名が日本語のため、Whizlabs 版の slugify（ASCII専用・非ASCIIを
#    全て除去する）はそのまま使えない。UTF-8 ファイル名を許容する前提で、ファイルシステム上
#    危険な文字（/ \ : * ? " < > |）と空白のみアンダースコアへ置換する。
# 🔴 防御的修正: sed は改行をレコード区切りとして扱うため、複数行文字列に対して
#    `[[:space:]]+` が改行を正しくアンダースコアへ変換しきれないケースがある（実機確認済み）。
#    sed にかける前に tr で改行・復帰・タブを先に空白へ変換しておく。
sanitize_jp() {
  local s
  s="$(printf '%s' "$1" | tr '\n\r\t' '   ' | /usr/bin/sed -E 's#[/\\:*?"<>|]+#_#g; s/[[:space:]]+/_/g; s/_+/_/g; s/^_+//; s/_+$//')"
  printf '%s' "${s}"
}

# --- JS 抽出ロジック（agent-browser eval --stdin へ渡す）---
# 🔴 collect-whizlabs.sh と同様、常に --stdin へヒアドキュメントで渡す。

# ログイン判定: ヘッダー等に textContent "ログイン" または "ログインする" の <a> があるかで判定する。
# （実機調査: studying の通常フォームログインページ自体は確認済みだが、ログイン後ヘッダーの正確な
#    表示文言までは未確認のため「ログインリンクの消失」という Whizlabs と同型の判定方式を採る）
cat > "${TMP_DIR}/check-login.js" <<'JS'
(() => {
  const links = Array.from(document.querySelectorAll('a'));
  const hasLoginLink = links.some((a) => {
    const t = (a.textContent || '').trim();
    return t === 'ログイン' || t === 'ログインする';
  });
  return { loggedIn: !hasLoginLink };
})()
JS

# ログインページ内「ログインする」リンクのクリック。
cat > "${TMP_DIR}/click-login-link.js" <<'JS'
(() => {
  const links = Array.from(document.querySelectorAll('a'));
  const link = links.find((a) => (a.textContent || '').trim() === 'ログインする');
  if (!link) return { error: 'login-link-not-found' };
  link.click();
  return { ok: true };
})()
JS

# コースタイトル取得: 🔴 実機確認済み（バグ修正）: ページ最初の h1 は共通ヘッダー
#    「スタディング マイページ」であり科目コース名ではない。document.title は
#    「<コース名> - スタディング 会員ページ」形式のため、末尾サフィックスを除去して使う。
cat > "${TMP_DIR}/get-course-title.js" <<'JS'
(() => {
  const raw = document.title || '';
  const title = raw.replace(/\s*-\s*スタディング\s*会員ページ\s*$/, '').trim();
  return { title: title || null };
})()
JS

# --- コーストップページの科目トグル展開 + practice_id 一括収集 ---
# 🔴 実機確認済み（practice_id収集の実機スモークテストで確定）:
#    - 科目トグル要素の確定セレクタ: `.m-ctop-course-d-list__link`（onclick属性を持つdiv。
#      `[onclick]` 全般より特定的で誤検出が少ない）。
#    - 科目名の確定セレクタ: `toggle.querySelector('.m-ctop-course-d-list__name')` の
#      textContent（.trim()のみでよい）。toggle.textContent をそのまま使うと進捗表示
#      （例:「6/6」）や大量の空白・改行が混入し、ファイル名が壊れる不具合があったため
#      修正した。
#    - リンク探索: 祖先方向への曖昧な深さ探索ではなく `toggle.closest('li')` で科目1件分の
#      LI要素を直接取得し、その中で `a[href*="course/practice/index/id/"]` を探す。
#    - 🔴 クリック直後は展開アニメーションが完了しておらずDOMに反映されない
#      （実機確認済み: 約500ms待機後に反映される）。同期的に探索すると
#      `practice-link-not-found-after-click` で軒並み失敗するため、本スクリプトは
#      非同期関数（async IIFE）にして各トグルクリック後に待機を挟む。agent-browser の
#      eval は async 関数が返す Promise を正しく解決できることを実機確認済み。
#    - 「セレクト過去問集（実技試験対策）」も学科試験対策と同一UI基盤であることを実機確認済み
#      （著作権法科目で同じ挙動を確認）。ただし科目ページ内部の `.list_question`/`.list_answer`
#      構造そのものは実技側では未確認（INSTRUCTIONS.md §2参照）。
cat > "${TMP_DIR}/collect-practice-links.js" <<'JS'
(async () => {
  const CATEGORIES = [
    'スマート問題集',
    'セレクト過去問集（学科試験対策）',
    'セレクト過去問集（実技試験対策）',
  ];
  const TOGGLE_SELECTOR = '.m-ctop-course-d-list__link';
  const NAME_SELECTOR = '.m-ctop-course-d-list__name';
  const EXPAND_WAIT_MS = 500;

  function norm(s) {
    return (s || '').replace(/\s+/g, '').trim();
  }

  function sleep(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  const allEls = Array.from(document.querySelectorAll('body *'));
  // 見出し候補: 子要素を持たない（テキストノードのみの）要素で CATEGORIES 文字列と完全一致するもの
  const headings = [];
  for (const label of CATEGORIES) {
    const el = allEls.find((e) => e.children.length === 0 && norm(e.textContent) === norm(label));
    if (el) headings.push({ label, el });
  }
  if (headings.length === 0) {
    // 🔴 nosubcat フォールバック（実機確認済み・再検証済み: コースID 2722「判例ビジュアルチェック200」の
    //    ような無料公開特別コンテンツ）: 通常コースの3セクション見出しが存在せず、カテゴリ見出しが
    //    h2.m-ctop-course-d-list__title--nosubcat（例:「労働基準法」）として直接列挙される構造。
    //    🔴 当初は h2 の祖先である .m-ctop-course-d-list__link（div, onclick="open_detail('practice',
    //    <id>, event)"）の <id> を practice_id とみなして抽出していたが、これは誤りだった（実機再検証で
    //    判明: このIDは「カテゴリ全体の開閉UI用の集約ID」であり、この ID で解説一覧表示ページ
    //    （course/practice/list/id/<id>/a/on/）を開くと 404 になる）。
    //    正しい practice_id は、見出しの closest('.m-ctop-course-d-list') 配下の
    //    ul.m-ctop-course-d-list__list--nosubcat 内に**最初からDOM上に存在する**
    //    a[href*="course/practice/index/id/"] リンクの href から取得する（クリック・展開待機は不要）。
    //    🔴 注意: 見出しdiv・科目リンクaタグの両方に同じクラス名 m-ctop-course-d-list__link が
    //    付与されているため、querySelectorAll では必ず 'a[href*="course/practice/index/id/"]' の
    //    ようにタグ名で限定し、div要素（誤った集約ID）を拾わないようにする。
    const NOSUBCAT_HEADING_SELECTOR = '.m-ctop-course-d-list__title--nosubcat';
    const NOSUBCAT_LIST_SELECTOR = '.m-ctop-course-d-list__list--nosubcat';
    const nosubcatResults = [];
    const headingEls = Array.from(document.querySelectorAll(NOSUBCAT_HEADING_SELECTOR));
    for (const headingEl of headingEls) {
      const categoryLabel = (headingEl.textContent || '').trim();
      const container = headingEl.closest('.m-ctop-course-d-list');
      if (!container) continue;
      const links = Array.from(
        container.querySelectorAll(`${NOSUBCAT_LIST_SELECTOR} a[href*="course/practice/index/id/"]`)
      );
      for (const link of links) {
        const subjectTitle = (link.textContent || '').trim();
        const href = link.getAttribute('href') || '';
        const m = href.match(/id\/(\d+)/);
        if (!m) continue;
        nosubcatResults.push({ category: categoryLabel, subject_title: subjectTitle, practice_id: m[1] });
      }
    }
    if (nosubcatResults.length === 0) {
      return { error: 'no-category-headings-found' };
    }
    return { items: nosubcatResults, errors: [], headingsFound: headingEls.length };
  }

  const isAfter = (a, b) => !!(a.compareDocumentPosition(b) & Node.DOCUMENT_POSITION_FOLLOWING);

  const results = [];
  const errors = [];

  for (let i = 0; i < headings.length; i++) {
    const { label, el: headingEl } = headings[i];
    const nextHeadingEl = headings[i + 1] ? headings[i + 1].el : null;

    const toggles = Array.from(document.querySelectorAll(TOGGLE_SELECTOR)).filter((t) => {
      if (!isAfter(headingEl, t)) return false;
      if (nextHeadingEl && !isAfter(t, nextHeadingEl)) return false;
      return true;
    });

    for (const toggle of toggles) {
      const nameEl = toggle.querySelector(NAME_SELECTOR);
      const subjectTitle = ((nameEl ? nameEl.textContent : toggle.textContent) || '').trim();
      try {
        toggle.click();
      } catch (e) {
        errors.push({ category: label, subjectTitle, error: 'click-failed' });
        continue;
      }

      // 🔴 クリック直後は展開アニメーションが未完了のため約500ms待機してから探索する
      await sleep(EXPAND_WAIT_MS);

      const li = toggle.closest('li');
      const link = li ? li.querySelector('a[href*="course/practice/index/id/"]') : null;
      if (!link) {
        errors.push({ category: label, subjectTitle, error: 'practice-link-not-found-after-click' });
        continue;
      }
      const href = link.getAttribute('href') || '';
      const m = href.match(/id\/(\d+)/);
      if (!m) {
        errors.push({ category: label, subjectTitle, error: 'practice-id-not-extracted', href });
        continue;
      }
      results.push({ category: label, subject_title: subjectTitle, practice_id: m[1] });
    }
  }

  return { items: results, errors, headingsFound: headings.length };
})()
JS

# --- 科目単位「解説一覧表示」ページの一括読み取り ---
# 🔴 実機確認済み（practice_id=223147〈スマート問題集・○×形式〉/223168〈セレクト過去問集・4択形式〉を
#    agent-browser で直接検証済み）:
#    - メタ情報のテキスト出現順は「N分 → N問 → 合格ライン...」（時間が先・問題数が後）。
#    - 問題ブロックは `.list_question`、解答ブロックは `.list_answer` が同数でインデックス対応する
#      （件数一致の探索は不要で、このクラス名を直接使える）。
#    - 4択形式: `.list_question ol.kanalist > li` が4件（選択肢本体）。マーカー文字「ア/イ/ウ/エ」は
#      CSS側で付与されテキストノードには含まれないため、出現順に機械的に割り当てる。○×形式は
#      `ol.kanalist` が存在しない（`.list_question` は `<div class="redactor-editor"><p>...</p></div>`
#      のみ）ため、`ol.kanalist` の有無で形式を判定する。
#    - 正解: `.list_answer` 側の `h4 .notosans-mark` の textContent がそのまま正解
#      （4択なら例 "ウ"・○×形式なら "○"/"×"）。文字列マッチングによる推定は不要。
#    - 各選択肢の解説: `.list_answer ol.kanalist > li`（`.list_question`側と同じ4件構造）。
#    - 学習のポイント: `.list_answer table.gakusyu` のテキスト。
# 🔴 未確認: セレクト過去問集（実技試験対策）は今回検証対象外（学科試験対策のみ検証済み）。
#    実技試験対策で `.list_question`/`.list_answer` 構造が異なる場合は INSTRUCTIONS.md §7 を参照して
#    調整する。
# 🔴 question/explanation は HTML保持で抽出する（実機確認済み: 「判例ビジュアルチェック200」等の
#    判例学習系コンテンツで <span class="span-bold">（太字強調）/<span class="span-square">
#    （空欄マーカー）/<br> 等の意味を持つHTML書式を確認したため。textContentでは失われる）。
#    Anki投入側 anki_toolkit.py は raw HTML 素通し設計のため studying_import.py 側の変更は不要。
cat > "${TMP_DIR}/read-practice-page.js" <<'JS'
(() => {
  function normWS(s) {
    return (s || '').replace(/[ \t]+/g, ' ').replace(/\s*\n\s*/g, '\n').trim();
  }

  // 🔴 実機確認済み（「判例ビジュアルチェック200」等の判例学習系コンテンツで確認）: 問題文・解説には
  //    <p>/<br>/<span class="span-bold">（重要語句の太字強調）/<span class="span-square">
  //    （空欄穴埋めマーカー）等のHTML書式が含まれ、これらは意味を持つ（強調箇所・空欄箇所の判別）。
  //    textContentで平坦化すると失われるため、question/explanation は sanitizeHtml() で
  //    HTML構造を保持したまま抽出する。Anki投入側の anki_toolkit.py は
  //    「back(解説)・front(問題文)は raw HTML を素通し（HTML-escapeしない）」設計のため、
  //    このまま Anki フィールドへ登録できる（studying_import.py・anki_toolkit.py の変更は不要）。
  // 🔴 クライアントサイドWebセキュリティレビュー指摘に基づき修正（多層防御）: 当初はブラック
  //    リスト方式（危険タグ・on*属性・javascript:スキームを列挙して除去）だったが、列挙漏れに
  //    弱く「HTMLが必要な場合は厳格な許可リストでサニタイズする」という原則に反するため、以下の
  //    厳格な許可リスト（allowlist）方式に全面書き換えした。
  //    - タグ: 許可リスト（ALLOWED_TAGS）に無いタグは中身（子要素・テキスト）を保持したまま
  //      タグ自体だけ除去（unwrap）する。ただし script/style/iframe 等の危険タグは
  //      REMOVE_ENTIRELY_SELECTOR で中身ごと完全除去する（unwrapしない）。
  //    - 属性: 要素ごとに許可リストを定義し、リスト外の属性（style 含む）は全て除去する。
  //      全要素共通で class のみ許可し、値は英数字・ハイフン・アンダースコア・空白のみの
  //      正規表現に一致する場合だけ保持する（それ以外の文字を含む場合は属性ごと除去）。
  //      img は src（絶対URL化は維持）・alt のみ、a は href（http/https スキームのみ）のみ許可。
  function sanitizeHtml(el) {
    if (!el) return '';
    const clone = el.cloneNode(true);

    // 🔴 危険タグは中身ごと完全除去する（unwrap対象外・タグも子孫も丸ごと削除）
    const REMOVE_ENTIRELY_SELECTOR =
      'script, style, iframe, object, embed, svg, math, form, input, button, textarea, select, link, meta';
    clone.querySelectorAll(REMOVE_ENTIRELY_SELECTOR).forEach((n) => n.remove());

    // 🔴 許可リスト（allowlist）: ここに無いタグは中身を保持したままタグ自体だけ除去（unwrap）する
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
      const keep = new Set(['class']); // 全要素共通の許可属性
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
      // href は http/https スキームのみ許可（javascript:/data:/vbscript: 等は除去）
      if (tag === 'a' && node.hasAttribute('href')) {
        const href = node.getAttribute('href') || '';
        if (!/^https?:\/\//i.test(href)) {
          node.removeAttribute('href');
        }
      }
      // src は javascript:/vbscript: スキームのみ拒否（data:/相対パス/http(s)は後続処理で扱う）
      if (tag === 'img' && node.hasAttribute('src')) {
        const src = node.getAttribute('src') || '';
        if (/^\s*(javascript|vbscript):/i.test(src)) {
          node.removeAttribute('src');
        }
      }
    }

    // 🔴 深い（子孫）要素から浅い（祖先）要素の順で処理する（querySelectorAllのdocumentOrderを
    //    reverseする）。unwrap時に子孫側の処理が既に完了していることを保証するため。
    const nodesDeepFirst = Array.from(clone.querySelectorAll('*')).reverse();
    for (const node of nodesDeepFirst) {
      if (!node.parentNode) continue; // 防御的チェック（通常は必ず親を持つ）
      const tag = node.tagName.toLowerCase();
      if (!ALLOWED_TAGS.has(tag)) {
        unwrap(node);
        continue;
      }
      filterAttributes(node);
    }

    // 🔴 実機確認済み: 解説内の <img src="skin/common/image/doc/..."> のような相対パス画像
    //    （UIアイコン等）は、抽出元ページのURLを離れるAnki上ではそのままだとリンク切れになる。
    //    document.baseURI を基準に絶対URL化してからHTML化する（data: スキームはそのまま）。
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

  const bodyText = document.body.innerText || '';

  // メタ情報: テキスト出現順は「N分 → N問 → 合格ライン...」（実機確認済み・時間が先）
  const metaMatch = bodyText.match(/([0-9]+)\s*分[^0-9]{0,30}([0-9]+)\s*問[^合]{0,30}合格ライン\s*([^\n]+)/);
  const total = metaMatch ? parseInt(metaMatch[2], 10) : null;
  const passLine = metaMatch ? metaMatch[3].trim() : '';

  const titleEl = document.querySelector('h1, h2');
  const subjectTitleFromPage = titleEl ? normWS(titleEl.textContent) : '';

  const qEls = Array.from(document.querySelectorAll('.list_question'));
  const aEls = Array.from(document.querySelectorAll('.list_answer'));

  if (qEls.length === 0) {
    return { error: 'question-blocks-not-found', total, passLine, subjectTitleFromPage };
  }

  const warnings = [];
  if (!total) {
    warnings.push({ warning: 'total-questions-metadata-not-found' });
  } else if (qEls.length !== total) {
    warnings.push({ warning: 'question-count-mismatch', total, found: qEls.length });
  }
  // メタ情報からの total 取得に失敗した場合は .list_question の実件数を採用する
  // （こちらの方が信頼性が高い一次情報のため）。
  const effectiveTotal = total || qEls.length;

  const LETTERS = ['ア', 'イ', 'ウ', 'エ'];
  const questions = [];

  qEls.forEach((qEl, idx) => {
    const aEl = aEls[idx];
    const questionEditor = qEl.querySelector('.redactor-editor');
    // 🔴 question は HTML保持（sanitizeHtml）で抽出する（textContentでは強調・空欄マーカーが失われるため）
    const question = sanitizeHtml(questionEditor || qEl);

    const markEl = aEl ? aEl.querySelector('h4 .notosans-mark') : null;
    const correctMark = markEl ? markEl.textContent.trim() : '';

    // 🔴 question_multi（複数空欄穴埋め形式・実機確認済み: 「判例ビジュアルチェック200」で
    //    全211問中約73%を占める形式）: `.notosans-mark` による単一正解が存在せず、代わりに
    //    aEl 配下の `.question_multi table tbody tr` に「Ａ・Ｂ・Ｃ…」のような複数空欄それぞれの
    //    正解（th=ラベル・td=正解テキスト）が並ぶ。行数は問題により2〜3行以上まで変動する
    //    （実機確認済み）。この形式では `.notosans-mark` が存在しないのが正常なため、
    //    `correct-mark-not-detected` 警告の判定からは除外する。
    const questionMulti = aEl ? aEl.querySelector('.question_multi') : null;

    if (!correctMark && !questionMulti) {
      warnings.push({ number: idx + 1, warning: 'correct-mark-not-detected' });
    }

    const kanalist = qEl.querySelector('ol.kanalist');
    // 🔴 kanalist を持たない設問の一部は table.transtable（空欄補充の組み合わせ選択等）で
    //    選択肢を表現する（実機確認済み）。この表はレター文字列（「ア.」等）が各行の最初の
    //    td に本物のテキストとして含まれるため、各 tr の全 td テキストを結合すれば
    //    レター込みの選択肢文になる（kanalist のような LETTERS 配列の割り当ては不要）。
    const transtable = kanalist ? null : qEl.querySelector('table.transtable');

    let choices = [];
    if (kanalist) {
      // 4択形式（マーカー文字はテキストノードに含まれないため出現順に ア/イ/ウ/エ を割り当てる）
      const qLis = Array.from(kanalist.querySelectorAll(':scope > li'));
      choices = qLis.map((li, i) => `${LETTERS[i] || String(i + 1)}. ${normWS(li.textContent)}`);
    } else if (transtable) {
      const rows = Array.from(transtable.querySelectorAll('tbody > tr'));
      choices = rows
        .map((tr) => Array.from(tr.querySelectorAll('td')).map((td) => normWS(td.textContent)).join(' ').trim())
        .filter(Boolean);
    }

    // 🔴 kanalist の有無だけで ○×/4択 を判定すると、kanalist（かつ transtable）を持たない
    //    特殊設問で「correct: ["ア"] なのに choice_type: "boolean"」という矛盾データが
    //    生成される不具合があった（実機確認済み）。優先順位: ①kanalist/transtable の
    //    いずれかがあれば "single"、②question_multi があれば "multi_blank"、③notosans-mark に
    //    値があり、その値が "○"/"×" なら "boolean"、④notosans-mark に値があり（○×以外の任意の
    //    単語・フレーズ）なら "fill_in_single"（単一空欄穴埋め形式）、⑤それ以外（本当にどの構造にも
    //    当てはまらない場合）のみ "unknown"。
    // 🔴 実機再調査で判明（practice_id=223631の7・8問目）: correctMark 自体は取得できているのに
    //    ○×以外の単語（例: 名詞・フレーズ）だと従来は "unknown" に落ちていた。これは第3の未知形式
    //    ではなく、"boolean" 判定条件（○/×限定）が厳しすぎたことが原因だったため、この優先順位に
    //    修正した。
    let choiceType;
    let multiBlankCorrect = null;
    if (kanalist || transtable) {
      choiceType = 'single';
    } else if (questionMulti) {
      // 🔴 question_multi: table tbody tr の各行（th=ラベル・td=正解テキスト）から
      //    "<ラベル>. <正解テキスト>" 形式の文字列を行ごとに1要素として correct に格納する。
      //    正解テキストにも太字強調等のHTML書式が含まれうるため sanitizeHtml() を通す
      //    （question/explanationと同じ扱い）。
      choiceType = 'multi_blank';
      const rows = Array.from(questionMulti.querySelectorAll('table tbody tr'));
      multiBlankCorrect = rows
        .map((tr) => {
          const thEl = tr.querySelector('th');
          const tdEl = tr.querySelector('td');
          const label = thEl ? normWS(thEl.textContent) : '';
          const value = tdEl ? sanitizeHtml(tdEl) : '';
          return label || value ? `${label}. ${value}`.trim() : '';
        })
        .filter(Boolean);
      if (multiBlankCorrect.length === 0) {
        warnings.push({ number: idx + 1, warning: 'multi-blank-rows-not-found' });
      }
    } else if (correctMark === '○' || correctMark === '×') {
      choiceType = 'boolean';
    } else if (correctMark) {
      // 🔴 fill_in_single: 単一の空欄に対する一問一答形式。kanalist/transtable/question_multiを
      //    持たず、notosans-mark の値が ○/× 以外の単語・フレーズの場合がこれに該当する。
      //    correct には既存ロジックのまま [correctMark] が入る（後続の共通処理で組み立てる）。
      //    choices は元々存在しないため空配列のまま。
      choiceType = 'fill_in_single';
    } else {
      choiceType = 'unknown';
      warnings.push({ number: idx + 1, warning: 'choice-structure-not-recognized', correctMark });
    }

    // 解説抽出: 現状は「kanalistがあればその内容、無ければ空」という設計だったが、
    //    次の優先順に汎用フォールバック化する（table.transtable形式は選択肢ごとの個別解説に
    //    分かれておらず、.redactor-editor 直下の<p>にまとまっているため実機確認済み）:
    //    1. aEl の ol.kanalist（既存動作・table.gakusyuがあれば末尾に結合）
    //    2. aEl の table.gakusyu（学習のポイントのみ）
    //    3. aEl の .redactor-editor 全文（上記どちらも無い場合のフォールバック）
    const aKanalist = aEl ? aEl.querySelector('ol.kanalist') : null;
    const gakusyuEl = aEl ? aEl.querySelector('table.gakusyu') : null;
    const aEditorEl = aEl ? aEl.querySelector('.redactor-editor') : null;

    // 🔴 explanation も HTML保持（sanitizeHtml）で抽出する（ユーザー要望: 解説のHTML構造を
    //    そのままAnki登録に使えるようにするため。区切りは textContent 版の '\n' 結合から
    //    HTML表示で改行として機能する '<br>' 結合に変更）
    let explanation = '';
    if (aKanalist) {
      const explSegments = Array.from(aKanalist.querySelectorAll(':scope > li')).map((li) => sanitizeHtml(li));
      const gakusyuText = gakusyuEl ? sanitizeHtml(gakusyuEl) : '';
      explanation = [explSegments.join('<br>'), gakusyuText].filter(Boolean).join('<br>');
    } else if (gakusyuEl) {
      explanation = sanitizeHtml(gakusyuEl);
    } else if (aEditorEl) {
      explanation = sanitizeHtml(aEditorEl);
    }

    // 🔴 multi_blank は複数空欄それぞれの正解一覧（multiBlankCorrect）を correct に格納する。
    //    それ以外の choice_type は従来通り単一の correctMark をそのまま使う。
    const correct = choiceType === 'multi_blank' ? (multiBlankCorrect || []) : (correctMark ? [correctMark] : []);

    questions.push({
      number: idx + 1,
      question,
      choice_type: choiceType,
      choices,
      correct,
      explanation,
    });
  });

  return { total: effectiveTotal, passLine, subjectTitleFromPage, questions, warnings };
})()
JS

# --- 認証（Auth Vault を第一候補、state save/load へフォールバック） ---
# 🔴 studying に専用ログインページ（/login/）が存在し（Whizlabsと異なりモーダル型ではない）、
#    通常表示のフォームとして input 要素が DOM に存在する。agent-browser の Auth Vault
#    （auth save/auth login）が機能する条件を満たしている可能性が高いが、実際に機能するかは
#    未検証のため、失敗時は通常フォーム入力 + state save/load にフォールバックする
#    （詳細: INSTRUCTIONS.md §3）。

is_logged_in() {
  local r
  r="$(ab eval --stdin < "${TMP_DIR}/check-login.js")" || return 1
  printf '%s' "${r}" | jq -e '.loggedIn' >/dev/null 2>&1
}

try_auth_vault() {
  log "[info] Auth Vault（プロファイル: ${STUDYING_AUTH_PROFILE}）でのログインを試行中..."
  if ! ab auth login "${STUDYING_AUTH_PROFILE}" >&2 2>&1; then
    log "[info] Auth Vault ログインに失敗しました（未登録の可能性）。通常フォーム入力にフォールバックします。"
    return 1
  fi
  ab open "${COURSE_URL}" >&2
  ab wait --load networkidle >&2
  if is_logged_in; then
    log "[info] Auth Vault からログイン状態を復元しました。"
    return 0
  fi
  log "[info] Auth Vault ログイン後もログイン状態を確認できませんでした。通常フォーム入力にフォールバックします。"
  return 1
}

perform_login_form() {
  log "[info] studying へログイン中（通常フォーム入力）..."
  : "${STUDYING_USERNAME:?エラー: STUDYING_USERNAME が未設定です（state/Auth Vault未確立時は必須）}"
  : "${STUDYING_PASSWORD:?エラー: STUDYING_PASSWORD が未設定です（state/Auth Vault未確立時は必須）}"

  local r
  ab open "${LOGIN_URL}" >&2
  ab wait --load networkidle >&2

  ab fill 'input[type="email"], input[name*="mail" i]' "${STUDYING_USERNAME}" >&2
  # 🔴 agent-browser fill はパスワードを標準入力ではなくコマンド引数として渡す仕様のため、
  #    ログ・シェルトレースへ出力しないこと（本スクリプトは set -x を使わない）。
  ab fill 'input[type="password"]' "${STUDYING_PASSWORD}" >&2

  r="$(ab eval --stdin < "${TMP_DIR}/click-login-link.js")"
  if ! printf '%s' "${r}" | jq -e '.ok' >/dev/null 2>&1; then
    log "エラー: 「ログインする」リンクが見つかりませんでした: ${r}"
    exit 1
  fi
  ab wait --load networkidle >&2

  if ! is_logged_in; then
    log "エラー: ログインに失敗した可能性があります。"
    exit 1
  fi

  mkdir -p "$(dirname "${STUDYING_STATE_FILE}")"
  ab state save "${STUDYING_STATE_FILE}" >&2
  log "[info] ログインに成功し state を保存しました: ${STUDYING_STATE_FILE}"
}

log "[info] studying 認証状態を確認中..."
LOGGED_IN=0
if [ -f "${STUDYING_STATE_FILE}" ]; then
  log "[info] 既存の state ファイルを読み込み中: ${STUDYING_STATE_FILE}"
  ab --state "${STUDYING_STATE_FILE}" open "${COURSE_URL}" >&2
  ab wait --load networkidle >&2
  if is_logged_in; then
    log "[info] state からログイン状態を復元しました。"
    LOGGED_IN=1
  fi
fi

if [ "${LOGGED_IN}" -eq 0 ]; then
  if try_auth_vault; then
    LOGGED_IN=1
    mkdir -p "$(dirname "${STUDYING_STATE_FILE}")"
    ab state save "${STUDYING_STATE_FILE}" >&2 || true
  else
    perform_login_form
    LOGGED_IN=1
  fi
fi
# 🔴 ログイン確立後は同一ブラウザプロセス内でログイン状態が保持されるため、
#    以降のコース一覧オープン・科目処理では再認証は不要。

# --- コーストップページの解析（科目トグル展開 + practice_id 一括収集） ---
log "[info] コース一覧を取得中: ${COURSE_URL}"
ab open "${COURSE_URL}" >&2
ab wait --load networkidle >&2

TITLE_JSON="$(ab eval --stdin < "${TMP_DIR}/get-course-title.js")"
COURSE_TITLE="$(printf '%s' "${TITLE_JSON}" | jq -r '.title // empty')"
[ -n "${COURSE_TITLE}" ] || COURSE_TITLE="course-${COURSE_ID}"

LINKS_JSON="$(ab eval --stdin < "${TMP_DIR}/collect-practice-links.js")"
if printf '%s' "${LINKS_JSON}" | jq -e '.error' >/dev/null 2>&1; then
  log "エラー: コース一覧から科目セクションを検出できませんでした: ${LINKS_JSON}"
  log "サイトのDOM構造が変わった可能性があります。collect-practice-links.js のセレクタを調整してください。"
  exit 1
fi

ITEM_COUNT="$(printf '%s' "${LINKS_JSON}" | jq '.items | length')"
ERROR_COUNT="$(printf '%s' "${LINKS_JSON}" | jq '.errors | length')"
if [ "${ERROR_COUNT}" -gt 0 ]; then
  log "[warn] 科目トグルの展開/収集に失敗した項目が ${ERROR_COUNT} 件あります: $(printf '%s' "${LINKS_JSON}" | jq -c '.errors')"
fi
if [ "${ITEM_COUNT}" -eq 0 ]; then
  log "エラー: 収集対象の科目が0件でした（トグル展開ロジックの調整が必要な可能性があります）。"
  exit 1
fi

log "[info] ${COURSE_TITLE}: ${ITEM_COUNT} 件の科目を検出しました。"

COURSE_SLUG="$(sanitize_jp "${COURSE_TITLE}")"
[ -n "${COURSE_SLUG}" ] || COURSE_SLUG="course-${COURSE_ID}"

# --- 科目ごとに収集（1件の失敗で全体を止めず、スキップして継続する） ---
SUBJECT_OK=0
SUBJECT_FAIL=0
SUBJECT_INDEX=0
PROCESS_LIMIT="${ITEM_COUNT}"
if [ "${STUDYING_MAX_N}" -gt 0 ] 2>/dev/null && [ "${STUDYING_MAX_N}" -lt "${ITEM_COUNT}" ]; then
  PROCESS_LIMIT="${STUDYING_MAX_N}"
  log "[info] STUDYING_MAX_N=${STUDYING_MAX_N} のため先頭 ${PROCESS_LIMIT} 件のみ処理します（スモークテスト）。"
fi

while [ "${SUBJECT_INDEX}" -lt "${PROCESS_LIMIT}" ]; do
  ITEM_JSON="$(printf '%s' "${LINKS_JSON}" | jq -c --argjson i "${SUBJECT_INDEX}" '.items[$i]')"
  CATEGORY="$(printf '%s' "${ITEM_JSON}" | jq -r '.category')"
  SUBJECT_TITLE="$(printf '%s' "${ITEM_JSON}" | jq -r '.subject_title')"
  PRACTICE_ID="$(printf '%s' "${ITEM_JSON}" | jq -r '.practice_id')"

  if [ "${SUBJECT_INDEX}" -gt 0 ]; then
    sleep "${WAIT_SEC}"
  fi

  PRACTICE_URL="${BASE_URL}/course/practice/list/id/${PRACTICE_ID}/a/on/"
  log "[info] 科目処理開始: [${CATEGORY}] ${SUBJECT_TITLE} (practice_id=${PRACTICE_ID})"

  ab open "${PRACTICE_URL}" >&2 || true
  ab wait --load networkidle >&2 || true

  PAGE_JSON="$(ab eval --stdin < "${TMP_DIR}/read-practice-page.js")" || {
    log "[warn] ${SUBJECT_TITLE}: ページ読み取りに失敗しました。"
    SUBJECT_FAIL=$((SUBJECT_FAIL + 1))
    SUBJECT_INDEX=$((SUBJECT_INDEX + 1))
    continue
  }

  if printf '%s' "${PAGE_JSON}" | jq -e '.error' >/dev/null 2>&1; then
    log "[warn] ${SUBJECT_TITLE}: 問題データを抽出できませんでした: ${PAGE_JSON}"
    SUBJECT_FAIL=$((SUBJECT_FAIL + 1))
    SUBJECT_INDEX=$((SUBJECT_INDEX + 1))
    continue
  fi

  WARN_COUNT="$(printf '%s' "${PAGE_JSON}" | jq '.warnings | length')"
  if [ "${WARN_COUNT}" -gt 0 ]; then
    log "[warn] ${SUBJECT_TITLE}: 抽出時に ${WARN_COUNT} 件の警告があります: $(printf '%s' "${PAGE_JSON}" | jq -c '.warnings')"
  fi

  TOTAL="$(printf '%s' "${PAGE_JSON}" | jq -r '.total')"
  PASS_LINE="$(printf '%s' "${PAGE_JSON}" | jq -r '.passLine')"
  QUESTIONS_JSON="$(printf '%s' "${PAGE_JSON}" | jq -c '.questions')"

  CATEGORY_SLUG="$(sanitize_jp "${CATEGORY}")"
  [ -n "${CATEGORY_SLUG}" ] || CATEGORY_SLUG="category-$((SUBJECT_INDEX))"
  SUBJECT_SLUG="$(sanitize_jp "${SUBJECT_TITLE}")"
  [ -n "${SUBJECT_SLUG}" ] || SUBJECT_SLUG="practice-${PRACTICE_ID}"

  JSON_FILE="${OUTPUT_DIR}/${COURSE_SLUG}__${CATEGORY_SLUG}__${SUBJECT_SLUG}.json"
  COLLECTED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  jq -n \
    --arg course_title "${COURSE_TITLE}" \
    --arg course_url "${COURSE_URL}" \
    --arg category "${CATEGORY}" \
    --arg subject_title "${SUBJECT_TITLE}" \
    --arg practice_id "${PRACTICE_ID}" \
    --arg collected_at "${COLLECTED_AT}" \
    --argjson total_questions "${TOTAL}" \
    --arg pass_line "${PASS_LINE}" \
    --argjson questions "${QUESTIONS_JSON}" \
    '{
       course_title: $course_title,
       course_url: $course_url,
       category: $category,
       subject_title: $subject_title,
       practice_id: $practice_id,
       collected_at: $collected_at,
       total_questions: $total_questions,
       pass_line: $pass_line,
       questions: ($questions | sort_by(.number))
     }' > "${JSON_FILE}"

  SUBJECT_OK=$((SUBJECT_OK + 1))
  log "[done] [${CATEGORY}] ${SUBJECT_TITLE}: ${JSON_FILE} を生成しました（${TOTAL}問）。"

  SUBJECT_INDEX=$((SUBJECT_INDEX + 1))
done

ab close >&2 || true
log "[done] ${COURSE_TITLE}: 対象 ${PROCESS_LIMIT} 件中 ${SUBJECT_OK} 件成功・${SUBJECT_FAIL} 件失敗。出力先: ${OUTPUT_DIR}"
