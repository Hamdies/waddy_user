import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:country_code_picker/country_code_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';
import 'package:waddy_app/features/profile/domain/models/update_user_model.dart';
import 'package:waddy_app/common/widgets/custom_button.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/features/auth/controllers/auth_controller.dart';
import 'package:waddy_app/features/auth/domain/enum/centralize_login_enum.dart';
import 'package:waddy_app/features/auth/screens/auth_utils.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/verification/controllers/verification_controller.dart';
import 'package:waddy_app/util/images.dart';
import 'package:waddy_app/util/dimensions.dart';

/// Phone → OTP (→ optional name) flow, shared by the full-screen
/// UnifiedAuthScreen and the checkout auth bottom sheet.
///
/// Calls [onSuccess] once the user holds a valid token — it never navigates
/// by itself, so hosts decide what happens next (route home, re-init
/// checkout, close a sheet...).
///
/// With [showNameStep] false, a brand-new account is completed silently with
/// a placeholder name ("Guest") — checkout captures the real name via the
/// delivery address form moments later.
class AuthFlowWidget extends StatefulWidget {
  final VoidCallback onSuccess;
  final bool compact;
  final bool showNameStep;
  final ValueChanged<int>? onStepChanged;

  /// Opens straight on the name step for a user whose phone is already
  /// verified but who never submitted a name. Requires [resumePhone].
  final bool startAtNameStep;
  final String? resumePhone;

  const AuthFlowWidget({
    super.key,
    required this.onSuccess,
    this.compact = false,
    this.showNameStep = true,
    this.onStepChanged,
    this.startAtNameStep = false,
    this.resumePhone,
  });

  @override
  State<AuthFlowWidget> createState() => AuthFlowWidgetState();
}

