import 'package:get/get.dart';
import 'package:waddy_app/common/enums/data_source_enum.dart';
import 'package:waddy_app/common/models/config_model.dart';
import 'package:waddy_app/common/models/response_model.dart';
import 'package:waddy_app/features/splash/domain/models/landing_model.dart';
import 'package:waddy_app/common/models/module_model.dart';
import 'package:waddy_app/features/splash/domain/repositories/splash_repository_interface.dart';
import 'package:waddy_app/features/splash/domain/services/splash_service_interface.dart';

class SplashService implements SplashServiceInterface {
  final SplashRepositoryInterface splashRepositoryInterface;
  SplashService({required this.splashRepositoryInterface});

  @override
  Future<Response> getConfigData({required DataSourceEnum source}) async {
    Response response = await splashRepositoryInterface.getConfigData(
      source: source,
    );
    return response;
  }

  @override
  ConfigModel? prepareConfigData(Response response) {
    ConfigModel? configModel;
    if (response.statusCode == 200) {
      configModel = ConfigModel.fromJson(response.body);
    }
    return configModel;
  }

  @override
  Future<LandingModel?> getLandingPageData({
    required DataSourceEnum source,
  }) async {
    return await splashRepositoryInterface.getLandingPageData(source: source);
  }

  @override
  Future<void> initSharedData() async {
    return await splashRepositoryInterface.initSharedData();
  }

  @override
  void disableIntro() {
    splashRepositoryInterface.disableIntro();
  }

  @override
  bool? showIntro() {
    return splashRepositoryInterface.showIntro();
  }

  @override
  Future<void> setStoreCategory(int storeCategoryID) async {
    return await splashRepositoryInterface.setStoreCategory(storeCategoryID);
  }

  @override
  Future<List<ModuleModel>?> getModules({
    Map<String, String>? headers,
    required DataSourceEnum source,
  }) async {
    return await splashRepositoryInterface.getModules(
      headers: headers,
      source: source,
    );
  }

  @override
  void updateModuleHeader(ModuleModel? module) {
    splashRepositoryInterface.updateModuleHeader(module);
  }

  @override
  Future<ModuleModel?> setCacheModule(ModuleModel? module) async {
    return await splashRepositoryInterface.setCacheModule(module);
  }

  @override
  ModuleModel? getCacheModule() {
    return splashRepositoryInterface.getCacheModule();
  }

  @override
  @override
  Future<ResponseModel> subscribeEmail(String email) async {
    return await splashRepositoryInterface.subscribeEmail(email);
  }

  @override
  bool getSuggestedLocationStatus() {
    return splashRepositoryInterface.getSuggestedLocationStatus();
  }

  @override
  Future<void> saveSuggestedLocationStatus(bool data) async {
    return await splashRepositoryInterface.saveSuggestedLocationStatus(data);
  }

  @override
  bool getReferBottomSheetStatus() {
    return splashRepositoryInterface.getReferBottomSheetStatus();
  }

  @override
  Future<void> saveReferBottomSheetStatus(bool data) async {
    return await splashRepositoryInterface.saveReferBottomSheetStatus(data);
  }

  @override
  bool getWelcomeLetterShownStatus() {
    return splashRepositoryInterface.getWelcomeLetterShownStatus();
  }

  @override
  Future<void> saveWelcomeLetterShownStatus(bool data) async {
    return await splashRepositoryInterface.saveWelcomeLetterShownStatus(data);
  }
}
