import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:waddy_app/util/swallow.dart';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:get/get.dart';
import 'package:waddy_app/api/api_client.dart';
import 'package:waddy_app/helper/analytics_helper.dart';

/// iOS App Tracking Transparency, and the bridge that tells the Facebook SDK
/// whether it may use the IDFA for ad attribution.
///
/// Apple rules this code must respect (App Store Guideline 5.1.2):
/// the prompt is never shown before the user has seen real content, the app
/// never gates anything on the answer, and a denial is simply passed through.
/// Attribution for deniers degrades to SKAdNetwork postbacks — that path
/// needs no consent and no IDFA.
class TrackingHelper {
  TrackingHelper._();

  static bool _requestedThisSession = false;

  /// Called once from the dashboard after the first frame. On Android and
  /// web this is a no-op. Never throws; tracking must never break the app.
  static Future<void> requestOnce() async {
    if (!GetPlatform.isIOS || _requestedThisSession) return;
    _requestedThisSession = true;
    try {
      TrackingStatus status =
          await AppTrackingTransparency.trackingAuthorizationStatus;

      if (status == TrackingStatus.notDetermined) {
        // Small pause so the dialog doesn't collide with the home screen's
        // entry animation (or a deep-link push happening this same frame).
        await Future.delayed(const Duration(milliseconds: 1200));
        status = await AppTrackingTransparency.requestTrackingAuthorization();
        AnalyticsHelper.log('att_prompt_answered', {'status': status.name});
      }

      await _syncFacebookSdk(status);
    } catch (e, s) {
      // ATT drives ad attribution. A failure here silently degrades campaign
      // measurement, which is exactly the kind of thing nobody notices.
      swallow('ATT prompt / Facebook SDK sync', e, s, true);
    }
  }

  /// The FB SDK checks ATT itself, but only at its own init moments; after
  /// the dialog is answered mid-session the SDK must be told explicitly or
  /// events keep flowing unattributed until next launch.
  static Future<void> _syncFacebookSdk(TrackingStatus status) async {
    try {
      final bool authorized = status == TrackingStatus.authorized;
      await FacebookAppEvents().setAdvertiserTracking(enabled: authorized);
      if (Get.isRegistered<ApiClient>()) {
        // The backend forwards this with its Conversions API events.
        Get.find<ApiClient>().updateAttHeader(authorized);
      }
    } catch (e, s) {
      swallow('advertiser-tracking flag propagation', e, s, true);
    }
  }
}
