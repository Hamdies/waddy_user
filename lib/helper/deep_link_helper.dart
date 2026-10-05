import 'dart:async';
import 'package:waddy_app/util/swallow.dart';

import 'package:app_links/app_links.dart';
import 'package:get/get.dart';
import 'package:waddy_app/helper/analytics_helper.dart';
import 'package:waddy_app/helper/route_helper.dart';

/// Routes ad and share links into the app without ever outrunning entry flow.
///
/// A deep link NEVER navigates by itself: it is parsed into an internal GetX
/// route and stashed, and the dashboard consumes the stash on its first frame.
/// Splash routing (auth check, guest bootstrap, mandatory location gate)
/// therefore always finishes first, so zone context exists before any target
/// screen loads — the store API reads zoneId from the saved address, and the
/// out-of-zone gates live in the controllers the target screens already use.
///
/// Supported link shapes (https://waddyapp.com/... and waddy://...):
///   /store?id=5        /store/5
///   /item?id=7         /item/7         /item-details?id=7
///   /category?id=3&name=Pizza
///   /order/42          (the iOS Live Activity tap)
/// Anything unparseable is dropped: a deep link must never leave the user
/// somewhere worse than no deep link would have.
class DeepLinkHelper {
  DeepLinkHelper._();

  static final AppLinks _appLinks = AppLinks();
  static StreamSubscription<Uri>? _sub;

  static String? _pendingRoute;
  static DateTime? _stashedAt;
  static bool _homeMounted = false;

  /// A stash that was never consumed (e.g. a notification cold start routed
  /// elsewhere) must not fire minutes later when the user wanders home.
  static const Duration _maxPendingAge = Duration(minutes: 5);

  /// Called once in main() before runApp. Never throws.
  static Future<void> init() async {
    try {
      final Uri? initial = await _appLinks.getInitialLink();
      if (initial != null) {
        _stash(initial, mode: 'cold');
      }
      _sub ??= _appLinks.uriLinkStream.listen(_onWarmLink, onError: (_) {});
    } catch (e, s) {
      swallow('deep link listener setup', e, s, true);
    }
  }

  /// Link arriving while the app is running. If the entry flow has already
  /// landed the user on home once, context exists — navigate immediately.
  /// Otherwise stash it like a cold start.
  static void _onWarmLink(Uri uri) {
    if (_homeMounted) {
      final String? route = _parse(uri);
      if (route == null) return;
      AnalyticsHelper.log('deep_link_opened', {'mode': 'warm'});
      Get.toNamed(route);
    } else {
      _stash(uri, mode: 'stashed_warm');
    }
  }

  static void _stash(Uri uri, {required String mode}) {
    final String? route = _parse(uri);
    if (route == null) return;
    _pendingRoute = route;
    _stashedAt = DateTime.now();
    AnalyticsHelper.log('deep_link_stashed', {'mode': mode});
  }

  /// Dashboard calls this on its first frame — the single point every entry
  /// path (splash, guest bootstrap, location gate, manual picker) converges
  /// on. Pushes the target ON TOP of home so back lands on home.
  static void consumePending() {
    _homeMounted = true;
    final String? route = _pendingRoute;
    final DateTime? stashedAt = _stashedAt;
    _pendingRoute = null;
    _stashedAt = null;
    if (route == null || stashedAt == null) return;
    if (DateTime.now().difference(stashedAt) > _maxPendingAge) {
      AnalyticsHelper.log('deep_link_expired');
      return;
    }
    AnalyticsHelper.log('deep_link_opened', {'mode': 'cold'});
    Get.toNamed(route);
  }

  /// Notification cold starts own the routing; a deep link stashed in the
  /// same launch would fire unexpectedly later.
  static void clearPending() {
    _pendingRoute = null;
    _stashedAt = null;
  }

  static String? _parse(Uri uri) {
    // waddy://store/5 puts "store" in host; https puts it in the path.
    final List<String> segments =
        uri.scheme == 'waddy'
            ? <String>[uri.host, ...uri.pathSegments]
            : List<String>.from(uri.pathSegments);
    if (segments.isEmpty) return null;

    int? id = int.tryParse(uri.queryParameters['id'] ?? '');
    id ??= segments.length > 1 ? int.tryParse(segments[1]) : null;

    switch (segments[0]) {
      case 'store':
        if (id == null) return null;
        return RouteHelper.getStoreRoute(id: id, page: 'deep-link');
      case 'item':
      case 'item-details':
        if (id == null) return null;
        return RouteHelper.getItemDetailsRoute(id, false);
      case 'order':
        if (id == null) return null;
        return RouteHelper.getOrderDetailsRoute(id);
      case 'category':
      case 'category-item':
        if (id == null) return null;
        return RouteHelper.getCategoryItemRoute(
          id,
          uri.queryParameters['name'] ?? '',
        );
      default:
        return null;
    }
  }
}
