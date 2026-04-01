import 'dart:async';
import 'dart:math' as math;
import 'package:country_code_picker/country_code_picker.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/common/widgets/custom_asset_image_widget.dart';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/helper/responsive_helper.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sixam_mart/common/widgets/code_picker_widget.dart';

class CustomTextField extends StatefulWidget {
  final String titleText;
  final String hintText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final FocusNode? nextFocus;
  final TextInputType inputType;
  final TextInputAction inputAction;
  final bool isPassword;
  final Function? onChanged;
  final Function? onSubmit;
  final bool isEnabled;
  final int maxLines;
  final TextCapitalization capitalization;
  final String? prefixImage;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final double prefixSize;
  final TextAlign textAlign;
  final bool isAmount;
  final bool isNumber;
  final bool showTitle;
  final bool showBorder;
  final double iconSize;
  final bool isPhone;
  final String? countryDialCode;
  final Function(CountryCode countryCode)? onCountryChanged;
  final bool showLabelText;
  final bool required;
  final String? labelText;
  final String? Function(String?)? validator;
  final double? labelTextSize;
  final Widget? suffixChild;
  final String? suffixImage;
  final Function()? suffixOnPressed;
  final bool divider;
  final bool fromUpdateProfile;

  const CustomTextField({
    super.key,
    this.titleText = 'Write something...',
    this.hintText = '',
    this.controller,
    this.focusNode,
    this.nextFocus,
    this.isEnabled = true,
    this.inputType = TextInputType.text,
    this.inputAction = TextInputAction.next,
    this.maxLines = 1,
    this.onSubmit,
    this.onChanged,
    this.prefixImage,
    this.prefixIcon,
    this.suffixIcon,
    this.capitalization = TextCapitalization.none,
    this.isPassword = false,
    this.prefixSize = Dimensions.paddingSizeSmall,
    this.textAlign = TextAlign.start,
    this.isAmount = false,
    this.isNumber = false,
    this.showTitle = false,
    this.showBorder = true,
    this.iconSize = 18,
    this.isPhone = false,
    this.countryDialCode,
    this.onCountryChanged,
    this.showLabelText = true,
    this.required = false,
    this.labelText,
    this.validator,
    this.labelTextSize,
    this.suffixChild,
    this.suffixOnPressed,
    this.suffixImage,
    this.divider = false,
    this.fromUpdateProfile = false,
  });

  @override
  CustomTextFieldState createState() => CustomTextFieldState();
}

