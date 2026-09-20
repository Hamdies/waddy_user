import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:waddy_app/common/widgets/custom_button.dart';
import 'package:waddy_app/features/cart/controllers/cart_controller.dart';
import 'package:waddy_app/features/store/domain/models/cart_reward_state.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/styles.dart';

/// The cart bar from the Claude Design "Product Detail" screen.
///
/// A FRESH component, deliberately not a variant of `HomeCartBar`. That one
/// leads with the STORE (thumbnail, name, "view full menu") and splits the
/// action across Checkout and clear-cart buttons. This one
/// leads with the MESSAGE — a circular badge that breaks the bar's top edge —
/// and has exactly one tap target below it.
///
/// ## Structure (design-exact)
///
/// ```
///        ╭────╮                  ← 56px badge, overhangs the top edge by 32,
///   ╭────┼────┼───────────────╮     ringed in 5px of the bar's own white
///   │    ╰────╯  Message here │  ← white ground, radius 16 16 0 0
///   │  ┌───────────────────┐  │
///   │  │ 2 Items | LE 232  │  │  ← 44px pill, radius 12, inset 14
///   │  │        View Cart  │  │
///   │  └───────────────────┘  │
///   ╰─────────────────────────╯
/// ```
///
/// Metrics are the design's: a 56px badge with a 32px overhang and a 5px white
/// ring, 14.5px message, a 44px pill at radius 12 with 18px side padding,
/// 15px/16px pill type, and a 12px gap between message and pill. The HUES are
/// this app's tokens — the design's `#1BA672` green maps to
/// [WaddyColors.primary] — so the bar belongs to the app while matching the
/// design's shape exactly.
///
/// Three in-cart states, as the design draws them:
///   • below minimum — grey badge and grey pill, still tappable
///   • free delivery locked — progress bar under the message
///   • free delivery unlocked — a "saved" chip inside the pill
///
/// Plus the empty-cart acquisition hooks, which the design has no slot for but
/// which drive first orders: those render the message row alone, with no pill.
class PillCartBar extends StatefulWidget {
  /// The store whose minimum/free-delivery rules apply, or null on surfaces
  /// that are not inside one store (the food home screen), where only the
  /// admin-wide rules can be evaluated.
  final Store? store;

  /// When true, resolve against admin-wide rules only — see
  /// [CartRewardState.resolveGlobal].
  final bool globalOnly;

  /// Reports the height a screen must reserve so nothing it scrolls ends up
  /// under this bar.
  ///
  /// The reported height INCLUDES the bottom system inset, which this bar
  /// carries inside its own ground — a caller must not add the inset again. It
  /// also INCLUDES [_Badge.overhang], the part of the badge painted above the
  /// bar's box: it is outside layout but it is still on top of the content,
  /// and a caller cannot be expected to know that. Reserve this number as-is
  /// and add only the clearance the design wants.
  final ValueChanged<double>? onHeightChanged;

  const PillCartBar({
    super.key,
    this.store,
    this.globalOnly = false,
    this.onHeightChanged,
  });

  @override
  State<PillCartBar> createState() => _PillCartBarState();
}

