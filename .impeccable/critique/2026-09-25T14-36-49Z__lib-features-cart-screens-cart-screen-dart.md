---
target: cart screen
total_score: 23
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 3
timestamp: 2026-09-25T14-36-49Z
slug: lib-features-cart-screens-cart-screen-dart
---
# Cart screen critique (2026-09-25)
Method: dual-agent. The detector checked nothing: .dart files aren't supported. A manual code scan was used instead.

Score 23/40 (Acceptable). H1 3, H2 3, H3 2, H4 2, H5 2, H6 3, H7 2, H8 2, H9 2, H10 2.

## Priority issues
- P1: The price chip (CheckoutSavingChip, checkout_card.dart:186) is a square-cornered, full-saturation mint rectangle. This is the PRODUCT.md anti-reference. The chip is shared with checkout. Fix: mintSurfaceDeep fill + mintInk text + radiusSmall, and apply it to every price, not only discounted ones.
- P1: The promo card (coupon_section.dart:136) is a second full-mint slab competing with the CTA. This violates the 2026-09-22 decision. Fix: mintSurface card; full mint only on the Apply button, or collapse it to a row.
- P1: A cold open shows the empty-cart screen while the cart loads (cart_screen.dart:107-109, :169). Fix: show a loading state or skeleton.
- P2: Items scroll under the pinned savings banner with a hard edge (cart_screen.dart:173). Fix: top fade, or move the banner into the scroll content.
- P2: No undo on delete (minus at 1, and swipe; cart_item_widget.dart:285, :103); no sanity check on quantity. Fix: Undo snackbar.
- P2: Tap targets under 44pt (back 37, steppers 32/24-30). Strikethrough price is #9EAAA8 at 11px, about 2.4:1 contrast. The fees line is 10.5px with maxLines 1 and no overflow.

## Minor
- Off-grid values: 26 font sizes, 12 paddings and 9 radii use numbers instead of Dimensions tokens.
- 6 of 6 GetBuilders have no id.
- The suggestion rail has a fixed 168px height.
- The banner total (893) is one more than the two shown line savings (525 + 367 = 892) because each is rounded separately.
- The fee size is never shown before checkout.
