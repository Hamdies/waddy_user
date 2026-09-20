import 'package:flutter/foundation.dart';
import 'package:lottie/lottie.dart';
import 'package:waddy_app/features/cart/controllers/cart_controller.dart';
import 'package:waddy_app/features/cart/widgets/extra_packaging_widget.dart';
import 'package:waddy_app/features/checkout/controllers/checkout_controller.dart';
import 'package:waddy_app/features/coupon/controllers/coupon_controller.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/store/controllers/store_controller.dart';
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
import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
  final ScrollController scrollController = ScrollController();

  /// The note for the restaurant, read straight off the checkout controller so
  /// the cart and the checkout screen edit one string, not two copies of it.
  /// [CheckoutController.noteController] is what `order_note` is built from at
  /// place-order time, so anything typed here does ship with the order.
  String get _restaurantNote =>
      Get.find<CheckoutController>().noteController.text;

  @override
  void initState() {
    super.initState();

    initCall();
  }

  Future<void> initCall() async {
    if (Get.find<CartController>().cartList.isEmpty) {
      await Get.find<CartController>().getCartDataOnline();
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
      Get.find<StoreController>().getCartStoreSuggestedItemList(
        Get.find<CartController>().cartList[0].item!.storeId,
      );
      Get.find<StoreController>().getStoreDetails(
        Store(
          id: Get.find<CartController>().cartList[0].item!.storeId,
          name: null,
        ),
        false,
        fromCart: true,
      );
      Get.find<CartController>().calculationCart();
      showReferAndEarnSnackBar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Warm, not white: the basket's white sections then read as a card that
      // ends, rather than dissolving into a same-coloured empty page below it.
      backgroundColor: WaddyColors.surfaceWarm,
      appBar: AppBar(
        backgroundColor: WaddyColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            size: 22,
            color: WaddyColors.ink,
          ),
          onPressed: () {
            if (widget.fromNav) {
              Get.offAllNamed(RouteHelper.getInitialRoute());
            } else {
              Get.back();
            }
          },
        ),
        // No title: the body's "Your basket" header is the screen's one
        // heading. Both together read as the same word twice.
        centerTitle: false,
        toolbarHeight: 48,
      ),
      body: GetBuilder<StoreController>(
        builder: (storeController) {
          return GetBuilder<CartController>(
            builder: (cartController) {
              return cartController.cartList.isNotEmpty
                  ? Column(
                    children: [
                      // XP earn banner — pinned above the scroll area, as in
                      // the design, so the reward stays visible while scrolling.
                      _buildXpEarnBanner(cartController),

                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          child: _buildMobileLayout(
                            cartController,
                            storeController,
                          ),
                        ),
                      ),

                      // Bottom checkout button
                      _buildBottomCheckoutButton(cartController),
                    ],
                  )
                  : const NoDataScreen(
                    isCart: true,
                    text: '',
                    showFooter: true,
                  );
            },
          );
        },
      ),
    );
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
      xp = xpController.calculateEstimatedXp(
        cartController.subTotal,
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
                width: 24,
                height: 24,
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
                              fontSize: 15,
                              color: WaddyColors.mintInk,
                            ),
                          ),
                          const TextSpan(text: ' '),
                          TextSpan(
                            text: 'on_this_order'.tr,
                            style: waddyRegular.copyWith(
                              fontSize: 15,
                              color: WaddyColors.inkLightOnMint,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (rewardTitle != null) ...[
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: rewardTitle,
                              style: waddyBold.copyWith(
                                fontSize: 13,
                                color: WaddyColors.mintInk,
                              ),
                            ),
                            TextSpan(
                              text:
                                  ' ${'xp_left'.tr.replaceAll('@xp', '$rewardXpLeft')}',
                              style: waddyRegular.copyWith(
                                fontSize: 13,
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
                size: 18,
                color: WaddyColors.mintInk,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(
    CartController cartController,
    StoreController storeController,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "Your basket" header — title + item count on the left, a mint
        // "+ Add more items" action on the right, then a hairline rule.
        Container(
          color: WaddyColors.surface,
          padding: const EdgeInsets.fromLTRB(
            Dimensions.paddingSizeDefault,
            Dimensions.paddingSizeSmall,
            Dimensions.paddingSizeDefault,
            Dimensions.paddingSizeMedium,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'your_basket'.tr,
                      style: waddyBold.copyWith(
                        fontSize: 22,
                        letterSpacing: -0.4,
                        color: WaddyColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${cartController.cartList.length} ${'items'.tr}',
                      style: waddyRegular.copyWith(
                        fontSize: 14,
                        color: WaddyColors.inkLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Dimensions.paddingSizeMedium),
              Padding(
                padding: const EdgeInsets.only(
                  top: Dimensions.paddingSizeExtraSmall,
                ),
                child: GestureDetector(
                  onTap: () {
                    if (widget.fromNav) {
                      Get.offAllNamed(RouteHelper.getInitialRoute());
                    } else {
                      Get.back();
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.add_rounded,
                        size: 15,
                        color: WaddyColors.mintInk,
                      ),
                      const SizedBox(width: Dimensions.paddingSizeSmall),
                      Text(
                        'add_more_items'.tr,
                        style: waddyBold.copyWith(
                          fontSize: 16,
                          color: WaddyColors.mintInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: WaddyColors.divider),

        // No minimum-order / reward strip here: the design gives this slot to
        // the XP band alone. The strip still runs on the store and home cart
        // bars, which is where the free-delivery progress is now surfaced.

        // Cart items — full-bleed white with hairline rules between lines,
        // per the design (no inset rounded card).
        Container(
          color: WaddyColors.surface,
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeDefault,
          ),
          child: ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: cartController.cartList.length,
            padding: EdgeInsets.zero,
            itemBuilder: (context, index) {
              return CartItemWidget(
                cart: cartController.cartList[index],
                cartIndex: index,
                addOns: cartController.addOnsList[index],
                isAvailable: cartController.availableList[index],
                showDivider: index != cartController.cartList.length - 1,
              );
            },
          ),
        ),
        // Rule below the last item is inset 16px, matching the design.
        Container(
          color: WaddyColors.surface,
          padding: const EdgeInsets.only(left: Dimensions.paddingSizeDefault),
          child: const Divider(
            height: 1,
            thickness: 1,
            color: WaddyColors.divider,
          ),
        ),

        // "Add a note for the restaurant"
        _buildRestaurantNoteRow(),

        // 8px band separating the basket from what follows. The scaffold below
        // is warm too, so when the sections that follow render nothing the
        // basket simply ends on the warm ground instead of bleeding into an
        // indistinguishable white void.
        Container(height: 8, color: WaddyColors.surfaceWarm),

        // "Did you forget?" suggested items
        _buildDidYouForgetSection(cartController.cartList),

        // Extra packaging
        ExtraPackagingWidget(cartController: cartController),

        const SizedBox(height: Dimensions.paddingSizeLarge),
      ],
    );
  }

  /// "Add a note for the restaurant" row.
  ///
  /// The sheet writes to [CheckoutController.noteController], which is the same
  /// controller the checkout screen's note field binds to and the source of
  /// `order_note` on the place-order body — so a note typed here survives the
  /// hop to checkout and reaches the restaurant.
  Widget _buildRestaurantNoteRow() {
    final bool hasNote = _restaurantNote.trim().isNotEmpty;

    return Container(
      color: WaddyColors.surface,
      child: InkWell(
        onTap: _openRestaurantNoteSheet,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeDefault,
            vertical: Dimensions.paddingSizeDefault,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.sticky_note_2_outlined,
                size: 22,
                color: WaddyColors.ink,
              ),
              const SizedBox(width: Dimensions.paddingSizeMedium),
              Expanded(
                child: Text(
                  hasNote
                      ? _restaurantNote
                      : 'add_a_note_for_the_restaurant'.tr,
                  style: waddyRegular.copyWith(
                    fontSize: 16,
                    color: hasNote ? WaddyColors.ink : WaddyColors.inkMid,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: Dimensions.paddingSizeSmall),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: WaddyColors.inkMuted,
              ),
            ],
          ),
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
                      fontSize: 18,
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
                      fontSize: 15,
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
    double subTotal = cartController.subTotal;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        Dimensions.paddingSizeDefault,
        Dimensions.paddingSizeMedium,
        Dimensions.paddingSizeDefault,
        0,
      ),
      decoration: BoxDecoration(
        color: WaddyColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // No delivery-address row: the design goes straight from the
            // basket to the CTA. Address and ETA are confirmed on the
            // checkout screen this button opens.

            // Primary CTA — the app's shared CustomButton, so the cart gets the
            // same fill, press animation and disabled/loading behaviour as
            // every other primary action. `child` supplies the split
            // label/total layout the design calls for.
            // "Checkout · <subtotal>", NOT "Place delivery order". This button
            // does not place anything — it opens checkout, where the delivery
            // fee is added and the order is actually confirmed. The number
            // beside it is the subtotal, so it is labelled as one: promising a
            // placed order at a pre-fee price is the version users read as a
            // bait-and-switch when the total jumps on the next screen.
            CustomButton(
              buttonText:
                  '${'go_to_checkout'.tr} — ${'subtotal'.tr} ${PriceConverter.convertPrice(subTotal)}',
              height: 52,
              onPressed: () async {
                // Zone gate before the user is sent any deeper, matching the
                // guard on the other checkout entry point.
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
                } else {
                  if (Get.find<SplashController>().module == null) {
                    // Checking out from the dashboard: adopt the cart's own
                    // module. The hand-rolled scan this replaces ran off the
                    // end of the list when the cart's module was not in it and
                    // then activated `moduleList[length]` — a range error on
                    // the checkout button.
                    await Get.find<SplashController>().activateModuleFor(
                      cartController.cartList[0].item!.moduleId,
                    );
                  }
                  Get.find<CouponController>().removeCouponData(false);
                  Get.toNamed(RouteHelper.getCheckoutRoute('cart'));
                }
              },
              // Mint fill with teal ink — CustomButton's default two-tone
              // look, so the cart CTA matches every other primary action.
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      'go_to_checkout'.tr,
                      style: waddyBold.copyWith(
                        color: WaddyColors.primary,
                        fontSize: 17,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: Dimensions.paddingSizeMedium),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Dimensions.paddingSizeMedium,
                      vertical: Dimensions.paddingSizeExtraSmall,
                    ),
                    decoration: BoxDecoration(
                      // Teal wash rather than a black scrim: the chip sits on
                      // mint, where black reads as a smudge.
                      color: WaddyColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(
                        Dimensions.radiusExtraLarge,
                      ),
                    ),
                    // The word "Subtotal" rides with the number so the figure
                    // can never be mistaken for the final charge. Small and
                    // lighter — it qualifies the price, it isn't the message.
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'subtotal'.tr,
                          style: waddyRegular.copyWith(
                            color: WaddyColors.primary.withValues(alpha: 0.75),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: Dimensions.paddingSizeExtraSmall),
                        Text(
                          PriceConverter.convertPrice(subTotal),
                          style: waddyBold.copyWith(
                            color: WaddyColors.primary,
                            fontSize: 15,
                          ),
                          textDirection: TextDirection.ltr,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // "Waddy! you're saving  [X saved]" — the same treatment the cart
            // bar uses, so the savings story reads identically on both
            // surfaces: coins animation, the pun, then the mint chip.
            if (cartController.itemDiscountPrice > 0)
              Padding(
                padding: const EdgeInsets.only(
                  top: Dimensions.paddingSizeMedium,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: WaddyColors.mintSurface,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(
                        Dimensions.paddingSizeExtraSmall,
                      ),
                      child: Lottie.asset(
                        'assets/animation/off.json',
                        // Clearing a discount is worth celebrating, so this one
                        // loops — unlike the cart bar's static states.
                        repeat: true,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: Dimensions.paddingSizeMedium),
                    Flexible(
                      child: Text(
                        'youre_saving'.tr,
                        style: waddyBold.copyWith(
                          fontSize: 14.5,
                          color: WaddyColors.ink,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: Dimensions.paddingSizeSmall),
                    // "X saved" — mint chip, teal ink, as on the cart bar.
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Dimensions.paddingSizeSmall,
                        vertical: Dimensions.paddingSizeExtraSmall,
                      ),
                      decoration: BoxDecoration(
                        color: WaddyColors.mint,
                        // Pill, matching the total chip inside the CTA — a
                        // square corner here reads as an unfinished edge next
                        // to the button and the circular coin badge.
                        borderRadius: BorderRadius.circular(
                          Dimensions.radiusExtraLarge,
                        ),
                      ),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: PriceConverter.convertPrice(
                                cartController.itemDiscountPrice,
                              ),
                              style: waddyBold.copyWith(
                                fontSize: 12,
                                color: WaddyColors.primary,
                              ),
                            ),
                            TextSpan(
                              text: ' ${'saved'.tr}',
                              style: waddyRegular.copyWith(
                                fontSize: 12,
                                color: WaddyColors.primary,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: Dimensions.paddingSizeMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildDidYouForgetSection(List<CartModel> cartList) {
    return GetBuilder<StoreController>(
      builder: (storeController) {
        List<Item>? suggestedItems;
        if (storeController.cartSuggestItemModel != null) {
          suggestedItems = [];
          List<int> cartIds = [];
          for (CartModel cartItem in cartList) {
            cartIds.add(cartItem.item!.id!);
          }
          for (Item item in storeController.cartSuggestItemModel!.items!) {
            if (!cartIds.contains(item.id)) {
              suggestedItems.add(item);
            }
          }
        }
        if (storeController.cartSuggestItemModel == null ||
            suggestedItems == null ||
            suggestedItems.isEmpty) {
          return const SizedBox();
        }

        // Full-bleed white on the design's sheet, not an inset rounded card,
        // so it reads as another section of the same page.
        return Container(
          padding: const EdgeInsets.fromLTRB(
            0,
            Dimensions.paddingSizeDefault,
            0,
            Dimensions.paddingSizeDefault,
          ),
          color: WaddyColors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: "Did you forget?" + "See all"
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeDefault,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'did_you_forget'.tr,
                      style: waddyBold.copyWith(
                        fontSize: 17,
                        letterSpacing: -0.2,
                        color: WaddyColors.ink,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        // Navigate to store page to see all items
                        if (cartList.isNotEmpty) {
                          Get.find<StoreController>().getStoreDetails(
                            Store(id: cartList[0].item!.storeId, name: null),
                            false,
                          );
                          Get.toNamed(
                            RouteHelper.getStoreRoute(
                              id: cartList[0].item!.storeId!,
                              page: 'item',
                            ),
                          );
                        }
                      },
                      child: Text(
                        'see_all'.tr,
                        style: waddyBold.copyWith(
                          fontSize: 15,
                          color: WaddyColors.mintInk,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Horizontal scroll of suggested item cards
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: suggestedItems.length,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: Dimensions.paddingSizeDefault,
                  ),
                  itemBuilder: (context, index) {
                    final item = suggestedItems![index];
                    double? discount = item.discount;
                    String? discountType = item.discountType;
                    bool hasVariations =
                        (item.foodVariations != null &&
                            item.foodVariations!.isNotEmpty) ||
                        (item.choiceOptions != null &&
                            item.choiceOptions!.isNotEmpty);

                    return GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (con) => ItemBottomSheet(itemId: item.id!),
                        );
                      },
                      child: Container(
                        width: 140,
                        margin: const EdgeInsets.only(
                          right: Dimensions.paddingSizeMedium,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Image card with + overlay
                            Stack(
                              children: [
                                Container(
                                  width: 140,
                                  height: 130,
                                  decoration: BoxDecoration(
                                    color: WaddyColors.surfaceWarm,
                                    borderRadius: BorderRadius.circular(
                                      Dimensions.radiusDefault,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      Dimensions.radiusDefault,
                                    ),
                                    child: CustomImage(
                                      image: item.imageFullUrl ?? '',
                                      height: 130,
                                      width: 140,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                // + button overlay bottom-right
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () async {
                                      if (hasVariations) {
                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          backgroundColor: Colors.transparent,
                                          builder:
                                              (con) => ItemBottomSheet(
                                                itemId: item.id!,
                                              ),
                                        );
                                      } else {
                                        double price =
                                            PriceConverter.convertWithDiscount(
                                              item.price!,
                                              discount,
                                              discountType,
                                            ) ??
                                            item.price!;
                                        OnlineCart onlineCart = OnlineCart(
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
                                        // Guest fallback so this quick-add lands
                                        // in the local cart instead of 401ing.
                                        CartModel suggestedCartModel =
                                            CartModel(
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
                                        // No toast: this quick-add fires from the
                                        // suggestion strip ON the cart screen, so
                                        // the new line lands in the list right
                                        // behind it, in view.
                                        await Get.find<CartController>()
                                            .addToCartOnline(
                                              onlineCart,
                                              localFallback: suggestedCartModel,
                                            );
                                      }
                                    },
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.1,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.add_rounded,
                                          size: 18,
                                          color: WaddyColors.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Item name
                            Text(
                              item.name ?? '',
                              style: waddyBold.copyWith(
                                fontSize: 15,
                                color: WaddyColors.ink,
                                height: 1.25,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            // Price
                            Text(
                              PriceConverter.convertPrice(
                                item.price,
                                discount: discount,
                                discountType: discountType,
                              ),
                              style: waddyBold.copyWith(
                                fontSize: 15,
                                color: WaddyColors.ink,
                              ),
                              textDirection: TextDirection.ltr,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
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
