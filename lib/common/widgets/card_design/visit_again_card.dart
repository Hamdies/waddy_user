import 'package:waddy_app/features/store/store_navigator.dart';
import 'package:waddy_app/common/models/module_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/add_favourite_view.dart';
import 'package:waddy_app/common/widgets/custom_ink_well.dart';
import 'package:waddy_app/common/widgets/not_available_widget.dart';
import 'package:waddy_app/features/language/controllers/language_controller.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';

class VisitAgainCard extends StatelessWidget {
  final Store store;
  final bool fromFood;
  const VisitAgainCard({
    super.key,
    required this.store,
    required this.fromFood,
  });

  @override
  Widget build(BuildContext context) {
    bool isPharmacy =
        Get.find<SplashController>().module?.type == ModuleType.pharmacy;
    bool isFood = Get.find<SplashController>().module?.type == ModuleType.food;
    bool isAvailable = store.open == 1 && store.active!;

    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(
            top: Dimensions.paddingSizeLarge,
            bottom: Dimensions.paddingSizeSmall,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            color: Theme.of(context).cardColor,
            border: Border.all(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 5, spreadRadius: 1),
            ],
          ),
          child: CustomInkWell(
            onTap: () {
              StoreNavigator.open(store);
            },
            radius: Dimensions.radiusDefault,
            padding: const EdgeInsets.only(
              top: Dimensions.paddingSizeExtraOverLarge,
              bottom: Dimensions.paddingSizeSmall,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    store.name ?? '',
                    style: waddyBold,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                if (store.ratingCount! > 0)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.star,
                        size: 15,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: Dimensions.paddingSizeExtraSmall),

                      Text(
                        store.avgRating!.toStringAsFixed(1),
                        style: waddyRegular,
                      ),
                      const SizedBox(width: Dimensions.paddingSizeExtraSmall),

                      Text(
                        "(${store.ratingCount})",
                        style: waddyRegular.copyWith(
                          fontSize: Dimensions.fontSizeSmall,
                          color: Theme.of(context).disabledColor,
                        ),
                      ),
                    ],
                  ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Dimensions.paddingSizeSmall,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.storefront_outlined,
                        size: 20,
                        color: Theme.of(context).disabledColor,
                      ),
                      const SizedBox(width: Dimensions.paddingSizeExtraSmall),

                      Flexible(
                        child: Text(
                          store.address ?? '',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: waddyRegular.copyWith(
                            color: Theme.of(context).disabledColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                store.items != null
                    ? Container(
                      alignment: Alignment.center,
                      height: 25,
                      width: 200,
                      child: ListView.builder(
                        itemCount: store.items!.length,
                        scrollDirection: Axis.horizontal,
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(
                              right: Dimensions.paddingSizeExtraSmall,
                            ),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    (isPharmacy || isFood)
                                        ? 100
                                        : Dimensions.radiusSmall,
                                  ),
                                  child: CustomImage(
                                    image:
                                        '${store.items![index].imageFullUrl}',
                                    fit: BoxFit.cover,
                                    height: 25,
                                    width: 25,
                                  ),
                                ),

                                index == store.items!.length - 1
                                    ? Positioned(
                                      top: 0,
                                      left: 0,
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            (isPharmacy || isFood)
                                                ? 100
                                                : Dimensions.radiusSmall,
                                          ),
                                          color: Colors.black.withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            (store.itemCount! > 20)
                                                ? '20+'
                                                : '${store.itemCount}',
                                            style: waddyMedium.copyWith(
                                              color: Colors.white,
                                              fontSize:
                                                  Dimensions.fontSizeExtraSmall,
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                    : const SizedBox(),
                              ],
                            ),
                          );
                        },
                      ),
                    )
                    : const SizedBox(),
              ],
            ),
          ),
        ),

        Align(
          alignment: Alignment.topCenter,
          child: Container(
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                fromFood ? 100 : Dimensions.radiusDefault,
              ),
              color: Theme.of(context).cardColor,
              border: Border.all(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                fromFood ? 100 : Dimensions.radiusDefault,
              ),
              child: Stack(
                children: [
                  CustomImage(
                    image: '${store.logoFullUrl}',
                    fit: BoxFit.cover,
                    height: 54,
                    width: 54,
                  ),

                  isAvailable
                      ? const SizedBox()
                      : NotAvailableWidget(
                        isStore: true,
                        store: store,
                        fontSize: 8,
                        isAllSideRound: true,
                      ),
                ],
              ),
            ),
          ),
        ),

        AddFavouriteView(
          top: 30,
          left: Get.find<LocalizationController>().isLtr ? null : 10,
          right: Get.find<LocalizationController>().isLtr ? 10 : null,
          item: null,
          storeId: store.id,
        ),
      ],
    );
  }
}
