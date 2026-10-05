import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/auth/controllers/auth_controller.dart';
import 'package:waddy_app/features/favourite/controllers/favourite_controller.dart';
import 'package:waddy_app/features/language/controllers/language_controller.dart';
import 'package:waddy_app/features/location/controllers/location_controller.dart';
import 'package:waddy_app/features/notification/domain/models/notification_body_model.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/helper/deep_link_helper.dart';
import 'package:waddy_app/helper/guest_bootstrap_helper.dart';
import 'package:waddy_app/helper/location_gate_helper.dart';
import 'package:waddy_app/features/pets/pets_navigator.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/app_constants.dart';

// class SplashRouteHelper{

// Plays the splash's exit animation (if one is registered), then navigates.
// All async prep must happen BEFORE this call so the splash never sits on a
// dead frame after its logo has left.
Future<void> _exitSplashThen(void Function() navigate) async {
  await Get.find<SplashController>().playSplashExit();
  navigate();
}

void route({NotificationBodyModel? body}) {
  double? minimumVersion = _getMinimumVersion();
  bool isMaintenanceMode =
      Get.find<SplashController>().configModel.maintenanceMode!;
  bool needsUpdate = AppConstants.appVersion < minimumVersion!;

  if (needsUpdate || isMaintenanceMode) {
    _exitSplashThen(
      () => Get.offNamed(RouteHelper.getUpdateRoute(needsUpdate)),
    );
  } else if (body != null) {
    // Notification cold starts own the routing; a deep link stashed in the
    // same launch must not fire later when the user reaches home.
    DeepLinkHelper.clearPending();
    _forNotificationRouteProcess(body);
  } else {
    _handleUserRouting();
  }
}

double? _getMinimumVersion() {
  if (GetPlatform.isAndroid) {
    return Get.find<SplashController>().configModel.appMinimumVersionAndroid;
  } else if (GetPlatform.isIOS) {
    return Get.find<SplashController>().configModel.appMinimumVersionIos;
  }
  return 0;
}

void _forNotificationRouteProcess(NotificationBodyModel? notificationBody) {
  final notificationType = notificationBody?.notificationType;

  final Map<NotificationType, Function> notificationActions = {
    NotificationType.order:
        () => Get.toNamed(
          RouteHelper.getOrderDetailsRoute(
            notificationBody!.orderId,
            fromNotification: true,
          ),
        ),
    NotificationType.block:
        () => _exitSplashThen(
          () => Get.offNamed(
            RouteHelper.getSignInRoute(RouteHelper.notification),
          ),
        ),
    NotificationType.unblock:
        () => _exitSplashThen(
          () => Get.offNamed(
            RouteHelper.getSignInRoute(RouteHelper.notification),
          ),
        ),
    NotificationType.message:
        () => Get.toNamed(
          RouteHelper.getChatRoute(
            notificationBody: notificationBody,
            conversationID: notificationBody!.conversationId,
            fromNotification: true,
          ),
        ),
    NotificationType.otp: () => null,
    NotificationType.add_fund:
        () => Get.toNamed(RouteHelper.getWalletRoute(fromNotification: true)),
    NotificationType.referral_earn:
        () => Get.toNamed(RouteHelper.getWalletRoute(fromNotification: true)),
    NotificationType.cashback:
        () => Get.toNamed(RouteHelper.getWalletRoute(fromNotification: true)),
    NotificationType.loyalty_point:
        () => Get.toNamed(RouteHelper.getLoyaltyRoute(fromNotification: true)),
    NotificationType.spots_prize:
        () => Get.toNamed(
          (notificationBody?.index ?? 0) > 0
              ? RouteHelper.getSpotsPrizeDetailsRoute(notificationBody!.index!)
              : RouteHelper.getSpotsPrizesRoute(),
        ),
    NotificationType.spots_draw:
        () => Get.toNamed(
          RouteHelper.getSpotsClawDrawRoute(period: notificationBody?.period),
        ),
    NotificationType.level_up:
        () => _exitSplashThen(
          () => Get.offAllNamed(RouteHelper.getMainRoute('levels')),
        ),
    NotificationType.challenge_complete:
        () => _exitSplashThen(() {
          Get.offAllNamed(RouteHelper.getMainRoute('levels'));
          Get.toNamed(RouteHelper.xpChallenges);
        }),
    NotificationType.pets:
        () => _exitSplashThen(() {
          Get.offAllNamed(RouteHelper.getMainRoute('home'));
          PetsNavigator.openHub(switchTab: false);
        }),
    NotificationType.general:
        () => Get.toNamed(
          RouteHelper.getNotificationRoute(fromNotification: true),
        ),
  };

  notificationActions[notificationType]?.call();
}

