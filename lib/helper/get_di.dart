import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:waddy_app/features/brands/controllers/brands_controller.dart';
import 'package:waddy_app/features/brands/domain/repositories/brands_repository.dart';
import 'package:waddy_app/features/brands/domain/repositories/brands_repository_interface.dart';
import 'package:waddy_app/features/brands/domain/services/brands_service.dart';
import 'package:waddy_app/features/brands/domain/services/brands_service_interface.dart';
import 'package:waddy_app/features/business/controllers/business_controller.dart';
import 'package:waddy_app/features/business/domain/repositories/business_repo.dart';
import 'package:waddy_app/features/business/domain/repositories/business_repo_interface.dart';
import 'package:waddy_app/features/business/domain/services/business_service.dart';
import 'package:waddy_app/features/business/domain/services/business_service_interface.dart';
import 'package:waddy_app/features/coupon/domain/repositories/coupon_repository.dart';
import 'package:waddy_app/features/coupon/domain/repositories/coupon_repository_interface.dart';
import 'package:waddy_app/features/home/controllers/advertisement_controller.dart';
import 'package:waddy_app/features/home/controllers/home_controller.dart';
import 'package:waddy_app/features/home/domain/repositories/advertisement_repository.dart';
import 'package:waddy_app/features/home/domain/repositories/advertisement_repository_interface.dart';
import 'package:waddy_app/features/home/domain/repositories/home_repository.dart';
import 'package:waddy_app/features/home/domain/repositories/home_repository_interface.dart';
import 'package:waddy_app/features/home/domain/services/advertisement_service.dart';
import 'package:waddy_app/features/home/domain/services/advertisement_service_interface.dart';
import 'package:waddy_app/features/home/domain/services/home_service.dart';
import 'package:waddy_app/features/home/domain/services/home_service_interface.dart';
import 'package:waddy_app/features/cart/controllers/cart_controller.dart';
import 'package:waddy_app/features/banner/controllers/banner_controller.dart';
import 'package:waddy_app/features/banner/domain/repositories/banner_repository.dart';
import 'package:waddy_app/features/banner/domain/repositories/banner_repository_interface.dart';
import 'package:waddy_app/features/banner/domain/services/banner_service.dart';
import 'package:waddy_app/features/banner/domain/services/banner_service_interface.dart';
import 'package:waddy_app/features/cart/domain/repositories/cart_repository.dart';
import 'package:waddy_app/features/cart/domain/repositories/cart_repository_interface.dart';
import 'package:waddy_app/features/cart/domain/services/cart_service.dart';
import 'package:waddy_app/features/cart/domain/services/cart_service_interface.dart';
import 'package:waddy_app/features/category/controllers/category_controller.dart';
import 'package:waddy_app/features/cuisine/controllers/cuisine_controller.dart';
import 'package:waddy_app/features/cuisine/domain/repositories/cuisine_repository.dart';
import 'package:waddy_app/features/cuisine/domain/repositories/cuisine_repository_interface.dart';
import 'package:waddy_app/features/cuisine/domain/services/cuisine_service.dart';
import 'package:waddy_app/features/cuisine/domain/services/cuisine_service_interface.dart';
import 'package:waddy_app/features/category/domain/reposotories/category_repository.dart';
import 'package:waddy_app/features/category/domain/reposotories/category_repository_interface.dart';
import 'package:waddy_app/features/category/domain/services/category_service.dart';
import 'package:waddy_app/features/category/domain/services/category_service_interface.dart';
import 'package:waddy_app/features/chat/controllers/chat_controller.dart';
import 'package:waddy_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:waddy_app/features/chat/domain/repositories/chat_repository_interface.dart';
import 'package:waddy_app/features/chat/domain/services/chat_service.dart';
import 'package:waddy_app/features/chat/domain/services/chat_service_interface.dart';
import 'package:waddy_app/features/coupon/controllers/coupon_controller.dart';
import 'package:waddy_app/features/coupon/domain/services/coupon_service.dart';
import 'package:waddy_app/features/coupon/domain/services/coupon_service_interface.dart';
import 'package:waddy_app/features/favourite/controllers/favourite_controller.dart';
import 'package:waddy_app/features/favourite/domain/repositories/favourite_repository.dart';
import 'package:waddy_app/features/favourite/domain/repositories/favourite_repository_interface.dart';
import 'package:waddy_app/features/favourite/domain/services/favourite_service.dart';
import 'package:waddy_app/features/favourite/domain/services/favourite_service_interface.dart';
import 'package:waddy_app/features/flash_sale/controllers/flash_sale_controller.dart';
import 'package:waddy_app/features/flash_sale/domain/repositories/flash_sale_repository.dart';
import 'package:waddy_app/features/flash_sale/domain/repositories/flash_sale_repository_interface.dart';
import 'package:waddy_app/features/flash_sale/domain/services/flash_sale_service.dart';
import 'package:waddy_app/features/flash_sale/domain/services/flash_sale_service_interface.dart';
import 'package:waddy_app/features/html/controllers/html_controller.dart';
import 'package:waddy_app/features/html/domain/repositories/html_repository.dart';
import 'package:waddy_app/features/html/domain/repositories/html_repository_interface.dart';
import 'package:waddy_app/features/html/domain/services/html_service.dart';
import 'package:waddy_app/features/html/domain/services/html_service_interface.dart';
import 'package:waddy_app/features/item/controllers/campaign_controller.dart';
import 'package:waddy_app/features/item/controllers/item_controller.dart';
import 'package:waddy_app/features/item/domain/repositories/campaign_repository.dart';
import 'package:waddy_app/features/item/domain/repositories/campaign_repository_interface.dart';
import 'package:waddy_app/features/item/domain/repositories/item_repository.dart';
import 'package:waddy_app/features/item/domain/repositories/item_repository_interface.dart';
import 'package:waddy_app/features/item/domain/services/campaign_service.dart';
import 'package:waddy_app/features/item/domain/services/campaign_service_interface.dart';
import 'package:waddy_app/features/item/domain/services/item_service.dart';
import 'package:waddy_app/features/item/domain/services/item_service_interface.dart';
import 'package:waddy_app/features/language/controllers/language_controller.dart';
import 'package:waddy_app/features/language/domain/repository/language_repository.dart';
import 'package:waddy_app/features/language/domain/repository/language_repository_interface.dart';
import 'package:waddy_app/features/language/domain/service/language_service.dart';
import 'package:waddy_app/features/language/domain/service/language_service_interface.dart';
import 'package:waddy_app/features/location/controllers/location_controller.dart';
import 'package:waddy_app/common/controllers/theme_controller.dart';
import 'package:waddy_app/api/api_client.dart';
import 'package:waddy_app/features/address/controllers/address_controller.dart';
import 'package:waddy_app/features/address/domain/repositories/address_repository.dart';
import 'package:waddy_app/features/address/domain/repositories/address_repository_interface.dart';
import 'package:waddy_app/features/address/domain/services/address_service.dart';
import 'package:waddy_app/features/address/domain/services/address_service_interface.dart';
import 'package:waddy_app/features/auth/controllers/auth_controller.dart';
import 'package:waddy_app/features/auth/controllers/deliveryman_registration_controller.dart';
import 'package:waddy_app/features/auth/controllers/store_registration_controller.dart';
import 'package:waddy_app/features/auth/domain/reposotories/auth_repository.dart';
import 'package:waddy_app/features/auth/domain/reposotories/auth_repository_interface.dart';
import 'package:waddy_app/features/auth/domain/reposotories/deliveryman_registration_repository.dart';
import 'package:waddy_app/features/auth/domain/reposotories/deliveryman_registration_repository_interface.dart';
import 'package:waddy_app/features/auth/domain/reposotories/store_registration_repository.dart';
import 'package:waddy_app/features/auth/domain/reposotories/store_registration_repository_interface.dart';
import 'package:waddy_app/features/auth/domain/services/auth_service.dart';
import 'package:waddy_app/features/auth/domain/services/auth_service_interface.dart';
import 'package:waddy_app/features/auth/domain/services/deliveryman_registration_service.dart';
import 'package:waddy_app/features/auth/domain/services/deliveryman_registration_service_interface.dart';
import 'package:waddy_app/features/auth/domain/services/store_registration_service.dart';
import 'package:waddy_app/features/auth/domain/services/store_registration_service_interface.dart';
import 'package:waddy_app/features/checkout/controllers/checkout_controller.dart';
import 'package:waddy_app/features/checkout/domain/repositories/checkout_repository.dart';
import 'package:waddy_app/features/checkout/domain/repositories/checkout_repository_interface.dart';
import 'package:waddy_app/features/checkout/domain/services/checkout_service.dart';
import 'package:waddy_app/features/checkout/domain/services/checkout_service_interface.dart';
import 'package:waddy_app/features/location/domain/repositories/location_repository.dart';
import 'package:waddy_app/features/location/domain/repositories/location_repository_interface.dart';
import 'package:waddy_app/features/location/domain/services/location_service.dart';
import 'package:waddy_app/features/location/domain/services/location_service_interface.dart';
import 'package:waddy_app/features/loyalty/controllers/loyalty_controller.dart';
import 'package:waddy_app/features/loyalty/domain/repositories/loyalty_repository.dart';
import 'package:waddy_app/features/loyalty/domain/repositories/loyalty_repository_interface.dart';
import 'package:waddy_app/features/loyalty/domain/services/loyalty_service.dart';
import 'package:waddy_app/features/loyalty/domain/services/loyalty_service_interface.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/features/xp/domain/repositories/xp_repository.dart';
import 'package:waddy_app/features/xp/domain/repositories/xp_repository_interface.dart';
import 'package:waddy_app/features/xp/domain/services/xp_service.dart';
import 'package:waddy_app/features/xp/domain/services/xp_service_interface.dart';
import 'package:waddy_app/features/places/controllers/places_controller.dart';
import 'package:waddy_app/features/places/domain/repositories/places_repository.dart';
import 'package:waddy_app/features/places/domain/repositories/places_repository_interface.dart';
import 'package:waddy_app/features/places/domain/services/places_service.dart';
import 'package:waddy_app/features/places/domain/services/places_service_interface.dart';
import 'package:waddy_app/features/notification/controllers/notification_controller.dart';
import 'package:waddy_app/features/notification/domain/repository/notification_repository.dart';
import 'package:waddy_app/features/notification/domain/repository/notification_repository_interface.dart';
import 'package:waddy_app/features/notification/domain/service/notification_service.dart';
import 'package:waddy_app/features/notification/domain/service/notification_service_interface.dart';
import 'package:waddy_app/features/onboard/controllers/onboard_controller.dart';
import 'package:waddy_app/features/onboard/domain/repository/onboard_repository.dart';
import 'package:waddy_app/features/onboard/domain/repository/onboard_repository_interface.dart';
import 'package:waddy_app/features/onboard/domain/service/onboard_service.dart';
import 'package:waddy_app/features/onboard/domain/service/onboard_service_interface.dart';
import 'package:waddy_app/features/order/controllers/order_controller.dart';
import 'package:waddy_app/features/order/domain/repositories/order_repository.dart';
import 'package:waddy_app/features/order/domain/repositories/order_repository_interface.dart';
import 'package:waddy_app/features/order/domain/services/order_service.dart';
import 'package:waddy_app/features/order/domain/services/order_service_interface.dart';
import 'package:waddy_app/features/parcel/controllers/parcel_controller.dart';
import 'package:waddy_app/features/parcel/domain/repositories/parcel_repository.dart';
import 'package:waddy_app/features/parcel/domain/repositories/parcel_repository_interface.dart';
import 'package:waddy_app/features/parcel/domain/services/parcel_service.dart';
import 'package:waddy_app/features/parcel/domain/services/parcel_service_interface.dart';
import 'package:waddy_app/features/payment/controllers/payment_controller.dart';
import 'package:waddy_app/features/payment/domain/repositories/payement_repository.dart';
import 'package:waddy_app/features/payment/domain/repositories/payment_repository_interface.dart';
import 'package:waddy_app/features/payment/domain/services/payment_service.dart';
import 'package:waddy_app/features/payment/domain/services/payment_service_interface.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';
import 'package:waddy_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:waddy_app/features/profile/domain/repositories/profile_repository_interface.dart';
import 'package:waddy_app/features/profile/domain/services/profile_service.dart';
import 'package:waddy_app/features/profile/domain/services/profile_service_interface.dart';
import 'package:waddy_app/features/review/controllers/review_controller.dart';
import 'package:waddy_app/features/review/domain/repositories/review_repository.dart';
import 'package:waddy_app/features/review/domain/repositories/review_repository_interface.dart';
import 'package:waddy_app/features/review/domain/services/review_service.dart';
import 'package:waddy_app/features/review/domain/services/review_service_interface.dart';
import 'package:waddy_app/features/search/controllers/search_controller.dart';
import 'package:waddy_app/features/search/domain/repositories/search_repository.dart';
import 'package:waddy_app/features/search/domain/repositories/search_repository_interface.dart';
import 'package:waddy_app/features/search/domain/services/search_service.dart';
import 'package:waddy_app/features/search/domain/services/search_service_interface.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/splash/domain/repositories/splash_repository.dart';
import 'package:waddy_app/features/splash/domain/repositories/splash_repository_interface.dart';
import 'package:waddy_app/features/splash/domain/services/splash_service.dart';
import 'package:waddy_app/features/splash/domain/services/splash_service_interface.dart';
import 'package:waddy_app/features/store/controllers/store_controller.dart';
import 'package:waddy_app/features/store/domain/repositories/store_repository.dart';
import 'package:waddy_app/features/store/domain/repositories/store_repository_interface.dart';
import 'package:waddy_app/features/store/domain/services/store_service.dart';
import 'package:waddy_app/features/store/domain/services/store_service_interface.dart';
import 'package:waddy_app/features/verification/controllers/verification_controller.dart';
import 'package:waddy_app/features/verification/domein/reposotories/verification_repository.dart';
import 'package:waddy_app/features/verification/domein/reposotories/verification_repository_interface.dart';
import 'package:waddy_app/features/verification/domein/services/verification_service.dart';
import 'package:waddy_app/features/verification/domein/services/verification_service_interface.dart';
import 'package:waddy_app/features/wallet/controllers/wallet_controller.dart';
import 'package:waddy_app/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:waddy_app/features/wallet/domain/repositories/wallet_repository_interface.dart';
import 'package:waddy_app/features/wallet/domain/services/wallet_service.dart';
import 'package:waddy_app/features/wallet/domain/services/wallet_service_interface.dart';
import 'package:waddy_app/helper/auth_token_store.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/features/language/domain/models/language_model.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';

