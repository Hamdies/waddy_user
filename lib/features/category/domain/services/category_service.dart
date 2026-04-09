import 'package:get/get.dart';
import 'package:waddy_app/common/enums/data_source_enum.dart';
import 'package:waddy_app/features/category/domain/models/category_model.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/features/category/domain/reposotories/category_repository_interface.dart';
import 'package:waddy_app/features/category/domain/services/category_service_interface.dart';

class CategoryService implements CategoryServiceInterface {
  final CategoryRepositoryInterface categoryRepositoryInterface;
  CategoryService({required this.categoryRepositoryInterface});

  @override
  Future<List<CategoryModel>?> getCategoryList(bool allCategory, {DataSourceEnum? source}) async {
    return await categoryRepositoryInterface.getList(allCategory: allCategory, categoryList: true, source: source);
  }

  @override
  Future<List<CategoryModel>?> getSubCategoryList(String? parentID) async {
    return await categoryRepositoryInterface.getList(id: parentID, subCategoryList: true);
  }

  @override
  Future<ItemModel?> getCategoryItemList(String? categoryID, int offset, String type) async {
    return await categoryRepositoryInterface.getList(id: categoryID, offset: offset, type: type, categoryItemList: true);
  }

  @override
  Future<StoreModel?> getCategoryStoreList(String? categoryID, int offset, String type) async {
    return await categoryRepositoryInterface.getList(id: categoryID, offset: offset, type: type, categoryStoreList: true);
  }

  @override
  Future<Response> getSearchData(String? query, String? categoryID, bool isStore, String type) async {
    return await categoryRepositoryInterface.getSearchData(query, categoryID, isStore, type);
  }

  @override
  Future<bool> saveUserInterests(List<int?> interests) async {
    return await categoryRepositoryInterface.saveUserInterests(interests);
  }

}