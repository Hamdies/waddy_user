import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/mccoin_mood.dart';
import 'package:waddy_app/features/checkout/widgets/checkout_card.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';
import 'package:waddy_app/features/checkout/controllers/checkout_controller.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/common/widgets/custom_text_field.dart';

class DeliveryManTipsSection extends StatefulWidget {
  final bool takeAway;
  final double totalPrice;
  final Function(double x) onTotalChange;
  final int? storeId;
  const DeliveryManTipsSection({
    super.key,
    required this.takeAway,
    required this.totalPrice,
    required this.onTotalChange,
    this.storeId,
  });

  @override
  State<DeliveryManTipsSection> createState() => _DeliveryManTipsSectionState();
}

class _DeliveryManTipsSectionState extends State<DeliveryManTipsSection> {
  bool canCheckSmall = false;

  int get _customIndex => AppConstants.tips.length - 1;

  @override
  Widget build(BuildContext context) {
    if (widget.takeAway ||
        Get.find<SplashController>().configModel.dmTipsStatus != 1) {
      return const SizedBox.shrink();
    }

    return GetBuilder<CheckoutController>(
      builder: (checkoutController) {
        // Index 0 is "not now" and the last is "custom"; the chips show the
        // amounts in between, sorted, and "not now" is reached by tapping the
        // selected chip again.
        final List<int> amountIndexes = [
          for (int i = 1; i < _customIndex; i++) i,
        ]..sort(
          (a, b) => double.parse(
            AppConstants.tips[a],
          ).compareTo(double.parse(AppConstants.tips[b])),
        );
        final bool isCustom = checkoutController.selectedTips == _customIndex;
        // A tip the user saved on an earlier order ("Save for later") comes
        // back preselected. Say so, so the amount reads as their own choice
        // carried over rather than a default the app picked.
        final String savedIndex = checkoutController.getSharedPrefDmTipIndex();
        final bool isUsualTip =
            checkoutController.selectedTips > 0 &&
            savedIndex == checkoutController.selectedTips.toString();

        return CheckoutCard(
          padding: const EdgeInsetsDirectional.fromSTEB(
            Dimensions.paddingSizeDefault,
            Dimensions.paddingSizeLarge,
            0,
            Dimensions.paddingSizeDefault,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  end: Dimensions.paddingSizeDefault,
                ),
                child: Row(
                  children: [
                    // McCoin reacts to the tip: a new mood is a new
                    // artboard, so the key forces a fresh load and the
                    // switcher cross-fades over it.
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: McCoinMoodAnimation(
                        key: ValueKey(_mood(checkoutController)),
                        mood: _mood(checkoutController),
                        size: 48,
                      ),
                    ),
                    const SizedBox(width: Dimensions.paddingSizeMedium),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'say_thanks_with_a_tip'.tr,
                            style: waddyBold.copyWith(
                              fontSize: Dimensions.fontSizeDefault,
                              color: WaddyColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isUsualTip
                                ? 'your_usual_tip_tap_to_change'.tr
                                : 'it_s_a_great_way_to_show_your_appreciation_for_their_hard_work'
                                    .tr,
                            style: waddyRegular.copyWith(
                              fontSize: Dimensions.fontSizeExtraSmall,
                              color:
                                  isUsualTip
                                      ? WaddyColors.mintInk
                                      : WaddyColors.inkLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Dimensions.paddingSizeDefault),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsetsDirectional.only(
                  end: Dimensions.paddingSizeDefault,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int rank = 0; rank < amountIndexes.length; rank++)
                      _TipChip(
                        label: PriceConverter.convertPrice(
                          double.parse(AppConstants.tips[amountIndexes[rank]]),
                          forDM: true,
                        ),
                        selected:
                            checkoutController.selectedTips ==
                            amountIndexes[rank],
                        mostTipped:
                            AppConstants.tips[amountIndexes[rank]] ==
                            checkoutController.mostDmTipAmount.toString(),
                        onTap:
                            () => _onTipTap(
                              checkoutController,
                              checkoutController.selectedTips ==
                                      amountIndexes[rank]
                                  ? 0
                                  : amountIndexes[rank],
                            ),
                      ),
                    _TipChip(
                      label: AppConstants.tips[_customIndex].tr,
                      selected: isCustom,
                      mostTipped: false,
                      onTap:
                          () => _onTipTap(
                            checkoutController,
                            isCustom ? 0 : _customIndex,
                          ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsetsDirectional.only(
                  end: Dimensions.paddingSizeDefault,
                  top: Dimensions.paddingSizeMedium,
                ),
                child:
                    isCustom
                        ? CustomTextField(
                          titleText: 'enter_amount'.tr,
                          controller: checkoutController.tipController,
                          inputAction: TextInputAction.done,
                          inputType: TextInputType.number,
                          onChanged:
                              (value) =>
                                  _onCustomChanged(checkoutController, value),
                        )
                        : CheckoutCheckRow(
                          value: checkoutController.isDmTipSave,
                          onTap: checkoutController.toggleDmTipSave,
                          label: 'save_for_later'.tr,
                        ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// No tip → sad, then hi, happy, and cool for the top amount or a custom
  /// one. Keyed off the tip amount, not the index, so reordering
  /// [AppConstants.tips] cannot scramble the faces.
  McCoinMood _mood(CheckoutController checkoutController) {
    final int index = checkoutController.selectedTips;
    if (index == _customIndex) return McCoinMood.cool;
    if (index <= 0 || index >= AppConstants.tips.length) return McCoinMood.sad;
    switch (AppConstants.tips[index]) {
      case '10':
        return McCoinMood.hi;
      case '15':
        return McCoinMood.happy;
      case '20':
        return McCoinMood.cool;
      default:
        return McCoinMood.sad;
    }
  }

  void _onTipTap(CheckoutController checkoutController, int index) {
    double total = widget.totalPrice - checkoutController.tips;
    checkoutController.updateTips(index);
    if (index != _customIndex) {
      checkoutController.addTips(double.parse(AppConstants.tips[index]));
    }
    checkoutController.tipController.text = checkoutController.tips.toString();

    if (checkoutController.isPartialPay ||
        checkoutController.paymentMethodIndex == 1) {
      checkoutController.checkBalanceStatus(
        (total + checkoutController.tips),
        0,
      );
    }
  }

  Future<void> _onCustomChanged(
    CheckoutController checkoutController,
    String value,
  ) async {
    double total = widget.totalPrice;
    if (value.isEmpty) {
      checkoutController.addTips(0.0);
      return;
    }
    try {
      if (double.parse(value) >= 0) {
        if (AuthHelper.isLoggedIn()) {
          total = total - checkoutController.tips;
          await checkoutController.addTips(double.parse(value));
          total = total + checkoutController.tips;
          widget.onTotalChange(total);
          final double walletBalance =
              Get.find<ProfileController>().userInfoModel!.walletBalance!;
          if (walletBalance < total &&
              checkoutController.paymentMethodIndex == 1) {
            checkoutController.checkBalanceStatus(total, 0);
            canCheckSmall = true;
          } else if (walletBalance > total &&
              canCheckSmall &&
              checkoutController.isPartialPay) {
            checkoutController.checkBalanceStatus(total, 0);
          }
        } else {
          checkoutController.addTips(double.parse(value));
        }
      } else {
        showCustomSnackBar('tips_can_not_be_negative'.tr);
      }
    } catch (e) {
      showCustomSnackBar('invalid_input'.tr);
      checkoutController.addTips(0.0);
      final String text = checkoutController.tipController.text;
      checkoutController.tipController.text = text.substring(
        0,
        text.length - 1,
      );
      checkoutController.tipController.selection = TextSelection.collapsed(
        offset: checkoutController.tipController.text.length,
      );
    }
  }
}

class _TipChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool mostTipped;
  final VoidCallback onTap;
  const _TipChip({
    required this.label,
    required this.selected,
    required this.mostTipped,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        end: Dimensions.paddingSizeSmall,
      ),
      child: Column(
        children: [
          Semantics(
            button: true,
            selected: selected,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(100),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 44,
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeMedium,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color:
                      selected ? WaddyColors.mintSurface : WaddyColors.surface,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: selected ? WaddyColors.primary : WaddyColors.divider,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  label,
                  textDirection: TextDirection.ltr,
                  style: waddyBold.copyWith(
                    fontSize: Dimensions.fontSizeExtraSmall,
                    color: WaddyColors.ink,
                  ),
                ),
              ),
            ),
          ),
          if (mostTipped)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'most_tipped'.tr,
                style: waddyMedium.copyWith(
                  fontSize: Dimensions.fontSizeOverSmall,
                  color: WaddyColors.mintInk,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
