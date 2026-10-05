import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/scratch_card/widgets/scratch_card_sheet.dart';
import 'package:waddy_app/features/scratch_card/widgets/scratch_flip_card.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/helper/address_helper.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

/// Where in the order's life the badge is shown; only its second line changes.
enum ScratchTeaserMoment {
  /// Store pages and cart: this order will bring a card.
  beforeOrder,

  /// Order confirmation.
  placed,

  /// Order details while the order is live.
  onTheWay,

  /// Order details after delivery: scratch it, spend it next time.
  delivered,
}

/// The scratch card badge from the Claude Design "Scratch Card" file: a
/// floating, flipping card rising out of a small teal plate. Tap opens
/// [ScratchCardSheet].
///
/// It is always placed ON a surface (the store cover, the confirmation, the
/// order card list), never floated over content: a corner overlay covered the
/// ADD buttons, prices and CTAs that live on the trailing side of every
/// screen (docs/scratch_card_plan.md §3a).
class ScratchCardBadge extends StatelessWidget {
  final ScratchTeaserMoment moment;

  /// 1 = the design's 116×132.
  final double scale;

  /// Label only, set larger, for small placements where the second line
  /// would shrink past reading (the store cover).
  final bool compact;

  const ScratchCardBadge({
    super.key,
    this.moment = ScratchTeaserMoment.beforeOrder,
    this.scale = 1,
    this.compact = false,
  });

  static const double width = 116;
  static const double height = 132;

  /// Cards are going into bags right now, in the customer's zone: the program
  /// is on and a batch is switched on (the server works that out). Off means
  /// no card anywhere in the app (SC-14). Callers check this before placing
  /// a badge or sticker, so nothing is left behind when it's off.
  static bool get inBags {
    final cards = Get.find<SplashController>().configModelOrNull?.scratchCards;
    if (cards == null || !cards.active) return false;
    final List<int>? zones = cards.zoneIds;
    if (zones == null) return true;
    final List<int> mine =
        AddressHelper.getUserAddressFromSharedPref()?.zoneIds ?? const [];
    return mine.any(zones.contains);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'scratch_card_label'.tr,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => ScratchCardSheet.show(context),
        child: SizedBox(
          width: width * scale,
          height: height * scale,
          child: FittedBox(
            child: SizedBox(
              width: width,
              height: height,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 80,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: WaddyColors.primary,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: WaddyColors.ink.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: MediaQuery.withNoTextScaling(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                'scratch_card_label'.tr,
                                maxLines: 1,
                                style: waddyBold.copyWith(
                                  fontSize: compact ? 15 : 11.5,
                                  fontWeight: FontWeight.w900,
                                  color: WaddyColors.mint,
                                ),
                              ),
                              if (!compact) const SizedBox(height: 1),
                              if (!compact)
                                Text(
                                  moment == ScratchTeaserMoment.delivered
                                      ? 'scratch_badge_delivered'.tr
                                      : 'scratch_comes_with_order'.tr,
                                  maxLines: 1,
                                  style: waddyMedium.copyWith(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: WaddyColors.surface,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const PositionedDirectional(
                    start: 18,
                    top: 0,
                    child: ScratchFlipCard(width: 80, height: 92),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Just the card, no plate: a sticker stuck to a bar or a header. Tap opens
/// [ScratchCardSheet].
///
/// However small it is drawn, it takes taps over at least
/// [Dimensions.minTapTarget] square, centred on the card, so no caller can
/// place a sticker that is hard to hit. It dips under the finger so the tap
/// is answered before the sheet arrives.
class ScratchCardSticker extends StatefulWidget {
  final double width;
  final double height;

  /// Flip to show sample prizes.
  final bool flips;

  const ScratchCardSticker({
    super.key,
    required this.width,
    required this.height,
    this.flips = false,
  });

  @override
  State<ScratchCardSticker> createState() => _ScratchCardStickerState();
}

class _ScratchCardStickerState extends State<ScratchCardSticker> {
  bool _pressed = false;

  void _press(bool down) {
    if (_pressed != down) setState(() => _pressed = down);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'scratch_card_label'.tr,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press(true),
        onTapUp: (_) => _press(false),
        onTapCancel: () => _press(false),
        onTap: () => ScratchCardSheet.show(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: Dimensions.minTapTarget,
            minHeight: Dimensions.minTapTarget,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: AnimatedScale(
              scale: _pressed ? 0.9 : 1,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              child: ScratchFlipCard(
                width: widget.width,
                height: widget.height,
                flips: widget.flips,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A full-width bar in the XP chip's colours (mint surface, mint border,
/// mint-ink text) for the confirmation and order details: a flipping card at
/// the start, a bold title over one short line, and a chevron because it
/// opens [ScratchCardSheet].
class ScratchCardBar extends StatelessWidget {
  final ScratchTeaserMoment moment;
  const ScratchCardBar({super.key, required this.moment});

  (String, String) get _copy => switch (moment) {
    ScratchTeaserMoment.delivered => (
      'scratch_bar_delivered_title',
      'scratch_bar_delivered_body',
    ),
    ScratchTeaserMoment.onTheWay => (
      'scratch_bar_on_way_title',
      'scratch_bar_on_way_body',
    ),
    _ => ('scratch_bar_placed_title', 'scratch_bar_placed_body'),
  };

  @override
  Widget build(BuildContext context) {
    final (String title, String body) = _copy;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => ScratchCardSheet.show(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsetsDirectional.fromSTEB(
            Dimensions.paddingSizeMedium,
            Dimensions.paddingSizeMedium,
            Dimensions.paddingSizeSmall,
            Dimensions.paddingSizeMedium,
          ),
          decoration: BoxDecoration(
            color: WaddyColors.mintSurface,
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            border: Border.all(
              color: WaddyColors.mint.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              const ScratchFlipCard(width: 40, height: 46),
              const SizedBox(width: Dimensions.paddingSizeMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.tr,
                      style: waddyBold.copyWith(
                        fontSize: Dimensions.fontSizeDefault,
                        color: WaddyColors.mintInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body.tr,
                      style: waddyMedium.copyWith(
                        fontSize: Dimensions.fontSizeSmall,
                        color: WaddyColors.mintInk,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: WaddyColors.mintInk,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
