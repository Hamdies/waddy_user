import 'package:waddy_app/common/enums/data_source_enum.dart';
import 'package:waddy_app/features/home/domain/models/advertisement_model.dart';

abstract class AdvertisementServiceInterface {
  Future<List<AdvertisementModel>?> getAdvertisementList(DataSourceEnum source);
}