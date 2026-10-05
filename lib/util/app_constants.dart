import 'package:get/get.dart';
import 'package:waddy_app/common/models/choose_us_model.dart';
import 'package:waddy_app/features/language/domain/models/language_model.dart';
import 'package:waddy_app/util/app_environment.dart';
import 'package:waddy_app/util/images.dart';

class AppConstants {
  static const String appName = 'Waddy';
  static const double appVersion = 3.3;

  ///Flutter sdk 3.32.8

  /// Body face — Thmanyah Sans.
  static const String fontFamily = 'ThmanyahSans';

  /// Display face — headlines, scores, kickers, rank numerals. Alexandria is
  /// heavier and more geometric than the body face, which is what lets a
  /// headline outrank body copy by voice instead of by size alone.
  static const String displayFontFamily = 'Alexandria';

  // Fallback seed coordinates (Maadi center) used by guest bootstrap when the
  // config API's default_location is missing or unparseable.
  static const double maadiDefaultLatitude = 29.9602;
  static const double maadiDefaultLongitude = 31.2569;

  static const bool payInWevView = false;
  static const int balanceInputLen = 10;

  /// The web host, per build flavor. See [AppEnvironment].
  static const String webHostedUrl = AppEnvironment.webHostedUrl;
  static const bool useReactWebsite = false;

