import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/add_favourite_view.dart';
import 'package:waddy_app/common/widgets/custom_ink_well.dart';
import 'package:waddy_app/common/widgets/hover/text_hover.dart';
import 'package:waddy_app/features/language/controllers/language_controller.dart';
import 'package:waddy_app/features/splash/controllers/splash_controller.dart';
import 'package:waddy_app/features/store/controllers/store_controller.dart';
import 'package:waddy_app/common/models/module_model.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/app_constants.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/images.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_button.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/discount_tag.dart';
import 'package:waddy_app/common/widgets/new_tag.dart';
import 'package:waddy_app/common/widgets/not_available_widget.dart';
import 'package:waddy_app/features/store/screens/store_screen.dart';

class StoreCardWithDistance extends StatefulWidget {
  final Store store;
  final bool fromAllStore;
  final bool? isNewStore;
  final bool? fromTopOffers;
  final bool recommendedStore;
  const StoreCardWithDistance({
    super.key,
    required this.store,
    this.fromAllStore = false,
    this.isNewStore = false,
    this.fromTopOffers = false,
    this.recommendedStore = false,
  });

  @override
  State<StoreCardWithDistance> createState() => _StoreCardWithDistanceState();
}

class _StoreCardWithDistanceState extends State<StoreCardWithDistance>
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
    double distance = (widget.store.distance! / 1000);
    double discount = widget.store.discount?.discount ?? 0;
    String discountType = widget.store.discount?.discountType ?? '';
    bool isRightSide =
        Get.find<SplashController>().configModel!.currencySymbolDirection ==
        'right';
    String currencySymbol =
        Get.find<SplashController>().configModel!.currencySymbol!;

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
              width: widget.fromAllStore ? double.infinity : 260,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                boxShadow: [
                  // Ambient shadow
                  BoxShadow(
                    color: Theme.of(context).shadowColor.withOpacity(0.06),
                    blurRadius: 12,
                    spreadRadius: 0,
                    offset: const Offset(0, 2),
                  ),
                  // Directional shadow
                  BoxShadow(
                    color: Theme.of(context).shadowColor.withOpacity(0.10),
                    blurRadius: 8,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ],
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
                radius: Dimensions.radiusDefault,
                child: TextHover(
                  builder: (hovered) {
                    return Column(
                      children: [
                        Expanded(
                          flex: widget.recommendedStore ? 3 : 1,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(
                                Dimensions.radiusDefault,
                              ),
                              topRight: Radius.circular(
                                Dimensions.radiusDefault,
                              ),
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CustomImage(
                                  isHovered: hovered,
                                  image: '${widget.store.coverPhotoFullUrl}',
                                  fit: BoxFit.cover,
                                  height: double.infinity,
                                  width: double.infinity,
                                ),

                                !widget.fromTopOffers!
                                    ? DiscountTag(
                                      discount: Get.find<StoreController>()
                                          .getDiscount(widget.store),
                                      discountType: Get.find<StoreController>()
                                          .getDiscountType(widget.store),
                                      freeDelivery: widget.store.freeDelivery,
                                    )
                                    : const SizedBox(),

                                Get.find<StoreController>().isOpenNow(
                                      widget.store,
                                    )
                                    ? const SizedBox()
                                    : const NotAvailableWidget(isStore: true),

                                widget.fromTopOffers!
                                    ? Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal:
                                              Dimensions.paddingSizeSmall,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(
                                              Dimensions.radiusDefault,
                                            ),
                                          ),
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error.withOpacity(0.9),
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
                                            color: Theme.of(context).cardColor,
                                            fontSize: Dimensions.fontSizeSmall,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    )
                                    : const SizedBox(),

                                AddFavouriteView(
                                  top: 10,
                                  left:
                                      Get.find<LocalizationController>().isLtr
                                          ? null
                                          : 10,
                                  right:
                                      Get.find<LocalizationController>().isLtr
                                          ? 10
                                          : null,
                                  item: null,
                                  storeId: widget.store.id,
                                ),

                                widget.isNewStore!
                                    ? const NewTag()
                                    : const SizedBox(),
                              ],
                            ),
                          ),
                        ),

                        widget.recommendedStore
                            ? Expanded(
                              flex: 2,
                              child: Column(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 95),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(
                                            height:
                                                Dimensions
                                                    .paddingSizeExtraSmall,
                                          ),

                                          Flexible(
                                            child: Text(
                                              widget.store.name ?? '',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: robotoMedium.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(
                                            height:
                                                Dimensions
                                                    .paddingSizeExtraSmall,
                                          ),

                                          Padding(
                                            padding: const EdgeInsets.only(
                                              right:
                                                  Dimensions.paddingSizeDefault,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              children: [
                                                Icon(
                                                  Icons.star,
                                                  color:
                                                      Theme.of(
                                                        context,
                                                      ).primaryColor,
                                                  size: 14,
                                                ),
                                                const SizedBox(
                                                  width:
                                                      Dimensions
                                                          .paddingSizeExtraSmall,
                                                ),

                                                Text(
                                                  '${widget.store.avgRating}',
                                                  style: robotoRegular.copyWith(
                                                    fontSize:
                                                        Dimensions
                                                            .fontSizeExtraSmall,
                                                  ),
                                                ),
                                                const SizedBox(
                                                  width:
                                                      Dimensions
                                                          .paddingSizeExtraSmall,
                                                ),

                                                Text(
                                                  '(${widget.store.ratingCount})',
                                                  style: robotoRegular.copyWith(
                                                    fontSize:
                                                        Dimensions
                                                            .fontSizeExtraSmall,
                                                    color:
                                                        Theme.of(
                                                          context,
                                                        ).disabledColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                            : Expanded(
                              flex: 1,
                              child: Column(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 95),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(
                                            height:
                                                Dimensions
                                                    .paddingSizeExtraSmall,
                                          ),

                                          Flexible(
                                            child: Text(
                                              widget.store.name ?? '',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: robotoMedium.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(
                                            height:
                                                Dimensions
                                                    .paddingSizeExtraSmall,
                                          ),

                                          !widget.fromTopOffers!
                                              ? Row(
                                                children: [
                                                  Icon(
                                                    Icons.location_on_outlined,
                                                    color:
                                                        isPharmacy
                                                            ? Colors.blue
                                                            : Theme.of(
                                                              context,
                                                            ).primaryColor,
                                                    size: 15,
                                                  ),
                                                  const SizedBox(
                                                    width:
                                                        Dimensions
                                                            .paddingSizeExtraSmall,
                                                  ),
                                                  Expanded(
                                                    child: Text(
                                                      widget.store.address ??
                                                          '',
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: robotoRegular.copyWith(
                                                        color:
                                                            Theme.of(
                                                              context,
                                                            ).disabledColor,
                                                        fontSize:
                                                            Dimensions
                                                                .fontSizeExtraSmall,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              )
                                              : const SizedBox(),
                                        ],
                                      ),
                                    ),
                                  ),

                                  widget.fromTopOffers!
                                      ? Expanded(
                                        flex: 4,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal:
                                                Dimensions.paddingSizeDefault,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const SizedBox(
                                                height:
                                                    Dimensions
                                                        .paddingSizeExtraSmall,
                                              ),
                                              Flexible(
                                                child: Text(
                                                  widget.store.address ?? '',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: robotoRegular.copyWith(
                                                    color:
                                                        Theme.of(
                                                          context,
                                                        ).disabledColor,
                                                    fontSize:
                                                        Dimensions
                                                            .fontSizeExtraSmall,
                                                  ),
                                                ),
                                              ),

                                              Row(
                                                children: [
                                                  if (widget
                                                          .store
                                                          .ratingCount! >
                                                      0)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            right:
                                                                Dimensions
                                                                    .paddingSizeDefault,
                                                          ),
                                                      child: Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .start,
                                                        children: [
                                                          Icon(
                                                            Icons.star,
                                                            color:
                                                                Theme.of(
                                                                  context,
                                                                ).primaryColor,
                                                            size: 14,
                                                          ),
                                                          const SizedBox(
                                                            width:
                                                                Dimensions
                                                                    .paddingSizeExtraSmall,
                                                          ),

                                                          Text(
                                                            '${widget.store.avgRating}',
                                                            style: robotoRegular
                                                                .copyWith(
                                                                  fontSize:
                                                                      Dimensions
                                                                          .fontSizeExtraSmall,
                                                                ),
                                                          ),
                                                          const SizedBox(
                                                            width:
                                                                Dimensions
                                                                    .paddingSizeExtraSmall,
                                                          ),

                                                          Text(
                                                            '(${widget.store.ratingCount})',
                                                            style: robotoRegular
                                                                .copyWith(
                                                                  fontSize:
                                                                      Dimensions
                                                                          .fontSizeExtraSmall,
                                                                  color:
                                                                      Theme.of(
                                                                        context,
                                                                      ).disabledColor,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),

                                                  Text(
                                                    '${widget.store.itemCount} ${'items'.tr}',
                                                    style: robotoRegular.copyWith(
                                                      fontSize:
                                                          Dimensions
                                                              .fontSizeExtraSmall,
                                                      color:
                                                          Theme.of(
                                                            context,
                                                          ).primaryColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                      : Expanded(
                                        flex: 3,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal:
                                                Dimensions.paddingSizeDefault,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 3,
                                                      horizontal:
                                                          Dimensions
                                                              .paddingSizeSmall,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context)
                                                      .primaryColor
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        Dimensions.radiusLarge,
                                                      ),
                                                  border: Border.all(
                                                    color: Theme.of(context)
                                                        .primaryColor
                                                        .withOpacity(0.2),
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
                                                                .fontSizeExtraSmall,
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
                                                                .fontSizeExtraSmall,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              CustomButton(
                                                height: 30,
                                                width:
                                                    widget.fromAllStore
                                                        ? 70
                                                        : 65,
                                                radius: Dimensions.radiusSmall,
                                                onPressed: () {
                                                  if (Get.find<
                                                            SplashController
                                                          >()
                                                          .moduleList !=
                                                      null) {
                                                    for (ModuleModel module
                                                        in Get.find<
                                                              SplashController
                                                            >()
                                                            .moduleList!) {
                                                      if (module.id ==
                                                          widget
                                                              .store
                                                              .moduleId) {
                                                        Get.find<
                                                              SplashController
                                                            >()
                                                            .setModule(module);
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
                                                buttonText: 'shop_now'.tr,
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).primaryColor,
                                                textColor:
                                                    Theme.of(context).cardColor,
                                                fontSize:
                                                    Dimensions.fontSizeSmall,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                ],
                              ),
                            ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),

        Positioned(
          top: widget.fromTopOffers! ? 40 : 60,
          left: 15,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 65,
                width: 65,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).shadowColor.withOpacity(0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                  child: CustomImage(
                    image: '${widget.store.logoFullUrl}',
                    fit: BoxFit.cover,
                    height: double.infinity,
                    width: double.infinity,
                  ),
                ),
              ),

              _buildRatingOrNewBadge(context),
            ],
          ),
        ),

        _buildSmartBadges(context),
      ],
    );
  }

  Widget _buildRatingOrNewBadge(BuildContext context) {
    final hasGoodRating = widget.store.avgRating != null && widget.store.avgRating! >= 4.0;
    final hasAnyRating = widget.store.avgRating != null && widget.store.avgRating! > 0 && widget.store.ratingCount != null && widget.store.ratingCount! >= 5;
    
    if (hasAnyRating) {
      return Positioned(
        bottom: -5,
        right: 5,
        left: 5,
        child: Container(
          decoration: BoxDecoration(
            color: hasGoodRating ? Theme.of(context).primaryColor : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withOpacity(0.12),
                blurRadius: 5,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.store.avgRating!.toStringAsFixed(1),
                style: robotoMedium.copyWith(
                  fontSize: Dimensions.fontSizeSmall,
                  color: hasGoodRating ? Colors.white : Theme.of(context).textTheme.bodyMedium!.color,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.star,
                color: hasGoodRating ? Colors.white : const Color(0xFFFFD700),
                size: 13,
              ),
            ],
          ),
        ),
      );
    } else {
      return Positioned(
        bottom: -5,
        right: 5,
        left: 5,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).primaryColor.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).primaryColor.withOpacity(0.3),
                blurRadius: 4,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 10,
              ),
              const SizedBox(width: 2),
              Text(
                'new'.tr.toUpperCase(),
                style: robotoBold.copyWith(
                  fontSize: 8,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildSmartBadges(BuildContext context) {
    final badges = <Widget>[];
    double badgeTop = 10;
    
    if (widget.store.freeDelivery == true) {
      badges.add(
        Positioned(
          bottom: badgeTop,
          left: 10,
          child: _SmartBadge(
            icon: Icons.local_shipping_outlined,
            text: 'free_delivery'.tr,
            color: const Color(0xFF4CAF50),
          ),
        ),
      );
      badgeTop += 24;
    }

    if (widget.store.open == 1 && widget.store.active == true) {
      final now = DateTime.now();
      final hour = now.hour;
      if ((hour >= 12 && hour <= 14) || (hour >= 18 && hour <= 20)) {
        badges.add(
          Positioned(
            bottom: widget.store.freeDelivery == true ? badgeTop : 10,
            left: 10,
            child: _SmartBadge(
              icon: Icons.schedule,
              text: 'busy_now'.tr,
              color: const Color(0xFFFF9800),
            ),
          ),
        );
      }
    }

    if (badges.isEmpty) {
      return const SizedBox();
    }

    return Stack(children: badges);
  }
}

class _SmartBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _SmartBadge({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.95),
        borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            text,
            style: robotoMedium.copyWith(
              fontSize: 9,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
