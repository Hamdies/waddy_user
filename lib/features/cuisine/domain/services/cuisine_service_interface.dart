import 'package:waddy_app/common/enums/data_source_enum.dart';
import 'package:waddy_app/features/cuisine/domain/models/cuisine_model.dart';

abstract class CuisineServiceInterface {
  Future<List<CuisineModel>?> getCuisineList({DataSourceEnum? source});
}
