import 'package:waddy_app/common/enums/data_source_enum.dart';
import 'package:waddy_app/common/models/module_model.dart';
import 'package:waddy_app/interfaces/repository_interface.dart';

abstract class SplashRepositoryInterface extends RepositoryInterface {
  Future<dynamic> getConfigData({required DataSourceEnum source});
  Future<dynamic> getLandingPageData({required DataSourceEnum source});
  Future<void> initSharedData();
  void disableIntro();
  bool? showIntro();
  Future<void> setStoreCategory(int storeCategoryID);
  Future<dynamic> getModules({
    Map<String, String>? headers,
    required DataSourceEnum source,
  });
  void updateModuleHeader(ModuleModel? module);
  Future<ModuleModel?> setCacheModule(ModuleModel? module);
  ModuleModel? getCacheModule();
  Future<dynamic> subscribeEmail(String email);
  bool getSuggestedLocationStatus();
  Future<void> saveSuggestedLocationStatus(bool data);
  bool getReferBottomSheetStatus();
  Future<void> saveReferBottomSheetStatus(bool data);
  bool getWelcomeLetterShownStatus();
  Future<void> saveWelcomeLetterShownStatus(bool data);
}
