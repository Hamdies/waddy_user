import 'package:waddy_app/common/enums/data_source_enum.dart';
import 'package:waddy_app/interfaces/repository_interface.dart';

abstract class CuisineRepositoryInterface implements RepositoryInterface {
  @override
  Future getList({int? offset, DataSourceEnum? source});
}
