import 'dart:io';
import 'package:waddy_app/util/swallow.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:just_the_tooltip/just_the_tooltip.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/custom_text_field.dart';
import 'package:waddy_app/common/widgets/menu_drawer.dart';
import 'package:waddy_app/features/language/controllers/language_controller.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';
import 'package:waddy_app/features/profile/domain/models/update_user_model.dart';
import 'package:waddy_app/features/auth/controllers/auth_controller.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/helper/custom_validator.dart';
import 'package:waddy_app/helper/validate_check.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/images.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_button.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/common/widgets/footer_view.dart';
import 'package:waddy_app/common/widgets/not_logged_in_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class UpdateProfileScreen extends StatefulWidget {
  const UpdateProfileScreen({super.key});

  @override
  State<UpdateProfileScreen> createState() => _UpdateProfileScreenState();
}

class _UpdateProfileScreenState extends State<UpdateProfileScreen> {
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  JustTheController toolController = JustTheController();
  final ScrollController scrollController = ScrollController();
  bool isPhoneVerified = false;
  bool isEmailVerified = false;
  String? _countryDialCode;
  bool _isPhoneLoading = true;

  @override
  void initState() {
    super.initState();
    _initCall();
  }

  void _initCall() {
    AuthController authController = Get.find<AuthController>();
    _countryDialCode =
        authController.getUserCountryCode().isNotEmpty
            ? authController.getUserCountryCode()
            : CountryCode.fromCountryCode(
              Get.find<SplashController>().configModel.country!,
            ).dialCode;

    if (Get.find<AuthController>().isLoggedIn() &&
        Get.find<ProfileController>().userInfoModel == null) {
      Get.find<ProfileController>().getUserInfo();
    }
    Get.find<ProfileController>().getUserInfo();
    Get.find<ProfileController>().initData();
  }

