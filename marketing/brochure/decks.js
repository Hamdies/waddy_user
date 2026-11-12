// Copy for the three merchant brochures.
//
// Truth rule (PRODUCT.md, docs/app_store_listing.md): never promise what the
// app won't do. No order-uplift numbers, no user counts, no commission rates,
// no delivery-time claims. Every feature named here exists in the customer app.

// Fill `value` to print contact details on the last slide; leave it empty and
// the line prints blank for a sales rep to write on.
const CONTACT = [
  { label: 'Name', value: '' },
  { label: 'Phone', value: '' },
  { label: 'WhatsApp', value: '' },
];

// ── slides every deck shares ────────────────────────────────────────────────
const who = {
  type: 'who',
  eyebrow: 'Who we are',
  title: 'In Egypt, <u>“waddy”</u> is what you say when something’s great.',
  lede: 'We built a delivery app that has to live up to its own name. One neighborhood, done properly: Maadi’s food, groceries and pet supplies in a single app, brought to the door by riders customers can watch arrive.',
  facts: [
    { h: 'Local first', p: 'We start with Maadi and the places Maadi already loves. You are a neighbour here, not a row in a national database.' },
    { h: 'One app, three aisles', p: 'Food, groceries and pets live side by side. Someone who opens Waddy for dinner sees your store on the way.' },
    { h: 'The mint one', p: 'Every other delivery app is orange or red. Waddy is mint, so your customers know where they found you.' },
  ],
};

const tracking = (line) => ({
  type: 'feature', tone: 'tint', flip: true, mock: 'tracking',
  eyebrow: 'Delivery they can trust',
  title: 'No more <u>“where’s my order?”</u>',
  lede: `Your work ends well when the order arrives well. ${line}`,
  points: [
    { i: 'pin', h: 'A live map, a live ETA', p: 'Customers watch their rider cross Maadi instead of calling your shop to ask.' },
    { i: 'clock', h: 'Every stage, shown', p: 'Placed, prepared, on the way. They know what is happening before they wonder.' },
    { i: 'lock', h: 'A delivery PIN at the door', p: 'The rider asks for it, so the order reaches the right customer and only them.' },
  ],
  win: 'Fewer phone calls, fewer disputes, and a last impression as good as your first.',
});

const loyalty = (title, lede, win) => ({
  type: 'feature', tone: 'paper', mock: 'xp',
  eyebrow: 'Customers who come back',
  title, lede,
  points: [
    { i: 'bolt', h: 'XP on every order', p: 'Customers level up as they order, with weekly quests that give them a reason to open Waddy again.' },
    { i: 'tag', h: 'Coupons and offers from your store', p: 'Your deals appear on your store before the customer orders, not buried in a banner.' },
    { i: 'gift', h: 'A scratch card in the bag', p: 'A printed code in the delivery turns one order into a reason for the next.' },
  ],
  win,
});

const cta = (title, cardTitle) => ({
  type: 'cta',
  eyebrow: 'Getting started',
  title,
  steps: [
    { h: 'Tell us about your place', p: 'What you sell, where you are, when you’re open.' },
    { h: 'We put your store on Waddy', p: 'Your items, your prices, your photos, set up with you.' },
    { h: 'Go live in Maadi', p: 'Orders come to you. Riders take them to the door.' },
  ],
  cardTitle,
  cardBody: 'Talk to your Waddy partner manager. We’ll walk you through it in one visit.',
});

