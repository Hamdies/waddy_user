import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:waddy_app/api/api_client.dart';
import 'package:waddy_app/helper/live_activity_helper.dart';
import 'package:waddy_app/util/app_constants.dart';

class LiveActivityService {
  static const _channel = MethodChannel(
    'com.hamdiesolutions.waddi/live_activity',
  );

  static Future<bool> isSupported() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'isLiveActivitySupported',
      );
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<String?> startActivity({
    required int orderId,
    required String status,
    String? subStatus,
    String? eta,
    String? storeName,
    String? storeLogoUrl,
    String? deliveryManName,
    String orderType = 'delivery',
  }) async {
    try {
      final activityData = LiveActivityHelper.getActivityData(
        status: status,
        subStatus: subStatus,
        eta: eta,
        takeAway: orderType == 'take_away',
      );

      final result = await _channel.invokeMethod<String>('startLiveActivity', {
        'orderId': orderId,
        'orderType': orderType,
        'storeName': storeName,
        'storeLogoUrl': storeLogoUrl,
        'status': status,
        'subStatus': subStatus,
        'title': activityData.title,
        'subtitle': activityData.subtitle,
        'progress': activityData.progress,
        'etaText': activityData.etaText,
        'step': activityData.step,
        'deliveryManName': deliveryManName,
      });

      // On iOS, result is the push token — send it to backend for APNs updates
      if (result != null && result.isNotEmpty) {
        debugPrint(
          'LiveActivityService: push token received (${result.length} chars), sending to backend...',
        );
        _sendPushTokenToBackend(orderId, result);
      } else {
        debugPrint('LiveActivityService: no push token returned');
      }
      return result;
    } on PlatformException catch (e) {
      debugPrint('LiveActivityService.startActivity error: $e');
      return null;
    }
  }

  static Future<void> updateActivity({
    required int orderId,
    required String status,
    String? subStatus,
    String? eta,
    String? deliveryManName,
    String? storeName,
    String orderType = 'delivery',
  }) async {
    try {
      final activityData = LiveActivityHelper.getActivityData(
        status: status,
        subStatus: subStatus,
        eta: eta,
        takeAway: orderType == 'take_away',
      );

      await _channel.invokeMethod('updateLiveActivity', {
        'orderId': orderId,
        'status': status,
        'subStatus': subStatus,
        'title': activityData.title,
        'subtitle': activityData.subtitle,
        'progress': activityData.progress,
        'etaText': activityData.etaText,
        'step': activityData.step,
        'deliveryManName': deliveryManName,
        'storeName': storeName,
      });
    } on PlatformException catch (e) {
      debugPrint('LiveActivityService.updateActivity error: $e');
    }
  }

  static Future<void> _sendPushTokenToBackend(
    int orderId,
    String pushToken,
  ) async {
    try {
      await Get.find<ApiClient>().postData(AppConstants.liveActivityTokenUri, {
        'order_id': orderId,
        'push_token': pushToken,
      });
    } catch (e) {
      debugPrint('LiveActivityService: Failed to send push token - $e');
    }
  }

  static Future<void> endActivity(int orderId) async {
    try {
      await _channel.invokeMethod('endLiveActivity', {'orderId': orderId});
    } on PlatformException catch (e) {
      debugPrint('LiveActivityService.endActivity error: $e');
    }
  }
}
