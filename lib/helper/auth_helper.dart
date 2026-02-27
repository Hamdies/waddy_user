import 'package:get/get.dart';
import 'package:sixam_mart/features/auth/controllers/auth_controller.dart';

class AuthHelper {
  static bool isGuestLoggedIn() {
    return false;
  }

  static String getGuestId() {
    return Get.find<AuthController>().getGuestId();
  }

  static bool isLoggedIn() {
    return Get.find<AuthController>().isLoggedIn();
  }
}
