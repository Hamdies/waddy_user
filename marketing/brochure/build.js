// Builds the three Waddy merchant brochures (restaurants, grocers, pet shops).
//   node marketing/brochure/build.js
// Writes out/<deck>.html and out/<deck>.pdf. Copy lives in decks.js.
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');
const { decks, CONTACT } = require('./decks');
const mock = require('./mockups');

const ROOT = path.resolve(__dirname, '../..');
const OUT = path.join(__dirname, 'out');
const font = (f) => 'file://' + path.join(ROOT, 'assets/font', f);
const asset = (f) => 'file://' + path.join(__dirname, 'assets', f);

const ICONS = require('./icons');
const icon = (n, s = 22) =>
  `<svg class="ic" width="${s}" height="${s}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${ICONS[n] || ''}</svg>`;

const css = fs.readFileSync(path.join(__dirname, 'style.css'), 'utf8')
  .replace(/FONT\(([^)]+)\)/g, (_, f) => font(f))
  .replace(/ASSET\(([^)]+)\)/g, (_, f) => asset(f));

// ── slide renderers ─────────────────────────────────────────────────────────
const R = {
  cover: (s, d) => `
    <section class="slide mint cover">
      <div class="brand"><img src="${asset('w_teal.png')}"><span>Waddy</span><i>${d.audience}</i></div>
      <div class="cover-copy">
        <div class="kicker">${s.kicker}</div>
        <h1>${s.title}</h1>
        <p class="lede">${s.lede}</p>
        <div class="chips">${s.chips.map((c) => `<span>${c}</span>`).join('')}</div>
      </div>
      <div class="cover-art"><div class="blob"></div><img src="${asset(s.art)}"></div>
    </section>`,

  who: (s) => `
    <section class="slide teal who">
      <div class="eyebrow">${s.eyebrow}</div>
      <h2>${s.title}</h2>
      <p class="lede">${s.lede}</p>
      <div class="who-grid">${s.facts.map((f) => `
        <div class="fact"><b>${f.h}</b><p>${f.p}</p></div>`).join('')}
      </div>
      <img class="wm" src="${asset('w_mint.png')}">
    </section>`,

  problem: (s) => `
    <section class="slide paper problem">
      <div class="eyebrow coral">${s.eyebrow}</div>
      <h2>${s.title}</h2>
      <div class="pains">${s.pains.map((p, i) => `
        <div class="pain"><span class="n">0${i + 1}</span><b>${p.h}</b><p>${p.p}</p></div>`).join('')}
      </div>
      <div class="turn">${icon('bolt', 20)}<span>${s.turn}</span></div>
    </section>`,

  feature: (s) => `
    <section class="slide ${s.tone || 'paper'} feature ${s.flip ? 'flip' : ''}">
      <div class="f-copy">
        <div class="eyebrow">${s.eyebrow}</div>
        <h2>${s.title}</h2>
        <p class="lede">${s.lede}</p>
        <ul class="points">${s.points.map((p) => `
          <li><span class="pi">${icon(p.i)}</span><div><b>${p.h}</b><p>${p.p}</p></div></li>`).join('')}
        </ul>
        ${s.win ? `<div class="win"><em>What it does for you</em>${s.win}</div>` : ''}
      </div>
      <div class="f-art">${mock[s.mock](icon)}</div>
    </section>`,

  tiles: (s) => `
    <section class="slide ${s.tone || 'tint'} tiles">
      <div class="eyebrow">${s.eyebrow}</div>
      <h2>${s.title}</h2>
      <p class="lede">${s.lede}</p>
      <div class="tile-grid n${s.items.length}">${s.items.map((t) => `
        <div class="tile"><span class="ti">${icon(t.i, 24)}</span><b>${t.h}</b><p>${t.p}</p></div>`).join('')}
      </div>
    </section>`,

  moves: (s) => `
    <section class="slide teal moves">
      <div class="eyebrow">${s.eyebrow}</div>
      <h2>${s.title}</h2>
      <div class="move-row">${s.moves.map((m, i) => `
        <div class="move">
          <div class="mh"><span class="mn">${i + 1}</span>${icon(m.i, 26)}</div>
          <b>${m.h}</b><p>${m.p}</p>
          <ul>${m.tools.map((t) => `<li>${t}</li>`).join('')}</ul>
        </div>`).join('<div class="arrow">→</div>')}
      </div>
    </section>`,

  cta: (s, d) => `
    <section class="slide mint cta">
      <div class="cta-copy">
        <div class="eyebrow">${s.eyebrow}</div>
        <h2>${s.title}</h2>
        <div class="steps">${s.steps.map((st, i) => `
          <div class="step"><span>${i + 1}</span><div><b>${st.h}</b><p>${st.p}</p></div></div>`).join('')}
        </div>
      </div>
      <div class="card">
        <img src="${asset('w_mint.png')}">
        <b>${s.cardTitle}</b>
        <p>${s.cardBody}</p>
        ${CONTACT.map((c) => `<div class="line"><i>${c.label}</i><span>${c.value || ''}</span></div>`).join('')}
        <small>Waddy · ${d.audience} · Maadi, Cairo</small>
      </div>
    </section>`,
};

function html(d) {
  const slides = d.slides.map((s, i) => {
    const body = R[s.type](s, d);
    if (s.type === 'cover') return body;
    const foot = `<footer><img src="${asset('FOOTMARK')}"><span>Waddy · ${d.audience}</span><b>${String(i + 1).padStart(2, '0')}</b></footer>`;
    const dark = /class="slide teal/.test(body);
    return body.replace('</section>', foot.replace('FOOTMARK', dark ? 'w_mint.png' : 'w_teal.png') + '</section>');
  });
  return `<!doctype html><html lang="en"><head><meta charset="utf-8"><title>${d.title}</title><style>${css}</style></head><body>${slides.join('\n')}</body></html>`;
}

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  for (const d of decks) {
    const file = path.join(OUT, d.file + '.html');
    fs.writeFileSync(file, html(d));
    await page.goto('file://' + file);
    await page.evaluate(() => document.fonts.ready);
    const over = await page.evaluate(() =>
      [...document.querySelectorAll('.slide')].map((s, i) => {
        const bad = [...s.querySelectorAll('h1,h2,p,li,b,.tile,.move,.pain,.fact,.win,.card,.phone')].filter((e) => { if (e.closest('footer')) return false;
          const r = e.getBoundingClientRect(), p = s.getBoundingClientRect();
          return r.bottom > p.bottom - 34 || r.right > p.right - 8;
        });
        return bad.length ? `slide ${i + 1}: ${bad.length} overflow (${bad[0].className || bad[0].tagName})` : null;
      }).filter(Boolean));
    if (over.length) console.log(d.file, over);
    await page.pdf({ path: path.join(OUT, d.file + '.pdf'), width: '1280px', height: '720px', printBackground: true });
    console.log('built', d.file);
  }
  await browser.close();
})();
