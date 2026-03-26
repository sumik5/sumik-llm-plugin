/**
 * engine/slide.js — コアエンジン層（編集不要）
 * キーボード操作 / クリックナビ / フルスクリーン / ビューポートスケーリング / PDF書き出し
 */
(() => {
  const slides = () => [...document.querySelectorAll('.slide')];
  let cur = 0;

  function show(n) {
    const all = slides();
    cur = Math.max(0, Math.min(n, all.length - 1));
    all.forEach((s, i) => s.classList.toggle('is-active', i === cur));
    const el = document.querySelector('.slide-counter');
    if (el) el.textContent =
      `${String(cur + 1).padStart(2, '0')} / ${String(all.length).padStart(2, '0')}`;
  }

  const next = () => show(cur + 1);
  const prev = () => show(cur - 1);

  // ── キーボード ──
  document.addEventListener('keydown', e => {
    if (['ArrowRight', 'ArrowDown', ' '].includes(e.key)) { e.preventDefault(); next(); }
    if (['ArrowLeft', 'ArrowUp'].includes(e.key))         { e.preventDefault(); prev(); }
    if (e.key === 'f' || e.key === 'F')                   { toggleFullscreen(); }
  });

  // ── デッキクリック（左半分=前、右半分=次）──
  document.querySelector('.deck')?.addEventListener('click', e => {
    if (e.target.closest('.slide-ui')) return;
    const deck = document.querySelector('.deck');
    const rect = deck.getBoundingClientRect();
    const clickX = e.clientX - rect.left;
    if (clickX < rect.width / 2) {
      prev();
    } else {
      next();
    }
  });

  // ── ナビボタン ──
  document.getElementById('btn-prev')?.addEventListener('click', prev);
  document.getElementById('btn-next')?.addEventListener('click', next);
  document.getElementById('btn-fs')?.addEventListener('click', toggleFullscreen);
  document.getElementById('btn-pdf')?.addEventListener('click', exportPDF);

  // ── フルスクリーン ──
  function toggleFullscreen() {
    if (!document.fullscreenElement) {
      document.documentElement.requestFullscreen().catch(() => {});
    } else {
      document.exitFullscreen();
    }
  }

  // ── PDF書き出し ──
  function exportPDF() {
    const params = new URLSearchParams(window.location.search);
    const scale = parseFloat(params.get('print-scale')) || 100;

    if (scale !== 100) {
      const factor = scale / 100;
      const style = document.createElement('style');
      style.id = 'print-scale-override';
      style.textContent = `
        @media print {
          @page { size: ${254 * factor}mm ${142.875 * factor}mm; }
          .slide { transform: scale(${factor}); transform-origin: top left; }
        }
      `;
      document.head.appendChild(style);
      requestAnimationFrame(() => {
        window.print();
        const el = document.getElementById('print-scale-override');
        if (el) el.remove();
      });
    } else {
      window.print();
    }
  }

  // ── ビューポートに合わせてスケーリング ──
  function scaleDeck() {
    const deck = document.querySelector('.deck');
    if (!deck) return;
    const scale = Math.min(window.innerWidth / 1280, window.innerHeight / 720);
    deck.style.transform = `scale(${scale})`;
  }

  // ── 外部API ──
  window.__slideShow = show;

  // ── URLハッシュ連動 ──
  function updateHash() {
    const deck = document.querySelector('.deck');
    if (!deck) return;
    const active = deck.querySelector('.slide.is-active');
    if (!active) return;
    const idx = [...deck.querySelectorAll('.slide')].indexOf(active);
    const newHash = '#' + (idx + 1);
    if (location.hash !== newHash) {
      history.replaceState(null, '', newHash);
    }
  }

  // ── セグメント式進捗インジケータ（オプション） ──
  // _foot.html 等から window.__initProgressBar(segments) を呼び出して有効化
  window.__initProgressBar = function(segments) {
    const bar = document.getElementById('progress-bar');
    const deck = document.querySelector('.deck');
    if (!bar || !deck) return;

    segments.forEach(seg => {
      const el = document.createElement('div');
      el.className = 'progress-seg';
      el.style.flex = (seg.end - seg.start + 1) + '';
      el.title = seg.label;
      const fill = document.createElement('div');
      fill.className = 'progress-seg-fill';
      el.appendChild(fill);
      const lbl = document.createElement('span');
      lbl.className = 'progress-seg-label';
      lbl.textContent = seg.label;
      el.appendChild(lbl);
      el.style.cursor = 'pointer';
      el.addEventListener('click', () => show(seg.start));
      bar.appendChild(el);
      seg.el = el;
      seg.fill = fill;
      seg.lbl = lbl;
    });

    function updateProgress() {
      const active = deck.querySelector('.slide.is-active');
      if (!active) return;
      const idx = [...deck.querySelectorAll('.slide')].indexOf(active);
      const total = deck.querySelectorAll('.slide').length;

      segments.forEach(seg => {
        seg.el.classList.remove('done', 'active');
        if (idx > seg.end) {
          seg.el.classList.add('done');
          seg.fill.style.width = '100%';
          seg.lbl.textContent = seg.label;
        } else if (idx >= seg.start) {
          seg.el.classList.add('active');
          const pct = ((idx - seg.start + 1) / (seg.end - seg.start + 1)) * 100;
          seg.fill.style.width = pct + '%';
          seg.lbl.textContent = seg.label + ' [' + (idx + 1) + '/' + total + ']';
        } else {
          seg.fill.style.width = '0%';
          seg.lbl.textContent = seg.label;
        }
      });
    }

    return updateProgress;
  };

  // ── スライド変更の監視・ハッシュ更新 ──
  const deck = document.querySelector('.deck');
  if (deck) {
    const observer = new MutationObserver(() => {
      updateHash();
      if (window.__updateProgress) window.__updateProgress();
    });
    deck.querySelectorAll('.slide').forEach(s => {
      observer.observe(s, { attributes: true, attributeFilter: ['class'] });
    });
  }

  // ── ビューポートスケーリング ──
  window.addEventListener('resize', scaleDeck);
  scaleDeck();
  show(0);

  // ── ページロード時: ハッシュからスライド復元 ──
  const hash = parseInt(location.hash.replace('#', ''), 10);
  if (hash > 1 && hash <= slides().length) {
    show(hash - 1);
  }
})();
