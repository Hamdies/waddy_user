import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:waddy_app/common/widgets/custom_button.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/features/address/domain/models/address_model.dart';
import 'package:waddy_app/features/auth/controllers/auth_controller.dart';
import 'package:waddy_app/features/auth/widgets/auth_flow_widget.dart';
import 'package:waddy_app/features/home/screens/home_screen.dart';
import 'package:waddy_app/features/location/controllers/location_controller.dart';
import 'package:waddy_app/features/location/domain/models/zone_response_model.dart';
import 'package:waddy_app/helper/address_helper.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/images.dart';
import 'package:waddy_app/util/dimensions.dart';

/// Full-screen auth: phone → OTP → (name for new accounts) → location.
/// The phone/OTP/name machinery lives in [AuthFlowWidget]; this screen only
/// hosts it and owns the final location step.
class UnifiedAuthScreen extends StatefulWidget {
  const UnifiedAuthScreen({super.key});

  @override
  State<UnifiedAuthScreen> createState() => _UnifiedAuthScreenState();
}

class _UnifiedAuthScreenState extends State<UnifiedAuthScreen> {
  static const int _stepLocation = 3;

  final GlobalKey<AuthFlowWidgetState> _flowKey =
      GlobalKey<AuthFlowWidgetState>();

  // 0: phone, 1: OTP, 2: name — mirrored from AuthFlowWidget; 3: location.
  int _currentStep = 0;
  bool _onLocationStep = false;

  /// Set when the splash gate sent us here to finish an interrupted signup.
  late final bool _resumingProfile;
  late final String? _resumePhone;

  @override
  void initState() {
    super.initState();
    final AuthController authController = Get.find<AuthController>();
    _resumePhone = authController.getPendingProfilePhone();
    _resumingProfile =
        authController.isProfileIncomplete() && _resumePhone != null;
    if (_resumingProfile) {
      _currentStep = 2;
    }
  }

  AddressModel? _fetchedAddress;
  bool _isFetchingLocation = false;

  void _onAuthSuccess() {
    if (AddressHelper.getUserAddressFromSharedPref() != null) {
      // Home's initState calls loadData(false), which the quiet-path window
      // swallows because the guest session just loaded — leaving the
      // logged-in-only batch (customer/info, XP, coupons, orders) unfetched,
      // so the greeting stayed "there" until a manual pull-to-refresh. Force
      // the reload here, where the session has just changed hands.
      HomeScreen.loadData(true);
      Get.offAllNamed(RouteHelper.getInitialRoute());
    } else {
      setState(() {
        _onLocationStep = true;
        _currentStep = _stepLocation;
      });
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _useCurrentLocation();
      });
    }
  }

  void _useCurrentLocation() async {
    setState(() {
      _isFetchingLocation = true;
    });

    Get.find<LocationController>().checkPermission(() async {
      AddressModel address = await Get.find<LocationController>()
          .getCurrentLocation(true);

      if (!mounted) return;
      setState(() {
        _fetchedAddress = address;
        _isFetchingLocation = false;
      });
    });
  }

  void _confirmAddress() async {
    if (_fetchedAddress == null) return;

    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );

    ZoneResponseModel response = await Get.find<LocationController>().getZone(
      _fetchedAddress!.latitude,
      _fetchedAddress!.longitude,
      false,
    );

    if (response.isSuccess) {
      Get.find<LocationController>().saveAddressAndNavigate(
        _fetchedAddress!,
        false,
        null,
        false,
        false,
      );
    } else {
      Get.back();
      showCustomSnackBar(response.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // A resumed profile step has nothing valid to pop back to.
      canPop: _currentStep == 0 && !_resumingProfile,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_onLocationStep) return; // No back out of the final step.
        _flowKey.currentState?.handleBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFDFDFD),
        body: Column(
          children: [
            _buildBrandHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Dimensions.paddingSizeExtraLarge),
                child:
                    _onLocationStep
                        ? _buildLocationSelectionStep()
                        : AuthFlowWidget(
                          key: _flowKey,
                          showNameStep: true,
                          startAtNameStep: _resumingProfile,
                          resumePhone: _resumePhone,
                          onSuccess: _onAuthSuccess,
                          onStepChanged: (step) {
                            setState(() {
                              _currentStep = step;
                            });
                          },
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Container(
      color: const Color(0xFFFDFDFD),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          // Fixed height so hiding the close button doesn't shift the
          // content below it between steps.
          child: SizedBox(
            height: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Image.asset(Images.waddyLogo, height: 40),
                // Only offered on the phone step — once a code is on its way
                // the user finishes the flow (or backs out step by step).
                if (!_onLocationStep && _currentStep == 0)
                  GestureDetector(
                    onTap: () => Get.offAllNamed(RouteHelper.getInitialRoute()),
                    child: Icon(
                      Icons.close,
                      color: Theme.of(context).primaryColor,
                      size: 24,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationSelectionStep() {
    if (_isFetchingLocation) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Center(child: Image.asset(Images.waddyLogo, width: 140)),
          const SizedBox(height: 50),
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'detecting_location'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).primaryColor.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    if (_fetchedAddress != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Image.asset(Images.waddyLogo, width: 140)),
          const SizedBox(height: 50),
          Text(
            'is_this_your_location'.tr,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).primaryColor,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              border: Border.all(
                color: Theme.of(
                  context,
                ).secondaryHeaderColor.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedLocation01,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _fetchedAddress!.address ?? '',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          CustomButton(
            buttonText: 'yes_confirm'.tr,
            onPressed: _confirmAddress,
          ),
          const SizedBox(height: 16),
          CustomButton(
            buttonText: 'no_choose_another'.tr,
            onPressed: () {
              setState(() {
                _fetchedAddress = null;
              });
            },
            transparent: true,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: Image.asset(Images.waddyLogo, width: 140)),
        const SizedBox(height: 50),
        Text(
          'select_location'.tr,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).primaryColor,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'select_delivery_location_message'.tr,
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).primaryColor.withValues(alpha: 0.6),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 40),
        CustomButton(
          buttonText: 'use_current_location'.tr,
          onPressed: _useCurrentLocation,
          icon: Icons.my_location,
        ),
        const SizedBox(height: 16),
        CustomButton(
          buttonText: 'set_from_map'.tr,
          onPressed: () {
            Get.toNamed(RouteHelper.getPickMapRoute(RouteHelper.signUp, false));
          },
          icon: Icons.map,
          transparent: true,
        ),
      ],
    );
  }
}
