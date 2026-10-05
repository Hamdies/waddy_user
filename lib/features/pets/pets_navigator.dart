import 'package:get/get.dart';
import 'package:waddy_app/common/models/module_model.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/helper/route_helper.dart';

/// The way into the Pets hub from outside the dashboard: a pet push, the
/// menu. Finds the Pets module by type (it has no fixed id) and enters it
/// the way a dashboard tile does.
class PetsNavigator {
  PetsNavigator._();

  /// The Pets module, or null when this zone isn't served one.
  static ModuleModel? petsModule() => Get.find<SplashController>().moduleList
      ?.firstWhereOrNull((m) => m.type == ModuleType.pets);

  /// Whether the Pets module is open in the current zone.
  static bool get available => petsModule() != null;

  /// Opens the hub. [switchTab] is false when the caller has just put the
  /// dashboard on screen itself (a cold start from a push).
  static Future<void> openHub({bool switchTab = true}) async {
    final SplashController splash = Get.find<SplashController>();
    if (splash.moduleList == null) await splash.getModules();
    final ModuleModel? module = petsModule();
    if (switchTab) RouteHelper.goToTab(RouteHelper.tabHome);
    if (module != null) await splash.enterModule(module);
  }
}
