import 'package:get/get.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/common/models/module_model.dart';
import 'package:waddy_app/features/cart/domain/models/cart_model.dart';
import 'package:waddy_app/features/cart/domain/models/online_cart_model.dart';
import 'package:waddy_app/features/cart/domain/services/cart_service_interface.dart';
import 'package:waddy_app/features/checkout/controllers/checkout_controller.dart';
import 'package:waddy_app/features/checkout/helpers/checkout_calculation_helper.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/features/checkout/domain/models/place_order_body_model.dart';
import 'package:waddy_app/features/item/controllers/item_controller.dart';
import 'package:waddy_app/features/location/controllers/location_controller.dart';
import 'package:waddy_app/features/store/controllers/store_controller.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/helper/analytics_helper.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/helper/guest_gate_helper.dart';
import 'package:waddy_app/helper/date_converter.dart';
import 'package:waddy_app/helper/module_helper.dart';
import 'package:waddy_app/helper/price_converter.dart';

class CartController extends GetxController implements GetxService {
  final CartServiceInterface cartServiceInterface;

  CartController({required this.cartServiceInterface});

  /// CS-03: the single subtotal implementation lives here now.
  final CheckoutCalculationHelper _calcHelper = CheckoutCalculationHelper();

  List<CartModel> _cartList = [];
  List<CartModel> get cartList => _cartList;

  double _subTotal = 0;
  double get subTotal => _subTotal;

  double _itemPrice = 0;
  double get itemPrice => _itemPrice;

  double _itemDiscountPrice = 0;
  double get itemDiscountPrice => _itemDiscountPrice;

  double _addOns = 0;
  double get addOns => _addOns;

  double _variationPrice = 0;
  double get variationPrice => _variationPrice;

  List<List<AddOns>> _addOnsList = [];
  List<List<AddOns>> get addOnsList => _addOnsList;

  List<bool> _availableList = [];
  List<bool> get availableList => _availableList;

  List<String> get notAvailableList => [
    'remove_it_from_my_cart'.tr,
    'wait_until_restocked'.tr,
    'please_cancel_the_order'.tr,
    'call_me_asap'.tr,
    'notify_me_when_back'.tr,
  ];
  bool _addCutlery = false;
  bool get addCutlery => _addCutlery;

  int _notAvailableIndex = -1;
  int get notAvailableIndex => _notAvailableIndex;

  int _currentIndex = 0;
  int get currentIndex => _currentIndex;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isCartLoading = false;
  bool get isCartLoading => _isCartLoading;

  bool _needExtraPackage = true;
  bool get needExtraPackage => _needExtraPackage;

  bool _isExpanded = true;
  bool get isExpanded => _isExpanded;

  int? _directAddCartItemIndex = -1;
  int? get directAddCartItemIndex => _directAddCartItemIndex;

  void setDirectlyAddToCartIndex(int? index) {
    _directAddCartItemIndex = index;
  }

  void toggleExtraPackage({bool willUpdate = true}) {
    _needExtraPackage = !_needExtraPackage;
    if (willUpdate) {
      update();
    }
  }

  void setAvailableIndex(int index, {bool willUpdate = true}) {
    _notAvailableIndex = cartServiceInterface.availableSelectedIndex(
      _notAvailableIndex,
      index,
    );
    if (willUpdate) {
      update();
    }
  }

  void updateCutlery({bool willUpdate = true}) {
    _addCutlery = !_addCutlery;
    if (willUpdate) {
      update();
    }
  }

  Future<void> forcefullySetModule(int moduleId) async {
    ModuleModel? module = cartServiceInterface.forcefullySetModule(
      Get.find<SplashController>().module,
      Get.find<SplashController>().moduleList,
      moduleId,
    );
    if (module != null) {
      // enterModule, not the raw setter: the cart can belong to a module the
      // user is not currently in, and entering it has to drop the catalogue of
      // the one they were. It reloads home itself, so the explicit
      // loadData(true) that used to follow is gone — it was a second full load
      // racing the first.
      await Get.find<SplashController>().enterModule(module);
    }
  }

