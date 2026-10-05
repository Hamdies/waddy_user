import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/checkout/widgets/checkout_card.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

/// The top of the cart AND checkout: [BasketHeader] in the app bar, then
/// [BasketSavingsBanner] pinned under it. One widget pair, so the two screens
/// read as one flow and cannot drift apart.

/// Height of the app bar that hosts [BasketHeader].
const double kBasketHeaderHeight = 60;

/// Space before the header's back button. It is 4 under the page gutter
/// because the button's 48 hit box rings its 40 circle, so the circle itself
/// lands on the gutter.
const double kBasketHeaderStartInset = Dimensions.paddingSizeMedium;

/// Circled back button, then [title] over "STORE · N items".
class BasketHeader extends StatelessWidget {
  final String title;
  final String? storeName;
  final int itemCount;
  final VoidCallback onBack;
  const BasketHeader({
    super.key,
    required this.title,
    required this.storeName,
    required this.itemCount,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final String countText =
        '$itemCount ${(itemCount == 1 ? 'item' : 'items').tr}';
    final String? store =
        storeName == null || storeName!.isEmpty ? null : storeName;

    return Row(
      children: [
        // Drawn at 40, hit at 48: the ring around the circle also goes back.
        Semantics(
          button: true,
          label: MaterialLocalizations.of(context).backButtonTooltip,
          child: GestureDetector(
            onTap: onBack,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: Dimensions.minTapTarget,
              height: Dimensions.minTapTarget,
              child: Center(
                child: Material(
                  color: WaddyColors.surface,
                  shape: const CircleBorder(
                    side: BorderSide(color: WaddyColors.divider),
                  ),
                  child: InkWell(
                    onTap: onBack,
                    customBorder: const CircleBorder(),
                    child: const SizedBox(
                      width: Dimensions.paddingSizeExtraOverLarge,
                      height: Dimensions.paddingSizeExtraOverLarge,
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: Dimensions.paddingSizeLarge,
                        color: WaddyColors.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: Dimensions.paddingSizeSmall),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: waddyBold.copyWith(
                  fontSize: Dimensions.fontSizeLarge,
                  color: WaddyColors.ink,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (itemCount > 0)
                Text(
                  store == null ? countText : '$store · $countText',
                  style: waddyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: Dimensions.fontSizeExtraSmall,
                    letterSpacing: 0.2,
                    color: WaddyColors.inkLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Waddy! You saved [39 LE]" — the order's savings, pinned under the header,
/// with the amount in the mint saving chip.
///
/// Renders nothing when there is no saving; a "You saved 0 LE" banner is
/// worse than none (the cart falls back to its XP band instead).
class BasketSavingsBanner extends StatelessWidget {
  final double amount;
  const BasketSavingsBanner({super.key, required this.amount});

  @override
  Widget build(BuildContext context) {
    if (amount <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimensions.paddingSizeDefault,
        0,
        Dimensions.paddingSizeDefault,
        Dimensions.paddingSizeExtraSmall,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Dimensions.paddingSizeDefault,
          vertical: Dimensions.paddingSizeMedium,
        ),
        decoration: BoxDecoration(
          color: WaddyColors.mintSurface,
          border: Border.all(
            color: WaddyColors.mint.withValues(alpha: 0.55),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: Dimensions.paddingSizeExtraLarge,
              height: Dimensions.paddingSizeExtraLarge,
              child: CustomPaint(painter: _DiscountSealPainter()),
            ),
            const SizedBox(width: Dimensions.paddingSizeMedium),
            // "Waddy!" is the Egyptian-slang pun (واضي), on purpose.
            Flexible(
              child: Text(
                'waddy_you_saved'.tr,
                style: waddyBold.copyWith(
                  fontSize: Dimensions.fontSizeSmall,
                  color: WaddyColors.mintInk,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: Dimensions.paddingSizeSmall),
            CheckoutSavingChip(
              PriceConverter.convertPrice(amount),
              fontSize: Dimensions.fontSizeSmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// The design's filled discount seal: a scalloped badge with a white "%".
class _DiscountSealPainter extends CustomPainter {
  const _DiscountSealPainter();

  // The seal's outline on a 24-unit grid.
  static const List<Offset> _seal = [
    Offset(12, 1.5),
    Offset(14.3, 3.2),
    Offset(17.1, 2.9),
    Offset(18.2, 5.5),
    Offset(20.8, 6.6),
    Offset(20.5, 9.4),
    Offset(22.2, 11.7),
    Offset(20.5, 14),
    Offset(20.8, 16.8),
    Offset(18.2, 17.9),
    Offset(17.1, 20.5),
    Offset(14.3, 20.2),
    Offset(12, 22.5),
    Offset(9.7, 20.8),
    Offset(6.9, 21.1),
    Offset(5.8, 18.5),
    Offset(3.2, 17.4),
    Offset(3.5, 14.6),
    Offset(1.8, 12),
    Offset(3.5, 9.7),
    Offset(3.2, 6.9),
    Offset(5.8, 5.8),
    Offset(6.9, 3.2),
    Offset(9.7, 3.5),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    canvas.drawPath(
      Path()..addPolygon(_seal, true),
      Paint()..color = WaddyColors.mintInk,
    );
    final Paint white = Paint()..color = WaddyColors.surface;
    canvas.drawLine(
      const Offset(9, 15),
      const Offset(15, 9),
      white
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(const Offset(9.3, 9.3), 1.4, white);
    canvas.drawCircle(const Offset(14.7, 14.7), 1.4, white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Lays [child] (the page's scroll view) under a short fade, so rows scrolling
/// up under [BasketSavingsBanner] dissolve instead of being cut on a hard
/// edge. A painted gradient, not a ShaderMask, so scrolling costs no layer.
class BasketScrollFade extends StatelessWidget {
  final Widget child;
  const BasketScrollFade({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: Dimensions.paddingSizeMedium,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [WaddyColors.surface, Color(0x00FFFFFF)],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
