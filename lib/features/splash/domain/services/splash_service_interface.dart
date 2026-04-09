import 'package:get/get.dart';
import 'package:waddy_app/common/enums/data_source_enum.dart';
import 'package:waddy_app/common/models/config_model.dart';
import 'package:waddy_app/common/models/response_model.dart';
import 'package:waddy_app/features/splash/domain/models/landing_model.dart';
import 'package:waddy_app/common/models/module_model.dart';

abstract class SplashServiceInterface {
  Future<Response> getConfigData({required DataSourceEnum source});
  ConfigModel? prepareConfigData(Response response);
  Future<LandingModel?> getLandingPageData({required DataSourceEnum source});
  Future<ModuleModel?> initSharedData();
  void disableIntro();
  bool? showIntro();
  Future<void> setStoreCategory(int storeCategoryID);
  Future<List<ModuleModel>?> getModules({Map<String, String>? headers, required DataSourceEnum source});
  Future<void> setModule(ModuleModel? module);
  Future<ModuleModel?> setCacheModule(ModuleModel? module);
  ModuleModel? getCacheModule();
  ModuleModel? getModule();
  Future<ResponseModel> subscribeEmail(String email);
  bool getSavedCookiesData();
  Future<void> saveCookiesData(bool data);
  void cookiesStatusChange(String? data);
  bool getAcceptCookiesStatus(String data);
  bool getSuggestedLocationStatus();
  Future<void> saveSuggestedLocationStatus(bool data);
  bool getReferBottomSheetStatus();
  Future<void> saveReferBottomSheetStatus(bool data);
  bool getWelcomeLetterShownStatus();
  Future<void> saveWelcomeLetterShownStatus(bool data);
}