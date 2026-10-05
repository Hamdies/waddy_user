import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:lottie/lottie.dart';
import 'package:waddy_app/features/scratch_card/widgets/scratch_card_badge.dart';
import 'package:waddy_app/features/address/controllers/address_controller.dart';
import 'package:waddy_app/features/address/domain/models/address_model.dart';
import 'package:waddy_app/features/cart/controllers/cart_controller.dart';
import 'package:waddy_app/features/cart/widgets/extra_packaging_widget.dart';
import 'package:waddy_app/features/category/controllers/category_controller.dart';
import 'package:waddy_app/features/category/domain/models/category_model.dart';
import 'package:waddy_app/features/checkout/widgets/coupon_section.dart';
import 'package:waddy_app/features/checkout/controllers/checkout_controller.dart';
import 'package:waddy_app/features/coupon/controllers/coupon_controller.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/store/controllers/store_list_controller.dart';
import 'package:waddy_app/features/cart/domain/models/cart_model.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/helper/guest_gate_helper.dart';
import 'package:waddy_app/helper/analytics_helper.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/features/location/controllers/location_controller.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_button.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/common/widgets/item_bottom_sheet.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/no_data_screen.dart';
import 'package:waddy_app/features/cart/widgets/cart_item_widget.dart';
import 'package:waddy_app/features/cart/widgets/basket_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/item/domain/produce_preference.dart';
import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/features/xp/controllers/xp_controller.dart';
import 'package:waddy_app/features/checkout/domain/models/place_order_body_model.dart';

class CartScreen extends StatefulWidget {
  final bool fromNav;
  const CartScreen({super.key, required this.fromNav});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _resolvingAddress = false;

  /// A signed-in user with no saved address fills in the address details
  /// screen before checkout, so the rider gets building/floor/apartment
  /// instead of a bare map pin. Returns false when they back out of it — the
  /// cart stays put. Guests are left to checkout's own guest-address flow.
  Future<bool> _ensureSavedAddress(CartController cartController) async {
    if (!AuthHelper.isLoggedIn()) return true;
    if (_resolvingAddress) return false;
    _resolvingAddress = true;
    try {
      final AddressController addressController = Get.find<AddressController>();
      if (addressController.addressList == null) {
        await addressController.getAddressList();
      }
      // Still null means the fetch failed — don't hold checkout hostage to it.
      final List<AddressModel>? saved = addressController.addressList;
      if (saved == null || saved.isNotEmpty) return true;

      final dynamic result = await Get.toNamed(
        RouteHelper.getAddAddressRoute(
          true,
          false,
          cartController.cartList.first.item?.zoneId,
        ),
      );
      if (result is! AddressModel) return false;
      // Checkout resets its selection on open; have it land on the new
      // address (index 0 is the current location, 1 the newest saved). If the
      // new address sits on the current pin, checkout merges the two and
      // clamps this back to 0 — which is the same new address.
      Get.find<CheckoutController>().preselectAddressIndex(1);
      return true;
    } finally {
      _resolvingAddress = false;
    }
  }

  final ScrollController scrollController = ScrollController();

  /// Selected "Complete your meal" tab; null is "All".
  int? _mealCategoryId;

  /// The note for the restaurant, read straight off the checkout controller so
  /// the cart and the checkout screen edit one string, not two copies of it.
  /// [CheckoutController.noteController] is what `order_note` is built from at
  /// place-order time, so anything typed here does ship with the order.
  String get _restaurantNote =>
      Get.find<CheckoutController>().noteController.text;

  /// True until the first cart fetch settles on a cold open. An empty list
  /// before then means "not loaded yet", not "empty" — showing the empty-cart
  /// screen in that gap told a user with a full basket it was gone.
  late bool _fetching = Get.find<CartController>().cartList.isEmpty;

  /// Items already in the basket when the screen opened. The rail leaves
  /// them out — it should suggest what is missing, not what the basket above
  /// already shows. Items added FROM the rail during this visit are not in
  /// here, so tapping "+" never makes a card vanish from under the thumb.
  /// An item that leaves the basket drops out of this set, so it can come
  /// back as a suggestion.
  final Set<int> _inCartAtOpen = {};

  @override
  void initState() {
    super.initState();

    initCall();
  }

