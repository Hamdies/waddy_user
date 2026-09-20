import 'package:waddy_app/common/enums/data_source_enum.dart';
import 'package:waddy_app/features/home/domain/models/advertisement_model.dart';
import 'package:waddy_app/interfaces/repository_interface.dart';

abstract class AdvertisementRepositoryInterface extends RepositoryInterface {
  @override
  Future<List<AdvertisementModel>?> getList({
    int? offset,
    DataSourceEnum source = DataSourceEnum.client,
  });
}
