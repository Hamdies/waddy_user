import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:waddy_app/features/auth/controllers/auth_controller.dart';
import 'package:waddy_app/features/auth/domain/enum/centralize_login_enum.dart';
import 'package:waddy_app/features/location/controllers/location_controller.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/verification/controllers/verification_controller.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:country_code_picker/country_code_picker.dart';

class UnifiedAuthScreen extends StatefulWidget {
  const UnifiedAuthScreen({super.key});

  @override
  State<UnifiedAuthScreen> createState() => _UnifiedAuthScreenState();
}

class _UnifiedAuthScreenState extends State<UnifiedAuthScreen> {
  int _currentStep = 0; // 0: Phone Input, 1: OTP Verification, 2: Name Input

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  String? _countryDialCode;
  String? _phoneNumber;
  String? _firebaseSession;
  Timer? _timer;
  int _seconds = 30;

  StreamController<ErrorAnimationType>? errorController;

  @override
  void initState() {
    super.initState();
    _countryDialCode =
        CountryCode.fromCountryCode(
          Get.find<SplashController>().configModel!.country!,
        ).dialCode;

    errorController = StreamController<ErrorAnimationType>();

    // Listen to phone controller changes
    _phoneController.addListener(() {
      setState(() {});
    });

    _otpController.addListener(() {
      setState(() {});
    });

    _nameController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
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
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: _phoneNumber!,
      verificationCompleted: (PhoneAuthCredential credential) {},
      verificationFailed: (FirebaseAuthException e) {
        if (e.code == 'invalid-phone-number') {
          showCustomSnackBar('please_submit_a_valid_phone_number'.tr);
        } else {
          showCustomSnackBar(e.message?.replaceAll('_', ' '));
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        _firebaseSession = verificationId;

        if (_currentStep != 1) {
          setState(() {
            _currentStep = 1;
          });
        }

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

    if (Get.find<SplashController>().configModel!.firebaseOtpVerification!) {
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
              setState(() {
                _currentStep = 2;
              });
            } else {
              errorController?.add(ErrorAnimationType.shake);
              showCustomSnackBar(value.message);
            }
          });
    }
  }

  void _completeName() {
    if (_nameController.text.trim().isEmpty) {
      showCustomSnackBar('Please enter your name');
      return;
    }

    // Navigate to location screen
    Get.find<LocationController>().navigateToLocationScreen(
      'verification',
      offNamed: true,
    );
  }

  void _goBack() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    } else {
      Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header with back button and Next button
            _buildHeader(),

            // Progress indicator
            _buildProgressIndicator(),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _buildStepContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    bool canProceed = false;

    switch (_currentStep) {
      case 0:
        canProceed = _phoneController.text.trim().length >= 9;
        break;
      case 1:
        canProceed = _otpController.text.length == 6;
        break;
      case 2:
        canProceed = _nameController.text.trim().isNotEmpty;
        break;
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E5E5), width: 1),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              onPressed: _goBack,
              padding: EdgeInsets.zero,
            ),
          ),

          // Next button
          TextButton(
            onPressed:
                canProceed
                    ? () {
                      switch (_currentStep) {
                        case 0:
                          _sendOTP();
                          break;
                        case 1:
                          _verifyOTP();
                          break;
                        case 2:
                          _completeName();
                          break;
                      }
                    }
                    : null,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'Next',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color:
                    canProceed
                        ? const Color(0xFF000000)
                        : const Color(0xFFBDBDBD),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Expanded(child: _buildProgressBar(0)),
          const SizedBox(width: 8),
          Expanded(child: _buildProgressBar(1)),
          const SizedBox(width: 8),
          Expanded(child: _buildProgressBar(2)),
        ],
      ),
    );
  }

  Widget _buildProgressBar(int step) {
    bool isActive = _currentStep >= step;
    bool isCurrent = _currentStep == step;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 4,
      decoration: BoxDecoration(
        color:
            isActive
                ? (isCurrent
                    ? const Color(0xFFFF6B6B)
                    : const Color(0xFFE0E0E0))
                : const Color(0xFFE0E0E0),
        borderRadius: BorderRadius.circular(2),
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
      default:
        return const SizedBox();
    }
  }

  Widget _buildPhoneInputStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),

        // Title
        const Text(
          'Enter your\nPhone Number',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: Color(0xFF000000),
            height: 1.2,
          ),
        ),

        const SizedBox(height: 40),

        // Phone input field
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Country code picker
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Text(
                  _countryDialCode ?? '+1',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF000000),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(width: 1, height: 24, color: const Color(0xFFE0E0E0)),
              const SizedBox(width: 12),

              // Phone number input
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF000000),
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: const InputDecoration(
                    hintText: '+12 345 6789012',
                    hintStyle: TextStyle(
                      fontSize: 16,
                      color: Color(0xFFBDBDBD),
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 0,
                      vertical: 18,
                    ),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(15),
                  ],
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Next button (large)
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed:
                _phoneController.text.trim().length >= 9 ? _sendOTP : null,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _phoneController.text.trim().length >= 9
                      ? const Color(0xFF000000)
                      : const Color(0xFFBDBDBD),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor: const Color(0xFFBDBDBD),
              disabledForegroundColor: Colors.white,
            ),
            child: const Text(
              'Next',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOTPVerificationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),

        // Title
        const Text(
          'Enter\nConfirmation Code',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: Color(0xFF000000),
            height: 1.2,
          ),
        ),

        const SizedBox(height: 16),

        // Subtitle
        Text(
          'We sent a 6-digit code to\n$_phoneNumber',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF757575),
            height: 1.5,
          ),
        ),

        const SizedBox(height: 40),

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
            activeFillColor: const Color(0xFFF5F5F5),
            inactiveFillColor: const Color(0xFFF5F5F5),
            selectedFillColor: const Color(0xFFF5F5F5),
            activeColor: const Color(0xFF000000),
            inactiveColor: const Color(0xFFE0E0E0),
            selectedColor: const Color(0xFF000000),
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

        const SizedBox(height: 24),

        // Resend code
        Center(
          child: TextButton(
            onPressed: _seconds < 1 ? _sendOTP : null,
            child: Text(
              _seconds > 0 ? 'Resend code in ${_seconds}s' : 'Resend code',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color:
                    _seconds > 0
                        ? const Color(0xFFBDBDBD)
                        : const Color(0xFF000000),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNameInputStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),

        // Title
        const Text(
          'What\'s your\nName?',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: Color(0xFF000000),
            height: 1.2,
          ),
        ),

        const SizedBox(height: 40),

        // Name input field
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _nameController,
            keyboardType: TextInputType.name,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF000000),
              fontWeight: FontWeight.w500,
            ),
            decoration: const InputDecoration(
              hintText: 'Enter your full name',
              hintStyle: TextStyle(
                fontSize: 16,
                color: Color(0xFFBDBDBD),
                fontWeight: FontWeight.w400,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
            ),
          ),
        ),

        const SizedBox(height: 32),

        // Complete button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed:
                _nameController.text.trim().isNotEmpty ? _completeName : null,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _nameController.text.trim().isNotEmpty
                      ? const Color(0xFF000000)
                      : const Color(0xFFBDBDBD),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor: const Color(0xFFBDBDBD),
              disabledForegroundColor: Colors.white,
            ),
            child: const Text(
              'Complete',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
