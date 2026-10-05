import 'package:waddy_app/common/widgets/offer_collar_badge.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/flash_sale/controllers/flash_sale_controller.dart';
import 'package:waddy_app/features/item/controllers/item_controller.dart';
import 'package:waddy_app/features/flash_sale/domain/models/flash_sale_model.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/cart_count_view.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/organic_tag.dart';

class FlashSaleCard extends StatefulWidget {
  final List<ActiveProducts> activeProducts;
  final bool soldOut;
  const FlashSaleCard({
    super.key,
    required this.activeProducts,
    required this.soldOut,
  });

  @override
  State<FlashSaleCard> createState() => _FlashSaleCardState();
}

class _FlashSaleCardState extends State<FlashSaleCard> {
  late PageController _pageController;
  int _currentPage = 1;
  bool isFirstTime = false;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.activeProducts.length > 1 ? 1 : 0;
    _pageController = PageController(
      initialPage: _currentPage,
      viewportFraction: 0.8,
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {});
    });
  }

  @override
  void dispose() {
    super.dispose();
    _pageController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1.6,
          child: PageView.builder(
            itemCount: widget.activeProducts.length,
            allowImplicitScrolling: true,
            physics: const ClampingScrollPhysics(),
            controller: _pageController,
            onPageChanged: (int pageIndex) {
              Get.find<FlashSaleController>().setPageIndex(pageIndex);
            },
            itemBuilder: (context, index) {
              return Container(
                margin: EdgeInsets.zero,
                child: AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, child) {
                    double value = 0.0;
                    if (_pageController.position.haveDimensions) {
                      value = index.toDouble() - (_pageController.page ?? 0);
                      value = (value * 0.038).clamp(-1, 1);
                    }
                    return Transform.rotate(
                      angle: pi * value,
                      child: carouselCard(index, widget.activeProducts[index]),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget carouselCard(int index, ActiveProducts activeProduct) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeLarge,
              vertical: Dimensions.paddingSizeLarge,
            ),
            child: Hero(
              tag: "image$index",
              child: InkWell(
                hoverColor: Colors.transparent,
                onTap:
                    widget.soldOut
                        ? null
                        : () => Get.find<ItemController>().navigateToItemPage(
                          activeProduct.item,
                          context,
                        ),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).primaryColor.withValues(alpha: 0.2),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(
                      Dimensions.radiusDefault,
                    ),
                    color: Theme.of(context).cardColor,
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          Dimensions.radiusDefault,
                        ),
                        child: CustomImage(
                          image: '${activeProduct.item!.imageFullUrl}',
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),

                      OfferCollarBadge.itemCorner(activeProduct.item!),

                      OrganicTag(
                        item: activeProduct.item!,
                        placeInImage: false,
                      ),

                      Positioned(
                        bottom: -15,
                        left: 0,
                        right: 0,
                        child:
                            widget.soldOut
                                ? Center(
                                  child: Container(
                                    alignment: Alignment.center,
                                    width: 80,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(112),
                                      color: Theme.of(context).cardColor,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Theme.of(
                                            context,
                                          ).primaryColor.withValues(alpha: 0.1),
                                          spreadRadius: 1,
                                          blurRadius: 5,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      'sold_out'.tr,
                                      style: waddyMedium.copyWith(
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                )
                                : CartCountView(
                                  item: activeProduct.item!,
                                  index: index,
                                  child: Center(
                                    child: Container(
                                      alignment: Alignment.center,
                                      width: 65,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                          112,
                                        ),
                                        color: Theme.of(context).cardColor,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Theme.of(context)
                                                .primaryColor
                                                .withValues(alpha: 0.1),
                                            spreadRadius: 1,
                                            blurRadius: 5,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        "add".tr,
                                        style: waddyBold.copyWith(
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
