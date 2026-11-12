// Builds every brochure edition in English and Arabic.
//
//   node build.js                 all editions, both languages
//   node build.js grocery ar short  one edition / language / length (any may be omitted)
//   FINAL=1 node build.js         hide the internal status chips for print
//
// Per edition it writes out/<name>.pdf, plus out/dom/<name>.json and
// out/raster/<name>/ which make_pptx.py turns into the PowerPoint.
// Arabic is produced by translating the English page in the browser
// (ar.js maps each English text node to its Arabic), then laying it out RTL.
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const ROOT = path.resolve(__dirname, '../..');
const OUT = path.join(__dirname, 'out');
const asset = (f) => 'file://' + path.join(__dirname, 'assets', f);
const css = fs.readFileSync(path.join(__dirname, 'style.css'), 'utf8').replace(/FONT\(([^)]+)\)/g, (_, f) => 'file://' + path.join(ROOT, 'assets/font', f))
  + fs.readFileSync(path.join(__dirname, 'master.css'), 'utf8');

const ICONS = require('./icons');
const icon = (n, s = 22) => `<svg class="ic" width="${s}" height="${s}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${ICONS[n] || ''}</svg>`;
const master = require('./master');
const AR = fs.existsSync(path.join(__dirname, 'ar.js')) ? require('./ar') : {};
// Confirmed terms carry their own Arabic.
const TERMS = require('./terms');
for (const t of Object.values(TERMS)) if (t && t.en && t.ar) AR[t.en] = t.ar;
// A WhatsApp number becomes a scannable wa.me QR on the join page.
if (TERMS.whatsapp) {
  const digits = TERMS.whatsapp.en.replace(/\D/g, '');
  require('child_process').execFileSync('python3', ['-c',
    `import qrcode;q=qrcode.QRCode(border=0,box_size=12);q.add_data('https://wa.me/${digits}');q.make();q.make_image(fill_color='#134E4A',back_color='white').save('${path.join(__dirname, 'assets', 'qr_whatsapp.png')}')`]);
}

function render(edition, length) {
  const { pages, STATUS, label, file } = master(icon, asset, edition, length);
  const body = pages.map((p, i) => {
    const foot = i === 0 ? '' : `<footer><img src="${asset(p.tone === 'teal' ? 'w_mint.png' : 'w_teal.png')}"><span>Waddy · ${label}</span>${p.status ? `<span class="status ${p.status}">${STATUS[p.status]}</span>` : ''}<b>${String(i + 1).padStart(2, '0')}</b></footer>`;
    return `<section class="slide m ${p.tone} ${p.cls}">${p.html}${foot}</section>`;
  }).join('\n');
  return { file, html: `<!doctype html><html lang="en"><head><meta charset="utf-8"><title>Waddy · ${label}</title><style>${css}
body.capmode * { visibility: hidden !important; } body.capmode .capt, body.capmode .capt * { visibility: visible !important; }
</style></head><body class="${process.env.FINAL ? 'final' : ''}">${body}</body></html>` };
}

// In the page: every text node, normalised. With a dictionary, translate in place.
function texts(dict) {
  const skip = (t) => !/[A-Za-z]{2}/.test(t);
  const seen = [], missing = [];
  const tw = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
  let n;
  while ((n = tw.nextNode())) {
    if (n.parentElement.closest('style,script')) continue;
    const key = n.textContent.replace(/\s+/g, ' ').trim();
    if (!key || (skip(key) && !(dict && dict[key] !== undefined))) continue;
    seen.push(key);
    if (!dict) continue;
    if (dict[key] === undefined) { missing.push(key); continue; }
    const lead = /^\s/.test(n.textContent) ? ' ' : '', trail = /\s$/.test(n.textContent) ? ' ' : '';
    n.textContent = lead + dict[key] + trail;
  }
  if (dict) { document.documentElement.dir = 'rtl'; document.documentElement.lang = 'ar'; document.body.classList.add('rtl'); }
  return { seen, missing };
}

