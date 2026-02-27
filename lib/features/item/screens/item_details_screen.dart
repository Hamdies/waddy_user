import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/features/cart/controllers/cart_controller.dart';
import 'package:sixam_mart/features/item/controllers/item_controller.dart';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/features/checkout/domain/models/place_order_body_model.dart';
import 'package:sixam_mart/features/cart/domain/models/cart_model.dart';
import 'package:sixam_mart/features/item/domain/models/item_model.dart';
import 'package:sixam_mart/helper/price_converter.dart';
import 'package:sixam_mart/helper/responsive_helper.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/images.dart';
import 'package:sixam_mart/util/styles.dart';
import 'package:sixam_mart/common/widgets/confirmation_dialog.dart';
import 'package:sixam_mart/common/widgets/custom_app_bar.dart';
import 'package:sixam_mart/common/widgets/custom_image.dart';
import 'package:sixam_mart/common/widgets/custom_snackbar.dart';
import 'package:sixam_mart/common/widgets/menu_drawer.dart';
import 'package:sixam_mart/features/checkout/screens/checkout_screen.dart';
import 'package:sixam_mart/features/item/widgets/details_app_bar_widget.dart';
import 'package:sixam_mart/features/item/widgets/details_web_view_widget.dart';
import 'package:sixam_mart/features/item/widgets/item_image_view_widget.dart';
import 'package:sixam_mart/features/item/widgets/item_title_view_widget.dart';
import 'package:sixam_mart/features/cart/widgets/cart_module_conflict_dialog.dart';

class ItemDetailsScreen extends StatefulWidget {
  final int itemId;
  final bool inStorePage;
  final bool? isCampaign;
  const ItemDetailsScreen({
    super.key,
    required this.itemId,
    required this.inStorePage,
    this.isCampaign,
  });

  @override
  State<ItemDetailsScreen> createState() => _ItemDetailsScreenState();
}

class _ItemDetailsScreenState extends State<ItemDetailsScreen> with TickerProviderStateMixin {
  final Size size = Get.size;
  final GlobalKey<ScaffoldMessengerState> _globalKey = GlobalKey();
  final GlobalKey<DetailsAppBarWidgetState> _key = GlobalKey();
  final GlobalKey _addToCartButtonKey = GlobalKey();
  final GlobalKey _productImageKey = GlobalKey();

  OverlayEntry? _overlayEntry;
  late AnimationController _flyAnimationController;
  late Animation<double> _flyAnimation;

  @override
  void initState() {
    super.initState();

    _flyAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _flyAnimation = CurvedAnimation(
      parent: _flyAnimationController,
      curve: Curves.easeInOutCubic,
    );

    Get.find<ItemController>().getItemDetails(itemId: widget.itemId);
    Get.find<ItemController>().setSelect(0, false);
    Get.find<ItemController>().getRecommendedItemList(true, 'all', false);
  }

  @override
  void dispose() {
    _flyAnimationController.dispose();
    super.dispose();
  }

