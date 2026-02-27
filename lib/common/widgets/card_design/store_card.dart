import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sixam_mart/common/widgets/add_favourite_view.dart';
import 'package:sixam_mart/common/widgets/custom_ink_well.dart';
import 'package:sixam_mart/common/widgets/hover/text_hover.dart';
import 'package:sixam_mart/common/widgets/not_available_widget.dart';
import 'package:sixam_mart/features/language/controllers/language_controller.dart';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/features/store/controllers/store_controller.dart';
import 'package:sixam_mart/common/models/module_model.dart';
import 'package:sixam_mart/features/store/domain/models/store_model.dart';
import 'package:sixam_mart/helper/responsive_helper.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/util/app_constants.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/images.dart';
import 'package:sixam_mart/util/styles.dart';
import 'package:sixam_mart/common/widgets/custom_image.dart';
import 'package:sixam_mart/common/widgets/new_tag.dart';
import 'package:sixam_mart/common/widgets/rating_bar.dart';
import 'package:sixam_mart/features/store/screens/store_screen.dart';

class StoreCard extends StatefulWidget {
  final Store store;
  final bool? isTopOffers;
  const StoreCard({super.key, required this.store, this.isTopOffers = false});

  @override
  State<StoreCard> createState() => _StoreCardState();
}