  double calculationCart() {
    _addOnsList = [];
    _availableList = [];
    _itemPrice = 0;
    _itemDiscountPrice = 0;
    _addOns = 0;
    _variationPrice = 0;
    bool isFoodVariation = false;
    double variationWithoutDiscountPrice = 0;
    bool haveVariation = false;
    for (var cartModel in cartList) {
      isFoodVariation =
          ModuleHelper.getModuleConfig(
            cartModel.item!.moduleType,
          ).newVariation!;
      double? discount = cartModel.item!.discount;
      String? discountType = cartModel.item!.discountType;

      List<AddOns> addOnList = cartServiceInterface.prepareAddonList(cartModel);

      _addOnsList.add(addOnList);
      _availableList.add(
        DateConverter.isAvailable(
          cartModel.item!.availableTimeStarts,
          cartModel.item!.availableTimeEnds,
        ),
      );

      _addOns = cartServiceInterface.calculateAddonPrice(
        _addOns,
        addOnList,
        cartModel,
      );

      _variationPrice = cartServiceInterface.calculateVariationPrice(
        isFoodVariation,
        cartModel,
        discount,
        discountType,
        _variationPrice,
      );

      variationWithoutDiscountPrice = cartServiceInterface
          .calculateVariationWithoutDiscountPrice(
            isFoodVariation,
            cartModel,
            variationWithoutDiscountPrice,
          );
      haveVariation = cartServiceInterface.checkVariation(
        isFoodVariation,
        cartModel,
      );

      double price =
          haveVariation
              ? variationWithoutDiscountPrice
              : (cartModel.item!.price! * cartModel.quantity!);
      double discountPrice =
          haveVariation
              ? (variationWithoutDiscountPrice - _variationPrice)
              : (price -
                  (PriceConverter.convertWithDiscount(
                        cartModel.item!.price!,
                        discount,
                        discountType,
                      )! *
                      cartModel.quantity!));

      _itemPrice = _itemPrice + price;
      _itemDiscountPrice = _itemDiscountPrice + discountPrice;

      haveVariation = false;
    }
    if (isFoodVariation) {
      _itemDiscountPrice =
          _itemDiscountPrice +
          (variationWithoutDiscountPrice - _variationPrice);
      _variationPrice = variationWithoutDiscountPrice;
    }

    // CS-03: the subtotal itself is no longer computed here.
    //
    // This method used to reach its own figure — `(_itemPrice -
    // _itemDiscountPrice)`, plus add-ons and variations for food — by walking
    // the cart a second time, independently of
    // `CheckoutCalculationHelper`. The two produced different numbers for the
    // same cart (180 vs 200 on a 10% item discount), which is `CC-14`.
    //
    // The loop above stays: it populates `_addOnsList`, `_availableList`,
    // `_itemPrice` and `_variationPrice`, which the cart screen and the
    // summary rows read. Only the arithmetic is delegated, to the helper's
    // explicit net projection — deliberately the cart's meaning, so the
    // number the bars show does not change.
    //
    // The store is resolved defensively: the helper's price path is wrapped in
    // `if (store != null)` and answers 0 without one, and the cart bars render
    // in places where neither CheckoutController nor a fetched store is
    // guaranteed to exist. Falling back to the previous local arithmetic there
    // keeps the bars correct rather than showing a free cart.
    final Store? store =
        Get.isRegistered<CheckoutController>()
            ? Get.find<CheckoutController>().store
            : Get.isRegistered<StoreController>()
            ? Get.find<StoreController>().store
            : null;

    _subTotal =
        store != null
            ? _calcHelper.calculateNetSubTotal(store: store, cartList: cartList)
            : (_itemPrice - _itemDiscountPrice) +
                (isFoodVariation ? _addOns + _variationPrice : 0);

    return _subTotal;
  }

