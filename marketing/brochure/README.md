# Waddy merchant brochures

B2B sales material for onboarding stores, generated from code so copy and
design stay in one place. Four editions, each in English and Arabic, each as
a PDF and an editable PowerPoint (`out/`):

| Edition | English | Arabic |
|---|---|---|
| Partner brochure (all categories) | `waddy-partner-brochure` | `waddy-partner-brochure-ar` |
| Restaurants and cafés | `waddy-for-restaurants` | `waddy-for-restaurants-ar` |
| Supermarkets and grocers | `waddy-for-grocery-stores` | `waddy-for-grocery-stores-ar` |
| Pet shops and vet clinics | `waddy-for-pet-shops` | `waddy-for-pet-shops-ar` |

Every edition is 22 pages and tells the same commercial story. The category
editions swap in their own cover, discovery page, ad creatives and two
feature pages (pages 13 and 16).

Supporting documents are in `docs/`: unconfirmed commercial information,
proposed campaigns, and capabilities to verify.

## Rebuild

```sh
node build.js && python3 make_pptx.py   # everything
node build.js grocery ar                # one edition and/or one language
FINAL=1 node build.js                   # hide the internal status chips
```

Needs Node with Playwright and Python with `python-pptx`.

- `master.js`: the pages and the per-edition differences (English source).
- `ar.js`: the Arabic for every English string. The build lists any string
  that has no Arabic yet, so an edit to the English cannot ship untranslated.
- `mockups.js`: the illustrative phone screens.

The PowerPoint files use Alexandria and Thmanyah Sans from `assets/font/`.
Install them before opening, or lines will re-wrap.
