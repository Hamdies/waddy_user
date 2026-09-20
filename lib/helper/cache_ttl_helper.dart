import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Freshness stamps for the locally cached API responses.
///
/// These used to live in a plain static map, which meant they were empty on
/// every cold start: [isStale] always reported stale, so the "serve local
/// first" branch never ran on launch and the app went to the network for
/// everything, every time. The drift cache was doing the work of storing
/// responses that nothing was allowed to read.
///
/// Stamps now persist, so a customer reopening the app inside the TTL window
/// sees their last home screen immediately instead of a shimmer.
class CacheTtlHelper {
  CacheTtlHelper._();

  static final Map<String, DateTime> _timestamps = <String, DateTime>{};

  static const String _prefix = 'cache_ttl_';

  static const Duration defaultTtl = Duration(minutes: 10);
  static const Duration groceryTtl = Duration(minutes: 5);

  /// SharedPreferences is registered in `di.init()` before any of this runs in
  /// the app, but unit tests exercise controllers without a GetX container.
  /// Returning null there degrades to the old in-memory behaviour rather than
  /// throwing.
  static SharedPreferences? get _prefs {
    if (!Get.isRegistered<SharedPreferences>()) return null;
    return Get.find<SharedPreferences>();
  }

  static void markFresh(String key) {
    final DateTime now = DateTime.now();
    _timestamps[key] = now;
    // Fire and forget: a lost write only costs one extra fetch next launch.
    _prefs?.setInt('$_prefix$key', now.millisecondsSinceEpoch);
  }

  static bool isStale(String key, {Duration? ttl}) {
    DateTime? timestamp = _timestamps[key];

    if (timestamp == null) {
      final int? stored = _prefs?.getInt('$_prefix$key');
      if (stored != null) {
        timestamp = DateTime.fromMillisecondsSinceEpoch(stored);
        // Promote into memory so the rest of the session skips the disk read.
        _timestamps[key] = timestamp;
      }
    }

    if (timestamp == null) return true;
    return DateTime.now().difference(timestamp) > (ttl ?? defaultTtl);
  }

  static void invalidate(String key) {
    _timestamps.remove(key);
    _prefs?.remove('$_prefix$key');
  }

  static void invalidateAll() {
    _timestamps.clear();
    final SharedPreferences? prefs = _prefs;
    if (prefs == null) return;
    for (final String key in prefs.getKeys().toList()) {
      if (key.startsWith(_prefix)) {
        prefs.remove(key);
      }
    }
  }
}