  void _startFlyToCartAnimation(String imageUrl) {
    final RenderBox? productBox = _productImageKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? buttonBox = _addToCartButtonKey.currentContext?.findRenderObject() as RenderBox?;

    if (productBox == null || buttonBox == null) return;

    final productPosition = productBox.localToGlobal(Offset.zero);
    final buttonPosition = buttonBox.localToGlobal(Offset.zero);
    final productSize = productBox.size;
    final buttonSize = buttonBox.size;

    final startX = productPosition.dx + productSize.width / 2 - 30;
    final startY = productPosition.dy + productSize.height / 2 - 30;
    final endX = buttonPosition.dx + buttonSize.width / 2 - 12;
    final endY = buttonPosition.dy + buttonSize.height / 2 - 12;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return AnimatedBuilder(
          animation: _flyAnimation,
          builder: (context, child) {
            final t = _flyAnimation.value;
            final x = startX + (endX - startX) * t;
            final y = startY + (endY - startY) * t;
            final imgSize = 60.0 * (1.0 - t * 0.7);
            final opacity = 1.0 - t * 0.5;

            return Positioned(
              left: x,
              top: y,
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: SizedBox(
                  width: imgSize,
                  height: imgSize,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(imgSize / 2),
                    child: CustomImage(
                      image: imageUrl,
                      height: imgSize,
                      width: imgSize,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);

    _flyAnimationController.forward(from: 0.0).then((_) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      _key.currentState?.shake();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CartController>(
      builder: (cartController) {
        return GetBuilder<ItemController>(
          builder: (itemController) {
            Item? item = itemController.item;

            int? stock = 0;
            CartModel? cartModel;
            OnlineCart? cart;
            double priceWithAddons = 0;
            int? cartId = cartController.getCartId(itemController.cartIndex);
            if (item != null && itemController.variationIndex != null) {
              List<String> variationList = [];
              for (int index = 0; index < item.choiceOptions!.length; index++) {
                variationList.add(
                  item
                      .choiceOptions![index]
                      .options![itemController.variationIndex![index]]
                      .replaceAll(' ', ''),
                );
              }
              String variationType = '';
              bool isFirst = true;
              for (var variation in variationList) {
                if (isFirst) {
                  variationType = '$variationType$variation';
                  isFirst = false;
                } else {
                  variationType = '$variationType-$variation';
                }
              }

              double? price = item.price;
              Variation? variation;
              stock = item.stock ?? 0;
              for (Variation v in item.variations!) {
                if (v.type == variationType) {
                  price = v.price;
                  variation = v;
                  stock = v.stock;
                  break;
                }
              }

              double? discount = item.discount;
              String? discountType = item.discountType;
              double priceWithDiscount =
                  PriceConverter.convertWithDiscount(
                    price,
                    discount,
                    discountType,
                  )!;
              double priceWithQuantity =
                  priceWithDiscount * itemController.quantity!;
              double addonsCost = 0;
              List<AddOn> addOnIdList = [];
              List<AddOns> addOnsList = [];
              for (int index = 0; index < item.addOns!.length; index++) {
                if (itemController.addOnActiveList[index]) {
                  addonsCost =
                      addonsCost +
                      (item.addOns![index].price! *
                          itemController.addOnQtyList[index]!);
                  addOnIdList.add(
                    AddOn(
                      id: item.addOns![index].id,
                      quantity: itemController.addOnQtyList[index],
                    ),
                  );
                  addOnsList.add(item.addOns![index]);
                }
              }

              cartModel = CartModel(
                null,
                price,
                priceWithDiscount,
                variation != null ? [variation] : [],
                [],
                (price! -
                    PriceConverter.convertWithDiscount(
                      price,
                      discount,
                      discountType,
                    )!),
                itemController.quantity,
                addOnIdList,
                addOnsList,
                item.availableDateStarts != null,
                stock,
                item,
                item.quantityLimit,
              );

              List<int?> listOfAddOnId = _getSelectedAddonIds(
                addOnIdList: addOnIdList,
              );
              List<int?> listOfAddOnQty = _getSelectedAddonQtnList(
                addOnIdList: addOnIdList,
              );

              cart = OnlineCart(
                cartId,
                widget.itemId,
                null,
                priceWithDiscount.toString(),
                '',
                variation != null ? [variation] : [],
                null,
                itemController.cartIndex != -1 &&
                        itemController.cartIndex <
                            cartController.cartList.length
                    ? cartController.cartList[itemController.cartIndex].quantity
                    : itemController.quantity,
                listOfAddOnId,
                addOnsList,
                listOfAddOnQty,
                'Item',
              );
              priceWithAddons =
                  priceWithQuantity +
                  (Get.find<SplashController>()
                          .configModel!
                          .moduleConfig!
                          .module!
                          .addOn!
                      ? addonsCost
                      : 0);
            }

            // Update app bar title with item name
            if (item != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _key.currentState?.updateTitle(item.name ?? '');
              });
            }

            return Scaffold(
              key: _globalKey,
              backgroundColor: const Color(0xFFF7F8FA),
              endDrawer: const MenuDrawer(),
              endDrawerEnableOpenDragGesture: false,
              appBar:
                  ResponsiveHelper.isDesktop(context)
                      ? const CustomAppBar(title: '')
                      : DetailsAppBarWidget(key: _key),

              body: SafeArea(
                child:
                    (item != null)
                        ? ResponsiveHelper.isDesktop(context)
                            ? DetailsWebViewWidget(
                              cartModel: cartModel,
                              stock: stock,
                              priceWithAddOns: priceWithAddons,
                              cart: cart,
                            )
                            : Column(
                              children: [
                                // Scrollable content
                                Expanded(
                                  child: Stack(
                                    children: [
                                      SingleChildScrollView(
                                        physics: const BouncingScrollPhysics(),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                        // Product image
                                        RepaintBoundary(
                                          key: _productImageKey,
                                          child: ItemImageViewWidget(
                                            item: item,
                                            isCampaign: widget.isCampaign ?? false,
                                            inStock: (Get.find<SplashController>()
                                                    .configModel!
                                                    .moduleConfig!
                                                    .module!
                                                    .stock! &&
                                                stock! <= 0),
                                          ),
                                        ),

                                        // Product info: in stock, name, weight, price
                                        ItemTitleViewWidget(
                                          item: item,
                                          inStorePage: widget.inStorePage,
                                          isCampaign: item.availableDateStarts != null,
                                          inStock: (Get.find<SplashController>()
                                                  .configModel!
                                                  .moduleConfig!
                                                  .module!
                                                  .stock! &&
                                              stock! <= 0),
                                        ),

                                        const SizedBox(height: 6),

                                        // Variation section - compact themed list with prices
                                        if (item.choiceOptions!.isNotEmpty)
                                          ...item.choiceOptions!.asMap().entries.map((entry) {
                                            final index = entry.key;
                                            final choice = entry.value;
                                            // Find the cheapest variation price for "Save X!" calculation
                                            double? cheapestPrice;
                                            if (item.variations!.isNotEmpty) {
                                              for (var v in item.variations!) {
                                                if (cheapestPrice == null || (v.price != null && v.price! < cheapestPrice)) {
                                                  cheapestPrice = v.price;
                                                }
                                              }
                                            }
                                            return Container(
                                              margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(18),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withValues(alpha: 0.04),
                                                    blurRadius: 12,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  // Header
                                                  Padding(
                                                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                                                    child: Row(
                                                      children: [
                                                        Text(
                                                          choice.title!,
                                                          style: robotoBold.copyWith(
                                                            fontSize: 14,
                                                            color: const Color(0xFF1A1A2E),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Text(
                                                          '• ${'select'.tr} 1',
                                                          style: robotoRegular.copyWith(
                                                            fontSize: 11,
                                                            color: Colors.grey.shade400,
                                                          ),
                                                        ),
                                                        const Spacer(),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: Theme.of(context).secondaryHeaderColor.withValues(alpha: 0.15),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            'required'.tr,
                                                            style: robotoMedium.copyWith(
                                                              fontSize: 10,
                                                              color: Theme.of(context).primaryColor,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Divider(height: 1, color: Colors.grey.shade50),
                                                  // Options with prices
                                                  ...choice.options!.asMap().entries.map((optEntry) {
                                                    final i = optEntry.key;
                                                    final optionName = optEntry.value.trim();
                                                    final bool isSelected = itemController.variationIndex![index] == i;

                                                    // Find price for this option
                                                    double? optionPrice;
                                                    final optionKey = optionName.replaceAll(' ', '');
                                                    for (var v in item.variations!) {
                                                      if (v.type != null && v.type!.contains(optionKey)) {
                                                        optionPrice = v.price;
                                                        break;
                                                      }
                                                    }

                                                    // Calculate discount with item discount
                                                    double? displayPrice = optionPrice != null
                                                        ? PriceConverter.convertWithDiscount(optionPrice, item.discount, item.discountType)
                                                        : null;

                                                    return InkWell(
                                                      onTap: () => itemController.setCartVariationIndex(index, i, item),
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                                        margin: isSelected ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2) : EdgeInsets.zero,
                                                        decoration: BoxDecoration(
                                                          color: isSelected
                                                              ? Theme.of(context).secondaryHeaderColor.withValues(alpha: 0.12)
                                                              : Colors.transparent,
                                                          borderRadius: isSelected ? BorderRadius.circular(12) : null,
                                                        ),
                                                        child: Row(
                                                          children: [
                                                            // Option name
                                                            Expanded(
                                                              child: Text(
                                                                optionName,
                                                                style: (isSelected ? robotoBold : robotoRegular).copyWith(
                                                                  fontSize: 13,
                                                                  color: isSelected
                                                                      ? Theme.of(context).primaryColor
                                                                      : const Color(0xFF1A1A2E),
                                                                ),
                                                              ),
                                                            ),
                                                            // Price
                                                            if (displayPrice != null)
                                                              Padding(
                                                                padding: const EdgeInsets.only(right: 10),
                                                                child: Text(
                                                                  PriceConverter.convertPrice(displayPrice),
                                                                  style: robotoMedium.copyWith(
                                                                    fontSize: 12,
                                                                    color: isSelected
                                                                        ? Theme.of(context).primaryColor
                                                                        : Colors.grey.shade600,
                                                                  ),
                                                                  textDirection: TextDirection.ltr,
                                                                ),
                                                              ),
                                                            // Radio
                                                            Container(
                                                              width: 22,
                                                              height: 22,
                                                              decoration: BoxDecoration(
                                                                shape: BoxShape.circle,
                                                                border: Border.all(
                                                                  color: isSelected
                                                                      ? Theme.of(context).secondaryHeaderColor
                                                                      : Colors.grey.shade200,
                                                                  width: 2,
                                                                ),
                                                              ),
                                                              child: isSelected
                                                                  ? Center(
                                                                      child: Container(
                                                                        width: 10,
                                                                        height: 10,
                                                                        decoration: BoxDecoration(
                                                                          shape: BoxShape.circle,
                                                                          color: Theme.of(context).secondaryHeaderColor,
                                                                        ),
                                                                      ),
                                                                    )
                                                                  : null,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    );
                                                  }),
                                                ],
                                              ),
                                            );
                                          }),

                                        // Prescription required
                                        if (item.isPrescriptionRequired!)
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 8,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context).colorScheme.error.withValues(alpha: 0.05),
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: Theme.of(context).colorScheme.error.withValues(alpha: 0.12),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Icon(
                                                      Icons.medical_services_outlined,
                                                      size: 16,
                                                      color: Theme.of(context).colorScheme.error,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Text(
                                                      'prescription_required'.tr,
                                                      style: robotoMedium.copyWith(
                                                        fontSize: Dimensions.fontSizeSmall,
                                                        color: Theme.of(context).colorScheme.error,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),

                                        const SizedBox(height: 4),

                                        // Nutrition & Allergies
                                        if ((item.nutritionsName != null && item.nutritionsName!.isNotEmpty) ||
                                            (item.allergiesName != null && item.allergiesName!.isNotEmpty))
                                          _buildNutritionAllergySection(item),

                                        // Suggested items
                                        _buildSuggestedItems(itemController, item),

                                        const SizedBox(height: 80),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Sticky bottom bar - qty selector + checkout
                                _buildBottomBar(
                                  context: context,
                                  item: item,
                                  stock: stock,
                                  cartModel: cartModel,
                                  cart: cart,
                                  cartController: cartController,
                                  itemController: itemController,
                                  priceWithAddons: priceWithAddons,
                                ),
                              ],
                            )
                        : const Center(
                            child: CircularProgressIndicator(),
                          ),
              ),
            );
          },
        );
      },
    );
  }


  Widget _buildNutritionAllergySection(Item item) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.nutritionsName != null && item.nutritionsName!.isNotEmpty) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Theme.of(context).secondaryHeaderColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.eco_outlined, size: 16, color: Theme.of(context).primaryColor),
                ),
                const SizedBox(width: 10),
                Text(
                  'nutrition_details'.tr,
                  style: robotoBold.copyWith(fontSize: 14, color: const Color(0xFF1A1A2E)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: List.generate(
                item.nutritionsName!.length,
                (index) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    item.nutritionsName![index],
                    style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).primaryColor),
                  ),
                ),
              ),
            ),
          ],
          if (item.nutritionsName != null && item.nutritionsName!.isNotEmpty &&
              item.allergiesName != null && item.allergiesName!.isNotEmpty) ...
            [
              const SizedBox(height: 6),
              Divider(color: Colors.grey.shade100, height: 1),
              const SizedBox(height: 10),
            ],
          if (item.allergiesName != null && item.allergiesName!.isNotEmpty) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.warning_amber_rounded, size: 16, color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(width: 10),
                Text(
                  'allergic_ingredients'.tr,
                  style: robotoBold.copyWith(fontSize: 14, color: Theme.of(context).colorScheme.error),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: List.generate(
                item.allergiesName!.length,
                (index) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    item.allergiesName![index],
                    style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSuggestedItems(ItemController itemController, Item currentItem) {
    final List<Item>? recommended = itemController.recommendedItemList;
    if (recommended == null || recommended.isEmpty) return const SizedBox.shrink();

    // Smart filtering: prioritize same category/subcategory, then same store
    final currentCategoryIds = currentItem.categoryIds?.map((c) => c.id).toSet() ?? {};
    final currentCategoryId = currentItem.categoryId;

    final List<Item> filtered = recommended.where((i) => i.id != currentItem.id).toList();

    // Score items by relevance
    filtered.sort((a, b) {
      int scoreA = 0, scoreB = 0;

      // Same store = +3
      if (a.storeId == currentItem.storeId) scoreA += 3;
      if (b.storeId == currentItem.storeId) scoreB += 3;

      // Same primary category = +2
      if (a.categoryId == currentCategoryId && currentCategoryId != null) scoreA += 2;
      if (b.categoryId == currentCategoryId && currentCategoryId != null) scoreB += 2;

      // Shared subcategory = +1 per match
      final aCatIds = a.categoryIds?.map((c) => c.id).toSet() ?? {};
      final bCatIds = b.categoryIds?.map((c) => c.id).toSet() ?? {};
      scoreA += aCatIds.intersection(currentCategoryIds).length;
      scoreB += bCatIds.intersection(currentCategoryIds).length;

      return scoreB.compareTo(scoreA);
    });

    final suggestions = filtered.take(10).toList();
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Divider(color: Colors.grey.shade100, height: 1),
        ),
        const SizedBox(height: 16),

        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Theme.of(context).secondaryHeaderColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.shopping_basket_rounded, size: 16, color: Theme.of(context).primaryColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Frequently Bought Together',
                  style: robotoBold.copyWith(
                    fontSize: 15,
                    color: const Color(0xFF1A1A2E),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Horizontal scrollable list - compact cards
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: suggestions.length,
            itemBuilder: (context, index) {
              final item = suggestions[index];
              final double? discount = item.discount;
              final String? discountType = item.discountType;
              final bool hasVariations = item.choiceOptions != null && item.choiceOptions!.isNotEmpty;

              return GestureDetector(
                onTap: () => Get.find<ItemController>().navigateToItemPage(item, context),
                child: Container(
                  width: 135,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image - clean white bg
                      Expanded(
                        flex: 3,
                        child: Stack(
                          children: [
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAFAFA),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                ),
                                child: CustomImage(
                                  image: '${item.imageFullUrl}',
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                              ),
                            ),
                            // Discount chip
                            if (discount != null && discount > 0)
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.error,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    discountType == 'percent'
                                        ? '${discount.toStringAsFixed(0)}%'
                                        : '-${PriceConverter.convertPrice(discount)}',
                                    style: robotoBold.copyWith(
                                      fontSize: 10,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Info + ADD button
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Name
                              Text(
                                item.name ?? '',
                                style: robotoMedium.copyWith(
                                  fontSize: 11,
                                  color: const Color(0xFF1A1A2E),
                                  height: 1.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              // Price + ADD row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      PriceConverter.convertPrice(
                                        Get.find<ItemController>().getStartingPrice(item),
                                        discount: discount,
                                        discountType: discountType,
                                      ),
                                      style: robotoBold.copyWith(
                                        fontSize: 12,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                      textDirection: TextDirection.ltr,
                                      maxLines: 1,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      if (hasVariations) {
                                        Get.find<ItemController>().navigateToItemPage(item, context);
                                      } else {
                                        final double discountedPrice = PriceConverter.convertWithDiscount(
                                          item.price, discount, discountType,
                                        )!;
                                        final onlineCart = OnlineCart(
                                          null,
                                          item.id,
                                          null,
                                          discountedPrice.toString(),
                                          '',
                                          null,
                                          null,
                                          1,
                                          [],
                                          [],
                                          [],
                                          'Item',
                                        );
                                        Get.find<CartController>().addToCartOnline(onlineCart);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).secondaryHeaderColor,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'ADD',
                                            style: robotoBold.copyWith(
                                              fontSize: 10,
                                              color: Theme.of(context).primaryColor,
                                            ),
                                          ),
                                          const SizedBox(width: 2),
                                          Icon(
                                            Icons.add,
                                            size: 10,
                                            color: Theme.of(context).primaryColor,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
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

        // "Add all items" bundle button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Builder(
            builder: (context) {
              // Get IDs of items already in cart
              final cartController = Get.find<CartController>();
              final Set<int> cartItemIds = cartController.cartList
                  .map((c) => c.item?.id)
                  .whereType<int>()
                  .toSet();

              // Calculate total bundle price — skip items already in cart or with variations
              double bundleTotal = 0;
              int addableCount = 0;
              for (final item in suggestions) {
                final hasVars = item.choiceOptions != null && item.choiceOptions!.isNotEmpty;
                if (!hasVars && !cartItemIds.contains(item.id)) {
                  final price = PriceConverter.convertWithDiscount(
                    item.price, item.discount, item.discountType,
                  ) ?? 0;
                  bundleTotal += price;
                  addableCount++;
                }
              }
              if (addableCount < 2) return const SizedBox.shrink();
              return GestureDetector(
                onTap: () {
                  for (final item in suggestions) {
                    final hasVars = item.choiceOptions != null && item.choiceOptions!.isNotEmpty;
                    if (!hasVars && !cartItemIds.contains(item.id)) {
                      final discountedPrice = PriceConverter.convertWithDiscount(
                        item.price, item.discount, item.discountType,
                      )!;
                      final onlineCart = OnlineCart(
                        null, item.id, null,
                        discountedPrice.toString(), '',
                        null, null, 1, [], [], [], 'Item',
                      );
                      cartController.addToCartOnline(onlineCart);
                    }
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).secondaryHeaderColor.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_shopping_cart_rounded, size: 16,
                        color: Theme.of(context).primaryColor),
                      const SizedBox(width: 6),
                      Text(
                        'Add all $addableCount items',
                        style: robotoMedium.copyWith(
                          fontSize: 12,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        PriceConverter.convertPrice(bundleTotal),
                        style: robotoMedium.copyWith(
                          fontSize: 12,
                          color: Theme.of(context).primaryColor,
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
    );
  }

  Widget _buildBottomBar({
    required BuildContext context,
    required Item item,
    required int? stock,
    required CartModel? cartModel,
    required OnlineCart? cart,
    required CartController cartController,
    required ItemController itemController,
    required double priceWithAddons,
  }) {
    final bool isOutOfStock = Get.find<SplashController>()
            .configModel!
            .moduleConfig!
            .module!
            .stock! &&
        stock! <= 0;
    final bool isInCart = itemController.cartIndex != -1;

    // Get current quantity
    final int currentQty = isInCart && itemController.cartIndex < cartController.cartList.length
        ? cartController.cartList[itemController.cartIndex].quantity ?? 1
        : itemController.quantity ?? 1;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: isOutOfStock
            ? Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Container(
                  key: _addToCartButtonKey,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.remove_shopping_cart_outlined, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'out_of_stock'.tr,
                        style: robotoBold.copyWith(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Discount savings banner - only show if savings >= 3
                  if (isInCart && item.discount != null && item.discount! > 0) ...[
                    Builder(
                      builder: (context) {
                        final double totalSavings = (item.price! - PriceConverter.convertWithDiscount(item.price, item.discount, item.discountType)!) * currentQty;
                        if (totalSavings < 3) return const SizedBox.shrink();
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).secondaryHeaderColor.withValues(alpha: 0.12),
                            border: Border(
                              bottom: BorderSide(
                                color: Theme.of(context).secondaryHeaderColor.withValues(alpha: 0.2),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.local_offer_rounded, size: 16, color: Theme.of(context).primaryColor),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${'you_are_saving'.tr.isNotEmpty ? 'you_are_saving'.tr : 'You\'re saving'} ${PriceConverter.convertPrice(totalSavings)}',
                                  style: robotoMedium.copyWith(
                                    fontSize: 12,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  textDirection: TextDirection.ltr,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],

                  // XP gain info
                  if (Get.find<SplashController>().configModel!.loyaltyPointStatus == 1 &&
                      Get.find<SplashController>().configModel!.loyaltyPointItemPurchasePoint != null &&
                      Get.find<SplashController>().configModel!.loyaltyPointItemPurchasePoint! > 0)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        border: Border(
                          bottom: BorderSide(color: Colors.amber.shade100),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Text('⭐', style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 6),
                          Text(
                            '${'earn'.tr.isNotEmpty ? 'earn'.tr : 'Earn'} ${(priceWithAddons * Get.find<SplashController>().configModel!.loyaltyPointItemPurchasePoint! / 100).toStringAsFixed(0)} ${'points'.tr.isNotEmpty ? 'points'.tr : 'points'} ${'with_this_order'.tr.isNotEmpty ? 'with_this_order'.tr : 'with this order'}',
                            style: robotoMedium.copyWith(
                              fontSize: 12,
                              color: const Color(0xFFF57C00),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Subtotal + action row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: isInCart
                        // IN CART: subtotal + counter + checkout
                        ? Column(
                            children: [
                              // Subtotal row
                            
                              // Counter + Checkout row
                              Row(
                                children: [
                                  // Quantity selector - pill style
                                  Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF5F5F7),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Delete (qty=1) or Minus (qty>1)
                                        GestureDetector(
                                          onTap: cartController.isLoading
                                              ? null
                                              : () {
                                                  if (currentQty <= 1) {
                                                    cartController.removeFromCart(
                                                      itemController.cartIndex,
                                                      item: item,
                                                    );
                                                  } else {
                                                    cartController.setQuantity(
                                                      false,
                                                      itemController.cartIndex,
                                                      stock,
                                                      cartController.cartList[itemController.cartIndex].quantity,
                                                    );
                                                  }
                                                },
                                          child: Container(
                                            padding: const EdgeInsets.all(10),
                                            margin: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(12),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.06),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 1),
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              currentQty <= 1 ? Icons.delete_outline_rounded : Icons.remove_rounded,
                                              size: 20,
                                              color: currentQty <= 1
                                                  ? Theme.of(context).colorScheme.error
                                                  : Theme.of(context).primaryColor,
                                            ),
                                          ),
                                        ),
                                        // Quantity number
                                        AnimatedSwitcher(
                                          duration: const Duration(milliseconds: 200),
                                          transitionBuilder: (child, animation) {
                                            return ScaleTransition(scale: animation, child: child);
                                          },
                                          child: Container(
                                            key: ValueKey<int>(currentQty),
                                            padding: const EdgeInsets.symmetric(horizontal: 6),
                                            constraints: const BoxConstraints(minWidth: 32),
                                            alignment: Alignment.center,
                                            child: Text(
                                              '$currentQty',
                                              style: robotoBlack.copyWith(
                                                fontSize: 18,
                                                color: const Color(0xFF1A1A2E),
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Plus button
                                        GestureDetector(
                                          onTap: cartController.isLoading
                                              ? null
                                              : () {
                                                  cartController.setQuantity(
                                                    true,
                                                    itemController.cartIndex,
                                                    stock,
                                                    cartController.cartList[itemController.cartIndex].quantityLimit,
                                                  );
                                                },
                                          child: Container(
                                            padding: const EdgeInsets.all(10),
                                            margin: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(12),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.06),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 1),
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              Icons.add_rounded,
                                              size: 20,
                                              color: Theme.of(context).secondaryHeaderColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // View Cart button with price
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: cartController.isLoading
                                          ? null
                                          : () => Get.toNamed(RouteHelper.getCartRoute()),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).secondaryHeaderColor,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Theme.of(context).secondaryHeaderColor.withValues(alpha: 0.35),
                                              blurRadius: 16,
                                              offset: const Offset(0, 6),
                                            ),
                                          ],
                                        ),
                                        child: cartController.isLoading
                                            ? Center(
                                                child: SizedBox(
                                                  height: 22,
                                                  width: 22,
                                                  child: CircularProgressIndicator(
                                                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                                                    strokeWidth: 2.5,
                                                  ),
                                                ),
                                              )
                                            : Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.shopping_cart_outlined,
                                                        color: Theme.of(context).primaryColor,
                                                        size: 20,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        'view_cart'.tr.isNotEmpty ? 'view_cart'.tr : 'View Cart',
                                                        style: robotoBold.copyWith(
                                                          color: Theme.of(context).primaryColor,
                                                          fontSize: 15,
                                                          letterSpacing: 0.3,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Text(
                                                    PriceConverter.convertPrice(priceWithAddons),
                                                    style: robotoBlack.copyWith(
                                                      color: Theme.of(context).primaryColor,
                                                      fontSize: 16,
                                                    ),
                                                    textDirection: TextDirection.ltr,
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        // NOT IN CART: full-width Add To Cart button
                        : GestureDetector(
                            onTap: cartController.isLoading
                                ? null
                                : () => _handleAddToCart(
                                      item: item,
                                      cartModel: cartModel,
                                      cart: cart,
                                      stock: stock,
                                      cartController: cartController,
                                      itemController: itemController,
                                    ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              key: _addToCartButtonKey,
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).secondaryHeaderColor,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context).secondaryHeaderColor.withValues(alpha: 0.35),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: cartController.isLoading
                                  ? Center(
                                      child: SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                                          strokeWidth: 2.5,
                                        ),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add_shopping_cart_rounded,
                                          color: Theme.of(context).primaryColor,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'add_to_cart'.tr,
                                          style: robotoBold.copyWith(
                                            color: Theme.of(context).primaryColor,
                                            fontSize: 15,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  void _handleAddToCart({
    required Item item,
    required CartModel? cartModel,
    required OnlineCart? cart,
    required int? stock,
    required CartController cartController,
    required ItemController itemController,
  }) async {
    final bool canAdd = !Get.find<SplashController>()
            .configModel!
            .moduleConfig!
            .module!
            .stock! ||
        stock! > 0;

    if (!canAdd || cartController.isLoading) return;

    if (item.availableDateStarts != null) {
      Get.toNamed(
        RouteHelper.getCheckoutRoute('campaign'),
        arguments: CheckoutScreen(
          storeId: null,
          fromCart: false,
          cartList: [cartModel],
        ),
      );
    } else {
      if (cartController.existAnotherModuleItem(
        Get.find<SplashController>().module?.id ??
            Get.find<SplashController>().cacheModule?.id,
      )) {
        final splashController = Get.find<SplashController>();
        String currentModuleName = 'another category'.tr;
        if (cartController.cartList.isNotEmpty) {
          final cartModuleId = cartController.cartList.first.item?.moduleId;
          if (cartModuleId != null && splashController.moduleList != null) {
            final cartModule = splashController.moduleList!.firstWhereOrNull(
              (m) => m.id == cartModuleId,
            );
            currentModuleName = cartModule?.moduleName ?? 'another category'.tr;
          }
        }
        final newModuleName = splashController.module?.moduleName ??
            splashController.cacheModule?.moduleName ??
            'this category'.tr;
        Get.dialog(
          CartModuleConflictDialog(
            currentModuleName: currentModuleName,
            newModuleName: newModuleName,
            onClearCart: () {
              Get.back();
              cartController.clearCartOnline().then((success) async {
                if (success) {
                  await cartController.addToCartOnline(cart!);
                  itemController.setExistInCart(item, null);
                }
              });
            },
            onCancel: () => Get.back(),
          ),
          barrierDismissible: false,
        );
      } else if (cartController.existAnotherStoreItem(
        cartModel!.item!.storeId,
        Get.find<SplashController>().module == null
            ? Get.find<SplashController>().cacheModule!.id
            : Get.find<SplashController>().module!.id,
      )) {
        Get.dialog(
          ConfirmationDialog(
            icon: Images.warning,
            title: 'are_you_sure_to_reset'.tr,
            description: Get.find<SplashController>()
                    .configModel!
                    .moduleConfig!
                    .module!
                    .showRestaurantText!
                ? 'if_you_continue'.tr
                : 'if_you_continue_without_another_store'.tr,
            onYesPressed: () {
              Get.back();
              cartController.clearCartOnline().then((success) async {
                if (success) {
                  await cartController.addToCartOnline(cart!);
                  itemController.setExistInCart(item, null);
                }
              });
            },
          ),
          barrierDismissible: false,
        );
      } else {
        if (itemController.cartIndex == -1) {
          await cartController.addToCartOnline(cart!).then((success) {
            if (success) {
              itemController.setExistInCart(item, null);
              _startFlyToCartAnimation(item.imageFullUrl ?? '');
            }
          });
        } else {
          await cartController.updateCartOnline(cart!).then((success) {
            if (success) {
              _startFlyToCartAnimation(item.imageFullUrl ?? '');
            }
          });
        }
      }
    }
  }

  List<int?> _getSelectedAddonIds({required List<AddOn> addOnIdList}) {
    List<int?> listOfAddOnId = [];
    for (var addOn in addOnIdList) {
      listOfAddOnId.add(addOn.id);
    }
    return listOfAddOnId;
  }

  List<int?> _getSelectedAddonQtnList({required List<AddOn> addOnIdList}) {
    List<int?> listOfAddOnQty = [];
    for (var addOn in addOnIdList) {
      listOfAddOnQty.add(addOn.quantity);
    }
    return listOfAddOnQty;
  }

}

class QuantityButton extends StatelessWidget {
  final bool isIncrement;
  final int? quantity;
  final bool isCartWidget;
  final int? stock;
  final bool isExistInCart;
  final int cartIndex;
  final int? quantityLimit;
  final CartController cartController;
  const QuantityButton({
    super.key,
    required this.isIncrement,
    required this.quantity,
    required this.stock,
    required this.isExistInCart,
    required this.cartIndex,
    this.isCartWidget = false,
    this.quantityLimit,
    required this.cartController,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap:
          cartController.isLoading
              ? null
              : () {
                if (isExistInCart) {
                  if (!isIncrement && quantity! > 1) {
                    Get.find<CartController>().setQuantity(
                      false,
                      cartIndex,
                      stock,
                      quantityLimit,
                    );
                  } else if (isIncrement && quantity! > 0) {
                    if (quantity! < stock! ||
                        !Get.find<SplashController>()
                            .configModel!
                            .moduleConfig!
                            .module!
                            .stock!) {
                      Get.find<CartController>().setQuantity(
                        true,
                        cartIndex,
                        stock,
                        quantityLimit,
                      );
                    } else {
                      showCustomSnackBar('out_of_stock'.tr);
                    }
                  }
                } else {
                  if (!isIncrement && quantity! > 1) {
                    Get.find<ItemController>().setQuantity(
                      false,
                      stock,
                      quantityLimit,
                    );
                  } else if (isIncrement && quantity! > 0) {
                    if (quantity! < stock! ||
                        !Get.find<SplashController>()
                            .configModel!
                            .moduleConfig!
                            .module!
                            .stock!) {
                      Get.find<ItemController>().setQuantity(
                        true,
                        stock,
                        quantityLimit,
                      );
                    } else {
                      showCustomSnackBar('out_of_stock'.tr);
                    }
                  }
                }
              },
      child: Container(
        height: 30,
        width: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color:
              (quantity! == 1 && !isIncrement) || cartController.isLoading
                  ? Theme.of(context).disabledColor.withValues(alpha: 0.1)
                  : Theme.of(context).primaryColor,
        ),
        child: Center(
          child: Icon(
            isIncrement ? Icons.add : Icons.remove,
            color:
                isIncrement
                    ? Colors.white
                    : quantity! == 1
                    ? Theme.of(context).disabledColor
                    : Colors.white,
            size: isCartWidget ? 26 : 20,
          ),
        ),
      ),
    );
  }
}
