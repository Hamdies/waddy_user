import 'package:country_code_picker/country_code_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:waddy_app/common/models/response_model.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/features/cart/controllers/cart_controller.dart';
import 'package:waddy_app/features/profile/domain/models/update_user_model.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';
import 'package:waddy_app/features/auth/domain/models/social_log_in_body.dart';
import 'package:waddy_app/features/auth/domain/models/signup_body_model.dart';
import 'package:waddy_app/features/auth/domain/services/auth_service_interface.dart';
import 'package:waddy_app/helper/analytics_helper.dart';
import 'package:waddy_app/helper/route_helper.dart';

class AuthController extends GetxController implements GetxService {
  final AuthServiceInterface authServiceInterface;
  AuthController({required this.authServiceInterface}) {
    _notification = authServiceInterface.isSharedPrefNotificationActive();
  }

  bool _notification = true;
  bool get notification => _notification;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _guestLoading = false;
  bool get guestLoading => _guestLoading;

  bool _acceptTerms = true;
  bool get acceptTerms => _acceptTerms;

  bool _isActiveRememberMe = false;
  bool get isActiveRememberMe => _isActiveRememberMe;

  bool _notificationLoading = false;
  bool get notificationLoading => _notificationLoading;

  bool _isNumberLogin = false;
  bool get isNumberLogin => _isNumberLogin;

  var countryDialCode = "+880";

  bool _isOtpViewEnable = false;
  bool get isOtpViewEnable => _isOtpViewEnable;

  Future<ResponseModel> registration(SignUpBodyModel signUpBody) async {
    _isLoading = true;
    update();
    ResponseModel responseModel = await authServiceInterface.registration(
      signUpBody,
    );
    if (responseModel.isSuccess) {
      AnalyticsHelper.logCompleteRegistration(method: 'manual');
    }
    _isLoading = false;
    update();
    return responseModel;
  }

  Future<ResponseModel> login({
    required String emailOrPhone,
    required String password,
    required String loginType,
    required String fieldType,
    bool alreadyInApp = false,
  }) async {
    _isLoading = true;
    update();
    ResponseModel responseModel = await authServiceInterface.login(
      emailOrPhone: emailOrPhone,
      password: password,
      loginType: loginType,
      fieldType: fieldType,
      alreadyInApp: alreadyInApp,
    );
    _getUserAndCartData(responseModel);
    _isLoading = false;
    update();
    return responseModel;
  }

  Future<ResponseModel> otpLogin({
    required String phone,
    required String loginType,
    required String otp,
    required String verified,
    bool alreadyInApp = false,
  }) async {
    _isLoading = true;
    update();
    ResponseModel responseModel = await authServiceInterface.otpLogin(
      phone: phone,
      otp: otp,
      loginType: loginType,
      verified: verified,
      alreadyInApp: alreadyInApp,
    );
    _getUserAndCartData(responseModel);
    _isLoading = false;
    update();
    return responseModel;
  }

  void resetOtpView({bool isUpdate = true}) {
    _isOtpViewEnable = false;
    if (isUpdate) {
      update();
    }
  }

  void enableOtpView({bool enable = false}) {
    _isOtpViewEnable = enable;
    update();
  }

  Future<ResponseModel> guestLogin() async {
    return await authServiceInterface.guestLogin();
  }

  Future<ResponseModel> loginWithSocialMedia(
    SocialLogInBody socialLogInBody,
  ) async {
    _isLoading = true;
    update();
    ResponseModel responseModel = await authServiceInterface
        .loginWithSocialMedia(
          socialLogInBody,
          isCustomerVerificationOn:
              Get.find<SplashController>().configModel.customerVerification!,
        );
    _getUserAndCartData(responseModel);
    _isLoading = false;
    update();
    return responseModel;
  }

  void toggleIsNumberLogin({bool? value, bool willUpdate = true}) {
    if (value == null) {
      _isNumberLogin = !_isNumberLogin;
    } else {
      _isNumberLogin = value;
    }
    initCountryCode();
    if (willUpdate) {
      update();
    }
  }

  Future<ResponseModel> updatePersonalInfo({
    required String name,
    required String? phone,
    required String loginType,
    required String? email,
    required String? referCode,
    bool alreadyInApp = false,
  }) async {
    _isLoading = true;
    update();
    ResponseModel responseModel = await authServiceInterface.updatePersonalInfo(
      name: name,
      phone: phone,
      email: email,
      loginType: loginType,
      referCode: referCode,
      alreadyInApp: alreadyInApp,
    );
    if (responseModel.isSuccess) {
      // The name step is the finish line of the new-user flow (phone →
      // verify → personal info), so this is CompleteRegistration for ads.
      AnalyticsHelper.logCompleteRegistration(method: loginType);
      // Profile is whole now; stop resuming the name step on next launch.
      await authServiceInterface.setProfileIncomplete(false);
    }
    _getUserAndCartData(responseModel);
    _isLoading = false;
    update();
    return responseModel;
  }

  void _getUserAndCartData(ResponseModel responseModel) {
    if (responseModel.isSuccess &&
        responseModel.authResponseModel != null &&
        responseModel.authResponseModel!.isPhoneVerified! &&
        responseModel.authResponseModel!.isEmailVerified! &&
        responseModel.authResponseModel!.isPersonalInfo! &&
        responseModel.authResponseModel!.isExistUser == null) {
      Get.find<ProfileController>().getUserInfo();
      Get.find<CartController>().getCartDataOnline();
    }
  }

