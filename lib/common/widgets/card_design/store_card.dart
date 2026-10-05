import 'package:waddy_app/features/store/store_navigator.dart';
import 'package:waddy_app/features/store/domain/store_rules.dart';
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
import 'package:waddy_app/util/images.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/new_tag.dart';
import 'package:waddy_app/common/widgets/rating_bar.dart';

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
        Get.find<SplashController>().module?.type == ModuleType.pharmacy;
    // The store's own coordinates are server strings and can be absent, so
    // they are read before they are used rather than banged through.
    final double? distance = widget.store.distanceFromUserKm();
    double discount = widget.store.discount?.discount ?? 0;
    String discountType = widget.store.discount?.discountType ?? '';
    bool isRightSide =
        Get.find<SplashController>().configModel.currencySymbolDirection ==
        'right';
    String currencySymbol =
        Get.find<SplashController>().configModel.currencySymbol!;
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
                // One blur pass per card, not two — see
                // store_card_with_distance.dart for the measurement.
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).shadowColor.withOpacity(0.14),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: CustomInkWell(
                onTap: () {
                  StoreNavigator.open(widget.store);
                },
                padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                radius: Dimensions.radiusDefault,
                child: Stack(
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
                                  CustomImage(
                                    image: '${widget.store.logoFullUrl}',
                                    height: 50,
                                    width: 50,
                                    fit: BoxFit.cover,
                                    // Rounded by the decoration, not a ClipRRect — no saveLayer.
                                    borderRadius: BorderRadius.circular(
                                      Dimensions.radiusDefault,
                                    ),
                                  ),

                                  isAvailable
                                      ? const SizedBox()
                                      : NotAvailableWidget(
                                        isStore: true,
                                        store: widget.store,
                                        fontSize: Dimensions.fontSizeExtraSmall,
                                        isAllSideRound: true,
                                      ),
                                ],
                              ),
                              const SizedBox(
                                width: Dimensions.paddingSizeSmall,
                              ),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 190,
                                      child: Text(
                                        widget.store.name ?? '',
                                        style: waddyMedium.copyWith(
                                          fontSize: Dimensions.fontSizeDefault,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: Dimensions.paddingSizeExtraSmall,
                                    ),

                                    !isPharmacy
                                        ? widget.store.ratingCount! > 0
                                            ? RatingBar(
                                              rating: widget.store.avgRating,
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
                                                style: waddyRegular.copyWith(
                                                  fontSize:
                                                      Dimensions
                                                          .fontSizeExtraSmall,
                                                  color:
                                                      Theme.of(
                                                        context,
                                                      ).primaryColor,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                    const SizedBox(
                                      height: Dimensions.paddingSizeExtraSmall,
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
                                                style: waddyMedium.copyWith(
                                                  fontSize:
                                                      Dimensions
                                                          .fontSizeExtraSmall,
                                                  color:
                                                      Theme.of(
                                                        context,
                                                      ).primaryColor,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        )
                                        : Text(
                                          '${widget.store.itemCount}'
                                                  ' '
                                                  'items'
                                              .tr,
                                          style: waddyRegular.copyWith(
                                            fontSize: Dimensions.fontSizeSmall,
                                            color:
                                                Theme.of(context).primaryColor,
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
                                              distance == null
                                                  ? '--'
                                                  : '${distance > 100 ? '100+' : distance.toStringAsFixed(2)} ${'km'.tr}',
                                              style: waddyBold.copyWith(
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).disabledColor,
                                                fontSize:
                                                    Dimensions.fontSizeSmall,
                                              ),
                                            ),
                                            const SizedBox(
                                              width:
                                                  Dimensions
                                                      .paddingSizeExtraSmall,
                                            ),

                                            Text(
                                              'from_you'.tr,
                                              style: waddyRegular.copyWith(
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).disabledColor,
                                                fontSize:
                                                    Dimensions.fontSizeSmall,
                                              ),
                                            ),
                                          ],
                                        ),

                                        Container(
                                          decoration: BoxDecoration(
                                            color:
                                                Theme.of(context).primaryColor,
                                            borderRadius: BorderRadius.circular(
                                              Dimensions.radiusExtraLarge,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal:
                                                Dimensions.paddingSizeSmall,
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
                                            style: waddyMedium.copyWith(
                                              color:
                                                  Theme.of(context).cardColor,
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
                                          borderRadius: BorderRadius.circular(
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
                                              distance == null
                                                  ? '--'
                                                  : '${distance > 100 ? '100+' : distance.toStringAsFixed(2)} ${'km'.tr}',
                                              style: waddyBold.copyWith(
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).primaryColor,
                                                fontSize:
                                                    Dimensions.fontSizeSmall,
                                              ),
                                            ),
                                            const SizedBox(
                                              width:
                                                  Dimensions
                                                      .paddingSizeExtraSmall,
                                            ),

                                            Text(
                                              'from_you'.tr,
                                              style: waddyRegular.copyWith(
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).primaryColor,
                                                fontSize:
                                                    Dimensions.fontSizeSmall,
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
                                              widget.store.isOpenNow
                                                  ? const Color(
                                                    0xffECA507,
                                                  ).withOpacity(0.1)
                                                  : Theme.of(context)
                                                      .colorScheme
                                                      .error
                                                      .withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            Dimensions.radiusExtraLarge,
                                          ),
                                          border: Border.all(
                                            color:
                                                widget.store.isOpenNow
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
                                                  widget.store.isOpenNow
                                                      ? const Color(0xffECA507)
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
                                              widget.store.isOpenNow
                                                  ? 'open_now'.tr
                                                  : 'closed_now'.tr,
                                              style: waddyBold.copyWith(
                                                color:
                                                    widget.store.isOpenNow
                                                        ? const Color(
                                                          0xffECA507,
                                                        )
                                                        : Theme.of(
                                                          context,
                                                        ).colorScheme.error,
                                                fontSize:
                                                    Dimensions.fontSizeSmall,
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
                      left: Get.find<LocalizationController>().isLtr ? null : 0,
                      right:
                          Get.find<LocalizationController>().isLtr ? 0 : null,
                      item: null,
                      storeId: widget.store.id,
                    ),
                  ],
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