  /// The API host, per build flavor.
  ///
  /// This used to be a hardcoded production URL, which meant every developer
  /// run, QA pass and debug session wrote to live customer data. It is now
  /// selected at build time and cannot be changed at runtime — see
  /// [AppEnvironment] and the `env/*.json` files.
  static const String baseUrl = AppEnvironment.baseUrl;
  static const String categoryUri = '/api/v1/categories';
  static const String cuisineUri = '/api/v1/cuisine/list';
  static const String cuisineStoreUri = '/api/v1/cuisine/stores/';
  static const String bannerUri = '/api/v1/banners';
  static const String storeItemUri = '/api/v1/items/latest';
  static const String buyAgainUri = '/api/v1/items/buy-again';
  static const String pairsWithUri = '/api/v1/items/pairs-with';
  static const String popularItemUri = '/api/v1/items/popular';
  static const String reviewedItemUri = '/api/v1/items/most-reviewed';
  static const String searchItemUri = '/api/v1/items/details/';
  static const String subCategoryUri = '/api/v1/categories/childes/';
  static const String categoryItemUri = '/api/v1/categories/items/';
  static const String categoryStoreUri = '/api/v1/categories/stores/';
  static const String configUri = '/api/v1/config';
  static const String trackUri = '/api/v1/customer/order/track?order_id=';
  static const String riderLocationUri =
      '/api/v1/customer/order/rider-location?order_id=';
  static const String messageUri = '/api/v1/customer/message/get';
  static const String forgetPasswordUri = '/api/v1/auth/forgot-password';
  static const String verifyTokenUri = '/api/v1/auth/verify-token';
  static const String resetPasswordUri = '/api/v1/auth/reset-password';
  static const String verifyPhoneUri = '/api/v1/auth/verify-phone';
  static const String checkEmailUri = '/api/v1/auth/check-email';
  static const String verifyEmailUri = '/api/v1/auth/verify-email';
  static const String registerUri = '/api/v1/auth/sign-up';
  static const String loginUri = '/api/v1/auth/login';
  static const String tokenUri = '/api/v1/customer/cm-firebase-token';
  static const String liveActivityTokenUri =
      '/api/v1/customer/live-activity-token';
  static const String placeOrderUri = '/api/v1/customer/order/place';
  static const String placePrescriptionOrderUri =
      '/api/v1/customer/order/prescription/place';
  static const String addressListUri = '/api/v1/customer/address/list';
  static const String zoneUri = '/api/v1/config/get-zone-id';
  static const String checkZoneUri = '/api/v1/zone/check';
  static const String removeAddressUri =
      '/api/v1/customer/address/delete?address_id=';
  static const String addAddressUri = '/api/v1/customer/address/add';
  static const String updateAddressUri = '/api/v1/customer/address/update/';
  static const String setMenuUri = '/api/v1/items/set-menu';
  static const String customerInfoUri = '/api/v1/customer/info';
  static const String couponUri = '/api/v1/coupon/list';
  static const String couponApplyUri = '/api/v1/coupon/apply?code=';
  static const String runningOrderListUri =
      '/api/v1/customer/order/running-orders';
  static const String historyOrderListUri = '/api/v1/customer/order/list';
  static const String orderCancelUri = '/api/v1/customer/order/cancel';
  static const String codSwitchUri = '/api/v1/customer/order/payment-method';
  static const String orderDetailsUri =
      '/api/v1/customer/order/details?order_id=';
  static const String reorderUri = '/api/v1/customer/order/reorder';
  static const String wishListGetUri = '/api/v1/customer/wish-list';
  static const String addWishListUri = '/api/v1/customer/wish-list/add?';
  static const String removeWishListUri = '/api/v1/customer/wish-list/remove?';
  static const String notificationUri = '/api/v1/customer/notifications';
  static const String updateProfileUri = '/api/v1/customer/update-profile';
  static const String searchUri = '/api/v1/';
  static const String globalSearchUri = '/api/v1/search/global';
  static const String reviewUri = '/api/v1/items/reviews/submit';
  static const String itemDetailsUri = '/api/v1/items/details/';
  static const String lastLocationUri =
      '/api/v1/delivery-man/last-location?order_id=';
  static const String deliveryManReviewUri =
      '/api/v1/delivery-man/reviews/submit';
  static const String storeUri = '/api/v1/stores/get-stores';
  static const String popularStoreUri = '/api/v1/stores/popular';
  static const String latestStoreUri = '/api/v1/stores/latest';
  static const String topOfferStoreUri = '/api/v1/stores/top-offer-near-me';
  static const String storeDetailsUri = '/api/v1/stores/details/';
  static const String basicCampaignUri = '/api/v1/campaigns/basic';
  static const String itemCampaignUri = '/api/v1/campaigns/item';
  static const String basicCampaignDetailsUri =
      '/api/v1/campaigns/basic-campaign-details?basic_campaign_id=';
  static const String interestUri = '/api/v1/customer/update-interest';
  static const String suggestedItemUri = '/api/v1/customer/suggested-items';
  static const String storeReviewUri = '/api/v1/stores/reviews';
  static const String distanceMatrixUri = '/api/v1/config/distance-api';
  static const String searchLocationUri =
      '/api/v1/config/place-api-autocomplete';
  static const String placeDetailsUri = '/api/v1/config/place-api-details';
  static const String geocodeUri = '/api/v1/config/geocode-api';
  static const String socialLoginUri = '/api/v1/auth/social-login';
  static const String socialRegisterUri = '/api/v1/auth/social-register';
  static const String updateZoneUri = '/api/v1/customer/update-zone';
  static const String moduleUri = '/api/v1/module';
  static const String parcelCategoryUri = '/api/v1/parcel-category';
  static const String aboutUsUri = '/api/v1/about-us';
  static const String privacyPolicyUri = '/api/v1/privacy-policy';
  static const String termsAndConditionUri = '/api/v1/terms-and-conditions';
  static const String cancellationUri = '/api/v1/cancelation';
  static const String refundUri = '/api/v1/refund-policy';
  static const String shippingPolicyUri = '/api/v1/shipping-policy';
  static const String subscriptionUri = '/api/v1/newsletter/subscribe';
  static const String customerRemoveUri = '/api/v1/customer/remove-account';
  static const String walletTransactionUri =
      '/api/v1/customer/wallet/transactions';
  static const String loyaltyTransactionUri =
      '/api/v1/customer/loyalty-point/transactions';
  static const String loyaltyPointTransferUri =
      '/api/v1/customer/loyalty-point/point-transfer';
  static const String zoneListUri = '/api/v1/zone/list';

