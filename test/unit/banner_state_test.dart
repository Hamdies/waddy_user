import 'package:flutter_test/flutter_test.dart';
import 'package:waddy_app/common/enums/data_source_enum.dart';
import 'package:waddy_app/features/banner/controllers/banner_controller.dart';
import 'package:waddy_app/features/banner/domain/models/banner_model.dart';
import 'package:waddy_app/features/banner/domain/services/banner_service_interface.dart';

/// BannerView renders three different things from two nullable lists:
/// null is "still loading" (a shimmer), empty is "no banner" (collapsed), and
/// non-empty is the carousel. Nothing but the controller decides which, so a
/// fetch that returned null used to leave the shimmer running for the life of
/// the screen — the bug these pin.
void main() {
  group('banner state always resolves', () {
    test('a failed fetch renders empty, not loading', () async {
      final controller = BannerController(
        bannerServiceInterface: _NullBannerService(),
      );

      expect(
        controller.bannerImageList,
        isNull,
        reason: 'starts as "not asked yet"',
      );

      await controller.getBannerList(true);

      expect(
        controller.bannerImageList,
        isEmpty,
        reason: 'a failed fetch must collapse the section, not shimmer',
      );
    });

    test('a bare [] response does not throw and renders empty', () async {
      // The backend's own error path returns `[]` with status 200, which
      // parses into a model whose campaigns and banners are both null. The
      // bangs that used to read them threw inside the fetch, and the caller
      // swallowed it — leaving the lists null and the shimmer running.
      final controller = BannerController(
        bannerServiceInterface: _EmptyJsonBannerService(),
      );

      await controller.getBannerList(true);

      expect(controller.bannerImageList, isEmpty);
      expect(controller.bannerDataList, isEmpty);
      expect(controller.bannerVariantsList, isEmpty);
    });

    test('clearBanner drops all three lists together', () async {
      final controller = BannerController(
        bannerServiceInterface: _EmptyJsonBannerService(),
      );
      await controller.getBannerList(true);
      expect(controller.bannerImageList, isNotNull);

      controller.clearBanner();

      // All three, or a module switch leaves the previous module's data and
      // variant lists paired with the next module's images.
      expect(controller.bannerImageList, isNull);
      expect(controller.bannerDataList, isNull);
      expect(controller.bannerVariantsList, isNull);
    });
  });
}

/// Every fetch fails, the way a non-200 does once the repository drops it.
class _NullBannerService implements BannerServiceInterface {
  @override
  Future<BannerModel?> getBannerList({required DataSourceEnum source}) async =>
      null;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// The backend's `catch` path: HTTP 200 carrying a bare `[]`.
class _EmptyJsonBannerService implements BannerServiceInterface {
  @override
  Future<BannerModel?> getBannerList({required DataSourceEnum source}) async =>
      BannerModel.fromJson(<String, dynamic>{});

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
