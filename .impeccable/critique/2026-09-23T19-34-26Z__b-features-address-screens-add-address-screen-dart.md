---
target: address details screen
total_score: 24
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 3
timestamp: 2026-09-23T19-34-26Z
slug: b-features-address-screens-add-address-screen-dart
---
# Critique: Address details (add_address_screen.dart), 2026-09-23
Score 24/40 (H1 2, H2 3, H3 3, H4 2, H5 2, H6 3, H7 3, H8 2, H9 1, H10 3).
Specificity: category-interchangeable skeleton; mint ~1-2% of viewport; loudest colour was an amber tip banner; CTA grey (disabled, no reason).
P1 receiver fields unmounted mid-typing (_needsReceiverFields derived live) — FIXED (latched).
P1 phone validated on hidden prefilled field — FIXED (reveal receiver fields on invalid).
P1 silent disabled CTA — FIXED (reason line above button, 2 new keys). No inline field errors yet (snackbars only).
P2 amber banner wrong semantic / no mint structure — FIXED (mint location card: address + rider tip; mintInk underline on filled fields; mint focus on directions).
P2 touch targets <48 (chips, back, Change) — FIXED.
P3 token drift (+2 nudges, 150/118 strip literals, pin literals) — partially fixed.
Open: floor field is number-only (أرضي/روف impossible); blank grey map tiles in screenshot; _addressController set in build with `!`; counter digits not localised.
