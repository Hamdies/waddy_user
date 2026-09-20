import 'package:flutter/foundation.dart';
import 'package:waddy_app/features/favourite/controllers/favourite_controller.dart';
import 'package:waddy_app/features/auth/controllers/auth_controller.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/helper/guest_bootstrap_helper.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:get/get.dart';

class ApiChecker {
  /// [showError] controls ONLY the failure toast. The 401 session sweep below
  /// is unconditional — an expired session must always be swept out, that is a
  /// session concern and not a presentation one.
  ///
  /// Default is `false` (silent) because the overwhelming majority of callers
  /// are reads: background refreshes, prefetches and parallel fan-outs whose
  /// failure the presentation layer already absorbs into a cached or partial
  /// render. Writes opt in explicitly. See docs/snackbar_noise_plan.md.
  static void checkApi(
    Response response, {
    bool getXSnackBar = false,
    bool showError = false,
  }) {
    if (response.statusCode == 401) {
      // 401-SWEEP INSTRUMENTATION (debug only, no behaviour change).
      // Names the endpoint + auth-state on every 401 so the guest-open-surface
      // sweep produces hard evidence instead of a subjective "seemed fine".
      // A 401 logged with authState=guest is a NOT-guest-safe endpoint to fix.
      // This is the data the §8 flip depends on ("sweep finds no guest 401").
      //
      // On `none`: a genuine no-session 401 is expected only when guest-browse
      // is OFF. A `none` 401 while the flag is ON is SUSPICIOUS — it can be a
      // guest-safety bug wearing the wrong label (e.g. a call racing an
      // in-flight bootstrap, or a session just cleared). It's tagged
      // `none-FLAG_ON-SUSPECT` so the sweep treats it like a guest hit, not a
      // benign none. (The bootstrap path itself is race-safe: _handleUserRouting
      // awaits guestLogin→saveSharedPrefGuestId before navigating home, so no
      // mounted screen fires an API call before guest_id is persisted.)
      // Remove alongside the guard revisit. See docs/guest_mode_DETAILS.md §8/§9.
      if (kDebugMode) {
        final String url = response.request?.url.toString() ?? 'unknown';
        String authState;
        if (AuthHelper.isLoggedIn()) {
          authState = 'user';
        } else if (AuthHelper.isGuestLoggedIn()) {
          authState = 'guest';
        } else {
          authState =
              GuestBootstrapHelper.guestBrowseEnabled
                  ? 'none-FLAG_ON-SUSPECT'
                  : 'none';
        }
        debugPrint('[Waddy] 401-SWEEP → authState=$authState endpoint=$url');
      }

      // Guests browse freely. A 401 here means a background/browse endpoint the
      // guest isn't allowed on (e.g. address/list) — NOT an expired session, so
      // never force the guest to the auth screen. The caller already degrades
      // gracefully on the empty response. Auth is required only at action
      // boundaries (checkout, favourites, orders), and those screens gate
      // themselves. Only a genuinely logged-in user whose session expired should
      // be swept out to sign in again.
      if (!AuthHelper.isLoggedIn()) {
        return;
      }

      Get.find<AuthController>().clearSharedData(removeToken: false).then((
        value,
      ) {
        Get.find<FavouriteController>().removeFavourite();
        Get.offAllNamed(RouteHelper.getUnifiedAuthRoute());
      });
    } else if (showError) {
      showCustomSnackBar(response.statusText, getXSnackBar: getXSnackBar);
    }
  }
}
