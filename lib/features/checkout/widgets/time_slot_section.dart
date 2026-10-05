import 'package:flutter/material.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:waddy_app/features/checkout/widgets/checkout_card.dart';
import 'package:get/get.dart';
import 'package:just_the_tooltip/just_the_tooltip.dart';
import 'package:waddy_app/features/cart/domain/models/cart_model.dart';
import 'package:waddy_app/common/models/config_model.dart';
import 'package:waddy_app/features/checkout/controllers/checkout_controller.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/features/checkout/widgets/time_slot_bottom_sheet.dart';

class TimeSlotSection extends StatelessWidget {
  final int? storeId;
  final CheckoutController checkoutController;
  final List<CartModel?>? cartList;
  final JustTheController tooltipController2;
  final bool tomorrowClosed;
  final bool todayClosed;
  final Module? module;
  const TimeSlotSection({
    super.key,
    this.storeId,
    required this.checkoutController,
    this.cartList,
    required this.tooltipController2,
    required this.tomorrowClosed,
    required this.todayClosed,
    this.module,
  });

  @override
  Widget build(BuildContext context) {
    bool isGuestLoggedIn = false;
    return Column(
      children: [
        !isGuestLoggedIn &&
                storeId == null &&
                checkoutController.store!.scheduleOrder! &&
                cartList!.isNotEmpty &&
                cartList![0]!.item!.availableDateStarts == null
            ? Container(
              decoration: BoxDecoration(
                color: WaddyColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeLarge,
                vertical: Dimensions.paddingSizeSmall,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('preference_time'.tr, style: waddyMedium),
                      const SizedBox(width: Dimensions.paddingSizeExtraSmall),

                      JustTheTooltip(
                        backgroundColor: WaddyColors.ink,
                        controller: tooltipController2,
                        preferredDirection: AxisDirection.right,
                        tailLength: 14,
                        tailBaseWidth: 20,
                        content: Padding(
                          padding: const EdgeInsets.all(
                            Dimensions.paddingSizeSmall,
                          ),
                          child: Text(
                            'schedule_time_tool_tip'.tr,
                            style: waddyRegular.copyWith(
                              color: WaddyColors.surface,
                            ),
                          ),
                        ),
                        child: InkResponse(
                          onTap: () => tooltipController2.showTooltip(),
                          radius: 22,
                          // An 18pt glyph in a 44pt target.
                          child: const Padding(
                            padding: EdgeInsets.all(13),
                            child: CheckoutIcon(
                              icon: HugeIcons.strokeRoundedInformationCircle,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Dimensions.paddingSizeSmall),

                  InkWell(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder:
                            (con) => TimeSlotBottomSheet(
                              tomorrowClosed: tomorrowClosed,
                              todayClosed: todayClosed,
                              module: module,
                            ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: WaddyColors.primary,
                          width: 0.3,
                        ),
                        borderRadius: BorderRadius.circular(
                          Dimensions.radiusDefault,
                        ),
                      ),
                      height: 50,
                      child: Row(
                        children: [
                          const SizedBox(width: Dimensions.paddingSizeLarge),

                          Expanded(
                            child:
                                ((checkoutController.selectedDateSlot == 0 &&
                                            todayClosed) ||
                                        (checkoutController.selectedDateSlot ==
                                                1 &&
                                            tomorrowClosed))
                                    ? Center(
                                      child: Text(
                                        module!.showRestaurantText!
                                            ? 'restaurant_is_closed'.tr
                                            : 'store_is_closed'.tr,
                                      ),
                                    )
                                    : Text(
                                      checkoutController
                                              .preferableTime
                                              .isNotEmpty
                                          ? checkoutController.preferableTime
                                          : 'instance'.tr,
                                    ),
                          ),

                          const CheckoutIcon(
                            icon: HugeIcons.strokeRoundedArrowDown01,
                            size: 20,
                          ),
                          CheckoutIcon(
                            icon: HugeIcons.strokeRoundedClock01,
                            color: WaddyColors.primary,
                          ),
                          const SizedBox(
                            width: Dimensions.paddingSizeExtraSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Dimensions.paddingSizeLarge),
                ],
              ),
            )
            : const SizedBox(),

        SizedBox(
          height:
              !isGuestLoggedIn &&
                      storeId == null &&
                      checkoutController.store!.scheduleOrder! &&
                      cartList!.isNotEmpty &&
                      cartList![0]!.item!.availableDateStarts == null
                  ? Dimensions.paddingSizeSmall
                  : 0,
        ),
      ],
    );
  }
}
