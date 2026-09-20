import 'package:waddy_app/common/models/module_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_ink_well.dart';
import 'package:waddy_app/features/item/controllers/item_controller.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/add_favourite_view.dart';
import 'package:waddy_app/common/widgets/cart_count_view.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/discount_tag.dart';
import 'package:waddy_app/common/widgets/organic_tag.dart';

class MedicineItemCard extends StatelessWidget {
  final Item item;
  const MedicineItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    bool isShop =
        Get.find<SplashController>().module?.type == ModuleType.ecommerce;
    double? discount = item.discount;
    String? discountType = item.discountType;

    return Container(
      width: isShop ? 200 : 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        color: Theme.of(context).cardColor,
      ),
      child: CustomInkWell(
        onTap:
            () => Get.find<ItemController>().navigateToItemPage(item, context),
        radius: Dimensions.radiusDefault,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(Dimensions.radiusDefault),
                      topRight: Radius.circular(Dimensions.radiusDefault),
                    ),
                    child: CustomImage(
                      image: '${item.imageFullUrl}',
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),

                  AddFavouriteView(item: item),

                  DiscountTag(
                    discount: discount,
                    discountType: discountType,
                    freeDelivery: false,
                  ),

                  OrganicTag(item: item, placeInImage: false),

                  isShop
                      ? const SizedBox()
                      : Positioned(
                        bottom: 10,
                        right: 10,
                        child: CartCountView(
                          item: item,
                          child: Container(
                            height: 25,
                            width: 25,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).primaryColor,
                            ),
                            child: Icon(
                              Icons.add,
                              size: 20,
                              color: Theme.of(context).cardColor,
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ),

            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                child: Column(
                  crossAxisAlignment:
                      isShop
                          ? CrossAxisAlignment.center
                          : CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(
                      item.storeName ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: waddyRegular.copyWith(
                        color: Theme.of(context).disabledColor,
                        fontSize: Dimensions.fontSizeSmall,
                      ),
                    ),

                    Text(
                      item.name ?? '',
                      style: waddyBold,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    if (item.genericName != null &&
                        item.genericName!.isNotEmpty)
                      Wrap(
                        children: List.generate(item.genericName!.length, (
                          index,
                        ) {
                          return Text(
                            '${item.genericName![index]}${item.genericName!.length - 1 == index ? '.' : ', '}',
                            style: waddyRegular.copyWith(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyLarge!
                                  .color
                                  ?.withValues(alpha: 0.5),
                              fontSize: Dimensions.fontSizeSmall,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        }),
                      ),

                    if (isShop)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.star,
                            size: 15,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(
                            width: Dimensions.paddingSizeExtraSmall,
                          ),

                          Text(item.avgRating.toString(), style: waddyRegular),
                          const SizedBox(
                            width: Dimensions.paddingSizeExtraSmall,
                          ),

                          Text(
                            "(${item.ratingCount})",
                            style: waddyRegular.copyWith(
                              fontSize: Dimensions.fontSizeSmall,
                              color: Theme.of(context).disabledColor,
                            ),
                          ),
                        ],
                      ),

                    item.discount != null && item.discount! > 0
                        ? Text(
                          PriceConverter.convertPrice(
                            Get.find<ItemController>().getStartingPrice(item),
                          ),
                          style: waddyMedium.copyWith(
                            fontSize: Dimensions.fontSizeExtraSmall,
                            color: Theme.of(context).disabledColor,
                            decoration: TextDecoration.lineThrough,
                          ),
                          textDirection: TextDirection.ltr,
                        )
                        : const SizedBox(),

                    Align(
                      alignment:
                          isShop ? Alignment.center : Alignment.centerLeft,
                      child: Row(
                        mainAxisAlignment:
                            isShop
                                ? MainAxisAlignment.center
                                : MainAxisAlignment.start,
                        children: [
                          Text(
                            PriceConverter.convertPrice(
                              Get.find<ItemController>().getStartingPrice(item),
                              discount: item.discount,
                              discountType: item.discountType,
                            ),
                            textDirection: TextDirection.ltr,
                            style: waddyMedium,
                          ),
                          const SizedBox(
                            width: Dimensions.paddingSizeExtraSmall,
                          ),

                          (Get.find<SplashController>()
                                      .configModel
                                      .moduleConfig!
                                      .module!
                                      .unit! &&
                                  item.unitType != null)
                              ? Text(
                                '/ ${item.unitType ?? ''}',
                                style: waddyRegular.copyWith(
                                  fontSize: Dimensions.fontSizeExtraSmall,
                                  color: Theme.of(context).hintColor,
                                ),
                              )
                              : const SizedBox(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
