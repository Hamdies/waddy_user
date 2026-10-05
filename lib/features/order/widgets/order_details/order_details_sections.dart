import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/item/domain/produce_preference.dart';
import 'package:lottie/lottie.dart' hide Marker;
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/features/order/controllers/order_controller.dart';
import 'package:waddy_app/features/order/domain/models/order_details_model.dart';
import 'package:waddy_app/features/order/domain/models/order_model.dart';
import 'package:waddy_app/features/order/domain/models/order_status.dart';
import 'package:waddy_app/features/order/widgets/rider_helmet.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Order details — the sections of the redesigned screen (Claude Design
// "Order Details"). The screen owns data, polling and the map; everything in
// this file is presentation plus the two sheets (bill, cancel).
//
// Four live stages drive the layout:
//   preparing  → no rider yet: "assigning" card
//   collecting → rider assigned, heading to the store: rider card
//   onWay      → picked up: rider card; once the rider is within ~1.5 km
//                the screen swaps to a full-bleed map with these cards on a
//                sheet ([OrderNearSheet])
//   delivered  → mint header with the delivery time, outcome card, rate
//                rider / store
// plus `closed` for cancelled / failed (red header) and refund states (amber
// header), which reuse the delivered layout with a different outcome card.
// ─────────────────────────────────────────────────────────────────────────────

enum OrderStage { preparing, collecting, onWay, delivered, closed }

extension OrderStageX on OrderStage {
  bool get isLive =>
      this == OrderStage.preparing ||
      this == OrderStage.collecting ||
      this == OrderStage.onWay;
}

OrderStage orderStageOf(OrderModel order) {
  final OrderStatus? status = OrderStatus.fromString(order.orderStatus);
  switch (status) {
    case OrderStatus.delivered:
    case OrderStatus.refundRequestCanceled:
      return OrderStage.delivered;
    case OrderStatus.failed:
    case OrderStatus.canceled:
    case OrderStatus.refundRequested:
    case OrderStatus.refunded:
      return OrderStage.closed;
    case OrderStatus.pickedUp:
      return OrderStage.onWay;
    default:
      return order.deliveryMan != null
          ? OrderStage.collecting
          : OrderStage.preparing;
  }
}

/// ", " in English, "، " in Arabic.
String listSeparator() => Get.locale?.languageCode == 'ar' ? '، ' : ', ';

/// Money lines for the bill sheet, computed once by the screen.
class OrderBill {
  final double itemsPrice;
  final double addOns;
  final double discount;
  final double couponDiscount;
  final double referrerBonus;
  final double tax;
  final bool taxIncluded;
  final double deliveryCharge;
  final double dmTips;
  final double additionalCharge;
  final double extraPackaging;
  final double total;

  const OrderBill({
    required this.itemsPrice,
    required this.addOns,
    required this.discount,
    required this.couponDiscount,
    required this.referrerBonus,
    required this.tax,
    required this.taxIncluded,
    required this.deliveryCharge,
    required this.dmTips,
    required this.additionalCharge,
    required this.extraPackaging,
    required this.total,
  });

  double get subTotal => itemsPrice + addOns;
}

// ─── Header ──────────────────────────────────────────────────────────────────
// Full-bleed colour band that owns the status-bar inset. Mint while the order
// is live or delivered, red once it is cancelled or failed, amber for refunds.
enum OrderHeaderTone { mint, red, amber }

extension OrderHeaderToneX on OrderHeaderTone {
  /// (band, ink on the band, pill on the band)
  (Color, Color, Color) get colors => switch (this) {
    OrderHeaderTone.mint => (
      WaddyColors.mint,
      WaddyColors.primary,
      WaddyColors.primary.withValues(alpha: 0.12),
    ),
    OrderHeaderTone.red => (
      WaddyColors.statusRed,
      WaddyColors.surface,
      WaddyColors.surface.withValues(alpha: 0.18),
    ),
    OrderHeaderTone.amber => (
      WaddyColors.statusAmber,
      WaddyColors.statusAmberInk,
      WaddyColors.statusAmberInk.withValues(alpha: 0.12),
    ),
  };
}

/// The header's arrival line, decided by the screen.
class OrderEta {
  final String label;

  /// "On time" / "Running late", shown after a dot. Null for none.
  final String? note;
  final bool delayed;

  /// Whole minutes to arrival when known, for the near-state sheet's large
  /// figure.
  final int? minutes;
  const OrderEta({
    required this.label,
    this.note,
    this.delayed = false,
    this.minutes,
  });
}

class OrderDetailsHeader extends StatelessWidget {
  final String storeName;
  final OrderStage stage;
  final OrderHeaderTone tone;
  final String statusTitle;

  /// Pill text once the order has ended ("Cancelled at 9:58 PM"). Null hides
  /// the pill.
  final String? endedSubtitle;

