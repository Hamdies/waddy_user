import 'package:flutter_test/flutter_test.dart';
import 'package:waddy_app/common/enums/data_source_enum.dart';
import 'package:waddy_app/features/store/controllers/store_list_controller.dart';
import 'package:waddy_app/features/location/domain/models/zone_response_model.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/features/store/domain/services/store_service_interface.dart';

/// Concurrent callers of the featured list share one fetch. The guard that
/// does that holds the in-flight future in a field — so the local leg must
/// reach the client leg WITHOUT going back through the public wrapper, or it
/// returns the very future it is inside and awaits itself. The request never
/// goes out and the rails shimmer forever.
void main() {
  test('the local leg reaches the network instead of awaiting itself', () async {
    final service = _RecordingStoreService();
    final controller = StoreListController(storeServiceInterface: service);

    // A real deadlock never completes, so a timeout is the assertion.
    await controller
        .getFeaturedStoreList()
        .timeout(
          const Duration(seconds: 5),
          onTimeout:
              () => fail(
                'getFeaturedStoreList deadlocked: the local leg awaited its '
                'own in-flight future instead of calling the client leg',
              ),
        );

    expect(
      service.requestedSources,
      containsAllInOrder(<DataSourceEnum>[
        DataSourceEnum.local,
        DataSourceEnum.client,
      ]),
      reason: 'the cache read must be followed by a real network read',
    );
  });

  test('concurrent callers still share a single fetch', () async {
    final service = _RecordingStoreService();
    final controller = StoreListController(storeServiceInterface: service);

    await Future.wait(<Future<void>>[
      controller.getFeaturedStoreList(),
      controller.getFeaturedStoreList(),
      controller.getFeaturedStoreList(),
    ]).timeout(
      const Duration(seconds: 5),
      onTimeout: () => fail('coalesced callers deadlocked'),
    );

    // Three callers, one local + one client read — not three of each.
    expect(
      service.requestedSources
          .where((s) => s == DataSourceEnum.client)
          .length,
      1,
      reason: 'the whole point of the in-flight guard',
    );
  });
}

class _RecordingStoreService implements StoreServiceInterface {
  final List<DataSourceEnum> requestedSources = <DataSourceEnum>[];

  @override
  Future<List<Store>?> getFeaturedStoreList({
    required DataSourceEnum source,
  }) async {
    requestedSources.add(source);
    return <Store>[];
  }

  @override
  List<Modules> moduleList() => <Modules>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
