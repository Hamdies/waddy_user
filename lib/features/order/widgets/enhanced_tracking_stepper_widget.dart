import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/features/order/widgets/enhanced_stepper_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Sub-status constants matching backend OrderSubStatus
class OrderSubStatus {
  static const String preparing = 'preparing';
  static const String packaging = 'packaging';
  static const String ready = 'ready';
  static const String enRoute = 'en_route';
  static const String nearby = 'nearby';
  static const String arrived = 'arrived';
}

/// Enhanced tracking stepper that displays sub-statuses
class EnhancedTrackingStepperWidget extends StatelessWidget {
  final String? status;
  final String? subStatus;
  final bool takeAway;
  final String? eta;

  const EnhancedTrackingStepperWidget({
    super.key,
    required this.status,
    this.subStatus,
    required this.takeAway,
    this.eta,
  });

  @override
  Widget build(BuildContext context) {
    final stepInfo = _getStepInfo();

    return Container(
      padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
      ),
      child: Column(
        children: [
          Row(
            children: [
              EnhancedStepperWidget(
                title: 'order_placed'.tr,
                isActive: stepInfo.state > -1,
                isCompleted: stepInfo.state > 0,
                haveLeftBar: false,
                haveRightBar: true,
                rightActive: stepInfo.state > 0,
                subStatusText: stepInfo.state == 0 ? stepInfo.subText : null,
                showPulse: stepInfo.state == 0 && stepInfo.isCurrentStep,
              ),
              EnhancedStepperWidget(
                title: 'order_confirmed'.tr,
                isActive: stepInfo.state > 0,
                isCompleted: stepInfo.state > 1,
                haveLeftBar: true,
                haveRightBar: true,
                rightActive: stepInfo.state > 1,
                subStatusText: stepInfo.state == 1 ? stepInfo.subText : null,
                showPulse: stepInfo.state == 1 && stepInfo.isCurrentStep,
              ),
              EnhancedStepperWidget(
                title: 'preparing_item'.tr,
                isActive: stepInfo.state > 1,
                isCompleted: stepInfo.state > 2,
                haveLeftBar: true,
                haveRightBar: true,
                rightActive: stepInfo.state > 2,
                subStatusText: stepInfo.state == 2 ? stepInfo.subText : null,
                showPulse: stepInfo.state == 2 && stepInfo.isCurrentStep,
              ),
              EnhancedStepperWidget(
                title:
                    takeAway
                        ? 'ready_for_handover'.tr
                        : 'delivery_on_the_way'.tr,
                isActive: stepInfo.state > 2,
                isCompleted: stepInfo.state > 3,
                haveLeftBar: true,
                haveRightBar: true,
                rightActive: stepInfo.state > 3,
                subStatusText:
                    stepInfo.state == 3 ? (eta ?? stepInfo.subText) : null,
                showPulse: stepInfo.state == 3 && stepInfo.isCurrentStep,
              ),
              EnhancedStepperWidget(
                title: 'delivered'.tr,
                isActive: stepInfo.state > 3,
                isCompleted: stepInfo.state > 4,
                haveLeftBar: true,
                haveRightBar: false,
                rightActive: stepInfo.state > 4,
                subStatusText: stepInfo.state == 4 ? stepInfo.subText : null,
                showPulse: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  _StepInfo _getStepInfo() {
    int state = -1;
    String? subText;
    bool isCurrentStep = true;

    // Determine main state
    if (status == 'pending') {
      state = 0;
      subText = 'waiting_for_confirmation'.tr;
    } else if (status == 'accepted' || status == 'confirmed') {
      state = 1;
      subText = 'store_accepted_order'.tr;
    } else if (status == 'processing') {
      state = 2;
      // Use sub-status for detail
      subText = _getProcessingSubText();
    } else if (status == 'handover') {
      state = takeAway ? 3 : 2;
      subText = takeAway ? 'ready_to_pickup'.tr : _getProcessingSubText();
    } else if (status == 'picked_up') {
      state = 3;
      // Use sub-status for delivery detail
      subText = _getDeliverySubText();
    } else if (status == 'delivered') {
      state = 4;
      subText = 'order_completed'.tr;
      isCurrentStep = false;
    }

    return _StepInfo(
      state: state,
      subText: subText,
      isCurrentStep: isCurrentStep,
    );
  }

  String? _getProcessingSubText() {
    switch (subStatus) {
      case OrderSubStatus.preparing:
        return 'preparing_your_order'.tr;
      case OrderSubStatus.packaging:
        return 'packaging_order'.tr;
      case OrderSubStatus.ready:
        return 'order_ready'.tr;
      default:
        return 'preparing_your_order'.tr;
    }
  }

  String? _getDeliverySubText() {
    switch (subStatus) {
      case OrderSubStatus.enRoute:
        return 'driver_on_the_way'.tr;
      case OrderSubStatus.nearby:
        return 'driver_nearby'.tr;
      case OrderSubStatus.arrived:
        return 'driver_arrived'.tr;
      default:
        return eta ?? 'driver_on_the_way'.tr;
    }
  }
}

class _StepInfo {
  final int state;
  final String? subText;
  final bool isCurrentStep;

  _StepInfo({required this.state, this.subText, required this.isCurrentStep});
}