class _PillCartBarState extends State<PillCartBar>
    with SingleTickerProviderStateMixin {
  final GlobalKey _barKey = GlobalKey();
  late final AnimationController _pulse;
  late final Animation<double> _scale;

  double _lastReportedHeight = -1;
  int _lastCount = -1;

  /// Retires the empty-cart hooks after they have been read.
  ///
  /// A hook renders the message row with NO pill beneath it, so for as long as
  /// it is up the screen carries a permanent bottom strip that cannot be
  /// tapped, cannot be dismissed, and covers the last menu row. A first-timer
  /// taps it — it is the only fixed element on the screen — and nothing
  /// happens. Held forever it costs more than it earns; shown once it does
  /// exactly the acquisition job it was written for.
  ///
  /// Scoped to the hooks alone. Every other state reports something about a
  /// real cart and must persist for as long as that stays true.
  Timer? _hookTimer;
  bool _hookExpired = false;

  static const Duration _kHookLifetime = Duration(seconds: 6);

  /// Starts the retirement clock the first time a hook is built, and rearms it
  /// when the cart empties again after an order or a clear-out — a returning
  /// user is owed the message once more, not silence.
  void _armHookTimer() {
    if (_hookTimer != null || _hookExpired) return;
    _hookTimer = Timer(_kHookLifetime, () {
      if (!mounted) return;
      setState(() => _hookExpired = true);
    });
  }

  void _resetHook() {
    _hookTimer?.cancel();
    _hookTimer = null;
    if (_hookExpired) _hookExpired = false;
  }

  @override
  void initState() {
    super.initState();
    // Transform-only, so the acknowledgement composites without a relayout.
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.03), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.03, end: 1.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _hookTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  /// Measured after layout, never during it.
  ///
  /// The measured box excludes the badge's overhang — the badge reserves only
  /// the slice of itself that sits inside the bar and paints the rest above,
  /// outside layout. A caller reserving the raw box height therefore left the
  /// overhang to land on the last row of the list, which in a menu is a price.
  /// Adding it here keeps the fix in the contract rather than in each caller's
  /// arithmetic.
  void _reportHeight() {
    if (widget.onHeightChanged == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _barKey.currentContext;
      final double h =
          ctx == null
              ? 0
              : ((ctx.findRenderObject() as RenderBox?)?.size.height ?? 0) +
                  _Badge.overhang;
      if ((h - _lastReportedHeight).abs() > 0.5) {
        _lastReportedHeight = h;
        widget.onHeightChanged?.call(h);
      }
    });
  }

  void _reportZero() {
    if (widget.onHeightChanged == null || _lastReportedHeight == 0) return;
    _lastReportedHeight = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onHeightChanged?.call(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CartController>(
      builder: (cart) {
        final bool empty = cart.cartList.isEmpty;

        CartRewardState reward = CartRewardState.resolveFromContext(
          store: widget.store,
          subTotal: cart.subTotal,
          cartIsEmpty: empty,
          globalOnly: widget.globalOnly,
        );

        // ── The "some stores show a bar, some show nothing" gap.
        //
        // The ladder returns `hidden` for an empty cart at a store whose only
        // notable fact is a minimum order, because none of its empty-cart
        // hooks are a minimum. On the shelf that read as the feature being
        // broken at half the stores: Zooba (free delivery) showed a strip,
        // Butcher's (120 LE minimum) showed nothing at all.
        //
        // A minimum is exactly what a user needs BEFORE they start adding, so
        // it is surfaced here rather than left to the moment they are already
        // under it. Resolved locally — not by loosening the shared ladder,
        // which the cart and the older bars also read and which deliberately
        // keeps "you can check out" off browsing surfaces.
        final double minimum = widget.store?.minimumOrder ?? 0;
        if (empty &&
            !reward.isVisible &&
            !widget.globalOnly &&
            minimum > 0 &&
            widget.store?.delivery != false) {
          reward = CartRewardState(
            kind: CartRewardKind.minimumOrder,
            remaining: minimum,
            progress: 0,
          );
        }

        // The hook clock. Armed while a hook is up, reset the moment there is
        // a real cart to talk about, so the next empty cart gets the message
        // again rather than inheriting a spent timer.
        if (reward.isAcquisitionHook) {
          if (_hookExpired) {
            _reportZero();
            return const SizedBox.shrink();
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _armHookTimer();
          });
        } else if (!empty) {
          _resetHook();
        }

        // Nothing in the basket and genuinely nothing to say.
        if (empty && !reward.isVisible) {
          _reportZero();
          return const SizedBox.shrink();
        }

        final int count = cart.cartList.fold<int>(
          0,
          (sum, c) => sum + (c.quantity ?? 1),
        );
        if (_lastCount != -1 && count != _lastCount && count > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _pulse.forward(from: 0);
          });
        }
        _lastCount = count;

        _reportHeight();

        // Below the minimum the pill still navigates: the cart screen is where
        // the user removes or adjusts items, so blocking the only route there
        // strands them. It wears the design's grey, but it is not inert.
        final bool blocked = reward.kind == CartRewardKind.minimumOrder;

        // No message to show: the ladder is silent and the cart carries no
        // discount, so the bar is the pill alone. Must match `_MessageRow`'s
        // own silence test, which is what actually suppresses the badge.
        final bool silent =
            reward.kind == CartRewardKind.hidden && cart.itemDiscountPrice <= 0;

        final Widget bar = Container(
          key: _barKey,
          decoration: const BoxDecoration(
            color: WaddyColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: WaddyColors.shadowTeal,
                blurRadius: 24,
                offset: Offset(0, -6),
              ),
            ],
          ),
          // The design's `padding: 16px 0 12px`, plus the system inset so the
          // white runs to the physical screen edge. The 16 is the room the
          // badge's in-bar half needs; with no message row there is no badge,
          // so it collapses to a plain 12 rather than leaving dead white.
          padding: EdgeInsets.only(
            top: silent ? 12 : 16,
            bottom: MediaQuery.paddingOf(context).bottom + 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MessageRow(state: reward, saved: cart.itemDiscountPrice),
              if (!empty) ...[
                if (!silent) const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: _CartPill(cart: cart, count: count, blocked: blocked),
                ),
              ],
            ],
          ),
        );

        // The badge overhangs the bar's top edge by 32, so nothing here may
        // clip: no `clipBehavior`, and the Stack is explicitly allowed to
        // paint outside its box. `alignment: bottomCenter` keeps the bar
        // pinned to the screen edge while the overhang grows upward.
        return ScaleTransition(
          scale: _scale,
          child: Stack(clipBehavior: Clip.none, children: [bar]),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════
// The message row — badge + copy (+ progress)
// ═══════════════════════════════════════════

/// The design's `display:flex;gap:14px;padding:0 20px` row: the overhanging
/// badge, then the message, with the progress track under the message when the
/// state is progress-shaped.
class _MessageRow extends StatelessWidget {
  final CartRewardState state;
  final double saved;

  const _MessageRow({required this.state, required this.saved});

  bool get _isBlocker => state.kind == CartRewardKind.minimumOrder;

  /// Which animation the badge holds.
  ///
  /// These replace the design's emoji (🎉 / 🚚 / 🛒) with animations the app
  /// already ships, so nothing new is downloaded:
  ///   • below the minimum → `order_placed`   (getting an order started)
  ///   • free delivery     → `delivery_order` (the van)
  ///   • money saved       → `waddi_coins`    (the app's savings mark)
  String get _animation {
    switch (state.kind) {
      case CartRewardKind.minimumOrder:
      case CartRewardKind.minimumOrderMet:
        return 'assets/animation/order_placed.json';

      case CartRewardKind.freeDeliveryProgress:
      case CartRewardKind.freeDeliveryUnlocked:
      case CartRewardKind.freeDeliveryGuaranteed:
      case CartRewardKind.hookFreeDelivery:
        return 'assets/animation/delivery_order.json';

      case CartRewardKind.hookFirstOrder:
      case CartRewardKind.hidden:
        return 'assets/animation/waddi_coins.json';
    }
  }

  /// True when there is no message at all — a non-empty cart whose ladder
  /// state is `hidden` and which carries no discount. The badge must not
  /// render on its own: a lone circle overhanging the bar with nothing beside
  /// it reads as a rendering fault.
  bool get _isSilent => state.kind == CartRewardKind.hidden && saved <= 0;

  @override
  Widget build(BuildContext context) {
    if (_isSilent) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Badge(
            asset: _animation,
            // Loop ONLY on the moment worth celebrating. waddi_coins is 228KB
            // and delivery_order 80KB — looping either forever behind a static
            // message is wasted battery on a screen users sit on.
            repeat: state.celebrates,
            // The design greys the badge in the below-minimum state and greens
            // it otherwise; a mint tint is this app's stand-in for that green,
            // and it lets the Lottie artwork read in its own colours instead
            // of fighting a saturated teal disc.
            fill:
                _isBlocker
                    ? WaddyColors.surfaceRaised
                    : WaddyColors.mintSurface,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _message(),
                if (state.hasProgress) ...[
                  // The design's `margin-top:7px;height:5px;radius:3px`.
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      // The RENDERED value is clamped; `state.progress` stays
                      // true for the label. Without the ceiling a 97% bar
                      // paints as full, so "Add LE 8 more" would sit beside a
                      // finished-looking bar.
                      value: state.progress.clamp(0.04, 0.92),
                      minHeight: 5,
                      backgroundColor: WaddyColors.divider,
                      valueColor: const AlwaysStoppedAnimation(
                        WaddyColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Moved out of the pill button below: this is the only place on
          // the bar that already states a fact about the whole order (free
          // delivery, minimum reached, …), so "how much you saved" belongs
          // beside it rather than crowded into the tap target underneath.
          if (saved > 0 && !_isBlocker) ...[
            const SizedBox(width: 10),
            _SavedChip(amount: saved),
          ],
        ],
      ),
    );
  }

  /// The design's message: 14.5px at weight 500, with the amount and the words
  /// "FREE DELIVERY" at weight 800. No highlighter block — the new design
  /// dropped it in favour of weight alone.
  Widget _message() {
    final TextStyle base = waddyRegular.copyWith(
      fontSize: 14.5,
      color: WaddyColors.ink,
      height: 1.3,
    );
    final TextStyle strong = waddyBold.copyWith(
      fontSize: 14.5,
      color: WaddyColors.ink,
      height: 1.3,
    );

    switch (state.kind) {
      case CartRewardKind.minimumOrder:
        return Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '${'add'.tr} ', style: base),
              TextSpan(
                text: PriceConverter.convertPrice(state.remaining),
                style: strong,
              ),
              TextSpan(text: ' ${'add_to_start_your_order'.tr}', style: base),
            ],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        );

      case CartRewardKind.freeDeliveryProgress:
        return Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '${'add'.tr} ', style: base),
              TextSpan(
                text: PriceConverter.convertPrice(state.remaining),
                style: strong,
              ),
              TextSpan(text: ' ${'add_to_have_free_delivery'.tr}', style: base),
            ],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        );

      case CartRewardKind.freeDeliveryUnlocked:
        return Text(
          'waddy_free_delivery_unlocked'.tr,
          style: strong,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        );

      case CartRewardKind.minimumOrderMet:
        return Text(
          'minimum_order_reached'.tr,
          style: strong,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        );

      case CartRewardKind.freeDeliveryGuaranteed:
        return Text(
          'free_delivery_on_this_order'.tr,
          style: strong,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        );

      // ── The empty-cart hooks. No pill renders beneath these.
      case CartRewardKind.hookFreeDelivery:
        return Text(
          'waddy_got_you_free_delivery'.tr,
          style: strong,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        );

      case CartRewardKind.hookFirstOrder:
        final double amount = state.discountAmount ?? 0;
        final String off =
            state.discountIsPercent
                ? '${amount.toStringAsFixed(0)}%'
                : PriceConverter.convertPrice(amount);
        return Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '${'waddy_got_you_first_order_off'.tr} ',
                style: base,
              ),
              TextSpan(text: off, style: strong),
              TextSpan(text: ' ${'off_your_first_order'.tr}', style: base),
            ],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        );

      // The ladder has nothing to say. If the cart nonetheless carries a real
      // discount, that is the news — the design's own "You're saving" line.
      // With no discount there is genuinely nothing to report, and an empty
      // row is better than a bare "You're saving".
      //
      // The amount itself is NOT repeated here: the [_SavedChip] rendered
      // alongside this text already states it, so printing it twice on one
      // row read as the same number said back-to-back.
      case CartRewardKind.hidden:
        if (saved <= 0) return const SizedBox.shrink();
        return Text(
          'youre_saving'.tr,
          style: strong,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        );
    }
  }
}