// ── restaurants ─────────────────────────────────────────────────────────────
const restaurants = {
  file: 'waddy-for-restaurants',
  title: 'Waddy for Restaurants',
  audience: 'For restaurants & cafés',
  slides: [
    {
      type: 'cover', art: 'burger.webp',
      kicker: 'Maadi is hungry.',
      title: 'Be the first name <u>it sees.</u>',
      lede: 'Waddy puts your kitchen in front of the neighborhood that already loves it, then gives them reasons to order again.',
      chips: ['Top 10 Maadi', 'Waddy Spots', 'Live tracking'],
    },
    who,
    {
      type: 'problem',
      eyebrow: 'The problem',
      title: 'On most apps, your restaurant is <u>one row in an endless list.</u>',
      pains: [
        { h: 'Good food, buried', p: 'A customer scrolling hundreds of places across the whole city never reaches the one around the corner.' },
        { h: 'Discounting is the only lever', p: 'When every listing looks the same, the cheapest one wins. That is a race you pay for.' },
        { h: 'One order, then silence', p: 'Someone tries you once and nothing brings them back. You start from zero every night.' },
      ],
      turn: 'Waddy is built the other way round: <b>a smaller stage, a louder spotlight.</b>',
    },
    {
      type: 'feature', tone: 'paper', mock: 'top10',
      eyebrow: 'Get seen',
      title: 'A stage the size of <u>your neighborhood.</u>',
      lede: 'Waddy opens on Maadi, not on the whole city. The first thing a hungry customer sees is the places near them.',
      points: [
        { i: 'trophy', h: 'Top 10 Maadi, ranked', p: 'A ranked list of the neighborhood’s favorites, at the top of the food home.' },
        { i: 'grid', h: 'Found by cuisine', p: 'Egyptian, burgers, pizza, grills, shawarma and more. Customers land on you by craving.' },
        { i: 'tag', h: 'Offers shown up front', p: 'Your offers and free delivery show on your listing before anyone opens the menu.' },
      ],
      win: 'You compete with the street, not with the city. That is a list you can lead.',
    },
    {
      type: 'feature', tone: 'teal', flip: true, mock: 'spots',
      eyebrow: 'Only on Waddy · Spots',
      title: 'Every week, Maadi votes. <u>Then it shows up.</u>',
      lede: 'Waddy Spots is a weekly vote for the neighborhood’s favorite café, restaurant or hangout. Your regulars do your marketing.',
      points: [
        { i: 'users', h: 'One vote per person, every week', p: 'A fair, live leaderboard your customers want to move.' },
        { i: 'trophy', h: 'A champion is crowned', p: 'The spot with the most votes takes the week, in front of everyone using the app.' },
        { i: 'gift', h: 'Five voters win a free item at your place', p: 'Picked at random in a live draw. Waddy runs the draw and winners come through your door.' },
      ],
      win: 'Free word of mouth, a title worth sharing, and new faces walking in to claim a prize.',
    },
    {
      type: 'feature', tone: 'tint', mock: 'menu',
      eyebrow: 'Get chosen',
      title: 'Your menu, <u>exactly how they like it.</u>',
      lede: 'An order that arrives right is an order that gets repeated. Waddy makes it easy to ask for it properly the first time.',
      points: [
        { i: 'sliders', h: 'Every item customizable', p: 'Extras, removals and choices are set by the customer, not guessed by your kitchen.' },
        { i: 'repeat', h: 'Reorder in seconds', p: 'Last Friday’s order is one tap away. Habits form around the places that make it easy.' },
        { i: 'eye', h: 'Clear before checkout', p: 'Prices, offers and delivery are visible before they commit. No surprises, no abandoned carts.' },
      ],
      win: 'Fewer wrong orders, fewer refunds, and regulars who order the same thing again and again.',
    },
    tracking('Waddy shows the customer the whole journey from your counter to their door.'),
    loyalty(
      'The first order is luck. <u>The tenth is design.</u>',
      'Waddy gives customers a reason to return that isn’t a deeper discount from you.',
      'Repeat orders you didn’t have to buy with a price cut.',
    ),
    {
      type: 'moves',
      eyebrow: 'How Waddy grows your restaurant',
      title: 'Three moves. <u>One busier kitchen.</u>',
      moves: [
        { i: 'eye', h: 'Get seen', p: 'Be in front of Maadi the moment it gets hungry.', tools: ['Top 10 Maadi', 'Cuisine browse', 'Waddy Spots'] },
        { i: 'tap', h: 'Get chosen', p: 'Win the order with a clear menu and an honest offer.', tools: ['Customizable items', 'Offers up front', 'Free delivery badge'] },
        { i: 'repeat', h: 'Get reordered', p: 'Turn tonight’s customer into a weekly one.', tools: ['One-tap reorder', 'XP & quests', 'Scratch cards'] },
      ],
    },
    cta('Let’s put your kitchen <u>on the map.</u>', 'Ready when you are.'),
  ],
};

