# Master catalogue plan (`CAT-*`)

Status: **phases 1–2 live 2026-09-29 — 84 catalogue products, 187 supermarket listings linked; phase 3 built, deploy pending**; phases 4–8 open. Numbered phases below are the live order.

Goal: move grocery from "one product row per store" to the model talabat, Instacart and
Amazon use — **one catalogue entry per real product** (content: name, photos,
description, brand, size, category, barcode) and **one listing per store that sells
it** (price, stock, discount, on/off). Content is written once; stores only own the
commercial facts.

## Master status

| ID | Finding | Severity | Status | Phase |
|---|---|---|---|---|
| CAT-01 | Product content is copied per store; edits and photos land on one copy only (Garnier #1310 Metro has no image, #1312 Gourmet does) | High | in progress — 187 supermarket listings linked to 84 products (P2, 09-29), Garnier included; edits still land per listing until P3 | 1–3 |
| CAT-02 | No product identity: nothing says two rows are the same product. No barcode/GTIN column anywhere | High | partial — `catalog_products.barcode` exists (nullable, unique); stays open until most products carry one (decision 2) | 1 |
| CAT-03 | Deleting a product deletes its image files (`Admin/ItemController.php:842–847`). Once listings share files, deleting one listing breaks the photo for every store | High — blocker for sharing files | **fixed** (P1, live 09-29) | 1 |
| CAT-04 | Four write paths edit content with no notion of a shared source: admin form, vendor web (`Vendor/ItemController`), store-app API (`Api/V1/Vendor/ItemController`), bulk import | High | fixed server-side (P3, deploy pending) — also approval + remove-image paths; store-app UI in P6 | 3, 6 |
| CAT-05 | Product Gallery (`ItemController::product_gallery`) copies a product into another store — duplication by design | Medium | open | 4 |
| CAT-06 | Search and browse return the same product once per store (3× Garnier in results) | Medium | open | 7 |
| CAT-07 | Bulk import creates standalone rows; a store can't onboard by uploading barcodes + prices | Medium | open | 5 |
| CAT-08 | `items.category_ids` position convention differs: admin form writes 1 = category / 2 = sub; the admin + vendor **bulk importers** and my seeders wrote 0 / 1. Not harmless: `CentralLogics/item.php:857,1324` take `position == 1` as the main category, so 0/1 rows surface their sub-category in the categories returned with store/search item lists | Low | **fixed** (P1, live 09-29: 189 of 304 items shifted) | 1 |
| CAT-09 | Specialty stores' own products (Sindbad's feteer, a butcher's cuts) are unique to that store — they don't belong in a shared catalogue | Info — design decision | decided: listings may have no catalogue product | 1 |
| CAT-10 | Food module is out of scope: a restaurant's dishes are its own, never shared | Info — design decision | decided | — |
| CAT-11 | Nothing stops a store holding two listings of one product; phase 4's merge creates exactly that whenever both merged products were sold by the same store | High | partial — unique index landed (P1); merge logic is phase 4 | 1, 4 |
| CAT-12 | Silently dropping a vendor's content edit on a linked listing reads as "the app is broken" (title changes, then reverts) | Medium | fixed server-side (P3, deploy pending): `content_managed` + message in every response; vendor web shows a warning toast + notice; store app shows the `message` | 3, 6 |
| CAT-13 | With barcode optional, name + unit grouping misses Arabic/English variants ("لبن جهينة" vs "Juhayna Milk") and can merge look-alikes ("Milk 1L", two brands) — phase 2 is the riskiest step | High | open | 2 |
| CAT-14 | Save-time propagation is one write per linked listing; fine at Maadi scale, slow once a product is sold by many stores | Low | open — inline only for now (max 4 listings per product); queued path waits on CAT-17 | 3 |
| CAT-15 | `catalog_content_backup` holds old image filenames; if CAT-03's helper later deletes those files as unreferenced, `--rollback` restores paths to missing files | High | partial — helper treats backup names as references (P1); backfill must also delete nothing (P2) | 1, 2 |
| CAT-16 | Merge re-points carts/favourites; a user holding BOTH listings ends with duplicate rows (neither table has a unique index in the migrations — base tables from the SQL dump unverified) | Medium | open | 4 |
| CAT-18 | Deleting a product still deletes its photo from **order history**: `order_details.item_details` snapshots name the file, and the CAT-03 helper doesn't scan that table (large; LIKE over JSON on every delete). Pre-existing, not caused by the catalogue | Low | open — fix by keeping product files on delete once CAT-01 lands (orphans pruned by `catalog:prune-images`, which can afford the scan) | 2 |
| CAT-17 | Queued propagation fails silently if no worker runs: catalogue shows the new photo, stores keep the old one, no error. `.env.example` has `QUEUE_CONNECTION=sync`; live server has a `queue.log` but its worker setup is unverified | Medium | open | 3 |

## Verify on device / admin

Appended as phases land; tick when checked.

- [x] (P1) Deploy: `php artisan migrate` runs `2026_09_29_000002` + `000003` cleanly on the live DB (09-29)
- [x] (P1) `catalog:normalize-category-ids` — 304 scanned, 189 shifted 0/1 → 1/2, 0 unreadable (09-29)
- [ ] (P1) Admin: remove one gallery image of a product → other products' photos unaffected; the removed file is gone if nothing else used it
- [ ] (P1) Vendor edit with product approval ON, no new photo → approve it → the product keeps its photo (was: deleted by the approval)

- [x] (P2) Backfill report reviewed: every multi-store group had identical names, prices and categories; no brand mixing (09-29 — run live without a separate dry run, reviewed from its output)
- [ ] (P3) Admin: edit Gourmet's Garnier photo → toast says "all 3 stores"; Seoudi and Metro show the new photo in the app
- [ ] (P3) Admin edit form of a linked product shows the blue "Shared product, sold by N stores" notice
- [ ] (P3) Vendor web: change a linked product's title and price → orange toast; price saved, title unchanged
- [ ] (P3) Change Metro's price → Gourmet's price unchanged
- [ ] (P3) Delete Metro's listing → Gourmet's photo still loads
- [ ] (P3) Store app: change a linked product's title → the snackbar says name/photos are managed by Waddy; price change saved
- [x] (P2) Undo: `catalog:backfill --rollback --group=…` restored 10 listings and removed 6 emptied products on live (09-29)
- [ ] (P2) App: Metro's and Seoudi's Garnier Micellar Water now show Gourmet's photo + description
- [ ] (P2) App: Bakery aisle — does the now-empty "Flatbread" sub-category (171) show as an empty tab? If so, hide or delete it
- [ ] (P4) Merge two catalogue products both sold by Metro → Metro keeps ONE listing; its cart rows, favourites and reviews moved to it
- [ ] (P4) A user with BOTH merged listings in cart ends with one line, quantities added; in favourites, one row
- [ ] (P2) After backfill + rollback, every restored listing's image still loads
- [ ] (P3) Stop the queue worker, save a product with >25 listings → admin list flags it as drifted; start the worker → flag clears
- [ ] (P4) Admin catalogue: create product with barcode, "add to stores" with per-store price
- [ ] (P5) Upload a CSV of barcode + price + stock for a store → matched rows become listings, unknown barcodes land in the review queue
- [ ] (P6) Store app (waddi_store): adding a product searches the catalogue first; editing a linked product can change price/stock only
- [ ] (P7) Search "garnier" shows the product once with "at 3 stores", cheapest first

---

## 1. Target model

```
catalog_products                     items  (existing table = the LISTING)
────────────────                     ─────────────────────────────────────
id                                   id                  ← cart, orders, favourites,
module_id                            catalog_product_id ─┐   reviews all key on this;
barcode   (unique, nullable)         store_id            │   none of them change
name, description        ──copied──▶ name, description   │
image, images            ──copied──▶ image, images       │  content: written by the
brand, unit, size_value  ──copied──▶ unit_id …           │  catalogue, read-only on a
category_id / category_ids ─copied─▶ category_id …       │  linked listing
translations (morph)     ──copied──▶ translations        │
status                               price, discount,  ◀─┘  commercial: owned by the store
                                     stock, status, is_approved …
```

### The key decision: listings ARE the existing `items` rows

Everything that sells — cart, checkout, order placement, the order snapshot
(`order_details.item_details` is a full JSON copy of the item, `PlaceNewOrder.php:1190`),
favourites, reviews, the store app, every customer API — keys on `items.id`. Keeping
`items` as the listing means **none of those paths change**. The catalogue is a new
table that sits *beside* it.

Content is **denormalized**: when a catalogue product is saved, its content is copied
onto every linked listing. Reads stay exactly as they are today; only writes learn
about the catalogue. That is the strangler approach — the new model is live after
phase 3 without touching a single read path. Phase 7 can later switch reads to the
catalogue and drop the copies, if and when it's worth it.

Rejected: replacing `items` with a catalogue + a thin listings table. Correct in the
abstract, but it rewrites cart, checkout, orders, search, the store app and every
formatter at once, on a live database.

### Which listings get a catalogue product

- **Supermarket stores** (store type "Supermarkets"): every listing links to one.
- **Specialty stores** (see `grocery-specialty-stores`): optional. A roastery's
  "Turkish Coffee 250g" may link; Sindbad's own feteer does not. `catalog_product_id`
  is nullable and an unlinked listing behaves exactly as items do today (CAT-09).
- **Food:** never (CAT-10).

### Identity

`barcode` (EAN-13 / GTIN) is the key the industry matches on — stores' POS exports,
brand feeds and supplier sheets all carry it. Nullable, because fresh produce and
loose goods have none; those are matched by name + unit and curated by hand.

---

## 2. Phases

### Phase 1 — Schema + safety (CAT-02, CAT-03, CAT-08)
- `catalog_products` table (above) + `Translation` morph support.
- `items.catalog_product_id` (nullable, indexed).
- **Fix CAT-03 first:** item delete / image replace only deletes a file when no other
  item and no catalogue product references it. Until this lands, nothing may share files.
- Pick one `category_ids` convention (admin's 1/2) and normalise existing rows (CAT-08).
- **Unique `(store_id, catalog_product_id)` on `items`** (CAT-11). MySQL allows many
  NULLs under a unique index, so unlinked listings are unaffected.
- `items.catalog_linked_at` + `catalog_content_backup` (JSON): set when a listing is
  linked, holding the content it had before. This is what makes phase 2 undoable.

#### Phase 1 — concrete tasks

Nothing here is visible to customers or stores; every step deploys on its own.

| # | Task | Touches |
|---|---|---|
| 1.1 | Migration `create_catalog_products_table`: `module_id`, `barcode` (unique, nullable), `name`, `description`, `image`, `images` (JSON), `brand`, `unit_id`, `size_value`, `category_id`, `category_ids` (JSON, 1/2 convention), `status`, `last_propagated_at`, timestamps | new migration |
| 1.2 | Migration `add_catalog_columns_to_items`: `catalog_product_id` (nullable, indexed), `catalog_linked_at`, `catalog_content_backup` (JSON), unique `(store_id, catalog_product_id)` | new migration |
| 1.3 | `CatalogProduct` model (translations morph, `listings()` hasMany Item); `Item::catalogProduct()` belongsTo | 2 models |
| 1.4 | **CAT-03:** one helper `Helpers::deleteProductImageIfUnreferenced($file)` — deletes only when no other `items.image/images`, no `catalog_products.image/images` **and no `items.catalog_content_backup`** references the file (CAT-15: otherwise a rollback restores a path to a deleted file). Replace all 19 raw `check_and_delete('product/' …)` / image-replace sites: Admin `ItemController` (8), Vendor `ItemController` (6), API Vendor `ItemController` (5) | 3 controllers + helpers |
| 1.5 | **CAT-08:** `catalog:normalize-category-ids --dry-run` — rewrites `items.category_ids` written 0/1 to admin's 1/2; prints counts first | new command |
| 1.6 | Verify: deleting a product whose image file another product also uses leaves the file in place (seed two rows sharing one filename, delete one) | manual check |

**Landed 2026-09-29 (waddy_back, uncommitted):**
- 1.1 `2026_09_29_000002_create_catalog_products_table`. Two deviations from the table above: `brand_id` (the platform's `brands` table, as `ecommerce_item_details` uses) instead of free-text `brand`; and `image_storage` for the main image's disk (items keep it in the `storages` morph table — phase 3 propagation must write that row explicitly, because `Item::saved` stamps the *current* disk on any image change).
- 1.2 `2026_09_29_000003_add_catalog_columns_to_items_table` — unique index named `items_store_catalog_product_unique`.
- 1.3 `App\Models\CatalogProduct` (`listings()` bypasses `StoreScope` + `ZoneScope`, so a zone admin's save still reaches every store; `scopeDrifted()` for CAT-17). `Item::catalogProduct()`; `catalog_content_backup` is `$hidden`, so it never enters an API payload or an order's `item_details` snapshot.
- 1.4 `Helpers::deleteProductImageIfUnreferenced($image, $exceptItemId, $exceptTempProductId)` + `Helpers::updateProductImage()` (replaces `Helpers::update('product/', …)`: uploads first, deletes the old file only if unreferenced, keeps the old image if the upload fails). References checked: `items.image/gift_image/images`, `temp_products.image/gift_image/images`, `catalog_products.image/images`, and any `items.catalog_content_backup`. Substring match, so every historical `images` shape counts (incl. double-encoded). A failed lookup keeps the file. All 19 sites converted (Admin 8, Vendor web 6, store-app API 5); `remove_image` now deletes *after* rewriting the row so the row's own main image still counts. **Also fixes a live bug:** a vendor edit under product approval deleted the live item's photo when the pending copy shared its file.
- 1.5 `catalog:normalize-category-ids [--dry-run]` over `items` + `temp_products`; shifts only rows whose lowest position is 0, leaves `updated_at` alone (phase 2 picks "most recent" by it). The four bulk-import sites (Admin + Vendor `ItemController`) and both seeders now write 1/2, so the fix holds.
- 1.6 Checked against an in-memory SQLite copy of the columns (9 cases: shared file kept, own file deleted, temp↔live sharing kept both ways, backup name kept, catalogue file kept, double-encoded JSON matched, `def.png` never deleted). Not yet checked on MySQL — see the P1 verify items.

### Phase 2 — Backfill with a dry run (CAT-01)
- Artisan command `catalog:backfill --dry-run`: groups supermarket listings by
  normalised name + unit within the module, picks the richest copy (has image > has
  description > most recent) as the catalogue content, prints every group.
- You review the report. A group is **flagged, and not linked unless you approve it**, when
  its members differ materially (CAT-13): brand words differ, price spread > 30%,
  images present on some but different files, or unit/size text differs. Arabic-only and
  English-only rows are never auto-merged — they are listed as "possible match" pairs for
  a human to confirm.
- Then run it for real: creates catalogue products, links listings, copies the chosen
  content to all of them — Metro's Garnier gets Gourmet's photo here. Each linked
  listing keeps its previous content in `catalog_content_backup`.
- The backfill **deletes no image files**, even ones no longer shown anywhere (CAT-15).
  A separate `catalog:prune-images` runs only after you've accepted the result, and it
  also skips anything still named in a `catalog_content_backup`.
- `catalog:backfill --rollback` restores that content and unlinks — per group or all.
  Take a DB backup before the real run as well; the rollback is the fine-grained undo,
  the backup is the safety net.

#### Phase 2 — built 2026-09-29 (waddy_back, not yet run on live)

**Change from the bullets above: the unit is NOT part of the group key.** Live data has
Garnier #1312 (Gourmet, the only copy with a photo) with unit "كيلوجرام" and #1308/#1310
with none — keying on unit would have split the headline example. The key is the
normalised name only; a unit difference is a blocking flag you approve.

- `App\Services\CatalogMatcher` — normalisation that only removes *format* differences
  (case, punctuation, accents, "1.5 L"→"1.5l", "6 x 1.5L"→"6x1.5l", Arabic letter variants
  and digits). Never drops words or converts units (1000g ≠ 1kg). Group key =
  `g` + 7 hex of sha1(module|normalised name) — stable between the dry run and the real run.
  `isPossibleMatch()`: same size token and (≥60% word overlap, or one name's words all
  inside the other's).
- `App\Services\CatalogService` — `createFromListing`, `linkListing` (backup taken once,
  on first link), `applyContent` (phase 3's propagation will reuse it), `restoreListing`.
  Query builder only (the Item `saved` hook would stamp the wrong disk); writes the
  `storages` disk rows and name/description translations explicitly. Deletes no files.
- `catalog:backfill` options: `--dry-run`, `--approve=KEYS`, `--merge=KEY_A,KEY_B`
  (repeat per set; a merge is an approval), `--store=IDS`, `--all` (also list single-store
  groups), `--rollback [--product=IDS]`, `--force`. Every run saves a JSON report to
  `storage/app/catalog/`.
- Blocking flags (group is HOLD until approved): `same_store_twice`, `units_differ`,
  `price_spread` (>30%), `different_photos` (by file checksum — same bytes under two names
  is one photo). Note only: `category_differs`. When a store has a product twice, the
  richest copy links and the other stays unlinked (CAT-11's unique index).
- Rollback deletes only catalogue products *it* emptied (rows + translations, no files).
- Checked end to end on in-memory SQLite: Metro's Garnier gets Gourmet's photo,
  description, unit and Arabic name; keeps its price; its old photo sits in the backup
  and is protected by the CAT-03 helper; held groups untouched; rollback restores photo,
  description, unit and translations exactly and empties the catalogue; no file deleted.

**Expected on live** (from the public API, 178 supermarket listings): ~78 groups, 50 sold at
2–3 stores, 28 single-store. Garnier will be HOLD on `units_differ` — the report shows
#1312's "كيلوجرام" on a 100ml bottle, which the catalogue would copy to all three; fix
#1312's unit in the admin first or approve knowingly. Possible matches to judge:
tomatoes / fresh tomatoes, baladi bread / egyptian baladi bread (likely the same);
Juhayna full cream milk / Juhayna UHT milk and "full cream fresh milk" / Juhayna milk
(different products — do not merge).

**Live run 2026-09-29:** 87 groups (50 multi-store incl. a 4th supermarket, Adam
Supermarket #385/#386; 37 single-store) → 86 catalogue products, 186 listings linked. Held:
Garnier `gb63009f` (units_differ — #1312 "Kilogram"). Possible matches found, all linked as
*separate* products because the run was real, not dry:

| Pair | Call |
|---|---|
| `gda62526` Fresh Tomatoes 1kg ~ `gc522c3c` Tomatoes 1kg | merge — Seoudi has both (#220 at 25 LE, #450 at 22): switch #220 off first |
| `g7fa740a` Fresh Cucumbers 1kg ~ `gc3eeaa2` Cucumbers 1kg | merge |
| `gbcf261d` Egyptian Baladi Bread 10pcs ~ `g097de14` Baladi Bread 10pcs | merge — Seoudi has both (#225, #473): switch #225 off first |
| `g3c37586` Juhayna Full Cream Milk 1L ~ `g69452ec` Full Cream Fresh Milk 1L | keep apart (branded vs generic) |
| `g3c37586` Juhayna Full Cream Milk 1L ~ `gbcdce40` Juhayna Full Cream UHT Milk 1L | keep apart (fresh vs UHT) |
| `g8f815dc` Crystal Sunflower Oil 1L ~ `g30ab34a` Sunflower Oil 1L | keep apart (branded vs generic) |

Follow-up (09-29): `--rollback --group=KEYS` (undo by report key) and, within one store,
the switched-on copy is the one that *links*. Content source order is photo > description >
switched on > recent — so a switched-off copy with a description still donates content.
Merging already-linked groups = group rollback, then re-run with `--merge`.

**Merge run 2026-09-29:** Garnier unit cleared (#1312 → no unit), Seoudi #220/#225 switched
off, 3 pairs rolled back by group and re-run merged → 4 products, 11 listings. Results:
- Tomatoes: source was switched-off #220 (only copy with a description), so all four
  listings are named "Fresh Tomatoes 1kg" with its description; category unchanged (8).
- Bread: source #225 → "Egyptian Baladi Bread 10pcs", and the three listings moved from
  Bakery › Flatbread (171) to Bakery › Egyptian Baladi Bread (28). **Flatbread is now empty.**
- Cucumbers: Metro #230's content onto Adam #377. Garnier: #1312's photo + description onto
  Seoudi #1308 and Metro #1310 — the first customer-visible CAT-01 fix.
- Unlinked supermarket listings left: #220, #225 (switched-off duplicates).

Kept as-is by default (richer content, same aisle). To prefer a specific source instead,
a `--source=ITEM_ID` option would be needed — not built.

Known limit: a listing joining an *existing* catalogue product on a later run is
flagged only against the other new listings, not against the ones already linked.

### Phase 3 — Write path: catalogue owns content (CAT-01, CAT-04)
- `CatalogService::save()` writes the catalogue product then propagates content +
  translations + category to every linked listing, in one transaction.
- Admin item form: on a linked listing, content fields are read-only with "Edit in
  catalogue"; price / discount / stock / status stay editable.
- Vendor web + store-app API: the same rule server-side. Content fields on a linked
  listing are not applied — **but not silently** (CAT-12): the save succeeds (so old
  store-app builds keep working) and the response carries
  `content_managed: true` + a translated message ("Name and photos are managed by Waddy
  — send a correction instead"). The vendor web shows it as a notice; phase 6 surfaces
  it in waddi_store.
- **Suggest a correction** (vendor web + store app): a vendor who spots a wrong title or
  photo files a correction into the same review queue as new-product requests (phase 5).
  This is how "no override" (decision 3) stays fair to stores.
- Propagation (CAT-14): inline in the save transaction up to ~25 linked listings; above
  that, the catalogue row saves inline and the copy runs as a queued job
  (`PropagateCatalogProduct`), idempotent so a retry is harmless.
- **Queue prerequisites (CAT-17), before the queued path is enabled:** confirm
  `QUEUE_CONNECTION` on the server is not `sync`, a supervisor/systemd worker is running
  `queue:work` and restarts on deploy, and `failed_jobs` exists. Each catalogue product
  gets `last_propagated_at`; the admin catalogue list flags any product whose
  `updated_at` is newer (drift = worker down or job failed). Until the worker is
  verified, propagation stays inline for every product regardless of listing count.

#### Phase 3 — built 2026-09-29 (waddy_back, not yet deployed)

**Change from the bullets above: the admin form is the catalogue editor for now.** Locking
content with an "Edit in catalogue" link would leave nowhere to edit it until phase 4, and
decision 1 makes the admin the catalogue team. So an admin save on a linked listing *is*
the catalogue save; the form shows "Shared product, sold by N stores — name, description,
photos, unit and category changes apply to all of them". Phase 4 adds the dedicated screens.

`CatalogService`:
- `syncFromListing($itemId)` — admin path: listing content → catalogue product (incl.
  translations, disk, size) → `propagate()` to every listing; then deletes photos the
  product stopped showing, via the CAT-03 helper (so backup-named files survive).
- `propagate($product)` — inline, one transaction, stamps `last_propagated_at` after the row.
- `reassertContent($itemId)` — store path: puts the catalogue's content back after the
  store's save (price/stock/status stand), deletes the store's now-unused upload, returns
  whether content had changed.
- `withoutManagedContent($row, $catalogProductId)` — bulk import strips content (+ slug)
  from linked rows.

Wired: Admin `update` (sync; toast "now shows at all N stores"), `remove_image` (sync),
`approved` (reassert — approving a store's pending edit applies price/stock only),
`bulk_import_data` (strip). Vendor web `update` (reassert; approval path answers
`catalog_content_managed_pending` up front), `remove_image` on a linked listing (refused),
`bulk_import_data` (strip), edit-page notice, warning toast when `content_managed`.
Store-app API `update` (reassert; message + `content_managed: true`; approval path too).
Strings in `resources/lang/{en,ar}/messages.php`: `catalog_product_updated_for_stores`,
`catalog_content_managed`, `catalog_content_managed_pending`, `catalog_content_managed_short`,
`catalog_shared_notice`, `catalog_vendor_notice`.

Checked on SQLite (15 cases): admin edit reaches all listings incl. Arabic name, prices
untouched, not drifted; the first catalogue photo survives while rollback backups name it
and a later replaced photo is deleted; vendor title + upload reverted/removed while price
and stock stay; a price-only save reports no content change; bulk rows stripped only when linked.

Deferred: **suggest a correction** → phase 5 (it files into the review queue built there).
**Queued propagation** (`PropagateCatalogProduct`) not built — inline until the worker is
verified (CAT-17). Vendor web content fields are not disabled, only explained + enforced.

### Phase 4 — Admin catalogue UI (CAT-05)
- Catalogue list / search (name, barcode) / create / edit, with images and translations.
- "Add to stores": pick stores, enter price + stock per store → creates listings.
- "Merge duplicates": pick two catalogue products → one survives, listings re-point.
  When a store has a listing on BOTH (CAT-11), it keeps one: the survivor listing is
  the one with stock, else the more recently updated. The other listing's `carts`,
  `wishlists` and `reviews` rows are re-pointed to the survivor; its `order_details`
  are left as they are (history — each row already holds its own `item_details`
  snapshot); then it is unlinked and switched off, not deleted.
  Campaign/flash-sale rows (`item_campaigns`, `flash_sale_items`) on the loser block
  the merge with a message until removed — they carry their own prices.
  Per-user collisions (CAT-16), resolved row by row before re-pointing: if the user
  already has the survivor in **favourites**, the loser's row is deleted; in the
  **cart**, the loser's quantity is added to the survivor's line (capped at the
  survivor's stock / max-cart quantity) and the loser's line deleted — except when the
  two lines carry different variations/add-ons, which stay separate. **Reviews** always
  move (a user's two reviews are both real).
- Product Gallery becomes "add from catalogue" instead of copying rows.

### Phase 5 — Store onboarding by barcode (CAT-07)
- Upload CSV `barcode, price, stock[, discount]` for a store: known barcodes become or
  update listings; unknown ones go to a **review queue** (`catalog_product_requests`)
  for the catalogue team to approve into the catalogue.

### Phase 6 — Vendor side (CAT-04)
- Vendor web + waddi_store app "add product": search catalogue by name / **scan barcode**
  first; only if missing, submit a new-product request (queue from phase 5). The
  scanner is how barcodes fill in without being mandatory — by the time the catalogue
  reaches a few thousand products, most should already carry one (keeps CAT-02
  closable without reversing decision 2).
- waddi_store shows the `content_managed` notice from phase 3 and the "suggest a
  correction" action.
- Edit screen on a linked listing shows content read-only.

### Phase 7 — Customer-side payoff (CAT-06)
- Search groups results by `catalog_product_id`: one card, "at 3 stores", cheapest or
  nearest first.
- Product page: "Also at Metro · 105 LE".
- Optional: switch reads to the catalogue and stop denormalizing.

### Phase 8 — Scale (when the catalogue passes ~10k products)
- Search index (Meilisearch) instead of SQL `LIKE`.
- Image CDN + variants per catalogue product (not per listing).
- Scheduled price/stock sync from store POS feeds.

---

## 3. Decisions (answered 2026-09-29)

1. **Who may create catalogue products?** → **Admin / catalogue team only.** Vendors
   submit new-product requests into the phase-5 review queue.
2. **Barcode required?** → **Optional.** Consequence to plan for: matching falls back to
   normalised name + unit, so phase 2's dry-run review and phase 4's "merge
   duplicates" tool carry more weight, and phase 5's CSV import must also accept a
   name + unit match (flagged for review) when a row has no barcode. Revisit when the
   catalogue passes a few thousand products — CAT-02 stays open until then.
3. **Store content override?** → **No.** One photo / description per product everywhere;
   a store that sells something different creates its own unlinked listing. Stores keep
   full control of price, discount, stock and on/off, and fix content through "suggest a
   correction" (phase 3). *(Reversing this — letting stores edit content — would change
   phases 3 and 7; decide before phase 3 starts.)*

Plan status: **phase 1 live 2026-09-29; phase 2 built, awaiting its live dry run.** Nothing is linked until you've reviewed the report.