class CustomTextFieldState extends State<CustomTextField>
    with TickerProviderStateMixin {
  bool _obscureText = true;
  late AnimationController _animationController;
  late AnimationController _shakeController;
  late Animation<double> _animation;
  late Animation<double> _shakeAnimation;
  Timer? _emptyTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    // Shake animation controller
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticOut),
    );

    widget.focusNode?.addListener(() {
      if (widget.focusNode!.hasFocus) {
        _animationController.forward();
        _startEmptyTimer();
      } else {
        _animationController.reverse();
        _stopEmptyTimer();
      }
      setState(() {});
    });

    // Start timer if field is focused initially
    if (widget.focusNode?.hasFocus == true) {
      _startEmptyTimer();
    }
  }

  void _startEmptyTimer() {
    _stopEmptyTimer();
    _emptyTimer = Timer(const Duration(seconds: 3), () {
      if (mounted &&
          widget.focusNode?.hasFocus == true &&
          (widget.controller?.text.isEmpty ?? true)) {
        _triggerShake();
      }
    });
  }

  void _stopEmptyTimer() {
    _emptyTimer?.cancel();
    _emptyTimer = null;
  }

  void _triggerShake() {
    _shakeController.reset();
    _shakeController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _shakeController.dispose();
    _stopEmptyTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Modern title with subtle animation
        if (widget.showTitle)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: Text(
              widget.titleText,
              style: robotoMedium.copyWith(
                fontSize: Dimensions.fontSizeDefault,
                color: Theme.of(
                  context,
                ).textTheme.bodyLarge?.color?.withValues(alpha:0.9),
                letterSpacing: 0.2,
              ),
            ),
          ),

        SizedBox(height: widget.showTitle ? 8 : 0),

        // Main text field container with modern design and shake animation
        AnimatedBuilder(
            animation: Listenable.merge([_animation, _shakeAnimation]),
            builder: (context, child) {
              // Calculate shake offset
              double shakeOffset = 0;
              if (_shakeAnimation.value > 0) {
                shakeOffset =
                    math.sin(_shakeAnimation.value * math.pi * 8) *
                    (1 - _shakeAnimation.value) *
                    3;
              }

              return Transform.translate(
                offset: Offset(shakeOffset, 0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextFormField(
                    maxLines: widget.maxLines,
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    textAlign: widget.textAlign,
                    validator: widget.validator,
                    style: robotoMedium.copyWith(
                      fontSize: Dimensions.fontSizeLarge,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      letterSpacing: 0.1,
                    ),
                    textInputAction: widget.inputAction,
                    keyboardType:
                        widget.isAmount
                            ? TextInputType.number
                            : widget.inputType,
                    cursorColor: Theme.of(context).primaryColor,
                    cursorWidth: 2.5,
                    cursorHeight: 24,
                    textCapitalization: widget.capitalization,
                    enabled: widget.isEnabled,
                    autofocus: false,
                    obscureText: widget.isPassword ? _obscureText : false,
                    inputFormatters:
                        widget.inputType == TextInputType.phone
                            ? <TextInputFormatter>[
                              FilteringTextInputFormatter.allow(
                                RegExp('[0-9]'),
                              ),
                            ]
                            : widget.isAmount
                            ? [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d*'),
                              ),
                            ]
                            : widget.isNumber
                            ? [FilteringTextInputFormatter.allow(RegExp(r'\d'))]
                            : null,
                    decoration: InputDecoration(
                      // Modern border design
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          style:
                              widget.showBorder
                                  ? BorderStyle.solid
                                  : BorderStyle.none,
                          width: 1.5,
                          color:
                              isDark
                                  ? Colors.white.withValues(alpha:0.08)
                                  : Colors.black.withValues(alpha:0.06),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          style:
                              widget.showBorder
                                  ? BorderStyle.solid
                                  : BorderStyle.none,
                          width: 2.5,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          style:
                              widget.showBorder
                                  ? BorderStyle.solid
                                  : BorderStyle.none,
                          width: 1.5,
                          color:
                              isDark
                                  ? Colors.white.withValues(alpha:0.08)
                                  : Colors.black.withValues(alpha:0.06),
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          style:
                              widget.showBorder
                                  ? BorderStyle.solid
                                  : BorderStyle.none,
                          width: 2,
                          color: Theme.of(
                            context,
                          ).colorScheme.error.withValues(alpha:0.8),
                        ),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          style:
                              widget.showBorder
                                  ? BorderStyle.solid
                                  : BorderStyle.none,
                          width: 2.5,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: widget.isPhone ? 4 : 20,
                        vertical: 18,
                      ),
                      hintText:
                          widget.hintText.isEmpty ||
                                  !ResponsiveHelper.isDesktop(context)
                              ? widget.titleText
                              : widget.hintText,

                      fillColor: Theme.of(context).cardColor,

                      hintStyle: robotoRegular.copyWith(
                        fontSize: Dimensions.fontSizeLarge,
                        color: Theme.of(context).hintColor.withValues(alpha:0.5),
                        letterSpacing: 0.1,
                      ),
                      filled: true,

                      // Modern label styling
                      labelStyle:
                          widget.showLabelText
                              ? robotoMedium.copyWith(
                                fontSize: Dimensions.fontSizeDefault,
                                color: Theme.of(
                                  context,
                                ).hintColor.withValues(alpha:0.8),
                                letterSpacing: 0.2,
                              )
                              : null,
                      errorStyle: robotoRegular.copyWith(
                        fontSize: Dimensions.fontSizeSmall,
                        letterSpacing: 0.1,
                      ),

                      // Enhanced label with modern styling
                      label:
                          widget.showLabelText
                              ? Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: widget.labelText ?? '',
                                      style: robotoMedium.copyWith(
                                        fontSize:
                                            widget.labelTextSize ??
                                            Dimensions.fontSizeLarge,
                                        color:
                                            ((widget.focusNode?.hasFocus ==
                                                            true ||
                                                        widget
                                                            .controller!
                                                            .text
                                                            .isNotEmpty) &&
                                                    widget.isEnabled)
                                                ? Theme.of(context).primaryColor
                                                : Theme.of(
                                                  context,
                                                ).hintColor.withValues(alpha:0.7),
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    if (widget.required &&
                                        widget.labelText != null)
                                      TextSpan(
                                        text: ' *',
                                        style: robotoMedium.copyWith(
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.error,
                                          fontSize: Dimensions.fontSizeLarge,
                                        ),
                                      ),
                                    if (widget.isEnabled == false)
                                      TextSpan(
                                        text:
                                            widget.fromUpdateProfile
                                                ? ' (${'non_changeable'.tr})'
                                                : ' (${'non_changeable'.tr})',
                                        style: robotoRegular.copyWith(
                                          fontSize: Dimensions.fontSizeSmall,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error.withValues(alpha:0.8),
                                        ),
                                      ),
                                  ],
                                ),
                              )
                              : null,

                      // Modern prefix icon design
                      prefixIcon:
                          (widget.isPhone || widget.countryDialCode != null)
                              ? _buildModernPhonePrefix(context, isDark)
                              : widget.prefixImage != null &&
                                  widget.prefixIcon == null
                              ? _buildModernPrefixImage(context)
                              : widget.prefixImage == null &&
                                  widget.prefixIcon != null
                              ? _buildModernPrefixIcon(context)
                              : null,

                      // Modern suffix icon design
                      suffixIcon:
                          widget.isPassword
                              ? _buildModernPasswordToggle(context, isDark)
                              : widget.suffixImage != null
                              ? _buildModernSuffixImage(context, isDark)
                              : widget.suffixChild,
                    ),
                    onFieldSubmitted:
                        (text) =>
                            widget.nextFocus != null
                                ? FocusScope.of(
                                  context,
                                ).requestFocus(widget.nextFocus)
                                : widget.onSubmit != null
                                ? widget.onSubmit!(text)
                                : null,
                    onChanged: (text) {
                      // Reset timer when user starts typing
                      if (text.isNotEmpty) {
                        _stopEmptyTimer();
                      } else if (widget.focusNode?.hasFocus == true) {
                        _startEmptyTimer();
                      }
                      widget.onChanged?.call(text);
                    },
                  ),
                ),
              );
            },
          ),

        // Modern divider
        if (widget.divider)
          Container(
            margin: const EdgeInsets.only(top: 16),
            height: 1,
            color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
          ),
      ],
    );
  }

  Widget _buildModernPhonePrefix(BuildContext context, bool isDark) {
    return Container(
      width: 120,
      padding: const EdgeInsets.only(left: 8, right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 44,
            decoration: BoxDecoration(
              color: Theme.of(context).hintColor.withValues(alpha:0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.only(right: 12),
            child: Center(
              child: CodePickerWidget(
                flagWidth: 28,
                padding: EdgeInsets.zero,
                onChanged: widget.onCountryChanged,
                initialSelection: widget.countryDialCode,
                favorite: [widget.countryDialCode ?? ''],
                enabled:
                    Get.find<SplashController>()
                        .configModel
                        ?.countryPickerStatus,
                dialogBackgroundColor: Theme.of(context).cardColor,
                hideMainText: true,
                textStyle: robotoMedium.copyWith(
                  fontSize: Dimensions.fontSizeDefault,
                  color: Theme.of(context).textTheme.bodyMedium!.color,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ),
          Container(
            height: 24,
            width: 1,
            color: Theme.of(context).dividerColor.withValues(alpha:0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildModernPrefixImage(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color:
            widget.focusNode?.hasFocus == true
                ? Theme.of(context).primaryColor.withValues(alpha:0.1)
                : Theme.of(context).hintColor.withValues(alpha:0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: CustomAssetImageWidget(
        widget.prefixImage!,
        height: 18,
        width: 18,
        fit: BoxFit.cover,
        color:
            widget.focusNode?.hasFocus == true
                ? Theme.of(context).primaryColor
                : Theme.of(context).hintColor.withValues(alpha:0.7),
      ),
    );
  }

  Widget _buildModernPrefixIcon(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color:
            widget.focusNode?.hasFocus == true
                ? Theme.of(context).primaryColor.withValues(alpha:0.1)
                : Theme.of(context).hintColor.withValues(alpha:0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        widget.prefixIcon,
        size: 18,
        color:
            widget.focusNode?.hasFocus == true
                ? Theme.of(context).primaryColor
                : Theme.of(context).hintColor.withValues(alpha:0.7),
      ),
    );
  }

  Widget _buildModernPasswordToggle(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _toggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).hintColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _obscureText
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                key: ValueKey(_obscureText),
                color: Theme.of(context).primaryColor,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernSuffixImage(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.suffixOnPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).hintColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Image.asset(
              widget.suffixImage!,
              height: 18,
              width: 18,
              fit: BoxFit.cover,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ),
      ),
    );
  }

  void _toggle() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }
}
