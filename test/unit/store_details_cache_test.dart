import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/features/store/domain/services/store_details_cache.dart';

/// ST-10: one store fetch shared by the page, the cart, checkout and the item
/// sheet.
void main() {
  late DateTime now;
  late StoreDetailsCache cache;
  late int fetches;

  Future<Store?> fetchStore(int id) async {
    fetches++;
    return Store(id: id, name: 'store $id');
  }

  setUp(() {
    now = DateTime(2026, 9, 30, 12);
    cache = StoreDetailsCache(clock: () => now);
    fetches = 0;
  });

  test('a second caller inside the TTL is served from memory', () async {
    await cache.get('a', () => fetchStore(1));
    final Store? again = await cache.get('a', () => fetchStore(1));
    expect(again?.id, 1);
    expect(fetches, 1);
  });

  test('an entry older than the TTL is fetched again', () async {
    await cache.get('a', () => fetchStore(1));
    now = now.add(const Duration(minutes: 6));
    await cache.get('a', () => fetchStore(1));
    expect(fetches, 2);
  });

  test('a caller can demand a fresher copy than the TTL', () async {
    // The store page shows open/closed and accepts at most 30 s.
    await cache.get('a', () => fetchStore(1));
    now = now.add(const Duration(minutes: 1));
    await cache.get('a', () => fetchStore(1));
    expect(fetches, 1, reason: 'inside the 5-minute TTL');
    await cache.get(
      'a',
      () => fetchStore(1),
      maxAge: const Duration(seconds: 30),
    );
    expect(fetches, 2, reason: 'older than the 30 s the caller accepts');
  });

  test('concurrent callers share one request', () async {
    final Completer<Store?> gate = Completer<Store?>();
    int started = 0;
    Future<Store?> slow() {
      started++;
      return gate.future;
    }

    final Future<Store?> first = cache.get('a', slow);
    // Even a caller demanding a live copy joins: the fetch in flight is the
    // freshest there will be.
    final Future<Store?> second = cache.get('a', slow, maxAge: Duration.zero);
    gate.complete(Store(id: 1));
    expect((await first)?.id, 1);
    expect((await second)?.id, 1);
    expect(started, 1);
  });

  test('a failed fetch is not cached and does not evict a good entry', () async {
    await cache.get('a', () => fetchStore(1));
    now = now.add(const Duration(minutes: 1));
    final Store? failed = await cache.get(
      'a',
      () async => null,
      maxAge: Duration.zero,
    );
    expect(failed, isNull);
    expect(cache.peek('a')?.id, 1);
  });

  test('peek never fetches and respects the TTL', () async {
    expect(cache.peek('a'), isNull);
    await cache.get('a', () => fetchStore(1));
    expect(cache.peek('a')?.id, 1);
    now = now.add(const Duration(minutes: 6));
    expect(cache.peek('a'), isNull);
  });

  test('the key separates language and saved address', () {
    // Names are localised; `open` and distance are computed from the address.
    final String en = StoreDetailsCache.keyFor(
      1,
      languageCode: 'en',
      latitude: '29.9',
      longitude: '31.2',
    );
    expect(
      StoreDetailsCache.keyFor(
        1,
        languageCode: 'ar',
        latitude: '29.9',
        longitude: '31.2',
      ),
      isNot(en),
    );
    expect(
      StoreDetailsCache.keyFor(
        1,
        languageCode: 'en',
        latitude: '30.0',
        longitude: '31.2',
      ),
      isNot(en),
    );
  });
}
