import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/checkout/controllers/checkout_controller.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

class WebDeliveryInstructionView extends StatefulWidget {
  const WebDeliveryInstructionView({super.key});

  @override
  State<WebDeliveryInstructionView> createState() => _WebDeliveryInstructionViewState();
}

class _WebDeliveryInstructionViewState extends State<WebDeliveryInstructionView> {

  static const List<IconData> _instructionIcons = [
    Icons.phone_disabled_rounded,
    Icons.notifications_off_rounded,
    Icons.door_front_door_rounded,
    Icons.security_rounded,
    Icons.home_rounded,
    Icons.desk_rounded,
  ];

  @override
  Widget build(BuildContext context) {

    return Padding (
      padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeLarge),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
          border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.20)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeLarge, vertical: Dimensions.paddingSizeExtraSmall),
        child: GetBuilder<CheckoutController>(
            builder: (checkoutController) {
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('add_delivery_instructions'.tr, style: robotoMedium),
                    IconButton(
                      padding: const EdgeInsets.all(0),
                      onPressed: (){
                        checkoutController.toggleExpand();
                      },
                      icon: Icon(checkoutController.isExpand ?  Icons.keyboard_arrow_up : Icons.keyboard_arrow_down)
                    )
                  ],
                ),

                !checkoutController.isExpand ? const SizedBox() :
                GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisSpacing: Dimensions.paddingSizeSmall,
                    mainAxisSpacing: Dimensions.paddingSizeSmall,
                    childAspectRatio: 3.5,
                    crossAxisCount: 3,
                  ),
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: AppConstants.deliveryInstructionList.length,
                  itemBuilder: (context, index) {
                    bool isSelected = checkoutController.selectedInstructions.contains(index);
                    final IconData icon = index < _instructionIcons.length
                        ? _instructionIcons[index]
                        : Icons.info_outline_rounded;
                    return InkWell(
                      onTap: () {
                        checkoutController.toggleInstruction(index);
                      },
                      borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                      child: Container(
                        padding: const EdgeInsets.all(Dimensions.paddingSizeExtraSmall),
                        decoration: BoxDecoration(
                          color: isSelected ? Theme.of(context).primaryColor.withValues(alpha: 0.08) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                          border: Border.all(
                            color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 4),
                            Icon(icon, color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).disabledColor, size: 18),
                            const SizedBox(width: Dimensions.paddingSizeSmall),
                            Expanded(
                              child: Text(
                                AppConstants.deliveryInstructionList[index].tr,
                                style: robotoMedium.copyWith(
                                  fontSize: Dimensions.fontSizeSmall,
                                  color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).disabledColor,
                                ),
                              ),
                            ),
                            if (isSelected)
                              Icon(Icons.check_circle, color: Theme.of(context).primaryColor, size: 18),
                            const SizedBox(width: 4),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                !checkoutController.isExpand ? const SizedBox() : const SizedBox(height: Dimensions.paddingSizeSmall),

              ]);
            }
        ),
      ),
    );
  }
}