// In the page: turn each slide into boxes, text blocks and raster slots.
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
      // Headlines carry the browser's own line breaks into PowerPoint, so a
      // font-metric difference can't re-wrap them. Body copy is left to wrap.
      const lock = parseFloat(cs.fontSize) >= 26;
      let lastTop = null, n;
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
      const rtl = cs.direction === 'rtl';
      const centered = cs.textAlign === 'center' || (cs.display.includes('flex') && cs.justifyContent === 'center');
      items.push({ t: 'text', runs, lh: parseFloat(cs.lineHeight) || parseFloat(cs.fontSize) * 1.2, multi, rtl, al: centered ? 'c' : (rtl ? 'r' : 'l'),
        ...(multi || br ? { x: r.left - o.left + pl, y: rr.top - o.top, w: r.width - pl - pr, h: rr.height }
                        : { x: rr.left - o.left, y: rr.top - o.top, w: rr.width, h: rr.height }) });
    };
    [...s.children].forEach(walk);
    return { bg: rgba(getComputedStyle(s).backgroundColor), items };
  });
}

function bounds() {
  return [...document.querySelectorAll('.slide')].map((s, i) => {
    const p = s.getBoundingClientRect();
    const bad = [...s.querySelectorAll('h1,h2,p,li,b,dd,.note,.rw,.hf,.pillar,.camp,.vert,.cmp>div,.terms>div,.phone,.qr,.win,.chips')].filter((e) => {
      if (e.closest('footer') || e.closest('[data-raster]')) return false;
      const r = e.getBoundingClientRect();
      return r.bottom > p.bottom - 44 || r.right > p.right - 20 || r.left < p.left + 20 || r.top < p.top + 8;
    });
    return bad.length ? `page ${i + 1}: ${bad.length} out of bounds (${bad[0].className || bad[0].tagName})` : null;
  }).filter(Boolean);
}

(async () => {
  const args = process.argv.slice(2);
  const langs = args.includes('ar') ? ['ar'] : args.includes('en') ? ['en'] : ['en', 'ar'];
  const all = master(icon, asset, 'all').editions;
  const editions = all.filter((e) => args.includes(e)).length ? all.filter((e) => args.includes(e)) : all;
  for (const d of ['dom', 'raster']) fs.mkdirSync(path.join(OUT, d), { recursive: true });
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 }, deviceScaleFactor: 2 });
  const strings = new Set(), untranslated = new Set();

  const lengths = args.includes('short') ? ['short'] : args.includes('full') ? ['full'] : ['full', 'short'];
  for (const edition of editions) for (const length of lengths) {
    const { file, html } = render(edition, length);
    const src = path.join(OUT, file + '.html');
    fs.writeFileSync(src, html);
    for (const lang of langs) {
      const name = lang === 'ar' ? file + '-ar' : file;
      await page.goto('file://' + src);
      const { seen, missing } = await page.evaluate(texts, lang === 'ar' ? AR : null);
      seen.forEach((t) => strings.add(t)); missing.forEach((t) => untranslated.add(t));
      await page.evaluate(() => document.fonts.ready);
      const over = await page.evaluate(bounds);
      if (over.length) console.log(name + '\n  ' + over.join('\n  '));
      await page.pdf({ path: path.join(OUT, name + '.pdf'), width: '1280px', height: '720px', printBackground: true });

      fs.writeFileSync(path.join(OUT, 'dom', name + '.json'), JSON.stringify(await page.evaluate(extract)));
      const ras = path.join(OUT, 'raster', name);
      fs.mkdirSync(ras, { recursive: true });
      await page.evaluate(() => document.body.classList.add('capmode'));
      for (const el of await page.$$('[data-rid]')) {
        const id = await el.getAttribute('data-rid');
        await el.evaluate((e) => e.classList.add('capt'));
        await el.screenshot({ path: path.join(ras, id + '.png'), omitBackground: true });
        await el.evaluate((e) => e.classList.remove('capt'));
      }
      console.log('built', name);
    }
  }
  await browser.close();
  fs.writeFileSync(path.join(OUT, 'strings.json'), JSON.stringify([...strings], null, 1));
  if (untranslated.size) {
    fs.writeFileSync(path.join(OUT, 'untranslated.json'), JSON.stringify([...untranslated], null, 1));
    console.log(`${untranslated.size} strings have no Arabic yet -> out/untranslated.json`);
  }
})();
