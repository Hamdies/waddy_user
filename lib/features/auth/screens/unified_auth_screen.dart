import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:lottie/lottie.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sixam_mart/features/auth/controllers/auth_controller.dart';
import 'package:sixam_mart/features/auth/domain/enum/centralize_login_enum.dart';
import 'package:sixam_mart/features/location/controllers/location_controller.dart';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/features/verification/controllers/verification_controller.dart';
import 'package:sixam_mart/common/widgets/custom_snackbar.dart';
import 'package:sixam_mart/common/widgets/custom_button.dart';
import 'package:sixam_mart/helper/address_helper.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/features/address/domain/models/address_model.dart';
import 'package:sixam_mart/features/location/domain/models/zone_response_model.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'auth_utils.dart';

class UnifiedAuthScreen extends StatefulWidget {
  const UnifiedAuthScreen({super.key});

  @override
  State<UnifiedAuthScreen> createState() => _UnifiedAuthScreenState();
}

class _UnifiedAuthScreenState extends State<UnifiedAuthScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _shakeController;

  int _currentStep =
      0; // 0: Phone Input, 1: OTP Verification, 2: Name Input, 3: Privacy (Hide Phone), 4: Location

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // Individual OTP field controllers
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(
    6,
    (index) => FocusNode(),
  );

  String? _countryDialCode;
  String? _phoneNumber;
  String? _firebaseSession;
  AddressModel? _fetchedAddress;
  bool _isFetchingLocation = false;
  bool _isLoading = false;
  Timer? _timer;
  int _seconds = 30;

  StreamController<ErrorAnimationType>? errorController;

  @override
  void initState() {
    super.initState();

    // Initialize fade animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _fadeController.forward();

    // Initialize shake animation
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _countryDialCode =
        CountryCode.fromCountryCode(
          Get.find<SplashController>().configModel!.country!,
        ).dialCode;

    errorController = StreamController<ErrorAnimationType>();

    // Listen to phone controller changes
    _phoneController.addListener(() {
      if (mounted) setState(() {});
    });

    _otpController.addListener(() {
      if (mounted) setState(() {});
    });

    _nameController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _shakeController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _otpFocusNodes) {
      node.dispose();
    }
    _timer?.cancel();
    errorController?.close();
    super.dispose();
  }

  void _startTimer() {
    _seconds = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _seconds = _seconds - 1;
          if (_seconds == 0) {
            timer.cancel();
            _timer?.cancel();
          }
        });
      }
    });
  }

  void _sendOTP() async {
    String rawPhone = _phoneController.text.replaceAll(' ', '');

    if (rawPhone.isEmpty) {
      showCustomSnackBar('please_enter_phone_number'.tr);
      return;
    }

    if (rawPhone.length != 10) {
      _shakeController.forward(from: 0.0);
      showCustomSnackBar('please_enter_valid_phone_number'.tr);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    _phoneNumber = _countryDialCode! + rawPhone;

    // Check if this is a resend (already on step 1)
    if (_currentStep == 1) {
      // Just trigger Firebase verification again for resend
      _triggerFirebaseVerification();
      return;
    }

    // Initial send - Use Firebase OTP verification
    Get.find<AuthController>()
        .otpLogin(
          phone: _phoneNumber!,
          otp: '',
          loginType: CentralizeLoginType.otp.name,
          verified: '',
        )
        .then((response) {
          if (response.isSuccess) {
            // Check if Firebase verification is enabled
            if (response.authResponseModel != null &&
                !response.authResponseModel!.isPhoneVerified!) {
              if (Get.find<SplashController>()
                  .configModel!
                  .firebaseOtpVerification!) {
                // Trigger Firebase verification
                _triggerFirebaseVerification();
              } else {
                // Move to OTP step for manual verification
                setState(() {
                  _isLoading = false;
                });
                _changeStep(1);
                _startTimer();
              }
            }
          } else {
            setState(() {
              _isLoading = false;
            });
            showCustomSnackBar(response.message);
          }
        });
  }

  void _triggerFirebaseVerification() async {
    // Ensure loading is true (in case called directly or logic fell through)
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: _phoneNumber!,
      verificationCompleted: (PhoneAuthCredential credential) {
        // Auto-retrieval or instant verification might happen here
        // We should probably handle it, but for now just stop loading if needed?
        // Usually we sign in with credential.
      },
      verificationFailed: (FirebaseAuthException e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        if (e.code == 'invalid-phone-number') {
          showCustomSnackBar('please_submit_a_valid_phone_number'.tr);
        } else {
          showCustomSnackBar(e.message?.replaceAll('_', ' '));
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!mounted) return;
        _firebaseSession = verificationId;

        if (_currentStep != 1) {
          _changeStep(1);
        }

        _timer?.cancel();
        setState(() {
          _seconds = 30;
          _isLoading = false;
        });
        _startTimer();

        showCustomSnackBar('otp_sent_successfully'.tr, isError: false);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _firebaseSession = verificationId;
      },
    );
  }

  void _verifyOTP() async {
    // Combine all OTP fields
    String otp = _otpControllers.map((c) => c.text).join();

    if (otp.length < 6) {
      showCustomSnackBar('please_enter_valid_otp'.tr);
      return;
    }

    _otpController.text = otp;

    Get.find<VerificationController>().updateVerificationCode(otp);

    if (Get.find<SplashController>().configModel!.firebaseOtpVerification!) {
      Get.find<VerificationController>()
          .verifyFirebaseOtp(
            phoneNumber: _phoneNumber!,
            session: _firebaseSession ?? '',
            otp: otp,
            loginType: CentralizeLoginType.otp.name,
            token: '',
            isSignUpPage:
                false, // Set to false to prevent controller from calling getUserInfo automatically
            isForgetPassPage: false,
          )
          .then((value) {
            if (value.isSuccess) {
              // Check if profile is complete.
              // We need to check both isPersonalInfo flag AND if we have a valid token.
              // If token is null, we are not fully logged in/registered yet.
              bool isProfileComplete = false;
              if (value.authResponseModel != null &&
                  value.authResponseModel!.isPersonalInfo == true &&
                  value.authResponseModel!.token != null) {
                isProfileComplete = true;
              }

              if (!isProfileComplete) {
                _changeStep(2);
              } else {
                _checkAddressAndProceed();
              }
            } else {
              // Shake animation for error
              for (var controller in _otpControllers) {
                controller.clear();
              }
              _otpFocusNodes[0].requestFocus();
              showCustomSnackBar(value.message);
            }
          });
    }
  }

  void _completeName() {
    String name = _nameController.text.trim();
    String email = _emailController.text.trim();

    if (name.isEmpty) {
      showCustomSnackBar('auth_name_placeholder'.tr);
      return;
    }

    if (email.isNotEmpty && !GetUtils.isEmail(email)) {
      showCustomSnackBar('enter_valid_email_address'.tr);
      return;
    }

    Get.find<AuthController>()
        .updatePersonalInfo(
          name: name,
          phone: _phoneNumber,
          loginType: CentralizeLoginType.otp.name,
          email: email.isEmpty ? null : email,
          referCode: '', // Referral code can be added if needed
        )
        .then((response) {
          if (response.isSuccess) {
            // Go to privacy step (step 3) instead of directly to location
            _changeStep(3);
          } else {
            showCustomSnackBar(response.message);
          }
        });
  }

  void _checkAddressAndProceed() {
    if (AddressHelper.getUserAddressFromSharedPref() != null) {
      Get.offAllNamed(RouteHelper.getInitialRoute());
    } else {
      _changeStep(4);
    }
  }

  void _proceedToLocation() {
    if (AddressHelper.getUserAddressFromSharedPref() != null) {
      Get.offAllNamed(RouteHelper.getInitialRoute());
    } else {
      _changeStep(4);
    }
  }

  void _handleHidePhoneChoice(bool hidePhone) async {
    if (hidePhone) {
      // Show warning dialog first
      _showHidePhoneWarningDialog();
    } else {
      // User chose not to hide phone, proceed directly
      _proceedToLocation();
    }
  }

  void _showHidePhoneWarningDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 28,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'important_notice'.tr,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'hide_phone_warning_message'.tr,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.6),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).secondaryHeaderColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).secondaryHeaderColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'check_app_messages_reminder'.tr,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            CustomButton(
              buttonText: 'cancel'.tr,
              onPressed: () {
                Navigator.of(context).pop();
              },
              transparent: true,
              height: 40,
              radius: 8,
            ),
            CustomButton(
              buttonText: 'i_understand'.tr,
              onPressed: () {
                Navigator.of(context).pop();
                _confirmHidePhone();
              },
              height: 40,
              radius: 8,
            ),
          ],
        );
      },
    );
  }

  void _confirmHidePhone() async {
    final response = await Get.find<AuthController>().toggleHidePhone(
      hidePhone: true,
    );
    if (response.isSuccess) {
      _proceedToLocation();
    } else {
      showCustomSnackBar(response.message);
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
        GetPlatform.isDesktop,
      );
    } else {
      Get.back(); // Close loader
      showCustomSnackBar(response.message);
    }
  }

  void _goBack() {
    if (_currentStep > 0) {
      _fadeController.reverse().then((_) {
        setState(() {
          _currentStep--;
        });
        _fadeController.forward();
      });
    } else {
      Get.back();
    }
  }

  void _changeStep(int newStep) {
    if (!mounted) return;
    _fadeController.reverse().then((_) {
      if (!mounted) return;
      setState(() {
        _currentStep = newStep;
      });
      _fadeController.forward().then((_) {
        // Auto-fetch location when entering step 4 (location), after animation completes
        if (newStep == 4 && mounted) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              _useCurrentLocation();
            }
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentStep == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentStep > 0) {
          _fadeController.reverse().then((_) {
            if (mounted) {
              setState(() {
                _currentStep--;
              });
              _fadeController.forward();
            }
          });
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFDFDFD),
        body: Stack(
          children: [
            // Top Left - Primary

            // Top Right - Secondary

            // Bottom Left - Secondary
            Positioned(
              bottom: -100,
              left: -100,
              child: _buildGradientBlob(
                Theme.of(context).secondaryHeaderColor.withValues(alpha: 0.2),
              ),
            ),
            // Bottom Right - Primary
            Positioned(
              bottom: -100,
              right: -100,
              child: _buildGradientBlob(
                Theme.of(context).primaryColor.withValues(alpha: 0.2),
              ),
            ),

            // Blur effect to soften them further
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Container(
                  color: const Color(0xFFFDFDFD).withValues(alpha: 0.1),
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  // Progress indicator removed

                  // Content with fade transition
                  Expanded(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: _buildStepContent(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientBlob(Color color) {
    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final steps = ['Phone', 'Verify', 'Profile', 'Privacy', 'Location'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step labels
          // Row(
          //   children: List.generate(steps.length, (index) {
          //     final isCurrent = _currentStep == index;
          //     final isCompleted = _currentStep > index;

          //     return Expanded(
          //       child: AnimatedDefaultTextStyle(
          //         duration: const Duration(milliseconds: 300),
          //         curve: Curves.easeOut,
          //         style: TextStyle(
          //           fontSize: isCurrent ? 13 : 11,
          //           fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
          //           color:
          //               isCurrent
          //                   ? Theme.of(context).primaryColor
          //                   : isCompleted
          //                   ? Theme.of(context).secondaryHeaderColor
          //                   : const Color(0xFFBDBDBD),
          //         ),
          //         child: Text(steps[index], textAlign: TextAlign.center),
          //       ),
          //     );
          //   }),
          // ),
          const SizedBox(height: 12),
          // Progress bar
          LayoutBuilder(
            builder: (context, constraints) {
              final progressWidth =
                  constraints.maxWidth * ((_currentStep + 1) / steps.length);

              return Container(
                height: 20,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Stack(
                  children: [
                    // Animated progress fill
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      width: progressWidth,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Theme.of(context).secondaryHeaderColor,
                            Theme.of(
                              context,
                            ).secondaryHeaderColor.withValues(alpha: 0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).secondaryHeaderColor.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                    // Step markers
                    // Row(
                    //   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    //   children: List.generate(steps.length, (index) {
                    //     return _buildStepMarker(index);
                    //   }),
                    // ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildPhoneInputStep();
      case 1:
        return _buildOTPVerificationStep();
      case 2:
        return _buildNameInputStep();
      case 3:
        return _buildPrivacyStep();
      case 4:
        return _buildLocationSelectionStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildPhoneInputStep() {
    // Calculate validation state
    String rawText = _phoneController.text.replaceAll(' ', '');
    bool isLengthValid = rawText.length == 10;
    bool isPrefixValid = rawText.startsWith('1');
    bool isValid = isLengthValid && isPrefixValid;

    return Stack(
      children: [
        // Positioned(
        //   bottom: 0,
        //   right: 0,
        //   child: Opacity(
        //     opacity: 0.9,
        //     child: Image.asset('assets/image/logo_no_bg.png', width: 150),
        //   ),
        // ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Lottie.asset(
                'assets/animation/waddy_anim.json',
                width: 300,
              ),
            ),
            SizedBox(height: 50),
            // Title
            SizedBox(
              width: double.infinity,
              child: Text(
                'auth_enter_your_phone'.tr,
                textAlign: TextAlign.start,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),

            const SizedBox(height: 8),
            Text(
              'auth_verification_code_subtitle'.tr,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).primaryColor.withValues(alpha: 0.6),
              ),
            ),

            const SizedBox(height: 40),

            // Phone input field
            ShakeWidget(
              controller: _shakeController,
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Container(
                  height: 56, // Touch target
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).primaryColor.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Country code picker
                      CountryCodePicker(
                        onChanged: (country) {
                          setState(() {
                            _countryDialCode = country.dialCode;
                          });
                        },
                        initialSelection:
                            Get.find<SplashController>().configModel!.country!,
                        favorite: [
                          Get.find<SplashController>().configModel!.country!,
                        ],
                        showCountryOnly: false,
                        showOnlyCountryWhenClosed: false,
                        alignLeft: false,
                        hideMainText: false,
                        showFlag: true,
                        showFlagDialog: true,
                        padding: EdgeInsets.zero,
                        textStyle: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                        dialogTextStyle: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 1,
                        height: 24,
                        color: Theme.of(
                          context,
                        ).primaryColor.withValues(alpha: 0.2),
                      ),
                      const SizedBox(width: 12),

                      // Phone number input
                      Expanded(
                        child: Semantics(
                          label: "Phone number input",
                          hint:
                              "Enter your 10-digit mobile number starting with 1",
                          child: TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.0,
                            ),
                            cursorColor: Theme.of(context).secondaryHeaderColor,
                            decoration: InputDecoration(
                              hintText: '010 1234 5678',
                              hintStyle: TextStyle(
                                fontSize: 16,
                                color: Theme.of(
                                  context,
                                ).primaryColor.withValues(alpha: 0.35),
                                fontWeight: FontWeight.w400,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 0,
                                vertical: 18,
                              ),
                            ),
                            inputFormatters: [EgyptianPhoneFormatter()],
                            onChanged: (value) {
                              // Haptic feedback on 10th digit
                              String raw = value.replaceAll(' ', '');
                              if (raw.length == 10) {
                                HapticFeedback.lightImpact();
                              }
                              setState(() {});
                            },
                          ),
                        ),
                      ),

                      // Checkmark if valid
                      if (isValid)
                        Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: FadeTransition(
                            opacity: const AlwaysStoppedAnimation(1.0),
                            child: Icon(
                              Icons.check_circle,
                              color: Theme.of(context).secondaryHeaderColor,
                              size: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Helper text / Counter
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isValid
                        ? 'auth_valid_mobile_number'.tr
                        : 'auth_enter_without_leading_zero'.tr,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          isValid
                              ? Theme.of(context).secondaryHeaderColor
                              : Theme.of(
                                context,
                              ).primaryColor.withValues(alpha: 0.5),
                    ),
                  ),
                  Text(
                    'auth_digits_counter'.trParams({
                      'count': '${rawText.length}',
                    }),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).primaryColor.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Next button
            CustomButton(
              buttonText: 'next'.tr,
              onPressed: (isValid && !_isLoading) ? _sendOTP : null,
              isLoading: _isLoading,
              height: 56,
              icon: Icons.arrow_forward,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOTPVerificationStep() {
    String otp = _otpControllers.map((c) => c.text).join();
    bool isOtpComplete = otp.length == 6;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Lottie.asset('assets/animation/waddy_anim.json'),
        // Title — bold, left-aligned
                const SizedBox(height: 16),

        Text(
          'auth_enter_code_title'.tr,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).primaryColor,
            height: 1.2,
          ),
        ),

        const SizedBox(height: 12),

        // Subtitle with phone number
        GestureDetector(
          onTap: () => _changeStep(0),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'auth_sent_to_verify'.trParams({
                    'phone': _phoneNumber ?? '',
                  }),
                  style: TextStyle(
                    fontSize: 15,
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.6),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 32),

        // OTP input boxes — gray rounded style
        Directionality(
          textDirection: TextDirection.ltr,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth - (5 * 10);
              final boxWidth = (availableWidth / 6).clamp(40.0, 52.0);
              const boxHeight = 58.0;

              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  final hasValue = _otpControllers[index].text.isNotEmpty;
                  final isFocused = _otpFocusNodes[index].hasFocus;

                  return Padding(
                    padding: EdgeInsets.only(right: index < 5 ? 10 : 0),
                    child: GestureDetector(
                      onTap: () => _otpFocusNodes[index].requestFocus(),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: boxWidth,
                        height: boxHeight,
                        decoration: BoxDecoration(
                          color:
                              isFocused
                                  ? Theme.of(
                                    context,
                                  ).primaryColor.withValues(alpha: 0.08)
                                  : Theme.of(
                                    context,
                                  ).primaryColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border:
                              isFocused
                                  ? Border.all(
                                    color: Theme.of(context).primaryColor,
                                    width: 1.5,
                                  )
                                  : null,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Hidden TextField for input
                            Opacity(
                              opacity: 0,
                              child: SizedBox(
                                width: boxWidth,
                                height: boxHeight,
                                child: TextField(
                                  controller: _otpControllers[index],
                                  focusNode: _otpFocusNodes[index],
                                  keyboardType: TextInputType.number,
                                  maxLength: 1,
                                  decoration: const InputDecoration(
                                    counterText: '',
                                    border: InputBorder.none,
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  onChanged: (value) {
                                    if (value.isNotEmpty && index < 5) {
                                      _otpFocusNodes[index + 1].requestFocus();
                                    } else if (value.isEmpty && index > 0) {
                                      _otpFocusNodes[index - 1].requestFocus();
                                    }

                                    String otp =
                                        _otpControllers
                                            .map((c) => c.text)
                                            .join();
                                    if (otp.length == 6) {
                                      _verifyOTP();
                                    }

                                    setState(() {});
                                  },
                                ),
                              ),
                            ),
                            // Visible digit
                            if (hasValue)
                              Text(
                                _otpControllers[index].text,
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).primaryColor,
                                ),
                              )
                            else if (isFocused)
                              Container(
                                width: 2,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor,
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ),

        const SizedBox(height: 20),

        // "Don't see it? Retry in X seconds" / Resend link
        _seconds > 0
            ? Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'auth_dont_see_it'.tr,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(
                        context,
                      ).primaryColor.withValues(alpha: 0.6),
                    ),
                  ),
                  TextSpan(text: ' '),
                  TextSpan(
                    text: '$_seconds',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  TextSpan(
                    text: ' ${'auth_seconds'.tr}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(
                        context,
                      ).primaryColor.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            )
            : GestureDetector(
              onTap: _sendOTP,
              child: Text(
                'auth_resend_code'.tr,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).primaryColor,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),

        const SizedBox(height: 48),

        // Verify button
        GetBuilder<VerificationController>(
          builder: (verificationController) {
            return CustomButton(
              buttonText: 'verify'.tr,
              onPressed:
                  (isOtpComplete && !verificationController.isLoading)
                      ? _verifyOTP
                      : null,
              isLoading: verificationController.isLoading,
              height: 56,
            );
          },
        ),
      ],
    );
  }

  Widget _buildNameInputStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Lottie.asset('assets/animation/waddy_anim.json', width: 300),
        ),
        const SizedBox(height: 50),

        // Title
        Text(
          'complete_profile'.tr,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).primaryColor,
            height: 1.2,
          ),
        ),

        const SizedBox(height: 40),

        // Name input field
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
            ),
          ),
          child: TextField(
            controller: _nameController,
            keyboardType: TextInputType.name,
            textCapitalization: TextCapitalization.words,
            cursorColor: Theme.of(context).secondaryHeaderColor,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'auth_name_placeholder'.tr,
              hintStyle: TextStyle(
                fontSize: 16,
                color: Theme.of(context).primaryColor.withValues(alpha: 0.35),
                fontWeight: FontWeight.w400,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
              prefixIcon: Icon(
                Icons.person_outline,
                color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Email input field
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
            ),
          ),
          child: TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            cursorColor: Theme.of(context).secondaryHeaderColor,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: '${'email'.tr} (${'optional'.tr})',
              hintStyle: TextStyle(
                fontSize: 16,
                color: Theme.of(context).primaryColor.withValues(alpha: 0.35),
                fontWeight: FontWeight.w400,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
              prefixIcon: Icon(
                Icons.email_outlined,
                color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),

        const SizedBox(height: 32),

        // Complete button
        CustomButton(
          buttonText: 'auth_complete'.tr,
          onPressed:
              _nameController.text.trim().isNotEmpty ? _completeName : null,
          height: 56,
          icon: Icons.arrow_forward,
        ),
      ],
    );
  }

  Widget _buildPrivacyStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Lottie.asset('assets/animation/waddy_anim.json', width: 300),
        ),
        const SizedBox(height: 50),

        // Title
        Text(
          'privacy_settings'.tr,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).primaryColor,
            height: 1.2,
          ),
        ),

        const SizedBox(height: 16),

        // Subtitle
        Text(
          'hide_phone_question'.tr,
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).primaryColor.withValues(alpha: 0.6),
            height: 1.5,
          ),
        ),

        const SizedBox(height: 40),

        // Privacy illustration/icon
        Center(
          child: Container(
            child: Lottie.asset("assets/animation/dnd_feature.json"),
          ),
        ),

        const SizedBox(height: 32),

        // Info card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(
                context,
              ).secondaryHeaderColor.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                color: Theme.of(context).secondaryHeaderColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'hide_phone_description'.tr,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.6),
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Yes - Hide my phone button
        CustomButton(
          buttonText: 'yes_hide_my_phone'.tr,
          onPressed: () => _handleHidePhoneChoice(true),
          height: 56,
          icon: Icons.visibility_off,
        ),

        const SizedBox(height: 16),

        // No - Keep my phone visible button
        CustomButton(
          buttonText: 'no_keep_visible'.tr,
          onPressed: () => _handleHidePhoneChoice(false),
          height: 56,
          icon: Icons.visibility,
          transparent: true,
        ),
      ],
    );
  }

  Widget _buildLocationSelectionStep() {
    if (_isFetchingLocation) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Center(
            child: Lottie.asset('assets/animation/waddy_anim.json', width: 300),
          ),
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
          Center(
            child: Lottie.asset('assets/animation/waddy_anim.json', width: 300),
          ),
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(
                  context,
                ).secondaryHeaderColor.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                HugeIcon(icon: HugeIcons.strokeRoundedLocation01, color: Theme.of(context).primaryColor),
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
            height: 56,
          ),

          const SizedBox(height: 16),

          CustomButton(
            buttonText: 'no_choose_another'.tr,
            onPressed: () {
              setState(() {
                _fetchedAddress = null;
              });
            },
            height: 56,
            transparent: true,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Lottie.asset('assets/animation/waddy_anim.json', width: 300),
        ),
        const SizedBox(height: 50),

        // Title
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

        // Use Current Location Button
        CustomButton(
          buttonText: 'use_current_location'.tr,
          onPressed: _useCurrentLocation,
          height: 56,
          icon: Icons.my_location,
        ),

        const SizedBox(height: 16),

        // Select on Map Button
        CustomButton(
          buttonText: 'set_from_map'.tr,
          onPressed: () {
            Get.toNamed(RouteHelper.getPickMapRoute(RouteHelper.signUp, false));
          },
          height: 56,
          icon: Icons.map,
          transparent: true,
        ),
      ],
    );
  }
}
