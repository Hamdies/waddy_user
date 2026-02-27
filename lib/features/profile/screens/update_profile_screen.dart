import 'dart:io';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:just_the_tooltip/just_the_tooltip.dart';
import 'package:sixam_mart/common/widgets/custom_image.dart';
import 'package:sixam_mart/common/widgets/custom_text_field.dart';
import 'package:sixam_mart/common/widgets/menu_drawer.dart';
import 'package:sixam_mart/common/widgets/web_menu_bar.dart';
import 'package:sixam_mart/features/language/controllers/language_controller.dart';
import 'package:sixam_mart/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart/features/profile/domain/models/update_user_model.dart';
import 'package:sixam_mart/features/auth/controllers/auth_controller.dart';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/helper/custom_validator.dart';
import 'package:sixam_mart/helper/responsive_helper.dart';
import 'package:sixam_mart/helper/validate_check.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/images.dart';
import 'package:sixam_mart/util/styles.dart';
import 'package:sixam_mart/common/widgets/custom_button.dart';
import 'package:sixam_mart/common/widgets/custom_snackbar.dart';
import 'package:sixam_mart/common/widgets/footer_view.dart';
import 'package:sixam_mart/common/widgets/not_logged_in_screen.dart';
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
              Get.find<SplashController>().configModel!.country!,
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
    } catch (_) {}
    setState(() {
      _isPhoneLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isLoggedIn = Get.find<AuthController>().isLoggedIn();
    final primaryColor = Theme.of(context).primaryColor;
    final secondaryColor = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      appBar: ResponsiveHelper.isDesktop(context) ? const WebMenuBar() : null,
      endDrawer: const MenuDrawer(),
      endDrawerEnableOpenDragGesture: false,
      backgroundColor: Colors.white,
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
                '${profileController.userInfoModel?.fName ?? ''} ${profileController.userInfoModel?.lName ?? ''}';
          }

          if (profileController.userInfoModel != null &&
              _emailController.text.isEmpty) {
            _emailController.text =
                profileController.userInfoModel?.email ?? '';
          }

          return isLoggedIn
              ? profileController.userInfoModel != null
                  ? ResponsiveHelper.isDesktop(context)
                      ? webView(profileController, isLoggedIn)
                      : Scaffold(
                        backgroundColor: const Color(
                          0xFFFDF8F3,
                        ), // Light cream background
                        body: SafeArea(
                          child: Column(
                            children: [
                              // Header with overlapping profile image
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  // Green header section
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.only(
                                      top: 16,
                                      bottom: 60,
                                    ),
                                    decoration: BoxDecoration(
                                      color: secondaryColor,
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(32),
                                        bottomRight: Radius.circular(32),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      child: Row(
                                        children: [
                                          // Back button - white with dark border
                                          GestureDetector(
                                            onTap: () => Get.back(),
                                            child: Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: primaryColor
                                                      .withOpacity(0.2),
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: Icon(
                                                Icons
                                                    .arrow_back_ios_new_rounded,
                                                color: primaryColor,
                                                size: 18,
                                              ),
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            'my_profile'.tr,
                                            style: robotoBold.copyWith(
                                              fontSize: 22,
                                              color: primaryColor,
                                            ),
                                          ),
                                          const Spacer(),
                                          const SizedBox(
                                            width: 44,
                                          ), // Balance for back button
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Profile image - overlapping bottom of header
                                  Positioned(
                                    bottom: -50,
                                    left: 0,
                                    right: 0,
                                    child: Center(
                                      child: GestureDetector(
                                        onTap:
                                            () => profileController.pickImage(),
                                        child: Stack(
                                          children: [
                                            // White frame with rounded corners
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: primaryColor
                                                      .withOpacity(0.15),
                                                  width: 2,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.08),
                                                    blurRadius: 15,
                                                    offset: const Offset(0, 5),
                                                  ),
                                                ],
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                child:
                                                    profileController
                                                                .pickedFile !=
                                                            null
                                                        ? GetPlatform.isWeb
                                                            ? Image.network(
                                                              profileController
                                                                  .pickedFile!
                                                                  .path,
                                                              width: 90,
                                                              height: 90,
                                                              fit: BoxFit.cover,
                                                            )
                                                            : Image.file(
                                                              File(
                                                                profileController
                                                                    .pickedFile!
                                                                    .path,
                                                              ),
                                                              width: 90,
                                                              height: 90,
                                                              fit: BoxFit.cover,
                                                            )
                                                        : FadeInImage.assetNetwork(
                                                          placeholder:
                                                              Images
                                                                  .placeholder,
                                                          image:
                                                              '${profileController.userInfoModel!.imageFullUrl}',
                                                          height: 90,
                                                          width: 90,
                                                          fit: BoxFit.cover,
                                                          imageErrorBuilder:
                                                              (
                                                                c,
                                                                o,
                                                                s,
                                                              ) => Image.asset(
                                                                Images
                                                                    .placeholder,
                                                                height: 90,
                                                                width: 90,
                                                                fit:
                                                                    BoxFit
                                                                        .cover,
                                                              ),
                                                        ),
                                              ),
                                            ),
                                            // Camera icon - small, bottom right
                                            Positioned(
                                              bottom: -2,
                                              right: -2,
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: secondaryColor,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: Colors.white,
                                                    width: 2,
                                                  ),
                                                ),
                                                child: Icon(
                                                  Icons.camera_alt_rounded,
                                                  color: primaryColor,
                                                  size: 14,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // Spacer for the overlapping image
                              const SizedBox(height: 60),

                              // Form section
                              Expanded(
                                child: SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.all(
                                    Dimensions.paddingSizeDefault,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.04),
                                          blurRadius: 15,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Name field
                                        _buildLightTextField(
                                          context,
                                          controller: _nameController,
                                          focusNode: _nameFocus,
                                          nextFocus: _emailFocus,
                                          label: 'name'.tr,
                                          hint: 'enter_name'.tr,
                                          icon: Icons.person_outline_rounded,
                                          isRequired: true,
                                          primaryColor: primaryColor,
                                        ),

                                        const SizedBox(height: 20),

                                        // Email field (Optional)
                                        _buildLightTextField(
                                          context,
                                          controller: _emailController,
                                          focusNode: _emailFocus,
                                          label: 'email'.tr,
                                          hint: 'enter_email'.tr,
                                          icon: Icons.email_outlined,
                                          isRequired: false,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          primaryColor: primaryColor,
                                          suffix:
                                              profileController
                                                          .userInfoModel!
                                                          .isEmailVerified! &&
                                                      profileController
                                                              .userInfoModel!
                                                              .email ==
                                                          _emailController.text
                                                  ? Icon(
                                                    Icons.verified_rounded,
                                                    color: secondaryColor,
                                                    size: 22,
                                                  )
                                                  : null,
                                        ),

                                        const SizedBox(height: 20),

                                        // Phone field
                                        _buildLightPhoneField(
                                          context,
                                          controller: _phoneController,
                                          focusNode: _phoneFocus,
                                          label: 'phone'.tr,
                                          isEnabled:
                                              !profileController
                                                  .userInfoModel!
                                                  .isPhoneVerified! ||
                                              profileController
                                                      .userInfoModel!
                                                      .phone ==
                                                  null,
                                          countryDialCode:
                                              _countryDialCode ??
                                              Get.find<LocalizationController>()
                                                  .locale
                                                  .countryCode,
                                          onCountryChanged:
                                              (CountryCode countryCode) =>
                                                  _countryDialCode =
                                                      countryCode.dialCode,
                                          primaryColor: primaryColor,
                                          isVerified:
                                              profileController
                                                  .userInfoModel!
                                                  .isPhoneVerified!,
                                          secondaryColor: secondaryColor,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // Update button using CustomButton
                              CustomButton(
                                isLoading: profileController.isLoading,
                                onPressed:
                                    () => _updateProfile(
                                      profileController: profileController,
                                      fromButton: true,
                                      fromPhone: false,
                                    ),
                                margin: const EdgeInsets.all(
                                  Dimensions.paddingSizeDefault,
                                ),
                                buttonText: 'update'.tr,
                              ),
                            ],
                          ),
                        ),
                      )
                  : const Center(child: CircularProgressIndicator())
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

  Widget _buildLightTextField(
    BuildContext context, {
    required TextEditingController controller,
    required FocusNode focusNode,
    FocusNode? nextFocus,
    required String label,
    required String hint,
    required IconData icon,
    required bool isRequired,
    required Color primaryColor,
    Color? secondaryColor,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffix,
  }) {
    final bgColor = secondaryColor?.withOpacity(0.08) ?? Colors.grey.shade50;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: robotoMedium.copyWith(fontSize: 14, color: primaryColor),
            ),
            if (isRequired)
              Text(
                ' *',
                style: robotoMedium.copyWith(color: Colors.red, fontSize: 14),
              ),
            if (!isRequired)
              Text(
                ' (${'optional'.tr})',
                style: robotoRegular.copyWith(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200, width: 1),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            textInputAction:
                nextFocus != null ? TextInputAction.next : TextInputAction.done,
            onSubmitted: (_) => nextFocus?.requestFocus(),
            style: robotoRegular.copyWith(
              fontSize: 15,
              color: const Color(0xFF1E293B),
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: robotoRegular.copyWith(
                fontSize: 14,
                color: Colors.grey.shade400,
              ),
              prefixIcon: Icon(icon, color: primaryColor, size: 22),
              suffixIcon: suffix,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLightPhoneField(
    BuildContext context, {
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required bool isEnabled,
    required String? countryDialCode,
    required Function(CountryCode) onCountryChanged,
    required Color primaryColor,
    required Color secondaryColor,
    required bool isVerified,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: robotoMedium.copyWith(fontSize: 14, color: primaryColor),
            ),
            Text(
              ' *',
              style: robotoMedium.copyWith(color: Colors.red, fontSize: 14),
            ),
            if (!isEnabled)
              Text(
                ' (${'non_changeable'.tr})',
                style: robotoRegular.copyWith(color: Colors.grey, fontSize: 12),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color:
                isEnabled
                    ? secondaryColor.withOpacity(0.08)
                    : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primaryColor.withOpacity(0.15), width: 1),
          ),
          child: Row(
            children: [
              // Country code picker
              Container(
                padding: const EdgeInsets.only(left: 8),
                child: CountryCodePicker(
                  onChanged: onCountryChanged,
                  initialSelection: countryDialCode,
                  favorite: const ['+20', '+1', '+91'],
                  showCountryOnly: false,
                  showOnlyCountryWhenClosed: false,
                  alignLeft: false,
                  padding: EdgeInsets.zero,
                  textStyle: robotoRegular.copyWith(
                    fontSize: 14,
                    color: const Color(0xFF1E293B),
                  ),
                  flagWidth: 24,
                  enabled: isEnabled,
                ),
              ),
              Container(
                width: 1,
                height: 30,
                color: primaryColor.withOpacity(0.15),
              ),
              // Phone number input
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: TextInputType.phone,
                  enabled: isEnabled,
                  style: robotoRegular.copyWith(
                    fontSize: 15,
                    color: isEnabled ? const Color(0xFF1E293B) : Colors.grey,
                  ),
                  decoration: InputDecoration(
                    hintText: 'write_phone_number'.tr,
                    hintStyle: robotoRegular.copyWith(
                      fontSize: 14,
                      color: Colors.grey.shade400,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              if (isVerified)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(
                    Icons.verified_rounded,
                    color: secondaryColor,
                    size: 22,
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
                width: Dimensions.webMaxWidth,
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
                      style: robotoMedium.copyWith(
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
                      width: Dimensions.webMaxWidth,
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
                                      ? GetPlatform.isWeb
                                          ? Image.network(
                                            profileController.pickedFile!.path,
                                            width: 100,
                                            height: 100,
                                            fit: BoxFit.cover,
                                          )
                                          : Image.file(
                                            File(
                                              profileController
                                                  .pickedFile!
                                                  .path,
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
                                    margin: const EdgeInsets.all(25),
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
                                              .configModel!
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
                                                      .configModel!
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
                                                          .configModel!
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
      // Only validate email format if email is provided (email is now optional)
      showCustomSnackBar('enter_a_valid_email_address'.tr);
    } else {
      UpdateUserModel updatedUser = UpdateUserModel(
        name: name,
        email: email, // Can be empty now
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