  Future<void> addToCart(CartModel cartModel, int? index) async {
    if (index != null && index != -1) {
      _cartList.replaceRange(index, index + 1, [cartModel]);
    } else {
      _cartList.add(cartModel);
    }
    Get.find<ItemController>().setExistInCart(
      cartModel.item,
      null,
      notify: true,
    );
    await cartServiceInterface.addSharedPrefCartList(_cartList);

    AnalyticsHelper.logAddToCart(
      itemId: cartModel.item?.id,
      itemName: cartModel.item?.name,
      price: cartModel.discountedPrice ?? cartModel.price ?? 0,
      quantity: cartModel.quantity ?? 1,
    );

    calculationCart();
    update();
  }

  int? getCartId(int cartIndex) {
    return cartServiceInterface.getCartId(cartIndex, _cartList);
  }

  /// Guards against the two ways a quantity tap can race the network:
  /// a row that has no server id yet (the `cart/add` response has not landed),
  /// and a `cartIndex` that went stale because [getCartDataOnline] rebuilt
  /// `_cartList` while an earlier tap was still in flight. Both used to throw a
  /// null check on `_cartList[cartIndex].id!`.
  Future<void> setQuantity(
    bool isIncrement,
    int cartIndex,
    int? stock,
    int? quantityLimit,
  ) async {
    if (cartIndex < 0 || cartIndex >= _cartList.length) return;

    // Hold the row itself, not its position: the list identity survives the
    // awaits below even when the list is replaced under us.
    final CartModel cart = _cartList[cartIndex];
    if (cart.id == null || cart.quantity == null || cart.item == null) return;

    final int previousQuantity = cart.quantity!;

    cart.quantity = await cartServiceInterface.decideItemQuantity(
      isIncrement,
      _cartList,
      cartIndex,
      stock,
      quantityLimit,
      Get.find<SplashController>().configModel.moduleConfig!.module!.stock!,
    );

    // `decideItemQuantity` refuses the change at a stock or limit ceiling by
    // handing back the same number it was given. Nothing to send, and painting
    // a loading state for a no-op is what made a blocked tap feel broken.
    if (cart.quantity == previousQuantity) {
      update();
      return;
    }

    // Only when no write for this line is out: mid-burst, the number being
    // replaced is one the server has not accepted, so it is no rollback target.
    if (!_quantityWritesInFlight.contains(cart.id)) {
      _acceptedQuantity[cart.id!] = previousQuantity;
    }
    _lineEditedAt[cart.id!] = ++_quantityEdits;

    // Paint the new number now. The server call below is the slow part, and
    // making the digit wait on two round-trips is what made the stepper feel
    // laggy — the animation was never the bottleneck.
    calculationCart();
    update();

    if (ModuleHelper.getModuleConfig(cart.item!.moduleType).newVariation!) {
      await Get.find<ItemController>().setExistInCart(
        cart.item,
        null,
        notify: true,
      );
    }

    await _syncQuantity(cart.id!);
  }

  /// Cart-line ids with a quantity write on the wire.
  final Set<int> _quantityWritesInFlight = {};

  /// The quantity the server last accepted for each line in [_quantityWritesInFlight].
  final Map<int, int> _acceptedQuantity = {};

  /// Counts local quantity edits; [_lineEditedAt] stamps each line with the
  /// count at its latest one, so a server cart response can tell which lines
  /// changed after its request left.
  int _quantityEdits = 0;
  final Map<int, int> _lineEditedAt = {};

  CartModel? _lineById(int cartId) =>
      _cartList.firstWhereOrNull((line) => line.id == cartId);

