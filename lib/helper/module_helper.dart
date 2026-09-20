import 'package:get/get.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/common/models/module_model.dart';
import 'package:waddy_app/common/models/config_model.dart';

class ModuleHelper {
  static ModuleModel? getModule() {
    return Get.find<SplashController>().module;
  }

  static ModuleModel? getCacheModule() {
    return Get.find<SplashController>().cacheModule;
  }

  /// The module id a request should carry: the module the user is in, or —
  /// from the module-less dashboard — the last one that was in play.
  ///
  /// This expression was written out by hand wherever it was needed, most
  /// often as three arguments handed down four layers so a repository could
  /// re-derive it. It is one question with one answer.
  static int? currentModuleId() => getModule()?.id ?? getCacheModule()?.id;

  static Module getModuleConfig(String? moduleType) {
    return Get.find<SplashController>().getModuleConfig(moduleType);
  }
}
