import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/common/widgets/custom_ink_well.dart';
import 'package:waddy_app/common/widgets/hover/text_hover.dart';
import 'package:waddy_app/features/store/domain/models/store_model.dart';
import 'package:waddy_app/helper/responsive_helper.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/features/store/screens/store_screen.dart';

class PopularStoreCard extends StatefulWidget {
  final Store store;
  const PopularStoreCard({super.key, required this.store});

  @override
  State<PopularStoreCard> createState() => _PopularStoreCardState();
}

class _PopularStoreCardState extends State<PopularStoreCard>
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
    final hasDiscount =
        widget.store.discount != null &&
        widget.store.discount!.discount != null &&
        widget.store.discount!.discount! > 0;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(scale: _scaleAnimation.value, child: child);
        },
        child: Container(
          width: ResponsiveHelper.isDesktop(context) ? 315 : 260,
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
          child: TextHover(
            builder: (hovered) {
              return CustomInkWell(
                onTap: () {
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
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                  child: Stack(
                    children: [
                      CustomImage(
                        isHovered: hovered,
                        image: '${widget.store.coverPhotoFullUrl}',
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 170,
                      ),

                      // Discount badge
                      if (hasDiscount)
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.error,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${widget.store.discount!.discount!.toInt()}% OFF',
                              style: robotoMedium.copyWith(
                                color: Colors.white,
                                fontSize: Dimensions.fontSizeExtraSmall,
                              ),
                            ),
                          ),
                        ),

                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          width: double.infinity,
                          height: 89,
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(
                              Dimensions.radiusDefault,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(
                              Dimensions.paddingSizeSmall,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(
                                      color: Theme.of(
                                        context,
                                      ).primaryColor.withOpacity(0.3),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Theme.of(
                                          context,
                                        ).shadowColor.withOpacity(0.08),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(100),
                                    child: CustomImage(
                                      image: '${widget.store.logoFullUrl}',
                                      height: 40,
                                      width: 40,
                                    ),
                                  ),
                                ),
                                const SizedBox(
                                  width: Dimensions.paddingSizeDefault,
                                ),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        widget.store.name ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: robotoMedium.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        widget.store.address ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: robotoRegular.copyWith(
                                          color:
                                              Theme.of(context).disabledColor,
                                        ),
                                      ),

                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Theme.of(
                                                context,
                                              ).primaryColor.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.star,
                                                  color:
                                                      Theme.of(
                                                        context,
                                                      ).primaryColor,
                                                  size: 13,
                                                ),
                                                const SizedBox(width: 2),
                                                Text(
                                                  widget.store.avgRating!
                                                      .toStringAsFixed(1),
                                                  style: robotoMedium.copyWith(
                                                    fontSize:
                                                        Dimensions
                                                            .fontSizeExtraSmall,
                                                  ),
                                                ),
                                                const SizedBox(width: 2),
                                                Text(
                                                  '(${widget.store.ratingCount})',
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
                                              ],
                                            ),
                                          ),
                                          const SizedBox(
                                            width: Dimensions.paddingSizeSmall,
                                          ),
                                          Text(
                                            '${widget.store.itemCount}'
                                                    ' '
                                                    'items'
                                                .tr,
                                            style: robotoRegular.copyWith(
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).primaryColor,
                                              fontSize:
                                                  Dimensions.fontSizeExtraSmall,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
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
            },
          ),
        ),
      ),
    );
  }
}