  /// Pushes a line's quantity to the server, one write per line at a time.
  ///
  /// Taps that land while a write is out only move the local number; when the
  /// write returns it sends whatever the line reads by then. Firing a write
  /// per tap let their responses, and the cart re-sync each one triggered,
  /// land out of order — a re-sync that left before the latest tap reached
  /// the server handed back the older number and the digit slid backwards
  /// under a thumb that was still tapping.
  ///
  /// Deliberately does not raise [_isLoading]: dimming and disabling the
  /// stepper for the length of a round-trip is what stopped rapid taps from
  /// registering.
  Future<void> _syncQuantity(int cartId) async {
    if (!_quantityWritesInFlight.add(cartId)) return;

    bool settled = false;
    try {
      while (true) {
        final CartModel? line = _lineById(cartId);
        if (line == null || line.item == null || line.quantity == null) break;
        final int sent = line.quantity!;

        final double price = await cartServiceInterface
            .calculateDiscountedPrice(
              line,
              sent,
              ModuleHelper.getModuleConfig(line.item!.moduleType).newVariation!,
            );
        final bool success = await cartServiceInterface
            .updateCartQuantityOnline(cartId, price, sent);

        // Looked up again: a re-sync from elsewhere may have replaced the list.
        final CartModel? current = _lineById(cartId);
        if (!success) {
          // Put back the last number the server accepted rather than leaving
          // the UI asserting a quantity it never did.
          final int? accepted = _acceptedQuantity[cartId];
          if (current != null && accepted != null) {
            current.quantity = accepted;
            calculationCart();
            update();
          }
          break;
        }
        _acceptedQuantity[cartId] = sent;
        // Removed meanwhile: the removal re-syncs once its delete lands, and a
        // fetch from here could beat that delete and bring the row back.
        if (current == null) break;
        if (current.quantity == sent) {
          settled = true;
          break;
        }
      }
    } finally {
      // In `finally` so a thrown request cannot leave the line marked busy,
      // which would swallow every later write for it.
      _quantityWritesInFlight.remove(cartId);
      _acceptedQuantity.remove(cartId);
    }

    // Re-sync once the line has settled, not after every write: totals and any
    // server-side adjustment land without the digit waiting on them.
    if (settled) await getCartDataOnline();
  }

  /// Swaps in the server's cart. Lines whose quantity the user changed after
  /// [requestedAt] (a [_quantityEdits] reading taken when the request left),
  /// or whose write is still out, keep their local number — the response
  /// predates it, and taking it would slide the digit backwards.
  void _applyServerCart(
    List<OnlineCartModel> onlineCartList, {
    required int requestedAt,
  }) {
    final Map<int, int> local = {
      for (final CartModel line in _cartList)
        if (line.id != null &&
            line.quantity != null &&
            (_quantityWritesInFlight.contains(line.id) ||
                (_lineEditedAt[line.id] ?? 0) > requestedAt))
          line.id!: line.quantity!,
    };
    _cartList = [
      ...cartServiceInterface.formatOnlineCartToLocalCart(
        onlineCartModel: onlineCartList,
      ),
    ];
    for (final CartModel line in _cartList) {
      final int? quantity = local[line.id];
      if (quantity != null) line.quantity = quantity;
    }
    calculationCart();
  }

  Future<void> removeFromCart(int index, {Item? item}) async {
    int cartId = _cartList[index].id!;
    _cartList.removeAt(index);
    update();
    Get.find<ItemController>().cartIndexSet();
    await removeCartItemOnline(cartId, item: item);
    if (Get.find<ItemController>().item != null) {
      Get.find<ItemController>().cartIndexSet();
    }
  }

  /// Removes the item from local state ONLY — call [confirmCartRemoval] after
  /// the undo window expires, or [restoreCartItem] if the user undoes.
  ({CartModel removed, int? cartId}) removeFromCartOptimistic(int index) {
    final CartModel removed = _cartList[index];
    // Guest carts are local-only and their entries may carry no server id.
    final int? cartId = removed.id;
    _cartList.removeAt(index);
    calculationCart();
    update();
    Get.find<ItemController>().cartIndexSet();
    return (removed: removed, cartId: cartId);
  }

  /// Re-inserts a previously removed item at its original position.
  void restoreCartItem(CartModel cart, int originalIndex) {
    final int insertAt = originalIndex.clamp(0, _cartList.length);
    _cartList.insert(insertAt, cart);
    cartServiceInterface.addSharedPrefCartList(_cartList);
    calculationCart();
    update();
    Get.find<ItemController>().cartIndexSet();
  }

  /// Fires the server-side delete — call this after the undo window expires.
  /// Guest carts live server-side too (keyed by guest_id), so a guest delete
  /// must hit the API as well; skipping it let the next cart/list fetch pull
  /// the "deleted" item straight back. Only entries with no server id at all
  /// are purely local.
  Future<void> confirmCartRemoval(int? cartId, {Item? item}) async {
    if (cartId == null ||
        !(AuthHelper.isLoggedIn() || AuthHelper.isGuestLoggedIn())) {
      await cartServiceInterface.addSharedPrefCartList(_cartList);
      return;
    }
    await removeCartItemOnline(cartId, item: item);
  }