class AuthFlowWidgetState extends State<AuthFlowWidget>
    with TickerProviderStateMixin {
  static const int stepPhone = 0;
  static const int stepOtp = 1;
  static const int stepName = 2;

  int _currentStep = stepPhone;
  int get currentStep => _currentStep;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  late final AnimationController _shakeController;
  late final AnimationController _checkmarkController;
  late final Animation<double> _checkmarkScale;
  late final AnimationController _giftShakeController;
  late final AnimationController _otpCursorController;

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  /// One real field backs all six boxes. SMS autofill delivers the whole code
  /// to a single input — split across six fields the platform never fills any
  /// of them, which is why the boxes are painted from this controller's text.
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();

  String? _countryDialCode;
  String? _phoneNumber;
  String? _firebaseSession;
  XFile? _pickedImage;
  DateTime? _birthday;
  bool _isLoading = false;
  Timer? _timer;
  int _seconds = 30;
  String? _otpError;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _checkmarkController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _checkmarkScale = CurvedAnimation(
      parent: _checkmarkController,
      curve: Curves.elasticOut,
    );

    // Gift emoji wiggle: ~0.9s of motion, then a beat of stillness.
    _giftShakeController = AnimationController(
      duration: const Duration(milliseconds: 2200),
      vsync: this,
    )..repeat();

    // Blinking caret for the active OTP box.
    _otpCursorController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();

    _otpFocusNode.addListener(() {
      if (mounted) setState(() {});
    });

    _countryDialCode =
        CountryCode.fromCountryCode(
          Get.find<SplashController>().configModel.country!,
        ).dialCode;

    // Resuming an interrupted signup: the phone is already verified, so jump
    // to the name step with it restored for the submit call.
    if (widget.startAtNameStep && widget.resumePhone != null) {
      _currentStep = stepName;
      _phoneNumber = widget.resumePhone;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onStepChanged?.call(stepName);
      });
    }

    _phoneController.addListener(() {
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
    _checkmarkController.dispose();
    _giftShakeController.dispose();
    _otpCursorController.dispose();
    _phoneController.dispose();
    _nameController.dispose();
    _otpController.dispose();
    _otpFocusNode.dispose();
    _timer?.cancel();
    super.dispose();
  }

  /// Steps back inside the flow. Returns false when already on the first
  /// step, i.e. the host should handle the back action itself.
  bool handleBack() {
    // A resumed flow has no earlier steps to return to — the phone is
    // already verified server-side.
    if (widget.startAtNameStep) return true;
    if (_currentStep > stepPhone) {
      _changeStep(_currentStep - 1);
      return true;
    }
    return false;
  }

  /// Drops the keyboard. Used the moment a field is *complete* — a finished
  /// phone number or a full OTP — so the primary button and any error text
  /// aren't left buried under the keyboard on short screens, which is the
  /// common case inside the checkout sheet (85% of a viewport, minus the
  /// keyboard, is not much).
  void _dismissKeyboard() {
    if (!mounted) return;
    FocusScope.of(context).unfocus();
  }

  void _changeStep(int newStep) {
    if (!mounted) return;
    _fadeController.reverse().then((_) {
      if (!mounted) return;
      setState(() {
        _currentStep = newStep;
      });
      widget.onStepChanged?.call(newStep);
      _fadeController.forward();
    });
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

    _dismissKeyboard();

    setState(() {
      _isLoading = true;
    });

    _phoneNumber = _countryDialCode! + rawPhone;

    if (_currentStep == stepOtp) {
      _triggerFirebaseVerification();
      return;
    }

    Get.find<AuthController>()
        .otpLogin(
          phone: _phoneNumber!,
          otp: '',
          loginType: CentralizeLoginType.otp.name,
          verified: '',
        )
        .then((response) {
          if (response.isSuccess) {
            if (response.authResponseModel != null &&
                !response.authResponseModel!.isPhoneVerified!) {
              if (Get.find<SplashController>()
                  .configModel
                  .firebaseOtpVerification!) {
                _triggerFirebaseVerification();
              } else {
                setState(() {
                  _isLoading = false;
                });
                _changeStep(stepOtp);
                _startTimer();
              }
            } else {
              // Defensive: a success response that doesn't request OTP
              // (e.g. backend reports the phone already verified) must not
              // leave the button spinning forever.
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
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
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: _phoneNumber!,
      verificationCompleted: (PhoneAuthCredential credential) {},
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

        if (_currentStep != stepOtp) {
          _changeStep(stepOtp);
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
    String otp = _otpController.text;

    if (otp.length < 6) {
      showCustomSnackBar('please_enter_valid_otp'.tr);
      return;
    }

    // The code is in — let the keyboard go so the result isn't hidden behind it.
    _dismissKeyboard();

    Get.find<VerificationController>().updateVerificationCode(otp);

    if (Get.find<SplashController>().configModel.firebaseOtpVerification!) {
      Get.find<VerificationController>()
          .verifyFirebaseOtp(
            phoneNumber: _phoneNumber!,
            session: _firebaseSession ?? '',
            otp: otp,
            loginType: CentralizeLoginType.otp.name,
            token: '',
            isSignUpPage: false,
            isForgetPassPage: false,
          )
          .then((value) {
            if (value.isSuccess) {
              bool isProfileComplete = false;
              if (value.authResponseModel != null &&
                  value.authResponseModel!.isPersonalInfo == true &&
                  value.authResponseModel!.token != null) {
                isProfileComplete = true;
              }

              if (isProfileComplete) {
                widget.onSuccess();
              } else if (widget.showNameStep) {
                _changeStep(stepName);
              } else {
                _completeProfileSilently();
              }
            } else {
              _otpController.clear();
              _shakeController.forward(from: 0.0);
              HapticFeedback.heavyImpact();
              _otpFocusNode.requestFocus();
              setState(() {
                _otpError = value.message;
              });
            }
          });
    }
  }

  /// Sheet flow for brand-new accounts: finish registration with a
  /// placeholder name so the user isn't blocked mid-checkout. The real name
  /// arrives with the delivery address they fill in right after.
  void _completeProfileSilently() {
    setState(() {
      _isLoading = true;
    });
    Get.find<AuthController>()
        .updatePersonalInfo(
          name: 'Guest',
          phone: _phoneNumber,
          loginType: CentralizeLoginType.otp.name,
          email: null,
          referCode: '',
        )
        .then((response) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
          });
          if (response.isSuccess) {
            widget.onSuccess();
          } else {
            showCustomSnackBar(response.message);
          }
        });
  }

  void _completeName() {
    String name = _nameController.text.trim();

    if (name.isEmpty) {
      showCustomSnackBar('auth_name_placeholder'.tr);
      return;
    }

    Get.find<AuthController>()
        .updatePersonalInfo(
          name: name,
          phone: _phoneNumber,
          loginType: CentralizeLoginType.otp.name,
          email: null,
          referCode: '',
        )
        .then((response) async {
          if (response.isSuccess) {
            await _saveOptionalProfileExtras(name);
            widget.onSuccess();
          } else {
            showCustomSnackBar(response.message);
          }
        });
  }

  /// The name goes up with `updatePersonalInfo`, but the avatar (and the
  /// birthday) need the multipart `update-profile` endpoint — a separate call
  /// made once the account exists. Both are optional, so a failure here must
  /// never block sign-in.
  ///
  /// NOTE: the backend's update_profile validator currently accepts only
  /// name/email/phone/image/password and `users` has no birth-date column,
  /// so `birthDate` is ignored server-side until that lands. The app sends it
  /// already; no client change is needed once the column exists.
  Future<void> _saveOptionalProfileExtras(String name) async {
    if (_pickedImage == null && _birthday == null) return;

    ProfileController profileController = Get.find<ProfileController>();
    profileController.setPickedFile(_pickedImage);
    try {
      await profileController.updateUserInfo(
        UpdateUserModel(
          name: name,
          phone: _phoneNumber,
          buttonType: 'update_profile',
          birthDate: _birthday == null ? null : _isoDate(_birthday!),
        ),
        Get.find<AuthController>().getUserToken(),
        fromVerification: true,
      );
    } catch (_) {
      // Both fields are optional; swallow so auth still completes.
    } finally {
      profileController.setPickedFile(null);
    }
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: switch (_currentStep) {
        stepOtp => _buildOtpStep(),
        stepName => _buildNameStep(),
        _ => _buildPhoneStep(),
      },
    );
  }

  Widget _buildHeroAnimation({double width = 140}) {
    if (widget.compact) return const SizedBox();
    return Column(
      children: [
        Center(child: Image.asset(Images.logoNoBg, width: width)),
        const SizedBox(height: 50),
      ],
    );
  }

  Widget _buildPhoneStep() {
    String rawText = _phoneController.text.replaceAll(' ', '');
    bool isLengthValid = rawText.length == 10;
    bool isPrefixValid = rawText.startsWith('1');
    bool isValid = isLengthValid && isPrefixValid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroAnimation(),
        Text(
          'auth_enter_your_phone'.tr,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).primaryColor,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'auth_verification_code_subtitle'.tr,
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).primaryColor.withValues(alpha: 0.6),
          ),
        ),
        SizedBox(height: widget.compact ? 24 : 40),

        ShakeWidget(
          controller: _shakeController,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  CountryCodePicker(
                    onChanged: (country) {
                      setState(() {
                        _countryDialCode = country.dialCode;
                      });
                    },
                    initialSelection:
                        Get.find<SplashController>().configModel.country!,
                    favorite: [
                      Get.find<SplashController>().configModel.country!,
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
                  Expanded(
                    child: Semantics(
                      label: "Phone number input",
                      hint: "Enter your 10-digit mobile number starting with 1",
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
                          hintText: '10 1234 5678',
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
                          String raw = value.replaceAll(' ', '');
                          final wasValid = raw.length > 10;
                          final nowValid =
                              raw.length == 10 && raw.startsWith('1');
                          if (nowValid && !wasValid) {
                            HapticFeedback.lightImpact();
                            _checkmarkController.forward(from: 0);
                            // Number is complete: get out of the way so the
                            // continue button is visible without a scroll.
                            _dismissKeyboard();
                          } else if (!nowValid) {
                            _checkmarkController.reverse();
                          }
                          setState(() {});
                        },
                      ),
                    ),
                  ),
                  if (isValid)
                    Padding(
                      padding: const EdgeInsets.only(
                        right: Dimensions.paddingSizeDefault,
                      ),
                      child: ScaleTransition(
                        scale: _checkmarkScale,
                        child: Icon(
                          Icons.check_circle,
                          color: Theme.of(context).secondaryHeaderColor,
                          size: 22,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.only(
            top: Dimensions.paddingSizeSmall,
            left: Dimensions.paddingSizeExtraSmall,
            right: Dimensions.paddingSizeExtraSmall,
          ),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              'auth_digits_counter'.trParams({'count': '${rawText.length}'}),
              style: TextStyle(
                fontSize: 12,
                color:
                    isValid
                        ? Theme.of(context).primaryColor
                        : Theme.of(context).primaryColor.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),

        SizedBox(height: widget.compact ? 24 : 32),

        CustomButton(
          buttonText: 'next'.tr,
          onPressed: (isValid && !_isLoading) ? _sendOTP : null,
          isLoading: _isLoading,
          icon: Icons.arrow_forward,
        ),
      ],
    );
  }

  /// Returns to the phone step with the number restored for editing, so
  /// "wrong number" doesn't mean retyping it from scratch.
  void _editPhoneNumber() {
    _timer?.cancel();
    final String dial = _countryDialCode ?? '';
    if (_phoneNumber != null && _phoneNumber!.startsWith(dial)) {
      final String local = _phoneNumber!.substring(dial.length);
      _phoneController.value = TextEditingValue(
        text:
            EgyptianPhoneFormatter()
                .formatEditUpdate(
                  TextEditingValue.empty,
                  TextEditingValue(text: local),
                )
                .text,
      );
    }
    _otpController.clear();
    setState(() {
      _otpError = null;
      _seconds = 0;
      _isLoading = false;
    });
    _changeStep(stepPhone);
  }

  Widget _buildOtpStep() {
    String otp = _otpController.text;
    bool isOtpComplete = otp.length == 6;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.compact) ...[
          const SizedBox(height: 16),
          Center(child: Image.asset(Images.logoNoBg, width: 140)),
          const SizedBox(height: 16),
        ],
        Text(
          'auth_enter_code_title'.tr,
          style: TextStyle(
            fontSize: widget.compact ? 22 : 28,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).primaryColor,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        _buildSentToLine(),
        SizedBox(height: widget.compact ? 24 : 32),

        _buildOtpBoxes(otp),

        const SizedBox(height: 12),

        if (_otpError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 15),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _otpError!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

        Row(
          children: [
            Expanded(
              child:
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
                            const TextSpan(text: ' '),
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
                      : _buildOtpAction(
                        icon: Icons.refresh,
                        label: 'auth_resend_code'.tr,
                        onTap: _isLoading ? null : _sendOTP,
                      ),
            ),
            const SizedBox(width: Dimensions.paddingSizeMedium),
            _buildOtpAction(
              icon: Icons.edit_outlined,
              label: 'auth_edit_phone_number'.tr,
              onTap: _isLoading ? null : _editPhoneNumber,
            ),
          ],
        ),

        SizedBox(height: widget.compact ? 24 : 48),

        GetBuilder<VerificationController>(
          builder: (verificationController) {
            return CustomButton(
              buttonText: 'verify'.tr,
              onPressed:
                  (isOtpComplete &&
                          !verificationController.isLoading &&
                          !_isLoading)
                      ? _verifyOTP
                      : null,
              isLoading: verificationController.isLoading || _isLoading,
            );
          },
        ),
      ],
    );
  }

  /// "Sent to +20… Check your messages." with only the number underlined, so
  /// the tappable part looks tappable. The number always renders LTR — an
  /// Arabic locale would otherwise flip the leading '+' to the wrong end.
  Widget _buildSentToLine() {
    final Color primary = Theme.of(context).primaryColor;
    final String template = 'auth_sent_to_verify'.tr;
    final String phone = _phoneNumber ?? '';
    final int slot = template.indexOf('@phone');

    final TextStyle base = TextStyle(
      fontSize: 15,
      color: primary.withValues(alpha: 0.6),
      height: 1.4,
    );

    // Missing placeholder: fall back to the plain interpolated string rather
    // than dropping the number entirely.
    if (slot < 0) {
      return Text(template.replaceAll('@phone', phone), style: base);
    }

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: template.substring(0, slot), style: base),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: _isLoading ? null : _editPhoneNumber,
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  phone,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    color: primary,
                    decoration: TextDecoration.underline,
                    decorationColor: primary.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ),
          TextSpan(
            text: template.substring(slot + '@phone'.length),
            style: base,
          ),
        ],
      ),
      style: base,
    );
  }

  /// Six boxes painted from a single hidden field. Splitting the code across
  /// six real inputs breaks SMS autofill — the platform hands the whole code
  /// to one field — so the boxes are display-only and all editing, selection
  /// and autofill happen in [_otpController].
  Widget _buildOtpBoxes(String otp) {
    final Color primary = Theme.of(context).primaryColor;
    final Color accent = Theme.of(context).secondaryHeaderColor;
    final bool isFocused = _otpFocusNode.hasFocus;
    final bool hasError = _otpError != null;

    return ShakeWidget(
      controller: _shakeController,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                const double gap = 10;
                final double boxWidth = ((constraints.maxWidth - (5 * gap)) / 6)
                    .clamp(40.0, 52.0);
                const double boxHeight = 58.0;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (index) {
                    final bool hasValue = index < otp.length;
                    // The caret sits on the next empty box; once all six are
                    // filled it parks on the last one instead of vanishing.
                    final bool isActive =
                        isFocused &&
                        (index == otp.length ||
                            (otp.length == 6 && index == 5));

                    return Padding(
                      padding: EdgeInsets.only(right: index < 5 ? gap : 0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        width: boxWidth,
                        height: boxHeight,
                        decoration: BoxDecoration(
                          color:
                              hasError
                                  ? Colors.red.withValues(alpha: 0.04)
                                  : hasValue
                                  ? primary.withValues(alpha: 0.06)
                                  : primary.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusDefault,
                          ),
                          // The mint border alone marks the active box — at
                          // this size a glow just reads as a smudge.
                          border: Border.all(
                            color:
                                hasError
                                    ? Colors.red.withValues(alpha: 0.55)
                                    : isActive
                                    ? accent
                                    : hasValue
                                    ? primary.withValues(alpha: 0.35)
                                    : primary.withValues(alpha: 0.10),
                            width: isActive || hasValue ? 1.5 : 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child:
                            hasValue
                                ? _buildOtpDigit(otp[index], index, primary)
                                : isActive
                                ? _buildOtpCaret(accent)
                                : const SizedBox.shrink(),
                      ),
                    );
                  }),
                );
              },
            ),

            // The real input: full-bleed and invisible, so a tap anywhere on
            // the row opens the keyboard and the OS can autofill it.
            Positioned.fill(
              child: AutofillGroup(
                child: TextField(
                  controller: _otpController,
                  focusNode: _otpFocusNode,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  enableInteractiveSelection: false,
                  showCursor: false,
                  maxLength: 6,
                  // Transparent rather than Opacity: an opacity-0 subtree can
                  // be skipped for hit-testing on some platforms, and the
                  // field must stay tappable.
                  style: const TextStyle(
                    color: Colors.transparent,
                    fontSize: 1,
                    height: 0.1,
                  ),
                  cursorColor: Colors.transparent,
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  onChanged: _onOtpChanged,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onOtpChanged(String value) {
    // Keep the caret at the end — a stray tap must not let the user type
    // into the middle of the code while the boxes render left-to-right.
    if (_otpController.selection.baseOffset != value.length) {
      _otpController.selection = TextSelection.collapsed(offset: value.length);
    }

    setState(() {
      _otpError = null;
    });

    if (value.isNotEmpty) HapticFeedback.selectionClick();

    if (value.length == 6) {
      HapticFeedback.lightImpact();
      // Dismiss here rather than relying on _verifyOTP's unfocus: this covers
      // the autofilled-code path too, and it happens before the network call
      // so the keyboard never sits over the spinner.
      _dismissKeyboard();
      _verifyOTP();
    }
  }

  /// A digit settles into its box: fades in while rising and easing out of a
  /// slight overshoot. Keyed by value so re-entering a different digit
  /// replays it, and scaling stays inside the box — the old bounce grew the
  /// whole container past its neighbours.
  Widget _buildOtpDigit(String digit, int index, Color primary) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('otp_${index}_$digit'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 8),
            child: Transform.scale(scale: 0.85 + (0.15 * t), child: child),
          ),
        );
      },
      child: Text(
        digit,
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: primary,
        ),
      ),
    );
  }

  Widget _buildOtpCaret(Color accent) {
    return FadeTransition(
      // Ease the blink rather than hard-toggling it; a snapping caret is the
      // single most distracting thing on this screen.
      opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _otpCursorController, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 2,
        height: 24,
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(Dimensions.radiusExtraSmall / 4),
        ),
      ),
    );
  }

  Widget _buildOtpAction({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    final Color primary = Theme.of(context).primaryColor;
    final bool enabled = onTap != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: Dimensions.paddingSizeSmall,
          horizontal: Dimensions.paddingSizeExtraSmall,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: primary.withValues(alpha: enabled ? 1 : 0.4),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: primary.withValues(alpha: enabled ? 1 : 0.4),
                  decoration: TextDecoration.underline,
                  decorationColor: primary.withValues(alpha: 0.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Optional avatar for the name step. Empty state shows the Waddy W mark
  /// tinted dark grey rather than a photo-shaped placeholder.
  Widget _buildAvatarPicker() {
    final double size = widget.compact ? 88 : 104;
    final Color primary = Theme.of(context).primaryColor;
    final Color accent = Theme.of(context).secondaryHeaderColor;

    return GestureDetector(
      onTap: _pickProfileImage,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary.withValues(alpha: 0.05),
                  border: Border.all(
                    color:
                        _pickedImage != null
                            ? accent
                            : primary.withValues(alpha: 0.15),
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child:
                      _pickedImage != null
                          ? (Image.file(
                            File(_pickedImage!.path),
                            width: size,
                            height: size,
                            fit: BoxFit.cover,
                          ))
                          // Empty state: the W mark tinted dark grey, inset so
                          // the glyph doesn't touch the circle's edge.
                          : Padding(
                            padding: EdgeInsets.all(size * 0.22),
                            child: ColorFiltered(
                              colorFilter: const ColorFilter.mode(
                                Color(0xFF6B7280),
                                BlendMode.srcIn,
                              ),
                              child: Image.asset(
                                Images.logoMarkTransparent,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFDFDFD),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    _pickedImage != null ? Icons.edit : Icons.camera_alt,
                    size: 15,
                    color: primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'auth_add_profile_photo'.tr,
            style: TextStyle(
              fontSize: 13,
              color: primary.withValues(alpha: 0.5),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _pickProfileImage() async {
    XFile? picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;

    // Mirror the profile screen's cap so the multipart upload isn't rejected.
    final int length = await picked.length();
    if (!mounted) return;
    if (length > 1000000) {
      showCustomSnackBar('please_upload_lower_size_file'.tr);
      return;
    }
    setState(() {
      _pickedImage = picked;
    });
  }

  /// Birthday is optional and only used to send a real gift on the day —
  /// hence the gift emoji that wiggles once a date is set.
  Widget _buildBirthdayField() {
    final Color primary = Theme.of(context).primaryColor;
    final Color accent = Theme.of(context).secondaryHeaderColor;
    final bool hasDate = _birthday != null;

    return GestureDetector(
      onTap: _pickBirthday,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
          border: Border.all(
            color: hasDate ? accent : primary.withValues(alpha: 0.15),
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: Dimensions.paddingSizeDefault,
          vertical: 18,
        ),
        child: Row(
          children: [
            _buildWigglingGift(),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hasDate
                    ? _formatBirthday(_birthday!)
                    : 'auth_birthday_placeholder'.tr,
                style: TextStyle(
                  fontSize: 16,
                  color: hasDate ? primary : primary.withValues(alpha: 0.35),
                  fontWeight: hasDate ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
            Icon(
              hasDate ? Icons.edit_calendar : Icons.calendar_today,
              size: 18,
              color: primary.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWigglingGift() {
    return AnimatedBuilder(
      animation: _giftShakeController,
      builder: (context, child) {
        // Wiggle over the first 40% of each cycle, then rest — a periodic
        // nudge reads as playful where a constant shake just nags.
        final double t = _giftShakeController.value;
        final double angle =
            t < 0.4
                ? math.sin(t / 0.4 * math.pi * 3) * 0.30 * (1 - t / 0.4)
                : 0.0;
        return Transform.rotate(angle: angle, child: child);
      },
      child: const Text('🎁', style: TextStyle(fontSize: 20)),
    );
  }

  String _formatBirthday(DateTime date) {
    const List<String> months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  void _pickBirthday() async {
    final DateTime now = DateTime.now();
    final DateTime initial =
        _birthday ?? DateTime(now.year - 20, now.month, now.day);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      // 13+ keeps it sane; 100 years covers everyone else.
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 13, now.month, now.day),
      helpText: 'auth_birthday_picker_help'.tr,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              onSurface: Theme.of(context).primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) return;
    setState(() {
      _birthday = picked;
    });
    HapticFeedback.lightImpact();
  }

  Widget _buildNameStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: widget.compact ? 8 : 16),
        Text(
          'auth_name_step_title'.tr,
          style: TextStyle(
            fontSize: widget.compact ? 24 : 32,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).primaryColor,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'auth_name_step_subtitle'.tr,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).primaryColor.withValues(alpha: 0.6),
            height: 1.4,
          ),
        ),
        SizedBox(height: widget.compact ? 20 : 32),
        Center(child: _buildAvatarPicker()),
        SizedBox(height: widget.compact ? 20 : 32),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
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
                horizontal: Dimensions.paddingSizeDefault,
                vertical: 18,
              ),
              prefixIcon: Icon(
                Icons.person_outline,
                color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _buildBirthdayField(),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(
            left: Dimensions.paddingSizeExtraSmall,
            right: Dimensions.paddingSizeExtraSmall,
          ),
          child: Text(
            'auth_birthday_hint'.tr,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 32),
        GetBuilder<AuthController>(
          builder: (authController) {
            return CustomButton(
              buttonText: 'auth_complete'.tr,
              onPressed:
                  (_nameController.text.trim().isNotEmpty &&
                          !authController.isLoading)
                      ? _completeName
                      : null,
              isLoading: authController.isLoading,
              icon: Icons.arrow_forward,
            );
          },
        ),
      ],
    );
  }
}