  /// Demand capture for un-served areas ("notify me when you launch here").
  static const String zoneRequestUri = '/api/v1/zone-request';
  static const String zoneRequestStatusUri = '/api/v1/zone-request/status';
  static const String storeRegisterUri = '/api/v1/auth/vendor/register';
  static const String dmRegisterUri = '/api/v1/auth/delivery-man/store';
  static const String refundReasonUri = '/api/v1/customer/order/refund-reasons';
  static const String supportReasonUri = '/api/v1/customer/automated-message';
  static const String refundRequestUri =
      '/api/v1/customer/order/refund-request';
  static const String directionUri = '/api/v1/config/direction-api';
  static const String vehicleListUri = '/api/v1/vehicles/list';
  static const String vehicleChargeUri = '/api/v1/vehicle/extra_charge';
  static const String vehiclesUri = '/api/v1/get-vehicles';
  static const String storeRecommendedItemUri = '/api/v1/items/recommended';
  static const String orderCancellationUri =
      '/api/v1/customer/order/cancellation-reasons';
  static const String cartStoreSuggestedItemsUri = '/api/v1/items/suggested';
  static const String landingPageUri = '/api/v1/flutter-landing-page';
  static const String mostTipsUri = '/api/v1/most-tips';
  static const String addFundUri = '/api/v1/customer/wallet/add-fund';
  static const String walletBonusUri = '/api/v1/customer/wallet/bonuses';
  static const String guestLoginUri = '/api/v1/auth/guest/request';
  static const String offlineMethodListUri =
      '/api/v1/offline_payment_method_list';
  static const String offlinePaymentSaveInfoUri =
      '/api/v1/customer/order/offline-payment';
  static const String offlinePaymentUpdateInfoUri =
      '/api/v1/customer/order/offline-payment-update';
  static const String storeBannersUri = '/api/v1/banners/';
  static const String recommendedItemsUri = '/api/v1/items/recommended?filter=';
  static const String visitAgainStoreUri = '/api/v1/customer/visit-again';
  static const String discountedItemsUri = '/api/v1/items/discounted';
  static const String parcelOtherBannerUri = '/api/v1/other-banners';
  static const String whyChooseUri = '/api/v1/other-banners/why-choose';
  static const String videoContentUri = '/api/v1/other-banners/video-content';
  static const String promotionalBannerUri = '/api/v1/other-banners';
  static const String basicMedicineUri = '/api/v1/items/basic';
  static const String commonConditionUri = '/api/v1/common-condition';
  static const String conditionWiseItemUri = '/api/v1/common-condition/items/';
  static const String flashSaleUri = '/api/v1/flash-sales';
  static const String flashSaleProductsUri = '/api/v1/flash-sales/items';
  static const String ramadanFeaturedItemsUri =
      '/api/v1/items/ramadan-featured';
  static const String featuredCategoriesItemsUri =
      '/api/v1/categories/featured/items';
  static const String recommendedStoreUri = '/api/v1/stores/recommended';
  static const String similarStoresUri = '/api/v1/stores/similar';
  static const String storeBundlesUri = '/api/v1/stores/';
  static const String parcelInstructionUri =
      '/api/v1/customer/order/parcel-instructions';
  static const String cashBackOfferListUri = '/api/v1/cashback/list';
  static const String getCashBackAmountUri = '/api/v1/cashback/getCashback';
  static const String brandListUri = '/api/v1/brand';
  static const String brandItemUri = '/api/v1/brand/items';
  static const String advertisementListUri = '/api/v1/advertisement/list';
  static const String searchSuggestionsUri =
      '/api/v1/items/item-or-store-search';
  static const String searchPopularCategoriesUri = '/api/v1/categories/popular';
  static const String firebaseAuthVerify = '/api/v1/auth/firebase-verify-token';
  static const String personalInformationUri = '/api/v1/auth/update-info';
  static const String firebaseResetPassword =
      '/api/v1/auth/firebase-reset-password';
  static const String getOrderTaxUri = '/api/v1/customer/order/get-Tax';
  static const String getSurgePriceUri =
      '/api/v1/customer/order/get-surge-price';
  static const String toggleHidePhoneUri = '/api/v1/customer/toggle-hide-phone';