  Future<void> clearCartList({bool canRemoveOnline = true}) async {
    _cartList = [];
    // Guests have a server-side cart too (keyed by guest_id) — clearing only
    // the local list would let the next cart/list fetch restore everything.
    if ((AuthHelper.isLoggedIn() || AuthHelper.isGuestLoggedIn()) &&
        (ModuleHelper.getModule() != null ||
            ModuleHelper.getCacheModule() != null) &&
        canRemoveOnline) {
      clearCartOnline();
    }
  }

  int isExistInCart(
    int? itemID,
    String variationType,
    bool isUpdate,
    int? cartIndex,
  ) {
    return cartServiceInterface.isExistInCart(
      _cartList,
      itemID,
      variationType,
      isUpdate,
      cartIndex,
    );
  }

  bool existAnotherStoreItem(int? storeID, int? moduleId) {
    return cartServiceInterface.existAnotherStoreItem(
      storeID,
      moduleId,
      _cartList,
    );
  }

  bool existAnotherModuleItem(int? moduleId) {
    return cartServiceInterface.existAnotherModuleItem(moduleId, _cartList);
  }

  void setCurrentIndex(int index, bool notify) {
    _currentIndex = index;
    if (notify) {
      update();
    }
  }

  /// Adds to the server cart for BOTH guests and logged-in users. Guests are
  /// identified by `guest_id` (sent by CartRepository) — the backend supports
  /// guest carts natively (is_guest scoping), so there's no separate local
  /// path. The `localFallback` param is retained (unused) for call-site
  /// compatibility. See docs/guest_mode_DETAILS.md (backend guest cart).
  Future<bool> addToCartOnline(
    OnlineCart cart, {
    CartModel? localFallback,
  }) async {
    // Out-of-zone users can browse the whole catalogue (see StoreLogic::get_stores)
    // but must not build a cart they can never check out. Gating here — the one
    // chokepoint every add-to-cart entry point funnels through — keeps the ~15 UI
    // call sites unchanged; they all already handle a false return.
    if (Get.find<LocationController>().outOfServingZone) {
      AnalyticsHelper.log('add_to_cart_blocked_out_of_zone', {
        'auth_state': AuthHelper.isLoggedIn() ? 'user' : 'guest',
      });
      // Pass the store they were trying to order from: this is the single
      // highest-intent demand signal in the app — not just "someone in Nasr
      // City wants Waddy" but "wants THIS restaurant" — which is what turns
      // the expansion data into a merchant sign-up shortlist.
      await GuestGate.showNoDeliverySheet(
        source: 'add_to_cart',
        storeId: Get.find<StoreController>().store?.id,
      );
      return false;
    }

    _isLoading = true;
    bool success = false;

    // OPTIMISTIC ADD — the row appears in the cart bar on this frame, before
    // the request goes out. Without it the bar sat unchanged for the whole
    // round-trip, which is what made adding feel unresponsive now that the
    // toast (which used to paper over the wait) is gone.
    //
    // The server response still replaces the list wholesale below, so it
    // remains the source of truth for ids, merged quantities and pricing; this
    // only covers the gap. On failure the snapshot is restored, so a rejected
    // add cannot leave a phantom row.
    final List<CartModel> snapshot = List<CartModel>.from(_cartList);
    if (localFallback != null) {
      _cartList.add(localFallback);
      calculationCart();
    }
    update();

    final int requestedAt = _quantityEdits;
    List<OnlineCartModel>? onlineCartList = await cartServiceInterface
        .addToCartOnline(cart);
    if (onlineCartList != null) {
      _applyServerCart(onlineCartList, requestedAt: requestedAt);
      success = true;
    } else if (localFallback != null) {
      // Roll back the optimistic row.
      _cartList = snapshot;
      calculationCart();
    }
    _isLoading = false;
    update();

    return success;
  }