Future<Map<String, Map<String, String>>> init() async {
  /// Every dependency below is a global singleton registered once, before the
  /// first route exists. Under GetX's default `SmartManagement.full` a lazily
  /// built instance is linked to whatever route happened to create it and is
  /// *removed from the container* — factory and all — when that route is
  /// disposed. The next `Get.find()` then throws `"X" not found`, which is how
  /// the checkout auth sheet died on `AuthRepositoryInterface` (built during an
  /// earlier route, wiped when it popped, then wanted again by
  /// VerificationService).
  ///
  /// Setting `keepFactory` is not enough on its own. GetX only consults
  /// `smartManagement` when the fenix flag is *null*, and the public
  /// `Get.lazyPut` signature is `bool fenix = false` — so every call passes an
  /// explicit `false` and `fenix ?? Get.smartManagement == keepFactory`
  /// (get_instance.dart:123) never sees a null to fall back from. A non-fenix
  /// builder is erased from the container entirely when its route disposes, so
  /// the next `Get.find()` throws `"X" not found`.
  ///
  /// [_lazy] passes `fenix: true` explicitly, which keeps the builder alive:
  /// the instance may still be released with its route, but `Get.find()`
  /// rebuilds it on demand.
  Get.smartManagement = SmartManagement.keepFactory;

  /// Core
  final sharedPreferences = await SharedPreferences.getInstance();
  _lazy(() => sharedPreferences);

  /// The auth token lives in encrypted storage, not SharedPreferences, but is
  /// read synchronously in 18 places — including the ApiClient constructor two
  /// lines below, which builds the Authorization header. Hydrate the
  /// synchronous cache here, before anything can read it, and migrate any
  /// plaintext token left by a previous build. See [AuthTokenStore].
  await AuthTokenStore.hydrate(sharedPreferences);
  _lazy(
    () => ApiClient(
      appBaseUrl: AppConstants.baseUrl,
      sharedPreferences: Get.find(),
    ),
  );

  /// Repository interface
  _lazy<CheckoutRepositoryInterface>(
    () => CheckoutRepository(
      apiClient: Get.find(),
      sharedPreferences: Get.find(),
    ),
  );
  _lazy<AuthRepositoryInterface>(
    () => AuthRepository(apiClient: Get.find(), sharedPreferences: Get.find()),
  );
  _lazy<LocationRepositoryInterface>(
    () => LocationRepository(apiClient: Get.find()),
  );
  _lazy<DeliverymanRegistrationRepositoryInterface>(
    () => DeliverymanRegistrationRepository(
      apiClient: Get.find(),
      sharedPreferences: Get.find(),
    ),
  );
  _lazy<StoreRegistrationRepositoryInterface>(
    () => StoreRegistrationRepository(apiClient: Get.find()),
  );
  _lazy<ParcelRepositoryInterface>(
    () => ParcelRepository(apiClient: Get.find()),
  );
  _lazy<AddressRepositoryInterface>(
    () => AddressRepository(apiClient: Get.find()),
  );
  _lazy<OrderRepositoryInterface>(() => OrderRepository(apiClient: Get.find()));
  _lazy<PaymentRepositoryInterface>(
    () =>
        PaymentRepository(apiClient: Get.find(), sharedPreferences: Get.find()),
  );
  _lazy<CampaignRepositoryInterface>(
    () => CampaignRepository(apiClient: Get.find()),
  );
  _lazy<ChatRepositoryInterface>(
    () => ChatRepository(apiClient: Get.find(), sharedPreferences: Get.find()),
  );
  _lazy<CouponRepositoryInterface>(
    () => CouponRepository(apiClient: Get.find()),
  );
  _lazy<FavouriteRepositoryInterface>(
    () => FavouriteRepository(apiClient: Get.find()),
  );
  _lazy<FlashSaleRepositoryInterface>(
    () => FlashSaleRepository(apiClient: Get.find()),
  );
  _lazy<HomeRepositoryInterface>(
    () => HomeRepository(apiClient: Get.find(), sharedPreferences: Get.find()),
  );
  _lazy<BannerRepositoryInterface>(
    () => BannerRepository(apiClient: Get.find()),
  );
  _lazy<HtmlRepositoryInterface>(() => HtmlRepository(apiClient: Get.find()));
  _lazy<LanguageRepositoryInterface>(
    () => LanguageRepository(
      apiClient: Get.find(),
      sharedPreferences: Get.find(),
    ),
  );
  _lazy<NotificationRepositoryInterface>(
    () => NotificationRepository(
      sharedPreferences: Get.find(),
      apiClient: Get.find(),
    ),
  );
  _lazy<OnboardRepositoryInterface>(() => OnboardRepository());
  _lazy<ProfileRepositoryInterface>(
    () => ProfileRepository(apiClient: Get.find()),
  );
  _lazy<SearchRepositoryInterface>(
    () =>
        SearchRepository(apiClient: Get.find(), sharedPreferences: Get.find()),
  );
  _lazy<SplashRepositoryInterface>(
    () =>
        SplashRepository(sharedPreferences: Get.find(), apiClient: Get.find()),
  );
  _lazy<ReviewRepositoryInterface>(
    () => ReviewRepository(apiClient: Get.find()),
  );
  _lazy<StoreRepositoryInterface>(
    () => StoreRepository(apiClient: Get.find(), sharedPreferences: Get.find()),
  );
  _lazy<WalletRepositoryInterface>(
    () =>
        WalletRepository(sharedPreferences: Get.find(), apiClient: Get.find()),
  );
  _lazy<ItemRepositoryInterface>(() => ItemRepository(apiClient: Get.find()));
  _lazy<CategoryRepositoryInterface>(
    () => CategoryRepository(apiClient: Get.find()),
  );
  _lazy<CuisineRepositoryInterface>(
    () => CuisineRepository(apiClient: Get.find()),
  );
  _lazy<LoyaltyRepositoryInterface>(
    () => LoyaltyRepository(apiClient: Get.find()),
  );
  _lazy<XpRepositoryInterface>(() => XpRepository(apiClient: Get.find()));
  _lazy<PlacesRepositoryInterface>(
    () => PlacesRepository(apiClient: Get.find()),
  );
  _lazy<CartRepositoryInterface>(
    () => CartRepository(apiClient: Get.find(), sharedPreferences: Get.find()),
  );
  _lazy<VerificationRepositoryInterface>(
    () => VerificationRepository(
      apiClient: Get.find(),
      sharedPreferences: Get.find(),
    ),
  );
  _lazy<BrandsRepositoryInterface>(
    () => BrandsRepository(apiClient: Get.find()),
  );
  _lazy<BusinessRepoInterface>(() => BusinessRepo(apiClient: Get.find()));
  _lazy<AdvertisementRepositoryInterface>(
    () => AdvertisementRepository(apiClient: Get.find()),
  );

  /// Service Interface
  _lazy<CheckoutServiceInterface>(
    () => CheckoutService(checkoutRepositoryInterface: Get.find()),
  );
  _lazy<AuthServiceInterface>(
    () => AuthService(authRepositoryInterface: Get.find()),
  );
  _lazy<LocationServiceInterface>(
    () => LocationService(locationRepoInterface: Get.find()),
  );
  _lazy<DeliverymanRegistrationServiceInterface>(
    () => DeliverymanRegistrationService(
      deliverymanRegistrationRepoInterface: Get.find(),
      authRepositoryInterface: Get.find(),
    ),
  );
  _lazy<StoreRegistrationServiceInterface>(
    () => StoreRegistrationService(
      deliverymanRegistrationRepositoryInterface: Get.find(),
      storeRegistrationRepoInterface: Get.find(),
    ),
  );
  _lazy<ParcelServiceInterface>(
    () => ParcelService(
      parcelRepositoryInterface: Get.find(),
      checkoutRepositoryInterface: Get.find(),
    ),
  );
  _lazy<AddressServiceInterface>(
    () => AddressService(addressRepoInterface: Get.find()),
  );
  _lazy<OrderServiceInterface>(
    () => OrderService(orderRepositoryInterface: Get.find()),
  );
  _lazy<PaymentServiceInterface>(
    () => PaymentService(paymentRepositoryInterface: Get.find()),
  );
  _lazy<CampaignServiceInterface>(
    () => CampaignService(campaignRepositoryInterface: Get.find()),
  );
  _lazy<ChatServiceInterface>(
    () => ChatService(chatRepositoryInterface: Get.find()),
  );
  _lazy<CouponServiceInterface>(
    () => CouponService(couponRepositoryInterface: Get.find()),
  );
  _lazy<FavouriteServiceInterface>(
    () => FavouriteService(favouriteRepositoryInterface: Get.find()),
  );
  _lazy<HomeServiceInterface>(
    () => HomeService(homeRepositoryInterface: Get.find()),
  );
  _lazy<FlashSaleServiceInterface>(
    () => FlashSaleService(flashSaleRepositoryInterface: Get.find()),
  );
  _lazy<BannerServiceInterface>(
    () => BannerService(bannerRepositoryInterface: Get.find()),
  );
  _lazy<HtmlServiceInterface>(
    () => HtmlService(htmlRepositoryInterface: Get.find()),
  );
  _lazy<LanguageServiceInterface>(
    () => LanguageService(languageRepositoryInterface: Get.find()),
  );
  _lazy<NotificationServiceInterface>(
    () => NotificationService(notificationRepositoryInterface: Get.find()),
  );
  _lazy<OnboardServiceInterface>(
    () => OnboardService(onboardRepositoryInterface: Get.find()),
  );
  _lazy<ProfileServiceInterface>(
    () => ProfileService(profileRepositoryInterface: Get.find()),
  );
  _lazy<SearchServiceInterface>(
    () => SearchService(searchRepositoryInterface: Get.find()),
  );
  _lazy<SplashServiceInterface>(
    () => SplashService(splashRepositoryInterface: Get.find()),
  );
  _lazy<ReviewServiceInterface>(
    () => ReviewService(reviewRepositoryInterface: Get.find()),
  );
  _lazy<StoreServiceInterface>(
    () => StoreService(storeRepositoryInterface: Get.find()),
  );
  _lazy<WalletServiceInterface>(
    () => WalletService(walletRepositoryInterface: Get.find()),
  );
  _lazy<ItemServiceInterface>(
    () => ItemService(itemRepositoryInterface: Get.find()),
  );
  _lazy<CategoryServiceInterface>(
    () => CategoryService(categoryRepositoryInterface: Get.find()),
  );
  _lazy<CuisineServiceInterface>(
    () => CuisineService(cuisineRepositoryInterface: Get.find()),
  );
  _lazy<LoyaltyServiceInterface>(
    () => LoyaltyService(loyaltyRepositoryInterface: Get.find()),
  );
  _lazy<XpServiceInterface>(() => XpService(xpRepositoryInterface: Get.find()));
  _lazy<PlacesServiceInterface>(
    () => PlacesService(placesRepositoryInterface: Get.find()),
  );
  _lazy<CartServiceInterface>(
    () => CartService(cartRepositoryInterface: Get.find()),
  );
  _lazy<VerificationServiceInterface>(
    () => VerificationService(
      verificationRepoInterface: Get.find(),
      authRepoInterface: Get.find(),
    ),
  );
  _lazy<BrandsServiceInterface>(
    () => BrandsService(brandsRepositoryInterface: Get.find()),
  );
  _lazy<BusinessServiceInterface>(
    () => BusinessService(businessRepoInterface: Get.find()),
  );
  _lazy<AdvertisementServiceInterface>(
    () => AdvertisementService(advertisementRepositoryInterface: Get.find()),
  );

  /// Controller
  _lazy(() => ThemeController(sharedPreferences: Get.find()));
  _lazy(() => SplashController(splashServiceInterface: Get.find()));
  _lazy(() => AddressController(addressServiceInterface: Get.find()));
  _lazy(() => LocationController(locationServiceInterface: Get.find()));
  _lazy(() => LocalizationController(languageServiceInterface: Get.find()));
  _lazy(() => OnBoardingController(onboardServiceInterface: Get.find()));
  _lazy(() => AuthController(authServiceInterface: Get.find()));
  _lazy(
    () => DeliverymanRegistrationController(
      deliverymanRegistrationServiceInterface: Get.find(),
    ),
  );
  _lazy(
    () => StoreRegistrationController(
      storeRegistrationServiceInterface: Get.find(),
      locationServiceInterface: Get.find(),
    ),
  );
  _lazy(() => ProfileController(profileServiceInterface: Get.find()));
  _lazy(() => BannerController(bannerServiceInterface: Get.find()));
  _lazy(() => CategoryController(categoryServiceInterface: Get.find()));
  _lazy(() => CuisineController(cuisineServiceInterface: Get.find()));
  _lazy(() => ItemController(itemServiceInterface: Get.find()));
  _lazy(() => CartController(cartServiceInterface: Get.find()));
  _lazy(() => StoreController(storeServiceInterface: Get.find()));
  _lazy(() => FavouriteController(favouriteServiceInterface: Get.find()));
  _lazy(() => HomeController(homeServiceInterface: Get.find()));
  _lazy(() => SearchController(searchServiceInterface: Get.find()));
  _lazy(() => CouponController(couponServiceInterface: Get.find()));
  _lazy(() => OrderController(orderServiceInterface: Get.find()));
  _lazy(() => NotificationController(notificationServiceInterface: Get.find()));
  _lazy(() => CampaignController(campaignServiceInterface: Get.find()));
  _lazy(() => ParcelController(parcelServiceInterface: Get.find()));
  _lazy(() => WalletController(walletServiceInterface: Get.find()));
  _lazy(() => ChatController(chatServiceInterface: Get.find()));
  _lazy(() => FlashSaleController(flashSaleServiceInterface: Get.find()));
  _lazy(() => CheckoutController(checkoutServiceInterface: Get.find()));
  _lazy(() => PaymentController(paymentServiceInterface: Get.find()));
  _lazy(() => HtmlController(htmlServiceInterface: Get.find()));
  _lazy(() => ReviewController(reviewServiceInterface: Get.find()));
  _lazy(() => CategoryController(categoryServiceInterface: Get.find()));
  _lazy(() => LoyaltyController(loyaltyServiceInterface: Get.find()));
  _lazy(() => XpController(xpServiceInterface: Get.find()));
  _lazy(() => PlacesController(placesServiceInterface: Get.find()));
  _lazy(() => VerificationController(verificationServiceInterface: Get.find()));
  _lazy(() => BrandsController(brandsServiceInterface: Get.find()));
  _lazy(() => BusinessController(businessServiceInterface: Get.find()));
  _lazy(
    () => AdvertisementController(advertisementServiceInterface: Get.find()),
  );

  /// Retrieving localized data — ONLY the locale about to be rendered.
  ///
  /// This used to load every bundle the app ships: 285 KB of JSON read,
  /// decoded and rebuilt key-by-key on the main isolate, synchronously, before
  /// runApp was ever called. The user needs one of them. The rest are loaded a
  /// frame later by [loadRemainingLanguages].
  final LanguageModel active = _activeLanguage(sharedPreferences);
  return <String, Map<String, String>>{
    _localeKey(active): await _loadLanguage(active),
  };
}

