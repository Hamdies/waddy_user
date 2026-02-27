import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/features/home/domain/models/cashback_model.dart';
import 'package:sixam_mart/features/home/domain/services/home_service_interface.dart';
import 'package:sixam_mart/features/item/controllers/item_controller.dart';

class HomeController extends GetxController implements GetxService {
  final HomeServiceInterface homeServiceInterface;
  HomeController({required this.homeServiceInterface});

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
  bool _showRamadanDecorations = false; // Controlled by backend ramadan_mode setting
  bool _isRamadanLightsOn = false; // Lights start OFF
  double _ramadanLightProgress = 0.0; // Animation progress

  bool get showRamadanDecorations => _showRamadanDecorations;
  bool get isRamadanLightsOn => _isRamadanLightsOn;
  double get ramadanLightProgress => _ramadanLightProgress;

  // For backward compatibility
  bool get isRamadanCelebrationActive => _showRamadanDecorations;

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
        } catch (_) {}
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

  /// Toggle Ramadan celebration overlay on/off (legacy method)
  void toggleRamadanCelebration() {
    toggleRamadanDecorations();
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

  // bool _canShoeReferrerBottomSheet = false;
  // bool get canShoeReferrerBottomSheet => _canShoeReferrerBottomSheet;

  // void toggleReferrerBottomSheet({bool? status}) {
  //   if(Get.find<ProfileController>().userInfoModel!.isValidForDiscount! && status == null) {
  //     _canShoeReferrerBottomSheet = true;
  //   } else {
  //     _canShoeReferrerBottomSheet = status ?? false;
  //   }
  // }

  Future<void> getCashBackOfferList() async {
    _cashBackOfferList = null;
    _cashBackOfferList = await homeServiceInterface.getCashBackOfferList();
    update();
  }

  void forcefullyNullCashBackOffers() {
    _cashBackOfferList = null;
    update();
  }

  /*  Future<double> getCashBackAmount(double amount) async {
    _cashBackAmount = await homeServiceInterface.getCashBackAmount(amount);
    return _cashBackAmount;
  }*/

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
