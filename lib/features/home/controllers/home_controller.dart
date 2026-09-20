import 'dart:async';
import 'package:waddy_app/util/swallow.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/home/domain/models/cashback_model.dart';
import 'package:waddy_app/features/home/domain/services/home_service_interface.dart';
import 'package:waddy_app/features/item/controllers/item_controller.dart';

/// GetBuilder ids for the home feed's sections.
///
/// Keyed by what the user can *see* fail, not by endpoint: several calls feed
/// one rail, and a rail is the smallest thing the UI can put an error row in.
/// These double as `update([id])` targets so one section's failure repaints
/// that section and nothing else.
class HomeSection {
  const HomeSection._();

  static const String modules = 'home_modules';
  static const String battle = 'home_battle';
  static const String fastest = 'home_fastest';
  static const String grocery = 'home_grocery';
  static const String offers = 'home_offers';
  static const String recommended = 'home_recommended';
  static const String orderAgain = 'home_order_again';
  static const String zone = 'home_zone';

  /// Repainted whenever any section's failure state changes.
  static const String any = 'home_error';
}

class HomeController extends GetxController implements GetxService {
  final HomeServiceInterface homeServiceInterface;
  HomeController({required this.homeServiceInterface});

  // ── Section failure state ──────────────────────────────────────────────────
  // A Set, not a bool: on a partial failure only the sections that actually
  // failed may show an error row. A global flag would put one under every
  // empty section, including the ones that are legitimately empty.
  final Set<String> _failedSections = <String>{};
  Set<String> get failedSections => Set.unmodifiable(_failedSections);

  bool hasError(String section) => _failedSections.contains(section);
  bool get hasAnyError => _failedSections.isNotEmpty;

  /// Set.add/remove return whether the set changed, which is the guard for
  /// free — same shape as [setBottomNavVisibility] below.
  void recordError(String section) {
    if (_failedSections.add(section)) update([section, HomeSection.any]);
  }

  void clearError(String section) {
    if (_failedSections.remove(section)) update([section, HomeSection.any]);
  }

  void clearAllErrors() {
    if (_failedSections.isEmpty) return;
    _failedSections.clear();
    update([HomeSection.any]);
  }

  List<CashBackModel>? _cashBackOfferList;
  List<CashBackModel>? get cashBackOfferList => _cashBackOfferList;

  CashBackModel? _cashBackData;
  CashBackModel? get cashBackData => _cashBackData;

  bool _showFavButton = true;
  bool get showFavButton => _showFavButton;

  // Bottom nav bar visibility for scroll-hide behavior
  bool _isBottomNavVisible = true;
  bool get isBottomNavVisible => _isBottomNavVisible;

  Timer? _bottomNavTimer;

  // Ramadan celebration state
  // _showRamadanDecorations: whether to show the decorations overlay at all
  // _isRamadanLightsOn: whether the lights are currently lit (user tapped button)
  // _ramadanLightProgress: 0.0 to 1.0, controls sequential bulb lighting animation
  bool _showRamadanDecorations =
      false; // Controlled by backend ramadan_mode setting
  bool _isRamadanLightsOn = false; // Lights start OFF
  double _ramadanLightProgress = 0.0; // Animation progress

  bool get showRamadanDecorations => _showRamadanDecorations;
  bool get isRamadanLightsOn => _isRamadanLightsOn;
  double get ramadanLightProgress => _ramadanLightProgress;

  /// Initialize Ramadan mode from backend config (called after config loads)
  void initRamadanMode(bool isEnabled) {
    if (_showRamadanDecorations != isEnabled) {
      _showRamadanDecorations = isEnabled;
      if (!isEnabled) {
        _isRamadanLightsOn = false;
        _ramadanLightProgress = 0.0;
      } else {
        // Fetch Ramadan featured items when mode is enabled
        try {
          Get.find<ItemController>().getRamadanFeaturedItemList();
        } catch (e, s) {
          swallow('fetch Ramadan featured items', e, s);
        }
      }
      update();
      update(['ramadan']);
      update(['ramadan_lights']);
    }
  }

  /// Toggle showing/hiding the entire Ramadan decoration overlay
  void toggleRamadanDecorations() {
    _showRamadanDecorations = !_showRamadanDecorations;
    if (!_showRamadanDecorations) {
      // Reset lights when hiding decorations
      _isRamadanLightsOn = false;
      _ramadanLightProgress = 0.0;
    }
    update();
    update(['ramadan']);
    update(['ramadan_lights']);
  }

  /// Called when user taps "Celebrate Ramadan" button - toggles lights on/off
  void celebrateRamadan() {
    _isRamadanLightsOn = !_isRamadanLightsOn;
    debugPrint(
      'HomeController: Ramadan lights ${_isRamadanLightsOn ? "ON" : "OFF"}!',
    );
    if (!_isRamadanLightsOn) {
      // Reset progress when turning off
      _ramadanLightProgress = 0.0;
    }
    update(['ramadan']);
    update(['ramadan_lights']);
  }

  /// Update the light animation progress (called by animation controller)
  void updateRamadanLightProgress(double progress) {
    _ramadanLightProgress = progress;
    update(['ramadan_lights']);
  }

  /// Reset lights to OFF state
  void resetRamadanLights() {
    _isRamadanLightsOn = false;
    _ramadanLightProgress = 0.0;
    update(['ramadan']);
    update(['ramadan_lights']);
  }

  void setBottomNavVisibility(bool visible) {
    if (_isBottomNavVisible != visible) {
      _isBottomNavVisible = visible;
      update();
    }
  }

  /// Called when user scrolls - hides nav bar and starts timer to show again
  void onScrollDown() {
    setBottomNavVisibility(false);
    _bottomNavTimer?.cancel();
    _bottomNavTimer = Timer(const Duration(milliseconds: 1500), () {
      setBottomNavVisibility(true);
    });
  }

  /// Called when user scrolls up or stops - shows nav bar immediately
  void onScrollUp() {
    _bottomNavTimer?.cancel();
    setBottomNavVisibility(true);
  }

  Future<void> getCashBackOfferList() async {
    _cashBackOfferList = null;
    _cashBackOfferList = await homeServiceInterface.getCashBackOfferList();
    update();
  }

  void forcefullyNullCashBackOffers() {
    _cashBackOfferList = null;
    update();
  }

  Future<void> getCashBackData(double amount) async {
    CashBackModel? cashBackModel = await homeServiceInterface.getCashBackData(
      amount,
    );
    if (cashBackModel != null) {
      _cashBackData = cashBackModel;
    }
    update();
  }

  void changeFavVisibility() {
    _showFavButton = !_showFavButton;
    update();
  }

  Future<bool> saveRegistrationSuccessfulSharedPref(bool status) async {
    return await homeServiceInterface.saveRegistrationSuccessful(status);
  }

  Future<bool> saveIsStoreRegistrationSharedPref(bool status) async {
    return await homeServiceInterface.saveIsRestaurantRegistration(status);
  }

  bool getRegistrationSuccessfulSharedPref() {
    return homeServiceInterface.getRegistrationSuccessful();
  }

  bool getIsStoreRegistrationSharedPref() {
    return homeServiceInterface.getIsRestaurantRegistration();
  }
}
