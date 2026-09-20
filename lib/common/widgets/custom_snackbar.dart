import 'package:waddy_app/common/widgets/coustom_toast.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// A single toast. New bars REPLACE the current one rather than queueing behind
/// it — `ScaffoldMessenger` queues serially, so without the hide a parallel
/// fan-out (the Spots home fires 7 reads at once) stacked 7 bars back-to-back
/// and blocked the screen bottom for ~14s. See docs/snackbar_noise_plan.md.
void showCustomSnackBar(
  String? message, {
  bool isError = true,
  bool getXSnackBar = false,
  int? showDuration,
}) {
  if (message == null || message.isEmpty) return;

  if (getXSnackBar) {
    if (Get.isSnackbarOpen) {
      Get.closeCurrentSnackbar();
    }
    Get.showSnackbar(
      GetSnackBar(
        backgroundColor: Colors.transparent,
        messageText: CustomToast(
          text: message,
          isError: isError,
          animate: false,
        ),
        maxWidth: 500,
        duration: Duration(seconds: showDuration ?? 3),
        snackStyle: SnackStyle.FLOATING,
        margin: const EdgeInsets.only(
          left: Dimensions.paddingSizeSmall,
          right: Dimensions.paddingSizeSmall,
          bottom: 100,
        ),
        borderRadius: 50,
        isDismissible: true,
        dismissDirection: DismissDirection.horizontal,
      ),
    );
    return;
  }

  // No context means no tree to attach to (a toast fired from a background
  // isolate or after teardown). Dropping it beats crashing on `Get.context!`.
  final BuildContext? context = Get.context;
  if (context == null) return;
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      dismissDirection: DismissDirection.endToStart,
      elevation: 0.0,
      backgroundColor: Colors.transparent,
      padding: EdgeInsets.zero,
      // Spacing lives on the SnackBar's own margin, NOT inside CustomToast. M3
      // animates a floating bar by interpolating its height, so any padding
      // inside the content is dead space being grown frame by frame — that was a
      // large part of the shudder. Margin sits outside the animated box.
      margin: const EdgeInsets.only(
        left: Dimensions.paddingSizeLarge,
        right: Dimensions.paddingSizeLarge,
        bottom: Dimensions.paddingSizeExtraOverLarge,
      ),
      content: CustomToast(text: message, isError: isError),
      duration: Duration(seconds: showDuration ?? 2),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
