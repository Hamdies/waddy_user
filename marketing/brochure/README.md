# Waddy merchant brochures

Sales material for onboarding stores, generated from code so copy and design stay in one place.

| File in `out/` | What it is |
|---|---|
| `waddy-partner-brochure.pdf` | The 22-page partner brochure (all categories) |
| `waddy-partner-brochure.pptx` | The same brochure as an editable PowerPoint |
| `waddy-partner-brochure-preview.png` | Every page on one sheet |
| `waddy-for-restaurants.pdf` | Category deck: restaurants and cafés |
| `waddy-for-grocery-stores.pdf` | Category deck: supermarkets and grocers |
| `waddy-for-pet-shops.pdf` | Category deck: pet shops and vet clinics |

Supporting documents are in `docs/`: unconfirmed commercial information,
proposed campaigns, and capabilities to verify.

## Rebuild

```sh
node build_master.js && python3 make_pptx.py   # partner brochure, PDF + PPTX
FINAL=1 node build_master.js                    # hide the internal status chips
node build.js                                   # the three category decks
```

Needs Node with Playwright and Python with `python-pptx`. Copy is in
`master.js` (partner brochure) and `decks.js` (category decks).

The PowerPoint uses Alexandria and Thmanyah Sans from `assets/font/`. Install
them before opening it, or lines will re-wrap.
