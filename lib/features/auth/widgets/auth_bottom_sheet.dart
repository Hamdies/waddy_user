import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/auth/widgets/auth_flow_widget.dart';
import 'package:waddy_app/features/cart/controllers/cart_controller.dart';
import 'package:waddy_app/helper/analytics_helper.dart';
import 'package:waddy_app/helper/guest_carryover_helper.dart';
import 'package:waddy_app/util/dimensions.dart';

/// Quick phone → OTP login sheet for guests at checkout. The guest's local
/// cart is snapshotted before the flow starts and merged to the server on
/// success — the guest's server cart is migrated to the account by the backend
/// on login (`check_guest_cart`), so nothing is lost or doubled.
Future<void> showAuthBottomSheet({required VoidCallback onSuccess}) async {
  bool succeeded = false;
  AnalyticsHelper.log('checkout_auth_sheet_opened');

  // Wait one frame before presenting. Callers often trigger this from a tap on
  // a widget that is simultaneously being rebuilt (e.g. a leaderboard card when
  // fresh data lands), and grabbing a context mid-teardown throws "Looking up a
  // deactivated widget's ancestor". Waiting for end-of-frame guarantees we're
  // not inside a build; the overlay context is stable across those page
  // rebuilds, unlike Get.context which may point at a deactivated element.
  await WidgetsBinding.instance.endOfFrame;

  await showModalBottomSheet(
    context: Get.overlayContext ?? Get.context!,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(Dimensions.radiusExtraLarge),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: Dimensions.paddingSizeLarge,
            right: Dimensions.paddingSizeLarge,
            top: Dimensions.paddingSizeSmall,
            bottom:
                MediaQuery.of(context).viewInsets.bottom +
                Dimensions.paddingSizeLarge,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(
                    bottom: Dimensions.paddingSizeDefault,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).disabledColor.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                AuthFlowWidget(
                  compact: true,
                  showNameStep: false,
                  onSuccess: () async {
                    succeeded = true;
                    AnalyticsHelper.log('checkout_auth_sheet_success');
                    await Get.find<CartController>().mergeGuestCartToServer();
                    // Correct the new account's saved address before continuing:
                    // never persist the Maadi browsing seed for an out-of-zone
                    // guest. See docs/guest_mode_plan.md (Amendment B).
                    await GuestCarryover.onLogin();
                    if (context.mounted) Navigator.of(context).pop();
                    onSuccess();
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  if (!succeeded) {
    AnalyticsHelper.log('checkout_auth_sheet_abandoned');
  }
}