  @override
  void dispose() {
    toolController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _splitPhoneNumber(String number) async {
    _isPhoneLoading = true;
    try {
      PhoneValid phoneNumber = await CustomValidator.isPhoneValid(number);
      _phoneController.text = phoneNumber.phone.replaceFirst(
        '+${phoneNumber.countryCode}',
        '',
      );
      _countryDialCode = '+${phoneNumber.countryCode}';
    } catch (e, s) {
      swallow('split stored phone into country code', e, s);
    }
    setState(() {
      _isPhoneLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isLoggedIn = Get.find<AuthController>().isLoggedIn();
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final accentColor = theme.colorScheme.secondary;

    return Scaffold(
      appBar: null,
      endDrawer: const MenuDrawer(),
      endDrawerEnableOpenDragGesture: false,
      backgroundColor: theme.colorScheme.background,
      body: GetBuilder<ProfileController>(
        builder: (profileController) {
          if (profileController.userInfoModel != null &&
              _phoneController.text.isEmpty &&
              _isPhoneLoading) {
            if (profileController.userInfoModel?.phone != null &&
                profileController.userInfoModel!.phone!.isNotEmpty) {
              _splitPhoneNumber(profileController.userInfoModel!.phone!);
            }
          }

          if (profileController.userInfoModel != null &&
              _nameController.text.isEmpty) {
            _nameController.text =
                '${profileController.userInfoModel?.fName ?? ''} ${profileController.userInfoModel?.lName ?? ''}'
                    .trim();
          }

          if (profileController.userInfoModel != null &&
              _emailController.text.isEmpty) {
            _emailController.text =
                profileController.userInfoModel?.email ?? '';
          }

          return isLoggedIn
              ? profileController.userInfoModel != null
                  ? _mobileView(profileController, primaryColor, accentColor)
                  : Center(
                    child: CircularProgressIndicator(
                      color: accentColor,
                      strokeWidth: 3,
                    ),
                  )
              : NotLoggedInScreen(
                callBack: (value) {
                  _initCall();
                  setState(() {});
                },
              );
        },
      ),
    );
  }

  Widget _mobileView(
    ProfileController profileController,
    Color primaryColor,
    Color accentColor,
  ) {
    return Container(
      color: primaryColor,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeDefault,
                vertical: Dimensions.paddingSizeSmall,
              ),
              child: Row(
                children: [
                  _backButton(primaryColor, accentColor),
                  const Spacer(),
                  Text(
                    'edit_profile'.tr,
                    style: waddyBold.copyWith(fontSize: 18, color: accentColor),
                  ),
                  const Spacer(),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Content area
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.background,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: Dimensions.paddingSizeDefault,
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      _buildAvatar(
                        profileController,
                        primaryColor,
                        accentColor,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${profileController.userInfoModel?.fName ?? ''} ${profileController.userInfoModel?.lName ?? ''}'
                            .trim(),
                        style: waddyBold.copyWith(
                          fontSize: 16,
                          color: primaryColor,
                        ),
                      ),
                      if (profileController.userInfoModel?.email != null &&
                          profileController.userInfoModel!.email!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            profileController.userInfoModel!.email!,
                            style: waddyRegular.copyWith(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                      const SizedBox(height: 18),
                      // Form card
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Dimensions.paddingSizeDefault,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusLarge,
                          ),
                          border: Border.all(
                            color: primaryColor.withOpacity(0.06),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.04),
                              blurRadius: 16,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _buildField(
                              controller: _nameController,
                              focusNode: _nameFocus,
                              nextFocus: _emailFocus,
                              label: 'name'.tr,
                              hint: 'enter_name'.tr,
                              icon: HugeIcons.strokeRoundedUser,
                              isRequired: true,
                              primaryColor: primaryColor,
                              accentColor: accentColor,
                            ),
                            const SizedBox(height: 14),
                            _buildField(
                              controller: _emailController,
                              focusNode: _emailFocus,
                              label: 'email'.tr,
                              hint: 'enter_email'.tr,
                              icon: HugeIcons.strokeRoundedMail01,
                              isRequired: false,
                              keyboardType: TextInputType.emailAddress,
                              primaryColor: primaryColor,
                              accentColor: accentColor,
                              suffix:
                                  profileController
                                              .userInfoModel!
                                              .isEmailVerified! &&
                                          profileController
                                                  .userInfoModel!
                                                  .email ==
                                              _emailController.text
                                      ? Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: accentColor.withOpacity(0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.check_rounded,
                                          color: primaryColor,
                                          size: 14,
                                        ),
                                      )
                                      : null,
                            ),
                            const SizedBox(height: 14),
                            _buildPhoneField(
                              controller: _phoneController,
                              focusNode: _phoneFocus,
                              label: 'phone'.tr,
                              isEnabled:
                                  !profileController
                                      .userInfoModel!
                                      .isPhoneVerified! ||
                                  profileController.userInfoModel!.phone ==
                                      null,
                              countryDialCode:
                                  _countryDialCode ??
                                  Get.find<LocalizationController>()
                                      .locale
                                      .countryCode,
                              onCountryChanged:
                                  (CountryCode countryCode) =>
                                      _countryDialCode = countryCode.dialCode,
                              primaryColor: primaryColor,
                              accentColor: accentColor,
                              isVerified:
                                  profileController
                                      .userInfoModel!
                                      .isPhoneVerified!,
                            ),
                            const SizedBox(height: 14),
                            _buildHidePhoneToggle(
                              profileController: profileController,
                              primaryColor: primaryColor,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Update button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap:
                              profileController.isLoading
                                  ? null
                                  : () => _updateProfile(
                                    profileController: profileController,
                                    fromButton: true,
                                    fromPhone: false,
                                  ),
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusLarge,
                          ),
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  primaryColor,
                                  primaryColor.withOpacity(0.85),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(
                                Dimensions.radiusLarge,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: Dimensions.paddingSizeMedium,
                              ),
                              child: Center(
                                child:
                                    profileController.isLoading
                                        ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: accentColor,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                        : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            HugeIcon(
                                              icon:
                                                  HugeIcons
                                                      .strokeRoundedCheckmarkCircle02,
                                              color: accentColor,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'update'.tr,
                                              style: waddyBold.copyWith(
                                                fontSize: 15,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _backButton(Color primaryColor, Color accentColor) {
    return GestureDetector(
      onTap: () => Get.back(),
      child: Container(
        padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        ),
        child: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Colors.white,
          size: 16,
        ),
      ),
    );
  }

  Widget _buildAvatar(
    ProfileController profileController,
    Color primaryColor,
    Color accentColor,
  ) {
    return GestureDetector(
      onTap: () => profileController.pickImage(),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Rounded rectangle avatar matching menu_screen style
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              border: Border.all(color: accentColor, width: 2),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF134E4A), Color(0xFF1A7A6E)],
              ),
              borderRadius: BorderRadius.circular(Dimensions.radiusExtraLarge),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Dimensions.radiusExtraLarge),
              child:
                  profileController.pickedFile != null
                      ? Image.file(
                        File(profileController.pickedFile!.path),
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                      )
                      : FadeInImage.assetNetwork(
                        placeholder: Images.placeholder,
                        image:
                            '${profileController.userInfoModel!.imageFullUrl}',
                        height: 90,
                        width: 90,
                        fit: BoxFit.cover,
                        imageErrorBuilder:
                            (c, o, s) => Image.asset(
                              Images.placeholder,
                              height: 90,
                              width: 90,
                              fit: BoxFit.cover,
                            ),
                      ),
            ),
          ),
          // Camera badge
          Positioned(
            bottom: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedCamera01,
                color: primaryColor,
                size: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Privacy setting relocated here from the old signup wizard: whether the
  /// delivery partner sees the customer's real phone number.
  Widget _buildHidePhoneToggle({
    required ProfileController profileController,
    required Color primaryColor,
  }) {
    final bool hidePhone = profileController.userInfoModel?.hidePhone ?? false;

    return Row(
      children: [
        Icon(
          Icons.visibility_off_outlined,
          size: 20,
          color: primaryColor.withOpacity(0.6),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'hide_phone_from_delivery_partner'.tr,
            style: waddyRegular.copyWith(
              fontSize: Dimensions.fontSizeSmall,
              color: primaryColor,
            ),
          ),
        ),
        Switch(
          value: hidePhone,
          activeColor: primaryColor,
          onChanged: (value) {
            if (value) {
              _showHidePhoneWarningDialog();
            } else {
              _setHidePhone(false);
            }
          },
        ),
      ],
    );
  }

  void _showHidePhoneWarningDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
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
          content: Text(
            'hide_phone_warning_message'.tr,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).primaryColor.withValues(alpha: 0.6),
              height: 1.5,
            ),
          ),
          actions: [
            CustomButton(
              buttonText: 'cancel'.tr,
              onPressed: () => Navigator.of(context).pop(),
              transparent: true,
              height: 40,
              radius: 8,
            ),
            CustomButton(
              buttonText: 'i_understand'.tr,
              onPressed: () {
                Navigator.of(context).pop();
                _setHidePhone(true);
              },
              height: 40,
              radius: 8,
            ),
          ],
        );
      },
    );
  }

  void _setHidePhone(bool hidePhone) async {
    final response = await Get.find<AuthController>().toggleHidePhone(
      hidePhone: hidePhone,
    );
    if (response.isSuccess) {
      await Get.find<ProfileController>().getUserInfo();
      if (mounted) setState(() {});
    } else {
      showCustomSnackBar(response.message);
    }
  }

  Widget _buildField({
    required TextEditingController controller,
    required FocusNode focusNode,
    FocusNode? nextFocus,
    required String label,
    required String hint,
    required dynamic icon,
    required bool isRequired,
    required Color primaryColor,
    required Color accentColor,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            HugeIcon(icon: icon, color: primaryColor, size: 16),
            const SizedBox(width: 5),
            Text(
              label,
              style: waddyMedium.copyWith(fontSize: 12, color: primaryColor),
            ),
            if (isRequired)
              Text(
                ' *',
                style: waddyMedium.copyWith(color: Colors.red, fontSize: 12),
              ),
            if (!isRequired)
              Text(
                ' (${'optional'.tr})',
                style: waddyRegular.copyWith(
                  color: Colors.grey.shade400,
                  fontSize: 10,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.03),
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            border: Border.all(color: primaryColor.withOpacity(0.1)),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            textInputAction:
                nextFocus != null ? TextInputAction.next : TextInputAction.done,
            onSubmitted: (_) => nextFocus?.requestFocus(),
            style: waddyRegular.copyWith(fontSize: 14, color: primaryColor),
            cursorColor: accentColor,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: waddyRegular.copyWith(
                fontSize: 13,
                color: Colors.grey.shade400,
              ),
              suffixIcon:
                  suffix != null
                      ? Padding(
                        padding: const EdgeInsets.only(
                          right: Dimensions.paddingSizeSmall,
                        ),
                        child: suffix,
                      )
                      : null,
              suffixIconConstraints: const BoxConstraints(
                minWidth: 20,
                minHeight: 20,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeMedium,
                vertical: Dimensions.paddingSizeMedium,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required bool isEnabled,
    required String? countryDialCode,
    required Function(CountryCode) onCountryChanged,
    required Color primaryColor,
    required Color accentColor,
    required bool isVerified,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedSmartPhone01,
              color: primaryColor,
              size: 16,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: waddyMedium.copyWith(fontSize: 12, color: primaryColor),
            ),
            Text(
              ' *',
              style: waddyMedium.copyWith(color: Colors.red, fontSize: 12),
            ),
            if (!isEnabled)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(
                    Dimensions.radiusExtraSmall,
                  ),
                ),
                child: Text(
                  'non_changeable'.tr,
                  style: waddyRegular.copyWith(
                    color: primaryColor.withOpacity(0.6),
                    fontSize: 9,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color:
                isEnabled
                    ? primaryColor.withOpacity(0.03)
                    : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            border: Border.all(color: primaryColor.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.only(left: 6),
                child: CountryCodePicker(
                  onChanged: onCountryChanged,
                  initialSelection: countryDialCode,
                  favorite: const ['+20', '+1', '+91'],
                  showCountryOnly: false,
                  showOnlyCountryWhenClosed: false,
                  alignLeft: false,
                  padding: EdgeInsets.zero,
                  textStyle: waddyMedium.copyWith(
                    fontSize: 13,
                    color: primaryColor,
                  ),
                  flagWidth: 22,
                  enabled: isEnabled,
                ),
              ),
              Container(
                width: 1,
                height: 24,
                color: primaryColor.withOpacity(0.1),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: TextInputType.phone,
                  enabled: isEnabled,
                  cursorColor: accentColor,
                  style: waddyRegular.copyWith(
                    fontSize: 14,
                    color: isEnabled ? primaryColor : Colors.grey,
                  ),
                  decoration: InputDecoration(
                    hintText: 'write_phone_number'.tr,
                    hintStyle: waddyRegular.copyWith(
                      fontSize: 13,
                      color: Colors.grey.shade400,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: Dimensions.paddingSizeSmall,
                      vertical: Dimensions.paddingSizeMedium,
                    ),
                  ),
                ),
              ),
              if (isVerified)
                Padding(
                  padding: const EdgeInsets.only(
                    right: Dimensions.paddingSizeSmall,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: primaryColor,
                      size: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget webView(ProfileController profileController, bool isLoggedIn) {
    return SingleChildScrollView(
      controller: scrollController,
      child: FooterView(
        child: Stack(
          children: [
            SizedBox(height: 520, width: context.width),

            Center(
              child: Container(
                height: 300,
                width: Dimensions.maxContentWidth,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  image: const DecorationImage(
                    image: AssetImage(Images.profileBg),
                    fit: BoxFit.fill,
                  ),
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: Dimensions.paddingSizeDefault,
                    ),
                    child: Text(
                      'profile'.tr,
                      style: waddyMedium.copyWith(
                        fontSize: Dimensions.fontSizeLarge,
                        color: Theme.of(context).cardColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            Positioned(
              top: 120,
              left: 0,
              right: 0,
              child: Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      alignment: Alignment.topCenter,
                      height: 400,
                      width: Dimensions.maxContentWidth,
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(Dimensions.radiusExtraLarge),
                          bottom: Radius.circular(Dimensions.radiusDefault),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.1),
                            spreadRadius: 1,
                            blurRadius: 10,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),

                    Positioned(
                      top: -50,
                      left: 0,
                      right: 0,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Stack(
                          children: [
                            ClipOval(
                              child:
                                  profileController.pickedFile != null
                                      ? Image.file(
                                        File(
                                          profileController.pickedFile!.path,
                                        ),
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                      )
                                      : CustomImage(
                                        image:
                                            '${profileController.userInfoModel!.imageFullUrl}',
                                        height: 100,
                                        width: 100,
                                        fit: BoxFit.cover,
                                      ),
                            ),

                            Positioned(
                              bottom: 0,
                              right: 0,
                              top: 0,
                              left: 0,
                              child: InkWell(
                                onTap: () => profileController.pickImage(),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Container(
                                    margin: const EdgeInsets.all(
                                      Dimensions.paddingSizeExtraLarge,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        width: 2,
                                        color: Colors.white,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Positioned(
                      top: 80,
                      left: 0,
                      right: 0,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 90),
                        child: Center(
                          child: SizedBox(
                            width: 500,
                            child: Column(
                              children: [
                                CustomTextField(
                                  titleText: 'enter_name'.tr,
                                  controller: _nameController,
                                  capitalization: TextCapitalization.words,
                                  inputType: TextInputType.name,
                                  focusNode: _nameFocus,
                                  nextFocus: _emailFocus,
                                  prefixIcon:
                                      CupertinoIcons.person_alt_circle_fill,
                                  labelText: 'name'.tr,
                                  required: true,
                                  validator:
                                      (value) =>
                                          ValidateCheck.validateEmptyText(
                                            value,
                                            "first_name_field_is_required".tr,
                                          ),
                                ),
                                const SizedBox(
                                  height: Dimensions.paddingSizeExtraOverLarge,
                                ),

                                CustomTextField(
                                  titleText: 'enter_email'.tr,
                                  controller: _emailController,
                                  focusNode: _emailFocus,
                                  inputType: TextInputType.emailAddress,
                                  prefixIcon: CupertinoIcons.mail_solid,
                                  labelText: 'email'.tr,
                                  required: true,
                                  validator:
                                      (value) =>
                                          ValidateCheck.validateEmail(value),
                                  onChanged: (value) {
                                    profileController.update();
                                  },
                                  suffixImage:
                                      profileController
                                                  .userInfoModel!
                                                  .isEmailVerified! &&
                                              profileController
                                                      .userInfoModel!
                                                      .email ==
                                                  _emailController.text
                                          ? Images.verifiedIcon
                                          : Get.find<SplashController>()
                                              .configModel
                                              .centralizeLoginSetup!
                                              .emailVerificationStatus!
                                          ? Images.unverifiedIcon
                                          : null,
                                  suffixOnPressed: () {
                                    if (!profileController
                                            .userInfoModel!
                                            .isEmailVerified! ||
                                        profileController
                                                .userInfoModel!
                                                .email !=
                                            _emailController.text) {
                                      _updateProfile(
                                        profileController: profileController,
                                        fromButton: false,
                                        fromPhone: false,
                                      );
                                    }
                                  },
                                ),
                                const SizedBox(
                                  height: Dimensions.paddingSizeExtraOverLarge,
                                ),

                                Stack(
                                  children: [
                                    CustomTextField(
                                      titleText: 'phone'.tr,
                                      controller: _phoneController,
                                      focusNode: _phoneFocus,
                                      inputType: TextInputType.phone,
                                      isEnabled:
                                          !profileController
                                              .userInfoModel!
                                              .isPhoneVerified! ||
                                          profileController
                                                  .userInfoModel!
                                                  .phone ==
                                              null,
                                      fromUpdateProfile: true,
                                      labelText: 'phone'.tr,
                                      required: true,
                                      isPhone: true,
                                      onCountryChanged:
                                          (CountryCode countryCode) =>
                                              _countryDialCode =
                                                  countryCode.dialCode,
                                      countryDialCode:
                                          _countryDialCode ??
                                          Get.find<LocalizationController>()
                                              .locale
                                              .countryCode,
                                      suffixImage:
                                          profileController
                                                  .userInfoModel!
                                                  .isPhoneVerified!
                                              ? Images.verifiedIcon
                                              : null,
                                    ),

                                    Positioned(
                                      right: 10,
                                      top: 10,
                                      child:
                                          !profileController
                                                      .userInfoModel!
                                                      .isPhoneVerified! &&
                                                  Get.find<SplashController>()
                                                      .configModel
                                                      .centralizeLoginSetup!
                                                      .phoneVerificationStatus!
                                              ? InkWell(
                                                onTap: () {
                                                  if (!profileController
                                                          .userInfoModel!
                                                          .isPhoneVerified! &&
                                                      Get.find<
                                                            SplashController
                                                          >()
                                                          .configModel
                                                          .centralizeLoginSetup!
                                                          .phoneVerificationStatus!) {
                                                    _updateProfile(
                                                      profileController:
                                                          profileController,
                                                      fromButton: false,
                                                      fromPhone: true,
                                                    );
                                                  }
                                                },
                                                child: Image.asset(
                                                  Images.unverifiedIcon,
                                                  height: 25,
                                                  width: 25,
                                                  fit: BoxFit.cover,
                                                ),
                                              )
                                              : const SizedBox(),
                                    ),
                                  ],
                                ),
                                const SizedBox(
                                  height: Dimensions.paddingSizeExtraOverLarge,
                                ),

                                CustomButton(
                                  width: 500,
                                  buttonText: 'update_profile'.tr,
                                  fontSize: Dimensions.fontSizeDefault,
                                  isBold: false,
                                  radius: Dimensions.radiusSmall,
                                  isLoading: profileController.isLoading,
                                  onPressed:
                                      () => _updateProfile(
                                        profileController: profileController,
                                        fromButton: true,
                                        fromPhone: false,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
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

  Future<void> _updateProfile({
    required ProfileController profileController,
    required bool fromButton,
    required bool fromPhone,
  }) async {
    String name = _nameController.text.trim();
    String email = _emailController.text.trim();
    String phoneNumber = _phoneController.text.trim();
    String numberWithCountryCode = _countryDialCode! + phoneNumber;
    PhoneValid phoneValid = await CustomValidator.isPhoneValid(
      numberWithCountryCode,
    );
    numberWithCountryCode = phoneValid.phone;

    if (name.isEmpty) {
      showCustomSnackBar('enter_your_name'.tr);
    } else if (!phoneValid.isValid) {
      showCustomSnackBar('invalid_phone_number'.tr);
    } else if (phoneNumber.isEmpty) {
      showCustomSnackBar('enter_phone_number'.tr);
    } else if (phoneNumber.length < 6) {
      showCustomSnackBar('enter_a_valid_phone_number'.tr);
    } else if (email.isNotEmpty && !GetUtils.isEmail(email)) {
      showCustomSnackBar('enter_a_valid_email_address'.tr);
    } else {
      UpdateUserModel updatedUser = UpdateUserModel(
        name: name,
        email: email,
        phone: numberWithCountryCode,
        buttonType:
            fromButton
                ? ''
                : fromPhone
                ? 'phone'
                : 'email',
      );
      await profileController.updateUserInfo(
        updatedUser,
        Get.find<AuthController>().getUserToken(),
        fromButton: fromButton,
      );
    }
  }
}
