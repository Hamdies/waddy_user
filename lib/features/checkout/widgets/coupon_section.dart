import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:waddy_app/common/widgets/confetti_burst.dart';
import 'package:waddy_app/common/widgets/custom_button.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:waddy_app/features/checkout/widgets/checkout_card.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/coupon/controllers/coupon_controller.dart';
import 'package:waddy_app/features/checkout/controllers/checkout_controller.dart';
import 'package:waddy_app/helper/date_converter.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';

/// "Don't miss out on our promo code" — a full-saturation mint card with a
/// white well holding the code field, or, once a code is in, what it saved.
///
/// Mint here is deliberate even though it is the press colour: the card is an
/// invitation to act, and the only pressable thing inside it is Apply. A good
/// code gets a burst of confetti; a bad one gets an inline error instead of a
/// snackbar, next to the field that needs fixing.
///
/// The apply/remove logic is the old section's, unchanged.
class CouponSection extends StatefulWidget {
  final int? storeId;
  final CheckoutController checkoutController;
  final double total;
  final double price;
  final double discount;
  final double addOns;
  final double deliveryCharge;
  final double variationPrice;

  /// Set when the card sits on the cart rather than checkout. The cart has no
  /// payment method yet, so the wallet/partial-pay rebalancing is skipped, and
  /// the store comes from the basket. On checkout it is checkout's own store;
  /// `StoreController.store` is the store PAGE, never the basket's (ST-02).
  final int? cartStoreId;

  /// What item discounts already take off, when the caller's [discount] does
  /// not carry it (the cart passes 0 there). Used only for the heading.
  final double? itemSavings;
  const CouponSection({
    super.key,
    this.storeId,
    required this.checkoutController,
    required this.total,
    required this.price,
    required this.discount,
    required this.addOns,
    required this.deliveryCharge,
    required this.variationPrice,
    this.cartStoreId,
    this.itemSavings,
  });

  @override
  State<CouponSection> createState() => _CouponSectionState();
}

class _CouponSectionState extends State<CouponSection> {
  bool _invalid = false;

  TextEditingController get _field =>
      widget.checkoutController.couponController;

  @override
  void initState() {
    super.initState();
    _field.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _field.removeListener(_onFieldChanged);
    super.dispose();
  }