  final OrderEta eta;
  final bool refreshing;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  const OrderDetailsHeader({
    super.key,
    required this.storeName,
    required this.stage,
    required this.tone,
    required this.statusTitle,
    this.endedSubtitle,
    required this.eta,
    required this.refreshing,
    required this.onBack,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final bool live = stage.isLive;
    final (Color bg, Color ink, Color pill) = tone.colors;
    final double top = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value:
          tone == OrderHeaderTone.red
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        color: bg,
        padding: EdgeInsets.only(top: top, bottom: Dimensions.paddingSizeLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeSmall,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: onBack,
                      tooltip:
                          MaterialLocalizations.of(context).backButtonTooltip,
                      icon: Icon(Icons.arrow_back_rounded, color: ink),
                    ),
                    Expanded(
                      child: Text(
                        storeName,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: waddyBody.copyWith(
                          fontSize: Dimensions.fontSizeLarge,
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                    ),
                    // Balances the back button so the title stays centred.
                    const SizedBox(width: Dimensions.minTapTarget),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeDefault,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    statusTitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: waddyBody.copyWith(
                      fontSize: Dimensions.fontSizeOverLarge,
                      fontWeight: FontWeight.w800,
                      color: ink,
                      height: 1.15,
                    ),
                  ),
                  if (live) ...[
                    const SizedBox(height: Dimensions.paddingSizeMedium),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(child: _EtaChip(eta: eta)),
                        const SizedBox(width: Dimensions.paddingSizeSmall),
                        _RefreshButton(
                          refreshing: refreshing,
                          onTap: onRefresh,
                        ),
                      ],
                    ),
                  ] else if (endedSubtitle != null) ...[
                    const SizedBox(height: Dimensions.paddingSizeMedium),
                    Container(
                      constraints: const BoxConstraints(
                        minHeight: Dimensions.minTapTarget - 8,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: Dimensions.paddingSizeDefault,
                        vertical: Dimensions.paddingSizeSmall,
                      ),
                      decoration: BoxDecoration(
                        color: pill,
                        borderRadius: BorderRadius.circular(
                          Dimensions.radiusDefault,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              endedSubtitle!,
                              textAlign: TextAlign.center,
                              style: waddyBody.copyWith(
                                fontSize: Dimensions.fontSizeDefault,
                                fontWeight: FontWeight.w700,
                                color: ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Near state: map + sheet ─────────────────────────────────────────────────

/// A round (icon) or pill (label) button floating over the map.
class OrderMapButton extends StatelessWidget {
  final IconData? icon;
  final String? label;
  final String? semanticLabel;
  final VoidCallback onTap;
  const OrderMapButton({
    super.key,
    this.icon,
    this.label,
    this.semanticLabel,
    required this.onTap,
  }) : assert(icon != null || label != null);

  @override
  Widget build(BuildContext context) {
    final bool round = label == null;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: WaddyColors.surface,
        shape: round ? const CircleBorder() : const StadiumBorder(),
        elevation: 3,
        shadowColor: WaddyColors.ink.withValues(alpha: 0.3),
        child: InkWell(
          customBorder: round ? const CircleBorder() : const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: Dimensions.minTapTarget,
              minHeight: Dimensions.minTapTarget,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: round ? 0 : Dimensions.paddingSizeDefault,
              ),
              child: Center(
                widthFactor: 1,
                child:
                    round
                        ? Icon(icon, size: 22, color: WaddyColors.primary)
                        : Text(
                          label!,
                          style: waddyBody.copyWith(
                            fontSize: Dimensions.fontSizeDefault,
                            fontWeight: FontWeight.w700,
                            color: WaddyColors.primary,
                          ),
                        ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The sheet over the near-state map: grab handle, [summary], then the
/// order's cards.
class OrderNearSheet extends StatelessWidget {
  final ScrollController controller;
  final double bottomInset;
  final Widget summary;
  final List<Widget> children;
  const OrderNearSheet({
    super.key,
    required this.controller,
    required this.bottomInset,
    required this.summary,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: WaddyColors.surfaceRaised,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Dimensions.radiusExtraLarge),
        ),
        boxShadow: [
          BoxShadow(
            color: WaddyColors.ink.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Dimensions.radiusExtraLarge),
        ),
        child: ListView(
          controller: controller,
          padding: EdgeInsets.fromLTRB(
            Dimensions.paddingSizeDefault,
            0,
            Dimensions.paddingSizeDefault,
            Dimensions.paddingSizeExtraOverLarge + bottomInset,
          ),
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(
                  vertical: Dimensions.paddingSizeMedium,
                ),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: WaddyColors.inkMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            summary,
            const SizedBox(height: Dimensions.paddingSizeLarge),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Top of the near-state sheet: "Estimated arrival", the minutes in large
/// type, the status line, and the three-step progress bar.
class OrderNearSummary extends StatelessWidget {
  final OrderEta eta;
  final String title;

  /// How far along the last step (on the way) is, 0–1.
  final double rideProgress;
  const OrderNearSummary({
    super.key,
    required this.eta,
    required this.title,
    required this.rideProgress,
  });

  @override
  Widget build(BuildContext context) {
    final int? minutes = eta.minutes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'od_eta_heading'.tr,
          style: waddyBody.copyWith(
            fontSize: Dimensions.fontSizeDefault,
            color: WaddyColors.inkLight,
          ),
        ),
        const SizedBox(height: Dimensions.paddingSizeExtraSmall),
        Text(
          minutes != null
              ? 'od_eta_minutes'.trParams({'min': '$minutes'})
              : eta.label,
          style: waddyBody.copyWith(
            fontSize: Dimensions.fontSizeOverLarge,
            fontWeight: FontWeight.w800,
            color: WaddyColors.ink,
            height: 1.15,
          ),
        ),
        const SizedBox(height: Dimensions.paddingSizeExtraSmall),
        Text(
          title,
          style: waddyBody.copyWith(
            fontSize: Dimensions.fontSizeLarge,
            fontWeight: FontWeight.w600,
            color: WaddyColors.primary,
          ),
        ),
        const SizedBox(height: Dimensions.paddingSizeMedium),
        Row(
          children: [
            const Expanded(child: _ProgressStep(value: 1)),
            const SizedBox(width: Dimensions.paddingSizeSmall),
            const Expanded(child: _ProgressStep(value: 1)),
            const SizedBox(width: Dimensions.paddingSizeSmall),
            Expanded(child: _ProgressStep(value: rideProgress)),
          ],
        ),
      ],
    );
  }
}

class _ProgressStep extends StatelessWidget {
  final double value;
  const _ProgressStep({required this.value});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 6,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          builder:
              (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 6,
                backgroundColor: WaddyColors.progressTrack,
                valueColor: const AlwaysStoppedAnimation(
                  WaddyColors.progressFill,
                ),
              ),
        ),
      ),
    );
  }
}

/// The stage animation, on a continuation of the header's colour band at the
/// top of the scrolling body. Only the title and ETA stay pinned; this
/// scrolls away with the content, the same way the map does once the order
/// is on its way.
class OrderStageBand extends StatelessWidget {
  final String asset;
  final OrderHeaderTone tone;

  /// Live stages loop; a finished order plays its animation once and holds
  /// the last frame, so the delivered check doesn't keep un-drawing.
  final bool loop;
  const OrderStageBand({
    super.key,
    required this.asset,
    required this.tone,
    required this.loop,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      color: tone.colors.$1,
      padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeLarge),
      alignment: Alignment.topCenter,
      child: _StageAnimation(asset: asset, loop: loop),
    );
  }
}

class _EtaChip extends StatelessWidget {
  final OrderEta eta;
  const _EtaChip({required this.eta});

  @override
  Widget build(BuildContext context) {
    final style = waddyBody.copyWith(
      fontSize: Dimensions.fontSizeDefault,
      fontWeight: FontWeight.w700,
      color: WaddyColors.primary,
    );
    return Container(
      constraints: const BoxConstraints(minHeight: Dimensions.minTapTarget),
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
        vertical: Dimensions.paddingSizeSmall,
      ),
      decoration: BoxDecoration(
        color: WaddyColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      ),
      // A min-width Row inside the min-height box centres the text
      // vertically without stretching the chip to the full width.
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: eta.label),
                  if (eta.note != null) ...[
                    const TextSpan(text: '  ·  '),
                    TextSpan(
                      text: eta.note,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: eta.delayed ? WaddyColors.coralInk : null,
                      ),
                    ),
                  ],
                ],
              ),
              textAlign: TextAlign.center,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

/// The stage Lottie under the header title. Keyed by asset so a stage change
/// swaps it with a short cross-fade; still under reduced motion.
class _StageAnimation extends StatelessWidget {
  final String asset;
  final bool loop;
  const _StageAnimation({required this.asset, required this.loop});

  static const double _size = 132;

  /// The artwork fills only the middle of its 500×500 canvas; scale it up
  /// inside the tile instead of growing the tile.
  static const double _zoom = 1.3;

  @override
  Widget build(BuildContext context) {
    final bool still = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      width: _size,
      height: _size,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: RepaintBoundary(
          key: ValueKey(asset),
          child: ExcludeSemantics(
            child: ClipRect(
              child: Transform.scale(
                scale: _zoom,
                child: Lottie.asset(
                  asset,
                  width: _size,
                  height: _size,
                  fit: BoxFit.contain,
                  animate: !still,
                  repeat: loop,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RefreshButton extends StatelessWidget {
  final bool refreshing;
  final VoidCallback onTap;
  const _RefreshButton({required this.refreshing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'od_refresh'.tr,
      child: Material(
        color: WaddyColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        child: InkWell(
          onTap: refreshing ? null : onTap,
          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
          child: SizedBox(
            width: Dimensions.minTapTarget,
            height: Dimensions.minTapTarget,
            child: Center(
              child:
                  refreshing
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: WaddyColors.primary,
                        ),
                      )
                      : const Icon(
                        Icons.refresh_rounded,
                        size: 20,
                        color: WaddyColors.primary,
                      ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Shared card chrome ──────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final Widget child;
  final Color borderColor;
  const _Card({required this.child, this.borderColor = WaddyColors.divider});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: WaddyColors.surface,
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

/// One hairline between rows inside a card.
class _Hairline extends StatelessWidget {
  final Color color;
  const _Hairline({this.color = WaddyColors.divider});

  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, thickness: 1, color: color);
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _CircleAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: WaddyColors.surface,
        shape: const CircleBorder(side: BorderSide(color: WaddyColors.divider)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: Dimensions.minTapTarget,
            height: Dimensions.minTapTarget,
            child: Icon(icon, size: 20, color: WaddyColors.mintInk),
          ),
        ),
      ),
    );
  }
}

/// Five tappable stars. The tapped value is handed on, so the review screen
/// opens already showing it.
class _StarRow extends StatelessWidget {
  final String title;
  final Color titleColor;
  final void Function(int stars) onRate;
  const _StarRow({
    required this.title,
    required this.onRate,
    this.titleColor = WaddyColors.ink,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: _rowTitleStyle.copyWith(color: titleColor)),
        const SizedBox(height: Dimensions.paddingSizeExtraSmall),
        Row(
          children: List.generate(5, (i) {
            return Semantics(
              button: true,
              label: 'od_rate_stars'.trParams({'count': '${i + 1}'}),
              child: InkResponse(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onRate(i + 1);
                },
                radius: Dimensions.minTapTarget / 2,
                child: const SizedBox(
                  width: Dimensions.minTapTarget,
                  height: Dimensions.minTapTarget,
                  child: Icon(
                    Icons.star_outline_rounded,
                    size: 32,
                    color: WaddyColors.amberInk,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.chevron_right_rounded,
      size: 20,
      color: WaddyColors.inkLight,
    );
  }
}

TextStyle get _titleStyle => waddyBody.copyWith(
  fontSize: Dimensions.fontSizeLarge,
  fontWeight: FontWeight.w700,
  color: WaddyColors.ink,
  height: 1.3,
);

TextStyle get _rowTitleStyle => waddyBody.copyWith(
  fontSize: Dimensions.fontSizeDefault,
  fontWeight: FontWeight.w700,
  color: WaddyColors.ink,
  height: 1.35,
);

TextStyle get _metaStyle => waddyBody.copyWith(
  fontSize: Dimensions.fontSizeExtraSmall,
  fontWeight: FontWeight.w500,
  color: WaddyColors.inkLight,
  height: 1.4,
);

TextStyle get _copyStyle => waddyBody.copyWith(
  fontSize: Dimensions.fontSizeDefault,
  fontWeight: FontWeight.w500,
  color: WaddyColors.inkMid,
  height: 1.4,
);

/// Full-saturation mint is the "press this" colour; this is the one place in
/// the body it appears.
class _MintAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool busy;
  final VoidCallback onTap;
  const _MintAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: busy ? null : onTap,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(Dimensions.minTapTarget),
        backgroundColor: WaddyColors.mint,
        foregroundColor: WaddyColors.primary,
        disabledBackgroundColor: WaddyColors.mint.withValues(alpha: 0.6),
        disabledForegroundColor: WaddyColors.primary,
        textStyle: waddyBody.copyWith(
          fontSize: Dimensions.fontSizeDefault,
          fontWeight: FontWeight.w800,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        ),
      ),
      icon:
          busy
              ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: WaddyColors.primary,
                ),
              )
              : Icon(icon, size: 20),
      label: Text(label),
    );
  }
}

// ─── Delivery PIN ────────────────────────────────────────────────────────────
class OrderPinCard extends StatefulWidget {
  final String otp;
  const OrderPinCard({super.key, required this.otp});

  @override
  State<OrderPinCard> createState() => _OrderPinCardState();
}

class _OrderPinCardState extends State<OrderPinCard> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.otp));
    HapticFeedback.lightImpact();
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    // The one thing to act on right now, so it wears the brand tint.
    return _NowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconDisc(
                icon: Icons.verified_user_outlined,
                background: WaddyColors.surface,
              ),
              const SizedBox(width: Dimensions.paddingSizeMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('od_delivery_pin'.tr, style: _titleStyle),
                    const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                    Text(
                      'od_pin_hint'.tr,
                      style: _metaStyle.copyWith(color: WaddyColors.mintInk),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _copy,
                style: TextButton.styleFrom(
                  foregroundColor: WaddyColors.mintInk,
                  minimumSize: const Size(
                    Dimensions.minTapTarget,
                    Dimensions.minTapTarget,
                  ),
                ),
                child: Text(
                  _copied ? 'od_copied'.tr : 'od_copy'.tr,
                  style: waddyBody.copyWith(
                    fontSize: Dimensions.fontSizeDefault,
                    fontWeight: FontWeight.w800,
                    color: WaddyColors.mintInk,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Dimensions.paddingSizeMedium),
          // Digits read left-to-right in both languages.
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              children:
                  widget.otp.split('').map((digit) {
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: Dimensions.paddingSizeExtraSmall,
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: Dimensions.paddingSizeMedium,
                        ),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: WaddyColors.surface,
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusDefault,
                          ),
                          border: Border.all(
                            color: WaddyColors.mintSurfaceDeep,
                          ),
                        ),
                        child: Text(
                          digit,
                          style: waddyBody.copyWith(
                            fontSize: Dimensions.fontSizeOverLarge,
                            fontWeight: FontWeight.w800,
                            color: WaddyColors.primary,
                            height: 1.1,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mint-tinted card for the slot at the top of the body: whatever the
/// customer should act on now (the PIN, rating a delivered order).
class _NowCard extends StatelessWidget {
  final Widget child;
  const _NowCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        color: WaddyColors.mintSurface,
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        border: Border.all(color: WaddyColors.mintSurfaceDeep),
      ),
      child: child,
    );
  }
}

class _IconDisc extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color color;
  const _IconDisc({
    required this.icon,
    this.background = WaddyColors.mintSurface,
    this.color = WaddyColors.mintInk,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Dimensions.minTapTarget,
      height: Dimensions.minTapTarget,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, size: 22, color: color),
    );
  }
}

// ─── Delivered ───────────────────────────────────────────────────────────────
// The last thing a customer sees before their next order: celebrate, one
// rating row, and the way back in.
class OrderEndingCard extends StatelessWidget {
  final String headline;
  final String subtitle;
  final String? tipLine;
  final void Function(int stars)? onRate;
  final VoidCallback? onReorder;
  final bool reordering;

  const OrderEndingCard({
    super.key,
    required this.headline,
    required this.subtitle,
    this.tipLine,
    this.onRate,
    this.onReorder,
    this.reordering = false,
  });

  @override
  Widget build(BuildContext context) {
    return _NowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            headline,
            style: waddyBody.copyWith(
              fontSize: Dimensions.fontSizeExtraLarge,
              fontWeight: FontWeight.w800,
              color: WaddyColors.primary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeExtraSmall),
          Text(
            subtitle,
            style: _copyStyle.copyWith(
              color: WaddyColors.mintInk,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (tipLine != null) ...[
            const SizedBox(height: Dimensions.paddingSizeSmall),
            Row(
              children: [
                const Icon(
                  Icons.volunteer_activism_outlined,
                  size: 18,
                  color: WaddyColors.mintInk,
                ),
                const SizedBox(width: Dimensions.paddingSizeSmall),
                Expanded(
                  child: Text(
                    tipLine!,
                    style: _metaStyle.copyWith(color: WaddyColors.mintInk),
                  ),
                ),
              ],
            ),
          ],
          if (onRate != null) ...[
            const SizedBox(height: Dimensions.paddingSizeMedium),
            const _Hairline(color: WaddyColors.mintSurfaceDeep),
            const SizedBox(height: Dimensions.paddingSizeMedium),
            _StarRow(
              title: 'od_how_was_it'.tr,
              titleColor: WaddyColors.primary,
              onRate: onRate!,
            ),
          ],
          if (onReorder != null) ...[
            const SizedBox(height: Dimensions.paddingSizeMedium),
            _MintAction(
              label: 'od_order_again'.tr,
              icon: Icons.replay_rounded,
              busy: reordering,
              onTap: onReorder!,
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Outcome (cancelled / failed / refund) ───────────────────────────────────
class OrderOutcomeCard extends StatelessWidget {
  final bool positive;
  final IconData icon;
  final String title;
  final String subtitle;

  /// Why the order ended, when someone wrote a reason. Null hides it.
  final String? reason;

  /// Puts the same items back in the cart. Null hides the button.
  final VoidCallback? onReorder;
  final bool reordering;

  const OrderOutcomeCard({
    super.key,
    required this.positive,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.reason,
    this.onReorder,
    this.reordering = false,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      borderColor:
          positive
              ? WaddyColors.divider
              : WaddyColors.coral.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _IconDisc(
                  icon: icon,
                  background:
                      positive
                          ? WaddyColors.mintSurface
                          : WaddyColors.coralSurface,
                  color: positive ? WaddyColors.mintInk : WaddyColors.coralInk,
                ),
                const SizedBox(width: Dimensions.paddingSizeMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: _titleStyle),
                      const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                      Text(subtitle, style: _metaStyle),
                    ],
                  ),
                ),
              ],
            ),
            if (reason != null) ...[
              const SizedBox(height: Dimensions.paddingSizeMedium),
              const _Hairline(),
              const SizedBox(height: Dimensions.paddingSizeMedium),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${'od_reason'.tr}  ',
                      style: const TextStyle(color: WaddyColors.inkLight),
                    ),
                    TextSpan(text: reason),
                  ],
                ),
                style: _rowTitleStyle.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
            if (onReorder != null) ...[
              const SizedBox(height: Dimensions.paddingSizeDefault),
              _MintAction(
                label: 'od_order_again'.tr,
                icon: Icons.replay_rounded,
                busy: reordering,
                onTap: onReorder!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Assigning a rider ───────────────────────────────────────────────────────
class OrderAssigningCard extends StatelessWidget {
  final String text;

  /// Tip already added at checkout, or null when none.
  final String? tipLine;
  const OrderAssigningCard({super.key, required this.text, this.tipLine});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
            child: Row(
              children: [
                const RiderHelmet(size: Dimensions.minTapTarget),
                const SizedBox(width: Dimensions.paddingSizeMedium),
                Expanded(child: Text(text, style: _rowTitleStyle)),
              ],
            ),
          ),
          if (tipLine != null) _TipFooter(text: tipLine!),
        ],
      ),
    );
  }
}

class _TipFooter extends StatelessWidget {
  final String text;
  const _TipFooter({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: WaddyColors.divider)),
      ),
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      child: Row(
        children: [
          const Icon(
            Icons.volunteer_activism_outlined,
            size: 18,
            color: WaddyColors.mintInk,
          ),
          const SizedBox(width: Dimensions.paddingSizeSmall),
          Expanded(child: Text(text, style: _copyStyle)),
        ],
      ),
    );
  }
}

// ─── Rider ───────────────────────────────────────────────────────────────────
class OrderRiderCard extends StatelessWidget {
  final DeliveryMan rider;
  final VoidCallback? onChat;
  final VoidCallback? onCall;
  final String? tipLine;

  const OrderRiderCard({
    super.key,
    required this.rider,
    this.onChat,
    this.onCall,
    this.tipLine,
  });

  @override
  Widget build(BuildContext context) {
    final String name = '${rider.fName ?? ''} ${rider.lName ?? ''}'.trim();
    final String displayName = name.isNotEmpty ? name : 'delivery_partner'.tr;
    final double? rating = rider.avgRating;
    final int ratings = rider.ratingCount ?? 0;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
            child: Row(
              children: [
                // Every rider shows as the Waddi helmet, not their own photo, so
                // the card, the glyph and the map marker are one character.
                const RiderHelmet(),
                const SizedBox(width: Dimensions.paddingSizeMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _titleStyle,
                      ),
                      const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                      // Names the role: the customer's own name and number sit
                      // a card below, and they can be the same common name.
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'od_your_rider'.tr,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _metaStyle.copyWith(
                                color: WaddyColors.mintInk,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (rating != null && rating > 0 && ratings > 0) ...[
                            const SizedBox(width: Dimensions.paddingSizeSmall),
                            const Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: WaddyColors.amberInk,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${rating.toStringAsFixed(1)} (${'od_ratings_count'.trParams({'count': '$ratings'})})',
                              style: _metaStyle.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (onChat != null) ...[
                  const SizedBox(width: Dimensions.paddingSizeSmall),
                  _CircleAction(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'chat'.tr,
                    onTap: onChat!,
                  ),
                ],
                if (onCall != null) ...[
                  const SizedBox(width: Dimensions.paddingSizeSmall),
                  _CircleAction(
                    icon: Icons.call_outlined,
                    label: 'od_call_name'.trParams({'name': displayName}),
                    onTap: onCall!,
                  ),
                ],
              ],
            ),
          ),
          if (tipLine != null) _TipFooter(text: tipLine!),
        ],
      ),
    );
  }
}

// ─── Delivery details ────────────────────────────────────────────────────────
class OrderDeliveryDetailsCard extends StatelessWidget {
  final String? contactLine;
  final String addressTitle;
  final String? addressLine;
  final String? instructions;

