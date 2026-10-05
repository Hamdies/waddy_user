import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/features/checkout/controllers/checkout_controller.dart';
import 'package:waddy_app/features/checkout/widgets/checkout_card.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

/// Every payment method the order can use, listed inline as radio rows.
///
/// This replaced a single "Payment method ▾" pill that opened
/// PaymentMethodBottomSheet. The choice is the last thing standing between
/// the customer and the order, so it is on the page, not behind a tap. The
/// sheet still exists — the place-order handler falls back to it if nothing
/// is selected — and the availability rules here are the sheet's, including
/// partial payment.
class PaymentSection extends StatelessWidget {
  final int? storeId;
  final bool isCashOnDeliveryActive;
  final bool isDigitalPaymentActive;
  final bool isWalletActive;
  final double total;
  final CheckoutController checkoutController;
  final bool isOfflinePaymentActive;
  const PaymentSection({
    super.key,
    this.storeId,
    required this.isCashOnDeliveryActive,
    required this.isDigitalPaymentActive,
    required this.isWalletActive,
    required this.total,
    required this.checkoutController,
    required this.isOfflinePaymentActive,
  });

  @override
  Widget build(BuildContext context) {
    final config = Get.find<SplashController>().configModel;
    final CheckoutController c = checkoutController;

    // Prescription orders are cash only; the screen pins the method to 0.
    if (storeId != null) {
      return CheckoutCard(
        padding: const EdgeInsets.symmetric(
          horizontal: Dimensions.paddingSizeDefault,
        ),
        child: _MethodRow(
          leading: const _GlyphIcon(HugeIcons.strokeRoundedMoney03),
          title: 'cash_on_delivery'.tr,
          selected: true,
          showDivider: false,
          showRadio: false,
          onTap: null,
        ),
      );
    }

    // Partial payment narrows what can cover the remainder — the sheet's
    // `configurePartialPayment`, verbatim in effect.
    bool showCod = true;
    bool showDigital = true;
    if (c.isPartialPay) {
      showCod = config.partialPaymentMethod != 'digital_payment';
      showDigital = config.partialPaymentMethod != 'cod';
    }

    final double walletBalance =
        Get.find<ProfileController>().userInfoModel?.walletBalance ?? 0;
    final bool showWallet =
        isWalletActive &&
        (config.partialPaymentStatus ?? false) &&
        walletBalance > 0 &&
        c.distance != -1;
    final bool walletApplied = c.paymentMethodIndex == 1 || c.isPartialPay;

    final List<Widget> rows = [];

    if (isCashOnDeliveryActive && showCod) {
      rows.add(
        _MethodRow(
          leading: const _GlyphIcon(HugeIcons.strokeRoundedMoney03),
          title: 'cash_on_delivery'.tr,
          selected: c.paymentMethodIndex == 0,
          onTap: () {
            c.setPaymentMethod(0);
            c.rememberPaymentMethod(0);
          },
        ),
      );
    }

    if (isDigitalPaymentActive && showDigital) {
      for (final method in config.activePaymentMethodList ?? []) {
        rows.add(
          _MethodRow(
            leading:
                method.getWayImageFullUrl != null
                    ? CustomImage(
                      image: method.getWayImageFullUrl!,
                      height: 20,
                      width: 28,
                      fit: BoxFit.contain,
                    )
                    : const _GlyphIcon(HugeIcons.strokeRoundedCreditCard),
            title: method.getWayTitle ?? method.getWay ?? '',
            selected:
                c.paymentMethodIndex == 2 &&
                c.digitalPaymentName == method.getWay,
            onTap: () {
              c.setPaymentMethod(2);
              c.changeDigitalPaymentName(method.getWay!);
              c.rememberPaymentMethod(2, gateway: method.getWay);
            },
          ),
        );
      }
    }

    if (isOfflinePaymentActive) {
      rows.add(
        _MethodRow(
          leading: const _GlyphIcon(HugeIcons.strokeRoundedBank),
          title: 'offline_payment'.tr,
          selected: c.paymentMethodIndex == 3,
          onTap: () {
            c.setPaymentMethod(3);
            c.rememberPaymentMethod(3);
          },
        ),
      );
    }

    if (rows.isEmpty && !showWallet) return const SizedBox.shrink();

    // Cash is the only way to pay: say so plainly. A lone radio button
    // implied other methods hidden somewhere, and sent people hunting for an
    // online option that does not exist yet.
    final bool cashOnly =
        rows.length == 1 &&
        !showWallet &&
        isCashOnDeliveryActive &&
        showCod &&
        !(isDigitalPaymentActive && showDigital) &&
        !isOfflinePaymentActive;
    if (cashOnly) {
      if (c.paymentMethodIndex != 0) {
        // Nothing to choose, so nothing for the user to forget to choose.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (c.paymentMethodIndex != 0) c.setPaymentMethod(0);
        });
      }
      rows
        ..clear()
        ..add(
          _MethodRow(
            leading: const _GlyphIcon(HugeIcons.strokeRoundedMoney03),
            title: 'cash_on_delivery'.tr,
            subtitle: 'online_payment_coming_soon'.tr,
            selected: true,
            showRadio: false,
            onTap: null,
          ),
        );
    }

    // The last row carries no divider.
    if (rows.isNotEmpty) {
      final _MethodRow last = rows.removeLast() as _MethodRow;
      rows.add(last.withoutDivider());
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: WaddyColors.surface,
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        border: Border.all(color: WaddyColors.divider),
      ),
      child: Column(
        children: [
          // Balance is not one method among many — it stacks with them
          // (partial pay), so it is a switch on top, not a radio row.
          if (showWallet)
            _BalanceToggle(
              balance: walletBalance,
              on: walletApplied,
              needsSecondMethod: c.isPartialPay && c.paymentMethodIndex == 1,
              showDivider: rows.isNotEmpty,
              onTap: () => _toggleWallet(c, walletBalance),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeDefault,
            ),
            child: Column(children: rows),
          ),
        ],
      ),
    );
  }

  /// PaymentMethodBottomSheet's wallet "Apply" / "✕" toggle.
  void _toggleWallet(CheckoutController c, double walletBalance) {
    final bool walletApplied = c.paymentMethodIndex == 1 || c.isPartialPay;
    if (walletApplied) {
      c.setPaymentMethod(-1);
      if (c.isPartialPay) c.changePartialPayment();
    } else {
      if (c.isPartialPay) c.changePartialPayment();
      c.setPaymentMethod(1);
      if (walletBalance < total) c.changePartialPayment();
    }
  }
}