class _StoreCardState extends State<StoreCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _animationController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _animationController.reverse();
  }

  void _onTapCancel() {
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    bool isPharmacy =
        Get.find<SplashController>().module != null &&
        Get.find<SplashController>().module!.moduleType.toString() ==
            AppConstants.pharmacy;
    double distance = Get.find<StoreController>().getRestaurantDistance(
      LatLng(
        double.parse(widget.store.latitude!),
        double.parse(widget.store.longitude!),
      ),
    );
    double discount = widget.store.discount?.discount ?? 0;
    String discountType = widget.store.discount?.discountType ?? '';
    bool isRightSide =
        Get.find<SplashController>().configModel!.currencySymbolDirection ==
        'right';
    String currencySymbol =
        Get.find<SplashController>().configModel!.currencySymbol!;
    bool isAvailable = widget.store.open == 1 && widget.store.active!;

    return Stack(
      children: [
        GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              );
            },
            child: Container(
              width: 300,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                boxShadow:
                    ResponsiveHelper.isMobile(context)
                        ? [
                          // Ambient shadow - soft, spread out
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).shadowColor.withOpacity(0.08),
                            blurRadius: 12,
                            spreadRadius: 0,
                            offset: const Offset(0, 2),
                          ),
                          // Directional shadow - for depth
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).shadowColor.withOpacity(0.12),
                            blurRadius: 8,
                            spreadRadius: 0,
                            offset: const Offset(0, 4),
                          ),
                        ]
                        : null,
              ),
              child: CustomInkWell(
                onTap: () {
                  if (Get.find<SplashController>().moduleList != null) {
                    for (ModuleModel module
                        in Get.find<SplashController>().moduleList!) {
                      if (module.id == widget.store.moduleId) {
                        Get.find<SplashController>().setModule(module);
                        break;
                      }
                    }
                  }
                  Get.toNamed(
                    RouteHelper.getStoreRoute(
                      id: widget.store.id,
                      page: 'store',
                    ),
                    arguments: StoreScreen(
                      store: widget.store,
                      fromModule: false,
                    ),
                  );
                },
                padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                radius: Dimensions.radiusDefault,
                child: TextHover(
                  builder: (hovered) {
                    return Stack(
                      children: [
                        Column(
                          children: [
                            Expanded(
                              flex: 5,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          Dimensions.radiusDefault,
                                        ),
                                        child: CustomImage(
                                          isHovered: hovered,
                                          image: '${widget.store.logoFullUrl}',
                                          height: 50,
                                          width: 50,
                                          fit: BoxFit.cover,
                                        ),
                                      ),

                                      isAvailable
                                          ? const SizedBox()
                                          : NotAvailableWidget(
                                            isStore: true,
                                            store: widget.store,
                                            fontSize:
                                                Dimensions.fontSizeExtraSmall,
                                            isAllSideRound: true,
                                          ),
                                    ],
                                  ),
                                  const SizedBox(
                                    width: Dimensions.paddingSizeSmall,
                                  ),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          width: 190,
                                          child: Text(
                                            widget.store.name ?? '',
                                            style: robotoMedium.copyWith(
                                              fontSize:
                                                  Dimensions.fontSizeDefault,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(
                                          height:
                                              Dimensions.paddingSizeExtraSmall,
                                        ),

                                        !isPharmacy
                                            ? widget.store.ratingCount! > 0
                                                ? RatingBar(
                                                  rating:
                                                      widget.store.avgRating,
                                                  ratingCount:
                                                      widget.store.ratingCount,
                                                  size: 12,
                                                )
                                                : const SizedBox()
                                            : Row(
                                              children: [
                                                Icon(
                                                  Icons.storefront,
                                                  size: 15,
                                                  color:
                                                      Theme.of(
                                                        context,
                                                      ).primaryColor,
                                                ),
                                                const SizedBox(
                                                  width:
                                                      Dimensions
                                                          .paddingSizeExtraSmall,
                                                ),

                                                Expanded(
                                                  child: Text(
                                                    widget.store.address ?? '',
                                                    style: robotoRegular.copyWith(
                                                      fontSize:
                                                          Dimensions
                                                              .fontSizeExtraSmall,
                                                      color:
                                                          Theme.of(
                                                            context,
                                                          ).primaryColor,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                        const SizedBox(
                                          height:
                                              Dimensions.paddingSizeExtraSmall,
                                        ),

                                        !isPharmacy
                                            ? Row(
                                              children: [
                                                Icon(
                                                  Icons.storefront,
                                                  size: 15,
                                                  color:
                                                      Theme.of(
                                                        context,
                                                      ).primaryColor,
                                                ),
                                                const SizedBox(
                                                  width:
                                                      Dimensions
                                                          .paddingSizeExtraSmall,
                                                ),

                                                Flexible(
                                                  child: Text(
                                                    widget.store.address ?? '',
                                                    style: robotoMedium.copyWith(
                                                      fontSize:
                                                          Dimensions
                                                              .fontSizeExtraSmall,
                                                      color:
                                                          Theme.of(
                                                            context,
                                                          ).primaryColor,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            )
                                            : Text(
                                              '${widget.store.itemCount}'
                                                      ' '
                                                      'items'
                                                  .tr,
                                              style: robotoRegular.copyWith(
                                                fontSize:
                                                    Dimensions.fontSizeSmall,
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).primaryColor,
                                              ),
                                            ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child:
                                  widget.isTopOffers!
                                      ? Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal:
                                              Dimensions.paddingSizeExtraSmall,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).primaryColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            Dimensions.radiusExtraLarge,
                                          ),
                                          border: Border.all(
                                            color: Theme.of(
                                              context,
                                            ).primaryColor.withOpacity(0.15),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                const SizedBox(
                                                  width:
                                                      Dimensions
                                                          .paddingSizeExtraSmall,
                                                ),

                                                Image.asset(
                                                  Images.distanceLine,
                                                  height: 15,
                                                  width: 15,
                                                  color:
                                                      Theme.of(
                                                        context,
                                                      ).disabledColor,
                                                ),
                                                const SizedBox(
                                                  width:
                                                      Dimensions
                                                          .paddingSizeExtraSmall,
                                                ),

                                                Text(
                                                  '${distance > 100 ? '100+' : distance.toStringAsFixed(2)} ${'km'.tr}',
                                                  style: robotoBold.copyWith(
                                                    color:
                                                        Theme.of(
                                                          context,
                                                        ).disabledColor,
                                                    fontSize:
                                                        Dimensions
                                                            .fontSizeSmall,
                                                  ),
                                                ),
                                                const SizedBox(
                                                  width:
                                                      Dimensions
                                                          .paddingSizeExtraSmall,
                                                ),

                                                Text(
                                                  'from_you'.tr,
                                                  style: robotoRegular.copyWith(
                                                    color:
                                                        Theme.of(
                                                          context,
                                                        ).disabledColor,
                                                    fontSize:
                                                        Dimensions
                                                            .fontSizeSmall,
                                                  ),
                                                ),
                                              ],
                                            ),

                                            Container(
                                              decoration: BoxDecoration(
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).primaryColor,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      Dimensions
                                                          .radiusExtraLarge,
                                                    ),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal:
                                                        Dimensions
                                                            .paddingSizeSmall,
                                                    vertical: 3,
                                                  ),
                                              child: Text(
                                                discount > 0
                                                    ? '${(isRightSide || discountType == 'percent') ? '' : currencySymbol}$discount${discountType == 'percent'
                                                        ? '%'
                                                        : isRightSide
                                                        ? currencySymbol
                                                        : ''} ${'off'.tr}'
                                                    : 'free_delivery'.tr,
                                                style: robotoMedium.copyWith(
                                                  color:
                                                      Theme.of(
                                                        context,
                                                      ).cardColor,
                                                  fontSize:
                                                      Dimensions.fontSizeSmall,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                      : Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal:
                                                  Dimensions.paddingSizeSmall,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Theme.of(
                                                context,
                                              ).primaryColor.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    Dimensions.radiusExtraLarge,
                                                  ),
                                              border: Border.all(
                                                color: Theme.of(
                                                  context,
                                                ).primaryColor.withOpacity(0.2),
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Image.asset(
                                                  Images.distanceLine,
                                                  height: 15,
                                                  width: 15,
                                                ),
                                                const SizedBox(
                                                  width:
                                                      Dimensions
                                                          .paddingSizeExtraSmall,
                                                ),

                                                Text(
                                                  '${distance > 100 ? '100+' : distance.toStringAsFixed(2)} ${'km'.tr}',
                                                  style: robotoBold.copyWith(
                                                    color:
                                                        Theme.of(
                                                          context,
                                                        ).primaryColor,
                                                    fontSize:
                                                        Dimensions
                                                            .fontSizeSmall,
                                                  ),
                                                ),
                                                const SizedBox(
                                                  width:
                                                      Dimensions
                                                          .paddingSizeExtraSmall,
                                                ),

                                                Text(
                                                  'from_you'.tr,
                                                  style: robotoRegular.copyWith(
                                                    color:
                                                        Theme.of(
                                                          context,
                                                        ).primaryColor,
                                                    fontSize:
                                                        Dimensions
                                                            .fontSizeSmall,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Spacer(),

                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal:
                                                  Dimensions.paddingSizeSmall,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  Get.find<StoreController>()
                                                          .isOpenNow(
                                                            widget.store,
                                                          )
                                                      ? const Color(
                                                        0xffECA507,
                                                      ).withOpacity(0.1)
                                                      : Theme.of(context)
                                                          .colorScheme
                                                          .error
                                                          .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    Dimensions.radiusExtraLarge,
                                                  ),
                                              border: Border.all(
                                                color:
                                                    Get.find<StoreController>()
                                                            .isOpenNow(
                                                              widget.store,
                                                            )
                                                        ? const Color(
                                                          0xffECA507,
                                                        ).withOpacity(0.3)
                                                        : Theme.of(context)
                                                            .colorScheme
                                                            .error
                                                            .withOpacity(0.3),
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Image.asset(
                                                  Images.clockIcon,
                                                  height: 15,
                                                  width: 15,
                                                  color:
                                                      Get.find<
                                                                StoreController
                                                              >()
                                                              .isOpenNow(
                                                                widget.store,
                                                              )
                                                          ? const Color(
                                                            0xffECA507,
                                                          )
                                                          : Theme.of(
                                                            context,
                                                          ).colorScheme.error,
                                                ),
                                                const SizedBox(
                                                  width:
                                                      Dimensions
                                                          .paddingSizeExtraSmall,
                                                ),

                                                Text(
                                                  Get.find<StoreController>()
                                                          .isOpenNow(
                                                            widget.store,
                                                          )
                                                      ? 'open_now'.tr
                                                      : 'closed_now'.tr,
                                                  style: robotoBold.copyWith(
                                                    color:
                                                        Get.find<
                                                                  StoreController
                                                                >()
                                                                .isOpenNow(
                                                                  widget.store,
                                                                )
                                                            ? const Color(
                                                              0xffECA507,
                                                            )
                                                            : Theme.of(
                                                              context,
                                                            ).colorScheme.error,
                                                    fontSize:
                                                        Dimensions
                                                            .fontSizeSmall,
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

                        AddFavouriteView(
                          top: 0,
                          left:
                              Get.find<LocalizationController>().isLtr
                                  ? null
                                  : 0,
                          right:
                              Get.find<LocalizationController>().isLtr
                                  ? 0
                                  : null,
                          item: null,
                          storeId: widget.store.id,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),

        !widget.isTopOffers! ? const NewTag() : const SizedBox(),
      ],
    );
  }
}
