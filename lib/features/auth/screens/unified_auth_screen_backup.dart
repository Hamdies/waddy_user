import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:waddy_app/features/auth/controllers/auth_controller.dart';
import 'package:waddy_app/features/auth/domain/enum/centralize_login_enum.dart';
import 'package:waddy_app/features/location/controllers/location_controller.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/verification/controllers/verification_controller.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:country_code_picker/country_code_picker.dart';

class UnifiedAuthScreen extends StatefulWidget {
  const UnifiedAuthScreen({super.key});

  @override
  State<UnifiedAuthScreen> createState() => _UnifiedAuthScreenState();
}

class _UnifiedAuthScreenState extends State<UnifiedAuthScreen>
    with TickerProviderStateMixin {
  int _currentStep = 0; // 0: Phone Input, 1: OTP Verification, 2: Success

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  String? _countryDialCode;
  String? _phoneNumber;
  String? _firebaseSession;
  Timer? _timer;
  int _seconds = 30;

  late AnimationController _successAnimationController;
  late Animation<double> _successScaleAnimation;

  late AnimationController _cardAnimationController;
  late Animation<double> _card1OpacityAnimation;
  late Animation<double> _card2OpacityAnimation;
  late Animation<double> _card3OpacityAnimation;

  StreamController<ErrorAnimationType>? errorController;

  @override
  void initState() {
    super.initState();
    _countryDialCode =
        CountryCode.fromCountryCode(
          Get.find<SplashController>().configModel!.country!,
        ).dialCode;

    _successAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _successScaleAnimation = CurvedAnimation(
      parent: _successAnimationController,
      curve: Curves.elasticOut,
    );

    // Card animation controller
    _cardAnimationController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();

    // Card 1 animations (appears first) - 0% to 33%
    _card1OpacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 10,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 15),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 8,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 67),
    ]).animate(_cardAnimationController);

    // Card 2 animations (appears second) - 33% to 66%
    _card2OpacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 33),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 10,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 15),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 8,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 34),
    ]).animate(_cardAnimationController);

    // Card 3 animations (appears third) - 66% to 100%
    _card3OpacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 66),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 10,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 15),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 9,
      ),
    ]).animate(_cardAnimationController);

    errorController = StreamController<ErrorAnimationType>();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _timer?.cancel();
    _successAnimationController.dispose();
    _cardAnimationController.dispose();
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
    if (_phoneController.text.isEmpty) {
      showCustomSnackBar('please_enter_phone_number'.tr);
      return;
    }

    _phoneNumber = _countryDialCode! + _phoneController.text.trim();

    // Check if this is a resend (already on step 1)
    if (_currentStep == 1) {
      // Just trigger Firebase verification again for resend
      _triggerFirebaseVerification();
      return;
    }

    // Initial send - Use Firebase OTP verification like the existing flow
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
                  _currentStep = 1;
                });
                _startTimer();
              }
            }
          } else {
            showCustomSnackBar(response.message);
          }
        });
  }

  void _triggerFirebaseVerification() async {
    // Handle Firebase verification within this screen
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: _phoneNumber!,
      verificationCompleted: (PhoneAuthCredential credential) {
        // Auto-verification completed
      },
      verificationFailed: (FirebaseAuthException e) {
        if (e.code == 'invalid-phone-number') {
          showCustomSnackBar('please_submit_a_valid_phone_number'.tr);
        } else {
          showCustomSnackBar(e.message?.replaceAll('_', ' '));
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        // Store the session ID for verification
        _firebaseSession = verificationId;

        // Move to OTP input step (or stay if already there for resend)
        if (_currentStep != 1) {
          setState(() {
            _currentStep = 1;
          });
        }

        // Restart timer for resend
        _timer?.cancel();
        setState(() {
          _seconds = 30;
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
    if (_otpController.text.length < 6) {
      showCustomSnackBar('please_enter_valid_otp'.tr);
      return;
    }

    Get.find<VerificationController>().updateVerificationCode(
      _otpController.text,
    );

    // Use Firebase verification if enabled
    if (Get.find<SplashController>().configModel!.firebaseOtpVerification!) {
      // Verify with Firebase session
      Get.find<VerificationController>()
          .verifyFirebaseOtp(
            phoneNumber: _phoneNumber!,
            session: _firebaseSession ?? '',
            otp: _otpController.text,
            loginType: CentralizeLoginType.otp.name,
            token: '',
            isSignUpPage: true,
            isForgetPassPage: false,
          )
          .then((value) {
            if (value.isSuccess) {
              _handleSuccessVerification(value);
            } else {
              errorController?.add(ErrorAnimationType.shake);
              showCustomSnackBar(value.message);
            }
          });
    }
  }

  void _handleSuccessVerification(dynamic value) {
    setState(() {
      _currentStep = 2;
    });
    _successAnimationController.forward();

    // Navigate after showing success
    Future.delayed(const Duration(seconds: 2), () {
      Get.find<LocationController>().navigateToLocationScreen(
        'verification',
        offNamed: true,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF134E4A),
              Color(0xFF0F3D3A),
              Color(0xFF1EF2A0).withOpacity(0.3),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Animated notification cards
            _buildAnimatedCards(),

            // Bottom Sheet
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: EdgeInsets.only(
                  top: MediaQuery.of(context).size.height * 0.3,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 30,
                      offset: Offset(0, -10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with step indicator
                    _buildHeader(),

                    // Content based on current step
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(24),
                        child: _buildStepContent(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    String title = '';
    switch (_currentStep) {
      case 0:
        title = 'auth_enter_phone_number'.tr;
        break;
      case 1:
        title = 'auth_confirmation_code'.tr;
        break;
      case 2:
        title = 'complete'.tr;
        break;
    }

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 20),

          // Title and close button
          Row(
            children: [
              if (_currentStep > 0 && _currentStep < 2)
                IconButton(
                  icon: Icon(Icons.arrow_back_ios, size: 20),
                  onPressed: () {
                    setState(() {
                      _currentStep--;
                    });
                  },
                )
              else
                SizedBox(width: 48),

              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: robotoMedium.copyWith(
                    fontSize: 18,
                    color: Colors.black87,
                  ),
                ),
              ),

              IconButton(
                icon: Icon(Icons.close, size: 24),
                onPressed: () => Get.back(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernStepper() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        children: [
          // Progress bar with stops
          SizedBox(
            height: 50,
            child: Stack(
              children: [
                // Background track
                Positioned(
                  left: 20,
                  right: 20,
                  top: 24,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),

                // Active progress track
                Positioned(
                  left: 20,
                  right:
                      _currentStep == 0
                          ? MediaQuery.of(context).size.width * 0.5
                          : 20,
                  top: 24,
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),

                // Step circles
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStepStop(0, 'auth_phone_step'.tr),
                    _buildStepStop(1, 'auth_verify_step'.tr),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepStop(int step, String label) {
    bool isActive = _currentStep >= step;
    bool isCurrent = _currentStep == step;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Circle stop
        AnimatedContainer(
          duration: Duration(milliseconds: 300),
          width: isCurrent ? 44 : 36,
          height: isCurrent ? 44 : 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                isActive
                    ? Theme.of(context).colorScheme.secondary
                    : Colors.grey[300],
            border: Border.all(
              color:
                  isCurrent
                      ? Theme.of(context).colorScheme.secondary.withOpacity(0.3)
                      : Colors.transparent,
              width: isCurrent ? 8 : 0,
            ),
            boxShadow:
                isCurrent
                    ? [
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).colorScheme.secondary.withOpacity(0.4),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ]
                    : [],
          ),
          child: Center(
            child: Container(
              width: isCurrent ? 16 : 12,
              height: isCurrent ? 16 : 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? Colors.white : Colors.grey[400],
              ),
            ),
          ),
        ),
        SizedBox(height: 8),

        // Label
        Text(
          label,
          style: robotoMedium.copyWith(
            fontSize: isCurrent ? 13 : 12,
            color:
                isActive
                    ? Theme.of(context).colorScheme.secondary
                    : Colors.grey[400],
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildPhoneInputStep();
      case 1:
        return _buildOTPVerificationStep();
      case 2:
        return _buildSuccessStep();
      default:
        return SizedBox();
    }
  }

  Widget _buildPhoneInputStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 20),

        Text(
          'auth_welcome_to_waddy'.tr,
          style: robotoMedium.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 8),

        Text(
          'auth_enter_phone_to_get_started'.tr,
          style: robotoRegular.copyWith(fontSize: 14, color: Colors.grey[600]),
        ),
        SizedBox(height: 24),

        // Stepper
        _buildModernStepper(),
        SizedBox(height: 32),

        // Phone input with country code
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              CountryCodePicker(
                onChanged: (CountryCode countryCode) {
                  _countryDialCode = countryCode.dialCode;
                },
                initialSelection:
                    Get.find<SplashController>().configModel!.country,
                favorite: ['+966', '+20', '+971'],
                showCountryOnly: false,
                showOnlyCountryWhenClosed: false,
                alignLeft: false,
                padding: EdgeInsets.zero,
              ),
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: 'phone'.tr,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  style: robotoRegular.copyWith(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 32),

        // Continue button
        Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.4),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.secondary,
                blurRadius: 0,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _sendOTP,
              borderRadius: BorderRadius.circular(30),
              child: Center(
                child: Text(
                  'continue'.tr,
                  style: robotoMedium.copyWith(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOTPVerificationStep() {
    return Column(
      children: [
        SizedBox(height: 20),

        // Timer circle
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey[100],
            border: Border.all(
              color: Theme.of(context).primaryColor.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              '$_seconds',
              style: robotoMedium.copyWith(
                fontSize: 20,
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        SizedBox(height: 24),

        Text(
          'auth_to_confirm_your_account'.tr,
          textAlign: TextAlign.center,
          style: robotoRegular.copyWith(fontSize: 14, color: Colors.grey[600]),
        ),
        SizedBox(height: 4),

        Text(
          '${'auth_we_sent_to'.tr} $_phoneNumber',
          textAlign: TextAlign.center,
          style: robotoMedium.copyWith(fontSize: 14, color: Colors.black87),
        ),
        SizedBox(height: 24),

        // Stepper
        _buildModernStepper(),
        SizedBox(height: 32),

        // OTP Input
        PinCodeTextField(
          appContext: context,
          length: 6,
          controller: _otpController,
          keyboardType: TextInputType.number,
          animationType: AnimationType.fade,
          pinTheme: PinTheme(
            shape: PinCodeFieldShape.box,
            borderRadius: BorderRadius.circular(12),
            fieldHeight: 56,
            fieldWidth: 48,
            activeFillColor: Colors.white,
            inactiveFillColor: Colors.grey[100],
            selectedFillColor: Colors.white,
            activeColor: Theme.of(context).primaryColor,
            inactiveColor: Colors.grey[300]!,
            selectedColor: Theme.of(context).primaryColor,
          ),
          animationDuration: const Duration(milliseconds: 300),
          backgroundColor: Colors.transparent,
          enableActiveFill: true,
          errorAnimationController: errorController,
          onCompleted: (v) {
            _verifyOTP();
          },
          onChanged: (value) {},
        ),
        SizedBox(height: 24),

        // Resend code
        TextButton(
          onPressed: _seconds < 1 ? _sendOTP : null,
          child: Text(
            _seconds > 0
                ? '${'auth_resend_code_in'.tr} ${_seconds}s'
                : 'resend'.tr,
            style: robotoMedium.copyWith(
              fontSize: 14,
              color:
                  _seconds > 0 ? Colors.grey : Theme.of(context).primaryColor,
            ),
          ),
        ),
        SizedBox(height: 16),

        // Next button
        Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.4),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.secondary,
                blurRadius: 0,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _verifyOTP,
              borderRadius: BorderRadius.circular(30),
              child: Center(
                child: Text(
                  'next'.tr,
                  style: robotoMedium.copyWith(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessStep() {
    return Column(
      children: [
        SizedBox(height: 40),

        // Success animation
        ScaleTransition(
          scale: _successScaleAnimation,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).primaryColor,
              border: Border.all(
                color: Theme.of(context).colorScheme.secondary.withOpacity(0.4),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.secondary,
                  blurRadius: 0,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Icon(Icons.check, size: 60, color: Colors.white),
          ),
        ),
        SizedBox(height: 32),

        Text(
          'auth_logged_in_successfully'.tr,
          style: robotoMedium.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 12),

        Text(
          'auth_welcome_back_logged_in'.tr,
          textAlign: TextAlign.center,
          style: robotoRegular.copyWith(
            fontSize: 14,
            color: Colors.grey[600],
            height: 1.5,
          ),
        ),
        SizedBox(height: 40),

        // Complete button
        Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.4),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.secondary,
                blurRadius: 0,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Get.find<LocationController>().navigateToLocationScreen(
                  'verification',
                  offNamed: true,
                );
              },
              borderRadius: BorderRadius.circular(30),
              child: Center(
                child: Text(
                  'complete'.tr,
                  style: robotoMedium.copyWith(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedCards() {
    return Stack(
      children: [
        // Background circles decoration
        Positioned(
          top: 100,
          left: -50,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.secondary.withOpacity(0.4),
                width: 1,
              ),
            ),
          ),
        ),
        Positioned(
          top: 150,
          right: -80,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.secondary.withOpacity(0.4),
                width: 1,
              ),
            ),
          ),
        ),

        // Main calendar event card - centered
        Positioned(
          top: 80,
          left: 30,
          right: 30,
          child: AnimatedBuilder(
            animation: _cardAnimationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _card1OpacityAnimation,
                child: _buildCalendarEventCard(),
              );
            },
          ),
        ),

        // Speech bubble - top left

        // Bottom right avatars
      ],
    );
  }

  Widget _buildCalendarEventCard() {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFFE6D5F5).withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 30,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top section with date and time
          Container(
            padding: EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date box
                Column(
                  children: [
                    Text(
                      'APR',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8B7BA8),
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '10',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D1B4E),
                        height: 1,
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 20),

                // Time
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '09:00-10:00',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D1B4E),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Event details section
          Container(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Location
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: Color(0xFF8B7BA8)),
                    SizedBox(width: 4),
                    Text(
                      '1414 6th Ave, New York City',
                      style: TextStyle(fontSize: 12, color: Color(0xFF8B7BA8)),
                    ),
                  ],
                ),
                SizedBox(height: 12),

                // Event title and actions
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'auth_meeting_for_breakfast'.tr,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D1B4E),
                          height: 1.3,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    // Fire emoji
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Text('🔥', style: TextStyle(fontSize: 20)),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Participants and menu
                Row(
                  children: [
                    // Participant avatars
                    Stack(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFFFB6C1),
                            border: Border.all(
                              color: Color(0xFFE6D5F5),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        Positioned(
                          left: 24,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFDDA0DD),
                              border: Border.all(
                                color: Color(0xFFE6D5F5),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Spacer(),
                    // Three dot menu
                    Icon(Icons.more_vert, color: Color(0xFF2D1B4E), size: 24),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ArrowClipper extends CustomClipper<Path> {
  final bool isFirst;
  final bool isLast;

  ArrowClipper({this.isFirst = false, this.isLast = false});

  @override
  Path getClip(Size size) {
    Path path = Path();
    double arrowDepth = 12.0;

    // Start top left
    path.moveTo(isFirst ? 0 : arrowDepth, 0);

    // Top line
    path.lineTo(isLast ? size.width : size.width - arrowDepth, 0);

    // Right arrow point
    if (!isLast) {
      path.lineTo(size.width, size.height / 2);
      path.lineTo(size.width - arrowDepth, size.height);
    } else {
      path.lineTo(size.width, size.height);
    }

    // Bottom line
    path.lineTo(isFirst ? 0 : arrowDepth, size.height);

    // Left arrow cutout
    if (!isFirst) {
      path.lineTo(0, size.height / 2);
      path.lineTo(arrowDepth, 0);
    } else {
      path.lineTo(0, 0);
    }

    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