// ── grocery stores ──────────────────────────────────────────────────────────
const grocery = {
  file: 'waddy-for-grocery-stores',
  title: 'Waddy for Grocery Stores',
  audience: 'For supermarkets & grocers',
  slides: [
    {
      type: 'cover', art: 'fresh_market.webp',
      kicker: 'Fresh, the way they’d pick it.',
      title: 'Your shelves, on <u>every phone</u> in Maadi.',
      lede: 'Waddy is the grocery app that asks how ripe, and what it’s for, so your fresh aisle sells online like it does in store.',
      chips: ['Ripeness choice', 'Salad or cooking', 'Shop by aisle'],
    },
    who,
    {
      type: 'problem',
      eyebrow: 'The problem',
      title: 'Nobody trusts a stranger to <u>pick their tomatoes.</u>',
      pains: [
        { h: 'Fresh is where online grocery breaks', p: 'Customers order the packaged goods and still walk to the shop for fruit and vegetables.' },
        { h: 'Wrong ripeness, lost customer', p: 'Green bananas for tonight’s dessert. Soft tomatoes for a salad. One bad basket and they don’t come back.' },
        { h: 'Your picker has to guess', p: 'The order says “1 kg tomatoes”. It never says what the customer is cooking.' },
      ],
      turn: 'Waddy fixes it with <b>one question, asked before the cart.</b>',
    },
    {
      type: 'feature', tone: 'paper', mock: 'ripeness',
      eyebrow: 'Only on Waddy · Ripeness',
      title: 'Bananas for today. <u>Or bananas for Thursday.</u>',
      lede: 'On fruit, Waddy asks the question a good greengrocer asks across the counter: when are you eating it?',
      points: [
        { i: 'check', h: 'Ready to eat', p: 'Ripe and sweet, for today.' },
        { i: 'clock', h: 'Ripe in 2–3 days', p: 'A little firm, ripens at home.' },
        { i: 'sliders', h: 'On the categories that need it', p: 'Fruit asks about ripeness. Milk and rice ask nothing. Shopping stays fast.' },
      ],
      win: 'Customers finally trust you with fruit online, and fruit is what fills a weekly basket.',
    },
    {
      type: 'feature', tone: 'tint', flip: true, mock: 'use',
      eyebrow: 'Only on Waddy · Use it for',
      title: 'Salad tomatoes and sauce tomatoes <u>are not the same tomato.</u>',
      lede: 'On vegetables, Waddy asks what they’re for. Two answers, and your picker knows exactly which crate to reach into.',
      points: [
        { i: 'leaf', h: 'For salad', p: 'Firm and crisp, eaten raw.' },
        { i: 'bolt', h: 'For cooking', p: 'Riper and softer, cooks down well.' },
        { i: 'bag', h: 'Sell the whole crate', p: 'Softer produce goes to the cooks who want it, instead of being left on the shelf.' },
      ],
      win: 'The right vegetable to the right kitchen: fewer complaints for you, less waste on your shelf.',
    },
    {
      type: 'feature', tone: 'teal', mock: 'ticket',
      eyebrow: 'On your side of the counter',
      title: 'One question for them. <u>Zero guessing for you.</u>',
      lede: 'The customer’s answer travels with the item, all the way to whoever picks the order.',
      points: [
        { i: 'tag', h: 'Written on the order line', p: '“Bananas · Ripe in 2–3 days.” The instruction sits next to the item it belongs to.' },
        { i: 'lock', h: 'Never touches price or stock', p: 'It is a picking note, not a new product. Nothing extra to manage in your catalogue.' },
        { i: 'check', h: 'The customer must answer', p: 'No produce reaches the cart without it, so no order arrives at your store unclear.' },
      ],
      win: 'Your team picks like they know the customer, because now they do.',
    },
    {
      type: 'feature', tone: 'paper', flip: true, mock: 'aisles',
      eyebrow: 'Your store, online',
      title: 'The whole shop, <u>aisle by aisle.</u>',
      lede: 'Your store on Waddy is laid out the way people already shop it, with nothing hidden until checkout.',
      points: [
        { i: 'grid', h: 'Shop by aisle', p: 'Produce, dairy, bakery, snacks, cleaning and home essentials, each with its own shelf.' },
        { i: 'search', h: 'Search for exactly that', p: 'Customers who know what they want find it in one step.' },
        { i: 'eye', h: 'Clear prices before the cart', p: 'What they see is what they pay. Trust builds basket by basket.' },
      ],
      win: 'Bigger baskets: they came for milk and found the rest of your store.',
    },
    tracking('Fresh food should not sit in a bag while a customer wonders where it is.'),
    loyalty(
      'Groceries are a habit. <u>Be the habit.</u>',
      'A household that shops with you weekly is worth more than a hundred one-off orders. Waddy rewards the weekly shop.',
      'A reason to do the next weekly shop with you, not with whoever is open.',
    ),
    {
      type: 'moves',
      eyebrow: 'How Waddy grows your store',
      title: 'Three moves. <u>One fuller basket.</u>',
      moves: [
        { i: 'eye', h: 'Earn trust', p: 'Win the fresh aisle, the one other apps lose.', tools: ['Ripeness choice', 'Salad or cooking', 'Clear prices'] },
        { i: 'cart', h: 'Fill the basket', p: 'Make the whole store easy to walk through on a phone.', tools: ['Shop by aisle', 'Search', 'Offers up front'] },
        { i: 'repeat', h: 'Own the weekly shop', p: 'Bring the same household back every week.', tools: ['Buy again', 'XP & quests', 'Scratch cards'] },
      ],
    },
    cta('Let’s put your shelves <u>in every kitchen.</u>', 'Ready when you are.'),
  ],
};