  /// XP & Leveling System
  // Level data is fetched via the merged xpLevelDetailsUri endpoint; the legacy
  // /xp/level and /xp/levels endpoints are no longer called by the client.
  // Pets module (docs/pets_module_plan.md)
  static const String petsListUri = '/api/v1/customer/pets/list';
  static const String petsAddUri = '/api/v1/customer/pets/add';
  static const String petsUpdateUri = '/api/v1/customer/pets/update/';
  static const String petsDeleteUri = '/api/v1/customer/pets/delete/';
  static const String petsClinicsUri = '/api/v1/pets/clinics';
  static const String petsCategoriesUri = '/api/v1/pets/categories';
  static const String petsUsualUri = '/api/v1/customer/pets/usual';
  static const String petsRemindersUri = '/api/v1/customer/pets/reminders';
  static const String xpChallengesUri = '/api/v1/customer/xp/challenges';
  static const String xpClaimChallengeUri = '/api/v1/customer/xp/challenges/';
  static const String xpPrizesUri = '/api/v1/customer/xp/prizes';
  static const String xpClaimPrizeUri = '/api/v1/customer/xp/prizes/';
  static const String xpCheckoutPrizesUri =
      '/api/v1/customer/xp/checkout-prizes';
  static const String xpConfigUri = '/api/v1/xp/config';
  static const String xpLevelDetailsUri = '/api/v1/customer/xp/level-details';
  static const String xpAcknowledgeLevelUpsUri =
      '/api/v1/customer/xp/level-ups/acknowledge';
  static const String xpLeaderboardUri = '/api/v1/customer/xp/leaderboard';

  /// Places to Visit / Hidden Gems
  static const String placesUri = '/api/v1/places';
  static const String placesCategoriesUri = '/api/v1/places/categories';
  static const String placesLeaderboardUri = '/api/v1/places/leaderboard';
  static const String placesTrendingUri = '/api/v1/places/trending';
  static const String placesTagsUri = '/api/v1/places/tags';
  static const String placesBannersUri = '/api/v1/places/banners/featured';
  static const String placesFavoritesUri = '/api/v1/places/favorites/my';
  static const String placesSubmissionsUri = '/api/v1/places/submissions';
  static const String placesSubmissionsMyUri = '/api/v1/places/submissions/my';
  static const String placesTopVotersUri = '/api/v1/places/top-voters';
  static const String placesZonesUri = '/api/v1/places/zones';
  static const String placesPrizesMyUri = '/api/v1/places/prizes/my';
  static const String placesRecentWinnersUri = '/api/v1/places/winners/recent';

  /// The claw-machine replay. Append a period ("/2026-W27") for a specific
  /// draw; bare, the server answers with the last closed period.
  static const String placesDrawUri = '/api/v1/places/draw';

  ///Subscription
  static const String businessPlanUri = '/api/v1/vendor/business_plan';
  static const String businessPlanPaymentUri =
      '/api/v1/vendor/subscription/payment/api';
  static const String storePackagesUri = '/api/v1/vendor/package-view';

  /// MESSAGING
  static const String conversationListUri = '/api/v1/customer/message/list';
  static const String searchConversationListUri =
      '/api/v1/customer/message/search-list';
  static const String messageListUri = '/api/v1/customer/message/details';
  static const String sendMessageUri = '/api/v1/customer/message/send';
  static const String markMessageReadUri = '/api/v1/customer/message/mark-read';

