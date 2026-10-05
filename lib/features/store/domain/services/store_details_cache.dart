import 'package:waddy_app/features/store/domain/models/store_model.dart';

/// Store details, fetched once and shared by everything that asks (ST-10).
///
/// The store page, the cart screen, checkout and the item sheet all want the
/// same store, and each used to fetch it or borrow it from
/// `StoreController.store` — a field that held whichever store page was
/// opened last, so borrowing was only safe behind an id check, and a fetch
/// already in flight for the page was fetched again by the next caller.
///
/// Callers say how old a store they can accept ([get]'s `maxAge`): the store
/// page wants it near-live because it shows open/closed, the item sheet only
/// wants a logo. A fetch in flight is joined by every caller regardless —
/// it is by definition the freshest copy there will be.
///
/// Keys are built by the caller ([keyFor]) and carry everything that changes
/// the response: the id, the language (names are localised), and the saved
/// address (the backend computes `open` and distance from it).
class StoreDetailsCache {
  StoreDetailsCache({
    this.ttl = const Duration(minutes: 5),
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  /// The oldest entry [peek] and a default [get] will hand out.
  final Duration ttl;
  final DateTime Function() _now;

  final Map<String, _Entry> _entries = {};
  final Map<String, Future<Store?>> _inFlight = {};

  static String keyFor(
    int storeId, {
    required String languageCode,
    String? latitude,
    String? longitude,
  }) => '$storeId|$languageCode|${latitude ?? ''},${longitude ?? ''}';

  /// The cached store if it is younger than [ttl]; never fetches.
  Store? peek(String key) => _fresh(key, ttl);

  /// The store for [key], from the cache when an entry is younger than
  /// [maxAge] (default [ttl]), otherwise from [fetch].
  ///
  /// A failed fetch (null) is not cached and does not evict an older entry:
  /// the next caller tries again.
  Future<Store?> get(
    String key,
    Future<Store?> Function() fetch, {
    Duration? maxAge,
  }) {
    final Store? hit = _fresh(key, maxAge ?? ttl);
    if (hit != null) return Future<Store?>.value(hit);

    final Future<Store?>? joining = _inFlight[key];
    if (joining != null) return joining;

    late final Future<Store?> request;
    request = fetch()
        .then((Store? store) {
          if (store != null) put(key, store);
          return store;
        })
        .whenComplete(() {
          if (identical(_inFlight[key], request)) _inFlight.remove(key);
        });
    _inFlight[key] = request;
    return request;
  }

  void put(String key, Store store) {
    _entries[key] = _Entry(store, _now());
  }

  void clear() {
    _entries.clear();
    _inFlight.clear();
  }

  Store? _fresh(String key, Duration maxAge) {
    final _Entry? entry = _entries[key];
    if (entry == null) return null;
    if (_now().difference(entry.at) > maxAge) return null;
    return entry.store;
  }
}

class _Entry {
  _Entry(this.store, this.at);
  final Store store;
  final DateTime at;
}
