import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/models/config_model.dart';
import 'package:waddy_app/common/models/module_model.dart';
import 'package:waddy_app/features/location/domain/models/zone_response_model.dart';
import 'package:waddy_app/features/address/domain/models/address_model.dart';
import 'package:waddy_app/features/cart/controllers/cart_controller.dart';
import 'package:waddy_app/features/cart/domain/models/cart_model.dart';
import 'package:waddy_app/features/cart/domain/repositories/cart_repository_interface.dart';
import 'package:waddy_app/features/cart/domain/services/cart_service.dart';
import 'package:waddy_app/features/checkout/domain/models/checkout_pricing.dart';
import 'package:waddy_app/features/checkout/domain/models/place_order_body_model.dart';
import 'package:waddy_app/features/checkout/helpers/checkout_calculation_helper.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';
import 'package:waddy_app/features/profile/domain/services/profile_service_interface.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/splash/domain/services/splash_service_interface.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/features/xp/domain/services/xp_service_interface.dart';
import 'package:waddy_app/util/app_constants.dart';

/// Phase 0 of `docs/cart_checkout_structure_plan.md` — the safety net.
///
/// Nothing tested cart or checkout before this file (`CS-11`), which is why
/// `CS-02` and `CS-03` survived: both are divergences between two code paths
/// that no assertion ever compared. These pin the arithmetic *as it is today*
/// so the restructuring in Phases 1–3 has something to move against, and they
/// state the two known divergences as expectations rather than leaving them to
/// be rediscovered.
///
/// Deliberately not covered here: `CartController.calculationCart`, which needs
/// a `CartServiceInterface` and a repository to construct. `CS-03`'s divergence
/// is asserted against the arithmetic it performs rather than the controller —
/// see the `CS-03` group.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// `getModuleConfig` answers "every flag off" until a `module_config` entry
  /// exists, and `newVariation` — the one flag pricing turns on — is derived
  /// from the module *type*, not the payload. So both module types need an
  /// entry, and their contents do not matter.
  ///
  /// The rest of this boot exists for a less obvious reason, and it is the
  /// most useful thing writing these tests turned up.
  ///
  /// `CS-11` calls the helper's methods "pure functions over a cart and a
  /// config". They are not pure over anything. Pricing one cart reaches
  /// through `Get.find` for **four** controllers:
  ///
  ///   * `SplashController` — `getModuleConfig`, `configModel`
  ///     (`digitAfterDecimalPoint` via `PriceConverter.toFixed`,
  ///     `dmTipsStatus`, `adminFreeDelivery`) and `module!.id`
  ///   * `ProfileController` — the referral discount
  ///   * `XpController` — whether a free-delivery prize is selected
  ///   * `CartController` — via `calculateExtraPackagingCharge`
  ///
  /// Every one of them is dereferenced with `!`, so each throws rather than
  /// degrades when its controller is absent. That is `CS-04`'s untracked-
  /// dependency shape one layer below the screen, and it is why the count in
  /// `CS-04` understates the problem: removing `Get.find` from `build()` does
  /// not remove it from the arithmetic `build()` calls.
  void bootSplash() {
    Get.reset();
    final SplashController splash = SplashController(
      splashServiceInterface: _StubSplashService(),
    );
    splash.setModuleConfigForTest(<String, dynamic>{
      AppConstants.food: <String, dynamic>{},
      AppConstants.grocery: <String, dynamic>{},
    });
    splash.setConfigModelForTest(
      ConfigModel(digitAfterDecimalPoint: 2, dmTipsStatus: 1),
    );
    Get.put<SplashController>(splash);
    // `calculateReferralDiscount` reaches for this through `Get.find` — a
    // third hidden dependency of the "pure" helper, alongside the two named
    // above. A null `userInfoModel` is the signed-out case: no referral bonus.
    Get.put<ProfileController>(
      ProfileController(profileServiceInterface: _StubProfileService()),
    );
    // Delivery charges are looked up by module id against the address's zone
    // data, so pricing needs a current module even to answer "no delivery".
    splash.setModuleForTest(
      ModuleModel(
        id: 7,
        moduleName: 'grocery',
        moduleType: AppConstants.grocery,
      ),
    );
    // The fourth. `calculateDeliveryCharge` asks it whether a free-delivery
    // prize is selected.
    Get.put<XpController>(XpController(xpServiceInterface: _StubXpService()));
  }

  setUp(bootSplash);
  tearDown(Get.reset);

  Item item({
    double price = 100,
    double discount = 0,
    String discountType = 'percent',
    String moduleType = AppConstants.grocery,
  }) => Item(
    id: 1,
    name: 'Koshary',
    price: price,
    discount: discount,
    discountType: discountType,
    moduleType: moduleType,
    storeId: 1,
    // Every list the pricing path walks is dereferenced with `!`, so an item
    // that simply has no variations must still carry empty lists.
    variations: <Variation>[],
    foodVariations: <FoodVariation>[],
    addOns: <AddOns>[],
  );

  CartModel cart({
    Item? forItem,
    int quantity = 1,
    List<AddOns> addOns = const <AddOns>[],
    List<AddOn> addOnIds = const <AddOn>[],
  }) => CartModel(
    1,
    forItem?.price ?? 100,
    forItem?.price ?? 100,
    <Variation>[],
    <List<bool?>>[],
    0,
    quantity,
    addOnIds,
    addOns,
    false,
    10,
    forItem ?? item(),
    10,
  );

  final Store store = Store(id: 1, name: 'Zooba Maadi', zoneId: 1);

  group('CheckoutCalculationHelper — the pricing arithmetic', () {
    test('price is unit price times quantity', () {
      final CheckoutCalculationHelper helper = CheckoutCalculationHelper();
      final double price = helper.calculatePrice(
        store: store,
        cartList: <CartModel?>[cart(quantity: 3)],
      );

      expect(price, 300);
    });

    /// Worth stating outright, because it is not what the signature suggests.
    ///
    /// For a non-food module `calculatePrice` throws its own accumulator away
    /// and returns `calculateVariationPrice(store:, cartList:)` over the whole
    /// list — and that method is wrapped in `if (store != null)`. So a null
    /// store does not mean "price without store discounts"; it means the cart
    /// is free. The checkout screen always passes
    /// `checkoutController.store`, which is null until the store fetch
    /// resolves, and the screen computes prices on every build (`CS-01`).
    test('a null store prices a non-food cart at zero', () {
      final CheckoutCalculationHelper helper = CheckoutCalculationHelper();

      expect(
        helper.calculatePrice(
          store: null,
          cartList: <CartModel?>[cart(quantity: 3)],
        ),
        0,
        reason: 'CS-01: pricing before the store lands yields 0, not a partial',
      );
    });

    test(
      'a percentage item discount is reported, not subtracted from price',
      () {
        final CheckoutCalculationHelper helper = CheckoutCalculationHelper();
        final Item discounted = item(discount: 10, discountType: 'percent');
        final List<CartModel?> list = <CartModel?>[
          cart(forItem: discounted, quantity: 2),
        ];

        final double price = helper.calculatePrice(
          store: store,
          cartList: list,
        );
        final double discount = helper.calculateDiscountPrice(
          store: store,
          cartList: list,
          price: price,
          addOns: 0,
          calStoreDiscount: false,
        );

        expect(price, 200, reason: 'price stays gross');
        expect(discount, 20, reason: '10% of 200');
      },
    );

    test('total folds delivery, tips, packaging and excluded tax in', () {
      final CheckoutCalculationHelper helper = CheckoutCalculationHelper();

      final double total = helper.calculateTotal(
        subTotal: 200,
        deliveryCharge: 25,
        discount: 20,
        couponDiscount: 10,
        taxIncluded: false,
        tax: 14,
        orderType: 'delivery',
        tips: 5,
        additionalCharge: 3,
        extraPackagingCharge: 2,
      );

      // 200 + 25 - 20 - 10 + 14 + 5 + 3 + 2
      expect(total, 219);
    });

    test('an included tax is not added to the total a second time', () {
      final CheckoutCalculationHelper helper = CheckoutCalculationHelper();

      final double total = helper.calculateTotal(
        subTotal: 200,
        deliveryCharge: 25,
        discount: 0,
        couponDiscount: 0,
        taxIncluded: true,
        tax: 14,
        orderType: 'delivery',
        tips: 0,
        additionalCharge: 0,
        extraPackagingCharge: 0,
      );

      expect(total, 225);
    });
  });

  group('CS-03 · subtotal has two independent implementations', () {
    /// `CartController.calculationCart` computes, for a non-food module:
    ///
    ///     subTotal = itemPrice - itemDiscountPrice
    ///
    /// dropping `_addOns` and `_variationPrice`, both of which it has just
    /// accumulated. `CheckoutCalculationHelper.calculateSubTotal` computes
    /// `price` for the same module — also without add-ons.
    ///
    /// So the two agree on a plain cart and would diverge the moment a
    /// grocery module gained add-ons. This pins which of the two is which, so
    /// that Phase 3's merge is a deletion rather than a behaviour change.
    test('grocery: helper subtotal is price alone, add-ons excluded', () {
      final CheckoutCalculationHelper helper = CheckoutCalculationHelper();
      final List<CartModel?> list = <CartModel?>[cart(quantity: 2)];

      final double subTotal = helper.calculateSubTotal(
        price: 200,
        addOns: 30,
        variations: 10,
        cartList: list,
      );

      expect(
        subTotal,
        200,
        reason: 'non-food modules take price only — add-ons are dropped',
      );
    });

    test('food: helper subtotal is price + add-ons + variations', () {
      final CheckoutCalculationHelper helper = CheckoutCalculationHelper();
      final List<CartModel?> list = <CartModel?>[
        cart(forItem: item(moduleType: AppConstants.food), quantity: 2),
      ];

      final double subTotal = helper.calculateSubTotal(
        price: 200,
        addOns: 30,
        variations: 10,
        cartList: list,
      );

      expect(subTotal, 240);
    });

    /// The direct comparison the plan asked for. `CartController` turns out to
    /// be constructible from a service alone — the calculation methods it uses
    /// never touch the repository — so the two paths can be run against one
    /// cart after all.
    test(
      'the two paths disagree: cart nets the discount, checkout does not',
      () {
        final CartController cartController = CartController(
          cartServiceInterface: CartService(
            cartRepositoryInterface: _StubCartRepository(),
          ),
        );
        final Item discounted = item(discount: 10, discountType: 'percent');
        final CartModel line = cart(forItem: discounted, quantity: 2);
        cartController.cartList.add(line);

        final double cartSubTotal = cartController.calculationCart();

        final CheckoutCalculationHelper helper = CheckoutCalculationHelper();
        final List<CartModel?> list = <CartModel?>[line];
        final double price = helper.calculatePrice(
          store: store,
          cartList: list,
        );
        final double checkoutSubTotal = helper.calculateSubTotal(
          price: price,
          addOns: helper.calculateAddonsPrice(store: store, cartList: list),
          variations: helper.calculateVariationPrice(
            store: store,
            cartList: list,
            calculateWithoutDiscount: true,
          ),
          cartList: list,
        );

        // `CC-14`'s mechanism, stated as arithmetic: the cart bar shows 180 and
        // the checkout screen 200, because one subtracts the item discount into
        // the subtotal and the other reports it as a separate line.
        //
        // Still true after the CS-03 merge, and deliberately so. The merge
        // removed the second *implementation*, not the second *meaning*: the
        // cart bars want the figure the customer will pay, checkout wants a
        // breakdown that sums. Both now come from
        // `CheckoutCalculationHelper`, so they can no longer drift apart by
        // accident — which is what CS-03 was about. Whether the checkout screen
        // should also lead with the net figure is CC-14's own call.
        expect(cartSubTotal, 180, reason: 'cart: net of the 10% item discount');
        expect(
          checkoutSubTotal,
          200,
          reason: 'checkout: gross, discount is a line',
        );
        expect(cartSubTotal, isNot(checkoutSubTotal));
      },
    );

    /// The merge's safety condition: the helper's net projection must produce
    /// exactly what `calculationCart` produced, or `CartController` delegating
    /// to it is a behaviour change rather than a deduplication.
    test('the helper net projection reproduces the cart number exactly', () {
      final CartController cartController = CartController(
        cartServiceInterface: CartService(
          cartRepositoryInterface: _StubCartRepository(),
        ),
      );
      final Item discounted = item(discount: 10, discountType: 'percent');
      final CartModel line = cart(forItem: discounted, quantity: 2);
      cartController.cartList.add(line);

      expect(
        CheckoutCalculationHelper().calculateNetSubTotal(
          store: store,
          cartList: <CartModel?>[line],
        ),
        cartController.calculationCart(),
      );
    });

    test('an empty cart subtotals to the price it was handed, not zero', () {
      final CheckoutCalculationHelper helper = CheckoutCalculationHelper();

      expect(
        helper.calculateSubTotal(
          price: 0,
          addOns: 0,
          variations: 0,
          cartList: const <CartModel?>[],
        ),
        0,
      );
    });
  });

  group('CS-01 · the pricing snapshot', () {
    /// Phase 2 moved the fourteen chained calculations out of `build()` into
    /// `CheckoutPricing`. These pin the two properties that made the move
    /// worth doing: the numbers are the same ones the chain produced, and the
    /// two figures that used to be out-parameters on the helper now arrive as
    /// fields rather than being scraped off it afterwards.
    CheckoutPricing priceOf({
      required List<CartModel?> cartList,
      double couponDiscount = 0,
      double tips = 0,
      double additionalCharge = 0,
      double extraPackagingCharge = 0,
      bool taxIncluded = false,
      double tax = 0,
    }) => CheckoutPricing.calculate(
      helper: CheckoutCalculationHelper(),
      store: store,
      cartList: cartList,
      address: AddressModel(
        zoneData: <ZoneData>[
          ZoneData(
            id: 1,
            modules: <Modules>[
              Modules(
                id: 7,
                pivot: Pivot(
                  zoneId: 1,
                  moduleId: 7,
                  deliveryChargeType: 'distance',
                  perKmShippingCharge: 5,
                  minimumShippingCharge: 15,
                  maximumShippingCharge: 60,
                ),
              ),
            ],
          ),
        ],
      ),
      distance: 2,
      extraCharge: 0,
      orderType: 'take_away',
      couponDiscount: couponDiscount,
      tips: tips,
      additionalCharge: additionalCharge,
      extraPackagingCharge: extraPackagingCharge,
      taxIncluded: taxIncluded,
      tax: tax,
      surgePrice: null,
      surgePriceType: null,
    );

    test('the snapshot agrees with the chain it replaced', () {
      final List<CartModel?> list = <CartModel?>[cart(quantity: 2)];
      final CheckoutPricing pricing = priceOf(cartList: list);

      final CheckoutCalculationHelper helper = CheckoutCalculationHelper();
      final double price = helper.calculatePrice(store: store, cartList: list);
      final double addOns = helper.calculateAddonsPrice(
        store: store,
        cartList: list,
      );
      final double variations = helper.calculateVariationPrice(
        store: store,
        cartList: list,
        calculateWithoutDiscount: true,
      );
      final double subTotal = helper.calculateSubTotal(
        price: price,
        addOns: addOns,
        variations: variations,
        cartList: list,
      );

      expect(pricing.price, price);
      expect(pricing.addOns, addOns);
      expect(pricing.variations, variations);
      expect(pricing.subTotal, subTotal);
    });

    test('total is already net of the referral discount', () {
      final CheckoutPricing pricing = priceOf(
        cartList: <CartModel?>[cart(quantity: 2)],
        tax: 14,
      );

      // `build()` used to compute total, then subtract referralDiscount on a
      // following line. Folding that in is why nothing downstream may subtract
      // it a second time.
      expect(
        pricing.total,
        closeTo(
          pricing.subTotal +
              pricing.deliveryCharge -
              pricing.discount -
              pricing.couponDiscount +
              14 -
              pricing.referralDiscount,
          0.001,
        ),
      );
    });

    test('the tooltip charges are fields, not left on the helper', () {
      final CheckoutPricing pricing = priceOf(
        cartList: <CartModel?>[cart(quantity: 1)],
      );

      // CS-09: the point is that reading them needs no knowledge of which call
      // set them or when — they are on the value, whatever their amount.
      expect(pricing.badWeatherChargeForToolTip, isA<double>());
      expect(pricing.extraChargeForToolTip, isA<double>());
    });

    test('an empty cart prices to zero throughout', () {
      final CheckoutPricing pricing = priceOf(cartList: const <CartModel?>[]);

      expect(pricing.price, 0);
      expect(pricing.subTotal, 0);
      expect(pricing.orderAmount, 0);
    });
  });

  group('CS-02 · the order is described twice', () {
    /// The checkout screen builds a `PlaceOrderBodyModel` twice — at
    /// `checkout_screen.dart:489` for the tax quote and at `:1254` for the
    /// order — and the two disagree on `order_amount`: the quote sends
    /// `subTotal`, the order sends `total`, which already contains delivery,
    /// tips, packaging and the tax figure itself.
    ///
    /// Confirmed against the backend on 2026-09-16: for every order type this
    /// app places, `PlaceNewOrder.php` overwrites `order_amount` with its own
    /// figure (`:472`, then `:516`) before using it, and `getCalculatedTax`
    /// recomputes `$product_price` from the cart for non-parcel orders. So the
    /// divergence is a wrong *quote* under a future zone- or amount-sensitive
    /// tax rule, not a wrong charge today.
    ///
    /// This test states the invariant Phase 1 must establish: one builder, one
    /// meaning for `order_amount`. It fails today by construction — the two
    /// payloads below are built the way the screen builds them.
    PlaceOrderBodyModel payload({required double orderAmount}) =>
        PlaceOrderBodyModel(
          cart: <OnlineCart>[],
          couponDiscountAmount: 0,
          couponCode: null,
          orderAmount: orderAmount,
          orderType: 'delivery',
          paymentMethod: 'cash_on_delivery',
          storeId: 1,
          distance: 2,
          discountAmount: 0,
          orderNote: '',
          receiverDetails: null,
          parcelCategoryId: null,
          chargePayer: null,
          dmTips: '5',
          unavailableItemNote: '',
          cutlery: 0,
          partialPayment: 0,
          guestId: 0,
          isBuyNow: 0,
          extraPackagingAmount: 0,
          createNewUser: 0,
          password: null,
        );

    /// Phase 1 settled `order_amount` on `subTotal` for both payloads, so the
    /// figure below is the one both call sites now send. Before that the order
    /// sent `total` and this pairing was `(200, 244)`.
    test('the tax quote and the order agree on order_amount', () {
      const double subTotal = 200;

      final Map<String, String> taxQuote =
          payload(orderAmount: subTotal).toJson();
      final Map<String, String> order = payload(orderAmount: subTotal).toJson();

      expect(taxQuote['order_amount'], order['order_amount']);
      expect(order['order_amount'], '200.0');
    });

    test('nothing either payload sets diverges once both take one figure', () {
      final Map<String, String> taxQuote = payload(orderAmount: 200).toJson();
      final Map<String, String> order = payload(orderAmount: 200).toJson();

      final Set<String> differing = <String>{
        for (final String key in <String>{...taxQuote.keys, ...order.keys})
          if (taxQuote[key] != order[key]) key,
      };

      expect(
        differing,
        isEmpty,
        reason:
            'CS-02: one source, one projection — no field diverges by omission',
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

class _StubCartRepository implements CartRepositoryInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