/// The 56px circle that overhangs the bar's top edge.
///
/// `margin-top: -32px` in the design's terms, which is a NEGATIVE top margin:
/// the circle's upper 32px sit outside the bar. Flutter has no negative
/// margin, so the equivalent here is a [Transform.translate] on a box that
/// reserves only the visible remainder — that way the row's height is the 24px
/// of in-bar circle, and the rest paints over whatever is above.
///
/// The design's `box-shadow: 0 0 0 5px #fff` is a hard 5px spread with no blur:
/// a solid ring, not a shadow. That is a [Border], not a [BoxShadow] — using a
/// blurred shadow here would smear the punch-through effect the ring creates.
class _Badge extends StatelessWidget {
  final String asset;
  final bool repeat;
  final Color fill;

  static const double _diameter = 56;

  /// How far the badge circle rises above the bar's top edge.
  ///
  /// Painted, not reserved — so `_reportHeight` adds it back when telling a
  /// scrolling caller how much room to leave.
  static const double overhang = 32;
  static const double _ring = 5;

  const _Badge({required this.asset, required this.repeat, required this.fill});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _diameter,
      // Only the part of the circle that sits INSIDE the bar occupies layout
      // space; the overhang is painted, not reserved.
      height: _diameter - overhang,
      child: OverflowBox(
        maxHeight: _diameter + _ring * 4,
        alignment: Alignment.topCenter,
        child: Transform.translate(
          offset: const Offset(0, -overhang),
          child: Container(
            width: _diameter,
            height: _diameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fill,
              // The white ring that makes the badge read as punched through
              // the bar's edge.
              border: Border.all(color: WaddyColors.surface, width: _ring),
            ),
            // The ring is drawn INSIDE the 56px box, so the animation gets the
            // remaining room; a little extra inset keeps the artwork off the
            // ring rather than touching it.
            padding: const EdgeInsets.all(4),
            child: Lottie.asset(asset, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// The pill
// ═══════════════════════════════════════════

/// The design's 44px bar at radius 12: `{count} Items | LE {total}` on the
/// left, `View Cart` on the right. Built on the shared [CustomButton] so the
/// cart bar's one real action uses the app's common button rather than its
/// own bespoke `Material`/`InkWell` — the split left/right content is passed
/// in as `child`, since [CustomButton] otherwise only centers a single label.
class _CartPill extends StatelessWidget {
  final CartController cart;
  final int count;
  final bool blocked;

  const _CartPill({
    required this.cart,
    required this.count,
    required this.blocked,
  });

  @override
  Widget build(BuildContext context) {
    // Below the minimum the design calls for a flat disabled look — `#f1f1f3`
    // ground, `#a0a0a6` ink — which stays an explicit override because it is
    // a real state, not a color choice. Otherwise the pill takes
    // [CustomButton]'s own default brand look (mint fill, primary text/border)
    // rather than restating the app's colours here.
    final Color? ground = blocked ? WaddyColors.surfaceRaised : null;
    final Color ink = blocked ? WaddyColors.inkMuted : WaddyColors.primary;

    final String label =
        '$count ${count == 1 ? 'cart_bar_item'.tr : 'cart_bar_items'.tr}'
        ' | ${PriceConverter.convertPrice(cart.subTotal)}';

    return CustomButton(
      buttonText: '${'view_cart'.tr}, $label',
      height: 44,
      radius: 12,
      color: ground,
      onPressed: () {
        HapticFeedback.selectionClick();
        Get.toNamed(RouteHelper.getCartRoute());
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Count and total. Flexible, not Expanded: "View Cart" must
            // keep its full width (the design marks it `flex:none`), and
            // this side is what gives way when the currency string is long.
            Flexible(
              child: Text(
                label,
                style: waddyBold.copyWith(fontSize: 15, color: ink),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // `space-between` in the design. A fixed gap rather than a
            // Spacer: the left side is already Flexible, so a Spacer would
            // fight it for the slack and collapse the label first.
            const SizedBox(width: 12),
            Text(
              'view_cart'.tr,
              style: waddyBold.copyWith(fontSize: 16, color: ink),
              maxLines: 1,
              softWrap: false,
            ),
          ],
        ),
      ),
    );
  }
}

/// The "X saved" pill. Was the cart button's own inline chip; moved beside
/// the free-delivery/minimum message in [_MessageRow] instead, since that row
/// is the bar's one place already stating a fact about the whole order — the
/// tap target below it is for going to the cart, not for reading numbers off.
class _SavedChip extends StatelessWidget {
  final double amount;

  const _SavedChip({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: const BoxDecoration(color: WaddyColors.mint),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: PriceConverter.convertPrice(amount),
              style: waddyBold.copyWith(
                fontSize: 12,
                color: WaddyColors.primary,
              ),
            ),
            TextSpan(
              text: ' ${'saved'.tr}',
              style: waddyRegular.copyWith(
                fontSize: 12,
                color: WaddyColors.primary,
              ),
            ),
          ],
        ),
        maxLines: 1,
        softWrap: false,
      ),
    );
  }
}