  Future<bool> updateCartOnline(
    OnlineCart cart, {
    CartModel? localFallback,
    int? localIndex,
  }) async {
    _isLoading = true;
    bool success = false;
    update();
    final int requestedAt = _quantityEdits;
    List<OnlineCartModel>? onlineCartList = await cartServiceInterface
        .updateCartOnline(cart);
    if (onlineCartList != null) {
      _applyServerCart(onlineCartList, requestedAt: requestedAt);
      success = true;
    }
    _isLoading = false;
    update();

    return success;
  }

  /// After login, refresh the cart from the server. The guest cart already
  /// lives server-side (keyed by guest_id), and the backend's login flow
  /// (`check_guest_cart`) automatically re-parents every guest cart row to the
  /// new user — so there is nothing to push from the client. Re-pushing a local
  /// backup here would double items or race that migration. We just pull the
  /// now-migrated server cart. See docs/guest_mode_DETAILS.md.
  Future<void> mergeGuestCartToServer() async {
    if (!AuthHelper.isLoggedIn()) return;
    try {
      await getCartDataOnline();
    } catch (e, stackTrace) {
      AnalyticsHelper.logError('cart_sync_failed', e, stackTrace);
    }
  }

  // Splash and dashboard both fetch the cart during boot — coalesce those
  // near-simultaneous calls into one cart/list request. The join window is
  // deliberately short so a refresh fired after an add/remove mutation never
  // reuses a response that predates the mutation.
  Future<void>? _cartFetchInFlight;
  DateTime? _cartFetchStartedAt;

  Future<void> getCartDataOnline({bool initialLoad = false}) {
    if (_cartFetchInFlight != null &&
        _cartFetchStartedAt != null &&
        DateTime.now().difference(_cartFetchStartedAt!) <
            const Duration(milliseconds: 300)) {
      return _cartFetchInFlight!;
    }
    _cartFetchStartedAt = DateTime.now();
    late final Future<void> fetch;
    fetch = _fetchCartDataOnline(initialLoad: initialLoad).whenComplete(() {
      if (identical(_cartFetchInFlight, fetch)) _cartFetchInFlight = null;
    });
    _cartFetchInFlight = fetch;
    return fetch;
  }

  Future<void> _fetchCartDataOnline({bool initialLoad = false}) async {
    // Guest carts live server-side too (keyed by guest_id, which the repo
    // appends to every cart request) — a guest boot must pull the cart like a
    // logged-in one, or the cart stays empty until the next add mutation.
    if (AuthHelper.isLoggedIn() || AuthHelper.isGuestLoggedIn()) {
      if (initialLoad) {
        _isCartLoading = true;
        update();
      } else {
        _isLoading = true;
      }
      final int requestedAt = _quantityEdits;
      List<OnlineCartModel>? onlineCartList =
          await cartServiceInterface.getCartDataOnline();
      if (onlineCartList != null) {
        _applyServerCart(onlineCartList, requestedAt: requestedAt);
      }
      _isCartLoading = false;
      _isLoading = false;
      update();
    }
  }

  Future<bool> removeCartItemOnline(int cartId, {Item? item}) async {
    _isLoading = true;
    update();
    bool success = await cartServiceInterface.removeCartItemOnline(cartId);
    if (success) {
      await getCartDataOnline();
      if (item != null) {
        Get.find<ItemController>().setExistInCart(item, null, notify: true);
      }
    }
    _isLoading = false;
    update();
    return success;
  }

  Future<bool> clearCartOnline() async {
    _isLoading = true;
    update();
    bool success = await cartServiceInterface.clearCartOnline();
    if (success) {
      getCartDataOnline();
    }
    _isLoading = false;
    update();
    return success;
  }

  int cartQuantity(int itemId) {
    return cartServiceInterface.cartQuantity(itemId, _cartList);
  }

  String cartVariant(int itemId) {
    return cartServiceInterface.cartVariant(itemId, _cartList);
  }

  void setExpanded(bool setExpand) {
    _isExpanded = setExpand;
    update();
  }
}
