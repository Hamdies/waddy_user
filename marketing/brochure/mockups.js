// Illustrative phone screens for the brochures. They show what a feature does,
// drawn in the app's own colours; they are not screenshots of a build.
const phone = (inner) => `<div class="phone"><div class="notch"></div><div class="screen">${inner}</div></div>`;
const head = (small, title, plain) => `<div class="s-head ${plain ? 'plain' : ''}"><small>${small}</small><b>${title}</b></div>`;
const opt = (on, h, p) => `<div class="row ${on ? 'on' : ''}"><span class="radio"></span><div class="grow"><b>${h}</b><p>${p}</p></div></div>`;

module.exports = {
  // ── restaurants ──
  top10: () => phone(`
    ${head('Food · Maadi', 'Top 10 Maadi spots')}
    <div class="s-body">
      ${[['1', 'Your restaurant', 'Burgers · Free delivery', 'on'], ['2', 'Grill house', 'Grills · Egyptian', ''], ['3', 'Pizza corner', 'Pizza · Offers', ''], ['4', 'Shawarma stop', 'Shawarma', '']].map(([n, a, b, on]) => `
        <div class="row ${on}"><span class="rank">${n}</span><span class="sw ${on ? 'teal' : ''}">${a[0]}</span><div class="grow"><b>${a}</b><p>${b}</p></div>${on ? '<span class="pill dark">You</span>' : ''}</div>`).join('')}
      <div class="s-label">Browse by cuisine</div>
      <div class="tagrow">${['Egyptian', 'Burgers', 'Pizza', 'Grills', 'Shawarma'].map((c) => `<span class="pill">${c}</span>`).join('')}</div>
    </div>`),

  spots: (icon) => phone(`
    ${head('Waddy Spots · This week', "Who's ruling Maadi?")}
    <div class="s-body">
      <div class="row on"><span class="rank">1</span><span class="sw teal">${icon('trophy', 18)}</span><div class="grow"><b>Your café</b><p>Live leader</p></div><span class="pill dark">Champion</span></div>
      <div class="row"><span class="rank">2</span><span class="sw amber">B</span><div class="grow"><b>Brunch place</b><p>It's close at the top</p></div><span class="pill">Top 3</span></div>
      <div class="row"><span class="rank">3</span><span class="sw coral">R</span><div class="grow"><b>Rooftop hangout</b><p>New this week</p></div><span class="pill amber">New entry</span></div>
      <div class="s-label">The claw · Voter draw</div>
      <div class="row"><span class="sw">${icon('gift', 18)}</span><div class="grow"><b>5 voters win a free item</b><p>At the champion's place. Watch the draw live.</p></div></div>
    </div>
    <div class="s-foot"><div class="btn">Vote for your spot</div></div>`),

  menu: () => phone(`
    ${head('Your restaurant', 'Make it yours', true)}
    <div class="s-body">
      <div class="hero-prod"><div><b>Classic burger</b><small>Customize every item</small></div><div class="dot" style="background:#FFBE0B"></div></div>
      <div class="s-label">Choose your extras</div>
      ${opt(true, 'Extra cheese', 'Added to this burger')}
      ${opt(false, 'No onions', 'Just how they like it')}
      <div class="s-label">Order again</div>
      <div class="row"><span class="sw amber">2×</span><div class="grow"><b>Last Friday's order</b><p>Reorder in seconds</p></div><span class="pill dark">Reorder</span></div>
    </div>
    <div class="s-foot"><div class="btn">Add to cart</div></div>`),

  // ── grocery ──
  ripeness: () => phone(`
    ${head('Fruit', 'Bananas', true)}
    <div class="s-body">
      <div class="hero-prod" style="background:#FFF3C4"><div><b>Bananas</b><small>Clear price before you add</small></div><div class="dot" style="background:#FFBE0B"></div></div>
      <div class="s-label">Ripeness</div>
      ${opt(true, 'Ready to eat', 'Ripe and sweet, for today')}
      ${opt(false, 'Ripe in 2–3 days', 'A little firm, ripens at home')}
    </div>
    <div class="s-foot"><div class="btn">Add to cart</div></div>`),

  use: () => phone(`
    ${head('Vegetables', 'Tomatoes', true)}
    <div class="s-body">
      <div class="hero-prod" style="background:#FFD9D6"><div><b>Tomatoes</b><small>One question before the cart</small></div><div class="dot" style="background:#FF6B6B"></div></div>
      <div class="s-label">Use it for</div>
      ${opt(false, 'For salad', 'Firm and crisp, eaten raw')}
      ${opt(true, 'For cooking', 'Riper and softer, cooks down well')}
    </div>
    <div class="s-foot"><div class="btn">Add to cart</div></div>`),

  ticket: () => phone(`
    ${head('New order', "What your picker reads")}
    <div class="s-body">
      <div class="row"><span class="sw amber">B</span><div class="grow"><b>Bananas</b><p><span class="pill dark">Ripe in 2–3 days</span></p></div></div>
      <div class="row"><span class="sw coral">T</span><div class="grow"><b>Tomatoes</b><p><span class="pill dark">For cooking</span></p></div></div>
      <div class="row"><span class="sw">A</span><div class="grow"><b>Avocados</b><p><span class="pill dark">Ready to eat</span></p></div></div>
      <div class="row"><span class="sw">C</span><div class="grow"><b>Cucumbers</b><p><span class="pill dark">For salad</span></p></div></div>
      <div class="row"><span class="sw">M</span><div class="grow"><b>Milk</b><p>No question asked</p></div></div>
    </div>
    <div class="s-foot"><div class="btn">Start picking</div></div>`),

  // ── pets ──
  petProfile: (icon) => phone(`
    <div class="s-head" style="padding-bottom:22px">
      <small>Pets</small><b>Everything<br>Luna needs</b>
      <div class="pol" style="position:absolute;right:18px;top:40px"><div class="polaroid"><div class="ph">${icon('paw', 40)}</div><b>Luna</b></div></div>
    </div>
    <div class="s-body" style="padding-top:20px">
      <div class="s-label">Luna's profile</div>
      <div class="tagrow">${['Cat', 'Girl', '2 years', 'Picky eater'].map((c) => `<span class="pill dark">${c}</span>`).join('')}</div>
      <div class="s-label">Picked for Luna</div>
      <div class="row"><span class="sw">F</span><div class="grow"><b>Cat food</b><p>Your shop</p></div><span class="price">Add</span></div>
      <div class="row"><span class="sw amber">T</span><div class="grow"><b>Treats</b><p>Your shop</p></div><span class="price">Add</span></div>
      <div class="row"><span class="sw coral">L</span><div class="grow"><b>Litter & care</b><p>Your shop</p></div><span class="price">Add</span></div>
    </div>`),

  petUsual: (icon) => phone(`
    ${head('Pets', "Luna's usual")}
    <div class="s-body">
      <div class="push"><span class="sw teal">${icon('bell', 18)}</span><div><b>Luna's food runs out Thursday</b><p>Order her usual from your shop in one tap.</p></div><time>now</time></div>
      <div class="s-label">Order again</div>
      <div class="row on"><span class="sw teal">${icon('repeat', 18)}</span><div class="grow"><b>Luna's usual</b><p>Cat food · treats · litter</p></div><span class="pill dark">Reorder</span></div>
      <div class="s-label">Remind me every…</div>
      <div class="tagrow">${['2 weeks', '3 weeks', '4 weeks', '6 weeks'].map((c, i) => `<span class="pill ${i === 2 ? 'dark' : ''}" style="font-size:11px;padding:6px 10px">${c}</span>`).join('')}</div>
      <div class="push"><span class="sw amber">${icon('cake', 18)}</span><div><b>Luna turns 1 this week</b><p>Time for adult food.</p></div></div>
    </div>`),

  clinic: (icon) => phone(`
    ${head('Pets · Near you', 'Vet clinics')}
    <div class="s-body">
      <div class="hero-prod" style="height:84px"><div><b>Your clinic</b><small>Open now · 600 m away</small></div><span class="sw teal">${icon('paw', 20)}</span></div>
      <div class="tagrow">${['Open now', '24/7', 'Home visits', 'Treats cats'].map((c) => `<span class="pill dark">${c}</span>`).join('')}</div>
      <div class="s-label">One tap to reach you</div>
      <div class="row"><span class="sw">${icon('phone', 18)}</span><div class="grow"><b>Call</b><p>Straight to your front desk</p></div></div>
      <div class="row"><span class="sw">${icon('chat', 18)}</span><div class="grow"><b>WhatsApp</b><p>The way clinics already work</p></div></div>
      <div class="row"><span class="sw">${icon('pin', 18)}</span><div class="grow"><b>Directions</b><p>To your door</p></div></div>
    </div>`),

  // ── shared ──
  tracking: (icon) => phone(`
    <div class="map">
      <i style="left:0;right:0;top:92px;height:14px"></i><i style="left:0;right:0;top:186px;height:12px"></i>
      <i style="top:0;bottom:0;left:74px;width:13px"></i><i style="top:0;bottom:0;left:196px;width:13px"></i>
      <svg viewBox="0 0 268 250"><path d="M80 210 V99 H202 V60" fill="none" stroke="#134E4A" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/><circle cx="80" cy="210" r="9" fill="#134E4A"/><circle cx="202" cy="60" r="13" fill="#1EF2A0" stroke="#134E4A" stroke-width="4"/><circle cx="140" cy="99" r="11" fill="#fff" stroke="#134E4A" stroke-width="4"/></svg>
    </div>
    <div class="s-body">
      <div style="display:flex;align-items:flex-end;justify-content:space-between"><div><div class="s-label">Arriving in</div><div class="eta">12 min</div></div><span class="pill dark">On the way</span></div>
      <div class="prog"><span class="d"></span><span class="d"></span><span class="d"></span><span></span></div>
      <div class="row"><span class="sw teal">${icon('lock', 18)}</span><div class="grow"><b>Delivery PIN</b><p>Your rider asks for it at the door</p></div><div class="pin-box"><span>4</span><span>8</span></div></div>
      <div class="row"><span class="sw">${icon('bag', 18)}</span><div class="grow"><b>Placed · Prepared · On the way</b><p>Every stage, without a phone call</p></div></div>
    </div>`),

  xp: (icon) => phone(`
    ${head('XP & Levels', 'Waddy! You just grabbed some XP')}
    <div class="s-body">
      <div class="row" style="display:block"><div style="display:flex;justify-content:space-between;margin-bottom:7px"><b>Level 4</b><span class="price">120 XP to go</span></div><div class="bar"><span style="width:68%"></span></div></div>
      <div class="s-label">Weekly quests</div>
      <div class="row on"><span class="sw teal">${icon('check', 18)}</span><div class="grow"><b>Order twice this week</b><p>1 of 2 done</p></div><span class="pill dark">+XP</span></div>
      <div class="s-label">Rewards</div>
      <div class="row"><span class="sw amber">${icon('tag', 18)}</span><div class="grow"><b>Coupon from your store</b><p>Yours to offer</p></div></div>
      <div class="row"><span class="sw">${icon('gift', 18)}</span><div class="grow"><b>Scratch card in the bag</b><p>A code for their next order</p></div></div>
      <div class="row"><span class="sw coral">${icon('users', 18)}</span><div class="grow"><b>Invite a friend</b><p>Both get rewarded</p></div></div>
    </div>`),

  aisles: (icon) => phone(`
    ${head('Your store', 'Shop by aisle')}
    <div class="s-body">
      <div class="row"><span style="color:#51605D">${icon('search', 16)}</span><div class="grow"><p style="font-size:12px">Search for exactly what you need</p></div></div>
      <div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:8px">
        ${[['Produce', '#D3F6E8'], ['Dairy', '#E6F4F3'], ['Bakery', '#FFE9A8'], ['Snacks', '#FFD6D6'], ['Cleaning', '#E6F4F3'], ['Home', '#D3F6E8']].map(([n, c]) => `<div style="background:${c};border-radius:13px;height:62px;display:flex;align-items:flex-end;padding:8px;font-weight:700;font-size:11px">${n}</div>`).join('')}
      </div>
      <div class="s-label">Fresh today</div>
      <div class="row"><span class="sw amber">B</span><div class="grow"><b>Bananas</b><p>Ripeness asked</p></div><span class="price">Add</span></div>
      <div class="row"><span class="sw coral">T</span><div class="grow"><b>Tomatoes</b><p>Salad or cooking asked</p></div><span class="price">Add</span></div>
    </div>`),
};
