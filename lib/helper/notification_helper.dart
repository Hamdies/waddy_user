import 'dart:convert';
import 'package:waddy_app/util/swallow.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:waddy_app/common/widgets/demo_reset_dialog_widget.dart';
import 'package:waddy_app/features/chat/controllers/chat_controller.dart';
import 'package:waddy_app/features/chat/enums/user_type_enum.dart';
import 'package:waddy_app/features/notification/controllers/notification_controller.dart';
import 'package:waddy_app/features/notification/domain/models/notification_body_model.dart';
import 'package:waddy_app/features/order/controllers/order_controller.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:waddy_app/helper/live_activity_helper.dart';
import 'package:waddy_app/services/live_activity_service.dart';

class NotificationHelper {
  static Future<void> initialize(
    FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin,
  ) async {
    var androidInitialize = const AndroidInitializationSettings(
      'notification_icon',
    );
    var iOSInitialize = const DarwinInitializationSettings();
    var initializationsSettings = InitializationSettings(
      android: androidInitialize,
      iOS: iOSInitialize,
    );
    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()!
        .requestNotificationsPermission();
    flutterLocalNotificationsPlugin.initialize(
      initializationsSettings,
      onDidReceiveNotificationResponse: (NotificationResponse load) async {
        try {
          if (load.payload!.isNotEmpty) {
            NotificationBodyModel payload = NotificationBodyModel.fromJson(
              jsonDecode(load.payload!),
            );

            final Map<NotificationType, Function> notificationActions = {
              NotificationType.order: () {
                Get.toNamed(
                  RouteHelper.getOrderDetailsRoute(
                    int.parse(payload.orderId.toString()),
                    fromNotification: true,
                  ),
                );
              },
              NotificationType.block:
                  () => Get.toNamed(
                    RouteHelper.getSignInRoute(RouteHelper.notification),
                  ),
              NotificationType.unblock:
                  () => Get.toNamed(
                    RouteHelper.getSignInRoute(RouteHelper.notification),
                  ),
              NotificationType.message:
                  () => Get.toNamed(
                    RouteHelper.getChatRoute(
                      notificationBody: payload,
                      conversationID: payload.conversationId,
                      fromNotification: true,
                    ),
                  ),
              NotificationType.otp: () => null,
              NotificationType.add_fund:
                  () => Get.toNamed(
                    RouteHelper.getWalletRoute(fromNotification: true),
                  ),
              NotificationType.referral_earn:
                  () => Get.toNamed(
                    RouteHelper.getWalletRoute(fromNotification: true),
                  ),
              NotificationType.cashback:
                  () => Get.toNamed(
                    RouteHelper.getWalletRoute(fromNotification: true),
                  ),
              NotificationType.loyalty_point:
                  () => Get.toNamed(
                    RouteHelper.getLoyaltyRoute(fromNotification: true),
                  ),
              NotificationType.spots_prize:
                  () => Get.toNamed(
                    (payload.index ?? 0) > 0
                        ? RouteHelper.getSpotsPrizeDetailsRoute(payload.index!)
                        : RouteHelper.getSpotsPrizesRoute(),
                  ),
              NotificationType.general:
                  () => Get.toNamed(
                    RouteHelper.getNotificationRoute(fromNotification: true),
                  ),
            };

            notificationActions[payload.notificationType]?.call();
          }
        } catch (e, s) {
          swallow('notification tap routing', e, s, true);
        }
        return;
      },
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      if (kDebugMode) {
        print("onMessage: ${message.data['type']}/${message.data}");
      }
      if (message.data['type'] == 'demo_reset') {
        Get.dialog(const DemoResetDialogWidget(), barrierDismissible: false);
      }
      if (message.data['type'] == 'message' &&
          Get.currentRoute.startsWith(RouteHelper.messages)) {
        if (AuthHelper.isLoggedIn()) {
          Get.find<ChatController>().getConversationList(1);
          if (Get.find<ChatController>().messageModel!.conversation!.id
                  .toString() ==
              message.data['conversation_id'].toString()) {
            Get.find<ChatController>().getMessages(
              1,
              NotificationBodyModel(
                notificationType: NotificationType.message,
                adminId:
                    message.data['sender_type'] == UserType.admin.name
                        ? 0
                        : null,
                restaurantId:
                    message.data['sender_type'] == UserType.vendor.name
                        ? 0
                        : null,
                deliverymanId:
                    message.data['sender_type'] == UserType.delivery_man.name
                        ? 0
                        : null,
              ),
              null,
              int.parse(message.data['conversation_id'].toString()),
            );
          } else {
            NotificationHelper.showNotification(
              message,
              flutterLocalNotificationsPlugin,
            );
          }
        }
      } else if (message.data['type'] == 'message' &&
          Get.currentRoute.startsWith(RouteHelper.conversation)) {
        if (AuthHelper.isLoggedIn()) {
          Get.find<ChatController>().getConversationList(1);
        }
        NotificationHelper.showNotification(
          message,
          flutterLocalNotificationsPlugin,
        );
      } else if (message.data['type'] == 'demo_reset') {
      } else {
        NotificationHelper.showNotification(
          message,
          flutterLocalNotificationsPlugin,
        );

        // Update Live Activity for order status changes
        if (message.data['type'] == 'order_status' &&
            message.data['order_id'] != null) {
          _updateLiveActivityFromFCM(message.data);
        }

        if (AuthHelper.isLoggedIn()) {
          Get.find<OrderController>().getRunningOrders(1);
          Get.find<OrderController>().getHistoryOrders(1);
          Get.find<NotificationController>().getNotificationList(true);
        }
      }

      Map<String, String> payloadData = {
        'title': '${message.data['title']}',
        'body': '${message.data['body']}',
        'order_id': '${message.data['order_id']}',
        'image': '${message.data['image']}',
        'type': '${message.data['type']}',
      };

      PayloadModel payload = PayloadModel.fromJson(payloadData);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        print("onOpenApp: ${message.data}");
      }
      try {
        if (message.data.isNotEmpty) {
          NotificationBodyModel notificationBody = convertNotification(
            message.data,
          );

          final Map<NotificationType, Function> notificationActions = {
            NotificationType.order:
                () => Get.toNamed(
                  RouteHelper.getOrderDetailsRoute(
                    int.parse(message.data['order_id']),
                    fromNotification: true,
                  ),
                ),
            NotificationType.block:
                () => Get.toNamed(
                  RouteHelper.getSignInRoute(RouteHelper.notification),
                ),
            NotificationType.unblock:
                () => Get.toNamed(
                  RouteHelper.getSignInRoute(RouteHelper.notification),
                ),
            NotificationType.message:
                () => Get.toNamed(
                  RouteHelper.getChatRoute(
                    notificationBody: notificationBody,
                    conversationID: notificationBody.conversationId,
                    fromNotification: true,
                  ),
                ),
            NotificationType.otp: () => null,
            NotificationType.add_fund:
                () => Get.toNamed(
                  RouteHelper.getWalletRoute(fromNotification: true),
                ),
            NotificationType.referral_earn:
                () => Get.toNamed(
                  RouteHelper.getWalletRoute(fromNotification: true),
                ),
            NotificationType.cashback:
                () => Get.toNamed(
                  RouteHelper.getWalletRoute(fromNotification: true),
                ),
            NotificationType.loyalty_point:
                () => Get.toNamed(
                  RouteHelper.getLoyaltyRoute(fromNotification: true),
                ),
            NotificationType.spots_prize:
                () => Get.toNamed(
                  (notificationBody.index ?? 0) > 0
                      ? RouteHelper.getSpotsPrizeDetailsRoute(
                        notificationBody.index!,
                      )
                      : RouteHelper.getSpotsPrizesRoute(),
                ),
            NotificationType.general:
                () => Get.toNamed(
                  RouteHelper.getNotificationRoute(fromNotification: true),
                ),
          };

          notificationActions[notificationBody.notificationType]?.call();
        }
      } catch (e, s) {
        swallow('notification tap routing', e, s, true);
      }
    });
  }

  static void _updateLiveActivityFromFCM(Map<String, dynamic> data) {
    final orderId = int.tryParse(data['order_id'].toString()) ?? 0;
    if (orderId == 0) return;

    var status = data['status'] as String?;
    final subStatus = data['sub_status'] as String?;
    final storeName = data['store_name'] as String?;
    final deliveryManName = data['delivery_man_name'] as String?;
    final etaMinutes = int.tryParse(data['eta_minutes']?.toString() ?? '');
    final etaText =
        data['eta_text'] as String? ??
        (etaMinutes != null ? 'Arriving in $etaMinutes mins' : null);

    // If status not in FCM payload, try to get it from the cached track model
    if (status == null) {
      try {
        final trackModel = Get.find<OrderController>().trackModel;
        if (trackModel?.id == orderId) {
          status = trackModel?.orderStatus;
        }
      } catch (e, s) {
        // Opportunistic read of an already-open tracking screen. Absent
        // controller just means we fall back to the payload's own status.
        swallow('read order status from open tracker', e, s);
      }
    }

    if (status == null) return;

    if (LiveActivityHelper.isTerminalStatus(status)) {
      LiveActivityService.endActivity(orderId);
    } else {
      LiveActivityService.updateActivity(
        orderId: orderId,
        status: status,
        subStatus: subStatus,
        eta: etaText,
        storeName: storeName,
        deliveryManName: deliveryManName,
      );
    }
  }

  static Future<void> showNotification(
    RemoteMessage message,
    FlutterLocalNotificationsPlugin fln,
  ) async {
    String? title;
    String? body;
    String? orderID;
    String? image;
    NotificationBodyModel notificationBody = convertNotification(message.data);

    title = message.data['title'];
    body = message.data['body'];
    orderID = message.data['order_id'];
    image =
        (message.data['image'] != null && message.data['image'].isNotEmpty)
            ? message.data['image'].startsWith('http')
                ? message.data['image']
                : '${AppConstants.baseUrl}/storage/app/public/notification/${message.data['image']}'
            : null;

    if (image != null && image.isNotEmpty) {
      try {
        await showBigPictureNotificationHiddenLargeIcon(
          title,
          body,
          orderID,
          notificationBody,
          image,
          fln,
        );
      } catch (e) {
        await showBigTextNotification(
          title,
          body!,
          orderID,
          notificationBody,
          fln,
        );
      }
    } else {
      await showBigTextNotification(
        title,
        body!,
        orderID,
        notificationBody,
        fln,
      );
    }
  }

  static Future<void> showTextNotification(
    String title,
    String body,
    String orderID,
    NotificationBodyModel? notificationBody,
    FlutterLocalNotificationsPlugin fln,
  ) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          '6ammart',
          AppConstants.appName,
          playSound: true,
          importance: Importance.max,
          priority: Priority.max,
          sound: RawResourceAndroidNotificationSound('notification'),
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    await fln.show(
      0,
      title,
      body,
      platformChannelSpecifics,
      payload:
          notificationBody != null
              ? jsonEncode(notificationBody.toJson())
              : null,
    );
  }

  static Future<void> showBigTextNotification(
    String? title,
    String body,
    String? orderID,
    NotificationBodyModel? notificationBody,
    FlutterLocalNotificationsPlugin fln,
  ) async {
    BigTextStyleInformation bigTextStyleInformation = BigTextStyleInformation(
      body,
      htmlFormatBigText: true,
      contentTitle: title,
      htmlFormatContentTitle: true,
    );
    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          '6ammart',
          AppConstants.appName,
          importance: Importance.max,
          styleInformation: bigTextStyleInformation,
          priority: Priority.max,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('notification'),
        );
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );
    NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );
    await fln.show(
      0,
      title,
      body,
      platformChannelSpecifics,
      payload:
          notificationBody != null
              ? jsonEncode(notificationBody.toJson())
              : null,
    );
  }

  static Future<void> showBigPictureNotificationHiddenLargeIcon(
    String? title,
    String? body,
    String? orderID,
    NotificationBodyModel? notificationBody,
    String image,
    FlutterLocalNotificationsPlugin fln,
  ) async {
    final String largeIconPath = await _downloadAndSaveFile(image, 'largeIcon');
    final String bigPicturePath = await _downloadAndSaveFile(
      image,
      'bigPicture',
    );
    final BigPictureStyleInformation bigPictureStyleInformation =
        BigPictureStyleInformation(
          FilePathAndroidBitmap(bigPicturePath),
          hideExpandedLargeIcon: true,
          contentTitle: title,
          htmlFormatContentTitle: true,
          summaryText: body,
          htmlFormatSummaryText: true,
        );
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          '6ammart',
          AppConstants.appName,
          largeIcon: FilePathAndroidBitmap(largeIconPath),
          priority: Priority.max,
          playSound: true,
          styleInformation: bigPictureStyleInformation,
          importance: Importance.max,
          sound: const RawResourceAndroidNotificationSound('notification'),
        );
    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    await fln.show(
      0,
      title,
      body,
      platformChannelSpecifics,
      payload:
          notificationBody != null
              ? jsonEncode(notificationBody.toJson())
              : null,
    );
  }

  static Future<String> _downloadAndSaveFile(
    String url,
    String fileName,
  ) async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final String filePath = '${directory.path}/$fileName';
    final http.Response response = await http.get(Uri.parse(url));
    final File file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);
    return filePath;
  }

  static NotificationBodyModel convertNotification(Map<String, dynamic> data) {
    final type = data['type'];

    switch (type) {
      case 'referral_code':
        return NotificationBodyModel(
          notificationType: NotificationType.general,
        );
      case 'referral_earn':
        return NotificationBodyModel(
          notificationType: NotificationType.referral_earn,
        );
      case 'cashback':
        return NotificationBodyModel(
          notificationType: NotificationType.cashback,
        );
      case 'loyalty_point':
        return NotificationBodyModel(
          notificationType: NotificationType.loyalty_point,
        );
      case 'spots_prize_won':
        return NotificationBodyModel(
          notificationType: NotificationType.spots_prize,
          // The backend sends the prize id as data_id (the FCM helper only
          // forwards a fixed key list — a prize_id key would be dropped).
          index: int.tryParse('${data['data_id']}'),
        );
      case 'otp':
        return NotificationBodyModel(notificationType: NotificationType.otp);
      case 'add_fund':
        return NotificationBodyModel(
          notificationType: NotificationType.add_fund,
        );
      case 'block':
        return NotificationBodyModel(notificationType: NotificationType.block);
      case 'unblock':
        return NotificationBodyModel(
          notificationType: NotificationType.unblock,
        );
      case 'order_status':
        return _handleOrderNotification(data);
      case 'trip_status':
        return _handleTripNotification(data);
      case 'message':
        return _handleMessageNotification(data);
      default:
        return NotificationBodyModel(
          notificationType: NotificationType.general,
        );
    }
  }

  static NotificationBodyModel _handleOrderNotification(
    Map<String, dynamic> data,
  ) {
    final orderId = data['order_id'];
    return NotificationBodyModel(
      orderId: int.tryParse(orderId) ?? 0,
      notificationType: NotificationType.order,
    );
  }

  static NotificationBodyModel _handleTripNotification(
    Map<String, dynamic> data,
  ) {
    final orderId = data['order_id'];
    return NotificationBodyModel(
      orderId: int.tryParse(orderId) ?? 0,
      notificationType: NotificationType.trip,
    );
  }

  static NotificationBodyModel _handleMessageNotification(
    Map<String, dynamic> data,
  ) {
    final conversationId = data['conversation_id'];
    final senderType = data['sender_type'];

    return NotificationBodyModel(
      notificationType: NotificationType.message,
      deliverymanId: senderType == 'delivery_man' ? 0 : null,
      adminId: senderType == 'admin' ? 0 : null,
      restaurantId: senderType == 'vendor1' ? 0 : null,
      conversationId: int.parse(conversationId.toString()),
    );
  }
}

@pragma('vm:entry-point')
Future<dynamic> myBackgroundMessageHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print("onBackground: ${message.data}");
  }
}

class PayloadModel {
  PayloadModel({this.title, this.body, this.orderId, this.image, this.type});

  String? title;
  String? body;
  String? orderId;
  String? image;
  String? type;

  factory PayloadModel.fromRawJson(String str) =>
      PayloadModel.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory PayloadModel.fromJson(Map<String, dynamic> json) => PayloadModel(
    title: json["title"],
    body: json["body"],
    orderId: json["order_id"],
    image: json["image"],
    type: json["type"],
  );

  Map<String, dynamic> toJson() => {
    "title": title,
    "body": body,
    "order_id": orderId,
    "image": image,
    "type": type,
  };
}
