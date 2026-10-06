import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/checkout/widgets/checkout_card.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/features/xp/domain/models/checkout_prize_model.dart';
import 'package:waddy_app/features/xp/domain/models/prize_kind.dart';
import 'package:waddy_app/features/xp/widgets/prize_visual.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

/// The XP prizes the user can spend on this order, in checkout's own idiom:
/// the flat hairline card and radio rows of "Pay with", with the picked prize
/// lit in mint. Sits right under the promo code field.
class PrizeSelectionWidget extends StatelessWidget {
  final double orderAmount;

  const PrizeSelectionWidget({super.key, required this.orderAmount});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<XpController>(
      id: XpController.idCheckoutPrizes,
      builder: (xp) {
        if (xp.checkoutPrizes.isEmpty && !xp.isCheckoutPrizesLoading) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(top: Dimensions.paddingSizeMedium),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: WaddyColors.surface,
              borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
              border: Border.all(color: WaddyColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(xp),
                if (xp.isCheckoutPrizesLoading)
                  const Padding(
                    padding: EdgeInsets.all(Dimensions.paddingSizeDefault),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: WaddyColors.primary,
                        ),
                      ),
                    ),
                  )
                else
                  for (int i = 0; i < xp.checkoutPrizes.length; i++)
                    _row(
                      xp,
                      xp.checkoutPrizes[i],
                      last: i == xp.checkoutPrizes.length - 1,
                    ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _header(XpController xp) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
        vertical: Dimensions.paddingSizeMedium,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: WaddyColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'apply_xp_prize'.tr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: waddyBold.copyWith(
                fontSize: Dimensions.fontSizeDefault,
                color: WaddyColors.ink,
              ),
            ),
          ),
          if (!xp.isCheckoutPrizesLoading)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeSmall,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: WaddyColors.mintSurface,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                '${xp.checkoutPrizes.length}',
                style: waddyBold.copyWith(
                  fontSize: Dimensions.fontSizeExtraSmall,
                  color: WaddyColors.mintInk,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(XpController xp, CheckoutPrize prize, {required bool last}) {
    final bool selected = xp.selectedCheckoutPrize?.id == prize.id;
    final String expiry = _formatExpiry(prize);

    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: InkWell(
        onTap:
            () =>
                selected
                    ? xp.clearSelectedCheckoutPrize()
                    : xp.selectCheckoutPrize(prize),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeDefault,
            vertical: Dimensions.paddingSizeMedium,
          ),
          decoration: BoxDecoration(
            color: selected ? WaddyColors.mintSurface : WaddyColors.surface,
            border:
                last
                    ? null
                    : const Border(
                      bottom: BorderSide(color: WaddyColors.divider),
                    ),
          ),
          child: Row(
            children: [
              _buildPrizeIcon(prize),
              const SizedBox(width: Dimensions.paddingSizeMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prize.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: waddyBold.copyWith(
                        fontSize: Dimensions.fontSizeSmall,
                        color: WaddyColors.ink,
                      ),
                    ),
                    if (expiry.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          expiry,
                          style: waddyMedium.copyWith(
                            fontSize: Dimensions.fontSizeExtraSmall,
                            color: _getExpiryColor(prize),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (prize.isFreeDelivery) ...[
                const SizedBox(width: Dimensions.paddingSizeSmall),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Dimensions.paddingSizeSmall,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color:
                        selected
                            ? WaddyColors.surface
                            : WaddyColors.mintSurface,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    'free_delivery'.tr,
                    style: waddyBold.copyWith(
                      fontSize: Dimensions.fontSizeExtraSmall,
                      color: WaddyColors.mintInk,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: Dimensions.paddingSizeMedium),
              CheckoutRadio(selected: selected),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrizeIcon(CheckoutPrize prize) {
    // The glyph is the XP surfaces' (X-38); the colour stays checkout's.
    final Color color = switch (prize.kind) {
      PrizeKind.freeDelivery => WaddyColors.success,
      PrizeKind.discount => WaddyColors.amberInk,
      PrizeKind.walletCredit => WaddyColors.mintInk,
      PrizeKind.badge || PrizeKind.other => WaddyColors.primary,
    };

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      ),
      child: Icon(prize.kind.icon, size: 20, color: color),
    );
  }

  String _formatExpiry(CheckoutPrize prize) {
    if (prize.timeUntilExpiry == null) return '';

    final duration = prize.timeUntilExpiry!;
    if (duration.inDays > 0) {
      return '${'expires_in'.tr} ${duration.inDays} ${'days'.tr}';
    } else if (duration.inHours > 0) {
      return '${'expires_in'.tr} ${duration.inHours} ${'hours'.tr}';
    } else {
      return 'expires_soon'.tr;
    }
  }

  Color _getExpiryColor(CheckoutPrize prize) {
    if (prize.timeUntilExpiry == null) return WaddyColors.inkLight;

    final duration = prize.timeUntilExpiry!;
    if (duration.inDays < 1) {
      return WaddyColors.coralInk;
    } else if (duration.inDays < 3) {
      return WaddyColors.amberInk;
    }
    return WaddyColors.inkLight;
  }
}

/// Keeps the XP prize list in step with the cart's current value.
///
/// Eligibility depends on the order amount, so this re-syncs whenever the
/// amount changes rather than fetching once — see `syncCheckoutPrizes`. The
/// trigger lives in lifecycle callbacks and not in a builder: firing a fetch
/// from inside `build` is what the controller's `Future.microtask(update)`
/// workarounds existed to tolerate.
class CheckoutPrizeSection extends StatefulWidget {
  const CheckoutPrizeSection({super.key, required this.orderAmount});

  final double orderAmount;

  @override
  State<CheckoutPrizeSection> createState() => _CheckoutPrizeSectionState();
}

class _CheckoutPrizeSectionState extends State<CheckoutPrizeSection> {
  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(CheckoutPrizeSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderAmount != widget.orderAmount) _sync();
  }

  void _sync() {
    final amount = widget.orderAmount;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Get.find<XpController>().syncCheckoutPrizes(amount);
    });
  }

  @override
  Widget build(BuildContext context) =>
      PrizeSelectionWidget(orderAmount: widget.orderAmount);
}
