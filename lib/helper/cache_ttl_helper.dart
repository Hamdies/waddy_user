class CacheTtlHelper {
  static final Map<String, DateTime> _timestamps = {};

  static const Duration defaultTtl = Duration(minutes: 10);
  static const Duration groceryTtl = Duration(minutes: 5);

  static void markFresh(String key) {
    _timestamps[key] = DateTime.now();
  }

  static bool isStale(String key, {Duration? ttl}) {
    final timestamp = _timestamps[key];
    if (timestamp == null) return true;
    return DateTime.now().difference(timestamp) > (ttl ?? defaultTtl);
  }

  static void invalidate(String key) {
    _timestamps.remove(key);
  }

  static void invalidateAll() {
    _timestamps.clear();
  }
}