  Future<void> initCall() async {
    if (Get.find<CartController>().cartList.isEmpty) {
      try {
        await Get.find<CartController>().getCartDataOnline();
      } finally {
        if (mounted) setState(() => _fetching = false);
      }
    }
    if (Get.find<CartController>().cartList.isNotEmpty) {
      if (kDebugMode) {
        print(
          '----cart item : ${Get.find<CartController>().cartList[0].toJson()}',
        );
      }

      if (Get.find<CartController>().addCutlery) {
        Get.find<CartController>().updateCutlery(willUpdate: false);
      }
      if (Get.find<CartController>().needExtraPackage) {
        Get.find<CartController>().toggleExtraPackage(willUpdate: false);
      }
      Get.find<CartController>().setAvailableIndex(-1, willUpdate: false);
      _inCartAtOpen.addAll(_itemIdsIn(Get.find<CartController>()));
      final int? storeId = Get.find<CartController>().cartList[0].item!.storeId;
      // A coupon applied to another store's basket (or another checkout) has
      // no business showing as applied here.
      Get.find<CouponController>().keepOnlyFor(storeId);
      Get.find<StoreListController>().getCartStoreSuggestedItemList(storeId);
      // The meal tabs name their categories from this list. It is per module,
      // so only fetch when a module is active — from the dashboard there is
      // none, and the tabs simply stay hidden.
      if (Get.find<SplashController>().module != null &&
          Get.find<CategoryController>().categoryList == null) {
        Get.find<CategoryController>().getCategoryList(false);
      }
      // The cart's own store (ST-02). This was `StoreController
      // .getStoreDetails(fromCart: true)`, which wrote the cart's store into
      // the field a store page under the cart renders its header from.
      Get.find<CartController>().loadCartStore();
      Get.find<CartController>().calculationCart();
      showReferAndEarnSnackBar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WaddyColors.surface,
      appBar: AppBar(
        backgroundColor: WaddyColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: kBasketHeaderHeight,
        titleSpacing: kBasketHeaderStartInset,
        title: GetBuilder<CartController>(
          builder: (cartController) => _buildHeader(cartController),
        ),
        // The printed card this order brings, as a sticker at the header's
        // end: pinned, and over nothing (docs/scratch_card_plan.md §3a).
        actions: [
          if (ScratchCardBadge.inBags)
            const Padding(
              padding: EdgeInsetsDirectional.only(
                end: Dimensions.paddingSizeDefault,
              ),
              child: ScratchCardSticker(width: 46, height: 52, flips: true),
            ),
        ],
      ),
      body: GetBuilder<CartController>(
        builder: (cartController) {
          _syncCouponToBasket(cartController);
          if (cartController.cartList.isEmpty && _fetching) {
            return const Center(
              child: CircularProgressIndicator(color: WaddyColors.mintInk),
            );
          }
          return cartController.cartList.isNotEmpty
              ? Column(
                children: [
                  // Pinned above the scroll area so it stays in view.
                  _buildSavingsBanner(cartController),

                  Expanded(
                    child: BasketScrollFade(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        child: _buildMobileLayout(cartController),
                      ),
                    ),
                  ),

                  _buildBottomCheckoutButton(cartController),
                ],
              )
              : const NoDataScreen(isCart: true, text: '', showFooter: true);
        },
      ),
    );
  }

  void _goBack() {
    if (widget.fromNav) {
      Get.offAllNamed(RouteHelper.getInitialRoute());
    } else {
      Get.back();
    }
  }

  /// The cart's store name — the fetched store when it is this basket's,
  /// otherwise the name the cart line carries.
  String? _storeName(CartController cart) {
    if (cart.cartList.isEmpty) return null;
    final Item? item = cart.cartList.first.item;
    final Store? store = cart.cartStore;
    if (store != null && store.id == item?.storeId && store.name != null) {
      return store.name;
    }
    return item?.storeName;
  }

  /// The shared basket header — identical on checkout.
  Widget _buildHeader(CartController cartController) {
    return BasketHeader(
      title: 'cart'.tr,
      storeName: _storeName(cartController),
      itemCount: cartController.cartList.fold<int>(
        0,
        (sum, cart) => sum + (cart.quantity ?? 0),
      ),
      onBack: _goBack,
    );
  }

  /// "EGP 15.00 saved! With B.Laban offers" — the store's item discounts on
  /// this basket, pinned under the header.
  ///
  /// The design gives this slot to savings. A basket with no discounted items
  /// falls back to the XP earn band, so the slot is never an empty promise.
  Widget _buildSavingsBanner(CartController cartController) {
    final double saved = cartController.itemDiscountPrice;
    if (saved <= 0) return _buildXpEarnBanner(cartController);
    return BasketSavingsBanner(amount: saved);
  }

  /// Keeps an applied coupon's discount in step with the basket.
  ///
  /// The coupon can be applied here and carried into checkout, so a quantity
  /// change after applying it has to re-work the discount — or drop the
  /// coupon if the basket fell under its minimum. Deferred past the frame
  /// because it may notify the CouponController mid-build. A no-op when the
  /// total has not moved.
  void _syncCouponToBasket(CartController cartController) {
    final CouponController coupons = Get.find<CouponController>();
    if (coupons.coupon == null || cartController.cartList.isEmpty) return;
    final double order = cartController.subTotal;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) coupons.refreshForOrder(order);
    });
  }

  /// "You'll earn N XP on this order" — the mint band under the app bar.
  ///
  /// The XP figure is the real estimate for the current subtotal, not a fixed
  /// number, so it moves as the basket changes. Hidden entirely when leveling
  /// is off, the user is a guest, or the estimate is zero — an empty reward
  /// band is worse than no band.
  Widget _buildXpEarnBanner(CartController cartController) {
    if (!AuthHelper.isLoggedIn()) return const SizedBox.shrink();

    int xp = 0;
    String? rewardTitle;
    int? rewardXpLeft;
    try {
      final xpController = Get.find<XpController>();
      if (xpController.xpConfig == null ||
          !xpController.xpConfig!.levelingEnabled) {
        return const SizedBox.shrink();
      }
      // Per line, as the server awards it; the whole-subtotal estimate read
      // a few XP high (X-23).
      xp = xpController.estimateForCart(
        cartController.cartList,
        Get.find<SplashController>().module?.moduleType,
      );
      // The payoff line — the next unclaimed prize BY NAME ("Free delivery"),
      // with the XP still to go. A bare number never told anyone what XP buys.
      // Both are needed for the line to mean anything, so it renders only when
      // the level call has landed AND there is a prize still outstanding.
      final reward = xpController.nextReward;
      final int remaining = xpController.xpToNextReward;
      if (reward != null && reward.title.isNotEmpty && remaining > 0) {
        rewardTitle = reward.title;
        rewardXpLeft = remaining;
      }
    } catch (_) {
      return const SizedBox.shrink();
    }
    if (xp <= 0) return const SizedBox.shrink();

    return Material(
      color: WaddyColors.mintSurface,
      child: InkWell(
        // "31 XP" means nothing on its own — the band is the most prominent
        // thing under the app bar, so it has to lead somewhere that explains
        // what XP buys.
        onTap: () => Get.toNamed(RouteHelper.getXpLevelsRoute()),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeDefault,
            vertical: Dimensions.paddingSizeMedium,
          ),
          child: Row(
            children: [
              Lottie.asset(
                'assets/animation/waddi_coins.json',
                width: Dimensions.paddingSizeExtraLarge,
                height: Dimensions.paddingSizeExtraLarge,
              ),
              const SizedBox(width: Dimensions.paddingSizeSmall),
              // Two stacked lines, left-aligned: the earn on top, the named
              // prize under it. Centring these forced a wrap as soon as the
              // reward had a name, which is exactly when the band matters most.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'youll_earn_xp'.tr.replaceAll('@xp', '$xp'),
                            style: waddyBold.copyWith(
                              fontSize: Dimensions.fontSizeSmall,
                              color: WaddyColors.mintInk,
                            ),
                          ),
                          const TextSpan(text: ' '),
                          TextSpan(
                            text: 'on_this_order'.tr,
                            style: waddyRegular.copyWith(
                              fontSize: Dimensions.fontSizeSmall,
                              color: WaddyColors.inkLightOnMint,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (rewardTitle != null) ...[
                      const SizedBox(
                        height: Dimensions.paddingSizeExtraSmall / 2,
                      ),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: rewardTitle,
                              style: waddyBold.copyWith(
                                fontSize: Dimensions.fontSizeExtraSmall,
                                color: WaddyColors.mintInk,
                              ),
                            ),
                            TextSpan(
                              text:
                                  ' ${'xp_left'.tr.replaceAll('@xp', '$rewardXpLeft')}',
                              style: waddyRegular.copyWith(
                                fontSize: Dimensions.fontSizeExtraSmall,
                                color: WaddyColors.inkLightOnMint,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Dimensions.paddingSizeExtraSmall),
              const Icon(
                Icons.chevron_right_rounded,
                size: Dimensions.paddingSizeLarge,
                color: WaddyColors.mintInk,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(CartController cartController) {
    final CheckoutController checkoutController =
        Get.find<CheckoutController>();
    final int? cartStoreId = cartController.cartList.first.item?.storeId;
    // Rounded together, so the printed lines add up to the Checkout button.
    final List<double> linePrices = PriceConverter.allocateRounded([
      for (final CartModel line in cartController.cartList)
        CartItemWidget.lineTotal(line),
    ]);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimensions.paddingSizeDefault,
        Dimensions.paddingSizeMedium,
        Dimensions.paddingSizeDefault,
        Dimensions.paddingSizeExtraLarge,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The basket — one bordered card: the lines, then "Add more items"
          // and the note for the restaurant under a rule each.
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeDefault,
              vertical: Dimensions.paddingSizeExtraSmall,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: WaddyColors.divider),
              borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
            ),
            child: Column(
              children: [
                for (
                  int index = 0;
                  index < cartController.cartList.length;
                  index++
                )
                  CartItemWidget(
                    displayPrice: linePrices[index],
                    cart: cartController.cartList[index],
                    cartIndex: index,
                    addOns: cartController.addOnsList[index],
                    isAvailable: cartController.availableList[index],
                    showDivider: index != cartController.cartList.length - 1,
                  ),
                _buildCardAction(
                  icon: Icons.add_rounded,
                  label: 'add_more_items'.tr,
                  onTap: _goBack,
                ),
                _buildRestaurantNoteRow(),
              ],
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeDefault),

          _buildCompleteYourMeal(cartController),

          ExtraPackagingWidget(cartController: cartController),

          // The same promo card checkout shows. A code applied here stays
          // applied on checkout (CouponController.keepOnlyFor), and its
          // discount follows the basket (_syncCouponToBasket).
          // No gap of its own: the section above already ends in the 16 that
          // separates every card on this screen. Stacking another 24 here left
          // a 40 hole whenever the rail was empty.
          if (AuthHelper.isLoggedIn() && cartStoreId != null) ...[
            CouponSection(
              checkoutController: checkoutController,
              cartStoreId: cartStoreId,
              itemSavings: cartController.itemDiscountPrice,
              total: cartController.subTotal,
              price: cartController.subTotal,
              discount: 0,
              addOns: 0,
              variationPrice: 0,
              deliveryCharge: _deliveryChargeGate(cartController, cartStoreId),
            ),
          ],
        ],
      ),
    );
  }

  /// What the cart hands the coupon check as the delivery charge.
  ///
  /// The real fee needs an address and a distance, which only checkout has.
  /// The coupon check only uses it as a gate — a free-delivery code is refused
  /// when there is no fee to waive — so the cart answers that question: zero
  /// for a free-delivery store, a positive stand-in otherwise. The discount
  /// itself is never computed from this number.
  double _deliveryChargeGate(CartController cart, int storeId) {
    final Store? store = cart.cartStore;
    if (store != null && store.id == storeId && store.freeDelivery == true) {
      return 0;
    }
    return 1;
  }

  /// A full-width mint action row inside the basket card, under a rule.
  Widget _buildCardAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: Dimensions.minTapTarget),
        padding: const EdgeInsets.symmetric(
          vertical: Dimensions.paddingSizeMedium,
        ),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: WaddyColors.divider)),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: Dimensions.paddingSizeDefault,
              color: WaddyColors.mintInk,
            ),
            const SizedBox(width: Dimensions.paddingSizeSmall),
            Expanded(
              child: Text(
                label,
                style: waddyBold.copyWith(
                  fontSize: Dimensions.fontSizeSmall,
                  color: WaddyColors.mintInk,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "Add a note for the restaurant" row, the last row of the basket card.
  ///
  /// The sheet writes to [CheckoutController.noteController], which is the same
  /// controller the checkout screen's note field binds to and the source of
  /// `order_note` on the place-order body — so a note typed here survives the
  /// hop to checkout and reaches the restaurant.
  Widget _buildRestaurantNoteRow() {
    final bool hasNote = _restaurantNote.trim().isNotEmpty;

    return InkWell(
      onTap: _openRestaurantNoteSheet,
      child: Container(
        constraints: const BoxConstraints(minHeight: Dimensions.minTapTarget),
        padding: const EdgeInsets.symmetric(
          vertical: Dimensions.paddingSizeMedium,
        ),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: WaddyColors.divider)),
        ),
        child: Row(
          children: [
            // Mint-ink like "Add more items" above it: both rows are actions.
            const Icon(
              Icons.sticky_note_2_outlined,
              size: Dimensions.paddingSizeDefault,
              color: WaddyColors.mintInk,
            ),
            const SizedBox(width: Dimensions.paddingSizeSmall),
            Expanded(
              child: Text(
                hasNote ? _restaurantNote : 'add_a_note_for_the_restaurant'.tr,
                style: waddyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: Dimensions.fontSizeSmall,
                  color: hasNote ? WaddyColors.ink : WaddyColors.inkLight,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: Dimensions.paddingSizeLarge,
              color: WaddyColors.inkLight,
            ),
          ],
        ),
      ),
    );
  }

  void _openRestaurantNoteSheet() {
    // The checkout controller's own field — edited in place, so Save needs no
    // copy step and the checkout screen shows the same text when it opens.
    final controller = Get.find<CheckoutController>().noteController;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (con) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(con).viewInsets.bottom,
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: WaddyColors.surface,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(Dimensions.radiusExtraLarge),
                ),
              ),
              padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'add_a_note_for_the_restaurant'.tr,
                    style: waddyBold.copyWith(
                      fontSize: Dimensions.fontSizeLarge,
                      color: WaddyColors.ink,
                    ),
                  ),
                  const SizedBox(height: Dimensions.paddingSizeDefault),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    maxLines: 3,
                    maxLength: 200,
                    style: waddyRegular.copyWith(
                      fontSize: Dimensions.fontSizeDefault,
                      color: WaddyColors.ink,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: WaddyColors.surfaceWarm,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          Dimensions.radiusDefault,
                        ),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: Dimensions.paddingSizeSmall),
                  SizedBox(
                    width: double.infinity,
                    child: CustomButton(
                      buttonText: 'save'.tr,
                      radius: Dimensions.radiusDefault,
                      onPressed: () {
                        // The text is already on the shared controller; setState is
                        // only here to repaint the row with it.
                        setState(() {});
                        Get.back();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildBottomCheckoutButton(CartController cartController) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        Dimensions.paddingSizeDefault,
        Dimensions.paddingSizeMedium,
        Dimensions.paddingSizeDefault,
        math.max(
          Dimensions.paddingSizeMedium,
          MediaQuery.paddingOf(context).bottom,
        ),
      ),
      decoration: const BoxDecoration(
        color: WaddyColors.surface,
        border: Border(top: BorderSide(color: WaddyColors.divider)),
        boxShadow: [
          BoxShadow(
            color: WaddyColors.shadowTeal,
            blurRadius: Dimensions.paddingSizeMedium,
            offset: Offset(0, -Dimensions.paddingSizeExtraSmall),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        // Rebuilds on the coupon too: the figure on the button is the basket
        // net of any code applied above it.
        child: GetBuilder<CouponController>(
          builder: (coupons) {
            final double couponOff =
                coupons.hasAppliedCoupon ? (coupons.discount ?? 0) : 0;
            final double total = (cartController.subTotal - couponOff).clamp(
              0,
              double.infinity,
            );

            // "Checkout ▸ … EGP x + delivery & service fees". The button opens
            // checkout, it does not place anything, and the fees line under
            // the figure says it is not the final charge — the total jumping
            // on the next screen reads as bait-and-switch otherwise.
            return Semantics(
              button: true,
              label: '${'checkout'.tr} — ${PriceConverter.convertPrice(total)}',
              child: Material(
                color: WaddyColors.mint,
                shape: const StadiumBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _proceedToCheckout(cartController),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        Dimensions.paddingSizeLarge,
                        Dimensions.paddingSizeSmall,
                        Dimensions.paddingSizeLarge,
                        Dimensions.paddingSizeSmall,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    'checkout'.tr,
                                    style: waddyBold.copyWith(
                                      fontSize: Dimensions.fontSizeLarge,
                                      color: WaddyColors.primary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(
                                  width: Dimensions.paddingSizeSmall,
                                ),
                                const _PlayArrow(),
                              ],
                            ),
                          ),
                          const SizedBox(width: Dimensions.paddingSizeMedium),
                          Flexible(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  PriceConverter.convertPrice(total),
                                  style: waddyBlack.copyWith(
                                    fontSize: Dimensions.fontSizeLarge,
                                    color: WaddyColors.primary,
                                  ),
                                  textDirection: TextDirection.ltr,
                                ),
                                Text(
                                  'plus_delivery_and_service_fees'.tr,
                                  style: waddyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: Dimensions.fontSizeExtraSmall,
                                    color: WaddyColors.primary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _proceedToCheckout(CartController cartController) async {
    // Zone gate before the user is sent any deeper, matching the guard on
    // the other checkout entry point.
    if (Get.find<LocationController>().outOfServingZone) {
      AnalyticsHelper.log('cart_proceed_blocked_out_of_zone', {
        'auth_state': AuthHelper.isLoggedIn() ? 'user' : 'guest',
      });
      GuestGate.showNoDeliverySheet(source: 'cart_proceed');
      return;
    }
    Get.find<CheckoutController>().updateFirstTime();
    if (!cartController.cartList.first.item!.scheduleOrder! &&
        cartController.availableList.contains(false)) {
      showCustomSnackBar('one_or_more_product_unavailable'.tr);
      return;
    }
    if (Get.find<SplashController>().module == null) {
      // Checking out from the dashboard: adopt the cart's own module. The
      // hand-rolled scan this replaces ran off the end of the list when the
      // cart's module was not in it and then activated `moduleList[length]`
      // — a range error on the checkout button.
      await Get.find<SplashController>().activateModuleFor(
        cartController.cartList[0].item!.moduleId,
      );
    }
    if (!await _ensureSavedAddress(cartController)) return;
    // The coupon is NOT cleared here any more: one applied on this cart
    // carries into checkout. Settle its discount on the final basket first,
    // in case the last quantity change has not been synced yet.
    Get.find<CouponController>().refreshForOrder(cartController.subTotal);
    Get.toNamed(RouteHelper.getCheckoutRoute('cart'));
  }

  /// Categories for the "Complete your meal" tabs: the module's categories
  /// that at least one suggestion belongs to, in the module's own order.
  ///
  /// The suggest endpoint returns only category ids, so the names come from
  /// [CategoryController]. Fewer than two means there is nothing to switch
  /// between, and the tabs are hidden.
  List<CategoryModel> _mealCategories(List<Item> items) {
    final List<CategoryModel>? all =
        Get.isRegistered<CategoryController>()
            ? Get.find<CategoryController>().categoryList
            : null;
    if (all == null) return const [];
    final Set<int> used = {
      for (final Item item in items) ..._categoryIdsOf(item),
    };
    final List<CategoryModel> tabs =
        all.where((c) => c.id != null && used.contains(c.id)).toList();
    return tabs.length < 2 ? const [] : tabs;
  }

  Iterable<int> _categoryIdsOf(Item item) sync* {
    if (item.categoryId != null) yield item.categoryId!;
    for (final CategoryIds c in item.categoryIds ?? const []) {
      if (c.id != null) yield c.id!;
    }
  }

  /// "Complete your meal" — the store's suggestions, tabbed by category.
  ///
  /// Leaves out what the basket held on arrival ([_inCartAtOpen]). Every card
  /// carries a "+" at the bottom of its image; on an item added from here it
  /// bumps that line, whose quantity is otherwise edited on the basket line
  /// above.
  Widget _buildCompleteYourMeal(CartController cartController) {
    return GetBuilder<StoreListController>(
      id: StoreListController.cartSuggestId,
      builder: (storeController) {
        final Set<int> inCart = _itemIdsIn(cartController);
        _inCartAtOpen.retainWhere(inCart.contains);
        final List<Item> items = [
          for (final Item item
              in storeController.cartSuggestItemModel?.items ?? const <Item>[])
            if (!_inCartAtOpen.contains(item.id)) item,
        ];
        if (items.isEmpty) return const SizedBox.shrink();

        final List<CategoryModel> categories = _mealCategories(items);
        final int? selected =
            categories.any((c) => c.id == _mealCategoryId)
                ? _mealCategoryId
                : null;
        final List<Item> shown =
            selected == null
                ? items
                : items
                    .where((i) => _categoryIdsOf(i).contains(selected))
                    .toList();
        final bool isFood =
            cartController.cartList.firstOrNull?.item?.moduleType == 'food';

        return Padding(
          padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
          child: Container(
            clipBehavior: Clip.antiAlias,
            padding: const EdgeInsetsDirectional.only(
              start: Dimensions.paddingSizeDefault,
              top: Dimensions.paddingSizeLarge,
              bottom: Dimensions.paddingSizeLarge,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: WaddyColors.divider),
              borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (isFood ? 'complete_your_meal' : 'did_you_forget').tr
                      .toUpperCase(),
                  style: waddyBold.copyWith(
                    fontSize: Dimensions.fontSizeExtraSmall,
                    letterSpacing: 1.2,
                    color: WaddyColors.inkLight,
                  ),
                ),
                if (categories.isNotEmpty) ...[
                  const SizedBox(height: Dimensions.paddingSizeMedium),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: Dimensions.paddingSizeDefault,
                    ),
                    child: _buildMealTabs(categories, selected),
                  ),
                ],
                const SizedBox(height: Dimensions.paddingSizeSmall),
                // Sized by its tallest card, not a fixed 168: a fixed height
                // clipped the names as soon as text got larger. The rail is a
                // handful of suggestions, so building them eagerly is fine.
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsetsDirectional.only(
                    top: Dimensions.paddingSizeSmall,
                    end: Dimensions.paddingSizeDefault,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < shown.length; i++) ...[
                        if (i > 0)
                          const SizedBox(width: Dimensions.paddingSizeMedium),
                        _buildSuggestionCard(shown[i], cartController),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Segmented pill: "All" plus one tab per category. Equal widths when they
  /// fit four across, as drawn; a scrolling row when there are more.
  Widget _buildMealTabs(List<CategoryModel> categories, int? selected) {
    final List<(int?, String)> tabs = [
      (null, 'all'.tr),
      for (final CategoryModel c in categories) (c.id, c.name ?? ''),
    ];
    Widget tab((int?, String) t, {required bool expand}) {
      final bool on = t.$1 == selected;
      final Widget pill = GestureDetector(
        onTap: () => setState(() => _mealCategoryId = t.$1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 40),
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(
            horizontal:
                expand
                    ? Dimensions.paddingSizeExtraSmall
                    : Dimensions.paddingSizeDefault,
          ),
          decoration: BoxDecoration(
            color: on ? WaddyColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(_pill),
          ),
          child: Text(
            t.$2,
            style: waddyBold.copyWith(
              fontSize: Dimensions.fontSizeExtraSmall,
              color: on ? WaddyColors.surface : WaddyColors.ink,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
      return expand ? Expanded(child: pill) : pill;
    }

    final bool fits = tabs.length <= 4;
    return Container(
      padding: const EdgeInsets.all(Dimensions.paddingSizeExtraSmall),
      decoration: BoxDecoration(
        color: WaddyColors.surfaceRaised,
        borderRadius: BorderRadius.circular(_pill),
      ),
      child:
          fits
              ? Row(children: [for (final t in tabs) tab(t, expand: true)])
              : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [for (final t in tabs) tab(t, expand: false)],
                ),
              ),
    );
  }

  Set<int> _itemIdsIn(CartController cartController) => {
    for (final CartModel line in cartController.cartList)
      if (line.item?.id != null) line.item!.id!,
  };

  /// Radius that turns any box into a pill.
  static const double _pill = 100;

  /// The suggestion card's image square and the chip overlapping its corner.
  static const double _railImage = 92;
  static const double _railChip = 36;

  Widget _buildSuggestionCard(Item item, CartController cartController) {
    final bool hasVariations =
        (item.foodVariations?.isNotEmpty ?? false) ||
        (item.choiceOptions?.isNotEmpty ?? false) ||
        ProducePreference.asks(item.prepOption);
    // A plain item already in the basket: "+" bumps that line. An item with
    // variations always opens its sheet — which of its lines would it bump?
    final int cartIndex =
        hasVariations
            ? -1
            : cartController.cartList.indexWhere((c) => c.item?.id == item.id);

    return GestureDetector(
      onTap: () => _openItemSheet(item),
      child: SizedBox(
        width: _railImage + Dimensions.paddingSizeSmall,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _railImage + Dimensions.paddingSizeSmall,
              height: _railImage,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: _railImage,
                    height: _railImage,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: WaddyColors.surfaceWarm,
                      border: Border.all(color: WaddyColors.divider),
                      borderRadius: BorderRadius.circular(
                        Dimensions.radiusDefault,
                      ),
                    ),
                    child: CustomImage(
                      image: item.imageFullUrl ?? '',
                      height: _railImage,
                      width: _railImage,
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Inside the image's bottom-end corner: a 36 chip drawn 4
                  // in from the corner, in a 44 hit box flush with it.
                  PositionedDirectional(
                    bottom: 0,
                    end: Dimensions.paddingSizeSmall,
                    child: _buildSuggestionAdd(
                      item,
                      hasVariations,
                      cartController,
                      cartIndex,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Dimensions.paddingSizeSmall),
            SizedBox(
              width: _railImage,
              child: Text(
                item.name ?? '',
                style: waddyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: Dimensions.fontSizeExtraSmall,
                  height: 1.3,
                  color: WaddyColors.ink,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: Dimensions.paddingSizeExtraSmall),
            // Mint ink, like the basket's price chips: the price column's
            // mint rhythm carries on into the rail.
            Text(
              PriceConverter.convertPrice(
                item.price,
                discount: item.discount,
                discountType: item.discountType,
              ),
              style: waddyBold.copyWith(
                fontSize: Dimensions.fontSizeExtraSmall,
                color: WaddyColors.mintInk,
              ),
              textDirection: TextDirection.ltr,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionAdd(
    Item item,
    bool hasVariations,
    CartController cartController,
    int cartIndex,
  ) {
    return GestureDetector(
      onTap: () {
        if (hasVariations) {
          _openItemSheet(item);
        } else if (cartIndex >= 0) {
          // Already a line: add one to it. A fresh add of the same item is
          // refused by the server as a duplicate line.
          final CartModel line = cartController.cartList[cartIndex];
          cartController.forcefullySetModule(line.item!.moduleId!);
          cartController.setQuantity(
            true,
            cartIndex,
            line.stock,
            line.quantityLimit,
          );
        } else {
          _quickAdd(item);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Container(
            width: _railChip,
            height: _railChip,
            decoration: BoxDecoration(
              color: WaddyColors.surface,
              border: Border.all(color: WaddyColors.divider),
              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              boxShadow: const [
                BoxShadow(
                  color: WaddyColors.shadowTeal,
                  blurRadius: Dimensions.paddingSizeExtraSmall,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: const Icon(
              Icons.add_rounded,
              size: Dimensions.paddingSizeLarge,
              color: WaddyColors.mintInk,
            ),
          ),
        ),
      ),
    );
  }

  void _openItemSheet(Item item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (con) => ItemBottomSheet(itemId: item.id!),
    );
  }

  /// One-tap add for a suggestion with no variations to choose.
  Future<void> _quickAdd(Item item) async {
    final double price =
        PriceConverter.convertWithDiscount(
          item.price!,
          item.discount,
          item.discountType,
        ) ??
        item.price!;
    final OnlineCart onlineCart = OnlineCart(
      null,
      item.id,
      null,
      price.toString(),
      '',
      null,
      null,
      1,
      [],
      null,
      [],
      'Item',
    );
    // Guest fallback so this quick-add lands in the local cart instead of
    // 401ing.
    final CartModel localCart = CartModel(
      null,
      item.price,
      price,
      [],
      [],
      (item.price! - price),
      1,
      [],
      [],
      item.availableDateStarts != null,
      item.stock,
      item,
      item.quantityLimit,
    );
    // No toast: the new line lands in the basket right above, and the "+"
    // turns into a stepper in place.
    await Get.find<CartController>().addToCartOnline(
      onlineCart,
      localFallback: localCart,
    );
  }

  Future<void> showReferAndEarnSnackBar() async {
    String text = 'your_referral_discount_added_on_your_first_order'.tr;
    if (Get.find<ProfileController>().userInfoModel != null &&
        Get.find<ProfileController>().userInfoModel!.isValidForDiscount!) {
      showCustomSnackBar(text, isError: false);
    }
  }
}

/// The small solid "▸" after "Checkout", mirrored for RTL.
class _PlayArrow extends StatelessWidget {
  const _PlayArrow();

  @override
  Widget build(BuildContext context) {
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    return Transform.flip(
      flipX: rtl,
      child: const CustomPaint(size: Size(7, 9), painter: _TrianglePainter()),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  const _TrianglePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, size.height / 2)
        ..lineTo(0, size.height)
        ..close(),
      Paint()..color = WaddyColors.primary,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
