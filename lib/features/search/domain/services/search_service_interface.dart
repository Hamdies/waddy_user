import 'package:get/get_connect/http/src/response/response.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/search/domain/models/global_search_model.dart';
import 'package:waddy_app/features/search/domain/models/popular_categories_model.dart';
import 'package:waddy_app/features/search/domain/models/search_suggestion_model.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';

abstract class SearchServiceInterface {
  Future<Response> getSearchData(String? query, bool isStore, {String? sortBy});
  Future<List<Item>?> getSuggestedItems();
  Future<bool> saveSearchHistory(List<String> searchHistories);
  List<String> getSearchAddress();
  Future<bool> clearSearchHistory();
  List<Item>? sortItemSearchList(
    List<Item>? allItemList,
    double upperValue,
    double lowerValue,
    int rating,
    bool veg,
    bool nonVeg,
    bool isAvailableItems,
    bool isDiscountedItems,
    int sortIndex,
  );
  List<Store>? sortStoreSearchList(
    List<Store>? allStoreList,
    int storeRating,
    bool storeVeg,
    bool storeNonVeg,
    bool isAvailableStore,
    bool isDiscountedStore,
    int storeSortIndex,
  );
  Future<SearchSuggestionModel?> getSearchSuggestions(String searchText);
  Future<List<PopularCategoryModel?>?> getPopularCategories();
  Future<List<GlobalSearchStore>?> getGlobalSearch(String query);
}
