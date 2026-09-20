import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/checkout/controllers/checkout_controller.dart';
import 'package:waddy_app/features/checkout/widgets/voice_recorder_widget.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

class DeliveryInstructionView extends StatefulWidget {
  const DeliveryInstructionView({super.key});

  @override
  State<DeliveryInstructionView> createState() =>
      _DeliveryInstructionViewState();
}

class _DeliveryInstructionViewState extends State<DeliveryInstructionView> {
  ExpansibleController controller = ExpansibleController();

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
    return Container(
      decoration: BoxDecoration(color: Theme.of(context).cardColor),
      child: GetBuilder<CheckoutController>(
        builder: (checkoutController) {
          final bool hasVoice = checkoutController.voiceInstructionPath != null;
          final bool hasTextInstructions =
              checkoutController.selectedInstructions.isNotEmpty;
          final bool hasAnyInstruction = hasVoice || hasTextInstructions;

          return Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              controller: controller,
              tilePadding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeLarge,
                vertical: 0,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(
                Dimensions.paddingSizeLarge,
                0,
                Dimensions.paddingSizeLarge,
                Dimensions.paddingSizeDefault,
              ),
              onExpansionChanged:
                  (value) => checkoutController.expandedUpdate(value),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color:
                      hasAnyInstruction
                          ? Theme.of(
                            context,
                          ).primaryColor.withValues(alpha: 0.1)
                          : Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mic_rounded,
                  color:
                      hasAnyInstruction
                          ? Theme.of(context).primaryColor
                          : Colors.grey.shade600,
                  size: 20,
                ),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'add_delivery_instructions'.tr,
                    style: waddyMedium.copyWith(
                      fontSize: Dimensions.fontSizeDefault,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasAnyInstruction
                        ? _buildSummaryText(checkoutController)
                        : 'help_delivery_partner_reach_faster'.tr,
                    style: waddyRegular.copyWith(
                      fontSize: Dimensions.fontSizeExtraSmall,
                      color:
                          hasAnyInstruction
                              ? Theme.of(context).primaryColor
                              : Theme.of(context).hintColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              trailing: Icon(
                checkoutController.isExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: Theme.of(context).hintColor,
              ),
              children: [
                /// Voice Recorder
                Text(
                  'voice_instruction'.tr,
                  style: waddyMedium.copyWith(
                    fontSize: Dimensions.fontSizeSmall,
                  ),
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),
                VoiceRecorderWidget(
                  existingRecordingPath:
                      checkoutController.voiceInstructionPath,
                  onRecordingChanged: (path) {
                    checkoutController.setVoiceInstructionPath(path);
                  },
                ),

                const SizedBox(height: Dimensions.paddingSizeLarge),

                /// Quick Instruction Chips
                Text(
                  'quick_options'.tr,
                  style: waddyMedium.copyWith(
                    fontSize: Dimensions.fontSizeSmall,
                  ),
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),

                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.1,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: AppConstants.deliveryInstructionList.length,
                  itemBuilder: (context, index) {
                    final bool isSelected = checkoutController
                        .selectedInstructions
                        .contains(index);
                    return _buildInstructionChip(
                      context,
                      index,
                      isSelected,
                      checkoutController,
                    );
                  },
                ),

                const SizedBox(height: Dimensions.paddingSizeDefault),

                /// Save for address toggle
                InkWell(
                  onTap:
                      () =>
                          checkoutController.toggleSaveInstructionForAddress(),
                  borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: Checkbox(
                          value: checkoutController.saveInstructionForAddress,
                          onChanged:
                              (_) =>
                                  checkoutController
                                      .toggleSaveInstructionForAddress(),
                          activeColor: Theme.of(context).primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              Dimensions.radiusExtraSmall,
                            ),
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: Dimensions.paddingSizeSmall),
                      Expanded(
                        child: Text(
                          'save_for_all_orders_at_this_address'.tr,
                          style: waddyRegular.copyWith(
                            fontSize: Dimensions.fontSizeSmall,
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInstructionChip(
    BuildContext context,
    int index,
    bool isSelected,
    CheckoutController controller,
  ) {
    final IconData icon =
        index < _instructionIcons.length
            ? _instructionIcons[index]
            : Icons.info_outline_rounded;

    return InkWell(
      onTap: () => controller.toggleInstruction(index),
      borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      child: Container(
        decoration: BoxDecoration(
          color:
              isSelected
                  ? Theme.of(context).primaryColor.withValues(alpha: 0.08)
                  : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
          border: Border.all(
            color:
                isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.topRight,
              children: [
                Icon(
                  icon,
                  color:
                      isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.grey.shade600,
                  size: 26,
                ),
                if (isSelected)
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 10,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeExtraSmall,
              ),
              child: Text(
                AppConstants.deliveryInstructionList[index].tr,
                style: waddyRegular.copyWith(
                  fontSize: Dimensions.fontSizeExtraSmall,
                  color:
                      isSelected
                          ? Theme.of(context).primaryColor
                          : Theme.of(context).textTheme.bodyMedium?.color,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildSummaryText(CheckoutController controller) {
    final parts = <String>[];
    if (controller.voiceInstructionPath != null) {
      parts.add('voice_note'.tr);
    }
    if (controller.selectedInstructions.isNotEmpty) {
      parts.add(
        '${controller.selectedInstructions.length} ${'options_selected'.tr}',
      );
    }
    return parts.join(' + ');
  }
}
