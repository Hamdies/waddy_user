import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/models/config_model.dart';
import 'package:waddy_app/common/models/module_model.dart';
import 'package:waddy_app/features/cart/domain/models/cart_model.dart';
import 'package:waddy_app/features/cart/domain/repositories/cart_repository_interface.dart';
import 'package:waddy_app/features/cart/domain/services/cart_service.dart';
import 'package:waddy_app/features/checkout/domain/models/place_order_body_model.dart';
import 'package:waddy_app/features/checkout/helpers/order_payload_builder.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/splash/domain/services/splash_service_interface.dart';
import 'package:waddy_app/util/app_constants.dart';

/// The last two Tier-1 gaps from `docs/architecture_hardening_plan.md` §3:
/// the cart's mixing guards and the order payload's shape.
///
/// **Why these two.**
///
/// The guards (`existAnotherStoreItem`, `existAnotherModuleItem`,
/// `isExistInCart`) decide whether adding an item silently replaces the cart.
/// Get one wrong and a customer either loses a cart they were building or ends
/// up with an order spanning two stores that no single rider can fulfil.
/// Nothing tested them.
///
/// `OrderPayloadBuilder` is the client/server contract for what an order *is*.
/// `CS-07` records that its loop existed verbatim twice, and `CS-02` is the
/// bug that slipped through because of it. It was deduplicated but never
/// pinned.
///
/// Characterization, as in `checkout_pricing_gaps_test.dart`: these assert what
/// the code does today so Phase 3 can prove it changed nothing by accident.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CartService service;

  void bootSplash() {
    Get.reset();
    final SplashController splash = SplashController(
      splashServiceInterface: _StubSplashService(),
    );
    // `newVariation` is derived from the module *type*, so both need an entry
    // even though the payload contents do not matter.
    splash.setModuleConfigForTest(<String, dynamic>{
      AppConstants.food: <String, dynamic>{},
      AppConstants.grocery: <String, dynamic>{},
    });
    splash.setConfigModelForTest(ConfigModel(digitAfterDecimalPoint: 2));
    splash.setModuleForTest(
      ModuleModel(
        id: 7,
        moduleName: 'grocery',
        moduleType: AppConstants.grocery,
      ),
    );
    Get.put<SplashController>(splash);
  }

  setUp(() {
    bootSplash();
    service = CartService(cartRepositoryInterface: _StubCartRepository());
  });
  tearDown(Get.reset);

  Item item({
    int id = 1,
    int storeId = 1,
    int moduleId = 7,
    String moduleType = AppConstants.grocery,
    List<FoodVariation>? foodVariations,
  }) => Item(
    id: id,
    name: 'Koshary',
    price: 100,
    discount: 0,
    discountType: 'percent',
    moduleType: moduleType,
    storeId: storeId,
    moduleId: moduleId,
    variations: <Variation>[],
    foodVariations: foodVariations ?? <FoodVariation>[],
    addOns: <AddOns>[],
  );

  CartModel cart({
    Item? forItem,
    int quantity = 1,
    List<Variation>? variation,
    List<List<bool?>>? foodVariations,
    List<AddOn> addOnIds = const <AddOn>[],
    List<AddOns> addOns = const <AddOns>[],
    bool isCampaign = false,
    int? id,
  }) => CartModel(
    id ?? 1,
    100,
    100,
    variation ?? <Variation>[],
    foodVariations ?? <List<bool?>>[],
    0,
    quantity,
    addOnIds,
    addOns,
    isCampaign,
    10,
    forItem ?? item(),
    10,
  );

  group('existAnotherStoreItem — the "clear your cart?" guard', () {
    test('an empty cart never blocks', () {
      expect(service.existAnotherStoreItem(1, 7, <CartModel>[]), isFalse);
    });

    test('the same store in the same module is fine', () {
      final List<CartModel> list = <CartModel>[
        cart(forItem: item(storeId: 1, moduleId: 7)),
      ];
      expect(service.existAnotherStoreItem(1, 7, list), isFalse);
    });

    test('a different store in the same module blocks', () {
      // This is the case that pops the "clear cart" dialog.
      final List<CartModel> list = <CartModel>[
        cart(forItem: item(storeId: 2, moduleId: 7)),
      ];
      expect(service.existAnotherStoreItem(1, 7, list), isTrue);
    });

    test('a different store in a DIFFERENT module does not block', () {
      // Both conditions must hold: different store AND same module. A grocery
      // cart does not block adding from a food store here — that is
      // existAnotherModuleItem's job, and the two are checked separately.
      final List<CartModel> list = <CartModel>[
        cart(forItem: item(storeId: 2, moduleId: 99)),
      ];
      expect(service.existAnotherStoreItem(1, 7, list), isFalse);
    });

    test('one foreign line among many is enough to block', () {
      final List<CartModel> list = <CartModel>[
        cart(forItem: item(id: 1, storeId: 1, moduleId: 7)),
        cart(forItem: item(id: 2, storeId: 1, moduleId: 7)),
        cart(forItem: item(id: 3, storeId: 2, moduleId: 7)),
      ];
      expect(service.existAnotherStoreItem(1, 7, list), isTrue);
    });
  });

  group('existAnotherModuleItem', () {
    test('an empty cart never blocks', () {
      expect(service.existAnotherModuleItem(7, <CartModel>[]), isFalse);
    });

    test('the same module is fine', () {
      final List<CartModel> list = <CartModel>[
        cart(forItem: item(moduleId: 7)),
      ];
      expect(service.existAnotherModuleItem(7, list), isFalse);
    });

    test('any other module blocks, regardless of store', () {
      final List<CartModel> list = <CartModel>[
        cart(forItem: item(storeId: 1, moduleId: 99)),
      ];
      expect(service.existAnotherModuleItem(7, list), isTrue);
    });

    test('a null module id blocks against a real one', () {
      // Pinned because it is a plain `!=`: null is "another module", so a cart
      // line with no module id makes every add look like a module switch.
      final List<CartModel> list = <CartModel>[
        cart(forItem: item(moduleId: 7)),
      ];
      expect(service.existAnotherModuleItem(null, list), isTrue);
    });
  });

  group('isExistInCart — index of a matching line, or -1', () {
    test('an empty cart is a miss', () {
      expect(service.isExistInCart(<CartModel>[], 1, '', false, null), -1);
    });

    test('a matching item without variations returns its index', () {
      final List<CartModel> list = <CartModel>[
        cart(forItem: item(id: 5)),
        cart(forItem: item(id: 9)),
      ];
      expect(service.isExistInCart(list, 9, '', false, null), 1);
    });

    test('a different item is a miss', () {
      final List<CartModel> list = <CartModel>[cart(forItem: item(id: 5))];
      expect(service.isExistInCart(list, 99, '', false, null), -1);
    });

    test('variation type must match when the line has one', () {
      final List<CartModel> list = <CartModel>[
        cart(
          forItem: item(id: 5),
          variation: <Variation>[Variation(type: 'Large')],
        ),
      ];
      expect(service.isExistInCart(list, 5, 'Large', false, null), 0);
      expect(service.isExistInCart(list, 5, 'Small', false, null), -1);
    });

    test('a line with no variations matches any variation type', () {
      // The `isNotEmpty ? ... : true` arm means an unvaried line is a match
      // for whatever type is asked for.
      final List<CartModel> list = <CartModel>[cart(forItem: item(id: 5))];
      expect(service.isExistInCart(list, 5, 'anything', false, null), 0);
    });

    test('updating a line does not count as a duplicate of itself', () {
      // isUpdate + the index being edited => -1, so editing quantity on an
      // existing line is not reported as "already in cart".
      final List<CartModel> list = <CartModel>[
        cart(forItem: item(id: 5)),
        cart(forItem: item(id: 5)),
      ];
      expect(service.isExistInCart(list, 5, '', true, 0), -1);
    });

    test('updating one line still finds a different matching line', () {
      final List<CartModel> list = <CartModel>[
        cart(forItem: item(id: 5)),
        cart(forItem: item(id: 5)),
      ];
      // Editing index 1: index 0 is a genuine duplicate and is reported.
      expect(service.isExistInCart(list, 5, '', true, 1), 0);
    });
  });

  group('cartQuantity — totals across duplicate lines', () {
    test('an absent item is zero', () {
      expect(service.cartQuantity(1, <CartModel>[]), 0);
    });

    test('quantities sum across separate lines for the same item', () {
      final List<CartModel> list = <CartModel>[
        cart(forItem: item(id: 5), quantity: 2),
        cart(forItem: item(id: 5), quantity: 3),
        cart(forItem: item(id: 9), quantity: 7),
      ];
      expect(service.cartQuantity(5, list), 5);
      expect(service.cartQuantity(9, list), 7);
    });
  });

  group('OrderPayloadBuilder — the order contract', () {
    test('a null cart builds an empty line list, not a throw', () {
      expect(
        OrderPayloadBuilder.buildCartLines(cartList: null, isCampaign: false),
        isEmpty,
      );
    });

    test('null entries in the list are skipped', () {
      final List<CartModel?> list = <CartModel?>[null, cart(), null];
      expect(
        OrderPayloadBuilder.buildCartLines(
          cartList: list,
          isCampaign: false,
        ).length,
        1,
      );
    });

    test('one cart line becomes one order line with its quantity', () {
      final List<OnlineCart> lines = OrderPayloadBuilder.buildCartLines(
        cartList: <CartModel?>[cart(quantity: 4)],
        isCampaign: false,
      );
      expect(lines.length, 1);
      expect(lines.first.quantity, 4);
      expect(lines.first.itemId, 1);
    });

    test('add-on ids and quantities travel as parallel lists', () {
      // The server pairs them by position, so their order and length must
      // match exactly — a silent contract this pins.
      final List<OnlineCart> lines = OrderPayloadBuilder.buildCartLines(
        cartList: <CartModel?>[
          cart(
            addOnIds: <AddOn>[AddOn(id: 11, quantity: 2), AddOn(id: 12, quantity: 5)],
            addOns: <AddOns>[AddOns(id: 11), AddOns(id: 12)],
          ),
        ],
        isCampaign: false,
      );
      expect(lines.first.addOnIds, <int?>[11, 12]);
      expect(lines.first.addOnQtys, <int?>[2, 5]);
    });

    test('a campaign order tags its item type', () {
      final List<OnlineCart> campaign = OrderPayloadBuilder.buildCartLines(
        cartList: <CartModel?>[cart()],
        isCampaign: true,
      );
      expect(campaign.first.itemType, 'AppModelsItemCampaign');

      final List<OnlineCart> normal = OrderPayloadBuilder.buildCartLines(
        cartList: <CartModel?>[cart()],
        isCampaign: false,
      );
      expect(normal.first.itemType, isNull);
    });

    test('a grocery line carries the legacy variation shape', () {
      // grocery => newVariation false => the old `variation` list is sent.
      // Both shapes serialise to the same `variation` key, so the JSON is
      // where the difference is observable — and the JSON is the contract.
      final List<OnlineCart> lines = OrderPayloadBuilder.buildCartLines(
        cartList: <CartModel?>[
          cart(
            forItem: item(moduleType: AppConstants.grocery),
            variation: <Variation>[Variation(type: 'Large')],
          ),
        ],
        isCampaign: false,
      );
      expect(lines.first.variation, isNotNull);
      final Map<String, dynamic> json = lines.first.toJson();
      expect(json['variation'], isA<List<dynamic>>());
      expect((json['variation'] as List<dynamic>).first, containsPair('type', 'Large'));
    });

    test('a food line sends selected food variations structurally', () {
      final Item foodItem = item(
        moduleType: AppConstants.food,
        foodVariations: <FoodVariation>[
          FoodVariation(
            name: 'Size',
            variationValues: <VariationValue>[
              VariationValue(level: 'Large', optionPrice: 20),
              VariationValue(level: 'Small', optionPrice: 10),
            ],
          ),
        ],
      );
      final List<OnlineCart> lines = OrderPayloadBuilder.buildCartLines(
        cartList: <CartModel?>[
          cart(
            forItem: foodItem,
            foodVariations: <List<bool?>>[
              <bool?>[true, false],
            ],
          ),
        ],
        isCampaign: false,
      );

      expect(lines.first.variation, isNull);
      final Map<String, dynamic> json = lines.first.toJson();
      final List<dynamic> sent = json['variation'] as List<dynamic>;
      expect(sent.length, 1);
      expect(sent.first, containsPair('name', 'Size'));
      // Only the selected level travels.
      expect(
        (sent.first as Map<String, dynamic>)['values'],
        containsPair('label', <String?>['Large']),
      );
    });

    test('a food group with nothing selected is omitted entirely', () {
      final Item foodItem = item(
        moduleType: AppConstants.food,
        foodVariations: <FoodVariation>[
          FoodVariation(
            name: 'Size',
            variationValues: <VariationValue>[
              VariationValue(level: 'Large', optionPrice: 20),
            ],
          ),
        ],
      );
      final List<OnlineCart> lines = OrderPayloadBuilder.buildCartLines(
        cartList: <CartModel?>[
          cart(
            forItem: foodItem,
            foodVariations: <List<bool?>>[
              <bool?>[false],
            ],
          ),
        ],
        isCampaign: false,
      );
      expect(lines.first.toJson()['variation'], isEmpty);
    });

    test('every cart line produces exactly one order line', () {
      // The count is the contract: a dropped line is a missing item on a real
      // order, and nothing downstream would notice.
      final List<CartModel?> list = <CartModel?>[
        cart(id: 1, forItem: item(id: 1)),
        cart(id: 2, forItem: item(id: 2)),
        cart(id: 3, forItem: item(id: 3)),
      ];
      final List<OnlineCart> lines = OrderPayloadBuilder.buildCartLines(
        cartList: list,
        isCampaign: false,
      );
      expect(lines.length, 3);
      expect(
        lines.map((OnlineCart c) => c.itemId).toList(),
        <int?>[1, 2, 3],
      );
    });
  });
}

class _StubSplashService implements SplashServiceInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _StubCartRepository implements CartRepositoryInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
