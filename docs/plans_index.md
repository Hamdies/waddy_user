# Plans index

Every audit plan in `docs/` numbers its findings with a prefix, and the plans
cite each other ("the `S-04` treatment", "twin of `G-03`"). This page maps the
prefixes to their files so a reference can be followed without holding all of
them in your head.

Each plan's own header is the source of truth for its status. The column here
is a snapshot; update it when a plan's header changes.

## ID-prefixed plans

| Prefix | File | Covers | Status (snapshot 2026-09-27) |
|---|---|---|---|
| `M-*` | [module_architecture_plan.md](module_architecture_plan.md) | The module system: how food / grocery / etc. are selected and carried through requests | Phases 0–4 landed 09-15 |
| `F-*` | [food_module_plan.md](food_module_plan.md) | Food end to end: home, store, ranked rail, filters, cart bar | F-01–F-05, F-07 landed; F-06 deploy; F-08 deferred; F-09 open |
| `G-*` | [grocery_module_plan.md](grocery_module_plan.md) | Grocery end to end: home, store, browse/filters, dashboard band | G-01–G-06, G-08 landed; G-07 product decision; G-09 open |
| `S-*` | [spots_module_plan.md](spots_module_plan.md) | Waddy Spots (places): home, details, voting, prizes, submissions | S-01–S-05, S-07–S-11, S-13 landed; S-06 partial; S-12 open |
| `CLAW-*` | [spots_claw_draw_plan.md](spots_claw_draw_plan.md) | The claw-machine voter draw screen in Spots | see file |
| `X-*` | [xp_module_plan.md](xp_module_plan.md) | XP / levels: levels home, challenges, prizes, level-up, checkout prize path | A–E landed 09-27; F–H landed 10-04 (backend deploy pending); X-41 deferred, X-47 product decision |
| `XM-*` | [xp_module_plan.md](xp_module_plan.md) Part 6 | XP motion: animated Rive/Lottie icons on XP home, Rewards, Quests | landed 10-04; assets swappable in `xp_motion.dart` |
| `CC-*` | [cart_checkout_fix_plan.md](cart_checkout_fix_plan.md) | Cart & checkout correctness: the arithmetic, order endpoints | planned; §2 landed |
| `CS-*` | [cart_checkout_structure_plan.md](cart_checkout_structure_plan.md) | Cart & checkout structure: the shape of the flow, not its arithmetic | Phases 0–3 landed 09-16 |
| `SC-*` | [scratch_card_plan.md](scratch_card_plan.md) | Physical scratch card in the bag: printed code typed in the promo field, single-use card codes | built 09-28 (backend deploy + migrate pending); SC-10 reorder metrics open |
| `ST-*` | [store_architecture_plan.md](store_architecture_plan.md) | The store layer: per-page vs cart vs discovery state in `StoreController`, how a store is opened (layout + module), store-details cache | **complete 09-30**: ST-01..ST-17 landed, store screens split into part files; ST-17 backend deploy + device checklist pending |
| `CAT-*` | [catalog_plan.md](catalog_plan.md) | Master catalogue: one product entry shared by every store, per-store listings for price/stock | P1–P2 live 09-29 (84 products, 187 listings); P3 built, deploy pending |
| `PET-*` | [pets_module_plan.md](pets_module_plan.md) | Pets module: pet shops, vet clinics (as Places), pet profiles, lifecycle pushes | P1–P4 built 10-02 (backend, screens, pet profile, lifecycle pushes), deploy + device check pending; P5 + art open |
| `PA-*` | [price_add_controls_plan.md](price_add_controls_plan.md) | One price / offer badge / add button / stepper language across every module; duplicate add → +n | all built 10-02; backend deploy + device check pending; Ramadan stall deferred |
| `LT-*` | [live_tracking_plan.md](live_tracking_plan.md) | Order "on the way": distance-gated map, Breadfast-style near state, rider marker, polling cadence + light rider-location endpoint | built 10-03 (backend deploy + device check pending) |
| `LA-*` | [live_activity_plan.md](live_activity_plan.md) | iOS order Live Activity: start, native bridge, APNs push path, token lifecycle, app-side sync, alerts, push-to-start | planned 10-04; Phase 0 (server diagnose) first |

## Recurring shapes

The same defects keep turning up in different modules. When one appears, the
earlier fix is usually the template.

| Shape | Seen as |
|---|---|
| Finished screen or widget that nothing builds or navigates to | `S-01`, `S-02`, `G-04`, `X-03` |
| Rebuild ids missing or bypassed, so one `update()` wakes unrelated screens | `S-04`, `X-01` |
| A singleton controller holding one page's state, so it leaks into the next page | `ST-01`, `ST-16` |
| A long page as a `Column` inside `SingleChildScrollView` | `G-03`, `S-05`, `X-09` |
| A comment promising a control, with an empty slot where it should be | `S-13`, `X-05` |

## Other plans (no ID prefix)

| File | Covers |
|---|---|
| [architecture_hardening_plan.md](architecture_hardening_plan.md) | App-wide hardening for scale |
| [cart_screen_restructure_plan.md](cart_screen_restructure_plan.md) | Cart screen layout |
| [food_store_add_feedback_plan.md](food_store_add_feedback_plan.md) | Food store anchored cart bar + reward strip |
| [snackbar_noise_plan.md](snackbar_noise_plan.md) | Snackbar noise |
| [guest_mode_plan.md](guest_mode_plan.md) | Guest browsing mode |
| [out_of_zone_plan.md](out_of_zone_plan.md) | Browsing outside the delivery zone |
| [ads_tracking_plan.md](ads_tracking_plan.md) | Meta / TikTok tracking and deep links |
| [mobile_only_plan.md](mobile_only_plan.md) | Removing web and desktop targets |
