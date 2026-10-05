import 'package:waddy_app/features/search/domain/models/global_search_model.dart';
import 'package:waddy_app/features/search/domain/models/popular_categories_model.dart';
import 'package:waddy_app/features/search/domain/models/search_suggestion_model.dart';
import 'package:waddy_app/interfaces/repository_interface.dart';

abstract class SearchRepositoryInterface extends RepositoryInterface {
  Future<bool> saveSearchHistory(List<String> searchHistories);
  List<String> getSearchAddress();
  Future<bool> clearSearchHistory();
  @override
  Future getList({
    int? offset,
    String? query,
    bool? isStore,
    bool isSuggestedItems = false,
    String? sortBy,
  });
  Future<SearchSuggestionModel?> getSearchSuggestions(String searchText);
  Future<List<PopularCategoryModel?>?> getPopularCategories();

  /// Stores of every module that match [query], each with its matching items.
  /// Null when the request failed — distinct from an empty (no matches) list.
  Future<List<GlobalSearchStore>?> getGlobalSearch(String query);
}