  void _onFieldChanged() {
    // Rebuild for the Apply button's enabled state; clear a stale error.
    //
    // The field is CheckoutController's, shared by every card on screen — the
    // cart's card stays mounted under checkout, and checkout's initState
    // resets the text mid-build. A setState then throws, so defer it past
    // the frame whenever a build is in progress.
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _invalid = false);
      });
    } else {
      setState(() => _invalid = false);
    }
  }

  Future<void> _apply() async {
    final CheckoutController c = widget.checkoutController;
    final CouponController coupons = Get.find<CouponController>();
    final String code = _field.text.trim();
    if (code.isEmpty) {
      showCustomSnackBar('enter_a_coupon_code'.tr);
      return;
    }
    if (coupons.isLoading) return;
    FocusScope.of(context).unfocus();

    final double? discount = await coupons.applyCoupon(
      code,
      (widget.price - widget.discount) + widget.addOns + widget.variationPrice,
      widget.deliveryCharge,
      widget.cartStoreId ?? widget.checkoutController.store?.id,
    );
    if (!mounted) return;

    final bool applied = (discount ?? 0) > 0 || coupons.freeDelivery;
    if (!applied) {
      setState(() => _invalid = true);
      return;
    }
    ConfettiBurst.show(context);
    if (widget.cartStoreId != null) return;
    if ((discount ?? 0) > 0 && (c.isPartialPay || c.paymentMethodIndex == 1)) {
      c.checkBalanceStatus(widget.total - discount!, discount);
    }
  }

  void _remove() {
    final CheckoutController c = widget.checkoutController;
    final CouponController coupons = Get.find<CouponController>();
    final double totalPrice = widget.total + (coupons.discount ?? 0);
    coupons.removeCouponData(true);
    _field.text = '';
    if (widget.cartStoreId != null) return;
    if (c.isPartialPay || c.paymentMethodIndex == 1) {
      c.checkBalanceStatus(totalPrice, 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.storeId != null) return const SizedBox.shrink();

    return GetBuilder<CouponController>(
      builder: (coupons) {
        final bool applied =
            (coupons.discount ?? 0) > 0 || coupons.freeDelivery;

        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: WaddyColors.mint,
            borderRadius: BorderRadius.circular(Dimensions.radiusExtraLarge),
          ),
          child: Stack(
            children: [
              // A few still flecks of confetti — the card's resting state
              // hints at what applying a code does.
              ..._flecks(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      Dimensions.paddingSizeLarge,
                      Dimensions.paddingSizeDefault,
                      Dimensions.paddingSizeLarge * 4,
                      Dimensions.paddingSizeMedium,
                    ),
                    // With a saving already on the order, lead with the
                    // number: a code adds to it, it does not replace it.
                    child: Text(
                      _alreadySaved > 0 && !applied
                          ? 'amount_off_add_a_code_for_more'.trParams({
                            'amount': PriceConverter.convertPrice(
                              _alreadySaved,
                            ),
                          })
                          : 'dont_miss_out_on_our_promo_code'.tr,
                      style: waddyBold.copyWith(
                        fontSize: Dimensions.fontSizeDefault,
                        color: WaddyColors.primary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(
                      Dimensions.paddingSizeDefault,
                    ),
                    decoration: BoxDecoration(
                      color: WaddyColors.surface,
                      borderRadius: BorderRadius.circular(
                        Dimensions.radiusExtraLarge,
                      ),
                      border: Border.all(color: WaddyColors.mintSurfaceDeep),
                    ),
                    child: applied ? _appliedRow(coupons) : _entry(coupons),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  double get _alreadySaved => widget.itemSavings ?? widget.discount;

  Widget _entry(CouponController coupons) {
    final bool empty = _field.text.trim().isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsetsDirectional.only(
            start: Dimensions.paddingSizeDefault,
            end: Dimensions.paddingSizeExtraSmall,
          ),
          decoration: BoxDecoration(
            color: WaddyColors.surface,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: _invalid ? WaddyColors.coralInk : WaddyColors.divider,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              const CheckoutIcon(
                icon: HugeIcons.strokeRoundedTicket01,
                size: 20,
                color: WaddyColors.mintInk,
              ),
              const SizedBox(width: Dimensions.paddingSizeSmall),
              Expanded(
                child: TextField(
                  controller: _field,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _apply(),
                  style: waddyBold.copyWith(
                    fontSize: Dimensions.fontSizeSmall,
                    color: WaddyColors.ink,
                    letterSpacing: 0.6,
                  ),
                  decoration: InputDecoration(
                    hintText: 'enter_promo_code'.tr,
                    hintStyle: waddyMedium.copyWith(
                      fontSize: Dimensions.fontSizeSmall,
                      color: WaddyColors.inkMuted,
                    ),
                    isDense: true,
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(width: Dimensions.paddingSizeSmall),
              CustomButton(
                buttonText: 'apply'.tr,
                onPressed: empty ? null : _apply,
                isLoading: coupons.isLoading,
                width: 92,
                height: 42,
                radius: 100,
                fontSize: Dimensions.fontSizeExtraSmall,
                // The two-tone default is the page's CTA; inside the promo
                // well Apply is secondary, so it takes the dark teal fill.
                color: WaddyColors.primary,
                textColor: WaddyColors.surface,
                child:
                    coupons.isLoading
                        ? const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: WaddyColors.surface,
                            ),
                          ),
                        )
                        : null,
              ),
            ],
          ),
        ),
        if (_invalid)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: Dimensions.paddingSizeDefault,
              top: Dimensions.paddingSizeSmall,
            ),
            child: Text(
              _errorText(coupons),
              style: waddyMedium.copyWith(
                fontSize: Dimensions.fontSizeExtraSmall,
                color: WaddyColors.coralInk,
              ),
            ),
          ),
      ],
    );
  }

  /// A printed scratch card that fails says why in its own words: a generic
  /// "invalid code" makes a real card feel fake (SC-06).
  String _errorText(CouponController coupons) {
    switch (coupons.errorCode) {
      case 'card_already_used':
        return 'scratch_card_already_used'.tr;
      case 'card_expired':
        return 'scratch_card_expired'.tr;
      case 'card_not_active':
        return 'scratch_card_not_active'.tr;
      case 'card_limit':
        final DateTime? on = DateTime.tryParse(coupons.errorAvailableOn ?? '');
        return on == null
            ? 'scratch_card_limit'.tr
            : 'scratch_card_limit_until'.trParams({
              'date': DateConverter.dateToReadableDate(on),
            });
      case 'too_many_attempts':
        return 'promo_too_many_attempts'.tr;
      default:
        return 'invalid_promo_code'.tr;
    }
  }

  Widget _appliedRow(CouponController coupons) {
    final String code = coupons.coupon?.code ?? _field.text.trim();
    // The one place the app answers the paper card (SC-07).
    final bool fromCard = coupons.coupon?.scratchCard ?? false;
    final String title =
        !fromCard
            ? 'code_applied'.trParams({'code': code.toUpperCase()})
            : coupons.freeDelivery
            ? 'scratch_card_free_delivery_on'.tr
            : 'scratch_card_discount_on'.tr;
    final String saved =
        coupons.freeDelivery
            ? 'free_delivery'.tr
            : 'you_saved_amount'.trParams({
              'amount': PriceConverter.convertPrice(coupons.discount),
            });

    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsetsDirectional.fromSTEB(
        Dimensions.paddingSizeMedium,
        Dimensions.paddingSizeSmall,
        Dimensions.paddingSizeExtraSmall,
        Dimensions.paddingSizeSmall,
      ),
      decoration: BoxDecoration(
        color: WaddyColors.mintSurface,
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: WaddyColors.primary,
            ),
            child: const CheckoutIcon(
              icon: HugeIcons.strokeRoundedTick02,
              size: 18,
              color: WaddyColors.surface,
            ),
          ),
          const SizedBox(width: Dimensions.paddingSizeMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: waddyBold.copyWith(
                    fontSize: Dimensions.fontSizeSmall,
                    color: WaddyColors.primary,
                  ),
                ),
                Text(
                  saved,
                  style: waddyMedium.copyWith(
                    fontSize: Dimensions.fontSizeExtraSmall,
                    color: WaddyColors.mintInk,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _remove,
            style: TextButton.styleFrom(
              foregroundColor: WaddyColors.primary,
              minimumSize: const Size(
                Dimensions.minTapTarget,
                Dimensions.minTapTarget,
              ),
            ),
            child: Text(
              'remove'.tr,
              style: waddyBold.copyWith(
                fontSize: Dimensions.fontSizeExtraSmall,
                color: WaddyColors.primary,
                decoration: TextDecoration.underline,
                decorationColor: WaddyColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _flecks() {
    Widget fleck(
      double end,
      double top,
      double w,
      double h,
      double deg,
      Color color,
    ) {
      return PositionedDirectional(
        end: end,
        top: top,
        child: Transform.rotate(
          angle: deg * math.pi / 180,
          child: Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(
                Dimensions.radiusExtraSmall / 2,
              ),
            ),
          ),
        ),
      );
    }

    return [
      fleck(26, 10, 6, 10, 25, WaddyColors.primary.withValues(alpha: 0.18)),
      fleck(56, 30, 5, 8, -30, WaddyColors.primary.withValues(alpha: 0.14)),
      fleck(90, 18, 6, 4, 15, WaddyColors.surface.withValues(alpha: 0.6)),
    ];
  }
}
