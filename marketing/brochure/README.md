# Waddy merchant brochures

B2B sales material for onboarding stores, generated from code so copy and
design stay in one place. Four editions, each in English and Arabic, each as
a PDF and an editable PowerPoint (`out/`):

| Edition | Full (16 pages) | Short (4 pages) |
|---|---|---|
| Partner brochure (all categories) | `waddy-partner-brochure` | `waddy-partner-brochure-short` |
| Restaurants and cafés | `waddy-for-restaurants` | `waddy-for-restaurants-short` |
| Supermarkets and grocers | `waddy-for-grocery-stores` | `waddy-for-grocery-stores-short` |
| Pet shops and vet clinics | `waddy-for-pet-shops` | `waddy-for-pet-shops-short` |

Add `-ar` for the Arabic edition of any of them (e.g. `waddy-for-pet-shops-short-ar`).

**Full edition**: cover, who we are, the problem, the comparison, then **the
offer on page 05** (what it costs, what you keep, how to start risk-free),
branch priority, the growth ecosystem, discovery, one promotion page, two
category pages, delivery, Partner App, first 90 days, and a WhatsApp-first
join page.

**Short edition**: cover, Waddy in one page, the offer, join. Made to be
left on the counter.

Supporting documents are in `docs/`: unconfirmed commercial information,
proposed campaigns, and capabilities to verify.

## Rebuild

```sh
node build.js && python3 make_pptx.py   # everything
node build.js grocery ar short          # one edition / language / length
FINAL=1 node build.js                   # hide the internal status chips
```

Needs Node with Playwright and Python with `python-pptx`.

- `master.js`: the pages and the per-edition differences (English source).
- `terms.js`: commission, fees, settlement, contract and contact details.
  Fill these in and rebuild; every edition updates.
- `ar.js`: the Arabic for every English string. The build lists any string
  that has no Arabic yet, so an edit to the English cannot ship untranslated.
- `mockups.js`: the illustrative phone screens.

The PowerPoint files use Alexandria and Thmanyah Sans from `assets/font/`.
Install them before opening, or lines will re-wrap.
