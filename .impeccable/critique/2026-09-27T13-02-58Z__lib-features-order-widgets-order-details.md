---
target: order details screen (all states)
total_score: 22
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 4
timestamp: 2026-09-27T13-02-58Z
slug: lib-features-order-widgets-order-details
---
# Critique: Order Details (all states) — 22/40

Method: dual-agent. Detector cannot scan .dart (0 files covered); grep pass substituted. Browser overlay n/a (native app).

## Heuristics
1 Status 2 (ETA grows 25→30→75; "Assigning" before store confirm) · 2 Real world 2 ("REASON null", "Delivery at Others") · 3 Control 3 · 4 Consistency 2 (card order shuffles per stage; pill shapes differ) · 5 Error prevention 2 (stars carry no value; PIN before pickup) · 6 Recognition 3 · 7 Efficiency 2 (no reorder) · 8 Minimalist 2 (status ×4; header ~40% viewport) · 9 Recovery 1 (cancelled: null, no next action) · 10 Help 3

## Specificity
Header = Waddy (mint band, W Lotties, tone shift). Body = generic anti-reference; three Zomato strings verbatim (od_delivery_details_title, od_tip_thanks, od_assigning_partner); dead widgets/zomato/ folder. Mint in body decorative only. No "Waddy!" voice anywhere in od_* copy.

## Priority issues
- [P1] Raw data as copy: _nonEmpty (order_details_screen.dart:935) passes literal "null"; (addressType).tr → "Delivery/Delivered at Others" (:787, :878, :890). clarify + harden.
- [P1] ETA unstable/multi-source (_getLiveEtaMinutes ?? _getPrepMinutes, :248-303): prep time labelled "Arriving in"; collecting uses rider→customer straight line; no plausibility gate; monotonic growth. harden.
- [P1] Timestamps hours off (07:54 AM vs device 3:54, minutes match): _formatTime (:960) parses offset-less string as local. Verify backend TZ. harden.
- [P1] Ended states dead ends: cancelled no reorder/refund; delivered two rating blocks, stars call onRate with no value (sections:640-645); completion Lottie repeat:true (:369); status ×4. delight + distill.
- [P2] Pinned header ~40% viewport (screen:572-588); FittedBox title shrinks; card order shuffles; body generic. layout + bolder.

## Persona red flags
Casey: ETA meaning shifts, 36pt refresh, fake stars. Jordan: unexplained PIN, "Others", unlabeled rider card beside own contact row. Mona (Arabic, 360dp, COD): header half the screen, "Rate Ahmed" ambiguity, time offset erodes trust.

## Minor
Item price = Subtotal duplicate; unlabeled discount; tip line on no-partner card; Lottie bg seams vs mint; chevron-down on pushed route; dashed/solid divider mix; POI clutter on map; '$name, $phone' Latin comma (:975); od_failed_subtitle always blames payment; 22 literal fontSizes (off-scale 11.5/12.5/13/13.5/14.5/17), ~10 off-grid paddings, tap targets 36/44 < 48, fixed 36pt pills clip at ~2x text.

## Questions
One committed arrival time? Single morphing mint "now card"? Delivered → "Waddy!" + one-tap reorder?