Future<void> _forLoggedInUserRouteProcess() async {
  // Verified the phone but never submitted a name (app killed on the profile
  // step, or the request failed). The token in hand is only temporary, so
  // send them back to finish rather than into a half-authed home.
  //
  // The pending phone must be present too: the resumed name step submits with
  // it, and without one the screen would fall back to asking for the number
  // again. Same condition the screen itself uses, so the two can't disagree.
  final AuthController authController = Get.find<AuthController>();
  if (authController.isProfileIncomplete()) {
    if (authController.getPendingProfilePhone() != null) {
      await _exitSplashThen(
        () => Get.offNamed(RouteHelper.getUnifiedAuthRoute()),
      );
      return;
    }
    // Flagged but no phone to resume with: the temporary token can't be
    // completed, so drop it and start clean rather than sit on a dead session.
    await authController.clearSharedData();
    await _exitSplashThen(
      () => Get.offNamed(RouteHelper.getUnifiedAuthRoute()),
    );
    return;
  }

  authController.updateToken();
  // Usability, not mere presence: a cleared address is stored as an empty
  // AddressModel, so a null check would send the user to a home screen with
  // nowhere to deliver.
  if (LocationGate.hasUsableAddress()) {
    if (Get.find<SplashController>().module != null) {
      await Get.find<FavouriteController>().getFavouriteList();
    }
    await _exitSplashThen(
      () => Get.offNamed(RouteHelper.getInitialRoute(fromSplash: true)),
    );
  } else {
    await _exitSplashThen(
      () => Get.find<LocationController>().navigateToLocationScreen(
        'splash',
        offNamed: true,
      ),
    );
  }
}

// Applies the device locale when the app ships a matching language, so the
// picker can be skipped. Returns false when nothing matched and the user has
// to choose for themselves.
bool _applyDeviceLanguage() {
  try {
    final Locale? deviceLocale = Get.deviceLocale;
    if (deviceLocale == null) {
      return false;
    }
    final String languageCode = deviceLocale.languageCode.toLowerCase();
    final int index = AppConstants.languages.indexWhere(
      (language) => language.languageCode?.toLowerCase() == languageCode,
    );
    if (index == -1) {
      return false;
    }

    final LocalizationController localizationController =
        Get.find<LocalizationController>();
    localizationController.setSelectLanguageIndex(index);
    localizationController.setLanguage(
      Locale(
        AppConstants.languages[index].languageCode!,
        AppConstants.languages[index].countryCode,
      ),
    );
    return true;
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[Waddy] device language auto-detection failed: $e');
    }
    return false;
  }
}

Future<void> _newlyRegisteredRouteProcess() async {
  // Resolve the language BEFORE navigating. The picker used to be pushed
  // unconditionally and then auto-dismiss itself from a post-frame callback,
  // which made it flash on screen for a moment on every first launch.
  final bool needsLanguagePicker =
      AppConstants.languages.length > 1 && !_applyDeviceLanguage();

  if (needsLanguagePicker) {
    await _exitSplashThen(
      () => Get.offNamed(RouteHelper.getLanguageRoute('splash')),
    );
  } else {
    await _exitSplashThen(() => Get.offNamed(RouteHelper.getOnBoardingRoute()));
  }
}

Future<void> _handleUserRouting() async {
  if (kDebugMode) {
    debugPrint(
      '[Waddy] entry resolver → '
      'loggedIn=${AuthHelper.isLoggedIn()} '
      'guest=${AuthHelper.isGuestLoggedIn()} '
      'usableAddr=${LocationGate.hasUsableAddress()} '
      'showIntro=${Get.find<SplashController>().showIntro()} '
      'guestBrowse=${GuestBootstrapHelper.guestBrowseEnabled}',
    );
  }
  if (AuthHelper.isLoggedIn()) {
    _forLoggedInUserRouteProcess();
    return;
  }

  if (AuthHelper.isGuestLoggedIn() && LocationGate.hasUsableAddress()) {
    // Returning guest with a real address: straight to home, then re-verify the
    // serving zone in the background so someone who has moved sees the correct
    // stamp without a blocking wait. Fire-and-forget; internally throttled.
    Get.find<LocationController>().refreshOutOfZoneStatus();
    await _exitSplashThen(
      () => Get.offNamed(RouteHelper.getInitialRoute(fromSplash: true)),
    );
    return;
  }

  if (Get.find<SplashController>().showIntro() == true) {
    _newlyRegisteredRouteProcess();
    return;
  }

  if (!GuestBootstrapHelper.guestBrowseEnabled) {
    await _exitSplashThen(
      () => Get.offNamed(RouteHelper.getUnifiedAuthRoute()),
    );
    return;
  }

  // No usable location. The app is zone-scoped and genuinely cannot work
  // without one, so this gate insists on a real address rather than inventing
  // a fallback. It either resolves from GPS or hands the user a mandatory
  // picker; every restart repeats it until a location exists.
  await Get.find<SplashController>().playSplashExit();
  await GuestBootstrapHelper.bootstrapGuest();
}

// }
