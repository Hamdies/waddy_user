import 'package:waddy_app/theme/light_theme.dart';
import 'package:waddy_app/common/widgets/offer_collar_badge.dart';
import 'package:waddy_app/common/widgets/price_tag.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/features/store/store_navigator.dart';
import 'package:waddy_app/common/widgets/weight_picker_widget.dart';
import 'package:waddy_app/common/widgets/custom_asset_image_widget.dart';
import 'package:waddy_app/common/widgets/custom_tool_tip_widget.dart';
import 'package:waddy_app/common/widgets/item_bottom_sheet_shimmer.dart';
import 'package:waddy_app/features/cart/controllers/cart_controller.dart';
import 'package:waddy_app/features/item/controllers/item_controller.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/favourite/controllers/favourite_controller.dart';
import 'package:waddy_app/features/checkout/domain/models/place_order_body_model.dart';
import 'package:waddy_app/features/cart/domain/models/cart_model.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/helper/auth_helper.dart';
import 'package:waddy_app/helper/date_converter.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/images.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_button.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/custom_snackbar.dart';
import 'package:waddy_app/common/widgets/quantity_stepper.dart';
import 'package:waddy_app/common/widgets/rating_bar.dart';
import 'package:waddy_app/features/checkout/screens/checkout_screen.dart';
import 'package:waddy_app/features/xp/widgets/xp_item_indicator_widget.dart';
import 'package:waddy_app/features/cart/widgets/cart_module_conflict_dialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/item/domain/produce_preference.dart';
import 'package:waddy_app/features/item/widgets/produce_preference_picker.dart';

class ItemBottomSheet extends StatefulWidget {
  final int itemId;
  final bool isCampaign;
  final CartModel? cart;
  final int? cartIndex;
  final bool inStorePage;
  const ItemBottomSheet({
    super.key,
    required this.itemId,
    this.isCampaign = false,
    this.cart,
    this.cartIndex,
    this.inStorePage = false,
  });

  @override
  State<ItemBottomSheet> createState() => _ItemBottomSheetState();
}

class _ItemBottomSheetState extends State<ItemBottomSheet> {
  bool _newVariation = false;