  /// Cart
  static const String getCartListUri = '/api/v1/customer/cart/list';
  static const String addCartUri = '/api/v1/customer/cart/add';
  static const String updateCartUri = '/api/v1/customer/cart/update';
  static const String removeAllCartUri = '/api/v1/customer/cart/remove';
  static const String removeItemCartUri = '/api/v1/customer/cart/remove-item';

  /// Shared Key
  static const String theme = '6ammart_theme';
  static const String token = '6ammart_token';
  static const String countryCode = '6ammart_country_code';
  static const String languageCode = '6ammart_language_code';
  static const String cacheCountryCode = 'cache_country_code';
  static const String cacheLanguageCode = 'cache_language_code';
  static const String cartList = '6ammart_cart_list';
  static const String userPassword = '6ammart_user_password';
  static const String userAddress = '6ammart_user_address';
  static const String userNumber = '6ammart_user_number';
  static const String userCountryCode = '6ammart_user_country_code';
  static const String notification = '6ammart_notification';
  static const String notificationIdList = 'notification_id_list';
  static const String searchHistory = '6ammart_search_history';
  static const String intro = '6ammart_intro';

  /// A guest's pet from onboarding, sent to the server after sign-in.
  static const String petDraft = 'waddy_pet_draft';
  static const String petOnboardingSeen = 'waddy_pet_onboarding_seen';
  static const String notificationCount = '6ammart_notification_count';
  static const String dmTipIndex = '6ammart_dm_tip_index';
  static const String earnPoint = '6ammart_earn_point';
  static const String suggestedLocation = '6ammart_suggested_location';
  static const String walletAccessToken = '6ammart_wallet_access_token';
  static const String guestId = '6ammart_guest_id';

  /// Set once the user has asked us to launch in their area, so we never
  /// prompt the same person twice.
  static const String zoneRequestSubmitted = 'waddi_zone_request_submitted';

  /// True between "OTP verified" and "name submitted". The backend hands out
  /// a temporary token in that window, so a token alone doesn't mean the
  /// account is usable — the splash gate reads this to resume the profile
  /// step after a restart or a killed app.
  static const String profileIncomplete = 'waddi_profile_incomplete';

  /// The verified phone belonging to [profileIncomplete], so the resumed name
  /// step can submit without asking for the number again.
  static const String pendingProfilePhone = 'waddi_pending_profile_phone';

  /// A request that failed to reach the server, parked for replay on next
  /// launch. The tap was a promise; a network blip must not silently drop it.
  static const String zoneRequestPending = 'waddi_zone_request_pending';
  static const String guestNumber = '6ammart_guest_number';
  static const String referBottomSheet = '6ammart_reffer_bottomsheet_show';
  static const String welcomeLetterShown = 'waddi_welcome_letter_shown';
  static const String zoneHintDismissedAt = 'waddi_zone_hint_dismissed_at';
  // Set once the "No delivery there" sheet auto-shows for the current
  // out-of-zone episode; cleared when the user comes back in zone so the next
  // out-of-zone episode shows it again. See GuestGate.maybeAutoShowNoDelivery.
  static const String noDeliverySheetShown = 'waddi_no_delivery_sheet_shown';
  static const String guestBootstrapFailCount =
      'waddi_guest_bootstrap_fail_count';
  // LEGACY, migration only. Older builds saved a fabricated fallback address
  // and set this flag. Nothing writes it any more; the splash route helper
  // reads it once to clear those stale saves, then removes it. Safe to delete
  // once no install can still be running a build older than that migration.
  static const String addressIsSeed = 'waddi_address_is_seed';
  // Serving zone (comma-joined zone ids) the "You're a bit far away from your
  // address!" sheet was last answered for. Suppresses a re-ask while the user
  // stays in that zone; moving to a different one asks again.
  static const String addressDivergenceAskedZone =
      'waddi_address_divergence_asked_zone';
  static const String xpOnboardingShown = 'waddi_xp_onboarding_shown';
  static const String walletCardAppearance = 'waddi_wallet_card_appearance';
  static const String walletCardSymbol = 'waddi_wallet_card_symbol';
  static const String dmRegisterSuccess = '6ammart_dm_registration_success';
  static const String isRestaurantRegister = '6ammart_store_registration';