// ── pet shops & vets ────────────────────────────────────────────────────────
const pets = {
  file: 'waddy-for-pet-shops',
  title: 'Waddy for Pet Shops',
  audience: 'For pet shops & vet clinics',
  slides: [
    {
      type: 'cover', art: 'pets.webp',
      kicker: 'Who’s the boss at home?',
      title: 'We don’t meet a customer. <u>We meet Luna.</u>',
      lede: 'Waddy knows every pet by name, what they eat and when it runs out. Then it sends their owner to your shop.',
      chips: ['Pet profiles', 'Refill reminders', 'Vet listings'],
    },
    who,
    {
      type: 'problem',
      eyebrow: 'The problem',
      title: 'Pet food runs out on a schedule. <u>Your sales shouldn’t be a surprise.</u>',
      pains: [
        { h: 'The bag is empty at 10 pm', p: 'The owner buys from whoever is closest and open. Your regular just became someone else’s.' },
        { h: 'Dog food shown to cat people', p: 'A generic shop shows everything to everyone, so owners scroll past what they need.' },
        { h: 'You know the pet. The apps don’t.', p: 'In store you ask about Luna by name. Online, she is an anonymous order number.' },
      ],
      turn: 'Waddy remembers the pet, <b>so the owner remembers your shop.</b>',
    },
    {
      type: 'feature', tone: 'paper', mock: 'petProfile',
      eyebrow: 'Only on Waddy · Pet profile',
      title: '“Everything <u>Luna</u> needs.”',
      lede: 'Before they shop, owners introduce their pet. From then on, the pet section is built around that animal.',
      points: [
        { i: 'paw', h: 'A real profile, per pet', p: 'Name, species, boy or girl, age and diet, down to “picky eater”. More than one pet per household.' },
        { i: 'sliders', h: 'A shop that fits them', p: 'A cat owner sees cat food, litter and treats first. Nothing to scroll past.' },
        { i: 'chat', h: 'Spoken like someone who knows them', p: 'Waddy talks about the pet by name, in English and in properly gendered Arabic.' },
      ],
      win: 'Your products meet the owners who actually need them, at the top of the screen.',
    },
    {
      type: 'feature', tone: 'teal', flip: true, mock: 'petUsual',
      eyebrow: 'Only on Waddy · The usual',
      title: '“Luna’s food runs out <u>Thursday.</u>”',
      lede: 'Pet supplies are the most repeatable purchase there is. Waddy turns that rhythm into orders for your shop.',
      points: [
        { i: 'repeat', h: 'Their usual, one tap', p: 'An “order again” card with the pet’s name on it, ready on the pet home.' },
        { i: 'bell', h: 'Reminders they choose', p: 'Every 2, 3, 4 or 6 weeks. The owner sets it once and stops running out.' },
        { i: 'clock', h: 'A nudge before the bag is empty', p: 'Waddy estimates the next refill from how the customer really orders, and reminds them in time.' },
      ],
      win: 'The 10 pm emergency becomes a planned order, and it comes to you.',
    },
    {
      type: 'tiles', tone: 'tint',
      eyebrow: 'Helpful, never spammy',
      title: 'We show up for the moments <u>that matter to them.</u>',
      lede: 'Owners love their pets more than they love any app. Waddy earns its place by getting the timing right.',
      items: [
        { i: 'cake', h: 'Birthdays', p: 'A message on the pet’s birthday. The easiest day of the year to sell a treat.' },
        { i: 'paw', h: 'Growing up', p: '“Luna turns 1, time for adult food.” Life-stage moments for cats and dogs, at one and at seven.' },
        { i: 'bell', h: 'On the owner’s terms', p: 'Reminders can be switched off per pet. Automatic nudges are limited to once a week.' },
        { i: 'clock', h: 'Daytime only', p: 'No messages late at night. A reminder should feel like a favour, not an alarm.' },
        { i: 'grid', h: 'Shelves by species, then by need', p: 'Cats, dogs, birds, fish and small pets. Food, treats, litter, toys, beds, grooming, health.' },
        { i: 'bolt', h: 'Rewards on every order', p: 'XP, weekly quests and coupons give owners one more reason to refill through Waddy.' },
      ],
    },
    {
      type: 'feature', tone: 'paper', mock: 'clinic',
      eyebrow: 'For vet clinics',
      title: 'The vet they find <u>when they need one.</u>',
      lede: 'Clinics have their own place on Waddy’s pet home, in front of pet owners near you. No ordering, no delivery, just a direct line.',
      points: [
        { i: 'phone', h: 'Call, WhatsApp or directions', p: 'One tap each. Owners reach your front desk the way they already prefer.' },
        { i: 'check', h: 'What you treat, at a glance', p: 'Open now, 24/7, home visits and the animals you see, shown as tags on your card.' },
        { i: 'pin', h: 'Nearest first', p: 'Owners see the clinics around them, with your opening hours on the card.' },
      ],
      win: 'You are in the pocket of every pet owner nearby, on the day their pet needs you.',
    },
    tracking('A heavy bag of food or litter, carried to the door and tracked the whole way.'),
    {
      type: 'moves',
      eyebrow: 'How Waddy grows your shop',
      title: 'Three moves. <u>One loyal pack.</u>',
      moves: [
        { i: 'paw', h: 'Know the pet', p: 'Start with the animal, not the catalogue.', tools: ['Pet profile', 'Species shelves', 'Picked for them'] },
        { i: 'bell', h: 'Catch the refill', p: 'Be there just before the bag runs out.', tools: ['The usual', 'Reminders', 'Refill nudges'] },
        { i: 'repeat', h: 'Keep them for life', p: 'Grow with the pet, from kitten to senior.', tools: ['Birthdays', 'Life stages', 'XP & coupons'] },
      ],
    },
    cta('Let’s introduce your shop <u>to Maadi’s pets.</u>', 'Luna is waiting.'),
  ],
};

module.exports = { decks: [restaurants, grocery, pets], CONTACT };
