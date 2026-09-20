# Waddy — Product Context

> Derived from the codebase (lib/theme, app_constants, brand assets). Refine with `$impeccable teach` if anything here is off.

## Product purpose
Waddy is a food & goods delivery app (customer app: `waddi_user`, Flutter + native iOS Live Activities). Users order from restaurants and stores, then track delivery in real time.

## Register
product

## Users
Hungry customers placing and tracking orders, often glancing at their phone repeatedly while waiting. Attention spans are 1–2 second glances; the top question is always "how long until my food arrives, and what stage is it at?"

**Market and age range:** Egypt, primarily 18–40. This is not a generic international audience — the copy, the colour strategy and the competitive set are all Egypt-specific. Competitors: Talabat (owns orange), Elmenus (owns red).

## Brand
- **Name:** Waddy (logo asset: WaddyLogo, wordmark rendered in brand color)
- **The name is a pun, and it is load-bearing.** "Waddy" / واضي is Egyptian colloquial for *great* / *nice* — everyday speech in the 18–40 range. So "Waddy!" in UI copy is not the app referring to itself in third person; it is a native exclamation that happens to be the brand name. **Do not "fix" it into neutral English.** Copy like `"Waddy! you're saving"` (`en.json: youre_saving`) reads to an Egyptian user as "Nice! you're saving" — the double meaning is the point and is the most authored thing in the product's voice.
- **Primary:** deep teal `#134E4A` (light variant `#1D706A`, tinted surface `#E6F4F3`)
- **Signature accent:** electric mint `#1EF2A0` (pressed `#0DC97D`, surface `#E6FCF3`)
- **Secondary pops:** coral `#FF6B6B` (errors/warm), amber `#FFBE0B` (ratings/warnings)
- **Dark theme:** teal-tinted darks (`#111715` bg, `#1E2926` cards, `#DDE8E6` text)
- **Type:** thmanyahsans (Light/Regular/Medium/Bold/Black) mapped over Roboto + Alexandria families in Flutter. Native surfaces (widgets) use SF Pro / SF Rounded.

## Tone
Confident, fresh, energetic, slightly playful. NOT premium/restrained — when in doubt, go bolder.

Mint is the dominant brand surface: large mint fields (home hero, feature cards) paired with deep-teal ink typography ARE the identity. Deep teal serves as the ink/anchor color, not the dominant field. Electric mint still does double duty as the functional accent (ETA, progress, live state) — keep functional mint saturated (`#1EF2A0`) and surface mint lighter so live-state signals stay legible against brand surfaces.

**Mint-dominance applies to EVERY surface, not just the home screen.** The strategic reason is competitive: Talabat owns orange and Elmenus owns red in Egypt, so mint is the one unclaimed colour in the category. A screen a user can recognize as Waddy from across a room is doing brand work that grey-on-white cannot. A surface where mint has shrunk to a few accent dots under ~2% of the viewport has drifted and should be treated as a defect, not a style choice.

**The constraint on task screens (Operate surfaces — menus, cart, checkout, lists):** mint must do *structural* work, not decorative fills. It should carry a repeating rhythm the eye can scan — e.g. the price column down a menu list — rather than tinting arbitrary panels. Decorative mint on a scanning surface costs legibility and is the failure mode to avoid. Expressive surfaces (home, splash, onboarding, empty states) can take large flat mint fields directly.

<!-- Decision 2026-07-09: mint-dominant direction confirmed by Ahmed during /critique of the home screen; supersedes the earlier "mint sparingly, never decoration" rule. -->
<!-- Decision 2026-07-10: splash = full mint field (#1EF2A0) matching the native launch screens, W mark tinted deep teal at runtime, mark-only (no wordmark), brand-constant across light/dark. Confirmed by Ahmed during /critique of the splash screen. -->
<!-- Decision 2026-09-14: mint-dominance scoped to ALL surfaces, not home-only, confirmed by Ahmed during /critique of the food store details screen. Rationale is competitive colour ownership in the Egyptian market (Talabat=orange, Elmenus=red, mint unclaimed). Structural-not-decorative constraint added for Operate surfaces at Claude's recommendation, accepted in the same exchange. -->

## Anti-references
- Generic white delivery-tracker cards that could belong to any app
- Emoji as primary status iconography
- Gray-on-white caption soup with no hierarchy
- **Theming a competitor's layout instead of designing a Waddy one.** Copying the Talabat/Deliveroo screen skeleton and applying Waddy tokens produces a screen that is category-interchangeable by construction — the tokens cannot rescue an inherited composition. If a widget's own doc comment describes it as "<competitor>-style", treat that as a defect marker, not a spec.
- Square-cornered mint rectangles behind text. Full-saturation `#1EF2A0` with no `borderRadius` reads as a highlighter/text-selection artifact rather than a designed chip. Every tinted surface in the app carries a radius; mint is the brand's loudest colour and must not be its least-finished component.

## Known truth contracts
Conventions that already exist in code and must not be contradicted by new UI:

- **Never print a number the app refuses to act on.** `StoreDeliveryFee` (`lib/features/store/helpers/store_delivery_fee.dart`) returns `null` rather than guessing and enforces `maxPlausibleKm = 60` against bad backend distances. Any surface displaying a distance must apply the same gate — a screen that won't quote a fee from a value must not print that value either. Seed/backend data in this project is known to return garbage distances (e.g. 3143.6 km for a Maadi store).
- **A bottom bar reports its whole footprint.** `PillCartBar.onHeightChanged` reports the measured box **plus** the badge overhang painted outside layout, and already includes the bottom system inset. Callers reserve that number as-is and add only clearance — do not re-add the inset, and do not subtract the overhang.
- **Prefer fixing a layout contract in the widget over patching each caller's arithmetic**, so the next screen to adopt a component cannot inherit the same bug.
