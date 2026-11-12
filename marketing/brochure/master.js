// The 22-page Waddy partner brochure. Each page: { tone, status, html }.
//
// status tells the reader (and Waddy's own team) how firm a page is:
//   live    – the feature exists in the customer app today
//   policy  – an intended operating policy; confirm before promising it
//   plan    – a proposed marketing plan awaiting approval
//   concept – a concept mockup, not a screenshot of a shipped screen
// [Bracketed] amber text is an editable placeholder for a figure or policy
// nobody has confirmed yet. See docs/unconfirmed_commercial_info.md.
const mock = require('./mockups');

const STATUS = {
  live: 'Live in the app',
  policy: 'Operating policy · confirm before print',
  plan: 'Marketing plan · for approval',
  concept: 'Concept mockup',
};
const ph = (t) => `<span class="ph">[${t}]</span>`;

module.exports = (icon, asset, vertical = 'all') => {
  const phoneHtml = (name) => mock[name](icon);
  const tilt = (inner, cap) => `<div class="f-art" data-raster><div class="tiltcard"></div>${inner}</div>${cap ? `<div class="cap">${cap}</div>` : ''}`;
  const rw = (i, h, p, lab, amber) => `<div class="rw"><span class="ico">${icon(i, 24)}</span><div><b>${h}</b><p>${p}</p></div>${lab ? `<span class="lab ${amber ? 'amber' : ''}">${lab}</span>` : ''}</div>`;
  const pt = (i, h, p) => `<li><span class="pi">${icon(i)}</span><div><b>${h}</b><p>${p}</p></div></li>`;
  const adhead = (sub) => `<div class="adhead"><span class="av"><img src="${asset('w_mint.png')}"></span><div>Waddy<small>${sub}</small></div></div>`;

  const partnerPhone = `<div class="phone"><div class="notch"></div><div class="screen">
    <div class="s-head"><small>Partner App · Maadi branch</small><b>New orders</b></div>
    <div class="s-body">
      <div class="row on"><span class="sw teal">3</span><div class="grow"><b>Order · 3 items</b><p>Rider assigned · PIN at the door</p></div><span class="pill dark">Accept</span></div>
      <div class="row"><span class="sw">2</span><div class="grow"><b>Order · 2 items</b><p>Being prepared</p></div><span class="pill">Preparing</span></div>
      <div class="s-label">Your products</div>
      <div class="row"><span class="sw amber">A</span><div class="grow"><b>Item A</b><p>Available</p></div><span class="pill dark">On</span></div>
      <div class="row"><span class="sw coral">B</span><div class="grow"><b>Item B</b><p>Sold out today</p></div><span class="pill">Off</span></div>
      <div class="s-label">Store</div>
      <div class="row"><span class="sw">${icon('clock', 18)}</span><div class="grow"><b>Open now</b><p>Opening hours and busy mode</p></div></div>
    </div></div></div>`;

  const sponsoredPhone = `<div class="phone"><div class="notch"></div><div class="screen">
    <div class="s-head"><small>Home · Maadi</small><b>Featured near you</b></div>
    <div class="s-body">
      <div class="hero-prod" style="background:#134E4A;color:#fff;height:112px"><div><span class="pill amber">Sponsored</span><b style="display:block;margin-top:6px">Your brand</b><small style="color:#CFE9E5">Home-screen placement</small></div><span class="sw" style="width:52px;height:52px">${icon('star', 24)}</span></div>
      <div class="s-label">Featured</div>
      <div class="row on"><span class="sw teal">Y</span><div class="grow"><b>Your business</b><p>Featured rail</p></div><span class="pill amber">Sponsored</span></div>
      <div class="row"><span class="sw">A</span><div class="grow"><b>Another store</b><p>Nearby</p></div></div>
      <div class="s-label">Your category</div>
      <div class="row"><span class="sw amber">Y</span><div class="grow"><b>Your business</b><p>Category placement</p></div><span class="pill amber">Sponsored</span></div>
    </div></div></div>`;

  const P = [];
  const page = (tone, status, html, cls = '') => P.push({ tone, status, html, cls: `${cls} p${P.length + 1}` });

  // 1 ── cover
  page('mint', null, `
    <div class="brand"><img src="${asset('w_teal.png')}"><span>Waddy</span><i>Partner brochure</i></div>
    <div class="copy">
      <div class="kicker">The local growth partner</div>
      <h1>Grow Your Business <u>Beyond the Counter.</u></h1>
      <p class="lede">Meet Waddy, the neighborhood delivery and growth platform built for Maadi.</p>
      <div class="chips"><span>Restaurants</span><span>Cafés</span><span>Grocery</span><span>Pet shops</span></div>
    </div>
    <div class="devices" data-raster>
      <div class="dv-a" style="position:absolute;left:0;top:70px;transform:scale(.86);transform-origin:top left">${partnerPhone}</div>
      <div class="dv-b" style="position:absolute;left:214px;top:0">${phoneHtml('top10')}</div>
    </div>
    <div class="tagline">Made in Maadi · Built around you</div>`, 'm-cover');

  // 2 ── who we are
  page('teal', 'live', `
    <div class="split">
      <div class="col">
        <div class="eyebrow">Who we are</div>
        <h2>Made in Maadi. <u>Built Around Local Business.</u></h2>
        <p class="lede">Waddy is a hyperlocal, multi-category delivery platform. We connect the people of one neighborhood with the restaurants, cafés, grocery stores and pet shops that serve it, and we concentrate our marketplace, our marketing and our riders on that neighborhood.</p>
      </div>
      <div class="col rows" style="flex:0 0 500px">
        ${rw('tap', 'A customer app', 'Discover nearby businesses, order, and track every delivery live.')}
        ${rw('sliders', 'A Partner App', 'Manage your orders, products, availability and daily operations.')}
        ${rw('pin', 'Our own riders', 'Waddy operates its delivery network inside the areas it serves.')}
        ${rw('grid', 'Four categories, one app', 'Food, coffee, groceries and pet supplies, side by side.')}
      </div>
    </div>
    <div class="band">Big apps list your business. <span>Waddy helps your neighborhood discover it.</span></div>`);

  // 3 ── the problem
  page('paper', null, `
    <div class="split">
      <div class="col">
        <div class="eyebrow coral">The problem</div>
        <h2>Your Business Deserves <u>More Than Another Listing.</u></h2>
        <p class="lede">A marketplace that covers a whole city is built for breadth. That structure creates real challenges for a business whose customers live a few streets away.</p>
        <div class="nums">
          <div class="num"><span>01</span><div><b>A much larger catalogue to compete in</b><p>Your listing shares attention with brands from every district.</p></div></div>
          <div class="num"><span>02</span><div><b>Advertising in a crowded room</b><p>Promotion has to be heard above everyone else’s.</p></div></div>
          <div class="num"><span>03</span><div><b>Little room for a neighborhood identity</b><p>It is hard to become “our local place” inside a citywide list.</p></div></div>
        </div>
      </div>
      <div data-raster style="flex:none"><div class="listviz">
        <div class="hd">Citywide catalogue · every area, every brand</div>
        ${Array.from({ length: 12 }, (_, i) => i === 6
          ? '<div class="lr me"><i></i>Your business</div>'
          : `<div class="lr"><i></i>${['Brand in another district', 'Chain branch, across town', 'Sponsored listing', 'Another area entirely'][i % 4]}</div>`).join('')}
        <div class="fade"></div>
      </div></div>
    </div>`);

  // 4 ── the Waddy difference
  const cmp = [
    ['Discovery', 'Customers browse a catalogue that spans many areas.', 'Customers browse businesses relevant to where they live.'],
    ['Marketing', 'Promotion competes for attention across a crowded marketplace.', 'Waddy concentrates its advertising on the areas it serves.'],
    ['Local brand', 'Limited room to build a distinct neighborhood identity.', 'Partners can become familiar names in their own neighborhood.'],
    ['Branches', 'A brand’s branches sit inside one broad, citywide presence.', 'The Maadi branch is the designated branch for Maadi customers.'],
    ['Delivery', 'Fleet and coverage are organized around the whole city.', 'Waddy’s own riders work inside its delivery areas.'],
    ['Repeat orders', 'Loyalty belongs mostly to the marketplace as a whole.', 'Rewards, weekly quests and Spots are built around local habits.'],
  ];
  page('tint', null, `
    <div class="eyebrow">The Waddy difference</div>
    <h2>Big Marketplace Thinking vs. <u>Neighborhood-First Growth.</u></h2>
    <div class="cmp">
      <div></div><div class="h a">Citywide marketplace model</div><div class="h b">Waddy: neighborhood-first</div>
      ${cmp.map(([k, a, b]) => `<div class="k">${k}</div><div class="a">${a}</div><div class="b">${b}</div>`).join('')}
    </div>
    <p class="note">This page compares two business models. It describes structural differences and is not a statement about any particular company.</p>`);

  // 5 ── why Maadi
  page('paper', 'live', `
    <div class="split">
      <div class="col">
        <div class="eyebrow">Why Maadi</div>
        <h2>Start Where Your Customers <u>Actually Live.</u></h2>
        <p class="lede">Waddy launches in Maadi and its surrounding service areas, including Degla. Everything we build points at the same streets you already serve.</p>
        <ul class="points">
          ${pt('eye', 'A marketplace the size of the neighborhood', 'A customer in Maadi opens Waddy and sees Maadi, not the whole of Cairo.')}
          ${pt('bolt', 'Marketing aimed at your delivery area', 'Our campaigns target the people who can actually order from you.')}
          ${pt('pin', 'Riders who work these streets', 'Short, familiar routes inside one service area.')}
        </ul>
        <p class="note">Launch service areas: ${ph('Confirmed Launch Service Areas')}</p>
      </div>
      <div data-raster style="flex:none"><div class="mapbox">
        <svg viewBox="0 0 500 540">
          <path d="M-20 400 C120 360 180 470 300 430 S470 380 540 420 V560 H-20Z" fill="#BFEFDC"/>
          <g stroke="#fff" stroke-width="12" fill="none" stroke-linecap="round"><path d="M40 90 L460 170"/><path d="M90 20 L160 520"/><path d="M330 10 L290 530"/><path d="M20 290 L480 330"/></g>
          <circle cx="250" cy="250" r="190" fill="#1EF2A0" opacity=".28"/><circle cx="250" cy="250" r="120" fill="#1EF2A0" opacity=".5"/>
          <circle cx="250" cy="250" r="54" fill="#134E4A"/>
          <text x="250" y="246" text-anchor="middle" font-weight="900" font-size="20" fill="#1EF2A0">Maadi</text>
          <text x="250" y="266" text-anchor="middle" font-weight="700" font-size="10" fill="#fff" letter-spacing="1.500">LAUNCH AREA</text>
          <g font-weight="800" font-size="15" fill="#134E4A"><text x="352" y="176">Degla</text><text x="120" y="188">Sarayat</text></g>
          <g fill="#134E4A"><circle cx="340" cy="186" r="7"/><circle cx="170" cy="198" r="7"/><circle cx="196" cy="342" r="7"/><circle cx="330" cy="330" r="7"/><circle cx="262" cy="130" r="7"/></g>
          <g fill="#fff"><circle cx="340" cy="186" r="3"/><circle cx="170" cy="198" r="3"/><circle cx="196" cy="342" r="3"/><circle cx="330" cy="330" r="3"/><circle cx="262" cy="130" r="3"/></g>
          <text x="36" y="500" font-weight="700" font-size="11" fill="#134E4A" letter-spacing="1.400">ILLUSTRATIVE MAP · NOT TO SCALE</text>
        </svg>
      </div></div>
    </div>`);

  // 6 ── Maadi branch priority
  page('teal', 'policy', `
    <div class="split">
      <div data-raster style="flex:none"><div class="mapbox" style="width:470px">
        <svg viewBox="0 0 470 540">
          <path d="M250 -10 C230 120 300 220 262 330 S250 480 280 560" stroke="#1D706A" stroke-width="26" fill="none" stroke-linecap="round"/>
          <g fill="#1D706A" stroke="#7ECAC3" stroke-width="2"><circle cx="70" cy="150" r="12"/><circle cx="226" cy="140" r="12"/><circle cx="372" cy="96" r="12"/><circle cx="408" cy="250" r="12"/></g>
          <g font-weight="700" font-size="14" fill="#7ECAC3"><text x="34" y="124">Sheikh Zayed</text><text x="150" y="118">Zamalek</text><text x="330" y="70">Heliopolis</text><text x="366" y="288">New Cairo</text></g>
          <circle cx="262" cy="390" r="74" fill="#1EF2A0" opacity=".18"/><circle cx="262" cy="390" r="46" fill="#1EF2A0" opacity=".3"/>
          <circle cx="262" cy="390" r="20" fill="#1EF2A0"/>
          <text x="262" y="456" text-anchor="middle" font-weight="900" font-size="22" fill="#1EF2A0">Maadi branch</text>
          <text x="262" y="478" text-anchor="middle" font-weight="700" font-size="11" fill="#fff" letter-spacing="1.500">PRIORITY FOR MAADI CUSTOMERS</text>
          <text x="24" y="520" font-weight="700" font-size="10.500" fill="#7ECAC3" letter-spacing="1.300">FICTIONAL BRAND · ILLUSTRATIVE MAP</text>
        </svg>
      </div></div>
      <div class="col">
        <div class="eyebrow">For brands with more than one branch</div>
        <h2 style="font-size:42px">Your Maadi Branch <u>Gets Priority.</u></h2>
        <p class="lede" style="font-size:17.500px">One brand. Multiple branches. Your neighborhood comes first. Whether you have one location or twenty, Waddy is built around the branch that serves the customer’s neighborhood.</p>
        <div class="vflow" style="margin-top:20px">
          <div class="vf"><span>1</span><div><b>A brand with several branches</b><p>Maadi, New Cairo, Heliopolis, Zamalek, Sheikh Zayed.</p></div></div>
          <div class="vf"><span>2</span><div><b>The customer opens Waddy in Maadi</b><p>Waddy shows the marketplace for that neighborhood.</p></div></div>
          <div class="vf on"><span>3</span><div><b>The Maadi branch is the one they see</b><p>A dedicated branch presence, with local promotions.</p></div></div>
          <div class="vf"><span>4</span><div><b>The order goes to the right kitchen</b><p>Prepared and delivered by the branch that serves them.</p></div></div>
        </div>
        <p class="note" style="margin-top:14px">Priority means local-branch relevance and designated visibility for Maadi customers. It is not a guaranteed ranking position. Other branches join as Waddy opens in their areas.</p>
      </div>
    </div>`);

  // 7 ── ecosystem
  const pillars = [
    ['Discover', 'Customers find nearby restaurants, cafés, grocery stores and pet shops.', 'Page 08'],
    ['Promote', 'Local advertising, social content, Partner Spotlights and neighborhood campaigns.', 'Pages 09–14'],
    ['Deliver', 'Waddy’s own riders carry the order, tracked live to the door.', 'Page 17'],
    ['Retain', 'Rewards, weekly quests, scratch cards and wallet bring customers back.', 'Page 15'],
    ['Grow', 'Your Partner App and available insights help you run and understand your business.', 'Page 18'],
  ];
  page('mint', null, `
    <div class="eyebrow">The Waddy local growth ecosystem</div>
    <h2 style="font-size:52px">One neighborhood. <u>Five ways to grow.</u></h2>
    <div class="pillars">${pillars.map(([h, p, g], i) => `
      <div class="pillar"><span class="pn">${i + 1}</span><b>${h.toUpperCase()}</b><p>${p}</p><span class="pg">${g}</span></div>`).join('')}
    </div>`);

  // 8 ── discovery
  page('paper', 'live', `
    <div class="split">
      <div class="col">
        <div class="eyebrow">1 · Discover</div>
        <h2>Be Where Your <u>Neighborhood Shops.</u></h2>
        <p class="lede">Waddy’s customer app is organized around what is near the customer, so being found does not depend on outspending a whole city.</p>
        <ul class="points">
          ${pt('trophy', 'Top 10 Maadi, ranked', 'A ranked list of neighborhood favorites at the top of the food home.')}
          ${pt('grid', 'Found by category', 'By cuisine for restaurants, by aisle for grocery, by pet for pet shops.')}
          ${pt('tag', 'Your offers, shown up front', 'Offers and free delivery appear on your listing before the menu opens.')}
          ${pt('search', 'Search that stays local', 'Customers looking for something specific find who sells it nearby.')}
        </ul>
        <div class="win"><em>What it means for you</em><span>You compete with your street, not with the city.</span></div>
      </div>
      <div style="flex:none">${tilt(phoneHtml('top10'))}</div>
    </div>`);

  // 9 ── local advertising + participation model
  page('teal', 'plan', `
    <div class="split">
      <div class="col">
        <div class="eyebrow">2 · Promote</div>
        <h2 style="font-size:40px">We Invest in Making Waddy <u>Visible in Maadi.</u></h2>
        <p class="lede" style="font-size:17px">Waddy builds awareness for the platform and the businesses on it, in the areas we serve. Here is who does what.</p>
        <div class="rows" style="margin-top:20px">
          ${rw('bolt', 'A · Platform-led marketing', 'Waddy-funded Instagram and Facebook advertising, organic social content, neighborhood and seasonal campaigns, Waddy Spots.', 'Funded by Waddy')}
          ${rw('star', 'B · Partner promotion', 'Selected partners are featured in Waddy’s content and campaigns, such as Partner Spotlight.', 'By selection')}
          ${rw('tag', 'C · Optional paid promotion', 'Sponsored in-app placements and partner-specific paid social campaigns.', 'Optional', true)}
        </div>
        <p class="note" style="margin-top:14px">Standard marketplace visibility is part of joining; you never have to buy advertising to be listed. Budget: ${ph('Monthly Advertising Budget')} · Cadence: ${ph('Campaign Frequency')}</p>
      </div>
      <div style="flex:none">
        <div class="ads" data-raster>
          <div class="story">
            <div class="bars"><i class="d"></i><i></i><i></i></div>
            ${adhead('Sponsored · Maadi')}
            <h4>Maadi’s burgers, at your door.</h4>
            <div class="art"><img src="${asset('burger.webp')}"></div>
            <div class="cta">Order on Waddy</div>
          </div>
          <div class="post">
            ${adhead('Sponsored · Maadi, Cairo')}
            <div class="tx">Your weekly grocery, picked the way you like it. From stores around you.</div>
            <div class="img"><h4>Ripe today, <em>or ripe Thursday.</em></h4><img src="${asset('fresh_market.webp')}"></div>
            <div class="ft"><div><b>Waddy</b>Groceries in Maadi</div><span class="cta">Order now</span></div>
          </div>
        </div>
        <div class="cap">Advertising concepts · story and feed formats</div>
      </div>
    </div>`);

  // 10 ── campaigns
  const camps = [
    ['Maadi Food Discovery', 'Introduce restaurants available on Waddy', 'Short Instagram video', 'Menu items and a kitchen visit', 'Open Waddy and order'],
    ['Coffee in Maadi', 'Local café discovery', 'Instagram and Facebook', 'Signature drinks, the space', 'Find a café on Waddy'],
    ['Your Weekly Grocery', 'Promote local grocery stores', 'Facebook and Instagram feed', 'Fresh aisle, weekly essentials', 'Start a grocery basket'],
    ['Pet Essentials', 'Highlight local pet shops', 'Instagram stories', 'Best-selling supplies', 'Add a pet and shop'],
    ['New on Waddy', 'Introduce newly joined partners', 'Feed and stories', 'Brand story and first offer', 'Try the new place'],
    ['Waddy Spots', 'Community vote for local favorites', 'Social and in-app', 'Invite your regulars to vote', 'Vote this week'],
  ];
  page('paper', 'plan', `
    <div class="eyebrow">2 · Promote · Instagram and Facebook campaigns</div>
    <h2>Local Advertising. <u>Relevant Audiences.</u></h2>
    <p class="lede">Six campaign concepts for Maadi. Each is geographically targeted to Waddy’s service area: ${ph('Targeting Radius / Areas')}.</p>
    <div class="camps">${camps.map(([n, o, f, r, a], i) => `
      <div class="camp"><span class="cn">Campaign 0${i + 1} · concept</span><b>${n}</b>
        <dl><dt>Objective</dt><dd>${o}</dd><dt>Format</dt><dd>${f}</dd><dt>Your role</dt><dd>${r}</dd><dt>Action</dt><dd>${a}</dd></dl></div>`).join('')}
    </div>
    <p class="note" style="margin-top:14px">These are proposed concepts, not campaigns that have already run. No results are implied. Neighborhood themes can also include Best Burgers in Maadi, Weekend Food Picks, and Ramadan and seasonal campaigns.</p>`);

  // 11 ── partner spotlight
  page('tint', 'plan', `
    <div class="split">
      <div style="flex:none">
        <div data-raster style="padding:10px 20px 20px"><div class="post" style="width:330px">
          ${adhead('Partner Spotlight · Maadi')}
          <div class="tx">Meet the people behind one of Maadi’s favorite kitchens. Now on Waddy.</div>
          <div class="img dark" style="height:250px"><h4 style="font-size:26px;width:200px">Partner Spotlight: <em>Your Brand</em></h4><img src="${asset('burger.webp')}" style="width:250px"></div>
          <div class="ft"><div><b>Your Brand</b>Road 9, Maadi</div><span class="cta">Order on Waddy</span></div>
        </div></div>
        <div class="cap">Spotlight creative · concept</div>
      </div>
      <div class="col">
        <div class="eyebrow">2 · Promote · Waddy Partner Spotlight</div>
        <h2 style="font-size:42px">Your Brand Deserves <u>the Spotlight.</u></h2>
        <p class="lede" style="font-size:17.500px">Partner Spotlight is promotional content Waddy creates about a participating business and publishes on Waddy’s own channels.</p>
        <div class="minis">
          ${[['Your brand', 'Who you are and why locals choose you'], ['Your products', 'What you are known for'], ['Your location', 'Where to find you in Maadi'], ['Your specialties', 'The items worth the order'], ['Your offers', 'What is on right now'], ['You, on Waddy', 'A direct path to order']].map(([h, p]) => `<div class="mini"><b>${h}</b><p>${p}</p></div>`).join('')}
        </div>
        <p class="note">Spotlights are an additional exposure opportunity, not a fixed entitlement. Selection: ${ph('Partner Spotlight Selection Criteria')} · Schedule: ${ph('Spotlight Schedule')}</p>
      </div>
    </div>`);

  // 12 ── how Waddy advertises your business
  const stages = [
    ['Partner selection', 'Waddy identifies participating partners and a suitable promotional opportunity.'],
    ['Content creation', `Waddy prepares the creative featuring you. Scope: ${ph('Production Services Included')}.`],
    ['Local targeting', 'The campaign is aimed at the relevant Waddy service area, starting with Maadi.'],
    ['Customer discovery', 'People nearby see the content and can find your business on Waddy.'],
    ['Performance review', 'We look at what is measurable: reach, impressions, clicks, engagement, app visits and attributed orders.'],
  ];
  page('paper', 'plan', `
    <div class="eyebrow">2 · Promote · How Waddy advertises your business</div>
    <h2 style="font-size:40px;max-width:1100px">We don’t just list local businesses. <u>We help put them in front of local customers.</u></h2>
    <div class="hflow">${stages.map(([h, p], i) => `
      <div class="hf ${i === 4 ? 'end' : ''}"><div class="hn">${i + 1}</div><b>${h}</b><p>${p}</p></div>`).join('')}
    </div>
    <p class="note">Advertising performance varies. Reach and engagement do not automatically become orders, and Waddy does not guarantee a result from any campaign.</p>`);

  // 13 ── Waddy Spots
  page('teal', 'live', `
    <div class="split">
      <div style="flex:none">${tilt(phoneHtml('spots'))}</div>
      <div class="col">
        <div class="eyebrow">2 · Promote · Waddy Spots</div>
        <h2>Let Your Neighborhood <u>Choose Its Favorites.</u></h2>
        <p class="lede">Every week, Waddy customers vote for their favorite local places. It gives the neighborhood something to talk about, and gives you something to win.</p>
        <ul class="points">
          ${pt('users', 'One vote per person, every week', 'A live leaderboard your regulars want to move.')}
          ${pt('trophy', 'Recognition for the winner', 'The spot with the most votes is crowned champion of the week inside Waddy.')}
          ${pt('gift', 'A reason to visit', 'Five of the champion’s voters are drawn at random to win a voucher for a free item there. Waddy runs the draw.')}
        </ul>
        <div class="win"><em>What it means for you</em><span>Community attention you did not have to buy, and new faces at your door.</span></div>
      </div>
    </div>`);

  // 14 ── sponsored placements
  page('paper', 'live', `
    <div class="split">
      <div class="col">
        <div class="eyebrow">2 · Promote · Optional</div>
        <h2>More Visibility <u>Inside the App.</u></h2>
        <p class="lede">When you want extra attention for a launch, an offer or a season, you can add visibility in the places customers already browse.</p>
        <ul class="points">
          ${pt('star', 'Home-screen placement', 'Your brand at the top of the screen customers open first.')}
          ${pt('grid', 'Category placement', 'Stand out inside your own category.')}
          ${pt('eye', 'Featured rails', 'A place among the businesses Waddy is highlighting.')}
        </ul>
        <p class="note">Sponsored placements are optional, always labelled, and separate from standard onboarding. Pricing: ${ph('Sponsored Placement Pricing')} · Available formats: ${ph('Confirmed Placement Formats')}</p>
      </div>
      <div style="flex:none">${tilt(sponsoredPhone, 'Placement positions · concept view')}</div>
    </div>`);

  // 15 ── retention
  page('tint', 'live', `
    <div class="split">
      <div style="flex:none">${tilt(phoneHtml('xp'))}</div>
      <div class="col">
        <div class="eyebrow">4 · Retain</div>
        <h2>Turn First Orders Into <u>Repeat Customers.</u></h2>
        <p class="lede">Waddy gives customers reasons to come back that do not depend on you cutting your prices.</p>
        <ul class="points">
          ${pt('bolt', 'XP and levels', 'Customers earn XP on every order and unlock rewards as they level up.')}
          ${pt('check', 'Weekly quests', 'Challenges that bring people back to the app within the week.')}
          ${pt('gift', 'Scratch cards', 'A printed code in the bag that turns one order into a reason for the next.')}
          ${pt('repeat', 'Wallet, referrals and reorder', 'Balance to spend, friends to invite, and past orders one tap away.')}
        </ul>
        <div class="win"><em>What it means for you</em><span>More of tonight’s customers become next week’s.</span></div>
      </div>
    </div>`);

  // 16 ── built for every business
  const verts = [
    ['Restaurants', 'trophy', '', [['Top 10 Maadi', 'A ranked local stage'], ['Customizable items', 'Orders arrive right the first time'], ['One-tap reorder', 'Habits form around your menu']]],
    ['Cafés', 'star', 't', [['Waddy Spots', 'Weekly votes for local favorites'], ['Found by craving', 'Customers browse by category'], ['Offers up front', 'Visible before the menu opens']]],
    ['Grocery & supermarkets', 'leaf', '', [['Ripeness choice', 'Ready to eat, or ripe in 2–3 days'], ['Salad or cooking', 'Your picker knows which crate'], ['Shop by aisle', 'The whole store, laid out clearly']]],
    ['Pet shops', 'paw', 't', [['Pet profiles', 'A shop built around each pet'], ['Refill reminders', 'An order before the bag runs out'], ['Vet clinic listings', 'Call, WhatsApp or directions']]],
  ];
  page('paper', 'live', `
    <div class="eyebrow">Built for every business</div>
    <h2>One Platform. <u>Different Business Needs.</u></h2>
    <div class="verts">${verts.map(([h, i, t, rows]) => `
      <div class="vert"><div class="vh ${t}"><b>${h}</b>${icon(i, 34)}</div>
        <div class="vb">${rows.map(([a, b]) => `<div><b>${a}</b><p>${b}</p></div>`).join('')}</div></div>`).join('')}
    </div>
    <p class="note">A dedicated brochure is available for restaurants, for grocery stores and for pet shops, with the details of each.</p>`);

  // 17 ── delivery
  page('teal', 'live', `
    <div class="split">
      <div class="col">
        <div class="eyebrow">3 · Deliver</div>
        <h2>We Deliver. <u>You Focus on Your Business.</u></h2>
        <p class="lede">Extend your reach without building and managing a rider team of your own.</p>
        <ul class="points">
          ${pt('pin', 'Waddy’s own riders', 'A delivery network that works inside the neighborhood.')}
          ${pt('clock', 'Live tracking for the customer', 'A live map and ETA, so they watch the order instead of calling you.')}
          ${pt('lock', 'A delivery PIN at the door', 'The rider asks for it, so the order reaches the right person.')}
          ${pt('bag', 'Cash handled for you', `Riders collect cash on delivery. Settlement: ${ph('Settlement Schedule')}.`)}
        </ul>
        <div class="win"><em>What it means for you</em><span>Fewer phone calls, fewer disputes, and a strong last impression.</span></div>
      </div>
      <div style="flex:none">${tilt(phoneHtml('tracking'))}</div>
    </div>`);

  // 18 ── partner app + insights
  page('paper', 'concept', `
    <div class="split" style="gap:40px">
      <div style="flex:none">${tilt(partnerPhone, 'Partner App · concept view')}</div>
      <div class="col">
        <div class="eyebrow">5 · Grow</div>
        <h2 style="font-size:40px">Your Business. <u>Under Your Control.</u></h2>
        <p class="lede" style="font-size:17px">Run your Waddy presence from the Partner App, and use the insights available to make better decisions.</p>
        <ul class="points">
          ${pt('bag', 'Orders', 'Receive, accept and follow every order.')}
          ${pt('tag', 'Products and prices', 'Keep your catalogue current.')}
          ${pt('clock', 'Availability', 'Mark items sold out and set your opening hours.')}
        </ul>
        <p class="note">Insights shown where supported: ${ph('Confirmed Analytics: sales, peak hours, top products, customer insights')}</p>
      </div>
      <div style="flex:none"><div data-raster style="padding:10px 16px 30px"><div class="insight">
        <div class="ih">Understand your business</div><div class="big">Peak hours</div>
        <div class="bars2">${[30, 44, 38, 62, 90, 100, 72, 40].map((h, i) => `<i class="${i === 4 || i === 5 ? 'd' : ''}" style="height:${h}%"></i>`).join('')}</div>
        <div class="ax"><span>12</span><span>3</span><span>6</span><span>9 pm</span></div>
        <div class="tp"><div><b>Top product</b><span>Item A</span></div><div><b>Repeat customers</b><span>Trend</span></div></div>
      </div></div><div class="cap">Insights · concept view</div></div>
    </div>`);

  // 19 ── first 90 days
  const days = [
    ['Days 1–14', 'Set up', 'Agreement, catalogue, photos and prices. Partner App training for your team.'],
    ['Days 15–30', 'Launch', 'Go live in Maadi. Your store appears in local discovery from day one.'],
    ['Days 31–60', 'Build', 'Offers, Spots and eligibility for Waddy’s partner promotion.'],
    ['Days 61–90', 'Review', 'Look at your orders and insights together and plan the next quarter.'],
  ];
  page('mint', 'plan', `
    <div class="eyebrow">Your roadmap</div>
    <h2 style="font-size:50px">Your First 90 Days <u>With Waddy.</u></h2>
    <div class="hflow">${days.map(([w, h, p], i) => `
      <div class="hf ${i === 3 ? 'end' : ''}"><div class="when" ${i === 3 ? 'style="color:#1EF2A0"' : ''}>${w}</div><b style="font-size:24px">${h}</b><p style="font-size:15px">${p}</p></div>`).join('')}
    </div>
    <p class="note">An indicative roadmap. Actual timing depends on your catalogue and readiness: ${ph('Onboarding Timeline')}</p>`);

  // 20 ── commercial partnership
  const terms = [
    ['Commission', 'What Waddy earns on each completed order.', 'Commission Structure'],
    ['Delivery', 'Who pays the delivery fee and how it is set.', 'Delivery Fee Model'],
    ['Subscription', 'Any fixed monthly fee for being on Waddy.', 'Monthly Subscription, if any'],
    ['Settlement', 'When and how your sales are paid out, including cash orders.', 'Settlement Schedule'],
    ['Refunds', 'How cancellations, refunds and order issues are handled.', 'Refund & Cancellation Policy'],
    ['Advertising', 'Optional paid promotion, priced separately.', 'Sponsored Placement Pricing'],
    ['Agreement', 'Contract length and notice period.', 'Contract Term & Notice'],
  ];
  page('paper', 'policy', `
    <div class="eyebrow">Commercial partnership</div>
    <h2>Clear Terms. <u>A Transparent Partnership.</u></h2>
    <p class="lede">Everything that affects what you earn is written down before you start. No surprises after you join.</p>
    <div class="terms">${terms.map(([k, d, p]) => `<div class="k">${k}</div><div>${d}</div><div>${ph(p)}</div>`).join('')}</div>`);

  // 21 ── why join now
  page('teal', null, `
    <div class="eyebrow">Why join now</div>
    <h2 style="font-size:54px">Build Your Position <u>in Maadi Early.</u></h2>
    <p class="lede">Waddy is assembling its first neighborhood partner network. Joining at the start has simple, practical advantages.</p>
    <div class="bigpts">
      <div class="bigpt"><span class="bn">1</span><div class="rule"></div><b>Be there on day one</b><p>Customers form habits early. The first places they order from are the ones they return to.</p></div>
      <div class="bigpt"><span class="bn">2</span><div class="rule"></div><b>Be part of the launch story</b><p>Waddy’s launch marketing introduces the platform through the businesses on it.</p></div>
      <div class="bigpt"><span class="bn">3</span><div class="rule"></div><b>Start building your record</b><p>Your catalogue, your Spots votes and your regulars start accumulating from your first week.</p></div>
    </div>
    <p class="note" style="margin-top:34px">Waddy does not limit partner numbers or guarantee results for early partners. The advantage is time in the market.</p>`);

  // 22 ── join
  page('mint', null, `
    <div class="join">
      <div style="flex:1">
        <div class="eyebrow">Join Waddy</div>
        <h2 style="font-size:54px">Let’s Grow <u>Maadi Together.</u></h2>
        <div class="steps">
          <div class="step"><span>1</span><div><b>Talk to us</b><p>Tell us about your business and your branches.</p></div></div>
          <div class="step"><span>2</span><div><b>Set up your store</b><p>We build your catalogue with you and train your team.</p></div></div>
          <div class="step"><span>3</span><div><b>Go live in Maadi</b><p>Start receiving orders from your neighborhood.</p></div></div>
        </div>
        <div class="closing">Your brand. Your local branch. Your neighborhood.<br>Your growth partner.</div>
      </div>
      <div class="qr">
        <div class="qtop"><div class="qimg" data-raster><img src="${asset('qr.png')}"></div><div><b>Become a Waddy partner</b><p>Scan to start, or contact your partner manager.</p></div></div>
        <div class="ln"><i>Web</i><span>waddyapp.com</span></div>
        <div class="ln"><i>Phone</i>${ph('Partner Team Phone')}</div>
        <div class="ln"><i>WhatsApp</i>${ph('Partner WhatsApp')}</div>
        <div class="ln"><i>Email</i>${ph('Partner Email')}</div>
        <div class="ln" style="margin-top:18px;font-family:Alexandria;font-weight:700;color:#1EF2A0">Waddy · Made in Maadi, built around you.</div>
      </div>
    </div>`);

  // ── editions ──────────────────────────────────────────────────────────────
  // The partner brochure is the master. Each category edition keeps its whole
  // commercial story and swaps in the pages that are specific to that trade.
  const V = {
    all: { file: 'waddy-partner-brochure', label: 'Partner brochure' },
    restaurants: {
      file: 'waddy-for-restaurants', label: 'For restaurants & cafés', art: 'burger.webp', coverMock: 'top10',
      h1: 'Grow Your Restaurant <u>Beyond the Counter.</u>',
      lede: 'Meet Waddy, the neighborhood delivery and growth platform that puts Maadi’s restaurants and cafés in front of Maadi.',
      chips: ['Top 10 Maadi', 'Waddy Spots', 'Local advertising', 'Our own riders'],
      postTx: 'New on Waddy: one of Maadi’s favorite kitchens, now delivering to your door.', postH: 'New on Waddy: <em>Your Brand</em>', postFt: 'Restaurants in Maadi',
      spot: 'kitchens',
      sigB: ['tint', 'live', 'Built for restaurants · Your menu', 'Your Menu, <u>Exactly How They Like It.</u>',
        'An order that arrives right is an order that gets repeated. Waddy makes it easy for customers to ask for it properly the first time.',
        [['sliders', 'Every item customizable', 'Extras, removals and choices are set by the customer, not guessed by your kitchen.'],
          ['repeat', 'Reorder in seconds', 'Last Friday’s order is one tap away. Habits form around the places that make it easy.'],
          ['eye', 'Clear before checkout', 'Prices, offers and delivery are visible before they commit.']],
        'Fewer wrong orders, fewer refunds, and regulars who order again and again.', 'menu', false],
    },
    grocery: {
      file: 'waddy-for-grocery-stores', label: 'For supermarkets & grocers', art: 'fresh_market.webp', coverMock: 'aisles',
      h1: 'Grow Your Store <u>Beyond the Counter.</u>',
      lede: 'Meet Waddy, the neighborhood delivery and growth platform that lets your fresh aisle sell online the way it sells in store.',
      chips: ['Ripeness choice', 'Salad or cooking', 'Local advertising', 'Our own riders'],
      storyH: 'Your weekly grocery, picked your way.', spot: 'grocers',
      discover: ['Be Where Your <u>Neighborhood Shops.</u>', 'Your store on Waddy is laid out the way people already shop it, in front of the households around you.',
        [['grid', 'Shop by aisle', 'Produce, dairy, bakery, snacks, cleaning and home essentials, each with its own shelf.'],
          ['search', 'Search that stays local', 'Customers who know what they want find it at a store nearby.'],
          ['eye', 'Clear prices before the cart', 'What they see is what they pay. Trust builds basket by basket.'],
          ['tag', 'Your offers, shown up front', 'Offers and free delivery appear on your listing before the store opens.']],
        'They came for milk and found the rest of your store.', 'aisles'],
      sigA: ['teal', 'live', 'Built for grocery · Only on Waddy', 'Ripe Today, or Ripe Thursday. <u>Salad, or Sauce.</u>',
        'Nobody trusts a stranger to pick their tomatoes. Waddy asks the question a good greengrocer asks across the counter, before the item reaches the cart.',
        [['clock', 'Ripeness, on fruit', 'Ready to eat today, or ripe in 2–3 days.'],
          ['leaf', 'Use it for, on vegetables', 'For salad: firm and crisp. For cooking: riper and softer.'],
          ['sliders', 'Only where it is needed', 'Fruit and vegetables ask. Milk and rice ask nothing, so shopping stays fast.']],
        'Customers trust you with fresh produce online, and fresh is what fills a weekly basket.', 'ripeness', true],
      sigB: ['tint', 'live', 'Built for grocery · On your side of the counter', 'One Question for Them. <u>Zero Guessing for You.</u>',
        'The customer’s answer travels with the item, all the way to whoever picks the order in your store.',
        [['tag', 'Written on the order line', '“Bananas · Ripe in 2–3 days.” The instruction sits next to the item it belongs to.'],
          ['lock', 'Never touches price or stock', 'It is a picking note, not a new product. Nothing extra to manage in your catalogue.'],
          ['bag', 'Sell the whole crate', 'Softer produce goes to the cooks who want it instead of staying on the shelf.']],
        'Fewer complaints and refunds for you, and less waste on your shelf.', 'ticket', false],
    },
    pets: {
      file: 'waddy-for-pet-shops', label: 'For pet shops & vet clinics', art: 'pets.webp', coverMock: 'petProfile',
      h1: 'Grow Your Pet Shop <u>Beyond the Counter.</u>',
      lede: 'Meet Waddy, the neighborhood delivery and growth platform that knows every pet by name and sends their owner to your shop.',
      chips: ['Pet profiles', 'Refill reminders', 'Local advertising', 'Our own riders'],
      storyH: 'Everything Luna needs, at your door.', spot: 'pet shops',
      postTx: 'New on Waddy: a pet shop that knows your pet by name.', postH: 'New on Waddy: <em>Your Pet Shop</em>', postFt: 'Pet supplies in Maadi',
      discover: ['Be Where Your <u>Neighborhood Shops.</u>', 'Waddy’s pet home puts shops and clinics in front of the pet owners who live around them.',
        [['grid', 'Shelves by species, then by need', 'Cats, dogs, birds, fish and small pets. Food, treats, litter, toys, grooming and health.'],
          ['paw', 'Picked for their pet', 'A cat owner sees cat food, litter and treats first. Nothing to scroll past.'],
          ['phone', 'Vet clinics, one tap away', 'Clinics are listed with call, WhatsApp and directions, and tags such as open now and home visits.'],
          ['tag', 'Your offers, shown up front', 'Offers and free delivery appear on your listing before the shop opens.']],
        'You are in the pocket of every pet owner nearby.', 'clinic'],
      sigA: ['teal', 'live', 'Built for pet shops · Only on Waddy', 'We Don’t Meet a Customer. <u>We Meet Luna.</u>',
        'Before they shop, owners introduce their pet. From then on, the pet section is built around that animal.',
        [['paw', 'A real profile, per pet', 'Name, species, age and diet, down to “picky eater”. More than one pet per household.'],
          ['sliders', 'A shop that fits them', 'Your products reach the owners who actually need them, at the top of the screen.'],
          ['chat', 'Spoken like someone who knows them', 'Waddy talks about the pet by name, in English and in Arabic.']],
        'Your catalogue meets the right owner, not every owner.', 'petProfile', true],
      sigB: ['tint', 'live', 'Built for pet shops · The usual', '“Luna’s Food Runs Out <u>Thursday.</u>”',
        'Pet supplies are the most repeatable purchase there is. Waddy turns that rhythm into planned orders for your shop.',
        [['repeat', 'Their usual, one tap', 'An “order again” card with the pet’s name on it, ready on the pet home.'],
          ['bell', 'Reminders they choose', 'Every 2, 3, 4 or 6 weeks. The owner sets it once and stops running out.'],
          ['cake', 'Moments that matter', 'A nudge before the bag is empty, on the pet’s birthday, and when it is time for adult food.']],
        'The late-night emergency becomes a planned order, and it comes to you.', 'petUsual', false],
    },
  };
  const v = V[vertical];
  const sub = (i, from, to) => { if (!P[i].html.includes(from)) throw new Error(`edition text not found on page ${i + 1}: ${from}`); P[i].html = P[i].html.split(from).join(to); };
  const feature = ([tone, status, eyebrow, h2, lede, pts, win, mk, flip], i) => {
    const art = `<div style="flex:none">${tilt(phoneHtml(mk))}</div>`;
    const col = `<div class="col"><div class="eyebrow">${eyebrow}</div><h2 style="font-size:40px">${h2}</h2><p class="lede">${lede}</p>
      <ul class="points">${pts.map((q) => pt(...q)).join('')}</ul>
      <div class="win"><em>What it means for you</em><span>${win}</span></div></div>`;
    P[i] = { tone, status, cls: ` p${i + 1}`, html: `<div class="split">${flip ? art + col : col + art}</div>` };
  };

  sub(5, 'The order goes to the right kitchen', 'The order goes to the right branch');
  sub(0, '<i>Partner brochure</i>', `<i>${v.label}</i>`);
  if (vertical !== 'all') {
    sub(0, 'Grow Your Business <u>Beyond the Counter.</u>', v.h1);
    sub(0, 'Meet Waddy, the neighborhood delivery and growth platform built for Maadi.', v.lede);
    sub(0, '<span>Restaurants</span><span>Cafés</span><span>Grocery</span><span>Pet shops</span>', v.chips.map((c) => `<span>${c}</span>`).join(''));
    if (v.coverMock !== 'top10') sub(0, phoneHtml('top10'), phoneHtml(v.coverMock));
    if (v.discover) { const [h2, lede, pts, win, mk] = v.discover; feature(['paper', 'live', '1 · Discover', h2, lede, pts, win, mk, false], 7); }
    if (v.storyH) { sub(8, 'Maadi’s burgers, at your door.', v.storyH); sub(8, 'burger.webp', v.art); }
    if (v.postTx) {
      sub(8, 'Your weekly grocery, picked the way you like it. From stores around you.', v.postTx);
      sub(8, '<div class="img"><h4>Ripe today, <em>or ripe Thursday.</em></h4>', `<div class="img dark"><h4>${v.postH}</h4>`);
      sub(8, 'fresh_market.webp', v.art); sub(8, 'Groceries in Maadi', v.postFt);
    }
    sub(10, 'favorite kitchens', `favorite ${v.spot}`); sub(10, 'burger.webp', v.art);
    if (v.sigA) feature(v.sigA, 12);
    if (v.sigB) feature(v.sigB, 15);
  }

  return { pages: P, STATUS, label: v.label, file: v.file, editions: Object.keys(V) };
};
