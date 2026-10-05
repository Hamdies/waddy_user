import 'package:flutter/material.dart';
import 'package:waddy_app/features/store/domain/store_rules.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/common/models/config_model.dart';
import 'package:waddy_app/features/checkout/controllers/checkout_controller.dart';
import 'package:waddy_app/helper/date_converter.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_button.dart';
import 'package:waddy_app/features/checkout/widgets/slot_widget.dart';

class TimeSlotBottomSheet extends StatefulWidget {
  final bool tomorrowClosed;
  final bool todayClosed;
  final Module? module;
  const TimeSlotBottomSheet({
    super.key,
    required this.tomorrowClosed,
    required this.todayClosed,
    required this.module,
  });

  @override
  State<TimeSlotBottomSheet> createState() => _TimeSlotBottomSheetState();
}

class _TimeSlotBottomSheetState extends State<TimeSlotBottomSheet> {
  int selectedTimeSlotIndex = 0;
  String selectedTimeSlot = '';

  @override
  void initState() {
    super.initState();
    selectedTimeSlotIndex = Get.find<CheckoutController>().selectedTimeSlot;
    selectedTimeSlot = Get.find<CheckoutController>().preferableTime;
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CheckoutController>(
      builder: (checkoutController) {
        return Builder(
          builder: (context) {
            return Container(
              width: context.width,
              constraints: BoxConstraints(
                maxHeight: context.height * 0.8,
                minHeight: 0,
              ),
              margin: const EdgeInsets.only(top: 30),
              decoration: BoxDecoration(
                color: WaddyColors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(Dimensions.radiusExtraLarge),
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => Get.back(),
                      child: Container(
                        height: 4,
                        width: 35,
                        margin: const EdgeInsets.symmetric(
                          vertical: Dimensions.paddingSizeExtraSmall,
                        ),
                        decoration: BoxDecoration(
                          color: WaddyColors.inkMuted,
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusDefault,
                          ),
                        ),
                      ),
                    ),

                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Dimensions.paddingSizeLarge,
                          vertical: Dimensions.paddingSizeLarge,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: tabView(
                                    context: context,
                                    title: 'today'.tr,
                                    isSelected:
                                        checkoutController.selectedDateSlot ==
                                        0,
                                    onTap: () {
                                      checkoutController.updateDateSlot(
                                        0,
                                        checkoutController
                                            .store!
                                            .orderPlaceToScheduleInterval,
                                      );
                                    },
                                  ),
                                ),

                                Expanded(
                                  child: tabView(
                                    context: context,
                                    title: 'tomorrow'.tr,
                                    isSelected:
                                        checkoutController.selectedDateSlot ==
                                        1,
                                    onTap: () {
                                      checkoutController.updateDateSlot(
                                        1,
                                        checkoutController
                                            .store!
                                            .orderPlaceToScheduleInterval,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: Dimensions.paddingSizeSmall),

                            Flexible(
                              child:
                                  ((checkoutController.selectedDateSlot == 0 &&
                                              widget.todayClosed) ||
                                          (checkoutController
                                                      .selectedDateSlot ==
                                                  1 &&
                                              widget.tomorrowClosed))
                                      ? Center(
                                        child: Text(
                                          widget.module!.showRestaurantText!
                                              ? 'restaurant_is_closed'.tr
                                              : 'store_is_closed'.tr,
                                        ),
                                      )
                                      : checkoutController.timeSlots != null
                                      ? checkoutController.timeSlots!.isNotEmpty
                                          ? GridView.builder(
                                            gridDelegate:
                                                const SliverGridDelegateWithFixedCrossAxisCount(
                                                  crossAxisCount: 3,
                                                  mainAxisSpacing:
                                                      Dimensions
                                                          .paddingSizeSmall,
                                                  crossAxisSpacing:
                                                      Dimensions
                                                          .paddingSizeExtraSmall,
                                                  childAspectRatio: 2.5,
                                                ),
                                            shrinkWrap: true,
                                            padding: const EdgeInsets.only(
                                              left: 2,
                                            ),
                                            physics:
                                                const AlwaysScrollableScrollPhysics(),
                                            itemCount:
                                                checkoutController
                                                    .timeSlots!
                                                    .length,
                                            itemBuilder: (context, index) {
                                              String time =
                                                  (index == 0 &&
                                                          checkoutController
                                                                  .selectedDateSlot ==
                                                              0 &&
                                                          checkoutController
                                                              .store!
                                                              .isOpenBySchedule() &&
                                                          (Get.find<
                                                                    SplashController
                                                                  >()
                                                                  .configModel
                                                                  .moduleConfig!
                                                                  .module!
                                                                  .orderPlaceToScheduleInterval!
                                                              ? checkoutController
                                                                      .store!
                                                                      .orderPlaceToScheduleInterval ==
                                                                  0
                                                              : true))
                                                      ? 'instance'.tr
                                                      : '${DateConverter.dateToTimeOnly(checkoutController.timeSlots![index].startTime!)} '
                                                          '- ${DateConverter.dateToTimeOnly(checkoutController.timeSlots![index].endTime!)}';
                                              return SlotWidget(
                                                title: time,
                                                isSelected:
                                                    selectedTimeSlotIndex ==
                                                    index,
                                                onTap: () {
                                                  setState(() {
                                                    selectedTimeSlotIndex =
                                                        index;
                                                    selectedTimeSlot = time;
                                                  });
                                                },
                                              );
                                            },
                                          )
                                          : Center(
                                            child: Text('no_slot_available'.tr),
                                          )
                                      : const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Dimensions.paddingSizeExtraLarge,
                        vertical: Dimensions.paddingSizeSmall,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: CustomButton(
                              radius: Dimensions.radiusDefault,
                              height: null,
                              isBold: true,
                              buttonText: 'cancel'.tr,
                              color: WaddyColors.inkMuted,
                              onPressed: () => Get.back(),
                            ),
                          ),
                          const SizedBox(width: Dimensions.paddingSizeSmall),

                          Expanded(
                            child: CustomButton(
                              radius: Dimensions.radiusDefault,
                              height: null,
                              isBold: true,
                              buttonText: 'schedule'.tr,
                              onPressed: () {
                                checkoutController.updateTimeSlot(
                                  selectedTimeSlotIndex,
                                );
                                checkoutController.setPreferenceTimeForView(
                                  selectedTimeSlot,
                                );

                                DateTime scheduleEndDate = DateTime.now();

                                DateTime date =
                                    checkoutController.selectedDateSlot == 0
                                        ? DateTime.now()
                                        : DateTime.now().add(
                                          const Duration(days: 1),
                                        );
                                DateTime endTime =
                                    checkoutController
                                        .timeSlots![checkoutController
                                            .selectedTimeSlot]
                                        .endTime!;
                                scheduleEndDate = DateTime(
                                  date.year,
                                  date.month,
                                  date.day,
                                  endTime.hour,
                                  endTime.minute + 1,
                                );

                                checkoutController.getSurgePrice(
                                  zoneId:
                                      checkoutController.store!.zoneId
                                          .toString(),
                                  moduleId:
                                      checkoutController.store!.moduleId
                                          .toString(),
                                  dateTime: DateConverter.dateToDateAndTime(
                                    scheduleEndDate,
                                  ),
                                  guestId: '',
                                );
                                Get.back();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget tabView({
    required BuildContext context,
    required String title,
    required bool isSelected,
    required Function() onTap,
  }) {
    final Color primaryColor = WaddyColors.primary;
    final Color accentColor = WaddyColors.mint;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(
          horizontal: Dimensions.paddingSizeExtraSmall,
        ),
        padding: const EdgeInsets.symmetric(
          vertical: Dimensions.paddingSizeSmall,
        ),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
          border: Border.all(
            color:
                isSelected
                    ? accentColor
                    : WaddyColors.inkMuted.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: Text(
            title,
            style:
                isSelected
                    ? waddyBold.copyWith(
                      color: WaddyColors.surface,
                      fontSize: 14,
                    )
                    : waddyMedium.copyWith(
                      color: WaddyColors.ink,
                      fontSize: 14,
                    ),
          ),
        ),
      ),
    );
  }
}
