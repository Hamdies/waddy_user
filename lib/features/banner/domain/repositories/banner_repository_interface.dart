import 'package:waddy_app/common/enums/data_source_enum.dart';
import 'package:waddy_app/interfaces/repository_interface.dart';

abstract class BannerRepositoryInterface implements RepositoryInterface {
  @override
  Future getList({
    int? offset,
    bool isBanner = false,
    bool isFeaturedBanner = false,
    bool isParcelOtherBanner = false,
    bool isPromotionalBanner = false,
    DataSourceEnum? source,
  });
}