  static const String topic = 'all_zone_customer';
  static const String zoneId = 'zoneId';
  static const String operationAreaId = 'operationAreaId';
  static const String moduleId = 'moduleId';
  static const String cacheModuleId = 'cacheModuleId';
  static const String localizationKey = 'X-localization';
  static const String latitude = 'latitude';
  static const String longitude = 'longitude';

  ///Refer & Earn work flow list..
  static final dataList = [
    'invite_your_friends_and_business'.tr,
    '${'they_register'.tr} ${AppConstants.appName} ${'with_special_offer'.tr}',
    'you_made_your_earning'.tr,
  ];

  /// Delivery Tips
  /// Rider tip options. First is "no tip", last is "custom"; the checkout
  /// tip card pairs each with a McCoin mood (sad → hi → happy → cool).
  static List<String> tips = ['0', '10', '15', '20', 'custom'];
  static List<String> deliveryInstructionList = [
    'avoid_calling',
    'dont_ring_the_bell',
    'leave_at_the_door',
    'leave_with_guard',
    'deliver_to_front_door',
    'deliver_the_reception_desk',
  ];

  static List<ChooseUsModel> whyChooseUsList = [
    ChooseUsModel(
      icon: Images.landingTrusted,
      title: 'trusted_by_customers_and_store_owners',
    ),
    ChooseUsModel(icon: Images.landingStores, title: 'thousands_of_stores'),
    ChooseUsModel(
      icon: Images.landingExcellent,
      title: 'excellent_shopping_experience',
    ),
    ChooseUsModel(
      icon: Images.landingCheckout,
      title: 'easy_checkout_and_payment_system',
    ),
  ];

  /// order status..
  static const String pending = 'pending';
  static const String accepted = 'accepted';
  static const String processing = 'processing';
  static const String confirmed = 'confirmed';
  static const String handover = 'handover';
  static const String pickedUp = 'picked_up';
  static const String delivered = 'delivered';

  ///modules..
  static const String pharmacy = 'pharmacy';
  static const String food = 'food';
  static const String parcel = 'parcel';
  static const String ecommerce = 'ecommerce';
  static const String grocery = 'grocery';
  static const String places = 'places';
  static const String pets = 'pets';

  static List<LanguageModel> languages = [
    LanguageModel(
      imageUrl: Images.english,
      languageName: 'English',
      countryCode: 'US',
      languageCode: 'en',
    ),
    LanguageModel(
      imageUrl: Images.arabic,
      languageName: 'عربى',
      countryCode: 'EG',
      languageCode: 'ar',
    ),
    // LanguageModel(
    //   imageUrl: Images.spanish,
    //   languageName: 'Spanish',
    //   countryCode: 'ES',
    //   languageCode: 'es',
    // ),
    // LanguageModel(
    //   imageUrl: Images.bengali,
    //   languageName: 'Bengali',
    //   countryCode: 'BN',
    //   languageCode: 'bn',
    // ),
  ];

  static List<String> joinDropdown = [
    'join_us',
    'become_a_seller',
    'become_a_delivery_man',
  ];

  static final List<Map<String, String>> walletTransactionSortingList = [
    {'title': 'filter_all_transactions', 'value': 'all'},
    {'title': 'filter_additions', 'value': 'add_fund'},
    {'title': 'filter_deductions', 'value': 'order'},
    {'title': 'filter_refunds', 'value': 'CashBack'},
    {'title': 'filter_rewards', 'value': 'loyalty_point'},
    {'title': 'filter_referral', 'value': 'referrer'},
  ];
}
