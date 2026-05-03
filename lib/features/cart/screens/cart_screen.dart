import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:waddy_app/features/cart/controllers/cart_controller.dart';
import 'package:waddy_app/features/cart/widgets/extra_packaging_widget.dart';
import 'package:waddy_app/features/cart/widgets/not_available_bottom_sheet_widget.dart';
import 'package:waddy_app/features/checkout/controllers/checkout_controller.dart';
import 'package:waddy_app/features/coupon/controllers/coupon_controller.dart';
import 'package:waddy_app/features/profile/controllers/profile_controller.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/store/controllers/store_controller.dart';
import 'package:waddy_app/features/cart/domain/models/cart_model.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/helper/responsive_helper.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/images.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_button.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/common/widgets/footer_view.dart';
import 'package:waddy_app/common/widgets/item_bottom_sheet.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/no_data_screen.dart';
import 'package:waddy_app/common/widgets/web_page_title_widget.dart';
import 'package:waddy_app/features/cart/widgets/cart_item_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/cart/widgets/web_cart_items_widget.dart';
import 'package:waddy_app/features/cart/widgets/web_suggested_item_view_widget.dart';
import 'package:waddy_app/features/cart/widgets/minimum_order_progress_widget.dart';
import 'package:waddy_app/features/home/screens/home_screen.dart';
import 'package:waddy_app/features/xp/widgets/xp_shopping_counter_widget.dart';
import 'package:waddy_app/helper/address_helper.dart';
import 'package:waddy_app/features/address/domain/models/address_model.dart';
import 'package:waddy_app/features/checkout/domain/models/place_order_body_model.dart';

