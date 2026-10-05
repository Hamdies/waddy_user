import 'package:get/get.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/search/domain/models/global_search_model.dart';
import 'package:waddy_app/features/search/domain/models/popular_categories_model.dart';
import 'package:waddy_app/features/search/domain/models/search_suggestion_model.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/features/search/domain/repositories/search_repository_interface.dart';
import 'package:waddy_app/features/search/domain/services/search_service_interface.dart';
import 'package:waddy_app/helper/date_converter.dart';

class SearchService implements SearchServiceInterface {
  final SearchRepositoryInterface searchRepositoryInterface;
  SearchService({required this.searchRepositoryInterface});

  @override
  Future<Response> getSearchData(
    String? query,
    bool isStore, {
    String? sortBy,
  }) async {
    return await searchRepositoryInterface.getList(
      query: query,
      isStore: isStore,
      sortBy: sortBy,
    );
  }

  @override
  Future<List<Item>?> getSuggestedItems() async {
    return await searchRepositoryInterface.getList(isSuggestedItems: true);
  }

  @override
  Future<bool> saveSearchHistory(List<String> searchHistories) async {
    return await searchRepositoryInterface.saveSearchHistory(searchHistories);
  }

  @override
  List<String> getSearchAddress() {
    return searchRepositoryInterface.getSearchAddress();
  }

  @override
  Future<bool> clearSearchHistory() async {
    return await searchRepositoryInterface.clearSearchHistory();
  }

  @override
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
  ) {
    List<Item>? searchItemList = [];
    if (allItemList == null) return searchItemList;
    searchItemList.addAll(allItemList);
    if (upperValue > 0) {
      searchItemList.removeWhere(
        (product) =>
            (product.price ?? 0) <= lowerValue ||
            (product.price ?? 0) > upperValue,
      );
    }
    if (rating != -1) {
      searchItemList.removeWhere(
        (product) => (product.avgRating ?? 0) < rating,
      );
    }
    if (!veg && nonVeg) {
      searchItemList.removeWhere((product) => product.veg == 1);
    }
    if (!nonVeg && veg) {
      searchItemList.removeWhere((product) => product.veg == 0);
    }
    if (isAvailableItems || isDiscountedItems) {
      if (isAvailableItems) {
        searchItemList.removeWhere(
          (product) =>
              !DateConverter.isAvailable(
                product.availableTimeStarts,
                product.availableTimeEnds,
              ),
        );
      }
      if (isDiscountedItems) {
        searchItemList.removeWhere((product) => product.discount == 0);
      }
    }
    if (sortIndex != -1) {
      switch (sortIndex) {
        case 0: // price_low_to_high
          searchItemList.sort((a, b) => (a.price ?? 0).compareTo(b.price ?? 0));
          break;
        case 1: // price_high_to_low
          searchItemList.sort((a, b) => (b.price ?? 0).compareTo(a.price ?? 0));
          break;
        case 2: // rating
          searchItemList.sort(
            (a, b) => (b.avgRating ?? 0).compareTo(a.avgRating ?? 0),
          );
          break;
        case 3: // popularity (ratingCount as proxy)
          searchItemList.sort(
            (a, b) => (b.ratingCount ?? 0).compareTo(a.ratingCount ?? 0),
          );
          break;
        case 4: // newest (higher id = newer)
          searchItemList.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
          break;
        case 5: // a_to_z
          searchItemList.sort(
            (a, b) => (a.name ?? '').toLowerCase().compareTo(
              (b.name ?? '').toLowerCase(),
            ),
          );
          break;
        case 6: // z_to_a
          searchItemList.sort(
            (a, b) => (b.name ?? '').toLowerCase().compareTo(
              (a.name ?? '').toLowerCase(),
            ),
          );
          break;
      }
    }
    return searchItemList;
  }

  @override
  List<Store>? sortStoreSearchList(
    List<Store>? allStoreList,
    int storeRating,
    bool storeVeg,
    bool storeNonVeg,
    bool isAvailableStore,
    bool isDiscountedStore,
    int storeSortIndex,
  ) {
    List<Store>? searchStoreList = [];
    if (allStoreList == null) return searchStoreList;
    searchStoreList.addAll(allStoreList);
    if (storeRating != -1) {
      searchStoreList.removeWhere(
        (store) => (store.avgRating ?? 0) < storeRating,
      );
    }
    if (!storeVeg && storeNonVeg) {
      searchStoreList.removeWhere((product) => product.nonVeg == 0);
    }
    if (!storeNonVeg && storeVeg) {
      searchStoreList.removeWhere((product) => product.veg == 0);
    }
    if (isAvailableStore || isDiscountedStore) {
      if (isAvailableStore) {
        searchStoreList.removeWhere(
          (store) => store.open == 0 || !(store.active ?? false),
        );
      }
      if (isDiscountedStore) {
        searchStoreList.removeWhere((store) => store.discount == null);
      }
    }
    if (storeSortIndex != -1) {
      switch (storeSortIndex) {
        case 0: // price_low_to_high (by minimum order)
          searchStoreList.sort(
            (a, b) => (a.minimumOrder ?? 0).compareTo(b.minimumOrder ?? 0),
          );
          break;
        case 1: // price_high_to_low (by minimum order)
          searchStoreList.sort(
            (a, b) => (b.minimumOrder ?? 0).compareTo(a.minimumOrder ?? 0),
          );
          break;
        case 2: // rating
          searchStoreList.sort(
            (a, b) => (b.avgRating ?? 0).compareTo(a.avgRating ?? 0),
          );
          break;
        case 3: // popularity (ratingCount as proxy)
          searchStoreList.sort(
            (a, b) => (b.ratingCount ?? 0).compareTo(a.ratingCount ?? 0),
          );
          break;
        case 4: // newest (higher id = newer)
          searchStoreList.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
          break;
        case 5: // a_to_z
          searchStoreList.sort(
            (a, b) => (a.name ?? '').toLowerCase().compareTo(
              (b.name ?? '').toLowerCase(),
            ),
          );
          break;
        case 6: // z_to_a
          searchStoreList.sort(
            (a, b) => (b.name ?? '').toLowerCase().compareTo(
              (a.name ?? '').toLowerCase(),
            ),
          );
          break;
      }
    }
    return searchStoreList;
  }

  @override
  Future<SearchSuggestionModel?> getSearchSuggestions(String searchText) async {
    return await searchRepositoryInterface.getSearchSuggestions(searchText);
  }

  @override
  Future<List<PopularCategoryModel?>?> getPopularCategories() async {
    return await searchRepositoryInterface.getPopularCategories();
  }

  @override
  Future<List<GlobalSearchStore>?> getGlobalSearch(String query) async {
    return await searchRepositoryInterface.getGlobalSearch(query);
  }
}
