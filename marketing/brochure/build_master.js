// Builds the 22-page partner brochure:
//   out/waddy-partner-brochure.{html,pdf}
//   out/master_dom.json + out/raster/*  -> consumed by make_pptx.py for the PPTX
//   node build_master.js           draft (status chips shown in the footer)
//   FINAL=1 node build_master.js   hides the status chips for print
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const ROOT = path.resolve(__dirname, '../..');
const OUT = path.join(__dirname, 'out');
const RAS = path.join(OUT, 'raster');
const asset = (f) => 'file://' + path.join(__dirname, 'assets', f);
const sub = (s) => s.replace(/FONT\(([^)]+)\)/g, (_, f) => 'file://' + path.join(ROOT, 'assets/font', f));
const css = sub(fs.readFileSync(path.join(__dirname, 'style.css'), 'utf8')) + fs.readFileSync(path.join(__dirname, 'master.css'), 'utf8');

const ICONS = require('./icons');
const icon = (n, s = 22) => `<svg class="ic" width="${s}" height="${s}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${ICONS[n] || ''}</svg>`;

const { pages, STATUS } = require('./master')(icon, asset);
const NAME = 'waddy-partner-brochure';

const body = pages.map((p, i) => {
  const foot = i === 0 ? '' : `<footer><img src="${asset(p.tone === 'teal' ? 'w_mint.png' : 'w_teal.png')}"><span>Waddy · Partner brochure</span>${p.status ? `<span class="status ${p.status}">${STATUS[p.status]}</span>` : ''}<b>${String(i + 1).padStart(2, '0')}</b></footer>`;
  return `<section class="slide m ${p.tone} ${p.cls}">${p.html}${foot}</section>`;
}).join('\n');
const html = `<!doctype html><html lang="en"><head><meta charset="utf-8"><title>Waddy Partner Brochure</title><style>${css}
body.capmode * { visibility: hidden !important; } body.capmode .capt, body.capmode .capt * { visibility: visible !important; }
</style></head><body class="${process.env.FINAL ? 'final' : ''}">${body}</body></html>`;

