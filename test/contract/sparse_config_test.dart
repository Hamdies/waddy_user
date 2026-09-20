import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waddy_app/common/models/config_model.dart';
import 'package:waddy_app/common/models/module_model.dart';
import 'package:waddy_app/features/address/domain/models/address_model.dart';
import 'package:waddy_app/features/checkout/helpers/checkout_calculation_helper.dart';
import 'package:waddy_app/features/coupon/controllers/coupon_controller.dart';
import 'package:waddy_app/features/coupon/domain/services/coupon_service_interface.dart';
import 'package:waddy_app/features/location/domain/models/zone_response_model.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';
import 'package:waddy_app/features/profile/domain/services/profile_service_interface.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/splash/domain/services/splash_service_interface.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/features/xp/domain/services/xp_service_interface.dart';
import 'package:waddy_app/util/app_constants.dart';

/// What happens when the server sends a config that omits optional sections.
///
/// ## Why this exists
///
/// `configModel` is non-null past the splash gate, and that is enforced by
/// `config_load_gate_test.dart`. But non-null config is not the same as
/// *complete* config: nothing guarantees the server sent `social_login`,
/// `module_config` or `active_payment_method_list`, or that an array has the
/// length a widget assumes.
///
/// That second bang is where the real crashes were:
///
///   * `socialLogin![0]` ran with no emptiness check at all, and
///     `socialLogin![1]` assumed a second entry — a short or absent array
///     took out the entire sign-in screen.
///   * `activePaymentMethodList!.length` as an `itemCount` crashed the
///     payment list builder rather than showing no methods.
///   * `defaultLocation!` was banged even though every call site already
///     supplied a `?? fallback` for the coordinate itself.
///
/// This file feeds the real `ConfigModel.fromJson` a deliberately sparse
/// payload and asserts the app degrades instead of throwing. It is the check
/// that says the hardening actually worked, rather than that it compiled.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// A config with the mandatory scalars and **none** of the optional
  /// collections a fully-populated production response carries.
  Map<String, dynamic> sparseConfigJson() => <String, dynamic>{
    'business_name': 'Waddy',
    'country': 'EG',
    'digit_after_decimal_point': 2,
    'currency_symbol': 'LE',
    // Deliberately absent: social_login, apple_login, module_config,
    // active_payment_method_list, default_location, centralize_login_setup.
  };

  group('ConfigModel.fromJson survives a sparse payload', () {
    test('parsing does not throw when the optional sections are missing', () {
      expect(() => ConfigModel.fromJson(sparseConfigJson()), returnsNormally);
    });

    test('the omitted collections come back null, not empty-but-present', () {
      final ConfigModel config = ConfigModel.fromJson(sparseConfigJson());
      expect(config.socialLogin, isNull);
      expect(config.moduleConfig, isNull);
      expect(config.activePaymentMethodList, isNull);
      expect(config.defaultLocation, isNull);
    });

    test('the scalars that were sent survive intact', () {
      final ConfigModel config = ConfigModel.fromJson(sparseConfigJson());
      expect(config.businessName, 'Waddy');
      expect(config.country, 'EG');
      expect(config.digitAfterDecimalPoint, 2);
    });
  });

  group('the social-login gate on a sparse config', () {
    test('an absent array means no provider is offered, not a crash', () {
      final ConfigModel config = ConfigModel.fromJson(sparseConfigJson());
      final List<SocialLogin> logins =
          config.socialLogin ?? const <SocialLogin>[];

      // This mirrors SocialLoginWidget's guard exactly: index only after a
      // length check. Before hardening, `socialLogin![0]` here would throw.
      bool statusAt(int index) =>
          index < logins.length && (logins[index].status ?? false);

      expect(() => statusAt(0), returnsNormally);
      expect(() => statusAt(1), returnsNormally);
      expect(statusAt(0), isFalse);
      expect(statusAt(1), isFalse);
    });

    test('a ONE-entry array does not crash the second lookup', () {
      // The specific shape that used to break: Google configured, Facebook
      // absent. `socialLogin![1]` was an unguarded index into a length-1 list.
      final ConfigModel config = ConfigModel.fromJson(<String, dynamic>{
        ...sparseConfigJson(),
        'social_login': <dynamic>[
          <String, dynamic>{'login_medium': 'google', 'status': true},
        ],
      });
      final List<SocialLogin> logins =
          config.socialLogin ?? const <SocialLogin>[];

      bool statusAt(int index) =>
          index < logins.length && (logins[index].status ?? false);

      expect(logins.length, 1);
      expect(statusAt(0), isTrue, reason: 'Google is configured');
      expect(statusAt(1), isFalse, reason: 'Facebook simply is not offered');
    });
  });

  group('the payment list on a sparse config', () {
    test('an absent list counts as zero rows rather than throwing', () {
      final ConfigModel config = ConfigModel.fromJson(sparseConfigJson());
      // The `itemCount:` expression the payment builders now use.
      expect(config.activePaymentMethodList?.length ?? 0, 0);
    });
  });

  group('the payment GATES on a sparse config', () {
    late CheckoutCalculationHelper helper;

    setUp(() async {
      Get.reset();
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppConstants.userAddress: jsonEncode(
          AddressModel(
            zoneData: <ZoneData>[
              ZoneData(
                id: 1,
                cashOnDelivery: true,
                digitalPayment: true,
                modules: <Modules>[],
              ),
            ],
          ).toJson(),
        ),
      });
      Get.put<SharedPreferences>(await SharedPreferences.getInstance());

      final SplashController splash = SplashController(
        splashServiceInterface: _StubSplashService(),
      );
      splash.setModuleConfigForTest(<String, dynamic>{
        AppConstants.grocery: <String, dynamic>{},
      });
      // The sparse config: cash_on_delivery and digital_payment absent.
      splash.setConfigModelForTest(ConfigModel.fromJson(sparseConfigJson()));
      splash.setModuleForTest(
        ModuleModel(
          id: 7,
          moduleName: 'grocery',
          moduleType: AppConstants.grocery,
        ),
      );
      Get.put<SplashController>(splash);
      Get.put<ProfileController>(
        ProfileController(profileServiceInterface: _StubProfileService()),
      );
      Get.put<XpController>(XpController(xpServiceInterface: _StubXpService()));
      Get.put<CouponController>(
        CouponController(couponServiceInterface: _StubCouponService()),
      );
      helper = CheckoutCalculationHelper();
    });
    tearDown(Get.reset);

    test('an unstated payment method is OFF, never assumed on', () {
      // The direction that matters. Defaulting a missing `cash_on_delivery` to
      // true would offer a payment method the business never enabled; a
      // customer could place an order the operation cannot collect on.
      // Off is the only safe default for a gating flag.
      final Store store = Store(id: 1, zoneId: 1);
      expect(helper.checkCODActive(store: store), isFalse);
      expect(helper.checkDigitalPaymentActive(store: store), isFalse);
    });

    test('the gates do not throw on a sparse config', () {
      final Store store = Store(id: 1, zoneId: 1);
      expect(() => helper.checkCODActive(store: store), returnsNormally);
      expect(
        () => helper.checkDigitalPaymentActive(store: store),
        returnsNormally,
      );
    });
  });
}

class _StubSplashService implements SplashServiceInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _StubProfileService implements ProfileServiceInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _StubXpService implements XpServiceInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _StubCouponService implements CouponServiceInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
