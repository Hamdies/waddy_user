import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/helper/auth_helper.dart';
import 'package:sixam_mart/helper/route_helper.dart';

/// GetX middleware that redirects unauthenticated users to the unified auth screen.
/// Apply this to any route that requires authentication.
class AuthGuardMiddleware extends GetMiddleware {
  @override
  int? get priority => 1;

  @override
  RouteSettings? redirect(String? route) {
    if (!AuthHelper.isLoggedIn()) {
      return RouteSettings(name: RouteHelper.getUnifiedAuthRoute());
    }
    return null;
  }
}