  void initCountryCode({String? countryCode}) {
    countryDialCode =
        countryCode ??
        CountryCode.fromCountryCode(
          Get.find<SplashController>().configModel.country ?? "BD",
        ).dialCode ??
        "+880";
  }

  void toggleRememberMe() {
    _isActiveRememberMe = !_isActiveRememberMe;
    update();
  }

  void toggleTerms() {
    _acceptTerms = !_acceptTerms;
    update();
  }

  Future<void> updateToken() async {
    await authServiceInterface.updateToken();
  }

  bool isLoggedIn() {
    return authServiceInterface.isLoggedIn();
  }

  /// True while a verified phone still has no name on the account — the
  /// window where the backend has only issued a temporary token.
  bool isProfileIncomplete() {
    return authServiceInterface.isProfileIncomplete();
  }

  Future<bool> setProfileIncomplete(bool value, {String? phone}) {
    return authServiceInterface.setProfileIncomplete(value, phone: phone);
  }

  /// Phone captured when the profile step was interrupted, if any.
  String? getPendingProfilePhone() {
    return authServiceInterface.getPendingProfilePhone();
  }

  bool isGuestLoggedIn() {
    return authServiceInterface.isGuestLoggedIn();
  }

  String getGuestId() {
    return authServiceInterface.getSharedPrefGuestId();
  }

  Future<bool> clearSharedData({bool removeToken = true}) async {
    Get.find<SplashController>().leaveModule();
    return await authServiceInterface.clearSharedData(removeToken: removeToken);
  }

  Future<void> socialLogout() async {
    final GoogleSignIn googleSignIn = GoogleSignIn();
    googleSignIn.disconnect();
    await FacebookAuth.instance.logOut();
  }

  Future<bool> clearSharedAddress() async {
    return await authServiceInterface.clearSharedAddress();
  }

  Future<void> saveUserNumberAndPasswordSharedPref(
    String number,
    String password,
    String countryCode,
  ) async {
    await authServiceInterface.saveUserNumberAndPassword(
      number,
      password,
      countryCode,
    );
  }

  String getUserNumber() {
    return authServiceInterface.getUserNumber();
  }

  String getUserCountryCode() {
    return authServiceInterface.getUserCountryCode();
  }

  String getUserPassword() {
    return authServiceInterface.getUserPassword();
  }

  void saveUserNumberAndPassword(
    String number,
    String password,
    String countryCode,
  ) {
    authServiceInterface.saveUserNumberAndPassword(
      number,
      password,
      countryCode,
    );
  }

  Future<bool> clearUserNumberAndPassword() async {
    return authServiceInterface.clearUserNumberAndPassword();
  }

  String getUserToken() {
    return authServiceInterface.getUserToken();
  }

  Future<void> updateZone() async {
    await authServiceInterface.updateZone();
  }

  Future<void> saveGuestNumber(String number) async {
    await authServiceInterface.saveGuestContactNumber(number);
  }

  String getGuestNumber() {
    return authServiceInterface.getGuestContactNumber();
  }

  Future<void> saveDmTipIndex(String i) async {
    await authServiceInterface.saveDmTipIndex(i);
  }

  String getDmTipIndex() {
    return authServiceInterface.getDmTipIndex();
  }

  void saveEarningPoint(String point) {
    authServiceInterface.saveEarningPoint(point);
  }

  String getEarningPint() {
    return authServiceInterface.getEarningPint();
  }

  Future<bool> setNotificationActive(bool isActive) async {
    _notificationLoading = true;
    update();
    _notification = isActive;
    await authServiceInterface.setNotificationActive(isActive);
    _notificationLoading = false;
    update();
    return _notification;
  }

  Future<String?> saveDeviceToken() async {
    return await authServiceInterface.saveDeviceToken();
  }

  Future<ResponseModel> toggleHidePhone({required bool hidePhone}) async {
    _isLoading = true;
    update();
    ResponseModel responseModel = await authServiceInterface.toggleHidePhone(
      hidePhone: hidePhone,
    );
    _isLoading = false;
    update();
    return responseModel;
  }

  Future<void> firebaseVerifyPhoneNumber(
    String phoneNumber,
    String? token,
    String loginType, {
    bool fromSignUp = true,
    bool canRoute = true,
    UpdateUserModel? updateUserModel,
  }) async {
    _isLoading = true;
    update();

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) {},
      verificationFailed: (FirebaseAuthException e) {
        _isLoading = false;
        update();

        if (Get.isDialogOpen!) {
          Get.back();
        }

        if (e.code == 'invalid-phone-number') {
          showCustomSnackBar('please_submit_a_valid_phone_number'.tr);
        } else {
          showCustomSnackBar(e.message?.replaceAll('_', ' '));
        }
      },
      codeSent: (String vId, int? resendToken) {
        if (Get.isDialogOpen!) {
          Get.back();
        }

        _isLoading = false;
        update();
        if (updateUserModel != null) {
          updateUserModel.sessionInfo = vId;
        }

        if (canRoute) {
          Get.toNamed(
            RouteHelper.getVerificationRoute(
              phoneNumber,
              '',
              token,
              fromSignUp ? RouteHelper.signUp : RouteHelper.forgotPassword,
              '',
              loginType,
              session: vId,
              updateUserModel: updateUserModel,
            ),
          );
        }
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        if (Get.isDialogOpen!) {
          Get.back();
        }
        showCustomSnackBar('timed_out_please_try_again_after_few_minutes'.tr);
      },
    );
  }
}
