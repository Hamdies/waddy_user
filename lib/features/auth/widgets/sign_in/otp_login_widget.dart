import 'dart:async';
import 'dart:math';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/auth/controllers/auth_controller.dart';
import 'package:waddy_app/features/auth/widgets/social_login_widget.dart';
import 'package:waddy_app/helper/responsive_helper.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/helper/validate_check.dart';
import 'package:waddy_app/features/language/controllers/language_controller.dart';

class OtpLoginWidget extends StatefulWidget {
  final bool socialEnable;
  final FocusNode phoneFocus;
  final TextEditingController phoneController;
  final Function(CountryCode countryCode) onCountryChanged;
  final String? countryDialCode;
  final Function() onClickLoginButton;

  const OtpLoginWidget({
    super.key,
    required this.socialEnable,
    required this.phoneFocus,
    required this.phoneController,
    required this.onCountryChanged,
    required this.countryDialCode,
    required this.onClickLoginButton,
  });

  @override
  State<OtpLoginWidget> createState() => _OtpLoginWidgetState();
}

class _OtpLoginWidgetState extends State<OtpLoginWidget>
    with TickerProviderStateMixin {
  bool _isButtonPressed = false;
  bool _isPhoneFocused = false;
  bool _shouldShake = false;
  Timer? _emptyFieldTimer;
  late AnimationController _shakeController;
  late AnimationController _focusController;
  late AnimationController _typingController;
  late Animation<double> _shakeAnimation;
  late Animation<double> _focusScaleAnimation;
  late Animation<double> _focusOpacityAnimation;
  late Animation<double> _typingPulseAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _focusController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _typingController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    _focusScaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _focusController, curve: Curves.easeInOut),
    );

    _focusOpacityAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _focusController, curve: Curves.easeInOut),
    );

    _typingPulseAnimation = Tween<double>(begin: 1.0, end: 1.01).animate(
      CurvedAnimation(parent: _typingController, curve: Curves.easeInOut),
    );

    widget.phoneFocus.addListener(() {
      setState(() {
        _isPhoneFocused = widget.phoneFocus.hasFocus;
      });
      if (_isPhoneFocused) {
        _focusController.forward();
      } else {
        _focusController.reverse();
      }
    });

    widget.phoneController.addListener(() {
      if (widget.phoneController.text.isNotEmpty) {
        _typingController.forward();
      } else {
        _typingController.reverse();
      }
    });
  }

  void _startContinuousShake() {
    if (_shouldShake) {
      _shakeController.forward().then((_) {
        if (_shouldShake) {
          _shakeController.reverse().then((_) {
            if (_shouldShake) {
              _startContinuousShake();
            }
          });
        }
      });
    }
  }

  void _stopContinuousShake() {
    _shouldShake = false;
    _shakeController.stop();
    _shakeController.reset();
  }

  @override
  void dispose() {
    _emptyFieldTimer?.cancel();
    _shakeController.dispose();
    _focusController.dispose();
    _typingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AuthController>(
      builder: (authController) {
        return Column(
          children: [
            Text(
              'hey_welcome_back'.tr,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
                letterSpacing: 0.2,
                height: 1.1,
              ),
            ),
            SizedBox(height: 12),
            _buildPhoneInputField(),
            const SizedBox(height: 24),
            _buildModernRememberMe(context, authController),
            const SizedBox(height: 16),
            _buildModernTermsConditions(context),
            const SizedBox(height: 24),
            _buildModernLoginButton(context, authController),
            const SizedBox(height: 32),
            if (widget.socialEnable) const SocialLoginWidget(),
          ],
        );
      },
    );
  }

  Widget _buildPhoneInputField() {
    return AnimatedBuilder(
      animation: Listenable.merge([_focusController, _typingController]),
      builder: (context, child) {
        return Transform.scale(
          scale: _focusScaleAnimation.value * _typingPulseAnimation.value,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              color: _isPhoneFocused ? Colors.white : const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    _isPhoneFocused
                        ? const Color(0xFF6B7280)
                        : Colors.transparent,
                width: _isPhoneFocused ? 2 : 0,
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      _isPhoneFocused
                          ? const Color(
                            0xFF6B7280,
                          ).withOpacity(0.1 * _focusOpacityAnimation.value)
                          : Colors.transparent,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: TextFormField(
              controller: widget.phoneController,
              focusNode: widget.phoneFocus,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              validator:
                  (value) =>
                      ValidateCheck.validateEmptyText(value, "phone_number".tr),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1F2937),
                letterSpacing: 0.2,
              ),
              decoration: InputDecoration(
                labelText: 'phone'.tr,
                labelStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color:
                      _isPhoneFocused
                          ? const Color(0xFF374151)
                          : const Color(0xFF9CA3AF),
                  letterSpacing: 0.2,
                ),
                floatingLabelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color:
                      _isPhoneFocused
                          ? const Color(0xFF374151)
                          : const Color(0xFF6B7280),
                  letterSpacing: 0.3,
                ),
                prefixIcon: Container(
                  padding: const EdgeInsets.only(left: 8, right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CountryCodePicker(
                        onChanged: widget.onCountryChanged,
                        initialSelection: 'EG',
                        favorite: const ['EG'],
                        countryFilter: const ['EG'],
                        showCountryOnly: true,
                        showOnlyCountryWhenClosed: true,
                        showFlag: true,
                        showDropDownButton: false,
                        enabled: false,
                        alignLeft: false,
                        flagWidth: 24,
                        textStyle: const TextStyle(
                          fontSize: 0,
                          fontWeight: FontWeight.w500,
                          color: Colors.transparent,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 24,
                        color: const Color(0xFFE5E7EB),
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      Text(
                        widget.countryDialCode ?? '+20',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF374151),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                filled: true,
                fillColor:
                    _isPhoneFocused ? Colors.white : const Color(0xFFFAFAFA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: Color(0xFF6B7280),
                    width: 2,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Colors.red, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernRememberMe(
    BuildContext context,
    AuthController authController,
  ) {
    return GestureDetector(
      onTap: () => authController.toggleRememberMe(),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color:
                      authController.isActiveRememberMe
                          ? const Color(0xFF0F766E)
                          : const Color(0xFFD1D5DB),
                  width: authController.isActiveRememberMe ? 2 : 1.5,
                ),
                color:
                    authController.isActiveRememberMe
                        ? const Color(0xFF0F766E)
                        : Colors.transparent,
              ),
              child:
                  authController.isActiveRememberMe
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
            ),
            const SizedBox(width: 12),
            Text(
              'remember_me'.tr,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernTermsConditions(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF6B7280),
          height: 1.4,
          letterSpacing: 0.2,
        ),
        children: [
          TextSpan(text: 'by_continuing_you_agree_our'.tr),
          const TextSpan(text: ' '),
          TextSpan(
            text: 'terms_of_service'.tr,
            style: const TextStyle(
              color: Color(0xFF0F766E),
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
            ),
          ),
          const TextSpan(text: ' '),
          TextSpan(text: 'and'.tr),
          const TextSpan(text: ' '),
          TextSpan(
            text: 'privacy_policy'.tr,
            style: const TextStyle(
              color: Color(0xFF0F766E),
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernLoginButton(
    BuildContext context,
    AuthController authController,
  ) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isButtonPressed = true),
      onTapUp: (_) => setState(() => _isButtonPressed = false),
      onTapCancel: () => setState(() => _isButtonPressed = false),
      onTap: () {
        if (widget.phoneController.text.trim().isEmpty) {
          _shouldShake = true;
          _startContinuousShake();
          _emptyFieldTimer?.cancel();
          _emptyFieldTimer = Timer(const Duration(seconds: 2), () {
            _stopContinuousShake();
          });
        } else {
          _stopContinuousShake();
          widget.onClickLoginButton();
        }
      },
      child: AnimatedBuilder(
        animation: _shakeAnimation,
        builder: (context, child) {
          final shakeOffset = sin(_shakeAnimation.value * pi * 4) * 3;
          return Transform.translate(
            offset: Offset(shakeOffset, 0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeInOut,
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors:
                      _isButtonPressed
                          ? [const Color(0xFF0D9488), const Color(0xFF0F766E)]
                          : [const Color(0xFF14B8A6), const Color(0xFF0F766E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F766E).withOpacity(0.3),
                    blurRadius: _isButtonPressed ? 8 : 12,
                    offset: Offset(0, _isButtonPressed ? 2 : 4),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child:
                  authController.isLoading
                      ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                      )
                      : Center(
                        child: Text(
                          'continue'.tr,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
            ),
          );
        },
      ),
    );
  }
}
