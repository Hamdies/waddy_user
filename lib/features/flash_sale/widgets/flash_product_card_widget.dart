import 'package:waddy_app/common/widgets/offer_collar_badge.dart';
import 'package:waddy_app/common/widgets/price_tag.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_ink_well.dart';
import 'package:waddy_app/features/item/controllers/item_controller.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/flash_sale/domain/models/product_flash_sale.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/add_favourite_view.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/organic_tag.dart';

class FlashProductCardWidget extends StatelessWidget {
  final Products product;
  final int? index;
  const FlashProductCardWidget({super.key, required this.product, this.index});

  @override
  Widget build(BuildContext context) {
    final ItemPrice price = ItemPrice.of(
      product.item!,
      base: Get.find<ItemController>().getStartingPrice(product.item!),
    );

    int stock = product.stock!;
    int sold = product.sold!;
    int remaining = stock - sold;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: CustomInkWell(
        onTap:
            remaining == 0
                ? null
                : () => Get.find<ItemController>().navigateToItemPage(
                  product.item,
                  context,
                ),
        padding: const EdgeInsets.all(Dimensions.paddingSizeExtraSmall),
        radius: Dimensions.radiusDefault,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 1,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(
                      Dimensions.radiusDefault,
                    ),
                    child: CustomImage(
                      image: '${product.item!.imageFullUrl}',
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),

                  if (price.onSale)
                    PositionedDirectional(
                      top: 6,
                      start: 6,
                      child:
                          OfferCollarBadge.forPrice(
                            price,
                            compact: true,
                            onPhoto: true,
                          )!,
                    ),

                  OrganicTag(item: product.item!, placeInImage: false),

                  AddFavouriteView(top: 5, right: 5, item: product.item!),

                  const SizedBox(),
                ],
              ),
            ),
            SizedBox(height: 0),

            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(Dimensions.paddingSizeExtraSmall),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      product.item!.name ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: waddyMedium,
                    ),

                    (Get.find<SplashController>()
                                .configModel
                                .moduleConfig!
                                .module!
                                .unit! &&
                            product.item!.unitType != null)
                        ? Text(
                          '(${product.item!.unitType ?? ''})',
                          style: waddyRegular.copyWith(
                            color: Theme.of(context).disabledColor,
                            fontSize: Dimensions.fontSizeSmall,
                          ),
                        )
                        : const SizedBox(),

                    PriceTag(price: price, oneLine: true),

                    const SizedBox(),

                    Stack(
                      children: [
                        SizedBox(
                          width: Get.width,
                          child: LinearProgressIndicator(
                            borderRadius: const BorderRadius.all(
                              Radius.circular(Dimensions.radiusDefault),
                            ),
                            minHeight: 12,
                            value: remaining / stock,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).primaryColor,
                            ),
                            backgroundColor: Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.25),
                          ),
                        ),

                        Positioned(
                          top: -1.5,
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Text(
                            '${'sold'.tr} $sold/$stock',
                            style: waddyMedium.copyWith(
                              fontSize: Dimensions.fontSizeExtraSmall,
                              color: Theme.of(context).cardColor,
                            ),
                            textAlign: TextAlign.center,
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
  }
}
