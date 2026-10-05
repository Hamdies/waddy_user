import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/store/domain/models/buy_again_line.dart';
import 'package:waddy_app/features/category/domain/models/category_model.dart';
import 'package:waddy_app/common/enums/data_source_enum.dart';
import 'package:waddy_app/interfaces/repository_interface.dart';

abstract class StoreRepositoryInterface extends RepositoryInterface {
  @override
  Future getList({
    int? offset,
    bool isStoreList = false,
    String? filterBy,
    bool isPopularStoreList = false,
    String? type,
    bool isLatestStoreList = false,
    bool isFeaturedStoreList = false,
    bool isVisitAgainStoreList = false,
    bool isStoreRecommendedItemList = false,
    int? storeId,
    bool isStoreBannerList = false,
    bool isRecommendedStoreList = false,
    bool isTopOfferStoreList = false,
    DataSourceEnum? source,
    String extraQuery = '',
  });
  Future<dynamic> getStoreDetails(
    String storeID,
    bool fromCart,
    String slug,
    String languageCode,
    int? moduleId,
  );
  Future<dynamic> getStoreItemList({
    int? storeID,
    required int offset,
    int? categoryID,
    String? type,
    List<String>? filter,
    int? rating,
    double? lowerValue,
    double? upperValue,
  });
  Future<dynamic> getStoreSearchItemList(
    String searchText,
    String? storeID,
    int offset,
    String type,
    int? categoryID,
  );
  Future<dynamic> getCartStoreSuggestedItemList(
    int? storeId,
    String languageCode,
    int? moduleId,
  );
  Future<dynamic> getSimilarStoreList(
    int? storeId, {
    int offset = 1,
    int limit = 10,
  });
  Future<dynamic> getDashboardRailStoreList({
    required int moduleId,
    required bool mostOrdered,
    int limit = 6,
    DataSourceEnum source,
  });
  Future<List<CategoryModel>?> getStoreSubCategories(
    int? storeId,
    int? categoryId,
  );
  Future<dynamic> getStoreBundleList(
    int? storeId, {
    int offset = 1,
    int limit = 10,
  });
  Future<({int orderCount, List<BuyAgainLine> lines})?> getBuyAgainItems(
    int storeId,
  );

  /// Items other customers bought in the same orders as [itemId]; empty when
  /// there is no repeated pairing. Null on any failure.
  Future<List<Item>?> getPairedItems(int itemId);
}