class CartScreen extends StatefulWidget {
  final bool fromNav;
  const CartScreen({super.key, required this.fromNav});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final ScrollController scrollController = ScrollController();
  bool _showSuggestions = false;

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
    bool isDesktop = ResponsiveHelper.isDesktop(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF2F0EB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F0EB),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 22, color: Color(0xFF1A1A1A)),
          onPressed: () {
            if (widget.fromNav) {
              Get.offAllNamed(RouteHelper.getInitialRoute());
            } else {
              Get.back();
            }
          },
        ),
        centerTitle: false,
        title: Text(
          'basket'.tr,
          style: robotoBold.copyWith(fontSize: 18, color: const Color(0xFF1A1A1A)),
        ),
      ),
      body: GetBuilder<StoreController>(
        builder: (storeController) {
          return GetBuilder<CartController>(
            builder: (cartController) {
              return cartController.cartList.isNotEmpty
                  ? Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          child: isDesktop
                            ? _buildDesktopLayout(cartController, storeController)
                            : _buildMobileLayout(cartController, storeController),
                        ),
                      ),

                      // Bottom checkout button - Blinkit style
                      if (!isDesktop)
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

  Widget _buildMobileLayout(CartController cartController, StoreController storeController) {
    final Color primaryColor = Theme.of(context).primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "Your basket" header
        Container(
          color: const Color(0xFFF2F0EB),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'your_basket'.tr,
                      style: robotoBold.copyWith(fontSize: 22, color: const Color(0xFF1A1A1A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${cartController.cartList.length} ${'items'.tr} · ${PriceConverter.convertPrice(cartController.subTotal)}',
                      style: robotoRegular.copyWith(fontSize: 13, color: const Color(0xFF888888)),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  if (widget.fromNav) {
                    Get.offAllNamed(RouteHelper.getInitialRoute());
                  } else {
                    Get.back();
                  }
                },
                child: Text(
                  '+ ${'add_more_items'.tr}',
                  style: robotoMedium.copyWith(fontSize: 13, color: primaryColor),
                ),
              ),
            ],
          ),
        ),

        // Minimum order progress bar
        MinimumOrderProgressWidget(
          subTotal: cartController.subTotal,
          store: storeController.store,
        ),

        // Cart items
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
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

        // "Did you forget?" suggested items
        _buildDidYouForgetSection(cartController.cartList),

        // XP Shopping Counter
        const XpShoppingCounterWidget(),

        // Extra packaging
        ExtraPackagingWidget(cartController: cartController),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildDesktopLayout(CartController cartController, StoreController storeController) {
    return FooterView(
      child: SizedBox(
        width: Dimensions.webMaxWidth,
        child: Column(
          children: [
            WebScreenTitleWidget(title: 'cart_list'.tr),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WebCardItemsWidget(cartList: cartController.cartList),
                const SizedBox(width: Dimensions.paddingSizeSmall),
                Expanded(
                  flex: 4,
                  child: pricingView(cartController, cartController.cartList[0].item!),
                ),
              ],
            ),
            WebSuggestedItemViewWidget(cartList: cartController.cartList),
            const SizedBox(height: Dimensions.paddingSizeExtraOverLarge),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryAddressPreview(StoreController storeController) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final AddressModel? address = AddressHelper.getUserAddressFromSharedPref();

    if (address == null || address.address == null) return const SizedBox();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.location_on_rounded, size: 22, color: primaryColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'deliver_to'.tr,
                      style: robotoBold.copyWith(fontSize: 14, color: Colors.black87),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      address.address!,
                      style: robotoRegular.copyWith(fontSize: 12, color: Colors.grey.shade600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => Get.toNamed(RouteHelper.getAccessLocationRoute('cart')),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: primaryColor, width: 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'change'.tr,
                    style: robotoMedium.copyWith(fontSize: 12, color: primaryColor),
                  ),
                ),
              ),
            ],
          ),

          // Delivery time estimate
          if (storeController.store?.deliveryTime != null) ...[            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 16, color: primaryColor),
                    const SizedBox(width: 6),
                    Text(
                      '${'estimated_time'.tr}: ${storeController.store!.deliveryTime} ${'min'.tr}',
                      style: robotoMedium.copyWith(fontSize: 12, color: primaryColor),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderSummary(CartController cartController, StoreController storeController) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final bool hasAddons = cartController.addOns > 0;
    final bool hasVariations = cartController.variationPrice > 0;
    final bool hasDiscount = cartController.itemDiscountPrice > 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).secondaryHeaderColor.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            // Decorative glow circle top-right
            Positioned(
              top: -18,
              right: -18,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Theme.of(context).secondaryHeaderColor.withOpacity(0.18),
                      Theme.of(context).secondaryHeaderColor.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).secondaryHeaderColor,
                      primaryColor,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.receipt_long_rounded, size: 16, color: primaryColor),
              const SizedBox(width: 6),
              Text(
                'order_summary'.tr,
                style: robotoBold.copyWith(fontSize: 14, color: Colors.black87),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Item breakdown section
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade100, width: 1),
            ),
            child: Column(
              children: [
                // Item price
                _buildSummaryRow(
                  '${hasDiscount ? 'Original Price' : 'Item Price'} (${cartController.cartList.length} ${'items'.tr})',
                  PriceConverter.convertPrice(cartController.itemPrice),
                ),

                // Variations
                if (hasVariations) ...[
                  const SizedBox(height: 6),
                  _buildSummaryRow(
                    'variations'.tr,
                    '+ ${PriceConverter.convertPrice(cartController.variationPrice)}',
                  ),
                ],

                // Addons
                if (hasAddons) ...[
                  const SizedBox(height: 6),
                  _buildSummaryRow(
                    'addons'.tr,
                    '+ ${PriceConverter.convertPrice(cartController.addOns)}',
                  ),
                ],

                // Discount with tappable breakdown
                if (hasDiscount) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: GestureDetector(
                          onTap: () => _showDiscountBreakdown(context, cartController),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'discount'.tr,
                                style: robotoRegular.copyWith(fontSize: 13, color: Colors.grey.shade600),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.help_outline_rounded, size: 14, color: Colors.grey.shade400),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '- ${PriceConverter.convertPrice(cartController.itemDiscountPrice)}',
                        style: robotoMedium.copyWith(fontSize: 13, color: Colors.green.shade600),
                        textDirection: TextDirection.ltr,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Subtotal
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).secondaryHeaderColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).secondaryHeaderColor.withOpacity(0.2), width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'subtotal'.tr,
                    style: robotoBold.copyWith(fontSize: 15, color: Colors.black87),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).secondaryHeaderColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      PriceConverter.convertPrice(cartController.subTotal),
                      style: robotoBold.copyWith(fontSize: 16, color: primaryColor),
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Note: delivery & taxes at checkout
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline_rounded, size: 12, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(
                  'delivery_taxes_calculated_at_checkout'.tr,
                  style: robotoRegular.copyWith(fontSize: 10, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
        ],
      ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDiscountBreakdown(BuildContext context, CartController cartController) {
    final Color primaryColor = Theme.of(context).primaryColor;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        double runningTotal = 0;
        final items = cartController.cartList.map((cart) {
          double? discount = cart.item!.discount;
          String? discountType = cart.item!.discountType;
          double originalUnit = PriceConverter.convertWithDiscount(cart.item!.price!, 0, 'amount')!;
          double discountedUnit = PriceConverter.convertWithDiscount(cart.item!.price!, discount, discountType)!;
          double itemSaving = (originalUnit - discountedUnit) * cart.quantity!;
          runningTotal += itemSaving;
          return (name: cart.item!.name!, saving: itemSaving, qty: cart.quantity!);
        }).where((e) => e.saving > 0).toList();

        double displayedTotal = cartController.itemDiscountPrice;
        double roundingDiff = (displayedTotal - runningTotal).abs();

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              Text('Discount Breakdown', style: robotoBold.copyWith(fontSize: 16, color: Colors.black87)),
              const SizedBox(height: 12),
              ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(child: Text(item.name, style: robotoRegular.copyWith(fontSize: 13, color: Colors.grey.shade700), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text('- ${PriceConverter.convertPrice(item.saving)}', style: robotoMedium.copyWith(fontSize: 13, color: Colors.green.shade600), textDirection: TextDirection.ltr),
                  ],
                ),
              )),
              if (roundingDiff >= 0.5) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Rounding adjustment', style: robotoRegular.copyWith(fontSize: 12, color: Colors.grey.shade400)),
                      Text('~ ${PriceConverter.convertPrice(roundingDiff)}', style: robotoRegular.copyWith(fontSize: 12, color: Colors.grey.shade400), textDirection: TextDirection.ltr),
                    ],
                  ),
                ),
              ],
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Saved', style: robotoBold.copyWith(fontSize: 14, color: Colors.black87)),
                  Text('- ${PriceConverter.convertPrice(displayedTotal)}', style: robotoBold.copyWith(fontSize: 14, color: primaryColor), textDirection: TextDirection.ltr),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? valueColor, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: (isBold ? robotoMedium : robotoRegular).copyWith(
              fontSize: isBold ? 14 : 13,
              color: isBold ? Colors.black87 : Colors.grey.shade600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: (isBold ? robotoBold : robotoMedium).copyWith(
            fontSize: isBold ? 14 : 13,
            color: valueColor ?? Colors.black87,
          ),
          textDirection: TextDirection.ltr,
        ),
      ],
    );
  }

  Widget _buildBottomCheckoutButton(CartController cartController) {
    double subTotal = cartController.subTotal;
    final Color primaryColor = Theme.of(context).primaryColor;
    final AddressModel? address = AddressHelper.getUserAddressFromSharedPref();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      decoration: const BoxDecoration(
        color: Color(0xFFF2F0EB),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Delivery address row
            if (address != null && address.address != null)
              GetBuilder<StoreController>(
                builder: (storeController) {
                  return GestureDetector(
                    onTap: () => Get.toNamed(RouteHelper.getAccessLocationRoute('cart')),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.location_on_rounded, size: 20, color: primaryColor),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${'deliver_to'.tr} ${address.addressType ?? 'home'.tr} · ${address.address!.split(',').first}',
                                  style: robotoMedium.copyWith(fontSize: 13.5, color: const Color(0xFF1A1A1A)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (storeController.store?.deliveryTime != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      '${'arriving_in'.tr} ${storeController.store!.deliveryTime} ${'min'.tr}',
                                      style: robotoRegular.copyWith(fontSize: 12, color: const Color(0xFF888888)),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, size: 22, color: Color(0xFF888888)),
                        ],
                      ),
                    ),
                  );
                },
              ),

            // Payment row
            Row(
              children: [
                // Payment method chip (placeholder)
                /*
                GestureDetector(
                  onTap: () {
                    // Navigate to payment selection
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.credit_card_rounded, size: 18, color: primaryColor),
                        const SizedBox(width: 8),
                        Text('pay'.tr, style: robotoMedium.copyWith(fontSize: 13, color: const Color(0xFF1A1A1A))),
                        const SizedBox(width: 6),
                        const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF888888)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                */
                // Pay button
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Get.find<CheckoutController>().updateFirstTime();
                      if (!cartController.cartList.first.item!.scheduleOrder! &&
                          cartController.availableList.contains(false)) {
                        showCustomSnackBar('one_or_more_product_unavailable'.tr);
                      } else {
                        if (Get.find<SplashController>().module == null) {
                          int i = 0;
                          for (i = 0; i < Get.find<SplashController>().moduleList!.length; i++) {
                            if (cartController.cartList[0].item!.moduleId ==
                                Get.find<SplashController>().moduleList![i].id) {
                              break;
                            }
                          }
                          Get.find<SplashController>().setModule(
                            Get.find<SplashController>().moduleList![i],
                          );
                          HomeScreen.loadData(true);
                        }
                        Get.find<CouponController>().removeCouponData(false);
                        Get.toNamed(RouteHelper.getCheckoutRoute('cart'));
                      }
                    },
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          '${'pay'.tr} ${PriceConverter.convertPrice(subTotal)}',
                          style: robotoBold.copyWith(
                            color: Colors.white,
                            fontSize: 16,
                            letterSpacing: 0.3,
                          ),
                          textDirection: TextDirection.ltr,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget pricingView(CartController cartController, Item item) {
    return Container(
      decoration:
          ResponsiveHelper.isDesktop(context)
              ? BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(
                  ResponsiveHelper.isDesktop(context)
                      ? Dimensions.radiusDefault
                      : Dimensions.radiusSmall,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 5,
                    spreadRadius: 1,
                  ),
                ],
              )
              : null,
      child: GetBuilder<StoreController>(
        builder: (storeController) {
          return Column(
            children: [
              ResponsiveHelper.isDesktop(context)
                  ? ExtraPackagingWidget(cartController: cartController)
                  : const SizedBox(),

              ResponsiveHelper.isDesktop(context)
                  ? Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Dimensions.paddingSizeDefault,
                        vertical: Dimensions.paddingSizeSmall,
                      ),
                      child: Text('order_summary'.tr, style: robotoBold),
                    ),
                  )
                  : const SizedBox(),

              !ResponsiveHelper.isDesktop(context) &&
                      Get.find<SplashController>()
                          .getModuleConfig(item.moduleType)
                          .newVariation! &&
                      (storeController.store != null &&
                          storeController.store!.cutlery!)
                  ? Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade50,
                          blurRadius: 2,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: Dimensions.paddingSizeDefault,
                      vertical: Dimensions.paddingSizeSmall,
                    ),
                    margin: const EdgeInsets.only(
                      bottom: Dimensions.paddingSizeSmall,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Image.asset(Images.cutlery, height: 18, width: 18),
                        const SizedBox(width: Dimensions.paddingSizeDefault),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'add_cutlery'.tr,
                                style: robotoMedium.copyWith(
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              const SizedBox(
                                height: Dimensions.paddingSizeExtraSmall,
                              ),

                              Text(
                                'do_not_have_cutlery'.tr,
                                style: robotoRegular.copyWith(
                                  color: Theme.of(context).disabledColor,
                                  fontSize: Dimensions.fontSizeSmall,
                                ),
                              ),
                            ],
                          ),
                        ),

                        Transform.scale(
                          scale: 0.7,
                          child: CupertinoSwitch(
                            value: cartController.addCutlery,
                            activeTrackColor: Theme.of(context).primaryColor,
                            onChanged: (bool? value) {
                              cartController.updateCutlery();
                            },
                            inactiveTrackColor: Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  )
                  : const SizedBox(),

              ResponsiveHelper.isDesktop(context)
                  ? const SizedBox()
                  : Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade50,
                          blurRadius: 2,
                          spreadRadius: 1,
                        ),
                      ],
                      // border: Border.all(color: Theme.of(context).primaryColor, width: 0.5),
                    ),
                    padding: const EdgeInsets.all(
                      Dimensions.paddingSizeDefault,
                    ),
                    margin:
                        ResponsiveHelper.isDesktop(context)
                            ? const EdgeInsets.symmetric(
                              horizontal: Dimensions.paddingSizeDefault,
                              vertical: Dimensions.paddingSizeSmall,
                            )
                            : EdgeInsets.zero,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () {
                            if (ResponsiveHelper.isDesktop(context)) {
                              Get.dialog(
                                const Dialog(
                                  child: NotAvailableBottomSheetWidget(),
                                ),
                              );
                            } else {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder:
                                    (con) =>
                                        const NotAvailableBottomSheetWidget(),
                              );
                            }
                          },
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'if_any_product_is_not_available'.tr,
                                  style: robotoMedium,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios_sharp,
                                size: 18,
                              ),
                            ],
                          ),
                        ),

                        cartController.notAvailableIndex != -1
                            ? Row(
                              children: [
                                Text(
                                  cartController
                                      .notAvailableList[cartController
                                          .notAvailableIndex]
                                      .tr,
                                  style: robotoMedium.copyWith(
                                    fontSize: Dimensions.fontSizeSmall,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),

                                IconButton(
                                  onPressed:
                                      () =>
                                          cartController.setAvailableIndex(-1),
                                  icon: const Icon(Icons.clear, size: 18),
                                ),
                              ],
                            )
                            : const SizedBox(),
                      ],
                    ),
                  ),
              ResponsiveHelper.isDesktop(context)
                  ? const SizedBox()
                  : const SizedBox(height: Dimensions.paddingSizeSmall),

              // Total
              ResponsiveHelper.isDesktop(context)
                  ? Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Dimensions.paddingSizeDefault,
                      vertical: Dimensions.paddingSizeSmall,
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('item_price'.tr, style: robotoRegular),
                            PriceConverter.convertAnimationPrice(
                              cartController.itemPrice,
                              textStyle: robotoRegular,
                            ),
                          ],
                        ),
                        SizedBox(
                          height:
                              cartController.variationPrice > 0
                                  ? Dimensions.paddingSizeSmall
                                  : 0,
                        ),

                        Get.find<SplashController>()
                                    .getModuleConfig(item.moduleType)
                                    .newVariation! &&
                                cartController.variationPrice > 0
                            ? Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('variations'.tr, style: robotoRegular),
                                Text(
                                  '(+) ${PriceConverter.convertPrice(cartController.variationPrice)}',
                                  style: robotoRegular,
                                  textDirection: TextDirection.ltr,
                                ),
                              ],
                            )
                            : const SizedBox(),
                        const SizedBox(height: Dimensions.paddingSizeSmall),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('discount'.tr, style: robotoRegular),
                            storeController.store != null
                                ? Row(
                                  children: [
                                    Text('(-)', style: robotoRegular),
                                    PriceConverter.convertAnimationPrice(
                                      cartController.itemDiscountPrice,
                                      textStyle: robotoRegular,
                                    ),
                                  ],
                                )
                                : Text('calculating'.tr, style: robotoRegular),
                            // Text('(-) ${PriceConverter.convertPrice(cartController.itemDiscountPrice)}', style: robotoRegular, textDirection: TextDirection.ltr),
                          ],
                        ),
                        SizedBox(
                          height:
                              Get.find<SplashController>()
                                      .configModel!
                                      .moduleConfig!
                                      .module!
                                      .addOn!
                                  ? 10
                                  : 0,
                        ),

                        Get.find<SplashController>()
                                .configModel!
                                .moduleConfig!
                                .module!
                                .addOn!
                            ? Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('addons'.tr, style: robotoRegular),
                                Text(
                                  '(+) ${PriceConverter.convertPrice(cartController.addOns)}',
                                  style: robotoRegular,
                                  textDirection: TextDirection.ltr,
                                ),
                              ],
                            )
                            : const SizedBox(),
                      ],
                    ),
                  )
                  : const SizedBox(),

              ResponsiveHelper.isDesktop(context)
                  ? CheckoutButton(
                    cartController: cartController,
                    availableList: cartController.availableList,
                  )
                  : const SizedBox.shrink(),
            ],
          );
        },
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
        if (storeController.cartSuggestItemModel == null || suggestedItems == null || suggestedItems.isEmpty) {
          return const SizedBox();
        }

        return Container(
          margin: const EdgeInsets.fromLTRB(0, 12, 0, 0),
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16), bottom: Radius.circular(16)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: "Did you forget?" + "See all"
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'did_you_forget'.tr,
                      style: robotoBold.copyWith(fontSize: 17, color: const Color(0xFF1A1A1A)),
                    ),
                    GestureDetector(
                      onTap: () {
                        // Navigate to store page to see all items
                        if (cartList.isNotEmpty) {
                          Get.find<StoreController>().getStoreDetails(
                            Store(id: cartList[0].item!.storeId, name: null),
                            false,
                          );
                          Get.toNamed(RouteHelper.getStoreRoute(
                            id: cartList[0].item!.storeId!,
                            page: 'item',
                          ));
                        }
                      },
                      child: Text(
                        'see_all'.tr,
                        style: robotoRegular.copyWith(fontSize: 13, color: const Color(0xFF888888)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final item = suggestedItems![index];
                    double? discount = item.discount;
                    String? discountType = item.discountType;
                    bool hasVariations = (item.foodVariations != null && item.foodVariations!.isNotEmpty) ||
                        (item.choiceOptions != null && item.choiceOptions!.isNotEmpty);

                    return GestureDetector(
                      onTap: () {
                        ResponsiveHelper.isMobile(context)
                            ? showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (con) => ItemBottomSheet(itemId: item.id!),
                              )
                            : showDialog(
                                context: context,
                                builder: (con) => Dialog(
                                  child: ItemBottomSheet(itemId: item.id!),
                                ),
                              );
                      },
                      child: Container(
                        width: 140,
                        margin: const EdgeInsets.only(right: 12),
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
                                    color: const Color(0xFFF5F2EC),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
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
                                        ResponsiveHelper.isMobile(context)
                                            ? showModalBottomSheet(
                                                context: context,
                                                isScrollControlled: true,
                                                backgroundColor: Colors.transparent,
                                                builder: (con) => ItemBottomSheet(itemId: item.id!),
                                              )
                                            : showDialog(
                                                context: context,
                                                builder: (con) => Dialog(
                                                  child: ItemBottomSheet(itemId: item.id!),
                                                ),
                                              );
                                      } else {
                                        double price = PriceConverter.convertWithDiscount(item.price!, discount, discountType) ?? item.price!;
                                        OnlineCart onlineCart = OnlineCart(
                                          null, item.id, null,
                                          price.toString(), '', null, null,
                                          1, [], null, [], 'Item',
                                        );
                                        bool success = await Get.find<CartController>().addToCartOnline(onlineCart);
                                        if (success) {
                                          showCustomSnackBar('added_to_cart'.tr, isError: false);
                                        }
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
                                            color: Colors.black.withValues(alpha: 0.1),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: const Center(
                                        child: Icon(Icons.add_rounded, size: 18, color: Color(0xFF1A1A1A)),
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
                              style: robotoMedium.copyWith(fontSize: 13, color: const Color(0xFF1A1A1A), height: 1.2),
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
                              style: robotoMedium.copyWith(fontSize: 13, color: const Color(0xFF555555)),
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

  Widget suggestedItemView(List<CartModel> cartList) {
    final Color primaryColor = Theme.of(context).primaryColor;

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
        return storeController.cartSuggestItemModel != null && suggestedItems!.isNotEmpty
            ? Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Collapsible header
                  InkWell(
                    onTap: () => setState(() => _showSuggestions = !_showSuggestions),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Icon(Icons.lightbulb_outline_rounded, size: 18, color: Colors.grey.shade500),
                          const SizedBox(width: 8),
                          Text(
                            'you_may_also_like'.tr,
                            style: robotoMedium.copyWith(fontSize: 14, color: Colors.grey.shade700),
                          ),
                          const Spacer(),
                          AnimatedRotation(
                            turns: _showSuggestions ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Expandable product cards
                  AnimatedCrossFade(
                    firstChild: const SizedBox(width: double.infinity, height: 0),
                    secondChild: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SizedBox(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: suggestedItems.length,
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.zero,
                          itemBuilder: (context, index) {
                            final item = suggestedItems![index];
                            double? discount = item.discount;
                            String? discountType = item.discountType;
                            bool hasVariations = (item.foodVariations != null && item.foodVariations!.isNotEmpty) ||
                                (item.choiceOptions != null && item.choiceOptions!.isNotEmpty);

                            return GestureDetector(
                              onTap: () {
                                ResponsiveHelper.isMobile(context)
                                    ? showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        builder: (con) => ItemBottomSheet(itemId: item.id!),
                                      )
                                    : showDialog(
                                        context: context,
                                        builder: (con) => Dialog(
                                          child: ItemBottomSheet(itemId: item.id!),
                                        ),
                                      );
                              },
                              child: Container(
                                width: 220,
                                margin: const EdgeInsets.only(right: 10),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade200, width: 1),
                                ),
                                child: Row(
                                  children: [
                                    // Product image
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: CustomImage(
                                        image: item.imageFullUrl ?? '',
                                        height: 60,
                                        width: 60,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    // Name + price
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            item.name ?? '',
                                            style: robotoMedium.copyWith(fontSize: 12, height: 1.2),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            PriceConverter.convertPrice(
                                              item.price,
                                              discount: discount,
                                              discountType: discountType,
                                            ),
                                            style: robotoBold.copyWith(fontSize: 13, color: primaryColor),
                                            textDirection: TextDirection.ltr,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    // ADD button
                                    GestureDetector(
                                      onTap: () async {
                                        if (hasVariations) {
                                          ResponsiveHelper.isMobile(context)
                                              ? showModalBottomSheet(
                                                  context: context,
                                                  isScrollControlled: true,
                                                  backgroundColor: Colors.transparent,
                                                  builder: (con) => ItemBottomSheet(itemId: item.id!),
                                                )
                                              : showDialog(
                                                  context: context,
                                                  builder: (con) => Dialog(
                                                    child: ItemBottomSheet(itemId: item.id!),
                                                  ),
                                                );
                                        } else {
                                          double price = PriceConverter.convertWithDiscount(item.price!, discount, discountType) ?? item.price!;
                                          OnlineCart onlineCart = OnlineCart(
                                            null, item.id, null,
                                            price.toString(), '', null, null,
                                            1, [], null, [], 'Item',
                                          );
                                          bool success = await Get.find<CartController>().addToCartOnline(onlineCart);
                                          if (success) {
                                            showCustomSnackBar('added_to_cart'.tr, isError: false);
                                          }
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: primaryColor,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'add'.tr,
                                          style: robotoBold.copyWith(fontSize: 12, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    crossFadeState: _showSuggestions
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 250),
                  ),
                ],
              ),
            )
            : const SizedBox();
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

class CheckoutButton extends StatelessWidget {
  final CartController cartController;
  final List<bool> availableList;
  const CheckoutButton({
    super.key,
    required this.cartController,
    required this.availableList,
  });

  @override
  Widget build(BuildContext context) {
    double percentage = 0;

    return Container(
      width: Dimensions.webMaxWidth,
      padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.isDesktop(context) ? Dimensions.radiusDefault : 0,
        ),
      ),
      child: GetBuilder<StoreController>(
        builder: (storeController) {
          if (Get.find<StoreController>().store != null &&
              !Get.find<StoreController>().store!.freeDelivery! &&
              (Get.find<SplashController>()
                          .configModel
                          ?.adminFreeDelivery
                          ?.status ==
                      true &&
                  (Get.find<SplashController>()
                              .configModel
                              ?.adminFreeDelivery
                              ?.type !=
                          null &&
                      Get.find<SplashController>()
                              .configModel
                              ?.adminFreeDelivery
                              ?.type ==
                          'free_delivery_by_order_amount') &&
                  (Get.find<SplashController>()
                          .configModel!
                          .adminFreeDelivery
                          ?.freeDeliveryOver !=
                      null))) {
            percentage =
                cartController.subTotal /
                Get.find<SplashController>()
                    .configModel!
                    .adminFreeDelivery!
                    .freeDeliveryOver!;
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              (storeController.store != null &&
                      !storeController.store!.freeDelivery! &&
                      (Get.find<SplashController>()
                                  .configModel
                                  ?.adminFreeDelivery
                                  ?.status ==
                              true &&
                          (Get.find<SplashController>()
                                      .configModel
                                      ?.adminFreeDelivery
                                      ?.type !=
                                  null &&
                              Get.find<SplashController>()
                                      .configModel
                                      ?.adminFreeDelivery
                                      ?.type ==
                                  'free_delivery_by_order_amount') &&
                          (Get.find<SplashController>()
                                  .configModel!
                                  .adminFreeDelivery
                                  ?.freeDeliveryOver !=
                              null)) &&
                      percentage < 1)
                  ? Column(
                    children: [
                      Row(
                        children: [
                          Image.asset(Images.percentTag, height: 20, width: 20),
                          const SizedBox(
                            width: Dimensions.paddingSizeExtraSmall,
                          ),

                          Text(
                            PriceConverter.convertPrice(
                              Get.find<SplashController>()
                                      .configModel!
                                      .adminFreeDelivery!
                                      .freeDeliveryOver! -
                                  cartController.subTotal,
                            ),
                            style: robotoMedium.copyWith(
                              color: Theme.of(context).primaryColor,
                            ),
                            textDirection: TextDirection.ltr,
                          ),
                          const SizedBox(
                            width: Dimensions.paddingSizeExtraSmall,
                          ),

                          Text(
                            'more_for_free_delivery'.tr,
                            style: robotoMedium.copyWith(
                              color: Theme.of(context).disabledColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Dimensions.paddingSizeExtraSmall),

                      LinearProgressIndicator(
                        backgroundColor: Theme.of(
                          context,
                        ).primaryColor.withValues(alpha: 0.2),
                        value: percentage,
                      ),
                    ],
                  )
                  : const SizedBox(),

              ResponsiveHelper.isDesktop(context)
                  ? const Divider(height: 1)
                  : const SizedBox(),
              const SizedBox(height: Dimensions.paddingSizeExtraSmall),

              Padding(
                padding: const EdgeInsets.only(
                  bottom: Dimensions.paddingSizeSmall,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'subtotal'.tr,
                      style: robotoMedium.copyWith(
                        color:
                            ResponsiveHelper.isDesktop(context)
                                ? Theme.of(context).textTheme.bodyLarge!.color
                                : Theme.of(context).primaryColor,
                      ),
                    ),
                    PriceConverter.convertAnimationPrice(
                      cartController.subTotal,
                      textStyle: robotoRegular.copyWith(
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),

              ResponsiveHelper.isDesktop(context) &&
                      Get.find<SplashController>()
                          .getModuleConfig(
                            cartController.cartList[0].item!.moduleType,
                          )
                          .newVariation! &&
                      (storeController.store != null &&
                          storeController.store!.cutlery!)
                  ? Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 0,
                      vertical: 0,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Image.asset(Images.cutlery, height: 18, width: 18),
                        const SizedBox(width: Dimensions.paddingSizeDefault),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'add_cutlery'.tr,
                                style: robotoMedium.copyWith(
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              const SizedBox(
                                height: Dimensions.paddingSizeExtraSmall,
                              ),

                              Text(
                                'do_not_have_cutlery'.tr,
                                style: robotoRegular.copyWith(
                                  color: Theme.of(context).disabledColor,
                                  fontSize: Dimensions.fontSizeSmall,
                                ),
                              ),
                            ],
                          ),
                        ),

                        Transform.scale(
                          scale: 0.7,
                          child: CupertinoSwitch(
                            value: cartController.addCutlery,
                            activeTrackColor: Theme.of(context).primaryColor,
                            onChanged: (bool? value) {
                              cartController.updateCutlery();
                            },
                            inactiveTrackColor: Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  )
                  : const SizedBox(),
              ResponsiveHelper.isDesktop(context)
                  ? const SizedBox(height: Dimensions.paddingSizeSmall)
                  : const SizedBox(),

              !ResponsiveHelper.isDesktop(context)
                  ? const SizedBox()
                  : Container(
                    width: Dimensions.webMaxWidth,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        Dimensions.radiusSmall,
                      ),
                      color: Theme.of(context).cardColor,
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).disabledColor.withValues(alpha: 0.2),
                        width: 0.5,
                      ),
                    ),
                    padding: const EdgeInsets.all(
                      Dimensions.paddingSizeDefault,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: () {
                            if (ResponsiveHelper.isDesktop(context)) {
                              Get.dialog(
                                const Dialog(
                                  child: NotAvailableBottomSheetWidget(),
                                ),
                              );
                            } else {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder:
                                    (con) =>
                                        const NotAvailableBottomSheetWidget(),
                              );
                            }
                          },
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'if_any_product_is_not_available'.tr,
                                  style: robotoMedium.copyWith(
                                    fontSize: Dimensions.fontSizeSmall,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.keyboard_arrow_down, size: 18),
                            ],
                          ),
                        ),
                        const SizedBox(
                          height: Dimensions.paddingSizeExtraSmall,
                        ),

                        Container(
                          padding: const EdgeInsets.only(
                            left: Dimensions.paddingSizeSmall,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              Dimensions.radiusSmall,
                            ),
                            color: Theme.of(
                              context,
                            ).disabledColor.withValues(alpha: 0.1),
                          ),
                          child:
                              cartController.notAvailableIndex != -1
                                  ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        cartController
                                            .notAvailableList[cartController
                                                .notAvailableIndex]
                                            .tr,
                                        style: robotoRegular.copyWith(
                                          fontSize:
                                              Dimensions.fontSizeExtraSmall,
                                          color: Theme.of(context).hintColor,
                                        ),
                                      ),

                                      IconButton(
                                        onPressed:
                                            () => cartController
                                                .setAvailableIndex(-1),
                                        icon: const Icon(
                                          Icons.clear,
                                          size: 18,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ],
                                  )
                                  : const SizedBox(),
                        ),
                      ],
                    ),
                  ),
              ResponsiveHelper.isDesktop(context)
                  ? const SizedBox(height: Dimensions.paddingSizeSmall)
                  : const SizedBox(),

              SafeArea(
                child: CustomButton(
                  buttonText: 'confirm_delivery_details'.tr,
                  fontSize:
                      ResponsiveHelper.isDesktop(context)
                          ? Dimensions.fontSizeSmall
                          : Dimensions.fontSizeLarge,
                  isBold: ResponsiveHelper.isDesktop(context) ? false : true,
                  radius:
                      ResponsiveHelper.isDesktop(context)
                          ? Dimensions.radiusSmall
                          : Dimensions.radiusDefault,
                  onPressed: () {
                    Get.find<CheckoutController>().updateFirstTime();
                    if (!cartController.cartList.first.item!.scheduleOrder! &&
                        availableList.contains(false)) {
                      showCustomSnackBar('one_or_more_product_unavailable'.tr);
                    } else {
                      if (Get.find<SplashController>().module == null) {
                        int i = 0;
                        for (
                          i = 0;
                          i < Get.find<SplashController>().moduleList!.length;
                          i++
                        ) {
                          if (cartController.cartList[0].item!.moduleId ==
                              Get.find<SplashController>().moduleList![i].id) {
                            break;
                          }
                        }
                        Get.find<SplashController>().setModule(
                          Get.find<SplashController>().moduleList![i],
                        );
                        HomeScreen.loadData(true);
                      }
                      Get.find<CouponController>().removeCouponData(false);

                      Get.toNamed(RouteHelper.getCheckoutRoute('cart'));
                    }
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
