import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:waddy_app/features/flash_sale/controllers/flash_sale_controller.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';
import 'package:waddy_app/common/widgets/custom_app_bar.dart';
import 'package:waddy_app/common/widgets/footer_view.dart';
import 'package:waddy_app/common/widgets/paginated_list_view.dart';
import 'package:waddy_app/features/flash_sale/widgets/flash_product_card_widget.dart';
import 'package:waddy_app/features/flash_sale/widgets/flash_sale_timer_view_widget.dart';

class FlashSaleDetailsScreen extends StatefulWidget {
  final int id;
  const FlashSaleDetailsScreen({super.key, required this.id});

  @override
  State<FlashSaleDetailsScreen> createState() => _FlashSaleDetailsScreenState();
}

class _FlashSaleDetailsScreenState extends State<FlashSaleDetailsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    Get.find<FlashSaleController>().getFlashSaleWithId(1, false, widget.id);
  }

  @override
  void dispose() {
    super.dispose();
    _scrollController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'flash_sale'.tr),
      body: Center(
        child: GetBuilder<FlashSaleController>(
          builder: (flashSaleController) {
            return Column(
              children: [
                SizedBox(height: 0),
                Container(
                  width: Dimensions.maxContentWidth,
                  padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(0),
                    border: Border.symmetric(
                      horizontal: BorderSide(
                        color: Theme.of(
                          context,
                        ).primaryColor.withValues(alpha: 0.2),
                        width: 2,
                      ),
                      vertical: BorderSide(
                        color: Theme.of(
                          context,
                        ).primaryColor.withValues(alpha: 0.2),
                        width: 2,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'flash_sale'.tr,
                            style: waddyBold.copyWith(
                              fontSize: Dimensions.fontSizeLarge,
                            ),
                          ),
                          const SizedBox(
                            height: Dimensions.paddingSizeExtraSmall,
                          ),

                          Text(
                            'limited_time_offer'.tr,
                            style: waddyRegular.copyWith(
                              fontSize: Dimensions.fontSizeSmall,
                              color: Theme.of(context).disabledColor,
                            ),
                          ),
                        ],
                      ),

                      FlashSaleTimerView(
                        eventDuration: flashSaleController.duration,
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    child: FooterView(
                      child: SizedBox(
                        width: Dimensions.maxContentWidth,
                        child: PaginatedListView(
                          scrollController: _scrollController,
                          totalSize:
                              flashSaleController.productFlashSale?.totalSize,
                          offset: flashSaleController.productFlashSale?.offset,
                          onPaginate:
                              (int? offset) async =>
                                  await flashSaleController.getFlashSaleWithId(
                                    offset!,
                                    false,
                                    widget.id,
                                  ),
                          itemView:
                              flashSaleController.productFlashSale != null
                                  ? GridView.builder(
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          crossAxisSpacing:
                                              Dimensions.paddingSizeSmall,
                                          mainAxisSpacing:
                                              Dimensions.paddingSizeSmall,
                                          mainAxisExtent: 240,
                                        ),
                                    physics: const BouncingScrollPhysics(),
                                    shrinkWrap: true,
                                    itemCount:
                                        flashSaleController
                                            .productFlashSale!
                                            .products!
                                            .length,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: Dimensions.paddingSizeDefault,
                                      vertical: Dimensions.paddingSizeDefault,
                                    ),
                                    itemBuilder: (context, index) {
                                      return FlashProductCardWidget(
                                        product:
                                            flashSaleController
                                                .productFlashSale!
                                                .products![index],
                                        index: index,
                                      );
                                    },
                                  )
                                  : const FlashProductCardShimmer(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class FlashProductCardShimmer extends StatelessWidget {
  const FlashProductCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: Dimensions.paddingSizeSmall,
        mainAxisSpacing: Dimensions.paddingSizeSmall,
        mainAxisExtent: 240,
      ),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: 10,
      padding: EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
        vertical: Dimensions.paddingSizeDefault,
      ),
      itemBuilder: (context, index) {
        return Shimmer(
          duration: const Duration(seconds: 2),
          enabled: true,
          child: Container(
            padding: const EdgeInsets.all(Dimensions.paddingSizeExtraSmall),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      Dimensions.radiusDefault,
                    ),
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: Theme.of(context).cardColor,
                    ),
                  ),
                ),
                SizedBox(height: 0),

                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(
                      Dimensions.paddingSizeExtraSmall,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          height: 10,
                          width: 100,
                          color: Theme.of(context).cardColor,
                        ),

                        Container(
                          height: 10,
                          width: 200,
                          color: Theme.of(context).cardColor,
                        ),

                        Container(
                          height: 10,
                          width: 100,
                          color: Theme.of(context).cardColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
