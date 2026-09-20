import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:waddy_app/api/api_client.dart';
import 'package:waddy_app/features/address/controllers/address_controller.dart';
import 'package:waddy_app/features/auth/controllers/auth_controller.dart';
import 'package:waddy_app/features/banner/controllers/banner_controller.dart';
import 'package:waddy_app/features/brands/controllers/brands_controller.dart';
import 'package:waddy_app/features/business/controllers/business_controller.dart';
import 'package:waddy_app/features/cart/controllers/cart_controller.dart';
import 'package:waddy_app/features/category/controllers/category_controller.dart';
import 'package:waddy_app/features/chat/controllers/chat_controller.dart';
import 'package:waddy_app/features/checkout/controllers/checkout_controller.dart';
import 'package:waddy_app/features/coupon/controllers/coupon_controller.dart';
import 'package:waddy_app/features/favourite/controllers/favourite_controller.dart';
import 'package:waddy_app/features/flash_sale/controllers/flash_sale_controller.dart';
import 'package:waddy_app/features/home/controllers/advertisement_controller.dart';
import 'package:waddy_app/features/home/controllers/home_controller.dart';
import 'package:waddy_app/features/html/controllers/html_controller.dart';
import 'package:waddy_app/features/item/controllers/campaign_controller.dart';
import 'package:waddy_app/features/item/controllers/item_controller.dart';
import 'package:waddy_app/features/language/controllers/language_controller.dart';
import 'package:waddy_app/features/location/controllers/location_controller.dart';
import 'package:waddy_app/features/loyalty/controllers/loyalty_controller.dart';
import 'package:waddy_app/features/notification/controllers/notification_controller.dart';
import 'package:waddy_app/features/onboard/controllers/onboard_controller.dart';
import 'package:waddy_app/features/order/controllers/order_controller.dart';
import 'package:waddy_app/features/parcel/controllers/parcel_controller.dart';
import 'package:waddy_app/features/payment/controllers/payment_controller.dart';
import 'package:waddy_app/features/places/controllers/places_controller.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';
import 'package:waddy_app/features/review/controllers/review_controller.dart';
import 'package:waddy_app/features/search/controllers/search_controller.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/store/controllers/store_controller.dart';
import 'package:waddy_app/features/verification/controllers/verification_controller.dart';
import 'package:waddy_app/features/wallet/controllers/wallet_controller.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/common/controllers/theme_controller.dart';

import 'package:waddy_app/helper/get_di.dart' as di;
import 'package:waddy_app/util/app_constants.dart';

