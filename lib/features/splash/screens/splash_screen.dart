import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sixam_mart/features/auth/controllers/auth_controller.dart';
import 'package:sixam_mart/features/cart/controllers/cart_controller.dart';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/features/notification/domain/models/notification_body_model.dart';
import 'package:sixam_mart/helper/address_helper.dart';
import 'package:sixam_mart/helper/auth_helper.dart';
import 'package:sixam_mart/common/widgets/no_internet_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';

class SplashScreen extends StatefulWidget {
  final NotificationBodyModel? body;
  const SplashScreen({super.key, required this.body});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> {
  final GlobalKey<ScaffoldState> _globalKey = GlobalKey();
  StreamSubscription<List<ConnectivityResult>>? _onConnectivityChanged;

  @override
  void initState() {
    super.initState();

    bool firstTime = true;
    _onConnectivityChanged = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> result,
    ) {
      bool isConnected =
          result.contains(ConnectivityResult.wifi) ||
          result.contains(ConnectivityResult.mobile);

      if (!firstTime) {
        isConnected
            ? ScaffoldMessenger.of(Get.context!).hideCurrentSnackBar()
            : const SizedBox();
        ScaffoldMessenger.of(Get.context!).showSnackBar(
          SnackBar(
            backgroundColor: isConnected ? Colors.green : Colors.red,
            duration: Duration(seconds: isConnected ? 3 : 6000),
            content: Text(
              isConnected ? 'connected'.tr : 'no_connection'.tr,
              textAlign: TextAlign.center,
            ),
          ),
        );
        if (isConnected) {
          Get.find<SplashController>().getConfigData(
            notificationBody: widget.body,
          );
        }
      }

      firstTime = false;
    });

    Get.find<SplashController>().initSharedData();
    if ((AuthHelper.getGuestId().isNotEmpty || AuthHelper.isLoggedIn()) &&
        Get.find<SplashController>().cacheModule != null) {
      Get.find<CartController>().getCartDataOnline();
    }
    // _route();
    Get.find<SplashController>().getConfigData(notificationBody: widget.body);
  }

  @override
  void dispose() {
    _onConnectivityChanged?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Get.find<SplashController>().initSharedData();
    if (AddressHelper.getUserAddressFromSharedPref() != null &&
        AddressHelper.getUserAddressFromSharedPref()!.zoneIds == null) {
      Get.find<AuthController>().clearSharedAddress();
    }

    return Scaffold(
      key: _globalKey,
      backgroundColor: Colors.white,
      body: GetBuilder<SplashController>(
        builder: (splashController) {
          return splashController.hasConnection
              ? Center(
                  child: Lottie.asset(
                    'assets/animation/waddy_anim.json',
                    width: 300,
                    height: 300,
                    fit: BoxFit.contain,
                  ),
                )
              : NoInternetScreen(child: SplashScreen(body: widget.body));
        },
      ),
    );
  }
}