/// `Get.lazyPut` with fenix forced on — see the note at the top of [init].
///
/// Registering through this instead of `Get.lazyPut` directly keeps each
/// builder in the container after the route that first built it is disposed,
/// so a later `Get.find()` rebuilds the instance rather than throwing.
void _lazy<S>(InstanceBuilderCallback<S> builder) =>
    Get.lazyPut<S>(builder, fenix: true);

String _localeKey(LanguageModel m) => '${m.languageCode}_${m.countryCode}';

Future<Map<String, String>> _loadLanguage(LanguageModel languageModel) async {
  final String jsonStringValues = await rootBundle.loadString(
    'assets/language/${languageModel.languageCode}.json',
  );
  final Map<String, dynamic> mappedJson = jsonDecode(jsonStringValues);
  final Map<String, String> json = <String, String>{};
  mappedJson.forEach((key, value) {
    json[key] = value.toString();
  });
  return json;
}

/// Which bundle to have ready for the first frame.
///
/// Mirrors how the locale is actually resolved later, in this order, so the
/// preloaded bundle is the one that ends up being used:
///   1. a language the user previously chose (SharedPreferences), then
///   2. the device locale, if the app ships it — this is what
///      `_applyDeviceLanguage` in splash_route_helper picks on a first launch,
///      then
///   3. the first shipped language, which is also the fallbackLocale.
LanguageModel _activeLanguage(SharedPreferences prefs) {
  final String? saved = prefs.getString(AppConstants.languageCode);
  if (saved != null && saved.isNotEmpty) {
    for (final LanguageModel m in AppConstants.languages) {
      if (m.languageCode == saved) return m;
    }
  }

  final String deviceCode =
      PlatformDispatcher.instance.locale.languageCode.toLowerCase();
  for (final LanguageModel m in AppConstants.languages) {
    if (m.languageCode?.toLowerCase() == deviceCode) return m;
  }

  return AppConstants.languages[0];
}

/// Loads the bundles [init] skipped and hands them to GetX.
///
/// Call once after the first frame. Until it completes the app has exactly one
/// language in memory, so a key missing from it resolves to the key itself
/// rather than to the fallback locale's copy — which is why this runs on the
/// very next frame rather than lazily on first use. The language picker is
/// many taps away; this window closes long before it can be reached.
Future<void> loadRemainingLanguages(
  Map<String, Map<String, String>> alreadyLoaded,
) async {
  for (final LanguageModel languageModel in AppConstants.languages) {
    final String key = _localeKey(languageModel);
    if (alreadyLoaded.containsKey(key)) continue;
    try {
      final Map<String, String> bundle = await _loadLanguage(languageModel);
      alreadyLoaded[key] = bundle;
      Get.appendTranslations(<String, Map<String, String>>{key: bundle});
    } catch (e) {
      // A missing or malformed bundle must not take the app down after it has
      // already rendered; the active language is loaded and working.
      if (kDebugMode) {
        debugPrint('[Waddy] failed to load language $key: $e');
      }
    }
  }
}