/// `get_di.dart` used to construct 71 repositories and services eagerly and
/// then hand each already-built instance to `Get.lazyPut(() => instance)` — a
/// lazy wrapper around work that had already happened. The whole graph was
/// built on the main isolate before `runApp`, blocking the first frame.
///
/// Converting it to real `Get.lazyPut<Interface>(() => Impl(...))` has two ways
/// to go wrong that the analyzer cannot see, and both are checked here:
///
///  1. Registering under the wrong type. `Get.lazyPut(() => FooRepository(…))`
///     infers the CONCRETE type, so every `Get.find<FooRepositoryInterface>()`
///     downstream would throw at runtime. Resolving each controller walks its
///     whole service → repository → ApiClient chain, so a single mis-typed
///     registration anywhere fails this test.
///  2. Not actually being lazy. Asserted directly below.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    Get.reset();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await di.init();
  });

  tearDown(Get.reset);

  test('init loads only the active locale, not every bundle', () async {
    Get.reset();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final Map<String, Map<String, String>> languages = await di.init();

    // The app ships more than one language; init must bring back exactly the
    // one about to be rendered. Loading all of them was 285 KB of JSON decoded
    // on the main isolate before runApp.
    expect(AppConstants.languages.length, greaterThan(1));
    expect(languages, hasLength(1));

    // And it has to be a real bundle — an empty map means the asset loaded but
    // decoded to nothing, which would render the app untranslated.
    expect(languages.values.single, isNotEmpty);
  });

  test('loadRemainingLanguages fills in the rest', () async {
    Get.reset();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final Map<String, Map<String, String>> languages = await di.init();

    await di.loadRemainingLanguages(languages);

    expect(languages, hasLength(AppConstants.languages.length));
    for (final MapEntry<String, Map<String, String>> e in languages.entries) {
      expect(e.value, isNotEmpty, reason: '${e.key} decoded empty');
    }
  });

  test('a saved language choice is the one preloaded', () async {
    Get.reset();
    // Pick a language that is NOT the default, so this cannot pass by accident.
    final String other = AppConstants.languages.last.languageCode!;
    SharedPreferences.setMockInitialValues(<String, Object>{
      AppConstants.languageCode: other,
    });
    final Map<String, Map<String, String>> languages = await di.init();

    expect(languages.keys.single, startsWith('${other}_'));
  });

  // Note on the two GetX predicates, because they do not mean what the names
  // suggest: `isRegistered` is true as soon as a factory is registered, built
  // or not. `isPrepared` is the one that means "registered by lazyPut and NOT
  // yet constructed". Laziness therefore has to be asserted with isPrepared.
  test('nothing is constructed during init()', () {
    // Before the change these would all have been false — not because they
    // were unregistered, but because every one had already been built by the
    // time init() returned.
    expect(Get.isPrepared<ApiClient>(), isTrue);
    expect(Get.isPrepared<StoreController>(), isTrue);
    expect(Get.isPrepared<HomeController>(), isTrue);
    expect(Get.isPrepared<ChatController>(), isTrue);
    expect(Get.isPrepared<ParcelController>(), isTrue);
  });

  test('resolving one controller does not drag in the rest of the graph', () {
    Get.find<StoreController>();

    // Built now.
    expect(Get.isPrepared<StoreController>(), isFalse);
    expect(Get.isPrepared<ApiClient>(), isFalse);

    // Unrelated features remain unbuilt — this is the cost that used to be
    // paid up front for all of them.
    expect(Get.isPrepared<ChatController>(), isTrue);
    expect(Get.isPrepared<ParcelController>(), isTrue);
    expect(Get.isPrepared<WalletController>(), isTrue);
  });

  test('every controller resolves through its full dependency chain', () {
    // Each entry walks controller → service → repository → ApiClient +
    // SharedPreferences. A registration under a concrete type instead of its
    // interface throws here.
    final List<Object Function()> resolvers = <Object Function()>[
      () => Get.find<ThemeController>(),
      () => Get.find<SplashController>(),
      () => Get.find<AddressController>(),
      () => Get.find<LocationController>(),
      () => Get.find<LocalizationController>(),
      () => Get.find<OnBoardingController>(),
      () => Get.find<AuthController>(),
      () => Get.find<ProfileController>(),
      () => Get.find<BannerController>(),
      () => Get.find<CategoryController>(),
      () => Get.find<ItemController>(),
      () => Get.find<CartController>(),
      () => Get.find<StoreController>(),
      () => Get.find<FavouriteController>(),
      () => Get.find<HomeController>(),
      () => Get.find<SearchController>(),
      () => Get.find<CouponController>(),
      () => Get.find<OrderController>(),
      () => Get.find<NotificationController>(),
      () => Get.find<CampaignController>(),
      () => Get.find<ParcelController>(),
      () => Get.find<WalletController>(),
      () => Get.find<ChatController>(),
      () => Get.find<FlashSaleController>(),
      // CheckoutController is deliberately absent. A FIELD INITIALIZER on it
      // reads `Get.find<SplashController>().configModel!.country!`, so it
      // cannot be constructed before the config request has returned — it
      // throws a null check error on an empty container. That is pre-existing
      // and unrelated to the DI change (controllers were always lazy), but it
      // does mean checkout is only constructible after splash has loaded
      // config, which is worth knowing before anything tries to warm it early.
      () => Get.find<PaymentController>(),
      () => Get.find<HtmlController>(),
      () => Get.find<ReviewController>(),
      () => Get.find<LoyaltyController>(),
      () => Get.find<XpController>(),
      () => Get.find<PlacesController>(),
      () => Get.find<VerificationController>(),
      () => Get.find<BrandsController>(),
      () => Get.find<BusinessController>(),
      () => Get.find<AdvertisementController>(),
    ];

    for (final Object Function() resolve in resolvers) {
      expect(resolve(), isNotNull);
    }
  });
}
