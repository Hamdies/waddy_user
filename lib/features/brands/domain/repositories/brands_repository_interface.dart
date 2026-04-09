import 'package:waddy_app/common/enums/data_source_enum.dart';
import 'package:waddy_app/features/brands/domain/models/brands_model.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/interfaces/repository_interface.dart';

abstract class BrandsRepositoryInterface extends RepositoryInterface {
  Future<ItemModel?> getBrandItemList({required int brandId, int? offset});
  Future<List<BrandModel>?> getBrandList({required DataSourceEnum source});
}