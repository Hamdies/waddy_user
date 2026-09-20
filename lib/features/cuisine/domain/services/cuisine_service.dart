import 'package:waddy_app/common/enums/data_source_enum.dart';
import 'package:waddy_app/features/cuisine/domain/models/cuisine_model.dart';
import 'package:waddy_app/features/cuisine/domain/repositories/cuisine_repository_interface.dart';
import 'package:waddy_app/features/cuisine/domain/services/cuisine_service_interface.dart';

class CuisineService implements CuisineServiceInterface {
  final CuisineRepositoryInterface cuisineRepositoryInterface;
  CuisineService({required this.cuisineRepositoryInterface});

  @override
  Future<List<CuisineModel>?> getCuisineList({DataSourceEnum? source}) async {
    return await cuisineRepositoryInterface.getList(source: source);
  }
}
