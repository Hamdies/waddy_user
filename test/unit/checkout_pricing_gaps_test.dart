import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waddy_app/common/models/config_model.dart';
import 'package:waddy_app/common/models/module_model.dart';
import 'package:waddy_app/features/address/domain/models/address_model.dart';
import 'package:waddy_app/features/cart/domain/models/cart_model.dart';
import 'package:waddy_app/features/coupon/controllers/coupon_controller.dart';
import 'package:waddy_app/features/coupon/domain/services/coupon_service_interface.dart';
import 'package:waddy_app/features/checkout/helpers/checkout_calculation_helper.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/location/domain/models/zone_response_model.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';
import 'package:waddy_app/features/profile/domain/services/profile_service_interface.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/splash/domain/services/splash_service_interface.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/features/xp/domain/services/xp_service_interface.dart';
import 'package:waddy_app/util/app_constants.dart';

/// Characterization tests for the parts of `CheckoutCalculationHelper` that
/// `cart_checkout_test.dart` does not reach.
///
/// **These pin behaviour as it is today, not as it ought to be.** Where the
/// current behaviour looks wrong, the test says so in a comment and asserts the
/// wrong thing anyway — that is the point of a characterization test. Phase 3
/// refactors this helper into a pure function over an explicit input struct;
/// these assertions are what will prove the refactor changed nothing by
/// accident. A test that encoded the *intended* behaviour would fail before the
/// refactor started and tell us nothing.
///
/// Gaps covered here, all previously untested:
///   * `getDiscountPrice` / `getExtraDiscountPrice`
///   * `calculateFoodVariationDiscount`
///   * `calculateOrderAmount`
///   * `calculateOriginalDeliveryCharge`
///   * `checkCODActive` / `checkDigitalPaymentActive`
///
/// The four hidden `Get.find` dependencies are documented at length in
/// `cart_checkout_test.dart`; the same boot is reproduced here.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CheckoutCalculationHelper helper;

  /// Zone 1 allows both payment methods; zone 2 allows neither. Used to prove
  /// the gates read the *store's* zone rather than the first zone they find.
  AddressModel addressWithZones() => AddressModel(
    zoneData: <ZoneData>[
      ZoneData(
        id: 1,
        cashOnDelivery: true,
        digitalPayment: true,
        // `calculateOriginalDeliveryCharge` walks `zData.modules!` with a bang,
        // so an address without this crashes rather than pricing at zero.
        modules: <Modules>[],
      ),
      ZoneData(
        id: 2,
        cashOnDelivery: false,
        digitalPayment: false,
        modules: <Modules>[],
      ),
    ],
  );

  Future<void> bootSplash({
    ConfigModel? config,
    AddressModel? address,
  }) async {
    Get.reset();
    SharedPreferences.setMockInitialValues(<String, Object>{
      if (address != null)
        AppConstants.userAddress: jsonEncode(address.toJson()),
    });
    // AddressHelper reaches for SharedPreferences through Get.find, so the
    // payment gates need it registered even though they never write.
    Get.put<SharedPreferences>(await SharedPreferences.getInstance());

    final SplashController splash = SplashController(
      splashServiceInterface: _StubSplashService(),
    );
    splash.setModuleConfigForTest(<String, dynamic>{
      AppConstants.food: <String, dynamic>{},
      AppConstants.grocery: <String, dynamic>{},
    });
    splash.setConfigModelForTest(
      config ??
          ConfigModel(
            digitAfterDecimalPoint: 2,
            dmTipsStatus: 1,
            cashOnDelivery: true,
            digitalPayment: true,
          ),
    );
    splash.setModuleForTest(
      ModuleModel(
        id: 7,
        moduleName: 'grocery',
        moduleType: AppConstants.grocery,
      ),
    );
    Get.put<SplashController>(splash);

    // A null `userInfoModel` is the signed-out case: no referral bonus. The
    // referral path is already covered in cart_checkout_test.dart.
    Get.put<ProfileController>(
      ProfileController(profileServiceInterface: _StubProfileService()),
    );
    Get.put<XpController>(XpController(xpServiceInterface: _StubXpService()));
    // A FIFTH hidden dependency, not listed in cart_checkout_test.dart's
    // catalogue of four: calculateDeliveryCharge asks the coupon controller
    // whether free delivery was won.
    Get.put<CouponController>(
      CouponController(couponServiceInterface: _StubCouponService()),
    );
  }

  setUp(() async {
    await bootSplash();
    helper = CheckoutCalculationHelper();
  });
  tearDown(Get.reset);

  Item item({
    double price = 100,
    double discount = 0,
    String discountType = 'percent',
    String moduleType = AppConstants.grocery,
    List<FoodVariation>? foodVariations,
  }) => Item(
    id: 1,
    name: 'Koshary',
    price: price,
    discount: discount,
    discountType: discountType,
    moduleType: moduleType,
    storeId: 1,
    variations: <Variation>[],
    foodVariations: foodVariations ?? <FoodVariation>[],
    addOns: <AddOns>[],
  );

  CartModel cart({
    Item? forItem,
    int quantity = 1,
    List<List<bool?>>? foodVariations,
  }) => CartModel(
    1,
    forItem?.price ?? 100,
    forItem?.price ?? 100,
    <Variation>[],
    foodVariations ?? <List<bool?>>[],
    0,
    quantity,
    const <AddOn>[],
    const <AddOns>[],
    false,
    10,
    forItem ?? item(),
    10,
  );

  group('getDiscountPrice — which of two discounts wins', () {
    test('the larger discount is the one applied', () {
      expect(helper.getDiscountPrice(30, 10), 30);
      expect(helper.getDiscountPrice(10, 30), 30);
    });

    test('a tie resolves to the item discount', () {
      // `>` not `>=`, so equal values fall through to the item side. Behaviour
      // is identical either way at equality; pinned so a future rewrite that
      // flips the comparison is noticed.
      expect(helper.getDiscountPrice(20, 20), 20);
    });

    test('zero on both sides is zero, not null', () {
      expect(helper.getDiscountPrice(0, 0), 0);
    });
  });

  group('getExtraDiscountPrice — the store surplus', () {
    test('is the amount the store discount exceeds the item discount by', () {
      expect(helper.getExtraDiscountPrice(30, 10), 20);
    });

    test('is zero when the item discount is the larger', () {
      // Not negative: the surplus is one-directional.
      expect(helper.getExtraDiscountPrice(10, 30), 0);
    });

    test('is zero at equality', () {
      expect(helper.getExtraDiscountPrice(20, 20), 0);
    });
  });

  group('calculateOrderAmount — the figure delivery tiers are judged on', () {
    test('is price plus add-ons, less discount, coupon and referral', () {
      final double amount = helper.calculateOrderAmount(
        price: 100,
        variations: 0,
        discount: 10,
        addOns: 20,
        couponDiscount: 5,
        cartList: <CartModel?>[cart()],
        referralDiscount: 2,
      );
      // (100 + 0 - 10) + 20 - 5 - 2
      expect(amount, 103);
    });

    test('grocery ignores the variation total', () {
      // `newVariation` is derived from the module type, and grocery does not
      // set it — so the variations argument is dropped on this path.
      final double amount = helper.calculateOrderAmount(
        price: 100,
        variations: 50,
        discount: 0,
        addOns: 0,
        couponDiscount: 0,
        cartList: <CartModel?>[cart()],
        referralDiscount: 0,
      );
      expect(amount, 100, reason: 'grocery drops variations here');
    });

    test('food folds the variation total in', () {
      final CartModel foodCart = cart(
        forItem: item(moduleType: AppConstants.food),
      );
      final double amount = helper.calculateOrderAmount(
        price: 100,
        variations: 50,
        discount: 0,
        addOns: 0,
        couponDiscount: 0,
        cartList: <CartModel?>[foodCart],
        referralDiscount: 0,
      );
      expect(amount, 150);
    });

    test('an empty cart drops variations regardless of module', () {
      final double amount = helper.calculateOrderAmount(
        price: 10,
        variations: 99,
        discount: 0,
        addOns: 0,
        couponDiscount: 0,
        cartList: const <CartModel?>[],
        referralDiscount: 0,
      );
      expect(amount, 10);
    });

    test('a coupon larger than the cart clamps at zero, never negative', () {
      // FIXED. This used to return -150: an over-large coupon drove the order
      // amount negative, and that negative figure then decided which delivery
      // tier applied and whether free delivery was met.
      final double amount = helper.calculateOrderAmount(
        price: 50,
        variations: 0,
        discount: 0,
        addOns: 0,
        couponDiscount: 200,
        cartList: <CartModel?>[cart()],
        referralDiscount: 0,
      );
      expect(amount, 0);
    });

    test('a referral bonus larger than the cart also clamps', () {
      final double amount = helper.calculateOrderAmount(
        price: 20,
        variations: 0,
        discount: 0,
        addOns: 0,
        couponDiscount: 0,
        cartList: <CartModel?>[cart()],
        referralDiscount: 75,
      );
      expect(amount, 0);
    });

    test('the result is rounded the way the server rounds', () {
      // Guards the seam to roundLikeServer: 10.995 must round up, not truncate.
      final double amount = helper.calculateOrderAmount(
        price: 10.995,
        variations: 0,
        discount: 0,
        addOns: 0,
        couponDiscount: 0,
        cartList: <CartModel?>[cart()],
        referralDiscount: 0,
      );
      expect(amount, 11.0);
    });
  });

  group('calculateFoodVariationDiscount', () {
    test('a cart with no food variations discounts nothing', () {
      expect(helper.calculateFoodVariationDiscount(cartModel: cart()), 0);
    });

    test('a null cart model is zero, not a throw', () {
      expect(helper.calculateFoodVariationDiscount(cartModel: null), 0);
    });

    test('a percent discount yields the variation surplus', () {
      final Item foodItem = item(
        moduleType: AppConstants.food,
        discount: 10,
        discountType: 'percent',
        foodVariations: <FoodVariation>[
          FoodVariation(
            name: 'Size',
            variationValues: <VariationValue>[
              VariationValue(level: 'Large', optionPrice: 100),
            ],
          ),
        ],
      );
      final CartModel c = cart(
        forItem: foodItem,
        foodVariations: <List<bool?>>[
          <bool?>[true],
        ],
      );
      // undiscounted 100 − discounted 90 = 10
      expect(helper.calculateFoodVariationDiscount(cartModel: c), 10);
    });

    test('an unselected variation contributes nothing', () {
      final Item foodItem = item(
        moduleType: AppConstants.food,
        discount: 10,
        discountType: 'percent',
        foodVariations: <FoodVariation>[
          FoodVariation(
            name: 'Size',
            variationValues: <VariationValue>[
              VariationValue(level: 'Large', optionPrice: 100),
            ],
          ),
        ],
      );
      final CartModel c = cart(
        forItem: foodItem,
        foodVariations: <List<bool?>>[
          <bool?>[false],
        ],
      );
      expect(helper.calculateFoodVariationDiscount(cartModel: c), 0);
    });

    test('quantity multiplies the discount', () {
      final Item foodItem = item(
        moduleType: AppConstants.food,
        discount: 10,
        discountType: 'percent',
        foodVariations: <FoodVariation>[
          FoodVariation(
            name: 'Size',
            variationValues: <VariationValue>[
              VariationValue(level: 'Large', optionPrice: 100),
            ],
          ),
        ],
      );
      final CartModel c = cart(
        forItem: foodItem,
        quantity: 3,
        foodVariations: <List<bool?>>[
          <bool?>[true],
        ],
      );
      expect(helper.calculateFoodVariationDiscount(cartModel: c), 30);
    });
  });

  group('checkCODActive / checkDigitalPaymentActive', () {
    test('both are on when the store zone and the config agree', () async {
      await bootSplash(address: addressWithZones());
      helper = CheckoutCalculationHelper();
      final Store store = Store(id: 1, zoneId: 1);

      expect(helper.checkCODActive(store: store), isTrue);
      expect(helper.checkDigitalPaymentActive(store: store), isTrue);
    });

    test('a zone that forbids them wins over a config that allows', () async {
      await bootSplash(address: addressWithZones());
      helper = CheckoutCalculationHelper();
      final Store store = Store(id: 1, zoneId: 2);

      expect(helper.checkCODActive(store: store), isFalse);
      expect(helper.checkDigitalPaymentActive(store: store), isFalse);
    });

    test('a config that forbids them wins over a zone that allows', () async {
      await bootSplash(
        address: addressWithZones(),
        config: ConfigModel(
          digitAfterDecimalPoint: 2,
          dmTipsStatus: 1,
          cashOnDelivery: false,
          digitalPayment: false,
        ),
      );
      helper = CheckoutCalculationHelper();
      final Store store = Store(id: 1, zoneId: 1);

      expect(helper.checkCODActive(store: store), isFalse);
      expect(helper.checkDigitalPaymentActive(store: store), isFalse);
    });

    test('a store in no known zone falls through to off', () async {
      // The loop simply never matches, so the initial `false` stands. Worth
      // pinning: "no matching zone" silently means "no payment methods", which
      // renders as a checkout with nothing selectable rather than an error.
      await bootSplash(address: addressWithZones());
      helper = CheckoutCalculationHelper();
      final Store store = Store(id: 1, zoneId: 99);

      expect(helper.checkCODActive(store: store), isFalse);
      expect(helper.checkDigitalPaymentActive(store: store), isFalse);
    });

    test('a null store is off without consulting the address', () {
      expect(helper.checkCODActive(store: null), isFalse);
      expect(helper.checkDigitalPaymentActive(store: null), isFalse);
    });

    test('no stored address degrades to "no methods", it does not throw', () {
      // FIXED. This used to bang through `getUserAddressFromSharedPref()!`, so
      // a signed-in user whose address had not loaded yet — a normal state on
      // every launch until the location gate resolves one — crashed the
      // payment section. Now the gates simply report nothing available, which
      // is what an unresolved address actually means.
      final Store store = Store(id: 1, zoneId: 1);
      expect(helper.checkCODActive(store: store), isFalse);
      expect(helper.checkDigitalPaymentActive(store: store), isFalse);
    });
  });

  group('calculateOriginalDeliveryCharge', () {
    test('a null store returns the -1 sentinel, not zero', () {
      // TODAY'S BEHAVIOUR, and a trap worth pinning: `deliveryCharge` starts at
      // -1 and every branch that could overwrite it is guarded by
      // `store != null`. So "no store" yields -1, not "free delivery" — and -1
      // is a *negative charge* if any caller adds it to a total without
      // checking. Callers do check (`deliveryCharge == -1` means "not
      // computable"), but the sentinel is invisible in the type.
      expect(
        helper.calculateOriginalDeliveryCharge(
          store: null,
          address: addressWithZones(),
          distance: 5,
          extraCharge: 0,
          surgePrice: null,
          surgePriceType: null,
        ),
        -1,
      );
    });

    test('the -1 sentinel never reaches calculateTotal', () {
      // FIXED. calculateTotal adds deliveryCharge without checking for the
      // sentinel, so "not computable" used to render as one pound off the
      // total. The screen guards SUBMISSION on `deliveryCharge == -1`
      // (checkout_screen.dart:1021) but not the total it DISPLAYS, so this
      // was visible to a user waiting for a distance to resolve.
      final double charge = helper.calculateDeliveryCharge(
        store: null,
        address: addressWithZones(),
        distance: 5,
        extraCharge: 0,
        orderAmount: 100,
        orderType: 'delivery',
        surgePrice: null,
        surgePriceType: null,
      );
      final double total = helper.calculateTotal(
        subTotal: 100,
        deliveryCharge: charge,
        discount: 0,
        couponDiscount: 0,
        taxIncluded: true,
        tax: 0,
        orderType: 'delivery',
        tips: 0,
        additionalCharge: 0,
        extraPackagingCharge: 0,
      );
      expect(charge, 0, reason: 'the sentinel is absorbed, not propagated');
      expect(total, 100, reason: 'so the displayed total is not discounted');
    });

    test('a self-delivering store uses its own per-km rate', () {
      final Store store = Store(
        id: 1,
        zoneId: 1,
        selfDeliverySystem: 1,
        perKmShippingCharge: 5,
        minimumShippingCharge: 10,
        maximumShippingCharge: 100,
      );
      final double charge = helper.calculateOriginalDeliveryCharge(
        store: store,
        address: addressWithZones(),
        distance: 6,
        extraCharge: 0,
        surgePrice: null,
        surgePriceType: null,
      );
      // 6 km × 5 = 30, inside the 10–100 band.
      expect(charge, 30);
    });

    test('the minimum charge floors a short trip', () {
      final Store store = Store(
        id: 1,
        zoneId: 1,
        selfDeliverySystem: 1,
        perKmShippingCharge: 5,
        minimumShippingCharge: 25,
        maximumShippingCharge: 100,
      );
      final double charge = helper.calculateOriginalDeliveryCharge(
        store: store,
        address: addressWithZones(),
        distance: 1,
        extraCharge: 0,
        surgePrice: null,
        surgePriceType: null,
      );
      expect(charge, 25);
    });

    test('the maximum charge caps a long trip', () {
      final Store store = Store(
        id: 1,
        zoneId: 1,
        selfDeliverySystem: 1,
        perKmShippingCharge: 5,
        minimumShippingCharge: 10,
        maximumShippingCharge: 40,
      );
      final double charge = helper.calculateOriginalDeliveryCharge(
        store: store,
        address: addressWithZones(),
        distance: 100,
        extraCharge: 0,
        surgePrice: null,
        surgePriceType: null,
      );
      expect(charge, 40);
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
