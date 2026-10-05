import 'package:get/get.dart';
import 'package:waddy_app/common/enums/data_source_enum.dart';
import 'package:waddy_app/features/cuisine/domain/models/cuisine_model.dart';
import 'package:waddy_app/features/cuisine/domain/services/cuisine_service_interface.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/helper/cache_ttl_helper.dart';

/// Store-level classifications, scoped to the active module: cuisines on the
/// food home (Pizza, Burgers), main categories on the grocery home
/// (Supermarkets, Roasteries). Not to be confused with item categories, which
/// are the aisles *inside* a store.
class CuisineController extends GetxController implements GetxService {
  final CuisineServiceInterface cuisineServiceInterface;
  CuisineController({required this.cuisineServiceInterface});

  /// Per module: one module's freshness says nothing about the other's.
  String get _ttlKey => 'cuisine_list_${_currentModuleId ?? 'none'}';

  int? get _currentModuleId => Get.find<SplashController>().module?.id;

  /// Module the held list was fetched for. Food's list is the wrong answer on
  /// the grocery home, however fresh it is.
  int? _listModuleId;

  List<CuisineModel>? _cuisineList;
  List<CuisineModel>? get cuisineList => _cuisineList;

  /// Set once a fetch has come back, however it went. The strip shimmers while
  /// this is false and null; without it an empty list is indistinguishable
  /// from a list still loading.
  bool _loaded = false;
  bool get loaded => _loaded;

  /// Food home and the home screen's loadData both ask in the same frame.
  Future<void>? _fetchInFlight;

  Future<void> getCuisineList(
    bool reload, {
    DataSourceEnum dataSource = DataSourceEnum.local,
  }) {
    if (_cuisineList != null && _listModuleId != _currentModuleId) {
      // Drop the other module's list before anything renders it, so the strip
      // shimmers rather than flashing "Pizza" on the grocery home.
      _cuisineList = null;
      _loaded = false;
      reload = true;
    }
    if (!reload && _fetchInFlight != null) return _fetchInFlight!;
    late final Future<void> fetch;
    fetch = _fetch(reload, dataSource).whenComplete(() {
      if (identical(_fetchInFlight, fetch)) _fetchInFlight = null;
    });
    _fetchInFlight = fetch;
    return fetch;
  }

  Future<void> _fetch(bool reload, DataSourceEnum dataSource) async {
    if (_cuisineList != null && !reload) return;
    final int? moduleId = _currentModuleId;

    if (dataSource == DataSourceEnum.local && CacheTtlHelper.isStale(_ttlKey)) {
      dataSource = DataSourceEnum.client;
    }

    List<CuisineModel>? cuisineList;
    if (dataSource == DataSourceEnum.local) {
      cuisineList = await cuisineServiceInterface.getCuisineList(
        source: DataSourceEnum.local,
      );
      // A fresh stamp is not proof the cached row exists — the same trap that
      // left the category strip shimmering forever. Fall through to the
      // network when the local read comes back empty.
      if (cuisineList == null) {
        dataSource = DataSourceEnum.client;
      }
    }

    if (dataSource == DataSourceEnum.client) {
      cuisineList = await cuisineServiceInterface.getCuisineList(
        source: DataSourceEnum.client,
      );
      if (cuisineList != null) CacheTtlHelper.markFresh(_ttlKey);
    }

    if (cuisineList != null) {
      _cuisineList = cuisineList;
      _listModuleId = moduleId;
    }
    _loaded = true;
    update();
  }

  /// Name lookup for the restaurant-card subtitle, which only has ids.
  ///
  /// [limit] caps the result at its first N resolved names. The cap belongs
  /// here rather than on the joined string: a caller that trims the output of
  /// `join(', ')` has to split it again, and that round-trip corrupts any
  /// cuisine whose own name contains a comma.
  String namesFor(List<int>? ids, {int? limit}) {
    if (ids == null || ids.isEmpty || _cuisineList == null) return '';
    final List<String> names = [];
    for (final int id in ids) {
      if (limit != null && names.length >= limit) break;
      for (final CuisineModel cuisine in _cuisineList!) {
        if (cuisine.id == id && cuisine.name != null) {
          names.add(cuisine.name!);
          break;
        }
      }
    }
    return names.join(', ');
  }
}
