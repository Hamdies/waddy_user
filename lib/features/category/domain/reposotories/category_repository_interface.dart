import 'package:waddy_app/common/enums/data_source_enum.dart';
import 'package:waddy_app/interfaces/repository_interface.dart';

abstract class CategoryRepositoryInterface implements RepositoryInterface {
  @override
  Future getList({
    int? offset,
    bool categoryList = false,
    bool subCategoryList = false,
    bool categoryItemList = false,
    bool categoryStoreList = false,
    bool? allCategory,
    String? id,
    String? type,
    DataSourceEnum? source,
  });

  /// Categories of one specific module, regardless of which module (if any)
  /// is currently selected — the aggregated dashboard has none.
  Future<dynamic> getModuleCategoryList(int moduleId);
  Future<dynamic> getSearchData(
    String? query,
    String? categoryID,
    bool isStore,
    String type,
  );
  Future<dynamic> saveUserInterests(List<int?> interests);
}