  @override
  void initState() {
    super.initState();

    ItemController itemController = Get.find<ItemController>();
    SplashController splashController = Get.find<SplashController>();

    if (splashController.module == null) {
      if (splashController.cacheModule != null) {
        splashController.setCacheConfigModule(splashController.cacheModule);
      }
    }

    itemController
        .getItemDetails(
          itemId: widget.itemId,
          cart: widget.cart,
          // Opened from a "+": "Add" grows a matching line instead of
          // overwriting it. Editing a cart line keeps replace semantics.
          accumulate: !widget.isCampaign,
        )
        .then((_) {
          _newVariation =
              splashController
                  .getModuleConfig(itemController.item!.moduleType)
                  .newVariation ??
              false;
        });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 550,
      margin: EdgeInsets.only(top: 30),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Dimensions.radiusExtraLarge),
        ),
      ),
      child: GetBuilder<ItemController>(
        builder: (itemController) {
          Item? item = itemController.item;

          if (itemController.item == null) {
            return const ItemBottomSheetShimmer();
          }

          double? startingPrice;
          double? endingPrice;
          if (item!.choiceOptions!.isNotEmpty &&
              item.foodVariations!.isEmpty &&
              !_newVariation) {
            List<double?> priceList = [];
            for (var variation in item.variations!) {
              priceList.add(variation.price);
            }
            priceList.sort((a, b) => a!.compareTo(b!));
            startingPrice = priceList[0];
            if (priceList[0]! < priceList[priceList.length - 1]!) {
              endingPrice = priceList[priceList.length - 1];
            }
          } else {
            startingPrice = item.price;
          }

          double? price = item.price;
          double variationPrice = 0;
          Variation? variation;
          double? initialDiscount = item.discount;
          double? discount = item.discount;
          String? discountType = item.discountType;
          int? stock = item.stock ?? 0;

          if (discountType == 'amount') {
            discount = discount! * itemController.quantity!;
          }

          if (_newVariation) {
            for (int index = 0; index < item.foodVariations!.length; index++) {
              for (
                int i = 0;
                i < item.foodVariations![index].variationValues!.length;
                i++
              ) {
                if (itemController.selectedVariations[index][i]!) {
                  variationPrice +=
                      item
                          .foodVariations![index]
                          .variationValues![i]
                          .optionPrice!;
                }
              }
            }
          } else {
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

            for (Variation variations in item.variations!) {
              if (variations.type == variationType) {
                price = variations.price;
                variation = variations;
                stock = variations.stock;
                break;
              }
            }
          }

          price = price! + variationPrice;
          double priceWithDiscount =
              PriceConverter.convertWithDiscount(
                price,
                discount,
                discountType,
              )!;
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
          priceWithDiscount = priceWithDiscount;
          double? priceWithDiscountAndAddons = priceWithDiscount + addonsCost;
          bool isAvailable = DateConverter.isAvailable(
            item.availableTimeStarts,
            item.availableTimeEnds,
          );

          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: Stack(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: Dimensions.paddingSizeLarge),

                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(
                          left: Dimensions.paddingSizeDefault,
                          bottom: Dimensions.paddingSizeDefault,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(
                                right: Dimensions.paddingSizeDefault,
                                top: Dimensions.paddingSizeDefault,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  //Product
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      InkWell(
                                        onTap:
                                            widget.isCampaign
                                                ? null
                                                : () {
                                                  if (!widget.isCampaign) {
                                                    Get.toNamed(
                                                      RouteHelper.getItemImagesRoute(
                                                        item,
                                                      ),
                                                    );
                                                  }
                                                },
                                        child: Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    Dimensions.radiusSmall,
                                                  ),
                                              child: CustomImage(
                                                image: item.imageFullUrl ?? '',
                                                width: 100,
                                                height: 100,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                            if (ItemPrice.of(
                                              item,
                                              base: startingPrice,
                                            ).onSale)
                                              PositionedDirectional(
                                                top: 6,
                                                start: 6,
                                                child:
                                                    OfferCollarBadge.forItem(
                                                      item,
                                                      base: startingPrice,
                                                      compact: true,
                                                      onPhoto: true,
                                                    )!,
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),

                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.name!,
                                              style: waddyMedium.copyWith(
                                                fontSize:
                                                    Dimensions.fontSizeLarge,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            InkWell(
                                              onTap: () {
                                                if (widget.inStorePage) {
                                                  Get.back();
                                                } else {
                                                  Get.back();
                                                  Get.find<CartController>()
                                                      .forcefullySetModule(
                                                        item.moduleId!,
                                                      );
                                                  StoreNavigator.open(
                                                    Store(
                                                      id: item.storeId,
                                                      moduleId: item.moduleId,
                                                    ),
                                                    page: 'item',
                                                  );
                                                }
                                              },
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                      0,
                                                      5,
                                                      5,
                                                      5,
                                                    ),
                                                child: Text(
                                                  item.storeName ?? '',
                                                  style: waddyRegular.copyWith(
                                                    fontSize:
                                                        Dimensions
                                                            .fontSizeSmall,
                                                    color:
                                                        Theme.of(
                                                          context,
                                                        ).primaryColor,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            !widget.isCampaign
                                                ? RatingBar(
                                                  rating: item.avgRating,
                                                  size: 15,
                                                  ratingCount: item.ratingCount,
                                                )
                                                : const SizedBox(),
                                            // One price: the app's price
                                            // line. A range keeps the text.
                                            if (endingPrice == null)
                                              PriceTag.forItem(
                                                item,
                                                base: startingPrice,
                                                size: PriceTagSize.large,
                                              )
                                            else ...[
                                              Text(
                                                '${PriceConverter.convertPrice(startingPrice, discount: initialDiscount, discountType: discountType)}'
                                                ' - ${PriceConverter.convertPrice(endingPrice, discount: initialDiscount, discountType: discountType)}',
                                                style: waddyMedium.copyWith(
                                                  fontSize:
                                                      Dimensions.fontSizeLarge,
                                                ),
                                                textDirection:
                                                    TextDirection.ltr,
                                              ),
                                              price > priceWithDiscount
                                                  ? Text(
                                                    '${PriceConverter.convertPrice(startingPrice)}'
                                                    ' - ${PriceConverter.convertPrice(endingPrice)}',
                                                    textDirection:
                                                        TextDirection.ltr,
                                                    style: waddyMedium.copyWith(
                                                      color:
                                                          Theme.of(
                                                            context,
                                                          ).disabledColor,
                                                      decoration:
                                                          TextDecoration
                                                              .lineThrough,
                                                    ),
                                                  )
                                                  : const SizedBox(),
                                            ],
                                          ],
                                        ),
                                      ),

                                      Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          widget.isCampaign
                                              ? const SizedBox(height: 25)
                                              : GetBuilder<FavouriteController>(
                                                builder: (wishList) {
                                                  return InkWell(
                                                    onTap: () {
                                                      if (AuthHelper.isLoggedIn()) {
                                                        wishList.wishItemIdList
                                                                .contains(
                                                                  item.id,
                                                                )
                                                            ? wishList
                                                                .removeFromFavouriteList(
                                                                  item.id,
                                                                  false,
                                                                  getXSnackBar:
                                                                      true,
                                                                )
                                                            : wishList
                                                                .addToFavouriteList(
                                                                  item,
                                                                  null,
                                                                  false,
                                                                  getXSnackBar:
                                                                      true,
                                                                );
                                                      } else {
                                                        showCustomSnackBar(
                                                          'you_are_not_logged_in'
                                                              .tr,
                                                          getXSnackBar: true,
                                                        );
                                                      }
                                                    },
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              Dimensions
                                                                  .radiusDefault,
                                                            ),
                                                        color: Theme.of(context)
                                                            .primaryColor
                                                            .withValues(
                                                              alpha: 0.05,
                                                            ),
                                                      ),
                                                      padding:
                                                          const EdgeInsets.all(
                                                            Dimensions
                                                                .paddingSizeSmall,
                                                          ),
                                                      margin: const EdgeInsets.only(
                                                        top:
                                                            Dimensions
                                                                .paddingSizeSmall,
                                                      ),
                                                      child: Icon(
                                                        wishList.wishItemIdList
                                                                .contains(
                                                                  item.id,
                                                                )
                                                            ? Icons.favorite
                                                            : Icons
                                                                .favorite_border,
                                                        color:
                                                            wishList.wishItemIdList
                                                                    .contains(
                                                                      item.id,
                                                                    )
                                                                ? Theme.of(
                                                                  context,
                                                                ).primaryColor
                                                                : Theme.of(
                                                                  context,
                                                                ).disabledColor,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                          const SizedBox(
                                            height:
                                                Dimensions.paddingSizeDefault,
                                          ),

                                          item.isStoreHalalActive! &&
                                                  item.isHalalItem!
                                              ? Padding(
                                                padding: const EdgeInsets.symmetric(
                                                  vertical:
                                                      Dimensions
                                                          .paddingSizeSmall,
                                                  horizontal:
                                                      Dimensions
                                                          .paddingSizeExtraSmall,
                                                ),
                                                child: CustomToolTip(
                                                  message:
                                                      'this_is_a_halal_food'.tr,
                                                  preferredDirection:
                                                      AxisDirection.up,
                                                  child:
                                                      const CustomAssetImageWidget(
                                                        Images.halalTag,
                                                        height: 35,
                                                        width: 35,
                                                      ),
                                                ),
                                              )
                                              : const SizedBox(),
                                        ],
                                      ),
                                    ],
                                  ),

                                  const SizedBox(
                                    height: Dimensions.paddingSizeLarge,
                                  ),

                                  (item.description != null &&
                                          item.description!.isNotEmpty)
                                      ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'description'.tr,
                                                style: waddyBold.copyWith(
                                                  fontSize:
                                                      Dimensions.fontSizeLarge,
                                                ),
                                              ),

                                              ((Get.find<SplashController>()
                                                              .configModel
                                                              .moduleConfig!
                                                              .module!
                                                              .unit! &&
                                                          item.unitType !=
                                                              null) ||
                                                      (Get.find<
                                                                SplashController
                                                              >()
                                                              .configModel
                                                              .moduleConfig!
                                                              .module!
                                                              .vegNonVeg! &&
                                                          Get.find<
                                                                SplashController
                                                              >()
                                                              .configModel
                                                              .toggleVegNonVeg!))
                                                  ? Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      vertical:
                                                          Dimensions
                                                              .paddingSizeExtraSmall,
                                                      horizontal:
                                                          Dimensions
                                                              .paddingSizeSmall,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            Dimensions
                                                                .radiusExtraLarge,
                                                          ),
                                                      color:
                                                          Theme.of(
                                                            context,
                                                          ).cardColor,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Theme.of(
                                                                context,
                                                              ).primaryColor
                                                              .withValues(
                                                                alpha: 0.2,
                                                              ),
                                                          blurRadius: 5,
                                                        ),
                                                      ],
                                                    ),
                                                    child:
                                                        Get.find<
                                                                  SplashController
                                                                >()
                                                                .configModel
                                                                .moduleConfig!
                                                                .module!
                                                                .unit!
                                                            ? Text(
                                                              item.unitType ??
                                                                  '',
                                                              style: waddyMedium.copyWith(
                                                                fontSize:
                                                                    Dimensions
                                                                        .fontSizeExtraSmall,
                                                                color:
                                                                    Theme.of(
                                                                      context,
                                                                    ).primaryColor,
                                                              ),
                                                            )
                                                            : Row(
                                                              children: [
                                                                Image.asset(
                                                                  item.veg == 1
                                                                      ? Images
                                                                          .vegLogo
                                                                      : Images
                                                                          .nonVegLogo,
                                                                  height: 20,
                                                                  width: 20,
                                                                ),
                                                                const SizedBox(
                                                                  width:
                                                                      Dimensions
                                                                          .paddingSizeSmall,
                                                                ),

                                                                Text(
                                                                  item.veg == 1
                                                                      ? 'veg'.tr
                                                                      : 'non_veg'
                                                                          .tr,
                                                                  style: waddyMedium
                                                                      .copyWith(
                                                                        fontSize:
                                                                            Dimensions.fontSizeDefault,
                                                                      ),
                                                                ),
                                                              ],
                                                            ),
                                                  )
                                                  : const SizedBox(),
                                            ],
                                          ),
                                          const SizedBox(
                                            height:
                                                Dimensions
                                                    .paddingSizeExtraSmall,
                                          ),

                                          Text(
                                            item.description!,
                                            style: waddyRegular.copyWith(
                                              color: Theme.of(context)
                                                  .textTheme
                                                  .bodyLarge!
                                                  .color
                                                  ?.withValues(alpha: 0.5),
                                            ),
                                          ),
                                          const SizedBox(
                                            height: Dimensions.paddingSizeLarge,
                                          ),
                                        ],
                                      )
                                      : const SizedBox(),

                                  (item.nutritionsName != null &&
                                          item.nutritionsName!.isNotEmpty)
                                      ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'nutrition_details'.tr,
                                            style: waddyBold.copyWith(
                                              fontSize:
                                                  Dimensions.fontSizeLarge,
                                            ),
                                          ),
                                          const SizedBox(
                                            height:
                                                Dimensions
                                                    .paddingSizeExtraSmall,
                                          ),

                                          Wrap(
                                            children: List.generate(
                                              item.nutritionsName!.length,
                                              (index) {
                                                return Text(
                                                  '${item.nutritionsName![index]}${item.nutritionsName!.length - 1 == index ? '.' : ', '}',
                                                  style: waddyRegular.copyWith(
                                                    color: Theme.of(context)
                                                        .textTheme
                                                        .bodyLarge!
                                                        .color
                                                        ?.withValues(
                                                          alpha: 0.5,
                                                        ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          const SizedBox(
                                            height: Dimensions.paddingSizeLarge,
                                          ),
                                        ],
                                      )
                                      : const SizedBox(),

                                  (item.allergiesName != null &&
                                          item.allergiesName!.isNotEmpty)
                                      ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'allergic_ingredients'.tr,
                                            style: waddyBold.copyWith(
                                              fontSize:
                                                  Dimensions.fontSizeLarge,
                                            ),
                                          ),
                                          const SizedBox(
                                            height:
                                                Dimensions
                                                    .paddingSizeExtraSmall,
                                          ),

                                          Wrap(
                                            children: List.generate(
                                              item.allergiesName!.length,
                                              (index) {
                                                return Text(
                                                  '${item.allergiesName![index]}${item.allergiesName!.length - 1 == index ? '.' : ', '}',
                                                  style: waddyRegular.copyWith(
                                                    color: Theme.of(context)
                                                        .textTheme
                                                        .bodyLarge!
                                                        .color
                                                        ?.withValues(
                                                          alpha: 0.5,
                                                        ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          const SizedBox(
                                            height: Dimensions.paddingSizeLarge,
                                          ),
                                        ],
                                      )
                                      : const SizedBox(),

                                  (item.genericName != null &&
                                          item.genericName!.isNotEmpty)
                                      ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'generic_name'.tr,
                                            style: waddyBold.copyWith(
                                              fontSize:
                                                  Dimensions.fontSizeLarge,
                                            ),
                                          ),
                                          const SizedBox(
                                            height:
                                                Dimensions
                                                    .paddingSizeExtraSmall,
                                          ),

                                          Wrap(
                                            children: List.generate(
                                              item.genericName!.length,
                                              (index) {
                                                return Text(
                                                  '${item.genericName![index]}${item.genericName!.length - 1 == index ? '.' : ', '}',
                                                  style: waddyRegular.copyWith(
                                                    color: Theme.of(context)
                                                        .textTheme
                                                        .bodyLarge!
                                                        .color
                                                        ?.withValues(
                                                          alpha: 0.5,
                                                        ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          const SizedBox(
                                            height: Dimensions.paddingSizeLarge,
                                          ),
                                        ],
                                      )
                                      : const SizedBox(),

                                  // Produce question (ripeness / use), required
                                  if (ProducePreference.asks(item.prepOption))
                                    ProducePreferencePicker(
                                      option: item.prepOption!,
                                      selected: itemController.preference,
                                      onSelect:
                                          (code) => itemController
                                              .setPreference(code, item),
                                      margin: const EdgeInsets.only(
                                        bottom: Dimensions.paddingSizeLarge,
                                      ),
                                    ),

                                  // Variation
                                  _newVariation
                                      ? NewVariationView(
                                        item: item,
                                        itemController: itemController,
                                        discount: initialDiscount,
                                        discountType: discountType,
                                        showOriginalPrice:
                                            (price > priceWithDiscount) &&
                                            (discountType == 'percent'),
                                      )
                                      : VariationView(
                                        item: item,
                                        itemController: itemController,
                                      ),
                                  SizedBox(
                                    height:
                                        (Get.find<SplashController>()
                                                    .configModel
                                                    .moduleConfig!
                                                    .module!
                                                    .addOn! &&
                                                item.addOns!.isNotEmpty)
                                            ? Dimensions.paddingSizeLarge
                                            : 0,
                                  ),

                                  // Addons
                                  (Get.find<SplashController>()
                                              .configModel
                                              .moduleConfig!
                                              .module!
                                              .addOn! &&
                                          item.addOns!.isNotEmpty)
                                      ? AddonView(
                                        itemController: itemController,
                                        item: item,
                                      )
                                      : const SizedBox(),

                                  isAvailable
                                      ? const SizedBox()
                                      : Container(
                                        alignment: Alignment.center,
                                        padding: const EdgeInsets.all(
                                          Dimensions.paddingSizeSmall,
                                        ),
                                        margin: const EdgeInsets.only(
                                          bottom: Dimensions.paddingSizeSmall,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            Dimensions.radiusSmall,
                                          ),
                                          color: Theme.of(
                                            context,
                                          ).primaryColor.withValues(alpha: 0.1),
                                        ),
                                        child: Column(
                                          children: [
                                            Text(
                                              'not_available_now'.tr,
                                              style: waddyMedium.copyWith(
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).primaryColor,
                                                fontSize:
                                                    Dimensions.fontSizeLarge,
                                              ),
                                            ),
                                            Text(
                                              '${'available_will_be'.tr} ${DateConverter.convertTimeToTime(item.availableTimeStarts!)} '
                                              '- ${DateConverter.convertTimeToTime(item.availableTimeEnds!)}',
                                              style: waddyRegular,
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
                    ),

                    ///Bottom side..
                    (!item.scheduleOrder! && !isAvailable)
                        ? const SizedBox()
                        : Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: const BorderRadius.all(
                              Radius.circular(0),
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 5,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: Dimensions.paddingSizeDefault,
                            vertical: Dimensions.paddingSizeDefault,
                          ),
                          child: Column(
                            children: [
                              Builder(
                                builder: (context) {
                                  double? cost =
                                      PriceConverter.convertWithDiscount(
                                        (price! * itemController.quantity!),
                                        discount,
                                        discountType,
                                      );
                                  double withAddonCost = cost! + addonsCost;
                                  return Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${'total_amount'.tr}:',
                                        style: waddyMedium.copyWith(
                                          fontSize: Dimensions.fontSizeDefault,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                      const SizedBox(
                                        width: Dimensions.paddingSizeExtraSmall,
                                      ),

                                      Row(
                                        children: [
                                          // XP indicator for this item
                                          XpItemIndicatorWidget(
                                            itemPrice: withAddonCost,
                                            quantity: 1,
                                          ),
                                          const SizedBox(
                                            width: Dimensions.paddingSizeSmall,
                                          ),

                                          discount! > 0
                                              ? PriceConverter.convertAnimationPrice(
                                                (price *
                                                        itemController
                                                            .quantity!) +
                                                    addonsCost,
                                                textStyle: waddyMedium.copyWith(
                                                  color:
                                                      Theme.of(
                                                        context,
                                                      ).disabledColor,
                                                  fontSize:
                                                      Dimensions.fontSizeSmall,
                                                  decoration:
                                                      TextDecoration
                                                          .lineThrough,
                                                  decorationColor:
                                                      WaddyColors.error,
                                                  decorationThickness: 2,
                                                ),
                                              )
                                              : const SizedBox(),
                                          const SizedBox(
                                            width:
                                                Dimensions
                                                    .paddingSizeExtraSmall,
                                          ),

                                          PriceConverter.convertAnimationPrice(
                                            withAddonCost,
                                            textStyle: waddyBold.copyWith(
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).primaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(
                                height: Dimensions.paddingSizeSmall,
                              ),

                              SafeArea(
                                child: Row(
                                  children: [
                                    // Quantity before adding: 1 is the
                                    // floor, so no trash — the minus
                                    // disables there instead.
                                    QuantityStepper(
                                      quantity: itemController.quantity ?? 1,
                                      itemName: item.name,
                                      size: QuantityStepperSize.large,
                                      onDecrement:
                                          () => itemController.setQuantity(
                                            false,
                                            stock,
                                            item.quantityLimit,
                                            getxSnackBar: true,
                                          ),
                                      onIncrement:
                                          () => itemController.setQuantity(
                                            true,
                                            stock,
                                            item.quantityLimit,
                                            getxSnackBar: true,
                                          ),
                                    ),
                                    const SizedBox(
                                      width: Dimensions.paddingSizeSmall,
                                    ),

                                    Expanded(
                                      child: GetBuilder<CartController>(
                                        builder: (cartController) {
                                          return CustomButton(
                                            width: null,
                                            isLoading: cartController.isLoading,
                                            buttonText:
                                                (Get.find<SplashController>()
                                                            .configModel
                                                            .moduleConfig!
                                                            .module!
                                                            .stock! &&
                                                        stock! <= 0)
                                                    ? 'out_of_stock'.tr
                                                    : widget.isCampaign
                                                    ? 'order_now'.tr
                                                    : widget.cart != null
                                                    ? 'update_in_cart'.tr
                                                    : 'add_to_cart'.tr,
                                            onPressed:
                                                (Get.find<SplashController>()
                                                            .configModel
                                                            .moduleConfig!
                                                            .module!
                                                            .stock! &&
                                                        stock! <= 0)
                                                    ? null
                                                    : () async {
                                                      String? invalid;
                                                      if (_newVariation) {
                                                        for (
                                                          int index = 0;
                                                          index <
                                                              item
                                                                  .foodVariations!
                                                                  .length;
                                                          index++
                                                        ) {
                                                          if (!item
                                                                  .foodVariations![index]
                                                                  .multiSelect! &&
                                                              item
                                                                  .foodVariations![index]
                                                                  .required! &&
                                                              !itemController
                                                                  .selectedVariations[index]
                                                                  .contains(
                                                                    true,
                                                                  )) {
                                                            invalid =
                                                                '${'choose_a_variation_from'.tr} ${item.foodVariations![index].name}';
                                                            break;
                                                          } else if (item
                                                                  .foodVariations![index]
                                                                  .multiSelect! &&
                                                              (item
                                                                      .foodVariations![index]
                                                                      .required! ||
                                                                  itemController
                                                                      .selectedVariations[index]
                                                                      .contains(
                                                                        true,
                                                                      )) &&
                                                              item
                                                                      .foodVariations![index]
                                                                      .min! >
                                                                  itemController
                                                                      .selectedVariationLength(
                                                                        itemController
                                                                            .selectedVariations,
                                                                        index,
                                                                      )) {
                                                            invalid =
                                                                '${'select_minimum'.tr} ${item.foodVariations![index].min} '
                                                                '${'and_up_to'.tr} ${item.foodVariations![index].max} ${'options_from'.tr}'
                                                                ' ${item.foodVariations![index].name} ${'variation'.tr}';
                                                            break;
                                                          }
                                                        }
                                                      }

                                                      if (invalid == null &&
                                                          ProducePreference.asks(
                                                            item.prepOption,
                                                          ) &&
                                                          itemController
                                                                  .preference ==
                                                              null) {
                                                        invalid =
                                                            'choose_prep_${item.prepOption}'
                                                                .tr;
                                                      }

                                                      Get.find<
                                                            SplashController
                                                          >()
                                                          .activateModuleFor(
                                                            item.moduleId,
                                                          );

                                                      if (invalid != null) {
                                                        showCustomSnackBar(
                                                          invalid,
                                                          getXSnackBar: true,
                                                        );
                                                      } else {
                                                        CartModel
                                                        cartModel = CartModel(
                                                          null,
                                                          price,
                                                          priceWithDiscountAndAddons,
                                                          variation != null
                                                              ? [variation]
                                                              : [],
                                                          itemController
                                                              .selectedVariations,
                                                          (price! -
                                                              PriceConverter.convertWithDiscount(
                                                                price,
                                                                discount,
                                                                discountType,
                                                              )!),
                                                          itemController
                                                              .quantity,
                                                          addOnIdList,
                                                          addOnsList,
                                                          widget.isCampaign,
                                                          stock,
                                                          item,
                                                          item.quantityLimit,
                                                          preference:
                                                              itemController
                                                                  .preference,
                                                        );

                                                        List<OrderVariation>
                                                        variations = _getSelectedVariations(
                                                          isFoodVariation:
                                                              Get.find<
                                                                    SplashController
                                                                  >()
                                                                  .getModuleConfig(
                                                                    item.moduleType,
                                                                  )
                                                                  .newVariation!,
                                                          foodVariations:
                                                              item.foodVariations!,
                                                          selectedVariations:
                                                              itemController
                                                                  .selectedVariations,
                                                        );
                                                        List<int?>
                                                        listOfAddOnId =
                                                            _getSelectedAddonIds(
                                                              addOnIdList:
                                                                  addOnIdList,
                                                            );
                                                        List<int?>
                                                        listOfAddOnQty =
                                                            _getSelectedAddonQtnList(
                                                              addOnIdList:
                                                                  addOnIdList,
                                                            );

                                                        OnlineCart
                                                        onlineCart = OnlineCart(
                                                          widget.cart?.id,
                                                          widget.isCampaign
                                                              ? null
                                                              : item.id,
                                                          widget.isCampaign
                                                              ? item.id
                                                              : null,
                                                          priceWithDiscountAndAddons
                                                              .toString(),
                                                          '',
                                                          variation != null
                                                              ? [variation]
                                                              : null,
                                                          Get.find<
                                                                    SplashController
                                                                  >()
                                                                  .getModuleConfig(
                                                                    item.moduleType,
                                                                  )
                                                                  .newVariation!
                                                              ? variations
                                                              : null,
                                                          itemController
                                                              .quantity,
                                                          listOfAddOnId,
                                                          addOnsList,
                                                          listOfAddOnQty,
                                                          'Item',
                                                          preference:
                                                              itemController
                                                                  .preference,
                                                        );

                                                        if (widget.isCampaign) {
                                                          Get.toNamed(
                                                            RouteHelper.getCheckoutRoute(
                                                              'campaign',
                                                            ),
                                                            arguments:
                                                                CheckoutScreen(
                                                                  storeId: null,
                                                                  fromCart:
                                                                      false,
                                                                  cartList: [
                                                                    cartModel,
                                                                  ],
                                                                ),
                                                          );
                                                        } else {
                                                          // First check for different module
                                                          if (Get.find<
                                                                CartController
                                                              >()
                                                              .existAnotherModuleItem(
                                                                Get.find<
                                                                          SplashController
                                                                        >()
                                                                        .module
                                                                        ?.id ??
                                                                    Get.find<
                                                                          SplashController
                                                                        >()
                                                                        .cacheModule
                                                                        ?.id,
                                                              )) {
                                                            // Get module names for the dialog
                                                            final cartController =
                                                                Get.find<
                                                                  CartController
                                                                >();
                                                            final splashController =
                                                                Get.find<
                                                                  SplashController
                                                                >();

                                                            // Get current cart module name
                                                            String
                                                            currentModuleName =
                                                                'another category'
                                                                    .tr;
                                                            if (cartController
                                                                .cartList
                                                                .isNotEmpty) {
                                                              final cartModuleId =
                                                                  cartController
                                                                      .cartList
                                                                      .first
                                                                      .item
                                                                      ?.moduleId;
                                                              if (cartModuleId !=
                                                                      null &&
                                                                  splashController
                                                                          .moduleList !=
                                                                      null) {
                                                                final cartModule = splashController
                                                                    .moduleList!
                                                                    .firstWhereOrNull(
                                                                      (m) =>
                                                                          m.id ==
                                                                          cartModuleId,
                                                                    );
                                                                currentModuleName =
                                                                    cartModule
                                                                        ?.moduleName ??
                                                                    'another category'
                                                                        .tr;
                                                              }
                                                            }

                                                            // Get new module name
                                                            final newModuleName =
                                                                splashController
                                                                    .module
                                                                    ?.moduleName ??
                                                                splashController
                                                                    .cacheModule
                                                                    ?.moduleName ??
                                                                'this category'
                                                                    .tr;

                                                            Get.dialog(
                                                              CartModuleConflictDialog(
                                                                currentModuleName:
                                                                    currentModuleName,
                                                                newModuleName:
                                                                    newModuleName,
                                                                onClearCart: () {
                                                                  Get.back();
                                                                  Get.find<
                                                                        CartController
                                                                      >()
                                                                      .clearCartOnline()
                                                                      .then((
                                                                        success,
                                                                      ) async {
                                                                        if (success) {
                                                                          await Get.find<
                                                                                CartController
                                                                              >()
                                                                              .addToCartOnline(
                                                                                onlineCart,
                                                                                localFallback:
                                                                                    cartModel,
                                                                              );
                                                                          Get.back();
                                                                        }
                                                                      });
                                                                },
                                                                onCancel:
                                                                    () =>
                                                                        Get.back(),
                                                              ),
                                                              barrierDismissible:
                                                                  false,
                                                            );
                                                          } else if (Get.find<
                                                                CartController
                                                              >()
                                                              .existAnotherStoreItem(
                                                                cartModel
                                                                    .item!
                                                                    .storeId,
                                                                Get.find<
                                                                              SplashController
                                                                            >()
                                                                            .module !=
                                                                        null
                                                                    ? Get.find<
                                                                          SplashController
                                                                        >()
                                                                        .module!
                                                                        .id
                                                                    : Get.find<
                                                                          SplashController
                                                                        >()
                                                                        .cacheModule!
                                                                        .id,
                                                              )) {
                                                            Get.dialog(
                                                              CartModuleConflictDialog.forStore(
                                                                newStoreName:
                                                                    cartModel
                                                                        .item!
                                                                        .storeName,
                                                                onClearCart: () {
                                                                  Get.back();
                                                                  Get.find<
                                                                        CartController
                                                                      >()
                                                                      .clearCartOnline()
                                                                      .then((
                                                                        success,
                                                                      ) async {
                                                                        if (success) {
                                                                          await Get.find<
                                                                                CartController
                                                                              >()
                                                                              .addToCartOnline(
                                                                                onlineCart,
                                                                                localFallback:
                                                                                    cartModel,
                                                                              );
                                                                          Get.back();
                                                                          //showCartSnackBar();
                                                                        }
                                                                      });
                                                                },
                                                              ),
                                                              barrierDismissible:
                                                                  false,
                                                            );
                                                          } else {
                                                            final CartController
                                                            cart =
                                                                Get.find<
                                                                  CartController
                                                                >();
                                                            if (widget.cart !=
                                                                null) {
                                                              // Editing a line from the cart: the
                                                              // sheet's quantity replaces it.
                                                              await cart
                                                                  .updateCartOnline(
                                                                    onlineCart,
                                                                    localFallback:
                                                                        cartModel,
                                                                    localIndex:
                                                                        itemController
                                                                            .cartIndex,
                                                                  )
                                                                  .then((
                                                                    success,
                                                                  ) {
                                                                    if (success) {
                                                                      Get.back();
                                                                    }
                                                                  });
                                                            } else {
                                                              // Opened from a "+": the same options
                                                              // and add-ons already in the cart grow
                                                              // that line by the sheet's quantity.
                                                              final int
                                                              line = itemController
                                                                  .identicalLineIndex(
                                                                    item,
                                                                    addOnIds:
                                                                        listOfAddOnId,
                                                                    addOnQtys:
                                                                        listOfAddOnQty,
                                                                  );
                                                              final Future<bool>
                                                              write =
                                                                  line == -1
                                                                      ? cart.addToCartOnline(
                                                                        onlineCart,
                                                                        localFallback:
                                                                            cartModel,
                                                                      )
                                                                      : cart.updateCartOnline(
                                                                        onlineCart.copyWith(
                                                                          cartId:
                                                                              cart.cartList[line].id,
                                                                          quantity:
                                                                              (cart.cartList[line].quantity ??
                                                                                  0) +
                                                                              (itemController.quantity ??
                                                                                  1),
                                                                        ),
                                                                        localIndex:
                                                                            line,
                                                                      );
                                                              await write.then((
                                                                success,
                                                              ) {
                                                                if (success) {
                                                                  Get.back();
                                                                }
                                                              });
                                                            }

                                                            //showCartSnackBar();
                                                          }
                                                        }
                                                      }
                                                    },
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                  ],
                ),

                Positioned(
                  top: 5,
                  right: 10,
                  child: InkWell(
                    onTap: () => Get.back(),
                    child: Container(
                      padding: const EdgeInsets.all(
                        Dimensions.paddingSizeExtraSmall,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.3),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.close, size: 14),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<OrderVariation> _getSelectedVariations({
    required bool isFoodVariation,
    required List<FoodVariation>? foodVariations,
    required List<List<bool?>> selectedVariations,
  }) {
    List<OrderVariation> variations = [];
    if (isFoodVariation) {
      for (int i = 0; i < foodVariations!.length; i++) {
        if (selectedVariations[i].contains(true)) {
          variations.add(
            OrderVariation(
              name: foodVariations[i].name,
              values: OrderVariationValue(label: []),
            ),
          );
          for (int j = 0; j < foodVariations[i].variationValues!.length; j++) {
            if (selectedVariations[i][j]!) {
              variations[variations.length - 1].values!.label!.add(
                foodVariations[i].variationValues![j].level,
              );
            }
          }
        }
      }
    }
    return variations;
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

class AddonView extends StatelessWidget {
  final Item item;
  final ItemController itemController;
  const AddonView({
    super.key,
    required this.item,
    required this.itemController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('addons'.tr, style: waddyMedium),

            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).disabledColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
              ),
              padding: const EdgeInsets.all(Dimensions.paddingSizeExtraSmall),
              child: Text(
                'optional'.tr,
                style: waddyRegular.copyWith(
                  color: Theme.of(context).hintColor,
                  fontSize: Dimensions.fontSizeSmall,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Dimensions.paddingSizeExtraSmall),

        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: item.addOns!.length,
          itemBuilder: (context, index) {
            return InkWell(
              onTap: () {
                if (!itemController.addOnActiveList[index]) {
                  itemController.addAddOn(true, index);
                } else if (itemController.addOnQtyList[index] == 1) {
                  itemController.addAddOn(false, index);
                }
              },
              child: Padding(
                padding: const EdgeInsets.only(
                  bottom: Dimensions.paddingSizeExtraSmall,
                ),
                child: Row(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Checkbox(
                          value: itemController.addOnActiveList[index],
                          activeColor: Theme.of(context).primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              Dimensions.radiusSmall,
                            ),
                          ),
                          onChanged: (bool? newValue) {
                            if (!itemController.addOnActiveList[index]) {
                              itemController.addAddOn(true, index);
                            } else if (itemController.addOnQtyList[index] ==
                                1) {
                              itemController.addAddOn(false, index);
                            }
                          },
                          visualDensity: const VisualDensity(
                            horizontal: -3,
                            vertical: -3,
                          ),
                          side: BorderSide(
                            width: 2,
                            color: Theme.of(context).hintColor,
                          ),
                        ),

                        Text(
                          item.addOns![index].name!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              itemController.addOnActiveList[index]
                                  ? waddyMedium
                                  : waddyRegular.copyWith(
                                    color: Theme.of(context).hintColor,
                                  ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    Text(
                      item.addOns![index].price! > 0
                          ? PriceConverter.convertPrice(
                            item.addOns![index].price,
                          )
                          : 'free'.tr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.ltr,
                      style:
                          itemController.addOnActiveList[index]
                              ? waddyMedium.copyWith(
                                fontSize: Dimensions.fontSizeSmall,
                              )
                              : waddyRegular.copyWith(
                                fontSize: Dimensions.fontSizeSmall,
                                color: Theme.of(context).disabledColor,
                              ),
                    ),

                    itemController.addOnActiveList[index]
                        ? QuantityStepper(
                          quantity: itemController.addOnQtyList[index] ?? 1,
                          itemName: item.addOns![index].name,
                          onDecrement:
                              () =>
                                  itemController.setAddOnQuantity(false, index),
                          // Trash at 1 deselects the add-on.
                          onRemove: () => itemController.addAddOn(false, index),
                          onIncrement:
                              () =>
                                  itemController.setAddOnQuantity(true, index),
                        )
                        : const SizedBox(),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: Dimensions.paddingSizeExtraSmall),
      ],
    );
  }
}

class VariationView extends StatelessWidget {
  final Item? item;
  final ItemController itemController;
  const VariationView({
    super.key,
    required this.item,
    required this.itemController,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: item!.choiceOptions!.length,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        bottom:
            item!.choiceOptions!.isNotEmpty ? Dimensions.paddingSizeLarge : 0,
      ),
      itemBuilder: (context, index) {
        final options = item!.choiceOptions![index].options ?? [];

        if (looksLikeWeightOptions(options)) {
          return WeightPickerWidget(
            item: item,
            itemController: itemController,
            choiceIndex: index,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item!.choiceOptions![index].title!, style: waddyMedium),
            const SizedBox(height: Dimensions.paddingSizeSmall),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                color: Theme.of(context).cardColor,
              ),
              padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: item!.choiceOptions![index].options!.length,
                itemBuilder: (context, i) {
                  return Padding(
                    padding: const EdgeInsets.only(
                      bottom: Dimensions.paddingSizeExtraSmall,
                    ),
                    child: InkWell(
                      onTap: () {
                        itemController.setCartVariationIndex(index, i, item);
                      },
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item!.choiceOptions![index].options![i].trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: waddyRegular,
                            ),
                          ),
                          const SizedBox(width: Dimensions.paddingSizeSmall),
                          Radio<int>(
                            value: i,
                            groupValue: itemController.variationIndex![index],
                            onChanged:
                                (int? value) => itemController
                                    .setCartVariationIndex(index, i, item),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            activeColor: Theme.of(context).primaryColor,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              height:
                  index != item!.choiceOptions!.length - 1
                      ? Dimensions.paddingSizeLarge
                      : 0,
            ),
          ],
        );
      },
    );
  }
}

class NewVariationView extends StatelessWidget {
  final Item? item;
  final ItemController itemController;
  final double? discount;
  final String? discountType;
  final bool showOriginalPrice;
  const NewVariationView({
    super.key,
    required this.item,
    required this.itemController,
    required this.discount,
    required this.discountType,
    required this.showOriginalPrice,
  });

  @override
  Widget build(BuildContext context) {
    return item!.foodVariations != null
        ? ListView.builder(
          shrinkWrap: true,
          itemCount: item!.foodVariations!.length,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.only(
            bottom:
                (item!.foodVariations != null &&
                        item!.foodVariations!.isNotEmpty)
                    ? Dimensions.paddingSizeLarge
                    : 0,
          ),
          itemBuilder: (context, index) {
            int selectedCount = 0;
            if (item!.foodVariations![index].required!) {
              for (var value in itemController.selectedVariations[index]) {
                if (value == true) {
                  selectedCount++;
                }
              }
            }
            return Container(
              padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
              margin: EdgeInsets.only(
                bottom:
                    index != item!.foodVariations!.length - 1
                        ? Dimensions.paddingSizeLarge
                        : 0,
              ),
              decoration: BoxDecoration(
                color:
                    itemController.selectedVariations[index].contains(true)
                        ? Theme.of(context).primaryColor.withValues(alpha: 0.01)
                        : Theme.of(
                          context,
                        ).disabledColor.withValues(alpha: 0.05),
                border: Border.all(
                  color:
                      itemController.selectedVariations[index].contains(true)
                          ? Theme.of(context).primaryColor
                          : Theme.of(context).disabledColor,
                  width: 0.5,
                ),
                borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        item!.foodVariations![index].name!,
                        style: waddyMedium.copyWith(
                          fontSize: Dimensions.fontSizeLarge,
                        ),
                      ),

                      Container(
                        decoration: BoxDecoration(
                          color:
                              item!.foodVariations![index].required! &&
                                      (item!.foodVariations![index].multiSelect!
                                              ? item!
                                                  .foodVariations![index]
                                                  .min!
                                              : 1) >
                                          selectedCount
                                  ? Theme.of(
                                    context,
                                  ).colorScheme.error.withValues(alpha: 0.1)
                                  : Theme.of(
                                    context,
                                  ).disabledColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusSmall,
                          ),
                        ),
                        padding: const EdgeInsets.all(
                          Dimensions.paddingSizeExtraSmall,
                        ),

                        child: Text(
                          item!.foodVariations![index].required!
                              ? (item!.foodVariations![index].multiSelect!
                                          ? item!.foodVariations![index].min!
                                          : 1) <=
                                      selectedCount
                                  ? 'completed'.tr
                                  : 'required'.tr
                              : 'optional'.tr,
                          style: waddyRegular.copyWith(
                            color:
                                item!.foodVariations![index].required!
                                    ? (item!.foodVariations![index].multiSelect!
                                                ? item!
                                                    .foodVariations![index]
                                                    .min!
                                                : 1) <=
                                            selectedCount
                                        ? Theme.of(context).hintColor
                                        : Theme.of(context).colorScheme.error
                                    : Theme.of(context).hintColor,
                            fontSize: Dimensions.fontSizeSmall,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Dimensions.paddingSizeExtraSmall),

                  item!.foodVariations![index].multiSelect!
                      ? Text(
                        '${'select_minimum'.tr} ${'${item!.foodVariations![index].min}'
                            ' ${'and_up_to'.tr} ${item!.foodVariations![index].max} ${'options'.tr}'}',
                        style: waddyMedium.copyWith(
                          fontSize: Dimensions.fontSizeExtraSmall,
                          color: Theme.of(context).disabledColor,
                        ),
                      )
                      : Text(
                        'select_one'.tr,
                        style: waddyMedium.copyWith(
                          fontSize: Dimensions.fontSizeExtraSmall,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                  SizedBox(
                    height:
                        item!.foodVariations![index].multiSelect!
                            ? Dimensions.paddingSizeExtraSmall
                            : 0,
                  ),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount:
                        itemController.collapseVariation[index]
                            ? item!
                                        .foodVariations![index]
                                        .variationValues!
                                        .length >
                                    4
                                ? 5
                                : item!
                                    .foodVariations![index]
                                    .variationValues!
                                    .length
                            : item!
                                .foodVariations![index]
                                .variationValues!
                                .length,
                    itemBuilder: (context, i) {
                      if (i == 4 && itemController.collapseVariation[index]) {
                        return Padding(
                          padding: const EdgeInsets.all(
                            Dimensions.paddingSizeExtraSmall,
                          ),
                          child: InkWell(
                            onTap:
                                () => itemController.showMoreSpecificSection(
                                  index,
                                ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.expand_more,
                                  size: 18,
                                  color: Theme.of(context).primaryColor,
                                ),
                                const SizedBox(
                                  width: Dimensions.paddingSizeExtraSmall,
                                ),

                                Text(
                                  '${'view'.tr} ${item!.foodVariations![index].variationValues!.length - 4} ${'more_option'.tr}',
                                  style: waddyMedium.copyWith(
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      } else {
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 0),
                          child: InkWell(
                            onTap: () {
                              itemController.setNewCartVariationIndex(
                                index,
                                i,
                                item!,
                              );
                            },
                            child: Row(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    item!.foodVariations![index].multiSelect!
                                        ? Checkbox(
                                          value:
                                              itemController
                                                  .selectedVariations[index][i],
                                          activeColor:
                                              Theme.of(context).primaryColor,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              Dimensions.radiusSmall,
                                            ),
                                          ),
                                          onChanged: (bool? newValue) {
                                            itemController
                                                .setNewCartVariationIndex(
                                                  index,
                                                  i,
                                                  item!,
                                                );
                                          },
                                          visualDensity: const VisualDensity(
                                            horizontal: -3,
                                            vertical: -3,
                                          ),
                                          side: BorderSide(
                                            width: 2,
                                            color: Theme.of(context).hintColor,
                                          ),
                                        )
                                        : Radio(
                                          value: i,
                                          groupValue: itemController
                                              .selectedVariations[index]
                                              .indexOf(true),
                                          onChanged: (dynamic value) {
                                            itemController
                                                .setNewCartVariationIndex(
                                                  index,
                                                  i,
                                                  item!,
                                                );
                                          },
                                          activeColor:
                                              Theme.of(context).primaryColor,
                                          toggleable: false,
                                          visualDensity: const VisualDensity(
                                            horizontal: -3,
                                            vertical: -3,
                                          ),
                                        ),

                                    Text(
                                      item!
                                          .foodVariations![index]
                                          .variationValues![i]
                                          .level!
                                          .trim(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          itemController
                                                  .selectedVariations[index][i]!
                                              ? waddyMedium
                                              : waddyRegular.copyWith(
                                                color:
                                                    Theme.of(context).hintColor,
                                              ),
                                    ),
                                  ],
                                ),

                                const Spacer(),

                                showOriginalPrice
                                    ? Text(
                                      '+${PriceConverter.convertPrice(item!.foodVariations![index].variationValues![i].optionPrice)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textDirection: TextDirection.ltr,
                                      style: waddyRegular.copyWith(
                                        fontSize: Dimensions.fontSizeExtraSmall,
                                        color: Theme.of(context).disabledColor,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    )
                                    : const SizedBox(),
                                SizedBox(
                                  width:
                                      showOriginalPrice
                                          ? Dimensions.paddingSizeExtraSmall
                                          : 0,
                                ),

                                Text(
                                  '+${PriceConverter.convertPrice(item!.foodVariations![index].variationValues![i].optionPrice, discount: discount, discountType: discountType, isFoodVariation: true)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textDirection: TextDirection.ltr,
                                  style:
                                      itemController
                                              .selectedVariations[index][i]!
                                          ? waddyMedium.copyWith(
                                            fontSize:
                                                Dimensions.fontSizeExtraSmall,
                                          )
                                          : waddyRegular.copyWith(
                                            fontSize:
                                                Dimensions.fontSizeExtraSmall,
                                            color:
                                                Theme.of(context).disabledColor,
                                          ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            );
          },
        )
        : const SizedBox();
  }
}