class _MethodRow extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final Color subtitleColor;
  final bool selected;
  final bool showDivider;

  /// False when this is the only method: a lone radio implies a choice.
  final bool showRadio;
  final VoidCallback? onTap;
  const _MethodRow({
    required this.leading,
    required this.title,
    this.subtitle,
    this.subtitleColor = WaddyColors.inkLight,
    required this.selected,
    this.showDivider = true,
    this.showRadio = true,
    required this.onTap,
  });

  _MethodRow withoutDivider() => _MethodRow(
    leading: leading,
    title: title,
    subtitle: subtitle,
    subtitleColor: subtitleColor,
    selected: selected,
    showDivider: false,
    showRadio: showRadio,
    onTap: onTap,
  );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: showRadio,
      checked: showRadio ? selected : null,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical:
                subtitle != null
                    ? Dimensions.paddingSizeMedium
                    : Dimensions.paddingSizeDefault,
          ),
          decoration: BoxDecoration(
            border:
                showDivider
                    ? const Border(
                      bottom: BorderSide(color: WaddyColors.divider),
                    )
                    : null,
          ),
          child: Row(
            children: [
              SizedBox(width: 28, child: Center(child: leading)),
              const SizedBox(width: Dimensions.paddingSizeMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: waddyMedium.copyWith(
                        fontSize: Dimensions.fontSizeSmall,
                        color: WaddyColors.ink,
                      ),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle!,
                          style: waddyBold.copyWith(
                            fontSize: Dimensions.fontSizeExtraSmall,
                            color: subtitleColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (showRadio) ...[
                const SizedBox(width: Dimensions.paddingSizeSmall),
                CheckoutRadio(selected: selected),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GlyphIcon extends StatelessWidget {
  final List<List<dynamic>> icon;
  const _GlyphIcon(this.icon);

  @override
  Widget build(BuildContext context) =>
      CheckoutIcon(icon: icon, size: 20, color: WaddyColors.ink);
}

class _BalanceToggle extends StatelessWidget {
  final double balance;
  final bool on;
  final bool needsSecondMethod;
  final bool showDivider;
  final VoidCallback onTap;
  const _BalanceToggle({
    required this.balance,
    required this.on,
    required this.needsSecondMethod,
    required this.showDivider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: on,
      button: true,
      child: Material(
        color: WaddyColors.mintSurface,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeDefault,
              vertical: Dimensions.paddingSizeMedium,
            ),
            decoration: BoxDecoration(
              border:
                  showDivider
                      ? const Border(
                        bottom: BorderSide(color: WaddyColors.mintSurfaceDeep),
                      )
                      : null,
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 28,
                  child: Center(
                    child: CheckoutIcon(
                      icon: HugeIcons.strokeRoundedWallet01,
                      size: 22,
                      color: WaddyColors.mintInk,
                    ),
                  ),
                ),
                const SizedBox(width: Dimensions.paddingSizeMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'use_my_balance'.tr,
                        style: waddyBold.copyWith(
                          fontSize: Dimensions.fontSizeSmall,
                          color: WaddyColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        needsSecondMethod
                            ? 'please_select_a_option_to_pay_remain_billing_amount'
                                .tr
                            : 'available_amount'.trParams({
                              'amount': PriceConverter.convertPrice(balance),
                            }),
                        style: waddyBold.copyWith(
                          fontSize: Dimensions.fontSizeExtraSmall,
                          color:
                              needsSecondMethod
                                  ? WaddyColors.coralInk
                                  : WaddyColors.mintInk,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Dimensions.paddingSizeSmall),
                // Drawn rather than a Material Switch: the design's track is
                // teal when on and a flat grey when off, with no thumb icon.
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 46,
                  height: 26,
                  padding: const EdgeInsets.all(3),
                  alignment:
                      on
                          ? AlignmentDirectional.centerEnd
                          : AlignmentDirectional.centerStart,
                  decoration: BoxDecoration(
                    color: on ? WaddyColors.primary : WaddyColors.inkMuted,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: WaddyColors.surface,
                      boxShadow: [
                        BoxShadow(color: WaddyColors.shadowDeep, blurRadius: 2),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
