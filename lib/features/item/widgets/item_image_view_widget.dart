import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waddy_app/features/item/controllers/item_controller.dart';
import 'package:waddy_app/features/item/domain/models/item_model.dart';
import 'package:waddy_app/helper/price_converter.dart';
import 'package:waddy_app/helper/responsive_helper.dart';
import 'package:waddy_app/helper/route_helper.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';

class ItemImageViewWidget extends StatefulWidget {
  final Item? item;
  final bool isCampaign;
  final bool inStock;
  const ItemImageViewWidget({super.key, required this.item, this.isCampaign = false, this.inStock = false});

  @override
  State<ItemImageViewWidget> createState() => _ItemImageViewWidgetState();
}

class _ItemImageViewWidgetState extends State<ItemImageViewWidget> {
  final PageController _controller = PageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<String?> imageList = [];
    List<String?> imageListForCampaign = [];

    if (widget.isCampaign) {
      imageListForCampaign.add(widget.item!.imageFullUrl);
    } else {
      imageList.add(widget.item!.imageFullUrl);
      imageList.addAll(widget.item!.imagesFullUrl!);
    }

    final List<String?> images = widget.isCampaign ? imageListForCampaign : imageList;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double imageHeight = ResponsiveHelper.isDesktop(context)
        ? 400
        : screenWidth * 0.65;

    return GetBuilder<ItemController>(
      builder: (itemController) {
        return Stack(
          children: [
            // Blurred background tint from product image
            if (images.isNotEmpty && images.first != null)
              Positioned.fill(
                child: ClipRect(
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                    child: Opacity(
                      opacity: 0.15,
                      child: CustomImage(
                        image: '${images.first}',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),

            // Main content
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFF7F8FA),
                    const Color(0xFFF7F8FA).withValues(alpha: 0.95),
                    Colors.white,
                  ],
                  stops: const [0.0, 0.7, 1.0],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Hero image area
                  GestureDetector(
                    onTap: widget.isCampaign
                        ? null
                        : () {
                            Navigator.of(context).pushNamed(
                              RouteHelper.getItemImagesRoute(widget.item!),
                              arguments: ItemImageViewWidget(item: widget.item),
                            );
                          },
                    child: SizedBox(
                      width: double.infinity,
                      height: imageHeight,
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: images.length,
                        itemBuilder: (context, index) {
                          return AnimatedBuilder(
                            animation: _controller,
                            builder: (context, child) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                child: Hero(
                                  tag: 'item_image_${widget.item?.id ?? 0}_$index',
                                  child: CustomImage(
                                    image: '${images[index]}',
                                    height: imageHeight,
                                    width: screenWidth,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        onPageChanged: (index) {
                          itemController.setImageSliderIndex(index);
                        },
                      ),
                    ),
                  ),

                  // Modern pill-style dot indicators with counter
                  if (images.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18, top: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 12,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(images.length, (index) {
                                final bool isActive = index == itemController.imageSliderIndex;
                                return GestureDetector(
                                  onTap: () {
                                    _controller.animateToPage(
                                      index,
                                      duration: const Duration(milliseconds: 350),
                                      curve: Curves.easeInOutCubic,
                                    );
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOutCubic,
                                    width: isActive ? 22 : 7,
                                    height: 7,
                                    margin: EdgeInsets.only(
                                      right: index < images.length - 1 ? 5 : 0,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      color: isActive
                                          ? Theme.of(context).primaryColor
                                          : Theme.of(context).primaryColor.withValues(alpha: 0.18),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Discount sticker - rotated chip like in-stock, neo-pop style
            if (widget.item!.discount != null && widget.item!.discount! > 0)
              Positioned(
                bottom: 16,
                right: 12,
                child: Transform.rotate(
                  angle: 0.12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).secondaryHeaderColor,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                          offset: const Offset(0, 3),
                        ),
                        BoxShadow(
                          color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      widget.item!.discountType == 'percent'
                          ? '${widget.item!.discount!.toStringAsFixed(0)}% ${'off'.tr.toUpperCase()}'
                          : '${PriceConverter.convertPrice(widget.item!.discount)} ${'off'.tr.toUpperCase()}',
                      style: robotoBlack.copyWith(
                        fontSize: 11,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ),
              ),

            // In-stock / Out-of-stock sticker - rotated on top-left
            Positioned(
              top: 16,
              left: 12,
              child: Transform.rotate(
                angle: -0.12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.inStock ? Theme.of(context).colorScheme.error : const Color(0xFF2E7D32),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: (widget.inStock ? Theme.of(context).colorScheme.error : const Color(0xFF2E7D32)).withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        widget.inStock ? 'out_of_stock'.tr : 'in_stock'.tr,
                        style: robotoBold.copyWith(
                          fontSize: 11,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