// Runs in the page: turns each slide into boxes, text blocks and raster slots.
function extract() {
  const rgba = (c) => { const m = c.match(/[\d.]+/g); return m ? { r: +m[0], g: +m[1], b: +m[2], a: m[3] === undefined ? 1 : +m[3] } : null; };
  let rid = 0;
  return [...document.querySelectorAll('.slide')].map((s) => {
    const o = s.getBoundingClientRect();
    const box = (r) => ({ x: r.left - o.left, y: r.top - o.top, w: r.width, h: r.height });
    const items = [];
    const walk = (el) => {
      const cs = getComputedStyle(el);
      if (cs.display === 'none') return;
      const r = el.getBoundingClientRect();
      if (el.hasAttribute('data-raster') || el.tagName === 'svg' || el.tagName === 'IMG') {
        el.dataset.rid = ++rid; items.push({ t: 'img', id: rid, ...box(r) }); return;
      }
      const bg = rgba(cs.backgroundColor), bw = parseFloat(cs.borderTopWidth), bc = rgba(cs.borderTopColor);
      const hasBorder = bw > 0 && cs.borderTopStyle !== 'none' && bc && bc.a > 0;
      if ((bg && bg.a > 0) || hasBorder) items.push({ t: 'rect', ...box(r), fill: bg && bg.a > 0 ? bg : null, line: hasBorder ? bc : null, lw: bw, rad: parseFloat(cs.borderTopLeftRadius) || 0 });
      const direct = [...el.childNodes].some((n) => n.nodeType === 3 && n.textContent.trim());
      if (!direct) { [...el.children].forEach(walk); return; }
      const runs = [];
      const tw = document.createTreeWalker(el, NodeFilter.SHOW_TEXT | NodeFilter.SHOW_ELEMENT);
      let n;
      // Headlines carry the browser's own line breaks into PowerPoint, so a
      // font-metric difference can't re-wrap them. Body copy is left to wrap.
      const lock = parseFloat(cs.fontSize) >= 26;
      let lastTop = null;
      while ((n = tw.nextNode())) {
        if (n.nodeType === 1) { if (n.tagName === 'BR') { runs.push({ br: 1 }); lastTop = null; } continue; }
        const ps = getComputedStyle(n.parentElement);
        const hl = rgba(ps.backgroundColor);
        const base = { c: rgba(ps.color), fw: +ps.fontWeight, fs: parseFloat(ps.fontSize), ff: ps.fontFamily.split(',')[0].replace(/"/g, ''), ls: parseFloat(ps.letterSpacing) || 0, hl: n.parentElement !== el && hl && hl.a > 0 ? hl : null };
        const fix = (t) => { t = t.replace(/\s+/g, ' '); return ps.textTransform === 'uppercase' ? t.toUpperCase() : t; };
        if (!lock) { const tx = fix(n.textContent); if (tx) runs.push({ tx, ...base }); continue; }
        let buf = '';
        for (const m of n.textContent.matchAll(/\S+\s*|\s+/g)) {
          if (m[0].trim()) {
            const wr = document.createRange(); wr.setStart(n, m.index); wr.setEnd(n, m.index + m[0].trimEnd().length);
            const top = wr.getBoundingClientRect().top;
            if (lastTop !== null && top > lastTop + base.fs * 0.5) { if (buf) runs.push({ tx: fix(buf).replace(/ $/, ''), ...base }); buf = ''; runs.push({ br: 1 }); }
            lastTop = top;
          }
          buf += m[0];
        }
        if (fix(buf)) runs.push({ tx: fix(buf), ...base });
      }
      const first = runs.find((q) => q.tx), last = [...runs].reverse().find((q) => q.tx);
      if (first) first.tx = first.tx.replace(/^ /, '');
      if (last) last.tx = last.tx.replace(/ $/, '');
      const rg = document.createRange(); rg.selectNodeContents(el);
      const tops = new Set([...rg.getClientRects()].map((q) => Math.round(q.top / 6)));
      const rr = rg.getBoundingClientRect();
      const pl = parseFloat(cs.paddingLeft), pr = parseFloat(cs.paddingRight);
      const multi = !lock && tops.size > 1;
      const br = runs.some((q) => q.br);
      const centered = cs.textAlign === 'center' || (cs.display.includes('flex') && cs.justifyContent === 'center');
      items.push({ t: 'text', runs, lh: parseFloat(cs.lineHeight) || parseFloat(cs.fontSize) * 1.2, multi, al: centered ? 'c' : 'l',
        ...(multi || br ? { x: r.left - o.left + pl, y: rr.top - o.top, w: r.width - pl - pr, h: rr.height }
                  : { x: rr.left - o.left, y: rr.top - o.top, w: rr.width, h: rr.height }) });
    };
    [...s.children].forEach(walk);
    return { bg: rgba(getComputedStyle(s).backgroundColor), items };
  });
}

(async () => {
  fs.mkdirSync(RAS, { recursive: true });
  const file = path.join(OUT, NAME + '.html');
  fs.writeFileSync(file, html);
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 }, deviceScaleFactor: 2 });
  await page.goto('file://' + file);
  await page.evaluate(() => document.fonts.ready);

  const over = await page.evaluate(() => [...document.querySelectorAll('.slide')].map((s, i) => {
    const p = s.getBoundingClientRect();
    const bad = [...s.querySelectorAll('h1,h2,p,li,b,dd,.note,.rw,.hf,.pillar,.camp,.vert,.cmp>div,.terms>div,.phone,.qr,.win')].filter((e) => {
      if (e.closest('footer')) return false;
      const r = e.getBoundingClientRect();
      return r.bottom > p.bottom - 44 || r.right > p.right - 20 || r.top < p.top + 8;
    });
    return bad.length ? `page ${i + 1}: ${bad.length} out of bounds (${bad[0].className || bad[0].tagName})` : null;
  }).filter(Boolean));
  if (over.length) console.log(over.join('\n'));

  await page.pdf({ path: path.join(OUT, NAME + '.pdf'), width: '1280px', height: '720px', printBackground: true });

  fs.writeFileSync(path.join(OUT, 'master_dom.json'), JSON.stringify(await page.evaluate(extract)));

  // each raster is captured alone, on a transparent background
  await page.evaluate(() => document.body.classList.add('capmode'));
  const els = await page.$$('[data-rid]');
  for (const el of els) {
    const id = await el.getAttribute('data-rid');
    await el.evaluate((e) => e.classList.add('capt'));
    await el.screenshot({ path: path.join(RAS, id + '.png'), omitBackground: true });
    await el.evaluate((e) => e.classList.remove('capt'));
  }
  await browser.close();
  console.log(`built ${NAME}: ${pages.length} pages, ${els.length} rasters`);
})();