  const OrderDeliveryDetailsCard({
    super.key,
    required this.contactLine,
    required this.addressTitle,
    required this.addressLine,
    required this.instructions,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      if (contactLine != null)
        _InfoRow(
          icon: Icons.call_outlined,
          title: contactLine!,
          subtitle: 'od_partner_may_call'.tr,
        ),
      _InfoRow(
        icon: Icons.location_on_outlined,
        title: addressTitle,
        subtitle: addressLine,
      ),
      if (instructions != null)
        _InfoRow(
          icon: Icons.sticky_note_2_outlined,
          title: 'delivery_instructions'.tr,
          subtitle: instructions,
        ),
    ];

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: WaddyColors.mintSurface,
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        border: Border.all(color: WaddyColors.mintSurfaceDeep),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeDefault,
              vertical: Dimensions.paddingSizeMedium,
            ),
            child: Text(
              'od_details_banner'.tr,
              style: waddyBody.copyWith(
                fontSize: Dimensions.fontSizeDefault,
                fontWeight: FontWeight.w700,
                color: WaddyColors.mintInk,
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: WaddyColors.surface,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(Dimensions.radiusLarge),
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeDefault,
            ),
            child: Column(
              children: [
                for (int i = 0; i < rows.length; i++) ...[
                  if (i > 0) const _Hairline(),
                  rows[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  const _InfoRow({required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: Dimensions.paddingSizeDefault,
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: WaddyColors.inkMid),
          const SizedBox(width: Dimensions.paddingSizeMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _rowTitleStyle),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                  Text(subtitle!, style: _metaStyle),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Store + order ───────────────────────────────────────────────────────────
class OrderStoreCard extends StatelessWidget {
  final Store? store;
  final VoidCallback? onCallStore;
  final String orderLabel;
  final String itemsSummary;
  final VoidCallback onOpenBill;
  final IconData paymentIcon;
  final String paymentLabel;
  final String amount;

  /// "Have the cash ready" reminder, only while a cash order is live.
  final String? cashNote;

  const OrderStoreCard({
    super.key,
    required this.store,
    required this.orderLabel,
    required this.itemsSummary,
    required this.onOpenBill,
    required this.paymentIcon,
    required this.paymentLabel,
    required this.amount,
    this.cashNote,
    this.onCallStore,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (store != null)
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: WaddyColors.divider)),
              ),
              padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    clipBehavior: Clip.antiAlias,
                    decoration: const BoxDecoration(
                      color: WaddyColors.amberSurface,
                      shape: BoxShape.circle,
                    ),
                    child:
                        (store!.logoFullUrl ?? '').isNotEmpty
                            ? CustomImage(
                              image: store!.logoFullUrl!,
                              height: 48,
                              width: 48,
                              fit: BoxFit.cover,
                            )
                            : const Icon(
                              Icons.storefront_outlined,
                              color: WaddyColors.amberInk,
                            ),
                  ),
                  const SizedBox(width: Dimensions.paddingSizeMedium),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store!.name ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _titleStyle,
                        ),
                        if ((store!.address ?? '').isNotEmpty) ...[
                          const SizedBox(
                            height: Dimensions.paddingSizeExtraSmall,
                          ),
                          Text(
                            store!.address!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _metaStyle,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (onCallStore != null) ...[
                    const SizedBox(width: Dimensions.paddingSizeSmall),
                    _CircleAction(
                      icon: Icons.call_outlined,
                      label: 'od_call_name'.trParams({
                        'name': store!.name ?? '',
                      }),
                      onTap: onCallStore!,
                    ),
                  ],
                ],
              ),
            ),
          InkWell(
            onTap: onOpenBill,
            child: Padding(
              padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
              child: Row(
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    size: 20,
                    color: WaddyColors.inkMid,
                  ),
                  const SizedBox(width: Dimensions.paddingSizeMedium),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(orderLabel, style: _rowTitleStyle),
                        const SizedBox(
                          height: Dimensions.paddingSizeExtraSmall,
                        ),
                        Text(
                          itemsSummary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: _metaStyle,
                        ),
                      ],
                    ),
                  ),
                  const _Chevron(),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeDefault,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Hairline(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: Dimensions.paddingSizeDefault,
                  ),
                  child: Row(
                    children: [
                      Icon(paymentIcon, size: 20, color: WaddyColors.inkMid),
                      const SizedBox(width: Dimensions.paddingSizeMedium),
                      Expanded(
                        child: Text(
                          paymentLabel,
                          style: _rowTitleStyle.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: Dimensions.paddingSizeSmall),
                      Text(
                        amount,
                        textDirection: TextDirection.ltr,
                        style: _rowTitleStyle.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                if (cashNote != null)
                  Container(
                    margin: const EdgeInsets.only(
                      bottom: Dimensions.paddingSizeDefault,
                    ),
                    padding: const EdgeInsets.all(Dimensions.paddingSizeMedium),
                    decoration: BoxDecoration(
                      color: WaddyColors.mintSurface,
                      borderRadius: BorderRadius.circular(
                        Dimensions.radiusDefault,
                      ),
                    ),
                    child: Text(
                      cashNote!,
                      style: waddyBody.copyWith(
                        fontSize: Dimensions.fontSizeDefault,
                        fontWeight: FontWeight.w700,
                        color: WaddyColors.mintInk,
                        height: 1.4,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Help + cancel ───────────────────────────────────────────────────────────
class OrderHelpCard extends StatelessWidget {
  final VoidCallback onHelp;
  final VoidCallback? onCancel;

  const OrderHelpCard({super.key, required this.onHelp, this.onCancel});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onHelp,
            child: Padding(
              padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
              child: Row(
                children: [
                  const _IconDisc(icon: Icons.headset_mic_outlined),
                  const SizedBox(width: Dimensions.paddingSizeMedium),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('od_need_help'.tr, style: _rowTitleStyle),
                        const SizedBox(
                          height: Dimensions.paddingSizeExtraSmall,
                        ),
                        Text('od_get_help'.tr, style: _metaStyle),
                      ],
                    ),
                  ),
                  const _Chevron(),
                ],
              ),
            ),
          ),
          if (onCancel != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeDefault,
              ),
              child: _Hairline(),
            ),
            InkWell(
              onTap: onCancel,
              child: Padding(
                padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                child: Row(
                  children: [
                    // Centred under the help disc so both labels align.
                    const SizedBox(
                      width: Dimensions.minTapTarget,
                      child: Icon(
                        Icons.cancel_outlined,
                        size: 20,
                        color: WaddyColors.inkMid,
                      ),
                    ),
                    const SizedBox(width: Dimensions.paddingSizeMedium),
                    Expanded(
                      child: Text(
                        'cancel_order'.tr,
                        style: _rowTitleStyle.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const _Chevron(),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Bill sheet ──────────────────────────────────────────────────────────────
class OrderBillSheet extends StatelessWidget {
  final String orderLabel;
  final List<OrderDetailsModel> items;
  final OrderBill bill;
  final String? paymentMethod;

  const OrderBillSheet({
    super.key,
    required this.orderLabel,
    required this.items,
    required this.bill,
    required this.paymentMethod,
  });

  static Future<void> show(
    BuildContext context, {
    required String orderLabel,
    required List<OrderDetailsModel> items,
    required OrderBill bill,
    required String? paymentMethod,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => OrderBillSheet(
            orderLabel: orderLabel,
            items: items,
            bill: bill,
            paymentMethod: paymentMethod,
          ),
    );
  }

  String _paymentLabel() {
    switch (paymentMethod) {
      case 'cash_on_delivery':
        return 'cash_on_delivery'.tr;
      case 'wallet':
        return 'wallet'.tr;
      case 'partial_payment':
        return 'partial_payment'.tr;
      case 'offline_payment':
        return 'offline_payment'.tr;
      default:
        return 'digital_payment'.tr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lines = <_BillLine>[
      // Items + add-ons only need a subtotal line when there are add-ons to
      // add up; otherwise it just repeats the same number.
      if (bill.addOns > 0) ...[
        _BillLine('item_price'.tr, bill.itemsPrice),
        _BillLine('addons'.tr, bill.addOns),
      ],
      _BillLine('subtotal'.tr, bill.subTotal, strong: true),
      if (bill.discount > 0) _BillLine('discount'.tr, -bill.discount),
      if (bill.couponDiscount > 0)
        _BillLine('coupon_discount'.tr, -bill.couponDiscount),
      if (bill.referrerBonus > 0)
        _BillLine('referral_discount'.tr, -bill.referrerBonus),
      if (bill.tax > 0)
        _BillLine(
          bill.taxIncluded
              ? '${'vat_tax'.tr} ${'tax_included'.tr}'
              : 'vat_tax'.tr,
          bill.tax,
        ),
      _BillLine('delivery_fee'.tr, bill.deliveryCharge),
      if (bill.dmTips > 0) _BillLine('od_rider_tip'.tr, bill.dmTips),
      if (bill.additionalCharge > 0)
        _BillLine('od_additional_charge'.tr, bill.additionalCharge),
      if (bill.extraPackaging > 0)
        _BillLine('od_extra_packaging'.tr, bill.extraPackaging),
    ];

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: WaddyColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(Dimensions.radiusExtraLarge),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: Dimensions.paddingSizeSmall),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: WaddyColors.divider,
                    borderRadius: BorderRadius.circular(
                      Dimensions.radiusExtraSmall,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Dimensions.paddingSizeDefault,
                  Dimensions.paddingSizeDefault,
                  Dimensions.paddingSizeDefault,
                  Dimensions.paddingSizeSmall,
                ),
                child: Text(orderLabel, style: _titleStyle),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    Dimensions.paddingSizeDefault,
                    0,
                    Dimensions.paddingSizeDefault,
                    Dimensions.paddingSizeDefault,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final item in items) _ItemLine(item: item),
                      if (items.isNotEmpty) ...[
                        const SizedBox(height: Dimensions.paddingSizeSmall),
                        const _Hairline(),
                        const SizedBox(height: Dimensions.paddingSizeMedium),
                      ],
                      for (final l in lines) l,
                      const SizedBox(height: Dimensions.paddingSizeSmall),
                      const Divider(height: 1, color: WaddyColors.divider),
                      const SizedBox(height: Dimensions.paddingSizeMedium),
                      _BillLine('total_amount'.tr, bill.total, total: true),
                      const SizedBox(height: Dimensions.paddingSizeMedium),
                      Row(
                        children: [
                          const Icon(
                            Icons.payments_outlined,
                            size: 18,
                            color: WaddyColors.inkLight,
                          ),
                          const SizedBox(width: Dimensions.paddingSizeSmall),
                          Text(
                            '${'payment_method'.tr}: ${_paymentLabel()}',
                            style: _metaStyle,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemLine extends StatelessWidget {
  final OrderDetailsModel item;
  const _ItemLine({required this.item});

  @override
  Widget build(BuildContext context) {
    final int qty = item.quantity ?? 1;
    final addOns = (item.addOns ?? [])
        .where((a) => (a.name ?? '').isNotEmpty)
        .map(
          (a) => (a.quantity ?? 1) > 1 ? '${a.name} ×${a.quantity}' : a.name!,
        )
        .join(listSeparator());
    // This app's words for the answer, else the server's.
    final String? preference =
        ProducePreference.label(item.preference) ?? item.preferenceLabel;
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: Dimensions.paddingSizeExtraSmall,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$qty × ${item.itemDetails?.name ?? ''}',
                  style: _rowTitleStyle.copyWith(fontWeight: FontWeight.w600),
                ),
                if (preference != null) Text(preference, style: _metaStyle),
                if (addOns.isNotEmpty) Text(addOns, style: _metaStyle),
              ],
            ),
          ),
          const SizedBox(width: Dimensions.paddingSizeMedium),
          Text(
            PriceConverter.convertPrice((item.price ?? 0) * qty),
            style: _rowTitleStyle.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _BillLine extends StatelessWidget {
  final String label;
  final double amount;
  final bool strong;
  final bool total;
  const _BillLine(
    this.label,
    this.amount, {
    this.strong = false,
    this.total = false,
  });

  @override
  Widget build(BuildContext context) {
    final style =
        total
            ? _titleStyle.copyWith(fontWeight: FontWeight.w800)
            : strong
            ? _rowTitleStyle
            : _copyStyle;
    final String value =
        amount < 0
            ? '- ${PriceConverter.convertPrice(-amount)}'
            : PriceConverter.convertPrice(amount);
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: Dimensions.paddingSizeExtraSmall,
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(
            value,
            style: style.copyWith(
              color: amount < 0 ? WaddyColors.mintInk : style.color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Cancel sheet ────────────────────────────────────────────────────────────
// The backend only accepts a customer cancel while the order is `pending`, and
// requires a reason; the reasons list is admin-configured and may be empty, in
// which case the customer types one.
class OrderCancelSheet extends StatefulWidget {
  final Future<void> Function(String reason) onConfirm;
  const OrderCancelSheet({super.key, required this.onConfirm});

  static Future<void> show(
    BuildContext context, {
    required Future<void> Function(String reason) onConfirm,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OrderCancelSheet(onConfirm: onConfirm),
    );
  }

  @override
  State<OrderCancelSheet> createState() => _OrderCancelSheetState();
}

class _OrderCancelSheetState extends State<OrderCancelSheet> {
  String? _selected;
  final TextEditingController _other = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    Get.find<OrderController>().getOrderCancelReasons();
    _other.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        decoration: const BoxDecoration(
          color: WaddyColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(Dimensions.radiusExtraLarge),
          ),
        ),
        child: SafeArea(
          top: false,
          child: GetBuilder<OrderController>(
            builder: (controller) {
              final reasons =
                  (controller.orderCancelReasons ?? [])
                      .map((r) => r.reason)
                      .whereType<String>()
                      .where((r) => r.trim().isNotEmpty)
                      .toList();
              final bool loaded = controller.orderCancelReasons != null;
              final bool freeText = loaded && reasons.isEmpty;
              final String? reason =
                  freeText
                      ? (_other.text.trim().isEmpty ? null : _other.text.trim())
                      : _selected;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: Dimensions.paddingSizeSmall),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: WaddyColors.divider,
                        borderRadius: BorderRadius.circular(
                          Dimensions.radiusExtraSmall,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Dimensions.paddingSizeDefault,
                      Dimensions.paddingSizeDefault,
                      Dimensions.paddingSizeDefault,
                      Dimensions.paddingSizeExtraSmall,
                    ),
                    child: Text('od_cancel_title'.tr, style: _titleStyle),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Dimensions.paddingSizeDefault,
                      0,
                      Dimensions.paddingSizeDefault,
                      Dimensions.paddingSizeSmall,
                    ),
                    child: Text('od_cancel_pick_reason'.tr, style: _metaStyle),
                  ),
                  Flexible(
                    child:
                        !loaded
                            ? const Padding(
                              padding: EdgeInsets.all(
                                Dimensions.paddingSizeExtraLarge,
                              ),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: WaddyColors.primary,
                                ),
                              ),
                            )
                            : freeText
                            ? Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Dimensions.paddingSizeDefault,
                              ),
                              child: TextField(
                                controller: _other,
                                maxLength: 255,
                                maxLines: 3,
                                minLines: 2,
                                decoration: InputDecoration(
                                  hintText: 'od_cancel_reason_hint'.tr,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      Dimensions.radiusDefault,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            : SingleChildScrollView(
                              child: RadioGroup<String>(
                                groupValue: _selected,
                                onChanged: (v) => setState(() => _selected = v),
                                child: Column(
                                  children: [
                                    for (final r in reasons)
                                      RadioListTile<String>(
                                        value: r,
                                        activeColor: WaddyColors.primary,
                                        title: Text(r, style: _copyStyle),
                                        dense: true,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Dimensions.paddingSizeDefault,
                      Dimensions.paddingSizeMedium,
                      Dimensions.paddingSizeDefault,
                      Dimensions.paddingSizeDefault,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _submitting ? null : () => Get.back(),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(
                                Dimensions.minTapTarget,
                              ),
                              foregroundColor: WaddyColors.primary,
                              side: const BorderSide(
                                color: WaddyColors.divider,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  Dimensions.radiusDefault,
                                ),
                              ),
                            ),
                            child: Text('od_keep_order'.tr),
                          ),
                        ),
                        const SizedBox(width: Dimensions.paddingSizeMedium),
                        Expanded(
                          child: FilledButton(
                            onPressed:
                                reason == null || _submitting
                                    ? null
                                    : () async {
                                      setState(() => _submitting = true);
                                      await widget.onConfirm(reason);
                                      if (mounted) {
                                        setState(() => _submitting = false);
                                      }
                                    },
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(
                                Dimensions.minTapTarget,
                              ),
                              backgroundColor: WaddyColors.coralDark,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  Dimensions.radiusDefault,
                                ),
                              ),
                            ),
                            child:
                                _submitting
                                    ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: WaddyColors.surface,
                                      ),
                                    )
                                    : Text('cancel_order'.tr),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
