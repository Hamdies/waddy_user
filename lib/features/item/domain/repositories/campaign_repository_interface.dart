import 'package:waddy_app/common/enums/data_source_enum.dart';
import 'package:waddy_app/interfaces/repository_interface.dart';

abstract class CampaignRepositoryInterface implements RepositoryInterface {
  @override
  Future getList({
    int? offset,
    bool isBasicCampaign = false,
    bool isItemCampaign = false,
    DataSourceEnum source,
  });
}
